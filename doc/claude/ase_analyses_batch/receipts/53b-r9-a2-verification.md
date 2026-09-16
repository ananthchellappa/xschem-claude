# 53b — adversarial verification of ⚖ R9 ruling A2 (receipt 53)

**Role:** adversarial verifier. Brief: disbelieve receipt `53-r9-a2-picker-words.md`, re-derive its two
headline claims independently, and report what is actually true.

**Tree state.** HEAD `252fee2d` at start and at end. **No source file was changed.** The four files
under test carry the identical md5s at the end of this pass that they carried at the start:

| file | md5, start and end |
|---|---|
| `src/ase.tcl` | `c72f09aa6d00f97708813e4c10104b78` |
| `src/ase_window.tcl` | `1709a76a35f19d0ead85935cdccb6a4b` |
| `tests/headless/test_ase_core.tcl` | `7c586655ee8b4f8d9bfab35117292f60` |
| `tests/headless/test_ase_dialogs.tcl` | `c9c2086cccad4304afedb29366d0bc5f` |

No `git checkout --`, `restore`, `stash`, `clean`, `add`, `commit` or `push` was run at any point.
`~/.xschem/recent_files` is **untouched at 2026-09-13 18:53:01** (issue 0924 canary), checked at the
start and again at the end. `owed.sh count` is **187 rule, 70 look, 11 suite** at start and end —
nothing added, nothing cleared.

---

## ⚠ THE METHOD, BECAUSE IT IS WHAT MAKES THIS INDEPENDENT

The brief forbade re-running the crew's script or trusting its method. **No source file was mutated
to test a mutation.** Instead every arm was run by pointing the binary at a *different sharedir*:

`src/xinit.c:3204` gives `XSCHEM_SHAREDIR` **priority 1** over every other resolution. So
`git archive 252fee2d | tar -x -C <scratch>` yields a complete pristine tree, `cp` of the two working
files over a copy of it yields a complete working tree, and each sabotage is a third tree differing
from the working one by a counted number of lines. The repo's own `src/` was never written to.

**The method was validated before it was trusted.** `XSCHEM_SHAREDIR=<scratch>/work/src` with the
repo's own suite returns `RESULT: ALL PASS (653 checks)` — byte-for-byte the verdict of the plain
in-tree run. An arm that could not reproduce the baseline would prove nothing about a mutation.

⚠ **One methodological failure of mine, recorded because it nearly produced a false finding.** My
first C2 arm ran a modified copy of the suite from a scratch directory. `scratch.tcl:43` computes the
repo home as `[file dirname [info script]] .. ..`, so a suite run from outside a checkout resolves
its fixtures **outside the repo** — and the run reddened `GN7`, `SP6`, `SP14/apt` and `SP14/fork`,
four rows with nothing to do with the gesture. **That looked exactly like a real finding and was an
artefact of where I put the file.** Rebuilt inside a full tree (which is why the pristine arm, run
from `<scratch>/pristine/tests/headless/`, worked first time) it reddens nothing but `G2sens`. The
lesson is the brief's own: a sabotage that reds a row it was not aiming at is an invalid arm, and the
first suspect is the harness, not the code.

---

## Claim 1 — "THE DECK IS BYTE-IDENTICAL TO 252fee2d, 89/89 lines" → **CONFIRMED**

Derived my own way and never by the crew's script.

**My enumeration is a registry walk, not a hand-listed set of types.** For every simulator, every
analysis type and every field, print the declared `values`/`default`; then build the **cross product**
of every value of every value-bearing field, and for each resulting row print `ase::analysis_line` and
`ase::analysis_emit_check`. Run against `<scratch>/work/src` and `<scratch>/pristine/src`.

**Result: the emitted surface is identical.** The only two differing lines in the raw capture are the
startup banners naming the sharedir path, which are environment, not content. Stripping to the
content rows (`REG`/`LINE`), both files are **`f6c3a33cc36bc23e3eba1ca90a1c82ee`, 32 lines**.

