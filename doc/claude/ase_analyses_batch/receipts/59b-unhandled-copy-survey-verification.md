# 59b — adversarial verification of receipt 59 (the unhandled-copy survey)

**Verifier:** separate agent. Did not do the work in receipt 59. Brief was to **disbelieve** it.
**Read-only.** No tracked file edited, no git mutation, no T1, no simulation, no `ngspice`
invoked, nothing written under `~/.xschem/`. The only file created is this receipt.

**Headline: the survey's METHOD is sound and its hardest numbers are exact — and its
HEADLINE ANSWER IS WRONG IN BOTH DIRECTIONS.** Three of the 19 fail the survey's own
provenance gate (they predate the batch), one group is undercounted by one, and the
12-string exclusion it is proudest of is an over-exclusion that the document it was matching
against **already refutes in writing, twice**.

**My number: 17 under the survey's own scope rules, 28 once the excluded class is restored.**
Not 19.

⚠ **And the "floor, not ceiling" caveat is doing more work than it admits.** ≈59 distinct strings
sit behind the two doors the survey names as closed — three times its whole reported answer — the
dialog inventory is 30 procs against the 25 it attempted, and the run-log arm was sized by a grep
that counted 25 comment lines. The bound is not honest-but-loose; it is stated at roughly a third
of what the survey's own evidence already implied.

---

## VERDICT TABLE

| # | claim | verdict | evidence |
|---|---|---|---|
| 1 | **19 strings in 7 groups** | ⛔ **REFUTED** | Group E's 3 are pre-existing (→16); Group F is 4 not 3 (→17); +11 restored by row 2 (→28) |
| 2 | **the 12 Direct Plot labels are not user-visible** | ⛔ **REFUTED — over-exclusion** | `select` is interpolated verbatim into two run-log sentences; **R9-274 and R9-276 say so in the document** |
| 3a | **53 of 60 help strings are ngspice's own text** | ✅ **CONFIRMED** | 60 distinct; 53 resolve, **all** to `cktsopt.c`, all as complete C string literals (53 EXACT / 0 partial) |
| 3b | **the remaining 7 all carry handles** | ✅ **CONFIRMED** | R9-199, R9-235, R9-255, R9-256, R9-257, R9-258, R9-670 |
| 3c | *"a `help` sentence for every catalogue row"* | ⛔ **REFUTED (descriptive)** | 67 of 247 rows carry `help`; 180 do not |
| 3d | *"the five handles … (R9-254…R9-258)"* | ⛔ **REFUTED (descriptive)** | only 4 of the 7 live there; **R9-254 is an `inert` reason, not a help string** |
| 4a | **domain sizes 247 / 19 / 8 / 11** | ✅ **CONFIRMED** | `dict size` on `sim_options`, `meas_kinds`, `meas_templates`, `analysis_types`; identical no-arg and `sim=ngspice` |
| 4b | Arm B composed the optsheet detail domain | ⚠ **PARTLY** | the enumeration omits 3 scope frames, 4 `opt_stored_verdict` arms and 6 `optsheet_preview` literals |
| 4c | **`ase::echo`: 211 sites, 82 decidable literals** | ⛔ **REFUTED — and it was GREPPED** | true sites **185**; 211 = raw `grep -c` including **25 comment lines + the `proc` def**. Distinct frames **100**, not 82 |
| 4d | **25 dialogs, 23 opened** | ⛔ **REFUTED** | **30 dialog-creating procs / 32 surfaces** exist; ≥5 procs (~20%) were never attempted |
| 4e | `~96` arg-taking spellers | ⚠ **PARTLY** | 118 named / 59 literal-returning / 135 union — 96 is inside the band, but **no criterion is stated** |
| 4f | 2 890 emissions → 828 distinct | ⬜ **NOT RE-DERIVED** | the dedup itself was not reproduced; the domains under it were (4a) |
| 5 | **provenance gate control-tested 9/9 both ways** | ⚠ **PARTLY — replicates, but cannot disagree** | 9/9 reproduced exactly; **all 9 controls are literals**, and the gate is structurally incapable of failing a *composed* string — which is how Group E slipped through |
| 6 | **positive control, re-found 4 of 6** | ⚠ **PARTLY — the receipt understates itself** | its own table shows **5 re-found + 1 correctly excluded = 0 missed**. It did not miss 2 |
| 7 | **118 `$`-or-`[` lines, 60 `<placeholder>` lines**; R9-188/666/225 | ✅ **CONFIRMED EXACTLY** | pre-edit doc: 727 entry lines, **118** and **60**. All three handles verified verbatim |
| 8 | **the bound is honest: 20 procs, 2 dialogs, run-time surfaces** | ⛔ **REFUTED — it understates its own gap** | ≈**59** distinct strings sit behind the two named doors, not 3; the dialog blind spot is ~7 surfaces, not 2; and Group F is behind **neither** door |
| 9a | filter swallowed the `wnflag` caveat, repaired | ✅ **CONFIRMED (self-consistent)** | not externally checkable; internally coherent |
| 9b | **document moved at 17:35:20; all 19 re-checked** | ✅ **CONFIRMED TO THE SECOND** | mtime `17:35:20.744`; diff +49/−1 is exactly the R9-731/732/733 block; 726→729 blocks, 730→733 handles |
| 10 | **read-only; nothing left behind** | ✅ **CONFIRMED** | one modified tracked file, and its diff is the driver's; youngest `xschem`/`wish` process is 19.4 h old |

