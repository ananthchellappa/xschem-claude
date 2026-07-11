# tests/from_user — wiring-bug evidence corpus

Schematics captured from real user sessions while hardening the fluid-editing /
connected-drag wiring engine (issues `doc/claude/issues/0079-*` … `0111-*`). The
headless and gesture regression tests in `tests/headless/` load these as fixtures;
several are also the oracles for the wireedit predicate pack
(`tests/headless/wireedit/predicates.tcl`).

## Naming convention

| pattern | meaning |
|---|---|
| `before_N.sch` | user pre-gesture state ("fixture generation" N). A generation serves a family of issues: `before_3` → 0085-0090, `before_7` → 0099-0104, `before_8` → 0105-0111. |
| `after_M.sch` | the buggy save as the user's gesture produced it. M is a **global monotone counter** across all generations — next evidence file is max(M)+1. |
| `preferred_M.sch` | hand-authored desired route for the same gesture (the P6 route-quality oracle). |
| `after_M_fixed.sch` | reference save produced by the fixed engine for the same gesture. |
| `beautified_M.sch` | hand-cleaned variant of an `after_M` used for route-quality comparison. |
| `before_7_dual_0104rv.sch` | one-off variant fixture (issue 0104 review); suffix names the issue. |

Unsuffixed `before.sch` / `after.sch` / `beautified.sch` predate the counter scheme.

## Rules

- These files are **evidence — never edit an existing `after_M`/`before_N` in place**;
  add a new counter value instead.
- Commit new evidence files as soon as an issue is filed
  (`doc/claude/WIRING.md` §10) — a clean checkout must reproduce the issue history.
- Autosave backups (`*~.sch`) and scratch logs stay untracked (see `.gitignore`).
- Issue write-ups in `doc/claude/issues/NNNN-*.md` say which fixture + gesture
  (waypoints) produced each `after_M`.
