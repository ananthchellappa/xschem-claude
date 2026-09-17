# Crew brief — the ASE-L analyses batch

Read this before you open a file. Then read `README.md`, then **`PLAN.md` in full — it is
the deliverable and it is authoritative** — with `APPENDIX_ngspice_analyses.md` open beside
it for anything at the parameter level. `evidence/design-of-record.md` is the 2323-line spine
`PLAN.md` was synthesised from: read it when you need the reasoning behind a stage, and
remember that `PLAN.md` §0 records the places where the two disagree, with `PLAN.md` winning.
The dossier that governs *how you write* is `evidence/ase-conventions.md`; its §10 is the
house shape and it is not optional.

⚠ **STAGE 0 HAS LANDED — 2026-09-10, issue 1401.** This paragraph read *"Nothing in this
batch is implemented. `src/ase.tcl` and `src/ase_window.tcl` are untouched. This pass is
ANALYSIS only"*, and that was true of the planning pass and of all three amendments. The
analysis-only scope ended when the user said *"go ahead with Stage 0"*. What is true now:
**`src/ase.tcl` has Stage 0 in it** (five new procs, the emit loop, the gate clause),
`src/ase_window.tcl` is still untouched, and **Stages 1–16 are still unimplemented**. A crew
picking up Stage 1 reads `receipts/05-stage-0-silent-drop.md` first — it carries the one
correction Stage 0 made to this plan (**C36**) and the two harness traps that cost two T1
baselines before one was clean.

## ⚠ A C SABOTAGE IS RESTORED WITHOUT `-p`, AND THE CAMPAIGN ENDS ON A POSITIVE ROW

Stage 12's crew (issue 1465, receipt 40, C8) restored mutated C files with **`cp -p`**. A preserved
mtime is **older** than the object `make` built from the mutated file, so `make` kept that object:
two C arms ran with the **previous** mutation still compiled in, and the restored tree's binary carried
two more — **with every source md5-identical the whole time**. It is CLAUDE.md's *no harness builds*
trap arriving from the sabotage side instead of the `git stash` side.

**What caught it was the campaign's last row: the suite on the restored tree must be a positive
`ALL PASS`** — and it came back `3 FAILED`. So, for any campaign that touches C: restore with plain
`cp`, `make` after every restore, and **end on a positive restored-tree row**. The discarded arm's
results are discarded, not averaged in.

⚠ **And three rows outside every stage's *Suites that move* list read `run_cmd`'s BODY** —
`test_ase_simreg_0931` **P6** and `test_ase_predeck_1439` **CM5/CM6** grep it for the router call
`ase::predeck_argv ngspice $state` and the word order. A refactor that moves those lines reds all
three (C9).

## ⚠ A GUARD AGAINST ABSENCE MUST ITSELF BE TESTED AGAINST ABSENCE

This batch's most-met defect is **a defect hiding in the absence of a signal** — a suite that dies
at rc 0 and looks like a pass, an extractor that returns nothing and cannot disagree, a default
column that holds no numbers so no row over it can discriminate. Crews now write guards against it
routinely.

⚠ **And issue 1464's crew found that the guard it had written for exactly that purpose had exactly
that hole.** Its sabotage gate was, in effect:

```sh
case "$h$d" in *FAIL*|*NORESULT*) ... ;; esac      # ← the hole
```

When **both** variables are empty — which is what a silent suite produces — `"$h$d"` is the empty
string, it matches **neither** pattern, and **the check whose only purpose was to catch a silent
suite waved one through.** Five results had to be discarded once it was found.

**So the rule is one level up from the one everybody already follows.** A positive control on the
*row* is not enough; the *guard* needs one too:

* **Feed your gate the empty case before you trust it.** One line: run it against `h=""` `d=""` and
  require it to complain. If it does not, it is decoration.
* **Prefer a positive assertion to a negative match.** *"I saw a `RESULT:` line and it said ALL
  PASS"* cannot be satisfied by silence; *"I did not see FAIL"* is satisfied by silence, by a
  crashed process, by a typo in the filename, and by an empty variable.
* ⚠ **Ask of every check you write: what does this do when it is handed nothing?** If the answer is
  *"passes"*, it is not a check — and this is the one question that would have caught all four of
  the defect shapes above at the moment each guard was written.

## ⚠ DO NOT WRITE THE `.state` BYTE-IDENTITY MEASUREMENT YOURSELF — SOURCE IT

Every stage has to show its change did not move the 104 committed `.state` files, and **three
separate crews wrote that measurement from scratch and all three got the same false alarm first**:

* receipt 30 §6 — found it and wrote it down;
* issue **1460**'s crew — *"my first `.state` measurement said 104/104 mismatching and was wrong"*;
* issue **1464**'s crew — *"a maximally alarming false alarm"*.

The trap is that **`ase::state_serialize` omits the trailing newline the file on disk carries**, so
a harness that compares the two directly reports **every** file as broken — the most alarming
possible wrong answer, arriving at the exact moment you are deciding whether you have damaged the
user's benches. Writing it down three times has not stopped it, so it is now **code**:

```tcl
source [file join $repo tests headless state_roundtrip.tcl]
set r [ase_state_roundtrip $repo]
# -> tracked / bad / control_disagrees / control_agrees
```

**`bad` must be empty and BOTH controls must be 1.** They are mandatory rather than decoration: a
comparison that never ran reports a clean sweep, and a comparison that always disagrees satisfies
the first control on its own. **Report all four numbers in your receipt.**

## ⚠ EVERY WAITING LOOP NEEDS A DEADLINE, AND HERE IS THE ONE TO COPY

Telling crews *"give every waiting loop a deadline"* has not worked. Measured across this batch:
**five deadline-less waiters** of the form

```sh
until grep -q 'SABOTAGE DONE' results.txt; do sleep 10; done     # ← NO
```

have had to be killed by the driver, **every one of them belonging to a crew that had already been
collected**, and two of them written by a crew whose own brief said not to. One of that shape cost
this user an eight-hour night (`doc/claude/code_analysis/a_hung_suite_and_an_unbounded_wait.md`).

The problem is not that crews disagree; it is that the instruction is an exhortation and the wrong
thing is shorter to type. **So here is the right thing, at the same length. Copy it.**

```sh
D=1500; S=$(date +%s)                      # deadline in seconds, and the start
while :; do
  N=$(wc -l < results.txt 2>/dev/null || echo 0)
  grep -q 'SABOTAGE DONE' results.txt 2>/dev/null && { echo "FINISHED ($N)"; break; }
  [ $(( $(date +%s) - S )) -ge $D ] && { echo "DEADLINE ${D}s — at $N, runner alive: $(pgrep -c -f sab.sh)"; break; }
  sleep 30
done
```

**Three properties the short version does not have**, and each is why a wait becomes a stall:

* **It ends.** A hung job and a slow job produce identical silence; a deadline is the only thing
  that tells them apart.
* **It reports PROGRESS on the way out** — `at $N` — so the deadline firing is a finding
  (*"stopped after 21 of 48"*) and not merely an absence.
