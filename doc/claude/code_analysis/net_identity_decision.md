# Net identity — direction (c) decision record (what a net's stable handle *is*)

Stable-object-handles **step-3 direction (c) "net-as-object"**, the design
decision that must be ratified *before* any C is written. This is the analog of
`instance_identity_decision.md` (Phase D for instances), but the answer is *not*
"stamp an id at the birth funnel" — because **a net has no birth funnel, no
struct, and no array to stamp.** This doc records what identity a net should
carry, lays out the three options, recommends one, and stops for the user.

- **Status:** **RATIFIED — (c2) chosen by the user 2026-06-13.** Implementation
  proceeds RED-first per §7. (Mirrors the instance Phase D flow: decision doc →
  user ratified → built.)
- **Recommendation:** **(c2) anchor net identity on a stored-object handle** — a
  net's durable handle *is* the stable id of a wire or label-instance on it; the
  net *name* (token) stays the human / cross-session form. Read-only first cut.
- **Context docs:** `tcl_introspection_wire.md` §2c/§2d (the coherence + authority
  traps), `step3_directions_guide.md` §4 (the (c) analysis),
  `instance_identity_decision.md` (the precedent flow), and the Phase A
  characterization suite `tests/stable_handles/net_*.tcl` (the baseline this
  builds on). The net-label investigation is summarized in §1 below.

---

## 1. The one fact that changes everything (verified, not assumed)

**A net is not stored.** There is no `xctx->net[]`, no slot, no struct. A net is
a *derived equivalence class* of electrically-connected wire segments and pins,
recomputed from scratch on every `prepare_netlist_structs()` rebuild. Its
identity today is a **string token** — the net name — living in `node_table[]`
(`struct node_hashentry`, `xschem.h:793`); for highlighting the key is really
`(token, sch_path)` because two different nets at different hierarchy levels can
share a token.

How a net name comes to exist (load-bearing, drives the whole design):

- A **"net label" is not a primitive** — it is an `xInstance` of a special symbol
  (`lab_pin.sym` / `lab_wire.sym` / `lab_generic.sym`, `K {type=label}`, template
  `lab=`). Its `lab` attribute *names* the net (`inst[i].node[0]`, set at
  `netlist.c:1415` under `IS_LABEL_OR_PIN`).
- That name **propagates to wires by geometry**: `name_attached_nets()`
  (`netlist.c:1064`) walks the wire spatial hash and sets `wire[n].node = <name>`
  for every wire the driver touches, *caching* it into the wire's `lab` token.
- A wire's own `lab` is therefore a **write-only cache, never read as a name
  source** (defect #6). Editing it is silently overwritten on the next rebuild —
  characterization **NC8** proves exactly this.

The consequence: the wire/instance recipe — "add an `id` field, stamp it at the
birth funnel, scan the array to resolve" — **does not transfer.** There is
nothing to stamp. We must first decide *what a net's identity even is*.

## 2. What the characterization established (Phase A, all 22 checks green)

`tests/stable_handles/net_*.tcl` locks today's surface. Two results are decisive:

- **NC3 — the §2c cold-start trap is real.** `resolved_net` of the *selection*
  returns empty on a cold select and the right net only after an unrelated query
  rebuilds `sel_array`. **Any new net command that reads the selection MUST call
  `rebuild_selected_array()` (and `prepare_netlist_structs(0)`) first.** This is
  the single sharpest hazard; the new surface must not reproduce it.
- **NC10 — the anchor survives what the name does not.** Renaming the net (by
  editing its *driver* label instance, per the §2d authority rule) changes the
  net's NAME under the wire (`MYNET` → `RENAMEDNET`), but the wire's `wire_id`
  and the driver's `instance_id` are **unchanged**. The stable ids that steps 1-2
  already shipped are exactly the durable thing a net handle wants to be.

In one line: **the net name is the unstable, derived part; the wire/label ids on
the net are the stable part.** A handle should be built from the stable part.

## 3. Why a net is not an instance (the analogy and where it breaks)

| | instance (step 2) | net (this step) |
| --- | --- | --- |
| stored? | yes — `xctx->inst[]` slot | **no** — derived equivalence class |
| birth funnel to stamp at | `inst_register()` | **none** |
| natural identity today | `instname` (reused, renamable) | `token` (reused, renamable, *recomputed*) |
| a place to put `unsigned int id` | the struct | **nowhere** |
| already-stable handle available | — (it was the thing being built) | **yes** — the wire/label ids *on* the net |

The instance decision was "id vs name vs both" because an instance *has* a slot.
The net decision is *prior* to that: there is no slot, so the first question is
whether to **invent** net storage (c3), **canonicalize the derived name** (c1),
or **borrow an existing stable handle** (c2).

## 4. The three options

### (c1) canonical name — a bridge over `(token, path)`
Treat the net's stable identity as a canonicalized form of its token (e.g. the
lexicographically-least equivalent label in a hierarchy), exposed via `net_*`
bridges over `(token, path)`.
- **+** cheap; no new storage; composes with the existing name-keyed queries
  (`instances_to_net`, `resolved_net <name>`, `hilight_netname`).
