# Triage of the owed queue — 2026-09-22

**What this is.** Your `rule` and `look` queue holds **248 entries stamped to this clone**
(189 decisions owed by you, 59 things owed to your eyes), the oldest three weeks old. This
document sorts every one of them into four piles and then collapses the survivors into a
short list of questions you can actually answer.

**Read Part 1 and stop.** Parts 2–7 are the working: which entries were retired, why, and
what could not be determined. Nothing in them needs to mean anything to you.

**Nothing was cleared.** This pass was read-only. Clearing a `rule` or a `look` is yours and
nobody else's, and a destroyed debt cannot be reconstructed — so every entry named "dead",
"duplicate" or "answerable without you" below is a *recommendation*, sitting untouched in the
store until you say otherwise.

| pile | count | what it means |
|---|---|---|
| **Dead** | **25** | The question was overtaken — the code changed, a later ruling answered it, or the issue it points at is closed |
| **Duplicate** | **21** | It asks the same thing as another entry, which should survive instead |
| **Answerable without you** | **23** | Internal engineering with a clearly correct answer. These should never have been queued |
| **Genuinely yours** | **179** | It changes something you see or experience, and nothing since has settled it |

179 survivors is not 179 conversations. They are **four features' worth of work**, and they
collapse into **two framing questions, nineteen decisions, and twenty-two short sittings in
front of a screen** — about **two hours of deciding and two hours of looking**, and the two
framing questions can cut the first of those in half.

**Start with the two framing questions (A-0 and B-0) and the one thing I would not leave
sitting (D-1).** Everything else can wait for whenever you have the screen time.

---

# PART 1 — THE SURVIVORS

## How they group, and why the order matters

| theme | survivors | what it collapses to |
|---|---|---|
| **A. The Results Display Window** (the operating-point dump pane, its buttons, and its shared settings file) | 54 decisions + 28 looks | 1 framing question, 6 decisions, 9 sittings |
| **B. ASE-L's new on-screen wording** (⚖ R9) | 49 decisions | 1 framing question, then 16 questions already written up |
| **C. ASE-L behaviour that is not wording** | 21 decisions + 21 looks | 6 decisions, 13 sittings |
| **D. Stock xschem: what `Simulate` runs, and what a path may contain** | 6 decisions | 1 urgent item, 3 decisions |

*130 decisions + 49 looks = 179.*

**Answer A-0 and B-0 first — in that order — and they reframe everything under them.** Both
are questions about *how you want to be asked*, not about the features. A-0 decides whether
the 54 Results-window decisions become a conversation or a look; B-0 decides whether 49
wording entries become 16 questions or none. Every question below them is written assuming
you have not yet answered either, so answering them changes the framing of the rest — which is
why they lead.

---

## A. The Results Display Window

**What it is, in one paragraph.** Annotate a schematic (press `6`), then press `1` over a FET,
and a separate window opens holding that device's operating-point numbers as a text block you
can select and paste into a design review. It has a column of buttons that edit which
parameters get drawn, and it saves those lists to a settings file you can share with
teammates. The feature is **complete and in the tree** — `op_param_batch` closed on
2026-09-04 — and it has been waiting on you ever since.

**Why 54 decisions.** Every one of them was filed the same way: a crew had to make a choice
no instruction covered, made it, shipped it, and wrote down what it chose so you could
overrule it. None of them blocks anything. **They are a record of driver decisions, not a set
of gates** — which is exactly what A-0 is about.

---

### A-0 — Do you want to review the 54 choices, or just look at the window?

**The question, plainly:** while this window was built, the people building it made 54 small
choices you never saw — where a button sits, what a sentence says, whether pressing Up also
re-orders a dump you are still reading. Every one shipped. Do you want to read them, or would
you rather open the window once, use it, and say what is wrong?

| | option | what it costs you |
|---|---|---|
| **A** | **Look, don't read** *(recommended)*. You open the window, work with it for half an hour, and say what jars. The 54 written-down choices become background material, consulted only when you flag something | ~50 minutes at the screen. You may not notice a choice that is wrong in a state you don't happen to reach |
| **B** | Read them. Six of them are genuinely load-bearing and are listed as A-1…A-6 below; the other 48 are wording and micro-interaction | ~3 hours, most of it on decisions you will agree with |
| **C** | Both — look first, then read the six | ~1h 15 |

**Recommendation: A, or C.** The reason is not the clock. Forty-eight of the 54 are *"we chose
X, here is why, overrule if you like"*, and the honest test of them is whether the window
annoys you — which no amount of reading settles. The six below are different: each one changes
where a file lands, what a saved list does, or whether the keyboard goes where you expect, and
none of them is visible from a single sitting.

**Needs your eyes?** Option A is *entirely* eyes. Options B and C can be answered from the
descriptions.

---

### A-1 — Where should the shared parameter-list file live?

**The question, plainly:** when you press Save in that window, which directory should the file
go in — the folder your design is in, or your home folder?

**Why it is a question at all.** The file was designed to be shareable with teammates, so it
was given a "project" location. But nothing in xschem defines what "the project" is, so the
code picks the directory xschem was launched from. **Measured: launched the ordinary way, that
directory is your home folder** — so the file lands at `~/.xschem/op_param_lists.conf` and
*every design on this machine reads it back*, including an unrelated project that has its own
`.xschem` folder. The window tells you this in its status line; it does not stop it.

| | option | cost |
|---|---|---|
| **A** | Keep today's behaviour and keep the warning sentence | One shared file per machine. A setting you make for one chip silently applies to every other |
| **B** | *(recommended)* Make it the directory of the schematic you have open | Matches "shareable with the team" — the file travels with the design. Costs: two people with the same design in different folders get different files |
| **C** | Always your home folder, and drop the pretence of a project tier | Simplest and honest. You lose the ability to give one design its own lists |

**Recommendation: B.** Your stated reason for the file was sharing it with teammates; a file in
your home folder is the one place a teammate never gets.

**Settles:** `1273`, `1325`, `1388`. **Eyes: no.**

---

### A-2 — Should that file be read back when xschem starts?

**The question, plainly:** today nothing reads the file at launch. You can Save your parameter
lists, and the next time you start xschem they are ignored.

| | option | cost |
|---|---|---|
| **A** | *(recommended)* Add a **Reload parameter lists** button beside Save | Small, stays inside this window, and you choose when it happens |
| **B** | Read it automatically at every launch | What you would expect — but two known rough edges then fire on every launch instead of only after a button press |
| **C** | Leave it. The lists last one session | Saving becomes a way of writing a file nothing reads |

