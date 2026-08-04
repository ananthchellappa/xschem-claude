# Item 1 receipt — `wviewer::sig_match`, the shared matcher

**Status:** DONE. 33 checks, all green; 3 sabotages, each fired on exactly one
check and nothing else.

**Files**
- `src/wave_viewer.tcl` — one new section at line 1447 (immediately after
  `wviewer::grid_dash_off` closes, before `wviewer::target_clamp`'s comment),
  inside the existing pure-helper cluster. Two new procs: `wviewer::sig_type`,
  `wviewer::sig_match`. No dialog, no widget, no ctx, no C.
- `tests/headless/test_wave_sigsearch.tcl` — NEW. 33 checks (SM01-SM26 minus
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
| a | `set rx $pattern` instead of `set rx "^(?:$pattern)\$"` | SM04 only | **1 FAILED / 32 passed — SM04 only.** Returned all 13 names (the ViVA trap, measured) |
| b | default `set nocase 0` | SM09 only | **1 FAILED / 32 passed — SM09 only.** `V(OUT)` → `{}` |
| c | `set pattern {} ; set rx {}` (legacy `xschem.tcl:4478`) instead of `return [list err $e]` | SM18 only | **1 FAILED / 32 passed — SM18 only.** `{ok 1}` vs `{err 0}` — both halves fired |

Each sabotage was followed by a revert and a clean
`tests/headless/run_suites.sh test_wave_sigsearch` → `RESULT: ALL PASS (33 checks)`.

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
