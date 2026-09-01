# 0623 — `Ctrl-6 -> nothing` is still FALSE on a generic-device sheet: `nmos4`/`pmos4` `vgs=`/`vds=` survive, in the OP block's colour

STATUS: **OPEN — measured, NOT fixed.** Found by the adversary leg of the crew
that implemented [0614](0614-annot-chords-must-own-node-voltages.md) /
[0615](0615-node-voltage-colour-collides-with-op-block.md), 2026-08-22. This is
[0613](0613-ctrl-6-does-not-clear-node-voltages-so-everything-off-is-false.md)'s
complaint **plus** 0615's colour collision, surviving on a device class the
user's sky130 bench does not contain — which is why the eyes-on session did not
show it.

---

## Measured, after 0614+0615 landed

`xschem_library/devices/nmos4.sym:56-57` (and `pmos4.sym:60-61`) carry:

```
T {tcleval(vgs=[to_eng \{@#1:spice_get_voltage - @#2:spice_get_voltage \}]
vds=[to_eng \{@#0:spice_get_voltage - @#2:spice_get_voltage \}])} 2.5 20 0 1 0.05 0.05 {layer=15 }
```

`layer=15`, **no `hide=` token**. So it is:

- **not classified** — 0614's content class is a whole-string match (IS, not
  CONTAINS) and this string is a `tcleval(...)` wrapper, so bit1 does not gate it;
- **not gated by bit0** either — no `hide=op`;
- **layer 15 — the OP block's exact colour.**

One `nmos4`, an OP raw, `xschem set annot_show 0` (what `Ctrl-6` writes), SVG at a
fixed viewport:

```
mask 0 : ... vgs=0.8|#ff7777 vds=1.7|#ff7777 ...        <- OP-block colour, after Ctrl-6
mask 3 : ... vgs=0.8|#ff7777 vds=1.7|#ff7777 -|#00ffcc DD|#00ddff 1.8|#ffffff 0.9|#ffffff 0.1|#ffffff 0|#ffffff
```

Everything 0614 gave bit1 correctly disappears at mask 0 — the four node voltages
(`1.8 0.9 0.1 0`, layer 9 white) and the branch current (`-`, layer 17). The two
composite rows do not. **`Ctrl-6` still leaves numbers on the screen**, and they
are the one colour 0615 was filed to stop node values wearing.

The same symbol's `T {@spice_get_current} ... {layer=17}` (`nmos4.sym:58`) IS a
whole-string match, so it *is* classified and *does* follow bit1 — the defect is
specific to the two-line `tcleval` composite.

## Blast radius

`grep -rlE '^C \{[^}]*[np]mos4(\.sym)?\}' --include=*.sch .` = **50 sheets**,
including `xschem_library/examples/cmos_example.sch` — i.e. the first schematic a
new user opens. sky130's own PDK symbols are **safe**: their equivalent texts
carry `hide=true`, which is why the user's bandgap bench never showed it.

## Why 0614's classifier deliberately cannot catch it

0614 chose IS-not-CONTAINS for a measured reason: 119 shipped `hide=true
@spice_get_node` records and 39 `vgs=expr(...)` records are **device OP info**,
not node voltages, and a CONTAINS rule sweeps them into bit1. The sabotage matrix
proves the rule is load-bearing — row U12's fixture is exactly this `nmos4` shape,
and a CONTAINS classifier reds it (variant SB-I2). So the fix is **not** to relax
the match.

## Three ways to close it, none free

1. **Tag the two symbols** — add `hide=op` to the `vgs=`/`vds=` record in
   `nmos4.sym` / `pmos4.sym` (2 files, 2 records). It is genuinely *device* OP
   info, so bit0 is the semantically right bit and `Ctrl-6` then clears it. This
   is what S10b already did for 40 sky130 symbols (with `hide=true`, see 0475 §3).
   Cost: library churn, and it does not generalise to a user's own symbol.
2. **Add a second, narrower implicit class for a `tcleval(...)` text whose body
   contains only `@spice_get_*` tokens and arithmetic.** Generalises; but it is a
   parser, and 0614's landmine about two drifting predicates applies.
3. **Leave it and document that generic devices are outside the mask.** Cheapest,
   and false to the ruling's own words.

Recommendation: **option 1**, and a spec sentence saying the mask governs a text
only when the text is *either* explicitly tagged *or* a whole-string annotation
token — a symbol author who builds a composite must tag it. Ladder **L2**: no new
predicate, smallest blast radius, and it makes the shipped tree honest.

## Guardian to add with the fix

A row that loads a `devices/nmos4` sheet with an OP raw, sets mask 0, and asserts
**no** `<text>` in the export contains `vgs=` or `vds=`. Section U has no
generic-device row at all today.

## Do not confuse with

- **0605** (overlay collides with the symbol's own texts) — that is duplication
  at mask 1, not survival at mask 0.
- **0475 §3** — the sky130 cleanup that made the PDK symbols safe. This is the
  same job for `xschem_library/devices/`, and it was never done there.
