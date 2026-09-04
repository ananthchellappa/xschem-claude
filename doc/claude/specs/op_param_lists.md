# Spec — the OP parameter lists: schematic declutter (`Ctrl-Alt-6`) and the Results Display Window

Branch `fluid-editing`. Drafted 2026-09-02 from the user's request of the same
day. **Nothing in section 4 is ratified**; section 5.1 is the list of questions
this spec owes the user, and no crew may start an item whose ruling is still
open there.

Two features, one spec, because they are the same object seen twice: a
**per-primitive-class, user-owned, ordered list of operating-point parameters**.
Feature A decides what the schematic stops drawing so that list is legible;
feature B is where the user reads, reorders and edits it.

---

## 0. Rulings so far (the user, 2026-09-02)

* **D-1 — "everything other than the name" means EVERYTHING.** Not just the
  sizing. *"even pin labels can be hidden when user is hiding other things that
  are not @name. We are only interested in name and annotation of OP info."*
  So the rule is not a parameter classifier at all: while decluttering, an
  instance draws **its name and its OP annotation, and nothing else**. This is
  simpler *and* more exact than any of the three candidate rules §4.1 offered,
  and it retires question Q2.
* **D-2 — the RDW takes bare `1`/`2`/`3`/`4` in the cadence profile only.**
  Stock xschem keeps "toggle pin logic level". ⚠ Note what that costs a cadence
  user: `logic_set` has **no menu entry and no second accelerator**, so within
  that profile the keys are its only door. `xschem logic_set n` remains
  scriptable.
* **D-3 — a multi-primitive instance prints all of its primitives** *"if data is
  available from the simulator and easy to find."* Measured, it is both: see
  §3.6 — `.options savecurrents` enumerates every sub-primitive at every depth
  by itself, with no cards and no hierarchy walk of our own.
* **D-4 — no guessing about what the simulator publishes.** *"This will be
  supported only for the case of the simulator accepting the wildcard OP info
  save. We should not guess what parameters are available."* The learn-and-prune
  design this spec first proposed is **withdrawn**. §3.6 is the measurement.
* **D-5 — THE SIMULATOR IS A MOVING TARGET, AND THAT IS THE DESIGN.**
  *"The simulator is not ready yet. I am doing a custom ngspice that will support
  wildcard OP info save for all devices. Till then, we will go with this 'dumb'
  approach."*
  So key 3 is built behind a **backend capability seam**, not around ngspice-45's
  limits. Today's implementation is the dumb one — **key 3 lists exactly what
  this run's raw actually holds for that device** (§4.2 B5-c): no cards we did
  not already emit, no `show`, no inference, nothing that can lie. When the
  custom ngspice lands, the wildcard becomes a second implementation behind the
  same seam and key 3 becomes complete **without the window, the lists, the
  dialogs or the settings file changing at all**. Nothing in feature B may encode
  "ngspice cannot enumerate parameters" as structure.
* **D-6 — the declutter reaches exactly the instances that got OP numbers.**
  A hierarchical block keeps its cell name and its pin labels; a device with no
  descriptor is untouched. The gate is the one carrier 2 already computes.
* **D-7 — the lists seed from the PDK, and the user's file wins.** The PDK's
  `op_annot::register` calls remain the defaults; the settings file overrides per
  class. Nothing has to be checked in until something is changed.
* **D-8 — the declutter exists only while OP info is displayed.** *"Declutter is
  active ONLY when OP info (6 key triggered) is displayed. I thought that was
  clear."* It was, and it is now a bit on `annot_show` — inert unless bit0 is
  set, and cleared by `Ctrl-6` with everything else. No separate persisted
  preference. ⚠ One consequence to look at on screen rather than argue about:
  after `6` → `Ctrl-Alt-6` → `Ctrl-6` → `6`, the parameters are back and
  `Ctrl-Alt-6` must be pressed again.

---

## 1. The problem

**A. The annotation and the parameters fight for the same pixels.** With `6`
pressed, every FET on the sheet grows a six-row block of numbers next to it. The
symbol is *already* printing `@mult x @W / @L`, `nf=@nf` and `@model` in that
same space. On a dense sheet the two overlap and neither is readable. The user
wants one chord that says *"while I am reading operating points, stop drawing
the sizing"* — and, crucially, wants the sizing back the instant annotation is
off, with no state to remember and nothing saved into the `.sch`.

**B. There is no way to ask "what else does this device know?"** The annotation
shows six numbers because `sky130_procs.tcl` says six. sky130's own comment, at
`sky130A/sky130_procs.tcl:405`, has said so since 2026-08-22:

> A first-class means for a user to choose her own set is OWED and TBD.

Cadence answers this with **ADE-L > Results > Print**: click a device, get its
operating point as text you can select, copy, and paste into a review document.
The user wants that, and wants it to go further — the printed dump is also
where you *edit* what gets printed and what gets annotated, so the thing you are
looking at is the thing you change.

---

## 2. What exists, precisely

Everything in this section was read or measured on 2026-09-02 at `9ef4a37e`.

### 2.1 The descriptor registry — the socket both features plug into

`src/op_annot.tcl` already carries the exact data structure both features need.

```
op_annot::register <symbol-type> <dict>    store or override a descriptor
op_annot::descriptor <symbol-type>         -> the dict, or {}
op_annot::type <instname>                  -> the symbol K-record `type=` token
op_annot::devpath <instname> ?basis? ?root?
op_annot::vector <instname> <param> ?kind?
op_annot::text <instname>                  -> the `label = value` block
```

Descriptor keys: `devpath` · `devproc` · `params` · `derived` · `pinexpr` ·
`match`.

* **`params` is an ordered list of `{label param kind}` triples.** It *is* the
  annotation list. `label` is what the display prints, `param` is the raw-file
  parameter name, `kind` is the `i()`/`v()`/bare wrapper. IHP already exploits
  the label/param split: `{id ids 0}` — the user sees `id`, ngspice is asked for
  `ids`. Any user-facing list editor gets that separation for free.
* **`match` is a list of globs over the instance's cell name**, e.g.
  `{*sky130_fd_pr/*}`. It exists because `type=nmos` is shared by sky130, gf180,
  IHP *and* `xschem_library/devices/nmos.sym` (issue 0425). It is therefore
  already the **device-flavor narrowing** the user's broad/narrow dialog needs.

So the user's two-level scheme — "only `nfet_01v8_lvt`, or all MOS" — maps onto
`(type= token) x (match glob)`. **Nothing new has to be invented for the store.**

### 2.2 What is actually registered today

| PDK | types registered | `params` |
|---|---|---|
| sky130 | `nmos`, `pmos` | `{id id 0} {gm gm 1} {gds gds 1} {vgs vgs 2} {vth vth 2} {vds vds 2}` |
| gf180mcu | `nmos`, `pmos` | the same six |
| IHP sg13g2 | `nmos`, `pmos` | the same six, but `{id ids 0}` |
| IHP sg13g2 | `vertical_npn` | `{ic ic 0} {ib ib 0} {gm gm 1} {go go 1} {vbe vbe 2} {vbc vbc 2}` |

**No PDK registers a capacitor, a resistor or a diode.** That is why the user's
deck saves `@m.…` and nothing else, and why clicking a mim cap today can only
ever produce a refusal.

The six are **RULING D9 (the user, 2026-08-22)**, recorded in
`op_annotation.md` §4.2a: *"id gm gds vgs vth vds and nothing else, on every PDK.
Too many parameters displayed is just clutter."* Feature A exists because the
same sentence applies to the *symbol's* text, which D9 could not reach.

### 2.3 The visibility machinery

S7 (2026-08-19) collapsed ten copy-pasted visibility tests into one predicate:

```c
int text_hidden(int flags, int ctx)      /* TEXT_CTX_INSTANCE | TEXT_CTX_SCHEMATIC */
```

> ⚠ **SUPERSEDED IN SHAPE BY ITEM A3, 2026-09-02** — one core, two entry points:
>
> ```c
> static int text_hidden_core(int flags, int ctx, int n);  /* the five arms + the rung */
> int text_hidden(int flags, int ctx);        /* delegate, n = -1: the 5 schematic sites
>                                                and get_annot_overlay()'s probe */
> int text_hidden_inst(int flags, int n);     /* the 6 instance sites; n is the instance */
> ```
>
> **A new instance-context call site must use `text_hidden_inst()`.** The plan's
> `TEXT_CTX_INSTANCE_ANNOTATED` was rejected — see §4.1 A3a.

Bits (`src/xschem.h:387-424`): `HIDE_TEXT 8`, `HIDE_TEXT_INSTANTIATED 32`,
`HIDE_TEXT_OP 64`, `HIDE_TEXT_VOLTAGE 128`, plus the two **content-derived**
classes `TEXT_ANNOT_VOLTAGE 256` and `TEXT_ANNOT_CURRENT 512` — **1024 is free**.
Mask (`src/xschem.h:432-454`): `ANNOT_SHOW_OP 1`, `ANNOT_SHOW_VOLTAGE 2`,
`ANNOT_SHOW_TRAN 4` — **8 is free**.

⚠ **There are ELEVEN `text_hidden()` call sites, not ten**, and the eleventh is
the one that matters: `src/actions.c:1832`, inside `get_annot_overlay()`, called
with a **synthetic literal** `text_hidden(HIDE_TEXT_OP, TEXT_CTX_INSTANCE)`
rather than a real text's flags — it is asking "would an OP text be visible right
now?" as a proxy for "should the overlay paint?". Any new rung added to
`text_hidden` is therefore also answering *that* question, and must not change
its answer.

⚠ **THE `actions.c` NUMBERS IN THIS SECTION WERE STALE AND ARE CORRECTED HERE**
(item A3, 2026-09-02). Item A2's `dcbb85c3` inserted 69 lines above them, so
"`actions.c:1832`" above and "`actions.c:6324`" below both read +69 low; item A3
moved them again. The census as of item A3's commit — **re-derive with grep, do
not trust a number in a document**:

| site | line | ctx |
|---|---|---|
| `draw.c` `draw_symbol()` | **872** | instance (`text_hidden_inst`) |
| `draw.c` `draw_temp_symbol()` | **1143** | instance |
| `draw.c` `inst_text_bbox()` | **10310** | instance |
| `svgdraw.c` `svg_draw_symbol()` | **927** | instance |
| `psprint.c` `ps_draw_symbol()` | **1209** | instance |
| `select.c` `symbol_bbox()` | **709** | instance |
| `draw.c` `draw()` | **10691** | schematic |
| `svgdraw.c` | **1337** | schematic |
| `psprint.c` | **1713** | schematic |
| `actions.c` `calc_drawing_bbox()` | **6590** | schematic |
| `actions.c` `get_annot_overlay()` | **2098** | **the synthetic literal** |

The safety of the eleventh is now **arithmetic, not etiquette**: `HIDE_TEXT_OP`
is 64 and the content-class-to-mask helper names only 256 and 512, so
`annot_class_mask(64, TEXT_CTX_INSTANCE)` is 0 and the probe returns at the
`HIDE_TEXT_OP` arm — *above* the rung — and it passes `n = -1`, which the rung's
`n >= 0` term rejects independently. Unreachable twice over.

⚠⚠ **SYMBOL TEXTS ARE SHARED BY EVERY INSTANCE OF A SYMBOL.** `draw_symbol()`
walks `symptr->text[j]` — the **symbol's** array, not the instance's. So a
per-instance answer cannot live in `xText.flags` at all, and **feature A is
inherently whole-sheet** unless a per-instance property or side table is added.
This was not obvious and it is the biggest single constraint on feature A's
shape.

`flags` is a plain `int` that is **never serialised** (always recomputed by
`set_text_flags`), so a new bit costs no file-format change. This is the single
site feature A has to touch: no object mutation, no undo entry, no dirty file.

`set_text_flags()` (`src/actions.c:1289`) already carries
`annot_content_class()` (`:1239`) and `annot_class_free()` (`:1228`) — a text is
implicitly classed VOLTAGE or CURRENT **from its own content** (a whole-string
match, not a substring one), and only when the explicit `hide=` chain set no bit
at all.
Classifying a text without editing PDK symbols is therefore an established
pattern here, not an invention.

⚠ **The OP annotation itself is no longer symbol text.** Carrier 2 (§4.4 of
`op_annotation.md`, landed S9b) is a draw-time overlay painted by `draw()`,
`svgdraw.c` and `psprint.c`, gated by `get_annot_overlay()` on `ANNOT_SHOW_OP`.
So hiding parameter text cannot accidentally hide the annotation, and vice
versa. Two separate paths, and feature A only touches one.

### 2.4 The keys as they stand

`src/cadence_style_rc:323-325` — **one file, sourced by all three PDK workareas**:

```tcl
bind .drw <Key-6>         {cadence::annot_mode op;     break}   ;# annot_show |= 1
bind .drw <Control-Key-6> {cadence::annot_mode none;   break}   ;# annot_show  = 0
bind .drw <Alt-Key-6>     {cadence::annot_mode opvolt; break}   ;# annot_show |= 2
```

RULING 0614: these are **two additive setters and one clear-all**. `6` never
turns anything off and is not a toggle; `Ctrl-6` is the only off switch.

### 2.5 Command mode already exists, and so does the read-only pick

* **`xschem instance_at <x> <y>`** (`scheduler.c:6919`) returns the instance name
  under a point. Its own comment: *"READ-ONLY: it selects nothing and changes
  nothing — this is the probe half of the verb-noun descend pick, and the
  deliberate opposite of `select_at`, which is the mutating coordinate pick."*
  This is exactly feature B's verb-noun requirement, already shipped.
* **A canvas command mode is an established concept.** `src/cmdmode.tcl`:
  *"a Tcl-level seize of the design canvas' gesture slots: ASE Direct Plot
  (`Ctrl-4`) rebinds `<ButtonPress-1>`/`<ButtonRelease-1>`/`<Key-Escape>` so every
  click queues a trace."* `cmdmode::register <key> <suspend_cb> <resume_cb>` is
  the participation contract, so a descend mid-command can pause and resume the
  mode. Feature B's 1/2/3 mode is the same shape and must register too.

### 2.6 Namespace already taken

`src/results.tcl` owns `results::` for **`Results > Select`** — choosing which
`.raw` is active. It is not this feature and must not be collided with.

---

## 3. The measured constraints

Measured 2026-09-02 against the user's own bandgap and sky130A.
Full transcript: `doc/claude/code_analysis/1244_op_param_list_measurements.md`.

### 3.1 One schematic instance is **not** one SPICE primitive

In sky130A every device is an X-subcircuit:

| symbol instance | SPICE primitives it becomes |
|---|---|
| `XM2 … nfet_01v8_lvt` | `m.x1.x1.xm2.msky130_fd_pr__nfet_01v8_lvt` — **one** |
| `XC1 … cap_mim_m3_2` | `c.xc1.c1` — **one** |
| `XR1 … res_xhigh_po_1p41` | `r.xr1.x0.rend1`, `r.xr1.x0.rend2`, `c.xr1.x0.xc0.c0`, `c.xr1.x0.xc1.c0` — **four, of two classes** |

Their model is a *local* name (`xr1.x0:reshead`), not the PDK cell name. So "the
OP info for this instance" is one-to-many for resistors, and the spec must rule
what a single click prints. **This is question Q7.**

### 3.2 `show` is complete, truncated, and a **superset** of the savable set

`show <exact-device> : all` returns 88 parameters for a sky130 BSIM4 FET —
instance parameters (`l w m nf ad as`), OP results (`gm gds id vth vdsat`) and
model switches (`trnqsmod geomod`) mixed together.

