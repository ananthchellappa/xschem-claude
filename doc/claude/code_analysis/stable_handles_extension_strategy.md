# Stable object handles — extension & refactoring strategy

How amenable is the XSCHEM codebase to the *large amount of query/command
surgery* that the stable-object-handles direction implies, and should we
refactor first to make that work easier? This is the architecture note that
answers those two questions. It is the forward-looking companion to:

- `tcl_introspection_wire.md` — the gap analysis that motivated the effort
  (§3 the per-type asymmetry, §5 the defect list, §6 the direction sketch);
- `wire_lifecycle_census.md` — the lifecycle-scatter census for wires;
- `plan_stable_handles_step1.md` — the executed step-1 plan (wires);
- `FAQ.md` Q7–Q12 — the running design Q&A;
- `green_but_hollow_tests.md` — the testing discipline this strategy leans on.

**Bottom line up front:** do **not** refactor-first with a big-bang. Keep
extending incrementally, but extract a small set of shared seams *just in time*
— test-first, triggered by real repetition — as the next type (instances) is
funnelled. The single highest-value investment is broader characterization
coverage, not new abstraction. Lock one convention now (object-reference
serialization); defer the helper extractions until the second/third consumer
exists.

---

## 1. What "tonnes of surgery" actually means here

The trajectory from `tcl_introspection_wire.md` §6 and the step-1 plan is a
long sequence of additive changes of a few recurring shapes:

- **identity for the other six object types** (instances next, then the
  per-layer graphical types) — repeat census → funnel → stamp;
- **bulk/typed read commands** (`xschem objects <type>`, `xschem object
  <ref>`, net→wires, region→objects) — the uniform read layer;
- **selection-as-data** beyond the `selection` command just added;
- **coherence** (every query rebuilds the caches it reads);
- **pothole fixes** (`wire_coord 0`, unchecked `getprop` index, …).

Every one of these touches the same two places: the **command dispatcher**
(`scheduler.c`) and the **object data model** (`xctx` arrays + their lifecycle).
So "is the code amenable" decomposes into "how amenable is each of those two."

---

## 2. Amenability, graded by layer

### 2a. The dispatch layer — *high amenability* (proven)

The `xschem` command is one dispatcher of **235 subcommands** across a
7,535-line `scheduler.c`, decomposed into per-first-letter functions
(`xschem_cmds_a … xschem_cmds_z`). Each subcommand is a self-contained
`else if(!strcmp(argv[1], "…"))` branch.

This layer is *easy* to extend, and we have direct evidence: this session
added `wire_id`, `wire_index`, and `selection` — three branches, zero
collateral, each verified in isolation. The 236th command costs what the
235th did. **No refactoring is needed to keep adding commands.** The
per-letter split already tamed the one real navigability risk (a single
thousand-branch function).

### 2b. The data model — *medium amenability* (a repeated tax)

The friction is one level down, and because it is *per-command*, you pay it on
every new query. Four recurring taxes, each evidenced:

1. **No uniform result serialization.** Each command invents its own output
   format: `selected_set` → `{name}`, `selected_wire` → `{label}`,
   `first_sel` → `type n col`, `wire_coord` → bare floats, the new `selection`
   → `{type index col id}`. Every consumer writes a bespoke parser
   (`tcl_introspection_wire.md` §3 catalogues the format zoo).
