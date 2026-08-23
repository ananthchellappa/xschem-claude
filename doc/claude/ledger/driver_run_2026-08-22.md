# Driver run 2026-08-22 — the eyes-on defect batch (branch `annotate`)

Source: the user's second hands-on session with the shipped OP-annotation
feature, on `sky130_tests_ase/tb_bandgap` via `ngspice_state1`. Every item is a
defect a person actually hit.

Status codes: **x** done+verified+committed · **F** failed (tree left clean,
nothing committed) · **D** deferred (blocked; nothing committed) · **E** landed
but needs a human eyeball (GUI-only proof, or a user-visible behaviour change
nobody ratified)

| item | status | commit | tests | new issues | one-line result |
|---|---|---|---|---|---|
| 0614+0615 | E | 4853cbd2 | test_op_annot 15F/264 -> ALL PASS 287; test_launch_context 13 -> 15 ALL PASS; test_annot_show_menu 4F/21 -> ALL PASS 25; test_backannotate_digital 81 and test_raw_read_failure_0306 63 unmoved; T1 3 FAIL (same 2 unrelated suites, verbatim); T2 HARNESS PASS 6/6 goldens | 0621,0622,0623,0624,0625 | annot_show now defaults to 0, so node voltages and branch currents are OFF at startup until you press Alt-6 or tick View > Show node voltage / branch current annotation — keep 0, or default to 2 (voltages on at startup exactly as before, with the chords and the View pair still owning them)? |
| S3 | E | 7088e8a8 | test_op_annot 287->330 headless / 336 display / 337 --logdir ALL PASS; test_annot_show_menu 25->25; test_launch_context 15->15; test_traversal_flag_leak 11->11; T1 3 FAIL->3 FAIL (both pre-existing, 0629 + sg13g2_tests_ase drift); T2 6/6->6/6 HARNESS PASS; no build (pure Tcl+md) | 0626,0627,0628,0629,0630,0631,0632 | On a sheet with unsaved edits, should "Create device OP .save file" REFUSE outright (one extra click, always safe), or keep walking as it does today — which rewrites the ~ backups of ancestor cells you never touched and, over a stale one, silently drops cards while saying "normal for such cells"? (0628 + 0632 are one ruling.) |
| S4 | E | 44f52f9a | test_ase_core 74->109, test_ase_final 28->49, test_ase_dialogs(:99) 147->158, test_ase_persist 17->17, test_op_annot 330->330 headless / 336->336 on :99, test_annot_show_menu 25, test_launch_context 15, test_traversal_flag_leak 11, T1 3 FAIL->3 FAIL (all pre-existing), T2 HARNESS PASS 6/6 | 0633,0634,0635,0636,0637 | With unsaved edits on the sheet and autosave backup ON (the shipped default), should Netlist-and-Run (a) REFUSE the device OP save cards and say so, as S4 shipped, or (b) walk anyway and accept that the walk rewrites the `~` autosave backups of ancestor cells you never touched (issue 0632)? |
