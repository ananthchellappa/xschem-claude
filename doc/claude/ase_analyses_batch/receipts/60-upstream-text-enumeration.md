# 60 — the upstream-text enumeration: the 53 transcribed help strings and the 15 capturable plot names

**Task:** read-only. Two enumerated lists, verbatim, so the driver can mint handles for the class
the user ruled *listed but not ratified* on 2026-09-16 (ngspice's own words, transcribed — the
`R9-276` precedent). Two prior passes established the **classes** and never wrote down the
**strings**. This receipt is the strings.

**Both splits re-derived from scratch and both MATCH.**

* **Deliverable A: 60 distinct help strings on the options sheet → 53 UPSTREAM / 7 ASE-L.** Matched.
* **Deliverable B: 18 distinct `select` literals over 21 plot rows → 15 capturable / 3 `role opinfo`.**
  Matched.
* **All 7 ASE-L-authored help strings are handled.** Receipt 59's "all 7 already carry handles" is
  **CONFIRMED** — and the brief's caution was right: only **4** of the 7 live in the catalogue-prose
  section. The other three are `R9-235`, `R9-670`, `R9-199`.
* **The opinfo three: `NOISE Operating Point` = 1 (`R9-276`), `AC Operating Point` = 0,
  `Distortion Operating Point` = 0.** Confirmed exactly as 59c measured.

⚠ **One premise in receipt 59 §5 is refuted, and it does not move the numbers.** It says *"the
options sheet renders a `help` sentence for every catalogue row."* It does not: **180 of the 247
rows carry no `help` key at all.** 67 rows carry one, and those 67 collapse to the 60 distinct
strings. The 53/7 split is right; the sentence under it is wrong, and a driver quoting it in a
handle's *Where:* line would be writing a false claim about the surface.

---

## VERDICT TABLE

| # | question | answer |
|---|---|---|
| 1 | distinct help strings reaching the options sheet | **60** |
| 2 | of those, ngspice's own text | **53** — every one resolving in `cktsopt.c` |
| 3 | of those, ASE-L's own wording | **7** |
| 4 | my split vs receipt 59's 53/7 | **MATCHED**, re-derived not carried |
| 5 | are all 7 ASE-L strings handled? | **YES — 7 of 7**, handles named in §A3 |
| 6 | do all 7 handles live in the catalogue-prose section? | **NO — 4 of 7.** `R9-235`/`R9-199` are in the detail-line section, `R9-670` in the issue-1467 section |
| 7 | distinct `select` literals in the live contract | **18** (11 types, 21 plot rows) |
| 8 | capturable / `role opinfo` | **15 / 3** |
| 9 | of the 15, how many carry an exact doc entry | **0 of 15** |
| 10 | the opinfo three's exact-entry status | **1 / 0 / 0** |
| 11 | catalogue rows carrying NO help string | **180 of 247** — receipt 59 §5's premise refuted |

---

## 1 — Method, and where each number comes from

**The domains are live, not grepped.** One headless probe
(`./src/xschem --nogui --pipe -q --nolog --script probe60.tcl`, rc 0, positive `PROBE DONE`
sentinel asserted rather than a FAIL-absence check) drove the shipped readers:

| what | how | result |
|---|---|---|
| Deliverable A domain | `ase::sim_option_names ngspice` → `ase::opt_help ngspice $n` per row | **247 rows**, 67 with help, **60 distinct** |
| Deliverable B domain | `ase::analysis_types ngspice`, then each type's `plots` rows | **11 types, 21 plot rows, 18 distinct `select`** |
| capturable split | `ase::plot_capturable $p`, the shipped proc, per row | **16 capturable rows / 5 opinfo rows** → 15 / 3 distinct |

Those figures reproduce 59c's live-contract numbers (11 / 21 / 18 / 15 / 3) **independently**.

**Authorship is a text fact, so it is grepped** — `/usr/bin/grep -rlF <string>
/home/analog/dev/ngspice/src/`, one call per distinct string, never the bare `grep`. A string with
≥1 hit is UPSTREAM; zero hits is ASE-L. No `ngspice` binary was invoked.

**Doc matching is against the CURRENT committed document.** `R9_COPY_REVIEW.md` is now **751
handles / 751 fenced `text` blocks** — receipt 59 matched against 733 and 59c against a dirty
buffer; HEAD has since moved to `f007fb03` *"22 handles for copy that was on screen with no name"*
and `git status` shows **no modified tracked files**. So this pass's matching is against committed
content. **A later reader should re-extract rather than trust these handle numbers**, for exactly
the reason receipt 59 §1 gives.

