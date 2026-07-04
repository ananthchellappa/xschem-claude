# Spec — Uniform property introspection (read values + enumerate keys) for all object types

**Status:** PROPOSED (enhancement). No code yet.
**Branch:** `fluid-editing`.
**Type:** capability enhancement, driven by the ultimate goals (select-by-name / replayable,
scriptable editing) — NOT a defect. Nothing here is broken; the capability was never built.
**Origin:** split out of the original issue 0077. The memory-safety defect that was filed
alongside it is a genuine bug tracked separately at
`doc/claude/issues/0077-getprop-unchecked-index-oob-read.md`.

---

## 1. Goal

A script (or the action log, or a future select-by-property feature) should be able to, for
**any** of the seven drawable object types, given a durable handle:

1. read one attribute value by key, and
2. **enumerate the object's attribute keys** (the `get_properties_names(x)` primitive), and
3. read the whole property string.

Today only *instances* and *symbols* support (2)/(3); five types are partly or wholly opaque.

## 2. Current state (what exists, what's missing)

The property read surface (`xschem getprop …` at `src/scheduler.c:2686`, plus the
`xschem list_tokens` / `xschem get_tok` helpers):

| Type | read value by key | read whole prop string | enumerate keys (via `list_tokens`) |
|---|---|---|---|
| instance | yes | **yes** (`:2707`) | yes (feed whole string) |
| symbol | yes | **yes** (`:2776`) | yes |
| wire | yes (token required) | **no** | **no** |
| text | yes (token required) | **no** | **no** |
| rect | yes (token required) | **no** | **no** |
| line | **no arm at all** | **no** | **no** |
| poly | **no arm at all** | **no** | **no** |
| arc | **no arm at all** | **no** | **no** |

Two gaps:

- **G1 (P2)** — no whole-property-string read for `wire`/`text`/`rect`, so `list_tokens`
  (which needs a whole string) cannot be fed → key enumeration impossible for them.
- **G2 (P3)** — `getprop` has **no `line`/`poly`/`arc` arm** (`:2686-2820` arms are
  instance / instance_notcl / instance_pin / symbol / rect / text / wire): those three types'
  attributes are entirely unreadable from Tcl.

The underlying C is already there — `list_tokens(prop, 0)` (`token.c:308`) returns the key
list for ANY property string, and every object struct carries `prop_ptr`. This is missing
dispatcher surface, not missing engine capability.

## 3. Why it matters (tie to ultimate goals)

The uniform, identity-aware LOCATE surface (`xschem object`/`objects`, covering all seven
types by `@id`/`#index`/name) has no matching READ surface: a script can find and select any
object but can only inspect the properties of two of eight families. Generic tooling —
"show me the attributes of whatever is selected", property-based selection, faithful
attribute logging/replay — cannot be built for the other types until this closes. It is the
exact gap that stops the `{first_selected → get_properties_names}` pseudocode from closing in
Tcl (see `object_model_architecture_primer.md` §8).

## 4. Candidate approaches (to be decided in design)

Two directions, not mutually exclusive:

- **A — extend `getprop` per type.** Add a whole-string form (token omitted → return
  `prop_ptr`) for `wire`/`text`/`rect`, and add `line`/`poly`/`arc` arms. Smallest, most
  local; keeps the existing command shape. Downside: perpetuates per-type dispatcher code and
  the two-command dance (`getprop` then `list_tokens`).
- **B — add property enumeration to the uniform API.** A `-props` flag on
  `xschem object`/`objects` that appends `props {k v k v …}` (pairing `list_tokens` +
  `get_tok_value` over `prop_ptr`) for every type in one identity-aware call. Closes G1+G2
  uniformly and lets the `get_properties_names` primitive be one call on a handle. Larger,
  but matches where the object API is going.

Any implementation must reuse the existing bounds-check discipline (cf. issue 0077 / the
`object #index` range-check) so a new read path does not reintroduce the OOB defect.

## 5. Out of scope
- The memory-safety fix for the existing `getprop wire`/`rect` OOB read — issue 0077.
- The descriptor row-format inconsistency (D8) — separate.

## 6. Related
- `doc/claude/issues/0077-getprop-unchecked-index-oob-read.md` — the sibling bug.
- `doc/claude/code_analysis/object_model_agent_reference.md` §9 (D2/D3), §11 (extension
  recipe for a `-props` sub-dict), §5 (property model: `list_tokens`, `get_tok_value`).
- `doc/claude/code_analysis/object_model_architecture_primer.md` §8 (the blocked pseudocode).
