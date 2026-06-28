# Library Manager — git Maintain reports (doc/claude/specs/library_git.md §2.1, §4.1).
# Phase 2 backend seam: the multi-library Show-Status / History report builders
# and the bucket-by-root grouping that makes them safe across topologies. This is
# the GUI-free, fully headless half of Phase 2 (the menubar + multi-select picker
# in library_manager.tcl is the manual-eyeball half, exercised under the binary).
#
# These procs map a registered LIBRARY NAME (via library_resolve) to its on-disk
# path, so the test sources library_defs.tcl too and registers real libraries
# over real git fixtures. Runs under a plain tclsh (no X, no rebuild):
#
#   tclsh tests/headless/test_library_git_report.tcl

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}
proc val {body} { if {[catch {uplevel 1 $body} r]} { return {__ERR__ 1} } ; return $r }
proc norm {p} { return [file normalize $p] }

set OS unix
set here [file dirname [file normalize [info script]]]
set src [norm [file join $here .. .. src]]
foreach f {library_defs.tcl library_git.tcl} {
  set p [file join $src $f]
  if {[file exists $p]} { source $p }
}

proc touch {f txt} { file mkdir [file dirname $f]; set fp [open $f w]; puts -nonewline $fp $txt; close $fp }
proc ginit {repo} {
  exec git init -q $repo
  exec git -C $repo config user.email test@example.com
  exec git -C $repo config user.name  Tester
  exec git -C $repo config commit.gpgsign false
}
proc gcommit {repo msg args} {
  exec git -C $repo add -- {*}$args
  exec git -C $repo commit -q -m $msg
}

# --- fixtures (real temp dir, NOT under any git repo) -----------------------
set tmpbase [expr {[info exists env(TMPDIR)] && $env(TMPDIR) ne {} ? $env(TMPDIR) : "/tmp"}]
set tmp [file join $tmpbase _libgitrep_[pid]]
file delete -force $tmp
file mkdir $tmp

# Case C: one bigger repo, two registered libraries sharing its root.
set big [file join $tmp big]
touch $big/libs/devices/and2/symbol/and2.sym       "v {and2 sym}\n"
touch $big/libs/examples/test1/schematic/test1.sch "v {test1 sch}\n"
ginit $big
gcommit $big "seed both libs" libs
set devices [file join $big libs devices]
set examples [file join $big libs examples]
# a devices-only commit (its own cell) gives devices history without disturbing
# the untracked/modified state we set up for the status report below.
touch $devices/and3/symbol/and3.sym "v {and3 sym}\n"
exec git -C $big add -- libs/devices/and3
exec git -C $big commit -q -m "history-marker-devices" -- libs/devices/and3
touch $devices/or3/symbol/or3.sym   "v {or3 sym}\n"            ;# untracked
touch $devices/and2/symbol/and2.sym "v {and2 sym MODIFIED}\n"  ;# modified tracked

# Case A/D: a standalone repo registered as its own library.
set slib [file join $tmp slib]
touch $slib/inv/symbol/inv.sym "v {inv sym}\n"
ginit $slib
gcommit $slib "seed slib" inv

# Case E: a registered library that is not under git at all.
set plain [file join $tmp plain]
touch $plain/buf/symbol/buf.sym "v {buf sym}\n"

# register everything
set defs [file join $tmp library.defs]
set fp [open $defs w]
puts $fp "DEFINE devices $devices"
puts $fp "DEFINE examples $examples"
puts $fp "DEFINE slib $slib"
puts $fp "DEFINE plainlib $plain"
close $fp
set ::XSCHEM_LIBRARY_DEFS $defs
set ::library_registry_defs_only 1

check "REG sanity: devices resolves" [expr {[library_resolve devices] eq [norm $devices]}] "(=> [library_resolve devices])"

# === §2.1 grouping invariant: bucket selected libraries by repo root =========
# Same repo (case C) -> ONE group with two pathspecs; different repos (case D) ->
# separate groups; not-under-git (case E) -> a root-"" group.
proc grp_roots {libs} {
  set out {}
  foreach g [val {lib_git_group_by_root $libs}] { lappend out [lindex $g 0] }
  return $out
}
proc grp_with_root {libs root} {
  foreach g [val {lib_git_group_by_root $libs}] { if {[lindex $g 0] eq $root} { return $g } }
  return {}
}
check "GR1 two libs sharing a root -> one group" [expr {[llength [val {lib_git_group_by_root {devices examples}}]] == 1}] "(=> [val {lib_git_group_by_root {devices examples}}])"
check "GR2 that group carries BOTH pathspecs against the shared root" [expr {
  [lindex [grp_with_root {devices examples} [norm $big]] 0] eq [norm $big] &&
  [llength [grp_with_root {devices examples} [norm $big]]] == 3}] "(=> [grp_with_root {devices examples} [norm $big]])"
check "GR3 libs in different repos -> separate groups (case D)" [expr {[llength [val {lib_git_group_by_root {devices slib}}]] == 2}] "(=> [grp_roots {devices slib}])"
check "GR4 not-under-git library buckets under root \"\" (case E)" [expr {[lsearch -exact [grp_roots {plainlib}] {}] >= 0}] "(=> [grp_roots {plainlib}])"
check "GR5 mixed selection: 2 groups (big + none)" [expr {[llength [val {lib_git_group_by_root {devices plainlib examples}}]] == 2}] "(=> [grp_roots {devices plainlib examples}])"

# === §4.1 Show Status: per-library untracked + pending sections ==============
set sr [val {lib_git_status_report {devices examples}}]
check "ST1 report has a per-library section header" [string match "*Library: devices*" $sr] {}
check "ST2 untracked cell listed under devices" [regexp {Untracked:.*or3/symbol} [string map {\n { }} $sr]] "(=> $sr)"
check "ST3 modified cell listed as pending commit" [regexp {Pending commit:.*and2/symbol.*modified} [string map {\n { }} $sr]] "(=> $sr)"
check "ST4 sibling library's cell never leaks into devices section" [expr {![string match "*test1*" [lindex [split $sr "\n\n"] 0]]}] "(devices section: [lindex [split $sr "\n\n"] 0])"
set sr2 [val {lib_git_status_report {plainlib}}]
check "ST5 not-under-git library degrades, never errors" [string match "*not under git*" $sr2] "(=> $sr2)"
set sr3 [val {lib_git_status_report {nosuchlib}}]
check "ST6 unknown library is reported, not fatal" [string match "*not found*" $sr3] "(=> $sr3)"

# === §4.1 History: per-library git log sections =============================
set hr [val {lib_git_history_report {devices}}]
check "HS1 history shows the devices commit" [string match "*history-marker-devices*" $hr] {}
check "HS2 examples history excludes the devices-only commit" [expr {![string match "*history-marker-devices*" [val {lib_git_history_report {examples}}]]}] "(=> [val {lib_git_history_report {examples}}])"
check "HS3 not-under-git library history degrades gracefully" [string match "*not under git*" [val {lib_git_history_report {plainlib}}]] {}

file delete -force $tmp
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
