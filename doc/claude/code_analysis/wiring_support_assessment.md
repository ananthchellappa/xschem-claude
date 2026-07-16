# How well does the codebase support wiring work? — assessment, retrospective, forecast

Date: 2026-07-10, branch `fluid-editing`, HEAD `f1692607`. Method: 16-agent deep analysis
(five code readers over move.c/select.c/check.c/store.c/netlist.c, spec and test readers,
two issue digesters over 0079–0111, two architecture assessors, a retrospective analyst,
three adversarial failure predictors, and a prediction critic). The machine-readable
companion is `doc/claude/WIRING.md` — that file is the working reference; this one is the
narrative for a human reader.

---

## Part 1 — The code, assessed as a platform for wiring features

### The one-paragraph verdict

XSCHEM's wire model is a **capture and display model, not a routing model**, and the
connected-drag work of the last weeks has been building a router on top of it anyway. The
result is genuinely impressive in one specific way — the "never worse" discipline
(tentatively apply, verify the electrical partition, revert exactly on failure) has let
roughly thirty fixes land in days without shipping a single new permanent short — but the
architecture is now **safe-but-brittle**: nine ordered healer passes with comment-only
contracts, four overlapping permission vocabularies, two-and-a-half verification
semantics, and a pair of passes three thousand lines apart that are explicitly co-designed
around each other. The marginal cost of each new wiring feature is rising, and the last
several issues (0110, 0111) were caused by the pipeline's own passes interacting, not by
new geometry. The platform is workable but is at the point where structural investment
pays back faster than the next feature.

### What the data model gives you, and what it doesn't

A wire is four doubles and a property string in a flat array. Connectivity does not exist
as data anywhere: wire A is connected to wire B if and only if an endpoint of one
coincides (in exact double arithmetic) with a point on the other. Net names are produced
by a full-sheet flood fill (`prepare_netlist_structs`) that frees and rebuilds every name
string each time it runs, and the auto-generated `#netN` numbers depend on traversal
order, so they can't even be compared across two runs.

Everything a router wants is therefore missing and gets re-derived, per gesture, with
bespoke code:

- **"Are these two things on the same net?"** — either run the full flood and compare
  strings, or run an O(W²) all-pairs geometric union-find. A single drag gesture triggers
  the full flood roughly 25–30 times.
- **"How many wires meet at this point?"** — the stored per-endpoint counters are lazy,
  viewport-scoped display data; real degree is a full array scan per query.
- **"Was this wire created by this drag?"** — reconstructed by diffing normalized
  geometry spans against a snapshot taken at move start, even though every wire carries a
  session-stable id that could answer the question directly.
- **"What's in the way of this candidate leg?"** — six different hand-written scan
  predicates; the spatial hash exists but is index-based and mutation-hostile, so the
  code that mutates the most is exactly the code that can't use it.

None of this is fatal — the workarounds exist and work — but each one is a standing tax,
and together they put a hard ceiling on the "reroute continuously while dragging" ambition
on large sheets.

### Safety by healing, not by checking

The specs define a clean contract: P1 connectivity and P2 no-short are hard invariants,
then escape-perpendicular, no-body-cross, Manhattan, stability, minimal bends, in a fixed
priority order. What the code actually has is:

- A **real enforcement point only on some paths**: the attempt ladder (try orthogonal,
  try single-pass, fall back to a rigid diagonal relay, restore the least-bad) verifies
  the pin partition — but only when its safety-net snapshot was armed, and the arming
  conditions were discovered one bug at a time (issues 0085, 0093, 0102, 0109 are all
  "this path never armed the net").
- A **general invariant checker that only logs**. `fluid_check_move_invariants` computed
  and printed the very violations that shipped in 0094/0098/0099 while they shipped.
- **Everything else is procedural**: no dead copper, minimal bends, Manhattan-ness, and
  pin escape are produced by nine ordered cleanup passes, each one born from one escaped
  artifact class, each with its own eligibility grammar and revert mechanism. Nothing
  ever checks the final result against those properties.

