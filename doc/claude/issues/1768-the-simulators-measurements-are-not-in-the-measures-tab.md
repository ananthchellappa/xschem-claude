# 1768 — the simulator's measurements are not in the Measures tab

**STAMP:** `v1 claim=fixed tree=55f0bf938 stamped=2026-11-25 fix=taken open=2 by=driver-1768`

Asked by the user on 2026-11-25 and built the same day. What is open is listed under
"Open".

## What the user wrote

> ensure that measurements set up in Outputs > Measurements, which generate numeric
> values, are visible in the Measures pane of ASE-L. What's the point of having these
> measures if the values are not visible to the user? There needs to be a way for the
> user to distinguish (when creating/editing) between a simulator (ngspice .meas) measure
> and a measure (output) that is based on a Calculator function. If it's already in place,
> well and good.

## What it was

- **The values.** A measurement of Outputs > Measurements is computed by the simulator
  during the run and written to `<rundir>/<cell>_ase.meas`. Its number was shown in the
  Value column of the Measurements dialog and in the run log, and nowhere on the ASE-L
  window. The Measures tab listed the `outputs` rows only.
- **Telling the two kinds apart.** It was in place only by construction: a measurement is
  made in the Measurements dialog and an Output in the output editor (or the Calculator).
  Neither dialog said who computes its rows, and nothing on the window did.

## What was built

Spec: `doc/claude/specs/ase_l.md` R-OUT18. FAQ Q110.

- **The Measures tab lists the measurements that answer with one number**, under the
  Outputs rows, in the list's own order (`ase::ui::meas_tab_rows`, `ase::ui::populate`).
  A row that makes a plot or a working vector is not listed (`ase::meas_number_rows`).
- **A `By` column** says who computes each row: the session's simulator for a measurement,
  `Calculator` for an Outputs row (`ase::ui::measures_by`).
- **Each dialog says which kind it makes** and names the door to the other kind
  (`ase::ui::lbl_meas_what`, `ase::ui::lbl_output_what`).
- **A double click, or the context menu's Edit, opens the row's own editor**: the
  Measurements dialog on that row, or the output editor (`ase::ui::edit_measures_item`).
  A dialog that is standing is not built again; it keeps what was typed and goes to the
  row (`ase::ui::meas_goto`).
- **Delete** removes each selected row from its own list (`ase::ui::selection_split`), and
  from a standing dialog's list too (`ase::ui::meas_forget`).
- **A row that names its analysis by type alone** (`analysis tran`, no handle) opens in
  the dialog with the analysis it reads shown, and keeps its words when it was only looked
  at. Before this the Analysis box was empty for it and OK removed its `analysis` key, so
  the measurement then named no analysis. That was there before this change; the new
  double click leads straight to it (`ase::ui::meas_show`, `ase::ui::meas_row_vals`).
- **A number belongs to the row as it was run** (`ase::meas_shown`, `ase::meas_was_run`,
  `ase::meas_standing`). The measurement file is read by name, so a row edited after the
  run would be handed the old definition's number. The run-state snapshot beside the deck
  says what the run measured. A row reads `not measured in this run` unless:
  1. that run's list holds the same row, compared as the simulator is given it: a key at
     its field's default, or empty, is the row without the key (`ase::meas_row_canon`);
  2. it reads the same analysis, where two analyses of its type exist
     (`ase::meas_reads_analysis`);
  3. a row that makes a plot stands behind the same plot-making rows (`ase::meas_feed`);
  4. every measurement it is computed from stands as it stood (`ase::meas_ref_words`).

  The Measurements dialog's Value column follows the same rule, which it did not before.
- The Value cell otherwise follows the other rows of the tab: the failed run's sentence,
  nothing with no results or with results older than the deck, the simulator's own
  complaint when it reported nothing, `not reported: the run was stopped` after a run the
  user stopped. A switched-off row reads `disabled`; a row that cannot be measured shows
  its refusal, also before any run (`ase::ui::meas_tab_value`).
- The state format is unchanged. The tab is a view over the two lists; a measurement's
  item id is `m<index>` (`ase::ui::meas_item_index`).

## Rows

`tests/headless/test_ase_meas_in_measures_1768.tcl`, registered on both arms.

