# 0428 — the Waves-menu result chooser discards the whole registry, and no test drives it

**Status:** OPEN. Measured on branch `fluid-editing` at `58b2c24d`, 2026-08-18.
**Area:** `proc load_raw` / `proc waves` / `proc select_raw`
(`src/xschem.tcl:16687` / `:6373` / `:16672`), the Waves menubar cascade
(`src/xschem.tcl:17126-17149`), the `raw_read` and `raw_clear` scheduler arms
(`src/scheduler.c:10776` / `:10761`).
**Found:** 2026-08-18, mapping xschem's surfaces against Cadence ADE-L's
`Results > Select…`.

---

## What

Two `xschem` verbs are one underscore apart and do **opposite** things to the
raw registry:

| verb | registry effect | implementation |
|---|---|---|
| `xschem raw read <file> [type]` | **appends** a database and makes it current | `extra_rawfile(1, …)`, `scheduler.c:10380-10404` |
| `xschem raw_read <file> [type]` | **clears every loaded database**, then reads | `extra_rawfile(3, NULL, …)` at `scheduler.c:10791`, then `read_rawfile_by_type()` at `:10810`; arm `:10776-10816` |

The arm's own header comment (`scheduler.c:10770-10775`) says only *"If a raw
file is already loaded delete from memory"* — singular, which reads as "replaces
the current one", not "empties the registry". The registry-wide truth is stated
only in an unrelated inline comment further down the same arm, where it is
mentioned in passing as a precondition for something else — nowhere a caller
would look.

**The schematic editor's only result chooser uses the destructive one**, and
belts it: `load_raw` (`xschem.tcl:16687-16700`) calls `xschem raw_clear` first
and *then* `xschem raw_read`, so the wipe happens twice. **Eight** Waves-menu
entries route there — `Load first analysis found`, `Op`, `Dc`, `Ac`, `Tran`,
`Noise`, `Sp`, `Spectrum`, all via `waves <type>` → `load_raw`. The other three
do not: `External viewer` takes the `waves external` branch, `Clear` calls
`xschem raw_clear` directly and openly, and `Op Annotate` calls `select_raw`
itself.

## Measured

```
== 'xschem raw read' (space) — the APPEND verb ==
after two 'raw read': registry holds 2 databases
1 current
0 .../srlatch/srlatch_ase.raw dc
1 .../cmos_ac_sweep/cmos_ac_sweep_ase.raw ac

== 'xschem raw_read' (underscore) — what the Waves menu uses ==
free_rawfile(): clearing data
free_rawfile(): clearing data
after one 'raw_read': registry holds 1 databases
0 current
0 .../tb_diff_amp/tb_diff_amp_ase.raw dc
```

`src/xschem --nogui --pipe -q --script`, 2026-08-18. Two databases the user had
open are gone, with no prompt and no message — the only trace is two
`free_rawfile(): clearing data` lines at `dbg` level.

## Why it matters

The registry is not bookkeeping. Things reference it by name:

- a graph rect carries `rawfile=` + `sim_type=` and its `node=` tokens may carry
  a `%<dataset> <rawfile>` suffix resolved through `node_token_split()`;
- the signal browser's **All DBs** search walks every loaded database;
- ASE-L's cosim attaches VCDs *alongside* the raw (`ase::attach_dbs`,
  `ase.tcl:2866`, which deliberately purges and re-reads in a controlled order).

So picking a Tran result from the Waves menu can silently drop the VCD half of a
mixed-signal session, or the second database a graph was comparing against, in
the same window. The user asked to *load a result*; they were not told they were
also unloading three.

Note the blast radius is one `xctx` — the registry is per window/tab
(`xschem.h:2036-2043`) — which is why this has survived: it does not disturb a
*separate* viewer window.

## And no test drives any of it

```sh
grep -rn "select_raw\|load_raw" tests/
```
returns four hits in two files, and **not one of them executes the path**:

- `tests/headless/test_backannotate_digital.tcl:303`, `:691` — prose comments
  about `select_raw`'s dialog.
- `tests/headless/test_wave_sigbrowser_i1315.tcl:7`, `:426-431` — BR04, which
  greps the **string** `select_raw` out of `wviewer::rawbar_browse`'s body
  (captured at `:354`) to prove the viewer's Browse button reuses it rather than
  reimplementing a second file dialog. That is a source-text assertion about a
  *different* proc, and it never executes either one.

So the surface every reader named as xschem's closest analogue to
`Results > Select…` has **zero functional coverage**: nothing asserts what the
registry looks like before and after, nothing asserts the cancel case
(`select_raw` returns `{}` and `load_raw` silently does nothing), nothing
asserts the `type ne {}` branch.

⚠ **A test cannot get the cancel case by running headless.** `select_raw`
computes a guessed default (`$netlist_dir/<cell>.raw`) *first* and only
overwrites it with `tk_getOpenFile` inside `if {[info exists has_x]}`
(`src/xschem.tcl:16676-16684`) — with no `has_x` it returns the **guess**, not
`{}`. The cancel arm has to be reached by shimming `select_raw`.

## Fix

1. **Decide the semantics and write them down.** Either
   (a) `load_raw` moves to the appending `xschem raw read`, and the Waves menu
   grows an explicit `Clear` (it already has one at `xschem.tcl:17131`), or
   (b) the replace-everything behaviour is kept as deliberate and *said so* — in
   the menu label, in `raw_read`'s comment, and in the spec.
   (a) is the better answer if `doc/claude/specs/results_selection.md` lands,
   because that feature is precisely "hold several results, pick which is
   current".
2. **Rename or alias so the two verbs cannot be confused.** `raw_read` is
   upstream and load-bearing (141 launcher instances across the three PDK
   workareas call it, plus `raw_read_from_attr`), so it cannot simply go — but
   its comment must state *"clears the entire registry first"*.
3. **Cover the path.** A headless case that: loads two databases with
   `raw read`; drives `load_raw` with `select_raw` shimmed to return a path;
   asserts the resulting registry; repeats with the shim returning `{}` (cancel)
   and asserts **nothing changed**. Shimming `select_raw` is the established
   idiom — `test_calc_skeleton.tcl` S26 shims the Calculator's whole resolution
   order the same way.

## Related

- issue **0427** — `raw_is_loaded` parses `xschem raw info` by word; the sibling
  defect on the same selection path.
- `doc/claude/specs/results_selection.md` — the feature that makes the
  append-vs-replace question user-visible.
- `doc/claude/specs/simulator_profiles.md` §14.7 — the existing enumeration of
  raw-adopt paths and which of them skip `ase::raw_content_verdict`.
