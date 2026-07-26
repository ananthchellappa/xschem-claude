# Receipt — item 14 persistence-accept (round-3 FINAL, acceptance gate)

Verdict: **DONE** [x] — **ROUND-3 ACCEPTANCE GATE PASSED**. Commit (NOT
pushed):
- `435a6fc9` feature — persist the waveform viewer in the ASE state +
  round-3 acceptance gate (`src/ase.tcl` +8/-, `src/ase_window.tcl` +73,
  `src/wave_viewer.tcl` +77, `src/draw.c` +19/-9,
  `tests/headless/test_ase_persist.tcl` +634 NEW,
  `tests/headless/test_ase_core.tcl` +4/-,
  `sky130A/.../test_nfet_final/ngspice_state1/test_nfet_final.state` +1,
  `doc/claude/specs/waveform_viewer.md` +213; exactly the 8 listed files
  staged explicitly, no pre-batch dirty tracked file swept in).

Outstanding problems: none (verified clean — empty problem list at
ledger time). Working tree clean at HEAD for all 8 committed files.
No fixer rounds.

NOTE for the driver: `doc/claude/specs/waveform_viewer.md` was untracked
through items 11-13 (receipts/13 flagged it as riding with the ledger
commit); item 14's feature commit is the commit that FIRST TRACKS it —
the full 213-line spec (round-1 contract + item-13 notes + this item's
Persistence rewrite + new "Item 14 notes") is now in git at 435a6fc9.
Nothing left for the ledger commit on that file.

## What landed

Per prompts/item14_persistence-accept.md D1-D11:

- **`viewer` state key (deliverable 1)**: appended as the 14th schema key
  in `ase::schema_keys`, default `viewer {}` in `ase::state_default`
  (src/ase.tcl). Old states load through the default merge; absent/`{}`
  viewer key → NO viewer auto-open (old-state fixture leg proves it).
  Non-empty shape, fixed build order for byte-deterministic snapshots:
  `viewer {open 0|1 sharedx 0|1 rawfile {} graphs {…}}` — graphs are the
  live wviewer model dicts VERBATIM incl. the item-13 `auto 1` marker
  (round-tripped, so always-replace does not spawn a second auto graph
  after reload). `sharedx` IS persisted; cursor mirrors are NOT (item-12
  design — die with the window).
- **Save State snapshots (deliverable 2)**: `wviewer::snapshot` — open-1
  arm captures the live layout; closed arm writes `open 0` with the
  previous dict's graphs KEPT; no-viewer-ever → `{}` passthrough.
  `ase::ui::viewer_snapshot` hooked FIRST into `do_save_state_as` (all
  three target arms) and the plain `ase::ui::save_state` seam.
  Snapshot-at-Save-only: no continuous sync, no snapshot at close (the
  session is already unregistered by `wviewer::close` time).
- **Load/open relaunch (deliverable 3+4 rawfile seam)**:
  `ase::ui::viewer_restore` runs at the end of `ase::ui::open`
  (fresh-open only — the `ase::open_state` RAISE arm is exempt) and of
  `do_load_state_from`; acts ONLY on `open 1`. `wviewer::restore` opens
  the window, overwrites the layout + syncs the sharedx menu mirror,
  then (when a raw resolved) inline `raw clear` + `raw read` (type word
  OMITTED when sim_type is `{}`) + re-materializes multi-token RPN
  traces via `raw add`, ONE regenerate at the end (attach_raw NOT reused
  — it would double-regenerate before the re-add). Raw resolution: dict
  `rawfile` override (absolute as-is / relative vs `[ase::rundir]`,
  attached iff exists) else `ase::last_rawfile`; missing raw → viewer
  opens with layout, traces draw empty, `ciw_echo` notice, NO crash.
- **Fixture + schema witnesses**: committed test_nfet_final state gained
  the trailing `viewer {}` line (keeps test_ase_final F3 byte-identity
  under the 14-key schema); test_ase_core R1 updated 13→14 keys
  (justified: schema grew by exactly this item's key). `library_new_view`
  seeds new state views with `viewer {}` automatically via state_default.
- **Spec (deliverable 5)**: Persistence bullet rewritten as-shipped +
  new "Item 14 notes (as shipped, 2026-07-21)" section (committed).

## Tests

`tests/headless/test_ase_persist.tcl` — NEW, **109 checks GUI arm,
three full runs ALL PASS with ZERO SKIPs** (gate requirement); `--nogui`
arm 17/17. Headless R legs: R1 viewer-key schema, R2 round-trip
byte-stability, R3 old-state fixture compat (no key → no auto-open),
R4 snapshot both arms (open-1 / open-0 graphs-kept), R5 --nogui.
GUI G1-G11 ACCEPTANCE GATE, all via send_return/send_key/real events:
fresh session on test_nfet_final ngspice_state1 → Choose Analyses dc
V2 0..1.8 step 0.01 (op stays enabled) → Outputs id row plot=1 →
**G3s** Outputs > To Be Saved > Select On Design click on D (see
deviation 1) → Netlist and Run → viewer auto-opens, auto graph carries
id, raw attached sim_type dc → cursor A readout vs `xschem raw value
id 180` ground truth 409.68uA, eng notation `409.7u` → Direct Plot
Button-1 on the D wire + real ESC → second graph v(d) → Save State to
scratch view ngspice_persist1 → close session (viewer closes, item-13
lifecycle) → reopen scratch view → viewer RELAUNCHES, both graphs +
auto marker restored, raw re-attached, RPN re-resolved, readout sane
again → open-0/no-key no-auto-open arms → missing-raw no-crash arm →
relative-rawfile seam.

- Protected suites all green by DIRECT runs at the final code:
  test_ase_core 66, test_ase_final 28 (--nogui), test_ase_view 36,
  test_wave_viewer 149 GUI + 36 nogui, test_ase_plot 85,
  test_ase_window 155, test_ase_dialogs 133, test_ase_interact 63.
- full_audit: launched (scratchpad/full_audit_item14.log), still in
  flight at forced-report time (receipts/12+13 precedent). Partial:
  test_ase_persist PASS, test_ase_core/final/interact PASS inside the
  audit; only baseline test_altf5_ciw + test_ase_dialogs (known WSLg
  parallel-audit flake — direct 133/133 green this session at the final
  code, receipts/13 precedent) non-PASS so far. nonBaselineFails=[]
  stands on the partial audit + direct green runs of every touched
  suite; verifier lenses subsequently confirmed (problems empty).
- KNOWN RESIDUAL FLAKES (pre-existing, NOT regressions, pass on
  re-run): WSLg main-window-never-usable self-SKIP arm; the receipts/13
  `load_new_window leaves .drw current` window-creation race (hit 1 of
  5 post-fix GUI runs mid-G8).

## Sabotage table (each `git diff`-confirmed sabotage-only, targeted
`git checkout -- <file>` revert, clean re-run green)

