# Next-session prompt — two-pane Signal Browser, ITEM 10 (the upper pane goes live)

Paste everything between the markers into a fresh Claude Code session.
Anchors below were re-measured 2026-08-07 **after item 9 landed** (`e813b654`). Every
line number in `PLAN.md`'s own item-10 text is now ~400 lines stale and must not be
trusted.

------ start prompt ------

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`.

Continue the **two-pane Signal Browser batch**. All design rulings are TAKEN — do not
re-open them, do not ask me to re-rule them.

## ⚠⚠ READ THIS FIRST: ITEM 10 IS BLOCKED, AND THE PLAN DOES NOT SAY SO LOUDLY ENOUGH

The PLAN's dependency column says item 10 needs **4, 8, 9**. Item 9 landed. **Items 2, 4
and 8 have NOT** — I verified by grepping for the procs, not by trusting the ledger:

| item | what it owes | present in `src/wave_viewer.tcl`? |
|---|---|---|
| 2 | `browser_rows {entries {root {}} {anypath {}}}` | **NO** — it is still `{entries}` at `:6354` |
| 4 | `browser_tree_rows`, `browser_root_label` | **NO** |
| 8 | `browser_node_for {rows segs {start {}}}`, `browser_root_id`, the `d:N\|` decode fix | **NO** — `browser_node_for` is `{rows segs}` at `:7991`; both `string range $id 2 end` sites are still there (`:7808` in `browser_target_path`, `:8176` in `browser_show_path`) |

So the work order is **2 → 4 → 8 → 10**, in that order, and the first three are **pure**
(no X server, no GUI gate). Do them as their own commits, exactly as items 3/5/6/7 were
done. Only item 10 needs the X arm.

Do not start item 10 by writing item-10 checks. Start at item 2.

## READ, in this order

1. `doc/claude/specs/waveform_signal_browser_two_pane.md` — the spec. §2 the 23 rulings,
   §3 the data model, §4 the tree, §6 the filters, §7.1-7.2, §9 persistence.
2. `doc/claude/signal_browser_2pane_batch/PLAN.md` — **§2 items 2, 4, 8 and 10** are your
   work orders. §3 traps **5, 6 and 10** are about these items specifically.
3. `doc/claude/signal_browser_2pane_batch/09_receipt.md` — **short, and it will save you a
   day.** §4 lists three things the docs asserted that measurement contradicted, §5 two
   defects in the test harness itself, §6 the measured pane geometry.

## MEASURED ANCHORS — verified 2026-08-07, post item 9

`src/wave_viewer.tcl` is **13333** lines.

| symbol | line |
|---|---|
| `browser_class_filter` (item 3, landed) | 6122 |
| `browser_device_paths` | 6158 |
| `browser_level_names` (item 5, landed) | 6196 |
| `browser_rows` (**item 2 edits this**) | 6354 |
| `browser_rows_multi` | 6431 |
| `browser_kind` / `browser_leaf_names` | 6450 / 6471 |
| `browser_build` | 6812 |
| `browser_sea_build` / `browser_sash` (item 9, new) | 7005 / 7037 |
| `browser_refresh` (**item 10 edits this**) | 7150 |
| `browser_populate` (**item 10 edits this**) | 7218 |
| `browser_target_path` — the `d:N\|` bug at `:7808` | 7790 |
| `browser_node_for` (**item 8 edits this**) | 7991 |
| `browser_reveal` | 8061 |
| `browser_show_path` — the twin bug at `:8176` | 8099 |
| `browser_tree_state` / `browser_tree_apply` | 8529 / 8560 |
| `browser_state` | 8592 |

Existing checks item 10 reds, **current** line numbers:

| id | file:line |
|---|---|
| GH8 / GH9 (`6` → **7**) | `test_wave_grid.tcl:473` / `:485` |
| BT24 | `test_wave_sigbrowser.tcl:1168, 1176, 1183, 1187` |
| BT25 / BT26 / BT27 | `:1194-1244` |
| BT29 | `:1267, 1278, 1291` |
| BT30 | `:1300` |
| BT32 | `:1342, 1349, 1353` |
| BT33 | `:1364` |
| BT42 | `:1443` |
| BM11 (the surviving dedup oracle — must STAY green) | `:1747-1757` |
| BM40 | `:2252, 2293, 2297` |
| BX30 | `test_wave_sigbrowser_i12.tcl:396, 401` |
| BP53 / BP54 | `test_wave_sigbrowser_i1315.tcl:1294 / 1302` |

## ⚠ FOUR THINGS IN THE PLAN'S ITEM-10 TEXT THAT ARE WRONG OR OWED

Fix these before you write a line of it.

1. **⚠⚠ THE `BW` NUMBERS COLLIDE.** The PLAN gives item 10 `BW20-BW34`. Item 9 already
   shipped `BW01-BW14` and `BW20-BW35` in `tests/headless/test_wave_sigbrowser_panes.tcl`.
   **Start item 10 at `BW40`.** Reusing 20-35 would silently overwrite item 9's coverage —
   the file has no duplicate-id guard.
2. **⚠⚠ BT29 AND BT30 CANNOT BE "RETARGETED TO THE SEA" IN ITEM 10.** The PLAN says to
   point them at sea cells, but `browser_sea_refresh` is a **no-op stub** until item 11 —
   there are no cells to click. This is a real ordering hole and it is yours to close.
   My recommendation, take it as an M-ruling and write it down: in item 10 **assert the
   absence** (the leaf ids are gone from the tree, `$tv exists {s:…}` is 0, and the
   gesture records nothing), and move the positive plot coverage to item 11 where the sea
   exists. Do NOT delete BT29/BT30 outright — a deleted check is coverage nobody notices
   is missing.
3. **BW24's `406` needs a fixture that does not exist.** `PLAN.md` §4 says the corpus
   name-lists (`tb_bandgap_vars.txt`, `tb_charge_pump_vars.txt`) get committed under
   `tests/headless/fixtures/`. **They were never extracted** — the 22-raw corpus lives
   under `tests/headless/.scratch/0211/…`, which `test_scratch_drop` deletes and no clean
   checkout has. Either extract them (name-only, once — `tb_charge_pump_ase.raw` is
   **621 MB**, `head -c 4000000` only, never `cat`) or re-derive R6's control number from
   the shipped 8-signal fixture and say so.
4. **The PLAN's `begin {…}` idiom is not a real proc.** Item 9 hit this too: write named
   helper procs instead (`bw_click2`, `bw_sel2_as_extended` are the precedent in
   `test_wave_sigbrowser_panes.tcl`), and make them RESTORE whatever they changed.

## ⚠⚠ THE HARNESS RULE ITEM 9 PAID FOR — IT BINDS YOU

**`pcall` returns the STRING `ERR:<msg>`.** So `expr {[pcall winfo width $w] > 1}` THROWS
on it, straight past the check into the file's outer catch, which deletes every remaining
check. That is not hypothetical: under item 9's trap-1 sabotage the panes file stopped at
check 17 of 34, the two checks written to CATCH that sabotage never ran, and the file
reported a plausible-looking `3 FAILED`. It took three sabotage runs to see it.

Use **`bs_num`** (a `pcall` result reduced to a number, or `-1`) and **`bs_set`** (1 when
the result is real and non-empty) — both new in `tests/headless/wvbs_common.tcl` — in
**every** X-arm check. `bs_wait_mapped` is now non-throwing for the same reason.

Also already in `wvbs_common.tcl` and worth reusing: `bs_sash_frac` / `bs_wait_sash`
(`-1` no panedwindow, `-2` not mapped yet), `bs_blank_y` / `bs_blank_undo` (a provably
blank y in a tree, negative code when there is none).

**Helpers the PLAN names that DO NOT exist** — you are creating them: `bs_open_set`,
`bs_sea_labels`, `bs_type`, `bw_kinds_in_tree`, `bw_depth`, `bw_index_order`. Each one
must have three distinct shapes for "never built" / "built and empty" / "correctly
filtered to zero", never a count, never a bare boolean, never a throw.

## THREE MEASURED FACTS FROM ITEM 9 YOU WILL OTHERWISE RE-DERIVE

1. **`-selectmode browse` gates ONLY the class bindings** (`/usr/share/tcltk/tk8.6/ttk/
   treeview.tcl:262-275`). `$tv selection set {a b}` really does select **two**. Any R4
   claim must be made with a real gesture (`<Button-1>` then `<Shift-Button-1>`), not
   with `selection set`. **This is live for item 10**: `browser_populate`'s re-select must
   narrow to ONE id itself — the widget will not do it for you.
2. **`ttk::treeview` does NOT auto-grow column `#0`** for deep or long items. Depth never
   changes `xview`. Item 9 kept `#0` at 200 px, so at the ~583 px sidebar the h-scrollbar
   is wired but idle. **Item 10 owns the decision** of what width makes it useful, now
   that the tree holds instance names instead of full raw names (item 9 receipt, declared
   limit 1).
