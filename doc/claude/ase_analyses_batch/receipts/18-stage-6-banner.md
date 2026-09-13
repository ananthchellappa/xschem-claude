# Stage 6 — the precondition banner, and the netlist a dialog may not produce

**One commit, issue 1435, and the seventh of Stage 6.** The first is **1429**
(⚖ R3's reader seam, `595ab274`); the second **1430** (the writer, the plot
sidecar and reconciliation, `7ea9f1dc`); the third the **1431** co-simulation
golden note (`b6b408fd`); the fourth **1432** (`noise`, `disto` and `sens`'s AC
mode, `873ab265`); the fifth **1433** (checkpointed salvage, `97974b42`); the
sixth **1434** (the four variant mitigations, `be23e3cb`). Stage 5 is **1426**
(`tf`), **1427** (`pz`), **1428** (`sens`, DC only). This one closes **Stage 4's
third user-visible surface**, which Stage 4 deferred by name.

**Floors:** `test_ase_core` 558 → **598** · `test_ase_preflight` 229 → **235** ·
`test_ase_dialogs` display 285 → **300** (headless 37 unmoved) — **sixty-one
new rows.** Core and preflight are in `tests/run_regression.tcl`, so **T1 covers
forty-six of them**; `test_ase_dialogs`' fifteen are on its display arm, which T1
does not run (it runs that file's headless arm only, and says so in its own floor
paragraph).

⚠ **Also filed, not fixed: issue 1436** — two rows of `test_ase_dialogs`' display
arm that were **already red at HEAD `81312742`**, proven by restore. Details
below; neither is a T1 failure.

---

## THE ONE DECISION THE BRIEF ASKED FOR, AND THE MEASUREMENT THAT SETTLES IT

The brief named a contradiction inside `PLAN.md` Stage 4 and asked which half is
stale. **The answer is (b): the banner is a genuinely new widget, the plan's
*"no look debt"* paragraph is wrong, and a `look` debt is owed.** The plan's own
*Files and procs* table — the `.note` precondition banner — is the **live** half,
and it is what shipped, under that name.

> **(b)** the banner is a genuinely new widget → the plan's *"no look debt"*
> paragraph is **wrong**, and a `look` debt is owed.

### The measurement, not a preference

The plan's ground for *"there is no new pixel"* is that everything reaches the
user through `ase::ui::dialog_status` — `$w.status`, the label at grid row 1,
column 1 of the Choose Analyses dialog. Measured on `:99` against that live
dialog, on the `nfet_clean` fixture bench, **2026-09-12**:

```
$w.status  class = Label   -wraplength = 0   -justify left   -anchor w
           grid: -row 1 -column 1 -columnspan 1

  op    ok       baseline      status=<Offered because every build of this
  dc    ok       baseline               simulator has it. Nothing was measured.>
  ac    ok       baseline      (identical on all nine)
  tran  ok       baseline
  noise ok       baseline
  tf    ok       baseline
  pz    ok       baseline
  sens  ok       baseline
  disto ok       baseline
  sp    blocked  unrenderable  status=<ASE-L cannot set up sp yet, so it is
  pss   blocked  unrenderable           listed but cannot be enabled.>
```

**Eleven cells, eleven occupied status lines, zero free.** A precondition sentence
there does not join a capability sentence; it **evicts** one that is equally
true. And:

```
dialog reqwidth                                        = 667 px
$w.status reqwidth, with its own text                  = 539 px
$w.status reqwidth, with ONE 101-char precondition     = 728 px
dialog reqwidth, with that sentence in the status line = 856 px   <-- +28 %
```

because `$w.status` has **`-wraplength 0`**. Two independent facts, each on its
own sufficient.

⚠ **AND THE ROW THAT MEASURES IT FOUND ITS OWN REFINEMENT, WHICH MATTERS TO THE
RULING.** The first cut of `GN1` asserted "occupied on every cell" without
touching the capability cache and **went red**: by that point in
`test_ase_dialogs`' display arm the cache is **warm**, so nine cells answer
`measured` and `ase::analysis_state_msg` returns `{}` for them — the status line
*looks* free. Both states are real. The collision exists in the **cold** one,
which is what a user who has never pressed Detect has, and which is the state
`test_ase_core`'s own ISO1434 pins as the honest one for a suite. **A surface
that shares a widget only sometimes is worse than one that never does**, because
the eviction then depends on whether the user pressed a button in an unrelated
part of the dialog. `GN1` now clears the cache and restores it; `GN1b` adds the
two `unrenderable` cells, which carry a sentence whatever has been measured.

### What the ruling costs

`owed.sh add look ase_precheck_banner_1435` was filed **at the moment the
decision was taken**, before any suite was green, and the deliverable is reported
here as **"suites green, please look"** and not as done. A `look` debt clears
only when the user says so.

---

## The item, and what the constraint actually was

`LEDGER.md` line ~910:

> the **precondition banner under the form** needs netlist *text*, which the
> dialog does not have and can only obtain by calling `ase::netlist` — **a side
> effect no dialog may have because a user opened it**.

⚠ **And `ase::netlist` really is not a read.** Read out of the tree rather than
assumed: it deletes and rewrites `<rundir>/<cell>.spice`; `ase::rundir` with an
empty `rundir` key answers `set_netlist_dir 0`, i.e. `~/.xschem/simulations`, the
one global directory the crew brief's own incident is about; arm (b) does
`xschem load`, replacing the current schematic buffer; arm (c) is
`ase::with_design_current`, which ascends the user's hierarchy, parks
`autosave_backup`, and **refuses outright** for a modified buffer with autosave
off. None of that may happen because a user opened a window.

**The solution is the shape this file already uses twice**, and naming both is
the point — nothing here is new machinery:

