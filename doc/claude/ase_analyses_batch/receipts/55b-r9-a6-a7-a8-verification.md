# 55b — adversarial verification of ⚖ R9 rulings A6, A7 and A8 (receipt 55)

**Role:** adversarial verifier. Brief: disbelieve `55-r9-a6-a7-a8-sentences.md`, re-derive its claims
independently, and report what is actually true. **No source file was changed.**

**Tree state.** HEAD `e6b69b39` at start and at end. `git status` carries the identical seven modified
paths and five untracked paths it carried at the start, plus this receipt. No `git checkout --`,
`restore`, `stash`, `clean`, `add`, `commit` or `push` at any point.
`doc/claude/ase_analyses_batch/LEDGER.md` is the driver's; I never opened it.

| file | md5, start and end |
|---|---|
| `src/ase.tcl` | `5aaadb746e67dd86cd5f12b355830162` |
| `src/ase_window.tcl` | `80931d3d572f682c28e836cce76bb309` |
| `tests/headless/test_ase_core.tcl` | `93e12bd3172e4988c18aaf2aa2143bba` |
| `tests/headless/test_ase_preflight.tcl` | `8aee4879a1a446acb5a1543be5967970` |
| `tests/headless/test_ase_dialogs.tcl` | `f34d54332adef12a6c448590b1423416` |
| `tests/headless/test_ase_trnoise_1466.tcl` | `b71dd1819860cb1b29ea13cd342b27c0` |

`~/.xschem/recent_files` **untouched at 2026-09-13 18:53:01** (issue 0924 canary), start and end.
`owed.sh count` **187 rule, 71 look, 11 suite** — the shared ledger was never written.
**`/usr/bin/ngspice` was never invoked by me**, no simulation was started by me, no deck was written
under `sky130A/`. `tests/run_regression.tcl` **NOT run** — the driver's, solo (issue 0990).

---

## ⚠ THE METHOD

Every mutation was built in a **scratch tree**, never in the repo. `git archive e6b69b39 | tar -x`
yields `pristine/`; `pristine` + the five working files copied over it yields `work/`; `mut/` and
`mutd/` are further copies differing from `work/` by a **counted** number of lines.
`XSCHEM_SHAREDIR` points the repo's own binary at the scratch `src/`, and each suite is run from
that tree's own `tests/headless/` (53b's recorded trap: `scratch.tcl` resolves the repo home from
`[info script]`). Each scratch tree was given a git index (`git init && git add -A`, 104 `.state`
paths in each) — 54b's recorded addition, because `CP7` and `state_roundtrip.tcl` shell out to
`git ls-files`.

**The method was validated before it was trusted**, and the controls are positive assertions rather
than absence of FAIL:

| control | verdict |
|---|---|
| `work/src` via `XSCHEM_SHAREDIR`, `test_ase_core` headless | `ALL PASS (669 checks)` — equals the plain in-tree run |
| `pristine/src`, `test_ase_core` / `test_ase_preflight` | `ALL PASS (662)` / `ALL PASS (238)` — the pre-change floors |
| the red-extractor fed the **empty** case | `EMPTY → DIED(no RESULT line)`, `NORESULT → DIED(no RESULT line)` |

⚠ **A FOURTH TREE, AND IT IS THE STRONGEST SINGLE INSTRUMENT HERE.** `xsrc/` is **work `src/` plus
PRISTINE suites**. If A7 and A8 really change no rendered text, the pre-change suites must still pass
against the post-change source *except* on rows that assert a deliberate A6/A8 **copy** change. That
converts "byte-identical" from an assertion into an enumeration, and it is derived from the shipped
code rather than from the crew's `verify.tcl`, which I never ran.

---

## Claim 1 — "a green dialogs arm may be consistent with those rows being unable to witness A7" → **REFUTED: they cannot witness it**

This is the claim the crew was honest about and explicitly did not resolve. Resolved here, and the
answer is the pessimistic branch.

