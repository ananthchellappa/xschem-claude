# 0611 — the netlist walk's save/restore should not go through the user-facing undo path

STATUS: **OPEN — filed by the user's X0498 ruling, 2026-08-22.** Not a defect;
a cost the shipped design pays on every global netlist. Related: **0498** (the
crash and the shield that fixed it), 0600 / 0431 (the leaks that make a stray
`no_undo` reachable in the first place).

---

## What the walk actually needs

A global netlist walks the whole hierarchy, and xschem has **one** document slot.
To visit a sub-sheet the walk *loads* it, so it must stash the user's document
first and put it back at the end.

It does that with the undo machinery:

```c
undo_saved = global ? undo_shield_push() : xctx->no_undo;   /* spice_netlist.c:309 */
xctx->push_undo();
...
xctx->pop_undo(2, 0);                                        /* the tail */
```

That is a **save/restore**, not an undo record. Nothing the user does can ever
undo *to* that slot — `pop_undo(2, 0)` consumes it at the end of the same call.

## What it costs

The default disk backend forks a subprocess and compresses the entire schematic
per push:

```
src/save.c:4744   execlp("gzip", "gzip", "--fast", "-c", NULL);
```

Measured during X0498 on `bandgap_opamp` (75 instances), 10 netlists:

| | before the shield | after | |
|---|---|---|---|
| disk undo, `no_undo=1` | 36 ms | 204 ms | ~6× |
| memory undo, `no_undo=1` | 31 ms | 73 ms | ~2.4× |
| **normal runs (`no_undo=0`)** | 206 ms | 192 ms | unchanged |

≈ **17 ms of added wall clock per global netlist** on a 75-instance cell — one
gzip of that schematic.

**The number to keep in view is the third row, not the first two.** Normal runs
were *already* paying this, before the shield and after it. X0498 did not add the
gzip; it removed the one escape hatch that skipped it. So this is not a
`no_undo`-only tax — it is on **every** global netlist anyone has ever run.

**It scales with cell size.** 75 instances gzips fast; a 5000-instance top cell
does not.

## Why this is filed rather than argued about

The X0498 ledger question was framed as *who pays* — accept the cost on
`no_undo` runs, or make the netlister refuse to run. The user's ruling
(2026-08-22) took neither horn:

> Accept the shield, and record that the walk's save/restore should not be going
> through the user-facing undo path at all. It never needs to be undoable by the
> user, so forking gzip for it is waste on every run, not just `no_undo` ones.
> Fixing that removes the tax entirely instead of arguing about who pays it.

## Fix direction — for whoever takes it

The walk needs *save the document, restore the document*. It does not need undo
semantics, a slot in the ring buffer, a redo peer, or `set_modify` bookkeeping.
Candidates, none evaluated:

* a dedicated save/restore that serialises to memory regardless of which undo
  backend is configured — `in_memory_undo.c` already has the machinery, and the
  measured memory-undo cost (31 → 73 ms) is a fifth of the disk one;
* skipping serialisation entirely, if the walk can be made to restore by
  re-loading `xctx->sch[0]` rather than by replaying a snapshot — cheaper still,
  but it loses unsaved modifications, so it is only correct if the walk is
  guaranteed not to run on a modified buffer;
* keeping `push_undo` but making the disk backend's compression optional.

## Do not undo the shield while fixing this

`undo_shield_push()` / `undo_shield_pop()` exist because a leaked `no_undo=1`
silently replaced the user's document and then took the process down with
SIGSEGV (issue 0498, measured deterministically 3-of-3). Whatever replaces the
push/pop pair must be equally immune to an editing flag — the property, not the
mechanism, is what 0498 ruled on.

## Sites

Every one of these carries the shielded pair, and all would change together:

| file | push | pops |
|---|---|---|
| `spice_netlist.c` | `:309` | `:330`, `:635` |
| `spectre_netlist.c` | `:187` | `:208`, `:513` |
| `vhdl_netlist.c` | `:142` | `:157`, `:519` |
| `verilog_netlist.c` | `:116` | `:130`, `:431` |
| `tedax_netlist.c` | `:152` | `:170`, `:307` |
| `hier_psprint()` | `:65` | `:144` |
