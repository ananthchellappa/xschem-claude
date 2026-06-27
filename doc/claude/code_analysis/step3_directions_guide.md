# Step-3 directions for stable object handles — a decision guide

*Pick the next thing to fix. This doc gives each candidate a tutorial-style
walkthrough with concrete, run-verified examples, an honest effort/payoff/risk
read, and how it relates to the north star (SKILL-parity scripting) and to
[[action-logging]] issue 0005 (replay-by-handle).*

Companion to `stable_handles_extension_strategy.md` (the "refactor first?"
analysis) and `tcl_introspection_wire.md` (the original defect list). Where this
doc shows command output, it was run against a real build on this branch.

> **STATUS UPDATE (2026-06-13): directions (a) AND (b) are DONE.**
> **(a)** rect/line/poly/arc carry session-stable ids (`xschem <type>_id`/`<type>_index`,
> one shared id space; `selection` rows filled). Census + funnel + RED→GREEN +
> sabotage-verified; `graphical_lifecycle_census.md`, suite `gfx_*.tcl` (54),
> probe `probe5.tcl`, manual `doc/stable_graphical_handles.md`. One correction to
> §2.4: the design call resolved *against* the recommendation — see the box there.
> **(b)** the uniform read API shipped: `xschem objects [-type|-selected|-layer]`
> enumerates every object as a self-describing dict `{type index layer id name}`,
> and `xschem object <type> <selector>` resolves `@id`/`#index`/`#layer,index`/name
> to one descriptor. RED→GREEN + sabotage-verified; suite `object_*.tcl` (18),
> probe `probe6.tcl`, manual `doc/object_query_api.md`.
> **text (the 7th type) is now DONE too** (own counter + `text_id`/`text_index`,
> flat-array, RED→GREEN + sabotage-verified, suite `text_*.tcl` (14)). **ALL
> SEVEN drawable types now carry session-stable ids** and `xschem objects` is
> fully id-bearing.
> **(c) net-as-object is now DONE too (2026-06-13), read-only first cut.** A net
> is derived (no slot), so its handle is an *anchor* — a wire/instance id on it
> (design option **c2**, ratified by the user). `xschem net @wire <id>` /
> `@inst <id> <pin>` / `<token>` → `{name nwires npins anchor}`; `xschem nets
> [-selected]`; `xschem net_members <selector>` → members by handle. Rename-safe
> (NH8), dangling → "" (NH9), cold-call correct (NH5, the §2c fix). Design-first
> → RED → GREEN → two-path sabotage; decision `net_identity_decision.md`, manual
> `doc/net_as_object.md`, suite `net_*.tcl` (39), probe `probe7.tcl`. Remaining
> live direction: action-logging 0005 (replay-by-handle), now feasible for every
> drawable type AND for nets (`object <type> @id` + `net <anchor>`).

---

## 0. Where we are

Two of the seven drawable object types now carry a **session-stable id**:

| type | array | id? | resolver commands | birth funnel |
| --- | --- | --- | --- | --- |
| wire | `xctx->wire[]` (flat) | ✅ | `wire_id`/`wire_index` | `wire_store*` (step 1) |
| instance | `xctx->inst[]` (flat) | ✅ | `instance_id`/`instance_index` | `inst_register` (step 2) |
| rect | `xctx->rect[layer][]` | ❌ | — | — |
| line | `xctx->line[layer][]` | ❌ | — | — |
| poly | `xctx->poly[layer][]` | ❌ | — | — |
| arc | `xctx->arc[layer][]` | ❌ | — | — |
| text | `xctx->text[]` (flat) | ❌ | — | — |

The recipe that worked twice: **characterize → census → funnel the lifecycle →
stamp identity at the funnel → expose two resolver commands**. And the shared
read surface, `xschem selection`, already returns one `{type index col id}` row
per selected object — today it carries a real id only for wires and instances:

```tcl
# placed one rect (layer 4) and one line (layer 4), then select_all:
xschem selection
;# -> {rect 0 4 -1} {line 0 4 -1}
;#        │  │ │  └ id: -1  (no stable id for graphical types yet)
;#        │  │ └ col: 4     (THE LAYER — for graphical types col == layer)
;#        │  └ index within that layer's array
;#        └ type
```

