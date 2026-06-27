# Library Manager — structured git history (doc/claude/specs/library_git.md §4.1, History
# form). `lib_git_log_records {root pathspecs}` returns one dict per commit
# (hash, short, date, author, subject, body), newest-first, scoped to the
# pathspecs — the data behind the two-pane History dialog (commit list above,
# message below). Pure Tcl; runs under a plain tclsh.
#
#   tclsh tests/headless/test_library_git_history.tcl

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}
proc val {body} { if {[catch {uplevel 1 $body} r]} { return {__ERR__ 1} } ; return $r }

set here [file dirname [file normalize [info script]]]
set gitlib [file normalize [file join $here .. .. src library_git.tcl]]
if {[file exists $gitlib]} { source $gitlib }

proc touch {f txt} { file mkdir [file dirname $f]; set fp [open $f w]; puts -nonewline $fp $txt; close $fp }
proc ginit {repo} {
  exec git init -q $repo
  exec git -C $repo config user.email test@example.com
  exec git -C $repo config user.name  Tester
  exec git -C $repo config commit.gpgsign false
}
# nth record's field
proc rfield {recs n key} {
  if {$n >= [llength $recs]} { return "<none>" }
  set r [lindex $recs $n]
  if {[catch {dict get $r $key} v]} { return "<nokey>" }
  return $v
}

set tmpbase [expr {[info exists env(TMPDIR)] && $env(TMPDIR) ne {} ? $env(TMPDIR) : "/tmp"}]
set tmp [file join $tmpbase _libgithist_[pid]]
file delete -force $tmp
file mkdir $tmp

# a bigger repo with two libraries; commits scoped to each
set big [file join $tmp big]
touch $big/libs/devices/and2/symbol/and2.sym       "v {and2 sym v1}\n"
touch $big/libs/examples/test1/schematic/test1.sch "v {test1 sch}\n"
ginit $big
exec git -C $big add -A
exec git -C $big commit -q -m "first commit"
set and2 [file join $big libs devices and2 symbol and2.sym]
touch $and2 "v {and2 sym v2}\n"
exec git -C $big add -- libs/devices/and2/symbol/and2.sym
# multi-paragraph message: subject + body (two body lines)
exec git -C $big commit -q -m "second subject" -m "body line one\nbody line two"
# a commit touching the OTHER library only (must not show in and2 history)
touch $big/libs/examples/test1/schematic/test1.sch "v {test1 sch v2}\n"
exec git -C $big commit -q -m "examples-only change" -- libs/examples

set root [file normalize $big]
set recs [val {lib_git_log_records $root {libs/devices/and2/symbol/and2.sym}}]

# === structure ==============================================================
check "HR1 two commits touch the and2 datafile" [expr {[llength $recs] == 2}] "(=> [llength $recs])"
check "HR2 newest commit first (subject)" [expr {[rfield $recs 0 subject] eq "second subject"}] "(=> [rfield $recs 0 subject])"
check "HR3 older commit second (subject)" [expr {[rfield $recs 1 subject] eq "first commit"}] "(=> [rfield $recs 1 subject])"

# === per-commit fields ======================================================
check "HR4 full 40-hex hash" [regexp {^[0-9a-f]{40}$} [rfield $recs 0 hash]] "(=> [rfield $recs 0 hash])"
check "HR5 short hash is a prefix of the full hash" [string match "[rfield $recs 0 short]*" [rfield $recs 0 hash]] "(=> [rfield $recs 0 short])"
check "HR6 date is YYYY-MM-DD HH:MM" [regexp {^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$} [rfield $recs 0 date]] "(=> [rfield $recs 0 date])"
check "HR7 author captured" [expr {[rfield $recs 0 author] eq "Tester"}] "(=> [rfield $recs 0 author])"

# === multiline body =========================================================
set body [rfield $recs 0 body]
check "HR8 body carries both lines" [expr {[string match "*body line one*" $body] && [string match "*body line two*" $body]}] "(=> [string map {\n { | }} $body])"
check "HR9 subject not duplicated into body" [expr {![string match "*second subject*" $body]}] "(=> [string map {\n { | }} $body])"

# === scoping + graceful ====================================================
set erecs [val {lib_git_log_records $root {libs/examples}}]
check "HR10 examples history has the examples-only commit" [expr {[string match "*examples-only change*" [rfield $erecs 0 subject]]}] "(=> [rfield $erecs 0 subject])"
check "HR11 and2 history excludes the examples-only commit" [expr {
  [lsearch -exact [list [rfield $recs 0 subject] [rfield $recs 1 subject]] "examples-only change"] < 0}] {}
check "HR12 not-under-git returns empty list" [expr {[val {lib_git_log_records "" {x}}] eq ""}] "(=> [val {lib_git_log_records "" {x}}])"

file delete -force $tmp
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