| # | Sabotage | Target | Failed exactly? |
|---|----------|--------|-----------------|
| S1 | `wviewer::snapshot` returns `$prev` unchanged — open-1 arm dead (src/wave_viewer.tcl) | R4 open-0 flip + G7 snapshot-dict family (open 1 / rawfile / 2-graphs / auto marker); dependent G8-G11 relaunch legs aborted on G7's empty dict ("key traces not known"); R1-R3, R4's other arms, G1-G6 green (6 FAILED / 62 passed) | yes |
| S2 | `wviewer::restore` drops step 2 — layout overwrite commented out (src/wave_viewer.tcl) | exactly the predicted G8 layout family (layout-2-graphs, auto-index-0, id trace, v(d) trace, raw-index-id, readout id line) + G10 layout-restored (8 FAILED / 101 passed); G7 snapshot, all R legs, raw re-attach + G11 seam green | yes |
| S3 | `ase::state_default` loses `viewer {}` (src/ase.tcl) | test_ase_persist R1 viewer-key assertion ("key viewer not known", aborts file, 1 FAILED / 1 passed --nogui) + test_ase_core R1 14-key check (1 FAILED / 65 passed); nothing unrelated | yes |

## Fix-round history

None — single feature commit, no verifier-raised problems, no fixer
commits.

## Implementer deviations (accepted, reality-forced, both spec-documented)

- (1) **Acceptance flow gained step G3s** — Outputs > To Be Saved >
  Select On Design on the D wire BEFORE the run: ngspice restricts the
  raw to the `.save` set and item-13 `add_trace` honestly refuses
  vectors absent from a loaded raw, so Direct Plot of an unsaved net
  cannot land a trace (probed: raw list had no v(d) under the prompt's
  literal flow). This is exactly what a real ADE-L user does; recorded
  in the spec's Item 14 notes.
- (2) **The prompt's "zero C changes" was impossible** — src/draw.c
  `graph_fullxzoom` dereferenced `xctx->rect[GRIDLAYER][graph_master]`
  unguarded while `graph_master` is MOUSE state (-1 off-graph,
  callback.c waves_selected): programmatic `setprop -fast rect 2 0
  fullxzoom` read `rect[2][-1]` and intermittently SIGSEGV'd the
  relaunch legs (2 of 3 pre-fix runs crashed; xschem-wrapper trace
  pinned it). Fix: out-of-range master clamped to the target graph
  (self-master). Pre-existing since item 12, surfaced by item 14's
  close/reopen cycles; src/xschem rebuilt, 0 crashes in 7+ post-fix
  runs.
- (3) Test-side: both sod_click sites use the documented test_ase_plot
  P6 ctx-switch idiom (replicates the real click's context switch that
  direct sod_click calls bypass).
- (assertion flip) **test_ase_core R1 13→14 keys**: schema legitimately
  grew by this item's `viewer` key; sabotage S3 proves the check still
  bites.

## Corrected anchors worth keeping (verified at 435a6fc9)

- `xctx->graph_master` is MOUSE state (-1 whenever the pointer is not
  over a graph): any C graph op reachable programmatically (setprop
  fullxzoom, regenerate, restore) must clamp/guard it — draw.c
  `graph_fullxzoom` now self-masters on out-of-range.
- ngspice raws contain ONLY the `.save` set — any plot-by-click flow
  must ensure the net is saved before the run, or `add_trace`'s honest
  raw-membership refusal blocks it.
- `wviewer::restore` must NOT reuse `attach_raw` (internal regenerate
  would fire before RPN `raw add` re-materialization → empty traces /
  readout interp throw). Order: layout overwrite → raw clear+read →
  raw add re-materialize → ONE regenerate.
- Snapshot-at-Save-only + no-snapshot-at-close: by `ase::ui::close`
  time the session is already unregistered when `wviewer::close` runs —
  a close-time snapshot hook is structurally impossible there.
- `viewer_restore` belongs to FRESH opens only; the `ase::open_state`
  raise arm must stay exempt or re-raising resurrects a viewer the
  user closed.
- Byte-determinism of the viewer dict comes from `wviewer::snapshot`'s
  fixed key build order (open sharedx rawfile graphs) — keep it if the
  shape grows.
- Reaffirmed from item 13: `raw read` type word must be OMITTED (not
  empty-string) when sim_type is `{}`; the `auto 1` graph marker must
  survive every (de)serialization or always-replace duplicates graphs.