**Recommendation: A**, then **B** once the two rough edges are fixed. **Settles:** `1313`.
**Eyes: no.**

---

### A-3 — When two patterns match the same device, which one wins?

**The question, plainly:** the file lets you write rules like *"for anything matching
`*nfet*`, show these parameters"*. Two rules can match one device. Today **the one higher up
in the file wins**, and no code tries to work out which is more specific — so a bare `*`
placed first beats a precise pattern.

**Why it is a question.** Two separate attempts were made to rank patterns by "narrowness",
and both produced an order where `*` beat a specific pattern, because "narrower" has no
defensible definition over wildcards. File order is the honest answer, and the window already
gives every list Up and Down buttons, so you set precedence by dragging and can see it in the
file.

| | option | cost |
|---|---|---|
| **A** | *(recommended, and what ships)* First in the file wins | To make a specific rule win, put it above the general one. Nothing is magic and nothing is guessed |
| **B** | Rank by specificity | Measured twice, refuted twice. Not available without inventing a rule about pattern *shape* rather than length |

There is a second half, and it is the one worth a moment: **your personal file is read before
the project's**, so your own rules are tried first and a project file can only outrank yours by
using the identical pattern. The alternative lets a shared team file silently override a
narrowing you wrote for yourself.

**Recommendation: A, and keep personal-before-project.** **Settles:** `1275`, and the two
duplicates behind it. **Eyes: no.**

---

### A-4 — After a dump, who should have the keyboard?

**The question, plainly:** when you press `1` and the window appears, should typing go to the
window or stay on the schematic?

**Why it is genuinely yours and cannot be settled here.** You asked for two things in one
sentence — that the window come to the front, and that it not steal the keyboard. On the test
display those are compatible. **On your screen they may not be**: your X server has no window
manager answering a polite "come forward" request, so the only way to raise the window is to
re-map it, and a re-map takes the keyboard with it. Today the code catches that and hands the
keyboard back to the schematic, winning a race by **0.7 ms** on a local test display — which is
not evidence for a server reached over the network.

**What it looks like if it is wrong:** after a dump, pressing `1`/`2`/`3`/`4` or Escape does
nothing until you click the schematic first.

| | option | cost |
|---|---|---|
| **A** | *(recommended)* Keep today's shape: the window rises, the keyboard goes back to the schematic, and you click the window before Ctrl-C | Consistent with the rule already set for this window. One extra click before copying |
| **B** | Let the keyboard stay in the window | Copying works immediately; the digit keys and Escape stop working until you click back |
| **C** | Do not raise the window at all on your server | Nothing is stolen, and a buried window stays buried |

**Recommendation: A**, but **this one needs your eyes first** — the answer depends on what your
own server actually does, and no test here can tell us.

**Settles:** `1340_R4…`, `1358`, `DD-1_rdw…`, `DD-3_rdw…`, and look sittings A-L5.
**Eyes: yes — and before answering.**

---

### A-5 — May an older dump re-order itself under you?

**The question, plainly:** press Up on a row, and every *other* dump of the same kind of device
already on screen re-orders too — including one you are in the middle of reading.

**Why.** The parameter order is a setting for a whole class of device, not for one dump. If
only the dump you pressed moved, the window would show the same class in two different orders
at once, which the setting cannot support. The cost is that something you were reading changes
without your touching it.

There are three more facets of the same thing, all measured and all pointing the same way: a
*new* dump after a re-order arrives in the simulator's order and contradicts the blocks below
it; a re-order on the "summary" list moves rows in the window that the schematic cannot
follow; and pressing Add re-sorts the pane by a different list than the one named above it.

| | option | cost |
|---|---|---|
| **A** | *(recommended)* Re-order everything of that class, including new dumps, so the window is never self-contradictory | An older dump changes under you |
| **B** | Move only the dump you pressed | Two orders for one class on screen at once, with nothing saying why |
| **C** | Move nothing; the order applies to the next dump | Pressing Up appears to do nothing |

**Recommendation: A, extended to new dumps too** — the half that is missing today.
**Settles:** `1338_R2…`, `1347_R2…`, `1350_R2…`, and look `1349_the_pane_order_flips…`.
**Eyes: helpful, not required.**

---

### A-6 — Deleting the last parameter of a device

**The question, plainly:** the Delete button refuses to remove a device's *last* remaining
parameter, with a short message. Should it?

**Why it refuses.** If the block became empty, the device would drop out of the declutter — so
pressing Delete to see *less* would make every hidden label on that device reappear. The
alternative, treating an emptied list as "no narrowing", makes the button do nothing at all.

| | option | cost |
|---|---|---|
| **A** | *(recommended, and what ships)* Refuse, and say so | You cannot empty a list from the UI. To show nothing on a device, turn its annotation off |
| **B** | Allow it, and accept the device un-decluttering | One Delete makes the sheet busier, not quieter |

**Recommendation: A.** **Settles:** `1285_empty_display_key` and its duplicate.
**Eyes: no.**

---

### A-7 … the other 48

Wording and micro-interaction: seven sentences the window prints, ten on the button column,
four in the shortened preamble, the engineering-number format, the greying as you switch
lists, the shade on the row your cursor is in, the Close button's position, the status-line
hint on the schematic. **All of them are judged better by looking than by reading**, which is
what A-0 is about. If you answer A-0 with option A, these fold into the sittings below and
need no separate answer.

### The sittings — A-L1 … A-L9

Twenty-eight look entries, one window. Set it up once: annotate (`6`), press `1` over a FET.
**Do this on your own screen** — every measurement behind these was taken on an invisible test
display whose fonts, window manager and timing are not yours.

