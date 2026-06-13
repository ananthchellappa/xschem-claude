# Instance identity — Phase D decision record (id vs. name vs. both)

Stable-object-handles **step 2 (instances)**, the Phase D design decision.
Phase C (the lifecycle funnel) is done; the birth chokepoint `inst_register(n)`
is the one place an identity would be stamped. Before stamping anything, this
records the choice of *what* identity instances should carry.

- **Status:** **IMPLEMENTED** (Phase D done, 2026-06-13). User ratified
  **both**; shipped RED→GREEN: ids stamped at `inst_register`, queryable via
  `xschem instance_id <name|index>` / `xschem instance_index <id>`, surfaced in
  the `selection` instance row, sabotage-verified on the live path. Suite:
  `tests/stable_handles/inst_*.tcl` 48 PASS. End-to-end demo:
  `code_analysis/introspection_probes/probe4.tcl`. (Recommendation originally
  stamped at `eb1e73b2`.)
- **Recommendation:** **both** — a numeric `id` as the canonical durable
  identity, with the existing `name` kept as the human / cross-session
  addressing form, under an explicit role contract (§4).
- **Context docs:** `instance_lifecycle_census.md` (the funnel + "banked for
  Phase D"), `instance_funnel_phase_c_report.md` (Phase C close-out),
  `tcl_introspection_wire.md` §2e (the identity hazard), the wire Phase D
  (`plan_stable_handles_step1.md`) as the precedent.

---

## 1. The question

Wires had no handle at all, so step 1's answer was obvious: stamp a numeric id.
Instances are different — they already own a name (`instname`, e.g. `R25`),
auto-assigned at birth and unique within the schematic, which CHI7 proved
survives the array compaction that dangles an index. So the Phase D choice is
genuinely open:

- **(a) name-only** — treat `instname` as the handle; stamp no numeric id.
- **(b) id-only** — stamp an `unsigned int id` like wires; ignore names for
  identity.
- **(c) both** — stamp a numeric id *and* keep the name, each with a defined
  role.

## 2. What the name actually is (verified, not assumed)

Two probes against `mos_power_ampli.sch` settled the load-bearing facts:

- **Names are reused.** Placed three resistors → auto-named `R25 R37 R38`;
  deleted `R37`; placed another resistor → it was auto-named **`R37` again**.
  So a script holding `R37` across a delete-then-create now references a
  *different* instance, silently — the exact §2e hazard the whole effort
  exists to eliminate (wire test H4 locks "no reuse" precisely because of
  this).
- **The name is editable, persisted prop data.** `instname` is the cached
  `name=` token of the instance's `prop_ptr`; it is written into the `.sch`
  `C {...}` record and can be changed by the user via attribute editing. It is
  *user data*, not a stamped invariant.
- **Corollary — the name is the only cross-session handle.** Because it is
  saved in the file, a name still refers to "the same" instance after
  save / close / reopen. A session-scoped numeric id (like the wire id) does
  **not** survive a reload.

## 3. Complementary stability — id and name are not competitors

| property | numeric `id` (proposed) | `name` (`instname`) |
| --- | --- | --- |
| unique within a context | yes | yes (`check_unique_names`) |
| **never reused** | **yes** (monotonic counter) | **no** — `R37` reused (verified) |
| survives neighbour delete (compaction) | yes | yes (CHI7) |
| **survives rename** | **yes** (independent of name) | **no** — the name *is* renamed |
| survives memory undo | yes (struct copy) | yes |
| survives disk undo | no (invalidate-on-restore) | yes (reloaded from file) |
| **persists across save / reopen** | **no** (session-only) | **yes** (in the `.sch`) |
| human-readable / user-types-it | no (opaque int) | **yes** |
| **uniform across all 7 object types** | **yes** | no (only inst / label / pin) |

Read by columns, each identifier covers the other's gaps: the id is reuse- and
rename-safe but vanishes on reload; the name persists and is human-friendly but
is reusable, renamable, and instance-only. Neither alone is a handle you can
rely on for every purpose.

## 4. Tradeoffs by axis

### Safety
- **Name-only is the unsafe option.** Reuse (verified) and rename reintroduce
  silent wrong-reference — the §2e bug class with a name instead of an index.
- **Id-only and both are equally safe *within* a session** (monotonic, never
  reused). **Both is strictly safer across sessions**, because the name remains
  a real cross-session handle; id-only leaves nothing stable after save/reopen.

### Consistency
- **A numeric id is non-negotiable for consistency.** It is the only scheme
  uniform across all seven object types (wires and the four graphical types
  have no names). The `selection` enumerator already reserves an `id` slot per
  row; instance rows carry `-1` today. (b)/(c) fill it; **(a) leaves instances
  the lone second-class type** in the mechanism meant to unify them.
- Exposing the name *as well* (c) costs no consistency: the id stays the
  universal mechanism, the name is an instance-specific convenience on top.

### Future ease of use
- **Both is best**, because the two identifiers do different jobs: **id = the
  durable machine handle** (held across edits, returned by `selection`, the
  referent for action-log replay / issue 0005, the basis for cross-type
  tooling); **name = the human + persistence layer** (typed and read by users,
  the only thing that survives save/reopen).
- Id-only loses ergonomics and cross-session identity (every human-facing or
  persistent reference needs a fragile round-trip, and the id is gone after
  reload). Name-only loses durability.

## 5. Recommendation — (c) both, with an explicit role contract

Add the numeric id (mirroring wires) **and** keep the name, documenting which
is which so callers hold the right one:

- **`id`** — the *canonical durable identity within a session*. Stamped at the
  `inst_register` chokepoint (one line), monotonic, never reused. What
  `selection` returns, what `instance_index <id>` resolves, what a replay log
  should reference. **Not persisted.**
- **`name`** — the *human and cross-session addressing form*. User-editable,
  saved in the file, resolved by the existing name-accepting commands plus a
  new `instance_id <name>` bridge. **Persisted; reusable; renamable — never
  hold it across edits as a machine handle.**

Safest (id removes the reuse/rename hazard; name preserves cross-session
reference), most consistent (id uniform across types, fills the selection
slot), easiest going forward (complementary tools, not a forced choice). The
cost is tiny now that Phase C is done — one `xWire`-style field, one stamp
line, two query commands; purely additive, exactly like wires.

## 6. The sub-decision to settle alongside it

Because the id and the index are **both bare integers**, and `get_instance`
already resolves "digits → index, else name" (so an instance literally named
`5` is already unreachable by name — a latent collision), choosing (c) forces a
**reference-convention** call:

- **Minimal / ship-now:** two commands mirroring wires —
  `instance_id <name|index>` (reuse `get_instance` for polymorphic input) and
  `instance_index <id>` — keeping id and index in *separate* commands (you
  cannot overload one "give me the number"). Name↔id conversion then comes free
  via the existing `instance_coord`.
- **Strategic / later:** a sigil'd uniform resolver (`@id` / `#index` /
  bareword-name) in the `xschem object` layer, which disambiguates all three
  and makes "convert" a field read off a row that carries id + name + index.

