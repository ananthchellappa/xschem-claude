# 1602 — the precision dialog accepts a value that then breaks every number it formats

**STAMP:** `v1 claim=open tree=2ecb21c2 stamped=2026-09-22 fix=untried open=3 by=driver`

**Status: OPEN — filed 2026-09-22** by the driver, from a gap two closed issues both
touched and neither owned. **Class** missing input validation with a silent, total
downstream effect.
**Related, read first:** **1345** (the Results Display Window said "(did not converge)"
when its own formatter merely declined — **FIXED** 2026-09-05; its §28 records *"no
validation"* on this dialog as the cause it did **not** fix) and **1352**
(`input_line`'s OK button ran what you typed as Tcl — **FIXED** in `2a22bfb7`; its receipt
says plainly *"input validation on these dialogs is still absent and is a separate
defect"*).

⚠ **This file reports no new measurement.** Everything below is CITED from `src/rdw.tcl`'s
comment wall, from issue 1345, and from the 1352 crew's receipt. The one thing that has
changed since those were written is stated as a consequence of `2a22bfb7`, not as a
measurement. **Measuring it is job 1.**

---

## The defect

`Simulation ▸ Set netlist / graph / annotation precision` is a bare `input_line` with no
validation. Whatever you type becomes `ev_precision`.

CITED from `src/rdw.tcl`'s comment wall above `rdw::_fmt_value`, which records it as
MEASURED: all eight of `-1`, `2.5`, `abc`, `4x`, `+4`, `0x4`, `6.` and `6.0` stick, and all
eight make `format %.${pr}g` raise inside `to_eng`.

CITED from issue 1345, the measured table:

```
ev_precision=4   : 1.11e-05=>11.1u    0.001=>1m       0.75=>0.75
ev_precision=-1  : 1.11e-05=>(did not converge)  0.001=>(did not converge)  …
ev_precision=2.5 : … all eight identical …
```

**The consequence is total, not partial.** From the moment a bad precision is set, *every
correctly measured value* in the Results Display Window reads `(did not converge)` — a
statement about the **circuit**, for numbers the simulator computed perfectly well, on the
one surface this feature exists to have pasted into a design review.

## What 1345 fixed, and why this survived it

1345 fixed the **reading**: the window no longer infers "non-finite" from an empty string
coming back from `eng_or_blank`, because that proc answers `{}` for two reasons a caller
cannot tell apart. It now asks `op_annot::_finite` directly, so a declining formatter
falls back to the raw text — unformatted but **true**.

That is the right fix for the window and it is not in question here. But it treats the
symptom at the last possible moment. The dialog upstream still accepts `abc`, and the
formatter still raises on every value; 1345 only stopped the window from lying about
*why*. **The rows that fence 1345 (`EN8` behavioural, `EN10` structural) would all still
pass with `ev_precision` set to `abc`** — that is what "fixed the reading" means.

## What `2a22bfb7` changed about it, and what it did not

Before the 1352 fix, typing `7 ; set ::INJECTED yes` left `ev_precision` numeric (`7`),
because the text was parsed as a script and only the first word reached `set`. After it,
the whole string lands as the value.

The 1352 crew checked the consequence rather than assuming it, and reports: `tclgetintvar`
is `atoi()`, so `atoi("7 ; set ::ILINJ yes")` is `7` and **every C consumer behaves exactly
as before**. The Tcl side is the exposed one, because `format %.${pr}g` takes the string.

So `2a22bfb7` neither caused this nor fixed it. ⚠ **But it does change the set of strings
that can reach `ev_precision`** — a value with a space in it could not survive the old
splicing and can now — so the eight-value measurement above predates the current code and
should be re-taken, not re-cited, by whoever takes this.

## The shape a fix takes, and the one question inside it

The mechanism is not in doubt: refuse a value the formatter cannot use, at the dialog,
and say why. `input_line` already returns the typed text to its caller, and the caller is
one line in `xschem.tcl`'s menu, so the validation has an obvious home that does not
require a new dialog.

**The question that is genuinely the user's** — and it is one question, not three:

> When you type something the precision box cannot use, should it refuse and tell you, or
> quietly keep the last good value?

Refusing is louder and cannot be missed; keeping the last good value never interrupts you
but means a keystroke you made had no effect and nothing said so. The recommendation is
**refuse and say why**, because the current behaviour's whole problem is silence, and
because this box is reached deliberately from a menu rather than in passing.

⚠ **Do not widen this into "validate every dialog".** `input_line` also carries snap value,
grid spacing, line width, grid point size, symbol width, crosshair size, the bus
replacement characters and the netlist name, and each has a different notion of a legal
value — the netlist name's is "almost anything", now that `2a22bfb7` lets it hold a space.
A single generic validator would be the wrong shape. If a per-caller validator is wanted,
that is a second issue with its own survey.

## Still open

1. **Re-measure the eight values on the current code** (`2a22bfb7` or later), rather than
   citing 1345's table. Report what each does to `ev_precision` and to a formatted value.
2. **Answer the one question above**, then implement it for the precision box only.
3. **A T1-visible test.** Structural is easy. The behavioural half needs the real dialog on
   a display, which `tests/headless/test_input_line_inject_1352.tcl` now does for this exact
   menu entry (rows `B18a`/`B18b`) — extend that suite rather than starting a new one.

## What this issue is NOT

It is not a complaint about `to_eng` raising. Raising on `format %.abcg` is correct; the
defect is that `abc` ever reached it. It is not a request to change what
`(did not converge)` means — 1345 settled that. And it is not about the injection, which
`2a22bfb7` closed.
