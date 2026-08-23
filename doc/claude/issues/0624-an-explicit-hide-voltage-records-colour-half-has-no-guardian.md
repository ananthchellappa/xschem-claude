# 0624 — the I7 gate's COLOUR half has no guardian: an explicit `hide=voltage` record can silently lose its own `layer=`

STATUS: **OPEN — a measured TEST-COVERAGE hole, not a live defect.** Found by the
sabotage leg of the crew that implemented
[0614](0614-annot-chords-must-own-node-voltages.md) /
[0615](0615-node-voltage-colour-collides-with-op-block.md), 2026-08-22. The
shipped behaviour is **correct**; what is missing is anything that would notice
if it stopped being.

---

## How it was found

Sabotage variant **SB-G** (`annot_class_free()` stubbed to always return 1, so the
implicit content class is stacked on top of an explicit `hide=` instead of only
being added when the `hide=` chain set no bit — a direct breach of invariant
**I7**) predicted two reds, **U10** and **U29**. Only **U10** fired.

`U29` ("an EXPLICIT `hide=voltage` on a schematic-own NON-floater is still hidden
by bit1") **cannot see the gate at all**: its fixture text is the marker string
`ZZUOWNHV` (`tests/headless/test_op_annot.tcl:7026`), which the content
classifier never matches whether or not the gate is present, so removing the gate
leaves the row unchanged. **U11** is blind the same way (marker `ZZUHVMARK`).

So the I7 gate is guarded by **U10 alone**, and only for **visibility**
(`hide=true` on a bare `@spice_get_voltage`).

## The unguarded half, measured directly

Probe symbol carrying `T {@spice_get_voltage} ... {layer=15 hide=voltage}` on a
labelled net with a raw loaded, mask 3:

| build | the explicit `hide=voltage` text | the implicitly classified `lab_pin` text |
|---|---|---|
| shipped (gate present) | `fill="#ffffff"`? **no — `#ff7777`, its own layer 15** ✅ | `#ffffff` (layer 9) ✅ |
| SB-G (gate removed) | **`#ffffff`** ✗ — it lost `layer=15` | `#ffffff` |

An author who writes `hide=voltage layer=15` on purpose silently loses the layer
she chose, and **no committed check notices**. The visibility half of the same
regression is caught (U10); the colour half is not.

This matters because `annot_text_layer()` (`src/actions.c`) deliberately
overrides the text's own `layer=` — every shipped voltage carrier spells
`layer=15`, so the override *must* beat it — and the only thing keeping an
author's explicit tag out of that override is which bit `set_text_flags()` set.

## The fix (test-only)

Give **U11** and **U29** a fixture whose **content IS** `@spice_get_voltage`
(keeping the `hide=voltage` token), and add one assertion:

```
# at mask 3, the explicitly-tagged record still carries its own layer, not layer 9
assert fill(explicit_hide_voltage_text) == fill(a plain layer-15 reference text)
```

That single assertion converts both rows from marker-string rows (which only
prove the *token* is parsed) into real guardians of decision **D1** — the two
dedicated implicit bits `TEXT_ANNOT_VOLTAGE` (256) / `TEXT_ANNOT_CURRENT` (512),
which exist precisely so the predicate can tell an author's explicit class from a
tree-computed one.

## Why it is filed rather than fixed here

Editing a green row's fixture in the same commit that turns 15 reds green makes
the pass unreadable: a later crew cannot tell which row moved because the feature
landed and which moved because the fixture changed. The rows are green and
correct today; this is the next crew's 20-line job, and the sabotage transcript
above is the proof it is worth doing.
