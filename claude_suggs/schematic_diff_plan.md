# Plan: Visual diff of two schematics / two symbols

Branch: `library-manager`. Spec: `specs/schematic_diff.md`.

## Difficulty: Moderate–High, **requires C + a rebuild**

Unlike the pure-Tcl `library_git` work, this touches the C engine: object-level
matching and canvas rendering live in C and the `xctx` object arrays. The good news
is that **every mechanism we need already exists** and is battle-tested — we are
generalising three proven facilities:

1. **Load-two-files-into-two-contexts** — `compare_schematics()` (`xinit.c:773-944`)
   already does `alloc_xschem_data` → copy viewport/GC fields → `load_schematic`
   (`xinit.c:819-860`) and `delete_schematic_data` (`xinit.c:905`).
2. **Object hashing/matching** — the `Int_hashtable` API
   (`int_hash_init`/`int_hash_lookup`/`int_hash_free`, `xschem.h:1741-1745`;
   `XLOOKUP`=1, `XINSERT_NOREPLACE`=3, `xschem.h:316/318`) — `compare_schematics`
   already hashes `C …`/`N …` strings with it.
3. **A side-array overlay drawn with a dedicated GC** — the **apply-scope highlight**
   is the exact template: parallel `xctx` arrays `scope_hi_type[]` / `scope_hi_id[]`
   (stable id, resolved to **index at draw time**), a count `scope_hi_n`, a dedicated
   `gc_scope` GC created/freed in `xinit.c:459/473` and recoloured in `build_colors`
   (`xinit.c:1100`), and `draw_scope_highlight()` run at the **end of `draw()`**
   (`draw.c:5332-5380`). The hover overlay (`gc_hover`, `draw_hover_shape`,
   `xschem.h:1436`) is a second example.

The diff feature is, structurally, **#1 + #2 to build a read-only union view, then
#3 (×4 GCs) to colour it**. We keep `compare_schematics` working as a back-compat
alias and repoint its menu entry.

## Locked design decisions (from spec §14)

- **Composite overlay** is the shipped v1 presentation (spec §5.1): one read-only
  diff view showing the **union** of A and B, colour-coded. (Side-by-side §5.2 is a
  later optional phase.)
- **Four dedicated diff GCs** — `removed / added / changed / unchanged` — created and
  recoloured exactly like `gc_scope`, painted by a new `draw_diff_overlay()`. Diff
  colours are therefore independent of layer/selection/highlight colours.

## Architecture at a glance

| Concern | Mechanism | Anchor |
|---|---|---|
| New engine | `src/schematic_diff.c` (new file) + proto in `xschem.h` | OBJ line `Makefile:8` |
| Load both sides | `alloc_xschem_data` / `load_schematic` / `delete_schematic_data` | `xinit.c:819-905` |
| Build **union** diff ctx | append B-only objects via `store.c` (`storeobject`/`wire_store`/`store_arc`/`store_poly` + text/instance append) | `store.c:132/174/226/339` |
| Match A↔B | `Int_hashtable`, **two keys per type** (identity + content) | `xschem.h:1741` |
| Per-object diff state | new `xctx` side-array keyed by stable `id` (scope_hi pattern) | `draw.c:5348-5360` |
| Render | 4 × `gc_diff[]` + `draw_diff_overlay()` at end of `draw()` | `draw.c:5332` model |
| Tcl access + record set | new `xschem schematic_diff` branch in `scheduler.c` | `scheduler.c:811` |
| Read-only view | reuse per-window `xctx->readonly` (library work) | — |

### Why a **union context** (not the transient overlay `compare_schematics` uses)

`compare_schematics` draws B's mismatches then **frees B** (`xinit.c:905`), so B-only
objects vanish — fine for a flash, useless for a navigable, persistent diff view. v1
instead builds **one** read-only context holding the union: load A, then **append the
B-only objects** into it via the same `store.c` functions the loader itself calls
(`save.c:2851` → `wire_store`). Every object then lives in one context, draws
normally, and the overlay just **recolours** it by state. Navigation/pan-to (Phase 2)
works because added objects are real objects with real coordinates.

### New data structures (Step 1.2)

In `Xschem_ctx` (near `gc_scope`/`gc_hover`, `xschem.h:1045-1053`, and
`sch_to_compare`, `xschem.h:1116`):

