# OVB-01 — `m` / `d` place a marker ANYWHERE inside a strip's PLOT BOX

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`. You are the
**implement** stage of overnight batch 2026-08-01 item **01**. The scout verdicted
**PROCEED** and re-verified every anchor below from source on **2026-08-01**.

The shape (decided — do **not** re-litigate; the reasoning is in the decision doc):
**three lines inside one primitive.** `graph_marker_create()` stops asking "is a
trace within 20 screen pixels of the pointer" and starts asking "is the pointer
inside this strip's PLOT BOX" — the same gate the item-9 diamond snap cursor
already uses — then picks the nearest sample of the nearest trace **however far**
with `graph_point_at(..., 1e30, ...)`, which is byte-for-byte the call the diamond
makes. So the marker lands exactly under the diamond, by construction. Trace
SELECTION keeps its 10-px proximity (`GRAPH_TRACE_PICK_TOL`), which the user
explicitly called good — **do not touch that constant.**

## READ FIRST (in order)

1. `doc/claude/code_analysis/ovb01_01_marker_anywhere_in_plotbox_decision.md` —
   the decision doc. §3 is the design, §4 is every resolved spec hole, §6 lists
   four PLAN.md claims that source refutes (read those before trusting the
   PLAN notes), §7 is the assertion list, §8 the test plan.
2. `doc/claude/code_analysis/waveform_subsystem_reference.md` — the WIRING.md of
   waveforms. Landmines **3** (`cy` is negative), **11** (local `Graph_ctx`),
   **19** (a graph gesture does not dirty — markers deliberately do), **33**
   (`graph_near_wave` ≠ `find_closest_wave`), **35** (raw, never log-space),
   **36** (`graph_top` and the GRAPHPAN routing latch), **37**
   (`setup_graph_data` is not safe as a query), **41** (`graph_marker_notify` is
   `has_x`-gated ⇒ nothing about the viewer model is observable under `--nogui`),
   **44** (the snap-grid override is handler-local).
3. `doc/claude/specs/graph_markers.md` — §2 decisions, §6.1 keys, §6.3 refusals,
   §6.4 what is drawn, §10.1 the exported inventory + the constants paragraph.
4. `doc/claude/specs/waveform_viewer_modes.md` §15.1 (the LMB/RMB ownership
   table) and **§15.7** (what a HOVER draws, by region — the table that says the
   legend band and both axis margins draw **nothing**; that is the argument for
   the plot box being the gate).
5. `doc/claude/overnight_batch_2026_08_01/PLAN.md` — the header (verdict alphabet,
   run policy, PREFLIGHT baseline, universal facts, test discipline) and the
   `## 01 marker-anywhere-in-plotbox` section.
6. `CLAUDE.md` — build, tests, conventions.
7. Templates you will copy from: `tests/headless/test_wave_snap.tcl` (its `SS8`
   legs are the source-tripwire idiom for exactly this gate, and its `SG6`
   comment is the "assert a FRACTION, never a magic count" lesson) and
   `tests/headless/test_wave_markers.tcl` (the suite you are extending).

## DISCIPLINE (non-negotiable)

* **Re-verify every anchor below from source before editing** — line numbers
  drift, and the PLAN notes for this item contain four claims source refutes
  (decision doc §6). A claim you cannot reproduce is a finding, not a blocker.
* **A green suite does not prove the changed code ran.** Every named sabotage in
  the TEST section must fail **exactly** its stated kill list, be reverted with a
  targeted `git checkout -- <file>` **only after** `git diff` confirms that file
  holds nothing but the sabotage, and the clean re-run must be green.
* **C89**: declarations at block top, `/* */` comments only in `.c`/`.h`.
  Allocations use `my_malloc`/`my_strdup`/`my_realloc` with the literal
  `_ALLOC_ID_` placeholder — never hand-numbered. (This item allocates nothing.)
* **`GUI_GATE=0`** in the environment for every suite run — overnight, nobody at
  the desk. Use `tests/headless/run_suites.sh`, never a bare `for` loop over
  `./src/xschem`.
* Git: **never** `git push`, `git reset --hard`, `git add -A`, `git commit -a`.
  Stage the explicit file list in the COMMIT step and nothing else. Do not touch
  the ~60 pre-existing untracked scratch/log paths in the tree, and leave the two
  pre-existing dirty tracked files alone
  (`doc/claude/suggestions/next_session_prompt_0165.md`,
  `sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/ngspice_state1/tb_bandgap.state`).
