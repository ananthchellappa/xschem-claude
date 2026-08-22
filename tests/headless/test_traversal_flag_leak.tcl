# Issue 0600 - `proc traversal` must not leak keep_symbols / no_draw / no_undo
# when its body raises.
#
# src/xschem.tcl (pre-fix :3572-3576) sets all three; (pre-fix :3596-3598) restores
# them on the NORMAL path only - no catch, no finally. The cheapest raise needs no
# error injection at all: `toplevel .trav` raises
#   window name ".trav" already exists in parent
# whenever a previous traversal window is still open, and .trav is destroyed only
# by the <Escape> binding, by the Upd button or by the WM's default delete handler -
# none of which a second scripted call performs. So: call traversal, leave its
# window up, call it again -> the second call sets the three flags, raises at
# `toplevel .trav`, and never reaches the restore.
#
# no_undo has NO getter (scheduler.c:12030 is a setter only; `xschem get no_undo`
# does not exist), so it is witnessed BEHAVIOURALLY: push_undo (save.c:4713) and
# pop_undo (save.c:4795) both return immediately when xctx->no_undo is set, so a
# leaked no_undo makes `xschem undo` a silent no-op.
#
# NEEDS A DISPLAY. `toplevel` is Tk; do NOT run this under --nogui. Run it as:
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --script \
#       tests/headless/test_traversal_flag_leak.tcl
# full_audit.sh's default arm (--pipe -q --nolog --script, full_audit.sh:448) is
# already the right one - do not add this suite to its nogui_tests list.

if {[catch {winfo exists .}]} {
  puts "RESULT: SKIP (needs Tk/X; `toplevel .trav` is the raise trigger)"
  flush stdout
  exit 0
}

# --- issue 0601: keep the editor's autosave "~" file out of the launch directory ---
# This suite edits the startup UNTITLED buffer (undo_works below instances a
# resistor), and the FIRST edit runs set_modify(1) -> write_backup()
# (src/actions.c:208 -> src/save.c:4149), dropping `untitled~.sch` into the
# directory the suite was LAUNCHED from -- the repo root under
# tests/headless/full_audit.sh:64, which does `cd "$REPO"`. A Tcl `cd` does not
# move it (pwd_dir, src/xinit.c:2952/174, issue 0323). write_backup() returns
# early when autosave_backup is off (src/save.c:4156). Same guard as
# tests/headless/test_undo_selection.tcl:24-25. Guarded by
# tests/headless/test_no_untitled_litter.tcl.
set ::saved_autosave_0601 $::autosave_backup
set ::autosave_backup 0

set fail 0
set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail"; incr npass } \
  else     { puts "FAIL: $name $detail"; incr fail }
}

# Behavioural witness for no_undo, which has no getter: make one undoable edit
# and undo it. Returns 1 if undo actually reverted the edit (no_undo == 0),
# 0 if the undo was a silent no-op (no_undo == 1), -1 if the edit itself failed.
# Deliberately does NOT touch no_undo itself - that is the thing under test.
proc undo_works {} {
  xschem clear force schematic
  xschem instance res.sym 0 0 0 0 {name=R1 value=1k}
  update idletasks
  xschem setprop instance R1 value 30k     ;# push_undo (no-op under no_undo)
  if {![string match {*value=30k*} [xschem getprop instance R1]]} { return -1 }
  xschem undo                              ;# pop_undo  (no-op under no_undo)
  update idletasks
  return [expr {[string match {*value=1k*} [xschem getprop instance R1]] ? 1 : 0}]
}

# --- baseline: all three flags at a known, non-default-ambiguous value --------
catch {destroy .trav}
set ::keep_symbols 0
xschem set no_draw 0
xschem set no_undo 0
xschem clear force schematic
update idletasks
set base_level [xschem get currsch]

# --- CONTROL: the NORMAL path already restores all three ----------------------
# (proves the baseline and the witnesses are sound, so the leak legs below
# cannot pass or fail for some unrelated reason.)
set rcA [catch {traversal} resA]
check "control: a normal traversal call returns cleanly" [expr {$rcA == 0}] "(rc=$rcA $resA)"
check "control: normal path restores keep_symbols" [expr {$::keep_symbols == 0}] "(keep_symbols=$::keep_symbols)"
check "control: normal path restores no_draw" [expr {[xschem get no_draw] == 0}] "(no_draw=[xschem get no_draw])"
check "control: normal path leaves undo working (no_undo==0)" [expr {[undo_works] == 1}] "(undo reverted the edit)"
check "control: normal path restores the hierarchy level" [expr {[xschem get currsch] == $base_level}] "(currsch=[xschem get currsch])"

# --- the trigger: the first window is still up, so the second call raises ------
check "precondition: .trav survives the first call (nothing destroys it)" \
  [winfo exists .trav] "(winfo exists .trav = [winfo exists .trav])"

xschem set no_draw 0
xschem set no_undo 0
set ::keep_symbols 0
set rcB [catch {traversal} resB]
check "the second traversal call RAISES at `toplevel .trav`" \
  [expr {$rcB == 1 && [string match {*already exists*} $resB]}] "(rc=$rcB {$resB})"

# --- the three flags must be back at their pre-call values --------------------
# PRE-FIX these three are the failures: keep_symbols=1, no_draw=1, undo a no-op.
check "0600 keep_symbols is restored after a raising traversal" \
  [expr {$::keep_symbols == 0}] "(keep_symbols=$::keep_symbols, expected 0)"
check "0600 no_draw is restored after a raising traversal" \
  [expr {[xschem get no_draw] == 0}] "(no_draw=[xschem get no_draw], expected 0)"
set uw [undo_works]
check "0600 no_undo is restored after a raising traversal (undo still works)" \
  [expr {$uw == 1}] "(undo_works=$uw, expected 1; -1 means the edit itself failed)"
check "0600 the hierarchy level is restored after a raising traversal" \
  [expr {[xschem get currsch] == $base_level}] "(currsch=[xschem get currsch], expected $base_level)"

# --- hygiene: leave the process as we found it --------------------------------
catch {destroy .trav}
set ::keep_symbols 0
xschem set no_draw 0
xschem set no_undo 0
set ::autosave_backup $::saved_autosave_0601   ;# issue 0601
update idletasks

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
