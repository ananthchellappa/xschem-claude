# Work order 02 — the two open items of issue 1657

Prepared 2026-11-21; revised the same night after a second reader, told to refute the
scout's notes, checked them against the tree. This text already carries its corrections.
Two changes in two places, one commit.

Read the issue first, all of it:
`doc/claude/issues/1657-results-are-matched-to-analysis-rows-by-position-while-the-sidecar-records-the-row.md`.
Its section "Open items" is this work order. Its opening still says the work is in the
working tree and not committed; it was committed as `7c77f3594`.

The scout's notes on every option, with the procs and rows named, and the second
reader's answer are
`/home/analog/dev/xschem-claude/doc/claude/overnight_batch_2026_11_21/maps/02_issue-1657-open-items.map.json`
and `.check.json` beside it (read only; read from the code, not run). Reproduce first;
the tree wins.

The second reader found that part 2, built the plain way, breaks three things that work
today. The ruling stands; "What to build" in part 2 is the shape that keeps them
working. If you find it cannot be built within those limits, do not build something
else: land part 1 alone, leave part 2 open in the issue with what you measured, and say
so.

---

## Part 1 — the Options preview shows the deck's order, in labelled groups

### Ruled by the user on 2026-11-21

"Deck order + labels": the preview asks the same question the deck asks, using the
netlist the window already reads, and lists the per-analysis groups in the order the deck
will run them. Each group is headed by its analysis. Before a netlist of this session
exists it says plainly that the `op` group may run last. The user chose it from this
sketch (wording not final):

```
inside the analysis block

  tran
    option itl4=200
    option itl4=10          <- put back
  op                        <- runs last in this deck
    option gmin=1e-10

  note: gmin is left in force for every
        analysis after op (none in this deck)
```

### What is true today

- The sheet is a window of its own, not modal. It repaints only through
  `ase::ui::optsheet_fill` (`src/ase_window.tcl`): when it is made, on a key in the Find
  box, on the Scope box, on the Show all tick, and after a row is committed. That proc
  ends in `ase::ui::optsheet_preview`, which calls `ase::opt_preview` (`src/ase.tcl`) with
  the text `ase::ui::optsheet_netlist_text` returns: a REDUCED copy of the netlist file
  (dot cards and control blocks only), cached by size and time.
- `ase::opt_preview` fills the `control` slot with `{option-name line}` pairs: first the
  lines ASE-L adds itself around an analysis (`ase::analysis_suppress_lines`), for every
  enabled row in the state's row order; then, for each type of
  `ase::preview_analysis_types`, each scoped option's set line followed by its restore
  line. That proc asks `ase::analysis_emit_order` for the operating-point-FIRST order,
  always.
- The pane prints only the line of each entry. No analysis is shown anywhere, and the
  comment in `ase::opt_preview` that says each line is tagged with its analysis is not
  what is built.
- The deck (`ase::backend::ngspice::render_deck`) runs the operating point last when the
  per-device requests go inside the control block. That needs: the gate on, an enabled
  `op` row, a held block for EXACTLY this netlist text (`ase::op_cards_for`, one slot per
  process, exact text equality), and a tier that reorders. `ase::saves_op_cards_coming`
  already spells the first three. The reduced copy cannot equal the captured text for a
  netlist that holds a device line, so the preview's present input can never match.
- Running the operating point last is the ngspice adapter's rule, not core's:
  `doc/claude/specs/ase_l_adapter_authors.md` (its section on plot reconciliation) tells
  an adapter author the order its deck runs the rows in is its own, and the header of
  `ase::analysis_emit_rank` says the rule does not generalise.
- `~/private/xschem-private` already holds the 1657 work and its pane code has moved on:
  there the pane's text is built by a pure proc, `ase::ui::optsheet_preview_text`, read
  by rows on the counted arm, and `ase::ui::optsheet_netlist_text` is written differently.
  Read both there (read only) before you design: build the pane text as a pure proc here
  too, with that name and shape, so the two trees can be merged by the port.

### What to build

