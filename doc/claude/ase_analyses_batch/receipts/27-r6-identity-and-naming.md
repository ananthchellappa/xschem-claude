# ⚖ R6 — analysis identity, and the one spelling of it (issue 1447)

**One task, the SCHEMA half of ⚖ R6 and of issue 1444.** `src/ase.tcl` +
`tests/headless/test_ase_core.tcl` + `tests/headless/test_ase_persist.tcl`.
**`src/ase_window.tcl` and `tests/headless/test_ase_dialogs.tcl` were NOT opened
for writing** — read only through `git show HEAD:<path>`. **No widget was built.**

**Floors: `test_ase_core` 602 → 622, `test_ase_persist` 44 → 49 / 148 → 153.**
Both files' own `AND RAISED` paragraphs are in the same diff.

| | before | after |
|---|---|---|
| `test_ase_core` headless | `ALL PASS (602 checks)` | `ALL PASS (622 checks)` |
| `test_ase_core` display (`:99`, Xvfb + openbox) | `ALL PASS (602 checks)` | `ALL PASS (622 checks)` |
| `test_ase_persist` headless | `ALL PASS (44 checks)` | `ALL PASS (49 checks)` |
| `test_ase_persist` display | `ALL PASS (148 checks)` | `ALL PASS (153 checks)` |
| `test_ase_meas_1443` both arms | `ALL PASS (100 checks)` | `ALL PASS (100 checks)` — unmoved |

Both baselines were re-measured here rather than taken from the dispatch, and all
three matched the driver's numbers.

`src/ase.tcl` **22978 → 23271** (+293). Eight new core procs, one arm on
`ase::meas_binding`, three clauses on `ase::meas_verdict`. **No schema version
bump, no new top-level key, nothing added to `ase::omit_if_empty`.**

---

## THE MEASUREMENT THE RULING RESTS ON

```
$ ./src/xschem --nogui --pipe -q --nolog --script /tmp/r6_roundtrip.tcl
STATEFILES: 104
MISMATCH:   0
ANALYSIS-ROWS-WITH-id: 0
```

The script walks `git ls-files -- '*.state'`, reads each file's bytes, runs
`ase::state_load` then `ase::state_serialize`, and compares `"<serialized>\n"`
against the original. **Identical before the change and after it.** It is now a
suite row rather than a scratch script — **`CP7`** in `test_ase_core.tcl:6776`,
reusing the CP section's own `$CPF` file list, with **`CP7c`** at `:6797` as its
control: one committed file with one `id` added to one analysis row must stop
round-tripping, or the comparison is measuring nothing.

`id` is never written on a round trip because **nothing writes it**. It is a
per-ROW key on an open dict, so the serializer writes the rows it was handed and a
row nobody gave an `id` has none. That is a different mechanism from `sim_entry`
and `measurements`, which are top-level keys protected by `ase::omit_if_empty` —
and it is why `R8a`/`R8d` in `test_ase_persist` exist rather than a new
`omit_if_empty` member: **a key that is never written cannot need omitting.**

---

## WHAT CHANGED, WITH ANCHORS

### `src/ase.tcl`

| anchor | what |
|---|---|
| `:6854` | `ase::meas_binding` — the `id` arm. A measurement row's `id` names an analysis handle and **outranks** the `row` index. |
| `:6980` | `ase::meas_verdict` — three clauses, so a handle that did not bind says **which** of three things went wrong. |
| `:9144` | the section header: `id` is a per-ROW key, absent on every committed file, and is **not** the committed output row called `id`. |
| `:9173` | `ase::analysis_id {row}` |
| `:9179` | `ase::analysis_id_ok {id}` |
| `:9213` | **`ase::analysis_handles {state}` — THE ONE SPELLER** |
| `:9248` | `ase::analysis_handle {state idx}` |
| `:9265` | `ase::analysis_by_handle {state handle}` → `{type idx}` |
| `:9287` | `ase::analysis_handle_faults {state}` → `{idx illegal\|duplicate spelling}` |
| `:9333` | `ase::analysis_handle_fields {sim state idx}` → `{handle … type … args … enabled …}` |
| `:9364` | `ase::analysis_handle_text {sim state}` — the copy-pasteable block |

