# 1490 — a space in the checkout path reds 71 rows across five suites

**STAMP:** `v1 claim=fixed tree=a1314271 stamped=2026-09-20 fix=taken open=3 by=C-docs`

**Status: FIXED 2026-09-20 in `a1314271`** (stranger-reds batch, item C: one implement
round, one adversarial verify, one fix round). The mechanism this file called READ is now
**TRACED** — word splitting at the first space, measured on two ngspice builds and
confirmed against `inp_readall` in ngspice's own `src/frontend/inpcom.c` — and the fix is in
`src/ase.tcl`, not in the suites. **It is one defect with issue 1484**, and the same change
closes both. Read "What item C measured and fixed" at the foot of this file.

⚠ **THE HEADLINE NUMBER IN THE TITLE IS WRONG, AND THE CORRECTED ONE IS LARGER.** This file
could not name its rows and said so. Item C named them: **147 rows across 17 suites**, not
71 across five, measured on a full `test_ase_*` sweep. The title is left alone because the
number is the identity; the list is in §2 below, which discharges fix-direction step 1.
Note that **many of the 147 are not this defect** — §3 says which, and why.

`open=3` counts the list under "Still open after item C", none of which is this defect.

**Filed 2026-09-20** by the stranger-reds batch, from item A's adversarial
verifier (finding **R6**), under batch decision **D4**: a finding outside the item being
worked is written down and filed, never fixed on the way past.
**Class** stranger-facing false red in T1, with a **product** defect underneath it that a
user can hit without running a test at all.
**Related: issue 1484**, which is the same class measured with an uppercase letter instead
of a space. Read the two together; see "Why this is not filed as a duplicate of 1484".

---

## What happens

Unpack the ZIP, or clone the repository, into a directory whose path contains a **space** —
`~/Downloads/xschem stuff/`, `/mnt/c/Users/Jane Doe/dev/`, `~/Documents/My Designs/` — and
build it. **Five suites go red, 71 rows in total, and every one of them is a
simulator-invocation row.** The same tree at a path with no space is green.

(They are presumably the ASE suites — every row is a simulator-invocation row, and issue
1484's five are all `test_ase_*` — but the receipts do not name them, so this file does not
either. "ASE" is deliberately not in its title for that reason.)

Nothing about the tree is different. The only variable is the name of a directory above it.

## What was measured, and by whom

| | |
|---|---|
| measured by | item A's `reproduce` verifier, 2026-09-20 |
| tree | `bbc9de1a` plus item A's then-uncommitted files (the fix landed as `1f3f5287`) |
| result | **5 suites red, 71 rows**, all simulator-invocation rows |
| recorded in | `doc/claude/stranger_reds_batch/receipts/A-verify.md` (finding R6) and `receipts/A-impl.md` (§F5), and `DECISIONS.md` D4 |

⚠ **The aggregate is all that survives, and that is a gap in this file rather than a
softening of the finding.** The receipts record "5 suites, 71 rows, all simulator-invocation
rows"; they do not enumerate the suites or name the rows. The per-row detail was in the
verifying crew's own logs, and the batch brief requires a crew to delete its scratch
(`CREW_BRIEF.md`, and `PLAN.md` criterion 6), so the logs are gone. **Whoever takes this
item re-measures first.** That is two builds and one loop over the suites, and it hands back
the row names this file cannot — see "Fix direction" step 1.

### Corroboration from the same class, with an uppercase letter instead of a space

Item A's implementer and its fix round both hit issue 1484 by accident, because the scratch
root they were assigned had a capital `A` in it — one directory name apart, **same commit,
same binary, same fresh throwaway HOME, same `AUDIT_DISPLAY=none`**:

| export built at | `test_ase_variant_1470` | `test_ase_sp_1452` |
|---|---|---|
| path with an uppercase `A` | `OT1` **FAIL** | `SE1/apt` **FAIL**, `SE1/fork` **FAIL** |
| the all-lowercase sibling | `OT1` **ok** → `ALL PASS (76)` | `SE1` **ok** → `ALL PASS (58)` |

