# Session prompt — issue 0204: the Ctrl-4 pick must stop selecting what it clicks

Paste everything below the line into a fresh session, from the repo root
`/home/analog/dev/xschem-claude`, on branch `open_pdk`.

---

Read `doc/claude/issues/0204-sod-pick-mutates-the-selection.md` first, in full. Then
`doc/claude/issues/0200-descend-has-no-verb-noun-pick.md` (it established the read-only
coordinate probe you are about to copy, and the "a pick is not a selection" principle) and
`doc/claude/specs/select_at.md`.

## The job

ASE's Select-On-Design mode (Ctrl-4, "select signals to plot") classifies each click by
calling `xschem select_at`, which is the **mutating** coordinate pick. Every plot click
therefore leaves its target selected. Net labels and pins are *instances*, so after
clicking one, `xschem selected_set` is non-empty — and `hi_descend` then takes its
noun-verb branch instead of arming the verb-noun pick, so `E` tries to descend into the
net label rather than asking which instance to descend into.

Make the Ctrl-4 pick stop mutating the selection, without breaking the three things that
currently depend on that mutation.

## Constraints, from the user, explicit

1. **The Ctrl-4 command must be orthogonal to waveform-viewer code.** Do not touch
   `src/wave_viewer.tcl`. The picking path should end up with no viewer coupling at all.
2. `src/ase_window.tcl` is owned by the `fluid-editing` branch, which is actively editing
   the waveform viewer right now. Keep Tcl edits confined to the bodies of
   `ase::ui::sod_click` and `ase::ui::sod_net_at`. Put anything new in C
   (`src/findnet.c` / `src/scheduler.c`) or in a new file. Strictly additive; rewrite no
   existing block you do not have to.

## Step 1 — reproduce it. Do not skip this.

The issue is established **by reading only**. Nothing below is measured. Your first
deliverable is a measurement, and it may contradict the issue — say so if it does.

The issue predicts the two halves of the user's report behave *differently*, because
`xschem selected_set` with no argument filters to `ELEMENT` (`scheduler.c:10307`):

- clicking a **net label / pin / vsource** (all instances) → in `selected_set` → `E`
  misfires. This is the reported bug.
- clicking a **bare wire** → selected as a `WIRE`, filtered out of `selected_set` → `E`
  *should* still arm the pick correctly.

The user reported both. Find out which is true. If bare wires also break `E`, the cause is
something else and you have two defects, not one.

`tests/headless/test_cmdmode_descend_0201.tcl` is the working template — it arms a real
SOD mode with `ase::ui::select_on_design K {save 0 plot 1} plot 0` (`do_raise 0`, so no ASE
session window is needed), stubs `ase::ui::dp_finish`, and drives real `<Key-e>` and
`<ButtonPress-1>` events through `event generate`. Copy its prologue.

Run GUI work under the test gate — `tests/headless/run_suites.sh <name>` or
`tests/headless/gated_xschem.sh`, never a bare loop (see CLAUDE.md). Press `Allow 30m` once
rather than clicking Proceed repeatedly.

## Step 2 — the fix

The issue lays out two options and recommends **B**. Read its "Why the obvious fix is
wrong" section before choosing: `sod_net_at`'s `#netN` fallback *reads* the selection
`select_at` made (`xschem nets -selected`), `select_at` doubles as click feedback and logs
a replayable action line, and issue 0160 deliberately left the lock un-overridden here
because "selection IS the lock".

- **Option A** — transient select: save the selection before `select_at`, restore after
  classification. Precedent: `net_hilight_mode_click` in `src/callback.c`. Small, safe,
  leaves the entanglement in place. Fine as an intermediate commit.
- **Option B (recommended)** — add the read-only twin, the way 0200 added
  `find_closest_instance()` + `xschem instance_at`: a coordinate-addressed
  `xschem net_at <x> <y>` (and, if classification needs it, an `xschem object_at <x> <y>`
  returning `select_at`'s `{type index}` shape without mutating), then drop `select_at`
  from `sod_click` entirely.

Pick one, say which and why. If B does not fit the session, land A and say what is left.

## Step 3 — tests

These must stay green — they encode the contracts the fix can most easily break:

```
tests/headless/test_ase_unnamed_net.tcl          # 0154 #netN picking, via nets -selected
tests/headless/test_ase_bus_bits_0159.tcl
tests/headless/test_ase_locked_wire_pick_0160.tcl
tests/headless/test_ase_hier_pick_0161.tcl
tests/headless/test_ase_plot.tcl
tests/headless/test_cmdmode_0201.tcl
tests/headless/test_cmdmode_descend_0201.tcl     # DISPLAY-gated
tests/headless/test_verb_noun_descend_0200.tcl   # DISPLAY-gated
```

Add a new DISPLAY-gated test with its own leg IDs asserting, at minimum: a SOD click on a
net label leaves `selected_set` empty and `lastsel` 0; the trace is still queued and still
correctly named; `E` immediately afterwards **arms the pick** rather than descending; and
whatever the Step-1 measurement showed about bare wires.

**Sabotage-verify it.** Re-introduce the mutation, confirm the new legs go red and say
which ones. A leg that stays green under sabotage is not testing anything.

Some tests poke `ase::ui::sod` directly (`test_ase_unnamed_net.tcl:127-134`,
`test_ase_bus_bits_0159.tcl:237-255`, `test_ase_locked_wire_pick_0160.tcl:119-180`) — they
will constrain any refactor of that array.

## Step 4 — write it up

Update `doc/claude/issues/0204-sod-pick-mutates-the-selection.md`: status, what the Step-1
measurement actually showed (including anything that contradicted the issue's prediction),
which option you took and why, the sabotage table, and what you deliberately left undone.
Do not commit unless asked.

## Context you will want

- Current branch `open_pdk` = `fluid-editing` + the 0200/0201 work. Number any new issue
  from **0205**; the `fluid-editing` agent owns the 0188-01xx range.
- `src/xschem` in-tree is the binary the tests use. **`/usr/local/bin/xschem` on `PATH` is
  from January 2025 and has none of this work** — never test against it.
- `xschem instance_at` (`scheduler.c:5809`) and `find_closest_instance()`
  (`src/findnet.c`) are the read-only probes 0200 added. `xschem closest_object`
  (`scheduler.c:2453`) takes no coordinates. `xschem flylines at x y`
  (`scheduler.c:3500`) is net-oriented and already read-only — `sod_net_at` calls it first
  and only falls back to the selection when it misses, so study why it misses.
