# test_perform_action_image.tcl -- Refactor B atom 20 (perform_action / image), audit §40.
#
# The `image` verb -- `xschem image [invert|white_transp|black_transp|transp_white|transp_black|
# blend_white|blend_black|write_back]` -- applies pixel transforms to the SELECTED GRIDLAYER image
# rects (flags&1024) via edit_image (draw.c, `#if HAS_CAIRO==1`). Atom 20 is the FIRST HAS_CAIRO-gated
# migration and the first verb with a read-only-SAFE QUERY sub-form, so it is a QUERY/MUTATE SPLIT
# (the wire_cut §37 form-split applied to a query vs a mutation):
#
#   - The scheduler branch keeps ONLY the two pre-mutation, read-only-safe replies IN FRONT of the
#     boundary: `image help` (a static usage string -> TCL_OK) and the argc<3 "Missing arguments"
#     validation. Routing either through perform_action would REFUSE it on a read-only cell, because
#     the boundary's ONE readonly gate (scheduler.c:1031) is unconditional per-verb -- the
#     read-only-safe-query OVER-REJECT the atom-19 handoff flagged. So they stay raw.
#   - Everything past help routes: `return perform_action("image", argc, argv)`. run_core holds the
#     `No images selected` precondition (a MUTATION precondition, NOT a query -- it stays below the
#     boundary so a read-only cell refuses first), the flag parse, and the `if(what)` block
#     (rebuild_selected_array, set_modify(1) ONLY on write_back, the SINGLE push_undo, the edit_image
#     loop, draw). core_log_action logs the FAITHFUL RAW full call `xschem image <flag>...` via a
#     fresh heap array `im` copied VERBATIM from argv (RAW, not canonical-from-`what`, so a what==0
#     no-op like `image foo` round-trips to the same no-op on replay instead of collapsing to a bare
#     `xschem image` that replays as "Missing arguments").
#
# CORRECTNESS FIX: the branch NEVER had a readonly gate -- pre-migration `image invert` MUTATED a
# read-only cell (pinned on the frozen binary). The boundary ADDS the gate; `image help` stays
# read-only-safe (it returns in the branch, never reaching the boundary).
#
# run under the action log:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) --script tests/headless/test_perform_action_image.tcl
# registered in full_audit.sh logdir_tests. doc/claude/code_analysis §40.

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} { incr ::fails }
}

# HAS_CAIRO defer: on a no-cairo build the whole `image` branch is #if HAS_CAIRO==1, so the
# dispatcher returns "xschem image: invalid command.". Defer ONLY on that exact no-cairo signal --
# NOT on any error -- so a regression that broke `image help` (e.g. routing it through the boundary,
# losing the read-only-safe split) does NOT mask itself as a defer; it proceeds and (b) catches it.
set _hprobe {}
catch {xschem image help} _hprobe
if {[string match {*invalid command*} $_hprobe]} {
  puts "deferred (no-cairo build: the `image` verb + edit_image are #if HAS_CAIRO==1)"
  puts "RESULT: ALL PASS"
  flush stdout
  exit 0
}

# The boundary's log site is only observable with the log open. full_audit registers this in
# logdir_tests so LOG is always set in the real run; the guard keeps a bare invocation from erroring.
set LOG [xschem get actionlog_filename]
if {$LOG eq {}} {
  puts "deferred (no --logdir; the perform_action log site needs an open action log)"
  puts "RESULT: ALL PASS"
  flush stdout
  exit 0
}

set REPO [file normalize [file join [file dirname [info script]] .. ..]]
set FIX  [file join $REPO tests headless fixtures image image_embedded.sch]
check "fixture present: image_embedded.sch (self-contained embedded image_data)" [file exists $FIX] "path=$FIX"

# image_data attribute of the sole GRIDLAYER (color 2) image rect
proc attr {} { return [xschem getprop rect 2 0 image_data] }
# ANY `xschem image*` line -- to prove a FAILED/no-op call logs the right count.
proc imc {} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0
  foreach l [split $b \n] { if {[string match {xschem image*} $l]} { incr n } }
  return $n
}
# lines exactly matching a pattern
proc impat {pat} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0
  foreach l [split $b \n] { if {[string match $pat $l]} { incr n } }
  return $n
}
# Fixture load + select the image rect. `saveas`/`load` CLEAR the selection, so EVERY image op
# re-selects first (the verb needs lastsel>0; without it -> "No images selected").
proc load_sel {} {
  global FIX
  xschem load $FIX
  xschem set readonly 0
  xschem select_all
}

