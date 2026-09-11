# Receipt 06 — Stage 1 landed: eight copies become one registry, byte-identically

**Date.** 2026-09-11.
**Scope.** `src/ase.tcl`, `src/ase_window.tcl`, `tests/headless/test_ase_core.tcl` (row **D8i**,
floor 257 → 258; the rest of D8 is its own commit), `tests/headless/test_ase_dialogs.tcl` (six widget paths + the G2
display golden), `tests/headless/test_ase_window.tcl` (the P4 display golden),
`doc/claude/specs/ase_l.md`, and this batch's records.

**Rulings: none.** Stage 1 carries no ruling and minted no user-facing sentence.

---

## The acceptance, and why the plan's own gate was not enough

**Stage 1's stated acceptance is deck golden D1 under `string equal`. D1 is OP-ONLY.** Its
fixture enables one `op` row, so the golden deck carries the single line `op` and the
`dc`/`ac`/`tran` emit arms are never exercised by it. A refactor that collapses a hand-written
four-arm `switch` into a registry can move those bytes with D1 still green.

**MEASURED, not suspected** — the registry was sabotaged against the whole committed suite:

| sabotage | `test_ase_core` before D8 | after D8 |
|---|---|---|
| `dc`'s template swaps `@start` and `@stop` | **ALL PASS (248)** | D8a, D8f, D8g, D8h, D8i red |
| `ac`'s hardwired `dec` → `oct` | **ALL PASS (248)** | D8b, D8e, D8f, D8g red |
| `op`'s `emitorder` 0 → 100 | 4 FAILED | 4 FAILED |
| `tran`'s `viewrank` demoted | unmoved *(correct — not a deck fact)* | `test_ase_optier_0963` **R6** red |

So **nothing committed in this tree would have noticed a refactor that reversed every DC sweep
in the product, or silently changed every AC sweep to octaves.** Both were caught only by a
17-case render corpus held outside the repository, which is not a guard anybody inherits.
Section **D8** commits that corpus's discriminating half so every later stage inherits an
acceptance that discriminates. Correction **C43**.

⚠ **D8 WAS COMMITTED SEPARATELY AND FIRST** (`test(ase-core): D8 pins the emitted analysis line
per type, because D1 could not`, floor **248 → 257**), and the split is what makes its claim
checkable: nine of its ten rows pin DECK BYTES and therefore pass against the hand-written
`switch` they were written to guard, and sabotaging *that switch* — not its replacement —
reddens four rows in each case. Only **D8i** belongs to this commit (floor **257 → 258**),
because the behaviour it asserts, the Arguments column being the emitted line, does not exist
until this refactor creates it.

**What the corpus established:** 17 cases (every type alone, all four together, both row
orderings, `op`-then-`dc`, duplicate rows of one type, an unknown extra key, nothing enabled)
rendered before and after the whole stage, md5 **`958abd0ba421f65cc9db21db6b99ea03`** both
times. Separately **105 `.state` files round-trip with 0 mismatches**, A/B-confirmed identical
against the pre-Stage-1 tree — which matters precisely because `ase::state_default`'s seed is
now a registry reader rather than a literal.

⚠ **The first run of that `.state` probe reported 105 of 105 mismatched, and it was the
PROBE.** `ase::state_serialize` returns the body without a trailing newline and the files on
disk have one. Third harness-side false red of this session; the A/B against the pre-Stage-1
tree is what settled it, not argument.

---

## 1e — the Xyce paper-validation, which is the reason this stage looks different from its plan

The plan says *"nothing broke is a suspicious answer"*. Nothing like it happened: five families
of Xyce analysis written against the §1a key set, every *"that expressed cleanly"* claim handed
to a separate agent told to refute it — **157 breakages, 77 found ONLY by the adversary**,
consolidating to 23 changes that must land before the key set freezes. All three predicted
breakages reproduced and each was larger than predicted.

**Three landed in this stage's code**, and none moves a byte:

1. **`verb` DELETED** (C41) — *"the `.control` command word AND what `help <verb>` probes
   with"*: two ngspice words in the half §1a says may contain none, naming a construct a
   batch-only simulator does not have. It was never the source of the emitted token.
2. **`gated` → `baseline`** (C42) — besides naming an ngspice source file inside the schema, it
   is the **only** steer on `ase::requires_state`'s `unknown` arm, so an adapter that cannot
   assert an ngspice-style invariant writes `0` and every unmeasured capability resolves to
   *offer it anyway*: the inverse of Stage 2's stated worst outcome.
3. **`emit` became an ordered list of role-tagged cards** (C40) — a runnable Xyce `.TRAN` is
   two cards, and **this repository already ships one**: `solar_panel_xyce.sch:155-156` carries
   `.tran 5n 1000u uic` plus `.print tran format=raw file=…`. It landed now rather than later
   because it changes the one speller's **return type**.