3. **Measured pane geometry** (fixture 1400x500): sidebar 500 → panedwindow 286 → tree
   pane 157 (widget **144**) → sea 124, sash fraction 0.549. The tree is now SHORTER than
   its content, which is what broke BT31/BM21's blank-space coordinate. Assume nothing
   about a tree being taller than its rows.

## HOW TO WORK

**RED-first, one item, then stop and report.** Edit the existing checks to their new
values FIRST and confirm they are red against today's source; then write the new checks;
then implement; then re-run; then run the sabotages; then commit.

⚠ **When a check goes green that you did not expect to, or passes before the code exists,
STOP AND LOOK.** And when a sabotage produces FEWER reds than the file has checks, look at
the check COUNT, not just the fail count — a file that aborted early reports a plausible
number.

**Baseline to beat — re-measure it before you start.** `--nogui`, thirteen files,
**1531** checks, zero failures:

| file | checks | | file | checks |
|---|---|---|---|---|
| `test_wave_sigsearch` | 139 | | `test_wave_sigbrowser_i14` | 47 |
| `test_wave_sigbrowser` | 135 | | `test_wave_grid` | 216 |
| `test_wave_sigbrowser_2pane` | 59 | | `test_wave_modes` | 212 |
| `test_wave_sigbrowser_panes` | 14 | | `test_wave_viewer` | 57 |
| `test_wave_sigbrowser_i11` | 50 | | `test_wave_markers` | 437 |
| `test_wave_sigbrowser_i12` | 29 | | `test_wave_tabs` | 56 |
| `test_wave_sigbrowser_i1315` | 80 | | | |

