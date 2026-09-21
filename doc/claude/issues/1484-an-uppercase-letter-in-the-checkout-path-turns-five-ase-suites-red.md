# 1484 — an uppercase letter in the checkout path turns five ASE suites red

**STAMP:** `v1 claim=fixed tree=a1314271 stamped=2026-09-20 fix=taken open=3 by=C-docs`

**Status: FIXED 2026-09-20 in `a1314271`** (stranger-reds batch, item C: one implement
round, one adversarial verify, one fix round). The mechanism this file called INFERRED is
now **TRACED** — measured on two ngspice builds and confirmed against `inp_readall` in
ngspice's own `src/frontend/inpcom.c` — and the product defect is fixed in `src/ase.tcl`,
not papered over in the suites. **It is one defect with issue 1490, not two**, and both are
closed by the same change. Read "What item C measured and fixed" at the foot of this file;
everything above that line is the record of what was believed before it. `open=3` counts
the list under "Still open after item C", none of which is this defect.

⚠ **The title undercounts.** Item C measured **six** suites and **12 rows**, not five —
`test_ase_optier_0963` is a sixth — and `test_op_dump_altshow` is a **seventh** that dies
rather than reds. The file name is left alone because the number is the identity.

**Filed 2026-09-18** by the outsider-fixes batch, stage F (docs crew), from
`doc/claude/outsider_fixes_batch/DECISIONS.md` D12, where it is recorded as **a new
stranger finding**. **Class** stranger-facing false red in T1, with a product defect likely
underneath it (INFERRED, see below).

