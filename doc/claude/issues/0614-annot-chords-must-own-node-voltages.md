# 0614 — the three OP chords must own the node voltages too (`Ctrl-6` off-ramp, `6` vs `Alt-6`)

STATUS: **IMPLEMENTED 2026-08-22, status E** — see the implementation section at
the bottom. The ruling is satisfied and the suites are green; the one unratified
question it exposed is issue **0621**, and three measured-not-fixed residuals are
**0622**, **0623**, **0624**. Originally: **RULED by the user 2026-08-22.** Supersedes the open decision in
[0613](0613-ctrl-6-does-not-clear-node-voltages-so-everything-off-is-false.md), which measured the defect and listed
three options. The user picked the first: **the chords take authority over the
node voltages.** Related: 0457 (the mask's menu controls), 0615 (colour), S7/S8.

---

## The ruling, verbatim — READ THIS, IT IS NOT THE OBVIOUS READING

First message (2026-08-22):

> "Fix Ctrl-6 - yes - must clear node voltage display and the Alt-6 and 6 doing
> the same thing issue. 6 is for OP info."

Second message, **correcting a wrong first reading of the above**:

> "No, 6 for OP info will NOT suppress node-voltages. 6 for OP info is ONLY to
> ADD device OP info to the annotation. ... Alt-6 is ONLY to ADD node voltage
> display to the annotation."

So the three chords are **two additive setters and one clear-all**, not a
three-state cascade:

| chord | effect on the mask | on screen |
|---|---|---|
| `6` | `annot_show |= ANNOT_SHOW_OP` — **bit1 untouched** | adds device OP blocks |
| `Alt-6` | `annot_show |= ANNOT_SHOW_VOLTAGE` — **bit0 untouched** | adds node voltages |
| `Ctrl-6` | `annot_show = 0` | clears **both** |

Consequences a reader will get wrong if they skim:

- **`6` never turns anything off.** Pressing it with voltages already on leaves
  them on. It is not a toggle either — pressing it twice leaves OP info on.
  `Ctrl-6` is the *only* off switch.
- **`Alt-6` is no longer mask 3.** Today `cadence::_annot_mask` returns 3 for
  `opvolt`, i.e. it force-sets bit0 as well. Under the ruling it must set bit1
  and leave bit0 exactly as it found it. Pressing `Alt-6` from a clean start
  therefore gives **mask 2** — voltages alone, no OP blocks — which is a state
  the chords could not reach before.
- Both chords still need the raw loaded, and still SAY on the held status line
  what happened. That behaviour is unchanged.
- The `cadence_style_rc:283-285` comment block is now **wrong in two of its three
  lines** and must be rewritten with the table above, not patched. *(ANCHOR
  CORRECTED on implementation: the table is at `:286-288`, drifted by 3. Done.)*

## Why it is broken today (measured, 0613)

`annot_show` gates `hide=op` / `hide=voltage` text records through
`text_hidden()` (`src/actions.c`, `src/xschem.h:397-401`). The node voltages and
branch currents come from a **different** mechanism — XSCHEM's native OP
back-annotation, symbol texts carrying `@spice_get_voltage` /
`@spice_get_current*` tokens resolved in `token.c:4821/4912/4989` — and
**no shipped symbol carries `hide=voltage`**, so bit1 has nothing to gate.

Measured on `bandgap_opamp` (13 FETs, 15.8 MB tran raw, cursor2 at 20 µs):

| mask | chord | render bytes | on screen |
|---|---|---|---|
| 1 | `6` | 169897 | blocks **+** voltages |
| 3 | `Alt-6` | 169897 | **byte-identical to mask 1** |
| 0 | `Ctrl-6` | 114394 | blocks gone, **voltages remain** |

Surviving `Ctrl-6`: `1.8` VCC, `0.8696` ADJ, `1.461` SP, `0.5328` G1, `0.4967`
G2, `1.185` DIFFOUT, and branch currents `4.854u 2.43u 2.424u 12.83u 7.25u
905.8p 413.8n`.

The user hit the same thing again unprompted in the second session:
"node voltages are already displayed without asking for them."

## Two ways to give bit1 something to gate — and the recommended one

**Option A — tag the shipped symbols.** Add `hide=voltage` to the voltage/current
texts in `xschem_library/devices/*.sym`. Rejected as the primary mechanism: it
edits shipped libraries, it is a per-symbol opt-in a third-party or user PDK
symbol will not have, and every such symbol then permanently escapes the switch.

**Option B — classify by content (RECOMMENDED).** Treat a text whose *unresolved*
token is `@spice_get_voltage`, `@spice_get_voltage(...)`, `@spice_get_current`,
`@spice_get_current<n>` or `@spice_get_current_<param>(...)` as class VOLTAGE at
the visibility test, exactly as if it carried `hide=voltage`. One predicate,
covers every symbol in every library including ones not yet written, no library
churn. Decision ladder **L2**: smallest blast radius, least surprising.

Whichever is implemented, keep the explicit `hide=voltage` token working (I7) —
Option B *adds* an implicit class, it does not replace the explicit one.

## Landmines

- **Invariant I7.** A user with no raw loaded and no annotation must see these
  symbols exactly as before. `annot_show` starts at 0, so a content-based class
  would blank `@spice_get_voltage` texts that today render as the literal token
  or as blank when unresolved — **check what they render as with no raw loaded
  and preserve it.** This is the one way Option B can regress a non-annotating user.
- The nine copy-pasted visibility tests are already unified behind `text_hidden()`
  (S7): `draw.c:872,1135,10270,10650` `svgdraw.c:927,1330` `psprint.c:1209,1702`
  `select.c:709`. Do not add a tenth test elsewhere — extend the predicate.
  *(COUNT CORRECTED on implementation: there are **TEN** call sites, not nine —
  the tenth is `actions.c:1475`, the S9b overlay's own D2 mask gate, which passes
  a literal `HIDE_TEXT_OP` rather than a text's flags and must NOT get a colour
  override. `actions.c:4796` (`calc_drawing_bbox`) is geometry-only. No eleventh
  was added.)*
- `select.c:709` means the class also decides **selectability**. Turning voltages
  off must not make a text unselectable in a way that strands it.
- `Ctrl-6` must keep ending in `break` (it displaces `Ctrl+<digit>` = select layer,
  `callback.c:7272`). *(ANCHOR CORRECTED: `case '6'` is `callback.c:7354`; `:7272`
  is `handle_key_press`'s signature line. All three binds were left untouched and
  still end in `break`.)*

## Acceptance

- From `Ctrl-6` (mask 0) with a raw loaded, four renders with four distinct byte
  counts: `Ctrl-6` -> nothing; `6` -> blocks only; `Alt-6` -> blocks **and**
  voltages (bit0 survived); `Ctrl-6` then `Alt-6` -> **voltages only, no blocks**
  (mask 2 — the state the old cascade could not produce, and the sharpest check
  that `Alt-6` stopped force-setting bit0).
- `6` pressed twice in a row leaves the mask unchanged; `6` pressed while
  voltages are on does not remove them.
- The 0457(b) View-menu pair (`::annot_show_op` / `::annot_show_voltage`) drives
  the same three states — unticking "node voltages" hides them.
- With **no** raw loaded and `annot_show` 0, every existing schematic renders
  byte-identically to before the change (I7 regression guard).

---

# ✅ IMPLEMENTED 2026-08-22 — with 0615, in ONE pass, one predicate, one draw pass

Committed on branch `annotate`. Status **E** — the implementation is landed and
green; the one unratified question it exposed is issue
[0621](0621-annot-show-default-decides-if-stock-live-backannotation-starts-on.md).

## BEFORE (Measure agent, verbatim transcript on its own PDK-neutral fixture)

```
annot_show 0 :  4533 bytes
                 1.234|#ff7777
                 7.891u|#00ffcc
annot_show 1 :  5123 bytes
                 gm = 765u|#ff7777
annot_show 2 :  4533 bytes
annot_show 3 :  5123 bytes
annot_show 0 vs annot_show 2 : BYTE-IDENTICAL
annot_show 1 vs annot_show 3 : BYTE-IDENTICAL
  _annot_mask opvolt -> 3
  after cadence::annot_mode opvolt -> annot_show = 3   (ruling wants 2)
  `6` while voltages are ON (mask 2): -> 1   (ruling wants 3, it REMOVES them)
xschem get annot_voltage_layer -> rc=0 result=''
xschem set annot_voltage_layer 9 -> rc=0 result=''
```

Two distinct renders where the ruling needs four; `Ctrl-6` still painting every
node voltage — the same `169897 == 169897` shape the user measured on
`bandgap_opamp`.

## AFTER — driven by the REAL chords (`cadence::annot_mode`), not `xschem set`

```
Ctrl-6            -> annot_show 0, 4298 bytes, texts {VOUT Vm1 M1}   (nothing)
6                 -> annot_show 1, 4888 bytes, adds `id =` `gm = 765u`
Alt-6             -> annot_show 3, 5123 bytes, adds `1.234` and `7.891u`, bit0 SURVIVED
Ctrl-6 then Alt-6 -> annot_show 2, 4533 bytes, `1.234` + `7.891u`, NO block
distinct renders = 4 (want 4)
6 twice from 0     -> 1 then 1        (never a toggle)
Alt-6 then 6 from 0-> 2 then 3        (`6` did NOT remove the voltages)
status after that pair : "OP annotation ON (device OP info + node voltages) -- raw already loaded"
status after Ctrl-6    : "OP annotation OFF"
```

## What landed, in four pieces

**(A) The predicate.** `src/actions.c` gains `annot_content_class()` — a
whole-string classifier over **six** spellings — called from `set_text_flags()`
**outside** the `if(t->prop_ptr)` block and **only** when `annot_class_free()`
says the `hide=` chain set no bit. It sets one of two NEW `xText.flags` bits,
`TEXT_ANNOT_VOLTAGE` (256) / `TEXT_ANNOT_CURRENT` (512). `text_hidden()` gains
**one** leading branch and **no tenth visibility site exists anywhere**:

```c
if(flags & (TEXT_ANNOT_VOLTAGE|TEXT_ANNOT_CURRENT)) {
  if(ctx == TEXT_CTX_INSTANCE || (flags & TEXT_FLOATER))
    return (xctx->annot_show & ANNOT_SHOW_VOLTAGE) ? 0 : 1;
}
```

All ten existing callers inherit it — including `select.c:709`, which is what
shrinks the `lab_pin` bbox back (row U23), and `actions.c:1475`, the S9b
overlay's own gate, which passes a literal `HIDE_TEXT_OP` and falls through
untouched.

**(B) The colour (0615).** New per-context `xctx->annot_voltage_layer`, default
**9**, MIRRORED IN TCL, pulled inside `annot_show_sync_cache()` with `tclgetvar()`
so all **eight** bulk-evaluation entry points refresh it. New
`int annot_text_layer(int flags, int ctx)` called at **six** sites, two per back
end (`draw.c` `svgdraw.c` `psprint.c`), after `get_sym_text_layer()` and inside
the `inst.color == -10000` arm.

**(C) The chords.** `utils/annot_mode.tcl`: `_annot_mask {mode {cur 0}}` is
additive (`none=0`, `op=cur|1`, `opvolt=cur|2`) and stays a **pure** function;
`annot_mode` pulls the live mask with `xschem get annot_show` and hands it over;
`_annot_msg` is re-keyed from the MODE to the **resulting mask** and gains mask
2's own wording. Mode spellings kept (invariant **I5** — a user's rc calls them).
`src/cadence_style_rc`'s three-line comment table is **rewritten** with the
ruling's table. **Note the anchor in this issue was drifted: it is `:286-288`,
not `:283-285`.** The three binds are untouched and still end in `break`.