---

## 1 — ⛔ Claim 2: the exclusion is an OVER-EXCLUSION, and the document already said so

The survey nearly reported 12 Direct Plot labels, then withdrew them on three grounds. **All
three are answerable, and two of them are answered inside the very document the survey was
matching against.**

### The mechanism the survey did not follow

`ase::plot_select` is read at two sites in `ase::reconcile_plots`, and **both feed user-visible
prose**:

```tcl
src/ase.tcl:9677   lappend expect [list $atype $ai [ase::plot_select $p]]   ; # captured
src/ase.tcl:9680   lappend unc    [list $atype $ai [ase::plot_select $p]]   ; # uncaptured
```

* **Path 1 — "also computes"** (`:9700-9704`): `unames` is built from `[lindex $u 2]`, i.e. the
  select literal, and interpolated: `"the … analysis also computes '[join $unames {', '}]'. …"`.
* **Path 2 — the mislabel arm** (`:9736-9737` → `:9773-9775`): `lappend mis [list … $got $sel
  registry]` where `$sel` **is** the select literal, rendered as
  `"the $mty analysis in row $mai recorded '$mgot' where $msay '$mwant', so results cannot be
  matched to the row that asked for them."`

Both land in `why`, and `why` reaches the user at `src/ase.tcl:9835`:

```tcl
foreach s [dict get $v why] { ::ase::echo "ase: results -- $s" $tag }
```

— **the run log**, which is the surface the survey itself created Group G for, on the explicit
argument that *"the run log is a surface no widget walk can reach."* The same argument that
justified Group G invalidates the exclusion.

### The document refutes it in writing, twice

Both of these are inside the 726-block corpus the survey extracted and matched against:

* **R9-274** (`R9_COPY_REVIEW.md:4662`) *Note:* — *"Here **$mwant is a GLOB pattern from the
  registry's `select` key**, so the quoted value may contain `*` and read oddly to a user, e.g.
  `where the registry declares 'Sensitivity Analysis*'`."*
* **R9-276** (`:4690`) *Where:* — *"the 'also computes' sentence, **which inserts the plot's
  `select` literal**."*

### The asymmetry is the proof

`ase::plot_capturable` (`src/ase.tcl:9138`) treats **only `role opinfo`** as uncapturable. So the
`opinfo` rows are the ones reaching "also computes", and the rest reach the user only through the
mislabel arm. Measured, every select literal in the contract against the document:

| role | select literals | in the document |
|---|---|---|
| `opinfo` | `AC Operating Point`, `Distortion Operating Point`, `NOISE Operating Point` | **3 of 3 handled** (2 / 2 / 1 hits) |
| `sweep`/`scalars`/`table` | 11 batch-added ones below | **0 of 11 handled** |

The document handles **exactly** the three that reach the sentence it knew about, and **none** of
the eleven that reach the sentence it did not. That is not a coincidence; it is the shape of the
gap.

