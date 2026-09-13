# Stage 6 — ⚖ R3's reader seam, and nothing else

**One commit, issue 1429, and the first of Stage 6.** Stage 5 is issues **1426** (`tf`,
commit `1e8e236e`), **1427** (`pz`, `326fe7b1`) and **1428** (`sens`, `89da8571`). Nothing
here touches any of them, or the writer, or the sidecar, or `noise`/`disto`/`sens (ac)`,
or checkpointed salvage.

**Floors:** `test_ase_core` 391 → **417** · `test_ase_simcaps_0948` 180 → **190** ·
`test_ase_result_case` 28 → **31** · `test_ase_print_bracket_0167` 12 → **14**
(`test_ase_preflight` 192 unmoved, `test_ase_dialogs` unmoved on both arms).

> ⚠ **FOOTNOTE ADDED BY THE DRIVER, 2026-09-12 — ⚖ R3 HAS SINCE BEEN ANSWERED.** The
> user ruled **Option C**: *"both with a rule is right, keep it"*. Everything below is
> left exactly as this crew wrote it, because a receipt is a dated record of what was
> known at the time; the *"recommendation"* and *"unanswered"* wording in it is correct
> for its date and stale for today. The live artefacts — `src/ase.tcl`, the four suite
> headers and issue 1429 — were corrected in place in the same driver pass.

⚠ **⚖ R3 IS ASKED AND UNANSWERED.** What ships is `DECISIONS.md`'s **recommendation**,
Option **C**, marked as a recommendation everywhere it is written down — the issue file,
the registry comments, four suite headers and this receipt. `DECISIONS.md` records R3 as
**extending** the user's own ruling in issue **1243**, not reversing it.

---

## What the stage was for, and what the tree said about it

`PLAN.md` §6e argues for reading scalars from the rawfile because it *"removes
`result_probe`'s case-folding ladder"*. ⚠ **That reason is wrong, and the real one is one
plot deeper.**

`print` reads **whichever plot the simulator is standing in**, and issue 1243 — the user's
own ruling — anchors the print lines on the operating point. Measured 2026-09-12, one
deck, prints placed exactly where `render_deck` puts them:

```
op / write / print v(mid) / print Transfer_function / print onoise_total / print r1
   / tf v(mid) V1 / write / sens v(mid) dc / write

  -> v(mid) = 1.500000e+00
  -> NOTHING ON STDOUT for the other three -- no `<name> = <value>` line, which is
     the only thing `result_probe` parses.

  ⚠ CORRECTED BY THE DRIVER. This receipt first said "no warning, no error line".
  ngspice DOES emit `Warning from checkvalid: vector <name> is not available or has
  zero length` -- but on STDERR, where no reader in this tree looks. Measured on
  /usr/bin/ngspice. The defect is that nothing PARSEABLE is produced, not that
  ngspice is silent, and the distinction matters to anyone who goes looking for
  the warning and finds it.
```

The `tf` and `sens` vectors are in the results file; they are not in the plot the prints
stand in. That is why the three analyses Stage 5 had just made choosable produced numbers
nobody could be shown. And the ladder is **not** removed: the raw reader needs a fold of
its own, because the fork writes `v(Transfer_function)` where apt 45.2 writes
`v(transfer_function)` (issue 1426's C46).

---

## What shipped

### `src/ase.tcl` — two new core procs, **schema**

| proc | what it answers |
|---|---|
| `ase::raw_scalars {path}` | every one-point number in a results file, as a **list** of `{plotname {var value …}}` pairs |
| `ase::result_source {sim ex}` | ⚖ R3's rule, and the whole of it: `raw` or `log` |

`ase::raw_scalars` sits beside `ase::cap_raw_plots`, whose header it inherits: it steps
over the numbers it is not going to use (issue 0971's rule — the user's own tb_bandgap
results file is ~69 MB with a one-point operating point at the end of it).

### `src/ase.tcl` — the adapter, inside `ase::backend::ngspice`

| proc | what it is |
|---|---|
| `result_probe_raw {state {mode fold}}` | the results-file reader |
| `result_probe_log {state logtext {mode {}}}` | **the old `result_probe`, renamed.** Body unchanged but for where `mode` comes from |
| `result_casemode {state logtext}` | the case rule's head, lifted out so both readers obey one rule and the delivered-casemode note is said once per run |
| `raw_spellings {nm}` / `raw_scalar_format {v}` | the `v(…)` wrapper the file writer adds; `%.6e` |
| `result_probe {state logtext}` | now a **dispatcher**, and still the registered hook |

**`src/ase_window.tcl` is untouched.** No registry entry changes, so
`ase::analysis_schema_errors` stays clean, row **GR8**'s declared-kind set is unmoved, and
`ase::state_default` still seeds exactly four rows — the 104 committed `.state` files are
byte-identical and section **CP** still proves it.

### The rule, stated on screen

The dispatcher says it once per run, through `ase::echo` (which reaches the CIW pane and
the action log):

```
ase: results -- a row whose expression names exactly one vector is read from the
results file; anything else is read from the print log. This run: 2 from the file,
1 from the log.
```

⚠ The counts are **computed from the rule**, never written out as prose, so a later ruling
of A or B leaves the sentence telling the truth without being edited (row **RS4b**).

---

## How C was made separable, so a later A-or-B ruling changes ONE place

C is the superset of A and B. The code is shaped so that is a fact, not a claim:

| a later ruling | what changes |
|---|---|
| **A** — results file only | `ase::result_source`'s body becomes `return raw`; `result_probe_log` is deleted whole |
| **B** — print log only | `ase::result_source`'s body becomes `return log`; `result_probe_raw`, `raw_spellings`, `raw_scalar_format` and `ase::raw_scalars` are deleted whole |

**The rule lives in exactly one proc.** The dispatcher partitions the output rows by
`ase::result_source`'s answer and hands each reader a state carrying **only its own rows**,
so neither reader knows the rule exists. Neither reader calls the other; neither reads the
other's source; neither mentions `raw_file`, `raw_scalars`, `logtext` or
`ase::result_source` outside its own half.

Three things hold that property rather than asserting it in prose:

* **RS2** — structural: seven `rg_has` probes over the two comment-stripped bodies.
* **RS3** — behavioural, and this is the one that costs something. It **performs both
  rulings**, by stubbing `ase::result_source` to one fixed answer — literally what ruling A
  (`return raw`) and ruling B (`return log`) do to that proc — and shows the whole surface
  following. ⚠ Its fixture log carries a **different** number for `Transfer_function`
  (`9.999999e+09`) from the one in the results file (`4.285714e-01`), so the row says
  **which reader answered** and not merely that a number appeared. A fixture whose two
  sources agreed could not adjudicate it at all.
* **RS3b** — the same conflict, read the other way: under C the results file's number wins
  and the log's rival is never taken.

And the two suites whose whole subject is the print log — `test_ase_result_case.tcl` and
`test_ase_print_bracket_0167.tcl` — now drive `result_probe_log` **by name**. ⚠ **The swap
is one line in each, and that is itself the evidence.** Both files' expressions (`v(In)`,
`v(MidNode)`, `v(out)`) name exactly one vector, so driving the dispatcher would have
measured the rawfile reader under their names; each gained rows that keep the dispatcher
honest instead.