2. **No uniform addressing/validation.** Each command re-rolls its own bounds
   check, and some are wrong: `wire_coord`'s `n > 0` off-by-one (defect #1)
   and `getprop wire`'s unchecked `atoi(argv[3])` straight into the array
   (defect #2) are the *same missing helper*, failing two different ways.
3. **No general "for each object" iterator.** The 7-type, per-layer walk
   (`for(c=0;c<cadlayers;…)` over `rect/line/poly/arc`, plus the flat
   `wire/text/inst` arrays) is hand-rolled in **10 files** (`netlist.c`,
   `findnet.c`, `psprint.c`, `draw.c`, `save.c`, `move.c`, `actions.c`,
   `hilight.c`, `select.c`, `svgdraw.c`). The *one* generic iterator that
   exists — `object_iterator_next` (`hash_iterator.c:160`, set up by
   `init_object_iterator` at `:137`) — is **spatial** (it takes a bbox), so
   bulk read commands cannot reuse it; they walk by hand again. The canonical full traversal already lives in
   `rebuild_selected_array` (`move.c:52`); nothing generalises it.
4. **Lifecycle/identity scatter.** Step 1 funnelled *wires* (births/deaths/
   compaction → `store.c`: `wire_store` / `wire_store_split` /
   `wire_delete_compact` / `wire_storage_reset`; id stamped at the funnel).
   The other six types still have scattered lifecycles — the census work
   repeats per type.

### 2c. The physical constraint that is *not* a defect

One thing that looks like duplication but is real: objects split into
**flat arrays** (`wire`, `text`, `inst` — addressed by one index) and
**per-layer arrays** (`rect`, `line`, `poly`, `arc` — `xType **` addressed by
`(layer, index)`). That `(layer, index)` second coordinate is a genuine
storage difference, not incidental copy-paste. Any abstraction must *carry* it,
not pretend it away — which is exactly why `selection` rows include `col`.

---

## 3. The recommendation: incremental, test-anchored, just-in-time

### 3a. Why **not** refactor-first (big-bang)

A speculative architecture refactor ahead of need would be the wrong move here,
for reasons specific to this codebase, not generic caution:

- **C89, ~25 years old, one giant global `xctx`.** Wide blast radius per
  change; many implicit invariants.
- **No comprehensive test net** except the characterization suites we have been
  growing deliberately. Refactoring code whose behaviour nothing pins down is
  the *green-but-hollow trap at architectural scale* (`green_but_hollow_tests.md`):
  you would be changing code with no way to prove you preserved its behaviour.
- **The incremental method has already worked three times in this repo.** The
  action-registry funnel, the action-logging funnel, and the wire-identity
  funnel all landed safely by the same move: *characterize → funnel one seam →
  verify → repeat.* That is the de-risking mechanism, and it already exists.

### 3b. Why not "just keep bolting on branches" either

Unbounded ad-hoc extension is the other failure mode: four more divergent
result formats, four more hand-rolled walks, four more subtly-wrong bounds
checks. The discipline that avoids both extremes is the **Rule of Three**:
extract a shared seam when the *third* consumer appears, using the repetition
itself as proof the abstraction is right — and extract it **test-first**, like
everything else here.

We are now at that inflection point. `wire_id` / `wire_index` / `selection`
are the *first* object-reference handling; the instances-identity work (the
planned next step) is the second and third. That work is precisely *when* to
lift the seams out — not before, not never.

### 3c. The seams to extract — and their just-in-time triggers

In dependency order. None of these is a prerequisite to starting the instances
work; each is extracted *during* it, the moment the second hand-written copy
would otherwise be typed.

| Seam | Generalise from | Extract when | Kills |
| --- | --- | --- | --- |
| **Object-reference serializer** (`{type index col id …}`) | `selection` (already prototypes the shape) | the 2nd read command would emit object refs | the format zoo (tax #1) |
| **All-types object iterator** | `rebuild_selected_array` (`move.c:52`) — the canonical walk | the 2nd bulk command would hand-roll the 7-type walk | the 10-file duplication (tax #3) |
| **Validated object-arg resolver** (`(type,index) → checked (i,col)`) | the scattered per-branch bounds checks | the next command parses an object index | defects #1/#2 + boilerplate (tax #2) |
| **Per-type lifecycle funnel** | `store.c` wire funnel | each new type gets identity | scatter (tax #4) — already the plan |

### 3d. The one thing to do slightly *ahead* of need

**Lock the object-reference serialization *convention* now**, while only
`selection` sets precedent. Deciding "every object-reference output is
`{type index col …}`, type ∈ `wire|instance|rect|line|poly|arc|text`" costs
nothing today and means the next three read commands *follow* it instead of
inventing three more formats to reconcile later. Conventions are cheap to set
early and expensive to retrofit; *abstractions* are the opposite — which is the
whole asymmetry behind this strategy: **lock conventions early, defer helpers
until duplication proves them.**

### 3e. The highest-value investment is not structural

The thing that turns every future change from scary to routine is **broader
characterization coverage**, because that is what makes a refactor provably
behaviour-preserving. If there is budget to "invest in making future work
easier," spend most of it on tests (per-type lifecycle characterization, the
seven-type selection/serialization invariants), not on speculative framework.
The funnel pattern plus characterization tests *is* the enabling
infrastructure, and it is already in place.

---

## 4. Caveat: ride the grain, don't fight it

This codebase is concrete, explicit, and repetitive *by temperament*. Favour a
few **thin** helpers that match its idiom (plain C functions, no hidden control
flow, the `(layer, index)` distinction carried in the open) over a grand
"object framework" with vtables and registration. The flat-vs-per-layer split
is physical; an abstraction that hides it will leak. The goal is to remove the
*duplicated* parts of the surgery (format, walk, validation), not to make the
data model pretend every object is uniform when it is not.

---

## 5. Suggested sequence (no big-bang anywhere)

1. **Instances identity** — next per the step-1 plan: census → funnel → stamp,
   characterization-tested, RED-first. (The worst remaining scatter; the recipe
   is proven on wires.)
2. **During (1), extract the first seam that repeats** — most likely the
   object-reference serializer (when the instance read command needs to emit a
   ref) and/or the validated arg resolver — each behind its own characterization
   test, justified by the second real consumer.
3. **Uniform read layer** (`xschem objects <type>`, `xschem object <ref>`) on
   top of the serializer + iterator once both exist.
4. **Coherence rule** — fold cache rebuilds into the query path as the read
   layer formalises (fixes defect #3's class).
5. **Pothole fixes** (`wire_coord 0`, etc.) as isolated commits whenever the
   surrounding code is already open — never mixed into a refactor diff.

Each step independently revertable, suite green throughout — the same cadence
that delivered step 1.
