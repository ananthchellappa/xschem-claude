# 0648 — the OP-card nudge goes silent on exactly the re-run the user makes after acting on it

STATUS: **OPEN — reported by the user 2026-08-23, reproduced and root-caused the
same day.** Compound defect: 0636's once-per-cellview latch + a dialog that
discards on close + no positive confirmation anywhere. Related: 0617, 0633, 0636.

---

## What the user did, and saw

> "OP analysis only. No OP info is available with key 6. I get id = blank, gm =
> blank. Node voltages are displayed with Alt-6 and Ctrl-6 does its job. Then, I
> went to Outputs > Save and checked the 'Save device OP parameters'. I re-ran
> the sim and still don't get OP info. This is for tb_bandgap in
> sky130_test_ase."

**The second run said nothing at all.** That silence is the defect.

## The backend is NOT at fault — measured on the user's exact cell

`tb_bandgap`, sky130 descriptors registered, gate forced on in a headless driver:

```
gate=1  op_enabled=1   design_is_dirty=0   op_cards_hit=1
save_cards            -> 469 lines
rendered deck         -> 794 lines, 516 .save lines, 468 device-param cards
                         .save @m.x1.x1.xm4.msky130_fd_pr__pfet_01v8[id]  ...
```

So S3 and S4 work on `tb_bandgap`. (Worth recording: the S4 crew's 468-card
evidence was taken on **`tb_bandgap_opamp`**, a *different* cell — that one yields
187. Both work; the benches are not interchangeable and a report must name which.)

The failure is entirely in front of the gate: **`save_op_params` was never 1 for
the run the user made.**

## The three defects, in the order they bite

### 1. The latch suppresses the message on the re-run (the sharp one)

`ase::op_cards_nudge_ok` (`src/ase.tcl`) keys `op_nudged` on
`lib/cell/view` alone, sets it on first use, and **never resets it** — not on a
state change, not on a gate change:

```tcl
if {[dict exists $op_nudged $k]} { return 0 }
dict set op_nudged $k 1
```

So the sequence a user actually performs is:

| step | gate | what the tool says |
|---|---|---|
| run 1 | off | the nudge: "Tick Outputs > Save All > Save device OP parameters" |
| user ticks the box, tick does not commit (see 2) | off | — |
| run 2 | off | **nothing. The latch already fired.** |

The message exists precisely to tell the user the gate is off, and it is
suppressed on the one run where the user has already tried to turn it on and
needs to know they failed. 0636 asked whether the cadence should be once-per-cell
or every-netlist; this is a third answer neither option covered: **once per
cellview *per gate state*, so a run that is still card-less after the user acted
speaks again.**

### 2. The Save All dialog discards the tick unless OK is pressed

`ase::ui::save_all_dialog` binds the three checkbuttons to `dlg($key,*)` and
commits **only** in `ase::ui::save_all_ok`, which runs from the `OK` button (or
`<Return>`). Every other exit — the `Cancel` button, `ESC` via
`bind_dialog_esc`, the window-manager close — reaches `save_all_cancel`, which
does `array unset dlg $key,opparams` and destroys the window. The tick vanishes
with no indication it was discarded.

That is conventional dialog behaviour, and it is still a trap **here**, because
the dialog's entire content is three checkboxes: a user who ticks one has
expressed the whole intent, and a checkbutton visibly toggling reads as
"applied". Nothing on screen distinguishes committed from discarded.

### 3. Nothing ever confirms the cards WERE emitted

There is a channel for the gate being off (the nudge), for a refusal (0633/0635),
and for under-emission (`last_warnings`). There is **no** message for the success
case. So a user who fixes the gate cannot tell the difference between "it worked"
and "it silently failed again" without descending and pressing `6`.

## What to do

1. **Reset or refine the latch.** Key it on cellview *and* the gate state, or
   clear `op_nudged` in `ase::session_update` when `save_op_params` changes. A
   card-less OP run after the user has touched the setting must speak.
2. **Make the tick's fate visible.** Either commit the three blankets live (no
   OK needed — they are preferences, not a transaction), or say on close that
   changes were discarded. Live-commit is the smaller surprise and matches how
   the rest of the Outputs pane behaves; if OK is kept, the discard must be
   stated.
3. **Confirm success once, quietly.** One line naming the count when cards are
   emitted — `ASE: 468 device OP save cards added` — closes the loop and makes
   0617's diagnosis unnecessary in the common case.

## Landmines

- 0636's latch exists for a real reason: three identical lines per session per
  cell, into a pane and a log people diff. Do not simply delete it.
- `save_op_params` is in `ase::omit_if_empty` and OFF must stay `{}`, never `0`,
  or the key lands in every `.state` a user saves and the 104 committed
  byte-identical fixtures redden.
- The dialog's widget paths (`.allv .alli .levels .btns.proceed`) are what the
  dialog suites drive. Changing the commit model must not rename them.
- A success line must not fire on the `ase::run_existing` path, where the cards
  come from a captured artifact and may not describe this deck (spec landmine 2).

## Acceptance

- Run with the gate off, tick the box, run again with the gate *still* off: the
  second run **says so**.
- Ticking the box and dismissing the dialog by ESC / window close either commits
  or states that it did not.
- A run that emits cards says how many, once.
- The 104 committed `.state` files stay byte-identical.
