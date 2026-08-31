# S7 brief — parked 2026-08-31, not yet dispatched

Dispatch as `Workflow({scriptPath:"doc/claude/ledger/crew.js", args:{id:"S7", brief:<everything below the rule>}})`
**after S6a lands and its ledger row is committed.** One crew at a time.

---

THREE GUI CONTROLS ALL CALLED "PUSH SCHEMATIC" DO THREE DIFFERENT THINGS, AND ONE OF THEM OPENS THE WRONG SCHEMATIC WITHOUT SAYING SO.

== WHAT THE USER ASKED FOR ==
The user chose "Both" when offered (a) the netlister fix and (b) these descend defects. S6/S6a is (a). This is (b). The user always launches with `./src/xschem --script sky130A/cadence_style_rc --logdir /tmp`, so the cadence path is the one that matters most.

== THE THREE CONTROLS, MEASURED ==
An instance can carry a per-instance `schematic=<name>` attribute. Three controls named "Push schematic" descend into it, and they disagree:
* **right-click canvas menu** — `src/callback.c:5490` (case 12) and `:5493` (case 22) call `descend_schematic(0, 1, 1, 1)`: fallback ON, alert ON. Prompts, lands on the base sheet. This is the only correct one.
* **the `E` key and Edit > Push schematic** — `src/xschem.tcl:14682` binds `<Key-$hi_descend_key>` (default `e`, `:5997`) to Tcl `hi_descend` and ends in `break`, and `:15676` wires the Edit menu item to `hi_descend` too. Neither reaches the C verb. Measured with Tk on `:99`: the specific `<Key-e>` binding fires and the generic `<KeyPress>` dispatcher does NOT, so `callback.c:7668`'s `case 'e'` is dead from the keyboard.
* **the toolbar button, visible by default** — `src/xschem.tcl:13350` `set_ne toolbar_visible 1`, `:13367` puts `EditPushSch` in the default list, `:13513` `toolbar_add EditPushSch "xschem descend" "Push schematic"`. Bare verb. Same for the command palette row `edit.push_schematic` at `src/actions.csv:91`.

== DEFECT ONE — issue 0979, the blank sheet ==
`xschem descend` hardcodes fallback=0 and alert=0 in all three of its forms: `src/scheduler.c:3355` (the `-inst` form), `:3362`, `:3364`. So the toolbar button, the palette row and the cadence chords land the user **one level down on a blank sheet**.
`currsch` is incremented BEFORE `load_schematic` (`src/actions.c:4800-4814`, with an explicit comment), so a failure is not "nothing happened" — the user is inside the blank sheet and needs `go_back`.
NOT silent to a script, contrary to how 0979 was filed: the verb evaluates to `"0"`, `xschem get descend_error` reads `load-failed`, and `xschem get statusmsg` carries a full sentence through `statusmsg_hold()`. So this is about BEHAVIOUR, not about adding a message.
Cadence mode is the worst case: `src/cadence_style_rc:202` binds Ctrl-X to `cadence::descend_into_inst`, whose entire body is `xschem descend` (`utils/cadence_nav.tcl:260-263`) with no CIW echo at all. Alt-X (`:240`) and Ctrl-Alt-D go through the same engine. Ctrl-Shift-X escapes it (it calls `hi_descend`). And cadence mode sets `descend_readonly 1` (`:494`, consumed at `src/actions.c:4879`) yet the blank sheet comes back **readonly=0** — an editable blank page aimed at the repo root, inside the mode whose whole point is read-only browsing.

