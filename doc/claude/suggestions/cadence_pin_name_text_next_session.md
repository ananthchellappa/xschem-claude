# Resume: Cadence-style pin-owned name text (Thread A)

Paste this to resume. **First, read these two — they hold the full state:**
- memory `cadence-pin-name-text` (and `wire-stub-netlabel`, the downstream goal)
- spec `doc/claude/specs/cadence_pin_name_text.md` (design, all phases P0–P9, §3.3 identity, file:line index)

## Where we are
Branch **`cadence-pin-name-text`** (off `fluid-editing`). Feature: a symbol PIN owns its
name text (Option B). On disk the name lives only as tokens on the pin's `B`-record
(`name= dir= show_pinname= name_dx/dy/size/rot/flip`); there is NO standalone name `T`.
In symbol-edit a transient editable `xText` "view" (`owner_pin_id` = owning pin's
`xRect.id`) is synthesized on load and skipped on save. Three seams: **S1** synth-on-load,
**S2** write-through-on-edit, **S3** skip-on-save.

**DONE + committed (P0→P3.6), all green:**
- P0/P1 `35cd449a` model + persistence seams; P2 `9e3dd1e8` `create_pin`; review fixes
  `91848aed` (disk-undo regen, sym-def init, long-name); P3 `7ea4e84b` write-through;
  P3.5 `80f8a0e0`+`335fa284` pin form + Add-Pin dialog; P3.6 `d6cadc81`+`567f3386`+`8c4ead6f`
  form rows/dir-labels/letter-cycle/show-toggle/delete-guard/rebindable keys.
- Tests: `tests/pin_name_text.tcl` **39/39** (`../src/xschem --nogui --pipe -q --script
  pin_name_text.tcl`); headless `test_bindings_file`/`test_keybindings_help`/
  `test_key_graph_context` PASS; core regression (`cd tests && tclsh run_regression.tcl`,
  grep results.log for FAIL/GOLD?/FATAL) clean; property_form suite
  (`cd src && ./xschem -q --script ../tests/property_form/wrap.tcl` → /tmp/sh_pf_test.log) clean.

## PENDING USER ACTION (ask first)
The user was going to **GUI-eyeball the P3.5+P3.6 batch** (rebuild `cd src && make && ./xschem`):
P/Shift+P keys, Add-Pin dialog + dir letter-cycle, `Q`-on-pin form (name_* rows, dir
dropdown, show-name uncheck hides, rename repaints), delete-name-alone refused.
**Confirm those feel right before building item #3 on top** (it layers on the Add-Pin form).

## IMMEDIATE NEXT: GUI item #3 — live cursor preview in the Add-Pin dialog
Make `addpin` (in `src/xschem.tcl`, namespace `addpin`) MODELESS with arm-on-name-change,
mirroring `ciform` in `src/create_instance.tcl` (`arm` / `after_drop` /
`install_drop_hook` / `escape` / `abort_if_placing`): once Pin Name is non-empty, moving
the mouse onto the canvas previews the pin on the cursor; click drops; re-arm for the next;
Esc finishes. **RISK to handle:** today `xschem add_symbol_pin -place` (scheduler.c) does
`push_undo + create_pin + move_objects(START)` — arming on each keystroke would (a) spam
undo and (b) leave orphan preview pins. So: abort the current preview on re-arm
(`xschem abort_operation`, gated on `ui_state & START_SYMPIN`), and don't push_undo until
the drop (move END). Verify abort cleanly removes the un-dropped pin+view. GUI-only — hand
the user a manual checklist (this is not headless-testable; `xschem callback` segfaults
under `--nogui`).

Also still open from item #1: `view.center_at_cursor` ships UNBOUND (so Shift+V stays
Vertical-Flip). If the user names a key, add a default `set_input_binding`/keybindings.csv
row (regenerate via `save_input_bindings_file keybindings.csv {key}`, drift-guard).

## THEN (later phases, see spec §8)
- **P4** copy/paste: delete-of-lone-view already DONE (P3.6); remaining = `copy_objects`
  (move.c) / paste (paste.c) must SKIP view objects and regenerate views after the copied
  pin's name is uniquified (else stray/duplicate labels).
- **P5** show/hide: global tri-state `show_pin_names` (on/off/auto) that WINS over per-pin
  `show_pinname` (locked decision). Draw gate.
- **P6** instance display: `draw_symbol` renders pin names from the symbol's pin tokens
  (Way A — do NOT synth into the `sym[]` cache). *Until P6, placed instances show no pin
  names — expected, not a bug.*
- **P7** ERC/check + assert netlist golden unchanged (display-only) + docs/tutorial.
- **P8** migration: Python at `tools/migrate/` (idempotent, brace-aware, `--dry-run`/
  `--backup`; adopt a legacy literal label only on EXACT name match, else owned-but-hidden;
  skip 0-pin/label/`@`-templated/dup-name; targets only `B` layer-5 in `.sym`).
- **P9** the original goal — wire-stubs + auto `lab_pin` net-labels (spec
  `doc/claude/specs/wire_stub_netlabel.md`); the Thread-B size getter reads `name_size`.

## Key facts (avoid re-discovery)
- `xText.owner_pin_id` (xschem.h): 0 = ordinary text, !=0 = synth view (= pin xRect.id).
  Init at ALL text births: create_text/load_text/merge_text/copy_objects (load_sym_def too).
- Helpers in actions.c: `synth_pin_views`, `create_pin`, `pin_idx_by_id`,
  `pin_name_view_of` (non-static), `pin_view_refresh` (full sync), `pin_view_apply`
  (create/delete per show + sync), `pin_reorient` (dir→name_dx/name_flip),
  `pin_view_writeback`/`pin_rename_from_view`/`pin_views_reconcile_after_move`.
- Pin form = slick graphical form: `slickprop::gfx_schema "pin"` (property_form.tcl) +
  `gfxform`/`text_line_slick` (xschem.tcl); `gfxform::selected_type` returns `pin` for a
  layer-5 rect (selection row `{rect n col id}`, col=5). `Q`-on-name-view retargets to its
  pin rect in `edit_property` (editprop.c). Add-Pin dialog `addpin::open`/`place` +
  `combo_letter_cycle`.
- DISK undo is the default — any new load-equivalent path must re-synth views (we hit this).
- get_tok_value() uses ONE static buffer — copy `name` before other token reads.
- Action registry: `init_input_bindings` + `keybindings.csv` (regen + drift-guard), ids in
  `action_registry[]` (callback.c) + `actions.csv`. Key event test:
  `xschem callback .drw 2 <mx> <my> <keysym> 0 0 <state>` (letters use rstate=state&~Shift).
- User runs the GUI as `src/xschem --script src/cadence_style_rc`; rebuild after C changes.
- Commit msgs end with the Co-Authored-By line; commit only when asked.
