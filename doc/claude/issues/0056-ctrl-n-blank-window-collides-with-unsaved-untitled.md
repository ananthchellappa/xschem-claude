# 0056 — Ctrl-N blank window collides with an unsaved `untitled.sch`

## Summary

In Cadence mode, **Ctrl-N** opens a fresh blank schematic in its own top-level window
(`cadence::new_blank_window` → `xschem new_schematic create_window {}`, commit
`b00f6a37`). The new buffer is named by the "untitled namer" which only checks whether a
file with the candidate name exists *on disk* (`stat()`). It does **not** consider names
already open (in memory) in other windows/tabs.

So if `untitled.sch` is already being edited in one window but has never been saved to
disk, Ctrl-N produces a *second* window also named `untitled.sch`. Two distinct buffers
now share one name — confusing in the title bar / window list, and a hazard for any code
that matches windows by name (`check_loaded`, save prompts, the untitled-reuse logic).

Expected (editor convention, e.g. NEdit/Notepad++): the second blank buffer should
iterate to `untitled-1.sch`, the third to `untitled-2.sch`, etc.

## Root cause

Three namer sites pick the next free `untitled[-n].{sch,sym}` by `stat()` alone:

- `save.c` `load_schematic()` — the empty-filename branch (the path Ctrl-N hits).
- `actions.c` — the Clear Schematic / discard branch (two sub-branches: `.sym` / `.sch`).

`stat()` answers "is this name on disk?" but an unsaved scratch buffer is **not** on
disk, so the collision slips through.

## Fix

Add a single shared namer, `get_unused_untitled_name(symbol, name, namesize)` in
`xinit.c` (it already owns the window enumeration via `get_window_ctx()`). A candidate
basename is "in use" if either:

1. a file with that name exists in the current directory (`stat()`, as before), **or**
2. any *other* open window/tab (`get_window_ctx()` over all slots, skipping the live
   `xctx`) already holds a buffer whose basename matches.

Both `save.c` and `actions.c` call the helper for basename selection, then prepend the
directory as they did before. Skipping the live `xctx` keeps Clear-Schematic-in-place
behavior unchanged (a lone window still resets to `untitled.sch`).

## Test

`tests/cadence_new_window.tcl` extended: after the first Ctrl-N scratchpad (still
`untitled.sch`), a second `new_schematic create_window {}` must yield `untitled-1.sch`,
and a third `untitled-2.sch`, with all three windows open simultaneously.