**(D) The stock surfaces.** `src/xschem.tcl`: both shipped Op-Annotate menu
bodies go `1` -> `3` with their deferring comment rewritten; the View label
becomes "Show node voltage / branch current annotation"; `set_ne
annot_voltage_layer 9` + a `tctx::global_list` entry. `scheduler.c` gains
`get`/`set annot_voltage_layer` (both dispatch halves swallowed the word before).
`xinit.c:941` gains the C default. `editprop.c` gains
`if(text_changed && !props_changed) set_text_flags(...)`, because the class is now
a function of the CONTENT and the dialog path only re-ran the classifier under
`props_changed`.

## Decisions, each with its ladder rung and its rejected alternative

| # | rung | decision | rejected |
|---|---|---|---|
| **D1** | L1 / **I7** | **TWO** dedicated implicit bits, `TEXT_ANNOT_VOLTAGE` 256 + `TEXT_ANNOT_CURRENT` 512 | the prior art's reuse of `HIDE_TEXT_VOLTAGE`. One shared bit cannot tell an author's explicit `hide=voltage` from a tree-computed class, so the floater exemption (D3) would wrongly un-hide it. Rows U27+U29 together force this |
| **D2** | L1 / **I7** | the implicit class is added **only when the `hide=` chain set no bit** | classify unconditionally. `text_hidden()` tests class bits BEFORE `show_hidden_texts`, and nine tracked records (`pcb_current_protection_embed.sch:174,441,456` + two mirrors) carry `hide=true` AND a bare token — an unconditional class silently moves them from the View > Show hidden texts switch to the annotation mask |
| **D3** | L1 / **I7** | a schematic-own text is classified **only when `TEXT_FLOATER` is set**; a symbol text **always** | the prior art's unconditional classification. Measured: a symbol `@spice_get_voltage` with no raw emits **no element** (free to classify) while a schematic-own NON-floater renders the **literal string** — the one way a content class regresses a non-annotating user. Also rejected: classifying only `TEXT_CTX_INSTANCE`, which reds U22 and makes three of the six colour sites dead code |
| **D4** | L2 | **branch currents JOIN the switch (bit1) and KEEP layer 17** | a third mask bit (`Alt-6` would become 7 — a fourth state against a three-row ruling table) and folding currents into `annot_voltage_layer` (erases a 15-vs-17 distinction the user already has). Re-derived, not inherited: 0613's surviving-`Ctrl-6` list **contains** the branch currents, so "`Ctrl-6` -> nothing" is false without them; and layer 17 is `#00ffcc` in **both** palettes across 84 shipped records |
| **D5** | L2 | **six** spellings; `@#<pin>:` split mirrors `get_pin_and_attr()` (`token.c:412`) bracket-for-bracket | this issue's own five-item list. **`@spice_get_current<n>` is DROPPED** — verified, there is no branch for it anywhere in `token.c`; its only tree hit is a stale comment at `save.c:5743`, which is where the five-item list was copied from. **`@#<pin>:spice_get_voltage` and `@spice_get_diff_voltage` are ADDED.** `@spice_get_modelparam*` / `@spice_get_modelvoltage*` deliberately NOT classified (issue 0418: matched then silently produce nothing, and they are device OP info, i.e. bit0's business) |
| **D6** | L2 | the mirror is pulled with `tclgetvar()` | `tclgetintvar()` — returns **0** on a missing var and **0 is BACKLAYER**, i.e. the annotation paints in the background colour. Also rejected: a raw `Tcl_GetVar` (the prior art's finding (d)) — `actions.c` has no other one and needs none |
| **D7** | L2 | any index outside `[1, cadlayers)` means **no override** | accepting 0 as a legal layer index. So `0` / `-1` / `999` / `"abc"` all fall back to the text's own layer; the setter still stores what it is given, so `set 7` / `get 7` round-trips (U21) |
| **D8** | L2/L3 | mode spellings `none`/`op`/`opvolt` **kept** while their semantics change; `_annot_mask` takes `{cur 0}` explicitly so it stays a pure, headless-testable function | renaming `opvolt` -> `volt` (breaks every user rc — invariant **I5** — reds N0/N2/N19, buys cosmetics). Also rejected: `_annot_mask` reading the mask itself (it would stop being pure and N1 would depend on live state) |
| **D9** | L2 | the status line is worded off the **resulting mask** and says "node voltages" where the View checkbutton says "node voltage / branch current" | leaving `_annot_msg` mode-keyed (it would say "device OP info + node voltages" after an `Alt-6` that produced voltages alone — the measured lie). Also rejected: "+ branch currents" in the status line — churns N6/N8/N9/N10/N10b/N15's committed goldens for no user gain |
| **D10** | **L3** | `annot_show` **keeps its default of 0** | default 2. **This is the STATUS E question — see issue 0621.** |

A second, smaller user-visible decision, recorded not filed: the two shipped
Op-Annotate menu bodies now write mask **3** as a HARD SET, whose semantics differ
from the two additive chords. That is row N22b's demand and exactly what those
bodies' own in-place comments deferred to "the moment bit1 gets producers"; both
comments are rewritten in place with the reasoning (a one-click "annotate this
cell" that loaded the raw and then hid the voltages it had just resolved would be
a worse first run than the dark annotator the line was written to fix).

## Sabotage matrix — 9 variants, and the one predicted red that did NOT appear

| variant | what it kills | predicted | observed |
|---|---|---|---|
| SB-A no implicit class | `annot_content_class` -> `NONE` | 12 | **14** — all 12 (U1 U2 U3 U6 U14 U15 U17 U18 U22 U23 U26 U28) + bonus U16 U20 |
| SB-B colour override dead | `annot_text_layer` -> `-1` | 6 | **7** — all 6 (U14 U15 U17 U18 U20 U28) + bonus U16. **U19 and U30 stayed GREEN by design** — proof the source-grep rows cannot substitute for the render oracles |
| SB-C psprint left behind (**the prior art's real hole**) | both `psprint.c` sites -> a local `-1` stub | 2 | **2 exact** — U18 (PS RGB oracle) + U30 (exact-call count `2 2 0`). **U19's file-set row stayed GREEN**, because the substring survives inside the stub name — in-tree proof that U19 alone would have shipped a four-of-six patch |
| SB-D mirror never pulled | the `tclgetvar` read in `annot_show_sync_cache` | 1 | **1 exact** — U20 only. U21 correctly green (the setter still pushes both halves), so U20 is the only row separating a *pulled* mirror from a *pushed* one |
| SB-E chords back to a hard three-state set | `_annot_mask` returns 0/1/3 ignoring `$cur` | 4 | **5** — all 4 (N1, N1b, LC1, LC2) + bonus N5. LC3 correctly green (`6` from 0 is 1 under both semantics) |
| SB-F status line speaks mode again | `_annot_msg` re-keyed on a mode word | 5 | **9** — all 5 (N3 N5 N6 N8 N23) + 4 bonus (N9 N10 N10b N15) |
| SB-G implicit class stacked on an explicit `hide=` | `annot_class_free` -> always 1 | 2 | **1** — U10 fired, **U29 did NOT.** ⚠ **REAL COVERAGE HOLE — filed as [0624](0624-an-explicit-hide-voltage-records-colour-half-has-no-guardian.md)** |
| SB-I CONTAINS instead of IS | `strstr("@spice_get_voltage")` | 4 | **4, but not the predicted set** — U7 U8 U13 + bonus U28; **U12 did NOT**, because its fixture spells the token `@#1:spice_get_voltage` and never contains the literal needle. Prediction mis-scoped, row alive |
| SB-I2 (extra, to disambiguate SB-I) | same, needle widened to `spice_get_voltage` | — | **7** — U12 **now fires**, with U7 U8 U13 U28 and the shipped-corpus rows L19 L20. U12 covers the CONTAINS shape reaching the 158 `nmos4`/`pmos4`-style `vgs=` records |

All variants restored; baseline green after restore.

## STILL OPEN (adversary residuals — none refuted the change)

1. **This issue's own acceptance sentence "renders byte-identically" is FALSE as
   written at fullzoom** — 59 of 822 shipped sheets reframe, and two flip symbol
   level-of-detail, because the instance bbox now depends on `annot_show`
   (`select.c:709`). No text is gained or lost, and at a fixed viewport 820/822
   are byte-identical. Filed as
   **[0622](0622-annot-show-perturbs-the-instance-bbox-so-a-no-raw-render-is-not-byte-identical.md)**.
2. **"`Ctrl-6` -> nothing" is still false on a generic-device sheet.**
   `devices/nmos4.sym:56-57` / `pmos4.sym:60-61` carry a `tcleval(vgs=... vds=...)`
   composite at `layer=15` with no `hide=` — not a whole-string match, so bit1
   does not gate it, and it wears the OP block's exact colour. 50 shipped sheets,
   including `examples/cmos_example.sch`. sky130's own symbols are safe
   (`hide=true`), which is why the eyes-on session did not show it. Filed as
   **[0623](0623-generic-nmos4-pmos4-vgs-vds-texts-survive-ctrl-6-in-the-op-block-colour.md)**.
3. **The I7 gate's colour half is guarded by nothing** — SB-G above. Filed as
   **[0624](0624-an-explicit-hide-voltage-records-colour-half-has-no-guardian.md)**.
4. `xschem get annot_voltage_layer` reads the C field, while the Tcl->C pull
   happens only at the eight bulk-evaluation entry points, so a Tcl-only write is
   invisible to `get` until the next draw/export. Same shape as `annot_show`, so
   not new — but a script that writes the var and reads it straight back gets the
   old value. Row U20 exercises the export path only.
5. **A newly created tab inherits `annot_voltage_layer` and `annot_show` from the
   Tcl mirror, not from `xinit.c`'s C defaults** (measured: tab1 at 7/2 -> a new
   tab opens at 7/2, not 9/0). Consistent with `annot_show`, but it means the C
   initialiser only ever applies to the first context — which changes where
   **0621**'s ratification actually has to land (the `set_ne` line, not
   `xinit.c:941`).
6. **A malformed `xschem new_schematic switch` argument segfaults.** Observed
   while exercising per-tab persistence; pre-existing tab-dispatch robustness,
   entirely outside this change, not filed here.
