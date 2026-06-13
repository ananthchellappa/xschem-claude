# Querying XSCHEM from Tcl — the state of object introspection,
# told through one selected wire

Scope: the user has a schematic open, selects a wire, and wants to work with
it *from code*. What can they learn, what can they change, where does it
hurt, and how does this compare to what a Cadence user takes for granted in
SKILL. Analysis only — nothing in the build is changed.

Method: code reading of `scheduler.c` (the single Tcl↔C gateway) plus two
**empirical probe scripts run against the real binary** on
`xschem_library/examples/mos_power_ampli.sch` (91 wires, 117 instances).
Probes and their captured logs: `code_analysis/introspection_probes/`.
Every claim below marked ▸ is a captured output, not an expectation.

## 1. The architecture in one page

All scripting goes through **one Tcl command**, `xschem`, dispatched by
`scheduler()` in `scheduler.c` — ~230 subcommands (the same funnel the GUI
itself uses). There is no other door: Tcl cannot touch `xctx` directly.

The C data model (`xschem.h:453` ff.): per-window context `xctx` holds plain
**arrays** — `wire[]`, `inst[]`, `text[]`, and per-layer `rect[layer][]`,
`line[layer][]`, etc. A wire is:

```c
typedef struct {           /* xschem.h:453 */
  double x1, x2, y1, y2;
  short  end1, end2;       /* endpoint connection state */
  short  sel;
  char  *node;             /* computed net name — cache, may be NULL */
  char  *prop_ptr;         /* the attribute string, e.g. "lab=OUTI" */
  double bus;  int flags;  /* caches derived from prop_ptr */
} xWire;
```

Three things follow, and they shape everything below:

1. **An object's only identity is its array index** (plus layer for
   rect/line/poly/arc). There is no ID, no handle, no generation count.
2. **Selection is a parallel structure**: each object has a `sel` flag, and
   `sel_array[]` (`Selected {type, n, col}`) is *lazily* rebuilt from the
   flags by `rebuild_selected_array()`. Whether a query sees the current
   selection depends on whether *something* has triggered that rebuild.
3. **Several fields are derived caches** (`node`, `bus`, `flags`, and — less
   obviously — the `lab` token inside `prop_ptr` itself), owned by the
   connectivity engine, with ad-hoc invalidation flags
   (`prep_net_structs`, `prep_hash_wires`, `need_reb_sel_arr`).

## 2. The selected wire — what code can do today

The user clicks a wire. Here is every question a script can ask, with the
real answers (▸ = captured from the probe).

### 2a. "Is something selected, and what?"

| Question | Command | Probe result | Notes |
| --- | --- | --- | --- |
| how many objects selected | `xschem get lastsel` | ▸ `1` | side effect: rebuilds `sel_array` — calling this first makes *other* queries coherent |
| what is it | `xschem get first_sel` | ▸ `1 5 0` | raw C values: type bitmask (`WIRE=1, xRECT=2, LINE=4, ELEMENT=8, xTEXT=16, POLYGON=32, ARC=64`, `xschem.h:265`), index, layer. Only the *first* object |
| selected nets | `xschem selected_wire` | ▸ `{OUTI}` | returns the `lab` token of each selected wire — a *derived cache* (see 2d), not indices, not coordinates |
| general selection dump | `xschem selected_set` | ▸ *empty* | **omits wires entirely** — handles only instances, rects, texts (`scheduler.c:5589`). Lines/polys/arcs also invisible |
| selection bbox | `xschem get bbox_selected` | ▸ `1106.3 -683.7 1113.7 -656.3` | works |

So: with one wire selected there is **no single call that says "you have
wire #5, from (1110,−680) to (1110,−660), on net OUTI"**. You assemble it:
`get lastsel` (to force the rebuild) → `get first_sel` (decode `1 5 0` with
magic numbers) → `wire_coord 5` → `getprop wire 5 lab`. Four calls and a
header file to interpret them.

### 2b. "What is its geometry / attributes?"

| Question | Command | Probe result | Notes |
| --- | --- | --- | --- |
| endpoints | `xschem wire_coord 5` | ▸ `1110 -680 1110 -660` | **off-by-one: `wire_coord 0` returns empty** — guard is `n > 0` instead of `n >= 0` (`scheduler.c:7032`). Wire 0 is unreachable |
| one attribute | `xschem getprop wire 5 lab` | ▸ `OUTI` | token-by-token only |
| *all* attributes | `xschem getprop wire 5` | ▸ `ERROR: ... needs <n> <token>` | **no way to read a wire's whole attribute string.** Instances have it (`getprop instance R1` → full string); wires don't (`scheduler.c:2193`) |
| the computed net field | `getprop wire 5 node` | ▸ *empty* | `node` is a struct field, not a token — invisible to `getprop` |
| bounds checking | `getprop wire <huge>` | not probed | `n = atoi(argv[3])` is used **unchecked** against `xctx->wire[n]` (`scheduler.c:2198`) — out-of-range reads. (`setprop wire` *does* check; `select wire` does too) |

