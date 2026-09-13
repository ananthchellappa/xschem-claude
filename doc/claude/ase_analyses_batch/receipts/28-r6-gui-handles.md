# ⚖ R6 — the GUI half: the handle is visible, and the second row of a type is reachable (issue 1448)

**One task, the GUI half of ⚖ R6 and of issue 1444.** `src/ase_window.tcl` +
`tests/headless/test_ase_dialogs.tcl`, plus the 1448 issue file, the 1444
append and `NUMBERING.md`. **`src/ase.tcl`, `test_ase_core.tcl`,
`test_ase_persist.tcl`, `test_ase_meas_1443.tcl` and `run_regression.tcl` were
NOT opened for writing** — `src/ase.tcl` was read only. No commit, no `git add`,
no stash, no restore.

**Floor: `test_ase_dialogs` 37 / 322 → 37 / 340.** The file's own floor
paragraph and header index are in the same diff.

| arm | before | after |
|---|---|---|
| headless (`timeout 400 ./src/xschem --nogui --pipe -q --nolog`) | `RESULT: ALL PASS (37 checks)` | `RESULT: ALL PASS (37 checks)` |
| display (`timeout 600 devdisplay.sh exec ./src/xschem --pipe -q --nolog`) | `RESULT: 1 FAILED (321 passed)` | `RESULT: 1 FAILED (339 passed)` |

Both baselines were **re-measured here** before any edit and both matched the
dispatch exactly, including the red's actual value. **The one red is `G2sens`,
issue 1436**, `{1 1 0 1 0 Entry Entry normal}` — the value that issue's own file
records — before and after. **`GG9` passed on every run of both arms today**, as
the file's own paragraph predicts (its premise needs a cold capability cache), so
the "TWO standing reds" sentence in that paragraph is a timestamp; the diff says
so in place rather than editing the mechanism out.

`src/ase_window.tcl` **9547 → 9872** (+356 / −31; **176** added lines are not
comment). `tests/headless/test_ase_dialogs.tcl` **3861 → 4367** (+522 / −16).

---

## 1. What changed, with anchors

### `src/ase_window.tcl`

| anchor | change |
|---|---|
| `:892` | the menubar gains `Analyses > List` |
| `:1462` | `pane_dblclick` passes the **index** it used to throw away |
| `:4515` | `edit_analysis_first` passes it too; its header's *"addresses the first row of that type"* paragraph rewritten |
| `:4649` | **`ase::ui::chana_row_idx {key type}`** — the one reader of the addressing |
| `:4669` | `chana_row` is now `lindex $rows [chana_row_idx]`, or a stub |
| `:4694` | **`ase::ui::chana_cache_key {key type}`** — the handle, or `*<type>` |
| `:4767` | `chana_detect` carries the addressed row across its destroy-and-reopen |
| `:4813` | `choose_analyses {key {type {}} {idx {}}}` — an index outranks the type and the type is **re-derived from the row**, never trusted |
| `:4942`, `:4956` | the **handle grid**: `ttk::treeview $w.rows`, columns `handle type enable args`, `<<TreeviewSelect>>` → `chana_rows_pick`, gridded at row 1 |
| `:5302` | `chana_cache_save` files under **`anshownkey`**, the standing form's key |
| `:5346` | **`ase::ui::chana_rows_fill`** |
| `:5380` | **`ase::ui::chana_rows_pick`** — idempotent, which is what stops the fill re-entering it |
| `:5442` | `chana_show` grids `$w.form` at row **3** (was 2) |
| `:5452`, `:5462` | `anshownkey` snapshotted at build; `chana_cache_apply` takes a cache key, not a type |
| `:5555` | `chana_show` ends by repainting the grid's selection |
| `:5757`, `:5968` | `chana_ok` and `chana_x_ok`: the first-of-type walk replaced by `chana_row_idx` |
| `:6023`–`:6071` | `analyses_list_body` / `_fill` / `analyses_list` — the `Analyses > List` viewer |
| `:7722`, `:7728` | `lbl_list`, `lbl_no_analyses` |

**State:** `dlg($key,anrow,<type>)` and `dlg($key,anshownkey)`, both array slots
on the existing `ase::ui::dlg`, both cleared by `chana_cache_clear` (and so by
`choose_analyses`, `chana_cancel` and `ase::ui::close`). **No new state key, no
schema change, nothing serialised.**

### `tests/headless/test_ase_dialogs.tcl`

