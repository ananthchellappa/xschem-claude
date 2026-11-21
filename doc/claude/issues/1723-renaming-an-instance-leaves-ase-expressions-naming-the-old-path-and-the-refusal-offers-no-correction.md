# 1723 — renaming an instance leaves ASE-L's saved expressions naming the old path, and the refusal offers no correction

**STAMP:** `v1 claim=partial tree=f09888cda stamped=2026-11-21 fix=taken open=3 by=port-1723`

Asked by the user on 2026-11-19: build a way out for a user who has no Claude Code to edit the state
files for them. Items 1 to 3 below are the agreed scope. Item 4 is recorded, not scheduled. Items 5
to 7 were ruled on 2026-11-21, after the user hit the include-file half of the same rename (see
"The user's second report" below).

This file and its code were built in `~/private/xschem-private` and ported to this branch at the
user's request: see "Ported from the private clone" at the foot before reading a commit id here.

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

Items 1, 2 and 3 are built by `e73fb41ae` (its parent is `777efaf24`):

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
crash. *(The fix round below widened "`{...}`" to every value that is not a plain number; the first
table measured only those two shapes.)* The same shape through ASE-L with the check switched off (`set ase_preflight 0`, row
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

Built by `ed635d969` (its parent is `a464b7f6b`). The first fix round below is `2f1b8bca7`; the second
is its child, the commit that adds the "Fix round 2" section.

**7. The gate.** `ase::preflight_gate` reads the include files once (`ase::include_texts`: binary,
deduplicated by resolved path) and hands them to the scan. `ase::include_card_idents` (pure) gives every
voltage name a top-level `.nodeset`/`.ic` card assigns, through `+` continuations (comment and blank
lines between are transparent, as ngspice drops them before joining), with its line, byte offsets and
value. *(⚠ False for a line that starts with `;` once its leading blanks are gone: ngspice reads that as a
card, which ends the `.nodeset`. Fix round 3, finding 1.)* `ase::preflight_scan` makes an `incrows` row of every one that resolves `absent`; a row with
`miss` refuses and joins `ase::preflight_rename_solve` as a decider beside the output rows (every rename
record now counts `includes`). The refusal head when only include rows refuse is "ase: REFUSED — N
.nodeset/.ic name(s) in M include file(s) stop(s) at an instance this circuit does not have…", which
`ase::preflight_is_name_refusal` reads, so the banner is offered for it. Each name gets a line with the
file, line, card, identifier and correction. The include-hit lines and the closing line name the button,
`ase::preflight_fix_includes <key>` and Setup > Include Files…; no line says "does not edit your files".
A row without `miss` (an absent node inside an instance that exists, or an absent top-level node) is one
caution line from `ase::preflight_include_caution`, which says what ngspice will do (`ase::include_ngspice_clause`,
the table above), and does not refuse. Three shapes stood down entirely: a missing top-level instance
or a top-level node that an include file's own element cards add (`ase::include_top_words`), and a
case-only spelling under `distinguish` (ngspice folds a card's names to lower case, so it reaches the
node). ⚠ **The third claim was false**, and the fix round below withdrew it: under `distinguish` the
case-keeping fork does not fold a card's names (measured), so that spelling is now a caution.

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
(it is now `ase::preflight_session_commit` of a fresh scan). *(⚠ That was false under `fold`, in this
commit and the first fix round: two spellings of a stale prefix were one rename group, which changed
what the command does for a session with no include file. Fix round 2, finding 7, put it back.)* `ase::ui::repair_offer` stays pure and
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
touch opens without Save. *(Fix round 2, finding 5: now only a file the user cannot write does; the
refusal had sent the user to this window to change such a file by hand.)* **Found and fixed while building:** `textwindow`'s Save was a braced script
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
  own nodes and is not read; an inline `;` or ` $` comment ends what is read of a line. *(The fix
  round below made the comment rule ngspice's own, `//` and `#` lines included; fix round 2 added `$`
  comment lines, `v (...)` with a blank, and the `\\` continuation.)*
- An absent top-level node is a caution, not a refusal: an include file may add it, and the scan stands
  down only when an include file's own element card connects it.
- Open goes through the stock `textwindow`: its Save writes in text mode, so a CRLF file comes back
  LF, and "read only" means no Save button (the text can still be typed into, but not written).
  *(Fix round 2: read only now means a file the user cannot write, and Save asks before it writes over
  a file that changed since the window read it.)*
- The Include Files window is refilled when it opens and after its own Add and Remove; a Session >
  Revert while it is open leaves its rows stale until it is reopened.
- Apply Corrections writes the files before the session; the session half is in-memory and is undone
  with the files if it raises.

## Fix round (2026-11-21): the review's confirmed findings

A review of the items 5-7 commit (`ed635d969`) confirmed thirteen findings, nine distinct defects. Each
was made a row first, watched red on that commit's code, then fixed. The sabotage sweep is
`doc/claude/issue_1723/receipts/sabotage_sweep_fix_round.md`.

**Measured for this round** (hand decks, `HOME` throwaway, no `.spiceinit`), a `.nodeset` name on a
node that the existing instance `xdut` does not have. `/usr/bin/ngspice` 45.2 and the fork ver_53 agree
on every line. A name under a missing instance (`x1.q`, on 45.2) splits the same way for `1.5`,
`{0.4}`, `'vsup'` and `vsup`, because one branch of ngspice's parser handles both shapes:

| value | what ngspice does | rc |
|---|---|---|
| `1.5`, `-0.1`, `+1.5`, `.5`, `5.`, `1.5m`, `1.5meg`, `1e-3`, `1e+3`, `1.5V`, `1.5e-3V`; blanks around `=` or not | `Warning : Nodeset on non-existent node`, the name is dropped | 0 |
| `{0.4}`, `{vsup}`, `{vsup-0.1}`, `'vsup-0.1'`, `'1.5'`, the bare parameter `vsup` | the warning, then `Error: .nodeset syntax error.` | 1 |
| empty (`v(xdut.nosuch)=`) | `Expression err`, `Cannot compute substitute`, fatal | 1 |
| `.ic` with `1.5` / with `{0.4}`, `'vsup'`, `vsup` | the same split, `.ic syntax error.` | 0 / 1 |

and, on the same decks:

- `.nodeset` alone on its line (LF), names on `+` lines: joined, and a `{...}` value on a missing node
  dies as above.
- `.nodeset v(b)=0.5 // v(x1.q)={0.4}`, `... 0.5//v(...)`, `... ; v(...)` and `... $ v(...)`: rc 0
  with no warning, so the name behind the comment never reaches the simulator.
- A `#` line between a card and its `+` continuation, at column 0 or indented, is a comment line: the
  card is joined across it.
- `-D casemode=distinguish -D casemodewrite` on the fork (the flags ASE-L passes), `xdut` in the
  netlist: `v(XDUT.mid)={0.4}` and `v(xdut.MID)={0.4}` give the warning and then the syntax error (rc 1).
  `v(XDUT.mid)=0.4`, `v(xdut.MID)=0.4` and `.ic v(XDUT.mid)=0.4` give the warning only (rc 0).
  `v(xdut.mid)={0.4}` runs clean. Under `casemode=fold`, and with no flag, every spelling reaches the
  node.

The fixes:

1. **A keyword alone on its line was never read** (findings 1 and 11). The early out in
   `ase::include_card_idents` ran without `-line`, so its `$` meant the end of the text, and `.nodeset`
   followed by LF matched nothing; only CRLF files worked. It now ends on `\s`. Rows `PF1723r3` and
   `PF1723s7`.
2. **The case-only stand-down rested on a false claim** (finding 2). Under `distinguish` a name that the
   netlist has in another case (or that differs in case from two netlist names) is now an include row
   without `miss`: one caution naming the netlist's spelling ("which the netlist spells 'xdut.a1':
   under case mode distinguish ngspice does not fold case, so …"). It neither refuses (the ruling refuses
   only on a missing instance) nor is rewritten. Row `PF1723s4` moved and says why; the leg is
   `PF1723s4b`.
