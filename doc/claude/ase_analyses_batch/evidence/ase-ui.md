# ASE-L's UI surface — dossier for the "expose every ngspice analysis" plan

**Area:** `/home/analog/dev/xschem-claude/src/ase_window.tcl` (all Tk code of ASE-L) and the
parts of `/home/analog/dev/xschem-claude/src/ase.tcl` it calls.
**Audience:** a future Claude Code session that must make ASE-L expose every ngspice ANALYSIS
and every option that configures one, "better than Cadence ADE-L".
**Written:** 2026-09-09, read-only pass. Nothing in either repo was modified.

---

## 0. Provenance, and how to re-anchor every line number below

| fact | value |
|---|---|
| repo | `/home/analog/dev/xschem-claude`, branch `fluid-editing` |
| git HEAD at read time | `5fb8f465` ("fix(1396): Save State asked nothing before it destroyed an existing state") |
| working tree | **DIRTY**: `src/ase_window.tcl`, `src/xschem.tcl`, `tests/headless/test_ase_window.tcl`, `doc/claude/ase_l_ux_batch/LEDGER.md` modified |
| `src/ase.tcl` | 11 745 lines, mtime 2026-09-08 22:50:20 — stable during this read |
| `src/ase_window.tcl` | mtime 2026-09-09 **18:48:37**, i.e. **22 seconds before I stat'd it** |

> ⚠ **`ase_window.tcl` WAS BEING EDITED WHILE THIS DOSSIER WAS WRITTEN.** It was 8 005 lines when
> I started reading and 8 120 lines eight minutes later; `ase::ui::build_pane` moved from :1172
> to :1272 mid-session. Another agent is landing `doc/claude/ase_l_ux_batch/PLAN.md` into this
> file right now (the new `ase::ui::pane_hscroll` / `ase::ui::retune_columns` procs and the
> `colpolicy`/`colfont` variables are that work arriving).
>
> **Every `ase_window.tcl:N` in this document is against a frozen snapshot**
> `/tmp/claude-1000/-home-analog-dev-ngspice/aa67b095-6376-4408-9db3-5c2a5c1d3f85/scratchpad/ase_window.snap.tcl`
> (8 120 lines, sha256 `75c634658a471f37…`), taken 2026-09-09 18:49.
> **Anchor by PROC NAME first; treat the number as a hint** and re-grep
> (`grep -n '^proc ase::ui::<name>' src/ase_window.tcl`). `ase.tcl:N` numbers are against the
> committed file and were stable.

Two other documents in that tree are load-bearing for this plan and were read in full for the
sections below:
* `doc/claude/specs/ase_l.md` — the authoritative chrome contract ("UI v2 / ADE-L parity rework").
* `doc/claude/ase_l_ux_batch/FINDINGS.md` — a 126-finding twelve-lens UX audit dated 2026-09-09,
  with live measurements. **Its own line anchors are already stale** (it cites
  `ase_window.tcl:4104` for the analysis radio loop, which is now :4551). I quote its
  *measurements* as theirs, and re-derive every structural claim from the source myself.

---

## 1. Structural map of the ASE-L main window as it is today

### 1.1 Window identity and lifecycle

* One toplevel **per session view**, named `.ase<N>` — `ase::ui::open` (`ase_window.tcl:598`),
  `set N [xschem allocate_window_number]` (:600), `toplevel .ase$N` (:601-602). N comes from the
  shared C counter, so `.aseN` can never collide with an editor/textwindow name.
* Bookkeeping dicts, all keyed by the session key `lib/cell/view`: `wins` (key→toplevel, :67),
  `wnum` (key→N, :71), `meta` (key→`{lib cell view}`, :73). Public accessors
  `ase::ui::window_for` (:578) and `ase::ui::number_for` (:589).
* `ase::ui::open` also installs the two global notify hooks:
  `set ::ase::session_notify ase::ui::session_changed` (:608) and
  `set ::ase::sim_notify ase::ui::refresh_status_all` (:640).
* Close routes: `wm protocol WM_DELETE_WINDOW` and `Control-w`/`Control-W` →
  `ase::ui::close_request` (:646-649); `ase::ui::close` (:660) is the unconditional teardown that
  drops every per-key array (`idlebg loglen selclear edrow edchk annot dlg simuse`) and calls
  `wviewer::close` and `ase::ui::sod_end`.
* The **only** seam from the Tk-free core into this file is `ase::open_state` (`ase.tcl:9552`),
  guarded by `if {![info exists ::has_x]} { return 1 }` (`ase.tcl:9567`). Everything in
  `ase_window.tcl` may assume a display; nothing in `ase.tcl` may assume this file exists.
* `ase::ui::build $key $top` (:812) then `ase::ui::populate $key` then `ase::ui::viewer_restore`
  (:653-658).

### 1.2 `ase::ui::build` (:812–:1181), top to bottom

Packing order matters and is commented as such: status bar and strip are packed **before** the
expanding body (an expanding widget packed first claims the cavity, :1064, :1084).

| # | element | widget path | source |
|---|---|---|---|
| 1 | menubar | `$top.mb` + 9 cascades | :818-1033 |
| 2 | toolbar row | `$top.tb` (frame), `$top.tb.temp` (entry -width 7), `$top.tb.degc` (label `°C`) | :1037-1059 |
| 3 | status bar (packed `-side bottom`) | `$top.status` + 9 labels: `win sep1 stat sep2 temp sep3 sim sep4 state` | :1066-1078 |
| 4 | action strip (packed `-side right -fill y`) | `$top.strip` + 8 buttons `ana var out del netrun run stop plot` | :1086-1108 |
| 5 | body (packed last, `-fill both -expand 1`) | `$top.body` + 3 labelframes `vars ana outs` | :1137-1174 |
| 6 | theming + idle-colour capture | `ase::ui::apply_theme $top`; `idlebg($key)` from `.status.stat -background` | :1176-1180 |

**Toolbar.** The temperature entry is the window's only always-visible editable field. Its tooltip
is armed **before** the two binds and the `FocusOut` bind is `+`-appended, because `::balloon`
does a plain `bind` on `<FocusOut>` and would otherwise silently eat the commit (:1040-1055 —
this is issue 1391, measured). `<Return>` and `<FocusOut>` → `ase::ui::temp_commit` (:2069).

**Status bar** renders `<win#> | Status: <S> | T=<T> C | Simulator: <sim> | State: <view>`;
`ase::ui::status_text` (:7404) reassembles it for tests. Only `.stat` is coloured, by
`ase::ui::set_status` (:7597): `running`→orange/"Running", `ok`→Green/"Ready", `fail`→red/"Error",
default→`idlebg`/"Ready". The `Simulator:` segment is `ase::sim_label`, i.e. the *registered
simulator in force*, not the backend word (:7385, issue 1370).

**Action strip** — eight single-glyph buttons, `-width 5`, packed top-down:

