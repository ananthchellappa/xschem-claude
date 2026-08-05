# Item 7 — PIXEL — plot-destination dropdown

**Verdict: `[E]`** (PIXEL item — awaiting eyeball; no claim of visual correctness is made here).

ViVA's `Append / Replace / NewSubWin / NewWin`, mapped onto xschem's model as
`append` / `replace` / `newstrip` / `newtab`, exposed as a `Destination:` combobox at the
top of the Add Trace dialog and as an `Options > Plot Destination` cascade, persisted per
viewer WINDOW, and honoured by both landing seams (`add_trace_ok` and `plot_signals`).

**Files touched**
- `src/wave_viewer.tcl`
- `tests/headless/test_wave_sigsearch.tcl`

---

## 1. The design, in one paragraph

The policy splits in two, and the split is the whole design:

| half | what it does | where it lives |
|---|---|---|
| **WINDOW** | anything that must happen before a plan can be made — today exactly "make the tab" | `wviewer::dest_prepare` |
| **LANDING** | which strip index each signal goes to, and which strips must be emptied first | `wviewer::plan_plot`, **extended, not forked** |

`newtab` therefore collapses to `append` *inside* `plan_plot`: by the time the planner is
called the tab already exists and holds exactly one empty strip, which `append` lands in.
That sentence is written verbatim in `plan_plot`'s header, because a future reader will
otherwise read it as a bug.

**The shape invariant that carries the regression claim:** the `clear` key is emitted
**iff** `dest eq replace`. Every other destination — including the default — returns a dict
byte-identical to the one `plan_plot` has always returned. That is why
`test_wave_modes`' ~25 whole-dict comparisons stayed green, and it is measured, not
asserted: sabotage **U5** (emit `clear` unconditionally) fails 32 checks there.

## 2. What changed in `src/wave_viewer.tcl`

| # | site | change |
|---|---|---|
| 1 | namespace vars (beside `mode`/`target`) | `variable dest; array set dest {}` |
| 2 | `forget` | `variable dest` **declared** + `unset dest($token)` |
| 3 | beside `sb_type_code`/`sb_syntax_code` | `dest_norm`, `dest_label`, `dest_labels` — PURE |
| 4 | after `set_plot_mode` | `plot_dest`, `set_plot_dest`, `dest_prepare` |
| 5 | `plan_plot` | 7th arg `{dest append}`; new `newstrip` arm; the three mode arms build `$plan` and fall through to the `replace` tail |
| 6 | beside `plan_plot` | `plan_replace_clear` — PURE, the index-space owner |
| 7 | `build_menubar` | `Options > Plot Destination` cascade, four plain **commands** |
| 8 | `add_trace_dialog` | the `Destination:` row at row 0; every existing row +1 |
| 9 | `add_trace_ok` | reordered around the destination; new `atok_report` helper |
| 10 | `plot_signals` | `dest_prepare` → re-read layout → 7th arg → clear loop |

### The order in `add_trace_ok` is load-bearing

```
read the dialog  ->  refuse  ->  dest_prepare  ->  plan  ->  create  ->  clear  ->  add  ->  report
```

* **read first** — `dest_prepare` for New Tab calls `new_tab`, which calls
  `tab_drop_transients`, which **destroys `$top.wvadd`**. Measured, not feared. Picks are
  snapshotted by name before that line; nothing reads a widget after it.
* **refuse before prepare** — a refused OK ("one Name cannot cover N traces") must not
  leave a stray tab or a stray empty strip behind. Refusing *after* preparation would turn
  a validation message into a destructive gesture. `MS10`/`MS11` and sabotage **U6** watch
  this.
* **clear after create, before add** — so the multi arm's post-insert indices are the live
  ones when the clear runs.

### `plan_replace_clear`, and why it is its own named proc

The two arms live in **different index spaces**, and getting it wrong silently empties the
wrong strip — the traces just vanish from a strip nobody was looking at:

* **multi** — targets are POST-INSERT, so the strips this plan creates are `0..new-1` and
  `t >= new` means pre-existing.
* **single** — `new` is 0 or 1; when it is 1 the landing strip *is* the one just appended
  or the empty one just reused, so nothing pre-exists and the list is empty.

A brand-new or reused-empty strip is therefore never listed, so no no-op
`clear_graph_traces` call is made. That is not tidiness: that proc runs
`wavehl_remap_apply` and `markers_sweep_numbers`, both with real side effects.
`DS03`/`DS04`/`DS05` pin all three cases **purely**, so the index-space bug cannot hide
behind a GUI check.

