# 1644 — every measured wave after the first draws the FIRST one's curve

**STAMP:** `v1 claim=open tree=30d304a0 stamped=2026-10-03 fix=untried open=1`

Status: **OPEN**, found 2026-10-03 by the Calculator batch's unit J1b recon, in the tree unit J1
had just shipped. Live from `486a9635`.

Area: `calc::wave_dest` (the column names it mints), `wviewer::resolve_signal_db` and
`wviewer::signal_list_all` in `src/wave_viewer.tcl`, `wviewer::add_trace`'s database argument.
Found: created two destinations and asked each one what its columns are called.

## The defect

`calc::wave_dest` names its two columns `calcx` and `calcy` — **always**, for every destination it
builds — and unit J1 **never drops a destination**, deliberately, because a plotted trace resolves
its database by registry name and freeing it would free what the user is looking at (issue filed as
a `rule` debt: `calc_measured_wave_lifetime`). So coexistence is not an edge case, it is the normal
state after the second measurement.

Measured: two `calc::wave_dest` calls produced `__calc_dest1` and `__calc_dest2`, and
`xschem raw list` against **each** answers the identical `calcx calcy`.

A trace plotted by name goes through `wviewer::resolve_signal_db`, which returns the **first** slot
in `signal_list_all` order carrying that name — current database first, then registry order. So:

> **Measure a duty cycle, plot it, measure a second one, plot it — and the second strip shows the
> first measurement's curve.** Same shape, same numbers, no error, no warning.

The user has no way to tell. Both traces are labelled `calcy`, both look plausible, and the only
symptom is that two different measurements produce identical curves.

## Why no row would have seen it

Every fence on the destination drives **one** destination. The suite reloads its fixture with
`xschem raw clear` between bands, which sweeps the second slot away before any row could notice;
`wd_nslots` is the only row that counts slots at all, and it counts rather than resolves. And the
leak fences cannot see a surviving destination either — they glob temporary **column** names over
the *current* database, while a leaked destination is a registry **slot** whose columns nobody
switches to.

## The fix, and it is already prescribed

Resolve the destination by its **registry index**, never by a bare column name: parse
`xschem raw info` for the slot whose path **and** type match, and hand that index to
`wviewer::plot_dbs_arm` before calling `wviewer::plot_signals`. That is the channel
`wviewer::browser_plot_ids` already uses and the reason `plot_dbs_arm` exists; its own banner says
*"`calc::wave_dest`'s own caller will be the first armer."*

⚠ **So `plot_dbs_arm` is MANDATORY, not optional**, which is the half the destination contract did
not say. Unit J1b carries the fix and a sabotage that omits the arm.

## The second, independent fix worth considering

Even with the index channel correct, **two databases with identical column names is a bear trap**
for anything that resolves by name later — a marker, a cursor readback, a saved schematic's `node=`
token. Giving each destination columns named after the measurement would remove the collision at
the source rather than route around it. That is bound up with the unratified naming question
(`rule` debt `calc_measured_wave_destination_name`), which is why it is recorded here rather than
decided.
