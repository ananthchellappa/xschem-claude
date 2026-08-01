# 0155 — `prepare_netlist_structs()` leaves `"0"` in the interp result, corrupting three verbs

Status: **FIXED** (2026-07-26)
Area: `src/netlist.c` (`prepare_netlist_structs`)
Tests: `tests/headless/test_prep_result_contamination_0155.tcl` — `RC0`–`RC11` (12 checks, new file)
Related: 0154 (the audit that surfaced this — its "Not fixed" item 1 and 2), commit
c99beb26 (the earlier per-site remedy this supersedes)
Reference: `doc/claude/code_analysis/waveform_subsystem_reference.md` §9, §11 landmine 23,
§12 backlog item 0

## Report

From the 0154 audit backlog:

> `src/scheduler.c` calls `Tcl_ResetResult(interp)` *before* `prepare_netlist_structs(0)`,
> then `Tcl_AppendResult`s the answer — and prep leaves `"0"` in the result. First call
> after a load: `xschem resolved_net D` → `0D`; second → `D`.

Confirmed, and **wider than reported**: three verbs are affected, not two, and one of
them corrupts a net name rather than a cosmetic path field.

## Root cause

`prepare_netlist_structs()` (`src/netlist.c:1663`) calls `set_modify(-2)` at `:1676`.
`set_modify` recolors the Netlist / Simulate / Waves menu entries with

```c
    if(has_x && (xctx->top_path[0] == '\0' || strstr(xctx->top_path, ".x") == xctx->top_path)) {
      tclvareval("catch {", xctx->top_path, ".menubar entryconfigure Netlist -background $simulate_bg}", NULL);
```

(`src/actions.c:205-207`, and four more `catch {...}` evals at `:211/:214/:221/:226`).
Tcl's `catch` **evaluates to `"0"`**, so prep returns with `"0"` sitting in the interp
result. Any `xschem` verb that calls prep and then *appends* its answer emits a stray
leading `0`. Verbs that use `Tcl_SetResult` are immune — it *replaces* the result.

### Why it survived this long — two independent masks

1. **`has_x`.** The `catch` evals are GUI-gated, so the **`--nogui` arm never
   reproduces it**. Most of the headless suite runs there. Measured on the same script,
   same binary, at 53d2cd19:

   | | `--nogui --pipe` | `--pipe` (DISPLAY=:0) |
   |---|---|---|
   | `resolved_net D`, 1st after load | `D` | **`0D`** |
   | `list_hilights all`, 1st | `.    lD  0` | **`0.    lD  0`** |
   | `list_hilights`, 1st | `D` | **`0D`** |

   The first investigation pass reported "cannot reproduce" for exactly this reason.

2. **The cold/warm split.** Prep early-returns when `xctx->prep_hi_structs` /
   `prep_net_structs` is already set (`netlist.c:1669-1670`) and so never dirties the
   result on a warm call. Only the *first* call after a load or any struct invalidation
   is wrong — and only that one. A test that queries twice, or that runs any prep-calling
   verb first, sees nothing.

   Note `prep(0)` does **not** warm a `prep(1)` consumer: `xschem nets` sets
   `prep_hi_structs`, while `list_hilights` calls `prepare_netlist_structs(1)` and needs
   `prep_net_structs`. So `nets` then `list_hilights` is still contaminated (leg `RC7`).

## The three contaminated verbs (GUI arm, cold), measured

| verb | got | should be | what is corrupted |
|---|---|---|---|
| `xschem resolved_net OUT` | `0OUT` | `OUT` | the **net name** |
| `xschem resolved_net` (0-arg, nothing selected) | `0` | *(empty)* | a bogus non-empty answer |
| `xschem list_hilights` | `0OUT` | `OUT` | the **first net name** |
| `xschem list_hilights all` | `0.  lOUT  0` | `.  lOUT  0` | the first entry's **path** field |
| `xschem instance_nodemap V1` | `0V1 p #net1 m GND` | `V1 p #net1 m GND` | the **instance name** |

`instance_nodemap` (`scheduler.c:5599`) was **not** in the original report — the sweep
found it. It matters: the fluid regression tests read instance→net maps through it
(`share_net` in `test_fluid_rotate_body_route_0130.tcl` and four siblings). They escape
only because each one calls `xschem resolved_net 0` first, whose *side effect* warms prep.
That warm-up was written as a connectivity refresh; it was also, unknowingly, the shield.

**This corrects 0154's "Not fixed" item 2**, which called the `list_hilights` wart
"cosmetic; field-parsing consumers like `hl_val` are unaffected". True for the `all`
form — `0.` keeps the field *count* intact, so `lindex`-based parsers still work — but
the **no-arg form glues the `0` onto a net name**, and that is a wrong answer, not a
cosmetic one.

### Full sweep — every `prepare_netlist_structs` site in `scheduler.c`

