# Batch F item 03 — open decision 5: who owns the instance↔VCD-scope mapping

**DOC-ONLY.** No `.c`, no `.tcl`, no test file, no build, no audit. Two rounds: the ruling, then a
fix round closing seven confirmed review findings, two of which broke the ruling's own sentences
against a live fixture. The **operative** ruling survived (key on the cell, refuse rather than
guess, derive the scope); two of its justifications and one advertised benefit did not.

## 1. Files changed

* `doc/claude/specs/mixed_signal_signal_browser.md` — `272 +++-`, **263 insertions, 9 deletions**
* `doc/claude/issues/0307-…-a-buried-code-block-has-no-cell.md` — **NEW**, 119 lines
* `doc/claude/batch_F/receipts/03-open-decision-5-…-ownership.md` — **NEW** (this file)

`git status --porcelain src/ tests/` is **empty** — no source or test file was touched. Spec
edits: the new "Open decision 5, ruled" section (:765ff), decision 5 struck through (:759),
cross-references at §F's F2 row (:655) and in §E, and four stale citations fixed (:77, :591,
:641, :645 → `src/ase.tcl:2079` / `:2113-2124` / `:2183`, `src/scheduler.c:6458-6472`).

## 2. Decisions taken, and the evidence for each

All rulings live in `doc/claude/specs/mixed_signal_signal_browser.md` §**"Open decision 5,
ruled"** (:765ff), which §F's F2 row now names as F2's contract.

* **RULING 5a — the mapping is THREE facts with three owners, not one.** f1 (instance→cell) =
  QUERY time, live design; f2 (cell/model→VCD file, or none and why) = NETLIST/RUN time, the
  `<rundir>/<cell>_ase.cosim` artifact; f3 (file→scope) = DERIVED from the loaded DB. Evidence:
  f2 is unrecoverable elsewhere (the VCD does not name the `.model` card that wrote it; only the
  deck knows `trace 0`/`multi 1`, `src/ase.tcl:1092-1098`), while f3 is fixed by elaboration,
  *after* the artifact is written (§C). So netlist time owns f2 **and only f2**, and the
  convenient "the `.cosim` file exists, let it own the mapping" answer is rejected.
* **RULING 5b — the join key is the CELL (`lib/cell`), never the instance path.** Forced, not
  preferred: (a) the artifact holds no path today — `insts` is the deck's leaf `a…` token
  (`src/ase.tcl:887-892`), the design walk is flat (`src/scheduler.c:6458-6472`); (b) the
  *deciding* reason, added by review — a path would not be a key even if recorded, since one
  `.subckt` instantiated twice puts the same block at `x1.a1` and `x2.a1` (what `multi` records).
  Ladder `lib/cell` → `cell` → `module` (only when `vfile` non-empty) → the instance's own
  `model=` property; both operands named per rung; >1 → `ambiguous`, no fall-through.
* **RULING 5c — `scope` stays a HINT; the derived answer wins.** Explicitly consistent with item
  4's brief, not a change to it. Corrected by review: the hint is `TOP.<module>` from the `.v`
  **only when** the walk or sidecar supplied one — with `vfile` empty `src/ase.tcl:1086` falls
  back `module = model`, so it is `TOP.<.model card name>` and **not eligible**. Verify by a
  literal case-**sensitive** prefix test, never `get_raw_index()`: measured, it MISSES a
  mixed-case name (it does not over-accept) and cannot answer a scope prefix at all.
* **RULING 5d — the schematic prefix is DROPPED, not translated.** Measured on
  `~/.xschem/simulations/counter.vcd`: the tree is `TOP` (port mirror) then `TOP.counter`, no
  `x1` anywhere; `x1.a1` resolves to the absolute pair `(counter.vcd, "TOP.counter")`.
* **RULING 5e — refuse with a code naming which of f1/f2/f3 failed**; never fall back to `TOP`
  (its signals are the ones already in the analog raw) nor to "the current DB".
* **Both alternatives worked, with failure modes.** Load-time-only cannot answer *which
  database* and cannot see an interleaved `multi 1` file; query-time-only would have to guess
  the artifact path through `cosim_safe_name` folding (`src/ase.tcl:1105-1117`). The
  disagreement matrix is in the same section; its edited-`.v` row is marked "nobody wins".
