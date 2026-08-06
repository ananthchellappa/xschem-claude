# tests/headless/wvbs_common.tcl — the SHARED PRELUDE of the signal-browser
# test files (doc/claude/signal_browser_batch/PLAN.md items 8-15).
#
# ============================================================================
# WHY THIS FILE EXISTS — DRIVER RULING 30
# ============================================================================
# Settled decision 9 put items 8-15 in ONE file. At 489 checks that file was
# killed mid-run by WSLg with ZERO check failures (0 of 9 completions measured
# 2026-08-06), so every later item's verification became unmeasurable. Ruling 30
# REVISED decision 9: the browser checks are split BY ITEM RANGE across a small
# number of files, each still re-run whole by every later verifier.
#
#   tests/headless/test_wave_sigbrowser.tcl       items 8, 9, 10   BS BT BM
#   tests/headless/test_wave_sigbrowser_i11.tcl   item 11          BH
#   tests/headless/test_wave_sigbrowser_i12.tcl   item 12          BX
#   (items 13-15 create ONE more file; item 13 owns that decision)
#
# ⚠ THIS FILE IS NOT A TEST AND MUST NEVER BE NAMED `test_*.tcl`.
# `full_audit.sh` selects its cases with `ls "$HERE"/test_*.tcl`, so a shared
# prelude called `test_…` would be executed as a case, would run zero checks,
# would print no RESULT banner and would be scored FAIL forever. `scratch.tcl`
# and `harness.tcl` are the house precedent for a non-`test_` helper.
#
# ============================================================================
# WHAT IT CARRIES, AND WHY EACH PIECE IS HERE RATHER THAN DUPLICATED
# ============================================================================
# Item 8's header declared the conventions items 9-15 inherit. Duplicating them
# three times is how they drift; a common file is how they cannot. Everything
# below was previously defined ONCE in test_wave_sigbrowser.tcl and used by two
# or more items, so moving it here is a relocation, not a rewrite:
#
#   check / check_true      the scoring pair
#   pcall                   error-guarded call — a sabotage that makes the code
#                           under test THROW must fail ONE check, not abort the
#                           file
#   ::bgerror               PRINTS and increments ::fail (a silent swallow hides
#                           a defect, a re-throw hangs a headless run under X)
#   wvproc_body             named proc body, CODE LINES ONLY
#   bs_packed / bs_order    the widget-state masquerade answers
#   bs_wait_mapped          item 5's `at_wait_mapped` idiom: polls the
#                           PRECONDITION and RETURNS the mapping
#   send_key / viewer_ready WSLg-robust key delivery and viewer map-wait
#   $wsrc                   src/wave_viewer.tcl as text (every item greps it)
#
# ⚠ TWO PROCS DELIBERATELY DID NOT MOVE. `bs_spy_on`/`bs_spy_off` spy on
# `wviewer::browser_show`, which is item 8's subject and nobody else's; and the
# per-item readers (`bt_tree`, `bm_menu_state`, `bx_vis`, …) belong to the item
# that reasons about them. A shared prelude is for what MORE THAN ONE file
# needs — anything else moved here would be coverage nobody's verifier reads.
#
# ⚠ bs_wait_mapped / send_key / viewer_ready ARE NOW DEFINED UNCONDITIONALLY.
# They used to sit inside item 8's `if {$::has_x}` fixture blocks. A `proc`
# body is not evaluated at definition time, so defining them without the gate
# is a no-op for behaviour — and it is what lets the item-11 and item-12 files,
# whose first X-gated block is their own, still reach them. Every CALL SITE is
# still inside an X gate, exactly as before.
#
# ============================================================================
# CONTRACT WITH THE FILE THAT SOURCES IT
# ============================================================================
# Before sourcing, the caller sets:
#     set ::wvbs_tag  <short scratch tag>      e.g. wvsigbrowser_i11
#     set ::wvbs_name <banner name>            e.g. test_wave_sigbrowser_i11
# After sourcing, the caller has: $fail $npass $here $repo $scratch $wsrc and
# every proc above. The caller ends with `wvbs_finish`, which prints the banner
# and exits 0/1 — the `RESULT: ALL PASS (N checks)` line full_audit.sh greps.
# ============================================================================