Matching is reported at three strengths, because receipt 59 §7c's lesson is that string equality
under-counts: **EXACT** (normalised block equality), **folded** (case + trailing colon), and
**occurrences anywhere in the document including prose**. The third is what separates *"handled"*
from *"mentioned inside another handle's sentence"*, and it is the distinction the opinfo three
turn on.

### The one rendering surface, named precisely

`ase::opt_help` has exactly **two** callers in the whole tree:

* `ase_window.tcl` `ase::ui::optsheet_detail` — `set h [ase::opt_help $sim $name]` then
  `lappend bits $h`, joined with `  |  ` into `$w.detail configure -text`. **This is the surface:
  the leading segment of the detail line under the options grid, for the selected row.**
* `ase.tcl` `ase::opt_match` — the sheet's search, which reads help as a *haystack*. Not a render.

**Reachability of all 247 rows is settled in the source, not assumed.** `ase::opt_in_scope` returns
1 unconditionally unless the scope is `{analysis …}`, and its own header states the design:
*"the global surface answers 1 for every row in the catalogue."* So every help-carrying row is
selectable on the global sheet and its help renders on selection. That is why the brief's
"visibility already settled" holds — but note it is **per selected row**, not a sheet-wide render.

---

## DELIVERABLE A — the 60 distinct option-help strings

Order is first appearance in the catalogue. **Carriers** are the option rows sharing the string
(`|`-separated). **Class** is measured by the authorship grep. **All 53 UPSTREAM strings resolve in
`src/spicelib/analysis/cktsopt.c`** — 53 of 53, which is stronger than receipt 59's
*"overwhelmingly"*; per-string extra hits are noted after the table.

| # | carriers | class | resolving ngspice file | help string (verbatim) |
|---|---|---|---|---|
| 1 | `absdv` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Maximum absolute iter-iter node voltage change` |
| 2 | `abstol`, `lteabstol` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Absolute error tolerence` |
| 3 | `autopartial` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Use auto-partial computation for all models` |
| 4 | `badmos3` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `use old mos3 model (discontinuous with respect to kappa)` |
| 5 | `bypass` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Allow bypass of unchanging elements` |
| 6 | `chgtol` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Charge error tolerence` |
| 7 | `convabsstep` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Absolute step allowed by code model inputs between iterations` |
| 8 | `convlimit` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Enable convergence assistance on code models` |
| 9 | `convstep` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Fractional step allowed by code model inputs between iterations` |
| 10 | `copynodesets` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Copy nodesets from device terminals to internal nodes` |
| 11 | `cshunt` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Shunt capacitor from analog nodes to ground` |
| 12 | `defad` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Default MOSfet area of drain` |
| 13 | `defas` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Default MOSfet area of source` |
| 14 | `defl` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Default MOSfet length` |
| 15 | `defm` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Default MOSfet Multiplier` |
| 16 | `defw` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Default MOSfet width` |
| 17 | `epsmin` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Minimum value for log` |
| **18** | `filetype` | **ASE-L** | — | `output file format for CIDER's own device dumps` |
| 19 | `gmin` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Minimum conductance` |
| 20 | `gminfactor` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `factor per Gmin step` |
| 21 | `gminsteps` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `number of Gmin steps` |
| 22 | `gshunt` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Shunt conductance` |
| 23 | `indverbosity` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Control Inductive Systems Check (coupling)` |
| 24 | `itl1` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `DC iteration limit` |
| 25 | `itl2` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `DC transfer curve iteration limit` |
| 26 | `itl4` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Upper transient iteration limit` |
| 27 | `itl6`, `srcsteps` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `number of source steps` |
| 28 | `keepopinfo` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Record operating point for each small-signal analysis` |
| 29 | `klu` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Set KLU as Direct Linear Solver` |
| 30 | `klu_memgrow_factor` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `KLU Memory Grow Factor (default is 1.2)` |
| 31 | `ltereltol`, `reltol` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Relative error tolerence` |
| 32 | `ltetrtol`, `trtol` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Truncation error overestimation factor` |
| 33 | `maxevtiter` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Maximum event iterations at analysis point` |
| 34 | `maxopalter` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Maximum analog/event alternations in DCOP` |
| 35 | `maxord` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Maximum integration order` |
| 36 | `method` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Integration method` |
| 37 | `minbreak` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Minimum time between breakpoints` |
| 38 | `newtrunc` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `voltage controlled truncation` |
| 39 | `nodedamping` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Limit iteration to iteration node voltage change` |
| 40 | `noopac` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `No op calculation in ac if circuit is linear` |
| 41 | `noopalter` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Do not do analog/event alternation in DCOP` |
| 42 | `noopiter` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Go directly to gmin stepping` |
| **43** | `notrnoise` | **ASE-L** | — | `switch off transient noise: white and 1/f noise always, RTS noise only where its noise timestep is above 0; random sources keep running` |
| 44 | `oldlimit` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `use SPICE2 MOSfet limiting` |
| 45 | `pivrel` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Minimum acceptable ratio of pivot` |
| 46 | `pivtol` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Minimum acceptable pivot` |
| 47 | `ramptime` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Transient analysis supply ramping time` |
| 48 | `reldv` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Maximum relative iter-iter node voltage change` |
| 49 | `rshunt` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Shunt resistance from analog nodes to ground` |
| **50** | `savecurrents`, `savecurrents_bsim3`, `savecurrents_bsim4`, `savecurrents_mos1` | **ASE-L** | — | `add .save lines for every device terminal current` |
| **51** | `seed` | **ASE-L** | — | `seed for the random number generator; a number, or the word random` |
| **52** | `seedinfo` | **ASE-L** | — | `print the seed value the random number generator was given` |
| **53** | `soa_log` | **ASE-L** | — | `file for SOA warnings; pairs with the warn option, which has a different door` |
| 54 | `sparse` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Set SPARSE 1.3 as Direct Linear Solver` |
| 55 | `temp` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Operating temperature` |
| 56 | `tnom` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` † | `Nominal temperature` |
| 57 | `trytocompact` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Try compaction for LTRA lines` |
| **58** | `units` | **ASE-L** | — | `angle unit for vp() and ph(). RADIANS by default -- a phase margin computed without it is wrong by 57.2958x` |
| 59 | `vntol` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Voltage error tolerence` |
| 60 | `xmu` | UPSTREAM | `src/spicelib/analysis/cktsopt.c` | `Coefficient for trapezoidal method` |