**The scheme:** a row's handle is its `id` if it declares one, and `<type><n>`
otherwise, `n` counting 1 from the top among rows of the same type.

```
op1    OP
dc1    DC    V2 0 1.8 0.01
ac1    AC    dec 10 1 10meg
dc2    DC    TEMP -40 125 5  (off)
tran1  TRAN  1n 10u
```

### `tests/headless/test_ase_core.tcl` (+410 / −0)

`CP7` `:6776`, `CP7c` `:6797`, then section **HN** `:6840`–`:7145`: HN1 HN2 HN3
HN4 HN5 HN5c HN6 HN7 HN8 HN8c HN9 HN10 HN11 HN12 HN13 HN14 HN15 HN15b, under
their own `catch` with an `HN0` guard row that counts only on a raise.

### `tests/headless/test_ase_persist.tcl` (+107 / −2)

Section **R8** `:508`–`:566` — R8a R8b R8c R8d R8e — placed after R7 for R7's own
stated reason: R2 is one of the five named load→save byte-identity rows and R3 is
the old-state-compat row, and this key is governed by both.

---

## THE THREE DECISIONS, AND WHY EACH IS THE ONE TAKEN

**1. `n` counts every row of the type, switched on or not.** Counting only enabled
rows renames `dc2` to `dc1` the moment somebody unticks the row above it — and a
measurement, or a line typed by hand into `calc::`, silently starts reading a
different sweep. Unticking is an everyday gesture. Sabotage **S2a** is exactly
that mistake (it is what copying `ase::meas_binding`'s walk would produce) and it
reds eight rows.

**2. An explicit `id` is claimed over the whole list before any derived handle is
minted.** A row that really is called `dc2` takes the spelling; the second derived
`dc` becomes `dc3`. Without the claiming pass the two are the same word and
`ase::analysis_by_handle` has to pick a winner — a coin toss wearing a rule. `HN5`,
with `HN5c` performing HN5's own sabotage in process.

**3. A type the registry does not OFFER still gets a handle** — see *the finding*
below.

### Two smaller ones, stated so nobody re-derives them

* **An illegal `id` is not a handle and the row falls back to its derived one.**
  `id {my sweep}` cannot be typed into an expression, so honouring it hands the
  user a broken reference; dropping the row from the list leaves the analysis they
  most want to ask about with nothing to call it. `ase::analysis_handle_faults` is
  what says so, by index and spelling, in tokens rather than sentences — core
  answers the machine question and a surface owns the words (D34).
* **`ase::analysis_by_handle` folds case**, because the simulator does. A user who
  types `AC1` beside vectors the simulator folded means `ac1`.

---

## ⚠ THE TRAP THE BRIEF NAMED, AND WHERE IT IS CAUGHT

Four committed benches carry `outputs {{name id expr -i(v1) save 1 plot 0}}` — a
**drain current**, in a different list, whose `name` happens to be the word.
Every reader takes an **`analyses`** row and asks `dict exists $row id`; nothing
added here reads `outputs` at all.

**`HN7`** asks it of the readers (an output row named `id` changes no handle and
raises no fault; an `id` on the *analysis* row changes exactly one) and **`R8e`**
asks it of the **file**. Sabotage **S5** makes the confusion real — an output row
named `id` treated as a declaration — and reds **exactly those two rows and
nothing else in 771 checks** (S5 was re-run at the final floor for this number).

---

## ⚠ THE FINDING: WHAT A HANDLE LOOKS LIKE WHEN THE TYPE IS NOT OFFERED

The brief asked *"what does your feature look like when the thing carrying it is
not offered?"*, after receipt 26's `registered 0` finding. Asked and answered:

`ase::analysis_offered` drops a `registered 0` entry, so such a type is invisible
to the radio row, to the seed and to every offered-shaped reader in
`test_ase_core.tcl` — **and a bench can still hold a row of it**, from a
hand-edited state or from an adapter that withdrew a type. A third case goes
further: a type the registry has never heard of at all.

**All three keep their handle**, measured on a scratch backend `hnsim` whose
registry declares `zzon` (`registered 1`) and `zzoff` (`registered 0`), against a
bench that also carries a `zzgone` row:

```
ase::analysis_offered hnsim            ->  zzon
ase::analysis_handles $HNOFF           ->  zzon1 zzoff1 zzgone1
ase::analysis_handle_fields … 1        ->  handle zzoff1  type ZZOFF   args 4
ase::analysis_handle_fields … 2        ->  handle zzgone1 type ZZGONE  args {}
```

*"What do I call this one?"* is a question about the **bench**, which the state
answers, not about the registry, which may never have heard of it. Deriving the
handle from `ase::analysis_offered` would leave exactly the rows a user most needs
to ask about with nothing to call them — **and it would do it silently**: sabotage
**S6** does precisely that and reds **`HN10` alone, out of 771 checks** (re-run at the final floor).

---

## THE SABOTAGE CAMPAIGN

Restores are `cp` from pristine copies taken before the first edit of each pass,
with an md5 compare. Pristine md5s at the end: `src/ase.tcl`
**34d88a969dc76fa5e404c2d0cbd91614**, `tests/headless/test_ase_core.tcl`
**e92a927a7144b9ae10032eedcd8ab594**, `tests/headless/test_ase_persist.tcl`
**03f672f27a39a9711660d225ccf35720** — each verified equal to the working file
after every restore.

| # | what was broken | verdict | rows reddened, by name |
|---|---|---|---|
| **S1** | `ase::state_load` back-fills an `id` onto every analysis row — *"`id` written on a round trip"* | core `3 FAILED (617)`, persist `8 FAILED (41)` | **CP7**, R2, R4 / R2, R7a, R7b, R7c, R7d, **R8a**, **R8b**, **R8d** |
| **S2a** | the ordinal counts only **enabled** rows | core `8 FAILED (612)`, persist `1 FAILED (48)` | **HN1**, HN2, HN4, HN7, HN8, HN11, HN12, HN14 / **R8a** |
| **S2b** | every row of a type collapses to the first one's handle — *"two rows of a type collapsing to the first"* | core `8 FAILED (612)` | **HN1**, HN2, HN4, **HN5**, **HN5c**, HN8, HN11, HN14 |
| **S3** | `ase::analysis_handle` returns the constant `a1` — *"the naming scheme returning a constant"* | core `6 FAILED (614)` | HN1, HN3, HN8, HN9, HN10, HN11 |
| **S3b** | `ase::analysis_handles` returns nothing for every row — the extractor that cannot disagree | core `15 FAILED (605)`, persist `3 FAILED (46)` | fifteen HN rows — HN1 HN2 HN3 HN4 HN5 HN5c HN6 HN7 HN8 HN9 HN10 HN11 HN12 HN13 HN14 / R8a, R8b, R8e |
| **S4** | `ase::meas_binding` ignores the `id` selector | core `2 FAILED (618)` | **HN13**, **HN14** |
| **S5** | an **output** row named `id` read as a declaration | core `1 FAILED (621)`, persist `1 FAILED (48)` | **HN7** / **R8e** — **and nothing else** |
| **S6** | handles derived from `ase::analysis_offered` — the not-offered case | core `1 FAILED (621)` | **HN10** — **and nothing else** |
| **S7** | HN5c's `dict remove` deleted — the control stops controlling | core `1 FAILED (619)` | **HN5c** |
| **S8** | HN8c injects nothing — the other control stops controlling | core `1 FAILED (619)` | **HN8c** |
| **S9** | CP7c injects no `id` — the corpus control stops controlling | core `1 FAILED (619)` | **CP7c** |

⚠ **S1–S4, S7, S8 and S9 were run before `HN15`/`HN15b` landed, so their passing
counts are against a 620-row `test_ase_core` and a 769-check total; S5, S6, S10
and S11 are against the final 622 / 771.** No red set changed — S5 and S6 were
re-run at the final floor and named the same rows.

| **S10** | a simulator verb list (`{ac dc tran op}`) planted in `ase::analysis_handle_text` | core `1 FAILED (621)` | **HN15** |
| **S11** | HN15's token list blinded to `{zzzzz}` | core `1 FAILED (621)` | **HN15b** |

`test_ase_meas_1443` stayed `ALL PASS (100)` through every one of the thirteen,
which is the statement that the arm on `ase::meas_binding` did not disturb the
suite that owns it.

### The four ways a row fails to fail, answered

1. **Fixtures that never disagree.** `CP7` reads the **committed corpus** through
   `git ls-files` — 104 real files, no fixture. `HN10` builds a scratch backend
   because the shipped registry has no `registered 0` entry to borrow, and says so.
   Every other HN row reads the shipped `ngspice` registry.
2. **Asking about position where the mechanism is last-writer-wins.** Deliberately
   inverted here: `HN2` asks *"what happens to the word when the rows move?"* and
   pins that the handle list is **unchanged** while `dc1` names the other sweep —
   which is the honest statement that a derived handle **is** a position, and the
   argument for `id`. Nothing in this section asserts an ordering that a
   last-writer-wins mechanism could satisfy by accident.
3. **An extractor that returns nothing cannot disagree.** **S3b** blinds the
   speller and reds fifteen core rows plus three persist rows. Three standing
   in-process positive controls run their own row's sabotage: **CP7c** (a
   committed file that must stop round-tripping), **HN5c** (the id removed, both
   halves move), **HN8c** (one field changed, one summary moves), plus **HN15b**,
   which runs HN15's own token list against the adapter so the D34 guard cannot
   pass by searching for nothing.
