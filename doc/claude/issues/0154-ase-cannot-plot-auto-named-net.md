# 0154 — an auto-named net (`#netN`) cannot be picked or plotted from ASE

Status: **FIXED** (2026-07-25)
Area: `src/ase_window.tcl` (`sod_expr`, new `sod_net_at`, `sod_click`)
Tests: `tests/headless/test_ase_unnamed_net.tcl` — `AN0`–`AN15` (28 checks, new file)
Related: 0153 (trace colors / picker highlight — the constraint this fix must respect),
0151 (plot modes), hover fly-lines rule A6
Reference: `doc/claude/code_analysis/waveform_subsystem_reference.md` §8, landmine 23;
`doc/claude/specs/waveform_viewer.md`; `doc/claude/specs/hover_flylines.md` §4

## Report

> Figure out why, with `gf180mcuD/xschem_libs/gf180mcu_tests/test_nfet_TRAN/schematic/test_nfet_TRAN.sch`,
> after simulation, the `#net1` connected to V1 and XR1 cannot be plotted.
> If I select that wire segment, I get a message in CIW:
> `ase: v1 queues source currents only — click a wire, a net label or a voltage source/ammeter`

Two independent defects, stacked. The first one is what the user sees; the second
would have bitten immediately after, and harder.

## Root cause A — the picker inherited a fly-lines exclusion

`ase::ui::sod_click` resolved the net under the click with the read-only
fly-lines query:

```tcl
catch {set net [dict get [xschem flylines at $x $y] net]}
```

`flyline_compute()` (`src/flyline.c`) implements spec rule **A6, "exclude
auto-named nets"**:

```c
  /* A6: auto-named nets (get_unnamed_node -> "#netN", the node[0]=='#' marker) are unique per
   * physical cluster and can never connect implicitly -- exclude them (empty result). */
  if(netname && netname[0] == '#') netname = NULL;
  if(!(netname && netname[0])) return;   /* no net -> empty result */
```

That is **correct for fly-lines** — a `#netN` cluster is unique per physical
cluster, so there is never a second cluster to fly to and a star would be
meaningless — and **wrong for signal picking**, where `#net1` is an ordinary net
to probe. `sod_click` therefore never set `kind`, and fell through to the
"source currents only" notice.

Measured on the reported fixture:

```
flylines at 500 -440  (the #net1 wire) -> net {} global 0 capped 0 members {} clusters {} segments {}
flylines at 480 -270  (GND)            -> net {GND} ...
flylines at 420 -350  (D)              -> net {D} ...
```

Note the "just strip the `#` and ask again" idea does **not** work: the by-name
form validates against `bus_node_hash_lookup`, whose key is literally `#net1`,
so `xschem flylines net net1` is empty too. Both fly-line forms are dead ends
for auto-named nets — by design.

## Root cause B — the emitted expression named a node that does not exist

`ase::ui::sod_expr` wrapped the raw token:

```tcl
if {$kind eq {voltage}} { return "v([string tolower $token])" }
```

so a `#net1` pick would have produced `v(#net1)`. The netlister strips the
marker — the fixture's own deck says so:

```
V1 net1 GND Vds
XR1 D net1 net1 ppolyf_u_1k r_width=1e-6 r_length=1e-6
```

Against a real gf180 ngspice tran run (`.save v(net1)`, raw = `time`, `v(net1)`):

| probe | result |
|---|---|
| `xschem raw index v(net1)` | `1` |
| `xschem raw index v(#net1)` | `-1` |
| `wviewer::validate_rpn v(net1)` | `{}` (accepted) |
| `wviewer::validate_rpn v(#net1)` | `unknown token 'v(#net1)' …` |

`get_raw_index`'s fuzzy ladder (`src/save.c`: verbatim → upper → lower →
`v(<node>)` → the `i(v.x` fixup) never strips `#`, so nothing downstream
rescues it.

**Severity is higher than "no trace".** The Select-On-Design (outputs) flavor
writes the same string into the deck as `.save <expr>` / `print <expr>`
(`src/ase.tcl`). A lone `.save v(#net1)` makes ngspice-42 abort the *entire*
analysis:

