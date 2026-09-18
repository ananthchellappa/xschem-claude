# Ledger — outsider fixes batch

**Opened** 2026-09-18 on `fluid-editing`. Receipts land in `receipts/`; a row lands here only
after the driver has checked at least one of its claims.

Safety net for the user's configuration, taken before any stage ran:
`~/.claude/xschem_dotdir_backup_20260918_fixes` (27 files) with a checksum manifest.

| stage | task | crew status | driver verdict | commit |
|---|---|---|---|---|
| S1 | Item 1 — the issue-stamp checker | DONE (`receipts/S1.md`) | **checked**: main tree suite `ALL PASS (60 checks)`, 0 skips, CLI `ok (0 problems)`, HOME=scratch. Two refuters `refuted=false` (`receipts/S1_verify.md`) but both found a **write hazard the fix introduced** (fixture git inherits `GIT_DIR`/`GIT_INDEX_FILE`) → S1-fix before commit | — |
| S1-fix | hermetic fixture git; unreadable state reports red instead of dying; config-hermetic transport; re-initialised export | DONE | refuter **refuted=true**: hermetic writes hold (victims byte-identical under GIT_DIR, hook GIT_INDEX_FILE, hostile config); the new `foreign` state **fails open** (rewritten history and corrupt clone green, verifying nothing) and `git init` alone goes red | — |
| S1-fix2 | positive-evidence per-stamp rule, fail-closed; H7; fixture seal vs ignore/attributes/quarantine; `%41`; no death before RESULT | DONE | refuter **refuted=true**: H7, seal, `%41`, unborn and no-death hold, but the date rule fails OPEN (a stamp's own `stamped=` typo exempts a bogus `tree=`; graft, orphan and root-date rewrite likewise) → D14 | — |
| S1-fix3 | D14: remove the date rule, keep the rest; the red explains a re-init; stderr warnings are not failures | DONE | refuter **refuted=true**: D14 holds (full/unreadable never skip; main tree 71/71, 0 skips) but `shallow` is repository-wide, so an off-path `fetch --depth 1` exempts a bogus stamp; also a dangling `.git` link, an amended-away stamp, `quote=--output` argument injection, and unparsed fences → D15 | — |
| S1-fix4 | D15 | DONE | refuter **refuted=true**: every git-side claim reproduces (injection via git closed, ancestry, lstat, off-path boundaries), but `assert=` `pat=` reaches Tcl `exec` as a redirection/pipe (truncate, write, **run a program**, green), a no-op `fetch --depth 1` still fails open, 4-backtick fences and `__STAMP:__` pass silently → D16 | — |
| S1-fix5 | D16 | DONE | refuter **refuted=true**: every exec/injection recipe closed (nothing written or run), shallow family correct, parser identical over 1047 files; but a non-UTF-8 filename is silently skipped (regression), unread `assert=` blocks are silent, disguised stamps (NBSP/HTML/table) pass, a symlinked issue file is followed out, `md_strip` is quadratic → D18 (threat model) | — |
| S1-fix6 | D18 | dispatched | — | — |
| S2a | Item 2 — HOME dependence map + `scratch.tcl` redirect feasibility | DONE (`receipts/S2a.md`) | collected; design adopted with the critic's corrections | — (docs ride with S2c) |
| S2b | Item 2 — design | driver | DONE: `DECISIONS.md` D4–D12 | — |
| S2c | Item 2 — implement (T Tcl / S shell / U suites, parallel) → integrate + canary proof → refute | DONE (receipts S2c-T/S/U/I) | armed commands **proven** (canary byte-identical, red-first; T1 87/86/**0** with DISPLAY set; all 402 shared suites same verdict and check count). Refuted (`receipts/S2c_refute_r1.md`): unarmed documented entry points, cwd autosave overwrite, sweep/handoff/KEEP holes, H1b by number → D13 | — |
| S2c-R2 | D13 items: T (Tcl) ∥ S (shell) → integrate + proof → refute | DONE (receipts S2c-R2-*, `S2c_refute_r2.md`) | core **proven by both refuters**: T1 87/86/0 in main-tree shape, canary byte-identical (seeded AND empty), auto-start env clean, attach identical, pairs green, 84/84 shared results identical. Refuted on edges: 3 more unarmed documented scripts, reaper start window, `devdisplay.sh stop` kills by recorded pid, relative TMPDIR, nesting forgery, V3 row gap → D17 | — |
| S2c-R3 | D17 | dispatched | — | — |
| F | T1 gate, CLAUDE.md, commit | driver | — | — |

## Open item for the user

`:99` is held by **the outsider audit's orphaned Xvfb (pid 1209045) and openbox (1209133)**,
started 2026-09-17 23:38 with `HOME=/var/tmp/xschem_outsider_audit/verify_f6/home_t1`, a
directory since deleted. The user's own dev display is not running: its state dir names
`xvfb.pid 1116`, which is dead. Checked: no other process has `DISPLAY=:99`. The driver's
`kill` was refused by the session's permission check, so the user decides. **Resolved 06:1x:
the user ran the kill; both are gone and `:99` is free.**
