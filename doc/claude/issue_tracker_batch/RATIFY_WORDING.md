# Ratify the new on-screen wording

## 16 decisions. About an hour.

Your queue currently shows **48 separate items** that all say the same thing: *"this stage
added new words to the screen — approve them or give different words."* They were filed one
at a time, over weeks, as each piece of work finished.

**They are one review, not 48.**

Thirty-six of them are already collected — word for word, taken from the shipped program
rather than from anybody's description of it, and grouped by **which window the text appears
in**. That collection is finished and waiting for you. It needs a skim, not 36 answers.

The other twelve raise questions the collection does not answer. Those, plus four new
sentences your own earlier answers created, are the **16 questions below**.

---

## How long this takes

| | |
|---|---|
| The 16 questions below | **~45 minutes**, or a few short conversations |
| Skimming the collected wording, by window | ~30 minutes, and optional |
| **All of it in one sitting** | **~1 hour 15** |

**You do not have to approve the collected wording line by line.** Its rule is: *anything you
do not mark is accepted as it stands.* So you can read it as fast as you like and stop only
where something jars. The 16 questions are the part that genuinely needs you.

> One thing to know before you open it: its contents table says it holds 410 pieces of text.
> It actually holds **821**. The table was written early and never updated as later work was
> added to the document. Nothing is missing — the count is just stale.

---

## Twelve recurring choices — already asked, already answered

Worth knowing before you start, because it is most of why this is now an hour and not a week.

Twelve questions cut across hundreds of the individual strings at once — shouted words in the
middle of sentences, lowercase acronyms in pickers, internal variable names shown where a
label belongs, units in brackets, developer jargon on your screen, and so on. **You answered
all twelve on 15 and 16 September**, and those answers have shipped.

**You are not being asked any of them again.**

Two of your answers, though, created sentences that did not exist when you gave them. You
ruled that a piece of information had to *move* somewhere else — you did not write the words
it moves into, because nobody had written them yet. Those are questions 1 and 2.

---

# The 16 questions

Grouped by the screen you meet them on.

## A. The analysis setup window

### Q1 — Two new sentences about a one-point noise sweep

Nothing like this was on screen before. It appears under the form when the setting is wrong.

| | |
|---|---|
| **Now** | *(nothing — the form said nothing about it)* |
| **Proposed warning** | `a linear noise sweep of 1 point measures one frequency and produces no Integrated Noise plot at all, and ngspice says nothing about it` |
| **Proposed fix line** | `use 2 points or more, or switch the sweep to dec` |

**Why this exists:** you ruled that arithmetic comes out of field labels and moves into the
warning line beneath the form. Doing that uncovered that the existing warning was a single
shared sentence telling four different analyses the same thing — and it was **wrong for two
of them**. So this analysis got its own sentence. These are those words.

### Q2 — Two new sentences about the start time

Appears under the form, and only when you have actually set a start time.

| | |
|---|---|
| **Was** | the label itself read `Start recording at (s)` and carried the meaning |
| **Now the label reads** | `Start time (s)` |
| **Proposed warning** | `ngspice still simulates from 0 and only discards the output before 5u, so this shortens the results file and not the run` |
| **Proposed fix line** | `clear Start time (s) to keep the whole waveform` |

**On screen it renders as one line:**

> ⚠ ngspice still simulates from 0 and only discards the output before 5u, so this shortens
> the results file and not the run. Fix: clear Start time (s) to keep the whole waveform

**Why this exists:** you ruled the label should become a plain noun phrase — but that label was
carrying a real fact, and you ruled the fact must **move, not disappear**. This is where it
moved to. You never saw these words.

### Q3 — What to call a simulator the program cannot drive *(two halves)*

Three sentences appear in the setup window's status line when the analysis list is empty:

```
ASE-L does not know a simulator backend called 'zznoad'. Registered: ngspice
ASE-L has no adapter for 'zznoad' yet, so it cannot list its analyses.
The adapter for 'zznoad' lists no analyses, so there is nothing to choose.
```

You have already struck the phrase *"this simulator backend"* out of three other sentences,
in favour of plain **"this simulator"**, on the grounds that *backend* is our word for our own
architecture — you choose a **simulator**, under Setup > Simulators. Your ruling named three
specific sentences, so these were **reported rather than quietly tidied**.

