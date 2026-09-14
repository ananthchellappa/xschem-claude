<!-- Provenance: doc/claude/ase_analyses_batch. Evidence in evidence/ — 29 files,
     of which evidence/design-of-record.md is the spine, evidence/00-critique.md
     resolves the inter-dossier contradictions, and evidence/builds.md is the one
     that actually built and ran PSS, CIDER and libngspice. NOTHING IN THIS PLAN
     HAS BEEN IMPLEMENTED. No file outside this directory was modified. Every
     ruling in it is still the user's to give EXCEPT ⚖ R1, which the user has
     answered -- Option A, keep `-b`, plus an always-salvage requirement. That
     answer is recorded in §0.12, in §0.1's *Salvaging a stopped run* block,
     in the ruling ledger's R1 row, and as Stage 2e and Stage 6f. The 26th
     evidence file is evidence/salvage.md, the measured basis for both.
     Files 27-29 are the VARIANT-SUPPORT amendment of 2026-09-10 --
     evidence/variants.md, evidence/fork-dependencies.md,
     evidence/fork-features.md -- which answer "most users won't have OUR
     ngspice". That amendment is §0.13, §0.1's three-binary table, the
     extensions to 1a/1b, sub-items 2f/2g, 6g, 7g, the new terminal Stage 16,
     five new refuse-list entries, decisions D42-D52, and ONE new unresolved
     ruling ⚖ R11 -- filed LAST, behind R2 and R10. -->

# Every analysis ngspice has, reachable — a staged plan for ASE-L

**What was asked for, verbatim:**

> Without changing any designs, we want to create a plan to capture every simulation capability of this version of ngspice in the ASE-L GUI (Analog Simulation Environment) of Xschem being worked on in /home/analog/dev/xschem-claude - the fluid-editing branch. If you look in the src directory of that folder, you will see ase_window.tcl and ase.tcl
>
> Is this a reasonable ask - to look at two projects? We want to make every simulation capability (all analysis types, and accompanying options) easily accessible through the GUI - user should be able to choose any supported analysis and set options easily. We want to be better than Cadence's Analog Design Environment.
>
> For now, all I am asking is for analysis (for Xschem, I believe just those two Tcl files should suffice, but Claude knows best how to proceed). For ngspice, you know the project and you know where it is hosted - which websites to use : https://ngspice.sourceforge.io/tutorials.html and https://ngspice.sourceforge.io/docs.html
>
> The customer for the plan document that will be created is a future Claude Code session operating on Xschem, to incorporate the features into the future GUI

**Spine.** `evidence/design-of-record.md`, which merged three competing designs after judging and
re-measured nineteen claims itself. Where this plan and the design of record disagree, this plan is
right and §0 says why — the design of record is evidence, not scripture.

| | |
|---|---|
| ngspice | `/home/analog/dev/ngspice`, `ver_50`, `ngspice-46-419-gccebdf2a2`; binary `build-ver_50/src/ngspice` |
| second ngspice — **and it is what a downloading user has** | `/usr/bin/ngspice`, self-identifies **`ngspice-45.2`**; Ubuntu 26.04.1 LTS package `45.2+ds-1`. It **has `pss`** and CIDER, which `build-ver_50` lacked when measured on 2026-09-09 (APPENDIX §1.7 `[A-M7]`). ⚠ `build-ver_50` was reconfigured with both on 2026-09-10 (§0.14), so the no-PSS fixture is now the third row's bare upstream build, and apt differs from both 46+ builds the other way (`pyplot`, `astate`, `ota`). Still the cheapest live test of Stage 2's four-state grid, because the binaries genuinely disagree — **and, since 2026-09-10, the binary a crew is required to test against** (§0.13, `CREW_BRIEF.md`) |
| third ngspice — stock upstream 47 | `…/workpad/builds/upstream47/src/ngspice`, built 2026-09-10 from `origin/pre-master-47` @ `c5cd68015` in **99 s**. Self-identifies **`ngspice-46+`** — **the same string as the fork**, with a byte-identical 134-row command and help table, which is why no version comparison can work (§0.13.3, APPENDIX §1.8) |
| xschem | `/home/analog/dev/xschem-claude`, `fluid-editing`, HEAD `2f1fad58` — **dirty and moving.** Every anchor below is a **proc name**; a line number appears only in parentheses, as a hint, and must be re-derived before it is quoted |
| ASE-L | `src/ase.tcl` (Tk-free by its own header, one guarded carve-out at `ase::open_state`) and `src/ase_window.tcl` (the `ase::ui::` widget layer) |
| owed ledger, today | **131 rule, 51 look, 8 suite** (`tests/headless/owed.sh`) |
| next free issue | **1400** (`doc/claude/issues/NUMBERING.md` tail, re-read at the moment of minting) |

**Scope.** Analysis only, as the user scoped it. Nothing here is implemented. Nothing outside
`doc/claude/ase_analyses_batch/` was modified by the pass that wrote this.

⚠ **THE BINARY TABLE ABOVE IS NOT THE WHOLE STORY, AND §0.13 IS WHY.** The plan was written against
the fork, and **most people who download this Xschem will run the ngspice their distribution
shipped** — measured, `45.2+ds-1` on the current Ubuntu LTS. There are **three** binaries in the
test matrix now, not two (`APPENDIX` §1.8, §0.1's three-binary table), and a crew tests against the
**stock** one as well as the fork.

---

## 0. Corrections — claims that did not survive checking

**The parameter-level inventory behind every stage is `APPENDIX_ngspice_analyses.md`; cite it, do not
restate it.** Where a stage below names an ngspice fact, the section of the appendix that holds it
measured is named beside the stage, and `evidence/<dossier>.md` stays as the second-level anchor.

Nine of them (§0.1–§0.9) are mine, taken against the two trees and the two binaries this session.
(⚠ **There are three binaries now, not two** — see §0.13 and `APPENDIX` §1.8.)
They matter because six were about to become a commit message, a test-row name, or a deferred
experiment that is in fact already answered.

⚠ **Two of the nine were themselves wrong and are corrected in place, not deleted** — §0.1 (the D4
claim) and §0.5 (the `.state` count). Each carries its own ⚠ CORRECTION block saying what it used to
say and which sibling document was right. That is the house rule working as intended: a refutation
stays visible at the place the wrong claim was made, because the wrong number is usually already
quoted somewhere else.

**§0.10 is a different kind of entry.** Not a claim that failed checking but a
**change of direction**, taken by the user after this batch was written and verified: who owns the
analysis registry. It is recorded here for the same reason the other nine are — a change of
direction stays visible at the place the superseded assumption was written down.

**§0.11** is an ordinary correction again: a probe design the pivot's own verification pass
proposed, measured on both binaries, and refused in the form proposed. It is written down rather
than dropped because the idea is good and the next reader will have it too.

**§0.12 is the one that changed an answer.** This plan's own ⚖ R1 write-up
said a `-b` run cannot keep a partial result. It can. The correction is recorded here, at the place
the wrong claim was made, because that claim *was* R1's cost line — and once it was measured false
the user could rule the cheap way and still get always-salvage.

**§0.13 is the newest, and it is the largest — and it is not a claim that failed checking either.
It is a STANDING ASSUMPTION that had never been named.** The whole plan was written against the
fork at `/home/analog/dev/ngspice`, and **most people who download this Xschem will run the ngspice
their distribution shipped**. It is written out in full, in eight parts, because a reader who misses
it will test on the one binary the plan is *not* worried about — and because two of the premises in
the question that produced it did not survive measurement.

**0.1 — `run_cmd`'s word order is pinned by SIX rows, not one.** The design of record's Stage 7 line
names only `test_ase_simreg_0931` row D4, which is true but **incomplete**. Six goldens pin
`<exe> -b [user args] [-n] [-D casemode=…] <deck> 2>@1`, and a seventh pins the exe alone:

```
A2   (:461)  [a_runcmd $DECK]                       == [list ngspice -b $DECK 2>@1]
B5   (:516)  [a_runcmd $DECK]                       == [list $STUB   -b $DECK 2>@1]
B6   (:535)  [a_runcmd $DECK]                       == [list $STUB   -b -q --foo $DECK 2>@1]
B11  (:572)  [a_runcmd $DECK]                       == [list $STUB   -b $DECK 2>@1]
B12  (:581)  [a_efields ng-rel {path}] + [a_runcmd] == [list [list $STUB] [list $STUB -b $DECK 2>@1]]
D4   (:791)  [lindex $D4SAID 0]                     == [list ngspice -b $DECK 2>@1]
L11  (:2487) [lindex $L11CMD 0]                     == $L11EXE          <- the EXE only
```

D4 reaches argv through `a_runcmd_said` (`:732-743`), which returns `[list $::a_rc2 $tag $msg]`
where `$::a_rc2` is `[a_runcmd $deck]` — so `[lindex $D4SAID 0]` **is** the argv list and it is
compared byte-for-byte. Anyone who re-baselined D4 and left the other five alone would leave **five
red rows**, not a green changed command line.

⚠ **CORRECTION TO THIS SECTION, 2026-09-09, and it stays visible because it was about to mislead a
crew.** An earlier draft of §0.1 asserted that D4 *"asserts nothing about argv"* and that only
A2/B5/B6/B11 pinned the word order. That was wrong on both halves: D4 pins the full command line,
and B12 pins it too. `DECISIONS.md` ⚖ R1 Option A and `LEDGER.md`'s Stage 7 block name D4 and were
**right**; this plan was the outlier. Both have been extended with the other five row names rather
than corrected, because there was nothing in them to correct.

**0.2 — Six lines of `test_ase_dialogs.tcl` drive a quick field by widget path, not five.** Measured:

```sh
grep -rn 'chana\.' tests/headless/test_*.tcl | grep -v 'chana\.btns\|chana\.types\|chana\.x\|chana\.opts'
  test_ase_dialogs.tcl:625   $top.chana.$fld delete 0 end
  test_ase_dialogs.tcl:626   $top.chana.$fld insert 0 $val
  test_ase_dialogs.tcl:629   send_return $top.chana.step {![winfo exists $top.chana]}
  test_ase_dialogs.tcl:655   $top.chana.stop delete 0 end
  test_ase_dialogs.tcl:656   $top.chana.stop insert 0 10u
  test_ase_dialogs.tcl:657   $top.chana.step delete 0 end
```

All six are inside G2/G2b and all six move to `$top.chana.form.<field>` at Stage 1. ⚠ **THE SENTENCE
THAT STOOD HERE — *"No other suite in the tree touches a Choose Analyses quick field by path"* — WAS
FALSE, AND IT COST 100 CHECKS (issue 1405, C47).** `tests/headless/test_ase_persist.tcl` row **G2**
drives the same widgets through a **variable** — `set w $top.chana`, then `$w.$fld` — so the
`grep 'chana\.'` this survey was made with could not see the block. Stage 1 moved the six literal
lines, left G2 behind, and nothing went red: the G-block is inside an `if {!$mainok}` skip so the
**headless arm reported `ALL PASS (44)` with the break live**, `run_regression.tcl` runs that file on
**neither** arm, and the raise was swallowed by the enclosing `catch`, taking G3–G11 with it. Display
arm 47 → **148** after the repair. **THE METHOD CORRECTION, which applies to every later stage: survey
for the widget LEAF NAMES (`\$w\.source`, `\$w\.step`), never for the toplevel's spelling.**

**0.3 — There are EIGHT hardcoded analysis-type lists in the analyses path, not seven.** The eighth is
the **print anchor's own** `foreach type {dc ac tran op}` inside `ase::backend::ngspice::render_deck`
(hint `:10929`), which is a *different literal, governed by a different rule* from the `anorder` list
twelve lines above it (hint `:10863`) — issue 1243's ruling versus issue 0964's. A registry pass that
collapses `anorder` and leaves the anchor loop alone has left the drift in place, in the one loop
whose job is to decide which analysis the Value column reports. The full reader set:

| # | reader | where |
|---|---|---|
| 1 | the `analyses` seed | `ase::state_default` |
| 2 | `anaargs` (`ac {points start stop dec}` — the drifted one) | `ase::ui`'s variable block |
| 3 | the radio `foreach t {op dc ac tran}` | `ase::ui::choose_analyses` |
| 4 | `anorder` + the emit `switch` | `ase::backend::ngspice::render_deck` |
| 5 | **the print anchor's own list** | `ase::backend::ngspice::render_deck` |
| 6 | the quick-field table | `ase::ui::chana_fields` |
| 7 | the five-name destroy list `{source start stop step points}` | `ase::ui::chana_show` |
| 8 | the viewer preference ranking | `ase::plot_sim_type` |

Three more are **declared out of scope** and must be named as such in Stage 1's acceptance rather than
quietly left: `ase::op_param_set`'s `{op dc}` allow-list (pinned by `test_rdw_seam_1245` G3/G3b),
`rdw.tcl`'s copy of the same list (its own comment, ruling DD-5), and `xschem.tcl`'s sim-type combobox
`{dc ac tran op sp spectrum noise constants table}`.

**0.4 — `OPTtbl` is 98 entries of which 57 are settable; "86" counted a narrower set.**
Measured on the ngspice tree, `src/spicelib/analysis/cktsopt.c:264-386`:

```sh
awk 'NR>=264 && NR<=386' cktsopt.c | grep -c '^\s*{ *"'            -> 98
… | grep '^\s*{ *"' | grep -c IF_SET                               -> 57
… | grep '^\s*{ *"' | grep -c IF_ASK                               -> 29
```

Two more counts finish the arithmetic (`APPENDIX_ngspice_analyses.md` §3.1): **2** rows carry both
flags (`tnom`, `temp`) and **14** carry neither (`itl3 itl5 acct list nomod nopage node opts numdgt
cptime limtim limpts lvlcod lvltim`). 57 + 29 − 2 = 84 with at least one flag; 84 + 14 = 98. ✓

The `IF_ASK`-only rows are `rusage` run statistics, not options. So the catalogue's **measured floor
is 57 + 163 = 220 rows** — 57 settable `OPTtbl` keywords plus `evidence/hidden-vars.md`'s 163
`cp_getvar` variables at 304 call sites, the two sets *provably disjoint*. "~250" was an estimate;
quote 220 and let mechanism-D and mechanism-E rows (`evidence/options.md` §1) carry it upward.

⚠ **CORRECTION TO THIS SECTION.** An earlier draft said *"'~86 keywords' is not a measured number"*.
It was measured — over a **narrower set**. `evidence/hidden-vars.md` §2 says `OPTtbl` "has exactly
**86** rows — 57 `IF_SET`, 27 `IF_ASK`, plus `itl3` and `itl5` which are neither", and 57 + 27 + 2 =
86 exactly: its arithmetic is right and its scope is `IF_ASK`-**only** plus two named strays. What
it missed is the other twelve neither-flag rows. **The table is 98. The settable floor is 57.** Both
numbers are right about different questions; do not "fix" hidden-vars, cite the scope.

⚠ **The siblings said "~250" and have been corrected in this pass, 2026-09-09**: `DECISIONS.md` D33
and `LEDGER.md`'s Stage 7 blurb now read 220 with the count beside them, each carrying its own
visible ⚠ CORRECTION line. `LEDGER.md`'s debt table was stale in the same way and is fixed under
§0.6/§0.7/§0.8. If any of the three has drifted back, this plan is the authority.

**0.5 — The on-disk `.state` count is 105; 104 are committed, and the tree's comments are right.**

```sh
find . -name '*.state' -not -path './.git/*' | wc -l     -> 105     (the working tree)
git ls-files | grep -c '\.state$'                        -> 104     (what the repository holds)
```

The 105th is `sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/tb_bandgap.state`, left
untracked by the UX batch's Save State item — a scratch bench, not a golden.

`test_ase_core.tcl` (`:207`, `:239`, `:246`), `test_ase_persist.tcl` (`:167`, `:357`, `:395`),
`test_ase_dialogs.tcl` (`:765`), `test_ase_final.tcl` (`:532`, `:662`, `:942`, `:956`),
`test_ase_simdlg_0937.tcl` (`:1940`) and `test_ase_simreg_0931.tcl` (`:2718`, `:2731`, `:2904`) all
say **"104 committed `.state` files"** and are all **right**. **Do not change those comments.** 104
is the acceptance number because the five byte-identity rows walk what git tracks:
**F3** in `test_ase_final.tcl`, **G3** in `test_ase_final_gf180.tcl`, **R4** in `test_ase_core.tcl`,
**V4** in `test_ase_view.tcl`, **R2** in `test_ase_persist.tcl`. Re-count at the moment of asserting
— the on-disk number moves whenever somebody saves a bench.

⚠ **CORRECTION TO THIS SECTION, 2026-09-09.** An earlier draft of §0.5 was headed *"The committed
`.state` count is 105; every comment in the tree still says 104"* and told a crew to *"fix the number
in the comments of whichever file a stage touches"*. That was backwards, and it would have replaced
fourteen correct comments with a wrong number. `LEDGER.md` ("105 on disk, 104 in git … **the
acceptance number is 104**"), `CREW_BRIEF.md` ("105 is the count on disk; **104 are committed**") and
`DECISIONS.md` D3 were right the whole time; this plan was the outlier, and the six places it
propagated "105 committed" have been changed to 104.

**0.6 — CLOSED BY MEASUREMENT, not deferred: open question M3. A bare `write <raw>` writes exactly
what `write <raw> all` writes.** The design of record listed this as an experiment that must happen
*before Stage 6*, because if the bare form dropped vectors the walk would silently lose NOISE traces.
Run this session, one deck, three plot kinds, both forms:

```
                                    bare `write f`        `write f all`
Integrated Noise                    2 vars / 1 point      2 vars / 1 point
Noise Spectral Density Curves       3 vars / 3 points     3 vars / 3 points
Sensitivity Analysis              102 vars / 3 points   102 vars / 3 points
```

**The walk may keep today's bare form.** The deck is quoted in full at APPENDIX **§6.3 `[A-M5]`**,
including the `setplot previous` pair — re-run there today, `AC Analysis` 4 vars / 3 points,
`Integrated Noise` 2 / 1, `Noise Spectral Density Curves` 3 / 3, **bare and `all` identical on every
one**. ⚠ And the probe found the trap that hides this: **without `set appendwrite`, `write`
TRUNCATES.** The first two runs of the experiment showed exactly one plot
per file and would have been read as *"the walk loses plots"*. Any measurement of the writer must
carry `set appendwrite`, which the real deck already does.

**0.7 — CLOSED BY MEASUREMENT: open question M4. All five DISTO literals and both SENS ones.**
One deck, `foreach p $plots / setplot $p / echo "PLOT $p |$curplotname|"` — the DISTO half is quoted
in full at APPENDIX **§2.9 `[A-M4]`** and re-run there today:

```
PLOT const   |constants|
PLOT disto1  |DISTORTION - 2nd harmonic|          <- disto dec 2 1k 10k        (2 plots)
PLOT disto2  |DISTORTION - 3rd harmonic|
PLOT disto3  |DISTORTION - IM: f1+f2|             <- disto dec 2 1k 10k 0.9    (3 plots)
PLOT disto4  |DISTORTION - IM: f1-f2|
PLOT disto5  |DISTORTION - IM: 2f1-f2|
PLOT sens5   |Sensitivity Analysis|               <- sens v(mid) dc
PLOT sens6   |Sensitivity Analysis|               <- sens v(mid) ac dec 2 1k 10k
PLOT noise6  |Noise Spectral Density Curves|
PLOT noise7  |Integrated Noise|
PLOT op7     |Operating Point|
```

Three things fall out. The IM literals are exact and go straight into the registry. **Two SENS
analyses share one literal**, so the `Plotname:` string cannot be the identity. And the creation
order is *spectrum first, Integrated Noise second*, which is why the `setplot previous` walk emits
`Integrated Noise` then `Noise Spectral Density Curves` into the sidecar.

**0.8 — CLOSED BY MEASUREMENT: open question M6. The DISTO segfault is upstream, not a `ver_50`
artefact.** `/usr/bin/ngspice`, which self-identifies as **`ngspice-45.2`** — a different, released
build that had never been run against this deck — dies the same way:

```
build-ver_50/src/ngspice -b d1.cir  ->  Segmentation fault, rc 139
/usr/bin/ngspice         -b d1.cir  ->  Segmentation fault, rc 139   (ngspice-45.2)
```

`d1.cir` is quoted in full at the end of this document (*One upstream bug this plan found*) and again
at APPENDIX **§2.9 `[A-M6]`**; it is four lines plus a `.control` block, and it was re-run on both
binaries today. ⚠ The design of record cited it as `../dor/d1.cir`; **that directory no longer
exists** — see `README.md`. Never cite a deck by a path outside this batch.

**File it.** `distoan.c` calls `SPfrontEnd->OUTpBeginPlot` at five sites (`:516`, `:540`, `:563`,
`:584`, `:606`) and **discards the return at every one of them**, then dereferences the plot handle a
few lines later in `CKTacDump`. `acan.c` shows the one-line fix pattern:

```c
error = SPfrontEnd->OUTpBeginPlot(ckt, ckt->CKTcurJob, …, &acPlot);
tfree(nameList);
if (error) return(error);                 /* acan.c — distoan.c has no such line */
```

The GUI-side mitigation is required whether or not the fix lands; a user's ngspice will be 45.2 or 46
for years.

**0.9 — RECONFIRMED this session, third independent time: the three traps this plan is built on.**

| probe | result |
|---|---|
| `.control` with `save v(nosuchnode)` + `disto` (ASE-L's exact deck shape) | **rc 139** |
| the same with a `.save all` card above `.control` | rc 0 |
| `.control` with `disto` + `op` and **no save at all** | rc 0 |
| `ac lin 2 1k 11k` then `let n2 = length(frequency)` | `n2 = 1.000000e+00` |
| `ac lin 3 1k 11k` | `n3 = 3.000000e+00` |
| `vp(mid)[0]` after `ac dec 10 1k 10k` | `-6.28310e-03` |
| the same after `set units=degrees` | `-3.59995e-01` — a factor of **57.2958** |

The trigger for the segfault is **a save list that resolves to nothing**, not "a narrowed save" and
not "no save". A refusal written the other way round refuses a deck that works.

**0.10 — A CHANGE OF DIRECTION, not a refuted measurement: `ase::analysis_types` IS the simulator's
adapter, and ASE-L owns only the schema.** This plan was authored treating the registry as ASE-L's
own table of analysis types, which *happened* to be reachable through an optional backend hook so a
second simulator could override it one day. The user has since settled the ownership the other way
round, on the ADE-L precedent: **the third-party tool vendor does the integration.** Xschem is not
responsible for making ASE-L work with any particular ngspice. What Xschem owes is a framework any
simulator's coding agent can integrate against — the user registers a simulator under *Setup >
Simulators*, gives it a path, and that simulator's analyses, their fields, their emit syntax, their
options and their result names arrive with its **adapter**, not from ASE-L's source. §1 states the
doctrine; `DECISIONS.md` **D34**–**D37** record it as decisions.

⚠ **No stage is invalidated by this, and nothing in it corrects a measurement.** The mechanism
Stage 1 designed was already adapter-shaped: `ase::analysis_types` resolves an OPTIONAL
`analysis_types` hook and falls back to `{}` — in Stage 1a's own words, *"NEVER to a literal list,
because a literal fallback is the ninth copy"*. What changed is **ownership and intent**: that hook
is not an override point, it **is** the contract, ngspice is its first content rather than its
built-in default, and the reason the four gates and the four-state grid exist is that the adapter
says what *could* exist while the probe says what this binary *has*. The consequences are additive
and each is named where it lands — Stage 1 gains sub-item **1e**, the paper check of the schema
against a second simulator, before its byte-identity acceptance is claimed, **and the naming rule
that decides which side of the line each later proc is on**; Stage 2 gains **2d**, the
*Setup > Simulators* gesture the doctrine is built around and what the grid says when a registered
simulator has no adapter; Stage 7 states that the 220-row option catalogue is the **adapter's**
content and not a variable in `ase.tcl` (`DECISIONS.md` **D33**'s amendment said Stage 7 would settle
that, and this is it); a new terminal **Stage 15** sketches the conformance harness a second adapter
would need; *Sequencing* gains the adoption order that the adoption goal implies; and the refuse-list
records the refusal of a sandboxed manifest format. **Stages 0–14 keep their numbers, their content
and their order**, and the space is **0–15, frozen** from that point on — the salvage amendment of the
same day added no stage either, riding as sub-items **2e** and **6f**. This entry exists so a future
reader does not re-litigate whose table this is. ⚠ **The variant amendment later that same day added
exactly one number — a new terminal Stage 16 (§0.13) — and renumbered nothing**: its other items ride
as extensions to **1a/1b** and as sub-items **2f**, **2g**, **6g** and **7g**.

**0.11 — REJECTED AS PROPOSED, and measured this pass: the bare-verb capability probe cannot ride the
existing capability deck, because on a build that HAS the verb it runs the analysis.** The pivot's
verification pass proposed adding the bare command word beside `help <verb>` in the same deck as a
cross-check, on the ground that it reads the command table rather than the help database and is
therefore immune to **M15**. The immunity is real; the placement is not. Measured 2026-09-10, both
binaries, on a deck carrying **no devices at all**:

```
build-ver_50, .control in a -b deck:  pss -> pss: no such command available in ngspice
                                      sp  -> parameter error, "sp simulation(s) aborted"
                                      op  -> RAN. "No. of Data Rows : 1"
/usr/bin/ngspice, same deck:          pss -> STARTED A PSS RUN and did not return inside 30 s
```

A deck always has a circuit, even an empty one, so inside `.control` the word is a **command, not a
question** — and on a user's real deck that is an unannounced simulation with the user's own run
directory underneath it. The probe is only safe with **no circuit loaded**, and the only transport
that offers that is `-p`:

```
printf 'pss\nsp\nop\nquit\n' | <exe> -p
  build-ver_50      pss: no such command available in ngspice / there aren't any circuits loaded. x2
  /usr/bin/ngspice  there aren't any circuits loaded. x3          (all three verbs exist)
```

Plain stdin is not a substitute — without `-p` ngspice reads those words as a **netlist** and answers
`Error: incomplete or empty netlist`. So the leg is worth having and it was **⚖ R1's to enable** —
**R1 is now answered Option A, so it is deferred with `-p`**, and it is one of the three things that
still argue for that transport (the *Deferred* table). It is recorded at Stage 2b as a second leg of
**Detect**, where a run is already paid for, and never in the cached fast path. This entry exists so
the next reader does not re-propose the one-line version.

**0.12 — WRONG, and this is the correction that let ⚖ R1 be answered the cheap way: a `-b` run
CAN keep a partial result.** `DECISIONS.md`'s ⚖ R1 *Trade-off* paragraph costed Option A with
*"`-b` costs nothing now and leaves the only measured capability gap — "stop and keep what you have"
— permanently open on a single long run"*, and this plan's *What this plan refuses* said the same
thing in one line. Both were wrong.
`stop` / `resume` checkpointing works in batch, on the stock binary, and it **preserves the
`.control` deck shape every stage of this plan depends on** — no argv change, so none of the six
`test_ase_simreg_0931` rows that pin `run_cmd` move.

MEASURED 2026-09-10 against `build-ver_50/src/ngspice`, in ASE-L's own deck shape (one `.control`
block, `set appendwrite`, `op` then `ac` then a checkpointed `tran`), killed with **SIGTERM 6 s into
an 80 ms transient — rc 143**:

* `<cell>_ase.raw` holds the completed `op` and `ac` plots **intact**; `load` gives `const op1 ac1`;
* `<cell>_ase.raw.ckpt` is **153,600,270** bytes holding one Transient Analysis plot of **4,800,000**
  points, `maximum(time)` = **4.799992e-02** of the 0.08 s asked for — **60 % of the run kept out of
  a hard kill**, in a file that loads. (4,800,000 × 4 vectors × 8 bytes = 153,600,000, plus a short
  header. This line read 192,000,311 until 2026-09-10 — 40 bytes a row, i.e. five vectors — which is
  correction **C35**;)
* the deck's completion echo is **absent from the log**, which is the only thing that says the run
  was aborted: `$sim_status` is **0** after a stop, and so is the exit status of a deck that reaches
  its end.

⚠ **The primitive is `stop after <points>`, and the obvious `stop when time > X` deck does NOT
work.** A `stop when` is not disarmed when it fires: its `resume` advanced the run by **one point**
and stopped again, so that deck simulates **12.5 %** of what it was asked for and exits **rc 0**.
Written into a stage as-is it would have shipped a checkpoint loop that silently truncates every run
long enough to matter. `evidence/salvage.md` §3.1–§3.2 is the measurement; the *Salvaging a stopped
run* block of §0.1 *Measured facts* below carries the numbers the stages cite, and **Stage 6f** is
the work.

What does **not** change: R1's recommendation, which the user has now ruled on — Option A, keep
`-b`. What does: R1's cost line, and `-p`'s justification, which is no longer about whether work
survives a Stop. Batch aborts in **a few milliseconds at worst**, SIGTERM and SIGKILL
indistinguishable (`evidence/salvage.md` §4.2) — at or below the *"under 5 ms"* figure
`evidence/builds.md` credits to `-p`. `-p` does not buy a *faster* abort; it buys a
**non-destructive** one. The ruling ledger's R1 row carries the
answer and the requirement that came with it.

**0.13 — THE WHOLE PLAN WAS WRITTEN AGAINST THE FORK, AND MOST USERS WILL NOT HAVE IT.** This is
not one wrong claim but a **standing assumption** that had never been named, so it is written here
in full rather than as a table row. Added 2026-09-10 by the variant-support amendment; its evidence
is `evidence/variants.md`, `evidence/fork-dependencies.md`, `evidence/fork-features.md`; its
reference tables are `APPENDIX` §1.8 and §7.5; its decisions are `DECISIONS.md` **D42–D52**; its
one unresolved question is ⚖ **R11**, filed **last**.

The user's framing: *"most users who download our Xschem won't have our ngspice … there probably
needs to be a stock 'basic' ASE-L which can fire up the needed hooks after detecting the version of
ngspice the user has said to use."* Two of that sentence's premises did not survive measurement,
and the second is what decides the architecture.

**0.13.1 — The good news first, because it changes the priority of everything below.** MEASURED: on
apt 45.2 — the ngspice the current Ubuntu LTS ships — ASE-L's full render (`.options savecurrents`,
`.temp`, `.save all`, two node `.save`s, two `.save @m.xi1.m1[…]`, `.control` with
`set appendwrite`, `set filetype=ascii`, the `$sim_status` guard after each analysis, `remzerovec`,
one `write` per analysis, `print`) produces **rc 0, 2 plots, identical `Variables:` blocks and
identical printed values** to the fork. `sim_status` exists on 45.2; `set appendwrite` appends on
45.2; the save list is sticky-forward on 45.2, so §0.1's *op-last* invariant is correct there. The
capability probe already answers correctly on 45.2 and `ase::cap_altshow_verdict` already withheld
tier `d` from it — **correctly, with no version number anywhere.** ⚠ **That measurement covers the
`op` and `tran` deck shapes ASE-L emits TODAY, and nothing else.** It is not a statement about the
multi-plot analyses Stage 6 adds; see 0.13.7.

**0.13.2 — The fork does NOT implement a blanket OP device-info save.** The user's question names
it as one of the fork's three additions. Three ways of checking, all negative
(`evidence/fork-features.md` §1): a grep for `saveopparam|saveoppoint|saveopinfo|oppoint|opparams|allop`
over the fork returns nothing; none of the 207 fork-only commits adds one — the fork's entire diff
to `src/frontend/breakp2.c`, which is the `save` grammar, is **two `eq`→`eqc` substitutions**; and
`save @m.xo1.xi1.m1[*]` fails byte-identically on apt 45.2 and on the fork. What exists is a
**request document** (`doc/claude/ngspice_enhancement_request_op_parameter_saving.md`, status line
*"draft — not yet sent"*) and, on the ASE-L side, the four-shape `ase::op_save_tier` workaround.
⚠ **And the one tier that behaves like a blanket save — tier `d`, `set altshow` + `show all >` — is
UPSTREAM, not fork.** It needs `10276f993` (2026-07-07); `git tag --contains 10276f993` returns
**nothing**, so it is in `pre-master-47` and in **no release**. On that axis fork == stock 47.

**0.13.3 — Detecting the version cannot work, because stock 47 and the fork are indistinguishable
by inspection.** MEASURED, and this is the design-deciding finding: both print `ngspice-46+` for
`-v` and for `version -v` (`configure.ac:19` is `m4_define([ngspice_major_version], [46+])` in both
trees, untouched by the fork); all **134** `spcp_coms[]` names are present on both; a join of the
two 134-row help-string lists filtered to rows that **differ** is **empty**; `devhelp` is
identical. Only the build timestamp differs, and that records whoever ran `make`. **So a
version-keyed capability table cannot express what ASE-L needs to know**, and `version_line` may be
displayed and logged but **never compared** (**D44**) — enforced by a conformance grep, not by a
convention.

**0.13.4 — "Basic" and "enhanced" cannot be two modes, because the subsets overlap without
nesting.** MEASURED: apt 45.2 has `pss` (it runs; `$plots` gains `pss1`) and CIDER's five device
families, which **neither** 46+ build has; the 46+ builds have `pyplot`, `astate` and `ota`, which
45.2 lacks — and `pyplot` has no `#ifdef`, so no rebuild recovers it. **Capability moves in both
directions at once**, no binary is the basic one, and a two-mode UI must make a false statement
about one axis whichever box it puts 45.2 in. The plan therefore has **one** ASE-L with **N feature
gates and zero version comparisons** (**D45**) — which is also what the tree already does: four
`op_save_tier` shapes from three measured keys, a casemode chooser offering exactly the measured
set, and no version number anywhere.

**0.13.5 — What a stock user actually loses is coverage and speed, not correctness.** On the user's
own `tb_bandgap`: tier `d` is 2 deck lines against tier `c`'s **468** `.save` cards; **212** devices
covered against 78; 88 parameters per MOSFET available to the Results Display Window against 6 — and
the uncovered set includes **the two PNPs that are the bandgap reference**, 24 resistors, 38
capacitors and 12 B-sources. Where both cover a device they agree to 4.70e-06. ⚠ **No column of the
Outputs pane goes empty on stock ngspice**: its Value column is filled from the `print` lines ASE-L
emits into the run log, and its `save_options_cell` column shows the Save-All blankets, which map to
`.save all` and `.options savecurrents` — in every ngspice ever released. Device OP numbers feed two
*other* surfaces, schematic annotation and the Results Display Window.

**0.13.6 — ASE-L never runs a probe that crashes the user's simulator (D50), and this is a refusal
with a measured price.** The `unset` / `define` / `load` aborts are cleanly probeable — a marker
file written after the aborting statement is a file-existence verdict, `absent` on apt 45.2 and
stock 47 (rc **134**, `it's a US_SIMVAR!` / `free(): invalid pointer`) and present on the fork. It
is refused because a deliberate SIGABRT of a dpkg-owned `/usr/bin/ngspice` is apport's reportable
case, and apport is **installed and enabled on this very release** (`dpkg -l apport` → `ii
2.34.1-0ubuntu0.1`; `/etc/default/apport` → `enabled=1`; `systemctl is-enabled apport.service` →
`enabled`; the `apport-coredump-hook@.service` unit present). It is silent here only because WSL
leaves `core_pattern` at `core`. On a stock Ubuntu desktop, the first thing a user would see after
registering their binary is *"ngspice closed unexpectedly."* — for a crash ASE-L caused. **What the
key would buy is upgrading a warning to a refusal on two of three binaries, and a warning is free.**

**0.13.7 — Two hazards this pass measured that no stage had written down.** Both are universal —
all three binaries — so both are unconditional mitigations with no key:

* **A narrowed `save` starves `noise`, `tf` and dc `sens`, not only `disto`.** MEASURED on all
  three: `save v(mid)` + `noise …` → `Error: no data saved for Noise analysis; analysis not run`,
  `$sim_status` **1**, a rawfile holding only `Plotname: constants`. Same for `tf` and for dc
  `sens`. `pz` survives. The general rule, of which `disto`'s segfault (**X1**) is the violent
  instance: **an analysis whose result vectors are not netlist names cannot run under a `save` list
  derived from netlist names**, and a *stale* Outputs entry — the normal case after a net rename —
  is enough to produce one. `APPENDIX` §7.5.2.
* **A bare `write` after `noise` keeps ONE of its two plots.** MEASURED on all three: `$plots` is
  `const noise1 noise2` and a bare `write` produces only `Integrated Noise` — the spectral-density
  curves are gone, at rc 0 and `$sim_status` 0, so nothing fires. Stage 6a's `setplot previous`
  walk is the fix and already owns this; `APPENDIX` §7.5.3 records the measured named-plot
  alternative **and why it was not taken** (the plot ids are session counters).

**0.13.8 — What was corrected inside the variant work itself, so nobody re-proposes it.** Three
ideas were measured and refused in the form proposed, and each is written down because the next
reader will have it too. (a) **Reading `$curcasemode` in the variant deck to publish
`casemode_detected`** — measured `none` / `none` / `fold`, i.e. the *current* mode and never the
supported *set*; publishing it would narrow the fork's real `{fold preserve distinguish}` to
`{fold}` and switch off the one feature the fork has (**D52**). (b) **Probing keyword case with a
capitalised COMMAND NAME** — measured: `Echo "…" >> f` works on all three, because command dispatch
inside `.control` is folded. The unfolded path is the **argument**: `write f ALL` leaves **no file**
on apt 45.2 and stock 47 and a file on the fork (`APPENDIX` §7.5.1). (c) **Filtering a raw column
named `all` inside `ase::raw_content_verdict`** — that proc is a read-only diagnosis over a 64 KB
head/tail slice; it returns no variable list and never reads the `Values:` block, so it cannot drop
anything. The real seams are `ase::cap_raw_plots` and the `xschem raw list` consumers; and ASE-L is
**already immune at the op-parameter seam**, because `ase::op_param_split` demands an `@dev[param]`
shape and discards `v(all)` for free (§6g).

**0.14 — `build-ver_50` gained PSS and CIDER on 2026-09-10, so every transcript in this batch that
shows it without them is historical.** At the user's request the tree was reconfigured with its
original arguments plus `--enable-pss --enable-cider` (same source commit, `ccebdf2a2`) and
reinstalled into `stage/`. Verified: `WITH_PSS` and `CIDER` defined in `config.h`; `help pss`
answers; `devhelp` lists `NUMD NUMD2 NBJT NBJT2 NUMOS`; both shipped PSS oscillators reach
`Convergence reached`; the binary went from 8 206 760 to 8 848 296 bytes; and the **version string is
still `ngspice-46+`**. Three consequences. **(a)** Every measurement in `evidence/` was taken against
the earlier binary (md5 `eaa99c22…`, `LEDGER.md` baseline); the `help pss` and CIDER-absent
transcripts are left exactly as they were measured. **(b)** The `absent` fixture for Stage 2's grid
and Stage 15's probe check moves to the bare-configure upstream build (`workpad/builds/upstream47`,
re-measured `Sorry, no help for pss.`). **(c)** `--enable-cider` changes what `rusage task` prints —
without CIDER `printres()` prints only the first simulator statistic, with CIDER a blank line and all
of them, and upstream has the same two arms — which broke one ngspice regression test that assumed
the two-line shape. What was done about it is in `receipts/04-dev-build-rebuilt.md`.

---

**Carried from `evidence/design-of-record.md` §12, because an implementer would otherwise re-make
them.** Full reasoning is there; this table exists so nobody has to find out the hard way.