Those two rows belong to issue **1484**, and they are now measured rather than inferred —
1484 records that. They are quoted here because they are the cheapest existing evidence that
the *class* is real: the checkout path reaches a simulator invocation, and the simulator
does not get the path back.

⚠ **The two sightings are not equally strong.** The implement round's is the clean one: two
trees, each built from scratch at its own path. The fix round's is a `cp -a` of a tree built
elsewhere, so it corroborates and does not repeat the experiment. Both are recorded in
`receipts/A-impl.md` §7.1 and `receipts/A-verify.md` R6, which say so themselves.

## Why it happens — the mechanism, READ from the code and not traced

`sp_export_lines` in `src/ase.tcl` (namespace `::ase::backend::ngspice`) returns the three
ngspice control lines of one S-parameter row. The middle one is built by string
interpolation:

```tcl
return [list "let Rbase = $rb" \
             "wrs2p [s2p_file $state $idx]" \
             {unlet Rbase}]
```

`s2p_file` in the same file builds an **absolute** path — `file join [::ase::rundir $state]
<cell>_ase_sp<idx>.s2p` — so the checkout path is inside the word, and the word goes onto an
ngspice control line **unquoted**. A space splits it into two arguments there. That is a
word-splitting defect, and it is a plainer explanation than the lowercasing that issue
1484's uppercase variant was attributed to.

⚠ **Stated as it is known.** The interpolation and the absolute path are a **READ of
`src/ase.tcl`** and are certain. That the split is what reddens these 71 rows is
**INFERRED** from the red/green split of two otherwise identical trees. Nobody has yet run
ngspice by hand with a spaced path, captured the deck, and looked at where the file landed.
Do that before writing a fix — and do not assume that the other suites in the red set share
this one call site.

## Why this is not filed as a duplicate of 1484

1484's title, and the whole of its measured set, is *"an uppercase letter"*: five suites and
**18** counted lines. This finding is a **space** and **71** rows. Same class, probably the
same cause, and **nobody has shown they are one bug** — that is the first thing to settle,
not something to assume by filing them as one number. Filing them together would also bury
the larger reproducer inside a file whose name says "uppercase". 1484 has been widened to
name the mechanism and to point here; if the measurement in step 1 shows one cause, close
this one into 1484 then, with the evidence in hand.

## Why a user cares, and not only a tester

The rows are tests, and the defect they trip over is not test-side. If the mechanism above
holds, then **any user whose project lives under a path with a space in it gets an
S-parameter export that silently lands somewhere else, or nowhere** — with no error, because
ngspice took a truncated word as the filename and wrote what it was told. On this platform
the shape is not exotic: `/mnt/c/Users/<First Last>/` is the ordinary Windows home seen from
WSL, and `~/Documents/My Designs/` is what a person actually types.

That widens issue 1484's own product claim from *"a capital letter"* to **"a path the
ngspice control line cannot take literally"**, which is the sentence both files now carry.

## Fix direction

1. **Measure it, and name the rows this file cannot.** Two clones of the same commit, both
   built, one at `…/sp space/` and one at `…/spspace/`; run the ASE suites through the armed
   driver and diff the verdicts. Record the five suite names and the 71 row ids in this
   file. Then run the S-parameter export by hand in the spaced tree, keep the deck ngspice
   was given, and look at what was written and where — that is the step that turns the
   mechanism from READ to TRACED.
2. **Fix it where the deck line is built**, not in the suites. The argument to `wrs2p` needs
   whatever quoting or escaping ngspice's control-line parser actually honours — check that
   before choosing, because a quoted word that ngspice takes *literally including the
   quotes* is a second defect wearing the fix's clothes.
3. **Sweep for siblings.** `wrs2p` is one interpolation onto one control line. Any other
   place in `src/ase.tcl` that interpolates a path into a control line has the same defect
   whether or not a test currently reaches it.