| button | glyph | command | tooltip source |
|---|---|---|---|
| `.strip.ana` | `OP,TR` | `ase::ui::choose_analyses $key` (:1087) | `menu_path_choose_analyses` |
| `.strip.var` | `=` | `ase::ui::add_variable_dialog` (:1089) | `lbl_add_variable` |
| `.strip.out` | `-->` | `ase::ui::output_editor $key -1` (:1093) | `lbl_add_output` |
| `.strip.del` | `X` | `ase::ui::delete_selection` (:1095) | `lbl_delete_selection` |
| `.strip.netrun` | `N&>` | `ase::ui::do_run` (:1097) | `menu_path_netlist_and_run` |
| `.strip.run` | `>` | `ase::ui::do_run_existing` (:1099) | `menu_path_run` |
| `.strip.stop` | `!` | `ase::ui::do_stop` (:1101) | `menu_path_stop` |
| `.strip.plot` | `~` | `ase::ui::open_viewer` (:1103) | `menu_path_waveform_viewer` |

Tips are attached in **one loop** over `ase::ui::strip_tips` (:1129-1132 → :6090), deliberately so
that a ninth button without a tip entry reds the suite instead of shipping bare. Delay 300 ms.

### 1.3 The three panes

`ase::ui::build_pane {key top pane columns headings policy}` (:1272) is the single constructor.
Contract:

* `ttk::treeview $pf.tv -columns … -show headings -selectmode extended -height 8
  -style Ase.Treeview` (:1275-1277).
* Per column: `-width [ase::ui::colw $glyphs $h]`, `-minwidth [ase::ui::colw 0 $h]`,
  `-anchor $anchor`, `-stretch $stretch` (:1284-1286). `ase::ui::colw n head` (:1203) = *n* zeros
  of `AseEntryFont`, floored at the heading's own ink in `AseLabelFont` + 16 px of ttk heading
  padding.
* The `{glyphs stretch anchor}` triple per column is recorded in `colpolicy($pf.tv)` (:1289) so
  `ase::ui::retune_columns` (:1252) can re-derive widths when — and only when — the data font's
  size moves (called from `apply_theme`, :467).
* **Exactly one stretchy column per table**, and it is the content column; anything else ratchets
  under repeated resize (:1155-1162, measured).
* Vertical `$pf.sb` **and** horizontal `$pf.hsb` scrollbars, **gridded** (`grid remove`'d for the
  h-bar), shown/hidden by `ase::ui::pane_hscroll` (:1229) on an actual change of need.
* Bindings (:1305-1339): `<<TreeviewSelect>>`→`pane_selected`; `<Button-1>`→`pane_click` with a
  `break` when the click landed on a checkbox cell; `<Double-1>`→`pane_dblclick`;
  `<Button-3>`→`pane_ctx_post`. Context menu `$pf.ctx` = **Add… / Edit… / Delete** exactly.
* **Item ids are the row's 0-based index into the state list** — repopulate keeps them dense, so
  `identify`/`selection` results address the state directly (:1268-1271 header).

| pane | frame | state key | columns (id / heading / glyphs / stretch / anchor) | double-click | ctx Add… | ctx Edit… |
|---|---|---|---|---|---|---|
| Design Variables | `$top.body.vars` | `variables` | `name`/Name/14/0/w · `value`/Value/13/**1**/w | `variable_editor $key <idx>` | `add_variable_dialog` | `edit_variable_first` |
| Analyses | `$top.body.ana` | `analyses` | `num`/#/3/0/e · `type`/Type/6/0/w · `enable`/Enable/3/0/**center** · `args`/Arguments/28/**1**/w | `choose_analyses $key <row's TYPE>` | `choose_analyses` (no type) | `edit_analysis_first` |
| Outputs | `$top.body.outs` | `outputs` | `name`/Name/12/0/w · `value`/Value/11/**1**/w · `plot`/Plot/3/0/center · `save`/Save/3/0/center · `saveopts`/Save Options/10/0/w | `output_editor $key <idx>` | `output_editor $key -1` | `edit_output_first` |

Layout (:1141-1147): `vars` at row 0 col 0 **rowspan 2**; `ana` row 0 col 1; `outs` row 1 col 1;
`columnconfigure 0 -weight 1`, `1 -weight 2`; both rows weight 1. **There is no sash** — the split
is frozen at 1:2 horizontally and 1:1 vertically.

**Pane semantics.**
* `pane_selected` (:1347) enforces **single-pane selection**: selecting in one clears the other two,
  with a `selclear($key)` suppression flag so the clears don't cascade.
* `pane_click` (:1367) maps the x/y to a column name and, for `ana/enable` or `outs/plot|save`,
  calls `toggle_flag` and returns 1 so the caller `break`s. **A click on those columns edits the
  deck instead of selecting the row, with no confirm and no undo.**
* `toggle_flag` (:1389) flips a 0/1 field of one row, preserving every other key, then
  `ase::session_update` + `populate`.
* `pane_dblclick` (:1407): for `ana` it reads the row's **type** and passes only that to
  `choose_analyses` — **the row index is computed and thrown away** (:1418-1424). That single
  fact is why ASE-L cannot hold two analyses of the same type (see §2.9).
* `delete_selection` (:1441) scans the three panes for the one holding a selection, deletes those
  indices descending, commits, repopulates. Its own comment: "**No confirm anywhere in this
  path.**" There is no undo in the file (`grep -in undo` returns one unrelated comment).

**`ase::ui::populate` (:1998)** is the one repaint: it clears and refills all three treeviews from
`ase::session_state`, refills the temperature entry from `temperature` (default 27), then
`refresh_title`, `refresh_status`, `apply_theme $top` (:2040-2044). Cell renderers:

* variables → `name`, `ase::format_value value`
* analyses → `[expr {$i+1}]`, `type`, `ase::ui::chk_glyph enabled`, `ase::ui::arg_summary $row`
* outputs → `ase::ui::output_display_name`, `ase::format_value <result>`,
  `chk_glyph plot`, `chk_glyph save`, `ase::ui::save_options_cell $st $row`
* `ase::ui::chk_glyph` (:1990) = `☑` (U+2611) / `☐` (U+2610) — a **text glyph in a text cell**,
  not a widget: no keyboard reach, no focus, no disabled state.
* `ase::ui::refresh_output_values` (:2050) is the selection-preserving partial repaint; its only
  caller in the tree is `run_finished` (:7846).

### 1.4 The menubar, entry by entry

Nine cascades, built verbatim from the v2 spec (:818-1033). **No `-accelerator` anywhere in the
file (grep count 0). No mnemonics. No default buttons (grep `-default` = 0).**