| # | ~time | what to open, and what would be wrong |
|---|---|---|
| **A-L1** | 10 min | **The window as it opens.** Newest block on top; the line above the pane naming which list the buttons edit; the strip of seven controls; the grey band on your cursor's row; the dark-orange notice lines. Press `2` and watch the window get ~78 px wider, then `1` and watch it shrink back. *Wrong:* the orange reads as an error; the control strip reads as crowded; you can't find the grey band, **or** it is strong enough that you take it for a selection; the window jumping between `1` and `2` annoys you more than the extra sentence is worth |
| **A-L2** | 10 min | **The text of one block**, beside the same device on the schematic. The two-line header, the caveat sentence, the `6 of 88 columns` line, and the numbers in engineering form. *Wrong:* window and sheet print different digits for the same value; the ragged value column looks untidy once pasted; three lines of preamble out-talk six numbers; `(no value reported)` and `(did not converge)` are indistinguishable at a glance |
| **A-L3** | 10 min | **Copying out.** *Your own clipboard, and no test can stand in for it.* First copy a sentence you care about from another application. Then: drag-select and Ctrl-C; the new right-click menu; double-click a word, let go, then drag; Select All + Copy in an **empty** window; select the settings path in the bottom line and Ctrl-C; then drag several rows, press Delete, and read the long verdict. *Wrong:* the sentence you cared about is gone; what you paste stops short; the bottom line claims a copy the clipboard no longer holds; two selection-coloured regions at once |
| **A-L4** | 8 min | **Editing with the buttons.** Click a row, press Up/Down/Delete/Add. The scope pop-up; the greying; what Save writes. *Wrong:* a highlight you were mid-copy of is thrown away by a Delete that redrew identical text; Add re-sorts the rows while the title names the other list; the button column shifts under the pointer |
| **A-L5** | 8 min | **Raise and keyboard** — *your screen only, and it decides A-4.* Press `1`, click back on the schematic so the window goes behind, press `1` over another device. Does it come forward? Does it creep up-and-left? Then click **in the pane**, click back on the schematic, select another device, press `1` — does it arrive on the **first** click? Then, without clicking the schematic, press `1`–`4` and Escape |
| **A-L6** | 5 min | **The pick mode on the canvas.** ⚠ *One queue entry says "nothing to look at yet" — that is out of date; the keys landed.* With nothing selected press `1`, `2`, `3`. Press, wiggle one pixel, release — nothing may get selected. Click just off a grid point on a device body — the block must be headed with the device **under the cursor** |
| **A-L7** | 5 min | **Text size (`aA`).** Up six, down six. *Wrong:* values stop lining up in columns; the window jumps to fill the screen; the tooltip lands off-window or never appears |
| **A-L8** | 5 min | **The status-bar hint on the schematic.** With nothing selected press `1` (then `2`, `3`) and **move the mouse around the canvas while you read the status bar**. Press Escape. *Wrong:* **any** flicker or twitch as you move the mouse — that is a real finding; the green reads as an alarm next to `DRAW WIRE!`; losing ~48 px of the coordinate readout beside it is not worth the sentence. Then narrow the main window below ~815 px until the sentence is clipped and hover it — the whole sentence should appear after one second (the `aA` button uses a third of that, on your own instruction) |
| **A-L9** | 3 min | **Tooltips near the corners of your screen** (a tree-wide change, 44 call sites). Drag the main window hard into the bottom-right corner and hover things there. *Wrong:* a tip that flickers on and off forever, one still cut off by the edge, or one that jumps to the far side of the display |

---

## B. ASE-L's new on-screen wording

### B-0 — How do you want to be asked to approve new wording?

**The question, plainly:** 49 entries on your queue all say the same thing — *"this piece of
work put new words on the screen; approve them or give different words."* They were filed one
at a time over five weeks. How would you like this to work from now on?

| | option | what it costs |
|---|---|---|
| **A** | *(recommended)* **Ship the words, collect them, and you skim.** Anything you do not mark is accepted. Only genuine choices — where two wordings mean different things — come to you as questions | You may live with a sentence you would have written differently until you notice it. Retires 49 entries today and stops the next 49 forming |
| **B** | Keep asking per piece of work | Honest, and unsustainable: it produced this queue |
| **C** | Ask once per feature, in a batch | Between the two. Roughly what was attempted; it produced 49 entries anyway because "a feature" kept being re-scoped |

**Recommendation: A.** You have said you do not want to gate progress, and wording is the one
class where an agent can be wrong cheaply and you can correct it late at no cost.

**If you choose A, everything below becomes optional reading** except the three items marked ★,
which are not wording.

**Eyes: no.**

---

### B-1 — The collection already exists, and so do the sixteen real questions

Two documents were built for exactly this and were never put in front of you:

* **`doc/claude/ase_analyses_batch/R9_COPY_REVIEW.md`** — 821 pieces of text, taken from the
  running program rather than from anyone's description of it, grouped by which window they
  appear in. ~30 minutes to skim. **Its own contents table says 410; it holds 821** — the table
  was written early and never updated.
* **`doc/claude/issue_tracker_batch/RATIFY_WORDING.md`** — the **16 questions** the collection
  does not answer, each with options and a recommendation. ~45 minutes.

**Take the order in that document, with one change: ask Q3 first.** Q3 asks whether the words
*backend* and *adapter* — our names for our own architecture — belong on your screen at all.
You have already struck *"this simulator backend"* out of three sentences; Q3 asks whether the
same objection reaches the rest. **It is a vocabulary question, so its answer changes how a
dozen other sentences are framed.** Then Q13 (below), then the remainder in document order.

### ★ Three of the 49 are not wording

| ★ | the question, plainly | recommendation |
|---|---|---|
| **B-2** (`1457`) | A checkbox reads **"Noise figure (2 ports only)"**. Measured: ticking it produces the noise figure — which does need two ports — **and** the noise correlation matrix, which the simulator produces at any port count. So on a three-port bench the label is telling you *not* to tick the only control that would give you the nine numbers you want. | **"Noise figure and correlation matrix"** — true at every port count. Eyes: no |
| **B-3** (`1463`) | A registered simulator that never answers costs a **30-second wait, once per point in a campaign**. Measured: a two-point campaign took 64 s, almost all waiting. A hundred-point campaign would wait fifty minutes for a program that is never going to reply. | Ask once per campaign and remember the answer for that campaign. Eyes: no |
| **B-4** (`1471_release_note_destination`) | A release note describing which ngspice ASE-L works with has been written. The repository's `Changelog` is upstream xschem's own per-release file, kept by its author — so ASE-L writing into it is a **maintainer's decision**, not ours. | Yours alone. Until you say, it ships nowhere. Eyes: no |

---

## C. ASE-L behaviour that is not wording

Six decisions and twelve sittings. **C-1 first** — it is the only one where the answer changes
what a button does rather than what it says.

### C-1 — May opening a dialog start your simulator?

**The question, plainly:** ASE-L can only know what your simulator is capable of by running it
once and reading the answer. Should it do that when you open **Setup ▸ Simulators ▸ Edit…**, or
only when you press **Detect**?