1. **The order question, asked without side effects and answered by the backend.** Three
   answers for a state and a netlist text: the operating point runs LAST; it runs FIRST;
   NOT KNOWN. NOT KNOWN covers: no netlist text; a held block for another text; no file
   where the RUN will look (below); each while the gate is on, `op` is enabled and more
   than one analysis is enabled. It gives the deck's own answer wherever the deck's
   answer is determined. Because the rule is the adapter's, core asks through an optional
   adapter hook; a backend without the hook answers FIRST, which is today's order (row
   HK3 drives such a backend). The adapter-authors spec gains the hook, in its table and
   in the count its heading states, and its reconciliation section says core now asks.
   It must NOT call `ase::op_tier_now` or `ase::op_save_tier`: on a cold capability cache
   those start the user's simulator, and this runs on every keystroke.
   `ase::op_tier_forced` is the side-effect-free read. Core procs hold no simulator
   words: the two rows named HK1 scan hand-kept lists of procs for them, so add your new
   core procs to those lists.
2. **The window hands over the unreduced text** for that question: as a NEW FIFTH argument
   of `ase::opt_preview` (existing callers pass the third and fourth by position), never
   to the seed rule, which keeps the reduced text. What `ase::ui::optsheet_netlist_text`
   returns to its present callers does not change, and nothing resolves or creates the
   run directory (rows RS9 and RS10 hold that; RS10 must drive your new reader too). The
   window does not always read the file the run reads: with `local_netlist_dir` set it
   does not look in the schematic's own directory, while the run resolves through
   `ase::rundir`. Either read where the run will read, without creating anything, or
   answer NOT KNOWN there. Keep the per-keystroke cost flat.
3. **Groups in deck order, each headed by its analysis.** LAST and FIRST order the groups;
   NOT KNOWN keeps today's order. The lines ASE-L adds itself go under their own
   analysis, where the deck writes them. Carry the analysis as a further element of each
   `control` entry so the keys of the preview's answer do not move. The loop that lists
   those added lines today pairs every name of a row with every line of that row; with
   one name it is right, with two it would list each line twice. Do not copy that shape.
4. **A heading is not a deck line and must not look like one.** Deck lines stand four
   spaces in and slot headings at the margin; the pane's rule is that every line it shows
   as a deck line is in the deck byte for byte. Give the group heading a shape of its
   own. The sheet already has words for an analysis elsewhere (its Written column, its
   detail line); stay with them.
5. **The statement when the order is not known:** one sentence, minted in core, shown once,
   and only when it can matter (two or more groups with lines, or a note about an option
   that is not put back). It says the operating point runs last when device
   operating-point numbers are saved, and that this is settled when the netlist is
   written.
6. **The note about an option that is not put back.** First MEASURE whether it is true
   across a `dc` row that sweeps a design variable: `ase::backend::ngspice::dcvar_body`
   reloads the circuit per point and writes its own lines again with the comment that a
   reset wipes them. Do not reword the sentence before that is known. Then: when the
   order is known the note names the analyses that run after it, or says none does; when
   it is not known it keeps today's words; and it says what is true across such a row.
7. **The pane does not go stale silently.** A new netlist, the tick that saves device
   operating-point numbers, enabling or disabling an analysis and a forced tier all
   change the answer while the sheet is open, and none of them repaints it. Repaint at
   those writers, or repaint when the sheet gets the focus; choose, and fence it.
8. The pane marks the `op` group as running last when it does, as in the sketch.

### Decided by the lead (spec holes; the receipt lists them)

- One group per analysis TYPE, as today. If two enabled rows of one type are not adjacent
  in the deck's order, say so and group by row instead.
- A sheet opened from an analysis form with its scope preset still lists every group, as
  today.
- Every new or changed sentence on this pane is copy the user reviewed once before
  (`doc/claude/ase_analyses_batch/R9_COPY_REVIEW.md`). Write them in that register, return
  a `rule` debt naming each sentence, and a `look` debt for the pane. The ledger already
  holds entries on this issue and this pane; do not touch them.
- `render_deck` is not restructured. The hook is fenced AGAINST decks it writes.

### Rows (red today unless marked)

