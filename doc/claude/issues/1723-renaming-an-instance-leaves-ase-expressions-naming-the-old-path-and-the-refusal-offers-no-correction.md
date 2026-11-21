# 1723 — renaming an instance leaves ASE-L's saved expressions naming the old path, and the refusal offers no correction

**STAMP:** `v1 claim=partial tree=f09888cda stamped=2026-11-21 fix=taken open=3 by=crew-1723i`

Asked by the user on 2026-11-19: build a way out for a user who has no Claude Code to edit the state
files for them. Items 1 to 3 below are the agreed scope. Item 4 is recorded, not scheduled. Items 5
to 7 were ruled on 2026-11-21, after the user hit the include-file half of the same rename (see
"The user's second report" below).

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
   ASE-L never edits them, because they are the user's files. *(Superseded on 2026-11-21 by item 6:
   Apply Corrections now rewrites the resolved `.nodeset`/`.ic` names in them, after asking.)*
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

## The user's second report (2026-11-21)

In `~/dev/hdo-design`, testbench `my_buf3_tb`, the DUT was renamed `x1` → `xdut` again. The Run was
refused, the user pressed **Apply Corrections**, and the next Run died inside ngspice:

```
Error on line 3 or its substitute:
  .nodeset v(out)=1.2 v(x1.a1)=1.5 v(x1.d1)=    1.650000000000000e+00     v(x1.tail)=0.30 ...
 Error: .nodeset syntax error.
    Simulation interrupted due to error!
```

The session's `includes` key held `$::HDO_DIR/lib/hdo_sky130/my_buf3_tb/includes/nodeset_enabled.spice`
(beside a PDK stdcell deck), and that file holds one `.nodeset` card naming `x1.*` over two lines (a `+`
continuation) with values such as `{vsup-1.35}`. Items 1-3 had corrected the session and only *listed*
the file; the refusal printed one console line about it, and the banner said "the refusal lists them".
The user asked: "where are these nodesets hidden? How is a user to find them?" No ASE-L window showed the
`includes` key: Setup > Model Files shows only `models`. (The main session hand-fixed the user's two
files the same day.)

## The ruling (the user, 2026-11-21): items 5, 6 and 7, in one batch

5. **A Setup > "Include Files…" window.** It lists the session's `includes` entries: as stored, the
   resolved path, and whether the file exists. Add, Remove and Open. Open shows the file in XSCHEM's
   own text window. Add and Remove mark the session unsaved. Add stores a portable path the way Model
   Files does. The menu label is a constant proc (the issue 1704 `lbl_run_dir_menu` precedent), and the
   refusal and the banner name this door.
6. **Apply Corrections also fixes the include files, after asking.** A confirmation lists each file and
   its change, and says that files are written at once (not at Save State) and where each backup goes.
   OK: back up each file (`<name>.bak`, then `.bak2`, `.bak3`, …), rewrite it, then apply the session
   corrections; a failed backup or write is said and leaves nothing half-done. Cancel: nothing changes,
   the session included, and the banner stays. D1 stands. Files that are not writable, under the PDK,
   or under a `models` entry's folder are never touched and are named as not editable, by a pure
   predicate whose rule is stated in its header. Only the identifiers inside `.nodeset`/`.ic` cards
   (and their `+` continuations) that the scan resolved to a unique correction are rewritten, every
   other byte kept; other `<prefix>.` hits are counted and listed, never rewritten. Each file is re-read
   at the press and refused if it changed since the scan. `ase::preflight_fix_session` keeps working
   exactly as before, and the file half gets its own console command, named in the refusal.