The cost is structural: the pass count grows linearly with discovered artifact shapes,
the pass *interactions* grow faster, and ordering is encoded as block comments. The
clearest symptom is issue 0111: the straightener and the exit-stub pass form an
accidental normalizer loop, the committed test goldens had silently baked that loop's
output in as a contract, and the fix required teaching one pass about the other's future
behavior. That is the canonical smell of an architecture at its complexity limit.

### What's genuinely good

Worth saying plainly, because it's the reason the branch works at all:

- **The never-worse envelope.** Tentative-apply → partition-verify → exact revert is
  applied consistently across the healers, and it is why 24+ fixes landed in four days
  with zero new hard shorts shipped in fixed areas.
- **The determinism discipline.** Restore-and-recommit from a pristine snapshot each
  rubber step, with id counters re-stamped, makes release identical to stepwise dragging
  by construction — a property most CAD tools get wrong.
- **Session-stable object ids** exist, are correctly threaded through undo, and are
  already the backbone of user-wire protection.
- **FLTRACE** plus the user's before/after capture workflow is a genuinely effective
  field-diagnostic loop; issues 0105–0111 were all diagnosed from user traces.
- **The spec corpus.** P1–P8 and the incremental-reroute pivot are well-thought-out and
  ahead of the implementation — the problem has been enforcement, not vision.

### The structural work that would pay for itself

In order of leverage (details and effort estimates in WIRING.md §12):

1. **Wire the existing tests into CI and commit the untracked repro corpus.** Today a
   fluid regression cannot fail CI: the one fluid test CI runs self-skips headless and
   counts as a pass, the 52-test wireedit suite isn't invoked, and most of the
   before/after evidence files for issues 0090–0111 exist only in the working tree.
   Half a day, highest return available.
2. **Promote the invariant checker from log-only to enforce** (rollback or refuse) on
   every commit path. The snapshot, the checker, and the rollback machinery all already
   exist; only universal arming is missing. This single change would have made about a
   third of the historical issues impossible to ship.
3. **Reify the gesture context** — a struct replacing the file-scope statics — then a
   pass table with declared gates, verify direction, and ordering edges. This turns the
   comment-graph into checked structure and makes single passes testable in isolation.
4. **Unify the geometry predicates.** There are four dangling-tail candidacy variants,
   three novelty definitions, three foreign-copper guards, two pin-hit tolerances, and a
   degree function that lacks the degenerate-wire guard its siblings have. Several past
   bugs were exactly "one copy of a predicate missing one clause."
5. **An incremental connectivity oracle** (id-keyed union-find maintained through the
   three-function wire birth/death funnel). This is the only item that changes the
   asymptotics — it removes the ~30 full-sheet floods per gesture and is the
   prerequisite for true per-step incremental routing on big schematics.
6. **Do not build the spec's A*/Lee solver yet.** Dropped into the current pass soup it
   would just be pass #10 with N more pairwise interactions. It becomes attractive after
   items 3–5.

---

## Part 2 — Retrospective: 33 issues of connected drag (0079–0111)

### Where the bugs actually were

Half the bug mass (16 of 33) was not in routing at all but in the **cleanup that runs
after routing** — reconciling incrementally-committed geometry with the final picture:
prune passes, straighteners, de-shorters, the relay Manhattanizer. The router proper
(elbow placement, slides) accounts for six. The rest: follow-set/selection lifecycle
(four), safety-net orchestration (three), rotation pivots (two), rendering and
persistence one-offs (four).

Fix shapes: eight issues were fixed by adding a whole new END pass, nine by point patches
inside an existing pass, six by widening a scope gate, and the rest by data-model tweaks,
reorders, and rewrites. Three remain open (0079 follow-set rendering, 0084 replay-test
grep, 0101 rotatelocal tears). At least twelve fixes carried additional review-driven
hardening, and adversarial review caught roughly six would-be shorts/memory bugs before
they shipped — the single most effective practice in actual use.

### The nine root-cause families

1. **Unverified commit paths** — the P2 safety net was built for one code path
   (the diagonal decomposition) and every other path had to be individually discovered to
   be blind (0085, 0093, 0102, 0109). Four user-visible electrical escapes from one
   arming condition.
