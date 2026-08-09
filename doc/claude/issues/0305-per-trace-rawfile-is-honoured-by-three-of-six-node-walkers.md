# 0305 — a per-trace `%<rawfile>` is honoured by three of the six `node=` walkers

**Status:** OPEN
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
   it on a strip with two foreign DBs.
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

## Not fixed because

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