**Coverage, measured rather than assumed — this is what stops the probe being vacuous:**

* `namespace children ::ase::backend` → **`::ase::backend::ngspice` and nothing else.** There is
  exactly one backend, so walking ngspice is walking the whole registry.
* **8 value-bearing fields exist** and my probe printed a `REG` row for all 8: `ac.sweep`,
  `noise.sweep`, `pz.transfer`, `pz.mode`, `sens.mode`, `sens.sweep`, `disto.sweep`, `sp.sweep`.
* 10 analysis types walked (`op dc ac tran noise tf pz sens disto sp`; `pss` declares no fields).
* The `LINE` rows are non-vacuous and carry real deck text — all 6 `pz` combinations
  (`pz in 0 out 0 vol pz` … `pz in 0 out 0 cur zer`), both `sens` rows (`sens v(out) dc`,
  `sens v(out) ac dec 1 1 1`), and all three sweeps on each of `ac`/`disto`/`noise`/`sp`.
* **`grep -c 'Voltage\|Current\|Poles\|Zeroes\|PZ \|DC\|AC'` over the emitted surface returns `0`.**
  No display word reaches the deck.

⚠ **SCOPE THE CLAIM HONESTLY — IT IS A SCHEMA-LEVEL CLAIM.** This diff, and the crew's 89-line one,
exercise `ase::analysis_line` on constructed rows. **Neither touches `ase::ui::form_get`**, which is
where a display word would actually enter a row. The GUI write path is pinned by `G2pz`/`G2a2`, not
by this diff, and the S5 arm below is what demonstrates it. The claim is true as stated; it is
narrower than "the deck cannot break".

## Claim 2 — "`PZ2f` carries a non-vacuity half on purpose" → **CONFIRMED**

Tested by construction, not by reading the row. Arm **NOMAP**: the three `valuelabels` declarations
deleted from `ase.tcl`, readers left in place — i.e. a tree in which the mapping does not exist.

**Diff guard: 3 lines removed, 0 added** (`diff | grep -c '^<'` = 3, `'^>'` = 0). Not an md5 check.

`RESULT: 1 FAILED (652 passed)` — **`PZ2f` reds, alone.** And the actual value is the proof the row is
built the way it claims:

```
actual {{vol cur} {pz pol zer} {dc ac} zer Zeroes nosuchlabel {bare same bare same bare same bare same} {}}
exp    {{Voltage Current} {PZ Poles Zeroes} {DC AC} Zeroes zer nosuchlabel {bare same bare same bare same bare same} {}}
```

The sweeps-unlabelled term (`bare same …`) **matched** and the round-trip term (`{}`) **matched** —
exactly the trivial satisfaction the row's header warns about. Only the non-vacuity terms caught it.
The row is what the receipt says it is.

## The `dec`/`oct`/`lin` exception is really pinned → **CONFIRMED**

Arm **S4**, the user ruling reversed: `ac`'s sweep gains `valuelabels {dec Decade oct Octave lin Linear}`.

**Diff guard: 0 removed, 1 added.** Target confirmed functionally, not by reading a line number — the
probe reports `ac.sweep has valuelabels? = 1` and `value_labels(ac.sweep) = Decade Octave Linear`
under S4, and `0` / `dec oct lin` on the working tree.

* `test_ase_core` → `RESULT: 1 FAILED (652 passed)`, **`PZ2f` by name**.
* `test_ase_dialogs` display → `4 FAILED (383 passed)`: **`G2e` ×2 and `G2g`**, plus the pre-existing
  `G2sens`. Re-run **alone** on the display and reproduced identically.

⚠ **And the arm exposes *why* the exception is load-bearing beyond copy.** `ac.sweep` declares
`relabels points` (`ase.tcl:26923-26924`). `form_get`'s value feeds `form_label`, so a labelled sweep
does not merely change a picker's words — it feeds `Decade` where `labels {dec {Points per decade} …}`
expects `dec`, and the neighbouring label breaks. That is precisely what `G2e`'s
`a bench with no stored sweep key shows the default the deck emits -> {Decade} (exp {dec})` is
reporting. A later "consistency pass" here would break a label, not just reverse a ruling.

