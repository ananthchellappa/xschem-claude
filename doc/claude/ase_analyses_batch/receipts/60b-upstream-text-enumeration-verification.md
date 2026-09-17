# 60b — SEPARATE-VERIFIER pass on receipt 60's two enumerations

**Task:** read-only adversarial verification. I did not do the work in receipt 60 and I
disbelieved it. Both tables were re-derived from the live tree, not compared against the
receipt's own workings; the ngspice authorship was re-grepped per string; the one claim
receipt 60 inherited rather than measured (visibility of the 15) was **re-derived by
RENDERING**, not by reading the call graph.

**Headline: the enumerations are sound and the driver may mint from them. Every string in
both tables is byte-identical to the tree — 0 transcription defects over 60 + 18 strings.**
Four *citation and attribution* defects were found in the receipt's prose and one
corroboration claim is refuted. None of them moves a string, a class or a count; all of
them would propagate into a handle's `*Where:*` or `*Note:*` line if quoted.

---

## VERDICT TABLE

| # | claim | verdict | evidence |
|---|---|---|---|
| 1 | **transcription fidelity** of all 60 + 18 strings | **CONFIRMED** | mechanical diff, live probe vs parsed receipt tables: **0 defects**, both directions, carriers included |
| 2 | **completeness** — 60 distinct / 67 rows / 180 without / 53+7; 18 distinct / 11 types / 21 rows / 15+3 | **CONFIRMED** | independent probe: 247 / 67 / 180 / 60; 55×1+4×2+1×4=67; 11 / 21 / 18 / 15 / 3 |
| 3 | **53 of 53 resolve in `cktsopt.c`** | **CONFIRMED** | per-string `/usr/bin/grep -cF` → 53/53; the 7 ASE-L strings → **0 files** anywhere in ngspice `src/` |
| 4 | **the 7 ASE-L strings are all already handled** | **CONFIRMED** | exact fenced-block equality, 1 block each, handles exactly as named |
| 5 | **CORRECTION 1** — 59 §5's "help for every row" is false; the surface is `optsheet_detail`'s per-row detail line | **CONFIRMED** *(one sub-claim **PARTLY**)* | 180/247 measured live; `INSCOPE_GLOBAL` = 247/247. **"exactly two callers in the whole tree" is wrong** — 2 in `src/`, 4 more in `tests/` |
| 6 | **CORRECTION 2** — the path is `src/spicelib/parser/inp2dot.c`; `src/frontend/inp2dot.c` does not exist | **CONFIRMED** *(and the receipt then repeats the defect)* | both halves verified; all 8 job-name lines exact; all 15 files resolve with the literal on the cited line. **But 4 of the receipt's own citations are bare filenames** |
| 7 | **CORRECTION 3** — the `*` is ASE-L's; ngspice emits two names per plot via a ternary | **CONFIRMED, and strengthened** | ternaries exact at `noisesp.c:355-356` / `:186-188`, `noisean.c:534-535` / `:276-278`; starred forms → 0 files, bare → 3 and 2. **I rendered both starred literals onto the user's sentence** |
| 8 | **opinfo three = 1 / 0 / 0** | **CONFIRMED** | exact fenced-block equality; occurrences 1 / 3 / 2 |
| 8b | **related finding** — "`R9-276`'s own Note already says `disto` and `pz` add **two** more names" | **REFUTED** | the Note names **one** name (`Distortion Operating Point`). `AC Operating Point` appears **nowhere** in R9-276 |
| 8c | **§B3's occurrence *locations*** for the opinfo two | **REFUTED** | the lines belong to **R9-269**, not R9-274/R9-275; `:4694` is not an `AC Operating Point` occurrence at all |
| 9 | **the `Integrated Noise` trap** — 4 hits, all caution prose, correctly 0 | **CONFIRMED** | doc:180, 186 (`>`-quoted ruling block), 1657, 3111 (`*Note:*` on `lin_points`); starred 0; `Noise Spectral Density` 0 |
| 10 | **the inherited claim** — the 15 reach the user via `reconcile_plots`' mislabel arm | **CONFIRMED BY RENDERING** | 3 arms, verdict `mislabel`, select literal quoted verbatim in the user-facing sentence |
| — | **"several of the 53 also appear in `src/ngspice.txt`"** | **REFUTED** | exactly **1** of 53 does (`Operating temperature`). All three named examples resolve in `cktsopt.c` **only** |
| — | **`tnom` footnote — "many device files", "one of dozens"** | **PARTLY** | "not distinctive" is TRUE (3 files), but it is **2** device files, not dozens |

