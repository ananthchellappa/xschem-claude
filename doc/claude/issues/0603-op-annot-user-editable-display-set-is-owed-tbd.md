# 0603 — the user has no first-class way to choose WHICH parameters are annotated

STATUS: **OPEN — owed, mechanism TBD.** Opened 2026-08-22 alongside ruling **D9**
(spec §4.2a), which cut the shipped MOS annotation to six rows.
Related: 0429 (superseded by D9), 0457/0458 (`annot_show` has no stock control
either), invariant **I5**, and **ruling D9b** — which landed half of what this
issue asks for.

**⚠ PARTIALLY ANSWERED 2026-08-22 BY D9b.** The *count* half now has a setting:
`::op_annot_max_rows` (default 6, `0` = no limit), read live by
`op_annot::text`, settable from any `--script` rc or the console. What is still
owed is the *which* half — choosing the parameters themselves — and a means that
is not Tcl.

---

## What D9 decided, and what it deliberately did not

The user's words: *"Change display default to only display id, gm, gds, vgs, vth,
vds. We will provide a means (TBD) for user to update to what she wants. Too many
parameters displayed is just clutter."*

Six is the right **default**. It is not a claim that six is all anyone may have.
A designer debugging a slew-limited stage wants `vdsat`; somebody sizing for
bandwidth wants `cgg` and an fT; a device engineer wants the overlap caps. Today
the only route to any of that is:

```tcl
set d [op_annot::descriptor nmos]
dict set d params [concat [dict get $d params] {{vdsat vdsat 2} {cgg cgg 1}}]
dict set d derived {{ft {$gm/(2*3.141592654*$cgg)}} {gm/id {$gm/$id}}}
op_annot::register nmos $d
```

three lines of Tcl, in a `--script` rc, with the `{label param kind}` triple and
the `0`/`1`/`2` wrapper convention memorised. That is an **extension mechanism**,
not a user interface, and invariant I5 makes it worse than it looks: it cannot go
in `~/.xschem/xschemrc`, because xschemrc is sourced at `xinit.c:3234-3292`,
*before* `xschem.tcl` at `:3401`, so `op_annot::register` there dies with
`invalid command name`.

## What is actually required

* Reachable **without editing a PDK file** — a user who adds `vdsat` must not
  have their change reverted by the next PDK update, and must not need write
  access to `sky130A/`.
* Per **device class**, since that is what the descriptor is keyed on
  (`nmos`, `pmos`, `vertical_npn`, …), and ideally per **project**.
* Persistent across sessions.
* Must not require a rebuild or a restart — I5's "takes effect on redraw" is a
  property worth keeping.
* Should be able to express the three row kinds the descriptor already has
  (`params`, `derived`, `pinexpr`), or say plainly that it only edits `params`.

## Candidate shapes, none chosen

1. **A dialog** off the same menu the annotation keys live on: the registered
   list with checkboxes, plus an "add parameter" field. Discoverable; needs a
   place to persist to.
2. **A Tcl list variable** mirrored C-side like the other config vars
   (`MIRRORED IN TCL`), e.g. `op_annot_params(nmos)`, settable from a plain rc
   line and from the console. Cheapest; still text, but one line instead of
   three and no dict grammar.
3. **A per-schematic property**, so a testbench carries its own annotation set.
   Matches how xschem stores other view state; collides with I4 (the overlay
   never modifies the schematic) unless it is read-only view state.

## Why this is filed rather than implemented

D9 was a decision about a default. The means is a separate design with its own
persistence question and its own tests, and shipping the trim first is what makes
the default honest — the extra rows are recoverable today for anyone who reads
this file.