4. **A sabotage missing from the generator.** **S7**, **S8**, **S9** and **S11**
   exist for exactly this: each sabotages a **control**, and each reds that control
   alone.

---

## D34 — ASE-L OWNS THE SCHEMA, THE ADAPTER OWNS THE CONTENT

Section **HK** of `test_ase_meas_1443.tcl` runs a token list over its own
thirty-one `ase::meas_*` procs. **Its proc list cannot see a different prefix**,
so the eight procs added here were outside every guard in the tree. `HN15`
(`test_ase_core.tcl:7117`) asks the same question of them, with `HN15b` as its
non-vacuity control against the adapter. Both green; **S10** proves HN15 can red.

The handle is built from the row's **own stored `type`** — data the bench carries
— and the uppercase display form is `string toupper` of the same. No verb, no
option name, no emit syntax enters core. `args` comes from **`ase::analysis_line`**,
the emitter's own speller, which is the identical reason `ase::ui::arg_summary`
reads that proc: a summary assembled from the row's keys can describe a setting
the deck does not carry, and `ac`'s `dec` is the drift that proved it.

---

## ⚠ WHAT THE GUI HALF MUST CALL — SPELLED AS CODE

**Nothing below may mint a display form of its own.** The word a user reads off
the grid has to be the word they type into `calc::`.

