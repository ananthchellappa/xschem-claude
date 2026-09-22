# Headless crashes batch — xschem stops dying when there is no display

Issue 1483 fixed one statement. The verifiers that closed it measured that the same class
is alive in several more places, and found the global that makes the whole class silent.
This batch closes the class.

## Items

| # | issues | what happens today |
|---|---|---|
| A | 1493 | `xserver_ok()` calls `XCloseDisplay()` and leaves the global pointing at freed memory, so a missed guard reads a plausible wrong number instead of faulting. It is why 1483 survived: the loud face only appears when `DISPLAY` is unset |
| B | 0227, 0834, 0467 | `xschem callback` dereferences a display in `update_statusbar()` (`XGetKeyboardControl`). Four suites crash headless; none is a T1 case, so T1 has never seen it |
| C | 1492 | four verbs — `fill_reset`, `fullscreen`, `copy_hilights`, `compare_schematics` — kill the process outright with no display. A `catch` cannot catch a signal |

## Acceptance criteria, fixed before the first round

1. **The fix is in the product, and it is the cause.** A backtrace names the statement; no
   guess reaches a commit message. Item A's repair must make a missed guard FAULT rather
   than read freed memory — that is the point of it, and it will expose sites nobody has
   found yet. Those are findings, not regressions to paper over.
2. **Measured both ways.** Every affected suite passes with `DISPLAY` unset with the check
   count it has with `DISPLAY` set, and a full T1 is at ZERO on both arms.
3. **A guard that silently skips work a user asked for is worse than the crash.** Where an
   operation genuinely needs a display, it reports that through the existing error path.
4. **T1-visible.** The class is invisible to T1 today because none of the affected suites is
   a case. Anything this batch fixes gets a check that runs in T1, or the next regression is
   as silent as this one was.
5. **Rounds are capped**: one implement round, one adversarial verify, at most one fix round
   per item. What survives is committed; what does not is filed.
6. **Scratch is a subtree per crew, short path, deleted by its owner, peak size reported.**

## Gate

The driver runs T1 solo before each commit, on both display arms for items that touch the
display path, and reads `T1-RUN-END` for `cases=`, `blocks=`, `counted_failures=` and
`skips=`.
