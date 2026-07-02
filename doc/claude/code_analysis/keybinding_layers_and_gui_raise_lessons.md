# Four passes to bind one key: lessons on layered event dispatch, GUI raise, and testing the right seam

*A lessons-learned write-up from a deceptively small task — "bind Alt-F5 to raise the
CIW window." The final code is a handful of lines. It took four passes, each ending in
a confident "done" that the next real key-press disproved. This document is about **why**
each pass was wrong and the transferable patterns that would have collapsed four passes
into one. Running example touches `src/callback.c` (the C action registry),
`src/xschem.tcl` (Tk key delivery), `src/cadence_style_rc` (an opt-in rc), and
`src/ciw.tcl` (the CIW window). Every lesson transfers to any codebase with a GUI, a
plugin/binding layer, or more than one dispatch stage.*

Audience: an engineer who has added a keyboard shortcut, seen it "work" in a test, and
then watched a user report it doing nothing. You do not need to know XSCHEM (a schematic
editor in C + Tcl/Tk).

> **Thesis.** A feature that crosses N layers can fail at any of the N seams. A test that
> exercises seam k proves nothing about seams 1..k-1. "It ran" is not "it worked." When a
> sibling feature works and yours doesn't, **diff against the sibling** instead of
> theorizing. And when a debugging tool reports "no effect," first suspect the tool.

---

## The task and the four passes

**Goal:** press Alt-F5 → the CIW (command window) comes to the front.

- **Pass 1 — register + default-bind.** Added a `tools.raise_ciw` action to the C registry,
  a default `Alt-F5` row in `keybindings.csv`, metadata in `actions.csv`. Wrote a test that
  drove `xschem callback .drw 2 400 300 65474 0 0 8` and asserted the CIW state went to
  `normal`. **Green. Shipped.** → User: "Alt-F5 shows *Apply highlight…*."
- **Pass 2 — the cadence collision.** The user's `cadence_style_rc` binds plain F5 to a net
  highlight via `bind .drw <Key-F5> {…; break}`. Tk's `<Key-F5>` matches a *modified* F5
  too. Added a guard so the highlight only fires for non-Alt F5. **Reasoned correct.** →
  Still broken: the guard let Alt-F5 do *nothing*.
- **Pass 3 — same-bindtag pre-emption.** Probed the live widget tree and learned the generic
  key→dispatch binding lives on the **same bindtag** as cadence's `<Key-F5>`, so Tk never
  runs it for an F5 event — a guard can't "fall through." Changed the cadence bind to
  **forward** Alt-F5 into the dispatcher itself. → Now the action *fired* (a `ciw_create`
  line appeared in the log pane) **but the window still did not raise.**
- **Pass 4 — the platform no-op.** `ciw_create` re-showed the window with bare
  `wm deiconify; raise`, which is a **no-op under Weston/WSLg**. Swapped in the same
  `raise_activate_toplevel` helper the Library Manager already used. → Works.

Four passes, four different seams: C dispatch ✓ from the start, but the Tk **match** layer,
the Tk **bindtag** layer, and the **window-manager** layer each had their own bug.

---

## Lesson 1 — Test the seam where the bug can live, not a convenient proxy

Pass 1's test called `xschem callback …` directly. That is the C dispatch **contract**:
"given this event, the registry raises the CIW." It passed, and it was *right* — that seam
never had a bug. But the failure lived one layer up, in whether a real Alt-F5 key-press
*reaches* `xschem callback` at all. The test silently assumed the wiring it was supposed to
prove.

This is the green-but-hollow trap: a passing test that exercises B when the risk is in
A→B. The discipline is to **name the seam each test covers** and check the risky seam has
one. Here the risky seams were "does Tk deliver Alt-F5 to the dispatch" (match + bindtag)
and "does the raise actually raise" (WM) — none of which the callback-level test touched.

General rule: for a feature spanning `input → routing → action → effect`, a test at
`action` is necessary but not sufficient. Either add an end-to-end test at `input`, or —
when you can't (see Lesson 6) — *know and state* that the routing and effect seams are
unverified, and reason about them explicitly instead of letting a green proxy imply them.

## Lesson 2 — Learn your framework's dispatch-resolution rules before "fixing" a binding

Two Tk rules, each of which burned a pass:

