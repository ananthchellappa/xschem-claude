# 0948 — A registered simulator is never asked what it can actually do

**STATUS: FIXED (2026-08-30, item S3) — the surface exists, it answers from a
probe run, and it is registered and green at 50 checks. It ships with ONE
RULING OWED BY THE USER (see "What the user has not ratified") and SIX MEASURED
DEFECTS OF ITS OWN, all filed, two of which put a false sentence on the user's
screen: see "What it shipped with" near the bottom. Read that section before
building on this.**

## What the user sees

They point ASE-L at a simulator build of their own in Setup > Simulators. It
starts, it exits without complaint, and its log has no warning and no error
line in it. And their operating point is gone: pressing `6` on the schematic
says there are no operating point results, because the deck asks the simulator
to ADD each analysis to the results file and this build threw the earlier ones
away as it went. Nothing anywhere told them. It is issue 0929's exact symptom,
arriving through a door 0929 never guarded.

## Measured before-state (HEAD bb8fe6a2, headless, nothing rebuilt)

* Asking the registry what a registered build can do errors out:
  `ase: unknown hook 'capabilities' for simulator 'ngspice'`. The registered
  hook set is exactly `render_deck run_cmd log_file result_probe raw_file`;
  `grep -c capabilit` over `src/ase.tcl` and `src/ase_window.tcl` is 0 in both.
* Two decks identical but for one line, both through the real ngspice: with
  the add-each-analysis line, one results file holding an `Operating Point`
  plot AND a `Transient Analysis` plot; without it, one plot, the transient.
  **Both runs exit 0 and both logs are clean** — no warning, no error line.
* A version string cannot tell the two builds apart: both print
  `** ngspice-46+ : Circuit level simulation program`, byte for byte. The
  method has to be a probe run.
* The tree reports the unusable build as healthy: the validator returns empty,
  the resolver returns `ok 1` with nothing to say, and the record a dialog
  reads back to the user is empty.
* A blanket device save, `.save @m.xo1.xi1.m1[*]`, exits 0, WRITES a results
  file, and logs nothing — and the file holds a `constants` plot and no
  operating point at all. An "did the command error" check calls that success.

## What was built

A sixth backend hook, **`capabilities`**, alongside `render_deck`, `run_cmd`,
`log_file`, `result_probe` and `raw_file` — **optional**, so every hand-built
five-hook registration in the tree keeps registering and no future backend has
to write a probe before it may exist. `ase::register_backend`'s required-hook
loop is unchanged and a structural row locks it there.

**The front door is `ase::sim_capabilities <backend>`**, lazy and cached. It
answers one of

    {known 0}
    {known 1 usable 0|1 appendwrite 0|1 blanket_op_save 0|1 hier_op_names 0|1}

and when `known` is 0 the capability keys are **absent, never 0** — absent
means "nobody measured", 0 means "measured, and the answer is no". A reader
that treated a missing key as a no would turn "we never asked" into a
statement about the user's simulator.

**Three guards return before the probe and before any cache write:**

1. **the resolver said no.** Issue 0935: that answer still carries a
   `resolved` naming a real file on the PATH — the file a *wrong* choice would
   have started. Probing it would measure a program the resolver has already
   refused, and would file the answer under a simulator the user is not using.
2. **nothing resolved.** 0935's other half: `ok` is 1 while `resolved` is
   EMPTY whenever nothing is registered and nothing of that name is on the
   PATH. Two unrunnable backends both answer that way, so a cache keyed on an
   empty string would fuse them into one answer about neither. Nothing is ever
   stored under an empty key, and a structural row proves it after driving
   both arms repeatedly.
3. **the backend declares no probe** → `known 0`, never a guessed yes.

**The cache key is the resolved absolute path, and the stamp is path + mtime +
size** (`ase::cap_stamp`, modelled on `ase::cosim_stamp`). A user who rebuilds
their simulator in place is re-measured with **nothing to do on their part** —
that is the whole point of the mtime and size terms, and three separate rows
prove it: a rebuild that changes both, one that keeps the size, and one whose
file time did not move. `ase::cap_stale` is biased exactly like
`ase::cosim_stale`: any doubt at all costs one ~10 ms probe, and a wrong "not
stale" costs the user a silently truncated results file.
`ase::sim_caps_clear` is the lever for a user who knows something a file stamp
cannot see.

**The probe is two decks, and each verdict is read out of the results file.**
Deck A asks for an operating point AND a transient with the add-each-analysis
line set; deck B asks for every parameter of one device at once. The circuit is
PDK-free — a level-1 MOS two subcircuits deep — so nothing on the machine has
to be installed. `set filetype=ascii` is asked for (measured: ngspice-46+ still
appends every analysis with it), and `ase::cap_raw_plots` reads a binary
results file just as well, skipping each `Binary:` payload by its exact length.

* **`appendwrite`** — both analyses in ONE file, with the operating point
  holding at least one data point. The point count is not a formality: an
  operating point arriving with `No. Points: 0` is the bogus-empty deceit, and
  counting it would call a destroyed result a success.