**Measured:** 447 ms when the program is warm, up to **31.2 s** worst case.

| | option | cost |
|---|---|---|
| **A** | *(recommended, and what ships)* Only on **Detect** | A dialog opened cold shows "nothing measured yet" until you press it |
| **B** | Probe when the dialog opens | Up to half a minute of an unexplained wait on a dialog you only meant to glance at |

**Recommendation: A.** **Settles:** `1371`, `1371_marked_mode_is_saved`. **Eyes: no.**

---

### C-2 — There is no longer any way to reset your default simulator

**The question, plainly:** you asked, in your own words, to be able to *"hand control back to
the program my system finds on my PATH, as the default, for every bench that has no opinion."*
That gesture now exists **inside a bench** and **nowhere outside one** — once you have
registered a single simulator, the installation default is pinned to it and the only way to
change it is to hand-edit `~/.xschem/ase_simulators`.

| | option | cost |
|---|---|---|
| **A** | *(recommended)* Add a **Make this the default** control to Setup ▸ Simulators | One button, one saved line. Restores the gesture you asked for |
| **B** | Rule that the default is only ever set by the saved list and the startup file, and a user who wants it changed edits that file | Honest, and it removes a capability you explicitly requested |

**Recommendation: A.** **Settles:** `1395-default`. **Eyes: no.**

---

### C-3 — A value you typed into a folded section is remembered and not saved

**The question, plainly:** open an analysis form, expand **Advanced**, type a value, fold it
back, press OK. The value is shown back to you next time — and was never written.

This is a defect with a decision inside it: whether OK should write what the *form remembers*
or only what is *visible*. Writing what it remembers is what you would expect; it also means OK
can write a field you deliberately collapsed.

**Recommendation: write what the form remembers, and stop folding a section that holds a
value.** **Settles:** `1446`. **Eyes: no.**

---

### C-4 — Should the operating-point dump start working on folders with spaces and capitals?

**The question, plainly:** ASE-L currently **refuses** its fast operating-point dump when the
run folder's name contains a space or a capital letter, and asks you to rename the folder. The
underlying simulator-path defect that made it refuse was fixed on 2026-09-20 (`a1314271`), so
the refusal may now be liftable — which would make the feature start working where it presently declines.

**Recommendation: lift it, after one measurement on a folder with a space in it.** This one
needs a measurement, not a ruling — say the word and it is taken. **Settles:** `1334`.
**Eyes: no.**

---

### C-5 — Should picking an older run also repoint the Value column?

**The question, plainly:** the Outputs pane's **Value** column now reads its numbers from this
session's own results file. The plan also asked that choosing a different run under
**Results ▸ Select** repoint that column at the run you picked. The crew refused and asked
instead, because a hand-picked file cannot be checked against this session's netlist — which
is the same class of wrong-number defect the change just fixed.

| | option | cost |
|---|---|---|
| **A** | *(recommended)* Leave the column on this session's own run | The column and the waveform window can show different runs |
| **B** | Repoint it, with a visible warning that the numbers may not match the circuit on screen | You get what you asked for, and a plausible wrong number becomes reachable again |

**Recommendation: A** — and if B, only with the warning. **Settles:** `1498`. **Eyes: no.**

---

### C-6 — Two small ones that are really questions about how *you* work

* **`1390`** — do you ever use `-casemode distinguish`? A check that folds letter case
  unconditionally is correct for everyone who does not, and the third option costs real code.
  **One word from you closes it.**
* **`1393`** — do you ever open **two ASE-L sessions on one hierarchy**? A measured blank-row
  defect exists there and nowhere else. **One word from you closes it.**
* **`1370_ase_prefix`** — you diagnosed a problem by reading the run log. Should every ASE-L
  sentence carry an `ase:` prefix so your own `grep` finds all of them? It is all of them or
  none. **Recommendation: yes, all of them.**

### The sittings — C-L1 … C-L13

Open a bench, launch ASE-L once, stay in it. Twenty-one look entries, thirteen sittings, ~75 min.

**Choose Analyses** (the grid, the typed forms, the precondition banner, the handle column,
the lengthened picker words) · **Simulation ▸ Options…** (the changed-rows default view, the
Find box, Show all, the three-state badge, the deck preview) · **Measurements** · **S-parameter
ports and the result matrix** (including the 3-port case that shows 36 cells where it used to
show 27) · **Campaigns** (the histogram — the first drawing ASE-L has ever made) · **the
transient-noise section** · **the digital strip at a run's end** · **convergence, and the
starred nodes lit on your own schematic** · **Setup ▸ Simulators after Detect** · **Save State
over an existing name** (where the confirm lands, and that Return dismisses rather than writes)
· **the action-strip tooltips** (each one sits over the next button down, covering about four
fifths of it) · **the log window rising, and who has the keyboard.**

Full per-sitting checklists, with what "wrong" looks like for each, are in
`doc/claude/issue_tracker_batch/RATIFY_LOOKS.md`, its sittings **L11 – L22** (that document
numbers straight through L1–L27; my A-L1…A-L9 and C-L1…C-L13 are the same set regrouped by
feature rather than by screen, with the retired entries removed).

**C-L13, and it is the shortest and the most specific.** Open the bandgap bench, **Session ▸
Design Window**, descend into `x1` and again into `x1` — the exact gesture from your own report
— and press **Netlist and Run**. The button now climbs to the top sheet, netlists it, and puts
you back. The only question is whether you *see* that happen: any flash of the top sheet, any
blink, any zoom or pan wobble, any window flicker between the press and the run starting. **It
must look like nothing moved**, and the schematic window must not disappear or take the
keyboard. What is measured, and cannot stand in for your eyes: one repaint for the whole
two-level trip, and the view identical to fifteen significant figures — taken on a test display
whose event traffic differs from your own server by a measured factor of three.

---

## D. Stock xschem

### ★ D-1 — Typing into an xschem dialog box runs what you type as code

**This is the one item in the queue I would not leave sitting.**

**The question, plainly:** several xschem dialogs ask you to type a value. What you type is
handed to Tcl as a *script* rather than as a value. Driven live through the shipped menu
**Simulation ▸ Set netlist / graph / annotation precision**: typing

```
7 ; set ::INJECTED yes
```

set the precision **and ran the second command**. Every dialog that uses this mechanism shares
it, including **Set top level netlist name**.

**This is inherited stock xschem code, not something this branch introduced** — and it is on
the branch you publish. Still live today at `src/xschem.tcl:14739`.