**Arm, on `mutd/`:** `ase::analysis_refusal_frames`' status line made to render **different text** —
`status "This $type analysis $clause."` → `status "ZZZ $type analysis $clause"` (different lead,
full stop removed). **Counted diff 1 removed / 1 added on `src/ase.tcl`, 0 lines elsewhere.**

| suite | arm | verdict |
|---|---|---|
| `test_ase_dialogs` | headless | **`ALL PASS (37 checks)`** — unmoved |
| `test_ase_dialogs` | display `:99` | **`1 FAILED (387 passed)`** — **`G2sens` only, i.e. unmoved** |
| `test_ase_core` | headless | `1 FAILED (668 passed)` — **`SN4` alone** (positive control) |

`SN4` reddening proves the mutation is live and reachable; the dialogs suite is byte-for-byte at its
baseline on both arms with the status sentence visibly wrecked. **No `test_ase_dialogs` row —
`G2f`, `G2tf`, `G2pz` included — can witness a change to the A7 status line.** So **"37 / 387 green"
is no evidence for A7 at all**, and the receipt's suite-table row must not be carried forward as
cover. Same shape as 54b's `test_ase_meas_1443` refutation. The crew's refusal to claim it was
correct; the hedge is now a measurement.

## Claim 2 — the second sabotage campaign is valid → **CONFIRMED for S1, S6, S7, S8; PARTLY for S4**

Five arms redone by me from scratch, on `mut/`. Each arm: restore from `work/` with plain `cp` →
locate the target by an **exact** needle that `plant.py` requires to occur **exactly once** or the
arm aborts → plant → `diff -u` against `work/` and count changed lines against the number intended →
run → restore → **md5 equality with `work/` asserted**. ⚠ **No md5 was used as a sabotage guard.**

| arm | mutation | counted diff | reds I measured | receipt's declared set |
|---|---|---|---|---|
| **S1** | `R9-077` says `backend` again | −1/+1 `ase.tcl` | core **`SN1` `D7b` `D7e4`** · preflight **`PF222b` `PF222e`** · trnoise ALL PASS | identical ✓ |
| **S4** | A6's non-change reversed (`verbatim`→`inline` in `arg_summary`) | −1/+1 `ase_window.tcl` | core **`AC4` `SN3` `VB6`** | `SN3` `VB6` — **`AC4` not declared** |
| **S6** | A7 — `chana_ok` re-spells its own frame | −1/+1 `ase_window.tcl` | core **`SN5` ALONE** | identical ✓ |
| **S7** | A8 — the stop sentence loses its full stop | −1/+1 `ase.tcl` | core **`SN6` `SW2` `CK30` `CK30b` `CK33`** · trnoise **`NP7b`** | identical ✓ |
| **S8** | A8 — the gate re-spells its own tail | **−2/+3** `ase.tcl` | core **`SN7`** · preflight **`PF234b`** | `SN7`, `PF234b` ✓ (diff quoted −1/+2) |

**Campaign ends on a positive restored-tree row**, twice: `test_ase_core` **ALL PASS (669)**,
`test_ase_preflight` **ALL PASS (242)**, `test_ase_trnoise_1466` **ALL PASS (80)**, with both sources
md5-equal to `work/`.

⚠ **`AC4` is a real enumeration gap.** It asserts
`{tran 1n 10u  + verbatim: 1 line}` as one of three `arg_summary` goldens, so **any** rename of
`verbatim` in that column moves it. It is the same class of miss the crew self-reported for `CK33`
under S7 — and having reported one, it should have caught this one. Not a defect in the change; a
defect in the receipt's declared blast radius.

⚠ **The S8 diff difference is formatting, not a finding.** My restored literal is a three-line Tcl
continuation (−2/+3); the crew's was −1/+2. Both plant the same pristine sentence and both redden the
same two rows.

## Claim 3 — the structural claim, both halves → **CONFIRMED**

### (a) The rendered output really is byte-identical, derived two ways, neither of them `verify.tcl`

