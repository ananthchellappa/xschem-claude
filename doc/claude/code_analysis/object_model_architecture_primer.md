# XSCHEM Object Model & Identity — an Architecture Primer

*A plain-English tour of how XSCHEM stores a schematic in memory, what "identity"
means to it today, and what would have to change to (a) select objects by name and
(b) make every action loggable and replayable. Written for an interested reader who
wants to understand the software architecture and the limits it imposes — including
which limits come from the C language and where C++ might (and might not) help, given
that we intend to keep saving files as human-readable text.*

Branch analysed: `fluid-editing`. Every claim below was checked against the source and
carries file:line evidence in the companion reference document
(`object_model_agent_reference.md`). Where this primer simplifies, that document has the
exact detail.

---

## 0. The headline, up front

The original premise for this study was: *"we cannot select objects by name or make
actions replayable because we do not have stable object handles."*

**That premise is out of date for this branch.** XSCHEM already has stable object
handles. Every drawable object — every wire, instance, rectangle, line, polygon, arc,
and text — carries an `unsigned int id` that is stamped when the object is born and
stays with it for the whole editing session, even as the underlying arrays are shuffled
by deletes, inserts, re-ordering, and undo. There is already a scripting API
(`xschem object … @<id>`) that resolves an object by that id.

So the real situation is more nuanced, and more encouraging, than "no handles." The
handles exist. What is *missing* is narrower and more tractable:

1. **Names exist for only some object types.** Instances have names; nets have names;
   wires, rectangles, lines, polygons, arcs, and text do not. So "select by name where
   possible" is *already possible for instances* and is *impossible in principle* for
   the nameless types — exactly as the task anticipated.
2. **The stable id is session-only.** It is deliberately *not* written into the `.sch`
   file, so it does not survive save-and-reload. The only identity that crosses a
   save/reopen is the **name**.
3. **Action replay is coordinate-based, not identity-based.** When you click to select
   something, the log records *where you clicked*, not *what you hit*. Replaying that
   click re-runs the hit-test against whatever geometry exists at replay time.
4. **A few scripting conveniences are simply un-written** — e.g. there is no single
   command that hands a script the list of property names of a nameless object, even
   though the C function that does it already exists internally.

None of the four is a fundamental barrier. Points 1–3 are *design choices*, and point 4
is *missing dispatcher code*. The rest of this document explains the machinery well
enough that you can see why.

---

## 1. Where a schematic lives: the `xctx` global

Almost all program state hangs off one global pointer, `Xschem_ctx *xctx`. (Each open
window or tab has its own `xctx`; more on that in §9.) Inside it, the current
schematic's objects are stored as **plain C arrays of structs** — no database, no object
graph, just contiguous blocks of memory you index into.

There are eight object families, and they fall into three storage shapes:

| Family | Struct | Storage shape | Addressed as |
|---|---|---|---|
| Wire | `xWire` | one flat array `wire[]` | `wire[n]` |
| Instance (a placed symbol) | `xInstance` | one flat array `inst[]` | `inst[n]` |
| Text | `xText` | one flat array `text[]` | `text[n]` |
| Rectangle | `xRect` | **per-layer** array `rect[layer][]` | `rect[c][n]` |
| Line | `xLine` | **per-layer** array `line[layer][]` | `line[c][n]` |
| Polygon | `xPoly` | **per-layer** array `poly[layer][]` | `poly[c][n]` |
| Arc | `xArc` | **per-layer** array `arc[layer][]` | `arc[c][n]` |
| Symbol *definition* | `xSymbol` | one flat, de-duplicated array `sym[]` | `sym[n]` |

Three points matter:

- **Flat vs per-layer.** Wires, instances and text are one array each. The four
  *graphical* primitives live in one array *per drawing layer*, so you need two numbers
  to locate one — the layer `c` and the position `n`.
- **The symbol table is a dedup cache, not a per-instance thing.** When you place ten
  copies of an NMOS transistor, there is one `xSymbol` definition in `sym[]` and ten
  `xInstance`s, each of which points at the definition by an **integer index**
  (`inst.ptr`) into `sym[]`. There is *no* back-pointer from a symbol to its instances.
- **Growth is linear, not geometric.** Each array is grown on demand by reallocating in
  fixed-size chunks: the new capacity is `(1 + count/CHUNK) * CHUNK`. The chunk sizes
  differ per type (200 wires, 100 instances, 50 symbols, 100 per graphical layer). This
  is worth knowing for scalability: because the increment is a *constant* rather than a
  *doubling*, filling a very large schematic incurs O(n²) total copying as the array is
  repeatedly nudged larger. It is fine for typical designs and a real cost for huge ones.

