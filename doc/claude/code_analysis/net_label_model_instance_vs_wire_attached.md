# Net labels as instances — what XSCHEM does, what Cadence does, and whether it should change

Written 2026-08-05. Branch `open_pdk`.
Scope: how a net acquires a name in XSCHEM, how that compares to Cadence Virtuoso,
what the instance-based representation costs and buys, and what a wire-attached
name would actually take in this codebase.

Prompted by the observation:

> Currently, to place a wire-label, one places (effectively) a component from a
> library that has a pin. This is not how it is on Cadence.

Short answer: **the observation is correct in substance, imprecise in four ways,
and points at the wrong layer for a fix.** The defects that actually hurt are
policy and feedback failures, not representation failures. They are spun out as
issues 0230–0236 (listed at the end).

---

## 1. What happens today

`l` → `xschem add_wire_label -place` → `place_wire_label()` (`src/actions.c:2484`),
which does exactly one thing:

```c
src/actions.c:2493-2499
    place_symbol(-1, find_file_first("lab_pin.sym"), mousex_snap, mousey_snap,
                 0, 0, "name=l1 lab=<name>", …);
```

The result is an ordinary row in `xctx->inst[]`, serialized as an ordinary
component record:

```
xschem_library/examples/TwoStageAmp.sch:199
C {lab_pin.sym} 430 -650 0 0 {name=l16 sig_type=std_logic lab=Vcoll1}
```

The symbol carries a real `PINLAYER` rectangle —

```
xschem_library/devices/lab_pin.sym:30
B 5 -1.25 -1.25 1.25 1.25 {name=p dir=in}
```

— and the name reaches the net **only because that 2.5 × 2.5 box geometrically
coincides with copper**. So: a component, from a library, that has a pin.
Literally that.

---

## 2. Where the framing is imprecise

### 2.1 The Cadence comparison does not hold for hierarchy ports

This is the biggest imprecision. In Virtuoso, `basic/ipin`, `basic/opin` and
`basic/iopin` **are** instantiated cellviews — real `oaInst`s. XSCHEM's
`ipin.sym` / `opin.sym` / `iopin.sym` (`type=ipin`, `template="name=p1 lab=xxx"`,
`B 5 … {name=p dir=out}` at `ipin.sym:23/26/33`) reproduce that model exactly.

The divergence is confined to **pure net names** — `lab_pin`, `lab_wire`, `gnd`,
`vdd`, i.e. `type=label`. Cadence's wire name is a display object bound to a net;
it creates no instance and no terminal. XSCHEM's is an instance.

Any argument phrased as "XSCHEM uses instances where Cadence doesn't" is half
true. It applies to net names, not to ports.

### 2.2 A label instance is not quite a plain device either

There is no `xLabel` type — correct. But `xInstance` carries two fields that
exist only for labels and pins:

```c
src/xschem.h:905   char *lab;
src/xschem.h:193   #define PIN_OR_LABEL …
```

Both are populated behind an `IS_LABEL_SH_OR_PIN(type)` gate in
`set_inst_flags()` (`src/actions.c:993-997`) and `link_symbols_to_instances()`
(`src/save.c:3694-3699`). A resistor whose prop_ptr literally contains `lab=foo`
never gets `.lab` filled, and the netlister reads `inst[i].lab`, not the raw
property (`src/netlist.c:1491`).

So the record is uniform on disk; the in-memory object is not.

### 2.3 The *interaction* on this branch is already Cadence-shaped

`l` is bound to the registry action `edit.add_wire_label` (`src/callback.c:5021`),
which only runs `addlabel::open` (`src/scheduler.c:1881`) — a modeless,
**name-first** form with a multi-name placement queue (`src/xschem.tcl:11391-11440`).
The form then arms placement with `xschem add_wire_label -place`
(`src/xschem.tcl:11349`) → `place_wire_label()`, and the drop is **refused unless
the pin lands on copper** — `point_on_wire_or_pin()` (`src/check.c:188-201`) via
`wire_label_try_commit()` (`src/callback.c:2769`).

