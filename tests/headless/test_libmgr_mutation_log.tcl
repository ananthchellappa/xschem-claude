# Action-log coverage -- Library Manager MUTATIONS record replayable lines
# (issue 0064, issue 0071 atom 7).
#
# The 14 mutating libmgr::do_* workers (the dialog-free seam of
# src/library_manager.tcl) each log their own call line on the SUCCESS arm
# only, built with [list] for brace/newline safety:
#     xschem log_action [list libmgr::do_<op> <args...>]
# so a ctx_* dialog Cancel (which diverts before do_*) and a caught backend
# error leave no line. Replay = re-source the log: the do_* procs are defined
# unconditionally at startup and are headless-safe (refresh_after early-returns
# without .libmgr, libmgr::status is catch-guarded).
#
# Covered here:
#   - every filesystem worker (new/copy/rename/delete cell+view, new_library,
#     unregister) logs EXACTLY once on success
#   - git workers (checkout, checkin, checkin_lib, cancel_checkout) log exactly
#     once on success (SKIPped when git is not installed)
#   - backend errors (duplicate cell, missing cell, clean-tree/empty-message
#     checkin) log NOTHING
#   - ctx_* dialog-Cancel arms log NOTHING -- proven with COUNTING stubs
#     (a bare `return`-stub would mask a dead handler, atom-3 finding)
#   - a commit message with braces + a newline stays source-able (the logged
#     segment satisfies `info complete`) and REPLAYS: re-eval commits with the
#     exact message
#   - replay smoke: re-eval the logged do_new_cell line -> cell back on disk
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_libmgr_mutation_log.tcl

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} { incr ::fails }
}

set LOG [xschem get actionlog_filename]
if {$LOG eq {}} {
  puts "SKIP: no action log open -- run with --logdir"
  puts "RESULT: SKIP (no log)"
  exit 0
}
# Display-less box: Tk never loads, so the tk_messageBox rename in the ctx-stub
# section would be an invalid-command CRASH, not a skip (atom-8 review) --
# self-skip like every other GUI test.
if {[info commands winfo] eq {}} {
  puts "SKIP: no Tk (display-less session)"
  puts "RESULT: SKIP (no Tk)"
  exit 0
}

set REPO [file normalize [file join [file dirname [info script]] .. ..]]
set work /tmp/atom7_libmgr_mutation_log_work.[pid]
file delete -force $work; file mkdir $work

# count log lines matching a glob pattern; no-wildcard pattern = exact line
proc logtext {} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  return $b
}
proc logcountf {f pat} {
  if {[catch {open $f r} fd]} { return -1 }
  set b [read $fd]; close $fd
  set n 0
  foreach l [split $b \n] { if {[string match $pat $l]} { incr n } }
  return $n
}
proc logcount {pat} { return [logcountf [xschem get actionlog_filename] $pat] }

# ---------------------------------------------------------------------------
# fixture: a private nested library + its own library.defs
# ---------------------------------------------------------------------------
proc mkcell {f} {
  file mkdir [file dirname $f]
  set fp [open $f w]
  puts $fp "v {xschem version=test file_version=1.3}"
  foreach r {G K V S E} { puts $fp "$r \{\}" }
  close $fp
}
set LIB $work/t7lib
mkcell $LIB/foo/schematic/foo.sch
mkcell $LIB/foo/symbol/foo.sym
mkcell $LIB/bar/schematic/bar.sch
set defs [file join $work library.defs]
set fp [open $defs w]; puts $fp "DEFINE t7lib $LIB"; close $fp
set ::XSCHEM_LIBRARY_DEFS $defs
check "F0 fixture library registered" \
  [expr {[library_resolve t7lib] ne {}}] "path=[library_resolve t7lib]"

# git fixture: the library dir IS the repo root (standalone-lib case A)
set HAVEGIT [expr {[lsearch -exact [lib_git_available] git] >= 0}]
if {$HAVEGIT} {
  catch {exec git init $LIB} initout
  catch {exec git -C $LIB config user.email atom7@test}
  catch {exec git -C $LIB config user.name atom7}
  catch {exec git -C $LIB config commit.gpgsign false}
  set gitok [file isdirectory $LIB/.git]
  if {$gitok} {
    catch {exec git -C $LIB add -A}
    set gitok [expr {![catch {exec git -C $LIB commit -m init} e]}]
    if {!$gitok} { set initout $e }
  }
  if {!$gitok} { set HAVEGIT 0 }
  check "F1 git fixture repo built" $gitok "[string range $initout 0 100]"
  lib_git_reset_cache
} else {
  puts "note: git not installed -- git sections will be skipped"
}

