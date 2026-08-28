# 0911 — on a DESCENDED sheet with no ASE-L session, `6` never repairs, and the only escape now tells the user a false sentence

STATUS: OPEN — measured 2026-08-28 by item A15's adversary pass and re-measured
by A15's write-up agent on the delivered tree before filing.
FOUND IN: `cadence::_annot_raw_candidate`'s `netlist_dir` fallback,
`utils/annot_mode.tcl:151-186` — the candidate is built from
`xschem get schname`, i.e. the sheet the user is standing on — consumed by
`op_annot::db_current`'s guard G4 (`src/op_annot.tcl`).
RELATED: [0684](0684-annot-ensure-loaded-guards-on-the-wrong-predicate.md) §8
(route table corrected there),
[0910](0910-an-operating-point-attached-from-outside-is-trusted-forever-at-the-same-path.md).

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
SHIPPED `select_raw` spelling (`src/xschem.tcl:14471`), deliberately kept
identical there. On a descended sheet `schname` is the **subcell**, so the
candidate is `.../sub.raw` while the attached database is `.../top.raw`. Guard G4
sees candidate ≠ attached path and answers *"not mine, leave it exactly where it
is"* — the arm that exists to stop one corner's operating point being destroyed
by a press about another (issue 0908). Correct rule, wrong input.

The candidate is a pre-existing spelling; what is new is that **currency now
depends on it**, so a candidate that was merely a fallback for "which file would
I load" is now also deciding "are the numbers on screen the right ones".

## 3. Why an ASE-L session rescues it

`ase::session_for_current` (`src/ase.tcl:2351`) walks the **hierarchy stack**, so
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
