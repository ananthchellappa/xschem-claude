# Implementation plan — hover fly-lines (RED-first, atomic steps)

Status: 2026-07-13. Companion to `doc/claude/specs/hover_flylines.md` (feature spec) and
`doc/claude/code_analysis/flyline_architecture.md` (data-structure analysis). This is the
build order: every step is one RED (failing test) → GREEN (minimal impl) → commit.

## v1 constraints (baked into every step)

- **C1 — fly-lines never change wire appearance.** Pure read-only overlay: no writes to
  `hilight_table`, no `xInstance.color`, no `.sel`, no modified flag, no change to saved
  bytes. Locked by an explicit invariant test (step A8) and carried into the draw path
  (step B0). This is the load-bearing correctness rule of v1.
- **C2 — placeholder rendering is fine.** Dashed colored lines via a `gc_flyline` GC
  (modeled on `gc_hover`). The Cadence soft-cloudy/glow look is only attempted if a boxed
  spike (step B4) shows it is cheap; per the architecture analysis it needs a new Cairo
  alpha overlay surface the Xlib line path lacks, so the expected outcome is **defer**.

## Strategy: two tracks, logic before pixels

- **Track A (A0–A9)** — all connectivity/clustering logic behind a headless query command
  `xschem flylines …`. Pure data, deterministic, RED-first with golden asserts. Runs
  `--nogui --script` (no display needed; the committed `--script` recent-files gate,
  3dc41ba2, keeps these runs from touching the user's recent list).
- **Track B (B0–B5)** — the window-only overlay render, riding proven Track-A data. Tested
  by state introspection + `event generate <Motion>` gesture tests (needs `-x`), per the
  gesture-test-full-sequence discipline (drive the whole Tk sequence, not a synthetic call).

Do A fully before B. Each step is independently committable and greppable.

## Command surface (grows field-by-field across Track A)

- `xschem flylines net <name>` — coordinate-free, pure; the workhorse for logic tests.
- `xschem flylines at <wx> <wy>` — world coords; the hover path (needed for hub-under-cursor
  and net-resolution-at-point tests).
- Return dict grows per step:
  `{net {N} global 0 capped 0 members {{type n x y}...} clusters {{id members...}...}
    segments {{x1 y1 x2 y2}...}}`.

---

## Track A — connectivity logic (headless)

**A0 — command skeleton**
- RED: `xschem flylines` → usage error; `xschem flylines net foo` on empty sch →
  `{net {} members {} clusters {} segments {}}`.
- GREEN: add `flylines` subcommand in the correct first-letter ('f') dispatch fn of
  `scheduler.c` (see the scheduler-letter-dispatch note); empty stub dict.

**A1 — net resolution**
- RED: fixture = one labeled wire (`lab=CLK`). `flylines at <wx> <wy>` → `net {CLK}`;
  `flylines net CLK` → `net {CLK}`.
- GREEN: `prepare_netlist_structs(0)`; `find_closest_obj` at point; resolve via the
  `hilight_net` switch (WIRE→`wire.node`, label/pin ELEMENT→`inst.node[0]`). Extract this as
  `object_net_name(type,n,col)` (analysis §5.5) for reuse.

**A2 — member enumeration**
- RED: fixture = CLK on 2 wires + 2 label pins → `members` count == 4, each `{type n x y}`.
- GREEN: scan wires (`wire.node==CLK`) + inst pins (`inst.node[j]==CLK`), bus-aware;
  endpoints via `get_inst_pin_coord` / wire coords. Mirrors `propagate_hilights` scan.

**A3 — physical clustering (THE core; defining test)**
- RED: fixture-A = two CLK labels, NO wire between → `clusters` count == **2**.
  fixture-B = the two labels joined by a drawn wire → count == **1**.
- GREEN: non-destructive connected-component pass (analysis §5.1): union members that
  physically `touch()` via the spatial hash, using a scratch `Int_hashtable` visited marker
  — **never `.sel`** (C1). Return per-cluster member sets.

**A4 — anchors**
- RED: each cluster reports `anchor {x y}` at the known label pin coord.
- GREEN: anchor = pin coord (label/pin) or nearest wire endpoint to hub.

**A5 — star segments + implicit-only rule**
- RED: 3-cluster CLK (no wires), `net CLK` hub=cluster0 → `segments` count == **2**,
  endpoints hub→others. Single-cluster net → **0**. fixture-B (wired pair) → **0**.
- GREEN: hub = cluster0 for `net` form / cluster-under-cursor for `at` form; emit star
  hub→each other cluster.

**A6 — exclude unnamed**
- RED: bare unlabeled wire (auto `#net…`) → `segments {}`.
- GREEN: skip node names beginning `#` / matching `net#` (`get_unnamed_node` form).

**A7 — bus aggregate-per-label**
- RED: `A<1:0>` label twice, no wire → one **deduped** segment set (not per-bit doubled).
- GREEN: `expandlabel` per bit, gather, endpoint-dedup, one set.

**A8 — global suppress + cap + C1 invariant**
- RED (globals): `gnd!`/`global=true` on many pins → `net gnd!`, `flylines_show_globals=0`
  → `global 1 segments {}`; with `=1` and members > cap → `capped 1`, `segments` count ==
  `flylines_cap`.
- RED (C1 invariant — the load-bearing test): after any `flylines`/`at` call, assert
  `hilight_table` empty, no `inst.color` changed, `xschem get modified` == 0, sch bytes
  unchanged.
- GREEN: detect globals via `record_global_node(3,…)`; suppress by default; nearest-K cap +
  `ciw_echo` notice when capped. Keep the whole path read-only.

**A9 — config-var defaults**
- RED: `flylines`=0, `flylines_show_globals`=0, `flylines_cap`=32,
  `flylines_color/width/dash` exist (tclgetvar).
- GREEN: `set_ne` defaults in `xschem.tcl`; mirror in C where read (`MIRRORED IN TCL`).

---

## Track B — overlay render (needs `-x`)

**B0 — read-only draw guard (carries C1)**
- The draw path computes only from Track-A data and writes nothing but the window. No new
  behavior; a guard/assertion step so C1 cannot regress once drawing exists.

**B1 — `gc_flyline` GC**
- GREEN + smoke: build, launch `-x`, no crash, no leak (allocation trace clean). Create/free
  beside `gc_hover` (`xinit.c:1244`) from `flylines_color/width/dash`.

**B2 — draw on hover**
- RED: `flylines` on, `event generate .drw <Motion>` over a multi-cluster net →
  `xschem flylines shown` == net; over empty → "".
- GREEN: `draw_flylines()` reusing A1–A8; window-only star via `drawtempline`; called from
  `draw_hover` when `flylines` set; track shown-net in the new `Xschem_ctx` overlay fields
  (analysis §5.3) + the result cache (analysis §5.4).

**B3 — erase-on-move + leave + survive redraw**
- RED: hover A → move to B → `shown`==B (A erased); → empty → ""; hover → `zoom_full` →
  `shown` unchanged (re-established).
- GREEN: erase via regional `draw()` over the fly-line union bbox on net-change/leave
  (like `draw_hilight_region`); re-stamp hook in `draw()` beside `draw_hover(1)`
  (`draw.c:6120`).

**B4 — soft-cloudy spike (boxed, timeboxed)**
- Assess a Cairo alpha overlay for glow. Expected (per analysis §3/C2): not cheap on the
  Xlib interactive line path → **keep dashed placeholder, document defer**. If the spike
  proves trivial, add it; otherwise no code, just a note. No test.

**B5 — toggle + docs**
- Options-menu/key toggle for `flylines`; flip spec status (P0/P1 done); short lessons note
  if anything surprised.

---

## Test mechanics & discipline

- Fixtures: tiny `.sch` files under `tests/headless/flylines/` — labeled-no-wire pair,
  wired pair, 3-cluster net, unnamed net, bus label, global net.
- Track A rails: `xschem --nogui --pipe -q --script …`, assert on the `flylines` dict.
- Track B rails: `-x` with the full `<Motion>`/`<Leave>` Tk sequence; assert on
  `xschem flylines shown`.
- **Sabotage-verify** each rail (green-but-hollow discipline): break the impl, confirm the
  test goes RED, restore.
- **A3** (clustering: 2 vs 1) and **A8** (C1 read-only invariant) are the two make-or-break
  tests — clustering correct, zero wire-state mutation.

## Data-structure changes referenced (from the analysis)

- §5.1 non-destructive connected-component pass — **A3** (needed).
- §5.3 transient overlay `Xschem_ctx` fields + `gc_flyline` — **B1/B2** (needed).
- §5.4 result cache keyed by net + prep epoch — **B2** (needed for hover perf).
- §5.5 extract `object_net_name()` — **A1** (nice).
- §5.2 name→objects reverse index — **not in v1** (optional engine-wide upgrade; the A/B
  cache covers hover). Revisit only if the broader full-scan cost matters.
- §5.6 persistent cluster ids — **avoided** (clusters are edit-ephemeral).

## Suggested commit sequence

`feat(flylines): A0 query skeleton` → `A1 net resolution` → … → `A9 config vars`
→ `B1 gc_flyline` → `B2 draw on hover` → `B3 erase/redraw` → `B5 toggle+docs`.
One commit per step; keep Track A green before starting Track B.
