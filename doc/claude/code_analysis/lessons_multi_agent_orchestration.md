# Same brain, more eyes: what a buried net taught us about how agents should think together

*A lessons‑learnt tutorial, drawn from one real endeavour: diagnosing and fixing a
long‑standing cross‑window net‑highlighting bug in XSCHEM. The bug is incidental.
The subject is **method** — why a single high‑effort reasoning pass can fail on a
task like this, why multi‑agent orchestration succeeded, and, just as important,
when orchestration is the wrong tool. Written for a computer‑science‑literate
reader. It leans on human analogies throughout, because people remember a story and
a picture long after the abstraction has faded.*

> **Companion reading.** The technical write‑ups this reflects on:
> `net_highlight_hierarchy_and_linked_windows.md` (how the subsystem works),
> `net_highlight_linked_windows_agent_guide.md` (the fix, for a coding agent), and
> `doc/claude/issues/0073-hilight-not-synced-into-linked-descend-new-window.md`
> (§10, the resolution). This document is about *how the work was done*, not the
> code.

---

## Part 0 — The endeavour, in one breath

A user reported a bug that several prior attempts had not fixed: highlight a net in
a secondary window that has been descended **two levels deep** into a schematic, and
it does not light up in the primary window — yet pressing `0` to *un*‑highlight
everything **does** propagate across the two windows. Highlighting fails to cross the
gap; clearing crosses it fine.

The work went in two acts. **Act I** was analysis: produce a rigorous map of how net
highlights propagate through a design hierarchy and how the same highlight is kept in
sync across multiple linked windows. **Act II**, at the user's request, was the fix.

The path taken was not one long think. It was: scout inline briefly; then **fan out**
into eleven specialist agents (nine reading one subsystem each, two whose only job was
to *attack* the load‑bearing claims); discover that the "bug" was in fact a
*documented, deliberate* limitation, not a regression; kill a seductive‑but‑wrong fix
idea before it could waste the effort; then converge to a **single author** for the
delicate C of the actual fix — a *transient‑netlist relay* — and finish with an
adversarial review of the diff that caught a real contract bug the passing test suite
had missed.

It worked. And the interesting question is *why the shape of the work mattered at
all*, given that every agent in it was the very same model with the very same
reasoning budget.

---

## Part 1 — The thesis: orchestration manufactures **independence**, not intelligence

Here is the single idea to carry away, before the stories that make it stick:

> Multi‑agent orchestration did **not** make the model smarter. It was the same model
> in every seat. What it manufactured was **independence** — independence of *working
> memory* (each fact held at full fidelity by a context whose only job is that fact),
> of *stake* (a claim is audited by a mind that did not author it), and of *incentive*
> (a skeptic rewarded for breaking a hypothesis, not confirming it). A lone context is
> forced to be believer, holder, and auditor all at once, on a desk far too small — and
> it audits the way every author audits their own belief: by looking for confirmation.

That is the whole lesson. Everything below is either a reason a lone pass loses that
independence, a reason to *not* pay for it when it isn't needed, or a caveat about what
independence orchestration still cannot buy.

---

## Part 2 — Five ways a lone high‑effort pass is at risk

### 2.1 The bounded desk — *working‑memory economics*

Every reasoning context, human or model, is a **desk, not a warehouse**. It has a
finite surface on which facts stay sharp enough to be *combined*. Pile on more and the
oldest items don't get deleted on purpose — they slide off the edge. This is why a fact
established on "page 1" of a long single‑pass reading is often silently gone by "page
40." The failure is *invisible*, which is exactly what makes it dangerous: the pass
keeps producing confident prose built on a fact it no longer actually holds, and it
cannot tell that it has forgotten.

> **Picture an election‑night desk editor.** Their head carries exactly one thing: the
> front‑page plan and the electoral arithmetic, and it must stay pristine until
> midnight. They physically *cannot* also be the person staring at one county's precinct
> feed refreshing every ninety seconds — that raw stream would evict the plan within
> minutes. So fifty reporters each watch one state's returns all night and file a single
> sentence: *"Called: Nevada, Dem, 89% in."* The editor composes the page from
> sentences, never from feeds. The raw data is held deeply — but out at the stations, by
> contexts whose only job is that one state.
>
> **Mapping:** editor = the orchestrator context (holds the plan, never the raw data);
> each reporter = a subagent owning one subsystem; the filed one‑liner = a distilled
> structured finding; the precinct feeds that never leave a reporter's screen = the
> ~850k tokens of source the orchestrator never had to read.