---

## 1 — Method

**Nothing was carried.** The domains came from one headless probe of the shipped readers, the
authorship from a fresh per-string grep, the document from an independently written extractor.
The prior crew's scratch artefacts share this session's scratchpad directory; **I read none of
them** and wrote my own under `scratchpad/v60/`.

| what | how | result |
|---|---|---|
| A domain | `probe60v.tcl` → `ase::sim_option_names ngspice`, `ase::opt_help` per row | 247 rows, 67 help, 60 distinct |
| A reachability | `ase::opt_in_scope ngspice $n global` per row | **247 / 247** |
| B domain | `ase::analysis_types ngspice` → each type's `plots`; `ase::plot_capturable`, `ase::plot_select` | 11 types, 21 rows, 18 distinct, 15 / 3 |
| authorship | `/usr/bin/grep -cF` in `cktsopt.c`, `-rlF` in `src/` | 53/53 upstream; 0/7 for ASE-L |
| document | `extract_doc.py`, independently written | **751 handles / 751 fenced blocks** (718 distinct bodies) |
| visibility | `render60v.tcl` → `ase::reconcile_plots` driven to `mislabel` | select literal rendered verbatim, 4 literals over 3 arms |

**Strings crossed the probe boundary base64-encoded**, so byte-identity survives transport —
a TSV of raw help text would have made exactly the mangling this pass exists to catch
invisible. Both probes assert a positive sentinel (`PROBE DONE` / `RENDER DONE`) as their last
act; a silent or crashed probe reports `NO SENTINEL` rather than passing. Fed an empty
domain, both write `FATAL` and `exit 1` — the guard was written to be able to disagree.

---

## 2 — Claim 1: transcription fidelity. **0 defects.**

The highest-value check, done mechanically. `parse_receipt.py` parses the receipt's three
tables out of the markdown; the probe supplies the tree's own strings; the comparison is exact
Python string equality in both directions.

```
== TRANSCRIPTION FIDELITY: receipt A table vs live tree ==
 receipt rows=60 live distinct=60
 -> A fidelity defects: 0
== FIDELITY: receipt B1+B3 vs live ==
 -> B fidelity defects: 0
```

That covers, per row: the help string itself, the **carrier list** (a receipt row naming the
wrong option rows would have failed here), and for B the `select` literal and its
capturable/opinfo side. No string in either table differs from the tree by one character.
**The driver may transcribe all 78 strings straight from the tables.**

## 3 — Claim 2: completeness. Every number re-derived.

```
rows=247  rows_with_help=67  rows_without=180  distinct_help=60
carrier multiplicity: {1: 55, 2: 4, 4: 1} -> rows accounted: 67
  x2 abstol,lteabstol      x2 itl6,srcsteps
  x2 ltereltol,reltol      x2 ltetrtol,trtol
  x4 savecurrents,savecurrents_bsim3,savecurrents_bsim4,savecurrents_mos1
authorship: 53 UPSTREAM + 7 ASE-L = 60

plot_rows=21 distinct_select=18 capturable=15 opinfo=3 mixed=0
capturable ROWS=16 opinfo ROWS=5
  x2 AC Operating Point          [ac/r2, sp/r2]
  x2 Distortion Operating Point  [pz/r2, disto/r6]
  x2 Sensitivity Analysis        [sens/r1, sens/r2]
TYPES = op dc ac tran noise tf pz sens disto sp pss    NOPLOTSKEY = pss
```

Every figure matches the receipt, including the three twice-carried literals, the 16/5 row
split behind the 15/3 distinct split, and `pss` carrying no `plots` key. **`mixed=0` is a
check the receipt did not state**: no `select` literal is capturable in one row and opinfo in
another, so the 15/3 split is well-defined rather than an artefact of which row was seen first.

