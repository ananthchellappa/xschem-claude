# Phase 3d.2 — sem-gated batch 3 (`j` hilight-list, branch migration)

**Status:** DONE (commit `c5f5b909`). **Branch:** `feature/action-registry`.
**Predecessors:** d1b (`idle_only`), sem-gated batches 1 (`n`/`U`/`u`, `ac558252`) and
2 (`k`/`K`, `107c1524`). Same pattern; see `lessons_learnt_action_registry.md` and
`plan_phase3d2_semgated_batch2.md`.

## Goal

Migrate the three exact-chord sem-gated branches of `case 'j'` (the highlight-net
list/create commands) to `idle_only` canvas rows. This is a **branch** migration: the
`case` stays for its 4th branch, which is a *family* guard and not sem-gated.

## The chords

| Key (keysym) | Chord | Switch behavior | id (reused) | tcl | fate |
|---|---|---|---|---|---|
| `j` (106) | plain `rstate==0` | `print_hilight_net(1)` (print list) | `sym.list.print_list_of_highlight_nets` | `xschem print_hilight_net 1` | migrate, **idle** |
| `j` (106) | `Ctrl` | `print_hilight_net(0)` (create pins) | `sym.list.create_pins_from_highlight_nets` | `xschem print_hilight_net 0` | migrate, **idle** |
| `j` (106) | `Alt` (`EQUAL_MODMASK`) | `print_hilight_net(4)` (create labels) | `sym.list.create_labels_from_highlight_nets` | `xschem print_hilight_net 4` | migrate, **idle** (Mod1+Mod4) |
| `j` (106) | `SET_MODMASK && Ctrl` | `print_hilight_net(3)` (list, buses expanded) | — | — | **stays in C** (family, not sem-gated) |

`xschem print_hilight_net N` = `print_hilight_net(atoi(argv[2]))` (scheduler.c:4218),
identical to the switch (no extra redraw) — so all three reuse the existing
`sym.list.*` csv ids, Tcl-backed. (The csv `accel` column on these rows is decorative
and disagrees with the real key — irrelevant; we reuse the *command*, verified.)

## Why branch, not whole-delete

The 4th branch `SET_MODMASK && (state & ControlMask)` is a **family**: `SET_MODMASK` =
`(rstate & Mod1) || (rstate & Mod4)` matches *any* state containing Mod1 or Mod4 (with
Ctrl) — exact rows can't cover it. And it has **no** `if(sem>=2)break;`. So it stays in
C; only the first three (exact, sem-gated) branches are removed. After migration
`case 'j'` contains only the `SET_MODMASK && Ctrl` branch.

`J` (keysym 74) is also deferred: its sole guard is `SET_MODMASK` (a family) →
`print_hilight_net(2)`. Can't exact-migrate; additive-only, low value.

All three migrated chords are **canvas-only** (no `waves_selected` in `case 'j'`).

## Behavior preservation (per migrated chord)

- `sem>=2`: idle row → gate skips → switch → `case 'j'` → only the `SET_MODMASK&&Ctrl`
  branch remains, which doesn't match (plain/Ctrl/Mod1/Mod4) → nothing. *(old: each had
  `if(sem>=2)break;` → nothing.)* ✓
- `sem<2`: gate → canvas row → `xschem print_hilight_net N`. *(old: `print_hilight_net(N)`.)* ✓
- `Alt+Ctrl+j` (the kept family chord): no exact row → falls to switch →
  `SET_MODMASK&&Ctrl` → `print_hilight_net(3)`, unchanged. ✓

## Concrete steps

1. Add 3 Tcl-backed registry rows reusing the `sym.list.*` ids (fn=NULL, tcl=`xschem
   print_hilight_net N`).
2. Seed 4 `idle_only` canvas rows: `j 0` (show 1), `j ctrl` (show 0), `j Mod1` + `j
   Mod4` (show 4).
3. Delete the plain/Ctrl/Alt branches from `case 'j'`; keep the case + the
   `SET_MODMASK && (state & ControlMask)` branch + `break;`.
4. Build (C89, no warnings).

## Testing (extend `tests/headless/test_key_graph_context.tcl`)

`print_hilight_net` is hard to observe cleanly: show=1/3 open a `viewdata` window
(dialog), show=0/4/2 run tmpfile-based Tcl procs that are no-ops on the fixture. So:
- **Data:** the 4 rows present **with ` idle`**, canvas-only (no graph row); e.g.
  `{key 106 0 canvas sym.list.print_list_of_highlight_nets idle}`,
  `{key 106 alt canvas sym.list.create_labels_from_highlight_nets idle}` (Mod1 row; the
  Mod4 row dumps mods `0` per the known `mods_name` gap).
- **No-error dispatch** on a non-dialog chord (`j` Ctrl = create pins, a no-op here):
  pressing it at `sem=0` doesn't error. Do **not** key-press `j` plain (opens viewdata).
- The idle gate itself is already proven concretely (d1b probe + batch 1 undo/redo +
  batch 2 hilight); `j`'s effect isn't cleanly observable, so we assert data + no-error.
- Engine `run.sh` 6/6 + all GUI smokes. Narrow any older assertion the new rows trip.

## Definition of done

- Builds clean; engine 6/6; all GUI smokes green.
- 4 idle_only canvas rows added; the 3 exact branches removed from `case 'j'`; the
  family branch kept; actions reuse the verified-identical `sym.list.*` ids.
- Test: rows-present-with-idle + canvas-only + `j` Ctrl dispatch-without-error.
- Plan/tutorial/lessons/memory/next-prompt updated; commits split code vs docs.