Alongside the object arrays sit four **spatial hash tables** (a coarse grid keyed on
bounding boxes) used to make hit-testing, selection and connectivity fast. They store
*raw array indices*, which — as we are about to see — makes them derived state that must
be rebuilt whenever indices move.

---

## 2. Why a raw array index is not a durable handle

The obvious way to "remember" an object is to remember its array index. XSCHEM does this
constantly for transient work, but an index is a *positional* reference, and positions
move. An index silently starts pointing at a *different* object after any of these:

1. **Delete-compaction.** Deleting objects doesn't leave holes; the survivors are
   shifted down to close the gap, so every index above a deletion decrements.
2. **Re-ordering (`change_elem_order`).** Sending an object to front/back swaps two array
   slots — both indices now name different objects.
3. **Insert-at-position.** Inserting at position `p` shifts everything from `p` upward.
4. **Symbol-table compaction.** Removing an unused symbol definition compacts `sym[]`,
   which silently invalidates the `inst.ptr` of every instance above it (the code works
   around this by re-resolving, not by fixing up the pointers).
5. **Undo / reset.** Both undo backends and the "clear drawing" path rebuild the arrays
   wholesale.

And a saved *pointer* (`xInstance *`) is even weaker than an index: a reallocation during
array growth can move the whole block, dangling the pointer while integer indices at
least survive the move.

This is the core problem that motivated stable ids: **you cannot hold an index across an
edit and trust it.**

---

## 3. The stable-id system (this is the part that already exists)

Every drawable struct has a field `unsigned int id`. It is assigned once, at the moment
the object is created, from a monotonic counter that only ever counts up:

- There are **four independent counters / id-spaces**: one for wires, one for instances,
  one for text, and **one shared counter for all four graphical types** (rect/line/poly/
  arc share an id-space so their ids never collide with each other). An id is only
  meaningful together with its *type*.
- Ids are stamped at a small number of **birth chokepoints** — `wire_store`,
  `inst_register`, `gfx_register`, `text_register` — so there is exactly one place per
  family where identity is minted.
- `id == 0` is the "never stamped" sentinel; no live object has id 0.
- Counters are **never reset** while a context lives (not even by "clear drawing"), so an
  id is **never reused** within a session.

To go from an id back to a live object, there are linear-scan resolvers
(`wire_index_from_id`, `inst_index_from_id`, `gfx_index_from_id`, `text_index_from_id`).
They walk the array looking for the matching id and return the current index, or `-1` if
the object is gone. This is deliberately *not* a maintained hash map. The reasoning, which
the source documents explicitly, is elegant: because the id lives *inside* the struct, the
array itself is always the authoritative id→index relation. There is no separate map that
could fall out of sync during a compaction or an undo, and therefore no class of
"stale-map" bugs. The cost is O(n) per lookup, judged acceptable because lookups arrive at
human/script speed over arrays of typically a few hundred objects.

### What the stable id survives — and what it doesn't

This is the single most important table in this document, because it defines exactly how
durable "identity" is today.

| Operation | Same id afterward? | Why |
|---|---|---|
| Delete other objects (compaction) | **Yes** | id rides inside the struct; the resolver re-finds it |
| Re-order (`change_elem_order`) | **Yes** | swap moves the struct, id and all |
| Insert / paste elsewhere | **Yes** (for existing objects) | shift moves structs bodily |
| Plain move (drag) | **Yes** | fields updated in place, no re-birth |
| **In-memory undo/redo** | **Yes** | undo slot struct-copies the `.id` field |
| **Disk undo/redo** | **Yes**, via a side-channel | see below |
| **Copy / paste (the copy)** | **No** — new id | a copy is a new birth |
| **Layer change of a graphical object** | **No** — new id | implemented as delete + recreate on the new layer |
| **Save → reload (new session)** | **Not reliably** | id is not in the file; see §3.1 |

The disk-undo case is subtle and worth calling out because it shows how seriously the
codebase already takes identity. Disk undo works by *serialising* the schematic to a temp
file and reading it back — and the read re-mints fresh ids (it goes through the same birth
chokepoints). That would break every live handle. So a dedicated **side-channel**
(`Undo_ids`) snapshots the live ids just before the save and re-stamps them onto the
objects just after the reload, positionally. This exists specifically so that highlight
scopes and live `xschem object` handles survive an undo. (It was issue 0043.)