- **−** **does not survive a rename or auto-rename** — the exact weakness names
  had for instances (the reuse hazard the whole effort exists to kill). NC10
  shows the name moving under the user; a name-derived handle moves with it.
- **−** still `(token, path)`, so still entangled with hierarchy bookkeeping.
- **Verdict:** reintroduces the hazard we are paid to remove. Not it.

### (c2) anchor identity on a stored-object handle — **RECOMMENDED**
A net's durable handle *is* the stable id of a wire or label-instance on it:
"the net that **wire-id 5** is currently on," or "the net at **instance-id 3**'s
pin `PLUS`." Resolution runs the current connectivity and returns the net's
*present* token + membership.
- **+** reuses the step-1/2 ids **directly** — invents no net storage, adds no
  field to the connectivity engine, touches none of the §2c-trap-prone rebuild.
- **+** **rename-safe by construction**: you hold the *anchor*, not the name
  (NC10 — the anchor id is unchanged across the rename). The token stays the
  human / cross-session form, exactly the instance id-vs-name contract.
- **+** composes cleanly with the shipped `xschem object`/`objects` API: a net is
  addressed by an object handle you already know how to get.
- **+** lowest coherence risk — it is a *read/resolve veneer* over existing
  resolvers (`wire_index_from_id`, `inst_index_from_id`) plus a connectivity
  read, the same shape as `object`/`objects`.
- **−** a net with **no** wire and no label on it (a pure pin-to-pin abutment)
  has no obvious anchor — but such a net also has no user-visible object to point
  at, and `instances_to_net`/`instance_net` still address it by name. Acceptable
  for a first cut; note as a known edge.
- **−** the handle is "the net *under* this anchor," so if the user deletes the
  anchor the handle dangles (loud, like every other id) — correct behavior, but
  worth documenting: you are holding the anchor, and through it, its net.
- **Verdict:** the clean parallel to the instance id-vs-name contract, the
  least-invasive path, and the one that turns the work already done into net
  identity for free.

### (c3) a real net registry
Stamp ids into `node_table` and carry them across rebuilds by matching old/new
equivalence classes (a net that keeps ≥ N members keeps its id).
- **+** a true net *object*, independent of any wire/label, survives anchor
  deletion, closest to SKILL `net~>...`.
- **−** most invasive — new state *inside* the connectivity engine, recomputed
  every rebuild; the matching heuristic (when is a split/merged net "the same"
  net?) is a genuine research problem with no obviously-correct answer.
- **−** highest coherence risk — it lives right next to the §2c staleness traps
  this whole effort exists to cure; easy to introduce a new strain.
- **Verdict:** over-reach for a first cut. The right *future* direction if (c2)
  proves limiting (e.g. action-log replay of anchorless nets). Note and defer.

## 5. Recommendation — ship (c2), read-only, token as the human form

Build a small read/resolve surface where **a net is addressed by a stored-object
handle and described uniformly**, with the token as the human form. Mirrors the
`object`/`objects` veneer; invents no net storage; reuses steps 1-2 directly.

**Proposed surface (refine with the user before building):**

```
xschem net <selector>
    selector:  @wire <id>          the net the wire with stable id <id> is on
               @inst <id> <pin>    the net at instance-id <id>'s named pin
               <token>             by current net name (human form; may alias)
    -> a descriptor dict:
       {name <token> nwires <n> npins <m> anchor {wire <id>}}

xschem nets [-selected]
    -> a Tcl LIST of net descriptors, one per distinct net (deduped by token)

xschem net_members <selector>
    -> {wires {<id> ...} pins {{<inst-id> <pin>} ...}}   membership by handle
```

