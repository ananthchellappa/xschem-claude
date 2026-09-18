# Ledger — outsider fixes batch

**Opened** 2026-09-18 on `fluid-editing`. Receipts land in `receipts/`; a row lands here only
after the driver has checked at least one of its claims.

Safety net for the user's configuration, taken before any stage ran:
`~/.claude/xschem_dotdir_backup_20260918_fixes` (27 files) with a checksum manifest.

| stage | task | crew status | driver verdict | commit |
|---|---|---|---|---|
| S1 | Item 1 — the issue-stamp checker | DONE (`receipts/S1.md`) | **checked**: main tree suite `ALL PASS (60 checks)`, 0 skips, CLI `ok (0 problems)`, HOME=scratch. Two refuters `refuted=false` (`receipts/S1_verify.md`) but both found a **write hazard the fix introduced** (fixture git inherits `GIT_DIR`/`GIT_INDEX_FILE`) → S1-fix before commit | — |
| S1-fix | hermetic fixture git; unreadable state reports red instead of dying; config-hermetic transport; re-initialised export | dispatched | — | — |
| S2a | Item 2 — HOME dependence map + `scratch.tcl` redirect feasibility | DONE (`receipts/S2a.md`) | collected; design adopted with the critic's corrections | — (docs ride with S2c) |
| S2b | Item 2 — design | driver | DONE: `DECISIONS.md` D4–D12 | — |
| S2c | Item 2 — implement (T Tcl / S shell / U suites, parallel) → integrate + canary proof → refute | dispatched | — | — |
| F | T1 gate, CLAUDE.md, commit | driver | — | — |

## Open item for the user

`:99` is held by **the outsider audit's orphaned Xvfb (pid 1209045) and openbox (1209133)**,
started 2026-09-17 23:38 with `HOME=/var/tmp/xschem_outsider_audit/verify_f6/home_t1`, a
directory since deleted. The user's own dev display is not running: its state dir names
`xvfb.pid 1116`, which is dead. Checked: no other process has `DISPLAY=:99`. The driver's
`kill` was refused by the session's permission check, so the user decides. Until then, T1
cannot attach to a dev display here. Under D8 it falls back to a private Xvfb.
