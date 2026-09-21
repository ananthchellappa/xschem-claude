# 0467 — `test_undo_selection` segfaults (signal 11) at teardown, after every one of its checks has passed

**STAMP:** `v1 claim=open tree=0eed8a1b stamped=2026-09-20 fix=none open=1 by=B-docs`

⚠ **THE TITLE IS WRONG AND THIS FILE IS PROPOSED FOR CLOSURE AS A DUPLICATE OF 0227.**
It is not at teardown, every one of its checks has **not** passed, and it has been
diagnosed. See the dated section at the foot — and do not act on the four paragraphs
below without reading it.

Status: **OPEN, measured, NOT fixed, NOT caused by S9b.**
Filed by the S9b crew (op-annotation, branch `annotate`); confirmed unchanged
after S9b landed.

Measured on the unpatched tree (`src/xschem` md5 `bd5381a3e9fd4c2835d23709bac0b7b8`,
no S9 code compiled in): `tests/headless/test_undo_selection.tcl` prints 20 `ok:`
lines and 0 `FAIL`, then dies with `FATAL: signal 11`, rc=1. Deterministic, 2/2
runs identical. It writes an emergency save to `/tmp` (not into the repo).

Why it is invisible: it crashes AFTER printing its `ok:` lines, and it is not in
the `tests/headless/run.sh` golden list, so neither T1 nor T2 counts it.

⚠ For the S9b Verify-A agent: this crash is expected to PERSIST. If it disappears
after S9b lands, that is itself a finding worth chasing, not a win.

## AFTER S9b (2026-08-20)

**BIT-IDENTICAL**: 20 `ok:`, 0 `FAIL`, then `FATAL: signal 11`, rc=1. The crash
neither appeared nor disappeared, which is the required outcome — S9b's four
invalidation hooks sit in `clear_drawing()`, `set_modify()`, `remove_symbols()`
and the raw mutators, all of which this suite exercises, so an unchanged
signature is evidence the hooks are inert on this path.

Still open. Nobody has diagnosed the teardown crash itself.

---

# 2026-09-20 — diagnosed: it is issue 0227, it is not at teardown, and closure is PROPOSED

Appended by the stranger-reds batch from item B's out-of-scope findings
(`doc/claude/stranger_reds_batch/receipts/B-impl.md` §1.4,
`receipts/B-verify.md` §4.3, batch decision **D6**). **Nothing above is edited.** The
original observation stands as what was seen in August 2026; what follows is what it
turned out to be.

## The measurement

**MEASURED twice independently** — by item B's implementer and, separately, by its
`reproduce` verifier — on the **fixed** binary of 2026-09-20, `env -u DISPLAY`,
`--nogui --pipe -q --nolog`, with `handle SIGSEGV stop nopass` so xschem's own signal
handler does not swallow the frame:

```
#0  XGetKeyboardControl () from libX11.so.6
#1  update_statusbar (persistent_command=0, wire_draw_active=0) at callback.c:9891
#2  callback (win_path=".drw", event=2, mx=100, my=100, key=117, …) at callback.c:10093
#3  xschem_cmds_c (… argc=10 …) at scheduler.c:2765
```

Both runs: **20 `ok:` rows, then `FATAL: signal 11`, mid-suite, on an `xschem callback`
row.** The `reproduce` verifier confirmed the implementer's frames independently.

## What that corrects, point by point

| this file says | measured |
|---|---|
| "at teardown" | **mid-suite**, inside `callback()`, at the top of the event dispatch |
| "after every one of its checks has passed" | after **the checks before the crash** — `tests/headless/test_undo_selection.tcl` contains an `xschem callback` line, and the suite stops there. The 20 `ok:` rows are the rows *before* the crash, not the whole file, and no `RESULT:` line is ever printed |
| "Nobody has diagnosed the teardown crash itself" | diagnosed: `update_statusbar()` dereferences the `display` global with no `has_x` guard. It is **issue 0227**, filed 2026-08, and `test_keybind_snap_grid` is the same crash on the same line |

The August reading was reasonable from what it had: `ok:` rows, no `FAIL`, then a death,
with nothing printed to say the file had stopped early. **A suite that crashes mid-run
and a suite that crashes after finishing look identical unless you know how many rows the
file contains** — which is the general lesson here and is worth more than the diagnosis.

## Why it is a PROPOSAL and not a closure

This is somebody's filed observation, and it was an honest one; closing it silently would
take the correction out of the place a reader looks. So the record is deliberately in
both files: **0227** now carries `test_undo_selection` as one of four measured witnesses
and says the closure is proposed here, and this file says what it turned out to be. The
driver or the user takes the closure.

Two practical notes for whoever does:

* **The stamp above deliberately carries no `super=0227`.** `tests/headless/issue_stamp.tcl`
  refuses a `claim=open` file pointing `super=` at another `claim=open` file — *"claims
  super=NNNN replaced it, but NNNN is itself stamped claim=open"* — and it is right to:
  a reader following that pointer would arrive at a defect nobody has fixed either. When
  0227 is fixed, this becomes `claim=duplicate … super=0227` in one edit.
* **Do not lose the fixture.** `test_undo_selection` is the best red-first fixture 0227
  has: deterministic, 20 rows of progress before the crash, and not a T1 case, so nothing
  currently counts it. 0227's section of 2026-09-20 says so.

## What this file was right about

Its 2026-08-20 note — *"⚠ this crash is expected to PERSIST. If it disappears after S9b
lands, that is itself a finding worth chasing, not a win"* — was exactly the right
instinct, and the `BIT-IDENTICAL` re-measurement after S9b is what makes the August
record usable today. It is also why the crash could be attributed with confidence to
something S9b never touched.

## Still open (1)

1. The closure as a duplicate of **0227** is **proposed, not taken** — it needs the
   driver's or the user's word. The crash itself is tracked in 0227 and is deliberately
   not restated here.