That one line of output is the hinge for all three directions below: (a) fills
the `-1`, (b) turns the row into a first-class object you can query, (c) adds a
row type the enumerator can't currently produce at all.

---

## 1. The three candidates at a glance

| | (a) graphical types | (b) `xschem object` API | (c) net-as-object |
| --- | --- | --- | --- |
| **one-liner** | finish the job: ids for rect/line/poly/arc (+text) | a uniform read/resolve veneer over the ids that exist | identity for *nets*, which are derived, not stored |
| **new concept** | per-**layer** addressing `(type, layer, index)` | reference convention (`@id` / `#index` / name) | what identity even *means* for a recomputed entity |
| **builds on** | the proven funnel recipe, 3rd/4th time | the ids already shipped (Rule of Three trigger) | almost nothing — new ground |
| **effort** | medium (mechanical, but ×4 types ×per-layer) | low–medium (mostly Tcl/dispatch veneer) | high (research-first) |
| **risk** | low (recipe known; compaction already per-layer) | low (additive read layer) | high (touches connectivity/coherence) |
| **payoff** | completeness; unblocks (b) for all types | ergonomics; the API users actually want | the biggest SKILL-parity gap closed |
| **0005 fit** | lets the log reference *any* shape by handle | the natural place a replay resolver lives | lets the log say "the net OUTI", the holy grail |

The rest of this doc is the long version of that table.

---

## 2. Direction (a): the graphical types (rect / line / poly / arc)

### 2.1 What they are, by example

Unlike wires and instances (flat arrays), the four graphical types live in
**per-layer** arrays — one sub-array per drawing color/layer:

```tcl
xschem clear force schematic
xschem get rectcolor          ;# -> 4   (the "current layer" new shapes land on)
xschem rect 100 100 300 200   ;# a rectangle on layer 4
xschem line 0 0 500 0         ;# a line on layer 4
xschem get rects 4            ;# -> 1   (count is PER LAYER: note the "4")
xschem get lines 4            ;# -> 1
```

`xschem get rects` with no layer is an *error* — `give a layer number` — because
there is no single flat count; a rect is addressed by the pair **(layer,
index)**, e.g. "rect 0 on layer 4". That pair is exactly what shows up in the
selection row's `index` and `col` fields above.

### 2.2 Why they're the lone second-class types

Every mechanism the handles effort built stops at the flat types:

- `xschem selection` returns `-1` in their id slot (§0).
- there is no `rect_id` / `line_index` / etc.:
  ```tcl
  xschem rect_id 4 0    ;# -> xschem rect_id: invalid command.
  ```
- so a script that grabs "rect 0 on layer 4", then deletes an earlier rect on
  the same layer, has the **exact §2e dangling-index bug** wires and instances
  were just cured of — with no handle to fall back on.

The compaction that causes it is already there, just **replicated four times**
inside a per-layer loop (`select.c:399–488`):

```c
for(c=0;c<cadlayers; ++c) {
  /* rects:  order-preserving shift, xctx->rects[c] -= j;   */
  /* lines:  same idiom again                                */
  /* arcs:   same idiom again                                */
  /* polys:  same idiom again (plus free x/y/selected_point) */
}
```

Four hand-rolled copies of the same shift = four chances for the index to move
under a held reference, and zero handles. This is the worst-covered corner of
the object model.

### 2.3 What the work looks like

The recipe is known; the only genuinely new thing is the **per-layer
addressing**. A sketch, mirroring step 2:

1. **Characterize** rect/line/poly/arc lifecycle through the Tcl surface
   (create on a layer, select, delete an earlier one, undo) — locking today's
   per-layer index behavior, including the dangle.
2. **Census** the births/deaths/reorders. Births: `storeobject` (rect+line),
   `store_poly`, `store_arc`. Death: the one per-layer compaction above. Plus
   the realloc/grow sites (`check_box_storage` etc.) and any change-layer move
   (a shape changing color *moves between sub-arrays* — the per-layer analog of
   `change_elem_order`, worth a hard look).
