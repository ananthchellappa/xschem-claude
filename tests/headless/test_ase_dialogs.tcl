# ASE-L v2 dialogs (item 07 of doc/claude/ase_l_batch, spec
# doc/claude/specs/ase_l.md "Menu tree v2" / "Choose Analyses dialog" /
# "Dialog style"):
#   H1     ase::open_state trailing ro arg -> session attr `readonly`
#          (every open sets it; a plain reopen clears it)
#   H2     ase::ui::save_as_needs_confirm (D8, UNCHANGED by the D13 overrule):
#          readonly+same-target / plain same-target / unwritable-file
#          same-target / a target this session does not own -- both the
#          unresolvable one and an EXISTING sibling, which is the row the old
#          fourth-row name only pretended to be
#   H2b    ase::ui::save_as_overwrites_other (S-2..S-6), the SECOND door the
#          user's 2026-09-09 overrule of D13 added: a DIFFERENT EXISTING state
#          -> 1, this session's own -> 0, a missing target -> 0, an UNTITLED
#          session against an existing target -> 1 (S-3); the two predicates
#          are mutually exclusive on every target; and the predicate is PURE --
#          it creates nothing and writes nothing
#   H2c/d  the two overwrite SENTENCES, both minted in the lbl_* family (S-7):
#          the new one interpolates the l/c/v it was given, the read-only one
#          is the shipped string byte for byte, embedded newline included
#   H3     ase::ui::do_save_state_as creates a MISSING view through
#          library_new_view and writes this session's serialization (D9)
#   H4     ase::ui::do_load_state_from imports content into THIS session,
#          session goes dirty (D10)
#   G1-G11 GUI legs (DISPLAY only, else a partial skip): Choose Analyses via
#          menu / OP,TR strip / analyses double-click preselect; dc
#          quick-field round trip + D6 rejection; Setup Design (View list
#          filtered to schematic views) round trip; Model Files list dialog
#          add/delete; Save All -> save_all_i + Save Options column + deck
#          line + disabled Levels; the S4 `save_op_params` third blanket
#          (G5b widget paths + grid rows survive the shift, G5c commits `0` for
#          the explicit OFF and writes `{}` -- the ON default -- back on, issue
#          0927); Simulation Options add/delete; Save-As
#          prefill / new-view create / same-target clean save; read-only
#          same-target confirm gate; G8b the DIFFERENT-EXISTING-state confirm
#          gate driven through the real menu -- the row the silent-clobber
#          defect would have failed; Load State browser (opens defaulted to
#          the session's own Library/Cell with the View column filled and no
#          View preselected -- G9a; a Library change clears the stale status
#          -- G9b; an unknown cell degrades one column only -- G9c; a bare OK
#          names the missing View -- G9d; state-view filter, import + dirty,
#          dirty-prompt-first); --> strip = Add Output;
#          no todo_stub left on any rewired item-07 entry.
#   GR5a-l ⚖ R5 (issue 1445): the Choose Analyses form REMEMBERS. Clicking a
#          type cell saves the visible form's edits into a per-dialog, per-type
#          cache and repopulating overlays that cache over the stored row, so
#          "I typed 500u, clicked the ac radio, clicked back, and 500u was gone"
#          (doc/claude/ase_l_ux_batch/FINDINGS.md) no longer happens -- GR5a.
#          The cache is per TYPE and not per field (GR5b), MERGES rather than
#          replaces so an untouched visible field (GR5c) and a field hidden
#          behind `▸ Advanced` (GR5d) keep their stored values, covers the
#          Advanced toggle too (GR5e, GR5l), records only what was TOUCHED
#          (GR5f), and is not committed for any type but the visible one
#          (GR5g). It
#          dies with the dialog, by Cancel (GR5h) and by a bare window-manager
#          destroy (GR5i); Enable rides with it (GR5j); and clicking all eleven
#          cells then pressing OK writes the same bytes as never opening the
#          dialog (GR5k), which is the 104-file byte-identity constraint asked
#          from the GUI side.
#   GR6a-h issue 1446, Option B: OK writes what the dialog REMEMBERED. ⚖ R5 made
#          the form remember and left `ase::ui::chana_ok` reading the LIVE
#          widgets, so a value typed under `▸ Advanced` and then folded away was
#          remembered and silently NOT committed -- `chana_show` destroys
#          `$w.form`. `ase::ui::chana_commit_vals` reads the visible type's live
#          widgets MERGED OVER THAT TYPE'S CACHE: the folded edit is written
#          (GR6a), a merged value equal to the field's declared default writes
#          no key and a non-default one does (GR6b), an emptied field deletes
#          its stored key (GR6c), and a retyped live widget beats the cache
#          (GR6d). It is STILL A SINGLE-TYPE WRITE -- GR6e presses OK with
#          another type's edit cached and asks for every other row of the bench
#          back byte for byte -- and it writes the same bytes as never opening
#          the dialog (GR6f). The cached copy of Enable never reaches the row
#          (GR6g), because the reader answers in FIELDS. GR6h pins the one
#          residual: the precondition banner's `chana_merged_row` still reads
#          live widgets only.
#   GH1-15 ⚖ R6's GUI half (issue 1448), closing two of issue 1444's three
#          surfaces. The Choose Analyses dialog gains a HANDLE GRID -- one line
#          per analysis row, `Handle` first, rendering `ase::analysis_handle_fields`
#          (GH1, GH2) -- and picking a line is how the SECOND `dc` row of a
#          bench is edited at all (GH3), which it could not be: `chana_row`
#          answered with the first row of a type and `pane_dblclick` threw the
#          index away, so both the context Edit… door (GH4b) and the
#          double-click door (GH4c) opened `dc1`. The type cell no longer resets
#          the addressing (GH4), OK writes the addressed row and leaves the rest
#          byte for byte (GH5, GH7), and ⚖ R5's edit cache is keyed by HANDLE
#          rather than by type, because a type-keyed cache overlays one dc row's
#          typing on the other's form (GH6). `Analyses > List` dumps every row
#          with the switched-off ones marked (GH8, GH9, GH10, GH14). GH11 is the
#          one-speller row, on the one fixture where a locally minted
#          `<type><n>` would disagree -- a row declaring `id vinsweep`. GH12 is
#          that identity surviving an edit; GH13/GH13b are what the commit door
#          does and does not see about it, the second a KNOWN DEFECT pinned by
#          measurement. GH15 is the byte-identity question asked of the new
#          grid.
#   GE1-16 item-10 esc-dismiss legs: EVERY ASE-L dialog OF THE ITEM-10 SET
#          dismisses on a real generated <Key-Escape> through its CANCEL path
#          (the results-batch item-7 `Results > Select…` dialog is newer and
#          carries its own ESC leg, tests/headless/test_results_dialog.tcl
#          SEL407 -- destroyed AND its per-window dlg records cleaned, which is
#          what tells the close path apart from a bare destroy) — dialog destroyed,
#          per-window records (edrow/edchk/dlg) cleaned, ZERO state mutation
#          (serialize snapshot unchanged); ESC from inside an entry bubbles
#          to the dialog toplevel (GE2); the .chana.x subdialog dismisses
#          without killing its parent and cleans dlg(anextra) (GE5); the
#          confirm's ESC never runs oncmd (GE13); the ASE main window (GE14,
#          witness-proven delivery) and the log window (GE15) stay
#          ESC-unbound; the item-08 Select-On-Design canvas ESC still ends
#          the mode with the seized binding restored verbatim (GE16).
#
# Runs via full_audit's DEFAULT arm. Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_dialogs.tcl
# (env -u DISPLAY for the headless-only run; add DISPLAY for the GUI legs)

set fail 0; set npass 0
# ============================================================================
# THE COUNT IS A FLOOR AND IT ONLY EVER GOES UP -- AND IT IS TWO NUMBERS
# ============================================================================
# ⚠ THIS FILE HAD NO FLOOR PARAGRAPH UNTIL ISSUE 1408. Two things make that
# worse here than in most suites:
#
#   * THE TWO ARMS MEASURE DIFFERENT THINGS, NOT THE SAME THING TO DIFFERENT
#     PRECISION. Most of this file is inside `if {[info exists ::has_x] ...}`,
#     so HEADLESS runs 37 checks and the DISPLAY arm runs 224. Reporting one
#     number reads as a floor that fell by 187. ALWAYS REPORT PER ARM.
#   * `run_regression.tcl` RUNS THIS FILE ON **NEITHER** ARM -- measured, it is
#     in neither `cases` nor `dcases`. So T1 at zero says NOTHING about any row
#     here, and a receipt that quotes a T1 zero has not exercised one of them.
#     The suite runs under full_audit.sh's display arm and under run_suites.sh.
#
# THE HISTORY:
#   37 / 215   as this paragraph was written (2026-09-11, HEAD 8bfbbd6f)
#   37 / 236   section GG, issue 1411: the wrapping type grid. Headless is
#              unmoved because every GG row is a widget row.
#   37 / 224   section G14, issue 1408: the dialog describes THIS session's
#              simulator. Headless is UNMOVED because every G14 row is a widget
#              row and sits inside the display guard, by design -- the schema
#              half of the same change is test_ase_core.tcl section AD.
#   37 / 265   sections G2b-G2k, Stage 3 (issues 1416-1420): the typed form, the
#              commit door and the Options editor's closed door.
#   37 / 271   section G2tf, Stage 5 (issue 1426): the transfer function can be
#              CHOSEN. Headless is unmoved because every G2tf row is a widget
#              row; the schema half is test_ase_core.tcl section TF.
#              ⚠ G2tf's last row reads `$top.chana.status` inside its OWN
#              `catch`, because the one change it exists to catch -- `insrc`
#              losing `required 1`, after which OK commits and CLOSES -- raised
#              `invalid command name ".ase5.chana.status"` and killed the file
#              at 65 of 271 instead of reddening a row. MEASURED, not feared.
#   37 / 278   section G2pz, Stage 5 (issue 1427): the pole-zero analysis can be
#              CHOSEN. Headless is unmoved for the same reason. It is the first
#              form in this tree that mixes THREE widget classes -- four `kind
#              node` entries and two `kind mode` comboboxes -- so it is the first
#              place a row can say that a picker is a picker. ⚠ Its refusal row
#              carries G2tf's `catch` from the start rather than learning it
#              again.
#   37 / 285   section G2sens, Stage 5 (issue 1428): DC sensitivity can be
#              CHOSEN. Headless is unmoved for the same reason. It is the first
#              form whose second field is OPTIONAL AND OMITTED FROM THE LINE
#              when it is blank -- `tf`'s two fields are both required and
#              `pz`'s optional four all carry defaults -- so it is the first
#              place a widget row can say that an empty box produces a SHORTER
#              deck line rather than a padded one. ⚠ Its refusal row carries
#              G2tf's `catch` from the start.
#   37 / 300   section GN, Stage 6 (issue 1435): the PRECONDITION BANNER under
#              the form -- Stage 4's first user-visible surface, deferred
#              because it needs netlist TEXT and a dialog may not produce one.
#              Headless is unmoved for the usual reason; the schema half is
#              test_ase_core.tcl section BN.
#              ⚠ GN1 IS WHY THE `look` DEBT EXISTS. PLAN.md's Stage 4 says of
#              this item "there is no new pixel ... No look debt is filed", on
#              the ground that everything reaches the user through
#              `ase::ui::dialog_status`. GN1 clears the capability cache -- what
#              a user who has never pressed Detect has -- and measures ALL
#              ELEVEN cells carrying a capability sentence in that very widget,
#              so the two sentences would evict each other; GN2 measures that it
#              does not wrap. The plan's paragraph is the stale half and its
#              `.note` name is the live one.
#              ⚠ GN10 IS THE ITEM'S WHOLE CONSTRAINT AS A ROW: opening the
#              dialog and clicking all eleven cells must start NO netlist.
#   37 / 313   section GR5, ⚖ R5 (issue 1445): a type click no longer discards
#              what you typed. Headless is unmoved because every GR5 row drives
#              widgets -- there is no schema half at all, which is the point:
#              the cache is per-dialog memory, no new state key and no schema
#              change. GR5k is the row that would notice one, and it asks the
#              104-file byte-identity question from the GUI side: click all
#              eleven cells, press OK, get the same bytes.
#   37 / 322   section GR6, issue 1446: OK now writes the folded-away value the
#              dialog was already remembering. Headless is unmoved for GR5's
#              reason -- there is no schema half, only a second reader on the
#              commit door -- and GR6f is the row that would notice a key this
#              change wrote into a bench that never carried one.
#   37 / 346   section NX, issue 1450: one list of non-setting row keys, and the
#              `Options...` subdialog stops refusing every row that carries one.
#              Headless is unmoved for GR5's, GR6's and GH's reason -- every NX
#              row drives the real subdialog's widgets. The schema half is
#              test_ase_core section NS (the proc and the fourth-copy source
#              scan), which runs on BOTH arms.
#   37 / 363   section MS, Stage 8b (issue 1451): the Measurements sub-dialog,
#              the eight named templates and the Value column. Headless is
#              unmoved for GR5's, GR6's, GH's and NX's reason -- every MS row
#              drives the real dialog's widgets. The schema half is
#              test_ase_core section MT (the templates and the one-line handle
#              renderer) and test_ase_meas_1443 section TP (the same eight
#              templates as the deck carries them).
#              ⚠ MS10's Value cells are the SIMULATOR'S PRINTED TEXT: apt 45.2
#              prints `9.149274e+05` where the fork prints `9.14927e+05` for the
#              same measurement, and the row asserts both survive untouched. A
#              golden that keyed on digit count passes on one binary and fails on
#              the other.
#   37 / 386   AND RAISED 385 -> 386 on the display arm, ⚖ **R9 ruling A2**
#              (2026-09-16): G2a2, the READ direction of "display the readable
#              word, emit the deck word". G2pz MOVED rather than being added --
#              its golden read `vol pz {vol cur} {pz pol zer}` and now reads
#              `Voltage PZ {Voltage Current} {PZ Poles Zeroes}` -- and G2pz's
#              pick gesture moved with it, from `set pol` to `set Poles`.
#              ⚠ THAT GESTURE MOVE IS NOT COSMETIC: `ase::field_label_value`
#              falls back to identity, so the old gesture stored `pol` with the
#              mapping never consulted and the row stayed green either way.
#              MEASURED on this change before the gesture was moved. Headless is
#              unmoved because every row here is a widget row inside the display
#              guard; the schema half is test_ase_core.tcl row PZ2f.
#   37 / 385   AND RAISED 384 -> 385 on the display arm, ⚖ **R9 ruling A1**
#              (2026-09-15): G2e2, the row that stops a field label regaining an
#              arithmetic claim. G2e and G2g MOVED rather than being added --
#              their goldens read `Number of points (2 gives ONE point):` and
#              now read `Number of points:`. Headless is unmoved because both
#              are widget rows inside the display guard.
#   37 / 384   AND RAISED 382 -> 384 on the display arm, issue **1457**: SP9b
#              and SP9c, the section's FIRST THREE-PORT ROWS. SP7 asked for 12
#              cells and SP9 for 20, both on the two-port bench, so a picker that
#              hid the nine `Cy` vectors every larger run really writes was green
#              here as well as in the schema suite. SP9b asks for all 36 cells,
#              the 3x3 `Cy` geometry, the ABSENCE of the four scalars, and that
#              no two gridded children of the picker share a cell -- a four-
#              matrix stack with no scalar strip is a layout `matrix_dialog` had
#              never been handed. SP9c ticks a three-port `Cy` cell and follows
#              it to an Outputs row, wrap and all. Headless unmoved, same reason.
#   37 / 382   sections SP, Stage 9a/9b (issue 1454): the ports table and the
#              matrix picker. Headless is unmoved for GR5's, GR6's, GH's, NX's
#              and MS's reason -- every SP row drives real widgets, and the
#              schema half is test_ase_sp_1452 section SX, which runs on both
#              arms. ⚠ SP14 is the exception to "no simulator in this file": it
#              runs BOTH binaries on the deck the table wrote, because two halves
#              of a feature tested in different suites never meet (issue 1449).
#   37 / 340   section GH, ⚖ R6's GUI half (issue 1448): the handle is visible
#              and the second row of a type is reachable. Headless is unmoved
#              for GR5's and GR6's reason -- every GH row drives widgets, and
#              the schema half shipped separately as test_ase_core section HN /
#              test_ase_persist section R8 (issue 1447).
#              ⚠ GH15 is this section's byte-identity row and it presses OK on
#              `ac`, never on `op`: `op` has no fields, so `chana_ok` writes
#              nothing whatever the reader answers and such a row cannot fail.
#              That is GR6f's measured correction to GR5k, inherited rather than
#              re-learned.
#              ⚠ GH13b PINNED A DEFECT AND NOW PINS ITS ABSENCE. It was written
#              to go RED when `ase::analysis_emit_check` learned about the `id`
#              key ⚖ R6 added, and it did -- issue 1449 landed that word and this
#              arm went to 2 FAILED (338 passed). Rewritten under issue 1450: the
#              gate is silent on a named enabled row, the row still renders its
#              card, and a third state carrying a key nothing can spend is the
#              non-vacuity control, because the original PAIR no longer disagrees.
#   MS1-17     THE MEASUREMENTS SUB-DIALOG (issue 1451, PLAN.md §8b). Issue 1443
#              shipped the whole DECK half of Stage 8 and built no widget:
#              nothing read a kind's `label`, `ase::meas_report` had no caller
#              anywhere in the tree, and a user could not create one measurement
#              row without hand-editing a `.state` file. `Outputs > Measurements…`
#              is that surface -- a list with a Value column (MS1, MS2, MS10),
#              a Kind picker rendering the adapter's declared labels (MS3), an
#              Analysis dropdown that is `ase::analysis_handle_line`'s answer and
#              stores `id <handle>` and never `row <index>` (MS4), add / delete /
#              reorder whose order reaches the deck (MS5), ⚖ R5's remembering
#              inherited through one harvest door (MS6), the eight named
#              templates (MS8), `R9-325`'s one-line `When signal … reaches`
#              constraint (MS9), the evaluator's own refusal sentences (MS11),
#              `Measured on` so nothing the deck can carry is unshowable (MS12),
#              the enable tri-state (MS13) and the 104-file byte-identity
#              question from the GUI side (MS14).
#              ⚠ MS15 IS THE ONE THAT MATTERS: a row CREATED IN THE DIALOG,
#              committed, RENDERED INTO A DECK with `set units=degrees` above it,
#              and read back into a Value CELL from the sidecar text a real run
#              wrote. Issue 1449 is the scar it answers -- two halves of a
#              feature tested in different suites never meet.
#              ⚠ MS10's FOURTH TERM IS THE OTHER DEFECT THIS SECTION FOUND IN
#              ITSELF: two rows may share a name -- the second is REFUSED but is
#              still storable and still on screen -- and a name-keyed Value
#              lookup hands the FIRST row, the one with a real number in it, the
#              SECOND row's refusal sentence. The lookup is positional with a
#              name guard.
#              ⚠ MS16 IS THE DEFECT THIS SECTION FOUND IN ITSELF: a handle the
#              bench no longer resolves must still be OFFERED by the Analysis
#              picker, or the harvest sees an empty box and the next selection
#              change -- or OK -- strips the binding off a row the user opened
#              the dialog only to look at. MS17 is the item-10 ESC leg for both
#              new toplevels.
#   SP1-SP14   STAGE 9a/9b (issue 1454): THE PORTS TABLE AND THE MATRIX PICKER.
#              Issue 1452 made a setup table EMIT and built no widget -- `ports`
#              was a row key with no surface anywhere, so the only way to put a
#              two-port table on a bench was to hand-edit a `.state` file. The
#              Choose Analyses form gains two per-type doors (SP1), the ports
#              dialog renders the row's own table with the ADAPTER's column
#              labels, title and caption and spells none of them itself (SP2,
#              SP3), Add/edit/Delete go through the real entries (SP4), the note
#              is `ase::needs_eval`'s own verdict and OK is a commit door that
#              refuses a one-port table (SP5) while letting a good one and an
#              emptied one through (SP5b), `Add from Schematic…` peeks and never
#              netlists (SP6, SP6b), the matrix picker offers one cell per vector
#              the run will answer and writes ordinary Outputs rows in the
#              viewer's own RPN (SP7, SP8, SP8b), it reads the LIVE form so a
#              just-ticked noise flag already shows its vectors (SP9) at two
#              ports and at THREE (SP9b/SP9c, issue 1457), an empty
#              table gets the run's own sentence rather than a blank window
#              (SP10), a type click closes a standing subdialog (SP11) and ESC
#              dismisses all three toplevels through their cancel paths (SP11b).
#              ⚠ SP12 IS THE DEFECT THIS SECTION FOUND, and it is issue 1450's
#              for the THIRD time: `ports` is licensed per TYPE rather than per
#              row, so it is not in `ase::analysis_nonsetting_keys` and the
#              `Options…` subdialog's reader and writer asked only that proc.
#              Measured on the unfixed tree through these very widgets -- the
#              whole table listed as one free-text NAME/VALUE pair, OK refusing
#              it, subdialog standing, nothing written -- and the writer's strip
#              would have DESTROYED the table on any commit that got past it.
#              ⚠ SP14 IS THE ROW ISSUE 1449 ASKED FOR: a port typed into the
#              table, through the real widgets, reaching a rendered `alter` line
#              and then a REAL RUN ON BOTH BINARIES that answers `S_1_1`. It is
#              the only row in this file that starts a simulator, and its match
#              is case-INSENSITIVE with the spelling reported, because the fork
#              writes `S_1_1` and apt 45.2 writes `s_1_1` into the same file for
#              the same deck.
#              The schema half is `test_ase_sp_1452.tcl` section SX, both arms.
#   NX1-NX6    ONE list of non-setting row keys (issue 1450). The `Options...`
#              subdialog kept its own copy of it -- twice, a reader and a writer,
#              both `{type enabled}` plus the declared fields -- so a row carrying
#              either of `DECISIONS.md` D4's two optional keys was LISTED there as
#              a free-text NAME/VALUE pair and then REFUSED at OK (`this dc
#              analysis has a setting named 'id' that ASE-L cannot emit`), leaving
#              the editor unusable on that row. `x` had been in that state since
#              issue 1419. All three sites now ask
#              `ase::analysis_nonsetting_keys`; NX5 proves they ASK by stubbing
#              it, and test_ase_core's NS2 is the fourth-copy guard.
#
# ⚠ TWO ROWS IN THIS FILE ARE RED ON THE DISPLAY ARM AND WERE RED BEFORE 1435
# -- verified by restoring src/ase.tcl and src/ase_window.tcl to HEAD 81312742
# and re-running: the same two rows, the same actual values, 283 passed either
# way. They are issue **1436**, filed rather than carried:
#   * `G2sens` expects `$top.chana.form.stop` NOT to exist for `sens`. Issue 1432
#     gave `sens` its AC mode -- `mode sweep points start stop`, every one
#     `depends {mode ac}` -- and `ase::ui::chana_show` builds every non-advanced
#     field whatever its `depends` says. So the widget is there and the row,
#     written for 1428's two-field `sens`, still says it is not. This is the
#     visible face of receipt 17's own deferred note: **`depends` has no
#     surface.**
#   * `GG9` expects `ase::analysis_detectable` to be 1 and Detect to be live. By
#     that point in this arm the capability cache is WARM. In a fresh process it
#     is cold and the row's premise holds; under a scratch HOME a THIRD row
#     (`GG3`) reds as well, so the leak is environmental. That is ISO1434's
#     lesson from the other side: a suite's isolation covers the REGISTRY, and
#     `ase::sim_status` falls back to `[auto_execok ngspice]`.
# T1 runs this file's HEADLESS arm only (37 checks, ALL PASS), so neither red is
# a T1 failure -- and neither is furniture.
# ⚠ MEASURED 2026-09-13, issue 1448: **one** of the two, not both. `G2sens` reds
# with the identical actual value `{1 1 0 1 0 Entry Entry normal}` recorded in
# issue 1436; `GG9` passed on every run of both arms, exactly as the paragraph
# above predicts (its premise needs a COLD capability cache). So the count in
# that paragraph is a timestamp and the mechanism is not.
#
# ⚠ RAISED, NEVER LOWERED. If a number falls, say which rows went and why, per
# row; do not edit the number downward to make the file agree with itself.

proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# --- helpers copied verbatim from tests/headless/test_ase_window.tcl ---------
# (each test is its own process — helpers are copied, not shared-sourced)

# the grid row a widget sits in, or -1 when it is not gridded at all (S4's
# Save All row shift: the third checkbox pushes Levels and the button bar down
# by one, and the existing rows drive those two by PATH)
proc ase_grid_row {w} {
  if {![winfo exists $w]} { return -1 }
  set gi [grid info $w]
  if {[dict exists $gi -row]} { return [dict get $gi -row] }
  return -1
}

# the treeview item whose $col cell equals $val, or {}
proc tv_find {tv col val} {
  foreach it [$tv children {}] {
    if {[$tv set $it $col] eq $val} { return $it }
  }
  return {}
}

# bbox of $item (optionally a cell) with a retry loop — WSLg can be slow to
# map the toplevel, and bbox is empty until the row is displayed
proc tv_bbox {tv item {col {}}} {
  for {set i 0} {$i < 100} {incr i} {
    update
    if {$col ne {}} { set bb [$tv bbox $item $col] } \
    else            { set bb [$tv bbox $item] }
    if {[llength $bb] == 4} { return $bb }
    after 50
  }
  return {}
}

# real double-click replay at the center of $item's row: Tk REFUSES `event
# generate <Double-1>`, so replay two press/release pairs — Tk's click-count
# machinery turns the second press into the <Double-1> match (the
# test_ase_view G1 idiom)
proc tv_dblclick {tv item} {
  set bb [tv_bbox $tv $item]
  if {[llength $bb] != 4} { return 0 }
  lassign $bb x y wdt hgt
  set cx [expr {$x + $wdt/2}]; set cy [expr {$y + $hgt/2}]
  foreach ev {<ButtonPress-1> <ButtonRelease-1> <ButtonPress-1> <ButtonRelease-1>} {
    event generate $tv $ev -x $cx -y $cy
  }
  update
  return 1
}

# real single click at the center of $item's $col cell (checkbox cells).
# `dx` shifts the click point horizontally: two consecutive generated clicks
# at the SAME spot classify as <Double-1> (generated events share the display
# timestamp, so Tk's 500ms window never expires — only a >5px offset breaks
# the multi-click chain).
proc tv_cell_click {tv item col {dx 0}} {
  set bb [tv_bbox $tv $item $col]
  if {[llength $bb] != 4} { return 0 }
  lassign $bb x y wdt hgt
  set cx [expr {$x + $wdt/2 + $dx}]; set cy [expr {$y + $hgt/2}]
  event generate $tv <ButtonPress-1> -x $cx -y $cy
  event generate $tv <ButtonRelease-1> -x $cx -y $cy
  update
  return 1
}

# deliver a REAL generated key event $ev to $w, WSLg-robustly. The W6c
# diagnosis, extended to EVERY generated-key site (item-06 fixer round 2,
# generalized from <Return>-only to any key for the item-10 ESC legs): Tk
# redirects GENERATED KeyPress events to the display's focus window, and
# under WSLg the X focus round-trip is asynchronous — an ungated
# `focus -force; update; event generate ...` intermittently lands the key on
# the previously-focused widget, so the product binding under test silently
# never fires (run 4: the W3 editor's Return was lost, cascading into 5
# FAILs; a lost W3t restore-to-27 left .temp 33 in the W6 deck). Gate every
# generate on Tk actually REPORTING $w as the focus owner, and retry the
# whole sequence until $done — an expr string evaluated in the CALLER's scope
# that proves the product binding really ran (dialog destroyed / state key
# changed / entry restored) — turns true. Returns 1 on proven delivery, 0 on
# timeout (~10s); the caller's own checks then report the real failure.
proc send_key {w ev done} {
  for {set i 0} {$i < 200} {incr i} {
    update
    if {[uplevel 1 [list expr $done]]} { return 1 }
    if {[winfo exists $w]} {
      focus -force $w
      update
      if {[uplevel 1 [list expr $done]]} { return 1 }
      if {[winfo exists $w] && [focus -displayof $w] eq $w} {
        event generate $w $ev
        update
        if {[uplevel 1 [list expr $done]]} { return 1 }
      }
    }
    after 50
  }
  puts "  send_key: $ev delivery to $w never confirmed (WSLg focus stall)"
  return 0
}

# the original 2-arg helper the pre-item-10 legs call (same contract)
proc send_return {w done} {
  return [uplevel 1 [list send_key $w <Return> $done]]
}

# --- local helper (extends the copied pair) ----------------------------------
# double-click aimed at a specific CELL: the analyses rows carry an Enable
# checkbox cell whose single-click handler toggles the flag, so a row-center
# double click could land there — aim at the harmless $col cell instead.
proc tv_dblclick_cell {tv item col} {
  set bb [tv_bbox $tv $item $col]
  if {[llength $bb] != 4} { return 0 }
  lassign $bb x y wdt hgt
  set cx [expr {$x + $wdt/2}]; set cy [expr {$y + $hgt/2}]
  foreach ev {<ButtonPress-1> <ButtonRelease-1> <ButtonPress-1> <ButtonRelease-1>} {
    event generate $tv $ev -x $cx -y $cy
  }
  update
  return 1
}

# --- issue 0648 helpers ------------------------------------------------------
# Every new-API call is catch-wrapped, so on a tree where the seam does not
# exist yet each row goes red on its own with `ERR: invalid command name ...`
# instead of aborting the whole GUI leg at the first missing proc.
# (Copied verbatim from tests/headless/test_ase_core.tcl, house style: each
# test is its own process, so helpers are copied and not shared-sourced.)
proc cx {script} {
  if {[catch {uplevel 1 $script} r]} { return "ERR: $r" }
  return $r
}
# the ase::echo pane sink, parked and collected (test_ase_core's c_echo_arm).
# ase::echo (ase.tcl:134) calls ::ciw_echo unconditionally when it exists, so
# renaming it is how every ASE suite captures a notice.
proc d_echo_arm {} {
  set ::d_echo {}
  if {[info commands ::d_saved_ciw_echo] eq {}} {
    if {[info commands ::ciw_echo] ne {}} { rename ::ciw_echo ::d_saved_ciw_echo }
    proc ::ciw_echo {msg {tag {}}} { lappend ::d_echo [list $tag $msg] }
  }
}
proc d_echo_disarm {} {
  if {[info commands ::d_saved_ciw_echo] ne {}} {
    catch {rename ::ciw_echo {}}
    rename ::d_saved_ciw_echo ::ciw_echo
  }
}
# how many collected messages match $pat -- a COUNT, not a boolean: "the
# discard is stated" and "the discard is stated ONCE" are different claims and
# a duplicated sentence is its own defect (issue 0635's subject).
proc d_echoed_n {pat} {
  set n 0
  foreach e $::d_echo { if {[string match -nocase $pat [lindex $e 1]]} { incr n } }
  return $n
}

# The same spy one channel further in, on `ase::echo` itself. `d_echo_arm`
# above parks ::ciw_echo; the 0691 failure lines are emitted by ase::echo
# (ase.tcl:180) -- do_load_state_from's own unloadable-FILE arm already calls
# it directly -- so they are read HERE. Copied verbatim in shape from
# tests/headless/test_ase_window.tcl's w_aecho_spy (each test is its own
# process: helpers are copied, not shared-sourced).
proc d_aecho_spy {script} {
  set ::d_aecho {}
  if {[info commands ::d_saved_ase_echo] eq {}} {
    if {[info commands ::ase::echo] ne {}} { rename ::ase::echo ::d_saved_ase_echo }
    proc ::ase::echo {msg {tag {}}} { lappend ::d_aecho [list $tag $msg] ; return 1 }
  }
  catch {uplevel 1 $script}
  if {[info commands ::d_saved_ase_echo] ne {}} {
    catch {rename ::ase::echo {}}
    rename ::d_saved_ase_echo ::ase::echo
  }
  return $::d_aecho
}
# just the `error`-tagged pairs of a d_aecho_spy result -- "it said something"
# and "it said ONE error-tagged sentence" are different claims (issue 0635)
proc d_aecho_errors {echoes} {
  set out {}
  foreach e $echoes { if {[lindex $e 0] eq {error}} { lappend out $e } }
  return $out
}

# --- locations (cwd-independent) --------------------------------------------
set here    [file normalize [file dirname [info script]]]      ;# tests/headless
set repo    [file normalize [file join $here .. ..]]           ;# repo root
set models  [file join $repo sky130A models libs.tech combined sky130.lib.spice]
source [file join $here scratch.tcl]
set scratch [test_scratch ase_dialogs]

# --- scratch lib/cell/view fixture + registry --------------------------------
# clean nfet schematic (the test_ase_core fixture: nfet_test_claude minus its
# corner + simulator_commands_shown instances)
set sch_text {v {xschem version=3.4.7RC file_version=1.2}
G {}
K {}
V {}
S {}
E {}
N 420 -330 600 -330 {}
N 380 -300 380 -330 {}
N 380 -330 250 -330 {}
N 250 -270 600 -270 {}
N 420 -300 420 -270 {}
C {sky130_fd_pr/nfet_01v8} 400 -300 0 0 {name=M1 W=1 L=0.15 nf=1}
C {devices/vsource} 600 -300 0 0 {name=V1 value=1}
C {devices/vsource} 250 -300 0 0 {name=V2 value=1.8}
C {devices/gnd} 510 -270 0 0 {name=GND1 lab=GND}
C {devices/lab_wire} 500 -330 0 0 {name=lD lab=D}
C {devices/lab_wire} 300 -330 0 0 {name=lG lab=G}
}
file mkdir [file join $scratch aselib nfet_clean schematic]
set f [open [file join $scratch aselib nfet_clean schematic nfet_clean.sch] w]
puts -nonewline $f $sch_text
close $f
set f [open [file join $scratch library.defs] w]
puts $f "DEFINE aselib [file join $scratch aselib]"
puts $f "DEFINE sky130_fd_pr [file join $repo sky130A xschem_libs sky130_fd_pr]"
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

set rundir  [file normalize [file join $scratch run]]

if {[catch {

# seed the state view through the REAL creation backend, then shape the nfet
# fixture state (models/variables/outputs/options, rundir -> scratch) through
# the session procs + session_save — itself code under test
library_new_view aselib nfet_clean ngspice_state1 ngspice_state1
set spath [xschem cellview_path aselib/nfet_clean ngspice_state1]
if {$spath eq {}} { error "fixture: state view did not resolve" }
set spath [file normalize $spath]
set key [ase::session_key aselib nfet_clean ngspice_state1]

ase::session_open $key $spath
set st [ase::session_state $key]
dict set st rundir $rundir
dict set st models [list [list file $models section tt]]
dict set st variables {{name Vgs value 1.8} {name Vds value 1.0}}
dict set st outputs {{name id expr -i(v1) save 1 plot 0}}
dict set st options {{name savecurrents value 1}}
ase::session_update $key $st
ase::session_save $key
ase::session_close $key

# a second, DIFFERING state view (Vgs 0.9) seeded through the real creation
# backend — the H4/G9 import fixture. Deliberately NOT created through the
# Save-As worker: the S2 sabotage class (worker view-creation broken) must
# fail exactly its H3/G7 targets, never cascade into the import legs.
library_new_view aselib nfet_clean ngspice_stateB ngspice_state1
set bpath [file normalize [xschem cellview_path aselib/nfet_clean ngspice_stateB]]
set stB [ase::state_load $spath]
dict set stB variables {{name Vgs value 0.9} {name Vds value 1.0}}
ase::state_save $bpath $stB

# --- H1: the trailing ro arg threads the session readonly attr (D7) ----------
check "H1 ro-open returns 1" [ase::open_state aselib nfet_clean ngspice_state1 1] 1
check "H1 ro-open sets the session readonly attr" \
  [ase::session_getattr $key readonly] 1
check "H1 plain reopen returns 1" [ase::open_state aselib nfet_clean ngspice_state1] 1
check "H1 plain reopen clears it" [ase::session_getattr $key readonly] 0

# --- H2: save_as_needs_confirm predicate (D8) --------------------------------
# ⚠ D13 IS RETIRED, AND THE USER RETIRED IT (2026-09-09). D13 read "overwriting
# a DIFFERENT existing view needs NO confirm in v1 -- the spec's only confirm
# trigger is read-only + same-target", and it described the shipped window
# accurately: measured that day on the live binary with session `ngspice_state1`
# open and its sibling view `debug_st1` present and writable,
# `save_as_needs_confirm` answered **0** for `debug_st1` -- so typing an
# existing sibling view into the Save-As form destroyed it with no warning at
# all. The user's ruling, verbatim: "Just confirm if overwriting an existing
# state." Undo was explicitly NOT asked for; a confirm was.
#
# THIS PREDICATE IS UNCHANGED BY THAT (batch decision S-1,
# doc/claude/ase_l_ux_batch/DECISIONS.md). It still answers exactly "the target
# IS my own file AND that file is effectively read-only", and the four rows
# below still pin it, byte for byte. The NEW door is
# `ase::ui::save_as_overwrites_other` -- section H2b.
#
# What the overrule DID change here is a NAME (S-9). The fourth row used to be
# called "H2 different target needs no confirm even readonly" -- a promise about
# the WINDOW, and the window no longer makes it. Renamed to name the PREDICATE
# and its value. Its assertion is untouched.
ase::session_setattr $key readonly 1
check "H2 needs_confirm: readonly + same target" \
  [ase::ui::save_as_needs_confirm $key aselib nfet_clean ngspice_state1] 1
ase::session_setattr $key readonly 0
check "H2 plain same target" \
  [ase::ui::save_as_needs_confirm $key aselib nfet_clean ngspice_state1] 0
file attributes $spath -permissions 0444
check "H2 unwritable file same target" \
  [ase::ui::save_as_needs_confirm $key aselib nfet_clean ngspice_state1] 1
file attributes $spath -permissions 0644
ase::session_setattr $key readonly 1
check "H2 needs_confirm: 0 for an unresolvable target, readonly or not" \
  [ase::ui::save_as_needs_confirm $key aselib nfet_clean ngspice_state9] 0
# ...and S-1's REAL pin, which the row above only looked like. `ngspice_state9`
# does not exist, so that call returns at the unresolvable guard and never
# reaches the own-vs-other comparison at all. `ngspice_stateB` DOES exist, is
# NOT this session's file, and the session is read-only-flagged besides: still
# 0. Widening save_as_needs_confirm to swallow the new case -- the thing S-1
# forbids -- turns THIS row red and no other.
check "H2 needs_confirm: 0 for an EXISTING target this session does not own, readonly or not" \
  [ase::ui::save_as_needs_confirm $key aselib nfet_clean ngspice_stateB] 0
ase::session_setattr $key readonly 0

# --- H2b: save_as_overwrites_other predicate (S-2 .. S-6) --------------------
# The second door, added 2026-09-09 when the user overruled D13: 1 iff the
# resolved target EXISTS and is NOT this session's own state file, else 0.
# `ngspice_stateB` is the fixture's second, DIFFERING state view (seeded above
# through library_new_view for the H4/G9 import legs) -- an existing file this
# session does not own, which is precisely the case that used to be destroyed
# in silence. `ngspice_state9` is never created by this fixture.
set fh [::open $bpath r]; set h2b_before [read $fh]; close $fh
check "H2b overwrites_other: a DIFFERENT, EXISTING state -> 1 (S-2)" \
  [ase::ui::save_as_overwrites_other $key aselib nfet_clean ngspice_stateB] 1
check "H2b overwrites_other: this session's OWN state -> 0 (S-4, that is what Save means)" \
  [ase::ui::save_as_overwrites_other $key aselib nfet_clean ngspice_state1] 0
check "H2b overwrites_other: a target that does not exist -> 0 (S-5, creating is not overwriting)" \
  [ase::ui::save_as_overwrites_other $key aselib nfet_clean ngspice_state9] 0
# read-only is the OTHER door's business and must not leak into this one
ase::session_setattr $key readonly 1
check "H2b overwrites_other: read-only does not change any of the three answers" \
  [list [ase::ui::save_as_overwrites_other $key aselib nfet_clean ngspice_stateB] \
        [ase::ui::save_as_overwrites_other $key aselib nfet_clean ngspice_state1] \
        [ase::ui::save_as_overwrites_other $key aselib nfet_clean ngspice_state9]] \
  {1 0 0}
# S-2's load-bearing claim: the two doors are mutually exclusive BY
# CONSTRUCTION (one arm needs target == own, the other target != own), so
# save_state_ok can chain them and never has to compose a sentence out of two
# reasons. Measured as a pair per target, in the ONE session state where both
# could plausibly fire -- read-only:
#   own -> {1 0}   different+existing -> {0 1}   missing -> {0 0}   never {1 1}
set h2b_pairs {}
foreach h2b_v {ngspice_state1 ngspice_stateB ngspice_state9} {
  lappend h2b_pairs [list \
    [ase::ui::save_as_needs_confirm    $key aselib nfet_clean $h2b_v] \
    [ase::ui::save_as_overwrites_other $key aselib nfet_clean $h2b_v]]
}
check "H2b the two doors are mutually exclusive on every target (never both 1)" \
  $h2b_pairs {{1 0} {0 1} {0 0}}
ase::session_setattr $key readonly 0

# S-3: an UNTITLED session owns NO file -- `ase::session_path` returns {}, issue
# 0141's marker -- so EVERY existing target is somebody else's, including the
# one this fixture's titled session is sitting on. That is the case where a
# clobber is most likely and least expected, so it is the case that must ask.
# The suite had no untitled session, so make one the way Tools > Launch ASE-L
# does: ase::new_session (src/ase.tcl:9840) registers under the untitled
# metaview, a key of its own, and is closed again below so no later leg inherits
# a second session on this design.
set uk [ase::new_session aselib nfet_clean schematic]
# ...and flagged read-only, deliberately: without the flag the last row of this
# group could not go red at all. `save_as_needs_confirm` only ever returns 1 on
# a readonly attr or an unwritable file, so an unflagged untitled session would
# answer 0 whether or not the proc still bails on `own eq {}` -- a green row
# measuring nothing. Flagged, dropping that bail turns it red and nothing else.
ase::session_setattr $uk readonly 1
check "H2b the untitled session really has no own file" [ase::session_path $uk] {}
check "H2b overwrites_other: UNTITLED + an EXISTING target -> 1 (S-3)" \
  [ase::ui::save_as_overwrites_other $uk aselib nfet_clean ngspice_state1] 1
check "H2b overwrites_other: UNTITLED + a target that does not exist -> 0 (S-5 holds untitled too)" \
  [ase::ui::save_as_overwrites_other $uk aselib nfet_clean ngspice_state9] 0
check "H2b needs_confirm stays 0 for a read-only-flagged UNTITLED session (no own file to be read-only)" \
  [ase::ui::save_as_needs_confirm $uk aselib nfet_clean ngspice_state1] 0
ase::session_close $uk

# PURITY, asserted rather than assumed: save_as_overwrites_other is called from
# an OK handler that has NOT yet decided to do anything. Probing a view that
# does not exist must not create it (contrast ase::rundir, which mkdirs and
# moves a process-global), and the sibling it just answered about must be
# byte-identical afterwards.
set fh [::open $bpath r]; set h2b_after [read $fh]; close $fh
check_true "H2b the predicate created nothing and wrote nothing" [expr {
  [xschem cellview_path aselib/nfet_clean ngspice_state9] eq {} &&
  [lsearch -exact [xschem cell_views aselib nfet_clean] ngspice_state9] < 0 &&
  $h2b_after eq $h2b_before}]

# --- H2c/H2d: the two overwrite sentences (S-7) ------------------------------
# Both live in the lbl_* family (src/ase_window.tcl:5578) so that neither is a
# magic string inside save_state_ok -- the save_all_report_discard drift of
# issue 0661 is what that family exists to prevent. Asserted THROUGH the procs;
# every other row in this suite that needs one of these sentences reads it from
# the proc too, so the literal is typed in exactly one place: here.
check "H2c lbl_overwrite_state is the ratified sentence" \
  [ase::ui::lbl_overwrite_state aselib nfet_clean ngspice_stateB] \
  {State aselib/nfet_clean/ngspice_stateB exists. Overwrite?}
# ...and it really INTERPOLATES all three arguments rather than naming a fixed
# target: substituting the fixture's l/c/v out of one rendering must reproduce
# the rendering taken with placeholder arguments. A proc that dropped, swapped
# or hardcoded any of the three fails here; a proc that interpolated nothing at
# all fails the row above.
check "H2c lbl_overwrite_state interpolates the lib/cell/view it was given" \
  [ase::ui::lbl_overwrite_state L C V] \
  [string map {aselib L nfet_clean C ngspice_stateB V} \
     [ase::ui::lbl_overwrite_state aselib nfet_clean ngspice_stateB]]
# The read-only sentence was MOVED into the family, not rewritten: it is the
# string that shipped, byte for byte, embedded newline included. The mint was
# meant to change zero pixels on the arm it did not come to change, and this
# row is what says so.
check "H2d lbl_overwrite_readonly is the SHIPPED read-only sentence, unchanged" \
  [ase::ui::lbl_overwrite_readonly aselib nfet_clean ngspice_state1] \
  "The state aselib/nfet_clean/ngspice_state1 was opened read-only.\nOverwrite it?"
check "H2d ...and its embedded newline survived the move (two lines, not one)" \
  [llength [split [ase::ui::lbl_overwrite_readonly aselib nfet_clean ngspice_state1] \n]] 2
# same structural interpolation test as H2c, for the same reason: a sentence
# that hardcoded one of its three components would render IDENTICALLY under the
# row above (which feeds it the very values it hardcoded) and only shows up when
# the arguments change.
check "H2d ...and it interpolates its lib/cell/view too" \
  [ase::ui::lbl_overwrite_readonly L C V] \
  [string map {aselib L nfet_clean C ngspice_state1 V} \
     [ase::ui::lbl_overwrite_readonly aselib nfet_clean ngspice_state1]]

# --- H3: do_save_state_as creates a missing view (D9) ------------------------
set r3 [ase::ui::do_save_state_as $key aselib nfet_clean ngspice_state2]
set p2 [xschem cellview_path aselib/nfet_clean ngspice_state2]
check_true "H3 do_save_state_as creates a new view dir" \
  [expr {$r3 == 1 && $p2 ne {}}]
check_true "H3 cell_views lists the created view" \
  [expr {[lsearch -exact [xschem cell_views aselib nfet_clean] ngspice_state2] >= 0}]
set c2 {}
catch {set f [::open $p2 r]; set c2 [read $f]; close $f}
check "H3 created file carries this session's serialization" \
  $c2 "[ase::state_serialize [ase::session_state $key]]\n"

# --- H3b (0691 SWEEP): do_save_state_as REFUSES a key nobody is under --------
# 0691's "weaker second arm". Measured at HEAD, headless: an unknown key makes
# `ase::session_path` return {} -- the SAME value that marks an untitled session
# -- so control reaches the `own eq {}` adopt arm at ase_window.tcl:3800-3805.
# library_new_view CREATES the view, a defaults-state file is written into it,
# `ase::session_adopt` returns 0 into a discarded value (:3804) and the proc
# ends in its hardcoded `return 1` (:3815):
#   H3B catch=0 res=1
#   H3B viewpath = .../aselib/nfet_clean/ngspice_stateH3B/nfet_clean.state
#   H3B echoes   = {{} {ase: state saved to aselib/nfet_clean/ngspice_stateH3B}}
# The lie and the bogus view arrive together, so the row pins both: refusing
# BEFORE any write removes the manufactured 1 and the litter in one guard.
set h3b_key {H3B-NO-SESSION}
set h3b_e [d_aecho_spy \
  {set ::h3b_rc [ase::ui::do_save_state_as $h3b_key aselib nfet_clean ngspice_stateH3B]}]
set h3b_err [d_aecho_errors $h3b_e]
check "H3b 0691 do_save_state_as REFUSES a key no session is under: returns 0,\
 creates NO view (and therefore no state file), and says so exactly once tagged\
 error" \
  [list [expr {[info exists ::h3b_rc] ? $::h3b_rc : {NO-RETURN}}] \
        [expr {[xschem cellview_path aselib/nfet_clean ngspice_stateH3B] ne {} ? 1 : 0}] \
        [llength $h3b_err] \
        [expr {[llength $h3b_err] == 1 ? [lindex $h3b_err 0 0] : {NO-ONE-LINE}}]] \
  {0 0 1 error}

# --- H4: do_load_state_from imports content + dirty (D10) --------------------
# import the differing stateB content (seeded in the fixture)
check "H4 session clean before the import" [ase::session_dirty $key] 0
set r4 [ase::ui::do_load_state_from $key $bpath]
check "H4 worker returns success" $r4 1
check "H4 do_load_state_from imports content" \
  [ase::state_get [ase::session_state $key] variables] \
  {{name Vgs value 0.9} {name Vds value 1.0}}
check "H4 session dirty after the import" [ase::session_dirty $key] 1
ase::session_revert $key
check "H4 revert leaves the session clean" [ase::session_dirty $key] 0

# --- H4b/H4c/H4d (0691): the witness, the sentence, and the ONE sentence -----
# `ase::ui::do_load_state_from` (ase_window.tcl:3575-3587) is honest about the
# FILE (:3576-3579) and never about the KEY: `ase::session_update`'s answer is
# discarded at :3580 and the proc ends in a hardcoded `return 1` at :3586 --
# the identical shape 0679 just fixed one proc over in `save_all_apply`.
# Measured at HEAD, headless, at the same commit as the repaired twin:
#   session_update(BOGUS)      = 0    <- honest
#   do_load_state_from(BOGUS)  = 1    <- fabricated
#   save_all_apply(BOGUS)      = 0    <- 0679's repair holding
# So "Load State into a session that is gone" reports success, changes nothing
# and says nothing.
set h4_key {H4B-NO-SESSION}
set h4b_bad  [d_aecho_spy {set ::h4b_badrc  [ase::ui::do_load_state_from $h4_key $bpath]}]
set h4b_good [d_aecho_spy {set ::h4b_goodrc [ase::ui::do_load_state_from $key $bpath]}]
check "H4b 0691 do_load_state_from reports FAILURE for a key no session is under\
 and SUCCESS for the registered one -- both arms from the SAME loadable file in\
 one tuple, so a proc hardwired to either value fails one half" \
  [list [expr {[info exists ::h4b_badrc] ? $::h4b_badrc : {NO-RETURN}}] \
        [expr {[info exists ::h4b_goodrc] ? $::h4b_goodrc : {NO-RETURN}}]] \
  {0 1}

set h4c_err [d_aecho_errors $h4b_bad]
check "H4c 0691 the refused import is NOT SILENT: exactly one ase::echo, tagged\
 error, naming the key it could not find -- and the successful import says\
 nothing at all" \
  [list [llength $h4c_err] \
        [expr {[llength $h4c_err] == 1 ? [lindex $h4c_err 0 0] : {NO-ONE-LINE}}] \
        [expr {[llength $h4c_err] == 1 &&
               [string first $h4_key [lindex $h4c_err 0 1]] >= 0 ? 1 : 0}] \
        [llength $h4b_good]] \
  {1 error 1 0}

# H4d: GREEN AT HEAD, and the row that stops the fix growing a SECOND sentence.
# The unloadable-FILE arm already emits one error-tagged line; the new
# unknown-KEY arm must be mutually exclusive with it, not additive.
set h4d [d_aecho_spy \
  {set ::h4d_rc [ase::ui::do_load_state_from $key [file join $scratch h4d-no-such.state]]}]
set h4d_err [d_aecho_errors $h4d]
check "H4d 0691 THE ECHO DOES NOT DOUBLE-FIRE: an unloadable FILE into a\
 REGISTERED key still returns 0 with exactly one error-tagged line" \
  [list [expr {[info exists ::h4d_rc] ? $::h4d_rc : {NO-RETURN}}] \
        [llength $h4d_err] \
        [expr {[llength $h4d_err] == 1 ? [lindex $h4d_err 0 0] : {NO-ONE-LINE}}]] \
  {0 1 error}

# H4b's registered arm re-imported stateB: leave the session exactly as the H4
# block left it, so the GUI legs below open on a clean session.
ase::session_revert $key
check "H4d the H block leaves the session clean again" [ase::session_dirty $key] 0

# drop the H session so the GUI legs exercise a fresh window build
if {[info exists ::has_x] && [info commands winfo] ne {}} {
  ase::ui::close $key; update
} else {
  ase::session_close $key
}

# --- GUI legs (DISPLAY-guarded partial skip) ---------------------------------
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  check "G1 open_state -> 1" [ase::open_state aselib nfet_clean ngspice_state1] 1
  update
  set top [ase::ui::window_for $key]
  check_true "G1 session window up" [expr {$top ne {} && [winfo exists $top]}]

  # G1: Choose Analyses opens from the menu (default preselect op), from the
  # OP,TR strip button, and from an analyses-row double-click (that row's
  # type preselected)
  $top.mb.analyses invoke "Choose\u2026"
  update
  check_true "G1 menu Choose Analyses opens the dialog" [winfo exists $top.chana]
  check "G1 menu open preselects op" $::ase::ui::dlg($key,antype) op
  $top.chana.btns.cancel invoke
  update
  $top.strip.ana invoke
  update
  check_true "G1 OP,TR strip opens Choose Analyses" [winfo exists $top.chana]
  $top.chana.btns.cancel invoke
  update
  set atv $top.body.ana.tv
  set dcit [tv_find $atv type dc]
  check_true "G1 analyses pane has the dc row" [expr {$dcit ne {}}]
  tv_dblclick_cell $atv $dcit type
  check_true "G1 dbl-click opens Choose Analyses" [winfo exists $top.chana]
  check "G1 dbl-click dc row preselects dc" $::ase::ui::dlg($key,antype) dc

  # G2: dc quick fields round trip through the dialog OK (dialog is still up
  # and preselected dc from G1)
  foreach {fld val} {source V2 start 0 stop 1.8 step 0.01} {
    $top.chana.form.$fld delete 0 end
    $top.chana.form.$fld insert 0 $val
  }
  set ::ase::ui::dlg($key,anen) 1
  send_return $top.chana.form.step {![winfo exists $top.chana]}
  check_true "G2 dialog closed on Return" [expr {![winfo exists $top.chana]}]
  set dcrow {}
  foreach a [ase::state_get [ase::session_state $key] analyses] {
    if {[ase::state_get $a type] eq {dc}} { set dcrow $a; break }
  }
  check "G2 Choose Analyses round-trips dc quick fields" \
    [list [ase::state_get $dcrow enabled] [ase::state_get $dcrow source] \
          [ase::state_get $dcrow start] [ase::state_get $dcrow stop] \
          [ase::state_get $dcrow step]] \
    {1 V2 0 1.8 0.01}
  set dcit [tv_find $atv type dc]
  ## ⚠ STAGE 1 MOVED THIS STRING, DELIBERATELY, AND IT IS THE ONE VISIBLE
  ## CHANGE OF THE WHOLE STAGE. The Arguments column stops being a key dump and
  ## becomes THE LINE THE DECK WILL CARRY -- ase::ui::arg_summary now calls
  ## ase::analysis_line, the same proc render_deck emits, so the pane cannot
  ## show a setting the deck does not have. It is a DISPLAY string, not deck
  ## output: deck golden D1 and the 17-case render corpus are byte-identical.
  check "G2 Arguments summary is the line the deck will carry" \
    [expr {$dcit ne {} ? [$atv set $dcit args] : {}}] \
    {dc V2 0 1.8 0.01}

  # G2b: D6 rejection — an ENABLED tran with a blank step is refused, the
  # dialog survives, the state is untouched. Driven through the OK BUTTON:
  # a rejection has no observable delivery witness, so a WSLg-dropped
  # <Return> would make this leg hollow-green (Return delivery is proven by
  # G2 above).
  $top.strip.ana invoke
  update
  $top.chana.types.tran invoke
  update
  set ::ase::ui::dlg($key,anen) 1
  $top.chana.form.stop delete 0 end
  $top.chana.form.stop insert 0 10u
  $top.chana.form.step delete 0 end
  set ana_before [ase::state_get [ase::session_state $key] analyses]
  $top.chana.btns.proceed invoke
  update
  check_true "G2b enabled tran with blank step rejected (dialog survives)" \
    [winfo exists $top.chana]
  check "G2b state unchanged on rejection" \
    [ase::state_get [ase::session_state $key] analyses] $ana_before
  $top.chana.btns.cancel invoke
  update

  # G2c: THE CONVERSE OF G2b, AND THE ROW THE D6 REPLACEMENT EXISTS FOR.
  ## ⚠ G2b ALONE WOULD HAVE STAYED GREEN THROUGH ISSUE 1416. The old door
  ## demanded that EVERY field of the type be non-empty, which was only ever
  ## right because every field of every type happened to be `required 1`. tran
  ## gained three OPTIONAL fields, so the old loop would refuse a row ngspice
  ## runs perfectly well -- and refuse it naming a field the user was never
  ## obliged to fill. Nothing in the suite would have said so: G2b asserts a
  ## REFUSAL, and a door that refuses everything satisfies it.
  ##
  ## ⚠ THE DISCLOSURE IS OPENED FIRST, DELIBERATELY. With it closed the three
  ## optional widgets do not exist, so a fixture that "left them blank" would be
  ## proving nothing -- it would be proving that a field the form never built
  ## cannot block a commit. Opening it makes the row assert what it claims.
  $top.strip.ana invoke
  update
  $top.chana.types.tran invoke
  update
  ## This row asserts the DEFAULT state, so it says so rather than relying on
  ## being the first row in the file that happens to touch the disclosure.
  set ::ase::ui::dlg($key,advopen) 0
  ase::ui::chana_show $key
  update
  check_true "G2c the tran form opens with an Advanced disclosure, closed" \
    [expr {[winfo exists $top.chana.form.advbtn] \
           && ![winfo exists $top.chana.form.tstart]}]
  check "G2c closed, the form shows exactly the two REQUIRED fields" \
    [list [winfo exists $top.chana.form.step] [winfo exists $top.chana.form.stop] \
          [winfo exists $top.chana.form.tstart] [winfo exists $top.chana.form.tmax] \
          [winfo exists $top.chana.form.uic]] {1 1 0 0 0}
  ## The disclosure TOGGLES and is remembered for the window, so every fixture
  ## that wants it open asks for the state rather than assuming a fresh dialog.
  if {![winfo exists $top.chana.form.tstart]} {
    $top.chana.form.advbtn invoke
    update
  }
  check "G2c open, all five are there and uic is a checkbutton, not an entry" \
    [list [winfo exists $top.chana.form.tstart] [winfo exists $top.chana.form.tmax] \
          [winfo exists $top.chana.form.uic] \
          [winfo class $top.chana.form.uic]] {1 1 1 Checkbutton}
  ## ⚠ AND THE LABELS CARRY THEIR UNITS. `Stop time:` and `Stop time (s):` are
  ## different questions, and the second is the one the simulator is asking.
  check "G2c the labels are the declared ones and carry their units" \
    [list [$top.chana.form.lstep cget -text] [$top.chana.form.lstop cget -text] \
          [$top.chana.form.ltstart cget -text]] \
    {{Time step (s):} {Stop time (s):} {Start recording at (s):}}
  set ::ase::ui::dlg($key,anen) 1
  foreach {fld val} {step 1n stop 10u} {
    $top.chana.form.$fld delete 0 end
    $top.chana.form.$fld insert 0 $val
  }
  foreach fld {tstart tmax} { $top.chana.form.$fld delete 0 end }
  set ::ase::ui::dlg($key,fld,uic) 0
  set g2c_before [ase::state_get [ase::session_state $key] analyses]
  $top.chana.btns.proceed invoke
  update
  check_true "G2c an enabled tran with its two required values and all three\
 optional ones VISIBLE and blank is COMMITTED, not refused" \
    [expr {![winfo exists $top.chana]}]
  set g2crow {}
  foreach a [ase::state_get [ase::session_state $key] analyses] {
    if {[ase::state_get $a type] eq {tran}} { set g2crow $a; break }
  }
  ## ⚠ AND THE BLANK OPTIONAL FIELDS LEAVE NO KEY BEHIND. A door that stored an
  ## empty `tstart` would put a key on disk that every one of the 104 committed
  ## benches lacks, and the round-trip this batch is measured against would stop
  ## being byte-identical the first time anyone opened the dialog.
  check "G2c a blank optional field writes no key at all" \
    [list [ase::state_get $g2crow enabled] [ase::state_get $g2crow step] \
          [ase::state_get $g2crow stop] [lsort [dict keys $g2crow]]] \
    {1 1n 10u {enabled step stop type}}
  set g2cit [tv_find $atv type tran]
  check "G2c and the Arguments column shows the three words the deck will carry" \
    [expr {$g2cit ne {} ? [$atv set $g2cit args] : {}}] {tran 1n 10u}

  # G2h: TICKING THE BOX REACHES THE DECK. THIS IS THE BATCH'S OWN ACCEPTANCE
  # CRITERION, STATED AS ONE ROW: nothing the window shows may fail to reach the
  # deck, and nothing the deck contains may be unshowable in the window.
  ## ⚠ G2c IS NOT THIS ROW AND CANNOT BE. G2c leaves the box CLEAR and asserts
  ## that no key is written -- which a `form_get` that always answered 0, or a
  ## checkbutton wired to nothing at all, would satisfy perfectly. MEASURED: a
  ## sabotage making the bool arm return a constant 0 passes every other row in
  ## this file. The only thing that catches it is switching the control ON and
  ## following the value all the way to the emitted line.
  $top.strip.ana invoke
  update
  $top.chana.types.tran invoke
  update
  if {![winfo exists $top.chana.form.uic]} {
    $top.chana.form.advbtn invoke
    update
  }
  set ::ase::ui::dlg($key,anen) 1
  foreach {fld val} {step 1n stop 10u} {
    $top.chana.form.$fld delete 0 end
    $top.chana.form.$fld insert 0 $val
  }
  foreach fld {tstart tmax} { $top.chana.form.$fld delete 0 end }
  ## A real gesture, not a poke at the variable: `invoke` is what a click does.
  if {[ase::ui::form_get $key uic] ne {1}} {
    $top.chana.form.uic invoke
    update
  }
  check "G2h clicking the box actually turns it on" \
    [ase::ui::form_get $key uic] 1
  $top.chana.btns.proceed invoke
  update
  set g2hrow {}
  foreach a [ase::state_get [ase::session_state $key] analyses] {
    if {[ase::state_get $a type] eq {tran}} { set g2hrow $a; break }
  }
  set g2hit [tv_find $atv type tran]
  ## ⚠ AND THE BACK-FILL IS VISIBLE HERE TOO. `uic` is the fifth positional slot,
  ## so turning it on with no start time emits the start time's `whenskipped`
  ## value -- `tran 1n 10u 0 uic`, not `tran 1n 10u uic`. Issue 1416.
  check "G2h a ticked box is stored, reaches the emitted line, and back-fills the\
 positional slot it skipped over" \
    [list [ase::state_get $g2hrow uic] \
          [expr {$g2hit ne {} ? [$atv set $g2hit args] : {}}]] \
    {1 {tran 1n 10u 0 uic}}
  ## ⚠ AND CLEARING IT AGAIN REMOVES THE KEY, rather than leaving `uic 0` behind.
  $top.strip.ana invoke
  update
  $top.chana.types.tran invoke
  update
  if {![winfo exists $top.chana.form.uic]} {
    $top.chana.form.advbtn invoke
    update
  }
  check "G2h reopening shows the box still ticked, because the bench says so" \
    [ase::ui::form_get $key uic] 1
  $top.chana.form.uic invoke
  update
  set ::ase::ui::dlg($key,anen) 1
  $top.chana.btns.proceed invoke
  update
  set g2hrow2 {}
  foreach a [ase::state_get [ase::session_state $key] analyses] {
    if {[ase::state_get $a type] eq {tran}} { set g2hrow2 $a; break }
  }
  check "G2h clearing it removes the key entirely instead of storing an off" \
    [list [lsort [dict keys $g2hrow2]] \
          [expr {[set i [tv_find $atv type tran]] ne {} ? [$atv set $i args] : {}}]] \
    [list {enabled step stop type} {tran 1n 10u}]

  # G2tf: THE TRANSFER FUNCTION CAN BE CHOSEN AT ALL. Stage 5, issue 1426.
  ## ⚠ UNTIL THIS COMMIT `tf` WAS A CELL YOU COULD SELECT AND NOT USE. It was
  ## `registered 1` with a `role probe` card and nothing else, so the grid showed
  ## it exists, `ase::analysis_renderable` answered 0, the Enable checkbutton was
  ## disabled and the form below it was empty. A user could see that ngspice has
  ## a DC small-signal transfer function and could not ask for one.
  ##
  ## ⚠ THIS IS THE HALF test_ase_core CANNOT ASSERT. Section TF there pins the
  ## registry and the deck bytes; only a real widget can say that the two fields
  ## are BUILT, that the previous type's widgets are GONE from the same frame,
  ## and that Enable is live. `$w.form` is destroyed whole on every rebuild
  ## (Stage 1's `.form` child frame) -- the hardcoded five-name destroy list this
  ## replaced would have left `step` and `stop` standing behind a tf form.
  $top.strip.ana invoke
  update
  $top.chana.types.tf invoke
  update
  check "G2tf selecting tf builds its two fields, leaves none of tran's behind,\
 and leaves Enable live" \
    [list [winfo exists $top.chana.form.out] [winfo exists $top.chana.form.insrc] \
          [winfo exists $top.chana.form.step] [winfo exists $top.chana.form.stop] \
          [winfo exists $top.chana.form.uic] \
          [winfo class $top.chana.form.out] \
          [string tolower [$top.chana.enable cget -state]]] \
    {1 1 0 0 0 Entry normal}
  ## ⚠ THE LABELS ARE THE DECLARED ONES, and they are NEW USER-FACING COPY --
  ## ⚖ R9, recorded as an `owed.sh add rule 1426` debt rather than ratified here.
  check "G2tf the two labels are the declared ones" \
    [list [$top.chana.form.lout cget -text] [$top.chana.form.linsrc cget -text]] \
    [list {Output:} {Input source:}]
  ## ⚠ AND THE WHOLE ROUND TRIP, BECAUSE A FORM THAT BUILDS AND DOES NOT COMMIT
  ## IS THE DEFECT THIS BATCH IS NAMED FOR. Type both values, tick Enable, press
  ## OK, and follow them to the stored row AND to the Arguments column -- which
  ## is `ase::analysis_line`, the same proc render_deck emits.
  set ::ase::ui::dlg($key,anen) 1
  foreach {fld val} {out v(D) insrc V1} {
    $top.chana.form.$fld delete 0 end
    $top.chana.form.$fld insert 0 $val
  }
  $top.chana.btns.proceed invoke
  update
  check_true "G2tf an enabled tf row with both values is COMMITTED, not refused" \
    [expr {![winfo exists $top.chana]}]
  set g2tfrow {}
  foreach a [ase::state_get [ase::session_state $key] analyses] {
    if {[ase::state_get $a type] eq {tf}} { set g2tfrow $a; break }
  }
  set g2tfit [tv_find $atv type tf]
  check "G2tf the tf row round-trips and the Arguments column is the line the\
 deck will carry" \
    [list [ase::state_get $g2tfrow enabled] [ase::state_get $g2tfrow out] \
          [ase::state_get $g2tfrow insrc] [lsort [dict keys $g2tfrow]] \
          [expr {$g2tfit ne {} ? [$atv set $g2tfit args] : {}}]] \
    [list 1 {v(D)} V1 {enabled insrc out type} {tf v(D) V1}]
  ## ⚠ AND THE DOOR STILL SHUTS ON A HALF-FILLED ONE. Without this the row above
  ## is satisfied by a door that commits anything -- the G2b/G2c pair's lesson,
  ## which this file learned by having only one side of it.
  $top.strip.ana invoke
  update
  $top.chana.types.tf invoke
  update
  set ::ase::ui::dlg($key,anen) 1
  $top.chana.form.insrc delete 0 end
  set g2tf_before [ase::state_get [ase::session_state $key] analyses]
  $top.chana.btns.proceed invoke
  update
  ## ⚠ THE STATUS LINE IS READ INSIDE THIS ROW'S OWN `catch`, AND THAT IS NOT
  ## DEFENSIVE PADDING -- IT IS WHAT THE SABOTAGE ASKED FOR. A bare
  ## `$top.chana.status cget -text` here is only legal while the dialog is still
  ## up, so the one change this row exists to catch -- `insrc` losing its
  ## `required 1`, after which OK COMMITS AND CLOSES -- raised
  ## `invalid command name ".ase5.chana.status"` and killed the whole file at 65
  ## of 271 instead of reddening a row. A suite that dies names the defect with a
  ## line number; a row that reds names it with a sentence.
  set g2tf_alive [expr {[winfo exists $top.chana] ? 1 : 0}]
  set g2tf_said 0
  if {$g2tf_alive} {
    catch {
      set g2tf_said [expr {[string first {insrc} \
        [$top.chana.status cget -text]] >= 0}]
    }
  }
  check "G2tf an enabled tf row with no input source is refused, the dialog\
 survives and the state is untouched" \
    [list $g2tf_alive $g2tf_said \
          [ase::state_get [ase::session_state $key] analyses]] \
    [list 1 1 $g2tf_before]
  ## Leave the bench as the rest of this file found it: no tf row. ⚠ The cancel
  ## is caught for the same reason as the read above -- under the sabotage the
  ## dialog is already gone, and the cleanup must not become a second casualty.
  catch {$top.chana.btns.cancel invoke}
  update
  set g2tf_st [ase::session_state $key]
  set g2tf_rows {}
  foreach a [ase::state_get $g2tf_st analyses] {
    if {[ase::state_get $a type] ne {tf}} { lappend g2tf_rows $a }
  }
  dict set g2tf_st analyses $g2tf_rows
  ase::session_update $key $g2tf_st
  ase::ui::populate $key
  update
  check "G2tf the fixture is left without a tf row, so the rows below see the\
 bench they were written against" \
    [tv_find $atv type tf] {}

  # G2pz: THE POLE-ZERO ANALYSIS CAN BE CHOSEN AT ALL. Stage 5, issue 1427.
  ## ⚠ UNTIL THIS COMMIT `pz` WAS A CELL YOU COULD SELECT AND NOT USE, exactly as
  ## `tf` was one commit ago: `registered 1` with a `role probe` card and nothing
  ## else, so the grid showed it exists, `ase::analysis_renderable` answered 0,
  ## the Enable checkbutton was disabled and the form below it was empty.
  ##
  ## ⚠ AND IT IS THE FIRST ANALYSIS WHOSE FORM MIXES THREE WIDGET CLASSES. Four
  ## entries (`kind node`, a kind this registry had never declared) and TWO
  ## comboboxes (`kind mode`). `test_ase_core` section PZ pins the registry and
  ## the deck bytes; only a real widget can say that six controls are BUILT, that
  ## the two pickers are COMBOBOXES rather than text boxes, and that the previous
  ## type's widgets are gone from the same `$w.form` frame.
  $top.strip.ana invoke
  update
  $top.chana.types.pz invoke
  update
  check "G2pz selecting pz builds four node entries and two pickers, leaves none\
 of tran's behind, and leaves Enable live" \
    [list [winfo exists $top.chana.form.inp] [winfo exists $top.chana.form.inn] \
          [winfo exists $top.chana.form.outp] [winfo exists $top.chana.form.outn] \
          [winfo exists $top.chana.form.transfer] [winfo exists $top.chana.form.mode] \
          [winfo exists $top.chana.form.step] [winfo exists $top.chana.form.stop] \
          [winfo class $top.chana.form.inp] \
          [winfo class $top.chana.form.mode] \
          [string tolower [$top.chana.enable cget -state]]] \
    {1 1 1 1 1 1 0 0 Entry TCombobox normal}
  ## ⚠ THE PICKERS OPEN SHOWING THE DECLARED DEFAULT, NOT BLANK, AND THAT IS A
  ## BYTE-IDENTITY RULE RATHER THAN A COSMETIC ONE (issue 1416's `sweep` lesson).
  ## A bench storing neither key renders `pz in 0 out 0 vol pz`; a blank picker
  ## beside a deck line that says `vol pz` is the window disagreeing with the
  ## file.
  ## ⚠ EVERY `cget` HERE GOES THROUGH `g2pz_cget`, AND THAT IS WHAT THE SABOTAGE
  ## ASKED FOR. `-values` exists only on a combobox, so the one change this row
  ## exists to catch -- a picker declared `kind node` and built as a text box --
  ## raised `unknown option "-values"` and killed the whole file at 67 of 278
  ## instead of reddening a row. MEASURED (sabotage S33), the same lesson G2tf's
  ## last row records about reading a destroyed dialog.
  proc g2pz_cget {w opt} {
    if {[catch {$w cget $opt} v]} { return NOOPT }
    return $v
  }
  ## ⚠ THE WORDS IN THE PICKER ARE THE READABLE ONES SINCE ⚖ R9 RULING A2
  ## (2026-09-16), AND THE DECK'S ARE UNCHANGED. This golden read
  ## `vol pz {vol cur} {pz pol zer}` -- ngspice's own spelling, straight onto the
  ## user's screen. The ruling maps the DISPLAY only: the row still stores `vol`
  ## and the deck line below is still `pz in 0 out 0 vol pz`. `test_ase_core`
  ## section PZ2e pins the registry's `values` (still the deck words) and PZ2f
  ## pins the map itself.
  check "G2pz the pickers open on the declared default, spell it the way a\
 person reads it, and the labels are the declared ones" \
    [list [$top.chana.form.transfer get] [$top.chana.form.mode get] \
          [g2pz_cget $top.chana.form.transfer -values] \
          [g2pz_cget $top.chana.form.mode -values] \
          [g2pz_cget $top.chana.form.linp -text] \
          [g2pz_cget $top.chana.form.linn -text] \
          [g2pz_cget $top.chana.form.lmode -text]] \
    [list Voltage PZ {Voltage Current} {PZ Poles Zeroes} {Input +:} {Input -:} {Find:}]
  ## ⚠ THE WHOLE ROUND TRIP, AND THE PART THAT MATTERS IS WHAT IS **NOT** STORED.
  ## Typing only the two signal nodes must store only those two keys: the pickers
  ## answer their own defaults, and `form_is_absent` drops a value that equals the
  ## declared default. A bench that stored `transfer vol mode pz` would be a bench
  ## whose `.state` file grew two keys the moment somebody opened the dialog.
  set ::ase::ui::dlg($key,anen) 1
  foreach {fld val} {inp in outp out} {
    $top.chana.form.$fld delete 0 end
    $top.chana.form.$fld insert 0 $val
  }
  $top.chana.btns.proceed invoke
  update
  check_true "G2pz an enabled pz row with both signal nodes is COMMITTED, not refused" \
    [expr {![winfo exists $top.chana]}]
  set g2pzrow {}
  foreach a [ase::state_get [ase::session_state $key] analyses] {
    if {[ase::state_get $a type] eq {pz}} { set g2pzrow $a; break }
  }
  set g2pzit [tv_find $atv type pz]
  check "G2pz the pz row round-trips storing only what differs from the deck's\
 own defaults, and the Arguments column is the line the deck will carry" \
    [list [ase::state_get $g2pzrow enabled] [ase::state_get $g2pzrow inp] \
          [ase::state_get $g2pzrow outp] [lsort [dict keys $g2pzrow]] \
          [expr {$g2pzit ne {} ? [$atv set $g2pzit args] : {}}]] \
    [list 1 in out {enabled inp outp type} {pz in 0 out 0 vol pz}]
  ## ⚠ AND A NON-DEFAULT PICK **IS** STORED AND **DOES** REACH THE LINE. Without
  ## this the row above is satisfied by a form whose pickers are decoration.
  $top.strip.ana invoke
  update
  $top.chana.types.pz invoke
  update
  ## ⚠ THE TWO GESTURES ARE CAUGHT FOR THE SAME REASON THE READS ABOVE ARE. A
  ## combobox takes `set`; an Entry does not, and raises `bad option "set"`. So
  ## a picker declared as the wrong kind would kill the file here even with the
  ## reads hardened -- which is exactly what sabotage S33 did, twice. The
  ## RETURN CODE is recorded as an ordinary value, so the row reds naming the
  ## gesture that could not be made.
  set ::ase::ui::dlg($key,anen) 1
  ## ⚠ AND THE GESTURE USES THE WORD THE USER CAN SEE, NOT THE DECK WORD. This
  ## read `set pol` / `set cur` until ⚖ R9 A2, and leaving it that way would have
  ## been a row proving nothing: `ase::field_label_value` falls back to IDENTITY
  ## for a label it cannot map, so typing the DECK word straight into the picker
  ## went on storing `pol` with the whole display mapping BYPASSED -- MEASURED on
  ## this change, the row stayed green with the map never once consulted. Picking
  ## `Poles` and getting `pol` on the line below is the write direction proven.
  set g2pz_pick [list [catch {$top.chana.form.mode set Poles}] \
                      [catch {$top.chana.form.transfer set Current}]]
  $top.chana.btns.proceed invoke
  update
  set g2pzrow2 {}
  foreach a [ase::state_get [ase::session_state $key] analyses] {
    if {[ase::state_get $a type] eq {pz}} { set g2pzrow2 $a; break }
  }
  check "G2pz a non-default pick is made with a real picker gesture, is stored,\
 and reaches the emitted line" \
    [list $g2pz_pick [lsort [dict keys $g2pzrow2]] \
          [expr {[set i [tv_find $atv type pz]] ne {} ? [$atv set $i args] : {}}]] \
    [list {0 0} {enabled inp mode outp transfer type} {pz in 0 out 0 cur pol}]

  ## G2a2: ⚖ R9 A2 -- THE READ DIRECTION, WHICH IS THE HALF A WRITE CANNOT SHOW.
  ## ⚠ THE ROW ABOVE PROVES `Poles` -> `pol` ON THE WAY OUT. This one reopens the
  ## dialog on the bench that write just produced -- a row storing the DECK words
  ## `cur` and `pol` -- and asks what the user sees. A mapping applied only on
  ## commit would show `cur` here, which is the window disagreeing with itself:
  ## the same picker that offers `Current` would be sitting on `cur`.
  ## ⚠ AND IT ASKS THE STORED ROW AND THE EMITTED LINE IN THE SAME BREATH, so the
  ## row cannot be satisfied by a tree that made the screen readable by moving
  ## the display word into the state file. That is the failure this ruling's
  ## whole risk is about: the 104 committed `.state` files carry deck words.
  $top.strip.ana invoke
  update
  $top.chana.types.pz invoke
  update
  check "G2a2 a bench storing ngspice's own words opens showing the readable\
 ones, while the row on disk and the emitted line keep the deck's spelling" \
    [list [$top.chana.form.transfer get] [$top.chana.form.mode get] \
          [ase::state_get $g2pzrow2 transfer] [ase::state_get $g2pzrow2 mode] \
          [ase::analysis_line ngspice $g2pzrow2]] \
    [list Current Poles cur pol {pz in 0 out 0 cur pol}]
  $top.chana.btns.cancel invoke
  update
  ## ⚠ AND THE DOOR STILL SHUTS ON A HALF-FILLED ONE. ⚠ THE STATUS LINE IS READ
  ## INSIDE THIS ROW'S OWN `catch`, for the reason G2tf's last row records: the
  ## one change this row exists to catch -- `outp` losing its `required 1`, after
  ## which OK COMMITS AND CLOSES -- would otherwise raise `invalid command name`
  ## and kill the whole file instead of reddening a row.
  $top.strip.ana invoke
  update
  $top.chana.types.pz invoke
  update
  set ::ase::ui::dlg($key,anen) 1
  $top.chana.form.outp delete 0 end
  set g2pz_before [ase::state_get [ase::session_state $key] analyses]
  $top.chana.btns.proceed invoke
  update
  set g2pz_alive [expr {[winfo exists $top.chana] ? 1 : 0}]
  set g2pz_said 0
  if {$g2pz_alive} {
    catch {
      set g2pz_said [expr {[string first {outp} \
        [$top.chana.status cget -text]] >= 0}]
    }
  }
  check "G2pz an enabled pz row with no output node is refused, the dialog\
 survives and the state is untouched" \
    [list $g2pz_alive $g2pz_said \
          [ase::state_get [ase::session_state $key] analyses]] \
    [list 1 1 $g2pz_before]
  ## Leave the bench as the rest of this file found it: no pz row. ⚠ The cancel
  ## is caught for the same reason as the read above.
  catch {$top.chana.btns.cancel invoke}
  update
  set g2pz_st [ase::session_state $key]
  set g2pz_rows {}
  foreach a [ase::state_get $g2pz_st analyses] {
    if {[ase::state_get $a type] ne {pz}} { lappend g2pz_rows $a }
  }
  dict set g2pz_st analyses $g2pz_rows
  ase::session_update $key $g2pz_st
  ase::ui::populate $key
  update
  check "G2pz the fixture is left without a pz row, so the rows below see the\
 bench they were written against" \
    [tv_find $atv type pz] {}

  # G2sens: DC SENSITIVITY CAN BE CHOSEN AT ALL. Stage 5, issue 1428.
  ## ⚠ UNTIL THIS COMMIT `sens` WAS A CELL YOU COULD SELECT AND NOT USE, exactly
  ## as `tf` and `pz` were: `registered 1` with a `role probe` card and nothing
  ## else, so the grid showed it exists, `ase::analysis_renderable` answered 0,
  ## the Enable checkbutton was disabled and the form below it was empty.
  ##
  ## ⚠ AND IT IS THE FIRST FORM WHOSE SECOND FIELD IS OPTIONAL AND **OMITTED
  ## FROM THE LINE** WHEN IT IS BLANK. `tf`'s two fields are both required and
  ## `pz`'s optional four all carry defaults, so this is the first place a widget
  ## row can say that leaving a box empty produces a SHORTER deck line rather
  ## than a padded one -- which is the `whenskipped`-free half of section SE2c,
  ## driven through the real form.
  $top.strip.ana invoke
  update
  $top.chana.types.sens invoke
  update
  check "G2sens selecting sens builds its two fields, leaves none of tran's\
 behind, and leaves Enable live" \
    [list [winfo exists $top.chana.form.out] \
          [winfo exists $top.chana.form.filters] \
          [winfo exists $top.chana.form.step] [winfo exists $top.chana.form.stop] \
          [winfo exists $top.chana.form.uic] \
          [winfo class $top.chana.form.out] \
          [winfo class $top.chana.form.filters] \
          [string tolower [$top.chana.enable cget -state]]] \
    {1 1 0 0 0 Entry Entry normal}
  ## ⚠ THE LABELS ARE THE DECLARED ONES, and they are NEW USER-FACING COPY --
  ## ⚖ R9, recorded as an `owed.sh add rule 1428` debt rather than ratified here.
  ## ⚠ AND `kind filter` RENDERS AS A PLAIN ENTRY TODAY, which is the whole
  ## reason the kind exists rather than a bare `text`: PLAN.md §5a's computed
  ## checkbox tree (`devhelp -csv -type -flags`, no run needed) is Stage 5b's,
  ## and it needs to find this field without guessing which text box it is.
  check "G2sens the two labels are the declared ones" \
    [list [$top.chana.form.lout cget -text] \
          [$top.chana.form.lfilters cget -text]] \
    [list {Output:} {Parameters:}]
  ## ⚠ THE WHOLE ROUND TRIP WITH THE OPTIONAL BOX LEFT BLANK, because a form
  ## that builds and does not commit is the defect this batch is named for, and
  ## because the blank box is the case that must NOT reach the line.
  set ::ase::ui::dlg($key,anen) 1
  $top.chana.form.out delete 0 end
  $top.chana.form.out insert 0 {v(D)}
  $top.chana.form.filters delete 0 end
  $top.chana.btns.proceed invoke
  update
  check_true "G2sens an enabled sens row with only the output is COMMITTED, not refused" \
    [expr {![winfo exists $top.chana]}]
  set g2serow {}
  foreach a [ase::state_get [ase::session_state $key] analyses] {
    if {[ase::state_get $a type] eq {sens}} { set g2serow $a; break }
  }
  set g2seit [tv_find $atv type sens]
  check "G2sens the sens row round-trips storing no key for the blank box, and\
 the Arguments column is the line the deck will carry" \
    [list [ase::state_get $g2serow enabled] [ase::state_get $g2serow out] \
          [lsort [dict keys $g2serow]] \
          [expr {$g2seit ne {} ? [$atv set $g2seit args] : {}}]] \
    [list 1 {v(D)} {enabled out type} {sens v(D) dc}]
  ## ⚠ AND A FILTER THAT **IS** TYPED IS STORED AND **DOES** REACH THE LINE,
  ## between the output and the mode word. Without this the row above is
  ## satisfied by a form whose second box is decoration.
  $top.strip.ana invoke
  update
  $top.chana.types.sens invoke
  update
  set ::ase::ui::dlg($key,anen) 1
  $top.chana.form.filters delete 0 end
  $top.chana.form.filters insert 0 {r*:r m*:vth0}
  $top.chana.btns.proceed invoke
  update
  set g2serow2 {}
  foreach a [ase::state_get [ase::session_state $key] analyses] {
    if {[ase::state_get $a type] eq {sens}} { set g2serow2 $a; break }
  }
  check "G2sens a typed filter list is stored whole and lands between the output\
 and the mode word" \
    [list [ase::state_get $g2serow2 filters] [lsort [dict keys $g2serow2]] \
          [expr {[set i [tv_find $atv type sens]] ne {} ? [$atv set $i args] : {}}]] \
    [list {r*:r m*:vth0} {enabled filters out type} {sens v(D) r*:r m*:vth0 dc}]
  ## ⚠ AND THE DOOR STILL SHUTS ON A ROW WITH NO OUTPUT. ⚠ THE STATUS LINE IS
  ## READ INSIDE THIS ROW'S OWN `catch`, for the reason G2tf's and G2pz's last
  ## rows record: the one change this row exists to catch -- `out` losing its
  ## `required 1`, after which OK COMMITS AND CLOSES -- would otherwise raise
  ## `invalid command name` and kill the whole file instead of reddening a row.
  $top.strip.ana invoke
  update
  $top.chana.types.sens invoke
  update
  set ::ase::ui::dlg($key,anen) 1
  $top.chana.form.out delete 0 end
  set g2se_before [ase::state_get [ase::session_state $key] analyses]
  $top.chana.btns.proceed invoke
  update
  set g2se_alive [expr {[winfo exists $top.chana] ? 1 : 0}]
  set g2se_said 0
  if {$g2se_alive} {
    catch {
      set g2se_said [expr {[string first {out} \
        [$top.chana.status cget -text]] >= 0}]
    }
  }
  check "G2sens an enabled sens row with no output is refused, the dialog\
 survives and the state is untouched" \
    [list $g2se_alive $g2se_said \
          [ase::state_get [ase::session_state $key] analyses]] \
    [list 1 1 $g2se_before]
  ## Leave the bench as the rest of this file found it: no sens row. ⚠ The cancel
  ## is caught for the same reason as the read above.
  catch {$top.chana.btns.cancel invoke}
  update
  set g2se_st [ase::session_state $key]
  set g2se_rows {}
  foreach a [ase::state_get $g2se_st analyses] {
    if {[ase::state_get $a type] ne {sens}} { lappend g2se_rows $a }
  }
  dict set g2se_st analyses $g2se_rows
  ase::session_update $key $g2se_st
  ase::ui::populate $key
  update
  check "G2sens the fixture is left without a sens row, so the rows below see\
 the bench they were written against" \
    [tv_find $atv type sens] {}

  # G2i/G2j/G2k: THE OPTIONS DOOR CLOSES. Issue 1418.
  ## ⚠ THIS EDITOR IS THE DEFECT STAGE 3 IS NAMED FOR. It collected free-text
  ## name/value pairs, round-tripped them through the .state file and showed them
  ## back to the user -- and NOTHING EVER EMITTED THEM. The fix is not to make
  ## free text emit; it is to stop accepting a name nothing can spend.
  $top.strip.ana invoke
  update
  $top.chana.types.tran invoke
  update
  ase::ui::chana_options $key
  update
  check_true "G2i the Options subdialog opens on a type ASE-L can set up" \
    [winfo exists $top.chana.x]
  set g2i_before [ase::state_get [ase::session_state $key] analyses]
  set g2i_rows0 [llength [$top.chana.x.tv children {}]]
  $top.chana.x.row.name delete 0 end
  $top.chana.x.row.name insert 0 zzmysetting
  $top.chana.x.row.value delete 0 end
  $top.chana.x.row.value insert 0 7
  $top.chana.x.row.add invoke
  update
  ## ⚠ REFUSED AT `Add`, NOT AT OK. A pair the user has already watched land in
  ## the list is a pair they believe they have set; taking it away at OK would be
  ## a second surprise on top of the first.
  check "G2i a setting name ASE-L cannot emit never reaches the list, and the\
 refusal names it" \
    [list [expr {[llength [$top.chana.x.tv children {}]] == $g2i_rows0}] \
          [expr {[string first {zzmysetting} \
                  [$top.chana.status cget -text]] >= 0}] \
          [ase::state_get [ase::session_state $key] analyses]] \
    [list 1 1 $g2i_before]

  ## ⚠ AND THE REFUSAL IS NOT BLANKET. A name the type really does declare is
  ## still accepted -- otherwise this row could not tell "closed the door" from
  ## "broke the editor", which is the difference a sabotage has to be able to see.
  $top.chana.x.row.name delete 0 end
  $top.chana.x.row.name insert 0 tmax
  $top.chana.x.row.value delete 0 end
  $top.chana.x.row.value insert 0 0.2n
  $top.chana.x.row.add invoke
  update
  check "G2j a name the type actually declares is still accepted" \
    [expr {[llength [$top.chana.x.tv children {}]] == $g2i_rows0 + 1}] 1
  $top.chana.x.btns.cancel invoke
  update

  ## ⚠ AND AGAIN AT OK, BECAUSE THE EDITOR IS SEEDED FROM THE STORED ROW. A bench
  ## written by an older ASE-L, or edited by hand, arrives carrying keys `Add`
  ## never saw -- and writing them straight back would launder them through a
  ## door that now refuses them at the front.
  set g2k_st [ase::session_state $key]
  set g2k_rows [ase::state_get $g2k_st analyses]
  set g2k_i -1
  for {set i 0} {$i < [llength $g2k_rows]} {incr i} {
    if {[ase::state_get [lindex $g2k_rows $i] type] eq {tran}} { set g2k_i $i; break }
  }
  set g2k_orig [lindex $g2k_rows $g2k_i]
  lset g2k_rows $g2k_i [dict merge $g2k_orig [dict create zzplanted 9]]
  dict set g2k_st analyses $g2k_rows
  ase::session_update $key $g2k_st
  $top.strip.ana invoke
  update
  $top.chana.types.tran invoke
  update
  ase::ui::chana_options $key
  update
  set g2k_before [ase::state_get [ase::session_state $key] analyses]
  $top.chana.x.btns.proceed invoke
  update
  check "G2k a hand-edited bench carrying a setting ASE-L cannot emit is refused\
 at OK rather than written back, and the bench is untouched" \
    [list [ase::state_get [ase::session_state $key] analyses] \
          [expr {[string first {zzplanted} \
                  [$top.chana.status cget -text]] >= 0}]] \
    [list $g2k_before 1]
  catch {$top.chana.x.btns.cancel invoke}
  update
  catch {$top.chana.btns.cancel invoke}
  update
  ## Put the planted key back out of the bench for the rows below.
  set g2k_st2 [ase::session_state $key]
  set g2k_rows2 [ase::state_get $g2k_st2 analyses]
  lset g2k_rows2 $g2k_i $g2k_orig
  dict set g2k_st2 analyses $g2k_rows2
  ase::session_update $key $g2k_st2
  ase::ui::populate $key
  update

  # G2e: THE AC SWEEP MODE IS A CONTROL, AND PICKING ONE RELABELS ITS NEIGHBOUR.
  ## ⚠ THIS IS ngspice's SHARPEST AC TRAP AND THE FORM USED TO SAY `Points:` FOR
  ## BOTH SIDES OF IT: `dec 10` is ten points PER DECADE, `lin 10` is ten points
  ## IN TOTAL, and `lin 2` yields one point.
  ## ⚠ THE LABEL NO LONGER CARRIES THAT ARITHMETIC. ⚖ R9 ruling A1 part 1
  ## (2026-09-15) took it out: `ac`/`sp` read `Number of points (2 gives ONE
  ## point)` while `noise` read `(1 gives ONE point)` -- the same caption with
  ## different numbers in one dialog, both measured-correct, which reads as a
  ## typo rather than as two counts. The relabel still HAPPENS, and it is still
  ## what this row is about; what it says is now a name, and the count is said
  ## by the caution beneath the form. Row G2e2 is the pin.
  $top.strip.ana invoke
  update
  $top.chana.types.ac invoke
  update
  check "G2e the sweep mode is a readonly combobox offering exactly ngspice's three" \
    [list [winfo class $top.chana.form.sweep] \
          [$top.chana.form.sweep cget -values] \
          [$top.chana.form.sweep cget -state]] {TCombobox {dec oct lin} readonly}
  ## ⚠ A BENCH THAT STORES NO SWEEP KEY STILL SHOWS `dec`, because the deck it
  ## renders CARRIES `dec`. A blank picker beside a deck line reading `dec` is
  ## the window disagreeing with the file.
  check "G2e a bench with no stored sweep key shows the default the deck emits" \
    [$top.chana.form.sweep get] dec
  check "G2e and the neighbour is labelled per decade to match it" \
    [$top.chana.form.lpoints cget -text] {Points per decade:}
  $top.chana.form.sweep set lin
  event generate $top.chana.form.sweep <<ComboboxSelected>>
  update
  check "G2e picking a linear sweep relabels the neighbour away from the\
 per-decade rate, which is the defect this control exists to delete" \
    [$top.chana.form.lpoints cget -text] {Number of points:}
  $top.chana.form.sweep set oct
  event generate $top.chana.form.sweep <<ComboboxSelected>>
  update
  check "G2e and per octave for oct" \
    [$top.chana.form.lpoints cget -text] {Points per octave:}

  ## G2e2: ⚖ R9 A1 part 1 -- A FIELD LABEL CARRIES NO ARITHMETIC, ON ANY FORM.
  ## ⚠ THIS ROW EXISTS BECAUSE THE RULING IS EASY TO UNDO BY ACCIDENT. Putting a
  ## count back into a label reads like helpfulness, and the four types drifted
  ## apart exactly that way once already -- three spellings of one caption, of
  ## which two were arithmetic and one was not. The last two terms are the
  ## non-vacuity half: no digit and no shouted word in any of the four, so a
  ## label that regained `(2 gives ONE point)` reds here even if someone also
  ## edited the golden above to match it.
  check "G2e2 every sweep-bearing type spells the linear points label the same,\
 and none of the four carries a number or a shouted word" \
    [list [ase::ui::form_label ngspice ac    points lin] \
          [ase::ui::form_label ngspice noise points lin] \
          [ase::ui::form_label ngspice disto points lin] \
          [ase::ui::form_label ngspice sp    points lin] \
          [regexp {[0-9]} [ase::ui::form_label ngspice ac points lin]] \
          [regexp {[A-Z]{2,}} [ase::ui::form_label ngspice noise points lin]]] \
    {{Number of points:} {Number of points:} {Number of points:} {Number of points:} 0 0}
  $top.chana.btns.cancel invoke
  update

  # G2g: THE WRITE-BACK RULE, WHICH IS A BYTE-IDENTITY RULE.
  ## ⚠ A COMBOBOX ANSWERS `dec` WHERE A BENCH STORES NOTHING, and `dec` is
  ## already what the emitter resolves from the field's own `default`. A door
  ## that stored it would put a `sweep` key on disk that NONE of the 104
  ## committed benches carries, changing no deck line whatsoever -- and the round
  ## trip this batch is measured against would break the first time a user opened
  ## the dialog and pressed OK. The same shape sank `uic 0` in this commit.
  $top.strip.ana invoke
  update
  $top.chana.types.ac invoke
  update
  set ::ase::ui::dlg($key,anen) 1
  foreach {fld val} {points 20 start 10 stop 1g} {
    $top.chana.form.$fld delete 0 end
    $top.chana.form.$fld insert 0 $val
  }
  $top.chana.form.sweep set dec
  event generate $top.chana.form.sweep <<ComboboxSelected>>
  $top.chana.btns.proceed invoke
  update
  set g2gac {}
  foreach a [ase::state_get [ase::session_state $key] analyses] {
    if {[ase::state_get $a type] eq {ac}} { set g2gac $a; break }
  }
  check "G2g picking the mode the deck already emits writes NO key, so a bench a\
 user merely opened is byte-identical to one they never touched" \
    [list [lsort [dict keys $g2gac]] \
          [expr {[set i [tv_find $atv type ac]] ne {} ? [$atv set $i args] : {}}]] \
    [list {enabled points start stop type} {ac dec 20 10 1g}]

  ## ⚠ AND A NON-DEFAULT PICK MUST STILL BE STORED, or the rule above would be
  ## indistinguishable from a door that silently discards the control -- which is
  ## the defect this whole stage exists to delete.
  $top.strip.ana invoke
  update
  $top.chana.types.ac invoke
  update
  set ::ase::ui::dlg($key,anen) 1
  $top.chana.form.sweep set lin
  event generate $top.chana.form.sweep <<ComboboxSelected>>
  $top.chana.btns.proceed invoke
  update
  set g2gac2 {}
  foreach a [ase::state_get [ase::session_state $key] analyses] {
    if {[ase::state_get $a type] eq {ac}} { set g2gac2 $a; break }
  }
  check "G2g a mode that is NOT the default is stored, and reaches the deck line" \
    [list [ase::state_get $g2gac2 sweep] \
          [expr {[set i [tv_find $atv type ac]] ne {} ? [$atv set $i args] : {}}]] \
    [list lin {ac lin 20 10 1g}]

  ## ⚠ AND THE FORM MUST OPEN AGREEING WITH IT. The relabel has to run at BUILD
  ## time and not only on a pick: this bench now stores `lin`, so a form that
  ## relabelled only on a <<ComboboxSelected>> would open reading `Points per
  ## decade` over a bench whose deck line says `lin` -- the window disagreeing
  ## with the file, which is the one thing this batch forbids.
  $top.strip.ana invoke
  update
  $top.chana.types.ac invoke
  update
  check "G2g reopening a bench that stores a non-default mode shows that mode AND\
 the label that goes with it, without anyone touching the picker" \
    [list [$top.chana.form.sweep get] [$top.chana.form.lpoints cget -text]] \
    {lin {Number of points:}}
  $top.chana.btns.cancel invoke
  update

  # G2d: THE GROUP DOOR, AND WHERE ITS REFUSAL IS VISIBLE.
  ## A second sweep variable with no start, stop or step is not a smaller sweep
  ## -- it is a parse error ngspice reports from the middle of a run, after the
  ## deck is written and the process started. No per-field `required` can say
  ## this: each of the four is optional alone, and 68 committed benches have none.
  $top.strip.ana invoke
  update
  $top.chana.types.dc invoke
  update
  if {![winfo exists $top.chana.form.source2]} {
    $top.chana.form.advbtn invoke
    update
  }
  set ::ase::ui::dlg($key,anen) 1
  foreach {fld val} {source V2 start 0 stop 1.8 step 0.01 source2 temp} {
    $top.chana.form.$fld delete 0 end
    $top.chana.form.$fld insert 0 $val
  }
  foreach fld {start2 stop2 step2} { $top.chana.form.$fld delete 0 end }
  set g2d_before [ase::state_get [ase::session_state $key] analyses]
  $top.chana.btns.proceed invoke
  update
  check_true "G2d an enabled dc naming a second sweep variable with no start,\
 stop or step is refused and the dialog survives" \
    [winfo exists $top.chana]
  check "G2d and the bench is untouched" \
    [ase::state_get [ase::session_state $key] analyses] $g2d_before
  ## ⚠ AND THE SENTENCE IS IN THE DIALOG, NOT ONLY IN THE ACTION LOG. Before
  ## issue 1417 a refusal went only to `ase::echo`, which lands in ANOTHER
  ## WINDOW -- so from the user's seat OK "did nothing".
  check "G2d the refusal is written where the user is looking, and names the\
 GROUP rather than picking one of its three empty fields" \
    [list [expr {[$top.chana.status cget -text] ne {}}] \
          [expr {[string first {second sweep} \
                  [$top.chana.status cget -text]] >= 0}] \
          [expr {[string first {start2} [$top.chana.status cget -text]] >= 0}]] \
    {1 1 0}
  ## ⚠ THE REFUSAL MUST NOT REBUILD THE FORM. chana_show destroys and recreates
  ## every widget, so a door that reopened the disclosure to point at a hidden
  ## field would DISCARD everything the user had typed in order to show them
  ## what was wrong with it. This row proves the four values survived.
  check "G2d the refusal leaves every value the user typed in place" \
    [list [$top.chana.form.source get] [$top.chana.form.start get] \
          [$top.chana.form.stop get] [$top.chana.form.step get] \
          [$top.chana.form.source2 get]] {V2 0 1.8 0.01 temp}
  foreach {fld val} {start2 -40 stop2 60 step2 50} {
    $top.chana.form.$fld delete 0 end
    $top.chana.form.$fld insert 0 $val
  }
  $top.chana.btns.proceed invoke
  update
  check "G2d completing the nest commits it, and the Arguments column carries\
 all eight words" \
    [list [expr {![winfo exists $top.chana]}] \
          [expr {[set i [tv_find $atv type dc]] ne {} ? [$atv set $i args] : {}}]] \
    {1 {dc V2 0 1.8 0.01 temp -40 60 50}}

  # G2f: A MISSING REQUIRED VALUE PUTS THE CURSOR ON THE FIELD THAT IS MISSING.
  ## ⚠ THERE WAS NO `focus` CALL ANYWHERE IN THIS DIALOG before issue 1417 --
  ## measured, across choose_analyses and every proc it calls. A refusal that
  ## names a field and leaves the cursor where it was makes the user hunt for
  ## the field their own error message just named.
  $top.strip.ana invoke
  update
  $top.chana.types.dc invoke
  update
  set ::ase::ui::dlg($key,anen) 1
  $top.chana.form.step delete 0 end
  $top.chana.btns.proceed invoke
  update
  check "G2f a missing required value is refused, said in the dialog, and the\
 cursor lands on the field that is missing" \
    [list [winfo exists $top.chana] \
          [expr {[string first {step} [$top.chana.status cget -text]] >= 0}] \
          [focus]] \
    [list 1 1 $top.chana.form.step]
  $top.chana.btns.cancel invoke
  update
  ## Put the bench back the way G2 left it, so the rows below keep the state
  ## they were written against.
  set g2st [ase::session_state $key]
  dict set g2st analyses $g2c_before
  ase::session_update $key $g2st
  ase::ui::populate $key
  update

  # G3: Setup > Design — View list filtered to SCHEMATIC views (nfet_clean
  # also has ngspice_state* views: the filter proof), round trip via OK
  $top.mb.setup invoke "Design\u2026"
  update
  check_true "G3 Setup Design opens" [winfo exists $top.design]
  check "G3 prefilled Library" [$top.design.lib get] aselib
  check "G3 prefilled Cell" [$top.design.cell get] nfet_clean
  check "G3 view list filtered to schematic views" \
    [$top.design.view cget -values] schematic
  $top.design.btns.proceed invoke
  update
  check_true "G3 Setup Design closed on OK" [expr {![winfo exists $top.design]}]
  set d3 [ase::state_get [ase::session_state $key] design]
  check "G3 design round-trips" \
    [list [dict get $d3 lib] [dict get $d3 cell] [dict get $d3 view]] \
    {aselib nfet_clean schematic}
  check_true "G3 title still shows the design cell" \
    [string match {Analog Sim Environment nfet_clean*} [wm title $top]]

  # G4: Setup > Model Files — list dialog rows from the state, row-editor
  # add, dialog-local ctx delete (D1)
  $top.mb.setup invoke "Model Files\u2026"
  update
  check_true "G4 Model Files dialog opens" [winfo exists $top.models]
  set mtv $top.models.tv
  check "G4 Model Files lists the state models" \
    [list [llength [$mtv children {}]] [$mtv set 0 file] [$mtv set 0 section]] \
    [list 1 $models tt]
  $top.models.ctx invoke "Add\u2026"
  update
  check_true "G4 Add opens the row editor" [winfo exists $top.modrow]
  $top.modrow.file insert 0 /tmp/extra.lib.spice
  $top.modrow.section insert 0 tt2
  send_return $top.modrow.section {![winfo exists $top.modrow]}
  check_true "G4 add round-trips" [string match \
    {*file /tmp/extra.lib.spice section tt2*} \
    [ase::state_get [ase::session_state $key] models]]
  check "G4 dialog list grew" [llength [$mtv children {}]] 2
  $mtv selection set 1
  update
  $top.models.ctx invoke Delete
  update
  check "G4 delete removes the row" \
    [llength [ase::state_get [ase::session_state $key] models]] 1
  $top.models.btns.close invoke
  update

  # G5: Outputs > Save All — alli toggle writes save_all_i, the outputs
  # pane's Save Options column reacts, the deck gains the blanket line, the
  # Levels field is the inert disabled v1 placeholder (D11)
  $top.mb.outputs invoke "Save All\u2026"
  update
  check_true "G5 Save All dialog opens" [winfo exists $top.saveall]
  check "G5 levels entry disabled" [$top.saveall.levels cget -state] disabled
  $top.saveall.alli invoke
  $top.saveall.btns.proceed invoke
  update
  check "G5 Save All writes save_all_i" \
    [ase::state_get [ase::session_state $key] save_all_i] 1
  set otv $top.body.outs.tv
  set idit [tv_find $otv name id]
  check "G5 Save Options column reacts" \
    [expr {$idit ne {} ? [$otv set $idit saveopts] : {}}] alli
  set render [ase::backend_hook ngspice render_deck]
  set st5 [ase::session_state $key]
  dict set st5 options {}   ;# drop the explicit row — the blanket alone
  set deck5 [$render $st5 "* stub circuit\n.end\n"]
  check_true "G5 deck gains .options savecurrents" \
    [regexp -line {^\.options savecurrents$} $deck5]

  # G5b/G5c: Outputs > Save All gains the THIRD blanket — `save_op_params`,
  # the gate that lets ase::netlist capture op_annot::save_cards and
  # render_deck carry it into the deck (plan step S4 / issue 0617).
  # ⚠ THE ROW NUMBERS IN save_all_dialog ARE HARDCODED: opparams takes grid row
  # 2, so `dialog_row $w 2 Levels: levels` must move to 3 and
  # `dialog_buttons $w 3` to 4. The widget PATHS `.allv` `.alli` `.levels`
  # `.btns.proceed` are what G5 and GE10 drive, so they must survive verbatim.
  $top.mb.outputs invoke "Save All\u2026"
  update
  check_true "G5b Save All dialog reopens" [winfo exists $top.saveall]
  check "G5b the opparams checkbutton exists" \
    [winfo exists $top.saveall.opparams] 1
  check "G5b allv/alli/levels/proceed paths survive the row shift" \
    [list [winfo exists $top.saveall.allv] [winfo exists $top.saveall.alli] \
          [winfo exists $top.saveall.levels] \
          [winfo exists $top.saveall.btns.proceed]] {1 1 1 1}
  check "G5b Levels is still the inert disabled v1 field" \
    [$top.saveall.levels cget -state] disabled
  check "G5b opparams sits between alli and Levels in the grid" \
    [list [ase_grid_row $top.saveall.alli] [ase_grid_row $top.saveall.opparams] \
          [ase_grid_row $top.saveall.levels] [ase_grid_row $top.saveall.btns]] \
    {1 2 3 4}

  # G5c: the checkbox actually reaches the state, both ways round.
  # ⚠ 0927 FLIPPED THE POLARITY (2026-08-29, the user's call). The box now
  # starts TICKED on a state that never mentions the key -- which is every
  # existing test bench -- and the empty value is what keeps the key out of
  # ase::state_serialize and the 104 committed .state files byte-identical
  # (F3/G3/R4/V4/R2). So: ON writes `{}` and VANISHES from the file, OFF writes
  # a literal `0` and is the only thing a state file ever says about this key.
  # The sequence below is untick -> OK -> reopen -> retick -> OK, i.e. the
  # mirror image of what this row used to drive.
  check "G5c 0927 opparams starts TICKED (the gate defaults ON)" \
    [expr {[info exists ::ase::ui::dlg($key,opparams)]
             ? $::ase::ui::dlg($key,opparams) : {<no record>}}] 1
  catch {$top.saveall.opparams invoke}
  $top.saveall.btns.proceed invoke
  update
  check "G5c 0927 UN-ticking opparams writes save_op_params 0" \
    [ase::state_get [ase::session_state $key] save_op_params] 0
  check_true "G5c 0927 an off gate IS serialized (off is what costs a key)" \
    [expr {[string first "save_op_params 0" \
       [ase::state_serialize [ase::session_state $key]]] >= 0}]
  $top.mb.outputs invoke "Save All\u2026"
  update
  check "G5c reopening preloads the UN-ticked state" \
    [expr {[info exists ::ase::ui::dlg($key,opparams)]
             ? $::ase::ui::dlg($key,opparams) : {<no record>}}] 0
  catch {$top.saveall.opparams invoke}
  $top.saveall.btns.proceed invoke
  update
  check "G5c 0927 re-ticking writes {} back, never 1" \
    [ase::state_get [ase::session_state $key] save_op_params <absent>] {}
  check "G5c 0927 an ON gate is OMITTED from the serialized state again" \
    [expr {[string first "save_op_params" \
       [ase::state_serialize [ase::session_state $key]]] >= 0}] 0

  # G6: Simulation > Options — name/value row add + delete (immediate
  # commit, D15)
  $top.mb.sim invoke "Options\u2026"
  update
  check_true "G6 Simulation Options dialog opens" [winfo exists $top.simopt]
  $top.simopt.ctx invoke "Add\u2026"
  update
  check_true "G6 Add opens the option row editor" [winfo exists $top.optrow]
  $top.optrow.name insert 0 reltol
  $top.optrow.value insert 0 1e-4
  send_return $top.optrow.value {![winfo exists $top.optrow]}
  check_true "G6 Sim Options round-trips a name/value row" [string match \
    {*name reltol value 1e-4*} \
    [ase::state_get [ase::session_state $key] options]]
  set optv $top.simopt.tv
  set ridx [expr {[llength [ase::state_get [ase::session_state $key] options]] - 1}]
  $optv selection set $ridx
  update
  $top.simopt.ctx invoke Delete
  update
  check_true "G6 delete removes the option row" \
    [expr {![string match {*reltol*} \
      [ase::state_get [ase::session_state $key] options]]}]
  $top.simopt.btns.close invoke
  update

  # G7: Session > Save State — always Save-As, prefilled with the session's
  # own L/C/V; same-target OK is the plain save (clears dirty); an edited
  # View creates the new view (item-02 creation path)
  $top.mb.session invoke {Save State}
  update
  check_true "G7 Save-As dialog opens" [winfo exists $top.saveas]
  check "G7 Save-As dialog prefilled with current lcv" \
    [list [$top.saveas.lib get] [$top.saveas.cell get] [$top.saveas.view get]] \
    {aselib nfet_clean ngspice_state1}
  check "G7 session dirty before the save" [ase::session_dirty $key] 1
  $top.saveas.btns.proceed invoke
  update
  check_true "G7 Save-As closed after the save" \
    [expr {![winfo exists $top.saveas]}]
  check "G7 same-target OK saves clean" [ase::session_dirty $key] 0
  $top.mb.session invoke {Save State}
  update
  $top.saveas.view delete 0 end
  $top.saveas.view insert 0 ngspice_state3
  $top.saveas.btns.proceed invoke
  update
  set p3 [xschem cellview_path aselib/nfet_clean ngspice_state3]
  check_true "G7 Save-As creates a new view dir" [expr {$p3 ne {}}]
  check_true "G7 new view listed in cell_views" \
    [expr {[lsearch -exact [xschem cell_views aselib nfet_clean] ngspice_state3] >= 0}]

  # G8: read-only same-target -> the confirm gate (D7/D8): proceed on the
  # Save-As first raises $top.confirm WITHOUT writing; the confirm's OK
  # writes + cleans
  set st8 [ase::session_state $key]
  dict set st8 variables {{name Vgs value 1.44} {name Vds value 1.0}}
  ase::session_update $key $st8
  check "G8 session dirty before the confirm path" [ase::session_dirty $key] 1
  ase::session_setattr $key readonly 1
  $top.mb.session invoke {Save State}
  update
  $top.saveas.btns.proceed invoke
  update
  check_true "G8 read-only same-target raises the confirm" \
    [winfo exists $top.confirm]
  set f [::open $spath r]; set sdata [read $f]; close $f
  check_true "G8 file not yet written while the confirm is up" \
    [expr {![string match {*Vgs value 1.44*} $sdata]}]
  $top.confirm.btns.proceed invoke
  update
  set f [::open $spath r]; set sdata [read $f]; close $f
  check_true "G8 confirm proceed writes the file" \
    [string match {*Vgs value 1.44*} $sdata]
  check "G8 session clean after the confirmed save" [ase::session_dirty $key] 0
  ase::session_setattr $key readonly 0

  # G8b: THE ROW THE SILENT-CLOBBER DEFECT WOULD HAVE FAILED (S-2).
  # Save State is always a Save-As, so OK can land on a file that is already
  # somebody's state. Until 2026-09-09 it just wrote: measured on the live
  # binary, `save_as_needs_confirm` answered 0 for an existing sibling view and
  # there was no second door, so an existing state was destroyed with no
  # warning. Now `save_as_overwrites_other` answers 1 and OK raises the confirm
  # FIRST. Driven through the REAL menu entry and the REAL form, not the worker:
  # the defect lived in the OK handler, and a worker-level row would have been
  # green through all of it.
  #
  # A DEDICATED victim view, seeded here rather than reusing `ngspice_stateB`:
  # stateB is the G9 import fixture and this row's entire subject is a file that
  # must NOT change, so a regression here must not also redden G9 for a reason
  # that is not G9's. `library_new_view` is the same real creation backend the
  # fixture uses; its content is then made distinct from this session's, so a
  # write of ANY kind moves the bytes.
  library_new_view aselib nfet_clean ngspice_stateV ngspice_state1
  set vpath [file normalize [xschem cellview_path aselib/nfet_clean ngspice_stateV]]
  # THE ANTI-VACUITY GUARD, and it is not decoration. The H2 row renamed above
  # spent months called "a different target needs no confirm" while pointing at
  # `ngspice_state9`, a view this fixture never creates -- so it was measuring
  # the unresolvable-target guard, and it would have stayed green through the
  # entire defect. A row about overwriting an existing state is worth nothing
  # unless the state exists, is not this session's own, and holds something this
  # session would not write.
  check_true "G8b the victim state exists and is not this session's own file" [expr {
    $vpath ne {} && [file exists $vpath] &&
    $vpath ne [file normalize [ase::session_path $key]]}]
  if {[file exists $vpath]} {
    set stV [ase::state_load $vpath]
    dict set stV variables {{name Vgs value 0.11} {name Vds value 0.22}}
    ase::state_save $vpath $stV
  }
  # every read of the victim goes through this, so a red row above degrades the
  # rows below to reds of their own instead of aborting the GUI block
  proc g8b_read {} {
    global vpath
    set c {}
    catch {set fh [::open $vpath r]; set c [read $fh]; close $fh}
    return $c
  }
  set vbefore [g8b_read]
  check_true "G8b ...and it holds something this session would NOT write" [expr {
    $vbefore ne {} && ![string match {*Vgs value 1.44*} $vbefore]}]
  $top.mb.session invoke {Save State}
  update
  # the form re-opens on the SESSION's own identity, never on whatever was
  # typed into it last -- so the overwrite below is a thing the user has to type
  # on purpose, and this row is what says the retype is real rather than a
  # leftover
  check "G8b the re-opened Save-As is prefilled with the session's own l/c/v" \
    [list [$top.saveas.lib get] [$top.saveas.cell get] [$top.saveas.view get]] \
    {aselib nfet_clean ngspice_state1}
  $top.saveas.view delete 0 end
  $top.saveas.view insert 0 ngspice_stateV
  $top.saveas.btns.proceed invoke
  update
  check_true "G8b OK onto a DIFFERENT EXISTING state raises the confirm" \
    [winfo exists $top.confirm]
  # One title for both arms, and the sentence READ FROM THE MINT rather than
  # retyped here -- a drift between the two would be issue 0661 all over again.
  # Both reads are caught into {}: when the confirm is missing (which is exactly
  # what the pre-2026-09-09 window did) these rows must go red one by one, not
  # abort the whole GUI block into a single UNEXPECTED ERROR that says nothing
  # about which promise broke.
  set g8b_title {}; catch {set g8b_title [wm title $top.confirm]}
  set g8b_msg   {}; catch {set g8b_msg [$top.confirm.msg cget -text]}
  check "G8b the confirm is titled Overwrite State" $g8b_title {Overwrite State}
  check "G8b the confirm names the state it is about to destroy" $g8b_msg \
    [ase::ui::lbl_overwrite_state aselib nfet_clean ngspice_stateV]
  check "G8b the target is byte-identical while the confirm is up" [g8b_read] $vbefore
  # Cancel: nothing written, and the Save-As form STAYS UP so the user can
  # retype the view they meant (that is also what keeps save_state_modal's
  # tkwait from returning a false completion on the quit path)
  catch {$top.confirm.btns.cancel invoke}
  update
  check_true "G8b Cancel dismisses the confirm" \
    [expr {![winfo exists $top.confirm]}]
  check "G8b Cancel wrote NOTHING: the target is still byte-identical" [g8b_read] $vbefore
  check_true "G8b Cancel leaves the Save-As form up to retype in" \
    [winfo exists $top.saveas]
  # CLEANUP, caught: a red row above can leave the form already gone, and an
  # error on the teardown would abort the whole GUI block into one UNEXPECTED
  # ERROR -- which is how a precise red turns into an unreadable run.
  catch {$top.saveas.btns.cancel invoke}
  update
  check_true "G8b the abandoned Save-As is gone and the session is untouched" [expr {
    ![winfo exists $top.saveas] && [ase::session_dirty $key] == 0}]

  # --- G8c: THE GATE MUST BE REAL FOR THE KEYBOARD TOO -----------------------
  # Both rows below are regressions found by this item's own adversary AFTER
  # the confirm shipped, i.e. the gate existed and was still bypassable.
  #
  # G8c-1 <Return>. `save_state_dialog` binds <Return> on all three fields, so
  # "type the view name, press Return" is the sanctioned submit; `ase::ui::confirm`
  # then focuses OK and binds <Return> to confirm_ok. Composed, the SAME key
  # raises the popup and fires it. `ase::ui::confirm_safe_default` puts focus on
  # Cancel and points <Return> at the dismissal instead. Escape already did.
  proc g8c_raise {} {
    uplevel 1 {
      catch {destroy $top.confirm}
      $top.mb.session invoke {Save State}
      for {set i 0} {$i < 100} {incr i} {
        update ; if {[winfo exists $top.saveas]} break ; settle 20 }
      $top.saveas.view delete 0 end
      $top.saveas.view insert 0 ngspice_stateV
      $top.saveas.btns.proceed invoke
      for {set i 0} {$i < 100} {incr i} {
        update ; if {[winfo exists $top.confirm]} break ; settle 20 }
    }
  }
  g8c_raise
  check_true "G8c the confirm is up again" [winfo exists $top.confirm]
  check "G8c focus rests on Cancel, not on the destructive button"     [focus -displayof $top.confirm] $top.confirm.btns.cancel
  check "G8c <Return> on the confirm is the DISMISSAL, not the write"     [bind $top.confirm <Return>] [list destroy $top.confirm]
  event generate $top.confirm <Return>
  update
  check_true "G8c ...and pressing it dismissed rather than wrote"     [expr {![winfo exists $top.confirm]}]
  check "G8c Return wrote NOTHING: the target is still byte-identical" [g8b_read] $vbefore

  # G8c-2 the ORPHAN. Escape on the Save-As form is the documented item-10
  # dismissal. It used to destroy the form and leave the confirm alive, so a
  # user who backed out of the dialog was left with a live destructive button
  # aimed at their file. `ase::ui::confirm_owned_by` binds the form's <Destroy>.
  g8c_raise
  check_true "G8c the confirm is up for the orphan check" [winfo exists $top.confirm]
  # focus -force first: the confirm holds the keyboard, and a generated Key
  # event is routed by focus. Without it the ESC lands nowhere and the row
  # would pass for the wrong reason (no orphan because no dismissal).
  focus -force $top.saveas
  update
  event generate $top.saveas <Key-Escape>
  update
  check_true "G8c ESC dismissed the form" [expr {![winfo exists $top.saveas]}]
  check_true "G8c ESC on the FORM takes the confirm with it (no orphan)" \
    [expr {![winfo exists $top.confirm]}]
  check "G8c the orphan path wrote NOTHING either" [g8b_read] $vbefore

  # G8c-3 re-opening the form must not leave a confirm naming the OLD target.
  # `dialog_frame` destroys the previous form, which fires the same <Destroy>.
  g8c_raise
  check_true "G8c the confirm is up for the re-open check" [winfo exists $top.confirm]
  $top.mb.session invoke {Save State}
  for {set i 0} {$i < 100} {incr i} {
    update ; if {[winfo exists $top.saveas]} break ; settle 20 }
  check_true "G8c re-opening the form drops the stale confirm"     [expr {![winfo exists $top.confirm]}]
  catch {$top.saveas.btns.cancel invoke}
  update
  check "G8c the whole G8c block wrote NOTHING to the victim" [g8b_read] $vbefore

  # G9: Session > Load State — browser filtered to simulation-state views,
  # import + dirty, and the dirty-prompt-first gate
  $top.mb.session invoke {Load State}
  update
  check_true "G9 Load State browser opens" [winfo exists $top.loadst]
  # G9a: the browser opens ALREADY on this session's own cell, so the only
  # pick left is the state View. Library + Cell selected, View column filled
  # and filtered, View deliberately UNselected (a default pick would be one
  # OK press from discarding the session for a state nobody chose).
  check "G9a defaults to the session Library" \
    [ase::ui::lb_sel $top.loadst.pw.lib.lb] aselib
  check "G9a defaults to the session Cell" \
    [ase::ui::lb_sel $top.loadst.pw.cell.lb] nfet_clean
  check_true "G9a View column already filled and filtered" [expr {
    [lsearch -exact [$top.loadst.pw.view.lb get 0 end] ngspice_state1] >= 0 &&
    [lsearch -exact [$top.loadst.pw.view.lb get 0 end] schematic] < 0}]
  check "G9a no View preselected" [ase::ui::lb_sel $top.loadst.pw.view.lb] {}
  check "G9a status names the defaulted cell" [$top.loadst.status cget -text] \
    {aselib/nfet_clean — choose a state View}
  # a library the browser does not list must fall back rather than
  # half-select or error, and it must not disturb what is already chosen
  check "G9a unknown library falls back" \
    [ase::ui::lb_select_value $top.loadst.pw.lib.lb no_such_lib] 0
  check "G9a a missed library leaves the selection alone" \
    [ase::ui::lb_sel $top.loadst.pw.lib.lb] aselib
  # G9b: picking a different Library must clear the status that described the
  # OLD cell -- only reachable on the first click now the browser opens
  # defaulted, so the defaulting is what makes this stale text visible
  $top.loadst.pw.lib.lb selection clear 0 end
  ase::ui::loadst_on_lib $key
  check "G9b library change resets the stale status" \
    [$top.loadst.status cget -text] \
    {pick a Library / Cell / simulation-state View}
  check "G9b library change empties the Cell column" \
    [$top.loadst.pw.cell.lb size] 0
  # G9c: an unknown CELL degrades one column only -- library stays chosen and
  # its Cell list stays filled (more useful than clearing it)
  ase::ui::lb_select_value $top.loadst.pw.lib.lb aselib
  ase::ui::loadst_on_lib $key
  check "G9c unknown cell falls back" \
    [ase::ui::lb_select_value $top.loadst.pw.cell.lb no_such_cell] 0
  check "G9c library stays chosen after a cell miss" \
    [ase::ui::lb_sel $top.loadst.pw.lib.lb] aselib
  check_true "G9c cell column stays filled after a cell miss" \
    [expr {[$top.loadst.pw.cell.lb size] > 0}]
  # G9d: bare OK with Library+Cell chosen and no View must name the MISSING
  # View, not tell the user to pick a Library they already picked
  ase::ui::lb_select_value $top.loadst.pw.cell.lb nfet_clean
  ase::ui::loadst_on_cell $key
  $top.loadst.b.ok invoke
  update
  check_true "G9d bare OK keeps the browser open" [winfo exists $top.loadst]
  check "G9d bare OK names the missing View" \
    [$top.loadst.status cget -text] {aselib/nfet_clean — choose a state View}
  set llb $top.loadst.pw.lib.lb
  set i9 [lsearch -exact [$llb get 0 end] aselib]
  $llb selection clear 0 end; $llb selection set $i9
  event generate $llb <<ListboxSelect>>
  update
  set clb $top.loadst.pw.cell.lb
  set i9 [lsearch -exact [$clb get 0 end] nfet_clean]
  $clb selection clear 0 end; $clb selection set $i9
  event generate $clb <<ListboxSelect>>
  update
  set vlb $top.loadst.pw.view.lb
  set views9 [$vlb get 0 end]
  check_true "G9 Load State browser filtered to state views" [expr {
    [lsearch -exact $views9 ngspice_state1] >= 0 &&
    [lsearch -exact $views9 ngspice_stateB] >= 0 &&
    [lsearch -exact $views9 schematic] < 0}]
  set i9 [lsearch -exact $views9 ngspice_stateB]
  $vlb selection clear 0 end; $vlb selection set $i9
  update
  $top.loadst.b.ok invoke
  update
  check "G9 load imports the picked state" \
    [ase::state_get [ase::session_state $key] variables] \
    {{name Vgs value 0.9} {name Vds value 1.0}}
  check "G9 session dirty after the import" [ase::session_dirty $key] 1
  set vt $top.body.vars.tv
  set vgsit [tv_find $vt name Vgs]
  # item 09: the pane renders the imported 0.9 in engineering notation
  # (900m); the raw-state import check above keeps asserting 0.9
  check "G9 panes repopulated with the imported value" \
    [expr {$vgsit ne {} ? [$vt set $vgsit value] : {}}] 900m
  # dirty session -> the discard prompt comes FIRST
  $top.mb.session invoke {Load State}
  update
  set llb $top.loadst.pw.lib.lb
  set i9 [lsearch -exact [$llb get 0 end] aselib]
  $llb selection clear 0 end; $llb selection set $i9
  event generate $llb <<ListboxSelect>>
  update
  set clb $top.loadst.pw.cell.lb
  set i9 [lsearch -exact [$clb get 0 end] nfet_clean]
  $clb selection clear 0 end; $clb selection set $i9
  event generate $clb <<ListboxSelect>>
  update
  set vlb $top.loadst.pw.view.lb
  set i9 [lsearch -exact [$vlb get 0 end] ngspice_stateB]
  $vlb selection clear 0 end; $vlb selection set $i9
  update
  $top.loadst.b.ok invoke
  update
  check_true "G9 dirty prompt appears first" [winfo exists $top.confirm]
  $top.confirm.btns.proceed invoke
  update
  check "G9 confirmed load leaves the imported content" \
    [ase::state_get [ase::session_state $key] variables] \
    {{name Vgs value 0.9} {name Vds value 1.0}}

  # G10: the --> strip button = the Add Output dialog (D3)
  $top.strip.out invoke
  update
  check_true "G10 --> strip opens the Add Output dialog" [expr {
    [winfo exists $top.edout] && [wm title $top.edout] eq {Add Output}}]
  $top.edout.btns.cancel invoke
  update

  # G11: no item-07 todo stubs remain on any rewired entry (the item-08
  # Outputs Select-On-Design entries are excluded by construction)
  set stub_hits {}
  foreach {m e} [list $top.mb.session {Load State} \
                      $top.mb.session {Save State} \
                      $top.mb.setup "Design\u2026" \
                      $top.mb.setup "Model Files\u2026" \
                      $top.mb.analyses "Choose\u2026" \
                      $top.mb.outputs "Save All\u2026" \
                      $top.mb.sim "Options\u2026"] {
    if {[string match *todo_stub* [$m entrycget $e -command]]} {
      lappend stub_hits [list $m $e]
    }
  }
  foreach b [list $top.strip.ana $top.strip.out] {
    if {[string match *todo_stub* [$b cget -command]]} { lappend stub_hits $b }
  }
  foreach e [list "Add\u2026" "Edit\u2026"] {
    if {[string match *todo_stub* [$top.body.ana.ctx entrycget $e -command]]} {
      lappend stub_hits [list ana.ctx $e]
    }
  }
  check "G11 no item-07 todo stubs remain" $stub_hits {}

  # ===========================================================================
  # GE: item 10 esc-dismiss — every dialog dismisses on ESC through its
  # CANCEL path. Per leg: serialize-snapshot the session state, open the
  # dialog through a REAL entry point, optionally perturb a field, deliver a
  # focus-gated <Key-Escape> (send_key), then assert: dialog destroyed,
  # per-window records cleaned (info exists = 0), state byte-identical to the
  # snapshot. Each leg keeps its snapshot local so the legs stay
  # mutation-free by construction.
  # ===========================================================================

  # GE1: Add Variable (= strip button; no per-window records)
  set snap [ase::state_serialize [ase::session_state $key]]
  $top.strip.var invoke
  update
  check_true "GE1 Add Variable dialog up" [winfo exists $top.addvar]
  $top.addvar.name insert 0 geVar
  send_key $top.addvar <Key-Escape> {![winfo exists $top.addvar]}
  check_true "GE1 ESC dismisses Add Variable" \
    [expr {![winfo exists $top.addvar]}]
  check "GE1 state unchanged" \
    [ase::state_serialize [ase::session_state $key]] $snap

  # GE2: Edit Variable — ESC is sent TO THE ENTRY (the bubbling proof: the
  # entry's bindtags include the dialog toplevel, whose ESC binding fires)
  set snap [ase::state_serialize [ase::session_state $key]]
  ase::ui::variable_editor $key 0
  update
  check_true "GE2 Edit Variable dialog up" [winfo exists $top.edvar]
  $top.edvar.value delete 0 end
  $top.edvar.value insert 0 9.99
  send_key $top.edvar.value <Key-Escape> {![winfo exists $top.edvar]}
  check_true "GE2 ESC from inside an entry dismisses the editor" \
    [expr {![winfo exists $top.edvar]}]
  check "GE2 edrow record cleaned" [info exists ::ase::ui::edrow($key,var)] 0
  check "GE2 state unchanged" \
    [ase::state_serialize [ase::session_state $key]] $snap

  # GE3: Add Output (--> strip button)
  set snap [ase::state_serialize [ase::session_state $key]]
  $top.strip.out invoke
  update
  check_true "GE3 Add Output dialog up" [winfo exists $top.edout]
  $top.edout.expr insert 0 v(d)
  send_key $top.edout <Key-Escape> {![winfo exists $top.edout]}
  check_true "GE3 ESC dismisses Add Output" \
    [expr {![winfo exists $top.edout]}]
  check "GE3 edrow/edchk records cleaned" \
    [list [info exists ::ase::ui::edrow($key,out)] \
          [info exists ::ase::ui::edchk($key,plot)] \
          [info exists ::ase::ui::edchk($key,save)]] {0 0 0}
  check "GE3 state unchanged" \
    [ase::state_serialize [ase::session_state $key]] $snap

  # GE4: Choose Analyses (OP,TR strip; perturb by picking the tran radio)
  set snap [ase::state_serialize [ase::session_state $key]]
  $top.strip.ana invoke
  update
  check_true "GE4 Choose Analyses dialog up" [winfo exists $top.chana]
  $top.chana.types.tran invoke
  update
  send_key $top.chana <Key-Escape> {![winfo exists $top.chana]}
  check_true "GE4 ESC dismisses Choose Analyses" \
    [expr {![winfo exists $top.chana]}]
  check "GE4 antype/anen records cleaned" \
    [list [info exists ::ase::ui::dlg($key,antype)] \
          [info exists ::ase::ui::dlg($key,anen)]] {0 0}
  check "GE4 state unchanged" \
    [ase::state_serialize [ase::session_state $key]] $snap

  # GE5: the Analysis Options SUBDIALOG (.chana.x, a nested toplevel):
  # ESC the subdialog FIRST (it dies with its Tk parent), the parent
  # survives (nested-toplevel binding isolation), dlg(anextra) is cleaned
  # (the chana_x_cancel fix — the old bare-destroy Cancel leaked it); then
  # ESC dismisses the parent too.
  set snap [ase::state_serialize [ase::session_state $key]]
  $top.strip.ana invoke
  update
  $top.chana.opts invoke
  update
  check_true "GE5 Analysis Options subdialog up" [winfo exists $top.chana.x]
  send_key $top.chana.x <Key-Escape> {![winfo exists $top.chana.x]}
  check_true "GE5 ESC dismisses Analysis Options" \
    [expr {![winfo exists $top.chana.x]}]
  check_true "GE5 parent Choose Analyses survives" [winfo exists $top.chana]
  check "GE5 anextra record cleaned" \
    [info exists ::ase::ui::dlg($key,anextra)] 0
  send_key $top.chana <Key-Escape> {![winfo exists $top.chana]}
  check_true "GE5 ESC then dismisses Choose Analyses" \
    [expr {![winfo exists $top.chana]}]
  check "GE5 state unchanged" \
    [ase::state_serialize [ase::session_state $key]] $snap

  # GE6: Setup > Design
  set snap [ase::state_serialize [ase::session_state $key]]
  $top.mb.setup invoke "Design\u2026"
  update
  check_true "GE6 Setup Design dialog up" [winfo exists $top.design]
  send_key $top.design <Key-Escape> {![winfo exists $top.design]}
  check_true "GE6 ESC dismisses Setup Design" \
    [expr {![winfo exists $top.design]}]
  check "GE6 dlib/dcell/dview records cleaned" \
    [list [info exists ::ase::ui::dlg($key,dlib)] \
          [info exists ::ase::ui::dlg($key,dcell)] \
          [info exists ::ase::ui::dlg($key,dview)]] {0 0 0}
  check "GE6 state unchanged" \
    [ase::state_serialize [ase::session_state $key]] $snap

  # GE7: Model Files list dialog (no records — immediate-commit engine)
  $top.mb.setup invoke "Model Files\u2026"
  update
  check_true "GE7 Model Files dialog up" [winfo exists $top.models]
  send_key $top.models <Key-Escape> {![winfo exists $top.models]}
  check_true "GE7 ESC dismisses Model Files" \
    [expr {![winfo exists $top.models]}]

  # GE8: Model File row editor over a reopened list dialog — ESC the row
  # editor first (list dialog survives, dlg(models) cleaned), then ESC the
  # list dialog
  set snap [ase::state_serialize [ase::session_state $key]]
  $top.mb.setup invoke "Model Files\u2026"
  update
  $top.models.ctx invoke "Add\u2026"
  update
  check_true "GE8 model row editor up" [winfo exists $top.modrow]
  send_key $top.modrow <Key-Escape> {![winfo exists $top.modrow]}
  check_true "GE8 ESC dismisses the row editor" \
    [expr {![winfo exists $top.modrow]}]
  check_true "GE8 models list dialog survives" [winfo exists $top.models]
  check "GE8 dlg(models) record cleaned" \
    [info exists ::ase::ui::dlg($key,models)] 0
  send_key $top.models <Key-Escape> {![winfo exists $top.models]}
  check_true "GE8 ESC then closes Model Files" \
    [expr {![winfo exists $top.models]}]
  check "GE8 state unchanged" \
    [ase::state_serialize [ase::session_state $key]] $snap

  # GE9: Simulation Options — same engine, terser (dismiss + record checks)
  $top.mb.sim invoke "Options\u2026"
  update
  $top.simopt.ctx invoke "Add\u2026"
  update
  check_true "GE9 option row editor up" [winfo exists $top.optrow]
  send_key $top.optrow <Key-Escape> {![winfo exists $top.optrow]}
  check_true "GE9 ESC dismisses the option row editor" \
    [expr {![winfo exists $top.optrow]}]
  check "GE9 dlg(simopt) record cleaned" \
    [info exists ::ase::ui::dlg($key,simopt)] 0
  send_key $top.simopt <Key-Escape> {![winfo exists $top.simopt]}
  check_true "GE9 ESC dismisses Simulation Options" \
    [expr {![winfo exists $top.simopt]}]

  # GE10: Save All — toggle a checkbox first: the toggle must NOT reach the
  # state through ESC (save_all_i stays as G5 wrote it)
  set snap [ase::state_serialize [ase::session_state $key]]
  $top.mb.outputs invoke "Save All\u2026"
  update
  check_true "GE10 Save All dialog up" [winfo exists $top.saveall]
  $top.saveall.alli invoke
  catch {$top.saveall.opparams invoke}   ;# S4's third blanket, same contract
  send_key $top.saveall <Key-Escape> {![winfo exists $top.saveall]}
  check_true "GE10 ESC dismisses Save All" \
    [expr {![winfo exists $top.saveall]}]
  check "GE10 allv/alli/opparams records cleaned" \
    [list [info exists ::ase::ui::dlg($key,allv)] \
          [info exists ::ase::ui::dlg($key,alli)] \
          [info exists ::ase::ui::dlg($key,opparams)]] {0 0 0}
  check "GE10 state unchanged" \
    [ase::state_serialize [ase::session_state $key]] $snap

  # =========================================================================
  # GE10b-GE10h -- ISSUE 0648: THE TICK THAT VANISHES WITHOUT A WORD
  # =========================================================================
  # The user, verbatim, 2026-08-23: "I went to Outputs > Save and checked the
  # 'Save device OP parameters'. I re-ran the sim and still don't get OP info."
  # Measured at HEAD under a real WM on :99: ticking the box sets
  # dlg($key,opparams)=1 and the checkbutton is visibly ON, while
  # `save_op_params` stays `{}`; ESC destroys the dialog and says NOTHING; and
  # `wm protocol $top.saveall WM_DELETE_WINDOW` is EMPTY -- ase::ui::dialog_frame
  # (:1350) registers no handler, the only WM_DELETE_WINDOW in ase_window.tcl
  # is :277 for the session toplevel -- so a window-manager close destroys the
  # toplevel WITHOUT running save_all_cancel at all (proof: after the close the
  # dlg record still EXISTS, which save_all_cancel would have unset). Issue
  # 0648's sentence "Cancel, ESC via bind_dialog_esc, and the window-manager
  # close all reach save_all_cancel" is WRONG on its third clause, and a
  # "changes were discarded" notice placed only in save_all_cancel would be
  # silent on exactly the path the user's window manager offers.
  #
  # The dialog's whole content is three checkboxes, so a user who ticks one has
  # expressed the entire intent and a visibly-toggled checkbutton reads as
  # applied. These rows pin the answer chosen in decision D1: KEEP OK-commit
  # (GE10h -- the GE1-GE16 zero-state-mutation contract survives) and STATE the
  # discard, name the dropped box, and RE-ARM the OP-card nudge so the user's
  # next run is not silent too (GE10f, the GUI half of the acceptance row).
  #
  # GREEN BEFORE THE CHANGE, and deliberately so (controls, not evidence):
  # GE10e (nothing is ever said today, so "says nothing" is trivially true) and
  # both GE10h rows (nothing commits today either -- they exist to stay green,
  # and they are what a live-commit design would have reddened).
  set snap [ase::state_serialize [ase::session_state $key]]

  # GE10b: the WM close is wired AT ALL, and to the cancel path -- reads '' at
  # HEAD.  GE10e rides its teardown: an untouched dialog must stay silent.
  d_echo_arm
  $top.mb.outputs invoke "Save All\u2026"
  update
  check "GE10b 0648 Save All registers a WM_DELETE_WINDOW handler on its cancel\
 path" \
    [cx {wm protocol $top.saveall WM_DELETE_WINDOW}] \
    [list ase::ui::save_all_cancel $key]
  send_key $top.saveall <Key-Escape> {![winfo exists $top.saveall]}
  d_echo_disarm
  check "GE10e 0648 NON-VACUITY CONTROL: dismissing an UNTOUCHED Save All says\
 nothing" [d_echoed_n {*NOT applied*}] 0

  # GE10c/GE10d: a DISCARDED tick is stated, once, and names the dropped box.
  d_echo_arm
  $top.mb.outputs invoke "Save All\u2026"
  update
  catch {$top.saveall.opparams invoke}
  send_key $top.saveall <Key-Escape> {![winfo exists $top.saveall]}
  d_echo_disarm
  check "GE10c 0648 a ticked box dropped by ESC is REPORTED, exactly once" \
    [d_echoed_n {*Save All*NOT applied*}] 1
  check "GE10d 0648 the report NAMES the box that was dropped" \
    [d_echoed_n {*Save device OP parameters*}] 1
  check "GE10h 0648 ZERO STATE MUTATION survives the fix: tick + ESC still\
 leaves the state byte-identical (the GE1-GE16 contract, decision D1)" \
    [ase::state_serialize [ase::session_state $key]] $snap

  # GE10f: THE ACCEPTANCE ROW, GUI SIDE. The user's exact sequence: the nudge
  # has already fired for this cellview (take, then hold), the user ticks the
  # box, the tick is discarded -- and the tool must be able to speak again on
  # the next card-less run instead of going silent, which is the whole defect.
  cx {ase::op_cards_nudge_reset}
  set ge10f_st [ase::session_state $key]
  set ge10f_take [list [cx {ase::op_cards_nudge_ok $ge10f_st}] \
                       [cx {ase::op_cards_nudge_ok $ge10f_st}]]
  $top.mb.outputs invoke "Save All\u2026"
  update
  catch {$top.saveall.opparams invoke}
  send_key $top.saveall <Key-Escape> {![winfo exists $top.saveall]}
  check "GE10f 0648 THE ACCEPTANCE ROW: a DISCARDED opparams tick RE-ARMS the\
 OP-card nudge (take, hold, then speak again)" \
    [list $ge10f_take [cx {ase::op_cards_nudge_ok [ase::session_state $key]}]] \
    {{1 0} 1}

  # GE10g: the window-manager close now behaves exactly as ESC does. Driven by
  # RUNNING the registered protocol command, which is what a real WM close
  # invokes -- and which is literally nothing at HEAD, so the dialog survives.
  d_echo_arm
  $top.mb.outputs invoke "Save All\u2026"
  update
  catch {$top.saveall.opparams invoke}
  set ge10g_cmd [cx {wm protocol $top.saveall WM_DELETE_WINDOW}]
  catch {uplevel #0 $ge10g_cmd}
  update
  d_echo_disarm
  check "GE10g 0648 a WM close destroys the dialog, cleans all three dlg\
 records AND reports the discard" \
    [list [winfo exists $top.saveall] \
          [info exists ::ase::ui::dlg($key,allv)] \
          [info exists ::ase::ui::dlg($key,alli)] \
          [info exists ::ase::ui::dlg($key,opparams)] \
          [d_echoed_n {*Save All*NOT applied*}]] {0 0 0 0 1}
  check "GE10h 0648 ZERO STATE MUTATION survives the fix: tick + WM close still\
 leaves the state byte-identical" \
    [ase::state_serialize [ase::session_state $key]] $snap
  # GE10i -- ISSUES 0692/0695: THE PER-KEY TOUCH RECORD SURVIVES NO TEARDOWN
  # PATH. GREEN AT HEAD and deliberately so (a guard, not evidence): at HEAD
  # there is no such record to leak -- the three checkbuttons carry no -command
  # and "the user touched this box" is a value diff. It is RETARGETED from the
  # as-opened `seed` record 0692 introduced, which 0695 deletes: once the touch
  # is an event on the widget the seed has no reader left, and a row asserting a
  # record nothing can create asserts nothing (test_ase_window W1zb term 5 pins
  # the deletion itself). This record is the ONLY guard it will ever have:
  # `ase::ui::save_all_close` (ase_window.tcl:3453-3466) unsets exactly
  # allv/alli/opparams and every existing cleanup row -- GE10 and GE10g above --
  # checks exactly those three, so a leaked touch record would outlive OK, ESC
  # AND the window-manager close with ZERO rows red, and would then make the
  # next dialog for this key believe a box was hand-ticked. It lives in this
  # suite because this is where 0648's WM-close protocol is owned.
  # The OK arm deliberately touches nothing, so its commit is idempotent and
  # GE10h's byte-identical-state contract above is not disturbed; the ESC and WM
  # arms DO tick a box first, so the record they must clean is a non-empty one --
  # `alli`, not `opparams`, so the OP-card nudge is left to GE10f which owns it.
  set ge10i {}
  $top.mb.outputs invoke "Save All…"
  update
  catch {$top.saveall.btns.proceed invoke}
  update
  lappend ge10i [info exists ::ase::ui::dlg($key,touched)]
  $top.mb.outputs invoke "Save All…"
  update
  catch {$top.saveall.alli invoke}
  send_key $top.saveall <Key-Escape> {![winfo exists $top.saveall]}
  lappend ge10i [info exists ::ase::ui::dlg($key,touched)]
  $top.mb.outputs invoke "Save All…"
  update
  catch {$top.saveall.alli invoke}
  catch {uplevel #0 [cx {wm protocol $top.saveall WM_DELETE_WINDOW}]}
  update
  lappend ge10i [info exists ::ase::ui::dlg($key,touched)]
  check "GE10i 0695 the per-key touch record is unset by ALL THREE teardown\
 paths -- OK, ESC, and the window-manager close protocol" $ge10i {0 0 0}

  # GE10j -- ISSUE 0695: THE TOUCH RECORD IS CLEARED AT OPEN, NOT ONLY AT CLOSE.
  # `ase::ui::dialog_frame` (ase_window.tcl:1391) DESTROYS an existing toplevel
  # of the same name with NO cancel, so re-opening Save All from the menu while
  # one is already up runs no teardown at all. A `touched` record that survived
  # that would make the fresh dialog believe a box was hand-ticked -- and a box
  # the dialog believes was hand-ticked is exactly the box that must NOT follow
  # an external write. The leak is therefore invisible on OK (a touched field
  # resolves to its own displayed value, which at open IS the live value) and
  # shows up only here: the fresh dialog's box must still follow.
  # RED AT HEAD for 0695's plain reason -- nothing follows yet.
  set ge10j_st [ase::session_state $key]
  set ge10j_off $ge10j_st
  dict set ge10j_off save_op_params 0   ;# 0927: OFF is `0`; `{}` is now the ON default
  cx {ase::session_update $key $ge10j_off}
  $top.mb.outputs invoke "Save All…"
  update
  catch {$top.saveall.opparams invoke}      ;# a hand tick, then ABANDONED
  $top.mb.outputs invoke "Save All…"        ;# re-open: destroy, no cancel, no teardown
  update
  set ge10j_touched [cx {ase::ui::save_all_touched $key}]
  set ge10j_box0 [cx {set [$top.saveall.opparams cget -variable]}]
  cx {ase::ui::save_op_params_on $key}      ;# external write, behind the FRESH dialog
  update
  set ge10j_box1 [cx {set [$top.saveall.opparams cget -variable]}]
  catch {destroy $top.saveall}
  foreach ge10j_r {allv alli opparams seed touched} {
    catch {array unset ::ase::ui::dlg $key,$ge10j_r}
  }
  cx {ase::session_update $key $ge10j_st}
  update
  check "GE10j 0695 a hand tick ABANDONED by re-opening the dialog does not\
 follow the user into the fresh one: its touched set is empty and its box still\
 follows an external write" \
    [list $ge10j_touched $ge10j_box0 $ge10j_box1] {{} 0 1}

  # GE10k -- ISSUE 0695: THE TOUCH IS AN EVENT ON THE WIDGET, AND IT IS WIRED ON
  # ALL THREE BOXES. Measured at HEAD: every one of the three checkbuttons reads
  # `command={}` -- there is no touch event at all, which is precisely why "the
  # user changed this box" had to be a value diff, and a value diff cannot
  # survive a box that follows the live value (test_ase_window W1ze owns that
  # half). Structural on purpose: this is the only row that fails loudly if a
  # later edit re-adds a checkbutton without its -command, and it pins `invoke`'s
  # empty return, which every G5/GE10 hand-tick gesture in this suite relies on.
  $top.mb.outputs invoke "Save All…"
  update
  set ge10k {}
  foreach ge10k_f {allv alli opparams} {
    lappend ge10k [cx {$top.saveall.$ge10k_f cget -command}]
  }
  lappend ge10k [cx {$top.saveall.opparams invoke}]
  catch {$top.saveall.opparams invoke}      ;# un-tick: leave the state alone
  send_key $top.saveall <Key-Escape> {![winfo exists $top.saveall]}
  check "GE10k 0695 every Save All checkbutton reports its own hand tick through\
 ase::ui::save_all_mark_touched, and invoke still returns the empty string the\
 existing gestures rely on" $ge10k \
    [list [list ase::ui::save_all_mark_touched $key allv] \
          [list ase::ui::save_all_mark_touched $key alli] \
          [list ase::ui::save_all_mark_touched $key opparams] {}]

  # leave no half-open dialog behind on a tree where GE10g could not close it
  catch {destroy $top.saveall}
  foreach ge10_r {allv alli opparams seed touched} {
    catch {array unset ::ase::ui::dlg $key,$ge10_r}
  }
  update

  # GE11: Load State browser (no records)
  set snap [ase::state_serialize [ase::session_state $key]]
  $top.mb.session invoke {Load State}
  update
  check_true "GE11 Load State browser up" [winfo exists $top.loadst]
  send_key $top.loadst <Key-Escape> {![winfo exists $top.loadst]}
  check_true "GE11 ESC dismisses Load State" \
    [expr {![winfo exists $top.loadst]}]
  check "GE11 state unchanged" \
    [ase::state_serialize [ase::session_state $key]] $snap

  # GE12: Save State (Save-As)
  set snap [ase::state_serialize [ase::session_state $key]]
  $top.mb.session invoke {Save State}
  update
  check_true "GE12 Save-As dialog up" [winfo exists $top.saveas]
  send_key $top.saveas <Key-Escape> {![winfo exists $top.saveas]}
  check_true "GE12 ESC dismisses Save-As" \
    [expr {![winfo exists $top.saveas]}]
  check "GE12 salib record cleaned" \
    [info exists ::ase::ui::dlg($key,salib)] 0
  check "GE12 state unchanged" \
    [ase::state_serialize [ase::session_state $key]] $snap

  # GE13: the shared confirm — ESC = Cancel, oncmd must NOT run
  unset -nocomplain ::ge13
  ase::ui::confirm $key {Confirm Test} {ESC must cancel, not proceed} \
    {set ::ge13 1}
  update
  check_true "GE13 confirm popup up" [winfo exists $top.confirm]
  send_key $top.confirm <Key-Escape> {![winfo exists $top.confirm]}
  check_true "GE13 ESC dismisses the confirm" \
    [expr {![winfo exists $top.confirm]}]
  check "GE13 oncmd did not run" [info exists ::ge13] 0

  # GE14: the ASE MAIN window stays ESC-unbound (structural), and a
  # temporary test-side witness binding proves ESC DELIVERY to the toplevel
  # (receipts/06: a no-op leg without a delivery witness is hollow-green);
  # the witness is restored to the empty binding afterwards
  check "GE14 session toplevel has no Escape binding" \
    [bind $top <Key-Escape>] {}
  set snap [ase::state_serialize [ase::session_state $key]]
  unset -nocomplain ::ge14
  bind $top <Key-Escape> {set ::ge14 1}
  send_key $top <Key-Escape> {[info exists ::ge14]}
  check "GE14 ESC delivery witnessed" [info exists ::ge14] 1
  bind $top <Key-Escape> {}
  check "GE14 witness removed (binding empty again)" \
    [bind $top <Key-Escape>] {}
  check_true "GE14 window survives" [winfo exists $top]
  check "GE14 state unchanged" \
    [ase::state_serialize [ase::session_state $key]] $snap

  # GE15: the log window stays ESC-exempt (structural — its documented
  # close is Ctrl-W, covered by test_ase_window W6c)
  set lw [ase::ui::log_open $key]
  update
  check_true "GE15 log window up" \
    [expr {$lw ne {} && [winfo exists $lw]}]
  check "GE15 log window has no Escape binding" [bind $lw <Key-Escape>] {}
  destroy $lw
  update

  # GE16: item-08 Select-On-Design ESC regression (D8) — the canvas-side
  # ESC seize/restore is untouched by the dialog wiring. Self-SKIP ONLY
  # when the mode never arms (design window unopenable — the WSLg W4-class
  # raise stall); once armed the assertions MUST run.
  set armed [ase::ui::select_on_design $key {save 1 plot 0}]
  if {$armed != 1} {
    puts "SKIPPED: GE16 sod ESC regression (select_on_design returned\
 $armed — design window unopenable, WSLg stall)"
  } else {
    set cv   $::ase::ui::sod($key,canvas)
    set prev $::ase::ui::sod($key,prevesc)
    # the test_ase_interact I7 pattern via send_key: done = the seized
    # Key-Escape binding reverted (restored by the product's sod_end)
    send_key $cv <Key-Escape> {[bind $cv <Key-Escape>] eq $prev}
    check "GE16 SOD ESC still ends the mode" \
      [expr {[bind $cv <Key-Escape>] eq $prev ? 1 : 0}] 1
    check "GE16 canvas Escape binding restored verbatim" \
      [bind $cv <Key-Escape>] $prev
  }

  # --- G13 (casemode item 9, fix round) ---------------------------------------
  # A Direct-Plot / Select-On-Design pick asks the session's profile for the case
  # mode its expressions must be written in (ase::ui::sod_case_mode). That
  # question used to travel ase::sim_profile_casemode -> ase::sim_profile_resolve
  # -> ::set_sim_defaults, and set_sim_defaults is NOT a read: while the
  # Simulation Configuration dialog is open its first loop SLURPS every
  # `.sim…r.$i.cmd` text widget back into `sim($tool,$i,cmd)`. So one pick
  # COMMITTED the user's unsaved edits into global config and defeated that
  # dialog's Cancel — a read-only pick (issue 0204) writing something it has no
  # business writing. Fixed by asking with the resolver's `init 0` form and doing
  # a guarded one-time init instead; test_ase_sod_case SC208 pins the cause
  # headless, THIS pins the symptom with a real dialog and a real widget.
  ::set_sim_defaults
  set g13_before $::sim(spice,0,cmd)
  simconf
  update
  set g13_w .sim.topf.f.scrl.center.spice.r.0.cmd
  check_true "G13 fixture: the simconf row-0 cmd widget exists" \
    [expr {[winfo exists $g13_w] ? 1 : 0}]
  if {[winfo exists $g13_w]} {
    $g13_w delete 1.0 end
    $g13_w insert 1.0 {G13-USER-IS-STILL-TYPING}
    update
    set g13_mode {}
    catch {set g13_mode [ase::ui::sod_case_mode $key]}
    check "G13 a case-mode resolve leaves an OPEN simconf's unsaved edit uncommitted" \
      [list $::sim(spice,0,cmd) [expr {$g13_mode ne {} ? 1 : 0}]] [list $g13_before 1]
  }
  if {[winfo exists .sim]} {
    destroy .sim
    xschem set semaphore [expr {[xschem get semaphore] -1}]
  }
  update
  set ::sim(spice,0,cmd) $g13_before

  # done: close the session window (unsaved edits are discarded by contract).
  # item 16: this session is DIRTY; the menu Close now routes through
  # close_request's save prompt, so tear down directly (behavior-identical to
  # the pre-rewire menu Close).
  ase::ui::close $key
  update
  check_true "G12 session window closed" [expr {![winfo exists $top]}]

  # --- GG: THE TYPE GRID -- ISSUE 1411 ---------------------------------------
  # Eleven cells, four per row, each carrying its state as a GLYPH on the label.
  #
  # ⚠ EVERY ROW HERE IS A DISPLAY-ARM ROW, and `run_regression.tcl` runs this file
  # on NEITHER of its arms -- so a receipt quoting a T1 zero has not exercised one
  # of them. The resolver's own contract is in test_ase_core.tcl section AG,
  # deliberately, so it survives that.
  check "GG fixture: a session for the grid rows" \
    [ase::open_state aselib nfet_clean ngspice_state1] 1
  update
  set top [ase::ui::window_for $key]
  catch {destroy $top.chana}
  $top.mb.analyses invoke "Choose…"
  update
  set gw $top.chana

  ## GG1 -- ELEVEN CELLS, FOUR PER ROW.
  ## ⚠ ELEVEN, NOT TWELVE. The plan's "twelve grid rows" counts the options sheet,
  ## which is `$w.opts` and is not an analysis type -- registering it would put it
  ## in ase::analysis_offered, in the seed and in the radio variable.
  ## ⚠ READ `grid info` BY NAME. Its key order is not guaranteed and taking
  ## `lindex 3`/`lindex 5` gave {row column} transposed on the first attempt --
  ## a row that would have passed or failed on Tk's option order, not on layout.
  set GG1COLS {}
  foreach gc [winfo children $gw.types] {
    set gi [grid info $gc]
    lappend GG1COLS [list [dict get $gi -row] [dict get $gi -column]]
  }
  check "GG1 every analysis this simulator describes gets a cell, and they wrap\
 four to a row instead of running off the dialog" \
    [list [llength [winfo children $gw.types]] \
          [lrange $GG1COLS 0 3] [lindex $GG1COLS 4]] \
    [list 11 {{0 0} {0 1} {0 2} {0 3}} {1 0}]

  ## GG2 -- ⚠ THE PATHS DID NOT MOVE. Four committed rows in three suites drive
  ## `$top.chana.types.<type>`; adding cells is safe, moving them is not, and
  ## issue 1405 is what that lesson cost. `pack` became `grid` inside the SAME
  ## frame, so the children keep their names.
  check "GG2 the cells the rest of the tree drives by name are still there under\
 those names, with the new ones added beside them" \
    [list [winfo exists $gw.types.op] [winfo exists $gw.types.dc] \
          [winfo exists $gw.types.ac] [winfo exists $gw.types.tran] \
          [winfo exists $gw.types.pss]] \
    {1 1 1 1 1}

  ## GG3 -- THE GLYPH CARRIES THE STATE, AND `ok` CARRIES NONE.
  ## Marking the normal case is how a grid becomes noise.
  check "GG3 a cell this adapter cannot yet drive is marked, and a cell that is\
 simply available is not" \
    [list [$gw.types.op cget -text] [$gw.types.pss cget -text] \
          [ase::ui::chana_glyph ok]] \
    [list op "⊘ pss" {}]

  ## GG4 -- ⚠ THE MEASUREMENT THAT FORCED THE GLYPH. A per-cell `-background` is
  ## WIPED: `ase::ui::_theme_widget`'s Radiobutton arm rewrites it and
  ## `ase::ui::populate` ends in `apply_theme $top`, which recurses into this child
  ## toplevel on every state mutation. This row sets a colour, repaints, and shows
  ## it gone -- so nobody re-proposes colour-coded cells.
  $gw.types.pss configure -background #123456
  set GG4SET [$gw.types.pss cget -background]
  ase::ui::apply_theme $top
  update
  check "GG4 a colour put on a cell does not survive the theme pass, which is why\
 the state is a glyph and not a colour" \
    [list [expr {$GG4SET eq {#123456}}] \
          [expr {[$gw.types.pss cget -background] eq {#123456}}]] \
    {1 0}

  ## GG5 -- ⚠ EVERY CELL IS SELECTABLE, INCLUDING A BLOCKED ONE, AND THIS IS THE
  ## ROW THAT MATTERS. `invoke` on a `-state disabled` radiobutton is a SILENT
  ## no-op (rc 0, variable unchanged, `-command` never fired), so disabling the
  ## cell would make a `.state` file carrying `{type pss enabled 1}` impossible to
  ## turn OFF in the dialog -- and would make a future row written as
  ## `$top.chana.types.pss invoke` pass while doing nothing at all.
  $gw.types.pss invoke
  update
  check "GG5 a cell for an analysis that cannot be run is still clickable, so its\
 reason can be read and a bench that already carries it can be edited" \
    [list [$gw.types.pss cget -state] $::ase::ui::dlg($key,antype)] \
    {normal pss}

  ## GG6 -- AND SELECTING IT SAYS WHY.
  check "GG6 selecting a blocked cell explains it in words rather than leaving the\
 user to guess from a greyed control" \
    [list [expr {[$gw.status cget -text] ne {}}] \
          [expr {[$gw.status cget -text] eq \
                 [ase::analysis_state_msg ngspice pss \
                   [ase::analysis_state ngspice pss [ase::sim_caps_cached ngspice]]]}]] \
    {1 1}

  ## GG7 -- WHAT IS DISABLED IS THE **Enable** CHECKBUTTON, not the cell.
  set GG7BLOCKED [$gw.enable cget -state]
  $gw.types.op invoke
  update
  check "GG7 an analysis that cannot be run cannot be switched on, while one that\
 can still can" \
    [list $GG7BLOCKED [$gw.enable cget -state]] \
    {disabled normal}

  ## GG8 -- ⚠ BUT A ROW ALREADY ON MUST STILL BE TURNABLE OFF. A bench can carry
  ## `{type pss enabled 1}` from a hand-edited file, and `ase::preflight_gate`
  ## refuses the run; if the dialog also refused to let it be cleared the user
  ## would have no way out except editing the file by hand.
  set GG8ST [ase::session_state $key]
  set GG8ROWS [ase::state_get $GG8ST analyses]
  lappend GG8ROWS {type pss enabled 1}
  dict set GG8ST analyses $GG8ROWS
  ase::session_update $key $GG8ST
  catch {destroy $gw}
  $top.mb.analyses invoke "Choose…"
  update
  set gw $top.chana
  $gw.types.pss invoke
  update
  check "GG8 a blocked analysis that is already switched on in the bench can still\
 be switched off, so a hand-edited state file is never a trap" \
    [list $::ase::ui::dlg($key,anen) [$gw.enable cget -state]] \
    {1 normal}

  ## GG9 -- DETECT IS OFFERED ONLY WHERE IT COULD CHANGE AN ANSWER.
  ## ⚠ A `noprobe` CELL IS ONE DETECT CAN NEVER HELP; offering the button there is
  ## the button that lies, and it is why `noprobe` is a separate reason token.
  check "GG9 the Detect button is live while cells rest on an assumption, and the\
 grid says which cells those are" \
    [list [winfo exists $gw.detect] \
          [$gw.detect cget -state] \
          [ase::analysis_detectable ngspice [ase::sim_caps_cached ngspice]]] \
    {1 normal 1}

  ## GG10 -- ⚠ DETECT PAINTS BEFORE IT BLOCKS, AND THE ORDER IS THE WHOLE POINT.
  ## The measurement can take up to 31.2 s against a binary that never answers,
  ## with Tk frozen throughout; setting the sentence and calling `update idletasks`
  ## BEFORE the blocking call is what puts it on screen. Structural, because the
  ## only behavioural way to see it is to own a binary that hangs.
  set GG10B {}
  foreach gl [split [info body ase::ui::chana_detect] "\n"] {
    if {[regexp {^\s*#} $gl]} { continue }
    append GG10B "$gl\n"
  }
  check "GG10 STRUCTURAL Detect puts its sentence on screen before it blocks, not\
 after the wait is over -- which would be the same as not saying it" \
    [list [expr {[string first {update idletasks} $GG10B] > \
                 [string first {analyses_measuring} $GG10B]}] \
          [expr {[string first {analysis_detect} $GG10B] > \
                 [string first {update idletasks} $GG10B]}]] \
    {1 1}

  ## GG11 -- NO TENTH COLOUR.
  check "GG11 the grid adds no colour to the locked palette, so it reads the same\
 in every theme" \
    [llength [dict keys [ase::palette]]] 9

  # ==========================================================================
  # GN -- THE PRECONDITION BANNER UNDER THE FORM. Stage 6, issue 1435.
  # ==========================================================================
  # ⚠ IT IS A NEW WIDGET, AND THAT WAS MEASURED RATHER THAN PREFERRED.
  # PLAN.md's Stage 4 says of this item "there is no new pixel ... No look debt
  # is filed", on the ground that everything reaches the user through
  # `ase::ui::dialog_status`. Measured on :99 against this very dialog,
  # 2026-09-12: `$w.status` is OCCUPIED ON ALL ELEVEN CELLS of a fresh bench --
  # nine `baseline` cells carry "Offered because every build of this simulator
  # has it. Nothing was measured." and the two `unrenderable` ones carry theirs
  # -- so a precondition sentence there would EVICT a capability sentence that is
  # equally true, and `$w.status` has `-wraplength 0`, which took the dialog from
  # 667 px to 856 px with one 101-character sentence in it. GN1 and GN2 are those
  # two facts as rows, so the plan's paragraph cannot be re-derived from nothing.
  # A `look` debt is filed.

  ## GN1 -- THE STATUS LINE IS ALREADY SPOKEN FOR, AND THE FIRST-RUN USER IS THE
  ## ONE IT IS SPOKEN FOR ON EVERY CELL.
  ##
  ## ⚠ THE CAPABILITY CACHE IS CLEARED FOR THIS ROW, AND THE FIRST CUT DID NOT
  ## DO IT -- which is how this row found its own refinement. With capabilities
  ## MEASURED, nine of the eleven cells answer `measured` and
  ## `ase::analysis_state_msg` returns {} for them, so the status line looks free.
  ## With a COLD cache -- what a user who has never pressed Detect has, which is
  ## also the state `test_ase_core`'s ISO1434 pins as the honest one for a suite
  ## -- all eleven carry a sentence. Both states are real; the collision exists
  ## in one of them, and a surface that shares a widget only SOMETIMES is worse
  ## than one that never does, because the eviction then depends on whether the
  ## user pressed a button in an unrelated part of the dialog.
  set GN1CAPS $::ase::sim_caps
  set ::ase::sim_caps [dict create]
  set GN1 {}
  set GN1N 0
  foreach gnt [ase::analysis_states ngspice [ase::sim_caps_cached ngspice]] {
    incr GN1N
    set ::ase::ui::dlg($key,antype) [lindex $gnt 0]
    ase::ui::chana_show $key
    if {[string trim [$gw.status cget -text]] eq {}} { lappend GN1 [lindex $gnt 0] }
  }
  check "GN1 with nothing measured -- the state a first-run user is in -- the\
 existing status line carries a sentence on EVERY cell, so the banner cannot be\
 a second tenant of it" [list $GN1N $GN1] {11 {}}
  set ::ase::sim_caps $GN1CAPS
  ## GN1b -- AND A CELL RESTING ON NOTHING CARRIES ONE WHATEVER THE CACHE SAYS.
  ##
  ## ⚠ THIS ROW'S TITLE SAID *"the two unrenderable cells"* AND THAT STOPPED
  ## BEING TRUE AT ISSUE 1452, WHICH MADE `sp` RENDERABLE. The row stayed GREEN
  ## -- `sp` reads `absent unmeasured` with nothing measured and a cell in that
  ## state also carries a sentence -- so nothing went red and the sentence rotted
  ## in place. Receipt 32 recorded it as C8 and the GUI half owns the file, so it
  ## is corrected here rather than carried. `pss` is the last `unrenderable` type
  ## in the shipped registry; `sp` is now `absent`/`unmeasured`, which is a
  ## DIFFERENT reason for the same sentence and is why both cells still answer.
  set GN1B {}
  foreach gnt {sp pss} {
    set ::ase::ui::dlg($key,antype) $gnt
    ase::ui::chana_show $key
    lappend GN1B [expr {[string trim [$gw.status cget -text]] ne {}}]
  }
  ## ⚠ AND THE SECOND TERM IS WHAT KEEPS THE TITLE HONEST NEXT TIME: it asks
  ## RENDERABILITY rather than the cell's state word. The state word depends on
  ## whether the capability cache is warm -- measured here, `pss` reads `blocked`
  ## with a warm cache and `unrenderable` with a cold one, which is GG9's own
  ## lesson -- while `ase::analysis_renderable` is decided by the registry alone
  ## and cannot drift with the environment. The day `pss` becomes renderable this
  ## row goes RED and names the paragraph above as the one to rewrite.
  set GN1BREND {}
  foreach gnt {sp pss} { lappend GN1BREND [ase::analysis_renderable ngspice $gnt] }
  check "GN1b a cell that cannot be run here carries a sentence whatever has been\
 measured, and `sp` is no longer one of the unrenderable ones" \
    [list $GN1B $GN1BREND] {{1 1} {1 0}}

  ## GN2 -- AND IT DOES NOT WRAP, so a precondition sentence in it widens the
  ## dialog. The banner's own `-wraplength` is what keeps it from doing that.
  update idletasks
  set GN2W [winfo reqwidth $gw]
  check "GN2 the banner is its own wrapping label and costs the dialog no width" \
    [list [winfo class $gw.note] [$gw.status cget -wraplength] \
          [expr {[$gw.note cget -wraplength] > 0}] \
          [expr {[winfo reqwidth $gw.note] <= $GN2W}]] \
    {Label 0 1 1}

  ## GN3 -- WHERE IT SITS: under the form, above `Options…`, and nothing moved to
  ## make room. Issue 1405 is what moving a path costs.
  ##
  ## ⚠ THE FORM IS AT ROW **3** SINCE ISSUE 1448, AND THAT IS A MOVE THIS ROW
  ## EXISTS TO NOTICE. The handle grid took row 1, so `$w.enable`/`$w.status`
  ## went to 2 and the form to 3 -- the same WIDGETS in the same frame, one row
  ## lower, which is not what issue 1405 cost 100 checks over (that was a widget
  ## PATH moving, `$w.<field>` -> `$w.form.<field>`). The banner's own row, the
  ## `Options…` row and the button bar are the numbers that must not move, and
  ## they have not: 7, 8, 9. The handle grid's row is asserted here too, so the
  ## next thing inserted into this dialog has to come and read this paragraph.
  set GN3 [grid info $gw.note]
  check "GN3 the banner is at grid row 7, spanning both columns, with the handle\
 grid at 1, the form at 3 and Options/buttons still at 8 and 9" \
    [list [dict get $GN3 -row] [dict get $GN3 -columnspan] \
          [dict get [grid info $gw.rows] -row] \
          [dict get [grid info $gw.form] -row] \
          [dict get [grid info $gw.opts] -row] \
          [dict get [grid info $gw.btns] -row]] {7 2 1 3 8 9}

  ## GN4 -- COLD: the dialog has netlisted nothing, and says so rather than
  ## saying nothing. ⚠ THE SLOT IS CLEARED FIRST so this row cannot inherit a
  ## warm slot from an earlier section and pass vacuously.
  ase::facts_clear
  set ::ase::ui::dlg($key,antype) noise
  ase::ui::chana_show $key
  check "GN4 with nothing netlisted the banner says so, and names the door" \
    [list [expr {[$gw.note cget -text] ne {}}] \
          [string match "*[ase::ui::menu_path_netlist_recreate]*" \
             [$gw.note cget -text]]] {1 1}
  ## GN4b -- AND THE STATUS LINE IS UNTOUCHED BY IT. This is the eviction that
  ## did NOT happen, asserted rather than assumed -- before and after a repaint,
  ## plus the structural half, because "it happens not to write it today" and "it
  ## cannot write it" are different guarantees.
  set GN4BEFORE [$gw.status cget -text]
  ase::ui::chana_note $key
  check "GN4b painting the banner does not touch the status line, and cannot" \
    [list [expr {[$gw.status cget -text] eq $GN4BEFORE}] \
          [expr {[string first {.status} [info body ase::ui::chana_note]] >= 0}] \
          [expr {[string first {dialog_status} [info body ase::ui::chana_note]] >= 0}]] \
    {1 0 0}

  ## GN5 -- WARM: a netlist somebody asked for, through the menu entry the banner
  ## names, and the advice arrives. ⚠ `ase::ui::do_netlist_recreate` IS THE
  ## PRODUCT'S OWN GESTURE, not a direct ase::netlist -- the point of the item is
  ## that a legitimate gesture is the only filler.
  ase::ui::do_netlist_recreate $key
  set GN5FACTS [ase::netlist_facts_cached [ase::session_state $key]]
  set ::ase::ui::dlg($key,antype) ac
  ase::ui::chana_show $key
  check "GN5 Netlist > Recreate fills the slot and the ac cell gains its\
 precondition -- the run has not started" \
    [list [expr {$GN5FACTS ne {}}] \
          [string match "*no AC source*" [$gw.note cget -text]] \
          [string match "*Fix: put `ac 1`*" [$gw.note cget -text]]] {1 1 1}

  ## GN6 -- IT FOLLOWS THE SELECTED CELL. An `op` row has nothing to say and the
  ## banner goes quiet; picking `ac` again brings it back. A banner that stuck
  ## would be describing the previous analysis.
  set ::ase::ui::dlg($key,antype) op
  ase::ui::chana_show $key
  set GN6OP [$gw.note cget -text]
  set ::ase::ui::dlg($key,antype) ac
  ase::ui::chana_show $key
  set GN6AC [$gw.note cget -text]
  check "GN6 the banner follows the selected cell and clears when there is\
 nothing to say" [list $GN6OP [expr {$GN6AC ne {}}]] {{} 1}

  ## GN7 -- IT READS THE FORM, NOT THE STORED ROW. Type a source name that is not
  ## in the circuit into the dc form and the banner says so BEFORE OK is pressed.
  ## ⚠ THIS IS THE HALF THAT MAKES IT ADVICE RATHER THAN A POST-MORTEM.
  set ::ase::ui::dlg($key,antype) dc
  ase::ui::chana_show $key
  set GN7BEFORE [$gw.note cget -text]
  $gw.form.source delete 0 end
  $gw.form.source insert 0 Vnope
  ase::ui::chana_note $key
  check "GN7 the banner judges what is TYPED in the form, before OK" \
    [list $GN7BEFORE [string match "*no 'Vnope' to sweep*" [$gw.note cget -text]]] \
    {{} 1}
  ## GN7b -- AND THE MERGED ROW IS THE ONE OK WOULD STORE: a HIDDEN ADVANCED field
  ## keeps its stored value rather than vanishing because no widget exists.
  ##
  ## ⚠ SINCE ISSUE 1446 THAT SENTENCE HAS ONE EXCEPTION, AND `GR6h` MEASURES IT.
  ## `chana_ok` reads `ase::ui::chana_commit_vals` -- the live widgets merged
  ## over this type's cache -- so when the user has TYPED into an advanced field
  ## and folded it away, OK stores the remembered value while this banner still
  ## reads the stored one. Untouched, as here, the two agree.
  ##
  ## ⚠ THE FIXTURE IS `tran`, NOT `dc`, AND THAT IS A SABOTAGE FINDING. The first
  ## cut asserted this on the `dc` form, which has no advanced field at all, so
  ## "overlay the form on the stored row" and "build from the form alone" gave
  ## the same answer and the sabotage survived. `tran`'s `tmax` is `advanced 1`
  ## and the disclosure opens CLOSED, so `form_has` is false for it while the
  ## state carries a value -- the one shape that can tell the two apart. *A row
  ## whose fixtures never disagree cannot fail.*
  set GN7ST [ase::session_state $key]
  set GN7ROWS [ase::state_get $GN7ST analyses]
  for {set GN7I 0} {$GN7I < [llength $GN7ROWS]} {incr GN7I} {
    if {[ase::state_get [lindex $GN7ROWS $GN7I] type] eq {tran}} {
      lset GN7ROWS $GN7I [dict create type tran enabled 0 step 1n stop 1u tmax 2n]
    }
  }
  dict set GN7ST analyses $GN7ROWS
  ase::session_update $key $GN7ST
  set ::ase::ui::dlg($key,advopen) 0
  set ::ase::ui::dlg($key,antype) tran
  ase::ui::chana_show $key
  set GN7MERGED [ase::ui::chana_merged_row $key tran]
  check "GN7b the merged row overlays the form on the STORED row, so a hidden\
 advanced field is not lost -- and it really is hidden" \
    [list [ase::ui::form_has $key step] [ase::ui::form_has $key tmax] \
          [expr {[dict exists $GN7MERGED tmax] ? [dict get $GN7MERGED tmax] : {LOST}}] \
          [expr {[dict exists $GN7MERGED step] ? [dict get $GN7MERGED step] : {LOST}}]] \
    {1 0 2n 1n}
  ## GN7c -- the merged row and the banner read the SAME typed value, which is
  ## what makes the banner's answer the answer OK would act on. ⚠ The form is
  ## re-typed here because GN7b rebuilt it: `chana_show` destroys `$w.form`, so
  ## anything typed before it is gone by construction.
  set ::ase::ui::dlg($key,antype) dc
  ase::ui::chana_show $key
  $gw.form.source delete 0 end
  $gw.form.source insert 0 Vnope
  ase::ui::chana_note $key
  check "GN7c the merged row and the banner read the same typed value" \
    [list [dict get [ase::ui::chana_merged_row $key dc] source] \
          [string match "*no 'Vnope' to sweep*" [$gw.note cget -text]]] {Vnope 1}
  $gw.form.source delete 0 end
  $gw.form.source insert 0 V2
  ase::ui::chana_note $key

  ## GN8 -- A DISABLED ROW STILL GETS THE ADVICE, and that is where it parts
  ## company with `ase::analysis_precheck` (bench-wide, enabled-only). The
  ## commonest reason to be looking at this form is to decide whether to turn the
  ## analysis ON.
  set ::ase::ui::dlg($key,antype) ac
  ase::ui::chana_show $key
  check "GN8 the ac cell is advised while its row is still switched off" \
    [list [ase::state_get [ase::ui::chana_row $key ac] enabled 0] \
          [expr {[$gw.note cget -text] ne {}}]] {0 1}

  ## GN9 -- STALE: the banner does not go on quoting a netlist the schematic has
  ## outgrown. Driven through the slot's own stamp, because touching the fixture
  ## schematic here would move it under every later row in this file.
  set ::ase::netlist_facts_slot [dict replace $::ase::netlist_facts_slot \
                                   schstamp {1:1}]
  ase::ui::chana_show $key
  check "GN9 a schematic that has moved since the netlist is said to have moved,\
 rather than quoted" \
    [list [string match "*schematic has changed*" [$gw.note cget -text]] \
          [string match "*no AC source*" [$gw.note cget -text]]] {1 0}
  ase::ui::do_netlist_recreate $key
  ase::ui::chana_show $key

  ## GN10 -- ⚠ OPENING THIS DIALOG NETLISTS NOTHING. The schema half of this is
  ## test_ase_core's BN2; this is the same claim driven through the real dialog,
  ## because that is the gesture the constraint is about.
  ase::facts_clear
  rename ase::netlist ase::netlist_gnsaved
  set ::gn_netlisted 0
  proc ase::netlist {args} { set ::gn_netlisted 1 ; error "GN10: the dialog netlisted" }
  catch {destroy $gw}
  set gw [ase::ui::choose_analyses $key]
  foreach gnt {op dc ac tran noise tf pz sens disto sp pss} {
    catch {$gw.types.$gnt invoke}
  }
  update
  rename ase::netlist {}
  rename ase::netlist_gnsaved ase::netlist
  check "GN10 opening the dialog and clicking all eleven cells starts NO netlist" \
    [list $::gn_netlisted [winfo exists $gw.note]] {0 1}
  ase::ui::do_netlist_recreate $key

  ## GN11 -- ⚠ THE DOOR THE BANNER NAMES AND THE MENU ENTRY IT NAMES ARE ONE
  ## STRING, AND THIS ROW IS WHY THE MENU WAS REWIRED. The banner composes
  ## `Simulation > Netlist > Recreate` from `lbl_simulation`, `lbl_netlist` and
  ## `lbl_netlist_recreate`; before issue 1435 the menu spelled the last two as
  ## bare literals, so renaming the entry would have left the banner pointing at
  ## a menu item that no longer existed. Invariant I1, the rule the three labels
  ## beside them already carry.
  ##
  ## ⚠ BOTH HALVES, AND THE STRUCTURAL ONE IS NOT OPTIONAL. Comparing the
  ## rendered labels to the procs' answers passes just as well when the builder
  ## holds a hardcoded copy -- measured: the sabotage that put `-label Recreate`
  ## back reddened NOTHING until this row existed. So the builder's body is read
  ## too, the way GG10 reads `chana_detect`'s.
  set GN11B {}
  foreach gnl [split [info body ase::ui::build] "\n"] {
    if {[regexp {^\s*#} $gnl]} { continue }
    append GN11B "$gnl\n"
  }
  check "GN11 the Netlist menu is BUILT from the same two labels the banner's\
 door is composed from, and the rendered entries agree with them" \
    [list [$top.mb.sim.netlist entrycget 0 -label] \
          [ase::ui::lbl_netlist_recreate] \
          [expr {[string first {[ase::ui::lbl_netlist_recreate]} $GN11B] >= 0}] \
          [expr {[string first {[ase::ui::lbl_netlist]} $GN11B] >= 0}] \
          [ase::ui::menu_path_netlist_recreate]] \
    {Recreate Recreate 1 1 {Simulation > Netlist > Recreate}}

  catch {destroy $gw}
  ase::ui::close $key
  update


  # --- G14: THE DIALOG DESCRIBES **THIS** SESSION'S SIMULATOR -----------------
  # Issue 1408, Stage 2 item 2d of doc/claude/ase_analyses_batch/.
  #
  # ⚠ MEASURED BEFORE THE FIX, ON THIS ARM: a bench whose state said
  # `simulator zznoad` -- a backend registered with the five hooks and NO
  # `analysis_types` hook -- was shown NGSPICE's four radio buttons, a
  # committable `dc` form, and `dc V2 0 1.8 0.01` in the Arguments column. The
  # registry was right the whole time (`ase::analysis_offered zznoad` answered
  # `{}`); the dialog asked `ase::analysis_offered` with no argument.
  #
  # ⚠ THESE ROWS ARE ON THE DISPLAY ARM AND `run_regression.tcl` RUNS THIS FILE
  # ON NEITHER OF ITS ARMS -- measured. So a receipt quoting a T1 zero has NOT
  # exercised one of them. The schema half is in test_ase_core section AD,
  # deliberately, so the contract survives even where these cannot run.
  proc g14_five {} {
    return [dict create \
      render_deck  [ase::backend_hook ngspice render_deck] \
      run_cmd      [ase::backend_hook ngspice run_cmd] \
      log_file     [ase::backend_hook ngspice log_file] \
      result_probe [ase::backend_hook ngspice result_probe] \
      raw_file     [ase::backend_hook ngspice raw_file]]
  }
  catch {ase::register_backend zznoad [g14_five]}
  ## ⚠ `ase::session_update` DOES NOT REDRAW THE PANE, measured -- the Arguments
  ## column still held ngspice's deck lines after the state said `zznoad`. These
  ## rows set the simulator behind the UI's back (there is no gesture that edits
  ## the state key directly), so they must repaint the way the product's own
  ## simulator-choice path does, or they would be measuring a stale treeview.
  proc g14_setsim {k s} {
    set st [ase::session_state $k]
    dict set st simulator $s
    ase::session_update $k $st
    ase::ui::populate $k
    update
  }
  proc g14_kids {w} {
    if {![winfo exists $w]} { return NOWIDGET }
    set o {} ; foreach c [winfo children $w] { lappend o [winfo name $c] }
    return [lsort $o]
  }
  proc g14_state {w} {
    if {![winfo exists $w]} { return NOWIDGET }
    if {[catch {$w cget -state} v]} { return NOSTATE }
    return $v
  }

  ## ⚠ A FRESH SESSION AND A FRESH `$top`. By this point in the file the window
  ## G1 opened is gone -- measured, `$top.mb.analyses` raised
  ## `invalid command name ".ase5.mb.analyses"` -- so this block re-opens rather
  ## than inheriting a toplevel whose lifetime it does not control.
  check "G14 fixture: a session for these rows" \
    [ase::open_state aselib nfet_clean ngspice_state1] 1
  update
  set top [ase::ui::window_for $key]
  check_true "G14 fixture: its window is up" \
    [expr {$top ne {} && [winfo exists $top]}]
  catch {destroy $top.chana}
  g14_setsim $key zznoad
  set G14ANA0 [ase::state_get [ase::session_state $key] analyses]
  $top.mb.analyses invoke "Choose…"
  update

  ## G14a -- the grid is empty, because this simulator offers nothing.
  check "G14a a bench naming a simulator ASE-L has no adapter for gets NO analysis\
 radio buttons, instead of the default simulator's four" \
    [g14_kids $top.chana.types] {}

  ## G14b -- and it SAYS SO. ⚠ Not a fifth cell state and not a Detect button:
  ## the states are per ANALYSIS and there are no rows to colour, and no probe
  ## can help because the gap is in ASE-L rather than in the binary.
  check "G14b an empty grid says why it is empty, naming the simulator" \
    [list [expr {[$top.chana.status cget -text] ne {}}] \
          [expr {[string first {zznoad} [$top.chana.status cget -text]] >= 0}] \
          [expr {[$top.chana.status cget -text] eq [ase::analysis_gap_msg zznoad]}]] \
    {1 1 1}

  ## G14c -- every control that could write the bench is disabled.
  check "G14c with nothing to choose, Enable, Options and OK are all disabled" \
    [list [g14_state $top.chana.enable] [g14_state $top.chana.opts] \
          [g14_state $top.chana.btns.proceed]] \
    {disabled disabled disabled}

  ## G14d -- ⚠ AND THE PRESELECT IS EMPTY, NOT `op`. An unconditional `op` is
  ## what let OK append `{type op enabled 1}` to a bench whose backend cannot
  ## render op.
  check "G14d nothing is preselected when nothing is offered" \
    $::ase::ui::dlg($key,antype) {}

  ## G14e -- ⚠ THE COMMIT DOORS REFUSE ON **MEMBERSHIP**, NOT ON EXISTENCE.
  ## `[info exists dlg($key,antype)]` is TRUE for an `antype` of `{}`, which is
  ## exactly the value an empty grid leaves behind -- so the three doors were
  ## reachable and `chana_x_ok` would have written `{type {} enabled 0}` into the
  ## bench: a state key for a type that does not exist, round-tripping through
  ## the .state file forever. Driving the PROCS and not the buttons is the point,
  ## because a disabled Tk button's `invoke` returns `{}` and would hide it.
  set G14SAID {}
  set ::g14_echo {}
  set g14_had [expr {[info commands ::ciw_echo] ne {}}]
  if {$g14_had} { rename ::ciw_echo ::g14_saved_ciw }
  proc ::ciw_echo {line {tag {}}} { lappend ::g14_echo [list $tag $line] ; return {} }
  catch {ase::ui::chana_ok $key}
  catch {ase::ui::chana_options $key}
  ## ⚠ `anextra` IS PLANTED ON PURPOSE, AND WITHOUT IT THIS ROW IS BLIND.
  ## `chana_x_ok` returns early unless `dlg($key,anextra)` exists, and only
  ## `chana_options` sets it -- which the guard above has just refused. MEASURED:
  ## with `chana_x_ok`'s membership guard DELETED the suite still read ALL PASS,
  ## because the door was never reached. The state it protects is reachable in
  ## the product (open Options under one simulator, change the bench's simulator,
  ## press OK), and it is the door that writes `{type {} enabled 0}` -- a state
  ## key for a type that does not exist, round-tripping through the .state file
  ## forever. So the fixture puts the dialog in that state and knocks.
  set ::ase::ui::dlg($key,anextra) {}
  catch {ase::ui::chana_x_ok $key}
  array unset ::ase::ui::dlg $key,anextra
  set G14SAID $::g14_echo
  catch {rename ::ciw_echo {}}
  if {$g14_had} { rename ::g14_saved_ciw ::ciw_echo }
  update
  check "G14e all three commit doors refuse: the bench is untouched, no Options\
 subdialog is built, and each refusal says why" \
    [list [expr {[ase::state_get [ase::session_state $key] analyses] eq $G14ANA0}] \
          [winfo exists $top.chana.x] \
          [expr {[llength $G14SAID] >= 1}] \
          [expr {[string first {has no adapter} [lindex $G14SAID 0 1]] >= 0}]] \
    {1 0 1 1}

  ## G14f -- the Arguments column. ⚠ THE `op` ROW GOES BLANK and that is a
  ## ratified consequence, not an accident: there is no deck line to show, and
  ## the Type column beside it already says `op`.
  set G14PANE {}
  foreach g14r [$top.body.ana.tv children {}] {
    lappend G14PANE [lindex [$top.body.ana.tv item $g14r -values] 3]
  }
  check "G14f the Arguments column shows the stored keys under a simulator with\
 no adapter, and the op row -- which has no keys -- goes blank rather than\
 echoing a deck line no backend emits" \
    $G14PANE {{} {source=V2 start=0 stop=1.8 step=0.01} {} {}}

  catch {destroy $top.chana}

  ## G14g -- THE CONTROL, and it is what makes every row above non-vacuous:
  ## put ngspice back and the whole dialog works exactly as it did.
  g14_setsim $key ngspice
  $top.mb.analyses invoke "Choose…"
  update
  set G14PANE2 {}
  foreach g14r [$top.body.ana.tv children {}] {
    lappend G14PANE2 [lindex [$top.body.ana.tv item $g14r -values] 3]
  }
  ## ⚠ ELEVEN, NOT FOUR. This row asserted four until issue 1410 registered the
  ## seven analyses ngspice has that ASE-L cannot yet drive; they are LISTED so the
  ## user can see they exist, and each carries a `blocked` cell. The row is a
  ## CONTROL -- its job is that putting ngspice back restores the working dialog --
  ## so it tracks the registry rather than naming a number, and `lsort` is why the
  ## order here is alphabetical while the grid's is emit order (AG1 pins that).
  ## ⚠ THE SECOND TERM ASSERTS THE GAP SENTENCE IS **GONE**, NOT THAT THE LINE IS
  ## EMPTY. It was written as "nothing is said" when the status line existed only
  ## to explain an empty grid; issue 1411 gave every cell a sentence, so with
  ## ngspice back the line carries the SELECTED cell's own reason -- `op` resting
  ## on a source-verified invariant nobody has measured. What must not come back
  ## is the no-adapter line, and that is what is checked.
  check "G14g CONTROL with ngspice back the full grid returns, the no-adapter\
 line is gone and the selected cell explains itself instead, every control is\
 live, op is preselected and the pane shows deck lines again" \
    [list [g14_kids $top.chana.types] \
          [expr {[string first {no adapter} [$top.chana.status cget -text]] < 0}] \
          [expr {[$top.chana.status cget -text] eq \
                 [ase::analysis_state_msg ngspice op \
                   [ase::analysis_state ngspice op [ase::sim_caps_cached ngspice]]]}] \
          [list [g14_state $top.chana.enable] [g14_state $top.chana.opts] \
                [g14_state $top.chana.btns.proceed]] \
          $::ase::ui::dlg($key,antype) \
          [lindex $G14PANE2 0]] \
    [list {ac dc disto noise op pss pz sens sp tf tran} 1 1 {normal normal normal} op op]
  $top.chana.btns.cancel invoke
  update

  # --- GR5: WHAT YOU TYPED SURVIVES A TYPE CLICK -- ⚖ R5, ISSUE 1445 ---------
  # The user ruled on 2026-09-13: *"Make it remember -- that's a more
  # professional UI. We are trying to be better than Cadence"*. That REVERSES
  # D4 of `doc/claude/ase_l_batch/prompts/item07_dialogs.md` (*"in-form edits of
  # the previous type are DISCARDED"*) -- NOT `ase_analyses_batch/DECISIONS.md`'s
  # own D4, which is about the per-row keys `id` and `x` and would be a schema
  # change. `doc/claude/ase_l_ux_batch/FINDINGS.md` carries the lived report the
  # ruling answers: *"I typed 500u, clicked the ac radio, clicked back, and 500u
  # was gone"*, and GR5a is that sentence as a row.
  #
  # ⚠ WHAT THE REVERSAL DID **NOT** CHANGE IS THE COMMIT, and GR5g is the row
  # that says so. D4's stated reason -- "deterministic, no hidden multi-type
  # writes" -- defended the commit and was merely attached to the discarding.
  #
  # ⚠ EVERY ROW HERE IS A DISPLAY-ARM ROW and `run_regression.tcl` runs this
  # file on NEITHER of its arms, so a T1 zero exercises none of them.
  #
  # ⚠ THE CACHE SLOT IS SPELLED `anedit,tran1` AND NOT `anedit,tran` SINCE ISSUE
  # 1448, AND THAT IS THE FEATURE AND NOT A TYPO. ⚖ R5 keyed the cache by TYPE
  # because a type was the only identity a row had; ⚖ R6 gave every row a
  # handle and issue 1448 made two rows of one type reachable, at which point a
  # type-keyed cache would overlay one `dc` row's typing on the other one's
  # form. `tran1` is what `ase::analysis_handle` answers for the seeded tran row
  # (`ase::analysis_seed` -> op dc ac tran, one each), so every GR5/GR6 row
  # below reads the same cache it always did, under the name the user can see.
  # Section GH is where the two-rows-of-a-type case is measured.
  proc r5_open {key} {
    set top [ase::ui::window_for $key]
    # ⚠ A BARE `destroy` AND NOT `chana_cancel`: this is the window manager's
    # close button, the one close path that runs none of our procs. GR5i rests
    # on it.
    catch {destroy $top.chana}
    ase::ui::choose_analyses $key
    update
    return $top.chana
  }
  check "GR5 fixture: a session for the remembering rows" \
    [ase::open_state aselib nfet_clean ngspice_state1] 1
  update
  set top [ase::ui::window_for $key]
  catch {destroy $top.chana}
  # ⚠ THE TWO ROWS ARE PINNED BY HAND, AND THE FIXTURES MUST DISAGREE. `tran`
  # gets `stop 1u` and `ac` gets `stop 1meg` -- two DIFFERENT values under the
  # SAME field name, which is what lets GR5b say the cache is per type rather
  # than per field. `tran` also gets `tmax 2n`, an `advanced 1` field the
  # disclosure hides, which is GR5d's whole subject.
  set R5ST [ase::session_state $key]
  set R5ROWS {}
  foreach r5a [ase::state_get $R5ST analyses] {
    switch -exact -- [ase::state_get $r5a type] {
      tran { lappend R5ROWS [dict create type tran enabled 0 step 1n stop 1u \
                               tmax 2n] }
      ac   { lappend R5ROWS [dict create type ac enabled 0 points 10 start 1 \
                               stop 1meg] }
      default { lappend R5ROWS $r5a }
    }
  }
  dict set R5ST analyses $R5ROWS
  ase::session_update $key $R5ST
  set R5FIX [ase::session_state $key]
  set ::ase::ui::dlg($key,advopen) 0

  ## GR5a -- THE LIVED DEFECT, AS A ROW, WITH ITS OWN POSITIVE CONTROL. The
  ## second term proves the two fixtures DIFFER: a row whose before and after
  ## are equal passes whatever the code does, and this batch has been bitten by
  ## that nine times.
  set gw [r5_open $key]
  $gw.types.tran invoke
  update
  set R5A_BUILT [$gw.form.stop get]
  $gw.form.stop delete 0 end
  $gw.form.stop insert 0 500u
  $gw.types.ac invoke
  update
  set R5A_AC [$gw.form.stop get]
  $gw.types.tran invoke
  update
  check "GR5a typing 500u into tran, clicking the ac cell and clicking back\
 leaves 500u in the box -- and the value the file gave it is not 500u" \
    [list $R5A_BUILT [expr {$R5A_BUILT ne {500u}}] [$gw.form.stop get]] \
    {1u 1 500u}

  ## GR5b -- ONE CACHE PER TYPE. `tran` and `ac` both have a field called
  ## `stop`; a cache keyed by field rather than by type would show tran's 500u
  ## in ac's box and nothing would ever say so.
  check "GR5b the tran edit does not leak into ac's identically named box" \
    [list $R5A_AC [expr {$R5A_AC ne {500u}}]] {1meg 1}

  ## GR5c -- THE OVERLAY MERGES OVER THE STORED ROW. `step` was never touched,
  ## so it is in no cache, and it must still read what the file says. A cache
  ## that REPLACED the row would blank it.
  check "GR5c a field the user never touched keeps the value the file gave it" \
    [$gw.form.step get] 1n

  ## GR5d -- THE ADVANCED-FIELD TRAP, WHICH IS THE SHARPEST WAY TO GET THIS
  ## WRONG. `ase::ui::form_has` is FALSE for a widget that was never built, so
  ## `tmax` is absent from everything the form can report while the disclosure
  ## is closed. An overlay that replaced the stored row with "what is on screen"
  ## would delete it silently -- the form would look exactly right. The first
  ## term proves it really is hidden, which is the fixture control.
  set ::ase::ui::dlg($key,advopen) 0
  set gw [r5_open $key]
  $gw.types.tran invoke
  update
  set R5D_HIDDEN [ase::ui::form_has $key tmax]
  $gw.form.stop delete 0 end
  $gw.form.stop insert 0 500u
  $gw.types.ac invoke
  update
  $gw.types.tran invoke
  update
  set R5D_STOP [$gw.form.stop get]
  ase::ui::chana_adv_toggle $key
  update
  check "GR5d the advanced field the disclosure was hiding survives a round trip\
 through another type -- it really was hidden, and the visible edit really did\
 come back" \
    [list $R5D_HIDDEN $R5D_STOP [ase::ui::form_has $key tmax] \
          [$gw.form.tmax get]] \
    {0 500u 1 2n}

  ## GR5e -- THE SIDE WIN, AND IT WAS A DEFECT NOBODY REPORTED. The
  ## `▸ Advanced` toggle rebuilds through the SAME door a radio click does, so
  ## it discarded the form just as thoroughly; nobody hit it because nobody
  ## thought to type and then toggle. Saving in `chana_show` rather than on the
  ## radiobutton's `-command` is what covers it.
  check "GR5e opening the Advanced disclosure no longer costs the user what was\
 already in the form" [$gw.form.stop get] 500u
  set ::ase::ui::dlg($key,advopen) 0

  ## GR5f -- THE CACHE RECORDS WHAT WAS **TOUCHED**, AND THIS ROW IS ALSO THE
  ## POSITIVE CONTROL ON THE EXTRACTOR: the second term proves it returns
  ## something when it should, so the first term's emptiness is a measurement
  ## and not a broken reader.
  ##
  ## ⚠ THIS IS THE ROW THE FIRST CUT FAILED. Caching every live value of the
  ## outgoing form cached a `step` the user had never typed -- as the empty
  ## string -- and the overlay then DELETED a stored `step 1n`. It reddened
  ## `GN7b`. An untouched field must never enter the cache, which is also what
  ## makes GR5k true.
  set gw [r5_open $key]
  $gw.types.tran invoke
  update
  $gw.types.ac invoke
  update
  set R5F_UNTOUCHED {}
  if {[info exists ::ase::ui::dlg($key,anedit,tran1)]} {
    set R5F_UNTOUCHED $::ase::ui::dlg($key,anedit,tran1)
  }
  $gw.types.tran invoke
  update
  $gw.form.stop delete 0 end
  $gw.form.stop insert 0 500u
  $gw.types.ac invoke
  update
  set R5F_TOUCHED {}
  if {[info exists ::ase::ui::dlg($key,anedit,tran1)]} {
    set R5F_TOUCHED $::ase::ui::dlg($key,anedit,tran1)
  }
  check "GR5f visiting a type caches no key at all; typing into one caches that\
 key and nothing else" [list $R5F_UNTOUCHED $R5F_TOUCHED] [list {} {stop 500u}]

  ## GR5g -- OK COMMITS THE VISIBLE TYPE AND ONLY IT. D4's reason survives the
  ## reversal untouched, and the user did not ask for a multi-type write. The
  ## third term is the positive control that the two values differ.
  set gw [r5_open $key]
  $gw.types.tran invoke
  update
  $gw.form.stop delete 0 end
  $gw.form.stop insert 0 500u
  $gw.types.ac invoke
  update
  $gw.form.stop delete 0 end
  $gw.form.stop insert 0 2meg
  $gw.btns.proceed invoke
  update
  set R5G_TRAN [ase::ui::chana_row $key tran]
  set R5G_AC   [ase::ui::chana_row $key ac]
  check "GR5g OK writes the visible type alone -- the remembered tran edit is\
 NOT written, and the ac edit is" \
    [list [ase::state_get $R5G_AC stop] [ase::state_get $R5G_TRAN stop] \
          [expr {[ase::state_get $R5G_TRAN stop] ne {500u}}]] \
    {2meg 1u 1}

  ## GR5l -- THE SAVE MERGES OVER THE TYPE'S OWN EARLIER CACHE, and this is the
  ## journey that needs it: open `▸ Advanced`, type into `tmax`, close the
  ## disclosure, go to another type, come back, open it again. That is TWO
  ## saves, and the second one can see no `tmax` widget at all -- so a save that
  ## REPLACED the type's cache instead of merging into it would throw the typed
  ## value away at the moment the user folded the section shut.
  set ::ase::ui::dlg($key,advopen) 0
  set gw [r5_open $key]
  $gw.types.tran invoke
  update
  ase::ui::chana_adv_toggle $key
  update
  set R5L_BUILT [$gw.form.tmax get]
  $gw.form.tmax delete 0 end
  $gw.form.tmax insert 0 7n
  ase::ui::chana_adv_toggle $key
  update
  set R5L_HIDDEN [ase::ui::form_has $key tmax]
  $gw.types.ac invoke
  update
  $gw.types.tran invoke
  update
  ase::ui::chana_adv_toggle $key
  update
  check "GR5l a value typed under Advanced survives the disclosure being folded\
 shut and a trip through another type -- and the file's own value is not 7n" \
    [list $R5L_BUILT [expr {$R5L_BUILT ne {7n}}] $R5L_HIDDEN \
          [$gw.form.tmax get]] \
    {2n 1 0 7n}
  set ::ase::ui::dlg($key,advopen) 0

  ## GR5h -- CANCEL DISCARDS EVERYTHING, INCLUDING WHAT WAS REMEMBERED. The
  ## cache is the dialog's memory and not the bench's.
  ##
  ## ⚠ THE `ac` CLICK IS LOAD-BEARING AND IT WAS ADDED AFTER THE FIRST CUT.
  ## `chana_cache_save` runs on a REBUILD, so typing and cancelling straight
  ## away leaves the cache empty -- and a row whose before and after are equal
  ## passes whatever the code does. The click forces the save, `R5H_CACHED` is
  ## the positive control that it happened, and `R5H_LEFT` is what reddens if
  ## `chana_cancel` stops clearing.
  ase::session_update $key $R5FIX
  set gw [r5_open $key]
  $gw.types.tran invoke
  update
  $gw.form.stop delete 0 end
  $gw.form.stop insert 0 500u
  $gw.types.ac invoke
  update
  set R5H_CACHED \
    [expr {[llength [array names ::ase::ui::dlg $key,anedit,tran1]] > 0}]
  $gw.btns.cancel invoke
  update
  set R5H_LEFT [lsort [array names ::ase::ui::dlg $key,anedit,*]]
  set gw [r5_open $key]
  $gw.types.tran invoke
  update
  check "GR5h a dialog dismissed with Cancel remembers nothing: the cache really\
 had something in it, Cancel emptied it, and the reopened dialog starts from\
 the file" [list $R5H_CACHED $R5H_LEFT [$gw.form.stop get]] [list 1 {} 1u]

  ## GR5i -- AND SO DOES A BARE DESTROY. The window manager's close button runs
  ## none of our close paths, so `chana_cancel`'s clear cannot be the only one:
  ## `R5I_SURVIVED` measures that the cache is STILL STANDING after the destroy,
  ## which is exactly why `choose_analyses` clears on every open. Without that
  ## clear the reopened dialog shows 500u and this row reds while GR5h does not.
  $gw.form.stop delete 0 end
  $gw.form.stop insert 0 500u
  $gw.types.ac invoke
  update
  set R5I_CACHED \
    [expr {[llength [array names ::ase::ui::dlg $key,anedit,tran1]] > 0}]
  destroy $gw
  update
  set R5I_SURVIVED \
    [expr {[llength [array names ::ase::ui::dlg $key,anedit,tran1]] > 0}]
  set gw [r5_open $key]
  $gw.types.tran invoke
  update
  check "GR5i a dialog closed by the window manager -- no Cancel, no OK -- leaves\
 nothing behind either, and the clear that does it is the one on OPEN" \
    [list $R5I_CACHED $R5I_SURVIVED [$gw.form.stop get]] [list 1 1 1u]

  ## GR5j -- THE Enable BOX IS PART OF WHAT A TYPE'S FORM REMEMBERS, and
  ## remembering it still writes nothing. The last term is the one that says the
  ## bench is untouched.
  set gw [r5_open $key]
  $gw.types.tran invoke
  update
  set R5J_BEFORE $::ase::ui::dlg($key,anen)
  $gw.enable invoke
  update
  $gw.types.ac invoke
  update
  set R5J_AC $::ase::ui::dlg($key,anen)
  $gw.types.tran invoke
  update
  check "GR5j the Enable box is remembered per type, and remembering it writes\
 nothing to the bench" \
    [list $R5J_BEFORE $R5J_AC $::ase::ui::dlg($key,anen) \
          [ase::state_get [ase::ui::chana_row $key tran] enabled]] \
    {0 0 1 0}
  $gw.btns.cancel invoke
  update

  ## GR5k -- THE BYTE-IDENTITY ROW, AND IT IS THE HARDEST CONSTRAINT IN THIS
  ## BATCH. 104 committed `.state` files round-trip byte-identically because
  ## `ase::ui::form_is_absent` stops a form writing a key no bench carries
  ## (`uic 0`, `sweep dec`). A cache that re-supplied a value the user never
  ## typed would defeat that the first time somebody browsed the grid. This row
  ## clicks all eleven cells and presses OK, and asks for the SAME BYTES.
  ##
  ## ⚠ OK IS PRESSED ON `op`, WHICH THE BENCH ALREADY CARRIES. Pressing it on
  ## a type with no stored row APPENDS a disabled row -- that is the shipped
  ## behaviour of the commit door and it is not what this row is about.
  ase::session_update $key $R5FIX
  set R5K_BEFORE [ase::state_serialize [ase::session_state $key]]
  set gw [r5_open $key]
  foreach r5c [lsort [winfo children $gw.types]] {
    $r5c invoke
    update
  }
  $gw.types.op invoke
  update
  $gw.btns.proceed invoke
  update
  check "GR5k clicking every cell in the grid and pressing OK writes the same\
 bytes as never opening the dialog" \
    [ase::state_serialize [ase::session_state $key]] $R5K_BEFORE

  # --- GR6: OK WRITES WHAT THE DIALOG REMEMBERED -- ISSUE 1446, OPTION B -----
  # ⚖ R5 (GR5, above) made the form REMEMBER. It did not change what OK READS,
  # and `ase::ui::chana_ok` read the LIVE widgets: a value typed under
  # `▸ Advanced` and then folded away has no widget left to read, because
  # `chana_adv_toggle` rebuilds through `chana_show` and `chana_show` does
  # `destroy $w.form`. So the dialog remembered it -- unfold and it is there --
  # and OK dropped it in silence. Option B of issue 1446 is
  # `ase::ui::chana_commit_vals`: the visible type's live widgets merged over
  # THAT type's cache. Same type, same row, one write.
  #
  # ⚠ GR6e IS THE D4 GUARD AND IT IS THE REASON THIS SET EXISTS AT ALL.
  # `doc/claude/ase_l_batch/prompts/item07_dialogs.md`'s D4 reason -- *"no
  # hidden multi-type writes"* -- is what ⚖ R5 was careful to preserve, and
  # widening the reader is exactly how it would get spent by accident. GR6e
  # presses OK with ANOTHER type's edit sitting in the cache and asks for every
  # other row of the bench back byte for byte.
  #
  # ⚠ AND `ase::ui::form_is_absent` STILL DECIDES WHAT IS WRITTEN -- GR6b and
  # GR6c. A merged value goes through the identical test a live one does, which
  # is what keeps the 104 committed `.state` files round-tripping; GR6f asks
  # that question from the GUI side, as GR5k does for ⚖ R5.
  #
  # ⚠ EVERY ROW HERE IS A DISPLAY-ARM ROW, like GR5's.
  proc r6_type {key type} {
    # A radio click ends in `chana_show`, and so does this: the radiobuttons'
    # `-variable` IS `dlg($key,antype)`. Setting it directly is how GN7b reaches
    # a type too, and it does not depend on whether the cell is clickable --
    # a DISABLED radiobutton's `invoke` is a silent no-op.
    set ::ase::ui::dlg($key,antype) $type
    ase::ui::chana_show $key
    update
  }
  # THE GR6 BENCH: GR5's, plus a `noise` row. `noise`'s `ptssum` is the one
  # `advanced 1` field in the registry that DECLARES A DEFAULT, and the
  # declared-default arm of `ase::ui::form_is_absent` is the arm the byte
  # identity of the 104 committed `.state` files rests on. Every row stays
  # `enabled 0`: D6 validation is the commit door's other half and it is not
  # this section's subject.
  ase::session_update $key $R5FIX
  set R6ST [ase::session_state $key]
  set R6ROWS {}
  set R6HASNOISE 0
  foreach r6a [ase::state_get $R6ST analyses] {
    if {[ase::state_get $r6a type] eq {noise}} {
      set R6HASNOISE 1
      lappend R6ROWS [dict create type noise enabled 0 out v(out) insrc V1 \
                        points 10 start 1 stop 1meg]
    } else {
      lappend R6ROWS $r6a
    }
  }
  if {!$R6HASNOISE} {
    lappend R6ROWS [dict create type noise enabled 0 out v(out) insrc V1 \
                      points 10 start 1 stop 1meg]
  }
  dict set R6ST analyses $R6ROWS
  ase::session_update $key $R6ST
  set R6FIX [ase::session_state $key]
  check "GR6 fixture: the bench carries a noise row, whose ptssum is advanced\
 AND declares a default" \
    [list [ase::state_get [ase::ui::chana_row $key noise] type] \
          [dict exists [ase::field_descriptor ngspice noise ptssum] default] \
          [dict get [ase::field_descriptor ngspice noise ptssum] advanced]] \
    {noise 1 1}

  ## GR6a -- THE ROW THE ISSUE WAS FILED FOR. Type into an advanced field, fold
  ## the disclosure shut, press OK: the key is WRITTEN. Terms 1-3 are the
  ## fixture controls -- the file's own `tmax` is not `7n` (a row whose before
  ## and after agree cannot fail) and the widget really is gone by the time OK
  ## is pressed. Term 5 is the visible field, which must still be written the
  ## way it always was.
  ase::session_update $key $R6FIX
  set ::ase::ui::dlg($key,advopen) 0
  set gw [r5_open $key]
  r6_type $key tran
  ase::ui::chana_adv_toggle $key
  update
  set R6A_BUILT [$gw.form.tmax get]
  $gw.form.tmax delete 0 end
  $gw.form.tmax insert 0 7n
  ase::ui::chana_adv_toggle $key
  update
  set R6A_HIDDEN [ase::ui::form_has $key tmax]
  $gw.btns.proceed invoke
  update
  set R6A_ROW [ase::ui::chana_row $key tran]
  check "GR6a a value typed under Advanced and then folded away is WRITTEN by\
 OK -- the widget really was gone, and the file's own value was not 7n" \
    [list $R6A_BUILT [expr {$R6A_BUILT ne {7n}}] $R6A_HIDDEN \
          [ase::state_get $R6A_ROW tmax] [ase::state_get $R6A_ROW stop]] \
    {2n 1 0 7n 1u}

  ## GR6b -- TRAP 1: A MERGED VALUE GOES THROUGH `ase::ui::form_is_absent`
  ## EXACTLY AS A LIVE ONE DOES. `noise`'s `ptssum` is `advanced 1 default 1`,
  ## so typing `1` and folding it away must write NO KEY -- `uic 0` and
  ## `sweep dec` are the two measured cases of the same rule, and it is what the
  ## 104-file round trip rests on.
  ##
  ## ⚠ THE SECOND JOURNEY IS THE POSITIVE CONTROL AND IT IS NOT DECORATION.
  ## "No key" is also what a merge that never happened produces. The same
  ## journey with `2` -- not the declared default -- must write `ptssum 2`, so
  ## the two halves together say the merge ran AND the filter ran.
  ase::session_update $key $R6FIX
  set ::ase::ui::dlg($key,advopen) 0
  set gw [r5_open $key]
  r6_type $key noise
  ase::ui::chana_adv_toggle $key
  update
  set R6B_BUILT [$gw.form.ptssum get]
  $gw.form.ptssum delete 0 end
  $gw.form.ptssum insert 0 1
  ase::ui::chana_adv_toggle $key
  update
  $gw.btns.proceed invoke
  update
  set R6B_DEF [ase::ui::chana_row $key noise]
  ase::session_update $key $R6FIX
  set ::ase::ui::dlg($key,advopen) 0
  set gw [r5_open $key]
  r6_type $key noise
  ase::ui::chana_adv_toggle $key
  update
  $gw.form.ptssum delete 0 end
  $gw.form.ptssum insert 0 2
  ase::ui::chana_adv_toggle $key
  update
  $gw.btns.proceed invoke
  update
  set R6B_OTHER [ase::ui::chana_row $key noise]
  check "GR6b a folded value equal to the field's DECLARED DEFAULT writes no\
 key, and the same journey with a non-default value writes one" \
    [list $R6B_BUILT [dict exists $R6B_DEF ptssum] \
          [dict exists $R6B_OTHER ptssum] [ase::state_get $R6B_OTHER ptssum]] \
    {{} 0 1 2}

  ## GR6c -- AND THE EMPTY ARM OF THE SAME RULE. Clearing an advanced field and
  ## folding it away DELETES the stored key, because an empty value is absent
  ## whatever it arrived through. Term 2 is the control that the cache really
  ## carried the emptiness -- an edit that never reached the cache would leave
  ## the stored `2n` standing and this row would pass on nothing at all.
  ase::session_update $key $R6FIX
  set ::ase::ui::dlg($key,advopen) 0
  set gw [r5_open $key]
  r6_type $key tran
  ase::ui::chana_adv_toggle $key
  update
  $gw.form.tmax delete 0 end
  ase::ui::chana_adv_toggle $key
  update
  set R6C_CACHED {}
  if {[info exists ::ase::ui::dlg($key,anedit,tran1)]} {
    set R6C_CACHED $::ase::ui::dlg($key,anedit,tran1)
  }
  $gw.btns.proceed invoke
  update
  set R6C_ROW [ase::ui::chana_row $key tran]
  check "GR6c clearing an advanced field and folding it away deletes the stored\
 key -- the cache carried the emptiness and the filter spent it" \
    [list [dict exists [ase::ui::chana_row $key ac] stop] $R6C_CACHED \
          [dict exists $R6C_ROW tmax] [ase::state_get $R6C_ROW step]] \
    [list 1 {tmax {}} 0 1n]

  ## GR6d -- THE LIVE WIDGET WINS. Typed, folded, unfolded, RETYPED: the user
  ## may have done all four, and the cache is only ever as new as the last
  ## rebuild while a standing widget is as new as the last keystroke. Term 1 is
  ## the control that the first value really did survive the fold, so an
  ## inverted precedence has something to be wrong about.
  ase::session_update $key $R6FIX
  set ::ase::ui::dlg($key,advopen) 0
  set gw [r5_open $key]
  r6_type $key tran
  ase::ui::chana_adv_toggle $key
  update
  $gw.form.tmax delete 0 end
  $gw.form.tmax insert 0 7n
  ase::ui::chana_adv_toggle $key
  update
  ase::ui::chana_adv_toggle $key
  update
  set R6D_REMEMBERED [$gw.form.tmax get]
  $gw.form.tmax delete 0 end
  $gw.form.tmax insert 0 9n
  $gw.btns.proceed invoke
  update
  check "GR6d typed, folded, unfolded, retyped: the live widget wins over the\
 cache -- and the cache really did carry the first value" \
    [list $R6D_REMEMBERED [expr {$R6D_REMEMBERED ne {9n}}] \
          [ase::state_get [ase::ui::chana_row $key tran] tmax]] \
    {7n 1 9n}

  ## GR6e -- ONE OK WRITES ONE TYPE, AND THIS IS THE D4 GUARD. The remembered
  ## `tran` edit is sitting in the cache, fully available to the commit door,
  ## and OK on `ac` must not spend it. Term 1 is the positive control that it
  ## was there; term 3 asks for EVERY OTHER ROW of the bench back byte for byte,
  ## so a reader widened to "every cached type" reddens here and not merely on
  ## the one field a narrower row happened to name.
  ase::session_update $key $R6FIX
  set ::ase::ui::dlg($key,advopen) 0
  set gw [r5_open $key]
  r6_type $key tran
  ase::ui::chana_adv_toggle $key
  update
  $gw.form.tmax delete 0 end
  $gw.form.tmax insert 0 7n
  ase::ui::chana_adv_toggle $key
  update
  r6_type $key ac
  set R6E_OTHERS {}
  foreach r6b [ase::state_get [ase::session_state $key] analyses] {
    if {[ase::state_get $r6b type] ne {ac}} { lappend R6E_OTHERS $r6b }
  }
  set R6E_CACHED {}
  if {[info exists ::ase::ui::dlg($key,anedit,tran1)]} {
    set R6E_CACHED $::ase::ui::dlg($key,anedit,tran1)
  }
  $gw.form.stop delete 0 end
  $gw.form.stop insert 0 2meg
  $gw.btns.proceed invoke
  update
  set R6E_AFTER {}
  foreach r6b [ase::state_get [ase::session_state $key] analyses] {
    if {[ase::state_get $r6b type] ne {ac}} { lappend R6E_AFTER $r6b }
  }
  set R6E_AC [ase::ui::chana_row $key ac]
  check "GR6e one OK writes ONE type: the folded tran edit is cached and\
 available, the ac row is written, no other type's field lands in it, and every\
 other row of the bench comes back byte for byte" \
    [list $R6E_CACHED [ase::state_get $R6E_AC stop] \
          [dict exists $R6E_AC tmax] [expr {$R6E_AFTER eq $R6E_OTHERS}]] \
    [list {tmax 7n} 2meg 0 1]

  ## GR6f -- THE BYTE-IDENTITY ROW FOR THE NEW READER: GR5k with the disclosure
  ## in it. Click every cell, fold `▸ Advanced` open and shut on each one, press
  ## OK on `op`, and ask for the same bytes. The merge must add NOTHING, because
  ## the cache holds only what was TOUCHED and nothing here was -- that is
  ## GR5f's rule seen from the commit door, and it is what stops this change
  ## writing `uic 0` and `ptssum 1` into 104 benches that carry neither.
  ##
  ## ⚠ OK IS PRESSED ON `ac`, NOT ON GR5k's `op`, AND THAT IS A SABOTAGE
  ## FINDING. `op` has no fields at all, so `chana_ok` writes nothing whatever
  ## the reader answers and this row passed under EVERY mutation -- *a row that
  ## cannot fail proves nothing.* `ac` carries `sweep`, a `mode` field whose
  ## `default dec` the form RESOLVES at build time (a blank picker beside a deck
  ## line that says `dec` is the window disagreeing with the file), so the form
  ## offers a value no bench stores. It is one of the two measured cases in the
  ## write-back rule's own comment, and with `ase::ui::form_is_absent` bypassed
  ## this row goes red on `sweep dec`.
  ##
  ## ⚠ AND `ac` ALREADY HAS A STORED ROW, which is the half of GR5k's note that
  ## still applies: pressing OK on a type with no row appends a disabled one,
  ## which is the shipped behaviour of the commit door and not this row's
  ## subject.
  ase::session_update $key $R6FIX
  set R6F_BEFORE [ase::state_serialize [ase::session_state $key]]
  set ::ase::ui::dlg($key,advopen) 0
  set gw [r5_open $key]
  foreach r6c [lsort [winfo children $gw.types]] {
    $r6c invoke
    update
    ase::ui::chana_adv_toggle $key
    update
    ase::ui::chana_adv_toggle $key
    update
  }
  $gw.types.ac invoke
  update
  $gw.btns.proceed invoke
  update
  check "GR6f clicking every cell, folding Advanced open and shut on each one\
 and pressing OK writes the same bytes as never opening the dialog" \
    [ase::state_serialize [ase::session_state $key]] $R6F_BEFORE
  set ::ase::ui::dlg($key,advopen) 0

  ## GR6g -- THE Enable BOX IS THE LIVE ONE, AND THE CACHE'S COPY MAY NOT WIN.
  ## `chana_cache_save` stores `enabled` beside the fields, because the box the
  ## user ticked belongs to the form it was ticked on (GR5j). `chana_ok` owns
  ## that key itself, from the LIVE `anen` -- so `chana_commit_vals` answers in
  ## FIELDS and the cached copy never reaches the write loop. Without that the
  ## journey below ends with a bench that says ON while the box the user is
  ## looking at says OFF: tick Enable, fold the disclosure (which caches
  ## `enabled 1`), untick it, press OK.
  ase::session_update $key $R6FIX
  set ::ase::ui::dlg($key,advopen) 0
  set gw [r5_open $key]
  r6_type $key tran
  $gw.enable invoke
  update
  set R6G_TICKED $::ase::ui::dlg($key,anen)
  ase::ui::chana_adv_toggle $key
  update
  set R6G_CACHED {}
  if {[info exists ::ase::ui::dlg($key,anedit,tran1)]} {
    set R6G_CACHED $::ase::ui::dlg($key,anedit,tran1)
  }
  $gw.enable invoke
  update
  # ⚠ READ `anen` BEFORE OK, NOT AFTER. `chana_ok` ends in `chana_cancel`, which
  # `array unset`s it -- reading it afterwards raises `no such element in array`
  # INSIDE the block's catch, which kills the file at that row and loses every
  # row after it rather than reddening one. Measured, this row's first cut.
  set R6G_UNTICKED $::ase::ui::dlg($key,anen)
  $gw.btns.proceed invoke
  update
  check "GR6g the cache's copy of Enable never reaches the row: the box really\
 was ticked, the fold really did cache it, and OK writes what the box says NOW" \
    [list $R6G_TICKED [expr {[dict exists $R6G_CACHED enabled] \
                             ? [dict get $R6G_CACHED enabled] : {NONE}}] \
          $R6G_UNTICKED \
          [ase::state_get [ase::ui::chana_row $key tran] enabled]] \
    {1 1 0 0}

  ## GR6h -- THE RESIDUAL, MEASURED RATHER THAN ASSUMED. The PRECONDITION
  ## BANNER's reader `ase::ui::chana_merged_row` (issue 1435) was deliberately
  ## left reading the live form alone, so while a folded edit sits in the cache
  ## the banner judges the STORED value and OK writes the REMEMBERED one. It
  ## changes no sentence today -- no `needs` rule in the ngspice adapter reads
  ## an `advanced 1` field -- and it was left out of scope because issue 1446 is
  ## a change to the commit door that the user has not yet ruled on. This row
  ## pins the divergence so that closing it is a deliberate act with a red row
  ## to point at rather than a surprise.
  ase::session_update $key $R6FIX
  set ::ase::ui::dlg($key,advopen) 0
  set gw [r5_open $key]
  r6_type $key tran
  ase::ui::chana_adv_toggle $key
  update
  $gw.form.tmax delete 0 end
  $gw.form.tmax insert 0 7n
  ase::ui::chana_adv_toggle $key
  update
  set R6H_MERGED [ase::ui::chana_merged_row $key tran]
  set R6H_COMMIT [ase::ui::chana_commit_vals $key tran [ase::ui::chana_sim $key]]
  check "GR6h KNOWN RESIDUAL (issue 1446): with a folded edit remembered, the\
 banner's merged row still reads the STORED value while the commit reader reads\
 the remembered one" \
    [list [ase::state_get $R6H_MERGED tmax] \
          [expr {[dict exists $R6H_COMMIT tmax] \
                 ? [dict get $R6H_COMMIT tmax] : {NONE}}]] \
    {2n 7n}
  $gw.btns.cancel invoke
  update

  # --- GH: THE HANDLE IS VISIBLE, AND THE SECOND ROW OF A TYPE IS REACHABLE --
  # ⚖ R6's GUI half (issue 1448), closing two of issue 1444's three surfaces.
  #
  # ⚠ THE LOAD-BEARING ROW IS GH3 AND IT IS NOT A DISPLAY FEATURE. Before this,
  # `ase::ui::chana_row` returned the FIRST row of a type and
  # `ase::ui::pane_dblclick` threw the index away, so a bench that said "sweep
  # VIN, **and also** sweep temperature" -- the bench ⚖ R6 was ruled to make
  # possible -- had a second `dc` row that could be deleted from the pane and
  # never edited: every door opened the first one. `DECISIONS.md` ⚖ R6 records
  # it from the other side and calls it "the work".
  #
  # ⚠ AND THE CACHE MOVED WITH IT. ⚖ R5's per-dialog edit cache was keyed by
  # TYPE because a type was the only identity a row had. The moment two rows of
  # a type are reachable, a type-keyed cache overlays one row's typing on the
  # other row's form and OK writes it. GH6 is that sentence as a row; the key is
  # now `ase::analysis_handle`'s answer (`ase::ui::chana_cache_key`).
  #
  # ⚠ NOTHING HERE ASSEMBLES A HANDLE. `ase::analysis_handles` is the one
  # speller (issue 1447) and GH11 is the row that says so, on a bench whose
  # first `dc` row declares `id vinsweep` -- the ONE fixture where a locally
  # minted `<type><n>` would disagree with the real answer instead of
  # accidentally matching it.
  #
  # ⚠ EVERY ROW HERE IS A DISPLAY-ARM ROW, like GR5's and GR6's.
  proc gh_open {key {idx {}}} {
    set top [ase::ui::window_for $key]
    catch {destroy $top.chana}
    ase::ui::choose_analyses $key {} $idx
    update
    return $top.chana
  }
  proc gh_col {gw col} {
    set out {}
    foreach it [$gw.rows children {}] { lappend out [$gw.rows set $it $col] }
    return $out
  }

  ## THE BENCH: FIVE ROWS, TWO OF THEM `dc`, AND THE TWO `dc` ROWS DISAGREE.
  ## `V2 0 1.8 0.01` against `TEMP -40 125 5` -- a voltage sweep and a
  ## temperature sweep, which is the user's own example and the reason ⚖ R6 was
  ## ruled. A fixture whose two rows of a type were equal would pass whatever
  ## the addressing did, which is this batch's failure mode #1 and has bitten it
  ## eleven times.
  ##
  ## ⚠ THE `ac` ROW STORES NO `sweep`, DELIBERATELY. The form resolves the
  ## declared default `dec` and `ase::ui::form_is_absent` then writes no key, so
  ## GH15 can press OK on a type that HAS fields (GR6f's correction to GR5k's
  ## `op`, which has none and therefore cannot notice a broken reader).
  set GHROWS [list \
    {type op enabled 1} \
    {type dc enabled 1 source V2 start 0 stop 1.8 step 0.01} \
    {type ac enabled 0 points 10 start 1 stop 1meg} \
    {type tran enabled 0 step 1n stop 1u} \
    {type dc enabled 0 source TEMP start -40 stop 125 step 5}]
  set GHIDROWS [lreplace $GHROWS 1 1 \
    {type dc enabled 0 source V2 start 0 stop 1.8 step 0.01 id vinsweep}]
  set GHIDONROWS [lreplace $GHROWS 1 1 \
    {type dc enabled 1 source V2 start 0 stop 1.8 step 0.01 id vinsweep}]
  set GHST [ase::session_state $key]
  dict set GHST analyses $GHROWS
  ase::session_update $key $GHST
  ase::ui::populate $key
  set GHFIX [ase::session_state $key]
  set ::ase::ui::dlg($key,advopen) 0
  set top [ase::ui::window_for $key]

  ## GH1 -- THE HANDLE COLUMN EXISTS AND IT IS THE HANDLE, NOT THE INDEX. The
  ## item ids ARE the indices (the pane convention), so the third and fourth
  ## terms are the control: a column rendering the index would still be five
  ## values and would still look like a column.
  set gw [gh_open $key]
  set GH1H [gh_col $gw handle]
  set GH1I [$gw.rows children {}]
  check "GH1 the Choose Analyses handle grid renders one line per analysis row\
 with the HANDLE in its first column -- and the handles are not the indices" \
    [list [llength $GH1I] $GH1H $GH1I [expr {$GH1H ne $GH1I}]] \
    [list 5 {op1 dc1 ac1 tran1 dc2} {0 1 2 3 4} 1]

  ## GH2 -- AND THE OTHER THREE COLUMNS ARE `ase::analysis_handle_fields`'s
  ## ANSWER, FOR A DISABLED ROW TOO. Compared BOTH to the proc and to a literal
  ## golden (the W1t discipline): a constant compared to a constant cannot fail.
  set GH2F [ase::analysis_handle_fields ngspice $GHFIX 4]
  set GH2ROW [list [$gw.rows set 4 handle] [$gw.rows set 4 type] \
                   [$gw.rows set 4 enable] [$gw.rows set 4 args]]
  set GH2EXP [list [dict get $GH2F handle] [dict get $GH2F type] \
                   [ase::ui::chk_glyph [dict get $GH2F enabled]] \
                   [dict get $GH2F args]]
  check "GH2 the grid's Type, Enable and Arguments columns are the fields proc's\
 answer -- the switched-off row is listed, with the pane's own off glyph" \
    [list $GH2ROW [expr {$GH2ROW eq $GH2EXP}] [$gw.rows set 1 enable]] \
    [list [list dc2 DC "☐" {TEMP -40 125 5}] 1 "☑"]

  ## GH3 -- ⚠ THE ROW THIS WHOLE TASK EXISTS FOR. Picking the SECOND `dc` line
  ## builds the form from the SECOND `dc` row. Before issue 1448 both lines --
  ## and both doors into this dialog -- opened `dc1`, and the third term is the
  ## control that the two rows really do disagree.
  $gw.rows selection set [list 1]
  update
  set GH3A [$gw.form.source get]
  $gw.rows selection set [list 4]
  update
  set GH3B [$gw.form.source get]
  check "GH3 picking the second dc line in the handle grid builds the form from\
 the SECOND dc row, and the two rows really do differ" \
    [list $GH3A $GH3B [expr {$GH3A ne $GH3B}] [ase::ui::chana_row_idx $key dc]] \
    {V2 TEMP 1 4}

  ## GH4 -- THE TYPE CELL DOES NOT RESET THE ADDRESSING, and the grid's
  ## highlight follows the form. Clicking away to `ac` and back to `dc` has to
  ## return to `dc2`: a type cell that silently jumped to the first row would
  ## put the user back on the row they had just navigated away from.
  $gw.types.ac invoke
  update
  set GH4AC [$gw.rows selection]
  $gw.types.dc invoke
  update
  check "GH4 clicking away to the ac cell and back to dc returns to dc2, and the\
 grid's highlight tracks the form both times" \
    [list $GH4AC [$gw.rows selection] [$gw.form.source get] \
          [ase::ui::chana_row_idx $key dc]] \
    {2 4 TEMP 4}
  $gw.btns.cancel invoke
  update

  ## GH4b -- THE PANE'S CONTEXT `Edit…` DOOR. It reads the pane selection and
  ## called `choose_analyses` with the row's TYPE only; its own header said the
  ## dialog "addresses the first row of that type" and that extras "remain
  ## X-deletable", which is a fair description of a row that can be deleted and
  ## not edited.
  set atv $top.body.ana.tv
  $atv selection set [list 4]
  update
  ase::ui::edit_analysis_first $key
  update
  set gw $top.chana
  check "GH4b the pane's context Edit… on the fifth analyses row opens Choose\
 Analyses on dc2, not on dc1" \
    [list $::ase::ui::dlg($key,antype) [ase::ui::chana_row_idx $key dc] \
          [$gw.form.source get] [$gw.rows selection]] \
    {dc 4 TEMP 4}
  $gw.btns.cancel invoke
  update

  ## GH4c -- AND THE DOUBLE-CLICK DOOR, driven at real coordinates off the
  ## pane's own bbox. The first term is the control that the bbox resolved: a
  ## row that could not find the cell would otherwise pass by calling
  ## `pane_dblclick` with coordinates that identify nothing, which returns
  ## early and opens no dialog at all.
  catch {destroy $top.chana}
  set GH4CBB [$atv bbox 4]
  if {$GH4CBB ne {}} {
    ase::ui::pane_dblclick $key ana [expr {[lindex $GH4CBB 0] + 2}] \
      [expr {[lindex $GH4CBB 1] + 2}]
    update
  }
  set gw $top.chana
  check "GH4c double-clicking the fifth analyses row opens the dialog on dc2 --\
 the index the pane had and the dialog used to throw away" \
    [list [expr {$GH4CBB ne {}}] [winfo exists $gw] \
          [ase::ui::chana_row_idx $key dc] [$gw.form.source get]] \
    {1 1 4 TEMP}
  $gw.btns.cancel invoke
  update

  ## GH5 -- OK WRITES THE ADDRESSED ROW AND LEAVES EVERY OTHER ROW BYTE FOR
  ## BYTE. Both commit doors walked to the first row of the type; on this bench
  ## an edit to `dc2` landed on `dc1` and silently changed the voltage sweep.
  ase::session_update $key $GHFIX
  set gw [gh_open $key 4]
  $gw.form.stop delete 0 end
  $gw.form.stop insert 0 77
  $gw.btns.proceed invoke
  update
  set GH5ROWS [ase::state_get [ase::session_state $key] analyses]
  check "GH5 OK writes the ADDRESSED dc row: dc2 takes the new stop, dc1 is\
 untouched, every other row comes back byte for byte, and 77 was not already\
 anybody's value" \
    [list [ase::state_get [lindex $GH5ROWS 4] stop] \
          [expr {[lindex $GH5ROWS 1] eq [lindex $GHROWS 1]}] \
          [expr {[lreplace $GH5ROWS 4 4] eq [lreplace $GHROWS 4 4]}] \
          [expr {[ase::state_get [lindex $GHROWS 4] stop] ne {77}}]] \
    {77 1 1 1}

  ## GH6 -- ⚠ THE CACHE IS PER ROW, NOT PER TYPE, AND THIS IS THE DESIGN
  ## QUESTION THE SCHEMA HALF DID NOT SETTLE. ⚖ R5 keyed it by type; with two
  ## `dc` rows reachable that overlays `dc1`'s typing on `dc2`'s form, and the
  ## user is then looking at a temperature sweep wearing a voltage sweep's
  ## numbers. The second term is the control that the two stored values differ.
  ase::session_update $key $GHFIX
  set gw [gh_open $key 1]
  set GH6A [$gw.form.stop get]
  $gw.form.stop delete 0 end
  $gw.form.stop insert 0 9.9
  $gw.rows selection set [list 4]
  update
  set GH6B [$gw.form.stop get]
  $gw.rows selection set [list 1]
  update
  check "GH6 an edit to dc1 does not surface on dc2's identically named box, and\
 coming back to dc1 finds it still there" \
    [list $GH6A $GH6B [expr {$GH6A ne $GH6B}] [$gw.form.stop get]] \
    {1.8 125 1 9.9}
  $gw.btns.cancel invoke
  update

  ## GH7 -- AND THE COMMIT READER MOVED WITH IT (issue 1446 under addressing).
  ## A value typed under `▸ Advanced` and folded away has no widget left to
  ## read, so OK reads the cache -- which must be the ADDRESSED row's cache. The
  ## row is switched off, so the D6 group rule (`second sweep` is all-or-none)
  ## does not arise; what is being measured is WHICH row the value lands on.
  ase::session_update $key $GHFIX
  set ::ase::ui::dlg($key,advopen) 0
  set gw [gh_open $key 4]
  ase::ui::chana_adv_toggle $key
  update
  set GH7HAD [ase::ui::form_has $key step2]
  $gw.form.step2 delete 0 end
  $gw.form.step2 insert 0 7
  ase::ui::chana_adv_toggle $key
  update
  set GH7GONE [ase::ui::form_has $key step2]
  $gw.btns.proceed invoke
  update
  set GH7ROWS [ase::state_get [ase::session_state $key] analyses]
  check "GH7 a folded-away Advanced edit is committed to the row the dialog was\
 addressing -- it really was on screen, it really was gone at OK, dc2 has it and\
 dc1 does not" \
    [list $GH7HAD $GH7GONE [ase::state_get [lindex $GH7ROWS 4] step2] \
          [dict exists [lindex $GH7ROWS 1] step2]] \
    {1 0 7 0}
  set ::ase::ui::dlg($key,advopen) 0

  ## GH8 -- `Analyses > List` (issue 1444 surface 3). The body is
  ## `ase::analysis_handle_text` and nothing else, EVERY row is listed, and the
  ## switched-off ones are marked. 1444 asked for "the enabled analyses"; issue
  ## 1447's C-R6-1 corrected it, because a measurement bound to a switched-off
  ## row REFUSES and the reader's next question is which one is off.
  ase::session_update $key $GHFIX
  catch {destroy $top.anlist}
  set GH8W [ase::ui::analyses_list $key]
  update
  set GH8TXT [$GH8W.t get 1.0 end-1c]
  set GH8OFF 0
  foreach gh8l [split $GH8TXT "\n"] {
    if {[string match {*(off)} $gh8l]} { incr GH8OFF }
  }
  check "GH8 Analyses > List dumps one line per analysis row -- every row, not\
 only the enabled ones -- with the three switched-off rows marked" \
    [list [llength [split $GH8TXT "\n"]] $GH8OFF \
          [expr {$GH8TXT eq [ase::analysis_handle_text ngspice \
                              [ase::session_state $key]]}] \
          [lindex [split [lindex [split $GH8TXT "\n"] 4]] 0]] \
    {5 3 1 dc2}

  ## GH9 -- THE MENU ENTRY IS REAL AND IT IS THE DOOR. Driven through the actual
  ## cascade rather than by calling the proc, which is the only way to notice an
  ## entry that was never added.
  set GH9L {}
  for {set gh9i 0} {$gh9i <= [$top.mb.analyses index end]} {incr gh9i} {
    lappend GH9L [$top.mb.analyses entrycget $gh9i -label]
  }
  catch {destroy $top.anlist}
  ## ⚠ THE INVOKE AND EVERY READ OF THE WINDOW ARE CAUGHT, WHICH IS G2tf's
  ## LESSON AND NOT CAUTION. The one change this row exists to catch -- the menu
  ## entry never added -- makes `invoke 1` a bad index and `$top.anlist.t` an
  ## invalid command name; both raise into the display block's outer catch,
  ## which kills the FILE at this row and loses every row after it instead of
  ## reddening one. Measured on sabotage s12.
  catch {$top.mb.analyses invoke 1}
  update
  set GH9OPEN 0
  set GH9SAME 0
  if {[winfo exists $top.anlist.t]} {
    set GH9OPEN 1
    set GH9SAME [expr {[$top.anlist.t get 1.0 end-1c] eq $GH8TXT}]
  }
  check "GH9 the Analyses cascade carries List beside Choose…, and invoking it\
 opens the list window" \
    [list $GH9L $GH9OPEN $GH9SAME] \
    [list [list "Choose…" List] 1 1]

  ## GH10 -- IT IS A VIEWER: read-only, and the text is selectable so it can be
  ## COPIED, which is the whole reason issue 1444 kept this surface (the
  ## calculator has nothing to pick from).
  set GH10 {ABSENT ABSENT ABSENT}
  if {[winfo exists $top.anlist.t]} {
    set GH10 [list [$top.anlist.t cget -state] [$top.anlist.t cget -wrap] \
                   [winfo class $top.anlist.t]]
  }
  check "GH10 the list window is read-only machine text, not an editor" \
    $GH10 {disabled none Text}

  ## GH11 -- ⚠ ONE SPELLER, THREE RENDERINGS, ON THE ONE BENCH WHERE A LOCAL
  ## MINT WOULD DISAGREE. Every other fixture in this file would let a surface
  ## that assembled `<type><n>` itself pass by accident, because that IS the
  ## derived scheme. Here the first `dc` row declares `id vinsweep`, so the real
  ## answer is `{op1 vinsweep ac1 tran1 dc1}` and a local mint says
  ## `{op1 dc1 ac1 tran1 dc2}` -- the fourth term is that control.
  set GHIDST [ase::session_state $key]
  dict set GHIDST analyses $GHIDROWS
  ase::session_update $key $GHIDST
  ase::ui::populate $key
  set GHIDFIX [ase::session_state $key]
  catch {destroy $top.anlist}
  set gw [gh_open $key]
  ase::ui::analyses_list $key
  update
  set GH11L {}
  foreach gh11l [split [$top.anlist.t get 1.0 end-1c] "\n"] {
    lappend GH11L [lindex [split $gh11l] 0]
  }
  check "GH11 the handle grid, the first column of Analyses > List and\
 ase::analysis_handles are one answer rendered three times -- and a declared id\
 is what a locally minted <type><n> would have got wrong" \
    [list [gh_col $gw handle] $GH11L [ase::analysis_handles $GHIDFIX] \
          [expr {[ase::analysis_handles $GHIDFIX] ne \
                 {op1 dc1 ac1 tran1 dc2}}]] \
    [list {op1 vinsweep ac1 tran1 dc1} {op1 vinsweep ac1 tran1 dc1} \
          {op1 vinsweep ac1 tran1 dc1} 1]

  ## GH12 -- EDITING A ROW DOES NOT COST IT ITS NAME. `id` is an open-dict key
  ## the form knows nothing about, and `ase::ui::chana_ok` merges over the
  ## original row -- so the identity survives, and the handle with it.
  $gw.rows selection set [list 1]
  update
  $gw.form.stop delete 0 end
  $gw.form.stop insert 0 2.5
  $gw.btns.proceed invoke
  update
  set GH12ROWS [ase::state_get [ase::session_state $key] analyses]
  check "GH12 committing an edit to a row that declares an id keeps the id, and\
 the handle the user was told to type still names the same row" \
    [list [ase::state_get [lindex $GH12ROWS 1] id] \
          [ase::state_get [lindex $GH12ROWS 1] stop] \
          [ase::analysis_handles [ase::session_state $key]] \
          [ase::analysis_by_handle [ase::session_state $key] vinsweep]] \
    [list vinsweep 2.5 {op1 vinsweep ac1 tran1 dc1} {dc 1}]

  ## GH13 -- WHAT THE COMMIT DOOR ACTUALLY SEES, MEASURED RATHER THAN ASSUMED.
  ## `ase::ui::chana_ok`'s D6 probe is built from `vals` -- the FORM's declared
  ## fields -- so a row key the form knows nothing about never reaches
  ## `ase::analysis_emit_check` at all. An enabled row that declares an `id`
  ## therefore commits and closes, and the identity survives the write. This row
  ## was first written the other way round, expecting a refusal; the dialog
  ## disagreed and the dialog was right.
  set GHIDONST [ase::session_state $key]
  dict set GHIDONST analyses $GHIDONROWS
  ase::session_update $key $GHIDONST
  set gw [gh_open $key 1]
  set GH13EN $::ase::ui::dlg($key,anen)
  $gw.form.stop delete 0 end
  $gw.form.stop insert 0 3.3
  $gw.btns.proceed invoke
  update
  set GH13ROWS [ase::state_get [ase::session_state $key] analyses]
  check "GH13 the commit door judges the FORM's fields, so the id key is not\
 something it can refuse: an ENABLED row that declares one commits, closes and\
 keeps its name" \
    [list $GH13EN [winfo exists $top.chana] \
          [ase::state_get [lindex $GH13ROWS 1] id] \
          [ase::state_get [lindex $GH13ROWS 1] stop] \
          [ase::state_get [lindex $GH13ROWS 1] enabled]] \
    {1 0 vinsweep 3.3 1}

  ## GH13b -- AND THE BENCH RUNS. ⚠ THIS ROW USED TO PIN THE DEFECT AND NOW PINS
  ## ITS ABSENCE (issues 1448 -> 1449, rewritten under 1450).
  ##
  ## WHAT IT ASSERTED BEFORE: `{unknownkey id emit_incomplete {}}`. The surface
  ## GH ships tells a user to name their analyses, and
  ## `ase::analysis_emit_check`'s allow-list was `{type enabled x}` plus the
  ## declared field names -- ⚖ R6 added `id` to the ROW and not to that list. So
  ## `ase::preflight_gate`, which runs that check over every ENABLED stored row,
  ## refused the whole bench: no deck, no raw, no log, and `set ase_preflight 0`
  ## leaves that check in force. Naming an analysis and switching it on stopped the
  ## bench running. The row was written to go RED when that was fixed, and it
  ## did: issue 1449 landed the one word and this file's display arm went to
  ## 2 FAILED (338 passed).
  ##
  ## WHAT IT ASSERTS NOW: the gate is SILENT on a bench whose enabled row
  ## declares a name, that row still renders its analysis card, and the identical
  ## bench without the key behaves the same way.
  ##
  ## ⚠ THE PAIRED CONTROL IS KEPT AND A THIRD STATE IS ADDED, BECAUSE THE PAIR
  ## NO LONGER DISAGREES. Under the defect `GH13G` and `GH13GN` answered
  ## differently and that difference WAS the row. Now both answer `{}`, so a
  ## gate that had stopped running at all would satisfy both terms: `GH13BAD` is
  ## the same row plus a key nothing can spend, and it must still be refused.
  ## Terms 6 and 7 are the other half -- the two fixtures disagree about their
  ## own HANDLE (`vinsweep` against `dc1`), which says the `id` is doing ⚖ R6's
  ## job rather than sitting there ignored.
  ##
  ## ⚠ THE STATE IS HAND-BUILT AND PAIRED. Run through the session's own bench
  ## the gate has other things to refuse about (output names it cannot find in
  ## a fixture netlist), and a row that accepted ANY refusal would be measuring
  ## the wrong one.
  set GH13ROW {type dc enabled 1 source V2 start 0 stop 1.8 step 0.01 id vinsweep}
  set GH13ST [dict create version 1 simulator ngspice \
                design {lib aselib cell nfet_clean view ngspice_state1} \
                analyses [list $GH13ROW]]
  set GH13NOID $GH13ST
  dict set GH13NOID analyses [list [dict remove $GH13ROW id]]
  set GH13BAD $GH13ST
  dict set GH13BAD analyses [list [dict merge $GH13ROW {nonsense 1}]]
  set GH13G   [ase::preflight_gate $GH13ST   "* netlist\n.end\n"]
  set GH13GN  [ase::preflight_gate $GH13NOID "* netlist\n.end\n"]
  set GH13GB  [ase::preflight_gate $GH13BAD  "* netlist\n.end\n"]
  check "GH13b an analysis the user has NAMED and switched on lets the bench run:\
 the gate is silent, the row still renders its card, and a key nothing can spend\
 on the same row is still refused" \
    [list [ase::analysis_emit_check ngspice $GH13ROW] \
          [lindex $GH13G 0] $GH13GN \
          [ase::analysis_line ngspice $GH13ROW] \
          [lindex $GH13GB 0] \
          [ase::analysis_handles $GH13ST] \
          [ase::analysis_handles $GH13NOID]] \
    [list {} {} {} {dc V2 0 1.8 0.01} emit_incomplete vinsweep dc1]

  ## GH14 -- AN EMPTY BENCH SAYS SO. A window that opened blank would read as a
  ## broken one; the sentence is `ase::ui::lbl_no_analyses`, minted in the lbl_*
  ## family so it cannot drift from wherever it is shown. The second term is the
  ## control that this is not simply the same text as a full bench's.
  set GH14ST [ase::session_state $key]
  dict set GH14ST analyses {}
  ase::session_update $key $GH14ST
  catch {destroy $top.anlist}
  ase::ui::analyses_list $key
  update
  set GH14T {ABSENT}
  if {[winfo exists $top.anlist.t]} { set GH14T [$top.anlist.t get 1.0 end-1c] }
  check "GH14 Analyses > List on a bench with no analyses says so instead of\
 opening blank" [list $GH14T [expr {$GH14T ne $GH8TXT}]] \
    [list {No analyses on this bench.} 1]
  catch {destroy $top.anlist}

  ## GH15 -- THE BYTE-IDENTITY ROW, WITH ADDRESSING LIVE. GR5k asked it of the
  ## type grid and GR6f of the disclosure; this asks it of the handle grid,
  ## which is the new way to move between rows. Clicking every line of it and
  ## every cell of the type grid and then pressing OK must write the SAME BYTES
  ## as never opening the dialog -- the 104-file constraint from the GUI side.
  ##
  ## ⚠ OK IS PRESSED ON `ac`, NOT ON `op`. `op` has no fields at all, so
  ## `chana_ok` writes nothing whatever the reader answers and the row cannot
  ## fail; `ac`'s `sweep` is a `mode` field the form resolves to its declared
  ## default `dec`, a value no bench stores. That is GR6f's correction to GR5k
  ## and it is inherited here rather than re-learned.
  ase::session_update $key $GHFIX
  set GH15BEFORE [ase::state_serialize [ase::session_state $key]]
  set gw [gh_open $key]
  foreach gh15i [$gw.rows children {}] {
    $gw.rows selection set [list $gh15i]
    update
  }
  foreach gh15c [lsort [winfo children $gw.types]] {
    $gh15c invoke
    update
  }
  $gw.types.ac invoke
  update
  $gw.btns.proceed invoke
  update
  check "GH15 clicking every line of the handle grid and every cell of the type\
 grid and then pressing OK writes the same bytes as never opening the dialog" \
    [ase::state_serialize [ase::session_state $key]] $GH15BEFORE


  # --- NX: ONE LIST OF NON-SETTING KEYS -- THE `Options...` HALF -------------
  # Issue 1450. `DECISIONS.md` D4 licenses exactly two optional per-row keys,
  # `id` (⚖ R6's handle) and `x` (issue 1419's verbatim hatch). THREE places kept
  # a list of "keys on an analysis row that are not settings" and the three
  # disagreed: `ase::analysis_emit_check` knew both, while THIS subdialog's
  # reader (`ase::ui::chana_options`) and writer (`ase::ui::chana_x_ok`) each
  # knew `type enabled` and the declared fields.
  #
  # ⚠ MEASURED ON THE UNFIXED TREE, THROUGH THESE VERY WIDGETS. One `dc` row
  # carrying both keys: the subdialog listed `{id vinsweep}` and `{x {{echo hi}}}`
  # as free-text NAME/VALUE pairs, and OK then answered `ase: this dc analysis
  # has a setting named 'id' that ASE-L cannot emit` and returned -- subdialog
  # left standing, nothing written. The editor could not be opened-and-saved on
  # such a row at all, and the one gesture that DID get an OK out of it was
  # deleting the name. `x` had been in that state since issue 1419.
  #
  # ⚠ AND THE WRITER'S STRIP WAS THE SHARPER HALF. Its `foreach k [dict keys
  # $row]` loop deletes every key not in `skip` before writing back, so a `skip`
  # that had never heard of `id` would have DESTROYED the handle on any commit
  # that got past the refusal. NX6 is that sentence as a byte-identity row.
  #
  # ⚠ EVERY ROW HERE DRIVES THE REAL SUBDIALOG. The pure-Tcl half -- the proc
  # itself and the guard against a FOURTH copy appearing in the source -- is
  # test_ase_core section NS, which runs on both arms.
  proc nx_open {key idx} {
    set top [ase::ui::window_for $key]
    catch {destroy $top.chana}
    ase::ui::choose_analyses $key {} $idx
    update
    $top.chana.opts invoke
    update
    return $top.chana.x
  }
  proc nx_pairs {xw} {
    set out {}
    if {![winfo exists $xw.tv]} { return NOSUBDIALOG }
    foreach it [$xw.tv children {}] {
      lappend out [list [$xw.tv set $it name] [$xw.tv set $it value]]
    }
    return $out
  }

  ## THE BENCH: the addressed row carries BOTH D4 keys. The `x` value is a real
  ## one-line verbatim list, not a placeholder -- `ase::analysis_verbatim`
  ## answers it.
  ##
  ## ⚠ AND THE TWO KEYS ARE NOT EQUALLY VISIBLE ELSEWHERE, WHICH IS WHY HIDING
  ## THEM HERE IS A RULING AND NOT AN EDIT. Measured on this row:
  ##   handle grid, Handle column          : vinsweep
  ##   Analyses > List                     : vinsweep  DC  V2 0 1.8 0.01
  ##   handle grid, Arguments column       : V2 0 1.8 0.01      <- no hatch
  ##   main window Analyses pane           : dc V2 0 1.8 0.01  + verbatim: 1 line
  ## So `id` is on screen twice inside the very dialog whose button opens this
  ## subdialog, while `x` is mentioned only in the MAIN WINDOW's pane -- the
  ## grid's Arguments column is `ase::analysis_line`'s answer (`ase.tcl`
  ## analysis_handle_fields) and not `ase::ui::arg_summary`'s, so it never
  ## carries the `+ verbatim` clause. Filed as ⚖ R9 on issue 1450.
  set NXROW {type dc enabled 0 source V2 start 0 stop 1.8 step 0.01 id vinsweep x {{echo hi}}}
  set NXBENCH [list {type op enabled 1} $NXROW {type ac enabled 0 points 10 start 1 stop 1meg}]
  proc nx_bench {key rows} {
    set st [ase::session_state $key]
    dict set st analyses $rows
    ase::session_update $key $st
    ase::ui::populate $key
    update
  }
  nx_bench $key $NXBENCH

  ## NX1 -- THE READER. ⚠ THE SECOND TERM IS THE CONTROL AND IT IS WHY THIS ROW
  ## IS NOT "the list is empty". A bench written by an older ASE-L, or edited by
  ## hand, really can carry a key nothing can spend, and the editor's whole job
  ## is to SHOW that one. So the fixture carries three extra keys -- the two D4
  ## keys and one genuine stray -- and exactly the stray is listed. A reader that
  ## hid everything would pass a row that only asked for `{}`.
  set NX1XW [nx_open $key 1]
  set NX1A [nx_pairs $NX1XW]
  catch {destroy $top.chana}
  nx_bench $key [list {type op enabled 1} [dict merge $NXROW {legacykey 7}]]
  set NX1XW [nx_open $key 1]
  set NX1B [nx_pairs $NX1XW]
  catch {destroy $top.chana}
  nx_bench $key $NXBENCH
  check "NX1 the Options editor no longer lists a row's name or its verbatim\
 lines as free-text settings, and still lists a key that really is a stray" \
    [list $NX1A $NX1B] [list {} {{legacykey 7}}]

  ## NX2 -- THE WRITER. OK COMMITS AND SAYS NOTHING. Under the defect this press
  ## returned early with an error-tagged sentence and the subdialog still up;
  ## the third term counts the sentences, because "it committed" and "it
  ## committed silently" are different claims (issue 0635's subject).
  set NX2XW [nx_open $key 1]
  d_echo_arm
  $NX2XW.btns.proceed invoke
  update
  set NX2SAID [d_echoed_n {*cannot emit*}]
  d_echo_disarm
  set NX2ROWS [ase::state_get [ase::session_state $key] analyses]
  check "NX2 OK on a row that carries a name and a verbatim hatch commits, closes\
 and says nothing -- and the row keeps both keys" \
    [list [winfo exists $NX2XW] $NX2SAID [lindex $NX2ROWS 1]] \
    [list 0 0 $NXROW]
  catch {destroy $top.chana}
  nx_bench $key $NXBENCH

  ## NX3 -- ⚠ THE DOOR IS STILL SHUT, WHICH IS THE ONLY WAY THIS FIX CAN BE
  ## WRONG. Issue 1418 closed a door: a name no template can spend is refused at
  ## `Add` and again at OK, because `anextra` is seeded from the STORED row and
  ## writing it straight back would launder a stray through a door that refuses
  ## it at the front. Teaching the list about D4's two keys must not teach it to
  ## shrug. The fixture is the SAME row plus one stray, so the refusal cannot
  ## come from anything else -- and the refusal must name the STRAY.
  nx_bench $key [list {type op enabled 1} [dict merge $NXROW {legacykey 7}]]
  set NX3XW [nx_open $key 1]
  d_echo_arm
  $NX3XW.btns.proceed invoke
  update
  set NX3SAID {}
  foreach nx3e $::d_echo {
    if {[string first {cannot emit} [lindex $nx3e 1]] >= 0} { set NX3SAID [lindex $nx3e 1] }
  }
  d_echo_disarm
  check "NX3 a key nothing can spend is still refused at OK on the very row that\
 carries the name and the hatch, and the refusal names that key" \
    [list [winfo exists $NX3XW] $NX3SAID \
          [expr {[string first {'id'} $NX3SAID] < 0}] \
          [expr {[string first {'x'} $NX3SAID] < 0}]] \
    [list 1 "ase: this dc analysis [ase::analysis_emit_msg unknownkey legacykey]" 1 1]
  catch {destroy $top.chana}
  nx_bench $key $NXBENCH

  ## NX4 -- AND `Add` HAS NOT BECOME A BACK DOOR TO THE HANDLE. The two D4 keys
  ## are not settings, so they are not things this editor sets: `id` is written
  ## by ⚖ R6's own surfaces and `x` is the hatch. Typing either into the
  ## NAME/VALUE pair is refused exactly as before the fix, and the stored row is
  ## untouched. ⚠ WITHOUT THIS ROW "hide them from the list" and "let the list
  ## edit them" are indistinguishable.
  set NX4XW [nx_open $key 1]
  d_echo_arm
  $NX4XW.row.name  delete 0 end ; $NX4XW.row.name  insert 0 id
  $NX4XW.row.value delete 0 end ; $NX4XW.row.value insert 0 hijacked
  $NX4XW.row.add invoke
  update
  set NX4N [d_echoed_n {*cannot emit*}]
  d_echo_disarm
  set NX4P [nx_pairs $NX4XW]
  $NX4XW.btns.proceed invoke
  update
  set NX4ROWS [ase::state_get [ase::session_state $key] analyses]
  check "NX4 typing the handle key into the Options name/value pair is still\
 refused, the pair is not added, and the row's own name is unharmed" \
    [list $NX4N $NX4P [ase::state_get [lindex $NX4ROWS 1] id]] \
    [list 1 {} vinsweep]
  catch {destroy $top.chana}
  nx_bench $key $NXBENCH

  ## NX5 -- ⚠ BOTH SITES *ASK*, THEY DO NOT COPY, AND THIS IS THE ROW THAT SAYS
  ## SO. Every row above is satisfied by two sites that happen to hold the right
  ## literal today, which is exactly the state this issue found the tree in --
  ## each of the three was right about itself. Stub the one proc NARROWER and the
  ## defect must come back through both doors at once: the reader lists the two
  ## keys again and the writer refuses. A site holding its own list would not
  ## move.
  rename ase::analysis_nonsetting_keys ase::analysis_nonsetting_keys_nxsaved
  proc ase::analysis_nonsetting_keys {} { return {type enabled} }
  set NX5XW [nx_open $key 1]
  set NX5P [nx_pairs $NX5XW]
  d_echo_arm
  $NX5XW.btns.proceed invoke
  update
  set NX5N [d_echoed_n {*cannot emit*}]
  d_echo_disarm
  set NX5UP [winfo exists $NX5XW]
  rename ase::analysis_nonsetting_keys {}
  rename ase::analysis_nonsetting_keys_nxsaved ase::analysis_nonsetting_keys
  catch {destroy $top.chana}
  nx_bench $key $NXBENCH
  check "NX5 the Options reader and the Options writer both ASK the schema which\
 keys are not settings: narrowing the one proc brings the defect back through\
 both doors, and restoring it takes it away again" \
    [list $NX5P $NX5N $NX5UP \
          [nx_pairs [nx_open $key 1]]] \
    [list {{id vinsweep} {x {{echo hi}}}} 1 1 {}]
  catch {destroy $top.chana}

  ## NX6 -- THE BYTE-IDENTITY ROW, FROM THE `Options...` SIDE. GH15 asked it of
  ## the handle grid; this asks it of the subdialog, and it is the row the
  ## writer's strip loop would have failed: `foreach k [dict keys $row]` deletes
  ## every key not in `skip`, so a `skip` without `id` and `x` DESTROYS both on
  ## the way past. The 104-file constraint does not care that the refusal
  ## happened to fire first.
  ##
  ## ⚠ THE SECOND TERM IS THE NON-VACUITY CONTROL. A serialize that answered the
  ## same bytes for every bench would satisfy the first term for ever; the same
  ## bench with the name removed must serialize DIFFERENTLY.
  nx_bench $key $NXBENCH
  set NX6BEFORE [ase::state_serialize [ase::session_state $key]]
  set NX6XW [nx_open $key 1]
  $NX6XW.btns.proceed invoke
  update
  set NX6AFTER [ase::state_serialize [ase::session_state $key]]
  set NX6ST [ase::session_state $key]
  dict set NX6ST analyses [list {type op enabled 1} [dict remove $NXROW id] \
                                {type ac enabled 0 points 10 start 1 stop 1meg}]
  check "NX6 opening Options on a row that carries a name and a verbatim hatch\
 and pressing OK writes the same bytes as never opening it" \
    [list [expr {$NX6AFTER eq $NX6BEFORE}] \
          [expr {[ase::state_serialize $NX6ST] ne $NX6BEFORE}]] \
    [list 1 1]
  catch {destroy $top.chana}
  ase::session_update $key $GHFIX
  ase::ui::populate $key
  update

  # --- MS: THE MEASUREMENTS SUB-DIALOG (issue 1451, PLAN.md §8b) -------------
  #
  # Issue 1443 shipped the whole DECK half of Stage 8 -- a `measurements` state
  # list, eighteen kinds, a four-verdict refusal evaluator, the `meas` speller,
  # the producers and the sidecar -- and BUILT NO WIDGET. Nothing read a kind's
  # `label`, `ase::meas_report` had no caller anywhere in the tree, and a user
  # could not create one measurement row without hand-editing a `.state` file.
  # These rows are that surface.
  #
  # ⚠ THE LOAD-BEARING ROW IS MS15 AND IT IS ONE EXPRESSION FROM END TO END:
  # a row CREATED IN THE DIALOG, committed, rendered into a deck, and read back
  # into a Value cell from the sidecar text a real run wrote. Issue 1449 is why:
  # the `id` key passed 622 checks and a clean T1 because one suite's fixtures
  # declared ids and never enabled anything while another's enabled things and
  # never declared an id, and the defect lived in the seam. Two halves of a
  # feature tested in different suites never meet.
  #
  # ⚠ MS9 IS `R9-325`'s LAYOUT CONSTRAINT AS A MEASUREMENT. `reaches` is the
  # only LOWERCASE field label in the tree -- it is the second half of the
  # sentence `When signal <v(out)> reaches <0.9>` -- and it reads correctly only
  # if the form puts both on ONE line. The rule is keyed on the copy's own shape
  # (a lowercase label continues the row above it), so it needs no per-simulator
  # knowledge, and MS9's control is that an ordinary label is NOT inlined.
  #
  # ⚠ THE VALUE COLUMN IS THE SIMULATOR'S PRINTED TEXT, VERBATIM. Measured on
  # both binaries: apt 45.2 prints `9.149274e+05` where the fork prints
  # `9.14927e+05` for the same measurement. MS10 asserts both spellings survive
  # untouched, because a golden that keyed on digit count would pass on one
  # binary and fail on the other.
  #
  # ⚠ EVERY ROW HERE IS A DISPLAY-ARM ROW, like GR5's, GR6's, GH's and NX's.
  proc ms_open {key} {
    set top [ase::ui::window_for $key]
    catch {destroy $top.meas}
    ase::ui::measurements_dialog $key
    update
    return $top.meas
  }
  proc ms_col {mw col} {
    set out {}
    foreach it [$mw.rows children {}] { lappend out [$mw.rows set $it col_$col] }
    return $out
  }
  proc ms_cells {mw col} {
    set out {}
    foreach it [$mw.rows children {}] { lappend out [$mw.rows set $it $col] }
    return $out
  }
  proc ms_bench {key rows {meas {}}} {
    set st [ase::session_state $key]
    dict set st analyses $rows
    dict set st measurements $meas
    ase::session_update $key $st
    ase::ui::populate $key
    update
  }
  ## the grid row/column a form widget sits in, or `-` when it is not there
  proc ms_grid {w} {
    if {![winfo exists $w]} { return - }
    set gi [grid info $w]
    return [list [dict get $gi -row] [dict get $gi -column]]
  }
  ## write a sidecar with exactly the text a measured run produced
  proc ms_sidecar {key text} {
    set p {}
    if {[catch {ase::meas_path [ase::session_state $key]} p]} { return {} }
    file mkdir [file dirname $p]
    set fh [::open $p w]
    puts -nonewline $fh $text
    close $fh
    return $p
  }
  proc ms_no_sidecar {key} {
    set p {}
    if {[catch {ase::meas_path [ase::session_state $key]} p]} { return }
    catch {file delete -- $p}
  }

  ## THE BENCH: one AC row, one TRAN row and one DISABLED AC row, so the
  ## Analysis dropdown has something to disagree about. ⚠ The `op` row is the
  ## control the dropdown must NEVER offer -- ngspice's `chkAnalysisType()`
  ## accepts only tran/dc/ac/sp.
  set MSROWS [list \
    {type ac enabled 1 sweep dec points 100 start 1 stop 1g} \
    {type tran enabled 1 step 2u stop 3m} \
    {type op enabled 1} \
    {type ac enabled 0 sweep lin points 5 start 1 stop 10}]
  ms_bench $key $MSROWS
  set MSFIX [ase::session_state $key]
  ms_no_sidecar $key

  ## MS1 -- THE DOOR. `Outputs > Measurements…`, and the dialog it opens.
  set MS1MENU [cx {[ase::ui::window_for $key].mb.outputs index [ase::ui::lbl_measurements_menu]}]
  set mw [ms_open $key]
  check "MS1 `Outputs > Measurements…` exists and opens the Measurements dialog\
 with the list, the button bar and the form" \
    [list [expr {$MS1MENU ne {} && ![string match ERR:* $MS1MENU]}] \
          [winfo exists $mw] [winfo exists $mw.rows] [winfo exists $mw.bar.add] \
          [winfo exists $mw.bar.tpl] [winfo exists $mw.form] \
          [$mw.rows cget -columns]] \
    [list 1 1 1 1 1 1 {enable name kind analysis value}]
  $mw.btns.cancel invoke
  update

  ## MS2 -- THE LIST RENDERS THE KIND'S DECLARED **LABEL** AND THE ANALYSIS'S
  ## **HANDLE**. Nothing read a kind `label` before this widget existed. ⚠ The
  ## third term is the control: the kind COLUMN is not the kind token, so a fill
  ## that rendered the raw key would still produce three strings.
  ms_bench $key $MSROWS [list \
    {name gain kind max target vdb(out) analysis ac id ac1} \
    {name tr kind trigtarg trig v(out) targ v(out) analysis tran id tran1} \
    {name off1 kind rms target v(out) analysis tran id tran1 enabled 0}]
  set mw [ms_open $key]
  check "MS2 the list renders one line per measurement: the kind's declared\
 LABEL, the analysis's HANDLE, and the enable glyph" \
    [list [ms_cells $mw name] [ms_cells $mw kind] [ms_cells $mw analysis] \
          [ms_cells $mw enable]] \
    [list {gain tr off1} \
          [list {Maximum} {Delay (TRIG ... TARG)} {RMS}] \
          {ac1 tran1 tran1} \
          [list [ase::ui::chk_glyph 1] [ase::ui::chk_glyph 1] [ase::ui::chk_glyph 0]]]

  ## MS3 -- THE KIND PICKER. All nineteen labels in the catalogue's own order,
  ## and changing it rebuilds the form from the NEW kind's declared fields and
  ## stores the kind token, not the label.
  set MS3V [$mw.form.kind cget -values]
  $mw.form.kind set [ase::meas_kind_label [ase::ui::meas_sim $key] when]
  ase::ui::meas_kind_changed $key
  update
  ## the kind's own field widgets, in the order the descriptor declares them --
  ## `$w.form.f<field>`, which is why the fixed Name/Kind/Analysis controls above
  ## them cannot be mistaken for fields.
  set MS3F {}
  foreach f [ase::meas_kind_fields [ase::ui::meas_sim $key] when] {
    if {[winfo exists $mw.form.f[dict get $f name]]} { lappend MS3F [dict get $f name] }
  }
  check "MS3 the Kind picker offers every declared kind in catalogue order, and\
 picking one rebuilds the form from that kind's own fields" \
    [list [llength $MS3V] [lrange $MS3V 0 1] \
          [ase::state_get [lindex [ase::ui::meas_rows $key] 0] kind] $MS3F] \
    [list 19 [list {Delay (TRIG ... TARG)} {Value at a point}] when \
          {target value dir n td from to}]

  ## MS4 -- ⚖ R6's RULE AT THE ONE PLACE A USER CAN BREAK IT. The dropdown shows
  ## `ase::analysis_handle_line`'s answer -- the same string the Choose Analyses
  ## grid and `Analyses > List` render, `(off)` included -- and picking a line
  ## stores `id <handle>` with the handle's own type beside it and NO `row` key.
  ## ⚠ `op1` is the control: it is enabled and it must not be in the list.
  set MS4V [$mw.form.analysis cget -values]
  $mw.form.analysis set [lindex $MS4V 2]
  ase::ui::meas_an_changed $key
  update
  set MS4R [lindex [ase::ui::meas_rows $key] 0]
  check "MS4 the Analysis dropdown is the one speller's answer, never offers an\
 `op`, and picking a line stores `id <handle>` and never `row <index>`" \
    [list $MS4V [ase::state_get $MS4R id] [ase::state_get $MS4R analysis] \
          [dict exists $MS4R row]] \
    [list [list [ase::analysis_handle_line \
                   [ase::analysis_handle_fields [ase::ui::meas_sim $key] \
                      [ase::session_state $key] 0]] \
                {tran1  TRAN  2u 3m} {ac2  AC  lin 5 1 10  (off)}] \
          ac2 ac 0]
  $mw.btns.cancel invoke
  update

  ## MS5 -- ADD / DELETE / UP / DOWN, and the order REACHES THE DECK. Order is
  ## not cosmetic in this list: a `param` row computing `180 + pmph` must sit
  ## below the row that makes `pmph`, and the block emits rows in stored order.
  ms_bench $key $MSROWS [list \
    {name a kind max target vdb(out) analysis ac id ac1} \
    {name b kind min target vdb(out) analysis ac id ac1}]
  set mw [ms_open $key]
  $mw.rows selection set 1
  update
  ase::ui::meas_move $key -1
  update
  set MS5ORDER [ms_cells $mw name]
  ase::ui::meas_add $key
  update
  $mw.form.name delete 0 end
  $mw.form.name insert 0 c
  set MS5N [llength [ase::ui::meas_rows $key]]
  ase::ui::meas_del $key
  update
  set MS5N2 [llength [ase::ui::meas_rows $key]]
  $mw.btns.proceed invoke
  update
  set MS5DECK {}
  foreach l [split [ase::backend::ngspice::render_deck [ase::session_state $key] \
                     "* t\nv1 out 0 dc 0 ac 1\nr1 out 0 1k\n.end\n"] "\n"] {
    if {[string match {meas *} [string trim $l]]} {
      lappend MS5DECK [lindex [string trim $l] 2]
    }
  }
  check "MS5 Up reorders, Add appends, Delete removes, and the order the list\
 shows is the order the deck emits" \
    [list $MS5ORDER $MS5N $MS5N2 $MS5DECK] \
    [list {b a} 3 2 {b a}]

  ## MS6 -- ⚖ R5's RULING, INHERITED. Type into one row, click another, come
  ## back: what you typed is still there. ⚠ The second term is the control --
  ## the OTHER row is untouched, so a harvest that wrote the live form into
  ## whichever row happened to be selected would fail here rather than pass.
  ms_bench $key $MSROWS [list \
    {name a kind max target vdb(out) analysis ac id ac1} \
    {name b kind min target vdb(in) analysis ac id ac1}]
  set mw [ms_open $key]
  $mw.form.ftarget delete 0 end
  $mw.form.ftarget insert 0 vdb(mid)
  $mw.rows selection set 1
  update
  set MS6B [ase::state_get [lindex [ase::ui::meas_rows $key] 1] target]
  $mw.rows selection set 0
  update
  check "MS6 the form REMEMBERS: typing into one row and clicking another keeps\
 it, and the other row is untouched" \
    [list [$mw.form.ftarget get] $MS6B \
          [ase::state_get [lindex [ase::ui::meas_rows $key] 0] target]] \
    [list {vdb(mid)} {vdb(in)} {vdb(mid)}]

  ## MS7 -- OK WRITES THE LIST; CANCEL WRITES NOTHING.
  set MS7BEFORE [ase::state_serialize [ase::session_state $key]]
  $mw.btns.cancel invoke
  update
  set MS7CANCEL [ase::state_serialize [ase::session_state $key]]
  set mw [ms_open $key]
  $mw.form.ftarget delete 0 end
  $mw.form.ftarget insert 0 vdb(mid)
  $mw.btns.proceed invoke
  update
  check "MS7 Cancel writes nothing and OK writes the whole list" \
    [list [expr {$MS7CANCEL eq $MS7BEFORE}] \
          [ase::state_get [lindex [ase::state_get [ase::session_state $key] measurements] 0] target] \
          [winfo exists [ase::ui::window_for $key].meas]] \
    [list 1 {vdb(mid)} 0]

  ## MS8 -- THE TEMPLATE PICKER, AND IT IS THE ONE THAT PROVES THE FEATURE.
  ## Pick `Phase margin`, name the output, OK: THREE ordinary measurement rows,
  ## every one bound by handle, and the last one reading the phase the second one
  ## measures. ⚠ `let pm = 180 + pmph` is the term that matters: the plan writes
  ## both rows as `pm` and ASE-L refuses a duplicate name outright, so a
  ## per-row uniquifier would have renamed the measured phase and left the margin
  ## reading a vector that no longer exists.
  ms_bench $key $MSROWS {}
  set mw [ms_open $key]
  set tw [ase::ui::meas_tpl_dialog $key]
  update
  set MS8V [$tw.pick cget -values]
  $tw.pick set {Phase margin}
  ase::ui::meas_tpl_show $key
  update
  set MS8AN [$tw.form.an cget -values]
  $tw.form.out insert 0 out
  $tw.btns.proceed invoke
  update
  set MS8ROWS [ase::ui::meas_rows $key]
  check "MS8 the template picker offers §8b's eight by name, filters the Analysis\
 dropdown to the type the template reads, and writes ordinary rows that refer to\
 each other" \
    [list $MS8V $MS8AN [lmap r $MS8ROWS {ase::meas_name $r}] \
          [lsort -unique [lmap r $MS8ROWS {ase::state_get $r id}]] \
          [ase::state_get [lindex $MS8ROWS 2] expr] \
          [llength [lsearch -all -inline [lmap r $MS8ROWS {dict exists $r row}] 1]]] \
    [list [list {DC gain} {-3 dB bandwidth} {Unity-gain frequency} {Phase margin} \
                {Gain margin} {Slew rate} {Settling time} {THD}] \
          [list {ac1  AC  dec 100 1 1g} {ac2  AC  lin 5 1 10  (off)}] \
          {ugf pmph pm} ac1 {180 + pmph} 0]

  ## MS9 -- ⚠ `R9-325`'s LAYOUT CONSTRAINT. `When signal` and `reaches` on ONE
  ## line, because `reaches` is the only lowercase label in the tree and a
  ## right-aligned label column turns it into a stray lowercase word under its
  ## neighbour. The rule is keyed on the COPY's own shape; the last two terms
  ## are the control that an ordinary label is NOT inlined.
  $mw.rows selection set 1
  update
  set MS9WHEN  [ms_grid $mw.form.lfwhen]
  set MS9VAL   [ms_grid $mw.form.lfvalue]
  set MS9TARG  [ms_grid $mw.form.lftarget]
  check "MS9 the form puts `When signal` and `reaches` on one line, and an\
 ordinary label still starts its own" \
    [list [lindex $MS9WHEN 0] [lindex $MS9WHEN 1] \
          [lindex $MS9VAL 0] [lindex $MS9VAL 1] \
          [expr {[lindex $MS9TARG 0] != [lindex $MS9WHEN 0]}] [lindex $MS9TARG 1] \
          [ase::ui::meas_inline [ase::ui::meas_sim $key] find value] \
          [ase::ui::meas_inline [ase::ui::meas_sim $key] find when]] \
    [list [lindex $MS9WHEN 0] 0 [lindex $MS9WHEN 0] 2 1 0 1 0]

  ## MS10 -- THE VALUE COLUMN. ⚠ THE NUMBER IS THE SIMULATOR'S PRINTED TEXT AND
  ## IS NOT NORMALISED: measured on both binaries, apt 45.2 prints `9.149274e+05`
  ## where the fork prints `9.14927e+05` for the same measurement. And a FAILED
  ## measurement renders its SENTENCE, because an empty cell reads as zero --
  ## which is the one thing the guard cannot see any other way (rc 0,
  ## `$sim_status` 0, no vector, `print` prints nothing).
  ## ⚠ THE BENCH IS SEEDED INTO THE SESSION, not left in the dialog's working
  ## copy: `Measurements…` reads the STORED list on every open, so a row that
  ## only ever existed in a previous dialog would give this row zero lines and
  ## an empty answer it could not tell from a broken Value column.
  ms_bench $key $MSROWS [list \
    {name ugf kind when target vdb(out) value 0 dir fall analysis ac id ac1} \
    {name pmph kind find target vp(out) when vdb(out) value 0 analysis ac id ac1} \
    {name pm kind param expr {180 + pmph} analysis ac id ac1}]
  ms_sidecar $key "ASE-MEAS\nugf                 =  9.149274e+05\npm = 5.614170e+01\n"
  set mw [ms_open $key]
  set MS10APT [ms_cells $mw value]
  $mw.btns.cancel invoke
  update
  ms_sidecar $key "ASE-MEAS\nugf                 =  9.14927e+05\npm = 5.614170e+01\n"
  set mw [ms_open $key]
  set MS10FORK [ms_cells $mw value]
  $mw.btns.cancel invoke
  update
  ms_no_sidecar $key
  set mw [ms_open $key]
  set MS10NONE [ms_cells $mw value]
  ## ⚠ AND THE FOURTH CASE IS THE ONE A NAME-KEYED LOOKUP GETS WRONG. Two rows
  ## may share a name -- `ase::meas_verdict` REFUSES the second, because the
  ## sidecar's lookup is case-insensitive and the second answer would overwrite
  ## the first's -- but the row is still storable and still on screen. The FIRST
  ## row's cell must carry its NUMBER; only the second carries the refusal.
  ms_sidecar $key "ASE-MEAS\nugf                 =  9.149274e+05\npm = 5.614170e+01\n"
  ms_bench $key $MSROWS [list \
    {name ugf kind when target vdb(out) value 0 dir fall analysis ac id ac1} \
    {name ugf kind max target vdb(out) analysis ac id ac1}]
  set mw [ms_open $key]
  set MS10DUP [ms_cells $mw value]
  $mw.btns.cancel invoke
  update
  ms_bench $key $MSROWS [list \
    {name ugf kind when target vdb(out) value 0 dir fall analysis ac id ac1} \
    {name pmph kind find target vp(out) when vdb(out) value 0 analysis ac id ac1} \
    {name pm kind param expr {180 + pmph} analysis ac id ac1}]
  ms_no_sidecar $key
  set mw [ms_open $key]
  check "MS10 the Value column shows each binary's own printed text verbatim, a\
 failed measurement shows its sentence, a bench that has never run shows\
 neither, and a duplicate name does not put the second row's refusal in the\
 first row's cell" \
    [list $MS10APT $MS10FORK $MS10NONE $MS10DUP] \
    [list [list {9.149274e+05} \
                {the simulator did not report this measurement: the condition it asks about may never occur in this run} \
                {5.614170e+01}] \
          [list {9.14927e+05} \
                {the simulator did not report this measurement: the condition it asks about may never occur in this run} \
                {5.614170e+01}] \
          [list {} {} {}] \
          [list {9.149274e+05} \
                "another measurement is already called 'ugf', and the simulator\
 would overwrite the first one's answer with this one's"]]

  ## MS11 -- THE VERDICT SENTENCE, WHICH IS THE EVALUATOR'S OWN AND NOT REWORDED
  ## HERE. ⚖ R6's three handle refusals reach the user through this label; the
  ## fourth term is the control that an `ok` row says NOTHING.
  set MS11R [ase::state_get [ase::session_state $key] measurements]
  lset MS11R 0 [dict replace [lindex $MS11R 0] id nosuch]
  set ::ase::ui::dlg($key,mrows) $MS11R
  set ::ase::ui::dlg($key,msel) 0
  ase::ui::meas_note $key
  set MS11A [$mw.note cget -text]
  lset MS11R 0 [dict replace [lindex $MS11R 0] id ac2]
  set ::ase::ui::dlg($key,mrows) $MS11R
  ase::ui::meas_note $key
  set MS11B [$mw.note cget -text]
  lset MS11R 0 [dict replace [lindex $MS11R 0] id tran1 analysis ac]
  set ::ase::ui::dlg($key,mrows) $MS11R
  ase::ui::meas_note $key
  set MS11C [$mw.note cget -text]
  lset MS11R 0 [dict replace [lindex $MS11R 0] id ac1 analysis ac]
  set ::ase::ui::dlg($key,mrows) $MS11R
  ase::ui::meas_note $key
  check "MS11 the selected row's verdict is the evaluator's own sentence, and an\
 `ok` row says nothing" \
    [list $MS11A $MS11B $MS11C [$mw.note cget -text]] \
    [list "no analysis called 'nosuch' for 'ugf' to read" \
          "the analysis called 'ac2' is switched off, so 'ugf' has nothing to read" \
          "'ugf' names ac but reads 'tran1', which is tran" \
          {}]
  $mw.btns.cancel invoke
  update

  ## MS12 -- `Measured on`. ⚠ NOTHING THE DECK CARRIES MAY BE UNSHOWABLE IN THE
  ## WINDOW, which is this batch's oldest rule and the one §8b is easiest to
  ## break: a row measured on a producer's plot is how a peak is read off a
  ## spectrum rather than off the transient that made it. The control is that a
  ## bench with no producer offers no such control at all.
  ms_bench $key $MSROWS [list \
    {name sp1 kind fft target v(out) analysis tran id tran1} \
    {name pk kind max target v(out) analysis tran id tran1}]
  set mw [ms_open $key]
  $mw.rows selection set 1
  update
  set MS12V [$mw.form.on cget -values]
  $mw.form.on set sp1
  ase::ui::meas_harvest $key
  set MS12ON [ase::meas_on [lindex [ase::ui::meas_rows $key] 1]]
  $mw.btns.cancel invoke
  update
  ms_bench $key $MSROWS {{name pk kind max target v(out) analysis tran id tran1}}
  set mw [ms_open $key]
  set MS12NONE [winfo exists $mw.form.on]
  check "MS12 a bench carrying a producer offers `Measured on` and stores it; a\
 bench with none offers no such control" \
    [list $MS12V $MS12ON $MS12NONE] \
    [list [list [ase::ui::lbl_meas_on_own] sp1] sp1 0]

  ## MS13 -- THE ENABLE TRI-STATE, WHICH IS A BYTE-IDENTITY RULE. `enabled 1` is
  ## the ABSENT value, so only the OFF state costs a key -- exactly the
  ## discipline `ase::ui::form_is_absent` states for an analysis field, and what
  ## keeps a bench that never turned a row off byte-identical.
  set ::ase::ui::dlg($key,men) 0
  ase::ui::meas_enable_changed $key
  set MS13OFF [lindex [ase::ui::meas_rows $key] 0]
  set ::ase::ui::dlg($key,men) 1
  ase::ui::meas_enable_changed $key
  set MS13ON [lindex [ase::ui::meas_rows $key] 0]
  check "MS13 unticking Enable writes `enabled 0` and re-ticking it removes the\
 key rather than writing `enabled 1`" \
    [list [ase::state_get $MS13OFF enabled NONE] [ase::state_get $MS13ON enabled NONE] \
          [ase::meas_enabled $MS13ON]] \
    [list 0 NONE 1]
  $mw.btns.cancel invoke
  update

  ## MS14 -- THE 104-FILE BYTE-IDENTITY QUESTION, FROM THE GUI SIDE. Open the
  ## dialog on a bench that carries NO measurements, click through every kind the
  ## simulator describes, and press OK: the same bytes. ⚠ `measurements` is in
  ## `ase::omit_if_empty`, so a commit that wrote an empty list -- or a form that
  ## re-supplied a declared default -- would show up here and nowhere else.
  ms_bench $key $MSROWS {}
  set MS14BEFORE [ase::state_serialize [ase::session_state $key]]
  set mw [ms_open $key]
  $mw.btns.proceed invoke
  update
  set MS14EMPTY [ase::state_serialize [ase::session_state $key]]
  set mw [ms_open $key]
  ase::ui::meas_add $key
  update
  foreach k [ase::meas_kind_order [ase::ui::meas_sim $key]] {
    $mw.form.kind set [ase::meas_kind_label [ase::ui::meas_sim $key] $k]
    ase::ui::meas_kind_changed $key
    update
  }
  ase::ui::meas_del $key
  update
  $mw.btns.proceed invoke
  update
  set MS14WALK [ase::state_serialize [ase::session_state $key]]
  ## ⚠ AND THE ROW THAT ACTUALLY COMMITS ONE. The walk above DELETES its row
  ## before pressing OK, so it can say the empty list is not written and nothing
  ## about what a committed row carries -- which is where the byte-identity rule
  ## really bites: a form that answered with a field's DECLARED DEFAULT would
  ## store a key the deck already resolves for itself, and the row would then be
  ## fatter than the one a person would have typed. `when`'s `Edge number`
  ## defaults to 1 and the form shows 1; the stored row must not carry it.
  ## Sabotage s15 is that rule removed, and it SURVIVED the walk above.
  ms_bench $key $MSROWS {}
  set mw [ms_open $key]
  ase::ui::meas_add $key
  update
  $mw.form.kind set [ase::meas_kind_label [ase::ui::meas_sim $key] when]
  ase::ui::meas_kind_changed $key
  update
  $mw.form.name insert 0 d3
  $mw.form.ftarget insert 0 vdb(out)
  $mw.form.fvalue insert 0 -3
  set MS14SHOWN [$mw.form.fn get]
  $mw.btns.proceed invoke
  update
  set MS14DEF [lindex [ase::state_get [ase::session_state $key] measurements] 0]
  set mw [ms_open $key]
  ## ⚠ `Edge number` IS AN ENTRY, NOT A PICKER -- `$w set` raises on one, and the
  ## raise lands inside a check and KILLS THE FILE rather than reddening a row
  ## (measured here: `bad option "set"`, no MS14, no MS15, no MS16, no MS17).
  ## That is G2tf's documented failure shape met again.
  $mw.form.fn delete 0 end
  $mw.form.fn insert 0 2
  $mw.btns.proceed invoke
  update
  set MS14SET [lindex [ase::state_get [ase::session_state $key] measurements] 0]
  check "MS14 opening the dialog on a bench with no measurements, walking every\
 kind and pressing OK writes the same bytes as never opening it -- and a field\
 left at its declared default writes no key while a changed one does" \
    [list [expr {$MS14EMPTY eq $MS14BEFORE}] [expr {$MS14WALK eq $MS14BEFORE}] \
          [string first {measurements} $MS14BEFORE] \
          $MS14SHOWN [ase::state_get $MS14DEF n NONE] \
          [ase::state_get $MS14SET n NONE]] \
    [list 1 1 -1 1 NONE 2]

  ## MS15 -- ⚠ THE END-TO-END ROW, IN ONE EXPRESSION. A measurement CREATED IN
  ## THE DIALOG -- template picker, real widgets, real OK -- must reach a
  ## RENDERED DECK and come back into a Value CELL. Issue 1449 is the scar: the
  ## `id` key passed 622 checks and a clean T1 because one suite's fixtures
  ## declared ids and never enabled anything while another's enabled things and
  ## never declared an id, so the two halves never met.
  ##
  ## ⚠ THE SIDECAR TEXT IS THE ONE A REAL RUN WROTE, on apt 45.2, for exactly
  ## these rows: `pm = 5.614170e+01`. WITHOUT the `set units=degrees` the same
  ## deck answered `pm = 1.778383e+02` on both binaries, at rc 0, with nothing
  ## said -- a 56-degree phase margin reported as 178.
  ms_bench $key $MSROWS {}
  set mw [ms_open $key]
  set tw [ase::ui::meas_tpl_dialog $key]
  update
  $tw.pick set {Phase margin}
  ase::ui::meas_tpl_show $key
  update
  $tw.form.out insert 0 out
  $tw.btns.proceed invoke
  update
  $mw.btns.proceed invoke
  update
  set MS15DECK {}
  foreach l [split [ase::backend::ngspice::render_deck [ase::session_state $key] \
                     "* t\nv1 out 0 dc 0 ac 1\nr1 out 0 1k\n.end\n"] "\n"] {
    set l [string trim $l]
    if {[regexp {^(meas |let pm|set units=degrees)} $l]} {
      lappend MS15DECK [regsub { >>.*$} $l {}]
    }
  }
  ms_sidecar $key "ASE-MEAS\nugf                 =  9.149274e+05\npmph                =  -1.238583e+02\npm = 5.614170e+01\n"
  set mw [ms_open $key]
  set MS15VAL [ms_cells $mw value]
  check "MS15 a measurement CREATED IN THE DIALOG reaches the rendered deck --\
 with `set units=degrees` above it -- and its number comes back into the Value\
 column" \
    [list $MS15DECK $MS15VAL] \
    [list [list {set units=degrees} {meas ac ugf WHEN vdb(out)=0 FALL=1} \
                {meas ac pmph FIND vp(out) WHEN vdb(out)=0} {let pm = 180 + pmph}] \
          [list {9.149274e+05} {-1.238583e+02} {5.614170e+01}]]
  $mw.btns.cancel invoke
  update

  ## MS16 -- ⚠ A BINDING THE BENCH NO LONGER RESOLVES IS NOT SILENTLY THROWN
  ## AWAY. Delete the analysis a measurement reads and the row still SAYS
  ## `id ac1`; the Analysis picker must show that word, because a picker that
  ## could not would leave the harvest with an empty box and the next selection
  ## change -- or OK -- would strip the binding off a row the user opened the
  ## dialog only to LOOK at. Nothing the deck carries may be unshowable in the
  ## window, and this is the one place in this dialog where that rule bites.
  ##
  ## ⚠ The last two terms are the control: the row's own verdict is the
  ## MISSING-ANALYSIS sentence, not the no-analysis-at-all one, which is what
  ## tells a preserved binding from a stripped one.
  ms_bench $key [list {type tran enabled 1 step 2u stop 3m}] \
    [list {name gain kind max target vdb(out) analysis ac id ac1}]
  set mw [ms_open $key]
  set MS16V [$mw.form.analysis cget -values]
  set MS16SHOWN [$mw.form.analysis get]
  ase::ui::meas_harvest $key
  set MS16ROW [lindex [ase::ui::meas_rows $key] 0]
  $mw.btns.proceed invoke
  update
  set MS16STORED [lindex [ase::state_get [ase::session_state $key] measurements] 0]
  check "MS16 a handle the bench no longer resolves is still offered, still\
 shown, and survives a harvest and an OK -- with the verdict that names it" \
    [list $MS16V $MS16SHOWN [ase::state_get $MS16ROW id] \
          [ase::state_get $MS16STORED id] [ase::state_get $MS16STORED analysis] \
          [lindex [ase::meas_verdict [ase::ui::meas_sim $key] \
                     [ase::session_state $key] $MS16STORED] 1]] \
    [list [list ac1 {tran1  TRAN  2u 3m}] ac1 ac1 ac1 ac \
          "no analysis called 'ac1' for 'gain' to read"]

  ## MS17 -- ESC DISMISSES BOTH NEW TOPLEVELS THROUGH THEIR OWN CANCEL PATH, and
  ## it comes from `ase::ui::dialog_buttons` BY CONSTRUCTION -- the item-10
  ## esc-dismiss set that sections GE1-16 hold for every other dialog in this
  ## file. ⚠ The third and fourth terms are what tells a cancel path from a bare
  ## destroy: the per-window records go with it.
  ms_bench $key $MSROWS {{name a kind max target vdb(out) analysis ac id ac1}}
  set mw [ms_open $key]
  set tw [ase::ui::meas_tpl_dialog $key]
  update
  send_key $tw <Key-Escape> {![winfo exists $tw]}
  set MS17TPL [winfo exists $tw]
  set MS17PARENT [winfo exists $mw]
  send_key $mw <Key-Escape> {![winfo exists $mw]}
  check "MS17 ESC dismisses the template picker without killing its parent,\
 and ESC on the dialog itself dismisses it through Cancel and cleans its\
 records" \
    [list $MS17TPL $MS17PARENT [winfo exists $mw] \
          [info exists ::ase::ui::dlg($key,mrows)] \
          [info exists ::ase::ui::dlg($key,msel)]] \
    [list 0 1 0 0 0]

  ms_no_sidecar $key
  ase::session_update $key $MSFIX
  ase::ui::populate $key
  update

  # --- SP: THE PORTS TABLE AND THE MATRIX PICKER (issue 1454, PLAN.md §9a/§9b)
  #
  # Issue 1452 made a setup table EMIT and built no widget. `ports` was a row key
  # with no surface anywhere: the only way to put a two-port table on a bench was
  # to hand-edit a `.state` file. And the one editor that DID see the key was
  # BROKEN by it -- SP12 is that defect as a row, measured on the unfixed tree
  # through these very widgets:
  #
  #     Options editor lists: {ports {{src v1 num 1 z0 50} {src v2 num 2 z0 50}}}
  #     OK pressed         -> subdialog still up = 1, bytes changed = 0
  #
  # which is issue 1450's defect for the THIRD time, on a key licensed per TYPE
  # rather than per row.
  #
  # ⚠ EVERY COLUMN HEADING, THE NOUN AND THE MINIMUM COME FROM THE REGISTRY, and
  # SP3 is the row that says the dialog ASKS rather than knowing. The schema half
  # is `test_ase_sp_1452.tcl` section SX, which runs on both arms.
  proc sp_open_chana {key idx} {
    set top [ase::ui::window_for $key]
    catch {destroy $top.chana}
    ase::ui::choose_analyses $key {} $idx
    update
    return $top.chana
  }
  ## ⚠ EVERY CELL READ IS CAUGHT, AND A SABOTAGE IS WHY. Measured: a mutation
  ## that made the column reader answer a FIXED list instead of the contract's
  ## left the treeview without a `z0` column, and a bare `$tv set $it z0` raised
  ## `Invalid column index z0` -- the file lost NINETEEN checks to the top-level
  ## catch instead of reddening SP2. G2tf's documented failure shape, met a third
  ## time in this section alone. A missing column now reads `NOCOL`, which is a
  ## value a row can compare.
  ## One heading, or `NOCOL` -- same reason as `sp_tbl`'s caught cells.
  proc sp_head {sw c} {
    set v NOCOL
    catch {set v [$sw.tv heading $c -text]}
    return $v
  }
  ## Type into one entry of the edit row, tolerating a column the contract no
  ## longer declares -- the widget then does not exist, and a bare
  ## `$sw.row.z0 insert` would kill the file instead of reddening a row.
  proc sp_type {sw c v} {
    if {![winfo exists $sw.row.$c]} { return 0 }
    $sw.row.$c delete 0 end
    if {$v ne {}} { $sw.row.$c insert 0 $v }
    return 1
  }
  proc sp_tbl {sw cols} {
    set out {}
    if {![winfo exists $sw.tv]} { return NOTABLE }
    foreach it [$sw.tv children {}] {
      set r {}
      foreach c $cols {
        set v NOCOL
        catch {set v [$sw.tv set $it $c]}
        lappend r $v
      }
      lappend out $r
    }
    return $out
  }
  proc sp_bench {key rows} {
    set st [ase::session_state $key]
    dict set st analyses $rows
    ase::session_update $key $st
    ase::ui::populate $key
    update
  }
  ## ⚠ ONE LINE, AND A CONTINUATION HERE COST A ROW. A backslash-newline inside
  ## a braced fixture leaves a DOUBLE SPACE in the literal, the dialog writes the
  ## dict back normalised, and SP13's byte-identity row then reds on the
  ## fixture's own whitespace rather than on anything the product did.
  ## ⚠ AND THE SECOND ENTRY'S KEYS ARE IN A DIFFERENT ORDER FROM THE COLUMNS,
  ## deliberately. A dialog that rebuilt each entry in column order -- the obvious
  ## tidy-up -- would rewrite a hand-written table's bytes on an OK that changed
  ## nothing, and a fixture whose key order already matched the columns could not
  ## see it. Measured: with both entries in column order the mutation SURVIVED.
  set SPROW {type sp enabled 1 points 3 start 100meg stop 1g ports {{src v1 num 1 z0 50} {z0 50 src v2 num 2}}}
  set SPBENCH [list {type op enabled 1} $SPROW \
                    {type ac enabled 0 points 10 start 1 stop 1meg}]
  sp_bench $key $SPBENCH

  ## SP1 -- THE DOOR EXISTS, IT IS PER TYPE, AND IT IS NOT A THIRD COPY OF THE
  ## WORD `Ports`. The button's text is composed from the contract's declared
  ## `noun`; `ac`, which declares no contract, gets no button at all. ⚠ AND THE
  ## EXISTING WIDGETS DO NOT MOVE -- issue 1405 cost 100 checks for that lesson
  ## and issue 1448 paid it again, so the row asks for the four established grid
  ## rows back as well as for the new one.
  set cw [sp_open_chana $key 1]
  ## ⚠ EVERY GRID READ GOES THROUGH `ase_grid_row`, WHICH ANSWERS -1 FOR A
  ## WIDGET THAT IS NOT GRIDDED, AND A SABOTAGE IS WHY. Measured: a mutation that
  ## never grids the Matrix door made a bare `dict get [grid info …] -row` raise
  ## `key "-row" not known in dictionary` and the file lost TWENTY checks to the
  ## top-level catch instead of reddening this row -- G2tf's documented failure
  ## shape, met again.
  set SP1B [list [$cw.setupbtn cget -text] [$cw.matrixbtn cget -text] \
                 [ase_grid_row $cw.setupbtn] [ase_grid_row $cw.matrixbtn]]
  $cw.types.ac invoke
  update
  set SP1AC [list [llength [grid info $cw.setupbtn]] [llength [grid info $cw.matrixbtn]]]
  set SP1GRID [list [ase_grid_row $cw.rows] [ase_grid_row $cw.form] \
                    [ase_grid_row $cw.note] [ase_grid_row $cw.opts] \
                    [ase_grid_row $cw.btns]]
  check "SP1 the type that declares a table gets a door named after its own noun,\
 the type that declares none gets neither door, and nothing else moved" \
    [list $SP1B $SP1AC $SP1GRID] \
    [list [list "Ports…" "Matrix…" 4 4] {0 0} {1 3 7 8 9}]

  ## SP2 -- THE TABLE IS THE ROW'S, RENDERED. ⚠ THE FIXTURE'S TWO ENTRIES DIFFER
  ## IN EVERY COLUMN, so a dialog that showed one entry twice, or read the wrong
  ## key, cannot pass by accident.
  sp_bench $key [list {type op enabled 1} \
    {type sp enabled 1 points 3 start 100meg stop 1g \
     ports {{src v1 num 1 z0 50} {src vin2 num 2 z0 75}}}]
  set cw [sp_open_chana $key 1]
  $cw.setupbtn invoke
  update
  set sw $cw.setup
  check "SP2 the ports dialog shows the addressed row's own table" \
    [list [winfo exists $sw] [$sw.tv cget -columns] [sp_tbl $sw {src num z0}]] \
    [list 1 {src num z0} {{v1 1 50} {vin2 2 75}}]

  ## SP3 -- AND EVERY WORD OF IT IS THE REGISTRY'S. The headings are the
  ## ADAPTER's declared column labels, the title and the caption are composed
  ## from its declared `noun`, and this file spells none of them. ⚠ THE FOURTH
  ## TERM IS PLAN.md §9a's RATIFIED SENTENCE, byte for byte -- it is the promise
  ## that makes S-parameters usable with no schematic edit, and a dialog that
  ## showed a list of source names without it invites exactly the wrong
  ## conclusion.
  check "SP3 the headings, the title and the caption are the registry's answer\
 and this dialog spells none of them" \
    [list [list [sp_head $sw src] [sp_head $sw num] [sp_head $sw z0]] \
          [wm title $sw] \
          [$sw.cap cget -text] \
          [expr {[string first {Source} [info body ase::ui::setup_dialog]] >= 0}] \
          [expr {[string first {assigned at run time} \
                    [info body ase::ui::setup_dialog]] >= 0}]] \
    [list {Source Port {Z0 (ohm)}} {Analysis Ports (sp)} \
          {Ports are assigned at run time. Nothing is written to your schematic.} \
          0 0]

  ## SP4 -- ADD, EDIT AND DELETE, THROUGH THE REAL ENTRIES. ⚠ ADD ON A FIRST
  ## COLUMN ALREADY IN THE TABLE REPLACES THAT ENTRY rather than appending a
  ## second one: two entries naming the same source is a table no simulator can
  ## act on, and an editor that let you build one and refused at OK would be two
  ## surprises instead of none. The last term is the control -- a DIFFERENT name
  ## really does append.
  $sw.tv selection set p1
  update
  set SP4LOADED {}
  foreach spc {src num z0} {
    set spv NOCOL
    catch {set spv [$sw.row.$spc get]}
    lappend SP4LOADED $spv
  }
  sp_type $sw z0 100
  $sw.row.add invoke
  update
  set SP4EDIT [sp_tbl $sw {src num z0}]
  foreach spc {src num z0} { sp_type $sw $spc {} }
  sp_type $sw src v9
  sp_type $sw num 3
  $sw.row.add invoke
  update
  set SP4ADD [sp_tbl $sw {src num z0}]
  $sw.tv selection set p2
  $sw.row.del invoke
  update
  set SP4DEL [sp_tbl $sw {src num z0}]
  check "SP4 Add on a name already in the table edits it in place, a new name\
 appends, and Delete removes the selected line" \
    [list $SP4LOADED $SP4EDIT $SP4ADD $SP4DEL] \
    [list {vin2 2 75} {{v1 1 50} {vin2 2 100}} \
          {{v1 1 50} {vin2 2 100} {v9 3 {}}} {{v1 1 50} {vin2 2 100}}]

  ## SP5 -- THE LIVE NOTE IS `ase::needs_eval`'s OWN VERDICT, AND OK IS A COMMIT
  ## DOOR. `span.c:376-386` calls `controlled_exit(EXIT_BAD)` below two ports --
  ## the process dies and takes every other analysis of the run with it, `op`
  ## included -- so a one-port table must not leave this dialog. ⚠ THE EMPTY
  ## TABLE IS ALLOWED THROUGH: it is the untouched state, not a wrong answer, and
  ## the run-time `two_ports` fatal still refuses it and still refuses a
  ## hand-edited `.state`.
  $sw.tv selection set p1
  $sw.row.del invoke
  update
  set SP5NOTE [$sw.note cget -text]
  set SP5BEFORE [ase::state_serialize [ase::session_state $key]]
  $sw.btns.proceed invoke
  update
  set SP5UP [winfo exists $sw]
  set SP5SAME [expr {[ase::state_serialize [ase::session_state $key]] eq $SP5BEFORE}]
  check "SP5 a one-port table paints the run's own refusal and OK refuses it,\
 leaving the dialog up and the bench untouched" \
    [list [string match {*needs at least 2 ports and names 1*} $SP5NOTE] \
          [string match {*nothing is written to your schematic*} $SP5NOTE] \
          $SP5UP $SP5SAME] \
    {1 1 1 1}

  ## SP5b -- THE NON-VACUITY CONTROL FOR SP5. A table that is ALL RIGHT commits
  ## and closes, and an EMPTY one commits too. Without this, an OK that refused
  ## everything would pass SP5.
  ##
  ## ⚠ IT RE-OPENS THE DIALOG IF SP5's OK LET IT CLOSE, AND A SABOTAGE IS WHY.
  ## Measured while running sabotage s11 (OK stops being a commit door): the
  ## dialog closed under SP5, this row's first `$sw.row.src insert` raised
  ## `invalid command name ".ase7.chana.setup.row.src"`, and the file lost
  ## FOURTEEN checks to the top-level catch instead of reddening a row -- G2tf's
  ## documented failure shape, met again. With the guard, SP5 still goes red and
  ## SP6..SP14 still RUN -- measured, the arm went from `3 FAILED (366 passed)`
  ## to `2 FAILED (381 passed)`, which is fourteen checks that stopped being
  ## silently absent.
  if {![winfo exists $sw]} {
    $cw.setupbtn invoke
    update
    set sw $cw.setup
  }
  sp_type $sw src vin2
  sp_type $sw num 2
  sp_type $sw z0 75
  $sw.row.add invoke
  update
  $sw.btns.proceed invoke
  update
  set SP5BROW {}
  foreach spa [ase::state_get [ase::session_state $key] analyses] {
    if {[ase::state_get $spa type] eq {sp}} { set SP5BROW $spa }
  }
  set cw [sp_open_chana $key 1]
  $cw.setupbtn invoke
  update
  set sw $cw.setup
  $sw.tv selection set p0
  $sw.row.del invoke
  $sw.tv selection set p0
  $sw.row.del invoke
  update
  $sw.btns.proceed invoke
  update
  set SP5BEMPTY {}
  foreach spa [ase::state_get [ase::session_state $key] analyses] {
    if {[ase::state_get $spa type] eq {sp}} { set SP5BEMPTY $spa }
  }
  check "SP5b a good table commits and closes, and an emptied one commits and\
 removes the key rather than storing an empty list" \
    [list [ase::state_get $SP5BROW ports] \
          [dict exists $SP5BEMPTY ports] \
          [ase::state_get $SP5BEMPTY points]] \
    [list {{src v1 num 1 z0 50} {src vin2 num 2 z0 75}} 0 3]

  ## SP6 -- ADD FROM SCHEMATIC. ⚠ IT PEEKS AND NEVER NETLISTS -- a dialog may not
  ## produce a netlist because a user opened it (issue 1435's constraint, and
  ## this window is under that dialog). COLD first, so the row cannot inherit a
  ## warm slot from an earlier section and pass vacuously: the picker is empty
  ## and says the banner's own cold sentence, naming the door.
  ase::facts_clear
  set cw [sp_open_chana $key 1]
  $cw.setupbtn invoke
  update
  set sw $cw.setup
  $sw.btns.scan invoke
  update
  set scw $sw.scan
  set SP6COLD [list [llength [$scw.tv children {}]] \
                    [string match "*[ase::ui::menu_path_netlist_recreate]*" \
                       [$scw.note cget -text]]]
  $scw.btns.cancel invoke
  update
  ## AND WARM, through the product's own gesture -- the menu entry the cold
  ## sentence names -- on the fixture schematic, whose two `vsource` symbols are
  ## `V1` and `V2`.
  ase::ui::do_netlist_recreate $key
  update
  $sw.btns.scan invoke
  update
  set scw $sw.scan
  set SP6WARM [sp_tbl $scw {src num z0}]
  set SP6SEL [llength [$scw.tv selection]]
  set SP6TITLE [wm title $scw]
  $scw.btns.proceed invoke
  update
  set SP6TBL [sp_tbl $sw {src num z0}]
  check "SP6 Add from Schematic is empty and says why on a bench nobody has\
 netlisted, and after Netlist > Recreate it offers the circuit's own voltage\
 sources, preselected, numbered from 1" \
    [list $SP6COLD [llength $SP6WARM] $SP6SEL $SP6TBL $SP6TITLE] \
    [list {0 1} 2 2 {{V1 1 {}} {V2 2 {}}} {Add Ports from Schematic}]

  ## SP6b -- AND IT DOES NOT OFFER WHAT IS ALREADY IN THE TABLE. Reopening the
  ## picker on the table SP6 just filled offers nothing, with the "no more"
  ## sentence rather than the cold one -- the two empties are different and the
  ## dialog says which.
  $sw.btns.scan invoke
  update
  set scw $sw.scan
  set SP6BN [$scw.note cget -text]
  set SP6BC [llength [$scw.tv children {}]]
  $scw.btns.cancel invoke
  update
  $sw.btns.cancel invoke
  update
  check "SP6b a second Add from Schematic offers nothing and says so in its own\
 words, not the cold ones" \
    [list $SP6BC $SP6BN] [list 0 {This schematic offers no more ports.}]

  ## SP7 -- THE MATRIX PICKER. ⚠ ITS SIZE IS THE PORTS TABLE'S, which is why it
  ## reads the same row: measured on both binaries, a two-port `sp` run with the
  ## flag OFF answers twelve vectors in three families and a three-port one
  ## twenty-seven. (With the flag ON those become 20 and **36** -- issue 1457,
  ## rows SP9 and SP9b. This comment said "twenty-seven" with no flag clause
  ## until then, which is the sentence the defect was hiding behind.)
  ## ⚠ OPENING THE PICKER IS CAUGHT, AND A SABOTAGE IS WHY -- THE SIXTH TIME
  ## THIS SHAPE HAS BEEN MET AND THE THIRD INSIDE SECTION SP. Measured under
  ## issue 1457: a mutation that made `ase::analysis_matrix_of` stop filtering by
  ## family had `matrix_dialog` build `cS_1_1` once per family, and
  ## `window name "cS_1_1" already exists in parent` came straight out of
  ## `$cw.matrixbtn invoke`. SP7 through SP12 -- THIRTEEN checks -- stopped
  ## running, and the row that should have gone red never reported at all.
  ## A dialog that raises on the way up IS a defect and must redden a row, so
  ## `mx_open` answers a window path when one came up and the unusable
  ## `.nosuchmxwin` when it did not, with the message in `::MXERR`. Every read
  ## below goes through a total reader for the same reason.
  proc mx_open {cw} {
    set ::MXERR {}
    if {[catch {$cw.matrixbtn invoke} m]} { set ::MXERR "RAISED:$m" ; return .nosuchmxwin }
    update
    if {![winfo exists $cw.mx]} { set ::MXERR NOWINDOW ; return .nosuchmxwin }
    return $cw.mx
  }
  proc mx_title {mw} { set v NOTITLE ; catch {set v [wm title $mw]} ; return $v }
  proc mx_fmts {mw} { set v NOFMT ; catch {set v [$mw.fmt.v cget -values]} ; return $v }
  proc mx_click {mw b} { return [expr {[catch {$mw.btns.$b invoke}] ? 0 : 1}] }
  ## the captions, in the order the picker built them -- `NOBODY` when the
  ## window is not there at all, which is a value a row can compare.
  proc mx_caps {mw} {
    if {![winfo exists $mw.body]} { return NOBODY }
    set out {}
    foreach spw [winfo children $mw.body] {
      set cls {}
      catch {set cls [winfo class $spw]}
      if {$cls ne {Checkbutton}} { continue }
      set t {}
      catch {set t [$spw cget -text]}
      lappend out $t
    }
    return $out
  }
  sp_bench $key [list {type op enabled 1} $SPROW]
  set cw [sp_open_chana $key 1]
  set mw [mx_open $cw]
  set SP7CELLS [mx_caps $mw]
  set SP7N [expr {$SP7CELLS eq {NOBODY} ? -1 : [llength $SP7CELLS]}]
  check "SP7 the matrix picker offers one cell per vector the run will answer,\
 laid out as the matrix it is" \
    [list $::MXERR [mx_title $mw] $SP7N [lsort -unique $SP7CELLS] \
          [mx_fmts $mw]] \
    [list {} {Result Matrix (sp)} 12 {1,1 1,2 2,1 2,2} \
          {{Magnitude (dB)} {Phase (deg)} Real Imaginary}]

  ## SP8 -- OK WRITES ORDINARY OUTPUT ROWS AND INVENTS NO STATE. `plot 1` /
  ## `save 0`, because `sp` declares `resultvecs own` and the deck already
  ## carries a `.save all` leader -- a Save tick would narrow nothing (issue
  ## 1434's `vecsaves` caution). ⚠ AND THE EXPRESSION IS THE VIEWER'S OWN RPN,
  ## measured accepted against BOTH binaries' variable lists: `wviewer::validate_rpn`
  ## answers {} for `S_1_1 db20()` against the fork's `S_1_1` AND against apt
  ## 45.2's `s_1_1`, and rejects `S_9_9` and `nosuchfn()`.
  set ::ase::ui::dlg($key,mxv,S_1_1) 1
  set ::ase::ui::dlg($key,mxv,Y_2_1) 1
  set ::ase::ui::dlg($key,mxfmt) {Phase (deg)}
  set SP8OK [mx_click $mw proceed]
  update
  set SP8OUT {}
  foreach spo [ase::state_get [ase::session_state $key] outputs] {
    set spx [ase::state_get $spo expr]
    if {[string first {S_} $spx] < 0 && [string first {Y_} $spx] < 0} { continue }
    lappend SP8OUT [list [ase::state_get $spo name] $spx \
                         [ase::state_get $spo plot] [ase::state_get $spo save]]
  }
  set SP8RPN {}
  foreach spvl [list {frequency S_1_1 Y_2_1} {frequency s_1_1 y_2_1}] {
    set spr NOPROC
    catch {set spr [wviewer::validate_rpn {S_1_1 cph()} $spvl]} spr
    lappend SP8RPN $spr
    set spr NOPROC
    catch {set spr [wviewer::validate_rpn {S_9_9 cph()} $spvl]} spr
    lappend SP8RPN [expr {$spr ne {}}]
  }
  check "SP8 OK writes one ordinary Outputs row per ticked cell, in the viewer's\
 own RPN, and the viewer resolves it against EITHER binary's spelling" \
    [list $SP8OK $SP8OUT $SP8RPN] \
    [list 1 {{S_1_1_ph {S_1_1 cph()} 1 0} {Y_2_1_ph {Y_2_1 cph()} 1 0}} {{} 1 {} 1}]

  ## SP8b -- AND TICKING THE SAME CELL TWICE DOES NOT WRITE THE TRACE TWICE.
  ## Opening the picker again with the same cells ticked is an ordinary gesture,
  ## and a second identical Outputs row would plot the same trace over itself.
  ## The control is a DIFFERENT format, which is a different expression and does
  ## get written.
  set cw [sp_open_chana $key 1]
  set mw [mx_open $cw]
  set ::ase::ui::dlg($key,mxv,S_1_1) 1
  set ::ase::ui::dlg($key,mxfmt) {Phase (deg)}
  set SP8BOK [mx_click $mw proceed]
  update
  set SP8BN 0
  foreach spo [ase::state_get [ase::session_state $key] outputs] {
    if {[ase::state_get $spo expr] eq {S_1_1 cph()}} { incr SP8BN }
  }
  set cw [sp_open_chana $key 1]
  set mw [mx_open $cw]
  set ::ase::ui::dlg($key,mxv,S_1_1) 1
  set ::ase::ui::dlg($key,mxfmt) {Real}
  set SP8BOK2 [mx_click $mw proceed]
  update
  set SP8BR 0
  foreach spo [ase::state_get [ase::session_state $key] outputs] {
    if {[ase::state_get $spo expr] eq {S_1_1 re()}} { incr SP8BR }
  }
  check "SP8b the same cell in the same format is not added twice, and the same\
 cell in another format is" [list $SP8BOK $SP8BOK2 $SP8BN $SP8BR] {1 1 1 1}

  ## SP9 -- THE PICKER DESCRIBES THE FORM THE USER IS LOOKING AT, NOT THE STORED
  ## ROW. A user who has just ticked the noise flag and not pressed OK is reading
  ## a form that says the run will answer `NF`; a picker built from the stored row
  ## would not offer it. ⚠ MEASURED ON BOTH BINARIES: the flag adds the four
  ## scalars AND a `Cy` correlation matrix, which `evidence/sp-stage9.md` does
  ## not have.
  set cw [sp_open_chana $key 1]
  update
  catch {$cw.form.advbtn invoke}
  update
  set SP9HAVE [winfo exists $cw.form.donoise]
  if {$SP9HAVE} { $cw.form.donoise select }
  update
  set mw [mx_open $cw]
  set SP9CAPS [mx_caps $mw]
  set SP9N [expr {$SP9CAPS eq {NOBODY} ? -1 : [llength $SP9CAPS]}]
  set SP9NF [winfo exists $mw.body.cNF]
  set SP9CY [winfo exists $mw.body.cCy_1_1]
  mx_click $mw cancel
  update
  check "SP9 the picker is built from the live form, so a noise flag the user has\
 ticked and not yet committed already shows its own vectors" \
    [list $::MXERR $SP9HAVE $SP9N $SP9NF $SP9CY] {{} 1 20 1 1}

  ## SP9b -- THE THREE-PORT PICKER, WHICH IS ISSUE **1457**. Section SP had no
  ## three-port row at all: SP7 asks for 12 cells and SP9 for 20, both on the
  ## two-port bench, so the picker that hid nine real vectors on every larger run
  ## was green here too.
  ##
  ## ⚠ RE-MEASURED ON BOTH BINARIES, SIX DECKS, FROM THE WRITTEN RAWFILE'S
  ## `Variables:` BLOCK: a three-port run with the flag on writes **36** vectors
  ## -- 27 in S/Y/Z and a **9-cell `Cy`** grid -- and **no** `NF`/`NFmin`/`Rn`/
  ## `SOpt` at all. `Cy` follows the flag at ANY port count, N x N; only the four
  ## scalars are restricted to N == 2. So this row asks for BOTH mistakes, which
  ## are opposite ones: `Cy` missing (the shipped defect) and the scalars present
  ## (its mirror image).
  ##
  ## ⚠ AND THE LAYOUT IS THE PART NO SCHEMA ROW CAN SEE. A 3x3 `Cy` block with no
  ## scalar strip under it is a geometry `matrix_dialog` had never been handed:
  ## four matrix families stacked, each one's header label in column 0 of the row
  ## above its own first cell. The terms below are the two ways that goes wrong
  ## -- a family's cells landing on top of another family's, or on their own
  ## header -- asked as a COLLISION over every gridded child of `$mw.body`, so a
  ## future family needs no new term.
  ##
  ## ⚠ EVERY READ IS TOTAL. A sabotage that drops a family removes the widget,
  ## and a bare `grid info` on a missing window raises and takes the whole file
  ## down at rc 0 -- this section has met that shape three times already (SP5b,
  ## SP1, SP2). `mx_cells` answers `NOBODY` and never raises.
  proc mx_cells {mw} {
    if {![winfo exists $mw.body]} { return NOBODY }
    set out {}
    foreach spw [winfo children $mw.body] {
      set cls {}
      catch {set cls [winfo class $spw]}
      if {$cls ne {Checkbutton}} { continue }
      set gi {}
      catch {set gi [grid info $spw]}
      set gr -1 ; set gc -1
      catch {set gr [dict get $gi -row]}
      catch {set gc [dict get $gi -column]}
      lappend out [list [string range [winfo name $spw] 1 end] $gr $gc]
    }
    return [lsort -index 0 $out]
  }
  ## every gridded child of the body, cells AND headers, as {row col} -- the
  ## collision check's input.
  proc mx_slots {mw} {
    if {![winfo exists $mw.body]} { return NOBODY }
    set out {}
    foreach spw [winfo children $mw.body] {
      set gi {}
      catch {set gi [grid info $spw]}
      set gr -1 ; set gc -1
      catch {set gr [dict get $gi -row]}
      catch {set gc [dict get $gi -column]}
      lappend out [list $gr $gc]
    }
    return $out
  }
  ## ⚠ ONE LINE -- a backslash-newline inside a braced fixture leaves a DOUBLE
  ## SPACE in the literal, which is what cost SP13 a row.
  set SP3PROW {type sp enabled 1 points 3 start 100meg stop 1g donoise 1 ports {{src v1 num 1 z0 50} {src v2 num 2 z0 50} {src v3 num 3 z0 50}}}
  sp_bench $key [list {type op enabled 1} $SP3PROW]
  set cw [sp_open_chana $key 1]
  set mw [mx_open $cw]
  set SP9BCELLS [mx_cells $mw]
  set SP9BN [expr {$SP9BCELLS eq {NOBODY} ? -1 : [llength $SP9BCELLS]}]
  ## the Cy block's own geometry: nine names, three distinct grid rows, three
  ## distinct grid columns. A `Cy` emitted at a fixed 2x2 keeps the family and
  ## still fails here.
  set SP9BCYN {} ; set SP9BCYR {} ; set SP9BCYC {}
  if {$SP9BCELLS ne {NOBODY}} {
    foreach spc $SP9BCELLS {
      if {![string match {Cy_*} [lindex $spc 0]]} { continue }
      lappend SP9BCYN [lindex $spc 0]
      if {[lsearch -exact $SP9BCYR [lindex $spc 1]] < 0} { lappend SP9BCYR [lindex $spc 1] }
      if {[lsearch -exact $SP9BCYC [lindex $spc 2]] < 0} { lappend SP9BCYC [lindex $spc 2] }
    }
  }
  ## no two gridded children share a cell -- headers included
  set SP9BSLOTS [mx_slots $mw]
  set SP9BDUP [expr {$SP9BSLOTS eq {NOBODY} ? -1 :
                     [llength $SP9BSLOTS] - [llength [lsort -unique $SP9BSLOTS]]}]
  ## the four scalars are not offered, and the `Noise` heading is not drawn
  set SP9BSCAL {}
  foreach spn {NF NFmin Rn SOpt} {
    if {[winfo exists $mw.body.c$spn]} { lappend SP9BSCAL $spn }
  }
  set SP9BHEADS {}
  foreach spf {S Y Z Cy Noise} {
    if {[winfo exists $mw.body.h$spf]} { lappend SP9BHEADS $spf }
  }
  check "SP9b a three-port row with the noise flag offers all 36 cells the run\
 writes -- the nine-cell Cy grid included -- and none of the four scalars" \
    [list $::MXERR $SP9BN [llength $SP9BCYN] $SP9BCYN \
          [llength $SP9BCYR] [llength $SP9BCYC] \
          $SP9BSCAL $SP9BHEADS $SP9BDUP] \
    [list {} 36 9 {Cy_1_1 Cy_1_2 Cy_1_3 Cy_2_1 Cy_2_2 Cy_2_3 Cy_3_1 Cy_3_2 Cy_3_3} \
          3 3 {} {S Y Z Cy} 0]

  ## SP9c -- AND THE NINE CELLS REACH A TRACE, which is the whole of what the
  ## user was being denied. ⚠ THE EXPRESSION CARRIES THE `i(...)` WRAP AT N == 3,
  ## RE-MEASURED RATHER THAN ASSUMED TO GENERALISE FROM N == 2: against the real
  ## three-port variable list of each binary, `wviewer::validate_rpn` rejects the
  ## bare `Cy_3_3`, accepts `i(Cy_3_3)`, and rejects `i(Cy_9_9)` as the control.
  ## The second term is that measurement run here, both spellings; the third is
  ## the control that keeps it honest.
  ##
  ## ⚠ THE ORDER IS THE MATRIX'S, NOT THE TICKING'S, and that is asserted rather
  ## than sorted away: `matrix_ok` walks `ase::analysis_matrix`, so `S_3_1`
  ## lands above `Cy_3_3` however they were ticked. Measured -- the row was
  ## written the other way round first and reddened on exactly this.
  set ::ase::ui::dlg($key,mxv,Cy_3_3) 1
  set ::ase::ui::dlg($key,mxv,S_3_1) 1
  set ::ase::ui::dlg($key,mxfmt) {Phase (deg)}
  set SP9COK [mx_click $mw proceed]
  update
  set SP9COUT {}
  foreach spo [ase::state_get [ase::session_state $key] outputs] {
    set spx [ase::state_get $spo expr]
    if {[string first {Cy_} $spx] < 0 && [string first {S_3_} $spx] < 0} { continue }
    lappend SP9COUT [list [ase::state_get $spo name] $spx]
  }
  ## ⚠ THE TWO LISTS MUST DISAGREE, AND THAT IS A TERM. They are the SAME run in
  ## the two binaries' spellings -- the fork writes `i(Cy_3_3)`, apt 45.2 writes
  ## `i(cy_3_3)` -- so if a tidy-up ever makes them identical this row stops
  ## measuring the fold while staying green. `SP9CDIFF` is what notices.
  set SP9CLISTS [list {frequency i(Cy_3_3) S_3_1} {frequency i(cy_3_3) s_3_1}]
  set SP9CDIFF [expr {[lindex $SP9CLISTS 0] ne [lindex $SP9CLISTS 1]}]
  set SP9CRPN {}
  foreach spvl $SP9CLISTS {
    set spr NOPROC
    catch {set spr [wviewer::validate_rpn {i(Cy_3_3) cph()} $spvl]} spr
    lappend SP9CRPN $spr
    set spr NOPROC
    catch {set spr [wviewer::validate_rpn {Cy_3_3 cph()} $spvl]} spr
    lappend SP9CRPN [expr {$spr ne {}}]
    set spr NOPROC
    catch {set spr [wviewer::validate_rpn {i(Cy_9_9) cph()} $spvl]} spr
    lappend SP9CRPN [expr {$spr ne {}}]
  }
  check "SP9c a ticked three-port Cy cell becomes an ordinary Outputs row in the\
 wrap the rawfile really uses, which the viewer accepts in either spelling" \
    [list $SP9COK $SP9COUT $SP9CDIFF $SP9CRPN] \
    [list 1 {{S_3_1_ph {S_3_1 cph()}} {Cy_3_3_ph {i(Cy_3_3) cph()}}} 1 \
          {{} 1 1 {} 1 1}]

  ## SP10 -- AN EMPTY TABLE HAS NO MATRIX, AND THE PICKER SAYS THE RUN'S OWN
  ## REASON RATHER THAN GOING BLANK. This is the "nothing the window shows may
  ## fail to reach the deck" rule from the other end: there is nothing to show,
  ## and the sentence is the one the run would give.
  sp_bench $key [list {type op enabled 1} \
    {type sp enabled 1 points 3 start 100meg stop 1g}]
  set cw [sp_open_chana $key 1]
  set mw [mx_open $cw]
  set SP10CAPS [mx_caps $mw]
  set SP10N [expr {$SP10CAPS eq {NOBODY} ? -1 : [llength $SP10CAPS]}]
  set SP10T {}
  catch {set SP10T [$mw.body.empty cget -text]}
  mx_click $mw cancel
  update
  check "SP10 a bench with no ports gets no cells and the run's own sentence" \
    [list $::MXERR $SP10N \
          [string match {*needs at least 2 ports and names 0*} $SP10T]] {{} 0 1}

  ## SP11 -- A STANDING SUBDIALOG DIES WITH A TYPE CLICK. Both of them edit ONE
  ## row of ONE type and both read the live `antype`, so a Ports table left open
  ## across a type click would write the previous type's table into the new
  ## type's row. ⚠ AND THE RECORDS GO WITH THE WINDOWS, which is what tells a
  ## cancel path from a bare destroy (item 10's rule).
  sp_bench $key $SPBENCH
  set cw [sp_open_chana $key 1]
  $cw.setupbtn invoke
  update
  set SP11UP [winfo exists $cw.setup]
  $cw.types.ac invoke
  update
  check "SP11 a type click closes a standing ports table and takes its records\
 with it" \
    [list $SP11UP [winfo exists $cw.setup] \
          [info exists ::ase::ui::dlg($key,anports)]] {1 0 0}

  ## SP11b -- ESC DISMISSES BOTH NEW TOPLEVELS AND THE NESTED THIRD ONE, through
  ## their own cancel paths (item 10, sections GE1-16's set).
  set cw [sp_open_chana $key 1]
  $cw.setupbtn invoke
  update
  set sw $cw.setup
  $sw.btns.scan invoke
  update
  set scw $sw.scan
  send_key $scw <Key-Escape> {![winfo exists $scw]}
  set SP11BSCAN [list [winfo exists $scw] [winfo exists $sw]]
  send_key $sw <Key-Escape> {![winfo exists $sw]}
  set SP11BSETUP [list [winfo exists $sw] [winfo exists $cw] \
                       [info exists ::ase::ui::dlg($key,anports)]]
  set mw [mx_open $cw]
  send_key $mw <Key-Escape> {![winfo exists $mw]}
  check "SP11b ESC dismisses the scan picker without killing the ports table, the\
 ports table without killing Choose Analyses, and the matrix picker, each\
 through its own cancel path" \
    [list $SP11BSCAN $SP11BSETUP $::MXERR [winfo exists $mw] \
          [info exists ::ase::ui::dlg($key,mxfmt)]] \
    [list {0 1} {0 1 0} {} 0 0]

  ## SP12 -- THE DEFECT THIS SECTION FOUND, AND IT IS ISSUE 1450's FOR THE THIRD
  ## TIME. `ports` is licensed on ONE type rather than on every row, so it is
  ## deliberately not in `ase::analysis_nonsetting_keys` -- and the `Options…`
  ## subdialog's reader and writer asked only that proc. MEASURED on the unfixed
  ## tree through these very widgets: the whole table listed as one free-text
  ## NAME/VALUE pair, and OK refusing it as a setting ASE-L cannot emit, with the
  ## subdialog left standing and nothing written.
  ##
  ## ⚠ THE SECOND HALF IS THE SHARPER ONE. The writer's strip deletes every key
  ## not in `skip` before writing back, so a `skip` that had never heard of the
  ## table key would DESTROY it on any commit that got past the refusal. This row
  ## asks for the bench back byte for byte, and its third term is the control --
  ## a key that really IS a stray is still listed and still refused.
  sp_bench $key [list {type op enabled 1} $SPROW]
  set SP12BEFORE [ase::state_serialize [ase::session_state $key]]
  set cw [sp_open_chana $key 1]
  $cw.opts invoke
  update
  set xw $cw.x
  set SP12PAIRS {}
  foreach spit [$xw.tv children {}] {
    lappend SP12PAIRS [list [$xw.tv set $spit name] [$xw.tv set $spit value]]
  }
  d_echo_arm
  $xw.btns.proceed invoke
  update
  set SP12ERR [d_echoed_n {*cannot emit*}]
  d_echo_disarm
  set SP12UP [winfo exists $xw]
  set SP12AFTER [ase::state_serialize [ase::session_state $key]]
  sp_bench $key [list {type op enabled 1} [dict merge $SPROW {legacykey 7}]]
  set cw [sp_open_chana $key 1]
  $cw.opts invoke
  update
  set SP12STRAY {}
  foreach spit [$cw.x.tv children {}] {
    lappend SP12STRAY [list [$cw.x.tv set $spit name] [$cw.x.tv set $spit value]]
  }
  $cw.x.btns.cancel invoke
  update
  check "SP12 the Options editor no longer lists a row's setup TABLE as a\
 free-text setting, commits silently, leaves the bench byte for byte, and still\
 lists a key that really is a stray" \
    [list $SP12PAIRS $SP12UP [expr {$SP12AFTER eq $SP12BEFORE}] \
          $SP12ERR $SP12STRAY] \
    [list {} 0 1 0 {{legacykey 7}}]

  ## SP13 -- THE 104-FILE BYTE-IDENTITY QUESTION, FROM THIS SECTION'S SIDE.
  ## Opening both new dialogs and pressing OK on a table nothing changed writes
  ## the same bytes as never opening them. ⚠ THE CONTROL IS A CHANGED TABLE,
  ## because a dialog whose OK did nothing at all would pass the first half.
  sp_bench $key $SPBENCH
  set SP13BEFORE [ase::state_serialize [ase::session_state $key]]
  set cw [sp_open_chana $key 1]
  $cw.setupbtn invoke
  update
  $cw.setup.btns.proceed invoke
  update
  set mw [mx_open $cw]
  set SP13MXOK [mx_click $mw proceed]
  update
  $cw.btns.proceed invoke
  update
  set SP13SAME [expr {[ase::state_serialize [ase::session_state $key]] eq $SP13BEFORE}]

  set cw [sp_open_chana $key 1]
  $cw.setupbtn invoke
  update
  sp_type $cw.setup src v7
  sp_type $cw.setup num 3
  $cw.setup.row.add invoke
  update
  $cw.setup.btns.proceed invoke
  update
  set SP13DIFF [expr {[ase::state_serialize [ase::session_state $key]] ne $SP13BEFORE}]
  check "SP13 opening both Stage 9 dialogs and pressing OK on an untouched table\
 writes the same bytes as never opening them, and a changed table does not" \
    [list $SP13MXOK $SP13SAME $SP13DIFF] {1 1 1}

  ## SP14 -- THE ROW ISSUE 1449 ASKED FOR: A PORT ADDED IN THE TABLE, THROUGH THE
  ## REAL WIDGETS, REACHING A RENDERED `alter` LINE AND THEN A REAL RUN THAT
  ## ANSWERS `S_1_1`.
  ##
  ## ⚠ TWO HALVES OF A FEATURE TESTED IN DIFFERENT SUITES NEVER MEET. The widget
  ## half is everything above; the deck half is `test_ase_sp_1452.tcl`; this is
  ## the one row that goes all the way through, and it is the only row in this
  ## file that starts a simulator. Binaries come from `$env(ASE_SP_NGSPICE)`
  ## (colon-separated) or from the two CREW_BRIEF names; a missing one SKIPS with
  ## its path printed, so the log never confuses "not tested" with "tested and
  ## fine".
  ##
  ## ⚠ AND THE `S_1_1` MATCH IS CASE-INSENSITIVE, AND THE SPELLING IT FOUND IS
  ## REPORTED. Measured: the fork writes `S_1_1` and apt 45.2 writes `s_1_1` into
  ## the same file for the same deck. A case-sensitive row would be green on the
  ## development reference and red on the binary a downloading user has.
  sp_bench $key [list {type op enabled 1} \
    {type sp enabled 1 points 3 start 100meg stop 1g}]
  set cw [sp_open_chana $key 1]
  $cw.setupbtn invoke
  update
  set sw $cw.setup
  foreach {spn spnum} {v1 1 v2 2} {
    foreach spc {src num z0} { sp_type $sw $spc {} }
    sp_type $sw src $spn
    sp_type $sw num $spnum
    sp_type $sw z0 50
    $sw.row.add invoke
    update
  }
  $sw.btns.proceed invoke
  update
  set SP14ST [ase::session_state $key]
  set SP14NL "* spbench\nv1 in 0 dc 1 ac 1\nv2 out 0 dc 0 ac 0\nr1 in mid 50\nr2 mid 0 50\nr3 mid out 50\n.end\n"
  set SP14RUN [file join $scratch sp14run]
  file delete -force $SP14RUN
  file mkdir $SP14RUN
  dict set SP14ST rundir $SP14RUN
  dict set SP14ST design [dict create cell spbench lib $scratch]
  set SP14DECK {}
  catch {set SP14DECK [ase::backend::ngspice::render_deck $SP14ST $SP14NL]} SP14DECK
  set SP14ALT {}
  foreach spl [split $SP14DECK "\n"] {
    if {[string match {alter *} [string trim $spl]]} { lappend SP14ALT [string trim $spl] }
  }
  check "SP14 a port typed into the table reaches the deck as the promotion the\
 simulator needs, above the card" \
    [list $SP14ALT \
          [expr {[string first {alter v1 portnum = 1} $SP14DECK] \
                 < [string first {sp dec 3 100meg 1g} $SP14DECK]}]] \
    [list [list {alter v1 portnum = 1} {alter v1 z0 = 50} \
                {alter v2 portnum = 2} {alter v2 z0 = 50}] 1]

  set SP14BINS {}
  if {[info exists ::env(ASE_SP_NGSPICE)] && $::env(ASE_SP_NGSPICE) ne {}} {
    foreach spb [split $::env(ASE_SP_NGSPICE) :] {
      if {[string trim $spb] ne {}} { lappend SP14BINS [string trim $spb] }
    }
  } else {
    set SP14BINS [list /usr/bin/ngspice \
                       /home/analog/dev/ngspice/build-ver_50/src/ngspice]
  }
  foreach spb $SP14BINS {
    set sptag [expr {[string match {/usr/bin/*} $spb] ? {apt} : {fork}}]
    if {![file executable $spb]} {
      puts "  SP14/$sptag SKIPPED -- no binary at $spb"
      continue
    }
    set spdeckf [file join $SP14RUN spbench_ase.spice]
    set spf [open $spdeckf w] ; puts -nonewline $spf $SP14DECK ; close $spf
    set sprc 0
    set spout {}
    if {[catch {exec timeout 120 $spb -b $spdeckf 2>@1} spout]} { set sprc 1 }
    set spraw [file join $SP14RUN spbench_ase.raw]
    set sphave [ase::raw_vectors_present $spraw {S_1_1 S_2_1 Y_1_1 Z_2_2 S_9_9}]
    set spspell {}
    foreach sppl [ase::cap_raw_plots $spraw] {
      if {![string equal -nocase [lindex $sppl 0] {SP Analysis}]} { continue }
      foreach spv [lindex $sppl 2] {
        if {[string equal -nocase $spv {S_1_1}]} { set spspell $spv }
      }
    }
    check "SP14/$sptag the deck that table wrote really runs, and the results\
 file answers the matrix the picker offers" \
      [list [file exists $spraw] $sphave [expr {$spspell ne {}}]] \
      [list 1 {S_1_1 S_2_1 Y_1_1 Z_2_2} 1]
    puts "  SP14/$sptag rc=$sprc rawfile spelling of S_1_1 = |$spspell|"
    if {$sprc} { puts "  SP14/$sptag output: $spout" }
  }
  sp_bench $key $SPBENCH

} else {
  puts "gui legs skipped (no DISPLAY)"
}


} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  incr fail
}

# --- cleanup + verdict -------------------------------------------------------
catch {file attributes $spath -permissions 0644}
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
# ⚠ THE SECOND SENTINEL, AND IT IS WHAT LETS run_regression.tcl READ THIS FILE
# AT ALL (issue 1413). There are TWO completion banners in this tree:
# `run_suites.sh` accepts either `RESULT: ALL PASS` or `OVERALL: ok` (issue 0228),
# while `tests/banner_rule.tcl` -- the rule `run_regression.tcl` consumes --
# accepts ONLY a whole-line `OVERALL: ok` with an optional parenthesised trailer.
# A suite printing `RESULT:` alone is scored a HARNESS FAILURE by T1 however many
# of its own checks passed, which is issue 0689's shape, filed four times.
#
# MEASURED: this suite printed `RESULT:` and nothing else, so it could not be
# added to T1's case list -- and seven commits of the analyses batch were reported
# as "T1 at zero" while T1 ran only FOUR test_ase_* suites and never this one.
# The suites were run separately every time, so the work was verified; the NUMBER
# was quoted for more than it covered. `test_ase_simcaps_0948` and
# `test_ase_optier_0963` already emit both, which is exactly why THEY are in T1.
if {$fail == 0} {
  puts "OVERALL: ok"
} else {
  puts "OVERALL: notok"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