## Correction C2 — "the old `G2pz` gesture was passing by accident" → **CONFIRMED**

Two arms, opposite directions.

* **Old gesture, map live.** Working sources, suite identical to the tree except the two gesture lines
  reverted to `set pol` / `set cur` (**diff guard: 2 removed, 2 added**), run inside a full tree:
  `RESULT: 1 FAILED (386 passed)` — **`G2sens` only. `G2pz` passes.** The deck word goes straight
  through `field_label_value`'s identity fallback and the row proves nothing, exactly as C2 says.
* **New gesture, map removed.** Arm **S5** below reds `G2pz` twice. So the moved gesture is what turned
  the row into a write-direction proof.

The new gesture also demonstrably exercises the read direction: running the **pristine** suite against
**working** sources reds `G2pz` with `actual {Voltage PZ {Voltage Current} {PZ Poles Zeroes} …}` against
the old golden — the change is observable at the widget, not only in the descriptor.

## S5 — the arm that matters → **PARTLY: the containment holds, the blast radius is UNDER-REPORTED**

Arm **S5**: `form_get` loses the display→deck map. Implemented as the minimal one-line form —
`if {$_t eq {}} { return $_v }` → `return $_v` — so the proc always returns the raw display word.
**Diff guard: 1 removed, 1 added; `ase.tcl` md5 unchanged from the working tree.**

**Confirmed:** `test_ase_core` stays **`ALL PASS (653 checks)`**. The widget-only containment the
design claims is real.

**Refuted:** the receipt says *"its blast radius is exactly the two widget rows"* and its table lists
`G2pz` `G2a2`. Measured: `RESULT: 6 FAILED (381 passed)` — **five newly-red rows**, not two, in three
row-name families:

| row | actual under S5 |
|---|---|
| `G2pz` (round-trip) | `{pz in 0 out 0 Voltage PZ}` |
| `G2pz` (pick) | `{pz in 0 out 0 Current Poles}` |
| `G2a2` | `{Current Poles Current Poles {pz in 0 out 0 Current Poles}}` |
| **`G2sens`** (round-trip) | **`{sens v(D) DC}`** |
| **`G2sens`** (filters) | **`{sens v(D) r*:r m*:vth0 DC}`** |
| `G2sens` (field build) | pre-existing, issue 1436 |

The two extra `G2sens` rows are **on-topic, not noise**: `sens.mode` is a ruled field (`R9-053`), so
`DC` leaks into `sens v(D) DC` exactly as `Voltage` leaks into the `pz` line. This is an error **in
the safe direction** — the guard is wider than claimed, not narrower — but the receipt's S-table is
inaccurate and the driver should not quote "exactly two widget rows" forward.

## Suite numbers, both arms, run by me → **CONFIRMED**

| run | verdict |
|---|---|
| `test_ase_core` headless, working | `ALL PASS (653 checks)` |
| `test_ase_core` display `:99`, working | `ALL PASS (653 checks)` |
| `test_ase_core` headless via `XSCHEM_SHAREDIR=work/src` | `ALL PASS (653 checks)` (method control) |
| `test_ase_dialogs` headless, working | `ALL PASS (37 checks)` |
| `test_ase_dialogs` display `:99`, working | `1 FAILED (386 passed)` — `G2sens` only |
| `test_ase_dialogs` display `:99`, **true pristine** (pristine src + pristine suite) | `1 FAILED (385 passed)` — **`G2sens` only** |
| `test_ase_trnoise_1466` headless | `ALL PASS (80 checks)` |
| `test_ase_trnoise_gui_1467` display `:99` | `ALL PASS (63 checks)` |

**`G2sens` is genuinely pre-existing**, established by *running* the pristine state rather than by
reading the receipt: the fully pristine display run reds `G2sens` and nothing else, with the identical
actual value `{1 1 0 1 0 Entry Entry normal}`. Issue 1436, not A2's.