**(a)** Does `backend` go the same way here?
**(b)** Is `adapter` the same objection wearing a different word? That one has never been put
to you at all.

*These three sentences are the whole of what that window can say when the list is empty, so
changing the vocabulary changes all of it or none of it.*

### Q4 — Six sentences saying why an analysis cannot be switched on

These are on screen today and none has ever been reviewed. They appear in the analysis grid
when you click a greyed-out analysis.

| What it says now | When |
|---|---|
| `This build cannot run <name> -- the simulator was asked and does not have it.` | the program was asked and said no |
| `Nothing has been measured about this simulator yet. Press Detect to ask it which analyses it can run.` | nobody has asked it yet |
| `Nothing can be measured about this simulator, so ASE-L cannot tell whether it has <name>.` | it cannot be asked at all |
| `ASE-L cannot set up <name> yet, so it is listed but cannot be enabled.` | we have not built it yet |
| `ASE-L could not work out whether this simulator has <name>.` | the answer was unreadable |
| `<name> will run, but <reason>.` | it works with a caveat |

**Why they were missed:** the survey that collected this copy worked by *rendering the screen
and reading it* — which is the right method, and it can only ever show the states it managed
to produce. Its test bench never got into these six states, so six live sentences were
invisible to it. A seventh sentence on the same screen was reviewed; these six were not.

### Q5 — One caption is still bare

On the DC sweep form:

| Caption | Status |
|---|---|
| `Sweep variable` | fine |
| `Start` | **bare** |
| `Stop value` | you renamed this from `Stop` |
| `Step size` | you renamed this from `Step` |

You ruled *"no caption is bare"*, but the table you ruled on listed only **Stop** and **Step**.
So `Start` was left and reported rather than changed to match.

⚠ **No replacement wording has been written for it anywhere**, and I have deliberately not
invented one. The question is whether it changes at all, and if so to what.

---

## B. How refusals are written *(cuts across several windows)*

### Q6 — Three places still show angle brackets as literal text

You ruled that placeholders should be spelled as words, so that **any `<...>` you see on
screen means a value failed to fill in** — a reportable bug rather than house style.

Three places deliberately still show angle brackets, because there they are a **syntax
template you are meant to read and copy**, not a value: a sensitivity filter, the pre-run
check, and one remedy line. Your ruling was about one family of sentences and did not reach
these.

**Do they stay as they are?** If they do, the rule is *"angle brackets mean a bug, except in
a syntax template"* — which is a weaker guarantee than the one you asked for.

### Q7 — Whether a refusal may cite our own program's source

You ruled: where the program knows exactly where a limit lives in **the simulator's** source
code, it says so — in brackets, at the end of the sentence. A designer who thinks a refusal
is wrong can check it in ten seconds; everyone else stops at the bracket.

One message cites **XSCHEM's own netlister** instead of the simulator's. It is bracketed and
sentence-final, so it already obeys the shape of your rule — but your rule's subject was the
simulator. Widening it is a one-word change to your own ruling, and it is yours to make.

### Q8 — One sentence reads awkwardly

| | |
|---|---|
| **Now** | `Measure Value at a point, Minimum, Maximum or Average there` |
| **Suggested** | `Use Value at a point, Minimum, Maximum or Average there` |

Every word in that sentence is an existing, already-approved label — it was rebuilt out of
them deliberately, so no new wording was invented and nothing can go stale. The cost is a
clumsy verb pairing that the old version did not have. Smoothing it means one new word, which
is why it was brought to you rather than fixed.

---

## C. The warning line before a run

### Q9 — Three warnings, their fixes, and the shape of the line

These are checked from your circuit before anything starts, so you get the warning *before*
the run instead of hunting for it in a log afterwards.

| Warning | Fix offered |
|---|---|
| `this circuit has no AC source` | `put ac 1 on the input source (any magnitude will do)` |
| `this circuit has no <x> to sweep` | `name a voltage source, a current source, a resistor, or temp` |
| `this circuit has a CIDER numerical device, and the KLU solver exits outright on one` | `select the sparse solver for this run` |

Two more parts of the same decision:

- **A suffix added to a warning that might be wrong:** `(read from the netlist text, which
  cannot see inside an .include)`. It is there because the check reads your netlist as text
  and genuinely cannot see inside an included file — so it says so, rather than refusing work
  that would have succeeded.