* The parameter-name column is **11 characters** and the device-path field is
  **20**. `sourceconductance` prints as `sourcecondu`;
  `m.xm2.msky130_fd_pr__nfet_01v8_lvt` prints as `m.xm2.msky130_fd_pr__`.
  **`set width=300` does not move either.** Truncation is hard-coded.
* The truncation is **display-only**: `show m : gm id sourceconductance` accepts
  the full name and returns its value. A long name can be *used* once known and
  can never be *learned* from `show`.
* Consequently a class-wildcard `show m : all` **cannot be parsed on a real
  design** — the only column identifier is the truncated device row, and
  multiple devices come back as side-by-side columns, not blocks. Per-device
  `show <exact path> : all` is safe, because the caller already knows what it
  asked about.
* **`save @dev[all]` is accepted and yields an empty vector.** There is no
  save-everything wildcard; all 88 names must be spelled out.
* ⚠ **And the catalogue lies.** Saving 20 named parameters across all 78 devices
  of the user's bandgap put all 20 in the raw — and **78 columns came back
  `dims=0`, exactly one per device, every one of them `ib`**. `ib` is in
  `show`'s 88-name list for sky130 BSIM4 and is **not savable**. ngspice printed
  no warning at all. `dims=0` in the raw header is the only detector, which is
  R5's own residual (`op_annotation.md` §3.1) reproduced on a parameter rather
  than on a device.

### 3.3 Saving everything is free. Re-running is not.

| measurement | result |
|---|---|
| the user's bandgap, `op` only | **16.27 s** |
| the same, plus 1560 save cards (78 devices × 20 params) | **17.52 s**, raw **131 KB**, 1983 vectors, 1 point |
| extrapolated to the full 88-parameter set (6864 cards) | ~7300 vectors, ~500 KB |
| `show <one device> : all` | 104 lines, 88 rows |

So **there is no cost argument against putting every available device parameter
into the operating-point raw** — it costs 1.2 s and half a megabyte. And a
per-click re-run is out: 16 s per click on a *medium* design.

### 3.4 The classification vocabulary is ragged

The `type=` token census across the three PDK trees in this repo:

| PDK | tokens seen |
|---|---|
| sky130 | `primitive` 436, `subcircuit` 89, `nmos` 26, `pmos` 17, `poly_resistor` 7, `high_precision_poly_resistor` 6, `high_precision_poly_p` 4, `capacitor` |
| gf180mcu | `subcircuit` 58, `res` 15, `moscap` 13, `nmos` 10, `pmos` 9, `diode` 9, `vertical_npn` 6, `vertical_pnp` 4 |
| IHP sg13g2 | `subcircuit` 89, `primitive` 75, `diode` 8, `vertical_npn` 6, `res` 5, `pmos` 4, `nmos` 4, `capacitor` 4 |

Two problems for "broad primitive class":

1. **`nmos` and `pmos` are separate tokens** and nothing maps them both to
   "MOS". This is the user's own question, and it has no answer in the tree
   today — the three PDK rc files each paper over it with
   `foreach t {nmos pmos} { op_annot::register $t … }`.
2. **The vocabulary is per-PDK and inconsistent**: a resistor is `res` on gf180
   and IHP but `poly_resistor` / `high_precision_poly_resistor` /
   `high_precision_poly_p` on sky130.

### 3.5 The parameter text already sits on its own layer — in every real PDK

| symbol | name | pins | parameters | annotation |
|---|---|---|---|---|
| sky130 `nfet_01v8_lvt` | `@name` default | 7 | **13** | 15 / 17 |
| sky130 `cap_mim_m3_2` | `@name` default | 7 | **13** | — |
| sky130 `res_xhigh_po_1p41` | `@name` default | 7 | **13** | — |
| gf180 `ppolyf_u_1k` | `@spiceprefix@name` default | 7 | **13** | — |
| IHP `sg13_lv_nmos` | `@name` default | 7 | **13** | — |

…but **`xschem_library/devices/*.sym` uses layer 13 for pin numbers** and puts
`@w\/@l\/@m`, `@value` and `m=@m` on the default layer. So a layer-13 rule
hides parameters on any PDK device and *pin numbers* on a stock xschem device.
**The layer number is a PDK convention, not an xschem rule.** This is question Q2.

### 3.6 What ngspice will and will not publish without being told — the D-4 gate

RULING D-4 says key 3 exists only where the simulator accepts a **wildcard OP
info save**. So: measured, ngspice-45.2, every form tried.

| form | result |
|---|---|
| no `save` cards at all | 5 vectors: node voltages and source branch currents. No device parameters. |
| `save all` | identical — 5 vectors. `all` does not mean device parameters. |
| `save @m.xm2.m1[all]` | **accepted, and yields an empty vector** (`0 long`). Silent. |
| `save @m*[*]` | no match; the op plot is destroyed |
| `save @m.xm2.m1[*]` | no match; the op plot is destroyed |
| `save @m.xm2.m1` (no bracket) | no match; the op plot is destroyed |
| `save m` | no match; **the whole op plot is destroyed** — R5's all-bogus case |
| `.options savepower` / `savevoltages` / `saveall` / `saveop` / `probe` | no effect; no such options |
| **`.options savecurrents`** | **THE ONE WILDCARD THAT WORKS** |

**`.options savecurrents`, measured on real sky130 devices, with no save cards
at all**, publishes for every device at every hierarchy depth:

```
@b.xr1.x0.brbody[i]   @c.xc1.c1[i]          @c.xr1.x0.xc0.c0[i]
@c.xr1.x0.xc1.c0[i]   @r.xr1.x0.rend1[i]    @r.xr1.x0.rend2[i]
@m.xm1.msky130_fd_pr__nfet_01v8_lvt[id]     …[ig]  …[is]  …[ib]
```

Three things follow, and they decide the design:

1. **ngspice has NO wildcard for the full OP parameter set.** Under D-4 as
   written, key 3's "all available parameters" is **not supportable on ngspice**.
2. **ngspice DOES have a wildcard for device CURRENTS**, and it is free — one
   `.options` line, no cards, no name building, nothing to guess.
3. **`savecurrents` also solves D-3 for free.** One `XR1` came back as *five*
   sub-primitives — two resistors, two capacitors **and a diode**
   (`b.xr1.x0.brbody`) nobody had noticed. The simulator enumerated the
   hierarchy itself; we do not have to walk it.

⚠ **And it is not uniformly populated.** Of the FET's four currents, `id` came
back `1 long` and `ig`, `is`, `ib` came back **`0 long`** — present in the
header, empty in the data, no warning. Same silent-empty class as the `dims=0`
columns in §3.2. Any reader must treat length 0 as *absent*, not as zero.

**The honest third option, and it is not guessing.** `show <exact device> : all`
is the simulator **enumerating its own parameters**, not us inferring them — it
is a different objection from the one D-4 raises. Its costs are known: it is a
text channel rather than the raw, it is operating-point only, and its display
columns truncate (11 chars for a parameter name, 20 for a device path), though
no sky130 BSIM4 parameter name is long enough to be affected. Whether that
counts as "the simulator accepting the request" is question **Q4**.

---

## 4. Design

### 4.1 Feature A — `Ctrl-Alt-6`, the parameter declutter

**A1. The bit.** A new mask bit `ANNOT_SHOW_NOPARAM 8` on `xctx->annot_show`,
mirrored in Tcl as `annot_show` like its neighbours, set and cleared through
`xschem set annot_show N` (never a bare `set ::annot_show` — the C field reads
stale, and the variable is an integer so `true`/`on` `atoi` to 0, silently off).

> **LANDED — item A1, 2026-09-02** (`src/xschem.h`, `utils/annot_mode.tcl`,
> `src/cadence_style_rc`, `tests/headless/test_annot_declutter_1244.tcl`, 36
> checks). Three things the implementation settled that this section did not say:
>
> * **The one writer is `cadence::annot_declutter {{mode toggle}}`**, appended at
>   the end of `utils/annot_mode.tcl`. It takes `toggle` | `on` | `off` and
>   **raises** on anything else, naming the three — the same discipline as
>   `cadence::_annot_mask`, which is deliberately **not** extended: `declutter`
>   still raises there, exactly as `tran` does, because that table is the
>   ADDITIVE-SETTER table and row N1 of `test_op_annot.tcl` golds it as such.
> * **It never refuses when `ANNOT_SHOW_OP` is clear.** Arming ahead of
>   annotation is legal and inert (invariant **I-C**), and the user is told so by
>   a sentence rather than by a refusal. The gate is A2's draw-time predicate,
>   AND-ed on both bits — not the writer.
> * **The status line is minted by a pure proc**, `cadence::_annot_declutter_msg
>   {on gated}`, three sentences, written to the **held status line only** and
>   never to the CIW (the declutter publishes nothing; `annot_tran` uses both
>   sinks *because* it does). ⚠ **The wording is UNRATIFIED** — `rule` debt 1244,
>   §5.1 below. ⚠ **Item A4 added a SECOND pure minter to this family**,
>   `cadence::_annot_declutter_clause {mask}` — the clause the *other* four
>   annotation chords carry afterwards (issue **1251**). It composes with these
>   three and reworded none of them; its own wording is `rule` debt **1251**.
> * **D-8's "`Ctrl-6` clears it with the rest" cost no code at all**:
>   `cadence::_annot_mask none` returns a hard 0. The rows asserting it were
>   green before the writer existed.
> * ⚠ **A net-zero pair of presses is not a no-op** — `annot_show_set()` stamps
>   `xctx->annot_root`, so two presses convert an `xschemrc`-armed `annot_show`
>   from one that survives a `File > Open` into one that is cleared by it. Issue
>   **1247**, measured, open, and it reverses a prior ruling whichever way it is
>   repaired.

**A2. The predicate.** One new rung in `text_hidden(flags, ctx)`, before the
`show_hidden_texts` fall-through:

```c
if(ctx == TEXT_CTX_INSTANCE && (flags & HIDE_TEXT_PARAM) &&
   (xctx->annot_show & ANNOT_SHOW_OP) && (xctx->annot_show & ANNOT_SHOW_NOPARAM))
  return 1;
```

Note it is gated on **both** bits, which is the user's "ONLY when OP info is
displayed" in one expression: with annotation off the declutter bit is inert and
every parameter draws.

> ⚠ **`HIDE_TEXT_PARAM` DOES NOT EXIST AND WILL NOT** (item A2, 2026-09-02). The
> snippet above predates **D-1** and is superseded by **A3** below: there is no
> parameter classifier, so the rung's test is *"carries neither
> `TEXT_ANNOT_NAME` nor an annotation class"*, not a `HIDE_TEXT_PARAM` bit.
> `TEXT_ANNOT_NAME 1024` is the only new `xText.flags` bit in feature A, and it
> is the **eleventh and last free power of two documented in the map** — the ten
> below it are `TEXT_BOLD 1` … `TEXT_ANNOT_CURRENT 512`. Item A3 needs no bit of
> its own: its per-instance gate cannot live in `xText.flags` at all (A3a).

**A3. The rule — settled by D-1.** There is no "parameter classifier". While
decluttering, an instance draws **its name and its OP annotation, and nothing
else**. That inverts the problem: instead of recognising ~33,000 shipped `T`
records as parameters, recognise the **three name spellings**, of which the tree
has exactly 4,632 occurrences across 3,686 `.sym` files — `@name` 3,165,
`@symname` 1,386, `@spiceprefix@name` 81.

So `set_text_flags()` gains one more implicit content class beside
`annot_content_class()`'s existing two:

```
TEXT_ANNOT_NAME 1024   /* the trimmed string is exactly @name,
                          @spiceprefix@name or @symname */
```

and `text_hidden()` gains one rung: in `TEXT_CTX_INSTANCE`, with **both** mask
bits set, hide any text carrying neither `TEXT_ANNOT_NAME` nor any annotation
class. ⚠ The rung must sit **after** the existing class tests, so that
`get_annot_overlay()`'s synthetic `text_hidden(HIDE_TEXT_OP, TEXT_CTX_INSTANCE)`
probe (§2.3) still answers exactly as it does today — a declutter that switched
the annotation overlay off would be the whole feature eating itself.

⚠ **`@spiceprefix@name` is 81 records and includes gf180's FETs and the generic
`devices/nmos4.sym`.** `draw.c:873`'s shipped keep-name test misses it; a rule
that copies that test inherits a measured bug in which those instances lose
their names entirely.

