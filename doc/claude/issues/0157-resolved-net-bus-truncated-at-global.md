# 0157 — `resolved_net()` truncates a bus at a global element

Status: **FIXED** (2026-07-26)
Area: `src/hilight.c` (`resolved_net`)
Tests: `tests/headless/test_resolved_net_bus_global_0157.tcl` — `RB0`-`RB16` (19 checks, new file)
Related: 0154 (the audit that surfaced it — "Not fixed" item 3), 0155 (same function, different
defect), 0158 (the other half of the same audit line: the `#` strip in the same function)

## Report

From the 0154 backlog:

> **`resolved_net` truncates a bus at a global element.** The global branch uses `my_strdup2`
> (replaces the accumulator) where the normal branch uses `my_mstrcat` (appends):
> `xschem resolved_net {D,GND}` → `GND`, dropping `D`. `{GND,D}` → `GND,D` is correct, so only
> element order exposes it.

Reproduced first-hand at 14d02a0c in **both** arms (`--nogui` and `--pipe` with `DISPLAY=:0`;
the report predates 0155, so this is not the contamination bug wearing a different hat):

```
{D,GND}       -> GND        (expected D,GND)
{GND,D}       -> GND,D      (correct)
{D,GND,E}     -> GND,E      (expected D,GND,E)
{A,B,GND,VCC} -> VCC        (expected A,B,GND,VCC — three elements lost)
```

The report understated it in one way: it is not only the trailing-global case. **Every** element
resolved before *any* global is discarded, so a 4-element bus with a global in the last position
returns a **single** name. The count of `,`-separated items in the answer therefore no longer
matches `mult`, which is what the consumers iterate on.

## Root cause

`resolved_net()` (`src/hilight.c:2580`) expands a possibly-bussed name with `expandlabel`, then
walks the hierarchy once per bus element, accumulating into `rnet`:

```c
    for(k = 0; k < mult; k++) {
      ...                                   /* resolve this element -> local `resolved_net` */
      if(record_global_node(3, NULL, resolved_net)) {
        my_strdup2(_ALLOC_ID_, &rnet, resolved_net);            /* :2654 REPLACES rnet */
      } else {
        my_mstrcat(_ALLOC_ID_, &rnet, path2, resolved_net, NULL); /* :2656 APPENDS to rnet */
      }
      if(k < mult - 1) my_strcat(_ALLOC_ID_, &rnet, ",");
    }
```

`my_strdup2(id, &dest, src)` (`src/util.c:718`) reallocs `*dest` and `memcpy`s `src` over it —
it **replaces**. `my_mstrcat(id, &str, ...)` (`src/util.c:768`) starts from `strlen(*str)` and
appends (allocating if `*str == NULL`) — it **appends**.

The global branch exists for a real reason: a global net is **flat**, so it must not receive the
`path2` hierarchy prefix. But skipping the prefix is all it needed to do; using `my_strdup2`
additionally threw away everything accumulated so far, *including the `,` already appended by the
previous iteration*. The shape looks like it was copied from the function's own early return at
`:2586`, where `rnet` is genuinely fresh (`NULL`) and a replace is correct.

## Fix

One statement (`src/hilight.c:2653`): append without the prefix instead of replacing.

```c
      if(record_global_node(3, NULL, resolved_net)) {
        /* a global net is flat: append it WITHOUT the path2 hierarchy prefix. Must
         * APPEND -- my_strdup2() here REPLACED the accumulator, so any global at
         * k>0 discarded every bus element resolved before it (issue 0157). */
        my_mstrcat(_ALLOC_ID_, &rnet, resolved_net, NULL);
      } else {
        my_mstrcat(_ALLOC_ID_, &rnet, path2, resolved_net, NULL);
      }
```

The early-return branch at `:2586` is **not** touched: there `rnet` is `NULL` and the whole net is
the global, so `my_strdup` is right.

### Why not "just always `my_mstrcat(&rnet, path2, ...)`"

Because that is the *other* bug. Globals are flat by definition — `record_global_node` is exactly
the "this name has no hierarchy" predicate — so prefixing `GND` with `X1.` inside a subcircuit
produces a net name no netlist or `.raw` contains. The sabotage run below confirms the test file
catches that direction too.

## Blast radius (who was getting a truncated bus)

`resolved_net()` has five callers; all of them treat the answer as a `,`-list:

| site | consumer | effect of the truncation |
|---|---|---|
| `src/hilight.c:1595` | `send_net_to_graph` — `count_items(fqnet, ",")` then `find_nth` per bit, feeding the waveform graph | a bus containing a global plotted only the tail elements |
| `src/token.c:4253` | `translate()`'s `@#<pin>:resolved_net` attribute | a truncated net name reaches **netlist output** |
| `src/token.c:4224`, `:4718` | `@spice_get_voltage` | **not** affected — both are guarded by `multip == 1`, i.e. scalar nets only |
| `src/scheduler.c:9254` | the `xschem resolved_net` Tcl verb | the reported symptom |

The Tcl-side consumers in the tree (`tests/headless/wireedit/predicates.tcl`, the `test_fluid_*`
files) call `xschem resolved_net 0` for its **side effect only** (it runs
`prepare_netlist_structs`) and ignore the return value, so none of them depended on the old
behavior. `src/ase_window.tcl` deliberately does not call it at all (`sod_expr` must stay pure —
see 0154/0155).

## Test

`tests/headless/test_resolved_net_bus_global_0157.tcl`, 19 checks, teeth in **both** arms (nothing
here is `has_x`-gated, unlike 0155).