* **`hier_op_names`** — the device is inside two subcircuits and its numbers
  must arrive under the three exact spellings `op_annot::_wrap` builds
  (`src/op_annot.tcl:419-425`). Measured separately from `appendwrite`, so a
  build with a naming difference is visible as a naming difference.
* **`blanket_op_save`** — no released ngspice can do this, and the probe
  answers NO by **measurement**: on this box the run exits 0, writes a file,
  logs nothing, and the file holds only a `constants` plot. A non-vacuity row
  drives a stand-in that CAN do it and proves the answer flips to yes.
* **`usable`** — did anything with a data point in it come back at all.

**The exit code is collected and used for nothing.** That is the central
constraint, and the before-state above is why: exit 0, a clean log and a
written file all say success over a destroyed result.

**Two new sentences, minted in `ase::sim_why` and nowhere else** (ruling
D5-4), rendered through `ase::sim_say` so the Simulators window can read back
the very sentence the CIW got:

* `cap_no_append` — the program keeps only the last analysis, this run has
  more than one, so run them one at a time or use a build that adds each
  analysis to the results file.
* `cap_not_a_simulator` — the program produced no results at all on a tiny
  test circuit; check that it really is a circuit simulator.

Both put the program's **location first**, deliberately: they are about a
PROGRAM, not a list entry, and location-first is also what keeps the
one-place-only structural row meaningful (a location dropped into the middle of
a sentence leaves a fragment of itself glued to the words in front of it, which
no source line can match).

**The say-site is `ase::cap_report`, called once from `ase::run_deck`** right
after the 0929 raw deletion — not from `run_cmd`, whose returned command and
echo behaviour are pinned byte for byte by row D4 of
`tests/headless/test_ase_simreg_0931.tcl`. It is wrapped in a `catch`: a
capability probe that cannot run must never stop the run it was only reporting
on. The suite calls it directly, uncaught, so a defect in it is still loud.

`ase::n_enabled_analyses` now owns the enabled-analysis count that both the
rendered deck and the report lean on; counted twice, the two could disagree and
the warning would be about a run that is not the one being launched. The
rendered deck is byte-identical.

## A trap this fix walked into, recorded because the next editor will too

**A `#` line inside a `switch` body is NOT a comment.** A switch body is parsed
as a LIST of pattern/body pairs: the `#` becomes a pattern, the next word its
body, and every pair after it shifts by one. Adding the two new kinds with a
comment between them silently ate `path_in_force`, which fell through to the
catch-all sentence and reddened row R9 of
`tests/headless/test_ase_simreg_0931.tcl` — a real user-visible wording
regression, caught only because that row exists. The comment now lives above
the `switch`, and says so.

## Where the checks are

`tests/headless/test_ase_simcaps_0948.tcl` — **50 checks**. The first 40 were
written with the fix; 32 of those were red at bb8fe6a2 for the reason above
(`NOPROC` / unknown hook) and 8 green because they are the guard rows that must
not move. Registered in `tests/run_regression.tcl` (hcases, dual banner) and in
`tests/headless/full_audit.sh` (`nogui_tests`). Sections B, C, D, E and G drive
hermetic stub simulators the suite writes itself, so the probe's behaviour is
proved with no ngspice on the box; row C4 is the one row that measures the real
build, and it skips loudly when none resolves.

### The ten rows added after the sabotage pass

A sabotage pass deleted each guard one at a time and found **six that no row
could see** — the exact defect this branch has twice let past a wall of passing
checks. Each was closed by adding a row, never by deleting the guard. Every one
of the ten was then proved by deleting its guard again and watching it redden:

| row | the guard it watches | proved by |
|---|---|---|
| **F8** structural | the warning is raised where the **run** is started and nowhere else | deleting the call in `ase::run_deck`, and the faithful move of it into `run_cmd` — both redden it |
| **F9** behavioural | starting a real run really does put the sentence in the CIW, exactly once | deleting the call in `ase::run_deck` |
| **G5** | a program that never comes back at all is cut off, so the user's Run cannot hang on it | deleting the wall-clock cap in `ase::cap_run` — the suite then takes 30 s and the row reds |
| **G6** | the extra arguments a user registered are handed to the program when it is **measured** too | deleting the pass-through in `ase::cap_run` |
| **B7** | a results file written as raw numbers is read correctly, and numbers that spell a plot header are not mistaken for one | deleting the payload skip in `ase::cap_raw_plots` |
| **B8** | the same when each number takes twice the room | deleting the skip, **and** separately collapsing the wide stride to the plain one |
| **C5** structural | every deck the probe writes asks for a results file in plain text, not just the first | dropping the request from the second deck |
| **D7** | the program a remembered answer was about is deleted: the tree measures again | flipping the empty-record arm of `ase::cap_stale` |
| **D8** | an empty record means measure again; only an exact match is trusted | flipping the empty-record arm |
| **D9** structural | both doubt arms still answer measure-again | flipping **either** arm |

