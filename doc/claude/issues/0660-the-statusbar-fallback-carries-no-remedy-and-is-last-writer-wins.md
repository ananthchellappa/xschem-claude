# 0660 — the `.statusbar.12` fallback carries no remedy, and it is last-writer-wins

Status: OPEN (measured, NOT fixed)
Filed by: the 0650 write-up pass, 2026-08-23, from the adversary leg's findings.

Two defects in one sink, both of which bite **exactly** when the fallback is the
only thing the user can see.

## (a) The remedy is stripped from the only sink that fires when the CIW is invisible

`xschem::notify` appends `-menu` and `-command` to `$line` (pane + log) but feeds
`xschem::notify_short` the bare `$msg`. Measured:

```
LINE  : ASE: device operating-point parameters were not saved in this deck (issue 0617). Fix: Outputs > Save All… > Save device OP parameters (gm, gds, vth, ...). CIW command: ase::ui::save_op_params_on lib/cell/schematic
SHORT : no OP params saved
```

So R-0653-d's entire benefit — *"say what to do about it"* — reaches every sink
**except** the one that fires when the CIW is not visible. It is worse for the
61+ plain `ase::echo` sites, which pass no `-short` at all and therefore get a
blind 25-character prefix: PS14's own note records the delivered text as
`ASE: device operating-poi...`.

0650's sink table asked for *"short form plus 'see CIW / log'"*. The "see CIW /
log" half was not implemented — and note it would have to say something better
than "see CIW", since the CIW being invisible is the precondition for this sink
firing at all.

## (b) Volume: the field is `configure -text`, a REPLACE

Measured on :99 with the CIW withdrawn, three notices in a row:

```
0660 after 3 notices, only this survived           'ASE: netlist written'
```

The two per-device warnings are gone. This is not hypothetical: in
`ase::op_cards_capture` the `::op_annot::last_warnings` loop emits **one line per
unnamed device** and is **always** followed by either the empty-block error or the
success line. So the under-emission warnings — the messages this whole feature
exists to surface — can **never** survive to the fallback sink.

## Why it was not fixed here

Both fixes are design, not repair. (a) needs a rule for what a 28-character field
says about a remedy it cannot print; (b) needs either a queue with a timer, a
"+N more" counter, or a different carrier. Both are cheap **if** the sink moves to
the ASE session window (issue **0655**), which is the ruling the user owes on the
0650 status-E row — so building either here risks paying twice.

## Related

* **0654** — the field's four measured properties (clips at ~28-42 chars, shared
  with `*BUSY*`, cleared unconditionally by `propagate_logic()`, per-toplevel).
* Also measured and not separately filed: `.statusbar.12` is created `-fg red`
  (`src/xschem.tcl:15573`) and nothing changes it, so a **plain success** line —
  `ASE: netlist written to /...` — is delivered to the user in the error colour.

## Still open

All of it.