# ---------------------------------------------------------------------------
# (a) SUCCESS: a write_back transform mutates image_data, logs exactly +1 faithful line, the logged
#     line is byte-exact `xschem image invert write_back`, and the interp result is BLANK.
# ---------------------------------------------------------------------------
load_sel
check "(a) fixture: one selected GRIDLAYER image rect (lastsel=1, flags=image round-trips)" \
  [expr {[xschem get lastsel] == 1 && [xschem get rects 2] >= 1}] "lastsel=[xschem get lastsel] gridrects=[xschem get rects 2]"
set a0 [attr]; set c0 [imc]
set r [xschem image invert write_back]
check "(a) mutate -> image_data changed" [expr {[attr] ne $a0}] "unchanged=[expr {[attr] eq $a0}]"
check "(a) mutate -> exactly +1 log line" [expr {[imc] == $c0 + 1}] "c0=$c0 now=[imc]"
check "(a) logged line is byte-exact 'xschem image invert write_back'" \
  [expr {[impat {xschem image invert write_back}] == 1}] "count=[impat {xschem image invert write_back}]"
check "(a) RESULT BLANK: the boundary blanks the incidental interp leak on success" [expr {$r eq ""}] "r=>$r<"

# (a2) MULTI-FLAG faithfulness: all flag words log verbatim, in the typed order (barewords -> Tcl_Merge
#      logs them unbraced == byte-identical), and the line replays.
load_sel
xschem image blend_white write_back
check "(a2) multi-flag call logs the flags verbatim 'xschem image blend_white write_back'" \
  [expr {[impat {xschem image blend_white write_back}] == 1}] "count=[impat {xschem image blend_white write_back}]"

# ---------------------------------------------------------------------------
# (b) help is READ-ONLY-SAFE (the query/mutate split): returns TCL_OK + usage even on a read-only
#     cell, and logs NOTHING (it returns in the branch, never reaching the boundary log site).
# ---------------------------------------------------------------------------
xschem load $FIX
xschem set readonly 1
set hc [imc]
set hrc [catch {xschem image help} h]
check "(b) image help -> TCL_OK + usage string (read-only-safe: works with readonly=1)" \
  [expr {$hrc == 0 && [string match {xschem image*} $h]}] "rc=$hrc h=>$h<"
check "(b) image help logs NOTHING (returns in the branch, before the boundary)" [expr {[imc] == $hc}] "hc=$hc now=[imc]"

# ---------------------------------------------------------------------------
# (c) READ-ONLY REFUSE (the correctness fix): with the cell read-only, a mutating `image invert
#     write_back` is REFUSED (TCL_ERROR, verb-named message), mutates NOTHING, and logs NOTHING.
#     (Pre-migration this MUTATED -- pinned on the frozen binary.)
# ---------------------------------------------------------------------------
xschem load $FIX
xschem set readonly 1
xschem select_all
set b0 [attr]; set rc0 [imc]
set rc [catch {xschem image invert write_back} e]
check "(c) read-only mutate -> REFUSED (TCL_ERROR)" [expr {$rc == 1}] "rc=$rc"
check "(c) read-only refuse -> verb-named read-only message" [string match {*read-only*} $e] "e=>$e<"
check "(c) read-only refuse -> image_data UNCHANGED (no mutation)" [expr {[attr] eq $b0}] "changed=[expr {[attr] ne $b0}]"
check "(c) read-only refuse -> logs NOTHING (log-on-success)" [expr {[imc] == $rc0}] "rc0=$rc0 now=[imc]"

# ---------------------------------------------------------------------------
# (d) set_modify ONLY on write_back: a plain `image invert` (no write_back) mutates the in-memory
#     surface but leaves modified==0; `image invert write_back` sets modified==1.
# ---------------------------------------------------------------------------
load_sel
xschem image invert
check "(d) image invert (no write_back) -> modified == 0" [expr {[xschem get modified] == 0}] "modified=[xschem get modified]"
load_sel
xschem image invert write_back
check "(d) image invert write_back -> modified == 1" [expr {[xschem get modified] == 1}] "modified=[xschem get modified]"

