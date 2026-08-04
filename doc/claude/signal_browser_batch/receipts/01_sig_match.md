# Item 1 receipt — `wviewer::sig_match`, the shared matcher

**Status:** DONE (after one verifier-driven FIXUP — see §11). 34 checks, all
green; 5 sabotages, each fired on exactly its target check(s) and nothing else.

**Files**
- `src/wave_viewer.tcl` — one new section at line 1447 (immediately after
  `wviewer::grid_dash_off` closes, before `wviewer::target_clamp`'s comment),
  inside the existing pure-helper cluster. Two new procs: `wviewer::sig_type`,
  `wviewer::sig_match`. No dialog, no widget, no ctx, no C.
- `tests/headless/test_wave_sigsearch.tcl` — NEW. 34 checks (SM01-SM27 minus
  SM03, ST01-ST08). Writes nothing, so no `test_scratch` dir. Auto-globbed by
  `full_audit.sh`; deliberately NOT added to `nogui_tests` even though item 1's
  checks need no X, because items 4-7 append dialog checks to this same file and
  need the display arm. No `gold/` entry (gold/ holds netlists only) and no
  `tests/run_regression.tcl` registration (no wave test is listed there).

---

## 1. THE ONE REAL CONFLICT: decision 3 vs item 1's test bullet — resolved, declared

Item 1's test bullet says *"regexp `l*` matches **everything** (the documented
ViVA trap — assert it, it is not a bug)"*. Settled decision 3 says regexp
patterns are wrapped `^(?:$pat)$`. **Both cannot be true**: under the wrapper
`l*` is zero-or-more-`l` ANCHORED, so it matches only names made entirely of
`l` — nothing in a realistic list.

**Decision 3 wins.** Three independent reasons:
1. It is in the **Settled** section; the bullet is illustrative prose.
2. The item's OWN sabotage (a) — "drop the `^(?:...)$` anchoring → the
   regexp-anchoring check fails and nothing else" — is **incoherent under the
   bullet**. Unanchored, "regexp `l*` matches everything" would PASS, not fail.
   The sabotage only has a target under the anchored reading.
3. `references/viva_cadence_waveform_viewer.md:212` derives ViVA's anchoring
   from "regex `l*` = all" being START-anchored, and :943 states outright that
   anchoring *"is inferred from three worked examples, never stated as a rule"*.

**Resolution (declared, not silent):** the trap is still asserted, **inverted**.
Check `SM04` asserts regexp `l*` returns `{ok {}}`, carrying a comment recording
that ViVA / unanchored would return every name. That single check IS sabotage
(a)'s target — and the sabotage run **measured** the unanchored behaviour: all
13 fixture names came back, exactly as the bullet described. If the driver
disagrees, this is a one-line ruling that changes one check.

## 2. The `[list ...]` quoting trap

Raw names contain brackets (`v(net_name[3])`, `@m.x1.m1[id]`). Tcl's canonical
list string-rep **brace-quotes** such an element, so an expected value written
as a `{...}` literal can never compare equal to the returned list — the sabotage
(a) failure output shows it plainly: `{@m.x1.m1[id]}`, `{v(net_name[3])}`.
Every multi-element expectation in the test file is therefore built with
`[list ...]`, and a REQUIRED comment above the fixture says why. The scout lost
five phantom reds to this before switching; items 2-7 must keep the rule.

## 3. `@`-form classification diverges from `ase::ui::output_kind` — deliberate

`wviewer::sig_type` classifies ngspice's `@m.x1.m1[id]` terminal-current form as
**`other`**, because item 1's contract says *"classifying on a leading `v(` /
`i(`"* and this implements the contract verbatim rather than substituting.
`ase::ui::output_kind` (`src/ase_window.tcl:791`) classifies a leading `@` as
`current`.

So **two classifiers in this codebase now disagree about `@`**, on purpose.
Check `ST05` pins the contract behaviour so the disagreement is visible rather
than latent, and the proc header carries a ⚠ note.