| | option | cost |
|---|---|---|
| **A** | *(recommended)* Take the one-line fix tree-wide | One line. Risk: a caller that today relies on typed text being split into several arguments would change behaviour silently — none is known, and a survey would find them |
| **B** | Survey every caller first, then fix | Safer, a few hours, and the hole stays open meanwhile |
| **C** | Leave it as an inherited sharp edge | It is your published branch |

**Recommendation: A, with the survey run alongside rather than before.** **Settles:** `1352`.
**Eyes: no.**

---

### D-2 — Should plain `Simulate` use the arguments you recorded with a simulator?

When you register a simulator you can record arguments with it. The ordinary **Simulate**
button uses the *program* and the *case mode* but **not** those arguments — it reports them as
unused instead. Carrying them is defensible (the path and the arguments are one record
describing one invocation); against it, it makes the plain button a second implementation of
ASE-L's run command. **Recommendation: report, as today.** **Settles:** `1238_args_placement`,
`1238`, `1238_composer_sentences` (five log sentences), `1238_xyce_word_scan` (a bare file path
in the command can silently stop your registered simulator being used). **Eyes: no.**

### D-3 — A model path with an unusual shape is now a hard error

Paths that used to be silently mangled — a `$` that Tcl would have read as a variable, a name
the expander stopped short on — now refuse loudly instead of becoming a filename with a dollar
in it that fails later, somewhere else, with a worse message. **Measured across 54,240 strings:
none of your committed files is affected.** Ratify the direction, or ask for a fallback.
**Recommendation: ratify.** **Settles:** `1239_silent_literal`. **Eyes: no.**

### D-4 — What may a Save create?

Two settings writers disagree about a missing parent folder: one creates it and saves, the
other refuses with a sentence. **Recommendation: neither creates a folder** — a Save that
silently makes directories is the surprising one. **Settles:** `1286`, and the related
folder-permission sentences in `0960`. **Eyes: no.**

---

# PART 2 — Something of yours that was damaged

Not questions. Facts you should know, filed under entries that are otherwise retired.

* **Fifty of your hundred-and-one saved window geometries were permanently displaced**
  (`1397`, measured 2026-09-09). Test suites had been writing into your real
  `~/.xschem/geometry` for as long as suites have opened schematics; half the file came to
  name scratch directories that no longer exist, and the hundred-entry cap evicted your own
  entries. **Not recoverable** — the file was hashed before the runs but never copied. **The
  cause is closed**: since 2026-09-18 every documented test command runs under a throwaway
  HOME. A residual gap remains for one undocumented spelling (a bare
  `./src/xschem --script …`), and `store_geom` itself still has no gate.
* **Your `File ▸ Open Recent` was filled with ten dead simulation decks** (`1453`) and your
  ASE-L simulator list was replaced by entries a test crew created. **Both were repaired on
  2026-09-17 on your instruction**, and the cause was traced and closed. One question from that
  entry survives — the wording of ASE-L's new refusal when something tries to register the
  xschem binary itself as a simulator. It is in theme C.

---

# PART 3 — The retired piles, entry by entry

## 3.1 Dead — 25

The question was overtaken. **Name of what overtook it is given for each.**

### Rule debts (22)

| entry | what overtook it |
|---|---|
| `1243` | Issue 1243 **FIXED 2026-09-02**; the Value column was then rebuilt again on 2026-09-21 (issue 1498), which is the live question |
| `1244_A5b_pin_names_vanish` | Its own text: *"Ratified by D-1, in your own words"* — filed for awareness, never a question |
| `1245_DD1_capability_declared` | Forced by your own ruling D-4 (*no guessing*) |
| `1245_DD2_class_is_the_key` | Forced by your own *"one list per major primitive type"* plus the scope dialog |
| `1245_DD4_delete_is_display` | Corrected by DD-6, then by DD-13; neither survives in the shipped shape |
| `1245_DD5_name_the_analysis` | Decision implemented; only the wording survives, as `1282_analysis_sentence_wording` |
| `1245_DD9_derived_reads_the_run` | It *is* the answer to issue 1289, which is FIXED by item B2b |
| `1277_precedence_sentence` | The character-counting precedence rule it asks about was replaced by file order (ruling DD-8, landed `21fcece6`). The sentence no longer exists |
| `1280` | Answered by DD-4 → DD-6 → DD-13; issue superseded |
| `1285` | Issue 1285 **FIXED by item B2b, 2026-09-03** — `op_annot::text` reads a separate `shown` key today |
| `1288` | Issue 1288 **✅ CLOSED 2026-09-04 by item B5-3** |
| `1289` | Issue 1289 **FIXED by item B2b under ruling DD-9** |
| `1296` | **RULED AND HALF-FIXED 2026-09-04 under DD-11** — a closed ruling, not an open question |
| `1312` | **✅ FIXED by item B2e, 2026-09-04**; the entry that asks about it says so itself |
| `1314` | Asked which of three routes to take to re-land the button column. The route was taken: store fix first (B2e), then B5-a, then B5-3 (`05949661`). Feature B is complete |
| `1326` | **✅ FIXED 2026-09-04 by item B5-3 under ruling DD-15** |
| `1397` | Overtaken by `7a46275f` (2026-09-18) — the throwaway HOME is the very fix this entry names as its preferred option. **The damage it reports is still yours to know: Part 2** |
| `1400` | Fixed by `47480371` (per-clone stamps, cross-clone refusal, `cleared.log`). Its remaining question — who renumbers 1333–1348 — is answered by policy: `NUMBERING.md` states *"This branch does NOT renumber"* |
| `1458` | Its own stamp reads `claim=duplicate super=1397`; overtaken by the same `7a46275f` |
| `DD-4_rdw_only_lists_1_and_2_rerender_the_sheet` | Your own words; cost recorded as "none known" |
| `DD-6_rdw_raise_without_activation` | Your instruction (*"no need to focus"*), and superseded by `1340_R4…`, which survives |
| `R9_preexisting_unhandled_copy` | Its own text: **RULED BY YOU 2026-09-16** — *"Give them their own pass, later."* It is a reminder, not a question |

### Look debts (3)

| entry | what overtook it |
|---|---|
| `1341_R5_the_window_says_did_not_converge…` | Repaired. Rule `1345_window_prints_what_the_sheet_blanks` says outright that it answers this and that both should clear together |
| `rdw_1356_selection_note` | The one-line status strip it measured no longer exists — it is a wrapping panel with a scrollbar (issues 1362 → 1365) |
| `rdw_1356_note_cut_off_measured` | Same. Its own question was measured by the entry above, then answered by the rebuild |

