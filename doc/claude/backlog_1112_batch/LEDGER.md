# Backlog batch 2026-11-12 — LEDGER

Base: e615a1801 (fluid-editing). One row per stage when its receipt is collected.

| stage | item | crew receipt | verifier | T1 gate | commit |
|---|---|---|---|---|---|
| A | 1 seed steps aside | receipts/A-seed.md (3 passes: base, preview gap, verifier D1-D4) | receipts/A-verify.md: D1 blocked, fixed; re-verify clean, 4 warning-only misses + sabotage Y1 recorded | ~/gc26 results.2828742.log 197/0/skips=13 (private :100) | 5f88a7c65 |
| B | 3 T1 never waits for :99 | receipts/B-t1display.md (T1_DISPLAY knob, /proc-identity detector, hcases follow the arm; test_t1_display_arm) | receipts/B-verify.md: one defect (no-display run still handed :99 state dir to hcases), fixed + row TD12 | ~/gdb results.3626261.log 198/0/skips=10 (T1_DISPLAY=private, :100) | c24560855 |
| C | 4 more device limits | receipts/C-devlim.md (IHP R/C provider, setprop through devlim_clamp, gf180 _dss 3v3 + 6v0 W/Lmax; Lmin owed as rule gf180-dss-lmin) | receipts/C-verify.md: four cited limits unfenced, rows widened | ~/gdc results.3785324.log RED 7 (SP rows counted the --logdir action-log mirror of each setprop; SP recorder now keeps `warning: ` lines only, like FL) -> results.3884743.log 199/0/skips=11 (T1_DISPLAY=private; +1 skip is d67644607's FL rows headless) | 56e387860 |
| D | 2 dead-gated checks | receipts/D-deadgates.md (no second dead gate by runtime census; 2 dead upstream leftovers left in place; A22 census counted a comment -> issue 1712, test fixed) | receipts/D-verify.md: not refuted; suite given OVERALL sentinel and registered in dcases | ~/gdd results.4129483.log 200/0/skips=11 (T1_DISPLAY=private) | 395ab7442 |
| E | follow-up: run_suites.sh/full_audit.sh step aside | receipts/E-launchers.md (detector moved to tests/headless/dev_display_users.tcl, shared by T1 and xvfb_arm.sh; AUDIT_DISPLAY=auto\|dev\|private) | receipts/E-verify.md: unbounded helper call (now timeout, TL10), no-xvfb-run fallback to inherited DISPLAY (now unset, TL11), AUDIT_DISPLAY=dev holder unfenced (TL5 leg) | ~/gde results.536155.log 200/0/skips=11 (T1_DISPLAY=private) | (this commit) |