```tcl
# --- surface 2: the handle column in the Choose Analyses grid ----------------
# one column, one call per row index, alongside the existing Arguments column
set handle [ase::analysis_handle $state $idx]        ;# "dc2", or {} for a
                                                     ;#  row with no type

# --- surface 3: Analyses > List ---------------------------------------------
# the whole body of the window, already padded and already marked (off)
set body [ase::analysis_handle_text $sim $state]
#   op1    OP
#   dc1    DC    V2 0 1.8 0.01
#   dc2    DC    TEMP -40 125 5  (off)
# ⚠ EVERY ROW, not only the enabled ones -- a correction to issue 1444, below.

# --- surface 1: Stage 8 task 2's Measurements dropdown ----------------------
# one entry per analysis row; show the three fields, store the HANDLE
foreach idx [...] {
  set f [ase::analysis_handle_fields $sim $state $idx]
  #  {handle dc1 type DC args {V2 0 1.8 0.01} enabled 1}
  # entry text: "[dict get $f handle]  [dict get $f type]  [dict get $f args]"
}
# on OK, write the chosen handle onto the MEASUREMENT row:
dict set measrow id $chosen_handle       ;# NOT `row <index>`
# `ase::meas_binding` then binds by handle, and the handle BEATS `row`.

# --- an editable `id` field, wherever the grid grows one --------------------
if {![ase::analysis_id_ok $typed]} { ... }            ;# a bare identifier
set faults [ase::analysis_handle_faults $state]       ;# {idx illegal|duplicate spelling}
```

**Do not** call `ase::analysis_id` to build a display string — it answers `{}` for
a row that has no explicit `id`, which is most rows. `ase::analysis_handle` is the
one that always has an answer.

