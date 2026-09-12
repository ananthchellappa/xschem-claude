# 1423 — preconditions become filters, not error messages

**Status:** fixed
**Branch:** fluid-editing
**Stage:** commit **C3** of Stage 4 of `doc/claude/ase_analyses_batch/`.

## What ships

`ase::analysis_needs {sim row facts {opts {}}}` — evaluates a registry type's declared `needs` ids
against `ase::netlist_facts`, returning `{<id> <verdict> <sentence> <fix>}` with `verdict` one of
`caution` / `blocked` / `fatal`. `ase::needs_eval` is the per-predicate body;
`ase::analysis_precheck {sim state facts}` is every **enabled** analysis's verdicts by type; and
`ase::precheck_worst` is the ordering, written once.

Three predicates, chosen because they are the three reachable today — `noise`, `disto` and `sp`
stay probe-only until Stage 6, so a `needs` entry on them would be unreachable code with an
unreachable test:

| id | on | verdict |
|---|---|---|
| `ac_source` | `ac` | blocked (demoted, see below) |
| `sweep_target` | `dc` | blocked (demoted) |
| `cider_klu` | `ac`, `dc`, `tran` | **fatal**, never demoted |

## The governing rule: a false refusal is worse than a missed one

`ase::netlist_facts` answers `exact 0`. It cannot see inside an `.include`, so *"this deck has no AC
source"* from a deck that includes a stimulus file is a **guess**. A refusal built on a guess stops
work that would have succeeded and gives the user no way to tell the tool it is wrong.

So **every `blocked` verdict on a static pass is demoted to `caution`**, and the sentence gains
*"(read from the netlist text, which cannot see inside an .include)"*. ⚠ **The demotion lives in one
place** — in `analysis_needs`, not in each predicate — so that a predicate author writes the honest
verdict and the evaluator lowers it, rather than thirteen authors each remembering the same caveat.

`fatal` is **not** demoted, and the difference is measured: ngspice `exit(1)`s on a CIDER device
under KLU. Not an error return — an **exit** — so the rest of `.control` never runs and nothing
after that analysis happens either. A caution would let the user start a run that cannot produce
anything and cannot say why.

## Three shapes that would each have been a false refusal

⚠ **The CIDER/KLU pair needs BOTH halves.** The first draft fired on the device alone. A CIDER
device is perfectly fine under the default solver, and CIDER decks are the only reason anyone builds
ngspice with it — a predicate firing on the device alone would refuse **every deck the feature
exists for**. The solver comes from the bench's own options, which is why the evaluator takes them.

⚠ **`temp` is a legal sweep target and names no instance.** A `sweep_target` predicate that required
the target to be in the deck would refuse `dc v1 0 1 0.5 temp -40 60 50` — the cheapest genuine
ADE-beater in this whole design.

⚠ **An unimplemented precondition id is *satisfied*.** A registry naming a precondition nobody has
written yet must not block a run. An unimplemented id is a fact about the registry, to be reported
when somebody asks about the registry — not at the moment a user presses Run.

## Enabled only

Exactly as the Arguments column decided in issue 1420: a switched-off analysis makes no claim about
a run, and a bench opening with three disabled rows must not open wearing three warnings about a
circuit nobody has asked it to simulate.

## Suites

`test_ase_preflight.tcl` **135 → 144** (section **PF224**). Eight sabotages.

⚠ **One survived, and its repair is the interesting part.** Swapping `fatal` and `blocked` in
`precheck_worst` passed the whole suite, because **every fixture in it yielded findings of exactly
one severity** — and with a lone `fatal`, any ordering returns `fatal`. An ordering row whose
fixtures never disagree is a row that cannot fail. PF224i now forces `exact 1` (so the AC finding
stays `blocked` instead of being demoted) on a CIDER deck under KLU (which is `fatal`), and requires
`fatal` to win.
