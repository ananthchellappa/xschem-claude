# XSCHEM Object Model — Agent Reference

*Machine-oriented reference for the object storage, identity, selection, property, and
action-log subsystems. The customer for this document is a coding agent (or a developer
moving at that pace) about to extend one of these subsystems. It is deliberately
table-dense and anchored to `file:line` on branch `fluid-editing`. The companion prose
document is `object_model_architecture_primer.md`.*

Line numbers are as of this analysis; treat them as strong hints and re-grep the named
symbol if a line looks off. Every fact here was verified against source.

---

## 1. Object taxonomy

| API type name | Const | Struct | Array | Count | Addressing | id counter | Has name? |
|---|---|---|---|---|---|---|---|
| `wire` | `WIRE` | `xWire` | `xctx->wire` | `xctx->wires` | `wire[n]` | `wire_id_counter` | no (has `.node` net cache) |
| `instance` | `ELEMENT` (8) | `xInstance` | `xctx->inst` | `xctx->instances` | `inst[n]` | `inst_id_counter` | **yes** `.instname` |
| `text` | `xTEXT` | `xText` | `xctx->text` | `xctx->texts` | `text[n]` | `text_id_counter` | no |
| `rect` | `xRECT` | `xRect` | `xctx->rect[c]` | `xctx->rects[c]` | `rect[c][n]` | `gfx_id_counter` (shared) | no |
| `line` | `LINE` | `xLine` | `xctx->line[c]` | `xctx->lines[c]` | `line[c][n]` | `gfx_id_counter` (shared) | no |
| `poly` | `POLYGON` | `xPoly` | `xctx->poly[c]` | `xctx->polygons[c]` | `poly[c][n]` | `gfx_id_counter` (shared) | no |
| `arc` | `ARC` | `xArc` | `xctx->arc[c]` | `xctx->arcs[c]` | `arc[c][n]` | `gfx_id_counter` (shared) | no |
| *(symbol def)* | — | `xSymbol` | `xctx->sym` | `xctx->symbols` | `sym[n]` | **none** | `.name` (def name) |

- Struct defs: `xschem.h:479` (xWire), `497` (xLine), `527` (xRect), `549` (xPoly),
  `567` (xArc), `584` (xText), `616` (xSymbol), `656` (xInstance).
- `id` fields: `xschem.h:492/507/544/562/579/604/709`. **`xSymbol` has no id.**
- Counters: `xschem.h:1057` (wire), `1060` (inst), `1063` (gfx, "ONE shared counter"),
  `1067` (text). Init to 0 at `xinit.c:642-645`; **never** reset by `clear_drawing`.
- `object_type_from_name` maps API name → const: `scheduler.c:5425`.
- Instance→symbol link: `xInstance.ptr` = **integer index** into `sym[]` (`xschem.h:659`);
  `-1` = unresolved. Access idiom `xctx->sym[inst[i].ptr]`. **No symbol→instance
  back-pointer** (`xSymbol` struct `xschem.h:616-654` has no instance field).
- `WIRELAYER` (=1) is the reported "layer" for wire & instance descriptors (a fixed
  display layer, not a real layer): `xschem.h:162`.

### Storage growth (NOTE: linear, not geometric)
`check_*_storage()` grows capacity by a **fixed additive increment**:
`max = (1 + count/CHUNK) * CHUNK` → O(n²) total copy cost on large fills. `store.c:26-130`.
Chunks: `CADMAXWIRES=200`, `CADMAXTEXT=100`, `ELEMINST=100`, `ELEMDEF=50` (symbols),
`CADMAXOBJECTS=100` (each graphical layer), `MAXGROUP=100` (sel_array). `xschem.h:186-191`.
(`CADCHUNKALLOC=512` is a *string*-buffer chunk, unrelated — `xschem.h:213`.)