In this endeavour the relevant file, `hilight.c`, is about four thousand lines, and the
fix touched six files. The fix function alone demanded simultaneous, full‑fidelity recall
of at least four invariants that share *no cognitive category*: that `find_nth`/`strtok`
reuse static buffers so their results must be copied immediately; that a vector‑slice
index carries an off‑by‑one; that a global `has_x` flag must be forced to zero around the
transient loads or a GUI‑only path dereferences a null graphics context; and that the
global `xctx` pointer must be restored on *every* exit path. Each is a whole reporter's
beat. Eleven agents digested the source while the orchestrator only ever saw the filed
sentences.

**Lesson.** Match the unit of delegation to the unit of working memory: give each context
exactly one invariant‑dense slice it can hold at full fidelity, and route only a distilled
verdict across the boundary. A useful heuristic — *count the independent, full‑attention
invariants a task demands; that count is a lower bound on how many ways to split it.*

### 2.2 The stale eyewitness — *confirmation bias and dated memory*

Every project accumulates a memory: issue trackers, design notes, a `MEMORY.md`. These
are indispensable, and they are also **eyewitness testimony** — accurate the day they were
written, silently aging thereafter. This session opened on exactly such a witness. The
project memory declared, twice, that the cross‑window highlight feature was "FIXED" and
"COMMITTED." The user then reported a bug that flatly contradicted it. The path of least
resistance — and the cheapest, most authoritative‑feeling move for a lone agent — was to
trust the note and conclude the user was mistaken. And this is the treacherous part: a
*high‑reasoning* pass that anchors on a stale premise will reason flawlessly to a wrong
conclusion. Extra horsepower only makes the wrong turn faster and more convincingly argued;
the defect is in the starting premise, not the inference.

> **Picture a detective reopening a cold case.** The file's cover sheet, in the previous
> lead's hand, reads in bold: *"SOLVED — CASE CLOSED."* The lazy move is to tell the new
> complainant they're confused. The disciplined move is to treat that cover sheet as a
> year‑old summary — not the crime scene — and read the file *underneath*, where the same
> detective wrote: *"Note: downtown burglaries remain unsolved, same MO, deferred."* The
> cover sheet never lied. It was true about the murder it closed. The new complaint is the
> deferred burglaries.
>
> **Mapping:** the cover sheet's "CASE CLOSED" = the memory's "issue 0073 FIXED"; the reflex
> dismissal = the lone agent's least‑resistance path; reading the file underneath =
> re‑deriving from the *current* source; the deferring detective's own note = the "still
> deferred" clause that sat right beside the "FIXED" stamp.

Re‑deriving from primary evidence revealed that both records were true at once. The issue
document's own "still deferred" clause coexisted with its "FIXED" stamp, and a source
comment did more than contradict the note — it *predicted the user's exact fingerprint*:
clearing crosses the untranslatable gap, "but populating never crosses the gap." That one
sentence explains why `0` propagated while a highlight did not. The bug was real, but it
was the documented deferred case, not a regression.

**Lesson.** Treat your own notes, docs, and memory as dated eyewitness testimony, not
ground truth. When a fresh report contradicts an "already handled" record, re‑derive from
primary evidence *before* acting — and route that re‑derivation through a context with **no
stake** in the prior conclusion, because the author of a belief is the worst auditor of it.
And read past the *status* line ("FIXED") to the *scope* line ("deferred"): both can be true
in the same record.

### 2.3 The unrefuted hypothesis — *falsify before you build*

Every debugging effort spawns a tempting shortcut. Here it was a beauty: *"the drill option
already walks the design and precomputes the deep‑level highlight entries, so the fix is just
to stop dropping them across the gap."* It was cheap (delete a few lines), plausible (the code
clearly does *some* propagation), and exactly the kind of idea a lone agent falls in love with
— precisely because the agent generated it. A single pass, having produced that hypothesis,
"checks" it — and checking, done by the same mind that authored the guess, almost always
collapses into *confirming*. Confirmation is easy because it is asymmetric: for almost any
claim, *some* reading of a four‑thousand‑line file is consistent with it.

> **Picture a chess sacrifice.** A weaker player finds a combination that *looks* winning and
> analyses only the lines where the opponent cooperates — every variation ends in mate, so they
> play it. A stronger player does the opposite: before touching the piece, they hunt for the
> single *refuting* reply that busts the whole thing. Soundness is never "I found a line that
> works"; it is *"I searched hard for the line that breaks it and could not find one."*

