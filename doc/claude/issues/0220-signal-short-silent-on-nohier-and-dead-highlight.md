# 0220 — `signal_short()` is silent on `-nohier` / current-level-only netlist, and its highlight branch is unreachable

Status: **FIXED** 2026-08-05 — as drafted below, with two corrections (see *Corrections made
while implementing*). Landed as the S0 prerequisite of
`doc/claude/specs/wire_label_ride.md`.
Area: `src/netlist.c` `signal_short()` (`:923-941`), the `print_erc` gate at `:1426`
Tests: `tests/headless/test_signal_short_nohier_0220.tcl` — 11 checks. Verified RED against the
pre-fix tree on exactly the two defects (`A1` = defect A, `D0`/`D1`/`D2` = defect B) with every
control green on both sides.
Found: 2026-08-05, while grounding `doc/claude/code_analysis/net_label_model_instance_vs_wire_attached.md`
Related: **0221** — the order-dependent naming this failure hides. No prior issue covers `signal_short`; the nearest prose is `doc/claude/specs/pin_rename_propagation.md:88,111` and the comment at `src/editprop.c:1243-1246`.

## Not the defect that was first suspected

The initial claim was "`signal_short()` never fires at top level". **That is wrong** and
must not be written anywhere as fact: on a default hierarchical netlist the short *is*
reported. Every backend runs a **second** `prepare_netlist_structs(1)` on the reloaded top
level after descending the hierarchy, with `netlist_count > 0` by then
(`spice_netlist.c:534`, `spectre_netlist.c:420`, `verilog_netlist.c:383`,
`vhdl_netlist.c:473`, `tedax_netlist.c:260`, all inside `if(global)`).

Measured, two `lab_pin`s with different names on one wire:

```
$ xschem netlist -erc -messages
-----------…/short1.sch
Error: undriven node: BBB
Warning: open net: #net1
-----------…/short1.sch
Error: Net shorted: AAA - BBB
```

Two real defects remain.

## Defect A — no short report at all when the hierarchy is not descended

```c
src/netlist.c:927
 if( xctx->netlist_count && n1 && n2 && strcmp( n1, n2) )
```

`netlist_count` is 0 for the whole run whenever `if(global)` is false, so the second pass
never happens:

- `xschem netlist -nohier` (`src/scheduler.c:8119`, `:8144-8146`)
- the Shift-N "current level only netlist" key (`src/callback.c:6557-6561`,
  `global_spice_netlist(0, 1)`)

Same fixture, same shorted schematic:

```
$ xschem netlist -erc -messages -nohier
-----------…/short1.sch
Error: undriven node: BBB
Warning: open net: #net1
```

No `Net shorted` line. The user gets a netlist in which two differently-named nets were
merged, with nothing said about it.

Also silent for the same reason: the two non-netlist `prepare_netlist_structs(1)` callers,
`print_hilight_net()` (`src/hilight.c:4262`) and `list_hilights()` (`:4359`), which did
report shorts before upstream `590b6fb3` added the gate.

## Defect B — the highlight branch is dead code

```c
src/netlist.c:927-938
 if( xctx->netlist_count && n1 && n2 && strcmp( n1, n2) )
 {
   …
   statusmsg(str,2);
   if(!xctx->netlist_count) {                       /* <-- unreachable */
      bus_hilight_hash_lookup(n1, xctx->hilight_color, XINSERT);
      if(tclgetboolvar("incr_hilight")) incr_hilight_color();
      bus_hilight_hash_lookup(n2, xctx->hilight_color, XINSERT);
      if(tclgetboolvar("incr_hilight")) incr_hilight_color();
   }
 }
```

`:927` requires `netlist_count != 0`; `:933` requires `== 0`. Shorted nets are therefore
**never coloured on the canvas** any more — the ERC text appears, the schematic does not
change. `git log -L 923,941:src/netlist.c` shows why: the inner block predates the gate,
and `590b6fb3` ("better ERC messaging in case of errors (shorts, pins with missing
attrs)") added only `xctx->netlist_count &&` to `:927` and left the inner branch alone.
This is a regression, not an intentional disable.

## Fix

The two defects share one fix: gate on the existing double-print flag instead of on
`netlist_count`, which restores the inner branch to the meaning it was written with.

1. `src/netlist.c:1414` — hoist `print_erc` to file scope. Delete the local
   `int print_erc;` from `name_nodes_of_pins_labels_and_propagate()` and declare it beside
   the other file statics (`static int for_netlist;`, `netlist_lvs_ignore`, `startlevel`):

   ```c
   static int print_erc = 0;
   ```

   `:1426` keeps assigning it verbatim:

   ```c
   print_erc = (xctx->netlist_count == 0 || startlevel < xctx->currsch) && for_netlist;
   ```

   `name_nodes_of_pins_labels_and_propagate()` is the first thing
   `prepare_netlist_structs()` calls (`:1776`), before `name_unlabeled_nets()` /
   `name_unlabeled_instances()`, so `print_erc` is already set for every `signal_short`
   call site (`:1042`, `:1097`, `:1120`, `:1144`, `:1358`, `:1389`) in the same run.