* **Issue 0307 filed** — the buried block is a defect, not a design consequence:
  `ase::cosim_design_scan` is flat, so such a block gets `cell=''`, `vfile=''` and a fabricated
  `TOP.<cardname>` hint, and "works" today only if the card was named after the module.

### The measurements that changed the ruling

Fix round, live scratchpad fixture: the spec's own canonical `tbh → x1 (dig_top) → a1 (dcell)`,
real `xschem netlist`, then `cosim_scan_deck`/`_design_scan`/`_map` under `--nogui --pipe -q`.

```
instance_list on tbh: {x1} {dlib/dig_top} {subcircuit}   cosim_design_scan keys: <EMPTY>
entry: model='dcell' lib='' cell='' module='dcell' vfile='' insts='a1' scope='TOP.dcell'
card renamed cnt8:  entry model='cnt8' cell='' module='cnt8'   f1 says cell='dcell'
   -> old 3-rung ladder matches NOTHING; rung 4: getprop instance a1 model = 'cnt8' == entry
insts for a1 / a_cnt / u_cnt = 'a1' / 'a_cnt' / ''      (the `a` prefix is mandatory)
bare-cell key 'dcell' matches 2 entries; 'elib/dcell' matches 1  -> the ladder must carry lib
raw index 'TOP.counter.clk'->7   'top.counter.clk'/'TOP.COUNTER.CLK'->-1   'TOP.counter'->-1
```

## 3. Tests

**No new checks were written — this item ships no code.** `test_ase_cosim` (201 checks) was run
once in the fix round because the ruling asserts "no existing check changes expectation":
`DS13-scope-hint`, `REF10-map-scope`, `REF12-scope-hint-matches-the-real-vcd`
(`tests/headless/test_ase_cosim.tcl:466`, `:1100`, `:1106`) assert the *production* of the hint,
which the ruling leaves byte-identical. Verbatim, from `GUI_GATE=1
tests/headless/run_suites.sh --nogui test_ase_cosim`; **the closer did not re-run it** — the
item forbids suite runs and the tree has not changed since:

```
PASS     | test_ase_cosim               run 1/1  RESULT: ALL PASS (201 checks)
RESULT: 1/1 runs passed
```

Confirmation the tree is unchanged, **not evidence about this item** — no code changed.

## 4. Sabotage table

| check id | what was broken | went red? | restored green? |
|---|---|---|---|
| — | — | — | — |

**Zero new checks, therefore zero sabotages, and none is claimed** — no code under test to break.
Every check in `test_ase_cosim` is **unsabotaged by this item and is not evidence for it**. What
it carries instead is §2's probes — adversarial: two broke the ruling's own text.

## 5. What was NOT verified

* **NO AUDIT WAS RUN, and none should have been** — the item's guidance requires the skip, and
  `git` proves the change is two `.md` files, so `full_audit.sh` would have measured HEAD, not
  this item. `doc/claude/batch_F/baseline_status.txt` **exists** (11579 bytes, baseline
  `7a592f9c`) and was left **untouched and undiffed**; the audit diff is empty because no audit
  ran, **not** because nothing moved. No test status was measured in either direction.
* **Raised but NOT confirmed, deliberately not acted on:** the `noattach` reason code. With
  `ase::cosim_policy $state attach 0` (`src/ase.tcl:1521`) `last_vcdfiles` returns `{}`, so the
  ruled step 4 answers `notloaded` — the wrong-cause failure the ruling rejects one step earlier
  for `multi 1`. One lens only; the contract was left alone rather than churned.
* **Not proven (reviewers said so, and it stands):** the ruling is not prototyped — nobody wrote
  `ase::cosim_scope_for_instance`, so steps 4-5 (registry match on `path`, the derived-scope
  fallbacks) are unverified; no genuinely **inlined** VCD exists on this machine, so the branch
  the whole ruling is justified by was never exercised (only the hint path was); 5e's premise
  that `TOP`'s signals are always the analog raw's was checked against one VCD; how item 4 gets
  a viewer token for step 4 while step 1 must read in the design context is underspecified; and
  rung 3's `module` comparand is untestable on a cell where `model == cell == module`.
* **Eyeball owed: none for this item** (no pixels). The ruling's eventual visible payload is
  F5's empty-pane notice — item 5's verdict to earn, not this one's.
* **Tree hygiene:** the repo root holds untracked `untitled-18..22.sch` droppings timestamped
  18:20-22:21, all predating this item; not created here, not removed.