## 3.2 Duplicate — 21

**The entry that should survive is named.**

### Rule debts (15)

| entry | duplicates | keep |
|---|---|---|
| `0960_catchall_sentence` | `0960` — titled *"CORRECTION TO RULE DEBT 0960"*; one question covers all three sentences | `0960` |
| `1239` | `1239_silent_literal` — titled *"CORRECTION TO RULE DEBT 1239"*, and it widens the question | `1239_silent_literal` |
| `1245_B1_nonfinite_render` | `1341_nonfinite_in_the_devices_bucket` — the later one shipped and is fenced by a test row | `1341_…` |
| `1245_DD8_precedence_is_file_order` | `1275` item (2), which states the same rule with its consequence | `1275` |
| `1245_DD10_delete_refuses_last_row` | `1285_empty_display_key` — DD-10 is the driver's answer to that question | `1285_empty_display_key` |
| `1245_DD12_escape_ends_mode` | `1308` / `1340_R4…` — one keyboard question | `1340_R4…` |
| `1245_DD15_duplicate_label_refused` | `1326` (now dead) — it is that issue's answer | — |
| `1245_DD16_cross_sheet_edit` | `1322` | `1322` |
| `1257` | `1257_A7_armed_no_values`, which carries the state that shipped | `1257_A7…` |
| `1282` | `1282_analysis_sentence_wording` — the specimen 1282 quotes was refuted by measurement | `1282_analysis_sentence_wording` |
| `1308` | Same keyboard question as `1340_R4…`, and settled in the code under DD-12 | `1340_R4…` |
| `1344` | `1351@xschem-claude`, which says in its own text that it is *"a THIRD answer to the question look debt 1344 already asks you"* | `1351@xschem-claude` |
| `1362` | `1365` — 1365 says it *removed the thing you were being asked to ratify* | `1365` |
| `1369` | Not a ruling at all: it asks for a measurement only you can take. It is look `the_RDW_raise_behaviour` | the look |
| `1370_none_word` | `1370` — same status-bar segment, same one-line change | `1370` |

### Look debts (6)

| entry | duplicates | keep |
|---|---|---|
| `1338_R2_window_vs_sheet_disagree` | Two of its four findings shipped as fixes; the other two are rule debts `1347_R2…` and `1350_R2…`, not eyes | the two rules |
| `1340_R4_adversary_the_keyboard_after_a_dump` | `1369_the_keyboard_after_a_dump_on_your_own_server`, which says outright *"This also answers the standing debt 1340_R4_adversary…"* | `1369_…` |
| `1343_rdw_raise_on_your_own_server` | `the_RDW_raise_behaviour` — same gesture, same code | `the_RDW_raise_behaviour` |
| `ASE-L_Save_State_overwrite_confirm_popup` | `ase_l_1396_overwrite_confirm`, filed two days later, asking everything this one does and three things more | `ase_l_1396_overwrite_confirm` |
| `rdw_1362_status_wrap` | `rdw_1365_status_scroll`, whose first line reads *"SUPERSEDES look debt rdw_1362_status_wrap — please read this one instead"* and voids two of its checks | `rdw_1365_status_scroll` |
| `the_RDW_select_and_copy_on_VcXsrv` | A 54-character placeholder filed before the fix existed; the full version is `1339_R3_select_and_copy` | `1339_R3_select_and_copy` |

## 3.3 Answerable without you — 23

Each lives entirely inside the implementation or the test harness. **The answer is given; no
question needs to reach you.** **Eight** of the 23 are test-harness mechanics — `1375`,
`1377_isolate_opt_in`, `1377_repo_root_litter`, `1385`, `1399`, `1431`, `1440`, `DD-8` — which
is the literal subject of *"I don't get into the weeds of the test-suites."* (Three more,
`1397`, `1458` and `1400`, are the same kind and are counted in the dead pile because the code
overtook them.)

| entry | the answer |
|---|---|
| `1240` | Split the two consumers of `update_op()` so each of your rulings holds on its own path. An interim already honours the ruling; nothing you see is waiting |
| `1244_A5c_recompute_syncs` | Leave the sync where it is. One struct compare per instance is free; hoisting is the caller's optimisation if it ever measures |
| `1245_B3_add_greyed_on_list1` | Keep the button greyed rather than absent, so the column does not move under the pointer |
| `1245_DD3_settings_file_is_data` | Forced: a shared file that gets *sourced* is arbitrary code execution on whoever opens the project |
| `1245_DD6_display_field` | Internal data model — a descriptor key the display prefers. Already landed |
| `1245_DD7_save_is_read_modify_write` | Forced: two crews serialising a merged model both deleted rows the user had typed. You cannot delete a row you never parsed |
| `1245_DD11_version_line_is_ours` | Correct and settled: rewrite the machine `version` line, never your comments |
| `1245_DD13_three_lists` | Internal data model — three lists, not two. Already landed |
| `1245_DD14_recipe_unsets_declared` / `1315` | The recovery recipe is printed in PDK startup files and read by a PDK author, not by you. Keep the `unset` line |
| `1288`⁺, `1296`⁺ | *(listed as dead above; both were internal contracts)* |
| `1328` | Wrap each shipped PDK registration site in a `catch` that reports and continues — the entry's own recommendation. No shipped PDK hits it. **Still unimplemented** |
| `1375` | Suppress modal dialogs under `--script`. **Still open in the code** (`src/actions.c`) and it is the root cause of `1440` |
| `1377_isolate_opt_in` | Make the test fixture clear the simulator registry **by default**, with an explicit opt-out for the suites that are *about* the registry |
| `1377_repo_root_litter` | Removing the stray files was right. The littering itself is now issue **1486** — repo root is clean today, `tests/untitled~.sch` is not |
| `1385` | Pin a window geometry in the fixture. **Not** covered by the throwaway HOME: cases inside one run still share it |
| `1399` | Two test rows have failed on the display arm since before the batch that found them. Diagnose, then force the race deterministically. **`test_wave_sigbrowser_0312` is still not in the regression case list**, so these reds are invisible to it |
| `1431` | Re-baseline the one-nanosecond golden |
| `1440` | Closes when `1375` does |
| `1397`⁺, `1458`⁺ | *(listed as dead above; both were test isolation)* |
| `DD-2_rdw_cursor_shade_derived_from_palette` | Forced — a literal grey is invisible in a dark scheme |
| `DD-5_rdw_ctrlc_writes_CLIPBOARD_and_a_menu_exists` | A bug fix, not a preference |
| `DD-7_rdw_eng_notation_must_not_blank_anything` | Forced by an existing defect |
| `DD-8_rdw_copy_measured_on_the_real_X_server` | Test method |
| `1349_Delete_and_Add_now_wipe_the_pane_selection` *(look)* | Make the repaint conditional on the blocks actually changing. Destroying a selection you are mid-copy of, in the window whose purpose is copying, is a defect rather than a preference |

