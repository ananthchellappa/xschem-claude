# Library Manager — git revision-control backend (doc/claude/specs/library_git.md, Phase 1).
# Exercises the pure-Tcl `exec git` wrappers in src/library_git.tcl against real
# temp git-repo fixtures covering EVERY topology in spec §2:
#
#   A. standalone repo   — the library dir IS the repo root
#   B. subdir of a repo  — the library lives deep inside a bigger repo
#   C. two libs, ONE repo— `devices` + `examples` share a root; ops must scope
#   D. libs, DIFF repos  — slib (repo A) + devices (repo B) resolve to own roots
#   E. not under git     — every action degrades gracefully, never errors the GUI
#
# The backend is pure Tcl (no C, no X), so this runs under a plain tclsh as well
# as the xschem binary; it sources the source-tree file directly so no rebuild /
# reinstall is needed. Fixtures live OUTSIDE the working tree (a temp dir) so the
# "not under git" case is genuinely outside any enclosing repo.
#
#   tclsh tests/headless/test_library_git.tcl
#   ./xschem --pipe -q --script ../tests/headless/test_library_git.tcl   (from src/)

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}
# value of `body`, or a sentinel if it raised. The sentinel is a valid 2-element
# list AND dict ("__ERR__ 1") so the list/dict helpers below never crash on it —
# a missing proc surfaces as a visible FAIL, not an aborted run (genuine RED).
proc val {body} { if {[catch {uplevel 1 $body} r]} { return {__ERR__ 1} } ; return $r }
proc errs {body} { return [catch [list uplevel 1 $body]] }
proc norm {p} { return [file normalize $p] }
proc dval {d key} { if {[dict exists $d $key]} { return [dict get $d $key] } ; return "<none>" }
proc has  {d key} { return [dict exists $d $key] }
proc inlist {l v} { return [expr {[lsearch -exact $l $v] >= 0}] }

# Source the backend under test directly from the source tree (RED before it
# exists: the procs are simply undefined and every `val` returns <ERR:...>).
set here [file dirname [file normalize [info script]]]
set gitlib [norm [file join $here .. .. src library_git.tcl]]
if {[file exists $gitlib]} { source $gitlib }

proc touch {f txt} { file mkdir [file dirname $f]; set fp [open $f w]; puts -nonewline $fp $txt; close $fp }
proc slurp {f} { set fp [open $f r]; set d [read $fp]; close $fp; return $d }
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

# --- fixtures (in a real temp dir, NOT under any git repo) -------------------
set tmpbase [expr {[info exists env(TMPDIR)] && $env(TMPDIR) ne {} ? $env(TMPDIR) : "/tmp"}]
set tmp [file join $tmpbase _libgit_[pid]]
file delete -force $tmp
file mkdir $tmp

# Case A — standalone repo: library dir == repo root. Nested 'inv' (sym+sch)
# committed; a flat 'res.sym' left untracked.
set slib [file join $tmp slib]
touch $slib/inv/symbol/inv.sym    "v {inv sym}\n"
touch $slib/inv/schematic/inv.sch "v {inv sch}\n"
touch $slib/library.tag           "NAME slib\n"
ginit $slib
gcommit $slib "init slib" inv library.tag
touch $slib/res.sym "v {res sym}\n"   ;# untracked flat cell

# Cases B + C — one bigger repo holding unrelated files AND two libraries.
set big [file join $tmp big]
touch $big/src/foo.txt                                "unrelated\n"
touch $big/libs/devices/and2/symbol/and2.sym          "v {and2 sym}\n"
touch $big/libs/devices/library.tag                   "NAME devices\n"
touch $big/libs/examples/test1/schematic/test1.sch    "v {test1 sch}\n"
touch $big/libs/examples/library.tag                  "NAME examples\n"
ginit $big
gcommit $big "init big" src libs
set devices [file join $big libs devices]
set examples [file join $big libs examples]
set and2sym [file join $devices and2 symbol and2.sym]
set and2_committed [slurp $and2sym]
touch $devices/or3/symbol/or3.sym "v {or3 sym}\n"            ;# untracked new cell
touch $and2sym                    "v {and2 sym MODIFIED}\n"  ;# modified tracked
touch $examples/test1/schematic/test1.sch "v {test1 sch MODIFIED}\n"  ;# modified, other lib

