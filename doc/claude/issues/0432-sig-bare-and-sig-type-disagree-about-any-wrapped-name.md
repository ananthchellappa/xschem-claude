# 0432 — `wviewer::sig_bare` and `wviewer::sig_type` disagree about any wrapper that is not `v(`/`i(`

**Status:** OPEN. Measured on branch `fluid-editing` at `89d0f13e`, 2026-08-19.
**Area:** `wviewer::sig_bare` (`src/wave_viewer.tcl:2155`) and
`wviewer::sig_type` (`:1951`), both consumed by the Signal Browser's
classification.
**Found:** 2026-08-19, while specifying typed signal accessors
(`doc/claude/specs/typed_signal_accessors.md` §10 L5).
**Severity:** latent today — no shipped name has a third wrapper — and
**blocking** for the accessor work, which introduces twelve of them.

---

## What

The two procs answer questions about the same name with two different notions of
what a wrapper is.

`sig_bare` strips **any** `identifier(...)` wrapper:

```tcl
if {[regexp {^[A-Za-z_][A-Za-z_0-9]*\((.*)\)$} $name -> inner]} { return $inner }
```
— `src/wave_viewer.tcl:2155-2158`

`sig_type` recognises **exactly two** prefixes, `v(` and `i(`, case-insensitively,
and returns `other` for everything else (`:1951`).

So for a name like `VT(out)`:

```
wviewer::sig_bare  VT(out)   ->  out        (treated as wrapped)
wviewer::sig_type  VT(out)   ->  other      (treated as unwrapped)
```

## Why it is latent rather than live

No ngspice writer produces a third wrapper: raws hold `v(`, `i(`, bare names and
`@dev[param]`. A VCD holds bare names. So the disagreement has never had an input
that exercises it.

## Why it stops being latent

`doc/claude/specs/typed_signal_accessors.md` introduces eight accessor spellings
(`VT`/`VS`/`VF`/`VDC`, `IT`/`IS`/`IF`/`IDC`) and four wrappers
(`mag`/`phase`/`real`/`imag`) that are exactly `identifier(...)` tokens. Every one
of them will be bared by `sig_bare` and classed `other` by `sig_type`, which
feeds the browser's per-row class, its `-type v` / `-type i` filters and its
declass logic. The affected assertions are already committed:
`tests/headless/test_wave_sigsearch.tcl` ST01/ST03 (`sig_type`) and
SB01/SB04/SB05/SB08/SB09 (`sig_bare` + `sig_split`).

## Fix direction

Decide, once, what "the wrapper of a name" means for the browser, and make both
procs answer from it:

- if the browser classifies **stored raw names**, `sig_bare` is the one that is
  too permissive and should recognise the same closed set `sig_type` does;
- if it classifies **user-written expressions** too, `sig_type` is the one that
  is too narrow and should learn the accessor set.

The accessor spec's R306 requires the second reading for `validate_rpn`; whether
the browser follows is a separate call, and this issue exists so it is made
rather than defaulted.

## Related

`doc/claude/specs/typed_signal_accessors.md` §10 L5, R306, §19 defect 3; issue
0419 (the other Signal Browser classification defect, about `@dev[param]` at top
level).