**Updated 2026-09-20** by the stranger-reds batch with two measurements from item A — see
"What item A added". `open=` was re-derived from this file's own list rather than carried
forward: it read **4** then (it reads **3** now — this paragraph is the item A record, and
the stamp is the file's newest word). Two rows moved from inferred to
measured, and the trigger is now described as **a path the ngspice control line cannot take
literally** rather than as a capital letter. **Related: issue 1490**, the same class
measured with a space, which is the larger and cheaper reproducer.

---

## What happens

Clone this repository into a directory whose path contains an uppercase letter, build it,
run T1, and five ASE suites go red. The suites are the same, and fail the same way, in the
old harness and the new one.

* **MEASURED (S2a redirect study, `receipts/S2a.md`):** a variant tree named `cloneB`
  turned five suites red: `test_ase_sp_1452` (row `SE1`), `test_ase_campaign_1462`,
  `test_ase_campaign_gui_1464`, `test_ase_converge_1459` and `test_ase_variant_1470`.
  For `test_ase_sp_1452` the variable was isolated: a tree at `clonB` gave `2 FAILED`,
  and one at `clone2` gave `ALL PASS`. **For the other four, case and path length were
  not separated.**
* **MEASURED (S2c-T, `receipts/S2c-T.md`):** a T1 in a stage directory named `s2c_T`
  carried **26** counted failures. The same code in a lowercase sibling carried **8**,
  which are the DISPLAY-unset segfaults of issue 1483. The difference is **18 counted
  lines, all in the five suites above** (`test_ase_campaign_gui_1464` on both arms), and
  they were identical in the fixed tree and the unfixed base, after pid normalisation.
* **MEASURED (S2c-U, `receipts/S2c-U.md`):** under a scratch root named `s2c_U`,
  `test_ase_converge_1459` `EE5` and `test_ase_sp_1452` `SE1` were red in tree and base
  alike. Both were green under a lowercase root.

Later crews moved their clones to lowercase siblings to get a clean comparison (the S2c
regression refuter's `s2cv2`, the R3 prover's `r3p`). The S2c safety refuter stayed at its
assigned uppercase path and saw the same reds, identical per case in tree and base
(`receipts/S2c_refute_r1.md`, "Per case, tree and base are IDENTICAL").

## Why — INFERRED, not measured

`ase::sp_export_lines` in `src/ase.tcl` writes the S-parameter export into the ngspice
deck as `wrs2p [s2p_file $state $idx]`: a bare, **unquoted** path (READ). The S2a study
inferred that ngspice lowercases an unquoted word on that control line, so the file is
written to a path that does not exist when the directory has capitals, and the suite's
check then finds nothing. **That is inferred from the red/green split, not read in
ngspice's source and not traced.** The mechanism for the other four suites is not
established at all, and it may be a different one.

⚠ **Read "What item A added" at the foot of this file before acting on the paragraph above.**
The unquoted interpolation is confirmed by a second reader and cited there by proc name; the
*lowercasing* half is still nobody's measurement, and a space in the path — issue **1490** —
reds far more rows than a capital does, which word-splitting explains and case folding does
not.

If the inference holds, **this is a product defect, not only a test one**: a user whose
project lives under `~/Projects/…`, `~/Documents/…`, or a home directory with a capital
in the user name would get an S-parameter export that silently lands nowhere (INFERRED).

## What it is not

* **Not the test home.** The throwaway HOME's `mktemp` suffix is mixed-case about 96% of
  the time. S2a measured 11 ASE-heavy hcases identical under a mixed-case HOME
  (`xschem-test-home.4242.QmZxKe_…`) and a lowercase control, and every later T1 ran
  green under mixed-case throwaways. The "lowercase only" rule is about paths that reach
  an ngspice control line, and the checkout is one of those.
* **Not the git-export reds (1485) or the DISPLAY-unset segfaults (1483).** Those appear
  in lowercase paths too.

## Fix direction

1. Measure it first: run `test_ase_sp_1452` in `…/caseA` and `…/casea` clones, and
   inspect the deck and the directory ngspice actually wrote into. Then quote the
   `wrs2p` argument the way the deck quotes its other paths, if ngspice accepts that.
2. Separate case from length for the other four suites before assuming they share the
   cause.
3. Add a T1-visible row: a two-character uppercase directory in the S-parameter export
   path, which must round-trip.

## Evidence

`doc/claude/outsider_fixes_batch/receipts/S2a.md` (the paragraph beginning "Confound
found and removed"), `receipts/S2c-T.md` (the per-case attribution under the T1 table,
and open problem 6), `receipts/S2c-U.md` (deviation 2).

---

# What item A added — 2026-09-20, stranger-reds batch

Two facts this file did not have. Neither is a fix; both are evidence, and the second one
changes what this issue is about.

## 1. MEASURED: `test_ase_variant_1470` `OT1` and `test_ase_sp_1452` `SE1`, by accident

Item A's implementer was assigned a scratch root with a capital `A` in it, reproduced these
two rows, moved to an all-lowercase sibling and re-measured. Its fix round hit the same
thing again from a different direction. The identical export, built twice from the same
`HEAD`:

| export built at | `test_ase_variant_1470` | `test_ase_sp_1452` |
|---|---|---|
| a path with an uppercase `A` | `OT1` **FAIL** | `SE1/apt` **FAIL**, `SE1/fork` **FAIL** |
| the all-lowercase sibling | `OT1` **ok** → `ALL PASS (76)` | `SE1` **ok** → `ALL PASS (58)` |

**Same commit, same binary, same fresh throwaway HOME, same `AUDIT_DISPLAY=none`, one
directory name apart** — and from a crew that was not looking for this defect, which is why
it is worth more than another deliberate run.

⚠ **Two qualifications, so the strength of each half is plain.** The implement round's pair
is the clean one: two trees each built from scratch at the two paths. The fix round's
corroboration is a `cp -a` of a tree built elsewhere, so it is corroboration and not a
second clean experiment. And these two rows are an observation about **case**, not about the
mechanism — nothing here traces what ngspice did.

**This also closes issue 1485's one open question.** 1485 recorded that an F21 verifier saw
`OT1` and `SE1` red in a fresh-HOME git clone while this box's full-clone control had both
green, and called the difference UNKNOWN with 1484 as an INFERRED explanation. It is this
issue, it is measured, and 1485 now says so. Those two rows are therefore **MEASURED** here;
the other three suites' rows remain as measured by S2a/S2c-T/S2c-U above, and the mechanism
below remains unproven for all of them.

## 2. The mechanism is LOCATED — and it is READ from the code, not proven

Item A's verifier went to `src/ase.tcl`. `sp_export_lines` (namespace
`::ase::backend::ngspice`) returns the three ngspice control lines of one S-parameter row,
and builds the middle one by string interpolation:

