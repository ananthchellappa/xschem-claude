# 0911 — on a DESCENDED sheet with no ASE-L session, `6` never repairs, and the only escape now tells the user a false sentence

STATUS: **FIXED** 2026-08-28 by item B2. Measured 2026-08-28 by item A15's
adversary pass, re-measured by A15's write-up agent on the delivered tree before
filing, and reproduced byte for byte by B2 on HEAD 4eb0076e before any change.
FOUND IN: `cadence::_annot_raw_candidate`'s `netlist_dir` fallback,
`utils/annot_mode.tcl` — the candidate was built from
`xschem get schname`, i.e. the sheet the user is standing on — consumed by
`op_annot::db_current`'s guard G4 (`src/op_annot.tcl`).
FIXED IN: the same fallback arm. It now asks `xschem get schname 0` — the TOP of
`xctx`'s `sch[]` stack — and returns level `0` instead of an empty level, so the
raw binds to `xctx->sch[0]` and the device path keeps its hierarchy prefix.
Guard G4 was NOT touched: only its input was repaired.
ACCEPTANCE: `tests/headless/test_annot_hier_0911.tcl`, 15 checks, registered in
`tests/run_regression.tcl`'s `hcases` and `full_audit.sh`'s `nogui_tests`. It is
the first suite on this surface that stages a hierarchy at all.
RELATED: [0684](0684-annot-ensure-loaded-guards-on-the-wrong-predicate.md) §8
(route table corrected there),
[0910](0910-an-operating-point-attached-from-outside-is-trusted-forever-at-the-same-path.md).
COST OF THIS FIX, all three filed and all three invisible to every suite:
[0917](0917-answering-always-from-the-top-of-the-hierarchy-moves-the-0911-defect-into-the-standalone-block-workflow.md)
(the same symptom, silently, in the standalone-block workflow),
[0918](0918-alt-shift-6-changed-direction-on-a-descended-sheet-when-0911-was-fixed.md)
(Alt-Shift-6 moved in both directions),
[0919](0919-two-rows-gold-the-untruncated-sentence-against-the-truncated-status-bar.md)
(two of this issue's own acceptance rows are checkout-path-length sensitive).

---

## 1. What the user does, and what they see

A top sheet instantiating a subcircuit. No ASE-L session — the plain
`netlist_dir` way of working. Press `6` on the top sheet (attaches
`$netlist_dir/top.raw`), descend into the instance, re-run the simulation so
`top.raw` holds new numbers, press `6`. Measured, delivered tree, headless:

```
D2| press 6 on descended sheet (disk says 9m)
D2|     sheet paints : id = 10u | gm = 100u | gds = 1u
D2|     status line  : ... These results were already loaded.
D2| press 6 a THIRD time                  -> id = 10u | gm = 100u | gds = 1u
D2| Ctrl-6 then 6 (untick / re-tick)      -> id = 10u | gm = 100u | gds = 1u
D2| Waves > Clear then 6 -- the ONLY escape the old tree had
D2|     sheet paints : id = | gm = | gds =
D2|     status line  : ... There is no results file at /tmp/vc684/nd/sub.raw yet. Run a simulation first.
```

So: the previous run's numbers, permanently, on the gesture the user named — and
the one escape that worked before now ends in a sentence that is **false about a
run that just finished**. It names a file the design never had and tells the user
to run a simulation they have already run.

## 2. Mechanism

With no ASE-L session the candidate falls through to
`"$netlist_dir/[file tail [file rootname [xschem get schname]]].raw"` — the
SHIPPED `select_raw` spelling (`src/xschem.tcl:14763`, the path built on
`:14766`), deliberately kept
identical there. On a descended sheet `schname` is the **subcell**, so the
candidate is `.../sub.raw` while the attached database is `.../top.raw`. Guard G4
sees candidate ≠ attached path and answers *"not mine, leave it exactly where it
is"* — the arm that exists to stop one corner's operating point being destroyed
by a press about another (issue 0908). Correct rule, wrong input.

The candidate is a pre-existing spelling; what is new is that **currency now
depends on it**, so a candidate that was merely a fallback for "which file would
I load" is now also deciding "are the numbers on screen the right ones".

## 3. Why an ASE-L session rescues it

`ase::session_for_current` (`src/ase.tcl:3091`) walks the **hierarchy stack**, so
the candidate stays `top.raw` all the way down. Measured (adversary probe
`d3.tcl`): same descend, same re-run, press `6` → `id = 9m` and
`Loaded results from .../top.raw.` The whole defect is the fallback's flat
`schname`.

## 4. What would close it

Resolve the fallback candidate from the hierarchy the way
`ase::session_for_current` already does — the top of `xctx`'s `sch[]` stack, not
the current sheet — and pass the level with it, as the ASE arm already does
(spec landmine 4). That is one function, and it also fixes the false sentence,
because the refusal would then name the file the design really uses.

## 5. Acceptance rows this would need

Nothing in the tree descends. `tests/headless/test_annot_stale_0684.tcl` and
`test_op_annot.tcl` both stage flat sheets. A closing fix needs: press `6` on a
top sheet, descend, re-run, press `6` → the NEW numbers; and `Waves > Clear` then
`6` on the descended sheet → the top sheet's raw named, not the subcell's.

---

## 6. How it was closed (item B2, 2026-08-28)

**Two lines, in the `netlist_dir` fallback of `cadence::_annot_raw_candidate`
(`utils/annot_mode.tcl`). The ASE arm was not touched.**

```
-  catch {set sn [xschem get schname]}
+  catch {set sn [xschem get schname 0]}
-  return [list "$nd/$cell.raw" {} netlist_dir]
+  return [list "$nd/$cell.raw" 0 netlist_dir]
```

`xschem get schname 0` is `xctx->sch[0]` (`src/scheduler.c:5251-5261`), always
populated whenever a schematic is loaded, so no extra fallback arm and no new
invisible guard were needed.

**The level is half the fix, not a garnish, and this was measured rather than
argued.** Descended one level into `x1` with the top's operating point attached:

| attached | `sim_sch_path` | device path | block |
|---|---|---|---|
| with level `0`  | `x1.` | `@m.x1.mzz` | `id = 10u \| gm = 100u \| gds = 1u` |
| with no level   | (empty) | `@m.mzz` | `id = \| gm = \| gds =` |

`op_annot::db_attach` passes the level to `xschem annotate_op`; with `level >= 0`
`scheduler.c:2540-2543` sets `xctx->raw->level` and binds `raw->schname` to
`xctx->sch[level]`, otherwise `raw_read` (`save.c:1269-1270`) defaults both to the
CURRENT sheet — spec landmine 4's silent device-path collapse. A fix that
corrected only the path would re-attach the right file and still paint a blank
block. Row **H1** pins that engine fact so the level assertions are not taken on
trust.

### The three twins, each a running row rather than an argument

1. **The flat case** — H7 (behaviour unchanged) and H8 (on a flat sheet, carrying
   the level and not carrying it are the SAME attach: same device values, same
   file, same hierarchy prefix). `currsch` is already 0 there, so the `0` is a
   behavioural no-op.
2. **Issue 0908** — H9 stages the only state that actually reaches guard G4:
   another corner's operating point attached, then rewritten so the freshness
   stamp no longer matches, then asked with a candidate at a different path. G4
   still answers "leave it alone" and the corner's numbers survive. H12 is its
   structural half and also proves the **0912 fence held** — G4's
   `if {$cand eq {}} { return 1 }` arm is untouched.
3. **The ASE-L arm** — H10 stubs a live session on a DESCENDED sheet and requires
   the session's own file and its own level (`1`, not `0`) to be the answer, i.e.
   the new code is never reached.

### Collateral, and it was the only collateral in the tree

Rows **N12** and **N13** of `tests/headless/test_op_annot.tcl` golded the
fallback's level as the empty string; both now gold `0`. Nothing else in the tree
moved, because every other fixture on this surface is flat. Measured after the
fix: `test_op_annot` 475 headless / 482 with a display, `test_annot_stale_0684`
52, `test_annot_blank_cause_0909` 27 — all identical to the pre-change baseline —
and `tests/run_regression.tcl` at 44 blocks (43 + this suite) with ZERO counted
failures.

### The cost that was known when it landed, and it is UNRATIFIED

⚠ It was called "the one cost" when this item shipped. It is not: the
adversary pass found two more, filed as **0917** and **0918** and listed under
"What this fix COST, and what is still open" below. Read the two together —
0917 §3 shows that neither option below fixes 0917's half.

`xschem netlist` netlists the sheet the user is STANDING ON — measured by the
implementing agent: from the descended sheet the deck is written as
`sub.spice`. (The adversary could not reproduce that on a thinner fixture —
its `xschem netlist` returned 0 and wrote nothing — so treat the *spelling*
of the claim as single-sourced. It is not load-bearing: 0917 and the option
set below only need a file named `netlist_dir/<standing sheet>.raw` to
exist, however it got there.) So a user who descends into a
subcircuit and simulates it on its own really does get `netlist_dir/sub.raw`, and
on the shipped tree pressing `6` there loaded it. After this fix that press
refuses and names `top.raw`, a file that run never produced — the same shape of
false sentence this issue is filed about, one case over.

* **Option A (shipped, provisional)** — the top of the hierarchy stack, always.
  One spelling, no disk-dependent answer, matches what the ASE-L arm already does.
* **Option B** — the top first, and the sheet the user is standing on as a
  fallback when the top's results file is not there. Keeps the standalone subcell
  run working, at the cost of a candidate whose answer depends on what happens to
  be on disk and a refusal that has to choose which of two paths to name.

Row **H13** pins option A and is the row that moves if the user rules option B.
Recorded as a rule debt (`owed.sh add rule 0911`). A **look** debt is also open:
the rows read the block through `op_annot::text`, the renderer, so a green suite
proves the values moved and NOT that the descended sheet repaints.

### §5's acceptance list, walked item by item

§5 asked for two things and warned that nothing in the tree descends. Both are
now running rows, and the fixture that made them possible — a top sheet
instantiating `sub.sym` as `x1`, plus a headless `xschem descend` — is the first
hierarchy on this surface anywhere in the tree.

| §5 asked for | the row that implements it | what it golds |
|---|---|---|
| "press `6` on a top sheet, descend, re-run, press `6` → the NEW numbers" | **H3** | one press paints `id = 9m \| gm = 7m \| gds = 50u` and says `Loaded results from …/top.raw.` Before: `id = 10u …` under `These results were already loaded.` |
| (the same gesture, repeated — §1's third press and its `Ctrl-6` then `6`) | **H4** | presses 2 and 3, and untick-then-re-tick, all agree with press 1. The numbers never go back. |
| (the escape §1 names — `Waves > Clear` then `6`) | **H5** | finds the file the design really uses and puts the numbers back, instead of blanking the block. |
| "`Waves > Clear` then `6` on the descended sheet → the top sheet's raw named, not the subcell's" | **H6** | with no results file anywhere, the refusal names `<nd>/top.raw`. Before: `<nd>/sub.raw`, a path nothing in the bench ever writes. |

Supporting rows, none of which §5 asked for and all of which the twins required:
**H0/H0b** (the fixture really is a hierarchy, and the two ways of naming the
results file really do disagree once descended — without H0b every row above
could pass vacuously); **H1** (the engine precondition that makes the level half
load-bearing); **H2** (the candidate itself, in one line — 0911 reduced to an
assertion); **H7/H8** (twin 1); **H9/H12** (twin 2, and the 0912 fence);
**H10** (twin 3); **H11** (the structural row); **H13** (the unratified cost).

Two sabotage variants were run against the product file itself, backed up and
restored with an mtime bump:

* **S1**, the flat `schname` spelling put back — 7 red, exactly H2/H3/H4/H5/H6/
  H11/H13, with H7 and H8 staying green. That is the item's acceptance point 6,
  and it reproduces §1's transcript verbatim, which is the strongest evidence
  the suite measures the filed defect and not a proxy.
* **S2**, the path fixed and the level dropped — 6 red, exactly H2/H3/H4/H5/H8/
  H11, with H6 and H13 green because they only exercise the path. This is the
  variant that proves the level is load-bearing rather than decorative.

Three further variants were exercised against mirrored copies: **S5** (level =
`currsch` instead of `0`, the plausible near-miss) reds H2/H3/H4/H5 and leaves
**H11 green**, which is the correct division of labour — a structural row cannot
see a wrong-but-present level, only the user's gesture can. **S3** (guard G4's
not-mine comparison deleted) reds H9 and H12 here, and two rows of
`test_annot_stale_0684` as well. **S4** (G4's no-candidate arm, issue 0912's
fenced subject, deleted) reds **H12 only** — and nothing at all in
`test_op_annot`, `test_annot_stale_0684` or `test_annot_blank_cause_0909`. H12 is
that guard's only witness anywhere in the tree, which is the house rule about
structural rows cashing out exactly as written.

### What this fix COST, and what is still open

Three things were measured on the delivered tree and are **not** fixed here. None
of them is visible to any suite; all three are filed.

* **[0917]** — answering always from the top moves 0911's own symptom into the
  standalone-block workflow, and there it is **silent**. With the chip's results
  file *and* a fresh block results file both in `netlist_dir`, descending into
  the block and pressing `6` paints the chip run, and keeps painting it after a
  block re-run under "These results were already loaded". Row **H13** pins only
  the *refusal* form of this cost — the case where the top's file is absent.
  Critically, **neither option A nor option B of the rule debt below fixes it**,
  because both answer the top's file when the top's file is present; 0917 §3
  adds options C, D and E to the menu.
* **[0918]** — `cadence::_annot_tran_supply` reads both halves of the same
  candidate, so these two lines also moved **Alt-Shift-6**, in both directions:
  with only the block's own transient on disk the chord went from showing the
  node voltages to a refusal that names no path at all; with only a chip-level
  transient it went from that refusal to showing the voltages. Nothing measures
  either. It also leaves `$path` and `$lvl` sourced from two different subjects
  when the waveform viewer supplies the file.
* **[0919]** — rows H6 and H13 gold a whole sentence against `xschem get
  statusmsg`, which `cadence::_annot_fit` caps at 255 bytes. At this checkout
  path the sentence is 205 characters, so there are 50 to spare; a worktree or a
  deeper clone false-reds both rows on a correct tree. Filed rather than patched
  because the obvious fix — fitting the expected string too — would truncate away
  the filename the rows exist to check, turning a false red into a silent pass.

### One registration judgement, recorded so it is not re-derived

The suite is in `run_regression.tcl`'s `hcases` but deliberately **not** in
`dcases`, where both sibling annotation suites live. Reason: it was measured
identical on both arms — 15/15 headless and 15/15 on the `:99` dev display with
openbox live — so a second run buys nothing today. The cost of the choice is
that the descended-sheet path is the one annotation path T1 never exercises under
a display. One line in `dcases` reverses it if that ever stops being true.

### No new wording was minted

`There is no results file at $path yet. Run a simulation first.` and
`Loaded results from $path.` (`utils/annot_mode.tcl`) are both existing,
already-ratified sentences. This item only re-points them at the right path.

### Two stale citations, corrected above

§2 cited `select_raw` at `src/xschem.tcl:14471`; it is at **14763**, with the path
built on **14766**. §3 and §4 cited `ase::session_for_current` at
`src/ase.tcl:2351`; it is at **3091** (2351 lands in `ase::cosim_scope_derive`).
`utils/annot_mode.tcl`'s own header carried the same two stale numbers plus a
stale `ase::last_rawfile` (689, really **1253**); all three are fixed there too.
