# 0272 — `xschem circle` and `xschem zoom_box` carry no modal-gesture gate at all, and `circle` has no read-only reject

Status: **FIXED 2026-08-09** on `open_pdk` — both verbs now carry all four gates, and `circle`
gained the `scheduler_readonly_reject()` its sibling `xschem arc` has always had
(`src/scheduler.c`). Found by the issue **0269** census.
Area: `src/scheduler.c` (the `circle` and `zoom_box` verb branches)
Tests: section **H2** of `tests/headless/test_shape_draw_gate.tcl` (10 checks), plus **E3** for the
read-only half. Was: none — phase 1's suite tested the shape KEYS.
Related: **0269**, **0247** (phase 1, which gated everything else in this family), **0243 F1**.

## The claim

Phase 1 (issue 0247) gated the shape arms against a live wire draw and enumerated them from the
verbs the bug report named. Two arms were missed, and the shape of the miss is instructive: both
have gated key and context-menu twins, so the family *looked* complete from either end.

| arm | key twin | ctx-menu twin | the verb |
|---|---|---|---|
| circle | `callback.c` `C` / Ctrl+C — gated, both branches | pick 20 — gated | `xschem circle` — **no gate at all** |
| zoom box | `callback.c` `z` — a decline guard, not a gate | — | `xschem zoom_box` — **no gate at all** |

`xschem arc`, `xschem rect` and `xschem polygon` all carried `leave_wire_draw_for()`. These two
never did, and neither was covered by a check.

## Measured, 2026-08-09, `--nogui`

```
                              before                    after
xschem wire gui               ui=1     last=1           ui=1     last=1
  + xschem circle             ui=65537 last=1   <--     ui=65536 last=0   ui2=128
  + xschem zoom_box           ui=65537 last=1   <--     ui=65536 last=0   ui2=8
```

`ui_state 65537` is `STARTWIRE | MENUSTART`: the wire draw is still live under a menu-armed shape,
with wire command mode still armed, which is the issue-0240 jam.

## The read-only half

`xschem circle` also had no `scheduler_readonly_reject()`, unlike `xschem arc` (and `rect`,
`polygon`) which have had one since their coordinate forms existed. `store_arc()` runs
unconditionally on the completing click; only `set_modify()` is read-only-suppressed. So a
read-only window could arm a circle and the third click would store an arc into it — a mutation of
a buffer the user had explicitly locked, invisible in the modify flag. Fixed with the same one-line
reject its sibling uses.

`xschem zoom_box` correctly has **no** reject: it is a view gesture and stores nothing. That is
also why it is the one shape a read-only window can arm, and therefore why
`leave_shape_draw_for()` has no read-only refusal of its own — see issue 0269 and test **E3**.

## The lesson, for the census that comes after this one

Enumerating the arms *from the verbs a bug report names* leaves the arms nobody has complained
about yet. 0242 learned this for the placement doors and 0265 restated it ("enumerated from the
state the teardown owns, not from the verbs"). Phase 1 was written before that rule existed and
enumerated by verb; this issue is the residue. The phase-3 census enumerated from the state — "a
modal gesture is being armed" — and these two fell out of the cross-check between the three
existing gate lists, not out of a report.