---

## What the Value column shows when a run computed nothing, and why

**Nothing at all.** Not a zero, not a constant, not a stale number.

Measured 2026-09-12 on both binaries, and reproduced independently by the driver: a `sens`
filter matching nothing — and a save list resolving to nothing — **exit 0** and write a
results file whose only record is

```
Title: Constant values / Plotname: constants / No. Variables: 12 / No. Points: 1
```

`ase::raw_scalars` excludes that plot **by name**, so the reader finds no vector, records
no value, and says so on screen:

```
ase: results -- the results file holds no single-point value for v(mid), so that row
has no value: a multi-point vector is not a scalar, and a run that computed nothing
writes only the constants plot.
```

**Why that is the right answer, and not "0".** The twelve constants are `yes FALSE TRUE
boltz c e echarge i kelvin no pi planck`. A reader that took "no vector" for zero would
put a number in the Value column for a run that computed nothing — and **`i` is one of the
twelve**, so a reader that merely forgot the name test would answer for an output row
called `i`. The empty cell is also what the log reader does today for the same run
(measured: `print v(mid)` after a dead-filter `sens` prints nothing at all), so Option C
changes nothing about this case except that it now **says why**.

⚠ **That the plot is also `Flags: complex` on both binaries is a second, accidental
guard — and a sabotage proved the accidental one was carrying the deliberate one.**
Deleting the name test left `test_ase_core` at ALL PASS. Rows **RD5c** and **RV3b** exist
because of it: the same plot flagged `real` must still not be read.

⚠ **And the reader never falls back to the log.** A single-vector row whose vector is not
in the file has **no** value even when the log has a number for it (row **RD12**). A
fallback would make the on-screen sentence false and would make a later ruling of A two
changes instead of one.

---

## Every measured fact this rests on, and where it was measured

All 2026-09-12, scratch decks under `/tmp/r3probe`, **never a bench under `sky130A/`** and
nothing written under `~/.xschem/`. Binary 3 is
`/home/analog/dev/ngspice/build-ver_50/src/ngspice` (`ngspice-46+`); binary 1 is
`/usr/bin/ngspice` (`ngspice-45.2`). **Both were run.**

### 1. The print anchor is why the raw reader exists

Above. `print Transfer_function`, `print onoise_total` and `print r1`, standing in `op1`,
produce **no line at all** — not a value, not a warning, not an error. The same three
commands standing in their own plots answer normally (measurement 4).

### 2. `v(a,b)` is two vectors, and is not in the file

```
print v(in,mid)  -> v(in,mid) = 1.714286e+00
```

