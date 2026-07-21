# Receipt — item 04 proof-final (BATCH ACCEPTANCE GATE)

Verdict: **DONE** ([x] in PLAN.md ledger). **Acceptance gate PASSED** — Id
reproduced end-to-end through the public ase API on the committed
clutter-free cell, with no workarounds anywhere: the committed state view
drives the run untouched except the D7 rundir override (hermetic run
location through the public state schema, committed file keeps `rundir {}`).
Commit: `c8d539c06c3a1a24d09c99ab035941b96970ff06` — `feat(ase): de-clutter
proof — sky130_tests/test_nfet_final + ngspice_state1 view, end-to-end Id
test`. NOT pushed (batch policy).

## What landed

7 files, +254/−2 (exactly the prescribed list, verified vs
`git show --stat c8d539c0`):

- **`sky130A/xschem_libs/sky130_tests/test_nfet_final/schematic/test_nfet_final.sch`
  (NEW)** — circuit ONLY: `sky130_fd_pr/nfet_01v8` M1 (`W=1 L=0.15 nf=1`),
  `devices/vsource` V1 (`value=Vds`) + V2 (`value=Vgs`), `devices/gnd`,
  `devices/lab_wire` D and G. nfet_test_claude geometry minus corner +
  simulator_commands_shown; NO netlist_commands instances, NO model include,
  NO `.control` anywhere.
- **`.../test_nfet_final/ngspice_state1/test_nfet_final.state` (NEW)** —
  committed in `ase::state_save` canonical bytes (D6, byte-identity
  round-trip assertable): design → the schematic view; models
  `{file $::SKYWATER_MODELS/sky130.lib.spice section tt}` (portable variable
  form per D1); variables Vgs 1.8 / Vds 1.0 (exercises `.param`); options
  savecurrents; analyses op enabled; outputs `-i(v1)` save; `rundir {}`.
- **`sky130A/xschem_libs/sky130_tests/nfet_test_claude/schematic/nfet_test_claude.sch`
  (NEW in git)** — the pre-batch untracked starting-point cell committed
  byte-identical as the before-exhibit (PLAN preflight note honored).
- **`src/ase.tcl`** — `proc ase::expand_path` (D1): variables-only
  `subst -nocommands -nobackslashes` at global level, `catch`-wrapped and
  rethrown as clean `ase: cannot expand model path '<raw>': <err>`; applied
  at the ngspice `render_deck` `.lib` emission. No ngspice literal in the
  helper — backend-seam invariant holds; item-01 golden deck unchanged
  (no `$`/`[` in its path) so test_ase_core stayed 33/33.
- **`sky130A/README.md`** — "ASE-L" paragraph (verified clean-tracked via
  git status BEFORE staging; not in the pre-batch dirty list).
- **`tests/headless/test_ase_final.tcl` (NEW)** — see Test below.
- **`tests/headless/full_audit.sh`** — `test_ase_final` registered in
  `nogui_tests` (D4; GUI-mode audit run would trip `ase::netlist`'s context
  guard arm (c) by design).

## Test

`tests/headless/test_ase_final.tcl` — **28 checks (F1–F10), all through the
PUBLIC ase:: API only** (state_load → netlist → render_deck → run → parse):
committed-state round-trip byte-identity (F3); view enumerated by
`cell_views`; netlist artifact asserted free of `.control`/`.lib`/corner
BEFORE deck append (de-clutter proof, F5/F7); deck checks incl. expanded
model path + no residual `$::` + `.param Vgs=1.8` + op inside the
`.control` block (F8); real ngspice run (F9) and Id parse (F10):
**Id = 4.096837e-04 A = 409.6837 µA, |Id·1e6 − 409.68| = 0.0037 < 1.0**.
F9/F10 actually RAN (not skipped) from repo root. Hermetics: scratch
`library.defs` per D3 (pointing at the REAL committed cell — unlike the
scratch-cell tests of items 01–03), `::SKYWATER_MODELS` set from repo root
per D2, rundir override per D7.

Prior ASE tests stayed green (NOT baseline fails): test_ase_core 33/33
(--nogui), test_ase_view 32/32 headless + 36/36 DISPLAY, test_ase_window
19/19 headless + 53/53 DISPLAY.

## Sabotage table