### Spatial hashes (derived state, keyed on RAW indices)
`instpin_spatial_table`, `wire_spatial_table`, `inst_spatial_table`,
`object_spatial_table` — `[NBOXES=50][NBOXES]` grid, `BOXSIZE=400`. `xschem.h:1144-1147`.
Store raw `(type,n,c)` indices, so they go stale on any index move; rebuild gated by
`prep_hash_inst`/`prep_hash_wires`/`prep_hash_object` flags (`xschem.h:1130-1132`) that
mutators must zero (`select.c:604`, `actions.c:2456`, `editprop.c:1204`).

---

## 2. Three ways to reference an object

| Reference | Form | Stable across edits? | Cross-session? | Resolver |
|---|---|---|---|---|
| **Array index** | `#n` / `#c,n` | **No** — moves on delete/reorder/insert/undo | No | direct subscript |
| **Stable id** | `@id` | **Yes** (within a context; both undo backends) | **No** (not persisted) | `*_index_from_id` |
| **Name** | bareword | reusable/renamable (weak) | **Yes** (in the file) | `get_instance` (instances only) |

### Index invalidation matrix
| Mutation | Effect | Site |
|---|---|---|
| delete-compact | order-preserving down-shift; every higher index −1 | `store.c:416` (wire), `485` (inst), `select.c:591` (text), `select.c:393` (rect/line/arc/poly) |
| `change_elem_order` | swaps two slots | `editprop.c:1227/1236/1248/1256` |
| insert at `pos>=0` | up-shift of all indices ≥ pos | `store.c:141/183/239/272/347`, `actions.c:2457` |
| `remove_symbol(j)` | compacts `sym[]`; every `inst.ptr>=j` stale (not fixed up) | `actions.c:830`; `remove_symbols` sets ptr=-1 `actions.c:842` |
| array realloc growth | may move base pointer → dangles saved `T*` (indices survive) | `store.c:31/49/60/74/89/101/113/125` |
| undo/reset | wholesale rebuild | `in_memory_undo.c`, `store.c:*_storage_reset` |

### id→index resolvers (linear scan, by design)
`wire_index_from_id` `store.c:445` · `inst_index_from_id` `store.c:559` ·
`text_index_from_id` `store.c:627` · `gfx_index_from_id` `store.c:638` (scans **all
layers** of the type, sets `*layer_out`). Return `-1` on id==0 / deleted / disk-undo-lost.
Rationale comment (why no maintained map): `store.c:435-444`. Declarations `xschem.h:1799`.

---

## 3. Lifecycle chokepoints (where identity is minted / destroyed)

| Family | Birth (stamps id) | Death | Bulk reset |
|---|---|---|---|
| wire | `wire_store` `store.c:339` (id at `:369`); split birth `:403` | `wire_delete_compact` `store.c:416` | `wire_storage_reset` `store.c:459` |
| instance | `inst_register` `store.c:538` (id at `:540`) | `inst_delete_compact` `store.c:485` | `inst_storage_reset` `store.c:512` |
| rect/line/poly/arc | `gfx_register(type,c,n)` `store.c:586` (id `:589-592`) | `del_rect_line_arc_poly` `select.c:393` | per-type in reset paths |
| text | `text_register` `store.c:616` (id `:618`) | text loop `select.c:591` | — |

- **Birth is funneled but not a single factory** (except wires): each call site fills the
  struct then calls `*_register` to bump the count and stamp the id. Load path re-mints via
  the same funnels: `save.c:2837` (text), `2853` (wire), `2904` (inst),
  `2965/3009/3071/3107` (gfx).
- Heap fields freed by hand at *both* the delete door and the reset door (duplicated) —
  e.g. instance frees `prop_ptr,node,pin_sel,name,instname,lab` at `store.c:492` **and**
  `store.c:517`. **Adding a heap field to a struct means editing both.**

---

## 4. Stable-id semantics (operation → id preserved?)

