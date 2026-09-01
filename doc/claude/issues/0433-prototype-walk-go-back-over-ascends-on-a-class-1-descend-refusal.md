# 0433 — both PDK hierarchy walks `go_back` on a descend refusal that never descended, popping a level they did not push

Status: OPEN, measured, **not fixed in the prototypes** (deliberately — S2 pinned
them as the acceptance oracle and S5 deletes them). Filed by the S3 write-up
agent (op-annotation crew, branch `annotate`).

Affected, byte-identically:

* `sky130A/sky130_procs.tcl` — `sky130_hier_sch_expand`
* `ihp-sg13g2/sg13g2_procs.tcl:401-407` — `sg13g2_hier_sch_expand`

Related: issue 0250 (`descend_schematic` returns 0 in two classes), 0431 (the
same two procs leak `no_draw`/`keep_symbols`), spec §5 I6.

## The code

```tcl
set res [xschem descend $n 2]
if {$res} {
  incr level
} else {
  xschem go_back 2
  puts "Can not descend into $instname"
  break
}
```

## What was measured

`xschem descend` returns 0 in **two classes with opposite required responses**
(`actions.c:4055-4065`, issue 0250). Measured on this tree:

| situation | return | `currsch` | `xschem get descend_error` |
|---|---|---|---|
| success | 1 | advanced | **empty** (cleared by `descend_clear_error()`, `actions.c:3855`) |
| nothing selected / not descendable / max depth | 0 | **UNCHANGED** | `no-selection`, `not-descendable:<type>`, `maxdepth` |
| subcircuit whose `.sch` is missing or blank | 0 | **ALREADY INCREMENTED** | `load-failed` |

The prototypes' unconditional `go_back 2` is:

* **correct** for the third row — the hierarchy did advance, so it owes a pop;
* **wrong** for the second row — nothing was pushed, so it pops a level
  belonging to the *caller*.

## Why nobody has noticed

The refusal that actually happens in practice is `load-failed` (a subcircuit with
no schematic), which is the class the code handles correctly. The class-1
refusals mostly occur at the **top level**, where `go_back` is a no-op — so the
bug is invisible.

One level down it is not a no-op. It corrupts `sch_path` for the remainder of the
walk, the walk then re-visits levels it has already emitted for, and the output
gains **duplicate cards**. Per issue 0434 / spec R5, duplicate and wrong cards
under the bench idiom cost the entire raw file.

Reachable for real at `CADMAXHIER = 40` on a recursive or deeply nested design,
where `descend` refuses with `maxdepth` and `currsch` unchanged — i.e. exactly
class 1, at depth 39, not at the top.

## Confirmed by construction

The reverted S3 implementation drove the decision off `xschem get currsch`
before/after plus `descend_error`, never off the return value:

```tcl
proc op_annot::_descended {c0} {
  if {[catch {xschem get currsch} c1]} { return 0 }
  if {$c1 <= $c0} { return 0 }                     ;# class 1 — do NOT go_back
  if {[catch {xschem get descend_error} derr]} { set derr {} }
  if {$derr eq {}} { return 1 }                    ;# success
  catch {xschem go_back 2}                         ;# class 2 — this one owes a pop
  return 0
}
```

On a self-recursive fixture this walked to `CADMAXHIER=40`, recorded one warning
naming the instance and `maxdepth`, emitted **118 unique** cards, terminated, and
restored the entry state. Swapping in the prototypes' arm as a sabotage variant
turned exactly the two predicted rows red (duplicate cards, and the entry state
not restored) — so the two behaviours are measurably different on a fixture that
is not contrived.

The empty-on-success property of `descend_error` is what makes the split
possible from live getters alone, without a new C return code.

## Why the prototypes are not being fixed

S2 pinned `sg13g2_write_save_lines` / `sky130_write_save_lines` and their walks as
the **acceptance oracle** for the generic name builder
(`ihp-sg13g2/sg13g2_procs.tcl:665-670` says so explicitly), and S5 deletes both
files outright. Editing them now would move the oracle under the feature that is
being validated against it. Recorded here so the deletion in S5 is understood as
*also* removing a live bug, not merely removing duplication — the same note
already applies to 0430 and 0431.

## Still open

* Both shipped prototypes carry the bug until S5 deletes them. A user who runs
  "Create FET .save file" on a deeply nested sky130 design today can get a
  corrupted card list with no diagnostic (the `puts` is invisible in a GUI
  session and under `--nogui`).
* The generic `src/xschem.tcl` walk (`hier_traversal`, `:3627-3727`) was not
  audited for the same pattern.
