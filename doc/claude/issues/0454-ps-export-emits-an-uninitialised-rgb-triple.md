# 0454 — `xschem print ps` ends every page with an UNINITIALISED RGB triple

**Status:** open, measured, not fixed
**Found by:** S7 RED agent (annotation classes), while trying to byte-compare two
PS exports of identical content for invariant I7.
**Severity:** low for rendering (PostScript clamps), high for testability — it makes
`xschem print ps` non-reproducible and silently defeats any byte-level export
regression test.

## What was measured

The last colour command emitted before `showpage` carries values far outside
PostScript's legal 0..1 range, and it CHANGES between two exports of the same
schematic in the same process:

```
$ ./src/xschem --nogui --pipe -q --nolog --script probe.tcl
# one schematic, one instance, two `xschem print ps <f> 900 400 -40 -40 300 80`
diff d1.ps d2.ps
186c186
< 4.06641 0 77.25 RGB
---
> 2.19141 0 6.51762e+06 RGB
```

Context in the file (`sed -n 178,190p`):

```
119.118 141.789 MT
1 -1 scale
(ZZS7MARK)
show
GR
0.316406 0 7.50066e+06 RGB      <-- this line
showpage
```

`set_ps_colors()` (src/psprint.c:415) prints
`ps_colors[pixel].red/256.0` etc. A blue component of `7.50066e+06` means
`ps_colors[pixel].blue` was about 1.92e9, which no initialised colour can be —
the index is out of range, or the entry was never filled.

## Reproduction shape (important)

* Within a run of N consecutive `print ps` calls the value is STABLE — six in a
  row were byte-identical.
* Interleave an `xschem print svg` and the NEXT ps export changes it. Measured:
  `ps, svg, ps` -> the two ps differ; `warm-ps, ps, svg, warm-ps, ps` -> still
  differ. So it tracks heap state, not the drawing.
* SVG export is byte-stable and shows nothing similar.

## Why it matters here

Invariant I7 of `doc/claude/specs/op_annotation.md` is "hide=true / hide=instance
semantics unchanged for ANY existing symbol in ANY library", and the natural way
to assert it is "export the shipped corpus twice and compare the bytes". That is
sound for SVG and unsound for PS until this is fixed. `tests/headless/test_op_annot.tcl`
rows L20 and L22 therefore compare a NORMALISED copy with every
`<r> <g> <b> RGB` line dropped (`opa_l_normps`), and row L21 exists to keep that
normalisation from making the comparison vacuous.

**When this is fixed, drop `opa_l_normps` and compare PS bytes directly** — that
is a strictly stronger test, and the normaliser is a workaround, not a design.

## Not investigated

Which `set_ps_colors()` call site emits it (psprint.c has 14; the one before
`showpage` is reached after the `xctx->texts` loop at psprint.c:1661-1697), and
whether `ps_colors[]` is short by one entry or the caller passes a stale layer.
No fix is proposed here: S7's brief forbids mixing an unrelated behaviour change
into its one commit.
