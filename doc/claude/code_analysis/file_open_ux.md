# How File → Open works in XSCHEM — a guided tour, with UX commentary

This is a walkthrough of everything that happens between clicking **File → Open**
and a schematic appearing on screen. If you want to modify the open flow (we do:
see the last section), this is the map you need. Line numbers refer to the
current tree.

## 1. The menu item is data, not code

The File menu is no longer hand-written Tcl. It is generated from the action
registry: `src/actions.csv` holds one row per menu item, and
`build_menu_from_table` (`src/action_registry.tcl:94`) turns rows into
`$menu add command ...` calls when `build_widgets` runs
(`src/xschem.tcl:10245`).

The row that interests us is:

```
file.open,command,file,Open,Ctrl+O,xschem load,,,Open a schematic or symbol file
```

So clicking **Open** simply evaluates the Tcl command `xschem load`. That's the
first lesson of this codebase: *every* user-facing operation funnels through the
single `xschem` Tcl command, dispatched by the giant `scheduler()` function in
`src/scheduler.c`.

Nearby rows matter too, because "opening a file" is really a family of five
menu entries: `Open`, `Open in new window`, `Open last closed` (Ctrl+Shift+T),
`Open most recent` (Ctrl+Shift+O), and the dynamic `Open recent` submenu.
Keep that in mind for the UX discussion.

## 2. `xschem load` — the C side picks a dialog

The `load` branch lives at `src/scheduler.c:3083`. With no file argument
(`argc == first`, line 3116) it has to *ask* the user, and here the flow forks
on a configuration variable:

```c
if(tclgetboolvar("new_file_browser")) {
  tcleval("file_chooser");
} else {
  ask_new_file(0, NULL);
  tcleval("load_additional_files");
}
```

- `new_file_browser` off (the default): `ask_new_file()` in
  `src/actions.c:609` prompts to save a modified schematic, then calls the
  classic Tcl dialog `load_file_dialog {Load file} *.{sch,sym,tcl}
  INITIALLOADDIR`, and finally loads whatever path comes back
  (`load_schematic(...)`, `update_recent_file`, `zoom_full`).
- `new_file_browser` on: a completely different Tcl widget, `file_chooser`
  (`src/xschem.tcl:5704`), which recursively indexes directories.

When a file *is* passed (`xschem load -gui /path/to/x.sch`, which is what the
**Open recent** entries run), the same branch loads it directly; `-gui` means
"don't force: ask before discarding unsaved changes and warn if the file is
already open in another tab" (lines 3140–3157).

## 3. `load_file_dialog` — the classic dialog, dissected

`load_file_dialog` (`src/xschem.tcl:4784`) builds a toplevel named `.load`:

- **Left pane**: a listbox of the *library search path* (`$pathlist`) — click a
  path element and the right pane shows its contents (`setglob`).
- **Right pane**: directory + file listbox on top, and below it a live
  **preview canvas** that renders the selected `.sch`/`.sym` via
  `xschem preview_window`. This is genuinely great — you see the circuit
  before opening it.
- **Button row 1**: `Home`, `Up`, `Current dir`, a `Library paths` checkbox
  (toggles full-path display), and a `New dir:` entry with `Create` and
  `Delete` buttons.
- **Button row 2**: a `Search:` glob-filter entry, a `Fuzzy:` filter entry, a
  `File:` entry, and `Cancel`/`OK`.

The result is delivered through the global `file_dialog_retval`, post-processed
by `file_dialog_getresult` (`src/xschem.tcl:4513`): relative names are resolved
against the currently browsed directory, and the file is sniffed with
`is_xschem_file` so you get a "does not seem to be an xschem file... Continue?"
alert rather than a garbage load.

## 4. The recent-files machinery

Three small procs in `src/xschem.tcl` own this:

- `load_recent_file` (line 1229) sources `$USER_CONF_DIR/recent_files` at
  startup, which sets `tctx::recentfile`.
- `update_recent_file` (line 1254) pushes a path on the front of the list,
  dedupes by `abs_sym_path`, truncates to **10 entries**, writes the file back,
  and rebuilds the menu.
- `setup_recent_menu` (line 1301) populates **File → Open recent**, labelling
  each entry with `file tail` — just the bare filename.

Every successful load funnels through `update_recent_file`, whether it came
from the dialog, the command line, or a recent-menu click. Single chokepoint —
nice design, and exactly the hook we'll reuse.

## 5. UX commentary — what works, what hurts

