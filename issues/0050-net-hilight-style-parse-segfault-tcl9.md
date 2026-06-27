# Issue 0050 — `xschem update_net_hilight_style` SIGSEGV on Tcl 9 (int vs Tcl_Size)

**Opened:** 2026-06-27
**Status:** ✅ FIXED (2026-06-27) — `parse_net_hilight_styles()` (`src/hilight.c`) passed `int *` to
`Tcl_SplitList`; Tcl 9 changed that count out-parameter to `Tcl_Size *` (`ptrdiff_t`). Fixed by a
Tcl 8/9 compat shim in `src/xschem.h` (`typedef int Tcl_Size;` guarded on `TCL_SIZE_MAX`) and changing
the three count locals (`nrows`, `nf`, `nd`) from `int` to `Tcl_Size`. Strict no-op on Tcl 8.6.
**Affects:** `src/hilight.c` `parse_net_hilight_styles()` (`Tcl_SplitList` at ~:439/:449/:467). Reached from
`xschem update_net_hilight_style` (`src/scheduler.c` ~:8333) → `build_net_hilight_styles()`.
**Severity:** HIGH — crashes xschem (signal 11) on Tcl 9 when applying any real highlight style that uses a
named/`#rrggbb` color or a dash pattern (the default integer-color, solid-dash table does not crash).
**Branch:** `fluid-editing`.
**Reported by:** PR #4 (Nithin P) as fork-numbered "issue 0041"
(`doc/ai_docs/issues/0041-nhse-segfault-named-colors-dash-patterns.md`); the fork's number collides with
this repo's local 0041 (readonly-enforcement), hence renumbered 0050 here.
**Related:** [[net-hilight-styles]], [[tcl9-tcl-size]].

---

## 1. Symptom

Under a **Tcl 9** build, with a display (`DISPLAY=:0 ./src/xschem --pipe --nolog`):

```tcl
set ::net_hilight_style {{0 4 1 {} 0 0 none 0} {1 red 3 {6 4} 30 0 march_fwd 2}}
xschem update_net_hilight_style          ;# -> FATAL: signal 11
```

No schematic need be loaded and no net need be highlighted — it crashes in the parse, not the render.
The first row (integer color `4`, empty dash `{}`) alone does **not** crash; adding the second row
(named color `red`, dash `{6 4}`) does. On **Tcl 8.6 the identical script survives** (exit 0).
Four GUI tests (`test_nh_editor_table/_align/_persist/_flush_scroll`) crash with signal 11 on Tcl 9.

## 2. Root cause — Tcl 9 ABI break

Tcl 9 widened the count out-parameter of the list/string APIs (`Tcl_SplitList`,
`Tcl_ListObjGetElements`, `Tcl_GetStringFromObj`, …) from `int *` to `Tcl_Size *` — and `Tcl_Size` is
`ptrdiff_t` (8 bytes on LP64), where it was effectively `int` (4 bytes) in Tcl 8.x.

`parse_net_hilight_styles()` is the **only** code in `src/` that calls `Tcl_SplitList` (3 calls), and all
three passed the address of a plain `int`:

```c
int nrows; ... Tcl_SplitList(interp, tab,    &nrows, &rows);   /* :439 outer: rows           */
int nf;    ... Tcl_SplitList(interp, rows[j], &nf,  &f);       /* :449 per-row: fields       */
int nd;    ... Tcl_SplitList(interp, f[3],    &nd,  &dd);      /* :467 dash list (only if f[3] non-empty) */
```

On Tcl 9 each call writes an 8-byte `Tcl_Size` into a 4-byte `int`; the extra 4 bytes clobber an
adjacent stack slot. The default-shaped row (`{idx layer 1 {} …}`) has an integer color and an empty
dash, so it takes neither `find_best_color()` nor the inner dash split — only the two outer splits run,
and their collateral write happens to land harmlessly. A row with a **dash pattern** additionally runs
the inner `Tcl_SplitList(interp, f[3], &nd, &dd)`, whose collateral corruption hits a live
pointer/length; the following `dd[k]` / `Tcl_Free((char *)dd)` then dereferences garbage → signal 11.

This is why "all 50 headless tests pass" on Tcl 9 yet net-hilight crashes: the parser is the lone user
of `Tcl_SplitList` in the C engine. `find_best_color()` (the named-color path) is **pure Xlib** and is
version-independent — a red herring in the original report; the dash list is the actual Tcl-9 trigger.

## 3. Fix

`src/xschem.h`, right after `#include <tcl.h>` — a Tcl 8/9 compatibility shim (the standard Tcl
porting idiom; guard on the **macro** `TCL_SIZE_MAX`, which Tcl 9 defines, because `Tcl_Size` is a
typedef and cannot be tested with `#ifndef`):

```c
#ifndef TCL_SIZE_MAX
typedef int Tcl_Size;
#endif
```

`src/hilight.c` `parse_net_hilight_styles()` — declare the three counts as `Tcl_Size` (loop indices
`j`, `k` stay `int`; they compare against the `Tcl_Size` counts, which is fine):

```c
Tcl_Size nrows = 0; int j;
Tcl_Size nf = 0;    const char **f = NULL;
Tcl_Size nd = 0;    int k; const char **dd = NULL;
```

On Tcl 8.6 `Tcl_Size`→`int`, so the change is a strict no-op there.

## 4. Verification

Tcl 9 was not available in the fix environment (only Tcl 8.6), so the *crash-gone* confirmation is
pending a Tcl 9 build; but the change is the canonical migration and corrects all three split calls.
On **Tcl 8.6** (no-op regression check): clean build (no warnings); the exact §1 repro survives; full
path (load + `select wire` + `hilight` + render through `draw_hilight_wire` with a named-color+dash
style) survives; regression suite (create_save / open_close / netlisting) 0 FATAL;
`test_nh_export_custom_color`, `test_nh_editor_table`, `test_nh_editor_persist` all PASS.

### Notes for future work
- This is the only `Tcl_SplitList` site, but Tcl 9 widened **string** length out-params too
  (`Tcl_GetStringFromObj`, `Tcl_GetByteArrayFromObj`, `Tcl_NumUtfChars`, `Tcl_SplitPath`, …). A broader
  Tcl-9 sweep of `int`-typed length locals is tracked separately (see [[tcl9-tcl-size]]).
- Command-proc `objc` stays `int` in Tcl 9 — those are fine; it is the **out-parameter** length/count
  pointers that changed.
- Once this lands, the PR #4 Tcl wrapper that silently drops `update_net_hilight_style`, and the
  commented-out `utils/display.tcl` call, can be removed.
