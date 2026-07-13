# Plan: a Notifications / "efficiency coach" that teaches cheaper ways to do things

*Status: design proposal. Plain-English plan for discussion, not yet scheduled.*

## 1. The one-line idea

Watch what the user actually does, recognise when they reached a result the long way round,
and quietly queue a note that says "next time you can do this in fewer steps — press X."
Surface those notes through a **Notifications bell on the toolbar** that lights up when there
is something worth telling them. The more often a particular inefficiency recurs, the higher it
rises in the queue.

## 2. Why this is the same problem as the wire-routing work

The routing work (fluid editing, issues 0081–0090) is about one thing: **a path from A to B has a
cost, several paths reach the same endpoints, and we want to detect a wasteful path and offer the
cheap one.** A staircase and a clean "L" connect the same two pins; one just costs more bends.

This feature is that exact idea moved from *geometry* to *interaction*:

| Wire routing | Efficiency coach |
|---|---|
| Endpoints (the two pins) | The **outcome** (what the user accomplished) |
| A wire path between them | The **action path** the user took to get there |
| Path cost = bends + length | Path cost = clicks + keystrokes + dialogs opened |
| The minimal L | The cheapest way to reach the same outcome (usually a single shortcut) |
| "Collapse the staircase to the L" | "You took the long path; here is the short one" |

So the mental model is identical: **observe a path, compare its cost to the cheapest path that
reaches the same end-state, and if the taken path is dominated, report it.** The only genuinely new
piece is that the "cheapest path" is not computed geometrically — it is *looked up*, because XSCHEM
already records, per action, what its canonical shortcut is (the action registry).

## 3. What class of problem is this?

It sits at the intersection of three well-studied areas:

- **Plan / intent recognition.** Infer the user's *goal* from a stream of observed low-level
  actions. Classic AI problem; here it is deliberately kept shallow (we recognise a small set of
  known goals, not arbitrary ones).
