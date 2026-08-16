# 0408 — `test_label_ride.tcl` writes a fixed-path fixture (not parallel-safe) and row V22 flakes under load

Status: **OPEN** — measured, NOT fixed. Test-harness hygiene, filed by crew item **D10**
(Verify-A and Verify-C both hit it, from opposite directions).
Area: `tests/headless/test_label_ride.tcl` — `:548`
`set ::rfsch [file join [file dirname [info script]] _label_ride_rf.sch]`, and row V22 at `:678`.
Related: `doc/claude/WIRING.md` (sabotage/measurement discipline), the gated-tier list in every
crew brief — `label_ride` is one of them, at 157 checks.

## Two observations, one suspected shared cause

**(a) Not parallel-safe.** The fixture path is fixed and lives *in the test directory*, not in a
per-PID scratch dir. Two headless suites running concurrently write and delete the same
`tests/headless/_label_ride_rf.sch`: the adversary agent ran two `Bash` batches at once and saw
`test_label_ride` abort, and — worse — the *next, sequential* run stay red until the stale file was
cleaned. Re-run strictly sequentially, it is `ALL PASS (157)` three times in a row.

**(b) Row V22 flakes.** Verify-A measured `V22 40 orientation x transform cells all agree`
returning a nonzero disagreement count (`{4}` once, `{1}` once) — tier 157 → 156, `OVERALL: notok` —
**2 failures in 16 runs against a byte-identical binary** (`md5 d8f471d7eb014c21f5a815957db97c4e`
verified before and after every batch). 10/10 consecutive passes on a quiet machine; both failures
fell inside a window when other crew agents were active.

(b) is *not* explained by (a) — a fixture collision aborts the script, it does not return a wrong
agreement count — so this issue records two symptoms and one confirmed cause. The V22 nondeterminism
is unexplained and is the more important half.

## Why it matters

`label_ride` is a **gated tier**: a crew item that changes nothing in its path can still be handed a
red tier and be wrongly reverted, or a real regression can be waved off as "the flake". Either way
the run substrate is replay/autograding, and a tier that is not deterministic is not a gate.

Ruled out as a cause of the flake: item D10's own change (issue 0266). V22 drives only
`move_objects 0 0 $mr $mf -anchor 0 0 kissing`, whose `argv[2]`/`argv[3]` are the literal `0` `0`,
which the new validator accepts deterministically; the change adds pure `argv` inspection and no
state.

## Fix sketch

1. Move the fixture to a per-PID path (`_label_ride_rf.[pid].sch`, or the scratch dir the other
   suites use) and delete it in a `finally`-shaped cleanup, so concurrent runs cannot collide and a
   crashed run cannot poison the next one.
2. Then chase V22 on its own: log the four transform cells that disagreed rather than only the
   count, and run it in a loop under artificial load until it reproduces.