† `tnom`'s `Nominal temperature` is the one UPSTREAM string that is **not distinctive to
`cktsopt.c`** — it also appears in many device files (`src/spicelib/devices/hisimhv1/hsmhv.c` and
others). It does resolve in `cktsopt.c`, so the class is unchanged; it is flagged because a handle
citing a single line for it would be citing one of dozens.

**Several of the 53 also appear in `src/ngspice.txt`** (the shipped manual text) — e.g. rows 29
(`Set KLU as Direct Linear Solver`) and 12/13 (`Default MOSfet area of …`). That is corroboration
of upstream authorship, not a competing origin.

### A2 — arithmetic, so the table can be checked rather than believed

```
catalogue rows (ase::sim_option_names ngspice)   247
  rows with an EMPTY help key                    180
  rows with a help string                         67
distinct help strings                             60
  55 strings carried by 1 row   = 55 rows
   4 strings carried by 2 rows  =  8 rows   (abstol/lteabstol, itl6/srcsteps,
                                             ltereltol/reltol, ltetrtol/trtol)
   1 string  carried by 4 rows  =  4 rows   (the savecurrents family)
                                   ------
                                     67 ✓
authorship: 53 UPSTREAM + 7 ASE-L = 60 ✓
```

### A3 — ⚠ THE 7 ASE-L STRINGS: ALL SEVEN ARE HANDLED, AND THREE HANDLES ARE NOT WHERE 59 IMPLIED

Receipt 59's *"all 7 already carry handles"* is **confirmed by exact fenced-block equality** — not
substring, not keyword. Each of the 7 matched **exactly one** block, and each occurs exactly **once**
in the whole document, so there is no ambiguity:

