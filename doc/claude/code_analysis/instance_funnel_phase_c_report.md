# Instance lifecycle funnel — Phase C report

Stable-object-handles **step 2 (instances)**, Phase C. This is the close-out
report for the funnel refactor: what was done, why instances were handled
differently from wires, what was deliberately *not* funneled, and how zero
behavior change was demonstrated rather than asserted.

- **Scope:** route every instance birth / death / bulk-reset through a single
  function family in `src/store.c`, a pure refactor that prepares the one
  chokepoint where Phase D will stamp a stable identity.
- **Commits:** `6771e985` (IC1 death), `3ed836f1` (IC2 bulk), `618737f0`
  (IC3 birth), `fa8be52e` (census status). Preceded by `c181b325` (Phase A
  characterization suite) and `0bcdae7a` (Phase B census).
- **Outcome:** instances 33/33, wires 57/57, file_open 33/33 — green at every
  commit. No functional change.

Companion docs: `instance_lifecycle_census.md` (the authoritative site list),
`wire_lifecycle_census.md` + the wire funnel (the proven precedent),
`green_but_hollow_tests.md` (the verification discipline), `FAQ.md` Q7
(why the funnel comes before the handle).

---

## 1. Why a funnel at all

The keystone finding of this whole effort (FAQ Q7) is that XSCHEM's object
store has **no single owner**: a wire — and an instance — is born, dies and
moves in memory at many scattered sites. You cannot stamp a session-stable id
at "creation" if creation happens in six places. So before identity can be
added, every lifecycle event must pass through one chokepoint. Phase C builds
those chokepoints for instances; Phase D adds the id at the birth one.

This is the same move that paid off three times already in this repo: the
`scheduler()` command funnel (made action-logging nearly free), the
input-binding table (made key remapping free), and the wire lifecycle funnel
(step 1). Phase C is that move applied to instances.

---

## 2. The census, recapped

Phase B (`instance_lifecycle_census.md`) enumerated every mutation of
`xctx->inst[]` / `xctx->instances`, grep-complete. The shape that mattered for
Phase C:

| class | sites | funnel target |
| --- | --- | --- |
| BIRTH | `place_symbol` (actions.c:1654), `load_inst` (save.c:2899), `merge_inst` (paste.c:312), move-copy (move.c:972) | `inst_register()` |
| DEATH | `delete()` instance loop (select.c) | `inst_delete_compact()` |
| BULK RESET | `clear_drawing()` instance loop (actions.c) | `inst_storage_reset()` |
| REORDER | `place_symbol` pos≥0 shift (IR1), `change_elem_order` swap (IR2) | **none — see §4** |
| GROWTH / UNDO | `check_inst_storage` (IG1), `pop_undo` bulk replace (IB7) | **none — see §4** |

**The headline difference from wires:** instances have **no `check.c`
births**. The connectivity checker splits and creates *wires* directly (four
extra birth sites that made the wire funnel delicate); it never creates
instances. So instance births are fewer — but, as it turned out, individually
more divergent.

---

## 3. The design decision: no unifying birth factory

For wires, `wire_store()` is a real factory — every wire birth became a thin
caller that hands over coordinates and lets the factory do the field init,
because wire births were structurally similar. The instinct was to repeat that
for instances with an `inst_store()`.

**Reading the four birth sites in full disproved that instinct** — the
"a call that looks like this helper is a hypothesis; read the branch" rule in
force. The four births are irreducibly heterogeneous:

- `place_symbol` looks up and links a symbol (`ptr`), resolves `@params` via
  `translate()`, may reload the symbol, computes `symbol_bbox`, uniquifies the
  name, selects the result, and can embed a scope floater.
- `load_inst` parses fields from the `.sch` file; the name comes *from the
  file* (no uniquify); symbol linking is deferred to
  `link_symbols_to_instances()`.
- `merge_inst` reads from the clipboard file and *does* uniquify the name.
- move-copy clones an existing struct, deep-copying `name`/`prop_ptr`/`lab`/
  `instname`, then uniquifies.

Worse for a factory: **two of the four increment the count mid-flow**.
`place_symbol` (actions.c:1654) and move-copy (move.c:972) bump
`xctx->instances` *before* calling `translate()` / `symbol_bbox()`, because
those functions need the updated count — the comments at both sites say so
explicitly. `load_inst` and `merge_inst` increment at the end. An `inst_store`
that "owns" the increment would have to move it relative to those calls, a
behavior change waiting to happen.

**Conclusion:** instances do not have a unifiable field-init, so the funnel
must not pretend they do. The birth chokepoint is therefore *thin* — it owns
**only the count increment**, left at each site's exact existing point:

```c
/* Birth chokepoint of the instance lifecycle funnel ... the single place
 * instance identity will be stamped (step-2 Phase D). ... this owns only the
 * increment, kept at each site's existing point. */
void inst_register(int n)
{
 (void)n; /* used in Phase D to stamp xctx->inst[n].id */
 xctx->instances++;
}
```

Each birth site swapped `xctx->instances++;` for `inst_register(<slot>);`:

| site | call |
| --- | --- |
| place_symbol (actions.c:1654) | `inst_register(n)` |
| load_inst (save.c:2899) | `inst_register(i)` |
| merge_inst (paste.c:312) | `inst_register(i)` |
| move-copy (move.c:972) | `inst_register(xctx->instances)` |

The slot `n` is the just-filled slot — `xctx->instances` at every append site.
`place_symbol`'s `pos≥0` insert (which would make `n != xctx->instances`) is
unreachable: **every `place_symbol` caller passes `pos = -1`** (15 call sites,
verified). After IC3 the only `xctx->instances++` left in the entire tree is
the one inside `inst_register`.