```c
GC gc_diff[4];                 /* DIFF_REMOVED/ADDED/CHANGED/UNCHANGED */
struct diff_rec *diff_rec;     /* parallel to the apply-scope arrays */
int diff_n;                    /* number of records (0 = inactive) */
int diff_alloc;                /* capacity */
int diff_cur;                  /* current record for next/prev nav (Phase 2) */
char diff_fileA[PATH_MAX];     /* for the legend/title */
char diff_fileB[PATH_MAX];
```

`struct diff_rec` (in `xschem.h`):
```c
struct diff_rec {
  short otype;          /* WIRE/xRECT/LINE/ELEMENT/xTEXT/ARC/POLYGON (xschem.h:265+) */
  short state;          /* DIFF_REMOVED=0 ADDED=1 CHANGED=2 UNCHANGED=3 */
  unsigned int id;      /* STABLE object id in the diff ctx, resolved to index at draw */
  double cx, cy;        /* object centre — pan-to target for Phase-2 navigation */
  char *summary;        /* "R12: W=2u -> 3u", "pin VSS added", ... (my_strdup) */
};
```
State constants `#define DIFF_REMOVED 0 … DIFF_UNCHANGED 3` next to `SELECTED`
(`xschem.h:243`).

---

## Phase 1 — C diff engine + `xschem schematic_diff` (composite overlay)

Goal: `xschem schematic_diff <A> <B>` opens a read-only composite diff view of two
on-disk files (sch or sym), all object types coloured by state, and **returns the
structured record set**. Headless `-count` form for tests. No Library-Manager / git
yet (Phase 3). This is the bulk of the work; stage object coverage 1a → 1b.

### Step 1.0 — Recon (no code): confirm the three uncertain seams
1. **Instance append**: find the function that adds an instance to the current ctx
   given `name,x0,y0,rot,flip,prop` (grep `place_symbol`, `new_instance`, `xctx->inst`
   appenders near `save.c:load_inst`). Record its exact signature.
2. **Text append**: find the text-record store (grep `xText`/`place_text`/`store`
   near `save.c:load_text`).
3. **Type constants**: confirm `ARC` and `POLYGON` `#define`s exist (we verified
   `WIRE=1,xRECT=2,LINE=4,ELEMENT=8,xTEXT=16`, `xschem.h:265-269`).
**Done when** the three signatures are written into this plan; they parametrise
Steps 1.7–1.8.

### Step 1.1 — Create the file skeleton + build wiring (compiles, does nothing)
1. New `src/schematic_diff.c` with `#include "xschem.h"` and a stub
   `int schematic_diff(const char *fa, const char *fb, int count_only){ return 0; }`.
2. Proto in `xschem.h` near `compare_schematics` (`xschem.h:1850`):
   `extern int schematic_diff(const char *fa, const char *fb, int count_only);`
3. `src/Makefile`: add `schematic_diff.o` to `OBJ` (`Makefile:8`) and a compile rule
   modelled on `xinit.o` (`Makefile:87-88`):
   ```make
   schematic_diff.o: schematic_diff.c
   	$(CC) -c $(CFLAGS) -o schematic_diff.o schematic_diff.c
   ```
4. Mirror both into `src/Makefile.in` (the canonical template — CLAUDE.md) and add to
   `CMakeLists.txt` source list for parity.
**Verify:** `make` clean-builds; binary runs unchanged.

### Step 1.2 — Add the `xctx` fields, `struct diff_rec`, and constants
Add the fields/struct/`#define`s from "New data structures" above. Initialise
`diff_n=0`, `diff_rec=NULL`, `diff_alloc=0` wherever `scope_hi_*` is initialised, and
**free** `diff_rec` (and each `summary`) wherever `scope_hi` is torn down (grep
`scope_hi_alloc` to find both sites).
**Verify:** `make`; no behavioural change.

### Step 1.3 — Create / free / recolour the four diff GCs
1. In `create_gc()` (`xinit.c:445`+), beside `gc_scope` creation (`xinit.c:459`):
   `for(i=0;i<4;i++) xctx->gc_diff[i] = XCreateGC(display, xctx->window, 0L, NULL);`