⚠ **The meta-finding is the one to carry.** **§1a's naming rule is LEXICAL, so it caught every
ngspice NOUN and missed every ngspice SEMANTIC** (C37). `emit`'s `@name!` exists *"because
ngspice's argument lists are POSITIONAL"*; `bool`'s *"never `=1`"* is a measured ngspice defect
promoted into the type system; `plots.match` globs a record only an ngspice rawfile has. All
three pass a grep for simulator words, so **D36's prediction that reaching for a simulator fact
surfaces as a finding is false exactly where it cost most.** And the tree proves the sharpest
case: §1b's number lexicon `f p n u m k meg g t` is **narrower than xschem's own C parser**,
which carries `x` = 1e6 at `src/editprop.c:101` under the comment `/* Xyce extension */`.

**Three defects were found on paper with no Xyce involved at all**, each verified in-tree:
`rules` has **no written grammar anywhere** (§1a's cross-reference points at §1d, the `.form`
frame); **D30 would reject the plan's own `tran`/`tf`/`pz`/`sens` entries** (C38); and
`requires`' **`raised` arm is unreachable by a conforming adapter** (C39) — present at
`PLAN.md:1206` and in a planned test row at `:1047`, absent from all of D42–D52.

⚠ **`ase::requires_state` AND THE ENTRY-LEVEL `requires` KEY ARE NOT IN THE TREE — they are DESIGNED here, not SHIPPED here.** Measured 2026-09-11: `grep -c requires_state src/ase.tcl src/ase_window.tcl` is **0** in both. The sentences above describe what the key is *for*, and a reader has already taken them as a record of something landed. **Stage 2's C5 commit creates it**, with the signature `{req caps baseline}` — not the plan's `{req caps gated}` — because Stage 1 renamed the key and INVERTED its polarity, so an absent `baseline` must default to **0**. Corrected after the Stage 2 recon caught it; the same class of un-measured record cost 100 checks as issue 1405.

**The other 20 changes are recorded against ⚖ R10**, whose input this is. The largest: there is
**no adapter-level descriptor at all** — analysis cardinality, composition, whether the
simulator owns its own sweep, and the run-model fact Stage 2e's Stop sentence needs have
nowhere to be written.

---

## The eight copies, and where each went

| copy | now |
|---|---|
| `render_deck`'s four-arm emit `switch` | `ase::analysis_line` — the one speller |
| the print anchor's own `foreach type {dc ac tran op}` | `ase::analysis_emit_order $state 1` |
| `ase::analysis_emit_rank`'s four-entry table | the registry's `emitorder` |
| `ase::plot_sim_type`'s own walk | the registry's `viewrank` |
| `ase::state_default`'s analyses seed | `ase::analysis_seed` + `seed_enabled` |
| `ase::ui::anaargs` | **deleted** |
| `ase::ui::chana_fields`' `switch` | `ase::analysis_field_names` |
| the radio `foreach {op dc ac tran}` | `ase::analysis_offered` |
| *(and)* `chana_show`'s five-name destroy list | `destroy $w.form` |

⚠ **One literal is kept, deliberately and marked.** `ase::analysis_seed`'s fallback is today's
four-row list, because `ase::state_default` is called before any simulator is chosen —
including by `ase::state_load` for every file it merges over — and a backend with no registry
must still produce a usable default state.

## Three defects of mine, all caught by measurement rather than by reading

* **Unbounded recursion.** `state_default → analysis_seed → analysis_types → state_default`;
  the file would not load. Fixed with a named `ase::default_simulator` rather than resolving
  the default out of `state_default`.
* **The state's `simulator` key is not always a backend name.** `test_ase_core` E2b and E3
  drive a deliberately missing binary and a `nosuchsim`. With the ranks now in the rendering
  backend's registry rather than a literal in core, `render_deck` must ask for **its own** —
  `[namespace tail [namespace current]]`. Cost: 85 checks, and the suite aborted at 163 of 248.
* **The Arguments column asked for a deck line from a row that cannot have one.**
  `ase::analysis_line` resolves `@source` with `dict get` *deliberately* — that is byte for byte
  the failure `render_deck` had before Stage 1, and a refactor may not change a failure mode any
  more than an output. But the pane renders **every** row, and `state_default` seeds
  `{type dc enabled 0}` with no field keys. `test_ase_dialogs` died at **0 of 215** on the
  display arm while the headless arm stayed green — **37 checks against 215**. The deck path
  still raises; the renderer falls back. Row **D8j** pins it.

⚠ **The third one is the arm-coverage lesson in its sharpest form**: a widget change whose whole
subject is a widget path cannot be accepted on a headless number.

## What was NOT done, deliberately

* **`ac`'s stored sweep mode is still ignored.** A state carrying `dec oct` still emits
  `ac dec 20 10 1g`. That is the drift the registry exists to delete, and deleting it is
  **Stage 3's**, where a moved golden is expected and named. Row **D8e** pins today's behaviour
  and says in its own text that Stage 3 moves it.
* **`label` carries today's radio text**, not a human noun. A refactor may not mint user-facing
  copy; promoting these is a ratified change under ⚖ **R9**.
* **`requires` / `notes` / `lint` are declared and unexercised.** None of Stage 1's four types
  uses one, so no row pins them — which is exactly the gap ⚖ R10 governs.
* **Out of scope and named, per the plan:** `test_rdw_seam_1245` G3/G3b, `rdw.tcl`'s copy of the
  `{op dc}` allow-list, and `xschem.tcl`'s sim-type combobox. Untouched.