# Case E — not under git at all.
set plain [file join $tmp plain]
touch $plain/inv.sym "v {plain inv}\n"

# === capability ==============================================================
check "AV1 git capability detected" [inlist [val {lib_git_available}] git] "(=> [val {lib_git_available}])"

# === root / relpath / context resolution (A,B,D,E) ===========================
# A: root derived from a datafile path equals the standalone library/repo dir.
check "RT1 standalone root == library dir" [expr {[val {lib_git_root $slib/inv/symbol/inv.sym}] eq [norm $slib]}] "(=> [val {lib_git_root $slib/inv/symbol/inv.sym}])"
check "RT2 root of the library dir itself"  [expr {[val {lib_git_root $slib}] eq [norm $slib]}] {}
# B: a deep subdir library resolves to the FAR-ABOVE repo root, not the lib dir.
check "RT3 subdir-lib root is the bigger repo" [expr {[val {lib_git_root $devices}] eq [norm $big]}] "(=> [val {lib_git_root $devices}])"
check "RT4 relpath scopes lib to its pathspec" [expr {[val {lib_git_relpath [norm $big] $devices}] eq "libs/devices"}] "(=> [val {lib_git_relpath [norm $big] $devices}])"
check "RT5 relpath of root to itself is ." [expr {[val {lib_git_relpath [norm $slib] $slib}] eq "."}] "(=> [val {lib_git_relpath [norm $slib] $slib}])"
check "RT6 context = {root pathspec}" [expr {[val {lib_git_context $devices}] eq [list [norm $big] libs/devices]}] "(=> [val {lib_git_context $devices}])"
# E: graceful — no enclosing repo.
check "RT7 not-under-git root is empty" [expr {[val {lib_git_root $plain}] eq ""}] "(=> [val {lib_git_root $plain}])"
check "RT8 not-under-git context is {}" [expr {[val {lib_git_context $plain}] eq ""}] "(=> [val {lib_git_context $plain}])"

# === path -> cellview attribution helper =====================================
check "AT1 nested datafile -> cell/view"  [expr {[val {lib_git_cellview $slib inv/symbol/inv.sym}] eq "inv/symbol"}] "(=> [val {lib_git_cellview $slib inv/symbol/inv.sym}])"
check "AT2 flat .sym -> cell/symbol"      [expr {[val {lib_git_cellview $slib res.sym}] eq "res/symbol"}] "(=> [val {lib_git_cellview $slib res.sym}])"
check "AT3 flat .sch -> cell/schematic"   [expr {[val {lib_git_cellview $slib res.sch}] eq "res/schematic"}] "(=> [val {lib_git_cellview $slib res.sch}])"
check "AT4 library.tag is not a cellview" [expr {[val {lib_git_cellview $slib library.tag}] eq ""}] {}
check "AT5 trash is excluded"             [expr {[val {lib_git_cellview $slib .xschem_trash/inv/symbol/inv.sym}] eq ""}] {}
check "AT6 ~-backup is excluded"          [expr {[val {lib_git_cellview $slib inv/symbol/inv.sym~}] eq ""}] {}
check "AT7 mismatched nested name ignored" [expr {[val {lib_git_cellview $slib foo/symbol/bar.sym}] eq ""}] "(=> [val {lib_git_cellview $slib foo/symbol/bar.sym}])"

# === status map ==============================================================
# devices: untracked new cell + modified tracked cell, scoped to devices only.
check "SM1 untracked new cell" [expr {[dval [val {lib_git_status_map $devices}] or3/symbol] eq "untracked"}] "(=> [dval [val {lib_git_status_map $devices}] or3/symbol])"
check "SM2 modified tracked cell" [expr {[dval [val {lib_git_status_map $devices}] and2/symbol] eq "modified"}] "(=> [dval [val {lib_git_status_map $devices}] and2/symbol])"
check "SM3 sibling library never leaks in (case C)" [expr {![has [val {lib_git_status_map $devices}] test1/schematic]}] "(keys: [dict keys [val {lib_git_status_map $devices}]])"
check "SM4 standalone: flat untracked cell" [expr {[dval [val {lib_git_status_map $slib}] res/symbol] eq "untracked"}] "(=> [dval [val {lib_git_status_map $slib}] res/symbol])"
check "SM5 not-under-git status degrades to empty" [expr {[val {lib_git_status_map $plain}] eq ""}] "(=> [val {lib_git_status_map $plain}])"

