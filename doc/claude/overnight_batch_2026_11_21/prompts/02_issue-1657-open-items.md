# Work order 02 — the two open items of issue 1657

Prepared 2026-11-21. Two changes in two places, one commit.

Read the issue first, all of it:
`doc/claude/issues/1657-results-are-matched-to-analysis-rows-by-position-while-the-sidecar-records-the-row.md`.
Its section "Open items" is this work order. Its opening still says the work is in the
working tree and not committed; it was committed as `7c77f3594`.

The scout's notes on every option, with the procs and rows named, are at
`/home/analog/dev/xschem-claude/doc/claude/overnight_batch_2026_11_21/maps/02_issue-1657-open-items.map.json`
(read only; read from the code on 2026-11-21, not run). A skeptic's corrections, if any,
are at the foot of this work order. Reproduce first; the tree wins.

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

- `ase::ui::optsheet_fill` (`src/ase_window.tcl`) repaints the pane on every key typed in
  the Find box, through `ase::ui::optsheet_preview`, which calls `ase::opt_preview`
  (`src/ase.tcl`) with the text `ase::ui::optsheet_netlist_text` returns: a REDUCED copy of
  the netlist file (dot cards and control blocks only), cached by size and time.
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

### What to build

1. **The order question, asked without side effects.** A predicate in core with three
   answers for a state and a netlist text: the operating point runs LAST; it runs FIRST;
   NOT KNOWN (there is no netlist text, or the held block is for another text, while the
   gate is on, `op` is enabled and more than one analysis is enabled). It must give the
   deck's own answer wherever the deck's answer is determined. It must NOT call
   `ase::op_tier_now` or `ase::op_save_tier`: on a cold capability cache those start the
   user's simulator, and this runs on every keystroke. `ase::op_tier_forced` is the
   side-effect-free read. Core procs hold no simulator words (the two HK1 rows scan for
   them); if the answer needs something only the adapter knows, it comes through an
   optional adapter hook, with the adapter-authors spec updated.
2. **The window hands the preview the unreduced text** for that question, without changing
   what the reduced text is used for (the seed rule) or what
   `ase::ui::optsheet_netlist_text` returns to its present callers, and without resolving
   or creating the run directory. Keep the per-keystroke cost flat (the cache exists for
   that reason).
3. **Groups in deck order, each headed by its analysis.** LAST and FIRST order the groups;
   NOT KNOWN keeps today's order. The lines ASE-L adds itself go under their own
   analysis, where the deck writes them. Carry the analysis as a further element of each
   `control` entry so the keys of the preview's answer do not move.
4. **The statement when the order is not known:** one sentence, minted in core, shown once,
   and only when it can matter (two or more groups with lines, or a note about an option
   that is not put back). It says the operating point runs last when device
   operating-point numbers are saved, and that this is settled when the netlist is
   written.
5. **The note about an option that is not put back** says something true of THIS deck:
   when the order is known it names the analyses that run after it, or says none does;
   when it is not known it keeps today's words. First find out whether the sentence is
   true at all across a `dc` row that sweeps a design variable
   (`ase::backend::ngspice::dcvar_body` reloads the circuit per point); if it is not, say
   what is true there.
6. The pane marks the `op` group as running last when it does, as in the sketch.

### Decided by the lead (spec holes; the receipt lists them)

- One group per analysis TYPE, as today. If two enabled rows of one type are not adjacent
  in the deck's order, say so and group by row instead.
- The label is the analysis name as the window shows it elsewhere.
- Every new or changed sentence on this pane is copy the user reviewed once before
  (`doc/claude/ase_analyses_batch/R9_COPY_REVIEW.md`). Write them in that register, return
  a `rule` debt naming each sentence, and a `look` debt for the pane.
- `render_deck` is not restructured. The predicate is fenced AGAINST decks it writes.

### Rows (red today unless marked)

In section RO of `tests/headless/test_ase_core.tcl` (helpers `ro_state`, `ro_deck`,
`ro_recs`), in `tests/headless/test_ase_optsheet_1441.tcl` (sections PV and UI) and beside
row RS9 of `tests/headless/test_ase_run_seed.tcl`:

1. Bench `op` + `tran`, one option scoped to each, device requests held for the
   fixture's netlist text: the order of the option lines in the preview's `control` slot
   equals their order in the deck `render_deck` wrote.
2. The predicate's matrix: gate on/off, `op` enabled or not, the held block (for this
   text with cards, for this text and empty, for another text, none), one or several
   enabled analyses, each forced tier and none. Its answer equals whether the rendered
   deck's own record lines put `op` after another type. The comparand is the deck, a
   different mechanism from the predicate. Legs that say both answers occur and that the
   one tier that keeps the operating point first differs from its neighbour.
