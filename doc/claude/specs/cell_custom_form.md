# Cell-declared Edit-Properties field customization

Status: SHIPPED (redesigned 2026-07-25). Cells: devices/{vpwl,vpulse,ipwl,ipulse}.
Related: src/property_form.tcl (slickprop), doc/claude/specs/slick_text_dialog.md.

## Problem

Some cells want a nicer Edit-Properties experience than raw `token=value` fields —
friendly labels, or a widget for a token whose shape varies (a PWL source: a
variable number of (time,value) points). But this must AUGMENT the standard
generic form, NOT replace it: the user still needs Apply-to, Library/Cell/View,
Name, and every other field. (The first cut wrongly *replaced* the whole form
with a tiny cell-only dialog — the bug this design fixes.)

## Mechanism

The generic form (`slickprop::edit_form` -> `slickprop::build_fields`) is always
shown, unchanged. A symbol may declare, in its global `K {}` props,
`edit_form=<ns>` — a namespace whose companion `<symbol>.tcl` (same path as the
`.sym`, `.tcl` ext) provides any of these OPTIONAL procs, consulted by
`build_fields` per field:

- `<ns>::field_labels`  -> dict `{token -> friendly label}`. Relabels those fields;
  everything else keeps its token name. (static cells need only this.)
- `<ns>::field_custom`  -> list of tokens the cell renders ITSELF (a custom widget
  instead of the plain entry).
- `<ns>::field_build {tok frame value}` -> pack the custom widget for `<tok>` into
  the full-width `<frame>`, seeded from the current `value` string.
- `<ns>::field_get {tok}` -> read the custom widget back as a value string.
- `<ns>::field_tips`    -> dict `{token -> hover text}`, shown by `balloon` on the
  field's label (text rows and bool rows).
- `<ns>::field_bools`   -> list of `{tok <token> label <text> on <value>}` rows:
  checkboxes for per-instance flags the template does not declare. They join
  `slickprop::inst_schema`, so they behave as the label's "Stack V" row does: an
  untouched box writes nothing, a ticked one writes `<token>=<on>`, an unticked one
  removes the token.
- `<ns>::field_readouts` -> list of `{label <text> cmd <command prefix> ?tip <text>?}`
  rows: read-only values the cell computes from the form. `cmd` is called with one
  argument, a dict token -> the field's current value (the template default for a
  field left on its placeholder), on every edit; what it returns is shown. They are
  not tokens and never reach `collect_changes`.
- `<ns>::field_fixed`   -> list of `{tok <token> label <text> value <text> ?tip <text>?}`
  rows: something the cell fixes and the designer cannot set. Each is the form's first
  rows, a disabled (greyed) entry showing `<value>`: information only. `<token>` is not
  a field of the form: nothing is written for it, and one left on the instance by an
  older sheet is neither listed under "Extra (undeclared)" nor touched.

The cell's readout rows and its `field_bools` rows sit with the declared fields, above
any "Extra (undeclared)" section (the core's own bool rows, a label's "Stack V", stay
after it).

The namespace may also be defined by a file the workarea sources instead of a
per-symbol companion `.tcl` (the sky130 resistors: `sky130_res` in
`sky130A/xschem_libs/sky130_fd_pr/sky130_res.tcl`, sourced by `sky130A/sky130_procs.tcl`
and shared by all 22 `sky130_fd_pr/res_*` symbols, which use these hooks for the `ns`
hover text, "Import split", the total-R row and the fixed-width cells' "W (fixed)"
row; fence `tests/headless/test_sky130_res_series.tcl`). The same file registers a
`devlim` provider whose rule for `ns` is of kind `count` (`devlim::corrections`,
`src/property_form.tcl`): a whole number, 1 or more, enforced where W/L limits are.

`slickprop::cellform_ns {symbol}` resolves the namespace: read the `edit_form`
attr (**load-on-throw**: `getprop symbol` throws when the symbol is not loaded in
the current context — e.g. editing an instance while a different schematic is
current — so `load_symbol` + retry; a loaded symbol without the attr returns `{}`
with no throw, so no extra load on a normal edit), then lazily `source` the
companion `.tcl`. Returns the namespace **with a leading `::`** so
`${cf}::field_labels` resolves at global scope, not `::slickprop::` (Tcl 9 TIP 278).

`build_fields` consults it once (from `$::symbol`): a token in `field_custom` gets
a spanning sub-frame built by `field_build` (marked `cur(custom,$tok)=1`,
`cur(cf,$tok)=$cf`); every other token is the standard label+entry, with the label
swapped for a `field_labels` override if present. `field_value` returns
`${cf}::field_get` for a custom token, so the existing apply path
(`collect_changes` -> `result` -> `xschem apply_properties`, one undo, Apply-to
scope, LCV all intact) writes the cell's value with no special-casing.

So xschem core carries only this generic customization hook; the labels, widget,
and netlist format all live in the library cell. Drop the cell dir into any
library and symbol + form travel together.

## Cells

All four: `type=vsource|isource`, 2 pins p/m, netlist format in the `.sym`, the
field-customization in the sibling `.tcl` (`edit_form=<ns>`).

- **vpwl / ipwl** (dynamic): `format="@name @pinlist @DC PWL(@pwl )"` (v) /
  `I ... PWL(@pwl )` (i). `field_labels {DC {DC Voltage}}` + `field_custom {pwl}`;
  `field_build` renders a "PWL points" spinbox + N (time,value) rows with a
  grey-cascade (row k editable only when every earlier row is complete);
  `field_get` joins the filled prefix into `t1 v1 t2 v2 …`. The pwl value is one
  spaced string that quote/round-trips through save + `setprop` + apply
  (`slickprop::requote`). **The space before `)` in the format is required** —
  xschem terminates a `@token` name on whitespace, so `PWL(@pwl)` reads the token
  as `pwl)`.
- **vpulse / ipulse** (static): `format="@name @pinlist @DC PULSE(@Vinit @Vpulse
  @TD @TR @TF @PW @PER )"`. `field_labels` only (Initial/Pulsed Value, Delay/Rise/
  Fall Time, Pulse Width, Period); no custom widget — each param is a plain entry.
  ngspice PULSE(V1 V2 TD TR TF PW PER).

`ipwl.tcl`/`ipulse.tcl` are self-contained namespace copies of `vpwl.tcl`/
`vpulse.tcl` (V vs I never changes the form); no cross-cell coupling.

## Tests

`tests/headless/{test_vpwl,test_vpulse,test_isources}.tcl` — pure helpers, netlist
(DC + PWL/PULSE, spaced-value quoting round-trip), and the `build_fields`
integration (GUI: friendly labels present; `pwl` rendered as a custom spinbox
widget for vpwl/ipwl and read back via `field_value`; `result` carries the edited
requoted pwl; vpulse/ipulse render plain entries, no custom widget). Property-form
neighbors (`test_pin_type_edit`, `editprop_preserve`, `perform_action_apply_pin_prop`)
stay green — normal cells resolve `cellform_ns` to `{}` and are unaffected.

## Adding another customized cell

1. `<cell>.sym`: `edit_form=<ns>` in the `K {}` props (+ its `format`).
2. Sibling `<cell>.tcl`: `namespace eval <ns> {}` + any of `field_labels` /
   `field_custom` + `field_build`/`field_get`.
No xschem core change.
