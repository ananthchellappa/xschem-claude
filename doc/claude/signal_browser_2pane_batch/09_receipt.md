# Item 9 receipt — the paned skeleton

**Status: DONE.** `src/wave_viewer.tcl` `browser_build` now hosts a vertical
`ttk::panedwindow` with the instance tree above an empty sea-of-names canvas, the tree
has both scrollbars and `-selectmode browse`, and R11's two checkbuttons exist **inert**.
No behaviour changed: the tree is still populated by exactly the code that populated it
before. Items 10-13 add behaviour to a shape that has now stopped moving.

Spec: `doc/claude/specs/waveform_signal_browser_two_pane.md` (R3, R4, R11, M3, M4, M5).
Plan: `doc/claude/signal_browser_2pane_batch/PLAN.md` item 9 + §3 traps 1 and 9.

---

## 1. What landed

| file | change |
|---|---|
| `src/wave_viewer.tcl` | `browser_build`: `$f.opt` (two `ttk::checkbutton`s, **no `-command`**), `$f.pw` (`ttk::panedwindow -orient vertical`), the tree frame re-parented to `$f.pw.tvf`, `-selectmode browse`, column `#0` `-stretch 0`, a horizontal scrollbar + `-xscrollcommand`; new `browser_sea_build` and `browser_sash`; `browser_show` applies the sash from the **pack** branch; three new per-token arrays declared, seeded and unset on teardown; **all 17** longhand `tvf.tv` sites re-pointed to `pw.tvf.tv` |
| `tests/headless/test_wave_sigbrowser_panes.tcl` | **NEW**, band `BW`, 14 `--nogui` + 34 X |
| `tests/headless/wvbs_common.tcl` | `bs_sash_frac`, `bs_wait_sash`, `bs_scan_blank`, `bs_blank_y`, `bs_blank_undo`, `bs_num`, `bs_set`; `bs_wait_mapped` made non-throwing |
| `test_wave_sigbrowser.tcl` | BS22/BT21 child sets and the pack recipe (6→7 slaves), BT21's tree tuple (`extended 1` → `browse 1 1`), 3 `bind $f.` source greps, 4 path literals, BT31/BM21's blank-space coordinate |
| `_i11 / _i12 / _i1315 / _i14` | 19 path literals + BR20/BR21's local twins |
| `doc/waveform_viewer_guide.html` | 4 `data-bseq` values `tvf.tv …` → `pw.tvf.tv …`; **the count stays 6**, so GH8/GH9 do not move |
| `doc/claude/specs/waveform_signal_browser.md` | contract lines for `browser_sea_build` and `browser_sash` (GS1 requires them in the same commit as the procs) |

`browser_width` is **untouched** (M5). No accessor was introduced — `browser_tree` /
`browser_sea` are item 1's, which has not landed; item 9 re-points the literals and
nothing else rides along.

## 2. Verification

**`--nogui`**, re-measured before and after on the same twelve files:

| | before (12 files) | after (13 — the BW file is new) |
|---|---|---|
| the browser-family set | **1515** | **1531** |
| all `test_wave_*` suites | 2209 | 2225 |