4. **Add a T1-visible row** that a regression cannot walk past: a run directory whose name
   contains a space (and one with a capital), whose export must round-trip. Until such a row
   exists, this defect is invisible to every green T1 that has ever been taken, because
   every one of them ran at a path with neither.

## Still open as this file was filed (4) — all four are now answered, see the foot of the file

1. The five suites and the 71 rows are not named anywhere — re-measure (step 1).
2. The mechanism is READ, not traced: no deck captured, no ngspice run observed (step 1).
3. No product fix for the unquoted control-line path (steps 2 and 3).
4. No T1-visible row, so nothing catches a regression or a recurrence (step 4).

## Evidence

`doc/claude/stranger_reds_batch/receipts/A-verify.md` — finding **R6** (the aggregate, the
rejection for item A, and the mechanism); `receipts/A-impl.md` §7.1 (the uppercase pair,
measured twice) and §F5; `doc/claude/stranger_reds_batch/DECISIONS.md` **D4**.
Code: `sp_export_lines` and `s2p_file` in `src/ase.tcl`.

---

# What item C measured and fixed — 2026-09-20, stranger-reds batch, `a1314271`

Sources: `doc/claude/stranger_reds_batch/receipts/C-impl.md` (§1–§9 and **FIX ROUND**
§F1–§F9), `receipts/C-verify.md`, and `DECISIONS.md` **D7** and **D8**.

## 1. The mechanism is TRACED — word splitting, measured

**MEASURED** — decks written by hand, ngspice run, the filesystem looked at afterwards — on
**`/usr/bin/ngspice` 45.2** and on the ASE registry's fork
`/home/analog/dev/ngspice/build-ver_50/src/ngspice` (**46+**), with identical results on
both, and **re-traced from scratch** by the adversarial verifier (`C-verify.md` §1.1:
*"The receipt's table is correct row for row"*).

> **The space face is word splitting.** `wrs2p /var/tmp/xsr_c/tr/w s/out.s2p` wrote a
> complete 653-byte Touchstone file to `/var/tmp/xsr_c/tr/w` — a **file** where the user has
> a **directory** — at rc 0 with nothing said. `com_write_sparam` takes `wl->wl_word`, the
> first word, and the redirection parser takes the first word after `>`/`>>`.

**Every one of the ten control lines splits**, whitelisted or not — `write`, `wrdata`,
`echo … >>`, `print … >>`, `eprvcd … >`, `set >>`, `meas … >>`, `wrnodev`, `wrs2p`, and
`shell mv -f` (*"splits, and single quotes do NOT help"*). That is the difference from the
capital face, which touches only the four commands off ngspice's whitelist: **the space face
is strictly larger, which is why this file's row count is strictly larger than 1484's.**
Both are the same word reaching the same parser (`DECISIONS.md` **D7**).

The verifier's own independent run: `wrs2p …/tr/w s/o.s2p` plus `write …/tr/w s/o.raw`
wrote **ONE file `…/tr/w`, 652 B, rc 0, nothing on stderr**.

### This file's step-2 warning was right, and it was proved

*"a quoted word that ngspice takes literally including the quotes is a second defect wearing
the fix's clothes"* — measured: `wrs2p "<path>"` in a directory with **neither** a capital
nor a space gives *`"/tmp/plain/b.s2p": No such file or directory`*, and the verifier re-ran
it as *"**rc 0, not one file written**, on both binaries"*, for `write`, `wrnodev` and
`wrs2p` alike. What works is `setcs v = '<path>'` then `$v` — `setcs` is on ngspice's
case-folding whitelist, single quotes make the value one word, and `$v` expands **after**
the reader has folded the line it sits on. The `shell` line needs the **opposite** quoting
(`setcs p = '/x/w s/a' … shell mv -f "$p" "$q"` → MOVED; bare and single-quoted → NO MOVE).

## 2. The rows, named — 17 suites, 147 rows. This discharges step 1.