# === tracked set (drives the bold tag) =======================================
check "TS1 committed datafile is tracked"   [has [val {lib_git_tracked_set $devices}] and2/symbol] {}
check "TS2 untracked datafile is not"       [expr {![has [val {lib_git_tracked_set $devices}] or3/symbol]}] {}
check "TS3 not-under-git tracked set empty"  [expr {[val {lib_git_tracked_set $plain}] eq ""}] {}

# === checkouts (local edit-lock model) =======================================
check "CO1 modified view shows as a checkout" [inlist [val {lib_git_checkouts $devices}] and2/symbol] "(=> [val {lib_git_checkouts $devices}])"
check "CO2 untracked-new view is not a checkout" [expr {![inlist [val {lib_git_checkouts $devices}] or3/symbol]}] {}
# checking out a CLEAN, committed view records a marker so it shows up even
# before any edit (integrates with the read-only clear in the GUI layer).
check "CO3 check out a clean view" [expr {![errs {lib_git_checkout $slib/inv/symbol/inv.sym}]}] {}
check "CO4 checked-out clean view appears via marker" [inlist [val {lib_git_checkouts $slib}] inv/symbol] "(=> [val {lib_git_checkouts $slib}])"

# === commit (pathspec-scoped to ONE library; case C invariant) ===============
check "CM1 commit devices succeeds" [expr {![errs {lib_git_commit [norm $big] {libs/devices} "commit-devices-only"}]}] {}
check "CM2 devices change is now committed (clean)" [expr {![has [val {lib_git_status_map $devices}] and2/symbol]}] "(keys: [dict keys [val {lib_git_status_map $devices}]])"
check "CM3 sibling library was NOT swept into the commit" [expr {[dval [val {lib_git_status_map $examples}] test1/schematic] eq "modified"}] "(=> [dval [val {lib_git_status_map $examples}] test1/schematic])"
check "CM4 commit message is empty-string guarded" [errs {lib_git_commit [norm $big] {libs/devices} "  "}] {}

# === log (history, pathspec-scoped) ==========================================
check "LG1 history shows the devices commit" [string match {*commit-devices-only*} [val {lib_git_log [norm $big] {libs/devices}}]] {}
check "LG2 examples history excludes the devices-only commit" [expr {![string match {*commit-devices-only*} [val {lib_git_log [norm $big] {libs/examples}}]]}] {}

# === restore (roll a datafile back to HEAD) ==================================
# and2 was just committed (content == MODIFIED). Edit again, then restore.
touch $and2sym "v {and2 sym EDITED-AGAIN}\n"
check "RS1 edit dirties the view" [expr {[dval [val {lib_git_status_map $devices}] and2/symbol] eq "modified"}] {}
check "RS2 restore succeeds" [expr {![errs {lib_git_restore [norm $big] [list $and2sym]}]}] {}
check "RS3 datafile rolled back to committed content" [expr {[slurp $and2sym] eq "v {and2 sym MODIFIED}\n"}] "(=> [slurp $and2sym])"

# === cancel checkout (restore + drop marker), and graceful no-git ============
touch $slib/inv/symbol/inv.sym "v {inv sym DIRTY}\n"
check "CC1 cancel checkout reverts edits" [expr {![errs {lib_git_cancel_checkout $slib/inv/symbol/inv.sym}]}] {}
check "CC2 datafile restored after cancel" [expr {[slurp $slib/inv/symbol/inv.sym] eq "v {inv sym}\n"}] "(=> [slurp $slib/inv/symbol/inv.sym])"
check "CC3 commit on a non-git path errors (never silently no-ops)" [errs {lib_git_commit "" {x} "m"}] {}
check "CC4 checkout on a non-git path errors" [errs {lib_git_checkout $plain/inv.sym}] {}

file delete -force $tmp
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
