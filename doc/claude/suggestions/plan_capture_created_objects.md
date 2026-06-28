# Plan — capture a Tcl reference to ANYTHING created

*North star:* **everything XSCHEM creates is an object, and a Tcl caller must be
able to capture a durable reference to it** — whether the object was made by a
scripted command, a bulk load/paste, or a mouse gesture in the GUI. This is the
generalization of Cadence's "the CIW echoes the db_ID of every object you
create."

Status: **PLAN ONLY — no code yet.** Analysis below is run-verified on
`feature/stable-object-handles`. Build phases are RED-first per the project's
established discipline.

---

## 1. Where we already are (the expensive part is done)

The Cadence feature needs two things; we own the hard one.

| Prerequisite | Status |
| --- | --- |
| Every drawable object carries a **session-stable handle** (the db_ID equivalent) | ✅ all 7 types (`wire`/`instance`/`rect`/`line`/`poly`/`arc`/`text`) |
| Nets carry a handle | ✅ anchor-based (`net @wire`/`@inst`) |
| Resolve a handle back to a live object (`obj~>` equivalent) | ✅ `xschem object <type> @id`, `xschem objects` |
| **Births funnel through single choke points** | ✅ `wire_store`, `inst_register`, `gfx_register`, `text_register` (the funnel work) |
| **Monotonic per-type id counters** | ✅ `wire_id_counter`, `inst_id_counter`, `gfx_id_counter`, `text_id_counter` (`xschem.h:964-974`, init 0 at `xinit.c:514-517`) |
| **Creation commands return the new handle** | ❌ the gap |
| **A uniform way to capture creates from compound/GUI operations** | ❌ the gap |

The two ❌ rows are this plan.

## 2. The key insight — a creation substrate already exists

The identity work left behind exactly the machinery a capture feature needs, for
free:

- **Four birth choke points** (`wire_store`, `inst_register`, `gfx_register`,
  `text_register`) — *the* places, and the only places, an object comes into
  being. Anything created — by a command, a paste, a load, or a mouse drag —
  passes through one of these four. They are the natural **creation-event
  emission points**.
- **Four monotonic counters** that advance by exactly one per birth and are never
  rewound. A snapshot of the four is a **creation timestamp**: any object whose
  `id` exceeds the snapshot value *for its type* was born after the snapshot.

So "what did this operation create?" reduces to **diffing the id-space** — no new
struct field, no per-funnel return-value plumbing, no change to the connectivity
engine. That is the spine of the whole design.

> Verified: current creation commands return inconsistent noise, not handles —
> `wire`→`""`, `line`→`"0"`, `rect`→`"0"`, `arc`→`"1"`, `polygon`/`text`→`""`,
> `instance`→`"0"`. And **no in-tree Tcl/test caller inspects these results**
> (audited `src/*.tcl`, `tests/`). So the values are unused noise — low-risk to
> standardize, but see §7 for the external-script caveat.

## 3. The design — three capture layers over one substrate

Different creation situations need different ergonomics; all three layers sit on
the §2 substrate, so they stay consistent.

### Layer A — the capture primitive (covers *everything*, zero compat risk)

A mark/diff pair, modeled on git's "what changed since":

```tcl
set m [xschem creation_mark]        ;# opaque token = snapshot of the 4 counters
# ...any creating operation(s): a command, a paste, a load, a script, a gesture...
xschem objects -created-after $m    ;# -> list of descriptors for every new object
```

- `creation_mark` returns an opaque token encoding the four counter values.
- `objects -created-after <mark>` is a **new filter on the existing `objects`
  enumerator** (`scheduler.c` `xschem_cmds_o`): emit a descriptor for each object
  whose `id > mark[type]`. Reuses the descriptor the API already speaks.
- **Covers literally anything** — single command, paste of 40 objects, a whole
  loaded schematic, even GUI-drawn objects — because it reads the id-space the
  funnels maintain regardless of *how* the object was born.
- **Changes no existing command's return value → zero backward-compat risk.**
- Naturally excludes memory-undo restores (they preserve ids → counter
  unchanged) and naturally includes disk-undo re-mints (they advance the counter)
  — a defensible, documentable semantic (see §6.D).

