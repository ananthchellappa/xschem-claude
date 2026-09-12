# 1416 — a skipped start time let the maximum step be read as one, and the sweep mode was discarded

**Status:** fixed
**Branch:** fluid-editing
**Stage:** commit **C3** of Stage 3 of `doc/claude/ase_analyses_batch/`.

## What ships

The **four field tables**. `tran` gains `tstart`, `tmax` and `uic`; `ac` gains `sweep`; `dc` gains
its second sweep nest (`source2 start2 stop2 step2`). `ase::analysis_expand` gains the **positional
back-fill**; `ase::analysis_emit_check` gains the **group rule**; the adapter gains a `dc_swkind`
hook. `ase::ui::chana_ok`'s D6 loop is deleted and the door **asks `ase::analysis_emit_check`**.

## The defect this is named for

ngspice reads the transient card **purely by position**:

```
tran tstep tstop [tstart [tmax]] [uic]
```

Issue 1414 stopped a skipped slot emitting an **empty word**. It did not stop a skipped slot letting
the value to its **right** slide left into its place — and that emission has no double space, no
empty element and nothing whatever for a reader to notice. A row carrying a maximum step and no
start time emitted

```
tran 1n 10u 0.2n
```

and ngspice takes `0.2n` as **tstart**: the run records from 0.2n to 10u with the integrator left
unbounded. **rc 0, no warning, a plot with the right name and the wrong contents.**

The fix is `whenskipped` on the **field**, not a flag on the card. A field that occupies a position
says what it means when it is left out, and a skipped slot emits that value whenever anything to its
right still emits. A field with no `whenskipped` is genuinely trailing and simply vanishes — which
is why `tmax` declares none and `tstart` declares `0`.

| row | emits |
|---|---|
| `step stop` | `tran 1n 10u` — **unchanged, and that is the point** |
| `step stop tmax` | `tran 1n 10u 0 0.2n` |
| `step stop tstart tmax` | `tran 1n 10u 1u 0.2n` |
| `step stop uic` | `tran 1n 10u 0 uic` |
| `step stop uic 0` | `tran 1n 10u` |

## The second defect: `ac` discarded the sweep mode in silence

`render_deck` carried the word `dec` as a **literal inside the template**, so a state row storing
`oct` or `lin` emitted `ac dec …` and threw the stored value away. This was measured and recorded
beside the registry entry before this commit; `@sweep?` with `default dec` resolves the same word
**at emit**, so all 104 committed `ac` rows — **none of which carries a `sweep` key at all** — still
emit the same five words, and a row that stores `lin` finally gets `lin`.

## Three measurements that corrected the plan

⚠ **The plan spelled the dc sweep variable `@target`. Not one committed row carries that key.**
Measured over every tracked `.state` file: **36** rows carry `source`, **0** carry `target`. A
required `@target` slot would have raised on every one of them and reddened four suites. The field
is `source`.

⚠ **The plan's template spelling would have moved all 104 committed benches.** It wrote
`{tran @step @stop @tstart! @tmax! @uic?}`. Under the grammar shipped in 1414, `!` resolves a
non-bool through `ase::field_emits`, which returns the field's **default** when the key is absent —
so a defaulted `tstart` emits `tran 1n 10u 0` for **every** committed row. `?` and `!` are swapped
relative to the implemented grammar: the optional value slots are `?`, and `!` is the bool. The
shipped template is `{tran @step @stop @tstart? @tmax? @uic!}`.

⚠ **`dc_swkind` classifies by the SPICE device letter, and the corpus is why.** The plan's sketch
was "the literal word `temp`, else a voltage source". The 104 committed benches carry twelve
distinct sweep variables —

```
I0 V1 VD Vce Vds Vin Vres i0 i1 temp v2 vd
```

— of which **three spellings are current sources, across seven committed rows**. The sketch would
have labelled every one of them a voltage source. `Vres` is the other half of the lesson: it is a
**voltage source whose name contains `res`**, so the test has to be the first character and not a
substring.

## The group rule, and why `required` cannot express it

Each of the second nest's four values is genuinely optional on its own — 68 of the 104 committed
benches have none of them. What is not legal is **three**. `dc V1 0 1 0.1 temp` is not a smaller
sweep that does less; it is a parse error ngspice reports from the middle of a run, after the deck
has been written and the process started. A per-field `required` cannot say this, so a field may
declare `group <phrase>` and `analysis_emit_check` refuses any group that is partly filled. The
finding names the **group**, not one of its fields: naming one would send the user to fill it in and
leave the other two still missing.

## The door no longer knows what a row needs; it asks

`ase::ui::chana_ok`'s D6 loop demanded that **every** field of the type be non-empty. That was only
ever right because every field of every type happened to be `required 1`. The moment `tran` declared
three optional ones, that loop would refuse a row ngspice runs perfectly well — and refuse it naming
a field the user was never obliged to fill.

⚠ **And the existing suite would not have caught it.** Row G2b asserts that an enabled `tran` with a
blank `step` is *refused*; a door that refuses **everything** satisfies it. G2c is the converse row,
and it exists because of this.

The probe row is built from the **form's** values, not from the stored row: the point of a commit
door is to judge what the user is about to store, and the stored row is still the previous answer at
that moment.

## The corpus, measured

| | |
|---|---|
| tracked `.state` files | **104** |
| analysis rows | **416**, exactly four per file |
| key sets | `ac` `{enabled type}` / `{enabled points start stop type}`; `dc` `{enabled type}` / `{enabled source start step stop type}`; `op` `{enabled type}`; `tran` `{enabled type}` / `{enabled step stop type}` |
| rows carrying a key outside `type`/`enabled`/declared fields | **0** |
| emitted word counts | `op` 1, `dc` 5, `ac` 5, `tran` 3 — **unchanged by this commit** |

The last row is the byte-identity proof: a new default, a new back-fill or a new positional slot
leaking into the committed corpus moves one of those four numbers, and section **CP** of
`test_ase_core.tcl` is the only thing in the tree that would notice.

## Suites

`test_ase_core.tcl` **309 → 333** (sections **PB**, **GR**, **CP**).
`test_ase_simcaps_0948.tcl` **158 → 164** (section **W**; row **Q1** narrowed to its own claim).
`test_ase_dialogs.tcl` display **236 → 242** (rows **G2c**, **G2d**), headless 37 unmoved.

⚠ **Row Q1 was pinning the whole `dc` template as evidence for a claim about its first word**, so it
reddened the moment `dc` gained its nest — for a reason unrelated to its subject, which is exactly
the failure `ase.tcl` warns about beside `ase::analysis_expand`. It now pins the claim: the token is
the template's first word, the template is longer than that word, and its second token is a slot.

## What this does NOT ship

The `▸ Advanced` disclosure, the mode picker as a real combobox, the `uic` checkbutton, the relabel
on a mode change, and the Initial-conditions sub-dialog are **C4**. Until C4 lands, the new fields
appear as plain entries, and `uic` is an entry the user types `1` or `0` into — `analysis_emit_check`
refuses anything else, so it cannot reach a deck wrong, but it is not yet the control it should be.

The `grid` field (`native`/`interp`/`linearize`) is **deferred to Stage 6** — see the ledger.
