# 59c — adjudication of receipt 59 against receipt 59b (the unhandled-copy survey)

**Adjudicator:** third agent. **Did neither piece of work.** Every number below was re-derived from
the tree, not adopted from either receipt. Read-only: no tracked file edited, no git mutation, no
T1, no simulation, `/usr/bin/ngspice` never invoked, nothing written under `~/.xschem/`. The only
file created is this receipt.

**Headline: the verifier (59b) wins four of the six contested points outright, the survey (59) wins
none, and on the other two BOTH are wrong.**

* The survey's **19** is wrong.
* The verifier's **"17, or 28 with row 2 restored"** is right on the 17 — and wrong twice over on
  the rest: the restored class is **15**, not 11, and it is **upstream simulator text**, which puts
  it in a class the document already has a rule for.
* **The answer is 18**, because the one arm that was grepped hid a second finding, not just a
  wrong denominator.

**And the brief's instruction to assume a FOURTH `site`-trap instance was correct. There are at
least four more, and the first one is in the same dict as the third.**

---

## DECISION TABLE

| # | contested point | winner | evidence I took myself |
|---|---|---|---|
| **C1** | Group E: batch-added or pre-existing? | ⛔ **VERIFIER. All three are PRE-EXISTING.** | `ase.tcl:2339` ≡ `2f1fad58:…:2136`; `ase_window.tcl:9533,9536` ≡ `2f1fad58:…:5262,5265`. Both enclosing procs byte-identical across the blobs. |
| **C2** | can the provenance gate disagree? | ⛔ **VERIFIER. It cannot, for a composed string.** | Handed the three frames, the pre-batch blobs score **0 hits each** → gate says "batch-added" for three strings I had just proved pre-existing. Demonstrated, not argued. |
| **C3** | Group F: three headings or four? reachable? | ⛔ **VERIFIER. FOUR, and reachable — one fold-click.** | `On`/`Target`/`Kind`/`Values` all **0** exact doc entries; `Kind`'s two hits are R9-384 (Measurements list) and R9-537 (axis editor), verbatim different surfaces. `nz_build` is called unconditionally at `ase_window.tcl:5696`, gridding `frame $cw.noise` **inside** Choose Analyses. |
| **C4** | Direct Plot `select` labels: 0, 11, or 12? | ⛔ **BOTH WRONG. 15 capturable (18 distinct in all).** | Live contract: **11 types, 21 plot rows, 18 distinct `select` literals, 15 capturable / 3 opinfo.** Mechanism proven by **RENDERING**, not by call graph. |
| **C5** | `ase::echo`: 211/82 or 185/100? | ⛔ **VERIFIER on sites — BOTH WRONG on frames.** | `211 = 97+114` raw; `25` comment lines; `1` proc def; **185** true sites. Frames are **98**, not 82 and not 100. **And widening the domain surfaces a SECOND finding.** |
| **C6** | the honest bound | ⛔ **VERIFIER directionally — but BOTH door numbers answer the wrong question.** | 30 procs / 32 surfaces confirmed; the guard verdict is the verifier's, verbatim. Neither crew's "strings behind the doors" figure was ever checked against the document. |

**Plus findings that are neither crew's:** a **third `sp`-gated door** (§C6), and **four more
`site`-trap instances** (§6).

---

## C1 — Group E is pre-existing. The survey is wrong; this does NOT make it handled.

All three strings are present **verbatim, in byte-identical procs**, in the pre-batch blob:

| # | string | today | at `2f1fad58` |
|---|---|---|---|
| 13 | `return "$who — will not run"` | `ase.tcl:2339` (`ase::sim_label`, opens `:2325`) | `:2136` (opens `:2122`) — identical |
| 14 | `unsupported { return "$mode (NOT supported)" }` | `ase_window.tcl:9536` | `:5265` — identical |
| 15 | `if {$mode eq {}} { return "global default ([ase::sim_casemode_floor])" }` | `ase_window.tcl:9533` | `:5262` — identical |

