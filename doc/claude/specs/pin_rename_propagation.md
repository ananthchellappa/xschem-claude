# Pin-rename label propagation (Cadence behaviour)

Implementation: `pin_rename_targets()` (pure decision) and
`propagate_pin_rename()` (mutation shell) in `src/editprop.c`, codes and
prototypes in `src/xschem.h`. Called from `apply_symbol_prop()`
(`src/editprop.c`) and the `setprop instance` arm (`src/scheduler.c`). Option
`pin_rename_propagate` (`src/xschem.tcl`). Test:
`tests/headless/test_pin_rename_propagate.tcl` (47 checks, true `--nogui`).

## The behaviour

In Virtuoso, renaming an interface pin in a schematic immediately renames every
wire label that carried the same name, so the nets the user drew stay attached
to the pin. xschem now does the same.

Concretely: when an `ipin` / `opin` / `iopin` instance's `lab` changes from OLD
to NEW, every `type=label` instance in the same schematic whose net name is
exactly OLD becomes NEW, in the same undo step.

Without this, a rename silently disconnects: the pin moves to the new net, the
labels stay on the old one, the drawing looks unchanged, and the break only
shows up in the netlist.

**Fail-loud, all-or-nothing.** Where the right action is ambiguous the
propagation does *nothing* and *warns*. A partial rewrite is worse than none: it
leaves the sheet internally self-consistent and thereby erases the ERC evidence
(`sym_vs_sch_pins` orphan-label errors) that would otherwise report the damage.
Refusing restores the loud pre-feature failure.

## What is a pin, what is a label

Read from the symbol's `type` token via the existing macros in `xschem.h`:

| symbol | `type=` | role |
|---|---|---|
| `ipin.sym`, `opin.sym`, `iopin.sym` | `ipin`/`opin`/`iopin` | rename SOURCE (`IS_PIN`) |
| `lab_pin.sym`, `lab_wire.sym`, `vdd.sym`, `gnd.sym` | `label` | rename TARGET (globals excepted, below) |
| everything else | — | untouched |

`show_label`, `scope` and `bus_tap` are matched by `IS_LABEL_SH_OR_PIN`
elsewhere but are **not** targets here: they are annotation/pass-through
symbols, not the user's net naming.

## Direction, scope

**Pin → labels only.** Renaming a label is the user's only gesture for moving
one wire onto a different net; propagating it would make detaching a wire
impossible. The pin name is also part of the cell's contract
(`sym_vs_sch_pins`, `@pinlist`), so a label edit must never rewrite the
interface. `netlist.c` already encodes the asymmetry — a pin declares a port and
a direction, a label declares nothing.

**Current schematic only.** Undo is a whole-schematic snapshot per context and
each tab owns its own undo ring, so an edit spanning two contexts could not be
one undo step. Repairing the parent is a different operation on different data
(symbol `PINLAYER` rects, not net names) and already has an authoritative
reporter in `sym_vs_sch_pins()`, which would be defeated by silently editing the
symbol from the schematic side. **Consequence:** after a pin rename the parent is
stale until the user netlists or checks — as it was before this feature.

## Matching rule

Compare on `get_tok_value(prop_ptr, "lab", 0)` — the *evaluated* value, which is
exactly what `inst[].lab` holds and what every netlist backend consumes. A pin
`lab=tcleval($::EE)` with `EE=FOO` and a label `lab=FOO` are the same net, and
matching on the raw text would strand that label.

Write `get_tok_value(prop_ptr, "lab", 3)` — the *raw* text, backslashes and
quotes kept, unevaluated. Writing the evaluated form would freeze the labels to a
snapshot of an expression-valued pin name and let the two diverge on the next
change.

- **Case-sensitive.** `xctx->case_insensitive` governs symbol-file lookup on
  case-insensitive filesystems; every one of its call sites compares symbol
  names, none compares net names.
- **No bus expansion.** `A[3:0]` → `D[3:0]` rewrites a label whose text is
  exactly `A[3:0]`; see the overlap refusal below for `A[2]`.

## Edge cases

| case | action | feedback |
|---|---|---|
| OLD empty | no-op | silent |
| NEW empty (name cleared, or the attribute-delete form) | pin cleared, labels untouched | silent |
| NEW == OLD | no-op | silent |
| source is not a pin (label→label, symbol carrying `lab=`) | no-op | silent |
| another **pin** still carries OLD | refuse entirely | warn |
| NEW already names other labels/pins | **propagate** — that is how a user joins a net | warn (nothing else reports it: `signal_short` only fires when two *different* names meet on one conductor) |
| OLD is a **global** net name | refuse entirely | warn |
| NEW is a **global** net name | refuse entirely | warn |
| a label **bit-overlaps** OLD without matching exactly | refuse entirely | warn |
| a matching label is **SELECTED** | refuse entirely | warn |
| fan-out Apply (`scope` = selected/all, `Shift+Q`) | never propagates | — |
| `setprop -fast` | never propagates | — |
| read-only buffer | rename already rejected upstream | existing rejection |
| symbol view | no instances, no-op | silent |

### Globals refuse in both directions

A name is global iff it is `"0"` or some `type=label` instance carrying it
declares `global=true|ground` — instance property first, then symbol property,
the netlister's own two-step. Globals span the hierarchy while this rewrite is
sheet-local: moving the `vdd` instances on one sheet would split the power net
from every other sheet. Renaming a signal pin *onto* `VDD`/`0` is a design-wide
short that no ERC reports.

### Bus overlap refuses