# ---------------------------------------------------------------------------
# (e) undo is a SINGLE push: one undo restores the pre-transform image_data.
# ---------------------------------------------------------------------------
load_sel
set e0 [attr]
xschem image invert write_back
check "(e) transform changed image_data (pre-undo)" [expr {[attr] ne $e0}] "unchanged=[expr {[attr] eq $e0}]"
xschem undo
check "(e) ONE undo restores image_data (single push_undo)" [expr {[attr] eq $e0}] "restored=[expr {[attr] eq $e0}]"

# ---------------------------------------------------------------------------
# (f) what==0 NO-OP (an unrecognized flag word): TCL_OK, mutates nothing, sets modified nothing,
#     and STILL logs +1 (the §30 no-op-still-logs property) as the RAW faithful `xschem image
#     bogusflag` -- which replays to the SAME no-op (a canonical rebuild would log a bare
#     `xschem image` that replays as "Missing arguments").
# ---------------------------------------------------------------------------
load_sel
set f0 [attr]; set fc [imc]
set frc [catch {xschem image bogusflag} fe]
check "(f) what=0 no-op -> TCL_OK (not an error)" [expr {$frc == 0}] "rc=$frc e=>$fe<"
check "(f) what=0 no-op -> image_data UNCHANGED" [expr {[attr] eq $f0}] "changed=[expr {[attr] ne $f0}]"
check "(f) what=0 no-op -> modified == 0 (no push, no write_back)" [expr {[xschem get modified] == 0}] "modified=[xschem get modified]"
check "(f) what=0 no-op -> STILL logs +1 (no-op-still-logs)" [expr {[imc] == $fc + 1}] "fc=$fc now=[imc]"
check "(f) what=0 no-op -> RAW faithful line 'xschem image bogusflag' (replays to a no-op)" \
  [expr {[impat {xschem image bogusflag}] == 1}] "count=[impat {xschem image bogusflag}]"

# ---------------------------------------------------------------------------
# (g) `No images selected`: editable cell, NOTHING selected -> TCL_ERROR (a mutation precondition,
#     below the boundary), and logs NOTHING (log-on-success).
# ---------------------------------------------------------------------------
xschem load $FIX
xschem set readonly 0
xschem unselect_all
set gc [imc]
set grc [catch {xschem image invert} ge]
check "(g) nothing selected -> TCL_ERROR" [expr {$grc == 1}] "rc=$grc"
check "(g) nothing selected -> 'No images selected' message" [string match {*No images selected*} $ge] "e=>$ge<"
check "(g) nothing selected -> logs NOTHING (failed precondition, log-on-success)" [expr {[imc] == $gc}] "gc=$gc now=[imc]"

# ---------------------------------------------------------------------------
# (h) REPLAY round-trip: the logged `xschem image invert write_back` re-applied to a fresh selected
#     fixture reproduces the SAME image_data (edit_image is deterministic given the same input).
# ---------------------------------------------------------------------------
load_sel
xschem image invert write_back
set recorded [attr]
load_sel
xschem image invert write_back
check "(h) replay faithful: re-applying the logged line reproduces the same image_data" \
  [expr {[attr] eq $recorded}] "recorded==replayed=[expr {[attr] eq $recorded}]"

# ---------------------------------------------------------------------------
# (i) argc<3 "Missing arguments" -- the OTHER read-only-safe raw-front reply (kept in the branch IN
#     FRONT of the boundary, like help). Bare `xschem image` -> TCL_ERROR + logs NOTHING; a regression
#     that routed argc<3 through perform_action would refuse it as read-only (or phantom-log) instead.
# ---------------------------------------------------------------------------
load_sel
set ic [imc]
set irc [catch {xschem image} ie]
check "(i) bare `xschem image` (argc<3) -> TCL_ERROR" [expr {$irc == 1}] "rc=$irc"
check "(i) argc<3 -> 'Missing arguments' message (raw-front validation, not the boundary)" \
  [string match {*Missing arguments*} $ie] "e=>$ie<"
check "(i) argc<3 -> logs NOTHING (a raw-front reply never reaches the boundary log site)" \
  [expr {[imc] == $ic}] "ic=$ic now=[imc]"

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
