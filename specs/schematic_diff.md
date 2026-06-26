# Spec: Visual diff of two schematics / two symbols

Branch: `library-manager`. Status: **proposed** (no code yet). This is a scoping
document, not an implementation record.

## 1. Goal

Let a user **see the differences between two schematics, or two symbols, drawn on
the canvas** — added objects in one colour, removed in another, changed in a third,
everything else dimmed — the way Cliosoft/Keysight **SOS graphical diff** shows an
instance/wire/pin-level visual delta rather than a raw text diff of the datafile.

Two distinct capabilities, one engine:

1. **Compare any two cellviews** — pick file A and file B (two `.sch`, or two `.sym`)
   and see the visual delta. This is independent of version control: it is useful for
   "are these two cells actually the same?", "what did the migration script change?",
   "diff golden vs regenerated", reviewing a copied cell, etc.

2. **Compare across revisions (the predominant application)** — diff a cellview's
   **working copy against a git revision**, **HEAD against an older commit**, or **two
   arbitrary commits**, launched from the Library Manager and its History dialog. This
   is where a *graphical* diff earns its keep: a unified `git diff` of a `.sch` file is
   technically readable (the format is line-oriented) but says nothing about *what moved
   on the canvas*. See `specs/library_git.md` for the revision-control substrate this
   builds on.

The `.sch` and `.sym` text record format is identical (`save.c`), so symbols and
schematics share one diff engine; symbols simply skew toward graphics/text/pins while
schematics skew toward instances/wires.

## 2. What exists today, and why it is not enough

xschem already ships a comparator: **`compare_schematics(const char *f)`**
(`xinit.c:773-944`), reachable as `xschem compare_schematics [file]`
(`scheduler.c:811`) and wired into the **Hilight** menu — *"Set schematic to compare
and compare with"*, *"Swap compare schematics"*, and a *"Compare schematics"*
checkbutton (`xschem.tcl:11324-11335`, `swap_compare_schematics` at `xschem.tcl:9115`).
State lives in `xctx->sch_to_compare`.

How it works: it hashes schematic 1's objects, loads schematic 2 into a second
`Xschem_ctx` (`alloc_xschem_data` + `load_schematic`, reusing the live window's
viewport, `xinit.c:820-860`), hashes schematic 2, and flags every object present in
one but not the other with the `SELECTED` flag, drawing the mismatches via
`draw_selection()` — schematic-2-only in `PINLAYER` colour (red), schematic-1-only in
`SELLAYER` colour (`xinit.c:897-941`). It is **bidirectional** and overlays both deltas
onto the **single live canvas**.

Its limitations are exactly the gap this spec closes:

- **Only instances (`C`) and wires (`N`) are compared.** Graphical objects — lines
  `L`, rectangles `B`, arcs `A`, polygons `P`, text `T` — and the global property
  records (`G K V S E F`) are completely ignored. **This makes it nearly useless for
  symbols**, which are almost entirely `L/B/A/P/T` plus pin rects.
- **No notion of "changed".** Matching is an exact hash of
  `C <name> <x> <y> <rot> <flip> <props>` / `N <x1> <y1> <x2> <y2>`. An instance that
  moved 1 unit, or whose `W=2u` became `W=3u`, appears as **both** a removal **and** an
  addition at (nearly) the same spot — visually noisy and semantically wrong. A real
  diff must report that one object *changed*, and ideally *what* changed.
- **Overlay-only, on the live canvas.** It mutates the current window's selection set
  and paints onto the schematic the user is editing. There is no dedicated, read-only
  diff view, no colour legend, no list of differences, no next/prev-difference
  navigation, no way to step through changes the way SOS does.
- **No data output.** It returns only `0/1` (any-difference). Nothing structured is
  handed back to Tcl, so no report, no difference tree, no test assertions on *which*
  objects differ.
- **Not connected to the Library Manager or git.** You cannot say "diff this cell at
  HEAD vs my working copy" or "diff these two commits" from the browser; you must hand
  it a file path.

**Decision: build the new engine as a superset of `compare_schematics`, then
re-point the existing Hilight-menu entry at it** (keeping `xschem compare_schematics`
working as a thin alias for backward compatibility / existing keybindings). We are
not throwing the old function away; we are generalising its load-two-contexts-into-one-
viewport mechanism (`xinit.c:819-860`) and replacing its matcher and its renderer.

