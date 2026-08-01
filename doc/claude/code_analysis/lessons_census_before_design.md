# Census before design: how to build a cross-cutting feature with agents without paying for it twice

*A method retrospective, drawn from one real endeavour: adding Cadence-style waveform
markers to XSCHEM — twelve source files across C and Tcl, +2,450/−57 lines, twenty-one
bugs found, six of them pre-existing. The feature is incidental. The subject is
**method**: what preparation and what prompting would have produced the same result
faster, cheaper, and with less rework. Written for whoever does the next one.*

> **Companion reading.** This is the third of a family and deliberately does not
> repeat the other two. `lessons_multi_agent_orchestration.md` covers a *diagnosis*
> endeavour — why fan-out manufactures independence, and when not to pay for it.
> `lessons_green_is_not_correct.md` covers verification — why a green bar is evidence
> of presence, never of absence. This one covers a **greenfield build**, where the
> failure modes are different from both. Where it sharpens something they already
> say, it says so and states the delta.
>
> The feature itself: `doc/claude/specs/graph_markers.md`. The subsystem:
> `waveform_subsystem_reference.md`. The original request, with a proposed plan that
> was never implemented and was partly wrong:
> `references/cadence_style_waveform_markers.md` — **note this path is currently
> untracked**, so it exists in the working tree and not in a fresh clone.

---

## Part 0 — The endeavour, in one breath

The ask: markers on waveform strips, the way Cadence does them. Press `m` and a
callout pins itself to the nearest real sample on a trace — `M1:3.2n,1.14` — with a
leader line to an anchor dot. Press `d` and the next marker also carries a delta
block against the previous one. Click a marker to select it. Drag the **anchor** and
it slides along its own trace, snapping to samples; drag the **text** and only the
callout moves. Two visually similar gestures that must never be confused.

**What it cost.** Twenty-six subagents across four workflows plus one solo agent;
about 6.0 M subagent output tokens; 2,327 tool calls; roughly 7.4 hours of agent
wall-clock, on top of the main thread's own inline work.

**What it produced.** `src/` +2,450/−57 across twelve files; a 3,558-line headless
suite (607 assertions with a display, 310 without); a 1,293-line spec;
`waveform_subsystem_reference.md` +530/−56, taking its §11 landmine list from 34 to 40.
Twenty-one defects found: six pre-existing — including an **infinite loop**, a
**SIGSEGV** and a **heap corruption** latent for years — and fifteen in the new work,
every one caught before the user saw it.

**What it should have cost.** Rounds three and four — roughly 1.9 M tokens and 3.3 of
the 7.4 hours — were mostly *fix-induced churn*: fixing consequences of earlier fixes,
and resynchronising documentation written against a moving target. Perhaps half of
that was avoidable with an hour of different preparation. This document is about
which hour.

---

## Part 1 — The thesis

> In a greenfield build, the expensive mistakes are not the **hard** questions. They
> are the **exhaustiveness** questions. Every costly round of rework traced to a
> question of the form *"who **else** does X?"* — and those get answered one call site
> per review round, because that is exactly what review is good at.

Design questions were answered well the first time and stayed answered: the token
grammar, the coordinate space for the label offset, rendering under `draw_graph`'s
content flag rather than its UI-chrome flag, push-not-pull model sync. None churned.

Census questions behaved completely differently:

| Census question | When it was answered |
|---|---|
| Who duplicates a rect's `prop_ptr`? | `merge_box` in the plan · `copy_objects` in round **3** |
| Who calls `setup_graph_data()` outside a draw? | one site in round **2** · two more in round **3** · a fourth in round **4** |
| Who must reset this transient `xctx` state? | `xinit.c` in the plan · `clear_drawing()` in round **3** |
| Which paths mutate content (for the read-only gate)? | key arms round **3** · drag-commit round **4** · the viewer's mouse-release round **4** |
| Who calls `wviewer::regenerate`, and which of them fold live state back first? | **enumerated in the plan, before any code** |