# ---------------------------------------------------------------------------
# 1) filesystem workers: success logs EXACTLY once, effect lands on disk
# ---------------------------------------------------------------------------
proc once {name line body} {
  set c0 [logcount $line]
  set rc [uplevel 1 $body]
  check "$name returns 1" [expr {$rc == 1}] "rc=$rc"
  check "$name logs exactly +1" [expr {[logcount $line] == $c0 + 1}] \
    "line={$line} c0=$c0 now=[logcount $line]"
}

once "T1 do_new_cell" {libmgr::do_new_cell t7lib zz1} \
  {libmgr::do_new_cell t7lib zz1}
check "T1 new cell on disk" [file isfile $LIB/zz1/schematic/zz1.sch]

once "T2 do_new_view" {libmgr::do_new_view t7lib foo altv symbol} \
  {libmgr::do_new_view t7lib foo altv symbol}
check "T2 new view on disk" [file isfile $LIB/foo/altv/foo.sym]

once "T3 do_copy_view" {libmgr::do_copy_view t7lib foo schematic t7lib foo vcopy} \
  {libmgr::do_copy_view t7lib foo schematic t7lib foo vcopy}
check "T3 copied view on disk" [file isfile $LIB/foo/vcopy/foo.sch]

once "T4 do_rename_view" {libmgr::do_rename_view t7lib foo vcopy vren} \
  {libmgr::do_rename_view t7lib foo vcopy vren}
check "T4 renamed view on disk" [expr {[file isfile $LIB/foo/vren/foo.sch] \
  && ![file isdirectory $LIB/foo/vcopy]}]

once "T5 do_delete_view" {libmgr::do_delete_view t7lib foo vren} \
  {libmgr::do_delete_view t7lib foo vren}
check "T5 deleted view trashed" [expr {![file isdirectory $LIB/foo/vren]}]

once "T6 do_copy_cell" {libmgr::do_copy_cell t7lib foo t7lib cc1} \
  {libmgr::do_copy_cell t7lib foo t7lib cc1}
check "T6 copied cell on disk" [file isfile $LIB/cc1/schematic/cc1.sch]

once "T7 do_rename_cell" {libmgr::do_rename_cell t7lib cc1 t7lib cc2} \
  {libmgr::do_rename_cell t7lib cc1 t7lib cc2}
check "T7 renamed cell on disk" [expr {[file isfile $LIB/cc2/schematic/cc2.sch] \
  && ![file isdirectory $LIB/cc1]}]

once "T8 do_delete_cell" {libmgr::do_delete_cell t7lib cc2} \
  {libmgr::do_delete_cell t7lib cc2}
check "T8 deleted cell trashed" [expr {![file isdirectory $LIB/cc2]}]

once "T9 do_new_library (default {} path logged as given)" \
  {libmgr::do_new_library n7lib {}} {libmgr::do_new_library n7lib {}}
check "T9 new library dir on disk" [file isdirectory $work/n7lib]
check "T9 new library registered" [expr {[library_resolve n7lib] ne {}}]

once "T10 do_unregister" {libmgr::do_unregister n7lib} \
  {libmgr::do_unregister n7lib}
check "T10 library unregistered" [expr {[library_resolve n7lib] eq {}}]

# ---------------------------------------------------------------------------
# 2) backend errors: return 0, log NOTHING
# ---------------------------------------------------------------------------
proc silent {name globpat body} {
  set c0 [logcount $globpat]
  set rc [uplevel 1 $body]
  check "$name returns 0" [expr {$rc == 0}] "rc=$rc"
  check "$name logs nothing" [expr {[logcount $globpat] == $c0}] \
    "c0=$c0 now=[logcount $globpat]"
}
silent "E1 duplicate do_new_cell" {libmgr::do_new_cell t7lib zz1} \
  {libmgr::do_new_cell t7lib zz1}
silent "E2 do_delete_cell of a missing cell" {libmgr::do_delete_cell t7lib nosuch*} \
  {libmgr::do_delete_cell t7lib nosuch}
silent "E3 do_copy_view onto an existing view" \
  {libmgr::do_copy_view t7lib foo schematic t7lib foo symbol} \
  {libmgr::do_copy_view t7lib foo schematic t7lib foo symbol}

# ---------------------------------------------------------------------------
# 3) ctx_* dialog arms with COUNTING stubs: Cancel logs nothing, OK logs once.
#    The ctx handlers used here read only libmgr namespace vars (no .libmgr
#    window needed); the counters prove each stub was actually consulted.
# ---------------------------------------------------------------------------
set libmgr::sel_lib t7lib
set libmgr::sel_cell zz1
array set ::stubn {msgbox 0 commit 0 prompt 0}
set ::stub_msgbox_ans no
rename tk_messageBox ::atom7_orig_msgbox
proc tk_messageBox {args} { incr ::stubn(msgbox); return $::stub_msgbox_ans }
rename libmgr::commit_dialog ::atom7_orig_commit
proc libmgr::commit_dialog {title} { incr ::stubn(commit); return {} }
rename libmgr::simple_prompt ::atom7_orig_prompt
proc libmgr::simple_prompt {title label {default {}}} { incr ::stubn(prompt); return {} }