Section **GH**, `:3883`–`:4328`, **18 rows** — GH1 GH2 GH3 GH4 GH4b GH4c GH5 GH6
GH7 GH8 GH9 GH10 GH11 GH12 GH13 GH13b GH14 GH15 — plus the header index, the
floor paragraph, `GN3`'s grid-row expectation, and **thirteen `anedit,tran` →
`anedit,tran1`** reads in ⚖ R5's and 1446's own rows (§4).

---

## 2. ⚠ THE CORRECTION THAT MATTERS: "a handle COLUMN in the Choose Analyses GRID" COULD NOT BE BUILT AS WRITTEN

The brief, issue 1444 and `DECISIONS.md` all say *"a handle column in the Choose
Analyses grid ... beside the row it names"*. **The cells in that dialog are
TYPES, not analyses** — `$w.types.<type>`, eleven of them for ngspice, four per
row, built from `ase::analysis_states`. A type with two rows has two handles and
a type with none has none, so a handle cannot be a column of *that* grid without
inventing a rule for both cases.

What is built is **the grid the handle IS a column of**: a `ttk::treeview` with
one line per analysis row of the bench.

```
Handle  Type  Enable  Arguments
op1     OP      ☑
dc1     DC      ☑     V2 0 1.8 0.01
ac1     AC      ☐     dec 10 1 10meg
tran1   TRAN    ☐     1n 10u
dc2     DC      ☐     TEMP -40 125 5
```

Three things follow, and each is why this is the right shape rather than a
workaround:

* **Every column is `ase::analysis_handle_fields`'s answer, rendered.** Nothing
  assembles a handle, an uppercase type or an argument summary. `Type`, `Enable`
  and `Arguments` are the **Analyses pane's own heading words**, reused verbatim,
  so only `Handle` is new copy.
* **It carries the row addressing.** Picking a line is how `dc2` is edited, which
  is the load-bearing half of the task; one widget, not two.
* **The main window's Analyses pane was NOT given a column**, deliberately.
  `tests/headless/test_ase_window.tcl:1771` asserts that pane's `-columns` list
  by value and that file is not this task's. Recorded so nobody reads the absence
  as an oversight.

**What moved:** `$w.rows` took grid row 1, so `$w.enable`/`$w.status` went to 2
and `$w.form` to 3. **No widget path moved** — issue 1405's lesson is about paths
(`$w.<field>` → `$w.form.<field>`, 100 checks), and these are the same widgets in
the same frame one row lower. `$w.note` (7), `$w.opts`/`$w.detect` (8) and the
button bar (9) are untouched. `GN3` asserts all of it, including the new row.

---

## 3. WHAT I DECIDED ABOUT THE CACHE UNDER ROW ADDRESSING, AND WHY

**The brief's honest answer is the right one: the cache must be keyed by handle,
not by type.** It is, and `GH6` is the measurement.

⚖ R5 keyed `dlg($key,anedit,<type>)` by type because a type was the only identity
a row had. Under addressing that is a leak with a straight face: type `9.9` into
`dc1`, click `dc2`, and a type-keyed cache overlays `dc1`'s edit on `dc2`'s form —
the user is looking at a **temperature sweep wearing a voltage sweep's numbers**,
and OK writes them. `GH6` drives exactly that sequence and asks for `dc2`'s own
stored `125`, with the two stored values proven different as its control.

**The key is `ase::analysis_handle`'s word**, never assembled here, so the array
slot and the grid line and the calculator expression are one string.
`*<type>` covers a type with **no** row: no handle can begin with `*`
(`ase::analysis_id_ok` requires a bare identifier, a derived handle is
`<type><n>`), and a type with no row has exactly one fresh form because OK on it
appends.

