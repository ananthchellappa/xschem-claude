# 1602 — the precision dialog accepts a value that then breaks every number it formats

**STAMP:** `v1 claim=fixed tree=c3ec73a3 stamped=2026-09-22 fix=taken open=1 by=crew1602`

**Status: FIXED — 2026-09-22.** Filed 2026-09-22 by the driver, from a gap two closed
issues both touched and neither owned. **Class** missing input validation with a silent,
total downstream effect.
**Related, read first:** **1345** (the Results Display Window said "(did not converge)"
when its own formatter merely declined — **FIXED** 2026-09-05; its §28 records *"no
validation"* on this dialog as the cause it did **not** fix) and **1352**
(`input_line`'s OK button ran what you typed as Tcl — **FIXED** in `2a22bfb7`; its receipt
says plainly *"input validation on these dialogs is still absent and is a separate
defect"*).

---

## The defect

`Simulation ▸ Set netlist / graph / annotation precision` was a bare `input_line` with no
validation. Whatever you typed became `ev_precision`.

## §1 What it actually did — RE-MEASURED, not re-cited

The filed version of this issue reported no new measurement and asked for one, because
`2a22bfb7` changed which strings can reach `ev_precision`. All twenty values below were
driven through the **shipped menu entry** on a display (`DISPLAY=:99`, tree `c3ec73a3`,
before the fix), reading `ev_precision` back, then `to_eng 1.11e-05` (the Tcl formatter
the annotation sheet and the Results window share), `rdw::_value_text 1.11e-05` (the
window) and `xschem eval_expr {expr_eng(1.11e-05)}` (a **C** consumer, which reaches
`dtoa_eng` through `tclgetintvar`).

| typed | lands in `ev_precision` | Tcl `to_eng` | RDW shows | C `expr_eng` |
|---|---|---|---|---|
| `-1` | `-1` verbatim | **raises** `bad field specifier "-"` | `1.11e-05` raw | `11.1u` |
| `2.5` | `2.5` verbatim | **raises** `bad field specifier "."` | `1.11e-05` raw | `11u` |
| `abc` | `abc` verbatim | **raises** `bad field specifier "a"` | `1.11e-05` raw | `1.11e-05` |
| `4x` | `4x` verbatim | **raises** `expected integer but got "11.1"` | `1.11e-05` raw | `11.1u` |
| `+4` | `+4` verbatim | **raises** `bad field specifier "+"` | `1.11e-05` raw | `11.1u` |
| `0x4` | `0x4` verbatim | **raises** `expected integer but got "11.1"` | `1.11e-05` raw | `1.11e-05` |
| `6.` | `6.` verbatim | **raises** `bad field specifier "."` | `1.11e-05` raw | `11.1u` |
| `6.0` | `6.0` verbatim | **raises** `bad field specifier "."` | `1.11e-05` raw | `11.1u` |
| `" "` (one space) | `" "` verbatim | **raises** `bad field specifier " "` | `1.11e-05` raw | `1.11e-05` |
| `"4 5"` | `4 5` verbatim | **raises** `bad field specifier " "` | `1.11e-05` raw | `11.1u` |
| `"7 ; set ::ILINJ yes"` | whole string verbatim | **raises** `bad field specifier " "` | `1.11e-05` raw | `11.1u` |
| `""` (empty) | **unchanged** (stays 4) | `11.1u` | `11.1u` | `11.1u` |
| `4f` | `4f` verbatim | **`11.1000gu`** | **`11.1000gu`** | `11.1u` |
| `4e0` | `4e0` verbatim | **`1.1100e+010gu`** | **`1.1100e+010gu`** | `11.1u` |
| `4s` | `4s` verbatim | **`11.1gu`** | **`11.1gu`** | `11.1u` |
| `4l` | `4l` verbatim | `11.1u` | `11.1u` | `11.1u` |
| `007` | `007` verbatim | `11.1u` | `11.1u` | `11.1u` |
| `0` | `0` verbatim | `1e+01u` | `1e+01u` | **`1.11e-05`** |
| `17` | `17` verbatim | `11.1u` | `11.1u` | `11.1u` |
| `4` | `4` verbatim | `11.1u` | `11.1u` | `11.1u` |

**All eight cited values still stick, verbatim.** Nothing normalises them. (Two earlier
passes of this measurement reported `+4` becoming `4` and `6.` becoming `6.0`; that was an
`expr {... ? $x : ...}` ternary **in the probe**, which numifies its operand. The table
above was taken without one.)

### Three things the cited table did not say

1. **The headline consequence has changed.** Since 1345 the Results window no longer prints
   `(did not converge)` for these; it falls back to the raw text. The damage is now that
   every correctly measured value prints **unformatted** — `1.11e-05` where the sheet
   beside it prints `11.1u`. Still wrong, no longer a lie about the circuit.

2. **⚠ There is a class that does NOT raise, and it is worse.** `format %.${pr}g` pastes
   the precision into a format string, so a trailing conversion character **ends the
   specifier** and the `g` becomes literal text. A true `1.11e-05` prints as `11.1000gu`
   at `4f`, `11.1gu` at `4s`, `1.1100e+010gu` at `4e0`. Nothing raises, so 1345's
   fallback never engages, and the window and the annotation sheet **both** print a
   different number that reads like a measurement.

3. **⚠ The C side is not immune; it fails differently, and at the top of the range it
   aborts the program.** `tclgetintvar` is `atoi()`, so C never raises — it silently uses
   a *different* precision (`atoi("2.5")`=2, `atoi("abc")`=0, `atoi("4x")`=4), and at 0 it
   turns engineering notation **off** (`eval_expr.y` uses the precision as its own on/off
   flag), which is why `0` makes C answer `1.11e-05` where Tcl answers `1e+01u`. But
   `dtoa_eng` (`src/editprop.c`) `sprintf()`s into a `static char s[80]` with an indirect
   precision and no bound — its own comment says `my_snprintf` cannot be used there.
   MEASURED on this binary:

   ```
   ev_precision=72  xschem eval_expr {expr_eng(1e300*1.0)}  -> 79 chars, survives
   ev_precision=73  xschem eval_expr {expr_eng(1e300*1.0)}  -> *** buffer overflow
                                                               detected ***: terminated
   ```

   (SIGABRT, rc 134.) The arithmetic worst case — a negative value in the same `1e12`
   branch — needs one byte more, so **71** is the largest precision proven safe.
   `draw.c`'s `char tmpstr[100]` overflows at 92 by the same arithmetic.

## §2 The decision — DRIVER DECISION, taken 2026-09-22

> **Refuse a value the formatter cannot use, at the dialog, and say why. Do not silently
> keep the last good value.**

The reasoning, recorded here because it is also in the code comment: the current
behaviour's whole problem is **silence** — a keystroke that appears to work and quietly
poisons every displayed number afterwards. Keeping the last good value without saying so
replaces one silence with another. And this box is reached **deliberately from a menu**
rather than in passing, so an explicit refusal cannot be a surprise. If the dialog turns
out to be unwelcome, it is a one-line change.

### What counts as a legal precision — both bounds MEASURED, neither guessed

**A plain decimal integer from 1 to 71 inclusive.** Leading zeros are allowed and are
stripped (`007` is stored as `7`).

* **Ceiling 71** is the memory-safety boundary above: 73 aborts this binary inside
  `dtoa_eng`'s `sprintf`, 72 survives at exactly 80 bytes for a positive value, and the
  worst case needs one byte more than 72 leaves.
* **Floor 1** is a surface-agreement boundary: at 0, `eval_expr.y` reads
  `engineering = xctx->ev_precision` as "engineering off", so C prints `1.11e-05` while
  Tcl's `to_eng` prints `1e+01u`. Ruling **DD-7** (issue 1341) exists to stop exactly that
  disagreement. From 1 to 71 the two surfaces agree on every value measured.
* Everything else is refused because `format %.Ng` either raises on it or — the `4f`
  class — silently prints something else.

## §3 What changed

* **`src/xschem.tcl`, new `proc set_ev_precision`** (immediately above `proc to_eng`),
  with the measurement wall above it. Empty input is a **silent** no-op (Cancel, Escape,
  an emptied field); a whitespace-only field is refused like anything else; anything not
  matching `^0*([0-9]{1,3})$` or outside 1..71 is refused with an `alert_` that quotes
  back what was typed and states the precision that is still in force.
* **`src/xschem.tcl`, the `Simulation ▸ Set netlist / graph / annotation precision` menu
  entry**: `input_line "Enter precision (int):" "set ev_precision" $ev_precision` became
  `set_ev_precision [input_line "Enter precision (int 1-71):" {} $ev_precision]`.

**⚠ Why the validator is called on `input_line`'s RETURN VALUE and not as its `$cmd`.**
`input_line` holds a `grab set .dialog` across its OK callback. An `alert_` raised from
inside that callback maps a toplevel that nobody can click or dismiss, because the grab
sends every pointer and key event to `.dialog` — a deadlock, not a message. On the return
value the grab is already released. Cancel and Escape return the empty string, which the
silent arm handles.

**⚠ Why the rule is not inside `input_line`.** That proc is shared by the snap value, grid
spacing, line width, grid point size, symbol width, crosshair size, the bus replacement
characters and the top level netlist name — and since `2a22bfb7` the netlist name's legal
value is very nearly **any** string, spaces included. A generic validator there would have
to be either useless or wrong for most of its callers. A second box wanting a rule gets
its own proc.

## §4 The test

`tests/headless/test_input_line_inject_1352.tcl` (extended, not replaced — it already
drove this exact menu entry at `B18a`/`B18b`). Registered in `tests/run_regression.tcl` in
both `hcases` and `dcases`.

* **P1–P6 structural, both arms**: the menu entry names `set_ev_precision`, the literal
  `"set ev_precision"` command is gone from the file, and the proc still carries its
  digits-only pattern, its `1..71` range test and its `alert_`.
* **P7a–P17 behavioural, display arm**: the real menu entry, the real dialog, the real
  refusal. `abc`, `4f`, `72`, `0` and `9 ; set ::ILINJ yes` are each refused with the
  precision unmoved and the user told, naming what they typed; `6`, `71` and `007` land
  (`007` as `7`); an emptied field changes nothing and says nothing; after a refusal
  `to_eng` still formats. `P17` is the liveness row — every drive reached the real OK
  button.
* **`B18a` now measures the 1352 property off the refusal**, which quotes back the whole
  string it was given. A splice would have delivered `7` alone.
* Headless the P7–P17 rows print one `skip:` line, folded into the existing `BROWS` line.
* Check floor: **13** headless, **58** on the display arm.

## §5 Still open — 1 item, deliberately not taken here

**`dtoa_eng`'s unbounded `sprintf` into `static char s[80]` is still a live defect.** The
dialog is now not a door to it, but `~/.xschem/xschemrc` is: a line `set ev_precision 200`
reaches `ev_precision` without passing through `set_ev_precision`, and the first value
`dtoa_eng` scales into its `T` branch aborts the program. The same arithmetic applies to
`draw.c`'s four `char tmpstr[100]` sites and to `graph_marker_fmt`, which takes a
`destsize` and then `sprintf`s past it. Fixing that is a C change to the formatter, not to
a dialog, and it wants its own issue number.

## §6 What this issue is NOT

It is not a complaint about `to_eng` raising. Raising on `format %.abcg` is correct; the
defect was that `abc` ever reached it. It is not a request to change what
`(did not converge)` means — 1345 settled that. And it is not about the injection, which
`2a22bfb7` closed and which `B18`/`P11c` still fence at this entry.