The receipt's §2 self-disclosure about a raw script printing **19** — its own `NOPLOTSKEY`
sentinel for `pss` — is consistent with my run, which emits the same sentinel on its own line
rather than into the literal list. Disclosed honestly; not a defect.

## 4 — Claim 3: authorship. 53/53, and 0/7.

Per-string, `/usr/bin/grep` throughout (never the bare `grep`; it is a function routing to
ugrep). **53 of 53 UPSTREAM strings resolve in `src/spicelib/analysis/cktsopt.c`** — the
stronger form the receipt claims over 59's "overwhelmingly" is correct. **All 7 ASE-L strings
return 0 files across the whole of ngspice `src/`**, so none of them is ngspice's wording
being mistaken for ASE-L's.

### ⚠ But the `src/ngspice.txt` corroboration is REFUTED

The receipt says *"Several of the 53 also appear in `src/ngspice.txt`* (the shipped manual
text) — e.g. rows 29 (`Set KLU as Direct Linear Solver`) and 12/13 (`Default MOSfet area of
…`)". Measured over all 53:

```
'Set KLU as Direct Linear Solver'  -> ['spicelib/analysis/cktsopt.c']            (1 file)
'Default MOSfet area of drain'     -> ['spicelib/analysis/cktsopt.c']            (1 file)
'Default MOSfet area of source'    -> ['spicelib/analysis/cktsopt.c']            (1 file)
-> 1 of 53 UPSTREAM strings appear in src/ngspice.txt   ('Operating temperature')
```

`src/ngspice.txt` exists, so this is not a missing-file artefact. **All three named examples
are wrong** and the count is 1, not "several". This is a corroboration claim — it does not
move the class, which is already settled by `cktsopt.c` — but it must not reach a handle.

### `tnom`'s footnote — PARTLY

*"also appears in many device files … a handle citing a single line for it would be citing one
of dozens."* `Nominal temperature` → **3 files**: `hisimhv1/hsmhv.c`, `hisimhv2/hsmhv2.c`,
`cktsopt.c`. The load-bearing half — **not distinctive to `cktsopt.c`**, so do not cite one
line — is TRUE and worth keeping. "Dozens" is **two**.

## 5 — Claim 4: the 7 ASE-L strings. All handled, exactly as named.

Exact fenced-block equality against the committed document, one block each, one occurrence each:

```
filetype      exact_blocks=1  -> R9-235        seed       exact_blocks=1 -> R9-256
notrnoise     exact_blocks=1  -> R9-670        seedinfo   exact_blocks=1 -> R9-257
savecurrents  exact_blocks=1  -> R9-255        soa_log    exact_blocks=1 -> R9-258
units         exact_blocks=1  -> R9-199
```

**Nothing to mint on the ASE-L half.** The receipt's caution that only 4 of the 7 live in the
catalogue-prose section is not something I re-derived independently (it is a claim about
document *sections*, not strings), but the handle ids themselves are confirmed exact, which is
what the driver needs.

## 6 — Claim 5: CORRECTION 1. Confirmed, with one wrong scope word.

* **180 of 247 rows carry no `help`** — measured live, not grepped. Receipt 59 §5's premise is
  indeed false and a `*Where:*` line quoting it would be a false claim 53 times over.
* **The surface is the detail line, per selected row.** `ase::ui::optsheet_detail` reads
  `set h [ase::opt_help $sim $name]`, `lappend bits $h` **first**, and ends
  `$w.detail configure -text [join $bits {  |  }]` — so help really is the *leading* segment,
  and it renders for the row the treeview has selected, not sheet-wide.
* **Reachability is settled in source AND measured.** `ase::opt_in_scope` opens
  `if {[lindex $scope 0] ne {analysis}} { return 1 }`, its header states *"The global surface
  answers 1 for every row in the catalogue"*, and my probe measured **247/247** on the global
  surface. The receipt asserted the source; I added the measurement.