Read the last row twice. It is the control experiment. The one census question the
planning phase answered by *enumeration* — because a mapping agent was explicitly
asked for the call sites — produced a design (a push hook from C into Tcl rather than
a pull) that shipped unchanged and caused **zero** rework. Every census question left
to emerge produced another round.

The numbers, verifiable today: **20** `wviewer::regenerate` call sites, of which
**4** call `capture_live_graph_state` first (19 and 3 before this work; markers added
one of each). The plan's agent reported "18 sites, only 3 capture" — off by one on
the sites. **It did not matter.** The census's value was never the integer; it was the
*ratio* and the conclusion it forced: most regeneration paths do not preserve live
state, one of them is a plain window resize, therefore a pull-only design silently
loses every marker when the user drags the window edge. That conclusion is robust to
a miscount, and it was worth the whole round.

**Why review cannot substitute.** An adversarial reviewer is superb at finding *the
next* missed call site and structurally incapable of *bounding the set*. It reports
"you missed `copy_objects`". It does not report "and here are all N doors, and here is
the grep that proves N". So an exhaustiveness question answered by review converges
**linearly** — one site per round — and each round costs a full workflow.

---

## Part 2 — What the up-front investment genuinely bought

**The subsystem reference doc was the biggest accelerant, and it was free.**
`waveform_subsystem_reference.md` already existed: 1,041 lines, 34 numbered landmines.
Reading it first is why the hard things were right on the first attempt — markers
render under `draw_graph`'s **flags bit 8** (durable content) and never bit 16 (UI
chrome, stripped from every export); a trace's model index and its node index are
different spaces (landmine 34); a query must build a stack-local `Graph_ctx` because
`xctx->graph_struct` is shared (landmine 11). None of those churned. **If the
subsystem you are about to change has a reference doc, the cheapest hour you will ever
spend is reading it before you plan. If it does not have one, consider whether the
feature is really the first deliverable.**

**Fan out the map, converge the design, fan out the attack.** Eight read-only mapping
agents in parallel (render, gesture engine, point-picker, persistence, viewer, verb
surface, tests, gesture conflicts) → one designer → three adversarial critics with
*different lenses* → one finalizer required to dispose of every finding. The critics
found five blockers and twelve majors **before any code existed**. Fixing a blocker in
a plan costs a paragraph; fixing it in code costs a workflow round. Three of the five
would otherwise have been multi-round bugs: the undo snapshot taken *after* the model
mutation, so `u` would have restored the marker it was meant to remove; the paste
renumber computing its base per record instead of once; and a press in a strip's top
margin failing to latch the routing latch, so the release was silently dropped.

**Single-author the delicate core.** The C engine — a picker refactor, a renderer, a
hit-tester and a gesture state machine threaded into an existing event handler — was
written by the main thread. Agents did the map, the review, the Tcl side, the tests
and the docs. This matches the sibling document's conclusion and is worth restating:
**orchestration is for breadth and independence, not for interdependent surgery.**

**Smoke-test the instant a vertical slice exists.** Two bugs died within minutes of
the first hand-written smoke script: `my_snprintf` is a minimal reimplementation in
this tree (`HAS_SNPRINTF` is undefined — the fallback at `util.c:571` handles only
`%s %d %x %c %u %p %g %e %f`) and does **not** understand `%.*g`; it consumed the
precision argument as the double and printed
`700.0000000000001136868377216160297393798828125`. And `setup_graph_data()` returns
early for an off-screen graph (`draw.c:3607`) *before* it parses `unitx`/`unity`
(`:3633`), so the label read `M2:0,0`. Neither is discoverable by reading.

Hold that against §3.2: the drag path was **not** smoke-tested early, and its bug
survived two full review rounds.

---

## Part 3 — The six churn engines, and the preparation that kills each

### 3.1 Census by review

Covered in Part 1. **Preparation:** Part 4.