| Operation | id preserved? | Mechanism / caveat |
|---|---|---|
| delete others, reorder, insert, plain move | **yes** | id rides in struct |
| in-memory undo/redo | **yes** | undo slot struct-copies `.id` (`in_memory_undo.c:344` etc.) |
| disk undo/redo | **yes** | `Undo_ids` side-channel: `capture_undo_ids` `save.c:3970` at push, `restore_undo_ids` `save.c:3996` at pop; **positional**, bails to fresh ids on shape mismatch (`save.c:3999`). Struct `xschem.h:771-787`. (issue 0043) |
| copy/paste (the copy) | **no** | new birth: `paste.c:53/132/315`, `move.c:972/1031` |
| layer change (gfx) | **no** | `change_layer` = delete + recreate on new layer, new id: `actions.c:4269` |
| save → reload (new session) | **coincidentally** | re-mint is positional/file-order; pristine reload → same numbers, but diverges after edits reorder the array. Not persisted: `XSCHEM_FILE_VERSION "1.3"` `xschem.h:27`; no save record writes `.id` |

Special: `xText.owner_pin_id` (`xschem.h:608`) ≠ 0 marks a **synthesized transient
"pin-name view"**; its value is the owning pin's `xRect.id`. Not persisted; regenerated by
`synth_pin_views` (`actions.c:1467`).

---

## 5. Property model

- Storage: one freeform `char *prop_ptr` per object, `key=value key2=value2 …`. **No
  schema, no types.** Written verbatim (brace-wrapped, escaped) to file: `save.c:2639`,
  `save_ascii_string` `save.c:2508`.
- Parser: `token.c`. State machine `get_tok_value(s, tok, flags)` `token.c:438`.
- Symbol-template defaults: `xSymbol.templ` (`xschem.h:637`) = value of `template=` in the
  symbol prop; instance lookups fall back symbol→template when not found on the instance
  (`token.c:1011-1014`).
- `node[]` (`xInstance`, `xschem.h:706`): derived per-pin net-name array, built by
  `prepare_netlist_structs`/`hash_inst_pin` (`netlist.c:1578`), **not** in prop_ptr, **not**
  persisted, can be NULL.

| Need | C function | Tcl command | Notes |
|---|---|---|---|
| read one value by key | `get_tok_value(prop,key,flags)` `token.c:438` | `xschem getprop <type> <ref> <key>`; `xschem get_tok <str> <key> [wq]` `scheduler.c:2869` | returns `""` if absent, never NULL |
| test key existence | check `xctx->tok_size` (0=absent) `token.c:451/505` | `xschem get_tok_size` `scheduler.c:2885` | **global** side-channel — read immediately, next call clobbers |
| **enumerate keys** | `list_tokens(prop,flags)` `token.c:308` | **`xschem list_tokens <str> <wq>`** `scheduler.c:4099` | returns space-separated **key names**; Tcl wrapper proc `xschem.tcl:2741` |
| read whole prop string | `obj.prop_ptr` | `xschem getprop instance <name>` / `getprop symbol <sym>` **only** `scheduler.c:2698/2767` | **GAP: no whole-string read for wire/text/rect/line/poly/arc** |
| write/change/delete key | `subst_token(s,tok,val)` `token.c:1234` (NULL/empty val deletes) | `xschem setprop <type> <ref> <tok> [val]`; `xschem subst_tok <str> <tok> <val>` `scheduler.c:8615` | sole mutation primitive |
| enforce unique instance name | `new_prop_string` `token.c:760` | (interactive; `xschem check_unique_names` `scheduler.c:917`) | not run on load |

**Footguns:** (1) `get_tok_value`/`list_tokens` return a pointer into a **shared static
buffer** (`static char *result`/`*token`) — copy with `my_strdup` before the next call.
(2) existence via global `tok_size` — clobbered by any intervening lookup.

---

## 6. Selection model

- Authoritative truth = `.sel` flag on each object struct (`SELECTED` = nonzero mode).
- Derived cache = `sel_array` of `Selected{unsigned short type; int n; unsigned int col}`
  (`xschem.h:472`). **`.n` is the ARRAY INDEX, not the id** — snapshot only.
  `.col` = layer for graphical types / pin index for `INST_PIN`.
- Rebuilt by `rebuild_selected_array()` `move.c:52` **only if** `need_reb_sel_arr` set;
  header warns it is only shrink-safe. Grown via `check_selected_storage` `store.c:35`.