**First derivation — the six A7 strings, pristine against work.** For each of the three doors I took
the *shipped* frame: on `pristine/` by extracting the literal out of `info body` and `subst`-ing it
under the same bindings, on `work/` by calling `ase::analysis_refusal_frames`. All **six**
(log + status × `chana_ok` / `chana_x_add` / `chana_x_ok`) are **byte-equal**:

```
ase: enabled tran analysis needs a value for 'Stop time (s)'
This tran analysis needs a value for 'Stop time (s)'.
ase: this tran analysis has a setting named 'zz' that ASE-L cannot emit
This tran analysis has a setting named 'zz' that ASE-L cannot emit.
```

⚠ **My first extraction was wrong and I caught it rather than reporting it.** The regexp took the
*first* `::ase::echo` line in `chana_x_add`, which is `ase: option name must not be empty` — an
unrelated earlier refusal — and printed a spurious divergence. Anchoring the pattern on `analysis`
fixed it. A verifier's own instrument is as capable of a false positive as a crew's.

**Second derivation — `xsrc/`, the pristine suites against the post-change source.** Twelve reds,
and **every one of them is a deliberate copy change or the one structural row**:

| suite | verdict | reds |
|---|---|---|
| `test_ase_core` | `7 FAILED (655 passed)` | `D7b` `D7e4` `SW2` `AC5` `CK30` `CK30b` `CK33` |
| `test_ase_preflight` | `4 FAILED (234 passed)` | `PF222b` `PF222e` `PF228b` · **`PF234b`** (structural) |
| `test_ase_trnoise_1466` | `1 FAILED (79 passed)` | `NP7b` |

**Not one A7 frame sentence and not one gate-tail sentence moved.** `PF222c`/`PF222d`, which assert
fragments of the gate refusals as rendered text, passed against the refactored source. `VB4` passed —
its edit was to the row's *name*, which is what the receipt says. `D7c` passed (see claim 6).

### (b) Re-spelling a call site reddens exactly those rows and **nothing else in the repository**

S6 and S8 were each run across **eleven suite/arm combinations** — every ASE suite on both arms:

| | S6 | S8 |
|---|---|---|
| `test_ase_core` headless | **`SN5` alone** (668 passed) | **`SN7` alone** (668 passed) |
| `test_ase_preflight` headless | ALL PASS (242) | **`PF234b` alone** (241 passed) |
| `test_ase_trnoise_1466` / `test_ase_window` / `test_ase_meas_1443` / `test_ase_simreg_0931` headless | ALL PASS 80 / 56 / 113 / 118 | same |
| `test_ase_dialogs` headless / display | ALL PASS 37 / `G2sens` only | same |
| `test_ase_optsheet_1441` headless / display | ALL PASS 64 / 89 | same |
| `test_ase_trnoise_gui_1467` display | ALL PASS (63) | same |

**`SN5`, `SN7` and `PF234b` are the only guards anywhere in this repository**, and the receipt's
claim is exact rather than overstated. Corroborated statically: `rg_body`/`info body` over
`chana_ok`, `chana_x_add`, `chana_x_ok`, `preflight_gate`, `preflight_refusal` and
`analysis_refusal_frames` appears in **`test_ase_core.tcl` and `test_ase_preflight.tcl` only**.

⚠ **And one result decides the byte-identity question on its own: `PF235d` stayed GREEN under S8.**
That row drives the real `ase::preflight_gate` end to end and asserts its two refusal sentences.
With the composed tail replaced by the hand-written pristine literal, it did not move — so the two
render **byte-identically**, measured through the gate rather than through the composer.

## Claim 4 — "three A7 sites, not two" → **CONFIRMED, and there is no fourth**

Established by grepping the **pristine** tree for the *shape*, not for names. The two-channel
signature is a `::ase::echo "ase: <verb> $… analysis …"` log literal paired with a
`"This $… analysis ….”` status literal. Exactly three pairs exist, all in `ase_window.tcl`:
`5913`/`5918` (`ase::ui::chana_ok`), `6985`/`6987` (`ase::ui::chana_x_add`), `7073`/`7075`
(`ase::ui::chana_x_ok`).

