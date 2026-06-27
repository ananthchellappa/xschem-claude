# Task — direction (c): net-as-object

Execute **direction (c) "net-as-object"** of the stable-object-handles effort:
give *nets* a queryable, stable identity in the same spirit as the seven
drawable types already have, so scripts can hold a durable reference to "this
net" across edits and read its membership uniformly.

Branch: `feature/stable-object-handles` (verify with `git branch --show-current`).

**This is the hardest and most open item on the menu, and it is RESEARCH- and
DECISION-first, not implementation-first.** Steps 1–3 (wires, instances, the
four graphical types, text) are DONE — all seven *drawable* types carry
session-stable ids. A net is different in kind, and the whole point of this file
is to hand you the context so you don't re-discover it.

---

## 0. The one fact that changes everything

**A net is not stored. There is no `xctx->net[]` array, no slot, no struct to
stamp an id onto.** A net is a *derived equivalence class* of electrically
connected wires and pins, recomputed from scratch every time connectivity is
rebuilt. Its identity today is a **string token** (the net name) living in a
hash table. So the wire/instance/text recipe — "add an `id` field, stamp it at
the birth funnel, scan the array to resolve" — **does not transfer.** You must
first decide *what a net's identity even is*, then build to that decision.

This means **do not start by writing C.** Start by characterizing the current
net surface, then write a decision doc, then get the user to ratify the identity
model, *then* implement. Exactly like the instance Phase D flow
(`doc/claude/code_analysis/instance_identity_decision.md` → user ratified "both" → built).

---

## 1. The net-label investigation (already done — load-bearing findings)

This was investigated in the prior session; internalize it before designing.

- **A "net label" is not a primitive object — it is an `xInstance` of a special
  symbol.** Label symbols (`xschem_library/devices/lab_pin.sym`, `lab_wire.sym`,
  `lab_generic.sym`) carry `K {type=label ...}` and a template `lab=xxx`. You
  place one as an instance; its `lab` attribute names the net.
- **Net names originate at label/pin instances and propagate to wires by
  geometry.** A label/pin instance's `lab` becomes `inst[i].node[0]`
  (`netlist.c:1415`, gated by `IS_LABEL_OR_PIN`, macro at `xschem.h:384`). Then
  `name_attached_nets()` (`netlist.c:1064`) walks the wire spatial hash and, for
  every wire the point touches, sets `wire[n].node = <name>` (the wire's derived
  net name) and *caches* it into the wire's `lab` property token.
- **A wire's own `lab` is a write-only cache, never read as a name source** (this
  is introspection **defect #6** — "setprop wire lab silently overwritten"). The
  connectivity engine owns `wire[].node`.
- **`xText` is pure annotation** — no pin, no connectivity, ignored by the
  netlister. (It now has a stable id like every drawable type, but that id has
  nothing to do with nets.)
- **Net identity is really `(token, hierarchy_path)`** — two different nets at
  different hierarchy levels can share a token; the highlight table
  (`hilight_table`, keyed by token + `sch_path`) reflects this.

**Conclusion that should drive the design:** the user-facing, durable handle for
a net is most naturally **a stored-object handle** — the wire or label-instance
that sits on it — because those now have stable ids, while the net name itself
is derived and reusable (just like an instance *name* was, which is why step 2
chose a numeric id as the durable handle and kept the name as the human form).

---

## 2. The identity design space — present these, recommend (c2)

Write a decision doc (`doc/claude/code_analysis/net_identity_decision.md`, mirroring
`instance_identity_decision.md`) laying out the options, recommend one, and
**STOP for the user to ratify before implementing.**

- **(c1) canonical name.** Treat the net's stable identity as a canonicalized
  form of its token (e.g. the lexicographically-least equivalent label in a
  hierarchy), exposed via `net_*` bridges over `(token, path)`. *Cheap, but
  does not survive a rename or auto-rename — the same weakness names had for
  instances. Reintroduces the reuse hazard.*
- **(c2) anchor identity on a stored-object handle (RECOMMENDED).** A net's
  durable handle *is* the stable id of a wire or label-instance on it: "the net
  that wire-id 5 is currently on," or "the net at instance-id 3's pin PLUS."
  Resolution runs the current connectivity and returns the net's present token +
  membership. Reuses the step-1/2 ids directly, invents no net storage, and is
  rename-safe (you hold the *anchor*, not the name). The token stays the human /
  cross-session form. **This is the clean parallel to the instance id-vs-name
  contract and the least-invasive, lowest-coherence-risk path.**
