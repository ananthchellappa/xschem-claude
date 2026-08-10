# Batch F item 04 — F2: a schematic instance → its VCD scope, verified against the loaded DB

**Verdict [x].** The payload is a resolver's return value, not pixels; every branch is asserted
headless. Item 3's ruling was implemented as written; six points it left open were ruled into the spec
as **RULING 5f**, none re-opened. Nine confirmed review findings (two real `src/ase.tcl` defects, a
false evidence claim here, five coverage holes, a stale spec ref) are all fixed.

## 1. Files changed (`git diff --stat`; nothing else staged)

* `src/ase.tcl` **+348/-0** — one contiguous insertion after `ase::last_vcdfiles`: `cosim_f1`,
  `cosim_map_match`, `cosim_rung_name`, `cosim_scopes_of`, `cosim_scope_derive`, `cosim_hint_note`,
  `cosim_db_inventory`, `cosim_scope_for_instance`, `cosim_scope_for_state`. **Nothing existing was
  edited**: `cosim_map` and the artifact are byte-identical. `tests/headless/test_ase_cosim.tcl`
  **+395/-0** — the **FS** group (63 checks) plus `fget`, `mkvcdtree`, one fixture cell; 201 → 264
  checks, none renumbered or lost.
* `src/ciw.tcl` **+7/-0** — RULING 5f-6: `tag configure note` beside `input`/`result`/`error`;
  `doc/claude/specs/mixed_signal_signal_browser.md` **+79/-6** (the RULING 5f section, F2/H4 closed,
  four `src/ase.tcl` line refs re-measured); `doc/claude/issues/0307-…-no-cell.md` **+13**; this file.

## 2. Decisions, and the evidence for each

`ase::cosim_scope_for_instance <key> <instpath> ?<token>?` → `{ok <vcd> <scope> <how> <note>}` or
`{none <code> <sentence>}`, the five ruled steps in the ruled order: f1 read once in the design
context (lib/cell + the `.v`'s module + the instance's `model=`); the 5b four-rung `lib/cell` ladder,
case-insensitive, a multi-match refusing without falling through; the entry's own refusals (`multi`,
empty `vcd`); the DB matched on path; then the scope **derived, verified** — a hint is
eligible only when `vfile` is non-empty, accepted only on a literal case-**sensitive** `<hint>.`
prefix hit in the loaded DB, else derived (deepest scope whose leaf is f1's module, else the single
non-root scope, else refuse). The prefix is dropped, never translated; nothing falls back to `TOP`.

* **5f-1 — the disagreement is a FIFTH tuple slot plus an `ase::echo … note`**, not a third `how`
  value that consumers written against 5c (`$how eq {derived}`) would not see. FS46/FS47.
* **5f-2 — the third parameter is a viewer token**: it lets step 1 read the design context and step 4
  the viewer's registry (else the current registry, restore unconditional). FS33c/FS49.
* **5f-3 — no scope matches → `{none noscope <sentence>}`**, naming the module sought, the scopes
  found and the DB basename; never an `ok` on the root. **F5 renders it.** FS26/FS27/FS28/FS38/FS39.
* **5f-4 — `nodigital` covers both f1 failures** (leaf names no instance / no `verilog` view), a
  sentence each, not a seventh code F5 could not act on. FS6/FS43.
