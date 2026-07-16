# Issue 0084 — test_action_replay.sh: "log missing placed instance" (pre-existing)

**Opened:** 2026-07-08
**Status:** OPEN (branch `fluid-editing`).
**Severity:** test regression (one check), scope unknown — may indicate a real action-logging gap
(a placed instance not recorded → replay incomplete), or a stale test expectation.

## Observation

`sh tests/headless/test_action_replay.sh` → `RESULT: 1 FAILED`, failing check:
`FAIL: log missing placed instance` (the gesture-driven place-instance action does not appear in
the recorded Xschem.log). The two adjacent gesture checks (`log has gesture wire`,
`log has gesture rect`) pass, and the replay equivalence checks
(`replayed state matches recorded state`, `replayed schematic file is byte-identical`) pass — so
whatever is missing from the log is ALSO missing from the recorded reference state, or the
instance is logged in a different (absorbed?) form the grep does not match.

## Not caused by the 2026-07-08 cleanups

Verified by building `dd66b292` (before the recent-files-protection / launch-line commits) in a
fresh worktree: the same single check fails there. Suspect window: any commit since the last time
this suite was green (possibly the action-log absorb / outcome-level logging work — an absorbed
`place instance` line would change its logged shape and break the test's grep while keeping
replay equivalence green, which matches the symptom exactly).

## Next steps

- Bisect from the last known-green run of `test_action_replay.sh`.
- Read the failing grep in `tests/headless/test_action_replay.sh` vs the actual Xschem.log line
  produced for a placed instance today; decide test-update vs logging fix.
- If the instance-place line was absorbed into an outcome-level command (see
  `doc/claude/specs/action_log_absorb.md`), update the test to accept the absorbed form.