In section RO of `tests/headless/test_ase_core.tcl` (helpers `ro_state`, `ro_deck`,
`ro_recs`), in `tests/headless/test_ase_optsheet_1441.tcl` (sections PV and UI) and beside
rows RS9 and RS10 of `tests/headless/test_ase_run_seed.tcl`. A row that primes the held
block (`ase::op_cards_put`) saves and restores `::ase::op_cards`, as section RO does: a
primed slot changes every deck rendered after it in the same file.

1. Bench `op` + `tran`, one option scoped to each, device requests held for the
   fixture's netlist text: the order of the option lines in the preview's `control` slot
   equals their order in the deck `render_deck` wrote.
2. The hook's matrix: gate on/off, `op` enabled or not, the held block (for this text
   with cards, for this text and empty, for another text, none), one or several enabled
   analyses, each forced tier and none. Its answer equals whether the rendered deck's
   own record lines put `op` after another type. The comparand is the deck, a different
   mechanism from the hook. Legs that say both answers occur and that the one tier that
   keeps the operating point first differs from its neighbour. A backend without the
   hook answers FIRST.
3. NOT KNOWN: the statement appears exactly once with two analyses carrying lines and no
   text, with a text the block is not held for, and where the window and the run would
   read different files; it does not appear with one enabled analysis or when the block
   is held. Control: the default state's answer is byte-identical to row PV8's gold.
4. Every `control` entry carries its analysis; entries of one analysis are contiguous; a
   line ASE-L added carries its row's type and is listed once (row DK10's fixture, and a
   fixture with two suppressed names if the adapter can be made to give one).
5. The pane text, on the counted arm through the pure proc: between the heading of the
   in-block slot and the next heading there is one group heading per analysis, each
   followed by its own lines and no other's; the `op` heading says it runs last when it
   does; no heading has the shape of a deck line. And once on the display arm, read from
   the widget.
6. The not-put-back note on a bench `op` + `noise` with row SP3's option: with device
   requests held it names `op` as running after; with the gate off it does not.
7. Through a real session: the text handed over for the order question is byte-equal to
   the file the run will read; nothing is written and no directory is created (RS10's
   shape); RS9's seed leg does not move.
8. Stale pane: with the sheet open, each of the four changes of item 7 above is followed
   by a pane that shows the new answer.
9. Row RO1's census moves on purpose, and the changed signatures are pinned with
   `info args` and `info default`, not with a text scan.

---

## Part 2 — a request for `op` reads again when an untyped read stored the noise totals

### Ruled by the user on 2026-11-21

"Re-read when op is asked": a request that names `op` and meets a table that an untyped
read took from the noise totals reads the file again and gets the operating point. Every
caller is cured (annotate, `xschem raw read <file> op`, scripts). A file without noise
totals behaves exactly as today.

### What is true today

- `read_dataset()` (`src/save.c`), called with no type, lets the file's first plot fix the
  type, and overwrites its own `type` variable as it goes. A file whose first plot is
  `Integrated Noise` is stored as `op`, holding the two totals. With the operating point
  first and totals of the same variable count, the totals are appended to it as a second
  `op` dataset.
- `extra_rawfile()`, asked to read a file the registry already holds under that type,
  switches to it and reads nothing. Doors into that arm: `xschem raw read`,
  `xschem raw select` (through `raw_select()`), the `annotate_op` arm of
  `src/scheduler.c` (which removes the current table first only when it is a one-point
  `op` or `dc`; it has a shape with an explicit type word as well), `raw_case_reread()`,
  and the graph drawing code in `src/draw.c`: a graph with `autoload` set asks for its
  file under its own type or, when it names none, under the CURRENT table's stored type,
  on every draw, and puts the registry's cursors back by absolute index afterwards.
- `raw_select()` fills in a missing type from the current table's stored type. The
  selection spec (`doc/claude/specs/results_selection.md`, R301 and its landmine on
  clearing) says a select never clears and never frees, and answers 2 when nothing was
  parsed.
