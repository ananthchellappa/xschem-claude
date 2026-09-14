# What `onoise_total` is, and what `Nintegrate()` does — debt **M10**, answered

**Measured 2026-09-13 by the driver**, in the ngspice source at
`/home/analog/dev/ngspice` and against a circuit whose answer is known in closed form, on
**both** binaries. M10 recorded that *"`Nintegrate()`'s definition was never located, so nobody can
explain an `onoise_total` number to a user"* — and the Outputs Value column shows that number.

## 1. `Nintegrate()` — `src/spicelib/analysis/ninteg.c`

It integrates the noise between **two adjacent frequency points**, on the assumption that the
density follows a power law between them:

```
NOISE = a · f^EXPONENT          exponent = (ln N₂ − ln N₁) / Δ ln f
```

Three branches, and the thresholds are both `1E-10` (`noisedef.h:109,113`):

| when | what it returns | the physical case |
|---|---|---|
| `|exponent| < N_INTFTHRESH` | `noizDens · Δf` | **flat** — white noise, a rectangle |
| `|exponent + 1| < N_INTUSELOG` | `a · (ln f₂ − ln f₁)` | **1/f** — flicker, where the ordinary power rule divides by zero |
| otherwise | `a · (f₂^(e+1) − f₁^(e+1)) / (e + 1)` | any other slope |

`limexp()` clamps the exponential at 700 to avoid overflow. The `N_INTUSELOG` branch exists purely
because **exponent = −1 is the case the general formula cannot express** — which is flicker noise,
i.e. the case that matters most in analog design.

⚠ **So the total is not a sum of samples and it is not a trapezoid.** It is an analytic integral
per interval, exact for any density that really is a power law between two adjacent points, and the
error is entirely in that assumption. **A user who doubles the point count changes the answer** —
not because the simulator is noisy, but because the piecewise power-law fit gets closer to the true
curve.

## 2. The units, measured rather than assumed — **it is RMS, not squared**

A current source into a single 1 kΩ resistor has a known thermal noise density, so the integral is
known in closed form:

```
i1 0 out ac 1
r1 out 0 1k
.control
noise v(out) i1 lin 2001 1 1meg 1
print onoise_total inoise_total
.endc
```

| | apt 45.2 | the fork | closed form |
|---|---|---|---|
| `onoise_total` | `4.071369e-06` | `4.071369e-06` | **√(4kTR · Δf) = 4.071370e-06** |
| `onoise_spectrum[0]` | `4.071372e-09` | `4.071372e-09` | √(4kTR) = 4.0714e-09 |
| `inoise_total` | `4.071369e-09` | `4.071369e-09` | the above ÷ the 1 kΩ transimpedance |

**Seven significant figures, both binaries.** `4kTR = 1.657607e-17 V²/Hz` at T = 300.15 K, and
Δf = 10⁶ − 1, so the *integral* is 1.6576e-11 V² — and what ngspice prints is its **square root**.

Confirmed in source: `src/spicelib/analysis/cktnoise.c:113` and `:126` —
`data->outpVector[i] = sqrt(data->outpVector[i]);` — applied to the whole output vector before it
is written. **Both the spectrum and the totals are square-rooted.**

So:

* **`onoise_spectrum` is V/√Hz**, not V²/Hz.
* **`onoise_total` is V RMS**, not V².
* `inoise_total` is the same quantity referred to the input, in the input source's units.

## 3. The sentence a tooltip can actually say

> **`onoise_total`** — the RMS noise at the output over the whole swept band. ngspice integrates
> the squared spectral density between adjacent frequency points, fitting a power law across each
> interval (with a separate closed form for the 1/f case), sums the intervals and takes the square
> root. **Its value depends on the sweep range and, slightly, on the number of points.**

That last clause is the part worth showing, and it is the part nobody could have written before
this was measured: the number is not a property of the circuit alone.

## What this leaves

* **M10 is closed.**
* **Not measured:** how far the point count actually moves the answer on a real flicker-dominated
  circuit — the flat resistor case above is exact at any point count by construction, so it cannot
  show the sensitivity the tooltip warns about. Worth one deck when Stage 8's Value column is
  revisited; it does not block anything.