if {![info exists ::wvbs_tag]}  { set ::wvbs_tag  wvsigbrowser }
if {![info exists ::wvbs_name]} { set ::wvbs_name test_wave_sigbrowser }

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# Error-guarded call (test_wave_sigsearch's `pcall`, same `{args}` +
# `uplevel 1 $args` shape). REQUIRED, not stylistic: a sabotage can make the
# code under test THROW, and an unguarded throw hits the outer catch and aborts
# every remaining check — turning a one-target sabotage into a file-wide abort.
proc pcall {args} {
  if {[catch {uplevel 1 $args} r]} { return "ERR:$r" }
  return $r
}

# bgerror override. REQUIRED: the fixture groups build real Tk widgets with real
# bindings, and an error that escapes to background level pops the stock bgerror
# dialog — MODAL under X, which HANGS a headless run. Swallow it, print it, and
# COUNT IT AS A FAILURE: a silent swallow hides a defect, a re-throw hangs, only
# this shape does neither.
proc ::bgerror {msg} { puts "BGERROR: $msg"; incr ::fail }

# recent-files gate (issue 0119)
set no_recent_files 1
set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch $::wvbs_tag]

# body of a named proc up to the closing brace in column 0, CODE LINES ONLY
# (test_wave_grid's helper, verbatim) — the bodies here carry comments naming
# the very strings being grepped, and a leg that counts prose is a leg that goes
# green on a deleted line of code.
proc wvproc_body {src name} {
  set i [string first "\nproc $name \{" $src]
  if {$i < 0} { return {} }
  set j [string first "\n\}\n" $src $i]
  if {$j < 0} { set j end }
  set out {}
  foreach line [split [string range $src $i $j] "\n"] {
    if {[regexp {^\s*#} $line]} { continue }
    lappend out $line
  }
  return [join $out "\n"]
}

# --- the two answers to the widget-state masquerade -------------------------
# NEVER THROWS: a destroyed widget and a hidden one both read 0, which is why
# every use of it is PAIRED with a `winfo exists` assertion.
proc bs_packed {w} { expr {[catch {pack info $w}] ? 0 : 1} }
# An ASSERTABLE STRING, never a boolean and never an exception. `pack info` does
# not report -before; the SLAVE ORDER is what -before set (the house oracle,
# test_wave_tabs.tcl). "a was never packed", "b was never packed", "there is no
# toplevel" and "they are packed the wrong way round" are FOUR DIFFERENT values.
proc bs_order {top a b} {
  if {[catch {pack slaves $top} sl]} { return "no-top" }
  set ia [lsearch -exact $sl $a]; set ib [lsearch -exact $sl $b]
  if {$ia < 0} { return "a-missing" }
  if {$ib < 0} { return "b-missing" }
  return [expr {$ia < $ib ? "a-before-b" : "a-after-b"}]
}

# the `at_wait_mapped` idiom (item 5). Polls the PRECONDITION — mapping —
# never the asserted value, and RETURNS the mapping so every caller can carry
# it in its own tuple: a budget expiry then reads as "never mapped" and cannot
# masquerade as a real failure.
proc bs_wait_mapped {w {budget 1500}} {
  for {set t 0} {$t < $budget && ![winfo ismapped $w]} {incr t} {
    after 10 ; update
  }
  update
  return [winfo ismapped $w]
}

# ⚠ THE TOPLEVEL TWIN OF bs_wait_mapped, ADDED BY THE RULING-30 SPLIT and the
# answer to flaky check BH54. `winfo ismapped .` on the MAIN window is not a
# fact the test may assume: a raise is asynchronous, the WM answers when it
# answers, and under a loaded WSLg compositor the answer can arrive after the
# assertion. BH54 asserted it as an instantaneous truth and flapped 1-in-4 with
# item 12 ABSENT — the un-named ~20% flap `11_receipt.md` §13.4 could not name.
#
# ⚠ IT IS A WIDENING, NOT A WEAKENING (ruling 17). It still RETURNS THE
# MAPPING, so an expired budget reads `0` and FAILS the check exactly as an
# unmapped window always did — this cannot go always-true. What it adds is the
# time the WM is allowed to take. A window that is genuinely never mapped burns
# the whole budget and still fails; only a window that maps LATE is rescued.
proc bs_wait_mapped_top {w {budget 3000}} {
  for {set t 0} {$t < $budget} {incr t} {
    if {[catch {winfo ismapped $w} m]} { return 0 }
    if {$m} { return 1 }
    after 10 ; update
  }
  update
  if {[catch {winfo ismapped $w} m]} { return 0 }
  return $m
}

# ⚠ ADDED BY THE RULING-30 SPLIT, and the answer to flaky check BT45. A widget's
# GEOMETRY is not readable until the WM has grown the TOPLEVEL to its final size;
# `update` alone does not guarantee that under WSLg. MEASURED on the real viewer:
#   settled   top 1067  sidebar 480  canvas 587
#   flapping  top  400  sidebar 240  canvas 160
# `wviewer::browser_width` caps the sidebar at 45% of the toplevel but FLOORS it
# at 240 px, so mid-resize the floor wins and the sidebar really is wider than
# the canvas. The flap was a read taken before the window finished growing.
#
# ⚠ WIDENING, NOT WEAKENING. It polls the PRECONDITION — the TOPLEVEL's width
# has been unchanged for `settle` consecutive polls — and RETURNS
# {topw aw bw settled|unsettled}, never a verdict. The caller still does the
# comparing, so an equal or inverted layout still fails; an expired budget comes
# back tagged `unsettled` with the widths it saw, so it is visible in the log
# rather than masquerading as a layout result. Nothing here can make a false
# claim true.
proc bs_wait_widths {top a b {budget 300} {settle 12}} {
  set last -1 ; set same 0
  for {set t 0} {$t < $budget} {incr t} {
    set wt 0; set wa 0; set wb 0
    catch {set wt [winfo width $top]}
    catch {set wa [winfo width $a]}
    catch {set wb [winfo width $b]}
    if {$wt > 1 && $wa > 1 && $wb > 1} {
      if {$wt == $last} { incr same } else { set same 0 ; set last $wt }
      if {$same >= $settle} { return [list $wt $wa $wb settled] }
    }
    after 10 ; update
  }
  set wt 0; set wa 0; set wb 0
  catch {set wt [winfo width $top]}
  catch {set wa [winfo width $a]}
  catch {set wb [winfo width $b]}
  return [list $wt $wa $wb unsettled]
}

# WSLg-robust key delivery (test_wave_grid's helper): a bare `event generate`
# loses the key when the focus round-trip has not completed (~1 run in 5).
# Gate on Tk reporting the canvas as focus owner and retry until the effect
# shows; report whether delivery was ever CONFIRMED so a stall can self-skip
# rather than masquerade as a broken binding (the BAR25 rule).
proc send_key {w ev done} {
  for {set i 0} {$i < 200} {incr i} {
    update
    if {[uplevel 1 [list expr $done]]} { return 1 }
    if {![winfo exists $w]} { return 0 }
    focus -force $w
    update
    if {[uplevel 1 [list expr $done]]} { return 1 }
    if {[focus -displayof $w] eq $w} {
      event generate $w $ev
      update
      if {[uplevel 1 [list expr $done]]} { return 1 }
    }
    after 50
  }
  puts "  send_key: $ev delivery to $w never confirmed (WSLg focus stall)"
  return 0
}
proc viewer_ready {top} {
  for {set i 0} {$i < 300} {incr i} {
    update
    if {[winfo exists $top.drw] && [winfo ismapped $top.drw]} { return 1 }
    after 20
  }
  return 0
}

# src/wave_viewer.tcl as text — every item's SOURCE arm greps it, so it is read
# once here instead of once per file.
set wv [file join $repo src wave_viewer.tcl]
set fp [open $wv r]; set wsrc [read $fp]; close $fp

# The closing banner every file shares. `RESULT: ALL PASS (N checks)` is what
# full_audit.sh's is_pass greps; `RESULT: N FAILED` is not a substring of it.
proc wvbs_finish {} {
  global fail npass scratch
  catch {test_scratch_drop $scratch}
  puts "----"
  puts "$::wvbs_name: $npass passed, $fail failed"
  if {$fail == 0} {
    puts "RESULT: ALL PASS ($npass checks)"
    flush stdout
    exit 0
  } else {
    puts "RESULT: $fail FAILED ($npass passed)"
    flush stdout
    exit 1
  }
}