* Scratch files go in the test's own `test_scratch` dir, never the repo root.

## ANCHORS (verified by the scout 2026-08-01 — **verify, do not trust**)

**The one function you change**

* `src/draw.c:6357` `int graph_marker_create(int i, double px, double py, int delta)`
  — the pixel-addressed creator; the **single** gate behind both key arms and the
  `xschem graph_marker add` verb.
* `src/draw.c:6367-6370` — `memset` + the landmine-37 `graph_flags` bracket around
  `setup_graph_data(i, 1, gr)`. **Leave it alone.** ⚠ `skip = 1` on a zeroed local
  means `gr->gx1 == gr->gx2 == gr->gw == 0` (the `if(!skip)` block is
  `src/draw.c:3866-3874`) and `gr->cx = gr->w / gr->gw` (`src/draw.c:4045`) is
  **infinity**. `gr->digital` is the only field of that `gr` that may be read —
  **never compute the plot box from it.**
* `src/draw.c:6371-6374` — the `gr->digital` refusal. **Stays FIRST**, so the
  specific message survives (`graph_plotbox_at` refuses digital too).
* `src/draw.c:6375` — `if(!graph_point_at(i, px, py, GRAPH_MARKER_PICK_TOL, -1, -1, &hit))`
  and `:6376` its `"xschem: no trace near the pointer"` message. **This is the
  line the item changes.**
* `src/draw.c:6379` — `return graph_marker_add_record(i, hit.wave, hit.dataset,
  hit.point, hit.x, hit.y, delta);`. Unchanged.

**The gate you reuse (do not re-implement)**

* `src/draw.c:5031` `int graph_plotbox_at(int i, double px, double py)` — 1 when
  the CANVAS PIXEL is inside the rectangle between the two axes. Local
  `Graph_ctx`, hcursor bits bracketed, both coordinate pairs normalised
  (`gr->cy` is negative). Fails closed on: bad index, non-graph rect, off-screen
  graph, **digital** strip, **no loaded data**.
* `src/draw.c:5141` `void draw_graph_snap_cursor(int mx, int my)` and its pick
  loop `:5180-5187` — **the idiom to copy verbatim**: `graph_plotbox_at(...)`
  then `graph_point_at(i, ..., 1e30, -1, -1, &h)`. Its `:5172-5179` comment is
  the prose for the same decision.
* `src/draw.c:5221` `int graph_point_at(...)`; ranking `:5390-5426` (nearest
  trace by point-to-SEGMENT distance, ties to the first node; nearest SAMPLE by
  2-D screen distance; `hit.x`/`hit.y` RAW); x-window filter `:5376`; shared
  guard prefix `:5247`, `:5259`, `:5260`.

**The constant you delete**

* `src/xschem.h:443` `#define GRAPH_MARKER_PICK_TOL 20.0` — its comment block
  starts at `:436`. **`src/draw.c:6375` is its only use in the tree.** Not
  mirrored in Tcl.
* `src/xschem.h:418` `#define GRAPH_TRACE_PICK_TOL  10.0` — **must not change.**
  Its comment (`:399-417`) names the four surfaces that share it.

**Things that need NO edit — confirm each, then leave it**

* `src/callback.c:1514` (`m`) and `:1518` (`d`) — they pass the pointer through
  and test nothing. Read-only is gated in the primitive
  (`graph_marker_ro_refuse`, `src/draw.c:6303`), not the arm.
* `src/wave_viewer.tcl:5885` `key_filter` — forwards 109/100 inside `with_edit`
  when `wviewer::over_graph` (`:5859`, the rect **bbox**) is true. Strictly
  looser than the plot box, so C decides in the viewer too.
* `src/scheduler.c:5146` `xschem graph_marker add` (calls the same primitive),
  `:3859` `xschem get graph_plotbox_at`, `:3869+` `xschem get graph_trace_at`.
  **No new verb; no letter-dispatch risk.**
* `src/draw.c:6352` — `log_action("xschem graph_marker add_at %d %d %d %d%s\n", ...)`.
  The log is data-addressed, never pixels; replay is unaffected.

**Test-side anchors**