I checked the obvious confound and it is clean. `will not run` has **4** hits in today's `ase.tcl`
against **2** pre-batch, so two are new — but they are `:13152` (a comment) and `:13258` (the
`disto` save-list refusal sentence), and `ase_window.tcl:4789` is a comment. **None is
`sim_label`'s suffix.** Group E maps unambiguously to the pre-existing site.

⚠ **Class, as the brief requires:** all three are **pre-existing and unhandled** — the ~152 class.
They are still real copy that has never been put to the user. Moving them is a reclassification,
not a dismissal.

---

## C2 — the gate cannot disagree, and this is not a hypothesis

The gate asks *"is this string present in the source as of `2f1fad58`?"* The survey normalises a
rendered string to its **frame** first. No frame exists in any source blob, because the source holds
`"$who — will not run"`, not `<entry> — will not run`. Measured directly:

```
frame [<entry> — will not run]   -> pre-batch hits: 0  => gate answers "BATCH-ADDED"
frame [<mode> (NOT supported)]   -> pre-batch hits: 0  => gate answers "BATCH-ADDED"
frame [global default (<mode>)]  -> pre-batch hits: 0  => gate answers "BATCH-ADDED"
```

…for three strings whose enclosing procs I had just shown byte-identical in that same blob. **The
gate returns "new" for every composed string it will ever be handed.** All nine of its controls are
literals, so all nine pass and none tests this.

This is the batch's signature defect — *a guard that cannot disagree* — and `CREW_BRIEF.md` states
the test that catches it: *"ask of every check you write: what does this do when it is handed
nothing?"* Handed a placeholder, this one says "new".

### Which of the 19 rest on it — and I closed the rest by hand

**Six of the 19 are composed frames**, so six rest on an answer structurally incapable of being
"no". Three are Group E. **I verified the other three directly**, finding the source literal and
confirming its absence from the pre-batch blobs:

| # | string | source today | pre-batch |
|---|---|---|---|
| 3 | `Offered because every build of this simulator has it…` | `ase.tcl:10504` | 0 |
| 4 | `ase: '<sim>' cannot run <type>, so it was not added to the bench.` | `ase.tcl:10608` | 0 |
| 8 | `axis '<name>' has no values, so there is nothing to sweep` | `ase.tcl:22034` | 0 |
| 19 | `…ran longer than <n> s and was stopped; the campaign continues with the next point` | `ase.tcl:22402` | 0 |

**The gate's defect cost exactly three wrong answers**; the remaining three composed strings are
genuinely batch-added. Its answers are worth nothing on their own for a composed string — they are
right here by luck, not by measurement.

**The fix:** a tenth control, one composed *pre-existing* string. `<mode> (NOT supported)` is the
obvious candidate, since it is now known-failing.

---

## C3 — Group F is FOUR, it is reachable, and the walk missed it for a nameable reason

**Four, not three.** Exact fenced-block entries in `R9_COPY_REVIEW.md`:

```
^On$ -> 0        ^Target$ -> 0        ^Kind$ -> 2        ^Values$ -> 0
```

`Kind`'s two are **different surfaces**, verified verbatim:
* **R9-384** (`doc:6475`) — *"the third column heading of the **Measurements list**, and its form label"*
* **R9-537** (`doc:8265`) — *"the **axis editor**."*

`ase::ui::lbl_nz_columns` (`ase_window.tcl:6074`) returns `{On Target Kind Values}` and is mentioned
**0 times** in the document. The survey's hedge — *"`Kind` is handled, which is itself the argument
that the other three should be"* — read correctly is an argument that **Group F is one bigger.**

**They are not behind an unopenable dialog.** `nz_build` is called **unconditionally** from the
Choose Analyses build path (`:5696`) and grids `frame $cw.noise` at **row 5 inside Choose Analyses**
(`:6312`). Its gates are `nz_type` non-empty (`:6297`) and the fold being open (`:6318`). There is no
`noise_editor`; the proc is `ase::ui::nz_editor` (`:6564`) and **Group F is not behind it** — the
headings are consumed at `:6340` inside `nz_build`.

### ⚠ Why the widget walk missed them — a class, not a one-off

The early return sits **before** the treeview is created:

```tcl
ase_window.tcl:6318   if {!$open} { ase::ui::apply_theme $w ; return $w }   ;# no treeview yet
…
ase_window.tcl:6340   foreach c $cols h [concat [ase::ui::lbl_nz_columns] [list {}]] … {
                        $w.tv heading $c -text $h
```

A walk that **opens** Choose Analyses and enumerates widgets sees the fold button `$w.hdr` and
nothing behind it. `$open` is false unless `dlg($key,nzopen) eq 1` — **default closed**.

**The blind spot is default-closed disclosure folds, and there are exactly two** — `nzopen` and
`advopen` (`chana_adv_toggle`, `:5325`), **both in Choose Analyses**. That is broader than the
verifier's *"per-type form state"* and far narrower than *"2 dialogs"*: an enumerable class of two.

### Two corroborations that settle it against the survey

1. **The noise editor's form labels ARE handled** — `Target:` = **R9-657**, `Kind:` = **R9-658**,
   `Estimates:` = **R9-659**, and the caption *"Noise sources are added at run time. Nothing is
   written to your schematic."* at `doc:9596`. **The document reached that surface.** Only the four
   table headings were missed.
2. **The second fold is handled too** — `▸ Advanced` and `▾ Advanced` each have an exact entry, and
   `It is under Advanced.` is handled at `doc:2106`. **The document crossed both folds. The walk is
   what failed.**

**Consequence: Group F needs no `look` debt**, contrary to receipt 59 §10. One fold-click inside a
dialog the survey already opened renders all four.

---

## C4 — BOTH CREWS WRONG. The number is 15, and I proved the mechanism by rendering.

### Proven by EMISSION, not by call graph

I drove the **real, unmodified** `ase::reconcile_plots` headless
(`./src/xschem --nogui --pipe -q --nolog --script …`), stubbing only the two *file readers*
(`plotmap_read`, `cap_raw_plots`) so the composer is shipped code. It emitted:

```
verdict=mislabel
why> the ac analysis in row 1 recorded 'Bogus Plot Name' where the registry declares
     'Operating Point', so results cannot be matched to the row that asked for them.
```

**`'Operating Point'` is the contract's `select` literal, interpolated verbatim into a sentence a
user reads.** `why` reaches the user at `ase.tcl:9835`:

```tcl
foreach s [dict get $v why] { ::ase::echo "ase: results -- $s" $tag }
```

— the run log, **the very surface the survey created Group G for**, on the argument that no widget
walk can reach it. Its *"Arm A rendered 0 hits"* is true and irrelevant: **nine of its own 19 are
marked `C`** (composer-only, never on a widget), so that standard would delete half its own answer.

**The document refuted the exclusion in writing, inside the corpus the survey was matching against**
— both confirmed verbatim by me:
* **R9-274** (`doc:4666`) — *"Here **$mwant is a GLOB pattern from the registry's `select` key**…"*
* **R9-276** (`doc:4690`) — *"the 'also computes' sentence, **which inserts the plot's `select`
  literal**."*

### The inventory — from the LIVE contract, not from either receipt

`ase::analysis_types ngspice` → **11 types, 21 plot rows** (`pss` carries no `plots` key):
**18 distinct `select` literals — 15 capturable, 3 `role opinfo`.** `ase::plot_capturable`
(`:9138-9141`) returns 0 only for `opinfo`, so the 3 reach the *"also computes"* sentence and **all
15 capturable ones reach the user only through the mislabel arm.**

**The 15, every one with ZERO exact doc entries:** `Operating Point`, `DC transfer characteristic`,
`AC Analysis`, `Transient Analysis`, `Integrated Noise*`, `Noise Spectral Density Curves*`,
`Transfer Function`, `Pole-Zero Analysis`, `Sensitivity Analysis`, `DISTORTION - 2nd harmonic`,
`DISTORTION - 3rd harmonic`, `DISTORTION - IM: 2f1-f2`, `DISTORTION - IM: f1-f2`,
`DISTORTION - IM: f1+f2`, `SP Analysis`.

### Where each crew went wrong