3. **`//` comments, quoted values and `#` lines** (finding 3, plus the `#` line found while fixing it).
   `ase::spice_comment_at` (pure) is a port of ngspice's `inp_stripcomments_line` outside `.control`:
   `;` anywhere but the first character, `//`, `$` after a blank, tab or comma, with quoted stretches
   skipped. Both readers cut each physical line with it. A line that is only a comment, or starts with
   `*` or `#`, is transparent. Rows `PF1723r4`, `PF1723r5` and `PF1723s7`.
4. **The caution said "dropped" for values that stop the run** (finding 4). `ase::include_value_plain`
   (pure) says whether a value is a plain number, and `ase::include_ngspice_clause` says the run stops
   for every other value, quoting it ("because such a name's value must be a plain number and this one
   is 'vsup'"). The refusal head now says the same: "…when its value is a plain number, and stops the
   run with a syntax error when it is anything else (a {...} or '...' expression, or a parameter
   name)". Rows `PF1723u3`, `PF1723t` and `PF1723u`.
5. **A failed write could destroy the only copy and then say all was well** (findings 5 and 7).
   `ase::include_apply_plan`'s failure arm now skips a file that still reads as it was
   (`ase::include_reads_as`), writes the others back (`ase::include_write_bytes`), and deletes a backup
   only after its file is back. If any file could not be put back, the sentence names each one with its
   error and its kept backup ("…so their backups are kept as the only copy of what they held: …").
   `ase::include_unapply` uses the same writer. Row `PF1723ad3`: a full disk (`/dev/full`, larger than a
   channel buffer) after the truncation, with one leg where the other file goes back and one where it
   does not. `PF1723ad2` still holds.
6. **The backup took the umask's mode** (finding 6). `ase::include_backup_write` creates it exclusively
   at 0600 and, once it is complete, gives it the original's permissions. Row `PF1723ac4` (0640 and
   0600).