| existing | the rule it already states |
|---|---|
| `ase::sim_caps_cached` | *"THE FREE PEEK … IT MUST NEVER START A PROGRAM"*, with `Detect` as the one cold door |
| `ase::op_cards_put` / `_hit` / `_for` | a slot filled as a **by-product of a netlist somebody asked for**, read by whoever needs it afterwards |

⚠ **AND THE FILL SITE IS SINGULAR, WHICH IS WHAT MAKES THE RULE TRUE BY
CONSTRUCTION RATHER THAN BY CONVENTION.** Measured (comments stripped):
`xschem netlist ` appears **exactly once** in `src/ase.tcl` — inside
`ase::netlist_in_place` — and **not at all** in `src/ase_window.tcl`; all four
arms of `ase::netlist` end in that proc, and `ase::op_cards_capture` is already
captured on the line above. One line beside it, and every legitimate producer
(*Simulation > Netlist > Recreate*, *Netlist > Display*, *Netlist and Run*, the
descend round trip) fills the slot while nothing else can. Row **BN10** pins the
count and the adjacency; **BN2** and **GN10** pin the absence from the other end.

---

## What shipped

### `src/ase.tcl` — the schema half (core `ase::`)

| proc | what it answers |
|---|---|
| `ase::facts_clear` | empty the one slot |
| `ase::facts_stamp {path}` | a file's `mtime:size` identity, `{}` when it is not there |
| `ase::facts_design_path {state}` | where the design lives, resolved the way `ase::netlist` resolves it and with none of its side effects |
| `ase::facts_is_current {path}` | is this the schematic the editor is showing |
| `ase::facts_capture {state netlistpath}` | **the priming seam** — one line in `ase::netlist_in_place` |
| `ase::facts_donate {state netlistpath facts}` | the run path hands over the copy it already computed; **an existing slot only** |
| `ase::facts_status {state}` | `cold` / `stale <why>` / `warm`, from two `file stat`s and one `xschem get` |
| `ase::netlist_facts_cached {state}` | **the free peek** — parses once, memoises, `{}` for cold or stale |
| `ase::state_option_map {state}` | the option flattening `analysis_precheck` carried inline; now one body |
| `ase::precheck_banner {sim state type row}` | the banner's structured answer, for the **selected** type, **enabled or not** |
| `ase::precheck_banner_text {banner}` | the rendered lines, **worst first** |
| `ase::preflight_gate` | gains an **optional** third argument, `{netlistpath {}}`, so that the one caller which knows the path can donate |

### `src/ase.tcl` — the content half

**Empty, and that is a finding rather than an omission.** Every precondition
sentence the banner prints was already minted in `ase::needs_eval` by issues
1423/1425/1426/1427/1428/1432/1434, and the registry's `needs` lists were already
complete for all nine renderable types. `ase::backend::ngspice` is **byte
unmoved**: no new hook, no new key, no new verb. This issue mints **three
frames** — the cold sentence and the two stale ones — and nothing else.

⚠ **That is D34–D37 paying out.** The plan budgeted `≈ +60` for this item on the
window side and said nothing about the adapter, and the reason it needed nothing
is that Stage 4 put the sentences where content belongs. A banner is a
**presentation** of facts the schema already owns.

### `src/ase_window.tcl` — the window half

* **`$w.note`** — a `-wraplength 600` label at grid **row 7**, columnspan 2: under
  the form (row 2), above `Options…` (row 8) and the button bar (row 9). **No
  existing widget path moved**; rows 3–7 were free. The row is reserved whether
  or not the label has text, exactly as `$w.status`'s is.
* **`ase::ui::chana_note {key}`** — repaints it, at the end of `chana_show`,
  **after** the form is rebuilt because it reads the form.
* **`ase::ui::chana_form_vals`** and **`ase::ui::chana_merged_row`** — factored
  out of `chana_ok`, which now calls them. The banner judges **what is typed**,
  overlaid on the stored row, which is `chana_ok`'s own stated rule for its
  commit probe.
* **`ase::ui::chana_glyph`** gains a `fatal` arm wearing `blocked`'s mark.
* **`lbl_netlist`**, **`lbl_netlist_recreate`**, **`menu_path_netlist_recreate`**
  — and the Netlist menu is now built from the first two, so the door the banner
  names follows a rename. Invariant I1, the rule the three labels beside it
  already carry.

**No new state key, no `seed_enabled`, `ase::state_default` still seeds exactly
four rows, and the 104 committed `.state` files are byte-identical** — section
**CP** of `test_ase_core.tcl` is the row that would notice. **No deck golden
moved**: the banner emits nothing.

---

## Every measured fact this rests on

All **2026-09-12/13**. Scratch fixtures under `tests/headless/.scratch/` and
`/tmp/vm6banner`; **nothing under `~/.xschem/` was touched and no bench under
`sky130A/` was run**; every xschem invocation was given a path (`./src/xschem`)
and `--nolog`, never `--logdir`, never a bare `xschem`.

### 1. The status line is occupied, and it does not wrap

The table and the four widths at the top of this receipt. Taken on `:99`
(Xvfb 1920x1080x24, **openbox 3.6.1** live — `devdisplay.sh status` before the
run) through `devdisplay.sh exec`.

### 2. ⚠ `ase::netlist_facts` IS LINEAR AND NOT FREE, WHICH DECIDED THE CACHE'S SHAPE

Measured on this box, `time` over 3 iterations:

```
netlist_facts over    200 lines (   3 303 bytes):     893.7 us
netlist_facts over  2 000 lines (  38 704 bytes):   7 486.3 us
netlist_facts over 20 000 lines ( 446 705 bytes):  76 544.3 us
```