### 3.1 The one genuine identity gap: save/reload

The stable id is **deliberately not written to the `.sch`/`.sym` file** (the file-format
version stays `1.3`; adding an id token would bump it and touch every reader/writer and
the whole symbol library). On load, every object is re-created through the birth
chokepoints and gets a **fresh** id.

A precise statement of the consequence — and here even the summary needs a caveat: the
re-mint is *positional and file-ordered*. Save writes objects in array order; load stamps
ids 1, 2, 3, … in that same order. So a **pristine, unedited** save-then-reload actually
reproduces the *same* id numbers. The id only genuinely *diverges* once intervening edits
(a delete-compaction, a mid-array insert, a re-order) have made the array order differ
from the original birth order. Either way, the id is **not a dependable cross-session
handle** — it is a machine handle that is durable *within* a session and coincidental
across one.

**The only identity that reliably crosses a save/reopen is the name.**

---

## 4. Names and cross-session identity

Three roles carry a human-readable name; the rest carry none:

- **Instances** have an `instname` (e.g. `M1`, `R3`), which is really the cached value of
  the `name=` token in the instance's property string.
- **Nets** have names — but a net is not a stored object at all (see below).
- **Net-label instances** are a special case of instances whose `lab` attribute names a
  net.
- **Wires, lines, rectangles, polygons, arcs, and text have no name field whatsoever.**

Two important qualifications about instance names:

- **Uniqueness is not an invariant.** Nothing in the data model guarantees two instances
  can't share a name. Uniqueness is enforced only at *interactive* edit/place/paste time
  (by `new_prop_string`), can be switched off (`disable_unique_names`), and is *not*
  checked on file load — so a hand-edited or programmatically-built `.sch` can contain
  duplicate names until you run the on-demand reconciler (`check_unique_names`, bound to
  the `#` key).
- **Names are reusable and editable.** Delete `R37` and the auto-namer can hand `R37` to
  the next resistor; rename an instance and the old name now refers to nothing. So a name
  held across edits is *also* not perfectly safe — it is just the best cross-session
  handle available, because it is the thing the file actually stores.

**Nets deserve special mention** because they are the deepest "no stored object" case. A
net is a *derived equivalence class* — the set of wires and pins that connectivity
analysis (`prepare_netlist_structs`) decides are electrically joined. Its name is a string
token, recomputed from scratch on every rebuild, and its *true* identity is the pair
`(token, hierarchy-path)` because the same token names different nets at different levels
of the hierarchy. You can address a net by name for highlighting and queries
(`xschem hilight_netname`, `instances_to_net`). Notably, there is already a newer net API
that lets you refer to a net by a **durable anchor** — the stable id of a wire or instance
pin on it (`xschem net @wire <id>` / `@inst <id> <pin>`) — precisely so a reference can
survive the net being renamed. This is the identity pattern the rest of the system could
learn from.

The hierarchy itself is a fixed-depth stack (`CADMAXHIER = 40`). The current path
(`sch_path`) is a dot-delimited chain of the *names* of the instances you descended
through (`.x1.x3.`) — a human, cross-session-meaningful address.

---

## 5. Properties: everything is a string

XSCHEM has **no typed attribute schema**. Every object carries a single freeform string,
`prop_ptr`, of space-separated `key=value` couples, e.g.
`name=M1 model=nmos w=2u l=0.15u`. This string is exactly what gets written, verbatim
(brace-wrapped and escaped), to the text file — which is *why* the file format is so
easy to read and hand-edit.

Reading and writing go through a small hand-rolled parser in `token.c`:

- **Read one value by key:** `get_tok_value(prop, key, flags)` scans the string and
  returns the value (or `""` — never NULL). Whether the key *existed* is reported through
  a global side-channel, `xctx->tok_size` (0 = not found). Two footguns live here: the
  return value points into a **shared static buffer** that the *next* call overwrites (so
  callers must copy immediately), and existence is signalled *globally* rather than in the
  return value (so you must check `tok_size` before any other lookup clobbers it).
- **Enumerate the keys:** `list_tokens(prop, flags)` returns the space-separated list of
  just the *key names*. This is the direct equivalent of "get the property names of this
  object," and — importantly — **it is exposed to Tcl** as `xschem list_tokens`. The
  property editor dialog already uses it.
