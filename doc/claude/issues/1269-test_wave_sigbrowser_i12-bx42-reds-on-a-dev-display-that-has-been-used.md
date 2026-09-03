# 1269 — `test_wave_sigbrowser_i12`'s BX42 reds on a dev display that has been used, and greens on a fresh one

**Filed** 2026-09-02 by the driver of the OP-parameter-lists batch, while
attributing a twelfth red that item A6's audit reported against an eleven-name
baseline. Status: **open**, not fixed.
Related: **1244** (the batch that surfaced it), **0990** (the other way a suite
number lies), `doc/claude/specs/dev_display.md`

## Why it matters

This batch's whole acceptance discipline is a **name+status diff, never a
count**. A suite that reds for reasons outside the repository breaks that
discipline in the most expensive direction: it costs a full attribution hunt,
and it trains a reader to wave the next red through.

## The measurement

The failing check is one of 126:

```
FAIL: BX42 (DECLARED) the context is LEFT ON THE VIEWER, the raised window
      -> {0} (exp {1}) : FAIL
```

| what was run | binary | result |
|---|---|---|
| inside `full_audit.sh`, items A3 and A4 | A3 / A4 | **PASS** |
| inside `full_audit.sh`, item A6 | A6 | **FAIL** |
| standalone, `devdisplay.sh exec`, used display | A6 (uncommitted) | **FAIL** (125/1) |
| standalone, `devdisplay.sh exec`, used display | HEAD, A6 stashed | **FAIL** (125/1) |
| standalone, `devdisplay.sh exec`, used display | **A4's commit `ccd2aec1`, built in a clean worktree** | **FAIL** (125/1) |
| standalone, **after `devdisplay.sh stop && start`** | A6 (uncommitted) | **ALL PASS (126)** |

So it is not A6's code, and not A5's, and not A4's. **It is the display.** The
same binary that fails on a display which has hosted a day of suites passes on a
freshly started one, and the check that moves is the one about a **raised
window** — precisely the property stray windows from earlier runs perturb.

## What is not yet known

* Which leftover — a mapped toplevel, a focus owner, a WM stacking entry — is the
  one BX42 reads. The bisect above stopped at "restarting the display fixes it"
  because that was enough to clear the attribution; nobody has named the object.
* Whether other window-mapping suites share the sensitivity and have simply been
  lucky. The seven standalone `test_*.sh` window-mapping suites are the obvious
  place to look.

## The cheap mitigation, and why it is not the fix

`devdisplay.sh stop && devdisplay.sh start` before an audit costs ~0.3 s and
makes the number trustworthy. But CLAUDE.md's own rule about `:0` applies here
too: **a bug only a dirty display reproduces is a test defect as well.** The fix
is for BX42 to establish the window state it depends on, rather than to inherit
whatever the display happens to be holding.
