# 0425 — the `op_annot` descriptor key (symbol `type=`) is not unique: one `nmos` is claimed by three PDKs and the generic device library

Status: **DECIDED AND IMPLEMENTED by S2 (2026-08-16), branch `annotate`.** The
ruling, the rejected alternatives, the measured before/after and the accepted
residual are at the bottom of this file under
[The S2 ruling](#the-s2-ruling--optional-match-glob-list-l1--i3). The analysis
above it is the original S1 filing, left as written.

Found by the S1 Verify-C adversary of the
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

---

# The S2 ruling — optional `match` glob list (L1 / I3)

**Chosen: option 3, "let a descriptor carry a `match` predicate".** A descriptor
may carry an optional `match` key holding a list of globs, tested with
`string match -nocase` against the instance's cell name
(`getprop instance <n> cell::name`, e.g. `sky130_fd_pr/nfet_01v8.sym`). A
descriptor that matches no glob builds **no devpath**. Absent or empty `match` is
permissive — exactly the behaviour before the key existed.

```
sky130  match {*sky130_fd_pr/*}
gf180   match {*gf180mcu_pr/*}
IHP     match {*sg13g2_pr/*}      (nmos, pmos and vertical_npn)
```

Implementation: `op_annot::_matches` in `src/op_annot.tcl`, called from ONE new
line in `op_annot::devpath` immediately after the descriptor lookup. Everything
below that line — devproc-vs-template, `_lower`, `_simpath`, the error discipline
— is untouched. `_matches` **never raises**: it runs inside a draw / `tcleval`
path, so an unreadable instance or a malformed glob list is a data condition
answered with 0 (i.e. blank), not an exception.

## Ladder rung and grounding

**L1, invariant I3** ("a missing vector renders BLANK — not 0, not NaN, not the
previous run's number"), via spec §6 landmine 9. The landmine was re-measured by
the S2 adversary rather than trusted: a deck asking for a device name that does
not exist produces a raw header carrying
`@m.xm1.msky130_fd_pr__nfet_01v8[gm] admittance dims=0`, **no stderr warning**,
and `xschem raw value <that> 0` returns `0` while the correct name returns
`0.00079867192`. A wrong descriptor is therefore indistinguishable from a real
zero on the schematic. Blank is the only I3-compliant outcome for a device a
descriptor does not own, and `match` is what produces it.

## Rejected alternatives

* **Option 1, qualify the key** (`op_annot::register sky130:nmos …` plus a
  session-level "active PDK"). Rejected: a new user-facing concept plus a rewrite
  of every lookup, to solve a problem a per-descriptor predicate solves with one
  optional key and one line in `devpath`.
* **Option 2, scope the store per library** by deriving the scope from the cell
  path prefix. Rejected: the derivation is a string-prefix *guess* made by the
  framework. `match` makes the same string-prefix test, but the PDK author writes
  it explicitly and can see it in their own file.
* **Option 4, do nothing and document it.** Rejected outright: it leaves failure
  (1) live, and failure (1) fabricates numbers on an ordinary mixed schematic.

## Measured — BEFORE (verbatim, from the S2 Measure agent's transcript)

```
BEFORE-3 descriptor nmos         = {}
BEFORE-5 descriptor vertical_npn = {}
BEFORE-6 op_annot::type M1       = {nmos}
BEFORE-7 op_annot::devpath M1    = {}
0425-1 after sky130 register, descriptor nmos devpath = {\@m.@path@spiceprefix@name\.msky130_fd_pr__@model}
0425-2 after IHP    register, descriptor nmos devpath = {\@n.@path@spiceprefix@name\.n@model}
0425-3 sky130 descriptor still reachable = 0
0425-4 devpath M1 (IHP cell, sky130 reg lost) = {@n.xm1.nsg13_lv_nmos}
```

and, on the two-instance fixture (sky130 `nfet_01v8` M1 + generic
`devices/nmos.sym` M2), before the key existed:

```
failure (1)  devpath M2 = @m.m2.msky130_fd_pr__cmosn      <- sky130 name, non-sky130 device
failure (2)  devpath M1 = @n.xm1.nnfet_01v8               <- IHP name, sky130 device
```

## Measured — AFTER

```
ok: P28 0425(1) a generic devices/nmos gets NO devpath under a match glob
ok: P30 0425(2) a cross-PDK overwrite degrades to BLANK, not a wrong name
ok: P29 0425 vector on a non-matching instance is BLANK, not a raise
ok: P27 CONTROL a descriptor with NO match key still annotates everything
ok: P26 all seven registrations carry their PDK's match glob
```

Both failure modes now produce `{}`. `P27` is the backward-compatibility control
and is what keeps S1's 32 original rows and a user's own `op_annot::register`
(invariant I5) working unchanged — all 32 stayed green with no edits.
`P29` matters separately: `vector` short-circuits on the blank devpath *before*
`_kind`'s deliberate raise, so a draw path never sees an exception.

## Consumer contract — THIS IS A CHANGE

**A non-empty descriptor no longer implies a non-empty devpath.** S3's walk and
S5's formatter must skip on a blank `devpath`, never on a blank `descriptor`.
Recorded in the `src/op_annot.tcl` header and in spec §4.2.

## Sabotage matrix (S2 Verify-B, 6 variants, all restored, md5-verified)

| variant | predicted red | observed |
| --- | --- | --- |
| `match_guard_noop` (`_matches` → `return 1`) | P28, P29, P30 | **3, exactly as predicted** — and P27 correctly stayed green, confirming it tests backward compatibility and not the guard |
| `sky130_devproc_naive` (four-way switch → §4.2's single template) | P3, P4, P5, P6, P7 | 5 |
| `ihp_npn_no_5t_strip` | P21, P22 | 2 |
| `gf180_register_noop` | P13, P14, P15, P26 | 5 (bonus P25) |
| `ihp_params_truncated_to_spec` | P19, P20, P21, P23 | 5 (bonus P25) |
| `pmos_registrations_dropped` | P2, P13, P15, P20, P26 | 7 (bonus P18, P25) |

**No predicted red failed to appear.** The two "bonus" columns are extra rows
that also caught the sabotage, which is coverage, not noise.

## Still open

* **ACCEPTED RESIDUAL — the overwrite itself is not fixed.** Two PDKs registered
  in one interpreter still lose the first registration; `register` replaces
  rather than merges (an S1 decision, and the right one). What `match` buys is
  that the loss degrades to **blank** instead of to a confidently wrong name.
  Spec §8's "one interpreter per PDK" still stands, and the S2 suite is written
  that way — one section per PDK, each re-setting `XSCHEM_LIBRARY_PATH` and
  sourcing its own procs file immediately before its own assertions.
* **A new silent-blank mode, same class, not covered by the residual note.** A
  genuine PDK FET whose symbol was **copied or wrapped into a project library**
  gets cell name `mylib/nfet_01v8.sym`, matches no glob, and annotates not at
  all — with no diagnostic. Measured: two instances of the identical symbol in
  one cell, referenced as `sky130_fd_pr/nfet_01v8` and `mylib/nfet_01v8.sym`,
  give `@m.xm1.msky130_fd_pr__nfet_01v8` and `{}` respectively, though both
  netlist identically. Copying PDK symbols into a project library is ordinary EDA
  practice. I3-safe (blank, not wrong) but unrecorded until now.
* **`match` has no loud failure mode.** `register` raises on a malformed dict,
  but a glob that matches *nothing* is indistinguishable from "this PDK is
  unsupported" — the exact ambiguity op_annot's error discipline exists to avoid.
  A user's I5 override with a typo'd glob blanks everything, silently. A
  `op_annot::why <inst>` diagnostic (which descriptor was found, which glob
  rejected it) would close this and is worth a row in a later step.
* One run in 22 of the adversary's sweep reported no `pmos` descriptor registered
  at all, and could not be reproduced in 21 further runs including 3 under 4-way
  CPU contention. Most likely an artifact of a concurrent file write in the
  adversary's own harness, but it could not be proven so, and a silently-missing
  registration is precisely the failure this design exists to prevent.