Method (`C-impl.md` §2): three trees at `/var/tmp/xsr_c/{plain,Cap,w s}/x`, each a `cp -a`
of the repository at `0eed8a1b` with its own build in place, **each run from its own tree so
the checkout path is the variable**, all 44 `test_ase_*` suites through
`tests/headless/run_suites.sh --nogui` with `AUDIT_DISPLAY=none`. Cross-checked against a
second experiment — one tree, three `XSCHEM_TEST_SCRATCH` values — *"which reproduced the
capital list identically and the space list to within the rows that only a checkout move can
reach."*

| suite | n | rows |
|---|---|---|
| `test_ase_campaign_1462` | 7 | `RN12` `EE2/apt` `EE3b/apt` `EE7/apt` `EE2/fork` `EE3b/fork` `EE7/fork` |
| `test_ase_campaign_gui_1464` | 4 | `RR1b` `RR5` `EE2/apt` `EE0` |
| `test_ase_converge_1459` | 2 | `EE5/apt` `EE5/fork` |
| `test_ase_core` | 5 | `E1a` `E1b` `E1c` `E1f` `CK11` |
| `test_ase_cosim` | 2 | `HI21-stale-artifact-deleted` `AT17-last-vcdfiles` |
| `test_ase_events_1465` | 15 | `CI2` `CI3` `CI6` `CI8` `EM5` `EE3/apt` `EE4/apt` `EE5/apt` `EE6/apt` `EE10/apt` `EE3/fork` `EE4/fork` `EE5/fork` `EE6/fork` `EE10/fork` |
| `test_ase_final` | 13 | `F9`×2 `F10` `F18`×3 `F13`×2 `F14` `F15` `F16` `F17` `F21` |
| `test_ase_final_gf180` | 3 | `G9`×2 `G10` |
| `test_ase_optier_0963` | 15 | `A1` `A2` `B1` `B4` `M1` `R1` `R3` `R4` `ACC1` `ACC2` `Z6` `X1` `X2` `X3` `X7` |
| `test_ase_preflight` | 3 | `PF218g-…` `PF220-…` `PF220e-…` |
| `test_ase_print_bracket_0167` | 2 | `PB12` `PB12b` |
| `test_ase_simcaps_0948` | 40 | `Z2` `Z3` `B1` `B2` `B4` `B5` `B6` `B9` `B10` `C2` `D1` `D2` `D3` `D4` `D5` `D6` `D10` `D11` `F1` `F2` `F4` `F9` `G4` `G6` `J7` `J11` `J12` `K1` `K2` `K4` `K5` `K5b` `K5c` `K5e` `K5h` `K6` `M2` `N1` `N7` `XE11` |
| `test_ase_simchoice_1395` | 1 | `B1` |
| `test_ase_simreg_0931` | 9 | `A4` `E3` `E6` `E8` `E10` `E13` `R8` `R8b` `S6` |
| `test_ase_sp_1452` | 6 | `SE1/apt` `SE2/apt` `SE1/fork` `SE2/fork` `SE3/apt` `SE3/fork` |
| `test_ase_trnoise_1466` | 18 | `EE1..EE6/apt` `EE1..EE6/fork` `EC2..EC4/apt` `EC2..EC4/fork` |
| `test_ase_variant_1470` | 2 | `OT1` `M21b` |

The receipt states plainly why the two figures cannot be reconciled:

> **147, not 71.** 1490 recorded 71 from a crew that was not looking for this; the difference
> is the arm and the suite set, and the receipt that carried the 71 is gone, so the two are
> not reconcilable. Take **147/17** as the measured figure for a full `test_ase_*` sweep on
> the `--nogui` arm at this commit.

⚠ **One correction to the census itself, made by the fix round** (`C-impl.md` §F3, finding
`C2`): `test_ase_core` in a space **checkout** is `671+4` (`E1a` `E1b` `E1c` `E1f`), where
§5's first table had recorded `675`. A space **scratch** does not reproduce it, *"because
`$models` is `[file join $repo sky130A …]`"* — the checkout has to move.

## 3. What the fix greened, and what stayed red for other reasons — quoted

