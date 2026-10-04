# 1647 — `test_wave_sigbrowser`'s display arm flakes on three gesture rows, announcing nothing

**STAMP:** `v1 claim=open tree=060c6d77 stamped=2026-10-03 fix=none open=2`

Status: **OPEN**, characterised 2026-10-03 while deciding issue 1645's registration shape.
Area: `tests/headless/test_wave_sigbrowser.tcl` rows `BT43`, `BT44`, `BM43`.

## What was measured

The suite's **display** arm (`tests/headless/run_suites.sh test_wave_sigbrowser`, which routes to
the Xvfb dev display) was run **30 times**. It came back **red 3 times**, on `BT43`, `BT44` and
`BM43`, and green 27 times at `ALL PASS (353 checks)`. The **counted** arm
(`--nogui`) was green throughout at `ALL PASS (135 checks)`.

⚠ **The failures announce nothing.** There is no `skip:` line, no `SKIP`, no `TIMEOUT` — the rows
simply report a wrong value. So a verdict carrying this failure says `counted_failures=N` with no
indication that the cause is intermittent, which is exactly the shape that costs a gate re-run
before anyone suspects a flake.

## Why this is filed rather than fixed

Per D8 this is a characterised observation, not a diagnosis: **nothing has been changed for it**,
and nothing was retried, lengthened or skipped — that would make it invisible rather than legible,
which is the handling `test_ase_optier_0963`'s paragraph in CLAUDE.md explicitly refuses.

It is filed because it **changed a decision**. Issue 1645 asks where to register this suite. A
`dcases` entry imports a ~10% failure rate into a 650-second gate; the precedent,
`test_ase_optier_0963`, has cost four gate re-runs. The suite was therefore registered in `hcases`
**alone**, with the display arm's 218 extra checks deliberately left outside the gate, and the
coverage they carried moved onto the counted arm instead (see issue 1646's leg-4 repair). That is a
knowing trade and it is recorded here so nobody reads the `hcases`-alone shape as an oversight.

## What the next occurrence should do rather than re-run

Three gesture rows, one of them in a different band from the other two, is a narrower signature
than `test_ase_optier_0963`'s. Before spending runs:

1. Determine whether the three share a **fixture** — a window that must be mapped, a canvas that
   must have a size, a `<Configure>` that must have arrived. An empty Xvfb does not reparent and
   silently no-ops `wm iconify`; a WM fixes both, and **an absent WM falls back silently with only
   a stderr warning**. Record which WM was live (`AUDIT_WM=openbox`, `/usr/bin/openbox` 3.6.1).
2. Make the failure **say** something. A row that reports a wrong value where the true cause is an
   unmapped window is misdescribing itself; `test_ase_optier_0963`'s `NORAW rc={…} wall={…}ms`
   diagnostic is the precedent for making the next occurrence explain itself in the verdict
   instead of needing five re-runs.
3. Only then decide whether the row or the product is the suspect.

## Outstanding

1. Whether the three rows share a fixture precondition that is not being waited for.
2. Whether the display arm can be registered once it is stable, recovering the 218 checks.
