# Green-but-hollow: when a passing suite proves nothing

A practice note for developers and for LLM coding agents, distilled from a
real incident in the stable-object-handles work (Phase C, 2026-06-12).
Short version: **a test suite can be 100 % green while the code you changed
never executes.** Green tells you "nothing I observed broke"; it does not
tell you "I observed the thing you changed."

## The incident, in four beats

1. We were about to refactor xschem's four wire-*split* sites (code inside
   `trim_wires` / `break_wires_*` in `check.c`) behind a single helper. The
   characterization suite contained tests that ran exactly those commands
   on a rich 91-wire example schematic and asserted wire counts. All green.
2. The trap: the example schematic is *well-formed* — nothing to trim,
   nothing to break. `trim_wires` ran and did **nothing**: 91 wires in,
   91 wires out, assertion `count == 91` green. The refactored split code
   was never reached. The suite would have stayed green if the splits had
   been replaced with `abort()`.
3. The fix: five synthetic cases purpose-built to force each split branch —
   a T-junction (a wire ending mid-span of another) for the trim split, a
   `wire_cut` at a projected point, a break-at-selected-wire. Each asserts
   the *exact resulting segment set*, not just a count.
4. The payoff beyond safety: verifying those new tests against the
   **pre-refactor build first** (stash the change, rebuild, run) falsified
   one of our own expectations — `wire_cut` no-ops on a freshly scripted
   schematic because the wire spatial hash is stale until
   `rebuild_connectivity` runs. That is real system knowledge, found *by*
   the discipline, that no amount of green had surfaced.

## Why this bites LLM agents harder than humans

- **Plausible scaffolding is cheap.** An agent generates a fluent test
  suite in minutes; fluency reads as rigor. Nobody (including the agent)
  re-derives whether the asserted condition could *fail* under the change
  being protected against.
- **Rich fixtures feel thorough and are the opposite.** A big real-world
  example is the *least* likely input to exercise repair/edge paths,
  precisely because real saved files are well-formed. Edge code needs
  hostile inputs, which must be constructed, not found.
- **"Suite green" is a strong reward signal.** Agents (and tired humans)
  pattern-match it as "safe to proceed." Without a deliberate
  red-check, green is consumed as confirmation rather than interrogated.
- **No execution feedback by default.** A human stepping through a
  debugger notices the breakpoint never hits. An agent running a headless
  suite sees only PASS lines. Unless reachability is made an explicit
  obligation, it is invisible.

## The discipline (checklist form)

Before trusting a green suite to protect a change:

1. **Ask the falsification question.** For each test guarding the change:
   *what modification to the code under test would make this fail?* If the
   honest answer is "removing the code entirely would not", the test is
   hollow for this purpose (it may still be a fine test of something else).
2. **Prove the suite can go red.** At least once, run the guarding tests
   against a build where the protected behavior is absent or broken. Three
   cheap ways, best first:
   - *stash-verify* (what we did): `git stash push <changed files>` →
     rebuild → run → expect identical green (for characterization tests,
     this also proves they describe the old system, not your expectations)
     → pop. For new-feature tests, expect **red** here — that is TDD's
     red phase doing its real job.
   - *sabotage run*: deliberately break the new code path (early return,
     wrong constant), confirm red, revert. Mutation testing is this,
     industrialized.
   - *coverage probe*: gcov/llvm-cov, or even a `dbg()` counter, showing
     the changed lines execute under the suite.
3. **Assert deltas and exact outcomes, not non-change.** "Count unchanged
   on a well-formed input" is a no-op detector, not a behavior lock.
   Prefer: exact resulting object set, exact diff against a baseline
   snapshot, exact error message.
4. **Construct minimal hostile inputs per branch.** One synthetic fixture
   per code path you claim to cover (our T-junction = the split branch).
   If you cannot construct an input that reaches the branch, say so out
   loud in the test file — "covered by identical helper body, reachability
   not demonstrated" is honest and reviewable; silence is not.
5. **When a reachability test fails on the *old* code, mine it.** It means
   the system has a precondition you did not know (our stale spatial
   hash). Encode the precondition in the test with a comment; you just
   documented real behavior nobody had written down.

## The two questions that summarize it

Every "tests pass" claim should be able to answer:

- **Did the changed code run?** (reachability)
- **Would the suite notice if it ran wrong?** (sensitivity)

Green answers neither by itself. The stash-verify / sabotage run answers
both in one cheap step, which is why it should be the default closing move
of any refactor commit — human or agent.

## Pointers

- Incident commits: `ea08bb0e` (the refactor + the five reachability
  tests, with the stash-verify methodology in the commit message),
  `d2f5daa6` (the original — green-but-partially-hollow — suite).
- Related: `plan_stable_handles_step1.md` (the TDD plan this happened
  inside), `lessons_learnt_action_registry.md` ("a call that looks like
  this helper is a hypothesis; read the branch" — the same epistemics,
  one level down).
