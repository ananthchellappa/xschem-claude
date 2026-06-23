# Issue 0023 — `is_pristine_untitled()` matches any path containing the substring "untitled"

**Opened:** 2026-06-22
**Status:** ✅ RESOLVED 2026-06-22 (branch `fluid-editing`). `is_pristine_untitled()` now
matches the BASENAME against the exact scratch-name pattern via a new `is_untitled_basename()`
helper (`untitled.sch` / `untitled-<n>.sch` / `.sym`), and NULL-guards `sch[currsch]`.
Regression test `tests/headless/test_pristine_untitled_basename.tcl` (RED→GREEN): a real
empty unmodified schematic under a directory named `…untitled…` is NOT clobbered when another
file is opened (it lands in a new window). Existing `test_untitled_reuse.tcl` still green
(genuine `untitled.sch` scratch is still reused).
**Affects:** `is_pristine_untitled()` (`src/scheduler.c`), used by the `xschem
load_new_window` reuse path.
**Severity:** low — requires a real, empty, unmodified, top-level schematic whose path
contains "untitled"; in that case the open silently reuses (replaces) the buffer.
**Branch:** `fluid-editing`. See [[untitled-reuse]].

---

## 1. Symptom

Opening a file while a *real* but empty/unmodified schematic whose path contains the
substring "untitled" is current (e.g. `/home/user/untitled_designs/blank.sch`) replaces that
buffer in place instead of opening a new window/tab — the reference to the real file is
dropped.

## 2. Root cause

```c
/* src/scheduler.c:3331 (inside is_pristine_untitled) */
return (xctx->sch[xctx->currsch][0] == '\0' ||
        strstr(xctx->sch[xctx->currsch], "untitled") != NULL);
```

`xctx->sch[currsch]` is the **full path**, and `strstr` matches "untitled" anywhere in it,
including a directory component. `clear_schematic` only ever assigns the scratch names
`untitled.sch` / `untitled-N.sch`, so the loose full-path substring test over-matches real
files. (The reuse is gated by `modified == 0`, `instances == 0`, `wires == 0`, so no drawn
work is lost, but the real file reference is silently dropped.)

## 3. Fix

Match the **basename** against the exact scratch-name pattern `clear_schematic` produces
(`untitled.sch`, or `untitled-<n>.sch`), not `strstr` of the whole path. Reuse the basename
helper already used elsewhere in the codebase. Also consider the NULL-safety noted below.

## 4. Notes

`is_pristine_untitled` dereferences `xctx->sch[xctx->currsch][0]` with no NULL check, while
the adjacent new `xschem windows` code guards the same field
(`ctx->sch[ctx->currsch] ? ... : ""`). `sch[]` is `char *sch[CADMAXHIER]`; slot 0 normally
holds a name post-init, so this is latent, but the two sites should treat the field
consistently — add a NULL guard here too.

## 5. Tests

Headless: with current buffer set to an empty unmodified schematic named `.../untitled_x/
real.sch`, `xschem load_new_window <other>` must open a new window and leave the real file
open (not reuse it).