### 3.2 No walking skeleton before the full build

Two defects would have died in twenty lines of throwaway code:

- **O(N²) render and hit-test.** The renderer called a *by-number* label builder per
  record, and the by-number builder rescanned and re-parsed every graph rect in the
  window. Nobody measured until round three, when a reviewer produced the table that
  made it undeniable: 0.1 ms at 0 markers, 1.9 at 50, 7.7 at 100, 32.4 at 200, 139.4
  at 400 — a clean 4× per doubling — *per redraw, on every pan, zoom and mouse press*,
  against a shipped cap of 512.
- **Frozen readout during a drag.** The anchor slid while the callout kept showing the
  pre-drag `x/y`, `Δx/Δy` and slope, because the label was re-derived from the marker
  *number*, which reads the stored token — and the stored token is deliberately not
  written until release. The readout is the entire reason a marker exists. Nobody
  performed a drag until round three.

**Preparation.** Before the design is finalised, build a **walking skeleton**: the
thinnest end-to-end path through *every verb the feature has*, on a real fixture, with
measured timings. Concretely, what that looked like here and what to copy:

```tcl
# hermetic fixture — no ngspice, no .raw file, deterministic 11-point grid
xschem raw new mk.raw dc vsweep 0 1.0 0.1
xschem raw add v_a {vsweep 1 +}
xschem set rectcolor 2
xschem rect 0 0 800 400 -1 "flags=graph\nnode=\"v_a\"\nsweep=\"vsweep\"\n..." 0
xschem zoom_full; xschem redraw
# never hardcode a pixel: scan for one the engine agrees is on a trace
for {set px 20} {$px < 900} {incr px 3} { ... xschem get graph_near_wave 0 $px $py 6 ... }
# then exercise EVERY verb, and time the expensive ones
set t0 [clock milliseconds] ; xschem draw_graph 0 ; # ... repeat, report ms
```

Five operations — create, render, one full press-drag-release, read back, delete —
one afternoon hour, and it retires an entire class. The two rules that make it worth
anything: **a hermetic fixture** (`raw new` + `raw add`, so the grid is exactly
eleven samples at 0.0…1.0 and every snap assertion is a literal constant) and **never
a hardcoded pixel** (scan with the engine's own hit-test verb, and fail loudly if the
scan finds nothing).

### 3.3 "Open decisions" are deferred churn, and a policy is not a decision

The plan ended with a table of open decisions. One of them — read-only, which shipped
as spec **§2 D6** — went through **four** states:

1. the plan recommended shipping *ungated*: the C graph path already writes
   `hilight_wave` and cursor positions into read-only rects, so precedent said leave
   it;
2. implementation gated it with `readonly_block()` in the key arms;
3. round-four review: `readonly_block()` pops a **modal** (`callback.c:47`,
   `tk_messageBox`), and a modal on a keystroke deadlocks any script that drives the
   refusal — it hung the marker suite forever under a real display — *and* the key
   arms miss the drag-commit path entirely, so a **mouse** gesture could still
   permanently edit a read-only buffer with no undo point;
4. moved to a non-blocking refusal inside the four mutating primitives — which then
   broke the viewer's mouse drag, requiring the release forward to be wrapped in
   `with_edit`.

Four rounds, one decision. And the answer was visible in round one: **the feature
already had its own refusal channel** — `graph_marker_refuse()` → `ciw_echo`
(`draw.c:5599`), used by "no trace near the pointer", "markers are not supported on
digital strips", "too many markers on this graph". Every refusal in the feature was
non-blocking. Only the read-only one reached for a modal.

**Preparation, two rules:**

- **Resolve policy decisions before implementation.** An open decision in a plan is a
  decision that will be made under time pressure by whoever hits it first.
