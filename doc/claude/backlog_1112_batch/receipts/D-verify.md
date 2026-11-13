# Stage D verifier receipt

Verifier crew, 2026-11-12. Tree: HEAD `514868462` plus stage D's uncommitted work plus mine.
Nothing is committed.

- Every xschem run had `unset DISPLAY`.
- The only display I used was my own Xvfb `:283` plus openbox, both killed by pid at the end.
  I never used `:99` and ran no T1.
- Every probe script lives in the session scratchpad
  (`/tmp/claude-1000/-home-analog-dev-xschem-claude/77b869a3-9e5c-4256-9142-c01d3eba1aef/scratchpad/dv/`).

**Verdict.** I could not refute "no second dead gate": every candidate I measured is live or is
a false positive. The two upstream leftovers are dead and each has a live sibling. The A22
blanker is correct on all 40 C files in `src/`. Issue 1712's number is free and its stamp is
valid. **I registered the suite** in `dcases` only, after first adding the `OVERALL:` sentinel.
Without the sentinel, registering it would have produced a counted failure.

## My changes

| file | what |
|---|---|
| `tests/headless/test_annot_declutter_1244.tcl` | Epilogue: prints `OVERALL: ok (<n> checks)` after `RESULT:` on a pass, `OVERALL: notok` on a failure. This is `test_annot_blank_cause_0909`'s shape. The check count is unchanged (134). |
| `tests/run_regression.tcl` | `"headless/test_annot_declutter_1244"` added to `dcases` only, after `test_annot_blank_cause_0909`. My sed first matched the `hcases` line too, and I removed that hit. `git diff` shows exactly one `+` line, inside `dcases`. |
| `doc/claude/issues/1712-…md` | Stamp changed from `open=1` to `open=0`. "Still open (1)" is replaced by a "Registration (taken)" section. `issue_stamp.tcl` gives `ok (0 problems)`. |

## 1. Attacks on "no second dead gate"

All of these are runtime measurements in a live xschem on `:283`. Where noted, they were taken
in four configurations: base, sky130A, ihp-sg13g2 and gf180mcuD, each with the workarea's
`cadence_style_rc` sourced.

