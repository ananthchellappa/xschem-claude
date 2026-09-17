# Release note — ASE-L and the ngspice you have (Stage 16e, issue 1471)

⚖ **WHERE THIS SHIPS IS NOT DECIDED, AND IT IS NOT THIS BATCH'S DECISION.** The repository's
`Changelog` is upstream xschem's per-release file, kept by its author, and ASE-L writing into it is a
maintainer's call. It is filed on the user's queue as `owed.sh` rule **`1471_release_note_destination`**.
Until it is answered the note lives here, in the batch directory, and ships nowhere.

**How this file is laid out.** Everything between the `note:begin` and `note:end` markers is the text
that would ship. Every claim in it carries a tag — `[E3]` — naming a row of the evidence table below
`note:end`, which is for the maintainer and does not ship; strip the tags when it does. Rows **WR1–WR4**
of `tests/headless/test_ase_simwin_variant_1471.tcl` hold the text to its rules: no claim without an
evidence row, no evidence row without a file behind it, never "basic", never PSS, never a future release
fixing anything, and no version floor. The rules are PLAN §16a (a)–(c) and §16e, receipt 46's correction
**C8**, and ⚖ **R11**.

**Two halves (PLAN §16e).** The **description** is a measured finding and ships without a ruling. The
**support sentence** is ⚖ R11's, answered **Option C** on 2026-09-13; its wording departs from the
drafted one in one place, recorded under *The support sentence* below.

<!-- note:begin -->
## ASE-L and the ngspice you have

**ASE-L runs on the ngspice your distribution ships, with no configuration.** On Ubuntu 26.04 LTS that
is the `ngspice` package, 45.2. You do not need our own build of ngspice to use ASE-L [E1].

To see what your ngspice can and cannot do, open **Setup > Simulators…**, pick it, press **Edit…** and
then **Detect**. A sentence beneath the case-mode line says what that program can do — and on a program
that can do everything ASE-L offers, it says exactly that [E2].

### The same on every ngspice we test

* **OP, DC, AC and TRAN**, and several of them in one run: the same plots, in the same order, told apart
  the same way [E3].
* **TF, PZ and DC sensitivity** run and read back on both [E4]. **NOISE, DISTO and AC sensitivity**
  produce the same plots in the same order [E5].
* **S-parameters (SP)**: the same analysis, with the same vector names on screen [E6].
* **Stopping a run keeps what was already computed**: the analyses that had finished, and a transient up
  to its last checkpoint [E7].
* **The options sheet**: every option ASE-L probed behaves the same, and the start-up settings that have
  to be made before the circuit is read take effect [E8].
* **Measurements**: every measurement template returns a number [E9].
* **Convergence aids**: an operating point reached through `optran` gives the same numbers [E10].
* **Campaigns and Monte Carlo** run, and a seeded random draw gives the same number [E11].
* **Mixed-signal (XSPICE) runs**: the digital results and their VCD export [E12].
* **Transient noise and random sources** [E13].
* **Operating-point annotation** shows the same numbers [E14].

### What differs

* **Case-sensitive net names need our own build.** It keeps the case of net and device names; the
  distribution's 45.2 and stock upstream hand every name back in lower case. ASE-L measures which
  spellings a program keeps and offers only those [E15].
* **On 45.2, operating points are collected one device at a time.** Its fast operating-point dump prints
  wrong numbers, and no ngspice release has the fix yet; stock upstream and our own build use the fast
  dump [E16]. The numbers you see are the same. What is lost is speed and coverage: only the devices
  your PDK's annotation descriptor can name are annotated [E17].
* **Two kinds of command line are misread by 45.2 and by stock upstream** — a keyword argument written
  in capitals on a `write` line, and a bare `gnd` in a command that takes text. ASE-L warns before a run
  that uses one [E18].
* **Three kinds of command line can abort 45.2** — `unset`, a `define` of your own, and `load` of some
  results files. ASE-L warns before any run that uses one, on every build; it never finds out by
  crashing your simulator [E19].
* **VCD export carries the digital signals only**, on every build, because naming an analog signal on
  the export line aborts 45.2 [E20].
* **NOISE can list more noise contributions for a device on our own build** than on 45.2 [E21].
* **The number of points in a transient differs slightly between builds** — 118 against 121 for the
  same circuit — so point counts and file sizes are always given as estimates [E22].
* **45.2 accepts a request for more measurement digits and ignores it** [E23].

### Handled for you

* 45.2 writes S-parameter names in lower case in the results file; ASE-L reads them either way [E6].
* 45.2 prints a measurement with one more decimal than our own build; ASE-L reads the value, not the
  width [E24].

### What we test against

<!-- support:begin -->
ASE-L is tested against the ngspice your distribution ships (45.2 on the current Ubuntu LTS), against
stock upstream ngspice built from source, and against our own build. Older ngspice is not refused — it
is measured, and ASE-L offers whatever it proves it can do.
<!-- support:end -->
<!-- note:end -->

## Evidence — one row per tag, for the maintainer; does not ship

