# Item 27 add_wire_label - DEFERRED at scout stage.

fr: 99

reasons:
- Drop already logged in the commit funnel: wire_label_try_commit (callback.c:1816) calls end_move_copy_logged(0) at callback.c:1824, the sole commit funnel; boundary logging of -drop would double-log every commit unless the funnel's log relocates into the boundary - the log-site-move pattern ratified undesigned at receipt 26 (arc). Defer trigger 1 CONFIRMED.
- 1/0 interp result is the load-bearing committed/refused witness: scheduler.c:1864 Tcl_SetResult(wire_label_try_commit() ? 1 : 0), consumed at four capture sites in tests/headless/test_add_wire_label.tcl (lines 108/118/149/164). The boundary's Tcl_ResetResult would clobber it - result-preservation blocker ratified at receipt 09 (apply_properties).
- 0122 E1 drop-witness is test-locked inside the same funnel: xctx->sympin_drops++ at callback.c:1633 (gated on sympin_preview), getter scheduler.c:4074, form snapshots xschem.tcl:10548/10608/10661/10859/10914 - any log-site move touches this funnel. Defer trigger 2 CONFIRMED.
- Bare/-place arms confirmed raw opener/gesture-arm: bare = tcleval(addlabel::open) (scheduler.c:1867, transient D2 dialog); -place (scheduler.c:1824-1856) reads form state via tclgetvar(label_new_name) not argv and arms START_SYMPIN with its own per-gesture push_undo - neither is 1:1 replayable, so only -drop is even admissible.
- Zero coverage gain: the GUI button drop is a raw C second entry (end_place_move_copy_zoom, callback.c:1908-1910) reaching wire_label_try_commit without crossing the scheduler, and readonly is already gated in-branch (scheduler_readonly_reject, scheduler.c:1818); the l key/menu route through the verb already (keybindings.csv:37, callback.c:3816, xschem.tcl:14438) so no 0068 gap exists.
- Line drift noted: PLAN.md cited scheduler.c:1682; the branch is now scheduler.c:1815-1870. callback.c:1816 for wire_label_try_commit is still accurate.