**The eleven, all `doc=0` and `pre-batch=0`:** `DC transfer characteristic`, `DISTORTION - 2nd
harmonic`, `DISTORTION - 3rd harmonic`, `DISTORTION - IM: 2f1-f2`, `DISTORTION - IM: f1+f2`,
`DISTORTION - IM: f1-f2`, `Integrated Noise*`, `Noise Spectral Density Curves*`, `Pole-Zero
Analysis`, `SP Analysis`, `Transfer Function`.
(`AC Analysis`'s single doc hit is inside the plotmap-record note at `:4869`, not an entry of its
own; `Sensitivity Analysis`, `Transient Analysis` and `Operating Point` appear as prose.)

### Why each ground fails

| the survey's ground | why it fails |
|---|---|
| *"`select` is **OPAQUE TO CORE**"* | the schema header (`src/ase.tcl:4748`) says **"Core never parses it"** — a statement about *parsing*, not about visibility. A string can be un-parsed and still be printed. |
| *"Every reader is `reconcile_plots`/`plot_select` — matching machinery"* | the reader list is right; the characterisation is wrong. `reconcile_plots` is **also a composer of user-visible prose**, and it is the only composer of it. |
| *"Arm A rendered 0 hits for all twelve"* | true and irrelevant. Arm A is a widget walk; this surface is `ase::echo`. **Nine of the survey's own 19 are marked `C`** — composer-only, never on a widget — so this standard would delete half its own answer. |

⚠ **And this is the `site` trap's THIRD instance, arriving from the opposite side.** `site` was a
key that grepped as visible and renders to nobody; `select` is a key that walks as invisible and
**prints to somebody**. The survey built one detector, pointed it in one direction, and the second
error shape went straight past it.

---

## 2 — ⛔ Claim 1: three of the 19 predate the batch

All of **Group E** is present *verbatim and in the same proc* in the pre-batch blob `2f1fad58`:

| # | string | today | at `2f1fad58` |
|---|---|---|---|
| 13 | `return "$who — will not run"` | `src/ase.tcl:2339` | `pre_ase.tcl:2136` — identical |
| 14 | `unsupported { return "$mode (NOT supported)" }` | `src/ase_window.tcl:9536` | `pre_asew.tcl:5265` — identical |
| 15 | `if {$mode eq {}} { return "global default ([ase::sim_casemode_floor])" }` | `src/ase_window.tcl:9533` | `pre_asew.tcl:5262` — identical |

The surrounding procs (`ase::sim_label`, `ase::ui::simdlg_case_label`) are byte-identical across
the two lines. These are **pre-existing** copy — real, unhandled, and belonging to the 152 class
the survey reports separately, **not** to ⚖ R9's declared scope.

The other 16 all check out: present in `src/ase*.tcl`, zero hits in `R9_COPY_REVIEW.md`, zero hits
in the pre-batch blob. (Three needed a looser search than `grep -F` because they span Tcl
continuation lines: Group C #8 at `src/ase.tcl:22035`, Group G #19 at `:22403`, Group B #3 at
`:10504`.)

### And Group F is 4, not 3

The survey's own supporting argument is false. It writes: *"`Kind`, the fourth heading, **is**
handled (2 entries), which is itself the argument that the other three should be."* The two
entries are **different surfaces**:

* **R9-384** (`:6478`) — *"the third column heading of the **Measurements list**, and its form label"*
* **R9-537** (`:8269`) — *"the **axis editor**."*

`ase::ui::lbl_nz_columns` returns `{On Target Kind Values}` (`src/ase_window.tcl:6074`) and is
mentioned **0 times** in the document. So the noise table's `Kind` heading is unhandled too, and
Group F is four strings. The argument the survey used to hedge Group F is, correctly read, an
argument that Group F is one bigger.

**17 under the survey's own rules: 19 − 3 (Group E) + 1 (Group F). 28 with the eleven restored.**

---

## 3 — ⚠ Claim 5: the gate is 9/9 and it cannot disagree

The control test exists and **replicates exactly** — I re-ran all nine against
`git show 2f1fad58:src/ase{,_window}.tcl`: the four negatives absent (0 hits each), the five
positives present (1, 3, 12, 2, 5 hits). It discriminates in both directions. As printed, it is a
real control.

⚠ **But every one of the nine is a LITERAL string, and the gate's failure mode is COMPOSED
strings.** The survey normalises a rendered string to its frame — `<entry> — will not run`,
`<mode> (NOT supported)`, `global default (<mode>)`. No such frame exists anywhere in a source
blob, because the source holds `"$who — will not run"`. So for a composed string the gate can
only ever answer **absent → batch-added**. It is the batch's signature defect — *a guard that
cannot disagree* — and it is not hypothetical: **it is exactly how all three Group E strings were
certified as batch-added.**

