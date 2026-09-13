# Stage 7 task 2 — the pre-deck class, and the door `wnflag` never needed

**One commit, issue 1439, and the second of Stage 7's four tasks.** Scope was
`PLAN.md` **§7d** and nothing else; §7a and §7b landed as task 1 (`d2f4437a`,
issue 1437); §7c, §7e, §7f and §7g are tasks 3 and 4 and are untouched here.

**It fixes issue 1438 — all three defects — and refutes 1438's own account of
the first one.**

**Floor:** new suite `test_ase_predeck_1439` — **78 checks**, registered in
`tests/run_regression.tcl`'s `hcases`, so **T1 covers all 78**.
`test_ase_simreg_0931` **111 → 117** (new section P). `test_ase_options_1437`
stays at **75** with **seven rows re-baselined**, each carrying the measurement
that moved it.

---

## ⚠ THE HEADLINE: THE FIVE BENCHES NOW DELIVER, AND THE REASON THEY DID NOT IS NOT THE ONE ON FILE

Issue **1438** says `wnflag` cannot be reached by any `.options` card because one
of its three read sites runs while the netlist is being read. **Two of those
three sites are dead code**, verified in `/home/analog/dev/ngspice` (`ver_50`,
`ccebdf2a2`):

* `src/frontend/inpcom.c:990` reads `wnflag` into a local that
  `inp_get_w_l_x()` **never uses again** — the identifier does not appear in the
  function after the `cp_getvar` call, and the loop it guards is itself gated on
  `newcompat.hs || newcompat.spe`;
* `src/frontend/inp.c:2828` is inside `#ifdef REM_UNUSED`, and **`REM_UNUSED` is
  defined nowhere** — three `#ifdef`s in `inp.c`, no `#define` in the tree, not
  in `configure.ac`, not in the build's `config.h`. The same shape as
  `ramptime`'s `XSPICE_EXP`.

The one live read is `src/spicelib/parser/inpgmod.c:268`, inside
`INPgetModBin()`, at **model-binning time** — after `inp_dodeck()` turns the
deck's `.options` cards into `ci_vars`. ngspice's own comment at `:293-294` says
so in as many words: *"Now it depends on the default wnflag or on the `.options`
wnflag."*

**MEASURED on BOTH binaries** — `/usr/bin/ngspice` (`ngspice-45.2`) and the fork
(`/home/analog/dev/ngspice/build-ver_50/src/ngspice`, `ngspice-46+`) — on a flat
`m` line **and** on the sky130 `x`-line shape the five benches actually use,
with two binned models 0.4 V apart:

```
                                     @m1[vth]        i(vd)
.options wnflag      (ASE-L's line)  9.888996e-01   -1.01728e-03
.options wnflag=1                    5.888996e-01   -1.73730e-03
set wnflag=1  inside .control        9.888996e-01   -1.01728e-03
-D wnflag=1                          9.888996e-01   -1.01728e-03
-D wnflag                            9.888996e-01   -1.01728e-03
<rundir>/.spiceinit  set wnflag=1    5.888996e-01   -1.73730e-03
```

**A 71% difference in drain current, at rc 0, with a clean log.** So the wrong
door was the **value**, not the phase: `wnflag` is a `deck` option and issue
1438's **defect 1 is its defect 2**. The brief asked for this one explicitly and
the answer is: fixed here, and fixed by the emitter rather than by the pre-deck
door.

**After the fix, over the user's own tree:** `ase::state_option_delivery` across
the 104 committed `.state` files reported `6 {acct list wnflag} 5` before and
reports **`1 {acct list} 0`** after. The one bench left is the `acct`/`list`
bench, whose two options are inert on ASE-L's `.control` route — and that is
`test_ase_options_1437`'s row DL5, re-baselined, with the note that **this row
going back up is a regression**.

---

## What shipped — the SCHEMA half (`src/ase.tcl`, `ase::`)

| proc | what it answers |
|---|---|
| `ase::opt_owner {sim name}` | the ASE-L control that really sets this option, or `{}` |
| `ase::opt_offer {sim name}` | `no` / `elsewhere` / `clamp` / `caveat` / `yes` — the inert list's shapes as an answer §7c can draw |
| `ase::rundir_is_shared {state}` | was the `set_netlist_dir 0` fallback taken? |
| `ase::predeck_plan {sim state}` | `{argv … file … refused … filewhy …}` — the whole answer for one run |
| `ase::predeck_argv {sim state}` | the command-line words, flattened |
| `ase::predeck_deliver {sim state plan}` | the optional `predeck_write` hook, or `{}` |
| `ase::predeck_report {sim state plan report}` | the sentences the run says — once |

plus an `owner` arm in `ase::opt_line`, `ase::opt_restore_line`,
`ase::state_option_delivery` and `ase::option_schema_errors`.

## What shipped — the CONTENT half (`ase::backend::ngspice`)