This layer alone fully satisfies the north star. B and C are ergonomics.

### Layer B — per-command direct return (the Cadence-CIW feel for scripts)

Make each scripted creation command *return* the handle(s) of what it made, so
the common case needs no mark:

```tcl
set w  [xschem wire 0 0 100 0]          ;# -> one descriptor (unwrapped, like `object`)
set ps [xschem paste]                   ;# -> a LIST of descriptors (compound create)
dict get $w id                          ;# -> 7
```

Implemented as the *same* substrate, applied uniformly: at the top of each create
branch, snapshot the counters; after the create, emit `created-after`. One
helper, every branch — so single-object commands return one descriptor and
compound commands (paste/copy/merge) return the list, with no per-command special
casing. This is where the **return-shape** and **compat** decisions live (§6.A,
§7); recommend gating it behind ratification.

### Layer C — the creation event stream (GUI + the persistent log)

The CIW-echo proper: a hook at the four birth funnels that, *when enabled*, emits
each new handle to a sink. This is the only layer that catches **GUI-drawn
objects** (a mouse-dragged wire never returns through a scripted command):

```tcl
xschem on_create {apply {h {puts "created: $h"}}}   ;# register a Tcl callback
# or route to the action log (Xschem.log) — see §5
```

- Single emission point set = the four funnels; gated by a flag (off by default,
  like `only_probes`) so there is no overhead or noise unless asked.
- Directly advances **action-logging issue 0005** (replay-by-handle): the log can
  record "the wire that became id 7," now true for every type *and* for nets.
- The undo-restore gating (§6.D) matters most here.

## 4. Census — every creation path (what makes objects, and how many)

From `scheduler.c` dispatch + the funnel return types (`store.c`, `actions.c`,
`paste.c`, `move.c`):

| command / op | makes | count | funnel | returns the index today? |
| --- | --- | --- | --- | --- |
| `wire` | wire | 1 | `wire_store` | yes (`wire_store`→idx) |
| `line` `rect` | line/rect | 1 | `storeobject` | no (`storeobject`→modified flag) |
| `polygon` | poly | 1 | `store_poly` (void) | no |
| `arc` | arc | 1 | `store_arc` (void) | no |
| `text` `place_text` | text | 1 | `create_text` (1/0) | no |
| `instance` `place_symbol` | instance | 1 | `place_symbol` (1/0)→`inst_register` | no |
| `net_label` | label instance | 1 | place + GUI | no — **GUI completion** |
| `paste` `merge` | any mix | **N** | `merge_file` (void) | no |
| `copy` `copy_objects` | any mix | **N** | `copy_objects` (void) | no |
| `copy_hierarchy` | any mix | **N** | — | no |
| `attach_labels` | label instances | **N** | — | no |
| `wire_cut`, `trim_wires`, break splits | wires | **1–N** | `wire_store_split` | partial |
| `load` / `open` a file | a whole schematic | **N** | bulk via funnels | no |
| **GUI gestures** (draw wire/line/rect/…) | per gesture | 1+ | the funnels | n/a — no scripted return |

Takeaways that shape the plan:

1. The return plumbing is **non-uniform** (`wire_store` hands back an index;
   `storeobject`/`place_symbol`/`create_text` hand back a success flag; `store_poly`/
   `store_arc`/`merge_file`/`copy_objects` are `void`). Threading an index out of
   each is *N* fiddly edits. **The §2 counter-diff sidesteps all of it** — which
   is the central argument for Layer A as the foundation.
2. Several first-class creates are **multi-object** (paste/copy/merge/load) — the
   capture API must return a *list*, never assume one.
3. Some creates are **GUI-completed** (`net_label`, `place_symbol`/`wire` in
   `gui` mode). Verified hazard: `xschem place_text 0 300 300` with placement
   args **hung a headless run** (had to be killed) — it started an interactive
   placement. GUI creates therefore *cannot* be captured by a scripted return;
   they need Layer C (the event stream) and tests must avoid the GUI arg forms.

## 5. How this composes with action-logging (issue 0005)

