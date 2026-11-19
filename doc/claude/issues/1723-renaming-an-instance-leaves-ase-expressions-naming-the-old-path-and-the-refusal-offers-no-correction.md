# 1723 — renaming an instance leaves ASE-L's saved expressions naming the old path, and the refusal offers no correction

**STAMP:** `v1 claim=partial tree=f09888cda stamped=2026-11-19 fix=taken open=2 by=crew-R`

Asked by the user on 2026-11-19: build a way out for a user who has no Claude Code to edit the state
files for them. Items 1 to 3 below are the agreed scope. Item 4 is recorded, not scheduled.

## What happened

In `~/dev/hdo-design`, the user renamed the DUT of `fast_buf3_tb` from `x1` to `xdut`. The next Run
was refused:

```
ase: REFUSED — 7 output expressions name something this circuit does not have. ...
ase:   'v(x1.a1)' — voltage 'x1.a1' is not in the netlist
...
ase: set ase_preflight 0 to disable this check (...)
```

The refusal is correct, since a run would have produced the twelve-constants raw. The problem is that
it is a dead end:

- **The stored text never follows a rename.** A session's `outputs`, its measurements' `target`s
  and the files it `.include`s all spell hierarchy paths as literal text (`v(x1.a1)`). Renaming the
  instance in the schematic changes the netlist (`xdut ... fast_buf3`), and nothing rewrites those
  references.
- **The refusal offers no correction for this shape.** `ase::preflight_scan` fills each row's
  `correction` from `ase::netlist_map_resolve`, which knows only a case mismatch (issue 0503).
  `ase::preflight_fixed_expr` and `ase::preflight_fix_session` therefore have nothing to apply, and
  the user is told only how to switch the check off.
- **The repair door is a console command.** Even for a case mismatch, the remedy the refusal names
  is ``ase::preflight_fix_session <key>``, typed into the Tcl console. A user without Claude Code
  will not find it.
- **The refusal names only part of the damage.** `ase::preflight_scan` checks only the cards of
  ticked plain output rows (R-OUT3a). In this bench, 7 measurements (`a1_dis`, `d1_dis`, `tail_dis`,
  `tailb_dis`, `a1_500`, `tail_0`, `tailb_0`) and every `.nodeset` in its two include files also
  named `x1.`, and none of them was mentioned.

The repair that was applied by hand: `x1.` → `xdut.` in both tests' `.state` files and both nodeset
includes, with the dot included. ⚠ **A find-and-replace of the bare word `x1` corrupts the state
file**: the graph record carries axis keys `x1 0 x2 9 y1 -78 y2 36`.

## The plan

1. **Offer a stale-instance correction.** When an identifier's hierarchy prefix (`x1`) is not an
   instance in the netlist, look for the instance in the same parent scope under which the rest of
   the path resolves (`xdut`). Offer it only if exactly one candidate makes **every** refused
   identifier with that stale prefix resolve; otherwise name the candidates and offer nothing. The
   result goes into the scan row's existing `correction` field, so `ase::preflight_fixed_expr` and
   `ase::preflight_fix_session` apply it unchanged, and the refusal prints
   `'v(x1.a1)' -> 'v(xdut.a1)'`.
2. **Put the repair behind a button in ASE-L.** When a refusal carries corrections, ASE-L offers to
   apply them (case-mismatch corrections included). The button does what the console command does:
   it rewrites the session, marks it unsaved, and leaves Save State to the user. This keeps D1's
   rule that corrections apply only on confirmation and never silently. The console command stays,
   and the refusal still names it.
3. **Include measurements, and point out include files.** A measurement `target` naming the same
   stale prefix is corrected along with the outputs and listed in the refusal. A stale measurement
   alone does not refuse a run: refusing on measurements would be a behaviour change nobody has
   ruled on. `.include`d files whose text names the stale prefix are listed by path and count.
   ASE-L never edits them, because they are the user's files.
4. *(Later, not scheduled.)* Offer the rewrite at rename time, when an instance's `name` changes in
   a testbench that has an ASE session. This needs every rename door covered (Edit Properties, the
   attribute editor, `xschem setprop`), so item 1 remains the safety net either way.

## Known limits (accepted for the MVP)

- If the old name now belongs to another instance (for example `x1` renamed to `xdut` and some other
  instance renamed to `x1`), the old prefix still resolves to a scope and no correction is offered.
- Only one renamed segment per identifier is in scope.
- *(Found while building items 1-3.)* The scan reads only what it already read: the cards of ticked
  plain output rows (R-OUT3a). An unticked plain row or an output expression naming the stale prefix
  keeps its text; the unticked row is offered the correction the first time it is ticked and refused.
- *(Found while building.)* A missing instance inside a scope that carries an `.include` card is
  `unknown`, not `absent` (the fix-round ruling in `ase::netlist_map_resolve`), so it neither refuses
  nor is searched for a rename.
- *(Found while building.)* A measurement whose target has a CASE mismatch (not a missing instance) is
  neither listed nor corrected; only measurement fields stranded by a missing instance are.
- *(Found while building.)* The include count reads each file in the state's `includes` key: a nested
  `.include` inside one is not followed, and a file over 8 MB is passed over.

## Status (crew R, 2026-11-19)

Items 1, 2 and 3 are built by the commit that adds this section (its parent is the stamp's `tree=`):

1. `ase::netlist_map_resolve` records where a path stops at a missing instance (`miss`);
   `ase::preflight_rename_try` and `ase::preflight_rename_solve` fill the scan row's existing
   `correction` field only when ONE instance of that scope makes every refused output row with the
   stale prefix resolve (`fit` = `unique`; `several` and `partial` name the candidates and offer
   nothing). The refusal prints `'v(x1.a1)' -> 'v(xdut.a1)'`, and its closing sentences now speak per
   kind: issue 0503 for a case mismatch, "looks like 'x1' was renamed 'xdut'" for a rename. A renamed
   deeper segment falls out of the same code.
2. A Run refused with corrections puts a banner over ASE-L's status bar with **Apply Corrections** and
   **Dismiss** (`ase::ui::repair_after_refusal`, from `ase::ui::run_raised`). The decision is
   `ase::ui::repair_offer`, pure; Apply runs `ase::preflight_fix_session`, which is now
   `ase::preflight_apply` (pure) plus the session write. The console command stays and the refusal
   names both.
3. Measurement fields (`target`, `trig`, `targ`, `when`) stranded by the same missing instance are
   corrected with the outputs and listed in the refusal; they never refuse a run on their own.
   `ase::preflight_include_hits` lists the `.include`d files naming `<prefix>.` by path and count, and
   nothing edits them.

Rows: `PF1723*` in `tests/headless/test_ase_preflight.tcl` (counted, headless) and `FX1723*` in
`tests/headless/test_ase_window.tcl` (display arm). The sabotage sweep is
`doc/claude/issue_1723/receipts/sabotage_sweep.md`.

Still open: **item 4** (unscheduled), and **the button's pixels**: suites green, owed a look
(`owed.sh` look `ase_repair_banner_1723`) and a `:0` run (suite `test_ase_window`).