`predeck_file`, `predeck_marker`, `predeck_user_file`, `predeck_write` —
registered as the optional **`predeck_write`** hook — and the `-D` arm in
`run_cmd`. Core knows no filename, no flag and no option name: section **HK2**
asserts it lexically over all seven new core procs against `.spiceinit`,
`spice.rc`, `casemode`, `wnflag`, `ngbehavior`, `sqrnoise`, `.options`,
`.control`, `CP_BOOL`, `CP_NUM`, `ngspice` and `-D`.

## What shipped — the EMITTER

`render_deck`'s option loop now asks what kind of option it is writing. Three
arms, and the order matters:

1. a name this simulator does not describe keeps the **old rule** — a catalogue
   is a claim about one simulator and the user may know something it does not;
2. an option whose door is not the deck's is **not written here** — the pre-deck
   doors carry it, and the run says so when they cannot;
3. everything else goes through **the one speller**.

An inert or owned row whose door **is** the deck's falls back to arm 1 rather
than vanishing: dropping a card a user's bench has carried for a year is a deck
change with no measurement behind it, and §7c owns the surface that stops it
being offered. Row **RD8** pins that, so the day it moves the suite says so.

---

## ⚠ WHAT I VERIFIED VERSUS WHAT I TRANSCRIBED

| claim | evidence |
|---|---|
| `wnflag`'s three read sites, two of them dead | **VERIFIED in the C source** — `grep -n wnflag` over `src/`, the function bodies read, `REM_UNUSED` grepped across the tree, `configure.ac` and the build's `config.h` |
| `wnflag` delivered / not delivered by each of six spellings | **MEASURED on both binaries**, two device shapes, real numbers above |
| `-D no_spinit` does not suppress the start-up file; `-n` does | **MEASURED on both binaries** |
| `-D` survives `-n` | **MEASURED on both binaries** (`ngbehavior=hs` → `Note: Compatibility modes selected: hs`) |
| the last `-D casemode=` wins | **MEASURED on the fork** (`$curcasemode` is the fork's) |
| the `.spiceinit` search order | **VERIFIED in `src/main.c:1264-1310`** *and* **MEASURED on both binaries** — a run-directory file shadows a `$SPICE_USERINIT_DIR` one entirely |
| `source` reads the target as commands iff the path contains `.spiceinit`/`spice.rc` | **VERIFIED at `src/frontend/inp.c:1984`** *and* **MEASURED on both binaries**, three filenames |
| a `CP_LIST` reaches ngspice from the run-directory file | **MEASURED on both binaries** (`set ticlist = ( 1 2 3 )`) |
| `*` and `#` comments are accepted in that file | **MEASURED on both binaries** |
| the catalogue's `group`, `scope`, `results` columns | **still 0/247 TRANSCRIBED** — task 1's caveat stands and nothing here rests on them |
| the 16 inert reasons, the `defas` defect, the `itl*` clamps | **inherited from task 1**, re-read only where a row asserts them (`OF1`–`OF3`) |

---

## Corrections, C115 onwards

### C115 — `wnflag` is not a pre-deck option, and two of its three cited read sites are dead

Above. It refutes **issue 1438 defect 1's stated root cause**, **task 1's
receipt headline**, **`APPENDIX_ngspice_analyses.md` §3.2.1's L1 table** (which
lists `wnflag` as reachable by *"spinit, `.spiceinit` only"*) and **the crew
brief's trap table**. ⚠ **It is `scale`/C107's shape exactly, one task later**:
a row transcribed from a dossier, shipped confidently, and refuted by a
three-line probe. The difference is that this time the transcription was
*costing a user numbers*.

### C116 — `no_spinit` is not pre-deck either, so the class is 32

MEASURED on both binaries: a run with `-D no_spinit` **still read**
`<rundir>/.spiceinit`; the same run with `-n` did not. Its phase is `cmdline`
and the command-line flag is its only door. **The pre-deck class is 32** — not
the plan's 26, not task 1's 34.

### C117 — `PLAN.md` §7d's "-n refuses every pre-deck option" is refuted

MEASURED on both binaries: `ngspice -b -n -D ngbehavior=hs <deck>` prints `Note:
Compatibility modes selected: hs` and the variable is in force. `-n` suppresses
the **file** and nothing else. ⚖ **R2's own text refuses the file**, which is
what shipped; a **rule debt is filed** for the narrowing, because scoping a
ratified condition is the user's call. Refusing `-D` too would have refused a
door measured to work — C107 in a different coat — and would have deleted
`-D casemode=`, which this tree emits under `-n` today and which six rows of
`test_ase_simreg_0931` pin.

### C118 — `[R-M7]`'s reason for "copy, never `source`" is conditional on the FILENAME

`com_source` (`src/frontend/inp.c:1984`) is