| # | option row(s) | handle | kind | the section the handle lives in |
|---|---|---|---|---|
| 1 | `filetype` | **R9-235** | label | *Simulation > Options… — the detail line under the grid* |
| 2 | `notrnoise` | **R9-670** | help | *Issue 1467 — the noise section on the Tran form (stage 13, the GUI half)* |
| 3 | `savecurrents` ×4 | **R9-255** | label | *Simulation > Options… — catalogue prose (the per-option help text)* |
| 4 | `seed` | **R9-256** | label | *…catalogue prose* |
| 5 | `seedinfo` | **R9-257** | label | *…catalogue prose* |
| 6 | `soa_log` | **R9-258** | label | *…catalogue prose* |
| 7 | `units` | **R9-199** | advice | *Simulation > Options… — the detail line under the grid* |

**The brief's caution is upheld on both counts.**

* **`R9-254` is NOT a help string.** It is the catalogue `inert` **reason** for `ramptime`
  (*"the live code is inside #ifdef XSPICE_EXP…"*), delivered through
  `"ase: option '$name' does nothing in this build: $reason"` and the delivery report. `ramptime`'s
  actual *help* string is row 47 above, `Transient analysis supply ramping time`, which is
  **UPSTREAM**. So the *"catalogue prose"* section's 5 handles are **4 help strings + 1 inert
  reason**, and receipt 59's *"the five handles it does give this section"* conflates them.
* **Only 4 of the 7 live in that section.** `R9-235` and `R9-199` are in the detail-line section
  and `R9-670` is in a stage-13 section. A driver looking for the 7 in one place will find 4 and
  wrongly conclude three are unhandled.

**Consequence for the driver: nothing to mint on the ASE-L half of this surface.** The 53 are the
whole of the listing work here.

---

## DELIVERABLE B — the 18 distinct `select` literals

From the live contract: **11 types** (`op dc ac tran noise tf pz sens disto sp pss`), **21 plot
rows**, **18 distinct `select` literals**. `pss` carries **no `plots` key at all** — it is the
eleventh type and contributes zero rows, which is why 11 types give 21 rows.