* **The survey excluded all of them. Refuted** — by rendering, and by its own corpus.
* **The verifier said eleven and undercounts its own finding by four.** Its parenthesis concedes
  that `AC Analysis`'s hit *"is inside the plotmap-record note at `:4869`, not an entry of its own"*
  and that `Sensitivity Analysis`, `Transient Analysis` and `Operating Point` *"appear as prose"* —
  which, by the document's per-surface handle model, means **those four are unhandled too.** I
  confirmed: `^AC Analysis$`, `^Sensitivity Analysis$`, `^Transient Analysis$`,
  `^Operating Point$` all score **0** exact entries.
* **`Integrated Noise` is a trap the verifier got right and I nearly fell into.** A substring grep
  gives **4** doc hits, but all four (`doc:180, 186, 1657, 3111`) are *caution prose about the plot
  not being created for a 1-point linear sweep* — not the select literal. Correctly **0**.

### ⚠ The classification matters more than the number

**All 18 select literals are ngspice's own plot names.** Measured against
`/home/analog/dev/ngspice/src`, every one resolves — `inp2dot.c`, `noisesp.c`, `noisean.c`,
`distoan.c`, `acan.c`, `span.c`, `pzan.c`.

**So the 15 are `upstream simulator text`, not ASE-L copy** — the *same class* as the 53 transcribed
option-help strings. That **collapses two open questions into one**: R9-276 is the precedent for
both and points the same way for both (*"listed because it is new text on a user's screen"* while
*"not ASE-L's wording to change"*). **The driver should not raise these as two rulings.**

### And the verifier's "asymmetry proof" is looser than stated

It claims the 3 opinfo literals are *"3 of 3 handled (2/2/1 hits)"*. Those are **substring** counts.
Exact entries: `NOISE Operating Point` **1** (R9-276), `AC Operating Point` **0**,
`Distortion Operating Point` **0** — the latter two only *named inside another handle's prose*
(`doc:4595`, `:4597`, `:4694`). **One handled, two mentioned-but-unratified.** The asymmetry is real
and points the right way; the "3 of 3" is not.

---

## C5 — the survey grepped the arm it said it did not, and the grep hid a second finding

### Sites: the verifier is exactly right

```
grep -c 'ase::echo'      ase.tcl  97   ase_window.tcl 114   -> 211   (exact)
comment logical lines             16                   9    ->  25
proc definition          ase.tcl:314                        ->   1
                                          true sites  80 + 105  ->  185
```

**`211` reconciles to the byte with a raw `grep -c`, including 25 comment lines and the proc
definition itself.** Receipt 59 §1 opens *"nothing here is counted from a source grep"*; for this
arm that is not so, and the number is the tell. First-argument split **129 literal / 37 bare `$var`
/ 19 `[call]`** — the verifier exact on all three.

### Frames: BOTH crews wrong. It is **98**.

The 129 literal sites collapse to **98** distinct frames (6 repeat; the big merge is `ase: @` at 21
sites). Crew 1's **82** is badly low; the verifier's **100** is high by two — and its own companion
numbers give it away: **95 frames with ≥2 English words and 93 with ≥3 are arithmetically consistent
with a 98-frame base, not a 100-frame one** (which would need 5 and 7 short frames rather than 3 and
5). No normalisation rule reproduces 100: single-token **98**, `$var`-vs-`[cmd]` **99**, three-way
**99**, names kept **110**, raw **118**.

### ⚠ And widening the domain surfaces a SECOND finding — so Group G is TWO

Of the 98 frames, **10 are batch-added** and **8 of those are already in the document**. Two are in
neither the document nor the pre-batch blob. One is crew 1's known item. **The other is new**, and I
verified it myself rather than adopt it:

```tcl
src/ase.tcl:22386    ::ase::echo "ase: campaign $tok did not start: $id" error
```

| check | result |
|---|---|
| present in `src/ase*.tcl` | **1** |
| present in `2f1fad58` blobs | **0** |
| present in `R9_COPY_REVIEW.md` | **0** (also `ase: campaign` → 0, `did not start` → 0) |

