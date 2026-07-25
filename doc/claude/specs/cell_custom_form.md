# Cell-declared custom Edit-Properties forms

Status: SHIPPED (2026-07-24). First cell: `devices/vpwl`.
Related: src/property_form.tcl (slickprop), doc/claude/specs/slick_text_dialog.md.

## Problem

Some cells need a bespoke property-edit dialog whose UI adapts to user input
(e.g. a PWL source: a variable number of (time,value) rows, greyed until the
prior row is filled). That logic belongs to the CELL, not to xschem core.

## Mechanism (the only core change)

`slickprop::edit_form` (src/property_form.tcl) already routed the built-in pin
cells (`ipin/opin/iopin`) to `schpin::edit_form`. Generalized into a
cell-declared, library-owned hook:

1. A symbol declares, in its global `K {}` props, `edit_form=<ns::proc>`.
2. On Edit Properties, `slickprop::edit_form` reads that attr
   (`xschem getprop symbol $symbol edit_form`). If set:
   - if the proc is not yet defined, **lazily source the companion `<symbol>.tcl`**
     (same path as the `.sym`, `.tcl` extension), then
   - `return [<ns::proc>]` — the custom form runs INSTEAD of the generic form.
3. The custom form reads the instance prop from `$::tctx::retval`
   (`xschem get_tok`), and on Apply/OK writes back with
   `xschem setprop instance <name> <tok> <val>` (the `schpin::edit_form` idiom),
   sets `::tctx::applied 1`, redraws, and returns `{}`.

**Fully-qualify the proc name (leading `::`)** in the dispatch: `edit_form`
runs in the `::slickprop` namespace, so a bare `vpwl::edit_form` would resolve
as `::slickprop::vpwl::edit_form` and never be found (Tcl 9 TIP 278). See memory
`tcl9-tip278-namespace-vars`.

So: the cell owns its netlist (symbol `format`) AND its form (companion `.tcl`);
xschem core carries only one generic, cell-agnostic dispatch. Drop the cell dir
into any library and symbol + form travel together — no rc or core edits.

## The `devices/vpwl` cell (worked example)

`xschem_libs_newsym/devices/vpwl/symbol/{vpwl.sym,vpwl.tcl}`.

- **Symbol** (`vpwl.sym`): 2 pins (p/m), `type=vsource`,
  `template="name=V1 DC=0 pwl=\"0 0 1n 1\""`,
  `format="@name @pinlist @DC PWL(@pwl )"`, `edit_form=vpwl::edit_form`.
  - Netlist: `V<name> <p> <m> <DC> PWL(<pwl> )` — DC value used for OP/DC, PWL
    for transient. **The space before `)` is REQUIRED**: xschem terminates a
    `@token` name on whitespace only, so `PWL(@pwl)` would read the token as
    `pwl)` (not found → empty). ngspice tolerates the inner space.
  - Points stored as ONE `pwl="t1 v1 t2 v2 …"` string (spaced values quote/
    round-trip through save + `setprop` fine), so the netlist format stays
    static — the FORM does the split/join.
- **Form** (`vpwl.tcl`, namespace `vpwl`):
  - pure helpers `split_pairs` / `prefix_pairs` / `join_pairs` / `validate`
    (headless-testable, no Tk).
  - `edit_form`: DC Voltage entry; "Number of points" spinbox (>= 2, default 2);
    N dynamic (time,value) rows; **grey-cascade** (`refresh_cascade`: row k
    editable only when every earlier row is a complete pair — no interior gaps);
    changing N rebuilds rows (`rebuild_rows`, values preserved). Apply validates
    (>= 2 complete leading points), joins the filled prefix into `pwl`, writes
    `DC`+`pwl` onto the instance.

## Tests

`tests/headless/test_vpwl.tcl` (29 checks): pure helpers; symbol declares
form+format; netlist DC+PWL with spaced-value quoting round-trip; GUI-gated
form (seed / dynamic N / grey-cascade / apply); GUI-gated **dispatch**
(green-but-hollow: delete the form proc, prove `slickprop::edit_form`
lazy-sources + routes, seeded from `retval`).

## The `devices/vpulse` cell (static-form example)

Same hook, but the field set is FIXED — the custom form exists only to give the
ngspice PULSE parameters friendly labels (the generic slick form would also
render them, just labelled by raw token name).

- **Symbol** (`vpulse.sym`): 2 pins, `type=vsource`,
  `template="name=V1 DC=0 Vinit=0 Vpulse=1 TD=0 TR=1n TF=1n PW=50n PER=100n"`,
  `format="@name @pinlist @DC PULSE(@Vinit @Vpulse @TD @TR @TF @PW @PER )"`,
  `edit_form=vpulse::edit_form`. Netlist:
  `V<name> p m <DC> PULSE(V1 V2 TD TR TF PW PER )` — ngspice PULSE order
  (V1 initial, V2 pulsed, TD delay, TR rise, TF fall, PW width, PER period).
  Every param is its own token so the whitespace-terminator rule is automatic;
  the single space before `)` is still required.
- **Form** (`vpulse.tcl`, namespace `vpulse`): one static grid built from a
  `{token label}` table (`vpulse::fields`) — DC Voltage, Initial/Pulsed Value,
  Delay/Rise/Fall Time, Pulse Width, Period. No dynamic rows, no cascade. Apply
  writes each field with `xschem setprop instance`.
- **Tests**: `tests/headless/test_vpulse.tcl` (18 checks).

## Adding another custom-form cell

1. Author `<cell>.sym` with `edit_form=<ns>::edit_form` (+ its `format`).
2. Author the sibling `<cell>.tcl` defining `<ns>::edit_form` (read
   `$::tctx::retval`, apply via `xschem setprop instance`, return `{}`).
No xschem core change.