- `first_sel` (`xschem.h:1127`) = multi-edit master; `set_first_sel(…,-2,…)` retrieves it
  (`select.c:753`), consumed at `editprop.c:1462`.
- `INST_PIN` (=128, `xschem.h:287`): transient, **inert** pin pseudo-selection backed by
  per-instance `pin_sel[]`/`pin_sel_size` (`xschem.h:673`); never in `.sel`, never edited,
  never saved; wiped by `unselect_all` (`select.c:802`). Gated by `en_pin_select`.

| Select by | Command | Resolver | Note |
|---|---|---|---|
| name | `xschem select instance <name>` | `get_instance` `scheduler.c:86` | **instances only** |
| index | `xschem select wire\|text <n>` / `line\|rect\|arc\|poly <c> <n>` | atoi | `scheduler.c:7532-7582` |
| coordinate | `xschem select_at <x> <y> [add] [nodraw]` | `select_object`→`find_closest_obj` | replayable click; `scheduler.c:7603` |
| pin | `xschem select pin <inst> <pinidx> [clear\|nodraw]` | — | transient/inert |
| **id** | — **(none)** | — | **GAP: `@id` works only on read-only `xschem object` query, not `select`** |

Enumerate selection two ways (can diverge):
- `xschem objects -selected` `scheduler.c:5536` — reads live `.sel` across **all 7 types**,
  no rebuild. **Preferred.** Row = `{type index layer id name}`.
- `xschem selection` `scheduler.c:7781` — reads `sel_array` (rebuilds first). Row =
  positional `{type index col id}` (no name; `INST_PIN`→`"pin"`). **Different format.**

**Selection ≠ undo:** both undo backends `unselect_all()` on restore; `pop_undo_keep_
selection` (`xschem.h:1915`, issue 0007) works around it.

---

## 7. Query API + command reference

`xschem object <type> <selector>` → one descriptor or `""`. `scheduler.c:5477`.
- `@<id>` stable handle · `#<index>` flat · `#<layer>,<index>` graphical · bareword name
  (**ELEMENT only**, via `get_instance`).
- Descriptor = `{type <s> index <d> layer <d> id <d> name {<s>}}` — `object_descriptor`
  `scheduler.c:5447`. **Address-only: no prop_ptr, no keys.** `name` empty for non-instances.

`xschem objects [-type T] [-selected] [-layer L]` → braced list of descriptors.
`scheduler.c:5536`.

`xschem hover` → same descriptor dict for hovered object. `scheduler.c:3127`.

Row-format inconsistency to handle in scripts:
- named dict `{type index layer id name}` — `object`/`objects`/`hover`
- positional `{type index col id}` — `selection`/`select_at`

Identity handles surfaced to Tcl: `instance_id`/`instance_index` `scheduler.c:3548/3567`;
`wire_id`/`wire_index` `9407/9425`; `text_id`/`text_index` `8916/8934`.

Net API (already identity-anchored — the model to emulate):
`xschem net @wire <id>` / `@inst <id> <pin>` / `<token>`; `nets`; `net_members` —
`scheduler.c:4950/5144/5181`. `hilight_netname <net>` `3325`; `instances_to_net <net>` `3842`.

---

## 8. Action logging & replay

- Funnel: `log_action(fmt,…)` `util.c:394` → writes `actionlog_fp` + mirrors to CIW via
  `ciw_echo`. No-op if off or `actionlog_suppress`. `log_action_argv` (Tcl_Merge quoting)
  `callback.c:1537`. Output/results logged as `#=`/`#!` comment lines `util.c:438`.
- File: `Xschem.log[.1..9]`, `ACTIONLOG_KEEP=10`, dir = `--logdir` else `$TMPDIR` else
  `/tmp`; opened for interactive session or when `--logdir`; `--nolog` disables.
  `util.c:277-376`.