| cascade | entry | command | line |
|---|---|---|---|
| **Launch** | `(placeholder)` (disabled); the cascade itself is `-state disabled` | — | 823-825 |
| **Session** | Design Window | `design_window` | 829 |
| | Load State | `load_state_dialog` | 834 |
| | Save State | `save_state_dialog` (always Save-As) | 836 |
| | *(separator)* / Close | `close_request` | 838-840 |
| **Setup** | Design… | `design_dialog` | 844 |
| | Model Files… | `model_files_dialog` | 846 |
| | Simulators… | `simulators_dialog` | 855 |
| **Analyses** | Choose… (`lbl_choose`) | `choose_analyses $key` | 863 |
| **Variables** | Edit… | `edit_variables` | 871 |
| **Outputs** | To Be Saved ▸ Select On Design | `select_on_design $key {save 1 plot 0}` | 880 |
| | To Be Plotted ▸ Select On Design | `select_on_design $key {save 1 plot 1}` | 884 |
| | Save All… (`lbl_save_all`) | `save_all_dialog` | 888 |
| **Simulation** | Netlist ▸ Recreate / Display | `do_netlist_recreate` / `view_netlist` | 894/896 |
| | Netlist and Run (`lbl_netlist_and_run`) | `do_run` | 903 |
| | Run (`lbl_run`) | `do_run_existing` | 905 |
| | Stop (`lbl_stop`) | `do_stop` | 907 |
| | Log | `show_log` | 909 |
| | Options… | `sim_options_dialog` | 910 |
| **Results** | Select… | `rsel_dialog` | 965 |
| | *(separator)* Direct Plot | `direct_plot` | 968 |
| | Annotate ▸ Operating Point info / DC Node Voltages / Transient Node Voltages (at cursor) | three **checkbuttons** over `::ase::ui::annot($key,op|volt|tran)`, built `-state disabled`, submenu `-postcommand ase::ui::annot_menu_sync` | 970-1007 |
| **Tools** | Waveform Viewer | `open_viewer` | 1031 |
| | Calculator | `calc::open` (no `$key` — per-process idempotent) | 1033 |

Menu **labels for five of the strip's eight buttons are minted once** in the `lbl_*` /
`menu_path_*` family (:5958-6068) and the menubar is built from those procs, so a tip and its
menu entry are literally the same string (issue 1391). `Analyses > Choose…` and the dialog title
`Choose Analyses` are *deliberately* two different spellings and that divergence is recorded, not
a bug to fix casually (:6014-6019).

Only three menu entries can ever grey out (the three Annotate checkbuttons, gated on
`ase::has_results`, `ase.tcl:7691`). `Stop` is black with nothing running and reports its refusal
into the CIW.

### 1.5 Run pipeline and the log window

* `do_run` (:7957): refuses a second launch while this session's results file is locked
  (`run_busy` :7921 → `ase::run_in_flight`), resolves the design, routes the design window if the
  design is not on the current window's hierarchy stack (`ase::stack_level`), then
  `ase::run $state [list ase::ui::run_finished $key]`.
* `do_run_existing` (:8053) skips netlisting entirely.
* `run_started` (:7897) → `log_open`, `log_clear`, `attach_trace`, `set_status running`.
* Live log: a `trace add variable ::execute(data,$id) write` (`attach_trace` :7712,
  `log_trace` :7730) pushes 1024-byte deltas into the log text.
* `run_finished` (:7846) appends the tail, prints co-simulation diagnostics, and on exit 0 sets
  the per-session `results` attr from `ase::last_result`, calls `refresh_output_values`,
  `set_status ok`, then `after idle` auto-plot and annotate refresh.
* **Log window** (`log_open` :7627) is a child toplevel `$top.logwin` with
  `text -height 24 -width 84 -state disabled -wrap none` and a **vertical scrollbar only**;
  Ctrl-W closes. It is opened and raised on **every** run.

---

## 2. How ANALYSES are presented today — the complete path

### 2.1 The state schema (the source of truth)

`ase::state_default` (`ase.tcl:502`) seeds every new session with **four rows, always**:

```tcl
analyses  {{type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 0}}
```

An analysis row is a plain dict: `type`, `enabled` (0/1), plus per-type argument keys. `version`
stays 1 when keys are added and `ase::state_load` (`ase.tcl:529`) merges the file **over** the
defaults, so **adding a new state key is backward- and forward-safe by construction**
(`ase.tcl:494-501` says so explicitly, and `tests/headless/fixtures/ase_state_v1_pre_cosim.state`
pins it). This is the single most important affordance for the plan: the state file can grow new
analysis types and new option keys without a migration.

### 2.2 The two field tables — and they disagree

| table | where | contents |
|---|---|---|
| `ase::ui::anaargs` | `ase_window.tcl:83` | `op {}`, `dc {source start stop step}`, `ac {points start stop dec}`, `tran {step stop}` |
| `ase::ui::chana_fields` | `ase_window.tcl:4527` | `dc {source start stop step}`, `ac {points start stop}`, `tran {step stop}`, anything else `{}` |

`anaargs` is *the Arguments-summary order*; `chana_fields` is *the dialog's quick-field set*. The
one difference is `dec` for `ac`: it is in the summary order but **not** in the dialog, and the
deck **hardwires the literal `dec`** (`ase.tcl:10964`). So `dec` is a key that can only be created
through the Options… sub-dialog and that nothing reads. `doc/claude/specs/ase_l.md:55` still shows
`dec 1` in its schema example.

### 2.3 The four doors into Choose Analyses

1. menu `Analyses > Choose…` → `choose_analyses $key` with no type (`ase_window.tcl:863`)
2. strip `OP,TR` → same (`:1087`)
3. Analyses-pane context `Add…` → same; context `Edit…` → `edit_analysis_first` (`:1324-1327`,
   `:4409`) which passes the **first selected row's type**
4. Analyses-pane double-click → `pane_dblclick` → `choose_analyses $key <that row's type>` (`:1418-1424`)

### 2.4 `ase::ui::choose_analyses` (:4549) — the dialog

```
.aseN.chana                       (dialog_frame, wm title "Choose Analyses")
 ├── .types            frame, row 0, columnspan 2, -sticky w
 │    ├── .op .dc .ac .tran       radiobutton, -variable ::ase::ui::dlg($key,antype),
 │    │                           -value <t>, -command chana_show, packed -side left -padx 4
 ├── .enable           checkbutton "Enable", row 1, -variable ::ase::ui::dlg($key,anen)
 ├── .l<field>/.<field> label+entry pairs on rows 2..  (built by chana_show)
 ├── .opts             button "Options…"  -> chana_options,   FIXED row 8
 └── .btns             dialog_buttons OK/Cancel,              FIXED row 9
```

* `type` defaults to **`op`** when the caller passes none (:4552) — regardless of what is enabled.
* The radio row is `pack -side left` inside one frame: **it will run off the right edge past about
  eight types.**
* Rows 2..7 are the only free grid rows; `Options…` at 8 and the button bar at 9 are hardcoded
  (:4573-4576, and the comment says the high fixed rows exist so rebuilds never collide).
* **No `focus` call anywhere in `choose_analyses` or `chana_show`** — every other editor in the
  file focuses its first entry (`:2185`, `:2237`, `:2317`, `:4834`, `:5527`). Focus lands on the
  toplevel.
* **No Apply button.** OK commits and closes; Cancel discards.

### 2.5 `ase::ui::chana_show` (:4581) — the per-type form swap

```tcl
foreach f {source start stop step points} {          ;# :4589  HARDCODED LIST
  catch {destroy $w.$f} ; catch {destroy $w.l$f}
}
set row [ase::ui::chana_row $key $type]              ;# FIRST state row of that type
set dlg($key,anen) …enabled…
set r 2
foreach f [ase::ui::chana_fields $type] {
  set e [ase::ui::dialog_row $w $r "[string totitle $f]:" $f]
  $e insert 0 [ase::state_get $row $f]
  bind $e <Return> [list ase::ui::chana_ok $key]
  incr r
}
ase::ui::apply_theme $w
```

