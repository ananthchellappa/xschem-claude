# Item 25 rect - DEFERRED at scout stage

fr: 99

## Reasons

- Defer trigger 1 (automatic): rank-24 replay-suppress/byte-dedup pattern is DEFERRED (PLAN ledger item 24 [D], receipts/24_text.md exists) - the D3 coordinate family unlock rect depends on does not exist.
- Defer trigger 2 confirmed from source: machinery emits `xschem rect` coordinate-form sub-steps - create_graph.tcl:36 (`xschem rect 0 -300 400 0` inside the graph-creation composite) and place_sym_pins.tcl:38 (`xschem rect $x1 $y1 $x2 $y2 -1 "name=$name dir=$dir" 0` in a per-pin loop); boundary log-on-success would spam machine sub-steps.
- Plan claim 'rect is SILENT' is FALSE - actions.c:4584-4585 in new_rect(PLACE) emits log_action("xschem rect %.16g %.16g %.16g %.16g") with RECTORDER'd read-back coords from every interactive commit (callback.c:1890/2700/3225/5673 funnel). Rect is therefore a full D3 coordinate-form-bypass sibling of wire (rank 06): the scheduler coord arm is the designated silent replay receiver, and raw-argv boundary logging can never byte-dedup against the %.16g read-back form (the exact atom-24 lesson). Fundamental contradiction of the plan item.
- Undo hole confirmed + interactive/scripted asymmetry is a 0125/0121-class STANDALONE BUG for the driver to file (independent of migration): scheduler.c rect branch (scheduler.c:8886, argc>5 arm at 8894-8915) does storeobject (~8904) + set_modify(1) (~8915) with NO xctx->push_undo(); storeobject itself (store.c:226, 441-line body) has 0 push_undo/log_action; the interactive path DOES push (actions.c:4576 xctx->push_undo() in new_rect PLACE before its storeobject at 4581). Scripted rects ride the previous undo checkpoint. Same hole PLAN notes for arc (item 26).
- No coverage or gating gain: inline scheduler_readonly_reject(interp, "rect") at scheduler.c:8893 already gates all arms; the coord arm sets no Tcl result (no consumers); menu (xschem.tcl:14473) and toolbar (xschem.tcl:12733) bare forms are MENUSTART gesture starters that must stay raw (F-split), and the gesture commit is already logged at actions.c:4584.