Per file after: sigsearch 139, sigbrowser 135, 2pane 59, **panes 14 (new)**, i11 50,
i12 29, i1315 80, i14 47, grid **216** (+2, GS1's two new contract lines), modes 212,
viewer 57, markers 437, tabs 56.

⚠ **The prompt's "1083 across twelve files" did not reproduce and names a set nobody
wrote down.** Measured on this tree at item 9's start, `--nogui`: sigsearch 139,
sigbrowser 135, 2pane 59, i11 50, i12 29, i1315 80, i14 47, grid 214, modes 212,
viewer 57, markers 437, tabs 56 = **1515**, zero failures. Nothing had moved; the figure
was stale. The set above is now written down so the next item can compare like with like.

**X arm** (`run_suites.sh`, under the gate), **10/10 runs passed**: panes 34,
sigbrowser 319, i11 74, i12 92, i1315 166, i14 83, 2pane 59, sigsearch 226, grid 341,
modes 485.

## 3. The four sabotages — RUN, not reasoned about

| sabotage | measured reds | verdict |
|---|---|---|
| leave `column #0 -stretch 1` | BW02, BW03 (greps) **+ BW22, BW28, BW29** (live) | M4 is pinned behaviourally, not only by grep |
| build `$f.pw` as a child of the **toplevel** | BW04, BW20-23, BW26/26b/27, BW28/29, **BW31, BW32**, BW33-35; BS22, BT04, BT20, BT21 — **while BW08, BW09 and BT08 stayed GREEN** | ⚠ trap 1 confirmed **exactly**: the four `browser_width` literals are source greps and prove nothing about whether the width rule still applies |
| give the sea a vertical scrollbar | BW11, BW23 | R3 pinned in source and on the widget |
| wire the checkbuttons now | BW25 | item 12 keeps its own attribution |

Source restored byte-identical after every one (`diff -q`).

## 4. Four things the docs said that measurement contradicted

1. **⚠ The PLAN's BW10/BW11 pair is self-contradictory and BW10 is red on a CORRECT
   widget.** BW10 asserts "`selection set {a b}` under `browse` leaves ONE", while the
   PLAN's own trap row 9 says `selection set` is *unaffected* by `-selectmode`. Both
   cannot hold. Run: it really does select **two**. Confirmed in the source —
   `/usr/share/tcltk/tk8.6/ttk/treeview.tcl:262-275`, `-selectmode` is read in exactly
   one place, `ttk::treeview::SelectOp`, which only the **class bindings** call.
   The discriminating pair therefore has to be a **real gesture**: `<Button-1>` then
   `<Shift-Button-1>` dispatches `select.extend.<mode>` — `BrowseTo` (1) under `browse`,
   `selection set [between …]` (2) under `extended`. That is BW26 + BW27, on the same
   widget, same rows, same events. **BW26b keeps the measured fact assertable**, because
   it is the live hazard: a state file written by the shipped `extended` version restores
   a two-id `sel` straight through `selection set`, so R4 is false from the first restore
   unless item 13/14 narrows it.
2. **⚠ The PLAN's BW12/BW13 ("a DEEP tree really has something to h-scroll") is wrong.**
   Measured on Tk 8.6.14: `ttk::treeview` does **not** auto-grow column `#0` for deep or
   long items. A six-level tree of 32-character names in a 570 px pane reports
   `xview {0.0 1.0}` under **both** stretch settings. Depth is not the discriminator.
   What is, measured on the same run:

   | setting | column #0 in a 570 px tree | `xview` |
   |---|---|---|
   | `-stretch 0`, width 200 | stays **200** | `{0.0 1.0}` |
   | `-stretch 1`, width 200 | becomes **568** | `{0.0 1.0}` |
   | `-stretch 0`, width > pane | — | `{0.0 0.79}` |

   So BW28 pins that the column does *not* track the pane, BW29 is its control (the same
   widget switched to `-stretch 1` **does** track it — the decorative state M4 forbids),
   and BW30 proves the `-xscrollcommand` wiring reaches the scrollbar by widening `#0`
   past the pane and reading the scrollbar's own `get`.
3. **⚠ The prompt's red-list is incomplete by four.** `bind $f.tvf.tv` is also a SOURCE
   grep in BT04 (×2), BM01 and BH08; all four redded on the path move.
4. **`wvbs_common.tcl` really has no `tvf`** (the prompt is right, the PLAN is not), and
   no `wvbs_tv` was created — see §1.

## 5. Two defects this item found in the test surface itself

Both were found by **running** the sabotages, and both are the shapes spec §13 names.

* **⚠⚠ `pcall` returns the STRING `ERR:<msg>`, and `expr {[pcall winfo width $w] > 1}`
  throws on it.** Under the trap-1 sabotage the panes file stopped at check 17 of 34 —
  so the two checks written to *catch* that sabotage, BW31 and BW32, never ran, and the
  file reported a plausible-looking 3 FAILED. `bs_wait_mapped` had the same defect
  (`winfo ismapped` on a missing widget throws). Fixed with `bs_num` / `bs_set`, a
  non-throwing `bs_wait_mapped`, and `pcall` on every X-arm read. After the fix the same
  sabotage runs all 34 checks and BW31/BW32 are red, as designed.
* **⚠ BT31 and BM21 assumed the tree is taller than its rows.** They spelled the blank
  coordinate `[winfo height $tv] - 3`. MEASURED after the split: sidebar 500 →
  panedwindow 286 → tree **144 px** against ~220 px of rows, so that y lands **on a row**
  and both checks went red reporting a plot and a posted menu. The gate never stopped
  refusing — there was nowhere blank left to click. `bs_blank_y` now finds a provably
  blank y, escalating (grow the pane → collapse the groups) only as far as it must, and
  answers a negative code rather than 0 when it cannot; the precondition is its own
  check at both sites.

## 6. Measured geometry, for the items that follow

Fixture 1400x500, sidebar packed: sidebar **500**, panedwindow **286**, tree pane **157**
(tree widget 144), sea **124**, sash 157, fraction **0.549**. An **unmapped**
`ttk::panedwindow` reports `winfo height` **1** and `sashpos 0` **0** — which is why
`browser_sash` no-ops below height 2 and `browser_show` applies it after
`update idletasks` *and* again on the idle queue.

## 7. Declared limits

1. **Column `#0`'s 200 px is the shipped value, kept deliberately.** At the derived
   sidebar width (~583 px) the tree pane is wider than 200, so the h-scrollbar is idle in
   production today. It is not decorative — BW30 proves the wiring is live — but the
   width that makes it *useful* depends on what the tree holds, and item 10 is what
   decides that. Revisit there, not here.
2. **The sash is not persisted yet** (item 14). `browser_sash` is the accessor and the
   apply; `browsersash($token)` exists and is unset on teardown.
3. **The checkbuttons are inert** (item 12) and the sea is empty (item 11). Both are
   asserted — BW25 and BW35 — so "still inert" cannot rot into "never wired".
4. **`selection set` is blind to `-selectmode`** (§4.1). Narrowing a restored multi-id
   selection is owed by item 13/14; BW26b is the standing reminder.