⚠ **76.5 ms is too much to pay per radio click and too much to pay on every
netlist.** `chana_show` runs on every cell selection; most netlists are never
followed by anyone opening this dialog; and the **run** path already pays it
inside `ase::preflight_gate`. So the capture stores a path and a stamp, the
**first peek** parses and memoises (row **BN1c**, driven by making the parse
*raise* — a memoised answer never reaches it), and `ase::facts_donate` lets the
run path hand over what it has (rows **BN5**–**BN5c**, **PF233c/d**).

### 3. The banner, end to end, through the product's own gesture

`ase::ui::do_netlist_recreate` — *Simulation > Netlist > Recreate*, the entry the
cold sentence names — on the `nfet_clean` bench, **before any run**:

```
COLD   ASE-L has not netlisted this design yet, so it cannot check this analysis
       against the circuit. Simulation > Netlist > Recreate.
WARM   sources = V1 V2, exact 0
  ac     ⚠ this circuit has no AC source (read from the netlist text, which
           cannot see inside an .include). Fix: put `ac 1` on the input source
           (any magnitude will do)
  disto  ⚠ no source in this circuit carries a `distof1` excitation, and a
           distortion analysis without one runs to completion and answers zeros
           … Fix: add `distof1 <mag> <phase>` to the input source (phase is in
           DEGREES)
  dc     ⚠ this circuit has no 'Vnope' to sweep …    (typed into the form, not
           stored — the banner read the widget)
  noise  ⚠ 'V1' carries no AC value, and a noise analysis is referred to its
           input source's AC magnitude … Fix: put `ac 1` on 'V1' (any magnitude
           will do)
  op tf pz sens tran   <nothing>
STALE  The schematic has changed since the last netlist, so these checks are out
       of date. Simulation > Netlist > Recreate.
```

⚠ **The `noise` line IS the sentence `PLAN.md` Stage 4 asks for**, arriving where
it asks for it. The plan writes it as *"`v1` has no AC value — a noise analysis
needs an AC input source (`ac 1` on the source, any magnitude)"*; the tree's own
wording, minted by issue 1432, says the same thing and adds the mechanism. **No
new precondition sentence was minted to reach the plan's target.**

### 4. The dialog netlists nothing

`ase::netlist` renamed away and replaced with a stub that sets a flag and raises;
then eleven banner evaluations, a peek and a status call (**BN2**), and
separately the **real dialog** opened and all eleven cells clicked (**GN10**):
`bn_netlisted` / `gn_netlisted` = **0** both times. **BN2b** is the non-vacuity
control — the same stub fires when something does netlist.

### 5. The banner costs the dialog no width

```
dialog reqwidth without the banner  = 667 px
dialog reqwidth with it             = 667 px
$w.note reqwidth (2 wrapped lines)  = 590 px, reqheight 55 px
```

which is what `-wraplength 600` is for, and row **GN2** asserts the relation
(`note reqwidth <= dialog reqwidth`) rather than the constant.

### 6. ⚠ THE UNSAVED-EDIT TEST IS ONE-SIDED, AND THE ONE SIDE IS SOUND

`xschem netlist` netlists the **in-memory buffer**, so a netlist taken over
unsaved edits is accurate for them; the question is only whether the buffer has
moved *since*. There is no modification counter to read — `xschem get modified`
is a flag, about the **current** schematic. So the slot records whether the
design was current at capture and what the flag said then:

| at capture | now | verdict | sound? |
|---|---|---|---|
| clean | dirty | **stale** | yes — an edit landed after the netlist |
| clean | clean | warm | yes — a save would have moved the file stamp |
| dirty | dirty | warm | correct to claim nothing |
| dirty | clean | stale **by the file stamp** | yes — they saved |

Rows **BN4f** and **BN4g**. A saved edit is caught by the stamp whatever the flag
says (**BN4b**).

### 7. ⚠ TWO ROWS OF `test_ase_dialogs`' DISPLAY ARM WERE ALREADY RED — ISSUE 1436

Proven by restore, not argued: `src/ase.tcl` and `src/ase_window.tcl` copied back
to HEAD `81312742` from `git show HEAD:…`, the suite re-run, the files restored
with an md5 compare.

```
at HEAD 81312742   2 FAILED (283 passed)   G2sens, GG9
with 1435          2 FAILED (296 passed)   G2sens, GG9   <- the same two
```

* **`G2sens`** expects `$top.chana.form.stop` **not** to exist for `sens`. Issue
  **1432** gave `sens` its AC mode and five more fields — `mode sweep points
  start stop`, every one carrying `depends {mode ac}` — and `chana_show` builds
  every non-advanced field whatever its `depends` says. Measured:
  `ase::analysis_field_names ngspice sens` → `out filters mode sweep points start
  stop`. ⚠ **This is receipt 17's own deferred note, "`depends` has no surface",
  arriving as a red.**
* **`GG9`** expects `ase::analysis_detectable` to be 1 and Detect live; the
  capability cache is warm by then. In a fresh process it is cold and the premise
  holds (`sim_status` resolving through the developer's own
  `~/.xschem/ase_simulators`, `registry entry ngspice-v50`), and under a scratch
  `HOME` a **third** row (`GG3`) reds as well. ⚠ **ISO1434's lesson from the other
  side**: a suite's isolation covers the REGISTRY, and `ase::sim_status` falls
  back to `[auto_execok ngspice]`. Related: issue **1397**.

Both fixes are rulings — whether `chana_show` honours `depends`, and whether
`test_ase_dialogs` gets ISO1434's stub — so they are **filed and not patched to
green**. T1 runs this file's headless arm only (37 checks, **ALL PASS**).

---

## The sabotage table