A tenth control — **one composed, pre-existing string**, e.g. `<mode> (NOT supported)` itself —
would have failed and caught this. The brief's own rule applies verbatim: *ask of every check you
write, what does this do when it is handed nothing?* Handed a placeholder, this one says "new".

---

## 4 — ⚠ Claim 8: one of the two closed doors is not a door

`setup_dialog` is genuine: `src/ase_window.tcl:7200`, and it refuses at `:7207` when
`[ase::ui::chana_committable $key] eq {}` — echoing `ase::analysis_commit_refusal`, **which is
Group B #4 itself**. Fair.

**The noise editor is not a dialog at all.** `ase::ui::nz_build` (`src/ase_window.tcl:6290`) is
called unconditionally from the Choose Analyses build path at `:5696`, and it creates
`frame $cw.noise` gridded at **row 5 inside the Choose Analyses dialog** (`:6312`). Its only gate
is `ase::ui::nz_type` returning non-empty (`:6297`) — i.e. the selected analysis type declares a
`stimuli` contract. It does **not** require a selected noise entry: `dlg($key,nzsel)` is *cleared*
at `:6301`, never demanded. The headings are then set at `:6340-6341` (`$w.tv heading $c -text $h`).

Arm A **already opened Choose Analyses** — Group B #3 is `.ase4.chana.status`. Selecting a noise
type would have rendered `On`/`Target`/`Kind`/`Values` on a real Treeview.

**Two consequences, in opposite directions.** Group F is the survey's *best*-evidenced group, not
its *"lowest-confidence three … worth the driver's eye before minting"* — and the real hole in the
bound is one the survey never names: **Arm A walked dialogs but not per-type form state.** Every
type-conditional widget in an opened dialog is unmeasured, which is a much larger gap than "2
dialogs", and it is the gap most likely to hold more findings.

### And the door the survey named does not exist under that name

There is no `noise_editor`. The proc is **`ase::ui::nz_editor`** (`src/ase_window.tcl:6564`) and
it is a **panel inside the Choose Analyses noise fold**, not a dialog. Its selection guard is real
(`:6576-6579`, rejecting a `k` outside the entry list) — but **Group F is not behind it.**
`lbl_nz_columns` is consumed at `:6340` inside `nz_build`, whose only further gate is the fold
being open (`:6323 if {!$open} { … return $w }`). One click on `▾ Noise sources (n)` renders all
four headings. The survey attributed its own lowest-confidence group to a guard that does not
govern it.

`setup_dialog`'s guard is also merged wrongly. `chana_committable` (`:4868-4877`) requires only
membership in `[ase::analysis_offered $sim]` — **any of the 11 types**, not `sp`. The
`sp`-specificity lives one line later at `:7213`, `if {![llength $cols]} { return }` — a **silent**
return with no message (`analysis_setup_columns ngspice <t>` is 0 for all ten other types and 3 for
`sp`). So the refusal the survey names as Group B #4 fires for a *non-offered* type, not for a
non-`sp` one.

### ⛔ The two doors hide ≈59 strings, not 3

Driven over their real domains:

| door | distinct strings | of which prose sentences |
|---|---|---|
| `setup_dialog` + `setup_scan_dialog` + exclusive callees + the ngspice `sp` backend | **31** | **14** (5 fatal + 2 caution verdicts in `sp_row_check`/`sp_alter_lines`/`sp_export_lines`, each a sentence plus a fix clause) |
| `nz_editor` | **28** | ~10 (7 trnoise arg labels, 5 trrandom, 4 distribution values, 4 conditional relabels) |

e.g. `port '$src' has Z0 '$z'. A Z0 of 0 or less turns that source back into an ordinary source,
and the simulator then blames a DIFFERENT port for 'incorrect port ordering'`.

**That is three times the survey's entire reported finding, behind two doors it credited with
three strings that are not even there.** The bound is not merely a floor; it is a floor set well
below the survey's own knowledge of where it stopped.

### And the dialog inventory is short by a fifth