- **Modifier-superset match:** a binding with *fewer* modifiers matches an event with
  *more*, when no more-specific binding exists. `<Key-F5>` catches Alt-F5. (Pass 2's bug.)
- **Per-bindtag single most-specific match + `break` semantics:** for one event Tk runs the
  single most-specific binding **on each bindtag**, in bindtag order. `break` stops
  progression to *other* bindtags — it does **not** let a less-specific binding on the
  *same* tag also run. So `<Key-F5>` and the generic `<Key>` on the same widget are
  mutually exclusive for an F5 event; "match `<Key-F5>`, do nothing, fall through to
  `<Key>`" is impossible. You must **forward explicitly**. (Pass 3's bug.)

Every event framework (Tk, the DOM, Qt, GTK, a game input map) has an analogous resolution
order and a "stop/consume" primitive with subtle scope. Read that spec first; a fix built
on a guessed model is a guess.

## Lesson 3 — In a layered dispatcher, an upper layer can silently veto the "authoritative" one

The design intent was: keys are remappable through the C action registry (the single source
of truth). But a real key-press only reaches the registry if the Tk layer forwards it, and a
more-specific Tk binding (cadence's F5) intercepts it first. The registry's authority is
real only for events that survive the layers above it.

General rule: when you own layer N and reason "layer N decides X," verify nothing in layers
1..N-1 can short-circuit the event before it arrives. Trace the **whole** path
top-to-bottom, not just your layer. An abstraction that is authoritative *in principle* is
not authoritative *for inputs a higher layer swallows.*

## Lesson 4 — "It executed" is a different question from "it worked"

Pass 3→4 turned on one precise user observation: *"a `ciw_create` line appears in the log
pane, but the window doesn't raise."* That single sentence split the problem cleanly — the
action **fired** (routing fixed) but its **effect** was null (WM raise failed). Without that
split we might have re-debugged the routing we'd just fixed.

Build this split into your instrumentation: make actions leave a trace *that they ran*
(here, the action log did it for free), separate from *what they achieved*. Then a bug
report localizes itself: trace present + effect absent ⇒ the effect layer; trace absent ⇒
the routing layer.

## Lesson 5 — When a sibling feature works and yours doesn't, diff against the sibling

Ctrl-Alt-S raised the Library Manager fine; Alt-F5 didn't raise the CIW. That contrast was
the whole answer to Pass 4: the working path called `raise_activate_toplevel` (a
withdraw→deiconify re-map plus `_NET_ACTIVE_WINDOW`, the only sequence that actually raises
under Weston/WSLg), and the broken path called bare `raise` (a documented no-op there).

Reinventing the raise from scratch would have rediscovered, painfully, what issue 0054 had
already learned. General rule: a working sibling is a **reference implementation**. Diff the
two code paths and copy the mechanism; don't theorize about the platform when a proven
answer is one `grep` away. (Bonus: reuse also inherits the sibling's hard-won edge-case
comments — here, "don't use `-topmost`/`iconify`, they drift/stick.")

## Lesson 6 — Probe the live system; don't trust a grep-built mental model

Static reading said the generic key→callback binding was on the toplevel (`bind $topwin
<KeyPress>`). A three-line runtime probe — `bindtags .drw`, `winfo toplevel .drw`,
`bind .drw` — showed it was actually on the **canvas** `.drw` (as `<Key>`), which is what
made it same-bindtag with cadence's F5. The grep-model was wrong about the one detail the
fix hinged on.

Introspect the running program: dump the real widget tree, the real binding table, the real
event target. Ten seconds of `puts [bind .drw]` beat an hour of re-reading source and
assuming.

## Lesson 7 — Suspect the test tool when it reports "nothing happened"

To verify real key delivery headlessly I reached for `event generate .drw
<Alt-KeyPress-F5>`. It reported no effect — for the fix I already *knew* was correct. The
tool was lying: synthetic compound-key events don't route reliably through this headless
WSLg stack. The tell was a **known-good** case also failing.

Two rules: (a) always include a positive control — if a case you're certain about also
fails, the harness is broken, not the code; (b) when a tool is unreliable, fall back to the
one the codebase already trusts. Here that was the project's own convention: key tests drive
`xschem callback …` directly (`proc key` in `test_action_log_dispatch.tcl`) precisely
*because* `event generate` is flaky — so the routing seam is asserted structurally
(inspect the installed binding string) plus at the dispatch contract, not via synthetic
events.

## Lesson 8 — Retract a wrong claim the moment evidence lands

Twice I wrote "no collision with cadence's plain-F5" — twice it was false. When Pass 2/3
disproved it, the fix commit said so in as many words. A confident-but-wrong statement left
standing becomes the next person's false premise. Correcting it in the commit/issue is
cheap; letting it rot is expensive.

---

## TL;DR checklist for a cross-layer feature

- List the seams: `input → match → route → action → effect`. Which does each test cover?
  Which risky seam has **none**?
- Before editing a binding, write down the framework's match order + consume semantics.
  Verify no upper-layer binding pre-empts you (same-bindtag pre-emption is the classic).
- Instrument "it ran" separately from "it worked," so a report self-localizes.
- Working sibling? Diff and copy its mechanism (esp. for platform/WM quirks).
- Probe the *live* system (widget tree, binding table); don't trust a grep model for the
  detail the fix hinges on.
- Keep a positive control in every ad-hoc test; when a known-good case fails, blame the
  harness first.
- Prefer the codebase's established test convention over a shinier tool that lies.
- When new evidence disproves an earlier claim, retract it in writing.