| # | the claim that was wrong | what is true |
|---|---|---|
| C1 | capture the plots with `foreach p $plots / setplot $p / write raw all` | it writes `constants` **first**, and `ase::raw_content_verdict` then answers `ok 0` — **the rawfile ASE-L itself rejects.** The `setplot previous` walk is the only shape left |
| C2 | `ase::netlist_map_resolve` is "built and unused" | `ase::preflight_scan` calls it per output identifier and `ase::preflight_gate` **already refuses** a run whose saved names do not resolve |
| C4 | `-b` is progress-blind | it prints ` Reference value : <scale>\r` at ~4 Hz on stdout for tran, dc, ac, noise, disto and sp — **wider coverage than libngspice's `SendStat`**, which emits nothing for op, noise, disto, pz, tf or sens |
| C5 | chain `.spiceinit` with `source <user file>` | ngspice parses the target as a **netlist** and the user's variables are lost. **Copy the lines in** |
| C7 | one `class opt` emitter arm for every `.options` row | `OPTtbl` mixes `IF_FLAG` with `IF_INTEGER` and `IF_REAL`; a single arm emits a bare `.options gminsteps` for a user who typed 0 |
| C8 | refuse `disto` + zero saved outputs | that refuses a deck that works (0.9 above). The trigger is a save list that **resolves to nothing** |
| C10 | match results on the `Plotname:` literal | two SENS analyses share one literal (0.7). The join must be **positional on creation order** |
| C11 | `sp` is unsatisfiable without a schematic edit | `alter v1 portnum = 1` / `alter v1 z0 = 50` on **ordinary** V sources makes it run and return a correct `s_1_1` |
| C12 | `.meas` needs a results row and nothing else | `grep -c '\bmeas\b' src/ase.tcl` = **0**. There is no measurement surface at all |
| C16 | PSS has never been run, so do not offer it | it was built and run: 0.91 s and 0.41 s on the two shipped oscillators, both `Convergence reached`, both within ~1 % of documented f0 |
| C26 | TF's vectors are `Input_impedance` / `output_impedance_at_<node>` | measured they are **`Transfer_function` (capital T)**, `v1#Input_impedance` and `output_impedance_at_V(b)` (capital `V`). All three spellings; the first was never stated and is the one a Value-column probe most needs |
| C27 | `fft`/`spec` write `spectrum`; `linearize` writes `transient` | they write `Spectrum` (typename `spN`, because `ft_plotabbrev()` returns the first substring match and `sp` shadows `spect`), `PSD`, and `<old> (linearized)` |
| **C30** | *(this plan's own)* `gminsteps` defaults to 10 | it defaults to **1**. `cktntask.c:120-122` is `TSKnumSrcSteps = 1; TSKnumGminSteps = 1; TSKgminFactor = 10;` — the `10` in that block is **`gminfactor`** |
| **C31** | *(this plan's own)* TF's transfer vector is `transfer_function` | measured `Transfer_function`, **capital T**, beside `v1#Input_impedance` and `output_impedance_at_V(b)` |
| **C32** | *(this plan's own, caught in verification)* row D4 of `test_ase_simreg_0931` asserts nothing about argv | it pins the **full command line** through `$D4SAID`'s first element, and B12 pins it too. Six rows, not four (§0.1). `DECISIONS.md` and `LEDGER.md` were right and this plan was wrong |
| **C33** | *(this plan's own)* the committed `.state` count is 105 and the tree's comments are stale | **104 are committed**, 105 are on disk, and all fourteen comments in the suites are right (§0.5) |
| **C34** | *(this plan's own)* a `-b` run cannot keep a partial result, so *"stop and keep what you have"* is `-p`'s to give | `stop after` checkpointing keeps it **in `-b`**, in ASE-L's own deck shape: 60 % of an 80 ms transient survived a SIGTERM, in a file that loads (§0.12, `evidence/salvage.md` §3). What `-p` buys is a **non-destructive** abort, not a faster one — batch already dies in a few milliseconds at worst (**C35**) |
| **C36** | *(this plan's own, caught by Stage 0 the moment it was measured)* Stage 0 said that today, an analysis type ASE-L cannot render leaves a deck of *".control / set appendwrite / remzerovec / write / .endc"* — i.e. that a rawfile is written and is merely empty | **There is no `remzerovec` and no `write` at all.** MEASURED 2026-09-10 on a noise-only state: the deck is `.control` / `set appendwrite` / `print -i(v1)` / `.endc` / `.end`, rc 0. Issue **0929** moved the write inside the per-analysis loop, so a type the loop never visits produces **no raw file whatsoever** — which is worse, not milder: `ase::attach_dbs` then reports `NOT ATTACHED … the analysis did not run` about a run that never contained the analysis, and a user reads that as the simulator having failed. ⚠ **The general lesson, for every stage after this one: this plan's prose about today's behaviour is a CLAIM, not a measurement, even where it is specific enough to look like one.** Render the deck and look. Issue **1401** carries the measured deck |
| **C35** | *(this plan's own, caught in the amendment's verification)* three numbers the salvage block published as measurements | **(a)** the printed recipe put `let ckdone = 0` **after** the `tran`, so the counter landed in `tran1` and was written into every checkpoint *and* into the results file — `No. Variables: 5`, a `ckdone notype dims=1` column beside the circuit quantities. The block's own byte count, 192,000,311 for 4,800,000 points, is 40 bytes a row and was the arithmetic proof. Counter moved up beside the others: `No. Variables: 4`, final body sha256 `b9836c494d9d52ad` = the unchecked run's, and the quoted checkpoint size is **153,600,270**. **(b)** abort latency is not a constant 4.5–5.6 ms: it tracks the run's resident memory (0.78–0.85 ms at 24 MB, 1.83–2.14 ms at 62 MB, 3.84–5.15 ms at 177 MB) and a `date`-in-bash harness adds ~2 ms of its own. **(c)** the cost table's constants moved ±30 % across three sittings and `shell mv` measured ≈ 4 ms, not ≈ 12 ms. None of the three changes a conclusion; (a) is the one that would have shipped. ⚠ **A proposed replacement for (b) — *"under 1 ms, measured 0.40–0.58 ms"* — was REJECTED**, because it does not reproduce either: three sittings on this machine gave 0.4–0.6, 1.6–2.2 and 4.5–5.6 ms, and swapping one unreproducible constant for another is the defect, not the fix. What is written instead is the mechanism, which reconciles all three and which any reader can re-time |
| **C37** | *(this plan's own, caught by Stage 1's Xyce paper-validation — §1e)* §1a's rule *"nothing in the schema half may spell an ngspice word"*, and **D36**'s prediction that reaching for a simulator fact would surface as a finding | **The rule is LEXICAL, so it caught every ngspice NOUN and missed every ngspice SEMANTIC — and D36 is false exactly where it cost most.** `emit`'s `@name!` dependency is justified in the schema half by *"because ngspice's argument lists are POSITIONAL"*; §1b's `bool` row promotes a MEASURED NGSPICE DEFECT (trap T4, a `CP_BOOL` written `=1` is silently turned off) into the type system; `plots.match` is *"a glob on the Plotname literal"*, a record type only an ngspice rawfile has. All three pass a grep for simulator words. ⚠ **The tree proves the sharpest case**: §1b's number lexicon `f p n u m k meg g t` is **narrower than xschem's own C parser**, which carries `x` = 1e6 at `src/editprop.c:101` under the comment `/* Xyce extension */`, plus `mil`. Restated as a SEMANTIC rule: each key's contract line records *"what would a simulator unlike ngspice answer here?"* |
| **C38** | *(this plan's own)* **D30**: *"every destination in APPENDIX §6.2 must appear in some registry row's `results`, and a row without one is a LOAD-TIME error"* | **D30 as written would reject THIS PLAN'S OWN ENTRIES.** §1a's `tran` example carries `plots {{match {Transient Analysis} role sweep results viewer label {Transient}}}` and **no entry-level `results` key at all**; `tf`, `pz` and `sens` are the same shape. Either the check reads the plot-level token or `results` moves up to the entry — Stage 1 does the latter for its four types and the general fix is recorded against ⚖ R10 |
| **C39** | *(this plan's own)* `requires` is a **three-valued** predicate (`present`/`absent`/`unknown`) whose four-state grid includes a `raised` arm | **The `raised` arm is UNREACHABLE by a conforming adapter.** It appears at `PLAN.md:1206` inside the grid and at `:1047` in a planned test row, and **zero** times in **D42–D52**, the decisions that created the key. An adapter told it owns three values can never produce the fourth, so `{state caution reason requires_raised}` can only ever come from ASE-L itself — which is not what the contract says |
| **C40** | *(this plan's own)* `emit` is *"a TOKEN TEMPLATE"* — one line per analysis | **One line cannot express a runnable deck for a simulator without a control language, and this repository already ships the counter-example.** `xschem_library/ngspice/solar_panel_xyce.sch:155-156` carries `.tran 5n 1000u uic` **plus** `.print tran format=raw file=…`, and `sky130A/xschem_libs/sky130_tests/test_ac/schematic/test_ac.sch:285` carries `.print ac format=raw`; without the second card a Xyce run produces no data at all. `emit` is now an ORDERED LIST of role-tagged cards with exactly one `analysis` role. ⚠ **It moves no byte**: ngspice declares a one-element list whose `analysis` template is today's text. It landed in Stage 1 rather than later because it changes the ONE SPELLER'S RETURN TYPE, which is free with one implementation and costs every reader afterwards |
| **C41** | *(this plan's own)* `verb` — *"the `.control` command word AND what `help <verb>` is probed with"* | **DELETED in Stage 1.** It is two ngspice words in the half §1a says may contain none, and it names a construct a batch-only simulator does not have. It was never the source of the emitted token — `emit {tran @step @stop}` carries the literal — so deleting it moves no byte. Stage 2's probe token becomes adapter-private |
| **C42** | *(this plan's own)* `gated` — *"1 when an `#ifdef` in `commands.c` can remove it"* | **Renamed `baseline` and re-specified, because it was load-bearing IN THE WRONG DIRECTION.** Besides naming an ngspice SOURCE FILE inside the schema, it is the only steer on `ase::requires_state`'s `unknown` arm: an adapter that cannot assert an ngspice-style source-verified invariant writes `0`, every unmeasured capability resolves `{ok baseline}`, and analyses nobody verified are offered — **the inverse of Stage 2's stated worst outcome** |
| **C43** | *(this plan's own, caught by Stage 1 by measurement)* Stage 1's acceptance is deck golden **D1** compared under `string equal` | **D1 IS NOT SUFFICIENT AND THAT WAS MEASURED, NOT SUSPECTED.** D1's fixture is **OP-ONLY**, so its golden deck carries the single line `op` and the `dc`/`ac`/`tran` emit arms are never exercised by it. MEASURED 2026-09-11: sabotaging `dc`'s emit template to swap start and stop, and `ac`'s hardwired `dec` to `oct`, each left `test_ase_core` at **ALL PASS (248)** — i.e. nothing committed in this tree would have noticed a refactor that reversed every DC sweep in the product. Stage 1 commits section **D8** (ten rows, floor 248 → 258) so that every later stage inherits an acceptance that discriminates |

⚠ **C32 and C33 were briefly numbered C28 and C29, and those two ids are already taken.**
`evidence/design-of-record.md` §12 defines **C1–C29**; its C28 is Design B's *"41 points"* mock and
its C29 the `.meas` card-vs-command wording — different corrections entirely. **The C-space is one
space across the batch** — `CREW_BRIEF.md` cites C21 and `LEDGER.md` cites C18, both design-of-record
ids — so this plan's own additions begin at **C30**. Nothing else in the batch cited the old numbers,
so the renumber costs nothing; do not re-mint C28 or C29.

---

## 0.1 Measured facts — so nobody re-derives them

The numbers the whole plan rests on, each with the probe that produced it. Everything else is in
`evidence/`; cite it, do not restate it.

### The three binaries — which ngspice the user actually has

**Added 2026-09-10. Read this before anything below, because every other number in §0.1 was taken
against the third column and most users will be on the first.** The reference table is
`APPENDIX` §1.8; this is the operating summary.

| | **apt 45.2** — what a new user has | **stock upstream 47** — what a from-source user has | **the fork** — the development reference |
|---|---|---|---|
| path | `/usr/bin/ngspice` | `…/workpad/builds/upstream47/src/ngspice` | `/home/analog/dev/ngspice/build-ver_50/src/ngspice` |
| provenance | Ubuntu 26.04.1 LTS, `45.2+ds-1` | `origin/pre-master-47` @ `c5cd68015` | `ver_50` @ `ccebdf2a2` |
| `-v` says | `ngspice-45.2` | **`ngspice-46+`** | **`ngspice-46+`** |
| has that the others do not | `pss`; CIDER's 5 families | — | casemode; ~35 bug fixes live upstream |
| lacks that the others have | `pyplot`, `astate`, `ota` | `pss`, CIDER | `pss`, CIDER |
| `ase::op_save_tier` picks | **`c`** (`unsafe`) | **`d`** (`dump`) | **`d`** (`dump`) |
| ASE-L's ordinary op+tran deck | **rc 0, identical results to the fork** | rc 0 | rc 0 |

**Four consequences, each of which a stage below depends on:**

1. **No version comparison, anywhere** (§0.13.3, **D44**). Columns 2 and 3 are the same string, the
   same 134 command names and the same 134 help strings.
2. **No "basic mode"** (§0.13.4, **D45**). The subsets overlap without nesting: the *oldest* binary
   has an analysis and five device families the *newest* two lack.
3. **A crew tests against column 1 as well as column 3.** `CREW_BRIEF.md`'s testing discipline
   carries the rule; the fork is where the work is developed, apt 45.2 is where it is run.
4. **Building column 2 takes 99 seconds**, not ten minutes — measured: autogen 26 s, configure
   14 s, `make -j8` 59 s on 20 cores. Rebuild it rather than reason about it.

### The trap set — what the GUI exists to prevent

The full register is **APPENDIX §7** — §7.1 crashes, hangs and aborts; §7.2 silent wrong answers;
§7.3 silent no-ops; §7.4 why `libngspice` is not the escape hatch; **§7.5 which binary has which of
them, with the three probes and the rule that a hazard is keyed on what the binary answered and
never on its version.** These **seventeen** are the ones a stage below refuses by name.

| # | fact | probe |
|---|---|---|
| **T1** | An analysis type ASE-L does not know is **silently dropped**. `render_deck`'s emit loop is `foreach type $anorder { foreach a [analyses] { if {[type] ne $type} continue … } }` — an unknown type is **never visited at all**, the `switch` has **no `default` arm**, `ase::n_enabled_analyses` still counts it, and the pane still shows it ticked | read in `ase::backend::ngspice::render_deck` |
| **T2** | `.disto` **SEGFAULTS (rc 139)** when its save list resolves to nothing — from ASE-L's exact `.control` shape, and from a dot-card deck | §0.9, two builds |
| **T3** | ngspice **silently accepts an unknown option name, on BOTH routes**. A deck with `.options bogusdot=1` + `option bogusopt=3` inside `.control` printed **no message at all** and the trailing bare `set` listed `+ bogusdot 1` and `bogusopt 3`; a dot-card deck with `.options frobnicate` + `.op` ran completely clean. The `Error: unknown option %s - ignored` branch exists (`inpdoopt.c:74-78`) and **neither route reaches it** | measured this session, both routes; APPENDIX §3.1. **This is why Stage 7f's requested-vs-effective read-back is mandatory, not a nicety** |
| **T4** | A `CP_BOOL` written `set x=1` is silently turned **OFF**. `set interp` → 21 uniform points; `set interp=1` → 109 raw ones | `evidence/hidden-vars.md` §0 |
| **T5** | A `CP_NUM`/`CP_REAL` is silently **inert** under a bare `set x`, and under `-D x=1`, because `-D` only ever makes strings and booleans | `evidence/hidden-vars.md` §0 |
| **T6** | `ac lin 2 <f1> <f2>` **and `sp lin 2 <f1> <f2>`** return **one point**, silently. `span.c:417-427` is character-for-character `acan.c:103-114`'s shape | §0.9; `sp lin 2 100meg 1g` → `No. of Data Rows : 1`, `lin 3` → 3 (APPENDIX §7.2 **S1**) |
| **T7** | `sens … ac` under `.options klu` → **rc 139**; `sens … dc` under klu → rc 0 | `evidence/00-critique.md` D3 |
| **T8** | 26 `cp_getvar` variables are read **before `.options` exists**, so `.options casemode=preserve` and `.options nosubckt` are silently ignored | `evidence/hidden-vars.md` §0 |
| **T9** | Under `-n` a `.spiceinit` beside the deck is silently dropped — 4700 becomes 1e-12, and the only message printed is about a *resistor* | `evidence/design-of-record.md` [R-M17] |
| **T10** | `.control`'s `if` on **strings** takes the **false** branch for both `eq` and `ne`. Only the numeric `$sim_status` guard survives | `evidence/design-of-record.md` [B-M5] |
| **T11** | `$` substitution swallows `.` in a generated variable name: `set wl = "$wl $p.all"` → `Error: p.all: no such variable` | `evidence/design-of-record.md` [R-M19] |
| **T12** | A bare `@dev` name on any write other than the `op` write gives dims=1, one non-zero sample at index 0, silently | decision F, [R-M4] |
| **T13** | **`sens … ac lin` sweeps GEOMETRICALLY.** `sens v(mid) r*:r ac lin 5 1k 5k` swept **1.000000e+03, 8.000000e+05, 6.400000e+08, 5.120000e+11, 4.096000e+14** — each × 800. `inc_freq()` (`cktsens.c:828-837`) is `if (type != LINEAR) freq *= step_size;` and its `LINEAR` is `noisedef.h:74`'s `#define LINEAR 3`, **not** `SENS_LINEAR` (`sensdefs.h:87`), so the test is always true. **Do not offer `lin` for SENS AC** | measured this session; APPENDIX §2.10, §7.2 **S2** |
| **T14** | **`.options defas=<v>` sets the DRAIN area, not the source area.** `cktsopt.c:111-113`'s `OPT_DEFAS` arm writes `TSKdefaultMosAD`, the same field the `OPT_DEFAD` arm three lines above writes. Silent wrong answer | read this session; APPENDIX §3.3, §7.2 **S3** |
| **T15** *(new 2026-09-10)* | **A narrowed `save` starves `noise`, `tf` and dc `sens`, not only `disto`.** `save v(mid)` + `noise …` → `Error: no data saved for Noise analysis; analysis not run`, `$sim_status` **1**, a rawfile holding only `Plotname: constants`. Identical for `tf` and dc `sens`; `pz` survives. T2's `disto` segfault is the violent instance of the same rule: **an analysis whose result vectors are not netlist names cannot run under a `save` list derived from netlist names** — and a *stale* Outputs entry is enough | measured on **all three binaries**; APPENDIX §7.5.2, §0.13.7 |
| **T16** *(new 2026-09-10)* | **A bare `write` after `noise` keeps ONE of its two plots.** `$plots` is `const noise1 noise2`; a bare `write z.raw` produces only `Integrated Noise`, at rc 0 and `$sim_status` 0, so no guard fires. Stage 6a's `setplot previous` walk is the fix and already owns it | measured on all three; APPENDIX §7.5.3 |
| **T17** *(new 2026-09-10)* | **An op plot holding exactly ONE saved vector is written with a phantom second column named `all`, carrying the same data.** `.save v(in)` + `op` + `write f` → `Variables:` = `v(in)` **and** `v(all)`. op/2 saves clean, op/3 saves clean, tran/1 save clean (the `time` scale is a second vector). This is the **one** fork fix that reaches ASE-L's own generated text | measured: **defect on apt 45.2 and stock 47, fixed on the fork**; probe key `one_vector_write`, APPENDIX §7.5.1; Stage 6g |

### The writer — how a multi-plot analysis is captured

`setplot previous` plus a per-write sidecar line, measured end to end:

```
noise v(mid) v1 dec 2 1k 10k
remzerovec / echo "PLOT noise n1 |$curplotname|" >> pm.map / write pm.raw
setplot previous
remzerovec / echo "PLOT noise n1 |$curplotname|" >> pm.map / write pm.raw
op
remzerovec / echo "PLOT op o1 |$curplotname|" >> pm.map / write pm.raw
```

gives a sidecar whose lines are **1:1 and in order** with the rawfile's `Plotname:` records:

```
PLOT noise n1 |Integrated Noise|
PLOT noise n1 |Noise Spectral Density Curves|
PLOT op o1 |Operating Point|
```

The first plot in the file is genuine data, so `ase::raw_content_verdict` answers `ok 1` and
`ase::attach_dbs` attaches. **Over-walking degrades and does not destroy:** one step too far
re-writes the previous analysis's plot, two steps writes `constants` — but plot 1 is still real, so
the file still attaches. `<cell>_ase.plotmap` is **deleted before every run**, because `>>` appends.

### The plot literals — the registry's `plots` column

`Plotname:` strings, measured (§0.7). The complete table, with the `destination` and `label shown`
columns the registry needs, is **APPENDIX §6.2**; the capture mechanism and the plot→analysis join
are **§6.3**. `evidence/an-*.md` is the second-level anchor. **The count is a predicate, not a
constant.**

| analysis | plots |
|---|---|
| `op` | `Operating Point` |
| `dc` | `DC transfer characteristic` |
| `ac` | `AC Analysis` (+ `AC Operating Point` under `keepopinfo`) |
| `tran` | `Transient Analysis` (+ `Transient Analysis (linearized)` after `linearize`) |
| `noise` | `Noise Spectral Density Curves`, `Integrated Noise` — the second **exists only when `start != stop`** (`noisean.c:511`); both renamed under `sqrnoise` |
| `tf` | `Transfer Function` |
| `pz` | `Pole-Zero Analysis` (+ an OP plot mislabelled **`Distortion Operating Point`**, upstream copy-paste at `pzan.c:58`) |
| `disto` | **2**: `DISTORTION - 2nd harmonic`, `DISTORTION - 3rd harmonic`; or **3** with `f2overf1`: `DISTORTION - IM: f1+f2`, `DISTORTION - IM: f1-f2`, `DISTORTION - IM: 2f1-f2` |
| `sens` | `Sensitivity Analysis` — **the same literal in both dc and ac modes** |
| `sp` | `SP Analysis` (+ `AC Operating Point`) |
| `pss` | `Time Domain Periodic Steady State Analysis`, `Frequency Domain Periodic Steady State Analysis` — **× (1 + relaunches)**, so take the *last* pair |
| `fft` / `spec` | `Spectrum` (typename `spN`) |
| `psd` | `PSD` |

### Transport — settled by the build probes

| | `-b` batch (today) | `-p` pipe | `libngspice` |
|---|---|---|---|
| abort | **every** signal is fatal at its default disposition — INT 130, TERM 143, HUP 129, QUIT 131, USR1 138, USR2 140, PIPE 141 — and whatever is in flight is lost. **Latency a few ms at worst** — sub-millisecond on a small run; it tracks the process's resident memory, not the signal (**C35**) — TERM and KILL alike. ⚠ *But a checkpointed deck keeps what it last wrote* — see the salvage block below | SIGINT pauses in **< 5 ms** — *the same order*. What differs is that the abort is **non-destructive**: partial results intact in the process (a valid 388 MB raw written after a stop), `resume` continues | `bg_halt` 10 ms — **but it wedges on `disto` and on `sens`** |
| progress | **yes** — ` Reference value :`, ~4 Hz, tran/dc/ac/noise/disto/sp | the same ticker | `SendStat` — **nothing at all** for op, noise, disto, pz, tf, sens |
| pre-deck options | `.spiceinit` + `-D`, two doors and four traps | **`set` before `source`** — one door | one door |
| crash blast radius | the child dies; xschem lives | the child dies; xschem lives | **xschem dies** — the `.disto` NULL-deref killed the host at rc 139 |
| deployment | any ngspice the user has | any ngspice the user has | ships and ABI-pins `libngspice.so.0`, sets `SPICE_LIB_DIR`, adds Tcl↔C FFI to a 19,880-line pure-Tcl codebase |

`--with-ngshared` builds **no `ngspice` binary**, and `ngSpice_Circ` after `ngSpice_Reset` SEGFAULTs
because `Reset` is a full teardown and `ngSpice_Circ` lacks the `is_initialized` guard
`ngSpice_Command` has. `evidence/builds.md` §3, §4.

### Salvaging a stopped run — what `-b` keeps, and what it costs

**The whole basis is `evidence/salvage.md`; cite it, do not restate it.** It supersedes the quick
pass that preceded it, and §0.12 records what that quick pass got wrong. These are the numbers
Stage 2e and Stage 6f are written from. Every row was measured 2026-09-10 against
`build-ver_50/src/ngspice` on an RC driven by a 1 kHz sine — four vectors, so a transient row is 32
bytes; `tran 10n 80m` → 8,000,008 points, 256 MB, 7.84 s; `tran 10n 8m` → 800,008 points, 25.6 MB,
0.82 s.

**The shape, in ASE-L's own deck.** The counters are created **before the first analysis** and the
threshold reaches `stop after` through a `set` variable; both are traps, not taste (below).

```
.control
set appendwrite
let ckstep = <points>        <- ALL THREE before any analysis. A `let` made while
let cknext = ckstep             op1 is current lands in op1 and is invisible from
let ckdone = 0                  tran1; one made after `tran` lands in tran1 and is
                                WRITTEN INTO every file the loop writes
set cktgt  = $&cknext        <- `stop after $&vec` is a SYNTAX ERROR above 1e6

op   / <guard> / remzerovec / write <raw>
ac … / <guard> / remzerovec / write <raw>

stop after $cktgt
tran 10n 80m
while ckdone = 0
  unset appendwrite          <- or the checkpoint STACKS a plot instead of
  remzerovec                    replacing the file
  write <raw>.ckpt.tmp       <- its OWN path, never the results file
  shell mv -f <raw>.ckpt.tmp <raw>.ckpt      <- ngspice has no rename primitive
  set appendwrite
  echo CKPT-DONE $cktgt      <- progress; NOT reliable under a kill, stdout is
                                block-buffered when redirected
  let cknext = cknext + ckstep
  set cktgt = $&cknext
  if cknext < <total>
    stop after $cktgt
    resume
  else
    let ckdone = 1
    delete all               <- or the stop re-fires, or leaks into the next analysis
    resume
  end
end
<guard> / remzerovec / write <raw>
echo ASE-RUN-COMPLETE        <- the ONLY completeness marker; rc and $sim_status are 0
.endc
```

| # | fact | probe |
|---|---|---|
| **SV1** | **`stop after N` does not perturb the run.** At 3 checkpoints and at 100, the final rawfile body's **sha256 is identical** to the unchecked run's — `b9836c494d9d52ad`, 25,600,256 bytes of body at 800,008 points. ⚠ **It holds only with the counters where SV11 puts them**; one created after the analysis adds a fifth column and there is nothing left to be identical to | `evidence/salvage.md` §3.2; **C35** |
| **SV2** | **`stop when time > X` does.** `com_stop()` calls `CKTsetBreak()` for a time condition, forcing a timepoint: **+3 rows per checkpoint** and a different timestep grid (800,011 / 800,017 against 800,008). The physics is unharmed — `max │Δv(out)│ = 4.7e-13` at shared timepoints — the bytes are not. **The interval is therefore in POINTS, not simulated time** | §3.2 |
| **SV3** | **`stop when` is not disarmed when it fires**, so it re-fires on the next point and `resume` advances **one point**. `status` still lists it. A deck written that way covers **12.5 %** of its run and exits **rc 0** | §3.1 |
| **SV4** | **Every checkpoint is an exact byte prefix of the final file** (200,000 / 400,000 / 600,000 rows, then 800,008), so overwriting one path loses nothing | §3.3 |
| **SV5** | ⚠ **`set appendwrite` — which `render_deck` emits — turns overwrite into STACK.** 3 checkpoints + the final write to one path gave **four plots, 64,001,536 bytes** where one plot is 25,600,541: quadratic in the checkpoint count, and readback-by-plot-name broken. Fix, measured: `unset appendwrite` around the checkpoint write, and **its own path** | §3.3 |
| **SV6** | **A stop armed once leaks into the next analysis in the same block** — and ASE-L renders op/dc/ac/tran in **one** block. `stop after 200000` truncated the `tran` **and** the following `ac`, rc 0; a `stop when time` left armed during an `ac` wrote **600,045** `Error: time: no such node` lines and a **15.6 MB** log. `delete all` between analyses is mandatory | §3.5 |
| **SV7** | **`$sim_status` is 0 after a stop**, `dosim()` (which `ft_dorun()` calls) maps *"simulation interrupted"* to `err = 0` deliberately, the existing guard prints nothing, the `write` runs and **rc is 0**. Completeness needs a **deck-emitted echo**; it cannot be inferred from the exit status | §3.6 |
| **SV8** | **`remzerovec` and `.options savecurrents` are undisturbed** by a stop: all vectors 200,000 long, nothing removed, the write succeeds | §3.6 |
| **SV9** | **A kill during a checkpoint write tears the file and the loader recovers NOTHING** — `raw_write()` writes the true count up front and then streams, so the header over-claims: `Error: bad rawfile / load aborted / no data read` over 1.7 M good points. Five kills gave a 27 MB and a 14 MB torn file, and **one landed in the `fopen(…, "wb")` window and left 0 bytes** where the previous good checkpoint had been. ⚠ One hit in five is **not a rate** — a later sitting got 0 in 5 — but it is what makes tmp+rename mandatory rather than tidy, because that failure destroys the **fallback**, not the new file | §4.3 |
| **SV10** | **`write <path>.tmp` + `shell mv` is kill-safe 6/6**; the damage is confined to the `.tmp`. **ngspice has no rename, move or copy primitive** — `spcp_coms[]` offers `write`, `fopen`/`fread`/`fclose`, `cd`, `getcwd` and `shell`, and nothing else — so the atomicity comes from `shell mv` in the deck or from the GUI. **≈ 4 ms per checkpoint** — two A/B sittings of twenty checkpoints measured 3.7 and 3.9 ms; an earlier pass recorded ≈ 12 ms and was three times too large | §4.4 |
| **SV11** | **The counters must live in the `const` plot** — for the *output*, not only for the loop. A `let` created while `op1` is current lands there and is **invisible** from `tran1`: `Error: &cknext: no such variable`, the counter never advances, no further checkpoint is armed, **rc 0**. And one created *after* the `tran` is a vector **of `tran1`**, so every `write` from then on emits it: measured `No. Variables: 5` and a `ckdone notype dims=1` column beside time and the circuit quantities, in the checkpoint **and** in `<cell>_ase.raw`, which ASE-L reads by enumerating a plot's vectors (**C35**) | §3.9a |
| **SV12** | **`stop after $&vec` breaks above 1,000,000** — `$&` formats as `1.2E+06` and `com_stop()` parses digits only: *"Syntax error parsing breakpoint specification"*, nothing armed, the run finishes unchecked at **rc 0**. Through a `set` variable it arms correctly, **rounded to 6 significant figures** | §3.9b |
| **SV13** | **Cost.** Extra bytes = **N/2 × final size**, linear in bytes. On the 25.6 MB / 0.82 s reference, three sittings on one machine: N=4 **+8 to +21 %**, N=20 **+60 to +75 %**, N=100 **+288 to +380 %**, implying B = 410–540 MB/s. **B is page-cache throughput that moved ±30 % between sittings — a planning constant, not a bound** (there is **no `fsync` anywhere** in `rawfile.c` or `outitf.c`). The model reproduces; the constants do not, so compute from `N/2 × S / B` and measure B here. A *machine* crash can still lose a checkpoint `write` reported as finished | §3.7 |
| **SV14** | **Choosing N.** Loss is `T/(2(N+1))`, cost is `N × S / (2B)`; minimising the sum gives **N + 1 = sqrt(T × B / S)** with B ≈ 400–500 MB/s. Reference deck → N = 3; a ten-minute, 200 MB job → **N ≈ 34, a checkpoint every ~17 s, costing 1.4 %**. Default where T and S are unknown: **N = 4**, clamped `[2, 50]`, worst-case loss **20 %** | §3.7 |
| **SV15** | **Point-count estimate.** `tstop/tstep + 8`, measured exactly on this deck. ⚠ It will not hold with `pulse`/`pwl` breakpoints, `.options interp` or a max-step setting — then the loop must read `length(time)` at the first checkpoint and re-arm from the measured value | §3.7, §7.2 |

**What cannot be salvaged, and it is a short list worth reading before designing around it.**

* **`op`** — one point; there is nothing to keep.
* **`noise` and `disto`** — a stop mid-run leaves an **incomplete plot SET**, not a short plot:
  an unchecked `noise` leaves `noise1 noise2`, stopped it leaves `noise1` only and `resume` then
  produces `noise2`. `disto` has the same two-plot shape. A salvaged one of these must **never** be
  presented as merely truncated (§3.4, and `evidence/ase-deck.md` §7.4's invariant).
* **`pss`, `sp`, `pz`, `sens`, `tf`** — unmeasured. `evidence/builds.md` already records that `sens`
  does not honour `bg_halt` and that `pz` likely cannot be interrupted at all. Not offered until
  measured (§7.3).
* **Windows** — the rename goes through `com_shell`, which runs `cmd` there, and `mv -f` is not a
  `cmd` builtin (§7.4). ASE-L's `ase::ui::do_stop` already refuses on Windows for its own reason.
* **A nonlinear circuit** — everything above is an RC. SV1's byte-identity is the one result to
  re-confirm on a transistor-level deck before it is quoted as a general fact (§7.1).

⚠ **`-r` is not the route, and it is not inert.** `ngspice -b -r <path>` *is* written incrementally
and a truncated one can be repaired — but on a deck whose `.control` block runs the analysis,
`main.c`'s batch arm calls `ft_dorun(ft_rawfile)` unconditionally, and **`dosim()`** beneath that
four-line wrapper opens the path `"wb"` and, in its close arm, **`unlink()`s it** when nothing was
written. (Grep `ft_dorun` and you find a wrapper with no `fopen`, no `unlink` and no `err` mapping —
the behaviour is one call down.) MEASURED: a good rawfile written by the
block's own `write` to that path was **gone at exit, rc 0**. `-r` against an ASE-L-shaped deck is a
destructor pointed at whatever path you name. Two further boundaries: the loader aborts the *whole*
file over a single leftover byte of a partial row, so the repair is two steps not one; and `-b -r`
**corrupts its own output above 99,999,999 points** — `fileInit()` reserves 8 characters, `fileEnd()`
writes `%d`, and a 101-second, 3.2 GB run produced `No. Points: 100000008Variables:`, which ngspice
refuses to load, at rc 0. That last one is an upstream defect and belongs in `doc/codex/issues/` in
the ngspice tree (`evidence/salvage.md` §2.3–§2.6, §7.7).

### The ASE-L side — what already exists, and what does not

| fact | anchor |
|---|---|
| `ase.tcl` is **Tk-free** by its own header, with one guarded carve-out (`ase::open_state`), and `test_ase_core.tcl` runs its procs true-headless | `src/ase.tcl` header |
| `ase::register_backend` requires exactly five hooks — `render_deck run_cmd log_file result_probe raw_file` — and **tolerates extras**; `capabilities`, `op_param_set` and `op_param_enumerable` already ride that way | `ase::register_backend`; `test_ase_simcaps_0948` **A3** |
| `ase::sim_caps_have_path {backend path {eargs {}}}` returns **0/1** — it is the free peek, not a dict | `ase::sim_caps_have_path` |
| the dialog must never start a probe: measured worst case for a program that exists, is executable and never answers is **31.2 s** | issues 0953/0958/0959 |
| `ase::preflight_gate` **already refuses** a run whose saved output names do not resolve, case-mode aware, with repair suggestions, ahead of any deck write — and `set ase_preflight 0` **defeats it** | `ase::preflight_gate` (hint `:4742`) |
| `ase::rundir` falls back to `set_netlist_dir 0` when the state carries no rundir — a directory shared by every cell **and by xschem's own netlister** | `ase::rundir` |
| **Stop already exists, it is a `kill -9`, and on the path that kills something it says NOTHING.** Two doors — *Simulation > Stop* and the `!` strip button — both call `ase::ui::do_stop`, which resolves the run (the session's `run_id` attr first, then `ase::run_in_flight`'s results-file lock), refuses on Windows, and calls `kill_running_cmds $id -9`. That helper is `exec kill $sig [pid $execute(pipe,$id)]`, so it signals the pipeline's own processes and **not** a process group | `ase::ui::do_stop`, `ase::ui::menu_path_stop`, `kill_running_cmds` (`src/xschem.tcl`) |
| **A successful Stop echoing nothing is PINNED.** `test_ase_core.tcl` **RG13** drives `ase::ui::do_stop` headless through `rg_ciw` and asserts the kill path's CIW output is `{}`; its sibling row asserts the nothing-to-stop path says *"ase: no simulation running for this session"*. So a Stop that speaks is a **changed row**, and a Stop that opens a **modal** hangs that suite | `test_ase_core.tcl` RG13 |
| ASE-L has a complete **VCD pipeline** already: `ase::cosim_map`, `ase::last_vcdfiles`, `ase::attach_dbs {rawfile sim_type {vcdfiles {}}}` | those three procs |
| `ase::ui::listdlg_open` / `listdlg_editor` are a config-driven `ttk::treeview` **editor** whose rows come from session state, with **no sorting** — not a result table | `ase::ui::listdlg_open` |
| `ase::plot_sim_type` is a **preference ranking**, deliberately decoupled from emit order (issue 0964); its own comment says the coupling must not be re-established. Row **R6** of `test_ase_optier_0963.tcl` pins it | `ase::plot_sim_type` |
| `ase::ui::chana_options` collects name/value pairs, round-trips them, renders them in the Arguments column and **never emits them**. Its own comment says so: *"DECK emission of extra keys stays deferred (v1 limit, documented here)"* | `ase::ui::chana_options` |
| `grep -c '\bmeas\b' src/ase.tcl` → **0** | — |
| today's golden deck's **`.control` block** — `test_ase_core.tcl` **D1** (`:375-404`), whose full `expected_deck` also carries the netlist lines, `.GLOBAL GND`, `.lib /models/sky130.lib.spice tt`, two `.param`s, `.options savecurrents`, `.temp 27` and `.save -i(v1)` **above** it — is the byte-identity target for Stage 1. Stage 1's acceptance is `string equal` against the **whole** string, not against the block below | see below |

```
.control
set appendwrite
op
if $?sim_status = 0
  echo NO-SIM-STATUS
end
if $sim_status ne 0
  echo RUN-FAILED
  quit 1
end
remzerovec
write @RAWFILE@
print -i(v1)
.endc
.end
```

### The invariants that must survive every stage

Each was measured, each has a suite row, and each is the kind of rule that gets refactored away by
someone who does not know why it is there.

1. **`op` is emitted LAST.** ngspice's save list is sticky *forward only* — `unsave` does not exist
   and a later `save all` does not reset it — so the device-parameter requests that sit immediately
   before `op` would be recorded again by every analysis after it. That is the 74.9 MB issue 0964
   deleted.
2. **A `$sim_status` guard follows EVERY analysis, above any write.** One guard at the end → rc 0 and
   a 2198-byte raw with the failure completely masked.
3. **`remzerovec` precedes EVERY write, including every write after a `setplot previous`.** It is
   per-plot, and it is the structural cure for the measured hazard where one zero-length vector makes
   `checkvalid` abort the *entire* `write` silently.
4. **Device `@dev` names ride the `op` write and no other.** `write raw all @m1[gm] …` *generates*
   those vectors; `setplot op1` + `write raw all` produces zero. Rows **E5** and **M1** of
   `test_ase_optier_0963.tcl` fail if this is loosened.
5. **The Outputs Value column holds a scalar and nothing else.** Issue 1243, the user's own ruling: a
   multi-point `print` emits a 20,514-row table from which `result_probe` extracts exactly nothing.
6. **Nothing goes on the schematic.** Transient noise uses `alter` or a generated parallel source; SP
   ports use `alter portnum`; design variables use `.param x='var(…)'`.

---

## 1. The axis split and how to read this plan

Fifteen stages on three axes, plus **two** terminal stages that belong to none of them: **Stage 15**
(the adapter conformance harness — not part of this pass) and **Stage 16** (*"the ngspice you
actually have"* — added 2026-09-10 by the variant amendment, and **terminal in numbering, not in
priority**: Stage 15 is terminal *and optional*, Stage 16 is terminal *and the adoption gate*). The
axes are not a taste split — they are three different answers to *"what happens if this stage never
ships"*.

**CORRECTNESS — Stages 0–4.** Five stages where the window today reports something that is not true,
or drops something without saying so. If none of the rest ships, these still must. They carry two
rulings between them, and Stages 0 and 1 carry **none**.

**CAPABILITY — Stages 5–9.** Eight of the twelve analysis types, the writer that can capture them,
both option catalogues, and the measurement surface that turns a run into a number. This is the half
the user asked for in the words *"any supported analysis and set options easily"*.

**REACH — Stages 10–14.** The five places ASE-L can be plainly ahead of ADE-L rather than level with
it: the convergence story, campaigns with a number at the end, the digital half of a mixed-signal
run, transient noise, and ngspice's only large-signal periodic analysis.

**Who owns what, across all fifteen.** **ASE-L owns the SCHEMA; a per-simulator ADAPTER owns the
CONTENT.** The analysis list, each analysis's fields with their units and defaults, its emit syntax,
its option catalogue and its result naming are **data the adapter supplies** — they do not
accumulate in ASE-L's own source. That is what `ase::analysis_types` resolving an optional
`analysis_types` hook and falling back to `{}` already is (Stage 1a); the pivot recorded in §0.10 is
that the hook is the contract rather than an override point. The reason is measured, and it is on
this machine: `/usr/bin/ngspice` (45.2) answers `help pss` with *"Do a periodic state analysis"* and
runs it, while a bare-configure build of the same simulator answers `Sorry, no help for pss.` and
returns `pss: no such command available in ngspice` — `--enable-pss` was given to one build and not
the other (APPENDIX §1.7 `[A-M7]`; measured on `build-ver_50` on 2026-09-09 and on
`workpad/builds/upstream47` on 2026-09-10). And `build-ver_50` itself moved from the second answer to
the first when it was reconfigured on 2026-09-10 (§0.14), still reporting `ngspice-46+`. **One simulator, one machine, two analysis sets.** A literal list in
`ase.tcl` is therefore already wrong for ngspice against *itself*, before a second simulator is
imagined, and that is the strongest argument in this batch for the adapter/probe split: the adapter
says which rows could exist, Stage 2's probe says which of them this binary has, and Stage 2's grid
is the join. Adapters are **first-party for now** — Xschem's own agent writes them, they live in
this tree, they version with Xschem — so an adapter is ordinary Tcl on the existing
`ase::register_backend` hooks and no manifest format or sandbox is designed for it (see *What this
plan refuses*). And the contract is built by being **its own first customer**: the ngspice adapter
of Stages 1–14 is written *through* it, never around it, because a contract with no implementation
pulling on it fits nothing.

**The honest sequencing claim.** Stage 0 is the only one that is urgent. Everything after it is a
capability the user does not have today and has lived without; Stage 0 is a run that *completes,
writes a rawfile, produces nothing, and leaves the box ticked*. A user cannot tell that from a run
that worked. Ship Stage 0 first, alone; it costs no ruling and moves no existing row.

**Reading rules.** A `⚖` marks a decision that is the user's; they are batched in the ruling ledger
and asked one at a time. An **answered** one keeps its row and carries the answer — ⚖ R1 is the first
of those. Every proc named exists unless the text says **new**. Every suite row named
was read this session. Line numbers appear only in parentheses and are hints — the tree is moving.

---

# CORRECTNESS

## Stage 0 — The silent drop dies

✅ **LANDED 2026-09-10 as issue 1401.** `LEDGER.md`'s Stage 0 block carries the numbers and
`receipts/05-stage-0-silent-drop.md` the account; **C36** below is the one thing this stage
measured that the plan had wrong. What follows is the stage as it was written.

**One commit. No ruling that blocks — one rule debt filed. No existing suite moves. RED first.**
This is the stage that has to ship whatever happens to the other fourteen.

Today, a state row whose `type` is anything but `op`/`dc`/`ac`/`tran` — a hand-edited `.state`, a
file from a future version, a row this plan's own Stage 5 will create — produces a run that
**completes normally and does nothing**. The emit loop never visits the row, the `switch` has no
`default` arm, `ase::n_enabled_analyses` counts it anyway so the deck still gets `set appendwrite`,
and the Analyses pane still shows it ticked with its arguments beside it.

### 0a. The emit loop iterates the ENABLED ROWS, not a fixed order

The current shape and the failure are the same line. Today:

```tcl
set anorder {op dc ac tran}
foreach type $anorder {
  foreach a [ase::state_get $state analyses] {
    if {[ase::state_get $a type] ne $type} { continue }     ;# <- the drop, silently
    …
  }
}
```

The replacement walks the rows and then orders them, so a row that is not in the order is still
*visited*:

```tcl
# <ISSUE>: ITERATE THE ROWS, THEN ORDER THEM -- never iterate the order.
# A row whose type is not in the emit order used to be skipped by the `continue`
# above, while n_enabled_analyses still counted it and the pane still showed it
# ticked: the run completed, wrote a rawfile, and produced nothing. There is no
# way for a user to tell that from a run that worked.
#
# ⚠ THE ORDER IS UNCHANGED AND MUST STAY UNCHANGED. `emit_rank` reproduces
# `op dc ac tran` exactly (op=0 dc=10 ac=20 tran=30) and the 0964 variant
# `dc ac tran op` by moving op to 90 -- the op-LAST rule is about ngspice's
# forward-sticky save list, not about this number, and it does not generalise
# to a new type. Deck golden D1 must not move.
proc ase::analysis_emit_order {state {op_last 0}} {
  set out {}
  set i -1
  foreach a [ase::state_get $state analyses] {
    incr i
    if {[ase::state_get $a enabled 0] ne {1}} { continue }
    set t [ase::state_get $a type]
    set r [ase::analysis_emit_rank $t $op_last]
    if {$r eq {}} {
      return -code error \
        "ase: analysis type '$t' is not one this simulator backend can render"
    }
    lappend out [list $r $i $t]
  }
  return [lsort -integer -index 0 [lsort -integer -index 1 $out]]
}
```

Substitute the number `doc/claude/issues/NUMBERING.md`'s **tail** gives at the moment of minting —
it read **1400** on 2026-09-09, and this plan is exactly the kind of document CREW_BRIEF forbids
trusting a number from.

`ase::analysis_emit_rank` is a four-entry lookup in Stage 0 and becomes `emitorder` off the registry
in Stage 1. The rank table is the *only* thing Stage 1 replaces here; the loop shape is final.

### 0b. `ase::preflight_gate` learns the same question

The refusal must arrive **before any artifact is touched**, not from inside `render_deck` when the
deck is half written. `ase::preflight_gate` already refuses a run whose saved output names do not
resolve; it gains one more clause, in its own idiom, with the type named:

```tcl
  # <ISSUE>: an enabled analysis this backend cannot render is a REFUSAL, not
  # a silent skip. Named here as well as in render_deck because the gate runs
  # ahead of the deck write, and because a .state can be hand-edited.
  foreach a [ase::state_get $state analyses] {
    if {[ase::state_get $a enabled 0] ne {1}} { continue }
    if {[ase::analysis_emit_rank [ase::state_get $a type]] eq {}} {
      lappend bad [ase::state_get $a type]
    }
  }
```

Same substitution rule for `<ISSUE>` as above.

⚠ **This clause is NOT defeasible by `set ase_preflight 0`.** That escape exists today (hint `:4742`)
and is a real lever for the save-name check; a run that emits no analysis at all is not something the
user can usefully override. Put the type check **above** the `ase_preflight` early return.

### 0c. `ase::plot_sim_type` answers `{}` honestly

It walks `{op dc ac tran}` and returns the last enabled. A state whose only enabled row is `noise`
gets `{}` today — which is correct — but by accident: it is the same `{}` a state with nothing
enabled gets. Make the two distinguishable so the caller can say *"this analysis has no viewer
mapping yet"* instead of *"nothing ran"*. One extra proc, no behaviour change to the existing four.

### 0d. Two stale sentences in the spec of record, fixed while you are in there

`doc/claude/specs/ase_l.md` still claims running is top-only, in **two** places, and its own
`### Netlist and Run works from any level of the design (issue 0643, 2026-09-08)` section (hint
`:697`) says the opposite:

* *"…and RUNNING is still top-only — `ase::netlist` requires the design to be the current schematic,
  so ascend before Run"* (hint `:946-947`);
* *"only the RUN is top-only"* (hint `:997`).

Nothing else in this plan touches them, and `evidence/ase-conventions.md` §11.1's rule is to fix a
paragraph you invalidate in the same commit. ⚠ There are **two** occurrences, not the one the
conventions dossier knew about. This stage owns both.

### What you see, the moment the window reopens

1. **Nothing, on any bench that works today.** That is the point: this stage is invisible until
   something is wrong.
2. A bench whose `.state` carries an analysis type this build cannot render **refuses at Netlist &
   Run**, before the netlist is written, with the type named:
   *"ase: analysis type 'noise' is not one this simulator backend can render"*.
3. The refusal lands in the action log through `ase::echo`, which is where every other ASE-L refusal
   lands, so the headless suites can assert it.

### Files and procs

| file | proc | ± |
|---|---|---|
| `src/ase.tcl` | **new** `ase::analysis_emit_rank`, **new** `ase::analysis_emit_order`; `ase::backend::ngspice::render_deck`'s emit loop; `ase::preflight_gate`; `ase::plot_sim_type` | **≈ +55 / −14** |
| `doc/claude/specs/ase_l.md` | `## Deck assembly (no C changes)` — the *"`analyses` render into one `.control` block … in a fixed order"* bullet (hint `:88-89`) gains the "a type the registry does not know is a refusal" sentence; the **two** stale top-only sentences (0d, hints `:946-947` and `:997`) | **≈ +6 / −4** |

### Suites that move

**None move. Four rows are added, and one of them is written RED first.**

* **RED FIRST, and it must pass-then-fail for the stated reason before anything is changed.** A new
  row in `test_ase_core.tcl`'s D section: take `[nfet_state …]`, set `analyses` to
  `{{type noise enabled 1 output v(out) source v1 sweep dec points 10 start 1 stop 1meg}}`, call
  `render_deck`, and assert the deck it produces **contains no analysis command at all**.
  ⚠ **CORRECTED 2026-09-10 BY MEASUREMENT (C36): today it is `.control` / `set appendwrite` /
  `print …` / `.endc` / `.end` — there is NO `remzerovec` and NO `write`**, because 0929 moved
  both inside the per-analysis loop, so the run writes no raw file at all rather than an empty
  one. Exit 0 either way. Write the
  row asserting *today's silence*, watch it pass, then change the code and watch it fail. Then invert
  it to assert the refusal. **The point is to see the silence once, in the suite, before it is
  fixed**; a fix landed without that step has no witness that the defect existed.
* `test_ase_core.tcl` — a row for the raised error and its sentence; a control row proving the four
  known types are untouched (**D1** must still be byte-identical, and **D2**'s "no dc line while dc
  disabled").
* `test_ase_preflight.tcl` — a `PF2xx`-shaped row for the gate refusal, plus one asserting
  `set ase_preflight 0` **does not** defeat it.
* Sabotage-verify: no-op `analysis_emit_rank`'s `{}` return, confirm exactly those rows go red,
  restore by `cp` from a pristine copy and md5-compare. Never `git checkout/restore/stash/clean`.

### Re-measure on the dev display

**None — this stage is headless by construction.** It changes no widget, no label and no layout; its
entire deliverable is a refusal that lands in `ase::echo` and in `ase::preflight_gate`, both of which
the headless suites read. There is no pixel to look at, so this stage files **no look debt**.

### Rulings in this stage

**None that block.** One user-facing sentence is minted — *"ase: analysis type '<t>' is not one this
simulator backend can render"* — and CREW_BRIEF's standing rule is that a new user-facing sentence is
the user's ruling, not a crew's. So: **mint it, ship it, and file `owed.sh add rule <issue>` at the
moment it lands**, then pay it with Stage 3's ⚖ R9 batch. It blocks nothing: the sentence is a
refusal in the `ase::echo … error` idiom every other refusal in the file already uses, and Stage 0
ships the day it is read.

---

## Stage 1 — The registry, byte-identically

**One commit. No ruling. The acceptance criterion is BYTE-IDENTITY, and it is a stop condition.**

> **If re-expressing today's four analysis types through the new registry cannot reproduce today's
> decks byte for byte, the descriptor's shape is wrong and the plan stops there.** Do not adjust the
> golden. Do not add a compatibility arm. Change the descriptor until deck golden **D1** in
> `test_ase_core.tcl` compares equal under `string equal`, or bring the shape back to be re-designed.

**What this stage actually is: the FIRST ADAPTER.** Read as a de-duplication it is a refactor that
collapses eight literals into one; read for what it is for, it is where ASE-L stops holding
per-simulator knowledge at all (§0.10, §1). Two halves, two owners, and they must not be confused:
**§1a's `CONTRACT, key by key` comment block is the SCHEMA, and ASE-L owns it** — the key set, what
each key means, the readers, the one emitter and the refusals; **the four `op`/`dc`/`ac`/`tran`
entries under it are CONTENT, and the ngspice adapter owns them.** Nothing in the schema half may
spell an ngspice word, and nothing in the content half may be reached except through the hook a
second simulator's adapter would use. A stage after this one that needs a private path from ASE-L
core to the ngspice backend has found a **missing schema key** — that is the finding, not the
workaround. Sub-item **1e** below is the check on that claim, and it happens before this stage's
acceptance is claimed.

**The naming rule every later stage inherits, and it is part of this stage's acceptance: a proc is
named on the side of the line it belongs to.** `ase::…` is the SCHEMA — the readers, the one speller
per surface, the refusal evaluator, the state keys. `ase::backend::<sim>::…` is the CONTENT — any
proc that spells a simulator's syntax, encodes one of its traps, or enumerates its facts, including
every `{build <proc>}` emit escape (§1c) and every catalogue. **A registry entry, and every value in
it, is adapter content**: it reaches core through the hook and is never a `variable` in `ase.tcl`.
The tree already says this in its own voice — `ase::register_backend ngspice …` is called from inside
`namespace eval ase::backend::ngspice` in `src/ase.tcl`, under the comment *"Kept inside this
namespace eval so the only ngspice literals outside `ase::backend::ngspice` stay the `state_default`
schema defaults."* Stage 1 keeps that promise instead of eroding it. Where the answer is genuinely
arguable a stage **says which side and why** rather than defaulting: `ase::netlist_facts` (Stage 4)
stays core because it reads the SPICE netlist xschem itself emits, and `ase::si_parse` (Stage 3)
stays core because it only validates what the user typed — the value is emitted **verbatim** (§1b) and
never re-spelled. **The stages whose file tables were re-checked against this rule when the pivot
landed, and changed, are 5, 7, 8, 9 and 14.** A file table that names a proc on the wrong side is the
table that is wrong; this rule wins.

Eight literals (§0.3) are eight copies of the answer to *"what is a dc analysis"*, each of which fails
silently when it drifts — and one already has: `anaargs` advertises `ac {points start stop dec}`,
`chana_fields ac` returns `{points start stop}`, and `render_deck` hardwires the word `dec`. The `dec`
key is a control the window offers, the state stores, and the deck ignores.

### 1a. `ase::analysis_types` — the schema ASE-L owns, and the first adapter's content

The comment block below is the schema. The entries after it are ngspice's, and they are the first
thing ever written through this contract, which is the only reason to trust that the key set is
expressive enough to be worth having.

⚠ **This covers every registry entry in the plan, not only Stage 1's four.** Stage 5's three, Stage
6's three, Stage 9's `sp` and Stage 14's `pss` are adapter content declared through the same hook,
even where those stages' file tables say only *"registry entries"* against `src/ase.tcl` — the file
they live in is `ase.tcl` today because `ase::backend::ngspice` is a namespace inside it, and the
namespace, not the filename, is what the rule is about. A later crew that moves the adapter into its
own `.tcl` file owes `src/Makefile.in` and a `./configure` re-run, verified with
`grep -c <newfile> src/Makefile`, expect **2** (issues 0423 / 0424).

```tcl
# ── ase.tcl ────────────────────────────────────────────────────────────────
# THE analysis registry. Backends declare it through an OPTIONAL
# `analysis_types` hook -- optional is already the established shape:
# ase::register_backend requires exactly the five hooks and tolerates extras,
# which is how `capabilities`, `op_param_set` and `op_param_enumerable` already
# ride (row A3 of test_ase_simcaps_0948 pins the five). ase::analysis_types
# resolves the hook for the simulator in force and falls back to {} -- NEVER to
# a literal list, because a literal fallback is the ninth copy.
#
# CONTRACT, key by key
#   label      display noun. USER-FACING -> ratify before minting.
#   verb       the .control command word AND what `help <verb>` is probed with.
#              ngspice has THREE namespaces for one analysis: verb `noise`,
#              registry `NOISE`, plot `Noise Spectral Density Curves`.
#   gated      1 when an #ifdef in commands.c can remove it. The NINE
#              `ac dc op tran pz tf disto noise sens` are unconditional in every
#              ngspice that has ever shipped; only `sp` (RFSPICE) and `pss`
#              (WITH_PSS) are bracketed. Stage 2 explains why this column exists.
#   registered 1 when the GUI offers this type at all -- the switch that lets a
#              type be described here and NOT shown, so a half-built entry can
#              land in one commit and be turned on in the next. Stage 1's four
#              are all 1; nothing in Stage 1 reads it yet.
#   emitorder  ascending: op=0 dc=10 ac=20 tran=30 reproduces today's order
#              EXACTLY; new types take 40+. `op` LAST is a SEPARATE NAMED RULE,
#              not this number -- its reason is ngspice's forward-sticky save
#              list and it does not generalise.
#   viewrank   which analysis the waveform window opens on when several are
#              enabled. SEPARATE FROM emitorder ON PURPOSE: ase::plot_sim_type
#              is a PREFERENCE ranking and its own header says issue 0964 broke
#              the coupling to emit order and it must not be re-established.
#   fields     ORDERED list of field descriptors (1b). ONE list, THREE roles:
#              form order, Arguments-column order, emit slot order. Two lists is
#              exactly how `ac`'s `dec` drifted.
#   emit       a TOKEN TEMPLATE (1c), or {build <proc>} for the two shapes a
#              template cannot express.
#   plots      list of {match <glob on the Plotname literal> when <pred>
#              role <r> results <dest> label <user string>}.
#              ⚠ LENGTH IS A PREDICATE, NOT A CONSTANT (see 6b).
#   needs      precondition ids evaluated against netlist_facts (Stage 4).
#   fatal      the subset of `needs` whose failure DESTROYS the run rather than
#              degrading it. Re-checked in render_deck, not only in the dialog.
#   rules      cross-field and option x analysis refusals (1d).
#   options    the per-analysis subset of the option catalogue (Stage 7).
#   results    every plot names a destination. NO ANALYSIS MAY BE REGISTERED
#              WITHOUT ONE -- that is how "the Value column holds a scalar" is
#              enforced structurally instead of remembered. Every destination in
#              APPENDIX §6.2 must appear in some registry row's `results`, and a
#              row without one is a LOAD-TIME error (D30).
#
#   ── ADDED 2026-09-10 BY THE VARIANT AMENDMENT (§0.13, D42-D52). THESE THREE
#      LAND IN STAGE 1 OR THEY CANNOT LAND AT ALL, because Stage 1 is where the
#      schema freezes and where 1e grades it. A `requires` key added in Stage 7
#      would be graded by nobody, and 1e would have validated a schema that
#      cannot express a variant -- which is the one thing the amendment exists
#      to make expressible. ⚠ THEY MOVE NO BYTE OF OUTPUT: Stage 1's acceptance
#      is byte-identity of deck golden D1 under `string equal`, and adding a
#      descriptor KEY does not move it. ────────────────────────────────────────
#
#   requires   OPTIONAL. A COMMAND PREFIX (D35: adapters are executable Tcl)
#              answering a THREE-VALUED question about the ADAPTER's own facts:
#              `present` / `absent` / `unknown`. Valid at THREE levels with
#              IDENTICAL semantics -- on this registry entry, on an option-
#              catalogue row (Stage 7), and on a FIELD descriptor (1b) -- so one
#              evaluator reads all three and there is one rule and one test.
#              ⚠ THE PREDICATE NEVER STARTS THE SIMULATOR. `caps` arrives as an
#              ARGUMENT, already in hand from the free peek or from a Run that
#              warmed the cache; D8 is the rule and a predicate that called
#              ase::sim_capabilities itself would put a 31.2 s freeze behind
#              every form the user opens.
#              ASE-L owns the four-state grid and the fallback; the adapter owns
#              only the three-valued answer:
#                  proc ase::requires_state {req caps gated}
#                    present -> {state ok     reason {}}
#                    absent  -> {state absent reason notbuilt}
#                    unknown -> gated ? {state absent reason unmeasured}
#                                     : {state ok     reason baseline}
#                    raised  -> {state caution reason requires_raised}
#              The `unknown` arm IS D6's ungated-baseline rule, in one place
#              instead of at every reader.
#   notes      OPTIONAL hook name. -> ordered {token severity clause} triples,
#              the clause list §16a's per-simulator sentence is composed FROM.
#              ⚠ D5-4 (ASE-L mints every user-facing sentence) and D34 (no
#              per-simulator fact in ASE-L's source) collide here, and the
#              resolution is written down rather than discovered: ASE-L owns
#              every FRAME and every sentence about its own machinery; an
#              adapter may supply a CLAUSE; an adapter clause is ratified under
#              ⚖ R9 exactly like any other label.
#   lint       OPTIONAL hook name. -> {token severity line clause} over
#              user-supplied control text (Stage 16b). Severity is
#              note/warn/refuse, and THE ADAPTER PROPOSES WHILE ASE-L DISPOSES:
#              the adapter says which class the pattern is in (M-free /
#              M-artifact / M-refusal, D46) and ase::preflight_notes applies
#              D47's policy, including "never refuse on an unmeasured build".
#              A future adapter with a different hazard set gets that for free.
proc ase::analysis_types  {{sim {}}}       { … resolve the hook, cache per sim … }
proc ase::analysis_entry  {sim type}       { … {} when absent … }
proc ase::analysis_field  {sim type field} { … }
proc ase::analysis_plots  {sim row opts}   { … evaluate `when`, return count+matches … }
proc ase::requires_state  {req caps gated} { … the four-state grid, in ONE place … }
```

⚠ **`requires` is NOT a new sub-item, and that is deliberate.** An earlier draft of this amendment
proposed it as *"new sub-item 1e"* — **1e is already taken**, by the Xyce paper-validation that
§8a's own scheduling argument says must **grade** it. Scheduling the amendment's most important
addition on top of its own grader is a wrong turn. It rides **1a** (this contract block) and **1b**
(the field level), and **1e is re-run against the schema including all three keys.**

The four Stage-1 entries are today's four, and `op`'s is the shortest thing in the file:

```tcl
op   { label {Operating point} verb op gated 0 emitorder 0  viewrank 40 registered 1
       fields {}  emit {op}
       plots {{match {Operating Point} role scalars results value label {Operating point}}}
       results {value {kind opvectors}} }

tran { label {Transient} verb tran gated 0 emitorder 30 viewrank 30 registered 1
       fields {step {kind time label {Time step} unit s required 1 gt 0}
               stop {kind time label {Stop time} unit s required 1 gt 0}}
       emit  {tran @step @stop}
       plots {{match {Transient Analysis} role sweep results viewer label {Transient}}} }
```

`dc` and `ac` follow the same shape. **`ac`'s Stage-1 entry emits the literal `dec`**, exactly as
`render_deck` hardwires it today — the sweep-mode field arrives in Stage 3, and Stage 1 is not allowed
to change a byte of output. That is the discipline: the registry lands as a *pure refactor*, and the
capability it enables lands one stage later, where a moved golden is expected and named.

### 1b. The field descriptor — `kind` is the whole type system

| `kind` | widget | validate | emits | picker |
|---|---|---|---|---|
| `int` | entry | integer, `min`/`max` | bare | — |
| `real` | entry + suffix parser | SPICE suffix `f p n u m k meg g t` | **verbatim as typed** | — |
| `freq` | entry + suffix, unit `Hz` | `> 0` for `dec`/`oct` | verbatim | — |
| `time` | entry + suffix, unit `s` | `>= 0` | verbatim | — |
| `mode` | readonly `ttk::combobox` | member of `values` | the token | — |
| `bool` | `checkbutton` | — | present/absent, **never `=1`** (T4) | — |
| `node` | entry + **Pick** | `ase::netlist_map_resolve` | `v(<n>)` | `ase::ui::select_on_design` |
| `nodepair` | two entries + Pick | both resolve; ref optional | `v(a)` or `v(a,b)` | `ase::ui::select_on_design` |
| `source` | combobox from `netlist_facts` + Pick | in the filtered set | the instance name | `ase::ui::select_on_design` |
| `device` / `param` | combobox from `netlist_facts` / `devhelp -flags` | in the set | as typed | — |
| `glob` | entry | non-empty | as typed | the Stage 5 picker |
| `expr` | entry | the measure grammar (Stage 8) | as typed | Calculator |

**`real`/`freq`/`time` emit VERBATIM.** ngspice's own parser is the authority and a round trip through
a Tcl double turns `1meg` into `1000000.0`. The GUI parses only to validate and to compute derived
readouts. Recorded decision N already requires this for stored numerics.

**Every field descriptor may carry `requires`, with 1a's semantics unchanged** (added 2026-09-10,
§0.13, **D42**). A field that exists only on some builds is expressed at the field level rather
than by splitting the analysis into two entries:

```tcl
{name portnum label {Port} kind int requires ::ase::backend::ngspice::req_rfspice}
```

and the adapter's side is three lines that read the dict and never launch anything:

```tcl
proc ase::backend::ngspice::req_rfspice {caps} {
  set g [ase::caps_get $caps flags]
  if {![dict get $g measured]} { return unknown }
  return [expr {[dict exists [dict get $g value] rfspice] &&
                [dict get [dict get $g value] rfspice] == 1 ? {present} : {absent}}]
}
```

⚠ **`unknown` at field level resolves through the SAME `ase::requires_state`** — a field on an
ungated analysis stays offered, a field on a `gated 1` analysis goes `absent`-with-Detect. One
evaluator, three levels, one test row per level.

### 1c. One emitter, and the Arguments column becomes the emitted line

```
@name    required slot
@name?   optional; omitted when empty
@name!   optional WITH A DEPENDENCY: emitting it forces every EARLIER optional
         slot to be materialised with its `whenskipped` default, because
         ngspice's argument lists are POSITIONAL. This is the rule
         `tran tstep tstop [tstart [tmax]] [uic]` needs: a tmax with no tstart
         must emit `tstart 0`, never shift a slot.
{build <proc>}   the escape hatch, used by exactly two types --
         NOISE's v(out,ref) composite and PZ's four-node + two-mode-word form.
```

**`ase::analysis_line {sim row}` builds the deck line AND the Arguments column, and nothing else may
spell an analysis line.** `render_deck` calls it; `ase::ui::arg_summary` calls it and renders the
result, falling back to today's `key=value` dump when the backend in force declares no
`analysis_types` hook. From that moment it is *structurally impossible* for the pane to show a setting
the deck does not carry — which is the whole reason `ac.dec` could drift.

### 1d. The `.form` child frame, and the six lines that move with it

`ase::ui::chana_show` destroys a **hardcoded five-name list** before rebuilding:

```tcl
foreach f {source start stop step points} { catch {destroy $w.$f} ; catch {destroy $w.l$f} }
```

`evidence/ase-ui.md` calls that the single sharpest trap in the analysis code, and it is: add a sixth
field name to any type and the fifth one's widget survives the rebuild. There is also a ceiling —
`Options…` is grid row 8 and the button bar row 9, so a seventh quick field collides. NOISE has eight
fields and DC-with-a-second-sweep has ten; the current layout cannot hold either.

One `$w.form` child frame kills both: `destroy $w.form` is exhaustive by construction, and the form
owns its own row space.

⚠ **This relocates `$w.step` / `$w.stop` to `$w.form.step` / `$w.form.stop`, and six lines of
`test_ase_dialogs.tcl` drive those by path** (§0.2). They move, deliberately, in this stage, and this
stage says so. `$top.chana.types.*`, `$top.chana.opts` and `$top.chana.btns.*` are untouched — adding
paths is safe, moving them is not, and these six are the only ones moved.

### 1e. Xyce's descriptor, on paper, before the shape is fixed

⚠ **AMENDED 2026-09-10: this exercise is re-run against the schema INCLUDING `requires`, `notes`
and `lint`** (1a, 1b), and it now has a second question to answer beside D37's. D37 asks *"what
does a second simulator break in the schema?"*. The variant amendment adds *"can this schema say
that an analysis exists on one build of ONE simulator and not on another?"* — which is not
hypothetical for ngspice: on this machine `/usr/bin/ngspice` has `pss` and CIDER and
`build-ver_50` has neither (§0.13.4, `APPENDIX` §1.8). Xyce's descriptor is where a `requires`
predicate is first written by somebody who is **not** the ngspice adapter's author, which is the
only cheap way to find out whether the three-valued contract is a general shape or an ngspice
accident.

**A schema with exactly one implementation is not a schema; it is a transcription of that
implementation.** So before Stage 1's acceptance is claimed, write **Xyce's adapter descriptor on
paper** against the §1a key set — *on paper*: no implementation, no file under `src/`, no second
backend registered, nothing that could become a maintenance obligation. Xyce is the useful adversary
because it breaks three assumptions ngspice lets the schema keep:

* **a native `.STEP`** — the sweep axis belongs to the simulator, not to the GUI. Everything in
  Stage 11 and ⚖ **R8** assumes the opposite;
* **no interactive control language** — so *"an analysis is a `.control` command word, never a dot
  card"* is an ngspice fact currently wearing a schema's clothes, and `verb`, the `emit` template's
  whole shape, and the `help <verb>` probe of Stage 2 all rest on it;
* **a different output format** — so the `setplot previous` walk, the `.plotmap` sidecar and the
  mandatory `results` destination (D30) have to be nameable without a rawfile underneath them.

**The deliverable is "what broke"**, written as a list: every key that could not express Xyce, and
every key that expressed it only by naming something ngspice-shaped. *"Nothing broke"* is a
suspicious answer — attach the descriptor to the receipt so a reader can check it. Then **fix the
schema against that list and only then claim byte-identity**, because changing a key set is free
while it has one implementation and costs eight readers afterwards. It produces no code and moves no
suite; its record is the *Xyce paper-validation — what broke* row in `LEDGER.md`'s Stage 1 block and
a paragraph in the stage receipt. `DECISIONS.md` **D37** carries the decision, and ⚖ **R10** — how
much further the formalisation goes than this — is **not** answered by it.

⚠ **This does not soften the stop condition, it precedes it.** Byte-identity over today's four types
is still the gate; what 1e can change is the descriptor's key set, which is exactly what the stop
condition tells you to change when D1 will not compare equal.

### What you see, the moment the window reopens

1. **The Arguments column stops being a key dump.** A dc row reads `dc V2 0 1.8 0.01` — literally the
   line in the deck — where it read `source=V2 start=0 stop=1.8 step=0.01`.
2. **Nothing else changes.** Same four radio buttons, same fields, same order, same deck. That is the
   acceptance criterion, on screen.

### Files and procs

| file | proc | ± |
|---|---|---|
| `src/ase.tcl` | **new** `ase::analysis_types` / `analysis_entry` / `analysis_field` / `analysis_plots` / `analysis_line` — the schema readers and the one speller; **the four `op`/`dc`/`ac`/`tran` entries are adapter content in `ase::backend::ngspice`, declared through the hook (§1a), not a core variable**; `ase::analysis_emit_rank` now reads `emitorder`; `render_deck`'s emit `switch` **deleted**; the print-anchor loop reads the registry; `ase::plot_sim_type` reads `viewrank`; `ase::state_default`'s seed reads the registry | **≈ +240 / −60** |
| `src/ase_window.tcl` | `ase::ui::choose_analyses`' radio `foreach` reads the registry and builds `.form`; `ase::ui::chana_fields` becomes a registry reader; `ase::ui::chana_show`'s destroy list becomes `destroy $w.form`; `ase::ui::arg_summary` calls `ase::analysis_line`; the `anaargs` variable **deleted** | **≈ +90 / −70** |
| `doc/claude/specs/ase_l.md` | `### Panes (ONLY these three; log pane REMOVED)` — the *"**Analyses** (right top): columns Type, Enable (checkbox), Arguments (view-only one-line summary)"* bullet (hint `:884-885`), because the Arguments column stops being a key dump and becomes the emitted line | **≈ +3 / −1** |

### Suites that move

* **`test_ase_dialogs.tcl` — six path lines** (`:625`, `:626`, `:629`, `:655`, `:656`, `:657`), all in
  G2/G2b, all gaining `.form`. ⚠ **AND `test_ase_persist.tcl` G2, through a variable** — the sentence
  *"nothing else in the tree drives a quick field by path"* that stood here was false and is corrected
  at §0.2; issue **1405** is the repair, and **G2p** now pins both halves of the path.
* **`test_ase_window.tcl` P4** (`arg_summary dc row`) and **`test_ase_dialogs.tcl` G2**
  (`Arguments summary shows the fields`) — two display-string goldens, `source=V2 start=0 stop=1.8
  step=0.01` → `dc V2 0 1.8 0.01`. **Both are display strings, not deck output.**
* **Must NOT move, and are the acceptance:** `test_ase_core.tcl` **D1** (the golden deck, compared with
  `string equal`), **D2**, **R1** (`version is 1`; `analyses are the four types in order`), **R4**;
  `test_ase_view.tcl` **V4**; `test_ase_persist.tcl` **R2**; `test_ase_final.tcl` **F3**;
  `test_ase_final_gf180.tcl` **G3**; every one of the **104** committed `.state` files (105 on disk, §0.5).
* **Must NOT move, and are declared out of scope in this stage's receipt:** `test_rdw_seam_1245`
  **G3/G3b** (`op_param_set`'s `{op dc}` allow-list), `rdw.tcl`'s copy of that list, `xschem.tcl`'s
  sim-type combobox. Name them; do not touch them.
* **`test_ase_window.tcl` W1p** (`exactly the three v2 panes`, `variables columns`) is unaffected — the
  pane model does not change — but re-run it, because `arg_summary` feeds the `args` column.

### Re-measure on the dev display

**None — this stage is headless by construction, and that is its acceptance criterion.** The whole
point of Stage 1 is that the window looks *identical*: same four radios, same fields, same order,
same deck. The one visible change is a display string (`source=V2 start=0 stop=1.8 step=0.01` →
`dc V2 0 1.8 0.01`) which two suite rows assert by value, not by pixel. If anything on screen moves,
the descriptor is wrong — that is the stop condition, not a look debt. **No look debt is filed.**

### Rulings in this stage

**None.** Every user-visible change here is either invisible (the registry) or a strictly more honest
rendering of a string the window already shows (the Arguments column). The `label` strings for the
four existing types are the words already on the radio buttons.

---

## Stage 2 — The type list is measured

**One commit. Rulings ⚖ R4, ⚖ R9.**

**Eleven analysis types exist, and with the options sheet they make twelve grid rows.** ASE-L offers
four. Two of the eleven (`sp`, `pss`) are `#ifdef`-gated and genuinely may be absent from the user's
build; the other **nine** — `ac dc op tran pz tf disto noise sens` — are unconditional in every
ngspice that has ever shipped. (`analInfo[]` at `analysis.c:36-59` holds twelve entries in a build
with both flags, but one of them is `OPTinfo`, which is **not runnable**: `cktsopt.c:389-403` gives
it `size = 0`, `an_init = NULL`, `an_func = NULL`, and it never enters `CKTdoJob`'s loop. In *this*
build ten analyses run, because `pss` is absent; eleven across builds. APPENDIX §0, §1.) A user who cannot find `pss` in ADE-L has no way to learn why, and that is the first
place this design is plainly better: **four states, never invisible.**

| state | when | what the user sees |
|---|---|---|
| `ok` | in the registry ∧ the binary has it ∧ this netlist permits it | normal |
| `caution` | permitted, with warnings | offered, plus a sentence saying what will be wrong |
| `blocked` | the binary has it, this netlist does not permit it | offered, **disabled**, with the reason **and the fix** |
| `absent` | the binary does not have it | listed, **disabled**, *"this ngspice was built without PSS (`--enable-pss`)"*, plus a **Detect** button |

### 2a. One new probe leg, in the existing capability deck

No new run. `ase::sim_capabilities`' deck gains, per registry verb:

```
foreach v <the registry's verbs>
  echo "== $v" >> cap.txt
  help $v      >> cap.txt
end
devhelp        >> fam.txt
```

Three rules, each with a measured reason:

* **Never `help all`** — it truncates at the first NULL `co_func` (`com_help.c:56`).
* **Never the exit code** — a parse-only probe deck exits 1 while writing its redirects correctly. The
  verdict is read from the **file**.
* **Parse rule: keep a stanza only when its first token equals the verb probed.** This survives the
  upstream copy-paste bug that makes `help tf` print `tf [.tran line args] : Do a transient
  analysis.` Measured: all ten present verbs answered; `pss` and `hb` returned `Sorry, no help for …`.
* **Never the bare verb, in THIS deck.** A deck always has a circuit, even one with no devices, so
  inside `.control` the word is a command and not a question: measured 2026-09-10, `op` **ran**, and
  `pss` on `/usr/bin/ngspice` started a PSS run and did not return inside 30 s (§0.11). The bare verb
  is still the one probe that needs no help database — it belongs in Detect, 2b below.

The answer gains two keys beside the ones it already publishes:

```
{known 1 usable 1 appendwrite 1 blanket_op_save 0 hier_op_names 1
 analyses_available {ac dc disto noise op pz sens sp tf tran}
 devices_available  {resistor capacitor vsource … d_cosim adc_bridge …}}
```

`devices_available` is the `devhelp` dump. It is a **stronger** XSPICE signal than the `codemodel`
command — the command proves XSPICE was compiled, the models prove `spinit` actually loaded them — and
it is also the CIDER probe. ⚠ Do **not** test CIDER by row count: a non-installed build lacks `spinit`
and loses 81 XSPICE rows. Grep `^(NUMD|NBJT|NUMOS)`.

⚠ **OSDI makes `devices_available` incomplete by construction.** `osdi_add_device` appends OpenVAF
devices to `DEVices` at *load* time (`dev.c:584,608`), so a `devhelp` run against a **scratch** deck
cannot see a PDK's Verilog-A devices. Therefore an **unknown family is `caution`, never `blocked`**,
and any exact leg must run `devhelp` against the **user's own deck**. Otherwise the worst outcome this
design can produce — refusing an analysis that would have run — becomes the likely one on any
Verilog-A PDK.

### 2b. The unmeasured case, and why the dialog never starts a probe

`ase::sim_capabilities`' standing contract is that **a missing key means "not measured", never "no"**.
Applied naively that empties the dialog. So:

* `analyses_available` present → it is the authority, for gated and ungated alike;
* absent → offer the **ungated baseline** (`ac dc op tran pz tf disto noise sens`) as `ok`, and show
  every `gated 1` type as `absent`-with-Detect.

We never claim a measurement; we fall back to a source-verified invariant.

**The dialog must never start a probe.** `ase::sim_caps_have_path {backend path {eargs {}}}` returns
**0/1** and is the free peek; **Detect** is the only door to a cold measurement. Measured worst case
for a program that exists, is executable and never answers: **31.2 s**. A startup probe in front of
the analyses list would make opening it take 31 seconds.

**Two caches, two keys.** Binary → resolved path + mtime + size. Netlist → the exact netlist text (the
key `op_annot` already uses). They invalidate on different events.

**Detect gets a SECOND leg, and it is the one that closes M15.** The whole capability gate rests on
`help <verb>`, whose single unmeasured failure mode is a build with a relocated or stripped help
database (**M15**). The command table is a different oracle and needs no database at all — but only
with **no circuit loaded**, which no deck can provide (§0.11). Measured on both binaries:

```
printf '<verb>\n…\nquit\n' | <exe> -p
  build-ver_50      pss -> `pss: no such command available in ngspice`
                    sp, op -> `Error: there aren't any circuits loaded.`   (the verb exists)
  /usr/bin/ngspice  pss, sp, op -> `Error: there aren't any circuits loaded.`  (all three exist)
```

So: Detect may run it, the cached fast path never does, and **the two legs must agree**. A
disagreement is not a tie to break — it is exactly the signal M15 is looking for, and the honest
answer is to report it rather than pick a winner. ⚠ **This leg needs `-p`, and ⚖ R1 is now
ANSWERED — Option A, `-b` this batch — so the leg is DEFERRED with the transport.** Under `-b` it
cannot be built, and plain stdin is not a substitute, because ngspice reads those words as a netlist
and answers `Error: incomplete or empty netlist`. It is written down here because it is the reason
`-p` is still worth scheduling: the capability probe, not the abort, is what the adapter doctrine
now leans on. **M15 stays open until it can be built** — Stage 2 ships the `help <verb>` leg alone
and says so.

### 2c. The type grid

`.types` becomes a wrapping grid, four per row, twelve cells, each coloured by state. **No new colour
in the locked 9-colour palette** — a `⚠ ` glyph on the label plus the status line does the job, is
theme-proof, and needs no ruling.

### 2d. *Setup > Simulators* — the gesture the doctrine is built around

The user's framing of the pivot is *"once the user registers the simulator by going to Setup >
Simulators and adds a new one by specifying path, magic needs to happen"* (§0.10, §1). That gesture
already exists — `ase::sim_register {name path args}` takes a `-backend` option, and
`ase::register_backend {name hooks}` is keyed by backend name — so an entry can already **name** a
backend. What no stage said, until this one, is what happens when the backend it names has no
`analysis_types` hook. Composed from §1a's fall-back to `{}` and §1c's `arg_summary` falling back to
a `key=value` dump, the answer today would be an **empty grid and a key dump, with no sentence saying
why**. That is precisely the first-run friction the four-state rule exists to forbid, so this stage
owns three things:

1. **Where an adapter lives, and when it is loaded.** First-party, so this is a `source` at startup
   and **not** a discovery mechanism: today `namespace eval ase::backend::ngspice` sits inside
   `src/ase.tcl` and calls `::ase::register_backend` at source time, and `src/xschem.tcl` sources
   `ase.tcl` once (`source $XSCHEM_SHAREDIR/ase.tcl`). A second adapter is a second
   `namespace eval ase::backend::<sim>` doing the same. If it is given **its own file**, that file
   must join `src/Makefile.in`'s install list and `./configure` must be re-run — verify with
   `grep -c <newfile> src/Makefile`, expect **2** (issues 0423 / 0424; an installed xschem otherwise
   segfaults at startup sourcing a file it never installed).
2. **An empty grid says why it is empty — and this is NOT a fifth cell state.** The four states are
   per analysis; a simulator with no `analysis_types` hook contributes **no rows at all**, so there
   is nothing to colour. Reusing `absent` would be a lie of exactly the kind the grid was written
   against: `absent` means *this binary lacks the analysis*, a fact about the user's build, and
   nobody measured anything here. The surface is therefore the dialog's own status line above an
   empty grid, with **no Detect button**, because no probe can help — the gap is in ASE-L, not in
   the binary.
3. **The sentence itself is ⚖ R9's**, batched with this stage's other labels: *"ASE-L has no adapter
   for this simulator yet, so it cannot list its analyses."* Recommended shape, not ratified — it
   states the gap and does not blame the binary.

⚠ This is a **grid-and-dialog** item, not a new registration mechanism, and **it adds no state to the
four**. Nothing here changes `ase::sim_register`, its conf file or its five gestures; what is added
is one sentence, shown where twelve cells would otherwise be shown empty.

### 2e. The Stop warning — what a Stop costs, said before it is pressed

⚠ **This item is not thematic to Stage 2 and is not pretending to be.** It rides Stage 2's ⚖ R9
batch because it is a user-facing sentence and Stage 2 is the first stage in the plan that carries
one. It is **not** in Stage 0: Stage 0's whole claim on shipping first is that it costs no ruling and
moves no existing row, and a new sentence costs ⚖ R9. It is not in Stage 6f either, because it must
ship **before** salvage does — the warning is what is honest until salvage lands, not a substitute
for it (⚖ R1's requirement; the *Salvaging a stopped run* block of §0.1 *Measured facts* is the
measured basis).

**What is true today, and unsaid.** Both Stop doors call `ase::ui::do_stop` → `kill_running_cmds
$id -9`. ngspice in batch installs a handler for **no signal at all** — `main.c` puts the whole block
inside `if (!ft_batchmode)`, and SIGTERM, SIGHUP and SIGQUIT are installed in no mode — so the
process dies at the default disposition, in **a few milliseconds at worst**, and nothing of the
analysis in flight is on disk. The window says none of that. The Stop succeeds silently and the user goes looking for a
rawfile that was never written.

**What the user sees, and when. Two places, both plain text, no dialog.**

1. **At launch — in the run log header, and as a CIW note.** One sentence, every run, for as long as
   that run has no checkpoints: *"Stopping this run discards it — ngspice in batch mode writes
   nothing on a stop."* `ase::run_log_header` already composes the header, so the log copy is one
   line; the note goes through `ase::echo`, which is where every ASE-L sentence goes
   (`ase::run_busy_msg`'s refusal, `do_stop`'s own *"no simulation running"*, `attach_dbs`'
   *"NOT ATTACHED"*). ⚠ **Not the status line** — `ase::ui::set_status` sets a one-word coloured
   label (`Running` / `Ready` / `Error`), and a sentence does not fit there.
2. **At the moment of the Stop, in the CIW**, from `ase::ui::do_stop`, and **only on the path that
   actually killed something**: *"ase: simulation stopped — nothing of this run was written."* The
   nothing-to-stop path keeps the sentence it has.

Both are recommended shapes, not ratifications (⚖ R9).

**Two refusals, each with a reason that is already in the tree.**

* **No modal confirm.** `test_ase_core.tcl` RG13 drives `ase::ui::do_stop` headless and reads its CIW
  line; a modal would hang it, which is the same reason *What this plan refuses* rules out modal
  dialogs. A confirm also stands in front of the one gesture a user presses having already decided.
* **Not on the strip button's tip.** Issue 1391 minted `ase::ui::strip_tips`' `stop` entry as exactly
  `[ase::ui::menu_path_stop]`, and three rows of `test_ase_window.tcl` hold it there: **W1s1** — the
  one that matters here — asserts the `!` button's tip is *both* that constant and the literal
  `Simulation > Stop`; **W1s2** is the gap guard (a strip child with no tip is a red row); **W1s2b**
  pins the key set to the packed buttons, in strip order. A warning there breaks the invariant that
  a tip and its menu twin cannot drift, and `!` has room for a menu path, not for a sentence.

**What changes when Stage 6f lands.** Sentence 1 becomes conditional — a checkpointed run says what
it will lose and what the checkpoints cost instead (6f) — and sentence 2 gains the salvaged-file
case. It is the same line in the same proc either way, which is why it goes in first rather than
waiting.

### 2f. THE VARIANT RECORD — four bands of keys, three predicates, no second store

*Added 2026-09-10 (§0.13, `DECISIONS.md` **D42**, **D48**). Stage 2 already owns "the type list is
measured", already adds `analyses_available` and `devices_available` to this same dict, and already
carries the missing-key contract. **The record is born here** and there is no second store.*

```tcl
# BAND 1 -- IDENTITY. Display and logs only. NEVER a gate, NEVER compared.
  version_line       "ngspice-45.2" | "ngspice-46+"      # `version -v`, one bare line
  build_date         "Fri Sep 12 11:58:13 UTC 2025"      # `version -d`
  scripts_dir        "/usr/share/ngspice/scripts"        # from $sourcepath, for 16c
  curcasemode_default  none|fold|preserve|distinguish    # ⚠ IDENTITY ONLY -- see D52

# BAND 2 -- CAPABILITY. Gate UP with ase::caps_is. 1 = proven present,
#                       0 = proven absent, ABSENT = not measured.
  usable  appendwrite  hier_op_names  blanket_op_save  altshow_op_dump     # shipped
  casemode_detected  {fold preserve distinguish}   # shipped; LIST; owned by D52's legs
  analyses_available {ac dc disto noise op pz sens sp tf tran}   # 2a; LIST
  devices_available  {resistor … NUMD NBJT …}                    # 2a; LIST
  flags  {xspice 1 osdi 1 rfspice 1 klu 1 pss 0 cider 0}

# BAND 3 -- DEFECT. Gate MITIGATIONS with ase::caps_measured_as.
#                   ⚠ POLARITY IS "1 = SOUND", the same as altshow_op_dump.
  one_vector_write  0|1   # 1 = a one-save op plot comes back holding ONE vector
  keyword_case      0|1   # 1 = a capitalised keyword ARGUMENT resolves
  gnd_literal       0|1   # 1 = a bare `gnd` token survives a control argument list

# BAND 4 -- PROVENANCE OF ABSENCE. Its own absence is not a claim.
  unmeasured       timeout|noplace                        # shipped; whole-answer
  unmeasured_keys  {analyses_available timeout …}         # NEW, per key
```

**Three things about the bands a later crew must not tidy away.**

* **Band 3's polarity is "1 = sound", not "1 = has the bug".** Every reader in the tree is written
  as `== 1` meaning *good*; one key with inverted polarity is a defect waiting for a copy-paste.
* **Band 3 is named for the DEFECT, not for the fix.** `ase::cap_altshow_verdict`'s own header
  states the doctrine — *"does this ngspice have altshow?"* is answered YES by every release since
  ng-37, so it separates nothing. `one_vector_write` is not *"does it have `vec_is_all_wildcard`"*;
  it is *"does a one-save op plot come back clean"*. That survives somebody fixing it a different
  way, and it survives the fork being upstreamed.
* **Band 1 may be displayed and logged; it may never be compared** (**D44**). Stock 47 and the fork
  both answer `ngspice-46+`, so any ordering operator on `version_line` is wrong **today**.
  Conformance greps for it (Stage 15/16), and it is not a convention.

**THE THREE PREDICATES, AND THE RULE ABOUT WHICH IS WHICH.** This is the load-bearing addition of
the whole amendment, because the idiom it replaces is written out at ~12 capability sites today
(`ase::op_save_tier`'s five guards, `ase::cap_report`'s three, the casemode layer's) and every copy
is a chance to fuse *absent* with *0*.

```tcl
# WHAT IS KNOWN ABOUT ONE KEY -- the three states, as data, in one place.
#   {measured 0}               nobody asked, or the whole answer is `known 0`
#   {measured 0 why <token>}   nobody asked, AND the probe recorded which leg failed
#   {measured 1 value <v>}     somebody asked, and this is the answer -- 0 included
#
# ⚠ THE CALLER MAY NOT READ `value` WITHOUT READING `measured` FIRST, and that is
# why `value` is ABSENT rather than empty when nothing was measured: a `dict get`
# on it RAISES, which is a defect that shows up in a test row instead of a
# fabricated 0 that shows up in a user's Outputs pane six months later.
proc ase::caps_get {caps key} { … }

# THE GATE-UP PREDICATE -- for CAPABILITIES. Unmeasured answers 0, which is right
# for "may I offer this?" and WRONG for "must I work around that?".
proc ase::caps_is {caps key want} { … }

# THE MITIGATION PREDICATE -- true ONLY when `measured 1` AND the value matches.
# Unmeasured is FALSE, so a mitigation does not fire on a binary nobody measured
# (D47). ⚠ WITHOUT THIS PROC the natural spelling of a mitigation gate is
# `![ase::caps_is $c one_vector_write 1]`, which is TRUE for unmeasured and
# therefore inverts D47 for every future ngspice. A schema that needs a comment
# to stop the natural spelling from inverting a policy will lose.
proc ase::caps_measured_as {caps key want} { … }
```

> **THE RULE: capabilities use `caps_is`; mitigations use `caps_measured_as`; nobody calls
> `caps_get` outside those two.**

⚠ **CONVERTING THE EXISTING SITES IS PART OF THIS SUB-ITEM, NOT A HOPE.** Leaving the ~12
hand-written `[dict exists $c k] && [dict get $c k] == 1` guards in place while adding three procs
gives the tree a *fifteenth* idiom instead of removing fourteen, with two competing spellings in
one file. This item converts `ase::op_save_tier`, `ase::cap_report` and the casemode layer in the
same commit, and Stage 15/16 gains a conformance row: **no bare `dict get $caps <capability key>`
outside `ase::caps_get`, and no `ase::caps_is` appearing under a `!`.**

**`unmeasured_keys` is a DELIVERABLE of this stage, not a design note.** `ase::cap_run` already
returns its `cut` flag; a leg that is cut writes `unmeasured_keys {<key> timeout}` before returning,
so `ase::cap_report` can say *"the one thing I could not measure was X"* instead of going quiet.
Its first customer is `analyses_available` — a slow box that loses the last leg would otherwise
publish nothing and say nothing.

### 2g. THE VARIANT PROBE — one more leg, and the one that was refused

*Added 2026-09-10. `DECISIONS.md` **D49**, **D50**, **D52**; decks and measured answers in
`APPENDIX` §7.5.1.*

**One additional `-b` process, after decks A/B/C, inside the existing 30 s budget.** Every verdict
is read from a **file** (D7), never from an exit code.

```tcl
# ---- LEG D: THE VARIANT DECK.
#
# ⚠ IT MUST NOT BE MERGED INTO DECK A. Deck A's answer is the SHAPE of its raw
# file; this deck deliberately writes a raw whose shape answers a DIFFERENT
# question -- how a ONE-vector plot comes back. Merging them makes each
# unreadable, which is the contract the A/B split already carries.
#
# ⚠ EVERY REDIRECT TARGET IS A BARE LOWER-CASE NAME. ngspice case-folds the whole
# `>` target, directory component included, and splits it on whitespace (issue
# 1334). cap_run puts the workdir under us, so a bare name is both required
# (issue 0949) and fold-safe.
* ase variant probe D
v1 in 0 dc 1
r1 in mid 3k
r2 mid 0 1k
.control
set filetype=ascii
save v(mid)
op
write probe_d.raw          ;# -> one_vector_write
write probe_k.raw ALL      ;# -> keyword_case   (file exists? D49: one line, free)
echo "@@gnd=M7 my gnd rail" >> probe_d.txt      ;# -> gnd_literal (D49: one line, free)
echo "@@sourcepath=$sourcepath" >> probe_d.txt  ;# -> scripts_dir (Band 1)
version -v >> probe_d.txt / version -d >> probe_d.txt / version -f >> probe_d.txt
help osdi / help pss / help sp / help sndprint / help bltplot / help use  >> probe_d.txt
devhelp >> probe_d.txt
.endc
```

| key | verdict | apt 45.2 | stock 47 | fork |
|---|---|---|---|---|
| `one_vector_write` | `probe_d.raw`'s `Variables:` block holds **exactly** the saved vector | **0** (`v(mid)` + `v(all)`) | **0** | **1** |
| `keyword_case` | `probe_k.raw` **exists** | **0** (absent) | **0** (absent) | **1** |
| `gnd_literal` | the echoed line still contains `gnd` | **0** (`my 0 rail`) | **0** | **1** |

⚠ **`@@casemode=$curcasemode` may be collected as Band-1 `curcasemode_default` and NOTHING ELSE**
(**D52**). It reports the **current** mode, never the supported **set** — measured `none` / `none` /
`fold` — so populating `casemode_detected` from it would publish `{fold}` for the fork, narrow its
real `{fold preserve distinguish}` and **switch off the one feature the fork has**.
`sim_probe_leg`'s own shipped header names this exact inference as measured-false.
`casemode_detected` is owned by `sim_probe_capability`'s three delivery legs, and leg D may not
touch it.

⚠ **THE LEG THAT WAS REFUSED, and it stays written down** (**D50**). The `cp_remvar` abort is
cleanly probeable in `-b`: `op` / `set temp=27` / `unset temp` / `echo lifetime_ok > probe_e.txt`
gives rc **134** with the marker **absent** on apt 45.2 and stock 47, rc 0 with `lifetime_ok` on
the fork. It is refused because it **SIGABRTs the user's own `/usr/bin/ngspice` from inside a Run
gesture**, and apport is installed and enabled on the exact platform this amendment exists for
(§0.13.6). What it would buy is upgrading a warning to a refusal on two of three binaries, and a
warning is free. **The discipline it leaves behind, for any future leg that CAN abort:** both
outcomes must be **positive artifacts** (a marker before the aborting statement and one after, so
*"the leg never ran"* is distinguishable from *"the defect fired"*); `cut` is **corroboration,
never the guard**, because `ase::cap_run` sets it only when `ase::cap_timeout_cmd` found a
`timeout(1)` and on a box without one it never fires; and the aborting leg runs **last, in its own
process** — a file closed before an `abort()` survives it, buffered stdout does not.

**THE BUDGET, STATED HONESTLY.** The tree starts **six** processes today, not four: decks A, B, C
plus **three** casemode legs (`sim_probe_capability` loops `foreach m {fold preserve distinguish}`
and each is one `sim_probe_once`). Leg D makes **seven**. Measured cost: ~10 ms + ~65 ms for the
shipped six, and `/usr/bin/time` on leg D reports **0.00 s** on all three binaries — below the
tool's resolution. ⚠ **The ordering matters because of what a spent budget drops:** leg D runs
after A/B/C, so on a slow box **leg D is the first thing a 30 s budget kills**, and Band 3 then
stays unmeasured for the whole session — `ase::sim_caps` is written only on `known 1` and cleared
only by `ase::sim_caps_clear`. That is exactly why `unmeasured_keys` is a deliverable of 2f and why
§16a's fourth sentence frame exists.

⚠ **This does NOT add a probe run to every Run press.** The probe is cached on
`[list $resolved $eargs]` plus an mtime/size stamp; `ase::cap_report` is its only Run-path caller; a
warm press pays nothing and a cold press pays one more sub-10 ms process. (Note for whoever chases
issue 0953: the tree's *real* per-press launch is `ase::run_precheck`'s **uncached**
`ase::sim_probe_run`, made on every Run whenever the requested casemode is not `fold`. Neither this
leg nor §16b's pure-Tcl linter adds anything to it.)

### What you see, the moment the window reopens

1. **Twelve analyses instead of four**, in a wrapping grid, with `op dc ac tran` where they are today.
2. Types this build cannot run are **listed and disabled with the reason**: *"this ngspice was built
   without S-parameter support (`--enable-rfspice`)"* — beside a **Detect** button.
3. The dialog opens as fast as it does today, because it reads a cache and never starts a program.
4. **Picking a type the bench does not have yet and pressing OK adds it.** `ase::ui::chana_ok`
   already searches `analyses` for the selected type and, finding none, takes its
   `else { set row [dict create type $type] }` arm and `lappend rows $row` (hint `:4650-4657`). So
   the grid **is** the add gesture, and ⚖ R4 costs the user nothing in reach — only in what a
   brand-new bench looks like. A *second* row of one type still needs ⚖ R6.
5. **A simulator registered under *Setup > Simulators* whose backend has no adapter says so** — one
   sentence over an empty grid, instead of an empty grid (2d).
6. **Pressing Stop stops looking like it saved something.** The run log says at launch that a Stop
   discards the run, and the Stop itself says so again when it kills one (2e). Today both are
   silent.

### Files and procs

| file | proc | ± |
|---|---|---|
| `src/ase.tcl` | the capability deck (`ase::sim_capabilities_at`), its parser, `analyses_available` / `devices_available`; **new** `ase::analysis_offered {sim}` returning `{type state reason}` triples; the launch-time Stop sentence — `ase::run_log_header` for the log copy, `ase::echo` for the CIW note (2e). ⚠ Detect's second leg (2b) is **deferred with `-p`** — ⚖ R1 answered Option A | **≈ +155** |
| `src/ase_window.tcl` | `ase::ui::choose_analyses`' `.types` grid; the Detect button; the state colouring; the no-adapter status line over an empty grid (2d); the Stop sentence on the kill path of `ase::ui::do_stop` (2e) | **≈ +85 / −10** |

### Suites that move

* `test_ase_simcaps_0948.tcl` **gains rows** — its A/B/C sections are the pattern (stand-in simulators
  answering canned files, so no real ngspice is needed). Add: the per-verb parse; the first-token rule
  against a `help tf` stanza; the file-not-exit-code rule; the ungated-baseline fallback when
  `analyses_available` is absent; the OSDI `caution` rule.
* `test_ase_dialogs.tcl` **G1** asserts `dlg($key,antype)` preselects — unchanged.
* **`test_ase_core.tcl` R1 (`analyses are the four types in order`) must stay green** — which is
  ⚖ **R4**: today `state_default` would gain rows *by accident* the moment it reads the registry.
* A new row for **2d**, in the same stand-in idiom: a registered simulator whose backend declares no
  `analysis_types` hook produces an empty grid **and the sentence**, not an empty grid — with a
  non-vacuity control proving the sentence is absent when the hook is present.
* **`test_ase_core.tcl` RG13 moves, and it is a floor RAISED** (2e). Its first check asserts
  `rg_ciw {ase::ui::do_stop …}` is `{}` on the path that kills a live run; with the warning it
  asserts the sentence. Its sibling — *"with nothing running Stop still says there is nothing to
  stop"* — must stay **byte-identical**, because a Stop with nothing to stop discarded nothing and
  must not claim otherwise. Add a row for the launch-time sentence in `ase::run_log_header` with a
  non-vacuity control on both the log copy and the `ase::echo` note, and a row proving
  `ase::ui::strip_tips`' `stop` entry did **not** change
  (`test_ase_window.tcl` **W1s1**, W1s2 and W1s2b stay green, untouched — W1s1 is the one that pins
  the `!` tip to `[ase::ui::menu_path_stop]` and to its literal).

### Re-measure on the dev display

`tests/headless/devdisplay.sh start`, then

```sh
DISPLAY=:99 GUI_GATE=0 ./src/xschem --pipe -q --nolog \
  --script sky130A/cadence_style_rc --command "source <probe>.tcl"
```

Take: **the twelve grid cells and all four of their states** in one screenshot (an `ok`, a `caution`,
a `blocked` and an `absent`-with-Detect must all be visible at once, because the four-state grid is a
new visual language for this window); the wrap at four per row at the dialog's default width; and
**the dialog's open latency against a cold cache** — it must not start a probe, and the measured
worst case for a program that never answers is 31.2 s. File `owed.sh add look` for the grid.

### Rulings in this stage

**⚖ R4 — does `ase::state_default` gain any of the new types?** Recommendation **no**: all 104
committed `.state` files carry exactly four rows, `test_ase_core.tcl` R1 asserts it, and Cadence does
not add analyses to your bench either. Discoverability is served by the four-state grid, which shows
all twelve whether or not they are in the state file. **But today this would change by accident, so it
must be a decision.**

**⚖ R9** for **four** new user-facing sentences, batched with this stage: the `absent` reason string
(*"this ngspice was built without S-parameter support (`--enable-rfspice`)"*); 2d's no-adapter
sentence; and 2e's two Stop sentences — the launch-time *"Stopping this run discards it — ngspice in
batch mode writes nothing on a stop."* and the post-kill *"ase: simulation stopped — nothing of this
run was written."* All four are recommended shapes, not ratifications. ⚠ The two Stop sentences are
**⚖ R1's requirement arriving**, not this stage's idea; they are dated by design and Stage 6f
rewrites the first of them.

---

## Stage 3 — The form stops lying

**One commit. Rulings ⚖ R5, ⚖ R9.** This is the correctness defect the user will feel.

`ase::ui::chana_options` collects free-text name/value pairs, round-trips them through the state file,
renders them in the Arguments column, and **never emits them**. Its own comment says so. Measured end
to end: type `uic 1`, `tstart 5u`, `tmax 1n` into a tran row, see all three confirmed in the pane, and
the deck says `tran 10n 200u`.

**The acceptance criterion for this whole batch is one sentence:** *nothing the window shows may fail
to reach the deck, and nothing the deck contains may be unshowable in the window.*

The fix is not to make free text emit. It is to **delete free text**:

* every parameter a type genuinely has becomes a **typed field** in `fields`, most behind an
  `advanced` disclosure;
* every *option* becomes a catalogue row with a `cptype` and a `door` (Stage 7);
* anything else is **refused at OK** with *"ASE-L cannot emit an option named `<x>`"*;
* the one honest hatch is `x` — a **labelled** verbatim list of `.control` lines that **actually
  emits**, immediately before the analysis, rendered in the Arguments column as
  `verbatim: <n> line(s)`.

**The parameter-level source for this stage** is APPENDIX **§2.4** (`TRAN`, including the five-row
point-count table and the `tstart`/`tmax` positional rule), **§2.5** (`AC`, including the `lin 2`
defect and the parser's three silent repairs) and **§2.3** (`DC`, including the four sweep targets and
the two-nest-level ceiling). Cite those; the field tables below are their GUI shape, not a restatement.

### 3a. Real fields for the four shipped types

`tran` gains what nobody offers today:

```tcl
tran {
  fields {
    step   {kind time label {Time step} unit s required 1 gt 0
            help {⚠ NOT an output interval. Its only structural role is to become
                  the default tmax. For a uniform output grid use Output grid below.}}
    stop   {kind time label {Stop time} unit s required 1 gt 0}
    tstart {kind time label {Start recording at} unit s advanced 1 whenskipped 0
            help {the simulation still starts at 0; this is when data is KEPT}}
    tmax   {kind time label {Maximum time step} unit s advanced 1}
    uic    {kind bool label {Use initial conditions (skip the operating point)} advanced 1}
    grid   {kind mode label {Output grid} values {native interp linearize} default native
            advanced 1
            help {native = whatever the integrator chose. interp = `set interp` before
                  the run. linearize = `linearize` after it, into a new plot named
                  `<old> (linearized)`.}}
  }
  emit {tran @step @stop @tstart! @tmax! @uic?}
}
```

`ac` gets its sweep mode — **which is where the `dec` drift dies**:

```tcl
  sweep  {kind mode label {Sweep type} values {dec oct lin} default dec relabels points}
  points {kind int label {} required 1 min 1 default 10
          labels {dec {Points per decade} oct {Points per octave}
                  lin {Number of points (2 gives ONE point)}}}
```

`dc` gets the four sweep kinds ngspice actually accepts and the second nest level:

```tcl
  kind   {kind mode label {Sweep variable} default source values {source isource resistor temp}
          relabels target help {dctrcurv.c:89-151 accepts exactly these four}}
  …
  emit {dc @target @start @stop @step @target2? @start2! @stop2! @step2!}
```

`temp` as a sweep target is measured: `dc v1 0 1 0.5 temp -40 60 50` → 9 rows, one flattened `v-sweep`
scale, no `Dimensions:` header. So *"sweep the bias at three temperatures"* is **one command** whenever
the temperatures are uniformly stepped, and only a campaign when they are not. *"DC sweep variable:
[V source | I source | Resistor | Temperature]"* is the cheapest genuine ADE-beater in this document:
ADE-L makes you know which variables are sweepable.

### 3b. `relabels` is one line, because `dialog_row` already names the label

`ase::ui::dialog_row` names its label `$w.l$ename`, so the mode field's `-command` is:

```tcl
proc ase::ui::chana_mode_changed {key type field} {
  set w   [ase::ui::chana_form $key]                    ;# new; the .form frame
  set tgt [dict get [ase::analysis_field $sim $type $field] relabels]
  set lbl [dict get [ase::analysis_field $sim $type $tgt] labels \
             [ase::ui::form_get $key $field]]           ;# new; reads the .form widget
  $w.l$tgt configure -text "$lbl:"
}
```

Today the label is `[string totitle $f]:` with no unit and no hint. This is the ADE-L behaviour people
actually miss, and it is the fix for `lin` meaning *total* while `dec` means *per decade*.

### 3c. Refusals appear where the typing is — three tiers

1. **Live, per field.** A `-validate key` handler (the `ase::ui::listdlg_editor` idiom, with the
   `after idle` deferral the tree already measured) writes a sentence into `.status` and prefixes the
   label with `⚠ `.
2. **At Apply/OK.** `required`, `rules`, `needs`. Refuse, **keep the dialog up**, sentence in
   `.status`, and — new — **focus the offending widget**. There is no `focus` call anywhere in
   `ase::ui::choose_analyses` today.
3. **At render.** `fatal` preconditions, and the never-store rule. `render_deck` refuses, `run_deck`
   re-raises, the run never starts, no artifact is touched. This tier exists because a `.state` can be
   hand-edited and a netlist can change under a saved analysis.

Generalise `ase::ui::rsel_status` into **new** `ase::ui::dialog_status {w key msg}` at a reserved grid
row, and keep the `ase::echo` line for the action log and for headless assertions. Today OK "does
nothing" and the sentence lands in another window.

The first two cross-rules ship here, both measured:

```tcl
rules {
  {lin_two   {sweep eq lin && points eq 2}  refuse
     {a linear sweep of 2 points yields ONE point (acan.c:103-114); use 3 or more}}
  {step_sign {sgn(stop-start) ne sgn(step)} refuse
     {this sweep produces zero points and ngspice reports nothing at all}}
}
```

### 3d. Initial conditions — the surface `uic` needs, in the same stage

⚠ **A `uic` checkbox with no way to author, view or edit the initial conditions it consumes is a
control that changes the answer and reports nothing about what it is using.** That is the same defect
this stage exists to delete, re-created inside its own antidote. So `uic` ships **with** a small
Initial conditions sub-dialog (one `listdlg` config):

* **`.ic` rows** — `v(<node>) = <value>`, emitted as one `.ic` card above `.control`, node picker is
  `ase::ui::select_on_design`;
* **`.nodeset` rows** — same shape, emitted as `.nodeset`, with the hint that states the difference: a
  `.nodeset` is a *hint* used to find the OP and then released; an `.ic` is *held* during the OP when
  `uic` is off, and is the starting state when `uic` is on;
* **Save this solution / Start from a saved solution** — `wrnodev <file>` after a converged `op`, and a
  `.include <file>` row. This is the closest thing ngspice has to Cadence's save/restore DC solution,
  and ASE-L lacks it entirely.

### What you see, the moment the window reopens

1. **The tran form has six controls instead of two**, four behind `▸ Advanced`, each with a unit
   beside it, and the Time step field carries the hint that it is **not** an output interval.
2. **The AC sweep type is a control**, and picking `lin` **relabels its neighbour** to
   `Number of points (2 gives ONE point)`.
3. **`Options…` no longer accepts a word ASE-L cannot emit.** Typing one gets a sentence in the dialog,
   at the field, with the dialog still up and the cursor in the offending widget.
4. **A derived readout under the frequency fields:** `61 points`, computed with the same arithmetic
   `noisean.c:145-168` uses (6 decades × 10 + 1). Nothing in ADE-L tells you that.
5. **Switching the type no longer discards what you typed** (⚖ R5), and there is an **Apply** button.

### Files and procs

| file | proc | ± |
|---|---|---|
| `src/ase.tcl` | the four registry entries gain their full `fields`, `rules`, `emit`; **new** `ase::si_parse` (validate-only SI suffix reader) | **≈ +200** |
| `src/ase_window.tcl` | `ase::ui::chana_show` builds from `fields`; **new** `ase::ui::chana_form`, `ase::ui::form_get`, `ase::ui::chana_mode_changed`, `ase::ui::dialog_status`; `ase::ui::chana_ok` refuses instead of storing; `ase::ui::chana_options` becomes the typed surface; the Initial conditions sub-dialog; **Apply** | **≈ +420 / −90** |
| `doc/claude/specs/ase_l.md` | `### Choose Analyses dialog` **in full** — six lines today (hint `:1094-1099`), and that is why this area drifted; plus `### Menu tree (v2)`'s *"- **Analyses** — Choose… (Choose Analyses dialog)."* line (hint `:1053`) | **≈ +30 / −6** |

### Suites that move

* `test_ase_dialogs.tcl` **G2** — the Arguments display string gains the optional tokens.
* `test_ase_dialogs.tcl` **G2b** — the rejection path now writes to `.status` as well as `ase::echo`;
  the row's assertions (`dialog survives`, `state unchanged`) are unchanged and must stay green.
* `test_ase_dialogs.tcl` **GE5** (the `.chana.x` subdialog Escape row) — the subdialog is rebuilt; the
  row asserts existence and Escape, both of which survive.
* `test_ase_persist.tcl` — `arg_summary` rows follow the emitted line.
* `test_ase_core.tcl` **D1** — the golden deck **moves once, deliberately**, only if the fixture state
  sets one of the new optional fields. **Prefer to leave the D1 fixture alone** and add a **D1x** row
  for the new tokens, so the original byte-identity anchor survives untouched.
* **⚖ R5 reverses recorded decision D4**, whose reason (*"deterministic, no hidden multi-type writes"*)
  is satisfied by caching per-type edits for the **dialog's lifetime** and committing only the visible
  type at OK.

### Re-measure on the dev display

The launch line is Stage 2's. Take: **the form's widget census** for each of the four types (six
controls on `tran`, four behind `▸ Advanced`); **the relabel on a `lin` pick** — the neighbour must
read `Number of points (2 gives ONE point)` — and on `dec`; **the derived point-count readout** under
the frequency fields (`61 points` for `dec 10 1k 1meg`); and **focus landing on the offending widget**
at OK, which is new behaviour with no `focus` call anywhere in `ase::ui::choose_analyses` today.
File `owed.sh add look` — the form triples in size and gains a disclosure.

### Rulings in this stage

**⚖ R5** (reverse D4 — keep what you typed across a type switch; recommendation: reverse) and **⚖ R9**,
the standing label ratification: every field label, unit string, hint and refusal sentence in this
stage is new user-facing copy. **Batch them per stage** — twelve analyses otherwise means twelve rounds
of asking, which is exactly what the standing preference forbids. Stage 0's one minted sentence rides
in with this batch.

---

## Stage 4 — The netlist permits

**One commit. Ruling ⚖ R9.** Preconditions become filters, not error messages.

**The parameter-level source for this stage** is APPENDIX **§2.6** (NOISE's `E_NOACINPUT` and the
`DEVnoise` device list), **§2.9** (DISTO's `distof1`/`distof2` preconditions), **§2.10** (SENS's
eligibility rule) and **§7** for every precondition that exists because something crashes.

### 4a. `ase::netlist_facts` — a second pure-Tcl pass

```tcl
# ase.tcl -- a SECOND pass over the text ase::netlist_map already walks, keeping
# the k=v parameter tokens netlist_map deliberately DROPS. That is the only way
# to answer "does this source carry an ac value", "a distof1", "a portnum", "a
# trnoise". Reuses netlist_map's continuation folding and .subckt scope stack.
#  -> {sources  {<inst> {scope <s> letter v|i ac <mag> dc <v> portnum <n> z0 <r>
#                        distof1 <a> distof2 <a> stimulus 0|1
#                        trnoise <args> trrandom <args>}}
#      families {resistor 1 vsource 1 mos1 1 …}
#      events   {<node> …}          ;# from `a` lines + .model d_* / *_bridge
#      models   {<name> {type numd|nbjt|numos|bsim4|… level <n>}}
#      nodes    <from netlist_map>
#      exact    0|1}
proc ase::netlist_facts {netlist_text} { … }
```

**Static by default, exact on request.** Static (`netlist_facts`, free) **warns**; an exact leg (a
parse-only `show v : acmag` probe, one run per netlist, verdict from a file) **blocks**. A false
refusal is worse than a missed one, and the stand-down precedent for `.include`-bearing scopes is
already ruled inside `ase::netlist_map_resolve`.

### 4b. The `needs` vocabulary

| id | predicate | verdict | evidence |
|---|---|---|---|
| `ac_source` | ≥1 independent source with a non-zero AC magnitude | `caution` static / `blocked` exact | `evidence/an-smallsig.md` |
| `input_source_ac` | NOISE's named source exists, is V or I, has `acGiven` | `blocked` | `noisean.c:110-142`, `E_NOACINPUT` |
| `output_node_resolves` | every node named **on a form field** resolves | `blocked` | `ase::netlist_map_resolve` |
| `two_ports` | ≥2 ports **after ASE-L's own `alter portnum` lines** | **fatal** | `span.c:376-386` `controlled_exit` |
| `contiguous_ports` | portnums are 1..N, unique | `blocked` | span.c port promotion |
| `distof_source` | ≥1 source carrying `distof1` (and `distof2` when `f2overf1` is set) | `caution` | `evidence/an-smallsig.md` §6.4 |
| `saves_resolve` | **every** save/output/analysis-field name resolves | **fatal when `disto` is enabled** | §0.9 |
| `disto_devices` / `noise_devices` | ≥1 family with `DEVdisto` / `DEVnoise` | `caution` ("will return zeros") | `evidence/cider-devices.md` §2.6 |
| `pz_devices` | no family lacking `DEVpzLoad`; **no transmission line** | `blocked` | `pzan.c:92-128` |
| `sens_params` | ≥1 eligible perturbable parameter | `caution` | `evidence/00-critique.md` §5.6 |
| `sweep_target` | DC's target is a V, an I, a **resistor**, or the literal **`temp`** | `blocked` | `dctrcurv.c:89-151` |
| `no_event_nodes` | the deck has no XSPICE event node | `caution` for `dc`; **blocked** for `.probe alli` | `evidence/xspice.md` §5.5, §12.1 |
| `cider_klu` | no CIDER device while `.options klu` is set | **fatal** | `evidence/builds.md` §2.3 — `exit(1)`, and the rest of `.control` never runs |

⚠ **Most of `saves_resolve` already ships.** `ase::preflight_scan` calls `ase::netlist_map_resolve` per
output identifier and `ase::preflight_gate` already refuses. What is genuinely new is (a) the same
check applied to identifiers typed on **analysis form fields**, which `preflight_scan` does not see;
(b) the `k=v` facts `netlist_map` discards; and (c) the DISTO cross-rule, which **must not be
defeasible by `set ase_preflight 0`** — that escape exists today and it would re-open a SIGSEGV.

### 4c. The device × analysis matrix, computed for the user's deck

The binary's families (`devhelp`, from Stage 2's probe run) × the deck's families × the hook matrix.
The distinction that matters: a missing **contribution** hook (`DEVnoise`, `DEVdisto`) is usually
*correct* → `caution`; a missing **matrix stamp** (`DEVacLoad`, `DEVpzLoad`) is always wrong →
`blocked`. And per Stage 2's OSDI rule, an **unknown** family is `caution`, never `blocked`.

### 4d. The DISTO rule, at its true width

Enabled `disto` promotes `saves_resolve` to **fatal**, checked in the dialog **and** re-checked in
`render_deck`, **and not defeasible**. When the netlist cannot answer — an `.include`-bearing scope
where `netlist_map_resolve` stands down — **widen to a `.save all` card and say so in the run log**. A
wide save is a big file; a segfault is a lost run; and `.save all` alongside the narrow save is
measured safe (§0.9, row 2).

And the second option × analysis refusal, which is only expressible because options are typed objects
rather than free text:

```tcl
  {klu_sens_ac {opt klu && mode eq ac} refuse
     {ngspice SEGFAULTS on AC sensitivity under the KLU solver (cktsens.c's guard
      is commented out); use `sparse`, or switch this sensitivity to DC}}
```

### What you see, the moment the window reopens

1. **A banner under the form** saying what will be wrong before you run: *"`v1` has no AC value — a
   noise analysis needs an AC input source (`ac 1` on the source, any magnitude)"* — the exact remedy
   for `E_NOACINPUT`, offered **before** the run instead of after it.
2. **A `caution` that names names:** *"3 of 14 device families contribute no noise: `e1`, `g2`
   (behavioural sources are noiseless), `t1` (transmission line)"*. That is a silent-zeros trap turned
   into a fact the user knows before misreading a plot.
3. **A `blocked` type carries its fix**, not just its reason.

### Files and procs

| file | proc | ± |
|---|---|---|
| `src/ase.tcl` | **new** `ase::netlist_facts`, `ase::analysis_needs {sim row facts}`, `ase::analysis_precheck`; `ase::preflight_gate` gains the non-defeasible DISTO clause; `render_deck` re-checks `fatal`. **All core, deliberately** (§1's naming rule): `netlist_facts` reads the SPICE netlist **xschem itself emits**, and the two `analysis_*` procs evaluate the schema's `needs` vocabulary. The DISTO rule's *reason* is ngspice's and travels as the adapter's `fatal` entry; the evaluator is ASE-L's | **≈ +330** |
| `src/ase_window.tcl` | the `.note` precondition banner; the grid's `caution`/`blocked` states read `analysis_precheck` | **≈ +60** |

### Suites that move

* **New rows in `test_ase_preflight.tcl`** (`PF2xx`-shaped; its existing fixtures already build
  three-scope netlists): `netlist_facts` keeps `k=v`; an `ac 1` source is found through a subckt scope;
  `saves_resolve` fatal-under-disto; **`set ase_preflight 0` does not defeat it**; the `sweep_target`
  four-way; `cider_klu`.
* `ase::netlist_map_resolve` gains its **second kind of customer** — form fields, not just outputs. No
  existing row moves.
* Sabotage: no-op `analysis_needs`' `fatal` arm and confirm the DISTO row goes red.

### Re-measure on the dev display

**None — this stage is headless by construction.** `ase::netlist_facts` and the `needs` predicates
are pure functions over netlist text; everything they produce reaches the user through widgets Stage
2 and Stage 3 already put on screen (the four-state grid's `blocked` cell and its reason, and
`ase::ui::dialog_status`). Assert the *sentences* in the headless suite; there is no new pixel.
**No look debt is filed.**

### Rulings in this stage

**⚖ R9** only — every precondition sentence is new user-facing copy. Batch with Stage 3's.

---

# CAPABILITY

## Stage 5 — The single-plot analyses: `tf`, `pz`, `sens` (DC)

**One commit. Ruling ⚖ R9.** Three new types at **zero writer risk**, because each writes exactly one
plot and emission stays byte-identical in shape.

```tcl
tf   { label {Transfer function} verb tf gated 0 emitorder 50 viewrank 0 registered 1
       fields {outkind outnode outref outsrc insrc}
       emit   {tf {build ase::backend::ngspice::an_tf_out} @insrc}
       plots  {{match {Transfer Function} role scalars results value label {Transfer function}
                vectors {Transfer_function v1#Input_impedance output_impedance_at_V(b)}}} }
```

⚠ **All three of TF's vector spellings are measured and none is what any design wrote.** `tf v(b) v1`
then `display` reports **`Transfer_function`** (capital T), **`v1#Input_impedance`** and
**`output_impedance_at_V(b)`** (capital V). A Value-column probe keyed on `Input_impedance`, or on
`transfer_function`, finds nothing. APPENDIX §2.7.

```tcl
pz   { … emit {pz {build ase::backend::ngspice::an_pz_nodes} @transfer @mode}
       plots {{match {Pole-Zero Analysis} role table results resulttable label {Poles and zeros}}
              {match {Distortion Operating Point} role opinfo results viewer
               when {opt keepopinfo} label {Pole-zero — operating point}}} }
```

⚠ `pz`'s operating-point plot really is labelled **`Distortion Operating Point`** — upstream
copy-paste at `pzan.c:58`. Carry the measured literal; do not "fix" it in the registry.

```tcl
sens { … emit {sens {build ase::backend::ngspice::an_sens_out} @filters? @modeargs}
       plots {{match {Sensitivity Analysis} role table results resulttable label {Sensitivity}}}
       rules {{sens_ac_lin {mode eq ac && sweep eq lin} refuse
                {ngspice's sensitivity AC sweep MULTIPLIES by the step instead of adding
                 it (cktsens.c:828-837 tests the wrong LINEAR constant), so `lin 5 1k 5k`
                 sweeps to 4.096e14 Hz; use dec or oct}}
              {klu_sens_ac {opt klu && mode eq ac} refuse
                {ngspice SEGFAULTS on AC sensitivity under the KLU solver; use `sparse`,
                 or switch this sensitivity to DC}}} }
```

⚠ **`@modeargs` is a free slot and `lin` lives inside it, so the refusal has to be a `rule`, not a
field constraint.** Measured this session: `sens v(mid) r*:r ac lin 5 1k 5k` swept **1.000000e+03,
8.000000e+05, 6.400000e+08, 5.120000e+11, 4.096000e+14** — each × 800. `inc_freq()` is
`if (type != LINEAR) freq *= step_size; else freq += step_size;` and its `LINEAR` is
`noisedef.h:74`'s `#define LINEAR 3`, **not** `SENS_LINEAR` (`sensdefs.h:87`), so the test is always
true and there is no linear arm at all. Trap **T13**; APPENDIX §2.10 and §7.2 **S2**. **Do not offer
`lin` for SENS AC.** (Stage 3's `rules` fence only `ac`; this is the same defect in a type Stage 3
does not know about, which is why it ships here.)

**The parameter-level source for this stage** is APPENDIX **§2.7** (`TF`, and the three measured
vector spellings), **§2.8** (`PZ`, including the mislabelled OP plot and the `DEVpzLoad` requirement)
and **§2.10** (`SENS`, both modes).

### 5a. The `.sens` parameter picker, computed offline

A three-device deck yields ~90 sensitivity vectors, which is unusable as a dump.
`devhelp -csv -type -flags <device>` prints exactly the four facts `cktsgen.c:193-216`'s eligibility
rule needs, so the picker is computable **with no run**:

> eligible = `Dir == inout` **and** `Type == real` **and** flags contain neither `X` (IF_NONSENSE) nor
> `R` (IF_REDUNDANT) — and, in DC mode, neither `A` nor `AA`.

The selection compiles to `.sens`'s glob filter: `sens v(out) r*:r m*:vth0 ac dec 10 1k 1meg`. A
checkbox tree instead of a 90-row dump. ⚠ **ADE-L does expose `sens` as a type** —
`evidence/ase-ui.md` §6 row 1 lists it among `tran dc ac noise xf sens dcmatch stb pz sp envlp pss
pac`. What it does not give you is a **computed eligibility picker**: the 90-row dump is the whole
surface. `devhelp -csv -type -flags` makes the picker computable with no run, and **that** is the
gain.

### 5b. Three destinations, and the read-only result table

PZ (complex, no scale), SENS-dc (real, one point, ~90 vectors) and — from Stage 6 — noise
contributors, the S-matrix, Fourier harmonics and campaign runs are **all one thing**: a sortable
scalar grid with a copy action. `ase::ui::listdlg_open` is config-driven, but it is an **editor** whose
rows come from session state and it has **no sorting**. A read-only, sortable **new
`ase::ui::resulttable`** sharing its column policy and theming is the honest estimate. Six bespoke
panes would be six half-finished panes.

⚠ Build it on the **derived font policy** issue 1398 landed (`AseEntryFont` data, `AseBodyFont`
chrome, `AseLabelFont` headings-only-and-bold, `AseMonoFont` machine text; `font configure` never
`font actual`; column widths from `font measure` with a `-minwidth` of the heading's own ink), not on
pixel constants. Re-read `doc/claude/ase_l_ux_batch/DECISIONS.md` at implementation time; it moved
while this was being written.

### What you see, the moment the window reopens

1. Three more analyses are `ok` in the grid and have real forms.
2. **A Transfer Function run puts three numbers in the Value column** — gain, input impedance, output
   impedance — where today it has nowhere to put them at all.
3. **Poles and zeros arrive as a sortable table** (Re, Im, f, Q) with an s-plane scatter beside it.
4. **Sensitivity arrives sorted by |value| with a normalised column**, from a picker you chose, not a
   90-row dump.

### Files and procs

| file | proc | ± |
|---|---|---|
| the ngspice adapter (in `src/ase.tcl` — §1a) | three registry entries; **new** `ase::backend::ngspice::an_tf_out` / `an_pz_nodes` / `an_sens_out` — §1c's three `{build <proc>}` escapes — and `…::sens_eligible`. **All four spell ngspice syntax or enumerate ngspice facts, so all four are content** | **≈ +260** |
| `src/ase_window.tcl` | **new** `ase::ui::resulttable`; the `.sens` picker | **≈ +230** |

### Suites that move

* **New deck goldens only** — three, one per type, in `test_ase_core.tcl`'s D section beside D1. No
  existing golden moves: each type is one plot, so the write block is exactly today's.
* `test_ase_window.tcl` — new rows for `resulttable`'s column policy and sort. **Do not** touch W1p's
  assertions about the three v2 panes.

### Re-measure on the dev display

The launch line is Stage 2's. Take: **`ase::ui::resulttable`'s column widths**, computed from
`font measure` against `AseLabelFont`'s own heading ink and never from pixel constants (issue 1398's
derived font policy — `AseEntryFont` data, `AseBodyFont` chrome, `AseLabelFont` headings-only-and-bold,
`AseMonoFont` machine text, `font configure` never `font actual`); the s-plane scatter beside the PZ
table; and the `.sens` picker's checkbox tree against the 90-row dump it replaces. Re-read
`doc/claude/ase_l_ux_batch/DECISIONS.md` first — it moved while this was being written.
File `owed.sh add look` — this is the first `resulttable` in the tree.

### Rulings in this stage

**⚖ R9** — three type labels, ~15 field labels, the eligibility hint. Batch.

---

## Stage 6 — The writer, and the multi-plot analyses

**One commit, and the only one where every deck golden moves. Rulings ⚖ R3, ⚖ R9.**

Five measured ways *"one analysis, one plot"* is wrong: `noise` writes 2 (or 1 at a single frequency);
`disto` writes 2 harmonic or **3** IM; `keepopinfo` prepends an OP plot to `ac`, `noise`, `pz`, `tf`,
`disto` and `sp`; `pz`'s OP plot is mislabelled; `pss` writes 2 × (1 + relaunches). Today ASE-L
captures **one** and loses the rest without saying so.

### 6a. The `setplot previous` walk

```
<THE ANALYSIS LINE>
if $?sim_status = 0 … end / if $sim_status ne 0 … quit 1 … end
remzerovec
echo "PLOT <type> <id> |$curplotname|" >> <cell>_ase.plotmap
write <raw> [all <device names>]                    ; device names: op ONLY
  ... repeated (nplots-1) times: ------------------
  setplot previous
  remzerovec
  echo "PLOT <type> <id> |$curplotname|" >> <cell>_ase.plotmap
  write <raw>
```

Four properties, each measured:

* **A single-plot analysis emits exactly what it emits today** — `remzerovec` then `write <raw>` — so
  Stages 1–5's decks stay byte-identical and only the sidecar line is new.
* **The sidecar is creation-ordered and 1:1** with the rawfile's `Plotname:` records. It is the
  **identity**; the literal is only the **label**. That is the only thing that separates two
  `Sensitivity Analysis` plots (§0.7) or two rows of one type.
* **`<cell>_ase.plotmap` is deleted before every run**, exactly as the rawfile is, because `>>`
  appends.
* **A bare `write` is enough** (§0.6). The walk does not need `all`.

⚠ **Do NOT use `foreach p $plots / setplot $p / write raw all` instead.** It writes `constants`
**first** — `Title: Constant values`, `Plotname: constants`, `No. Variables: 12`, `No. Points: 1`,
`Date` == the build stamp — all four markers `ase::raw_content_verdict` treats as decisive. It answers
`ok 0` and `ase::attach_dbs` echoes `NOT ATTACHED … the analysis did not run`. `destroy const` is
refused outright (`Error: can't destroy the constant plot`); `.control` cannot filter on a string
(T10); and the plot names cannot be built as a string inside the deck (T11). **The walk is the only
shape left.**

### 6b. `nplots` is a predicate

```tcl
plots {
  {match {Noise Spectral Density Curves*} role spectrum results viewer
   label {Noise — spectral density}}
  {match {Integrated Noise*} role scalars results value
   when {expr {start ne stop}} label {Noise — integrated}
   vectors {onoise_total inoise_total}}
  {match {NOISE Operating Point} role opinfo results viewer
   when {opt keepopinfo} label {Noise — operating point}}
}
```

`ase::analysis_plots {sim row opts}` evaluates the `when` predicates to a count and a match list. The
`Integrated Noise` plot **exists only when `start != stop`** (`noisean.c:511`) — a single-frequency
noise run produces none, and the form warns about it before you run.

### 6c. Post-run reconciliation — the safety net

After every run, before attaching: compare the rawfile's `Plotname:` list against the union of the
enabled rows' predictions, using the header parser `ase::cap_raw_plots` already has.

* **prediction == reality** → attach, label from the sidecar.
* **over-count** (a duplicate, or a trailing `constants`) → attach, drop the duplicate, and log *"this
  run captured N plots where the registry expected M; the extra ones were ignored."* An over-walk
  **degrades and does not destroy**: plot 1 is still genuine data, so the file still attaches.
* **under-count** → attach what is there and log *"one plot of the `<type>` analysis was not
  captured"*, naming the type. This is the case that used to be silent.

### 6d. `noise`, `disto`, `sens` (AC), and the routing table

The three multi-plot types land here, with the literals from §0.7 in their registry entries. NOISE's
entry is the one that argues for the whole registry, because of one field:

```tcl
  contributors {kind bool label {Per-device contributor table} default 0
          help {every device's own noise vectors, inside the spectrum plot}}
  ptssum {kind int label {Report every N points} default 1 min 1 advanced 1
          depends {contributors 1}
          help {ngspice couples the contributor table to spectrum DECIMATION.
                1 = the table AND the full spectrum. 4 over 21 points leaves 6 rows.}}
```

The raw parameter is a decimation factor whose *side effect* is the contributor table. **Nobody should
have to know that**, so the checkbox is named for the thing the user wants and the raw parameter hides
behind `depends`.

⚠ **The noise contributor table has three naming hazards**, and a table that sums without all three
gets the wrong answer: two conventions coexist (`onoise_total_<inst>_<mech>` with underscores for most
devices, `onoise.<inst>.<mech>` with dots for the BSIM3/4/SOI/HiSIM family); the **empty-suffix** entry
is the device *total*, so a naive sum **double-counts**; and OSDI emits `onoise_total_<inst>` **with a
trailing space**.

⚠ **`AC Operating Point` reads back as `op`.** xschem's `read_dataset` matches
`strstr(lowerline, "operating point")` **before** the AC arm (`src/save.c`), so a `keepopinfo` OP plot
from an AC, NOISE, PZ, TF, DISTO or SP run attaches with `sim_type = op` and collides with the real
operating point. Registry `role opinfo` plots are therefore **not** handed to `xschem raw read` with
`op`; they are read for their vectors and labelled from the sidecar.

The routing table, per plot, is **`APPENDIX_ngspice_analyses.md` §6.2** — cite it, do not restate it.
(It was lifted there from `evidence/design-of-record.md` §9.1 in this pass, gaining the `destination`
and `label shown` columns, because D30 makes the routing **normative** — a registry entry without a
destination is a load-time error — and a normative table cannot live only in an evidence file. The
dossier remains the second-level anchor.) The rule it encodes: **every plot names a destination, and
"the waveform viewer" is not an answer for six of the twelve.**

### 6e. Scalars from the rawfile — ⚖ R3

Today the Value column is filled by `result_probe` parsing `<expr> = <number>` out of `print` output,
anchored on `op` because a multi-point `print` emits a 20,514-row table that yields nothing (issue
1243). Every scalar an analysis produces is a **one-point plot in the rawfile**: `Operating Point`,
`Integrated Noise`, `Transfer Function`, dc `Sensitivity Analysis`. Reading them from the raw removes
`result_probe`'s case-folding ladder and gives NOISE, TF and SENS a scalar home the current rule
denies them.

**The cost, and it is why this is a ruling.** Arbitrary user-typed *expressions* (`v(a)*2`) are the
only thing that column holds today, and they are **not** vectors in the raw.

### 6f. Checkpointed salvage — a Stop keeps what the run had

**This is ⚖ R1's always-salvage requirement, and it lands here because Stage 6 owns the write
block.** The mechanism is extra lines around one analysis inside `render_deck`'s per-analysis loop,
and it has to interact with the three things that loop already does — `set appendwrite`, the
`$sim_status` guard and `remzerovec` — so it cannot be written anywhere else without writing that
loop twice. Stage 6 is also the one stage allowed to move every deck golden, once, deliberately,
which is exactly what a change to the emitted `.control` block costs. **No new top-level stage
number for 6f**: **0–15 is frozen** and `LEDGER.md` mirrors it. (⚠ **Stage 16 exists as of
2026-09-10** — added by the variant amendment as a new *terminal* stage, and it does not renumber
or move anything in 0–15.)

**The deck shape, the traps and the numbers are in the *Salvaging a stopped run* block of §0.1
*Measured facts*** — the recipe, SV1–SV15 and the disqualified list. Cite it; this section is only what
ASE-L decides on top of it.

⚠ **This is a generated `.control` loop, and *What this plan refuses* refuses one.** That refusal is
about **campaigns** — one process running N points, where an interrupted run is indistinguishable
from a finished one and the GUI is handed nothing to tell them apart. This loop is the opposite case:
it exists so that an interrupt is survivable, and it ships the completion echo that makes
finished-versus-aborted decidable for the first time (SV7). The two are not the same decision, and the
refuse-list entry stays as it is.

**Where the checkpoint goes.** `<rundir>/<cell>_ase.raw.ckpt`, written through
`<cell>_ase.raw.ckpt.tmp` + `shell mv -f`, and **deleted before every run** exactly as the rawfile
and the plotmap are (6a). Never the results file: `set appendwrite` turns an overwrite into a stack
of plots and would break readback by plot name (SV5). The checkpoint write is bracketed by
`unset appendwrite` / `set appendwrite`, and it **emits no `PLOT` line** — the plotmap is 1:1 and in
creation order with the *results* file (6a), and a checkpoint that wrote into it would put that
identity out by one.

**Which analyses are checkpointed, and this stage ships one.**

| type | this stage | why |
|---|---|---|
| `tran` | **yes** | the one shape measured end to end, through a SIGTERM, in ASE-L's own deck (§0.12) |
| `dc`, `ac` | **not yet** | both stop and resume correctly, but the full loop was never run against either, and `dc`'s sweep-variable plot may meet the `unset appendwrite` bracket differently (`evidence/salvage.md` §7.5). One measurement each and they land |
| `op` | **never** | one point |
| `noise`, `disto` | **never** | a stop leaves an **incomplete plot set**, not a short plot — `noise1` without `noise2` — so a salvaged one would be a wrong answer wearing a partial one's label (the SV block's disqualified list; `evidence/salvage.md` §3.4) |
| `pss`, `sp`, `pz`, `sens`, `tf` | **never, until measured** | unmeasured, and `evidence/builds.md` already records `sens` not honouring `bg_halt` and `pz` probably being uninterruptible |

**The interval rule, and it is in POINTS.**

* The primitive is **`stop after <points>`**. Never `stop when time` — it hands the integrator a
  breakpoint, forces a timepoint, and changes both the grid and the byte count (SV1, SV2).
* **N = 4 by default**, a checkpoint every 20 % of the run, clamped `[2, 50]`. Where the previous run
  of this bench gives a runtime `T` and a rawfile size `S`, **N + 1 = sqrt(T × B / S)** with
  B ≈ 400–500 MB/s (SV14) — a planning constant, not a bound; it moved ±30 % between sittings — which for a ten-minute, 200 MB job raises N to ~34 and *lowers* the cost to
  1.4 %, because checkpoint cost tracks the rawfile while the value of a checkpoint tracks the
  runtime.
* **An eligibility floor, read from the deck alone**: the estimated point count `tstop/tstep + 8`
  (SV15). Below the floor there is nothing a user would press Stop over, and no checkpoint block is
  emitted at all — which is what keeps the small rendered-deck goldens free of one. They move at this
  stage for 6a's `PLOT` line; **they must not move twice.** ⚠ **The floor is a number the crew picks
  and states in the code**, and the dossier does not supply one; the anchor it does supply is that
  the 800,008-point / 25.6 MB / 0.82 s reference deck is *already* worth three checkpoints by S14's
  formula, so the floor sits below that, not above it. ⚠ And the estimate itself does **not** hold
  for a deck with `pulse`/`pwl` breakpoints, `.options interp` or a max-step setting; there the loop
  re-arms from `length(time)` read at the first checkpoint.
* **Thresholds reach `stop after` through a `set` variable, never `$&`** — `$&` formats `1200000` as
  `1.2E+06`, `com_stop()` parses digits only, and the result is *"Syntax error parsing breakpoint
  specification"*, nothing armed, and a run that finishes unchecked at rc 0 (SV12). The `set` route
  rounds to **6 significant figures**, so a threshold above a million is approximate — harmless, and
  the crew should know it.
* **The counters are created before the first analysis**, in the `const` plot (SV11).
* **`delete all` before the next analysis and before the final `resume`** (SV6). ASE-L renders
  op/dc/ac/tran in one block, and a stop armed once truncates everything after it, at rc 0.

**What the run costs, and the GUI has to say it.** Extra bytes are **N/2 × the final rawfile size**,
linear in bytes (SV13). On the reference deck, three sittings on one machine: **+8 to +21 %** of wall
time at N = 4, **+60 to +75 %** at N = 20. Plus **≈ 4 ms per checkpoint** for the rename (SV10). The
model is the durable part; the constants moved ±30 % between sittings, so the GUI computes from
`N/2 × S / B` with a *measured-on-this-machine* B rather than quoting a percentage from this page.
The user is trading exactly that against the 20 % of a run a Stop can still cost them, so **both
numbers appear together or neither does**.

**After a Stop, what the user gets.** The results file holds the analyses that completed, intact.
`<cell>_ase.raw.ckpt` holds the interrupted one — one plot, loadable. Both attach, and the
interrupted one is labelled **partial, with how far it got**: `maximum(time)` against the `tstop` that
was asked for. **The verdict comes from the missing completion echo, never from the exit status** —
`$sim_status` is 0 after a stop, `dosim()` — which `ft_dorun()` calls — maps *"simulation
interrupted"* to `err = 0` deliberately, and a deck that reaches its end exits 0 (SV7). 6c's reconciliation must be told the run
was aborted **before** it reports an under-count, or every stopped run logs *"one plot of the `tran`
analysis was not captured"* as though something were wrong.

**The escape hatch is the existing idiom.** `set ase_checkpoint 0` defeats the whole block, the way
`set ase_preflight 0` defeats `ase::preflight_gate`. It exists for the crew comparing a deck against
a golden and for a user who wants the emitted block to be exactly what it was, and it is a hidden
variable, not a preference. **No new state key**: ⚖ R8 named `sweep` as the single exception to *no
new top-level keys*, and a per-bench interval would be a second one. A persisted interval is
deferred and named here so it is not smuggled in.

**Four things NOT adopted, each written down so it is not re-proposed.**

1. **`-r` as a progress or fallback rawfile.** On a `.control` deck it is a destructor: `main.c`'s
   batch arm calls `ft_dorun(ft_rawfile)` unconditionally, and `dosim()` beneath it opens the path
   `"wb"` and `unlink()`s it when nothing was written. A good rawfile at that path was **gone at exit, rc 0**
   (§0.1).
2. **SIGTERM-then-SIGKILL in `ase::ui::do_stop`.** `evidence/salvage.md` §4.2 recommends it; read
   against *this* tree it buys nothing measurable. `kill_running_cmds` is
   `exec kill $sig [pid $execute(pipe,$id)]` — the pipeline's own pids, not a process group — so the
   `shell mv` grandchild is not signalled either way, and ngspice does nothing with SIGTERM (it dies
   at the default disposition, in the same few milliseconds as SIGKILL). **The tmp + rename is the whole of
   the protection**, 6/6 measured, and it must not be sold as anything else.
3. **A checkpoint written into the results file.** Four stacked plots and 64,001,536 bytes where one
   plot is 25,600,541 (SV5).
4. **Inferring completeness from `rc` or `$sim_status`.** Both are 0 for a stopped run (SV7).

**And two limits that stay open**, because a user will meet them and the plan should not pretend
otherwise: the byte-identity of `stop after` (SV1) was measured on an **RC**, not on a
transistor-level deck whose stepping is LTE-limited; and there is **no `fsync` anywhere** in
`rawfile.c` or `outitf.c`, so a *machine* crash — as opposed to a kill — can still lose a checkpoint
that `write` reported as finished (SV13).

**The warning changes shape here (2e).** The launch-time sentence stops being *"Stopping this run
discards it"* for a checkpointed analysis and becomes what it actually costs — *"Stopping loses at
most the last 20 % of this run; checkpointing costs about 18 % more run time"* — with both numbers
computed from N and the estimated rawfile size. It stays the un-checkpointed sentence for every row
in the disqualified table above, which is most of them, which is why 2e ships first and stays.

### What you see, the moment the window reopens

1. **A noise run produces two results instead of one:** a spectrum in the viewer *and* `onoise_total` /
   `inoise_total` in the Value column, labelled *"Noise — integrated"*.
2. **A distortion run produces two or three named trace groups** — *Distortion — 2nd harmonic*,
   *Distortion — 3rd harmonic*, or the three IM plots — instead of one unlabelled one.
3. **Every result carries the name of the analysis that produced it**, including two sensitivity
   analyses in one run, which today are indistinguishable.
4. **When a plot goes missing, the run log says which type lost it.** Today it says nothing.
5. **Stopping a long transient no longer throws it away.** The analyses that finished are in the
   results file; the one that was running is beside it, labelled *partial*, with how far it got —
   *"stopped at 48.0 ms of 80 ms"* — and the run is marked aborted from the missing completion echo,
   not from an exit status that says 0 either way (6f).

### Files and procs

| file | proc | ± |
|---|---|---|
| `src/ase.tcl` | `render_deck`'s write block becomes the walk — **inside `ase::backend::ngspice`, where `render_deck` already lives**, because `setplot previous` is an ngspice command; **new core** `ase::plotmap_path`, `ase::plotmap_read`, `ase::reconcile_plots` — the sidecar is **ASE-L's own artefact**, written by ASE-L and read by ASE-L, so it is schema; `ase::attach_dbs` takes the sidecar; `result_probe` gains the raw reader (⚖ R3); **three registry entries, which are content** | **≈ +360 / −25** |
| `src/ase.tcl` | **6f:** the checkpoint block inside `render_deck`'s per-analysis loop — **the adapter's**, because `stop after`, `resume`, `delete all` and `shell mv` are ngspice words; **new core** `ase::ckpt_path` (ASE-L's own artefact, like the plotmap, so it is schema), `ase::ckpt_plan {row opts}` returning the thresholds and N, and `ase::run_completed` reading the completion echo out of the log. The `.ckpt` and `.ckpt.tmp` join the pre-run delete beside the rawfile and the plotmap | **≈ +200** |
| `src/ase_window.tcl` | result labels from the registry; the contributor table into `resulttable`; **6f:** the partial-result label with how far it got, and 2e's launch sentence gaining its checkpointed form | **≈ +160** |

### Suites that move

* **EVERY deck golden moves, once, deliberately** — the `echo "PLOT …" >> …plotmap` line joins every
  write. `test_ase_core.tcl` **D1** and its siblings, `test_ase_cosim.tcl`'s **RD1–RD11** rendered
  decks, and any golden in `test_ase_optier_0963.tcl`'s E section that compares whole write lines.
  (`E5` in `test_ase_cosim.tcl` is a **plan-item label in a comment**, not a check name — the checks
  there are `RD1`…`RD11` with sub-labels `RD2b`, `RD2c`, `RD3b`, `RD3c`, `RD11b`. The `E5` that *is*
  real is `test_ase_optier_0963.tcl:616`, below.)
  Re-baseline in **one commit**, with this stage named in the message.
* **Rows E5 and M1 of `test_ase_optier_0963.tcl` must be re-proven green.** They will be: the walk
  leaves the `op` write line exactly as it is, and the device names on that line are what *create* the
  vectors. Also re-run **R2** (the 74.9 MB row), **R4**, **R6**, **E17**.
* `test_ase_preflight.tcl` — a row that the plotmap is deleted before the run.
* New rows for the reconciliation's three arms, driven by hand-written rawfile headers (the
  `test_ase_simcaps_0948` canned-file idiom), so no simulator is needed.
* **6f's rendering rows, all against the deck text, no simulator:** a `tran` under the eligibility
  floor emits **no** checkpoint block — the row that keeps every small golden moving only for 6a's
  `PLOT` line, so it needs its non-vacuity control beside it (one above the floor that *does* emit
  the block); the emitted block uses `stop after` and
  **never** `stop when`; the counters are emitted **before** the first analysis; every threshold
  reaches `stop after` through a `set` variable and never `$&`; `unset appendwrite` brackets the
  checkpoint write; the checkpoint path is not the results path; the checkpoint write emits no
  `PLOT` line; `delete all` precedes the next analysis and the final `resume`; `op`, `noise` and
  `disto` rows emit no block at all; `set ase_checkpoint 0` emits none for anything.
* **`test_ase_preflight.tcl`** — the `.ckpt` and `.ckpt.tmp` are deleted before the run, the row the
  plotmap already has.
* **A completeness row**: a log with the echo reads complete, a log without it reads aborted, and
  **rc 0 with `SIM-STATUS-IS 0` in both** — the row exists to pin that the verdict does not come from
  either.
* **`test_ase_simreg_0931`'s six argv rows do NOT move.** 6f touches the deck, never the command
  line; if A2, B5, B6, B11, B12 or D4 goes red, something emitted a flag.

### 6g. The variant mitigations that move a deck golden or a reader

*Added 2026-09-10 (§0.13, `DECISIONS.md` **D46**, **D47**). They land here because Stage 6 is the
one stage allowed to move every deck golden, once, deliberately — and two of the four do.*

| # | what | class (D46) | gate |
|---|---|---|---|
| **6g-1** | **Never emit a narrowed `save` in the same run as an analysis whose result vectors are not netlist names** — `disto`, `noise`, `tf`, dc `sens` (T15, T2; `APPENDIX` §7.5.2) | **M-artifact, applied UNCONDITIONALLY** | none, and the ground is named: it is a **correctness precondition**, not a workaround. Without it the analysis does not run at all, on **every** binary |
| **6g-2** | **Filter a phantom raw column literally named `all` that duplicates another column of the same plot** (T17) | **M-free** | **none — unconditional** |
| **6g-3** | **Force `render_deck`'s `.save all` leader when the op plot would otherwise hold exactly one save** (T17, the emission-side fix) | **M-artifact** | `ase::caps_measured_as $caps one_vector_write 0` |
| **6g-4** | **A lint over the emitter**: no rendered deck golden may contain a capitalised ngspice keyword | **M-free** | none — it is an assertion about goldens, not about a binary |

**6g-1 is the one to get right, and its shape is a refusal to narrow rather than a rewrite.** ASE-L
emits `.save` cards from the Outputs pane; a *stale* entry (the normal case after a net rename) is
enough to starve the analysis. The rule is stated as a property of the analysis, not as a list of
four verbs, and the four verbs are the adapter's content: `ase::backend::ngspice::` enumerates
them, ASE-L enforces *"an analysis so marked runs with the save list left alone"*. ⚠ **Add one test
row per analysis type asserting the run survives a stale Outputs entry** — that is the case the
user will actually hit.

**6g-2 and 6g-3 are the two halves of T17, and the free half is the floor.** ⚠ **The free half does
NOT live in `ase::raw_content_verdict`** — an earlier draft of this amendment put it there, and it
cannot host it: that proc is a **read-only diagnosis** over a 64 KB head/tail slice, it returns
`{ok constants appended plotname nvars npoints signature why}` with **no variable list**, and it
deliberately never reads the `Values:` block it would need in order to prove a column duplicates
another. Two things are true instead, and both were checked in the tree:

* **ASE-L is already immune at the op-parameter seam.** `ase::op_param_split` demands an
  `@dev[param]` shape, so `ase::op_vector_for` and `ase::op_param_set` discard `v(all)` for free.
* **The filter belongs at the two seams that actually show a vector list to a user** — the
  `xschem raw list` consumer behind the Outputs/trace surface, and `ase::cap_raw_plots`, which is
  the one Tcl proc in the tree that returns a vector list.

⚠ **And the filter is on the literal name `all` only.** An earlier draft also filtered `allv` and
`alli`; those are **ASE-L's own Save-All tokens**, not ngspice vector names, and filtering on them
would eat real columns.

**6g-3 is gated because it is not free.** `render_deck`'s own comment records what the `.save all`
leader costs: it restores the implicit save-everything that any explicit `save` cancels — measured
*"13 vectors, 6 device params, 5 node `v()`"* with it against *"7 vectors, 6 device params, **zero**
node `v()`"* without. Changing every user's results file to work around a defect only some of them
have is not free, which is why it uses `caps_measured_as` (D48) and not `!caps_is`. **Ship both
halves**: the free one is the floor on every binary including ones nobody measured; the gated one
fixes the **file**, so xschem's own browser and any third-party viewer see the truth.

### Re-measure on the dev display

The launch line is Stage 2's. Take: the **result labels** in the Value column and the viewer, one
per plot, on a `noise` run (`Noise — spectral density`, `Noise — integrated`) and on a `disto` IM
run (three named trace groups); and the **contributor table** inside `resulttable`. No new pane is
built here — the table is Stage 5's — so **no new look debt is filed**; take the shots for the
receipt, because this is the stage where a user first sees an analysis name attached to a result.

### Rulings in this stage

**⚖ R3 — ANSWERED 2026-09-12, Option C.** Where the Value column's numbers come from. The
recommendation was **both**, with the rule stated on screen: *a row whose expression names exactly one
vector reads the raw; anything else reads the log* — and the user ruled for it in those terms: *"both
with a rule is right, keep it"*. Issue 1243 was the user's own ruling and this extends it rather than
reversing it.

**⚖ R9** — 6f's user-facing sentences, batched: the checkpointed form of 2e's launch warning
(*"Stopping loses at most the last N % of this run; checkpointing costs about M % more run time"*),
the partial-result label (*"partial — stopped at 48.0 ms of 80 ms"*), and the aborted-run verdict
line. ⚠ **6f itself needs no ruling** — always-salvage is already the user's requirement, given with
⚖ R1's answer. What R9 ratifies is only the wording.

---

## Stage 7 — The options surface

**One commit, or two. Rulings ⚖ R2 — ANSWERED, yes with four conditions — and ⚖ R9.** Both
catalogues become reachable and safe, and T3/T4/T5 become type errors.

**The parameter-level source for this stage** is APPENDIX **§3.1** (catalogue A, the 98 `OPTtbl`
rows and the count arithmetic), **§3.1.1** (the two paths that reach the options, and which keywords
each accepts), **§3.2** (catalogue B, the 163 `cp_getvar` variables), **§3.2.1** (the 26 pre-deck
ones, with their `CP_` classes) and **§3.3**/**§3.4** (the inert list and the four silent-failure
traps). §8.1 is the verification channel 7f uses.

### 7a. One catalogue, five load-bearing columns

**220 rows measured floor** (§0.4): 57 settable `OPTtbl` keywords + 163 `cp_getvar` variables, the two
sets provably disjoint. Generated once from `evidence/options.md` and `evidence/hidden-vars.md`,
hand-maintained thereafter.

**The catalogue is the ngspice adapter's CONTENT, and this is where `DECISIONS.md` D33's amendment
said the question would be settled.** Every row of it — the `CP_` classes, `OPTtbl`'s
`IF_FLAG`/`IF_INTEGER`/`IF_REAL` split, `itl4`'s clamp, `gminsteps`' default, `nosavecurrents`'
tombstone — is an ngspice fact, and by **D34** none of them may sit in ASE-L's own source. So it is
declared **in `ase::backend::ngspice`, through the hook**, exactly like the analysis registry (§1a).
**ASE-L owns the row SHAPE** — `cptype`, `door`, `phase`, `scope`, `inert` — the one speller (**D23**)
and the rule that an inert option is never a live field (**D24**), and nothing else here. A simulator
with no `CP_` classes at all supplies rows whose `cptype` vocabulary is its own; the emitter does not
care.

```tcl
# ── inside `namespace eval ase::backend::ngspice`, reached only through the
#    hook -- core never names this variable ─────────────────────────────────
variable sim_options {
  reltol    {cat task cptype optreal door options scope global group tolerances
             default 1e-3 gt 0 results 1
             help {relative error tolerance of the Newton loop}}
  gminsteps {cat task cptype optint  door options scope global group convergence
             default 1 min 0 results 1
             help {number of gmin-stepping steps; 0 disables gmin stepping}}
             ;# ⚠ THE DEFAULT IS 1, NOT 10. cktntask.c:120-122 is
             ;#   TSKnumSrcSteps = 1; TSKnumGminSteps = 1; TSKgminFactor = 10;
             ;# The 10 in that block is `gminfactor`. Getting this wrong makes
             ;# the shipped value read as "changed" in 7c's default view, which
             ;# is exactly how a real change gets hidden.
  keepopinfo {cat task cptype optflag door options|control
             scope {analysis ac noise pz tf disto sp} group output default 0 plots 1
             help {keep the operating point ngspice computes before a small-signal
                   analysis, as an extra plot}}
  klu       {cat task cptype optflag door options scope global group solver default 0
             help {KLU direct solver} conflicts {sens_ac cider}}
  itl4      {cat task cptype optint door options scope {analysis tran} group iteration
             default 100 min 100
             clamp {niiter.c:37-39 raises every iteration limit below 100 to 100, so
                    the shipped default of 10 is already 100}}
  sqrnoise  {cat var  cptype bool   door options|control scope {analysis noise sp}
             group output default 0 plots 1 results 1
             help {report noise as V^2/Hz instead of V/sqrt(Hz); RENAMES both plots}}
  units     {cat var  cptype string door control scope global group output
             default radians values {radians degrees} results 1
             help {angle unit for vp()/ph(). ⚠ RADIANS BY DEFAULT -- a phase margin
                   computed without this is wrong by 57.2958x}}
  casemode  {cat var  cptype string door predeck scope global phase L1
             values {fold preserve distinguish} owner casemode_batch
             help {node-name case policy; MUST reach ngspice before the deck is read}}
  wnflag    {cat var  cptype num    door predeck-file scope global phase L1
             help {MOS W is total (0) or per finger (1)}}
  norefprint {cat var cptype bool   door control scope global group diagnostics
             help {kills the ` Reference value ` progress ticker -- ASE-L must NOT
                   emit this while a progress bar is on screen}}
  oldlimit  {cat task cptype optflag door options scope global
             inert {TSKfixLimit is never copied by CKTnewTask (cktntask.c:68), so this
                    option is silently dropped on the .control route ASE-L uses}}
  ramptime  {inert {the live code is inside #ifdef XSPICE_EXP, which is defined
                    nowhere in this tree. It is an XSPICE code-model knob plus one
                    breakpoint, NOT a supply ramp}}
  nosavecurrents {inert {documented by the manual §13.7; the string appears NOWHERE in
                    this source tree. Tombstone -- do not re-add it}}
  …
}
```

**`door` is computed, never typed:**

| `door` | emitted as | when |
|---|---|---|
| `options` | `.options name` / `.options name=v` above `.control` | `OPTtbl` keywords; `cp_getvar` vars read at or after `inp.c:1376` |
| `control` | `set name` / `set name=v` inside `.control` | same set, when the value must not survive into a sibling deck |
| `predeck` | `-D name` or `-D name=<string>` | `phase L1/L2` **and** `cptype ∈ {bool, string}` |
| `predeck-file` | a `set` line in `<rundir>/.spiceinit` | `phase L1/L2` **and** `cptype ∈ {num, real, list}` |
| `cmdline` | a real argv flag (`--soa-log=…`) | the handful that are flags |

### 7b. One speller, where the traps become type errors

```tcl
proc ase::opt_line {sim name value} {
  set d [ase::sim_option_entry $sim $name]   ;# the hook, never $::ase::sim_options
  if {[dict exists $d inert]} {
    return -code error "ase: option '$name' does nothing in this build:\
 [dict get $d inert]"
  }
  switch -- [dict get $d cptype] {
    bool    { if {$value in {1 true yes on}} { return "set $name" }
              return {} }          ;# absence IS off. `set x=1` is ALSO off. Never `=`.
    num - real { if {$value eq {}} { return {} }
                 return "set $name=$value" }   ;# a bare `set` here is silently inert
    string  { return "set $name=$value" }
    list    { return "set $name = ( [join $value { }] )" }
    optflag { if {$value in {1 true yes on}} { return ".options $name" }
              return {} }          ;# IF_FLAG: a value is meaningless
    optint - optreal - optstring {
              if {$value eq {}} { return {} }
              return ".options $name=$value" }
              ;# ⚠ THE SPLIT: gminsteps/srcsteps/itl4/maxord are IF_INTEGER and
              ;# trtol/temp are IF_REAL. A single `opt` arm that returns a BARE
              ;# `.options gminsteps` for a user who typed 0 is this batch's own
              ;# defect inside its own antidote: the dialog shows 0, the deck
              ;# contains nothing, and gmin stepping runs at 1 (cktntask.c:120-122).
    default { return -code error "ase: option '$name' has no cptype" }
  }
}
```

T3, T4 and T5 die in that `switch`. The fourth trap — `-D name=value` is *always* a `CP_STRING` — dies
in the `door` computation, which never routes a `num`/`real`/`list` to `-D`.

### 7c. Finding one option among 220

1. **Search first** — one entry filtering name, group and help text, live
   (`ase::ui::combo_filter`'s prefix-match idiom generalises).
2. **"Changed only" is the DEFAULT view**, with `[Show all]`. A bench normally differs from default in
   0–5 places. It is a *filter*, not a feature, because the catalogue carries `default`.
3. **Groups, not an alphabet** — the eleven categories in `evidence/hidden-vars.md` §7.
4. **Two scopes on two surfaces** — global options in `Simulation > Options…` (which exists, has a
   state key and an emitter); per-analysis options behind the analysis form's `Options…`, filtered by
   `scope {analysis <type>}`. An option shown in the wrong scope is worse than one not shown.
5. **A ⚠ badge on every `results 1` row** — the 21 options that change numbers.
6. **A LIVE DECK PREVIEW PANE** showing the exact lines that will be emitted **and where**:
   `.options gmin=1e-10` above `.control`, `set sqrnoise` inside it, `-D casemode=preserve` on the
   command line, `set wnflag=1` into `<rundir>/.spiceinit`. *A setting with no line in the preview is
   visibly not in force.* This is what structurally prevents the free-text defect from returning;
   extend it to the whole deck, not only options.

### 7d. The pre-deck class, and the inert list

26 variables are unreachable from `.options` **and** from `.control` (T8). They get their own group,
labelled **"Applied before the netlist is read"**, and each row says which door it will use. This is
not a nicety: `.options casemode=preserve` and `.options nosubckt` are silently ignored, and a GUI that
offers them beside `reltol` teaches the user something false.

Delivery is `<rundir>/.spiceinit` (⚖ R2, **answered yes** on 2026-09-10 — its four conditions are
requirements, not advice) plus `-D` for the bool/string subset. **ASE-L reads the
user's `$HOME/.spiceinit` (or `$SPICE_USERINIT_DIR`'s) and COPIES its lines under a banner** —
`source <user file>` makes ngspice parse the target as a **netlist** (`Circuit: set frobnicate`,
`Unable to find definition of model`) and the user's variables are lost. The file is deleted and
rewritten per run, refused when ASE-L finds one it did not write, and the run log says once that it
exists and what it shadows.

**Two refusals, both free because the answer already exists:** `ase::sim_nospiceinit` is already
consulted by `run_cmd`, so **every pre-deck option and the entire campaign mechanism are refused when
`-n` is in force** — measured, the same deck gives 4700 with the file honoured and 1e-12 with `-n`, and
the only message is about a resistor. And `ase::rundir` falls back to `set_netlist_dir 0`, a directory
shared by every cell and by xschem's own netlister, so the pre-deck class **requires an explicit
per-session rundir** and the refusal must name that.

**The inert list, three shapes:** *not offered at all* — `ramptime`, `klu_memgrow_factor`,
`nosavecurrents`, `scalm`, `itl3`, `itl5`, `x11lineararcs`, `debug`, `newtrunc`; *offered with a clamp
and the reason* — `itl1`/`itl2`/`itl4`, widget minimum **100**, tip *"ngspice raises any iteration
limit below 100 (`niiter.c:37-39`), so the shipped defaults 50 and 10 are already 100"*; *kept as a
tombstone, or offered only with the defect named beside it* — `oldlimit`, which works from a dot card
and is dropped on the `.control` route we use, so it is not offered and the row keeps the reason so
the next reader does not re-add it from the manual; and **`defas`**, which is live and **wrong**:

> **`.options defas=<v>` sets the DRAIN area, not the source area.** `cktsopt.c:111-113`'s
> `OPT_DEFAS` arm is `task->TSKdefaultMosAD = val->rValue;` — the same field the `OPT_DEFAD` arm
> three lines above writes. **Offer it only with that sentence beside it, or not at all.** A user who
> sets `defas` today changes `defad` and nothing says so. Trap **T14**; APPENDIX §3.3 files it
> upstream as §7.2 **S3**.

### 7e. Per-analysis scope is a GUI fiction, and the GUI says so

ngspice has **no** per-analysis option scope: `option keepopinfo` inside `.control` stays set for every
later analysis. The GUI emits the option immediately before its analysis and **restores it immediately
after** from the catalogue's `default` column — measured to work for the flag class (`option
keepopinfo` then `ac` → `$plots` gains `op1 ac1`; `option keepopinfo=0` then `ac` → gains only `ac2`).
Two honest limits, both stated on the form: an option with **no known default** is labelled *global*
and offered only on the global surface; and if the live value differs from the catalogue default, the
restore writes the default and thus changes a global — which 7f reports.

### 7f. Post-run verification — requested vs effective

At the end of every deck, before `.endc`:

```
option   > <cell>_ase.effective
set     >> <cell>_ase.effective
```

`option` prints the effective task settings and reflects what actually took (`reltol (current) = 0.05`,
`itl4 (transient iterations) = 7`, `Integration Method = GEAR`). `set` lists every variable in force,
**including ones ngspice silently invented from an unknown `.options` name**. ASE-L diffs requested
against effective and surfaces *"you asked for X, the simulator is using Y"*. This is the only way to
catch T3's and T5's silent drops, it is the cheapest staleness check on a shipped catalogue against an
unfamiliar binary, and it **proves a pre-deck delivery landed**. ⚠ Caveat: neither channel reveals a
`CP_` class, so the type table still ships.

⚠ **There is NO error channel for a misspelled option on ASE-L's route — measured, both routes.** A
deck carrying `.options bogusdot=1` plus `option bogusopt=3` inside `.control` printed **no message at
all**, and the trailing bare `set` listed `+ bogusdot 1` and `bogusopt 3` — both invented as
variables. A dot-card deck with `.options frobnicate` + `.op` ran completely clean. The
`Error: unknown option %s - ignored` branch exists (`inpdoopt.c:74-78`) and **neither route reaches
it**. So this verification leg is **mandatory, not a nicety**: it is the only way the GUI learns that
a name did not land. APPENDIX §3.1 carries the probes.

`<cell>_ase.effective` is deleted before every run, like the rawfile and the plotmap.

### 7g. A `rules` clause may read `caps` — and four of them do

*Added 2026-09-10 (§0.13, `DECISIONS.md` **D46**). `rules` is already Stage 7's key (§1a, §1d); the
only change is that its evaluator is handed the capability dict.*

| rule | class (D46) | gate | what the user gets |
|---|---|---|---|
| never `option klu` on a run carrying an AC `sens` (T7, **X2**) | **M-free** | **none — unconditional**, and the option is simply not emitted for that run | one line saying KLU was left off for this run and why |
| never a narrowed `save` beside `disto` / `noise` / `tf` / dc `sens` (T15, T2) | M-artifact as a **correctness precondition** | **none — unconditional** (6g-1) | one line, and the analysis runs |
| `ac lin 2` / `sp lin 2` (T6, **S1**) | **M-refusal if refused; a form-level WARNING if not** | none | ⚠ **warn and name the fix** — *"a linear sweep of 2 points yields 1 point; use 3"* — rather than refusing. Refusing removes a number the user typed into a form, which is D47's losing cell; the warning costs nothing and is right on every binary |
| `No. Points:` above 99,999,999 (**D4**) | M-refusal | none | the cheap structural proof is a *source* fact true of all three binaries, so refuse-or-warn at the form, unconditionally |
| a `gated 1` option row whose `requires` says `absent` | capability | `ase::caps_is` (§1a) | the row is listed and disabled with the reason and the door, never hidden (D6) |

⚠ **These are RULES, not a hazard registry.** *"Never emit `option klu` with an AC `sens`"* is a
line in `render_deck` and a row here; a `hazard_table` proc would be a table with no key
(**D43**) pretending to be data. The mitigations get no registry of their own, deliberately.

### What you see, the moment the window reopens

1. **A search box and a "Changed only" list of five rows** where the manual has 220.
2. **A deck preview pane** that shows exactly where each setting will be written — and shows nothing at
   all for a setting that is not in force.
3. **A ⚠ badge on every option that changes a number**, and a plain-English clamp note on the three
   iteration limits.
4. **A group called "Applied before the netlist is read"**, which is the first time those 26 variables
   have been reachable from any GUI.
5. **After a run: a line saying what the simulator actually used**, when it differs from what you asked
   for.

### Files and procs

| file | proc | ± |
|---|---|---|
| `src/ase.tcl` — the SCHEMA half | **new** `ase::opt_line` (the one speller, D23), `ase::opt_door`, `ase::opt_restore_line`, `ase::effective_diff`, `ase::sim_option_entry` (the hook reader) | **≈ +180** |
| the ngspice adapter (`ase::backend::ngspice`, in `ase.tcl` today — §1a) | the 220-row catalogue **as content**; `render_deck`'s option block; `run_cmd`'s `-D` arm; **new** `spiceinit_write` and `effective_read` | **≈ +720** (the catalogue is most of it) |
| `src/ase_window.tcl` | the options surface: search, changed-only, groups, badge, deck preview; the pre-deck group; the effective-diff report | **≈ +430 / −120** |

### Suites that move

* **`test_ase_simreg_0931.tcl` A2 / B5 / B6 / B11 / B12 / D4** move **the first time `-D` is emitted
  for an option** — all six pin `<exe> -b [args] [-n] [-D casemode=…] <deck> 2>@1` byte for byte
  (§0.1), D4 through `[lindex $D4SAID 0]`. **L11** pins the exe alone and does not move. Re-baseline
  **all six in one commit** or five of them go red. ⚠ **⚖ R2 was answered YES, so the pre-deck class
  ships and this move is now expected rather than conditional** — the old escape ("if the pre-deck
  class emits no `-D`, none of them moves") is gone. Budget for the re-baseline.
* New suite for `ase::opt_line`: one row per `cptype` arm, one per `door`, one per inert shape, and a
  **non-vacuity row** proving a wrong arm produces a *different* line rather than none.
* New rows in `test_ase_preflight.tcl` for the `-n` refusal and the shared-rundir refusal.
* `test_ase_core.tcl` D-section: a golden with an option of each door.

### Re-measure on the dev display

The launch line is Stage 2's. Take: **the live deck preview pane diffed against the rendered deck**
— every line the pane shows must appear in `<cell>_ase.spice` (or in `<rundir>/.spiceinit`, or on the
argv), byte for byte and in the same slot, and a setting not in force must show **nothing**; the
"Changed only" default view against `[Show all]`; the ⚠ badge on the 21 `results 1` rows; and the
"Applied before the netlist is read" group. File `owed.sh add look` — this is the largest new pane
in the plan.

### Rulings in this stage

**⚖ R2 — ANSWERED 2026-09-10: yes, with those four conditions.** ASE-L writes
`<rundir>/.spiceinit` and copies the user's own file into it, provided the file is deleted and
rewritten per run; the user's lines are **copied** under a banner, never `source`d; the run log says
once what it shadows; and the whole mechanism is **refused** under the shared `set_netlist_dir 0`
rundir fallback and under `-n`. The conditions are requirements — a crew that ships three of four
has shipped a defect. This stage no longer waits on a ruling for its pre-deck class.
**⚖ R9** for the option group names, the badge sentence and the effective-diff sentence.

---

## Stage 8 — Measurements and post-processing

**One or two commits. Ruling ⚖ R9.** *"Read a number back"* — the task the evidence base says all three
competing designs lost.

`grep -c '\bmeas\b' src/ase.tcl` returns **0**. Two of the six benchmark ADE tasks — *read back the
phase margin* and *the spread of one measurement over 200 Monte Carlo runs* — currently end at "you are
on your own". That is the bar this plan opened by condemning.

**The parameter-level source for this stage** is APPENDIX **§6.7** (post-processing that produces
results, not just pictures — `.four`, `fft`, `spec`, `psd`, `linearize`, and `meas`'s grammar traps).

### 8a. A `measurements` list beside `outputs`

One row per measurement, an open dict, same discipline as an analysis row, edited in a Measurements
sub-dialog and emitted as `meas` **commands** inside `.control`, immediately after the analysis they
read:

```tcl
{name pm   analysis ac   id a1 kind param expr {180 + vp(out)[i_at_ugf]} unit deg}
{name f3db analysis ac   id a1 kind when  target {vdb(out)} value -3.0103 dir fall}
{name gain analysis ac   id a1 kind max   target {vdb(out)}}
{name tr   analysis tran id t1 kind trigtarg
 trig {v(out)} trigval 0.1 trigdir rise  targ {v(out)} targval 0.9 targdir rise}
{name irms analysis tran id t1 kind rms   target {i(vdd)} from 1u to 10u}
```

emitting:

```
meas ac   f3db when vdb(out)=-3.0103 fall=1
meas ac   gain max vdb(out)
meas tran tr   trig v(out) val=0.1 rise=1 targ v(out) val=0.9 rise=1
meas tran irms rms i(vdd) from=1u to=10u
```

The `kind` vocabulary is `evidence/measure.md`'s: `trigtarg` (delay), `find`/`when`,
`avg`/`rms`/`min`/`max`/`pp`/`integ`, `deriv`, `param`. Each kind is one form shape; expression fields
accept `par('…')`.

**Four grammar traps the form must encode**, all measured: `expr=` is broken (refused); `param=` is
one-shot per session (refused when the same circuit is re-run in one process — which the shard runner
never does); **`.meas` dot cards are refused under `-r`**, so this is a command, not a card; and the
created vector carries only **7 significant digits** (`"%e"` at `measure.c:138`), so when full
precision matters the GUI redirects `meas … > file` and parses the printed line.

⚠ **And the one nobody caught: `set units=degrees` is mandatory.** `vp()` returns **radians** (§0.9:
`-6.28310e-03` against `-3.59995e-01`, a factor of 57.2958). The Measurements dialog emits
`set units=degrees` automatically the moment any row's expression mentions `vp`, `ph`, `cph` or
`phase`, says so in the preview, and the Y-axis label says `deg`.

### 8b. Eight derived answers, as named templates

⚠ **WHAT TASK 2 INHERITS — written down 2026-09-13, when task 1 and two dialog commits landed,
so the next crew starts from measurements instead of rediscovering them.**

1. **Task 1 built no widget, and its copy is already ratified-in-waiting.** The eighteen kind
   labels, twenty-eight field labels, three picker values, twelve core refusals, six adapter
   refusals, the caution and five report frames are all in `R9_COPY_REVIEW.md` as
   **R9-294 … R9-372**. **Consume those words; do not mint a second set.** Most of them are
   *declared and read by nothing* today — nothing reads a kind's `label`, and
   `ase::meas_report` **has no caller in the tree** — so task 2 is the first code that shows
   any of them.
2. ⚠ **`R9-325` is the word `reaches`, and it carries a LAYOUT CONSTRAINT.** It is the only
   lowercase label in the tree and reads correctly only if the form puts `When signal` and
   `reaches` on **one line**. A right-aligned label column turns it into a stray lowercase word.
3. **The form remembers now, and OK writes what it remembered.** ⚖ R5 (issue 1445) gave the
   dialog a per-type cache cleared on open and close; issue 1446 made `chana_ok` read
   `ase::ui::chana_commit_vals` — the type's cache filtered to its declared fields, with the
   live form merged over it. **The Measurements sub-dialog inherits both**, which is why R5 was
   sequenced before this task. It is still a **single-type write**, and `GR6e` is the row that
   holds that line.
4. ⚠ **Two test traps, both measured, both cheap to repeat.** `GR5k` — the byte-identity row —
   presses OK on **`op`, which has no fields**, so it cannot see a `form_is_absent` bypass; a row
   copied from it inherits the blind spot, which is exactly what happened to 1446's first cut.
   And **reading `dlg(…,anen)` after OK raises**, because `chana_cancel` unsets it — that kills
   the suite file instead of reddening a row.
5. **One residual is pinned, not fixed**: the precondition banner's `chana_merged_row` reads
   **live widgets only**, so it judges the stored value where OK now writes the remembered one.
   Row `GR6h` pins it. If task 2's Measurements form has any `needs` rule that reads a field
   behind `▸ Advanced`, this becomes visible and the fix is one line.
6. **The Value column is binary-dependent by design.** `$val` is the simulator's printed text
   verbatim: apt 45.2 prints seven significant digits and ignores `measureprec`, the fork
   honours it. **Do not normalise it and do not golden it by digit count** —
   `evidence/binary-differences.md` #2 and #5.

The user picks one and fills two fields. This is what *"better than ADE-L"* means for the daily task.

| template | emits |
|---|---|
| DC gain | `meas ac gain max vdb(out)` |
| −3 dB bandwidth | `meas ac f3db when vdb(out)=<gain-3.0103> fall=1` |
| Unity-gain frequency | `meas ac ugf when vdb(out)=0 fall=1` |
| **Phase margin** | `set units=degrees` + `meas ac ugf when vdb(out)=0 fall=1` + `meas ac pm find vp(out) when vdb(out)=0` + `let pm = 180 + pm` |
| Gain margin | `meas ac gm find vdb(out) when vp(out)=-180` |
| Slew rate | `meas tran sr trig v(out) val=<10%> rise=1 targ v(out) val=<90%> rise=1` |
| Settling time | `meas tran ts when v(out)=<final±tol> cross=last` |
| THD | `.four <f0> v(out)` card + `thd1` read from the result table |

### 8c. Producers, not only destinations

`.four`, `fft`, `spec`, `psd` and `linearize` currently have destinations in every design and **no
producers anywhere**. Here they get both:

* **`.four` is a CARD** in the slot above `.control`. Its `fourierMN` 2-D vectors and `thdMN` scalar
  already exist and are today only printed as text.
* **`fft`/`spec`/`psd` are COMMANDS** after the transient. Measured literals: `Spectrum`, `Spectrum`,
  `PSD` — ⚠ **not** `spectrum`, and the typename is `spN`, not `spectN`, because `ft_plotabbrev()`
  returns the first substring match and `sp` shadows `spect`.
* **`linearize`** writes `<old> (linearized)`.

All four are captured by Stage 6's walk and named by the same sidecar. **The card/command split is a
rule:** `.four` and `.probe` are cards; `.meas` is a command. Nothing analysis-shaped ever goes in the
card slot.

⚠ **BOTH STRUCTURAL CLAIMS ABOVE WERE REFUTED BY MEASUREMENT WHEN STAGE 8 TASK 1 SHIPPED
(2026-09-13, issue 1443), AND THE SHIPPED CODE FOLLOWS THE MEASUREMENT, NOT THIS PARAGRAPH.**

1. **`.four` as a CARD runs the simulation TWICE.** Driver-verified on **both** binaries by
   counting `Doing analysis` lines in otherwise identical decks: **2** with the card, **1**
   without. Paying for a harmonic table with a second full transient is not a trade this plan
   ever costed. So the **`.four` card slot ships EMPTY** and `fourier` is emitted as a
   **command** instead. The card/command "rule" survives for `.probe`; for `.four` it was
   wrong.
2. **A producer's plot is read back as the analysis it MIMICS, not as a producer.** Measured:
   `xschem raw read … tran` on a results file carrying a producer's plot answers
   `datasets=2`, and `… ac` answers `sim_type=ac` on a deck that contains **no** `ac`
   analysis. The sidecar therefore cannot infer what wrote a plot from what the reader calls
   it, which is why the producer records its own name rather than trusting the file.

**Both corrections came from running the thing rather than from reading ngspice's source**,
and both are the kind that a suite passing on one arm would never have surfaced.

### What you see, the moment the window reopens

1. **A Measurements pane with a number in it.** `f3db = 1.0233e+06`, `pm = 62.4 deg`, `sr = 1.83e+07`,
   in the Value column, labelled with the measurement's own name.
2. **A phase margin that is right.** Today any GUI that routed `vp()` to a Value column would show
   `1.089` and call it degrees.
3. **A THD number and a harmonic table** from a `.four` card, where today the harmonics exist only as
   text in a log.

### Files and procs

| file | proc | ± |
|---|---|---|
| `src/ase.tcl` — the SCHEMA half | the `measurements` state list (per-row, absent by default) and the expression grammar it validates against | **≈ +70** |
| the ngspice adapter (in `src/ase.tcl` — §1a) | **new** `ase::backend::ngspice::meas_line`, `…::meas_templates`, `…::meas_needs_degrees`; `render_deck`'s `meas` block, `.four` card slot, post-processing command slot. **`.meas` is ngspice's card, 8b's eight templates are written in its syntax, and `meas_needs_degrees` encodes its radians trap (T9) — content, all three** | **≈ +260** |
| `src/ase_window.tcl` | the Measurements sub-dialog, the template picker, the Value-column rows | **≈ +330** |

### Suites that move

* New suite (`test_ase_meas_1400.tcl`, or rows in `test_ase_core.tcl`'s D section): one golden per
  `kind`; the `set units=degrees` auto-emission **and its non-vacuity control** (a row with no phase in
  it must **not** emit the line); the four refusals; the card/command split.
* `test_ase_optier_0963.tcl` **E17** (`the Outputs Value column reads the OPERATING POINT`) — re-run;
  measurement rows are additive and must not displace it.

### Re-measure on the dev display

The launch line is Stage 2's. Take: the **Measurements pane with numbers in it** (`f3db = 1.0233e+06`,
`pm = 62.4 deg`, `sr = 1.83e+07`) and the harmonic table from a `.four` card. The pane reuses Stage 5's
`resulttable` and Stage 3's form idiom, so **no new look debt is filed** — but check the `deg` unit
actually reaches the Y-axis label, because that is the visible half of the radians trap.

### Rulings in this stage

**⚖ R9** — every template name, every measurement label, the degrees sentence.

---

## Stage 9 — SP end to end

**One commit. Ruling ⚖ R9.** S-parameters with **no schematic edit**.

`span.c:376-386` calls `controlled_exit(EXIT_BAD)` below two ports: the process dies, the `.control`
block never resumes, and `run_done` may still see rc 0 if an earlier analysis succeeded. So
`two_ports` is **fatal**. But the precondition is **satisfied by the GUI, not merely checked** —
measured on two *ordinary* V sources that declare no port in the netlist:

```
alter v1 portnum = 1 / alter v1 z0 = 50 / alter v2 portnum = 2 / alter v2 z0 = 50
sp lin 3 100meg 1g
```

→ rc 0, `$curplotname` = `SP Analysis`, `s_1_1[1] = 1.674674e-05,-2.89363e-03`.

**And `sp` carries `ac`'s two-point defect, which nothing in this plan fenced until now:**

```tcl
  rules {{lin_two {sweep eq lin && points eq 2} refuse
           {a linear sweep of 2 points yields ONE point (span.c:417-427); use 3 or more}}}
```

Measured this session: `sp lin 2 100meg 1g` → `No. of Data Rows : 1`; `sp lin 3 100meg 1g` → 3.
`span.c:417-427` is character-for-character `acan.c:103-114`'s shape —
`if (job->SPnumberSteps - 1 > 1) … else job->SPfreqDelta = 0;`. Trap **T6**; APPENDIX §7.2 **S1**.

**The parameter-level source for this stage** is APPENDIX **§2.11** (`SP`: the port promotion, the
`controlled_exit` arms, the `portnum`/`z0` read-back asymmetry and `wrs2p`).

### 9a. The Ports table

```
S-parameter ports
  ┌──────────┬──────┬──────────┐
  │ Source   │ Port │ Z0 (Ω)   │        [Add from schematic…]
  ├──────────┼──────┼──────────┤
  │ v1       │  1   │ 50       │
  │ v2       │  2   │ 50       │
  └──────────┴──────┴──────────┘
  Ports are assigned at run time. Nothing is written to your schematic.
```

emitting those four `alter` lines immediately before the `sp` line. The `two_ports` fatal is then
evaluated **after** these lines are computed — it refuses only when the *table* is short, which the
user can fix in the dialog.

⚠ `portnum` is **not readable back** (`show v : portnum` returns 0 for a source declared `portnum 1`),
so the table is **GUI-owned state** and the netlist scan only *adds* sources that already declare one.

⚠ **THAT LAST CLAUSE IS REFUTED BY THIS STAGE'S OWN HEADLINE CASE, 2026-09-13 (issue 1454), AND
THE SHIPPED SCAN DOES SOMETHING ELSE.** The bench Stage 9 exists for is two **ordinary** V sources
promoted at run time with no schematic edit — on which *"only sources that already declare a
`portnum`"* offers **nothing**. So the scan offers every **top-level independent voltage source**
(no current sources, none inside a subcircuit, none already in the table), and what a declaration
buys is the **prefill**: a declaring source comes back with its own number and Z0, an ordinary one
with the next free number and a **blank** Z0 — because 50 Ω is the simulator's default and ASE-L
does not invent a number the user never typed. It **peeks and never netlists**: a bench nobody has
netlisted gets the precondition banner's own cold sentence and an empty list.

### 9b. The S-parameter surface

Matrix picker, Smith/polar, and `wrs2p` export with the `.csparam Rbase=50` workaround.

⚠ **SHIPPED HALF, 2026-09-13 (issue 1454): THE MATRIX PICKER IS IN AND THE SMITH CHART IS NOT,
AND THAT IS A MEASUREMENT ABOUT THIS TREE RATHER THAN A CHOICE.** `grep -ri smith src/*.c
src/*.tcl` prints **nothing** and `polar` matches only `bipolar`: the waveform viewer has one
rectangular axis pair and no mode that would draw either. A Smith chart is a new plot engine in
`wave_viewer.tcl`/`draw.c`, which is a different stage. What shipped instead are the four formats
the viewer **can** render of a complex answer — `db20()`, `cph()`, `re()`, `im()` — each measured
accepted against both binaries' variable lists. ⚠ **The `wrs2p` export is NOT `.csparam`**: it is
`let Rbase = <port 1's Z0>` / `wrs2p` / `unlet Rbase`, measured byte-identical to the `.csparam`
route and **per row** rather than deck-level, so two `sp` rows can carry different port-1
impedances (issue 1452). ⚠ **And §9a's scan rule below is refuted by this stage's own headline
case** — see the ⚠ there.

### What you see, the moment the window reopens

1. **`sp` is `ok`** on a deck that declares no ports at all, because the table makes it satisfiable.
2. **An S-matrix picker** ~~and a Smith chart~~, from a schematic nobody edited. ⚠ **The chart is outstanding** — see the ⚠ under §9b.
3. **A Touchstone file** you can open in someone else's tool.

### Files and procs

The ngspice adapter (in `src/ase.tcl` — §1a) — the `sp` registry entry and **new**
`ase::backend::ngspice::sp_alter_lines`, which spells `alter <src> portnum = N` / `z0 = R` and is
therefore content. `src/ase.tcl` core — the `two_ports` post-table evaluation, which is schema: it
reads the ports table the user filled in and never spells a simulator word (**≈ +140** between them).
`src/ase_window.tcl` — the Ports table (a `listdlg` config), the S-parameter surface (**≈ +300**).

### Suites that move

New goldens only: a deck with the four `alter` lines in the right place; a `two_ports` refusal with a
one-row table; a row proving the fatal is evaluated **after** the table, not before.

### Re-measure on the dev display

The launch line is Stage 2's. Take: the **Ports table** (a `listdlg` config) with its
*"Ports are assigned at run time. Nothing is written to your schematic."* line, and the S-matrix
picker. ⚠ **If the Smith chart is drawn as a new plot form rather than through the existing waveform
viewer, file `owed.sh add look` for it** — the look-debt list in the ruling ledger was written
assuming it reuses the viewer, and that assumption is this stage's to confirm or break.

### Rulings in this stage

**⚖ R9** — the Ports table's column heads and the sentence *"Ports are assigned at run time. Nothing is
written to your schematic."*

---

# REACH

## Stage 10 — Convergence and diagnosis

**Two commits. Ruling ⚖ R9. ⚠ Open question M1 gates the live pane, not the stage.**

This is the failure story ADE-L answers with an opaque `sim.log`.

### 10a. `CKTncDump`'s starred nodes, highlighted on the canvas

After a failed operating point ngspice prints a `Last Node Voltages` table with a trailing ` *` on
**every node that still fails the convergence test** (`cktncdump.c:11-43`). `evidence/convergence.md`
calls it *"the single most useful diagnostic in ngspice"* and nobody has ever put a UI on it. Parse it,
map the names through `ase::netlist_map`'s existing hierarchy-qualified resolution, and **highlight
those nets on the schematic**. Every piece exists; it needs no ngspice change. **Biggest win per line
of code in the entire evidence base.**

### 10b. The ladder pane and the remedy assistant

One panel, four rungs matching `cktop.c`'s actual ladder, emitting **either** `.options
noopiter/gminsteps/srcsteps` **or** one `optran` line, **never both** — `optran`'s first three
arguments supersede them on the same task:

```
Operating point strategy
  [x] 1. Newton from the initial guess                        -> optran arg 1
  [x] 2. gmin stepping        steps [ 1 ]                     -> optran arg 2
  [x] 3. source stepping      steps [ 1 ]                     -> optran arg 3
  [x] 4. transient operating point   step [ 100n ] to [ 10u ] -> optran args 4,5
        ⚠ ON BY DEFAULT in this ngspice (`optran 1 1 1 100n 10u 0`, injected by
          init.c:77-94). It returns the TRANSIENT state at the stop time as your
          operating point — measured 0.9999550 instead of 1.0 on a 1 us RC.
      [ Pick a settle time for me ]  = 100 x tstep before a transient,
                                       0.1 / fstart before an AC or noise run
  emits:  optran 1 1 1 100n 10u 0     <- the shipped defaults; gminsteps and
                                         srcsteps are BOTH 1 (cktntask.c:120-122),
                                         which is why this agrees with the ⚠ above
```

plus **a sentence on the OP form itself**: *"this operating point may come from a transient"*. That
sentence is a fact about the numbers in the Value column and no ngspice user has ever seen it.

⚠ The ramp argument is **always emitted as 0**: `optran.c:670-671` has no clamp, the factor oscillates
and returns to 0 at 2 × ramptime, and `README.optran` says ramping is not established.

**Two parser rules that must be COMMENTS IN THE CODE**, because they will otherwise be re-learned: the
two `ngdebug` per-step lines (`Trying gmin = …`, `Supplies reduced to …%`) end **without a newline**,
and the ladder is on **stderr** while `CKTncDump` and SOA warnings are on **stdout** — ASE-L folds them
with `2>@1`, so **match on line CONTENT, never on arrival order**, and never build a state machine that
assumes sequence.

### 10c. `wrnodev` save/restore, and the run-health strip

`wrnodev <file>` after a converged `op` plus a `.include <file>` row — the fastest fix for a bench that
takes four minutes to find its operating point. And one line, not a pane, for `rusage devtimes` /
`tranpoints accept rejected`.

### What you see

1. **The nodes that failed to converge, lit up on your schematic.**
2. **A ladder that shows which rung the simulator is on**, live.
3. **The `optran` fallback, visible for the first time**, with the sentence that says your operating
   point may not be an operating point.

### Files and procs

`src/ase.tcl` — **new** `ase::ncdump_parse`, `ase::ladder_parse`, `ase::optran_line`,
`ase::wrnodev_lines` (**≈ +260**). `src/ase_window.tcl` — the ladder pane, the remedy assistant with a
diff preview, the canvas highlight call, the health strip (**≈ +330**).

### Suites that move

New suite driven by **canned log text**, not a real non-converging deck, so it is deterministic: the
`*`-suffix parse; the no-trailing-newline lines; a **content-matched** ladder with the lines
deliberately interleaved out of order; the `optran`-xor-`noopiter` rule; the ramp-always-0 rule.

⚠ **M1 blocks the live pane, not the stage.** Until it closes, the pane reads the log file after the
fact. The experiment: run a deliberately non-converging OP through `ase::run_deck`'s existing capture
with `set ngdebug`, and diff the interleaving against two separate `-o` / `2>` files. One deck.

### Re-measure on the dev display

The launch line is Stage 2's. Take: **the nets `CKTncDump` starred, lit on the canvas** — this is a
change to the *canvas*, not to ASE-L, so it must be looked at on the user's own screen
(`AUDIT_DISPLAY=$DISPLAY`, not `:99`); the four-rung ladder pane with its checkboxes and the `optran`
sentence beneath; and the one-line run-health strip. File `owed.sh add look` for the lit nets.

### Rulings in this stage

**⚖ R9** — the four rung labels, the `optran` sentence, the refusal sentences.

---

## Stage 11 — Campaigns: sweeps, corners, Monte Carlo

**Two or three commits. Rulings ⚖ R8; ⚖ R2 is ANSWERED (yes, four conditions).**

⚠ **MEASURED 2026-09-13, and the drop is SILENT — `evidence/sweep-nesting.md`.** A third `.dc`
sweep level is **accepted and discarded**: three nested sweeps produce the same **9** rows as two,
byte-identical values, **rc 0 and nothing on stderr**, on both binaries. A user who asks for 27
operating points gets 9 and is told nothing. **So ASE-L must REFUSE a third level at the form**,
not pass it through with a caution. It is the fourth *accepted-and-inert* case this batch has
measured, and the rule they add up to is that **ngspice's usual answer to a request it cannot
honour is to take it and say nothing** — so "the simulator did not complain" is never evidence
that a setting reached anything.

ngspice has **no `.step` and no corner construct**; `.dc` nests exactly twice and sweeps only
R / V / I / `temp`; nested sweeps come back **flattened with no `Dimensions:` header**. So the GUI
generates the campaign, and being a good code generator is the job.

**The parameter-level source for this stage** is APPENDIX **§4** in full — §4.2 the four sweep
mechanisms ranked, §4.3 temperature's three mechanisms of which one is not a sweep, §4.4 corners and
Monte Carlo, §4.5 the generator's sharp edges, §4.6 one process per point versus one for all.

### 11a. One process per point

```
campaign/
  deck.spice                 <- ONE deck, byte-identical for every shard
  shard-0001/.spiceinit      <- set myres=4700 / set ase_temp=27 / set mc_vth=0.71
  shard-0001/<cell>_ase.raw
  shard-0001/<cell>_ase.plotmap
  shard-0002/…
  index.tsv                  <- shard | axis coordinates | exit code | raw path
                             |  + ONE COLUMN PER MEASUREMENT (Stage 8)
```

| | shard runner | one process, a `.control` loop |
|---|---|---|
| abort | kill the current shard; **every completed shard survives** — and from Stage 6f the shard that was *running* keeps what it had | Ctrl-C is timing-dependent and the user cannot tell which happened |
| an interrupted run | its shard has a non-zero exit code | leaves `sim_status = 0` — **indistinguishable from success** |
| progress | `k/N`, free | a generated `echo` the GUI must parse |
| the deck | one artifact, reviewable, diffable, hand-runnable | a generated loop nobody can read |
| results | one raw per point; the family is a directory | one raw with N plots, or a hand-built collector with the default-scale trap |
| parallelism | trivially available later | none |
| cost | N process starts + N parses | N parses (`reset`) or none (`alter`) |

⚠ **The honest counter-row:** `alter`/`altermod` avoid the re-parse and are ~10× cheaper per run on a
big PDK deck. So **`alter`-only axes may be collapsed into one shard**, and the runner **says which
mode it chose** in the run log.

The design-variable mechanism is measured: `.param rv = 'var(myres)'` in the deck plus
`set myres = 4700` in `<rundir>/.spiceinit` gives `@r1[resistance] = 4700` **with the process cwd
somewhere else entirely**. The schematic is untouched, the deck is byte-identical between shards, and
the only thing that varies is a two-line file. For a variable ASE-L itself rendered,
`alterparam <name> = <v>` + `reset` is the cheaper primitive; `var()` is the fallback for a value ASE-L
did not render.

**Axis kinds:** design variable (`.param x='var(ase_x)'` + per-shard `set`, or `alterparam` + `reset`);
instance parameter (`alter <flat> <param>=<v>`, no re-parse, same shard); model parameter
(`altermod @<model>[<p>]=<v>`, same); **temperature** — ⚠ `temp` is **not** a `.param`: uniform step and
an OP/DC analysis collapses to `dc … temp a b s`, otherwise **`.options temp=<v>` re-rendered per
shard** (an `OPTtbl` `IF_REAL` keyword) and never `set temp`; **corner** — re-render the deck with a
different `.lib <file> <section>` row, because `.lib` section selection happens at parse time and
cannot be `alter`ed, so corners always shard; statistical — the GUI draws the samples.

### 11b. The GUI is the random number generator

Not `agauss` in the netlist and not `sgauss` in the control language. ngspice's seeding has two serious
traps and three routes of which one silently does nothing; a model-level draw was *proven* to change
between runs of the same migrated state (issue 0210); and transient white and 1/f noise are
**irreproducible under every seed control** because the Wallace pool is seeded from `getpid()`.

When the GUI draws, the sample set is reproducible, inspectable, exportable, re-runnable point by
point, and **is a column in `index.tsv`**. **ADE-L cannot show you its samples.**

### 11c. The campaign ends with a NUMBER, not a directory

`index.tsv` carries one column per `measurements` row, and the campaign's result table offers
**histogram, mean, sigma, min/max, yield against a spec limit, and a scatter of any two columns** —
computed **in Tcl**, because ngspice has no sort, no median, no percentile and no histogram.

### 11d. Generator rules, each with its measured reason

A first implementation falls into every one of these.

| rule | reason |
|---|---|
| re-emit `save` after every `reset` | the save list does not survive a re-parse; the shipped ngspice examples get this wrong |
| name the collector: `setplot new aselres "ASE-L results" aseldata` | a bare `setplot new` gives `unknown1`/`Anonymous` |
| never compare strings in `.control` | T10 — both `eq` and `ne` take the false branch |
| never put `.` `-` `(` `[` in a generated variable name | T11 — `$` substitution swallows them |
| `set x = "$&vec"` to move a vector value into a shell variable | `$&vec` alone loses precision |
| statistics in Tcl, never in the deck | ngspice has no sort/median/percentile/histogram |
| `setseed <n>` once, and **say what it does not reproduce** | white and 1/f transient noise are `getpid()`-seeded; RTS and `trrandom` are reproducible |
| filter `Reset re-loads circuit <title>` from stdout | printed on every `reset` (`inp.c:551`) |

### What you see

1. **A sweep, a corner set and a Monte Carlo run, from one dialog**, with a progress readout of `k/N`
   and a Stop that keeps every completed point — plus, from Stage 6f, the partial one it was in the
   middle of.
2. **A histogram with a yield number under it**, not a directory of rawfiles.
3. **The sample set itself**, as a column you can export.

### Files and procs

`src/ase.tcl` — the campaign config; **new** `ase::campaign_shards`, `ase::campaign_render`,
`ase::campaign_index`, `ase::mc_draw`, the Tcl statistics (**≈ +700**). `src/ase_window.tcl` — the
campaign dialog, the progress readout, the campaign result table (**≈ +450**).

### Suites that move

New suite, driven by a **stand-in simulator** (the `test_ase_simcaps_0948` / `test_ase_optier_0963`
idiom: a few-line `/bin/sh` script that reads the deck and writes canned results), so no real ngspice
is required and the rows are deterministic: shard directory layout; deck byte-identity across shards;
`index.tsv` columns; the abort semantics; each of the eight generator rules as its own row with a
non-vacuity control.

⚠ **A multi-raw family is new to the waveform viewer and to the Calculator**, whose spec says v1
handles only the single-raw multi-dataset case. That is not an experiment — it is a conversation with
`doc/claude/specs/calculator.md`'s owner, **at this stage, not at Stage 0**. Open question **M5**.

### Re-measure on the dev display

The launch line is Stage 2's. Take: **the histogram**, with mean/sigma/yield beside it, drawn in Tcl
because ngspice has no histogram; and the campaign progress readout (`k/N`). File `owed.sh add look`
— a histogram is a new drawing in this tree and nothing else in ASE-L draws one.

### Rulings in this stage

**⚖ R8** — where does a campaign's configuration live? Recommendation: **a new top-level `sweep` state
key**, joining `ase::omit_if_empty` so byte-identity for the 104 committed files is preserved *by
construction* and `version` stays 1. It is the single named exception to "no new top-level keys".
**⚖ R2** applied again and is **answered yes**, so the design-variable axis ships: per-shard
`<rundir>/.spiceinit` under R2's four conditions. ⚠ **The fallback is not deleted, because R2's own
fourth condition keeps it live** — under `-n`, or when the rundir is the shared `set_netlist_dir 0`
directory, the file is refused and a campaign there falls back to `alterparam` over ASE-L's own
`.param` rows only. Say so where the campaign is configured rather than failing later.

---

## Stage 12 — Event-driven results: the digital half

**One commit. Ruling ⚖ R9.** XSPICE is **on by default** in this build, so a mixed-signal deck is an
ordinary deck — and today its digital half is invisible.

**The parameter-level source for this stage** is APPENDIX **§6.6** (event-driven results — what the
rawfile does and does not contain, and what `edisplay`/`eprvcd` give instead).

Measured on an `adc_bridge → d_inverter → dac_bridge` chain:

* **Inventory:** `edisplay` prints a machine-readable list of the event nodes in the current plot —
  `din : d , 7` / `dout : d , 7` — with no netlist parsing. It is also the check that decides whether
  any of this is emitted at all.
* **Transport:** `eprvcd din dout > <cell>_ase_evt.vcd` writes a **valid VCD** (`$timescale 1 ps`,
  `$var wire 1 ! din`, value changes).
* **The rawfile is NOT a viable transport:** `write mx.raw all` contains `time i(adac) v(aout) v(in)
  i(vin)` and **not** `din`/`dout`, silently; naming them explicitly produces vectors declared
  `dims=10` while `No. Points: 119`, zero-padded and not truncated on read.
* **Attach:** ASE-L already has the pipeline — `ase::cosim_map`, `ase::last_vcdfiles`,
  `ase::attach_dbs {rawfile sim_type {vcdfiles {}}}`. **The event VCD joins that list. This is one
  emitted line and one list append.**

**Two cautions the analyses pane owes a mixed deck:** `trtol` is **silently forced to 1** whenever
event nodes exist, which changes numbers and belongs in the `caution` vocabulary; and the DC-sweep +
auto-bridge failure has a reproducer and no root cause, so `dc` on a deck with event nodes is
`caution`, not `ok`. ⚠ **That second caution is permanent until open question M13 closes** — a
user-facing caution with no debt behind it is how a temporary hedge becomes furniture. M13 is in the
"Still open" table and `evidence/xspice.md` §12.1/§12.2 has the reproducer.

**Refused:** `.probe alli` on such a deck (fatal — `Error: Dot command '.probe alli' and digital nodes
are not compatible`); and `snsave`/`snload`, which this plan refuses **generally** — see the
refuse-list — not only here. Listing them in this stage's refusal line alone would read as "refused
for event decks, available otherwise", and they are available on neither.

### What you see

The digital pane fills in for a mixed-signal run, with the nodes under their ngspice names, beside the
analog traces from the same run.

### Files and procs

`src/ase.tcl` — **new** `ase::event_nodes` (parses `edisplay`), the `eprvcd` emission, the `vcdfiles`
append, the two cautions (**≈ +120**). `src/ase_window.tcl` — none beyond the caution sentence.

### Suites that move

New goldens: the `eprvcd` line present only when `edisplay` found nodes; the `.probe alli` refusal; the
`trtol` caution. `test_ase_cosim.tcl` is the neighbouring suite and its **RD4 / RD5 / RD6**
default-bridge rows and the rest of **RD1–RD11** must stay green. (`E5` in that file is a plan-item
label in a comment, not a check name.)

⚠ **Open question M9 is this stage's whole claim** and is not closed: does the `eprvcd` VCD attach
cleanly through `ase::attach_dbs` **alongside** a rawfile, and does the digital pane label the nodes
with their ngspice names? The experiment is to drive the measured `adc_bridge` deck through a real
ASE-L session with the VCD in `vcdfiles`. Do it before writing the emission.

### Re-measure on the dev display

The launch line is Stage 2's. Take: **the digital pane filled in beside the analog traces from the
same run**, with the event nodes under their ngspice names. **The labelling is the half nobody has
seen** — it is the second clause of open question **M9**, and this screenshot is that question's
proof. No new pane is built (the VCD pipeline already owns it), so **no new look debt is filed**.

### Rulings in this stage

**⚖ R9** — the two caution sentences and the `.probe alli` refusal.

---

## Stage 13 — Transient noise and `trrandom`

**One commit. Ruling ⚖ R9.** ⚠ A claim to check before quoting it: this is written as a category
ADE-L's *Choosing Analyses* form does not expose. Spectre itself has a transient-noise capability, so
the defensible sentence is about the form, not the simulator (see *The ADE-L comparison*).

**The parameter-level source for this stage** is APPENDIX **§5** in full — §5.2 all seven `trnoise`
arguments, §5.3 all five `trrandom` arguments, §5.4 seeding and the sentence a form owes the user,
§5.5 the two injection routes.

Both are `IF_REALVEC` instance parameters on **both** `vsrc` and `isrc` — the manual's *"isrc not yet
available"* is wrong here, measured — and documented nowhere in-tree. They belong on the **Tran form**
as a collapsible section: they are a simulation setting, not a source property, and nothing goes on the
schematic.

**Two injection routes, neither touching the schematic:**

1. `alter <src> trnoise = [ 10m 1u 0 0 ]` on an existing DC-only source — the GUI knows which sources
   it drives and **greys out the ones carrying a stimulus**, because the stimulus is replaced;
2. a parallel current source added by `render_deck` in a slot right after the netlist —
   `ase_inoise_1 0 out dc 0 trnoise(1m 1u 1 0.1m 5m 18u 30u)` — validated against
   `ase::netlist_map_resolve` first.

**The form**, one row per noisy source:

| field | meaning | validation |
|---|---|---|
| NA | white-noise amplitude | density = `NA*sqrt(2*TS)` V/√Hz — **shown as a derived readout** |
| TS | **the timestep**, not `tstep` | > 0. ⚠ **a negative TS HANGS ngspice.** Points ≈ `5*tstop/TS` — shown as a derived readout with an estimated file size |
| NALPHA | 1/f exponent | **strictly 0 < NALPHA < 2**; NALPHA = 2 is a silent zero |
| NAMP | 1/f amplitude | ≥ 0 |
| RTSAM / RTSCAPT / RTSEMT | RTS amplitude / mean-low / mean-high time | ≥ 0 |

**All seven `trnoise` arguments and all five `trrandom` arguments are emitted, always, positionally,
padded with 0.** Short forms are a heap read and a silent zero, and two shipped ngspice examples get
them wrong. ⚠ `evidence/trnoise.md` §10.3 says to omit args 5–7 when RTS is off; padding was measured
benign (stddev 8.59e-4 unpadded against 8.65e-4 padded, no DC offset). **Pad**, and this line is the
record of the disagreement.

**`trrandom` gets equal billing** — five distributions (`1` uniform, `2` gaussian, `3` exponential,
`4` poisson) with `TYPE TS TD PARAM1 PARAM2`, its own row kind in the same table, the same derived
readouts, and two refusals: on a **current** source it freezes after the first missed timepoint (emit a
V source + a VCCS instead), and under an `optran` fallback operating point it **pollutes the OP**, so
the section warns when Stage 10's rung 4 is armed. The `notrnoise` kill switch is a catalogue row.

**And one sentence, on screen, worth more than the whole manual on the subject:** *"White and 1/f noise
are not reproducible in this build — the generator is seeded from the process id."*

### What you see, the moment the window reopens

1. **A Transient noise section on the Tran form**, folded shut by default, with one row per noisy
   source and a **Add a noise source** button that offers only the sources a stimulus is not already
   using.
2. **A derived readout under NA and TS:** `density 1.41e-05 V/√Hz · ≈ 100,000 points · ≈ 4.8 MB`,
   before you run rather than after you wait.
3. **A sentence saying what the seed does not reproduce**, which is the fact this whole feature turns
   on and which the manual does not state.

### Files and procs

`src/ase.tcl` — **new** `ase::trnoise_lines`, `ase::trrandom_lines`, the derived readouts, the two
refusals (**≈ +200**). `src/ase_window.tcl` — the Tran form's collapsible section (**≈ +200**).

### Suites that move

New goldens: seven args always, padded; five args always; the current-source refusal; the
stimulus-bearing source greyed; the negative-TS refusal.

### Re-measure on the dev display

The launch line is Stage 2's. Take: the Tran form's **collapsible transient-noise section** with its
derived readouts (`density = NA*sqrt(2*TS)` shown live) and the honest seed sentence. It is a
disclosure inside Stage 3's form, whose look debt already covers the idiom, so **no new look debt is
filed** — but the derived readout is a number on screen and must be checked against the arithmetic.

### Rulings in this stage

**⚖ R9** — the field labels, the derived readouts, and the seed sentence.

---

## Stage 14 — PSS, explicitly experimental

**One commit. Ruling ⚖ R7. Last, deliberately.**

**The parameter-level source for this stage** is APPENDIX **§2.12** (`PSS`, absent from this build,
measured on the `--enable-pss` one) and **§1.7** (what a different build changes).

Every competing design refused a PSS form on the grounds that nobody had ever run it. Somebody has:
`evidence/builds.md` §1 built `--enable-pss` and ran it. **Measured:** a 3-stage ring in **0.91 s**,
Van der Pol in **0.41 s**, both `Convergence reached`, both within ~1 % of their documented f0,
deterministic to the centisecond. Two plots, literals **`Time Domain Periodic Steady State Analysis`**
(points+1 rows, scale `time`, **absolute circuit time, not 0..T**) and **`Frequency Domain Periodic
Steady State Analysis`** (exactly `harmonics` rows including DC, scale `frequency`, magnitudes only,
every variable tagged `plot=1`).

**It is shippable if and only if the form is a hard validator.** These refusals are not optional:

| refuse | because |
|---|---|
| `harmonics < 2` | 0 = SIGSEGV; 1 = infinite recursion at 199 % CPU |
| `fguess <= 0` | — |
| `fguess` biased **high** | 2.1× high aborts; 19× low converged. **Bias the default low.** |
| `points < 8` | — |
| `sc_iter > 1023` or `< 5` | — |
| `steady_coeff < 1e-6` | 1e-9 gave a **false** `Convergence reached` **4.5 % wrong** |

And three behaviours the panel must encode:

* **rc is not a success signal.** `Convergence not reached` returns **rc 0** with both plots full of
  plausible data. The panel scrapes stdout for the verdict string.
* **The plot numbering is not fixed** — the recursive relaunch produces 2 × (1 + relaunches) plots — so
  take the **last** TD/FD pair by Plotname.
* **`oscnode` steers nothing.** A nonexistent `oscnode` runs normally with no NULL deref. The field
  stays, because the argument list is positional, and its hint says *"ngspice records this and never
  reads it."*

Offer a **transient + FFT cross-check** beside the answer, because a false convergence looks exactly
like a true one.

### What you see, the moment the window reopens

1. **A twelfth analysis**, `ok` on a build that has it and `absent` with the flag named on one that
   does not.
2. **The word *experimental* on the form**, and a refusal — not a crash — for every input measured to
   crash.
3. **A verdict line the exit code cannot give you:** *"ngspice reported `Convergence not reached`; the
   two plots below contain data anyway and should not be trusted"*, beside an offer to run the same
   circuit as a transient and FFT it.

### Files and procs

The ngspice adapter (in `src/ase.tcl` — §1a) — the `pss` registry entry with its `rules`, and **new**
`ase::backend::ngspice::pss_verdict`, which scrapes **ngspice's own stdout strings** and is content by
any reading (**≈ +180**). `src/ase_window.tcl` — the panel, the word *experimental* on the form
(**≈ +120**).

### Suites that move

New suite, canned-stdout driven: each refusal with a non-vacuity control; the verdict scrape against
both literal strings; the last-pair-by-Plotname rule against a four-plot header.

### Re-measure on the dev display

The launch line is Stage 2's. Take: **the word *experimental* on the form**, and the verdict line
after a run that reported `Convergence not reached` while returning rc 0. Both are copy, not layout,
so **no new look debt is filed** beyond ⚖ R7's own ratification of the sentences.

### Rulings in this stage

**⚖ R7** — do we ship a PSS panel at all? Recommendation **yes, last, explicitly experimental**, with
the hard validator, the stdout verdict scrape, the transient+FFT cross-check offered beside the answer,
and the sentence that `oscnode` steers nothing.

---

## Stage 15 — The adapter conformance harness

**Not one of this pass's fifteen commits. This is what the SECOND adapter needs, not what the first
one does — and it is a stage sketch, not a design.**

Stage 1 makes the contract; every stage after it fills the contract in for ngspice. Neither proves
the contract holds for a simulator nobody here owns, because the only reader of the schema is the
crew that wrote it. A conformance harness is what closes that: **a suite an adapter author runs
against their own binary until it goes green**, which turns *"write an integration"* from an
open-ended reading exercise into a loop with a pass/fail signal at the end of it.

Five checks, in the order an author would hit them:

1. **Schema** — every required key present and of the declared kind; every registry row carries a
   `results` destination. D30 already makes a row without one a load-time error; here it is a check
   with a message that names the row.
2. **Emit** — render each declared analysis from its own descriptor defaults, hand the deck to the
   author's binary, and assert it is accepted. An `emit` template that cannot produce one runnable
   line is a descriptor that will fail on a user's first click.
3. **Probe, in BOTH directions** — the capability answer must say *present* on a build that has the
   analysis and *absent* on one that does not. **The fixture already exists and is the measured
   argument for this whole split**: `/usr/bin/ngspice` and `build-ver_50` have `pss`, and the
   bare-configure upstream build at `workpad/builds/upstream47` does not (§1, §0.14, APPENDIX §1.7
   `[A-M7]`). A harness that only ever ran against one build would have called both
   descriptors conformant.
4. **Results** — every `results` destination names a vector that exists after a run of the analysis
   that claims to produce it. This is where a wrong plot literal shows up as a red row instead of as
   an empty Value column six months later.
5. **Refusals** — at least one `needs` precondition and one `rules` clause per adapter shown to
   actually refuse. A descriptor whose refusals never fire has refusals that were never wired.

**What it is not.** It is not an adapter-author specification: no document here tells a stranger how
to write the second adapter, and none is written speculatively — that is `LEDGER.md`'s debt **M16**,
left standing on purpose, and ⚖ **R10**'s **option B**.

### What you see

Nothing, in the window. This stage's entire surface is a suite an adapter author runs and a report it
prints — which is the point: the first thing a second simulator's agent should be able to do is find
out whether they are done.

### Files and procs

A new `tests/headless/test_ase_adapter_conform.tcl` plus a stand-in adapter and stand-in binaries in
the `test_ase_simcaps_0948` / `test_ase_optier_0963` idiom (a few-line `/bin/sh` script answering
canned files), and whatever `src/ase.tcl` must **expose** to be checkable — expected to be nothing
new, because checks 1–5 are readers of the same hook Stage 1 defines. **≈ +500**, mostly test.

**The build is the smaller half of the cost.** The standing cost is that every schema key gains a
check that must then be kept true as the schema moves, so the harness becomes a second reader of the
contract that Stages 2–14 must not drift away from. That is precisely why it is terminal rather than
Stage 2: with one first-party adapter it would spend its life telling ngspice's author what ngspice's
author already knows, while charging for every key they add.

### Suites that move

**None.** New suite only; it introduces no production behaviour and asserts against stand-ins, so no
existing row can move. Nothing here may relax an assertion in `test_ase_simcaps_0948` — a
conformance harness that green-lights a descriptor the capability suite refuses is worse than none.

### Re-measure on the dev display

**None — headless by construction.** No look debt.

### Rulings in this stage

**⚖ R10** — how far the formalisation goes. **`DECISIONS.md` owns the lettering and it is A / B / C**:
**A** the working hook plus its documented schema, which is exactly what Stage 1 builds; **B** = A plus
a written adapter-author specification; **C** = B plus *this harness*. Recommendation **A in this
batch**: the stage stays terminal and is built when a second adapter is actually wanted, because a
specification written before its second implementation documents guesses and a harness with one
first-party adapter grades the thing that defined it. ⚠ **If the ruling comes back C, this stage
moves from terminal-and-optional to scheduled, and Stage 8 or Stage 11 gives up the time.** R10 is
deliberately **not a row of the ruling ledger's table** below — that table holds the nine questions
that gate a stage in *this* pass, and R10 gates nothing until a second simulator exists. It is carried
in a note directly under that table, in `DECISIONS.md` in full, and in `LEDGER.md`'s Stage 15 block.

---

## Stage 16 — "The ngspice you actually have"

**One commit. Rulings ⚖ R11 (one sentence of it), ⚖ R9 (the rest of the sentences).** Added
2026-09-10 by the variant amendment (§0.13, `DECISIONS.md` **D42–D52**). It is the last stage
**in numbering** and the first **in adoption value**, and `LEDGER.md` says so beside the number so
nobody reads 16 as a priority. Stage 15 is terminal *and optional* (⚖ R10 = A); Stage 16 is
terminal *and the adoption gate*.

**Depends on:** Stage 2f/2g (the record and the probe). **Nothing depends on it.**

**RED first**, and the red row is the whole justification: today a `pre_command` reading
`unset temp` on apt 45.2 gives **rc 134, a destroyed log and no sentence anywhere** — the abort
does not flush stdio, so the user gets an empty pane and no explanation.

### 16a. The per-simulator sentence — one line, no table

**Its rule: it names only the DIFFERENCES, never the inventory.** A user with a complete build
reads eleven words and stops. Composed by an `ase::` proc from clauses the adapter supplies
(§1a's `notes` hook), through the existing mint. **Four frames:**

```
nothing measured
  "ASE-L has not measured /usr/bin/ngspice yet. Press Detect in the Simulators
   window -- it takes about a second -- to find out what it can do."

measured, nothing missing
  "<path> can do everything ASE-L offers."

measured, something missing
  "<path> can do everything ASE-L offers except case-sensitive net names and the
   fast operating-point dump."

measured, but NOT COMPLETELY                        <- the fourth frame, and it is new
  "<path> can do everything ASE-L offers, except that one measurement did not
   finish: <key>. Press Detect to try again."
```

⚠ **The fourth frame is not optional decoration.** On a slow box the budget kills leg D first
(§2g), Band 3 stays unmeasured for the session, and without this frame that user gets the
*"can do everything"* sentence by default — a claim nobody measured. It reads `unmeasured_keys`
(§2f), which is why that band is a Stage 2 deliverable rather than a design note.

**Worked, from the measured dicts:**

| binary | the line |
|---|---|
| **apt 45.2** | *"…can do everything ASE-L offers except case-sensitive net names, and its operating point is saved the long way because this build's `show` printer is unsound. Two kinds of line in a Commands box are unsafe on it; ASE-L will say so if you use one."* |
| **stock 47** | *"…can do everything ASE-L offers except case-sensitive net names. Two kinds of line in a Commands box are unsafe on it; ASE-L will say so if you use one."* |
| **the fork** | *"…can do everything ASE-L offers."* |

⚠ **Three things those sentences must NOT say, each corrected in this pass from a draft that said
them.** (a) **Never *"ngspice 47 fixes that"***: `git tag --contains 10276f993` returns nothing, so
that names a version **that does not exist yet**, and this is precisely the sentence introduced to
repair a *wrong explanation*. If the clause needs a door it is *"the fast dump needs an ngspice
newer than any release — there is nothing to install today"*, or it says only what tier `c` costs.
(b) **PSS is not mentioned on any row.** The rule is *mention only capabilities ASE-L actually
offers*; apt 45.2 is the one binary that HAS `pss` and ASE-L does not offer it until Stage 14, so
naming it on the fork's row as *"available on some builds and not on this one"* is inventory about
builds not in front of the user, and omitting it from apt's row while the generic frame uses it as
its example is frame and table disagreeing about the same binary. **One rule, both places.**
(c) **It never says "basic".** It names capabilities, so it stays true when the subsets change
(**D45**).

**Three properties to hold onto:** it is a **delta**, so it shrinks to nothing on the best build;
it **says the door** in the same breath as the gap (*"press Detect"*, *"ASE-L will say so if you
use one"*); and it appears **twice and only twice** — the Simulators window row beside the existing
casemode status line, updated by the free peek (`ase::sim_caps_have_path`) so opening the dialog
still starts nothing (**D8**), and the run log **once per binary per session**, through
`ase::cap_report`'s existing say-once discipline. Never on every run; never a modal.

### 16b. The pass-through linter — five patterns, one proc, warn and never rewrite

`ase::backend::ngspice::lint_control_text {lines caps}` runs over `pre_commands`, any hand-edited
`.control` block and a schematic's own code block. **It warns; it never rewrites** — rewriting user
text is the failure this whole amendment is trying not to commit.

| # | pattern | what it does on a binary without the fix | class | severity |
|---|---|---|---|---|
| 1 | line begins `unset` | `set temp=27` / `unset temp` → **SIGABRT rc 134, stdout destroyed**; `unset curplot` and `unset plots` by other arms | M-refusal | **warn always, never refuse** — the key that would license a refusal is the one D50 refuses to measure |
| 2 | line begins `define` / `undefine` | `define c(x) 5` + two `print c(2)` → SIGABRT; `define d(x,y) x` + `print d(2,3)` → SIGSEGV | M-refusal | warn always. ngspice's own built-ins (`vm`, `vp`, `vdb`, `vr`, `vi`) are operator-rooted and unaffected — the pattern is a **user** `define` |
| 3 | line begins `load` | a raw whose header carries `Option: curplot=` / `plots=` / `curplotname=` → SIGSEGV on the *next* command; one carrying `Option: no_auto_gnd` / `ngbehavior` / `sourcepath` **reconfigures the parser** for a later `source` | M-refusal | warn always. **And the good news in the same breath:** the fork's own `casemodewrite` header (`Option: casemode=…`) does **not** collide and loads cleanly on apt (measured) — a fork-written raw is safe to hand to a stock binary |
| 4 | a whitespace- or paren-delimited bare `gnd` token | rewritten to ` 0 ` in control-command **arguments**: `echo M7 my gnd rail` → `M7 my 0 rail`, `echo v(gnd)` → `v( 0 )`. Paths survive (`/ _ - .` are not delimiters) | M-free | gated on `ase::caps_measured_as $caps gnd_literal 0`, **warn when unmeasured** — the key is free (§2g, **D49**) |
| 5 | an ngspice keyword ARGUMENT spelled with capitals | rejected, **usually silently**: `write <file> ALL @M1[ID]` gives rc 0 **with no raw**, so the `$sim_status` guard does not fire and `attach_dbs` reports `NOT ATTACHED` | M-free | gated on `ase::caps_measured_as $caps keyword_case 0`, warn when unmeasured |

**Two things it must get right, or it becomes the nuisance it exists to prevent.** It runs at
**pre-flight**, on the same pass as `ase::run_precheck` and before the first `open`, so nothing is
left half-written for a later read to mistake for a result. And **it reports the LINE, not the
file**: *"your Commands box has a problem"* is a nag; a quoted line with the remedy beside it is a
diagnosis.

⚠ **Patterns 1–3 warn on every binary including the fork**, and that is accepted rather than
solved, because the alternative is D50's refused leg. If the fork user's one line is judged
intrusive, suppress it on `casemode_detected` containing `preserve` — already measured, already
free — rather than by aborting anybody's simulator.

### 16c. The two co-simulation file checks — not about the binary at all

These are defects of the **installation**, not of the executable, so they are a **file diff** at
the directory `$sourcepath` names (Band 1's `scripts_dir`; measured
`. /usr/share/ngspice/scripts …` on apt). Parse rule, because the list has repeats and a leading
`.`: **take the first absolute element whose basename is `scripts`.**

| check | what a 0 means | what the user gets |
|---|---|---|
| `grep -c verilated_vcd_c <scripts_dir>/vlnggen` | a `--trace` Verilator build fails the final link with unresolved symbols | run **once**, when the user first asks for Verilog waveforms. Name the cause — it is a *build-time* failure of `vlnggen` arriving as *"my wrapper won't link"* — and hand over the seven-line `fopen` probe from the fork's `vlnggen` |
| `grep -c 'contextp.release' <scripts_dir>/src/verilator_shim.cpp` | the `Vlng` model holds a **non-owning** pointer to a `VerilatedContext` destroyed when `Cosim_setup()` returns: **use-after-free for the whole simulation** | warn, and hand over the one-line patch. Say plainly that a run which *"worked"* is **not** evidence the memory was valid, and that the fix needs no ngspice rebuild — only the user's wrapper `.so` |

### 16d. The `dumpunsound` reason token

`ase::op_save_tier` gains a fifth reason token so 16a's sentence can say the actionable thing.
Today a 45.2 user is told *"there is a much shorter way your simulator would accept, but it is all
or nothing"* — **true, and the wrong explanation**; the actual reason is `altshow_op_dump 0`, which
the sentence never mentions. ⚠ **Whether that sentence is WANTED is a ruling, not a finding**
(⚖ R9): it changes what a 45.2 user is told about why their deck is 468 lines long.

### 16e. The release note — and the split that lets most of it ship today

⚠ **Two halves, and only one of them waits on a ruling.**

* **The DESCRIPTION ships now, with no ruling.** *"Here is what works on which ngspice"* — the
  can/cannot list and the eight evidenced claims of `evidence/fork-features.md` §12/§14, plus §0.13's
  headline that the ordinary deck already runs byte-identically on apt 45.2. It is a **measured
  finding**. It turns *"will this work with my ngspice?"* from an unanswered question into a yes,
  it is zero code, and it is **the highest-adoption-value item in this whole amendment**.
* **The SUPPORT SENTENCE waits on ⚖ R11.** *"What we test and will fix bugs against"* is a promise,
  not a measurement. R11 is filed **last** in the ask order, behind R2 and R10 — and an earlier
  draft of this amendment had R11 blocking the release note while also calling the note the
  ship-first item, which cannot both be true. **The description is not blocked; the promise is.**

### What you see, the moment the window reopens

1. **One sentence in the Simulators window**, beside the casemode status line, saying what *this*
   binary can and cannot do — and nothing at all when the answer is "everything".
2. **One line in the run log, once per binary per session**, with the same sentence.
3. **A pre-flight warning that quotes the line** when a Commands box holds one of the five
   patterns, with the remedy beside it — where today an `unset` line produces rc 134 and silence.
4. **Nothing else changes.** No new pane, no new colour, no new state, no modal.

### Files and procs

| file | proc | ± |
|---|---|---|
| `src/ase.tcl` — the SCHEMA half | **new** `ase::variant_sentence`, `ase::variant_say`, `ase::preflight_notes` (applies **D47**'s warn/refuse policy) | **≈ +170** |
| the ngspice adapter | **new** `variant_notes {caps}` (the clause list), `lint_control_text {lines caps}` (the five patterns), `cosim_shim_verdict {scripts_dir}`; the `dumpunsound` token on `ase::op_save_tier` | **≈ +230** |
| `src/ase_window.tcl` | the Simulators-window row | **≈ +40** |
| release note | 16e's description half | zero code |

### Suites that move

* **None move.** Everything here is additive: a sentence, a linter over text ASE-L does not
  generate, and two file greps.
* New suite for `lint_control_text`: one row per pattern, one row proving it **warns and does not
  rewrite** (the input text is returned unchanged), and a **non-vacuity** row where a clean
  Commands box produces zero notes.
* New rows for `ase::variant_sentence`: one per frame — including the fourth — driven from
  hand-built dicts, so no binary is started.
* **Conformance rows (shared with Stage 15):** no ordering operator takes `version_line` as an
  operand (**D44**); no bare `dict get $caps <capability key>` outside `ase::caps_get`; no
  `ase::caps_is` under a `!` (**D48**).

### Re-measure on the dev display

The Simulators window with **two** registry entries — `/usr/bin/ngspice` and the fork — so the two
sentences appear side by side and the delta is visible in one shot. **One look debt**, because this
is a new user-facing line in an existing dialog.

### Rulings in this stage

**⚖ R11** — the minimum supported ngspice, and **only 16e's support sentence waits on it**. Filed
last; recommendation **C** (a capability floor in the code, a tested-binaries promise in prose).
**⚖ R9** — the sentence batch: 16a's four frames, the five linter clauses, the two co-simulation
clauses, and 16d's `dumpunsound` explanation.

---

## Deferred — named, not forgotten

| | what | why it waits |
|---|---|---|
| **the `-p` transport** | one asynchronous reader parsing the `ngspice N -> ` prompt, replacing `-b` behind the same internal run interface | ⚖ **R1 is ANSWERED — Option A — so this waits.** Its justification is now three things, and **none of them is whether work survives a Stop**; Stage 6f settled that inside `-b`. **(1)** A **non-destructive** abort — not a *faster* one: batch already dies in **a few milliseconds at worst**, TERM and KILL alike, so what `-p` removes is checkpoint granularity, the torn-file window and the `shell mv`, not latency. **(2)** The **no-circuit capability probe**, which is the only oracle that can close **M15** and the one the adapter doctrine leans on — inside a deck the bare verb is a command, not a question, and on a build that has it, it **runs** (§0.11, Stage 2b). **(3)** The **pre-deck option class**: three doors and four traps collapse to one (`set` before `source`), which is what would make ⚖ R2 moot and delete D19. Still the prerequisite for the transient debugger |
| the transient debugger | `iplot` and `step` | both need interactive or `-p`. They are the pipe transport's first customers. ⚠ **`stop` and `resume` are no longer wholly deferred** — Stage 6f emits `stop after` / `resume` in the rendered `-b` deck (`evidence/salvage.md` §3). `stop when` is refused as a checkpoint primitive on its own merits (**D41.1**), not for want of a transport |
| `libngspice` | — | **refused**, see below |
| CIDER as an offered capability | — | **refused as a capability**; detected and warned about in Stage 4 |
| `sens2`, `hb` | — | `SEN2info` and `HBinfo` are `extern` declared and defined **nowhere** |

---

## Acceptance — the boilerplate every stage inherits

Every stage's receipt reports these by name.

* Every touched suite green with **floors RAISED, never lowered**; report before/after per suite, by
  name, **per arm** — `--nogui` and `:99` differ, and `test_ase_window` is 56 headless against 295 on
  `:99` as of issue 1398.
* **Sabotage-verify each new proc**: no-op it, confirm the named rows go red, restore by `cp` from a
  pristine copy and md5-compare. **Never `git checkout/restore/stash/clean`.** A suite can be 100 %
  green while the code you changed never executes; ask the falsification question and prove the suite
  can go red.
* **The 104 committed `.state` files still round-trip byte-identically** — rows **F3**
  (`test_ase_final`), **G3** (`test_ase_final_gf180`), **R4** (`test_ase_core`), **V4**
  (`test_ase_view`), **R2** (`test_ase_persist`). 105 is the on-disk count (§0.5); **re-count at the
  moment of asserting**, because the on-disk number moves whenever somebody saves a bench.
* The deck goldens unchanged wherever the change is meant to be rendering-only. **Stage 6 is the one
  stage allowed to move them**, once, deliberately.
* A **measured end-to-end on the user's own gesture shape**, on a scratch library with an explicit
  `rundir` — never a bench under `sky130A/`.
* `run_regression.tcl` **solo** (issue 0990), **T1 at ZERO counted failures**, under a scratch `HOME`
  with `XSCHEM_DEVDISPLAY_DIR` exported, `--nolog` throughout.
* **Rebuild before any audit that is meant to be evidence.** No test harness builds; a correct source
  tree with a stale binary produces a plausible audit with wrong answers and nothing says so.
* Debts recorded **at the moment they are incurred**: `owed.sh add rule <issue>` for every new
  user-facing sentence, `owed.sh add look <what>` for every pixel deliverable, `owed.sh add suite
  <name>` for the `:0` run. The ledger stands at **131 rule, 51 look, 8 suite** today; this plan adds
  to all three and the batching is the point.
* **Amend the spec of record, do not replace it.** `doc/claude/specs/ase_l.md`'s Choose Analyses
  paragraph is **six lines** today, and that is why this area drifted for so long. Every stage that
  invalidates a paragraph rewrites it **in the same commit**. Five paragraphs are owed by this batch,
  each named by its heading with a parenthesised line hint, and each owned by a stage rather than by
  the batch as a whole — a paragraph owned by everybody is amended by nobody:

  | spec paragraph | quoted first words | owner |
  |---|---|---|
  | `## Deck assembly (no C changes)` (hint `:88-89`) | *"`analyses` render into one `.control` block (op → `op`, dc → `dc V2 0 1.8 0.01`, …) in a fixed order"* | **Stage 0** (the order stops being a literal) and **Stage 6** (the block gains the walk — and, on a long transient, 6f's checkpoint loop) |
  | `### Panes (ONLY these three; log pane REMOVED)` (hint `:884-885`) | *"**Analyses** (right top): columns Type, Enable (checkbox), Arguments (view-only one-line summary)"* | **Stage 1** (Arguments becomes the emitted line) |
  | `### Choose Analyses dialog` **in full** (hint `:1094-1099`) | *"Two vertical sections: top = analysis types with radio buttons…"* | **Stage 2** (the grid) and **Stage 3** (the form) |
  | `### Menu tree (v2)` (hint `:1053`) | *"- **Analyses** — Choose… (Choose Analyses dialog)."* | **Stage 2** / **Stage 3** |
  | the **two** stale top-only sentences (hints `:946-947` and `:997`) | *"…and RUNNING is still top-only"* / *"only the RUN is top-only"* | **Stage 0** (§0d) — both, and the file's own `### Netlist and Run works from any level of the design (issue 0643)` at `:697` already contradicts them |

  Each stage's LEDGER section records **which spec paragraphs it rewrote**; a stage that names none is
  asserting it invalidated none.

---

## The ruling ledger — batch these, ask once

Nine questions in the table below, and **two more immediately under it — ⚖ R10 and ⚖ R11** — both
out of the table because neither gates a stage in this pass, not because either is answered.
**None of the eleven blocks Stage 0 or Stage 1.** House rule and the user's standing preference:
**one at a time, discussed before the next is raised.**

**⚖ R1 and ⚖ R2 have been asked and answered; both keep their rows, with the answers in them.** R1
was the one that reordered other stages and R2 was asked next and alone; the remaining seven have no
forced order — take them down the table from **R3**, one at a time, then **R10**, then **R11** last
of all.

File them as one batch under **one issue number minted at that moment** — read `NUMBERING.md`'s
tail then, not now, grep every clone's `doc/claude/issues/` first, and skip the reserved blocks —
then `owed.sh add rule <that number>`. This paragraph names no number on purpose: a number written
down in a plan is stale by the time a crew reads it, and two batches minting the same one is a
merge nobody wants.

| # | Stage | The question | My recommendation — and, for R1, **the user's answer** |
|---|---|---|---|
| **R1** ✅ **ANSWERED** | deferred / 2e, 6f, 7, 10, 11 | Transport: keep `-b` this batch and schedule `-p` as a later stage, or move to `-p` now? | **THE USER'S ANSWER: Option A — keep `-b` in this batch, `-p` stays deferred.** *"That being said, in terms of milestones on the plan, it can wait. We proceed along path of least resistance"*. **A REQUIREMENT CAME WITH IT: always salvage** — *"We should put that in right away - always salvage, and alert user that her sittings will cause loss of simulation effort 'thus far'"*. Placed as **Stage 6f** (the salvage, checkpointed, in `-b`, measured) and **Stage 2e** (the warning, which ships first). ⚠ **The recommendation survives; its COST LINE did not.** Recommended and still standing: define ONE internal run interface now — start / progress event / abort / results-located — implement it with `-b` for Stages 0–9, schedule `-p` as its second implementation immediately after Stage 10, and **refuse `libngspice` either way** — `-b` is not progress-blind, which removes the reason to hurry, and the abort story matters most once campaigns exist. Withdrawn: *"`-b` … leaves the only measured capability gap — stop and keep what you have — permanently open on a single long run."* It does not (§0.12, C34) |
| **R2** ✅ **ANSWERED** | 7, 11 | May ASE-L write `<rundir>/.spiceinit`, copying the user's own file into it? | **THE USER'S ANSWER: yes, with those four conditions** (2026-09-10, verbatim: *"yes, with those four conditions"*). The recommendation stands **as written**, so no option moved and no cost line was refuted — what changed is that the four are **requirements**, not advice: deleted and rewritten per run; the user's lines **copied** under a banner, never `source`d; the run log says once that it exists and what it shadows; **refused** under the shared `set_netlist_dir 0` rundir fallback and under `-n`, each refusal naming what it refuses over. It unblocks Stage 7's 26 pre-deck variables and Stage 11's design-variable axis. ⚠ Measured the day it was answered: there is **no `$HOME/.spiceinit` on this machine** and `SPICE_USERINIT_DIR` is unset, so condition 2 shadows nothing *today* — which does not make it optional, it makes it the condition that bites the first time the user writes one. |
| **R3** | 6 | Does the Outputs Value column read the rawfile's one-point plots, or keep the `print` log? | **Both**, with the rule stated on screen: a row whose expression names exactly one vector reads the raw; anything else reads the log. Moving wholesale breaks every expression row a user has typed; keeping the log leaves NOISE, TF and SENS with nowhere to put their answer. |
| **R4** | 2 | Does `ase::state_default` gain any of the new analysis types? | **No.** All 104 committed files carry four rows and `test_ase_core` R1 asserts it. The four-state grid gives discoverability without touching a single bench. **But today this would change by accident, so it must be a decision.** ⚠ R4 costs the user **no reach**: `ase::ui::chana_ok` already appends a row when no row of the selected type exists (hint `:4650-4657`), so picking a type in the grid and pressing OK **is** the add gesture. R4 decides only what a brand-new bench looks like. |
| **R5** | 3 | Reverse recorded decision D4 — should switching the analysis type keep what you typed? | **Reverse.** Cache per-type edits for the dialog's lifetime and commit only the visible type at OK; D4's stated reason ("deterministic, no hidden multi-type writes") is satisfied because nothing is written until OK. Defensible with four types; a trap with twelve. |
| **R6** | after 3 | Do analysis rows gain identity (`id`) — two DC sweeps or two AC sweeps at once? | **Yes**, sequenced after Stage 3 so the addressing lands with the form work. One optional per-row key, absent on all 104 committed files, no schema version. It is the difference between a bench that can say "sweep VIN **and also** sweep temperature" and one that cannot. ⚠ `ase::ui::chana_row` returns the **first** row of a type and `pane_dblclick` discards the index, so the addressing work comes first either way. |
| **R7** | 14 | Do we ship a PSS panel at all, given that it was built and run? | **Yes, last, explicitly experimental**, with the hard validator, the stdout verdict scrape (rc 0 is not success), the last-pair-by-Plotname rule, the transient+FFT cross-check, and the `oscnode` hint. |
| **R8** | 11 | Where does a campaign's configuration live? | **A new top-level `sweep` state key**, in `ase::omit_if_empty` so byte-identity for the 104 committed files is preserved by construction and `version` stays 1. The single named exception to "no new top-level keys". |
| **R9** | 2–14 | The standing label ratification — every new user-facing sentence in this plan. | **Batch per stage.** Twelve analyses otherwise means twelve rounds of asking, which is exactly what the standing preference forbids. |

⚠ **⚖ R11 — THE MINIMUM SUPPORTED NGSPICE — IS NEW (2026-09-10) AND IS FILED LAST OF ALL.** It is
out of the table for the same reason R10 is: it gates **one sentence**, not a stage. The variant
amendment's ship-first item is Stage 16e's release note, and that note splits — its **description**
of what works on which binary is a measured finding and ships with no ruling; only its **support
sentence** (*"what we test and will fix bugs against"*) is R11. An earlier draft had R11 blocking
the whole note while also calling the note the highest-value item that could ship today, which
cannot both be true. **Recommendation C**: the floor is a *capability* floor in the code
(`known 1 && usable 1`) and never a version comparison (**D44**); the promise is prose naming three
*binaries*, not versions. **The real question is not "how old is too old"** — the probe answers that
per binary, and **D43**/**D47** already settle what happens on a binary nobody measured. It is
**"do we promise anything at all?"** `DECISIONS.md` ⚖ R11 carries the options and the trade-off in
full.

⚠ **⚖ R1 IS ANSWERED AND IT LEFT A REQUIREMENT BEHIND.** Its row is kept with its answer rather
than deleted — an answered ruling that disappears takes its reasoning with it, and this one's
reasoning was wrong in a way the batch quotes elsewhere. What the answer obliges every later stage to
hold:

* **Always salvage.** A run that is stopped keeps what it had, wherever the analysis allows it.
  **Stage 6f** is the implementation; the *Salvaging a stopped run* block of §0.1 *Measured facts*
  is the measured basis and `evidence/salvage.md` the dossier.
* **Warn wherever a Stop would still discard work** — which is still most analyses after 6f ships:
  `op`, `noise`, `disto` and the five unmeasured types are all disqualified, and so is any run under
  the eligibility floor. **Stage 2e** is the warning, and 6f does not retire it.
* **A warning is not salvage.** It is what is honest until salvage lands. The plan says that in both
  places on purpose, so a shipped sentence cannot come to stand in for shipped behaviour.
* **`-p` is no longer the price of admission for not losing work.** Where its case is recorded — the
  *Deferred* table, §0.11, Stage 2b, M15 — it is about a non-destructive abort, the no-circuit
  capability probe, and the pre-deck door. Not about a Stop costing you the run.

**The two questions that came before the ruling**, recorded because they are what got the claim
measured: *"In batch mode, is there no way to write what was simulated 'thus far' to disk before
exiting?"* and *"What is the benefit of losing partial results on Stop? Why would one ever want to do
that?"* The first is answered by Stage 6f. The second has an answer and it is **none**: `src/main.c`
installs its signal handlers inside `if (!ft_batchmode)`, so batch installs no handler for any signal
and every one of them is fatal with nothing written. Batch was written for scripted use where nobody
presses Stop. **No benefit is being traded away** — it is an accident of what batch mode was for, and
it is written down here so the next reader does not go hunting for a rationale that does not exist.

⚠ **A tenth, ⚖ R10, is deliberately NOT in this table, and it is still unanswered.** *How far is the
adapter contract formalised* — **A** the working hook plus its documented schema (what Stage 1 builds
anyway), **B** A plus a written adapter-author specification, **C** B plus Stage 15's conformance
harness; recommendation **A**. It is absent from the table because it gates no stage in this pass, not
because it is settled: `DECISIONS.md` ⚖ R10 carries it in full and Stage 15 carries its consequence.
Ask it **last**, after the eight still open above (R1 is answered).

**Look debts** (`owed.sh add look`), each cleared only by the user's eyes on their own display:
Stage 2 (the twelve-cell grid with four states is a new visual language for this window);
Stage 3 (the form triples in size and gains a disclosure);
Stage 5 (the first `resulttable`);
Stage 7 (the options surface is the largest new pane in the plan);
Stage 10 (nets lit on the schematic — a change to the *canvas*, not to ASE-L);
Stage 11 (a histogram).

---

## The ADE-L comparison, and what it rests on

**Every statement about Cadence ADE-L in this plan is recollection, not measurement — no ADE-L was
run for this batch.** They are written as claims a reviewer with a Cadence licence can falsify.
`evidence/ase-ui.md` §6 is where they came from: a fifteen-row behaviour-by-behaviour table against
ADE-L's *Choosing Analyses* form, plus an eight-point §6.1. Walked row by row against the stages:

| # | ADE-L behaviour | answered by |
|---|---|---|
| 1 | every analysis the simulator declares, as a wrapped radio grid | **Stage 2** — and better: four states with reasons, not a list |
| 2 | a per-analysis form that swaps in place | already have it; **Stage 1** makes the destroy exhaustive (`.form`) |
| 3 | Enabled checkbox on the form | already have it |
| 4 | an "Enabled" column in the main list | **— (UX batch).** Today it is a text glyph: no keyboard reach, no undo, and a stray click in a 63 px column silently edits the deck. Not this batch's surface |
| 5 | sweep variable / range / step with a mode selector | **Stage 3a/3b** — and better: the mode selector **relabels its neighbour** |
| 6 | Options… of typed simulator options | **Stage 7** — and better: 220 rows, both catalogues, a live deck preview |
| 7 | Apply | **Stage 3** |
| 8 | per-type form memory across type switches | **Stage 3**, ⚖ **R5** (reverses recorded decision D4) |
| 9 | several analyses of one type | ⚖ **R6**, sequenced after Stage 3 |
| 10 | **list starts empty; holds exactly the analyses you chose** | **NOT ANSWERED HERE.** ⚖ R4's recommendation is to keep `ase::state_default`'s four seeded rows, two of them permanently blank — the opposite of this row. The reason is the 104 committed `.state` files and `test_ase_core` R1; the cost is that a brand-new bench does not look like ADE-L's. ⚠ R4's own trade-off text ("Cadence does not add analyses to your bench either") reads the same fact the *other* way, and both readings are in the batch. **It is the user's ruling; the tension is deliberate and visible** |
| 11 | field-level rejection reported next to the field | **Stage 3c** (`ase::ui::dialog_status`) |
| 12 | unit-bearing typed fields, nothing free text | **Stage 3a** — this is the correctness defect, not a feature |
| 13 | sweep-variable picker from the design | **Stage 3a** via `ase::ui::select_on_design`, already built and hierarchy-aware |
| 14 | analyses run in list order | **deliberately not** — the `op`-last reorder exists for a measured reason (ngspice's forward-sticky save list, issue 0964). Stage 0's comment block says so |
| 15 | the setup travels with the cellview | already true and arguably better: a `.state` view, several per cell |

Nine specific behaviours in this plan are claimed to be **ahead** of ADE-L, each attached to a stage
rather than asserted: a build-absent analysis listed with the flag that would add it (Stage 2); the
four sweep-variable kinds (3a); the relabelling `lin`/`dec` points field (3b); the derived
point-count readout (3c); the computed sensitivity picker (5a — ADE-L *has* `sens`, what it lacks is
the picker); the eight measurement templates (8b); the convergence ladder against an opaque `sim.log`
(Stage 10); Monte Carlo samples as an exportable column (11b); and transient noise as a section of
the transient form (Stage 13). ⚠ **That last one is the weakest of the nine and a reviewer should
check it first** — Spectre has a transient-noise capability, so the defensible claim is about the
*Choosing Analyses form's* surface, not about the simulator's. Rows 4 and 10 above are the two places
this plan does **not** move ASE-L ahead, and they are named rather than omitted.

---

## What this plan refuses, and why

**`libngspice`.** Measured: the DISTO NULL-deref driven through the library **killed the host process
at rc 139** — the SIGSEGV handler is installed only during `ngSpice_Init` and restored before it
returns, and `sens … ac` under KLU and `pss harmonics<2` are in the same class. `ngSpice_Circ` after
`ngSpice_Reset` SEGFAULTs because `Reset` is a full teardown and `ngSpice_Circ` lacks the
`is_initialized` guard `ngSpice_Command` has. `bg_halt` **wedges** on `disto` (1.0095 s,
`Error: Couldn't stop ngspice`) and on `sens`. `--with-ngshared` builds **no `ngspice` binary**, so the
GUI would ship and ABI-pin `libngspice.so.0` and set `SPICE_LIB_DIR`. And `SendStat` emits **nothing at
all** for op, noise, disto, pz, tf and sens, while the `-b` ticker covers all of them. This design's
entire netlist-admissibility layer exists *because* a stale name in an Outputs pane makes ngspice
segfault; linking it into the editor's own address space is the opposite of that.

**A sandboxed, inert-data-only adapter manifest, and any third-party trust model.** The user's
ruling, and it is what makes the adapter contract cheap enough to be worth having: **adapters are
first-party** — Xschem's own agent writes them, they live in this tree, they are reviewed here and
they version with Xschem (§0.10, §1, `DECISIONS.md` **D35**). An adapter is therefore exactly as
trusted as `ase.tcl` itself, and it ships as ordinary Tcl on the existing `ase::register_backend`
hooks. A declarative manifest format — its own parser, its own escaping rules, its own
safe-evaluation story — defends against an adapter from an author nobody here trusts, and there is
no such author. And it would pay for that defence with the three things a descriptor most needs: a
`when` predicate on a plot row (§6b), the `{build <proc>}` emit escape for the two shapes a token
template cannot express (§1c), and a `needs` clause evaluated against `netlist_facts` (Stage 4).
**Revisit when the first adapter arrives from outside this tree** — that is the moment to ask what
an adapter may execute, and the schema written in Stage 1 is what the question would be asked about.
Stage 15's harness is the piece that would have to grow teeth then.

**Conditional logic in the generated deck.** `.control`'s `if` on strings takes the **false** branch for
both `eq` and `ne` (T10). Only the numeric `$sim_status` guard survives. Every decision belongs to the
renderer, in Tcl, where it is testable.

**A free-text option escape hatch on the analysis form.** That is precisely what lies today. Replaced by
typed fields, a typed catalogue, and one *labelled* verbatim `.control` list that actually emits and
says how many lines it is.

**Hiding an analysis the probe could not measure.** Hiding is how the current code lies. A missing
capability key means "not measured", never "no", and the fallback is a source-verified invariant.

**A curated ~120-row option catalogue.** There is **no runtime way to discover a variable's class**, so
a variable omitted from the table is a variable the GUI cannot spell safely — and `interp` (the only
uniform-grid switch), `plainwrite`, `noquotesinoutput` and `keep#branch` are exactly the rows a curator
drops. **The catalogue ships all of both catalogues**, with `inert` and `hidden` columns deciding what
is *offered*. **Curation is a view, not a table.**

**Dead knobs offered as live ones.** Three shapes, §7d. `nosavecurrents` in particular is documented by
the manual §13.7 and the string appears **nowhere** in this tree — it ships as a tombstone row carrying
that sentence, so the next reader does not re-add it from the manual.

**A corner / Monte Carlo engine inside the control language.** Ctrl-C there is timing-dependent — it
either kills one run and continues or discards the whole control block, indistinguishably — and an
interrupted run reports `sim_status = 0`, *indistinguishable from success*.

**Statistics inside the deck.** ngspice has no sort, no median, no percentile, no histogram.

**Any `.step`-shaped promise.** ngspice has none. Everything sweep-shaped is plainly labelled as
generated by the GUI, because when it breaks the user needs to know where to look.

**Three-deep `.dc` nesting, and any sweep target but V / I / resistor / `temp`.** A third triple is
silently dropped; `dctrcurv.c:89-151` accepts exactly those four.

**Offering CIDER as an analysis capability.** It adds no analysis, no dot card and no `SPICEanalysis`;
it is model authoring and belongs in a model editor. What the analyses pane owes it is four things and
no more: **warn** when the netlist has `.model … numd|nbjt|numos` and the probe says CIDER is absent
(ngspice's own message is `could not find a valid modelname`, naming neither CIDER nor the flag);
**never emit `.options klu`** on such a deck (measured `exit(1)`, every later `.control` command
skipped); mark noise/disto/SOA **silently incomplete** and pz **unreliable**; and **budget minutes, not
seconds** — the shipped examples span 0.10 s to **329.5 s**, so the run timeout and the progress UI must
not assume a toy. Also export `CIDER_COM_QUIT=OFF` when driving non-interactively.

**`sens2` and `hb`.** `SEN2info` and `HBinfo` are `extern` declared and defined **nowhere**.

**The `rusage` statistics beyond the four in the run-health strip.** `OPTtbl` carries **29** `IF_ASK`
rows (`cktsopt.c:264-386`), two of them (`temp`, `tnom`) shared with `IF_SET`. Stage 10c surfaces
`rusage devtimes` and `tranpoints accept rejected`, which are the convergence-health metrics
(`evidence/options.md` Table B calls `accept`/`rejected` "the single best convergence-health metric").
The other ~23 — `totiter traniter equations originalnz fillinnz totalnz time loadtime synctime
reordertime factortime solvetime trantime tranloadtime transynctime tranfactortime transolvetime
trantrunctime trancuriters actime acloadtime acsynctime acfactortime acsolvetime` — are per-phase
timers. They are a **profiler, not a simulation setting**, and a GUI that lists them beside `reltol`
teaches the user that they configure something. They are readable at any time with `rusage <name>`,
and APPENDIX §3.1 lists all 29 for whoever wants the "why was that slow" strip later.

**`snsave` / `snload`.** Refused **everywhere in this pass**, not only on a mixed-signal deck as
Stage 12's refusal line might otherwise suggest. They save and reload a converged node set as a
sidecar file; the surface this plan ships for the same need is `wrnodev` + a `.include` row (Stage
3d, Stage 10c), which is one mechanism instead of two and is measured. APPENDIX §9 records them as an
omission of the appendix as well, so neither document claims coverage it does not have.

**`aspice`.** Same shape: a fire-and-forget background launcher whose job the shard runner does with
an exit code per shard and a progress readout. Refused for the same reason the `.control` Monte Carlo
loop is refused — an interrupted run must be distinguishable from a finished one, and `aspice` gives
the GUI nothing to distinguish them with. APPENDIX §9.

**Round-tripping any analysis setting through ngspice.** OP has zero parameters and nothing about a DC
or OP job can be read back. The simulator is asked only what it *can* do, never what it *was told*.
Stage 7f's verification leg asks what took **effect**, which is the opposite direction and is not a
round trip.

**`iplot` and `step`, and `speedcheck` / `deltacheck`.** The first two need
interactive or `-p` mode. ⚠ **`stop` and `resume` came off this list on 2026-09-10**: Stage 6f emits
`stop after` and `resume` inside the rendered `-b` deck, and `stop when` is refused as a checkpoint
primitive on its own merits (**D41.1**) rather than for want of a transport. The last two need `set ngdebug`, which floods the log with per-step traces;
they ship as one line in a run-health strip instead of a pane.

**`ttk::notebook`, a scrolling form, and any modal analysis dialog.** The notebook appears nowhere in
the xschem tree except a comment explaining why it was not used; a scrolling form has no idiom in
`ase_window.tcl` and would need a `Canvas` theming arm; **a modal dialog would hang the headless
suites**. The form fits because `advanced` fields fold and options moved to the options surface.

**A new colour in the locked 9-colour palette.** A `⚠ ` glyph on the label plus the status line does the
job, is theme-proof, and needs no ruling.

**Any analysis capability delivered by putting something on the schematic.** Transient noise uses
`alter` or a generated parallel source; SP ports use `alter portnum`; design variables use
`.param x='var(…)'`.

⚠ **~~A promise of "stop and keep what you have" for a `-b` run.~~ THIS REFUSAL IS WITHDRAWN — it
was wrong.** It used to read: *"No signal handlers are installed in batch: SIGINT is rc 130 with
nothing written. The honest partial-result story is the shard runner, until ⚖ R1 says otherwise."*
The first sentence is true and the conclusion does not follow from it. `stop after` checkpointing
keeps a partial result **in `-b`**, in ASE-L's own deck shape — 60 % of an 80 ms transient survived a
SIGTERM in a file that loads (§0.12, §0.1's *Salvaging a stopped run* block,
`evidence/salvage.md` §3). **Always-salvage is now a requirement of this plan**, given by the user
with ⚖ R1's answer: **Stage 2e** warns wherever a Stop still discards work, **Stage 6f** is the
salvage. The entry is kept visible rather than deleted, because the withdrawn sentence is quoted
elsewhere in the batch. The shard runner keeps its
own reason for existing — every *completed* shard survives and a shard's exit code says which one did
not (Stage 11) — but it is no longer the whole of the partial-result story.

**A VERSION COMPARISON — anywhere, for any purpose.** Added 2026-09-10 (§0.13.3, **D44**).
Stock upstream 47 and the fork both answer `ngspice-46+`, carry a byte-identical 134-row command
and help table, and answer `devhelp` identically; a distribution may backport a fix without moving
the number; 47 is unreleased and still reports 46+. So `>=`, `<`, `package vcompare` and
`string match "4[5-9]*"` against a version string are **wrong today**, before ngspice 48 exists.
The version string may be **displayed and logged**. **A conformance row greps for any ordering
operator taking `version_line` as an operand** — this is enforced, not agreed.

**A VERSION-KEYED HAZARD TABLE.** Same reason plus one more: every hazard in the batch is either
**probeable** (then it is a probe, keyed on the probe's answer) or **universal** (then there is no
key and the mitigation is unconditional). `APPENDIX` §7.5 is the enumeration and it has **zero**
version-keyed rows. A table with one row reading *"all known versions"* is machinery that earns
nothing (**D43**).

**A "BASIC" MODE AND AN "ENHANCED" MODE.** Added 2026-09-10 (§0.13.4, **D45**). The subsets
**overlap without nesting** — the oldest binary has an analysis and five device families the
newest two lack, and the newest two have a command and two code models it lacks — so no binary is
the basic one and a two-mode UI must make a false statement about one axis. There is also no basic
deck to switch *to*: under `fold`, apt 45.2 and the fork produce byte-identical raw files for every
deck shape ASE-L emits. **One ASE-L, N feature gates, zero modes** — which is what the tree already
does, and `ase::cap_altshow_verdict` is the worked example: it withheld tier `d` from apt 45.2 with
no version number anywhere, and was right.

**A PROBE THAT CRASHES THE USER'S SIMULATOR.** Added 2026-09-10 (§0.13.6, **D50**). The
`unset` / `define` / `load` aborts are cleanly probeable and the verdict is a clean file-existence
test — and it is refused anyway, because a deliberate SIGABRT of a dpkg-owned `/usr/bin/ngspice` is
apport's reportable case on the exact platform this work exists for, and what the key buys is
upgrading a *warning* to a *refusal* on two of three binaries while a warning is free. ⚠ **The
invariant that matters is not "put the crash last" — it is "never on the Run path."** If a future
crew wants the refusal, the leg is reachable from the explicit **Detect** button and from nowhere
else, and it obeys the two-marker discipline in **D50**.

**REWRITING A USER'S CONTROL TEXT.** Stage 16b warns, quotes the line and names the remedy. It never
edits what the user typed. Rewriting user text to route around a simulator defect is the failure the
whole variant amendment is trying not to commit — and on a binary where the defect is fixed, the
rewrite is a corruption of a correct line.

**And it refuses to be quick.** Fifteen stages across two files totalling 19,880 lines of Tcl (`ase.tcl` 11,745 + `ase_window.tcl` 8,135, measured today) is not a
weekend, and the sequencing is the deliverable. Stage 0 alone can land this week: it moves no existing
row, mints no sentence, and closes the one defect a user cannot see. Anyone who reads *"make every
analysis reachable"* as *"add eight radio buttons"* will land half of it and produce a window that is
dishonest in eight new ways instead of four old ones.

---

## Sequencing at a glance

| commit | stage | what lands | lines | rulings | suites moved |
|---|---|---|---|---|---|
| 1 | **0** | the silent drop dies; RED-first row asserting today's silence | +55 / −14 | **none** | **0** (4 rows added) |
| 2 | **1** | `ase::analysis_types`; one emitter; eight readers; the `.form` frame; **`requires`/`notes`/`lint` in the contract (1a/1b)** | +360 / −130 | **none** | 6 path lines + 2 display goldens; **D1 must not move** — a descriptor KEY moves no byte |
| 3 | **2** | the probe leg; `analyses_available`; the twelve-cell four-state grid (eleven analyses + the options sheet); the no-adapter status line (2d); **the Stop warning (2e)**; **the variant record + three predicates (2f)**; **leg D (2g)** | +400 / −60 | **R4**, R9 | `test_ase_simcaps_0948` gains rows; **`test_ase_core` RG13 moves**; **the ~12 hand-written capability guards convert in this commit** |
| 4 | **3** | typed fields; `dialog_status`; refuse-at-OK; `x`; Apply; Initial conditions | +620 / −90 | **R5**, R9 | G2, G2b, GE5, `arg_summary` rows |
| 5 | **4** | `netlist_facts`; the `needs` predicates; the non-defeasible DISTO rule | +390 | R9 | new `PF2xx` rows |
| 6 | **5** | `tf`, `pz`, `sens` (dc); the `.sens` picker; `resulttable` | +490 | R9 | new goldens only |
| 7 | **6** | the writer, the sidecar, reconciliation; `noise`, `disto`, `sens` (ac); **checkpointed salvage (6f)**; **the variant mitigations that move a golden (6g)** | +920 / −25 | **R3**, R9 | **every deck golden, once**; optier E5/M1/R2/R4/R6/E17 and cosim RD1–RD11 re-proven; **simreg's six argv rows must NOT move** |
| 8 | **7** | the 220-row catalogue; `opt_line`; the surface; pre-deck; verification; **`rules` may read `caps` (7g)** | +1360 / −120 | **R2**, R9 | simreg A2/B5/B6/B11/B12/D4 — all six — **iff** `-D` is emitted |
| 9 | **8** | `measurements`; `meas` emission; eight templates; `.four`/`fft`/`psd`/`linearize` | +660 | R9 | new suite; Value column rows |
| 10 | **9** | `sp`; the Ports table; the S-parameter surface; `wrs2p` | +440 | R9 | new goldens |
| 11 | **10** | the ladder; `CKTncDump` on the canvas; `optran`; `wrnodev` | +590 | R9 | new suite (**M1 first**) |
| 12 | **11** | campaigns: shards, corners, GUI-drawn MC, `index.tsv`, statistics in Tcl | +1150 | **R8**, R2 | new suite (stand-in simulator) |
| 13 | **12** | `edisplay` + `eprvcd`; the VCD joins `attach_dbs` | +120 | R9 | new goldens (**M9 first**) |
| 14 | **13** | transient noise and `trrandom`, padded, with the seed sentence | +400 | R9 | new goldens |
| 15 | **14** | PSS, experimental, hard validator, stdout verdict | +300 | **R7** | new suite |
| later | **15** | the adapter conformance harness — what the SECOND adapter needs, not the first | +500 | **R10** | none; new suite only |
| any time after 2 | **16** | *"the ngspice you actually have"*: the per-simulator sentence, the pass-through linter, the two co-simulation file checks, `dumpunsound`, the release note | +440 | **R11** (one sentence of it), R9 | **none move**; new suite + three conformance rows |
| later | — | the `-p` transport and the transient debugger | — | **R1 ANSWERED: deferred** | — |

⚠ **Two items of the variant amendment are INDEPENDENT of this table and of each other, and both
should go first** (§0.13, Stage 16e): **(i) the release note's DESCRIPTION half** — zero code, no
ruling, and the single highest-adoption-value item in the amendment, because it turns *"will this
work with my ngspice?"* into a yes; **(ii) the three M-free mitigations** — the `all`-column filter
at the two real seams, the keyword-case lint over the emitter, and the structural test pinning `op`
inside `.control` (6g-2, 6g-4, and 6b's structural row). Small, unconditional, no schema
dependency, and they make every stock binary safer immediately. The one item with a **hard
deadline** is `requires`/`notes`/`lint`, which must land in Stage 1 or it cannot land at all.

**Ship Stage 0 this week.** Stages 1–3 repay themselves: after them, adding an analysis is one registry
entry and the window can no longer report a setting that is not in force. Stages 6 and 8 are the two
that change what a user can *get out of* a run.

### Two orders, and the table above is only one of them

**The stage numbers are the ENGINEERING order.** They are a dependency graph: kill the silent drop
(0), collapse the eight literals into one adapter-owned registry (1), measure what the binary has
(2), stop the form lying (3). Nothing there is negotiable, because each of those is what makes
adding the next analysis one registry entry instead of a ninth copy of the answer.

**The ADOPTION order is a different question, and it is the goal the user actually stated** — Xschem
is being promoted, and it has to support what ngspice offers for usage to take off. Read that way the
stages sort into two groups, and neither group is "whatever comes next in the graph":

* **What decides whether a user can do their job in Xschem at all** — **Stage 8** (measurements:
  getting a *number* back out of a run; `grep -c '\bmeas\b' src/ase.tcl` is **0** today, correction
  C12) and **Stage 11** (sweeps, corners, Monte Carlo). Someone who cannot read a number back and
  cannot sweep does not have a design environment, whatever else the window offers. This is the
  floor, not the ceiling.
* **What makes someone switch** — **Stage 5** (sensitivity: ADE-L *has* `sens`, what it lacks is
  5a's computed picker, and the *ADE-L comparison* section is where that claim is made and can be
  falsified), **Stage 9** (S-parameters, and the Smith chart that goes with them), **Stage 10** (the
  convergence-failure story — `CKTncDump`'s starred nodes lit on the canvas instead of buried in a
  log nobody opens) and **Stage 13** (transient noise — ⚠ the weakest of the nine ahead-of-ADE-L
  claims, and flagged as such where it is made). These are the differentiators.

⚠ **These six must not drift to the tail merely because they sit late in the dependency graph.** The
graph says what has to be **built** first; it says nothing about what is worth **shipping** first,
and the two get confused the moment a table like the one above is read as a schedule. Concretely: a
stage in the 5 / 8 / 9 / 10 / 11 / 13 set that can be brought forward without breaking a dependency
should be brought forward, and one that cannot should say in its receipt what it is waiting on — so
the wait is a decision somebody made rather than an order nobody chose. The one fixed point is
unchanged: **Stage 0 ships first, alone.** It is the only urgent stage, it costs no ruling and it
moves no row.

---

## Still open — the experiment, not the worry

**Three closed outright — M3 (§0.6), M4 (§0.7), M6 (§0.8) — and M2 closed in part**, by the second
build `/usr/bin/ngspice` at ngspice-45.2 (APPENDIX §1.7 `[A-M7]`). The stripped-or-relocated-database
half of M2 survives below as **M15**.

⚠ **One numbering space for the batch: `M1`–`M12` are the design of record's §16, inherited
unchanged; `M13`–`M15` are this pass's additions; and `M16`–`M17` were added on 2026-09-10 by the
adapter pivot** (`LEDGER.md`'s debt table owns their text — they are the two debts the pivot creates
and deliberately does not pay); **`M18` was added later the same day, when ⚖ R1 was answered and
always-salvage became a requirement**; **`M19`–`M21` were added later the same day again by the
variant-support amendment**. **The next free id is M22** — this line read *"M18"* until M18 was
minted and *"M19"* until the variant amendment minted three, and `LEDGER.md`'s debt table is the
one to believe about what is free. An earlier draft
of this table numbered the
multi-raw question `M13`, which collides with the DC-sweep question the APPENDIX numbers `M13`. It is
**M5** here, as it always was in `evidence/design-of-record.md` §16, in `LEDGER.md` and in
APPENDIX §8. `M2'` in APPENDIX §8 is renamed **M15** so no id carries a prime and none is reused.
These remain:

| # | question | blocks | the experiment |
|---|---|---|---|
| **M1** | Can the ladder pane get stdout and stderr as **two ordered streams**? ASE-L folds them with `2>@1` and two `ngdebug` lines carry **no trailing newline** | Stage 10's *live* pane, not the stage | One deliberately non-converging OP through `ase::run_deck`'s existing capture with `set ngdebug`; diff the interleaving against two separate `-o` / `2>` files |
| **M7** | Does `.probe p(XU1)` really yield `xu1:power`, and what are the differential / power vector spellings (`vd_R1`, `mq1:power`)? Documented by the manual §11.6.5, **never verified against source or a run by anyone** | the power column in Outputs | One deck with `.probe p(x1)` and `.probe vd(r1)`; `display` and `write`, then read the names |
| **M8** | Does `set interp` change a **complex** AC plot and a **nested DC** sweep correctly? Measured only on a real transient (21 points from `tran 1u 20u`) | Stage 3 ships `native`/`linearize` safely; the `interp` arm wants this | Three decks, `length()` and a spot value before and after |
| **M9** | Does the `eprvcd` VCD attach cleanly through `ase::attach_dbs` **alongside** a rawfile, and does the digital pane label the nodes with their ngspice names? | Stage 12's whole claim | Drive the measured `adc_bridge → d_inverter → dac_bridge` deck through a real ASE-L session with the VCD in `vcdfiles` |
| **M10** | `Nintegrate()`'s definition was never located, so nobody can explain an `onoise_total` number to a user | a tooltip, not a stage | `grep -rn "Nintegrate" src/` in the ngspice tree, then read |
| **M11** | Does `alterparam` + `reset` preserve `.options` and `set` variables across the re-parse, and does it re-read `<rundir>/.spiceinit`? | Stage 11's collapse-into-one-shard mode | One deck: `option reltol=0.05`, `alterparam`, `reset`, then `option` — Stage 7f's reader gives the diff for free |
| **M12** | What does `wrs2p` emit for an `sp` run with the `.csparam Rbase=50` workaround, and is it valid Touchstone? | Stage 9's export | One two-port deck, `wrs2p out.s2p`, open it in any Touchstone reader |
| **M5** | A **multi-raw family** (one raw per shard) is new to the waveform viewer and to the Calculator, whose spec says v1 handles only the single-raw multi-dataset case | Stage 11's family-of-curves display | Not an experiment — a conversation with `doc/claude/specs/calculator.md`'s owner, **at Stage 11** |
| **M13** | The **DC-sweep + auto-bridge failure** has a reproducer and no root cause | blocks offering `dc` on a mixed-signal deck as `ok` rather than `caution` — Stage 12 ships a **permanent** caution until this closes | `evidence/xspice.md` §12.1/§12.2 has the reproducer; someone must debug it |
| **M14** | Why does `help devhelp` print **nothing at all** — neither a help line nor `Sorry, no help for …`? | nothing. It matters only as *"never probe with `devhelp`"*, which is already Stage 2's rule | not worth an experiment; recorded so nobody re-hunts it |
| **M15** | Does `help <verb>` answer correctly on a build with a **relocated or stripped** help database? `[A-M7]` covers a second build but **both had their database** | nothing blocks — but Stage 2's whole gate rests on the `help <verb>` probe, so this is the gate's one unmeasured failure mode | the same probe against a third build, cross-checked against `devhelp`'s families. Publish only on a clean parse. ⚠ **Stage 2b's Detect leg is the cheaper half**: the command table is a second oracle that needs no help database, and *a disagreement between the two legs is itself the M15 signal* — it needs `-p` (§0.11), and ⚖ R1 has decided — **deferred with the transport** — so M15 stays open through this batch and Stage 2 ships the `help <verb>` leg alone, saying so |
| **M16** | **The adapter-author specification is not written, and will not be** — the schema is defined by the ngspice adapter that exercises it and by Stage 15's harness | nothing, while adapters are first-party. It becomes the whole cost of onboarding the first outside author, and nothing in the tree announces it | not an experiment. Write it **when a second adapter is actually wanted**, never speculatively. ⚖ R10's **option B**, left standing on purpose (`LEDGER.md` owns the row) |
| **M18** *(new 2026-09-10, with ⚖ R1's answer)* | **The warning ships before the salvage does.** Stage **2e**'s sentence costs nothing and lands early; the checkpoint loop that makes it untrue is Stage **6f**. Between those two commits ASE-L is **honest and still lossy** | nothing — it gates no stage. It is a debt to the **user**, and the only one on this list a person feels: someone who reads the sentence and stops a ten-minute run has still lost ten minutes | not an experiment. **Stage 6f landing discharges it**, and on that commit 2e's sentence is replaced by the two numbers §5.2 of the dossier makes computable. ⚠ **A residue survives 6f and is permanent, not transitional** — `op`, `noise`, `disto` and the five unmeasured types keep the un-checkpointed sentence for good, and it must be worded as a final answer rather than as a promise (`LEDGER.md` owns the row) |
| **M19** *(new 2026-09-10, the variant amendment)* | **The other ~33 category-(b) fork fixes were never individually assessed for probeability.** Two of them turned out to be probeable in a deck that was already running (`one_vector_write`, and `gnd_literal`/`keyword_case` as one-line riders), which overturns *"the fork's fixes have no probe"* as a blanket statement — **but three probes is not a survey** | nothing. It bounds how much of the fork/stock gap ASE-L can measure rather than warn about | a pass over the 35 category-(b) commits of `evidence/fork-dependencies.md` §3 asking, for each, *"does this defect land in a file?"*. Those that do are probeable in the same one extra process (**D49**) |
| **M20** *(new 2026-09-10, the variant amendment)* | **The known-0 leg of the build-flag probes is unmeasured.** Every binary on this machine has XSPICE, OSDI, RFSPICE and KLU, so `flags` is proven only in its **positive** direction | nothing today; it becomes real the first time a user registers a stripped build and ASE-L has to say *"this one lacks X"* rather than *"this one has X"* | one `../configure --disable-xspice --disable-osdi --disable-klu --disable-sp && make -j8`, ~2 min on the evidence of the 99-second stock-47 build (§0.1's three-binary table) |
| **M21** *(new 2026-09-10, the variant amendment)* | **The `casemodewrite` spec/code divergence is untouched**: the shipped spec asserts ASE-L emits `-D casemodewrite` alongside any non-`fold` mode and the code does not, so **no ASE-L run produces a self-describing raw even on the fork** | nothing in this plan — but the crew that builds Stage 16 will read that spec and find it describing behaviour that does not exist | not an experiment; a one-line reconciliation of the spec against the code, by whoever owns that spec. `evidence/fork-features.md` §11 has the measurement |
| **M17** | The schema will have been validated against **exactly one implementation plus one paper exercise** — ngspice, and Stage 1e's Xyce descriptor. A paper exercise finds the keys that cannot express a second simulator; it cannot find the ones that express it *wrongly*, because nothing runs | every stage after 1 adds registry content assuming the schema holds. If it does not, the cost is paid across Stages 2–14 instead of at Stage 1 | not an experiment either: **a real second adapter, against a real binary, through Stage 15's harness.** A third paper exercise buys much less than the second one did (`LEDGER.md` owns the row) |

---

## One upstream bug this plan found, and the patch shape

**`.disto` dereferences a plot handle it never checked.** `distoan.c` calls
`SPfrontEnd->OUTpBeginPlot` at `:516`, `:540`, `:563`, `:584` and `:606` and **discards the return at
every one of them**, then passes the handle to `CKTacDump`. When the save list resolves to nothing the
plot is never created and the process dies with SIGSEGV. Reproduced this session on **two independent
builds** — `ngspice-46-419-gccebdf2a2` and released **`ngspice-45.2`** — from a four-line deck:

```
disto probe deck
v1 in 0 dc 1 ac 1 distof1 1
r1 in mid 1k
r2 mid 0 1k
.control
save v(nosuchnode)
disto dec 2 1k 10k
op
.endc
.end
```

`acan.c` has the fix pattern in the same tree: `error = SPfrontEnd->OUTpBeginPlot(…); if (error)
return(error);`. Five sites, one line each. File it against ngspice with the deck above; it blocks no
stage here, because the GUI-side mitigation (Stage 4d) is required either way — a user's ngspice will
be 45.2 or 46 for years.
