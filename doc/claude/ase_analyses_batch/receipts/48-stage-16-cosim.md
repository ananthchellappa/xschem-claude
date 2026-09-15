# Stage 16 task 3 — wiring 16c, so the two co-simulation checks reach a user (issue 1472)

**Issue `doc/claude/issues/1472-two-co-simulation-installation-defects-were-measured-characterised-and-said-to-nobody.md`**,
minted by this crew with CLAUDE.md's two checks (1472 outside every reserved band; no file and no
reservation for it in either clone under `~/dev/*`; `NUMBERING.md` pointer → **1473**). Handed over
as one task: the Band 1 fact, the say-site, and the words. Receipt 46's **C6** and receipt 47's
*What binds later work* 7 were the specification.

Files touched, and nothing else:

| file | ± | md5 before → after |
|---|---|---|
| `src/ase.tcl` | **+328 / −27** | `19d246d7` → **`001af1ca`** |
| `tests/headless/test_ase_variant_1470.tcl` | **+257 / −3** (sections SD, CD; floor 57 → 76) | `f1e4e31c` → **`19cc30b0`** |
| `tests/headless/test_ase_simcaps_0948.tcl` | +8 / −1 (row **V8**) | `f6b895cd` → **`ce6e2bca`** |
| `doc/claude/issues/NUMBERING.md` | +14 / −1 | `08c89a12` → `8d0225ce` |
| `doc/claude/ase_analyses_batch/R9_COPY_REVIEW.md` | +29 / −3 (R9-722, R9-723; R9-713 and R9-715's *Where*; the header count) | `f93aeb16` → `e43d8811` |
| the issue file (95 lines), this receipt | new | → `ae83c5eb` |

**`src/ase_window.tcl` md5-unchanged (`55b021fd`)** — this task draws nothing. `src/xschem.tcl`
unchanged (`87ba1eec`). **No C and no new `.tcl` under `src/`**: `make -q -C src` rc 0 before and
after, `src/xschem` `96fc4899` throughout, so no `Makefile.in` / `./configure` obligation. **No new
suite file, so `tests/run_regression.tcl` is unchanged (`cca6117d`) — and, as the brief instructed,
NOT run.** No commit, no `git add`, no stash/restore/clean/push. HEAD `a64bd6a3` at start and at
hand-over; nobody else moved the tree. **No simulation on a bench under `sky130A/`; nothing under
`~/.xschem/`; nothing written to `xschem-op-wcard`.**

---

## ⚠ THE CRASH RULE — HOW IT WAS KEPT

Every process this crew started on a real ngspice was **the ordinary capability probe** — the same
short `-b` decks Detect already runs, with one more `echo` line in leg D's deck. That is rows
SD7/apt, SD7/fork, EX1–EX3 and M21b in the suite, plus two diagnostics of my own: the shipped deck D
run by hand on apt 45.2 and on the fork (`s16t3/deckd/`, **rc 0 both**), and the probe-timing script
(three cold probes per binary, twice). **`/usr/bin/ngspice` never aborted.** No rc 134, no rc 139, no
core anywhere. **No linter pattern was run on any binary**, and section CD starts nothing at all —
row CD8 measures that structurally *and* by the stand-in's marker file.

---

## THE HEADLINES

### 1. The fact — `scripts_dir`, Band 1, and NO new process

`ase::caps_keys identity` gains **`scripts_dir`**, published by leg D from one more line in a deck
that was already running: `echo "@@sourcepath=$sourcepath" >> probe_d.txt`, leg D's own redirect
form. **MEASURED HERE**, three cold probes per binary, before → after:

| binary | probe wall-clock before | after | `scripts_dir` |
|---|---|---|---|
| **apt 45.2** `/usr/bin/ngspice` | 536 / 427 / 424 ms | **544 / 429 / 429 ms** | absent → `/usr/share/ngspice/scripts` |
| **the fork** | 456 / 452 / 451 ms | **459 / 452 / 450 ms** | absent → `<build-ver_50>/stage/share/ngspice/scripts` |

The cost did not move because no leg was added. It is **display and log only** — nothing gates on
it, and the two greps it leads to are their own verdict (row SD6). **Absent means unknown, never a
guess**: a `$sourcepath` naming no absolute `scripts` directory publishes no key, and the say-site
then says nothing (rows SD5, CD3).

### 2. ⚠ THE KEY DID NOT APPEAR ON THE FIRST TRY, AND WHY IS THE FINDING

The first post-change timing run reported `scripts_dir NOKEY` on **both** binaries while the
hand-built payload parsed perfectly. Running the shipped deck by hand, **MEASURED HERE**, one run,
both binaries:

```
@@gref=M7 my 0 rail                                                       <- bare
"@@sourcepath=. /usr/share/ngspice/scripts /usr/share/ngspice/scripts ."   <- wholly quoted
```

ngspice's `echo` **re-quotes an argument expanded from a LIST variable** (`sourcepath` is
`cptype list`); `gref`'s payload is literal text. So the quote lands **in front of the `@@`**, and
`cap_d_field`'s position-0 test never matches. The payload had been arriving intact all along, in a
shape no reader could find — **which is indistinguishable from empty at every call site.** Stripping
quotes per *element*, which receipt 46 shipped inside `scripts_dir_of`, cannot reach it.