3. NOT KNOWN: the statement appears exactly once with two analyses carrying lines and no
   text, and with a text the block is not held for; it does not appear with one enabled
   analysis or when the block is held. Control: the default state's answer is
   byte-identical to row PV8's gold.
4. Every `control` entry carries its analysis; entries of one analysis are contiguous; a
   line ASE-L added carries its row's type (row DK10's fixture).
5. Display arm: the text of the pane between the heading of the in-block slot and the
   next heading has one label per analysis, each followed by its own lines and no
   other's; the `op` label says it runs last when it does.
6. The not-put-back note on a bench `op` + `noise` with row SP3's option: with device
   requests held it names `op` as running after; with the gate off it does not.
7. Through a real session: the text the window hands over for the order question is
   byte-equal to the file on disk; nothing is written and no directory is created; RS9's
   seed leg does not move.
8. Row RO1's census moves on purpose (the preview no longer asks for the
   operating-point-first order), and the changed signatures are pinned with `info args`
   and `info default`, not with a text scan.

---

## Part 2 — a request for `op` reads again when an untyped read stored the noise totals

### Ruled by the user on 2026-11-21

"Re-read when op is asked": a request that names `op` and meets a table that an untyped
read took from the noise totals reads the file again and gets the operating point. Every
caller is cured (annotate, `xschem raw read <file> op`, scripts). A file without noise
totals behaves exactly as today.

### What is true today

- `read_dataset()` (`src/save.c`), called with no type, lets the file's first plot fix the
  type. A file whose first plot is `Integrated Noise` is stored as `op`, holding the two
  totals.
- `extra_rawfile()`, asked to read a file that the registry already holds under that
  type, switches to it and reads nothing. That is how a later request for `op` is shown
  the totals. The annotate arm (`src/scheduler.c`) removes the current table first only
  when it is a one-point `op` or `dc`, so with the totals loaded but not current it is
  shown them too.
- `xschem raw_read` (with an underscore: the menu's `load_raw`, and the two procs that
  open a window on a loaded table) is a different door: it clears the registry and calls
  the reader directly. `Raw.req_sim_type` is not set on that door, so it cannot tell an
  untyped read from a typed one.
- ASE-L's own three callers were given the operating point all along, each through its
  own workaround (`ase::attach_dbs` clears first; `op_annot::db_attach` drops the path's
  `op` and `dc` entries; `calc::eval_texts` reads through a private alias).

### What to build

A mark on the table, set inside `read_dataset()` in the one case that matters (the
integrated-noise arm answers `op` for a caller that did not ask for `op`, and nothing
else was taken), because both read doors pass through that function. Then, where a
request that NAMES `op` meets a marked table, the file is read again asking `op` and the
marked table is replaced.

After an untyped read of a totals-first file that holds an operating point, EACH of
these is given the operating point:

- `xschem raw read <f> op` and `xschem raw select <f> op`
- `xschem annotate_op <f>`, with the totals current and with them loaded and not current
- `ase::attach_dbs <f> op`, `op_annot::db_attach`, `calc::eval_texts` (as before)
- the Calculator buffer's `vdc()` through `calc::aq_run`, on both of its arms. One arm
  evaluates in place when the current table's stored type already equals the analysis
  asked, and so asks for no read at all: that arm must not take a marked table for an
  operating point.
- a window opened from it (`open_sub_schematic`, `hi_descend_newwin`)

Stated as a limit, not built: `xschem raw switch <f> op`, which by definition never
reads.

### Decided by the lead (spec holes; the receipt lists them)

- **Issue 0685 stays apart.** The user chose this option over the one that is 0685's
  engine fix. Do not change what a bare annotate does for a file that holds no noise
  totals; row F12 of `tests/headless/test_annot_stale_0684.tcl` must not move. Say in the
  issue file that 0685 is the sibling left open.
- **When the re-read fails** (the file is being rewritten), the table that was loaded
  stays loaded and current, as far as the reader allows: a malformed header line clears
  the whole registry from inside the reader today, for every file, and that is not this
  item's to change. Measure what happens and say it.
- **A read is a read.** `xschem raw select` and `xschem raw read -case` infer "switched"
  from an unchanged table count. After a re-read their answers must be the ones a read
  gives. Choose replace-in-place or append-then-remove accordingly and say which.
- **A totals-only file** (no operating point) is marked too: the first request for `op`
  reads once more, gets the totals again, and the table is no longer marked. Its answer
  must not change.
