# 0161 — a signal picked while DESCENDED queued an unqualified name

Status: **FIXED** (2026-07-26)
Area: `src/ase_window.tcl` (new `ase::ui::sod_qualify`, one call site in `sod_click`)
Tests: `tests/headless/test_ase_hier_pick_0161.tcl` — `HP1`-`HP18b` (21 checks, new file)
Fixture: `tests/headless/fixtures/ase_hier/` (new, 5 files — a 3-level netlistable hierarchy)
Spec: `doc/claude/specs/ase_l.md`, "Select On Design v1 scope"
Reference: `doc/claude/code_analysis/waveform_subsystem_reference.md` §11 landmine 28
Related: 0154 (the audit that surfaced it — "Not fixed" item 8, the last one), 0159 (the bus
dialog this composes with), 0158/0157 (`resolved_net`, the resolver this now leans on),
0153 (the schematic colour cue), 0163 (an open `resolved_net` defect this inherits)

## Report

From the 0154 backlog, the last open item:

> **Descended picking produces an unqualified name.** `sod_expr` has never path-prefixed.
> Latent only: `ase::netlist` already refuses to run a descended schematic, but the picking
> mode itself has no such guard.

Confirmed at 6f526387. `ase::ui::sod_expr` is a pure string wrap, so a click at `currsch>0`
produced `v(mid)` where the simulator only knows `v(x1.x2.mid)`, and `i(v1)` where it knows
`i(v.x1.x2.v1)`. The expression is written verbatim into the deck as a `.save`/`print` card
(`src/ase.tcl`), so the trace silently never appears — or, when it is the only `.save` card,
ngspice-42 aborts the whole analysis (the hazard measured in 0154/0159).

"Latent" was the right call but for a shifted reason. `ase::netlist` has **no `currsch`
guard**; what refuses a descended run is its design-identity check —

```tcl
if {[file normalize [xschem get schname]] ne $path} { ... "is not the current schematic" }
```

— and descending changes `schname` to the CHILD (measured). So the pick is reachable at any
depth, the RUN is not, and the user must ascend before running. That is consistent with the
fix below: the queued name is top-relative, so it is still correct after ascending.

## What the simulator actually calls these nodes

Measured first-hand on the new fixture — `xschem netlist` → `ngspice -b`, ngspice-42:

```
Node                                   Voltage
topnet                                       1
x1.x2.mid                                    1
v9#branch                               -0.001
v.x1.x2.v1#branch                        0.001
```

`.save v(x1.x2.mid) i(v.x1.x2.v1) v(topnet)` is accepted verbatim; all three survive into the
raw. A vsource current is `v1#branch` at the top but `v.x1.x2.v1#branch` nested — the two forms
are structurally different, not just prefixed. `get_raw_index`'s `i(v.x` fixup (`src/save.c`)
is the other half of that same convention.

## Fix

Pure Tcl, `src/ase_window.tcl`. **No C change.**

**`ase::ui::sod_expr` is untouched** — it stays the pure string wrap `test_ase_interact` H1
asserts (called with no design loaded). The token arrives already qualified.

**New `ase::ui::sod_qualify {kind token}`**, called from `sod_click` per picked bit, right
before `sod_expr`. Identity when `currsch <= 0`, so every shipped top-level expression is
unchanged byte for byte.

- **voltage → `xschem resolved_net`**, deliberately not a Tcl path-prefix. A prefix would be
  wrong in four ways the C already gets right (all measured on the fixture, at depth 2):

  | pick | naive prefix | `resolved_net` | why |
  |---|---|---|---|
  | `A` (port, wired to the top) | `x1.x2.A` | `TOPNET` | ports resolve UP, they are not prefixed |
  | `B` (port, dangling one level up) | `x1.x2.B` | `x1.net1` | resolution stops where the name is made — ONE prefix level |
  | `0` (global) | `x1.x2.0` | `0` | globals are flat (the 0157 branch) |
  | `mid` (internal) | `x1.x2.mid` | `x1.x2.mid` | agree |
  | `#net1` (auto-named) | `x1.x2.#net1` | `x1.x2.net1` | per-element `#` strip (0158) |

  Called per BIT, after `sod_pick_tokens`/`bus_dialog` (0159) split a bus, so `resolved_net`'s
  comma-list arm never fires here and the bit dialog keeps working: `bus[1:0]` →
  `v(x1.x2.bus[1])`, `v(x1.x2.bus[0])`.

