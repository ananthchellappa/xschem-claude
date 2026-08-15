# Next-session prompt — two-pane Signal Browser, ITEM 10, CONTINUED

Items 2, 4 and 8 are **DONE and committed**. Item 10's source is **written and headless-green
but UNCOMMITTED**, because the X server died before any of its claims could be checked.

Paste everything between the markers into a fresh Claude Code session, **after** running
`wsl --shutdown` from a Windows prompt and reopening.

------ start prompt ------

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`.

Continue the **two-pane Signal Browser batch**, item 10. All design rulings are TAKEN — do
not re-open them.

## WHERE YOU ARE

Three commits landed last session and are **UNPUSHED** (there are now **8** unpushed
commits total):

| commit | item |
|---|---|
| `20ca095b` | 2 — `browser_rows` gains `root` + `anypath` |
| `acf26275` | 4 — `browser_tree_rows`, `browser_root_label`, the two corpus fixtures |
| `aae1dd8f` | 8 — the root-skip, `browser_root_id`, the `d:N\|` decode fix |

Read `doc/claude/signal_browser_2pane_batch/02_04_08_receipt.md` **first** — §4 lists four
things measurement contradicted, including one that makes a PLAN check
(**BW32**) something you must NOT write.

Item 10's source is in the working tree, **uncommitted**:

* `src/wave_viewer.tcl` — `browser_reload` captures the current raw path into a new
  `browserraw($token)`; `browser_refresh` class-filters (hardcoded `0 1`, item 12 wires the
  boxes) and passes a design-root label when All-DBs is OFF; `browser_populate` projects to
  nodes, inserts collapsed except the root, preserves the open set AND the selection;
  `browser_tree_nodes` no longer uses the "has children" predicate; a
  `<<TreeviewSelect>>` bind and a `browser_sea_refresh` **stub**; `browser_show_path`'s
  sim-root branch selects the root and its walks start at `browser_root_id`.
* `tests/headless/test_wave_sigbrowser_panes.tcl` — BW34/BW35 restated, **BW40-BW53 new**
  (X arm, NEVER RUN).
* `tests/headless/wvbs_common.tcl` — `bs_open_set`, `bs_tree_ids`, `bs_type`.
* `tests/headless/test_wave_grid.tcl` — GH8 `6` → `7`. `doc/waveform_viewer_guide.html` —
  the matching `data-bseq` row. Both green.

**Headless is 1586 across thirteen files, zero failures. That proves almost nothing about
item 10** — every claim it makes needs real Tk.

## ⚠⚠ WHY IT IS NOT COMMITTED

`xdpyinfo -display :0` never returns and **untouched** suites (`test_wave_viewer.tcl`)
segfault, so the WSLg Xwayland death took the display, not the change. **Re-verify the X
server is alive before you do anything else** — `timeout 15 xdpyinfo -display :0` must
return 0.

## THE WORK THAT REMAINS

### 1. Restate the 84 confirmed X-arm checks

`doc/claude/signal_browser_2pane_batch/item10_blast_radius.md` is the full list, produced by
an 8-agent audit plus an adversarial verify pass (110 candidates, 84 confirmed, 26 refuted,
with the refutations kept). **`PLAN.md` item 10's own red list names ~12 of these — it is
short by a factor of seven.**

⚠ **`VACUOUS` is most of the miss, and it reads GREEN.** The whole `BM` band (~45 checks,
the right-click menu) clicks LEAF ids in the tree. When the row disappears those checks do
not fail — they print `SKIPPED` and assert nothing.

**THE DRIVER HAS RULED on that band: option (a).** The fixture inserts the leaf rows into
its own throwaway tree by hand, so the menu gestures keep their present targets and all ~45
keep asserting exactly what they assert today. `browser_menu_post` / `browser_menu_ids`
take a clicked row id and are untouched by item 10 — only the widget hosting the row moves.
Leave a comment at the fixture saying it no longer mirrors production and that **item 11
re-points these at the sea of names**. Do NOT delete them, and do NOT re-aim them at group
rows (that would be a new claim, not preserved coverage).

The `FAIL` hits (BT24-BT33, BT40-BT44, BM40, BX30/BX32/BX45/BX46/BX50, BP43/BP45/BP52-BP55,
BD50b) need real restated values. **Measure them, do not predict them** — every expected
value in the audit's `new_expected` column is a subagent's guess and several say "unknown".

### 2. Run the X arm and believe only what it prints

`tests/headless/run_suites.sh` under one **`Allow 2h`** press, never a bare `for` loop.
`SUITE_TIMEOUT=400` for `test_wave_modes`. The item-9 X baseline to beat: panes 34,
sigbrowser 319, i11 74, i12 92, i1315 166, i14 83, 2pane 59, sigsearch 226, grid 341,
modes 485.

### 3. Sabotage it before you commit

At minimum: put `browser_tree_rows`' output into `browserrows` as well (BW44 is the only
thing that sees it); insert every node `-open 1` (BW41); call `$tv see` from
`browser_populate` (BW46/BW47); drop the open-set preservation (BW46); restore
`browser_tree_nodes`' "has children" predicate (BW52). **Run them.** And when a sabotage
gives FEWER reds than the file has checks, look at the check COUNT — an aborted file
reports a plausible number.

## THREE DEFECTS ITEM 10 FOUND, ALREADY FIXED IN THE WORKING TREE

Keep them; each is load-bearing and none is in the PLAN.

1. **`browser_tree_nodes`' "rows with children" predicate silently breaks.** It meant
   "groups" only while leaves were in the tree. Afterwards a node whose children were all
   signals has **no** children, so it would drop out of `browser_tree_state` and
   `browser_tree_apply` — the collapse state of exactly the leaf-most nodes would stop
   persisting. Every item in the tree is a node now; the predicate is gone. BW52.
2. **R5 needed the open set carried across a repopulate.** `browser_populate` deletes every
   row, and `browser_refresh` runs on every keystroke in either bar. While rows were
   re-inserted `-open 1` that was invisible; inserting them `-open 0` turns it into "typing
   in the Search bar collapses everything you expanded". R5's letter is "the tree never
   auto-OPENS on a search"; auto-closing is the same defect with the other sign. BW46.
3. **`browser_populate` must narrow the restored selection to ONE id itself.**
   `-selectmode browse` gates only ttk's class bindings, so `selection set` with two ids
   really selects two (item 9's measured fact, BW26b).

## FOUR THINGS THE PLAN SAYS THAT ARE WRONG — DO NOT REINSTATE THEM

1. **Do not write BW32** ("browser_refresh computes anypath BEFORE the class filter"). The
   gate cannot change anything (receipt §4.1), and passing it would flatten a hierarchical
   FOREIGN inventory whenever the current raw is flat. It is per-inventory and
   `browser_rows` already computes it per inventory.
2. **Do not renumber into BW20-BW35** — item 9 shipped those. Item 10 is **BW40-BW53**.
3. **BW24's `406` needs the corpus**, which is now committed as
   `tests/headless/fixtures/tb_bandgap_vars.txt`. The panes fixture is a 3-signal one, so
   its R6 control is `{3 2 1}`, not 406; the 406 is pinned purely in `test_wave_sigbrowser_2pane.tcl`.
4. **`begin {…}` is not a proc.** Named helpers, and they must RESTORE what they changed —
   `bw_sel_after_clear_and_refresh` and friends are the precedent.

## HOUSE RULES THAT HAVE BITTEN PREVIOUS SESSIONS

- Headless: `env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script <f>` from the
  repo ROOT; scripts end in `exit 0`.
- **`pcall` returns the STRING `ERR:<msg>`.** `expr` on it THROWS, past the check, into the
  file's outer catch, deleting every remaining check. Use `bs_num` / `bs_set`, and give
  every helper three shapes: "never built" / "built and empty" / "correctly filtered to
  zero".
- **A check that compares an error string with itself is GREEN before the code exists.**
  That happened again this session (TP33's uniqueness leg). When a check passes before you
  wrote the code, **stop and look**.
- Never `make` while suites run. `MG13` and `test_ase_plot` P4/P6/P8 are known WSLg flakes.
- **Commit when green. DO NOT PUSH** unless told.
- Measure, don't reason. Every line number in every doc has drifted at least once.

Start by confirming the X server is alive, re-measuring the headless baseline (**1586**),
then running the X arm on the UNCHANGED working tree to see the real red list — and compare
it against `item10_blast_radius.md` before you edit a single expected value.

------ end prompt ------