## 3. Object coverage (the whole record set)

The diff must cover **every** object type in the file format (`save.c` load/save):

| Rec | Object    | Struct      | Identity for matching (see §4)                         |
|-----|-----------|-------------|--------------------------------------------------------|
| `C` | instance  | `xInstance` | `instname` if present, else `name`+geometry            |
| `N` | wire      | `xWire`     | endpoints (`x1 y1 x2 y2`); + `node`/bus props          |
| `T` | text      | `xText`     | anchor (`x0 y0`)+rot/flip, then text content           |
| `L` | line      | `xLine`     | `layer`+geometry                                       |
| `B` | rect/box  | `xRect`     | `layer`+geometry (pins are rects on `PINLAYER`)        |
| `A` | arc       | `xArc`      | `layer`+centre/radius/angles                           |
| `P` | polygon   | `xPoly`     | `layer`+point list                                     |
| `G K V S E F` | global props | (strings) | record kind; value = textual diff (§9)        |

All coordinates are doubles (`%.16g`) and are `ORDER`/`RECTORDER`-normalised on load
(`x1<x2, y1<y2`), so geometric keys are stable regardless of how the file listed an
edge. **There is no persistent unique id in the file** — the `id` fields on every
struct (`xWire.id`, `xInstance.id`, …) are per-session counters assigned at load and
are *not* written to disk — so matching is purely geometry + properties + (for
instances/text) a name anchor. This is a hard constraint the algorithm in §4 is built
around.

## 4. The diff model

For each object type, partition the union of A's and B's objects into four states:

- **removed** — in A, no match in B (drawn red).
- **added** — in B, no match in A (drawn green).
- **changed** — a matched pair whose attributes differ (drawn amber; optionally the
  old shape ghosted red + new shape green at the same site).
- **unchanged** — a matched, attribute-identical pair (drawn dimmed/grey, or hidden).

Matching is **two-pass per type**: an *identity key* pairs objects up; a *content
hash* then decides changed-vs-unchanged for paired objects.

- **Instances.** Identity key = `instname` attribute when present (e.g. `M3`, `R12`)
  — the only thing approximating a stable id in the format. Fall back to
  `name`+`x0,y0,rot,flip` when an instance has no name. Content hash =
  `tcl_hook2(name)` + geometry + full `prop_ptr` (mirrors the existing hash string,
  `xinit.c:804`). → a renamed device value, a moved instance, a swapped symbol, or an
  edited property surfaces as **changed**, not add+remove. Duplicate instnames
  (illegal but possible) degrade gracefully to positional matching.
- **Wires.** No name; identity key = normalised endpoints. A moved wire is genuinely a
  different wire, so wires are **add/remove only** (no "changed"). Endpoint-touching
  heuristics for "a wire was extended" are explicitly **out of scope** for v1
  (documented limitation, §13).
- **Text.** Identity key = anchor `x0,y0,rot,flip`; content hash adds the string,
  scale, layer, font, flags. → editing the words of a label in place = **changed**;
  moving it = add/remove.
- **Graphics (`L B A P`).** Identity key = `layer` + normalised geometry; content hash
  adds `prop_ptr`, `fill`, `dash`. Practically add/remove, with "changed" only when
  same geometry gains/loses a property (e.g. a rect becomes filled). Polygons key on
  the full point list.
- **Global properties (`G K V S E F`).** Not geometric — compared as text and reported
  in the side panel (§9), and flagged in the legend as "header/property changes" since
  they have no on-canvas location.

Output is a **structured diff record set** (one record per non-unchanged object):
`{type state a_index b_index key summary}` where `summary` is a short human string
(`"R12: W=2u → 3u"`, `"wire (40,10)-(40,30) removed"`, `"pin VSS added"`). This is the
single source of truth that drives **both** the canvas overlay **and** the difference
list, and is what `xschem schematic_diff` returns to Tcl and to tests.

## 5. Visual presentation

### 5.1 Primary mode — composite overlay in a dedicated read-only diff view