2. **Trigger-bound detection** — safety detectors keyed to one geometric signature; the
   full contact matrix (endpoint-on-pin / pin-on-span / T / collinear × own/foreign ×
   moving/stationary × parallel/perpendicular) was never enumerated, so each cell was
   discovered by a user gesture (0083, 0085, 0094, 0098, 0105, 0106, 0109).
3. **Stale anchors** — follow wires re-route from the pin to the *pre-move* coordinate of
   their far end by design; under rotation that coordinate's purpose can evaporate,
   leaving dead tails, shorts through the vacated point, and relay routes to the pin's
   own old foot (0103, 0104, 0108, part of 0111).
4. **Decline residue** — every safety decline leaves dead copper, and cleanup was grown
   one residue shape at a time: loop, U-turn, staircase, overshoot, tail, stale feed
   (0088–0092, 0096, 0111). This family is a *theorem* of decline-based safety, not a
   series of accidents.
5. **Transform blindness** — the pipeline was written for translation with `+delta`
   arithmetic scattered everywhere; there is no single "final position of X" authority,
   so enabling rotation meant auditing every coordinate expression, and each missed one
   was an issue (0099, 0100, 0101, 0102).
6. **Selection/ownership debt** — the spec said the follow set should be tool-private;
   it was instead implemented in `wire.sel`, so tool artifacts leaked into user-visible
   selection semantics (0079, 0091, 0093, 0095, 0097).
7. **Decomposition future-blindness** — per-leg greedy decisions against intermediate
   geometry are implicit predictions about the next leg (0081, 0086, 0087).
8. **Blanket gates and accidental ordering** — passes switched off wholesale under
   rotation out of caution rather than semantics, and pass order was discovered by bug
   (0091, 0098-B, 0110).
9. **One-offs** — GC aliasing, double-delta redraw, test-grep drift (0080, 0082, 0084).

### Could these have been anticipated? Mostly yes — and that's the real finding

By the issues' own honest post-mortems, **about 26 of 33 were anticipatable**: they were
the negation of a just-written gate condition, the documented "deferred" item of the
previous fix, the explicit skip (`sa != sb`) of a sibling pass, or a known-unarmed commit
path someone had already noted in passing. The chains are explicit — 0099→0100→0101→0102
→0103→0104→0110 (rotation), 0094→0098→0105→0106→0109 (pin-on-foreign-copper),
0088→0089→0090→0096→0111 (residue). Only about three issues were genuinely novel (the GC
aliasing bug, the straighten/exit-stub fixed point, the replay-grep drift).