```c
if (ft_nutmeg || substring(INITSTR, owl->wl_word) || substring(ALT_INITSTR, owl->wl_word))
    inp_spsource(fp, TRUE,  ...);   /* read as COMMANDS */
else
    inp_spsource(fp, FALSE, ...);   /* read as a NETLIST */
```

MEASURED on both binaries, same bytes, three names: `.spiceinit` → both
variables arrive; `spice.rc` → both arrive; `myinit.txt` → `Circuit: set
frobnicate`, `Unable to find definition of model`, variables gone — the
dossier's transcript exactly. ⚠ **A crew that tested `source` with the real name
would have concluded it works.** The requirement stands and the reason is
sharper: the mechanism turns on a substring of a path ASE-L composes.

### C119 — the six `test_ase_simreg_0931` rows the plan expected to move do NOT move

`PLAN.md` §7 and `LEDGER.md` both budget a re-baseline of **A2 / B5 / B6 / B11 /
B12 / D4** *"the first time `-D` is emitted for an option"*, with *"re-baseline
all six in one commit or five of them go red"*. **All six build the command from
an EMPTY state** (`a_runcmd` is `run_cmd {} $DECK`), which carries no pre-deck
option, so the arm contributes nothing and every one of those commands is
byte-identical. Measured after the change: `test_ase_simreg_0931` **ALL PASS
(111)** with no row touched. That is 0931's compatibility contract holding, so
the arm is pinned by **six new rows in a new section P** instead — 111 → 117 —
and the file's own floor paragraph now records why.

### C120 — `casemode` needed the `owner` the plan's own sketch gave it, and the shipped catalogue had dropped it

`PLAN.md` §7a writes `casemode {… owner casemode_batch …}`; task 1's catalogue
row has no `owner`. MEASURED on the fork: `-D casemode=preserve -D
casemode=fold` answers `fold` and the reverse answers `preserve` — **the last
one wins**. `ase::run_casemode_flag` already puts one on the command line, gated
by the B4 pre-flight that *measures* what the binary delivers; an options row
would land after it, win, and bypass the measurement entirely. ⚠ **This is a
plan claim that HELD and was lost in transcription** — the opposite failure from
C115, and worth recording for the same reason the ledger records the two that
held.

### C121 — an owned pre-deck option's `.options` card disappears, and that is arm 2 beating the fallback on purpose

`render_deck`'s door test runs before the speller, so `casemode` stored on a
bench produces **no card at all** rather than falling back. `.options
casemode=preserve` was measured to fold every name anyway and say nothing, so
keeping it would be keeping the lie §7d exists to delete. No committed bench
stores it. Row **RD9** states it as a fact rather than leaving it as a surprise.

### C122 — issue 1438 has no entry in `NUMBERING.md`

Only the superseded pointer line (`~~The next free number is 1438~~ …
superseded`) is there; the `- **1438** — …` entry every other number has is
missing. ⚠ **Added by this crew, marked as such in the entry itself.** Nothing
was reverted and nothing else in that file was touched but the 1439 entry, the
pointer, and a bracketed `⚠ CORRECTED BY 1439` clause appended to 1437's
`wnflag` sentence — which otherwise leaves a measured-false claim standing in
the tree's own index.

---

## THE SABOTAGE CAMPAIGN