* **It says whether the runner is still alive**, which decides whether you wait again or go looking.

⚠ **And never `pkill -f` to clean up afterwards.** A crew reached for `pkill -f 'sleep 37'` and
**`-f` matched its own shell's command line and killed it.** Walk `ps`, match the exact argv, and
kill only what you started.

**This is not an anecdote — it is reproducible, and the driver reproduced it read-only while
writing this section.** `pgrep -c -f 'CAMPAIGN FINISHED'` answered **2** where exactly **one**
such process existed: the waiter, plus **the shell running the `pgrep`**, because `-f` matches the
whole command line and the pattern is *in* that command line. Swap `pgrep` for `pkill` and the
second match is the hand doing the killing.

So the rule has a mechanical reason rather than a moral one: **any `-f` pattern you type is, at the
moment you type it, present in a live process's command line — your own.**

⚠ **AND `pgrep -f` + `kill` IS THE SAME BUG WEARING A DISGUISE. The driver wrote the paragraph
above and then did it, one hour later.** Retiring a chained mutation launcher, it ran

```sh
for p in $(pgrep -f 'stage11b'); do
  c=$(tr '\0' ' ' < /proc/$p/cmdline)
  case "$c" in *pass3_go*|*pass4_go*) kill $p ;; esac      # ← killed its own shell
done
```

The loop's own command line contains `stage11b` **and** `pass3_go`, so the shell matched its own
`case` and killed itself — **exit 144**. The launcher was retired first and the tree was verified
byte-identical afterwards, so nothing was lost but the shell. **The lesson is that avoiding `pkill`
is not enough**: `pgrep -f` hands you your own pid, and any substring test you then apply is a test
your own argv can pass.

**What actually works:** exclude `$$` and your own process group, or match the **exact** argv of
something whose full command line you recorded when you started it — never a substring of a pattern
you are, at that instant, holding in your hand.

⚠ **AND A GUARD IS THE SAME BUG A THIRD TIME — IT FAILS SAFE, WHICH IS WHY IT IS EASY TO MISS.**
2026-09-15, the driver, before a solo T1: a guard meant to refuse the run if another suite was
alive, `ps -eo cmd | grep -qE '[r]un_regression'`, sat in the **same shell command** as
`tclsh run_regression.tcl`. The bracket trick hides `grep` from itself; it does not hide the shell
whose argv contains the literal — so the guard found "another suite", printed its refusal and
exited 3, **and T1 never ran**. The memory sampler written beside it had the same hole through its
own `echo … run_regression gone …` text, and would have reported T1 alive for twenty minutes.
**Match by process NAME, which no shell's argv can counterfeit:**

```sh
ps -eo comm=,args= | awk '($1=="tclsh" && /run_regression/) || $1=="xschem"'
```

`awk`'s own `comm` is `awk` and the shell's is `bash`, so neither can match itself.

⚠ **A BACKGROUND COMMAND STOPPED FOR "LOW MEMORY" IS A NAMED OUTCOME, NOT A MEASUREMENT.** The same
day the harness stopped two of the driver's long background commands — a sabotage-then-T1 chain and
a pinned T1 — as *"running low on memory"* while a sampler read **~13 900 MB available** and no
`xschem` process at all, and the T1 that followed, **in the foreground** under `timeout 590`,
finished clean at full parallelism with 13 970 MB available before and 13 907 MB after. Whatever the
trigger is, it was not the suite. So: when a background run is stopped that way, **check what it
left** (a sabotage mid-application, a truncated `results.log`, a `tests/.parallel_jobs.<pid>` job
list, a `results/.work`), restore or remove only what is yours, and **re-run in the foreground
under a `timeout`** — and say in the receipt that the first attempt has no verdict.

## ⚠ DISARM YOUR SABOTAGE SNAPSHOTS WHEN YOU HAND OVER

Every crew in this batch takes `cp` snapshots of `src/ase.tcl` and `src/ase_window.tcl` before its
sabotage campaign and restores from them after each arm. **Those snapshots do not expire, and the
restore script that reads them does not check their age.**

Measured 2026-09-13: **ten-plus pristine copies of `src/ase.tcl`** were sitting in `/tmp` from
every crew this batch has run, each one a pre-change file, each still restorable. A finished crew
can be woken by a stale background waiter — **two were, that evening** — and a `restore` fired then
would **silently overwrite the live tree with hours-old content**, taking both the current crew's
work and everything committed since.

One crew saw this coming and moved its own snapshots to an `ARCHIVED_DO_NOT_RESTORE/` directory
before standing down. **Do that.** When your campaign is finished and your receipt is written:

* **move or rename your snapshot files** so your own restore cannot find them, and
* **keep your campaign logs** — they are the evidence the receipt points at, and nothing reads them
  automatically.

⚠ **And if you are ever woken after your task is collected: check `git status` and `git log` before
you touch anything.** The tree will have moved on, another crew is probably live in it, and the
single most damaging thing a finished crew can do is tidy up.

**The standing rule that did NOT change:** no crew modifies anything outside
`doc/claude/ase_analyses_batch/` *except* the files its own stage names, and every stage
names them in `PLAN.md`'s *Files and procs* table.

## What the user asked, in their words (verbatim — do not paraphrase it in an issue file)

> Without changing any designs, we want to create a plan to capture every simulation capability of this version of ngspice in the ASE-L GUI (Analog Simulation Environment) of Xschem being worked on in /home/analog/dev/xschem-claude - the fluid-editing branch. If you look in the src directory of that folder, you will see ase_window.tcl and ase.tcl
>
> Is this a reasonable ask - to look at two projects? We want to make every simulation capability (all analysis types, and accompanying options) easily accessible through the GUI - user should be able to choose any supported analysis and set options easily. We want to be better than Cadence's Analog Design Environment.
>
> For now, all I am asking is for analysis (for Xschem, I believe just those two Tcl files should suffice, but Claude knows best how to proceed). For ngspice, you know the project and you know where it is hosted - which websites to use : https://ngspice.sourceforge.io/tutorials.html and https://ngspice.sourceforge.io/docs.html
>
> The customer for the plan document that will be created is a future Claude Code session operating on Xschem, to incorporate the features into the future GUI

---

## The goal behind the request

**The user is promoting Xschem and needs it to support everything ngspice offers so usage takes
off.** That is what this batch is for, and it is how a crew breaks a tie between two items: depth
of ngspice coverage, the differentiators someone would switch tools for, and low friction the
first time a user registers a simulator beat internal elegance no user sees.

It also settles who does what. Going by the ADE-L experience, the third-party tool vendor does the
integration — so **ASE-L is not in the business of knowing ngspice.** ASE-L owns the schema; a
per-simulator **adapter** owns the content, and the user reaches it by registering a simulator
under *Setup > Simulators*. ngspice is the first adapter and the hardest case, written *through*
the contract rather than around it, because a contract with nothing pulling on it fits nothing.
This came after the plan was written: `PLAN.md` §0 records the pivot, and Stage 1's mechanism
already had the right shape — what was missing was the statement of what the shape is **for**.
**Cite it by number**: `DECISIONS.md` **D34** (schema vs content), **D35** (adapters are
first-party), **D36** (written through the contract), **D37** (paper-validated against a second
simulator). ⚖ **R10** is the one question the pivot leaves open — how far the contract is written
down — and it is **not decided**; ask it last. (R1 is **answered**; see the end of this file.)