The orchestration hard‑wired the stronger search. A dedicated verifier — no authorship, no sunk
cost, an explicit mandate to *refute* — read the source cold and found the refuting move: the
drill mechanism is *lateral*, same‑level propagation through pass devices; it is off by default;
it never writes a deep‑path entry. The "precomputed" entries the shortcut relied on **do not
exist.** The combination was busted at the board, before a line of the real fix was written on a
false premise — and the real fix had to do the *opposite* of the shortcut.

One subtlety keeps this honest: the skeptics were **not rubber stamps**. A second verifier was
handed the four‑symptom bug trace and *confirmed* it line‑by‑line. One hypothesis died, one
survived — which is the only thing that makes a surviving verdict mean anything. A checker that
only ever kills, or only ever confirms, carries no information.

**Lesson.** For any load‑bearing assumption, spawn a separate context whose reward is *breaking*
it, and point it at the primary source, not your summary. Judge a hypothesis by whether it
survives a genuine attempt at falsification — never by how many confirming readings you can find.
And keep your skeptic calibrated by also feeding it claims that *should* survive.

### 2.4 The tunnel — *distributed truth needs parallel coverage*

A subsystem's truth is often not a wall of independent facts; it is an **organism**. Here, the
composite‑key data model (a highlight is a `(hierarchy‑path, net‑token)` pair) feeds the pin/bus
translation math, which feeds the buried‑net cue, which is bound by an invariant — *stale >
missing > wrong* — that lives nowhere in particular and everywhere at once. Read it serially, one
file at a time, and you meet these parts as strangers: by the time you understand the sync engine
you have half‑forgotten the data model, and the rule that ties them together clicks only on the
last page, if at all. This is where a single pass *tunnels* — it builds one mental model, fixates
on the visible wound, and confirms its own first hypothesis.

> **Picture a trauma team working one patient** (not a lone GP working a queue). Airway,
> circulation, and the surgeon each own a system and work *at the same time*, calling out what they
> see. The surgeon is head‑down on the obvious laceration; it is the anesthesiologist's *"pressure's
> dropping"* — a fact from a different vantage — that reveals a bleed the suturing would never have
> found.
>
> **Mapping:** the patient = the one net‑highlight organism rooted in `xctx`; the surgeon = the
> cross‑window sync engine; the anesthesiologist watching vitals = the "stale > missing > wrong"
> guardian; the perfusionist keeping blood moving through an *offline* organ = the transient
> windowless scratch context that loads a netlist for a level no window holds; the scrub nurse
> counting sponges in and out = the memory discipline (every scratch context freed, `xctx` restored
> on every exit).

That is what the fan‑out did. Nine agents partitioned the organism and read all of it at once, and
their findings *overlapped at the seams* — and the overlap **was** the diagnosis. Two independent
readers converged on the same bit‑index formula and the same `has_x` gate, which is what let the
team trust both readings; and the coverage surfaced the cross‑cutting fact a serial reader would
have reached last, if ever: that the "bug" was the deliberate deferred limitation, a fact only
legible by holding the data model and the buried‑cue invariant *together at the same instant*.

**Lesson.** When truth is smeared across interacting parts, partition the **reading**, not just the
writing — one specialist per part, in parallel — and deliberately *overlap* their lanes so the
load‑bearing facts get corroborated from two vantages. Coverage first; then convergence. A serial
reader can only be *right*; a line of specialists can be *checked*.

### 2.5 Placebo green — *correctness is earned by trying to break your own work*

Delicate C is exactly where a single confident pass ships a beautiful, plausible bug. And the
reflexive proof of correctness — "the tests pass" — is a **placebo** until you have watched the
tests *fail*.

> **Picture a vaccine trial.** A patient who "looks healthy" proves nothing: health that has never
> been challenged is indistinguishable from a placebo — a body that simply never met the pathogen.
> So the immunologist does the counterintuitive thing: injects a controlled, weakened dose of the
> very disease and watches for a visible immune response. Only the *response* proves the antibodies
> were ever real.
>
> **Mapping:** the green suite = a claim of immunity; a test you have never seen fail = untested
> immunity that might be a placebo; the sabotage step (a kill‑switch that disables the fix) =
> injecting the known pathogen; the assertion flipping **red** = the immune system visibly
> responding, proof the antibodies exist.

Two real defects in this session make the point. First, the *headless trap*: the fix loads
schematics into a windowless scratch context, and those loads take GUI rendering paths that would
dereference a null graphics context when there is no window — avoided *only* by deliberately asking
"what code runs here that I don't want?" and forcing the headless path around the loads. A pass that
never asks that question crashes under load. Second, the *contract bug*: when the target window could
not be borrowed, the fix returned "success" instead of falling back — and it **passed 44 checks**. An
independent adversarial diff review — a reader who had not written the code, and so did not share its
blind spots — caught it.

