# 1422 — the tokens `netlist_map` throws away are exactly the ones a precondition needs

**Status:** fixed
**Branch:** fluid-editing
**Stage:** commit **C2** of Stage 4 of `doc/claude/ase_analyses_batch/`.

## What ships

`ase::netlist_facts {netlist_text}` — a **second pass** over the text `ase::netlist_map` already
walks, returning

```
{sources  {<inst> {scope <s> letter v|i ac <mag> dc <v> portnum <n> z0 <r>
                   distof1 <a> distof2 <a> trnoise <args> trrandom <args>}}
 families {resistor 1 vsource 1 mos 1 ...}
 events   {<node> 1 ...}
 models   {<name> {type <t> level <n>}}
 nodes    <netlist_map's scopes>
 exact    0}
```

## Why a second pass and not a bigger first one

`netlist_map` **drops every token containing an `=`** — on element cards and on `.subckt` parameter
defaults — and skips every dot-card but `.subckt`, `.ends`, `.global` and the includes. That is
correct for its own job, which is *"does this node exist"*. It also makes it **structurally unable**
to answer what a precondition asks: does this source carry an AC magnitude, a `distof1`, a
`portnum`, a `trnoise`. Those are precisely the discarded tokens. Row **PF223a** asserts both
halves — that `netlist_facts` has `portnum=1` and that `netlist_map` still does not — so the two
passes cannot silently become redundant.

## Core, not adapter, and deliberately

This reads the SPICE netlist **xschem itself emits**; the device-letter convention is xschem's
netlister's, not any one simulator's. What each fact *means* to a given simulator is the adapter's
business (D34–D37); that this deck has a `v` card carrying an AC magnitude is not.

## Four measured traps, each with its own row

⚠ **A bare `ac` with no magnitude is still `acGiven`, and its magnitude is 1.** `I7 a b ac` is a
legal AC source. A reader that required a number would report *"no AC source"* for a deck that has
one — a **false refusal**, which is the failure mode this whole pass exists to avoid, and the reason
the plan caps static facts at `warns`.

⚠ **The continuation fold has to be byte-identical to `netlist_map`'s.** A source's `ac 1` most
often lives on a `+` line, because xschem's netlister wraps long device cards. A pass that folded
differently would answer differently about the same deck than the pass the refusals are aligned
with, and nothing would say so. **PF223j** asserts both passes see the same scopes.

⚠ **A bare value in the third position is a DC value.** `V9 TOPNET 0 1` means `dc 1` — the commonest
card in every bench in this repository. A precondition refusing it for *"no DC value"* would be
wrong about all of them.

⚠ **An unknown device letter is recorded, not discarded**, under its own letter. Stage 2's OSDI rule
applies here too: a family nothing recognises is a `caution` and never a block — and a caller cannot
caution about a family this pass silently dropped.

## `exact 0` is part of the answer, not a footnote

This pass cannot see inside an `.include`, so *"no AC source"* from a deck that includes a stimulus
file is a **guess**. A caller that turns a static fact into a refusal refuses decks that work. Static
**warns**; only an exact leg blocks. That is the same stand-down `ase::netlist_map_resolve` already
makes for include-bearing scopes, and **PF223i** pins it against `NLX`, the suite's include fixture.

## `events` holds nodes

An XSPICE event **model** is a fact about the deck, not about a node; putting its name in `events`
would make *"is this node an event node"* answer yes for a string that is not a node at all. The
model is in `models` with its type, which is where a caller asks whether the deck has a digital
island. That was wrong in the first draft and **PF223h** is why it is not wrong now.

## Suites

`test_ase_preflight.tcl` **125 → 135** (section **PF223**), and it is now in T1 (issue 1421).
Eight sabotages, each reddening exactly its own row.
