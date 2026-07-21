# Receipt — item 09 eng-notation (round-2 addendum)

Verdict: **DONE** [x]. Commit `05b2a708` (NOT pushed).

Anomaly: the pipeline workflow died at the implement stage ("completed
without calling StructuredOutput") AFTER the implementer had landed the full
commit. Verify/ledger stages never ran in-workflow; the DRIVER ran the same
3 adversarial lenses directly against 05b2a708 instead. All three: ok.

What landed (10 files):
- `ase::format_value` + `format_value_num` (src/ase.tcl:76-108): suffixes
  f p n u m {} k Meg G T, %.4g mantissa + trailing-zero trim, %g fallback
  (|v|>=1e15, nonzero <1e-18), non-numeric verbatim, sign kept,
  1000-mantissa rollover. 1.04e-4 → 104u, 4.096837e-4 → 409.7u.
- Gate `set_ne ase_eng_notation 1`; 0 → pre-feature display. Formatter at
  the 3 pane render sites only (ase_window.tcl:740,763,793); editor prefill
  + state file stay RAW (W3e asserts disk).
- Informational recovery comment in all 3 sourced rcs:
  src/cadence_style_rc:280, sky130A/cadence_style_rc:44,
  gf180mcuD/cadence_style_rc:47 (`# set ase_eng_notation 0`).
- Tests: test_ase_core F-table 66/66 headless; test_ase_window W3e GUI leg
  (pane 104u, raw round-trip, gate toggle) 153/153; display-contract
  updates in test_ase_dialogs (G9 0.9→900m) + test_ase_interact (suffix
  parse). Spec paragraph ase_l.md:193-200.

Lens evidence (driver-run):
- hygiene: no preflight-dirty files staged, scope exact, TIP-278 clean.
- tests: 6/6 ASE tests PASS twice (pre/post sabotage); formatter sanity
  8/8 headless; sabotage (u→n suffix flip, ase.tcl:107) failed EXACTLY the
  4 u-suffix checks (62 others green), targeted revert, clean re-run.
- spec: all 5 numbered deliverables verified in landed code, live-executed.
  Env note: suite needs XSCHEM_SHAREDIR at repo src/ else stale installed
  ase.tcl shadows (known memory gotcha) — surfaced as 4 FAILs, a de facto
  extra liveness witness.