| site | verb | verdict |
|---|---|---|
| 3521 | `flylines` | SAFE — resets after prep (`:3582`) |
| 5169 | `hilight_instname` | SAFE — resets after prep; no append |
| 5215 | `hilight_buried` | SAFE — `Tcl_SetResult` replaces |
| 5572 | `instance_net` | SAFE — `Tcl_SetResult` replaces |
| **5599** | **`instance_nodemap`** | **CONTAMINATED** — appends, never resets |
| 5722 | `instance_pins` | SAFE — `Tcl_SetResult` replaces |
| 5767 | `instances_to_net` | SAFE — `Tcl_SetResult` replaces |
| **5996** | **`list_hilights`** | **CONTAMINATED** — via `hilight.c:4172`, resets *before* `prep(1)` at `:4173` |
| 6938 | `net` | SAFE — c99beb26 remedy |
| 7130 | `nets` | SAFE — c99beb26 remedy |
| 7171 | `net_members` | SAFE — c99beb26 remedy |
| 8912 | `rebuild_connectivity` | SAFE — `Tcl_SetResult` replaces |
| **9260** | **`resolved_net`** | **CONTAMINATED** — resets at `:9259`, *before* prep |
| 11325 | `test` | SAFE — resets after prep; no append |

## Fix

One line in `src/netlist.c`, at the tail of `prepare_netlist_structs()`:

```c
  Tcl_ResetResult(interp);
```

**Fixed at the source, not per call site.** Both shapes are defensible:

* **Per-site** (what `doc/claude/code_analysis/waveform_subsystem_reference.md` §12
  item 0 prescribed, and what the three `/* prepare_netlist_structs leaves "0" in
  result */` siblings do) — minimal, precedented, zero reach.
* **At the source** — kills the class.

Chosen the second, because the per-site strategy has already been tried and has already
leaked: commit c99beb26 fixed `net` / `nets` / `net_members` one at a time and left
`resolved_net`, `list_hilights` and `instance_nodemap` behind. A fourth copy of the same
one-liner would not stop a fifth site appearing.

The reach is provably nil:

* Nothing in prep's chain sets a result any caller reads — `netlist.c` contains **no**
  `Tcl_SetResult` / `Tcl_AppendResult` / `Tcl_SetObjResult` at all, and the single
  `tclresult()` within six lines of any prep call in the tree (`hilight.c:2395`) reads
  the result of its *own* `tcleval("sim_is_xyce")`.
* Tcl resets the interp result before dispatching each command, so the only thing that
  can dirty a verb's result mid-body is one of its own callees — i.e. prep.
* The early returns at `:1669-1670` are left alone: a warm call never dirtied the result,
  so it must not clear it either.
* A caller that set a result *before* calling prep and expected it to survive was already
  broken (it got `"0"`); it now gets empty. Strictly less wrong, and no such caller exists.

The three existing per-site resets are left in place — now redundant, still harmless, and
they also cover any future callee that dirties the result between prep and the append.

## Verification

- `tests/headless/test_prep_result_contamination_0155.tcl` — 12 checks, new hermetic file
  (scratch fixture via `test_scratch`, symbols from the OA registry). **RED before the fix
  on `RC1`, `RC3`–`RC7`** (6 of 12), green after.
- The test asserts the *correct* values in both arms, so it is safe headless; it prints a
  `TEETH:` line saying whether the run could see the defect at all:
  ```
  --pipe            TEETH: yes -- GUI arm, has_x gate is open, legs are live   (RED: 6 FAILED)
  --nogui --pipe    TEETH: NO  -- --nogui arm, every leg passes vacuously      (ALL PASS)
  ```
  That asymmetry is itself the evidence for the `has_x` root cause.
- **Sabotage-verified.** Moving the reset from the tail to the top of prep (a plausible
  wrong fix — it clears the result *before* `set_modify` dirties it) reproduces all six
  failures. The test pins the reset's *placement*, not merely its presence.
- Controls `RC8`–`RC10` assert the three c99beb26 siblings stay clean, so a future
  regression can tell "the class came back" from "the class was never fixed".
- Regression sweep, all green after the fix: `test_ase_unnamed_net` (28),
  `test_ase_interact` (63), `test_ase_plot` (145), `test_wave_viewer` (292),
  `test_wave_modes` (174), `test_ase_window` (166), `test_ase_dialogs` (133),
  `test_ase_persist` (109), `test_add_wire_label` (59), `test_wire_split` (OVERALL: ok),
  `test_perform_action_check_unique_names`, the five `resolved_net`-warm-up fluid tests
  (`test_fluid_rotate_body_route_0130`, `..._rotate_second_drag_0132`,
  `..._bodyshove_guards_0132`, `..._ortho_second_drag_0132`, `..._ortho_ctrl1_shove_0132`),
  the `--nogui`-arm trio `test_ase_core` (66) / `test_ase_final` (28) /
  `test_ase_final_gf180` (33), and `sh tests/headless/test_flylines.sh` (ALL PASS).
- `tests/stable_handles/net_wrap.tcl`: 35 PASS / 4 FAIL — **identical before and after**
  the fix (verified by rebuilding at pristine `netlist.c`). The four
  (`NC11a`/`NC11b` `instances_to_net`, `NH10a`/`NH10b` `net_members` pin rows) are
  pre-existing and unrelated; not in this issue's scope.

## Not verified

- No end-to-end GUI eyeball. The change has no visual surface, but `set_modify(-2)`'s
  menu recolor is on the same path, so a "menu colors still update" glance is cheap
  insurance.
- The **same class outside prep** was not swept: any other function that calls
  `set_modify()` (or another `catch`-using `tclvareval`) and whose caller then *appends*
  to the result has the identical bug. Only prep's callers were audited here.
- Windows build not compiled (`XSchemWin/`); the change is one portable Tcl call.