**Do not** re-derive `<type><n>` anywhere. If a surface needs the parts, it takes
them from `ase::analysis_handle_fields`; if it needs the whole line, from
`ase::analysis_handle_text`.

---

## Corrections to the brief and to the plan

* **C-R6-1 — `Analyses > List` lists EVERY row, not only the enabled ones.** Issue
  1444 proposed *"a dump of one-liners for the enabled analyses"*. A measurement
  bound to a switched-off row **refuses**, and the user's next question is *which
  one is off*; a list that omitted it could not answer, and it would disagree with
  the grid beside it, which shows them all. `ase::analysis_handle_text` includes
  every row and marks a disabled one `(off)`. Recorded in issue 1444's appended
  section and in the ⚖ R9 rule debt.
* **C-R6-2 — the measurement row's selector key is `id`, and it is the ANALYSIS
  row's handle, not its index.** Receipt 23's note reads *"an explicit selector
  matches either the row's index or its `id`"*, which could be read as extending
  the `row` key. It is a **separate key**, exactly as `PLAN.md` §8a's own example
  row spells it (`{name pm analysis ac id a1 kind param …}`), and it **outranks**
  `row` rather than being reconciled with it: an index is a position and a handle
  is a name; a row carrying both has been edited by two hands and the name is the
  one a person chose.
* **C-R6-3 — an `id` alone is a sufficient selector.** `ase::meas_binding`
  previously returned `{}` for a row with no `analysis`. It still does when there
  is no `id`; with one, the handle alone binds. A stale `analysis` that
  **disagrees** with the handle binds to nothing and gets its own sentence, rather
  than being silently overruled.
* **C-R6-4 — the persist floor paragraph was one behind.** It read *"44 checks on
  the headless arm and 147 with a display"*; the display arm measured **148**
  before this task touched it. A floor only ever goes up, so it passed while
  understating. Both numbers are re-measured and corrected in the same diff.
* **`R8b`'s fixture must be ONE LINE.** A Tcl list literal broken across lines
  carries the newlines into the value, `ase::state_serialize` quotes them with
  backslashes, and the `analyses` line stops being a line. Measured here as a red
  before it was fixed; the comment above the fixture says so.

---

## Three binaries — not applicable, and why that is said rather than skipped

The brief's rule is that a change touching what ASE-L **emits, reads back or
offers** is verified against `/usr/bin/ngspice` (apt 45.2) as well as the fork.
**Nothing added here starts a simulator, reads a binary or touches the capability
cache** — no `exec`, no `auto_execok`, no probe. `ase::analysis_handle_fields`
reaches `ase::analysis_line`, which expands a template from the registry the
adapter declares as Tcl. Both arms are ALL PASS, so the answer is the same on
every binary by construction. The suites' own `E*` legs are untouched.

---

## Files changed

* `src/ase.tcl` — **+293 / −0**. Eight procs after `ase::analysis_unrenderable`
  (`:9144`–`:9385`), the `id` arm on `ase::meas_binding` (`:6854`), three clauses
  on `ase::meas_verdict` (`:6980`).
* `tests/headless/test_ase_core.tcl` — **+410 / −0**. `CP7`, `CP7c`, section HN
  (18 rows), and the floor paragraph `602 -> 622`.
* `tests/headless/test_ase_persist.tcl` — **+107 / −2**. Section R8 (5 rows) and
  the floor paragraph `44 -> 49 / 148 -> 153`.
* `doc/claude/issues/1447-two-sweeps-of-one-type-and-no-word-for-either-of-them.md`
  — **new**.
* `doc/claude/issues/1444-…md` — **appended only**: which half landed, the scheme
  in one sentence, and the exact call each open surface owes.
* `doc/claude/issues/NUMBERING.md` — the 1447 entry, pointer **1447 → 1448**.
* this receipt.

Nothing else. **`src/ase_window.tcl` and `tests/headless/test_ase_dialogs.tcl`
were never opened for writing**, and no new suite file was created — the rows went
into the two suites the dispatch named, so `tests/run_regression.tcl` **does not
change**.

---

## For the driver