* **0307 (the flat design walk): still open, not made worse** — `cosim_design_scan` untouched; rung 4
  (the buried block's carrier) is live code pinned by FS13, and FS16 proves rung 3 does not fire for
  a vfile-less entry.
* **5f-5 (review) — an empty `wviewer::signal_list_all` answer is not "no databases"** (also: stale
  token, refused ticket), so the token arm falls through to the direct registry. FS50/FS51.
* **5f-6 (review) — `note` is a real CIW tag** (dark orange, between `result` and `error`): an
  undefined Tk tag styles nothing, and `error` would cry red over a recovered-from hint. FS47b.

## 3. Tests, check count, verbatim RESULT, and the audit diff

`tests/headless/test_ase_cosim.tcl`, the **FS** group: **63 new checks** (46 as first written, 17 from
review), total **201 → 264**. Fixtures come from `mkvcdtree` beside `mkraw`/`mkvcd` — no simulator;
end-to-end checks attach the analog raw plus four VCDs with the analog one current, so the resolver
must reach a non-current DB. Under `GUI_GATE=1 DISPLAY=:0 run_suites.sh --nogui`, verbatim:

`PASS     | test_ase_cosim               run 1/1  RESULT: ALL PASS (264 checks)`

**Audit — a diff, not a count.** `full_audit.sh`, `DISPLAY=:0`, `GUI_GATE=1`, panel live
(`control=RUN`; never launched, killed, re-armed or written to; no Pause/Stop; no hidden display, no
Xvfb, X never revived). Baseline `doc/claude/batch_F/baseline_status.txt` **exists** (`7a592f9c`, same
`:0`); diff by NAME and STATUS both ways, 306 audit + 58 wireedit = **364 rows vs 364, no row on one
side only**. This run `271 pass / 33 fail / 2 crash-timeout / 0 skip` + WIREEDIT PASS (58/58), 0 leaks;
baseline `277 / 26 / 0 / 2 timeout / 1 skip` + wireedit 58/58.

* **WORSE → GREEN (6)**, all baseline-side: `test_fluid_bodyshove_guards_0132`, `test_fluid_editing`,
  `test_rotate_stretch_dangling_0103` (SKIP→PASS), `test_wave_crossdb_trace`,
  `test_wave_sigbrowser_i12`, `test_wire_vertex_grab`. **RED → RED (2)**: `test_ase_plot`
  TIMEOUT→FAIL, `test_ase_window` FAIL→TIMEOUT. `test_ase_cosim` is **PASS** in the audit.
* **GREEN → WORSE (12), every one chased.** `test_wave_sigbrowser_keys` / `test_wave_tabs` re-run
  `ALL PASS` (49 / 172). The other ten reproduce **identically with the item fully reverted**
  (`HEAD:src/ase.tcl` + `HEAD:src/ciw.tcl` restored, re-run, then restored from a byte-exact backup,
  md5 `674e1d89918b6338527832bc0741ffa5`): `test_ase_dialogs` (20 red at HEAD), `test_ase_interact`
  (**4 red in 3/3 runs at HEAD and 3/3 with the item**, same I7 checks), `test_cmdmode_descend_0201`,
  `test_multi_window`, `test_wave_modes`, `test_wave_sigbrowser`, `test_wave_sigbrowser_i1315`,
  `test_wave_sigbrowser_panes`, `test_wave_sigbrowser_sea`, `test_wave_viewer`. Every failing check is
  key/focus delivery: `:0`'s key delivery is degraded this session — a known WSLg flake, not this item.

## 4. Sabotage table

Patches were applied **one at a time** to a byte-exact backup, run through `gated_xschem.sh`, then
restored and md5-verified; rows are keyed by patch. **Every one of the 63 new checks appears exactly
once — none is unsabotaged — and no sabotage survived.** `S-A`-`S-E` are the reviewers' own patches,
which survived 247 checks before this round added the fixtures that catch them; `S-J` deletes the whole
section: **62 FAILED (202 passed)**, the exception being FS47b (it pins `ciw.tcl`).

| what was broken | checks that went red | red? | restored green? |
|---|---|---|---|
| S1 the hint is trusted instead of the DB | FS21 FS22 FS22b FS35 FS36 FS37 FS38 FS39 | yes | yes |
| S-A the DB is never consulted (hint leaf == module wins) | FS22c FS22d FS60 FS61 FS62 FS63 FS64 | yes | yes |
| S2 / S3 / S11 (3 patches) a rejected hint REFUSES instead of deriving; the prefix test folds case; the SHALLOWEST module scope wins | FS34 FS37b FS23 FS24 | yes | yes |
| S-B / S-C (2 patches) `cosim_scopes_of` yields only each name's innermost scope; rung 1 drops the CELL operand and joins on `lib` alone | FS24b FS24c FS10b FS10c | yes | yes |
| S12 / S13 / S32 (3 patches) root fall-back — the forbidden `TOP`; the single-non-root rung removed; a same-depth tie ignored | FS26 FS27 FS25 FS28 | yes | yes |
| S29 / S30 / S31 (3 patches) the VCD named by basename; `scope` and `how` swapped; an agreeing hint never labelled `hint` | FS31 FS32 FS20 FS33 FS33b | yes | yes |
| S15 / S-H (2 patches, before and after the fixture grew a 5th DB) the inventory reports only the current DB | FS30 FS48 | yes | yes |
| S14 / S-G (2 patches, the second against the rewritten assertion) the inventory does not put the DB pointer back | FS33c FS49 | yes | yes |
| S-F the token arm believes an empty `signal_list_all` | FS50 FS51 | yes | yes |
| S-D / S-E (2 patches) rung 3 reads f1's `cell` where it must read `module`; rung 4 reads `cell` where it must read `model` | FS12b FS13b FS13c | yes | yes |
| S5 / S6 / S7 / S9 (4 patches) rung 1 ignores `lib` (bare cell key); rung 2 / rung 3 / rung 4 removed | FS10 FS11 FS12 FS13 | yes | yes |
| S8 / S4 / S10 (3 patches) rung 3's `vfile` gate removed; an ambiguous rung falls through (first-won); `nomap` reported as `notloaded` | FS16 FS14 FS15 FS44 | yes | yes |
| S16-S21 (6 patches) f1 keeps the path prefix; skips `model=`; does not read lib/cell; does not read the module from the `.v`; fabricates a `.v` for a cell with no `verilog` view; keeps an unresolved instance | FS4 FS3 FS1 FS2 FS5 FS6 | yes | yes |
| S22-S25 (4 patches) the `multi`, `notraced`, no-verilog-view and not-in-the-registry refusals each removed | FS41 FS42 FS43 FS40 | yes | yes |
| S26 / S27 (2 patches) the disagreement is not echoed; every answer is echoed, agreement included | FS46 FS47 | yes | yes |
| S28 / S-I (2 patches) the key form ignores the session state; the `note` tag line deleted from `src/ciw.tcl` | FS45 FS47b | yes | yes |

## 5. What was NOT verified

* **No genuinely inlined VCD exists here** (no verilator): the divergence fixtures hand-write a map
  entry whose recorded hint is stale — mechanism proven, provenance not. **The token arm's SUCCESS
  path is unrun** (headless has no live viewer window). **Nothing calls the resolver yet** — F1's
  branch is untouched by design and "f1 before any viewer raise" is enforced by nothing, so 5f-3's
  "F5 renders it" is a spec promise no check holds.
* **Reviewer notes carried, not fixed** (none a confirmed defect): the hint is accepted on *existence*,
  not consistency (RULING 5c as committed, not this item's to re-open); `cosim_db_inventory` is
  O(all DBs × all signals) per resolve (the shape `signal_list_all` has; restore pinned) and narrowing
  it is F1's call; the count rung only fires on a one-level tree; `xschem raw index` is gated on
  `sch_waves_loaded()`, so the verifier's end-to-end step (D) does not generalize to F1.
* **Not reproduced here:** the 42 sabotage runs, the two earlier audits (their green→red rows
  disagreed — X-abort collateral), the verifier's end-to-end drive. Lens 2's unattributable
  `test_ase_core` FAIL is **PASS** here; its concurrent-agent warning is why the tree was md5-fenced.
* **Eyeball owed (does not gate the verdict):** the one pixel added is the CIW `note` colour — confirm
  it reads as a notice you recovered from, not an error and not noise. Untracked `untitled-*.sch` are
  full_audit droppings; no scratch dir leaked.
