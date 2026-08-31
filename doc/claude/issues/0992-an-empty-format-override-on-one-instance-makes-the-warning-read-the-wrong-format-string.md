# 0992 — an empty format override on one instance makes the netlist warning read a format string the netlister does not use, and the tool tells the designer to delete a setting VHDL really writes

**Filed** 2026-08-30, by the S4d sabotage pass.
**Status** FIXED 2026-08-30 by the S4d repair pass. **Class** false accusation of the 0980 harm class, RULING D5-1.
**Subject** `src/token.c`, the presence test in `ua_fmt_attr_state()`.

## The disagreement

`ua_fmt_attr_state()` decides whether a format attribute is "there":

```c
f = get_tok_value(xctx->inst[inst].prop_ptr, attr, 2);
found = (xctx->tok_size && f && f[0]) ? 1 : 0;
if(!found) {
  f = get_tok_value(xctx->sym[xctx->inst[inst].ptr].prop_ptr, attr, 2);
  found = (xctx->tok_size && f && f[0]) ? 1 : 0;
}
```

Every netlister asks a DIFFERENT question — `if(!xctx->tok_size)` alone
(`src/token.c:1532`, `:3254`, `:3640`, and `print_spice_element`'s own four-step
resolution). `xctx->tok_size` is the token-NAME length (`src/token.c:531`), so
`vhdl_format=""` typed on an instance is **present** to the netlister and
**absent** to the guard. The guard then falls through to the symbol's format
string, which the netlister never reads.

An empty format string in force also means the backend takes its parameter-map
path (`print_vhdl_element` hands off to `_primitive()` only `if(fmt[0])`), so
the correct answer for an empty string is "no format string", not "a format
string that does not mention the token".

## Two measured wrong sentences

Both on the shipped binary (`md5 0a9edb3350e4f17c9d895be09792c1b8`).

**(a) DESTRUCTIVE.** Cell `pempty`: `template="name=x1 knob=1"`,
`vhdl_format="-- @name has no knob"`, `verilog_format="// @name has no knob"`.
Instance: `{name=xE knob=99 vhdl_format=""}`.

> Warning: … instance xE (a pempty) sets knob=99, but pempty never reads knob
> when the netlist is written, so that setting did not reach the simulator and
> changed nothing. Check the spelling against the settings this cell does read,
> **or take it off.** …

Ground truth — the VHDL netlist of that very sheet: `knob => 99`.
Following the advice deletes a live setting. This is issue 0980's harm arriving
through a new door.

**(b) FABRICATED.** Cell `pemp2`: `template="name=x1"`,
`vhdl_format="-- @name VH=@zztok"`. Instance: `{name=xF zztok=5 vhdl_format=""}`.

> … **a VHDL netlist of the same cell does carry it**, so deleting it would
> break that.

Ground truth: `zztok` appears in neither the VHDL nor the Verilog netlist.

## No row can see it, in either direction

Mutation `SAB-f0half` — drop the `f && f[0]` half, keep `xctx->tok_size`:

    RESULT SAB-f0half rc=0 ok=57 nfail=0 allpass_banner=1 REDDENED=[ ]

And the CORRECTED version — fall back to the symbol only on genuine absence,
and treat an empty string in force as "no format string":

```c
f = get_tok_value(xctx->inst[inst].prop_ptr, attr, 2);
found = xctx->tok_size ? 1 : 0;
if(!found) {
  f = get_tok_value(xctx->sym[xctx->inst[inst].ptr].prop_ptr, attr, 2);
  found = xctx->tok_size ? 1 : 0;
}
if(!found || !f || !f[0]) return 0;
```

— builds, flips (a) to kind B naming VHDL and (b) to kind A, both of which are
the truth, and **also scores `RESULT: ALL PASS (57 checks)`**. The suite cannot
tell the defect from its fix. That is what makes this a 0986-class finding and
not merely a bug.

## Severity

