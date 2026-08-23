# 0617 — a successful OP run annotates nothing, and the tool does not say why

STATUS: **HALF CLOSED 2026-08-22 — S3 landed, S4 has not.** **Addressed by S3 (attempt 5), landed 2026-08-22** — see the *S3 LANDED* section of `doc/claude/suggestions/next_session_prompt_op_annotation.md`. `op_annot::save_cards` on the user's own `sky130_tests_ase/tb_bandgap` now emits **469 lines (1 × `.save all` + 468 cards)** in 244 ms, of which **468 of 468 materialise as real vectors** in an ngspice 46+ raw, and all 78 cards of the hand-written demo golden are a byte-exact subset. **The user's six blank rows are still blank until S4 carries the block into `ase::render_deck`** (or the user runs the new *Simulation → Graphs → Create device OP .save file* menu item and `.include`s the result). The **I8** half of this issue — the tool saying *why* a row is blank — is untouched and still open.

Original filing follows.

STATUS: **OPEN — reported by the user 2026-08-22**, second eyes-on session.
The *cause* is that plan steps **S3 and S4 were never implemented**; this issue
is the user-visible half that stands even after they land. Rider on
[0604](0604-op-annot-must-report-requested-but-undelivered-vectors.md) (invariant **I8**:
report requested-but-undelivered). Related: 0607, 0608.

---

## What the user did, and saw

```
src/xschem --script sky130A/cadence_style_rc --logdir /tmp
open ngspice_state1 of tb_bandgap  (sky130_tests_ase)
enable ONLY the OP analysis, Netlist and Run   -> succeeds
descend x1 > x1, press 6
```

> "Nothing - I get only `param = <blank>`. And node voltages are already
> displayed without asking for them."

## Why. It is not a mystery, and it is not the raw's fault

Measured simulator rule **R1** (spec §3): `gm`, `gds`, `vth`, `vdsat`, `cgg`
**exist in a raw only if the deck saved them explicitly, one card per device per
parameter.** `save all` does not include them — it covers node voltages and
source branch currents, which is exactly why the user's node voltages *were*
there and every device row was blank. The raw is correct; the deck never asked.

`ase::render_deck` (`src/ase.tcl:3159-3166`) emits `.save all` plus one `.save`
per **user-configured output row**. Nothing in the shipped tree emits the
per-device operating-point cards, because:

- **S3 (`op_annot::save_cards` + the hierarchy walk) is NOT IMPLEMENTED.**
  `src/op_annot.tcl` has `vector`, `devpath`, `text`, `descriptor` … and **no
  save-card emitter** at all (`grep -n '^proc' src/op_annot.tcl`).
- **S4 (ASE carries the cards into the deck) is NOT IMPLEMENTED.**

So the display half of the feature (S5/S6/S7/S8/S9/S11) shipped and the supply
half did not. Every demo to date got its cards from a **hand-written scratch
generator** outside the tree — `~/op_annot_demo/gen.tcl`, 78 cards, documented in
`~/op_annot_demo/REPRO_bandgap.md` step 2. That is the entire difference between
the sessions that annotated and the user's session that did not.

## The two halves of the fix

**Half 1 — supply the cards.** Implement S3 and S4 as the plan already specifies
them (`doc/claude/suggestions/next_session_prompt_op_annotation.md:610` and
`:742`, including landmines 1/2/7/14 and rule R4: **a save card is BARE, never
`op_annot::vector`'s wrapped form**). Dispatched as its own work; not this issue.

**Half 2 — this issue. Say it out loud.** Even with S3/S4 landed, a user can run
a deck that predates them, a hand-edited deck, or `Run` on an existing netlist
artifact (`ase::run_existing`). Today that path is **silent**: six rows of
`<blank>` and no statement of why. Invariant **I3** says a missing vector renders
blank — correct, keep it — but **I8** says the tool must report what it was asked
for and did not deliver.

Required: when annotation resolves and **every** device parameter vector is
missing while the raw is otherwise loaded and healthy, the status line must say
so once, held, naming the actual cause and the actual remedy. Something with the
information content of:

> `OP annotate: raw has no device parameter vectors (deck emitted no per-device
> .save cards). Re-netlist with OP annotation enabled.`

**Not** a generic "no data". The user must be able to act on it without reading
this file.

## Landmines

- **Distinguish the three blank causes** — they need different sentences:
  (a) no raw loaded at all; (b) raw loaded but *no device vectors saved* (this
  issue); (c) raw loaded, cards present, but this **instance** is absent from it
  (the `x1 > x2` case — measured 2026-08-22 as a *bench* artefact, the demo raw
  genuinely only held `@m.x1.x1.*`, and the blank was I3 behaving correctly).
  Reporting (b) when it is really (c) sends the user to re-netlist for nothing.
- **Say it once, held — not per instance.** 13 FETs must not produce 13 status
  messages or 78 of them. The S8 chords already use the held status line.
- **Do not break I3.** The rows still render blank. This adds a channel, it does
  not add a fake number or an error dialog.
- `ase::run_existing` deliberately does not re-netlist, so its remedy sentence
  differs — it must tell the user to re-netlist, not merely to re-run.

## Acceptance

- Raw with `save all` only + press `6`: blank rows **and** a held status line
  naming the missing-save-cards cause.
- Raw with cards present + press `6`: numbers, and **no** message (no crying wolf).
- Raw absent + press `6`: the existing "no raw file" message, unchanged.
- Cards present but the instance is not in the raw: the (c) sentence, not the (b) one.
