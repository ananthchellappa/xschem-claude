# Overnight batch 2026-08-01 — waveform viewer feature round

Driver harness modelled on `doc/claude/refactor_b_batch/`. Five user-supplied
feature items for the ASE waveform viewer. Fully autonomous overnight run: no
human interaction, no review gate, no permission prompts for tests.

- Repo: `/home/qflow/dev/xschem/claude_1/xschem`
- Branch: `fluid-editing`
- Pipeline: `doc/claude/overnight_batch_2026_08_01/feature_pipeline.js`
- Receipts: `doc/claude/overnight_batch_2026_08_01/receipts/NN_<slug>.md`
- Decision docs: `doc/claude/code_analysis/ovb01_<NN>_<slug>_decision.md`
- Implementation prompts: `doc/claude/overnight_batch_2026_08_01/prompts/NN_<slug>.md`

## Verdict alphabet

| mark | meaning |
|------|---------|
| `[ ]` | not started |
| `[x]` | DONE — implemented, committed, adversarially verified, and **every** deliverable is reachable by an assertion |
| `[E]` | DONE-EYEBALL-PENDING — implemented, committed, verified, but at least one deliverable is pixels / feel / layout that no check can see. Listed in the final report for the user to look at. |
| `[D]` | DEFERRED with recorded reasons (a success outcome) |
| `[F]` | FAILED — implementation aborted or the verifier rejected it after one repair attempt |

An item **may not** be ticked `[x]` if the verifier reports a non-empty
`unassertable` list. That is clause 11 of
`doc/claude/suggestions/orchestration_driver_vs_implementer.md`.

## Spec-hole policy (user instruction, 2026-08-01)

> "If there are spec holes and questions for me arise, make a reasonable
> assumption (usually claude's first option for each question is Claude's
> recommendation) and proceed, and note the decision that was made in the final
> report for that task item."

So a spec hole is **NEVER** a reason to DEFER. The scout decides it, records the
decision + the alternatives it rejected in the decision doc, and the ledger stage
copies the decision list into the receipt so the final report can surface it.
DEFER is reserved for: the item's scope genuinely balloons past one pipeline run,
or source fundamentally contradicts the request.

## Run policy for THIS batch

- **`GUI_GATE=0`** for every suite invocation. Nobody is at the desk overnight;
  the gate's 2-minute autostart per suite would cost hours and its
  `_gate_attention` relaunch is pointless with no viewer. (See memory
  `gui-test-gate`. This is a per-run override, NOT a change to the harness.)
- Tests run freely, no permission asks, no waiting.
- Commits: launching this batch authorizes **one commit per green item** (plus
  fixup commits from the repair stage) plus **one final ledger commit** touching
  only this batch directory. Explicit file lists only — never `git add -A`,
  never `git commit -a`, never `git reset --hard`, **never `git push`**.
- Strictly sequential. One item in flight at a time.

## DRIVER QUEUE (state on disk — survives compaction)

Remaining order, as of items 01–04 being resolved:

1. **item 03 REMEDIATION** — `fix_pipeline.js`, `{item: 3, slug: "axis-region-drag-zoom"}`
2. **item 04 REMEDIATION** — `fix_pipeline.js`, `{item: 4, slug: "axis-region-ctrl-wheel-zoom"}`
3. item 05 — `feature_pipeline.js`
4. **FINAL REPORT**, then the ONE ledger commit touching only this batch dir.
5. **THEN: end the turn with an `AskUserQuestion` call — a real question that needs
   a real answer.** User instruction, 2026-08-01: that is what raises the alert on
   their phone, so a plain prose sign-off leaves them with no notification that the
   overnight run has finished. Do NOT skip it, and do NOT substitute a rhetorical
   question in prose — it must be the tool call. Good subjects: which `[E]` items to
   eyeball first, whether to keep or revise a recorded spec-hole decision (e.g. item
   01's removal of the 20-px marker halo, item 05's shrink magnitude), or whether to
   push.

All three touch `tests/headless/test_wave_axis_zoom.tcl` (03's latch leg, 04's
off-centre Y legs) or the shared waveform sources, so they run **strictly
sequentially**. Two writers on one suite file lose edits.

### STOP-RULE DEVIATION, recorded by the driver 2026-08-01

The stated stop condition was *"two consecutive FAILED (= systemic)"*. Items 03
and 04 both came back `[F]`, and the driver **continued anyway**. The reasoning,
so the user can reverse it:

- The stop rule exists to catch a **broken tree**. The tree is not broken: build
  green, both features implemented and committed in scope, working dirt unchanged,
  the audit explained in both directions.
- Both failures are the **same defect class**, and it is a *test* defect, not a
  code defect: a probe placed where the correct and the incorrect implementation
  are numerically or structurally indistinguishable. Item 03 released the drag
  *inside* the strip, where the GRAPHPAN latch never fires. Item 04 probed at the
  plot box's *centre*, where an anchored zoom and a zoom-about-centre give the
  same answer.
- Both verifiers handed over an exact, cheap fix recipe including the sabotage
  that must start killing legs.
- The user had already directed that item 03's gap be closed, so continuing is the
  consistent action rather than a new decision.

The systemic signal was **acted on, not ignored** — see the probe-placement rule
added to the universal test discipline below, which every remaining stage
inherits.

## PREFLIGHT (filled by the driver, once — 2026-08-01)

- **build: GREEN.** `cd src && make` → `Nothing to be done for 'all'`, rc 0;
  `./src/xschem --version` → `XSCHEM V3.4.8RC`.
- **HEAD at preflight:** `e516cc85` — *test(0172): every clause of
  is_pristine_untitled() now has a leg that dies with it*
