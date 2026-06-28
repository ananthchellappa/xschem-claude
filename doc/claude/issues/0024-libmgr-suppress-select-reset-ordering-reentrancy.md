# Issue 0024 — Library Manager `suppress_select` reset relies on fragile event/idle ordering and is not re-entrancy safe

**Opened:** 2026-06-22
**Status:** ✅ RESOLVED 2026-06-22 (branch `fluid-editing`) **as hardening**. `refresh_after`
now cancels any pending reset before scheduling a new one (new `suppress_after` var holding
the `after idle` id), so two cascades in one event-loop turn share a single reset that fires
after the last one. No reliable RED: the double-reset race does not reproduce on this Tk
build (the deferred `<<TreeviewSelect>>` events drain benignly), so
`tests/headless/test_libmgr_refresh_reentrancy.tcl` passes on both binaries and is kept as a
regression guard. The cross-Tk-version ordering (option #2 in §3) was not pursued — see §3.
**Affects:** `libmgr::refresh_after` (`src/library_manager.tcl`), the lib→cell→view cascade
used by `libmgr::locate` (CTRL-ALT-S "locate in Library Manager").
**Severity:** low/medium — when the ordering assumption does not hold, the cell/view panes
silently collapse to library-only (the exact bug the guard was added to fix).
**Branch:** `fluid-editing`. See [[library-manager]], [[library-git]].

---

## 1. Symptom

After a locate cascade (or two cascades in quick succession), the Cell and View panes
intermittently end up cleared, showing only the selected library — the regression that
`suppress_select` was introduced to prevent.

## 2. Root cause

```tcl
# src/library_manager.tcl:491
set suppress_select 1
after idle [list set libmgr::suppress_select 0]
```

The guard assumes the deferred `<<TreeviewSelect>>` virtual events — queued by the later
`selection set` calls in `refresh_after` — are delivered **before** the `after idle` reset.
Two ways this breaks:

1. **Ordering across Tk builds/paths:** whether selection-generated virtual events drain
   ahead of the idle handler is not guaranteed. If the idle reset runs first,
   `suppress_select` is 0 when the pending `<<TreeviewSelect>>` fires, so `on_lib`/`on_cell`
   run un-suppressed and re-clear the deeper panes.
2. **Re-entrancy:** if `refresh_after` runs twice in one event-loop turn, each schedules its
   own `after idle [set ... 0]`. Reset #1 can fire while call #2's selection events are still
   queued, re-enabling the clobber for the second cascade.

Test `LM-LOC2` only covers the happy single-call path.

## 3. Fix

Make the reset deterministic and idempotent. Options:
- Cancel any pending reset before scheduling a new one (`after cancel` on a stored id), so
  re-entrant calls share one reset that fires after the last cascade.
- Or drop the timing dependency entirely: suppress with a depth counter and reset it
  *synchronously* after the `selection set` calls, having the bound handlers no-op while the
  counter is non-zero (rather than relying on event/idle interleaving). A counter also makes
  re-entrancy safe by construction.

## 4. Tests

Extend `tests/headless/test_lib_manager_locate.tcl`: call `libmgr::locate` twice
back-to-back without an `update` between them, then `update`, and assert lib+cell+view stay
selected (LM-LOC2-style) — this reproduces the re-entrancy path. Sabotage-verify by removing
the cancel/counter.
