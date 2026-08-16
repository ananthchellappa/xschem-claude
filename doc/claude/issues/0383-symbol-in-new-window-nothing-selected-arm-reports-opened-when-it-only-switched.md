# 0383 — symbol_in_new_window's "nothing selected" arm reports `1` (opened) when it only switched or only warned

Status: OPEN (filed, not fixed)
Filed: 2026-08-10, crew item D6 (Implement), while landing issue 0258.
Area: `src/actions.c` `symbol_in_new_window()` — the `xctx->lastsel != 1 || sel_array[0].type != ELEMENT`
arm; `src/xinit.c` `create_new_tab()` / `create_new_window()` already-open branches.

## What

Issue 0258 gave `symbol_in_new_window()` an `int` return: `0` nothing done, `1` opened, `2` switched
to the tab/window already holding the symbol, `3` refused and said why. The `2` / `3` / `0` answers
are produced by the new `symbol_already_open()` helper, which the 0258 fix put on the
**instance-selected** arm only.

The **other** arm — nothing (or more than one thing) selected, "open another view of the CURRENT
schematic's `.sym`" — was deliberately left untouched by D6 (smallest blast radius) and
unconditionally returns `1`. But `new_schematic("create", ...)` underneath it is `void` and has its
own already-open branch:

```
create_new_tab():   check_loaded(fname, open_path) -> warn -> switch_tab(open_path) -> return
create_new_window(): check_loaded(fname, toppath)  -> warn -> bare return (no switch, no raise)
```

so the caller can get `1` when nothing was opened. Measured 2026-08-10 headless, tabbed:

```
current window .x1.drw already holds descend_child.sym, nothing selected
xschem symbol_in_new_window
  -> stderr: create_new_tab: /tmp/snw_work/descend_child.sym already open: .x1.drw
  -> ret = 1                      <-- claims "opened"; no tab was created
```

In windowed mode the same call returns `1` having done *nothing at all* (no create, no switch, no
raise) — the exact defect 0258 fixed one arm up.

## Why it was not fixed in D6

The 0258 plan scoped the fix to the arm the issue was filed against and to the value `check_loaded`
already had in hand there. Routing this arm through `symbol_already_open()` too is a behaviour
change on a path 0258 never measured (it targets the *current schematic's own* symbol, not a
selected instance's), and `new_schematic()` being `void` means the honest answer needs either a
pre-check `check_loaded()` here or a return value on `new_schematic("create")` — a wider change.

## Fix sketch

Pre-check with `check_loaded(filename, win_path)` in this arm as well and delegate to the same
`symbol_already_open()` helper, so both arms answer with the same vocabulary. That also gives the
windowed-mode already-open case the switch + raise it has never had.

## Related

- 0258 (the fix this was found under), 0251 (the return-channel shape), 0370 (the same
  "reports success without doing it" class on the window table).