- **The shape of the line itself:** `ase: the ac analysis: <warning>. Fix: <remedy>`

---

## D. Simulation > Options…

### Q10 — Should this window tell you a row carries a name?

**Background in one sentence:** an analysis row can carry a name you gave it, and until
recently opening Options… on such a row listed that name as if it were an editable setting
and then refused to save. That is fixed; the name is no longer listed. The question is
whether anything should be said instead.

| | Option | Cost |
|---|---|---|
| **A** | **Say nothing new** *(recommended, and what ships today)* | none |
| **A′** | Say nothing, but show the existing `+ verbatim: 2 lines` note in one more place, where it is currently missing | no new wording at all |
| **B** | A read-only line at the top of the window, e.g. `HANDLE: vinsweep` | one new sentence, one more place the name is spelled |
| **C** | List the name again, greyed out and not editable | closest to the old pixels — and the shape that made the old list look like an editor when it was not |
| **D** | A, plus a sharper refusal if you type the name in by hand | one new sentence |

*Why A is recommended: three windows showing three spellings of the same thing would be worse
than none, and the old list was never an editor for these anyway — it refused to save.*

### Q11 — The pre-deck settings copy

Some simulator settings have to be made *before* your circuit is read, so they cannot go in
the deck. They go into a small start-up file beside the run. This is everything that mechanism
says to you.

**Two refusals** — why the file will not be written at all:

```
this bench names no run directory, so the file would go in one shared with every other
cell; set a run directory first

the simulator entry is set to skip start-up files, so this file would be ignored in silence
```

**One refusal about a single setting:**

```
it is set by <control>, not by the options sheet
```

**Three report sentences in the run log:**

```
option '<name>' will not reach the simulator: <reason>
pre-deck settings for this run are in <path>
<path> was not written by ASE-L, so it was left alone and nothing was written into it
```

…and when it hides a file of your own, that second line gains:
`; it shadows <your file> for this run`

**The banner written into the file itself**, which you will see if you open it:

```
* ASE-L pre-deck settings -- rewritten every run, deleted every run
*
* copied from <your file> -- this file shadows it for this run
```

**Also a phrase used as a location label:** `in the run-directory start-up file`

### Q12 — Does "skip start-up files" also block command-line settings?

The mechanism half of the same work as Q11. **Not a wording question** — it changes what
actually runs.

Your ruling said the start-up **file** is refused when the "no start-up file" switch is in
force. It did not say whether the settings the program passes on the **command line** should
be refused alongside it.

**Measured, on both simulator builds:** that switch suppresses the start-up file and
**nothing else**. A setting passed on the command line at the same time is honoured, and the
simulator says so in its own log.

What ships today refuses **the file only** — which is your ruling's own words, read
narrowly. Refusing the command line too would refuse a door that is measured to work, and
would remove a setting the program already depends on elsewhere.

**Confirm the narrow reading, or widen it.**

---

## E. The S-parameter bench

### Q13 — `Noise figure (2 ports only)`

⚠ **This is the only piece of text in the whole review with a measured defect behind it.**

| | |
|---|---|
| **Now** | `Noise figure (2 ports only)` |
| **Recommended** | `Noise figure and correlation matrix` |

**Why it matters:** ticking that box does two things, not one. It adds the noise figure
numbers — which really do need exactly two ports — **and** it adds the noise correlation
matrix, which the simulator produces at **any** port count. Measured at two, three and four
ports on both simulator builds.

So on a three-port bench, the label is telling you **not to tick the only control that would
give you the nine values you want**. Nothing was changed, because the wording is yours.

| | Option |
|---|---|
| **a** | Leave it — "noise figure" names those four numbers precisely, and a warning already explains the rest |
| **b** | `Noise figure and correlation matrix` *(recommended — true at every port count)* |
| **c** | `Noise data (figure needs 2 ports)` |
| **d** | Make the bracket appear only when there really are two ports — most accurate, and the only one that needs new code |

---

## F. Campaigns

### Q14 — What a dead simulator costs you

If a registered simulator never answers, the program waits **30 seconds for it — once per
point in the campaign**. Measured: a two-point campaign took 64 seconds, almost all of it
waiting. A hundred-point campaign would spend **fifty minutes** waiting for a program that is
never going to reply.