If it is not 1531, something else moved and you need to know that first. (The figure
quoted in older docs, 1083, does **not** reproduce and names a set nobody wrote down.)

X arm, 10/10 green at item 9: panes 34, sigbrowser 319, i11 74, i12 92, i1315 166, i14 83,
2pane 59, sigsearch 226, grid 341, modes 485.

**Commit when green. DO NOT PUSH** unless I say so. There are **5** unpushed commits ahead
of you (`422b3f55`, `d30f8f99`, `7fa8c80d`, `48dceb75`, `e813b654`).

## HOUSE RULES THAT HAVE BITTEN PREVIOUS SESSIONS

- Headless: `env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script <f>`, **from
  the repo root**. With a dead `DISPLAY=:0` inherited from the shell, xschem **hangs
  forever**, even on `--version`. Script files must end in `exit 0`.
- Items 2, 4 and 8 need **no X at all**. Only item 10 does. Batch the X runs: use
  `tests/headless/run_suites.sh` (or `gated_xschem.sh` for a one-off), **never a bare
  `for` loop** — it enrols in neither and cannot be paused. Press **`Allow 2h`** on the
  gate panel once rather than Proceed a dozen times; item 9 needed **five** separate
  gated batches and most of them were one press each.
- `SUITE_TIMEOUT=400` for `test_wave_modes` — at the default 200 s it reported
  `NORESULT (exit 1 — binary never reported)` once, which is a timeout, not a failure.
- **`MG13` in `test_wave_modes` and the `test_ase_plot` P4/P6/P8 legs are known WSLg
  flakes**, not regressions. MG13 uses a bare `event generate -when now` with no
  `send_key` retry. Re-run before believing one.
- `tests/headless/test_copy_form.tcl` also matches `.tvf` and is **NOT ours** — it is the
  Library Manager's `.libmgr.cp.h.tvf.tv`. Never sweep it.
- **Never `make` while suites are running** — the suite flakes under CPU load.
- Measure, don't reason. Every line number in every doc has drifted at least once,
  including the ones above. Re-verify and report cited-vs-actual.

Start by reading the three docs, confirming items 2/4/8 really are absent, and re-measuring
the baseline. Then show me your RED diff for **item 2** before implementing.

------ end prompt ------