Three consequences a future session must know:

* **The destroy list is a hardcoded five names, not `chana_fields`.** Add a field named `uic` to
  any type and switching types will leave `$w.uic` and `$w.luic` gridded on the form, showing the
  previous type's value. This is the single sharpest trap in the analysis code.
* **Switching type discards what you typed** — the form is rebuilt from state every time. This is
  a *recorded decision* (D4, comment at :4558-4560: "in-form edits of the previous type are
  DISCARDED — deterministic, no hidden multi-type writes"). Reversing it needs the user's ruling.
* Field labels are generated as `[string totitle $f]:` — so `points` renders `Points:` with no
  unit and no hint that the number means *points per decade*.
* `ase::ui::chana_row` (:4538) returns the **FIRST** state row of the type, or a fresh
  `{type <t> enabled 0}` stub.

### 2.6 `ase::ui::chana_ok` (:4608) — validation and commit

1. Harvest `[string trim [$w.$f get]]` for every field in `chana_fields $type` that exists.
2. **If Enable is ticked, every quick field must be non-empty** (:4622-4628). Otherwise:
   `ase::echo "ase: enabled $type analysis needs a non-empty '$f'" error` and `return` — the
   dialog stays up **with no visible change**. The reason for the rule is that `render_deck` does
   a bare `dict get` and would blow up mid-run.
3. Find the **first** row whose `type` matches; if none, start `{type <t>}`.
4. `dict set row enabled $en`; then for each harvested field: **empty value DELETES the key**,
   non-empty sets it. Every other key of the row survives byte-for-byte.
5. `lset`/`lappend`, `ase::session_update`, `ase::ui::populate`, `chana_cancel` (destroy + clear
   `dlg($key,antype|anen|anextra)`).

There is **no type checking, no range checking, no unit parsing** — `stop` accepts `banana`.

### 2.7 `ase::ui::chana_options` (:4668) — the extra-key editor

A nested toplevel `$top.chana.x` (a Tk child of the dialog, so it dies with it), titled
`Analysis Options (<type>)`. Contents: a 2-column `ttk::treeview {name value}`, a Name/Value entry
pair with **Add** and **Delete** buttons, and OK/Cancel. The editable set is
`row − {type enabled} − chana_fields(type)`, held in `dlg($key,anextra)`;
`chana_x_ok` (:4768) **replaces** the row's whole extra-key set.

> ⚠ **These keys never reach the deck.** The proc header says so (:4661-4665: "DECK emission of
> extra keys stays deferred (v1 limit, documented here)") and `FINDINGS.md`
> `analysis-options-is-a-dead-form` measured it end to end: typed `uic 1 tstart 5u tmax 1n`,
> `arg_summary` rendered `step=10n stop=200u uic=1 tstart=5u tmax=1n`, and the emitted line was
> `tran 10n 200u`. **The window reports a simulation setting that is not in force.** Across 105
> committed `.state` files and 420 analysis rows in the tree, not one carries an extra key.

### 2.8 The two pure cell renderers

`ase::ui::arg_summary {row}` (:1521):

```tcl
order = anaargs[type]                       ;# {} for op
for a in order:  if row has a -> "a=v"
for k,v in row:  skip type/enabled and anything already in order -> "k=v"
return [join $out " "]
```

So the Arguments column shows quick fields in schema order followed by every unknown key in dict
order — including the dead Options… keys, with nothing marking them as inert.

`ase::ui::save_options_cell {state row}` (:1507) belongs to the **Outputs** pane, not the analyses
pane: it classifies the row's expression with `ase::ui::output_kind` (:1492 — `v(`→voltage,
`i(` or `@`→current, else other) and returns `allv` when the state's `save_all_v` blanket is on
for a voltage, `alli` when `save_all_i` is on for a current, else blank. The blankets are written
by `Outputs > Save All…` (`save_all_dialog` :6179) and map in the deck to `.save all` and
`.options savecurrents`.

### 2.9 The `ase.tcl` side — what actually reaches ngspice

`ase::backend::ngspice::render_deck` (`ase.tcl:10521`), inside the `.control` block:

```tcl
if {[ase::n_enabled_analyses $state] > 0} { lappend lines "set appendwrite" }   ;# :10845
set anorder {op dc ac tran}                                                     ;# :10863
…
if {[llength $optier_ctl] || [llength $optier_post]} { set anorder {dc ac tran op} }  ;# :10938
foreach type $anorder {
  foreach a analyses-of-that-type-that-are-enabled {
    switch -- $type {
      op   { lappend lines "op" }                                               ;# :10951
      dc   { lappend lines "dc <source> <start> <stop> <step>" }                ;# :10961
      ac   { lappend lines "ac dec <points> <start> <stop>" }                   ;# :10964
      tran { lappend lines "tran <step> <stop>" }                               ;# :10966
    }
    …sim_status_guard… ; "remzerovec" ; "write <raw>" ; print lines at the anchor
  }
}
```

* **`dec` is a literal.** No `lin`, no `oct`. No `tstart`, no `tmax`, no `uic`. No second sweep
  source for `dc`. The whole analysis line is a 3-to-5-token template.
* **There is no `default` arm.** A state carrying `{type noise enabled 1 …}` renders a `.control`
  block with **no analysis at all**, exit 0, an empty raw — while the pane shows the row ticked.
  (`FINDINGS.md` `no-noise-analysis-and-silent-drop` measured exactly this.)
* `ase::n_enabled_analyses` (`ase.tcl:3695`) is the count used to decide `set appendwrite`.
* **The print anchor** (`ase.tcl:10925-10933`) is `foreach type {dc ac tran op}` last-enabled-wins,
  i.e. `op` when `op` is enabled. The Outputs pane's Value column is filled from those `print`
  lines, so with op+tran enabled the column shows the **operating point's** numbers under a
  heading that says only "Value" (`ase.tcl:10905-10924` carries the 1243 ruling and its reasoning).
* `ase::plot_sim_type` (`ase.tcl:7643`) is a **separate** order, `foreach {op dc ac tran}`
  last-wins, and decides which plot the waveform viewer opens on — transient preferred. Its own
  comment warns that it deliberately no longer mirrors the emit order.

### 2.10 The complete edit list for adding one analysis type

Seven places, and missing any one of them fails silently:

1. `ase.tcl:502` — `state_default`'s `analyses` seed (optional; see §7.10)
2. `ase_window.tcl:83` — `ase::ui::anaargs` (drives the Arguments column order)
3. `ase_window.tcl:4527` — `ase::ui::chana_fields` (drives the form)
4. `ase_window.tcl:4551` — `foreach t {op dc ac tran}` (the radio row)
5. `ase_window.tcl:4589` — **the hardcoded destroy list in `chana_show`**
6. `ase.tcl:10863` (+ `:10938`) — `anorder`, and the `switch` arm that emits the line
7. `ase.tcl:7643` — `plot_sim_type`'s preference order, if the new type produces a plot

Plus: `tests/headless/test_ase_dialogs.tcl` G1/G2/GE4/GE5 drive `$top.chana.types.tran` and
`$top.chana.<field>` **by path**, and `tests/headless/test_ase_window.tcl` W1p asserts the four
seeded analyses rows numbered `1 2 3 4`.

---

## 3. The reusable UI vocabulary

### 3.1 Dialog scaffolding — the contracts

| proc | line | contract |
|---|---|---|
| `ase::ui::dialog_frame {w title}` | :2113 | `catch destroy` the path, `toplevel`, `wm title`, `grid columnconfigure $w 1 -weight 1`, return `$w`. **Everything is gridded into `$w` directly**, so fields live at deterministic paths `$w.<name>`. No `wm transient`, no `wm geometry`, no `wm protocol`. |
| `ase::ui::dialog_row {w row label ename}` | :2121 | creates `label $w.l<ename>` (`-font AseLabelFont -anchor w`, col 0) + `entry $w.<ename>` (`-width 26 -font AseEntryFont`, col 1 `-sticky we`). Returns the entry path. **The label path is `$w.l<ename>` — that is how a field relabels itself under a mode selector.** |
| `ase::ui::dialog_buttons {w row okcmd cancelcmd}` | :2129 | `frame $w.btns` + `button $w.btns.proceed -text OK` packed left + `button $w.btns.cancel -text Cancel` packed **right**, gridded columnspan 2; then calls `bind_dialog_esc` so **every scaffold dialog gets Esc for free**. |
| `ase::ui::bind_dialog_esc {w cancelcmd}` | :2106 | `bind $w <Key-Escape> $cancelcmd`. Bound on the **toplevel**, so Esc inside any child entry bubbles up. Never a bare `destroy` — always the same command as Cancel, so per-key records are cleaned. |
| `ase::ui::dialog_close_protocol {w cmd}` | :6498 | `wm protocol $w WM_DELETE_WINDOW $cmd`. **Used by exactly one dialog** (`save_all_dialog`). Every other dialog's title-bar X bare-destroys and leaks its `dlg()` records — this is documented at :6224-6234 as a deliberate scoping decision (widening it is filed as issue 0651). |
| `ase::ui::confirm {key title msg oncmd}` | :4494 | modeless confirm at `$top.confirm`: message label, OK/Cancel, `<Return>`→OK, Esc→Cancel-destroy, `apply_theme`, `focus $w.btns.proceed`. `confirm_ok` (:4517) destroys then `uplevel #0 $oncmd`. |

### 3.2 Modality

**Everything is modeless** — the file header states it as the reason the dialogs are test-drivable
(:19-21). The only three modal points in the whole file:

* `ask_save_close` (:713) — `grab set` + `tkwait window` (:747-749), the dirty-session prompt.
* `save_state_modal` (:761) — `tkwait window` on the (modeless) Save-As form (:767).
* `bus_dialog` (:1934) — `grab set` + `tkwait` (:1941-1943), the bus-bit picker.

A new modal analysis dialog **would hang the headless suites**. Do not introduce one.

### 3.3 Per-window records

`dlg($key,<name>)` (`variable dlg`, :107) is the array every dialog parks its transient state in.
The discipline, stated in the header and enforced everywhere: **cleaned on proceed AND on cancel
AND in `ase::ui::close`** (:687). Known names today: `antype anen anextra` (Choose Analyses),
`allv alli opparams touched` (Save All), `dlib dcell dview` (Design), `salib` (Save-As),
`models simopt` (list dialogs), `simnames simrow simns` (Simulators), `rsel*` (Results Select),
`saveas_result`. `edrow($key,var|out)` and `edchk($key,plot|save)` are the row editors' own.

### 3.4 Tables and lists — three existing engines to copy from

1. **`build_pane`** (:1272) — the main-window pane engine. Copy it for any new multi-column table.
2. **`listdlg_open/fill/editor/ok/delete`** (:5743-5930) — a *config-driven* two-column list
   dialog. The config lives in `variable listdlg` (:128) as
   `{win skey cols heads ed edtitle}` and today has exactly two entries, `models` and `simopt`.
   **Adding a third entry is ~6 lines**; the engine gives you table, context menu Add…/Edit…/Delete,
   the `<Delete>` key, a row editor built from `dialog_row`, and **immediate commit per mutation**
   (decision D15 — no OK on the list itself, only a Close button).
3. **`simulators_dialog`** (:4989) — the richest form in the file, and the best template for a
   real analysis form: a stretch-policy treeview, a **readonly `ttk::combobox` as a mode selector**
   (`$w.use`), an **in-dialog status label** (`$w.status`, `-wraplength 560`), an explanatory
   label (`$w.where`), a real **Add… / Edit… / Remove / Close button row**, and grid weights that
   make the table the growing element.

### 3.5 The rich row editor — `simdlg_editor` (:5470)

This is the one place in ASE-L that already looks like an ADE form, and every element the plan
needs is in it:

* `dialog_frame` + two `dialog_row`s, plus a **Browse…** button on **column 2** of the same rows
  (`grid $w.browse -row 1 -column 2`) — the scaffold tolerates a third column.
* A `label $w.lcasemode` + **readonly `ttk::combobox $w.casemode`** whose `-values` are rebuilt
  from live capability data (`simdlg_case_show` :5332), with the current pick **kept and marked**
  rather than silently moved when the underlying answer changes.
* A **Detect** button beside it (row 2 col 2) that performs the measurement on demand.
* A `checkbutton $w.nospiceinit` bound to `dlg($key,simns)`.
* A `label $w.status -wraplength 420` — **the in-dialog feedback surface**, empty until there is
  something to say.
* **The one entry validation in the file**: `$ep configure -validate key -validatecommand
  [list ase::ui::simdlg_path_validate $key]` (:5518), whose handler defers the real work with
  `after idle` because a validate command runs *before* the entry's content changes (:5364-5372,
  measured). Validation also fires for programmatic insert, which is how Browse… is covered by
  the same mechanism.