Fixture, written into `test_scratch`: a parent with a subcircuit `X1` whose pin `A` is wired to a
plain net `TOP`, two `devices/gnd` instances (`lab=GND`, `lab=VSS` — `global=ground` registers
both as globals when prep runs), and a `lab_pin` carrying the bus label `"D,GND"` so `translate()`
has a bussed pin; a child with the port `A`, a purely local net `LOC` (no port ⇒ keeps the `X1.`
prefix) and `GND`.

> Fixture trap: the parent wire must land on the pin **rect centre** (`-20,0` for `X1` at the
> origin, from `B 5 -22.5 -2.5 -17.5 2.5`). The first draft ended it at `-22,0`, so `A` dangled
> onto an auto-named `#net1` and `RB15` was asserting `X1.LOC,GND,net1` — an accident that also
> quietly depended on the `#` strip at `actions.c:3596` (`single_n_ptr = single_n + 1` when
> building the portmap). Caught in review; the leg now asserts the intended `X1.LOC,GND,TOP` and
> `RB15a` pins the port→parent resolution on its own.

- `RB0` — fixture witness: `record_global_node 3` says GND/VSS are global and TOP is not. Without
  this leg every other leg could pass vacuously.
- `RB1`-`RB4` — the defect: trailing global, mid-bus global, two adjacent globals, and the
  reported `{D,GND}`.
- `RB5`-`RB7` — controls that already passed: leading global (the order that hid it), scalar
  non-global, scalar global (which takes the `:2586` early return, not the loop).
- `RB8`-`RB9` — **downstream** witness through `translate lBUS {@#0:resolved_net}`, so the fix is
  pinned at a consumer and not only at the verb.
- `RB10` — bracket buses (`{D[1:0]}`) still expand per bit.
- `RB11`-`RB15b` — descended into `X1`: local nets keep the `X1.` prefix, globals stay flat, and
  both accumulate together (`{LOC,GND}` → `X1.LOC,GND`, `{LOC,GND,A}` → `X1.LOC,GND,TOP`).
- `RB16` — the top-level answer is stable after `go_back`.

### Verified

- RED first: at 14d02a0c the file is **8 FAILED / 11 passed**; after the fix **19/19**, in both
  the `--nogui` and the `--pipe`+`DISPLAY=:0` arm.
- Sabotage 1 (the fix itself reverted to `my_strdup2`) — the original 8 legs go red.
- Sabotage 2 (the *opposite* error: give the global branch the `path2` prefix too) — `RB14`,
  `RB15`, `RB15b` go red (`X1.LOC,X1.GND`), so the "globals stay flat" half has teeth as well.
  `RB13` stays green under this sabotage **by design**: scalar `{GND}` never enters the loop.
- `full_audit.sh test_resolved_net_bus_global_0157` classifies **PASS** (the file prints the
  literal `RESULT: ALL PASS` its `is_pass()` requires) with **0 leaked scratch dirs**, and the
  52-file `wireedit` subset — whose `predicates.tcl` calls `xschem resolved_net 0` — is ALL PASS.
- Neighbouring suites, all green after the fix: `test_prep_result_contamination_0155` (12),
  `test_hash_label_crash_0156` (23), `test_ase_unnamed_net` (28), `test_ase_interact` (63),
  `test_ase_plot` (145), `test_wave_viewer` (292), `test_wave_modes` (174), `test_ase_window`
  (166), `test_ase_dialogs` (133), `test_ase_persist` (109), `test_ase_core` (66),
  `test_ase_final` (28), `test_ase_final_gf180` (33), `test_wire_split`, `test_add_wire_label`,
  and all 24 `test_fluid_*` files.
- `test_rotate_stretch_short_0104` fails — it is in the 15-test pre-existing baseline. Re-run
  with the fix stashed and rebuilt: **byte-identical** failure line
  (`rot180-ip (-30,70): no NEW dangling endpoints`), so it is the floor, not a regression.

### Raised in review and deliberately not changed

- **The `,` at `:2661` is appended unconditionally, so an empty element would give `A,,B`.**
  Pre-existing and equally true of the non-global branch, so the fix does not create it — but it
  does stop a later global from *masking* it, so it is worth knowing the three sources cannot
  produce an empty element: the `hier_attr` lookup is guarded by `if(ptr && ptr[0])` (`:2620`);
  the portmap value comes from `find_nth` over a non-empty `inst[].node[i]` (guarded at
  `actions.c:3556`) so it is non-empty too; and `my_strtok_r` over an `expandlabel` result yields
  no empty tokens. Not reachable today; not worth a guard that would need its own unreachable test.
- **The test does not assert `test_scratch` returned a usable path, nor that
  `xschem_libs_newsym/devices` exists.** Both are covered indirectly: the whole body runs inside
  `catch` (a failure prints `FATAL:` and fails the file), and if `devices/` were missing the two
  `devices/gnd` instances would not load, so `GND`/`VSS` would not be registered global and `RB0`
  — which exists for exactly this reason — goes red before any other leg can pass vacuously.

### NOT verified

- No `full_audit.sh` run for this change (the targeted suites above were used instead).
- `send_net_to_graph` (`hilight.c:1595`) is reasoned about but not exercised by a test: it needs a
  loaded `.raw` whose vectors match a bus containing a global. The `translate()` consumer (`RB8`)
  is the stand-in downstream witness.
- No check that an existing **saved** graph `node` string containing a previously-truncated bus
  re-renders differently; the fix changes what `send_net_to_graph` *writes*, and old saved strings
  are untouched (they keep whatever was stored).
