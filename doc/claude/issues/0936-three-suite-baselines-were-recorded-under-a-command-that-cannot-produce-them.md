# 0936 — three suite baselines were recorded under a command that cannot produce them

**STATUS: OPEN — a measurement trap, not a code defect.** Recorded 2026-08-29.
Measured independently by three agents in one session, each of whom stopped to
chase it.

## What happens

A crew brief lists these baselines under the **headless** command
(`./src/xschem --nogui --pipe -q --nolog --script tests/headless/<t>.tcl`):

| suite | brief says | headless really prints | on the dev display |
|---|---|---|---|
| `test_ase_view` | 36 | **32** | 36 |
| `test_ase_persist` | 109 | **17** | 109 |
| `test_ase_plot` | 150 | **30** | 150 |

Each short run prints `gui legs skipped (no DISPLAY)` first. The three numbers
were taken through `tests/headless/devdisplay.sh exec` and written down under
the headless heading.

A fourth, different mismatch in the same list:

| suite | brief says | with the brief's own flags | with logging on |
|---|---|---|---|
| `test_wave_viewer` | 404 | **401** (`--nolog`) | 404 (`--logdir`) |

The gap is exactly three checks, `G1c` at `tests/headless/test_wave_viewer.tcl`
lines 553 / 558 / 560, whose else-branch prints
`SKIP: G1c needs --logdir (the census is a log artifact)`. That is the recorded
"`--nolog` breaks log tests" gotcha, reproduced inside the baseline itself.

## Why it costs real time

Nothing here is red. But a crew that runs the command printed beside the number
sees **four counts that went down** on a tree with nothing wrong with it, and
the standing rule on this branch is that a count that moved is theirs to
explain. Three agents in one session each paid that cost, and each independently
worked out the same answer.

## The durable fix

Record the arm with the number, in whichever file the tier list is generated
from (`doc/claude/ledger/crew.js` carries these strings today), and either drop
`--nolog` from the `test_wave_viewer` line or record 401 as its `--nolog`
count. The suites themselves are fine and need no change: they already announce
the skip on the line above the total.

Not fixed here because the tier list is the orchestration layer's file, not the
repository's, and it was being written by another agent in the same session.

## Sighted again, 2026-08-30 (item S3a)

Three more agents in one session each stopped to chase the same four numbers and
each reached the answer already written above. That is six agents across two
sessions. The `test_wave_viewer` leg was re-measured on both launch forms and is
exactly as recorded here: 401 with `--nolog`, 404 with `--logdir`, both exit 0 and
ALL PASS, the gap being G1c's three log-artifact checks. Nothing in S3a touched
any of these suites. The cost is not going down on its own.