## Standing rules every crew obeys

Each one has a scar behind it. Sources: `/home/analog/dev/xschem-claude/CLAUDE.md` and
`evidence/ase-conventions.md` §1.

- **Give the binary a path.** `./src/xschem`, `$XSCHEM`, or
  `tests/headless/devdisplay.sh exec ./src/xschem`. **Never a bare `xschem`** —
  `/usr/local/bin/xschem` is 3.4.6 from January 2025, predates issue 0119, and rewrites
  `~/.xschem/recent_files`. One run of it emptied the user's *File > Open Recent*
  (issue **0924**).
- **Every launch carries `--nolog`. Never `--logdir`.** Two measured reasons: `--logdir`
  changed the thing under test and produced two false reds in `test_ase_core` NT17/NT18,
  and the user's own action log is `/tmp/Xschem.log.N` — issue **1359** is the scar, a crew
  destroyed it twice in one session. ⚠ `doc/claude/rdw_sim_batch/CREW_BRIEF.md` still says
  "every launch you make gets `--logdir <your scratch dir>`". That is the older ruling and
  it is superseded; use `--nolog`.
- **Never touch, move, back up or read-modify-write anything under `~/.xschem/`.**
  ⚠ **A SIMULATION RUN IS SUCH A WRITE.** `ase::rundir` with an empty `rundir` key returns
  `set_netlist_dir 0` — `~/.xschem/simulations`, one global directory shared by every state
  of every cell. **No crew runs a simulation on a bench under `sky130A/`**; a probe that
  needs a run uses a scratch library and an explicit `rundir`. Reading is fine. The incident
  is written up at the top of `doc/claude/ase_l_ux_batch/LEDGER.md`: an audit agent's run
  destroyed the user's 20502-point `tb_bandgap_ase.raw` and truncated its log.
- **Never** `git checkout --`, `git restore`, `git stash` or `git clean` against uncommitted
  work. **Never `git push`, never open a PR.** A sabotage restore is `cp` from a pristine
  copy plus an md5 compare.
- **Suites are hermetic about `HOME`.** Four ASE suites went red only because they read the
  developer's real `~/.xschem/ase_simulators`. The pattern is a scratch `HOME` **plus**
  `XSCHEM_DEVDISPLAY_DIR=$HOME_REAL/.claude/xschem_dev_display`, because `devdisplay.sh`,
  `gui_gate.sh`, `xvfb_arm.sh` and `spawn_reaper.sh` all resolve their state dir under
  `$HOME` and a bare scratch `HOME` produces a "clean zero" that verified nothing
  (issue **1397**).
- **No per-simulator knowledge goes into ASE-L's own source.** The analysis list, a field's units
  and defaults, the emit syntax, the option catalogue, the result names — all of it is **data the
  simulator's adapter supplies**, through the optional `analysis_types` hook on
  `ase::register_backend`, never a literal in `ase.tcl` or `ase_window.tcl`. The scar is on this
  machine and needs no second simulator to show itself: **the two ngspice binaries in the preflight
  below disagree about whether `pss` exists**, so a literal list is already wrong for one of the two
  binaries the user has. That is why `ase::analysis_types` falls back to `{}` and **never to a
  literal**, and why a crew that finds itself typing an analysis verb into ASE-L's own source has
  taken a wrong turn: the verb belongs in the adapter, which costs a proc (see the preflight —
  adapters are first-party Tcl).
  **The naming rule tells you which side you are on**: `ase::…` is the schema — readers, the one
  speller per surface, the refusal evaluator, the state keys; `ase::backend::<sim>::…` is the
  content — anything that spells a simulator's syntax, encodes one of its traps, or enumerates its
  facts. `PLAN.md` Stage 1 states it and `DECISIONS.md` **D36** is the decision. The tree already
  agrees: `ase::register_backend ngspice` is called from inside `namespace eval ase::backend::ngspice`
  under the comment *"the only ngspice literals outside `ase::backend::ngspice` stay the
  `state_default` schema defaults"*.
- **Full parallelism can OOM this box.** `test_njobs` is CPUs − 4 with no knob;
  `taskset -c 0-7` in front of `tclsh` is the external knob.
- **UI copy is terse and acronyms are UPPERCASE** — MOS, SPICE, PDK, OP, ASE-L, CIW, PATH,
  AC, DC, TRAN, PSS, VCD.
- **A new user-facing sentence is the USER'S ruling, not a crew's.** Mint it, ship it, and
  record `owed.sh add rule` for it. Never leave it in a write-up only. This plan is full of
  them — every field label, every unit string, every precondition sentence, every refusal,
  the `optran` sentence, the transient-noise seed sentence. `design-of-record.md` R9
  recommends batching them per stage, because twelve analyses otherwise means twelve rounds
  of asking, and the standing preference is one question at a time.

### Testing discipline

- **⚠ RUN THE STOCK BINARY TOO, and say so in the receipt.** Any change that touches what
  ASE-L *emits*, *reads back* or *offers* is verified against `/usr/bin/ngspice` (apt 45.2)
  as well as against the fork — the fork is the development reference, apt 45.2 is what a
  downloading user runs. See the preflight's three-binary table. A receipt that names only
  the fork has tested the one configuration the plan is *not* worried about. (This does not
  apply to pure-Tcl rows that never start a simulator; say that instead of testing twice.)
- **Raise a named suite's floor when you add rows. Never lower one.** The file's own
  `AND RAISED N -> M` paragraph goes in the same commit.
- **Sabotage-verify every new row.** Acceptance is a name+status diff, never a count: break
  the fix, watch the named row go RED, restore by `cp`, verify the md5 matches, report the
  red set by name. A row that cannot be made to fail proves nothing.
  ⚠ **AND "THE FILE CHANGED" IS NOT "THE FILE CHANGED WHERE I MEANT".** Measured 2026-09-15 by
  the ⚖ R9 A1 verifier, on itself: its first label sabotage **lost its line address and became a
  global substitution**, hitting all four labels instead of the one it named — and **the
  md5-moved guard passed**, because the edit *did* change the file, just far more of it than
  intended. A second arm lowercased `SCOPED:`, a term belonging to row **HK4**, and duly
  reddened **HK4** — while the row it was meant to prove was **HK5**. Either one, reported
  as-is, would have claimed a row proven on the strength of a red that was not it.
  **So the guard is not "the md5 moved" but "exactly the intended lines moved"**: diff the file
  after planting the arm and **count the changed lines against the number you intended**, and
  require the red set to be **exactly** the named row rather than merely non-empty. The verifier
  caught both itself and reported them; that is the standard.
