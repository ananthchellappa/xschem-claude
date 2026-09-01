# 0681 — 0678 moved THREE SHIPPED library records to a different chord, and a committed test comment says it moved none

STATUS: **OPEN — measured, NOT fixed.** Found by the write-up agent of the crew
that implemented [0678](0678-branch-currents-are-gated-by-alt-6-but-belong-to-6.md),
after the adversary leg flagged it as a residual risk. Two defects, one cause:
a **coverage gap** (the shipped spelling has no test row) and a **false statement
committed into a test comment** (which is how the gap stayed invisible).
Related: 0678, 0614, 0615, 0622.

---

## 1. The false statement, verbatim, as committed

`tests/headless/test_op_annot.tcl`, the comment above row **U33** (added by 0678):

> Nothing else in the tree sees that: the census in this section's U27 note found
> **ZERO shipped schematic-own bare `@spice_get_current` records**, so no golden
> and **no shipped sheet would move**.

Both halves are wrong. Measured on this tree, `grep -rn '@spice_get_current'
xschem_library/ --include=*.sch`:

| file:line | property list | floater? | moves Alt-6 → `6`? |
|---|---|---|---|
| `xschem_library/ngspice/solar_panel.sch:269` | `{layer=7 name=L2}` | **yes** | **YES** |
| `xschem_library/ngspice/solar_panel.sch:270` | `{layer=7 name=C1}` | **yes** | **YES** |
| `xschem_library/ngspice/pv_ngspice.sch:68` | `{layer=15 name=Rs}` | **yes** | **YES** |
| `xschem_library/pcb/pcb_current_protection_embed.sch:440` | `{layer=15 hide=true}` | no | no — `hide=true` sets `HIDE_TEXT`, so `annot_class_free()` is false and it never gets an implicit class at all |

(A fifth hit, `xschem_library/examples/mos_power_ampli.sch:497`, is a
`xschem translate` call inside a Tcl script, not a `T` record.)

So the census is **4, not 0**, and **three shipped sheets move**.

**How the error was made** — the U27 note it paraphrases is itself correct, but
it is scoped to a *different shape*:

> Census of the shipped libraries: 20 schematic-own T records carry a bare token,
> 6 with `hide=true` and the other 14 real `name=` floaters that resolve to
> empty — so no shipped sheet has this shape

U27's *"this shape"* is the **NON-FLOATER**, and for the non-floater the census
is genuinely zero. U33's comment re-used the sentence for the whole class and
dropped the qualifier. The 14 floaters were counted and then discounted as
*"resolve to empty"* — true with **no raw loaded**, which is the state the census
was taken in, and false the moment a user loads one.

## 2. The coverage gap

Invariant **I7** has two guards, and `annot_class_mask()` implements them as one
expression:

```c
if(ctx != TEXT_CTX_INSTANCE && !(flags & TEXT_FLOATER)) return 0;
```

A schematic-own text is classified **only when it is a floater**. So the two
schematic-own spellings take *opposite* branches of the same test, and the suite
guards only one of them:

| shape | example | row |
|---|---|---|
| schematic-own **NON**-floater | `T {@spice_get_current} … {layer=17}` | **U33** (added by 0678) |
| schematic-own **FLOATER** | `T {@spice_get_current} … {layer=7 name=C1}` | **none** |

The unguarded one is the one that **ships in the library**. U33 guards a shape
that exists in no shipped sheet; nothing guards the shape that exists in three.

## 3. Measured — BEFORE and AFTER

The behaviour itself is **CORRECT**; it is the coverage that is missing. Fixture
(`/tmp/…/scratch_0678_writeup/lib/wu.sch`) carries one `vsource.sym` V1, a
`lab_pin` on net `d`, and *both* schematic-own spellings side by side:

```
T {@spice_get_current} 200 -100 0 0 0.4 0.4 {layer=7 name=V1}   ;# FLOATER
T {ZZFLOATMARK}        200 -140 0 0 0.4 0.4 {layer=7}           ;# non-vacuity reference
T {@spice_get_current} 200 -200 0 0 0.4 0.4 {layer=17}          ;# NON-floater
```

with an OP raw carrying `i(v1) = -3.21e-04` and `v(d) = 1.8`. SVG export at each
mask, `<text>` elements scraped:

```
mask 0 : resolved_currents=0  literal_tokens=1  mark=1  texts={V1 5 d GND ZZFLOATMARK @spice_get_current}
mask 1 : resolved_currents=2  literal_tokens=1  mark=1  texts={V1 5 -321u d GND -321u ZZFLOATMARK @spice_get_current}
mask 2 : resolved_currents=0  literal_tokens=1  mark=1  texts={V1 5 d 1.8 GND ZZFLOATMARK @spice_get_current}
mask 3 : resolved_currents=2  literal_tokens=1  mark=1  texts={V1 5 -321u d 1.8 GND -321u ZZFLOATMARK @spice_get_current}
```

Read that as:

* the **floater** resolves to `-321u` and follows **bit0** — present at masks 1
  and 3, absent at 0 and 2. It **moved** from `Alt-6` to `6`, exactly like the
  symbol-side record. That is what 0678 intends and it is right;
* the **non-floater** stays the literal string `@spice_get_current` at **all
  four** masks (I7 intact, and this is what U33 pins);
* `mark=1` at every mask, so no row above is satisfied by an export that drew
  nothing.

Before 0678 the floater followed bit1 (`Alt-6`) — the same single `if` gated both
classes, so `solar_panel.sch`'s two currents appeared with the node voltages.
After 0678 they appear with the OP blocks.

## 4. What should be done

**Add a U33-shaped row for the FLOATER spelling** (call it **U36**) asserting
`{0 1 0 1}` on the shipped shape, and **correct U33's comment** to the real
census. The comment correction landed with 0678's write-up (it was a false
statement in a committed file and could not be left); **the test row did not** —
adding a check that no sabotage variant in that crew's matrix ever reddened would
have shipped an unproven guard, which is the failure mode this crew's own rules
exist to prevent. The row wants a red phase of its own: SB3
(`i7_ctx_guard_ignored`) and a new *"floater term dropped"* variant
(`if(ctx != TEXT_CTX_INSTANCE) return 0;`) are the two that must red it.

⚠ **Do not "fix" this by editing `solar_panel.sch` or `pv_ngspice.sch`.** They are
correct as they stand; the movement is the intended consequence of 0678.

## 5. Still open — what this does NOT settle

* **Whether the move is right for these three sheets is a LOOK, not a suite.**
  `solar_panel.sch` and `pv_ngspice.sch` are demo sheets a user opens to learn
  from. Their inductor/capacitor/resistor currents now need `6` rather than
  `Alt-6`. That is coherent with 0678's rule (a device's terminal current is
  device OP info) but nobody has opened either sheet since the change. It rides
  the open `look` debt `[0678_branch_currents_moved_from_Alt-6_to_6]`.
* **The `-` placeholder reaches these sheets too.** With no raw loaded the three
  floaters render `-` (issue **0625**), and after 0678 those hyphens appear on
  the `6` chord instead of `Alt-6`. Same count, different key.
* **`pcb_current_protection_embed.sch:440` is inert for a second reason.** It
  carries `hide=true`, so it answers to `show_hidden_texts`, not to `annot_show`
  at all. If a later step ever makes `hide=true` and the implicit class
  composable, this record becomes live and moves with them.