Open a **new, read-only schematic tab/window in "diff mode"** (not the user's live
editing canvas — unlike today's `compare_schematics`). It shows the **union** of A and
B at a shared viewport (full-zoom the union bbox), colour-coded:

```
  removed   red      (in A only)
  added     green    (in B only)
  changed   amber    (matched, attributes differ)
  unchanged dimmed    grey, low-contrast — context, not noise
```

A **legend** strip and a title (`diff: A  ◁▷  B`) make the mapping explicit. Diff mode
is read-only (reuse the per-window `xctx->readonly` protection layer from the library
work) so the view cannot be accidentally edited or saved.

Rationale for composite-over-side-by-side as the default: spatial coincidence is the
whole point — a moved/changed instance is *obvious* when old and new sit on the same
coordinates, which is precisely what SOS graphical diff does and what a text diff
cannot show.

### 5.2 Secondary mode — synchronised side-by-side (optional, later phase)

Two read-only panes, A | B, each tinted (A highlights removed, B highlights added),
with **locked pan/zoom** so scrolling one scrolls both. The tab/window infrastructure
already supports multiple live contexts (`save_xctx[]`, `new_schematic`,
`get_save_xctx`/`get_old_xctx`, `xinit.c`). Useful when the composite is too dense
(large flat schematics). Marked **Phase 4 / optional**; the spec is built so the same
diff record set feeds either presentation.

### 5.3 Difference list + navigation

A dockable panel (or the lower pane of the diff dialog) lists the diff records grouped
by state and type, each row showing the `summary`. Selecting a row **pans/zooms the
diff view to that object** and flashes it; **Next / Prev difference** (n/N) walk the
list. This is the SOS "change browser" affordance and the feature that makes a large
diff actually navigable. Reuse the two-pane `ttk::treeview` + detail pattern already
built for `libmgr::history_dialog` (`library_manager.tcl:596-655`).

## 6. Architecture

This feature **requires C and a rebuild** — unlike `library_git.tcl`, which was pure
Tcl. Object-level matching and canvas rendering live in the C engine and object arrays;
they cannot be done from Tcl. Be honest about that in the commit/PR.

### 6.1 C core — `schematic_diff` engine (extends `compare_schematics`)

New code, most naturally in `xinit.c` beside `compare_schematics`, or a new
`schematic_diff.c` added to `src/Makefile` `OBJ` + an explicit compile rule (and
`Makefile.in`), per CLAUDE.md:

- **Load both sides into separate contexts** reusing the proven sequence at
  `xinit.c:819-860` (`alloc_xschem_data` → copy viewport/GC fields → `load_schematic`).
  Generalise it to load *two* named files into two scratch contexts rather than
  assuming one side is the live `xctx`. Both sides are temp files for the git case
  (§8), so neither need be the open schematic.
- **Compute the diff record set** per §4 using the existing `Int_hashtable`
  machinery (`int_hash_init/lookup`, `node_hash.c`), one hash per object type per side,
  with the two-key (identity, content) scheme. Produce the `{type state a_index
  b_index summary}` list.
- **Render the overlay**: paint each non-unchanged object in its state colour into the
  diff view. Reuse one of the existing override mechanisms rather than touching the
  core `draw()` loop:
  - `draw_selection()` with a per-state GC (today's approach, `xinit.c:900/941`), or
  - the per-instance `xInstance.color` override consumed by `draw_hilight_net()`
    (`hilight.c:2260-2268`), or
  - the overlay/`gc_scope`-style custom-GC path (`draw_hover_shape()`, `draw.c:5462`,
    `xinit.c:459`).
  Recommendation: dedicate **four diff GCs** (removed/added/changed/unchanged) created
  like `gc_scope`, and a `draw_diff_overlay()` that walks the diff record set — this
  keeps diff colours independent of layer/selection colours and lets the legend match
  exactly.
- **Free the scratch contexts** (`delete_schematic_data`, `xinit.c:905`) and never
  disturb the user's live `xctx` (the v1 difference from `compare_schematics`, which
  paints on the live canvas).

### 6.2 Tcl dispatcher surface (`scheduler.c`)

New `xschem` subcommands beside `compare_schematics` (`scheduler.c:811`):

- `xschem schematic_diff <fileA> <fileB>` → opens the diff view (§5.1) and **returns
  the structured diff record set** (a Tcl list of dicts) for the difference panel and
  for tests. The pivotal upgrade over `compare_schematics`, which returns only `0/1`.
- `xschem schematic_diff -count <fileA> <fileB>` → counts only (cheap, headless).
- `xschem diff_goto <record-index>` / `diff_next` / `diff_prev` → drive §5.3 navigation.
- Keep `xschem compare_schematics` as a thin compatibility alias.

### 6.3 Tcl UI

- **Diff dialog / view**: legend + difference treeview + detail, modelled on
  `libmgr::history_dialog`'s vertical `ttk::panedwindow` two-pane form
  (`library_manager.tcl:596-670`).
- **Main-editor entry**: repoint the existing Hilight-menu *"Compare schematics"*
  items at the new engine (or add a *Tools → Visual diff…* entry); free-form file A/B
  via `load_file_dialog` (already used by `compare_schematics`, `xinit.c:789`).

## 7. Library Manager surface

Hook into the existing browser (`library_manager.tcl`) and git backend
(`library_git.tcl`), following the established `ctx_* → do_* → backend` seam used for
the git actions.

### 7.1 Context-menu additions (Cell and View menus)

After the **History** entry (`library_manager.tcl:158`/`174`):

- **Compare with revision…** — pick a commit from this cellview's history (reuse
  `lib_git_log_records`, `library_git.tcl:185`) → diff **working copy vs that
  revision**. Materialise the chosen blob to a temp file (§8) and call
  `xschem schematic_diff <tempfile> <workingfile>` (old=A, new=B).