- **(c3) a real net registry.** Stamp ids into the `node_table` and carry them
  across rebuilds by matching old/new equivalence classes. Most powerful (a true
  net object), most invasive, highest coherence risk — it lives right next to
  the connectivity engine and the §2c stale-data traps. *Probably over-reach for
  a first cut; note it as the future direction if (c2) proves limiting.*

**Recommendation to write up:** ship **(c2)** — a read/resolve surface where a
net is addressed by a stored-object handle and described uniformly, with the
token as the human form. It composes with the `xschem object`/`objects` API
already built. Get the user to confirm before building.

---

## 3. Recommended deliverable shape under (c2) — for when ratified

Mirror the uniform `object` API (`doc/object_query_api.md`). Sketch (refine with
the user):

```
xschem net <selector>
    selector:  @wire <id>            the net wire-id <id> is on
               @inst <id> <pin>      the net at instance-id <id>'s named pin
               <token>               by current net name (human form; may alias)
    -> a descriptor dict:
       {name <token> nwires <n> npins <m> anchor {wire <id>} ...}

xschem nets [-selected]
    -> a Tcl LIST of net descriptors (one per distinct net, deduped by token+path)

xschem net_members <selector>
    -> {wires {<id> <id> ...} pins {{<inst-id> <pin>} ...}}   membership by handle
```

The handle a script *stores* is the **anchor** (`{wire <id>}` or
`{inst <id> <pin>}`); resolving it re-runs connectivity and yields the net's
current token + members. That is the whole durability story — anchors are
step-1/2 ids, which are already stable.

Keep it **read-only** (like `object`/`objects`). Net *renaming* (editing the
owning label instance) and net *creation* are out of scope for the first cut —
note them as follow-ons.

---

## 4. Code map (references verified this session)

| what | where |
| --- | --- |
| net token table (`token`, `sig_type`, …) | `struct node_hashentry`, `xschem.h:793` (`xctx->node_table[]`) |
| a wire's derived net name | `xWire.node` (set in `name_attached_nets`, `netlist.c:1073`) |
| a pin's net name | `inst[i].node[]` (per pin) |
| name origin (label/pin → node) | `netlist.c:1415`, `IS_LABEL_OR_PIN` (`xschem.h:384`) |
| propagation to wires | `name_attached_nets()`, `netlist.c:1064` |
| **the connectivity rebuild** | `prepare_netlist_structs(0)` — **call this at the top of every net query** (sets up `wire[].node`, `inst[].node`, `node_table`). Flag `xctx->prep_net_structs` |
| existing net queries to characterize | `hilight` (`scheduler.c:2523`), `instance_net` (`:2848`), `instances_to_net` (`:3040`), `hilight_netname` (`:2589`), `resolved_net` (`:5532`), `unhilight` (`:7358`), `get bbox_hilighted` (`:1521`) |
| the §2c coherence trap (avoid it!) | `resolved_net` reads `sel_array[0]` and now calls `prepare_netlist_structs(0)` first — see `tcl_introspection_wire.md` §2c, defect #3. **Your net commands MUST `prepare_netlist_structs(0)` (and `rebuild_selected_array()` if they consult selection) before reading any `.node`** |
| the uniform read API to compose with | `xschem object`/`objects`, `scheduler.c` `xschem_cmds_o`, `doc/object_query_api.md` |
| step-1/2 resolvers you'll anchor on | `wire_index_from_id`, `inst_index_from_id` (`store.c`) |

---

## 5. The recipe for THIS step (adapted — design-first)

1. **Phase 0 — read.** This file; `doc/claude/code_analysis/tcl_introspection_wire.md` §2c/§2d/§3/§6;
   `doc/claude/code_analysis/step3_directions_guide.md` §4 (the (c) analysis); the
   net-label findings above; `doc/claude/suggestions/green_but_hollow_tests.md`.
2. **Phase A — characterize the CURRENT net surface.** A `net_*.tcl` suite
   (mirror `tests/stable_handles/object_*.tcl`) that locks today's behavior of
   `instances_to_net`, `instance_net`, `hilight`/`bbox_hilighted`,
   `resolved_net` — including the coherence quirk (cold-start staleness). This is
   your sensitivity net for the new work and documents the baseline.