**⚠ PARTLY on one sub-claim.** *"`ase::opt_help` has exactly **two** callers in the whole
tree."* In `src/` that is exact — the render (`ase_window.tcl:9113`) and the search
(`ase.tcl:7073`, inside `ase::opt_match`). But the tree also holds **four** test call sites:
`test_ase_optsheet_1441.tcl:413` and `:421`, `test_ase_trnoise_gui_1467.tcl:326`,
`test_ase_core.tcl:7152`. The *conclusion* — one rendering surface — is unaffected. The phrase
"in the whole tree" is not, and a handle repeating it would be checkably wrong.

## 7 — Claim 6: CORRECTION 2. Confirmed — and then committed again, four times.

`src/frontend/inp2dot.c` **does not exist**; `src/spicelib/parser/inp2dot.c` does. All eight
job-name literals are created there by `IFC(newAnalysis, …)`, and **every line number in the
receipt's B tables is exact, with the literal on the cited line** — 141, 203, 265, 303, 368,
429, 485, 736, plus `distoan.c` 517/541/564/585/607, `acan.c:158`, `pzan.c:58`,
`noisean.c:226`.

### ⚠ Four of the receipt's own citations are bare filenames

The same defect the receipt raises against 59c, inside the tables the driver mints from:

| as written in receipt 60 | resolves? | correct form |
|---|---|---|
| `noisean.c:535` | **no** | `src/spicelib/analysis/noisean.c:535` |
| `noisean.c:278` | **no** | `src/spicelib/analysis/noisean.c:278` |
| `span.c:479` | **no** | `src/spicelib/analysis/span.c:479` |
| `distoan.c:107` | **no** | `src/spicelib/analysis/distoan.c:107` |

All four **line numbers are correct** once the directory is supplied (verified: each holds its
literal). Only the path is short. **The driver must expand these before minting** — receipt
60's own words are *"a handle citing that path would not resolve"*.

## 8 — Claim 7: CORRECTION 3. Confirmed, and stronger than claimed.

The ternaries are exactly where the receipt puts them:

```
noisesp.c:355-356  ? "Integrated Noise - V^2 or A^2"         : "Integrated Noise",
noisesp.c:186-188  ? "Noise Spectral Density Curves - (V^2 or A^2)/Hz"
                                                             : "Noise Spectral Density Curves",
noisean.c:534-535  and  noisean.c:276-278   — the same pair again
```

Grep confirms the asymmetry the argument rests on: `Integrated Noise*` → **0 files**,
`Integrated Noise` → 3; `Noise Spectral Density Curves*` → **0**, bare → 2. The `*` is
ASE-L's. `ase::plot_select`'s own header records the measured reason — `.options sqrnoise`
renames both noise plots, so an exact literal would report `mislabel` on every `sqrnoise` run.

**And the `*` is not merely stored — it reaches the screen.** §11's arm a3 rendered both
starred literals verbatim into the user-facing sentence. So *"ngspice's plot name, with
ASE-L's trailing glob"* is not a pedantic hedge; the metacharacter is on the user's screen, and
a handle claiming "ngspice's own text, verbatim" for those two would be describing a string
that ngspice never wrote.

## 9 — Claim 8: the opinfo three. 1 / 0 / 0 confirmed; **the related finding refuted.**

By exact fenced-block equality (not substring): `NOISE Operating Point` → **1** block, owned by
**R9-276**; `AC Operating Point` → **0**; `Distortion Operating Point` → **0**. Occurrences
anywhere: **1 / 3 / 2**. Every one of the receipt's B1 parentheticals is exact too, including
`Operating Point` (11), `Sensitivity Analysis` (4), `AC Analysis` (1), `Transient Analysis` (1)
and the eleven zeroes.

### ⚠ 8b — the document concedes the principle for ONE of the two, not both

Receipt 60: *"the document already states, in `R9-276`'s own Note, that **two more plot names**
reach that sentence — and neither got an entry."* R9-276's Note, in full, on this point:

> `disto` adds "Distortion Operating Point" to the same sentence, which `pz` already contributed.

That is **one** plot name, contributed by two *analyses*. **`AC Operating Point` does not appear
in R9-276 at all** — `/usr/bin/grep -nF 'AC Operating Point'` returns lines 4595 and 4597 only,
and R9-276 begins at 4684.