- **A decision is not finished until it names the enforcement *point*.** "Read-only
  refuses markers" is a policy. "Read-only is enforced in the four mutating primitives
  using the feature's existing non-blocking refusal channel, because a modal on a
  keystroke deadlocks a driving script and because the key arms do not cover the
  drag-commit path" is a decision you can implement once.

Forcing question for any new user-facing operation: **"What channel does this
subsystem already use to say no, and why would this refusal be different?"**

### 3.4 Documentation written against a moving target

Docs were written in round two; round three landed nine fixes; round four landed four
more. A whole extra agent — 213 K tokens — existed only to resynchronise eight-plus
stale claims, and it still found the test file's banner comments describing a design
that no longer existed.

What survived the churn: **invariants and rationale**. What did not: `~line`
references, enumerations of call sites, and any sentence naming a specific function as
*the* place something happens.

**Preparation:** run the docs agent **once, last**, after the final review settles. If
it must run earlier, instruct it explicitly: *write the invariants and the reasoning;
do not enumerate call sites and do not cite line numbers — those will move.*

*And the honest coda that proves the rule:* even the resync agent did not catch
everything. `waveform_subsystem_reference.md:1447` still says the post-review fixes
"each still owe a named leg" — they do not; MF11b, MF12, MF13a and MF14 all exist and
pass. A sentence written against a moving target survived two passes of people
looking for exactly that.

### 3.5 A test harness whose bugs eat coverage silently

Two harness defects, both worse than any product bug they hid:

- `check_true name [pcall {...}]` evaluated `expr {$cond ? 1 : 0}` on `pcall`'s
  result. When the inner script errored, `pcall` returned the *string* `ERR:<msg>` and
  `expr` **threw**. At top level that unwound into the file's single outer catch: one
  error line, and everything after it silently never ran. A failing run reported
  "7 FAILED (457 passed)" — it had lost **144 checks** and said nothing.
- A `--pipe` run whose X server was briefly unreachable came up text-only and reported
  a cheerful `RESULT: ALL PASS (307 checks)` — half the suite untested,
  indistinguishable from a deliberate `--nogui` run.

**This is `lessons_green_is_not_correct.md` Lesson 2, sharpened.** That document
already prescribes a positive proof-of-completion emitted as the last action. The
increment here is that **a completion sentinel proves you reached the end; it does not
prove you did not skip the middle.** Three invariants, about thirty lines, written
*before* the legs:

1. **a leg that errors FAILS loudly** rather than aborting the file — this is the
   non-throwing `check_true`/`pcall`/`pexpr` trio plus per-group catches, not a
   sentinel;
2. **the run asserts its own expected check count** (`MZ1`), so silent coverage loss
   is itself a failure — the sentinel (`MZ2`) is the *detector* for a rule-1
   violation, not rule 1 itself;
3. **the run asserts the environment it thinks it is in** (`MA0`): if `DISPLAY` was
   set, `--nogui` was not passed, and the app came up headless anyway, that is a
   failure.

**The tax, which you must budget for:** rule 2's counts are hand-maintained constants
(`set ::mk_expect_x 605` / `mk_expect_nogui 308`). Every added leg means running both
arms and editing two numbers. Someone will forget, get a red suite, and be tempted to
delete the guard. Say so in the file — this one does, at `:3529`.

### 3.6 A fix that changed a resource's acquire/release shape

Hoisting `extra_rawfile()` out of the per-node loop was a legitimate fix: the per-node
form leaked. But it made the *restore* unpaired, and `extra_rawfile(5,…)` is a **swap
of two indices** (`save.c:1373-1378`), not a stack pop. Consequence: a pure hover query
on a graph whose `rawfile=` does not resolve silently repointed the session's current
raw **on every call**.

Two generic "review the diff" passes missed it. The round-four prompt that found it
immediately was targeted: *"verify no path can switch and fail to restore, or restore
twice."*

**Preparation:** when a refactor moves *where* a resource is acquired or released,
that refactor gets its own named review question. Generic review does not find pairing
bugs; pairing questions do.

---

