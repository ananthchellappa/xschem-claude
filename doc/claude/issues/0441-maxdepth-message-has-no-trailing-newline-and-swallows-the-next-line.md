# 0441 — `descend_schematic(): max hierarchy depth reached` prints with no trailing newline and glues itself onto the next output line

Status: OPEN, measured, not fixed. Filed by the S3b implement agent
(op-annotation crew, branch `annotate`). Discovered while running the S3b
sabotage matrix; unrelated to the annotation feature.

Related: the results.log reading rule in CLAUDE.md ("a `FAIL` ending a line, a
`GOLD?`, a `RESULT?`, or a leading `FATAL` counts"), issue 0420 (the sibling
sentinel-regex defect in `run_regression.tcl`).

## What was measured

`src/actions.c:3859`

```c
dbg(0, "descend_schematic(): max hierarchy depth reached: %d", CADMAXHIER);
```

and its twin `src/save.c:6165`

```c
dbg(0, "descend_symbol(): max hierarchy depth reached: %d", CADMAXHIER);
```

Both lack the `\n` that every neighbouring `dbg(0, …)` in those files carries.
`dbg` writes straight to the stream, so the message concatenates with whatever
is printed next. Observed verbatim in a
`tests/headless/test_op_annot.tcl` run whose fixture recurses to CADMAXHIER=40:

```
descend_schematic(): max hierarchy depth reached: 40ok:   S15 0433 the recursive walk terminates, …
```

and, in a sabotaged variant of the same run, on a FAILING line:

```
descend_schematic(): max hierarchy depth reached: 40FAIL: S15 0433 the recursive walk … : FAIL
```

## Why it matters beyond cosmetics

The second form is the finding. A reader grepping `^FAIL` — which several
suites, several harness scripts and every ad-hoc `grep -E '^FAIL'` in this
crew's transcripts use — **does not see that line**. The count printed by the
suite's own verdict (`RESULT: 6 FAILED`) and the count a `^FAIL` grep returns
(5) disagree, and the disagreement is silent. The documented `FAIL$` rule
survives this particular case, but only because `check` happens to put a second
`FAIL` at the end of the line.

Any C-side `dbg(0, …)` reaching stdout during a test run can hide the first
character of the next line; these two are simply the pair a hierarchy walk
reaches routinely.

## The fix, not applied here

Append `\n` to both format strings. It is a two-character C change in a file
S3b does not otherwise touch, and this crew's step is pure Tcl — filing rather
than fixing, per the crew rule that a discovered defect is never fixed silently.
Whoever takes it should also `grep -n 'dbg(0,' src/*.c | grep -v '\\n"'` for the
rest of the family.
