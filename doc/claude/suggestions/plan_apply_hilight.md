# Plan — apply_hilight (RED-first)

Spec: `doc/claude/specs/apply_hilight.md`. Branch `fluid-editing`. Pure Tcl; reuses the
existing `net_hilight_apply`.

## Slices

1. **Docs** — spec + this plan. (done)

2. **RED tests** — `tests/apply_hilight.tcl`
   (`../src/xschem --nogui --pipe -q --script apply_hilight.tcl`):
   - Pure parser `aphl::parse` -> 8-col row (compare cols 1..7, index col is placeholder):
     - named `=`: `{color="blue" pattern={10 20} thickness=10}` ->
       `{_ blue 10 {10 20} 0 0 none 0}`.
     - dict: `{color blue thickness 10 pattern {10 20}}` -> same.
     - positional: `{4 purple 3 {20 20} 0 1200 none 0}` -> unchanged (1..7).
     - aliases: `{width 5 dash {2 2} anim march_fwd speed 3}` -> cols 2,3,6,7.
     - omitted -> defaults: `{color blue}` -> `{_ blue 1 {} 0 0 none 0}`.
   - Integration: load fixture; place `lab_pin {lab=clk}`; select it;
     `apply_hilight {color green thickness 3}`; assert the style row is in
     `net_hilight_style_current`; `xschem unselect_all; xschem select_hilight_net`;
     assert `lastsel > 0` (the net is highlighted).
   - Confirm RED first.

3. **Implement** — `utils/apply_hilight.tcl`:
   - `aphl::parse {style}`: detect form (has `=` -> key=value regexp; first token a known
     key + even length -> dict; else positional). Build row from
     `net_hilight_style_default_row 0`, override mapped columns. Return the 8-col row.
   - `aphl::sel_has_net`: any selected wire, or instance whose `cell::type` is a
     label/pin (reuse `busresize::is_label_type`).
   - `apply_hilight {style}`: parse; if `sel_has_net` -> `net_hilight_apply $row` + CIW
     note; else arm `aphl::pending`, show prompt.
   - One-shot: `aphl::on_release` (gated; `after idle aphl::try_apply`), `aphl::try_apply`
     (apply + unselect + clear), `aphl::on_key %K` (Esc -> cancel), `aphl::show_prompt` /
     `clear_prompt` (statusbar + ciw_echo). Two `+`-appended binds on `.drw`
     (`<ButtonRelease>`, `<KeyPress>`), installed once at source time.
   - re-run tests GREEN.

4. **Wire-up + verify** — `src/cadence_style_rc`: source `utils/apply_hilight.tcl`; add a
   commented/active example bind, e.g.
   `bind .drw <Key-F5> {apply_hilight {color purple thickness 3 pattern {20 20}}; break}`.
   GUI smoke: (a) select a label, F5 -> it highlights in the style; (b) nothing selected,
   F5 -> prompt, click a net -> it highlights, prompt clears; Esc cancels. Regression
   suite. Commit + push.

## Risks / notes
- `+<ButtonRelease>`/`+<KeyPress>` on `.drw` must be gated by the pending var so they are
  inert normally and never interfere with selection / other keys; never bind the
  more-specific `<ButtonRelease-1>`/`<KeyPress-Escape>` (would shadow the generic
  `xschem callback` binding).
- Selection form of `net_hilight_apply` uses `xschem set hilight_color` (clamps <
  cadlayers); fine for a handful of favourite styles. Documented.
- Main-window `.drw` only; child windows get noun-verb (works) but not the prompt hook.