* **`NUMBERING.md`'s pointer was advanced 1447 → 1448**, and both mint checks were
  run at the moment of minting: the reserved-band scan over this clone's head
  table (**silent** for 1447) and `ls ~/dev/*/doc/claude/issues/1447-*` plus
  `/usr/bin/grep -lw 1447` across **both** clones' `NUMBERING.md` (only this
  clone's own pointer line). Re-run after HEAD moved (below) — still unique.
* **⚠ HEAD MOVED UNDER THIS TASK, THREE TIMES.** Handed over at **`1a79cc5b`**;
  it is at **`eb3d9593`** as this is written (`1cc37ae6`, `a06012eb` — ⚖ R5's
  issue 1446 — and `eb3d9593`). Checked rather than assumed:
  `git diff --stat 1a79cc5b HEAD -- src/ase.tcl tests/headless/test_ase_core.tcl
  tests/headless/test_ase_persist.tcl` is **empty**, and `NUMBERING.md` is not
  among the seven files those commits touched, so nothing here sits on top of
  somebody else's edit. `src/ase_window.tcl` and `test_ase_dialogs.tcl` gained
  the 1446 work and are now **clean** in the working tree — they were dirty when
  this task started and this crew did not touch them either way.
* **T1 was NOT run by this crew** (issue 0990 — it is yours and runs solo).
  `tests/run_regression.tcl` runs `headless/test_ase_core` and
  `headless/test_ase_persist`, so the counts it sees move **602 → 622** and
  **44 → 49** headless, **148 → 153** on its display arm.
* **A `rule` debt was filed: `owed.sh add rule 1447`** (ledger now 164 rule / 59
  look / 10 suite), stamped `repo:/home/analog/dev/xschem-claude`, `ref:` resolving
  to the 1447 issue file. It carries **five** unratified wordings — the handle
  spelling (`dc1` lowercase, the user's own sketch, against the house UPPERCASE
  rule), the uppercase TYPE column beside it, the `(off)` marker, the departure
  from 1444's *"enabled analyses"*, and the three new refusal sentences. The user
  is reviewing `R9_COPY_REVIEW.md` now and this joins it.
* **No `look` debt and no `suite` debt.** No pixels shipped — there is no widget in
  this change — and both suites pass on the dev display as well as headless, so a
  `:0` run is not owed for schema rows that render nothing.
* **⚠ FOUR UNSTAMPED LEDGER ENTRIES, FOUND WHILE TAKING THE BACKUP, AND NOT MINE
  TO TOUCH.** `CLAUDE.md` says an unstamped entry against a stamped ledger is
  evidence of another clone's older `owed.sh` overwriting something. Measured
  2026-09-13 09:10 before my first `add`:
  `/usr/bin/grep -L '^repo:' ~/.claude/xschem_owed/{rule,look,suite}/*` printed
  **four** — `rule/1357`, `rule/1357@xschem-claude`,
  `look/hier_pdf_nav_1357_H6.1789071932.2875683`,
  `suite/test_hier_pdf_links_1333` — all dated **Sep 10 13:25–13:35** and all
  unrelated to this batch (hierarchical-PDF nav and an `rdw::` list question). The
  two `rule/1357` files are issue 1400's collision shape in the ledger itself: one
  number, two different defects. `/usr/bin/grep -h '^repo:' …` split the rest
  **215 this clone / 13 op-wcard**. **I touched none of them**; a backup of the
  whole state dir was taken first at `/tmp/r6_owed_backup_091016`.
* **Nothing was committed, added, stashed, restored, cleaned or pushed.** No
  `git checkout --`, no `git restore`, no `git stash`, no `git clean`, no
  `git commit`, no `git push`, no PR. Working tree = the one handed over plus
  **five modified** (`src/ase.tcl`, the two suites, `NUMBERING.md`, issue 1444)
  and **two new** (the 1447 issue file, this receipt). The four untracked paths
  inherited at hand-over are untouched.
* **The one thing worth carrying forward.** The scheme is single-sourced **only for
  as long as nobody adds a ninth proc**. `HN15` names its eight by hand — a proc
  that spells a handle and is not in `HNPROCS` is outside the D34 guard, and a
  proc that spells a handle and is not `ase::analysis_handle*` is outside the
  *scheme*. If Stage 8 task 2 finds itself formatting `"$type$n"` anywhere, that is
  the second spelling this section exists to prevent.
