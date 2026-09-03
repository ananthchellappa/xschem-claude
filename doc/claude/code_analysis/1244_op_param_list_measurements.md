# Measurements behind `doc/claude/specs/op_param_lists.md`

Taken 2026-09-02 at `9ef4a37e` on branch `fluid-editing`, against the user's own
bandgap (`~/.xschem/simulations/tb_bandgap_ase.spice`, sky130A, 78 MOS devices)
and the three PDK trees in this repo. Every number below was produced by a command
run in this session, not inferred.


## 1. The user's deck saves six MOS parameters and nothing else
`~/.xschem/simulations/tb_bandgap_ase.spice`: 468 `@m.…[…]` saves, over exactly
`{gds gm id vds vgs vth}`. Zero `@r.`, `@c.`, `@q.` saves. So TODAY the raw
cannot answer "all available parameters" for anything, and cannot answer
anything at all for R/C/Q.

## 2. `show <exact-device> : all` is complete
88 parameters for a sky130 BSIM4 nfet_01v8_lvt:
  l w m nf sa sb sd sca scb scc sc min ad as pd ps nrd nrs off rbdb rbsb rbpb
  rbps rbpd delvto mulu0 xgw ngcon trnqsmod acnqsmod rbodymod rgatemod geomod
  rgeomod gmbs gm gds vdsat vth id ibd ibs gbd gbs isub igidl igisl igs igd igb
  igcs igcd vbs vgs vds cgg cgs cgd cbg cbd cbs cdg cdd cds csg csd css cgb cdb
  csb cbb capbd capbs qg qb qd qs qinv qdef gcrg gtau vgsteff vdseff cgso cgdo
  cgbo weff leff
Note it mixes INSTANCE parameters (l, w, m, nf, ad, as…) with OP RESULTS
(gm, gds, id, vth…) with MODEL SWITCHES (trnqsmod, geomod…). No longest name
exceeds 11 chars for this model.

## 3. `show` output is TRUNCATED, and the width is not settable
- parameter-name column: 11 chars. `sourceconductance` prints as `sourcecondu`.
- device-path value: 20 chars. `m.xm2.msky130_fd_pr__nfet_01v8_lvt` prints as
  `m.xm2.msky130_fd_pr__`.
- `set width=300` does NOT widen either. Truncation is hard-coded.
- ASYMMETRY: the truncation is DISPLAY-ONLY. `show m : gm id sourceconductance`
  accepts the full name and returns its value. So a long name can be USED once
  known, but can never be LEARNED from `show`.
CONSEQUENCE: a class-wildcard `show m : all` cannot be parsed on a real design —
the device row is the only thing identifying the column and it is truncated at 20.
Per-device `show <exact path> : all` is safe, because the caller already knows
which device it asked about.

## 4. Multiple devices come back as COLUMNS, not blocks
`show r : all` on a deck with two resistors emits one name column and one value
column PER DEVICE, side by side. 468 MOS would be 468 columns.

## 5. `save @dev[all]` is accepted and yields an EMPTY vector
`display` after it shows `@m.…[all]: voltage, real, 0 long`. There is no
save-everything wildcard. To get all 88 into the raw you must name all 88.

