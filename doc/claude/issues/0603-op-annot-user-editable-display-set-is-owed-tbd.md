# 0603 — the user has no first-class way to choose WHICH parameters are annotated

STATUS: **OPEN — owed, mechanism TBD.** Opened 2026-08-22 alongside ruling **D9**
(spec §4.2a), which cut the shipped MOS annotation to six rows.
Related: 0429 (superseded by D9), 0457/0458 (`annot_show` has no stock control
either), invariant **I5**, and **ruling D9b** — which landed half of what this
issue asks for.

**⛔ BLOCKED BY 0446 for one row class — ruled by the user 2026-08-22.** See
"BLOCKER" below before designing the picker.

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


---

## ⛔ BLOCKER — issue 0446, ruled onto this issue by the user 2026-08-22

**The picker must not offer `pinexpr` rows until issue 0446 is fixed, or until
the absent-net case is warned about.**

0446 is a C defect: an absent net expands to a literal `-` (`token.c:4364`), a
grounded net is hardcoded to `0.0` whether or not any raw is loaded, and
`translate`'s trailing arithmetic pass then reads `expr(- - 0.0 )` as minus
negative zero and yields a clean strict double **`0`** (`token.c:5441`). On a FET
with its source on ground — the ordinary topology — annotating the wrong `.raw`
paints **`vgs = 0`**, which reads as a real measurement of a device with its gate
shorted to its source. Every other row on the same device correctly blanks.

**Why this lands on 0603 specifically.** Ruling D9 deleted the `pinexpr` rows
from both shipped descriptors, so no PDK in this tree can reach the fabrication
today. Reaching it now needs two deliberate hand edits of Tcl — write a
descriptor with a `pinexpr` row, *and* raise `::op_annot_max_rows` above 6, since
the six defaults otherwise fill the block and the appended row is truncated away
unrendered (measured 2026-08-22, both states).

**This issue removes both barriers at once.** It exists to let a user choose rows
without editing a PDK file, and a picker that honoured a six-row cap it did not
let you raise would be a poor picker. The moment it ships, `vgs = 0` on a FET is
reachable by clicking. The user's ruling was to put the tripwire here rather than
leave it as a residual note in 0446 — because a residual note in this exact
family already failed once: 0444's sat unread from S5 until 2026-08-22.

**Acceptable ways to satisfy the blocker**, in either order:

* land 0446's C fix (refuse the `expr()` pass over an expansion containing the
  marker) and flip test rows K16 / S17b in the same change; or
* ship the picker with `pinexpr` rows withheld, and say why in the UI; or
* ship them with the 0604/I8 warning live, so a fabricated row announces itself.

## A second requirement, from the same measurement

**The picker must surface `op_annot::dropped`.** A user who adds a seventh row
under the default cap gets no row and no explanation — measured. Spec §4.2b
already names this: *"a silent truncation is precisely the class of thing
invariant I8 exists to make audible"*, and `op_annot::dropped` is the seam that
exists for it. Nothing surfaces it yet; that half belongs to **0604**.