**Floors raised in each file's own paragraph, confirmed in the source:** `test_ase_core.tcl:177`
`AND RAISED 652 -> 653`; `test_ase_dialogs.tcl:208` `37 / 386  AND RAISED 385 -> 386`.

Arithmetic note for a future reader: the display suite has **387 rows** after (386 pass + 1 `G2sens`)
and **386 before** (385 + 1). The receipt's "385 → 386" counts *passed*, not rows.

## "No handle was added; the count stays 728" → **CONFIRMED**

* `grep -c '^\*\*R9-'` — **727** on the working tree, **727** at `252fee2d`. Distinct handles **726**
  on both. Unmoved.
* Every new user-visible word **replaces** a handled string in its existing slot: `R9-046` `vol`→
  `Voltage`, `R9-047` `cur`→`Current`, `R9-048` `pz`→`PZ`, `R9-049` `pol`→`Poles`, `R9-050` `zer`→
  `Zeroes`, `R9-053` `dc ac`→`DC AC`. `R9-054` unchanged.
* **I looked for a new unhandled string and found none.** The diff adds no `-text`, no message and no
  label literal; the only new strings in `src/` are the three `valuelabels` dicts, all of which land
  in already-handled picker slots. This is the check A1's crew got wrong, so it was run directly
  against the diff rather than inferred.

## "The `nz_*` trio became wrappers — one body, not two" → **CONFIRMED**

* Exactly one body each: `ase.tcl:4895` `field_value_label`, `:4901` `field_label_value`, `:4909`
  `field_value_labels`.
* `ase_window.tcl:6247-6249` are three one-line delegations and contain no logic.
* `dict exists … valuelabels` appears **only** in `ase.tcl`'s reader bodies. No surviving second
  implementation anywhere in `src/*.tcl`.
* No hardcoded `vol → Voltage`-style table outside the registry declarations.
* Regression cover run by me: `test_ase_trnoise_1466` **80 ALL PASS**, `test_ase_trnoise_gui_1467`
  **63 ALL PASS**.

## `Zeroes` vs `Zeros` → **CONFIRMED in substance, the count is off**

* **`PLAN.md:2226` really does propose `label {Poles and zeros}`** for this very analysis. Confirmed
  verbatim. (`PLAN.md:2295` also says *"Poles and zeros arrive as a sortable table"*.)
* The tree spells the plural noun `zeros`. **Measured: 15 occurrences on 15 lines across 5 files** —
  `src/ase.tcl` 8, `src/op_annot.tcl` 3, `src/save.c` 2, `src/callback.c` 1, `src/token.c` 1. The
  receipt says *"twelve in `src/`"*; **I cannot reproduce twelve** by any grouping I tried (15 all
  files, 11 lines in `src/*.tcl`, 8 in `ase.tcl`). The direction of the finding is unaffected.
* `zeroes` in `src/` is **only ever the verb** (*"unselect_all(1) zeroes ui_state"*). Confirmed.
* **`Zeroes` capitalised appears exactly once in all of `src/`** — `ase.tcl:27007`, the new picker
  label. So nothing on screen is contradicted today, as the receipt says.

**This is the user's to settle, not the driver's and not mine.** Shipped as ruled.

## Sabotage arms redone independently — 4 arms, every guard a counted diff

| arm | mutation | diff guard | reds |
|---|---|---|---|
| **NOMAP** | the three `valuelabels` declarations deleted | **3 removed / 0 added** | `PZ2f` alone; core `1 FAILED (652 passed)` |
| **S4** | the user exception reversed — `ac.sweep` gains labels | **0 removed / 1 added** | core: `PZ2f` alone. display: `G2e` ×2, `G2g` (+ pre-existing `G2sens`) |
| **S5** | `form_get` loses the display→deck map | **1 removed / 1 added**, `ase.tcl` md5 unchanged | display: `G2pz` ×2, `G2a2`, **`G2sens` ×2** (+ pre-existing). core: **`ALL PASS (653)`** |
| **C2** (control) | suite only — gesture reverted to the deck words | **2 removed / 2 added** | **nothing but `G2sens`** — the old gesture proves nothing |

