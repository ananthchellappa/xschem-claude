# Item 09 — eng-notation: engineering-notation display for ASE-L values

Repo: /home/qflow/dev/xschem/claude_1/xschem, branch `fluid-editing`.
Spec: doc/claude/specs/ase_l.md (section "UI v2 — ADE-L parity rework",
lines 155–263; Panes / Value column at lines 178–192).
Item detail: PLAN.md "Round 2 addendum / 09 eng-notation" (lines 321–352).
All anchors below re-verified from source 2026-07-21 by the scout.

## RUNBOOK policies (copied verbatim — non-negotiable)

- Git: NEVER `git reset --hard`, NEVER `git add -A`/`commit -a`, NEVER push.
  Stage explicit file lists only. Pre-existing dirty tracked files at batch
  start (listed in PLAN.md preflight) must NEVER be staged; in particular
  `tests/run_regression.tcl` is dirty pre-batch → this batch does NOT register
  tests there; tests/headless/full_audit.sh auto-discovers `test_*.tcl`.
- A green suite ≠ the changed code ran: sabotage-verify (each sabotage fails
  EXACTLY its target check, revert via targeted `git checkout -- <file>` only
  after `git diff` confirms the file holds nothing but the sabotage, clean
  re-run green).
- Headless traps: each test its own process; repo-root cwd for relative paths;
  script error idles rather than hangs; `--nogui --pipe -q --nolog --script`.
- GUI tests: DISPLAY-guarded self-SKIP (`winfo exists .` guard pattern from
  full_audit.sh); replay WHOLE Tk event sequences in the shipping rc profile.
- User-facing messages via `ciw_echo`, not puts/statusbar.
- Tcl: TIP-278 (`variable`/absolute names in namespaces); C (if any): C89,
  `_ALLOC_ID_` placeholders. Windows: guard unix-only subprocess paths.
- Do not touch `_nhangle_*`/`_allm_*`/junk dirs or anything outside declared
  scope. Do not edit generated files (Makefile from Makefile.in — tmpasm, no
  `$@`/`$<`, `@` is the delimiter).
- Commit messages: normal prose, Co-Authored-By trailer per repo convention.

Additional batch facts for THIS item:
- Dirty tracked files right now (never stage any of them):
  `doc/claude/ase_l_batch/PLAN.md` (driver-owned round-2 edit),
  `doc/claude/specs/sky130_workarea.md`, `sky130A/xschem_libs/library.defs`,
  `src/ciw.tcl`, `tests/headless/test_sky130a_libmgr.tcl`,
  `tests/run_regression.tcl`, and the two `xschem_libs_newsym/SANDBOX/...`
  files. Every file in this item's commit list was verified CLEAN at scout
  time (`git status --porcelain` empty for all ten).
- Protected tests that must stay green (assertion updates allowed but every
  change justified in the receipt): test_ase_core, test_ase_view,
  test_ase_window, test_ase_dialogs, test_ase_final, test_ase_interact.
- Baseline full_audit fail list (tolerated, list equality): FAIL:
  test_altf5_ciw, test_cadence_descend_newwin_ro, test_cadence_drag,
  test_cadence_window_hop_log, test_ciw, test_crossview_paste,
  test_fluid_editing, test_hi_descend, test_launch_context,
  test_lib_manager_gui, test_lib_sweep, test_palette, test_phase3_mints,
  test_pin_type_edit, test_reopen_readonly, test_select_at,
  test_selflog_output, test_verb_noun_copy_move, test_wire_split,
  test_wire_vertex_grab. TIMEOUT: test_key_graph_context. Known WSLg flakes
  (not regressions if a direct re-run passes): test_deselect_mode,
  test_hover_highlight, and test_ase_window inside PARALLEL audit runs
  (rerun-first, receipts/06).

## Scope

ASE-L displays values in ENGINEERING notation (exponent a multiple of 3,
SPICE SI suffix): `1.04e-4` displays as `104u`. Display-only:

- Applies to the **Variables pane Value column** and the **Outputs pane Value
  column** (post-sim evaluated values).
- Edit dialogs / entry fields keep RAW values (round-trip safety); the state
  file ALWAYS stores raw values. Formatting happens only at pane-render time.
- Gated by the Tcl global `ase_eng_notation` (default 1; rc may preset;
  0 → panes show the stored value verbatim, i.e. plain %g/scientific).
- Informational comment in the cadence-style rc files.
- Spec paragraph in ase_l.md UI-v2 section.

Out of scope: any other display site (analyses Arguments summary, Save
Options, temperature entry, model-files/options dialogs, log/netlist
viewers), any state-schema change, any C code.

## Verified anchors (current lines, 2026-07-21)

- `src/ase.tcl` (669 lines): helpers `ase::state_get` :46, `ase::expand_path`
  :58 — put `ase::format_value` + the `set_ne` gate default right after
  `expand_path` (before the "State I/O" section at :65). No Tk anywhere in
  this file (headless contract, file header :5-10).
- `set_ne` proc: src/xschem.tcl:215 (set-if-not-exists, `upvar #0`).
  ase.tcl is sourced at src/xschem.tcl:14106, AFTER set_ne is defined — the
  gate default is safe at ase.tcl source time.
- **Pane render paths** (both must go through the formatter),
  `src/ase_window.tcl`:
  - `ase::ui::populate` :727 — Variables pane Value cell insert :738-739
    (`[ase::state_get $row value]`); Outputs pane Value cell insert :755-765
    (`set val [dict get $results $rkey]` :759, inserted :761-762).
  - `ase::ui::refresh_output_values` :778 — Outputs Value cell write
    `catch {$tv set $i value $val}` :792.
  - Edit dialogs stay RAW (no change): `variable_editor` prefill :909-910,
    `output_editor` prefill :975-976, `add_variable_dialog` :854.
- `src/cadence_style_rc` (279 lines) — base Cadence-UX rc; sourced by both
  workarea rcs. Settings block `set cadence_compat 1` etc. around :37-40.
- `sky130A/cadence_style_rc` (44 lines) + `gf180mcuD/cadence_style_rc`
  (47 lines) — the rcs users actually launch (`run.sh` line 7 in each
  workarea dir execs `--script .../cadence_style_rc`); both `source
  [file join $_ws .. src cadence_style_rc]` near the top.
- Tests:
  - `tests/headless/test_ase_core.tcl` (347 lines): check helpers :26-32,
    section prefixes R/B/D/P/N/E — the new formatter table gets prefix `F`
    (free in this file). Runs true-headless from repo root (:23-24).
  - `tests/headless/test_ase_window.tcl` (930 lines): `tv_find` :90,
    `send_return` :155-173, `menu_save_state` :180, W3v add-variable leg
    :617-660 ("W3v tmpA in the tree" :628-629 expects `0.5`), W3o ends :701,
    main-window gate `if {![main_ready]}` :704, W6 Value check :811-821
    ("W6 id row Value filled after run" :820, `string is double` parse
    :815-819).
  - `tests/headless/test_ase_interact.tcl` (whole-flow): "WF id Value
    ~409.7uA" :412 (double-parse :407-411), "WF vd Value ~1.0" :420
    (parse :415-419).
  - `tests/headless/test_ase_dialogs.tcl`: "G9 panes repopulated with the
    imported value" :523-524 expects `0.9` (raw-state companion check
    "G9 load imports the picked state" :517-519 stays as-is).
- Spec: doc/claude/specs/ase_l.md — UI v2 section starts :155; "Panes"
  block :178-192 (Value column USER-LOCKED note :183-188). Insert the new
  paragraph right after the interaction-model bullet (:189-192), before
  "### Action strip" (:194).

## Scout decisions (each with its one-line justification)