- ⚠ **NEVER END YOUR TURN WAITING TO BE WOKEN.** A watch, monitor, timer or notification does
  **not** resume you: when your turn ends you stop executing, and a pass that says *"standing by
  for the watch event"* sits there until the driver notices. This happened **twice on
  2026-09-15**, both times to a verifier holding a live regression run it had correctly started.
  **Poll it yourself, in the foreground, by recorded PID** — `while ps -p <pid> -o comm=
  >/dev/null; do sleep 30; done` inside `timeout <n>`, printing elapsed each pass so "still
  working" and "wedged" stay distinguishable. Never match a process by a pattern your own
  command line contains. **A stall is a named outcome — `TIMEOUT` with the last line of the log
  — never the absence of one**, because a hung job and a slow job produce identical silence.
- **Run `tests/run_regression.tcl` SOLO** (issue **0990** — two at once corrupt
  each other and the loser prints a `FATAL` that never happened; `exit -1` is the tell).
  ⚠ **The path above said `tests/headless/run_regression.tcl` until 2026-09-15 and that file
  does not exist.** The suite lives at `tests/run_regression.tcl`.
- ⚠ **INVOKE IT AS `cd tests && tclsh run_regression.tcl`, NEVER `tclsh tests/run_regression.tcl`.**
  Measured 2026-09-15 by the issue 1474 verifier: run from the repo root it **exits 1** and leaves
  the **previous run's `results.log` in place**, so the next reader counts a clean sweep that was
  never taken. Two receipts in this batch quote a T1 row obtained that way, and the case count
  they carry (**84**) is the stale file's; the tree measures **82**. This is the same defect as
  reading `run_regression.tcl`'s stdout instead of `results.log` (issue **1456**) — the failure
  is silent, plausible and always green. **Before counting, confirm the log's MTIME moved off the
  pre-run value**, and treat an empty log after the run as a death, never as zero.
  ⚠ **MTIME, NOT MD5** — this line said "mtime and md5" for an hour on 2026-09-15. `results.log`
  is **byte-deterministic for a green run** (three consecutive 82-case sweeps, all `8456b56c…`),
  so an unchanged md5 proves nothing and treating it as proof of a fossil condemns every honest
  green run. The stale file is itself a *previous green run*: only the mtime tells them apart.
- **T1's baseline is ZERO counted failures.** "A standing red is a defect, not furniture."
  A receipt may not say "3 FAIL — pre-existing"; if T1 is not zero, name the case and say
  why, per case. Eight issue files were filed four times each because crews carried
  pre-existing reds forward.
- **No test harness builds.** `full_audit.sh` runs `$REPO/src/xschem` as it finds it. A
  correct source tree plus a stale binary produces a plausible audit that is worthless.
  This batch is expected to be pure Tcl (ASE-L is Tcl by decision), so this bites only if an
  item adds a C file or a new `.tcl` — and a new `.tcl` obliges the `src/Makefile.in` →
  `./configure` re-run, verified with `grep -c <newfile> src/Makefile`, expect **2**
  (issues 0423/0424).
- **The dev display.** `tests/headless/devdisplay.sh start` (Xvfb `:99` + openbox);
  `AUDIT_SCREEN` pinned at `1920x1080x24`, never `1600x1200`. **There are three X servers
  here and `:0` is not the user's screen**: `:0` is WSLg Xwayland, `$DISPLAY` is the Windows
  X server the user actually looks at, `:99` is Xvfb. A look debt that says "on the user's
  real screen" is paid with `AUDIT_DISPLAY=$DISPLAY` or by hand.

### The GUI test gate

It exists: `tests/headless/gui_gate.sh` + `gui_gate_widget.tcl` + `gated_xschem.sh`, wired
into `full_audit.sh` and `run_suites.sh`, spec `doc/claude/specs/gui_test_gate.md`. It
**fails open** — no `DISPLAY`, `GUI_GATE=0`, or a closed panel and the tests just run — and
`GUI_GATE=0` is *forced* by the Xvfb arm, so **a panel popping for a routine suite is a
symptom, not the design**. The user's own instruction: press `Allow 30m` or `Forever` once,
don't press Proceed forty times. **Do not reintroduce it as a Claude Code settings hook**; a
prior hook-based gate died silently when `settings.local.json` was rewritten. The build-loop
gate `tools/review_gate/` is deliberately a *different* control dir and must run in the
background — a 30-minute foreground wait exceeds the 600 s command ceiling.

### Issue numbering

`doc/claude/issues/NUMBERING.md` is the **only** authority, and you read its **tail** at the
moment you mint. Do not trust a number quoted anywhere else, including `CLAUDE.md`, which
was wrong by 700+ for months, and including this file. Grep the issues directory before
minting (a collision once cost a renumbering of 0420–0432). File
`doc/claude/issues/NNNN-<kebab-slug>.md` where the slug is a sentence fragment describing the
defect, and record the number in `NUMBERING.md` **in the same commit**. Reserved blocks to
skip: **0500–0599** (fluid-editing), **0700–0799**, **1000–1199**.

At HEAD `2f1fad58` the tail reads *"The next free number is 1400."* — **this batch has not
advanced it and has minted nothing.**

### Commit style

Conventional-commit prefix with the issue numbers in parentheses, then a sentence — not a
noun phrase — in the tree's own voice, lowercase after the colon, stating the defect or the
gain and not the diff:

```
fix(1396): Save State asked nothing before it destroyed an existing state
batch(ase_analyses): the plan for every ngspice analysis, and the eight places that disagree today
```

Prefixes in use: `fix`, `feat`, `docs`, `batch`, `tools`. A batch's planning commit lands
**before** the item commits, so item commits' citations resolve.

### The three ledger debt kinds

`tests/headless/owed.sh`, spec `doc/claude/specs/owed.md`:

| kind | added by | clears when |
|---|---|---|
| `add rule <id>` | a decision that is the user's to make — every new user-facing sentence | **the user says so** |
| `add look <what>` | a pixel deliverable — a new form's appearance | **the user says so** |
| `add suite <name>` | a `:0` run owed | it passes |

**No command converts one kind into another.** A pixel deliverable is never "done" on a
green suite: record `owed.sh add look` and say "suites green, please look". Add `--eyes` to
a rule that cannot be settled without looking at pixels.

**⚠ ONE LEDGER, EVERY CLONE — check the signature before your first `add`.** The ledger lives
in `$HOME`, not in the tree, and it cannot tell a second checkout of this repo from a worktree
of this one. There are **two clones on this machine**: this one, and
`/home/analog/dev/xschem-op-wcard` (branch `op-wcard`). A bare `owed.sh add` here therefore
writes into a ledger that clone writes to as well, and a 4-digit rule id came to mean two
different things — that is issue **1400**, whose finding was that both writing paths destroyed
the other tree's entry in silence. `owed.sh add|clear … --repo <clone>` is the flag for
deliberately touching another clone's entry.

That flag arrived **after this brief was written**, which is the general point: `owed.sh` is
being actively changed by work outside this batch. **Where `CLAUDE.md` and this brief disagree
about `owed.sh`, `CLAUDE.md` wins** — read its command block before your first `add`, not after.

---

## "Do not change designs" — the user's phrase, in its three distinct senses