## 3. The test — group `DS`, appended to `tests/headless/test_wave_sigsearch.tcl`

| | before item 7 | after |
|---|---|---|
| DISPLAY arm | 158 | **188** |
| `--nogui` arm | 90 | **104** |
| DISPLAY-only | 68 | 84 |

14 pure checks (`DS01-DS14`) run in **both** arms; 16 GUI checks (`DS20-DS31`, incl.
`DS25b`/`DS28a`/`DS28b`/`DS30b`) are DISPLAY-only behind the load-bearing
`SKIPPED: DS group (Tk/X arm only)` wording.

**File runtime**: 1.94 s in the DISPLAY arm, 0.37 s in `--nogui` (§7).

**Fixture.** The MS teardown destroyed `.wvms1` and dict-unset **both** the
`::wviewer::windows wvms` and `::wviewer::layouts wvms` entries, so item 6's helpers
(`ms_open`, `ms_err`, `ms_field`) were live procs pointing at a **dead token**. The DS
group re-registers `wvms` against a fresh `.wvds1` with `win_path $SLMAIN` (`.drw`, a real
mapped canvas — receipt 06 D1's rule) and reuses those helpers **unchanged**, per driver
note (d). One new helper, `ds_open {ngraphs seeds}`, is a layout *builder*, not a third
waiting or error idiom.

**Driver note (c) invariants, both kept.** The DS group adds **no** raw vectors and issues
no `raw new`, so `MS17`'s exact-10 inventory claim is still true; and `DS31` repeats
`MS18`'s teardown assertion (`rects 0`, `readonly 0`) plus two of its own (`tab_count 0`,
no `dest` entry) — `new_tab` leaves the ctx readonly with a rect drawn, so item 8's file
would otherwise inherit a dirty canvas.

