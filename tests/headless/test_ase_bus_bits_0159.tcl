# ASE bus pick: per-bit selection dialog (issue 0159).
#
# `ase::ui::sod_expr` is a pure string wrap, so picking a BUS net produced one
# invalid vector: `A[1:0]` -> `v(a[1:0])`, `D,E` -> `v(d,e)`. That string is
# interpolated verbatim into the deck (`.save`/`print`, src/ase.tcl:911/:931).
# Measured with ngspice-42:
#   .save v(a[1:0]) ALONE          -> "no data saved ... analysis not run" (run dies)
#   .save v(a1) + .save v(a[1:0])  -> runs, the bad token is SILENTLY dropped
#   .save all + print v(a[1:0])    -> runs, "Warning from checkvalid: vector
#                                     a[1:0] is not available or has zero length"
#   .save v(d,e)                   -> never aborts; ngspice takes it
# so the common case is a silently missing trace and the sole-pick case kills
# the whole run.
#
# Contract (user decision): a bus pick opens a bit-selection dialog. Nothing is
# selected when it opens; `All` selects every bit; Ctrl-click toggles (Tk
# `extended` selectmode); `Reverse` flips the DISPLAYED order, which is also the
# order the bits are queued in; OK queues the selected bits in display order;
# Cancel queues nothing. Both pick paths get it -- Direct Plot (`dp_queue`) and
# the persisted Outputs list (`sod_queue`). Legacy saved states holding a
# `v(a[1:0])` row are expanded per bit on load.
#
# Legs (BB*):
#   BB1-BB7    ase::ui::sod_bits -- the PURE bit split. Must work with no design
#              loaded, like sod_expr (test_ase_interact H1 calls it that way).
#   BB8-BB14   ase::state_load migration of a legacy bus output row, and the
#              rows it must NOT touch (scalars, currents, derived expressions).
#   BB15-BB20  ase::ui::sod_pick_tokens -- what sod_click will queue, with the
#              dialog stubbed out. Cancel, All, subset, reverse order, scalar
#              (dialog must not even be consulted), current pick.
#   BB21-BB28  the real Tk dialog: initial empty selection, bit order, All,
#              Reverse (order flips, selection survives), OK order, Cancel.
#              SKIPPED without a usable DISPLAY.
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_bus_bits_0159.tcl
#   ./src/xschem --nogui --pipe -q --nolog --script ...   (BB1-BB20 only)

set fail 0; set npass 0; set skipped 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

set no_recent_files 1                       ;# issue 0119: keep Open Recent clean

set here    [file normalize [file dirname [info script]]]
set repo    [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch ase_bus_bits_0159]

## ISOLATION FROM WHOEVER'S ~/.xschem/ase_simulators IS LIVE (issue 1377).
test_sim_registry_isolate     ;# issue 1377: the registry below is OURS, not ~/.xschem's
## BB29/BB31/BB33 pin FOLDED bit names (`v(a[1])`, `v(out)`). MEASURED before
## this line: 3 FAILED under the developer's own HOME and under a hostile
## registry, ALL PASS (39) under a HOME with no registry.
check "ISO1377 the suite runs against an empty simulator registry, not the one in ~/.xschem" \
  [test_sim_registry_state] {0 {} {} path}

