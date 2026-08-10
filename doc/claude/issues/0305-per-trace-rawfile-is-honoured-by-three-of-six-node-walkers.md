# 0305 — a per-trace `%<rawfile>` is honoured by three of the six `node=` walkers

**Status:** FIXED 2026-08-09 (batch F item 1) — see "The fix, as landed" below.
The residuals it left (defect 1 below, plus `graph_fullyzoom()`'s two leaking early
returns and the carried sweep column) are **FIXED 2026-08-09, batch F item 2** — see
"The residuals, as landed" at the end. Defect 2 below (`graph_fullxzoom()`) stays OPEN:
it is spec D2, a different feature.
**Found:** 2026-08-09, while wiring spec §D1 (`doc/claude/specs/mixed_signal_signal_browser.md`)
**Area:** `src/draw.c` (graph rendering / graph interaction)
**Severity:** a cross-DB trace RENDERS correctly but is inert to every mouse gesture

## What

A graph rect's `node=` attribute is a newline-separated list. One entry is

```
[alias;]<vec-or-RPN> [ '%' [<dataset-digits> ] <rawfile> [ <sim_type> ] ]
```

Six functions in `src/draw.c` walk that list. All six parse the `%`. Only **three**
do anything with the `<rawfile>` part; the other three read the leading
**dataset digits** and then silently drop the rest of the field:

| function | line | what it drives | honours `%rawfile` |
|---|---|---|---|
| `draw_graph()` | draw.c:8185-8215 | THE RENDERER | yes |
| `graph_fullyzoom()` | draw.c:3452-3482 | Y autoscale | yes |
| `find_closest_wave()` | draw.c:4990-5017 | nearest-trace hit test | yes (but its restore is unbalanced — see below) |
| `graph_point_at()` | draw.c:5948-5955 | pick / hover / marker create + drag | **NO** |
| `wave_hilight_envelope()` | draw.c:6364-6371 | trace bold / highlight overlay | **NO** |
| `graph_wave_resolve()` | draw.c:7410-7416 | marker VALUE readout | **NO** |

The three that do honour it call
`extra_rawfile(<autoload>, <rawfile>, <sim_type>, -1.0, -1.0)`, draw/evaluate that
one trace against that database, and switch back. The three that do not evaluate
the trace's name against **whatever database happens to be current** — which for a
mixed analog+VCD strip is the analog one, where a VCD signal name does not exist.

## Symptom

With `src/wave_viewer.tcl` now emitting `%<rawfile> <sim_type>` for a trace picked
from a non-current database (spec §D1), a VCD trace in an otherwise analog strip:

* **draws correctly** — proved by `tests/headless/test_wave_crossdb_trace.tcl`
  (pixel probe: the analog sine's extremes land on the VCD square wave's edges);
* **cannot be picked** — clicking it selects a different trace or nothing;
* **cannot be bolded** — the LMB wave-bold click (issue 0152) resolves the name in
  the wrong DB, so the envelope is empty;
* **cannot be marked** — `m`/`d` markers create against the wrong DB, so the value
  readout is blank or shows another trace's number.

## Two smaller defects noticed in the same sweep

1. `find_closest_wave()` (draw.c:4990-5017) DOES switch, but its restore is not the
   balanced per-node `if(save_extra_idx != -1 && save_extra_idx != xctx->extra_idx)`
   pair that `draw_graph()` uses at draw.c:8438 — worth re-reading before trusting
   it on a strip with two foreign DBs. **STILL OPEN** after the 2026-08-09 fix: its
   `%` parse moved into `node_token_split()` with the rest, but its single mode-5
   restore outside the node loop was left exactly as it was. **FIXED in batch F item 2**
   (2026-08-09): it now has `graph_point_at()`'s two-level bracket.