### 2c. "What net is it on?" — the coherence trap

| Step | Command | Probe result |
| --- | --- | --- |
| cold start: select wire 5, ask | `xschem select wire 5; xschem resolved_net` | ▸ *empty* |
| same, but touch the selection first | `xschem select wire 5; xschem get lastsel; xschem resolved_net` | ▸ `OUTI` |

`resolved_net` reads `sel_array[0]` without calling
`rebuild_selected_array()` first (`scheduler.c:5189`) — so **the same query
returns different answers depending on which unrelated query you happened to
run before it**. Probe 1 "worked" only because an earlier `selected_wire`
had rebuilt the array; probe 2, asking cold, got nothing. This is the
sharpest expression of the lazy-cache problem: correctness of the query API
currently depends on incidental call order.

Whole-net queries, once you have a name, are genuinely good:

| Question | Command | Probe result |
| --- | --- | --- |
| all nets in schematic | `xschem list_nets` | ▸ `{PLUS ipin} {VNN ipin} {OUT opin} ... {#net10 net}` |
| who touches net OUTI | `xschem instances_to_net OUTI` | ▸ `{ {vd} {plus} {1110} {-660} } { {vu} {minus} {1110} {-700} } ...` — instance, pin, pin coords |
| expand selection to the whole net | `xschem connected_nets` | ▸ lastsel 1 → 10; all ten report net OUTI |

### 2d. "Rename the net" — the authority trap

| Step | Command | Probe result |
| --- | --- | --- |
| set the wire's lab | `xschem setprop wire 5 lab my_probe_net` | ▸ ok, `getprop` confirms `my_probe_net` |
| ask for its net | select + `resolved_net` | ▸ *empty* (caches now stale) |
| force rebuild, ask again | `xschem rebuild_connectivity` + select + `selected_wire` | ▸ `{OUTI}` — **the rename is gone** |

The wire's `lab` token is *not user data*. The connectivity engine stamps
the computed node name into every wire's `prop_ptr` on each rebuild
(`netlist.c:1051`, `netlist.c:1075`) — that is why all 91 wires "have" a
`lab`, including auto names like `#net2`. Net names are *owned* by label /
pin instances; writing `lab` on a wire segment is silently overwritten. A
script that wants to rename a net must find and edit a **label instance**
(`setprop instance <lab_inst> lab <newname>`) — nothing in the API surface
tells you that, and `setprop wire ... lab` succeeding without effect is the
worst kind of trap. (`setprop wire` is legitimate for `bus=`, `dash=` etc.)

### 2e. "Move / delete / create it" — and the identity problem

| Action | Command | Probe result |
| --- | --- | --- |
| move | select + `xschem move_objects 10 10` | ▸ coords `1110 -680...` → `1120 -670...`; undo restores |
| delete | select + `xschem delete` | ▸ wires 91 → 90; undo restores |
| create | `xschem wire x1 y1 x2 y2 [pos] [prop] [sel]` | undo-aware, invalidates caches properly (`scheduler.c:7049`) |
| highlight | select + `xschem hilight` | ▸ works; `list_hilights` → `0OUTI`; `get bbox_hilighted` usable |
| persist | `xschem save` | standard |

But watch identity across edits:

| Step | Probe result |
| --- | --- |
| `wire_coord 6` before deleting wire 5 | ▸ `1110 -600 1110 -560` |
| delete wire 5, then `wire_coord 6` | ▸ `180 -1110 180 -1070` — **a completely different wire** |

Deletion doesn't even shift indices — the array is compacted, so index 6 now
names what used to be some other wire entirely. **Any script that holds a
wire index across any mutation (or even a connectivity rebuild, which can
merge/split segments) holds a dangling reference, silently.** This is the
single biggest obstacle to SKILL-style scripting: there is nothing a script
*can* hold on to.

### 2f. Enumeration — the only idiom is an index loop