**Thirty-two respellings**, each a plausible rewrite rather than a break — the
tidy-up somebody would actually make. Restore was `cp` from
`/tmp/vm6banner/sab/good_ase.tcl` and `good_ase_window.tcl` with an md5 compare
after **every** one, and the campaign **aborts** on a restore mismatch rather than
continuing; the log records `RESTORED-OK` for all thirty-two, and for the four
re-runs after them. **Thirty-six applications in all, 36/36 restored, zero
survivors, zero kills.** Anchor uniqueness was checked against the pristine files
**before** the campaign started: 32/32 unique.

⚠ **THE CAMPAIGN OWNED THE WORKING TREE WHILE IT RAN**, and no source file was
edited during it — task 5's own scar, where a restore silently swallowed an edit.
Every measurement outside this table was taken before it started or after it
finished.

⚠ **AND PASS 1'S TABLE WAS RE-TAKEN RATHER THAN PATCHED.** Pass 1 ran thirty
sabotages, produced **five survivors and four suite kills**, and every one of
those nine was a defect in a *row* rather than in the code. The rows were fixed
(`bn_get`, BN1d, BN3d, BN4f/BN4f2/BN4h, BN8c, PF233e/f, GN7b, GN11) and the whole
table re-taken against the corrected tree, so the table below is one campaign
against one tree. **Pass 1's findings are kept** — they are corrections C98 and
the "learned" section's guard paragraph, and three of them are the reason four new
rows exist at all.

⚠ **THE FOUR KILLS ARE REPORTED AS KILLS.** S04, S05, S13 and S20 each aborted
`test_ase_core` at `invalid command name "ag_five"` — 4 000 lines past the
defect — because a bare `dict get … why` on an answer shaped `{state warm …}`
raises, and a raise inside this file's outer catch skips every later section. A
kill is a **weaker** result than a clean red: it proves something changed, and it
names a proc that has nothing to do with the change. All four now redden named
rows.

### The thirty-two, by name

| # | the respelling | rows reddened |
|---|---|---|
| S01 | `facts_capture` stops clearing the slot ("we overwrite it anyway") | core **BN3d** **BN3c** |
| S02 | `facts_stamp` keeps only the mtime, dropping the size | core **BN1d** |
| S03 | a slot taken from another design reads STALE rather than COLD | core **BN3** |
| S04 | `facts_status` stops checking the schematic stamp | core **BN4b** **BN4c** |
| S05 | `facts_status` stops checking the deck stamp | core **BN4d** **BN4e** |
| S06 | the unsaved test fires for a buffer already dirty at capture | core **BN4f2** |
| S07 | the peek answers for a stale slot too ("stale facts beat none") | core **BN4c** |
| S08 | the peek stops memoising and re-parses every time | core **BN1c** |
| S09 | `facts_donate` opens a slot when there is none | core **BN5** · preflight **PF233c** |
| S10 | `facts_donate` stops checking which deck the facts came from | core **BN5b** |
| S11 | `state_option_map` treats a valueless option as OFF | core **BN6** |
| S12 | `analysis_precheck` goes back to its own inline option loop | core **BN6b** |
| S13 | the banner reports only on ENABLED rows, like `analysis_precheck` | core **BN7** **BN7b** **BN7e** **BN8** **BN9** |
| S14 | a cold slot reports CLEAR, so the form says nothing at all | core **BN3c** |
| S15 | the text renders CLEAR as a reassurance sentence | core **BN8b** |
| S16 | findings come out in registry order instead of worst first | core **BN8f** |
| S17 | the fix clause is dropped from the line | core **BN8** |
| S18 | the menu path is spelled out instead of composed | core **BN8c** |
| S19 | one stale sentence for both reasons | core **BN8d** |
| S20 | the capture seam is dropped from `ase::netlist_in_place` | core **BN1** **BN1b** **BN1c** **BN10** · dialogs **GN5** **GN6** **GN7** **GN7c** **GN9** |
| S21 | `preflight_gate` donates for any caller, path or no path | preflight **PF233e** |
| S22 | `chana_glyph` mints a third mark for `fatal` | core **BN8g** |
| S23 | `chana_note` paints the status line, the surface `PLAN.md` named | dialogs **GN4** **GN4b** **GN5** **GN6** **GN7** **GN7c** **GN8** **GN9** · and **GG6**, **G14b** as collateral, which is those rows saying the status line is theirs |
| S24 | `chana_note` netlists when the slot is cold, to be helpful | core **BN10b** · dialogs **GN4** **GN10** |
| S25 | the banner is repainted before the form is rebuilt | dialogs **GN4** **GN5** **GN6** **GN7** **GN8** **GN9** |
| S26 | `chana_merged_row` builds from the form alone | dialogs **GN7b** |
| S27 | `chana_merged_row` judges the stored row, not what is typed | dialogs **GN7** **GN7c** |
| S28 | the banner is gridded at row 3, inside the form's row space | dialogs **GN3** |
| S29 | the banner label loses its wraplength, like the status line | dialogs **GN2** |
| S30 | the Netlist menu goes back to its own literals | dialogs **GN11** |
| S31 | `facts_modified_now` drops its current-schematic guard | core **BN4h** |
| S32 | `facts_status` drops the unsaved arm entirely | core **BN4f** **BN4g2** |

⚠ **`G2sens` AND `GG9` APPEAR UNDER EVERY DIALOGS ROW AND ARE NOT COUNTED.** They
are issue **1436**'s two pre-existing reds and they redden with and without every
sabotage; they are stripped from the table above so a real red is legible.

### ⚠ AND ONE NEW ROW WAS CAUGHT LITTERING BY A ROW TEN ISSUES OLDER

