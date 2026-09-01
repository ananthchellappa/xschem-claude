# 0494 — op_annot S3 attempt 4: reverted, and the two claims that refuted it

STATUS: **SUPERSEDED 2026-08-22 — attempt 5 landed from this patch.** **Addressed by S3 (attempt 5), landed 2026-08-22** — see the *S3 LANDED* section of `doc/claude/suggestions/next_session_prompt_op_annotation.md`. `git apply --3way` of the preserved patch was the starting point (D1): `src/xschem.tcl` applied clean, `src/op_annot.tcl` and the suite needed conflict resolution. Attempt 4's decisions **D2** (run and read the netlister, never mirror it), **D4** (`_netlisted` and `_descendable` are not aliases), **D5** (the deck basis is ENTRY-relative), **D6** (`_prefix_ok` suppresses), **D7** (`dims=0` is the acceptance detector) and **D10** (warnings as `* NOTE:` lines) all survived unchanged. Its **D3** (the `** sch_path:` key) was refuted and replaced — see **0496**.

Original filing follows.

STATUS: **OPEN.** Measured on branch `annotate`, step S3d, 2026-08-21, at
baseline commit `d56283ec`. **This is the record of the fourth reverted attempt
at `op_annot::save_cards`.** Preserved patch: `0494-attempt-4-reverted.patch`
(2813 lines, `git apply --check` rc=0 against `d56283ec` — re-verified on the
reverted tree at filing time, not merely at authoring time).

Predecessors: 0436 (attempt 1, raw-relative names), 0442 (attempt 2, three of
seven drop classes), 0443 (attempt 3, interrupted before Verify ever ran).
Children of this filing: 0495, 0496, 0497, 0498, 0499.

---

## Why this is filed as a revert and not as a shipped feature

Attempt 4 was, by a wide margin, the best of the four. It inverted the oracle as
the brief demanded — the SPICE netlister is *run* and *read* rather than
mirrored — it answered all seven drop classes from one hierarchical fixture, it
closed the generate → simulate → read loop against a real ngspice raw for the
first time in the feature's history, and it was green at **275 headless / 281
xvfb** checks against a **241 / 246** baseline, with **17 of 17** sabotage
variants red.

It was reverted because the adversary pass refuted its central claim on
**shipped** designs, and because the shape of the refutation is the same shape
that killed attempts 1, 2 and 3: *a green check count covering an invariant that
is false in the field, with a guardian row that cannot fail.*

Both refutations were re-measured independently by the write-up agent before the
revert was taken. Both reproduce.

---

## BEFORE (the Measure agent's transcript, verbatim)

```
BEFORE-1 save_cards: ABSENT
BEFORE-2 write_save_file: ABSENT
BEFORE-5 devpath args: instname
BEFORE-6 walk procs (_walk/_oracle_run/_deck_index): ABSENT ABSENT ABSENT
BEFORE-7 grep -c 'save_cards' src/xschem.tcl = 0
BEFORE-8 grep -cE '\.save file' src/xschem.tcl = 0
BEFORE-15 op_annot::text M1 on an ordinary-bench raw -> |id    =| |gm    =|
          |gds   =| |vth   =| |vdsat =| |cgg   =| |vgs   = 0.9| |vds   = 1.8|
          |ft    =| |gm/id =|
BEFORE-17 HIER sch (1 FET one level down), flat stand-in emits 0 cards -> {}
BEFORE-19 op_annot::save_cards on hier sch: RAISES: invalid command name
          "op_annot::save_cards"
```

That state is **restored**: after the revert, `src/op_annot.tcl` is back to 793
lines / 17 procs and `test_op_annot.tcl` reports `RESULT: ALL PASS (241 checks)`.

## AFTER (what the reverted patch achieved, for the next crew's benefit)

```
T3 test_op_annot.tcl headless = RESULT: ALL PASS (275 checks)   [baseline 241]
T3 test_op_annot.tcl xvfb     = RESULT: ALL PASS (281 checks)   [baseline 246]
T3 test_op_annot.tcl --logdir = RESULT: ALL PASS (276 checks)
T1 run_regression.tcl = byte-identical to baseline (3 FAIL / 0 GOLD? / 3 NOGOLD)
T2 tests/headless/run.sh = HARNESS: PASS, 6/6
X1..X4 = generated block + netlister deck -> ngspice rc=0, raw written,
         12/12 cards materialised, ZERO dims=0, op_annot::text renders
         id = 116.3u / gm = 581.3u / gds = 5.333u / vdsat = 0.4 / gm/id = 5
```

---

## REFUTATION 1 — I4 is claimed in the source and is false on a shipped design

`src/op_annot.tcl` (reverted patch, `save_cards` header) asserts:

```
## I4: reads context, never writes it. No instance placed, no set_modify,
## nothing written to the .sch — and it refuses outright rather than let the
## oracle's netlist eat a pending gesture.
```