- Dedup across 3 logging paths via `actionlog_cmd_logged`: (i) binding-table dispatch
  `dispatch_input_action` + `d->log_cmd`/`d->nolog` over `actions.csv`/`keybindings.csv`/
  `mousebindings.csv` (`callback.c:3454`); (ii) context-menu table `ctxmenu_log_cmd[]`
  (`callback.c:2538`); (iii) self-log-at-core `log_action()` in scheduler branches.
- Replay = `source Xschem.log` (Tcl); comments skipped; runs against **current** `xctx`.
  Suppress guard `actionlog_suppress` keeps replayed commands from re-logging.

| Gesture | Logged? | Referent | Replay robustness |
|---|---|---|---|
| pan / zoom_box / scroll | yes | delta / box | exact (no identity) |
| draw wire/line/rect/arc/text | yes | coordinates | geometry-based |
| place instance | yes | **symbol name** + coords | good |
| move/copy objects | yes | delta on current selection | selection-dependent |
| click-select | yes `xschem select_at x y [add]` `select.c:1421` | **coordinate** | **re-runs hit-test — drifts if geometry changed** |
| setprop instance `<name>` | yes | **name** | identity-stable |
| setprop wire/text/rect `<n>` | yes | **array index** | **wrong object after edits** |
| descend / go_back / descend_symbol (key) | partly/no | selected instance | legacy key path bypasses logging (Reason A) + no stable referent (Reason B, issue 0005) |
| dialog edits, control-point drag | `#` marker only | — | not replayable |

**The replay identity gap** (issue 0005 / `select_at.md`): gestures log *coordinates*, and
ids are *not persisted*, so nothing is identity-anchored across geometry change or reload.

---

## 9. Verified defects & gaps (as of this analysis)

| # | Severity | Defect | Site |
|---|---|---|---|
| D1 | **bug** | `getprop wire` / `getprop rect` index with **unchecked** `atoi` → OOB read on bad index (setprop/select DO bounds-check) | `scheduler.c:2810`, `2780` |
| D2 | gap | No whole-prop read for wire/text/rect/line/poly/arc → can't enumerate their keys from Tcl | `scheduler.c:2685-2813` |
| D3 | gap | `getprop` has **no line/poly/arc branch** at all — their attrs opaque to Tcl | `scheduler.c:2685-2813` |
| D4 | gap | No `select … @id` (id-based selection); `@id` only on read-only query | `scheduler.c:7480-7592` |
| D5 | trap | `selected_set` omits WIRE/LINE/POLYGON/ARC (side-stepped by `objects -selected`) | `scheduler.c:7711` |
| D6 | trap | Numeric instance name unreachable by name (`get_instance` routes digits→index) | `scheduler.c:91` |
| D7 | trap | `resolved_net` rebuilds connectivity but not selection → may read stale `sel_array[0]` | `scheduler.c:7196` |
| D8 | inconsistency | Two row formats: `{type index layer id name}` vs `{type index col id}` | `scheduler.c:5447` vs `7807` |
| D9 | fragility | Disk-undo id restore is positional; bails to fresh ids on count mismatch | `save.c:3999` |
| D10 | fragility | instance-name uniqueness not enforced on load | `save.c:2898`, `actions.c:976` |

---

## 10. Recipes

**Select the first selected object's property names (works today for instances/symbols):**
```tcl
set first [lindex [xschem objects -selected] 0]         ;# {type index layer id name}
if {[dict get $first type] eq "instance"} {
  set keys [xschem list_tokens [xschem getprop instance [dict get $first name]] 0]
}
# For wire/text/rect/line/poly/arc: no whole-prop read exists (D2/D3) → not closable from Tcl yet.
```

**Hold a durable in-session handle and resolve it later:**
```tcl
set h [dict get [xschem object instance M1] id]   ;# @id survives edits within the session
# …arbitrary edits…
set desc [xschem object instance @$h]             ;# "" if it was deleted (loud dangle, never aliases)
```

**Address a net by a durable anchor instead of its (renamable) name:**
```tcl
xschem net @wire [dict get [xschem object wire #3] id]
```

---

## 11. Extension points (how to add the missing pieces)