== DEFECT TWO — NOT YET FILED, AND IT OUTRANKS 0979 ==
`hi_descend` enumerates candidate views with the **symbol** form of the resolver — `src/xschem.tcl:6085` `xschem get_sch_from_sym -1 $sym` — so an instance-level `schematic=` is never a candidate row. `hi_descend_pick_view` then returns the row named `schematic`, `hi_descend_is_default_sch` compares it against the INSTANCE form, finds them different, and FORCES the base sheet through the one-shot C override at `src/actions.c:4306-4312`.
Consequence, measured on **shipped, `make install`-ed** data: `xschem_library/inst_sch_select` instance **x2** carries `schematic=comp3_parax.sch`, and that file **exists** (8 instances, 3 wires). Pressing `E` opens `comp3.sch` (54 instances, 61 wires) instead — **rc=1, no `descend_error`, no statusmsg, no prompt.** A valid binding silently discarded, and unlike 0979 it does not even look broken. File it and fix it.

== THE THIRD THING TO CHECK ==
The fallback prompt is gated on `has_x` (`src/actions.c:4345` `if(has_x && fallback && !is_gen && filename[0])`), and a verifier reported that `file_exists` is initialised to 0 and assigned nowhere else, so with fallback=1 and no X the base-schematic branch at `:4359` fires unconditionally. **Verify that claim against the source before acting on it** — if true it is a latent bug worth its own issue; if false, say so.

== WHO ELSE IS HIT ==
* `sky130A/sky130_procs.tcl:174` and `ihp-sg13g2/sg13g2_procs.tcl:399` see the 0, do `go_back 2`, print "Can not descend into $instname" and break — a hierarchical `.save` deck silently omits that whole subtree.
* `src/wave_viewer.tcl:11104-11118` — the cross-probe cannot reach a net inside such an instance. It refuses cleanly and rolls back, so the user is refused rather than stranded; fix the cause, not the viewer.
* This branch already WORKS AROUND the defect in two committed places: `src/op_annot.tcl:2684` (with the reason spelled out at `:1845-1852`) and a row in `tests/headless/test_ase_optier_0963.tcl`. If the verb is fixed, those workarounds should be revisited in the same pass — a workaround left behind a fix is how the next reader concludes the fix does not work.
* NOT hit, and do not "fix" it: **netlisting**. It never calls `descend_schematic` and has its own unconditional missing-file fallback at `src/actions.c:4133-4139`.
* NOT a live hit: `proc traversal` (`src/xschem.tcl:3644`) prunes the subtree on a 0, but it has no menu entry, no toolbar button, no keybinding and no `actions.csv` row. Real code, unreachable by any user gesture. Do not present it as a user-facing defect.

== WHAT "FIXED" MEANS ==
The three controls named "Push schematic" must agree with each other, and `hi_descend` must stop discarding a per-instance binding that resolves to a real file. Decide deliberately whether `xschem descend` grows an optional fallback argument (default preserving today's scripted behaviour) or whether the callers change, and say which you chose and why. Whatever you choose, a GUI control must never leave a person one level down on a blank page with no prompt.

== CADENCE FRAMING, THE PROJECT'S STANDING RULE ==
User, verbatim: 'Think Cadence Cadence Cadence. We want to support the same use mode as cadence, unless it's something very reasonable and easy to implement.' In Virtuoso, descending into an instance whose bound view is missing prompts or refuses; it never drops you on an untitled blank cellview. The user has also said `schematic=` will eventually be replaced by a Cadence-style Hierarchy Editor — so do not build anything that makes that harder, and note that `schematic=` is today the **only persistent per-instance view binding in the tool** (`hi_descend_view_path` is deliberately one-shot, `src/actions.c:4306-4312`).

== ISSUE NUMBERS ==
Next free is **1210** unless S6a advanced it — read `doc/claude/issues/NUMBERING.md` first, and advance it when you are done. `1000-1199`, `0500-0599` and `0700-0799` are RESERVED for other branches.

== PLAIN ENGLISH IS A HARD REQUIREMENT ==
User ruling, verbatim: 'wording too cryptic. Give it in plain english with context, 9th grade level.' Every sentence that reaches a user's screen is written for a first-time user who says schematic, library, cell, file, setting.