New `ase::backend::ngspice::cap_d_unquote` removes one pair of whole-line double quotes before the
marker test. Removing a quote that is not there is a no-op, so every bare marker reads as before
(`test_ase_simcaps_0948` V2 still green on both payload shapes).

### 3. ⚠ THE SAME QUOTING HID A SECOND, LATENT DEFECT — A FABRICATED IDENTITY KEY

A quoted marker line does not begin with `@@`, so it survived `cap_d_identity`'s marker skip and was
offered to the version and date tests. A program installed under, say, `/opt/ngspice-46.2/share`
would then have had its Band 1 **`version_line` fabricated from a folder name**. The three preflight
binaries happen not to reproduce it — no `ngspice-` and no four consecutive digits in either
installed path — which is exactly the kind of luck a reader must not be left depending on. The skip
now unquotes first, and **row SD4 is that row**, driven by a hand-built `/opt/ngspice-46.2/...`
payload.

### 4. The say-site — where, when, and how often

`ase::cosim_shim_report` runs from `ase::run_deck`'s co-simulation block, **above
`ase::cosim_build`**: the first defect is precisely what makes that build fail its final link, and a
failed build raises out of `run_deck`, so a warning placed after it would never reach the one user
who needs it (row **CD9**, which also pins that what is said reaches the run log's `notes`).

* **The gate is this run's own promise of a VCD** — a map entry carrying `vcd`, which
  `ase::cosim_map` sets only when the run will really write one (never the Icarus arm, never a `.so`
  outside the run directory, never a `+`-continued card, never under `cosim trace 0`). So it is not a
  proxy for the user's intention; it *is* the promise, and the first defect is a failure of the
  `--trace` build that promise implies (row CD4).
* **Once per installed scripts directory per session**, keyed on `{sim dir check}` (row CD11), a
  **note** and never a modal, through `ase::sim_say`.
* **An `unknown` verdict says nothing** — "I could not look" is not a finding about somebody's
  installation (row CD2).
* **A backend with no `cosim_shim_verdict` hook gets nothing** — no fallback, no guessed file name
  (row CD5). A hook that raises gets a developer diagnostic and no sentence (row CD6).

### 5. The words — R9-713 … R9-716 said for the first time

The clauses and remedies are issue 1470's, re-used verbatim; only the **frame** is new
(`ase::sim_why cosim_install`, R9-722) plus one developer diagnostic (R9-723). The frame supplies
**no subject**, because both clauses are already whole subject + predicate, and `<path>` is the
**file**, not the program — the executable is blameless, and naming it would send the user to change
the wrong thing. Rendered on a broken tree (MEASURED HERE):

> This run asks for Verilog waveforms, and this ngspice's vlnggen does not link the VCD runtime, so a
> Verilog block built with waveforms fails at the final link with unresolved symbols. The file is
> `<dir>/vlnggen`. Fix: add the lines below to your copy of vlnggen, after its verilated_timing.o
> lines.
> *(then the seven lines from the fork's own `vlnggen`, verbatim)*

and the shim clause with *"a run that worked is not evidence the memory was valid"* and *"ngspice
itself needs no rebuild"*, followed by the three-line `contextp.release()` change.

---

## ⚠ WHAT I MEASURED VERSUS WHAT I TRANSCRIBED

All 2026-09-15. Every xschem launch was `--nolog` with `HOME` pointed at a fresh scratch directory;
the display arm ran on `:99` (Xvfb + **openbox**) with `XSCHEM_DEVDISPLAY_DIR` set to the real state
directory and `GUI_GATE=0`. Every command ran under `timeout`, in the foreground.

| claim | evidence |
|---|---|
| the probe wall-clock before and after, both binaries | **MEASURED HERE**, `s16t3/caps/time_before.txt`, `time_after2.txt` |
| `scripts_dir` recorded by the real probe on apt 45.2 and the fork | **MEASURED HERE**, the same runs, and rows SD7/apt and SD7/fork |
| the whole-line quoting of `@@sourcepath=`, and `@@gref=` staying bare | **MEASURED HERE**, the shipped deck D run by hand on both binaries (`s16t3/deckd/`) |
| the two installation greps on the apt and fork trees (`0 0` / `1 1`) | **MEASURED HERE** (files only), rows CS4 and SD7 |
| the composed sentences, clause + file + remedy + patch | **MEASURED HERE**, `s16t3/caps/smoke.txt` and row CD1 |
| a registry edit clears the said-ledger | **MEASURED HERE** — row CD11 as first written returned `{2 2 2}` |
| the `vlnggen` and shim defects themselves, and their patches | **TRANSCRIBED**, `evidence/fork-dependencies.md` §5 B4.1/B4.2 and receipt 46 — **deliberately not re-run** |
| `unset`/`define`/`load` aborting apt 45.2 | **TRANSCRIBED**, same file §3–§4 — never run |

---

## What shipped

### `src/ase.tcl` — the schema half

| proc | change |
|---|---|
| `ase::caps_keys` | `scripts_dir` joins the **identity** band |
| `ase::cosim_has_shim_hook` | **new** — does this backend check its own installation at all |
| `ase::cosim_scripts_dir` | **new** — the directory, out of the **free peek**, never a measurement |
| `ase::cosim_shim_notes` | **new** — the adapter's failed checks, validated; a raise is reported and swallowed |
| `ase::cosim_shim_say` | **new** — once per `{sim dir check}`, through `ase::sim_say … note` |
| `ase::cosim_shim_report` | **new** — the run's door, gated on a promised VCD |
| `ase::sim_why` | **new kind `cosim_install`** (R9-722) |
| `ase::sim_caps_clear` | also forgets `cosim_said` |
| `ase::run_deck` | calls `ase::cosim_shim_report` inside the co-simulation block, **above** `ase::cosim_build`, into `casenote` |

### `src/ase.tcl` — the ngspice adapter

**New** `cap_d_unquote`; `cap_d_field` and `cap_d_identity` read through it; `cap_deck_d` carries the
`@@sourcepath=` line; `cap_d_identity` publishes `scripts_dir`; `cosim_shim_verdict`'s two notes
carry **`file`**. No new hook registered — `scripts_dir_of` and `cosim_shim_verdict` were already
registered by issue 1470 and had no caller.

### `tests/headless/test_ase_variant_1470.tcl` — floor **57 → 76**, both arms

**SD** (8): SD1 the deck, SD2 the two payload shapes, SD3 what leg D publishes, SD4 the fabrication
trap, SD5 absent-is-unknown, SD6 the band, SD7/apt + SD7/fork the real probe end to end.
**CD** (11): CD1 the two sentences and the second-ask silence, CD2 sound and unknown, CD3 no key,
CD4 the VCD gate, CD5 no hook, CD6 a raising hook, CD7 malformed notes, CD8 structural (no process,
reads the peek, marker file unmoved), CD9 structural (order in `run_deck`, and the log), CD10 the
clear, CD11 the say-once key. SD7/apt and SD7/fork self-skip, uncounted, when their binary or
installed tree is absent; **0 SKIPPED on every run here**.

---

## Suites — before → after, both arms, with rc

**Before** = HEAD `a64bd6a3` untouched (`s16t3/logs/base/`). **After** = the final tree
(`s16t3/logs/after/`). One fresh `HOME` per suite, `timeout --kill-after=20 400` per launch.

| suite | headless before | headless after | display before | display after |
|---|---|---|---|---|
| **`test_ase_variant_1470`** | 57, rc 0 | **76, rc 0** | 57, rc 0 | **76, rc 0** |
| `test_ase_simwin_variant_1471` | 12, rc 0 | 12, rc 0 | 21, rc 0 | 21, rc 0 |
| `test_ase_simcaps_0948` | 211, rc 0 | 211, rc 0 | 211, rc 0 | 211, rc 0 |
| `test_ase_simreg_0931` | 117, rc 0 | 117, rc 0 | 117, rc 0 | 117, rc 0 |
| `test_ase_cosim` | 341, rc 0 | 341, rc 0 | 341, rc 0 | 341, rc 0 |
| `test_ase_events_1465` | 87, rc 0 | 87, rc 0 | 87, rc 0 | 87, rc 0 |
| `test_ase_core` | 638, rc 0 | 638, rc 0 | 638, rc 0 | 638, rc 0 |
| `test_ase_persist` | 49, rc 0 | 49, rc 0 | 153, rc 0 | 153, rc 0 |

Every cell reads `RESULT: ALL PASS (<n>)`. **Not a count diff — a name diff**: for the seven existing
suites on both arms the sorted `status id` list after versus before is **identical, `SAME` × 14**.
`test_ase_variant_1470`'s diff on each arm is exactly its **19 new rows appearing as `ok`**, nothing
lost and nothing changed status. `test_ase_simcaps_0948`'s **V8** keeps its name and its `ok`; what
moved is the expected value, with a paragraph naming issue 1472.

### Per binary

SD7/apt, SD7/fork, EX1/apt, EX2/fork, EX3/up47, CS4/apt, CS4/fork and M21b ran on **every** run of
both arms — **0 SKIPPED**. Sections SD (except SD7) and CD are pure Tcl and file reads and start
nothing.

---

## `.state` byte identity

Row **ST1**, through `tests/headless/state_roundtrip.tcl`, green on both arms before the campaign, in
every campaign arm that left `ase::omit_if_empty` alone, and on the restored tree:

```
tracked 104    bad {}    control_disagrees 1    control_agrees 1
```

No state key was added — `scripts_dir` is a **capability** key, which no `.state` file carries.

---

## THE SABOTAGE CAMPAIGN — 25 arms, every one of the 19 new rows reddened, 0 restore mismatches

`sab.py`, three chunks, headless arm (**no new row is display-gated** — both arms run all 19, and the
restored-tree row was taken on both). Started with **no `xschem` alive, matched by `comm`**. Each arm
verified the post-fix md5, applied a mutation whose anchor occurs **exactly once**, ran the suite,
read reds **by row name**, restored by a plain write and compared md5. The restore is guaranteed by
`try/finally` plus SIGTERM/SIGINT handlers. **The gate is a positive assertion and was fed the empty
case first**: `GATE CONTROLS empty=NORESULT partial=NORESULT pass=PASS fail=FAIL`.
**0 NOT APPLIED, 0 RESTORE MISMATCH, 0 NORESULT.**

| # | what I broke | reds |
|---|---|---|
| **S00** | **the whole pre-change `src/ase.tcl`** | SD1 SD2 SD3 SD4 SD6 SD7/apt SD7/fork · CD1–CD11 · simcaps **V8** |
| S01 | leg D stops asking for `$sourcepath` | SD1 SD7/apt SD7/fork |
| S02 | the marker reader forgets about whole-line quoting | SD2 SD3 SD4 SD7/apt SD7/fork |
| S03 | leg D never publishes the directory | SD3 SD4 SD7/apt SD7/fork |
| S04 | an unparsed `$sourcepath` is **guessed** as `/usr/share` | SD5 |
| S05 | the identity loop's marker skip drops the unquoting | SD4 |
| S06 | the key leaves the identity band | SD6 · V8 |
| S07 | the key becomes a **capability**, so something could gate on it | SD6 · V8 |
| S08 | the say-site **measures** instead of peeking | CD8 |
| S09 | an unmeasured directory is served as `/usr/share` anyway | CD3 |
| S10 | a malformed note is no longer dropped | CD7 |
| S11 | a raising hook is not caught | CD6 |
| S12 | a backend with no hook is given **fallback** content | CD5 |
| S13 | "said" is never recorded | CD1 CD10 CD11 |
| S14 | the say-once key is the **program**, not the directory | CD11 |
| S15 | the gate accepts any co-simulation, promised VCD or not | CD4 |
| S17 | the sentence loses the patch | CD1 |
| S18 | the sentence never names the file | CD1 |
| S19 | clearing the measurements does not forget "said" | CD2 CD4 CD10 CD11 |
| S20 | the run never asks about its co-simulation files | CD9 |
| S21 | what is said never reaches the run log | CD9 |
| S22 | it **builds first and warns afterwards** | CD9 |
| S23 | a file that could not be read is reported as a defect | CD2 · CS2 |
| S24 | a **sound** installation is warned about | CD2 SD7/fork · CS2 CS4/fork |
| S25 | the note loses the file it is about | CD1 CD2 CD4 CD10 CD11 |
| **final** | **the restored tree**, md5 `001af1ca` | **variant_1470 ALL PASS (76) headless AND display · simcaps_0948 ALL PASS (211) both arms**, rc 0 each |

**Coverage — every new row has a killer:** SD1 (S00 S01) · SD2 (S00 S02) · SD3 (S00 S02 S03) ·
SD4 (S00 S02 S03 S05) · **SD5 (S04)** · SD6 (S00 S06 S07) · SD7/apt (S00 S01 S02 S03) · SD7/fork
(S00 S01 S02 S03 S24) · CD1 (S00 S13 S17 S18 S25) · CD2 (S00 S19 S23 S24 S25) · CD3 (S00 S09) ·
CD4 (S00 S15 S19 S25) · CD5 (S00 S12) · CD6 (S00 S11) · CD7 (S00 S10) · CD8 (S00 S08) ·
CD9 (S00 S20 S21 S22) · CD10 (S00 S13 S19 S25) · CD11 (S00 S13 S14 S19 S25).

**SD5 is the one new row S00 leaves green**, and deliberately: it pins that nothing is published
when nothing was parsed, which a tree with no feature also satisfies. S04 — planting the guess — is
its killer, and that is the shape the crew brief asks for (*"what does this check do when it is
handed nothing?"*).

⚠ **S12 was written as "plant fallback content", not "delete the no-hook guard"**, because deleting
it is invisible: the raise it causes is swallowed by the `catch` one line below, the notes list comes
back empty either way, and CD5 would have stayed green. The defect being fenced is a *guessed
clause*, so that is what the arm plants.

Logs: `s16t3/sab/results.txt` and `s16t3/sab/logs/<arm>.<suite>.h.log`.

---

## Debts — before → after

`owed.sh count`: **184 rule, 70 look, 11 suite → 185 rule, 70 look, 11 suite.** The ledger was backed
up first (`s16t3/owed_backup/`, 266 files). The add answered `recorded` and the entry is stamped
`repo:/home/analog/dev/xschem-claude`.

* **rule `1472`** — the two new strings (R9-722, R9-723) and four choices: it is said on the run that
  first asks for Verilog waveforms; once per installed scripts directory, keyed on the **directory**;
  an `unknown` verdict says nothing; the sentence names the **file**, not the program.
* **look** — none. This task draws nothing; `src/ase_window.tcl` is md5-unchanged.
* **suite** — none added. `test_ase_variant_1470` is already in T1's `hcases`.
* **R9**: 721 → **723** entries, from 35 → **36** issues, for `LEDGER.md`'s count. R9-713 and R9-715's
  *"not yet said anywhere"* notes are now corrected in place.

---

## Corrections

| | |
|---|---|
| **C1** | ⚠ **Receipt 46's C5 was half the finding, and the tree's comment was wrong in the other direction.** The vocabulary comment said `$sourcepath` *"came back EMPTY from inside the probe deck"*; C5 said that did not reproduce. **Both missed that the key still never appeared**: the line arrives **wholly double-quoted**, because `echo` re-quotes an argument expanded from a list variable, so the `@@` is not at position 0 and no reader could find it — indistinguishable from empty at the call site. Fixed in `cap_d_unquote`; both comments corrected in place |
| **C2** | ⚠ **A latent defect the quoting concealed**: a quoted marker line survived `cap_d_identity`'s `@@` skip and was offered to the version and date tests, so a program under a path like `/opt/ngspice-46.2/share` would have had `version_line` **fabricated from a folder name**. Not reproducible on any of the three preflight binaries. Row **SD4** |
| **C3** | **PLAN §16c gives the two checks different verbs** — the `vlnggen` one *"run once, when the user first asks for Verilog waveforms"*, the shim one *"warn"*. Shipped at **one door**, the waveform gate, because both are about the same installation and the user can fix both in one sitting. Confining the shim warning to that gate is a deliberate narrowing (the defect bites every co-simulation, traced or not) and is recorded under rule `1472` |
| **C4** | ⚠ **This crew's own, and measured rather than reasoned:** row CD11 was written as *"two registered entries sharing one tree are told once between them"* and came back **`{2 2 2}`**. Registering the second entry is a **registry edit**, and every registry edit calls `ase::sim_caps_clear` (issue 0950), which now forgets the said-ledger too. That user **is** told again, and rightly. The row now tests the key where it lives, and the header comment that made the same false claim was corrected with it |
| **C5** | **PLAN §16's Files table gives the adapter ≈ +230 for all of 16c.** 1470 spent that on the checks; this task added +328 / −27 across schema and adapter, most of it the comments the house style requires, and **no `ase_window.tcl` change at all** |

---

## What binds later work

1. **The note contract**: `{check file clause remedy ?patch?}`; a note missing any of the first four
   is dropped, a non-dict is dropped, a raising hook gives no sentence, and **a backend with no hook
   gets nothing**. A second adapter brings its own installation defects and keeps the frame.
2. **`scripts_dir` is Band 1 — display and log only.** ⚠ **The D48 conformance scanner (CF2) reads
   only the capability and defect bands**, so a bare `dict get $caps scripts_dir` would *not* be
   caught by it. This task routes through `ase::caps_get` and row SD6 pins the band, but a future
   reader adding an identity key should know the scanner does not cover them.
3. **`cap_d_unquote` now sits under every `@@` marker.** Any future marker whose payload interpolates
   a **list** variable will arrive wholly quoted; the reader already handles it, and a marker line can
   no longer be mistaken for identity.
4. **"Once per session" means once per measurement epoch.** Every registry edit clears the ledger
   with the measurements (issue 0950). Rows CD10 and CD11 pin the two halves.
5. **`run_deck`'s order is pinned by CD9**: `cosim_shim_report` inside the co-simulation block, above
   `cosim_build`, its answer appended to `casenote`. Moving it below the build silences it for the
   user whose build is about to fail.
6. **T1's `hcases` floor for `test_ase_variant_1470` is now 76**, and the suite starts apt 45.2 and the
   fork twice more (SD7), about 1 s. Headless and display run the same 76 rows.
7. **The two clauses are now said, so PLAN §16c is closed** — with the shim warning scoped to the
   waveform gate (C3), which is the one part of §16c a ruling could still move.

---

## Hygiene

* **One tree-reading phase at a time, in this order:** baseline (both arms, in parallel) → timing →
  patch → diagnosis of the quoting (hand deck run) → fix → timing again → suite → after (both arms)
  → campaign (three sequential chunks) → restored-tree rows on both arms.
* **Every command had a `timeout` and every run was in the foreground.** No background runner and no
  waiter loop were used, so none can wake later. No `pkill`, no `pgrep -f`; processes were checked by
  `comm` at every phase boundary, and at hand-over **`xschem` 0, `ngspice` 0, `python3` 0**.
* **Nothing under `~/.xschem/`**: every launch used its own scratch `HOME`, so every probe workdir and
  every artifact landed in scratch. `owed.sh` wrote the real ledger once, after a backup.
* **Snapshots disarmed.** `snap/` (the pre-change and post-fix copies) and `sab.py` are under
  `…/scratchpad/s16t3/ARCHIVED_DO_NOT_RESTORE/i1472/`.
* **Logs kept:** `s16t3/logs/{base,new,after,final}/`, `s16t3/sab/` (three chunk transcripts,
  `results.txt`, per-arm logs), `s16t3/caps/` (both timings, the smoke), `s16t3/deckd/` (the hand deck
  run on both binaries).
* ⚠ **If this crew is woken after collection: run `git status` and `git log` before touching
  anything.**

`…/scratchpad` is `/tmp/claude-1000/-home-analog-dev-xschem-claude/c8183bb1-7387-41d6-9d30-a409f8d7e1a3/scratchpad`.