1. **Formatter checks the gate internally** (call sites just wrap): keeps
   the gate testable headless and both render paths trivially compliant —
   one proc owns the whole display policy.
2. **Gate off → return the input VERBATIM** (not re-%g'd): the stored raw
   values already are the "%g/scientific" form the item describes (`1.04e-4`,
   `4.096837e-04`), and verbatim is exactly the pre-item-09 pane behavior
   the GUI test's "re-render → scientific" leg asserts.
3. **Sub-femto clamp**: engineering exponent clamped into [-15, 12]; values
   with |v| in [1e-18, 1e-15) render with fractional mantissa on `f`
   (5e-16 → `0.5f`) — this is the only reading that makes the item's stated
   fallback boundaries (`|v| >= 1e15 or nonzero < 1e-18 → %g`) exact.
4. **Mantissa = `format %.4g`** (≈4 significant digits, trailing zeros
   trimmed for free) + an explicit roll-over (rounding to mantissa 1000 →
   next suffix, e.g. 999.96e-6 → `1m`). Scout validated ALL item examples
   byte-exact with this algorithm (see table below).
5. **rc comment goes in all three rcs** (src/cadence_style_rc +
   sky130A/cadence_style_rc + gf180mcuD/cadence_style_rc): the workarea rcs
   are what users open/edit (run.sh entry points), the base rc covers
   non-workarea Cadence-UX launches; the comment is inert so duplication is
   harmless. All three verified NOT dirty. Ordering is a non-issue: the rcs
   run via `--script` (after ase.tcl's set_ne), so a plain
   `set ase_eng_notation 0` overrides; if some launch mode ever ran them
   earlier, set_ne would respect the preset — both orders work.
6. **Tcl trap (scout-reproduced)**: a `return` inside `catch {...}` is
   caught as TCL_RETURN → the naive "wrap the whole body in catch" defensive
   pattern silently returns the fallback for EVERY input. Structure the
   defensive catch around a helper call (`if {[catch {ase::format_value_num
   $v} out]} { return $v }; return $out`) or check the catch code — never
   around inline `return`s.
7. **Existing Value-cell assertions in 3 protected tests must be reworked**
   (enumerated below): the formatter changes what those cells display; the
   raw-state companion checks beside them stay untouched and become the
   display-vs-raw witnesses.
8. **The new GUI leg uses the Variables pane** (no ngspice dependency) via
   the real Add Variable dialog + send_return; Outputs-side formatting is
   covered by the reworked W6/WF run legs.

## Deliverables

### 1. `src/ase.tcl` — formatter + gate default

Insert after `ase::expand_path` (:63), before the State I/O section:

```tcl
# Display-side engineering notation (UI v2 item 09): SPICE SI suffixes,
# ~4 significant digits. Display-ONLY — state files and edit dialogs always
# carry raw values. Gated by the global ase_eng_notation (rc may preset;
# 0 -> the stored value is returned verbatim).
set_ne ase_eng_notation 1

proc ase::format_value {v} {
  if {![string is double -strict $v]} { return $v }
  if {![info exists ::ase_eng_notation] || !$::ase_eng_notation} { return $v }
  if {[catch {ase::format_value_num $v} out]} { return $v }
  return $out
}

# numeric arm (separate proc: `return` inside catch would read as an error)
proc ase::format_value_num {v} {
  set d [expr {double($v)}]
  if {$d == 0} { return 0 }
  set sign {}
  set a [expr {abs($d)}]
  if {$d < 0} { set sign - }
  if {$a >= 1e15 || $a < 1e-18} { return [format %g $d] }
  set e3 [expr {int(floor(log10($a)/3.0)*3)}]
  if {$e3 < -15} { set e3 -15 }
  if {$e3 > 12}  { set e3 12 }
  set m [expr {$a / pow(10.0,$e3)}]
  set ms [format %.4g $m]
  if {$ms == 1000 && $e3 < 12} { set e3 [expr {$e3 + 3}]; set ms 1 }
  set sfx [dict create -15 f -12 p -9 n -6 u -3 m 0 {} 3 k 6 Meg 9 G 12 T]
  return $sign$ms[dict get $sfx $e3]
}
```

(Exact code is yours to polish — comments/naming house-style — but the
behavior table below is the contract. `dict` vs `array` for the suffix map is
free choice; no namespace `variable` needed — TIP-278 moot for these two
procs.)

Scout-validated behavior table (all byte-exact):

| input | output | | input | output |
|---|---|---|---|---|
| `1.04e-4` | `104u` | | `0.5` | `500m` |
| `4.096837e-4` | `409.7u` | | `0.15` | `150m` |
| `1e-3` | `1m` | | `1.000000e+00` | `1` |
| `27` | `27` | | `999.96e-6` | `1m` (roll-over) |
| `1.5e6` | `1.5Meg` | | `5e-16` | `0.5f` (clamp) |
| `0` | `0` | | `1e-18` | `0.001f` (clamp edge) |
| `-1.04e-4` | `-104u` | | `9e-19` | `9e-19` (%g) |
| `1.8` | `1.8` | | `1e15` | `1e+15` (%g) |
| `vdd/2` | `vdd/2` (verbatim) | | `{}` | `{}` (verbatim) |
| `1k` | `1k` (verbatim — not a double) | | `NaN` | `NaN` (catch → verbatim) |

Gate off (`set ::ase_eng_notation 0`): every input returned verbatim.

### 2. `src/ase_window.tcl` — wire BOTH render paths (3 cell sites)

- `ase::ui::populate` :738-739 — Variables Value cell:
  `[ase::format_value [ase::state_get $row value]]`.
- `ase::ui::populate` :761-762 — Outputs Value cell: insert
  `[ase::format_value $val]` (formatting `{}` yields `{}` — blank pre-run
  behavior unchanged).
- `ase::ui::refresh_output_values` :792 — `$tv set $i value
  [ase::format_value $val]`.

NOTHING else changes in this file: editors/dialogs keep prefolding raw state
values (:854, :909-910, :975-976), temperature entry stays raw.

### 3. rc informational comment (3 files, identical block)

Append near the end of `src/cadence_style_rc`, and in the "settings" tail of
`sky130A/cadence_style_rc` + `gf180mcuD/cadence_style_rc` (e.g. just before
the final `unset` line), a comment block shaped like:

```tcl
# ASE-L shows values in engineering notation (e.g. 104u). To recover
# scientific notation, uncomment:
# set ase_eng_notation 0
```

Comment ONLY (the `set` line stays commented) — default stays 1.

### 4. Spec paragraph — doc/claude/specs/ase_l.md

In the UI v2 section, after the Panes interaction-model bullet (:189-192),
add one short paragraph, e.g.:

> **Value display — engineering notation (2026-07-21, item 09):** the
> Variables and Outputs Value columns render numeric values in engineering
> notation (SPICE SI suffixes f p n u m k Meg G T, ~4 significant digits:
> `1.04e-4` → `104u`, `4.096837e-4` → `409.7u`); |v| ≥ 1e15 or nonzero
> < 1e-18 falls back to %g; non-numeric strings (expressions) verbatim.
> Display-only: state files and edit dialogs always carry raw values.
> Gated by the Tcl global `ase_eng_notation` (default 1; rc may preset 0
> to recover plain scientific display). Formatter: `ase::format_value`.

### 5. Tests

**A. `tests/headless/test_ase_core.tcl` — new `F` section** (after P1,
before N1, or after E3 — your choice; keep the file's check helpers):
named checks, one per row (exact expected strings from the table):

- `F1 1.04e-4 -> 104u`
- `F1 4.096837e-4 -> 409.7u`
- `F1 1e-3 -> 1m`
- `F1 27 -> 27`
- `F1 1.5e6 -> 1.5Meg`
- `F1 0 -> 0`
- `F1 negative keeps sign (-1.04e-4 -> -104u)`
- `F1 sub-unity gets a suffix (0.5 -> 500m)`
- `F1 mantissa rounding rolls over (999.96e-6 -> 1m)`
- `F1 sub-femto clamps to f (5e-16 -> 0.5f)`
- `F2 1e15 falls back to %g`
- `F2 9e-19 falls back to %g`
- `F3 expression verbatim (vdd/2)`
- `F3 blank verbatim`
- `F3 already-suffixed verbatim (1k)`
- `F4 gate off returns raw (set ::ase_eng_notation 0 -> 1.04e-4)`
- `F4 gate restored -> 104u again` (restore `set ::ase_eng_notation 1`
  before the later sections — leave no global leak).

**B. `tests/headless/test_ase_window.tcl` — new GUI leg `W3e`** (insert
after W3o :701, BEFORE the `main_ready` gate :704 — it needs no main window
and no ngspice). Drive the REAL Add Variable dialog with `send_return`
(:155 helper; done-condition = dialog destroyed):

1. `$top.strip.var invoke` → `.addvar` up → name `tmpE`, value `1.04e-4` →
   send_return → `W3e add-variable 1.04e-4 shows 104u in the pane`
   (tv_find name tmpE, value cell eq `104u`).
2. `W3e session state keeps the raw value` — `ase::session_state` variables
   list matches `*{name tmpE value 1.04e-4}*`.
3. `menu_save_state $top` → `W3e saved state file stores the raw value` —
   grep the state file on disk for `value 1.04e-4` AND assert it does NOT
   contain `104u`.
4. `set ::ase_eng_notation 0; ase::ui::populate $key` →
   `W3e gate off shows the raw scientific value` (cell eq `1.04e-4`).
5. `set ::ase_eng_notation 1; ase::ui::populate $key` →
   `W3e gate back on shows 104u again`.
6. Double-click the tmpE row (`tv_dblclick`) → `W3e editor prefill is the
   RAW value` (`$top.edvar.value get` eq `1.04e-4`), then cancel the dialog.
7. Cleanup: select the tmpE row, `$top.strip.del invoke`, `menu_save_state`
   → `W3e cleanup leaves the session clean` (`ase::session_dirty` 0,
   variables back to Vgs/Vds) — the later W4-W7 legs depend on the seeded
   state.

**C. Reworked EXISTING assertions** (each justified in the receipt as a
direct consequence of the display contract; the neighbouring raw-state
checks stay untouched as display-vs-raw witnesses):

- test_ase_window `W3v tmpA in the tree` :628-629 — expected `0.5` → `500m`
  (the state check :630-632 keeps `{name tmpA value 0.5}` raw).
- test_ase_window `W6 id row Value filled after run` :811-821 — the cell now
  reads `409.7u`-style; replace the double-parse with a suffix parse that
  KEEPS the physical gate, e.g.
  `regexp {^([0-9.]+)u$} $vcell -> num` and `abs($num - 409.68) < 1.0`
  (the `u` suffix makes the cell µA directly). Keep the check name.
- test_ase_interact `WF id Value ~409.7uA` :407-413 — same suffix-parse
  rework as W6.
- test_ase_interact `WF vd Value ~1.0` :415-421 — formatted v(d)=1.0 renders
  `1` (still a double, tolerance holds), but make the parse suffix-tolerant
  anyway (accept `NUM` or `NUMm` with ×1e-3) so a 999.9m-class rounding can
  never flake the leg. Keep the check name.
- test_ase_dialogs `G9 panes repopulated with the imported value` :523-524 —
  expected `0.9` → `900m` (the raw import check :517-519 unchanged).

**Run everything** (repo root cwd):

```sh
./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_core.tcl
./src/xschem --pipe -q --nolog --script tests/headless/test_ase_window.tcl    # with DISPLAY
./src/xschem --pipe -q --nolog --script tests/headless/test_ase_dialogs.tcl   # with DISPLAY
./src/xschem --pipe -q --nolog --script tests/headless/test_ase_interact.tcl  # with DISPLAY
./src/xschem --pipe -q --nolog --script tests/headless/test_ase_view.tcl      # with DISPLAY
./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_final.tcl
tests/headless/full_audit.sh    # compare against the baseline fail list above
```

test_ase_final and test_ase_view need no changes (final is public-API
headless, view is dispatch-only) — they must pass UNTOUCHED.

## Sabotage plan (≥2 required; do all three)

After the green run + commit, one sabotage at a time; `git diff` must show
ONLY the sabotage before the targeted `git checkout -- <file>` revert; clean
re-run green after each.

- **S1 formatter gutted** (src/ase.tcl: make the numeric arm return `$v`):
  headless F1 table checks fail (104u/409.7u/1m/1.5Meg/-104u/500m/roll-over/
  clamp rows) while F2/F3/F4 stay green; GUI `W3e ...104u...`/`W3e gate back
  on` + `W3v tmpA in the tree` + `W6 id row Value filled after run` fail.
  Run test_ase_core + test_ase_window; enumerate the observed fail set —
  it must be exactly these formatter-consuming checks, nothing else.
- **S2 gate ignored** (src/ase.tcl: drop the `ase_eng_notation` read —
  always format): EXACTLY `F4 gate off returns raw` (headless) and
  `W3e gate off shows the raw scientific value` (GUI) fail; everything else
  green.
- **S3 wiring dropped at one site** (src/ase_window.tcl: remove the
  `ase::format_value` wrap from the populate VARIABLES cell only): headless
  all green (proves S3 targets the wiring, not the proc); GUI
  `W3e add-variable 1.04e-4 shows 104u` + `W3e gate back on` + `W3v tmpA in
  the tree` fail while the Outputs-side W6 check stays green.

## Commit — ONE commit, explicit file list

Stage EXACTLY these ten files (all verified clean of foreign edits at scout
time; re-verify with `git status --porcelain <file>` before staging; NEVER
`git add -A`):

```
src/ase.tcl
src/ase_window.tcl
src/cadence_style_rc
sky130A/cadence_style_rc
gf180mcuD/cadence_style_rc
doc/claude/specs/ase_l.md
tests/headless/test_ase_core.tcl
tests/headless/test_ase_window.tcl
tests/headless/test_ase_interact.tcl
tests/headless/test_ase_dialogs.tcl
```

Suggested message shape: `feat(ase): engineering-notation Value display
(104u), gated ase_eng_notation` + a body naming the formatter, the two
render paths, the gate default, the rc comments, and the reworked
assertions; end with the repo's Co-Authored-By trailer. Do NOT push. Do NOT
stage PLAN.md or any pre-batch dirty file.

## Cautions

- The state file must NEVER receive a formatted value: only the three
  render-time cell sites change. Watch `add_variable_ok` /
  `variable_editor_ok` — they read entry widgets (raw) and are correct
  as-is; do not "helpfully" format anywhere else.
- test_ase_window is a known WSLg flake INSIDE parallel audit runs —
  rerun-first directly with DISPLAY before classifying anything as a
  regression (receipts/06).
- The W3e leg mutates then restores the seeded session; if it leaves extra
  variables or dirt behind, W4-W7 and the W6 deck golden (`.temp 27`) go
  red — end the leg with the cleanup checks.
- Restore `::ase_eng_notation 1` after every gate-off test leg (core AND
  window) — a leaked 0 flips later formatted assertions.
- `string is double` accepts `Inf`/`NaN` spellings; the catch-wrapped
  numeric arm returns them verbatim — no special-casing needed, no test
  required.