There is no literal string "do not change designs" in the tree. It resolves to three rules,
and an item should say which one it means (`evidence/ase-conventions.md` §3):

**(a) The ASE-L founding doctrine — the schematic carries only the circuit.** The target
cell contains only devices, sources and net labels; analyses, models, variables, outputs,
options, run dir and simulator choice are STATE, in the `ngspice_state1` view. **No analysis
capability in this plan may be delivered by putting anything back on the schematic** — no
`code_shown`/`simulator_commands` instance, no `corner.sym`, no `flags=graph` block. The
migration tool exists precisely to *remove* those. This is why the plan reaches S-parameter
ports through `alter <src> portnum = N` / `alter <src> z0 = R`, transient noise through
`alter` or a generated parallel source, and design variables through
`.param x='var(…)'` — all emitted, none drawn.

**(b) Do not touch the user's own designs, benches or artifacts.** `sky130A/` benches,
`~/.xschem/`, `/tmp/Xschem.log.*`. Probes use a scratch library with an explicit `rundir`;
fixtures are built under `/tmp`; never write into a committed `xschem_library*`.

**(c) Do not silently dirty a schematic as a side effect of a walk.** The
`ase::with_design_current` round trip is built entirely around this: `go_back` calls
`load_backup_as()` whenever a `<cell>~.sch` exists, ending in `set_modify(1)`, so the trip
parks `autosave_backup`, restores `readonly`, and **refuses outright** for a modified buffer
with autosave off (issues 0626 / 0432). Anything this plan adds that netlists or descends
inherits that doctrine — carry it, do not re-derive it.

---

## THE PREFLIGHT — measured before any crew started, so nobody re-derives it

Re-measured 2026-09-09, the day this brief was written.

### The ngspice under test

| | |
|---|---|
| tree | `/home/analog/dev/ngspice`, branch `ver_50` |
| `git describe` | `ngspice-46-419-gccebdf2a2` |
| **binary — the development reference** | `/home/analog/dev/ngspice/build-ver_50/src/ngspice` |
| self-reports | `ngspice-46+`, `Creation Date: Thu Sep  3 06:46:24 UTC 2026`, "Compiled with KLU Direct Linear Solver" |
| configured | bare `../configure` — so XSPICE **on**, OSDI **on**, CIDER **off**, RFSPICE **on**, `WITH_PSS` **off** |

Most measurements in `evidence/` were taken against that binary. Run it freely; it is
read-only work on scratch decks in your own scratch directory.

### ⚠ THREE BINARIES, NOT ONE — and the fork is NOT what users have

**Added 2026-09-10 by the variant-support amendment. This supersedes "use this path, always".**

The user's own framing is the reason: *"most users who download our Xschem won't have our
ngspice."* Measured on this machine — `cat /etc/os-release` → **Ubuntu 26.04.1 LTS**,
`apt-cache policy ngspice` → **`45.2+ds-1`** from `resolute/universe`. **The current Ubuntu LTS
ships ngspice 45.2.** That, not the fork, is the binary a first-run user will register.

| # | binary | path | reports | what it has that the others do not |
|---|---|---|---|---|
| 1 | **apt 45.2** — *what a new user has* | `/usr/bin/ngspice` | `ngspice-45.2` | `pss`; CIDER (`NUMD NUMD2 NBJT NBJT2 NUMOS`) |
| 2 | **stock upstream 47** — *what a from-source user has* | `/home/analog/.claude/projects/-home-analog-dev-ngspice/workpad/builds/upstream47/src/ngspice` | **`ngspice-46+`** | `pyplot`, `astate`, `ota` (also on the fork) |
| 3 | **the fork** — *the development reference* | `/home/analog/dev/ngspice/build-ver_50/src/ngspice` | **`ngspice-46+`** | casemode (`$curcasemode`); ~35 bug fixes still live upstream |

**THE RULE: a crew tests its change against binary 1 and binary 3 at minimum, and reports both.**
The fork is where the work is developed; apt 45.2 is where it will be *run*. A green suite on the
fork alone proves nothing about the users this plan exists to reach. Binary 2 is the tiebreak when
a difference turns out to be "the fork fixed it" rather than "45.2 is old".

**Four facts about those three that will save you a wrong turn:**

1. **Version detection cannot work, and the plan forbids it.** Stock 47 and the fork **both report
   `ngspice-46+`** for `-v` and for `version -v` (`configure.ac:19` is `m4_define([ngspice_major_version], [46+])`
   in both trees, untouched by the fork), all **134** `spcp_coms[]` names are present on both, a
   join of the two 134-row help-string lists filtered to rows that differ is **empty**, and
   `devhelp` is identical. Only the build timestamp differs, and that is whoever ran `make`.
   `version_line` may be **displayed and logged; it may never be compared** (`PLAN.md` §0.13,
   `DECISIONS.md` **D44**).
2. **Capability is not ordered by version and moves in both directions at once.** The *older*
   45.2 has an analysis (`pss`) and five device families (CIDER) the *newest* builds lack; the
   newest builds have `pyplot`, `astate` and `ota` that 45.2 lacks. There is no "basic" binary and
   no nesting to exploit.
3. **The ordinary ASE-L deck already works on 45.2.** Measured: the full `.options savecurrents` /
   `.temp` / `.save all` / `.save @dev[param]` / `$sim_status`-guarded / `remzerovec` / `write` /
   `print` render produces rc 0, 2 plots, **identical `Variables:` blocks and identical printed
   values** on apt 45.2 and on the fork (`evidence/fork-dependencies.md` §4.0). `sim_status`,
   `set appendwrite` and the forward-sticky save list all behave the same there.
4. **`$casemode` is a false-positive probe; `$curcasemode` is the real one.** Measured: apt 45.2
   and stock 47 accept `-D casemode=preserve` **silently** — rc 0, nothing on either stream — then
   answer `$casemode` → `preserve` while folding every name anyway. `$curcasemode` answers
   `Error: curcasemode: no such variable.` there and `preserve` on the fork. Never read back your
   own flag; ASE-L already gets this right (`ase::sim_casemode_selectable` measures *delivery*).

⚠ **Building stock upstream 47 takes 99 seconds, not "10+ minutes".** Measured 2026-09-10 on 20
cores from a scratch worktree at `origin/pre-master-47` (`c5cd68015`), bare `../configure`:
autogen 26 s, configure 14 s, `make -j8` 59 s, rc 0. If binary 2 is missing, rebuild it rather
than reason about it. The worktree was removed afterwards; `git worktree list` shows only the main
tree, and `ver_50` is clean.

⚠ **Never run a probe that crashes the user's simulator.** A deliberate SIGABRT of a
dpkg-owned `/usr/bin/ngspice` is exactly apport's reportable case, and apport is installed and
enabled on this very release (`dpkg -l apport` → `ii 2.34.1-0ubuntu0.1`, `/etc/default/apport`
→ `enabled=1`, `systemctl is-enabled apport.service` → `enabled`). It is silent *here* only
because WSL leaves `core_pattern` at `core` and `systemd-coredump` is not installed. On a stock
Ubuntu desktop the same probe files a crash report blaming the user's simulator. See `PLAN.md`
§0.13 and the refuse-list.