| | Option |
|---|---|
| **A** | *(recommended)* Ask once per campaign and remember the answer for that campaign only |
| **B** | Remember it until the simulator entry changes — bigger blast radius: one briefly-busy program stays condemned |
| **C** | Check once up front and refuse before anything runs — **arguably the best experience, and it needs words from you**, roughly *"this simulator did not answer; the campaign was not started"* |
| **D** | Do nothing — what happens today |

A and C are not exclusive. ⚠ **Option C's sentence has not been written**, so there is no
proposed wording to show you yet.

### Q15 — Do file headers count as copy you ratify?

A campaign writes an index file listing every point. It opens with two comment lines you read
as English:

```
# ASE-L campaign index -- one row per point, run or not
# a '-' in exit or raw means that point produced nothing
```

Everything else in this review is text **on screen**. This is text **on disk**. Whether that
is in scope at all is your call, and this question exists so it gets asked rather than assumed.

---

## G. The release note

### Q16 — Where the release note ships

A short note has been written describing which ngspice ASE-L works with. **Where it goes is
not a wording question.** The repository's `Changelog` is upstream XSCHEM's own per-release
file, kept by its author — so ASE-L writing into it is a maintainer's decision, not ours.

Until you say, the note sits in the working directory and ships nowhere.

---

# Three of these are not really wording

They arrived on the wording queue, but none of them is a question about words. Flagging them
so you can answer them differently — or hand them back.

| Question | What it actually is |
|---|---|
| **Q12** — does the "no start-up file" switch also block command-line settings? | A **mechanism** decision. Measured: the switch does not block them. What ships follows your own ruling's exact words; confirming or widening it is a one-line answer |
| **Q14** — the dead-simulator cost | A **time and behaviour** decision. Only one of its four options produces any new text |
| **Q16** — where the release note ships | A **destination** decision, and a maintainer's call about someone else's file |

---

# One thing I could not supply

**Q5** — the bare `Start` caption. No replacement wording exists anywhere in the record, so
there is nothing to show you side by side. I did not invent one.

Everything else quoted above was read out of either the shipped program or the collected
wording document, never out of a description of it.

---

# Reference

For whoever implements the answers. Nothing in this column needs to mean anything to you.

| Question | Queue entries it settles | Where the text lives |
|---|---|---|
| Q1 | `R9_section_a_new_copy` (A1) | `R9-727`, `R9-728` |
| Q2 | `R9_section_a_new_copy` (A5) | `R9-729`, `R9-730` |
| Q3 | `1408`, `R9_section_a_new_copy` item 12 | `R9-731`, `R9-732`, `R9-733` |
| Q4 | `R9_choose_analyses_status_strings` | `src/ase.tcl:10502-10521`, unhandled |
| Q5 | `R9_section_a_new_copy` item 7b | `R9-002` |
| Q6 | `R9_section_a_new_copy` item 5 | `ase.tcl:12767`, `:14351`, `:28440` |
| Q7 | `R9_section_a_new_copy` item 8 | the `d_cosim` notice |
| Q8 | `R9_section_a_new_copy` item 9 | `R9-361` |
| Q9 | `1423`, `1425` | issue files only — not in the collected document |
| Q10 | `1450` | issue file only — not in the collected document |
| Q11 | `1439` (copy half) | `src/ase.tcl:6857-6872`, `:6935-6951`, `:24960`, `:24997` |
| Q12 | `1439` (mechanism half) | ⚖ R2 condition 4 |
| Q13 | `1457` | `R9-411` |
| Q14 | `1463` | issue file only — option C's sentence unwritten |
| Q15 | `1462` / the survey | `R9-742` |
| Q16 | `1471_release_note_destination` | `RELEASE_NOTE.md` |
| **The collected document** | the other 36 entries | `doc/claude/ase_analyses_batch/R9_COPY_REVIEW.md` |

**The 36 already collected:** 1401, 1404, 1416, 1417, 1418, 1419, 1420, 1426, 1427, 1428,
1429, 1430, 1432, 1433, 1434, 1435, 1437, 1441, 1442, 1443, 1448, 1451, 1452, 1454, 1459,
1460, 1464, 1465, 1466, 1467, 1469, 1470, 1471, 1472, 1473, 1474.

**Read against** `doc/claude/ase_analyses_batch/R9_COPY_REVIEW.md` and `src/ase.tcl` at
revision `ed77ec5a`; re-checked unchanged at `0e985165`.
