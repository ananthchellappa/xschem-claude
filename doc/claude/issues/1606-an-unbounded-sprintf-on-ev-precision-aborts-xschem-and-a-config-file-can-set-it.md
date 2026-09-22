# 1606 — an unbounded `sprintf` on `ev_precision` aborts xschem, and a config file can set it

**STAMP:** `v1 claim=open tree=635587968567e4 stamped=2026-09-22 fix=untried open=4 by=driver`

**Status: OPEN — filed 2026-09-22** by the driver, from the 1602 crew's measurement and
its explicit *"this wants a number and a crew"*. **Class** memory safety — an unbounded
`sprintf` with an indirect precision into a fixed buffer.
**Related, read first:** **1602** (the precision dialog now refuses anything outside
1–71 — **FIXED** in `63558796`; **its ceiling of 71 comes from this defect**, and the
dialog is only one of the ways `ev_precision` gets set).

---

## The defect — MEASURED

`dtoa_eng` in `src/editprop.c`:

```c
char *dtoa_eng(double i, int precision)
{
  static char s[80];
  ...
    /* can not use my_snprintf() here due to indirect precision */
    if(suffix == 'M')
      n = sprintf(s, "%.*gMEG", precision, i);
    else
      n = sprintf(s, "%.*g%c", precision, i, suffix);
  ...
}
```

`precision` arrives from `xctx->ev_precision`, which C reads with `tclgetintvar` —
`atoi()`, so it never raises and never validates. The buffer is 80 bytes and there is no
bound. The comment is honest about why `my_snprintf` is not used (it does not understand
the `*` precision) and stops there.

MEASURED by the 1602 crew on the shipped binary:

```
ev_precision=72   xschem eval_expr {expr_eng(1e300*1.0)}  -> 79 chars, survives
ev_precision=73   xschem eval_expr {expr_eng(1e300*1.0)}  -> *** buffer overflow
                                                             detected ***: terminated
```

SIGABRT, rc 134. The sweep taken was 71 → 78 chars, 72 → 79, and 73, 74, 75, 80, 90, 99,
100, 200, 400 and 1000 all abort. The arithmetic worst case — a negative value in the same
`1e12` branch, with a three-digit exponent — needs one byte more than 72 leaves, which is
why **71** is the largest value anyone has proven safe and why 1602's dialog stops there.

## Why 1602 does not close it

1602 validates **the dialog**. `ev_precision` is an ordinary Tcl global, and the dialog is
not the only writer:

* **`~/.xschem/xschemrc`.** A line `set ev_precision 200` in a user's own rc file reaches
  the variable without passing through any dialog. That is a **startup-time landmine**:
  nothing goes wrong until a value lands in the `1e12` branch, and then the process
  aborts.
* **`--preinit 'set ev_precision N'`**, which the test suites themselves use (issue 1345
  records it).
* **Any Tcl** — a `tcleval` property on a schematic, a helper script, a menu hook.

So the fix belongs in C, at the point of use, not in any one writer.

## Two more sites, and they are not equally bad — READ at `63558796`

| site | shape | verdict |
|---|---|---|
| `src/draw.c` ×2 (near `:4933` and `:4995`, the cursor readout) | `sprintf(tmpstr, "%.*g%c", xctx->ev_precision, …)` into `char tmpstr[100]` | **Same defect, wider buffer.** Unclamped `ev_precision` straight from `xctx`. Overflows later than 80 bytes does, not never. |
| `src/draw.c` `graph_marker_fmt` (`:7716`) | takes `int destsize` and then `sprintf`s past it, ignoring it | ⚠ **Not currently exploitable, and the issue should say so.** All four of its callers (`:7830`, `:7831`, `:7846`, `:7847`) sit in one function, below `if(prec > 17) prec = 17;` at `:7810`, with a comment saying that is exactly why. It is a **latent** hazard: a fifth caller added without the clamp reintroduces it, and the signature invites one by taking a `destsize` it does not honour. |

The 1602 crew reported the third as live. Re-reading it here, it is not — the clamp is
there and documented. Recorded that way rather than inherited, because an issue that
overstates one of its three sites gets the other two discounted with it.

## The shape a fix takes

The comment's premise — that `my_snprintf` cannot do `%.*g` — is the constraint, not the
conclusion. At least three ways past it, and the choice needs measuring rather than
picking:

1. **Clamp at the point of use.** One line in `dtoa_eng`, and the same in the two `draw.c`
   sites. Cheapest, and it makes the C side agree with 1602's dialog instead of merely
   not crashing. ⚠ It also **silently changes** what a user with `set ev_precision 200` in
   their rc sees, which is a behaviour change on an obscure path and should be stated, not
   slipped in.
2. **Size the buffer from the precision** — compute the worst case and `my_malloc`. Removes
   the ceiling instead of enforcing it, at the cost of `dtoa_eng`'s `static char` contract,
   which ~70 call sites rely on by holding the result as a `const char *`.
3. **Give `my_snprintf` the `*` precision.** Fixes the class everywhere rather than three
   sites, and is the largest change. `graph_marker_fmt`'s comment records what happens
   today when someone assumes it already works: the house `my_snprintf` consumed the `int`
   as the `double` and produced
   `700.0000000000001136868377216160297393798828125` with the suffix swallowed.

**Recommendation: 1, and open a second issue for 3.** Clamping is the only one of the
three that can land today without a redesign, and the disagreement it leaves — a user's rc
asking for 200 and getting 71 — is smaller than the process aborting.

## Still open

1. Fix `dtoa_eng`, and the two `draw.c` cursor-readout sites with it. They share the
   defect and a fix to one alone leaves a live one.
2. Decide and state what an out-of-range `ev_precision` from a non-dialog writer should
   do — clamp silently, clamp and warn once, or refuse at startup. 1602 chose "refuse and
   say why" for the dialog on the grounds that silence is the original defect; the same
   argument does not automatically carry to a config file read before there is a window
   to put a message in.
3. A test row. Cheap and headless: set `ev_precision` past the ceiling by `--preinit`, ask
   for a value in the `1e12` branch, and assert the process survives with a sane string.
   ⚠ It must assert on the **exit code**, not only the output — the failure mode is
   SIGABRT, and a suite that only diffs text would read the death as an empty answer.
4. `graph_marker_fmt` should either honour its `destsize` or stop taking one. Latent, not
   live; do it with item 1 while the file is open.
