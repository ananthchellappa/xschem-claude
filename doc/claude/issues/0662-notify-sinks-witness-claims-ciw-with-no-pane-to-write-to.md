# 0662 — `notify_last sinks` claims `ciw` with no pane to write to

Status: OPEN (measured, NOT fixed — found while implementing 0658)
Filed by: the 0658 crew (Scout + Measure + Implement all reproduced it), 2026-08-24.

## Measured

Under `./src/xschem --nogui --pipe -q --nolog --script <t>.tcl` — no Tk at all,
no `.ciw`, no `.ciw.l.t` anywhere:

```
xschem::notify {a notice} -tag error
dict get $::xschem::notify_last sinks   ->   ciw log
```

Zero sinks were actually reached for the pane half.

## Mechanism

`src/ciw.tcl` sink 1 counts the sink whenever `::ciw_echo` merely fails to raise:

```tcl
if {[info commands ::ciw_echo] ne {}} {
  if {![catch {::ciw_echo $line $tag}]} { lappend sinks ciw }
}
```

but `ciw_echo` (src/ciw.tcl:450) is a SILENT no-op when there is no Tk or no
pane widget:

```tcl
if {![llength [info commands winfo]] || ![winfo exists .ciw.l.t]} return
```

A silent `return` is not a raise, so the claim stands and the witness lies.

## Why it matters

This is byte-for-byte the defect issue 0657 fixed for the `log` sink — where
`xschem log_action` never reports a closed log and `sinks` therefore claimed
`log` under `--nolog`. 0657 gated that claim on `xschem get actionlog_filename`
being non-empty and left the identical hole live for `ciw`. `sinks` is the
headless witness the whole notification feature is asserted through, so a sink
it claims but did not reach is 0652's class: a report that lies.

## Consequence already absorbed by 0658

Every 0658 row asserts on the durable log FILE or on a renamed `::ciw_echo` spy,
never on the `sinks` field, precisely because of this. See the ⚠ block at the
head of the NT16-NT21 / NTD1-NTD7 section of `tests/headless/test_ase_core.tcl`.

## Probable fix

Make `ciw_echo` report whether it wrote (return 1/0 instead of a bare `return`),
or have sink 1 test the same predicate `xschem::notify_ciw_visible` already
owns — but note the two are NOT the same question: `ciw_echo` writes happily
into a WITHDRAWN pane (that is 0650's measured refutation, and PS17 pins it), so
the sink-1 predicate is "the widget exists", not "the user can see it".

## Still open

All of it.