7. **A backup that failed after its open was left behind with its channel open** (finding 8). The same
   proc closes the channel and removes a backup it created. Row `PF1723ad4`.
8. **A symlinked PDK root protected nothing** (findings 9 and 13). `ase::include_protected_roots` lists a
   PDK root both as spelled and resolved through its last component. Row `PF1723y4` covers
   `::PDK_ROOT` and `env(PDK_ROOT)` with a trailing slash.
9. **A nested include's instance was refused as missing** (finding 10). `ase::include_top_nests` (pure)
   finds the `.include`, `.inc` and `.lib` cards at an include file's own top level (the keywords
   `ase::netlist_map` counts). While there is one, a missing top-level instance or node is `unknown`,
   as in any scope carrying an include card, so it neither refuses nor cautions. Row `PF1723s5`: the
   bench ngspice runs, the control without the nested card, a deeper missing instance that still
   refuses, and an include inside a `.subckt` body that does not count.
10. **The fixtures lacked the user's real include list** (finding 12). `PF1723s6` (counted, a scan and a
    gate) and the end-to-end `PF1723ah` and `FX1723E` now put a stdcell deck first. Its `.subckt` and
    `.SUBCKT` bodies are full of `X1` element cards, and every entry is a `$::VAR` path. Breaking
    `ase::include_top_words`' depth, or skipping `$::VAR` entries in `ase::include_texts`, now reddens
    them.

## Known limits of the fix round (accepted)

- **A case-only spelling under `distinguish` is said, not fixed.** The caution names the netlist's
  spelling. The Run is not refused and Apply Corrections does not rewrite it: item 6 rewrites
  rename corrections only, and no ruling covers a case rewrite of a user's file.
- **A nested include at an include file's top level silences every missing top-level name.** It is the
  `unknown` rule, and it is coarse: the nested file is still not followed, so a `.nodeset` on a stale
  top-level `x1.` beside such a card is not refused either. A missing instance deeper than the top level
  still refuses.
- The comment port covers ngspice outside `.control` with the PS compatibility mode off. Inside a
  `.control` block, `$` is a comment only before a blank. `newcompat.ps` turns the `$` rule off. Neither
  is modelled, and neither is a place for a `.nodeset` card.
- Where the platform has no `file attributes -permissions` (Windows), a backup stays 0600.
- The stdcell deck in the user's bench (`$::SKYWATER_HVL_STDCELLS/...`) lies under neither PDK root nor
  a models folder, so it is judged by its permissions alone, and Open shows it with Save. Apply never
  writes it, because it carries no `.nodeset`/`.ic` card.

## Fix round 2 (2026-11-21): the second review's confirmed findings