**FLAGGED FOR ITEM 9** (the type dropdown): a real raw carries `@`-form
currents, so a user picking "Current" will not see them. Widening `sig_type` is
a one-line change; not doing it silently is the failure mode. Driver call,
cheap either way.

## 4. HANDOFF TO ITEM 3 — two findings, neither item 1's to fix

**(a) `-sort $graph_sort` is a MIS-MAPPING.** Item 3 says call
`sig_match ... -sort $graph_sort`. `graph_sort` is 0/1 where **0 means
`-decreasing`**, whereas this contract's `-sort 0` means **RAW ORDER**. A
literal pass-through silently changes the legacy dialog's default sort from
descending to unsorted — exactly the on-screen change item 3 forbids. Item 3
must map `[expr {$graph_sort ? 1 : -1}]`.

**(b) `::graph_sort` is UNSET headless.** `set_ne graph_sort 0`
(`xschem.tcl:4772`) is inside a proc, so the var does not exist until the graph
dialog is built. Item 3's test must set it itself or `graph_get_signal_list`
throws.

## 5. The `^(?:...)$` wrapper breaks two Tcl-only regexp forms

Measured: `^(?:***=foo)$` and `^(?:(?i)x)$` **both** raise
`couldn't compile regular expression pattern: quantifier operand invalid`,
because ARE directors and embedded options are legal only at the very START of
an RE. Raw, both compile fine.

Consequence: a user typing `(?i)foo` gets an error message instead of a
case-insensitive match. **Acceptable** — `-case` / the Match-case box is the
supported way to ask for that — but it is recorded in the proc header verbatim
so item 4 files it as documented behaviour, not a bug.

## 6. Other decisions written into the proc header (so items 2/3 cannot guess wrong)

- **`siglist` is a Tcl LIST, not a newline blob.** The item never said; splitting
  `xschem raw list` is the CALLER's job, and item 2's `signal_list` becomes the
  one place that does it. Item 3's legacy body already splits.
- **The empty-pattern short-circuit is MANDATORY, not a consequence.** Probed:
  `string match {} x` → 0 and `regexp {^(?:)$} x` → 0. "An empty pattern matches
  everything" is a coded early-`lappend`. SM16/SM17 pin both syntax arms.
- **The pattern is never trimmed and never eval'd.** `--` guards the regexp arm;
  the shell arm is safe by arity (`string match $pat $n` is objc==3 and parses
  no options — probed with a pattern of literally `-nocase`).
- **`switch -exact -- $sort` needs the `--`**: `-1` is a legal value.

## 7. Anchor drift measured by the scout

Every anchor in the PLAN sits **+40 lines** on this tree — *except*
`wviewer::open`, cited at `:624`, which is at **:677 (+53)**. **Drift is NOT
uniform**; a later scout must re-verify each anchor from source rather than add
40. All 14 scout anchors were re-verified byte-exact at implement time, plus the
insertion point (`grid_dash_off` closes 1445, blank 1446, `target_clamp` comment
1447).

Minor implementation divergence from the scout's rehearsal, declared: option
validation uses `lsearch -exact {shell regexp} $syntax < 0` rather than the
`ni` operator, matching the idiom already used throughout `wave_viewer.tcl`
(`lsearch -exact` at :661, :722, :1539, :1729, :1749 — zero uses of `in`/`ni`).
Semantically identical.

## 8. Sabotage log

Because `src/wave_viewer.tcl` carried this item's uncommitted work, a
`git checkout -- src/wave_viewer.tcl` would have wiped the whole item, not the
sabotage. Substitute with the identical guarantee: a pristine byte-copy of the
green file was snapshotted to the scratchpad, each sabotage was confirmed with
`diff -u <pristine> src/wave_viewer.tcl` showing **one hunk and nothing else**,
and each revert was a `cp` back followed by `diff -q` proving identity.