`BN4h` dirties the editor's buffer for real — `xschem align` sets the modify flag,
`xschem load` of the same path clears it — because that is the only way to reach
`ase::facts_modified_now`'s guard. Its first cut reddened **C11**, *"no
`untitled~.sch` was dropped in the repo root (issue 0609)"*: a modified buffer gets
an autosave backup written beside it, and the current schematic at that point in
the suite is the repo root's `untitled.sch`. The row now parks `autosave_backup`
for the three statements in between, the way `ase::with_design_current` parks it,
and restores it on the way out. The stray file was removed. ⚠ **An existing row
caught a new row littering the repo** — which is what those rows are for, and it
is an argument for running the whole file rather than the new section.

---

## What the plan and the tree said that this refuted

The batch's ninety-second through ninety-ninth corrections. (Stage 5 took
C43–C55; issue 1429 C56–C59, 1430 C60–C64, 1432 C65–C71, 1433 C72–C80, 1434
C81–C91.)

### C92 — `PLAN.md` Stage 4's *"there is no new pixel … No look debt is filed"* is wrong, and its own table knew

The whole of the decision above. Two independent measurements — eleven occupied
status lines on a cold cache, and `-wraplength 0` costing 28 % of the dialog's
width for one sentence. ⚠ **And the plan is not merely stale here: it is
self-contradictory in one section**, the `.note` row and the no-pixel paragraph
three paragraphs apart. A crew reading either alone would have been confident and
half of them wrong.

### C93 — and Stage 4's `≈ +60` for `src/ase_window.tcl` bought the wrong half

The plan budgets the banner as a window change. Measured, the window half is a
label, a painter and two factored readers; **the item is the SLOT**, which is
core, which the plan's table does not mention at all, and which is where every
decision in this issue lives. ⚠ **A deferred item's cost estimate is an estimate
of the surface, and the surface is the part that was never the problem.**

### C94 — the content half is EMPTY, and D34–D37 is why

No new adapter hook, no new registry key, no new ngspice word; every sentence the
banner prints was minted in `ase::needs_eval` by seven earlier issues and every
renderable type's `needs` list was already complete. ⚠ **A stage that put the
sentences where content belongs made its own later presentation stage free.** The
inverse is the warning: had Stage 4 spelled those sentences in the dialog, this
issue would have had to move them.

### C95 — the fill site is singular, and that was a measurement rather than a design choice

`xschem netlist ` appears **once** in `src/ase.tcl` and **nowhere** in
`src/ase_window.tcl`, and all four arms of `ase::netlist` end in
`ase::netlist_in_place`. The brief offered four shapes — a cached netlist, a lazy
fetch on a gesture, a fact set carried from the last netlist, a "not yet known"
banner. **The tree collapses them into one**: because there is exactly one
producer, "carried from the last netlist" and "filled by an explicit gesture" are
the *same mechanism*, and *Simulation > Netlist > Recreate* is the gesture,
already in the menu, needing no new button. ⚠ **Count the producers before
designing the cache.**

### C96 — ⚠ `ase::netlist_facts` IS 76.5 ms ON A REAL NETLIST, AND NO DOCUMENT SAYS SO

Every design note in this batch treats `netlist_facts` as a pure function, which
it is, and none of them treats it as a **cost**. At 447 KB it is 76.5 ms with Tk
frozen — acceptable once, unacceptable per radio click, and wasteful on the many
netlists nobody opens a dialog after. That single number decided three things
(lazy parse, memo, donate) and is the reason `ase::facts_capture` stores a path
rather than facts. ⚠ **Measure the pure function before you decide where to call
it.**

### C97 — "the status line is occupied" is TRUE ONLY ON A COLD CACHE, and the row found it

The `GN1` story above. ⚠ **A measurement taken in one process is a measurement of
that process's history.** The first cut measured a fresh dialog and generalised;
the suite runs the same dialog after a capability probe, and nine of eleven
sentences vanish. The ruling survives — a sometimes-shared widget is worse than a
never-shared one — but the *argument* had to be re-taken, and the row now states
which state it is measuring and why that is the state that matters.

### C98 — `ase::facts_clear` inside `ase::facts_capture` looks dead and is not

The final `set` replaces the whole slot, so the clear on the line above reads as
belt-and-braces — and sabotage **S01 survived** its removal. It is reachable
through exactly one door: the `$sch eq {}` early return, where it is the only
thing between a capture that cannot name a design and the **previous** design's
facts still answering. Row **BN3d** was written for it. ⚠ *A row whose fixtures
never disagree cannot fail* — the **eighth** time in this batch, and the second
time it has been a guard that looked redundant rather than a fixture that looked
sufficient.

### C99 — `chana_ok`'s own comment is the specification for the banner, and it was already written

*"THE PROBE ROW IS BUILT FROM `vals`, NOT FROM THE STORED ROW. The whole point of
a commit door is to judge what the user is about to store, and the stored row is
still the PREVIOUS answer at this moment."* The banner sits next to the same
widgets and needed the same rule; it is now one body, `ase::ui::chana_merged_row`,
called by both. ⚠ **Read the comments on the proc you are about to sit beside** —
this is 1434's *"a guard's stand-down list is a map of what the emitter should
have done"* in a second costume.

---

## Suites moved, before → after

| suite | headless | display (`:99`) | in T1? |
|---|---|---|---|
| `test_ase_core` | 558 → **598** | **598** | yes (`run_regression.tcl:75`) |
| `test_ase_preflight` | 229 → **235** | not run | yes (`:29`) |
| `test_ase_dialogs` | 37 → 37 | 285 → **300** | ⚠ **headless arm only** (`:76`) |
| `test_ase_persist` | 44 → 44 | 148 → 148 | yes (`:77`) |
| every other ASE suite | unmoved | — | — |

