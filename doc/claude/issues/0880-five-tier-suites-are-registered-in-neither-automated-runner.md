# 0880 — five of the twelve suites this feature is gated on are registered in NEITHER automated runner

Status: 🔴 **OPEN** — measured 2026-08-27 by the A3h write-up, confirmed
pre-existing at `HEAD` (`868a8df5`). **Not caused by any A3/A3h change**, and
deliberately not fixed in the A3h commit: silently editing a shared harness's
test list inside a hardening commit about four other issues is the kind of
unrelated scope this tracker exists to prevent.

Class: **a guard no runner can see** — the same shape as issue **0409**
(`test_cadence_drag` red and wired into no harness) and **0147** (the suite that
ran nothing and printed a plausible `results.log`).

## The finding

`CLAUDE.md` states the invariant plainly:

> Register it in TWO places (`grep -c` each, expect 1): `tests/headless/full_audit.sh`'s
> `nogui_tests` string, and `tests/run_regression.tcl`'s `hcases`.

Measured across the twelve suites the OP/transient annotation feature is gated
on, `grep -c <name>` in each runner:

| suite | checks | `full_audit.sh` | `run_regression.tcl` |
|---|---|---|---|
| `test_op_annot` | **413** | **0** | 1 |
| `test_backannotate_digital` | 84 | 1 | 1 |
| `test_zero_point_raw_0836` | 73 | 1 | 1 |
| `test_zero_point_pos_at_0852` | 41 | 1 | 1 |
| `test_raw_read_dispatch` | 137 | 2 | **0** |
| `test_raw_ascii_point_bounds` | 90 | 2 | **0** |
| `test_raw_read_failure_0306` | 63 | 2 | **0** |
| `test_wave_cursor_crossdb` | 93 | 1 | **0** |
| `test_wave_markers` | **437** | **0**† | **0** |
| `test_wave_viewer` | 57 | **0** | **0** |
| `test_annot_show_menu` | 29 | **0** | **0** |
| `test_ase_window` | 221 | **0** | **0** |

† `test_wave_markers` greps 1 in `full_audit.sh`, but **the only hit is a
comment**, at `tests/headless/full_audit.sh:50`:

    # 300, not 120: test_wave_markers legitimately needs 61-149 s, so the old

It is not in `nogui_tests` (`:161`). A bare `grep -c` scores it registered; it is
not. That is the same substring-versus-line trap issue **0350**/**0354** fixed
inside this very file's predicates, reappearing in how a human *reads* the file.

**Five suites — `test_wave_markers`, `test_wave_viewer`, `test_annot_show_menu`,
`test_ase_window`, and (in `full_audit` only) `test_op_annot` — carry 1157
checks between them and run only when a person types their name.**

## Why it is not merely untidy

`test_op_annot` is this feature's entire row set. It is the suite that grew from
358 to 413 rows across issues 0868/0869/0872/0873/0874/0878, and it is the suite
carrying every acceptance row for RULING **0856**, RULING **D5-1** and RULING
**D4-4**. It **is** in `run_regression.tcl`'s `hcases`, which is the authoritative
gate, so the risk is bounded — but `full_audit.sh` is the script whose whole
purpose is "did anything break anywhere", and it does not know this suite exists.

`test_annot_show_menu` and `test_ase_window` are Tk-only and self-SKIP under
`--nogui`, so `nogui_tests` is the wrong list for them — but `full_audit.sh` has
GUI lists too, and they are in none of them.

## What a fix costs, measured

`test_op_annot` runs in **2.98 s** headless. `full_audit.sh`'s per-test budget is
`AUDIT_TIMEOUT`, default **300 s** (`:52`), so it fits with three orders of
magnitude to spare. `test_wave_markers` is the one with a real cost — the comment
at `:50` records 61–149 s, which is why the default was raised to 300 — and it is
also the largest unregistered suite at 437 checks.

## Options

1. **Add the four headless suites to `nogui_tests`** and the two Tk suites to the
   matching GUI list. Cheapest, and it is what the house rule already demands.
   Cost: `full_audit.sh` gains ~150 s of wall clock, nearly all of it
   `test_wave_markers`.
2. **Add them, and give `test_wave_markers` its own longer budget.** The comment
   at `:50` shows the file already reasons about per-test cost; nothing yet lets
   it *express* one per test.
3. **Leave `full_audit.sh` alone and rely on `run_regression.tcl`.** Then the
   house rule's "TWO places" sentence is wrong as written and should be amended
   to say which runner is authoritative for which kind of suite — because today a
   crew that follows it and a crew that reads the file reach different answers.

Recommended: **1**, plus a `grep -c` that is anchored the way this file's own
`line_has()` predicate is, so a comment can never again score as a registration.

## Acceptance

A row — in the audit's own self-test, `test_audit_classifier.tcl`, which already
locks the banner rule across all three readers (section K) — asserting that every
name in `run_regression.tcl`'s `hcases` also appears in `full_audit.sh`'s
`nogui_tests` **as a whole word inside that string**, not merely somewhere in the
file. That row is what would have caught this, and it would have caught 0409 too.