Widened twice to look for a fourth: **every** literal beginning `"This ` across `src/*.tcl`
(26 hits — the rest are CIW advice, balloons, comments and `ase_window.tcl:7152`'s
`This schematic offers no more …`, none of them a two-channel refusal) and **every** literal
beginning `"ase: (enabled|this|the) ` (13 hits). **No fourth site.** The two nearest neighbours,
`ase.tcl` pristine `14165` `ase: the $pty analysis cannot run: …` and `14200` `ase: the $pty
analysis: …`, are precheck **log-only** lines with no paired status line — a different family, and
correctly out of A7's scope. `ase::ui::chana_options` holds no frame, as the crew's correction says.

## Claim 5 — the gate pair's two leads genuinely differ → **CONFIRMED (one half not reproduced)**

Reproduced independently on this tree's own binary, no simulator started:

```
emit_order incomplete : 0 <<{0 0 op} {30 1 tran}>>                        <- returns NORMALLY
emit_order unrend     : 1 <<ase: analysis type 'pss' is not one this simulator can render>>  <- RAISES
```

The asymmetry the ruling rests on is real: the two arms fail the deck writer at different points, so
*"completed, produced no result for it, and said nothing"* is true of one and would be false of its
near-twin. **The preserved difference is a real difference**, and flattening it would have made a
sentence false — which §A8 ranks as worse than the drift.

⚠ **I did NOT reproduce the second half of the crew's quoted probe.** Its
`INCOMPLETE render rc=1 err=<<key "stop" not known in dictionary>>` needs a state carrying a design
cell; my minimal fixture failed earlier, at `ase: state design has no cell (plotmap_path)`, for
**both** arms. That is a limitation of my fixture, not a refutation — the `emit_order` measurement
is the one the ruling and the source comment turn on, and it reproduces exactly.

## Claim 6 — `D7c` cannot witness a copy change → **CONFIRMED**

`D7c` asserts `[ase::analysis_unrenderable_msg pss] eq $d7err`, and `$d7err` is the message that
proc mints, propagated out of `render_deck`. Both sides move together under any rewording.
**Two independent demonstrations:** under **S1**, which reverts that exact sentence, the core red set
is `SN1 D7b D7e4` with **`D7c` green**; and in the `xsrc` run, where the sentence moved under the
row's feet, `D7c` again stayed green while `D7b`/`D7e4` reddened. It is a **self-consistency** row,
and `D7b`/`D7e4`/`SN1` are what pin the words.

⚠ **A small internal inconsistency in the receipt.** Its suite table lists `D7c` among the nine
core rows that *"moved, not gained"*. It did not move: its golden is unchanged in the diff and it
**cannot** move. The receipt's own later paragraph gets this right; the table should be corrected
to eight.

## Claim 7 — A6's protected non-change → **CONFIRMED, and not reversed**

| | pristine | work |
|---|---|---|
| `ase_window.tcl:1650` | `set vb "  + verbatim: 1 line"` | **identical** |
| `ase_window.tcl:1652` | `set vb "  + verbatim: $nvb lines"` | **identical** |
| rendered `arg_summary` | `tran 1n 10u  + verbatim: 1 line` / `2 lines` | **identical**, on both scratch trees and on the real repo |
| `R9-080` (`ase.tcl:5483`) | `has verbatim lines that are not a readable list of non-blank lines` | `has verbatim lines ASE-L cannot read, or a blank one among them` |

The ruled non-change (`R9-157`/`R9-158`) is byte-identical; the ruled change (`R9-080`) is a
**different string** that legitimately keeps the word `verbatim` and lost only its Tcl vocabulary.
**Not backwards.** `SN3` is the only record of the non-change, and S4 proves it load-bearing.

## Suites, both arms, run by me → **CONFIRMED**