New sections: **BN** in `test_ase_core.tcl` (40 rows), **PF233** in
`test_ase_preflight.tcl` (6 rows), **GN** in `test_ase_dialogs.tcl` (15 rows, all
inside the display guard). All three floor paragraphs raised in the same change.

⚠ **FORTY-SIX OF THE SIXTY-ONE NEW ROWS ARE IN T1**; the fifteen `GN` rows are
on an arm T1 does not run, and `test_ase_dialogs`' own floor paragraph already
says so in as many words. The **schema** half of every GN claim has a `BN` twin
on purpose — BN2 to GN10, BN8c to GN4, BN1d/BN4* to GN9 — so the contract
survives where the widgets cannot run.

**NO DECK GOLDEN MOVED AND NO `.state` FILE MOVED**, and neither is luck: the
banner emits nothing into a deck and adds no state key. `git ls-files | grep
'\.state$' | wc -l` is **104**; section **CP** of `test_ase_core.tcl` is the row
that would notice a byte.

**NO EXISTING ROW IN ANY SUITE MOVED.** `chana_ok`'s factoring is
behaviour-preserving by construction — the two extracted bodies are its own
lines — and `test_ase_dialogs`' G2*/GG* rows, `test_ase_persist`'s G2p and
`test_ase_interact`'s WF rows are all green and unedited.

---

## Rulings

⚖ **R9 — three new user-facing sentences, and ONE new surface.**

1. **cold** — *"ASE-L has not netlisted this design yet, so it cannot check this
   analysis against the circuit. Simulation > Netlist > Recreate."*
2. **stale, the schematic** — *"The schematic has changed since the last netlist,
   so these checks are out of date. Simulation > Netlist > Recreate."*
3. **stale, the artifact** — *"The netlist has changed since ASE-L read it, so
   these checks are out of date. Simulation > Netlist > Recreate."*

plus the **line shape** for a finding: `<glyph><sentence>. Fix: <fix>`, worst
first, one line per finding.

⚠ **NO PRECONDITION SENTENCE IS NEW.** Every clause the banner prints was minted
in `ase::needs_eval` by issues 1423/1425/1426/1427/1428/1432/1434 and is already
on the user's queue under those numbers. What is new here is the three frames
above and **the fact that the user now reads them before pressing Run instead of
in the log afterwards** — which is the part worth the user's eye.

Recorded as `owed.sh add rule 1435` at the moment it was incurred, pointing at
the issue file. **Batch with 1426, 1427, 1428, 1429, 1430, 1432, 1433 and 1434,
which are all still waiting**, per ⚖ R9 and the standing one-question-at-a-time
preference.

⚖ **AND A `look` DEBT, WHICH IS THE DECISION THE BRIEF ASKED FOR.**
`owed.sh add look ase_precheck_banner_1435` — the `.note` banner is a **new
widget**, `PLAN.md` Stage 4's *"no look debt is filed"* paragraph is the stale
half, and this deliverable is **"suites green, please look"**, not done. A `look`
debt clears only when the user says so.

⚠ **THE LEDGER WAS BACKED UP FIRST**, per `CLAUDE.md`'s one-ledger-every-clone
paragraph, to `/tmp/vm6banner/owed_backup_20260913_001159` (**154 rule / 56 look
/ 9 suite** at the time). Both new entries are stamped
`repo:/home/analog/dev/xschem-claude`; after them the ledger reads **155 / 57 /
9**.

⚠ **AND THE FOUR UNSTAMPED ENTRIES ARE STILL THERE, UNTOUCHED.** Measured
2026-09-13 00:11, before the adds:

```
/usr/bin/grep -L '^repo:' ~/.claude/xschem_owed/{rule,look,suite}/*
  ->  rule/1357   rule/1357@xschem-claude
      look/hier_pdf_nav_1357_H6.1789071932.2875683
      suite/test_hier_pdf_links_1333

/usr/bin/grep -h '^repo:' … | sort | uniq -c   ->  202 xschem-claude / 13 op-wcard
                                (after the two adds: 204 / 13)
```

Identical in kind to what issues 1430, 1432, 1433 and 1434 found. **Nothing has
cleared them and nothing has claimed them.** The two `rule/1357` entries still
point at two different issue files — issue **1400**'s collision, standing in the
ledger itself. ⚠ The op-wcard count has now moved **13 → 13 → 13 → 13 → 13**
across five receipts while this clone's moved **197 → 199 → 200 → 202 → 204**.

---

## What I did NOT ship, and why

* **A per-keystroke refresh.** The banner repaints on every `chana_show` — a
  radio pick, an Advanced toggle, a mode relabel — and reads the form's live
  values when it does, so typing a bad source name and switching cells shows it.
  A refresh *as the characters land* needs a binding on every entry plus a
  debounce, and a wrong sentence flickering under a half-typed name is worse than
  a right one a moment later. It is a surface of its own and it is named here
  rather than half-built.
* **A whole-bench banner.** `ase::preflight_gate`'s advice block (issue 1425) is
  already one, bench-wide, before the run. This one is per-type, before the
  commit. ⚠ **They are complementary and the split is stated in the code**, so
  the next crew does not delete one as a duplicate of the other.
* **Filling the slot from anywhere but a netlist.** No probe, no background
  parse, no "netlist quietly on open", no netlist on a cold banner. That is the
  whole item, and sabotage **S24** — `chana_note` netlisting when the slot is
  cold, *to be helpful* — is exactly the change a later crew will be tempted to
  make. It reddens **BN10b, GN4 and GN10**.