set c0 [logcount {libmgr::do_delete_cell t7lib zz1}]
libmgr::ctx_delete_cell
check "C1 delete-cell Cancel consulted the confirm box" [expr {$::stubn(msgbox) == 1}] \
  "n=$::stubn(msgbox)"
check "C1 delete-cell Cancel logs nothing" \
  [expr {[logcount {libmgr::do_delete_cell t7lib zz1}] == $c0}]

set c0 [logcount {libmgr::do_checkin t7lib zz1*}]
libmgr::ctx_checkin_cell
check "C2 check-in Cancel consulted the commit dialog" [expr {$::stubn(commit) == 1}] \
  "n=$::stubn(commit)"
check "C2 check-in Cancel logs nothing" \
  [expr {[logcount {libmgr::do_checkin t7lib zz1*}] == $c0}]

set c0 [logcount {libmgr::do_new_cell t7lib*}]
libmgr::ctx_new_cell
check "C3 new-cell Cancel consulted the prompt" [expr {$::stubn(prompt) == 1}] \
  "n=$::stubn(prompt)"
check "C3 new-cell Cancel logs nothing" \
  [expr {[logcount {libmgr::do_new_cell t7lib*}] == $c0}]

# OK arm through the same ctx wire: confirm "yes" -> do_delete_cell -> one line
set ::stub_msgbox_ans yes
set c0 [logcount {libmgr::do_delete_cell t7lib zz1}]
libmgr::ctx_delete_cell
check "C4 delete-cell confirm consulted the box again" [expr {$::stubn(msgbox) == 2}]
check "C4 delete-cell OK logs exactly +1" \
  [expr {[logcount {libmgr::do_delete_cell t7lib zz1}] == $c0 + 1}]
check "C4 delete-cell OK deleted on disk" [expr {![file isdirectory $LIB/zz1]}]

rename tk_messageBox {}; rename ::atom7_orig_msgbox tk_messageBox
rename libmgr::commit_dialog {}; rename ::atom7_orig_commit libmgr::commit_dialog
rename libmgr::simple_prompt {}; rename ::atom7_orig_prompt libmgr::simple_prompt

# ---------------------------------------------------------------------------
# 4) git workers (skipped without git)
# ---------------------------------------------------------------------------
set CIMSG "fix {braced} thing\nsecond line of the message"
if {$HAVEGIT} {
  once "G1 do_checkout (cell-level, default view logged as {})" \
    {libmgr::do_checkout t7lib bar {}} {libmgr::do_checkout t7lib bar}
  check "G1 checkout marker recorded" \
    [file isfile $LIB/.git/xschem_lib_checkouts]

  # backend-error arms first, on the clean tree: no line
  silent "G2 do_checkin with an EMPTY message" {libmgr::do_checkin t7lib bar*} \
    {libmgr::do_checkin t7lib bar {} {}}
  silent "G3 do_checkin with nothing to commit" {libmgr::do_checkin t7lib bar*} \
    {libmgr::do_checkin t7lib bar {} {clean tree msg}}

  # a real check-in with a brace+newline message: logs once, stays source-able.
  # The expected logged string is the [list]-built call itself; its first
  # physical line is the match prefix (a literal unbalanced open-brace here
  # would break the enclosing if-body's brace parse, so derive it).
  set fp [open $LIB/bar/schematic/bar.sch a]; puts $fp "B {edit1}"; close $fp
  set lline [list libmgr::do_checkin t7lib bar {} $CIMSG]
  set pre [lindex [split $lline \n] 0]
  set c0 [logcount "$pre*"]
  set rc [libmgr::do_checkin t7lib bar {} $CIMSG]
  check "G4 do_checkin (multiline message) returns 1" [expr {$rc == 1}] "rc=$rc"
  check "G4 do_checkin logs exactly +1 (first physical line)" \
    [expr {[logcount "$pre*"] == $c0 + 1}]
  check "G4 committed message is verbatim" \
    [expr {[string trim [exec git -C $LIB log -1 --format=%B]] eq $CIMSG}]
  # the logged SEGMENT (line + continuation) is a complete Tcl command
  set seg {}
  foreach l [split [logtext] \n] {
    if {$seg eq {} && ![string match "$pre*" $l]} continue
    append seg $l
    if {[info complete "$seg\n"]} break
    append seg \n
  }
  check "G4 logged segment is a complete sourceable command" \
    [expr {$seg ne {} && [info complete "$seg\n"] && [llength $seg] == 5}] \
    "seg={$seg}"
  check "G4 segment carries the message verbatim" \
    [expr {[lindex $seg 4] eq $CIMSG}]

  # cancel-checkout: destructive revert to HEAD, logs once
  set head [exec git -C $LIB show HEAD:bar/schematic/bar.sch]
  set fp [open $LIB/bar/schematic/bar.sch a]; puts $fp "B {scratch}"; close $fp
  once "G5 do_cancel_checkout" {libmgr::do_cancel_checkout t7lib bar {}} \
    {libmgr::do_cancel_checkout t7lib bar}
  set fp [open $LIB/bar/schematic/bar.sch r]; set now [read $fp]; close $fp
  check "G5 datafile rolled back to HEAD" \
    [expr {[string trim $now] eq [string trim $head]}]

  # library-level check-in sweeps the pending edit under the lib pathspec
  set fp [open $LIB/foo/schematic/foo.sch a]; puts $fp "B {edit2}"; close $fp
  once "G6 do_checkin_lib" {libmgr::do_checkin_lib t7lib {lib sweep msg}} \
    {libmgr::do_checkin_lib t7lib {lib sweep msg}}
  check "G6 sweep committed the pending edit" \
    [expr {[string trim [exec git -C $LIB status --porcelain -- foo]] eq {}}]
} else {
  puts "note: G1-G6 git checks skipped (no git on PATH)"
}