| attack | method | result |
|---|---|---|
| Menu `-command`s, widget `-command`/scroll/validate commands, every `bind` on every widget and on the classes `Text Entry Canvas Menu Button Listbox Toplevel all`, pending `after` scripts | Walked the widget tree. Split each script into complete commands with `info complete`. Checked each command's first word with `info commands` and `auto_load`. All four configurations. | **0 real.** The only reports were false positives: `a`, `and` and `doesn't` are words from a comment that contains `;`. `get_sel_inst_name` (the sky130 menu) is a `proc` defined inside that same `-command` before it is called. |
| The same walk with lazy windows open | sky130A with `tb_bandgap` loaded, then `calc::open`, `ase::launch_for_current` (`.ase4`) and `simconf` (`.sim`) | **0 real.** Same false positives only. |
| `tcleval`/`tclvareval`/`Tcl_Eval` literals in C: first word is a command | 116 distinct first words, all four configurations | **0.** The one miss, `someproc`, is in a comment in `util.c`. |
| `my_snprintf` format strings whose first word looks like a command | 28 words not in the set above | **0.** All are format text (`snap`, `nosel`, `ylab_visible`, and so on). |
| `info procs/commands <literal>` | 63 literal names, all four configurations | **0.** The 3 misses are comment fragments. |
| `info exists ::X` (qualified, code lines only) | 95 names; 33 absent at startup in every configuration. For each absent leaf I counted the setters (`set`, `variable`, `-variable`, `tclsetvar`, …) | The names with 0 setters are exactly the receipt's tunables (`PDK_LAUNCHER_NO_UI`, `new_window_size_frac`, `palette_emphasis_color`, `slickprop_accent`/`_warn`, `wviewer_reuse_max_distance`). I read the 1-setter ones (`tctx::edit_inst_id`/`_sel_ids` come from `editprop.c`'s `tclsetvar`; `gfxform_geom`, `nhse_snapshot` and so on) and found no misspelled or wrong-namespace setter. |
| `tclget*var("X")` in C | 161 names, GUI and `--nogui` | 19 or 20 absent at startup. Each has a setter under the exact name except the two `slickprop_highlight_*` tunables. `tctx::*` is set by C. `sim(spicewave,default)`: see below. |
| `xschem get <literal>` | Diffed against the names `scheduler.c`'s `get` branch compares | The 3 left over are `cursor` (the `cursor${which}_x` spelling; `cursor1_x`/`cursor2_x` are both handled) and two comment mentions. **0 real.** |
| Multi-line gate spellings (`info … \` continuations, a name on the next line) | Regex over the Tcl and C sources | 3 hits, all inside comments. |
| `drc=` in symbols | Every `drc=` across sky130A, ihp-sg13g2, gf180mcuD and xschem_library `.sym` files: 7 proc names. Checked at runtime per workarea. | Each is defined in its own workarea: `sky130_fet_drc` in sky130A, and the six `sg13g2_*_drc` in ihp-sg13g2. gf180 and xschem_library carry none. |
| `edit_form=` | The 4 symbols in `xschem_libs_newsym/devices/{ipulse,ipwl,vpulse,vpwl}`. Sourced each companion `.tcl`. | Each gives `namespace exists ::<n>` = 1, with 1 or 11 procs. |

**One observation that is not a dead gate.** `act_highlight_send_waveform` (Alt-G,
`hilight.send_to_waveform`) checks `info exists sim`. At startup that measured **0**: the
`sim()` array is built lazily by `set_sim_defaults`, which only the simulation, netlist and
config paths call. So before any of those paths has run, Alt-G sends nothing to Gaw or Bespice;
the graph path works regardless. The setter exists and is live, and `main` (upstream) has the
same lazy shape. Alt-G is also a native-xschem surface, not on the user's ASE-L path. I did not
change it and I am not raising it as a ruling.

## 2. The two upstream leftovers

- **`.dialog.txt`** (`handle_button_press`, `callback.c`). I searched every tracked
  `.tcl`/`.c`/`.h`/rc file outside `doc/` and `tests/`. `.dialog.txt` occurs only in that
  `callback.c` test; nothing creates it. Its sibling `.dialog.f2.txt` is created by
  `enter_text` (`text .dialog.f2.txt`), and the sibling branch invokes the same
  `.dialog.buttons.ok`. I also checked the third sibling, `.dialog.textinput`: it is created by
  `text_line_legacy`, which also creates the `.dialog.f1.b1` that branch invokes. The
  implementer's runtime measurement stands (`.dialog.txt=0`, `.dialog.f2.txt=1`).
- **`.searchall`** (the `file_chooser` Dismiss button). `searchall` outside comments and tests
  occurs only as `file_chooser(searchall)` (the checkbutton and its readers) plus this one
  `winfo exists .searchall`. No `toplevel .searchall` exists anywhere. The live replacement is
  the `.ins.top4.search_all` checkbutton, which drives the same listbox.

I agree with leaving both in place.

## 3. The A22 fix

- **Correct against a real C tokenizer.** I wrote a reference blanker in Python that knows
  string and char literals (so `"/*"` inside a string is not a comment). On all 40 `src/*.c`
  files its output is byte-identical to `dc_c_blank`'s. The one apparent difference,
  `cairo_jpg.c`, is a CRLF artefact of my harness: Tcl's `read` translates `\r\n`; with
  `\r` stripped the two outputs are identical.
- No string literal in the four census files contains `/*` or `*/`. svgdraw.c has two `//`
  URLs inside strings, which are harmless because the blanker ignores `//`.
- The census counts match the reference with `//` comments also stripped: `{4 2 2 1 0}`.
- **Blind spot, declared not fixed:** `dc_c_blank` does not blank `//` comments. The four
  files contain none, since they are C89. A future `// text_hidden_inst(` comment would be
  counted. That reddens the row; it cannot make it falsely green.
- **The golden is right.** `text_hidden_inst(` appears on 5 lines of draw.c. Line 709 is the
  comment above `sym_text_vstack()`. The other four are calls: 983 and 1093 in `draw_symbol`,
  1289 in `draw_temp_symbol`, and 11600 in `inst_text_bbox`.
- **The self-test leg has bite.**
  - `{1 4}` is the right answer for its sample.
  - A no-op blanker gives `{3 4}`: the implementer's SA3.
  - A blanker that eats newlines would give a different line count.
  - A greedy `.*` blanker passes the sample but blanks most of draw.c, so the main legs
    redden.