## Part 4 — Phase 0: the census

The single highest-leverage change. Before design, run one read-only agent per census
question. Each returns an exhaustive `file:line` table **and the argument that proves
the table complete**. That last clause is what turns an answer into a bound.

**The mechanical detail that makes it work: grep in command position.** In Tcl,
`grep -c regenerate src/wave_viewer.tcl` returns **76**; the real call-site count is
19. A 4× error, and it is the most transferable thing in this whole endeavour:

```sh
grep -rnE '(^|[[:space:]\[;{])wviewer::regenerate[[:space:]]' src/*.tcl   # then drop the `proc` line
```

For C, the equivalent is `\bfunc\s*\(` while excluding the definition and the
prototype. Say which form you used, in the report.

**The generic families, which recur in almost any XSCHEM feature:**

1. **Duplication doors.** Who copies this object's `prop_ptr` / id / unique field?
   Here: `merge_box` (`paste.c`) *and* `copy_objects` (`move.c`) — and they run on
   **opposite sides** of `gfx_register`, so in one the new rect is already visible to
   a numbering scan and in the other it is not. The reason a single
   `graph_marker_renumber_rect()` is correct in both is that it computes its base
   **once**; a per-record base would have been right in one door and wrong in the
   other, which is precisely the bug an adversarial critic caught in the plan.
2. **Teardown sites.** Who must reset this transient state? `xinit.c` per-context init
   *and* `clear_drawing()` — the same `xctx` is reused by `xschem clear`, File>Open in
   the tab, `xschem load` and the disk-undo reload, so a surviving selection latched
   onto whatever object in the *new* document carried that number.
3. **Mutation paths.** Every route by which the feature changes durable state. Four
   here — keys, the Tcl verb, the drag-commit, and the viewer's wrapped forward —
   discovered over three rounds.
4. **Regeneration / invalidation sites.** Who rebuilds the thing you are storing state
   on, and which of them preserve it? The census that worked.
5. **Shared-context mutators.** Who calls a setup function with global side effects
   from outside the context it was designed for? Four in the feature
   (`graph_point_at`, `graph_marker_at`, `graph_marker_create`,
   `graph_marker_drag_to`, all now bracketing `graph_flags` bits 128|256) — **and more
   outside it** (`scheduler.c:4980`, `:10835`, `:10844`, `:11358`) which are
   pre-existing and unbracketed. Scope the question, and say what you scoped it to.
6. **Precedence chains.** For a new gesture: the complete ordered list of what already
   claims that button, in *every* context the code runs in. Here: cursor grab,
   wave-bold click, strip reorder, trace drag, box-zoom, pan — in both the on-canvas
   graph and the ASE viewer, whose Tcl filters get first refusal.
7. **C↔Tcl mirrors.** The recurring hazard in this codebase specifically — `grep
   'MIRRORED IN TCL'`. Any feature touching `xschem.h`, `scheduler.c` and a `.tcl`
   file is standing exactly where it bites: constants duplicated on both sides
   (`GRAPH_REORDER_HANDLE_W` and `wviewer::strip_handle_at_pixel` are the worked
   example), config vars declared in `xschem.tcl` and read with `tclgetintvar`, and
   any hit-test whose geometry exists twice.

**The prompt shape:**

> Enumerate **every** call site of X. Return a `file:line` table. State the exact grep
> or structural argument that proves the list complete, and say what would make it
> incomplete. If you cannot prove completeness, say so — an unbounded answer is more
> useful than a confident partial one.