- **Compare with…** — pick a second cellview from the browser → diff the two on-disk
  datafiles. This is the version-control-independent "any two" path. Resolve both via
  `libmgr::cellview_files {lib cell view}` (`library_manager.tcl:502`).

### 7.2 History dialog additions

In `libmgr::history_dialog` (`library_manager.tcl:596`):

- **Diff vs working** — selected commit ◁▷ working copy.
- **Diff selected pair** — extend the commit treeview to allow picking two commits
  (Ctrl-click) → diff revision A ◁▷ revision B.

Both go through one `libmgr::do_diff {lib cell view revA revB}` worker (the
dialog-free `do_*` seam) that resolves `{root pathspec}` (`libmgr::git_target`,
`library_manager.tcl:517`), materialises each side, and invokes `xschem
schematic_diff`. A `revB` of `{}` means "working copy on disk".

### 7.3 Selection model note

The three browser panes are single-select (`-selectmode browse`,
`library_manager.tcl:91`). "Compare with…" therefore uses a **second pick** (a small
picker or "remember first selection, then pick second"), not multi-select in the main
panes — consistent with how the Maintain picker handles multi-target operations.

## 8. Git integration — materialising a revision

To diff against a git revision we need the file *as of that revision* on disk. Add to
`library_git.tcl` (pure Tcl, reuses the `{root pathspec}` invariant from
`specs/library_git.md §2.1`):

- `lib_git_show_version {root pathspec revision}` → run
  `git -C <root> show <revision>:<pathspec>` and write the blob to a temp file under
  `$XSCHEM_TMP_DIR` (name encodes cell/view/rev so the diff title is meaningful), and
  return the temp path. Throws (human message) if the path did not exist at that
  revision — i.e. the cellview was **added** since, which the diff view should state
  plainly ("not present at <rev>").
- The diff **targets** then reduce to two file paths fed to `xschem schematic_diff`:
  - working vs HEAD → `{show HEAD:pathspec}` vs working file
  - working vs `<rev>` → `{show rev:pathspec}` vs working file
  - `<revA>` vs `<revB>` → two `show` temp files
  - any two cellviews → two `cellview_files` paths (no git at all — capability 1)

Temp files are cleaned on diff-view close. Embedded symbols (`[ ... ]` blocks after a
`C` record, `save.c:3185`) travel inside the datafile, so they diff for free.

## 9. Property / header / textual diff

