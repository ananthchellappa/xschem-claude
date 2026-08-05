# Item 7 — PIXEL — plot-destination dropdown

**Verdict: `[E]`** (PIXEL item — awaiting eyeball; no claim of visual correctness is made here).

> **⚠ THIS RECEIPT HAS BEEN AMENDED BY A FIXUP COMMIT.** The adversarial verifier
> rejected 876e8f0f on five problems; **§9 is the record of the repair** and is the
> authoritative section where it contradicts anything above it. Every claim in §1-§8
> has been re-checked against the fixed-up code and the ones that were false have
> been corrected in place (they are called out in §9). The sabotage table in §4 is
> the measurement of **876e8f0f as first shipped** and is kept for the record; §9.6
> carries the six measurements of the code that is actually committed.

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

`newtab` therefore reaches the `append` policy *inside* `plan_plot`: by the time the planner
is called the tab already exists and holds exactly one empty strip, which `append` lands in.
That sentence is written verbatim in `plan_plot`'s header, because a future reader will
otherwise read it as a bug. **It happens BY FALL-THROUGH, not by a `set dest append`
statement** — see §9.3; the body names only `newstrip` and `replace`.

**The shape invariant that carries the regression claim:** the `clear` key is emitted
**iff** `dest eq replace`. Every other destination — including the default — returns a dict
byte-identical to the one `plan_plot` has always returned. That is why
`test_wave_modes`' ~25 whole-dict comparisons stayed green, and it is measured, not
asserted: sabotage **U5** (emit `clear` unconditionally) fails **24 checks in
`test_wave_modes`** — plus 8 in this file, **32 in total**. (The "32 there" in the first
draft of this receipt was the TOTAL mislabelled as the `test_wave_modes` count; verifier
problem **P4**.)

**And Replace is a SINGLE-MODE policy** — declared, not discovered: multi-plot lands every
signal in a strip it creates or a reused *empty* one, never on an occupied strip, so under
multi there is nothing for Replace to clear and it is behaviourally identical to Append.
§9.1 is the whole argument and the coverage that now pins it.

## 2. What changed in `src/wave_viewer.tcl`

| # | site | change |
|---|---|---|
| 1 | namespace vars (beside `mode`/`target`) | `variable dest; array set dest {}` |
| 2 | `forget` | `variable dest` **declared** + `unset dest($token)` |
| 3 | beside `sb_type_code`/`sb_syntax_code` | `dest_norm`, `dest_label`, `dest_labels` — PURE |
| 4 | after `set_plot_mode` | `plot_dest`, `set_plot_dest`, `dest_prepare` |
| 5 | `plan_plot` | 7th arg `{dest append}`; new `newstrip` arm; the three mode arms build `$plan` and fall through to the `replace` tail |
| 6 | beside `plan_plot` | `plan_replace_clear` — PURE, the index-space owner (and, since §9.2, the EMPTY-strip filter) |
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
  `t >= new` is the pre-existing strip `t - new`.
* **single** — `new` is 0 or 1; when it is 1 the landing strip *is* the one just appended,
  so nothing pre-exists; when it is 0 the target is a live strip in the unshifted space.

A brand-new **or reused-empty** strip is never listed, so no no-op `clear_graph_traces`
call is made. That is not tidiness: that proc runs `wavehl_remap_apply`,
`markers_sweep_numbers` and `set_graphs` (a redraw), all with real side effects.
⚠ **The reused-empty half of that sentence was FALSE in the first draft and is now TRUE
because the proc takes the empty-strip list as a 4th argument** — verifier problem **P2**,
repaired in §9.2. `DS03`/`DS04`/`DS04b`/`DS04c`/`DS05`/`DS05b` pin every case **purely**,
and `DS23`/`DS23b`/`DS30`/`DS30c`/`DS30d` pin the *call itself* with a recorder, so
neither the index-space bug nor a no-op clear can hide behind a trace-count check.

## 3. The test — group `DS`, appended to `tests/headless/test_wave_sigsearch.tcl`

| | before item 7 | at 876e8f0f | **after the fixup** |
|---|---|---|---|
| DISPLAY arm | 158 | 188 | **194** |
| `--nogui` arm | 90 | 104 | **107** |
| DISPLAY-only | 68 | 84 | 87 |

