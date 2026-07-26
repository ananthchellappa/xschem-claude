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

  # --- BB34-BB35  the REAL modal wrapper -------------------------------------
  # ase::ui::bus_dialog does update + raise + grab + tkwait. Drive it with a
  # timer that presses the buttons while it is blocked in tkwait, so the
  # grab/tkwait path itself is covered and not just the widget builder. The
  # second `after` is a deadman: if the first never fires the window is
  # destroyed anyway and tkwait returns, so this can never hang the suite.
  after 100  {catch {.asebusbits.btns.all invoke} ; catch {.asebusbits.btns.ok invoke}}
  after 5000 {catch {destroy .asebusbits}}
  set got [ase::ui::real_bus_dialog nosuchkey {A[1:0]} [list {A[1]} {A[0]}]]
  check "BB34 the modal wrapper returns the chosen bits and releases" \
    $got [list {A[1]} {A[0]}]
  check_true "BB34b it left no grab and no window behind" \
    [expr {![winfo exists .asebusbits] && [grab current] eq {}}]

  after 100  {catch {.asebusbits.btns.cancel invoke}}
  after 5000 {catch {destroy .asebusbits}}
  set got [ase::ui::real_bus_dialog nosuchkey {A[1:0]} [list {A[1]} {A[0]}]]
  check "BB35 Cancel through the modal wrapper returns nothing" $got {}
}

} err]} { puts "FATAL: $err" ; incr fail }

if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks[expr {$skipped ? ", $skipped group(s) skipped" : {}}])"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