| # | sabotage | expected target | measured |
|---|----------|-----------------|----------|
| a | `set rx $pattern` instead of `set rx "^(?:$pattern)\$"` | SM04 only | **1 FAILED / 33 passed — SM04 only.** Returned all 13 names (the ViVA trap, measured) |
| b | default `set nocase 0` | SM09 **and** SM27 (both case-DEFAULT checks) | **2 FAILED / 32 passed — SM09 + SM27, nothing else.** `V(OUT)` → `{}` on both arms |
| c | `set pattern {} ; set rx {}` (legacy `xschem.tcl:4478`) instead of `return [list err $e]` | SM18 only | **1 FAILED / 33 passed — SM18 only.** `{ok 1}` vs `{err 0}` — both halves fired |
| d | drop `-nocase` from the **regexp** arm (`:1577`) — *the verifier's sabotage, the one that used to survive* | SM27 only | **1 FAILED / 33 passed — SM27 only** |
| e | drop `-nocase` from the **shell** arm (`:1571`) — d's mirror, added so both arms are pinned symmetrically | SM09 only | **1 FAILED / 33 passed — SM09 only** |

Sabotage (b) fails **two** checks by design, and that is the correct scoping, not
leakage: there are two case-DEFAULT checks because the implementation carries two
independent `-nocase` flags (`:1571` shell, `:1577` regexp), and (d)/(e) prove
each one is individually pinned. The item's original "(b) → the case check fails"
assumed a single arm. Coverage wins over a one-target count — see §11.

Each sabotage was followed by a `git checkout -- src/wave_viewer.tcl` (HEAD now
carries the item, so the targeted checkout is exact), a `git diff --quiet` proving
the file held nothing but the sabotage, and a clean re-run →
`RESULT: ALL PASS (34 checks)`.

## 9. Verification

- `cd src && make` → *Nothing to be done for 'all'* (Tcl-only item; `src/*.tcl`
  is read from the source tree at startup, so no rebuild is owed).
- `tests/headless/run_suites.sh test_wave_sigsearch` → `RESULT: ALL PASS (33 checks)`,
  green under the GUI gate (never a bare loop).
- `tests/headless/full_audit.sh` — see §10.

## 10. full_audit vs the 18-name baseline

`tests/headless/full_audit.sh` (solo, exit 1):
**`SUMMARY: 256 pass  22 fail  2 crash/timeout  3 skip  (total 283)`**
— total 283 = the baseline's 282 + this item's new test. `WIREEDIT: PASS`,
`SCRATCH: 0 leaked dir(s)`.

**15 of the 18 baseline fails reproduced**; three baseline fails happened to pass
this run (`test_remap`, `test_resolved_net_hash_bus_0158`, and
`test_wave_trace_menu` — the TG9 root-coords flake landing on its good side).

**Nine names outside the baseline, ALL cleared as environment flakes, none mine:**

| name | verdict |
|------|---------|
| test_ase_interact, test_ase_persist, test_fluid_editing, test_geometry_sanity, test_hover_highlight, test_wave_snap | re-ran individually through `run_suites.sh` → **all 6 PASS** (63 / 109 / 26 / — / — / 106 checks). Load flakes. |
| test_key_graph_context (TIMEOUT in the audit) | re-ran → **PASS**. |
| test_ase_plot (TIMEOUT in the audit) | the documented P4/P6 gesture flake — and **ISOLATION-PROVED** below. |
| test_altf5_ciw | fails on a *different* check each run (`Alt-F5 raises` / `rebound Alt-F5 raises`), once NORESULT, once **PASS** — the documented WSLg raise/focus flake, and **ISOLATION-PROVED** below. |

**ISOLATION PROOF for the two stubborn ones.** `src/wave_viewer.tcl` was
temporarily reverted to `HEAD` (`git show HEAD:src/wave_viewer.tcl > …`, so the
tree was byte-identical to the pre-item state), and `test_ase_plot` +
`test_altf5_ciw` were re-run twice each: **identical failures — same six P4/P6
checks, same Alt-F5 check, plus a NORESULT and a PASS.** They fail without item 1
present, so they are not item 1's. The file was then restored from the scratchpad
byte-copy (`diff -q` clean) and `test_wave_sigsearch` + `test_wave_viewer` re-run
green (33 + 400 checks).