**So Group G's *"the only batch-added unhandled one"* was decided over a domain 16 frames too small,
by the one method §1 forbids — and it cost a real finding.** This is the survey's own lesson landing
on the survey: the `site` trap is a grep overstating a domain, and here a grep understated one.

⚠ **A method caveat worth recording**, because it changed the answer during the re-derivation:
matching candidate frames against the document by 3-word runs produces **false "handled"** on
generic English trigrams — it wrongly cleared crew 1's *own* known frame via `was stopped the`
(`doc:4715`). At 4-word runs the candidate set is stable, and five of seven candidates were then
correctly eliminated by keyword checks, exactly as the survey's §7c predicted: the document records
some of them in **source-expression** form (`ase: results -- $s` at `:4577`) and others in
**rendered** form inside a `*Note:*` (`:2128`).

---

## C6 — the bound understates itself; but BOTH crews' door numbers answer the wrong question

### The inventory: the verifier's numbers are right, its mechanism is not

**30 distinct dialog-creating procs**, confirmed: `ase_window.tcl` has 20 `toplevel $` matches, three
of which are `winfo toplevel`/`raise_activate_toplevel` (`:480`, `:2669`, `:11919`) → **17 real
creation sites**; minus the session window `ase::ui::open` (`:636`) and the shared helper
`dialog_frame` (`:2272`) → **15**; plus **15 distinct `dialog_frame` callers** → **30**. `ase.tcl`
has **zero**. **32 openable surfaces** is also right — but **not by the verifier's route**:
`listdlg_open` has exactly **one** call site (`:8805`, always `models`), so it is *not*
parameterised; the two extra surfaces come from `listdlg_editor` and from `simdlg_editor`
(`Add Simulator` / `Edit Simulator`). Two native file dialogs exist (`:9872`, `:15110`).

**25 is not the set, and the survey's *"2 dialogs never opened"* understates its blind spot.**

### The guard: the verifier is right verbatim; the survey is wrong on both halves

```tcl
7207:  if {[ase::ui::chana_committable $key] eq {}} { … ase::analysis_commit_refusal … ; return }
7212:  set cols [ase::ui::setup_colnames $_sim $type]
7213:  if {![llength $cols]} { return }          ;# <-- the sp gate, and it is SILENT
```

`chana_committable` (`:4868-4877`) tests only membership in `[ase::analysis_offered $sim]` — **any
of the 11 types**. Measured over the real domain, `analysis_setup_columns ngspice <t>` is **3 for
`sp` and 0 for all ten others**. So the survey's *"needs a committable `sp` analysis (it refuses
otherwise)"* is wrong twice: **the refusal is not `sp`-conditioned, and the `sp` condition does not
refuse** — it returns silently, saying nothing at all.

### ⚠ A THIRD `sp`-gated door neither crew named

`ase::ui::matrix_dialog` (`ase_window.tcl:7623`) carries the **identical** `chana_committable` guard
at `:7627` and is `sp`-only (`matrix ::ase::backend::ngspice::sp_matrix` is the only matrix hook in
the contract). I confirmed the guard in source. It adds ~10 strings, 2 of them prose.

### ⛔ But neither crew's "strings behind the doors" figure is a count of UNHANDLED strings

The verifier's **≈59** and the re-derived **~91** (47 behind `setup_dialog`, ~10 behind
`matrix_dialog`, 34 behind `nz_editor`) are both counts of *strings that exist behind a door*.
**Neither was ever checked against `R9_COPY_REVIEW.md`.** Since the document demonstrably reaches
into these surfaces already — R9-657/658/659 sit inside the very noise fold at issue — an unknown
and probably large fraction of both figures is **already handled**. So:

* the survey's *"3 strings behind 2 doors"* is wrong;
* the verifier's *"≈59, three times the whole reported finding"* is **not comparable to the 18** and
  should not be quoted as though it were;
* **the honest statement is that the unhandled count behind those doors is unmeasured.**