* `dialog_buttons $w 5`, `apply_theme $w`, then `focus`.

### 3.6 Feedback surfaces

| mechanism | proc | notes |
|---|---|---|
| CIW / notice channel | `ase::echo` (`ase.tcl:298`) | where **every** validation refusal in the editing loop goes today. The dialog itself says nothing. |
| in-dialog status line | `ase::ui::rsel_status` (:3952) | keeps the sentence in `dlg($key,rselstatus)` **whether or not a widget exists**, so it is assertable headlessly. This is the shape to generalise. |
| debounced preview | `rsel_preview_soon` (:3941) | `after 250`, cancelled on Return/Escape and by the commit path — the recorded race and its fix are at :3900-3931. |
| fixed per-widget tooltip | `::balloon w text 1 0 300` (`xschem.tcl:14829`) | bakes one string in at attach time. Used for the temperature entry and all eight strip buttons. |
| clipping-aware tooltip | `balloon_clipped` (`xschem.tcl:14935`) | shows a tip only when the text is actually clipped. **Not yet used by ASE-L.** |
| per-row tooltip | `rsel_tip` / `rsel_tip_show` / `rsel_tip_cancel` (:4188-4211) | `<Motion>` handler → `identify row/column` → `balloon_show`. The precedent for per-cell tips on a treeview. |
| status segment | `set_status key running|ok|fail|<other>` (:7597) | the only colour-carrying feedback in the window. |
| minted labels | `lbl_*` / `menu_path_*` (:5958-6068) | **house rule: a user-facing string is minted once and read, never typed twice.** Issue 0661 is the recorded cost of breaking it. |