| band | what it holds |
|---|---|
| MC | a row as a comparable value: key order, padding, `enabled 1`, a key at its default (for every field of every kind that declares one), an empty key and a key that is no field do not count |
| MR | did the run measure the row as it stands: unchanged, edited, renamed, new, switched on since, refused by that run; computed from a measure that was edited, switched off, already off in the run, deleted, renamed, or two steps away; a node or a device quantity named like a measurement; a result substituted into a field; the dialog's dropped keys; the plot-making rows before it; the analysis it reads; forty rows that read the rows above them; two rows that read each other |
| MS | what a surface shows per row, with and without a snapshot; an edited row gets no value |
| MN | the rows that answer with one number |
| MV | one Value cell, by verdict and by the run's state, a stopped run included |
| MI | item ids, and the order plain and sorted |
| MD | a selection split over two lists; rows removed by index |
| MK | a session's rows: never run, run, edited after, added after, computed from an edited measure, a standing dialog's working copy, another state of the cell on the same run directory, a failed run with and without a results file, results older than the deck, no snapshot, neither snapshot nor measurement file, a run with no measurement, a saved result in view, a saved result whose snapshot Save made |
| ML | the two dialogs' lines, the menu path and the right-click entry they name, the simulator's name taken from the session |
| MX | the real simulator through a real launch: the numbers, the simulator's silence, a measurement edited after the run, the next run |
| MW1 | the tree: both kinds in order, Name, By (wide enough for both words), Value, the empty Plot and Save cells |
| MW2 | the Value header sorts both kinds together |
| MW3 | a real double click opens each row's own editor, on that row; with the dialog standing it keeps what was typed |
| MW4 | a real click on a measurement's Plot cell flips nothing and selects the row |
| MW5 | the dialog's OK repaints the tab; an edited row reads `not measured in this run` in the dialog and in the tab; a look and OK with nothing typed keeps the number |
| MW6 | the refresh a finished run makes, also on a sorted view, keeps the selection |
| MW7 | Delete over both lists; with the dialog standing the row leaves its list too |
| MW8 | both dialogs' lines on the window; the Saves door has none; the door the dialog names; a session whose simulator has another name |
| MW9 | the context menu's Edit |
| MW10 | a row that is no dict; a failure while the measurements are read costs only the measurement rows |

Rows of two older suites follow the new column: TW1 of `test_ase_outputs_tabs`, and W1f6,
W1p and D1398g of `test_ase_window`.

The bank question is `ase-meas-in-measures`.

## The review

Three reviewers read the first build, each finding checked by a second reader with a
probe (2026-11-25). What they found, all fixed above with a row each:

- a look at a template's row and OK blanked its number: the comparison counted a key at
  its default as a difference (point 1);
- a number stayed after the resample row before a transform was edited, after a measure
  it read was deleted or renamed, and after its analysis binding moved (points 2 to 4);
- a measurement named like a node, or a device quantity's word, was taken for an input;
- an input already off in the run made the row read as changed for ever;
- rows that read the rows above them made each repaint cost exponential time;
- after a stopped run the cell gave the wrong reason;
- with the dialog standing, a double click in the tab dropped what was typed and a tab
  Delete was undone by the dialog's OK;
- the By column cut `Calculator` off;
- the dialog's line named a door no menu shows;
- one-line breaks the suite did not catch: the failed-run sentence without a results
  file, a measurement file taken for granted, a saved result's snapshot that Save made,
  the simulator's name typed in three places, an input two steps away.

## Breaks

Each is one change to `src/ase.tcl` or `src/ase_window.tcl`, run against the suite on both
arms and taken back (2026-11-25, on the tree of this change). The bands named turn red;
a band beginning MW runs on the display arm only.