⚠ **BROKEN TWICE ON 2026-09-15, BY THE DRIVER AND BY A CREW — and both times it felt like a
measurement rather than a probe.** The driver, characterising M9's `eprvcd` abort, crashed
`/usr/bin/ngspice` **twice** (rc 134): the first unintended, the second a deliberate variant run to
find the trigger. Stage 12's crew met `eprvcd` after `tf` segfaulting through a sabotage run —
unintended — and then **ran the deck directly on 45.2 to confirm it**, which was deliberate. **The
rule covers a confirmation too.** Once a crash is seen on 45.2, characterise it **on the fork**,
where a crash is harmless, and carry 45.2's half as the one observation already made.

**Partial results ARE recoverable in `-b`, and the mechanism is checkpointing.** Measured
2026-09-10 against that binary (`evidence/salvage.md`, APPENDIX §6.8): a `.control` block that
arms `stop after <points>`, writes to a `.tmp` and `shell mv`s it into place, and `resume`s keeps
everything up to its last checkpoint through a `kill -9` — **a plain `write` in the same loop does
NOT**, because a kill landing inside one leaves a file ngspice refuses **whole**
(`Error: bad rawfile / load aborted / no data read`, over millions of good points). With the
counters in the `const` plot, the finished run is **byte-identical** to an unchecked one — final
body sha256 `b9836c494d9d52ad`, the same at 0, 3 and 100 checkpoints. **Both qualifiers are
load-bearing, and this paragraph carried neither until 2026-09-10** — the `.tmp` + `shell mv` was
in the recipe but not in the summary, and the counter was in the wrong place in the recipe itself
(`PLAN.md` **C35**). The reason
ngspice throws the work away by default is **a missing handler, not a decision** — `src/main.c`
puts its whole `signal()` block inside `if (!ft_batchmode)`, so batch takes the default
disposition and dies where it stands (SIGTERM, SIGHUP, SIGQUIT are installed in **no** mode at
all). Nothing is being traded away for it; batch was written for scripted use where nobody
presses Stop. **Do not re-investigate this**, and do not reach for `-r` to fix it — see the
traps table. The safe form is `stop after`, never `stop when`, and the four rc-0 ways of writing
the loop wrong are APPENDIX §6.8.6.

### The analysis registry, and what is build-gated

Eleven analysis types, plus the options sheet as the twelfth row of
`design-of-record.md` §5.1's reference table. Two are `#ifdef`-gated in
`src/frontend/commands.c` — `pss` behind `WITH_PSS`, `sp` behind `RFSPICE`; the other nine
are unconditional in every ngspice that has ever shipped, which is what lets the GUI fall
back to an "ungated baseline" when it has no measurement.

Measured on this build with one `-b` deck running `help <verb>` per verb:

```
op dc ac tran noise tf pz sens disto sp   ->  answered
pss                                       ->  Sorry, no help for pss.
hb  sens2                                 ->  Sorry, no help for hb. / for sens2.
```

So, **measured 2026-09-09, `sp` was present in the user's build and `pss` was not.**

⚠ **UPDATED 2026-09-10 — the transcript above is that build as it was.** At the user's request
`build-ver_50` was reconfigured with `--enable-pss --enable-cider` (same source commit; `make
install` into `stage/`). It now answers `help pss` with `pss [.pss line args] : Do a periodic
state analysis.`, lists `NUMD NUMD2 NBJT NBJT2 NUMOS` in `devhelp`, runs both shipped PSS
oscillators to `Convergence reached`, and **still reports `ngspice-46+`**. Every measurement in
`evidence/` was taken against the earlier binary (md5 `eaa99c22…`, the `LEDGER.md` baseline).
The live fixture for the four-state grid's `absent` state is now the **bare-configure upstream
build**, `/home/analog/.claude/projects/-home-analog-dev-ngspice/workpad/builds/upstream47/src/ngspice`,
which answers `Sorry, no help for pss.` (measured 2026-09-10). A crew testing Stage 2's
Detect leg and the `absent` state registers that binary as a second simulator entry — no rebuild
needed. ⚠ **This sentence also named *"a crew testing Stage 14"* until 2026-09-16; there will be no
such crew.** ⚖ R7 was reversed and **Stage 14 is not built** (issue **1475**) — the `--enable-pss`
fork build stays a useful fixture for the four-state grid, and is no longer a fixture for a panel. `/usr/bin/ngspice` (45.2) still differs from both 46+ builds in the other direction
(`pyplot`, `astate`, `ota`; APPENDIX §1.8).
`hb` and `sens2` will never be present: `HBinfo` and `SEN2info` are `extern` declared and
defined nowhere. **That two-binary disagreement is the whole case for the adapter/probe split**
— one simulator, one machine, two analysis sets — and it is the standing rule above.

**Adapters are FIRST-PARTY, so executable Tcl is acceptable.** A simulator's adapter is written by
Xschem's own agent, lives in this tree and is versioned with it, so it is ordinary Tcl on the
existing `ase::register_backend` hooks. **Do not spend a day building a manifest format, an inert
data loader or a sandbox for it** — that defends against a threat that does not exist here, and the
user has said so. If third-party adapters ever arrive, that is when the question is reopened.

⚠ **`help tf` prints the transient help** — `tf [.tran line args] : Do a transient
analysis.` — an upstream copy-paste bug, live on this build. The capability parse rule
survives it by keeping a stanza only when **its first token equals the verb probed**. Do not
"fix" the probe by matching on the help text.

CIDER is absent from this build, and its absence does not say so: a deck with
`.model dm numd` fails with `could not find a valid modelname`, naming neither CIDER nor the
flag. That message is the reason `design-of-record.md` §4 requires the GUI to warn before
running such a netlist.

### The xschem tree

| | |
|---|---|
| tree | `/home/analog/dev/xschem-claude`, branch `fluid-editing` |
| HEAD when this was written | `2f1fad58` — *"fix(1398): ASE-L came back three points smaller than it went in"* |
| working tree | **dirty**: untracked `.xschem/`, `doc/claude/ase_analyses_batch/`, `doc/claude/rdw_lists_batch/`, `doc/claude/rdw_sim_batch/`, and `sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/` |
| `src/ase.tcl` | 11745 lines |
| `src/ase_window.tcl` | 8135 lines |
| other writers | **yes — this clone is shared.** See below |

⚠ **YOU ARE NOT THE ONLY WRITER IN THIS CLONE.** On 2026-09-10, between 10:49 and 11:16 and
with no connection to this batch, another session modified `CLAUDE.md`,
`doc/claude/issues/NUMBERING.md`, `doc/claude/specs/owed.md`, `tests/headless/owed.sh` and
`tests/headless/test_owed.sh` here — filing issue **1400** and reserving issue block
**1500–1599**. Two consequences: **run `git status` before you start**, so you know what you
are sharing the tree with and do not mistake someone else's work in progress for your own
baseline; and **treat every number in this preflight and in `LEDGER.md` as measured against a
moving tree** — re-measure before you diff against it. The reserved issue blocks in
`NUMBERING.md` in particular changed *after* this brief was written, so read that file rather
than trusting any number quoted here.

