# Leveraging a coding LLM (Opus 4.8) on a hairball codebase

The honest framing: a hairball's defining property — which we *measured* on
xschem, not guessed — is that **effects aren't local**. 14.6k `xctx->` refs, a
17-file mutual-recursion core, C/Tcl state mirrored by hand. That single fact
dictates the whole strategy: neither you *nor the model* can reliably reason
about what a change breaks just by reading. So the leverage isn't "the LLM
understands the codebase" — it's the moves below.

(Evidence for every point lives in `doc/claude/code_analysis/` and `tests/headless/`.)

## 1. Make the model build you a map — don't make it hold the map
The highest-leverage work is the model *writing tools that turn the hairball
into queryable data* (the call-graph extractor, the menu-inventory parser, the
coupling tables) — not reading code. A 64k-line tangle no human or context
window can hold becomes a CSV you can sort. On a hairball, the model's job is
**cartography first, surgery second**. Prefer "write a script that inventories X
across all files" over "read these files and tell me."

## 2. Buy a fast empirical loop before writing any feature
Because ripples are invisible to reasoning, replace reasoning with *observation*.
The headless harness is worth more than the model staring at `netlist.c`: cheap,
deterministic verify -> every iteration checked in seconds -> value compounds
instead of accumulating unverified risk. **Trust the diff, not the model's (or
your) mental model of global effects.**

## 3. Drive work to the seams; treat the core as hostile
We mapped clean seams (netlist backends, renderers, new `xschem` commands, the
Tcl menu layer) vs. the high-blast-radius core (`token.c`, `xctx` semantics, the
`actions<->draw<->save<->select` cycle). The model is excellent at additive work
behind a clean interface and dangerous at deep mutable-state surgery. Point it at
seams confidently; for core changes switch modes — small steps, heavy
verification, explicit skepticism.

## 4. Locate -> slice, never dump
The 1M window is a *trap* here: stuffing 64k lines degrades reasoning versus
surgical retrieval. Ask the model to find anchors (`file:line`), then read
targeted slices. Precision beats volume. Use the big context for many small
relevant excerpts plus tool outputs, not whole files.

## 5. Verify the model's own analysis — confident drafts, not truth
Our call-graph tool silently missed 76 of `save.c`'s 78 functions until a sanity
check caught it, and still under-counts function-pointer dispatch
(`xctx->push_undo()`). LLM-generated analysis is a **draft to validate against
ground truth**, never gospel. Build the spot-check in ("does this number match a
`grep`?") — a plausible-but-wrong map is worse than no map.

## 6. Persist the tribal knowledge so every session starts warm
Hairballs encode conventions implicitly: `MIRRORED IN TCL`, the `_ALLOC_ID_`
placeholder, the dispatcher's sorted-`strcmp` ordering, the generated parsers you
must not hand-edit. Capture them in `CLAUDE.md` / `WORKLOG.md` so the model walks
in knowing the landmines instead of rediscovering them.

## 7. Refactor *toward* what the model is good at — a virtuous cycle
Declarative data is what an LLM manipulates best — far more safely than
control-flow-embedded logic (a 700-line `build_widgets`, a C `if/else` keysym
chain). Every cleanup that turns buried logic into a table makes the *next* model
task cheaper and safer. Bias refactors toward "make it data."

## Where the human stays in the loop
Keep yourself on **intent, risk judgment, and the irreversible/outward-facing
calls** — the exact spots where we hit friction this session: the email/reauthor
decision, public-vs-private, full-copy scope, the push. The model multiplies
*execution and analysis*; it should not decide what's safe to publish or what
"done" means.

---

Net: on a clean codebase you delegate *understanding*; on a hairball you delegate
*tooling and verified iteration*, and you keep judgment. A map and a feedback
loop — `doc/claude/code_analysis/` and `tests/headless/` — are that strategy made concrete.