`C-impl.md` §5, the space tree:

> **Issue 1490's space tree: 57 rows greened and ZERO newly red.** Base 142 `test_ase_*`
> rows red, final 85; the set difference in the other direction is **empty**. The 103 that
> remain (including the ten non-ASE suites) were every one of them red on the base and are
> other defects.

**The 103 are not this call site.** They are the same *class* — a path something cannot take
literally — in code this item does not own:

* `test_ase_simcaps_0948` (40) and `test_ase_simreg_0931` (9): *"shell stand-ins and registry
  fixtures whose own paths break"*.
* `test_cosim_golden_e2e` (14) and `test_op_annot` `XR1`–`XR4` (4): *"Icarus/ngspice
  invocations"*.
* `test_ase_trnoise_1466` (18): confirmed by the verifier as *"18 FAILED on the fix and 18
  FAILED on `HEAD`"*.
* `test_ase_events_1465` `CI2` `CI3` `CI6` `CI8`, and `test_ase_core` `E1a` `E1b` `E1c`
  `E1f`: the **`.include`/`.lib`** class — the user's own PDK cards, which fail **loudly**
  (rc 1) rather than landing elsewhere. That is now issue **1496**.
* `test_ase_optier_0963` `A1` `A2` `ACC1` `ACC2` and the rest: *"end-to-end rows whose
  fixtures do not survive a space."*

⚠ **One attribution in the implement round was WRONG, and the fix round refuted it by
measurement** (`C-impl.md` §F4.1). §7.1 had filed `test_ase_converge_1459 EE5` under the
`.include`/`.lib` class. It is not: `EE5` is **ASE-L's own** `opstate` `force` `.include`,
and reverting only that one fix takes `test_ase_converge_1459` in a space tree from
**ALL PASS (77)** to **4 FAILED** — `WR4b`, `WR4b2`, `EE5/apt`, `EE5/fork`. It greens on one
conditional pair of quotes.

## 4. The product defect — steps 2 and 3, answered

`C-impl.md` §F2.1: one bench through `ase::backend::ngspice::render_deck`, ngspice 45.2, six
artifacts, three run directories differing only in name, **rc 0 in all six runs**.

| run directory | base (`HEAD`) | fix |
|---|---|---|
| `plain` | 6 of 6, correct | 6 of 6 |
| `Cap` | **3 of 6** — three artifacts in **`cap/`** | 6 of 6 in `Cap/`, sibling empty |
| `w s` | **1 of 6** (the deck, which Tcl writes) — every simulator artifact collapsed into ONE 832-byte file `…/w` | 6 of 6 in `w s/`, nothing beside |

This file's own sentence — *"an S-parameter export that silently lands somewhere else, or
nowhere"* — was true and **understated**: at a spaced path **every** simulator artifact
collapses onto one file, *"each clobbering the last"*. A user under `~/Documents/My Designs/`
loses the results file as well as the export.

**The sweep for siblings (step 3) was done and it found eleven**, all in `src/ase.tcl`,
namespace `::ase::backend::ngspice`: the plotmap `echo … >>` (×2), the results `write` (×3),
the meas sidecar, `eprvcd … >`, `wrs2p`, `set >>`, `wrnodev`, and the checkpoint block's
`write <tmp>` + `shell mv -f <tmp> <final>`; the fix round added the `opstate_lines` `force`
`.include` and `ase::op_dump_reachable_dir`. Two of them were worse than `wrs2p`:

* **The checkpoint block, which neither issue named.** *"With a space in the run directory
  the checkpoint was written to a file named after the **truncated** word and then not moved
  at all — so a Stop salvaged **nothing, silently**, which is the one outcome that block
  exists to prevent."* Row `CK11`, *"red on the base in a space tree and nobody had
  attributed it"*.