⚠ **THE TREE IS DIRTY AND MOVING. CITE PROC NAMES, NEVER BARE LINE NUMBERS.** A line number
may appear only as a parenthesised hint. This is a ruling the tree already took: an adversary
finding on the 1396 item was *"Three `:321-335` citations stale the day they land"* →
*"FIXED. Line ranges replaced by section names — a section survives an edit, a line range
does not."* The proof is in this batch: the driver's own brief said `ase_window.tcl` was
~7.7k lines; it is 8135 today. Every proc this brief names was re-checked present in the
tree before it was written — `ase::state_default`, `ase::plot_sim_type`, `ase::rundir`,
`ase::sim_capabilities`, `ase::sim_caps_have_path`, `ase::attach_dbs`, `ase::netlist_map`,
`ase::netlist_map_resolve`, `ase::preflight_gate`, `ase::n_enabled_analyses`,
`ase::raw_content_verdict`, `ase::cosim_map`, `ase::register_backend`,
`ase::backend::ngspice::render_deck`, `ase::ui::chana_options`, `ase::ui::chana_show`,
`ase::ui::chana_row`, `ase::ui::chana_fields`, `ase::ui::choose_analyses`,
`ase::ui::rsel_status`, `ase::ui::pane_dblclick`. One name in the evidence is not a proc:
`ase::ui::listdlg` is a **variable** (the procs are `listdlg_open` and friends). That is the
class correction C21 names — *"two procs used in design B's code sketches do not exist"* — so
do the same check for every proc you inherit from a dossier before you cite it.

### The 105 `.state` files — the hard migration constraint

```
find . -name '*.state' -not -path './.git/*' | wc -l     ->  105
git ls-files | grep -c '\.state$'                        ->  104
grep -ho 'type [a-z]*' over all of them
    ->  105 type ac / 105 type dc / 105 type op / 105 type tran, and nothing else
```

⚠ **Correction to `evidence/ase-conventions.md` §6, which says "105 committed".** 105 is the
count on disk; **104 are committed**. The 105th is
`sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/tb_bandgap.state`, left untracked
by the UX batch's Save State item. A byte-identity claim covers the 104 committed files;
count again yourself before quoting either number.

Every one of them carries exactly four analysis rows, enabled or not. `ase::state_default`
seeds precisely those four. **Five suites assert load→save byte-identity** and are named in
the code as **F3 / G3 / R4 / V4 / R2**; `ase::omit_if_empty` exists entirely to keep them
green when a key is added. This is why the plan's stage 1 acceptance criterion is byte
identity, and why adding a type to `ase::state_default` is a ruling (R4) rather than an edit.

### The eight copies of "what is a `dc` analysis"

`ase::state_default`'s seed, `anaargs`, the radio `foreach`, `anorder` + its switch, **the
print anchor's own `foreach type {dc ac tran op}` inside the same `render_deck` proc**,
`ase::ui::chana_fields`, `ase::ui::chana_show`'s destroy list, `ase::plot_sim_type`. They fail
**silently** when they drift, and one already has: `ac`'s `dec` key is advertised in
`anaargs`, omitted from `chana_fields`, and hardwired in
`ase::backend::ngspice::render_deck`. Collapsing these into `ase::analysis_types` is the
whole of stage 1.

⚠ **The count was seven and is eight** (`PLAN.md` §0.3). The eighth — the print anchor's loop
— is a **separate literal twelve lines below `anorder`**, governed by issue **1243**'s ruling
rather than **0964**'s, and it is the one loop whose job is to decide which analysis the Value
column reports. A registry pass that collapses `anorder` and leaves it alone has left the
drift in place, in the worst possible loop.

---

## The traps that will bite you in the first hour

Rows 1, 2, 3, 6, 7 and 8 were re-measured on `build-ver_50` on 2026-09-09 for this file — all
four DISTO decks included. The **inert options** and **pre-deck** rows are quoted from
`evidence/options.md` and `evidence/hidden-vars.md`, which anchor them to source lines; the
**one Plotname** row is `[R-M11]`; the PSS row is from `evidence/builds.md`'s `--enable-pss`
build, which is **not** the user's binary.