3. **Funnel** each type's births through a register chokepoint and the deaths
   through one compaction helper (per layer) — the rect/line/poly/arc analog of
   `inst_register` / `inst_delete_compact`.
4. **Stamp** `unsigned int id` in each struct (they already carry `prop_ptr`,
   `sel`, `dash`, `bus` — adding one int is trivial), one counter per context.
5. **Resolve** with a linear scan — but now the scan is **over all layers**,
   because an id is unique per *context*, not per layer, and a shape can change
   layer. The resolver returns the pair: `{layer index}` or `-1`.
6. **Expose** `xschem rect_id <layer> <index>` → id, and
   `xschem rect_index <id>` → `{layer index}` (and the same for line/poly/arc);
   fill the selection row's id slot.

### 2.4 The one design call to make — and how it actually resolved

**Does the id survive a shape changing layer?** The recommendation here was
"yes" (same spirit as "id survives rename" for instances).

> **RESOLVED (against the recommendation).** `change_layer()` (`actions.c:3349`,
> triggered by `xschem set rectcolor` on a selection) is implemented as
> **delete + recreate** on the new layer — not an in-place attribute edit like
> the instance rename. Making the id survive would mean *rewriting* change_layer
> to carry the id through the reconstruction: a behavior change, not the additive
> stamp the rest of the effort is. So the shipped semantic is **the id does NOT
> survive a layer change** — the reconstructed object gets a fresh id and the old
> id dangles (loud `-1`), exactly like a disk-undo restore. The resolver still
> scans **all** layers (an object can be born on any layer) and returns
> `{layer index}`. Characterized by GH6; demonstrated in probe5 §5. Lesson: an
> "id survives X" promise is only free when X is an in-place edit; when X
> reconstructs the object, surviving costs a behavior change.

### 2.5 Effort / payoff / risk

- **Effort:** medium. Four types instead of one, and per-layer instead of flat,
  but each step is mechanical and the recipe is proven. Text (the 7th type) is
  a flat array and can ride along almost for free.
- **Payoff:** *completeness*. After this, **all seven types** carry ids and
  `xschem selection` is fully populated — which is the precondition that makes
  direction (b) cover everything instead of two types.
- **Risk:** low. The compaction already exists and is order-preserving; you're
  consolidating and stamping, not redesigning. The only subtlety is the
  layer-change move.

> **Pick (a) if** you want to finish what's started and unlock a *uniform* (b),
> and you prefer low-risk mechanical work with a known recipe.

---

## 3. Direction (b): the uniform `xschem object` read API

### 3.1 The friction today

Two types have ids, but reading and converting between (id, index, name) is a
scatter of type-specific commands with different shapes:

```tcl
xschem wire_id 6            ;# wire: index -> id
xschem instance_id R25      ;# instance: name OR index -> id
xschem instance_index 470   ;# instance: id -> index
xschem wire_coord 6         ;# wire geometry (different command)
xschem instance_coord R25   ;# instance geometry (different command, different shape)
xschem selection            ;# the only place a uniform {type index col id} row exists
```

A script that wants "give me a durable handle to whatever is selected, then
later get its geometry back" has to branch on type and call a different command
family per branch. The *data* is uniform (every object has type, index, a
handle, geometry, props); the *API* is not.

### 3.2 What the unified veneer would look like

A small read/resolve layer on top of what already exists — **no new identity
mechanism**, which is what makes this low-risk:

```tcl
# resolve any reference to a normalized descriptor (PROPOSED shape):
xschem object @470
;# -> type instance  id 470  index 117  name R25  layer 1  bbox {...}

xschem object #6@wire           ;# index 6, type wire
;# -> type wire  id 124  index 6  name {}  layer 4  bbox {...}

# enumerate with a filter, every row the same shape as `selection`:
xschem objects -type instance -selected
;# -> {type instance id 470 index 117 ...} {...} ...
```

The **reference convention** is the one decision to lock (it was already flagged
in `instance_identity_decision.md` §6): a sigil grammar that disambiguates the
three ways to name a thing —

- `@<n>`  → by stable **id** (the durable handle)
- `#<n>`  → by current **index** (transient)
- bareword → by **name** (instances/labels/pins only)