2. `src/netlist.c:927` —

   ```c
   if( print_erc && n1 && n2 && strcmp( n1, n2) )
   ```

3. `src/netlist.c:933` — **leave `if(!xctx->netlist_count)` exactly as it is.** It now
   means "highlight only on the top-level pass", which is what it was written for, and it
   becomes reachable again.

Resulting behaviour: hierarchical netlist → short printed once, on pass 1 instead of
pass 2, and now also highlighted; `-nohier` / Shift-N → short printed, currently silent;
sub-block shorts → still printed (`netlist_count > 0` but `startlevel < currsch` keeps
`print_erc` at 1); `prepare_netlist_structs(0)` callers → unaffected, every call site is
already wrapped in `if(for_netlist>0)`.

## Risks

- **Message order changes** for hierarchical netlists: `Error: Net shorted` moves from
  after the second `-----------<sch>` banner to before `Error: undriven node` under the
  first. Anything diffing full ERC text churns. `tests/netlisting/` has no committed
  `gold/` baseline (see CLAUDE.md), so nothing in-tree compares it — but check
  `tests/headless/gold/` for ERC-text captures before landing.
- **`err` timing**: the short's `err |= 1` now arrives via `spice_netlist.c:184` instead of
  `:534`. Both are OR'd into the same returned `err`, so `exit_code` / `show_infotext` are
  unchanged — but confirm for tEDAx, whose `global_tedax_netlist()` return is ignored at
  `scheduler.c:8176`.
- **`print_erc` as a file static** is shared across the five backends and across
  windows/tabs. Same assumption `static int startlevel` (`netlist.c:1417`) already makes
  ("safe to keep even with multiple schematic windows, netlist is not interruptable"), so
  no new hazard — but it is a second piece of hidden cross-call state.
- **Re-enabling the highlight** calls `bus_hilight_hash_lookup` + `incr_hilight_color` and
  reads `tclgetboolvar("incr_hilight")` per short, inside the hot naming loop. Upstream
  `0805802b` already removed a per-short Tcl call from this function for exactly that
  reason. Hoist the `tclgetboolvar` out.
- Restoring reports to the two `hilight.c` callers may be unwanted. There is no
  "netlisting in progress" flag to gate on today; prefer the simple form above and revisit
  only if it proves noisy.

## Corrections made while implementing

1. **`startlevel` is not a file-scope static.** Step 1 above says to declare `print_erc`
   "beside the other file statics (`static int for_netlist;`, `netlist_lvs_ignore`,
   `startlevel`)". `startlevel` is a **function-scope** static local at `netlist.c:1417`; the
   only file-scope statics are `for_netlist` (`:25`) and `netlist_lvs_ignore` (`:26`).
   `print_erc` was hoisted to `:25-26`; `startlevel` was **not** moved, and its sole
   consumer — `print_erc`'s assignment — stays inside the function where it is visible. Do not
   move `startlevel`.
2. **Two more callers become noisy, not the two the risk list names.** Besides
   `print_hilight_net()` (`hilight.c:4262`) and `list_hilights()` (`:4359`), `node_hash.c:383`
   and `show_unconnected_pins()` (`netlist.c:1692`) also pass `for_netl=1` with
   `netlist_count == 0`, so they too now report shorts. Kept, per the issue's own
   recommendation ("prefer the simple form above and revisit only if it proves noisy") — and
   the `list_hilights` path is what makes defect B testable at all (see below).
3. **`incr_hilight` hoist.** `signal_short()` owns no loop, so the `node_hash.c:200-202`
   function-local hoist does not transfer. Cached in a file static `erc_incr_hilight`,
   refreshed once per run in `prepare_netlist_structs()` beside
   `netlist_lvs_ignore=tclgetboolvar("lvs_ignore")` — the existing pattern for exactly this.

## How defect B is tested without a hollow assertion

On a netlist run the shorted names light up whether or not `signal_short`'s branch works,
because `traverse_node_hash()` separately highlights every undriven / open / goes-nowhere net
(`node_hash.c:212`, `:220`, `:227`, `:235`) — and the losing name of a naming short is always
one of those. Measured: a two-name-on-one-wire fixture highlights `AAA` and `BBB` from the
undriven pass alone.

The test therefore probes through `xschem list_hilights` (`hilight.c:4359`), which runs
`prepare_netlist_structs(1)` **without** `traverse_node_hash()`. There `signal_short()` is the
only thing that can insert into the hilight table, so the check is a real discriminator — and
it simultaneously pins correction 2 as intended behaviour.

## Measured effect of the fix

- Neither risk listed below fired: `tests/headless/gold/` holds no ERC-text capture (6 files,
  all `.spice` netlists plus one state dump), and `tests/headless/run.sh` stays green.
- The `err` timing note holds: `tests/headless/run.sh` and `tests/run_regression.tcl` show no
  exit-code change.

## What this does *not* fix

The order-dependent name selection — see **0221**. This issue only makes the collision
audible on the paths where it currently is not.