- **current → mirror `send_current_to_graph()`** (`src/hilight.c:1720`), which is the shipped C
  convention for the same job: `i(` + `v.` + lowercased `sch_path` + name + `)` when there is
  hierarchy, bare `i(name)` at the top. There is no `resolved_net` for instance names.

The 0153 colour cue keeps the **raw** token: `dp_queue`'s 4th argument is untouched, because
`xschem hilight_netname x1.x2.mid` finds nothing — the schematic's own name and the simulator's
name are different values and 0154 already separated the two slots.

## Verification

- `tests/headless/test_ase_hier_pick_0161.tcl` — **21 checks**, new file, passes in BOTH arms
  (`--nogui` and under `DISPLAY`). RED before the fix: **10 FAILED / 10 passed**, failing
  exactly `HP3`, `HP8`, `HP10`-`HP17`.
- New fixture `tests/headless/fixtures/ase_hier/` — top → `x1` (ase_hier_mid) → `x2`
  (ase_hier_leaf), with a named internal net (`mid`), a resolved port (`A`→`TOPNET`), a dangling
  port (`B`), an auto-named net, a bus (`bus[1:0]`), a global (`0`) and a nested vsource (`V1`).
  It netlists and simulates, which is how the ngspice names above were measured.
- **Sabotage-verified, five teeth** (each break applied with an assert-the-pattern-was-found
  patcher, never `perl -0pi` — see the 0154 trap list):

  | sabotage | caught by |
  |---|---|
  | revert: `sod_click` drops the qualification | `HP8`, `HP10`-`HP15`, `HP17` (8 legs) |
  | opposite: naive Tcl path-prefix instead of `resolved_net` | `HP8`, `HP12`, `HP13`, `HP15`, `HP16` |
  | opposite: current arm drops the ngspice `v.` branch prefix | `HP11` |
  | the 0153 colour cue gets the QUALIFIED token | `HP17` |
  | the `currsch<=0` identity guard is removed | `HP6b` |

  The last one initially passed the whole file — the guard had **no teeth** until `HP6b` was
  added. It uses a bus RANGE as the discriminator (`resolved_net` expands `a[1:0]` to
  `a[1],a[0]`, identity does not), because at the top level every other probe agrees.
  The revert sabotage was re-run in the GUI arm as well (8 FAILED there too).
- Regression, all green: `test_ase_interact`, `test_ase_plot`, `test_ase_unnamed_net`,
  `test_ase_bus_bits_0159`, `test_ase_locked_wire_pick_0160`, `test_ase_window`,
  `test_ase_dialogs`, `test_ase_persist`, `test_ase_dirty`, `test_ase_view`, `test_ase_launch`,
  `test_ase_savestate_adopt`, `test_wave_viewer`, `test_wave_modes`, and the `--nogui`-arm trio
  `test_ase_core` / `test_ase_final` / `test_ase_final_gf180`.

## Known limits (inherited, not introduced)

1. **`resolved_net` measures its path from `sch_waves_loaded()`.** An expression queued while a
   raw is loaded BELOW the top is relative to THAT raw, not to ASE's own top-level deck. ASE
   loads its raw at the top, so its own flow is consistent; a user who loads a raw at depth and
   then picks can queue a name the ASE deck will not produce. Not reachable from ASE's own UI.
   **RETIRED for the ASE path by issue 0168**: `resolved_net` now takes an explicit start
   level (`resolved_net_from`), and `sod_qualify` passes the level of the session's own
   design, so the answer no longer depends on where a raw happens to be loaded.
2. **`resolved_net` still trusts any parent instance attribute matching a child net name**
   (issue 0163, open). A child net named like an instance attribute resolves to the attribute's
   VALUE. That defect is now on the ASE pick path too — fixing 0163 fixes it here for free.
3. **The expression is a persisted ledger key** (`sod_merge`, `dp_queue`'s `lsearch -exact`,
   `result_probe`). Descended picks saved before this fix carry the unqualified name and are
   NOT migrated — they named a node that never existed, so there is nothing to preserve.
4. Not eyeballed interactively: this was driven programmatically in both arms.