```tcl
set nw [xschem get wires]
for {set i 0} {$i < $nw} {incr i} {
  puts "[xschem wire_coord $i] lab=[xschem getprop wire $i lab]"
}
```
▸ works (modulo wire 0's missing coords), one round-trip per attribute per
object. There is no "give me all wires with coordinates and attributes" call,
no query-by-region, no query-by-net→wires (only net→instance pins exists).

## 3. The asymmetry: instances are first-class, wires are an afterthought

The instance API is *much* richer — addressable **by name or number**, whole
prop string readable, and a real query family:

| Capability | Instance | Wire |
| --- | --- | --- |
| address by stable-ish name | yes (`R1`, `get_instance`) | no — index only |
| whole attribute string | `getprop instance R1` ▸ `name=p0 lab=PLUS` | **no** |
| symbol/master attrs | `getprop instance R1 cell::name` ▸ `ipin.sym` | n/a |
| pins | `instance_pins p0` ▸ `{{p}}` | n/a |
| pin→net | `instance_net p0 p` ▸ `PLUS` | net via `resolved_net` (fragile, 2c) |
| bbox | `instance_bbox p0` ▸ instance + symbol boxes | assemble from `wire_coord` |
| appears in `selected_set` | yes (by name) | **no** |
| coordinates | `instance_coord`, `instance_pos` | `wire_coord` (with the 0 bug) |
| **stable session handle** | **yes — `instance_id`/`instance_index`** (Phase D) | **yes — `wire_id`/`wire_index`** (step 1) |

> **Update (stable-object-handles, 2026-06-13).** The "address by stable-ish
> name" row above understated the hazard: instance names are not just
> reused-across-files but **reused within a session** (`R37`/`R25` come back
> after a delete) and **renamable**, so a held name silently aliases a
> different instance — the §2e identity problem with a name instead of an
> index. Both wires and instances now carry a session-stable numeric **id**
> (monotonic, never reused, not persisted), queryable via `wire_id`/`wire_index`
> and `instance_id`/`instance_index`, and returned in every `selection` row.
> Per the role contract (`instance_identity_decision.md`) the **id** is the
> durable machine handle and the **name** stays the human / cross-session form.

This reflects history (netlisting needed instance queries; wires only needed
to be drawn), not design intent. Texts and rects sit in between; lines,
polygons and arcs have almost nothing (create + select by (layer,index)
only). Even counts are inconsistent: `get wires/instances/rects/lines/polygons`
exist, ▸ `get texts` silently returns "" — which is also the general failure
mode: **an unknown `get` attribute returns empty string, not an error**, so
typos read as "no data".

## 4. Against the Cadence/SKILL yardstick

What a SKILL user assumes, and where xschem stands:

| SKILL concept | SKILL idiom | xschem today |
| --- | --- | --- |
| stable object handles | every db object is a first-class value you can hold, pass, store | array indices, invalidated silently by any edit (§2e) |
| uniform property access | `obj~>prop`, `obj~>??` lists *everything*, same for any object type | per-type subcommands with different addressing (name / index / layer+index), different capabilities, no "list all attrs" for most types |
| selection as data | `geGetSelSet()` → list of objects, filter/map at will | `selected_set` (omits 4 of 7 types) + `selected_wire` (labels only) + `first_sel` (first object, magic numbers); coherent only after an incidental rebuild |
| traversal | net~>terms, inst~>net, cv~>shapes — closed graph, walk anywhere | good: net→inst pins (`instances_to_net`), inst pin→net (`instance_net`); missing: net→wires, wire→instances, point/region→objects (`closest_object` is mouse-only) |
| windows/cellviews | `hiGetCurrentWindow()`, window→cellview→objects | decent: `tab_list` ▸ window paths + filenames, `get topwindow/current_win_path/schname/sch_path/currsch`; per-window contexts exist (`xctx` swap) |
| evaluation model | everything returns structured lisp data | strings with per-command ad-hoc formats: `1 5 0`, brace-wrapped names, newline-separated rows, `0OUTI` (`list_hilights`) — each needs custom parsing |
| failure model | nil / errors | mixed: some TCL_ERROR, some silent empty string, at least one unchecked array read |

The honest summary: **xschem's Tcl surface is an accumulation of commands
each added for a specific GUI or netlisting need; SKILL is a data model with
an evaluator on top.** The gap is not the number of commands (~230 is a
lot!) — it is identity, uniformity, and coherence.

What is *already good* and worth preserving: the single-funnel design (one
command, one dispatcher — trivially loggable, as the action-logging work
exploits); the net-level queries; `expandlabel`/`translate`/token utilities;
undo integration on every mutator; per-window contexts; `xschem help`
self-documentation.

## 5. Defect/hazard list (each independently verifiable)

| # | What | Where | Severity for scripting |
| --- | --- | --- | --- |
| 1 | `wire_coord 0` unreachable (`n > 0`) | `scheduler.c:7032` | bug, trivial fix |
| 2 | `getprop wire/rect` index unchecked (`atoi` straight into array) | `scheduler.c:2176,2198` | crash/garbage on bad input |
| 3 | `resolved_net` reads stale `sel_array` (no rebuild) | `scheduler.c:5189` | wrong-answer bug, call-order dependent |
| 4 | `selected_set` omits WIRE, LINE, POLYGON, ARC | `scheduler.c:5589` | API hole |
| 5 | no whole-prop read for wires (instances have it) | `scheduler.c:2193` | API hole |
| 6 | `setprop wire n lab` silently overwritten by connectivity engine | `netlist.c:1051,1075` | trap — needs doc or rejection |
| 7 | indices not stable across delete (compaction reorders) | `storeobject`/delete path | architectural — **ADDRESSED for wires** (2026-06-12) **and instances** (2026-06-13): session-stable ids via `xschem wire_id`/`wire_index` and `xschem instance_id`/`instance_index`, stamped at the store.c lifecycle funnels (`plan_stable_handles_step1.md`; instance Phase D). Memory undo round-trips ids; disk undo invalidates them loudly (deref → −1, never a stranger). For instances the id additionally cures the name-reuse/rename alias (a name is *not* a safe handle — `R37` returns after a delete; `instance_identity_decision.md`). Probes `introspection_probes/probe3.tcl` (wires) and `probe4.tcl` (instances) re-run the §2e failure side-by-side with the handle version. Other five graphical object types: pending (step 3) |
| 8 | unknown `get` attr → silent `""` | `scheduler.c:1466` ff. | typo hazard |
| 9 | no `get texts` (counts inconsistent across types) | `scheduler.c` get branch | API hole |

(1–5, 8–9 are small, additive, independently fixable; 6 needs a decision;
7 is the architectural one.)

## 6. Directions for the architecture discussion (sketch, not a plan)

Ordered from least to most invasive — all additive, nothing breaks the ~230
existing commands:

1. **Patch the potholes** — defects 1–5, 8, 9 above. Hours of work, makes
   the *existing* model dependable enough to script against.
2. **A coherence rule**: every query subcommand that consults selection or
   connectivity calls its rebuild first (one `rebuild_selected_array()` /
   `prepare_netlist_structs()` at the top of the branch — the pattern most
   branches already follow; the bugs are the stragglers). "A query never
   returns stale data" as a stated contract.
3. **A uniform read layer**, one new subcommand, e.g.
   `xschem object <type> <n> [attr]` returning a Tcl dict
   (`type wire n 5 x1 1110 y1 -680 ... net OUTI props {lab OUTI}`), same
   shape for all seven types, plus `xschem objects <type>` for bulk
   enumeration and `xschem selection` returning the full typed list. This
   alone delivers ~80 % of the SKILL ergonomics for read-only scripting and
   is pure addition.
4. **Stable handles** — the real fix for identity: a monotonically
   increasing id stamped on every object at creation (survives array
   compaction; map id→index maintained by store/delete). *Step 1 (wires)
   implemented 2026-06-12 on `feature/stable-object-handles` — see §5
   defect 7 for the surface and contract.* Then
   `xschem object @1234 ...` works across edits, selections can be saved
   and replayed, and the action log gains stable referents — note this is
   the same problem as deferred issue **0005** in the action-logging work
   (stable referents for replay): one mechanism would serve both.
5. **Net as an object**: `net OUTI wires` / `net OUTI pins` / rename-net
   (which edits the owning label instances, encapsulating the §2d trap).

The wire was a good probe: small struct, yet it surfaced every systemic
issue — identity, cache coherence, API asymmetry, derived-data authority.
Instances would have *hidden* most of these (they have names, whole-prop
reads, and a mature query family).

## Appendix — reproducing

```sh
cd src && ./xschem -q --script ../code_analysis/introspection_probes/probe.tcl
cat /tmp/wire_probe.log     # probe2.tcl / wire_probe2.log likewise
```
Captured logs from the runs cited above are checked in next to the probes.
`probe3.tcl` / `wire_probe3.log` (added with the stable-handles work) re-run
the §2e identity failure side-by-side with the `wire_id`/`wire_index` handle
version and demonstrate the memory-undo/disk-undo identity contract.