**The project's foresight consistently outran its enforcement.** The knowledge existed —
in deferred lists, code comments, and trace observations — but lived as prose with no
mechanism forcing it back into the work queue before a user gesture found it. The one
place a deferred item was turned into an executable xfail tripwire (0104's), it worked
exactly as intended, firing the moment a later fix changed the tolerated behavior.

### Why this problem is intrinsically hard

Essential difficulty, present in any implementation:

- **Connectivity is implicit in geometry.** With no net objects, every coordinate
  coincidence is an electrical event; a route that merely passes through a point where
  something else ends changes the netlist. The hazard set of any move is global.
- **Safety and beauty are adversarially coupled.** Aesthetic moves can short; safe
  declines create ugliness; the last-resort safety mechanism (rigid relay) violates
  Manhattan by construction. Every quality pass needs the full safety verify and every
  safety decline needs a quality cleanup.
- **Incrementality destroys information.** Per-step commits, multi-gesture sequences and
  the X-then-Y decomposition mean decisions are taken against intermediate geometry;
  gesture N+1's "pristine" is gesture N's output.
- **Rotation changes the problem class.** rot180 permutes pins across the pivot so the
  follow routes *must* cross — the two-orientation elbow vocabulary is structurally too
  weak, forcing the relay escalation and its Manhattanization debt.
- **The objective is global, the edits are local.** Whether a one-grid slide is safe can
  depend on a sibling pin's not-yet-laid route, and the killer repros are one-grid
  sensitive.

Accidental difficulty, self-inflicted and fixable: no incremental net model, follow set
in `wire.sel`, safety as detector accretion instead of one checker, verification bound to
code paths instead of to commits, translation-era arithmetic, goldens silently promoted
to contracts. Rough split across the 33 issues: ~7 essential, ~22 accidental, ~4 one-off.

### Process lessons, ranked by prevented-issues-per-effort

1. Make the END invariant check **enforcing**, not logging (≈11 issues).
2. **Delta-sweep fuzzer** on the standard fixtures (drags over a grid of deltas ×
   {plain, stretch, ALT-R, ALT-R², split gesture}, asserting partition-clean, Manhattan,
   no novel dangling ends, no body crossings, bounded copper length) — would have found
   ~11 issues before any user (all predicates already exist in C; only the driver is
   missing).
3. **Every deferral ships as an xfail test**, not prose (~8 issues were pre-written).
4. **Gate-boundary enumeration** as part of writing any gated fix (0101's lesson).
5. **Repro with the user's exact gesture** — real keysyms, real callback path (0100's
   green-but-hollow lesson).
6. **Post-fix interaction sweep**: what does the new guard over-protect, what residue
   does the new decline leave, what consumes the new output (three issues were direct
   children of the immediately preceding fix).
7. **Premise-expiry audits**: record *why* a compromise exists so the premise's removal
   flags it (0095 outlived its justification by months).

---

## Part 3 — Forecast: where manual testing will break it next

The user's operations are only translate / flip / rotate of a selection, with each
follow wire's far end fixed. What makes even that small vocabulary hard: rotation
invalidates the stale-anchor model; flips got systematically less testing than rotations;
mixed selections disable the safety net; and everything to date was tested on unlabeled
two-pin fixtures. Three adversarial predictors generated ~30 candidate failures; a critic
deduplicated, killed the already-covered ones, and verified the mechanism of the top
twelve against source. The full ranked list with repro recipes and suggested fixes lives
in **WIRING.md §11**. The headlines:

1. **Named nets are a repair blackout.** Every de-shorter hard-declines copper carrying a
   real label (`VDD`, `GND`, any bus) — the entire short-repair family built in
   0094–0106 is inert on realistically-labeled schematics. Every historical fixture used
   auto-numbered nets. This is the single most likely "how was this never seen" report.
2. **Selections containing a wire commit unverified.** Both non-rotated safety-net arms
   require a pure instance selection; box-select an instance plus one wire and the fixed
   0105/0109 shorts come back, saved silently (documented open gap 0093-D2).
3. **Transistors break the de-shorter.** The pin-pair axis derivation skips any
   non-axis-aligned merged pair (gate vs drain), and the entire test suite is
   transistor-free.
4. **The open 0101 family** (rotate-local tears for instance-to-instance straps,
   wire-grab followers, off-grid grabs) — documented open, and documented-open holes have
   historically been the highest-likelihood user reports.
5. **Net labels as first-class movers.** One-pin label instances can never present the
   pin *pair* the merge detector needs; dragging a label onto foreign copper, or routing
   across a stationary label pin, has no owning repair pass — and the wire-stub+netlabel
   feature mass-produces exactly these topologies.
6. **In-place rotate during a fluid hold is silently discarded** (the zero-delta early-out
   tests only deltas), and return-to-origin drags leak kiss stubs and an undo slot.
7. **Rotated drops lack the obstacle-detour and exit-stub machinery** that translation
   has (still gated `rot==0`), so a rotated drop near a straddled device saves diagonals
   or a short where the identical translated drop routes cleanly.

What to do proactively, in order: wire the suites into CI and commit the repro corpus
(nothing else is trustworthy until then); arm the safety net on every commit path and
make the invariant checker enforce; then burn down the §11 list top-to-bottom by writing
each as an xfail gesture test *before* attempting fixes — the same discipline that
retired 0104. Add labeled-rail, transistor, and net-label variants of the standard
fixtures; every current fixture equivalence class (unlabeled, two-pin, axis-aligned) has
now been mined dry by the issues it produced.