Then the tests *earned* their green. An oracle was derived from a known‑good path (the behaviour a
fully‑open descend chain must match). Two assertions that had encoded the old limitation ("primary NOT
populated") were **flipped** to the new correct behaviour (the surfacing net now lights the primary,
with no false cue). And the vaccine: a sabotage check disables the relay and asserts the surfacing net
must *not* light — proving the assertion can turn red, and pinning the relay itself, not some incidental
path, as the mechanism.

**Lesson.** A test you have never watched fail is not evidence — treat it as a placebo. Before trusting
green on any nontrivial change: derive the oracle from a known‑good path; confirm the assertion is red
*before* your fix makes it green; deliberately sabotage the code and confirm the test goes red; and get
someone who did **not** write the code to review the diff. "It passed" is not correctness. "I re‑broke
it, watched the alarm fire, and a stranger tried to break it again and failed" is.

---

## Part 3 — The honest counterpoint: when orchestration is the *wrong* tool

It is tempting to read this as "eleven agents beat one, therefore always fan out." That is the wrong
lesson, and an expensive one. Orchestration did not make the model think better — same model
everywhere. What it bought was breadth and independent checking, and those are **not free**: on the
order of a million subagent tokens, real wall‑clock coordination, and a *reconciliation tax* whenever
agents return overlapping or conflicting findings the orchestrator must resolve. "We ran eleven agents"
is not "we were right."

> **Picture a newsroom.** When nobody knows where the corruption is buried, an editor assigns a dozen
> reporters to separate beats and runs every explosive claim past a fact‑checker paid to disagree —
> because printing a confident lie is worse than printing nothing. But the same newsroom does **not**
> convene the investigative desk when a reader emails that you misspelled the mayor's name: one copy
> editor fixes it in ten seconds. And when it is finally time to *write* the exposé, **one** writer holds
> the pen, so the piece has a single voice — the reporters *feed* the writer; they do not each write a
> paragraph and staple it together.

All three moves showed up here, deliberately. The assistant **scouted inline first** — reading its own
memory and the key functions — before spending a single subagent; you don't convene a task force to
change a lightbulb. The fan‑out earned its cost at one identifiable point (killing the drill hypothesis).
And the delicate implementation was pointedly **not** fanned out: the fix is one function authored by a
single mind, because coherence — the scratch‑context lifecycle, the `has_x` discipline, the buffer‑copy
guards, the balanced pointer restore, one consistent contract — cannot be stapled together from twelve
paragraphs. Even then, that single author still needed exactly one outside check on the boundary — and
it paid for itself.

**Lesson.** Calibrate to *uncertainty × blast‑radius*, not to ambition. Fan out only when the location is
unknown or broad **and** a wrong answer is expensive. Fan out to **search** and to **verify**; converge to
**one author** to **build** anything delicate; then give that author exactly one outside diff‑check. Counting
agents is not measuring correctness.

---

## Part 4 — The caveats the five lenses miss (the advanced lessons)

The stories above are the memorable 80%. These are the sharp edges that separate someone who *uses*
orchestration from someone who *understands* it.

**1. Correlated blind spots — diversity of vantage is not diversity of cognition.** Fan‑out buys
independence of *context* and *stake*, but every agent is the **same base model**. A systematic error the
model is uniformly prone to survives all eleven seats — the trauma team is one surgeon's brain cloned. This
is the single most important caveat, and it explains why the *real* proof in this session was not another
agent's opinion but an **executable sabotage test** that turned an assertion red. True independence needs a
*different kind* of checker: a runnable oracle, a different model, or a human. When you catch yourself
trusting a conclusion because "many agents agreed," ask whether they could all be wrong in the same way.

**2. Lossy distillation is a hazard, not only a virtue.** The one‑liner that keeps the editor's desk clean
can also drop the load‑bearing caveat — the reporter who files "Nevada 89% in" but omits "the remaining 11%
is all rural precincts." The mitigation: structured findings should carry their **own confidence and their
exceptions**, and the orchestrator must retain the ability to pull the raw source when a summary reads
suspiciously clean. *Trust the distillate, but keep the drill‑down.*

**3. The decomposition is the load‑bearing single decision — and it never leaves the orchestrator.**
Parallelism cannot rescue a bad partition. You do not *escape* single‑point reasoning by fanning out; you
**relocate** it up a level, to the choice of seams — which therefore deserves as much care as the fix itself.
Note *how* the split was drawn here: along **invariants and subsystems**, not along files. A per‑file split
would have smeared the cross‑cutting truth (the deliberate deferral) across the seams and missed it. Choosing
where to cut is the one place the lone reasoner cannot be checked, so spend real thought there.