…which also cleanly resolves the pre-existing latent collision that an instance
literally named `5` is unreachable by name today (`get_instance` treats digits
as an index).

### 3.3 Why it's the "Rule of Three" moment

`stable_handles_extension_strategy.md` argued: don't build the framework until a
second/third consumer proves the seam. You now have **two** id-carrying types
and an existing `selection` row format — the serializer seam is real and
exercised. (b) is *extracting* that seam (a single object-ref serializer + a
validated `(type,ref)→(i,col)` resolver), not inventing one. The strategy doc
explicitly named these as two of the four just-in-time seams.

### 3.4 Effort / payoff / risk

- **Effort:** low–medium, and *mostly Tcl + dispatch glue* rather than core C —
  it reads existing state through existing accessors.
- **Payoff:** this is the API surface users (and an LLM writing xschem Tcl)
  actually want — one verb, uniform rows, handle-first. High ergonomic return.
- **Risk:** low; it's an additive read layer. The honest caveat: built **now**
  it covers only wire + instance richly and returns `-1`/`{}` for the other
  five. Built **after (a)** it covers all seven uniformly.

> **Pick (b) if** you value the developer/agent-facing ergonomics most and are
> comfortable either shipping it two-type-rich now or sequencing it after (a).

---

## 4. Direction (c): net-as-object

> **RESOLVED & SHIPPED (2026-06-13).** Design-first as predicted: a
> characterization suite locked the current net surface (the §2c trap, the
> derived-name authority trap, and the key finding that a net's *stable anchors
> already exist* — the wire/label ids survive a rename that the net name does
> not), then a decision doc (`net_identity_decision.md`) laid out c1/c2/c3 and
> the user ratified **c2**: a net's durable handle is the stable id of a wire or
> label-instance *on* it. Built read-only, RED→GREEN→two-path-sabotage: `xschem
> net <selector>` / `nets [-selected]` / `net_members <selector>`, where the
> selector is `@wire <id>` / `@inst <id> <pin>` / `<token>`. Reuses the step-1/2
> resolvers, invents no net storage, fixes the §2c cold-call trap by contract,
> and composes with the `object` API (membership comes back as handles). Manual
> `doc/net_as_object.md`, suite `tests/stable_handles/net_*.tcl` (39), probe
> `introspection_probes/probe7.tcl`. The §4.3 (c2) option below is the one that
> shipped; (c3) the registry remains the future direction if c2 proves limiting.

### 4.1 Why this one is different in kind

Wires, instances and shapes are *stored* — there's a struct in an array you can
stamp. **A net is not.** A net is a *derived* equivalence class of connected
pins and wire segments, recomputed from scratch every time connectivity is
rebuilt. Its identity today is a **string token** (the net name) living in a
hash table:

```c
struct node_hashentry {            /* xctx->node_table[] — the net table */
  struct node_hashentry *next;
  unsigned int hash;
  char *token;                     /* THE net name, e.g. "OUTI" — its identity */
  char *sig_type; char *value; char *class; ...
  Drivers d;
};
```

Highlighting keys off the same string plus the hierarchy path
(`hilight_table`, token + `sch_path`). There is no `net[]` array, no slot, no
index — so there is nothing to put an `unsigned int id` *on*, and the wire/inst
recipe does not transfer.

### 4.2 The net surface today, and its trap

Nets already have the *richest* query family (netlisting needed it):

```tcl
xschem instances_to_net OUTI   ;# -> {{vd} {plus} {1110} {-660}} {{vu} {minus} ...}  pins on the net
xschem instance_net X10 PLUS   ;# -> the net name at a pin
xschem hilight                 ;# highlight the net(s) of the selection
```

But the identity is a *name*, and the name is **derived and unstable**:

- it changes if you rename the driving label (the §2d "authority trap": to
  rename a net you edit a label *instance*, and the net name follows);
- it is recomputed on every connectivity rebuild, and `resolved_net` reads a
  stale `sel_array` if you don't rebuild first (`tcl_introspection_wire.md` §2c,
  defect #3) — the canonical coherence bug;