7. **Stop before ngspice.** A `.nodeset`/`.ic` name in an include file whose path stops at a missing
   instance (`netlist_map_resolve`'s `miss`) refuses the Run, naming the file, the line, the identifier,
   the correction when the rename is unique, and the door. It fires even when every output row is
   already correct. These rows join the rename search like output rows. An absent node inside an
   instance that exists does not refuse; it gets one caution line saying what ngspice will do. The
   `unknown` rule and this file's known limits carry over.

Also ruled: neither the banner nor the refusal may still say "ASE-L does not edit your files";
`ase::ui::repair_offer` stays pure and tested on the counted arm; the act goes on the display arm with
real presses of OK and Cancel; an end-to-end fixture in the user's exact shape runs on
`/usr/bin/ngspice`; and the saved operating point restored as Seed is to be **measured, not built**.

## Measured (2026-11-21)

**What ngspice does with a `.nodeset`/`.ic` name on a node it does not have.** Hand decks on
`/usr/bin/ngspice` (apt 45.2) and the fork (ver_53), with identical results:

| card | value | what ngspice prints | rc | raw |
|---|---|---|---|---|
| `.nodeset` | plain number | `Warning : Nodeset on non-existent node - x1.m, ignored` | 0 | written |
| `.nodeset` | `{...}` | the same warning, then `Error: .nodeset syntax error.` and `Simulation interrupted due to error!` | 1 | none |
| `.ic` | plain number | `Warning : IC on non-existent node - xdut.m, ignored` | 0 | written |
| `.ic` | `{...}` | the same warning, then `Error: .ic syntax error.` | 1 | none |

A plain value is therefore a guess lost without a word in ASE-L, and a `{...}` value is the user's
crash. The same shape through ASE-L with the check switched off (`set ase_preflight 0`, row
`PF1723ah`'s control) dies the same way, with `=== exit 1`.

**The saved operating point restored as Seed (Simulation > Convergence…), after a rename.** Measured
end to end through `ase::run_deck` on `/usr/bin/ngspice`: run 1 on a bench whose DUT is `x1`, with
`opstate {save 1}`, wrote `.ic v(x1.a1) = 1.35` and `.ic v(x1.d1) = 0.9` (wrnodev's own file). The DUT
was then renamed `xdut` and the file restored:

- `mode seed`: the deck carries `.nodeset v(x1.a1) = 1.35` and `.nodeset v(x1.d1) = 0.9`; ngspice
  prints `Nodeset on non-existent node` for both, the run ends `=== exit 0`, the raw is written, and
  ASE-L's pre-flight says nothing.
- `mode force`: the deck carries `.include <file>`; ngspice prints `IC on non-existent node` for both,
  `=== exit 0`, the raw is written.

So the stale names reach the deck and are dropped. The run is never broken by them, because wrnodev
writes only plain numbers. **Not built**: it does not fall out of item 7's scan for free. That scan
reads the `includes` files, and the saved operating point is not one of them. Folding it in would mean
either a refusal nobody has ruled on (the run works today) or a new caution path. Re-saving the
operating point once (Save operating point, one run) replaces the file with the new names. Recorded as
an open question, not a defect.

## Items 5-7 as built (crew 1723i, 2026-11-21)

Built by the commit that adds this section (its parent is the stamp's `tree=`).

**7. The gate.** `ase::preflight_gate` reads the include files once (`ase::include_texts`: binary,
deduplicated by resolved path) and hands them to the scan. `ase::include_card_idents` (pure) gives every
voltage name a top-level `.nodeset`/`.ic` card assigns, through `+` continuations (comment and blank
lines between are transparent, as ngspice drops them before joining), with its line, byte offsets and
value. `ase::preflight_scan` makes an `incrows` row of every one that resolves `absent`; a row with
`miss` refuses and joins `ase::preflight_rename_solve` as a decider beside the output rows (every rename
record now counts `includes`). The refusal head when only include rows refuse is "ase: REFUSED — N
.nodeset/.ic name(s) in M include file(s) stop(s) at an instance this circuit does not have…", which
`ase::preflight_is_name_refusal` reads, so the banner is offered for it. Each name gets a line with the
file, line, card, identifier and correction. The include-hit lines and the closing line name the button,
`ase::preflight_fix_includes <key>` and Setup > Include Files…; no line says "does not edit your files".
A row without `miss` (an absent node inside an instance that exists, or an absent top-level node) is one
caution line from `ase::preflight_include_caution`, which says what ngspice will do (`ase::include_ngspice_clause`,
the table above), and does not refuse. Three shapes stand down entirely: a missing top-level instance
or a top-level node that an include file's own element cards add (`ase::include_top_words`), and a
case-only spelling under `distinguish` (ngspice folds a card's names to lower case, so it reaches the
node).

**6. Apply Corrections, after asking.** `ase::ui::repair_apply` builds the plan
(`ase::preflight_include_plan`) and, when an editable file has edits, opens the confirmation
`ase::ui::repair_confirm` instead of writing anything. Its text is `ase::ui::repair_confirm_lines`
(pure). **OK** (`ase::ui::repair_confirm_ok`) runs `ase::include_apply_plan`: re-read and compare every
file, write every backup (`ase::include_backup_name`; created exclusively, with `lstat` so a dangling
link counts as taken), then write every file; a failure at any step puts back every file written and
deletes every backup made. Then the session corrections of the scan the dialog showed
(`ase::preflight_session_commit`). **Cancel** (`ase::ui::repair_confirm_cancel`) only closes the dialog.
A press whose corrections reach no editable file is the session-only press it was. The predicate is
`ase::include_edit_verdict` (pure, rule in its header) over `ase::include_edit_facts` (the disk) and
`ase::include_protected_roots` (`::PDK_ROOT`, `env(PDK_ROOT)`, and the folder of every `models` entry
and of `::ASE_DEFAULT_MODELS`). The edits are `ase::preflight_include_edits` (pure): only card names
with a unique rename, and only the stale prefix in the name's own spelling (`X1.tail` → `xdut.tail`
under `fold`). `ase::include_rewrite_text` (pure) applies them at byte offsets and raises on a span
that no longer reads as scanned. The console command for the file half is
`ase::preflight_fix_includes <key>`; `ase::preflight_fix_session <key>` is unchanged in what it does
(it is now `ase::preflight_session_commit` of a fresh scan). `ase::ui::repair_offer` stays pure and
gains the plan's counts (`incnames`, `incfiles`, `incblocked`).

**5. Setup > Include Files….** `ase::ui::include_files_dialog`, labelled by
`ase::ui::lbl_include_files_menu` and named by `ase::ui::menu_path_include_files` (the engine's literal
fallback, `ase::preflight_include_door`, is held equal by row `PF1723w`). Rows come from
`ase::include_rows` (pure) against `ase::include_rundir_peek`, which never calls `ase::rundir`, so
opening the window creates no folder. Add stores the path as typed (`ase::include_add`), Remove takes
the selected rows (`ase::include_remove`), and both go through `ase::session_update`, so the session
goes unsaved. **Open uses `textwindow`**: `edit_file` hands the file to an external `$editor` when one
is executable, which is not XSCHEM's own window; `editdata` is modal and returns text to its caller,
with only "Save a copy"; `viewdata` shows data with only Save As. `textwindow` takes a file name, shows
it in XSCHEM's text widget, and its Save writes back to that file. A file Apply Corrections may not
touch opens without Save. **Found and fixed while building:** `textwindow`'s Save was a braced script
reading the globals of whichever text window opened last, so with two open, Save in the first wrote the
second's text and closed the second (row `FX1723If`; now `textwindow_save`, bound per window). Its
duplicate `open` before the guarded one, which leaked a channel per call and raised on an unreadable
file, is gone.

Rows: `PF1723r`-`PF1723ah2` in `tests/headless/test_ase_preflight.tcl` (counted, headless; `PF1723ah`
is the user's shape end to end on `/usr/bin/ngspice` through the console command), and the `FX1723I`,
`FX1723C` and `FX1723E` bands in `tests/headless/test_ase_window.tcl` (display arm, real presses;
`FX1723Cc` is Cancel leaving the session, its state file and every include file byte-identical,
`FX1723Cf` is an OK whose session half raises putting every file back through
`ase::include_unapply`, and `FX1723E` is the same end-to-end fixture by Run, Apply, OK, Run). Rows `PF1723c`, `p`, `l2`, `n2`,
`o2` and `FX1723d` moved with the ruling and say so where they stand; `FX1723`'s include now sits in a
model file's folder, so its press stays the session-only one. The sabotage sweep is
`doc/claude/issue_1723/receipts/sabotage_sweep_items_5_7.md`.

## Known limits of items 5-7 (accepted)

- The carried-over limits still hold: a nested `.include` inside an include file is not followed, a
  file over 8 MB or unreadable is passed over, and a missing instance inside a scope carrying an
  `.include` card is `unknown`, so it neither refuses nor is searched.
- **The PDK is found only by `::PDK_ROOT` and `env(PDK_ROOT)`**, plus the folders of the `models`
  entries and of `::ASE_DEFAULT_MODELS`. The sky130A workarea sets `::PDK_ROOT`; the gf180mcuD and
  ihp-sg13g2 workareas set neither (measured 2026-09-08, `src/op_param_lists.tcl`'s PDK-identity
  comment). A PDK file outside those folders is judged by its permissions alone.
- **An include row that disagrees with the outputs costs the outputs their correction.** Include rows
  decide like output rows (the ruling), so an output naming `x1.a1` (only `xdut` has `a1`) and a
  `.nodeset` naming `x1.b1` (only `xother` has `b1`) are a `partial` fit and nothing is offered (row
  `PF1723s3`). Before item 7 the outputs alone decided.
- Only `v(...)` names are read; a card inside a `.subckt` body of an include names that subcircuit's
  own nodes and is not read; an inline `;` or ` $` comment ends what is read of a line.
- An absent top-level node is a caution, not a refusal: an include file may add it, and the scan stands
  down only when an include file's own element card connects it.
- Open goes through the stock `textwindow`: its Save writes in text mode, so a CRLF file comes back
  LF, and "read only" means no Save button (the text can still be typed into, but not written).
- The Include Files window is refilled when it opens and after its own Add and Remove; a Session >
  Revert while it is open leaves its rows stale until it is reopened.
- Apply Corrections writes the files before the session; the session half is in-memory and is undone
  with the files if it raises.

Still open: **item 4** (unscheduled); **the pixels** of the Include Files window and the confirmation
(suites green, owed a look and a `:0` run of `test_ase_window`); and the saved-operating-point question
above.
