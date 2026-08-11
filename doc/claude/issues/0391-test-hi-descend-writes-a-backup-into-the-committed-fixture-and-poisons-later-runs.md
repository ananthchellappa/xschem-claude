# 0391 — a failing `test_hi_descend` leaves `top~.sch` in the committed fixture and poisons every later run

Status: **OPEN** (measured, not fixed) — **harness hazard, high value for automated crews**
Found: 2026-08-10, crew item D6 Verify-B (during the sabotage loop) and independently by Implement.
Area: `tests/headless/test_hi_descend.tcl` — the blocks that work directly on
`tests/headless/fixtures/hi_descend/hidlib/top/schematic/top.sch`; the `set_modify` hook that writes
`<name>~.sch` beside the file; `.gitignore` (backups are ignored, so `git status` never shows it).
Related: **0368** (a Tcl suite that aborts mid-file exits 0), **0384** (the other harness hazard
found in the same run), **0380**/**0381**.

## The defect

Any run of `test_hi_descend.tcl` that dirties the fixture and does not reach its cleanup leaves

```
tests/headless/fixtures/hi_descend/hidlib/top/schematic/top~.sch
```

in the **committed** fixture tree. It is gitignored, so `git status --short` is clean and nothing
warns. The very next run of the same suite then fails, reproducibly:

```
FAIL: HID2 parent not dirtied by view override (modified=1)
```

Observed 3/3 on a tree byte-identical to a known-green one; deleting the stray backup restored
green. So one failing run poisons every later run of the suite until a human notices a file that no
tool reports. During the D6 sabotage loop this cost a full false "the restored baseline is red"
scare, and Implement hit the same thing with a hand-written probe.

## Fix sketch

Do what the newer blocks in the same file already do: copy the fixture library to a `/tmp` work dir
and load from there (the `NAMELESS` block in `test_hi_descend.tcl` and the `GATE-brace` block in
`test_cadence_descend_newwin_ro.tcl` are the pattern). Failing that, the suite should delete
`*~.sch` under `fixtures/` in a cleanup at both ends of the run, and the fixture dir should carry a
`.gitignore`-visible check in the harness so a stray backup is *reported* rather than silently
changing the next verdict.
