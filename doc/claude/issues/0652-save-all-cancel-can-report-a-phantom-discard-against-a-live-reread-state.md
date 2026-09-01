# 0652 — `save_all_cancel` re-reads live state, so it can report a discard that did not happen — and spuriously re-arm the nudge

STATUS: **OPEN — a NEW defect introduced by 0648's fix**, found by its own
adversary leg (attack A10) before the fix landed, and filed rather than patched
in the write-up pass. Related: 0648, 0636, 0651.

---

## The defect

0648 made a discarded tick speak: on dismissal, `save_all_cancel` compares the
dialog's pending `dlg($key,*)` values against the session's **current** state and,
if they differ, says the change was not applied and re-arms the OP-card nudge.

The comparison re-reads the session state **at dismissal time**, not at
dialog-open time. So if the state changes underneath a dialog left open, the diff
reports a difference that the *user* never made.

**Reachable by a real menu gesture**, not a contrived one: leave Save All open,
then use `Session > Revert` or `Session > Load State`. The reloaded state can
carry `save_op_params 1`. The dialog's pending record still holds the old value.
On dismissal the tool then announces that a setting "was NOT applied" **when it
is in fact applied**, and re-arms the nudge for a session whose gate is on.

Two harms, in order:

1. **The tool asserts a false thing about the user's settings.** At HEAD the path
   was silent and could not lie; the fix gave it a voice and the voice can be
   wrong. That is strictly worse than silence for the class of message whose whole
   purpose is to be trusted.
2. The spurious re-arm undoes 0636's noise control for that cellview, so the
   nudge fires on a run that does not warrant it — teaching the user to ignore it,
   which is exactly what 0636 exists to prevent.

## The fix

**Snapshot the state at dialog-open** and diff the pending values against that
snapshot, not against a live re-read. The dialog already seeds `dlg($key,*)` from
the state in `save_all_dialog`; capture the same three values alongside them and
compare against the capture.

That makes the report answer the question it is actually asking — *did the user
change something and then throw it away* — rather than *does the dialog disagree
with the world right now*, which is a different question with a different answer.

## Landmines

- The snapshot must be cleared with the rest of the `dlg` records, on **every**
  dismissal route — including the WM-close route, which does not currently run
  the cancel path at all (issue 0651), and the two routes 0648's adversary
  measured as bypassing both: reopening the dialog, and closing the session
  window.
- `save_op_params` OFF is `{}`, never `0` (`ase::omit_if_empty`). A snapshot that
  normalises `{}` to `0` would make a no-change dismissal look like a change and
  reintroduce the phantom from the other direction.
- Do not "fix" this by dropping the discard report. SAB-D proves the report is
  load-bearing: neutralise it and `GE10c`, `GE10d`, `GE10g` go red. The report is
  right; its input is wrong.

## Acceptance

- Open Save All, change nothing, dismiss: no discard line.
- Open Save All, tick a box, dismiss: discard line, exactly once.
- Open Save All, tick nothing, `Session > Load State` a state with a different
  `save_op_params`, dismiss: **no discard line and no re-arm** — the user changed
  nothing.
- The nudge latch is re-armed only when the user actually discarded a change.
