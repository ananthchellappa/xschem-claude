# Issue 1603 — a symbol with no `type=` is a NULL `strcmp` in 27 places

Issue: `doc/claude/issues/1603-a-symbol-with-no-type-property-is-a-null-strcmp-in-28-places.md`
Related: **1607** / **1353** (the heap over-read in the same file, closed in `97766c66`),
**1492**/**1493** (the display-crash class this was found beside and is *not* a member of).

`dc23e730` closed **exactly one** of these sites — `psprint.c:1070`, the only one ever driven to
a segfault, identified by a gdb backtrace landing in `__strcmp_avx2 ← ps_draw_symbol ← create_ps
← ps_draw ← hier_psprint`. The test moved into `hier_psprint_inst_dest()`, which opens
`if(!type) return NULL;`.

**The other 26 stand**, and 19 of them are in the netlisters — the operation this program exists
to perform, which runs headless in every batch flow, where a NULL dereference takes the whole
process down with no netlist and no diagnostic.

## What makes this issue awkward, and it is not the guard

The issue says so itself: a blanket `type ? type : ""` would answer all 27 at once and **would be
wrong wherever the absence means something other than "not that type"**. `move.c` already shows
the considered form — `if(!sym->type || strcmp(sym->type, "label")) return -1;` — a typeless
symbol is *not* a label. But at `netlist.c:1030` the question is whether it is a port, and that
is a semantic decision per site, not a mechanical one.

So the work is: **prove non-NULL, or guard with a stated meaning.** Never guard by reflex.

## Stage A — turn the candidate list into a defect count

The issue is explicit that **28 was a candidate list, not a defect count** (since corrected to 27
— `spice_netlist.c:96` was a false positive of the two-line context window, guarded two lines
earlier). Exactly one has been driven to a crash. The sweep was a pattern match, so a site
guarded further up its function reads as unguarded, and a site where `type` is non-NULL by
construction reads as a defect when it is not.

**Item 1 of the issue asks for the fixture back**: a symbol with no `type=` property, a schematic
instancing it, and a driver that reaches each site. The original repro is in a deleted scratch
clone — the finding survived, the fixture did not. Rebuilding it is the highest-value single step,
because it converts 27 guesses into a measured count and gives every later fix a red to turn
green.

## Stage B — triage each surviving site

For each: either prove `type` cannot be NULL there (and say how — a dominating guard, a
by-construction invariant, a caller contract), or state what a typeless symbol *means* at that
site and add the house-style guard. The netlister cluster first.

## Stage C — fence it

A guard added without a row that reddens on its removal is a guard that leaves silently. The
shape is already established in this tree: a behavioural row driven by the Stage A fixture, plus
a static row where the behavioural one cannot fire deterministically — the lesson issue 1607's
batch paid for when its `V25` turned out to be a sampler and needed `V27` beside it.

## What is NOT in scope

- Turning `ps_hier_nav` on. Waits on a human opening a PDF; no viewer on this machine.
- The `svg_draw()` leak on an unwritable plotfile (found during the 1607 batch, unfiled).
- Gate coverage — `test_scratch_home_note`'s red, and the 336 `tests/headless/` suites T1 does
  not run. Real, recorded in `doc/claude/issue_1607_batch/LEDGER.md`, and a different project.