17 pure checks (`DS01-DS14`, incl. `DS04b`/`DS04c`/`DS05b`) run in **both** arms; 20 GUI
checks (`DS20-DS31`, incl. `DS23b`/`DS25b`/`DS28a`/`DS28b`/`DS30b`/`DS30c`/`DS30d`) are
DISPLAY-only behind the load-bearing `SKIPPED: DS group (Tk/X arm only)` wording.

**File runtime**: 2.4 s in the DISPLAY arm, 0.4 s in `--nogui` (§7).

**Fixture.** The MS teardown destroyed `.wvms1` and dict-unset **both** the
`::wviewer::windows wvms` and `::wviewer::layouts wvms` entries, so item 6's helpers
(`ms_open`, `ms_err`, `ms_field`) were live procs pointing at a **dead token**. The DS
group re-registers `wvms` against a fresh `.wvds1` with `win_path $SLMAIN` (`.drw`, a real
mapped canvas — receipt 06 D1's rule) and reuses those helpers **unchanged**, per driver
note (d). The new helpers are a layout *builder* (`ds_open {ngraphs seeds}`) and, since the
fixup, a *call recorder* (`ds_spy_on`/`ds_spy_off` + the two gesture wrappers `ds_spy_ok` /
`ds_spy_plot`, §9.1) — neither is a third waiting or error idiom; the recorder is the
"make the thing I need to observe an assertable value" rule applied to a **call** instead of
a vanished widget. All four are `rename`d away before the teardown.

**Driver note (c) invariants, both kept.** The DS group adds **no** raw vectors and issues
no `raw new`, so `MS17`'s exact-10 inventory claim is still true; and `DS31` repeats
`MS18`'s teardown assertion (`rects 0`, `readonly 0`) plus three of its own (`tab_count 0`,
no `dest` entry, and since the fixup no `mode` entry either — `DS30c` seeds a plot mode on
this token and it must not outlive the group) — `new_tab` leaves the ctx readonly with a
rect drawn, so item 8's file would otherwise inherit a dirty canvas.

**The inventory is 10 rows here, not 9** — MS scenario B materialized `db1` — and the
listbox order is raw order, unsorted (MS03's premise). Row indices are written into the
group header so a later reader does not have to re-derive them.

## 4. Sabotages — **AS FIRST SHIPPED (876e8f0f). §9.6 supersedes this for the committed code.**

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

**D-n — REPLACE IS A SINGLE-MODE POLICY (added by the fixup).** Under multi-plot it is
behaviourally identical to Append, because multi never lands on an occupied strip. Declared
in `plan_plot`'s ⚠⚠, in `plan_replace_clear`'s header, at the `plot_signals` call site, and
pinned by `DS05`/`DS05b`/`DS30c`. The `clear` key is still emitted under multi (the dict
shape tracks the destination, not the mode) — it is always empty. **Widening this into
"Replace wipes the whole plot area under multi" is a DIFFERENT policy and is deliberately
NOT done here**; whoever wants it owns the reuse arithmetic that follows from it. §9.1.

**D-o — the `newtab` -> `append` collapse statement was REMOVED (fixup).** Measured dead;
`newtab` reaches the append policy by fall-through. `DS09` pins the behaviour and sabotage
S6 proves `DS09` can fail. §9.3.

**D-p — `add_trace_ok` now hands `plan_plot` the real empty-strip list (fixup).** It cannot
change where the dialog's gesture lands (argued and sabotage-checked, §9.2); it exists only
so Replace onto an already-empty target makes no no-op `clear_graph_traces` call. `DS23b`
is its only oracle, and sabotage S5 fails exactly that check.

**D-m — `set_plot_dest` is called before the refusal**, so a refused OK still persists the
dropdown choice. That is intended: the dropdown *is* the setting, independently of whether
this particular OK went through.

## 7. Runs — **AT 876e8f0f. §9.7 is the run record for the committed code.**

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

⚠ **AND IT INHERITS ONE DECLARED LIMIT: Replace does nothing under multi-plot** (D-n/§9.1).
A browser gesture that offers Replace while the window is in multi-plot mode is offering
Append. If item 9's toolbar wants to say so in the UI — grey it out, or footnote it — that
is a UI decision it owns; the policy layer states the fact and pins it, and does not
pretend otherwise.

Process state left behind for item 8's new file (settled decision 9 starts a second file
there, but the *process* is only shared within a file — this is for anyone who appends
here anyway): the DS group destroys `.wvds1`, `tabs_forget`s and dict-unsets `wvms` from
both registries, unsets `::wviewer::dest(wvms)` / `target(wvms)`, and restores the main
context to `readonly 0` with an empty drawing (`DS31`). It leaves the procs `ds_open`,
`ds_counts` and `ds_pick2` defined. It adds no raw vectors and creates no xschem context.

