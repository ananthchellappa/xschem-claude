# Track D kickoff prompt (D1 + D2 only)

Paste the block below into a new Claude Code session to start Track D of the hardening sprint,
implementing steps D1 and D2 only. Track D is a pure refactor (byte-identical on the full suite);
D3-D6 are deliberately out of scope for that session.

---

Execute Track D (gesture context + pass table) of doc/claude/suggestions/hardening_sprint_plan.md,
steps D1 and D2 ONLY, in order. STOP after D2 — do NOT start D3.

Before touching anything, read:
- doc/claude/suggestions/hardening_sprint_plan.md — Track D intro + D1 + D2. Note the
  "Track A/B/C DONE" headers: they record premise-corrections made while landing (the plan's
  literal line numbers/repros were wrong 3× in A and 3× in C — expect the same in D).
- ALL of doc/claude/WIRING.md, especially §2.3 (the four START snapshots + the 4 id counters),
  §3 (END pipeline ordering), §7 landmines (#3 re-fetch wire/line aliases after every
  restore/storeobject; #4 the movelastsel=lastsel ritual at 5 sites + ui_state + 4 id counters
  + rebuild_selected_array; #5 snapshot index alignment; #8 stretch_select/fluid_startsel_* freed
  exactly once at real END/ABORT; #9 file-scope statics as hidden parameters WITH VALIDITY
  WINDOWS), §12 R2 (the Fluid_gesture context struct this track builds), §13 symbol map
  (snapshots :2262-2328, restore/discard :5935/5955, invariant check :5869).
- memory files: hardening-sprint-plan (full Track A/B/C map + lessons) and any fluid-* memory
  touching the statics you move (rotate-stretch, drag-* families).

State you inherit (do NOT re-derive):
- Tracks A (CI firewall), B (enforce invariants), C (delta-sweep fuzzer) ALL DONE on branch
  fluid-editing. HEAD is at/after C5 doc-fix 282d8dae. Track C commits: C1 261ed06f, C2 57ac013f,
  C3 37052868, C4 b9131d21, C5 c6f69e37.
- Remote = github (ananthchellappa/xschem-claude); default branch is `main` (not master). The CI
  arbiter is the "Fluid suites gate (xvfb)" step; wireedit + fluid/rotate/cadence gesture tests
  are gated (globbed). PR CI = ci.yaml (Track A suites); the fuzzer runs in the separate nightly
  fuzz-nightly.yaml (goes live only on merge to main).
- NEW verification tooling from Track C: the delta-sweep fuzzer (tests/headless/fuzz/). It is a
  BYTE-IDENTICAL ORACLE for a pure refactor — see "Verification" below.

Track D is a PURE REFACTOR: every step must be byte-identical on the full suite. No behavior
change. Byte-identical has NO partial credit — one leaked static shows as one differing test.

Rules:
- One commit per step (D1, then D2). Each leaves the tree byte-identical and green; push to the
  github remote and watch the "Fluid suites gate (xvfb)" go green before starting the next step.
- If a step's premise doesn't match reality (line numbers drifted, a static isn't where the plan
  says, a reset point can't move where planned without a leak), STOP and update
  hardening_sprint_plan.md in the SAME commit rather than improvising silently. Track A/B/C each
  did this ~3×; the corrections are in-doc.

D1 — Fluid_gesture struct, snapshots first:
- Define `typedef struct {...} Fluid_gesture;` (in move.c initially) holding the four START
  snapshots (fluid_snap_pinnet / fluid_snap_id / fluid_geo_snap_id / fluid_start_wire) + npins;
  one file-scope instance; mechanical rename of every access.
- Add fluid_gesture_arm() / fluid_gesture_free() wrapping the existing snapshot/discard functions
  (:2262 / :5935 / :5955), asserting single-free (make the 7084-7094 discipline structural).
- Done when: full wireedit AND gesture suites byte-identical; valgrind clean via
  `bash tests/headless/wireedit/run_wireedit.sh --memcheck` (0 errors).

D2 — Fold the hidden-parameter statics into the struct:
- Move fluid_startsel_id/nid, fluid_stretch_premove_x/y, fluid_leg_future_dx/dy,
  fluid_slide_pushthrough_on, fluid_jog_doomed_from, fluid_manh_doomed_from, and the saved
  id-counter quad — each with a ONE-LINE comment stating its validity window (one
  place_moved_wire call / one leg / one attempt / one gesture, per WIRING §7.9).
- Move reset points into the lifecycle functions where the window allows. THIS is where
  byte-identical breaks: a reset in the wrong lifecycle spot leaks a stale value into the next
  leg/attempt/call. Watch early returns inside the attempt loop (they leak).
- Done when: `grep -c '^static.*fluid' src/move.c` drops accordingly; suites byte-identical;
  deliberately skipping fluid_gesture_free trips the new assert.

Verification (do this EVERY step, before diagnosing anything):
- Fast headless byte-identical check: run `bash tests/headless/wireedit/run_wireedit.sh` (must
  stay 55/55 ALL PASS). Then run the fuzz sweep as a stronger oracle — a pure refactor must leave
  its verdict matrix AND replay-file set IDENTICAL:
    FUZZ_OUTDIR=/tmp/fuzz_before ./src/xschem --nogui --pipe -q --nolog --script tests/headless/fuzz/fuzz_sweep.tcl
  Run once at the START (baseline), once after each step, and `diff` the matrix + `ls` the fails
  dirs. Any drop that changes verdict = a leaked static, caught in ~60s headless with no CI wait.
  Also run the four fuzz self-tests (test_fuzz_harness_c1/_c2_sabotage/_c3_sweep/_c4_blindspots)
  — all must stay ALL PASS.
- The GESTURE suite (real X) is the other half of byte-identical but WSLg flakes locally and xvfb
  is not installed — the CI xvfb fluid gate is the truth for gesture tests. Push and watch it.

Environment gotchas (all bit prior sessions):
- ALWAYS use absolute paths for builds/test runs (a lingering `cd src && make` verified the wrong
  worktree's binary once). Build from repo root: `make -C /home/qflow/dev/xschem/claude_1/xschem/src`.
- A missing fixture makes a --pipe test HANG (idle), not fail.
- New `xschem` subcommands (none needed for D1/D2, but if you add one) go in the matching
  first-letter dispatch function in scheduler.c, else silently unreachable.
- User feedback channel is ciw_echo, not puts/statusbar.
- Commit ONLY your Track-D files — the working tree has a large pre-existing untracked-junk set;
  `git add` explicit paths, never `git add -A`.

When D1 and D2 are complete, update the plan doc statuses (D1/D2 → DONE with the commit map +
any premise-corrections), update the hardening-sprint-plan memory file and its MEMORY.md
one-liner, then STOP — do not start D3.
