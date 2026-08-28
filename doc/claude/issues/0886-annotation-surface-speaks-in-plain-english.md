# 0886 — the annotation surface speaks in plain English

STATUS: **landed** (item A11, 2026-08-27). Wording only — no behaviour changed.
Six unratified wording decisions carry an `owed.sh` **rule** debt under this
number, and the new sentences carry a **look** debt (`annot-plain-english`).

The user's ruling, verbatim (2026-08-27): *"wording too cryptic. Give it in
plain english with context, 9th grade level."*

## What the user was being told before

The annotation surface spoke to the user in the program's own internal
vocabulary. It said `Transient annotation -- NO RAW FILE loaded` when it meant
no simulation results are loaded. It said `the loaded database is not a
transient analysis` when it meant these results have no time axis to read a
voltage at. When the operating point was missing it told the user to type
`xschem raw_clear` — an internal command, offered as a remedy. And every time
reached the user as a bare Tcl float: `Transient annotation at t = 1e-09
(cursor A)`, where an analog designer reads **1 ns**.

## What it says now

Every sentence minted by `cadence::_annot_msg` and `cadence::_annot_tran_msg`
(`utils/annot_mode.tcl`), plus the five sentences that bypassed both mints in
`src/ase_window.tcl` and `src/ase.tcl`, now says WHAT HAPPENED in the user's own
nouns, gives the CONTEXT that makes it make sense and, wherever the user can
act, says WHAT TO DO. The full table is
`doc/claude/specs/op_annotation.md` §4.9.

**The state NAMES did not change.** They are internal, nothing user-facing
carries one, and every test row that asserted a state name was left asserting
it.

## Four things that came with the wording

**1. Numbers are part of the wording.** `cadence::_annot_tsec` renders every
time on the annotation path in engineering units — 4 ns, 30 us, 0 s. It reuses
`op_annot::eng_or_blank` rather than minting a second formatter (invariant I1);
that helper emits no unit letter, so the SI prefix is split off its tail and the
`s` appended here. A value it cannot parse is returned **unchanged**, not
blanked: op_annot's invariant I3 blanks a missing *measurement*, but a time this
proc cannot read is a CALLER bug, and a caller bug rendering as an empty gap is
the silence the whole mode exists to remove. Row **A11-4**.

**2. The 255-character status line, which was ALREADY amputating a sentence.**
See issue **0639**, where the decision is recorded in full. Measured on the
shipped binary before a word was rewritten: mask 7 + `noop` + five symbol types
built 257 characters, `xschem get statusmsg` read back 255, and the tail died
mid-token. `cadence::_annot_fit` now cuts at a space and marks the cut;
`cadence::_annot_say` renders the sentence WHOLE to the CIW and the fitted copy
to the bar. Rows **A11-1**, **A11-2**, **A11-10**.

**3. Two RULING D5-4 breaches closed.** The menu path in the "these results hold
no operating point" sentence was TYPED; it is now derived through
`cadence::_annot_menu_op` → `annot_menu_path_waves_op`, the same mint the
menubar is built from (issue 0661 is the measured drift class). Rows **A11-5**
(behavioural, by renaming the mint) and **A11-6** (structural, the half no
behavioural row can see). And `ase: cannot annotate '<path>': <e>` was written
out at TWO call sites; it is minted once as `ase::ui::annot_fail_msg`. Row
**A11-8**.

**4. The instrument the suite did not have.** Every sentence golden in
`test_op_annot.tcl` is a byte comparison against a string this crew wrote, so a
green run proves the bytes match — the one thing that cannot tell a good
sentence from a bad one. Row **A11-7** enumerates all 202 renderable sentences
against a ban list of the program's own vocabulary and requires every one to be
plain printable ASCII; row **A11-11** (`test_results_freshness.tcl`) requires
every refusal the user can act on to carry a next step. The fourth leg — whether
they actually READ well — is the look debt, and only the user can pay it.

## Six decisions the user has not ratified (the rule debt)

1. **The 255-character split.** The status line shows a marked elision; the CIW
   keeps the whole sentence. The two channels therefore differ on the longest
   combinations. Ratify the split, or say which channel should win.
2. **The `xschem raw_clear` remedy is dropped.** The old sentence offered two
   ways out of "the loaded results have no operating point": the
   *Waves > Op Annotate* menu, and typing an internal command. Only the menu
   remedy survives. Is there a UI gesture that clears loaded results that should
   be named in its place?
3. **The three *Results > Annotate* menu labels are byte-identical.**
   *Operating Point info* and *DC Node Voltages* are the user's own ratified
   strings (decision D9); *Transient Node Voltages (at cursor)* is already plain
   English; and all three are `entryconfigure` lookup keys
   (`src/ase_window.tcl:2279-2284`), so a rename silently breaks the greying.
4. **One neutral clamped sentence, not two directional ones.** "past the end of
   the run" would be false when the cursor sits BEFORE the first sample, so the
   sentence says "outside the time range of the run ... the closest point that
   was actually measured", which is true at both ends and needs no new guard.
5. **The 28-character short form `not annotated: no ASE-L` stays.** It is the
   only thing a `--nolog` user sees and it is a recorded contract
   (`src/ase.tcl`), so only the long form beside it was rewritten. It is still
   the most cryptic string left in the surface.