## 6. Feasibility of saving everything (the important number)
468 MOS x 88 params = 41,184 vectors. In an OPERATING POINT plot that is one
double each = ~330 KB of data plus ~1.8 MB of names. Entirely practical.
(The user's current 69 MB raw is 69 MB because of the TRANSIENT, not the op.)

## 7. `show` and `print` both reach into subcircuits
`show m.x1.xm2.m1 : all` and `print @m.x1.xm2.m1[gm]` both work at depth.
`print` emits exactly `@m.x1.xm2.m1[gm] = 4.000000e-04` — the `expr = number`
shape `ase::backend::ngspice::result_probe` already parses (issue 1243).

## 8. ONE SCHEMATIC INSTANCE IS NOT ONE SPICE PRIMITIVE
This is the sharpest finding. In sky130A every device is an X-subcircuit:
  XM2  sky130_fd_pr__nfet_01v8_lvt -> m.x1.x1.xm2.msky130_fd_pr__nfet_01v8_lvt
       ONE m device.                                          [1:1, fine]
  XC1  sky130_fd_pr__cap_mim_m3_2  -> c.xc1.c1
       ONE c device.                                          [1:1, fine]
  XR1  sky130_fd_pr__res_xhigh_po_1p41
       -> r.xr1.x0.rend1, r.xr1.x0.rend2       (TWO resistors)
       -> c.xr1.x0.xc0.c0, c.xr1.x0.xc1.c0     (TWO capacitors)
       FOUR primitives, of two different classes, for ONE schematic symbol.
Their model is a LOCAL name, `xr1.x0:reshead`, not the PDK cell name.
So "the OP info for this instance" is one-to-many for R, and the spec must rule
what a single click prints.

# ---------------------------------------------------------------------------
# What the SYMBOLS say (measured 2026-09-02, three PDK trees in this repo)
# ---------------------------------------------------------------------------

## 9. Parameter text already sits on its own layer -- in every real PDK
Text records, by layer, for the primitives the user's bandgap actually uses:

  sky130 nfet_01v8_lvt : @name (default) | S D B G (7) | @model (default)
                         @mult x @W / @L (13) | LVT (13) | nf=@nf (13)
                         id=... (17) | gm=... (15) | vgs=expr(...) (default)
  sky130 cap_mim_m3_2  : m=@MF (13), @W / @L (13), computed C (13)
  sky130 res_xhigh_po  : @mult * 1.41 / @L (13), computed R (13)
  gf180  ppolyf_u_1k   : @m * @W / @L (13)
  ihp    sg13_lv_nmos  : m=@m (13) ng=@ng (13) l=@l (13) w=@w (13)

So across sky130A, gf180mcuD and ihp-sg13g2 the convention is identical:
  layer 13 = the instance PARAMETERS,  layer 7 = pin labels,
  default layer = @name and @model,    layers 15/17 = OP annotations.

## 10. ...but xschem's OWN generic devices use layer 13 for something ELSE
  xschem_library/devices/nmos4.sym : @w/@l/@m and @spiceprefix@name on the
      DEFAULT layer; layer 15 = net names; layer 17 = @spice_get_current.
  xschem_library/devices/{res,capa}.sym : layer 13 = @#N:pinnumber,
      @name / @value / m=@m on the DEFAULT layer.
So "hide layer 13" hides PARAMETERS on any PDK device and PIN NUMBERS on a stock
xschem device. The layer number is a PDK convention, not an xschem rule.
(72 of 724 sky130 symbols carry layer=13 text.)

## 11. The classification key already exists: the symbol K-record `type=` token
  sky130 nfet_01v8_lvt      type=nmos
  sky130 pfet_01v8          type=pmos
  sky130 cap_mim_m3_2       type=capacitor
  sky130 res_xhigh_po_1p41  type=high_precision_poly_p
Census of type= across the three PDK trees:
  sky130 : primitive 436, subcircuit 89, nmos 26, pmos 17, poly_resistor 7,
           high_precision_poly_resistor 6, high_precision_poly_p 4
  gf180  : subcircuit 58, res 15, moscap 13, nmos 10, pmos 9, diode 9,
           vertical_npn 6, vertical_pnp 4
  ihp    : subcircuit 89, primitive 75, diode 8, vertical_npn 6, res 5,
           pmos 4, nmos 4, capacitor 4
TWO PROBLEMS FOR "BROAD PRIMITIVE CLASS":
 (a) nmos and pmos are SEPARATE tokens. Nothing in the tree maps them both to
     "MOS". That is precisely the user's question, and it has no answer today.
 (b) the vocabulary is per-PDK and ragged: a resistor is `res` on gf180 and ihp
     but `poly_resistor` / `high_precision_poly_resistor` /
     `high_precision_poly_p` on sky130.

## 12. op_annot ALREADY HAS the registry both features need
  op_annot::register <symbol-type> <dict>   -- store/override a descriptor
  op_annot::descriptor <symbol-type>        -- read it back
  op_annot::type <instname>                 -- the symbol's type= token
Descriptor keys: devpath | devproc | params | derived | pinexpr | match.
  `params` is an ORDERED list of {label param kind} triples -- THE ANNOTATION
  LIST, exactly what feature (B) key 1 edits and reorders.
  `match` is a glob list over the instance's CELL NAME
  (e.g. {*sky130_fd_pr/*}) -- THE DEVICE-FLAVOR NARROWING, exactly what the
  broad/narrow dialog needs.
So the two-level scheme the user described (MOS class vs nfet_01v8_lvt flavor)
maps onto (type= token) x (match glob). Nothing new has to be invented.

## 13. Today's annotation list is RULING D9, and only for FETs
sky130A/sky130_procs.tcl:398 registers descriptors for `nmos` and `pmos` ONLY:
    params {{id id 0} {gm gm 1} {gds gds 1} {vgs vgs 2} {vth vth 2} {vds vds 2}}
"THE DEFAULT SIX -- RULING D9 (the user, 2026-08-22) ... and nothing else, on
every PDK. Too many parameters displayed is just clutter."
No descriptor is registered for capacitor, resistor or bipolar -- which is why
the deck saves `@m.` and nothing else (finding 1).
AND, at sky130_procs.tcl:405, in the shipped comment:
    "A first-class means for a user to choose her own set is OWED and TBD."
Feature (B)'s list editor is that owed thing.

# ---------------------------------------------------------------------------
# The keys and the draw-time socket (measured 2026-09-02, this tree)
# ---------------------------------------------------------------------------

## 14. Ctrl-Alt-6 IS NOT FREE TODAY -- it fires Alt-6
src/cadence_style_rc:323-325 binds
    <Key-6>          cadence::annot_mode op        (annot_show |= 1)
    <Control-Key-6>  cadence::annot_mode none      (annot_show  = 0)
    <Alt-Key-6>      cadence::annot_mode opvolt    (annot_show |= 2)
Tk matches a pattern whose modifiers are a SUBSET of the event's, and the spec
records this measured: "Ctrl+Alt+6 falls into the Alt form." So pressing
Ctrl-Alt-6 today turns node voltages ON. Feature (A) must bind
<Control-Alt-Key-6> EXPLICITLY, with a trailing `break`, or it both declutters
and switches on node voltages.
Also note 6 / Alt-6 are ADDITIVE SETTERS, not toggles (RULING 0614): 6 never
turns anything off, Ctrl-6 is the only off switch. The user asked for
Ctrl-Alt-6 to "hide/show", i.e. a TOGGLE -- deliberately unlike its neighbours.

## 15. BARE 1 2 3 4 ARE TAKEN, by a shipped editing action
src/callback.c:7434-7448. With no modifier, keys 0-4 call logic_set() --
"toggle pin logic level". Key 5 toggles xctx->only_probes. With ControlMask the
same keys choose the drawing layer.
src/cadence_style_rc binds NO bare digit, so in the cadence profile bare 1-4
still reach logic_set. Feature (B) wanting bare 1/2/3/4 therefore DISPLACES a
real feature; whether that is acceptable is the user's call.
src/keybindings.csv has exactly one digit row: key,50,alt,canvas,
view.toggle_view_type (Alt-2).

## 16. The draw-time socket for feature (A) already exists and is a ONE-LINER
S7 (2026-08-19) collapsed ten copy-pasted visibility tests into
    int text_hidden(int flags, int ctx)
with TEXT_CTX_INSTANCE / TEXT_CTX_SCHEMATIC. Bits (src/xschem.h:387-398):
    HIDE_TEXT 8 | HIDE_TEXT_INSTANTIATED 32 | HIDE_TEXT_OP 64 |
    HIDE_TEXT_VOLTAGE 128        (256 is free)
Mask (src/xschem.h:431-454):
    ANNOT_SHOW_OP 1 | ANNOT_SHOW_VOLTAGE 2 | ANNOT_SHOW_TRAN 4  (8 is free)
`flags` is a plain int, NEVER SERIALISED (always recomputed by set_text_flags),
so a new bit costs no file-format change. This is the single place feature (A)
has to touch to hide text at draw time -- no object mutation, no undo entry, no
dirty file.
⚠ but the OP ANNOTATION ITSELF is not symbol text any more: carrier 2 is a
draw-time OVERLAY painted by draw() / svgdraw.c / psprint.c and gated by
get_annot_overlay() on ANNOT_SHOW_OP. So hiding parameter text cannot
accidentally hide the annotation, and vice versa. Two separate paths.

## 17. There is ALREADY a content-based text classifier to copy
set_text_flags() (src/actions.c) carries annot_content_class() +
annot_class_free(): a text is implicitly classed VOLTAGE or CURRENT from its own
CONTENT (@spice_get_voltage / @spice_get_current), and only when the explicit
`hide=` chain set no bit at all. So "classify a text without editing 72 PDK
symbols" is an established pattern here, not an invention.

## 18. `show` was already weighed and deferred -- and key 3 is the deferred step
op_annotation.md 3.1 (R5, issue 0620, decided 2026-08-22) compares save cards
(chosen) against a bare `show`, and ends: "B is recorded as a named
operating-point-only fast path for a later step ... A future step may add it as
an `op`-only accelerator BESIDE A, never instead of it."
Its stated blockers were: (1) invariant I1 -- `show` publishes `von` where the
save card publishes `vth`, so B needs a second name builder; (2) `show` has no
timepoints; (3) `show` never reaches the raw.
For a READ-ONLY text dump (key 3) none of the three bites. They bite again the
moment key 3's "Add" promotes a show-spelled name into the annotation list --
that is exactly I1's drift. NOTE my own census: BSIM4 (sky130) publishes `vth`
AND `vdsat` and no `von`, so the von/vth mismatch is level-1 specific, but the
principle stands.

## 19. A PER-CLICK RE-RUN IS OUT: 16.3 s for an op-only solve
The user's own bandgap (tb_bandgap_ase.spice, 468 MOS), .control reduced to a
bare `op` plus one `show`, measured with /usr/bin/time:
    elapsed 16.27 s
So "click a device, re-run ngspice to `show` it" costs 16 s per click on a
MEDIUM design and worse on a real block. Key 3 must be served from data the run
the user already ran left behind, or from a live ngspice session (which ASE-L
does not keep -- it runs `ngspice -b`).
That same run's `show <one device> : all` was 104 lines / 88 parameter rows --
i.e. asking ONE representative device per MODEL is ~10 x 88 = ~880 lines, free.

## 20. The resulting shape (a design, for the user to rule on)
Learn once, save thereafter:
  run N   : emit `show <one representative device per distinct model> : all`.
            Cheap. Gives the exact parameter-name list per model.
            Cache it per model in the settings file.
  run N+1 : emit save cards for every cached name x every device, so all 88
            land in the RAW. Key 3 then reads the same channel annotation
            reads -- invariant I1 intact, no second name builder, and a name
            promoted by "Add" is already a name a save card can use.
Cost check from finding 6: 468 x 88 = 41,184 op-point vectors ~ 330 KB of data
plus ~1.8 MB of names. Practical.
The price: key 3 is COMPLETE only from the second run onward. The alternative is
shipping a curated per-model catalogue and never learning -- exact names, no
warm-up, but a new PDK model needs a tool edit.

## 21. SAVING EVERYTHING IS ESSENTIALLY FREE -- measured on the real design
Correction to finding 1's arithmetic: the 468 `@m.…` occurrences are 78 DISTINCT
DEVICES x 6 parameters, not 468 devices.
Test: the user's own bandgap, .control replaced with 78 devices x 20 parameters
= 1560 save cards, then `op`, then `write`.
    elapsed          17.52 s   (against 16.27 s for the bare op -- +1.2 s)
    No. Variables:   1983
    No. Points:      1
    raw file          131,442 bytes
Extrapolated to the full BSIM4 set (88 params x 78 devices = 6,864 cards):
~7,300 vectors, ~500 KB. Trivial.
CONCLUSION: there is no cost argument against putting every available device
parameter in the operating-point raw. The only real constraint is R5 -- a card
naming a device the deck does not contain yields a dims=0 column of zeros, and
an ALL-bogus card set suppresses the raw entirely. So the catalogue must be
per-model and correct, not a union sprayed at every device.

## 22. `show`'s catalogue is a SUPERSET of the savable set -- measured
Of the 20 parameters saved in finding 21, all 20 appear in the raw header, but
78 columns (exactly one per device) come back `dims=0`:
    9   i(@m.x1.x1.x1.xm1.msky130_fd_pr__nfet_01v8[ib])   current dims=0
    29  i(@m.x1.x1.x1.xm2.msky130_fd_pr__pfet_01v8[ib])   current dims=0
The offender is `ib`, and it is `ib` for every one of the 78 devices.
`ib` IS in `show <dev> : all`'s 88-name list for sky130 BSIM4. It is not
savable. ngspice printed NO warning (stderr warning count: 0).
CONSEQUENCE, and it is the load-bearing constraint on the whole "all
parameters" design: a catalogue learned from `show` cannot be trusted as a save
list. The failure is silent -- a full column of zeros, marked `dims=0` in the
header, no message anywhere. This is R5's own residual, reproduced here on a
parameter rather than on a device.
THE SELF-CORRECTING SHAPE THIS ARGUES FOR: save the whole `show` catalogue once,
then PRUNE by measurement -- drop every name that came back dims=0 and cache the
survivors per model. The catalogue then converges on the savable set after one
run and never lies again. `dims=0` -- not stderr -- is the only detector.

## 22a. ⚠ CORRECTION, 2026-09-02 (issue 1263, found by item A6's adversary pass)
**THE SENTENCE ABOVE IS TRUE OF ONE NGSPICE WRITER AND FALSE OF THE ONE XSCHEM
ACTUALLY USES.** Finding 22 was measured with the `.control` + `write` idiom,
which does emit the `dims=0` token. But xschem's own shipped simulate command is

    src/xschem.tcl:3854   set_ne sim(spice,2,cmd) {ngspice -b -r "$n.raw" "$N"}

and the batch `-r` writer publishes an unsatisfiable save card as a **plain zero
column with no `dims=0` token at all** -- re-measured 2026-09-02 on ngspice 45.2,
BSIM4 `level=14 version=4.8.1`, with `.options savecurrents`: the `Variables:`
block lists `i(@m1[is])`, `i(@m1[ig])`, `i(@m1[ib])` as ordinary `current`
columns, and `grep -ac 'dims=' <raw>` is **0**.

So through xschem's own simulate path there is **NO WAY TO DISTINGUISH "the
simulator could not compute this" FROM "the simulator computed 0.0"**. Not by
`dims=`, not by vector length, not by stderr. Any design that needs that
distinction must either change how xschem invokes ngspice, or accept that on the
shipped path the two are the same value.

Also measured while establishing this (issue **1264**): a **zero-length** vector
makes ngspice `write` refuse the **whole plot** and produce no raw at all -- so
the zero-length case from finding 3 cannot even reach a reader.

Findings 21 and 22's arithmetic stands. It is the DETECTOR that was
writer-specific, and this file asserted it without naming the writer.

⚠ **CORRECTED 2026-09-02 by item A6, re-measured against ngspice 45.2 on
throwaway BSIM4 decks. THE SENTENCE ABOVE IS TRUE OF THIS `.control`+`write`
RUN AND FALSE AS A GENERAL CLAIM, and the difference matters because the writer
xschem itself calls is the other one.** Run through the shipped simulate
command -- `ngspice -b -r "$n.raw" "$N"`, `src/xschem.tcl:3854` -- the SAME
unsatisfiable save card comes back as an **ordinary `current` column of 0.0 with
no `dims=0` token anywhere in the file**:

    Variables:
            4       i(@m1[id])      current
            5       i(@m1[is])      current
            6       i(@m1[ig])      current
            7       i(@m1[ib])      current
    $ grep -ac 'dims=' sc.raw
    0
    $ head -3 sc.err
    Warning: unrecognized variable - @m1[is]
    Warning: unrecognized variable - @m1[ig]
    Warning: unrecognized variable - @m1[ib]

and read back through xschem: `i(@m1[id])` = 3.12e-4, `is`/`ig`/`ib` = 0,
indistinguishable from a transistor that is off. **So on that path the detector
is stderr and nothing else** -- the exact inverse of the sentence above -- and
xschem never reads stderr. Also measured: a genuinely zero-LENGTH vector makes
`write` refuse the WHOLE plot (`Error during 'write': no writable vector
found`), producing no raw at all and in one form segfaulting; the finding-21
claim that these flavours are silent is wrong for that one too.

CONSEQUENCE FOR THE "SELF-CORRECTING SHAPE" ABOVE: probe-and-prune was already
rejected by ruling **D-5**; this measurement makes the rejection
over-determined, because the token it would prune on is absent on the path the
tool uses. Item A6-b closes the `dims=0` flavour only, behind
`raw_vector_absent()`. Issues **1263** (the `-r` writer) and **1264** (the
zero-length flavour).