**Suggested:** ship the minimal pair in Phase D, and lock the convention
"object-reference rows/dicts carry id, name and index together" now, so the
future `xschem object` API is a clean extension rather than a reconciliation.

## 7. Phase D shape under this recommendation (for when ratified)

Mirrors the wire Phase D, RED-first, suite green throughout:

1. `unsigned int id` appended to `xInstance`; monotonic `inst_id_counter` in
   `Xschem_ctx` (per window/tab, like `wire_id_counter`); init to 0 in
   `alloc_xschem_data`.
2. Stamp inside `inst_register(n)` — `xctx->inst[n].id = ++xctx->inst_id_counter;`
   — the single line the Phase C funnel was built to enable.
3. `inst_index_from_id()` in store.c: linear scan (no side-table; the id rides
   in the struct, so the array is the authority under every shift/swap/undo).
4. Two scheduler commands: `instance_id <name|index>` (resolve via
   `get_instance`, return `.id`) and `instance_index <id>`.
5. Add the `id` (and ideally `name`) to the instance row of `xschem selection`
   (today `{instance <index> <col> -1}`).
6. RED tests in the instance suite mirroring wire H1–H7, plus instance-specific
   ones: id survives rename (name does not), id not reused after delete+create
   at the same auto-name (the `R37` scenario), name remains the cross-session
   handle. Memory undo round-trips the id for free; disk undo invalidates
   (the settled D3 behavior).

Decision owner: the user. This record exists so the choice is on the books
before any `xInstance` field is added.