2. `graph_fullxzoom()` (draw.c:3284-3391) never parses `%` **at all**, and
   `wviewer::graph_props` emits no per-rect `rawfile=` token, so an auto X window
   spans the CURRENT database's extent only. MEASURED with the reference co-sim
   pair: `tb_counter_wrapper_ase.raw` spans 0..2 µs, `counter.vcd` spans 0..500 ns,
   and the auto window is 0..2 µs — the VCD trace occupies the left quarter of the
   strip and simply stops. That one is **spec §D2** (joint X domain) and is already
   tracked there; it is repeated here because it is the same root shape.

## Fix sketch

The `%` parse is copy-pasted six times with three different behaviours. The honest
fix is ONE helper — `node_token_split(ntok, &vec, &dataset, &rawfile, &sim_type)` —
plus the switch/restore bracket `draw_graph()` already gets right, applied at all
six sites. Adding a seventh copy is how this drifted in the first place.

## The fix, as landed (2026-08-09, batch F item 1)

`src/draw.c` gained ONE parser and ONE restore primitive, and every one of the six
walkers calls them:

```c
static void node_token_split(const char *ntok, char **expr, int *dataset,
                             char **rawfile, char **sim_type,
                             const char *dflt_sim_type);
static const char *node_dflt_sim_type(const char *graph_sim_type);
static void node_db_restore(int idx);       /* extra_rawfile(2, "<idx>", ...) */
```

`node_token_split()` parses and Tcl-`subst`s; it switches nothing. The switch, and
the restore that must pair with it, stay at the call site, because only the call site
knows where the unwind point is.

**The restore is an ABSOLUTE INDEX, not `extra_rawfile()`'s mode-5 swap.** This fix
nests a per-trace switch inside the graph-level `rawfile=` switch that
`graph_point_at()`, `wave_hilight_envelope()` and `graph_marker_sample()` already made.
Mode 5 is a SWAP, not a stack pop: unwinding two levels with it lands the session on the
inner database. Both levels now go through `node_db_restore()`, and absolute restores
compose. The three affected graph-level restores changed from `extra_rawfile(5, ...)` to
`node_db_restore(entry_extra_idx)` for that reason.

`graph_wave_resolve()` is the one that cannot close its own bracket: the `idx` and
`sweep_idx` it returns are COLUMN NUMBERS IN THE TRACE'S DATABASE, so the switch must
still be in force while the caller reads them. It therefore reports the slot to unwind
to through a new `int *db_restore_idx` out-parameter, and its single caller
`graph_marker_sample()` restores at its single `done:` label. That caller's `point`
bounds check moved BELOW the resolve for the same reason: `point` indexes the trace's
own database.

Two behavioural consequences worth naming:

* an unresolvable per-trace database now REFUSES the trace instead of falling back to
  the current one. Before the fix, an entry naming a nonexistent `.raw` was pickable,
  boldable and markable — answering with whatever the current database happened to hold,
  under the missing trace's name.
* the sweep column is looked up in the trace's own database, as `draw_graph()` has always
  done, kept in a per-node copy so a short `sweep=` list still carries forward correctly.
  **Corrected in review:** it is re-looked-up **by NAME on every entry that took the
  switch**, not only on the entries carrying their own `sweep=` token. The first cut
  carried the *index* forward across the switch, and an index resolved in a five-column
  analog raw subscripts a three-column VCD out of bounds — pick, bold and marker each
  SIGSEGV'd on a strip whose `sweep=` list was shorter than its `node=` list. See the
  sweep-column ruling in `doc/claude/specs/mixed_signal_signal_browser.md` §D1.