- `calc::aq_restore` puts the user's table back with `xschem raw read <name> <type>`,
  counting on the switch; `calc::aq_run` then compares the whole text of `xschem raw info`
  and refuses when it moved (band AT11's shape). `ase::optexport_datasets` uses the same
  restore.
- `xschem raw_read` (with an underscore: the menu's `load_raw`, the procs that open a
  window on a loaded table, `create_graph`) is a different door: it clears the registry
  and calls the reader directly. It does not record the type it was asked
  (`Raw.req_sim_type` stays unset), so `xschem raw case <mode>`, which reads again
  through `raw_case_reread()` with that field, reads again with NO type (read from the
  two functions, not driven).
- Readers that publish from a loaded table and never read: the `switch`, `switch_back`
  and `select` branches of the `raw` command call `update_op()` on a one-point `op` or
  `dc` table after the move; the Cadence profile's annotate chord
  (`cadence::_annot_op_db_ok` in `utils/annot_mode.tcl`) publishes the selected table when
  it is `op` or `dc`, else switches to any loaded one and publishes it, and only then
  asks for a read; `calc::aq_run` evaluates in place when the current table's stored type
  equals the analysis asked.
- ASE-L's own three callers were given the operating point all along, each through its
  own workaround (`ase::attach_dbs` clears first; `op_annot::db_attach` drops the path's
  `op` and `dc` entries; `calc::eval_texts` reads through a private alias).

### What to build

1. **The mark.** A field of the table, set inside `read_dataset()` when a read that named
   no type took an `Integrated Noise` plot as `op`, whichever dataset that was. "Named no
   type" has to be remembered on entry, because the function overwrites `type`. Both
   read doors pass through that function. The mark is readable from Tcl, in a way that
   leaves the text of `xschem raw info` for an unmarked table exactly as it is.
2. **Who asks.** The re-read happens only for a request whose own words named `op`: the
   `raw read` arm with a type word, the `raw select` arm with a type word, and the
   `annotate_op` arm where it asks for `op`. It does not happen for a type the engine
   filled in (a select with no type; a graph that names none), and never from the
   drawing code. Carry "the request named it" as a bit on the call, as `RAW_READ_REBIND`
   is carried.
3. **In place.** Read first; replace the marked table on success, in the SAME slot, with
   the registry's cursors untouched; never through the clear arm. A file with no
   `Integrated Noise` plot can never be marked, so nothing changes for it by
   construction: show that by measurement all the same.
4. **When the re-read fails**, the table that was loaded stays loaded and current, as far
   as the reader allows: a malformed header line clears the whole registry from inside
   the reader today, for every file, and that is not this item's to change. Band M
   already has both fixtures and neither needs a file rewritten: `in_nsd_ops` (asked `op`
   it is refused and nothing is wiped) and `in_opb` (refused, and every table is
   cleared).
5. **`raw select`.** A select that named `op` and met a marked table has parsed a file:
   it answers what a read answers. This is the one exception to "a select never frees
   and answers 2"; write it into the selection spec.
6. **The readers that never read, cured in Tcl with the mark.** The Cadence profile's
   annotate chord must not publish a marked table as an operating point: it goes on to
   its rung that asks for a read. `calc::aq_run`'s in-place arm must not take a marked
   table for an operating point. `calc::aq_restore` must put the user's table back
   without turning the restore into a re-read: after a Calculator press from another
   analysis the user's table is the one it was, and `xschem raw info` reads as before.
7. **The door that forgets what it was asked.** Measure the case-mode re-read described
   above. If it is as read, a correctly loaded operating point of a totals-first file
   turns into the totals on a case change: make the underscore door record the type it
   was asked, with a row.
8. **A totals-only file** (no operating point) is marked too: the first request that
   names `op` reads once more, gets the totals again, and the table is no longer marked.
   Its answer must not change.
9. Only the registry's SPICE arm is concerned; its twin for other formats is not touched.
   Say so in the comment that asks for the two to be kept in step.

After an untyped read of a totals-first file that holds an operating point, each of
these is given the operating point: `xschem raw read <f> op`; `xschem raw select <f> op`;
`xschem annotate_op <f>` with the totals current and with them loaded and not current;
the Cadence profile's annotate chord; `ase::attach_dbs <f> op`, `op_annot::db_attach` and
`calc::eval_texts` (as before); the Calculator buffer's `vdc()` through `calc::aq_run` on
both arms; a window opened from it (`open_sub_schematic`, `hi_descend_newwin`).

Stated as limits in the issue, not built: `xschem raw switch`, `xschem raw switch_back`
and a select that names no type move to a marked table and publish it as it stands (they
never read); `results::select` with no type on a totals-first file stores the totals and
publishes them in the same call; a graph with `autoload` set draws from a marked table
as it stands.

### Decided by the lead (spec holes; the receipt lists them)

- **Issue 0685 stays apart.** The user chose this option over the one that is 0685's
  engine fix. Do not change what a bare annotate does for a file that holds no noise
  totals; row F12 of `tests/headless/test_annot_stale_0684.tcl` must not move. Say in the
  issue file that 0685 is the sibling left open.
- **The cure the second reader raised and the user was not offered:** an untyped read
  that does not store the totals as `op` at all when the file holds an operating point.
  It would reach the readers listed above as limits, and it moves answers the issue
  lists as deliberately unchanged. Do not build it. Describe it in the issue beside the
  limits and return a `rule` debt, so the user can choose it later.

### Rows (red today unless marked)

In band M of `tests/headless/test_raw_ascii_point_bounds.tcl` (registered, no simulator).
Its present cells all start from an empty registry, so none of them sees this; the new
cells are sequences. A row for the Cadence chord or the Calculator goes in a suite that
gates: `tests/headless/test_annot_op_behind_tran_1242.tcl` is in no list and prints no
completion banner, so either register it with one or put the row where a list runs it.

1. For each block form and each totals-first file of the band that holds an operating
   point: clear; an untyped read through EACH door (`xschem raw read <f>` and
   `xschem raw_read <f>`); then `xschem raw read <f> op`. The answer equals the band's
   existing `op` cell for that file. Each file carries a premise leg: the untyped read
   answered 1 and the first name it lists is a noise total. Without it `ins_nsd_op`
   passes empty (its untyped read is refused), and `in_nsd_opm` needs its own
   expectation: its operating point is promoted to `dc`, so the table's key changes.
2. Nothing changes without totals: the same two-read sequence on files with no
   `Integrated Noise` plot gives the same answer and the same `xschem raw info` text as
   the unchanged binary; on totals-only files it still answers the totals (green today
   and after).
3. Annotate with the totals loaded and not current (an untyped read, then a typed read
   of a transient file, then `xschem annotate_op <f>`): the first name listed is a node
   voltage. Twin, green today: the same with the totals current.
4. `xschem raw select <f> op` after the untyped read: the operating point, in the same
   slot, with the answer a read gives. And a select that names NO type, with the marked
   table current, reads nothing and answers as today.
5. A draw does not re-read: a graph with `autoload` set, the marked table current, a
   redraw; the registry is as it was.
6. The Calculator: `vdc()` with the marked table current, on both arms of `calc::aq_run`;
   and a press from another analysis leaves the user's marked table in place with
   `xschem raw info` unmoved.
7. The Cadence profile's annotate chord with a marked table selected, and with one
   loaded and another table selected: node voltages are published.
8. The failed re-read on the two fixtures named above; and, with a transient of the same
   path attached first (row F13b's staging), that the transient is still attached and
   readable.
9. The case-mode re-read of item 7 above.
10. A new window opened on the marked table shows the operating point (the leg the issue
    marks "read from the code; not driven"). Section E of
    `tests/headless/test_raw_read_dispatch.tcl` is the template; find out whether it runs
    under `--nogui`.
11. Before and after, as a table in the receipt and not as rows: for one totals-first
    file with an operating point and one file with no totals, in both block forms, from
    each prior state (nothing loaded; the untyped table current through each door; the
    untyped table loaded and another current), what each reader named in this part is
    shown, the ones listed as limits included.

Run again, unchanged, after the engine change: row ET11 of `test_calc_eval_text` (the
tripwire for ordinary files); bands AT10, AT11, AT14 of `test_calc_analysis_tokens`;
`test_annot_stale_0684`; `test_op_annot`; `test_annot_blank_cause_0909`;
`test_annot_hier_0911`; `test_results_freshness`; `test_wave_crossdb_trace`;
`test_node_token_split`; `test_backannotate_digital`. And, by hand because they are in no
list: `test_raw_read_dispatch`, `test_results_select` (take their baseline first; a row
of the second was red in the private tree before any of this).

---

## Texts to update

- The issue file: both open items rewritten as ruled and built, with what was measured;
  the limits of part 2 and the cure not taken; the stamp line (`open=`, `stamped=`, and
  `tree=` as the batch rules say) on one physical line; the sentence about the working
  tree; the row for `ase::preview_analysis_types` in its table of procs; the entries of
  "What follows from the rule" that this closes or now drives.
- `doc/claude/issues/NUMBERING.md` where it says two items stay open.
- `doc/claude/specs/ase_l.md`: the paragraph on a file already loaded under `op`; and a
  description of the Options preview (slots, groups, the order rule, the not-known
  sentence), which the spec does not have: its menu section still calls the dialog
  minimal.
- `doc/claude/specs/ase_l_adapter_authors.md`: the new hook, the count in the heading of
  its hook section, and the reconciliation section.
- `doc/claude/specs/results_selection.md`: R112 and R301 gain the one exception.
- `doc/ase_l_tutorial.html`, the section on simulator options, if the pane it describes
  changed for the user.
- `doc/claude/FAQ.md`: one entry per part, newest on top.
- Comments: the DECLARED LIMIT block above `ase::preview_analysis_types`; the in-block
  comment in `ase::opt_preview`; the paragraph above the `noise` entry of the adapter's
  registry about a file already loaded; the paragraph above the integrated-noise arm of
  `read_dataset()` that says the function is not called for a loaded file; the
  return-value paragraph of `extra_rawfile()`; the comments of the new field and of
  `req_sim_type` in `src/xschem.h`; the header of section RO.

## Traps

- The sections the code comments call 7c-6 and 7e are in
  `doc/claude/ase_analyses_batch/PLAN.md` (a dated record: do not rewrite it), not in the
  spec.
- Rows PV1 and HK3 pin the keys of the preview's answer; PV8 pins the whole answer for
  the default state; PV6 pins one note per option, and notes are keyed by option name, so
  an option stored against two analyses keeps one note unless the key carries the
  analysis. UI17 pins the heading above the notes; the four slot headings are also
  phrases `ase::opt_door_phrase` returns in mid-sentence. Rewording any of them has
  siblings.
- The held-block slot is one per process: netlisting another session's design refills it,
  and this session's preview then answers NOT KNOWN. That is right; fence it.
- `render_deck` is held byte-for-byte by many rows. Do not move a line of it.
- Row A64-2 of `tests/headless/test_op_annot.tcl` slices the annotate arm's C source: the
  registry call and the publish call must stay on code lines of the arm, and one other
  call must stay off them. Read the row before you add a line there.
- A C change needs `make -C src` before any suite is evidence. `src/xschem.h` moved means
  everything recompiles.
- A write-up under `doc/claude/issues/` with a number in its name and no stamp line
  reddens the regression: measurements go in the receipt.
- If you file an issue: every number takes the two checks of `CLAUDE.md` again. 1728 is
  taken in `~/private/xschem-private`, whose pointer reads 1729.

## Out of scope

Issue 0685. The limits the issue lists under "What follows from the rule" other than the
loaded-table one: the malformed-header refusals, the CRLF limit (issue 0300), the plot
named after the type, which plot answers `noise`. The two readers and three hand-made
sidecar shapes the issue left as they are.

## Done means

Part 1 built; part 2 built within the limits above, or left open with the measurements
that say why; each row shown red on the unchanged product; the before-and-after table
taken; the issue file saying what is closed, what is a stated limit and what the user
can still choose; the debts for the pane's sentences, its look and the cure not taken
returned.
