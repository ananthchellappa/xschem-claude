# Reuse the launch "untitled" scratch buffer when opening a file

Status: **implemented** (branch `fluid-editing`).
Related: `src/scheduler.c` (`is_pristine_untitled`, `load_new_window`),
`specs/multi_window_detach.md` (the windows the open would otherwise spawn).

Editor behavior (NEdit, Notepad++): launching gives you a blank **untitled**
buffer, but the first file you open *replaces* it — you are never left with an
orphaned "untitled" sitting next to the file you actually wanted. `untitled.sch`
exists only when nothing else is open.

## Rule

When `xschem load_new_window [-window] <file>` would create a new window/tab, it
first checks the current window: if it holds a **pristine untitled** buffer, the
file is loaded **in place** (via `xschem load`) instead, consuming the placeholder.
This holds even when "New window" is requested — leaving a pristine untitled behind
violates the invariant, so it is reused regardless.

**Pristine untitled** (`is_pristine_untitled()`): top level (`currsch == 0`),
`!modified`, no instances and no wires, and the conventional `untitled` name (or
empty). A scratch buffer the user has actually drawn in is `modified`, so it is
**not** reused — the work is preserved and the open goes to a new window instead.

Because the launch buffer is consumed by the first open, no untitled coexists with a
real file thereafter; the second open finds no pristine untitled and creates a new
window as usual. Closing the last real file falls back to untitled (pre-existing).

## Acceptance / tests

`tests/headless/test_untitled_reuse.tcl` (needs X; run from repo root):

- **UR1** launch = a single pristine untitled buffer.
- **UR2** first open (even with `-window`) reuses untitled in place — still one
  window. *(Discriminating; sabotage-verified: forcing `is_pristine_untitled`→0
  makes this open a 2nd window.)*
- **UR3** the next open creates a new window (untitled is gone, both files present).
- **UR4** a *modified* untitled is preserved — the open goes to a new window,
  leaving the scratch work intact.

## Out of scope

- File ▸ New explicitly creating an untitled buffer alongside real files (the user
  asked for it; only the automatic launch placeholder is reclaimed).
- Reusing a pristine untitled that is **not** the current window (e.g. one left in
  another window) — the current flow already prevents that buffer from arising.
