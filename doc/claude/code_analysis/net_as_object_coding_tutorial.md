# Building "net-as-object": a coding tutorial

*How we gave XSCHEM's nets a stable, queryable identity — and what each step
teaches about data modelling, graph algorithms, identity, caching, and testing.*

This is an **analysis-and-teaching** companion to the how-to-use manual
(`doc/net_as_object.md`). It walks the *engineering* of the feature end to end:
the domain model, the algorithm that names a net, the design decision, the code,
two real bugs, and the testing discipline. Scattered throughout are **▶ Level up**
sidebars that connect the concrete xschem code to the general computer-science
idea underneath, so you can carry the lesson to your own projects.

All line references were read out of the source on the
`feature/stable-object-handles` branch and are reproducible.

---

## Part 0 — The job, in one paragraph

XSCHEM is a schematic editor that generates SPICE/Verilog/VHDL netlists. Six
"drawable" object types (wires, instances, rectangles, …) and text already had a
**stable handle** — a session-unique id you can hold across edits. A *net* (an
electrical node — "this wire is on `VDD`") did not. The task: give a net a
durable, scriptable identity too, so a program can say "watch *this* net" and
still mean the same net after the user edits the schematic. The catch, and the
whole reason this is interesting: **a net is not stored anywhere.**

---

## Part 1 — What *is* a net? (stored vs. derived data)

Open `xschem.h` and you find arrays for everything you can draw:
`xctx->wire[]`, `xctx->inst[]`, `xctx->rect[layer][]`, … Each element is a struct
you can point at and stamp with an id.

There is **no `xctx->net[]`.** A net is not a thing the program stores; it is a
*relationship the program computes*. Specifically, a net is an **equivalence
class** of wire segments and pins that are electrically connected — and it is
recomputed from scratch every time connectivity is rebuilt. Its only identity is
a **string token** (the net name) living in a hash table:

```c
/* xschem.h:793 — the net "table" is a hash of names, not an array of nets */
struct node_hashentry {
  struct node_hashentry *next;
  unsigned int hash;
  char *token;        /* THE net name, e.g. "OUTI" — its only identity */
  char *sig_type; char *value; char *class; ...
};
```

This single fact ("a net is derived, not stored") drives every later decision.
You cannot add an `id` field to a net, because there is no net struct. You must
first decide *what a net's identity even is.*