6. **ASE-L's own out-of-date-results sentence gets its own words**, not the
   mint's. Row V43 requires the fragment "is older than the circuit it
   describes" to live in `utils/annot_mode.tcl` and in no other file, so the
   `ase:`-prefixed sentence says the same thing in its own words: "is from an
   earlier run than the circuit now on screen".

## Not found: a sentence that was WRONG rather than merely cryptic

Nothing in the surface described behaviour the code does not have, so nothing is
owed a filing under the item's "wrong, not merely cryptic" rule. Both remedies
the old sentences offered exist, and `Alt-Shift-6` really is bound.

## What the sabotage run found, and what the repair pass did — 2026-08-28

The wording landed green and three of its guards were not guards. All three are
now closed, and the fixes are rows, not deletions.

1. **The budget counted the wrong unit — filed as 0887, FIXED.** The status line
   is 255 **bytes** (`statusmsg_text[256]`); `cadence::_annot_fit` counted Tcl
   **characters**, and three of the eight states paste the user's own
   results-file path into the sentence. A project directory spelled with
   anything outside ASCII put the amputation straight back — measured at 225
   characters / 256 bytes, cut at 255 with no `...`. `cadence::_annot_bytes` is
   now the one ruler; row **A11-9** is the end-to-end proof and **A11-10** grew
   a non-ASCII path and now measures in bytes.
2. **A11-7 was a legacy-string detector wearing a standard's name.** Its header
   claims "none of the program's own nouns may appear beside them"; its list was
   ten specific old spellings, and a sentence of fresh jargon
   (`OP annot state=nopath: sim dir unset …`) passed it. The list now also
   carries **shapes** — an underscore or an equals sign is an identifier, a
   namespace separator or the program's own command name is the machine talking,
   and the eleven bare state words are names this code calls itself by — and a
   **control**: three sentences that MUST be caught, so the instrument cannot
   read green while unplugged.
3. **The first sentence most users meet had no golden.** `A11_NOPATH` sat in
   `test_op_annot.tcl` defined and never referenced; the only byte-exact
   assertion of the never-simulated sentence lived in a suite no runner carried.
   Row **A11-12** asserts all eight state clauses byte for byte, and row
   **A11-13** brings the "every refusal says what to do next" property into the
   registered suite.

## Where the rows live

`tests/headless/test_op_annot.tcl` — A11-1 … A11-10, A11-12, A11-13, plus every
re-aimed golden. `tests/headless/test_results_freshness.tcl` — M1/M2/M3
(tightened from fragment matches to whole-sentence equality) and A11-11.

**That second suite could not report a failure until 2026-08-28**: its `ck`
printed `FAIL: <name>`, which `run_regression.tcl` does not count (it counts a
line ENDING in `FAIL`), and it finished with `xschem exit closewindow force`, so
a failing run exited **0**. It now prints a counted failure line, emits the dual
banner, exits 1 on any failure, and is registered in both runners. One of issue
**0880**'s five unregistered suites is therefore no longer unregistered; the
other four are untouched.

## What the write-up pass measured and did NOT fix — 2026-08-28

Five things were measured after the repair pass and left alone, each filed under
its own number rather than fixed quietly. Three of them this pass created.

* **0888 — the line says "Showing … on the schematic" when nothing was put
  there.** `<mask clause> <state clause>` is emitted for refusal states too, so
  a never-simulated cell reads *"Showing device operating-point values on the
  schematic. There is no results file at … yet."* 35 mask × refusal-state
  combinations. The mask clause used to be a **mode** claim (`OP annotation ON
  (…)`), which was true in these states; this pass turned it into a **screen**
  claim, which is not. `_annot_msg`'s own `notop` comment already argues exactly
  this and was applied to one state only. The remedy is a wording choice the
  user has to make, so it carries a rule debt of its own.
* **0889 — two edge values render badly.** `These symbol types … : nmos.` is
  plural with one item; `_annot_tsec -0.0` gives `-0 s`.
* **0890 — `ase::ui::annot_fail_msg` splices raw engine text into a user-facing
  sentence** through `$e`. Latent: measured 2026-08-28, `xschem annotate_op`
  does not raise on a missing path, an unparseable file, a bad level or a bad
  argument count, so the sentence appears to be unreachable today.
* **0891 — 0881's V50/V51 are green headless and RED with a live display.** Not
  this pass: the failing output carries this pass's new wording and *matches*
  the expectation, while the state and the attached file diverge; a non-comment
  diff against `HEAD` shows nothing on that path changed. Filed because it is a
  measured red that no runner can see.
* **0892 — five status-line rows compare the FITTED line to the UNTRIMMED
  sentence**, four of them with an absolute path in it. N9's margin is 35 bytes
  and N10b's is 33, on this machine. The old wording left N9 about 113; plain
  English ate 78 of them. Row N15 in the same file already shows the correct
  shape.

### And a number that belongs beside rule-debt item 1

The 255-byte split was ratified as a *decision* and not as a *frequency*. With
an ordinary project path (`/home/analog/proj/bandgap/tb_bandgap/simulation/run.raw`,
55 characters) the status bar elides **62 of 192** mask × state × symbol-type
combinations — measured 2026-08-28. The widest is 373 bytes. And the clause the
elision eats is the actionable one: mask 7 + `noop` fits as

    … values to show. Load a different results file from Waves...

so the derived menu path — the entire point of the D5-4 fix, and the only remedy
that sentence offers — is what gets cut. Row A11-11 cannot see this: it matches
the bare token `Load ` against the **unfitted** mint output, which survives. The
user should have that number in front of them when they rule on item 1.
