# 1310 — a NARROW (device-flavor) list is stored, written and honoured by `effective`, and never reaches the drawn sheet

**Filed by item B5 (2026-09-04) while wiring the scope dialog. Measured, stated
on screen, NOT fixed.** Status: **FILED, NOT FIXED.**

## What was measured

Item B5's scope dialog offers *this device flavor only* versus *every device of
this broad class* (spec 4.2 B7), and the narrow arm writes a `flavor` entry
keyed on the cell name. That entry is real everywhere except on the schematic:

```
op_param_lists::set_list flavor {b5cls <cell of M1>} annotation {{gm gm 1} {gds gds 1}}
op_param_lists::effective b5cls annotation <cell of M1>   -> {{gm gm 1} {gds gds 1}}   the narrowed list
op_param_lists::effective b5cls annotation <cell of M2>   -> the PDK seed              the sibling is untouched
op_annot::descriptor b5ndev                               -> BYTE-IDENTICAL before and after
```

Row **BT21** of `tests/headless/test_rdw_window_1245.tcl` is that measurement as
a fence, and row **BE4** of `tests/headless/test_op_param_store_1245.tcl` reads
the flavor rows back out of the settings file the window wrote.

## Why the display cannot follow

`op_param_lists::apply` re-registers descriptors **per `type=` token** and
passes **no cell name**, and `op_annot` holds **one descriptor per type**. A
per-cell display list therefore has nowhere to live: two cells of the same
`type=` token share one descriptor, so writing the flavor list onto it would
narrow **every** cell of that type — the exact opposite of *"narrow touches one
flavor and leaves its siblings alone"*, which is item B5's own acceptance
sentence.

Expressing it needs a change in `src/op_annot.tcl` (a per-cell display key, or a
draw-time consultation of `op_param_lists::effective` with the instance's cell
name), and item B5 may not edit that file. Note that DD-6 already rejected the
draw-time-consultation shape for `op_annot::text`, on load order — so this is
not a five-line fix and should not be taken as one.

## What ships instead

The button **says so**. `rdw::_edit`'s narrow arm ends its success sentence with

> The sheet still draws the `<class>` class list - a per-cell display list
> cannot be expressed yet (issue 1310).

That is invariant I3 read one level up: a control whose stored effect is real
and whose visible effect is absent, saying nothing, is indistinguishable from a
broken one.

## Options

* **(a)** a per-cell display key in the descriptor, written by `apply` from the
  instance's cell name — needs an instance→cell walk at apply time, which
  `apply` does not have today;
* **(b)** `op_annot::text` consults `op_param_lists::effective` with the
  instance's own cell name at draw time — rejected for `params` by DD-6 on load
  order, and it is a per-instance-per-redraw call site (issue 0447);
* **(c)** drop the narrow arm of the dialog — refused: the spec mandates it and
  DD-2 needs the flavor entry to exist for the file to be able to carry one.

**Recommended: (a)**, with the cell name resolved once per apply.