21 rows → 18 distinct because three literals are carried twice: `Sensitivity Analysis`
(`sens` dc arm + ac arm — the *"two analyses, one Plotname"* trap from the brief's trap table),
`AC Operating Point` (`ac` + `sp`), `Distortion Operating Point` (`pz` + `disto`).

### B1 — the 15 capturable (`ase::plot_capturable` = 1)

**Every one carries ZERO exact doc entries.** `role`/`results` are the contract's own keys, kept
because they are what makes the capturable/opinfo split checkable.

| # | `select` literal (verbatim) | type(s) · row | role / results | resolving ngspice file | exact doc entries |
|---|---|---|---|---|---|
| 1 | `Operating Point` | `op` r1 | scalars / value | `src/spicelib/parser/inp2dot.c:141` | **0** (11 prose occurrences) |
| 2 | `DC transfer characteristic` | `dc` r1 | sweep / viewer | `src/spicelib/parser/inp2dot.c:303` | **0** (0 occurrences) |
| 3 | `AC Analysis` | `ac` r1 | sweep / viewer | `src/spicelib/parser/inp2dot.c:203` | **0** (1 occurrence) |
| 4 | `Transient Analysis` | `tran` r1 | sweep / viewer | `src/spicelib/parser/inp2dot.c:429` | **0** (1 occurrence) |
| 5 | `Integrated Noise*` | `noise` r1 | scalars / value | `src/spicelib/analysis/noisesp.c:356`, `noisean.c:535` | **0** (0 occurrences) |
| 6 | `Noise Spectral Density Curves*` | `noise` r2 | sweep / viewer | `src/spicelib/analysis/noisesp.c:188`, `noisean.c:278` | **0** (0 occurrences) |
| 7 | `Transfer Function` | `tf` r1 | scalars / value | `src/spicelib/parser/inp2dot.c:368` | **0** (0 occurrences) |
| 8 | `Pole-Zero Analysis` | `pz` r1 | table / table | `src/spicelib/parser/inp2dot.c:265` | **0** (0 occurrences) |
| 9 | `Sensitivity Analysis` | `sens` r1 **and** r2 | table/table · sweep/viewer | `src/spicelib/parser/inp2dot.c:485` | **0** (4 prose occurrences) |
| 10 | `DISTORTION - 3rd harmonic` | `disto` r1 | sweep / viewer | `src/spicelib/analysis/distoan.c:541` | **0** (0 occurrences) |
| 11 | `DISTORTION - 2nd harmonic` | `disto` r2 | sweep / viewer | `src/spicelib/analysis/distoan.c:517` | **0** (0 occurrences) |
| 12 | `DISTORTION - IM: 2f1-f2` | `disto` r3 | sweep / viewer | `src/spicelib/analysis/distoan.c:607` | **0** (0 occurrences) |
| 13 | `DISTORTION - IM: f1-f2` | `disto` r4 | sweep / viewer | `src/spicelib/analysis/distoan.c:585` | **0** (0 occurrences) |
| 14 | `DISTORTION - IM: f1+f2` | `disto` r5 | sweep / viewer | `src/spicelib/analysis/distoan.c:564` | **0** (0 occurrences) |
| 15 | `SP Analysis` | `sp` r1 | sweep / viewer | `src/spicelib/parser/inp2dot.c:736` | **0** (0 occurrences) |

**This confirms the brief's list of 15 exactly** — same fifteen strings, same order of derivation,
independently obtained from the contract rather than copied.

⚠ **A path correction to 59c, which named `inp2dot.c` without a directory.** It is
**`src/spicelib/parser/inp2dot.c`**, not `src/frontend/inp2dot.c` — the eight job-name literals are
created by the parser at `IFC(newAnalysis, (ckt, which, "<name>", &foo, task))`, one call per dot
card. `src/frontend/inp2dot.c` **does not exist**; a handle citing that path would not resolve.

### B2 — ⚠ THE TWO STARRED LITERALS: THE `*` IS ASE-L'S, AND NOW THERE IS A MECHANISM FOR WHY

59c's fact is **preserved, not re-litigated**: the trailing `*` **is part of the literal**, it is a
glob, and the two strings must be listed with the asterisk. My grep confirms the asterisked form is
absent from ngspice (`-rlF 'Integrated Noise*'` → **0 files**) while the bare form resolves
(→ `noisesp.c`, `noisean.c`).

**What is new is the reason the glob exists, and the driver needs it to write the `Where:` line
honestly.** ngspice emits one of **two** names per plot, chosen by a ternary on whether units are
being reported:

```c
src/spicelib/analysis/noisesp.c:355-356    ? "Integrated Noise - V^2 or A^2"
                                           : "Integrated Noise",
src/spicelib/analysis/noisesp.c:186-188    ? "Noise Spectral Density Curves - (V^2 or A^2)/Hz"
                                           : "Noise Spectral Density Curves",
```

(the same pair again in `noisean.c:534-535` and `:276-278`). **The glob is there to match both
ngspice spellings.** So these two are the only literals in the list whose on-screen form contains a
character ngspice never wrote — *ngspice's words plus one ASE-L metacharacter*. They still belong in
the upstream-text class, but a handle that says "ngspice's own text, verbatim" is very slightly
wrong for exactly these two, and saying "ngspice's plot name, with ASE-L's trailing glob" costs
nothing.

### B3 — ⚠ THE 3 `role opinfo` LITERALS, REPORTED SEPARATELY AS INSTRUCTED

`ase::plot_capturable` returns 0 for these, so they never reach the mislabel arm; they reach the
user through the run log's *"also computes"* sentence instead.

| `select` literal | carried by | resolving ngspice file | **exact doc entry** | occurrences anywhere |
|---|---|---|---|---|
| `NOISE Operating Point` | `noise` r3 | `src/spicelib/analysis/noisean.c:226` | **1 — `R9-276`** | 1 |
| `AC Operating Point` | `ac` r2, `sp` r2 | `src/spicelib/analysis/acan.c:158`, `span.c:479` | **0** | 3 |
| `Distortion Operating Point` | `pz` r2, `disto` r6 | `src/spicelib/analysis/pzan.c:58`, `distoan.c:107` | **0** | 2 |

**59c's measurement is confirmed to the digit: 1 / 0 / 0.** And its characterisation is confirmed
too — the two unratified ones are *named only inside another handle's prose*, which I verified by
reading the hits rather than counting them:

* `AC Operating Point`'s three occurrences are `R9-274`'s fenced sentence body (`doc:4590`, where it
  is the *frame* `'[join $unames …]'`), `R9-275`'s *For:* line (`:4595`), its *Note:* rendered
  example (`:4597`), and `R9-276`'s *Note:* (`:4694`).
* `Distortion Operating Point`'s two are `R9-275`'s *Note:* (`:4597`) and `R9-276`'s *Note:*
  (`:4694`) — the latter reading *"`disto` adds 'Distortion Operating Point' to the same sentence,
  which `pz` already contributed."*

⚠ **So the document already states, in `R9-276`'s own Note, that two more plot names reach that
sentence — and neither got an entry.** `R9-276` is simultaneously the precedent for listing this
class and the place where two members of it were mentioned and skipped. **That is the driver's
answer to whether the opinfo two belong in this listing: the document has already committed to the
principle, and left the instances out.**

### B4 — the `Integrated Noise` trap, preserved

59c's caution is confirmed exactly. `Integrated Noise` **unstarred** has **4** substring hits in the
document (`doc:180`, `:186`, `:1657`, `:3111`), and I read all four: every one is **caution prose
about the plot not being created for a 1-point linear noise sweep** (two inside a quoted ruling
block, two inside `*Note:*` text on the `lin_points` caution). **None is the select literal.**
`Integrated Noise*` is correctly **0**, and `Noise Spectral Density` has **0** occurrences in any
form. Counted unhandled, as 59c had it.

---

## 2 — The re-derived splits, stated plainly

**Deliverable A: 53 UPSTREAM / 7 ASE-L. This MATCHES receipt 59's 53/7.** Re-derived from the live
catalogue and a fresh per-string grep; not carried from either receipt. The brief asked for a loud
statement if it were not 53/7 — **it is.** Two things I would have missed by carrying it forward:
the 180 help-less rows, and the fact that 53/53 resolve in `cktsopt.c` rather than
"overwhelmingly".

**Deliverable B: 18 distinct / 15 capturable / 3 opinfo, over 11 types and 21 plot rows. This
MATCHES 59c.** My raw script printed 19 distinct — the nineteenth is **my own `NOPLOTSKEY`
sentinel** written for `pss`, which carries no `plots` key. I am naming that rather than quietly
subtracting it, because an unexplained 19 in a corner of the batch that has already shipped two
confident wrong numbers is precisely what the brief warned about.

---

## 3 — What I could NOT establish

1. **Whether the 53 should be handled per string or as a class.** Not mine to decide. The
   enumeration is here; the minting policy is the driver's and the ratification is the user's.
2. **Whether the two starred literals count as "transcribed" for the user's ruling.** §B2 gives the
   mechanism and the defect in the "verbatim" phrasing; the classification call is the driver's.
3. **Whether any of the 53 reaches a second surface.** I established the *rendering* surface
   (`optsheet_detail`'s detail line) and the *search* consumer (`opt_match`). I did **not** survey
   for a help string appearing in a tooltip, an export, a deck comment or the run log. `opt_help`
   has only two callers, so any such appearance would be a second literal rather than this one —
   out of this task's scope, but not proven absent.
4. **The 180 help-less rows are not a finding I chased.** Whether a row with no help is a gap worth
   a handle-less defect note is the driver's call; I report the count only because it refutes
   receipt 59 §5's premise.
5. **No rendering of the 15 plot names was attempted.** 59c already proved their visibility by
   driving `ase::reconcile_plots` and emitting one of them into a run-log sentence; the brief told
   me visibility was settled and to enumerate. I relied on 59c for that one fact and re-derived
   everything else. **It is the single inherited claim in this receipt**, and it is the load-bearing
   one for the whole of Deliverable B — a reader who doubts it should re-run 59c's `probe_c4.tcl`
   rather than trust this sentence.

---

## 4 — Debts to report upward — nothing filed, nothing cleared, by me

* ⚖ **rule** — the **53** transcribed help strings and the **15** capturable plot names are the
  enumeration behind the user's 2026-09-16 ruling. 59c's advice holds and this pass strengthens it:
  **one class, one ruling** — they resolve to the same tree, by the same grep, under the same
  `R9-276` precedent.
* ⚖ **rule** — **`AC Operating Point` and `Distortion Operating Point` are unratified** and the
  document's own `R9-276` Note already names them (§B3). The driver needs to decide whether the
  listing covers the opinfo two; my measurement says the principle is already conceded in writing.
* **Nothing to mint for the 7 ASE-L help strings** — all 7 handled (§A3). This closes receipt 59's
  open question on that half.
* **A documentation defect, not a ruling** — receipt 59 §5's *"renders a `help` sentence for every
  catalogue row"* (180 of 247 carry none) and its *"five handles it does give this section"*
  (4 help + 1 inert reason). Both would propagate into a handle's `Where:` line if quoted.
* **A citation defect, not a ruling** — 59c's bare `inp2dot.c`. The file is
  `src/spicelib/parser/inp2dot.c`; `src/frontend/inp2dot.c` does not exist.
* **No `look` debt.** Nothing in this pass changed a pixel, and nothing in it needs eyes: both
  deliverables are text.
* **Nothing written to the owed ledger**, per the brief.

---

## 5 — Hygiene

* **Read-only on the tree.** `R9_COPY_REVIEW.md`, `LEDGER.md`, `src/` and the suites were **not**
  edited. **The only file I created is this receipt.**
  ⚠ **And unlike receipts 59 and 59c, `git status --porcelain -uall` shows NO modified tracked
  files** — only the five pre-existing untracked entries (`.xschem/op_param_lists.conf`, the two
  `rdw_*_batch` dirs' files, the `debug_st1` state). HEAD has moved to **`f007fb03`** *"docs(R9): 22
  handles for copy that was on screen with no name"*, so the driver's concurrent edits that both
  prior receipts had to disclose are now **committed**. My 751-handle extraction is therefore
  against committed content, which is a stronger footing than either prior pass had.
* **No git mutation** of any kind — no `add`, `commit`, `checkout`, `restore`, `stash`, `clean`,
  `push`.
* **`tests/run_regression.tcl` was not run** (issue 0990 — the driver runs T1 solo).
* **No simulation. `/usr/bin/ngspice` was never invoked, nor any other ngspice binary.** The ngspice
  tree at `/home/analog/dev/ngspice` was **read** with `/usr/bin/grep` only, to settle authorship —
  a text fact, per the brief. No deck was written or run; nothing under `sky130A/` was touched.
* **`/usr/bin/grep` throughout, never the bare `grep`** (it is a function routing to ugrep and
  answers differently).
* **Nothing under `~/.xschem/` was read-modify-written or touched**; `$HOME/.spiceinit` untouched.
* **The binary was given a path** — `./src/xschem --nogui --pipe -q --nolog --script …`, one launch,
  rc 0. Never a bare `xschem`; **`--nolog`, never `--logdir`.** `--nogui` needs no display, so
  nothing reached `:0`, `:99` or the user's screen.
* **Every command carried a `timeout`** (60–500 s). The single probe ran under `timeout 240` and
  exited 0 well inside it. **No waiting loop was written at all** — nothing in this task was
  asynchronous, so there was nothing to wait on and no deadline to get wrong.
* **The probe's success is a positive assertion, not a FAIL-absence check**: the script prints
  `PROBE DONE` as its last act and the harness required that exact line
  (`grep -q '^PROBE DONE$'` → `PROBE: OK`), so a silent or crashed probe reports `NORESULT` with the
  last lines of output rather than passing. Handed nothing, that check complains — which is the
  question `CREW_BRIEF.md` requires of every guard.
* **No `pkill`, no `pgrep -f`, no process matched by a pattern my own command line contained.** No
  process of mine outlived its command — measured by **age**, not by absence: `ps -eo comm=,etimes=`
  at the end of the pass shows **seven** live `wish`/`xschem` processes at **75 700–76 011 s
  (≈21 h)**, every one older than this pass by three orders of magnitude and consistent with the
  19.4 h and 19.9 h that receipts 59b and 59c measured for the same set. My single probe exited 0
  under its own `timeout`.
  ⚠ **A guard defect I caught in my own hygiene check, and it is this batch's signature shape.** The
  command that took that measurement ended with an **unconditional** `echo "(none listed above = no
  xschem/wish alive)"` — a line that prints its conclusion whatever `awk` found, and `awk` found
  seven. The verdict is unchanged because the ages settle it, but the check as written **could not
  have disagreed**, which is precisely the *"what does this do when it is handed nothing?"* hole the
  brief requires every guard to be fed. Recording it rather than quietly deleting it: the number
  above is the evidence, that echo line was never evidence of anything.
* Probe and analysis scripts are in the session scratchpad (`probe60.tcl`, `opts.tsv`, `plots.tsv`,
  `authorA.py`/`authorA.json`, `authorB.py`/`authorB.json`, `extract_doc.py`/`doc_blocks.json`,
  `match.py`). They are the evidence behind every number above and nothing reads them automatically.