3. **Phase B — the decision doc.** `doc/claude/code_analysis/net_identity_decision.md`
   (c1/c2/c3, recommend c2). **Present to the user. STOP. Do not implement until
   ratified** — exactly as the instance Phase D decision was ratified first.
4. **Phase C+ — implement the ratified design, RED-first.** Add the new `net*`
   commands; tests committed failing first (`xcheck`), flipped to `check` after
   the C lands; sabotage-verify that the tests reach the live path.
5. **Phase E — close out.** A `probe7.tcl` re-running the §2c scenario
   side-by-side with the handle version (hold a wire-id, edit, re-resolve the
   net); update the docs (`object_query_api.md` cross-ref, introspection §2c/§5,
   the directions guide); present what's left (action-logging 0005, or the c3
   registry if c2 proved limiting). Write a `doc/` manual if the surface warrants.

---

## 6. Hard-won testing rules (each cost real debugging time — follow exactly)

- **Run the binary from `src/`.** `cd src && timeout -s KILL 120 ./xschem -q
  --script ../tests/stable_handles/<suite>_wrap.tcl`. The cwd persists between
  shell calls and `./xschem` only exists in `src/` — a stale log from a failed
  run is the #1 time-waster. After ANY C change: `make -C src -j8` from the repo
  root, OR `make -j8` from `src/` — never `make -C src` while already in `src/`.
- **Net queries need `prepare_netlist_structs(0)` first** (the §2c trap). In Tcl,
  touch connectivity before asserting: a "cold" `resolved_net` returns empty
  until the structs are built. Your new commands must build them in C; your
  tests should still prove it (assert a cold call works).
- **Stub modals** at the top of every body file (copy the block from
  `object_body.tcl`: `tk_messageBox`, `tk_getOpenFile`, `alert_`).
- **Fixtures:** build a small known schematic with `clear force schematic` +
  `wire`/`instance`/label placements, or use
  `xschem_library/examples/mos_power_ampli.sch` (117 instances, real nets like
  `OUTI`). `xschem set modified 0` before every load. Edits on /tmp copies only.
- **Green-but-hollow discipline** (`doc/claude/suggestions/green_but_hollow_tests.md`):
  every new test FAILS before the C lands (`xcheck` → XFAIL); after GREEN,
  *sabotage* the implementation (e.g. make the resolver return a constant/empty)
  and confirm the right tests go red, then revert. A green bar proves nothing
  until you've watched it fail for the right reason. The `-2` "invalid command"
  sentinel in the wrapper procs can make a test spuriously pass (both sides
  `-2`); guard id/handle assertions with `> 0` like the gfx/text suites did.
- **`xschem get texts` does NOT exist; `get arcs <n>` does NOT exist.** There may
  be similar gaps for nets — count/enumerate via the new commands or a saveas,
  not via assumed `get` subcommands.
- **Commit per phase** with the established style: `test(handles): …` (RED),
  `feat(handles): …` (GREEN), `docs(handles): …` (decision/E). Keep commits
  additive; the ~230 existing commands must stay green throughout.

---

## 7. Where the effort stands (context for the recap)

- **STEP 1 wires, STEP 2 instances, STEP 3 graphical (rect/line/poly/arc) + text
  — ALL DONE.** Every drawable type carries a session-stable id. The uniform
  `xschem objects`/`object` read/resolve API is shipped and fully id-bearing.
- Suites (run all, must stay green): `tests/stable_handles/wrap.tcl` (wire 58),
  `inst_wrap.tcl` (48), `gfx_wrap.tcl` (54), `text_wrap.tcl` (14),
  `object_wrap.tcl` (18); plus `tests/file_open_dialog/wrap.tcl` (33).
- Key docs to build on: `doc/object_query_api.md`, `doc/stable_*_handles.md`,
  `doc/handles_cookbook.md`; `doc/claude/code_analysis/step3_directions_guide.md` (§4 = the
  (c) analysis), `doc/claude/code_analysis/tcl_introspection_wire.md` (§2c/§2d defects),
  `doc/claude/code_analysis/graphical_lifecycle_census.md` (the census method),
  `doc/claude/code_analysis/identity_vs_address_tutorial.md` (the concept), and the
  `introspection_probes/probe[3-6].tcl` precedents.

**Do not implement net commands before the user ratifies the identity model
(Phase B). Present the decision, recommend (c2), and stop.**
