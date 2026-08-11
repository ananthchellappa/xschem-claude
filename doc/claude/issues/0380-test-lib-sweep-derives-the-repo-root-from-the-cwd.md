# 0380 — `test_lib_sweep.tcl` derives the repo root from the cwd, so it only passes from `src/`

Status: **OPEN** — measured 2026-08-10 (item D5). Pre-existing; unrelated to the descend work.
Area: `tests/headless/test_lib_sweep.tcl`
Found: while running the descend suites from the repo root.

## The defect

The suite computes its repo root as `set repo [file join [pwd] ..]`, i.e. it assumes the process
cwd is `src/`. Run from the repo root — which is how every other headless suite in this tree is
invoked, and how `full_audit.sh` and the CLAUDE.md recipe invoke them — `$repo` points one level
*above* the checkout and the library sweep finds nothing:

```
5 FAILs, all of the form "missing cells for devices" (x12)
```

Those FAILs are **pure invocation error, not a product defect**, which makes them exactly the kind
of noise that trains a reader to ignore a red line.

## Fix shape

Derive the root from the script's own location, the way the sibling suites do, e.g.
`file normalize [file join [file dirname [info script]] .. ..]`, rather than from `[pwd]`. Add the
suite to whatever gated list it belongs on once it is invocation-independent.