**The 3 SKIPs** (`test_alt_transform_group_0116`,
`test_fluid_collinear_backbone_short_0105`,
`test_fluid_compact_escape_stub_0137`) each **PASS** when re-run individually;
a SKIP is a self-declared banner, not a failure, and full_audit counts it
separately from FAIL.

⚠ **PROCESS NOTE for the next implementer:** the first `full_audit.sh` of this
item was accidentally run while a previous one was still going. Two concurrent
audits produced `251 pass / 27 fail / 2 crash / 3 skip` — nine *extra* red names
that all evaporated when the suite was re-run solo. This is the
`headless-suite-flakes-under-cpu-load` lesson landing for real: **check
`pgrep -f full_audit.sh` before starting one.** Also: pipe the audit to a FILE,
not `| tail -40` — the summary line prints *before* the per-failure dumps, so
`tail` eats exactly the number you need.

---

## 11. FIXUP after the adversarial verifier (2026-08-04)

The verifier ran a sabotage of its own — **delete `-nocase` from the regexp arm
at `src/wave_viewer.tcl:1577`**, making RegExp-mode search case-SENSITIVE by
default in violation of settled decision 6 — and the suite stayed
`ALL PASS (33 checks)`. **That is a real coverage hole and the verdict was
correct**, so this fixup closes it rather than arguing:

**BLOCKER — fixed.** The two syntax arms carry two *independent* `-nocase`
flags (`:1571` shell, `:1577` regexp). The original test covered the DEFAULT only
on the shell arm (SM09/SM10/SM11) and covered the regexp arm only with an
explicit `-case 1` (SM25); every other regexp check dodged case entirely (SM04
returns `{}`, SM05 is all-lowercase, SM17 short-circuits on the empty pattern,
SM18 errors). New check:

```tcl
check {SM27 regexp arm is case-INsensitive by DEFAULT} \
  [lindex [sig_match $SIGS {V\(OUT\)} -syntax regexp] 1] [list v(out)]
```

The trade the original made — SM25's comment said it used `-case 1` "so sabotage
(b) keeps exactly one target" — was **the wrong trade, and it is reversed here**:
one-target sabotage hygiene is a bookkeeping convenience, coverage of a shipping
default is not. Consequence, declared in the test file and in §8: **sabotage (b)
now fails two checks, SM09 + SM27**, both of them case-DEFAULT checks and nothing
else. Two new sabotages (d) and (e) drop `-nocase` from one arm each and fire on
exactly SM27 / exactly SM09, proving the arms are pinned individually. This
matters beyond the unit: item 4's search bar ships Shell+RegExp with Match-case
OFF, so the regexp default is exactly what a user hits.

**Test-quality note — fixed.** SM23 ("default syntax is shell") asserted one
`sig_match` call against another `sig_match` call. It now asserts an independent
literal, `[list ok [list l1 l2]]`. It still gives sabotage (a) no second target
(the shell arm is untouched by the anchoring wrapper).

**Verifier notes that are NOT code problems, itemised for the driver:**

- **SM04's inversion** (regexp `l*` matches nothing, not everything) — the
  verifier independently reproduced the conflict, confirmed
  `references/viva_cadence_waveform_viewer.md` is internally inconsistent
  (:207 vs :211 vs :943), and agreed the resolution favours the Settled section.
  Unchanged; still §1's declared `[D]`-shaped call for the driver to affirm.
- **Decisions 12/13 in the PLAN diff** — the implementer did not author them;
  they were already in the working tree at item-1 start (the commit message says
  so). Driver confirmation only, no repo change possible from this side.
- **Baseline re-baselining** — a driver process recommendation, not an item-1
  defect. See §12 for this fixup's own audit, which reproduces the point.

## 12. Re-verification of the FIXUP

- `cd src && make` → *Nothing to be done for 'all'* (Tcl-only).
- `tests/headless/run_suites.sh test_wave_sigsearch` →
  `RESULT: ALL PASS (34 checks)`, under the GUI gate.