A review of the first fix round (`2f1b8bca7`) confirmed fourteen findings, thirteen distinct (8 and 10
are one defect). Twelve are fixed below. Finding 14 was this file's own commit pointers, fixed in the
two "built by" sentences above.
Each code defect is a row first, watched red on `2f1b8bca7`'s code (10 FAILED of 328 on the counted
arm; `FX1723Ie` and `FX1723Ih` red on the display arm), then fixed. The rows that cover an arm the
code already had right were proved by sabotage instead. The sweep is
`doc/claude/issue_1723/receipts/sabotage_sweep_fix_round_2.md`.

**Measured for this round** (hand decks, `HOME` throwaway, `DISPLAY` unset). The netlist has `xdut`
with an internal node `m`, and the deck `.include`s a file holding the card. On `/usr/bin/ngspice`
45.2 unless the row names the fork (ver_53, with `-D casemode=distinguish -D casemodewrite`, the flags
ASE-L passes):

| the include holds | what ngspice does | rc |
|---|---|---|
| `.nodeset v(b)=0.5`, `$ a note about x1`, `+ v(x1.q)={0.4}` | joined across the `$` line ("Please check line .nodeset v(b)=0.5 v(x1.q)=…"), the warning, then `.nodeset syntax error` | 1 |
| the same with the `$` line indented | the same | 1 |
| `$ x1 was the dut before the rename`, `.nodeset v(x1.a1)={0.4}` | "Unusual leading characters like '$'" (a warning only), then the same | 1 |
| `.nodeset v(b)=0.5`, `$ a note`, `+ v(xdut.nosuch)=0.4` | joined: "Nodeset on non-existent node - xdut.nosuch" | 0 |
| `.nodeset v (x1.q)={0.4}` / `.ic v (x1.q)={0.4}` | the warning naming `x1.q`, then the syntax error | 1 |
| `.nodeset v ( x1.q ) = 0.4` | the warning, the name dropped | 0 |
| `.nodeset v (xdut.m)={0.4}` | clean | 0 |
| `.nodeset v(b)=0.5 \\` then `v(x1.q)={0.4}` | joined, the warning, then the syntax error | 1 |
| the same with `; a note` before the `\\`, or blanks after it | joined, rc as above | 1 |
| `.nodeset v(b)=0.5`, `# a hash note \\`, `v(xdut.nosuch)=1` | joined (a `#` line's `\\` continues) | 0 |
| `.nodeset v(b)=0.5`, `* a star note \\`, `+ v(xdut.nosuch)=1` | the `*` line continues nothing; the `+` line joins `.nodeset` | 0 |
| `.nodeset v(b)=0.5 \\` then `* now a continuation` | the `*` line is joined into the card, and the syntax error | 1 |
| fork: `v(xdut.M)={0.4}`, `v(XDUT.m)={0.4}` | the warning, then the syntax error | 1 |
| fork: `v(xdut.m)={0.4}` | clean | 0 |
| a top-level node `out.p` (`xdut in out.p amp`, `R2 out.p 0 1k`) and `.nodeset v(out.p)=0.5` or `={0.5}` | applied, no warning (`out.p = 5.000000e-01`) | 0 |

Read against ngspice's source (ver_53, `src/frontend/inpcom.c` and `src/spicelib/parser/inppas3.c`):
`chk_for_line_continuation` blanks a trailing `\\` (not on a line whose column 0 is `*` or `$`) and
prefixes `+` to the next line, before comments are stripped; `inp_stripcomments_line` never cuts a `$`
at column 0; `inp_stitch_continuation_lines` skips any line whose first non-blank character is `#`, `$`
or `*` without ending the card; INPpas3 reads a card as tokens split on blanks, `=`, `(`, `)` and `,`.

The fixes:

1. **A `$` comment line cut the card, and its words stood item 7 down** (finding 1). The readers now
   share one line reader, `ase::spice_lines` (pure), a port of the three passes above in their order.
   A `$` line is transparent to `ase::include_card_idents` and adds no word to `ase::include_top_words`.
   `ase::include_top_nests` reads the same card lines. Row `PF1723r6`.
2. **`v (x1.q)` was never read** (finding 2). `ase::preflight_ident_spans` takes `gap`, and the card
   reader passes 1, so blanks may stand between `v` and its paren. Output expressions keep the old
   reading: nothing measured says the frontend reads `v (out)` as a vector. Row `PF1723r7`.
3. **The `\\` continuation was not followed** (finding 3). It is pass 1 of `ase::spice_lines`, and the
   offsets stay the file's own. Row `PF1723r8`.
4. **Under `distinguish` the press wrote only the prefix** (finding 4). `x1.A1`'s correction is `xdut.a1`,
   but the edit wrote `xdut.A1`, which the case-keeping fork dies on. `ase::include_name_fix` (pure) now
   writes the whole name as the row's correction when the rest is mis-cased too (`whole 1`). The
   refusal offers that spelling (`ase::include_name_fixed`), and the confirmation says "1 × x1.A1 →
   xdut.a1". Under `fold` only the prefix moves, as before. Row `PF1723s9`.
5. **The refusal sent the user to a window that could not save** (finding 5). Open now opens a file
   read-only only when the user cannot write it: "never touched" is the press's rule, not the user's.
   A plan record carries `writable`, and for a read-only file the refusal and the console command say
   "make it writable, then change it by hand (Setup > Include Files…)" (`ase::include_hand_first`).
   Rows `PF1723t5` and `FX1723Ie` (moved), plus `FX1723Ie3`.
6. **A node whose own name holds a dot was refused, and Apply would have "corrected" it** (finding 6).
   Where the instance walk misses, `ase::netlist_map_resolve` first asks whether the rest of the name
   is a node of that scope. An instance path that resolves is unchanged. Row `PF1723s8`.
7. **`ase::preflight_fix_session` had changed under `fold`** (finding 7). `ase::preflight_rename_solve`
   groups by the stale prefix as written again, as it did at `a464b7f6b`. `ase::preflight_rename_said`
   (pure) lets one sentence speak for spellings that fold together and agree, so the refusal and the
   banner do not say the same rename twice. Row `PF1723s10`.
8. **`ase::preflight_fix_includes` said there was no correction right after naming one** (findings 8
   and 10). When every correction sits in a file ASE-L may not edit, it now says so: "the 2
   .nodeset/.ic names with a correction are in 1 include file ASE-L may not edit, named above". Row
   `PF1723af3`.
9. **The refusal's not-editable, mixed, resolved-only and door-only arms had no row** (finding 9). Row
   `PF1723t4` asserts each whole line, and that none of them carries the banned sentence. Each arm's
   sabotage reddens it.
10. **`PF1723ag3` could not see a folder being created** (finding 11). It now peeks at a missing run
    directory and, for an empty `rundir`, a missing `::netlist_dir`. Both must still be missing
    afterwards, and `::netlist_dir` must not have moved.
11. **Remove's "marks the session unsaved" was never measured** (finding 12). Row `FX1723Id2` saves the
    session first and then presses Remove.
12. **A text window from Include Files silently undid Apply Corrections** (finding 13).
    `textwindow` keeps what it read, and `textwindow_save` asks (`textwindow_ask_overwrite`) before it
    writes over a file that changed since: `textwindow_disk_changed` decides it. A "no" keeps the
    window and writes nothing. This is the stock text window, so every XSCHEM door that opens one
    with Save gets the question. Rows `PF1723ai` (the decision, counted) and `FX1723Ih` (the presses).
13. **End to end** (`PF1723ah3`, `/usr/bin/ngspice`): an include holding a `$` line inside its card,
    `v (x1.d1)` and a `\\` continuation is refused before ngspice. With the check off, ngspice dies on
    the syntax error. After `ase::preflight_fix_includes`, all three names are rewritten and the run
    finishes with no nodeset warning.

## Known limits of fix round 2 (accepted)

- **Under `fold`, two spellings of one stale prefix are decided apart**, as before items 5-7. So
  `x1.a1` → `xdut.a1` and `X1.b1` → `xother.b1` can both be offered, although ngspice sees one
  instance. This is the behaviour the ruling kept for the console command.
- **A dotted node name is looked up only where the instance walk misses**, and only for a voltage. If
  a scope has both an instance `out` with a node `p` and a node `out.p`, the instance path wins.
- **The line reader models ngspice outside `.control` and with PS compatibility off**, as the comment
  port already did. A `*` line joined into a card by a `\\` before it is read like any continuation;
  ngspice dies on such a card anyway.
- **The text window's question compares the file's text as read in text mode.** A change in line ends
  alone (CRLF ↔ LF) is not seen. The window keeps a copy of what it read while it is open.
- **`G2sens` in `test_ase_dialogs` is red on the display arm**, the same row and values at
  `a464b7f6b`, at `2f1b8bca7` and here. That is issue 1436, not this one.

## Fix round 3 (2026-11-21): the third review's confirmed findings

A review of fix round 2 (`96c8ec091`) confirmed ten findings, nine distinct defects (3 and 8 are one).
All ten are fixed below. Each is a row that was written first and watched red on `96c8ec091`'s code:
21 FAILED of 349 on the counted arm, the 328 older rows all green, and `FX1723Cb3` and `FX1723Ce3` red
on the display arm. The sabotage sweep is `doc/claude/issue_1723/receipts/sabotage_sweep_fix_round_3.md`.

**Measured for this round** (hand decks, `HOME` throwaway, `DISPLAY` unset). The deck holds `xdut`
(`.subckt sub p q`, internal node `a1`) and no `x1`, and `.include`s a file holding the card.
`/usr/bin/ngspice` 45.2 and the fork (ver_53, run with `-D casemode=distinguish -D casemodewrite`) agree on
every line except the BOM line:

| the include holds | what ngspice does | rc |
|---|---|---|
| `.nodeset v(b)=0.3`, then `  ; note` (or a tab before `;`, or ` ;note`), then `+ v(x1.r)={2}` | the `;` line is a card that ends the `.nodeset`; the `+` line joins the `;` card, which becomes a comment. No warning for `x1.r` | 0 |
| the same with `  * note` in the middle | joined across the `*` line: the warning for `x1.r`, then the syntax error | 1 |
| `.nodeset v(b)=0.3`, `  * note \\` (or `  $ note \\`), then `R9 out 0 1meg` | the indented comment continues nothing, so the element card is not joined | 0 |
| `.nodeset v(b)=0.3 \\`, then `R9 out 0 1meg` (the control) | joined, and the syntax error | 1 |
| `.nodeset all=0.5 v(x1.q)={vsup}` | no warning: nothing after `all=` is read | 0 |
| `.nodeset all=0.5`, then `+ v(x1.q)={vsup} v(xdut.q)=0.2` | the same | 0 |
| `.nodeset v(x1.q)={vsup}` (the control) | the warning, then the syntax error | 1 |
| `.ic all=0.5 v(xdut.q)=1` | `.ic syntax error` at `all` (`.ic` has no `all` form) | 1 |
| `.nodeset v(b)=0.3 v(xdut.nosuch)=`, then `+ 1.5` | joined to `v(xdut.nosuch)=1.5`: the warning, and the name dropped | 0 |
| the same with `v(xdut.nosuch)`, then `+ =1.5` | the same | 0 |
| `<UTF-8 BOM>.nodeset v(b)=0.3 v(x1.r)={2}`, on line 1 | ver_53: "encoding: UTF-8 with BOM", the warning, the syntax error. 45.2: "unknown device type" | 1 / 1 |
| `<BOM>* hdr`, then `.nodeset v(b)=0.3 v(x1.r)={2}` | ver_53: the warning, then the syntax error | 1 |
| `.if (sel == 1)` / `.nodeset v(xalt.a1)={vsup-0.1}` / `.else` / `.nodeset v(xdut.a1)={vsup-0.1}` / `.endif`, with `sel=0` | the branch is not taken; no warning | 0 |
| the same with `.if (sel == 0)` | the warning for `xalt.a1`, then the syntax error | 1 |

Read against ngspice's source (ver_53): `readline()` in `src/frontend/inpcom.c` drops the blanks, tabs and
carriage returns a line starts with, before every pass the 1723 reader ports. `inp_stripcomments_line`
never cuts a `;` at index 0. `inp_stitch_continuation_lines` treats a `;`-led line as a regular card, and
`inp_check_syntax` later turns it into a `*` line. `inp_read` strips a UTF-8 BOM from a file's first line.
In `src/spicelib/parser/inppas3.c`, INPpas3's `.nodeset` loop handles `all` by setting every node and then
`break`ing out of the card. `src/frontend/inp.c`'s `recifeval` comments out every `.if` branch that is not
taken.

The fixes:

1. **An indented `;` line was read as a comment line** (finding 1). `ase::spice_lines` now drops the
   leading blanks first, as `readline()` does, so every column-0 test reads the first character after
   them. `  ; note` is now a card that ends the `.nodeset`, and an indented `* note \\` continues
   nothing. `ase::include_top_words` takes no element word from a card ngspice turns into a comment
   (a leading `;`, or one of the "unusual leading characters"), at column 0 or indented. Rows
   `PF1723r9`, `PF1723r10`, `PF1723r11` and `PF1723s11` (the finding's bench: no refusal, nothing to
   rewrite).
2. **Names after `.nodeset all=<v>` were read** (finding 2). `ase::include_card_names` (new, pure) reads
   one stitched card the way INPpas3 does. On a `.nodeset` card it reads nothing after an `all` that
   stands as a word of its own, outside every name, value, `{...}` and quoted stretch. `.ic` is unchanged.
   Rows `PF1723r13` and `PF1723s12`.
3. **The two console halves depended on their order** (findings 3 and 8). `ase::preflight_strand` (new,
   pure) computes the re-scan one half alone would leave and names every correction the other half would
   lose. `ase::preflight_fix_includes` refuses when its rewrite would cost the session half a correction:
   nothing is written, and the sentence names the loss and `ase::preflight_fix_all <key>`.
   `ase::preflight_fix_session` writes exactly what it always wrote (the ruling). When that costs the
   include half a correction, it prints a note naming every such name with the correction it just lost,
   so the user can make it by hand, and names `ase::preflight_fix_all`. `ase::preflight_fix_all <key>`
   (new) applies both halves from one scan through `ase::preflight_commit_both`, which the window's OK
   now runs too. OK logs that one command, where it used to log the two halves. The refusal names
   `ase::preflight_fix_all` whenever both halves carry corrections, and keeps the file half's own
   sentence when only the files do. Rows `PF1723aj` to `PF1723aj5`, `PF1723t6`, and `FX1723Ce3` (display
   arm).
4. **A value on the next `+` line was read as no value** (finding 4). `ase::include_card_names` joins
   the card's lines with one blank each, as `inp_stitch_continuation_lines` does, and reads the value
   from the joined text. Every offset still maps back to the file. Row `PF1723r14` covers both shapes, a
   blank line and a comment line between, and the caution, which now says "drops it".
5. **A UTF-8 BOM hid the whole file** (finding 5). `ase::spice_lines` drops the BOM from line 1, as the
   fork does, and the early out allows it. Row `PF1723r12` covers the reader, its offsets and the gate on
   a file written binary.
6. **A `.if` branch not taken was refused and offered for rewriting** (finding 6).
   `ase::include_card_idents` marks every card inside a `.if` ... `.endif` block `cond 1`, nested blocks
   included. `ase::preflight_scan` keeps such a row's missing instance as `condmiss`, not `miss`, so it
   neither refuses, nor joins the rename search, nor is rewritten. Its caution says "inside a .if block,
   which ASE-L does not evaluate, and the netlist has no instance 'xalt': if that branch is taken, ngspice
   stops the run with …". Rows `PF1723r15` and `PF1723s13`.
7. **A symlinked model file left its real folder unprotected** (finding 7).
   `ase::include_protected_roots` now lists a models entry's folder as spelled and as resolved through its
   last component, the PDK roots' rule. The header's claim that a models folder "needs no second form" is
   withdrawn in place. Row `PF1723y5`.
8. **Under `fold`, a hit line could quote a spelling the file does not hold, and an empty target**
   (finding 9). In `ase::preflight_include_hits`, the spellings of one folded group speak as one only when
   their rename records agree on one target. One record, counted case-blind, quotes the first spelling the
   file itself holds. When the records disagree, each spelling the file holds is its own record with its
   own target, and the gate counts each line's names against that target only. Rows `PF1723t7` (the
   finding) and `PF1723t8` (two spellings with two targets). `PF1723l`, `l2` and `t4` hold the agreeing
   case.