- **Sibling rows in the same suite.** The `"@symname"` and `annot_name_token(` censuses
  (A21 and its neighbours) still use the prose-blind `opa_n_grep`. I measured raw count against
  code-only count for all four files: they are equal today. So none of them is green only
  because its golden counts a comment. A future comment would redden them; it could not hide
  anything.

## 4. Issue 1712

- The candidate is not in any reserved band.
- I globbed `NUMBERING.md` in `~/dev/*` and `~/private/*`: three files, all of which exist.
- No file `1712-*` exists in any clone except this one.
- `grep -lw 1712` matches only this clone's `NUMBERING.md`.
- I listed `doc/claude/issues/` on every branch of `~/private/xschem-private` and on every
  local branch of `~/dev/xschem-op-wcard`: there is no `171[0-9]-` file apart from private's
  1707–1710, which `NUMBERING.md` already skips.
- `tclsh tests/headless/issue_stamp.tcl` gives `ISSUE-STAMP: ok (0 problems)`, both before
  and after my stamp edit.

## 5. Registration

**Red first.** I captured the suite exactly as T1's `dcases` arm runs it: from `tests/`, with
throwaway HOME, `DISPLAY=:283 GUI_GATE=0`, then
`timeout --kill-after=20 900 ../src/xschem --pipe -q --logdir <dir> --script headless/test_annot_declutter_1244.tcl`.
I scored the output with `banner_rule.tcl`, sourced:

| epilogue | rc | output | banner_complete | regression_case_failed |
|---|---|---|---|---|
| implementer's (no `OVERALL:`) | 0 | `RESULT: ALL PASS (134 checks)` | **0** | **1**, so registering would have been a counted HARNESS FAIL |
| mine, green | 0 | `ALL PASS (134 checks)` + `OVERALL: ok (134 checks)` | 1 | 0 |
| mine, A22 golden sabotaged | 1 | `OVERALL: notok` | 0 | 1 |

The sabotage was restored with `cp` and checked with `cmp`.

The green run printed 0 `^skip:` lines and 1 `^RESULT:` line. So the expected T1 delta is:
`cases` +1, `blocks` +1, `counted_failures` +0, `skips` +0, `wc -l` +3. That is derived from the
predicate, not from a gate run.

**Headless arm.** Under `--nogui` the suite dies early with `Line No: 176` and rc 0. That is why
the entry is `dcases` only and never `hcases`.

**Suites that census the registration lists**, counted arm
(`AUDIT_DISPLAY=:283 run_suites.sh --nogui`):

| suite | result |
|---|---|
| `test_registered_banner_1626` | ALL PASS (10 checks) |
| `test_suite_watchdog_1403` (W20h) | ALL PASS (40 checks) |
| `test_regression_concurrency_1476` | ALL PASS (46 checks) |
| `test_t1_display_arm` | ALL PASS (14 checks) |
| `test_issue_stamp` | ALL PASS (102 checks) |
| `test_home_isolation` | **1 FAILED (119 passed)** |

The `test_home_isolation` failure is row **G2**. Every UNARMED path it names is under the
**untracked** `doc/claude/rl_telescopic_amp/` (`run_measures.py`, `dump.sh`, `run.sh`). That is
not this stage's work, and a gate clone will not contain it. **Driver: do not `git add` that
directory with stage D**, or the gate will be red on G2.

Display arm of the suite itself: `AUDIT_DISPLAY=:283 run_suites.sh test_annot_declutter_1244`
gives `PASS … ALL PASS (134 checks)`. The T1-shaped `--logdir` run above passed too.

**Not checked:** the short-path gate-clone concern the implementer raised. The suite printed no
status-bar path elision on my 51-character repo path. The driver's gate clone at a short path
covers it.

## Blind spots of my attacks

- The widget walk covers startup windows plus the Calculator, the ASE window and simconf.
  Other lazily built dialogs (the property form, the wave viewer, the RDW, the library dialogs)
  were not opened.
- The script splitter splits at `;` inside comments, which produced the false positives. It
  does not recurse into `if`/`foreach` bodies, so a missing proc called only inside a branch
  body of a menu command is checked only by the implementer's text scans.
- Unqualified `info exists X` (global or local) was not re-derived. I relied on the receipt for
  it.

## User rulings

None. The Alt-G lazy-`sim` observation is a native-xschem surface that behaves as upstream does,
so it is recorded, not raised.