---

# 9. THE FIXUP — what the verifier rejected, and what changed

The verifier raised five problems against 876e8f0f. **Three were real defects (P1, P2, P3),
one was a real bookkeeping error (P4), one was real baseline hygiene that is not this
item's (P5).** None was disputed; nothing was argued away. One repair commit, three files:
`src/wave_viewer.tcl`, `tests/headless/test_wave_sigsearch.tcl`, this receipt (plus the
PLAN's baseline block for P5).

| | problem | verdict | resolution |
|---|---|---|---|
| **P1** | Replace is functionally inert under multi mode, undeclared and untested | **REAL** | claim NARROWED and the narrowing pinned — §9.1 |
| **P2** | `plan_replace_clear`'s "a reused-empty strip is NEVER listed" is false in both arms; the single-arm reuse path is uncovered | **REAL** | behaviour WIDENED to match the claim, path covered — §9.2 |
| **P3** | the `newtab` collapse line is dead code, yet credited as load-bearing | **REAL** | line deleted, credit withdrawn — §9.3 |
| **P4** | "U5 fails 32 checks in `test_wave_modes`" vs 24+8 elsewhere | **REAL** | 24 in `test_wave_modes`, 32 total; §1 corrected — §9.4 |
| **P5** | `test_verb_noun_copy_move` on neither baseline list; second self-skip name undocumented | **REAL, not item 7's** | PLAN baseline amended — §9.5 |

## 9.1 P1 — Replace under multi: the claim is NARROWED, and the narrowing is pinned

The verifier is right about the mechanism and right that nothing declared it. In the multi
arm every landing site is either a strip the plan **creates** (`0..new-1`) or a **reused
empty** strip — `plan_plot` builds `sites` from exactly those two sources — so multi-plot
**never lands on an occupied strip, for any destination**. There is therefore nothing for
Replace to clear there, and no fixture can make Replace destroy a trace under multi.

Ruling 17's corollary says widen the coverage or narrow the claim. **Narrowed**, because the
alternative is a *different policy*: "wipe the whole plot area" is not "clear the target
graph's traces first, then add", which is the mapping item 7 was given, and inventing it
here would also re-open the reuse arithmetic (a wiped strip becomes reusable, which changes
`new`). The narrowing is now written in three places and pinned in four checks:

* `plan_plot`'s header carries a **⚠⚠** stating that Replace is a single-mode policy, why
  that is structural rather than an oversight, and what the alternative would have meant.
* `plan_replace_clear`'s header states the consequence (`{}` under multi) **and** notes that
  the filter is still written generally, so a future multi arm that *could* land on an
  occupied strip gets the right answer instead of a silent no-clear.
* `plot_signals`' clear loop says the same at the call site.
* **`DS05`** (rewritten: `clear` is `{}` in both sub-cases), **`DS05b`** (new, a
  DIFFERENTIAL over five multi arms — mix, all-new, all-reuse, auto-strip: `replace` ==
  `append` + an empty `clear` key), **`DS30c`** (new, LIVE: the window in multi-plot, a
  Replace gesture through `plot_signals`, the occupied strip keeps all three traces **and
  zero clear calls are made**).

⚠ **`DS30c` needed the call recorder to say anything at all**, and that is the honest part
of this repair. Under multi the landing strip is empty, so a wrong Replace destroys nothing
and *every trace-count assertion still passes*. Counts cannot see this defect. What they
can see is the **call**: `ds_spy_on`/`ds_spy_off` rename `wviewer::clear_graph_traces` to a
recorder that delegates to the real proc, so "which strips were cleared, in order" becomes
an **assertable value** (driver note (e)(2) again, in a third costume). `DS30` is its
positive control (`{1}` — an occupied target IS cleared, exactly once), without which the
zero-call rows would only prove the recorder never sees anything.

## 9.2 P2 — the header claim was false; the CODE was fixed to match it

Both halves of the verifier's measurement reproduce:
`plan_plot single 3 1 2 1 {1 2} replace` returned `clear {2}` where strip 2 is a **reused
empty** strip, and under multi *every* listed strip was one. So the shipped code really did
call `clear_graph_traces` — `wavehl_remap_apply` + `markers_sweep_numbers` + a `set_graphs`
redraw — on strips with nothing to clear, which is exactly the "real work with real side
effects" the comment said it avoided.

The claim is the right one, so the **behaviour was widened to meet it**:

```
proc wviewer::plan_replace_clear {mode ngraphs plan {free {}}}   ;# 4th arg is new
  ... multi:  t < new  -> created;   pre = t - new
      single: new > 0  -> created;   pre = t
      then:   pre in $free -> REUSED EMPTY, nothing to clear -> skip
```

`free` is `plan_plot`'s already-sanitized empty-strip list (not the raw `$empties`), so the
filter reasons about the same indices the arms planned against. **Both call sites feed it:**

* `plan_plot` passes `$free` — one-line change at the `replace` tail.
* `add_trace_ok` no longer passes `{}` as the 6th argument; it passes
  `[wviewer::empty_graph_indices $gs -1]`. ⚠ This **cannot move where the dialog's gesture
  lands** — the single arm consults that list only when the stack is empty, where it is
  empty too, and `auto` deliberately stays `-1` because the dialog *names* its graph and may
  name the auto strip — it only lets the planner tell "Replace onto a strip holding traces"
  from "Replace onto a strip that is already empty". Without it, pressing Replace twice, or
  Replace into a fresh strip, made a no-op clear call every time.

**The uncovered path is now covered**, three ways, and the verifier's exact case is one of
them: **`DS04b`** (`single 3 1 2 1 {1 2} replace` -> `clear {}`, plus an auto-strip variant)
— pure, and it is the single-arm reuse path no check reached before; **`DS04c`** — the
NEGATIVE half, three cases where only the target differs (empty target -> `{}`, occupied
target -> `{1}`, occupied target with no empties list -> `{1}`), because "clears nothing" is
worth nothing without a neighbouring case that clears something; **`DS23b`** and **`DS30d`**
— LIVE at both seams (dialog and `plot_signals`), asserting the traces land identically
*and* the recorder saw **no call at all**.

## 9.3 P3 — the collapse line is gone, and so is the credit

Reproduced: `newtab` is neither `newstrip` nor `replace`, so `if {$dest eq {newtab}} {set
dest append}` changed nothing. It is **deleted**. `plan_plot`'s ⚠ now says in as many words
that the body names only `newstrip` and `replace`, that `newtab` reaches the append policy
**by fall-through**, that the collapse line was measured to change nothing and removed
because *a line that cannot fail reads as a guard and is not one*, and that `DS09` pins the
**behaviour**, which is what callers depend on either way. `DS09`'s own comment says the
same. Nothing in the receipt or the commit message credits the collapse any more.

⚠ And `DS09` is not a check that cannot fail: sabotage **S6** (`newstrip` arm made to accept
`newtab` too) fails it — see §9.6.

## 9.4 P4 — the number

**U5 failed 24 checks in `test_wave_modes` and 8 in this file: 32 in total.** §1 said "32
there", which was the total mislabelled as the `test_wave_modes` count; §4's table and the
structured claim were right. §1 is corrected and now states all three numbers.

**And the number is now RE-MEASURED rather than reconciled** — the whole point of the
receipt being that it is measured. U5 (`if {$dest eq {replace}}` -> `if {1}`, i.e. emit
`clear` unconditionally) injected into the **committed** `wave_viewer.tcl`:

```
test_wave_modes      24 FAIL      <- unchanged: this is the ~25 whole-dict oracle
test_wave_sigsearch  10 FAIL      <- was 8 at 876e8f0f; the fixup added DS04b/DS04c/DS05b
```

so 24 + 10 = **34** against the code as committed, and the `test_wave_modes` figure the
verifier could not reconcile is confirmed at **24**. Restored from the byte-exact backup,
`diff -q` clean, md5 `a4756b45d94431d00cf5b42a29dd6efc`.

## 9.5 P5 — baseline hygiene (not item 7's, and re-verified as not item 7's)

* **`test_verb_noun_copy_move`** — the verifier's audit failed it on `move: pin relocated to
  60` and then passed it 3/3. It is a mouse-gesture assertion in the schematic editor that
  cannot reach `wave_viewer.tcl`; my own audit for this fixup is the second independent
  data point. **Added to the PLAN's FLAKY list** so it does not burn item 8.
* **the self-skip name flaps to `test_rotate_stretch_reconnect_0099` as well** — the
  baseline block named only `test_alt_transform_group_0116 / _0098 / _0107 /
  test_ase_dirty`, and the verifier saw two self-skips in one run. **Both facts added.**
* **counts are not reproducible run to run** (258/23/1/1 vs 263/18/0/2, both baseline-clean
  as SETS). That is the baseline's own documented rule; the PLAN note now says the *totals*
  move too, not only the composition, so nobody reads a count delta as a regression.

⚠ **Those three amendments are in `doc/claude/signal_browser_batch/PLAN.md`, which is
DELIBERATELY LEFT UNCOMMITTED.** It was already dirty on arrival (batch bookkeeping the
driver owns, listed as expected-dirty by the baseline block itself), and 876e8f0f did not
carry it either. Committing it would sweep the driver's pending edits into an item commit
and break the "EXACTLY the scoped files" scope check. The content belongs in the PLAN; the
commit does not.

## 9.6 Sabotages — the six that measure the CODE THAT IS COMMITTED

Every one injected into `src/wave_viewer.tcl` by a `python3` patch that asserts its anchor
occurs exactly once and refuses a no-op, run through `gated_xschem.sh` (DISPLAY arm, all
194 checks), then restored **from a byte-exact backup of the item state** — never
`git checkout --`, which even now would revert to 876e8f0f and delete the fixup.
`md5sum src/wave_viewer.tcl` after **every** revert: `a4756b45d94431d00cf5b42a29dd6efc`,
confirmed by `diff -q` each time — **and that is the md5 of the file this commit contains**,
not of an intermediate. (The six were first measured at `8e929abb…`; one comment-only edit
followed, so **all six were re-run from scratch against the committed bytes** and every row
below reproduced identically. A sabotage table that describes bytes other than the committed
ones is not evidence about the commit.)

| # | injection | predicted | measured | verdict |
|---|---|---|---|---|
| **S1** (PLAN a) | `plan_plot`: `if {$dest eq {replace}}` -> `if {0}` (Replace behaves as Append) | DS03 DS04 DS04b DS04c DS05 DS05b DS23 DS29 DS30 DS30b | those **+ DS30c** (11) | superset by one, structural — see below |
| **S2** (PLAN b) | `plan_plot`: `if {$dest eq {newstrip}}` -> `if {0}` (New Strip respects plot mode) | DS06 DS07 DS08 DS24 DS25 | **exactly those** (5) | EXACT |
| **S3** | `plan_replace_clear`: delete the `lsearch $free $pre` filter line | DS04b DS04c DS05 DS05b DS23b DS30c DS30d | **exactly those** (7) | EXACT |
| **S4** | `plan_plot`: pass `{}` instead of `$free` to `plan_replace_clear` | same 7 as S3 | **exactly those** (7) | EXACT |
| **S5** | `add_trace_ok`: pass `{}` as the empties argument again (the pre-fix line) | **DS23b alone** | **DS23b alone** (1) | EXACT |
| **S6** | `plan_plot`: `newstrip` arm made to accept `newtab` too | DS09 (+DS26) | **DS09, DS26** (2) | as predicted |

**S1's superset is the DS30/DS30b/DS30c chain, ruling 23's shape** — those three share one
layout: S1 leaves strip 1 with 3 traces instead of 2 at DS30, DS30b then accumulates to 4,
and DS30c's `{1 3}` reads `{1 4}`. There is no injection point that severs one and not the
others without giving each its own fixture, which would cost DS30b/DS30c the thing they are
for (that the *same* seam is unchanged under append, and unharmed under multi). Checked, not
assumed: `DS23b` did **not** fire under S1, which is correct — an append onto an
already-empty target is genuinely identical, and that is the check discriminating the two
worlds rather than tracking the sabotage.

**S3 and S4 are deliberately a matched pair**: the filter and its wiring are one mechanism,
and measuring both proves the coverage does not depend on which end of it breaks. **S5 is
the sharp one** — a single named target, and it is the check that pins the `add_trace_ok`
half of §9.2, which would otherwise have been a code change with no oracle. That is the sin
P2 named, and it is not repeated here.

## 9.7 Runs (fixup)

`cd src && make` -> `Nothing to be done for 'all'` (Tcl only), unchanged.

| run | result |
|---|---|
| `run_suites.sh test_wave_sigsearch` | **ALL PASS (194 checks)**, and 3/3 on a `-n 3` re-run |
| `run_suites.sh --nogui test_wave_sigsearch` | **ALL PASS (107 checks)** |
| blast radius: `test_wave_modes` / `test_wave_viewer` / `test_wave_tabs` / `test_wave_clear_all` / `test_wave_grid` / `test_wave_split_strip` | **6/6 ALL PASS** (485 / 400 / 172 / 75 / 240 / 221) |

⚠ **Two `run_suites.sh` runs TIMED OUT at 200 s on this file and are VOID, not
measurements.** Diagnosed before blaming the harness (ruling 19): `/mnt/wslg/stderr.log`
ends in a fresh Xwayland start (`Failed to initialize glamor, falling back to sw`, the
xkbcomp keycode warnings), i.e. the WSLg server restarted underneath the run, and a client
launched into that window blocks in the X handshake. The same file run directly at that
moment completed in **2.42 s wall** and, once the server settled, `-n 3` through
`run_suites.sh` passed 3/3 at 194. Nothing about the file got slower.


## 9.8 The eyeball list is UNCHANGED

The fixup touches the **planner and the coverage only** — `plan_plot`'s comments and one
call argument, `plan_replace_clear`'s filter, one argument at the `add_trace_ok` call site,
and test code. **No widget, no grid row, no label, no menu entry and no colour changed**, so
§5's three eyeball items stand exactly as written and nothing new is owed to the queue. The
verdict stays **`[E]`**: still no claim of visual correctness.

One thing the eyeball may now find worth a sentence in the UI, though it is a *policy*
statement and not a defect: with the window in **multi-plot** mode the `Replace` entry does
the same thing as `Append` (D-n). It is honest, declared and pinned; whether the dropdown
should say so is item 9's call, not this item's.

## 9.9 `full_audit.sh` (fixup)

`SUMMARY: 267 pass  16 fail  0 crash/timeout  0 skip  (total 283)`, and it is a valid
measurement: **`X connection to :0 broken` occurs ZERO times** in the log (grepped before
interpreting anything). Compared as SETS, per the baseline's own rule:

* **15 of the 16 HARD names**, each on its recorded check — the action-log cluster
  (`test_ase_log_seam_0207` on `PS0`/`PS0b`/`PS2`-`PS12`/`RP1`, `test_select_at`,
  `test_selflog_output`, `test_phase3_mints`, `test_ciw`), the three PDK libmgr names on
  their `library_list = exactly the N intended libs` check with the `{SANDBOX TEST}` extras
  from the user-level `library.defs`, `test_ase_window` on `W7`, `test_lib_manager_gui` on
  `GUI8`/`GUI9`, `test_lib_manager_locate` on `LM-LOC3`, `test_lib_sweep` on `P1`/`P1b`,
  `test_reopen_readonly`, `test_rotate_stretch_short_0104`, and `test_cadence_drag`
  (re-anchored; any failure is baseline).
* **`test_fluid_editing` PASSED** — the documented composition flap; the verifier's audit saw
  the same thing. Compare SETS, not counts.
* **ZERO fails from the FLAKY list, zero skips, zero crashes.**
* **ONE unlisted name: `test_fluid_bodyshove_guards_0132`**, on `G2: shove landed at OWN body
  edge x=160 (not flung by Rfar)`. **3/3 ALL PASS on a solo re-run** (14 ok, 0 fail each).
  It is a wire-shove geometry assertion; the file does not contain the strings `wviewer`,
  `wave_viewer` or `graph` **anywhere** (grepped), so none of this item's changed procs —
  `plan_plot`, `plan_replace_clear`, `add_trace_ok`, all of which run only from a viewer
  gesture — is reachable from it. Ruling 22's A/B was not needed for a test that cannot
  execute the changed lines at all. Settled as an **unlisted flake**, the same shape as the
  `test_verb_noun_copy_move` the verifier hit, and **added to the PLAN's FLAKY list** so the
  next item does not spend the hour.

**No non-baseline failure.** Every `test_wave_*` suite passed, including
`test_wave_sigsearch` inside the audit itself and the two known viewer flakes
(`test_wave_markers`, `test_wave_hilight`, `test_wave_trace_menu`) which all passed this run.

### Authorization window

The user's test-at-will grant had lapsed at 06:01 MST, **but a live gate grant was in force
for this session** (`~/.claude/gui_test_gate/allow_until` = 1785941695, `control` = `RUN`),
so every run above started unprompted through the normal gate. **`GUI_GATE=0` was never set,
no control file was ever written or edited, and no run outlived the grant.** Every suite went
through `run_suites.sh` or `gated_xschem.sh`; nothing was launched in a bare loop.

## 9.10 `test_wave_modes` MG17 — an A/B, because a re-run count is not evidence (ruling 22)

**What happened.** After the fixup was committed, `test_wave_modes` failed **3 times in a
~3-minute window** immediately following the full audit — once in a 3-suite batch and twice
in a `-n 6` — always inside the **MG17** block (issue 0173, the context-borrowing bracket):

```
FAIL: MG17 in_ctx re-asserted the viewer title it clobbered, once -> {0} (exp {1})
FAIL: MG17 a refused switch makes in_ctx return {}              -> {42} (exp {})
FAIL: MG17 ... having run nothing at all                        -> {1} (exp {0})
(+ once: MG17 the mode really did change on the VIEWER          -> {single} (exp {}))
```

`test_wave_modes` is on NEITHER baseline list, so by the rules it is mine until proved
otherwise. It is not proved otherwise by a re-run count, so:

**THE A/B (ruling 22's decisive test).** `src/wave_viewer.tcl` swapped between the fixup
(`a4756b45…`) and 876e8f0f (`30f53c79…`) and run **INTERLEAVED, one run each per pair**, so
machine-state drift cannot favour either arm:

| arm | interleaved pairs | earlier blocks | total |
|---|---|---|---|
| **A — the fixup** | **12 / 12 PASS** | 6/6 block: 4 pass 2 FAIL; `-n 3`: 3 pass; 3-suite batch: 1 FAIL; audit: 1 pass | **23 pass, 3 fail** |
| **B — 876e8f0f** | **12 / 12 PASS** | 6/6 block: 6 pass | **18 pass, 0 fail** |

**And the MECHANISM says it cannot be the fixup.** The failing shape is diagnostic, not
generic: `wviewer::enter_ctx` takes its "already there" fast path (`if {$prev eq $wp} {return
{1 {}}}`, `wave_viewer.tcl:1041`) when the CURRENT xschem context already **is** the viewer's.
On that path no title is clobbered, so the retitle spy stays 0, **and the fake `switch_ctx`
the test installs is never reached**, so `in_ctx` runs the script and returns 42 with
`mg17_ran` 1 — precisely the three lines above, all three explained by one precondition:
*which xschem context was current when MG17 started*. That is C-side window state
(`new_schematic switch` under a raised semaphore — landmine 17, and `current_win_path` is
documented as transiently empty during window alloc/teardown). **This fixup contains no
window operation, no context switch and no call into that path**: `plan_plot` and
`plan_replace_clear` are pure dict arithmetic, and `add_trace_ok`'s one changed argument
calls `empty_graph_indices`, also pure. Nothing in the diff can execute during MG17.

**Verdict: an unlisted flake in MG17, not attributable to this change** — 12 interleaved
pairs with no difference, a fully-explained environmental precondition, and zero
reachability. It is **added to the PLAN's FLAKY list** with its exact check names rather
than left for the next item to rediscover. What is NOT claimed: that MG17 is *harmless*.
Something makes the context land on the viewer before that block roughly one run in eight
right after heavy X activity, and that is issue 0173's territory — worth a look by whoever
owns it, on its own ticket, not silently absorbed here.
