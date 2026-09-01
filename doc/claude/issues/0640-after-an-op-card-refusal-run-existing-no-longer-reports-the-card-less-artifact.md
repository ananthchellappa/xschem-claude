# 0640 — after an OP-card refusal, `run_existing` no longer reports the card-less artifact

Status: **OPEN — measured, not fixed. INTRODUCED by 0635's fix**, knowingly.
Filed by the 0617+0618 crew, 2026-08-23. Related: **0635**, 0633, 0617.

## What changed and why

0635's fix stores a record with an **empty block** on every OP-card refusal path
(`ase::op_cards_note_refusal`), so `ase::op_cards_hit` reads 1 and `render_deck`'s
stale-artifact arm stays silent. That is exactly right for the case 0635 was filed
about — the refusal and the render are the same action, one gesture, and the user was
getting two sentences that contradicted each other.

## The silence it leaves behind

The record outlives the gesture. A **later, independent** action —
`ase::run_existing` (`src/ase.tcl:485`), which deliberately does not re-netlist — on
that same artifact now renders a deck with no OP save cards and says **nothing**.
Measured: 0 sentences, deck contains 0 cards. Before the change that path emitted the
stale-artifact error.

The capture sentence *was* spoken, but possibly much earlier in the session, about a
different action, and the user may never have connected the two.

## Why it was accepted rather than fixed

The alternative considered was a "capture already spoke this pass" flag — a second
piece of cross-proc state whose lifetime is a single netlist gesture. That is the
correct shape for this defect, and the wrong size for the step that found it. The
record-based fix was chosen because it preserves the **genuine** stale-artifact
complaint structurally (a different netlist text still misses and is still reported —
row C13d), which a suppression flag would not.

## Recommended

Give the record a **reason** rather than only an empty block — e.g.
`op_cards_put $text {} refused` — and have `render_deck` distinguish "this session
refused to make cards for this artifact, and here is why" from "this artifact is
foreign to this session". That collapses 0635 and this issue into one truthful
sentence per action, which is what the whole 0617 family is about.