`src/ase_window.tcl` holds **17 `toplevel` sites** (minus the shared `dialog_frame` helper at
`:2270` and the session window `ase::ui::open` at `:636` = **15 direct dialogs**) plus **15
`dialog_frame` callers** = **30 distinct dialog-creating procs**. `listdlg_open` and
`listdlg_editor` are each parameterised over a 2-entry `listdlg` table, giving **32 openable
surfaces**, plus two native file dialogs. **25 is not the set.** At least 5 procs / ~7 surfaces —
roughly 20% — were never attempted, so the honest bound's *"2 dialogs never opened"* understates
its own blind spot by about 3.5×.

---

## 5 — ⚠ Claim 4a: the composer domain is enumerated short

Both receipt 59 §1 and `R9_COPY_REVIEW.md` §A11 describe `ase::ui::optsheet_detail` as composing
*"`help`, then `inert`/`owner`/`clamp`/`defect`+`caveat` by `ase::opt_offer`, then `results_why`,
`gate_why`, `leak_why`."* Read at `src/ase_window.tcl:9098-9150`, it **also** emits:

* three scope frames — `SCOPED: set for this analysis and put back after it`,
  `GLOBAL: this option is not offered per analysis`, `LEAKS: …`;
* four `opt_stored_verdict` arms — `CHANGED from the default …`, `SET to this simulator's own
  default`, `SET; this simulator declares no default to compare with`, `SET; this simulator's
  catalogue has no such option`;
* and the adjacent `ase::ui::optsheet_preview` emits six more (`above the analysis block`,
  `inside the analysis block`, `on the command line`, `in the run-directory start-up file`,
  `(nothing)`, `not delivered`).

**No finding falls out** — I checked all thirteen and every one has a doc hit and zero pre-batch
hits, so they are handled. But an incomplete composer enumeration is precisely the mechanism that
lost the `select` key, and this one is incomplete in the same document that carries the §A11
lesson.

---

## 6 — ✅ What survived, and survived well

* **Claim 7 is exact.** Counting entry lines of the **pre-edit** document (`git show HEAD:`),
  which is what the survey had: 727 entry lines, **118** containing `$` or `[`, **60** matching
  `<[a-z_]+>`. Both dead on. (Current worktree: 730 / 118 / 63 — the drift is the driver's three
  new blocks, each carrying `<nm>`.) The three deaths verify: **R9-188** at `doc:3547` as
  `[string toupper $grp] ([llength $names])` with all 14 group names in its note; **R9-666** at
  `doc:9713` as `  + <n> noise source(s)`; **R9-225** at `doc:3990` as `$sim declares no default
  for it, so there is nothing to put it back to`. **R9-002** `Start` at `doc:971`.
* **Claim 3 is exact on every load-bearing number** (delegated arm, independently re-derived two
  ways that agreed): catalogue is `variable sim_options` at `src/ase.tcl:29636`, **247 rows**, 67
  carrying `help`, **60 distinct** reaching `optsheet_detail`. **53 resolve, all to
  `spicelib/analysis/cktsopt.c`** — and against the adversarial form of the test (must appear as a
  *complete double-quoted C string literal*, not a substring, not a comment) the score is **53
  EXACT / 0 partial**. The "upstream" excuse holds in every case; no ASE-L sentence merely wraps an
  ngspice phrase. `Absolute error tolerence` is verbatim at `cktsopt.c:283` and `src/ase.tcl:29652`.
  The 7 non-resolvers all carry handles.
* **Claim 9b is confirmed to the second.** `R9_COPY_REVIEW.md` mtime `2026-09-16 17:35:20.744`;
  uncommitted diff +49/−1, containing exactly the R9-731/732/733 block under *"from ⚖ R9 itself —
  copy that reached the screen with no handle"*; header 730→733. Block/handle counts match the
  receipt's arithmetic precisely: HEAD **726** fenced blocks / **730** handles, worktree **729** /
  **733**. And the re-check's conclusion holds: all three new handles are `ase::analysis_gap_msg`
  (known item 5), so none covers any of the 19.
* **Claim 10 is confirmed.** `git status --porcelain -uall`: one modified tracked file,
  `R9_COPY_REVIEW.md`, whose diff is the driver's. The receipt is the only new file in the batch
  tree. No `xschem`/`wish`/`tclsh` process younger than **69 896 s (19.4 h)** exists — nothing from
  a pass that ran 17:35–18:05 today survives.