**Thirty-five respellings**, each a plausible rewrite rather than a break — the
tidy-up somebody would actually make — and **eight of them reproduce a claim
`PLAN.md`, a dossier or an issue file actually makes**: S01 (§7d's *"every
pre-deck option … refused when `-n`"*), S02 (the shared-rundir refusal), S05
(the old emitter's drop-on-zero, which is issue 1438's defect 3), S22 (D19's
`source` chaining), S24 (the search order), S27 (`hidden-vars.md` §3.2's
pre-deck table listing `wnflag`), S28 (`no_spinit` as a pre-deck variable), S30
(the shipped emitter's own loop).

Restore was `cp` from `/tmp/s7t2/sab/good_ase.tcl` with an **md5 compare after
every application**; the campaign aborts on a restore mismatch rather than
continuing; anchor uniqueness was checked against the pristine file **before**
the campaign started (**35/35 unique**); and **no source file was edited while a
campaign was live**. Every application ran **four** suites —
`test_ase_predeck_1439`, `test_ase_options_1437`, `test_ase_simreg_0931` and
`test_ase_core`, the last because `render_deck` is in the blast radius.

**Seventy-six applications in all** — 35 on the first tree, 3 survivor re-runs,
35 again on the final tree, 3 more re-runs after row RD13 was added —
**76/76 restored, ZERO KILLS, and on the final tree 35/35 redden at least one
NAMED row with ZERO SURVIVORS.**

| # | the respelling | rows reddened |
|---|---|---|
| S01 | predeck_plan: -n refuses the command line too, as PLAN.md 7d literally says | CM3 RF4 0931/P5 |
| S02 | predeck_plan: the shared-rundir refusal is dropped -- a bench almost always names one | HK5 RF1 RF5 |
| S03 | predeck_plan: an owned option is planned like any other -- the owner column is advisory | OW3 |
| S04 | predeck_plan: a switched-off pre-deck flag writes its absence as a zero | PD6 |
| S05 | predeck_plan: a value of 0 is dropped, exactly as the old emitter dropped it | PD7 |
| S06 | predeck_plan: a refused option is skipped -- the GUI disables the field anyway | RF1 RF3 RF5 |
| S07 | rundir_is_shared: compare the resolved path rather than the state key | **RF2b** |
| S08 | predeck_argv: the spelled line goes through whole, not split into words | CM2 CM3 PD8 0931/P2 0931/P3 0931/P5 |
| S09 | predeck_deliver: a backend with no hook falls back to the one writer there is | HK1 HK2 |
| S10 | predeck_deliver: only call the writer when there is something to write | HK5 |
| S11 | predeck_report: the shadow clause is always appended | UF7 |
| S12 | opt_owner: a row that carries the key is owned, whatever it says | OW1 OW2 OW3 OW4 |
| S13 | opt_offer: a clamp and a caveat are both just not-offered | OF2 OF3 OF6 |
| S14 | opt_offer: an owned row is a row not to offer | OF4 OF6 |
| S15 | opt_line: the owner refusal is dropped -- the form will not offer it anyway | 1437/CA6 CL6 OW2 OW6 OW7 |
| S16 | opt_restore_line: an owned row restores like any other | **OW5b** |
| S17 | state_option_delivery: an owned row is reported by its door, like everything else | OW4 |
| S18 | option_schema_errors: an empty owner is nothing to complain about | OW7 |
| S19 | predeck_file: name the file after the cell, like the deck and the log | FW1 |
| S20 | predeck_write: a file in OUR run directory is ours to replace | FW5 FW6 |
| S21 | predeck_write: the user's own lines go last, so their settings win | **UF4b** |
| S22 | predeck_write: chain the user's file with source instead of copying it (D19) | UF4 **UF4b** |
| S23 | predeck_write: the marker line is dropped -- the path already says whose it is | FW2 FW3 FW4 HK5 UF6 |
| S24 | predeck_user_file: the home directory is the documented place, look there first | UF3 |
| S25 | run_cmd: the bench's own words go first, ahead of ASE-L's flags | CM2 CM3 CM6 0931/P2 0931/P3 0931/P5 |
| S26 | run_cmd: the -D arm spells its own flag rather than asking the router | CM5 CM6 0931/P6 |
| S27 | catalogue: wnflag is pre-deck after all, as the dossier's own table lists it | 1437/CB6 1437/DL5 CL1 CL2 CL3 RD1 RD10 |
| S28 | catalogue: no_spinit is a variable read during start-up, so it is pre-deck | 1437/CB6 CL1 CL4 |
| S29 | catalogue: the casemode owner is dropped -- the options sheet may set it too | OF4 OW1 OW2 OW3 OW4 RD9 |
| S30 | render_deck: the old option loop, restored | RD1 RD12 RD2 RD3 RD6 RD9 |
| S31 | render_deck: a pre-deck option gets its .options card too, belt and braces | RD9 **RD13** |
| S32 | render_deck: an option the catalogue does not know is dropped -- the catalogue is the authority | RD7 |
| S33 | render_deck: an inert option is dropped, because D24 says it is never a live field | RD8 |
| S34 | render_deck: the speller answering nothing falls through to the old rule | RD12 |
| S35 | run_deck: the pre-deck delivery moves down beside the deck it describes | RN1 RN4 |

### ⚠ THREE SURVIVED PASS 1, AND ALL THREE ARE THE SAME DEFECT IN THE SUITE

*A row whose fixtures never disagree cannot fail* — the **fifteenth**, sixteenth
and seventeenth times in this batch. Each was a line whose failure mode needed a
state no fixture built, and the fix is the one the brief names: **build the
state, never delete the line.**

| survivor | why nothing moved | the row written for it |
|---|---|---|
| **S07** — `ase::rundir_is_shared` compares the resolved path instead of the state key | for both of RF2's benches the two rules give the **same** answer. The state that separates them is a bench whose `rundir` is spelled out *and* happens to be the shared directory: the fallback was not taken, the user typed that path, and refusing them there refuses a choice they made | **RF2b** — that exact bench, with a `SKIP` guard for a tree where `set_netlist_dir` is unavailable |
| **S16** — the owned-row guard in `ase::opt_restore_line` is deleted | neither owned ngspice row carries a `default`, so the proc answers `{}` two lines earlier for a different reason. The guard is what a **second adapter's** descriptor gets when its owned row does carry one — D37's paper validation exactly | **OW5b** — a stand-in backend with an owned row *and* a default, beside an unowned one that does restore |
| **S21** — the user's copied lines are appended **after** the bench's | ⚠ **the fixtures DID disagree and the row asked the wrong question.** UF4 used `lsearch -exact`, which finds the **first** copy, and asked only about an ordering. `set` is last-writer-wins, so the only thing that matters is which line is at the **bottom** | **UF4b** — the last line of the file is the bench's, and the user's appears exactly **once** |

⚠ **S21 is the one to remember, and it is a new shape for this batch.** The
other fourteen survivors across Stages 0–7 were fixtures that never exercised a
line. This one exercised the line, produced a genuinely different file, and
**passed anyway** — because the assertion was about position rather than about
the property that decides the outcome. **A row that checks an order when the
semantics are last-writer-wins is checking the wrong end of the list.**

### And one row was not enough on its own

**S31** — a pre-deck option keeps its `.options` card *as well* — reddened only
**RD9** in the first campaign, because `p_cards` filters the deck to `.options`
lines and the speller's answer for a pre-deck row in the deck slot is
`-D ngbehavior=hs`, which that filter cannot see. **A command-line flag written
into a SPICE deck was invisible to every row in the file.** Row **RD13** now
scans the whole deck slot for a `-D` or a `set` line; S31 reddens **RD9 and
RD13** on the final tree.

---

## Suites moved, before → after

| suite | headless | display (`:99`) | in T1? |
|---|---|---|---|
| **`test_ase_predeck_1439`** (new) | — → **78** | — → **78** | **yes** — added to `tests/run_regression.tcl`'s `hcases` in this change |
| **`test_ase_simreg_0931`** | **111 → 117** | **111 → 117** | **yes** (already) |
| `test_ase_options_1437` | **75 → 75**, seven rows re-baselined | **75 → 75** | **yes** (already) |
| `test_ase_core` | 598 → **598** | 598 → **598** | yes |
| `test_ase_preflight` | 235 → **235** | 235 → **235** | yes |
| `test_ase_persist` | 44 → **44** | 148 → **148** | yes |
| `test_ase_dialogs` | 37 → **37** | 299 passed / **1 FAILED** — issue **1436**, unchanged | yes (headless arm only) |
| `test_ase_simcaps_0948` | 199 → **199** | 199 → **199** | yes |
| `test_ase_optier_0963` | 108 → **108** | **TIMEOUT** — pre-existing, see below | yes (headless arm only) |
| every other ASE suite | unmoved | — | — |

**The seven re-baselined rows of `test_ase_options_1437`, each with the
measurement that moved it:**

| row | before → after | why |
|---|---|---|
| **CB6** | 34 → **32** pre-deck rows | `wnflag` (C115) and `no_spinit` (C116) were both measured out of the class |
| **DO2** | `wnflag` → `ps_use_mntymx` as the CP_NUM example | `wnflag`'s door is now `options` |
| **SP6** | `casemode` → `ngbehavior` as the CP_STRING example | the speller now refuses `casemode` (C120) |
| **SP7** | `wnflag` → `ps_tpz_delays` as the CP_NUM example | same as DO2 |
| **BR6** | *"the emitter still spells the bare card"* → *"the loop goes through the one speller, and the bare card survives only as the unknown-name fallback"* | this is the crew BR was written for |
| **DL1** | `wnflag` → `ps_tpz_delays` | the claim is unchanged; the example had to be a row really out of the deck's reach |
| **DL5** | `6 {acct list wnflag} 5` → **`1 {acct list} 0`** | ⚠ **the fix, measured over the user's own tree.** The row now says plainly that going back up is a regression |

**NO DECK GOLDEN MOVED AND NO `.state` FILE MOVED.** `render_deck`'s option loop
changed, and the only committed bench it changes a line for is a `wnflag` bench,
whose line goes from `.options wnflag` to `.options wnflag=1` — which is the
whole point and which no committed golden pins (`test_ase_core`'s D-section
goldens carry no `wnflag`, and `test_ase_core` is **598, unmoved**). No state key
was added, `ase::state_default` still seeds exactly four rows, there is no
`seed_enabled` anywhere, and `test_ase_core`'s section CP — the row that would
notice a byte in the 104 committed `.state` files — is green.

### ⚠ The two display-arm results that are NOT this change

* **`test_ase_dialogs` G2sens.** Issue **1436**, filed by the 1435 crew and not
  fixed. The actual value here — `{1 1 0 1 0 Entry Entry normal}` against
  `{1 1 0 0 0 Entry Entry normal}` — is **byte-identical to 1436's own
  transcript**. Its sibling **GG9** is no longer red, and the passing count has
  moved 283 → 299 since 1436 was written. T1 runs this file's **headless** arm
  only, where it is ALL PASS (37).
* **`test_ase_optier_0963` display arm: TIMEOUT.** Reproduced deliberately in
  260 s: **91 of 108 rows, stops after row N3**, rc 124, `FATAL: signal 15`.
  That is the stall `CLAUDE.md` and
  `doc/claude/code_analysis/a_hung_suite_and_an_unbounded_wait.md` already
  record — *"86 of 103 rows, stops after row N3"* — the one that cost a session
  8 h 07 m. Same row, same shape, and **`run_suites.sh` named it in 200 s**,
  which is that write-up's own point. T1 runs this suite **headless only**, where
  it is ALL PASS (108). ⚠ **It has a write-up and NO ISSUE NUMBER.** Not filed
  here — it is pre-existing and outside this task — but it is the only thing on
  either arm that is neither green nor already numbered.

---

## What I did NOT ship, and why

* **§7c's surface** — no options pane, no search box, no changed-only view, no
  ⚠ badge, no live deck preview, and therefore **no `look` debt**. `ase::opt_offer`
  is the answer that pane will draw; drawing it is task 3's.
* **§7e's emit-then-restore, §7f's `option`/`set` read-back, §7g's four
  `caps`-reading rules** — task 4. In particular the **`control`-door rows still
  take the old `.options` card**: `.options units=degrees` is measured to leave
  the phase in RADIANS, which is the 57.2958× error, and moving it needs an
  emission point inside `.control` that §7e owns. Row **RD8**'s neighbours pin
  the present behaviour so the day it changes the suite says so, and
  `ase::state_option_delivery` already reports every such row.
* **The `cmdline` door is planned but not emitted.** `--soa-log=<file>` is the
  one member; a stored `soa_log` is reported by `ase::state_option_delivery` as
  needing the `cmdline` door and is not written anywhere. Emitting it means
  deciding where an argv flag composes with the registry entry's own args, which
  is §7f's channel.
* **No new state key, no `seed_enabled`, no change to `ase::state_default`.**
  The 104 committed `.state` files are byte-unmoved; `test_ase_core`'s section
  CP is green.
* **No `help` text for the 190 rows outside block A** — task 1's reason stands.

---

## What this task learned that binds later stages

**A DEAD READ AND A LIVE ONE LOOK THE SAME IN A GREP.** `wnflag` has three
`cp_getvar` call sites and one of them decides a user's transistor width. The
other two are a local nobody reads and a block behind a macro nobody defines.
⚠ **A citation is a file and a line; evidence is the code between that line and
the end of the function**, plus a grep for the `#define` of whatever guards it.
Two dossiers, one issue file and one receipt all carried the same three sites,
and all four inherited the same wrong conclusion from them.

**THE PLAN'S SKETCH CAN BE RIGHT IN THE PLACE THE CATALOGUE IS WRONG.** C120 is
C100's mirror: task 1 correctly refused the plan's typed `door` column and, in
doing so, dropped the `owner` key the same sketch carried — which turned out to
be the one thing standing between an options row and the case-mode pre-flight.
⚠ **When you refuse a sketch, enumerate what it had that you are not keeping.**

**A RE-BASELINE THE PLAN BUDGETS CAN BE A ROW THE PLAN MISREAD.** §7's six-row
move was written as inevitable (*"re-baseline all six in one commit or five of
them go red"*). It never happens, because all six measure a bench that sets
nothing. ⚠ **Before paying a budgeted re-baseline, read the row's fixture** —
the cost may not exist, and if it does not, the honest delivery is new rows
rather than moved goldens.

**AND A REFUSAL CONDITION CAN BE NARROWER THAN THE PROSE THAT RESTATES IT.** ⚖ R2
refuses *the file*; `PLAN.md` §7d restates it as *"every pre-deck option and the
entire campaign mechanism"*. Implementing the restatement would have deleted a
shipped, measured, suite-pinned flag. ⚠ **Read the ruling, not the stage's
paraphrase of it** — and where the two differ, that difference is a rule debt,
not a judgement call.

---

## Rulings

⚖ **R9 — new user-facing copy, and ⚖ R2's condition-4 narrowing, filed together
as `owed.sh add rule 1439`** at the moment it was incurred, pointing at
`doc/claude/issues/1439-*.md`:

1. the **two pre-deck refusals** — *"this bench names no run directory, so the
   file would go in one shared with every other cell; set a run directory
   first"* and *"the simulator entry is set to skip start-up files, so this file
   would be ignored in silence"*;
2. the **owner refusal** — *"ase: option 'X' is set by …, not here"* — and the
   two control names it quotes, *"the simulator entry's Case field"* and *"the
   simulator entry's -n flag"*;
3. the **three report sentences** — *"option 'X' will not reach the simulator:
   …"*, *"pre-deck settings for this run are in <path>; it shadows <path> for
   this run"*, *"<path> was not written by ASE-L, so it was left alone and
   nothing was written into it"*;
4. the **run-directory file's own banner lines**, which a user will read in
   their run directory;
5. ⚠ **the narrowing of ⚖ R2's condition 4 to the file half** (C117). The
   measurement is in the issue file; the shape implemented is the ruling's own
   wording; the user's to confirm.

**NO `look` DEBT.** Nothing in this task draws a pixel: it is a plan, a file
writer, a command-line arm and an emitter branch. §7c owns the pane and owns
that debt.

⚖ R2 is **answered** and its four conditions are rows. ⚖ R3 is **answered**. ⚖ R4
is **open** and nothing here is gated on it — nothing was seeded and no
`seed_enabled` was added.

⚠ **THE LEDGER WAS BACKED UP FIRST**, per `CLAUDE.md`'s one-ledger-every-clone
paragraph, to `/tmp/s7t2/owed_backup/xschem_owed` (**156 rule / 57 look / 9
suite** at the time); after the add it reads **157 / 57 / 9**. Measured
immediately before the add: `/usr/bin/grep -L '^repo:'` over the three
directories prints the **same four unstamped entries** issues 1430–1437 have each
reported (`rule/1357`, `rule/1357@xschem-claude`,
`look/hier_pdf_nav_1357_H6.1789071932.2875683`,
`suite/test_hier_pdf_links_1333`), and the stamp split is **205 this clone / 13
op-wcard**. ⚠ The op-wcard count has now been **13 across seven receipts** while
this clone's has moved 197 → 199 → 200 → 202 → 204 → 205 → 206.

---

## For the driver

* **T1 was NOT run by this crew** (issue 0990 — the driver runs it solo). ⚠ **T1's
  membership changed in this commit**: `tests/run_regression.tcl`'s `hcases`
  gains `headless/test_ase_predeck_1439`, so T1 now runs **78 + 6 = 84 more
  checks** than it did at `9dcf78b8` (78 from the new suite, 6 from
  `test_ase_simreg_0931`'s new section P). Nothing else in that file moved.
* **Nothing was committed, added, stashed, restored, cleaned or pushed.** No
  `git checkout --`, no `git restore`, no `git stash`, no `git clean`, no
  `git commit`, no `git push`, no PR. The working tree is the one handed over
  plus **five modified files** (`src/ase.tcl`,
  `tests/headless/test_ase_options_1437.tcl`,
  `tests/headless/test_ase_simreg_0931.tcl`, `tests/run_regression.tcl`,
  `doc/claude/issues/NUMBERING.md`) and **three new ones**
  (`tests/headless/test_ase_predeck_1439.tcl`, the issue file, this receipt).
  The four untracked paths inherited at `9dcf78b8` — `.xschem/`,
  `doc/claude/rdw_lists_batch/`, `doc/claude/rdw_sim_batch/`,
  `sky130A/.../debug_st1/` — are untouched.
* **`NUMBERING.md`'s pointer was advanced 1439 → 1440** in the same change as the
  entry. **Both mint checks were run at the moment of minting**: the
  reserved-band scan over this clone's head table (**silent** for 1439) and
  `ls ~/dev/*/doc/claude/issues/1439-*` plus `/usr/bin/grep -lw 1439` across
  **every** clone's `NUMBERING.md` (`~/dev/xschem-claude` and
  `~/dev/xschem-op-wcard`, the glob verified non-empty) — only this clone's own
  pointer line came back.
* ⚠ **TWO OTHER EDITS TO `NUMBERING.md`, BOTH DELIBERATE AND NEITHER A REVERT.**
  (1) **Issue 1438 had no entry** — only the superseded pointer line. One was
  added, and the entry says in its own text that this crew added it. (2) The
  **1437 entry's `wnflag` sentence** carried the claim C115 measures false; a
  bracketed `⚠ CORRECTED BY 1439:` clause was appended rather than the sentence
  rewritten, so the original reading and the correction both stand.
* ✅ **BOTH ARMS AGREE ON EVERY SUITE THIS CHANGE TOUCHES**: predeck_1439
  **78 / 78**, options_1437 **75 / 75**, simreg_0931 **117 / 117**, core
  **598 / 598** — taken through `tests/headless/run_suites.sh`, which reported
  *"display arm: ATTACHED to persistent dev display :99 (devdisplay.sh),
  GUI_GATE=0"*; `devdisplay.sh status` before and after: alive, **openbox
  (Openbox 3.6.1)**, `1920x1080x24`. There is no widget in the new file, so the
  arms are expected to agree and the counts say they do.
* ✅ **AND IT WAS PROVEN END TO END, ON BOTH BINARIES, THROUGH ASE-L'S OWN
  ARTIFACTS.** Not a unit row — the three files ASE-L actually produces, handed
  to `/usr/bin/ngspice` (45.2) and the fork (`ngspice-46+`) in a scratch run
  directory under `/tmp`:

  | leg | the artifact | measured |
  |---|---|---|
  | **A** | the deck `render_deck` renders for a bench storing `{name wnflag value 1}` | `"@m1[vth]" = 5.888996e-01`, `i(vd) = -1.73730e-03` — against `9.888996e-01` / `-1.01728e-03` for the same deck with the old `.options wnflag` line. **Identical on both binaries.** |
  | **B** | the file `predeck_write` writes, with a user's own `.spiceinit` copied into it | run from a foreign cwd: `wnflag` in force (vth 0.5889); move the file away and it is 0.9889. The user's `frobnicate` and `uservar 7` are **both still in `set`'s dump**, beside `wnflag 1`. **Identical on both binaries.** |
  | **C** | the command `run_cmd` builds for a bench storing `{name ngbehavior value hs}` — `ngspice -b -D ngbehavior=hs <deck> 2>@1` — executed verbatim | `Note: Compatibility modes selected: hs`. **Identical on both binaries.** |

  The file ASE-L wrote, in full:

  ```
  * ASE-L pre-deck settings -- rewritten every run, deleted every run
  *
  * copied from /tmp/s7t2/e2e/fakehome/.spiceinit -- this file shadows it for this run
  set frobnicate
  set uservar=7
  *
  * set by this bench -- last, so the bench wins
  set wnflag=1
  ```
* ⚠⚠ **`$HOME/.spiceinit` WAS NEVER WRITTEN, MOVED, BACKED UP OR READ-MODIFY-
  WRITTEN, AND THERE IS NONE.** Measured at the start: `ls -la ~/.spiceinit` →
  *No such file or directory*, `SPICE_USERINIT_DIR` unset. Every "user file" in
  every probe, row and end-to-end leg was a file **this crew created** under
  `/tmp/s7t2/` or under the suite's own scratch tree, reached by pointing `HOME`
  or `SPICE_USERINIT_DIR` at it for the duration of the call and restoring both
  afterwards. `ase::backend::ngspice::predeck_user_file` opens nothing;
  `predeck_write` opens the user's file `r` and never `w`. **Nothing under
  `~/.xschem/` was touched** beyond `geometry` — see below.
* ⚠ **`~/.xschem/geometry` WILL HAVE BEEN WRITTEN AGAIN** by the display arm —
  issue **1397**, already on the user's queue and already reported by the 1430,
  1432, 1433, 1434, 1435 and 1437 crews. Every headless invocation here carried
  `--nogui`. The repo's own `.xschem/op_param_lists.conf` is unmodified.
* ⚠ **AND NOTHING HERE CALLS `ase::sim_register`.** Registration **persists**
  (`ase::sim_touch` → `ase::sim_write_conf` → `~/.xschem/ase_simulators`), so the
  new suite stubs `ase::sim_nospiceinit` for the two rows that need `-n` and
  clears the in-memory registry at the top with `ase::sim_clear`, which writes
  nothing. The clear is not decoration: **six rows reddened on a clean tree
  before it was added**, because the developer's own saved entry carries `-n`.
* ⚠ **NO SIMULATOR WAS STARTED BY ANY SUITE, BUT ~45 PROBES AND THREE END-TO-END
  LEGS WERE RUN, ON BOTH BINARIES.** All of them on scratch decks under
  `/tmp/s7t2/` with that directory as cwd. **No bench under `sky130A/` was run**
  and no simulation touched `~/.xschem/`.
* **Machine rules honoured throughout**: every xschem invocation was given a path
  (`./src/xschem`) and `--nolog`, never `--logdir`, never a bare `xschem`; every
  bespoke command carried a `timeout` and every waiting loop a deadline that
  announced itself; **a stall was a named outcome** (`TIMEOUT`, rc 124) and never
  an absence; `tests/run_regression.tcl` was not run.
* ⚠ **`/tmp` carries fifteen `xschem_emergencysave_bandgap_*` directories**, two
  of them created by this task's `test_ase_optier_0963` display-arm timeouts
  (SIGTERM's emergency-save path) and thirteen predating it. **Nothing was
  deleted** — they are outside the repo and not this crew's to clean.
* ✅ **THE WHOLE ASE FAMILY WAS RUN HEADLESS TWICE — once before the emitter was
  rewired and once on the final tree — with identical results**: **29 PASS**, 2
  self-skips (`test_ase_dirty`, `test_ase_log_seam_0207`, each of which says in
  its own first line that it needs an X connection) and **1 known red**,
  `test_cosim_golden_e2e` 45 passed / 1 failed, row **GE24**, issue **1431**, the
  one-timestep VCD boundary — unchanged, and not in T1.
* **No file was created in the repo root**, and `git status` carries no stray.
* **The next task is 3 of 4 — `PLAN.md` §7c**, the options surface. It inherits:
  `ase::opt_offer` is the answer its *not offered / clamp / caveat* rendering
  draws; `ase::state_option_delivery` and `ase::predeck_plan` are what the
  *"Applied before the netlist is read"* group and the ⚠ per-row warnings read;
  and the live deck preview has, for the first time, three places to show a line
  **and a proc that says which** — the deck, the command line and the
  run-directory file. ⚠ **It is the only one of the four tasks that draws a
  pixel, so it owns the plan's largest `look` debt, and task 1's warning stands:
  the 21 `results 1` rows its ⚠ badge rests on are still 0/247 verified.**