### 3.7 Combobox / listbox helpers

* `ase::ui::combo_filter {cb full}` (:4452) — type-to-filter: prefix-match the stored full list
  against typed text, fall back to the full list on no match. Driven from `<KeyRelease>`
  (`design_dialog` :4830).
* `ase::ui::lb_sel {lb}` (:4466) and `lb_select_value {lb val}` (:4477) — listbox helpers.
* Comboboxes must carry `-style Ase.TCombobox` **and** `-font AseEntryFont`; their popdown listbox
  font is set through a **per-window option-database entry** (`_combobox_popdown_font` :429) —
  the only pattern that works is `*ase<N>*Listbox.font`, measured (:405-427).

---

## 4. The theming layer — the contract a new widget must satisfy

* `ase::palette {?name?}` (:186) — **pure read**, returns the 9-colour locked palette:
  `panel #f2f2f2`, `table #ffffff`, `header #e8e8e8`, `accent #8b0000`, `fieldfg #000000`,
  `selectbg #4a6984`, `selectfg #ffffff`, `disabledbg #d9d9d9`, `disabledfg #a3a3a3`.
  **There is no error/warning/success colour in the palette.** (`accent` is the pane-title
  maroon and is documented in `FINDINGS.md` as "means two different things at once".)
* `ase::shade {c}` (:211) — one hover/trough step, ±40/255, direction flipped on a dark ground.
* `ase::theme {?name?}` (:306) — **not** a pure read: it reconfigures four named fonts and the
  shared ttk styles, then returns the palette. Call it when widgets are about to be created;
  call `ase::palette` when only a colour is wanted.
* The four type roles (issue 1398), **derived, no family literal**:
  `AseEntryFont` (data: cells, entries, combos), `AseBodyFont` (chrome: menus, buttons, prose),
  `AseLabelFont` (**headings only**: labelframe titles + column headings, bold),
  `AseMonoFont` (machine text: the log). Copied from `TkDefaultFont`/`TkFixedFont` with
  **`font configure`, never `font actual`** (:319-329, measured: `actual` normalises pixels to
  points and drifts 33 % with `tk scaling`).
* Size knob: `::ase_font_size` (`ase::font_size` :284), integer 6..32, **refused not clamped**
  when out of band; `0`/unset = follow `TkDefaultFont`. Read on **every** `ase::theme` call, so
  it is order-independent and rescales open windows.
* `ase::_mkfont` (:260) create-or-**reconfigure**, with a no-op guard that is load-bearing:
  `apply_theme` runs on every state mutation across ~53 widgets, and an unguarded
  `font configure` fires Tk's font-changed cascade every time.
* Styles configured: `Ase.TCombobox` (+ a **state `map`** for `readonly`/`disabled` — declaring
  only the base `-fieldbackground` leaves readonly comboboxes painted the palette's *disabled*
  grey, a trap the Calculator already measured), `Ase.Treeview` (+ map,
  `-rowheight [font metrics AseEntryFont -linespace]+4`), `Ase.Treeview.Heading`.
* `ase::ui::apply_theme {w}` (:462) = `ase::theme` once + `retune_columns` + the recursive
  `_theme_widget`.
* **`_theme_widget` (:481) switches on `winfo class` and handles exactly:**
  `Toplevel`, `Frame`, `Labelframe`, `Menu`, `Button`, `Checkbutton`, `Radiobutton`, `Label`,
  `Entry`, `Listbox`, `Text`, `TCombobox`, `Treeview`, `Scrollbar`.
  **It returns early for `*.balloon`** (a live tooltip is not ours to repaint, :483-490).

  > ⚠ **Any ttk widget class not in that list gets no theming at all** — `TFrame`, `TLabel`,
  > `TButton`, `TCheckbutton`, `TRadiobutton`, `TEntry`, `TSpinbox`, `TNotebook`,
  > `TPanedwindow`, `TSeparator`, `TScrollbar`, `Scale`, `Spinbox`, `Canvas`, `PanedWindow`.
  > `ttk::panedwindow`, `ttk::label` and `ttk::scrollbar` are already used in `load_state_dialog`
  > (:6613-6621) and are *not* themed — `FINDINGS.md` records exactly that as a defect
  > ("the Load State browser's headers and sashes are the #d9d9d9 the palette exists to escape").
  > **A new analysis form built out of ttk widgets will be visibly un-themed unless the switch
  > grows arms for them.** Every arm that writes a background must also write a foreground —
  > xschem's shipped `dark_gui_colorscheme 1` (`xschem.tcl:19078`) otherwise wins at 1.12:1.

---

## 5. Constraints — what this codebase makes easy, and what it makes hard

**Tk/Tcl available: 8.6.17** (measured: `tclsh` reports `8.6.17`, `package require Tk` → `8.6.17`).
So `ttk::notebook`, `ttk::spinbox`, `ttk::separator`, `ttk::progressbar`, `ttk::labelframe`,
`ttk::radiobutton`, `ttk::checkbutton` and `ttk::entry` **all exist**. The constraint is not the
toolkit; it is this file's conventions and its test surface.

### 5.1 Widget classes already used in `ase_window.tcl` (constructor counts, snapshot)

`button` 37 · `label` 29 · `frame` 17 · `menu` 16 · `toplevel` 11 · `scrollbar` 7 ·
`checkbutton` 7 · `ttk::treeview` 5 · `ttk::style` 5 · `labelframe` 5 · `entry` 5 ·
`ttk::combobox` 4 · `listbox` 2 · `ttk::scrollbar` 1 · `ttk::panedwindow` 1 · `ttk::label` 1 ·
`text` 1 · `radiobutton` 1.

**Everything else would be new to this file.** Notably absent: `ttk::notebook`, `ttk::spinbox`,
`ttk::separator`, `ttk::progressbar`, `ttk::entry`, `canvas`, `scale`.

### 5.2 Easy (a precedent exists in this file, copy it)

* A new modeless dialog of label+entry rows — `dialog_frame`/`dialog_row`/`dialog_buttons`.
* A discrete-choice control — **readonly `ttk::combobox`** with `-style Ase.TCombobox`
  (`simdlg_case_show` :5332 rebuilds its `-values` live). *This is the widget the ADE
  "Points Per Decade / Step Size / Number of Steps" selector maps onto.*
* Relabelling a field when a mode changes — `dialog_row` names the label `$w.l<ename>`, so
  `$w.lpoints configure -text "Points/decade:"` is one line.
* A boolean — `checkbutton` bound to `::ase::ui::dlg($key,<name>)`.
* A third widget on a form row — grid it at `-column 2` (`simdlg_editor` `$w.browse`, `$w.detect`).
* A multi-column table with sane column policy — `build_pane` or the `listdlg` config dict.
* A per-widget tooltip — `catch {::balloon $w <text> 1 0 300}`.
* A per-row/per-cell tooltip — copy `rsel_tip` (:4188).
* An in-dialog status line — copy `rsel_status` (:3952); grid it at a **high fixed row** so no
  other row moves (Choose Analyses already reserves 8 and 9 for exactly this reason).
