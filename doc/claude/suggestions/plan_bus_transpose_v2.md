# Plan — bus_transpose v2 (up/down rename + range support)

Spec: `doc/claude/specs/bus_transpose_scroll.md`. RED-first. Feature already committed
(`1c8bfb0a`); this is a revision of an uncommitted-since working tree.

Two changes, intertwined:
1. **Rename** the direction `grow|shrink` → `up|down` (arg, internal procs, action ids).
2. **Extend** the transform to ranges `[N:M]` (shift both endpoints ±1; down blocks on
   any negative; up never blocks).

## Phase 0 — RED
- Rewrite `tests/bus_transpose.tcl`:
  - pure-transform checks use `bustranspose::up_name` / `down_name`, add the range rows
    (`[N:M]` up/down, `[N:0]`/`[1:0]` down no-op), wrap each pure check so a missing proc
    reports FAIL rather than aborting.
  - integration calls become `bustranspose_apply up|down`, add a range case on `lab`.
- Run → RED (old code: procs are `grow_name`/`shrink_name`, `bustranspose_apply up` is a
  no-op, ranges unchanged).

## Phase 1 — implement (Tcl)
`utils/bus_transpose.tcl`
- Rename `grow_name`→`up_name`, `shrink_name`→`down_name`.
- `up_name`: range (`busresize::_split`) → both +1; else single `[i]` → `[i+1]`; else bare
  → `[0]`; else (other bracket) unchanged.
- `down_name`: range → both −1 unless either <0 (then unchanged); else single `[i]`:
  i==0→bare, i>0→`[i-1]`; else unchanged.
- `bustranspose_apply`: accept `up`/`down`; ternary picks `up_name`/`down_name`; update
  the guard + `ciw_echo` text.

## Phase 2 — rename the action ids (C + csv + rc)
- `src/callback.c`: registry rows `edit.transpose_up_selection` /
  `edit.transpose_down_selection` with commands `bustranspose_apply up|down`;
  `action_id_mutates` ids updated.
- `src/actions.csv`: N/A — these ship unbound and have no csv row (busresize-sibling
  convention; the C registry help string is their only metadata).
- `src/cadence_style_rc`: bind `wheel up alt+shift → edit.transpose_up_selection`,
  `wheel down alt+shift → edit.transpose_down_selection`; update the comment.

## Phase 3 — GREEN + regression
- `cd tests && ../src/xschem --nogui --pipe -q --script bus_transpose.tcl` → all PASS.
- Rebuild `src/` (callback.c changed). `test_keybindings_help` (every bound id has a csv
  label — transpose ids ship unbound, but the renamed csv rows must exist) + binding
  smokes green. No keybindings.csv change (these ship unbound → no drift-guard impact).
- GUI smoke: ALT+SHIFT+wheel over a selected label shifts the index (manual / synth).

## Phase 4 — docs/memory, commit
- New memory `bus-transpose`. Commit + push (user asked to commit previous work too).