Latent on today's tree: `grep 'format=""'` across `xschem_library`, `sky130A`,
`ihp-sg13g2`, `gf180mcuD` and `xschem_libs_newsym` returns 0, and no fixture
uses an empty override. The ingredient is ordinary, though — an empty override
is how a designer turns a cell's alternate netlist line off on one copy.

## Fix

Apply the corrected presence test above, and add two rows: an instance with an
empty `vhdl_format` over a symbol format that does NOT read the token (must be
kind B naming VHDL), and one over a symbol format that DOES (must be kind A).


---

# FIXED 2026-08-30 — the S4d repair pass

The corrected presence test proposed above is what shipped, verbatim:

```c
f = get_tok_value(xctx->inst[inst].prop_ptr, attr, 2);
found = xctx->tok_size ? 1 : 0;
if(!found) {
  f = get_tok_value(xctx->sym[xctx->inst[inst].ptr].prop_ptr, attr, 2);
  found = xctx->tok_size ? 1 : 0;
}
if(!found || !f || !f[0]) return 0;
```

Presence is `xctx->tok_size`, exactly as every netlister has it; an override
that IS there but empty resolves to state 0 — no format string governs this
backend, so the template path is the one taken — which is what the netlisters
themselves do one line later at `if(fmt[0])`.

## The two rows the suite was missing

Both copies on one sheet, `uaefmt_top.sch`, so ONE VHDL netlist settles both.

* **UF33a, the destructive shape.** Cell `uaemptf`: template declares `knob`,
  its VHDL and Verilog lines read other tokens. Copy `xEA` sets `knob=99` and
  `vhdl_format=""`. The sentence must be kind B naming VHDL, and the row opens
  the VHDL netlist of that sheet and counts `knob => 99` — exactly 1.
* **UF33b, the fabricating shape.** Cell `uaemptg`: template declares nothing,
  its VHDL line reads `@knob`. Copy `xEB` sets `knob=99` and `vhdl_format=""`.
  The sentence must be the accusing one, and the row asserts the whole VHDL
  netlist holds exactly ONE `knob =>` line — the OTHER copy's.

## Measured

Before the code fix, on the same fixture (this is the harm, verbatim):

> instance xEA (a uaemptf) sets knob=99, but uaemptf never reads knob when the
> netlist is written, … Check the spelling against the settings this cell does
> read, **or take it off.**

while `p_efmt.vhdl` reads:

    xEA : uaemptf
    generic map (
       knob => 99
    )

and the mirror:

> instance xEB (a uaemptg) … **a VHDL netlist of the same cell does carry it** …

while `xEB : uaemptg` in the same file has no generic map at all.

After the fix both sentences are the truth. Mutations, one per build:

    MUT PRESENCE-old      (put the old test back) => reds: UF33a UF33b
    MUT PRESENCE-noempty  (drop only the `!f[0]` arm) => reds: UF33a

## The neighbouring half this exposed — the copy's line WINS, it is not OR'd

The sabotage pass also found that restoring the old OR of the instance's and the
symbol's format strings was 57/57 green, because until now no copy anywhere
carried a format line that read a DIFFERENT setting from the cell's. A new
fixture `uaov_top.sch` has one: the cell's Spectre line reads `@OVTOK` and copy
`xOV` brings its own Spectre line reading something else, so the two disagree.
Row **UF31** demands the accusing shape on `xOV` and kind B naming Spectre on
the plain copy beside it.

    MUT FMT-OR-ONLY (OR the two, keeping the fixed presence rule) => reds: UF31
    MUT FMT-NOINST  (delete the copy-side lookup outright) => reds: UF25 UF31 UF33a UF33b

UF25 sees the second; only UF31 sees the first.

## Effect on shipped data: none, and that was checked

`grep -rE '(vhdl|verilog|spectre|tedax|spice)?_?format=""'` over
`xschem_library` returns nothing, so this shape is latent on shipped sheets. The
whole-library noise sweep is unchanged to the line after the fix:
`sheets_with_lines=17 lines=141 A=98 B=43 suspect=43 loose=120`.