9. **A shared include file was rewritten with no word about the others** (finding 10).
   `ase::include_sharers` (new) names every other state of the same library, `<lib>/*/*/*.state`, whose
   `includes` resolve to the same file, by any spelling and through a link to the file itself.
   `ase::ui::repair_apply` puts the result on the plan (`ase::include_plan_shared`). The confirmation adds
   "Shared: 2 other states of this library include it too (…), and they will read the new names.", and the
   console commands say the same after they write. Rows `PF1723ak` and `PF1723ak2`, and `FX1723Cb3` on the
   display arm, with a real second state view.
10. **End to end** (`PF1723ah4`, `/usr/bin/ngspice`, check ON): an include holding an indented `;` line
    before a `+` line, a `.nodeset all=` card and a `.if (0)` branch, all naming `x1.` with `{...}` values,
    is no longer refused. It reaches ngspice and finishes at exit 0 with no nodeset warning, the `.if` card
    is one caution, and the file is untouched. On `96c8ec091` this bench was refused before ngspice.

## Known limits of fix round 3 (accepted)

- **A `.if` condition is never evaluated.** Every absent name inside any `.if` block is a caution on every
  Run, even in a branch ngspice will never take, and it is never refused or rewritten, even in the branch
  that is taken. A rename that strands names inside such a block is said, and the user changes those names
  by hand (Setup > Include Files…).
