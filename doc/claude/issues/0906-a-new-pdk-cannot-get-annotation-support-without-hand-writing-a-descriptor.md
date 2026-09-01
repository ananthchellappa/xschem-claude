# 0906 — a new PDK cannot get device-OP annotation without hand-writing an undocumented descriptor

**Status:** **OPEN, MEASURED, NOT FIXED.** Filed 2026-08-28 at the user's request,
during the demo-readiness review. **Not to be worked on yet** — the user asked for
a spec and an issue only.

**Spec:** [pdk_annotation_bootstrap.md](../specs/pdk_annotation_bootstrap.md)
**Parent:** [op_annotation.md](../specs/op_annotation.md) §4.2 (the descriptor format)

---

## 1. What the user sees

A designer on any PDK other than sky130, gf180mcu or IHP SG13G2 runs a simulation,
presses `6`, and gets **an empty six-row device block on every transistor,
forever, with no message.** Node voltages (`Alt-6`) and transient-at-cursor
(`Alt+Shift+6`) work — only the device operating-point block is dead, which makes
the failure look like a data problem rather than a configuration one.

Nothing tells them why. There is no error, no menu entry, no hint in the status
line, and `op_annot::register` appears in **no user-facing document** — not
`README.md`, not `INSTALL`, not `doc/`.

## 2. The measurement

```
$ grep -rln "op_annot::register" --include="*.tcl" .
sky130A/sky130_procs.tcl
gf180mcuD/gf180_procs.tcl
ihp-sg13g2/sg13g2_procs.tcl
src/op_annot.tcl                      <- the definition
tests/headless/test_op_annot.tcl      <- test-local descriptors
tests/headless/test_annot_stale_0684.tcl
tests/headless/test_ase_final.tcl
```

Three PDK profiles, and nothing else. `op_annot::descriptor` returns `{}` for an
unregistered type — deliberately blank, never a raise, because *"this type is not
annotated" is a data condition* (`src/op_annot.tcl:336-343`). That design choice
is right for the renderer and is exactly why the user gets silence.

## 3. Why hand-writing one is harder than it looks

Four separate traps, each already paid for once by an existing PDK:

1. **The guard.** A raise inside a PDK procs file prints `Tcl_AppInit() error: can
   not execute <rc>` and **abandons the rest of `cadence_style_rc`** — the PDK
   menu, `user_startup_commands`, the library-manager autostart — while still
   exiting 0 (`sky130A/sky130_procs.tcl:310-316`). Every shipped registration is
   wrapped in `if {[info commands ::op_annot::register] ne {}}` for this reason.
2. **`nmos` and `pmos` are separate keys.** `op_annot`'s key is an exact array
   index, not a regexp. The original IHP prototype branched on `regexp {[pn]mos}`;
   copying that shape leaves every PMOS symbol unannotated in silence
   (`sky130A/sky130_procs.tcl:318-320`).
3. **`match` is mandatory.** Issue **0425**: `type=nmos` is shared by sky130,
   gf180, IHP *and* `xschem_library/devices/nmos.sym`. Without a `match` glob a
   descriptor claims another PDK's devices.
4. **`devpath` is not derivable from the symbols.** It is the SPICE hierarchical
   path to the inner device, a property of the PDK's subcircuits and the
   simulator's naming. sky130 needs a **four-branch** proc
   (`sky130_op_devpath`, `sky130A/sky130_procs.tcl:298-308`); gf180 needs a single
   template; IHP's NPN proc strips a `_5t` suffix. Nothing in the symbol library
   tells you which.

## 4. Scope of the impact

This is the difference between *"clone the branch and use the feature on your own
project"* and *"clone the branch and use the feature on one of three PDKs."* It
was ranked in the demo-readiness review as the reason a "use it on your own
design" video segment cannot be delivered: the device block ends up permanently
empty for any viewer not on those three.

**Honest scoping.** This is not a regression and not a defect in the annotation
engine — the engine behaves as designed. It is a **missing on-ramp**. The severity
comes entirely from its silence and from its absence from every document a user
reads.

## 5. What the user asked for

Verbatim, 2026-08-28:

> *"New PDK - add annotation support using a python script. The script can ask if
> they would like it to be as similar as possible to one of the existing three
> PDKs."*

The spec [pdk_annotation_bootstrap.md](../specs/pdk_annotation_bootstrap.md)
records the design. Its shape:

* a **discovery pass** over the PDK's symbol library — types, counts, a candidate
  `match` glob, model names — reported before anything is generated;
* three routes to the hard part, `devpath`: **measure it from a real `.raw`**
  (the only route that yields a descriptor known to resolve), **copy the shape
  from whichever of the three shipped PDKs the user says theirs resembles** (the
  user's own request — output marked UNVERIFIED, because resembling is not being),
  or **ask outright**;
* a **validation pass** when a raw is supplied, asserting the resolved vector
  actually exists in the file, per registered type;
* generated output carrying the default six `params` (**RULING D9**) and the
  mandatory guard, with a header recording which route produced the `devpath` and
  whether it was validated.

## 6. What is NOT in scope, and why

* **Letting a user choose a different parameter set.** All three shipped PDK files
  carry the same standing note — *"A first-class means for a user to choose her
  own set is OWED and TBD."* Still owed, separate item.
* **Non-MOS devices.** IHP's `vertical_npn` has its own proc and ruling D9's six
  are MOS quantities. v1 detects and reports non-MOS types, and declines them.
* **`Alt-6` and `Alt+Shift+6`.** Neither uses a descriptor; both read the raw
  directly. Only the device-OP block is PDK-dependent.

## 7. A cheaper partial fix, if the script is deferred

Two of the four traps cost minutes and would help even with no script:

1. **Say something when nothing is registered.** When `6` is pressed and every
   instance on the sheet resolves to an empty descriptor, the sentence should say
   so — *"No device operating-point descriptors are registered for this PDK, so
   there is nothing to show on these devices."* Today the user gets an empty block
   and no explanation. Note this is a wording change on the annotation surface and
   is subject to the user's PLAIN ENGLISH ruling.
2. **Document `op_annot::register` where a user reads.** One section in
   `README.md` with the gf180 block quoted verbatim as the minimal example.

Neither substitutes for the script; both remove the silence.

## 8. Acceptance

Per the spec §6 — reproduce sky130's and gf180's shipped descriptors from their
own directories; mark output unverified when no raw is supplied; report rather
than hide a `devpath` that resolves to nothing; and the end-to-end check, which is
that the generated block pasted into an rc produces a populated six-row block on
that PDK's own bench.