**The inventory is 10 rows here, not 9** — MS scenario B materialized `db1` — and the
listbox order is raw order, unsorted (MS03's premise). Row indices are written into the
group header so a later reader does not have to re-derive them.

## 4. Sabotages

Ten measurements (the eight the PLAN names, plus two re-measurements after a coverage
widening and after a VOID X-death run). Every one injected into `src/wave_viewer.tcl`,
run, then restored from a **byte-exact backup taken of the ITEM state** and confirmed by
`diff -q` + `md5sum` — never by `git checkout --`, which while uncommitted would revert to
`7f8affec` and delete the item (it actually happened in item 6).

`src/wave_viewer.tcl` md5 after every single revert: `30f53c7920068473539d8f7735037d10`.

| # | injection | predicted | measured | verdict |
|---|---|---|---|---|
| **(a)-NARROW** | `add_trace_ok`: delete the `foreach ci [dget $plan clear {}]` loop | DS23, DS29 | **DS23, DS29** | EXACT |
| **(a)-WIDE** | `plan_plot`: `if {$dest eq {replace}}` -> `if {0}` | DS03 DS04 DS05 DS23 DS29 DS30 | those **+ DS30b** | superset, honest |
| **(b)-NARROW** | `add_trace_ok`: pass `append` when dest is `newstrip` | DS24, DS25 | **DS24, DS25** | EXACT |
| **(b)-WIDE** | `plan_plot`: delete the `newstrip` arm | DS06 DS07 DS08 DS24 DS25 | **exactly those** | EXACT |
| **U1** | `dest_norm` fallback `append` -> `replace` | DS10, DS12 | DS01 DS09 DS10 DS12 DS20 DS22 DS30b | superset, honest |
| **U2** | drop the `set_plot_dest` call in `add_trace_ok` | DS28 alone | **DS28b, DS28** | superset by one |
| **U3** | `dest_prepare` returns 1 without calling `new_tab` | DS26, DS27 | DS26 DS27 DS28a DS30 DS30b | superset — **and see below** |
| **U4** | `newstrip` arm: `$mode eq {multi} ? 0 : $ngraphs` -> always `$ngraphs` | DS07 alone | **DS07, DS08** | superset by one |
| **U5** | emit `clear` unconditionally | DS01, DS02 + ~25 in `test_wave_modes` | 8 here (DS01 DS06 DS07 DS08 DS09 DS10 DS22 DS30b) **+ 24 in `test_wave_modes`** | superset; **the shape claim is now evidence** |
| **U6** | move the Name+N>1 refusal AFTER `dest_prepare` | MS10 + a stray tab | **DS25b, DS26** — MS10 did **not** fire | gap found and closed |

### The two supersets that are structure, not sloppiness (ruling 23)

* **DS30b** rides along with DS30 in three rows. It is a *sequential-state* consequence:
  DS30 and DS30b share one strip, so a DS30 that leaves the wrong trace count makes DS30b's
  accumulate arithmetic wrong too. There is no injection point that severs one and not the
  other without giving each its own fixture — which would weaken what DS30b is for
  (proving `append` through the same seam is unchanged).
* **U1** reaches seven checks because `dest_norm` is the single normalising gate: with the
  fallback flipped, the *default* argument `append` itself normalises to `replace`, so
  every check that asserts "no `clear` key on the default path" fires. That is the fallback
  doing exactly the job it was given.

### Two checks were WIDENED because a measurement showed they proved less than they claimed

Ruling 17's corollary — *where a claim and its coverage disagree, widen the coverage or
narrow the claim, never neither* — fired twice. Both were caught by sabotage, not by
inspection:

1. **U6 failed NOTHING** at first. `MS10`/`MS11` do exercise the same refusal, but the MS
   window's destination is `append`, where `dest_prepare` does nothing at all — so moving
   the refusal after it is invisible there. **`DS25b` was added**: under `New Tab`, a
   refused OK must leave no tab, no trace, the dialog still up and the contract string
   verbatim. U6 then failed `DS25b` (+ `DS26` as a stray-tab cascade).
2. **`DS27` was green under U3.** As first written it asserted "after a successful New Tab
   OK the dialog is gone" — but a successful OK ends in its own `destroy $w`, so the dialog
   is gone whether or not `dest_prepare` ever made a tab. **`DS27` was rewritten onto the
   ERROR path**, which does separate the two worlds: with the tab really made the dialog is
   already gone when the failure is reported, so the message can only reach
   `wviewer::echo`; without it the dialog is still up holding the text. It now also asserts
   the tab-count delta. U3 fails it.

No check was weakened to manufacture a single-target number.

## 5. Eyeball note (this is what `[E]` owes)

**No visual claim is made here.** The headless checks pin geometry *numbers* (`grid info
-row` for eleven widgets, `-values`, `-state`) and *model outcomes* (per-strip trace lists,
tab counts). They cannot see whether it looks right. The queue owes exactly three things:

1. **Dropdown placement.** Is `Destination:` **above** `Graph:` the right reading order, and
   does the two-graph arm — where `Graph:` is also visible — still scan cleanly as a
   four-label column (`Destination / Graph / Expression / Name`)? The one-graph arm hides
   `Graph:` entirely (it is created but never gridded, unchanged behaviour), so
   `Destination:` sits directly above `Expression:` there; check that too.
   *Why a row and not a column:* the measured grid is 3 columns wide and column 2 holds
   **only** the listbox scrollbar, so a label parked there would detach the scrollbar from
   the listbox. Every free cell in this form is in column >= 2.
2. **New Tab actually raises the new tab.** The tab bar only packs at >= 2 tabs
   (`tabbar_refresh`), so the *very first* New Tab is also the first time the bar appears —
   watch for a canvas jump or a stale repaint (the known WSLg trap). `DS26` proves
   `tab_index` is 1 and the traces are in the new tab's model; it cannot prove the user
   sees them.
3. **The New Tab error path is CIW-only by construction.** Type a bad expression with
   `New Tab` selected and confirm the message is actually visible — it goes to
   `wviewer::echo` (CIW + logfile), *not* to the dialog's red label, because the dialog is
   already gone. `DS27` pins the mechanism (`ms_err` returns `NO-DIALOG`); only an eyeball
   can say the user notices.

## 6. Divergences and declarations

**D-a — receipt renamed.** The PLAN said `receipts/07_destination.md`; driver note (a) and
the batch convention (items 2-6) say `NN_receipt.md`. This file is `07_receipt.md`.

**D-b — ViVA's unit-collision rule is NOT IMPLEMENTABLE and was not attempted.** ViVA's
`Append` opens a new Y axis on a unit mismatch and a new subwindow past four axes. xschem
has **no unit metadata at all**: `save.c read_dataset` (`src/save.c:593`) parses the
variable table at `src/save.c:785` with
`sscanf(line, "%*[\t]%d%*[\t]%[^\t]", &i, varname)` — only the index and the name; ngspice's
third tab-separated *type* column is never captured, and `Raw` carries no unit or type
array. Per the PLAN's ⚠, recorded and not attempted.

**D-c — `newtab` is a TAB, not a window, and the ViVA names are deliberately not aliases.**
ViVA's `NewWin` means a WINDOW; ours means a TAB, and ViVA's `NewSubWin` maps to our
`New Strip`. `dest_norm` therefore **rejects** `NewSubWin` and `NewWin` (they land on the
`append` fallback, pinned by `DS12`). Accepting the ViVA spelling would promise a fidelity
this mapping does not have.

**D-d — the destination is per WINDOW, not per TAB.** Deliberately absent from
`tab_freeze`/`tab_thaw`, which do carry `mode` and `target` per tab. One destination
governs every tab of the window, so switching tabs cannot silently change where the next
plot lands. The asymmetry is commented at the declaration site so it does not read as an
omission.

**D-e — AT02/AT03 expectations moved by the grid renumber.** `AT02` `{3 4 5 6 7}` ->
`{4 5 6 7 8}`, `AT03` `-row` `0` -> `1`. The **claim is re-asserted, not weakened**: the
same five widgets, still consecutive, still in the same order, still with no hole — only
the origin moved. It is the identical renumber the PLAN told item 5 to perform when it
inserted the search bar. `AT01`, `AT04` and `AT16` are untouched (existence and the
ungridded-combobox arm are unaffected), and nothing in `gsl_frozen_ref`, `GSO_NAMES`,
`GSO_PATS`, `GSO_BLOBS` or `GSPLAIN` was touched (driver note (d)).

**D-f — New Tab's error reporting is asymmetric, and that is declared, not fixed.** Three
destinations report a failed add in `$w.err`; New Tab cannot, because `dest_prepare`
already destroyed the dialog (MEASURED — `winfo exists $top.wvadd` goes 1 -> 0 across
`new_tab`). Those messages go through `wviewer::echo`, the 0207-correct CIW+logfile seam
the tab commands already use. The new `wviewer::atok_report` makes "the label I want to
write to has vanished" an **assertable value** (`dialog` / `echo`), never an exception —
driver note (e)(2) in a new costume, and the probe proved the branch reachable rather than
theoretical.

**D-g — two seams deliberately NOT wired to the destination.**
* `predict_colors` / `plan_colors` — `ase::ui::dp_finish` passes explicit `$qcolors` to
  `plot_signals`, so a Direct-Plot trace always gets exactly the colour the schematic was
  painted with, whatever the destination. Only the *distinctness heuristic* can differ under
  Replace (it counts the target's traces before they are cleared). Declared; not fixed.
* `ase::ui::auto_plot` — it does not route through `plot_signals` at all
  (`ensure_auto_graph` + `clear_graph_traces` + `add_trace` directly), so the destination
  deliberately does not govern the ASE auto strip. Item 13's always-replace contract owns
  that strip. Declared; not fixed.

**D-h — the Graph combobox is NOT disabled under New Strip / New Tab** even though it has
no effect there. A named, deliberate gap for whoever polishes the form (or for item 9's
toolbar). `DS25` pins that it is *ignored*, so the gap is cosmetic, not behavioural.

**D-i — the `wvms` token is re-registered against `.wvds1`;** item 6's `ms_open`/`ms_err`/
`ms_field` are reused unchanged. See §3.

**D-j — `add_trace_ok` now returns `{}` explicitly.** The rewrite ends in
`catch {destroy $w}` (New Tab may already have destroyed it), and `catch`'s `0` would
otherwise have become the proc's result. Caught by `MS02`/`MS08`/`MS12` on the first run —
which is exactly what those checks are for.

**D-k — `select_tab` takes a tab ID, not an index.** `tabs_init` seeds id 1; passing the
index `0` is a silent no-op that reads as a broken restore. Noted at the `DS28a` call site
so the next author does not repeat it.

**D-l — STEP 7 (the Options cascade) was NOT dropped.** The clock allowed it. It uses four
plain `command` entries, **not** radiobuttons: Tk writes a radiobutton's `-variable`
*before* it fires `-command`, so `set_plot_dest` would always see the new value already in
place, find "no change", and never write its replayable log line. Menu-assertion risk was
checked — `test_wave_viewer` G2 enumerates top-level cascades only, `test_wave_modes` MG4
`lsearch`es for `Options` and names `$mb.options.plotmode` explicitly — and both stayed
green. It carries **no dedicated check**: the cascade is built inside `build_menubar`,
which the DS fixture (a hand-registered token, no real `wviewer::open`) never runs. Named
gap, deliberate; item 9's toolbar is the other route to the same accessor.

**D-m — `set_plot_dest` is called before the refusal**, so a refused OK still persists the
dropdown choice. That is intended: the dropdown *is* the setting, independently of whether
this particular OK went through.

## 7. Runs

`cd src && make` -> `Nothing to be done for 'all'` (Tcl only), as expected.

**The item file**, both arms, in-tree binary:

| arm | checks | wall |
|---|---|---|
| DISPLAY | **188** ALL PASS | 1.94 s |
| `--nogui` | **104** ALL PASS | 0.37 s |

**The measured blast radius** — `plot_signals` is the Direct-Plot pipeline's landing seam,
so its five drive-site suites plus the two dialog suites were run explicitly, and all seven
were re-run clean after the last sabotage revert:

```
PASS | test_wave_sigsearch     188   PASS | test_wave_clear_all      75
PASS | test_wave_modes         485   PASS | test_wave_grid          240
PASS | test_wave_viewer        400   PASS | test_wave_split_strip   221
PASS | test_wave_tabs          172                        7/7 runs passed
```

**`tests/headless/full_audit.sh`** — `SUMMARY: 258 pass  23 fail  1 crash/timeout  1 skip
(total 283)`. Compared as SETS, not counts (the baseline's own warning):

* **all 16 HARD baseline names present**, none missing, and each on its recorded check —
  the action-log cluster (`test_ase_log_seam_0207` on `PS0`/`PS2`-`PS12`, plus
  `test_select_at`, `test_selflog_output`, `test_phase3_mints`, `test_ciw`), the three PDK
  libmgr names, and `test_cadence_drag` (re-anchored, any failure is baseline).
* **6 fails from the FLAKY list, each on its own listed check name**: `test_wave_hilight`
  (WD2/WD2c), `test_wave_markers` (MF1), `test_ase_unnamed_net` (AN8),
  `test_nh_anim_rearm` (R1/R2/R4/R6), `test_altf5_ciw`, `test_ase_persist`.
* **1 crash/timeout**: `test_alt_transform_group_0116` — the environmental self-skip whose
  name flaps run to run, exactly as the baseline describes.
* **1 skip**: `test_ase_savestate_adopt`.
* **1 VOID**: `test_add_wire_label`, whose entire output was
  `X connection to :0 broken (explicit kill or server shutdown)`. Per the baseline rule that
  is not a measurement. **Re-run: `ALL PASS (59 checks)`.**

**No non-baseline failure.** Nothing in `test_wave_*` failed except the two listed flakes,
neither of which is in this item's blast radius and both of which failed on their listed
check names, so ruling 22's A/B was not needed.

### One VOID run during the sabotage phase, diagnosed not ignored

Two consecutive U3 measurements truncated mid-file. Cause found before blaming the harness
(ruling 19): `/mnt/wslg/stderr.log` ends in
`Fatal server error: (EE) request could not be marshaled: can't send file descriptor` —
the known WSLg Xwayland abort, which kills every client. The server came back on its own;
U3 was re-measured on a live server and is the row in §4. The X-death runs are discarded,
not interpreted.

### Authorization window

The user's test-at-will grant expired at 06:01 MST (epoch 1785934870). Every suite run
above — the item file, the seven-suite blast radius, the full audit, all ten sabotage
measurements and the final clean re-run — completed **inside** the window, through
`run_suites.sh` / `gated_xschem.sh`. `GUI_GATE=0` was never set and no control file was
ever hand-written. Nothing was left running past the boundary.

## 8. Carry-forward to item 8

`wviewer::plot_dest <token>` is **THE accessor** the browser's three plot gestures must
call — item 9 says so explicitly. Nothing may re-implement the destination policy, exactly
as nothing may re-implement `sig_match`. `plot_signals` is already wired, so a gesture that
routes through it inherits the destination for free; a gesture that calls `add_trace`
directly does **not**, and must go through `plot_signals` or read `plot_dest` itself.

Process state left behind for item 8's new file (settled decision 9 starts a second file
there, but the *process* is only shared within a file — this is for anyone who appends
here anyway): the DS group destroys `.wvds1`, `tabs_forget`s and dict-unsets `wvms` from
both registries, unsets `::wviewer::dest(wvms)` / `target(wvms)`, and restores the main
context to `readonly 0` with an empty drawing (`DS31`). It leaves the procs `ds_open`,
`ds_counts` and `ds_pick2` defined. It adds no raw vectors and creates no xschem context.