**4. There is an oracle hierarchy, and internal confidence sits near the bottom.** The entire arc was
triggered by a *user's lived symptom* contradicting a "FIXED" note. Rank your sources of truth accordingly:
**executable check / reality > human observation > primary source > summary or memory.** However well‑reasoned,
internal confidence must always yield to an outside reality signal. That ordering is *why* re‑derivation was
the right reflex, and why a red sabotage assertion outranked a unanimous panel.

**5. Knowing when to stop is as much a skill as knowing when to fan out.** Skepticism has diminishing returns.
Two adversarial passes plus one executable sabotage was a *calibrated stopping point*, not infinite doubt. A
task force that never disbands is its own failure mode — symmetric to convening one for a typo. **Stopping
rule:** stop when independent re‑derivations converge *and* an executable oracle fires.

**6. Orchestration ships an audit trail for free.** Structured findings with exact `file:line` citations make
the reasoning inspectable, re‑runnable, and reviewable — unlike a single context's disposable internal
monologue. Correctness aside, that reproducibility is a real deliverable, and a reason to prefer the multi‑agent
form when the work must later be *defended* or revisited.

---

## Part 5 — The deepest technical moral: do the computation, don't drop the data

Every lens above is about *process*. But the endeavour also carries a moral about the *fix itself*, and it is
the one most worth teaching.

The old code faced an impossible‑looking choice across an untranslatable gap and chose **"missing"** (drop the
deep highlight entries) to avoid **"wrong"** (paint a false "buried‑net" cue on a net that actually surfaces).
That triage — *stale > missing > wrong* — is excellent engineering judgement: never show a confident lie. But it
is a **fallback, not a destination.** The relay fix refused all three outcomes by paying the compute the old code
had dodged: it *loads the intermediate netlist* and does the real translation.

And here is the elegance to remember: **the same computation that decides "surfaces vs. buried" both fixes the
bug and dissolves the original hazard.** Once you actually load the netlist, a surfacing net supplies its real
shallow name (which suppresses the would‑be false cue), and a genuinely buried net yields nothing and keeps its
correct cue. The fix didn't *tiptoe around* the thing that made the problem hard; it did that exact thing, and the
danger evaporated.

> **When you find yourself dropping data, degrading gracefully, or returning "unknown" to avoid being wrong, ask
> one question: is that a permanent verdict, or a fallback I'm accepting because the real computation looked
> expensive?** Graceful degradation is a floor to stand on, not a place to live. When you can afford the real
> computation, prefer it — and watch how often the "hard" computation is *also* the one that makes the whole class
> of hazards disappear.

---

## Part 6 — The playbook (portable checklist)

For your next non‑trivial, uncertain, or high‑blast‑radius endeavour:

1. **Scout inline first.** Read your own notes and the obvious code before spending a single subagent. Don't
   convene a task force to change a lightbulb.
2. **Distrust your memory; re‑derive from primary evidence** when a fresh report contradicts an "already handled"
   record. Read past *status* to *scope*.
3. **Choose the seams with care** — this is the one decision parallelism can't rescue. Partition along invariants
   and subsystems, not along files. Count the independent invariants; that's a floor on the number of splits.
4. **Fan out to search and to verify.** Give each context one invariant‑dense slice; return only distilled
   verdicts *that carry their own confidence and exceptions*.
5. **Assign a skeptic to every load‑bearing assumption** — rewarded for refuting, aimed at the source. Keep it
   honest with claims that should survive.
6. **Converge to one author to build** anything delicate; coherence can't be stapled together.
7. **Earn your green.** Oracle from a known‑good path → RED → GREEN → **sabotage** → one **outside** diff review.
8. **Prefer the real computation over dropping data** when you can afford it; degrade gracefully only as a floor.
9. **Know when to stop:** independent re‑derivations converge *and* an executable oracle fires.
10. **Remember the true checker is executable, or a different mind — never another copy of yourself.**

---

## The one thing to remember

More agents did not out‑think one agent. They out‑**structured** the problem — so that no single mind had to hold
the impossible, and every load‑bearing claim was attacked by a mind that hadn't birthed it, and the final proof was
a test that had been watched to fail. The intelligence was constant. What changed was the *epistemics*: belief,
holding, and audit were pulled apart and handed to different seats. Do that deliberately — and know when the task is
small enough that pulling them apart is just overhead — and you will find the bug the lone genius, reasoning
flawlessly from a stale premise, would have argued right past.