**Proof:** `tests/headless/test_node_token_split.tcl`, 91 checks, true headless (in
`full_audit.sh`'s `nogui_tests`). **19 of them are red at the parent commit `96f7678a`**,
covering all three of the broken walkers plus the silent-fallback defect; the `NDS` leg
covers the carried-sweep segfault, `NDT` the inherited-sim_type arm, and `NDX` reads
`draw.c` itself so that a seventh hand-rolled `%` parse cannot reappear unnoticed.
Thirty-one sabotages injected across the two rounds, every one caught — including one
that reverts the index restore to the mode-5 swap and reddens 16 checks by leaving a bare
envelope walk on the wrong database. Two source-level WH9h checks in
`tests/headless/test_wave_hilight.tcl` were RESTATED (not deleted): the unwind mechanism
and the switch count both genuinely changed.

`find_closest_wave()` is only reachable from `callback.c`'s graph motion handler — a real
DISPLAY — so its `%` parse moved into the shared helper but was NOT exercised
behaviourally by that test.

## Not fixed before because

Out of scope for the §D1 item (whose deliverable was the render plus the Tcl
emission). Fixing three C functions and their restore brackets is its own change
with its own gesture-level regression risk, and the batch it was found in
explicitly scoped C changes out.

---

## Addendum, 2026-08-09 — the §D1 review round

A three-lens adversarial review of the §D1 change found three further defects,
**all created by that change** (at its parent commit a cross-DB trace cannot be
created at all, so none of them existed before). All three are FIXED in the same
uncommitted tree; the residual limitations they leave are recorded below rather
than filed as new issue numbers.

### Fixed

1. **A saved cross-DB trace came back silently blank.** `wviewer::restore`
   (`src/wave_viewer.tcl`) cleared the raw registry and re-read ONE database —
   the session's analog raw — so a trace whose `node=` token ended in
   `%<rawfile> <sim_type>` asked `extra_rawfile()` to switch to a database that
   was no longer registered. That arm returns 0 at `dbg(1)` (save.c:1663): the
   strip still LISTED the signal in its legend and drew nothing, which reads as
   "that signal is flat", not "the data is gone". `restore` now takes the extra
   databases as a fifth argument (`ase::ui::viewer_restore` fills it from
   `ase::last_vcdfiles`, the list `dp_finish` and `auto_plot` already pass to
   `attach_raw`) and UNIONS it with the databases its own restored traces name
   (`wviewer::trace_dbs`). Measured across two processes by
   `tests/headless/test_wave_crossdb_trace.tcl`'s XS leg: red pixel columns
   145 (legend only) → 510 (the trace draws).
2. **The signal browser plotted the wrong database, silently.** The tree row id
   already carries the database (`d:2|s:TOP.m.sig`); `browser_leaf_names` threw
   that away, so with the same signal in two VCDs — exactly what spec §E
   produces when two `d_cosim` blocks instantiate the same Verilog module — a
   double-click under blockB's header plotted blockA's waveform, and selecting
   BOTH rows and pressing Plot produced ONE trace. `browser_leaf_specs` now
   answers `{name db}` pairs, `browser_plot_ids` dedupes on the PAIR, and the
   database is carried through to `add_trace`'s new `db` argument.
3. **A comment cited a nonexistent issue 0301** and four stale `draw.c` lines.
   Every line/file citation in the §D1 comment block, in this issue, in the
   spec's §D1 write-up and in the test's header was re-verified against the tree
   on 2026-08-09.

### Still not fixed (residual, deliberate)

* **The Add Trace… dialog and the browser's context menu stay NAME-ONLY.**
  `wviewer::browser_menu_names` still dedupes on the bare name, and
  `browser_send_to_add_trace` fills a TEXT ENTRY — a string the user may then
  edit, which cannot carry a database. So "Send to Add Trace…" on two same-named
  rows in different DBs yields one entry, and `resolve_signal_db`'s decision 4
  ("the current DB wins, then the lowest-index other DB") picks the database.
  That is the correct contract for a name; it is recorded here because it means
  the *menu* route still has defect 2's shape while the *plot* route no longer
  does.
* **The lower pane (the "sea") is CURRENT-DB ONLY.** `browser_reload` builds its
  entry snapshot from the current DB's inventory alone, and `browser_id_path`
  strips the `d:N|` prefix — so selecting a FOREIGN database's node in the tree
  shows the CURRENT database's names at that level, and `browser_sea_plot_idx`
  plots them by name. This predates §D1 (it is item 11/15's shape, not this
  change's) but it is the same root: the database identity is dropped from the
  id. Fixing it means giving the sea snapshot a per-DB dimension.
* **A named database that is missing on disk is REPORTED, not repaired.** The
  restore says so once per database, naming the traces that will draw nothing,
  and the session still opens. The traces keep their `%` suffix on purpose:
  stripping it would make them resolve against the analog raw and plot a
  DIFFERENT signal, and dropping them would discard the user's layout over a
  transient mount failure. Re-mount and reopen and they come back.
* **The per-signal database list reaches `plot_signals` through a namespace arm
  (`wviewer::plot_dbs_arm` / `plot_dbs_take`), not a fifth parameter.**
  `tests/headless/test_wave_sigbrowser.tcl` BM05 pins
  `proc wviewer::plot_signals {token exprs {colors {}} {destover {}}}` by
  LITERAL STRING MATCH, and both of that suite's plot_signals spies are declared
  with four parameters — a five-argument call is "too many arguments", swallowed
  by `browser_plot_ids`' own catch, and every BT gesture check there reads as
  "the gesture did nothing". If that pin is ever relaxed, collapse the two procs
  into a `{dbs {}}` parameter; the shape wants to be `colors`'.
* **`db_by_index` and `resolve_signal_db` each cost one `signal_list_all`,**
  i.e. one pass over the registry with a DB switch per slot, PER SIGNAL. A
  browser Plot of N foreign signals therefore switches the engine's current DB
  O(N·D) times. This is `resolve_signal_db`'s pre-existing cost profile, not new,
  and it is invisible at browser-selection sizes; a whole-group plot out of a
  large VCD is where it would first be felt, and a per-batch memo is the fix.

---

## The residuals, as landed (2026-08-09, batch F item 2)

Three defects, one shape: **an exit path that skips the epilogue, and an index that
outlives the database it was resolved in.** Rulings and their evidence are in
`doc/claude/specs/mixed_signal_signal_browser.md` §D1b; the receipt is
`doc/claude/batch_F/receipts/02-0305-residuals-swap-restore-and-leaks.md`.

1. **`find_closest_wave()`'s mode-5 SWAP → the balanced two-level bracket.** Its
   graph-level `rawfile=` switch was made once per NODE inside the walk and unwound by a
   single `extra_rawfile(5, …)` after it, run whether or not the switch had taken. It now
   switches once above the loop behind a `switched` flag and restores by absolute index,
   per node and once at the end — `graph_point_at()`'s shape exactly. It also re-resolves
   the sweep column by name and clamps it, for the reason below.

2. **`graph_fullyzoom()`'s two `return 0`s → one `goto fullyzoom_done` epilogue.** Each
   refusal hand-copied a subset of the function's frees, and each subset was wrong:
   `ntok_copy` was in neither (**13 bytes leaked per refused fullyzoom, measured with
   `-d 3 -l log` + `src/track_memory.awk`: 5 vs 205 refusals in one process gave 895 →
   3495 bytes broken, 830 → 830 fixed**) and neither restored the database. **Correction
   to the addendum below: `express` did NOT leak** — it is scoped inside the
   `if(!bus_msb)` block and freed unconditionally before either refusal is reachable.

3. **The carried sweep column, in `draw_graph()` and `graph_fullyzoom()`.** The D1 ruling
   "re-resolve the sweep column BY NAME after a per-trace switch" was written for the
   three walkers that had such a switch at the time; the other three resolve the column
   only for entries carrying their OWN `sweep=` token, and a short `sweep=` list carries
   the previous entry's forward. A five-column raw's column 4 used as a three-column
   VCD's `values[4]` is **not latent**: reverting the fix makes the headless suite die
   with `FATAL: signal 11`, and makes an on-display probe SIGSEGV inside `zoom_full`'s
   redraw. All six walkers now keep the sweep NAME, re-resolve after the switch and clamp
   against the switched-in `nvars`.

**New test seam.** `find_closest_wave()` was reachable only from `callback.c`'s graph
`t` key arm, so nothing headless could see it — which is why its restore was the one that
drifted. `xschem get graph_closest_wave <graph_idx> <px> <py>` (draw.c
`graph_closest_wave()`, scheduler.c `get` branch) answers `"<dataset> <node_index>"` at a
canvas pixel, read-only and fail-soft.

**Proof:** `tests/headless/test_node_token_split.tcl` grew from 91 to 118 checks (legs
`NDC` bracket, `NDL` epilogue, `NDW` sweep column, `NDR` structural, plus three NDF
premise checks); fifteen sabotages were injected, thirteen caught, two uncaught and named in the
receipt. No existing check was renumbered or deleted.

### Fix round on the residuals (2026-08-09) — five review findings, all with reproducers

1. **The registry cursor is a PAIR, and only half of it was restored.** `extra_prev_idx`
   is where `xschem raw switch_back` goes; every `extra_rawfile()` switch overwrites it,
   and in READ mode so does a FAILED one. So entering with prev=1/current=3 and making ONE
   call to `graph_closest_wave`, `graph_trace_at`, `wave_hilight_points` or a refused
   `fullyzoom` sent the next `switch_back` to slot 2 — a read-only getter moving the
   session. A family property (two of those four are unchanged HEAD code), fixed
   family-wide: `node_db_prev_restore()` in all six walkers, once each, at the graph-level
   unwind. Checks `NDU0`–`NDU5` + `NDR7`.

2. **The query verb wrote to stderr once per call.** `find_closest_wave()`'s
   "closest dataset=" trace was `dbg(0, …)`, i.e. unconditional (`debug_var` is 0 in a
   normal run). Once-per-gesture at HEAD, once-per-QUERY with the new verb — 25 lines per
   suite run. Now `dbg(1, …)`; check `NDR8`.

3. **`NDL3` asserted a property nothing measured, and paragraph 2 above over-claimed.**
   The two `graph_fullyzoom()` refusals are NOT symmetric: the graph-level switch is
   loop-invariant, so its refusal can only fire on iteration 1, where `ntok_copy` is still
   NULL and no switch is outstanding — the pre-item `return 0` there leaked nothing and
   stranded nothing, and reverting it alone left `NDL1`–`NDL5` green. **The leak and the
   missed restore were the PER-TRACE refusal's alone.** What the graph-level refusal does
   leave behind is the cursor's other half (finding 1), so `NDL3` now runs that strip with
   `autoload=true` and asserts `switch_back`'s destination; reverting the first refusal now
   reddens it.

4. **The LEAK half of residual (b) was covered by nothing.** Deleting the epilogue's
   `my_free(_ALLOC_ID_, &ntok_copy)` reintroduced a leak larger than the one this issue
   fixed and left all 118 checks green. `NDK0`–`NDK2` now measure it from the test itself:
   two child processes (`tests/headless/leakprobe_fullyzoom.tcl`, in the repo), 5 vs 55
   refusals, `-d 3 -l <log>` + `src/track_memory.awk`, slope must be 0. With the free
   deleted: 830/830 → 895/1545, `NDK1` red.

5. **The mouse-mirror put-back was covered by nothing** — deleting it left all 118 green.
   `NDC9` watches it through `xschem closest_object`, the production consumer of
   `xctx->mousex/mousey`, with the reference captured BEFORE the file's first query (after
   it, the parked mirror makes any before/after pair match and the check passes against
   broken code).

`tests/headless/test_node_token_split.tcl` is now **130 checks**. **Raised and NOT
confirmed, no code changed:** `graph_fullxzoom()` resolving its sweep index before the
master-rect switch — no reproducer was offered and D2 already owns that function.