| run | verdict |
|---|---|
| `test_ase_core` headless / display `:99`, working tree | **`ALL PASS (669 checks)`** / **`ALL PASS (669)`** |
| `test_ase_preflight` headless / display | **`ALL PASS (242)`** / **`ALL PASS (242)`** |
| `test_ase_dialogs` headless | **`ALL PASS (37 checks)`** |
| `test_ase_dialogs` display `:99` | **`1 FAILED (387 passed)`** — `G2sens` only |
| `test_ase_dialogs` display, **true pristine** (pristine src **and** pristine suite) | **`1 FAILED (387 passed)`** — **`G2sens` only** |
| `test_ase_trnoise_1466` / `test_ase_window` / `test_ase_meas_1443` headless | ALL PASS 80 / 56 / 113 |
| `test_ase_optsheet_1441` headless / display | ALL PASS 64 / 89 |
| `test_ase_simreg_0931` headless · `test_ase_trnoise_gui_1467` display | ALL PASS 118 · 63 |
| `test_ase_core` / `test_ase_preflight` **pristine** headless | `ALL PASS (662)` / `ALL PASS (238)` |

**`G2sens` is genuinely pre-existing**, established by *running* a true-pristine tree, not by reading
the assertion: the same row, the same actual `{1 1 0 1 0 Entry Entry normal}` against
`{1 1 0 0 0 Entry Entry normal}`, and nothing else red. Issue **1436**. The suite file is
md5-identical (`f34d5433…`) on both trees — the crew never touched it. T1 runs this file on neither
arm. The pristine floors (662 / 238) match the receipt's "before" column exactly.

**Floors confirmed in the source, each in its own paragraph:** `test_ase_core.tcl:216`
`AND RAISED 662 -> 669`; `test_ase_preflight.tcl:170` `AND RAISED 238 -> 242`.

## `.state` byte identity → **CONFIRMED**

Driven as a **proc**, `ase_state_roundtrip $repo`, never by running the script — against the scratch
trees **and** against the real repository:

```
tracked 104   bad {}   control_disagrees 1   control_agrees 1
```

All four reported, **both controls live**.

## Bookkeeping → **CONFIRMED**

* Header line 14 reads `**730 strings, from 38 issues…**` at **`e6b69b39` and on the worktree** — unmoved.
* `grep -c '^\*\*R9-'` = **727** both; distinct anchored handles = **726** both.
* **I minted no handle and ruled on no copy.**

**New user-visible copy with no handle: none added.** Every changed string is a reworded existing
handle. ⚠ But `R9-080`'s new wording is substantially new sentence text, the crew flagged it upward
rather than deciding it, and **no `owed.sh add rule` was filed** — see the findings below.

## `CK33` → **CONFIRMED**

It compares against `[list $CK30CK $CK30UN $CK30UN]` — the very variables edited for `CK30` — so it
moves by **variable reference** and needed no edit of its own. The arm that surfaced it (S7) is
valid: the aimed-at row `SN6` did redden, alongside `SW2`, `CK30`, `CK30b` and trnoise `NP7b`.

## The four "found and not fixed" → **CONFIRMED, all four**

1. **`ase::analysis_gap_msg`** renders (not read — rendered by me)
   `ASE-L does not know a simulator backend called 'nosuchsim'. Registered: ngspice.` at
   `ase.tcl:10608`. It is anchored by **no `**R9-nnn**` handle** and is **outside §A6's
   three-handle table**. Correctly reported rather than tidied. **The driver's to raise with the user.**
2. **`R9-121`** untouched at `ase.tcl:12792` — `write it as \`v(out)\` or \`v(out,ref)\``.
3. **`sens_filters`** untouched at `ase.tcl:12758` — `name a device this netlist has at the top level …`.
4. **`R9-262`** untouched at `ase.tcl:17293` — sentence-initial capital `Stopping` retained.

The node-naming family really did converge: `ase.tcl` `12381`, `12483`, `12680`, `12812` all read
`name a node that is in the circuit`, and `12787` reads
`name a node that is in the circuit, as \`v(out)\` or \`v(out,ref)\`` — the example moved, not deleted.

---

## ⚠ FINDINGS THE DRIVER MUST SEE

