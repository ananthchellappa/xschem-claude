# Issue 0021 — `handle_window_switching` can dereference `save_xctx[n]` with `n <= 0/-1`, newly reachable in tabbed mode

**Opened:** 2026-06-22
**Status:** ✅ RESOLVED 2026-06-22 (branch `fluid-editing`) **as hardening**. The deref at
`src/callback.c:5707` is now guarded `n >= 0 && save_xctx[n] && ...`. No reliable RED: the
OOB read of `save_xctx[-1]` does not fault deterministically (it reads adjacent memory whose
STARTCOPY bit happens clear), so the probe test
`tests/headless/test_window_switch_bogus_enter.tcl` passes on both the unfixed and fixed
binary — it is kept as a regression guard that locks the safe behavior (process survives an
EnterNotify on an unknown window path; current context unchanged).
**Affects:** `handle_window_switching()` (`src/callback.c`), the FocusIn/Expose/EnterNotify
context-switch path, when windows and tabs coexist (tabbed mode + a detached/real window).
**Severity:** medium — out-of-bounds read / potential crash on a rare teardown event;
partly pre-existing in windowed mode but the diff widens its reach into tabbed mode.
**Branch:** `fluid-editing`. See [[multi-window-detach]].

---

## 1. Symptom

A stale `EnterNotify` for an unregistered `win_path` (e.g. during a window/tab teardown),
while the current context is a real (detached) window, can index `save_xctx[]` with a
negative or zero slot and dereference it — an out-of-bounds read that can crash.

## 2. Root cause

The diff widened the entry condition of the switch block:

```c
/* src/callback.c:5689 */
int win_is_real = (n > 0 && save_xctx[n] && save_xctx[n]->top_path && save_xctx[n]->top_path[0]);
int cur_is_real = (xctx->top_path && xctx->top_path[0]);
if(!tabbed_interface || win_is_real || cur_is_real) {
```

`n = get_tab_or_window_number(win_path)` returns `-1` for an unknown path (and `0` for the
main window). `win_is_real` guards with `n > 0`, but `cur_is_real` does **not** — so in
tabbed mode, when the current context is a detached real window, the block is entered for
any `n`, including `-1`. Inside, one branch dereferences `save_xctx[n]` directly with no
guard:

```c
/* src/callback.c:5707 */
} else if( event == EnterNotify && (save_xctx[n]->ui_state & STARTCOPY)) {
```

With `n == -1` this is `save_xctx[-1]->ui_state` — out of bounds. Previously this whole path
ran only under `!tabbed_interface`, so the tabbed-mode coexistence case is newly exposed.

## 3. Fix

Guard the slot before dereferencing: require `n >= 0 && save_xctx[n]` (or `n > 0`, matching
`win_is_real`) before reading `save_xctx[n]->ui_state` at 5707, and bail out of the switch
for an unresolved `win_path` (`n < 0`). Consider computing a single `valid_n = (n >= 0 &&
save_xctx[n])` and gating both the entry condition and the deref on it.

## 4. Tests

Hard to reproduce deterministically (depends on a stale event). Add a defensive unit-style
headless check that drives `xschem callback <bogus-path> 9 ...` (EnterNotify) while a
detached window is current and asserts no crash. At minimum, sabotage-verify the guard by
forcing `n = -1` in a debug build.
