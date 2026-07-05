# Text-note-aware library & hierarchy navigation (CTRL-ALT-S / CTRL-SHIFT-N / CTRL-ALT-D)

Status: SPEC. Related memory: [[cadence-bindkeys]], [[library-manager]],
[[symbol-view-create]], [[descend-newwin-return-chain]], [[hi-descend]],
[[descend-readonly]].

## 1. Goal

Three Cadence-style shortcuts gain a common new capability: **a selected text note can
name a library cell or a hierarchy location**, and the shortcut acts on it. Plus the
shortcuts grow sensible no-selection fallbacks. The unifying idea: text notes become
*addressable bookmarks* into the library and the hierarchy.

All three are pure Tcl — binds in `src/cadence_style_rc`, helpers in `utils/`. No C
change is needed (every primitive already exists).

## 2. Shared building blocks (already in the tree)

- Selection probe: `xschem get lastsel` (count), `xschem get first_sel` → `"type n col"`
  (type `8`=ELEMENT/instance, `16`=xTEXT). Read a text's string: `xschem text_string n`.
- Instance→cell: `xschem get_inst_lcv` → `{lib cell view}` of the one selected instance.
- Current cell: `schematic_cellview [xschem get schname]` → `{lib cell view layout}`.
- Library Manager: `xschem library_manager {lib cell ...}` opens/raises + locates
  (`libmgr::open`/`libmgr::locate`/`libmgr::raise_to_front` → `raise_activate_toplevel`).
- Cell→file: `xschem cellview_path "lib/cell" schematic` → abs path (or `{}`).
- Open file read-only in a new OS window: `xschem load_new_window -window <file>` then
  `xschem set readonly 1` (the `libmgr::open_view_ro` recipe), then a deferred
  `force_window_repaint` (WSLg paint, issue 0052).
- Deep descend by instance-name path: select-then-descend loop (today inlined in
  `cadence::descend_to_last`); this spec **extracts** it as `cadence::descend_instnames`.
- The remembered deep location: `cadence::last_loc(<win>)` = a Tcl list of instance
  names, e.g. `{Xamp Xstage1}`, set by ALT-E `cadence::return_to_top`.
- Interactive placement: create the note, select it, `xschem move_objects` (sets
  `MENUSTART|MENUSTARTMOVE`) → it follows the cursor, user clicks to drop.

### 2.1 New pure (side-effect-free, unit-testable) parse helpers

- `cadence::first_libcell {text}` → the **first** substring matching a single-slash
  `lib/cell` token (`(\w+)/(\w+)`), returned as the list `{lib cell}`, or `{}` if none.
  Used by CTRL-ALT-S and CTRL-SHIFT-N.
- `cadence::deeppath_from_text {text}` → if the trimmed text **starts with** a
  multi-component slash path of instance names (`^\s*(\w+(?:/\w+)+)`), return that as a
  Tcl list of names (`a/b/c` → `{a b c}`), else `{}`. Used by CTRL-ALT-D.

Charset is `\w` (`[A-Za-z0-9_]`) per the request. Vector instances with `[`...`]` are a
documented v1 non-match (consistent with `descend_to_last`'s base-name behaviour).

## 3. CTRL-ALT-S — locate in Library Manager

Bind today: `bind .drw <Control-Alt-Key-s> {locate_selected_in_libmgr; break}`
(`utils/lib_mgr_helpers.tcl`). Rewrite `locate_selected_in_libmgr` to branch on selection:

1. **Exactly one instance selected** (current behaviour): `xschem get_inst_lcv` →
   `xschem library_manager $lcv`.
2. **Nothing selected** (NEW): the cell being *viewed* →
   `set lcv [schematic_cellview [xschem get schname]]`; if non-empty,
   `xschem library_manager [lrange $lcv 0 1]` (lib + cell; view optional).
3. **Exactly one text note selected** (NEW): `set lc [cadence::first_libcell <txt>]`;
   if non-empty, `xschem library_manager $lc`; else hint "no lib/cell in the selected
   note".
4. Anything else (multiple objects, a wire, …) → `ciw_echo` hint, no-op.

In all cases the manager is raised (the `library_manager` C/Tcl path already raises).

## 4. CTRL-SHIFT-N — open schematic view read-only in a new window

Bind today: `bind .drw <Control-Shift-Key-N> {cadence::open_inst_sch_readonly; break}`
(`utils/cadence_nav.tcl`). Add a text-note branch:

1. **Exactly one instance selected** (current behaviour): `xschem schematic_in_new_window
   force window` then `xschem set readonly 1`.
2. **Exactly one text note selected** (NEW): `set lc [cadence::first_libcell <txt>]`;
   if empty → hint. Else resolve `set f [xschem cellview_path "<lib>/<cell>" schematic]`;
   if `{}` → hint "no schematic view for lib/cell". Else open read-only in a new window
   via the `open_view_ro` recipe: `xschem load_new_window -window $f` →
   `xschem set readonly 1` → deferred `force_window_repaint`.
3. Nothing / other selection → existing "select one instance…" hint (extended to mention
   the note option).

## 5. CTRL-ALT-D — deep-location ↔ text-note round trip

Decoupled: CTRL-ALT-D is currently **unbound** in `cadence_style_rc` (plain Ctrl-D =
`delete_files` in C; the Ctrl-Alt chord is free). New bind:
`bind .drw <Control-Alt-Key-d> {cadence::deeploc_note; break}` → new proc
`cadence::deeploc_note` in `utils/cadence_nav.tcl`, branching on selection:

1. **Nothing selected** → *write* the remembered deep location as a note.
   `set names $cadence::last_loc(<win>)`; if empty → `ciw_echo "no remembered location
   (use Alt-E from a deep view first)" error`. Else build `set path [join $names /]`
   (e.g. `Xamp/Xstage1`) and enter **note-creation mode pre-filled** with `$path`:
   the standard `enter_text` dialog pre-seeded from `tctx::retval` (the user may edit),
   then create the text and hand it to `xschem move_objects` so the user clicks to place
   it. (`place_text` itself can't be pre-seeded — it clears `tctx::retval` — so a small
   `cadence::place_note_prefilled` helper mirrors its body with the seed kept.)
2. **Exactly one text note selected** matching `cadence::deeppath_from_text` → *read* it
   as a top-relative instance path and descend: `cadence::descend_instnames $names`
   (ascend to top, then select-instance/descend per name — the same utility ALT-X uses).
   A name that doesn't resolve aborts with the existing per-level `ciw_echo` error.
3. **Text selected but not a deep path** → hint "selected note is not a deep location
   (word/word/…)". **An instance (or other) selected** → hint pointing at Alt-X /
   the two supported modes.

### 5.1 Refactor (no behaviour change to ALT-X)

Extract the descend loop from `cadence::descend_to_last` into:

```tcl
proc cadence::descend_instnames {names} {        ;# ascend to top, then descend each level
  if {![cadence::ascend_to_top]} { ciw_echo "cannot return to top to begin descent" error; return 0 }
  foreach name $names {
    xschem unselect_all
    if {[xschem select instance $name] == 0} { ciw_echo "instance '$name' not found while descending to $names" error; return 0 }
    if {[xschem descend] == 0} { ciw_echo "cannot descend into '$name'" error; return 0 }
  }
  return 1
}
```

`descend_to_last` then becomes: resolve `last_loc`, call `descend_instnames`, echo.
CTRL-ALT-D mode 2 calls `descend_instnames` directly. One descend engine, two callers.

## 6. Edge cases & decisions

1. **Single vs first match.** S/N take the *first* `lib/cell` anywhere in the note;
   CTRL-ALT-D requires the note to *start* with a `word/word/…` path. So the same note
   `a/b` means "library a, cell b" under S/N but "descend a then b" under D — the
   shortcut chooses the interpretation. Documented, intentional.
2. **Ambiguity `lib/cell` vs 2-level path.** Resolved by #1 (shortcut picks meaning).
3. **Vectors.** `\w`-only; bracketed vector instance names won't match (same limitation
   as `descend_to_last`). Noted; revisit if needed.