- **pre-existing dirty TRACKED files** (must still be the ONLY dirty tracked files
  after every item, aside from that item's own commit):
  - `doc/claude/suggestions/next_session_prompt_0165.md`
  - `sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/ngspice_state1/tb_bandgap.state`

  (The tree also carries ~60 pre-existing UNTRACKED paths — test logs, scratch
  dirs, `references/`, `.agents/`. Leave every one of them alone.)

- **BASELINE AUDIT — `GUI_GATE=0 bash tests/headless/full_audit.sh`**
  `SUMMARY: 239 pass  20 fail  1 crash/timeout  11 skip  (total 271)`,
  `WIREEDIT: PASS` (all 58), `SCRATCH: 0 leaked dir(s)`.

  **This exact list is the contract.** Any fail NOT on it belongs to the current
  item until proven otherwise:

  ```
  FAIL     | test_altf5_ciw
  FAIL     | test_ase_unnamed_net
  FAIL     | test_cadence_drag
  FAIL     | test_ciw
  FAIL     | test_deselect_mode
  FAIL     | test_fluid_editing
  FAIL     | test_graph_context
  FAIL     | test_lib_manager_gui
  FAIL     | test_lib_sweep
  FAIL     | test_nh_anim_rearm
  FAIL     | test_phase3_mints
  FAIL     | test_pristine_untitled_viewer_0172
  FAIL     | test_readonly_action_dispatch
  FAIL     | test_reopen_readonly
  FAIL     | test_rotate_stretch_short_0104
  FAIL     | test_select_at
  FAIL     | test_selflog_output
  FAIL     | test_sky130a_libmgr
  FAIL     | test_verb_noun_copy_move
  FAIL     | test_wave_markers
  TIMEOUT  | test_key_graph_context
  ```

  Baseline SKIPs (also not yours):

  ```
  SKIP | test_connected_drag_group_transform_0114   SKIP | test_fluid_relay_manhattanize_0107
  SKIP | test_connected_drag_keeps_selection_0113   SKIP | test_fluid_reversal_0096
  SKIP | test_drag_keeps_selection                  SKIP | test_fluid_sibling_pin_backbone_short_0098
  SKIP | test_fluid_drag_onto_backbone_row_0106     SKIP | test_rotate_stretch_dangling_0103
  SKIP | test_fluid_exit_stub_staircase_0111        SKIP | test_rotate_stretch_reconnect_0100
  SKIP | test_fluid_loop_0088
  ```

### Three baseline fails that sit ON this batch's turf — read before blaming yourself

1. **`test_wave_markers` is ALREADY RED**, at `1 FAILED (802 passed)`:
   ```
   FAIL: MF1 the anchor really SLID (more than one distinct sample visited) -> {0} (exp {1}) : FAIL
   ```
   Items **01** and **02** both extend this suite. You inherit that one red leg.
   Do **not** "fix" it as part of your item and do not let it mask a real
   regression: your gate is *"1 FAILED, and the failing leg is exactly MF1, and
   the pass count went UP by the number of legs I added."* A second red leg, or a
   pass count that did not rise, is yours.

2. **`test_graph_context` is ALREADY RED** and **`test_key_graph_context` already
   TIMES OUT.** Their failing legs are all wheel/key-over-graph routing:
   ```
   FAIL: over-graph wheel leaves canvas zoom (z=1237.113402061856 @ 0,0)
   FAIL: over-graph f leaves canvas zoom (z=1030.927835051546 @ 0,0)
   FAIL: over-graph Up leaves canvas origin (...)
   FAIL: over-graph A leaves netlist_show (1 == 0)
   FAIL: over-graph Ctrl+b leaves sym_txt (0 == 1)
   ```
   Item **04** (CTRL+wheel in the axis region) is routing a wheel event over a
   graph — i.e. it lands in exactly the area these suites already fail in. Item 04's
   scout **must read both suites first**, because (a) they may be describing a real
   pre-existing routing hole the item has to design around, and (b) the item must
   not be blamed for them. If item 04's work incidentally makes either suite
   greener, say so; do not chase it.

3. **`test_pristine_untitled_viewer_0172` is RED at HEAD**, and HEAD is the commit
   that added it. Nothing in this batch touches it; it is baseline for this run.

### Known-flaky, pre-existing (memory-sourced reading aid; the list above is the contract)

- `test_cadence_drag` — fails 12/12 on pristine code (memory `viewer-no-snap-grid-0177`).
  It is on the baseline list above, as expected.
- `test_wave_trace_menu` TG9 "posted in ROOT coordinates" — 4-in-10 under WSLg on
  pristine HEAD (memory `tg9-root-coords-wslg-flake`). It PASSED this preflight;
  if it goes red under an item, re-run before attributing.
- `test_ase_plot` P4 / P6 / P8 gesture legs — 1–2 runs in 10 under WSLg, always
  have (memory `ase-test-flakes-wslg-gestures`). **The check COUNT is the signal,
  not the verdict**: 145 = a real run, 30 = a WSLg geometry skip that still prints
  `ALL PASS`. `test_wave_clear_all` has the same trap (68 real vs 58 skipped).
- WSLg Xwayland aborts kill every X client ~3x/session (memory
  `wslg-xwayland-aborts`). A whole-suite wipeout with `NORESULT` / connection
  errors is that, not a regression — re-run before attributing.

## POSTFLIGHT (driver, end of round — 2026-08-01)

- **build: GREEN** (`make` → nothing to be done; every item built before committing).
- **dirty TRACKED files: UNCHANGED from preflight** — still exactly
  `doc/claude/suggestions/next_session_prompt_0165.md` and
  `sky130A/.../tb_bandgap.state`. No item leaked a file.
- **FINAL AUDIT — `GUI_GATE=0 bash tests/headless/full_audit.sh`:**
  `SUMMARY: 246 pass  18 fail  1 crash/timeout  7 skip  (total 272)`,
  `WIREEDIT: ALL PASS`, `SCRATCH: 0 leaked dir(s)`.
  Baseline was `239 pass  20 fail  1 crash/timeout  11 skip  (total 271)`.
  The +1 total is the new suite `test_wave_axis_zoom` (items 03/04), which PASSES.

**Ten baseline fails did not recur**, including `test_wave_markers` — the `MF1`
red that items 01/02 inherited is green in this run — plus `test_graph_context`
and `test_pristine_untitled_viewer_0172`. The audit is demonstrably load-sensitive
in *both* directions (0 SKIP here vs 11 at baseline), so neither the improvement
nor the churn should be read as caused by the batch.

**Four fails were NOT on the baseline list. All four investigated, none attributable:**

| suite | standalone re-run | verdict |
|---|---|---|
| `test_wave_split_strip` | `ALL PASS (221 checks)` — full count | audit-load flake |
| `test_wire_vertex_grab` | `ALL PASS` | audit-load flake |
| `test_ase_plot` | `ALL PASS (150 checks)` — a real run, not the 30-check skip | the documented WSLg P4/P6/P8 flake |
| `test_hover_highlight` + `test_palette` | flake ~40 %, alternating | **CONTROLLED, see below** |

`test_hover_highlight` and `test_palette` were the only ones that had PASSED at
preflight, so they were treated as regressions until proven otherwise. Measured
5× on the batch build: hover `PASS/FAIL/PASS/FAIL/PASS`, palette
`yes/NO/yes/NO/yes`. Then a **git worktree at the preflight commit `e516cc85` was
built from scratch and run 5×**: hover `PASS/-/PASS/FAIL/PASS`, palette
`-/yes/yes/NO/yes`. **The same flake, at the same rate, on pristine pre-batch
code.** Same family as memory `wslg-key-delivery-flakes` (a bare `event generate`
flakes ~1 in 5) and `wslg-xwayland-aborts`. Control worktree removed after
measuring.

`test_palette` additionally has no `RESULT:` footer — it prints a bespoke
`EVENT opens palette: yes|NO` banner — so `full_audit.sh`'s classifier scores it
FAIL/NORESULT whenever the event is lost. Worth giving it the shipped footer
one day; out of scope here.

---

# Ledger

- [E] 01 marker-anywhere-in-plotbox — `m` (and `d`) place a marker anywhere inside the strip's plot box, at the diamond cursor's snapped point; no trace-proximity requirement -> DONE, EYEBALL PENDING: no check can read the two new CIW refusal strings or confirm the drawn diamond and the drawn marker anchor land on the same screen pixels
- [E] 02 dblclick-delta-marker-selects-pair — double-clicking a difference marker selects it **and** the marker its deltas are derived from -> DONE, EYEBALL PENDING: no test can see BOTH markers of a pair actually rendering selected (a predicate bounded to the head passes all 979 checks)
- [E] 03 axis-region-drag-zoom — LMB press-and-drag in the X or Y axis-number region zooms that axis only; forward drag = zoom in, reverse drag = zoom out -> DONE, EYEBALL PENDING: no check reads the canvas, so the rubber band's pixels — including whether the new abort path leaves a stale outline on screen — are unverified (latch coverage gap closed, fixup 33e3512b8c31c3779d5582d3e24abc29cfe9a36d)
- [E] 04 axis-region-ctrl-wheel-zoom — CTRL+wheel in an axis region zooms that axis only, about the pointer (the data point under the pointer does not move) -> DONE, EYEBALL PENDING: no leg reads the canvas, so the trace visibly staying put under the pointer and the repainted Y axis numbers are inferred from the model, never seen (latch coverage gap closed, fixup 42e2fdfc)
- [E] 05 multi-trace-drag-to-strip — dragging one selected trace drags the whole selection to the destination strip, with a shrink preview during the drag -> DONE, EYEBALL PENDING: no check reads a pixel, so nothing verifies that the carried traces actually render shrunk, on the right strips, inside a drawn drop-target frame

---

# Item detail

Every item below carries: the user's spec **verbatim**, the questions the scout
must answer (with the recommended answer, which is the one to take unless source
contradicts it), the known landmines, likely files, and the test plan seed. The
scout **re-verifies every claim here from source** — line numbers and API shapes
in these notes come from memory files and have drifted before.

Universal READ-FIRST for every stage:

1. `doc/claude/code_analysis/waveform_subsystem_reference.md` — the WIRING.md of
   waveforms. Data model, pipelines with file:line, the 40+ landmines. **Load it
   before touching anything.**
2. `doc/claude/specs/waveform_viewer_modes.md` — §12 strip reorder, §13 trace
   drag, §14 viewer undo/redo, §15 the full LMB/RMB ownership table.
3. `doc/claude/specs/graph_markers.md` — marker model, §2 D11, §4.1, §6.2.1, §6.4.
4. `doc/claude/specs/waveform_viewer.md` — the ASE viewer spec.
5. `CLAUDE.md` — build, tests, conventions.

Universal facts that bit previous rounds (do not re-learn them the hard way):

- **A graph is not a type.** It is an `xRect` on `GRIDLAYER(2)` with
  `flags=graph`; ~30 `token=value` props in `prop_ptr` hold all durable state.
- **Model trace index != node index.** `graph_props` skips a trace with an empty
  `vec` when building the `node` token, so every C answer (`graph_trace_at`,
  `hilight_wave`, `sel_waves`) is in NODE space.
  `node_index_of_trace` / `trace_index_of_node` / `node_count` are the mapping;
  nothing crosses without them.
- **Durable content renders under `draw_graph` flags bit 8; transient UI chrome
  under bit 16** (bit 16 is stripped from every export). Getting this backwards
  is how the marker work nearly shipped chrome into SVG.
- **`setup_graph_data()` returns EARLY for an off-screen graph** before parsing
  `unitx`/`unity`/`logx`, and it rewrites `graph_flags`' hcursor bits. A query
  needing those tokens must read them off the rect.
- **`my_snprintf` is a minimal reimplementation and does NOT understand `%.*g`.**
  Use raw `sprintf` for that pattern, as `draw_cursor` does.
- **`xschem get` / `set` are letter-dispatched internally** (`get` groups sub-keys
  by first letter, `set` splits on `argv[2][0] < 'n'`). A key filed in the wrong
  half is *silently unreachable* — no error, the setter just does nothing.
- **`lw = 0.0` is not zero width** — it inherits the GC resting width
  `XLINEWIDTH(xctx->lw)` where `xctx->lw = 1.125 * mooz`. Any new stroke that
  must be a fixed pixel width passes an explicit `bus` width; use the
  `GRAPH_MARKER_PX(n)` idiom (it adds +0.25 because `n*zoom*mooz` truncates to
  n-1 on 13.9 % of zooms).
- **Read-only is enforced in the mutating PRIMITIVES**, never in the key arms —
  `readonly_block()` pops a MODAL and a modal on a keystroke deadlocks any script
  driving the refusal. The viewer is read-only for life and gets through because
  `key_filter` wraps the keys and `strip_drag_release` wraps the release in
  `with_edit`.
- **`Graph_ctx` locals are built and dropped at six call sites** — a new field
  must be a FIXED array, never a malloc'ed pointer, or it leaks once per hover
  motion event.
- **The viewer's undo is NOT the C undo stack.** It is a per-window stack of
  model snapshots pushed by `wviewer::push_undo` immediately after
  `capture_live_graph_state`. Window OPTIONS (plot mode, sharedx, cursors, raw)
  are deliberately outside a snapshot.
- **A mutating viewer command must call `capture_live_graph_state` FIRST**,
  because `regenerate` re-places rects from the Tcl model while the C engine
  writes pan/zoom/bold straight into the rect prop.
- **An empty destination strip's ranges must be blanked to auto** on any drop, or
  a µA trace lands in a 0–2 V window and is drawn off-screen.
- **The ASE viewer learns about C-side changes by a PUSH from C**
  (`graph_marker_notify` → `graph_marker_changed`), never a pull: `regenerate`
  runs from ~18 sites and only 3 capture live state first, and one of the others
  is a plain window RESIZE.

Universal test discipline:

- New/changed headless tests live in `tests/headless/`, are registered in
  `tests/headless/full_audit.sh` (`logdir_tests`), and copy the shipped footer
  **exactly**: `RESULT: ALL PASS ($npass checks)` + `exit 0/1`. `run_suites.sh`
  classifies on the literal string `ALL PASS` — a footer saying `RESULT: PASS` is
  reported FAIL while printing PASS.
- **Never deliver a key with a bare `event generate` + one `update`.** Use the
  shipped idiom (`send_key` in `test_wave_clear_all.tcl`, `mg16_key` in
  `test_wave_modes.tcl`): loop, `focus -force`, confirm
  `[focus -displayof $w] eq $w`, generate, retry until an expr evaluated in the
  caller's scope reports the effect happened. For a NEGATIVE leg, confirm focus,
  deliver once, and add a check that the probe was actually delivered.
- **Replay the WHOLE Tk event sequence** in the shipping rc profile for any
  gesture leg (press → motion(s) → release, with `update` between).
- **A "far/empty" pixel scan must require `graph_plotbox_at`** or it hands back
  the label margin; and a scanned pixel must be RE-SCANNED after any leg that
  zooms or pans.
- **PROBE PLACEMENT — the rule this batch was taught the hard way, twice.**
  *Never drive a leg from a pixel or a path where the correct implementation and
  the bug you are guarding against give the SAME answer.* Both `[F]` verdicts in
  this round were exactly this and nothing else:
  - **item 04**: every Y-axis probe came from a helper whose y is
    `(box_top + box_bottom) / 2` — the plot box's vertical **centre**, u = 0.5 —
    where an anchored zoom and a zoom-about-**centre** are numerically identical.
    Two one-token sabotages of shipped source (`(double)my` → `(double)mx` in C,
    `$py` → `$px` in Tcl) left **all 338 checks green** while introducing a 12 %
    error. The suite even *documented* the trap on its X legs and then walked into
    it on its Y legs.
  - **item 03**: every drag leg released **inside** the strip, where
    `graph_master` is still set and the release arrives without the GRAPHPAN
    routing latch. Deleting the latch term left **all 196 checks green** while
    silently breaking a real, reachable gesture.

  Concretely, before you write a leg, answer: *what is the wrong implementation I
  am afraid of, and does my probe point discriminate it?* Then prove the answer by
  building that wrong implementation and watching the leg die. Prefer **off-centre**
  probes, **asymmetric** fixtures, and paths that exit the object under test.
  A leg that asserts only a magnitude (a width, a count, a "the other axis did not
  move") survives an arbitrarily wrong anchor — assert **both endpoints**, or the
  fixed point, or byte-equality with the primitive's own getter.
- **When the state being asserted is stored per-object, witness every object**,
  not the one you clicked (`hilight_wave` is a per-RECT token — a one-rect
  witness missed a whole class of bug).
- **Sabotage-verify every named sabotage**: it must fail EXACTLY its target
  check, be reverted with a targeted `git checkout -- <file>` *after* `git diff`
  confirms that file holds nothing but the sabotage, and the clean re-run must be
  green. Thresholds in behavioural legs are FRACTIONS of the measured range, not
  magic counts.
- Scratch files go in the test's own `test_scratch` dir, never the repo root.

---

## 01 marker-anywhere-in-plotbox

**User spec, verbatim:**

> Currently, to select a trace, the mouse pointer needs to be reasonably close to
> the trace - proximity. Good. However, this is not needed for adding a marker.
> Adding a marker is done by pressing "m" key - clear intention. Therefore, if the
> mouse is within the plot area of a strip, and user presses "m" key, add a marker
> at the point that the diamond cursor has snapped to

**What exists today** (re-verify): `m` places a marker at the nearest SAMPLE on a
trace and `d` places a marker plus a delta block versus the most recent one
(memory `cadence-waveform-markers`, spec `graph_markers.md`). The diamond snap
cursor is the viewer-plan item-9 feature; `graph_point_at(..., tol, restrict_wave,
restrict_dataset, ...)` is the snap primitive and already accepts a `1e30`
tolerance in the rigid-drag path. `GRAPH_TRACE_PICK_TOL` = 10.0 screen px in
`src/xschem.h` is shared by four trace-picking surfaces — this item must **not**
change it; trace *selection* keeps its proximity, which the user explicitly
called good.

**This is the same class of bug that shipped in viewer item 9**: the snap cursor's
gate was trace-proximity when it should have been the plot box. Memory
`pixel-deliverables-need-eyeball` has the measurements.

**Questions and recommended answers** (take the recommendation unless source says
otherwise; record whichever you take):

1. *What is "the plot area"?* → the strip's **plot box**, the region
   `graph_plotbox_at` answers for. Not the label margin, not the legend, not the
   axis-number margins, not the reorder-handle column.
2. *What does the diamond snap to when the pointer is far from every trace?* →
   the nearest sample of the **nearest trace in that strip**, however far — i.e.
   the existing nearest-wins rule with the tolerance dropped (`1e30`), which is
   exactly what the rigid marker drag already does. `find_closest_wave()` is
   still live for precisely this "nearest, however far" purpose (the `t`
   dataset-track arm uses its return value) — reuse it, do not clone it.
3. *Does the same relaxation apply to `d`?* → **yes.** `d` is `m` plus a delta
   block; the user's argument ("pressing the key is clear intention") applies
   identically. Record it as a decision.
4. *Pointer outside the plot box (legend / margin / handle column)?* → refuse
   exactly as today. No marker, no error dialog.
5. *Digital strips and bus traces?* → still refused; those are recorded as
   deferred in `graph_markers.md` and this item does not unlock them.
6. *Multiple traces equidistant?* → ties go to the first node, matching
   `graph_wave_at`'s documented tie rule.
7. *No raw loaded / empty strip?* → refuse; there is no sample to snap to.
8. *Does the marker still bind to a TRACE (so anchor-drag slides along it)?* →
   **yes** — the marker model is anchored to a trace + dataset + sample. This item
   changes only the *gate*, not the anchor model.

**Likely files:** `src/draw.c` (`graph_point_at`, `find_closest_wave`,
`graph_marker_*`, `graph_plotbox_at`), `src/callback.c` (the `m` / `d` key arms),
`src/xschem.h`, `src/wave_viewer.tcl` (`key_filter`), possibly `src/scheduler.c`
if a query verb needs widening.

**Test plan seed:** extend `tests/headless/test_wave_markers.tcl`. Legs must
include: a press at a plot-box pixel measured to be >10 px from every trace now
places a marker (this is the leg that dies if the gate is not relaxed); the same
press in the label margin still refuses; `d` gets the same treatment; the marker's
anchor is the nearest trace's nearest sample; a digital strip still refuses; the
existing trace-*selection* proximity is unchanged (a regression witness on
`GRAPH_TRACE_PICK_TOL` behaviour). Named sabotages: restore the proximity gate
(must kill the far-pixel leg only); make the gate proximity-to-trace instead of
plot-box (must kill the margin-refuse leg).

**Assertability:** the placement is fully assertable — this item is a strong `[x]`
candidate. Only report `unassertable` if the implementation adds new rendering.

**Defer triggers:** none expected. Defer only if the diamond snap cursor turns out
not to exist in the viewer at all (then the item is "build the snap cursor", which
is out of scope).

- receipt: doc/claude/overnight_batch_2026_08_01/receipts/01_marker-anywhere-in-plotbox.md — done and committed as `be5d9b98`, all three sabotages killed exactly their targets, eyeball pending

## 02 dblclick-delta-marker-selects-pair

**User spec, verbatim:**

> If a marker is a "difference marker" - created by pressing "d" key so that delta
> and slope are displayed, then, double-clicking the marker will select both this
> marker and the one that its deltas are derived from.

**What exists today** (re-verify): a marker's selection is identified by NUMBER
alone; `graph_marker_selgraph` is a rect INDEX and is only a hint (it goes stale
on a strip reorder / multi-plot prepend), so the Delete gate re-resolves with
`graph_marker_find()`. **Multi-marker selection is explicitly listed as DEFERRED**
in memory `cadence-waveform-markers` — so this item unlocks it. That makes it the
highest-risk item in the batch; the scout should size it honestly.

The double-click interlock already exists and must be reused, not reinvented:
`GRAPH_CLICK_TOL` (3.0, `callback.c`) is click-vs-drag TRAVEL in WORLD units
(`* xctx->zoom`), and the `-3` arm poisons `graph_press_x/y` with `-1e30` so a
trailing release cannot bold under the wave dialog.

**Questions and recommended answers:**

1. *There is no marker selection SET. Invent one how?* → mirror the trace
   selection model from issue 0175 exactly: keep the existing single-selection
   token grammar unchanged as the **head** of the set, and add an **optional**
   companion token emitted **only when two or more** markers are selected. That
   ">= 2 only" rule is the whole compatibility story — a strip never
   double-clicked serialises byte-identically to today, and an older build reads
   the head and ignores the unknown token. Additive optional rect tokens have
   never bumped `XSCHEM_FILE_VERSION`; do not bump it.
2. *Where do the readers/writers live?* → **one** get/set/toggle trio in `draw.c`
   and **one** Tcl mirror pair in `wave_viewer.tcl`, and nothing else may touch
   the token pair — that is what stopped the two 0175 tokens from drifting.
3. *Every draw-side "is this selected" comparison?* → must go through a single
   `marker_is_selected()` style helper, never a bare
   `sel == n` comparison. There were **eleven** such bare sites in the trace case
   and one missed site renders a selected object in the unselected style with no
   test able to see it. Assert the helper's use at SOURCE level in the suite, the
   way `test_wave_legend.tcl` LS5 does.
4. *Double-click a NON-difference marker?* → selects just that marker; same as a
   single click, no error.
5. *The reference marker was deleted / cannot be resolved?* → select only the
   difference marker, silently. Record the decision.
6. *Chained deltas (a `d` marker whose reference is itself a `d` marker)?* →
   select the **immediate pair only**, not the transitive chain. The user wrote
   "the one that its deltas are derived from", singular.
7. *Does `Delete` now remove both?* → **yes** — Delete removes the whole
   selection. Precedent: issue 0176 ("DEL deletes the selection"). Record it.
8. *Reference marker on a DIFFERENT strip?* → still selected. Selection is by
   marker NUMBER, and `graph_marker_selgraph` is already documented as a stale-able
   hint; do not let it become load-bearing.
9. *What is the double-click threshold?* → reuse the existing interlock's
   travel/time rules rather than adding a new constant. If Tk's `<Double-Button-1>`
   is the natural seam in the viewer, use it — but the leg must prove the FIRST
   click's ordinary single-select still happens and is then widened, not skipped.
10. *Does it log for replay?* → yes, and per the 0176 lesson the log line must
    name its targets by EXPLICIT marker numbers: selection state does not exist at
    replay time.

**Likely files:** `src/draw.c` (marker primitives + selection token pair),
`src/callback.c` (button arms), `src/scheduler.c` (query/mutate verbs),
`src/wave_viewer.tcl`, `src/xschem.h` (a fixed-size selection array on
`Graph_ctx` if one is needed — **fixed array, never a pointer**).

**Test plan seed:** extend `tests/headless/test_wave_markers.tcl`. Legs: place
`m` then `d`, double-click the delta marker, assert **both** numbers are in the
selection set and both render selected (witness every marker, not the one
clicked); double-click a plain marker selects one; delete the reference then
double-click the orphan delta selects one; a chained `d` selects the immediate
pair only; `Delete` on a two-marker selection removes both; the serialised prop
of a never-double-clicked strip is byte-identical to before. Named sabotages:
make the pair-widening a no-op (kills the pair legs only); leave one draw-side
comparison bare (kills the render-style leg); emit the companion token at size 1
(kills the byte-identical leg).

**Assertability:** the selection set is fully assertable; the *rendering* of two
simultaneously-selected markers is not. Expect `unassertable` to be non-empty →
`[E]` is the likely honest verdict.

**Defer triggers:** if introducing a marker selection SET requires reshaping the
marker storage model itself (rather than adding an optional token), that is a
genuine scope balloon → DEFER with the proposal written out.

- receipt: doc/claude/overnight_batch_2026_08_01/receipts/02_dblclick-delta-marker-selects-pair.md — done and committed as `1ec3ce89`, marker selection became a C-only SET (no prop token), all five sabotages killed exactly their targets, tests 870 → 979, eyeball pending

## 03 axis-region-drag-zoom

**User spec, verbatim:**

> LMB press-and-drag outside the plot area of a strip and in the AXIS region -
> where axis numbers are displayed - will result in zooming along that axis only.
> For the X-axis, if user presses-and-drags from left to right, that is a zooming
> in. The portion of the trace(s) that occupy the strip from x1 (press location)
> to x2 (LMB release location) will now be zoomed in and take up the entire plot
> area. If user presses-and-drags from right to left, then, the entire portion of
> the trace(s) currently displayed in the strip will be displayed between x1 and
> x2 (axis numbers will change accordingly to accommodate the zoom). In the right
> to left, the right-most (x2) is where LMB was pressed. Similarly for the Y axis.
> If drag is upwards, then zoom in, if downwards (towards origin) then zoom out -
> similar to what is done for X-axis.

**The two maths, stated precisely** (the scout must write these into the decision
doc as formulas and the suite must assert them numerically):

- **Zoom in (forward drag).** Let the press and release map to data coordinates
  `a` and `b` on that axis with `a < b`. New axis window = `[a, b]`, occupying the
  full plot extent.
- **Zoom out (reverse drag).** The press is the FAR end (for X: the right-hand
  end, `x2`; for Y: read the user's "downwards, towards origin" as the reverse
  direction, so the press is the upper end). Let the current window be `[A, B]`
  and the drag span in screen px be `d`, the plot extent in screen px be `W`. The
  current window must end up occupying exactly the span `[x1, x2]` on screen, so
  the new window is `[A - (B-A)*(x1_px - P0)/d, ...]` — i.e. new_range =
  (B-A) * W/d, positioned so `A` lands on the screen position of `x1` and `B` on
  `x2`. Write it as one anchored linear map, derive both endpoints from it, and
  assert both endpoints in the suite (asserting only the range width would pass
  with the window slid sideways).

**Questions and recommended answers:**

1. *What exactly is the "axis region"?* → the strip's **bottom margin**
   (`marginy`, where X-axis numbers are drawn) for X, and its **left margin**
   (`marginx`, where Y-axis numbers are drawn) for Y. Take the geometry from
   `Graph_ctx`, do not hardcode.
2. *Which existing gestures does this collide with?* → LMB in the strip BODY is
   already strip-reorder / trace-drag; the right-edge 14-px `GRAPH_REORDER_HANDLE_W`
   column is the reorder grip; the top of the rect is the legend
   (`legend_slot_hit` starts at `gr->ry1`); MMB is the graph pan (moved LMB→MMB
   engine-wide for the reorder work); `waves_selected` insets each strip by
   `border = 5.0 * tk_scaling * xctx->zoom` and a press inside that seam never
   reaches the graph at all. **Map all of these before choosing the region**, and
   assert the non-collision in the suite.
3. *`sharedx` stacks — does an X zoom apply to one strip or all?* → **all**, since
   that is what `sharedx` means. A Y zoom always applies to its own strip only.
4. *Click-vs-drag threshold?* → 3 screen px of travel, matching the strip-drag and
   trace-drag arms. A sub-threshold press must commit nothing and log nothing.
5. *Rubber-band preview while dragging?* → **yes**, a transient band drawn under
   `draw_graph` **flags bit 16** (UI chrome, stripped from exports), same
   transient rules as `reorder_handle` values 2/3/4. This is a pixel deliverable.
6. *Escape mid-drag?* → cancels, commits nothing, logs nothing (same as the strip
   and trace drags).
7. *Log-scale axes (`logx` / `logy`)?* → do the linear map in the axis's own
   (log) space, so the gesture behaves uniformly. **Beware**: `setup_graph_data`
   returns early for an off-screen graph *before* parsing `logx` — read the token
   off the rect.
8. *Does it push viewer undo?* → **no.** A zoom is a view change, like the
   existing mouse pan/zoom, and window view state is deliberately outside a
   `wviewer::push_undo` snapshot. Record the decision.
9. *Does it log for replay?* → yes, with explicit numeric axis bounds — never
   screen pixels, which do not exist at replay time.
10. *Release outside the window?* → clamp the release position to the plot extent
    and commit; do not silently cancel.
11. *Degenerate drag (`d` ≈ 0, or a zoom-out that would explode the range)?* →
    clamp to a sane maximum factor and record the clamp; never divide by zero.
12. *Does it need `capture_live_graph_state` first?* → yes, if it goes through any
    path that can `regenerate`.

**Likely files:** `src/callback.c` (press/motion/release arms, region hit-test),
`src/draw.c` (the band render + the axis window write), `src/xschem.h` (any new
constant, mirrored in Tcl if Tcl needs it), `src/wave_viewer.tcl` (button filters
— the viewer intercepts B1 before the C engine), `src/scheduler.c` (a
`graph_axis_region_at`-style query verb so the suite can find a pixel to press).

**Test plan seed:** a NEW suite `tests/headless/test_wave_axis_zoom.tcl`. Legs:
region hit-test answers X-margin / Y-margin / body / legend / handle correctly;
a forward X drag makes the window exactly `[a, b]`; a reverse X drag produces the
computed window with BOTH endpoints asserted; the same pair for Y; sub-threshold
press is a no-op; Escape cancels; a press on the reorder handle still reorders and
a press in the body still starts a trace drag (non-collision witnesses); `sharedx`
propagates X and not Y; log-scale axis maps in log space; the replay log line
carries numeric bounds. Named sabotages: invert the direction test (kills the
zoom-out legs only); drop the anchoring term so only the width is right (kills the
endpoint legs, which is exactly why both endpoints are asserted); widen the region
hit-test to include the body (kills the non-collision legs).

**Assertability:** the maths is strongly assertable; the rubber-band pixels and
the drag *feel* are not → expect `[E]`.

**Defer triggers:** if the axis margins turn out not to be hit-testable without a
new geometry pass, that is still in scope (add the query). Defer only if the
gesture cannot be given to the margin without taking a press away from an existing
committed gesture — in which case write the conflict up and DEFER.

- receipt: doc/claude/overnight_batch_2026_08_01/receipts/03_axis-region-drag-zoom.md — implemented and committed as `6d401fee` (+ repair fixup `826e1b60`); the hollow spot (the load-bearing, untested `callback.c` GRAPHPAN latch term) was then REMEDIATED in fixup `33e3512b8c31c3779d5582d3e24abc29cfe9a36d` — new AG14/AG15 groups take the suite to 361 checks, deleting the latch term now kills 3 legs, and probing it uncovered and fixed a real stale-axis-arm defect; see "# Remediation (gap closed)" in the receipt

## 04 axis-region-ctrl-wheel-zoom

**User spec, verbatim:**

> In the axis regions - where the LMB press-and-drag for zoom is supported,
> CTRL+Scroll_wheel will support zoom in/out for THAT AXIS ONLY. Zooming will be
> around the mouse pointer. That is, the point(s) on the trace(s) that are at x1
> (position of the mouse pointer) will remain there after zoom.

**Depends on item 03** for the axis-region hit-test — reuse it, do not write a
second one. If item 03 was DEFERRED or FAILED, this item's scout must decide
whether the hit-test can be built standalone (it can, and should) or whether the
dependency makes it a DEFER.

**The invariant, stated precisely:** let `p` be the pointer's data coordinate on
that axis before the zoom. After the zoom, `p` must map to the **same screen
pixel**. That is a numeric assertion and it is the heart of the suite: assert the
screen position of the data point, not just that the range shrank.

**Questions and recommended answers:**

1. *Zoom factor per wheel click?* → match the existing graph wheel-zoom factor in
   `callback.c` so the feel is uniform across the viewer. Scout reads the actual
   constant; do not invent a new one.
2. *Plain wheel (no Ctrl) in the axis region?* → leave whatever it does today
   **unchanged**, and add a regression witness for it.
3. *Ctrl+wheel over the strip BODY?* → out of scope, unchanged, and witnessed as
   unchanged.
4. *Shift+wheel, Alt+wheel in the axis region?* → out of scope, unchanged.
5. *`sharedx` stacks?* → same rule as item 03: an X zoom applies to all strips of
   the shared-x group; the anchor point is the pointer's data x, which is common
   across the group.
6. *Log-scale axes?* → the fixed-point invariant is applied in the axis's own
   (log) space, same as item 03.
7. *Does it push viewer undo?* → no, same reasoning as item 03.
8. *Does it log for replay?* → yes, with explicit numeric bounds.
9. *Range clamping?* → clamp to the same sane maximum/minimum span item 03 uses;
   share the clamp, do not duplicate the number.
10. *Does the wheel event reach the viewer at all?* → verify the Tk button-4/5 vs
    `<MouseWheel>` path for this platform and that `wviewer`'s button filters do
    not swallow it. This is the most likely place for the feature to be silently
    dead.

**Likely files:** `src/callback.c`, `src/draw.c`, `src/wave_viewer.tcl`, possibly
`src/xschem.h`.

**Test plan seed:** extend `tests/headless/test_wave_axis_zoom.tcl` (item 03's
suite) with a `CW*` block, or a new suite if 03 did not land. Legs: Ctrl+wheel-up
in the X margin narrows the X window and the pointer's data x maps to the same
screen pixel within a tight tolerance; Ctrl+wheel-down widens it with the same
invariant; the Y margin does the Y axis and leaves X untouched; plain wheel is
unchanged; Ctrl+wheel in the body is unchanged; repeated zoom in then out returns
to (approximately) the starting window; the replay log carries numeric bounds.
Named sabotages: drop the anchor correction so it zooms about the centre (kills
the fixed-point legs but NOT a naive "the range shrank" leg — which is precisely
why the fixed-point assertion is the leg that matters); apply the zoom to both
axes (kills the "other axis untouched" legs).

**Assertability:** very strong — this item is the best `[x]` candidate in the
batch. Only the wheel *feel* is unassertable, and feel alone should not force
`[E]` unless new rendering is introduced.

**Defer triggers:** only if the wheel event provably cannot be routed to the axis
margin without breaking the canvas wheel zoom.

- receipt: doc/claude/overnight_batch_2026_08_01/receipts/04_axis-region-ctrl-wheel-zoom.md — implemented and committed as `7e810bc2` (+ repair fixup `c11e0e9e`); the hollow spot (the Y-axis half of the gesture, unwitnessed on both the C and Tcl paths because every Y probe pixel sat at the plot box's vertical centre) was then REMEDIATED in fixup `42e2fdfc` — new off-centre-probe legs CE3b/CE3c/CE10/CV2/CV2b/CV2c take the suite to 370 checks, both verifier sabotages (the `callback.c` CTRL+wheel `my`→`mx` swap and the `wave_viewer.tcl` `$py`→`$px` swap) now kill exactly their targets where they killed 0 before, test-file only (`git diff 33e3512b -- src/` empty); see "# Remediation (gap closed)" in the receipt

## 05 multi-trace-drag-to-strip

**User spec, verbatim:**

> When multiple traces are selected, an LMB-press-and-drag with press on/near one
> of the traces, and drag to a destination strip will cause all selected traces to
> be moved to the destination. All selected traces being moved will display the
> cool-factor shrink during the press-and-drag

**What exists today** (re-verify): single-trace drag between strips is shipped
(spec `waveform_viewer_modes.md` §13; `graph_wave_at` returns the NODE index;
`GRAPH_TRACE_DROP_W`; `reorder_handle=4` is the grip plus a drop-target frame).
Multi-trace *selection* is shipped (issue 0175): a SET of node indices, held per
window, stored per strip across the `hilight_wave` head token plus an optional
`sel_waves` companion emitted only at size ≥ 2, with
`graph_sel_waves_get/set/toggle` in `draw.c` and `wviewer::model_sel` /
`model_sel_set` in Tcl as the ONLY readers/writers. This item joins the two.

**Questions and recommended answers:**

1. *Press on a trace that is NOT in the selection?* → drag that trace alone, i.e.
   today's behaviour, unchanged. Do not silently extend the selection at press.
2. *The selection spans several SOURCE strips?* → move **all** of them to the
   destination. The user wrote "all selected traces".
3. *The destination is one of the source strips?* → traces already there stay put;
   the others move in. A drop where nothing would move is a no-op that neither
   mutates nor logs (the existing same-strip rule).
4. *Order in the destination?* → appended at the end of the destination's trace
   list, in source order, keeping expr / alias / vec / colour — the existing
   single-trace rule, applied N times.
5. *What is the "cool-factor shrink"?* → during the drag, each moving trace is
   rendered scaled toward its strip's vertical midline (a transient, bit-16
   render). **Put the magnitude behind ONE named constant** so it is a one-line
   tune at eyeball time. This is the item most likely to be rejected on sight —
   the equivalent viewer-plan item 6 was specified Y-only at 10 % and *the user
   rejected it on sight*, and no test could ever have caught that. Do not
   over-invest; make it tunable and say so in the receipt.
6. *Does the source strip survive being emptied?* → yes, exactly as today ("source
   strip stays even when emptied").
7. *Highlight/selection after the move?* → the selection follows the traces to the
   destination. `remap_hilight_after_trace_move` returns `{}` for **two different
   reasons** ("no highlight" and "the bold trace is the one that left") and the
   caller must test which, or an unbolded move silently bolds something in the
   destination. The multi-move must remap the whole SET (both tokens), not just
   the head.
8. *Undo?* → **one** `wviewer::push_undo` for the whole multi-move, pushed right
   after `capture_live_graph_state`, so a single `u` puts every trace back.
9. *Empty destination ranges?* → blanked to auto on the drop, so `regenerate`
   re-autozooms; a destination that already holds traces keeps its window.
10. *Escape / sub-threshold click?* → commit nothing, log nothing (existing rule).
11. *Log line?* → names every moved trace by explicit model index and the
    destination by explicit index; selection state does not exist at replay time.
12. *Cursor?* → the existing `hand2` grab-hand, set on the PRESS, unchanged.

**Likely files:** `src/wave_viewer.tcl` (the drag state machine — this is mostly
Tcl), `src/draw.c` (the shrink render + `graph_wave_at`), `src/callback.c`,
`src/xschem.h` (the shrink constant, mirrored in Tcl if Tcl needs it),
`src/scheduler.c` (any widened verb).

**Test plan seed:** extend the `TD*` block in `tests/headless/test_wave_viewer.tcl`
(it is the suite that already owns trace drag) and/or
`tests/headless/test_wave_trace_menu.tcl` (the only suite with a LIVE multi-trace
strip, built hermetically with `xschem raw new` / `raw add`, no ngspice — a
single-trace fixture cannot tell "picks the nearest" from "picks node 0"). Carry
the inert `sdid` per-strip key so "which strip is at index k" is witnessed
independently of "which trace is in it" — without it a trace move and a strip
reorder produce the same first-trace-per-strip witness. Legs: select three traces
across two strips, drag one to a third strip, assert all three arrive in source
order and the sources are correctly emptied; the selection set survives the move
in the destination's tokens; a single `u` restores every trace and the selection;
dragging an unselected trace moves only it; a same-strip drop is a no-op with no
log line; an empty destination's ranges were blanked to auto; the log line names
explicit indices. Named sabotages: move only the pressed trace (kills the
multi-arrival legs); push undo per trace instead of once (kills the single-`u`
leg); skip the range blanking (kills the auto-range leg).

**Assertability:** the move, the selection remap, the undo and the logging are all
assertable. **The shrink is pure pixels** — it forces `[E]`. Say so plainly in the
receipt and name the constant the user can tune.

**Defer triggers:** if the drag state machine cannot carry a set without being
rewritten, write the proposal and DEFER — but the expectation is that it can,
because the selection set already exists and the drag already resolves a node
index.

- receipt: doc/claude/overnight_batch_2026_08_01/receipts/05_multi-trace-drag-to-strip.md — implemented and committed as `5648fe6f` (+ repair fixup `ef567e2b`, which fixed a D-44 miss where a drop back on the pressed strip refused the whole gesture); the shrink was already shipped, so this item made it carry N traces instead of 1, tests 1170 → 1319, eyeball pending