- **Write/change/delete a key:** `subst_token(prop, key, value)` is the single mutation
  primitive (an empty/NULL value deletes the key).

Symbol templates provide **defaults**: an instance that doesn't set an attribute falls
back to the value declared in its symbol's `template=`. This is a single-level string
fallback, not a general inheritance system.

The upshot for the pseudocode in the task (`get_properties_names(x)`) is in §8.

---

## 6. Selection

Selection is stored in **two parallel places**:

- The **authoritative** truth is a `sel` flag *on each object struct*. `select …`
  operations set it.
- A **derived cache**, `sel_array`, is a flat list of `Selected{type, n, col}` records —
  where `n` is the **array index** (not the stable id) and `col` is the layer. It is
  rebuilt lazily from the `sel` flags when a dirty flag says it is stale.

Because a `sel_array` entry stores a positional index, it is a *snapshot*, not a durable
handle — the same fragility as §2. In practice the code rebuilds it before use, so this
rarely bites, but it means selection is not something you can hold across edits. (There is
a separate, known subtlety that the two ways of enumerating the selection —
`xschem selection`, which reads `sel_array`, and `xschem objects -selected`, which reads
the live `sel` flags directly — can in principle diverge; the latter is the more robust
one and covers all seven types uniformly.)

What you can select today, and how:

- **By name:** instances only (`xschem select instance <name>`).
- **By index:** any type (`xschem select wire <n>`, `xschem select rect <layer> <n>`, …).
- **By coordinate:** `xschem select_at <x> <y> [add]` — the replayable form of a mouse
  click; it hit-tests the nearest object.
- **Individual instance pins** can be selected as a transient, inert overlay (they never
  participate in edits and are never saved) — the groundwork for wire-stub features.

There is **no select-by-stable-id command.** The `@<id>` selector exists only on the
read-only `xschem object` *query*; you cannot yet say "select the object whose id is 42."
That is a missing convenience, not a missing capability — the resolver is right there.

---

## 7. The query API and action logging

**Query API.** `xschem object <type> <selector>` resolves *one* object by `@<id>` (stable
handle), `#<index>` / `#<layer>,<index>` (position), or a bare name (instances only), and
returns a small descriptor dict `{type index layer id name}`. `xschem objects` enumerates
all objects with `-type`, `-selected`, and `-layer` filters. This is a clean, uniform,
identity-aware surface — but it is **address-only**: the descriptor carries no properties,
so reading attributes is a second call.

**Action logging.** XSCHEM writes a per-session *replayable Tcl log*: every logged line is
an `xschem …` command, and replaying the session is `source Xschem.log`. View and global
actions (pan, zoom-box, netlist, load) replay perfectly because they don't depend on
object identity. Coordinate edit gestures (draw a wire, place a symbol, move the
selection by a delta) replay by re-running against current geometry. Interactive
click-select is logged as `xschem select_at x y` (with an ` add` marker for shift-click).

**The replay gap is identity.** `select_at` records *the click point*, and on replay it
re-runs the nearest-object hit-test. If the schematic changed between record and replay,
the same coordinate resolves to whatever is now closest — or misses. Likewise
`setprop wire n` / `text n` / `rect layer n` log by *array index*, so replaying them
against an edited schematic can hit the wrong object; only `setprop instance <name>` is
identity-stable. And because the stable id is not persisted, it cannot be used as a replay
referent across a fresh reload anyway. So the log is faithful *within an unchanged
session* and drifts once geometry or ordering diverges.

Descend/return gestures are a separate story: some of them aren't logged at all, partly
because they ride a legacy key-handling path that bypasses logging and partly because
"descend into the selected instance" has no stable referent to reconstruct (issue 0005,
FAQ Q24).

---

## 8. The task's pseudocode, answered concretely

> `x = first_element_of_selected_set`
> `get_properties_names(x)`

**In C: fully possible today.** `xctx->sel_array[0]` (after a rebuild) or a scan of the
`.sel` flags gives you the first selected object; every object has a `prop_ptr`; and
`list_tokens(prop_ptr, 0)` *is* `get_properties_names`. Roughly five lines.

**From a Tcl script: possible today for instances and symbols; not yet for the other five
types.** The chain is:

```tcl
set first  [lindex [xschem objects -selected] 0]   ;# a {type index layer id name} dict
set props  [xschem getprop instance [dict get $first name]]   ;# whole property string
set keys   [xschem list_tokens $props 0]           ;# the property names — this works
```