- **Idiom / anti-pattern detection over an event stream.** Match a temporal pattern ("draw wire to a
  pin, then create a label with the pin's name") against a sliding window of recent events. This is
  the same shape as *complex event processing* and linters' anti-pattern rules.
- **Workflow / feature coaching.** Turn a recognised inefficiency into a teachable hint. There is
  strong prior art here worth studying rather than reinventing:
  - **JetBrains "Feature Suggester" / Productivity Guide** — IntelliJ literally watches you do
    something the manual way (e.g. delete a line char-by-char) and pops "you can press Ctrl+Y." This
    is the closest existing analogue to what is being asked for.
  - IDE/editor "did you know" hint systems, VS Code keybinding hints, GNOME/Office tip-of-the-day.
  - The cautionary tale is **Clippy**: the failure mode is *interruption and low precision*. The
    design below is built to avoid both (passive queue, high-precision rules, frequency-gated).

A useful internal name for it: an **"efficiency coach"** or **"power-user advisor."**

## 4. Why XSCHEM is unusually well-positioned to do this

The hard 80% of this problem is normally *getting a clean, de-noised, outcome-level event stream*.
XSCHEM has already built exactly that, for the replay/logging feature:

- **The action log is already outcome-level.** `xschem log_action` (the C sink, mirrored in
  `ciw.tcl` and `action_registry.tcl`) records *what happened*, not raw mouse motion. Gestures are
  already filtered out.
- **Gestures are already collapsed into significant steps.** The "descend absorb" work
  (`select_at` + `descend` recorded as one stable `xschem descend -inst NAME`, commit `8f7e621b`)
  is precisely the "a click-drag-key sequence is one meaningful step, not three gestures"
  abstraction the request calls for. There is already a **holding-area buffer** that stages recent
  raw events and emits one coalesced outcome — the natural tap point for the coach.
- **The canonical "cheap path" is already known.** The **action registry** (`action_registry.tcl`)
  maps every registered action to the user's *current* key/mouse binding, and can render it as a
  human label (`keybinding_chord_label`, `generate_keybindings_text`). So a suggestion can say the
  user's *actual* chord ("press Ctrl+X") and automatically respect remaps, instead of hard-coding a
  key that may not be bound.
- **Invocation provenance is visible.** Menu clicks flow through `menu_action_logged`, key/mouse
  actions through the registry dispatch, dialog OKs through the `property_form.tcl` log bridge.
  Each path *knows how it was invoked*, which is what lets us tell "reached via the descend dialog"
  apart from "reached via the Ctrl+X chord."

That last point is the subtle one and it shapes the whole design (next section).

## 5. The key insight: we must observe the *path*, not just the *outcome*

A naive version watches only outcomes ("user descended into X"). But the descend-absorb log records
the *same* line — `xschem descend -inst X` — whether the user pressed Ctrl+X or crawled through the
E-dialog. **The outcome alone cannot tell an efficient run from an inefficient one.**

So the coach's event record for each significant action must carry three things:

1. **Outcome** — what changed (the logged command / effect).
2. **Invocation provenance + cost** — *how* the user produced it: which menu items, dialogs, and
   keystrokes, and a simple cost (number of discrete UI interactions: clicks, key chords, dialog
   round-trips).
3. **Registered-action identity** (when known) — the action-registry id this outcome corresponds to,
   which yields the cheapest available binding for the same outcome.

Then the core rule is almost trivial:

> If `cost(path the user took)` is meaningfully larger than `cost(cheapest known path to the same
> outcome)`, queue a suggestion naming the cheap path.

This gives us two detection strategies that share the same plumbing.

## 6. Two detection strategies

### Type A — automatic "you used a costly route to a one-shortcut action"

For any outcome that corresponds to a **single registered action with a binding**, compare the taken
path's cost to that binding's cost (normally 1 chord). If the user went through a menu + dialog +
Enter to reach an action that has a direct chord, that is an inefficiency *detected with no
hand-written rule* — it falls straight out of tagging each logged action with (provenance-cost,
registered-action-id). The **descend** example is Type A.

This is the high-leverage part: once the tagging exists, *every* dialog/menu path to a chorded action
becomes coachable for free.

### Type B — hand-authored "manual composite that one feature replaces"

Some inefficiencies are not one action done expensively; they are a **small sequence the user
assembled by hand that a single feature would have produced.** These need a short, explicit rule per
idiom: a matcher over the recent-action window plus the suggestion payload. The **stub-label** and
**bus-rename** examples are Type B (there is no single "make bus label" action the user invoked; they
built the end-state out of primitives).

A rule is just: *a predicate over the last N events → (suggestion id, title, the registered action to
recommend)*. The binding text is filled in live from the registry.

Start with a **small, high-precision catalog** (the three requested examples). Grow it over time.
Precision beats coverage: one wrong suggestion costs more trust than ten missed ones.

## 7. Architecture

```
                 raw events (clicks, keys, dialog OKs)
                              │
      ┌───────────────────────┴───────────────────────┐
      │  existing action-log funnel + descend-absorb   │   ← already exists
      │  holding-area (coalesces gestures → outcomes)  │
      └───────────────────────┬───────────────────────┘
                              │  significant action + provenance + cost + action-id
                              ▼
                   ┌─────────────────────┐
                   │   Coach event tap    │   (in-process hook, NOT file tail)
                   │   ring buffer of last│
                   │   N significant acts │
                   └──────────┬──────────┘
                              ▼
        ┌──────────────────────────────────────────┐
        │  Rule engine                               │
        │   • Type A: cost(taken) > cost(registry)?  │
        │   • Type B: catalog of idiom matchers      │
        └──────────────────┬────────────────────────┘
                           ▼  suggestion {id, title, detail, recommend-action}
        ┌──────────────────────────────────────────┐
        │  Suggestion queue (persistent)             │
        │   id → {title, detail, count, last_seen,   │
        │         dismissed, snoozed}                │
        │   rank = f(count, recency)                 │
        └──────────────────┬────────────────────────┘
                           ▼
        ┌──────────────────────────────────────────┐
        │  Toolbar Notifications bell               │
        │   • lights up / badges new count          │
        │   • click → panel: ranked list, each with │
        │     "show me", "got it", "don't show again"│
        └──────────────────────────────────────────┘
```

Component notes:

- **Event tap.** Hook the existing outcome-emit point (the descend-absorb holding-area flush), not a
  file tail. In-process is lower-latency, has the provenance in hand, and avoids parsing a log format.
  Watching the log *file* is a valid fallback for a quick prototype, but it loses provenance and is
  racy — prefer the in-process hook.
- **Event record.** `{outcome_cmd, action_id (or {}), invocation ("chord"|"menu"|"dialog"|...),
  cost_int, context (selected object type, etc.), timestamp}`.
- **Ring buffer.** Last N (say 8–16) significant actions; Type-B rules scan it, Type-A looks at the
  latest.
- **Rule interface (Tcl).** `proc coach_rule_<name> {events} { ... return {} or {suggestion dict} }`.
  Register rules in a list so the catalog is data, like the action/menu registries already are.
- **Queue + persistence.** A dict keyed by suggestion id; counts and dismissals persisted under the
  user config dir (e.g. `~/.xschem/coach_state`) so "seen it 12 times → near the top" survives
  restarts, and "don't show again" is permanent.
- **Ranking.** `rank = count` with a mild recency boost; ties broken by last-seen. Simple and matches
  the request ("more times seen → higher up").
- **UI.** A bell icon in the existing toolbar; badge = number of un-acknowledged suggestions; a subtle
  light/colour change on a new one (never a modal, never steals focus — this is the anti-Clippy rule).
  Clicking opens a small panel listing suggestions newest/highest-count first; each row has the title,
  the one-line "cheaper way," the live keybinding, and per-item **Got it** / **Don't show again**.

## 8. The three requested examples, worked through

| # | What the user did (the costly path) | Cheaper way | Type | Difficulty |
|---|---|---|---|---|
| 1 | Select instance → **E** → descend dialog → **Enter** (descend same-window). Or right-click → "descend into schematic." | The user's Ctrl+X (descend) chord | **A** | Easy — both already log `descend`; only need to tag the invocation (dialog/menu vs chord) and compare cost. This example also establishes the provenance-tagging that Type A needs. |
| 2 | Select a pin → open properties form → edit `name=FOO` to `name=FOO[2:0]` → OK | Alt+ScrollWheel-Up (bus-width increase / bus transpose) | **B** | Medium — detect a properties-form edit whose only change is `name=X` → `name=X[a:b]` (a semantic before/after diff of the prop edit; the editprop funnel has both). |
| 3 | Draw a wire to a pin → create a net-label → type the pin's net name → attach | Select the pin → **Space** (auto `lab_pin` stub) | **B** | Medium-hard — a two-event correlation: a wire drawn incident to a pin, then a label created whose name equals that pin's net. Needs a small geometric + name join across two events. |

Recommended first target: **#1 (descend)**. It is Type A, it is the simplest end-to-end, and building
it forces the provenance-tagging + registry-lookup + queue + bell — i.e. the whole spine — for the
smallest possible rule. #2 and #3 then become "add a rule," not "add a system."

## 9. Risks and how the design handles them

- **The Clippy problem (interruption / annoyance).** Mitigations are structural: the coach *never*
  interrupts — it only lights a bell the user pulls when curious; a suggestion must recur ≥K times
  before it is surfaced prominently (frequency gate, which the request already wants); every item has
  "don't show again"; nothing fires mid-gesture.
- **False positives erode trust fast.** Ship only high-precision rules. A rule must key on the
  *outcome effect*, not just keystrokes, so it does not misfire when the user genuinely needed the
  long path (e.g. they opened the properties form to change *several* fields, not only the name — then
  it is not a bus-rename shortcut miss). Prefer "miss a real one" over "flag a false one."
- **Respecting the user's own bindings.** Always render the *current* binding from the registry; if
  the recommended action is unbound, either suggest binding it or stay silent — never tell the user to
  press a key that does nothing for them.
- **Privacy / trust.** All observation is local; state lives in the user's config dir; nothing leaves
  the machine. Worth stating explicitly, and offering a global off switch.
- **Noise from scripts/replay.** Suppress the coach during action-log *replay* and headless runs (it
  should learn from humans, not from its own replays).

## 10. Phased implementation plan

**Phase 0 — spike / feasibility (small).**
Confirm the descend-absorb holding-area flush is the right in-process tap and that at that point we
can see both the outcome (`descend -inst X`) and the invocation (dialog vs chord). Prove we can read
the current binding for an action from the registry. Output: a one-paragraph go/no-go note and the
chosen hook function name.

**Phase 1 — thin vertical slice (the whole spine, one rule).**
Event tap → ring buffer → **one Type-A rule (descend)** → suggestion queue (in-memory) → a bell icon
that lights up → a minimal panel that lists the suggestion with its live keybinding and a "got it."
No persistence yet, no ranking yet. Acceptance: do the descend the long way, the bell lights, the
panel says "press <your Ctrl+X>." Do it via the chord, nothing happens.

**Phase 2 — queue semantics.**
Add counts, dedup by id, frequency+recency ranking, persistence under the config dir, "don't show
again," and the frequency gate (only surface after K occurrences). Acceptance: repeat the same
inefficiency; it climbs; dismiss it; it stays gone.

**Phase 3 — grow the catalog.**
Add the bus-rename (#2) and stub-label (#3) Type-B rules. Each is one `coach_rule_*` proc + a catalog
entry + a regression test that replays the costly path and asserts the suggestion appears (and that
the *cheap* path produces none). This is where the routing project's "RED-first + sabotage-verify"
discipline pays off: every rule ships with a test that fails if the rule is neutered.

**Phase 4 — polish.**
Bell animation/colour, panel niceties ("show me" that highlights the relevant menu/toolbar target),
a global preferences toggle, and a short docs page.

## 11. How hard is it, really?

**Medium — and front-loaded onto plumbing we already have.** The genuinely hard part (a clean,
de-noised, provenance-carrying, outcome-level event stream) is *already built* for the logging/replay
feature; this feature is largely a *consumer* of it plus a registry lookup and a small UI. The rule
engine, queue, and bell are each modest. The real ongoing cost is **authoring and tuning rules for
precision**, not the framework. A Phase-1 slice (bell + one descend rule) is genuinely small; each
later rule is incremental.

The one architectural decision that matters most is **where to tap and what provenance to record**
(Section 5) — get that right and both rule types and every future rule are cheap; get it wrong (e.g.
tap only outcomes) and the whole thing cannot tell fast from slow.

## 12. Open questions for the requester

1. **Cost metric.** Is "count of discrete UI interactions (clicks + key chords + dialog round-trips)"
   the right notion of "costs less," or do you want something weighted (dialogs cost more than keys)?
2. **Surfacing threshold K.** After how many repeats should a suggestion light the bell — first time,
   or only after it recurs (say 3×)? The request implies frequency-ranked but does not fix the first
   trigger.
3. **Scope of the seed catalog.** Just the three examples for v1, or should Phase 0 also enumerate a
   longer wish-list of idioms so the rule interface is designed against more than three?
4. **Discoverability vs teaching.** Should the panel also offer "bind a key for this" when the
   recommended action is currently unbound, turning the coach into a binding-setup helper too?
5. **Global model later.** Out of scope for v1, but worth noting: Type-B rules are hand-authored; a
   future version could *mine* frequent costly subsequences automatically (sequential-pattern mining)
   and propose new rules. Flag now, build later.