⁺ Cross-references only — those four are counted once each, in the dead pile.

*The table has **24 rows**. Two are uncounted cross-references, leaving 22 counted rows; one of
those (`1245_DD14…` / `1315`) carries **two** ledger ids. **24 − 2 + 1 = 23.** The count is
taken from the ledger ids, not from the row count — a bundled table row is not one item.*

---

# PART 4 — The five `results_batch` look debts

**Finding: they were never in this store, and nothing destroyed them.**

The batch record names five, filed on 2026-08-20, and `~/.claude/xschem_owed/look/` holds no
`results-item*` entry. The `cleared.log` has no record of them either, and its earliest record
post-dates their ids by three weeks. The explanation is simpler than a destruction:

| fact | measured |
|---|---|
| The five were filed | **2026-08-20**, 00:59 – 06:06 |
| This clone was created | **`git clone`, 2026-09-01 09:56:17** (`git reflog` tail) |
| `~/.claude` was created | **2026-08-31 19:06:26** (inode birth) |
| `~/.claude/xschem_owed/` was created | **2026-09-01 10:32:41** (inode birth) — 36 minutes after the clone |
| `~/.claude/xschem_owed/cleared.log` was created | **2026-09-11 07:10:18** (inode birth) |
| Oldest surviving entry in the store | **2026-09-01 17:37** (`rule/1240`) |

**The store is younger than the debts.** Every entry it holds was filed on or after
2026-09-01, and both `~/.claude` and the clone predate it by hours, not weeks. The
results_batch ran against a home directory this machine no longer has. `cleared.log` is
genuinely append-only for everything it recorded — 23 records, all narrowly scoped, no purge
event, no mass overwrite — but it could not have recorded an event that happened three weeks
before it existed.

**A second, unrelated event is visible and is *not* this one.** Roughly 57 look entries and 3
rule entries share mtimes in a 14-second window at **2026-09-10 12:18:24–12:18:38** — a bulk
restore from backup, consistent with the destroyed-ruling incident recorded for that date. None
of the restored files is a `results-item*` entry.

**`owed.sh` has no code path that could have done it.** Reading the whole script: the
subcommands are `add`, `list`, `show`, `count`, `clear`, `drain`, `restamp`, `help`. There is no
purge, no TTL and no sweep. `clear` writes a pre-image to `cleared.log` before the `rm` and
dies if that write fails; `drain` touches only `suite` entries; `add` can overwrite an entry of
the same id from the same clone, and logs it. Nothing deletes a whole directory.

### What a reconstruction would need — and it needs nothing

**The full text of all five is preserved in the repository**, in
`doc/claude/results_batch/EYEBALL_SIGNOFF.md` (committed at `30d87dee`, present in both clones).
It carries each debt's exact id — epoch and pid suffix included — as a literal
`owed.sh clear look <id>` line, followed by the checklist that debt was asking you to work
through:

| id | what it asked you to look at |
|---|---|
| `results-item7-select-dialog` | The **Results ▸ Select** dialog: region order, the coloured bullet on the current session's row, whether already-loaded rows look different, the three Status-line wordings, double-click behaviour — and one thing the batch flagged as unprovable by any test: *"Hover a Loaded row and wait. A balloon must appear showing the full path. If it does not appear, that is a real defect."* |
| `results-item7-fixer-round-two-gestures` | Two regressions the fix round introduced and fixed: typing a path and pressing Return must keep saying *"Selected an.raw (tran)"* and not flip to *"Using an.raw"* a quarter-second later; a refusal for a non-existent path must persist rather than be erased |
| `results-item8-waves-gate-refusal-notice` | With `cadence_compat` on, **Waves ▸ Tran** must raise an alert rather than load — read the sentence, confirm it names the setting twice and points at **ASE-L ▸ Results ▸ Select** |
| `results-item8-fixer-round-refusal-sentence` | With no ASE-L window open, the box must add a clause pointing at **Tools ▸ Launch ASE-L** — *"Judge whether you could actually follow that from here. That clause is the whole reason the fix round happened"*; and clicking **Waves ▸ Op Annotate** behind the open box must retext the same box rather than raise a Tk error |
| `results-item6-restore-writes-raw_history` | After restoring a saved ASE-L session, the restored result must appear in the waveform viewer's Location drop-down **exactly once**, and stay once across a second restore |

**So a reconstruction needs no forensics.** If you want these back on the queue, five
`owed.sh add look` calls transcribed from that document restore them exactly, with the
checklists staying where they are.

**What is genuinely unrecoverable:** whether anybody ever looked. The batch's own close-out
records *"Eyeball debts: 5, all unpaid"* on 2026-08-20, its tracking table was left with a
blank row, and nothing after that date records a disposition either way. **My reading: they
were never paid, and they were never destroyed — they belong to a ledger this machine no longer
has.**

---

# PART 5 — Entries whose issue file or `ref:` does not resolve

**Every `ref:` on the 248 entries stamped to this clone resolves** to a file that exists in
this working tree. There are no dangling references in your own queue.

Four entries in the store are **not** stamped to this clone and are listed for completeness:

| entry | stamp | `ref:` | resolves? |
|---|---|---|---|
| `rule/1339` | `xschem-op-wcard` | `doc/claude/issues/1339-pdf-link-hotspot-tracks-name.md` | **Not in either working tree.** It exists in op-wcard's git history, added by commit `e451892bc` |
| `rule/1351` | `xschem-op-wcard` | `doc/claude/issues/1351-font-attribute-is-a-postscript-name-and-a-format-string.md` | **Not in either working tree.** Added by op-wcard commit `8e3f0e166` |
| `rule/1357` | *unstamped* | `doc/claude/issues/1357-hier-pdf-nav-strip-presentation-is-unratified.md` | **Not in either working tree.** Added by op-wcard commit `5866270d7` |
| `rule/1357@xschem-claude` | *unstamped* | `doc/claude/issues/1357-add-from-the-summary-list-writes-the-annotation-list.md` | Yes, here |