2. In the GC-free path (`xinit.c:473`): `XFreeGC` each.
3. In `build_colors()` (`xinit.c:~1100`, beside the `gc_scope` `XSetForeground`):
   set foregrounds from four new Tcl colour vars
   `diff_color_{removed,added,changed,unchanged}` (default red `#ff3030`, green
   `#30c030`, amber `#e0a000`, grey `#808080`; dark/light aware like `gc_scope`).
   `XSetLineAttributes(..., THICK?, LineSolid, …)`.
4. Declare the four Tcl vars with `set_ne` defaults in `xschem.tcl` (near
   `compare_sch`, `xschem.tcl:12065`) and add them to the colours config list
   (`xschem.tcl:10354` area) so they persist.
**Verify:** `make`; run; no visible change (GCs unused yet).

### Step 1.4 — `draw_diff_overlay()` (the renderer), wired into `draw()`
1. New `void draw_diff_overlay(void)` in `schematic_diff.c` (proto in `xschem.h`),
   modelled line-for-line on `draw_scope_highlight()` (`draw.c:5363`): if
   `xctx->diff_n==0` return; else loop records, **resolve `id`→index at draw time**
   per `otype` (same id→index resolution scope_hi uses), and redraw that object in
   `gc_diff[state]` (use the existing per-type temp/overlay draw helpers, e.g.
   `draw_hover_shape(xctx->gc_diff[state], otype, idx, col)` for outlines, or the
   `drawtemp*`/`draw_symbol` calls `draw_selection` uses, `move.c:210`).
2. Call `draw_diff_overlay()` at the **end of `draw()`**, right where
   `draw_scope_highlight()` is invoked (`draw.c:5380` area).
**Verify:** `make`; still inert (`diff_n==0`). Unit-test later by hand-seeding a record.

### Step 1.5 — The matcher core (1a: instances + wires, parity with compare)
In `schematic_diff()`:
1. Load A: `alloc_xschem_data` + viewport copy + `load_schematic(1, fa, 0, 1)`
   (clone `xinit.c:819-860`). Keep this ctx as the **diff/union ctx**; mark
   `xctx->readonly`.
2. Build **two** `Int_hashtable`s over A: `idA` (identity key) and `cA` (content
   key). For instances, identity = `instname` if set else `C <name> <x> <y> <rot>
   <flip>`; content = the full `compare_schematics` string `C <tcl_hook2(name)> <x>
   <y> <rot> <flip> <prop>` (`xinit.c:804`). For wires, identity == content ==
   `N <x1> <y1> <x2> <y2>` (`xinit.c:813`).
3. `alloc_xschem_data` a **scratch B ctx**, `load_schematic(1, fb, 0, 1)`, build
   `idB`/`cB` the same way.
4. Classify (record into the **A/union** ctx's `diff_rec`, using each object's stable
   `id`, with `cx,cy` = object centre, and a `summary`):
   - A-object: `idB` miss → **removed**; `idB` hit but `cB` miss for its content →
     **changed** (summary = first differing token); else **unchanged**.
   - B-object: `idA` miss → **added** → **append it into the A/union ctx** (Step 1.7),
     stable id of the new copy goes into the record.
5. `delete_schematic_data(0)` the scratch B ctx; switch back to the union ctx.
**Verify:** add a headless test (Step 1.10) over inst/wire fixtures.

### Step 1.6 — Dispatcher branch + return the record set
In `scheduler.c`, beside `compare_schematics` (`scheduler.c:811`):
```
else if(!strcmp(argv[1], "schematic_diff")) { ... }
```
1. `-count A B` → call `schematic_diff(A,B,1)`, return the count as itoa (cheap,
   headless, no view).
2. `A B` → `schematic_diff(A,B,0)`; build the **diff view** (open the union ctx as a
   read-only tab via the `new_schematic`/tab path), trigger a redraw (overlay paints),
   and set the Tcl result to the **record list** — one `{otype state summary cx cy}`
   sublist per `diff_rec` (Tcl list-of-lists, the single source of truth for the
   Phase-2 panel and for tests). Apply the `~` expansion regsub `compare_schematics`
   uses for paths (`scheduler.c:813`).
**Verify:** `xschem schematic_diff -count a.sch b.sch` prints an int headless;
full form lists records.

### Step 1.7 — Append B-only objects into the union ctx (wires + instances)
Using the Step 1.0 signatures:
- Wire: `wire_store(-1, x1,y1,x2,y2, 0, prop)` (exactly `save.c:2851`).
- Instance: the confirmed instance-append fn with `name,x0,y0,rot,flip,prop`.
Capture the returned/last stable `id` for the diff record. Append happens **before**
freeing the B scratch ctx (read fields from B, write into the union ctx — mind the
active-`xctx` switch; copy the needed scalars/strings into locals first).
**Verify:** added objects appear (uncoloured first), then green after Step 1.4 wiring.