```
Error: no data saved for Transient analysis; analysis not run
doAnalyses: not found
tran simulation(s) aborted
Warning from checkvalid: vector #net1 is not available or has zero length.
```

and the deck's `write` then dumps ngspice's `constants` plot as the `.raw`, so
every *other* trace in the session dies too. One bad pick poisoned the run.

## Constraint C — the two names must not be conflated

The issue-0153 color cue runs the other way. Measured:

```
xschem hilight_netname -layer 4 {#net1}  -> 1   (accepted, list_hilights shows  #net1  -4)
xschem hilight_netname -layer 4 net1     -> 0   (finds nothing, silently)
```

`ase::ui::dp_hilight` needs the **raw schematic token**; `sod_expr` needs the
**simulator name**. Both call sites are `catch`-guarded, so stripping the `#`
at the token level would have killed the color cue *silently*. `dp_queue`'s
signature already keeps the two apart (`ex` vs `token`), so no signature change
was needed — only the right value in the right slot.

## Fix

Pure Tcl in `src/ase_window.tcl`. **No C change. `src/flyline.c` untouched — A6
stands.**

1. **New `ase::ui::sod_net_at {x y hit}`** — the net under a click, as the RAW
   token. `xschem flylines at` stays the primary resolver (every named net keeps
   its shipped behavior byte for byte); when it comes back empty the helper falls
   back to `xschem nets -selected`, reading the selection `select_at` already
   made.

   The fallback is gated to **WIRE hits only**. On a device *body*
   `nets -selected` reports every net the device touches (2 for a vsource, 3 for
   a mosfet) — but a two-pin device with both pins on one net reports exactly
   **one**, so a list-length test alone would read a device-body click as a
   voltage pick and break the "non-source click queues nothing" contract
   (`test_ase_interact` I6). A wire lies on exactly one net by construction.
   `AN7b` is the fixture shape that makes this observable, and the sabotage run
   confirms it: with the gate removed, clicking the shorted resistor's body
   queues `v(short)`.

   `xschem nets -selected` is also the *cold-correct* choice: it resets the interp
   result **after** `prepare_netlist_structs`. `xschem resolved_net` does not —
   see "adjacent defects" below.

2. **`sod_expr` strips the leading `#`** — `v([string tolower [string trimleft
   $token #]])`. This mirrors `send_net_to_graph()` (`src/hilight.c`), the C path
   that sends highlighted nets to a graph: strip `#`, then lowercase.

   Deliberately a **pure string op**, not `xschem resolved_net` (what
   `send_net_to_graph` uses after its own strip). Two reasons: `sod_expr` is
   called with no design loaded (`test_ase_interact` H1 asserts its purity), and
   `xschem resolved_net` is contaminated on its first call after any
   netlist-struct invalidation. At top level — the only depth ASE runs at,
   `ase::netlist` refuses a descended schematic — the two agree byte for byte
   (verified for `#net1`, `D`, `G`, `GND`).

## Verification

- `tests/headless/test_ase_unnamed_net.tcl` — **28 checks**, new hermetic file
  (no DISPLAY, no ngspice, no ASE session). RED before the fix on `AN1`–`AN4`,
  `AN10`, `AN11`; green after.
- **Sabotage-verified**, three separate teeth:
  | sabotage | caught by |
  |---|---|
  | revert the `#` strip in `sod_expr` | `AN1`, `AN10`, `AN11` |
  | delete the `nets -selected` fallback | `AN1`–`AN4` |
  | delete the wire-only hit-type gate | `AN7b` (queues `v(short)` from a device body) |
- **Fly-lines A6 unchanged**: `sh tests/headless/test_flylines.sh` → `RESULT: ALL PASS`
  (43 rails, including the three `A6` ones). **`full_audit.sh` never runs this file**
  — it globs `test_*.tcl` and this is a `.sh`. Run it by hand after any flyline work.
  `AN9` is the ASE-side mirror of the same guard.