The old "drop an `xxx` label, then open the property dialog" flow survives on
Alt+Shift+L → `place_net_label(0)` (`src/actions.c:2429`, NULL props so the symbol
template's `lab=xxx` stands), on the port keys Ctrl+P / Ctrl+Shift+P, and on the
Symbol menu entries. **The UX gap is much smaller than the data-model gap.** See
issue 0233 for the residue.

### 2.4 Wire records already look Cadence-like on disk — and that is a trap

```
xschem_library/examples/TwoStageAmp.sch:30
N 430 -650 430 -600 {lab=Vcoll1}
```

3877 such records exist in the shipped library. It is pure **output**: written by
`subst_token` at `src/netlist.c:1093`, `:1117` and `set_unnamed_net()` `:1588`,
and never read back as user intent. The wire property dialog renders it as a
disabled entry and re-emits it byte-for-byte (`src/property_form.tcl:139-145`,
`:183`).

Anyone reading the file format would reasonably conclude that wires can be named.
They cannot. This matters for anyone scripting `.sch` generation.

---

## 3. What the instance model costs

**Object count.** 2153 of 6599 `C {...}` records in `xschem_library` are net-label
symbols — **33 % of all instances in the shipped corpus are labels**
(`TwoStageAmp.sch`: 20 of 57). Each is a full `xInstance` (`src/xschem.h:854-912`)
with a `node[]` array, a symbol bbox, and entries in both `inst_spatial_table` and
`instpin_spatial_table` (`src/netlist.c:1664-1667`).

This is a **measured corpus count, not a measured cost**. Nobody profiled redraw,
hash, bbox or netlist time against it. Do not claim a speedup from removing label
instances.

**Zero-tolerance geometry.** `touch()` is an exact **double** collinearity test —

```c
src/clip.c:234-245
    ((x2-x1)*(ya-y1) == (y2-y1)*(xa-x1))
```

— and the drop coordinate is `mousex_snap`. Precisely: an **axis-aligned** wire
off the snap lattice is unreachable from a snapped drop (`xschem wire 0 5 100 5`
→ `net_at 50 5` = 1, `net_at 50 0` = 0, and no snapped drop can produce y=5). An
*oblique* off-grid wire can still be hit at exact lattice crossings —
`xschem wire 5 5 105 105` then `net_at 10 10` returns 1. Do not write "off-grid
wires cannot be hit"; it is false as stated. (Issue 0233.)

**Failure when the label misses is quiet, though not unreported.** The name is
discarded and the wire falls through to `set_unnamed_net()` → `#netN`
(`src/netlist.c:1581-1593`), with no ERC and no netlist diagnostic. Two things do
catch it, neither on the netlist path: the Add-Wire-Label form refuses the drop
outright, and `select_dangling_nets()`'s third pass (`src/select.c:431-471`) finds
a label touching nothing — but that command has no menu entry, no button and no
key binding, so it reaches scripting users only. (Issues 0233, 0239.)

**A missing `.sym` rewrites the netlist without an ERC.** `match_symbol()` never
returns -1 (`src/token.c:201`); `load_sym_def()` substitutes
`systemlib/missing.sym` (`src/save.c:4683`), whose `type=missing` fails
`IS_LABEL_OR_PIN` at `src/netlist.c:1457` *and* whose lack of any `B` record
leaves `inst[i].node` NULL — so the instance stops naming anything, and the "no
type attribute set" ERC at `:1450` cannot fire because `"missing"` is a non-empty
type. Be precise about "silent": stderr does carry
`l_s_d(): Symbol not found: …` and the canvas draws a loud
`---MISSING SYMBOL---` box. What is missing is the ERC layer and any trace in the
simulator-facing netlist beyond a comment. Measured: two resistors that shared a
named net land on different nets. (Issue 0232.)

**Orientation is manual.** `place_wire_label()` and `place_net_label()` both
hard-code `rot=0, flip=0` (`src/actions.c:2429-2447`, `:2499`), so the name always
reads leftward from the attachment point. Auto-orientation exists —
`lab_orient()` (`src/actions.c:1387`) — but it is `static` and called only from
`add_pin_stubs` (`:1442`). (Issue 0233.)

**Move/edit duality.** `move.c` special-cases `type=="label"` in roughly a dozen
places with "labels have no body" guards — the label is simultaneously
not-a-device for body/collision purposes and is-a-device for net-identity
purposes. The concrete cost is that a label is never carried by the follow set:
`select_attached_nets()` (`src/select.c:1738-1853`) adds **only wires**, an
invariant documented at `src/callback.c:5827` and relied on by the rigid-group
rotate/flip pivot logic. Connectivity is rescued instead by
`connect_by_kissing()`, which samples only wire *endpoints* — so a label tapping
a span interior is stranded and the net silently reverts to `#netN`. Measured on
stock defaults. (Issues 0237, 0238.)

> Correction worth recording: `src/move.c:6246-6271` is **not** a label
> re-inclusion pass. It is block (3b) of `fluid_ml_hazards()` (`:6161`), the P2
> elbow-orientation hazard scorer; it skips *selected* instances by design and
> detects a merge, not a stranding. `doc/claude/WIRING.md` open risks 5
> (`:477-480`) and 6 (`:481-483`) are adjacent but do not cover the
> {pin-on-span, stationary, rigid-translation} cell.

**Netlist skip special-cases in five backends.** spice/spectre/tEDAx skip
`!IS_LABEL_OR_PIN` (`src/spice_netlist.c:211`), verilog/vhdl skip the wider
`!IS_LABEL_SH_OR_PIN` (`src/verilog_netlist.c:52`, `src/vhdl_netlist.c:77`). The
two differ on `scope`, `show_label` and `bus_tap` — but only `bus_tap` ships
format strings, so it is the only one observable: 19 `tap:` comment lines in the
`.spice` and `.tdx` of `test_bus_tap.sch`, **0** in the `.v` and `.vhdl`, despite
the symbol declaring `verilog_format=` and `vhdl_format=`. Two things that look
like defects and are not: `IS_PIN` is a distinct, correct concept (hierarchy
ports only), and `src/netlist.c:1460`'s `strcmp(type,"label")` is a
label-vs-port *discriminator* inside the `IS_LABEL_OR_PIN` branch, not a fourth
skip test. (Issue 0234.)

**Conflict resolution is by file record order.** Naming is first-writer-wins on a
NULL check (`src/netlist.c:1091`, `:1115`) inside a plain ascending
`for(i=0;i<instances;++i)` (`:1427`). There is no port-beats-label rule: with a
`lab_pin lab=AAA` listed before an `ipin lab=BBB`, the emitted `.subckt` declares
port `BBB` in its header and connects it to nothing in the body. Swapping the two
`C {...}` lines flips the result. The short *is* reported on a default
hierarchical netlist (from a second post-descent pass), but not on `-nohier` or
the Shift-N current-level netlist, and the highlight branch is unreachable dead
code. (Issues 0231, 0230.)

**Redraw mutates the document.** `src/draw.c:9695` calls `auto_set_wire_bus()` per
visible wire per repaint, which runs `prepare_netlist_structs(0)`, rewrites
prop_ptr and calls `set_modify(1)` with no `push_undo()` — a pan or zoom dirties
the buffer and fires an autosave. The preference defaults **off**
(`src/xschem.tcl:15734`) and the mutation fires only when a wire's bus-ness
flips, so this is the smaller half. The unconditional half needs no preference
and no netlisting: `prepare_netlist_structs()` back-annotates `lab=` into wire
prop_ptr (`src/netlist.c:1093`, `:1117`, `:1588`) without touching the modify
flag, so merely highlighting one net produces a 39-record save diff on
`cmos_example.sch` while `xschem get modified` stays 0 — and the `#netN` names in
it renumber on any topology change. (Issues 0236, 0235.)

---

## 4. What it buys — the honest case

This section exists because the costs above make the model look worse than it is.

**One object model, one code path.** Labels get undo, clipboard/paste,
move/rotate/flip/copy, bbox, both spatial hashes, the property dialog, `[...]`
embedding, tabs, LCC-as-symbol and hierarchy traversal **for free, with zero
label-specific code**. Every one of those would need a bespoke implementation for
a wire-attached name.

**Users author labels without touching C.** `grep -rl 'type=label' --include=*.sym`
returns **64 files**, not the six in `devices/` — including
`xschem_library/xschem_simulator/{giant_label,giant_label2,segment}.sym` and ~40
in `gschem_import/`. `segment.sym:29` even puts its label pin at (0,40), off the
symbol origin. That extensibility is real and free.

**The attribute machinery comes free, and is load-bearing.** `gnd.sym` and
`vdd.sym` are `type=label` plus `global=ground` / `global=true` (`gnd.sym:25`,
`vdd.sym:25`), routed through `record_global_node()` (`src/netlist.c:1543-1553`).
Global nets need no new object kind — Altium needs a Power Port primitive and
KiCad needs a power symbol to do the same job. `lab_generic.sym` carries `value=`,
consumed by `name_generics()` (`src/netlist.c:897-900`). Per-label `sig_type`,
`verilog_type`, `text_size_0` and the `*_ignore` tokens all work with no schema
change.

**Naming and ports are genuinely unified.** One loop at
`src/netlist.c:1427-1565` handles labels and ports; the only structural
difference is

```c
src/netlist.c:1460
    if(strcmp(type,"label")) { port=1; … }
```

Change one string in a `.sym` and a net name becomes a port. Cadence needs two
entirely separate mechanisms — net-owned display object vs. instantiated cellview
— to express the same two ideas. This is a design virtue, not an accident.

**The netlister already walks instance pins.** Labels ride
`name_attached_nets()` / `name_attached_inst()` (`src/netlist.c:1106-1127`) with
no separate traversal.

**File-format stability.** `XSCHEM_FILE_VERSION` is still `"1.3"`
(`src/xschem.h:27`). Because everything is either an instance or a token inside a
`{...}` string, the format has absorbed decades of features without a break, and
`.sch` files stay text-diffable, git-mergeable and script-generable — which is
precisely why XSCHEM works in open-PDK flows where an OA database does not.
Cadence's model has the inverse cost: a label cannot be authored independently of
extraction, so you cannot express intent the database has not yet validated.

---

## 5. What a Cadence-style wire-attached name would take here

The key finding is that **no file-format change is required**. The `N` record
already persists an arbitrary prop string (`src/save.c:2696`, read at `:2887`),
`wire_store_split()` already inherits `prop_ptr` into the new segment
(`src/store.c:400-402`), and in-memory undo already deep-copies it
(`src/in_memory_undo.c:428-431`, `:580-583`). Storage is free. Everything
expensive is elsewhere.

| Area | Work | Size |
|---|---|---|
| `xWire` / storage | No new struct field. New token in `prop_ptr` — but it **cannot be `lab=`** (claimed as netlister output, `netlist.c:1093/1117/1588`) or `name=` (claimed by the generic object-name facility, `select.c:1267`, `move.c:656`). Needs e.g. `netname=`. | **small** |
| `save.c` + `XSCHEM_FILE_VERSION` | None. Unknown tokens are ignored by `get_tok_value`; unknown records fall to `read_record()` (`save.c:3268-3271`). No version bump. | **small** |
| Undo / clipboard | Free — prop_ptr already deep-copied. | **small** |
| `netlist.c` / `node_hash.c` | New seeding pass reading `netname=` into `wire[].node` before the label loop at `netlist.c:1427`, plus an explicit precedence policy (today: first-writer-wins by array index). Bus expansion is free — `bus_node_hash_lookup()` takes a string (`node_hash.c:123-163`). Must define short semantics and fix issue 0230 first. | **medium** |
| `draw.c` / `svgdraw.c` / `psprint.c` | Wires have **no text path at all** today (`draw.c:9680-9714` draws lines and junction dots only). Needs a placement rule relative to the segment, font metrics, cairo/Xlib duplication, three exporters, hidden-text and zoom handling — and critically, a wire's redraw bbox is currently its segment, so every incremental-invalidate site would under-invalidate. | **medium-large** |
| `select.c` / `findnet.c` | `find_closest_wire` is distance-to-segment; the glyph sits outside it. Cheapest: the name is not separately pickable. Proper: sub-object selection, for which precedents exist (`xPoly.selected_point`, `xInstance.pin_sel`). | **medium** |
| `move.c` / fluid engine | **The real cost.** Per `doc/claude/WIRING.md:137, 311-323`, the fluid engine already uses prop_ptr `lab=` as its per-wire net-identity snapshot and its "explicit label" gate (`move.c:2694`, `:2858-2870`, `:3443-3451`). A second, *authoritative* name source doubles that state space. Split: both halves inherit the name, but a later prune must not delete the sole carrier — the hazard already open at `WIRING.md:613-622`. Merge: `merge_collinear_wires` keys on byte-equal prop_ptr (`check.c:809`), so same-named segments weld and the name's *position* is lost. Trim, `break_wires_at_pins` and every de-shorter gate need re-derivation. | **large** |
| Backward compat | Reading old files is fine; both mechanisms coexist. The problem is *permanent duality* — 2153 label instances in the shipped library alone, forever a second way to name a net, with `sym_vs_sch_pins`, hilight, the fluid engine and five backends all needing to understand both. | **medium, ongoing** |

**And it does not buy the unification.** Ports must stay instances — Cadence keeps
them as instances too. So this adds a *third* naming mechanism alongside label
instances and port instances. That, more than any single line item, is the
argument against.

---

## 6. Middle path — Cadence *feel*, no format change

Everything below fits inside the instance model, with no `XSCHEM_FILE_VERSION`
change and no new object type. Ranked by value / cost. Each is an issue.

1. **Close the silent-failure holes** (issues 0232, 0233) — small, best ratio. A
   label that names nothing should say so.
2. **Fix the short detector** (issue 0230) — small, independent of everything
   else, and an outright bug on the `-nohier` / Shift-N paths.
3. **Auto-orient on drop** (issue 0233) — small. `lab_orient()` already exists at
   `src/actions.c:1387`; un-static it and call it from `wire_label_try_commit()`,
   where the wire under the cursor is already known.
4. **Snap tolerance on drop** (issue 0233) — small-medium. Search a small radius
   and move the label's pin onto the nearest wire, turning "drop failed, no idea
   why" into "it snapped".
5. **Keep the label attached when the wire moves** (issues 0237, 0238) — medium,
   the only genuinely hard piece. Two one-file fixes: extend
   `connect_by_kissing()`'s endpoint sweep (`src/actions.c:2110-2121`) to the span
   interior so a mid-span label gets the same rescue stub the endpoint case
   already gets, and arm `connect_by_kissing` on the two keyboard stretch paths
   (`src/callback.c:6445`, `:6466`) that currently do not.
   **Do not** teach `select_attached_nets()` to add the label instance — that
   breaks the follow-set-adds-only-wires invariant documented at
   `src/callback.c:5827`. Read `WIRING.md` §7 landmines first.

Together these deliver the three things a Cadence user actually notices — type the
name first, it lands on the wire, it reads the right way, it stays attached —
without a format change, without a third naming mechanism, and without opening the
fluid engine's state space.

---

## 7. Recommendation

**Do not change the data model.** The instance representation is not the defect;
it is a coherent design that buys uniformity, extensibility and format stability,
and it matches Cadence exactly where Cadence itself uses instances (ports).

Every symptom that actually hurts — labels that miss the wire with no ERC, labels
that read backwards, labels stranded by a wire move, conflicting names resolved by
file record order, a missing `.sym` rewriting the netlist — is a **policy and
feedback** failure. All are fixable in place.

Ship the outright bugs first (0230, 0232, 0235), then the ergonomics (0233), then
0237 + 0238 with a headless regression. 0231 needs a naming-policy decision before
any code. Revisit a wire-attached name only if users still report the model leaking
after that — and note that even then it would be an *addition*, not a replacement,
because ports stay instances.

---

## 8. Issues spun out of this analysis

All ten were verified against source before filing; each doc records what was
measured, what was refuted, and what is not claimed. Every candidate came back
**partly wrong** on first reading — the docs carry the corrections, so read them
rather than this summary if you are about to touch the code.

| # | one line | severity |
|---|---|---|
| **0230** | `signal_short()` silent on `-nohier` / Shift-N; its highlight branch is unreachable dead code | wrong output on one path + dead code |
| **0231** | a net's name is decided by file record order; a hierarchy port loses to a plain label and its `.subckt` port connects to nothing | wrong output |
| **0232** | a label symbol missing from the library path silently stops naming its net; no ERC fires | wrong output |
| **0233** | `place_net_label()` (Alt+Shift+L, Symbol menu, `xschem net_label`) commits a label off copper; the Add-Wire-Label form refuses | misleading UI |
| **0234** | `bus_tap`'s `verilog_format`/`vhdl_format` unreachable; every label symbol's `format=` is dead in all five backends | dead code |
| **0235** | netlist/highlight back-annotates `lab=` into wire records without setting modified; `#netN` renumbers into save diffs | silent data churn |
| **0236** | `auto_set_wire_bus()` runs from `draw()`, so pan/zoom modifies the document with no undo (opt-in preference) | silent mutation |
| **0237** | a net label tapping a wire's span interior is stranded by a translation; net silently becomes `#netN` | silent data loss |
| **0238** | the keyboard stretch paths never arm kissing, so even an *endpoint* label is stranded | silent data loss |
| **0239** | `select_dangling_nets()` doc contradicts the code about pins, ignores connect-by-name, and its second pass skips `skip_instance()` | doc + minor |

0237 and 0238 are fluid-engine adjacent; per `MEMORY.md` another agent owns that
area, so both docs cite by issue number rather than quoting current `move.c` text.

---

## 9. What this analysis does *not* establish

- **The entire Cadence side is domain recall, not verified against an install.**
  Specifically unconfirmed: the existence and values of a "Scope" widget and a
  "Show Wire Name" checkbox on the Add Wire Name form; the option labels for
  detached/offset placement mode; the exact OpenAccess enum and the SKILL creation
  function; the exact wording of the shorted-net and floating-label check messages.
  "Two names on one connected net is a short" is *likely*, not certain. Do not
  write any of it into a spec without checking an IC6.1.8 / ICADV install.
- **Whether a Cadence wire name creates the `oaNet` eagerly at placement or only
  at Check&Save** — not established.
- **Performance.** The 33 % label-instance share is a corpus count; the cost of it
  was never profiled.
- **User impact of the axis-aligned off-lattice case** (issue 0233) — the geometry
  is measured, but no evidence anyone has hit it in practice.
- **Whether `scope` / `show_label` divergence between the backends matters** — with
  the shipped library it is latent, because neither carries a `format=`. It would
  surface only for a user-authored symbol of those types (issue 0234).
- `src/netlist.c:1536-1541` (a label-name fallback to the symbol template) is
  inside `#if 0`. It is **dead**, and it looks live in a casual grep.

Claims that were **overturned** during verification, recorded so they are not
resurrected: `signal_short()` does fire on a default hierarchical netlist;
`select_dangling_nets()`'s label exclusion is the command's documented
specification, not an oversight, and a label touching nothing *is* reported by its
third pass; `src/move.c:6246-6271` is a hazard scorer, not a label re-inclusion
pass; `IS_PIN` is not a redundant macro; `auto_set_wire_bus` is off by default.