**The good.** The preview canvas is the standout: no stock OS dialog shows you
the schematic before you commit. The left pane being the *library path* rather
than the filesystem root matches how EDA users actually think ("it's in the
PDK lib", not "it's in /usr/share/..."). Window geometry, sash positions and
the last directory (`INITIALLOADDIR`) all persist. Path entries are colored by
which library they belong to.

**The hurts**, roughly ordered by how often they bite:

1. **There is no fast path for "I already have the path."** The most common
   power-user gesture — copy a path from a terminal, paste, Enter — is poorly
   served. The `File:` entry at the bottom of `.load` *can* accept a typed
   path, but it is created with `-takefocus 0` (`src/xschem.tcl:4915`), so you
   cannot Tab into it; you must notice it and click it. Nothing about it says
   "paste a path here".
2. **Pasting a directory silently does nothing.** The `<Return>` binding
   (line 5014) refuses to close the dialog when the entry holds a directory —
   no navigation into it, no message, no bell. The user's mental model
   ("Enter on a folder enters the folder") is simply ignored.
3. **The recent list is filenames only, with `file tail` labels.** Open two
   `inverter.sch` from different projects and **Open recent** shows two
   identical entries — you pick one and hope. And there is no notion of recent
   *directories* at all, although "reopen something from the project I worked
   on yesterday" is the actual task behind most opens.
4. **Recents are not reachable from the dialog.** The place where you choose a
   file (the dialog) and the place that remembers your habits (the menu) are
   different widgets; muscle memory has to switch surfaces.
5. **Two parallel browsers.** Depending on the hidden `new_file_browser`
   option, File → Open produces entirely different UIs (`load_file_dialog` vs
   `file_chooser`) with different layouts and bindings. Documentation and
   screenshots can match at most half your users.
6. **Four entry widgets in one dialog** (`Search:`, `Fuzzy:`, `File:`,
   `New dir:`) with no visual hierarchy. Each is individually defensible; the
   ensemble forces a read-the-manual moment for what should be the most
   self-evident dialog in the program.
7. **The `Delete` button deletes with no confirmation** (line 4970:
   `file delete "$dir/[entry get]"`). It only removes files/empty dirs, but a
   destructive control sitting next to `Create` in an *open* dialog, acting on
   a name typed in the "New dir" box, is a trap.
8. **Keyboard reach is uneven.** `H`/`U` jump Home/Up (undocumented in the
   dialog), yet Tab order skips the one field where typing makes sense.

## 6. What we add (and why this shape)

Two features, addressing pains 1–4 directly, *inside* `load_file_dialog`
itself. An earlier iteration was a separate **File → Open path…** dialog
(one `actions.csv` row + standalone `quick_open_*` procs); integrating it
into the classic dialog means one surface instead of three — pain 5 argues
hard against adding browsers, and pain 4 is only truly fixed when the
recents live where the choosing happens.

- **The `File:` entry becomes a first-class path field.** It is focusable
  (the `-takefocus 0` is gone) and in load mode it receives initial focus, so
  the power-user gesture is now: open dialog, paste, Enter.
  `file_dialog_entry_enter` (bound to `<Return>` on the entry widget, with
  `break` so the generic `bind .load <Return>` doesn't also fire) resolves
  what you typed — absolute, `~`-prefixed, relative to the browsed directory,
  relative to the cwd, or against the library search path via `abs_sym_path`,
  so `devices/nmos.sym`-style names work too. An existing *file* is accepted
  through the normal `file_dialog_retval` + destroy route, so
  `file_dialog_getresult` still runs its `is_xschem_file` sanity sniff. A
  *directory* navigates the dialog into it (`file_dialog_navigate`, which
  mirrors `load_file_dialog_up`: `file_dialog_set_home` + `setglob` +
  recolor) instead of the old silent refusal. A path that resolves nowhere
  pops an error and keeps the dialog open — except in save mode, where a
  not-yet-existing name is the normal case and is accepted unchanged.
- **A Recent menubutton next to the entry** (`.load.buttons_bot.recent` —
  `.load.l.recent` is taken by the insert-symbol pane). Rebuilt on every post
  by `file_dialog_fill_recent_menu`: recent *files* first (full paths, fixing
  the `file tail` ambiguity), a separator, then recent *directories* — the
  ones navigated through this field (persisted as `tctx::recentdirs` in the
  same `recent_files` conf file, capped at 10, registered in
  `tctx::global_list` so tab/window context switches don't lose it) plus the
  directories of the recent files, deduped, labelled with a trailing `/`.
  Entries that no longer exist on disk are skipped at post time — the stored
  lists are not rewritten, so a path on a temporarily unmounted filesystem
  reappears once reachable again. Picking an item behaves exactly like
  typing it and pressing Enter.

The dialog has six callers in three modes (the `loadfile` argument): Open,
Merge and Schematic-to-compare use `1`; Save-as uses `0`; Insert-symbol uses
`2`. The Recent button only exists for `loadfile == 1` — recent schematics
are wrong for Save-as and Insert-symbol. Directory navigation on Enter is
harmless and active in all modes; accepting a file on Enter is skipped in
mode `2`, which never had a Return binding. A small side fix: the
undocumented `H`/`U` (Home/Up) shortcuts no longer fire while focus is in an
entry widget — the path field is now in the Tab order and paths can contain
capital letters.