| trap | what happens | what a crew must do |
|---|---|---|
| **DISTO with an unresolvable save list** | `.control` with `save v(nosuchnode)` then `disto` → **rc 139, SIGSEGV**. The same deck with a `.save all` card above `.control` → rc 0. A `.control` deck with `disto` and **no save at all** → rc 0. Dot cards `.op` + `.disto` + `.control run` → **rc 139** | The trigger is *"a save list that resolves to nothing"* — **not** "a narrowed save" and **not** "no save". Design C's proposed refusal (refuse `disto` with zero saved outputs) would refuse a deck that works. The rule is `saves_resolve` promoted to fatal whenever `disto` is enabled, checked in the dialog **and** re-checked in `render_deck`, and **not defeasible** by `set ase_preflight 0` |
| **`sens … ac` under `.options klu`** | rc 139. `sens … dc` under klu → rc 0 | An option × analysis cross-rule, refused at the moment of typing with the fix offered. Only expressible because options are modelled as typed objects rather than free text |
| **`ac lin 2`** | `ac lin 2 1k 11k` → `length(frequency)` = **1**. `lin 3` → **3** | Silent. The form validates it; nothing downstream can |
| **Inert options** | `ramptime` is live code inside `#ifdef XSPICE_EXP`, defined nowhere. `nosavecurrents` is documented by the manual §13.7 and the string appears **nowhere** in this tree. `klu_memgrow_factor` assigns the boolean result of a comparison to a double, so every value but `1.2` sets the factor to `0.0`. `itl1`/`itl2`/`itl4` below 100 are silently raised to 100. `oldlimit` works from a dot card and is dropped on the `.control` route | Three shapes, all in `design-of-record.md` §7.4: **not offered at all**, **offered with a clamp and the reason**, **kept as a tombstone with the reason** so the next reader does not re-add it from the manual |
| **The pre-deck option class** | **26** of the 163 `cp_getvar` variables are unreachable from `.options` *and* from `.control` — `casemode`, `ngbehavior`, `wnflag` among them. `.options casemode=preserve` is **silently ignored** | They need `<rundir>/.spiceinit` or `-D`, and `-D name=v` makes a `CP_STRING` and nothing else — it cannot carry a `CP_NUM`, `CP_REAL` or `CP_LIST`. Chaining the user's own `.spiceinit` by `source` **loses their variables** (ngspice parses the target as a netlist); ASE-L must **copy** the lines under a banner. All of it is refused outright when the simulator entry carries `-n`. This is ruling **R2 — ANSWERED yes on 2026-09-10**, with four conditions, so the door is open and the conditions are requirements |
| **`.control` `if` on strings** | takes the **false** branch for both `eq` and `ne` | No conditional logic in a generated deck except the numeric `$sim_status` guard. Every decision belongs to the renderer, in Tcl, where it is testable |
| **A capture loop cannot name plots** | `set wl = "$wl $p.all"` inside `foreach p $plots` → `Error: p.all: no such variable`, twice — the `.` is swallowed by `$` substitution, so the escape of naming the plots on one `write` line cannot be generated from inside a deck. `$plots` leads with `const` (measured: `const noise1 noise2 op2`) and `destroy const` is refused — `Error: can't destroy the constant plot`. On the append-write path ASE-L uses, the loop therefore writes the `constants` plot **first**, which `ase::raw_content_verdict` rejects outright (that last step is `[R-M2]`, not re-measured today) | The writer is the `setplot previous` walk plus a per-write plotmap sidecar. This is correction **C1**, the largest single repair in the design of record |
| **Phase is in RADIANS** | measured today on an RC at 3.98 kHz: `vp(mid)[3]` = `-1.25359e-02`, then after `set units=degrees`, `-7.18257e-01` — the factor is 57.2958. (`[R-M10]` records the same ratio on a different deck: `-4.96729e-04` → `-2.84605e-02`) | Every `meas`, every derived phase margin, every phase trace is preceded by `set units=degrees` and labelled `deg`. **No design caught this and all three routed a phase margin to the user** |
| **Two analyses, one `Plotname:`** | `sens … dc` and `sens … ac` both report `Sensitivity Analysis` | Results cannot be matched on the plot literal alone; the sidecar's creation order is what separates them, and what separates two rows of the same type |
| **`Convergence not reached` returns rc 0** (PSS, on the `--enable-pss` build) | with both plots full of plausible data | The exit code is not a success signal. The panel scrapes stdout for the verdict string. Same class: an interrupted control-block run reports `sim_status = 0`, indistinguishable from success |
| **Probing for a verb with the bare verb** | inside a `.control` block it is a **command, not a question**: a deck always has a circuit, even one with no devices. Measured 2026-09-10 — `op` **ran** and printed `No. of Data Rows : 1`; `pss` on `/usr/bin/ngspice` **started a PSS run** and had not returned after 30 s | Probe with `help <verb>`. The command word is a real second oracle — it answers `pss: no such command available in ngspice` and needs no help database — but only with **no circuit loaded**, which needs `-p`; plain stdin makes ngspice read the words as a netlist. `PLAN.md` §0.11 has both transcripts; Stage 2b is where it is allowed to live |
| **Reaching for `-r` to get partial results** | On an ASE-L-shaped deck — one where a `.control` block runs the analyses — `ngspice -b -r <path>` writes **nothing at all** to `<path>`, and then **deletes it**. Measured 2026-09-10: a good 32-byte file at that path, a deck whose block ran `tran` and `write victim.raw`, `ngspice -b -r victim.raw deck.cir` → the log prints `binary raw file "…victim.raw"` **twice**, and at exit `ls: cannot access 'victim.raw': No such file or directory`, **rc 0**. `main.c`'s batch arm calls `ft_dorun(ft_rawfile)` unconditionally after the deck is sourced; **`dosim()`**, the function that four-line wrapper calls, opens the path `"wb"` up front and, finding `ftell == 0` on the way out, `unlink`s it — grep `ft_dorun` alone and you find no `fopen` and no `unlink` | This is the one that bites first, because `-r` is the obvious reach and it fails as an **empty directory with no error**. `-r` streams incrementally and salvages beautifully — but only on a **dot-card** deck, which is not the shape the plan depends on. Salvage the checkpoint way instead (preflight above; APPENDIX §6.8). If `-r` is ever added to `run_cmd` for progress or a fallback raw, point it at a path **nothing else owns**. APPENDIX §7.1 **X11** |
| **Running a bench under `sky130A/`** | writes into `~/.xschem/simulations` and destroys the user's artifacts | See the standing rules. It has already happened once |

---

## Reading order

1. `README.md` — ninety seconds.
2. This file.
3. **`PLAN.md` — in full.** §0 is the corrections and the measured facts, §1 the axis split,
   then fifteen stages on three axes — **0 through 14, the numbers frozen** — plus **two**
   terminal stages on none of the axes: **Stage 15**, the conformance harness the second
   adapter needs and outside this pass, and **Stage 16**, *"the ngspice you actually have"*.
   Then the ruling ledger, the ADE-L comparison, the refuse-list, the sequencing table and
   what is still open. Stage 1 is where the adapter contract lives. **§0.13 is the variant
   architecture and §0.1's three-binary table is the fact behind it** — read both before you
   write anything that starts a simulator.
4. `APPENDIX_ngspice_analyses.md` for your stage's ngspice facts at the parameter level —
   each stage names the sections it rests on.
5. `DECISIONS.md` for the D-number or ⚖ R-number your commit will cite.
6. `LEDGER.md` for the baseline and for your stage's empty section, which you fill in.
7. `evidence/ase-conventions.md` §10 before you write a document; §1 before you write a test.
8. `evidence/design-of-record.md` where a stage's reasoning is challenged — §0.1 is the
   nineteen measurements, §2 the decisions, §12 the twenty-nine corrections, §13 the stages,
   §14 the rulings, §15 what the plan refuses, §16 the twelve things still to measure. Read it
   as **evidence, not scripture**; `PLAN.md` §0 says where it was wrong.
9. The dossier for your area, from `README.md`'s table. **If your stage emits, reads back or
   offers anything, `evidence/variants.md`, `evidence/fork-dependencies.md` and
   `evidence/fork-features.md` are in your area** — they are what the fork/stock difference
   was actually measured in, and between them they close four questions a crew would
   otherwise re-derive: which fork commits are live-upstream bugs (35), which of them reach
   ASE-L's own emitted text (**one**), whether the fork has a blanket OP save (**it does
   not**), and whether stock 47 can be told from the fork by inspection (**it cannot**).

⚖ **R1 is answered — do not re-ask it.** The user ruled **Option A on 2026-09-10: keep `-b` in
this batch, `-p` stays deferred**, path of least resistance on milestones. They added a
requirement with it: **always salvage**, and warn the user wherever a Stop would still discard
work. That is affordable in `-b` — see the preflight and APPENDIX §6.8 — so it is no longer a
reason to change transport.

⚖ **R2 is answered too — do not re-ask it.** **Yes, with four conditions**, 2026-09-10: ASE-L may
write `<rundir>/.spiceinit` and copy the user's own file into it, provided the file is deleted and
rewritten per run, the user's lines are **copied** under a banner and never `source`d, the run log
says once what it shadows, and the whole mechanism is **refused** under `-n` and under the shared
`set_netlist_dir 0` rundir fallback. Stage 7's pre-deck class and Stage 11's design-variable axis
are unblocked; nothing else in the plan moved. **Ask ⚖ R3 next, and stop**; ⚖ **R10** and then ⚖ **R11** are the two filed behind everything
else — R11 (the minimum supported ngspice) is **new on 2026-09-10 and deliberately last**, because
the probe already answers *"how old is too old"* per binary and R11 asks only whether the download
page promises anything at all. One question at a time, discussed before the next is raised; that
is the user's standing instruction and R9 exists because twelve analyses would otherwise mean
twelve rounds of asking.