* Key-level entry validation — `-validate key -validatecommand`, with `after idle` (:5518, :5364).
* A file picker — `tk_getOpenFile` (`simdlg_browse` :5545). **Untestable headlessly** — it grabs
  the display; the tree's convention is to assert the *body* instead (row S14a).
* Adding a new state key — `state_load` merges over `state_default`, so it is free (§2.1).
* Adding a `listdlg` entry (e.g. `includes`, `pre_commands`) — ~6 lines of config dict.

### 5.3 Hard, or genuinely new ground

* **Tabs / notebook.** `ttk::notebook` is used **nowhere in the entire xschem tree** — the only
  occurrence is a comment in `wave_viewer.tcl:18147` explaining why it was *not* used (it manages
  its own tab bar geometry). The tree's tab idiom is a hand-built row of buttons. A notebook in
  ASE-L would be new, would need a `TNotebook` theming arm, and would break the "deterministic
  widget paths" convention the suites depend on unless paths are chosen carefully.
* **Scrolling form.** There is no scrollable-frame idiom anywhere in `ase_window.tcl`. A form
  taller than the screen needs the `canvas` + inner `frame` + `<Configure>` dance built from
  scratch, plus a `Canvas` theming arm. Nothing in this file has ever done it.
* **A sash between the three panes.** `ttk::panedwindow` exists in the file (Load State, :6613)
  but the body is a plain `grid` with fixed weights (:1141-1147). Making the panes resizable is a
  layout change to `build`, which every W1p-family check observes.
