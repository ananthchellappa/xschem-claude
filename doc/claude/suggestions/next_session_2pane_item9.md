# Next-session prompt — two-pane Signal Browser, ITEM 9 (the paned skeleton)

Paste everything between the markers into a fresh Claude Code session.
Anchors below were re-measured 2026-08-07 **after** items 1-7 landed; the PLAN's own
`src/wave_viewer.tcl` line numbers are ~250 lines stale and must not be trusted.

------ start prompt ------

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`.

Continue the **two-pane Signal Browser batch** at **item 9, the paned skeleton**. All design
rulings are TAKEN — do not re-open them, do not ask me to re-rule them.

## READ FIRST, in this order

1. `doc/claude/specs/waveform_signal_browser_two_pane.md` — the spec. 23 rulings
   (R1-R12 driver, M1-M11 implementer). §1 the shape, §2 the rulings, §4 the tree,
   §5 the sea of names, §9 persistence, §12 what moves in lockstep.
2. `doc/claude/signal_browser_2pane_batch/PLAN.md` — **§2 "Item 9"** is your work order,
   and **§3 "Silent-green traps"** rows 1 and 9 are about this item specifically.
3. `doc/claude/code_analysis/signal_browser_reference.md` — the operational map. ⚠ Its §1,
   §9 and the "~3 in 10" at `:100` are KNOWN-WRONG; corrections in
   `signal_browser_teardown_scoping.md` §7-F.

## WHAT ITEM 9 IS

Move the browser's single tree into a vertical `ttk::panedwindow` with an empty
sea-of-names canvas below it, add both tree scrollbars, switch the tree to single-select,
and add the two class checkbuttons **INERT**. **No behaviour changes.** The tree is still
populated exactly as it is today; items 10-13 add behaviour to a shape that has already
stopped moving.

**This is the batch's only pinned-surface move, and it happens exactly once.** That is why
it is one item and why nothing else may ride along in its commit.

## MEASURED ANCHORS — verified 2026-08-07, post items 1-7

`src/wave_viewer.tcl` (12834+ lines; **the PLAN's numbers are ~250 low, these are current**):

| symbol | line |
|---|---|
| `browser_build` | **6788** |
| `ttk::treeview $f.tvf.tv` create | **6839** |
| `column #0 … -stretch 1` (M4 changes this) | **6841** |
| `scrollbar $f.tvf.sb` | **6842** |
| the four `bind $f.tvf.tv` | **6865, 6867, 6875, 6883** |
| `browser_refresh` | **6985** |
| `browser_populate` | **7053** |
| `browser_reveal` | **7896** |
| `browser_width` (⚠ **M5: DO NOT TOUCH**) | **8097** |
| `browser_show` (the pack branch) | **8153** |
| `browser_tree_state` / `browser_tree_apply` | **8352 / 8383** |
| `browser_state` | **8415** |

**17 longhand `tvf.tv` sites in `src/`**, all of which move:
`6839, 6841, 6842, 6844, 6865, 6867, 6875, 6883, 6992, 7038, 7123, 7756, 7900, 7946, 7949,
8355, 8387`.

**33 `.tvf` occurrences in the browser test files**: `test_wave_sigbrowser.tcl` 14,
`test_wave_sigbrowser_i14.tcl` 10, `test_wave_sigbrowser_i1315.tcl` 4,
`test_wave_sigbrowser_i11.tcl` 3, `test_wave_sigbrowser_i12.tcl` 2.

⚠ **`tests/headless/test_copy_form.tcl` also matches `.tvf` and is NOT ours** — it is the
Library Manager's `.libmgr.cp.h.tvf.tv` (`:105-106`). A blind
`sed -i 's/\.tvf/\.pw\.tvf/'` across `tests/headless/` breaks it. Never sweep that file.

⚠ **`wvbs_common.tcl` has ZERO `tvf` occurrences** — there is no `wvbs_tv` accessor to
update, contrary to the PLAN. If you want one, you are creating it.

`doc/waveform_viewer_guide.html`: 6 `data-bseq` rows at `:1127, 1131, 1135, 1139, 1143,
1147`. **The four `tvf.tv` ones (`:1135, 1139, 1143, 1147`) change value to `pw.tvf.tv`;
the COUNT stays 6**, so GH8/GH9 do not move in this item.

## THE CHECKS THIS REDS — current values, measured