### Step 1.8 — Extend coverage to graphics + text + global props (1b)
Repeat Steps 1.5/1.7 for the remaining types — this closes the spec §3 gap that makes
the old `compare_schematics` useless for symbols:
- **Text `T`**: identity = anchor `x0,y0,rot,flip`; content adds string/scale/layer/
  font/flags. Append via the Step 1.0 text-store fn.
- **Lines `L` / rects `B`**: identity = `layer`+normalised geometry; content adds
  `prop_ptr`/`fill`/`dash`. Append via `storeobject(-1, x1,y1,x2,y2, type, …)`
  (`store.c:226`).
- **Arcs `A`**: `store_arc` (`store.c:132`); **polygons `P`**: `store_poly`
  (`store.c:174`) — identity = layer+centre/radius/angles, resp. layer+point list.
- **Global props `G K V S E F`**: compared as strings; emit **text-only** diff records
  (`otype` = a sentinel, no `cx,cy`) surfaced only in the list (spec §9).
Note: **pins are rects on `PINLAYER`** with the pin name in `prop_ptr` — so
add/remove/rename of a pin falls out of the rect path automatically (spec §10).
**Verify:** symbol fixtures (pin add/remove/rename, graphics edits) in Step 1.10.

### Step 1.9 — Legend + read-only guard + cleanup
1. Tiny legend strip in the diff view (Tcl) mapping the four colours to
   removed/added/changed/unchanged, plus title `diff: <A>  ◁▷  <B>`.
2. Confirm the view is read-only (`xctx->readonly`) so it can't be saved/edited.
3. Closing the diff tab frees `diff_rec`+summaries and the union ctx (Step 1.2 teardown
   path); `diff_n=0`.
**Verify:** open, eyeball colours/legend; close; no leak (run under `-d 3 -l log`,
CLAUDE.md leak-check).

### Step 1.10 — Headless tests (RED-genuine first)
`tests/headless/test_schematic_diff.tcl`, run via `xschem … --no_x --pipe -q --script`:
fixtures pairs exercising **every state × every type** — instance moved / renamed /
value-changed / added / removed; wire add/remove; text edit-in-place vs move; line/
rect/arc/poly add/remove + property-only change; **symbol** pin add/remove/rename;
global-prop change. Assert on the returned record set of `xschem schematic_diff
-count` and full form. Edge cases: duplicate instnames, unnamed instances,
ORDER-normalised geometry (edge listed both directions must match), embedded symbols
(`[ … ]`, `save.c:3185`).
**Verify:** tests fail before 1.5–1.8, pass after.

---

## Phase 2 — Difference list, navigation, main-editor menu repoint

### Step 2.1 — Difference panel
Tcl two-pane form modelled on `libmgr::history_dialog`
(`library_manager.tcl:596-670`): upper `ttk::treeview` of records grouped by
state/type (columns State | Type | Summary), lower detail pane. Populated from the
Step 1.6 record list.

### Step 2.2 — Pan-to + flash + next/prev
1. `xschem diff_goto <rec-index>` → pan/zoom the diff view to that record's `cx,cy`
   and flash it (reuse the hover/scope flash path).
2. `xschem diff_next` / `diff_prev` → advance `xctx->diff_cur`, call `diff_goto`.
3. Bind treeview `<<TreeviewSelect>>` → `diff_goto`; bind `n`/`N` keys in the diff
   view. (Mirror `history_show`, `library_manager.tcl:658`.)

### Step 2.3 — Repoint the main-editor menu
Repoint the Hilight-menu *Compare schematics* items (`xschem.tcl:11324-11335`) at the
new dialog (free-form A/B via `load_file_dialog`, as `compare_schematics` already does
at `xinit.c:789`). **Keep `xschem compare_schematics` as a thin alias** so existing
keybindings/scripts (`swap_compare_schematics`, `xschem.tcl:9115`) still work.
**Verify:** GUI eyeball; old command still returns 0/1.

---

## Phase 3 — Library Manager + git integration