- **`ase::preflight_fix_session` can still cost the include half its correction.** The ruling keeps what it
  writes unchanged, so it applies and then says so: a note names every include name it stranded, with the
  correction to make by hand. `ase::preflight_fix_all` is the console command that cannot strand either
  half. `ase::preflight_fix_includes` refuses rather than strand.
- **The strand check compares corrections, not states.** It asks whether every correction this scan offers
  the other half is still offered after a re-scan, read from the texts this scan read. A file edited
  between the two commands is not seen until the next scan.
- **The sharer search covers one library.** `ase::include_sharers` reads `<lib>/*/*/*.state` of the
  session's own library, and only when the session's state file has that shape, with its design cell as
  `<cell>`. A state in another library, or an open session's unsaved `includes`, is not seen. A relative
  include of another state resolves against that state's own run directory (peeked, never created).
- **The BOM rule is UTF-8 only.** A UTF-16 file (which the fork also strips and reads) is not modelled. The
  apt 45.2 build does not strip a BOM and dies on such a file anyway, so a refusal is right on both.
- **`.nodeset all` is read as a word of its own** outside every `v(...)` name with its value, `{...}` and
  quoted stretch. The model does not follow ngspice's tokenizer any further. A syntax error before `all`
  ends ngspice's reading too, and the run dies anyway.

