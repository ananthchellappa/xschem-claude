# Plan — CTRL+Plus / CTRL+Minus grow/shrink text size (RED-first)

Spec: `doc/claude/specs/text_size_scroll.md`. Branch `fluid-editing`. Reuses the
single-undo applier from the bus gestures; key chord (not wheel).

## Slices

1. **Docs** — spec + this plan. (done)

2. **RED tests** — `tests/text_size.tcl`
   (`../src/xschem --nogui --pipe -q --script text_size.tcl`):
   - Pure (`source utils/text_resize.tcl`):
     - grow: `0.33`→ min-step bump (`0.38` with step 0.05); `1.0`→`1.1` (10% wins).
     - shrink(s,floor): `0.38`→`0.33`; `0.12` floor `0.1`→`0.1` (clamp); `0.1` floor
       `0.1`→`0.1` (no-op).
   - Integration (needs xschem):
     - text note: `xschem text … 0.4 …`; select; `textsize_apply grow` →
       `getprop text 0 size` > 0.4; shrink back; shrink to floor.
     - net label `lab_pin {lab=clk}`: select; grow → `inst_name_text` size increased,
       and `getprop instance i text_size_0` set; shrink.
     - generic instance `res` selected with a text note: instance ignored, note grows.
   - single-undo: a note + a label selected, one grow, one `xschem undo` reverts both.
   - Confirm RED first.

3. **C** — `src/scheduler.c` + `src/callback.c`:
   - `getprop text <n> size` → `xctx->text[n].xscale`.
   - `setprop text <n> size <v>` → set `xscale`=`yscale` (new branch beside `txt_ptr`);
     honour `-fast`/`-fastundo` like the rest of the branch.
   - `xschem inst_name_text <inst>` (xschem_cmds_i): scan `sym[ptr].text[j].txt_ptr`
     for `@lab`; if found return `"<j> <xscale>"` from `get_sym_text_size(i,j,…)`, else
     reset result ("").
   - `action_registry[]`: `edit.text_grow` (`textsize_apply grow`) / `edit.text_shrink`;
     add both to `action_id_mutates`.
   - `make`.

4. **Tcl** —
   - `utils/bus_resize.tcl`: `apply_changes` — add `text` kind →
     `xschem setprop -fast text $idx size $val`.
   - `utils/text_resize.tcl` (new): namespace `textsize` (vars factor 1.1, min_step
     0.05, min_text 0.1, min_label 0.1); `grow {s}`, `shrink {s floor}`, `_round`;
     `textsize_apply {dir}` collecting `text` (size) and label `instance`
     (`text_size_<idx>` via `inst_name_text`) changes, then `busresize::apply_changes`.
   - re-run tests GREEN.

5. **Wire-up + verify** — `src/cadence_style_rc`: source `utils/text_resize.tcl`;
   `xschem bind key 43 ctrl canvas edit.text_grow` + `45/65451/65453` to grow/shrink
   (43=+ via Shift+=, 65451=KP_Add → grow; 45=- , 65453=KP_Subtract → shrink). GUI
   smoke via synthesized key events (Ctrl+'+' grows a selected note + a label's @lab,
   one undo reverts; generic instance ignored). Regression suite. Commit + push.

## Risks / notes
- `size` is a pseudo-token on text objects (maps to xscale/yscale), not a stored prop;
  document it. No collision expected with real text prop tokens.
- Label name index is found by `@lab` scan (robust vs hardcoding 0), only matches
  `@lab` (never `@name`) so the instance NAME is never touched.
- text objects have no cached bbox (hit-tested live), so no recompute needed for them;
  instances do (text size changes bbox) — handled by apply_changes' instance path.