Two further corrections to the verifier's door numbers, both re-derived: `setup_dialog` is **47
distinct / 44 frames / ~25 prose**, not 31/14 (its 14 prose is right, but all 14 come from
`sp_row_check` alone — `sp_alter_lines`/`sp_export_lines` emit deck lines and no user-visible text);
and `nz_editor` is **34 distinct / 26 frames / ZERO prose**, not 28/~10 — its 28 is slot arithmetic
that double-counts `param2`'s relabels and misses the `V`/`A` unit doubling in `noise_quantity`,
and **there is no sentence in `nz_editor` at all**, so *"~10 prose"* describes nothing.

---

## 6 — ⚠ THE FOURTH `site`-TRAP INSTANCE — and it is in the same dict as the third

The brief said to assume a fourth exists. It does, and I found it independently before it was
corroborated.

**Every one of the 21 plot rows carries a `label` key. Nothing reads it.**

| key on a plot row | consumers |
|---|---|
| `select` | 8 |
| `role` | 4 |
| `results` | 4 |
| **`label`** | **0** |

Measured five ways, all agreeing:
* `grep -nE 'dict (get\|exists) \$[A-Za-z_]+ label'` finds 23 sites, **none on a plot row** — they
  are field descriptors (`$fd`), setup **columns** (`$_c`, `:5771`), stimuli **args** (`$_ad`,
  `:5839`), meas entries, matrix formats, remedies. The plots-row variable is `$p` throughout, and
  **`dict get/exists $p label` occurs nowhere.**
* No `ase::plot_label` accessor exists.
* `dict with` occurs **nowhere** in either file, so no destructuring read.
* **The schema validator never checks it**: the plots loop (`ase.tcl:5617-5675`) validates `select`,
  `role`, `when`, `results` — not `label`.
* The plots list is dereferenced at only two sites (`:5617`, `:9103`), which bounds the search.

The 21 values are exactly the kind that tempt a survey — `ac operating point`, `disto 2nd harmonic`,
`noise spectral density`, `sens ac`, `sp operating point`, `tf`, `tran`…

⚠ **The two errors sit in the same dict.** `select` walks as invisible and **prints to somebody**
(instance 3); `label` reads as content and **reaches nobody** (instance 4). A survey that examined
that dict got one key wrong in each direction.

⚠ **And the source states the governing rule twelve lines below the loop that omits the check**
(`ase.tcl:5679-5681`): *"This is issue 1428's S35 rule (**\"a key read by nothing is a key checked
by nothing\"**) pointed at a key that IS read."* The rule is written down, cited, applied to
`salvage` — while `label`, in the same dict, is read by nothing **and** checked by nothing.

### Three more, found in the same sweep

5. **Reverse instance — `ase::mc_dists` payload words ARE on-screen captions.** `ase.tcl:21608-21613`
   greps as pure sampler data; its values are the literal entry captions at
   `ase_window.tcl:14394-14395`, a treeview cell, the combobox items (`:14297`) and interpolated
   refusals. **Six rendered words with no `lbl_*` composer** — invisible to any survey that walks
   composers.
6. **Two `lbl_*` composers with no renderer** — `lbl_camp_dist` (`:13749`) and `lbl_camp_dist_of`
   (`:13756`), each with exactly one repo-wide hit: its own definition. The combobox they were
   written for is built bare at `:14296-14298`.
7. **Phantom renderings** — `lbl_setup_needs` composes `Every port needs a <column>.` for any
   column, but `setup_add` (`:7337`) only ever calls it with the first. `Every port needs a Port.`
   and `Every port needs a Z0 (ohm).` **can never reach a user**, and a composer-domain arm would
   have counted both.

⚠ **A counter-caution that cuts the other way**, and it belongs beside the rule: a key-name grep can
also **understate**, via dynamic dispatch. `dict get $sp post` has zero hits, which would make the
setup contract's `post` hook look dead — it is dispatched through a variable at `ase.tcl:6002`
(`set p [dict get $s $which]`) and invoked at `:24538`. **"Zero greps" is evidence, not proof.**

**None of §6 is copy and none of it is counted below.** It is recorded because the next survey will
meet it, and because a key with 21 plausible English values and no reader is precisely how the
393-vs-18 error happened the first time.

---

## 7 — THE FINAL NUMBER

**18 user-visible, batch-added, unhandled, ASE-L-authored strings.**