# ---------------------------------------------------------------------------
# 5) REPLAY smoke: re-eval logged lines in-process
# ---------------------------------------------------------------------------
# 5a) the do_new_cell line from T1 (cell was deleted again in C4)
set line {}
foreach l [split [logtext] \n] {
  if {[string match {libmgr::do_new_cell t7lib zz1} $l]} { set line $l; break }
}
check "R1 do_new_cell line found in the log" [expr {$line ne {}}]
if {$line ne {}} {
  set rc [eval $line]
  check "R1 replayed do_new_cell succeeds" [expr {$rc == 1}] "rc=$rc"
  check "R1 replayed cell back on disk" [file isfile $LIB/zz1/schematic/zz1.sch]
}
# 5b) the multiline do_checkin segment from G4, against a fresh pending edit
if {$HAVEGIT && [info exists seg] && $seg ne {}} {
  set fp [open $LIB/bar/schematic/bar.sch a]; puts $fp "B {edit3}"; close $fp
  set rc [eval $seg]
  check "R2 replayed multiline do_checkin succeeds" [expr {$rc == 1}] "rc=$rc"
  check "R2 replayed commit message verbatim" \
    [expr {[string trim [exec git -C $LIB log -1 --format=%B]] eq $CIMSG}]
}

# ---------------------------------------------------------------------------
# 6) --nogui child: the do_* seam records AND replays with NO Tk loaded.
#    Atom-7 review finding: refresh_after's bare `winfo` was an ERROR (not a
#    false) without Tk, and it fired AFTER the backend mutation -- so a
#    display-less session mutated disk, wrote NO line, and a log replay
#    aborted mid-file. Locks the [info commands winfo] headless guard.
#    (--script bodies are not auto-logged, so the line asserted below can only
#    come from do_new_cell's own seam log_action.)
# ---------------------------------------------------------------------------
set XSCHEM [file join $REPO src xschem]
set nglib $work/nglib
mkcell $nglib/seed/schematic/seed.sch
set ngdefs [file join $work ng_library.defs]
set fp [open $ngdefs w]; puts $fp "DEFINE nglib $nglib"; close $fp
set childscript $work/ng_child.tcl
set fp [open $childscript w]
puts $fp "set ::XSCHEM_LIBRARY_DEFS [list $ngdefs]"
puts $fp {set rc [catch {libmgr::do_new_cell nglib ngcell} ret]}
puts $fp "set fp \[open [list $work/ng_rc] w\]; puts \$fp \[list \$rc \$ret\]; close \$fp"
puts $fp {exit 0}
close $fp
set nglogdir $work/ng_logdir; file mkdir $nglogdir
catch {exec $XSCHEM --nogui --pipe -q --logdir $nglogdir --script $childscript \
         < /dev/null > $work/ng.out 2> $work/ng.err}
set nglog [file join $nglogdir Xschem.log]
check "N1 --nogui child ran and wrote a log" [file exists $nglog]
set ngres {1 unread}
catch {set fp [open $work/ng_rc r]; set ngres [string trim [read $fp]]; close $fp}
check "N2 do_new_cell survived with no Tk and returned 1 (headless guard)" \
  [expr {$ngres eq {0 1}}] "catch,ret=$ngres"
check "N3 cell created on disk by the --nogui child" \
  [file isfile $nglib/ngcell/schematic/ngcell.sch]
check "N4 seam line recorded in the --nogui log" \
  [expr {[logcountf $nglog {libmgr::do_new_cell nglib ngcell}] == 1}] \
  "n=[logcountf $nglog {libmgr::do_new_cell nglib ngcell}]"

file delete -force $work
catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