- Regression sweep, all green: `test_ase_interact` (63), `test_ase_plot` (145),
  `test_wave_viewer` (292), `test_wave_modes` (174), `test_graph_box_zoom_xy` (10),
  `test_ase_window` (166), `test_ase_dialogs` (133), `test_ase_dirty` (41),
  `test_ase_savestate_adopt` (26), `test_ase_view` (36), `test_ase_launch` (38),
  `test_ase_persist` (109), `test_add_wire_label` (59), `test_flylines_render`,
  and the `--nogui`-arm trio `test_ase_core` (66) / `test_ase_final` (28) /
  `test_ase_final_gf180` (33).
- **End-to-end on the reported fixture** (three clicks in Direct-Plot mode):
  ```
  QUEUE : v(net1) v(d) i(v1)
  COLORS: 4 5 7
  ECHO  : {ase: queued trace 'v(net1)'} {ase: queued trace 'v(d)'} {ase: queued trace 'i(v1)'}
  HILIGHTS: #net1 -4 | D -5 | V1 -7
  ```
- **Real ngspice chain**: netlist → gf180 typical models → `.tran 1n 200n` +
  `.save v(net1)` → `ngspice -b` runs clean → `raw list` = `time v(net1)` →
  `raw value v(net1) 0` = `3.3`.

## Not fixed (out of the reported scope) — adjacent defects found while auditing

All **VERIFIED first-hand**, all **pre-existing** and independent of this fix.

1. **`xschem resolved_net` is contaminated on its first call.** → **FIXED, issue 0155.**
   `src/scheduler.c` calls `Tcl_ResetResult(interp)` *before*
   `prepare_netlist_structs(0)`, then `Tcl_AppendResult`s the answer — and
   `prepare_netlist_structs` leaves `"0"` in the result. First call after a load:
   `xschem resolved_net D` → `0D`; second → `D`. One-line fix, and three sibling
   verbs in the same file already carry it with the literal comment
   `/* prepare_netlist_structs leaves "0" in result */`. This is why the fix above
   avoids `resolved_net`. *(0155 fixed it at the source — the reset now lives at
   the tail of prep — and found a third victim, `xschem instance_nodemap`.
   `sod_expr` still must not use `resolved_net`: it has to stay pure for
   `test_ase_interact` H1, which calls it with no design loaded.)*
2. **Same class in `xschem list_hilights`** — the first call prints the path as
   `0.` instead of `.` (reproduced with this change stashed). Cosmetic;
   field-parsing consumers like `hl_val` are unaffected. → **FIXED, issue 0155 —
   and "cosmetic" was wrong.** That holds only for the `all` form, where `0.`
   keeps the field *count* intact. The **no-arg** form appends `entry->path + 1`
   (empty at top level) directly onto the token, so the `0` glues to a **net
   name**: `xschem list_hilights` → `0OUT`. A wrong answer, not a cosmetic one.
3. **`resolved_net` truncates a bus at a global element.** → **FIXED, issue 0157.**
   The global branch uses `my_strdup2` (replaces the accumulator) where the normal
   branch uses `my_mstrcat` (appends): `xschem resolved_net {D,GND}` → `GND`,
   dropping `D`. `{GND,D}` → `GND,D` is correct, so only element order exposes it.
   *(Understated: it is not only the trailing case — **every** element resolved
   before **any** global is discarded, along with the `,` already appended for it,
   so `{A,B,GND,VCC}` → `VCC`. The global branch only ever needed to skip the
   `path2` prefix, since globals are flat; the replace looks copied from the
   function's own early return, where `rnet` really is fresh. It also reached
   netlist output through `translate()`'s `@#<pin>:resolved_net` and the waveform
   graph through `send_net_to_graph`, both of which iterate the `,`-list.)*
4. **`resolved_net` leaks `#` on non-first bus elements** → **FIXED, issue 0158.**
   The strip runs once on the whole token before `expandlabel`: `{D,#net1}` →
   `D,#net1`. *(Worse than stated: descended, the leaked `#` lands in the MIDDLE of
   the answer, behind the hierarchy prefix — `{LOC,#x}` → `X1.LOC,X1.#x`, a name no
   netlist or `.raw` contains. Fixed by stripping per element inside the loop; the
   strip stays LOOSE, not `is_auto_net_name()`, because a user `lab=#foo` was
   measured to netlist as plain `foo`. A third leak was found and NOT fixed: a
   `#`-leading value arriving from an instance attribute via `hier_attr` is never
   stripped, because the strip precedes the lookup — see 0158 for the measurement.)*
