# Enabling the master Library/Cell/View rows on `slick-property-forms`

**Audience:** someone working *on the `slick-property-forms` branch* who wants the
editable **Library / Cell / View** rows in the Edit Properties form (commit
`ebcee4a1`) to actually light up.

**Status on this branch:** the feature code is present and inert. It is wired so
that, without the OpenAccess (OA) *library registry* it depends on, the L/C/V
rows never appear and the form behaves exactly as it always did. This document
explains what the registry is, what specifically is missing here, and the two
ways to bring it in — with the trade-offs of each.

> This is a **plan**, not a change. Nothing in the registry is added by reading
> this. Decide between Option A and Option B below, then execute.

---

## 1. What the feature calls, and why it is dormant here

Two procs in `src/property_form.tcl` reach outside the form:

| Proc | Calls | Purpose |
|------|-------|---------|
| `slickprop::update_lcv` | `library_inst_lcv $sym` | **Display**: resolve the instance's symbol reference → `{lib cell view}` and populate the three rows. |
| `slickprop::lcv_compose_symbol` | `xschem cellview_path "$lib/$cell" $view` | **Edit**: turn an edited L/C/V back into a `.sym` reference so the master is re-pointed on Apply/OK. |

Both calls are wrapped in `catch`. On this branch `library_inst_lcv` does not
exist, so the lookup yields nothing, `update_lcv` hides the rows (and shows the
legacy `Symbol` + `Browse` row instead), and `lcv_compose_symbol` is gated off.
That is the intended graceful-degradation contract — **the form is never broken
by the absence of the registry.**

To make the rows functional you must add the registry these two calls depend on.

---

## 2. The dependency map (what "the registry" actually is)

The OA library model is **overwhelmingly a Tcl subsystem with thin C bridges**,
not deep C. It splits cleanly into two tiers by what you want to enable.

### Tier 1 — *display* the L/C/V rows (read-only population). **No C changes.**

The display path is pure Tcl + filesystem:

```
library_inst_lcv $sym
  ├─ abs_sym_path $ref          (Tcl proc, src/xschem.tcl — OA-aware version)
  └─ library_defs_registry      (Tcl proc, src/library_defs.tcl — parses library.defs files)
```

What is missing here, and must be added:

1. **`src/library_defs.tcl`** (~700-line Tcl file). Defines `library_inst_lcv`,
   `library_defs_registry`, `cellview_resolve`, `cellview_path` (Tcl), and the
   rest of the registry. Absent on this branch.
2. **The source line** that loads it. On the registry branches it is
   `src/xschem.tcl`: `source $XSCHEM_SHAREDIR/library_defs.tcl`. This branch has
   **neither the file nor the source line**.
3. **OA-aware `abs_sym_path` / `rel_sym_path`** in `src/xschem.tcl`. These core
   resolver procs *differ* between this branch and the registry branches — the
   OA-awareness is woven **inside** them. `library_inst_lcv` relies on
   `abs_sym_path` being able to resolve OA-style references. ⚠ This is the part
   that makes a naive file-drop unsafe (see §4).
4. **Runtime data**: a `library.defs` registry plus an OA library tree (e.g.
   `xschem_libraries_oa/`). Instances must reference *registered* library cells.
   With no registered libraries, `library_inst_lcv` correctly returns `{}` and
   the rows stay hidden — so Tier 1 ported but with an empty registry simply
   looks like "no change."

### Tier 2 — make the rows *editable* (re-point the master on Apply/OK). **Adds C shims.**

`lcv_compose_symbol` calls the **C** subcommand `xschem cellview_path`, which is
a 4-line shim that bridges straight back into Tcl:

```c
/* src/scheduler.c (registry branches) */
else if(!strcmp(argv[1], "cellview_path")) {
  if(argc > 3) tclvareval("cellview_path {", argv[2], "} {", argv[3], "}", NULL);
  else Tcl_ResetResult(interp);
}
```

That Tcl `cellview_path` proc resolves via `cellview_resolve → library_resolve`,
which calls `xschem library`. So Tier 2 needs these **thin `scheduler.c` shims**
(each merely `tclvareval`s into a Tcl proc of the same name):

- `cellview_path`  — called directly by the feature
- `library`, `libraries` — needed by `cellview_resolve` / `library_resolve`
- (`cell_views` — used by the Library Manager tree; only needed if you also want that)

The other registry shims (`get_inst_lcv`, `library_manager`, `create_instance`)
back the **Library Manager GUI** and the Cadence Create-Instance / key-binding
helpers — **not** the property form. You do not need them for the L/C/V rows.

> **Takeaway:** Tier 1 (rows *visible*, read-only) is achievable with **zero C
> changes** — Tcl file + source line + the OA resolvers + registry data. Only
> Tier 2 (rows *editable*, master re-point) requires the C shims.

---

## 3. Branch topology — where the registry lives

All three branches share merge-base `70d90907`:

| Branch | Commits ahead of `slick-property-forms` | Has the registry? |
|--------|------------------------------------------|-------------------|
| `library-manager` | ~57 | **Yes — this is the registry's home branch** |
| `fluid-editing` | ~137 | Yes (contains the `library-manager` work + more) |