**Where the answer lives.** A census answer that stays in a workflow transcript decays
and gets rediscovered in round three. In this repo it belongs as a **numbered landmine
in the subsystem reference** — which is, after the fact, exactly what happened:
landmines 37 ("`setup_graph_data` rewrites `graph_flags` and returns early before
parsing units"), 38 (the sweep-token carry-forward) and 39 (two duplication doors) *are*
census answers, written down at the end instead of used at the start. Writing them
first closes the loop with Part 2: this endeavour's biggest accelerant was the previous
endeavour's census.

**When not to run one.** A census family is worth a round only when a missed site
ships a **correctness** bug. If the worst case is cosmetic — a stale repaint, a
misaligned label — let review find it. The stopping rule: run the family if you can
name the wrong behaviour a missed site would produce and it involves lost data, a
crash, or a silently ignored user action.

---

## Part 5 — The prompt clauses that earned their keep

Copy these. Each produced measurable value here.

- **`READ ONLY — do not edit any file.`** on every map and review agent. See
  `lessons_subagent_git_reset.md` for why this matters more than it looks.
- **`Every problem must carry EVIDENCE from the real code (file:line or a quote) or
  from a command you actually ran, with its output.`** The highest-value clause in the
  set. Findings backed by a probe were essentially all real; findings from reading
  alone had a visibly higher false-positive rate. The O(N²) finding arrived as a
  measured table and was undeniable.
- **`Default to REPORTING when uncertain, but say so.`** Produced honest labels like
  *"latent rather than observed — I did not reproduce a wrong render"*, which is
  exactly what triage needs.
- **`If you find nothing in your lens, return an empty list — do not manufacture
  findings.`**
- **`Flag anything that contradicts the reference doc — its line numbers drift and its
  prior plan was never implemented.`** This *licenses agents to correct the map*, and
  they did: landmine 19 turned out to be factually wrong and was rewritten. Without the
  licence, agents treat a checked-in doc as ground truth.
- **`Where two mapping agents disagree, say so explicitly and pick, with reasoning.`**
- **`A test that fails because the PRODUCT is wrong: do not paper over it — report it
  as a defect with the evidence and leave the assertion failing.`**
- **Structured output schemas** (`severity` / `file` / `problem` / `evidence` / `fix`).
  Makes triage mechanical, and makes an evidence-free finding obvious at a glance.
- **Distinct lenses for review agents** — correctness/landmines,
  interaction/regression, persistence/model-sync. Note this is the *opposite* of the
  sibling document's advice to overlap the mapping lanes, and both are right for their
  phase: **overlap the map** so two independent readings corroborate a fact; **partition
  the review** so three critics do not triple-pay for the same finding.
- **The sabotage table** — already prescribed by both companion documents; the
  increment here is the *naming* requirement: *"for each sabotage, name the leg that
  must go red. If no named leg can go red, that is a HOLE in the suite and you must fix
  the suite."* That phrasing caught three holes that were otherwise green. Pair with
  *"restore `src/` exactly and md5-verify the restore."*

### The four clauses that were missing

- **`Enumerate every call site of X and prove the list exhaustive.`** (Part 4.)
- **`Name the enforcement POINT, not just the policy. What channel does this subsystem
  already use to refuse, and why would this refusal differ?`** (§3.3.)
- **`Before designing, build a walking skeleton exercising every verb end to end on a
  hermetic fixture, and report measured timings.`** (§3.2.)
- **`This refactor changes when a resource is acquired or released. List every path and
  pair them.`** (§3.6.)

---

## Part 6 — The honest counterpoint

Preparation would **not** have prevented everything, and pretending otherwise makes the
playbook useless.

- **`my_snprintf` not understanding `%.*g`** is unknowable without executing. The
  mitigation is not planning, it is smoke-testing early — which worked.
- **Six pre-existing bugs** — the bus infinite loop, the sweep-token shift, the
  `extra_rawfile` leak, the uninitialised `ofs_end`, the `--nogui` SIGSEGV, and
  `raw_deletevar`'s `sizeof(p) * nvars + 1` precedence bug — were found precisely
  *because* this work walked code nobody had walked in a while. That is dividend, not
  churn. The heap corruption had been backlog item 3 of the reference doc for months
  and surfaced only because this suite is the tree's first caller of `xschem raw del`.
- **Some rework is the system working.** Round-one critics found seventeen problems in
  a plan; that is the plan phase doing its job cheaply. The rework worth eliminating is
  specifically Part 3's kind — consequences of fixes, and answers arriving one call
  site at a time.
- **The WSLg input-focus race** cost a de-flake round and would have cost it whenever
  it was paid. But do not write the round off as pure loss: it produced a **reusable
  asset**. Any future Tk gesture suite in this repo should lift
  `test_wave_markers.tcl`'s `mk_prep_ctx` / `send_key_fb` / `mf_arm` / `mx_arm` — the
  pattern is *re-establish the precondition, retry a bounded number of times, print a
  `note:` on every retry so a flake is visible, then emit a distinctive
  `MARKER-TEST-STALL:` rather than passing* — together with its governing rule, **no
  retry may pass by testing less**.

And a caution the other way: **do not front-load so much that you design against an
imagined system.** The census is cheap because it is mechanical and verifiable. A
speculative "design every edge case first" phase is neither, and would have produced a
worse plan than three adversarial critics attacking a concrete draft.

---

## Part 7 — The playbook

**Before planning**

0. Read the subsystem reference doc end to end. If there is none, write one first, or
   accept that you are paying for it inside the feature.
1. **Run the census** (Part 4) — one read-only agent per exhaustiveness question, each
   returning `file:line` plus a completeness argument, using a command-position grep.
   Do it *before* the design agent, and feed it in. Record each answer as a numbered
   landmine, not as a workflow transcript.
2. **Build the walking skeleton.** Thinnest end-to-end path through every verb, on a
   hermetic fixture, with measured timings and no hardcoded pixels. Expect one bug that
   reading cannot find.

**Planning**

3. Fan out the map (read-only, overlapping lanes), converge to one designer, attack
   with three *partitioned* adversarial lenses, converge to one finalizer who must
   dispose of every finding explicitly.
4. **Close every policy decision, and require each to name its enforcement point.**
5. Require a **landmine compliance walk** naming each numbered landmine the design
   touches and how it complies.

**Building**

6. Single-author the interdependent core. Delegate breadth: the other language, the
   tests, the docs.
7. **Harness invariants before test legs** (§3.5), and budget for the hand-maintained
   check-count tax.
8. Freeze the public API — verb names, signatures, result shapes — before delegating
   anything that consumes it.

**Reviewing**

9. Adversarial review with evidence-or-it-did-not-happen, partitioned lenses,
   structured output, and an explicit licence to return nothing.
10. Add a **named review question for every refactor that moved a resource's
    acquire/release**, and for **every fix landed since the last review** — late fixes
    are written under time pressure and get the least scrutiny. Both blockers in this
    endeavour's last two rounds were in code younger than the previous review.
11. Sabotage-verify: each sabotage must turn a *named* leg red; `src/` md5-restored.

**Finishing**

12. Docs **last**, once, after the final review settles. Invariants and rationale; no
    line numbers, no call-site enumerations.
13. Soak any gesture suite ten-plus times before declaring it green — a one-in-six
    flake reads as green on the first run. Budget for it: under a real or WSLg
    `$DISPLAY` these suites take over the machine, which is why
    `tests/headless/gui_gate.sh` exists (`doc/claude/specs/gui_test_gate.md`). Ten runs
    is a scheduled event, not something to start and walk away from.

---

## The one thing to remember

> Ask *"who **else** does this?"* — and demand the proof that the answer is complete —
> **before** you design, not one reviewer at a time afterwards. Adversarial review
> converges on an exhaustiveness question **linearly**, at one workflow round per missed
> call site. A census answers it once, mechanically, for the price of a single cheap
> parallel pass.
>
> The evidence is the table in Part 1: the one census question this endeavour answered
> by enumeration up front produced a design that shipped unchanged — and it did so even
> though the count in it was off by one, because what a census buys is the **bound**,
> not the integer. Every question left to emerge produced another round.