5. **Two `lab=#foo` labels on one wire crash the binary** → **FIXED, issue 0156** — and the
   shape was wrong in both directions: the crash needs *a wire whose name starts with `#` plus a
   second label*, which fires for the engine's own `#net1`+`#net2` too, while a lone `#foo` is
   harmless. A second, independent crash (out-of-bounds, `lab=#net99999999` in VHDL/Verilog
   netlisting) was found alongside. The `#` premise below is now **enforced**: `#` is reserved,
   `is_auto_net_name()` is the strict test, and `addlabel::name_ok` refuses a user-typed `#`.
   Original text: — `FATAL: signal 11`,
   reproduced. Backtrace: `set_inst_node` ← `name_attached_inst_to_net` ←
   `wirecheck` ← `name_attached_nets` ← `prepare_netlist_structs` ← `list_nets`.
   `src/netlist.c` does `atoi(node + 4)` for any `node[0]=='#'`, assuming the
   literal `#net` prefix, and `get_unnamed_node(2,…)` then indexes
   `xctx->node_mult` with no bounds/NULL check. Nothing to do with ASE, but it
   means "`#` implies auto-named" — the premise A6's comment states — is not
   actually true: a user *can* create a `#`-leading net.
6. **A BUS pick still emits an invalid single vector.** → **FIXED, issue 0159.**
   `sod_expr voltage {A[1:0]}` → `v(a[1:0])`, unchanged by this fix (`trimleft`
   only touches a leading `#`). It has the same `.save`-card hazard as root
   cause B did. The `send_net_to_graph` precedent fans out per bit; ASE does not.
   *(Two corrections from measuring ngspice-42 directly: the hazard is only
   fatal when the bad card is the ONLY `.save` — alongside any other valid save
   ngspice silently drops it and the trace just never appears — and the comma
   bus form `v(d,e)` never aborts at all. Also, both bus shapes reach the picker,
   not just the bracket one. Fixed not by fanning out silently but with a
   **Select Bus Bits** dialog: the user picks which bits and in what order.
   Legacy `v(a[1:0])` rows expand on load, bracket form only, so a user's
   `v(a,b)` differential is never rewritten.)*
7. **A `lock=true` wire is unpickable, silently.** → **FIXED, issue 0160.**
   `select_at` picks with `override_lock=0` while `flylines at` uses `1`, so
   `sod_click`'s `if {$hit eq {}} { return }` fires before any classification —
   not even the notice. *(Fixed by moving that return to the BOTTOM so an empty
   hit still gets classified, NOT by overriding the lock: `lock` is enforced only
   in `select.c` and `findnet.c`, with no check in any edit path, so selection IS
   the lock and making a locked wire selectable would make it deletable. The
   test's third sabotage is exactly that wrong fix.)*
8. **Descended picking produces an unqualified name.** → **FIXED, issue 0161.**
   `sod_expr` has never path-prefixed. Latent only: `ase::netlist` already refuses to run a
   descended schematic, but the picking mode itself has no such guard. *(Two corrections from
   measuring it: the refusal is NOT a `currsch` guard — `ase::netlist` compares
   `xschem get schname` against the design path, and descending changes `schname` to the
   child; and the fix is real hierarchy support, not a guard. The token is qualified in a new
   `ase::ui::sod_qualify` called from `sod_click`, so `sod_expr` stays the pure wrap H1
   asserts. Voltages go through `xschem resolved_net`, never a path string-prefix: a port
   resolves UP to the parent net, a dangling port stops one level up, and a global stays
   flat — measured. Currents mirror `send_current_to_graph`: `i(v.<path>.<name>)`, which is
   how ngspice-42 names a nested branch.)*

## Also worth knowing (not a defect)

After this fix, Direct Plot of `#net1` still needs the net to be **in the `.save`
set** — ngspice restricts the raw to it, and `save_all_v` defaults to 0. That is
the shipped ADE-L contract already recorded in
`doc/claude/specs/waveform_viewer.md` ("Direct Plot needs the net SAVED"): mark
it *To Be Saved* (which now writes the correct `.save v(net1)`), run, then plot.