and the results file's `Operating Point` plot holds `v(in) v(mid) v(out) i(v1) i(vsense)
i(vz) v(zed)` — no `v(in,mid)`. A difference is an expression and belongs to the log.

### 3. The `v(…)` wrapper is the FILE WRITER's, not the vector's name

Same deck, fork:

```
display  ->  Transfer_function   v1#Input_impedance   output_impedance_at_V(mid)
raw      ->  v(Transfer_function) v(v1#Input_impedance) v(output_impedance_at_V(mid))
```

ngspice types all three `voltage` and the writer prefixes every voltage-typed vector. The
same is true of `v(onoise_total)` and of every `sens` parameter (`v(r1)`, `v(r1:r)`). A
user types what they can **see**, so `raw_spellings` offers the stripped form beside the
literal one.

⚠ **The `i(…)` form is NOT stripped, and that is measured rather than symmetry.** Stripping
it would index `i(v1)` under the bare word `v1`, which is **also** the sensitivity to
source V1 — a manufactured collision between an operating point current and a sensitivity,
in every run that enables both. Row **RD7** carries exactly that pair.

### 4. Names with parentheses ARE printable — from the right plot

```
print output_impedance_at_V(mid)  -> output_impedance_at_v(mid) = 5.000000e+02
print Transfer_function           -> transfer_function = 5.000000e-01
print r1:r                        -> r1:r = -0.000000e+00
```

⚠ **and `print` FOLDS the echoed label even on the case-preserving fork** for these
vectors. So the limitation in reason 3 of the rule (a parenthesised name goes to the log
and finds nothing there under the op anchor) is the print **anchor's**, not a parser's.

### 5. `remzerovec` does NOT create a divergence between the two readers

`v(zed)`, a node at exactly 0 V, is in the results file **and** echoed by `print` as
`0.000000e+00`. `remzerovec` removes zero-*length* vectors, not zero-*valued* ones, and in
`render_deck`'s emitted order the prints sit **after** `remzerovec` and after the `write`
anyway — so the two readers see the same vector set. This was the sharpest regression risk
and it is not one.

### 6. `%.6e` of the raw value IS the log's own `print` echo, byte for byte

```
raw (ASCII)  1.285714285714286e+00     log  v(mid) = 1.285714e+00
raw (binary) 1.2857142857142858        %.6e -> 1.285714e+00
```

So ⚖ R3 gives a number to rows that had none and **changes no row that already had one**.
Row **RD1**.

### 7. A one-point plot is not always a scalar

```
ac lin 1 1k 1k  ->  Plotname: AC Analysis / Flags: complex / No. Points: 1
print v(mid)    ->  v(mid) = 4.999951e-01,-1.57078e-03
```

Two numbers. Today's log regexp ends at one number and does not match that line either, so
the cell is empty today and stays empty. Complex plots are excluded.

### 8. The three destinations ⚖ R3 exists for

```
Plotname: Transfer Function / Flags: real / No. Points: 1
   v(Transfer_function)  v(output_impedance_at_V(mid))  v(v1#Input_impedance)
Plotname: Integrated Noise / Flags: real / No. Points: 1
   v(onoise_total)  v(inoise_total)
Plotname: Sensitivity Analysis / Flags: real / No. Points: 1 / No. Variables: 111
   v(r1)  v(r1:r)  v(r1_m)  v(r2)  …
```

apt 45.2 writes the same file with `v(transfer_function)`; `pz`'s and `sens`'s names have
no capitals at all (issues 1427, 1428).

### 9. The constants-only file

Measurement above, plus its `Flags:` line: `constants` is `Flags: complex` on **both**
binaries, which is why the name test had to be pinned separately.

---

## What the plan and the tree said that this refuted

This is the batch's eighteenth through twenty-first corrections (Stage 5 took C43–C55).

### C56 — `PLAN.md` §6e's stated reason for reading the raw is not the reason

§6e: *"Reading them from the raw removes `result_probe`'s case-folding ladder and gives
NOISE, TF and SENS a scalar home the current rule denies them."* The second clause is
right; the first is false. Measurement 8: the fork and apt 45.2 spell the same vector
`v(Transfer_function)` and `v(transfer_function)` **in the rawfile**, so the ladder moves
rather than disappearing — `result_probe_raw` runs the same two rungs, gated by the same
`result_casemode`, and rows **RD3/RD3b/RD3c** pin it. The real argument is measurement 1,
which no design document in this batch states: **the log can only ever answer about the
one plot the print anchor stands in.**

### C57 — "a row whose expression names exactly one vector" cannot be decided from parentheses

`DECISIONS.md`'s recommended rule reads as though it were a lookup. It is not:
`abs(v(mid))` and `output_impedance_at_V(mid)` are the same string shape and no string test
tells a function call from a vector whose name contains brackets. The rule ships as
*out_decompose first, then a bare-name alphabet, then everything else is an expression* —
which routes `output_impedance_at_V(mid)` to the log, where it gets nothing under the op
anchor. **That is a named limitation, not an oversight**: the alternative loses
`abs(v(mid))` and `v(a)*2`, which are exactly what Option B exists to protect. The fix is
the registry's `plots` key — issue 1426 already computes that name in `tf_vectors` — and it
is Stage 6's results seam, not a cleverer regexp.

### C58 — `PLAN.md` 6e says nothing about what happens when the vector is absent, and that is the question the driver asked

Answered above, with its two independent exclusions and the sabotage that proved the second
one was carrying the first.

### C59 — the `\W`-escaped log regexp and the raw lookup are NOT the same matcher, and the raw one is a dict

The log reader builds a per-row regexp and scans the whole log for it. The raw reader
builds **one** lookup over the file and answers every row out of it, because the file has a
variable list and the log does not. That difference is why the raw reader can DECLINE on a
name found twice with two numbers — the log reader can only see the labels its own regexp
matched, while the raw reader sees the whole namespace. Row **RD6b** is the case only the
raw side can catch: issue 1428's measured `r1_temp` collision, the **same name twice inside
one plot**.

---

## Suites moved, before → after, per arm

| suite | headless | display (`:99`) |
|---|---|---|
| `test_ase_core` | 391 → **417** | 391 → **417** |
| `test_ase_simcaps_0948` | 180 → **190** | 180 → **190** |
| `test_ase_result_case` | 28 → **31** | 28 → **31** |
| `test_ase_print_bracket_0167` | 12 → **14** | 12 → **14** |
| `test_ase_preflight` | 192 → 192 | 192 → 192 |
| `test_ase_dialogs` | 37 → 37 | 285 → 285 |
| `test_ase_persist` | 44 → 44 | 148 → 148 |
| `test_ase_cosim` | 341 → 341 | 341 → 341 |
| `test_ase_optier_0963` | 103 → 103 | see *For the driver* |

New sections: **RS** and **RD** in `test_ase_core.tcl`, **RV** in
`test_ase_simcaps_0948.tcl`, **NCR** in `test_ase_result_case.tcl`, and **PB13** / **PB12b**
in `test_ase_print_bracket_0167.tcl`. All four floor paragraphs raised in the same commit.

⚠ **NOT ONE EXISTING ROW MOVED, in any suite, on either arm.** Three Stage 5 commits in a
row each moved four to seven; this one moves none, because it adds no registry key and
changes no emitted deck. What it *did* do is make two existing suites test a differently
named proc, which is recorded above and is not the same thing.

⚠ **Sections RS, RD and RV carry their own `catch`.** `test_ase_core.tcl`'s outer one
closes at the end of section SI and `test_ase_simcaps_0948.tcl`'s at the end of section H,
both far above where these sections live. Issue 1428's S10 and S12 measured what that
costs, and **sabotage S11 proved the guard earns its place here**: it raised inside section
RV and the file still printed two named rows (`RV1`, `RV0`) and both banners, instead of
dying with no `RESULT:` line.

---

## The sabotage table

**Thirty-one distinct respellings of `src/ase.tcl`, forty-two runs**, each a plausible
rewrite rather than a break. Restore was `cp` from `/tmp/r3probe/pristine/` with an `md5sum
-c` after **every** one; the final tree matches pristine on every touched file.

Counted by first attempt: **twenty-three reddened a named row**, **six survived**, **one
KILLED a suite** (S31), and **one did not land at all** (S15 — the `sed` pattern missed;
recorded rather than hidden, and re-run as S15r). Of the re-runs, one made a section RAISE
instead of reddening a named row (S12t) and bought a third hardening. **Every exception was
re-run against what it bought.** The six survivors are **S4, S6, S7 (on `test_ase_core`),
S12, S14 and S28**: five bought a row, and the sixth (S28) is a survivor **by
construction**, with the construction now asserted rather than assumed.

| # | the respelling | rows reddened |
|---|---|---|
| S1 | the bare-name alphabet gains `(` and `)` ("so `output_impedance_at_V(mid)` is reachable") | core **RS1 RS1b** |
| S2 | `{voltage a b}` counted as ONE vector | core **RS1** |
| S3 | the alphabet gains `[` and `]` | core **RS1** · print_bracket **PB13** |
| S4 | the alphabet gains a leading `@` | **NOTHING** *(survivor 1 — see below)* |
| S4r | the same, re-run against the row it bought | core **RS1** |
| S5 | `out_decompose`'s answer ignored entirely | core **RS1 RS4 RD1 RD4 RD7 RD10** |
| S6 | the alphabet gains a leading `-` | **NOTHING** *(survivor 2)* |
| S6r | the same, re-run against the row it bought | core **RS1** |
| S7 | the `constants` NAME test deleted | simcaps **RV3b** — core **ALL PASS** *(survivor 3)* |
| S7r | the same, re-run against the row it bought | core **RD5c** · simcaps **RV3b** |
| S8 | the `Flags: complex` exclusion deleted | core **RD4** · simcaps **RV3** |
| S9 | the `No. Points: 1` exclusion deleted | core **RD4** · simcaps **RV3 RV6** |
| S10 | `raw_scalars_add` zips a short value list instead of dropping it | simcaps **RV4** |
| S11 | the answer becomes a flat dict instead of a list of pairs | core **RS3 RS3b RD1 RD2 RD3 RD4 RD5b RD6 RD7 RD10** · simcaps **RV1 RV0** |
| S12 | the `Binary:` seek loses the complex ×16 (a `sed` hits BOTH procs that carry the line) | simcaps **B8** — an EXISTING `cap_raw_plots` row, and none of this issue's *(survivor 4)* |
| S12r | the same, applied to `ase::raw_scalars` ALONE | **NOTHING** — an all-zero payload has no newline to resynchronise on *(survivor 4b)* |
| S12s | the same, against the `ZZGHOST` fixture it bought | simcaps **RV6** |
| S12t | and the other direction — a real payload over-counted ×16 | simcaps **RV0**, the section catch: `abs(ABSENT - 1.28)` RAISED *(bought `rv_near`)* |
| S12u | the same, re-run against the hardened compare | simcaps **RV6** |
| S13 | the ASCII value parser takes the point INDEX instead of the number | core **RS3 RS3b RD2 RD3 RD4 RD6 RD7 RD10** · simcaps **RV1 RV3 RV5** |
| S14 | the `Values:` arm stops asking `raw_scalars_wanted` | **NOTHING** *(survivor 5)* |
| S14r | the same, re-run against the row it bought | simcaps **RV3d** |
| S15 | `raw_spellings` strips `i(…)` too | *(the edit did not land — recorded, not hidden)* |
| S15r | the same, applied | core **RD7** |
| S16 | `raw_spellings` returns only the literal name | core **RS3 RS3b RD2 RD3 RD6 RD7** |
| S17 | the folded rung is not gated on `distinguish` | core **RD3b** · result_case **NCR2** |
| S18 | the two-numbers decline dropped: take the first | core **RD6 RD6b** |
| S19 | `%.6e` → `%.4e` | core **RS3 RS3b RD1 RD2 RD3 RD3c RD4 RD5b RD6 RD7 RD10** · result_case **NCR1 NCR3** |
| S20 | no formatting at all — the raw value verbatim | the same thirteen |
| S21 | the missing-vector sentence fires with NO results file | core **RD8** |
| S22 | the missing-vector sentence dropped | core **RD8 RD8b** |
| S23 | the folded rung consulted BEFORE the exact one | core **RD3c** |
| S24 | the LOG reader handed EVERY row — a silent fallback | core **RS3 RD12** |
| S25 | the RAW reader handed EVERY row | core **RS3 RS3b RD1 RD2 RD3 RD3c RD4 RD5b RD6 RD7 RD8 RD8b RD10** |
| S26 | the rule no longer said on screen | core **RS4 RS4b** |
| S27 | the sentence hardcodes its counts instead of computing them | core **RS4b** |
| S28 | the merge order reversed — the log wins a clash | **NOTHING** *(survivor 6 — by construction)* |
| S28r | the same, re-run against the row it bought | **NOTHING**, correctly — see below |
| S29 | each reader resolves the case rule for itself | core **RD11** |
| S30 | `ase::result_source` called from INSIDE the raw reader | core **RS2** |
| S31 | the `catch` around `raw_file` dropped | **KILLED `test_ase_core`** *(see below)* |
| S31r | the same, re-run against the hardening it bought | core **P1 P1 RD14**, `RESULT: 3 FAILED (414 passed)` |

### The one that KILLED a suite, and the two things it bought

**S31's first attempt did not redden a row — it killed `test_ase_core` outright**, with
`UNEXPECTED ERROR: ase: state design has no cell (raw_file)` and no `RESULT:` line at all.

The reason is a real contract, not a test artefact. Since ⚖ R3 made `result_probe` a
dispatcher it resolves the results-file path on **every** call, and
`ase::backend::ngspice::raw_file` raises for a state with no `design cell`. Row **P1** —
which predates this issue by a year — calls the probe with exactly such a state
(`ase::state_default` plus an `outputs` key), and it is nearly four thousand lines above
where this file's outer `catch` has already closed.

Two things landed because of it, and the first matters more:

* **RD14** asserts the contract: a state with no design cell answers its log rows and does
  **not** raise. `ase::run_done` calls the probe on **every** completion, including runs
  that failed before a design was resolved, so this is a production property.
* **P1's two calls now go through a `p1probe` wrapper** that returns `RAISED:<msg>` as an
  ordinary value, and read their key through a `p1val` helper. Re-run: **3 FAILED (414
  passed)**, three named rows, both banners. The reason is written beside it, because the
  next person to touch P1 will otherwise read the `catch` as defensive padding.

This is the Stage 3 lesson arriving for the fourth time in this batch (`pz`'s `pzkey` and
`g2pz_cget`, `sens`'s `svkey` and its three `_lines` catches). ⚠ **It is also the first time
the lesson has reached a row that was already there.** The other three hardened rows the
same crew had just written; this one is an existing row that a *new* seam made fragile, and
nothing in the diff would have pointed at it. **Sabotage the callers, not only the code.**

### The one that PROVED the section guard earns its place

**S11 raised inside section RV**, and the file did not die: it printed `RV1` and `RV0` —
the section's own named catch row — and both banners, at `RESULT: 2 FAILED (180 passed)`.
That is the guard doing exactly the job issue 1428's S12 paid for: `test_ase_simcaps_0948`'s
outer `catch` closes at the end of section H, hundreds of lines above RV.

### The six that SURVIVED, and the five rows they bought

**S4 and S6 — adding `@` or `-` to the name alphabet — changed nothing.** The first draft of
row RS1's shape list held `@r1[i]` and `-i(v1)`, and *both of those carry a second
disqualifying character* (a bracket, a parenthesis), so the row could not see the alphabet
it claims to pin. ⚠ **A row whose fixtures never isolate the thing it is about cannot fail**,
and this is that failure in its purest form: the list looked thorough. `@r1` and
`-onoise_total` were added; S4r and S6r each redden RS1.

**S7 — deleting the `constants` NAME test — left `test_ase_core` at ALL PASS (415)** and
reddened only `test_ase_simcaps_0948`'s RV3b. RD5's fixture is `Flags: complex`, which is
what **both binaries really write**, so the *accidental* guard was silently carrying the
*deliberate* one. **RD5c** is the same plot flagged `real`; S7r reddens it. ⚠ The general
shape: *two guards that happen to agree on every fixture are one guard, and which one you
have is not knowable from a green suite.*

**S12 — the `Binary:` seek losing the complex ×16 — reddened `cap_raw_plots`' row B8 and
none of mine**, because `ase::raw_scalars` and `ase::cap_raw_plots` carry the *same line*
and a `sed` hits both. Applied to `raw_scalars` alone (**S12r**) it left simcaps at ALL PASS
(190): my fixture's payload was all zeros, a short seek lands mid-payload, **an all-zero
block contains no newline**, and the reader simply resynchronises on the next real
`Plotname:`. The fix was already in this file — section B's **`ZZGHOST`** idiom, a payload
that *spells a plot header in the middle of itself*. RV6's fixture now carries it in both
payloads, the ghost being `Flags: real / No. Points: 1` so it would be reported as a
**scalar** plot, the worst shape: a number for an analysis nobody ran. **S12s** reddens RV6.

⚠ **And the other direction bought a second hardening.** **S12t** — a *real* payload
over-counted ×16 — made the section RAISE rather than redden: `rv_get` answers `ABSENT` for
a plot that is not there, and `abs(ABSENT - 1.285714…)` is a Tcl error, so the row that
should have gone red by name arrived as the section's catch row **RV0** and a lost check
count. That is `test_ase_result_case.tcl`'s `approx` rule (*"abort-proof numeric compare"*)
arriving in a second file. `rv_near` answers the offending value verbatim instead of doing
arithmetic on it; **S12u** reddens **RV6** by name.

⚠ **S12r and the first S12t were also taken against a fixture the fix had never reached**,
and that is recorded rather than tidied away: the step that applied the `ZZGHOST` fixture
sat behind a waiter loop that greps for its own command line (see the last lesson below), so
it never ran, and two sabotage verdicts were collected from the old fixture. They are listed
above with their real results.

**S14 — the `Values:` arm no longer asking `raw_scalars_wanted` — changed nothing
observable, and still does.** The test is asked from three places (both arms of the reader
and `raw_scalars_add`) precisely so the arms cannot drift, and the third call catches what
the first two let through. ⚠ A behavioural row for it would be a row that cannot fail, so
the drift is pinned **structurally** instead: **RV3d** counts the calls. S14r reddens it.

**S28 — reversing the merge order so the log wins a clash — changed nothing, and is a
survivor BY CONSTRUCTION.** A correct partition gives the two readers **disjoint key sets**,
so there is no clash to win. The dispatcher's comment nevertheless claims *"raw wins a key
clash"*, and an unasserted claim is issue 1428's S35 class exactly (*a key read by nothing
is a key checked by nothing*). **RD13** asserts the construction — the two readers' answers
for the same state share no key — and says in its comment why the order beneath it is inert.
S28r is still green, correctly, and it is recorded here rather than quietly dropped.

### The three rows that were written in anticipation, and the sabotages that confirmed them

RD3c (the raw reader's ladder ORDER), RD12 (no fallback to the log) and RD8b (the missing
sentence names only the rows the raw reader was given) were written **before** the
sabotages that target them, on the reasoning that each was an unasserted claim. S23, S24
and S25 confirm all three are non-vacuous. They are listed separately from the five
sabotage-driven rows above because the distinction is the whole point of the exercise: a
row predicted is a row that might still have been vacuous, and only the sabotage says.

---

## What this stage learned that binds later ones

**A design document's REASON can be wrong while its RECOMMENDATION is right.** `PLAN.md`
§6e argues for the rawfile because it *"removes `result_probe`'s case-folding ladder"* — a
claim about a mechanism, checkable in twenty minutes, and false. The ladder moves; it does
not go. Had the crew built on the stated reason it would have deleted the ladder and
shipped a reader that is wrong on `/usr/bin/ngspice`, which is the binary a downloading
user has. ⚠ **Check a plan's REASON, not only its conclusion** — and when the real reason
turns out to be better (here: *the log can only ever answer about the plot the print anchor
stands in*), write it down, because the next person will inherit the plan's sentence and
not this one.

**An unratified recommendation can ship, but only if its shape is the ruling's superset AND
something MEASURES that.** RS2 is the cheap half and it is not enough: it only says the two
bodies do not mention each other. RS3 is the half that costs something — it **performs**
both rulings by stubbing the one proc, on a fixture whose two sources deliberately
**disagree**, so it can say which reader answered. ⚠ A separability claim with no such
fixture is a claim about the code's *appearance*.

**Two guards that agree on every fixture are one guard, and a green suite cannot tell you
which one you have.** The `constants` plot is excluded by name *and* is `Flags: complex` on
both binaries. Deleting the name test — the deliberate guard, the one the whole
run-computed-nothing answer rests on — left `test_ase_core` at ALL PASS. The row that
catches it has to use a fixture that is **deliberately not what the simulator writes**
(`constants` flagged `real`), which feels wrong and is exactly right.

**A row whose fixture list looks thorough can still fail to isolate its own subject.** RS1
tabulated twenty expression shapes and could not see `@` or `-` being added to the name
alphabet, because the only `@` shape it held also carried a bracket and the only `-` shape
also carried a parenthesis. ⚠ **Each character a rule rejects needs a fixture that is
rejected FOR THAT CHARACTER ALONE.** This is the batch's fifth time meeting *a row whose
fixtures never disagree cannot fail*, and the first where the fixtures disagreed about
everything except the one thing.

**Sabotage the CALLERS, not only the code you wrote.** Removing one `catch` from a new proc
killed `test_ase_core` at row **P1** — a row a year older than this issue, four thousand
lines above where that file's outer `catch` has closed, which nothing in the diff points
at. A new seam can make an old row fragile, and the only thing that finds it is running the
sabotage against the whole suite rather than reasoning about the section you added.

**A payload of zeros hides a seek bug.** `ase::cap_raw_plots` and `ase::raw_scalars` carry
the same skip-by-arithmetic line, and a fixture whose binary payload is all zeros cannot see
it go wrong in the *short* direction: an all-zero block contains no newline, so a reader
that lands mid-payload simply resynchronises on the next real `Plotname:`. Section B of
`test_ase_simcaps_0948.tcl` had already solved this — a payload that **spells a plot header
in the middle of itself** — and the solution had to be borrowed rather than re-derived.
⚠ **Look for the idiom in the file before inventing one**; the row that needed it was three
thousand lines below the row that has it.

**A ternary `expr` on two STRING branches is a trap, and a braced one is not.**
`expr {$i == 0 ? " 0\t$v\n" : "\t$v\n"}` evaluates its quoted branches as **arithmetic** and
wrote `1.285714285714286-0.001714285714285714` into a fixture — which reads exactly like a
broken reader, and cost the first RD run. `expr {$n == 1 ? {that row has} : {those rows
have}}` is fine, because a **braced** operand is a string literal. The distinction is
quoting, not the ternary, and both forms are in this commit with the reason written beside
the dangerous one.

**A waiter that greps for its own command line never returns.** `until ! pgrep -f sab6.sh;
do sleep 5; done` run from a shell whose command line **contains** `sab6.sh` matches itself
forever. Two sabotage results (S12s, S12t) were taken against a fixture the fix had never
been applied to, because the step that applied it sat behind that loop. It is `CLAUDE.md`'s
*bound every wait* rule wearing a new costume: the loop had a condition that could never
become false, and "still running" was indistinguishable from "wedged". **Match on something
the waiter itself cannot contain** (`pgrep -f '/bin/sh /tmp/…/sab7'`), and re-verify a fix
landed before trusting a run that depends on it.

---

## What I did NOT ship, and why

* **The writer, the `setplot previous` walk, `<cell>_ase.plotmap` and the three-arm
  reconciliation** (`PLAN.md` 6a–6c). `render_deck` is **untouched**; **no deck golden
  moves**. `test_ase_cosim` (341) and `test_ase_optier_0963` (103) are unmoved headless.
* **`noise`, `disto` and `sens (ac)`** (6d). No analysis type is added, no registry entry
  changes. `ase::analysis_schema_errors` stays clean, row **GR8**'s declared-kind set is
  unmoved, and `test_ase_preflight`'s **PF222a-e / PF222h-j** — which rest on `noise` being
  UNRENDERABLE — are green, along with the rest of that suite's 192.
* **Checkpointed salvage** (6f) and **the four variant mitigations** (6g).
* **`seed_enabled`, anywhere.** `ase::state_default` still seeds exactly four rows; the 104
  committed `.state` files are byte-identical and section **CP** still proves it.
* **`output_impedance_at_V(mid)` and `pole(1)` as Value-column rows.** Correction C57: no
  string test tells a function call from a vector name containing brackets, and the losing
  side of that coin is `abs(v(mid))`, which works today. `pz`'s roots were never the Value
  column's anyway — issue 1427 gives them `results {table {kind roots}}`. The registry
  already computes the `tf` names (`tf_vectors`), so the results seam inherits them.
* **A complex scalar.** Measurement 7: two numbers, and the log reader does not match that
  line either.
* **Any change to `render_deck`'s print anchor.** That is issue 1243, the user's own ruling,
  and ⚖ R3 extends it rather than reversing it.
* **An early return in `result_probe_raw` when there are no raw rows.** It looks like a free
  optimisation and is not worth it: `ase::raw_scalars` reads headers and seeks, which
  `ase::cap_raw_plots` already does on the user's own 69 MB file on every run report (issue
  0965). Adding it would also have hidden the `raw_file` contract that row RD14 now states.
* **Anything in `src/ase_window.tcl`.** The Value column is filled from the same `results`
  dict, keyed exactly as `ase::ui::output_result_key` looks it up. Nothing on screen is
  drawn differently; what changed is which file a number was read from, and the run now
  says which.

---

## Rulings

⚖ **R3 is the ruling this task gates, and it is STILL UNANSWERED.** Option C ships as
`DECISIONS.md`'s recommendation, marked as one in the issue file, six code comment blocks,
four suite headers and this receipt. Nothing here converts it into a ratification, and the
table in *How C was made separable* is what makes a later A or B cheap.

⚖ **R9.** Three new user-facing sentences:

1. the rule itself — *"a row whose expression names exactly one vector is read from the
   results file; anything else is read from the print log. This run: N from the file, M from
   the log."*
2. the missing-vector note — *"the results file holds no single-point value for …, so those
   rows have no value: a multi-point vector is not a scalar, and a run that computed nothing
   writes only the constants plot."*
3. the two-numbers decline — *"output 'X' matches N different numbers in the results file
   (…), so no value is recorded for it: which one it means cannot be known, and a guess
   would put a wrong number in the Outputs pane."*

Recorded as `owed.sh add rule 1429` at the moment it was incurred, with the entry saying in
as many words that **it does not stand in for R3**. ⚠ **The ledger was backed up first** to
`/tmp/r3probe/owed_backup_20260912_133603`, per `CLAUDE.md`'s one-ledger-every-clone
paragraph; the entry is stamped `repo:/home/analog/dev/xschem-claude`. Batch with Stage 5's
three (1426, 1427, 1428), which are still waiting.

**No `look` debt.** `src/ase_window.tcl` is untouched and nothing new is drawn. The three
sentences reach the CIW pane through `ase::echo`, which is the same channel every other
result note in this file already uses.

**No `suite` debt beyond the display-arm runs recorded below**, which were taken.

---

## For the driver

* T1 was **not** run by this crew (issue 0990 — the driver runs it solo).
* **Nothing was committed, added, stashed, restored or cleaned.** `git status` shows
  **six modified** — `src/ase.tcl`, `tests/headless/test_ase_core.tcl`,
  `tests/headless/test_ase_simcaps_0948.tcl`, `tests/headless/test_ase_result_case.tcl`,
  `tests/headless/test_ase_print_bracket_0167.tcl`, `doc/claude/issues/NUMBERING.md` — and
  **two new**,
  `doc/claude/issues/1429-the-outputs-value-column-could-not-see-three-analyses-answers.md`
  and this receipt. **`src/ase_window.tcl` is untouched.** `LEDGER.md` is outside the files
  this crew may modify and is the driver's to close.
* `NUMBERING.md`'s pointer was advanced **1429 → 1430** in the same edit as the entry. Both
  mint checks were run: the reserved-band scan over this clone's head table (silent for
  1429) and `ls ~/dev/*/doc/claude/issues/1429-*` plus `/usr/bin/grep -lw 1429` across every
  clone's `NUMBERING.md` (only this clone's own pointer line).
* **The whole ASE family (29 suites) was re-run on BOTH arms through `run_suites.sh`**, every
  arm `timeout`-bounded (`SUITE_TIMEOUT=400`):
  * **headless** (`--nogui`): **27/27 passed, 2 self-skipped** (`test_ase_dirty`,
    `test_ase_log_seam_0207` — both need an X connection). `test_ase_optier_0963` headless is
    **ALL PASS (103)**, which is the arm `run_regression.tcl` runs it on.
  * **display `:99`** (openbox 3.6.1 live, `1920x1080x24`, confirmed by
    `devdisplay.sh status` before the run): **27/29 passed**, and both non-passes are named
    below.
* ⚠ **Two named outcomes on the display arm, neither a regression, both reported as outcomes
  rather than as silence — and both are exactly what the three Stage 5 crews reported:**
  * `test_ase_log_seam_0207` — **the invocation, not a regression.** It asserts on the action
    log, which exists only under `--logdir`; its own first row is literally
    `PS0 action log open (needs --logdir)`, and `full_audit.sh:85` has it on `logdir_tests`
    for exactly that reason. **I did not re-run it with `--logdir`, because this crew's brief
    forbids `--logdir` outright.** The `pz` receipt records
    `run_suites.sh --logdir test_ase_log_seam_0207` → **ALL PASS (49)**, and
    `run_suites.sh:122` is `tmpd=$(mktemp -d)` so the user's own `/tmp/Xschem.log.N` is never
    the target. **The driver may want that one run.**
  * `test_ase_optier_0963` — **`TIMEOUT | test_ase_optier_0963 run 15/29 (after 400s)`.**
    This is the filed pre-existing display-arm stall `CLAUDE.md` records by name (*"86 of 103
    rows, stops after row N3"*), which all three Stage 5 crews hit in the same place. Nothing
    in this commit touches `optier`, `render_deck` or anything that suite drives, and its
    headless arm is **ALL PASS (103)** before and after. Bounded by `run_suites.sh`'s own
    per-arm `timeout`, so there is no orphan: `pgrep -fa src/xschem` after the run is clean.
* **Both binaries were exercised for every measurement**: the fork
  (`/home/analog/dev/ngspice/build-ver_50/src/ngspice`, `ngspice-46+`) and
  `/usr/bin/ngspice` (`ngspice-45.2`). The three that decide the design were re-run on apt
  45.2 verbatim: the print anchor (only `v(mid)` answers, the other three print nothing), the
  constants-only file (`rc 0`, `Plotname: constants`, `Flags: complex`, 12 variables, and
  `print v(mid)` silent), and `v(in,mid)` printing in the log while being absent from the
  results file.
* ⚠ **`~/.xschem/` was not touched by any probe of mine** — every ngspice run used a scratch
  deck under `/tmp/r3probe`, and **no bench under `sky130A/` was run**. Every xschem
  invocation was given a path (`./src/xschem`), never a bare `xschem`, and never `--logdir`.
* The owed ledger was **backed up first** to `/tmp/r3probe/owed_backup_20260912_133603`
  (148 rule / 56 look / 9 suite at the time) before `owed.sh add rule 1429`; the new entry is
  stamped `repo:/home/analog/dev/xschem-claude`.
* Suggested commit subject:
  `feat(1429): the Outputs Value column could not see three analyses' answers`