The registry was developed on **`library-manager`**. ⚠ **Another contributor
actively develops that branch** — coordinate, and do any cross-branch work in a
**separate `git worktree`** (this very document was authored in one) to avoid
the shared-working-tree corruption that has bitten this repo before.

---

## 4. Why this is not a clean file-drop

The trap is item §2.3: the OA-awareness lives **inside** the core
`abs_sym_path` / `rel_sym_path` resolvers in `xschem.tcl`, which every symbol
load funnels through. You cannot simply copy `library_defs.tcl` over and expect
OA references to resolve — `library_inst_lcv`'s reverse map depends on the
OA-aware `abs_sym_path`. Porting the resolver changes risks conflicting with any
`xschem.tcl` edits on this branch, and getting them subtly wrong degrades
*all* symbol resolution, not just the L/C/V rows. Treat the registry as a
**coherent subsystem**, not a grab-bag of files.

---

## 5. The two ways to do it

### Option A — Merge `library-manager` into `slick-property-forms` (recommended for correctness)

```sh
# in a dedicated worktree, NOT your main checkout
git worktree add /tmp/slick-merge slick-property-forms
cd /tmp/slick-merge
git merge library-manager        # brings the registry coherently
# resolve conflicts (most likely in src/xschem.tcl and src/scheduler.c)
make && cd src && ./xschem        # build + smoke test
```

- **Pro:** the registry arrives whole and self-consistent — the resolvers, the
  Tcl file, the source line, and all the C shims land together and were tested
  together.
- **Con:** also brings the entire Library Manager / Create-Instance surface (~57
  commits). If `slick-property-forms` is meant to stay *minimal* (just the slick
  form), this is more than you asked for.

### Option B — Surgical port (smaller footprint, more care)

Bring only the registry pieces the form needs:

1. `src/library_defs.tcl` (the whole file).
2. The `source $XSCHEM_SHAREDIR/library_defs.tcl` line in `src/xschem.tcl`.
3. The OA hunks of `abs_sym_path` / `rel_sym_path` in `src/xschem.tcl`
   (and any helper they introduce, e.g. `lib_qualified_abs` / `lib_qualified_rel`).
4. The `scheduler.c` shims: `cellview_path`, `library`, `libraries`
   (add `cell_views` only if you want the Library Manager tree too).
5. A `library.defs` + OA library tree, and the runtime config that selects it
   (e.g. `XSCHEM_LIBRARY_DEFS`, `library_registry_defs_only`,
   `library_default_layout` — see `src/cadence_style_rc` on a registry branch).

Identify the introducing commits with:

```sh
git log --oneline slick-property-forms..library-manager -- src/library_defs.tcl
git log --oneline slick-property-forms..library-manager -- src/scheduler.c | grep -i 'cellview\|librar'
git log -L ':abs_sym_path:src/xschem.tcl' slick-property-forms..library-manager
```

then `git cherry-pick -x <sha>...` them in order.

- **Pro:** keeps the branch lean; only the registry, no Library Manager GUI.
- **Con:** you must isolate the resolver changes correctly; cherry-picks across
  137/57 commits of divergence may conflict and need manual reconciliation.

### Intermediate — Tier 1 only (display, no C, no build)

If you only want the rows to **show** (read-only) without re-pointing masters:
do steps B.1–B.3 and B.5 (skip the `scheduler.c` shims). No recompile needed —
it is pure Tcl. The rows display and track Next/Prev; editing them just warns
"no … view" because `xschem cellview_path` is absent. A cheap way to demo the
feature before committing to the full port.

---

## 6. How to verify once ported

1. Launch against an OA registry (a `library.defs` with at least one library):
   `cd src && ./xschem --script cadence_style_rc` (or your registry rc).
2. Place / open a schematic containing an instance of a registered library cell.
3. Select that instance, press `q` (or Edit ▸ Properties). **Expect:** the three
   `Library / Cell / View` rows appear under the "Apply to" selector, populated.
4. With several instances selected, use **Next/Prev** — the rows must update to
   the displayed instance. Edit a row then hit Next → the Apply/Discard prompt
   must fire (`lcv_dirty` is wired into `is_dirty`).
5. Change **Cell** to another registered cell → **Apply** → the instance must
   adopt the new master (`lcv_compose_symbol` → `xschem cellview_path` →
   resolved `.sym` → existing re-reference path). *(Tier 2 only.)*
6. Select a **pin or wire** → no L/C/V rows (the registry returns `{}` for
   non-library symbols).

---

## 7. One-paragraph summary

The L/C/V rows depend on the OA **library registry**, which is missing on
`slick-property-forms`. The registry is mostly Tcl (`src/library_defs.tcl` + the
OA-aware `abs_sym_path`/`rel_sym_path` resolvers in `src/xschem.tcl` + a
`library.defs`/library tree) with a few thin `scheduler.c` shims
(`cellview_path`, `library`, `libraries`). **Displaying** the rows needs only the
Tcl tier (no C); **editing** them needs the shims. Because the OA-awareness is
baked into the core resolvers, port the registry as a coherent unit — either
**merge `library-manager`** (cleanest) or **cherry-pick the registry commits**
(leaner, more care). Coordinate on `library-manager` and work in a separate
worktree.