The final step (`list_tokens`) is exposed and works. The *gap* is the middle step:
`xschem getprop` returns a *whole* property string only for **instance** and **symbol**.
For wire/text/rect it demands a specific token, and for line/poly/arc there is no
`getprop` branch at all. So if the first selected object is a wire (say), a Tcl script has
no way to fetch its whole property string, and therefore cannot feed `list_tokens`.

This is the perfect illustration of the whole report's theme: the capability exists in C
and is trivial; the only thing missing is a few lines of dispatcher code to expose a
whole-property read (or a `props` field on the descriptor) for the nameless types.

---

## 9. A note on multiple windows

Each open window/tab has its **own** `xctx`, with its **own** id counters. The same
numeric id therefore exists independently in every window and is meaningless without
knowing which context it belongs to. Replay and scripting that target "the current
context" implicitly, and any future cross-window handle scheme, must account for this.

---

## 10. What would have to change to fully meet the two goals

### Goal A — "select objects by name where possible"

- **Instances: already done.** `xschem select instance <name>` works.
- **Nets: mostly there.** Selection-by-net-name exists for highlighting; a
  `select`-by-net could reuse the net API.
- **The nameless types (wire/rect/line/poly/arc/text) cannot be named** without either
  (i) accepting that they are selected by *id* or *coordinate* instead, or (ii) adding an
  optional user-facing name attribute to their property string (which the freeform prop
  model already permits — it would just be another token). The cleanest step is to add
  **`xschem select <type> @<id>`** so the durable id becomes a first-class *selection*
  key, not just a query key. That is a small, additive change and immediately makes
  "select the object I'm holding a handle to" work for every type.

### Goal B — "make all actions loggable and replayable"

Two layers:

1. **Identity-based replay within a session.** Change the interactive gestures to log the
   **stable id** of what they touched instead of (or in addition to) the coordinate — e.g.
   `xschem select @<type> <id>` — and add the matching `select`/`setprop`-by-id commands.
   The resolver infrastructure already exists; this is mostly plumbing plus deciding the
   log grammar. It makes replay robust against geometry changes *within a session*.
2. **Identity-based replay across a reload.** This is the one that touches the file
   format, and it is a genuine decision, not free plumbing. Options: (a) **persist a
   stable id token** into the `.sch`/`.sym` record (bump `XSCHEM_FILE_VERSION`, update the
   readers/writers, and re-key the whole library) — clean but broad; or (b) resolve replay
   references by a **deterministic content+position hash** at replay time — no format
   change, but fragile when identical objects sit at the same point. Given the requirement
   to keep files as text, (a) is a small textual addition and is the more robust path;
   (b) is the zero-format-change fallback.

Neither goal requires abandoning anything that exists; both build on the id system that is
already in place.

---

## 11. C, C++, and the text file format

A recurring question is whether these limits come from writing the engine in C, and
whether C++ would help — with the hard constraint that files stay human-readable text.

**First, a clarifying fact that resolves most of the question:** the on-disk text format
is produced and consumed by `save.c` using ordinary `fprintf`/`fputs` over record
strings, and it is **completely decoupled** from the in-memory data structures. You can
change the entire in-memory representation — containers, ownership, typing — and emit
byte-identical files. So *the file format never forces any in-memory design decision, in
either language.* Persisting a stable id, or adopting a typed attribute model, is a
choice about what tokens you write, not about C vs C++.

With that established, here is a balanced view.

**Limits that are genuinely inherent to C** (C++ would remove the boilerplate, though
often at a cost noted below):

- **No destructors / RAII.** Each object owns several heap fields (`prop_ptr`, `node`,
  `name`, polygon point arrays, …) that must be freed by hand at *every* death and reset
  site, with the same free-list duplicated across the delete door and the reset door.
  Forget one and it leaks. A C++ destructor would delete this entire class of bug. This is
  the single most real C++ win.
- **No `std::string`.** All the property/name/node strings are raw `char*` juggled with
  `my_strdup`/`my_realloc`/`my_free` and manual buffer growth — including the shared
  static-buffer footgun in §5. `std::string` erases that dance.
- **No reflection.** Typed attribute access is impossible without the hand-written
  character scanner. (Though note: C++ has no real reflection either, pre-C++26 — you'd
  hand-write a schema table, which is equally doable in C.)
