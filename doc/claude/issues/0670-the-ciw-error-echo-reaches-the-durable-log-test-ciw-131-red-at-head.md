# 0670 — the CIW error echo reaches the durable log; `test_ciw.tcl:131` is RED at HEAD

Status: OPEN, and **RED in the suite right now**. Filed by the 0663 crew,
2026-08-24. Measured at HEAD `ac30edf0` (before any 0663 change) and again after
0663 landed — identical both times, so 0663 neither caused nor cured it.

## Measured

```sh
GUI_GATE=0 DISPLAY=:99 ./src/xschem --pipe -q --logdir $d \
    --script tests/headless/test_ciw.tcl
```

```
RESULT: 1 FAILED
FAIL: no result/error text in file        [tests/headless/test_ciw.tcl:131]
```

Reproduced **five times across three agents** (Measure x3, Implement x2), always
the same single row. The row asserts the durable log must NOT contain
`invalid command name`. It does — `Xschem.log` line 15:

```
#! invalid command name "this_is_not_a_command"
```

## What it means

The CIW's error echo is reaching the **durable** action log with a `#! ` prefix.
`test_ciw.tcl:131` encodes the design intent that the CIW pane's own
result/error echo is a *pane* artefact and does not belong in the durable file.
One of the two is wrong and nobody has ruled which.

This sits in the same neighbourhood as **0664 / 0665 / 0666** (all `notify_safe`
defects introduced by 0658) and looks like 0658-era fallout, but it is **none of
those three as filed** — they are about the degradation claim, doubled durable
lines, and echo raising into its caller respectively. This is a fourth, separate
seam.

## Why it was not fixed by the 0663 crew

Out of scope by the brief (the notify defects were explicitly queued to the next
crew) and unrelated to the startup path. Filed so it is not mistaken for 0663
fallout by whoever next runs the suite: **`test_ciw` was already 1 FAILED before
this work and is 1 FAILED after, with a byte-identical row.**

## Invocation trap, recorded

`test_ciw` **must** be launched with `--logdir <tmpdir>` (it is in
`full_audit.sh`'s `logdir_tests` list, `:84`) and needs X. Without `--logdir` it
fails on a different premise entirely.

## Still open

All of it — including which side is wrong.