```tcl
return [list "let Rbase = $rb" \
             "wrs2p [s2p_file $state $idx]" \
             {unlet Rbase}]
```

`s2p_file`, in the same file, returns an **absolute** path —
`file join [::ase::rundir $state] <cell>_ase_sp<idx>.s2p` — so the checkout path is inside
that word, and the word reaches an ngspice control line with **no quoting at all**.

**What is measured, what is read, and what is still inferred:**

* **READ, and certain:** the interpolation is unquoted, and the interpolated value is an
  absolute path containing the checkout path. Two procs, both in `src/ase.tcl`, cited by
  name because a line number rots.
* **MEASURED:** the red/green split of two otherwise identical trees, above and in S2a/S2c.
* **STILL INFERRED, and this is the important one:** that the unquoted path is *why* those
  rows red. **Nobody has captured the deck ngspice was given, run it, and looked at where
  the file landed.** The original attribution — ngspice lowercasing an unquoted word — is
  likewise inferred, and it is *not* what the space reproducer suggests. Do not write
  "ngspice lowercases the path" into a fix commit; measure it.
* **UNESTABLISHED:** that the other four suites fail through this call site at all. They may
  not.

## 3. Consequently this is not "a capital letter" — it is a path ngspice cannot take literally

Item A's verifier also measured, in passing, that a checkout path containing a **space**
reds **71 rows across five suites**, all of them simulator-invocation rows — far more than
the 18 counted lines this file records for the uppercase case. A space splits an unquoted
word into two arguments, which is a plainer and better-understood failure than case folding,
and it points at the same unquoted interpolation.

That finding is filed as issue **1490** (it was not folded in here, because nobody has yet
shown the two are one bug, and burying the larger reproducer in a file named "uppercase"
would hide it). Taken together the two say the trigger is not a letter's case but
**a path the ngspice control line cannot take literally**.

⚠ **So the product claim widens, and it is the half a user meets.** This file already said a
user under `~/Projects/…` would get an S-parameter export that silently lands nowhere. Add
the space: `~/Documents/My Designs/`, `/mnt/c/Users/Jane Doe/…` — the ordinary Windows home
seen from WSL. **Any user whose project path carries a capital or a space is exposed**, with
no error, because ngspice wrote what it was told to write. That is a product defect, not a
test one, and it is the reason to fix the deck line rather than the suites.

## Still open as this file was filed (4) — all four are now answered, see the foot of the file

1. The mechanism is not traced: no deck captured, no ngspice run observed, nothing looked at
   where the file actually landed (fix direction 1).
2. No product fix — the `wrs2p` argument is still unquoted, and no sweep has been made for
   other unquoted path interpolations onto control lines.
3. Case and path length are still not separated for `test_ase_converge_1459`,
   `test_ase_campaign_1462` and `test_ase_campaign_gui_1464`; and whether they share this
   call site at all is unestablished (fix direction 2).