- **Allocation tracking by placeholder.** Leak attribution relies on an out-of-band awk
  pass rewriting ~2700 `_ALLOC_ID_` placeholders into call-site ids — a workaround for C
  lacking allocation instrumentation.

**Limits that are *design choices*, not language limits** (fixable in C, unchanged by
C++):

- Index-based addressing and index-based selection records.
- The stable id being session-only / not persisted.
- Freeform, schema-less `key=value` properties.
- The O(n) linear-scan id→index resolvers — the source *documents* this as a deliberate
  "the array is the authority, no side-map to go stale" decision. And C already ships a
  general hash map (`Int_hashtable`, used in ~57 places), so an O(1) id→index cache needs
  **no** language change; the authors simply judged the map's coherence risk not worth it.

**Where C++ would *not* help much:**

- **id→index speed.** A `std::unordered_map` would be O(1), but the same map is available
  in C today, and the real obstacle the authors cite is *coherence under compaction/undo*,
  which a map (in either language) reintroduces. No unique C++ win.
- **Heterogeneous object types.** The seven types already live in separate, statically
  typed arrays dispatched by a type tag. There is no heterogeneous container for
  `std::variant`/polymorphism to unify, so that C++ feature buys little here.

**And the important catch on the one real win (RAII):** the exact structs that would
benefit from destructors are the ones the undo and compaction machinery **shallow-copies**
(`inst[i] = inst[j]`) and even `memcpy`s wholesale. A C++ member with non-trivial copy
semantics (a `std::string` or `std::vector`) would silently change what those bitwise
copies mean and corrupt ownership. So adopting RAII is *not* a drop-in — it forces
reworking the undo model at the same time.

**Costs and risks of a C++ migration** (all real, given this codebase): the existing
source is *not valid C++* — it uses `new`, `template`, `class`, and even a global function
named `delete` as ordinary identifiers, and relies throughout on C's implicit
`void*`→`T*` conversion; the entire feature surface funnels through one Tcl C-callback
with ~1200 `Tcl_*` API references that would need `extern "C"` boundaries; the
bison/flex-generated parsers are C and marked "do not hand-edit"; the memcpy-based undo
assumes trivially-copyable structs; and C89 with a single dual-platform (Unix + Windows)
toolchain is a stated project convention. A full conversion is a high-surface, high-risk
mechanical edit across ~40 files and ~74k lines whose one clean payoff (RAII) is entangled
with the undo model.

**Verdict.** The limitations that actually block the two goals are **design and
file-format choices, all addressable in C** without touching the text format. C++ would
tidy ownership and strings and is fully *compatible* with keeping the text format — but it
does not unlock any capability that is impossible today, its best win collides with the
undo model, and its migration cost on this particular codebase is large. The high-value,
low-risk path is targeted C work: expose the missing dispatcher branches, add
`select`/`setprop`-by-id, optionally persist a stable id token, and (if desired) introduce
a static attribute-schema table for typing while keeping the freeform text on disk.

---

## 12. One-page summary

- **Storage:** eight families of plain C structs in arrays off a global `xctx`; three flat,
  four per-layer, plus a de-duplicated symbol table. Arrays grow in fixed linear chunks.
- **Index fragility:** array indices move under delete/reorder/insert/undo — not durable.
- **Stable handles already exist:** every drawable has a session-stable `id`; a query API
  resolves it. It survives edits and both undo backends; it does **not** survive
  copy, layer-change, or (reliably) save/reload.
- **Names:** instances and nets have them; the five nameless graphical/wire/text types do
  not. Instance-name uniqueness is enforced only interactively, not on load.
- **Properties:** freeform `key=value` text, no schema; keys are enumerable
  (`list_tokens`, exposed to Tcl).
- **Selection:** a live `sel` flag per object plus a derived, index-based `sel_array`;
  select-by-name is instances-only; there is no select-by-id yet.
- **Replay:** coordinate-based; robust within an unchanged session, drifts otherwise;
  no cross-reload identity because ids aren't persisted.
- **The pseudocode works today** for instances/symbols end-to-end from Tcl, and in C for
  everything; the only gap is a whole-property read for the nameless types.
- **C vs C++:** the blocking limits are design/format choices fixable in C; the file
  format is orthogonal to the in-memory model; C++'s one real win (RAII) is entangled with
  the memcpy-based undo, and migration cost is high. Recommend targeted C changes.

*For exact function names, file:line anchors, command grammars, the defect list, and
step-by-step extension recipes, see `object_model_agent_reference.md` in this directory.*