* `tests/headless/test_wave_markers.tcl:1669-1671` — `mk_reset` / `raw clear` /
  `set_modify 0`, the seam between the MF engine half and the MF display half.
  **The new `MP*` engine group goes here.**
* `:1739` `proc mf_empty_px {gi band}` — the scanner that already REQUIRES
  `graph_plotbox_at`; its `:1731-1738` comment explains why. `:1727` and `:3743`
  are the two comments that name `GRAPH_MARKER_PICK_TOL` and must be mended.
* `:1911-1920` the MF display fixture (two strips, explicit `x1/x2/y1/y2`);
  `:1934` `mfe1x`/`mfe1y` = empty plot-box space in strip 1; `:1785-1789`
  `mf_press`/`mf_drag`/`mf_rel`/`mf_move`/`mf_key`; `:1829` `mf_ready`.
* `:3757` `proc mx_empty_row {}` — the viewer scanner that does **not** require
  the plot box. **Must gain it.** `:3746-3754` is the MODAL-hang banner that
  forbids aiming a synthetic key at an unclaimed pixel.
* `:3918-3934` group **MX4** — asserts the OLD refusal ("m in empty waveform
  space creates nothing", "the pixel-addressed verb refuses there too").
  **Must be inverted.**
* `:3540` `mk_near`, `:3555` `mk_wadd`, `:3560` `mk_wdel`, `:3525` `mk_list`,
  `:3449` `mk_prep_at`, `:3508` `mk_send_once`, `:3648` `mx_ready`.
* `:321` `check`, `:332` `check_true`, `:349` `pcall`, `:358` `pexpr`,
  `:340` `note`, `:344` `stall`, `:424` `mk_graph`, `:439` `mk_field`,
  `:448` `mk_close`, `:433` `mk_nums`.
* `tests/headless/test_wave_snap.tcl:170-178` — the `SS8` source-tripwire legs to
  mirror; `:105-110` `SQ3` ("no proximity-threshold var survives");
  `:425-436` `SG6` (the FRACTION lesson, with the measured 0.78-vs-0.07 numbers).

## DO — in this order

### 1. Baseline first, before any edit

```sh
cd /home/qflow/dev/xschem/claude_1/xschem
cd src && make && cd ..
GUI_GATE=0 tests/headless/run_suites.sh --nogui test_wave_markers
GUI_GATE=0 tests/headless/run_suites.sh         test_wave_markers
```

Record both check counts. The scout measured **328** (`--nogui`) and **803**
(DISPLAY, 4/4 runs green) on unmodified HEAD `e516cc85`. **PLAN.md says this
suite is red at MF1 with 802 — it was not, today.** MF1 is load-sensitive
(`doc/claude/issues/status.md`). Your gate at the end is therefore:

> 0 or 1 FAILED; **any** failing leg is exactly `MF1`; and the pass count rose by
> exactly the number of legs I added.

A second red leg, or a pass count that did not rise, is yours.

### 2. `src/draw.c` — the gate

In `graph_marker_create()`, **after** the `gr->digital` block and **before** the
`graph_point_at` call, insert the plot-box gate; then change that call's
tolerance to `1e30` and its refusal message. Shape (adapt the wording, keep the
structure):

```c
  /* THE GATE IS THE PLOT BOX, NOT A DISTANCE TO A TRACE. `m`/`d` are keys --
   * pressing one is a clear intention -- so anywhere inside the strip's plot
   * area marks the sample the item-9 diamond is already sitting on, however far
   * that trace is. This is the SAME pair of calls draw_graph_snap_cursor()
   * makes (draw.c, the snap pick loop), so the marker cannot land anywhere but
   * under the diamond. Outside the box -- the legend band, the axis-number
   * margins, the reorder grip column -- no diamond is drawn (waveform_viewer_
   * modes.md 15.7), so there is no snapped point to mark, and the key refuses.
   * ⚠ the box must come from graph_plotbox_at(): the local `gr` above was built
   * with setup_graph_data(i, 1, ...) -- skip = 1 leaves gx1/gx2/gw at 0 and
   * every derived coefficient at infinity, so gr->digital is the only field of
   * it that may be read. */
  if(!graph_plotbox_at(i, px, py)) {
    graph_marker_refuse("xschem: the pointer is not inside the plot area of a strip");
    return 0;
  }
  /* tol nothing can exceed: the RANKING graph_point_at does (nearest trace by
   * point-to-segment distance, then the nearest sample on it) is what we want,
   * the threshold is not. Reaching the refusal below now means the strip has no
   * markable trace at all (traceless, bus-only, or an unresolvable rawfile=). */
  if(!graph_point_at(i, px, py, 1e30, -1, -1, &hit)) {
    graph_marker_refuse("xschem: no trace to mark in this strip");
    return 0;
  }
```

Nothing else in `draw.c` changes. Do **not** add a local, do **not** touch
`graph_marker_add_record`, `graph_marker_move`, `graph_marker_anchor_at` or
`find_closest_wave`.

### 3. `src/xschem.h` — delete the dead constant

Remove `#define GRAPH_MARKER_PICK_TOL 20.0` (`:443`) and mend the comment block
above it (`:436-440`) so it describes only `GRAPH_MARKERS_MAX` and
`GRAPH_MARKER_TOL`, with a one-line note that the `m`/`d` creation gate is the
**plot box** (`graph_plotbox_at`), not a tolerance. **Do not touch
`GRAPH_TRACE_PICK_TOL`.** Confirm with `grep -rn GRAPH_MARKER_PICK_TOL src/` that
nothing in `src/` still references it, then `cd src && make`.

### 4. Tests — `tests/headless/test_wave_markers.tcl`

#### 4a. New `MP*` engine group (BOTH arms), inserted at `:1669-1671`

Self-contained: build its own fixture, run, tear down with `mk_reset` +
`xschem raw clear` + `xschem set_modify 0` so the MF display half below starts
exactly as it does today.

Fixture (the hermetic `raw new` incantation the suite already uses — never
ngspice): `xschem raw new mpmark.raw dc vsweep 0 1.0 0.1`, `raw add v_a
{vsweep 1 +}`, `raw add v_b {vsweep 2 *}`; strip 0 = `mk_graph 0 0 800 400` with
`node "v_a\nv_b"` and explicit `x1 0 / x2 1 / y1 0 / y2 2.5`; strip 1 = a DIGITAL
strip (`node "v_a"`, `digital 1`); strip 2 = a traceless strip (no `node` token);
then `xschem zoom_full`.

⚠ **The explicit `x1`/`x2` are load-bearing.** With them absent the default data
window is `0 .. 1e-6`, every sample is drawn squashed against the left edge of
the box, and the scans below find nothing useful. (Measured: traces present only
at box-x 151 of 151…937.) The MF fixture at `:1916` sets them for the same
reason.

**Scan, never hardcode.** Write small scanners and a staging leg per pixel that
FAILS (not skips) when a scan comes up empty:

* `mp_box` — the pixel extent of strip 0's plot box, from `xschem get
  graph_plotbox_at 0 $x $y` over a coarse grid, refined at the edges.
* `mp_far` — **scan upward from the BOTTOM of the box** at the box's centre x for
  the first row with `xschem get graph_near_wave 0 $cx $y 25` == 0. Require
  `xschem get graph_trace_at 0 $cx $y 1e30` to be **non-zero** (node 1), and say
  so in a staging leg — sabotage SAB-3 below depends on it.
* `mp_halo` — a pixel with `graph_plotbox_at == 0` **and**
  `graph_trace_at … 20 >= 0`: scan x leftwards from the box's left edge (1…20 px
  out) over the box's rows. (Measured to exist at x = 135…150.)
* `mp_on` — an on-trace pixel: the first row at `$cx` with
  `graph_trace_at 0 $cx $y 2 >= 0`.

Legs (names are the contract; keep the `MPn` prefixes):

| leg | asserts |
|---|---|
| `MP0` | staging: box width > 100 px, and all four pixels were scanned (`check_true`, and a `stall` note if not) |
| `MP1` | the far pixel really is far AND inside: `plotbox_at` = 1, `graph_trace_at … 10` = −1, `… 25` = −1, `… 1e30` ≥ 0 and ≠ 0 |
| `MP2` | **`xschem graph_marker add 0 $fx $fy` returns 1** — the leg that dies if the tolerance is not relaxed |
| `MP3` | the anchor is the NEAREST trace: `marker.wave == [xschem get graph_trace_at 0 $fx $fy 1e30]` |
| `MP4` | the anchor is a REAL sample: `mk_field n 5` == `marker.point / 10` exactly at `%.17g`, and `mk_close [mk_field n 6] [xschem raw value <name> point]` |
| `MP5` | the anchor's x is inside the graph's x window (`0 ≤ x ≤ 1`) |
| `MP6` | the anchor is near the pointer's x: `abs(x − [lindex [xschem graph_coord 0 $fx $fy] 0]) ≤ 0.101` — an INDEPENDENT pixel→data path |
| `MP7` | **the halo pixel is REFUSED**: `add` → `{}`, with `plotbox_at` = 0 and `graph_trace_at … 20` ≥ 0 witnessed in the same leg |
| `MP8` | `d`: `add 0 $fx $fy -delta` returns a number whose `prev` (field 7) is the previous marker's number |
| `MP9` | a vertical sweep at `$cx` in steps of 8 through the box: `created/tried > 0.95` (a **FRACTION**, per `test_wave_snap` SG6 — never a magic count); and the two pixels 8 px above the box top and 8 px below its bottom create **nothing**. `graph_marker delete -all` afterwards |
| `MP10` | the DIGITAL strip refuses (`add` → `{}`) and `graph_plotbox_at` on it is 0 |
| `MP11` | the traceless strip refuses at a pixel where `graph_plotbox_at` = 1 |
| `MP12` | after `xschem raw clear`, the far pixel refuses (run this LAST in the group) |
| `MP13` | trace SELECTION proximity is UNCHANGED: at the far pixel `graph_trace_at 0 $fx $fy` (default tol) = −1 while `add` succeeded; and `#define GRAPH_TRACE_PICK_TOL  10.0` is still in `src/xschem.h` |
| `MP14` | source tripwires, mirroring `test_wave_snap` SS8 — read `src/draw.c` and `src/xschem.h` and assert: the gate line `if(!graph_plotbox_at(i, px, py))` is present; `graph_point_at(i, px, py, 1e30, -1, -1, &hit)` is present; `GRAPH_MARKER_PICK_TOL` appears **0** times in both files (count CODE lines only — copy `count_code` from `test_wave_snap.tcl:40`, which exists precisely because a comment explaining what the code does *not* do contains the string being counted) |
| `MP15` | creating at the far pixel still sets `xschem get modified` to 1 (the marker exception to landmine 19 is intact) |

#### 4b. Display legs inside the existing MF block

Add after MF11a (`:2200`), reusing `mfe1x`/`mfe1y` (strip 1, already
plot-box-verified by `mf_empty_px`). `mf_ready {…}` before each gesture.

* `MP20` — `mf_move $mfe1x $mfe1y` then `mf_key $mfe1x $mfe1y 109`: **one marker
  now exists on strip 1** (before this change: none). Include the control that
  the key really arrived (a second, on-trace, press that does create — or assert
  `mf_latched` is 0 first, as the neighbouring legs do).
* `MP21` — `mf_key $mfe1x $mfe1y 100` adds a second with `prev` set.
* `MP22` — **the diamond equality, the user's sentence asserted.**
  `xschem set graph_snap_cursor 1`; `mf_move $mfe1x $mfe1y`; read
  `set snap [xschem get graph_snap]` and `check_true` that it is a 4-element list
  (if empty, `stall` loudly — never pass vacuously); then `mf_key … 109` and
  assert `lindex $snap 0` == the strip index, `lindex $snap 1` == the marker's
  `wave`, and `mk_close` on x and y. Finish with
  `xschem set graph_snap_cursor 0` and `graph_marker delete -all`.
  (`draw_graph_snap_cursor` returns early under `!has_x`, so this leg is
  DISPLAY-only by construction — landmine 41's split rule, second question.)

#### 4c. Viewer group — tighten the scanner, invert MX4

* `mx_empty_row` (`:3757`) must additionally require
  `[wviewer::plotbox_at $::vdrw 0 $mxx $mxec]` — the requirement `mf_empty_px`
  already carries and documents. Without it MX4's expected value depends on
  whether the scanned row lands in the legend margin or in the box.
* Add `mx_margin_row` — a row inside strip 0's band with
  `wviewer::plotbox_at … == 0` and `mk_near 0 $mxx $y 20` == 1.
* **MX4 becomes:** `m` at `$mxe` (now provably inside the plot box) **creates**
  a marker; the pixel verb `mk_wadd $tok 0 $mxx $mxe` also creates one; its
  `wave` is the `graph_trace_at … 1e30` answer; then `mk_wdel`. Keep the
  existing "the empty pixel is still CLAIMED by the graph" leg and the
  on-trace control.
* **MX4b (new):** `mk_wadd $tok 0 $mxx $mxmargin` returns `{}`.
  ⚠ **Drive the margin case through the VERB only — never a synthetic `m` key.**
  A key not claimed by the graph falls through to the schematic handler where
  `m` is `readonly_block()`, a MODAL that hangs the run to the harness timeout
  and is scored CRASH (`:3746-3754`, probe-verified at y = 2).

### 5. Build, sabotage-verify, run

```sh
cd src && make && cd ..
GUI_GATE=0 tests/headless/run_suites.sh --nogui test_wave_markers
GUI_GATE=0 tests/headless/run_suites.sh         test_wave_markers
```

Then each sabotage in turn — apply, rebuild, run, confirm the kill list **exactly**,
`git diff src/draw.c` to confirm it holds nothing but the sabotage,
`git checkout -- src/draw.c`, rebuild, confirm green again:

| # | sabotage (all in `graph_marker_create`) | must kill | must stay green |
|---|---|---|---|
| **SAB-1** | put the tolerance back: `1e30` → `20.0` | `MP2` + the legs needing that marker (`MP3`–`MP6`, `MP8`, `MP9`-positive, `MP15`) + `MP20`/`MP21`/`MP22` | `MP7`, `MP9`-negative, `MP10`–`MP14` |
| **SAB-2** | delete the `if(!graph_plotbox_at(...))` block | `MP7` and `MP9`-negative **only** (and MX4b) | `MP2`–`MP6`, `MP8`, `MP10`–`MP13`, `MP15` |
| **SAB-3** | pass `restrict_wave = 0` instead of `-1` to `graph_point_at` | `MP3` **only** | everything else |

If a sabotage kills more or fewer legs than its list, the LEG is wrong, not the
sabotage — fix the leg and re-run all three.

Finally the wider audit (it is the batch's contract, not optional):

```sh
GUI_GATE=0 bash tests/headless/full_audit.sh
```

Compare against the PLAN.md PREFLIGHT baseline —
`SUMMARY: 239 pass  20 fail  1 crash/timeout  11 skip  (total 271)`,
`WIREEDIT: PASS`, `SCRATCH: 0 leaked dir(s)` — and the verbatim 20-name FAIL list
plus `TIMEOUT | test_key_graph_context`. **Any fail not on that list is yours.**
Note that `test_wave_markers` is *on* the baseline fail list but measured GREEN
today; ending green is the expected outcome. A whole-suite wipeout with
`NORESULT`/connection errors is a WSLg Xwayland abort — re-run before attributing.

### 6. Docs

* `doc/claude/specs/graph_markers.md`
  * §2 — a new decision row: **what gates `m`/`d`** (the plot box, not a
    tolerance; the diamond is the partner).
  * §6.1 — the `m` and `d` rows: "at the sample nearest the pointer" becomes
    "**anywhere inside the strip's PLOT BOX**, at the sample the item-9 diamond
    has snapped to".
  * §6.3 — replace the `GRAPH_MARKER_PICK_TOL` bullet with the two real
    refusals (outside the plot area; no markable trace in the strip), and mend
    the "Ordering, because it is not what you would guess" paragraph and the
    bus-trace sentence beneath it.
  * §10.1 — the constants paragraph: drop `GRAPH_MARKER_PICK_TOL`, say the gate
    is `graph_plotbox_at()`.
  * §11 — a Shipped ledger line.
* `doc/claude/specs/waveform_viewer_modes.md` §15.7 — state under the hover
  table that `m`/`d` create **exactly where the diamond appears**: one region
  rule for the glyph and the key.
* `doc/claude/code_analysis/waveform_subsystem_reference.md`
  * §1 file map, the `src/xschem.h` row — drop `GRAPH_MARKER_PICK_TOL` from the
    constant list.
  * §5, the `waves_callback` bullet — `m`/`d` now gate on the plot box.
  * **new landmine 45**, two reusable lessons: (a) *a creation gate must match
    the FEEDBACK gate* — the diamond and `m` disagreed for one release because
    the glyph's gate was fixed (issue 0177 era) and the key's was not; (b)
    *`graph_marker_create` builds its `Graph_ctx` with `setup_graph_data(i, 1,
    gr)`, and `skip = 1` leaves `gx1/gx2/gw` at 0 with every derived coefficient
    at infinity — `gr->digital` is the only readable field, so any geometry
    question there must go through `graph_plotbox_at()`.*
* `doc/claude/issues/0188-marker-create-gate-is-proximity-not-plot-box.md` —
  new, in the house shape (`# 0188 — …`, `**Status:** FIXED (2026-08-01)`,
  `**Branch:** fluid-editing`, the user's report quoted, THE MEASURED MECHANISM
  with the `(145,480)` halo and the `(544,621)` refusal from the decision doc
  §2.5 table, the fix, the legs that defend it). **Verify 0188 is still free**
  (`ls doc/claude/issues/`) before writing. Do **not** edit
  `doc/claude/issues/status.md` — it is an explicit point-in-time snapshot.

### 7. COMMIT

Stage exactly this list — nothing else, no `-A`, no `-a`:

```sh
git add src/draw.c src/xschem.h \
        tests/headless/test_wave_markers.tcl \
        doc/claude/specs/graph_markers.md \
        doc/claude/specs/waveform_viewer_modes.md \
        doc/claude/code_analysis/waveform_subsystem_reference.md \
        doc/claude/code_analysis/ovb01_01_marker_anywhere_in_plotbox_decision.md \
        doc/claude/overnight_batch_2026_08_01/prompts/01_marker-anywhere-in-plotbox.md \
        doc/claude/issues/0188-marker-create-gate-is-proximity-not-plot-box.md
git status --short          # confirm ONLY the two pre-existing dirty tracked files remain
```

Message:

```
feat(0188): m/d mark anywhere in the plot box, at the diamond's sample

`m`/`d` refused unless a trace passed within GRAPH_MARKER_PICK_TOL (20
screen px) of the pointer, while the item-9 diamond snap cursor -- the
thing showing the user WHICH sample would be marked -- has gated on the
PLOT BOX since it shipped. The glyph and the key disagreed about where a
marker could be created, in both directions: no marker in the middle of
an empty box, and a marker 6 px OUTSIDE the box where no diamond is drawn
(measured: `graph_marker add 0 145 480` created one).

graph_marker_create() now asks graph_plotbox_at() and then picks with
graph_point_at(..., 1e30, ...) -- byte-for-byte the pair
draw_graph_snap_cursor() makes, so the marker cannot land anywhere but
under the diamond. GRAPH_MARKER_PICK_TOL had exactly one use and is gone.
Trace SELECTION keeps its 10-px GRAPH_TRACE_PICK_TOL proximity, untouched
and regression-witnessed.

Three call sites, one gate: both key arms and `xschem graph_marker add`
go through the same primitive, so callback.c, wave_viewer.tcl and
scheduler.c needed no change.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
```

## CONSTRAINTS

* **Do not change `GRAPH_TRACE_PICK_TOL`**, its four sharing surfaces, or the
  `{tol 10}` proc defaults in `wave_viewer.tcl`. Trace selection proximity is
  the half of the user's report that says "Good."
* **Do not touch** `find_closest_wave()`. It has two open defects (landmine 40)
  and is out of scope; PLAN.md's suggestion to reuse it is refuted in decision
  doc §6.1.
* **Do not unlock digital or bus strips.** They stay refused
  (`graph_markers.md` §11 Deferred).
* **Do not change the marker DRAG** (`graph_marker_move`,
  `graph_marker_anchor_at`, the press/release helpers). They already use `1e30`
  restricted to the marker's own trace and deliberately tolerate the margins.
* **Do not add a scheduler verb, a Tcl mirror or a config variable.** Everything
  needed is already exposed.
* **Do not bump `XSCHEM_FILE_VERSION`.** No token, grammar or file-format change.
* **No new rendering.** If you find yourself drawing something, stop — that turns
  the item into an `[E]` and it is not in scope.
* Do not "re-fix" pre-existing defects you notice (MF1's flakiness,
  `find_closest_wave`, `graph_coord`'s missing landmine-37 bracket). Record them
  in your summary instead.