* **Widening `ase::analysis_precheck` to disabled rows.** Its enabled-only rule
  is deliberate and load-bearing for the gate and the grid; the dialog's
  different answer lives in `ase::precheck_banner`, which is a different proc
  with its own stated reason.
* **A `blocked` verdict from a static pass.** `ase::analysis_needs`' demotion
  already turns every `blocked` into a `caution` with the `.include` suffix
  because `netlist_facts` answers `exact 0`. Row **BN7e** asserts the banner
  inherits it rather than re-deriving a stronger claim.
* **`seed_enabled`, anywhere.** Four seeded rows, 104 byte-identical `.state`
  files, section CP unmoved. Seven commits in a row now shipping ⚖ R4's
  recommended answer by construction.
* **Any change to `render_deck`.** No emit, no `.save`, no print anchor, no
  `$sim_status` guard, no `remzerovec`, no plotmap record, no checkpoint block.
  The banner produces text for a label.
* **Issue 1436's two reds.** Diagnosed, filed with the diagnosis, and **not
  patched to green**, because both fixes are rulings — whether `chana_show`
  honours a field's `depends`, and whether `test_ase_dialogs` gets ISO1434's
  capability stub.
* **`signal_list` in `src/wave_viewer.tcl`** — §6g-2's *other* named seam, and
  where the substantial user-visible half of 6g-2 still is. Named by task 5's
  receipt, out of scope here, **still open**, and in a file Stage 6's *Files and
  procs* table does not name.
* **A surface for issue 1434's widening.** The `.save all` leader 1434 emits
  overrides the user's per-output Save ticks and nothing greys or marks those
  ticks while an `own` analysis is enabled. Named by task 5's receipt, **still
  open**, one row for the next window stage.

---

## What this stage learned that binds later ones

**A DEFERRED ITEM'S COST ESTIMATE IS AN ESTIMATE OF THE SURFACE, AND THE SURFACE
IS NEVER THE PART THAT WAS DEFERRED.** `PLAN.md` budgets this item as `≈ +60` in
`src/ase_window.tcl` and says nothing about `src/ase.tcl`. The window half is a
label, a painter and two extracted readers; **every decision in the item is in
the core half the table does not mention.** ⚠ **When a plan defers something for
a stated reason, the reason names the real work — read the deferral, not the
table row.**

**COUNT THE PRODUCERS BEFORE DESIGNING THE CACHE.** The brief offered four
shapes: a cached netlist, a lazy fetch on a gesture, facts carried from the last
netlist, a "not yet known" banner. Because `xschem netlist ` appears **exactly
once** in ASE-L and all four arms of `ase::netlist` end there, three of the four
collapse into one line beside `ase::op_cards_capture`, and *Simulation > Netlist
> Recreate* is the gesture — already in the menu, needing no new button. ⚠ **A
single choke point turns a policy into a construction**, and the grep that finds
it is cheaper than the design that assumes several.

**MEASURE THE PURE FUNCTION BEFORE DECIDING WHERE TO CALL IT.** Every document in
this batch treats `ase::netlist_facts` as a pure pass, which it is, and none as a
**cost**. It is 76.5 ms over 447 KB with Tk frozen. That one number decided the
lazy parse, the memo and the donation. ⚠ **"Pure" says nothing about "free", and
a dialog painter runs on every click.**

**A ROW THAT RAISES IS A WEAKER RESULT THAN A ROW THAT FAILS.** Four sabotages —
S04, S05, S13, S20 — killed `test_ase_core` at `invalid command name "ag_five"`,
4 000 lines past the defect, because a bare `dict get … why` on an answer shaped
`{state warm …}` raises and a raise inside the file's outer catch skips every
section after it. The fix is `bn_get`, a two-line reader. ⚠ **When a proc answers
several shapes, every test that reads an optional key is a potential section
kill** — and the kill names a proc that has nothing to do with the change.

**AND THE GUARD THAT LOOKS REDUNDANT IS THE ONE TO SABOTAGE.** Three of this
campaign's survivors were lines a reviewer would have called defence in depth:
`ase::facts_clear` inside `ase::facts_capture` (reachable through exactly one
early return — **C98**), the size half of `ase::facts_stamp`, and the
`$netlistpath ne {}` half of the gate's donate guard, whose fixture had to be
constructed because `file normalize {}` answers the **empty string** rather than
the cwd. *A row whose fixtures never disagree cannot fail* — the **eighth**,
**ninth** and **tenth** times in this batch, and the pattern has shifted: it used
to be fixtures that could not tell two answers apart, and it is now **guards
whose failure mode needs a state the product cannot reach.** ⚠ **Either build the
state and pin the line, or delete the line — never leave it green and unmeasured.**

**A MEASUREMENT TAKEN IN ONE PROCESS IS A MEASUREMENT OF THAT PROCESS'S
HISTORY.** *"The status line is occupied on every cell"* was taken in a fresh
dialog and is false after a capability probe, where nine of eleven sentences
vanish. The ruling survived; the argument did not. ⚠ **Before generalising a
widget measurement, ask what else the session has done to that widget** — and
write the row so it says which state it is measuring.

**AND THE BEST PLACE TO FIND A NEW PROC'S SPECIFICATION IS THE COMMENT ON THE
PROC IT WILL SIT BESIDE.** `chana_ok` already carried *"THE PROBE ROW IS BUILT
FROM `vals`, NOT FROM THE STORED ROW … the stored row is still the PREVIOUS
answer at this moment"*, which is exactly the banner's rule. It is now one body.
⚠ This is issue 1434's *"a guard's stand-down list is a map of what the emitter
should have done"* in a second costume: **the design you need has often already
been written down as a warning by whoever was there last.**

---

## For the driver

