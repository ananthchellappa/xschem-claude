# Library Manager — launch command, autostart, single-window focus

Status: **implemented** (branch `fluid-editing`).
Related: `doc/claude/code_analysis/library_manager_design.md` (the model), `doc/claude/specs/action_logging.md`
(the replay log), `src/library_manager.tcl` (the GUI).

Three small, cohesive enhancements to how the Library Manager window is launched.

## 1. A logged, replayable launch command

**Problem.** The Tools ▸ Library Manager menu item calls the bare Tcl proc
`library_manager`, which is invisible to the action log / CIW. There is no
`xschem`-dispatched command for it, so it cannot be replayed and cannot be bound
to a key the way other editor actions are.

**Change.** Add an `xschem` subcommand:

```
xschem library_manager
```

It opens (or, if already open, raises+focuses — see §3) the Library Manager and
records itself in the action log via `log_action("xschem library_manager")`, so
the launch shows up in `Xschem.log` and is mirrored to the CIW like any other
gesture end. Both the menu item and any user key binding go through this one
command, so both are logged identically. Implemented in `xschem_cmds_l`
(`scheduler.c`), next to `libraries` / `library` / `lib_cells`. The Tcl proc
`library_manager` stays as the raw (unlogged) entry point used by tests and other
internal callers; the menu is repointed at `xschem library_manager`.

**Binding it to a key** (example, in `xschemrc` or a `--script`):

```tcl
bind .drw <Key-F9> {xschem library_manager}
```

**Locating a cell.** The command takes one optional argument: a Tcl **list**.
A single element is a library name; a `{lib cell}` or `{lib cell view}` list
descends further (always library first, then cell, then view):

```
xschem library_manager libName                  ;# select that library
xschem library_manager {libName cellName}        ;# select lib + cell
xschem library_manager {libName cellName view}   ;# select down to the view
```

Because the argument is a single list, the result of `xschem get_inst_lcv`
(itself a `{lib cell view}` list) feeds straight in, with no `{*}` expansion —
this is the canonical "find the selected instance's cell" gesture:

```tcl
xschem library_manager [xschem get_inst_lcv]
```

Each given piece is selected and scrolled into view across the three panes
(reusing `libmgr::refresh_after` + listbox `see`), so a similarly named cell is
easy to find. A missing library/cell/view stops at the first miss and reports it
on the status bar. Implemented as a single list arg on `libmgr::open` (which
`lassign`s it into lib/cell/view), dispatched from `scheduler.c` (which
brace-quotes the list into `libmgr::open {lcv}`). Passing the list as one
argument keeps a library name that contains spaces unambiguous.

**`xschem get_inst_lcv`** returns the `{lib cell view}` list for the single
selected instance, or errors. It reports only instances whose symbol lives in a
library defined in a loaded `library.defs` (`library_defs_registry`) and laid
out in the Cadence structure `<libpath>/<cell>/<view>/<cell>.sym` — the view is
the actual view-directory name (type always a `.sym` symbol, but the name is
arbitrary). A symbol that is flat/legacy, or only present via a search-path
directory with no `library.defs` entry, is not reported. Backend:
`library_inst_lcv` in `library_defs.tcl`.

## 2. An rc setting to autostart it

**Change.** A mirrored Tcl config flag:

```
launch_library_manager   0 (default) | 1
```

When `1`, the Library Manager is opened once at startup, after the rc files, the
main window, and any `--script` have all run (hooked at the tail of the init
sequence in `xinit.c`, gated on `has_x`). Default `0` preserves current behavior.
`cadence_style_rc` turns it **on** so the Cadence-style session comes up with the
Library Manager already visible.

## 3. Single window: raise + focus instead of a second window

**Problem.** `libmgr::open` already refuses to build a second window, but it only
`raise`d the existing one — if it was buried or iconified, nothing obvious
happened and keyboard focus stayed where it was.

**Change.** A shared `libmgr::raise_to_front` runs on BOTH the create and the
already-open paths: `wm deiconify`, `raise`, and **`focus -force`** on the library
listbox (re-asserted at idle for the just-created, not-yet-mapped case). Plain
`focus` cannot move the keyboard focus across toplevels, so when another window —
e.g. the CIW — is the active one it is ignored; `focus -force` grabs it. So
re-issuing the command (menu or key) always brings the one window forward AND
gives it the keyboard, regardless of which window was active before. Still exactly
one Library Manager window.

## Acceptance / tests

`tests/headless/test_lib_manager_launch.tcl` (needs X) — only the deterministic,
discriminating checks:

- LL1 `xschem library_manager` creates `.libmgr`.
- LL2 a second `xschem library_manager` does **not** rebuild it (same X id).
- LL5 `launch_library_manager` defaults to 0.
- LL6 the raw `library_manager` proc still opens the window.
- LL7 the Tools menu entry is wired to `xschem library_manager`.

`tests/headless/test_action_log_libmgr.tcl` AL10 (runs with `--logdir`): `Xschem.log`
gets a replayable `xschem library_manager` line.

**Not auto-tested (manual eyeball):** window-manager focus arbitration — that the
window grabs the keyboard when launched while another toplevel (the CIW, the main
window) is active. Under WSLg/Xvfb a scripted toplevel is auto-focused regardless
of the code, so an assertion there passes even with the fix removed; it can't tell
the bug from the fix. Validated by launching from a CIW-active state by hand.

## Out of scope

- Per-session window geometry persistence (the window already takes a fixed
  `760x460`; geometry memory is a separate enhancement).
- A toolbar button (only the menu + the bindable command are added here).
