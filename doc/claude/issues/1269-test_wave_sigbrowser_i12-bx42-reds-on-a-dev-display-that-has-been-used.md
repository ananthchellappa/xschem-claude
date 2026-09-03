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

## ⚠ Correction, same day: two rows of that table have uncertain binaries

Hours after filing, the driver found the main tree's `src/xschem` was **a build
behind its sources** — a `git stash` / build / `git stash pop` cycle run during
this very attribution restored the sources and left the binary at the stashed
state, and no test harness builds (see CLAUDE.md). So the two rows labelled
"A6 (uncommitted)" were probably running **pre-A6** code, not A6.

That does not overturn the conclusion; if anything it sharpens it, because rows
4, 5 and 6 then become **the same binary** on different displays:

| display | result |
|---|---|
| used | FAIL |
| freshly started | ALL PASS (126) |

One variable, two answers. But two things are now known not to be known:

* A **fresh-display full audit still redded BX42** — the display was fresh at the
  audit's *start*, and BX42 runs roughly 350 suites in. Consistent with the
  dirty-display hypothesis, and not evidence for it.
* **Why it passed inside the A3 and A4 audits is still unexplained**, and those
  runs were equally deep into the suite list. Until that is explained, the honest
  status of this issue is *display-sensitive flake, discriminator not isolated* —
  not *solved, mitigation known*.

## The re-measurement, 2026-09-03, correct binary throughout

Rebuilt tree, `src/xschem` verified to carry A6, display restarted before each
row:

| display state | result |
|---|---|
| freshly started, i12 alone | **ALL PASS (126)** |
| the same display, i12 a second time immediately | **ALL PASS (126)** |
| freshly started, `test_wave_sigbrowser_0312` (itself red) first, then i12 | **ALL PASS (126)** |
| after a full `full_audit.sh` run, i12 alone | **FAIL (125/1)** |
| inside `full_audit.sh` (fresh display at the audit's start) | **FAIL** |

So three candidates are now **excluded**: it is not the binary, it is not "one
prior xschem run", and it is not the red suite that runs immediately before it.
What is left is something the full audit **accumulates** over its ~350 suites.

## The likeliest mechanism, named but not yet proven

BX42 (DECLARED) reads `xschem get current_win_path` after
`raise_activate_toplevel`, which is `wm withdraw` + `wm deiconify` (issue 0054's
WSLg idiom). xschem's current window follows **X focus and `<Enter>` events**, so
the check is not really asking about a Tcl variable - it is asking where the X
server thinks the pointer and the focus are. A display carrying leftover mapped
toplevels, or a pointer parked over one of them, can hand the context to the
wrong window between the raise and the read. That would explain why a *count* of
prior runs does not reproduce it but a long, window-heavy audit does.

Naming the leftover is the next step, and the fix follows from it: BX42 should
**establish** the focus/pointer state it depends on rather than inherit whatever
the display is holding.

## The batch's handling

Feature A's boundary (`doc/claude/op_param_batch/PLAN.md`) closes at item A7, so
this is filed and deferred rather than grown into an item. For the remainder of
the batch, `test_wave_sigbrowser_i12` is an **accepted red carried by name and by
reason** - twelve names, not "eleven plus one". It is never carried as a count.

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