* **The `opstate` `force` restore**, measured end to end on both binaries (`C-impl.md`
  §F1.2): a `w s` run directory gave **rc 1** and **no raw file at all** —
  *"`Error: Could not find include file /var/tmp/…/w`, `fatal error in ngspice, exit(1)`"*.
  *"A user with a space in the run directory who ticks force-restore **loses the entire
  run**, loudly but with nothing salvaged."* The path is ASE-L's own, *"so there is no PDK
  to ask anyone to rename"*.

**The escape is emitted only where it is needed** — a path already safe as a bare word is
still written bare, so an ordinary bench renders the same deck, with the cell-name caveat
below. Four characters (`$`, backquote, `{`, `}`) and the five control characters survive no
encoding and are now **refused by name**; measured that none of them ever worked bare either.

### ⚠ The CELL NAME is a trigger, and neither issue names it

`C-impl.md` §F2.2, all-lowercase run directory, cell `LACGbench`, rc 0 both times: `HEAD`
wrote three of six artifacts as `lacgbench_ase.*`; the fix wrote all six as asked. *"my
cell"* — a cell name with a space — does the same through the splitting face
(`C-verify.md` §3). This repository contains a cell named exactly `LACG`. Row `CP7`.

## 5. The T1-visible rows — step 4, answered

`test_ase_sp_1452` **is** a T1 case (`hcases` in `tests/run_regression.tcl`), so the space
and capital conditions are visible to a regression for the first time. New rows: `CP1`–`CP7`,
`CP5b`, `CP5c` (`test_ase_sp_1452`), `CM1`/`CM2` (`test_ase_meas_1443`), `EV1`
(`test_ase_events_1465`), `WR4b2` (`test_ase_converge_1459`), `X4b`
(`test_op_dump_altshow`, not a T1 case). `CP6` runs the simulator against a directory with a
capital, one with a space and a plain control, on both binaries, *"and asks the
**filesystem** where the Touchstone export and the results file landed and whether anything
landed beside them"*; its red output names the cause itself —
*"`{0 0 0 beside/cp}` for the spaced one (the **truncated word**)"*.

Non-vacuity measured, not asserted: eleven sabotages (`C-impl.md` §8) and six
revert-one-change runs (§F4). `S2` (revert the results `write`, space tree) reds `CP2` `CP3`
`CP6`×6 `SE1`×2 `SE2`×2 `SE3`×2 — **14 rows**; `S7` (revert `eprvcd`, space tree) reds 13;
`S11`/`S12` (the two checkpoint halves, space tree) each red `CK11`.

**Gate:** T1 solo, `DISPLAY` set, `T1-RUN-END … cases=87 blocks=86 counted_failures=0
elapsed=525s`, 87 `Start` / 87 `Finish`, `wc -l` 177, zero `another regression run is live`.

## Still open after item C (3) — none of them is this defect

1. **`.include` and `.lib` cards from the user's own PDK setup** still fail on a path with a
   space, **loudly** (rc 1). Filed as issue **1496**. It is the direct cause of
   `test_ase_core` `E1a` `E1b` `E1c` `E1f` and `test_ase_events_1465` `CI2` `CI3` `CI6`
   `CI8` in a space checkout.
2. **The remaining space-tree reds in fixtures and stand-ins** (§3): `test_ase_simcaps_0948`
   40, `test_ase_trnoise_1466` 18, `test_ase_optier_0963` 9, `test_op_annot` 4,
   `test_ase_preflight` 1, `test_ase_campaign_1462` 1, `test_cosim_golden_e2e` 14. Every one
   was red on the base; they are the same class in suite-side code this item does not own,
   and none is filed on its own yet.
3. **The refusal arrives as a mid-render raise** rather than through a preflight refusal tier
   (`C-impl.md` §F7.3) — a deliberate silent-loss → hard-refusal behaviour change, recorded
   and handed to the driver because where the user meets it is product design.

**Filed elsewhere, not here:** a checkout path longer than about 73 characters — issue
**1495**, same class and a different mechanism. Issue **1334** is this defect found earlier
and worked around by refusing a feature; whether that refusal is now liftable is a user
ruling, filed as a rule debt against 1334.