### Step 3.1 — `lib_git_show_version` (pure Tcl, `library_git.tcl`)
`lib_git_show_version {root pathspec revision}` → `git -C <root> show
<revision>:<pathspec>` written to a temp file under `$XSCHEM_TMP_DIR` (name encodes
cell/view/rev for a meaningful title); returns the temp path; throws a human message
if absent-at-revision (spec §8). Reuses the `{root pathspec}` invariant
(`lib_git_context`, `library_git.tcl:73`). Temp files cleaned on diff-view close.

### Step 3.2 — `libmgr::do_diff` worker (the `do_*` seam)
`libmgr::do_diff {lib cell view revA revB}`: resolve `{root pathspec}`
(`libmgr::git_target`, `library_manager.tcl:517`), materialise each side
(`lib_git_show_version`, or working file via `libmgr::cellview_files`,
`library_manager.tcl:502`; `revB=={}` ⇒ working copy), then
`xschem schematic_diff <A> <B>`. Dialog-free, unit-testable.

### Step 3.3 — Context-menu + History-dialog entries
1. Cell/View menus (after History, `library_manager.tcl:158/174`): **Compare with
   revision…** (pick a commit via `lib_git_log_records`, `library_git.tcl:185`) and
   **Compare with…** (pick a second cellview — single-select panes ⇒ "remember first,
   pick second", spec §7.3), wired `ctx_* → do_diff`.
2. `libmgr::history_dialog`: **Diff vs working** (selected commit ◁▷ working) and
   **Diff selected pair** (Ctrl-click two commits ⇒ revA ◁▷ revB).
**Verify:** extend `test_lib_manager_ctx.tcl` for `do_diff`; manual browse→diff.

### Step 3.4 — Text-diff drill-in (spec §9)
On any changed/property row, a **show text diff** action popping the raw unified
`git diff` (git case) or a Tcl line diff (any-two case) in a read-only `viewdata`
window (`xschem.tcl:8670`).

---

## Phase 4 — Optional: synchronised side-by-side (spec §5.2)
Two read-only panes A | B with locked pan/zoom (multi-context tab infra already
exists: `save_xctx[]`, `new_schematic`, `xinit.c`). Same record set feeds it. Ship
only if the composite proves too dense on large flat schematics.

## Phase 5 — Future
Recursive **hierarchical** diff (whole design tree, not one cellview); topology-aware
**wire** matching (extend/split/move as "changed" rather than add+remove).

---

## Build & regression checklist (every phase)
- `make` from repo root (rebuild **is** required this time); `.in` templates edited,
  not generated files (CLAUDE.md).
- `cd tests && tclsh run_regression.tcl` — full lib suite + netlist golden sweep stays
  green (the diff engine must not perturb load/save/netlist paths).
- Leak check the new C with `xschem --script xschemtest.tcl -d 3 -l log` (CLAUDE.md).
- `XSCHEM_FILE_VERSION` and the record format are **untouched** — old/new files diff
  against each other; no datafile churn.

## Risk register
- **R1 — appending B-only objects across an `xctx` switch (Steps 1.7–1.8).** The
  active context flips between union and scratch; read all needed B fields into locals
  **before** writing into the union ctx, and free strings correctly (`my_strdup`/
  `my_free`, `_ALLOC_ID_`). *Mitigation:* mirror the exact field reads the loader does
  (`save.c` load_*), one type at a time, each guarded by a Step-1.10 fixture.
  *Fallback:* if instance/text append proves fragile, v1 can render added objects as
  **green outline overlays from captured geometry** (no real insertion) — loses
  selectability of added objects but keeps the visual diff; revisit in a later phase.
- **R2 — heuristic matching** (no persistent id, spec §3/§13). Duplicate/unnamed
  instances fall back to positional pairing and may mis-pair. *Mitigation:* documented
  limitation; dedicated edge-case fixtures (Step 1.10); the diff is a review aid, not
  an equivalence proof (netlist compare remains the authority).
- **R3 — overlay redraw cost** on large schematics (4-GC repaint each `draw()`).
  *Mitigation:* `draw_diff_overlay` early-outs on `diff_n==0` (scope_hi pattern); only
  the diff view carries records, never the user's live editing tabs.
- **R4 — leaks** from `diff_rec`/`summary`/union-ctx. *Mitigation:* tie teardown to
  the scope_hi teardown sites (Step 1.2); leak-check before each phase closes.