Contract, mirroring the instance id-vs-name roles:

- **anchor handle** (`{wire <id>}` / `{inst <id> <pin>}`) — the *durable machine
  reference*. It is a step-1/2 id, so it is already monotonic, never reused, and
  rename-safe. This is what a script stores, a log references, a data structure
  holds. Resolving it re-runs connectivity and yields the net's *current* token
  + members.
- **token** (the net name) — the *human / cross-session form*. Derived,
  reusable, renamable, recomputed every rebuild; fine to display and to address
  by, never to hold as a machine handle across edits.

**Hard requirements the implementation must meet (from Phase A):**

1. Every net command calls `prepare_netlist_structs(0)` first, and
   `rebuild_selected_array()` too if it consults the selection — so a *cold* call
   is correct (NC3 must not regress; a Phase C test asserts the cold path works).
2. Strictly **read-only** for the first cut. Net *rename* (edit the driver label,
   encapsulating the §2d trap) and net *creation* are explicit follow-ons, not in
   scope. `setprop wire lab` stays the documented no-op it is (NC8).
3. A dangling anchor (deleted wire/instance) resolves to `""` — loud, never a
   stranger — exactly like `object @<freed-id>`.

The cost is small and additive: no struct field, no engine change — a
dispatcher branch family (`xschem_cmds_n`) that reads existing state through
existing resolvers, plus a descriptor helper paralleling `object_descriptor()`.

## 6. The sub-decisions to settle alongside it (for the ratification)

These shape the surface; flagged so they are decided *with* the recommendation,
not discovered mid-build:

- **a) Anchor sigil grammar.** `@wire <id>` / `@inst <id> <pin>` vs folding into
  the existing `object`-style sigils. *Suggested:* keep `net` explicit and
  typed (`@wire`/`@inst`) so a net reference always says what it is anchored to;
  it reads next to `object <type> @id` without overloading it.
- **b) What `anchor` reports back.** When you resolve `xschem net <token>` by
  name, which anchor does the descriptor return? *Suggested:* prefer a **label /
  pin driver** if one exists (it is the net's *authority* — §2d), else the
  lowest-id wire on the net; document the rule so it is deterministic.
- **c) Hierarchy.** First cut operates at the **current** sheet (`sch_path`),
  matching `instances_to_net`/`resolved_net` today. Cross-hierarchy net identity
  (`(token, path)`) is noted as a c3-adjacent follow-on, not built now.
- **d) Membership currency.** `net_members` returns members **by handle**
  (wire-ids + `{inst-id pin}`), not coordinates — so the result is itself made of
  durable references and composes with `object`. Coordinates stay available via
  the existing per-object commands.

## 7. Phase C shape under this recommendation (for when ratified)

RED-first, the whole suite green throughout, exactly as steps 1-3:

1. A new `xschem_cmds_n` dispatcher group (paralleling `xschem_cmds_o`) holding
   `net`, `nets`, `net_members`. No new struct, no new counter.
2. A `net_descriptor(buf, ...)` helper paralleling `object_descriptor()`: given a
   resolved net (token + membership), emit the bare dict; the caller brace-wraps
   for the `nets` list (the same single-vs-list wrapping bug `object` hit).
3. Resolution: `@wire <id>` → `wire_index_from_id` → `wire[i].node`;
   `@inst <id> <pin>` → `inst_index_from_id` + pin lookup → `net_name(...)`;
   `<token>` → use directly. All after `prepare_netlist_structs(0)` (+
   `rebuild_selected_array()` for `-selected`).
4. Membership: scan `wire[].node == token` for wire members (return their ids)
   and the `instances_to_net`-style pin scan for pin members (return
   `{inst-id pin}`).
5. RED tests in a `net_*.tcl` Phase-C section: anchor→net (`@wire`/`@inst`),
   net→members by handle, the **cold-call correctness** assertion (the NC3 fix),
   rename-safety end-to-end (hold an anchor, rename via the driver, re-resolve →
   new token, same anchor), and a dangling-anchor `""`. Sabotage-verify the
   resolver (constant/empty) reddens the right checks.
6. Close-out: `probe7.tcl` re-running the §2c scenario side-by-side with the
   handle version; doc cross-refs (`object_query_api.md`, introspection §2c/§5,
   the directions guide); a `doc/` manual if the surface warrants.

Decision owner: **the user.** This record exists so the identity model is on the
books and ratified before any net command is added.