* **Dynamic forms beyond six rows.** `chana_show` rebuilds rows 2..; `Options…` is nailed to row 8
  and the button bar to row 9 (:4573-4576). **Seven or more quick fields collide.** Either move
  those two to computed rows (and update `test_ase_dialogs.tcl`'s grid-row helper) or nest the
  fields in a sub-frame that occupies one row.
* **Validation feedback.** There is no per-field marking anywhere: no invalid style, no red
  border, no error colour in the palette, no `-invalidcommand` use. Refusals go to the CIW and the
  dialog "does nothing" (measured in `FINDINGS.md` `refusals-appear-in-a-different-window`).
* **Unit-suffix entry.** Nothing parses SPICE suffixes. `ase::format_value` /
  `ase::format_value_num` (`ase.tcl:419`/`430`) render a *number* into engineering notation for
  **display only**, gated on `::ase_eng_notation`, with the suffix table
  `f p n u m (none) k Meg G T`. There is no inverse. `temp_commit` (:2069) uses
  `string is double -strict`, so `27degC` is refused; analysis quick fields are **not validated at
  all** and go into the deck verbatim, which is why `10n` works today.
* **Keyboard.** Zero accelerators, zero mnemonics, zero default buttons (grep counts above). The
  Enable/Plot/Save cells are glyphs in a text column and cannot be reached by any key.
* **Undo / confirm.** Neither exists. `ase::session_revert` (`ase.tcl:9475`) works and is wired to
  `ase::ui::revert_state` (:7454), which **has no menu entry**.
* **Geometry.** `wm geometry` and `wm minsize` do not occur once in the file (grep = 0).
  `wm transient` occurs twice and only for the two modals (:721 `ask_save_close`, :1853
  `bus_dialog`). Every dialog therefore lands wherever the WM puts it and can sink behind its
  parent. Fixing this centrally in `dialog_frame` touches ~10 dialogs at once.
* **The theme walk is on the hot path.** `populate` ends in `apply_theme $top` (:2044), so every
  checkbox click re-walks ~53 widgets. Anything expensive added to a themed widget's creation is
  paid on every state mutation.

### 5.4 The test surface a change must survive

| suite | what it pins |
|---|---|
| `tests/headless/test_ase_window.tcl` | **W1p**: exactly three panes; the three column lists verbatim; four seeded analyses rows numbered `1 2 3 4`; blank Value / Save Options pre-run; `-style Ase.Treeview`; the heading colour; "no inline add/del buttons under the panes". **W1f2/W1f3/W1f6**: the font ladder and the derived column widths (relations against `font measure`, never pixels). **D1398g**: no column ratchet over four resize cycles. **W1m**: the v2 menu tree labels. **W1s1/W1s2**: every strip button carries a tip, read back off the live widget. |
| `tests/headless/test_ase_dialogs.tcl` | **G1/G2**: Choose Analyses opens from menu / strip / double-click; dc quick fields round-trip; `$top.chana.types.tran` invoked by path; Return on `$top.chana.step` closes. **GE4/GE5**: Esc dismisses `.chana` and the nested `.chana.x` independently. Drives everything **by widget path**. |
| `tests/headless/test_ase_core.tcl` | **D1/D2**: byte-exact deck goldens. |
| `tests/headless/test_ase_persist.tcl` | state round-trip, incl. `arg_summary` output. |
| the 105 committed `.state` files | must keep round-tripping byte-identically (the `ase::omit_if_empty` machinery exists to keep new keys out of the serialised file when they carry their default). |

**Rule of thumb:** *adding* a widget path is additive and safe; *moving* one reds. Adding a row in
the middle of a gridded dialog moves the rows below it — which is why Choose Analyses puts
`Options…` and the buttons at fixed rows 8 and 9.

### 5.5 House rules from `CLAUDE.md` and the file itself

* **Every new user-facing sentence or label is the user's to ratify** — record it with
  `tests/headless/owed.sh add rule <id>`, do not mint it silently.
* **Mint a label once** (`lbl_*`) and read it everywhere; issue 0661 is the cost of not doing so.
* **One question at a time** when consulting the user (pinned memory).
* **Issue numbers come only from `doc/claude/issues/NUMBERING.md`.**
* **Never a bare `xschem` on PATH** — always `./src/xschem`, and route GUI runs through
  `tests/headless/devdisplay.sh`.

---

## 6. "Better than Cadence ADE-L", concretely, in *this* toolkit

ADE-L's *Choosing Analyses* form, behaviour by behaviour, against what exists here.

| # | ADE-L behaviour | ASE-L today | reachable here? | cost / collision |
|---|---|---|---|---|
| 1 | **Analysis type row** — every analysis the attached simulator declares (tran dc ac noise xf sens dcmatch stb pz sp envlp pss pac …), as a wrapped radio grid | four radios `op dc ac tran`, `pack -side left` in one frame (:4551-4557) | **yes, trivially** — but `pack -side left` overflows past ~8 types | switch to `grid` wrap or a two-row layout; `test_ase_dialogs.tcl` drives `.chana.types.tran` by path, so *adding* siblings is safe |
| 2 | **Per-analysis form that swaps in place** | `chana_show` destroy+rebuild (:4581) | **already have it** | ⚠ the destroy list is a hardcoded 5 names (:4589) and rows 8/9 are fixed |
| 3 | **Enabled checkbox on the form** | `$w.enable` checkbutton (:4566) | already have it | — |
| 4 | **"Enabled" column in the main list** | `enable` column with `☑`/`☐` + click-to-toggle (:1167, :1367-1387) | already have it | it is a text glyph, not a widget: no keyboard reach, no undo, and a stray click in a 63 px column silently edits the deck |
| 5 | **Sweep variable / range / step triple with a mode selector** ("Points Per Decade" / "Step Size" / "Number of Steps"; Start-Stop vs Center-Span) | **absent.** `dc {source start stop step}`, `ac {points start stop}` with `dec` hardwired in the deck (`ase.tcl:10964`) | **yes** — readonly `ttk::combobox` (idiom at :5332) + `$w.l<field> configure -text` to relabel | needs a new `sweep` state key, a deck-emit change, and **new user-facing labels → a ruling** |
| 6 | **Options… sub-dialog of typed simulator options** | a free-text name/value table whose keys **never reach the deck** (:4668, measured) | yes, but it must become *typed and emitted*, or be honestly labelled inert | this is the CRITICAL correctness item, not a feature: the window currently reports settings that are not in force |
| 7 | **Apply** (commit without closing, so several analyses are set up in one visit) | **absent** — OK/Cancel only | yes: a third button running `chana_ok`'s commit without the teardown | moves `dialog_buttons`' geometry; `GE4` reads the button bar |
| 8 | **Per-type form memory across type switches** | **absent by decision D4** (:4558) | yes: cache the harvested fields in `dlg($key,anform,<type>)` per dialog lifetime | **reverses a recorded decision → the user's ruling** |
| 9 | **Several analyses of the same type** (two dc sweeps, VIN and temperature) | **impossible**: `chana_ok` addresses the FIRST row of the type (:4620-4626) and `pane_dblclick` discards the row index (:1418-1424) | yes — pass the index through and key the dialog on it | `test_ase_dialogs.tcl` assumes first-row-of-type addressing |
| 10 | **List starts empty; holds exactly the analyses you chose, in order** | four rows seeded always (`ase.tcl:512`), two of them permanently blank | yes — seed `{}` | changes what a brand-new session looks like → **ruling**; W1p asserts rows `1 2 3 4` |
| 11 | **Field-level rejection reported on the form, next to the field** | refusal goes to the CIW; the dialog sits there (:4622-4628) | yes — generalise `rsel_status` into `dialog_status $w <msg>` at a high fixed row | the sentences already exist, so no new copy to ratify |
| 12 | **Unit-bearing, typed fields; nothing is free text** | everything is free text; only "non-empty when enabled" is checked | partially — `-validate key` exists as an idiom (:5518); a suffix parser would be new | a *typed* field set is what makes #6 safe |
| 13 | **Sweep-variable picker from the design** | absent for analyses — **but** `select_on_design` (:2408) already turns a schematic click into `v(net)`/`i(inst)` for OUTPUTS, with hierarchy qualification (`sod_qualify` :1739) and bus-bit picking (`bus_dialog` :1934) | **yes, and this is the cheapest genuine ADE-beater**: point the same click mode at a *source instance* to fill `dc`'s Source field | ADE-L makes you type that name too |
| 14 | **Analyses run in list order** | fixed `anorder {op dc ac tran}`, re-ordered to `{dc ac tran op}` when device-OP requests are in play (`ase.tcl:10863`, `:10938`) | possible, but the reorder exists for a measured reason (ngspice's save list is sticky forward-only) | do not touch without reading the 0964 comment block |
| 15 | **The setup travels with the cellview** | already true and arguably better: a `.state` view in the library, multiple states per cell, Load/Save State browsers | — | — |

### 6.1 What "better than ADE-L" would have to mean here, concretely

1. **Nothing on the form may fail to reach the deck.** ADE-L has *no* untyped escape hatch;
   ASE-L has one and it lies. Either every key emits, or the form says it does not. This is the
   one item that is a correctness defect rather than a feature gap.
2. **The type list comes from the simulator, not from a literal.** There is already a capability
   probe with a cached, timeout-bounded answer (`ase::sim_capabilities` `ase.tcl:2858`,
   `ase::backend::ngspice::capabilities` `ase.tcl:11325`, `ase::sim_caps_have` `ase.tcl:3043`) and
   its results are already rendered as a live combobox `-values` list (`simdlg_case_show` :5332).
   Extending the probe with the analysis set the binary supports is *precedented plumbing*, and it
   is exactly what would put ASE-L ahead of a hardcoded ADE analysis list.
3. **Every field is typed and named for what the number means** — "Points per decade", not
   "Points"; a sweep-type selector that relabels its neighbour. `dialog_row`'s `$w.l<ename>` makes
   the relabel a one-liner.
4. **A refusal appears where the typing is.** Generalise `rsel_status`; keep the `ase::echo` line
   for the action log and headless callers.
5. **Nothing is one unconfirmed click from gone.** `ase::ui::confirm` already exists;
   `ase::session_revert` already works and only lacks a menu entry.
6. **Pick from the design instead of typing** — the sweep source, the noise output node, the noise
   input source. The click-mode machinery is built, hierarchy-aware and bus-aware.
7. **The analysis you are looking at is the analysis whose numbers you see.** Today the Outputs
   Value column silently shows the operating point when op+tran are both enabled
   (`ase.tcl:10905-10933`) under a heading that says only "Value".
8. **Keyboard-complete.** ADE-L is mouse-heavy; a Tk window with accelerators, mnemonics, a
   default button, and Tab-reachable Enable/Plot/Save toggles would be plainly better. Note the
   existing hazard: the destructive action strip sits at the **front** of the tab chain.

---

## 7. Gaps, unknowns, and what another agent must confirm

* **The file is moving.** `ase_window.tcl` gained 115 lines during this read. Re-derive every line
  number before quoting one, and re-read `doc/claude/ase_l_ux_batch/PLAN.md` + `LEDGER.md` to see
  what has already landed — several findings I cite as open (fonts, column ratchet, h-scrollbar)
  were being fixed *while I read*.
* **I did not run the GUI.** Read-only mandate plus the GUI gate. Every "measured" claim I quote is
  the UX batch's own measurement, attributed as such; every structural claim is mine, from source.
* **Which ngspice analyses exist and what each one's option surface is** is a different agent's
  area. This dossier says only how the GUI would carry them.
* **Whether the capability probe can be extended to report an analysis set** — I read the probe's
  three decks (`ase.tcl:11325-11400`) and they measure `usable`/`appendwrite`/`hier`/`blanket`/
  `altshow`/`casemode`. Whether ngspice can be asked "what analyses do you support" at all is
  unanswered here.
* **Unratified decisions the plan must put to the user, one at a time**: reversing D4
  (form memory across type switches); seeding `analyses {}` instead of four rows; every new field
  label and every new sentence; whether `Options…` becomes typed-and-emitted or is labelled inert;
  whether the Analyses pane gains row identity (multiple rows per type).
* **`chana_show`'s hardcoded destroy list (:4589)** is a latent bug the moment a fifth field name
  is introduced. I did not verify it against a live run; it is a source reading.
* **`test_ase_dialogs.tcl`'s grid-row helper** is referenced in `FINDINGS.md` as existing ("a
  helper explicitly for 'the grid row a widget sits in'"); I did not read it directly.
* I did not audit `select_on_design`'s full click pipeline (:2408-2780) beyond its entry points and
  its expression builders — it is large and mostly about outputs, not analyses.
