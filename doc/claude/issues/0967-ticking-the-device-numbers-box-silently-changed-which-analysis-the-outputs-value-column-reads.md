# 0967 — ticking the device-numbers box silently changed which analysis the Outputs Value column reads

**Status:** FIXED (2026-08-30, item S4's repair pass)
**Superseded in part:** the question this issue deliberately did NOT answer —
*which* analysis the Value column reads — was ruled by the user on 2026-09-02
and is issue **1243**. The prints now follow the operating point. What survives
here is 0967's own claim: the anchor comes from the ENABLED SET, so the
device-numbers tick cannot move it.
**Found by:** the S4 sabotage pass, as an unguarded behaviour change — no
committed row could see it.

## What the user sees

The Outputs pane has a **Value** column, filled in after a run from the `print`
lines the deck carries for every output the user ticked **save** on. Issue 0964
moved the operating point to the END of the analysis order whenever the device
operating-point requests move inside the control block — that is, whenever the
user ticks **Save All > save device operating-point parameters** on a run that
has more than one analysis in it.

`print` reads whichever plot the simulator is standing in, and the deck's
`print` lines sit after every analysis. So moving the operating point last also
moved what the Value column is showing:

| Save-device-numbers tick | analyses in the control block | Value column for `v(out)` |
|---|---|---|
| off | `op`, `tran`, then the prints | empty — a transient print is a table, and the reader only accepts `<expr> = <number>` |
| on  | `tran`, `op`, then the prints | `1.800000e+00` — the DC operating point |

Measured on an op+tran bench with one saved output. The simulation log the CIW
points the user at changed the same way: one scalar line where it held a table.

That is a number appearing next to a row because of a checkbox about something
else entirely, with nothing said — ruling D5-1's class. Neither value is
labelled with the analysis it came from, so the user cannot tell.

## The fix

`src/ase.tcl`, the ngspice backend's `render_deck`: the `print` lines are now
emitted immediately after the write of the analysis that is **last in the
canonical `op dc ac tran` order**, rather than after whatever ran last. When
nothing was reordered the two are the same analysis and the deck renders
**byte-identically** — which is what keeps the committed deck goldens green.
When the operating point was moved last, the prints stay with the analysis they
have always read.

## The rows

`tests/headless/test_ase_optier_0963.tcl` section P.

* **P1** — with the reorder in force the printed outputs still read the
  transient: `tran`, the prints, then the device requests and `op`.
* **P2** — the control, with the tick off: the prints are last, after `op`,
  exactly as before.
* **P3** — an operating-point-only run and a deck with no analyses at all put
  the prints in the same place they always were.