- All **five** sabotages re-run on the fixed tree, each reverted with a targeted
  `git checkout -- src/wave_viewer.tcl` after `git diff` showed one hunk only —
  see the §8 table for the measured per-sabotage failure sets.
- `tests/headless/full_audit.sh` (solo — `pgrep -f full_audit.sh` checked first,
  piped to a FILE): **`SUMMARY: 247 pass  28 fail  1 crash/timeout  7 skip
  (total 283)`**, `WIREEDIT: PASS`, `SCRATCH: 0 leaked dir(s)`.
  16 of the 18 baseline fails reproduced (`test_remap` and
  `test_resolved_net_hash_bus_0158` happened to pass). **13 names outside the
  baseline, every one cleared:**

  | name(s) | verdict |
  |---------|---------|
  | test_ase_unnamed_net, test_close_window_force, test_deselect_mode, test_fluid_editing, test_hover_highlight, test_lib_manager_bold, test_multi_window, test_wave_modes | re-ran through `run_suites.sh` → **all 8 PASS** (28/–/18/26/–/–/15/485 checks). Load flakes. |
  | test_altf5_ciw, test_lib_manager_checkin (TIMEOUT in the audit) | re-ran → **PASS**. The documented WSLg raise/focus flake. |
  | test_ase_plot | the documented P4/P6 gesture flake — failed on exactly the documented P4/P6 checks. |
  | test_prop_form_field_width_0170 | **ISOLATION-PROVED**: fails IDENTICALLY (same 2 checks) with `src/wave_viewer.tcl` reverted to `3098afa0`, i.e. with item 1 physically absent (`grep -c sig_match` = 0). |
  | test_wave_axis_zoom | **ISOLATION-PROVED, see below.** |

  All **7 SKIPs** (`test_graph_box_zoom_xy`, `test_drag_keeps_selection`,
  `test_fluid_loop_0088`, `test_fluid_reversal_0089`,
  `test_fluid_drag_through_anchor_0109`,
  `test_connected_drag_group_transform_0114`, `test_flylines_render`) **PASS**
  when re-run individually. A SKIP is a self-declared banner, not a failure.

- **`test_wave_axis_zoom` — flaky, and NOT this item's** (it is the only
  non-baseline name that lives in the file item 1 touched, so it got the full
  bisect). Always the same 5 axis-grab gesture checks. Measured by reverting
  `src/wave_viewer.tcl` alone and re-running under `run_suites.sh`:

  | tree | wave_viewer.tcl content | runs |
  |------|-------------------------|------|
  | HEAD | item 1 present | 1 pass / 3 fail |
  | `3098afa0` | item 0 only, **no `sig_match` at all** | 1 pass / 3 fail |
  | `ccd5f30a` | pre-batch | 5 pass / 1 fail |

  It fails on a tree carrying **neither** item, so it is not item 1's and not a
  hard regression. ⚠ **FOR THE DRIVER:** the observed rate is visibly higher on
  the two batch trees than on the pre-batch one. At n=4/4/6 that is not
  separable from chance or machine load, but item 0 (`3098afa0`, the 0187 viewer
  ctx guard) is the only candidate and it is worth a look before item 2 —
  item 1 is excluded by construction (`grep -rn 'wviewer::sig_' src/ tests/`
  outside its own test file and proc: **zero callers**, so the new code cannot
  execute in any other suite).

- **BASELINE RECOMMENDATION (seconding the verifier).** Three audits of the same
  item produced three different non-baseline sets — implementer 9, verifier 8,
  this fixup 13, sharing only a few names. The "18 fails / 0 crash / 0 skip"
  preflight was a lucky run. The rule *"any new fail is the current item's
  problem, full stop"* will keep firing on every later item and cost each one an
  hour of re-runs. The driver should re-baseline as a fail SET **plus** a
  known-flaky set: `test_altf5_ciw`, `test_ase_plot` (P4/P6/P8),
  `test_geometry_sanity`, `test_prop_form_field_width_0170`,
  `test_wave_axis_zoom`, `test_wave_trace_menu` (TG9), `test_lib_manager_*`
  (timeouts), plus "any SKIP is not a FAIL".