The binaries are named as in `CREW_BRIEF.md`'s preflight: **apt 45.2** is `/usr/bin/ngspice`
(Ubuntu `45.2+ds-1`); **the fork** — "our own build" — is `/home/analog/dev/ngspice/build-ver_50/src/ngspice`;
**stock upstream** is the bare-configure build of `origin/pre-master-47` at `c5cd68015`, which reports
itself exactly as the fork does, so no version string can tell the two apart (`DECISIONS.md` D44).

| E | claim | evidence | measured on |
|---|---|---|---|
| E1 | runs on apt 45.2 with no configuration | `evidence/fork-features.md` §14 row 1 (MEASURED §3, §8); `PLAN.md` §0.13.1; `CREW_BRIEF.md` preflight (`apt-cache policy ngspice` → `45.2+ds-1` on Ubuntu 26.04.1 LTS) | apt 45.2, fork |
| E2 | Detect in the row editor shows the sentence; a complete build reads the complete frame | `tests/headless/test_ase_simwin_variant_1471.tcl` rows WG3, WG5, WG7/apt, WG7/fork (the real binaries through the real button); decision C2, rule `1471` | apt 45.2, fork |
| E3 | several analyses in one run: same plots, same order, told apart the same way | `receipts/14-stage-6-writer.md` (*"Row for row, byte for byte, identical on the fork and on apt 45.2"*); `PLAN.md` §0.13.1 (op and tran: identical `Variables:` blocks and printed values) | apt 45.2, fork |
| E4 | TF, PZ, DC sensitivity run and read back | `receipts/10-stage-5-tf.md`, `receipts/11-stage-5-pz.md`, `receipts/12-stage-5-sens.md` (*"rc 0 on the fork and rc 0 on apt 45.2"*, read back through ASE-L's readers) | apt 45.2, fork |
| E5 | NOISE, DISTO, AC sensitivity: same plots, same order | `receipts/15-stage-6-multiplot.md` (*"byte-identical between the fork and apt 45.2 for all four decks"*); the KLU crash of AC sensitivity is suppressed, measured on both in `receipts/22-stage-7-effective.md` | apt 45.2, fork |
| E6 | SP is the same analysis with the same on-screen names; the file's lower case is read either way | `evidence/binary-differences.md` (agreements, first bullet; difference 6); `receipts/32-stage-9-sp-deck.md`; `receipts/33-stage-9-sp-surface.md` (*"RE-MEASURED here on both"*) | apt 45.2, fork |
| E7 | Stop keeps finished analyses and the transient to its last checkpoint | `receipts/16-stage-6-salvage.md` (SIGTERM 6 s into an 8,000,008-point transient: op and ac intact, checkpoint *"byte-IDENTICAL on the two binaries"*) | apt 45.2, fork |
| E8 | options behave the same; start-up settings take effect | `receipts/19-stage-7-catalogue.md` (fourteen probe families, every value identical); `receipts/21-stage-7-finding.md` (22 `results` rows, *"Every value was identical on the two"*); `receipts/20-stage-7-predeck.md` (*"MEASURED on BOTH binaries"*) | apt 45.2, fork |
| E9 | every measurement template returns a number | `receipts/31-stage-8-measurements-gui.md` (*"all eight templates produce numbers — MEASURED on both binaries"*) | apt 45.2, fork |
| E10 | `optran` gives the same numbers | `receipts/36-stage-10-deck.md` (the `optran` table); `evidence/binary-differences.md` (agreements: *"agree to every digit printed"*) | apt 45.2, fork |
| E11 | campaigns run; a seeded draw gives the same number | `receipts/39-stage-11-gui.md` (*"Section EE starts real simulators on BOTH binaries"*); `receipts/38-stage-11-runner.md` (the shard design that avoids `var()`, which kills a run on 45.2 — difference 8); `evidence/binary-differences.md` (agreements: seeded randomness) | apt 45.2, fork; `var()` also on stock upstream |
| E12 | XSPICE digital results and VCD export | `receipts/40-stage-12-event-results.md` (rc 0 on both, the same VCD variables, the same attach) | apt 45.2, fork |
| E13 | transient noise and random sources | `receipts/41-stage-13-deck.md` (rows EE1–EE6 on both); `receipts/42-stage-13-gui.md` (the form to a run and back, on both) | apt 45.2, fork |
| E14 | annotation shows the same numbers | `evidence/fork-features.md` §14 row 2 (MEASURED §3: shape c byte-identical; tier d agrees to 4.70e-06, `show`'s print rounding) | apt 45.2, fork |
| E15 | case kept only by the fork; ASE-L offers only what was measured | `evidence/fork-features.md` §8 (the probe and the mixed-case deck, both binaries) and §12; `receipts/46-stage-16-deck.md` headline 1 (the real probe: `casemode_detected {fold}` on apt 45.2 and stock upstream); `tests/headless/test_ase_simdlg_0937.tcl` rows S24–S25 | apt 45.2, fork, stock upstream (probe) |
| E16 | 45.2's dump is unsound; no release has the fix; stock upstream and the fork use the dump | `evidence/fork-features.md` §4 (the dump, MEASURED); `receipts/46-stage-16-deck.md` (`git tag --contains 10276f993` empty, re-measured 2026-09-15; `altshow_op_dump` 0 / 1 / 1 from the real probe) | apt 45.2, fork, stock upstream (probe) |
| E17 | the per-device path covers only what a PDK descriptor names | `evidence/fork-features.md` §5 (the `tb_bandgap` table: 212 devices against 78); `PLAN.md` §0.13.5 | the user's `tb_bandgap`, as recorded in the tree's source comments |
| E18 | the two misread kinds, on 45.2 and stock upstream | `PLAN.md` §0.13.8 (b) (`write f ALL` leaves no file on apt 45.2 and stock upstream); `evidence/fork-dependencies.md` §4.7 (the `gnd` rewrite) and §4.11; `receipts/46-stage-16-deck.md` headline 1 (`keyword_case` 0 and `gnd_literal` 0 from the real probe on both) | apt 45.2, stock upstream; the fork measured sound |
| E19 | `unset`, `define`, `load` can abort 45.2; ASE-L warns on every build | `evidence/fork-dependencies.md` §4.3, §4.4/§4.5, §4.8; `PLAN.md` §0.13.6; `receipts/46-stage-16-deck.md` headline 3 (patterns 1–3 warn on every binary, linted over strings — never run on a binary) | apt 45.2 (the evidence file's own runs, deliberately not repeated) |
| E20 | VCD export names digital signals only | `evidence/binary-differences.md` difference 9; `evidence/m9-event-vcd-attach.md`; `receipts/40-stage-12-event-results.md` (the emitted line names only the event nodes) | apt 45.2 (from M9, not repeated), fork |
| E21 | more noise contributions per device on the fork | `receipts/15-stage-6-multiplot.md` (*"`onoise_d1_1overfsw`, `onoise_d1_idsw`, `onoise_d1_rsw` exist on the fork and not on 45.2"*) | apt 45.2, fork — stock upstream not measured, so the note names only these two |
| E22 | transient point counts differ; estimates are worded as estimates | `evidence/binary-differences.md` difference 7 (118 against 121); `receipts/41-stage-13-deck.md` (correction C8, the estimate wording); `receipts/42-stage-13-gui.md` (1210 against 1349 points) | apt 45.2, fork |
| E23 | `measureprec` accepted and inert on 45.2 | `evidence/binary-differences.md` difference 5; `receipts/23-stage-8-measurements.md` (correction C146, *"MEASURED on both binaries, both routes"*) | apt 45.2, fork |
| E24 | the `meas` line's six decimals against five; ASE-L reads the value | `evidence/binary-differences.md` difference 2; `receipts/23-stage-8-measurements.md` (fact 3: `ase::meas_parse` takes the value as a token; rows SC2d and S68) | apt 45.2, fork |

## What the note deliberately leaves out

* **PSS, on every row.** ASE-L does not offer it (`ase::analysis_renderable ngspice pss` answers 0), and
  on apt 45.2 it converges on nothing measured, not even ngspice's own example
  (`evidence/pss-two-binaries.md`). ✅ **This is now PERMANENT, not pending.** ⚖ R7 was reversed by the
  user on 2026-09-16 — the PSS panel is **not built** (issue **1475**) — so the omission is a decision
  rather than a gap waiting on a stage. ⚠ **This bullet read *"⚖ R7 is back with the user"* until then**,
  which would have shipped a user-facing note describing an open question as open after it was closed.
  One rule for the window, the run log and this note (PLAN §16a (b)).
* **The phantom `v(all)` column** (difference 1) and **XSPICE event counts** (difference 3). ASE-L already
  works around the first where it reads, and the evidence disagrees about the second — `binary-differences.md`
  counts 10 events against 11 where `m9-event-vcd-attach.md` found the counts equal on its own deck — so
  neither is a sentence a user can act on.
* **Anything about stock upstream beyond what its probe measured.** It was probed (receipt 46, rows EX3 of
  `test_ase_variant_1470`) and ran `var()` (receipt 38); no feature-by-feature run on it exists, so *"The
  same on every ngspice we test"* cites apt 45.2 and the fork only, and the support sentence promises that
  it is tested, which the batch's own two-binary rule and those rows make true.
* **Receipt 46 C8's two sentences.** Both named a release that does not exist; the measured wording —
  *"no ngspice release has the fix yet"* — is what the note, the Simulators window and the run log all say.
* **Any version floor**, by ⚖ R11.

## The support sentence — one departure from R11's draft

R11 drafted *"…against stock upstream **at the 47 tip**, and against our own build."* Shipped here:
*"…against stock upstream **ngspice built from source**, and against our own build."* ⚠ **The reason is
C8's rule**: ngspice 47 is not a release (`git tag --contains` is empty for the commits that would make it
one, and the build reports itself as 46+), so a number beside "stock upstream" is read as a version a
person could install. R11's condition 3 still binds: when a 47 release exists, the phrase becomes that
release's name. Everything else is R11's text verbatim. Recorded under rule `1471_release_note_destination`
so the user sees it when they rule on where the note goes.