if {[catch {

# --- BB1-BB7  sod_bits: the pure split -----------------------------------------
# NO design is loaded at this point on purpose: sod_expr's contract is that the
# simulator-side mapping is a pure string op, and the split must not weaken it.
check "BB1 a bracket bus splits MSB-first" \
  [ase::ui::sod_bits {A[1:0]}] [list {A[1]} {A[0]}]
check "BB2 a comma bus splits" \
  [ase::ui::sod_bits {D,E}] {D E}
check "BB3 a scalar net is a one-element list" \
  [ase::ui::sod_bits OUT] {OUT}
check "BB4 the auto-net marker rides along per bit (sod_expr strips it later)" \
  [ase::ui::sod_bits {#a[1:0]}] [list {#a[1]} {#a[0]}]
check "BB5 a wider bus, ascending range" \
  [ase::ui::sod_bits {A[0:3]}] [list {A[0]} {A[1]} {A[2]} {A[3]}]
check "BB6 a mixed bracket+comma bus" \
  [ase::ui::sod_bits {A[1:0],B}] [list {A[1]} {A[0]} B]
check "BB7 an empty token yields nothing" [ase::ui::sod_bits {}] {}

# --- BB8-BB14  legacy state migration -------------------------------------------
# A state saved before this fix carries one row whose expr is the invalid single
# vector. Expand it on load, preserving the row's other fields.
proc mkstate {outputs} {
  global scratch
  set st [dict merge [ase::state_default] [dict create outputs $outputs]]
  set p [file join $scratch legacy.ase]
  ase::state_save $p $st
  return [ase::state_load $p]
}
proc exprs {st} {
  set out {}
  foreach o [ase::state_get $st outputs] { lappend out [dict get $o expr] }
  return $out
}

set st [mkstate [list [dict create name vb expr {v(a[1:0])} plot 1 save 1]]]
check "BB8 a legacy bracket-bus output row expands per bit on load" \
  [exprs $st] [list {v(a[1])} {v(a[0])}]
check "BB9 the expanded rows keep the original flags" \
  [list [dict get [lindex [ase::state_get $st outputs] 0] plot] \
        [dict get [lindex [ase::state_get $st outputs] 1] save]] {1 1}

# The comma form is deliberately NOT migrated: a stored expr is opaque, and
# `v(a,b)` is also ngspice's differential voltage, which a user can have typed
# into the Add-Output dialog. Expanding it would destroy that row. The cost is
# nil -- measured with ngspice-42, `.save v(d,e)` does NOT abort the run (it
# saves v(d) and v(e)), unlike the bracket form. A comma bus picked on the
# SCHEMATIC still splits, because there the token is known to be a net (BB2).
set st [mkstate [list [dict create name vc expr {v(d,e)} plot 1 save 0]]]
check "BB10 a legacy comma expr is left alone (it may be a differential)" \
  [exprs $st] {v(d,e)}
set st [mkstate [list [dict create name vh expr {v(x1.a[1:0])} plot 1 save 1]]]
check "BB10b a hierarchical bracket bus still expands" \
  [exprs $st] [list {v(x1.a[1])} {v(x1.a[0])}]

set st [mkstate [list [dict create name vo expr {v(out)} plot 1 save 1]]]
check "BB11 (control) a scalar voltage row is untouched" [exprs $st] {v(out)}

set st [mkstate [list [dict create name i1 expr {i(v1)} plot 0 save 1]]]
check "BB12 (control) a current row is untouched" [exprs $st] {i(v1)}

set st [mkstate [list [dict create name d1 expr {v(a)-v(b)} plot 1 save 0]]]
check "BB13 (control) a DERIVED expression is never split" [exprs $st] {v(a)-v(b)}

set st [mkstate [list [dict create name vo expr {v(out)} plot 1 save 1] \
                      [dict create name vb expr {v(a[1:0])} plot 1 save 1] \
                      [dict create name i1 expr {i(v1)} plot 0 save 1]]]
check "BB14 mixed list: only the bus row expands, order preserved" \
  [exprs $st] [list {v(out)} {v(a[1])} {v(a[0])} {i(v1)}]

# --- BB15-BB20  what a click queues, with the dialog stubbed ---------------------
# sod_pick_tokens is the seam sod_click uses: it returns the list of tokens to
# queue. Overriding ase::ui::bus_dialog is the established test idiom (the
# descend tests override `ask_save` the same way).
set ::bus_dialog_calls 0
## keep the REAL proc so BB34 can exercise the modal wrapper: a plain
## `proc ase::ui::bus_dialog` here would overwrite it, and `rename … {}` later
## would DELETE it rather than put it back.
rename ase::ui::bus_dialog ase::ui::real_bus_dialog
proc ase::ui::bus_dialog {key token bits} {
  incr ::bus_dialog_calls
  return $::bus_dialog_answer
}

set ::bus_dialog_answer [list {A[1]} {A[0]}]
set ::bus_dialog_calls 0
check "BB15 a bus voltage pick queues one token per chosen bit" \
  [ase::ui::sod_pick_tokens k voltage {A[1:0]}] [list {A[1]} {A[0]}]
check "BB16 the dialog was consulted exactly once" $::bus_dialog_calls 1

set ::bus_dialog_answer [list {A[0]}]
check "BB17 a subset selection queues only those bits" \
  [ase::ui::sod_pick_tokens k voltage {A[1:0]}] [list {A[0]}]

set ::bus_dialog_answer [list {A[0]} {A[1]}]
check "BB18 the dialog's order is the queue order (Reverse works end to end)" \
  [ase::ui::sod_pick_tokens k voltage {A[1:0]}] [list {A[0]} {A[1]}]

set ::bus_dialog_answer {}
check "BB19 Cancel queues nothing" \
  [ase::ui::sod_pick_tokens k voltage {A[1:0]}] {}

set ::bus_dialog_calls 0
check "BB20 (control) a scalar pick queues the token and never opens the dialog" \
  [list [ase::ui::sod_pick_tokens k voltage OUT] $::bus_dialog_calls] {OUT 0}
set ::bus_dialog_calls 0
check "BB20b (control) a current pick is never treated as a bus" \
  [list [ase::ui::sod_pick_tokens k current V1] $::bus_dialog_calls] {V1 0}

# --- BB21-BB28  the real dialog --------------------------------------------------
set have_tk [expr {[info commands winfo] ne {} && ![catch {winfo exists .}]}]
if {!$have_tk} {
  puts "SKIP: BB21-BB28 need a DISPLAY (dialog widgets)"
  incr skipped
} else {
  # These legs drive bus_dialog_build and the button commands directly (that is
  # what the split is for); the real modal wrapper is exercised by BB34, which
  # uses the copy saved above.
  set w [ase::ui::bus_dialog_build {} {A[3:0]} {A[3] A[2] A[1] A[0]}]
  check_true "BB21 the dialog toplevel exists" [winfo exists $w]
  check "BB22 the bits are listed MSB-first, as expandlabel returns them" \
    [$w.lf.list get 0 end] [list {A[3]} {A[2]} {A[1]} {A[0]}]
  check "BB23 nothing is selected when it opens" [$w.lf.list curselection] {}

  $w.btns.all invoke
  check "BB24 All selects every bit" [$w.lf.list curselection] {0 1 2 3}

  $w.lf.list selection clear 0 end
  $w.lf.list selection set 1
  $w.lf.list selection set 3
  $w.btns.rev invoke
  check "BB25 Reverse flips the displayed order" \
    [$w.lf.list get 0 end] [list {A[0]} {A[1]} {A[2]} {A[3]}]
  check "BB26 Reverse carries the selection with the items" \
    [lsort [ase::ui::bus_dialog_selected $w]] [lsort [list {A[2]} {A[0]}]]

  set ::ase::ui::bus_dialog_result __unset__
  $w.btns.ok invoke
  check "BB27 OK returns the selection in DISPLAY order" \
    $::ase::ui::bus_dialog_result [list {A[0]} {A[2]}]
  check_true "BB27b OK destroys the dialog" [expr {![winfo exists $w]}]

  set w [ase::ui::bus_dialog_build {} {A[1:0]} {A[1] A[0]}]
  $w.btns.all invoke
  $w.btns.cancel invoke
  check "BB28 Cancel returns nothing even with bits selected" \
    $::ase::ui::bus_dialog_result {}
  catch {destroy $w}

  # --- BB29-BB32  the real sod_click, on a real bus wire ----------------------
  # Covers the fan-out LOOP in sod_click, not just the sod_pick_tokens seam:
  # select_at + sod_net_at really resolve the bus net under the click, and one
  # row per chosen bit really reaches the queue. dp_queue/sod_queue are stubbed
  # so no ASE session has to exist.
  proc wfile {p body} { set f [open $p w]; puts $f $body; close $f }
  wfile [file join $scratch bus.sch] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 0 0 200 0 {}
N 0 100 200 100 {}
C {devices/lab_pin} 0 0 0 0 {name=lA lab="A[1:0]"}
C {devices/lab_pin} 0 100 0 0 {name=lS lab=OUT}}
  set f [open [file join $scratch library.defs] w]
  puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
  close $f
  set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
  set ::library_registry_defs_only 1
  set ::XSCHEM_LIBRARY_PATH {}
  xschem load [file join $scratch bus.sch]

  set ::queued {}
  set ::hilit  {}
  proc ase::ui::dp_queue {key ex {kind {}} {token {}}} {
    lappend ::queued $ex ; lappend ::hilit $token
  }
  proc ase::ui::sod_queue {key ex} { lappend ::queued $ex }
  proc ase::ui::bus_dialog {key token bits} { return $::bus_dialog_answer }

  # plot mode
  array set ase::ui::sod [list k,flavor tobeplotted k,mode plot k,count 0]
  set ::bus_dialog_answer [list {A[1]} {A[0]}]
  set ::queued {} ; set ::hilit {}
  ase::ui::sod_click k 100 0
  check "BB29 a real bus click queues ONE trace per chosen bit" \
    $::queued [list {v(a[1])} {v(a[0])}]
  check "BB30 the schematic cue is painted once, for the first bit only" \
    $::hilit [list {A[1:0]} {}]

  # outputs mode
  array set ase::ui::sod [list k,flavor tobesaved k,mode outputs]
  set ::queued {}
  ase::ui::sod_click k 100 0
  check "BB31 the same fan-out happens on the persisted Outputs path" \
    $::queued [list {v(a[1])} {v(a[0])}]

  set ::bus_dialog_answer {}
  set ::queued {}
  ase::ui::sod_click k 100 0
  check "BB32 Cancel on a real click queues nothing at all" $::queued {}

  set ::queued {}
  ase::ui::sod_click k 100 100
  check "BB33 (control) a scalar net click still queues exactly one row" \
    $::queued {v(out)}

  # --- the modal driver: issue 1332's residual, and the poll that closes it ---
  ## BB34-BB38 drive a REAL grabbing modal: `ase::ui::bus_dialog` does build +
  ## update + raise + `grab set` + `focus` + `tkwait window`. They used to do it
  ## on a FIXED `after 100`, and THIS FILE is where that idiom came from - issue
  ## 1332 was filed against the copies of it in test_rdw_keys_1245.tcl, which
  ## measured it false-redding, converted itself to a poll, and named this file
  ## in its "still open" section. This is that residual.
  ##
  ## THE MARGIN IS NOT THE POINT. 1332 instrumented the dialog appearing 3-6 ms
  ## after the invoke, max 19 ms over 88 runs, against a 100 ms timer - a 5-30x
  ## margin that lost anyway, because a contended X display does not stretch the
  ## margin a little, it stops the interpreter reaching the event loop at all.
  ## So widening the delay is the one fix that is ruled out: it turns a race into
  ## a slower race. The driver POLLS instead, and 1332's recorded loss is the
  ## all-zeros tuple at 5004 ms - a plausible "nothing happened", not a crash and
  ## not a hang, which is why it survived 134 runs.
  ##
  ## AND THE CONDITION IS THE DIALOG'S OWN GRAB, NOT MERELY ITS WINDOW.
  ## `ase::ui::bus_dialog` runs `grab set $w`, `focus $w.lf.list` and
  ## `tkwait window $w` with NO event loop between them, so a driver that finds
  ## `.asebusbits` holding the grab is running from inside `tkwait` on a dialog
  ## that is fully modal. A poll waiting on `winfo exists` alone would fire
  ## during the wrapper's own `update`, before the grab; the buttons would still
  ## answer and the row would report the RIGHT bits having never entered tkwait -
  ## the one thing BB34's comment says it is there to cover. That is row BB37,
  ## and it is why this condition is the grab. `grab current` is compared to the
  ## WINDOW rather than to `{}` (1332's SD8): a bare `ne {}` answers for any grab
  ## the application holds anywhere, and one unrelated grab satisfies it.
  ##
  ## AND BOTH TIMERS ARE CANCELLED WHEN THE ROW ENDS. They were not: BB34's 5 s
  ## deadman stayed armed all through BB35, one `catch {destroy .asebusbits}`
  ## away from ending a dialog the next row was still driving - and BB35 expects
  ## `{}`, so it would have PASSED on the deadman's answer instead of Cancel's.
  ## The stray one-shot was survivable because it fired within 100 ms, i.e.
  ## almost always inside its own row; a self-re-arming poll lives seconds, so
  ## disarming is load-bearing here in a way it was not before. BB38 asserts it.
  set ::BB_POLL_ID {} ; set ::BB_DEADMAN {} ; set ::BB_POLLS 0
  set ::BB_GAVEUP 0 ; set ::BB_RAN 0 ; set ::BB_DEADLINE 0
  set ::BB_SEEN 0 ; set ::BB_GRAB {} ; set ::BB_FOCUS UNSET
  proc bb_arm {script {budget 900} {deadman 5000}} {
    ## ⚠ ARMING DISARMS FIRST, and that is not tidiness: overwriting the handles
    ## while the previous chain is still running puts it beyond reach of
    ## `bb_disarm`, and a live chain presses buttons on whatever dialog the NEXT
    ## row has up.
    bb_disarm
    set ::BB_POLLS 0 ; set ::BB_GAVEUP 0 ; set ::BB_RAN 0
    ## The give-up is a wall-clock deadline AS WELL AS a poll count. `after 5` is
    ## a floor, not a period: 1332's adversary measured a full 900-poll give-up
    ## taking 6.5 s at load avg 54 - past the 5 s deadman it was claimed to sit
    ## inside. Whichever limit comes first stops the chain, so a poll that never
    ## finds its dialog gives up rather than outliving the row.
    set ::BB_DEADLINE [expr {[clock milliseconds] + $deadman - 500}]
    set ::BB_POLL_ID {}
    set ::BB_DEADMAN [after $deadman {catch {destroy .asebusbits}}]
    bb_poll_modal $script $budget
    return {}
  }
  proc bb_poll_modal {script budget} {
    set ::BB_POLL_ID {}
    incr ::BB_POLLS
    if {[winfo exists .asebusbits] && [grab current] eq {.asebusbits}} {
      set ::BB_RAN 1
      uplevel #0 $script
      return
    }
    if {$::BB_POLLS >= $budget || [clock milliseconds] >= $::BB_DEADLINE} {
      set ::BB_GAVEUP 1 ; return
    }
    set ::BB_POLL_ID [after 5 [list bb_poll_modal $script $budget]]
  }
  proc bb_disarm {} {
    if {$::BB_POLL_ID ne {}} { catch {after cancel $::BB_POLL_ID} }
    if {$::BB_DEADMAN ne {}} { catch {after cancel $::BB_DEADMAN} }
    set ::BB_POLL_ID {} ; set ::BB_DEADMAN {} ; set ::BB_DEADLINE 0
    return {}
  }
  ## The sabotage rows below delay the real build by spinning the EVENT LOOP,
  ## which is what display contention does to this path. A busy-wait would prove
  ## nothing: no timer can fire while Tcl is not in the event loop.
  ## `rename`, never `proc` - this file's own idiom at :129-132.
  proc bb_spin {ms} {
    set ::BB_SPIN_GATE 0
    after $ms {set ::BB_SPIN_GATE 1}
    vwait ::BB_SPIN_GATE
    return {}
  }
  proc bb_slow_install {when ms} {
    set ::BB_SLOW_WHEN $when ; set ::BB_SLOW_MS $ms
    if {![llength [info commands ::ase::ui::bb_real_build]]} {
      rename ::ase::ui::bus_dialog_build ::ase::ui::bb_real_build
    }
    proc ::ase::ui::bus_dialog_build {args} {
      if {$::BB_SLOW_WHEN eq {before}} { bb_spin $::BB_SLOW_MS }
      set w [uplevel 1 [linsert $args 0 ::ase::ui::bb_real_build]]
      if {$::BB_SLOW_WHEN eq {after}} { bb_spin $::BB_SLOW_MS }
      return $w
    }
    return {}
  }
  proc bb_slow_none {} {
    set ::BB_SLOW_WHEN none
    if {![llength [info commands ::ase::ui::bb_real_build]]} {
      rename ::ase::ui::bus_dialog_build ::ase::ui::bb_real_build
    }
    proc ::ase::ui::bus_dialog_build {args} { return NO-DIALOG-EVER-BUILT }
    return {}
  }
  proc bb_slow_remove {} {
    if {[llength [info commands ::ase::ui::bb_real_build]]} {
      catch {rename ::ase::ui::bus_dialog_build {}}
      rename ::ase::ui::bb_real_build ::ase::ui::bus_dialog_build
    }
    set ::BB_SLOW_WHEN none
    return [llength [info commands ::ase::ui::bus_dialog_build]]
  }

  # --- BB34-BB35  the REAL modal wrapper -------------------------------------
  # ase::ui::bus_dialog does update + raise + grab + tkwait. Drive it with
  # `bb_arm`, which POLLS until the dialog owns the grab and only then presses
  # the buttons, so the grab/tkwait path itself is covered and not just the
  # widget builder. `bb_arm` carries the deadman (issue 0803): if the poll never
  # finds its dialog the window is destroyed anyway and tkwait returns, so this
  # can never hang the suite. `bb_disarm` cancels BOTH timers at the end of each
  # row -- BB34's deadman used to stay armed all through BB35, and BB35 expects
  # `{}`, so it could have passed on the deadman's answer instead of Cancel's.
  bb_arm {catch {.asebusbits.btns.all invoke} ; catch {.asebusbits.btns.ok invoke}}
  set got [ase::ui::real_bus_dialog nosuchkey {A[1:0]} [list {A[1]} {A[0]}]]
  bb_disarm
  check "BB34 the modal wrapper returns the chosen bits and releases" \
    $got [list {A[1]} {A[0]}]
  check_true "BB34b it left no grab and no window behind" \
    [expr {![winfo exists .asebusbits] && [grab current] eq {}}]

  bb_arm {catch {.asebusbits.btns.cancel invoke}}
  set got [ase::ui::real_bus_dialog nosuchkey {A[1:0]} [list {A[1]} {A[0]}]]
  bb_disarm
  check "BB35 Cancel through the modal wrapper returns nothing" $got {}

  # --- BB36  SHAPE A: the dialog is not there yet (issue 1332) ---------------
  ## 1332's own recorded failure, made deterministic. The real build is delayed
  ## 300 ms past the old 100 ms timer by spinning the event loop, which is the
  ## only kind of delay a timer can fire during.
  ##
  ## MEASURED on this tree with the driver reverted to `after 100`, twice and
  ## byte-identical:
  ##   BB36 -> {0 {} {} 0 {} 1 0 1 0 1}
  ##        exp {1 .asebusbits {{A[1]} {A[0]}} 0 {} 1 1 1 0 1}
  ## - nothing seen, no grab, no bits, and the `< 3000 ms` leg 0 because the
  ## deadman burned the full ~4.9 s (suite wall clock 5.92 s against 1.50 s
  ## green). Note the SHAPE: a plausible "the user chose nothing", not a crash
  ## and not a hang - which is why 1332 survived 134 runs before anyone saw it.
  ##
  ## A poll keyed on `winfo exists` ALONE reds this row differently, and the
  ## difference is the point: {1 {} {{A[1]} {A[0]}} ...} - the right bits, with
  ## an EMPTY grab. That is BB37's subject.
  ##
  ## The elapsed-time legs are what stop a poll quietly reverted to a fixed
  ## delay from passing by accident, and every leg below prints what was
  ## OBSERVED rather than a description of the failure case.
  bb_slow_install before 300
  set ::BB_SEEN 0 ; set ::BB_GRAB {}
  bb_arm {
    catch {set ::BB_SEEN [expr {[winfo exists .asebusbits] ? 1 : 0}]}
    catch {set ::BB_GRAB [grab current]}
    catch {.asebusbits.btns.all invoke}
    catch {.asebusbits.btns.ok invoke}
  }
  set BB36_T0 [clock milliseconds]
  set BB36_GOT [ase::ui::real_bus_dialog nosuchkey {A[1:0]} [list {A[1]} {A[0]}]]
  set BB36_DT [expr {[clock milliseconds] - $BB36_T0}]
  bb_disarm
  set BB36_RESTORED [bb_slow_remove]
  check "BB36 the modal driver is a POLL and not a bet: with the dialog's construction delayed 300 ms - past the old fixed 100 ms timer, and delayed by spinning the event loop the way a contended display does - the driver still lands on a real modal holding its OWN grab, All+OK still returns both bits, nothing is left behind, and it finishes well inside the 5 s deadman. Under `after 100` this row is issue 1332's own shape: nothing seen, no grab, no bits, ~5004 ms" \
    [list $::BB_SEEN $::BB_GRAB $BB36_GOT \
          [expr {[winfo exists .asebusbits] ? 1 : 0}] [grab current] \
          [expr {$BB36_DT >= 250 ? 1 : 0}] [expr {$BB36_DT < 3000 ? 1 : 0}] \
          $::BB_RAN $::BB_GAVEUP $BB36_RESTORED] \
    [list 1 .asebusbits [list {A[1]} {A[0]}] 0 {} 1 1 1 0 1]

  # --- BB37  SHAPE B: the window is there, the MODAL is not (issue 1332) -----
  ## The losing shape that does NOT red - it passes, having covered nothing, and
  ## that is worse. The delay moves to AFTER the real build returns and BEFORE
  ## the wrapper's own `update` / `grab set` / `tkwait`. A driver waiting on
  ## `winfo exists` alone fires here: `.asebusbits` already exists, the buttons
  ## answer, OK destroys the dialog, and the wrapper then SKIPS `tkwait`
  ## altogether because its window is already gone. The returned bits are right
  ## and the grab/tkwait path BB34 exists to cover was never entered.
  ## So the load-bearing leg is the GRAB AT DRIVE TIME. MEASURED on this tree,
  ## each sabotage run twice and byte-identical:
  ##   a poll keyed on `winfo exists` ALONE:
  ##     BB37 -> {1 {} 1 {{A[1]} {A[0]}} 0 {} 1 1 1 0 1}
  ##     -- window seen, grab EMPTY, tkwait never entered, and the RIGHT bits
  ##        returned. The vacuous pass, and ONLY the grab leg sees it.
  ##   the old fixed `after 100`:
  ##     BB37 -> {0 {} 0 {} 0 {} 1 1 1 0 1}
  ##     -- it never gets that far: the 100 ms timer fires before the toplevel
  ##        exists at all, so under the fixed bet this fixture degenerates into
  ##        BB36's shape A. Both are red, in DIFFERENT places.
  ##
  ## ⚠ AND THE FOCUS LEG IS A GUARD, NOT THE DISCRIMINATOR. It reads 1 under
  ## BOTH sabotages above (measured), because the window manager hands the new
  ## toplevel the focus before the wrapper's own `focus $w.lf.list` ever runs.
  ## It is kept because a driver firing while the keyboard is elsewhere is worth
  ## catching, but it must not be read as evidence of modality - the grab is the
  ## only leg that separates "inside tkwait" from "during the build's update".
  bb_slow_install after 200
  set ::BB_SEEN 0 ; set ::BB_GRAB {} ; set ::BB_FOCUS UNSET
  bb_arm {
    catch {set ::BB_SEEN [expr {[winfo exists .asebusbits] ? 1 : 0}]}
    catch {set ::BB_GRAB [grab current]}
    catch {set ::BB_FOCUS [focus]}
    catch {.asebusbits.btns.all invoke}
    catch {.asebusbits.btns.ok invoke}
  }
  set BB37_T0 [clock milliseconds]
  set BB37_GOT [ase::ui::real_bus_dialog nosuchkey {A[1:0]} [list {A[1]} {A[0]}]]
  set BB37_DT [expr {[clock milliseconds] - $BB37_T0}]
  bb_disarm
  set BB37_RESTORED [bb_slow_remove]
  check "BB37 and the poll waits for the MODAL, not merely for the window: with the delay moved between the build and the wrapper's own grab, the driver still finds `.asebusbits` owning the grab before it presses anything, so the bits it returns were given by a dialog that really was inside tkwait. A poll keyed on `winfo exists` alone fires during the build's `update` instead and reports the RIGHT bits with an EMPTY grab, having never entered tkwait - the vacuous pass only this row's grab leg can see; the old fixed `after 100` fires even earlier and loses the window too" \
    [list $::BB_SEEN $::BB_GRAB \
          [expr {$::BB_FOCUS eq {.asebusbits} || [string match {.asebusbits.*} $::BB_FOCUS] ? 1 : 0}] \
          $BB37_GOT \
          [expr {[winfo exists .asebusbits] ? 1 : 0}] [grab current] \
          [expr {$BB37_DT >= 150 ? 1 : 0}] [expr {$BB37_DT < 3000 ? 1 : 0}] \
          $::BB_RAN $::BB_GAVEUP $BB37_RESTORED] \
    [list 1 .asebusbits 1 [list {A[1]} {A[0]}] 0 {} 1 1 1 0 1]

  # --- BB38  the poll can fail, but it cannot lie and it cannot linger -------
  ## (a) NO dialog is ever CONSTRUCTED. The wrapper's own `winfo exists` guard
  ##     returns at once, so the poll must give up on its budget and its script
  ##     must never have run. `bus_dialog_result` is reset BY HAND here because
  ##     the stubbed build is the thing that normally resets it - left alone it
  ##     would still carry BB37's answer and this leg would read a stale pass.
  ## (b) a REAL dialog is built and NOBODY drives it. `tkwait` is entered for
  ##     real and only the deadman can end it - issue 0803's property, asserted
  ##     under the poll instead of assumed. A short deadman keeps the row cheap.
  ## (c) THE TIMERS ARE GONE AFTERWARDS. The deadman handle no longer resolves,
  ##     so neither timer can reach into a later row's dialog. This is the leg
  ##     that BB34's old uncancelled `after 5000` would have failed.
  bb_slow_none
  set ::ase::ui::bus_dialog_result {}
  bb_arm {catch {.asebusbits.btns.ok invoke}} 10
  set BB38A_GOT [ase::ui::real_bus_dialog nosuchkey {A[1:0]} [list {A[1]} {A[0]}]]
  ## ⚠ `after 120` ALONE WOULD PROVE NOTHING - a bare `after ms` BLOCKS and
  ## enters no event loop, so the poll's own timers cannot fire during it and the
  ## budget is never spent. The spin is a `vwait`, which IS the event loop.
  bb_spin 120
  set BB38A_RAN $::BB_RAN ; set BB38A_GAVE $::BB_GAVEUP
  bb_disarm
  set BB38_RESTORED [bb_slow_remove]
  bb_arm {} 900 300
  set BB38_H $::BB_DEADMAN
  set BB38_T0 [clock milliseconds]
  set BB38B_GOT [ase::ui::real_bus_dialog nosuchkey {A[1:0]} [list {A[1]} {A[0]}]]
  set BB38_DT [expr {[clock milliseconds] - $BB38_T0}]
  bb_disarm
  check "BB38 the poll can fail but it cannot lie or linger: with no dialog ever CONSTRUCTED the driver script never runs and the poll gives up on its own budget instead of re-arming into the next row; with a real dialog built and NOBODY driving it the deadman still ends it, tkwait returns, the answer is empty and no grab or window is left; and afterwards both timers are cancelled and the real bus_dialog_build is back in place" \
    [list $BB38A_GOT $BB38A_RAN $BB38A_GAVE $BB38_RESTORED \
          $BB38B_GOT \
          [expr {$BB38_DT >= 250 ? 1 : 0}] [expr {$BB38_DT < 2000 ? 1 : 0}] \
          [expr {[winfo exists .asebusbits] ? 1 : 0}] [grab current] \
          [catch {after info $BB38_H}] $::BB_POLL_ID $::BB_DEADMAN] \
    [list {} 0 1 1 {} 1 1 0 {} 1 {} {}]
}

} err]} { puts "FATAL: $err" ; incr fail }

if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks[expr {$skipped ? ", $skipped group(s) skipped" : {}}])"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
