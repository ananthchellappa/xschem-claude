# Issue 0020 — `clone_canvas_bindings` overwrites correct per-window canvas bindings with the main window's

**Opened:** 2026-06-22
**Status:** ✅ RESOLVED 2026-06-22 (branch `fluid-editing`). `clone_canvas_bindings` now
skips any sequence `dst` already binds (`if {[bind $dst $seq] ne {}} continue`), so the
per-window standards `set_bindings` installed are preserved and only the user's extra
`.drw` bindings are carried over; the misleading "%W-templated / idempotent" comment was
corrected. Regression test `tests/headless/test_clone_canvas_bindings.tcl` (RED→GREEN):
new window's `<Expose>` targets its own canvas, `<Control-Shift-Key-P>` opens the palette
on the new toplevel, and a user `.drw` binding still clones.
**Affects:** every new top-level window (`create_new_window`) and detached tab
(`detach_tab`), via `clone_canvas_bindings .drw .xN.drw` (`src/xinit.c` → `src/xschem.tcl`).
**Severity:** high — silently degrades input handling in all new/detached windows
(Enter/Leave/Expose handlers stop firing; the command palette targets the wrong window).
**Branch:** `fluid-editing`. See [[multi-window-detach]].

---

## 1. Symptom

In a new or detached window: mouse-enter autofocus and the "destroy context menu on leave"
behavior do not work, the Expose-driven redraw binding does not fire (window may stay blank
until forced), graph measurement does not stop on leave, and `Ctrl-Shift-P` opens the
command palette transient to the **main** window instead of the current one.

## 2. Root cause

`create_new_window`/`detach_tab` first call `set_bindings <win>.drw` — which correctly
installs per-window bindings — and then call:

```tcl
# src/xschem.tcl:10882
proc clone_canvas_bindings {src dst} {
  if {![winfo exists $src] || ![winfo exists $dst] || $src eq $dst} return
  foreach seq [bind $src] {
    bind $dst $seq [bind $src $seq]   ;# OVERWRITES dst's binding for $seq
  }
}
```

The comment claims the standard `set_bindings` bindings are "%W-templated so re-copying them
is idempotent". That is **false** for several of them. `set_bindings` (`src/xschem.tcl`,
proc at 10911) bakes the literal `$topwin` / `$parent` path into the binding body, not `%W`:

```tcl
# src/xschem.tcl:10930  (topwin == .drw -> body says {.drw})
bind $topwin <Leave>  "if {{%W} eq {$topwin}} { xschem callback %W ...; graph_show_measure stop }"
# src/xschem.tcl:10937
bind $topwin <Expose> "if {{%W} eq {$topwin}} {xschem callback %W ...}"
# src/xschem.tcl:10977
bind $topwin <Enter>  "if {{%W} eq {$topwin}} { ... focus $topwin; xschem callback %W ... }"
# src/xschem.tcl:10967
bind $topwin <Control-Shift-Key-P> "command_palette $parent; break"
```

Cloning `.drw`'s versions onto `.x1.drw` overwrites the correct ones with bodies that test
`{%W} eq {.drw}` (always false on `.x1.drw`, so Enter/Leave/Expose bodies never run) and
`command_palette .` (palette on the main window). The clone is meant only to carry the
user's *extra* `.drw` bindings (e.g. `cadence_style_rc`'s `bind .drw <Control-x> {...;
break}`, which use context-relative commands and clone fine); it must not clobber the
standard per-window bindings.

## 3. Fix

Make `clone_canvas_bindings` non-destructive: only copy a sequence that does **not** already
have a binding on `dst` (i.e. skip `seq` when `[bind $dst $seq] ne {}`). That preserves the
correct per-window bindings `set_bindings` installed while still carrying the user's extra
shortcuts. Alternatively, track the user-added bindings separately and replay only those.
Update the misleading "%W-templated / idempotent" comment.

## 4. Tests

`tests/headless/test_multi_window.tcl` has `MWk` (user `.drw` binding clones onto new
windows) — keep it green. Add a check that after `create_window`, the new window's
`<Enter>`/`<Expose>` binding body references the **new** canvas path (or that `%W eq`
compares against the new path), and that `<Control-Shift-Key-P>` resolves `command_palette`
to the new window. Sabotage-verify by restoring the unconditional overwrite.