**⚠ And the key is SNAPSHOTTED, not recomputed — this is the subtle half.**
`chana_cache_save` runs at the top of `chana_show`, and picking a line sets the
addressing **and then** rebuilds. A save that computed the key at save time would
file `dc1`'s typing under `dc2`. `dlg($key,anshownkey)` is taken when the form is
built, for exactly the reason ⚖ R5 took `anshown` rather than reading `antype`
(Tk sets a radiobutton's `-variable` before it runs `-command`) — one level down.
Sabotage **s8** is that mistake and reds `GH6`.

**The cost, stated rather than hidden:** thirteen reads in ⚖ R5's and 1446's rows
now spell the slot `anedit,tran1`. The GR5 section carries a paragraph saying why
that is the feature and not a typo, and sabotage **s5** (key by type again) reds
**six of those rows plus GH6** — which is the statement that the change did not
quietly disable the older section's assertions.

**What did NOT change: one OK still writes one row.** `chana_commit_vals` reads
one cache and `chana_ok` writes one row; `GR6e` (the D4 guard, not mine) is green
throughout and sabotage **s9** — the commit reading the *type's* cache — reds four
1446 rows plus GH7.

---

## 4. ⚠ THE FINDING: ⚖ R6's OWN KEY STOPS A BENCH RUNNING

**`ase::analysis_emit_check` has never heard of `id`.** Its `known` list is
`{type enabled x}` plus the declared field names (`src/ase.tcl:4615`), and issue
1447 added `id` to the **row** without adding it there. `ase::preflight_gate`
(`src/ase.tcl:12024`) runs that check over every **enabled** stored analysis row
before a run:

```
$ ./src/xschem --nogui --pipe -q --nolog --script /tmp/gh1448/probe4.tcl
ARGSUM: dc V2 0 1.8 0.01
EMIT:   {unknownkey id {has a setting named 'id' that ASE-L cannot emit}}
GATE:   emit_incomplete / 2
GATE-NOID:
```

**A user who names an analysis and switches it on cannot run the bench** — no
deck, no raw, no log, and the message says `set ase_preflight 0` does not disable
it. The surface this task ships is the one that invites them to name it.

**`src/ase.tcl` is not this task's file.** The fix is one word:
`set known [list type enabled x id]`. Row **GH13b** pins all three measurements
with the identical id-less bench as its paired control, so **the fix reddens the
row** and the row names the paragraph to rewrite. Issue 1448 and the 1444 append
both carry it; the **editable `id` field** (1444's fourth surface) is blocked
behind it and is deliberately not in this change.

⚠ **The Choose Analyses commit door is NOT the exposure, and that was measured
rather than assumed.** `chana_ok`'s D6 probe is built from `vals` — the form's
**declared fields** — so a row key the form knows nothing about never reaches the
check. **GH13 was first written expecting a refusal; the dialog disagreed and the
dialog was right.** The row now states what actually happens, and sabotage
**s16** (the probe carrying the addressed row's `id`) reds it alone.

---

## 5. The `.state` byte-identity measurement

```
$ git ls-files -- '*.state' | wc -l
104
$ timeout 300 ./src/xschem --nogui --pipe -q --nolog --script /tmp/gh1448/state_roundtrip_1448.tcl
STATEFILES: 104
MISMATCH:   0
ANALYSIS-ROWS-WITH-id: 0
$ git status --porcelain -- '*.state'
?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/tb_bandgap.state
```

— untracked, pre-existing at session start, not mine. **Zero tracked `.state`
files modified.**

**And the question from the GUI side, which is the one this change could break:**
row **GH15** clicks **every line of the handle grid** and **every cell of the type
grid** and presses OK, and asks for the same bytes. ⚠ OK is pressed on **`ac`**,
never on `op` — trap 1 in the dispatch, and GR6f's measured correction to GR5k:
`op` has no fields, so `chana_ok` writes nothing whatever the reader answers and
such a row cannot fail. Sabotage **s15** (the commit no longer filtered through
`ase::ui::form_is_absent`) reds GH15 **and eleven rows in four earlier sections**.

---

## 6. Sabotage — sixteen mutations, generator at `/tmp/gh1448/sab.py`

Every arm: `python3 sab.py <id>` writes the mutant from a pristine copy → run the
display arm under `timeout 500` → `sab.py restore` → md5 compare against
**both** pristine files, printed on mismatch. **No mismatch was printed on any of
the seventeen arms.** Final state:

```
a0efa596fe38c6c4d558325e0494ed7a  src/ase_window.tcl
69b9e2da8fa35881225cc3ca688f2fb2  tests/headless/test_ase_dialogs.tcl
```

| # | what I broke | `RESULT:` | rows that reddened (beyond the standing `G2sens`) |
|---|---|---|---|
| **s1** | the handle column shows the **index** | `4 FAILED (336)` | GH1 GH2 GH11 |
| **s2** | `chana_row_idx` ignores the addressing — *"`chana_row` still returning the first row of a type"* | `8 FAILED (332)` | **GH3 GH4 GH4b GH4c GH5 GH6 GH7** |
| **s3** | `Analyses > List` omits the disabled rows (1444 taken literally) | `3 FAILED (337)` | GH8 GH11 |
| **s4** | a **second speller** minted locally in the fill | `2 FAILED (338)` | **GH11 — and nothing else** |
| **s5** | the edit cache keyed by **type** again | `8 FAILED (332)` | GH6 + **GR5f GR5h GR5i GR6c GR6e GR6g** |
| **s6** | `chana_ok` walks to the first row of the type again | `3 FAILED (337)` | GH5 GH7 |
| **s7** | the fill never syncs the selection to the form | `3 FAILED (337)` | GH4 GH4b |
| **s8** | the save keys off the **live** key, not the standing form's | `2 FAILED (338)` | GH6 |
| **s9** | the commit reader takes the **type's** cache | `6 FAILED (334)` | GH7 + **GR6a GR6b GR6c GR6h** |
| **s10** | **CONTROL** — GH11's fixture loses its declared `id` | `3 FAILED (337)` | GH11 GH12 |
| **s11** | **CONTROL** — GH13b's paired control keeps the `id` | `2 FAILED (338)` | **GH13b** |
| **s12** | the `Analyses > List` menu entry never added | `3 FAILED (337)` | GH9 GH10 |
| **s13** | the fill leaves the list window **editable** | `2 FAILED (338)` | GH10 |
| **s13a** | the **creation-time** `-state disabled` flipped | `1 FAILED (339)` | **none — see below** |
| **s14** | an empty bench opens a blank window | `2 FAILED (338)` | GH14 |
| **s15** | the commit no longer filtered through `form_is_absent` | `12 FAILED (328)` | GH15 + **G2c G2g G2h G2pz×2 G2sens×2 GR6b GR6c GR6f** |
| **s16** | the D6 probe carries the addressed row's `id` | `2 FAILED (338)` | **GH13 — and nothing else** |

**Every GH row has at least one witness**: GH1 s1 · GH2 s1 · GH3 s2 · GH4 s2/s7 ·
GH4b s2/s7 · GH4c s2 · GH5 s2/s6 · GH6 s2/s5/s8 · GH7 s2/s6/s9 · GH8 s3 ·
GH9 s12 · GH10 s12/s13 · GH11 s1/s3/s4/s10 · GH12 s10 · GH13 s16 · GH13b s11 ·
GH14 s14 · GH15 s15. **Four sabotages redden rows in sections this change did not
write** (s5, s9, s15 and, through GN3, the layout) — a feature whose only
witnesses are its own new rows is a feature nothing else in the tree is watching.

**⚠ s13a is a finding, not a failed sabotage.** Flipping the text widget's
**creation-time** `-state` reds nothing, because `analyses_list_fill` ends every
fill with `configure -state disabled`. The creation option is therefore
decorative; what makes the window read-only is the fill, and that is what `GH10`
measures (s13 reds it). Recorded rather than "fixed" — deleting the redundant
option would leave a window editable for the instant before its first fill.

### The four ways a row fails to fail, answered

1. **Fixtures that never disagree.** The bench's two `dc` rows are `V2 0 1.8 0.01`
   and `TEMP -40 125 5` — the user's own example — and **GH3, GH5, GH6 and GH15
   each carry a term proving the two differ**. GH11's fixture goes further: its
   first `dc` row declares `id vinsweep`, which is the **only** fixture in this
   file where a locally minted `<type><n>` would *disagree* with the real answer
   instead of accidentally matching it. s4 and s10 are the two halves of that.
2. **Position asked where the mechanism is last-writer-wins.** Inverted
   deliberately: GH5 asks for **every other row of the bench back byte for byte**
   (`lreplace` on both sides), and GH15 asks for the whole serialization. Nothing
   here asserts an ordering a last-writer-wins mechanism could satisfy by
   accident.
3. **An extractor that returns nothing.** GH1 counts the items *and* prints them;
   GH2 compares the rendering to the proc **and** to a literal golden (the W1t
   discipline); GH7's first two terms prove the advanced widget was on screen and
   then gone; GH8's third term proves the text equals the proc's answer and its
   fourth reads a named field out of a named line; GH9/GH10/GH14 answer `ABSENT`
   rather than raising when the window is missing.
4. **A sabotage missing from the generator.** s10 and s11 sabotage **controls**
   (GH11's discriminating fixture, GH13b's paired control) and each reds the row
   it controls. s13a is the one that reddened nothing and became §6's finding.

⚠ **GH9, GH10 and GH14 were hardened BECAUSE of s12.** As first written they read
`$top.anlist.t` unguarded, and the missing menu entry made that an
`invalid command name` that **killed the file at 94 checks** instead of reddening
a row — G2tf's documented failure shape, met again by a third route. Every read
of that window is now guarded and answers `ABSENT`.

---

## 7. The other suites

`src/ase_window.tcl` is the whole GUI, so every ASE suite was re-run on **both**
arms, each under a hard timeout:

| suite | headless | display |
|---|---|---|
| `test_ase_window` | `ALL PASS (56)` | `ALL PASS (295)` |
| `test_ase_launch` | `ALL PASS (28)` | `ALL PASS (44)` |
| `test_ase_interact` | `ALL PASS (10)` | `ALL PASS (64)` |
| `test_ase_optsheet_1441` | `ALL PASS (62)` | `ALL PASS (87)` |
| `test_ase_simcaps_0948` | `ALL PASS (199)` | `ALL PASS (199)` |
| `test_ase_core` | `ALL PASS (622)` | `ALL PASS (622)` |
| `test_ase_persist` | `ALL PASS (49)` | `ALL PASS (153)` |
| `test_ase_meas_1443` | `ALL PASS (100)` | `ALL PASS (100)` |

Every number matches receipt 27's and receipt 24's recorded floors.
`test_ase_window` and `test_ase_launch` were not in either receipt and are
measured here because this change touches the menubar and the dialog's layout.

**The stock-binary rule does not apply, and this says so instead of testing
twice.** Nothing added here starts a simulator, reads a binary or touches the
capability cache: the grid renders `ase::analysis_handle_fields`, which reaches
`ase::analysis_line`, which expands a template the adapter declares as Tcl. No
`exec`, no `auto_execok`, no probe. Both arms are green, so the answer is the
same on every binary by construction.

---

## 8. New user-facing copy — FOUR strings, all ⚖ R9's

`owed.sh add rule 1448` filed (ledger 164 → **165** rule). Verbatim, for the
review:

| # | string | where |
|---|---|---|
| 1 | `Handle` | the first column heading of the handle grid in Choose Analyses. ⚠ The alternative considered was `Name`; `Handle` is what **R9-377**'s own *Where* text already calls this column, so the minted word follows the material the user is reviewing rather than competing with it |
| 2 | `List` | the second entry of the `Analyses` menu, beside `Choose…` |
| 3 | `Analyses — <cell>` | the `wm title` of the list window. **Composed**, not typed: `[ase::ui::lbl_analyses] — [ase::ui::design_cell_name $key]`, the same shape as the log window's `Simulation Log — <cell>` |
| 4 | `No analyses on this bench.` | the body of `Analyses > List` for a bench with no analysis rows |

**Consumed unchanged, not re-minted:** **R9-373**, **R9-374**, **R9-375** (the
three refusal sentences), **R9-376** (`(off)`, rendered by
`ase::analysis_handle_text` and shown verbatim) and **R9-377** (the handle
spelling itself, rendered in the grid's Handle column and in the List's first
column). The `Type`, `Enable` and `Arguments` headings are the **Analyses pane's
own words**, reused byte for byte. Measured over the diff: the only new string
literals outside comments are `{List}`, `{No analyses on this bench.}`, the
composed window title, and `"*$type"` — an internal array key that is never
shown. The four column headings are bare words in the grid's own build list,
three of them copied from `ase::ui::build_pane`'s `ana` call.

---

## 9. Debts

* **`owed.sh add rule 1448`** — the four strings above. Filed, stamped
  `repo:/home/analog/dev/xschem-claude`.
* **`owed.sh add look choose_analyses_handle_grid_1448`** — **suites green on both
  arms, please look.** A new `ttk` grid inside a dialog and a new toplevel are
  pixels, and a green suite is not a pair of eyes. This is the first change in
  this batch that draws any (receipts 24 and 25 both correctly filed none).
  Ledger 59 → **60** look.
* **`owed.sh add suite test_ase_dialogs`** — filed (it reported *updated*, so one
  was already standing). CLAUDE.md asks for one `:0` run before a GUI feature is
  called done, and unlike ⚖ R5's and 1446's changes this one has new widgets.
  **Not drained** — a drain runs with the gate live and pops the user's panel;
  that is the driver's batching call.
* **⚠ THE SAME FOUR UNSTAMPED LEDGER ENTRIES receipt 27 FOUND ARE STILL THERE AND
  ARE STILL NOT MINE.** Measured 2026-09-13 10:11 before my first `add`:
  `/usr/bin/grep -L '^repo:' ~/.claude/xschem_owed/{rule,look,suite}/*` printed
  `rule/1357`, `rule/1357@xschem-claude`,
  `look/hier_pdf_nav_1357_H6.1789071932.2875683`,
  `suite/test_hier_pdf_links_1333` — the identical four, unchanged since
  2026-09-10. The rest split **216 this clone / 13 op-wcard**. I touched none of
  them; a full backup was taken first at `/tmp/gh1448/owed_backup_101155`.

---

## 10. Corrections to the brief

1. ⚠ **"A handle column in the Choose Analyses grid" names a grid of TYPES, not of
   analyses** — §2. The column exists, in a new grid of analysis rows, and the
   brief's sentence *"beside the row it names"* is what that grid delivers. The
   main window's Analyses pane deliberately did **not** get one: its `-columns`
   list is asserted by value in `test_ase_window.tcl:1771`, which is not this
   task's file.
2. ⚠ **The dispatch's read of the `id` key's exposure was one door out.** It
   warned about the dialog; the dialog is fine (`chana_ok`'s probe is built from
   the form's fields). **`ase::preflight_gate` is where it bites, and it stops the
   whole bench running** — §4. This is a defect in the half that shipped before
   this one, and the one-word fix is in a file this task may not touch.
3. **The brief's baseline is exact**, both arms and the red's actual value,
   measured before any edit.
4. **Trap 1 was real and it was avoided by construction**: GH15 presses OK on
   `ac`, never on `op`, and says why in place. **Trap 2 was also real**: GH13
   captures `dlg($key,anen)` **before** pressing OK, and GH9/GH10/GH14 guard every
   read of a window that a sabotage can remove — measured on s12, which killed the
   file at 94 checks until they did.
5. **The minimum sabotage list of four was four short in the same way receipts 24
   and 25 found theirs to be.** The four named leave the cache's *key snapshot*
   (s8), the commit reader's key (s9), the selection sync (s7), the menu entry
   (s12), the fill's read-only discipline (s13), the empty-bench sentence (s14),
   the write-back filter (s15) and the D6 probe (s16) unwitnessed.
6. **⚠ `test_ase_dialogs` has ONE standing red today, not two.** `GG9` passed on
   every run of both arms, exactly as the file's own paragraph predicts. Said in
   the file as well as here.

---

## 11. For the driver

* **`NUMBERING.md`'s pointer advanced 1448 → 1449.** Both mint checks were run at
  the moment of minting: the reserved-band scan over this clone's head table
  (**silent** for 1448) and `ls ~/dev/*/doc/claude/issues/1448-*` plus
  `/usr/bin/grep -lw 1448` across every clone's `NUMBERING.md` (only this clone's
  own pointer line).
* **T1 was NOT run by this crew** (issue 0990 — it is yours and runs solo).
  `run_regression.tcl` runs `test_ase_dialogs` on **neither** arm, so T1's number
  does not move and does not exercise one row of this change. The eight suites in
  §7 are what covers it.
* **HEAD did not move under this task.** Handed over at `4a3e1a25`; still there.
* **Nothing was committed, added, stashed, restored, cleaned or pushed.** Working
  tree: **four modified** (`src/ase_window.tcl`,
  `tests/headless/test_ase_dialogs.tcl`, `doc/claude/issues/NUMBERING.md`,
  `doc/claude/issues/1444-…md`) and **two new** (the 1448 issue file, this
  receipt). The four untracked paths inherited at hand-over are untouched.
* **The one thing worth carrying forward.** `src/ase.tcl:4615` —
  `set known [list type enabled x]` — is one word away from letting a user name an
  analysis and still run their bench. Until it lands, **1444's editable `id`
  field must not be built**, and `GH13b` is the row that will tell you the moment
  it does.

---

## 12. Commands, for the driver to re-run

```sh
cd /home/analog/dev/xschem-claude
timeout 400 ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_dialogs.tcl
timeout 600 tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_dialogs.tcl
timeout 300 ./src/xschem --nogui --pipe -q --nolog --script /tmp/gh1448/state_roundtrip_1448.tcl
/tmp/gh1448/runsab.sh s1 s2 s3 s4 s5 s6 s7 s8 s9 s10 s11 s12 s13 s13a s14 s15 s16
```