**No arm reddened a row it was not aiming at**, once the harness error described above was corrected.
The guard is the line count in every case; **no md5 was used as a sabotage guard**, per the brief.

---

## ⚠ FINDINGS THE DRIVER MUST SEE

1. **`CLAUDE.md` is modified in the working tree and it is NOT part of A2.** It was **not** modified
   at the start of this pass (the session-opening `git status` lists only `R9_COPY_REVIEW.md`,
   `src/ase.tcl`, `src/ase_window.tcl` and the two suites). It appeared at **2026-09-16 07:46:41**,
   mid-verification, 30 insertions / 9 deletions, entirely about the `owed.sh` ledger stamping rules —
   **another session is live in this repo.** I did not touch it and did not revert it. **A `git commit
   -a` would sweep it into the A2 commit.** Stage the A2 files explicitly.
2. **Receipt 53's S5 blast radius is wrong** — five newly-red rows, not two; it omits two `G2sens`
   rows that S5 genuinely breaks. Safe direction, but do not carry "exactly two widget rows" forward.
3. **Receipt 53's "twelve `zeros` in `src/`" does not reproduce** — I measure 15. The finding it
   supports is unaffected and still stands.
4. **The `Zeroes`/`Zeros` collision is real and is the user's call**, not the driver's: `PLAN.md:2226`
   already proposes `Poles and zeros` for this same analysis.

## Disclosures

* **No simulation was launched by me and `/usr/bin/ngspice` was never invoked directly.** But it must
  be said plainly: `test_ase_dialogs`' **display arm runs a simulator of its own accord** — rows
  `SP14/apt` and `SP14/fork` are *"the deck that table wrote really runs"*, and they pass on the
  baseline. I ran that suite the same way receipt 53 did; I did not add a simulation to it, and no
  deck was written under `sky130A/`.
* **The `ase::analysis_emit_check` gap the receipt reports as "found and not fixed" is real**, verified
  directly: `{type pz … transfer Voltage mode PZ}` returns an **empty** (clean) verdict and renders
  `pz in 0 out 0 Voltage PZ`; `{type sens … mode DC}` renders `sens v(out) DC`; even
  `transfer nonsense mode alsononsense` passes. A display word in a row reaches the deck verbatim at
  rc 0. Pre-existing (issue 1416's allow-list), not introduced by A2, and not reachable through the
  GUI because `form_get` maps back — which is exactly why S5 is the arm that matters.
* **Every command carried a `timeout`.** No command was left unbounded, no waiting loop was used, and
  no run ended without a named verdict.
* Binary always by path (`./src/xschem`, `devdisplay.sh exec ./src/xschem`), always `--nolog`, never
  `--logdir`, never a bare `xschem`.
* Display arm is **`:99`** (Xvfb, **openbox 3.6.1**, `1920x1080x24`), `devdisplay.sh status` = alive.
  No `:0` and no `$DISPLAY` run was taken; **no pixel deliverable is claimed** and no `look` debt is
  discharged by anything here.
* Processes matched by **name** (`ps -eo pid,lstart,comm=`), never `pgrep -f`. **No `pkill`.** Alive
  and not mine: `Xvfb` pid 1116 (Sep 15 08:09:29) and two `xschem` pids 807232 / 809774 (Sep 15
  22:42:28 / 22:46:56) — the same pids receipts 52, 52b and 53 name. **No `ngspice` process alive at
  the end.** No background process of mine is running.
* **`tests/run_regression.tcl` was NOT run** — the driver's, solo (issue 0990).
* Scratch trees, mutations and all logs live under the session scratchpad
  (`…/scratchpad/v53b/`), never in the repo. Nothing there needs restoring because nothing in the
  repo was ever changed.