> **LANDED — item A2, 2026-09-02** (`src/xschem.h`, `src/actions.c`,
> `tests/headless/test_annot_declutter_1244.tcl` 36 → 52 checks). Full record:
> `doc/claude/op_param_batch/receipts/A2.md`. Six things the implementation
> settled or contradicted, all of which bind item A3:
>
> * ⚠ **The bit is set UNCONDITIONALLY, and this section implied otherwise.**
>   "gains one more implicit content class beside `annot_content_class()`'s
>   existing two" reads as *inside* the `annot_class_free()` gate. It is not.
>   The gate exists for one named mechanism — the two class bits are a
>   **visibility authority** that `text_hidden()` early-returns on *before*
>   `show_hidden_texts`, so an implicit class stacked on an explicit `hide=`
>   would move that text from *View > Show hidden texts* to the `annot_show`
>   mask. `TEXT_ANNOT_NAME` is deliberately **absent** from the
>   content-class-to-mask helper, which returns 0 for any bit it does not name,
>   so it gates nothing and that mechanism does not exist for it. Invariant
>   **I7** holds in both directions, and the bit can never make a hidden text
>   appear. **Measured before choosing, and it does not discriminate:** ZERO of
>   the 4,823 shipped name records carry any `hide=` token — 4,632 in `.sym`
>   plus **191 in `.sch`**, a figure this section did not have. So the choice is
>   about the **user's own future files**, and it is `rule` debt
>   **`1244_A2_name_bit_vs_hide_true`**, wanted **before A3 lands**.
> * **It is a separate `annot_name_token()`, not a third arm of
>   `annot_content_class()`.** That function carries two rules that exist solely
>   because `load_sym_def()` rewrites an LCC-embedded `@spice_get_voltage` into
>   `@spice_get_voltage(<parentpath><lab>)` *before* `set_text_flags` runs: the
>   trailing-`)` argument rule and the `@#<pin>:` split. Nothing rewrites a name
>   spelling, so inheriting them would classify `@name(anything)` as a name.
>   Copied instead, exactly: the two-ended trim, the `s[0] != '@'` fast reject,
>   and a length-exact `strncmp` — the length pairing is **forced**, because the
>   trim walks two pointers into a `const` string and cannot NUL-terminate it.
> * **"Under both contexts" is not implementable — it is unavoidable.**
>   `set_text_flags()` takes **no ctx argument**; it is called from `load_text()`
>   for the schematic's own `xctx->text[]` and from `load_sym_def()` for a
>   symbol's `tt[]`. The ctx distinction lives downstream, in the mask helper.
> * ⚠ **`xText.flags` is NOT observable from Tcl, and the obvious probe lies.**
>   `xschem get text_flags` does not raise — it returns the **empty string**
>   through the generic `get` fall-through, with or without an index; only
>   `xschem text_flags 0` errors. `scheduler.c` reads `text[i].flags` once (a
>   `TEXT_FLOATER` test) and never exposes `text_hidden`. **A3's rows will have
>   the same problem**, and A2's answer was C function-body slices plus an
>   out-of-suite gdb probe and a `-std=c89 -Wall -Wextra -pedantic` unit harness.
>   Budget for it; do not let a green structural suite be reported as
>   behavioural (issue **1248**).
> * ⚠ **42 shipped records put the name and a parameter in ONE `T` record** — 29
>   `.sym` + 13 `.sch`, 11 distinct strings (`@name\n@value` in `isource` and
>   `filesource`, `@symname\n@file`, `@name\n@wn/@ln\n@modeln` in `inv-2`,
>   `passgate`, sky130's `passgate_nlvt`, …). Whole-string correctly denies them
>   the bit, which means **once A3's rung lands those devices lose their NAMES
>   along with their parameters.** That is a consequence of **D-1**, not a bug,
>   and it is user-visible and unratified. A3 should surface it.
> * **`flags` is never serialised**, confirmed both ways: `save_text()` writes
>   `txt_ptr`, six numbers and `prop_ptr` and no flags field (structural row
>   N13), and the round-trip `.sch` is byte-identical across a mask sweep with
>   `modified` never set (row N12, and cross-binary against the pre-A2 build).
>   `XSCHEM_FILE_VERSION` does not move. Invariants **I-A** and **I-C** hold: a
>   60-schematic sweep across `xschem_library`, `xschem_libs_newsym`, sky130A,
>   gf180mcuD and ihp-sg13g2 is byte-invariant at masks 0/1/8/9.

**A3a. Which instances does it apply to? — OPEN, Q3.** Applying it to *every*
symbol would strip a hierarchical block of its pin names and cell name, which is
plainly not what was asked. The proposed default is the same gate carrier 2
already uses: **an instance declutters iff its `op_annot::text` block is
non-blank** — i.e. exactly the devices that got numbers lose their parameters,
and everything else is untouched. That gate is already computed per instance and
cached, so it costs nothing.

⚠ **Because symbol texts are shared (§2.3), this gate cannot live in
`xText.flags`.** It has to be applied at the six `TEXT_CTX_INSTANCE` call sites,
which do know the instance — most cheaply as a new context value
(`TEXT_CTX_INSTANCE_ANNOTATED`) rather than a third argument.

> ⚠ **THAT LAST SENTENCE IS WRONG AND ITEM A3 MEASURED WHY** (2026-09-02). A new
> context value is the **expensive** option, not the cheap one:
>
> * `annot_class_mask()` and `annot_text_layer()` both open with
>   `ctx != TEXT_CTX_INSTANCE`, so a fourth value silently kills the implicit
>   node-voltage class **and** issue 0615's annotation-colour override on exactly
>   the annotated instances the feature targets. Both guards would have to be
>   inverted in the same commit — and `annot_text_layer(text.flags,
>   TEXT_CTX_INSTANCE)` is a hardcoded literal *inside the same three render
>   loops*, so a careless sweep rewrites it too.
> * A ctx **value** cannot carry the datum. Each of the six sites would have had
>   to compute the gate itself and choose between two constants: six copies of one
>   decision, against invariant **I1**.
>
> **Shipped instead:** a third argument, behind two entry points on one core
> (§2.3). `text_hidden()` keeps its exact signature and its exact behaviour for
> all five schematic sites *and* for the overlay's probe; `text_hidden_inst(flags,
> n)` is the instance entry. Ladder **L2** — smallest blast radius — reinforced by
> **I1**.

**A3b. What the gate actually tests.** Shipped as `annot_instance_annotated(n)` =
`get_annot_overlay()`'s own precondition chain (factored out as
`annot_overlay_gate(n)` so the two readers cannot drift, **I1**) **plus** — since
item **A5-a**, 2026-09-02 — a block carrying **at least one actual VALUE**
(`annot_block_has_value()`, a pure scan of the same cached string). It must
**not** call `get_annot_overlay()` itself: that function does
`++annot_overlay_count` and row **O13** of `test_op_annot.tcl` golds the delta
exactly, so one call per text per instance per frame would both red O13 and
destroy the only seam an automated check has on the overlay.

⚠ **`op_annot::text` emits blank-VALUED rows when the raw publishes nothing for a
registered device.** Measured, twice, first-hand: with a descriptor registered and
a raw loaded whose vectors do not resolve, `op_annot::text M1` returns
`"zid =\nzgm =\n"` — non-blank — while a descriptor-less `R1` returns `{}`.

**Item A3 therefore shipped a gate that read *"this device has a descriptor whose
`match`/`devpath` resolve and which declares at least one row"*, not *"numbers
arrived"* — and that was wrong.** It followed the *pixels* (what the overlay
paints) where D-6's words are "only instances that got **OP numbers**". Item A4
then measured the consequence with **no raw loaded at all**, i.e. before any
simulation has been run:

```
raw loaded = -1
mask 1  ->  MC1 CW=1u {cid =}
mask 9  ->  MC1 {cid =}
```

The user presses `6`, presses `Ctrl-Alt-6`, and trades `W/L` for an empty label:
the whole feature inverted, in the first thirty seconds of using it.

**CORRECTED by item A5-a, 2026-09-02 (driver ruling).** The gate now requires
`annot_block_has_value()` — per line of the cached block, after the first `=`, any
character that is not a space or a tab. It is a **pure function of the string
`annot_overlay_cached_text()` already returns**: no `tcleval`, no `tclgetvar`, no
`xschem raw value`. That is deliberate and is the whole answer to issue **0466**
(thirteen epoch fields and not one moved on `xschem reload`, so the overlay painted
the previous file's numbers): value-ness acquires **zero** invalidation inputs of
its own and rides the one wholesale flush `annot_overlay_sync()` already performs,
so it cannot be staler than the block the overlay paints. Answering from a *second*
source would be 0466 re-opened. `rule` debt **`1244_A3_blank_valued_block`** stays
on the user's queue as confirmation of the gate itself.

⚠ **SO THE GATE AND `get_annot_overlay()`'s D1 TERM NOW DELIBERATELY DISAGREE, AND
D1 IS UNCHANGED.** The overlay keeps **painting** a label-only block, because a
user is entitled to see *which* parameters this device would show once the raw
carries them (invariant **I3**'s spirit — a missing vector renders blank, never a
stale or invented number). The declutter is the stronger half because it removes
the **user's own text**, so it may fire only where numbers actually replaced it.
An earlier draft of the C comment asserted the two "answer to ONE fact and cannot
disagree"; that sentence was **false** and has been rewritten in place.

⚠ **Two ways a valueless device still slips through, both measured after the fix
and both filed:** a descriptor **label containing `=`** parses as valued (issue
**1258** — the mint writes the separator as `` ` = ` ``, so requiring that, or
taking the last `=`, closes it), and a raw that publishes **0.0** renders `zid = 0`
and opens the gate (issue **1259** — absent-vs-zero is a distinction the block
string does not carry, and belongs with item B1's backend seam).

⚠ **Feature A shrinks the target feature B clicks.** `select.c:709` calls
`text_hidden` inside `symbol_bbox`'s text loop, so a hidden text shrinks the
with-text box `inst[i].x1..y2`; `findnet.c:461`'s `find_closest_element` uses
`POINTINSIDE` against exactly that box as its candidate gate. With A on, the
clickable area of every decluttered device gets smaller. That is arguably
correct — the text is not there any more — but it must be a check, not a
surprise.

> **MEASURED, item A3, 2026-09-02** — `cmos_inv.sch`, `M1` annotated, at mask 9:
> the with-text bbox `x2` goes **177.376 → 157.433** (`y1`/`y2` unchanged, and the
> surviving `@name` is what still stretches it); `xschem instance_at <x> -170`
> stops answering `M1` at x = **160/170/175** and still answers at 130/140/150,
> where before it answered at all six. Descriptor-less `R1` does not move at any
> mask. `rule` debt `1244_A3_click_target`; **item B4 clicks these devices** and
> must refresh the bboxes first (issue **1252**).

**A4. The chord.** ⚠ **`Ctrl-Alt-6` is not free today.** Tk matches a pattern
whose modifiers are a **subset** of the event's, and `op_annotation.md` §4.6
records it measured: *"`Ctrl+Alt+6` falls into the Alt form."* So pressing it now
turns node voltages on. The binding must be spelled out explicitly with a
trailing `break`, in `src/cadence_style_rc` beside its three neighbours:

```tcl
bind .drw <Control-Alt-Key-6> {cadence::annot_declutter toggle; break}
```

Unlike `6` and `Alt-6`, which RULING 0614 made additive setters, this one is a
**toggle** — the user asked for "hide/show". That asymmetry is deliberate and is
recorded here so it is not "corrected" later.

> **LANDED — item A1, 2026-09-02, and the prediction was collected on.** Before
> the bind existed, the chord was measured reaching `cadence::annot_mode opvolt`
> **two independent ways**: by mask (`annot_show` 1 → **3**, i.e. it turned node
> voltages on) and by a rename-stub dispatch recorder, whose answer was
> byte-identical to `<Alt-Key-6>`'s. After: `1 → 9`, `9 → 1`, `0 → 8`, and
> `rectcolor` is 4 throughout.
>
> Two corrections to this section's assumptions:
>
> * **Placement in the file is irrelevant.** Tk orders bindings by *specificity*
>   within a bindtag, not by file position — measured. The bind sits after
>   `<Alt-Key-6>` for readability alone.
> * **The `break` matters for a reason this section did not give.** It is not the
>   C layer-select (`callback.c:7474` tests `state==ControlMask` *exactly*, so a
>   Ctrl+Alt chord never reaches it). It is `bind all <Alt-Key>`, which is Tk's
>   own `tk::TraverseToMenu`, on the `all` bindtag — without `break` the chord
>   falls through to menu traversal. Row T4 measures it: 0 calls with the
>   `break`, 1 without.
> * **`<Control-Alt-Key-6>` is Tk's canonical spelling**; `<Alt-Control-Key-6>`
>   normalises to it. (Contrast `<Alt-Shift-Key-6>`, which lists as
>   `<Shift-Alt-Key-6>`.)
> * **One bind reaches all four profiles.** Each of `sky130A/`, `gf180mcuD/` and
>   `ihp-sg13g2/`'s `cadence_style_rc` is a single `source … src/cadence_style_rc`
>   line — measured — which is how landmine 6 is discharged without editing three
>   files.

> **LANDED — item A3, 2026-09-02** (`src/xschem.h`, `src/actions.c`, `src/draw.c`,
> `src/svgdraw.c`, `src/psprint.c`, `src/select.c`, **`src/scheduler.c`**,
> `src/xschem.tcl`, and rows in three suites; `test_annot_declutter_1244.tcl`
> **52 → 82 checks, ALL PASS**). Full record:
> `doc/claude/op_param_batch/receipts/A3.md`. **Feature A is complete.** The
> headline, on `cmos_inv.sch` with a descriptor and an OP raw:
>
> ```
> BEFORE   SVG identical 1 vs 9 : 1    mask 9: ... WP/LLP/1 M2 D {vgs=- - -} {vds=- - -} WN/LLN/1 M1 D vgs=0 vds=0 ...
> AFTER    SVG identical 1 vs 9 : 0    mask 9: ... M2 - {zid =} {zgm =} M1 - {zid =} {zgm =} ... R1 10 m=1 ...
> ```
>
> `0 vs 8 : 1` — with `ANNOT_SHOW_OP` clear the declutter bit still changes not one
> byte, invariant **I-C**, swept over four mask pairs. `modified` 0 and the `.sch`
> byte-identical across the sweep, invariant **I-A**, diffed rather than inferred.
>
> Five things this section did not say, and one it said wrongly:
>
> * ⚠ **The rung's position is forced on BOTH sides.** Below the class arms, for
>   the overlay probe (§2.3) — which this section did say. **Above** the
>   `show_hidden_texts` arm, which it did not: both shipped Op-Annotate menu
>   bodies do `set show_hidden_texts 1` **one line before** writing the mask
>   (`src/xschem.tcl`), so a rung below that arm would be a no-op on the exact
>   workflow the feature was written for. Row **A10** measures it; row **A20**
>   reads the arm order back out of the C.
> * ⚠ **`src/scheduler.c` had to join the file set.** One line —
>   `annot_overlay_sync();` beside `annot_show_sync_cache();` in the
>   `update_all_sym_bboxes` arm — because the D-6 gate reads the overlay cache and
>   that cache was synced at three draw/export entry points only. Without it the
>   shipped `annotate_op; update_all_sym_bboxes; redraw` computes the click target
>   from the pre-annotate cache. The other **38** `symbol_bbox()` callers still ran
>   outside any overlay sync: issue **1252**, **fixed at the second Tcl-reachable
>   door by item A5-c** (`annot_overlay_sync()` in the `recompute_inst_bbox` arm).
>   1252's own recommended repair — *"call `annot_overlay_sync()` wherever
>   `annot_show_sync_cache()` is already called"* — is **refuted**: the stale door
>   calls neither sync, so that repair leaves the defect where it was found.
>   Residue in issue **1260**: `xschem setprop instance` and `xschem move_instance
>   … nodraw` still write the click box from a stale gate (and A5-a *widened* the
>   first — a rename over a dead raw now flips the gate where before it did not),
>   and the **mask** half is still unsynced at `recompute_inst_bbox`.
> * ⚠ **The PDK symbols' OWN operating-point texts carry `hide=true`** (3 in
>   sky130 `nfet_01v8`, 2 in gf180 `nfet_03v3`, 0 in IHP `sg13_lv_nmos`), so they
>   are **not** annotation-classed, and once *View > Show hidden texts* is on —
>   the state both menu bodies create — **the rung hides them**, replaced by the
>   overlay block. Intended trade, unstated anywhere until now. `rule` debt
>   `1244_A3_hide_true_op_texts`.
> * ⚠ **P6 pin-owned pin names were NOT reached** (issue **1253**): they are drawn
>   by a **fourth** pass gated by `pin_name_visible()`, not by `text_hidden()`, so
>   a pin spelling `show_pinname=true` kept its name on a fully decluttered
>   device — measured first-hand. Inert on all three PDK acceptance devices (four
>   pins each, all `false`); live for the 2,968 shipped `true` records. D-1 says
>   pin labels are in scope, so this was a gap in the *implementation*, not in the
>   ruling. **FIXED by item A5-b**: one shared `if(text_hidden_inst(0, n)) continue;`
>   immediately after the `pin_name_visible()` anchor in each of `draw.c`,
>   `svgdraw.c` and `psprint.c`. The **click target does not move** — `symbol_bbox()`
>   walks only `symptr->text[]` and has no P6 pass, so this is purely a render
>   change.
> * **The 42 one-record `name+parameter` symbols are spared on this tree by the
>   gate**, not by luck: every shipped PDK descriptor is `match`-narrowed and
>   registers only `nmos`/`pmos` (+ IHP `vertical_npn`), so none of the 42 resolves
>   a devpath. Live only for a user's own `op_annot::register`.
> * **Issue 1249 was fixed as this section demanded**, by exporting
>   `annot_name_token()` — four copies of one predicate become one builder (**I1**).
>   Censused over 44,177 `T` records in five libraries: **exactly 69 symbols**
>   render differently, all of them the `@spiceprefix@name` spelling, and zero
>   because of the whitespace trim. The repair is **ungated by `annot_show`**.

> **LANDED — item A4, 2026-09-02** (`utils/annot_mode.tcl`,
> `tests/headless/test_annot_stale_0684.tcl` **52 → 54**,
> `tests/headless/test_annot_declutter_1244.tcl` **82 → 93**). Issues **1250**
> and **1251** closed; **1255** and **1256** filed and not fixed. **Status E** —
> the clause's wording is `rule` debt **1251**. Three things this section did not
> say, and one it implied wrongly:
>
> * ⚠ **THE DECLUTTER FIRES ON DESCRIPTOR RESOLUTION, NOT ON NUMBERS ARRIVING,
>   AND THE SENTENCE HAD TO FOLLOW IT.** §4.1's D-6 gate is a **non-blank**
>   `op_annot::text` block, so a registered device over a dead raw — or over *no
>   raw at all* — is decluttered while its block shows `zid =` with no value
>   (already recorded at §4.1 and as `rule` debt `1244_A3_blank_valued_block`).
>   Item A4 first gated the 1251 clause on `$state eq {live} || $state eq
>   {loaded}`, reasoning from issue 0909's `canask` term, and **that was measured
>   wrong the same day**:
>
>   ```
>   raw loaded = -1
>   mask 1 texts = MC1 CW=1u {cid =}
>   mask 9 texts = MC1 {cid =}
>   ```
>
>   `noraw` is the most common press there is (`6` before the simulation is run),
>   so the silence was the inaccuracy. **The gate is bit 3 AND bit 0 and nothing
>   else.** Whatever item A5 decides about the blank-block gate moves this
>   clause's truth condition with it; row **E6** is the row that notices.
> * ⚠ **THE 255-BYTE STATUS BUDGET NOW HAS A BIT-3 CONSUMER AND IT IS NEARLY
>   FULL.** Row A11-10 of `test_op_annot.tcl` and row V21 sweep masks **0..7
>   only**, so `test_annot_declutter_1244.tcl` row **B1** is the only place in the
>   tree that budgets a bit-3 sentence. Measured at an ordinary 55-byte results
>   path: with issue 0909's cause clause also present the declutter clause is
>   amputated by `cadence::_annot_fit` at masks **11, 13 and 15** in every state,
>   and never at mask 9 — A11-12b's ordering (the answer outranks the rest) doing
>   its job. The cap itself was **not** widened: 0639 rejects both that and
>   shortening the path, and `char statusmsg_text[256]` is a C array no `.tcl`
>   edit can move.
> * ⚠ **`Alt-Shift-6` composes at the CALL SITE.** `cadence::_annot_tran_msg` is a
>   pure four-argument minter that takes **no mask**, raises on unknown states, and
>   is golded in `tests/headless/test_op_annot.tcl` — a file item A4 does not own.
>   `cadence::annot_tran` therefore names the mask it writes
>   (`set newmask [expr {$mask | 4}]`) and appends the clause itself, on the
>   success path only.
> * **The bit still has two doors, and only one of them speaks.** The stock
>   `Waves > Op Annotate` menu (`src/xschem.tcl:17311`, `:17749`) preserves bit 3
>   — deliberately, since item A3's 1246 fix — and emits **no status sentence at
>   all**. Issue **1256**, filed and not fixed; `src/xschem.tcl` is in no Files
>   cell of items A4 or A5.

> **LANDED — item A5, 2026-09-02** (`src/actions.c`, `src/draw.c`, `src/svgdraw.c`,
> `src/psprint.c`, `src/scheduler.c`;
> `tests/headless/test_annot_declutter_1244.tcl` **93 → 105**). Issues **1252**,
> **1253** and **1254** closed; **1257**, **1258**, **1259**, **1260**, **1261**
> filed and not fixed. **Status E.** Four changes, five added code lines and one
> 12-line pure function:
>
> * **A5-a — the gate requires a NUMBER** (§4.1 A3b above, rewritten). Driver
>   ruling. Rows **A30** (no raw at all), **A32** (a raw that publishes nothing for
>   this device), **A33** (the valued control, still decluttered), **A34** (the
>   mint contract pinned from the Tcl side, so a change to `::op_annot::text`'s
>   width pass reds a row instead of silently re-opening the defect) and **A35**
>   (structural: one definition, one call, and the helper's body contains no
>   `tcleval`/`tclget`/`op_annot`/`xctx` — the 0466 guarantee written as structure).
> * **A5-b — 1253, pin names**, three byte-identical one-liners.
> * **A5-c — 1252, the stale `symbol_bbox()` door.** ⚠ **ORDER IS LOAD-BEARING in
>   any row that measures this**: any sync repairs the cache, so the stale door must
>   be read **first**. Row **A40**.
> * **A5-d — 1254, the two vacuous rows**, repaired in place and **shown failing**
>   under the sabotage that used to leave them green (`SB7b` → A15; `SB-GATE-ALWAYS`
>   → A17). Row **A22**'s source census golden moved `{3 1 1 1 0}` → `{4 2 2 1 0}`
>   deliberately; the regexp was **not** widened.
>
> Three things this section did not say:
>
> * ⚠ **TWO SUITE READERS PUNISH COMMENT PROSE IN `draw.c`/`svgdraw.c`/`psprint.c`.**
>   Row **A22** (`opa_n_grep`) counts comment lines, so writing `text_hidden_inst(`
>   in prose inflates the census; and row **L27** of `test_op_annot.tcl` asserts the
>   literal `HIDE_TEXT` survives in exactly **one** `.c` file. Both tripped item A5's
>   first draft and both are avoided by wording. Whoever next comments those three
>   files will hit them again.
> * ⚠ **Row A38 requires the new guard on the line IMMEDIATELY after the
>   `pin_name_visible()` anchor** (an exact trimmed-line match), so rationale prose
>   must live *above* the loop, not between the anchor and the guard.
> * ⚠ **`draw.c` DOES have a behavioural seam, contrary to what item A5 believed**
>   (issue **1261**): `print_image()` calls `draw()`, so a warm-then-real
>   `xschem print png` pair at a **tight** viewport measures a pin name going away
>   (12912 → 8301 bytes, with an 8744/8744 `show_pinname=false` control). At the
>   suite's usual wide viewport the name is zoom-culled at both masks and the PNGs
>   are byte-identical — which is how the seam was missed. `draw.c`'s leg is
>   therefore guarded by a **grep census** today.

### 4.2 Feature B — the Results Display Window

**B1. Naming.** `results::` is taken (§2.6). This feature takes **`rdw::`**, in a
new `src/rdw.tcl`, with menu label **Results Display Window**. ⚠ Adding a new
`src/*.tcl` obliges an install **and** an uninstall line in `src/Makefile.in`
and a `./configure` re-run — CLAUDE.md's issue 0424 trap; verify with
`grep -c rdw.tcl src/Makefile`, expect 2.

**B2. The window.** A singleton toplevel: a scrollable, selectable, read-only
text pane on the left; a button column on the right. Newest dump on **top**,
older dumps pushed below. Key `4` clears everything but the most recent.

**B3. The dump.** One block per request:

```
M2B:/xdut/xbg/xamp1
id  : 2.4u
gm  : 123u
```

The header is the instance name, a colon, and the hierarchical path. ⚠ **That is
not the tree's native spelling.** xschem's own is dot-separated and
element-lettered — `@m.x1.x1.xm2.msky130_fd_pr__nfet_01v8_lvt`. Question Q6.

> ✅ **ITEM B3, 2026-09-03 — BUILT, AND THE BLOCK IS BIGGER THAN THIS SECTION
> DRAWS IT.** `src/rdw.tcl`, 675 lines, pure Tcl. `grep -c rdw.tcl src/Makefile`
> **0 → 2** and the **installed** binary starts `rc=0` against the installed
> sharedir, so issue 0424 is closed in fact and not only in the generated
> Makefile. Singleton `.rdw`, raise-if-exists, `wm protocol … rdw::close`. The
> pane is `text -state disabled -exportselection 1`: measured on Tk 8.6.17 with
> `openbox` live, a real click plus `x` / `Return` / `BackSpace` / `Delete` /
> `<<Paste>>` leaves the buffer **byte-identical**, `<<SelectAll>>` takes the X
> `PRIMARY` selection and `<<Copy>>` lands the text on the clipboard — and the
> clipboard text equals `rdw::block_text` of the store, so the paste shape and
> the pane provably cannot drift. Every Tk command sits behind `rdw::have_tk`,
> proved **behaviourally** by sourcing the file into a bare `interp create`
> slave that has neither `winfo` nor `xschem`.
>
> **The block as shipped, against the four lines drawn above:**
>
> ```
> M2B:/xdut/xbg/xamp1                      <- tag hdr (Q6's default, bold)
> @m.x1.x1.xm2.msky130_fd_pr__nfet_01v8    <- tag dim (op_annot::devpath's OWN
>                                             string — what a user pastes into
>                                             ngspice; invariant I1, B3 builds
>                                             no @-name of its own, ever)
> Not a complete list: these are the operating-point columns this run saved
> for this device, not everything the device has.        <- tag note, DD-1's
>                                                           corollary, only when
>                                                           complete=0 AND state
>                                                           ok AND union non-empty
>   @r.xr1.x0.rend1                        <- per-primitive sub-header, needed by
>     i     : 1e-06                           D-3 (two primitives of one XR1 both
>   @r.xr1.x0.rend2                           publish a parameter spelled `i`);
>     i     : 2e-06                           suppressed only when there is
>                                             exactly one primitive whose name
>                                             equals line 2
>     vth   : (did not converge)           <- from `nonfinite`, never `nan`/`inf`
>     ib    :                              <- from `absent`, BLANK (invariant I3)
> A blank value means the raw names that column but the simulator did not
> compute it.                              <- tag note, only when absent non-empty
> ```
>
> **⚠ THE ROW SET IS THE UNION OF ALL THREE BUCKETS, AND THIS IS THE ITEM'S
> SHARPEST TRAP.** A device can appear in **no** `devices` entry at all:
> measured, an all-`dims=0` device answers `devices {} absent {…} state ok` and
> a binary NaN/Inf device answers `devices {} nonfinite {…} state ok`. Anything
> that walks `dict keys [dict get $ans devices]` prints an **empty dump for a
> real, named, non-converged device**.
>
> **A FIFTH SILENCE WAS NEEDED AND IS NOT IN THIS SPEC.** The seam's four non-`ok`
> states are four silences; **`state ok` with nothing in any bucket is a fifth**,
> and under measured rule **R1** it is the *common* one. It gets its own
> sentence, because saying nothing is indistinguishable from a rendering bug. All
> seven user-visible sentences are **unratified** — rule debt
> `1245_B3_window_wording`.
>
> **⚠ AND A SIXTH STATE NOBODY NAMED IS LIVE AND WRONG — issue 1282.** The seam's
> allow-list is `{op dc}`, not `{op}`, so a **DC sweep** answers `ok` with real
> point-0 numbers and the block presents them as an operating point with the word
> `dc` nowhere. Measured `sim_type = dc`, `state = ok`,
> `block-mentions-dc = 0`. Filed, **not fixed**: naming it, rendering it silently
> and refusing it are three different answers and the choice is the user's.
>
> **The dumps survive a close and reopen** (`::rdw::blocks` is namespace state;
> `rdw::close` touches it not at all), deliberately diverging from the
> Calculator, which clears its history. Rule debt `1245_B3_dumps_survive_close`.

**B4. The three lists.**

| key | list | source |
|---|---|---|
| `1` | **annotation** | the descriptor's `params` — the very list `6` paints |
| `2` | **summary** | a new per-class ordered list; **default = all available** |
| `3` | **all** | every parameter the simulator published for this device |

**B5. Where "all" comes from — the seam, RULED D-4 + D-5.**

Key 3 never asks ngspice a question directly. It asks the **backend** one:

```
ase::backend::<sim>::op_param_set <devpath>   ->  ordered {param value} pairs
```

> ⚠ **THAT RETURN SHAPE IS WRONG, AND THIS SPEC IS THE THING THAT IS WRONG.**
> Item **B1** implemented it, measured it against this section's own examples and
> refuted it (2026-09-03; receipt `../op_param_batch/receipts/B1.md`). §3.1's
> `XR1` resolves to `r.xr1.x0.rend1` **and** `r.xr1.x0.rend2`, and **both**
> publish a parameter spelled `i` — so a flat `{param value}` list cannot say
> which primitive each number belongs to, and **ruling D-3 becomes
> unimplementable in the shape this line asks for**. DD-1's corollary
> independently forbids handing a caller the pairs without the incompleteness
> riding alongside them, and there is nowhere in a flat list to put it.
>
> **The shape that survives measurement is an ANSWER DICT with FIVE keys:**
>
> | key | what it carries |
> |---|---|
> | `devices` | ordered `{<rawdev> {{<param> <value>} …}}` — one entry per **primitive** the request covers, raw-file order throughout |
> | `absent` | ordered `{<rawdev> <param>}` — columns the raw **names** and the simulator **did not compute** |
> | `nonfinite` | ordered `{<rawdev> <param> <text>}` — columns the raw **does** carry, holding Inf/NaN: **a device that did not converge** |
> | `complete` | the honesty flag **as data** (DD-1's corollary): the value the capability declares, `0` for today's ngspice |
> | `state` | `no_devpath` \| `no_raw` \| `not_op` \| `not_annotated` \| `ok` — four silences a caller must tell apart, which otherwise all arrive as the same empty list |
>
> ⚠ **`nonfinite` IS A SEPARATE BUCKET ON PURPOSE, AND IT WAS THE FIFTH KEY
> ADDED BY B1's RE-DO** (issue 1272). It renders blank today, exactly like
> `absent`, which is what makes collapsing the two tempting and wrong: *"the raw
> does not carry `id`"* and *"the raw carries `id` and the simulator produced
> NaN"* are different facts about the run, and the second is the one a designer
> most wants surfaced — a non-converged operating point is a **result**, not a
> gap. ⚠ And an **empty** `nonfinite` is not proof the run converged: the same
> NaN in an **ascii** raw arrives as a finite `0` and lands in `devices`,
> because `src/save.c`'s fast `my_atof()` path never parsed the words. That
> asymmetry is deliberate there and is still open at the end of issue 1272.
>
> **The capability is a second, optional hook** — `op_param_enumerable` — beside
> `op_param_set` in the same backend dict, because it is a question about the
> **backend** that must be answerable before any run, click or devpath exists.
> Neither may join `ase::register_backend`'s required-hook loop: two suites
> hand-build five-hook registrations that raise if a sixth becomes required.
>
> **B1 first returned `[F]`** on two separate defects — issue **1272** (it read
> through `op_annot::raw_or_blank` without `op_annot::_finite`, so a binary raw
> carrying a NaN returned `nan` in the **value** bucket, I3's own failure), and
> an over-strip in `ase::op_dev_norm` that silently lost any device whose path
> began with a one-character segment. The shape above is not what was refuted;
> it is what was measured. ✅ **Both were fixed the same day in a driver re-do
> and the seam is in the tree: 37 → 49 checks, ALL PASS.** It binds **B2**,
> **B3** and **B5**, and B3 renders from **five** keys, not two.
>
> **⚠ ABSENCE MAY BE REPORTED ONLY IN STATE `ok`.** Measured: `xschem raw value
> <v> -1` is the only reader carrying the absent/zero distinction — a `dims=0`
> column answers the empty string there and `0` at point 0, while a genuinely
> computed `0.0` answers `0` at both — but **before `update_op()` has published,
> point −1 is empty for every vector**. A seam that filled `absent` outside `ok`
> would report *"the simulator did not compute id"* about a run nobody annotated.

with a companion capability answer saying whether the backend can enumerate at
all. Two implementations, one contract:

| | today ("the dumb approach") | when the user's custom ngspice lands |
|---|---|---|
| source | the run's own **raw**, filtered to `<devpath>[…]` | the **wildcard OP info save**, which publishes every device parameter without cards |
| completeness | exactly what lists 1 and 2 asked for — honest, and no more | complete |
| invented by us | nothing | nothing |
| new machinery | **none** — `xschem raw` already holds the vectors | one emitter line, one capability flag |

**The whole point of the seam is that nothing above it changes.** The window,
the three keys, both grammars, the button column, the two dialogs and the
settings file are written once, against `op_param_set`. When the wildcard
arrives, key 3 becomes complete and no crew re-opens `src/rdw.tcl`.

⚠ **So key 3 is thin today, deliberately.** Until the custom simulator exists it
shows what the run saved, and the honest UI answer when that is only six rows is
to say so — not to go looking for more. A crew that "improves" key 3 by adding a
`show` parse, a per-model catalogue, or a probe-and-prune step is **violating
D-4** even though its output looks better.

⚠ **What is measured and NOT taken** (§3.6): `.options savecurrents` is a real
wildcard, it is free, and it enumerates every sub-primitive at every depth. It
is recorded here as an option deliberately left on the table — it would change
the deck, it publishes currents only, and three of a FET's four currents come
back zero-length. Revisit it only if the custom ngspice does not arrive.

**B6. The two grammars.**

* **noun-verb** — select one instance, press `1`/`2`/`3`. More than one selected,
  or nothing available: **refuse with one short line in the CIW** and change
  nothing.
* **verb-noun** — press `1`/`2`/`3` with nothing selected: enter a command mode
  modelled on ASE Direct Plot (§2.5), seizing `<ButtonPress-1>` and
  `<Key-Escape>`, resolving each click with `xschem instance_at` so **the
  selection never changes**, and registering with `cmdmode::register` so a
  descend can suspend and resume it.

⚠ **Bare `1`-`4` are taken.** `callback.c:7434-7448`: with no modifier, keys
`0`-`4` call `logic_set()` — "toggle pin logic level" — and `5` toggles
`only_probes`. Binding them in `src/cadence_style_rc` with `break` displaces a
shipped editing action for cadence-profile users only. Question Q5.

**B7. The button column.**

| button | annotation list (`1`) | summary list (`2`) | all (`3`) |
|---|---|---|---|
| **Up** / **Down** | reorder | reorder | reorder |
| **Delete** | remove from annotation | remove from summary | **greyed** |
| **Add** | — | add to annotation | add to **annotation or summary** (the dialog asks which) |
| **Save** | write the settings file | write the settings file | write the settings file |

> ✅ **ITEM B3, 2026-09-03 — THE COLUMN IS BUILT, GREYED AND INERT, AND THE
> `—` IN THE `Add` CELL IS NOW `greyed`.** Five buttons `Up · Down · Delete ·
> Add · Save`, the greying driven by `rdw::button_state {id kind}` — **this
> table as data**, so B5 can assert it with no Tk. The `Add`/annotation cell was
> an em dash, which does not say *greyed* versus *absent*; B3 shipped **greyed**
> by ladder **L2**, because the column then keeps a constant shape as the user
> switches lists and the other four buttons do not move under the pointer.
> Unratified — rule debt `1245_B3_add_greyed_on_list1`; overruling costs one line
> of `rdw::button_state` and one golden row. **Every enabled button is INERT**
> and names item **B5** in the window's own status line; **B5 replaces
> `rdw::inert`, it does not add a parallel command path.** The list identity is
> `::rdw::listkind`, moved only by `rdw::set_list` — **B4 must drive that setter
> rather than mint a second one** (invariant I1's shape). The greying keys on
> list **identity**, never on list **content**, which is why issue **1278**'s
> unbounded-glob freeze does **not** land on this window's redraw.

> ✅ **ITEM B2, 2026-09-03 — LIST 3 HAS NO PERSISTED STATE, AND THE STORE HAS
> NO SLOT FOR IT.** It is live from the run, its Delete is greyed above, and a
> persisted `all` would be a list no simulator ever published — the invented
> data **D-4** forbids. `op_param_lists::owns` answers 0 for it always,
> `effective` answers `{}`, and a settings-file row naming it is reported and
> skipped with a sentence saying why. **B5's Add-from-list-3 writes into
> `annotation` or `summary`** and so is left with nowhere to write.

Every Delete and Add raises a **scope dialog**: *this device flavor only*, or
*every device of this broad class*. That maps onto the descriptor's `match`
glob (§2.1) — narrow writes a flavor-specific entry, broad writes the class
entry. ⚠ Modal dialogs are a known headless-harness hazard (issue 0803: a modal
dialog hangs any suite under X); the dialog must be drivable by the tests
without a human.

#### AS BUILT — item B2d, 2026-09-04: the answer dict is UNTRUSTED INPUT

The five-key table above is a **description of what a well-behaved backend
sends**, and item B2d makes the renderer treat it as exactly that. Ruling
**D-5** exists so a second backend can plug in; the first one to occupy these
shapes will be the user's own custom ngspice. The contract, now implemented and
fenced in `tests/headless/test_rdw_window_1245.tcl` (rows F14-F29, Q6-Q9):

* **Only `state` is required.** `devices`, `absent`, `nonfinite` and `complete`
  are required **only when `state` is `ok`**, and an absent key is EMPTY, never
  malformed. **A non-`ok` state is a complete and legal answer on its own** and
  is rendered from `state` alone, with **no shape check of any kind** — a
  refusal makes no claim about data and nothing may walk what it did not claim.
  This corrects the "five keys, always" reading that made B2a accuse a correct
  backend of malforming its own refusal. `rdw::_answer_state` runs FIRST;
  `rdw::_answer_flaw` is consulted only under `ok`. Row **F26** asserts that
  order **structurally**, by reading `format_answer`'s own body.
* **An answer with no readable `state`, or that is not a dict at all, is itself
  malformed** and gets the flaw sentence naming the backend — never the fifth
  silence, which is a statement about the *raw* and would be false.
* **The bucket widths are part of the contract, and they differ**: `absent` is a
  `{<rawdev> <param>}` PAIR, `nonfinite` a `{<rawdev> <param> <text>}` TRIPLE
  (`rdw::_bucket_width`). A two-field `nonfinite` entry is an answer that does
  not meet the contract, not a short form — rendering `(did not converge)` from
  it is an assertion on no evidence.
* **Every entry must NAME a parameter** (`rdw::_named`, a `string trim`
  non-empty test on the `devices` pair's first field and a bucket entry's
  second). A value under no name is the "blank row that means nothing" the
  predicate rejects elsewhere. ⚠ The predicate is on the NAME, never on arity:
  a value-less `{id}` is legal and renders `(no value reported)`.
* **A missing or empty value renders `(no value reported)`**, in the same word
  family as `(did not converge)`, so it is no longer byte-identical to an absent
  column's blank and the per-block blank footnote is no longer false about it.
* **⚠ ONE BLOCK ENTRY IS ONE LINE, AND THE GUARANTEE LIVES AT THE EMIT POINT.**
  `rdw::_line {tag text}` wraps every line the file appends to a block;
  `rdw::block_text` joins the entries with a newline, so an entry containing one
  makes the block, the paste text and the pane report three different line
  counts (measured: 4, 5 and 7 on one answer). The escape was
  `_state_sentence`'s verbatim echo of the backend's own `state`, which rendered
  two fabricated, correctly formatted operating-point rows onto the clipboard.
  The same escape existed in `_flaw_line`'s backend name, the `dim` device-path
  line, the fifth silence's `$dp`, the `no_devpath` instance name and
  `dump_devpath`'s `"could not answer: $ans"` — a caught Tcl error, multi-line
  by nature. **A new `lappend out [list …]` in this file is a defect** (row F29).
* **Nothing raises.** `rdw::format_answer` is a pure renderer called by every
  suite row and every widget path; a raise out of it stops `Tcl_AppInit` dead
  under `--pipe`. 22,022 fuzzed answer shapes, zero raises.

**Ruling DD-5 is implemented as option (a)** — a `dc` answer is still rendered
and the block names the analysis, as a `note` between the device path and the
incompleteness line. ⚠ **The wording is not DD-5's specimen**, because
`src/save.c:1073` and `:1120` rename a *multi-point* `Operating Point` plot's
`sim_type` to `dc`; the shipped sentence names what the loaded results call
themselves. On the owed ledger as rule debt `1282_analysis_sentence_wording`.
⚠ **And the sentence is a property of `rdw::dump`, not of `rdw::dump_devpath`**
(issue **1298**): the door adds `sim` to the ctx and never `simtype`, so a
caller building its own ctx — items B4 and B5 — loses the sentence silently.

**Two refusals, not one** (`rdw::_sim_refusal`): *"no simulator named X is
registered"* and *"X is registered but declares no `op_param_set` hook"* are
different facts with different remedies. Membership is asked of
`ase::backend_names` **before** `ase::backend_hook` is called, so there is one
source of truth rather than a parsed error string.

### 4.3 The class map

§3.4 says `nmos` and `pmos` are separate tokens and the resistor spelling
differs per PDK. So a **class map** is required: `type=` token → broad class.

```
nmos pmos                                        -> mos
res poly_resistor high_precision_poly_resistor
  high_precision_poly_p                          -> resistor
capacitor moscap                                 -> capacitor
diode                                            -> diode
vertical_npn vertical_pnp                        -> bipolar
```

Shipped as a default, **overridable and extendable in the settings file**, so a
PDK with a token nobody anticipated is a one-line user fix and not a tool
release. ~~Question Q3 settles whether the class is what the lists key on, or
whether flavor is the primary key with class as a fallback.~~ ✅ **Q3 is
settled by DD-2: the class is the primary key and a flavor entry is an optional
override that wins when present.**

> ✅ **AS BUILT, item B2, 2026-09-03 — `src/op_param_lists.tcl`.** The map above
> ships **verbatim and unextended**, as a namespace variable (`defaultmap`),
> not a `switch`; row M3 fences that structurally.
>
> **⚠ AN UNMAPPED TOKEN IS ITS OWN CLASS — identity, never `{}` and never a
> raise.** That is what makes the map an *override table* rather than a gate,
> and it is what this section's one-line-user-fix promise actually rests on.
> Measured `type=` tokens present in this tree and **not** in the map above:
> sky130 `varactor`, `npn`, `pnp`, `pwell_resistor`, `p_diffusion_resistor`,
> `n_diffusion_resistor`, `high_precision_p`; IHP `pnp` (**not**
> `vertical_pnp`), `inductor`, `esd`; and `xschem_library` uses `type=` for
> arbitrary part numbers (`2N3906`, `4001`, `12SK7`). The token space is open,
> which is why a `switch` is provably wrong here.
>
> **The default was deliberately NOT extended with that census.** A map entry
> is a *claim* that two tokens share one list; `varactor` → capacitor or `esd`
> → diode are groupings no ruling covers, and inventing them is the shape D-4
> forbids one level up. Each is a one-line `class` row in the settings file, as
> this section promises.
>
> **⚠ THE MAP IS NOT ONTO, AND MUST NOT RAISE.** IHP registers `vertical_npn`
> and **no** `vertical_pnp` although the map names both, and three of the five
> classes — `resistor`, `capacitor`, `diode` — are registered by **no PDK in
> this tree at all**. Each seeds to `{}` without raising (row S2).
>
> **⚠ `apply` GATES ON THIS MAP AND SO CANNOT REACH AN UNMAPPED TOKEN** — the
> identity fallback works for `class` and `effective` and fails for `apply`,
> leaving a stored, correct, **invisible** list. Issue **1279**, not fixed.

### 4.4 The settings file

Requirements the user stated: findable, editable by hand, shareable with
teammates, written once per project.

> ⚠ **THIS SECTION CONFLATED TWO FILES AND IS CORRECTED BY DD-3.** There are
> **two**: `src/op_param_lists.tcl` is the **implementation** (Tcl code,
> shipped, sourced, installed); the **settings file** it reads is
> `<project>/.xschem/op_param_lists.conf`, which is **data and is never
> sourced**. The `.tcl` proposal struck through below was the vulnerability, not
> the design.

~~Proposed: **`<project>/.xschem/op_param_lists.tcl`**~~ →
**`<project>/.xschem/op_param_lists.conf`**, with
`~/.xschem/op_param_lists.conf` as the user-global fallback and the project
file winning. Written with the house **write-beside-and-move** pattern (issue
0937, `ase::sim_write_conf`) so an interrupted write never truncates the file.
The window's title bar and a CIW line on every Save name the exact path, so
"where is it?" is never a question.

~~⚠ **Format.** A sourced Tcl file is arbitrary code execution, and issue 0812
already burned this tree on `subst` and paths. Question Q8.~~ ✅ **Q8 is
settled by DD-3: data, never sourced.** The premise was measured rather than
assumed — feeding a plausible shared conf to `ase::sim_load_conf`'s
`uplevel #0 [list source $path]` idiom with the payload placed **first**, under
a friendly `# share freely` header, gave `OPL_PWNED=1 marker_on_disk=1` and the
Tcl error that followed was **cosmetic: the payload had already run**. A test
row that only checked for a raise would have scored that file as safe.

#### AS BUILT — item B2, 2026-09-03

**The grammar.** Line-oriented, whitespace-delimited, **every row
self-contained** so skipping a malformed row cannot silently reassign the rows
after it. Blank lines and `#` comments skipped; a trailing `\r` trimmed
defensively; `-encoding utf-8` pinned on **both** the read and the write
channel with `-translation` left at `auto`.

```
version 1
class <type-token> <broad-class>
list  <scope> <key> <listname>
param <scope> <key> <listname> <label> <rawparam> <kind>
```

* `scope` ∈ {`class`, `flavor`}; a `flavor` key is a **cell-name glob** matched
  with `string match -nocase`, which is exactly the narrowing
  `op_annot::_matches` already performs — not a second flavor concept.
* `listname` ∈ {`annotation`, `summary`}.
* `kind` is any integer. The store is deliberately **not stricter than
  `op_annot::_wrap`**, whose default arm copies `token.c`'s *"anything but 0/1
  → `v(`"*.
* A `param` row **implicitly declares its list**, so a hand-editing user never
  has to write the `list` line. `list` exists only to express an **emptied**
  list, which stays empty rather than degrading to the PDK seed; a lost `list`
  line therefore degrades to the seed, which is the safe direction.
* Anything unrecognised — an unknown verb, a wrong field count, a non-integer
  kind, an unknown scope or list name — is **reported and skipped**, and the
  rest of the file still loads. An unknown `version` is reported and the file is
  still parsed row by row.

**⚠ THE VALUE TRIPLE IS `{label param kind}` AND ALL THREE FIELDS MUST SURVIVE
THE ROUND TRIP.** `sky130A:401` and `gf180mcuD:107` both spell it `{id id 0}`;
`ihp-sg13g2:758` spells it **`{id ids 0}`** — label `id`, param `ids`, **they
differ**. A store that keeps only the name round-trips two PDKs *perfectly* and
**silently rewrites IHP**. Any suite over this file that does not carry the IHP
shape cannot see that failure.

**⚠ FIELDS ARE SPLIT WITH `regexp -inline -all {\S+}`, NEVER `llength` /
`lindex` ON THE LINE.** Measured: `llength "mos annotation { id 0"` **raises**
`unmatched open brace in list`, so treating a teammate's line as a Tcl list
lets a stray `{` kill the reader from inside. A parser its own input can raise
in is not a strict parser.

**⚠ THE ENCODING MUST BE PINNED, THE TRANSLATION MUST NOT BE.** Measured, same
bytes, two locales: with `encoding system` = `utf-8` a line reads as 15
characters; under `LC_ALL=C`, where it is `iso8859-1`, the **same bytes** read
as 16. A file that travels between teammates is otherwise a different string
depending on the reader's locale. CRLF, by contrast, is **already** handled by
the default `auto` translation — copying the tree's `-translation binary` idiom
(`ase.tcl:1625`, `xschem.tcl:7910`) would *reintroduce* the bug it looks like
it prevents.

**The tiers.** PDK seed → `~/.xschem/op_param_lists.conf` →
`<project>/.xschem/op_param_lists.conf`, later winning. A missing file at either
tier is the ordinary first-run case, not a failure. **The win is per
`(scope, key, listname)`**, which *refines* DD-3's "per class": finer, never
coarser, so a project file customising `mos annotation` no longer silently
discards the user-global's `mos summary`. Unratified — **rule debt 1275**.

**⚠ `<project>` MEANS `[pwd]`, AND THAT WAS B2's CHOICE, NOT A RULING.** There
is no `<dir>/.xschem/` precedent in this tree. Measured: `xschem get
current_dirname` **moves under a descend**, so a Save taken while descended into
a PDK library cell would write the project file into the PDK tree and the next
read, back at the top, would not find it — reader and writer silently
disagreeing about a path the CIW names out loud. `[pwd]` is stable for a whole
session and matches `xinit.c:3500-3515`'s `./xschemrc`. Unratified — **rule debt
1273**; one proc to move.

**List 3 (`all`) is never persisted** (D-4, and §4.2 B7 already greys its
Delete). `owns` answers 0, `effective` answers `{}`, and a conf row naming it is
reported and skipped with a sentence saying why.

**Six defects measured in this implementation and NOT fixed**, all latent while
the store is unwired, all inherited by B3/B5: **1276** (the writer reports
success when the file went elsewhere), **1277** (the flavor glob wins by `lsort`
order and carries no class), **1278** (an unbounded glob from a shared file
freezes the consumer), **1279** (`apply` cannot reach an unmapped token),
**1280** (`apply` narrows the deck's `.save` cards, blanking list 2), **1281**
(Save exports the author's personal user-global settings into the team's file).

### What item B2a measured about those six, 2026-09-03 — **attempted, then reverted**

Item **B2a** implemented all six plus **1282–1284**, was green (store 39→56,
window 32→43 / 42→53, seventeen sabotage variants each red on exactly their own
rows), and was **reverted in full** after its adversary pass; the diff is
preserved at `doc/claude/op_param_batch/B2a_working_tree_REVERTED.patch`.
**The tree is still as B2 and B3 left it.** Four findings outlive the revert and
are design-of-record:

1. **DD-2's "the narrower entry wins" has no operational definition, and the
   obvious one is wrong.** B2a ranked candidate globs by **fewest `*`**. Measured
   on `sky130_fd_pr__nfet_01v8_lvt`, both insertion orders: `sky130_fd_pr__*` —
   *the whole PDK* — beats `*nfet_01v8_lvt*`, and a bare `*` beats it too. Star
   count is not narrowness. Rank by **literal (non-`*`) length**, or by
   matched-prefix specificity, and fence it with a 1-star-vs-2-star pair; every
   glob in the store suite today is 2-star, which is why the hole was invisible.

2. **The flavor key still carries no class, and the fix is still free.** §4's
   key is `{scope key listname}`, so `effective` scans flavors **across classes**
   — a MOS flavor answers a `capacitor` query whenever its glob happens to match.
   The fix adds a field to the settings grammar (**v2**, issue **1275**).
   ⚠ **It stays an edit rather than a migration only until B5 writes the first
   flavor row.** B2a's v2 also had a second, separate hole worth designing out
   up front: it emitted the key by **interpolating a Tcl list representation**
   and read it back by **splitting on whitespace**, so any glob carrying a list
   metacharacter (`a[nm]fet*`, `a\*b`) round-tripped brace-quoted and could never
   match again, with zero reports on either side.

3. **A seam refusal legitimately carries only `state`.** The answer dict at §4's
   table is documented as five keys, and the *shipped* ngspice backend populates
   all five even when refusing (`src/ase.tcl:8781`) — but nothing requires that
   of a **D-5** third-party backend, for which `{state no_raw}` is the natural
   spelling. B2a's answer-validator treated an absent `devices` key as a
   malformed answer and ran **before** the state check, so three correct refusal
   sentences became one false accusation against the backend — a regression
   against the shipped window. **The contract to write down: `devices`, `absent`
   and `nonfinite` are OPTIONAL and default to empty; only `state` is required,
   and a non-`ok` state is rendered from `state` alone.** ✅ **WRITTEN DOWN AND
   IMPLEMENTED by item B2d, 2026-09-04** — see *"AS BUILT — item B2d"* at the end
   of §4.2, and row F26, which asserts the ordering structurally.

4. **`params` is BOTH the save list and the display list, so DD-4 needs a new
   field** (issue **1285**, and it **blocks B5**). `op_annot::_cards_for`
   (`op_annot.tcl:2808`) turns `dict get $d params` into `.save` cards, and
   `op_annot::text` (`op_annot.tcl:1726`, params loop `:1741`) draws the on-sheet
   rows from that **same list**. DD-4 says `apply` writes the **union** and the
   **display narrows** — two different readings of one field, which no
   implementation can satisfy. Either `op_annot::text` prefers a new descriptor
   key over `params`, or it calls `op_param_lists::effective` directly. Both need
   `src/op_annot.tcl`, which item B2a did not own.


### What item B2a-2 measured about the same six, 2026-09-03 — **attempted, then reverted again**

Item **B2a-2** applied B2a's patch unchanged, re-fixed its three refuted fixes,
implemented ruling **DD-6**, and went green (store 39→**71**, window 32→**49** /
42→**59**, ten sabotage variants, **red-before-green on every row**, Feature A's
485/492 and 134 unmoved). It was **reverted in full** after its adversary pass;
the diff — a **superset** of B2a's — is preserved at
`doc/claude/op_param_batch/B2a-2_working_tree_REVERTED.patch` and applies clean
to `849f2231`. **The tree is still as B2 and B3 left it.** Six findings are
design-of-record, and the first two **correct this spec**:

1. **⚠ CORRECTION TO FINDING 1 ABOVE: "rank by literal (non-`*`) length" DOES
   NOT WORK EITHER, and this spec's own cited case refutes it.**
   `sky130_fd_pr__` is **14** non-wildcard characters; `nfet_01v8_lvt` is **13**.
   So literal length ranks that pair exactly the way star count did. **No
   string-intrinsic metric separates a vendor prefix from a device name** — the
   information simply is not in the two strings. B2a-2 implemented *most
   non-wildcard characters, then fewest wildcards, then lexical* and it is still
   wrong in a second way: **`?` is counted as a wildcard but its narrowing is
   never credited**, so `_flavor_order {* ?*}` puts the bare `*` first and
   `{*ab* ?ab?}` prefers the broader glob. **What the design must accept:** state
   the implemented rule in the emitted file and make the fence *generate itself
   from that sentence*, or DD-2's "narrower wins" keeps meaning whatever the last
   implementer assumed. A settings file that documents a precedence its own code
   does not implement is worse than one that says "first match wins".

2. **⚠ A v2 flavor key is a two-element list used as an ARRAY INDEX, and must be
   canonicalised at both doors.** Finding 2's quoting hole is real and B2a-2
   fixed the *bytes* (emit class and glob as two separate unquoted fields, in
   **both** the `list` row and the `param` row — keep that). But the **key
   identity** hole is separate and remained: `set_list flavor {mos a[nm]fet*} …`
   and the parser's `list`-built key are different indices, so a round trip
   loses the entry, a re-set creates a **second** `owned` slot, and `write_conf`
   then emits two conflicting rows one of which the reader silently discards.
   **v1 had no such divergence** — a one-element key quoted identically from both
   doors. **Build the key with `list` on the way in too.**

3. **Finding 3's contract is CONFIRMED and was implemented correctly.** *"only
   `state` is required, and a non-`ok` state is rendered from `state` alone"* —
   B2a-2's implementation of it survived a 22-shape adversarial matrix with no
   counterexample, including an answer that is not a dict at all. Two additions
   worth writing down: **an answer with no readable `state` is itself malformed**
   and should name the backend; and the *order* needs a **structural** fence
   (read `format_answer`'s own body), because the ordering is the half a later
   edit silently restores.

4. **Finding 4 is settled by ruling DD-6, with two conditions this spec must
   carry.** The new descriptor key is **`shown`**: `op_annot::text` prefers it
   and falls back to `params`; `_cards_for`, `_claims` and `_kind` stay on
   `params`; `apply` writes both. A descriptor declaring only `params` — all four
   shipped PDK register sites — behaves exactly as before (**I7**).

   > ⚠ **BOTH CONDITIONS THIS PARAGRAPH USED TO CARRY WERE WRONG, AND ITEM B2b
   > SHIPPED SOMETHING ELSE.** They said (a) `shown ⊆ params` is *not* true "by
   > construction", and (b) validate the key **where it enters (`register`),
   > never where it draws**. The DD-6 amendment overrules the second outright
   > (*"a key that does not parse as a list is treated as absent, full stop"*)
   > and measurement refutes both:
   >
   > * **(a) is refuted by deriving the key differently.** The premise was
   >   right — `_save_set` dedups by **label** while `set_list` still accepts a
   >   duplicate label (issue **1288**, live and B2c's to fix) — but the
   >   conclusion does not follow. `op_param_lists::_show_set` **filters the
   >   union it is about to write into `params`**, keeping a triple iff its
   >   label is among the annotation list's labels, so every element of `shown`
   >   is *literally an element of* `params` for every input, 1288 or no 1288.
   >   Copying the annotation list wholesale is what made (a) true, and that
   >   copy is exactly what B2a-2 was refuted over. Attacked, not asserted:
   >   `test_op_param_store_1245.tcl` row **D5** computes the membership under
   >   1288's own duplicate-label input.
   > * **(b) does not close the door it names.** MEASURED, two shapes:
   >   `shown` = `{broken` makes even `llength` raise `unmatched open brace in
   >   list`, but `shown` = `{id id 0} {d "x}` has `llength` **2** and raises
   >   `unmatched open quote in list` only at the `lindex` of its second row —
   >   so the `catch {llength …}` this sentence recommends leaves the second
   >   shape wide open. And a register-side *raise* would reject the whole
   >   descriptor, which is strictly worse than ignoring one key. What shipped
   >   is `op_annot::_display_rows`, the `op_annot::_matches` idiom with the
   >   catch enclosing **the `lindex` of every row**: malformed → absent → the
   >   `params` rows draw. Row **D6** registers both shapes.
   >
   > The fallback deliberately hands back **nothing**, so `params` is still
   > walked unvalidated and issue **0447**'s existing door is still open. A
   > blanket catch there would close a filed defect by accident and turn it
   > into a silently blank sheet; row **D7** and `test_op_annot`'s **K17** fence
   > it from both sides.

5. **`derived` is a THIRD consumer of the list and DD-6 does not mention it**
   (issue **1289**). `op_annot::text` builds `vars` **inside** the loop the
   ruling narrows, so a derived row whose operand was deleted renders **blank**
   though the deck still saves it. Honest under **I3**, surprising to a user.
   **Ruled on by DD-9 and implemented by item B2b**: `op_annot::text` builds
   `vars` over `params` — what the run computed — and draws over `shown`, so a
   derived row keeps its value when its operand is merely hidden. The params
   loop stays the single place that reads the raw (no new `xschem` call), and
   the narrowed rows are minted from that pass's label→value cache.

   > ⚠ **"IHP ships exactly such rows (`gm/id`, `ft`)" IS FALSE ON THIS TREE**,
   > as are issue 1289's lines 39 and 74 which say the same. MEASURED: all four
   > shipped register sites — `sky130_procs.tcl:422`, `gf180_procs.tcl:128`,
   > `sg13g2_procs.tcl:779` and `:829` (line numbers as of this edit; B2b's own
   > comment block moved each down by 15) — carry `devpath`/`devproc` + `match` +
   > `params` and nothing else; every `derived` in the three PDK files sits
   > inside the **recovery-recipe comment**, because ruling D9 removed them, and
   > `test_op_annot`'s gold table `P_DERIVEDACC` (`:904-911`) golds
   > `derived` = `{}` for all seven shipped types. DD-9's substance is
   > untouched — the fixture is **built** from that documented recipe under
   > **I5**, which is what the recipe is for, and both named rows (`gm/id` and
   > `ft`) are exercised by row **D4**.

6. **`seed` reads the field `apply` overwrites** (issue **1287**), so **D-7**'s
   "the seed comes from the PDK" is false after the first apply and `reset`
   cannot restore it — measured `{id id 0} {gm gm 1} {gds gds 1}` before,
   `{id id 0}` after apply **plus reset**. DD-6 makes the stale seed the *union*,
   i.e. silently wider. **Any acceptance row that applies and then asserts a seed
   is fencing the wrong value**; capture it in a fresh process first.

7. **`apply` now reaches the PDK seed, and therefore raises on a malformed one**
   (issue **1291**, opened by item B2b). `_save_set` / `_show_set` walk
   `effective`, which falls through to `seed` for an unowned list and returns the
   registered `params` **string, verbatim and unvalidated**. Measured A/B on
   issue 0447's own shape: HEAD `rc=0` writing a clean `params`, after B2b
   `rc=1 unmatched open brace in list` and nothing written. Latent — `apply` has
   no caller until **B5** — but **B5 must not wire a button to this** before it
   is settled. Recommended: skip the class and `_say` why, the way `apply`
   already handles a failing `register`. **Never** treat a malformed seed as
   empty: that silently drops the PDK's rows out of the union and breaks the
   union's own superset guarantee.

8. **Narrowing is one-way** (issue **1292**). Nothing removes the `shown` key,
   and `apply` deliberately `continue`s a class the user owns nothing for, so
   `reset` + `apply` leaves the sheet narrowed for the session. `shown`'s
   **absence is meaningful** — it is the only value that means "draw every row" —
   so "leave the descriptor alone" and "restore the PDK's behaviour" are
   different outcomes and only the first is reachable. **B5's Reset button
   cannot be built on `reset` + `apply` as it stands.** The honest fix is the
   pristine-descriptor stash that issue **1287** already needs.

9. **One `params` label, two rows, two answers** (issue **1293**). The
   label→value cache the narrowed rows are minted from is FIRST wins;
   `_evalrow`'s binding loop is LAST wins. Unreachable through `apply` (it dedups
   by label, which is also what makes the subset hold under **1288**), so it
   needs a hand-written descriptor or a PDK rc. Decide it with 1288, not alone.

---

### What item B2c measured about the settings file, 2026-09-03 — **attempted on DD-7/DD-8, then reverted**

Item **B2c** was the deliberately small re-do of the two issues that had been
implemented and refuted twice (**1277**, **1281**) plus two smaller ones
(**1276**, **1288**), on the driver's settled designs **DD-7** (Save is a
read-modify-write of one tier's own file) and **DD-8** (precedence is file
order; nothing is ranked). It went green everywhere and was **reverted for issue
1294**. Code preserved at
`doc/claude/op_param_batch/B2c_working_tree_REVERTED.patch`.

**What is now SETTLED and should be written into the design rather than
re-derived:**

* **§4.4's precedence is FILE ORDER.** Any earlier wording in this spec implying
  the *narrower* or *more specific* glob wins is **wrong and overruled by
  DD-8**. `"narrower"` has no defensible total order over globs — is
  `sky130_fd_pr__*` narrower than `*nfet_01v8_lvt*`? Neither contains the other.
  Two crews ranked and both shipped a bare `*` beating a specific pattern. The
  store therefore needs an **insertion-order list** (`keyorder`), because a Tcl
  array has no order and `lsort` is what both crews fell back to.
* **A flavor entry carries a CLASS.** `effective <class>` must not scan another
  class's flavors. That half of issue 1277 stands under DD-8; only the ranking
  dies. The store key stays a **three**-element list whose middle field is the
  two-element `{<class> <glob>}`, so `lindex $k 2` is still the listname.
* **The key must be canonicalised, at exactly one door.** An uncanonicalised
  two-element list used as an array index is how B2a-2 lost entries on a round
  trip. `[list [lindex $key 0] [lindex $key 1]]` is idempotent for every
  metacharacter shape measured.
* **Metacharacters need no rejection arm.** Emit the flavor's class and glob as
  **two separate unquoted fields**; nine of ten shapes already round-trip at v1
  and the corruption is *created* by interpolating a two-element key whole.
  Refusing would cost `[nm]` and `\*`, both documented `string match` features.
* **The file must document its own precedence, and the fence must be GENERATED
  FROM the emitted comment** — regexp the worked example out of a freshly
  written file and build the case it describes. Both previous crews wrote
  *"narrowest matching glob wins"* into every file they emitted **while
  implementing something else**. This is the one row that catches that, and it
  is cheap.

**⚠ THE NEW CONSTRAINT DD-7 DID NOT STATE, AND IT IS THE REASON B2c FAILED
(issue 1294):**

> **Under a read-modify-write, the writer's row classifier must be EXACTLY as
> strict as the reader's parser.**

DD-7's safety argument is *"you cannot delete a row you never parsed into a
model."* That holds **only while the writer cannot IDENTIFY a row the reader
refused to parse.** B2c's `_row_id` validated verb → scope → arity and stopped,
while `_parse_line` also ran `_valid_list`, the livelist guard and `_triple`. So
`param class mos annotation NEWROW raw ratio` was rejected by the reader,
**identified** by the writer, and deleted when its key was dirty — rc=1, zero
reports, the exact signature that killed B2a and B2a-2. Any laxity in the
classifier converts DD-7 from a preservation mechanism into a deletion
mechanism, silently.

**And the fixture that would have caught it:** a "row this build does not
understand" must be a **known verb with an unreadable field**, not an unknown
keyword. An unknown keyword is the easy case every crew writes, and it is the
one class the classifier genuinely cannot identify. B2c's row T4 used
`sometotallyfuturerow whatever 1` and passed while the promise was false.

**Two more properties of the DD-7 shape, measured and filed:**

* **Line endings are not preserved** (issue **1295**). Reusing the parser's
  preamble (`string trimright \r`) is right for a parser and wrong for a
  preserver: a teammate's CRLF file comes back all-LF with zero reports, making
  every save a whole-file diff. Either record the dominant ending and re-emit
  it, or say so in the header. An interleaved comment inside a rewritten group
  also moves.
* **An existing file never gains the header** (issue **1296**, **needs a
  ruling**). "Emit the header only into a file with no lines" is forced by DD-7
  and fenced by the same-path byte-identity row — and it collides with "the file
  documents its own precedence", because every file is a pre-existing file from
  its second save onward.

**Two API shapes that are now pinned by existing green rows** — a direct
`load_conf` must stamp its keys session-dirty while the two-tier startup `load`
must not (or the five copy-a-file rows go red or vacuous), and both
`load_conf {path {stamp 1}}` and `write_body {fp {old {}}}` must keep their
**required** arity at one argument.

---

## 5. Contracts and invariants

* **I-TIER (added by B2a-2, 2026-09-03).** **Writing one tier's settings file
  must never remove a row that the file being written declared** — not a row
  belonging to the other tier, and **not a row belonging to the tier being
  written**. B2a leaked; B2a-2 fixed the leak and then deleted a user's own
  explicit `class nmos mos` because the value happened to equal the shipped
  default (`rc=1`, **zero reports**, the file left holding `version 2` alone).
  The override-compression that skips a default-valued row is fair for a row the
  store **synthesised** and is data loss for a row the user **typed** — the store
  must tell those apart, and a fence must construct a tier conflict on a
  **default-valued** token, which is the case both attempts left invisible.
* **I-CLASSIFIER (added by B2c, 2026-09-03 — the constraint DD-7 does not
  state, and the reason B2c was reverted).** **Under a read-modify-write, the
  writer's row classifier must be exactly as strict as the reader's parser.**
  DD-7's whole safety argument is *"you cannot delete a row you never parsed
  into a model"*, and that is true only while the writer cannot **identify** a
  row the reader refused. A classifier that validates fewer gates than the
  parser will identify — and therefore rebuild, and therefore delete — precisely
  the rows the parser threw away, with `rc=1` and no report. The only shape that
  cannot drift is **one builder called by both doors** (invariant I1, one level
  down). And the fence must use a **known verb with an unreadable field**: an
  unknown keyword is the one class every classifier rejects anyway, so a fixture
  built from one passes while the promise is false.
* **I-BYTES (added by B2c).** *"Preserved verbatim"* means **bytes**, not rows.
  A preserver that reuses a parser's line-splitting preamble silently normalises
  line endings and loses a missing final newline; a merge that replaces a group
  at its first line silently moves any comment that sat inside the group. Either
  preserve them or state the transformation in the emitted header — but do not
  write *"exactly as you wrote it"* over a writer that does neither.
* **I1 (inherited).** One vector-name builder. Every consumer goes through
  `op_annot::devpath` / `op_annot::vector`. A list editor that lets the user type
  a parameter name must not become a second builder.
* **I-A.** Feature A mutates **no object**, pushes **no undo**, and never sets
  the modify flag. Toggling it must leave the `.sch` byte-identical.
* **I-B.** The RDW is **read-only with respect to the design**. It edits lists,
  never the schematic.
* **I-C.** With `annot_show & ANNOT_SHOW_OP == 0`, feature A is inert: every
  parameter draws exactly as it does today.
* **I-D.** A pruned catalogue is per **model**, never per class — §3.2's `ib`
  shows a name can be published by `show` and be unsavable, and R5 says an
  all-bogus card set suppresses the raw entirely.

### 5.1 The questions this spec owes a human

**No crew starts an item whose question is still open.** Each is recorded on the
owed ledger as a `rule` debt at the moment this spec lands.

* ~~**Q1** — what does "everything other than the name" include?~~ **RULED D-1**:
  everything. Pin labels included. Only `@name` and the OP annotation survive.
* ~~**Q2** — how is a parameter text recognised?~~ **RETIRED by D-1** — the rule
  recognises names, not parameters.
* ~~**Q5** — may bare `1`-`4` displace "toggle pin logic level"?~~ **RULED D-2**:
  yes, in the cadence profile only.
* ~~**Q7** — one instance, many primitives?~~ **RULED D-3**: print all of them.
  §3.6 shows `.options savecurrents` finds them for us.

* ~~**Q3** — do the lists key on the broad class, or on the device flavor?~~
  **RULED DD-2**: the class is the primary key; a per-flavor entry is an optional
  override that wins when present. Both kinds exist, or §4.2 B7's scope dialog
  has nothing to write. Implemented by item **B2**; ⚠ the flavor arm's
  precedence is issue **1277**.
* ~~**Q8** — what format is the settings file?~~ **RULED DD-3**: a line-oriented
  **data** file, never sourced, read by a strict parser that does no `source`,
  no `eval`, no `subst` and no substitution of any kind. Anything unrecognised is
  reported and skipped, never executed. Grammar as built in §4.4. ⚠ **The
  ruling names the tier and leaves the *word* `<project>` undefined, and does not
  state the grammar** — those are `rule` debts **1273** and **1275**, raised by
  item B2 and still owed.

Still open:

* **Q16 — is the project settings file found beside the directory xschem was
  LAUNCHED from, or beside the schematic being edited?** (added by item B2,
  2026-09-03; `rule` debt **1273**; **this is item B2's status-E question**).
  B2 shipped `[pwd]/.xschem/op_param_lists.conf` on ladder L2, because
  `xschem get current_dirname` **moves under a descend** — a Save taken inside a
  PDK library cell would write the project file into the PDK tree and the next
  read, from the top, would not find it — while `[pwd]` is stable for a whole
  session and matches `xinit.c:3500-3515`'s `./xschemrc`. **The cost of the
  choice, stated:** the file a teammate is meant to find depends on the *launch
  directory*, not on where the design lives, so cloning a project and starting
  xschem from `$HOME` silently finds no project settings at all. The rejected
  alternatives are `current_dirname` (moves) and the top-of-hierarchy
  schematic's dirname (no Tcl accessor exists, and minting one is `op_annot` /
  `scheduler` work B2 does not own). It is one proc to move, and **B3 and B5
  must both resolve the path through `op_param_lists::conf_path project`** so
  that overruling it stays one edit.
* **Q17 — does removing a parameter from the annotation list stop *drawing* it,
  or stop *saving* it?** (added by item B2, 2026-09-03; issue **1280**).
  Measured coupling, not a preference: `op_annot::_cards_for` emits one `.save`
  card per `params` row and `op_param_lists::apply` writes the annotation list
  into `params`, so a Delete on list 1 today stops the deck saving what list 2
  asks for, and those rows go permanently blank with no report (rule R1,
  invariant I3). The question belongs with the item that ships Delete — **B5**.

* **Q11 — the declutter's three status sentences** (added by item A1,
  2026-09-02; `rule` debt **1244**). `cadence::_annot_declutter_msg` mints one of
  three: *"Decluttering the schematic: a device showing operating-point values
  draws its name and those values only. Press Ctrl-Alt-6 again to bring the rest
  of its text back."* · *"Decluttering is on, but nothing changes yet: it applies
  only while operating-point values are showing. Press 6 to show them."* ·
  *"Decluttering is off. Devices draw all of their text again."* ⚠ **The first
  describes the world item A3 creates** — between A1 and A3 landing it promises a
  declutter that has not arrived. It was written at A1 anyway because A3's Files
  cell does not include `utils/annot_mode.tcl`, so the wording is written once,
  there, or never. The rejected alternative was a placeholder sharpened by A3,
  which would make A3 edit a file it does not own.
* ~~**Q12 — does the declutter reach a registered device that got NO numbers?**~~
  **ANSWERED NO by driver ruling, item A5-a, 2026-09-02.** D-6 says "only
  instances that got OP numbers", and a label with no number did not get one. The
  gate now requires at least one row carrying an actual value; a registered FET
  over a dead raw — or with no raw loaded at all — keeps every one of its texts.
  `rule` debt **`1244_A3_blank_valued_block`** stays on the user's queue as
  confirmation. See §4.1 A3b for the mechanism, the deliberate disagreement with
  `get_annot_overlay()`, and the two remaining slips (issues **1258**, **1259**).
* **Q15 — with NO results file, `Ctrl-Alt-6` now hides nothing, but the status
  line still says other device text is hidden** (added by item A5, 2026-09-02;
  `rule` debt **1257**; **this is item A5's status-E question**). The gate moved
  (A5-a) and `cadence::_annot_declutter_clause` did not — it is gated on bit 3 AND
  bit 0 only, and lives in `utils/annot_mode.tcl`, item A4's landed file, which
  item A5 does not own. Should the clause **follow the gate** (say nothing when
  nothing was hidden), or should the press be **refused outright** with "Run a
  simulation first"? Row **E6** golds the gap on purpose, so it stays visible.
  ⚠ **ANSWERED 2026-09-02 by the DRIVER, and NOT YET LANDED.** The ruling is
  *"the clause follows the gate — emitted only when something was actually
  hidden"*, and the press is **not** refused (a mode you cannot arm before
  simulating would be worse than one that says it is waiting): three states,
  three sentences. Item **A7-a** implemented exactly that, was **refuted** by its
  own adversary pass and **reverted** — see issue **1270** and the A7 entry in
  `PLAN.md`. So Q15 is no longer an open *question*; it is unlanded *work*, and
  row **E6** still golds the gap.
  ⚠ **AND THE RULING'S OWN PREMISE IS OFF BY ONE: THERE ARE FOUR STATES.**
  Measured by A7: (1) no raw (`raw loaded` -1); (2) **dead raw** — loads and
  annotates, publishes no matching vector; (3) valued raw; (4) valued raw whose
  only non-`@name` text was **already invisible** (`hide=instance` / `hide=true`).
  States 2 and 4 both hide nothing while every mask-shaped and `_annotated`-shaped
  test says otherwise, and state 4 is what refuted A7. A re-run must drive all
  four; three sentences still suffice, because 2 and 4 both take the armed one.
* **Q14 — the clause the OTHER four chords now carry** (added by item A4,
  2026-09-02; `rule` debt **1251**; **this is item A4's status-E question**).
  After a `Ctrl-Alt-6`, every `6` / `Alt-6` / `Alt-Shift-6` press appends
  *" Decluttering is on, so other device text is hidden."* — 52 bytes, whenever
  bit 3 **and** bit 0 are both set, **in every state, including a press that
  found no results file**, because the sheet is stripped there too (§4.1, item A4's
  landing note). `Ctrl-Alt-6` already said the long version at the moment the bit
  was armed (Q11). Is that the right reminder on the other keys, should it be
  shorter, should it repeat the way out, or should the other keys stay silent?
  ⚠ **The 255-byte status bar is why it is not longer**, and the three rejected
  wordings are costed in issue **1251**: `" Device parameters are hidden."` (30 B)
  names a class **D-1 explicitly rejected**; the precise per-device form (98 B)
  puts mask 3 + `loaded` over the wall at this suite's own path; the
  remedy-bearing form (114 B) is eaten by the elision exactly where it would be
  needed. A1's three sentences (Q11) are **not** reworded — this composes with
  them.
* **Q13 — after item A3's 1247 fix, may a declutter press adopt an rc-armed
  mask?** (`rule` debt **`1244_A3_rc_armed_stamp`**). `annot_show_set()` now
  declines to stamp `xctx->annot_root` when the write moves the declutter bit
  **and nothing else**, which is what makes a net-zero pair of presses a true
  no-op again. The consequence: pressing `6` or `Alt-6` on a sheet whose
  `annot_show` came from `xschemrc` leaves it **rc-armed** — a later `File > Open`
  does *not* clear it — where today that press adopts the mask. Every other write,
  including one that changes nothing, still stamps, so issue **0688** is whole
  (row A26).
* **Q6 — the dump header.** `M2B:/xdut/xbg/xamp1` as asked. ⚠ The tree has three
  spellings and **none is that one**: `xschem get sch_path` gives
  `.xdut.xbg.xamp1.` (leading *and* trailing dot); `xschem get sim_sch_path`
  gives `xdut.xbg.xamp1.` and additionally strips every level above where the
  raw was loaded; the raw's own is `@m.x1.x1.xm2.msky130_fd_pr__nfet_01v8`.
  **Proposed default, to be confirmed on screen rather than in prose:** mint the
  Cadence spelling as asked — instance name, colon, then the instance path
  slash-separated with the leading and trailing dots stripped — and put the
  raw's own device path on a second, dimmer line, because that is the string a
  user pastes into ngspice. Recorded as a `look` debt, not a blocker.
  ✅ **IMPLEMENTED AS THE DEFAULT by item B3, 2026-09-03 — NOT re-litigated.**
  `rdw::_cadence_path` is `string map {. /} [string trim $schpath .]`, kept
  rooted, so `.xdut.xbg.xamp1.` → `M2B:/xdut/xbg/xamp1`; line 2 is
  `op_annot::devpath`'s own string, dimmed (`option get . disabledForeground`).
  ⚠ **At the top sheet `sch_path` is `.` and the trim yields the empty string, so
  the header degenerates to `M1:/`** — an edge nobody has ruled, chosen by ladder
  L2 to keep the header's shape constant with depth (two pastes from different
  sheets still align), and now locked by suite rows `H1`/`H2` so it cannot drift
  silently. `sim_sch_path` was rejected: it strips every level above where the
  raw was loaded, so the header would stop matching the schematic on screen.
  **The `look` debt stays open — it is the spelling that needs eyes, and B3's own
  `look` debt points at it rather than duplicating it.**
* **Q10 — does the RDW work on the ordinary post-run desktop?** ✅ **ANSWERED
  YES, MEASURED by item B1 with real ngspice, 2026-09-03.** `ngspice -b -r
  <raw> <deck>` on a deck carrying `.op` then `.tran` writes **one** file holding
  **two** plots (`Operating Point`, 1 point; then `Transient Analysis`).
  `xschem raw read <f>` with no `sim_type` argument lands on the **op** plot,
  `xschem annotate_op <f> 0` publishes (`raw annot` = `0 0 -1`), and
  `raw value <v> -1` returns real device-parameter numbers — so `update_op()`'s
  op/dc guard (`src/save.c`, and note the guard is **not** at the `:3680` this
  line quotes) is never reached with `sim_type=tran` on that path. **The RDW is
  reachable after an ordinary OP+TRAN run.** Two measured caveats: on the
  `.control` + `write` writer the second `write` **overwrites** the first without
  `set appendwrite`; and once the tran slot is read it becomes **current**, at
  which point `raw list` and `raw value` answer about the transient — the seam
  reads whatever slot is current and chooses none. B3's suite should now **assert**
  this rather than ask it. Still entangled with the open `rule` debts **1240** and
  **1243**.
  ✅ **ASSERTED by item B3, 2026-09-03** — suite row `Q1`: one raw holding an
  `Operating Point` plot **then** a `Transient Analysis` plot, read with
  `annotate_op`, gives `sim_type=op` and renders its six real numbers with the
  honesty line. It is a check now, not a question. ⚠ **But the adjacent state is
  a live defect:** the allow-list is `{op dc}`, so a **dc** slot answers `ok` and
  the window calls it an operating point — issue **1282**. ✅ **FIXED by item
  B2d, 2026-09-04** (rows F14, F15, Q6) — and it brought a new question with it.

* **Q18 — is the analysis sentence's wording right?** (added by item **B2d**,
  2026-09-04; `rule` debt `1282_analysis_sentence_wording`; **this is item B2d's
  status-E question**). Ruling **DD-5** decided that a `dc` answer is still
  rendered and that the block names the analysis, and that decision is
  implemented unchanged. **Its quoted specimen wording is refused, on a
  measurement**: `src/save.c:1073` and `:1120` both rename a MULTI-POINT
  `Operating Point` plot's `sim_type` to `dc`, so *"these numbers come from the
  `dc` analysis at its first point, not from a standalone operating point"*
  would tell a user who ran nothing but an operating point that they ran a
  sweep — reproduced on a real three-point raw by row Q6. What ships instead:
  *"These numbers come from the first point of results xschem reports as a `dc`
  analysis, not as a standalone operating point. A `dc` sweep's first point is
  one sweep step, and xschem also reports a multi-point operating point as
  `dc`."* It names what the loaded results **call themselves**, which is true in
  both cases and asserts nothing stronger. **Accept that wording, or give
  different words?** ⚠ Four more sentences went on screen with it and no ruling
  covers their wording either (`rule` debt `1284_four_new_sentences`): the
  malformed-answer sentence naming the backend, the two split simulator
  refusals, and `(no value reported)`.

---

## 6. Landmines

1. ~~**`Ctrl-Alt-6` currently fires `Alt-6`** and switches node voltages on
   (§4.4/A4).~~ **DISARMED by item A1, 2026-09-02** — bound explicitly with
   `break`, and rows D2/D3/S1/S2/S3/T4 of
   `tests/headless/test_annot_declutter_1244.tcl` hold it disarmed, by dispatch
   as well as by mask. Kept here because the *class* of trap is live for every
   future chord in this file: **a modifier chord that is not spelled out fires
   its subset**, silently and plausibly.
2. **A new `src/*.tcl` needs two `Makefile.in` lines and a `./configure` re-run.**
   In-tree it works either way; installed, the binary segfaults at startup
   (issue 0424). `grep -c rdw.tcl src/Makefile` must be 2.
3. **`show`'s catalogue is a superset of the savable set** (§3.2). Prune by
   `dims=0`, never trust the names.
4. **Over-emission destroys the raw.** R5: good cards plus one bogus card give a
   silent zero column; *all* cards bogus and ngspice writes no raw at all.
5. **Modal dialogs hang headless suites** (issue 0803). The scope dialog needs a
   test-drivable path from the first commit, not retrofitted.
6. **The three PDK `cadence_style_rc` files each `source` the one in `src/`.**
   Editing three files creates exactly the silent drift this tree forbids.
7. **`results::` is taken.** Use `rdw::`.
8. **`annot_show` is an integer.** `xschem set annot_show true` reads back 0.
9. **`textwindow` is the WRONG precedent for the RDW.** `xschem.tcl:13567-13615`
   takes a **filename**, reads it into an **editable** `text` widget (no
   `-state disabled`), and its Save button writes back to that same file. An RDW
   built on it would offer to save the dump over a design file. The RDW needs a
   string-backed, read-only, `-exportselection` pane of its own.
10. ~~**The three name spellings are three, not one.**~~ **DISARMED by item A3,
    2026-09-02** — `annot_name_token()` is exported and all three render loops
    call it; zero `strcmp(…,"@symname")` keep-name pairs remain (row **A19**), row
    **N14** flipped to `{1 1 1 1 1}`, and a census of 44,177 `T` records puts the
    blast radius at exactly 69 symbols. Kept in full because the *class* of trap —
    **four hand-written copies of one predicate, drifting silently** — is what
    invariant I1 exists for, and because the paragraph below is the measurement.
    `@name`, `@symname` and
    `@spiceprefix@name`. `draw.c:873`'s shipped keep-name test missed the third
    (81 records, including gf180's FETs and `devices/nmos4.sym`). **FILED as
    issue 1249** by item A2, which reproduced it *behaviourally* — at
    `hide_symbols=2` on `cmos_inv.sch` the render keeps `R1 V1 Vmeas` and loses
    `M1 M2` — and did **not** fix it (three files A2 does not own; three
    byte-identical copies at `draw.c:873`, `svgdraw.c:928`, `psprint.c:1210`, so
    screen, SVG and PDF lose the name together). Row **N14** of
    `test_annot_declutter_1244.tcl` pins the defect; whoever fixes it flips that
    row. `annot_name_token()` **is** the right predicate — export it rather than
    writing a fourth copy (invariant I1). Item A3 touches all three files.
11. **A zero-length vector is not a zero.** `savecurrents` publishes `ig`/`is`/
    `ib` as `0 long` on sky130 FETs, and an explicit `save …[ib]` card gives a
    `dims=0` column of `0.0`. Both are *absent*.
    ⚠ **CORRECTED 2026-09-02 by item A6, measured against ngspice 45.2 — this
    landmine used to end "and neither says so on stderr", and that is false in
    both directions.** There are **three** flavours and they behave differently:
    * **`dims=0`** — the `.control` + `write` path. The **file** says so, in the
      third tab-separated field of the `Variables:` line, and that is the only
      in-file carrier. Item A6-b parses it (`raw_line_dims_zero()`) and publishes
      it through `raw_vector_absent()`; `xschem raw value <v> -1` then answers
      **empty** and invariant I3 is satisfied.
    * **no marker at all** — the batch `-r <file>` writer, which is what
      `src/xschem.tcl:3854` runs. The same unsatisfiable card arrives as an
      **ordinary `current` column of 0.0**, byte-identical to a measured zero;
      ngspice warns `unrecognized variable` on **stderr**, which xschem never
      reads. **This flavour is not closed** — issue **1263** — so a
      `savecurrents` run through the shipped simulate command still declutters.
    * **genuinely zero-LENGTH** — `write` refuses the **whole plot**
      (`no writable vector found`) and produces **no raw at all**, in one form
      segfaulting. So this state never reaches xschem as a vector — issue
      **1264**, and it is landmine 12's shape reached through an *option line*
      rather than a wildcard `save` card.
    A **real computed 0.0** is none of these and must still render `0`: a
    transistor that is off has `id = 0` and that is a measurement, not a hole.
    Collapsing absent and zero in **either** direction is a defect.
12. **`save m`, `save @m*[*]` and friends do not merely fail — they destroy the
    plot.** A card that matches nothing takes the whole operating point with it
    (R5's all-bogus case), so an over-eager wildcard is worse than no wildcard.
13. **The declutter's per-instance gate must never call `get_annot_overlay()`**
    (item A3). That function does `++annot_overlay_count`, and row **O13** of
    `test_op_annot.tcl` golds the delta exactly — calling it once per text per
    instance per frame both reds O13 and destroys the only seam an automated check
    has on the overlay. Read the factored `annot_overlay_gate()` +
    `annot_overlay_cached_text()` instead, and keep the `annot_overlay_busy`
    guard: filling the cache tclevals `::op_annot::text`, which reaches
    `xschem translate` → `prepare_netlist_structs()` — the same machinery
    `symbol_bbox()` drives, and `symbol_bbox()` is one of the gate's own callers.
14. **`symbol_bbox()` is BOTH a declutter consumer and a click-target producer**
    (item A3). It has **39** callers across eight files; `annot_overlay_sync()`
    has **four**. So the gate can be stale exactly where the pick is computed
    (issue **1252**) — the same staleness shape as issue 0453. Any item that picks
    an instance by coordinate must refresh the bboxes first.
    ⚠ **UPDATED 2026-09-02 by item A6-c.** The repair went **inside the callee**:
    `symbol_bbox()`'s own prologue pulls the mask (`annot_show_pull_cache()`,
    without the 0688 backstop, which can *clear* the mask and must not ride a
    geometry verb) and, **behind the declutter bit**, syncs the overlay epoch. All
    39 callers are therefore fresh, and issue 1252's rejection of exactly this
    option is **deliberately reversed**, with both of its reasons answered:
    re-entrancy is already closed by `annot_overlay_busy`, and the bit-3 prefilter
    makes the sync a measured no-op whenever the declutter is unarmed.
    **The "refresh the bboxes first" instruction still stands anyway**, because
    `xschem annotate_op` and `xschem raw clear` move the gate's answer while
    calling `symbol_bbox()` not at all — issue **1266**.
15. **"Did the declutter hide anything?" cannot be answered by the mask, by
    `op_annot::_annotated`, or by the rung's `return 1`** (item A7, issue
    **1270**). The mask stopped meaning "the sheet is decluttered" when the value
    gate landed. `_annotated` answers **1** on a dead raw — one that loads and
    annotates but publishes no matching vector — exactly as on a valued one, and
    `cadence::annot_mode`'s `state` reads `live` there too, so **no Tcl-visible
    signal separates the states**. A C measurement is required. But the obvious
    place to take it is wrong: `text_hidden_core()`'s declutter `return 1` sits
    **above** the `show_hidden_texts` / `HIDE_TEXT` / `HIDE_TEXT_INSTANTIATED`
    arms, so a counter bumped there answers *"the rung said hide first"*, not
    *"this text would otherwise have been drawn"* — and on any annotated device
    whose only non-`@name` text is already `hide=instance` (**57 shipped
    `xschem_library/devices/*.sym`**) the sheet is byte-identical at mask 1 and
    mask 9 while all three status producers claim a declutter. Count it only when
    the tail below **would have returned 0** — and remember the `show_hidden_texts`
    arm, because both Op-Annotate menu bodies turn that switch **on** one line
    before writing the mask, so there the rung really does take the text away.
    ⚠ A related trap for the *reader* of such a counter: the delta is moved by
    `update_all_sym_bboxes` **alone** (measured: bbox-only 1, redraw-only 1), so
    it is a **geometry** answer, not a screen answer. Today they agree.


16. **A SENTENCE THAT INTERPOLATES SOMETHING A BACKEND SENT IS A LINE
    INJECTOR** (item B2d, 2026-09-04). `rdw::block_text` joins a block's entries
    with a newline, so one entry containing a newline makes the block, the paste
    text and the Tk pane report **three different line counts** — measured 4, 5 and
    7 on a single answer whose every data bucket was empty. The vehicle was the
    smallest legal-looking thing in the whole seam: `_state_sentence`'s default arm
    echoing the backend's own `state` string. The result on the clipboard is two
    correctly indented, correctly formatted operating-point rows that no bucket ever
    carried, indistinguishable from measured ones — invariant **I3**'s harm, one
    level up from a number. **The fix is the emit point, not the sentence**
    (`rdw::_line`), because wrapping each fragment leaves the next author a tenth
    site. ⚠ And note where the hole was: between two rows that each fenced half of
    it. F20 covers newline/CR/tab in a value, a parameter name and a device name;
    F25 covers the unrecognised-state arm — with a newline-free word. **Two green
    rows crossing a class is not the class fenced.**

---

## 7. Out of scope, named so it is not assumed

* Transient or AC values in the RDW. Operating point only, as the user said.
* Node voltages and currents in the RDW — instance OP info only.
* Editing the PDK's shipped symbols to carry `hide=param` (unless Q2 chooses
  A3-b, in which case it becomes its own item).
* Any change to what `6` / `Alt-6` / `Ctrl-6` do.
* Printing from the RDW, or writing a review document.

---

## 8. Verification

* A headless suite per feature. ⚠ **"Registered" means the glob, not a list** —
  corrected by item A1: `full_audit.sh:393` is
  `ls "$HERE"/test_*.tcl | sort`, so a suite named `test_*.tcl` registers itself
  and **`full_audit.sh` must not be edited**. Its three named lists
  (`nogui_tests`, `logdir_tests`, `nolog_tests`) are opt-ins for special run
  modes, and a chord suite on `nogui_tests` loses X and cannot `bind` or
  `event generate` at all. The consequence: **every new suite moves the audit
  denominator**, so the acceptance diff is by name and status, never by count.
* Feature A: a check that the `.sch` bytes are unchanged across a toggle; a
  check per PDK that the right texts vanish and `@name` survives; a check that
  with `annot_show` bit0 clear the declutter bit changes nothing.
* Feature B: fixture-driven, with a fabricated raw so the suite needs no ngspice;
  the refusal paths (multi-select, unregistered type, no raw) each get a row.
* The chord matrix: `6`, `Ctrl-6`, `Alt-6`, `Ctrl-Alt-6`, `Alt-Shift-6` fired by
  `event generate`, each asserting the mask it is supposed to produce — this is
  the guard for landmine 1.
* Baseline is a **name+status diff** against the current audit, never a count.
  `run_regression.tcl` **solo** (issue 0990).
* A `look` debt for every pixel deliverable; a `rule` debt for every §5.1
  question until the user clears it.
