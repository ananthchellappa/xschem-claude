# Item 04 get_additional_symbols - DEFERRED at scout stage.

fr: 2

reasons:
- Plan defer trigger #1 CONFIRMED from source: the what=1 state is derived netlisting cache, a pure function of existing instance schematic=/*_sym_def attributes, appended-then-discarded around every netlist run (core comment at actions.c:3076-3078 declares explicit start/end bracket semantics; spice_netlist.c:124-126 comments out the end bracket because pop_undo(0,0)/remove_symbols wholesale-restore the schematic instead) - reclass D2 transient, out-of-scope for the object-model boundary
- No push_undo and no set_modify anywhere in core (actions.c:3079-3224) or branch (scheduler.c:4261-4267): the author deliberately keeps this mutation off the document-modified/undo story, confirming non-document state
- Zero live Tcl entries repo-wide: no caller of 'xschem get_additional_symbols' in xschem.tcl, tests/, xschem_library/, rc files; no callback.c key, no keybindings.csv row, no menu -command - all 15 real call sites are raw C in the 5 netlist backends, so the 'silent' coverage gain is zero in practice
- Destructive standalone-replay hazard beyond the plan's F-flagarg note: num_syms is a zero-initialized process-lifetime static (actions.c:3082), so a logged '0' line replayed in a fresh session frees EVERY loaded symbol via remove_symbol (actions.c:750, full storage free) and sets xctx->symbols=0 while instances still hold ptr indices - a line from this verb can never be a self-contained faithful replay
- Readonly gate would be wrong-shaped, not a win: netlisting read-only views is a legitimate core workflow, the mutation is not saved bytes, and BOTH the 0 and 1 forms mutate xctx->sym so no query/mutate split (audit sections 40/43) applies
- Verified branch shape for the record: scheduler.c:4261 in xschem_cmds_g (3550..4810); argc==2 silent no-op TCL_OK (F-validate), atoi 0/1 token (F-flagarg), Tcl_ResetResult, no result consumed; plan's fr2 accurate; F-shared netlist-backend calls are C-level below the boundary (uncounted, consistent with clear_drawing fr1 scoring)