- two different nets in different hierarchy levels can share a token; identity is
  really `(token, path)`.

So "hold a handle to *this net* across edits" has no answer today, and it's the
single biggest gap against the Cadence/SKILL yardstick (`net~>terms`,
walk-the-graph-anywhere).

### 4.3 What an identity would even mean (the research)

This is the part that needs design before code. Options, roughly:

- **(c1) canonicalize the name** — define the stable name as the
  lexicographically-least equivalent label in a hierarchy, expose
  `net_id`/`net_index`-style bridges over `(token, path)`. Cheap-ish, but
  doesn't survive a rename — same weakness names had for instances.
- **(c2) anchor identity to a stored object** — a net's durable handle *is* the
  handle of its defining label-instance (which now has a stable id from step 2!).
  "The net of instance-id 470's PLUS pin." This reuses existing identity and
  sidesteps inventing net storage — promising, and it's why (c) is *easier after
  ample instance tooling*, not before.
- **(c3) a real net registry** — stamp ids into the node table across rebuilds
  by matching equivalence classes between the old and new computation. Most
  powerful, most invasive, most coherence risk.

### 4.4 Effort / payoff / risk

- **Effort:** high, **research-first** — expect a characterization + design doc
  phase (what is a net's identity, which option, how it survives a rebuild)
  before any funnel/stamp work. The recipe does *not* port directly.
- **Payoff:** highest against the north star. Net-level handles are what real
  schematic automation (and an LLM driving the tool) reach for first, and it's
  the marquee SKILL-parity gap.
- **Risk:** high — it lives next to the connectivity engine and the known
  coherence traps (#3). Easy to introduce a new strain of the staleness this
  whole effort exists to cure.

> **Pick (c) if** you want the highest-impact capability and are willing to fund
> a research/design phase first — and note it gets materially easier *after* (a)
> and (b), because (c2) leans on stored-object handles and a uniform resolver.

---

## 5. How each feeds action-logging issue 0005 (the "(d)")

0005 is "replay the log by stable referent instead of by raw index". It is not a
peer of (a)–(c); it's a **downstream consumer** that needs them:

- replaying *"delete the wire I made 30 steps ago"* needs wire handles ✅ (done);
- replaying an edit to a rect/text needs (a);
- the natural place a replay resolver lives — turning a logged `@id` back into a
  live object — is (b)'s reference layer;
- replaying *"probe the net OUTI"* needs (c).

So 0005 is best read as the **forcing function** that says: the more object
types carry handles and the more uniform the resolver, the more of the log
becomes replayable-by-meaning. It argues for (a) then (b), with (c) unlocking
the net-level log entries last.

---

## 6. A decision matrix (you pick — this is a recommendation, not a choice made)

| if you want… | pick | because |
| --- | --- | --- |
| finish the model, lowest risk, known recipe | **(a)** | all 7 types get ids; unblocks a uniform (b) and (d) |
| the API users/agents actually want, soon | **(b)** | ergonomics now; extracts the proven seam (Rule of Three) |
| the biggest capability, willing to research | **(c)** | net handles = the marquee SKILL-parity gap |

**Natural sequence if you don't want to choose a single one:** (a) → (b) → (c).
(a) makes (b) uniform across all types; (b)'s resolver is where (c2) plugs in;
(c) is the research-heavy capstone that benefits from both. Each is independently
shippable and independently valuable, so you can stop after any one.

The same discipline applies to whichever you pick: **characterize first,
RED-first tests, census with the dual-grep acceptance, funnel before stamping,
sabotage-verify the stamp** (the [[green-but-hollow]] rule). That is what made
steps 1 and 2 land clean, and it is type-agnostic.

---

*Grounding: per-layer storage `xctx->rect[layer][]` etc. (`xschem.h:578–586`);
the four-way per-layer compaction (`select.c:399–488`); the net table
(`node_hashentry`, `xschem.h:777`); the selection row format
(`scheduler.c` `selection` branch). Command outputs in §0/§2 are from a real run
on this branch. See also `stable_handles_extension_strategy.md`,
`tcl_introspection_wire.md`, `instance_identity_decision.md`.*