This branch already carries partial action-log infrastructure (`xschem log`,
`set_action_log_cmd`, `scheduler.c:3492/6549`). Layer C's sink is naturally the
action log: when creation tracking is on, each birth appends its handle, so a
replay can say *"recreate the object that was id 7"* and resolve it via Layer A's
`objects -created-after` or `object @id`. The same mechanism serves both "tell me
what I just made" (interactive) and "replay what was made" (the log) — one
substrate, both payoffs. Cross-reference the action-logging checklist's 0005 when
this lands.

## 6. Design decisions to ratify (present, don't pick)

These are the forks; settle them with the user before building, exactly like the
net c1/c2/c3 decision.

- **A. Return / descriptor shape.** What does a captured reference look like?
  1. bare id (`7`) — ambiguous across types, needs the type out-of-band;
  2. self-describing typed handle (`{wire 7}` or `wire:7`) — compact, but a new
     mini-grammar;
  3. the **full `object` descriptor dict** (`type wire index 0 layer 1 id 7 name
     {}`) — richest, *already the currency* of `object`/`objects`, id is a field
     read. **Recommend 3** for consistency (a capture is just an `objects` row),
     with `object <type> @id` as the round-trip resolver.
- **B. One verb or a filter?** `objects -created-after <mark>` (extend the
  existing enumerator — recommended, minimal surface) vs. a new `created <mark>`
  verb. Recommend the filter.