Global property records (`G K V S E F`) and per-object `prop_ptr` strings have no
canvas location, so a purely visual diff would silently drop them. Surface them in the
**difference list** as text rows ("schematic property `S{...}` changed", "instance R12
property `W` 2u→3u"), and offer a **"show text diff"** action on any changed row that
pops the raw unified `git diff` (or a Tcl line diff for the non-git "any two" case) for
that file in a read-only `viewdata` window (`xschem.tcl:8670`). Graphical and textual
diff thus complement each other rather than compete.

## 10. Symbols

No special engine — `.sym` is the same format. In practice symbol diffs are dominated
by `L/B/A/P/T` and pin rects (`B` on `PINLAYER`), exactly the object types today's
`compare_schematics` ignores, so symbols are the **biggest beneficiary** of §3's full
coverage. A pin added/removed/renamed (pin name lives in the rect's `prop_ptr`) must
show as added/removed/changed — important because pin changes break every parent that
instantiates the symbol.

## 11. Testing

- `tests/headless/test_schematic_diff.tcl` — fixtures of two `.sch`/`.sym` pairs
  exercising every state × every object type: instance moved/renamed/value-changed/
  added/removed, wire add/remove, text edit-in-place vs move, line/rect/arc/poly
  add/remove and property-only change, pin add/remove/rename in a symbol, global
  property change. Assert on the **returned record set** of `xschem schematic_diff
  -count` / full (this is why the engine returns structured data, §6.2) — RED-genuine
  before implementation. Headless via `xschem ... --no_x --pipe -q --script`.
- Identity-matching unit cases: duplicate instnames, unnamed instances, ORDER-
  normalised geometry (edge listed both directions must match), embedded symbols.
- `tests/headless/test_library_git.tcl` extension: `lib_git_show_version` for present
  / absent-at-revision / two-revision cases across the §2 topologies.
- Library-Manager GUI seam: extend `test_lib_manager_ctx.tcl` for `do_diff` workers.
- Regression: keep `xschem compare_schematics` behaviour green via its alias; full lib
  suite + netlist golden sweep; manual eyeball of the diff view, legend, and
  next/prev navigation on a real edit.

## 12. Build impact

**A rebuild is required** (new C in `xinit.c`/optional `schematic_diff.c`, new
`scheduler.c` branches). Contrast `specs/library_git.md`, which was pure Tcl with no
rebuild. If a new `.c` file is used: add it to `src/Makefile` `OBJ` with an explicit
compile rule and to `Makefile.in` (CLAUDE.md). The file format and `XSCHEM_FILE_VERSION`
are **untouched** — no datafiles change, and old/new files diff against each other.

## 13. Honest limitations (surface, don't hide)

- **Wire "changed" is not modelled.** A moved/extended/split wire shows as remove+add,
  not "changed" — wires have no identity beyond endpoints (§4). Topology-aware wire
  matching is explicitly out of scope for v1.
- **Matching is heuristic, not identity-based**, because the format stores no
  persistent object id (§3). Pathological inputs (many identical unnamed instances,
  duplicate instnames) fall back to positional matching and may mis-pair; the diff is a
  *review aid*, not a formal proof of equivalence — netlist comparison remains the
  authority for electrical equivalence.
- **Cross-cell / hierarchical diff is out of scope.** v1 diffs a single cellview's two
  versions, not a whole design tree. (A recursive hierarchy diff is a plausible Phase 5.)
- **Property diff is textual**, not semantically aware (it won't normalise `2u` vs
  `2.0u`); the on-canvas amber flag tells you an instance changed, the text row tells
  you the raw before/after.
- **Absent-at-revision** (cellview added since the chosen commit) is reported as
  "whole file added", since there is no A side.

## 14. Open decisions (resolve before Phase 1)

1. **Composite vs side-by-side as the shipped v1 default** (§5). Recommendation:
   composite overlay first (matches SOS, single context to manage), side-by-side as an
   opt-in later phase.
2. **Render path**: dedicate four diff GCs + `draw_diff_overlay()` (recommended) vs
   reuse `draw_selection()`/`inst.color` (less new code, but couples diff colours to
   selection/highlight colours). (§6.1)
3. **Diff view as a real tab vs a lightweight modal canvas.** Recommendation: a
   read-only tab so existing pan/zoom/find work unchanged.
4. **Keep `compare_schematics` as alias vs retire its menu entries** in favour of the
   new dialog. Recommendation: keep the alias (keybindings/scripts), repoint the menu.

## 15. Phasing

1. **C engine + `xschem schematic_diff` returning the record set**, all object types,
   composite overlay in a read-only view, four diff GCs, legend. Headless tests green.
2. **Difference list + next/prev navigation** (§5.3); main-editor menu repoint.
3. **Library Manager integration**: `lib_git_show_version`, Cell/View *Compare…*,
   History-dialog *Diff vs working* / *Diff pair*, `do_diff` seam (§7–8).
4. **Optional**: synchronised side-by-side mode (§5.2); text-diff drill-in polish (§9).
5. **Future**: recursive hierarchical diff; topology-aware wire matching.
