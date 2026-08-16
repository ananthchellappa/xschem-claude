# 0425 — the `op_annot` descriptor key (symbol `type=`) is not unique: one `nmos` is claimed by three PDKs and the generic device library

Status: **open — measured, not fixed.** Found by the S1 Verify-C adversary of the
op-annotation run (2026-08-16) on branch `annotate`, collision set re-measured by
the write-up agent. This is a **spec-level hole faithfully implemented by S1**,
not an S1 coding defect: `doc/claude/specs/op_annotation.md` §4.2 chose the key
and S1 keyed on exactly what the spec said.

Every later step of the op-annotation plan inherits it, which is why it is filed
now rather than when it first bites.

## The key

`op_annot::register <symbol-type> <dict>` is keyed on the symbol `K`-record
`type=` token. That key was chosen deliberately and for good reasons — the cell
*name* differs per `.sch` spelling (`sky130_fd_pr/nfet_01v8` vs
`…/nfet_01v8.sym`) and `xschem getprop symbol` **raises** `Symbol not found` on
the unsuffixed form, so keying on the cell name would push a `catch` into every
caller.

## The collision, measured

`type=nmos` is not a PDK-scoped token. Every one of these carries it:

```
$ grep -l 'type=nmos' xschem_library/devices/*.sym
xschem_library/devices/nmos.sym
xschem_library/devices/nmos-sub.sym
xschem_library/devices/nmos3.sym
xschem_library/devices/nmos4.sym
xschem_library/devices/nmos4_depl.sym
$ grep -rl 'type=nmos' sky130A/ gf180mcuD/ ihp-sg13g2/
sky130A/…/sky130_fd_pr/nfet_01v8/symbol/nfet_01v8.sym
gf180mcuD/…/gf180mcu_pr/nfet_06v0/symbol/nfet_06v0.sym
ihp-sg13g2/…/sg13g2_pr/sg13_lv_nmos/symbol/sg13_lv_nmos.sym
```

Two distinct failures follow, both measured by Verify-C on this tree:

1. **A generic device picks up a PDK's descriptor.** With sky130's `nmos`
   registered, a plain `xschem_library/devices/nmos.sym` instance `M2` in the
   same cell yields `@m.m2.msky130_fd_pr__cmosn[gm]` — a sky130 inner-device name
   glued onto a device that is not a sky130 device.
2. **A second PDK silently overwrites the first.** Registering IHP's `nmos` after
   sky130's rewrites it, and the sky130 FET then builds `@n.xm1.nnfet_01v8` — IHP's
   element letter and IHP's inner-device rule on a sky130 device. `register`
   replaces rather than merges (an S1 decision, and the right one — merging would
   leak `pinexpr`/`derived` across PDKs instead), so the overwrite is total and
   silent.

## Why it matters beyond tidiness

`doc/claude/specs/op_annotation.md` §8 specifies a **cross-PDK test**: "the same
test cell shape under each registered descriptor, asserting the built vector
names match what ngspice actually wrote". As specified that test **cannot run in
one interpreter** — the second `register` destroys the first descriptor before
the second assertion runs. It has to become one interpreter per PDK, or the key
has to change.

In normal use the collision is mostly masked: each PDK registers from its own
workarea `cadence_style_rc` / `*_procs.tcl`, so only one PDK's descriptors are
usually live in a session. Failure (1) is *not* masked, though — a generic
`devices/nmos.sym` next to PDK devices is an ordinary thing to have on a
schematic, and it will annotate with a fabricated device path.

Note this fails **safe-ish** rather than silent-wrong at the data level: the
built name does not exist in the raw, so `xschem raw value` finds nothing and I3
renders blank — *for kind-0 (`i(…)`) parameters*. For kind-1 (bare) parameters it
does **not** fail safe; see the landmine added to spec §6 in the same commit —
ngspice creates a real `0.0` column for an unresolvable bare device parameter.

## Options (none applied)

* **Qualify the key**: `op_annot::register sky130:nmos …` plus a session-level
  "active PDK" set by the workarea rc. Explicit, one more concept.
* **Key on `type=` but scope the store per library**: derive the scope from the
  instance's cell path prefix (`sky130_fd_pr/…`). No user-visible concept, but
  the derivation is a string-prefix guess and guesses are how this class of bug
  started.
* **Let a descriptor carry a `match` predicate** (e.g. a glob on the cell name)
  checked after the `type=` lookup. Most flexible, most rope.
* **Do nothing, document it**, and require the cross-PDK test to fork one
  interpreter per PDK. Cheapest, and the collision keeps biting case (1).

Deciding this belongs with S2 (the three PDK descriptors), which is the first
step that can actually observe the clash.
