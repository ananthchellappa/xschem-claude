# Item 30 line - DEFERRED at scout stage.

fr: 99

reasons:
- D3 coordinate-form-bypass confirmed from source: interactive gesture funnel new_line(PLACE) (src/actions.c:4490) already emits the exact `xschem line %.16g %.16g %.16g %.16g` replay lines at five sites (actions.c:4506, 4515, 4525, 4534, 4543; manhattan modes emit up to two lines per placement), all replayed through the scheduler coord branch with no suppress channel — boundary logging would re-log every replay and raw-argv vs %.16g read-back can never byte-dedup
- Plan defer trigger #1 fires: the rank-24 replay-suppress + byte-dedup pattern this family rides on is itself DEFERRED in the ledger (item 24 text, both triggers confirmed), as are the D3 siblings wire (06), rect (25), arc (26)
- Plan defer trigger #2 (family-wide hard stop) fires: un-suppressed machinery path exists — src/place_sym_pins.tcl:40 issues `xschem line $x $y [expr {$x + $line_offset}] $y {} 0` through the coord branch as a per-pin machine sub-step
- Branch anchor drifted: `line` branch is at src/scheduler.c:5756 (plan said 5621), in xschem_cmds_l(); readonly reject scheduler.c:5763; coord arm argc>5; gui arm start_line (infix) else MENUSTART|MENUSTARTLINE; bare arm MENUSTART|MENUSTARTLINE — gesture-START arms must stay raw and the only mutate tail is the D3-blocked coord form, so no accepted boundary pattern covers any part at single-atom scope
- Issue 0127 undo-hole sibling CONFIRMED with exact sites for the verify list: coord arm storeobject at scheduler.c:5774 + set_modify(1) at scheduler.c:5780 with NO push_undo, while the interactive gesture pushes undo at actions.c:4499 (xctx->push_undo() at top of new_line PLACE commit, before all five emit sites) — same class as rect; per DEFER rule no files were written, driver should paste these cites into doc/claude/issues/0127-scripted-rect-arc-coord-form-no-push-undo.md
- Second-entry audit clean: keybindings.csv row 38 (key,76,0,canvas,tools.insert_line) -> registry entry callback.c:3699 `xschem line gui`; menu Shift+L xschem.tcl:14472 and toolbar xschem.tcl:12732 all route via the verb — no 0068 raw-key gap; branch sets no Tcl result and no consumers found