**Confidence: high on each of the 18 individually.** Every one was re-derived by me from the tree —
source hit present, **0** hits in both `2f1fad58` blobs, **0** hits in `R9_COPY_REVIEW.md`. Not one
is adopted on either crew's word, including the two I inherited as findings.

```
19   the survey's answer
 −3   Group E -- PRE-EXISTING (C1); moves to the ~152 class
 +1   Group F's `Kind` -- unhandled on this surface (C3)
 +1   Group G's second frame -- `ase: campaign <tok> did not start: <err>` (C5)
 ──
 18
```

### The four classes, kept separate because they carry different consequences

| class | n | what it means for the driver |
|---|---|---|
| **batch-added and unhandled** (ASE-L's own words) | **18** | mint handles; this is ⚖ R9's declared scope |
| **upstream simulator text** — 15 capturable `select` plot names | **15** | **one ruling, shared with the 53 help strings.** R9-276 is the precedent and points the same way for both |
| **pre-existing and unhandled** | ~152 **+3** (Group E) = **~155** | a separate pass; never put to the user in any ruling |
| **handled already** | — | `Kind` on *two other* surfaces (R9-384, R9-537); the noise editor's form labels (R9-657/658/659); both fold headers |

**If the driver rules upstream text IN, the answer is 18 + 15 = 33** (and the 53 come with it,
making 86). **If OUT, it is 18.** That is **one** question, not three.

### What the 18 EXCLUDES, and why

1. **The 15 upstream plot names** — user-visible and unratified, but ngspice's words verbatim
   (verified in the ngspice tree). Excluded by the document's own stated exclusion; listed because
   R9-276 cuts the other way. **The driver's call, not mine.**
2. **The 53 transcribed option-help strings** — same class. **I did not re-derive the 53**; the
   verifier confirmed it adversarially (53 EXACT / 0 partial, all to `cktsopt.c`) and I accept that.
3. **The ~155 pre-existing strings.** Not re-derived by me.
4. **The plot rows' 21 `label` values and the rest of §6** — not copy.
5. **Everything behind the surfaces neither pass reached** — see the bound below.

### ⚠ 18 IS A FLOOR, AND THE GAP IS NOT THE ONE EITHER CREW DESCRIBED

The survey's *"20 procs, 2 dialogs, run-time surfaces"* is set below what its own evidence implied:
one of its two "doors" was a **collapsed fold inside a dialog it had already opened**, and the class
it never named — **default-closed disclosure folds** — is a set of two it walked past twice. But the
verifier's replacement figure is not usable either: **≈59 counts strings behind doors, not unhandled
strings behind doors**, and nothing in either pass checked them against the document.

**What would close the bound**, in cost order, none of it needing a simulation:
1. **One click each on the two folds** (`nzopen`, `advopen`) in Choose Analyses.
2. **An `sp` analysis committed**, opening `setup_dialog`, `setup_scan_dialog` **and
   `matrix_dialog`** — the third door.
3. **A widget walk that drives per-type form state**, not merely dialog-open.
4. **A doc-match pass over the ~91 strings behind those doors** — the step both crews skipped, and
   the only one that converts a surface inventory into a finding.
5. **A second registered adapter**, for the capability-gated arms.

---

## 8 — Where each crew stands, plainly

**The verifier was right and the survey wrong** on C1, C2, C3, and on C5's site count — each on
evidence I reproduced independently rather than on its say-so. **On C4 and on C5's frame count both
were wrong**, and on C6 both answered a question other than the one that matters.

* **C4:** the survey excluded a class that is user-visible, which its own corpus already refuted in
  writing. The verifier caught that, then undercounted the class by four and rested its asymmetry
  on substring counts. The number is **15**, and the useful finding is not the count but the
  **class** — upstream text, sharing the 53's ruling rather than needing its own.
* **C5:** the verifier's 185 is exact and its 100 is not; the frames are **98**, and its own 95/93
  betray it. More importantly, **the short domain hid a real second finding**, which is the thing
  that moves the answer.
* **C6:** the survey's bound understates its gap; the verifier's replacement overstates its
  comparability.

**Credit where it is owed.** The survey's method — three render arms, the frame collapse, the
source-expression correction in its §7c, and two self-corrections that went against its own finding
— is sound, and **all 18 surviving strings hold up under independent re-derivation**. What failed
was a gate that could not disagree, a widget walk that could not see a closed fold, and one arm that
was grepped after the receipt said nothing was. The verifier's own contribution is likewise real:
four of six, and it found the `select` over-exclusion that is the single largest correction here.

---

## 9 — Debts to report upward — nothing filed, nothing cleared, by me

* ⚖ **rule** — the **18** want handles minted by the driver.
* ⚖ **rule** — **the 15 upstream `select` plot names + the 53 transcribed help strings**: one
  question, on R9-276's precedent. **Do not raise as two.**
* ⚖ **rule** — the **~155 pre-existing** strings have never been put to the user in any ruling.
* **No `look` debt for Group F** — contrary to receipt 59 §10. One fold-click inside an
  already-opened dialog pays it.
* **Defects worth issues, not rulings** — the plot rows' unread `label` key and the other three
  instances in §6, which the tree's own S35 rule already governs.
* **Nothing written to the owed ledger.** Reported upward, per the brief.

---

## 10 — Hygiene

* **Read-only.** `R9_COPY_REVIEW.md`, `LEDGER.md`, `src/` and the suites were not edited by me. The
  only file created is this receipt (`59c-unhandled-copy-adjudication.md`, the sole new entry in
  `git status --porcelain -uall`).
  ⚠ **`git status` is NOT unchanged, and the honest statement is worth more than the tidy one** —
  the same disclosure receipt 59 §11 made, for the same reason. Two tracked files show modified:
  * `R9_COPY_REVIEW.md` (+49/−1) — **the driver's**, the R9-731/732/733 block, already present at
    the start of this pass and documented by both prior receipts;
  * `LEDGER.md` — **also not mine, and newer than both.** It was **not** modified when this pass
    began; it became modified while I was running. I never opened it for writing. This is the
    driver working concurrently, which `CREW_BRIEF.md` warns is normal in this shared clone
    (*"YOU ARE NOT THE ONLY WRITER IN THIS CLONE"*). **A reader auditing this pass should attribute
    both hunks to the driver**; neither is anything an adjudication would produce.
* **No process of mine survived.** At the end of the pass the youngest live `xschem`/`wish`/`tclsh`
  is **71 541 s (19.9 h)** old — older than this pass by an order of magnitude, and consistent with
  the 19.4 h the verifier measured earlier. My three headless probes each exited under their own
  `timeout` (rc 0).
* **No git mutation** of any kind — no `add`, `commit`, `checkout`, `restore`, `stash`, `clean`,
  `push`. The pre-batch blobs were materialised read-only into the session scratchpad via
  `git show 2f1fad58:…`, which mutates nothing.
* **`tests/run_regression.tcl` not run** (issue 0990 — the driver runs T1 solo).
* **No simulation. `/usr/bin/ngspice` never invoked** — the ngspice tree was read with `grep` only,
  to establish authorship of the plot names.
* **Nothing under `~/.xschem/` touched**; `$HOME/.spiceinit` untouched; no deck under `sky130A/`.
* **The binary was given a path every time** — `./src/xschem --nogui --pipe -q --nolog --script …`.
  Never a bare `xschem`; **every launch carried `--nolog`**, never `--logdir`.
* **Every command carried a `timeout`.** No process outlived its command; no `pkill`, and no process
  matched by a pattern my own command line contained.
* Two measurement arms (the `ase::echo` domain and the dialog inventory) were delegated to
  subagents under the same read-only constraints; **their load-bearing conclusions — the new Group G
  frame and the third `sp` door — were re-verified by me in this tree before adoption.**
* Probe scripts are in the session scratchpad (`probe_c4.tcl`, `probe_label.tcl`, `probe_label2.tcl`,
  and the delegated arms' `echo_survey.py` / `frames2.py` / `frames3.py`); they are the evidence
  behind §C4, §C5 and §6, and nothing reads them automatically.
