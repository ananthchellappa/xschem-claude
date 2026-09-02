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
>   §5.1 below.
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

**A3b. What the gate actually tests — and where it departs from D-6's words.**
Shipped as `annot_instance_annotated(n)` = `get_annot_overlay()`'s own
precondition chain (factored out as `annot_overlay_gate(n)` so the two readers
cannot drift, **I1**) **plus** a non-blank `annot_overlay_cached_text(n)`. It must
**not** call `get_annot_overlay()` itself: that function does
`++annot_overlay_count` and row **O13** of `test_op_annot.tcl` golds the delta
exactly, so one call per text per instance per frame would both red O13 and
destroy the only seam an automated check has on the overlay.

⚠ **`op_annot::text` emits blank-VALUED rows when the raw publishes nothing for a
registered device.** Measured, twice, first-hand: with a descriptor registered and
a raw loaded whose vectors do not resolve, `op_annot::text M1` returns
`"zid =\nzgm =\n"` — non-blank — while a descriptor-less `R1` returns `{}`. So the
gate reads *"this device has a descriptor whose `match`/`devpath` resolve and which
declares at least one row"*, **not** *"numbers arrived"*. D-6's words are "only
instances that got OP numbers". Subcircuits and descriptor-less devices are
untouched, which is what D-6 asks for; a **registered device over a dead or partial
raw is decluttered while showing empty rows**, which D-6's words do not cover — and
per measured rule **R1** (`gm`/`gds`/`vth` exist only if the deck saved them
explicitly) that is common rather than exotic. The gate follows the **pixels** — it
is exactly what the overlay already paints, and the alternative needs a second
parser of the block's format (two builders, against **I1**). `rule` debt
**`1244_A3_blank_valued_block`**; **it is item A3's status-E question.**

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
>   from the pre-annotate cache. The other **38** `symbol_bbox()` callers still run
>   outside any overlay sync: issue **1252**.
> * ⚠ **The PDK symbols' OWN operating-point texts carry `hide=true`** (3 in
>   sky130 `nfet_01v8`, 2 in gf180 `nfet_03v3`, 0 in IHP `sg13_lv_nmos`), so they
>   are **not** annotation-classed, and once *View > Show hidden texts* is on —
>   the state both menu bodies create — **the rung hides them**, replaced by the
>   overlay block. Intended trade, unstated anywhere until now. `rule` debt
>   `1244_A3_hide_true_op_texts`.
> * ⚠ **P6 pin-owned pin names are NOT reached** (issue **1253**): they are drawn
>   by a **fourth** pass gated by `pin_name_visible()`, not by `text_hidden()`, so
>   a pin spelling `show_pinname=true` keeps its name on a fully decluttered
>   device — measured first-hand. Inert on all three PDK acceptance devices (four
>   pins each, all `false`); live for the 2,968 shipped `true` records. D-1 says
>   pin labels are in scope, so this is a gap in the *implementation*, not in the
>   ruling.
> * **The 42 one-record `name+parameter` symbols are spared on this tree by the
>   gate**, not by luck: every shipped PDK descriptor is `match`-narrowed and
>   registers only `nmos`/`pmos` (+ IHP `vertical_npn`), so none of the 42 resolves
>   a devpath. Live only for a user's own `op_annot::register`.
> * **Issue 1249 was fixed as this section demanded**, by exporting
>   `annot_name_token()` — four copies of one predicate become one builder (**I1**).
>   Censused over 44,177 `T` records in five libraries: **exactly 69 symbols**
>   render differently, all of them the `@spiceprefix@name` spelling, and zero
>   because of the whitespace trim. The repair is **ungated by `annot_show`**.

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

Every Delete and Add raises a **scope dialog**: *this device flavor only*, or
*every device of this broad class*. That maps onto the descriptor's `match`
glob (§2.1) — narrow writes a flavor-specific entry, broad writes the class
entry. ⚠ Modal dialogs are a known headless-harness hazard (issue 0803: a modal
dialog hangs any suite under X); the dialog must be drivable by the tests
without a human.

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
release. Question Q3 settles whether the class is what the lists key on, or
whether flavor is the primary key with class as a fallback.

### 4.4 The settings file

Requirements the user stated: findable, editable by hand, shareable with
teammates, written once per project.

Proposed: **`<project>/.xschem/op_param_lists.tcl`**, with
`~/.xschem/op_param_lists.tcl` as the user-global fallback and the project file
winning. Written with the house **write-beside-and-move** pattern (issue 0937,
`ase::sim_write_conf`) so an interrupted write never truncates the file. The
window's title bar and a CIW line on every Save name the exact path, so
"where is it?" is never a question.

⚠ **Format.** A sourced Tcl file is arbitrary code execution, and issue 0812
already burned this tree on `subst` and paths. Question Q8.

---

## 5. Contracts and invariants

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

Still open:

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
* **Q12 — does the declutter reach a registered device that got NO numbers?**
  (added by item A3, 2026-09-02; `rule` debt **`1244_A3_blank_valued_block`**;
  **this is item A3's status-E question**). D-6 says "only instances that got OP
  numbers". The shipped gate is "the descriptor resolves and declares at least one
  row", because that is exactly what the overlay paints — so a registered FET over
  a dead or partial raw is decluttered **while its block shows `zid =` with no
  number**. Per measured rule **R1** that is common, not exotic. The alternative
  needs a second parser of the block's format (two builders, against **I1**) and
  would let a sheet show an OP block over parameters it had decided not to hide.
  See §4.1 A3b.
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
* **Q10 — does the RDW work on the ordinary post-run desktop?** `update_op()`
  refuses to publish when `sim_type` is not `op`/`dc` (`save.c:3680`). The
  annotation nevertheless works with OP **and** TRAN enabled, because the raw
  registry holds a separate op slot — that is the configuration issue 1243 was
  measured in. **To be verified, not assumed**, as the first check of the RDW's
  suite. Entangled with the open `rule` debts **1240** and **1243**.

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
    `dims=0` column of `0.0`. Both are *absent*, and neither says so on stderr.
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