Row **G3** was also strengthened. Its behavioural half — a program that stops to
read something typed at it — can only see its guard when the shell that launched
the test has a live input of its own; from a launcher whose input is already
finished the same row goes green with the guard deleted (measured both ways:
red at 20 s, green at 0.33 s). It now carries a structural half as well, so the
redirect is asserted on every arm.

### One guard that no row can watch, and it is now said out loud

`ase::cap_stale`'s second doubt arm — the one that answers "measure it again"
when the two records cannot even be compared — **cannot be reached by any
value**. Measured: `string equal` handed exactly two values and no options never
raises, whatever those values are, because options are only looked for when
there are more than two arguments, and there are always exactly two here. A
first attempt at a row for it scored a false green, which is how this was found.
The arm is kept (falling into it answers re-measure; falling out of the proc
would abort the run it was only reporting on), row D9 pins that it still answers
1, and the comment above the proc now records the reachability finding so no
later reader takes it for measured behaviour.

## What the user has not ratified

Recorded as a `rule` debt against this number. The decisions taken to get a
working surface, any of which the user may reverse:

1. **Warn, do not refuse**, for a build that keeps only the last analysis. The
   last analysis's results are still produced, so refusing would strand a user
   mid-gesture whose build is merely old, and the warning says exactly what to
   do instead. The rejected alternative is to refuse the way the resolver
   refuses a deleted program.
2. **Warn, do not refuse**, for a program that produced no results at all on
   the probe circuit — same reason, plus one more: the probe is a heuristic,
   and refusing on a probe some exotic build defeats would be worse than the
   failure it prevents.
3. **Said every run**, not once per build per session. A run that silently
   discards the user's operating point deserves a line each time, and it is one
   line in the CIW.
4. **Nothing at all is said when `blanket_op_save` answers no.** That is every
   released simulator, so a sentence would be noise on every run — but it does
   mean the user is never told why per-device save cards are still emitted one
   by one.
5. **No "check again" control in the Simulators window.** The lever
   (`ase::sim_caps_clear`) exists for a GUI to call; nothing calls it yet. The
   hole it would cover is a rebuild inside the same second that leaves the file
   exactly the same size — the same one-second file-time hole already recorded
   at `src/op_annot.tcl:843-847`.

## What it shipped with — six measured defects, filed, none fixed here

Found by this item's own verification and sabotage passes and by its write-up
pass, each reproduced before filing. They are listed worst-first; the first
three are the ones that make this surface lie.

| issue | what it does to the user |
|---|---|
| **0951** | Two xschem windows share one probe scratch file under one fixed name, so another window's results can answer for the program being measured. Reproduced: a "simulator" that wrote **nothing at all** was measured `usable 1 appendwrite 1 hier_op_names 1`. This defeats the purpose of 0948 itself, silently, and should be fixed first. |
| **0949** | A simulation folder whose name has a space (or a dollar sign) in it makes the probe write where it cannot read, and a perfectly healthy ngspice is told, on every Run, that it "produced no results at all" and to point the entry at a different file. The deck's `write` line is unquoted — and so is the real deck's, at `src/ase.tcl:5345`, which is older than this change. |
| **0952** | `appendwrite` is read off the presence of an operating-point plot, so a build that appends perfectly but spells device parameters differently is told it keeps only the last analysis and advised to run them one at a time — which changes nothing. The right answer is already computed (`hier_op_names 0`) and thrown away. |
| **0953** | Two probe runs at ten seconds each are paid synchronously inside the user's Run: a simulator that is slow to start freezes the editor for **20.0 s** (measured) and is then called not a simulator. "Cut off by its own clock" is being reported as "produced nothing". |
| **0950** | A wrong answer, once taken, is remembered for the whole session — the stamp only notices the program file changing, so every cause outside it is permanent. `ase::sim_caps_clear` fixes it in one call and nothing in the GUI calls it. This is decision 5 below, measured much wider than the one-second file-time hole that decision described. |
| **0954** | `ase::cap_run`, in the generic namespace, appends ngspice's `-b`. Latent while ngspice is the only backend; a trap for the second one, and a breach of this file's own stated seam (`src/ase.tcl:24`). |

Three of the six — 0949, 0950 and 0953 — are the same mistake in three places:
**a measurement that did not happen is being reported as a fact about the
user's program.** The contract at the top of `ase::sim_capabilities` already
says how to answer that (`known 0`, no capability keys, no cache entry); the
three arms above do not obey it.

## Deliberately not done

* **The cache is not persisted** beside the simulator list. It would buy one
  probe per session (~10 ms measured) and cost a file format, a corruption arm
  and a staleness arm.
* **No deck emission changed.** Section H of the suite exists to prove it: one
  add-each-analysis line, one write per analysis, unchanged.
* **No pixels.** There is no dialog here; a green suite proves the answer a
  Simulators window would show, never the window.