### Add `select … @id` (D4 — small, high value)
In the `xschem select` dispatcher (`scheduler.c:7480-7592`), for each type branch accept a
`@`-prefixed arg and route through the existing `*_index_from_id` resolver before calling
the per-type `select_*` funnel. Mirrors the resolve logic already in `xschem object`
(`scheduler.c:5491-5500`). Makes "select the object I hold a handle to" work for **all**
types.

### Expose whole-prop read / property dict for all types (D2/D3)
Two options: (a) add whole-string `getprop` branches for wire/text/rect/line/poly/arc
(each just `Tcl_SetResult(interp, obj.prop_ptr, …)`); or (b) add a `-props` flag to
`xschem object`/`objects` that appends `props {k v k v …}` by pairing `list_tokens` with
`get_tok_value` over `prop_ptr`. Option (b) also closes the pseudocode gap uniformly.

### Fix D1 (OOB) — add bounds checks
`getprop wire`/`rect`: validate `n`/`c` against `xctx->wires`/`cadlayers`/`rects[c]` before
subscripting, same as the `object #index` path (`scheduler.c:5507-5514`).

### Identity-based replay within a session (Goal B, layer 1)
Change interactive gestures to log the stable id: add `xschem select @<type> <id>` (see
above) and have `select_object` optionally emit the id-form (the hit `Selected` already
yields the index → read `.id`). Convert index-based `setprop` self-logging to id-form.
Infrastructure is entirely present; this is grammar + plumbing.

### Persist a stable id (Goal B, layer 2 — file-format change)
Add an id token to the `C{…}`/`T{…}`/wire/gfx records in `save.c` writers and parse it in
the `save.c:2813-3110` load funnels; bump `XSCHEM_FILE_VERSION` (`xschem.h:27`); handle
absent-token (old files) by falling back to a fresh stamp; re-save the library. This is the
**only** change here that touches the on-disk format. Alternative with no format change: a
deterministic content+position hash resolved at replay (fragile on duplicates).

### Add a new object heap field
Edit **both** the delete door and the reset door free-lists for that family (§3), plus the
in-memory undo capture/restore (`in_memory_undo.c`) and, if it must survive disk undo, the
`Undo_ids` walk (`save.c:3934`). Missing one leaks or corrupts.

### Add a new object type
Touch: struct + id field + counter (`xschem.h`); array + count in `Xschem_ctx`; init
(`xinit.c`); `check_*_storage` + birth/death/reset funnels (`store.c`); `object_type_from_
name` + `object`/`objects`/`getprop`/`select` branches (`scheduler.c`); save/load
(`save.c`); spatial hash if hit-tested; undo capture/restore. There is **no** single
type registry — every traversal is hand-written per type.

---

## 12. Invariant / footgun checklist

- [ ] Never cache a raw index across an edit — resolve `@id` each time, or hold the id.
- [ ] `get_tok_value`/`list_tokens` return a **shared static buffer** — `my_strdup` it
      before the next call.
- [ ] Check `xctx->tok_size` **immediately** after a lookup (global, clobbered next call).
- [ ] `sel_array.n` is an **index**, not an id; treat `sel_array` as a rebuilt snapshot.
- [ ] `objects -selected` (live `.sel`) is more robust than `selection` (`sel_array`).
- [ ] After any index-moving mutation, zero the relevant `prep_hash_*` flag.
- [ ] When adding a struct heap field, edit **both** free doors (delete + reset).
- [ ] `xSymbol` has **no** id and no `@id` path — reference symbols by name / `inst.ptr`.
- [ ] Ids are **per-context**; the same number exists in every window. Not global.
- [ ] Ids are **not persisted**; do not use them as cross-reload references.
- [ ] `setprop`/replay by index is geometry-fragile; prefer name (instances) or add id-form.

---

*Companion prose: `object_model_architecture_primer.md`. Related design docs:
`instance_identity_decision.md`, `net_identity_decision.md`,
`doc/claude/specs/select_at.md`, `doc/claude/issues/0005-*.md` (replay referent),
issue 0043 (disk-undo id side-channel), `doc/claude/FAQ.md` Q24 (why some gestures aren't
logged).*