| id | file:line | current expectation |
|---|---|---|
| BS22 | `test_wave_sigbrowser.tcl:308-312` | children `{ph wvsearch tb tvf wvfilter loc}` |
| BT21 | `:1086-1088` | the same six via `$BTF` |
| BT21 | `:1089-1091` | `[list Treeview extended 1]` — class, **selectmode, ONE scrollbar** |
| BT21 | `:1109-1111` | `pack slaves` == `{loc wvsearch tb ph wvfilter tvf}` |
| BT21 | `:1112-1121` | 6 sides + `-expand` == `{top top top bottom bottom top 1}` |
| BT22 | `:1123-1124` | `pack propagate $BTF` == 0 — **unchanged, but re-run it** |
| BR20/BR21/BR23 | `_i1315.tcl:513-541` | the local twins of the child set + pack recipe |
| BH40/BH41 | `_i11.tcl:413, 609` | `$BHTV` path |
| — | `_i12.tcl:595`, `sigbrowser:311`, `_i14.tcl` ×10 | paths |

## THE TWO TRAPS THAT MATTER HERE — run both sabotages, do not reason about them

1. **⚠⚠ `browser_width`'s four literals are SOURCE GREPS and stay GREEN while the width
   rule stops applying.** BT08 (`test_wave_sigbrowser.tcl:784-800`) and BP07
   (`_i1315.tcl:730-745`) both read `wvproc_body`, never a live widget. Build `$f.pw` as a
   child of the **toplevel** instead of `$f` and both stay green while the sidebar silently
   stops governing the panes. **Run that sabotage.** It is the proof that those four
   grep-pinned literals do not prove what they look like they prove. The check that catches
   it is a live one: `winfo height $F.pw > 1` **and** the sash fraction strictly in (0,1),
   on a **mapped** pane.
2. **⚠⚠ `-selectmode browse` gates only the CLASS BINDINGS.** Verified at
   `/usr/share/tcltk/tk8.6/ttk/treeview.tcl:263`: `$tv selection set {a b}` is
   **unaffected** and really does select two. So a check that asserts "selecting two leaves
   one" is green on a broken widget unless it is paired with a control that reconfigures
   the SAME widget to `extended` and gets 2. Write the pair or the check means nothing.

Third, cheaper: **leave `column #0 -stretch 1`** and the new h-scrollbar is decorative —
inside `pack propagate 0` a stretching column always fits, so it never has anything to
scroll. M4 requires `-stretch 0` **with an explicit width** *and* `-xscrollcommand`. Assert
those as ONE check; either leg alone goes green on a dead scrollbar.

## HOW TO WORK

**RED-first, one item, then stop and report.** Edit the existing checks to their new values
FIRST and confirm they are red against today's source; then write the new `BW` file; then
implement; then re-run; then run the sabotages; then commit.

⚠ **When a check goes green that you did not expect to, or passes before the code exists,
STOP AND LOOK.** On the first RED run of item 2, four checks passed VACUOUSLY because
`lsearch` on the `ERR:` string a missing proc returns is `-1`, so every absence check went
green on nothing. Make "the thing I am reading is gone" its own assertable value.

**Commit when green. DO NOT PUSH** unless I say so. There are 4 unpushed commits ahead of
you (`422b3f55`, `d30f8f99`, `7fa8c80d`, `48dceb75`).

## HOUSE RULES THAT HAVE BITTEN PREVIOUS SESSIONS

- Headless: `env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script <f>`. With a
  dead `DISPLAY=:0` inherited from the shell, xschem **hangs forever**, even on `--version`.
  Script files must end in `exit 0`.
- **Item 9 is the first item needing the X arm.** Use `tests/headless/run_suites.sh` or
  `gated_xschem.sh` — **never a bare `for` loop**, which enrols in neither and cannot be
  paused. Press **Allow 2h** on the gate panel once rather than Proceed forty times.
- The gate panel is **not currently running** and does not need to be — `gui_gate.sh`
  forks it itself on first use. As of 2026-08-07 08:00 the X server is **alive**
  (`xdpyinfo` rc=0), but four `panel launch abandoned (no usable X server)` entries in
  `~/.claude/gui_test_gate/events.log` from 2026-08-06 are the WSLg Xwayland death. If a
  log says `X connection to :0 broken`, that run is **not a measurement** — the cure is
  `wsl --shutdown` from Windows and you cannot do it from inside.
- **Never `make` while suites are running** — the suite flakes under CPU load.
- Baseline to beat: **1083 `--nogui` checks green across twelve files.** Re-measure it
  before you start; if it is not 1083, something else moved and you need to know that first.
- Measure, don't reason. Every line number in every doc has drifted at least once —
  including the ones above. Re-verify and report cited-vs-actual.

Start by reading the three docs and re-measuring the baseline. Then show me your RED diff
before implementing.

------ end prompt ------