The three that do not resolve are all on a branch nobody currently has checked out, so the
files are present in git and absent from disk — **not lost**. The two unstamped entries are the
innocent case already documented in `CLAUDE.md`: `rule/1357` is op-wcard's, and
`rule/1357@xschem-claude` is this clone's collision guard working exactly as intended.

The same applies to the **eleven `hier_pdf_*` look debts** stamped to op-wcard: their subject
lives on that branch, so they cost a checkout before they cost a look. They are deliberately
excluded from the 248 and from every count above.

**One entry worth naming, though it is not broken.** `look/the_nodes_CKTncDump_starred…` has an
empty body — its whole content sits in its (truncated) title. It is legible and it is a
survivor, but it is the one entry in the store whose text a filename truncation could have
eaten.

---

# PART 6 — The oldest ten survivors

Age is itself evidence. All ten are from the **first two days** of the queue, all belong to
theme A, and all have been waiting **twenty days**.

| # | filed | entry | in one sentence |
|---|---|---|---|
| 1 | 2026-09-02 01:53 | `the_RDW_dump_header_spelling…` *(look)* | You asked for a device path spelled `M2B:/xdut/xbg/xamp1`; the tree has three spellings and none is that one, so one was minted for you with the simulator's own path on a dimmer second line. Does it read right? |
| 2 | 2026-09-02 03:12 | `1244` | Three status sentences about decluttering, one of which promises a feature that had not arrived when it was written |
| 3 | 2026-09-02 05:08 | `1244_A2_name_bit_vs_hide_true` | Should a device name you have marked hidden still be drawn under the declutter? Measured: **zero** of the 4,823 shipped name records are affected — this is about your own future files only |
| 4 | 2026-09-02 08:36 | `1244_A3_blank_valued_block` | A device sitting over a dead results file is decluttered while its block shows labels with no numbers |
| 5 | 2026-09-02 08:36 | `1244_A3_click_target` | Decluttering **shrinks the area you can click** to select a device — measured, a MOSFET's clickable box loses about 20 units |
| 6 | 2026-09-02 08:36 | `1244_A3_hide_true_op_texts` | The PDK's own operating-point texts get hidden and replaced by the overlay. Intended, never stated |
| 7 | 2026-09-02 08:36 | `1244_A3_rc_armed_stamp` | Whether a keypress adopts a setting from your startup file or leaves it armed |
| 8 | 2026-09-02 12:36 | `1251` | A fourth declutter sentence, on the other keys, and how short it should be — the status bar is 255 bytes |
| 9 | 2026-09-02 16:16 | `1259` | Should a device whose every published number is **zero** count as "has numbers" for the declutter? Real case: `.option savecurrents` publishes some sky130 currents as 0 |
| 10 | 2026-09-03 01:53 | `1257_A7_armed_no_values` | On a sheet with no numbers, the declutter message advises pressing a key you have already pressed |

**All ten are sub-questions of one thing: what the declutter hides, and what it says while it
is doing it.** Eight of them are answered by pressing `Ctrl-Alt-6` on a sheet once and saying
whether it does what you meant. That is the shape of the whole queue in miniature, and it is
why A-0 leads.

---

# PART 7 — What I could not determine

Stated plainly, because a debt I cannot classify stays a survivor rather than a guess.

* **Whether the user has already ruled on anything since 2026-09-17.** Two collection documents
  — `RATIFY_WORDING.md` (16 questions) and `RATIFY_LOOKS.md` (27 sittings) — were written on
  2026-09-17 and **each has exactly one commit, its creation**. That is consistent with both
  "never shown" and "shown, answers never written back". I read repository state, not
  conversations.
* **Whether the eleven op-wcard `hier_pdf_*` look debts are still current.** Their subject is on
  a branch neither clone has checked out. They are excluded from every count here.
* **`1314`'s two follow-on sub-defects (A6, A7).** The issue file was never edited after
  2026-09-04, and the batch ledger says they were folded into B5-a/B5-3. I classified `1314`
  dead on the ledger's evidence, not the issue file's.
* **Whether `1377_repo_root_litter`'s question was the right one.** Repo root is clean today,
  but `tests/untitled~.sch` exists and issue **1486** is open with four items outstanding. I
  classified it answerable-without-you on the strength of its being a test-harness matter, not
  on its being finished.
* **Three entries I classified as survivors and would have liked to retire.** `1364`, `1366`
  and `1390` each describe a shipped behaviour with an "accept or say otherwise" tail, and each
  could be a driver decision that never needed you. I left them as survivors because their
  effect reaches the schematic or the run log, and the standing rule says an entry I cannot
  place stays yours.

---

## Provenance

Read against the ledger at `~/.claude/xschem_owed/` (193 rule, 70 look, 11 suite files; **248
rule+look stamped to this clone**), `doc/claude/issues/` (1,077 files),
`doc/claude/op_param_batch/`, `doc/claude/rdw_batch/`, `doc/claude/rdw_ux_batch/`,
`doc/claude/ase_analyses_batch/`, `doc/claude/issue_tracker_batch/`,
`doc/claude/lookdebt_batch/` and `doc/claude/results_batch/`, at HEAD `7e1e6a6f` on branch
`fluid-editing`, 2026-09-22. Every entry's full text was read. Nothing under `~/.claude` was
written; no `owed.sh` subcommand other than `count` was run; no file in `src/` or `tests/` was
modified.

**This pass stands on two earlier ones and says so.** `doc/claude/issue_tracker_batch/receipts/E1.md`
classified all 190 rule debts by *"does this reach a person?"* and found 153 theirs / 24 mine /
11 stale / 2 unknown. This pass asks a different question — *"has anything since overtaken
it?"* — and retires **59** where E1 retired 37, the difference being almost entirely code that
landed after E1 was written. `RATIFY_WORDING.md` and `RATIFY_LOOKS.md` are not re-derived here;
where they are right, this document points at them.

**And the honest limit, which that batch found and this one inherits.** Both earlier
collections were built and neither changed anything — one was never handed over, one was handed
over and then went stale as the queue grew past it. This document has the same shape and is
subject to the same failure. What is different is that it retires 69 entries outright and
reduces the rest to two framing questions; if those two are answered, the queue stops being a
backlog and becomes a morning.