Still open: **item 4** (unscheduled); **the pixels** of the Include Files window and the confirmation
(suites green, owed a look and a `:0` run of `test_ase_window`); and the saved-operating-point question
above.

## Ported from the private clone (2026-11-21)

The user asked on 2026-11-21 that this tree be able to take ASE-L's rename corrections and Apply
Corrections from `~/private/xschem-private`. Its six 1723 commits were replayed here with
`git am -3`, keeping their subjects, plus this note. The number is kept: this branch's
`NUMBERING.md` left 1721 to 1723 to that clone, and its 1723 line says the number came with the port.

- **Commit ids in this file and in `doc/claude/issue_1723/receipts/` name the private clone's
  history**, which this one does not hold: `777efaf24`, `e73fb41ae`, `ed635d969`, `2f1b8bca7`,
  `96c8ec091` and `3db2f8fd1` are the private commits of the same subjects here, in that order, and
  `a464b7f6b` was the private base of items 5 to 7. The receipts are dated records of that tree.
- **The stamp's `tree=` names the commit this branch stood at when the port was made.** `git am`
  gives every port commit a new id, so no port commit's id survives into the branch that takes the
  patches; that base does, as an ancestor. The claims were re-checked on top of it:
  `test_ase_preflight` and `test_ase_window` on both arms, and this tree's own suites that read the
  changed procs.
- **One merge was adapted.** In the private clone `ase::ui::run_started` also clears the state of a
  feature this tree does not have, next to the 1723 lines. The port keeps only the 1723 lines there:
  the repair banner and an open confirmation end when a run starts. Every other added or removed
  line is the private commits' own.
