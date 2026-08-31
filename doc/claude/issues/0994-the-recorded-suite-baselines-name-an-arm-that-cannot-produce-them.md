# 0994 — the recorded suite baselines name an arm that cannot produce them

**Status** OPEN, filed 2026-08-30 by item S4d's write-up pass. **Class** a
standing red that is really furniture — the shape CLAUDE.md names as the one
place a real regression hides in plain sight. **Not fixed here**: the numbers
live in a harness file another hand already has uncommitted edits in, so this
records the measurement rather than editing under them.

## The claim, and why it is not pedantry

`doc/claude/ledger/crew.js:167-176` hands every crew member a TIER LIST that
prints a command and, under it, the check counts that command must produce.
For four of the suites the counts and the command belong to **different arms**,
so the tier list can never be satisfied by the command it prescribes.

The next hand who runs it as written sees four suites "below baseline" and has
two choices, both of which are the documented failure mode: re-derive the arm
split from scratch, or wave the shortfall through as known-red. CLAUDE.md's own
rule is that a standing red is a defect, not furniture, and that this branch has
already shipped two defects past twenty-eight passing checks.

## Measured 2026-08-30 on binary md5 `803c30c8364c93f3eb2f4e81f6601bf1`

Every number below was taken by this pass, both arms, same binary, same session.

| suite | tier list says | `--nogui --pipe -q --nolog` | `devdisplay.sh exec ... --pipe -q --nolog` |
|---|---|---|---|
| `test_ase_view`    | 36 under the headless heading  | **32** | **36** |
| `test_ase_persist` | 109 under the headless heading | **17** | **109** |
| `test_ase_plot`    | 150 under the headless heading | **30** | **150** |

All three self-skip their Tk-dependent blocks under `--nogui`, which is correct
behaviour — the suites are right and the recorded arm is wrong. The tier list
prints these three under the **headless** command while the numbers are
**display-arm** numbers.

Fourth case, a different mechanism with the same effect:

| suite | tier list says | `--nolog` (the tier's own flag) | `--logdir <dir>` |
|---|---|---|---|
| `test_wave_viewer` | 404, Tk-only, `--nolog` | **401** | **404** |

The 3-check gap is one block gated on a log directory —
`tests/headless/test_wave_viewer.tcl:563` prints
`SKIP: G1c needs --logdir (the census is a log artifact)`. So 404 is the
**`--logdir`** count and the tier list pairs it with `--nolog`, which cannot
reach it. (The X8 slot-exhaustion probe self-skips on the display arm in both
runs and is *not* part of the gap.)

Fifth, a stale count rather than a wrong arm:

* tier list: `run_regression.tcl` — "**46 blocks**".
* measured today, run solo: **53 blocks**, every one `Total num fail: 0`, zero
  counted failures, zero launch failures. The suite has grown since the
  2026-08-29 measurement at `0e6cb3cb`; nothing about what passes has changed.

## Corroboration

This was found independently **four times in one item** — by both no-build
verify passes, by the sabotage pass on the restored binary, and again here.
Four hands each spent effort deciding whether four suites were red. That cost is
the defect, and it recurs every crew until the file is corrected.

## What the fix is

In `doc/claude/ledger/crew.js`'s `TIERTEXT`:

1. Move `test_ase_view 36`, `test_ase_persist 109` and `test_ase_plot 150` under
   the Tk-only heading, **or** name the arm beside each number.
2. Record `test_wave_viewer` 404 as its `--logdir` count — either by putting
   `--logdir` in the Tk-only command or by annotating the number.
3. Take the `run_regression.tcl` block count from 46 to 53.

Best shape, and the reason this is worth more than a text edit: the tier list
should carry **the arm as data beside each number**, not as a heading a reader
has to associate. A heading is what let three numbers drift under the wrong one.

## Deliberately not done here

`doc/claude/ledger/crew.js` had **uncommitted edits from another hand** when this
item started (`git status` at S4d's open). Editing it would either clobber that
work or entangle this item's commit with a ledger change that is not its
subject. Filed for whoever owns the harness config.

## Related

* CLAUDE.md, "T1's baseline is ZERO counted failures" — the standing-red rule
  this issue is an instance of, including the count of how many times 0689 and
  0690 were re-filed by hands re-deriving the same waved-through red.
* Issue 0990 — `run_regression.tcl` run concurrently manufactures a `FATAL`;
  a different way the same suite's baseline stops meaning what it says.