> **▶ Level up: stored vs. derived state.** In any non-trivial system, some state
> is *authoritative* (the source of truth) and some is *derived* (computed from
> it). A wire's endpoints are authoritative; the net it belongs to is derived.
> The discipline — sometimes called *normalization* — is to keep exactly one
> source of truth and recompute or cache everything else. Bugs cluster wherever
> derived data is mistaken for authoritative (you'll see exactly this in Part 8,
> where writing a *wire's* net name silently does nothing). When you design a
> schema, ask of every field: *is this the truth, or a view of the truth?* If
> it's a view, who recomputes it, and when?

---

## Part 2 — How a name gets tied to a wire (the algorithm)

A wire has no inherent name. So where does `OUTI` come from, and how does it end
up on *every* wire segment of that net? The answer is **geometry feeding a graph
flood-fill**, and it all runs inside `prepare_netlist_structs()` (`netlist.c:1663`).

### 2.1 Origin: a label instance donates its name

A "net label" is not a primitive — it is an *instance* of a special symbol
(`lab_pin.sym`, `K {type=label}`, template `lab=`). Its `lab` attribute is the
name. The engine copies that attribute onto the instance's pin node:

```c
/* netlist.c:1442, inside name_nodes_of_pins_labels_and_propagate(),
 * gated by IS_LABEL_OR_PIN(type) at :1415 */
my_strdup(_ALLOC_ID_, &inst[i].node[0], inst[i].lab);
```

That `inst[i].node[0]` is the **seed**.

### 2.2 Seed the one wire the label physically touches

It computes the pin's coordinate, finds its spatial-hash bucket, and names the
wire the point lands on:

```c
/* netlist.c:1474 */
name_attached_nets(x0, y0, sqx, sqy, inst[i].node[0]);
```
```c
/* netlist.c:1064 — name a wire the point touches, then spread */
if(touch(wire[n].x1, wire[n].y1, wire[n].x2, wire[n].y2, x0,y0)) {
  if(!wire[n].node) {
    my_strdup(_ALLOC_ID_, &wire[n].node, node);                 /* :1074 real field */
    my_strdup(_ALLOC_ID_, &wire[n].prop_ptr,
              subst_token(wire[n].prop_ptr, "lab", wire[n].node)); /* :1075 display cache */
    err |= wirecheck(n);                                        /* :1076 SPREAD */
  } else {
    if(for_netlist>0) err |= signal_short("Net", wire[n].node, node); /* two names meet = short! */
  }
}
```

### 2.3 Spread across the whole net: a recursive flood-fill

This is the heart of it. `wirecheck(k)` — commented in the source, literally,
`/* recursive routine */` — takes a just-named wire and visits every wire that
shares an endpoint or crossing with it, copying the name and recursing:

```c
/* netlist.c:1007 wirecheck(k): DFS flood-fill over the wire connectivity graph */
touches =
  touch(wire[k]..., wire[n].x1, wire[n].y1) || touch(wire[k]..., wire[n].x2, wire[n].y2) ||
  touch(wire[n]..., wire[k].x1, wire[k].y1) || touch(wire[n]..., wire[k].x2, wire[k].y2);
if( touches ) {
  if(!wire[n].node) {
    my_strdup(_ALLOC_ID_, &wire[n].node, wire[k].node);  /* :1050 inherit the name */
    err |= name_attached_inst_to_net(n, tmpi, tmpj);     /* name pins on it too */
    err |= wirecheck(n);                                 /* :1053 recurse */
  } else {
    if(for_netlist>0) err |= signal_short("Net to net", wire[n].node, wire[k].node);
  }
}
```

Read that as a graph algorithm and it's textbook **depth-first flood fill**:
- **nodes** = wire segments (and instance pins);
- **edges** = "these two segments touch geometrically";
- **the `if(!wire[n].node)` guard** = the *visited* set (a wire with a name has
  been reached);
- **the recursion** = the DFS stack.

Starting from each label seed, the name floods outward until the whole connected
island carries it. Unlabeled nets get the same treatment with an auto-name
(`set_unnamed_net` → `#netN` → `wirecheck(i)`, `netlist.c:1497`/`:1502`).

### 2.4 The netlist just reads the result

When a backend (`spice_netlist.c`, …) emits a device, it prints
`inst[i].node[p]` for each pin — which the flood-fill already set to the net
name. *That* is why the netlist reflects your label: the label's `lab` flowed
through the geometry onto every connected pin.

> **▶ Level up: connected components, flood fill, and union-find.** "Group things
> that are transitively connected" is one of the most common shapes in all of
> computing — friend graphs, image segmentation, type unification, this. Two
> classic tools:
> 1. **Flood fill / BFS-DFS from each unvisited node** (what xschem does): start
>    a traversal, mark everything reachable, repeat for the next unmarked node.
>    Simple, and natural when you also want to *do* something at each node (here,
>    stamp the name).
> 2. **Union-Find (Disjoint Set Union)**: maintain a forest where each element
>    points at a representative; `union(a,b)` merges classes, `find(a)` returns
>    the class id, both near-O(1) amortized with path compression + union by
>    rank. Preferred when connections *arrive incrementally* and you keep asking
>    "same group?"
>
> xschem recomputes from scratch each time, so flood-fill fits. But notice: a
> net **is** a disjoint-set class. If you ever needed stable *net-level* ids that
> survive edits (option c3 in Part 4), DSU with class-matching across rebuilds is
> exactly the machinery you'd reach for. Recognizing "this is connected
> components" instantly hands you a 60-year-old toolbox.

> **▶ Level up: spatial hashing — how `touch()` isn't O(n²).** Naively, "which
> wires touch this point?" scans all *n* wires; doing that for all *n* wires is
> O(n²) and dies on big schematics. xschem buckets objects into a grid
> (`wire_spatial_table[NBOXES][NBOXES]`, filled by `hash_wires()`,
> `netlist.c:555`): each wire is filed under the grid cells its bounding box
> covers, so a lookup only examines the handful of wires in the same cell. This
> is a **uniform-grid spatial hash**, the same idea as broad-phase collision
> detection in games and physics. General lesson: when an algorithm asks
> "what's near X?" a lot, precompute a spatial index (grid, quadtree, k-d tree,
> BVH) and turn O(n) scans into O(1)-ish bucket peeks.

> **▶ Level up: recursion depth is a real resource.** `wirecheck` recurses once
> per wire in the net. A pathological net with tens of thousands of segments
> could blow the C call stack (no tail-call guarantee in C). Production graph
> code often converts deep recursion to an explicit heap-allocated stack/queue
> for exactly this reason. When you write a recursive traversal, ask: *what
> bounds the depth, and what happens at the worst case?*

---

## Part 3 — Why you can't stamp a net (identity vs. address)

The other six types got ids by stamping a counter into a struct at birth. A net
has no struct and no birth — it pops into existence as a side effect of the
flood-fill and vanishes on the next rebuild. So what can a *durable handle* to a
net even be?

First, be precise about three different ways to "name" an object:

| concept | example here | stable across edits? |
| --- | --- | --- |
| **address** | a wire's array **index** (`wire[5]`) | **No** — deleting wire 3 renumbers it |
| **handle / identity** | a wire's stamped **id** | **Yes** — monotonic, never reused |
| **human name** | the **net token** `OUTI` | **No** — a rename or rebuild changes it |

An *address* tells you *where* something is *right now*; a *handle* tells you
*which* thing it is *for all time*. Confusing the two is the single most common
source of "it worked, then I deleted something and it pointed at garbage" bugs.

> **▶ Level up: the ABA problem and why "never reuse" matters.** Suppose handles
> were array indices that get reused after a delete. You grab "wire 5", someone
> deletes it, someone else creates a new wire that lands at index 5, and now your
> handle silently refers to a *different object that looks valid*. This is the
> **ABA problem** (the slot went A→B→A and you can't tell). The cure is a value
> that is **monotonic and never reused** — xschem's id counter only ever
> increments (`++xctx->wire_id_counter`), so a freed id can never come back and
> alias a stranger. The same pattern appears as **generational indices** in ECS
> game engines (index + a generation counter bumped on free), tagged pointers,
> and database row versions. Whenever you hand out references that outlive the
> thing, make reuse impossible or detectable.

The resolution for nets: **anchor the net's identity on a stored object's
handle.** A net's durable reference is "the net that *wire-id 5* is currently
on," or "the net at *instance-id 3*'s pin `PLUS`." You hold a wire/instance id —
which is already stable — and resolving it re-runs connectivity to get the net's
*current* name and members. The net name stays the human form; the anchor is the
machine handle.

---

## Part 4 — The design decision (choosing the right invariant)

We did **not** start coding. A net's identity is a genuine design fork, so the
flow was *characterize → write a decision doc → get it ratified → then build*
(recorded in `net_identity_decision.md`). Three options were on the table:

- **c1 — canonicalize the name.** Cheap, but a net rename moves the handle. This
  *reintroduces* the very instability the whole effort exists to remove.
- **c2 — anchor on a stored handle.** Reuses the existing stable ids, invents no
  net storage, rename-safe by construction. **Chosen.**
- **c3 — a real net registry.** Stamp ids into the node table and match
  equivalence classes across rebuilds (the DSU idea from Part 2). Most powerful,
  most invasive, highest risk. Recorded as the *future* direction.

> **▶ Level up: prefer the design that makes the bad state unrepresentable.**
> c1's flaw isn't that it's slow — it's that it *can* go wrong (a rename
> silently breaks the handle). c2 is rename-safe *by construction*: it physically
> cannot drift, because the thing you hold (the anchor id) is decoupled from the
> thing that changes (the name). Whenever you choose between designs, weight
> "which one makes the failure mode impossible" far above "which one is fewer
> lines today." This is the same instinct behind strong typing, making illegal
> states unrepresentable, and immutability. The cheapest bug is the one the
> design forbids.

> **▶ Level up: write the decision down before you write the code.** A one-page
> doc that lists the options, the trade-offs, and *the one you picked and why*
> costs an hour and saves weeks. It turns "a choice nobody remembers making" into
> "a ratified decision with a paper trail," and it forces you to actually
> compare alternatives instead of building the first thing that compiles. Senior
> engineers are mostly distinguished by the decisions they *didn't* rush.

---

## Part 5 — The code (a read/resolve veneer)

Because c2 reuses existing machinery, the implementation is small and *additive*:
no new struct, no new counter, no change to the connectivity engine. Three new
commands in the `xschem` dispatcher (`scheduler.c`, `xschem_cmds_n`):

```
xschem net <selector>          -> {name {tok} nwires N npins M anchor {wire id}|{inst id pin}}
    selector: @wire <id> | @inst <id> <pin> | <token>
xschem nets [-selected]        -> list of net descriptors (deduped by token)
xschem net_members <selector>  -> {wires {<id>..} pins {{<inst-id> <pin>}..}}
```

The work splits into three tiny helpers, each with one job:

**1. Resolve a selector to the net's current name.** This is the only place the
"anchor" idea becomes code — it leans on the *existing* per-type resolvers
(`wire_index_from_id`, `inst_index_from_id`, both linear scans in `store.c`):

```c
static const char *net_selector_token(int argc, const char *argv[], int base) {
  if(!strcmp(argv[base], "@wire")) {
    int i = wire_index_from_id(strtoul(argv[base+1], NULL, 10));
    if(i < 0) return NULL;                 /* dangling anchor */
    return xctx->wire[i].node;             /* the current net name */
  } else if(!strcmp(argv[base], "@inst")) {
    int i = inst_index_from_id(strtoul(argv[base+1], NULL, 10));
    /* ... find the named pin, return inst[i].node[p] ... */
  } else {
    return argv[base];                     /* a bareword token = the human form */
  }
}
```

**2. Describe a net** (`net_emit_descriptor`): scan once for member wires and
pins, count them, and pick the anchor to report (prefer the driving label — the
net's naming *authority* — over a plain wire).

**3. Deduplicate** for the list command (`net_token_add`): a tiny grow-on-demand
set so each distinct net token is reported once.

> **▶ Level up: the central-dispatcher (command) pattern.** Every xschem feature —
> GUI menu, keybinding, test, Tcl script — funnels through *one* command,
> `xschem <subcommand> ...`, dispatched by a giant switch. That uniformity is why
> the whole tool is scriptable and the action log can record everything: there is
> exactly one door. The cost is that one door is a 7000-line function (since
> decomposed into `xschem_cmds_a`…`_o` groups). The trade-off — *one choke point,
> uniformly observable, vs. many small entry points, individually simple* — is a
> recurring architectural decision (think: a single API gateway vs. microservice
> sprawl). Neither is "right"; know which one you're choosing and why.

> **▶ Level up: read-only veneers are cheap power.** This whole feature adds *no
> new state*. It's a thin layer that reads what the engine already computes and
> presents it usefully. Such "veneers" (think database *views*, or a REST facade
> over an existing model) are disproportionately valuable: low risk (they can't
> corrupt anything), high leverage (they unlock new use cases), and easy to
> delete if wrong. When you can deliver 80% of the value as a read-only layer
> over existing truth, do that *before* you consider changing the truth.

---

## Part 6 — Two bugs (and the general lessons inside them)

Both fixes are one line. Both teach something that generalizes.

### Bug 1 — the disconnected `if`-island

The new branches were dropped in as a fresh `if(!strcmp(argv[1],"net"))`,
immediately above the existing `if(!strcmp(argv[1],"net_label"))`. The dispatch
group is a long `if / else if / … / else { *cmd_found = 0; }` chain. By starting
a *new* `if`, my block ran correctly — and then control fell into the *original*
chain, which didn't match "net", hit its final `else`, set `*cmd_found = 0`, and
the outer dispatcher *also* reported `xschem net: invalid command`. The symptom
was bizarre: **correct output, immediately followed by an error.** The fix was to
chain in with `else if`.

> **▶ Level up: control-flow structure is part of the contract.** An `if/else-if`
> ladder is a single decision *with an invariant*: exactly one arm runs. Splice a
> bare `if` into the middle and you've silently created *two* decisions — both can
> fire. The "correct output then an error" symptom is the tell. When you extend
> someone's branch ladder, dispatch table, `switch`, or chain-of-responsibility,
> you are bound by its mutual-exclusion invariant — honor it or you get
> double-execution bugs that look like ghosts.

### Bug 2 — the leftover "0" in the result register

Tcl commands return a value by writing into the interpreter's shared *result*
object. My `net @wire <freed-id>` (a dangling anchor) was supposed to return `""`.
It returned `"0"`. Why? `prepare_netlist_structs()` leaves `"0"` (its return
code, surfaced somewhere upstream) sitting in that shared result. My code, when
the anchor didn't resolve, *appended nothing* — so the stale `"0"` survived. The
fix: `Tcl_ResetResult(interp)` **after** calling `prepare_netlist_structs()` and
before deciding what to emit (the existing `resolved_net` does the same dance).

> **▶ Level up: shared mutable output and ownership.** A C/Tcl interop result, an
> HTTP response object, `errno`, a status register — these are *shared mutable
> slots*, and the bug pattern is always the same: someone *else* wrote to it, and
> your "I didn't write anything" path inherits their value. The discipline is to
> **establish a clean baseline you own** before conditionally writing (reset the
> result; zero `errno` before the call you'll check; default the response). "I
> only set it on success" is a trap when the slot isn't yours and isn't empty.

> **▶ Level up: a dangling reference must be *loud*.** Notice what the *correct*
> behavior is: a deleted anchor resolves to `""` — an honest "nothing" — never a
> different net that happens to occupy the freed slot. Returning a plausible
> wrong answer (the `"0"`, or worse, a stranger) is far more dangerous than
> returning empty, because it fails *silently*. Design lookups so that "not
> found" is unmistakable and distinct from "found something." Fail loud, fail
> early, fail in a way the caller can test.

---

## Part 7 — Testing: red, green, and *sabotage*

The feature was built test-first, in the order the commits show:

1. **Characterize (Phase A).** Before touching anything, 22 tests pin down the
   *current* net surface — including its warts (Part 8). These are a safety net
   and a written record of "how it works today."
2. **RED (Phase C).** Write the tests for the new commands *first*; run them; watch
   them fail (`xcheck` → `XFAIL`). A test you haven't seen fail is a test you
   haven't tested.
3. **GREEN.** Implement until they pass; flip `xcheck` → `check`.
4. **SABOTAGE.** Here's the part most people skip. A green bar proves the tests
   *pass*; it does **not** prove they'd *notice if the code were wrong*. So we
   deliberately broke the implementation and confirmed the right tests went red:
   - made the resolver always return a constant → **12** tests reddened (every
     one that depends on resolution, including the dangling-anchor test — proving
     it wasn't passing vacuously);
   - made the enumerator always emit a constant token → the **2** list/dedup
     tests reddened.
   Then reverted. Now we *know* both code paths are actually exercised and the
   assertions are sensitive.

> **▶ Level up: coverage is not sensitivity (a.k.a. mutation testing).** "The line
> ran" (coverage) is weaker than "a test would fail if the line were wrong"
> (sensitivity). The sabotage step is **mutation testing** done by hand: introduce
> a small fault (a *mutant*) and check that the suite *kills* it. A suite that
> stays green on a mutant has a hole exactly there. The classic trap, christened
> here *green-but-hollow*: a fluent, passing suite whose assertions could survive
> the code being deleted. Two questions retire it — **Did the changed code run?**
> (coverage) and **Would the suite notice if it ran wrong?** (sensitivity). Green
> answers neither by itself; one deliberate red answers both.

> **▶ Level up: guard against the *vacuous* pass.** One sabotage run revealed a
> test that passed for the wrong reason: it looped over a result list asserting a
> property of each element — but when the command errored, the list was *empty*,
> so the loop body never ran and the assertion was trivially true. The fix was to
> also assert the list is non-empty. Any test of the form "for each X, assert P(X)"
> is silently satisfied by zero Xs. Always pair it with "and there is at least one
> X." Empty collections are the most underestimated edge case in testing.

---

## Part 8 — Coherence: the trap this feature had to *not* fall into

The old `resolved_net` command has a famous quirk (introspection "§2c"):

```tcl
xschem select wire 5; xschem resolved_net          ;# -> ""      (COLD: wrong!)
xschem select wire 5; xschem get lastsel; xschem resolved_net  ;# -> OUTI  (after an
                                                                #  unrelated query)
```

The same query returns different answers depending on *what you ran before it*.
The cause: `resolved_net` reads a **lazily-rebuilt cache** (the selection array)
without rebuilding it first. Whether your answer is correct depends on whether
some *other* command happened to refresh the cache. That is a coherence bug, and
it's the exact disease the whole stable-handles effort exists to cure — so the
new commands had to be immune.

The cure is a stated **contract**: every net command refreshes what it reads
*before* reading it — `prepare_netlist_structs(0)` for connectivity, and
`rebuild_selected_array()` too for `nets -selected`. A *cold* call is correct.
The characterization suite proves the old trap exists (test `NC3`) and the new
suite proves the new command is free of it (test `NH5`) — the bug is *pinned on
both sides*, so a future refactor can't silently reintroduce it.

> **▶ Level up: lazy caches and the two hard problems.** "There are only two hard
> things in computer science: cache invalidation and naming things" — and this
> feature is *both* (it's literally about naming nets, built atop a cache). A lazy
> cache (compute-on-demand, reuse until invalidated) is a great performance tool
> and a correctness minefield: every reader must either (a) ensure the cache is
> fresh, or (b) accept staleness explicitly. The §2c bug is option (c) — *assume*
> it's fresh and be wrong when it isn't. The robust pattern is a **read barrier**:
> a query *never returns stale data*, because it refreshes first. Yes, that costs
> a recompute; correctness-by-default beats speed-by-accident. If profiling later
> says the recompute hurts, add a dirty flag — but keep the guarantee.

> **▶ Level up: derived data has an *owner*; don't write to the view.** A wire
> appears to have a `lab` (net name) you can set — but the connectivity engine
> *overwrites* it on every rebuild (`subst_token(... "lab" ...)`, `netlist.c:1075`).
> So `setprop wire N lab foo` looks like it works and silently reverts. The wire's
> `lab` is a *display cache of derived data*; the authority is the label
> instance. Test `NC8` pins this exact trap. The general rule from Part 1, made
> sharp: **find the single owner of every piece of derived state, and route all
> writes through the owner.** Writing to a cached copy is a no-op at best and a
> corruption at worst.

---

## Part 9 — The shape of the whole thing

Put end to end, the feature is a clean stack, each layer leaning on the one
below:

```
xschem net @wire 5                     ← user/script asks by a stable HANDLE
  └ net_selector_token                 ← resolve handle → current net NAME (token)
      └ wire_index_from_id (store.c)    ← handle → array index (Part 3: id vs address)
          └ xctx->wire[i].node          ← the name the flood-fill computed...
              └ wirecheck / name_attached_nets (netlist.c)  ← ...by DFS over geometry (Part 2)
                  └ inst[i].lab          ← ...seeded from a label's attribute (the origin)
```

The durability story is entirely in the top half: you hold a handle that *can't*
go stale (Part 3), pointed at a name that *can* (Part 2). The feature is the
adapter between the two.

---

## Exercises (to actually internalize it)

1. **Graph reframing.** Rewrite `wirecheck`'s recursion as an explicit
   worklist (stack or queue) with no recursion. What did you have to make
   explicit that the call stack was doing for free? Which version bounds memory
   better on a 50,000-segment net?
2. **Union-Find.** Sketch how you'd assign *net-level* ids that survive a rebuild
   (option c3) using Disjoint Set Union, matching old classes to new ones by
   shared members. What's your rule for "the split net is still the same net"?
   Why is there no obviously-correct answer (hint: a net cut in two)?
3. **ABA.** Construct a concrete sequence of edits where, *if* net handles were
   net names instead of anchor ids, a script would silently end up watching the
   wrong net. Then show the anchor-id version surviving the same sequence. (Test
   `NH8` is the worked answer.)
4. **Sensitivity.** Pick any one `NH` test and name the smallest code change to
   the implementation that it would *fail to catch*. If you find one, you've
   found a real gap — add an assertion that closes it.
5. **Coherence.** Add a brand-new query command that reads the selection. Write
   the *cold-call* test first and watch it fail before you add the
   `rebuild_selected_array()` barrier. You just reproduced, and then fixed, the
   §2c bug in miniature.

---

## Pointers

- Mechanism source: `netlist.c` — `prepare_netlist_structs` (`:1663`),
  `name_nodes_of_pins_labels_and_propagate` (`:1359`), `name_attached_nets`
  (`:1064`), `wirecheck` (`:1007`), `hash_wires` (`:555`).
- Feature source: `scheduler.c` `xschem_cmds_n` (`net` / `nets` / `net_members`
  + the three helpers); resolvers in `store.c`.
- Decision & tests: `net_identity_decision.md` (c1/c2/c3, why c2),
  `tests/stable_handles/net_*.tcl` (NC characterization + NH feature),
  `introspection_probes/probe7.tcl` (the round-trip demo).
- Concept companions in this folder: `identity_vs_address_tutorial.md`,
  `tcl_introspection_wire.md` (the §2c/§2d defect analysis),
  `step3_directions_guide.md` §4 (where c2 sits in the larger plan); and
  `doc/claude/suggestions/green_but_hollow_tests.md` (the sabotage discipline in full).
- How-to-use (not analysis): `doc/net_as_object.md`.