1. **`test_ase_dialogs` cannot witness an A7 change** — proven by wrecking the status sentence and
   watching both dialogs arms sit at baseline while `SN4` reddened. The receipt's suite-table row
   for dialogs must not be carried forward as A7 cover. **The refactor is still correct** — claim 3
   establishes that independently — but its cover is `SN4`/`SN5` and nothing else.
2. **S4's declared red set omits `AC4`.** `AC4` asserts `{tran 1n 10u  + verbatim: 1 line}` and moves
   with any rename in that column. Same class as the `CK33` miss the crew did disclose.
3. **The receipt lists `D7c` as "moved"; it is unmoved and unmovable.** Nine should be eight. The
   receipt's own later finding about `D7c` is correct and contradicts its table.
4. **`R9-080`'s new wording carries no `rule` debt.** The crew flagged it upward deliberately and did
   not write the shared cross-clone ledger. It is substantially new copy on an existing handle, and
   §A6 ruled *"plain English"* without writing the sentence. **Decide before committing:** file
   `owed.sh add rule` against it, or record explicitly that ⚖ R9 itself collects it.
5. **`ase::analysis_gap_msg` is genuinely outside the ruling and genuinely says `backend`.** The
   driver's to raise.
6. **I could not reproduce the `analysis_line` half of the crew's gate probe** — a fixture limitation
   on my side (no design cell), not a refutation. The `emit_order` asymmetry, which is what the
   source comment and the ruling rest on, reproduces exactly.
7. **Everything else the receipt claims, I reproduced**, reading the `✅ RULED BY THE USER` blocks in
   `R9_COPY_REVIEW.md` §A6/§A7/§A8 as the authority rather than the receipt's paraphrase — including
   A6's protected `verbatim`, A7's three sites and two kept verbs, and A8's deliberately unflattened
   leads and its kept `v(out,ref)` example.

## Disclosures

* **No simulation was launched by me and `/usr/bin/ngspice` was never invoked.** As 53b and 54b
  recorded, `test_ase_dialogs`' display arm starts a simulator of its own accord; I ran that suite
  the way receipts 54 and 54b did, added no simulation to it, and wrote no deck under `sky130A/`.
* **Every command carried a `timeout`.** No background command was left running, no waiting loop was
  used, every run was polled in the foreground and ended in a named verdict
  (`PASS` / `FAIL` / `DIED`). **I never ended a turn waiting to be woken.**
* **Binary always by path** (`./src/xschem`, `devdisplay.sh exec ./src/xschem`), always `--nolog`,
  never `--logdir`, never a bare `xschem`.
* Display arm is **`:99`** (Xvfb, **openbox 3.6.1**, `1920x1080x24`, `devdisplay.sh status` = alive).
  **No `:0` and no `$DISPLAY` run was taken; no pixel deliverable is claimed** and no `look` debt is
  discharged by anything here.
* Processes matched by **name** (`ps -eo comm=`), never `pgrep -f`, never `pkill`. Alive and not
  mine: **`Xvfb`** (the shared `:99` dev display) and **two `xschem`** processes that predate this
  session. **No `ngspice` process at any point.**
* **Nothing in the repository was written except this receipt.** All scratch trees, mutations, probes
  and logs live under the session scratchpad (`…/scratchpad/v55/`): `pristine/`, `work/`, `mut/`,
  `mutd/`, `xsrc/`. **None of them is a restore snapshot** — my `restore` copies `work/`→`mut/` only
  and no script of mine writes into the repo — but `plant.py` was renamed `plant.py.disarmed` and the
  arm needles moved to `ARCHIVED_DO_NOT_RESTORE/` on stand-down anyway. **Campaign logs are kept**
  beside them as this receipt's evidence.
* One temporary probe file was copied into `tests/headless/` to measure the real repo's `.state`
  round trip and **deleted immediately**; `git status` is unchanged and the directory carries no
  `probe55_tmp.tcl`.
* **`tests/run_regression.tcl` was NOT run** — the driver's, solo (issue 0990).