- **C. Mark representation.** A tuple of the 4 counters (no new state — recommend)
  vs. a single global `creation_seq` counter (scalar mark + total cross-type
  order, but either a new struct field or it can't locate objects). Recommend the
  4-counter tuple; note the global-seq option if total ordering is ever needed.
- **D. Undo/redo semantics.** Should an undo that *recreates* objects count as
  "created"? The counter-diff gives a principled default for free: **memory-undo
  restores preserve ids (not counted); disk-undo re-mints (counted).** Decide
  whether to (a) accept that, or (b) set a `restoring` guard across `pop_undo` to
  suppress Layer-C events during undo. Recommend (a) for Layer A, (b)-optional
  for Layer C.
- **E. GUI capture ergonomics.** For mouse-drawn objects: a persistent
  `on_create` Tcl callback (push model) vs. "draw, then ask `objects
  -created-after $mark_taken_before`" (pull model). Recommend offering both;
  push (Layer C) is the CIW-faithful one.
- **F. Backward-compatible rollout of Layer B.** See §7 — the one place changing
  behavior could bite external scripts. Decide: opt-in flag vs. unconditional.

## 7. Backward-compatibility audit (the one real risk)

Layer A and Layer C **add** surface; they change nothing existing → safe.

Layer B **changes the return value** of existing create commands (today: noise
like `""`/`"0"`/`"1"`). In-tree this is safe — **no `src/*.tcl` or `tests/`
caller inspects these results** (audited). The risk is *external* user scripts
doing e.g. `if {[xschem rect ...]} {...}`: today `rect`→`"0"` (false); a
descriptor dict is non-empty (true) — such a script would flip. Mitigations,
recommend the first:

1. **Make Layer B opt-in** — a global `set_creation_echo 1` toggle or a trailing
   `-handle` flag; default keeps today's return. Zero surprise.
2. Ship Layer A + C only (which already meet the north star) and treat Layer B as
   a later, separately-ratified convenience.
3. Unconditional, documented as a (minor) breaking change with a version bump.

## 8. Phased implementation (RED-first, suite green throughout)

**Phase 0 — characterize (no behavior change).** A `creation_*.tcl`
characterization suite locking *today's* return values (the §2 noise) and the
counter monotonicity (mark before N creates → counters advance by exactly N per
type; paste of a mixed selection advances several). This is the sensitivity net.

**Phase 1 — Layer A (the primitive).** RED tests: `creation_mark` then
`objects -created-after <mark>` returns exactly the objects made since, for
single creates, a paste (multi), and a load (bulk). GREEN: a `creation_mark`
command (serialize 4 counters) + the `-created-after` filter in `xschem_cmds_o`
(compare each object's `id` to the per-type mark). Sabotage: freeze a counter →
the filter under-reports → the right tests redden. *This phase alone satisfies
the north star.*

**Phase 2 — Layer C (the event stream).** RED tests: enable tracking, create via
command, assert the handle reached the sink; create via a *second* path; disable
→ silent. GREEN: a `creation_track`/`on_create` flag + a 4-line emit at each of
the four funnels (after the id stamp). Decide §6.D (undo gating) here. Sabotage:
remove one funnel's emit → that type's births go uncaptured → reddens.

**Phase 3 — Layer B (per-command return), only if ratified (§6.F).** RED tests
per create command (single → one descriptor; paste → list). GREEN: the one
shared "snapshot at entry, created-after at exit" helper wired into each create
branch, behind the §7 opt-in. Sabotage: bypass the helper in one branch → that
command stops returning a handle → reddens. Backward-compat assertion: with the
toggle off, the legacy return is unchanged.

**Phase 4 — close-out.** A `probe8.tcl` end-to-end demo (mark → mixed creates →
capture → resolve each via `object @id` → edit → re-resolve); manual
`doc/capturing_created_objects.md`; cross-refs in `object_query_api.md`,
`net_as_object.md`, and the action-logging 0005 entry; update
`step3_directions_guide.md`.

## 9. Testing strategy & known hazards

- **Run from `src/`**, log to `/tmp`, stub modals — the established harness.
- **The GUI-create hang is real** (verified: `place_text` with placement args
  blocked headless until killed). Tests must use the *coordinate* create forms,
  never the `gui`/interactive arg forms. Document which command arg-shapes are
  headless-safe.
- **Green-but-hollow discipline**: every feature test fails first; after GREEN,
  sabotage the substrate (freeze a counter / drop a funnel emit) and confirm the
  right tests redden; guard against vacuous passes (a `-created-after` over an
  empty result must assert non-empty where N>0). [[green-but-hollow]]
- **Assert exact deltas**: "mark, create 3 wires + 1 rect, expect exactly those 4
  descriptors" — not just "non-empty".
- **Multi-context**: counters are per-tab; a mark from one tab must not resolve
  against another. Add a guard test.

## 10. Effort

- **Phase 0 + 1 (Layer A):** ~1 day. This is the whole north star at low risk.
- **Phase 2 (Layer C):** ~1 day (four 4-line emits + flag + tests + undo
  decision).
- **Phase 3 (Layer B):** ~1–2 days (every create branch + compat gating + the
  arg-shape/GUI audit).
- **Phase 4:** ~half a day.

Recommend shipping **0+1 first** (complete, safe, satisfies the goal), then 2,
then 3 only if the per-command ergonomics are wanted and §6.F is settled.

## 11. Out of scope / future

- **Cross-session db_IDs.** xschem ids are session-only; only an instance *name*
  survives save/reopen (`instance_identity_decision.md`). A Cadence db_ID
  persists in the cellview. True cross-session handles would need persisted ids —
  a separate, larger decision (touches the file format, `XSCHEM_FILE_VERSION`).
  This plan delivers *session* capture, which is what "tell me what I just made"
  needs.
- **`obj~>prop` pointer-chasing syntax.** Out of reach (xschem is command/Tcl,
  not an object graph) and unnecessary — `object <type> @id` is the equivalent
  capability, one resolve step more verbose.
- **A real net registry (c3).** Net *creation* capture maps to the anchor handle
  of the wire/label created; a first-class net object is the separate c3 item.

---

*Grounding: funnels `store.c:339/534/578/608`; counters `xschem.h:964-974`,
`xinit.c:514-517`; `storeobject`→modified `store.c:332`; create dispatch in
`scheduler.c` (§4 table); current returns + the GUI-hang verified via
`/tmp/cre.tcl`; caller audit over `src/*.tcl` + `tests/`. Companion docs:
`object_query_api.md`, `net_identity_decision.md`, `step3_directions_guide.md`,
`net_as_object_coding_tutorial.md`, action-logging `doc/claude/specs/action_logging_checklist.md`
(issue 0005).*