- Only the registry's SPICE arm is concerned; its twin for other formats is not touched.
  Say so in the comment that asks for the two to be kept in step.

### Rows (red today unless marked)

In band M of `tests/headless/test_raw_ascii_point_bounds.tcl` (registered, no simulator).
Its present cells all start from an empty registry, so none of them sees this; the new
cells are sequences.

1. For each block form and each totals-first file of the band that holds an operating
   point: clear; an untyped read through EACH door (`xschem raw read <f>` and
   `xschem raw_read <f>`); then `xschem raw read <f> op`. The answer equals the band's
   existing `op` cell for that file.
2. Nothing changes without totals: the same two-read sequence on files with no
   `Integrated Noise` plot gives the same answer and the same `xschem raw info` text as
   the unchanged binary; on totals-only files it still answers the totals (green today
   and after). Row ET11 of `tests/headless/test_calc_eval_text.tcl` is the tripwire for
   ordinary files; re-run it and bands AT10, AT11, AT14 of
   `tests/headless/test_calc_analysis_tokens.tcl`.
3. Annotate with the totals loaded and not current (an untyped read, then a typed read
   of a transient file, then `xschem annotate_op <f>`): the first name listed is a node
   voltage. Twin, green today: the same with the totals current.
4. `xschem raw select <f> op` after the untyped read: the operating point, and the answer
   a read gives.
5. The Calculator's `vdc()` with the totals table current, on both arms of
   `calc::aq_run`.
6. The failed re-read: the marked table in place, the file replaced by truncated junk,
   then the request for `op`; assert what is loaded and current afterwards as decided
   above, and, with a transient of the same path attached first (row F13b's staging),
   that the transient is still attached and readable.
7. A new window opened on the totals table shows the operating point (the leg the issue
   marks "read from the code; not driven"). Find out whether it runs under `--nogui`; if
   not, it is a display-arm row.
8. Before and after, as a table in the receipt and not as rows: for one totals-first file
   with an operating point and one file with no totals, in both block forms, from each
   prior state (nothing loaded; the untyped table current through each door; the untyped
   table loaded and another current), what each caller in the list above is shown.

---

## Texts to update

The issue file: both open items rewritten as ruled and built, with what was measured;
the stamp line (`open=`, `stamped=`, and `tree=` as the batch rules say) on one physical
line; the sentence about the working tree; the row for `ase::preview_analysis_types` in
its table of procs; the two entries of "What follows from the rule" that this closes or
now drives. `doc/claude/issues/NUMBERING.md` where it says two items stay open.
`doc/claude/specs/ase_l.md`: the paragraph on a file already loaded under `op`; and a
description of the Options preview (slots, groups, the order rule, the not-known
sentence), which the spec does not have: its menu section still calls the dialog
minimal. `doc/claude/specs/results_selection.md`: R112 says an already-loaded file is
returned with nothing parsed again; it gains this one exception. `doc/ase_l_tutorial.html`,
the section on simulator options, if the pane it describes changed for the user.
`doc/claude/FAQ.md`: one entry per part, newest on top. Comments: the DECLARED LIMIT block
above `ase::preview_analysis_types`; the in-block comment in `ase::opt_preview`; the
paragraph above the `noise` entry of the adapter's registry about a file already loaded;
the paragraph above the integrated-noise arm of `read_dataset()` that says the function
is not called for a loaded file; the return-value paragraph of `extra_rawfile()`; the
comment of the new field in `src/xschem.h`; the header of section RO.

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
- Rows A64-2 and O29b of `tests/headless/test_op_annot.tcl` slice the annotate arm's C
  source: if you add a line there they read it.
- `tests/headless/test_raw_read_dispatch.tcl` and `tests/headless/test_results_select.tcl`
  are in no list. Take their baseline before you change the registry and run them after;
  a row of the second was red in the private tree before any of this.
- A C change needs `make -C src` before any suite is evidence. `src/xschem.h` moved means
  everything recompiles.
- A write-up under `doc/claude/issues/` with a number in its name and no stamp line
  reddens the regression: measurements go in the receipt.

## Out of scope

Issue 0685. The limits the issue lists under "What follows from the rule" other than the
loaded-table one: the malformed-header refusals, the CRLF limit (issue 0300), the plot
named after the type, which plot answers `noise`. The two readers and three hand-made
sidecar shapes the issue left as they are.

## Done means

Both parts built, each row shown red on the unchanged product, the before-and-after table
taken, the issue file saying that no item is open (or which one is, and why), and the
debts for the pane's sentences and its look returned.