This matters to the driver because receipt 60 offers it as the decisive argument — *"the
document has already committed to the principle, and left the instances out"*. The commitment
is real for `Distortion Operating Point` and **absent for `AC Operating Point`**. The ⚖ rule
should be put to the user on that footing, not on a two-name concession that was never made.

### ⚠ 8c — the occurrence *locations* are attributed to the wrong handles

Receipt 60 §B3 places the `AC Operating Point` occurrences at *"`R9-274`'s fenced sentence body
(`doc:4590`) … `R9-275`'s *For:* line (`:4595`), its *Note:* (`:4597`) … and `R9-276`'s *Note:*
(`:4694`)"* — four items under the heading "three occurrences". Measured:

| line | actually belongs to | holds `AC Operating Point`? |
|---|---|---|
| 4590 | **R9-269** (advice) — the fenced body | no (it is the `[join $unames …]` frame) |
| 4595 | **R9-269**'s *For:* | yes ×1 |
| 4597 | **R9-269**'s *Note:* | yes ×2 |
| 4694 | R9-276's *Note:* | **no** |

Handle headers: R9-269 at **4587**, R9-274 at **4654**, R9-275 at **4669**, R9-276 at **4684**.
The **count of 3 is right** (4595 once, 4597 twice); three of the four *locations* are wrong.
Same for `Distortion Operating Point`: its two occurrences are at 4597 (**R9-269**'s Note, not
R9-275's) and 4694 (R9-276's Note — correct).

**The class conclusion is untouched**: both literals are named only inside other handles' prose
and neither has an entry. Only the citations are wrong — and they are exactly the sort of thing
a `*Note:*` would quote.

## 10 — Claim 9: the `Integrated Noise` trap. Preserved exactly.

Four bare hits, and I read all four:

| line | what it is |
|---|---|
| 180 | `>`-quoted ruling block — *"Integrated Noise plot is **not created at all**"* |
| 186 | `>`-quoted ruling block — the `noise` arm's sentence |
| 1657 | `*Note:*` on the `lin_points` caption — the moved noise warning |
| 3111 | `*Note:*` on the `lin_points` caution — the per-type arm |

**None is the select literal**; all four are caution prose about the plot not being created for
a 1-point linear noise sweep, two inside a quoted ruling block and two inside `*Note:*` text,
exactly as the receipt says. `Integrated Noise*` → 0. `Noise Spectral Density` → **0 in any
form**. Counted unhandled, correctly.

## 11 — Claim 10: the inherited claim, RE-DERIVED BY RENDERING

This is the one receipt 60 did not measure, and the one the whole of Deliverable B rests on.
`render60v.tcl` drove `ase::reconcile_plots` directly — with explicit scratch paths, so
`ase::rundir` is never consulted and nothing under `~/.xschem/` is touched — building a
plotmap sidecar and an ASCII rawfile whose recorded name matches each other but **not** the
registry's `select` glob, which is the registry arm's exact trigger.

```
ARM a1 ac   VERDICT mislabel  WHY the ac analysis in row 2 recorded 'Bogus Plot Name'
                                  where the registry declares 'AC Analysis', ...
ARM a2 tran VERDICT mislabel  WHY ... where the registry declares 'Transient Analysis', ...
ARM a3 noise VERDICT mislabel WHY ... where the registry declares 'Integrated Noise*', ...
                              WHY ... where the registry declares 'Noise Spectral Density Curves*', ...
```

**Four of the 15 literals rendered verbatim into a user-facing sentence**, two of them the
starred pair. The batch's lesson that a detector can be wrong in either direction does not
bite here: this is the rendered string, not a grep for a call. **Claim 10 is confirmed on its
own evidence, and the 15 are no longer resting on an inherited sentence.**

Arm a3 also shows the seed carries only `op dc ac tran`, so reaching `noise` required appending
a row — worth knowing for anyone re-running this.

---

## 12 — What I could NOT establish

1. **Whether the 7 ASE-L handles sit in the document sections receipt 60 names.** I confirmed
   the handle **ids** by exact block equality; I did not re-derive which prose section each
   lives in. The driver does not need it to mint.