* **Claim 6 understates itself.** The table shows #1–#5 *re-found* and #6 *correctly excluded* —
  **0 of 6 missed**, not 4 of 6 found. The headline counts only those found before the §7a filter
  repair. The premise that two were missed is not supported by the receipt. The control is weak
  for a *different* reason worth saying: five of the six are option-sheet citations found by one
  arm, and known item 5 stopped being a control mid-survey when the driver handled it.

---

## 7 — ⛔ The one arm that WAS grepped is the one arm whose numbers are wrong

§1 of the receipt opens: *"nothing here is counted from a source grep. Every string below was
**produced by running the code that puts it on screen**."* For Arm A and Arm B that holds. For the
run-log arm it does not, and the arithmetic proves it:

* **`211` reconciles to the byte with `grep -c 'ase::echo'` across both files (97 + 114 = 211)** —
  a count that includes **25 comment lines** and the `proc ase::echo` definition itself. The true
  number of emission sites, with continuations joined and comments excluded, is **185**.
* **`82` decidable literals is also low.** 129 of the 185 sites carry a literal first argument;
  normalised, they are **100 distinct frames** (95 with two or more English words, 93 with three).
  The other 56 are 37 bare `$var` and 19 `[call]`.

So Group G — *"the only batch-added unhandled one"* out of 82 — was decided over a domain that is
**18 frames larger** than the one examined, by the one method §1 forbids. This is the survey's own
lesson landing on the survey: the `site` trap is a grep overstating a domain, and here a grep
understated one.

### Not re-derived

**`2 890 emissions → 828 distinct strings`** — the dedup and normalisation step was not reproduced.
Every domain feeding it was (§6, and the table above). Also not attempted: the **152** out-of-scope
class and the **53 / 152** tier boundaries as counts.

### Re-derived and sound

`dict size` on the four accessors gives **247 / 19 / 8 / 11**, identical with no argument and with
`sim=ngspice` — so the receipt's single numbers are safe. ⚠ Note for anyone re-checking: `llength`
on these returns **494 / 38 / 16 / 22**, exactly double, because all four are **dicts**. A
re-derivation reaching for `llength` would "refute" four correct claims. The domain sizes are
right.

---

## 8 — For the driver

1. **⚖ The eleven select literals want a ruling, not a re-survey.** They are batch-added,
   user-visible through `ase::echo`, and the document already handles their three siblings. If the
   R9-276 precedent governs (*"listed because it is new text on a user's screen"*), they are
   listed-without-ratification exactly as it was.
2. **Move Group E's three to the 152 class.** They are pre-existing.
3. **Group F is four** (`On`, `Target`, `Kind`, `Values`) and needs no `look` debt — the headings
   render inside Choose Analyses on opening the noise fold. The `look` the receipt proposes can be
   paid by one click, not by building a state.
4. **The gate needs a tenth control**: one composed, pre-existing string. Without it the gate
   certifies every composed string as batch-added.
5. **The real gap in the bound is per-type form state inside opened dialogs**, not "2 dialogs" —
   and behind the two named doors sit ≈**59** distinct strings, ~24 of them prose sentences. That
   is more than three times the reported finding, and it is reachable without a simulation: an `sp`
   analysis for one door, one fold click for the other.
6. **The run-log arm should be re-run over 185 sites / 100 frames**, not 211 / 82. Group G's
   *"only one batch-added unhandled literal"* was decided over a short domain, by a grep.
7. **Five dialog procs were never attempted** (30 procs / 32 surfaces exist, not 25). Worth naming
   which, before the next pass repeats the same 25.

---

## 9 — Hygiene

* Read-only. Editing `R9_COPY_REVIEW.md`, `LEDGER.md`, `src/` and the suites was not attempted.
  No `git add`/`commit`/`checkout`/`restore`/`stash`/`clean`. `tests/run_regression.tcl` not run
  (issue 0990). No simulation; `/usr/bin/ngspice` never invoked — the ngspice tree was read with
  `grep` only. Nothing written under `~/.xschem/`; `$HOME/.spiceinit` untouched. No `pkill`.
* The pre-batch blobs were materialised read-only into the session scratchpad via
  `git show 2f1fad58:…`, which mutates nothing.
* Every command carried a `timeout`. No process was started that outlived its command.
* The only file created is this receipt.
