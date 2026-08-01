# Resume prompt — reuse empty strips in the trace-move and strip-split gestures

Paste the block below into a fresh session.

---

Two enhancements to the waveform viewer's just-landed context-menu gestures, both
about **not creating a strip when an empty one is already sitting there**.

**State.** Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`.
HEAD `8c688230`; `github/fluid-editing` is at `0f1720de` (someone pushed items
7/8/6 already, so only two doc commits are local). **Do not push unless I say so.**

## What to change

1. **`wviewer::move_trace_to_new_strip`** (`src/wave_viewer.tcl` ~3087) — "move this
   one trace to a strip of its own". It currently *always* `linsert`s a fresh
   `empty_graph` at `from_gi + 1`. Change it to **consume an existing empty strip
   when one exists**, anywhere in the stack, and only insert when there is none.

2. **`wviewer::split_strip`** (~3200) / **`wviewer::split_graph_in_graphs`** (~3167)
   — "one strip per trace". It currently inserts `nc - 1` fresh empty strips at
   `gi + 1`. Change it to **consume an ADJACENT empty strip if one exists**, and
   insert only the shortfall.

The asymmetry is deliberate and is mine, not a slip: the single-trace move may take
*any* empty strip; the split may only take an *adjacent* one.

## READ FIRST

1. `doc/claude/specs/waveform_viewer.md` — the "Trace context menu", "Strip context
   menu" and "Delete Empty Strips" sections. These three interact.
2. `src/wave_viewer.tcl` `plan_plot` header comment (~1185-1216). **This is the
   feature you are extending, already solved for a different gesture** — issue
   0171's follow-up made plot batches reuse empty strips, and its header states
   the whole rationale plus the auto-strip exclusion. Copy its reasoning; do not
   re-derive it.
3. `doc/claude/code_analysis/waveform_subsystem_reference.md` §11 (landmines).

## Seams that already exist — compose, do not reinvent

| what | where | note |
|---|---|---|
| `wviewer::empty_graph_indices {gs {auto -1}}` | ~1170 | the empty-strip enumerator, **with the auto exclusion already an argument** |
| `wviewer::auto_graph_index {token}` | ~1279 | what to pass as `auto` |
| `wviewer::move_trace_in_graphs {graphs from_gi from_ti to_gi}` | ~2900 | PURE; already blanks an EMPTY destination's ranges back to auto, which is exactly the reuse case — so autozoom keeps working for free |
| `wviewer::index_after_insert {index at {count}}` | ~2222 | only needed for the strips you still have to insert |
| `plan_plot`'s reuse arm | ~1231-1238 | `set reuse [lrange $free 0 [expr {$n - 1}]]` then `set new [expr {$n - [llength $reuse]}]` — the shortfall pattern, verbatim |

⚠ **`empty_graph_indices` means "zero model traces", not "node_count == 0".** A
strip holding only `vec`-less traces is NOT empty by that definition. Item 5's `e`
uses the same definition, so keep it — but say so in the spec rather than leaving
it implied.

## Decisions to make BEFORE writing code — answer them in the spec

- **D1 (single move): which empty strip, when several are free?** Recommend
  **nearest below `from_gi`, else nearest above, else insert at `from_gi + 1`**.
  Rationale: "below" is D-F's reading-order direction, and nearest keeps the trace
  near where it was picked up. State the tie-break explicitly.
- **D2 (single move): is a FAR empty strip really wanted?** Taking an empty strip
  seven positions away is correct per my request but may read as the trace
  teleporting. If you think a distance cap is needed, propose one and default it
  off — do not add it silently.
- **D3 (split): does "adjacent" include ABOVE (`gi - 1`)?** Recommend **NO, only
  `gi + 1`.** An empty strip above would put node 1 above node 0 and break the
  reading order D-F exists to preserve. If you disagree, say why in the spec.
- **D4 (split): only ONE adjacent slot exists, but a split needs `nc - 1`.**
  Recommend: consume `gi + 1` for node 1, insert the remaining `nc - 2` after it.
  So an empty strip immediately below is absorbed and the rest are new.
- **D5 (target strip).** `move_trace_to_new_strip` currently makes the destination
  the target (move_trace step 6). Keep that when reusing. `split_strip` shifts the
  stored target through the insert and does not adopt a destination — with fewer
  inserts the shift is smaller; make sure `index_after_insert` is called with the
  ACTUAL insert count, not `nc - 1`.

## Hard constraints

- **NEVER consume the auto-plot strip.** It is traceless *between runs* and item 13
  rebuilds it after every simulation — a trace moved there is silently destroyed at
  the next run. `empty_graph_indices` takes the exclusion as its `auto` argument;
  pass `wviewer::auto_graph_index`. This is decision D-D, already load-bearing for
  item 5.
- **`move_strip`'s ordering contract, unchanged**: validate → refuse without
  logging → verified `switch_ctx` → `capture_live_graph_state` → `push_undo` →
  mutate → target in place → ONE `regenerate` → ONE log line.
- **The log lines must stay as they are** (`move_trace_to_new_strip <gi> <ti>
  <token>`, `split_strip <gi> <token>`). Replay stays deterministic because the
  same model produces the same reuse choice — but assert that, do not assume it.
- **The PURE core stays pure.** The reuse decision belongs in a pure proc taking
  `graphs` + the auto index, so it is assertable with literal lists under
  `--nogui`. `split_graph_in_graphs` is already pure; keep it that way.
- Return values: `move_trace_to_new_strip` returns the destination index (now
  possibly an existing strip); `split_strip` returns the NUMBER OF NEW STRIPS —
  which with reuse may now be smaller than `nc - 1`, or **zero**. Decide whether
  zero-new-strips is still a success (recommend yes) and pin it.

## ⚠ THE HOLLOWNESS TRAP — read before writing a single leg

**Reuse and insert can produce an identical-looking model.** If the free empty
strip happens to sit at `gi + 1`, "consume it" and "insert one at `gi + 1`" leave
the same trace in the same visual position. A leg that only checks
`vecs_at $tok 1` passes either way.

Two discriminators, use both:

1. **STRIP COUNT is the signal.** Reuse leaves `llength $graphs` unchanged; insert
   grows it. Assert the count on every reuse leg.
2. **STRIP IDENTITY.** Put an inert key on the fixture's strips
   (`dict replace $G sdid A` — `regenerate`/`graph_props` read known keys only, so
   it changes nothing) and assert *which* strip the trace landed in. Precedent:
   `tests/headless/test_wave_viewer.tcl` ~1699-1718 (the SD legs) does exactly this
   for the same reason.

Also still true from last session:

- **`target_index` CLAMPS**, so target legs go hollow on a shallow stack — build the
  fixture so the clamped and the correct answers differ (`TG4`/`SG4` precedent).
- **Test both index spaces.** Plant a `vec`-less trace so model and node indices
  diverge, or the mapping is untested.
- A suite's check **COUNT** is the signal, not its verdict.

## Tests

Extend the two existing suites rather than adding a third — the gestures are theirs:

- `tests/headless/test_wave_trace_menu.tcl` (currently **128** DISPLAY / **34**
  nogui)
- `tests/headless/test_wave_split_strip.tcl` (currently **122** / **38**)

Both already have PURE `TP*`/`SP*` halves built from literal dicts — the reuse
decision should be assertable there with no window at all. Sabotage-verify every
new leg; at minimum, sabotage "reuse always, never insert" and "insert always,
never reuse" and confirm each turns different legs red.

Full battery that must stay green at these counts:
`test_wave_snap` 59, `test_wave_grid` 80, `test_wave_legend` 44,
`test_wave_empty_strips` 94, `test_wave_modes` 385, `test_wave_markers` 712,
`test_wave_viewer` 349, `test_wave_clear_all` 68, `test_ase_plot` 145.

⚠ **`test_wave_empty_strips` is the suite most likely to break** — `e` deletes
empty strips, and these changes make empty strips get consumed instead. Check the
interaction deliberately: after a reuse there should be *fewer* empty strips for
`e` to find, and D-C (never delete the last strip) still holds.

## Process

Run suites through `tests/headless/run_suites.sh` with `SUITE_TIMEOUT=900`, never a
bare loop, or the GUI-test gate cannot pause them. **Soak the DISPLAY arm 10x** —
last session that is what caught a pre-existing 3-in-10 `wviewer::open` bug no
single run reproduces.

Then: **build → suites green → COMMIT → raise
`tools/review_gate/review_gate.sh` in the background.** Never push.

Two items, so two commits. This is small and well-scoped with a pure core, so run
it as an IMPLEMENTER session, not a driver round — see
`doc/claude/suggestions/orchestration_driver_vs_implementer.md` for why (a driver
harness is overhead below ~5 mechanical items, and the five decisions above are
exactly the kind a pipeline would implement wrongly but faithfully).

## Docs to update

- `doc/claude/specs/waveform_viewer.md` — the two gesture sections, with D1–D5
  recorded as decisions and the "zero model traces" definition stated.
- `doc/claude/suggestions/plan_viewer_enhancements_2026-07.md` — a follow-up note
  under items 7 and 8; the ledger's item-6-round-2 line is still `TIMEOUT /
  un-eyeballed, and items 7 and 8's menus are still un-eyeballed too. Do not let
  this work bury that debt.