2. **Whether any of the 53 reaches a second surface.** Same boundary receipt 60 drew. I
   confirmed `opt_help`'s callers in `src/` are two; a help string appearing elsewhere would be
   a second literal, not this one.
3. **The minting policy and the ratification.** Not mine. My job was the strings.
4. **Nothing was run against a simulator.** `/usr/bin/ngspice` was never invoked; the ngspice
   tree was read with `/usr/bin/grep` and `sed` only.

## 13 — Debts — nothing filed, nothing cleared, by me

* **No `rule`, no `look`, no `suite` written.** The ⚖ rule receipt 60 recommends is unchanged
  in substance by this pass, but **its supporting argument needs correcting before it is put to
  the user** (§9, 8b): the document concedes the principle for `Distortion Operating Point`
  only.
* **Five corrections for the driver, none of which blocks minting**: the four bare-path
  citations (§7), the `ngspice.txt` corroboration (§4), the `tnom` "dozens" (§4), the
  "two callers in the whole tree" scope word (§6), and the §B3 handle attributions (§8c).

## 14 — Hygiene

* **Read-only.** `R9_COPY_REVIEW.md`, `LEDGER.md`, `src/` and the suites were **not** edited.
  **The only file I created in the tree is this receipt.** `git status --porcelain -uall` is
  byte-identical to its state when I started — the same six untracked entries, one of which is
  receipt 60 itself — and HEAD is unmoved at **`f007fb03`**.
* **No git mutation** — no `add`, `commit`, `checkout`, `restore`, `stash`, `clean`, `push`.
* **`tests/run_regression.tcl` was NOT run** (issue 0990 — the driver runs T1 solo).
* **No simulation.** `/usr/bin/ngspice` never invoked, nor any other ngspice binary.
* **Nothing under `~/.xschem/` touched**; `$HOME/.spiceinit` untouched; the owed ledger
  untouched. Both probes write only into the session scratchpad, and `render60v.tcl`
  deliberately calls `ase::reconcile_plots` rather than `ase::reconcile_report` **because the
  latter resolves `ase::rundir`**, which for an empty `rundir` key is the shared
  `~/.xschem/simulations`.
* **The binary was given a path** — `./src/xschem --nogui --pipe -q --nolog --script …`, two
  launches, both rc 0. Never a bare `xschem`; **`--nolog`, never `--logdir`**. `--nogui` needs
  no display, so nothing reached `:0`, `:99` or the user's screen.
* **`/usr/bin/grep` throughout**, never the bare `grep`.
* **Every command carried a `timeout`** (30–520 s); both probes finished well inside theirs.
  **No waiting loop was written** — nothing here was asynchronous, so there was no deadline to
  get wrong and no turn ended waiting to be woken.
* **Positive sentinels, not FAIL-absence.** Each probe's last act is a unique sentinel line and
  the harness greps for it anchored (`^PROBE DONE$` / `^RENDER DONE$`), so a crashed or silent
  probe reports `NO SENTINEL`. Handed an empty domain both write `FATAL` and `exit 1` — I fed
  that path by construction (the `llength == 0` arms) rather than assuming it.
* **No `pkill`, no `pgrep -f`, no process matched by a pattern my own command line contained.**
  Hygiene measured **by process NAME and AGE**, which no shell argv can counterfeit:
  `ps -eo comm=,etimes= | awk '$1=="xschem"||$1=="wish"'` → **7 processes at 76 277–76 610 s
  (≈21.3 h)**, every one older than this pass by three orders of magnitude and consistent with
  the ≈21 h receipt 60 measured for the same set. The `awk` prints `NONE ALIVE` when it finds
  nothing, so the check can disagree with itself. **My two probes exited 0 and left nothing.**
* **I did not read the prior crew's scratch artefacts**, though they share this session's
  scratchpad. Mine are under `scratchpad/v60/`: `probe60v.tcl`, `probe.tsv`, `render60v.tcl`,
  `render/render.txt`, `extract_doc.py`, `doc_blocks.json`, `parse_receipt.py`, `receipt.json`.