4. No T1-visible row, so every green T1 ever taken was taken at a path with neither a capital
   nor a space (fix direction 3, and issue 1490's step 4).

---

# What item C measured and fixed — 2026-09-20, stranger-reds batch, `a1314271`

Sources, and nothing here is summarised from anywhere else:
`doc/claude/stranger_reds_batch/receipts/C-impl.md` (implement round §1–§9 and **FIX
ROUND** §F1–§F9), `receipts/C-verify.md` (the adversarial verifier's §1–§5 and the fixer's
verdict table), and `DECISIONS.md` **D7** and **D8**.

## 1. The mechanism is TRACED — fix direction 1 and open item 1, answered

**MEASURED** — decks written by hand, ngspice run, the filesystem looked at afterwards — on
**`/usr/bin/ngspice` 45.2** and on the ASE registry's fork
`/home/analog/dev/ngspice/build-ver_50/src/ngspice` (**46+**), *"with identical results on
both"*, and **re-traced from scratch** by the adversarial verifier rather than read off the
implementer's receipt (`C-verify.md` §1.1: *"The receipt's table is correct row for row"*).

| control line | a capital in the path | a space in the path |
|---|---|---|
| `write <p>` · `wrdata <p>` · `echo … >> <p>` · `print … >> <p>` · `eprvcd … > <p>` | lands correctly | **splits** |
| `set >> <p>` · `meas … >> <p>` · `wrnodev <p>` · `wrs2p <p>` | **lowercased** | **splits** |
| `shell mv -f <a> <b>` | lands correctly | **splits, and single quotes do NOT help** |

**The capital face is case folding, and nothing else.** Quoting `C-impl.md` §1:

> With a lowercase sibling directory present beside `Cap/`, a deck saying `/x/Cap/f` wrote
> `/x/cap/f` — the **wrong directory**, at rc 0, with nothing on stderr. With no sibling,
> `wrs2p` says `/x/cap/o.s2p: No such file or directory` **and still exits 0**, so nothing
> downstream notices.

**The rule, READ in ngspice's source and reported as READ.** `inp_readall` in
`src/frontend/inpcom.c` (ngspice's own checkout at `~/dev/ngspice`, read-only) *"lowercases
every card in place when case folding is on (the default), **except** for a hard-coded
command whitelist"* — `write`, `wrdata`, `codemodel`, `osdi`, `pre_osdi`, `echo`, `shell`,
`source`, `cd`, `load`, `setcs`, `strcmp`, `strstr`, plus `.lib`/`.inc`, plus a separate
exemption for the token after `>` on `print`/`eprint`/`eprvcd`/`asciiplot`. **`wrs2p`,
`set`, `meas`, `wrnodev` and `show` are on neither list.** The verifier confirmed the read
independently and called it *"correct verbatim"*, citing `inpcom.c:2209-2222` for the
whitelist and `:2179-2192` for the redirect exemption — coordinates in a foreign tree that
this file does not stamp, so **read them by identity (`inp_readall`) if they have moved.**

**So: a control line whose command is not on ngspice's whitelist is lowercased in full.**
That is the capital face, and it *"predicts the measured table row for row"*. This file's
original guess (lowercasing) was right for this face; issue 1490's (word splitting) was
right for the space face; **they are the same word arriving at the same parser** (D7).

### The obvious remedy was itself a second defect — MEASURED

`wrs2p "<path>"` *"keeps the quotes **as part of the filename** and fails in a directory
with neither a capital nor a space: `"/tmp/plain/b.s2p": No such file or directory`"*, and
the same for `write`, `wrdata` and `wrnodev`. The verifier re-ran it: *"**rc 0, not one file
written**, on both binaries."* Issue 1490's own warning — *"a quoted word that ngspice takes
literally including the quotes is a second defect wearing the fix's clothes"* — is the row
that got proved.

**What works, on both binaries, for every one of the ten commands**, is `setcs v = '<path>'`
followed by `$v`: `setcs` is on the whitelist so its line keeps its case, single quotes make
the value one word, and `$v` expands **after** the reader has folded the line it sits on. The
`shell` line takes the **opposite** quoting (`setcs p = '/x/w s/a' … shell mv -f "$p" "$q"`
→ **MOVED**; bare and single-quoted → **NO MOVE**), which is why it has its own proc.

## 2. The rows, named — six suites, 12 rows (this file said five suites)

Method (`C-impl.md` §2): three trees at `/var/tmp/xsr_c/{plain,Cap,w s}/x`, each a `cp -a`
of the repository at `0eed8a1b` with its own build in place, **each run from its own tree so
the checkout path is the variable**, all 44 `test_ase_*` suites through
`tests/headless/run_suites.sh --nogui` with `AUDIT_DISPLAY=none`.

| suite | rows |
|---|---|
| `test_ase_campaign_1462` | `EE2/apt` `EE7/apt` `EE2/fork` `EE7/fork` |
| `test_ase_campaign_gui_1464` | `EE0` `EE2/apt` |
| `test_ase_converge_1459` | `EE5/apt` `EE5/fork` |
| `test_ase_optier_0963` | `Z6` |
| `test_ase_sp_1452` | `SE1/apt` `SE1/fork` |
| `test_ase_variant_1470` | `OT1` |

> 1484 named five suites; `test_ase_optier_0963` is a sixth. Of the twelve, **ten** are this
> defect and go green on the fix; `Z6` and `OT1` are not.

**Case is now separated from length** (open item 3) for all six: the capital tree is
`/var/tmp/xsr_c/Cap/x` and the green control is `/var/tmp/xsr_c/plain/x`, so the failing
path is **two characters shorter** than the passing one. *(DERIVED from the receipt's own
path names — the receipt states the paths, not this conclusion.)* Length has its own
measured mechanism and its own number: issue **1495**, `statusmsg_text` at `char[256]`,
threshold about 73 characters.

## 3. Which rows are still red in a capital tree, and why — quoted

`C-impl.md` §5, final measurement, 54 suites in three conditions on one tree,
`AUDIT_DISPLAY=none`, `--nogui`:

> **Issue 1484 is fixed.** All six suites it named are green in a capital tree with the same
> check counts as in a plain one: `campaign_1462` 161, `campaign_gui_1464` 78,
> `converge_1459` 76, `sp_1452` 69, `variant_1470` 76 (one red), `optier_0963` 109 (one
> red). The two remaining rows are **not this defect** — `Z6` and `OT1` fail
> **byte-identically on the base**, and `OT1`'s own output names the reason: `{c dumppath}`.

The fix round re-ran the three-tree census with the later edits in place (`C-impl.md` §F3):
the `Cap` column is *"green but for `OT1` and `Z6`"* and one `NORESULT`, and the `plain`
column is *"14/14 ALL PASS"*.

* **`test_ase_optier_0963 Z6`** — *"red byte-identically on base and fix in a capital tree.
  A capability-answer-changes-mid-session row; not traced."* Not this defect; carried below.
* **`test_ase_variant_1470 OT1`** — this is **issue 1334's own refusal**, not a failure of
  the escape. `ase::op_dump_reachable_dir` declines the fast operating-point dump whenever
  the run folder carries a capital or a space, and `OT1` reads the reason token
  `{c dumppath}`. The refusal is deliberate, and whether it is now liftable is a **user
  ruling**, filed as a rule debt against 1334 — see that file's 2026-09-20 section.
* **`test_op_dump_altshow`** — a **seventh** suite, found by the fix round (`C-impl.md`
  §F3.1). In a capital checkout it does not red, it **dies**:
  `NORESULT | test_op_dump_altshow (exit 0 — binary never reported)`, because the suite
  takes its own fixture dump with `show >` into a scratch carrying the checkout's capital and
  `op_annot` then raises *"no operating-point dump at '/var/tmp/xsr_c/cap/x/…/d.opinfo'"*
  — *"note the `cap` — ngspice folded it"*. **Measured identically with `HEAD`'s
  `src/ase.tcl` in the same tree**, so it is pre-existing. It is **not a T1 case**, and a
  suite death is *"the one shape a green T1 cannot see"*.

## 4. The product defect, measured outside the suites — open item 2, answered

`C-impl.md` §F2.1: one bench through `ase::backend::ngspice::render_deck`, run on ngspice
45.2, **six artifacts** (deck, plotmap, raw, Touchstone export, effective sidecar,
operating-point save), three run directories differing only in name, a lowercase sibling of
`Cap/` created on purpose so a folded write lands somewhere visible. **rc 0 in all six
runs.**

| run directory | base (`HEAD`) | fix |
|---|---|---|
| `plain` | 6 of 6, correct | 6 of 6 |
| `Cap` | **3 of 6** — `_ase.effective`, `_ase.nodeset`, `_ase_sp1.s2p` in **`cap/`** | 6 of 6 in `Cap/`, sibling empty |
| `w s` | **1 of 6** (the deck, which Tcl writes) — every simulator artifact collapsed into ONE 832-byte file `…/w` | 6 of 6 in `w s/`, nothing beside |

So this file's product claim was true and **understated**: it is not only the S-parameter
export. The verifier checked contents and not merely existence — the Touchstone export and
the `.raw` are *"byte-identical across the three shapes"* once the timestamp line is
dropped, and the deck on an ordinary path is *"byte-identical to `HEAD`'s"*.

### ⚠ The CELL NAME is a trigger, and this file never named it

`C-impl.md` §F2.2, measured at the product level in an **all-lowercase** run directory with
cell `LACGbench`, ngspice rc 0 both times: `HEAD` wrote three of six artifacts as
`lacgbench_ase.*` — *"under a name the user never asked for and nothing that reads them will
look up, **silently**"* — and the fix wrote all six as asked. **This repository contains a
cell named exactly `LACG`.** Row `CP7` pins it.

## 5. What was fixed, and the T1-visible rows — open item 4, answered

All in `src/ase.tcl`, namespace `::ase::backend::ngspice`: `path_word`, `path_quoted`,
`shell_word` and `path_bare_ok`, called from **eleven** control-line sites (the plotmap
`echo … >>` ×2, the results `write` ×3, the meas sidecar, `eprvcd … >`, `wrs2p`, `set >>`,
`wrnodev`, and the checkpoint `write <tmp>` + `shell mv -f`), plus the `opstate_lines`
`force` `.include` and `ase::op_dump_reachable_dir` in the fix round. **A path already safe
as a bare word is still written bare**, so an ordinary bench renders the deck it always did
— with the cell-name caveat above.

New rows, and `test_ase_sp_1452` **is** a T1 case (`hcases` in `tests/run_regression.tcl`),
so the capital and space conditions are now visible to a regression for the first time:
`CP1`–`CP7`, `CP5b`, `CP5c` (`test_ase_sp_1452`), `CM1`/`CM2` (`test_ase_meas_1443`), `EV1`
(`test_ase_events_1465`), `WR4b2` (`test_ase_converge_1459`), `X4b`
(`test_op_dump_altshow`, not a T1 case). `CP6` *"runs the simulator against a directory with
a capital, one with a space and a plain control, on both binaries, and asks the
**filesystem** where the Touchstone export and the results file landed."*

Non-vacuity was measured, not asserted: eleven sabotages in `C-impl.md` §8, each reverting
exactly one quoting fix, and six more in §F4 reverting each product change **on its own in
the tree that exercises it**. `S1` (revert `wrs2p`, capital tree) reddens `CP1` `CP2` `CP3`
`CP6/{apt,fork}/{cpA,cp s,cpz}` `SE1/apt` `SE1/fork` `SL4` — **12 rows**.

**Gate:** T1 solo, `DISPLAY` set, `T1-RUN-END … cases=87 blocks=86 counted_failures=0
elapsed=525s`, 87 `Start` / 87 `Finish`, `wc -l` 177, zero `another regression run is live`.

## Still open after item C (3) — none of them is this defect

1. **`test_op_dump_altshow` dies in a capital checkout** (§3 above): pre-existing, a
   `NORESULT` rather than a red, not a T1 case, and not fixed. It is this file's seventh
   suite and the only one that dies.
2. **`test_ase_optier_0963 Z6`** in a capital tree: red byte-identically on base and fix, a
   capability-answer-changes-mid-session row, **not traced**.
3. **`test_ase_variant_1470 OT1`** in a capital tree: issue **1334**'s deliberate refusal
   (`{c dumppath}`), standing until the user rules on lifting it. Not a defect of this fix.

**Filed elsewhere, not here** (PLAN.md criterion 4): `.include`/`.lib` cards from the user's
own PDK setup still fail loudly on a path with a space — issue **1496**. A checkout path
longer than about 73 characters — issue **1495**. The refusal now raises mid-render rather
than through a preflight tier (`C-impl.md` §F7.3), a deliberate silent-loss → hard-refusal
change recorded there.
