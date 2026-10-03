# 1633 — `table_read()` parses ASCII data with a **float** parser although the storage is `double`, and so does the ASCII raw reader

**STAMP:** `v1 claim=open tree=a90ffb98 stamped=2026-10-02 fix=none open=4`

Status: **OPEN**, found 2026-10-02 by the calculator batch's recon stages while establishing which
reader `cross` and the Calculator's import path may trust for a crossing time. Pre-existing; no
Calculator change caused it. **Highest-value item of the seven filed that day** — it silently costs
about five orders of magnitude of precision on every ASCII table anyone imports, and it killed a
design route on the day it was found.

Area: `table_read()` — `src/save.c` — the tree's **only** reader of the `SPICE_DATA_TYPE` macro,
and `read_raw_ascii_point()` in the same file, which reaches the same parser without the macro.
The parser is `my_atof()` — `src/util.c`. The macros are in `src/xschem.h`.
Found: `env -u DISPLAY ./src/xschem --pipe -q --nogui --script …` reading hand-written fixtures
through `xschem table_read` and `xschem raw read`, read back through `xschem raw values`
(which prints `%.16g`, so the measurement is the storage and not the print).

## The defect

`src/xschem.h` defines the storage type and a *separate* switch saying which parser to use, and the
two disagree:

```c
#define SPICE_DATA double
#define SPICE_DATA_TYPE 1 /* Use 1 for float, 2 for double */
```

`table_read()` is the only place in the tree that reads the switch, and it takes the `float` arm:

```c
#if SPICE_DATA_TYPE == 1 /* float */
raw->values[field][npoints] = (SPICE_DATA)my_atof(line_tok);
#else /* double */
raw->values[field][npoints] = (SPICE_DATA)my_atod(line_tok);
#endif
```

`my_atof()` is a hand-rolled **float** parser: `float value`, a `static const float p10[]` table of
eight entries, `float scale`, and `1E12f`/`1E4f` scaling constants. The value is therefore truncated
to single precision **and** to eight fractional digits *before* the cast widens it back to the
`double` the column actually holds. `my_atod()`, which the unused arm names, sits two functions
below in the same file with an eighteen-entry `p10[]` and `double` throughout — so the correct
parser already exists and is already declared; nothing calls it from here.

## Measured

Three values in one ASCII table, read through `xschem table_read`, read back with
`xschem raw values` (`%.16g`):

```
want=1.2345678901234567e-09   got=1.234567892360872e-09    rel=1.812e-09
want=3.141592653589793e-09    got=3.141592319622077e-09    rel=1.063e-07
want=0.0009999999999999998    got=0.0009999899193644524    rel=1.008e-05
```

The third line is a **real crossing time** — it is what the committed fixture's square wave crosses
0.5 at, and what `calc::cross` answers for it — and it is the one that matters, because it shows the
loss is **not bounded by single precision**. `float` would cost ~6e-8; this costs 1e-5. Two
independent truncations stack:

1. **float** itself, worth ~1e-7 relative;
2. the **eight-fractional-digit cap** in `my_atof()`'s `p10[]` (`if(cnt < 8)`), which on a *plain
   decimal* spelling of a small number throws away every digit after the eighth. `0.0009999999999999998`
   accumulates only `00099999` and stores `float(0.00099999)`.

The second one is spelling-dependent, and that is worth stating because it is the part a reader will
not predict. The **same value** written in scientific notation only loses the float term:

```
9.9999999999999980e-04  ->  0.0009999999310821295   rel=6.892e-08
1.0e-03                 ->  0.001000000047497451    rel=4.750e-08
```

So a table written by a tool that uses `%e` is ~1e-8 wrong, and the same table written with `%f` is
~1e-5 wrong, for the same numbers. **The error depends on how the producer formatted the file**,
which is the worst property a numeric reader can have.

## ⚠ The blast radius is wider than ASCII tables: ASCII `.raw` files lose it too

This is the half the recon that found the defect did not reach, and it is measured here.
`read_raw_ascii_point()` — the ASCII arm of `raw_read()` — carries the same choice without the
macro, as a deliberate optimisation with the `sscanf` alternative still in the file under `#if 0`:

```c
#if 0
if(sscanf(line,"%lf", &d) != 1) { … }
tmp[lines] = d;
#else /* faster */
tmp[lines] = my_atof(line);
#endif
```

The **sweep** column of an ASCII raw escapes, because the first line of each point block is parsed
by `sscanf(line,"%d %lf", &p, &d)`; every **other** column goes through `my_atof()`. Measured on a
hand-written three-point ASCII ngspice raw, the sweep came back exact and `v(a)` came back with the
same three errors as the table above, to the digit:

```
time: 0 1e-09 2e-09                       (exact)
v(a): 1.234567892360872e-09  3.141592319622077e-09  0.0009999899193644524
```

**A BINARY raw is unaffected**, and that is the control that proves the diagnosis: dataset 0 of
`tests/headless/data/calc_fixture.raw` reads back `time` as `0 0.0001 … 0.009999999999999995`, i.e.
the exact doubles the file holds, because that path `fread`s them and never parses text.

## Why nobody noticed

Every symptom is a plausible *simulator* artefact. A crossing time 1e-5 relative off a 1 ms edge is
10 ns, which reads as a timestep effect; a readout bar showing `0.00099999` instead of `0.001` reads
as display rounding. There is no diagnostic, no warning and no `dbg()` line anywhere on the path,
and the verb returns success. The one place it becomes undeniable is a *comparison* between a table
import and the binary raw of the same run — which is exactly what the recon stage was doing.

## Open items

1. **`table_read()` should call `my_atod()`.** The arm already exists, the function already exists
   and is already declared in `src/util.h`, and the storage is already `double`. Flipping
   `SPICE_DATA_TYPE` to `2` in `src/xschem.h` is the one-token spelling and is **not** obviously the
   right one, because the macro's name promises it describes `SPICE_DATA` and a future reader may
   change it for that reason; calling `my_atod()` unconditionally and deleting the dead arm says
   what is meant. Either way this is the item with the value in it.
2. **`read_raw_ascii_point()` has the same defect and a different remedy.** Its `my_atof()` is
   guarded by a comment reading `/* faster */` against the `sscanf` it replaced, so the trade was
   made knowingly — but `my_atod()` is the *third* option that was not on the table, and it is both
   fast and correct. Nothing measured here says the speed matters at all; that would want measuring
   before the comment is removed.
3. **The eight-digit cap is a defect in `my_atof()` on its own account** and is not fixed by either
   item above. `my_atof()` has other callers; a plain-decimal number with more than eight
   fractional digits is silently truncated for all of them. Filed as part of this item because it
   is the same measurement, not because the same change fixes it.
4. **A fence is owed and none exists.** No suite reads a table of known high-precision values and
   asserts what comes back — which is why a two-line macro disagreement survived. The row to write
   is: write a table whose values need more than single precision, read it, and compare against the
   same values read from a binary raw. **It must drive both spellings** (plain decimal and `%e`), or
   it will measure one of the two losses and miss the larger one.

## What this is NOT

Not a display or formatting defect: `xschem raw values` prints `%.16g` and `xschem raw value` prints
through `dtoa` (`%.8g`), and the measurements above are all from the `%.16g` door, so the digits
quoted are the storage.

Not a `my_atof()`-is-broken claim in general: for a `float` destination it is a reasonable fast
parser, cap included. The defect is that its destination here is a `double`.