There is no defined semantics for renaming *part* of a bus, and the connectivity
engine is itself inconsistent about bus identity (the node hash and fly-lines
treat `A[3:0]` and `A[2]` as overlapping; `signal_short` and `sym_vs_sch_pins`
compare the unexpanded strings). Rewriting only the exact label would leave
`A[2]` — formerly bit 2 of the port — as an unrelated floating net with nothing
reporting it. Detection reuses `flyline_same_net()` (`src/flyline.c`), the tree's
one bit-precise comparator, de-`static`'d for this purpose.

### Selected labels refuse the whole propagation

A selected object is one the user is editing directly. Skipping just that label
would **split** the net — xschem connects by name across disjoint geometry, so a
skipped label on a separate cluster becomes its own floating net with no ERC. So
the propagation refuses instead.

This is also what keeps `src/change_index.tcl` (the `+`/`-` bus-index keys)
correct: it loops `setprop` over `xschem selected_set`, so with pin `A[3]` and
label `A[3]` both selected the label would otherwise get two edits — propagated
to `A[4]`, then bumped again to `A[5]`. Measured before the guard: `{A[4]}
{A[5]}`. **Accepted cost:** select-all then rename via the pin form does not
propagate — but it warns, so it is not silent.

### Fan-out Apply never propagates

`scope=selected`/`all` gives every pin in the target set the *same* new name.
Measured on the unguarded build: three pins `A,B,C` each with a label, Apply
`lab=Z` with `scope=all`, yields `Z Z Z Z Z Z` — three distinct nets merged
sheet-wide, with the propagation erasing the evidence. Guarded with
`if(ntargets == 1)`.

### `-fast` is excluded

`setprop -fast` pushes no undo and skips `draw()`, and its callers loop over a
whole selection themselves — `utils/bus_resize.tcl` issues one `-fast setprop`
per selected pin *and* label under a single outer undo, so propagating would
double-edit exactly what the loop is about to edit. `-fastundo` and the plain
form both push undo and both propagate.

### `reset_inst_prop` is not a rename

`xschem reset_inst_prop <ref>` discards an instance's attributes back to the
symbol template, which for a pin clears its `lab`. It has its own inline writer
and does not propagate — deliberately. The invariant is `push_undo ⇔ propagate`
for **renames**, not "every logged `lab` write propagates". Locked by test P17.

## Warnings

Both channels, on every refusal a user would notice:

```c
statusmsg(msg, 1);   /* status bar -- what a GUI user sees        */
statusmsg(msg, 2);   /* info buffer -- readable headless via
                        `xschem get infowindow_text`              */
```

`n==2` alone is not enough: the info window is a snapshot, defaults to hidden,
and every netlister wipes the buffer on entry. `n==1` alone is invisible to a
headless test.

## Option

`pin_rename_propagate`, default **1**. MIRRORED IN TCL: `set_ne` in
`src/xschem.tcl`, listed among the persisted variables, exposed as *Symbol →
"Renaming a pin renames its net labels"*, read from C with
`tclgetboolvar()`.

Default on because that is the Cadence behaviour being reproduced; defeatable
because it rewrites objects the user did not select.

## Hook points — two, and why not one

Every user-initiated `lab=` write on a schematic instance reaches exactly one of
two writers, and neither calls the other:

1. **`apply_symbol_prop()`** — the slick Edit Properties form (via
   `xschem apply_properties` → `apply_instance_properties()`), the vim/legacy
   editor (`update_symbol()`), and scripted `apply_properties`.
2. **the `setprop instance` arm** (`src/scheduler.c`) — **the Cadence pin form**
   (`property_form.tcl` diverts `ipin/opin/iopin` to `schpin::edit_form`, whose
   Apply issues `xschem setprop instance <inst> lab <name>`), `change_index.tcl`,
   every script/CIW call, the `allprops` whole-string form, and action-log
   replay.

Hooking only the first leaves the primary GUI pin-rename gesture unhooked;
hooking only the second leaves `Shift+Q` and scripted `apply_properties`
inconsistent.

`set_inst_flags()` was considered as a single choke point and rejected: it also
fires during file load, paste and *inside the netlister's own `lab=` write-back*,
so mutating from there inverts its contract; and its `inst->lab` cache is
refreshed only under `if(cond)` with no `else`, so it can hold a stale name.

`propagate_pin_rename()` pushes no undo, sets no modify flag and does not
redraw: the caller has already pushed one undo for the whole edit, so the rewrite
lands in the same slot and a single undo restores pin and labels together. It
invalidates `prep_hash_inst` / `prep_net_structs` / `prep_hi_structs`.

## Not done

- No hierarchy repair (the parent schematic's instance is untouched).
- No bus-aware partial rename.
- No propagation to `text` objects spelling the old net name — annotation, not
  connectivity. Wires carry no name, so there is nothing to rewrite on them.
- No action-log entry of its own: the propagation is a consequence of the logged
  pin edit, and replaying that edit reproduces it.
- No `pin_rename_targets` Tcl query verb. The pure core exists and is used by the
  shell, but the tests assert through effects plus the warning buffer rather than
  adding command surface.

## Regression surface

Every instance-property Apply now runs one extra scan over the instance array.
The sweep run against this change (audit-classified, all PASS): the 18
pin/label/property tests, plus `test_expandlabel_zero_neg_mult_0182`,
`test_hash_extra_node_warn_0165` and `test_flylines_render` (the de-`static`'d
comparator), plus the golden netlist harness `run_nogui.sh`.