* T1 was **not** run by this crew (issue 0990 — the driver runs it solo).
* **Nothing was committed, added, stashed, restored or cleaned.** No
  `git checkout --`, no `git restore`, no `git stash`, no `git clean`, no
  `git push`, no PR. The working tree is the one handed over plus this issue's
  six modified files and three new ones.
* `NUMBERING.md`'s pointer was advanced **1435 → 1437** in the same change as the
  two entries. Both mint checks were run at the moment of minting: the
  reserved-band scan over this clone's head table (**silent** for both 1435 and
  1436) and `ls ~/dev/*/doc/claude/issues/<n>-*` plus `/usr/bin/grep -lw <n>`
  across **every** clone's `NUMBERING.md` — only this clone's own pointer line.
* ✅ **Two of the three suites this task moves ARE in `tests/run_regression.tcl`.**
  `test_ase_dialogs` is in `hcases`, so T1 runs its **headless** arm (37 checks,
  ALL PASS) and not the display arm where the fifteen `GN` rows live. That is
  stated in the receipt and in the suite's own floor paragraph rather than
  glossed. Issue 1421's twenty-one unreachable `test_ase_*` suites are all
  unmoved.
* ⚠ **NO SIMULATOR WAS NEEDED FOR THE FEATURE, AND THAT IS WORTH KNOWING BEFORE
  THE COMMIT.** The banner is pure Tcl over netlist text: it starts no program,
  emits nothing into a deck, and reads no capability. The crew brief's
  both-binaries rule is therefore discharged by saying so rather than by testing
  twice — but the suites that *do* start a simulator were run anyway (see the
  family below), on this box's default resolution, which is the fork
  (`/home/analog/dev/ngspice/build-ver_50/src/ngspice`, `ngspice-46+`). The two
  binaries named in the brief — that fork and `/usr/bin/ngspice` (`ngspice-45.2`)
  — were both exercised earlier in the batch for everything that emits, and this
  issue emits nothing new.
* **Machine rules honoured throughout**: every xschem invocation was given a path
  (`./src/xschem`) and `--nolog`, never `--logdir`, never a bare `xschem`; no
  bench under `sky130A/` was run; scratch fixtures under
  `tests/headless/.scratch/` and `/tmp/vm6banner` with explicit rundirs; every
  bespoke command carried a `timeout` and every waiting loop a deadline.
* ⚠ **ONE FILE WAS CREATED IN THE REPO ROOT AND REMOVED**, and it is reported
  rather than quietly cleaned: the first cut of row **BN4h** dirtied the editor's
  buffer without parking `autosave_backup`, which dropped a 74-byte
  `untitled~.sch` in the repo root — caught by row **C11** (issue 0609), which
  exists for exactly that. The row now parks the knob; the file was deleted; `git
  status` carries no trace of it.
* ⚠ **`~/.xschem/geometry` WAS WRITTEN AGAIN**, at 00:21:42 and again by the
  display arm. Issue **1397**, already on the user's queue and already reported by
  the 1430, 1432, 1433 and 1434 crews. Every one of this crew's own headless
  invocations carried `--nogui`; the writes come from `run_suites.sh`'s display
  arm and from `devdisplay.sh exec ./src/xschem --pipe`, both of which open a real
  window that saves its size on exit. **Nothing else under `~/.xschem/` was
  touched**, and the repo's own `.xschem/op_param_lists.conf` is unmodified
  (Sep 9).
* ⚠ **THE WHOLE ASE FAMILY (30 suites) WAS RUN HEADLESS**, every run `timeout
  500`-bounded so a stall would be a NAMED outcome: **27 ALL PASS**, **2
  self-skips** (`test_ase_dirty`, `test_ase_log_seam_0207`, each of which says in
  its own first line that it needs an X connection) and **1 known red** —
  `test_cosim_golden_e2e` **45 passed / 1 failed**, row **GE24**, issue **1431**,
  a one-timestep VCD boundary, unchanged and not in T1. `test_ase_final` is **ALL
  PASS (82)** and `test_ase_optier_0963` **ALL PASS (108)** — the latter did not
  flap this time (issue 1402).
* ⚠ **THE DISPLAY ARM: 3/4 runs passed, AND THE ONE FAIL IS ISSUE 1436's TWO
  PRE-EXISTING ROWS.** Taken through `tests/headless/run_suites.sh`, which
  reported *"display arm: ATTACHED to persistent dev display :99 (devdisplay.sh),
  GUI_GATE=0"* — `devdisplay.sh status` before and after: alive, **openbox
  (Openbox 3.6.1)**, `1920x1080x24`.

  | suite | headless | display (`:99`) |
  |---|---|---|
  | `test_ase_core` | **598** | **598** |
  | `test_ase_preflight` | **235** | **235** |
  | `test_ase_dialogs` | **37** | **300** (298 pass + 1436's two) |
  | `test_ase_persist` | **44** | **148** |

  ⚠ **Core's two arms are identical**, which is this suite's own stated contract
  (*"RUNS IN BOTH ARMS, with the same VERDICT"*), and section BN keeps it: BN4h's
  `xschem align` + reload works the same with and without a window, and every
  other BN row is pure Tcl over a file.

### The resume point, for `LEDGER.md`

**Stage 6 is complete.** §6a–§6g landed in tasks 1–5 (issues 1429, 1430, 1431,
1432, 1433, 1434); **Stage 4's deferred banner is this task** (1435); Stage 4's
other deferred item, the DISTO save-list rule, was discharged by 1432/1434. The
two follow-ups task 5 named are **still open and belong to the stages that own
those files**: `signal_list` in `src/wave_viewer.tcl` (§6g-2's other seam) and a
surface for 1434's widening. Issue **1436** is filed and open. **Stage 7 — the
options surface — is next.**