| # | Sabotage | Target check(s) | Result |
|---|----------|-----------------|--------|
| S1 | state file Vgs 1.8 → 0.9 (canonical form preserved) | F8 `.param Vgs=1.8` + F10 Id gate; F3 must STAY green | failed EXACTLY F8 .param-Vgs + F10 (Id=3.350433e-05 at Vgs=0.9); F3 stayed green as required |
| S2 | ase.tcl D1 expansion neutered (raw model path emitted) | F8 expanded-path + no-`$::` checks + F9/F10 (ngspice cannot open `$::SKYWATER_MODELS/...`) | failed EXACTLY the 2 F8 expansion checks + F9 exit-code + F9 log-data-rows + F10; F9 deck-written stayed green (deck written before ngspice runs); test_ase_core stayed 33/33 under the sabotage — F8 exercises the NEW seam with no collateral |
| S3 | .sch re-clutter (simulator_commands_shown re-appended) | F5 + F7 (+ anticipated double-.control deck effects) | failed EXACTLY F5 simulator_commands + F5 .control + F7 no-.control + F8 op-inside-.control (embedded block supplies the deck's first `.control`/`.endc`, appended op falls outside — anticipated, attributed); F5 no-corner correctly stayed green (only the commands instance re-added); F9/F10 stayed green (ngspice merges control blocks, same operating point) |

Each: applied post-commit, file-scoped `git diff` confirmed sabotage-only,
targeted `git checkout -- <file>` revert, clean re-run 28/28.

## Audit / fix rounds

- full_audit: **188 pass / 17 fail / 1 timeout / 8 skip, WIREEDIT PASS**;
  the fail set is a STRICT SUBSET of the PLAN.md baseline (baseline entries
  test_cadence_window_hop_log, test_palette, test_verb_noun_copy_move
  happened to pass). All 4 test_ase_* PASS inside the audit. **Zero
  non-baseline fails.**
- Build: `make` = nothing to be done (pure Tcl + data item).
- Verifier lenses returned no problems — **no fixer rounds were needed**
  (outstanding-problems list empty at ledger time).
- Declared implementer deviations (process only, none in code/content):
  1. full_audit executed as one background run due to the 10-min foreground
     tool cap (same script/flags/classification).
  2. Sabotages run after the single commit, per item-02/03 receipt precedent
     (the prescribed git-checkout revert flow needs the committed baseline).

## Outstanding problems

None — verified clean (empty outstanding-problems list at ledger time).

## Corrected/confirmed anchors worth keeping

- **Model-path portability (D1)**: state files carry the VARIABLE form
  (`$::SKYWATER_MODELS/...`); expansion lives in `ase::expand_path` at the
  ngspice `.lib` emission — NEVER in tests (test-side expansion is exactly
  the workaround class item 04 forbids; the committed view must also work
  from the GUI Run button where the rc sets the variable).
- **Symbolic sources (D5, scout-verified by running ngspice)**:
  `devices/vsource` with `value=<param>` netlists as `V1 D GND Vds`; plain
  ngspice resolves bare `.param` names in that position. Note the role swap
  vs nfet_test_claude (there V1(drain)=1, V2(gate)=1.8; here V1=Vds=1.0,
  V2=Vgs=1.8) — same operating point, Id exactly 4.096837e-04.
- **S3 anatomy — why the netlist-artifact checks matter**: a re-cluttered
  schematic's embedded `.control` becomes the deck's FIRST
  `.control`/`.endc`, pushing the appended analysis outside the block; but
  ngspice MERGES control blocks so F9/F10 alone would NOT catch re-clutter —
  the F5/F7 pre-append artifact assertions are the real de-clutter gate.
- **Deck-write ordering**: `ase::run` writes `<cell>_ase.spice` before
  spawning ngspice, so a "deck written" check stays green even when the sim
  fails (seen under S2) — pair it with exit-code/log checks.
- **Audit registration for state-driven tests (D4)**: `ase::netlist`'s
  context guard (arm (c)) errors by design in GUI mode — such tests go in
  full_audit.sh `nogui_tests` (run_regression.tcl stays untouched:
  pre-batch dirty, and full_audit auto-discovers).
- **Headless model/library resolution recipe (D2/D3)**: set
  `::SKYWATER_MODELS` from the repo root (`[file join $repo sky130A models
  libs.tech combined]`, mirroring cadence_style_rc) + scratch
  `library.defs` with `::library_registry_defs_only 1` and empty
  `::XSCHEM_LIBRARY_PATH` — works from repo root without touching the
  pre-batch-dirty workarea library.defs.

## Commit hygiene

ONE commit staging exactly the 7 prescribed paths (schematics ×2, state
file, sky130A/README.md, src/ase.tcl, test_ase_final.tcl, full_audit.sh).
nfet_test_claude committed byte-identical to the pre-batch untracked
original; sky130A/README.md confirmed clean-tracked before staging; no
pre-batch dirty tracked files, no junk dirs, no generated files. Not pushed.