Re-measured by the write-up agent, `--nogui`, sky130 library path set
unqualified and `sky130_procs.tcl` sourced (the suite's own fixture route):

```
I4-REPRO bandgap_opamp    : modified BEFORE=0 AFTER=1  rc=0  lines=103
I4-REPRO tb_bandgap_opamp : modified BEFORE=0 AFTER=0  rc=0  lines=115
```

Isolated to the exact operation, instance by instance:

```
load: modified=0 insts=73
DIRTY inst=x1  modified before=0 afterdescend=0 aftergoback=1
DIRTY inst=x3  modified before=1 afterdescend=0 aftergoback=1
final modified=1
```

`xschem go_back 2` dirties the **parent**. A user who clicks the new menu item
on `sky130A/xschem_libs/sky130_tests_ase/bandgap_opamp` gets a modified sheet
and a save-on-close prompt on a schematic they never edited. The guardian, row
**W19**, asserts `modified == 0` and **cannot fail**, because its fixture is a
synthetic `.sch` the test itself just wrote at file_version 1.2 while the shipped
bench is 3.4.8RC/1.3.

Filed separately as **0495** (the go_back behaviour) and **0499** (the vacuous
guardian).

## REFUTATION 2 — "one card per netlisted device" is false, silently, on the flagship bench

On `sky130_tests_ase/tb_bandgap_opamp`, re-measured by the write-up agent:

```
CARDS=114  DISTINCT-DEVICES=19
WARNINGS: {2 subcircuit instance(s) got no cards because the netlist does not
expand them here (spice_stop, spice_sym_def, an ignored or behavioural cell, or
an empty block) - normal for such cells}
deck MOS element count = 39
```

The deck the oracle itself wrote contains **both** of these, under the **same**
`** sch_path:` key:

```
175:** sch_path: .../sky130_tests/passgate/schematic/passgate.sch
176:.subckt passgate_1 Z A GP GN VCCBPIN VSSBPIN  W_N=1 L_N=0.2 W_P=1 L_P=0.2
195:** sch_path: .../sky130_tests/gain_stage/schematic/gain_stage.sch
196:.subckt gain_stage2 IN OUT VCC VSS START_N START EN_N  wcap=10 WN=0.5 WP=1
```

These are **parameter specialisations** synthesised by `get_additional_symbols`.
`get_sch_from_sym` answers the synthesised names `passgate_1` / `gain_stage2`,
which are not keys of the sch_path-keyed deck index, so `_descendable` is 0 and
both subtrees emit nothing. The netlister **did** expand them. The only user
signal is an aggregate warning ending **"- normal for such cells"**, which is
false here.

The direction is under-emission (blank rows, invariant I3's preferred failure),
not the raw-destroying over-emission — but it is the feature failing at its one
job, on the flagship sky130 bench, while reporting success. Filed as **0496**.

---

## Decisions taken by this crew, with ladder rung and rejected alternative

* **D1 — start from attempt 3 (0443), not 0442. Rung L2.** All three base blobs
  were present, `git apply -3` gave only comment-header collisions.
  *Rejected:* hand-lifting 0442 (cannot 3-way merge at all — "repository lacks
  the necessary blob") and re-deriving from 0436, both of which discard attempt
  3's oracle work for no gain.
* **D2 — the netlister is the oracle, READ not reimplemented. Rung L2, on
  measurement.** `xschem netlist -keep_symbols -noalert <abs>` costs 12–116 ms on
  ordinary designs, writes to `$USER_CONF_DIR/op_annot` so `$netlist_dir` is
  untouched, and restores netlist_dir itself. **This decision survived every
  attack and should be carried forward unchanged.** *Rejected:* a new C verb over
  `skip_instance()` (a partial oracle wearing a C badge — the four symbol-level
  classes are not in `skip_instance` at all), and a fourth hand-maintained Tcl
  mirror.
* **D3 — the deck index is keyed on `** sch_path:`. Rung L2. REFUTED IN PART by
  0496** — parameter specialisations share one key. *Rejected at the time:* the
  cell name (the netlister's own dedup hash) and `** sym_path:`.
* **D4 — `_netlisted` and `_descendable` are separate predicates. Rung L1,
  I2b.** Survived. *Rejected:* aliasing them, which is what attempt 2 shipped.
* **D5 — the deck basis is entry-relative, not level-0 absolute. Rung L1, I1.**
  Survived; settled by measurement (a netlist from a descended cell makes that
  cell the deck top). *Rejected:* 0436's own level-0 sketch.
* **D6 — a hierarchy segment disagreeing with the deck element name suppresses
  the subtree. Rung L1, I3.** Survived as a guard, filed as 0488 because it
  mitigates rather than fixes. *Rejected:* the Scout's "file it, pin it, do not
  let it block" — a pinned wrong card is the raw-destroying card in a hat.
* **D7 — the acceptance detector is `dims=0`, not the brief's stderr capture.
  Rung L2, on a measurement that contradicts the step brief.** Survived and is
  now written into the spec. *Rejected:* stderr as primary; kept as supplement.
* **D9 — the menu item lands in Simulation > Graphs. Rung L3.** This was the
  status-E question and is now **moot for this attempt** (reverted), but it
  returns for attempt 5. See the plan file.
* **D10 — warnings surface as `* NOTE:` comments, not an alert. Rung L2.**
  Survived in principle, but the channel is unreachable on the path that
  produces the most important warning — see **0497**.

---

## Sabotage matrix (17 planned + 3 extra, all red on the final code)

| variant | predicted red | observed |
|---|---|---|
| basis_ignored | 6 | 4 — W5 W6 W7 W8; **X2 X3 missing** |
| at_path_left_to_translate | 1 | 4 — C3 W6 W7 W8; W5 correctly green |
| devproc_gets_read_path | 3 | 3 — W5 W7 W8; W6 correctly green; **X2 X3 missing** |
| netlisted_always_true | 6 | 17 |
| descendable_aliases_netlisted | 4 | 2 — W14 W28; **W12 W13 W15 missing** |
| wrapped_card | 5 | 20 |
| no_save_all | 2 | 10 |
| restore_skipped | 4 | 14 + **deterministic SIGSEGV 3/3** |
| oracle_index_empty | — | 23 |
| descended_always_true | — | **W27 only** (unit probe; no integration row) |
| prefix_guard_off | — | W18 |
| user_region_ignored | — | W16 |
| env_not_restored | — | W24 W26 |
| unwind_to_zero | — | W8 W21 |
| idle_gate_off | — | W25 |
| menu_item_absent / menu_wrapper_silent | — | W29 (xvfb only) |
| partial_block_swallowed *(extra)* | — | W20 W21 W24 |
| derived_rows_emitted *(extra)* | — | 18 incl. X1 X3 |
| bare_save_all *(extra)* | — | 13 incl. all of X1–X4 |

### Predicted reds that did NOT appear — the tell, again

The plan said, in as many words: *if any of the four rows stays green the
seven-class fixture is defective; fix it before landing, do not footnote it.*
Three stayed green and were footnoted (rows W27/W28 were added instead).

* **descendable_aliases_netlisted → W12, W13, W15 stayed green.** Under the alias
  the walk **does** descend into the dropped subtree (`_miss_dev` moves 4 → 13),
  but the fixture gives each drop-class symbol a private byte-copy `.sch` whose
  key is absent from the deck index, so `_here_block` returns `{}` and no card
  can be emitted. The rows assert *"no card"*, never *"no descend"* — so they are
  true for a reason they do not test.
* **basis_ignored / devproc_gets_read_path → X2, X3 stayed green.** Structural,
  not a fixture defect: section X calls `save_cards` at the top with no raw
  loaded, where the `read` and `deck` bases produce the same string. The exact
  defect that killed attempt 1 is therefore verified **only** by string goldens
  and is never closed against a raw the feature itself caused to exist.
* **descended_always_true → W27 only**, a unit probe. No row exercises a walk
  containing a class-1 descend refusal, so 0433's real consequence (a level
  popped that was never pushed → duplicate cards) is uncovered end to end.

All three are folded into **0499**.

---

## Still open

Carried from the adversary pass; every one of these must be answered by attempt 5.

1. **0495** — `go_back` dirties the parent; I4 is claimed and false.
2. **0496** — parameter-specialised subcircuits are invisible to the deck index
   and their blocks merge under one key. 12 of 39 deck FETs get no card.
3. **0497** — the `* NOTE:` channel is unreachable on an empty block, a raising
   devproc emits zero cards and zero warnings, and an unreadable subcell is
   reported as "normal".
4. **0499** — W19 vacuous, section X cannot discriminate a basis, no end-to-end
   descend-refusal row, and the three under-reddened sabotage variants.
5. **0493** — ~5–6 s on `0_examples_top` (34538 `_normkey` calls), producing an
   empty file on that design.
6. **0488** — the hierarchy prefix drops `spiceprefix`; `_prefix_ok` mitigates.
7. **0498** — a leaked `keep_symbols=1` across a load segfaults the C core.
8. **The D9 cascade question** is unratified and returns with attempt 5.
9. `gf180` is the only descriptor arm with no in-tree bench carrying a FET; its
   `@path` TEMPLATE arm was never exercised against a real generated deck.
10. `_wrap` and `_cards_for` spell the `[param]` suffix independently. I1 holds
    for the device *name* (one builder), but a shared `_bare {dev param}` helper
    would remove the last place the two shapes can drift.