The death and bulk idioms, by contrast, *are* uniform, so they became real
functions mirroring the wire pair:

```c
int  inst_delete_compact(int (*doomed)(int n, void *arg), void *arg); /* ID1 */
void inst_storage_reset(void);                                        /* IZ1 */
```

`delete()` now calls `inst_delete_compact(inst_doomed_selected, NULL)` (the
predicate dooms `sel == SELECTED`) and keeps owning its derived-state
invalidation (`prep_hash_inst` / `prep_net_structs` / `prep_hi_structs`).
`clear_drawing()` calls `inst_storage_reset()` right after `wire_storage_reset()`.

---

## 4. What was deliberately *not* funneled, and why

A funnel can over-reach. Four site classes were left exactly where they are,
on purpose:

- **REORDER — `place_symbol` shift (IR1) and `change_elem_order` swap (IR2).**
  These move structs around the array but create/destroy nothing. With the
  linear-scan id→index resolver planned for Phase D (the same one wires use),
  *the id travels inside the struct*, so the array is the authoritative
  id→index relation after any shift or swap — zero map maintenance, nothing to
  funnel.
- **GROWTH — `check_inst_storage` (IG1).** Already a single shared function
  every birth calls; it is the growth funnel already. Reallocation dangles raw
  `xInstance *` pointers but not indices, and the funnel doors call it
  internally, exactly as before.
- **BULK REPLACE — `pop_undo` (IB7).** Memory undo struct-copies instances in
  and out, so a future `id` member rides along for free (same as wires); its
  disposal of the old array routes through `clear_drawing` →
  `inst_storage_reset`. Disk undo reloads via `load_inst` → `inst_register`,
  which will mint fresh ids — the known, accepted invalidate-on-restore
  behavior (the Phase D "D3" decision, already settled for wires).
- **The `place_symbol` error-path `instances--` rollback (actions.c:1702).**
  Left as a raw decrement. It undoes an `inst_register` increment on a failed
  scope-floater insert; in Phase D the abandoned id is harmless because the
  counter is monotonic and never reused.

This is the same conclusion the wire funnel reached: the funnel's job for
identity is **stamp at birth**; the reorder/growth/undo machinery needs no
participation because identity lives in the struct, not in a side table.

---

## 5. Verification — shown, not asserted

Phase A (`c181b325`) committed a 33-check instance characterization suite
*first*, and — critically — proved it was both **reachable** (the commands
provably execute) and **sensitive** (wrong invariants FAIL) via a sabotage
probe, *before* any refactor relied on it. That is what makes the green in
Phase C meaningful.

Each Phase C commit was then verified the same way:

- **IC1 / IC2** — both suites green; the death door is exercised by CHI2
  (delete) and CHI3 (undo round-trips), the bulk reset by CHI10 (explicit
  clear) and every `reload` (clear_drawing runs before each load — the
  117-instance fixture loads and frees repeatedly with no leak or crash).
- **IC3 — the closing move.** Because the birth chokepoint is the highest-risk
  change (it touches all four birth paths), its sensitivity was proven
  directly: temporarily making `inst_register` increment by 2 **collapsed the
  suite from 33 PASS to 0**. That is the green-but-hollow discipline's payoff —
  the births (CHI1 place_symbol, `reload` load_inst, CHI4 move-copy, CHI5
  merge_inst) demonstrably flow through the single chokepoint, and the suite
  would catch a regression in any of them. The sabotage was then reverted and
  green restored.

Cross-checks: the wire suite (57/57) and the file-open suite (33/33) stayed
green throughout, confirming the shared `delete()` / `clear_drawing()` paths
were not disturbed.

Two real, pre-existing behaviors the suite surfaced while being written (worth
recording): `instance_coord` appends a trailing newline (hence `string trim`
in the relevant checks), and the instance C-record snapshot regexp needs
`[^\}]` because an unescaped `}` closes a Tcl braced string early.

---

## 6. Lessons reaffirmed

1. **Read every branch before extracting a helper.** The `inst_store` factory
   that "obviously" mirrored `wire_store` would have forced a behavior change
   (moving the mid-flow increment). The births only *looked* uniform from the
   census summary; the source said otherwise.
2. **A thin funnel is still a funnel.** `inst_register` does almost nothing
   today, but it converts four scattered increments into one identity
   chokepoint — which is the entire point. Don't conflate "small function"
   with "pointless function."
3. **Let the resolver decide what needs funneling.** Choosing a linear-scan
   id→index resolver (no side-table map) means reorder/swap/realloc/undo need
   no funnel participation. The data-structure choice shrinks the refactor.
4. **Sabotage the chokepoint, not just the suite.** Proving the suite *can* go
   red in general (Phase A) and proving *this specific change* is on the live
   path (IC3 sabotage) are different obligations; both were met.

---

## 7. What Phase C sets up — and the open decision

The birth chokepoint exists; Phase D's diff is now small: add an
`unsigned int id` to `xInstance`, a monotonic per-context counter, and the
single stamp line inside `inst_register`, plus the query commands.

But Phase D carries a decision wires did **not** have, surfaced by Phase A's
CHI7: an instance already owns a stable handle — its **name** (`instname`),
which survives the array compaction that dangles its index. So "stamp a numeric
id" is no longer the obvious move; it is **id vs. name vs. both**. A numeric id
still adds value (rename-stable, present even for unnamed objects, uniform with
the wire mechanism and the `selection` enumerator), but the name covers much of
the need already. If an id is added, the conversion-utility and
reference-convention design (two polymorphic commands mirroring wires vs. a
sigil'd uniform resolver) is the follow-on question.

That decision is for the user to make at the start of Phase D; this report
ends Phase C with the funnel in place and the safety net green.