4. **Viewing a symbol (not schematic) for CTRL-ALT-S no-selection.** `schematic_cellview`
   works on any file path → still locates the cell.
5. **No remembered location for CTRL-ALT-D write.** Hard error with a hint to use Alt-E.
6. **Placement UX.** Pre-filled `enter_text` (editable) + cursor-follow `move_objects`.
   If the user empties the dialog, no note is created.
7. **Headless.** libmgr + new-window + placement need Tk/X → manual GUI verification.
   The parse helpers and the descend path are fully headless-testable.

## 7. Out of scope (v1)

- Vector/bus instance names in deep paths.
- Multi-line / multi-token notes for CTRL-ALT-D (only the leading path is read).
- A view selector for the read-only open (always the `schematic` view).

## 8. Test plan

Headless (`xschem --nogui --pipe -q --script`), RED-first:
- `cadence::first_libcell` — extracts `{lib cell}` from `"devices/res"`,
  `"see devices/res for ref"`, returns `{}` for `"plainword"` / empty.
- `cadence::deeppath_from_text` — `"Xamp/Xstage1/Xmir"` → `{Xamp Xstage1 Xmir}`;
  `"devices/res"` → `{devices res}`; `"nopath"` → `{}`; leading-space tolerated.
- `cadence::descend_instnames` — on a 3-level fixture, descends to the named leaf
  (assert `xschem get sch_path`); a bad name aborts returning 0.
- CTRL-ALT-D write→read round trip headlessly: ALT-E to remember, `deeploc_note` with
  nothing selected creates a note whose text (`xschem text_string`) equals the
  `/`-joined path; then selecting that note + `deeploc_note` descends back.

Manual GUI checklist (real WSLg):
- CTRL-ALT-S with an instance / nothing / a `lib/cell` note → manager raised on the
  right cell.
- CTRL-SHIFT-N with an instance / a `lib/cell` note → schematic opens read-only in a new
  window.
- CTRL-ALT-D nothing-selected → pre-filled note follows the cursor, drops on click;
  selecting it + CTRL-ALT-D descends there.

## 9. Acceptance criteria

Status: implemented; `tests/cadence_note_nav.tcl` green (20 checks). C additions:
`xschem get texts`, `xschem get mousex_snap|mousey_snap` (the only missing primitives).

1. ✅(logic) CTRL-ALT-S: instance→its master; nothing→current cell; `lib/cell` note→that
   cell; manager raised each time. Parse + routing headless; the raise is ◻ manual GUI.
2. ✅(logic) CTRL-SHIFT-N: instance→its schematic RO in new window; `lib/cell` note→that
   cell's schematic RO in new window. ◻ manual GUI for the actual window.
3. ✅ CTRL-ALT-D read path (note→descend) headless; ✅ write seam (`remembered_path`)
   headless; ◻ the dialog + cursor-follow placement is manual GUI.
4. ✅ ALT-X behaviour unchanged (same `descend_instnames` engine, now shared).
5. ✅ Headless parse + descend tests green. ◻ GUI behaviours (libmgr raise, RO new
   window, note placement) are manual — automated GUI verification is unsafe here
   (the libmgr Tk dialog blocks the headless `--script`→exit path on WSLg/Weston and
   risks wedging the compositor; PNG export only captures the canvas, not Tk dialogs).