| | what was broken | bands that turn red |
|---|---|---|
| b1 | the tab is filled without the measurements | MW1, MW10, MW2, MW3, MW4, MW5, MW6, MW7, MW8, MW9 |
| b2 | a number is shown by name alone: the snapshot is not asked | MK, MS, MX, MW5 |
| b3 | whether the row reached the run's deck is not asked | MR |
| b4 | an `enabled 1` makes another row | MC |
| b5 | every measurement row is a number row | MK, MN, MW1, MW2, MW5, MW6, MW7, MW9 |
| b6 | a failed run does not blank the measurements | MK, MV |
| b7 | no results, or results older than the deck, still show the number | MK, MV |
| b8 | the tab reads the Measurements dialog's working copy | MK |
| b9 | the tab reads the live run's measurement file under a saved result | MK |
| b10 | the snapshot asked is always the live run's | MK |
| b11 | a click on a measurement's Plot or Save cell is taken as a flip | MW4 |
| b12 | a double click always opens the output editor | MW3, MW5, MW7 |
| b13 | the context menu's Edit always opens the output editor | MW9 |
| b14 | Delete leaves the measurements alone | MW7, MW9 |
| b15 | the refresh after a run skips the measurements | MW6 |
| b16 | the sorted view ranks the Outputs rows only | MI, MW2, MW6 |
| b17 | the dialog opens on its first row whatever row is named | MW3, MW5, MW7, MW9 |
| b18 | the dialog's Value column answers by name alone | MW5 |
| b19 | the Saves door carries the line too | MW8 |
| b20 | every row is By the Calculator | ML, MW1, MW5, MW8 |
| b21 | the dialog's line types the simulator's name | ML, MW8 |
| b22 | the Measurements dialog has no line | MW10, MW8, MW9 |
| b23 | a switched-off row shows an empty cell | MK, MV, MW1 |
| b24 | a row's own refusal is hidden when there are no results | MK, MV |
| b25 | a padded or signed index names a measurement | MI |
| b26 | a measure computed from an edited measure keeps its number | MK, MR |
| b27 | the names a row reads are compared with their case | MR |
| b28 | the By column opens eight glyphs wide | MW1 |
| b29 | a standing dialog is built again from the session when the tab names a row | MW3, MW5 |
| b30 | a key at its default makes another row (the rows are compared as stored) | MC, MR, MW5 |
| b31 | a node inside v() or vdb() counts as a word | MR |
| b32 | a device quantity counts as words | MR |
| b33 | a result substituted into a field is not followed | MR |
| b34 | a function's name counts as a word | MR |
| b35 | the plot-making rows before a row are not compared | MR |
| b36 | the analysis a row reads is not compared | MR |
| b37 | an answer is not kept once it is final (the first guess stays) | MK |
| b38 | a stopped run is not told from a silent simulator | MV |
| b39 | a tab Delete leaves the standing dialog's list alone | MW7, MW9 |
| b40 | the tab takes a measurement file for granted | MK |
| b41 | the failed-run sentence needs a results file | MK, MV |
| b42 | a saved result's snapshot is taken for the run's whoever made it | MK |
| b43 | the By cell types the simulator's name | ML, MW8 |
| b44 | the Measurements dialog's line types the simulator's name at the call | MW8 |
| b45 | the output editor's line types the simulator's name at the call | MW8 |
| b46 | a measure whose input was already off in the run reads as not measured | MR |
| b47 | a failure while the measurements are read stops the repaint | MW10 |
| b48 | a measure over a measure that is gone still counts as measured | MR |
| b49 | the Measurements dialog's line names a door that is not there | ML |
| b50 | the dialog rewrites the analysis words of a row that was only looked at | MW5 |
| b51 | a row that names its analysis by type alone opens with an empty Analysis box | MW5 |
| b52 | the menu builds a standing dialog again from the session | MW5 |

## The builder's choices (not ruled by the user)

1. **The column is `By`, and its two words are the simulator's name and `Calculator`.**
   Another heading (`Type`, `Source`) or other words are one line each.
2. **The measurements come after the Outputs rows.** They could come first.
3. **A switched-off measurement is listed, reading `disabled`.** It could be left out of
   the tab instead.
4. **A measurement edited after the run loses its number until the next run**, in the tab
   and in the Measurements dialog, and so does a measure computed from it. Before this
   the dialog went on showing the old definition's number under the edited row.
5. **With one analysis of a type, a change to that analysis after the run keeps the
   measurements' numbers**, as it keeps the Outputs rows' Values. With two analyses of a
   type the analysis read is compared, and a change to it blanks the number.
6. **Delete in the tab removes a measurement with no confirmation**, as it does an Outputs
   row. A measurement holds more fields than an Output does.
7. **A measurement that makes a plot or a working vector is not listed**: it has no number.
8. **The context menu's Add still adds an Outputs row.** A measurement is added in the
   dialog (Outputs > Measurements…, then Add).
9. **A state on another state's results** (states of one cell sharing a run directory)
   shows a number only for a measurement both states hold in the same words.

## Open

1. The user's ruling on the choices above.
2. The user's own look, on their screen: a bench of theirs with a measurement, after a run.

## Known, and left

- A measure computed from a measure that is deleted is still accepted by
  `ase::meas_verdict`; the next run then gives the simulator's own complaint, which does
  not name the missing measure. The tab says `not measured in this run` meanwhile.
- The Measurements dialog rewrites a row's stored keys on OK even when nothing was typed
  (a key at its default is dropped), which marks the session changed. No number moves.

## Not checked

- The user's own screen. Every run here was on a hidden display under openbox.
- A bench of the user's design.
- A run launched from the window's own buttons. Band MX launches the simulator found on
  PATH through `ase::run_deck`, the launcher those buttons call; the other bands write the
  measurement file, the results file and the snapshot themselves.
