# 0298 — the ASCII raw reader trusts its own header

**Status:** OPEN. Three unbounded indices in the same reader, three measured crashes.
**Area:** `src/save.c` — `read_dataset()`'s `Variables:` arm and `read_raw_data_block()`'s
`ac` store loop.
**Found:** 2026-08-09, by the five-lens adversarial review of the issue 0213 fix.
**Pre-existing:** yes, all three. None of the lines below is inside a hunk of
`git diff -U0 -- src/save.c` for the 0213 change; every repro reproduces
identically on the pre-0213 binary and on the fixed one (both measured).
**Deliberately not fixed under 0213**, whose scope is `read_raw_ascii_point()`'s two
bounds. Widening that commit to cover a different function's pre-existing overruns
would be a silent scope expansion — the same call `0290` made under §C of the
mixed-signal spec, for the same reason: it is the user's decision, not a reviewer's.

Numbered 0298 to leave a gap above the local maximum 0297 (`github/open_pdk` is at 0263).

Everything below was measured on this tree with

```sh
cat > /tmp/p.tcl <<'EOF'
puts "RES=[catch {xschem raw read /tmp/x.raw tran} v]/$v"
puts "points=[catch {xschem raw points} p]/$p"
flush stdout
catch {xschem raw clear}
puts "SURVIVED-CLEAR"
exit 0
EOF
./src/xschem --nogui --pipe -q --nolog --script /tmp/p.tcl
```

and, where valgrind output is quoted, the same command under `valgrind -q`.

---

## Part 1 (HIGH) — the variable index from a `Variables:` line is never bounded

### Mechanism

`read_dataset()` sizes the name arrays straight from `No. Variables:`:

```c
/* src/save.c:1017 */
if(!raw->names)        raw->names        = my_calloc(_ALLOC_ID_, raw->nvars, sizeof(char *));
if(!raw->cursor_b_val) raw->cursor_b_val = my_calloc(_ALLOC_ID_, raw->nvars, sizeof(double));
my_realloc(_ALLOC_ID_, &varname, strlen(line) + 1) ;
n = sscanf(line, "%*[\t]%d%*[\t]%[^\t]", &i, varname);   /* :1020 */
if(n < 2) { ... "malformed raw file, aborting" ... }     /* :1021 — the ONLY check */
```

`i` comes from the file and is used unchecked:

* `my_strcat(_ALLOC_ID_, &raw->names[i], varname);` — `src/save.c:1060` (real);
* `my_strcat(_ALLOC_ID_, &raw->names[i << 2], varname);` — `src/save.c:1036` (AC), plus
  `[(i<<2)+1 .. +3]` immediately below it.

Nothing anywhere compares `i` to `raw->nvars`. The `n < 2` refusal at `:1021` is the only
validation the line gets, and it only asks whether the line *has* two fields.

### Repro 1a — one extra `Variables:` line, and the read still reports SUCCESS

```
Title: p1a
Plotname: Transient Analysis
Flags: real
No. Variables: 2
No. Points: 2
Variables:
	0	time	time
	1	v(out)	voltage
	2	v(extra)	voltage
Values:
0	0.0
	1.0

1	1e-8
	2.0

```

Observed (`xschem raw read … tran`):

```
Raw file data read: /tmp/p1a.raw
points=2, vars=2, datasets=1 sim_type=tran
RES=0/1
points=0/2
SURVIVED-CLEAR
```

i.e. it answers **1, success**, and only valgrind shows what happened:

```
==1768833== Invalid write of size 8
==1768833==    at 0x1DA8EC: my_strcat
==1768833==    by 0x1DF777: raw_read
==1768833==    by 0x1DED2C: extra_rawfile
==1768833==  Address 0x5d25dd0 is 0 bytes after a block of size 16 alloc'd
```

16 bytes = the two `char *` of `my_calloc(_ALLOC_ID_, raw->nvars=2, sizeof(char *))`.

### Repro 1b — an out-of-range index alone is enough

The same file with the second line changed to `\t99\tv(out)\tvoltage` (no extra lines,
`No. Variables: 2` still honest). Also reports success, and lands further out:

```
==1768839== Invalid write of size 8
==1768839==  Address 0x5d260d8 is 1 bytes after a block of size 7 alloc'd
```

— i.e. the write went through an unrelated 7-byte heap object, not merely off the end of
`names`.

### Repro 1c — enough of them and the editor dies

The same header with forty extra `Variables:` lines (indices 2…41):

```
rename dir (null) to /tmp/xschem_emergencysave_untitled-13_babdcaefef failed
EMERGENCY SAVE DIR: /tmp/xschem_emergencysave_untitled-13_babdcaefef

FATAL: signal 11
while editing: untitled-13
```

### Repro 1d — the AC arm, with a completely ordinary ngspice header order

`names[i << 2]` multiplies the reach by four, so an index only *one* past the end is fatal:

```
Title: ac oob index
Plotname: AC Analysis
Flags: complex
No. Variables: 2
No. Points: 1
Variables:
	0	frequency	frequency
	2	v(out)	voltage
Values:
0	1.0,0.0
	3.0,4.0

```

`xschem raw read /tmp/p1e.raw ac`:

```
EMERGENCY SAVE DIR: /tmp/xschem_emergencysave_untitled-13_fgafegfadf
FATAL: signal 11
```

and under valgrind, before the crash:

```
==1768893== Invalid write of size 8
==1768893==    at 0x1DA8EC: my_strcat
==1768893==  Address 0x5d25e40 is 0 bytes after a block of size 64 alloc'd
```

64 bytes = the eight `char *` that `No. Variables: 2` + `Flags: complex` produces
(`raw->nvars` is doubled at `src/save.c:973` and again at `:993`).

### Fix, when someone takes it

Bound `i` next to the existing `n < 2` refusal at `src/save.c:1021`, and refuse the file
the same way that branch does (`"malformed raw file, aborting"`, `extra_rawfile(3,…)`,
`exit_status = 0`, `goto read_dataset_done`) rather than skipping the line — a raw whose
`Variables:` indices do not match its own `No. Variables:` is not a file whose *values* can
be trusted either:

```c
if(n < 2 || i < 0 || i >= raw->nvars) { ... }
```

and, for the AC arm which writes `[(i<<2)+3]`, the test that actually covers it:

```c
if(ac_naming ? ((i << 2) + 3 >= raw->nvars) : (i >= raw->nvars)) { ... }
```

`(i << 2)` must be computed in a type that cannot overflow for a hostile `i`, or `i` must
first be range-checked against `raw->nvars >> 2`.

---

## Part 2 (MEDIUM) — the `ac` store loop steps past both of its allocations

### Mechanism

`read_raw_data_block()` sizes the per-point scratch buffer at half `raw->nvars`:

```c
rawvars = raw->nvars;          /* src/save.c:675, :684 */
if(ac) rawvars >>= 1;          /* :685 */
tmp = my_calloc(_ALLOC_ID_, rawvars, sizeof(double));
```

but the `ac` store loop walks `raw->nvars` in steps of four and touches `vv + 1` and
`v + 3`:

```c
for(v = 0; v < raw->nvars; v += 4) {   /* :755 */
  vv = v >> 1;
  ... tmp[vv], tmp[vv + 1] ...
  raw->values[v + 2][offset + p] = (SPICE_DATA)tmp[vv];       /* :769 */
  raw->values[v + 3][offset + p] = (SPICE_DATA)tmp[vv + 1];   /* :770 */
}
```

`raw->values` holds `raw->nvars + 1` pointers (`:728`), of which `0 … raw->nvars` were
`my_realloc`'d. The last iteration has `v = 4 * floor((raw->nvars - 1) / 4)`, so the loop
touches `values[v + 3]` — safe only when `raw->nvars % 4` is 0 or 3, out of range by one
pointer when it is 2, and by two when it is 1. `tmp[vv + 1]` runs past `tmp` for every
`raw->nvars` that is not a multiple of 4.

`raw->nvars` is a multiple of 4 exactly when `Flags: complex` **precedes**
`No. Variables:` — the ac doubling happens twice, at `src/save.c:973` and `:993`, and both are
driven by the `ac` flag as it stands *at that moment*. If `Flags:` comes after (or the
plot is not named as an AC plot but the flag says complex), `raw->nvars` is whatever the
header said and any value ≡ 1 or 2 (mod 4) reaches the overrun.

Residues 2 and 3 also give an **odd** `rawvars`, which an `ac` point (two doubles per
line) can never fill exactly, so those files are already refused as short by the 0213
bound. **Residue 1 is the reachable one**: `rawvars = (nvars-1)/2` is even, the point is
exactly full, the read is clean — and then the store loop runs off the end.

### Repro (measured, this tree)

```
Title: nvars5
Plotname: Transient Analysis
No. Variables: 5
No. Points: 1
Flags: complex
Values:
0	1.0,2.0

```

`xschem raw read /tmp/c5.raw tran` →

```
EMERGENCY SAVE DIR: /tmp/xschem_emergencysave_untitled-13_geaecgaefb
FATAL: signal 11
```

`No. Variables: 9` (also ≡ 1 mod 4, with two value lines) crashes identically.
`No. Variables: 8` in the same shape is the control and reads cleanly:
`points=1, vars=8, datasets=1 sim_type=tran`, `RES=1`, survives `raw clear`.

Under valgrind the order is: read past `tmp`, read past the `raw->values` pointer array,
then a write through the garbage pointer that came back.

### Note for whoever fixes it — a near miss already in the tree

`tests/headless/test_raw_ascii_point_bounds.tcl` group K builds **exactly this header
ordering** (`Plotname: Transient Analysis`, `No. Variables:`, then a late `Flags:
complex`) to get an odd per-point capacity — and picks **7**, which is ≡ 3 (mod 4): the
residue that keeps `values[v+3]` in range and is refused as a short point before the store
loop is ever reached. Change that 7 to a 5 and the suite crashes on a *different* bug. It
is worth recording that the fixture missed this by one residue class.

### Fix, when someone takes it

Either derive the loop bound from what was actually stored (`v + 3 < raw->nvars + 1`, i.e.
stop when a full quadruple does not fit) and clamp `vv + 1` to `rawvars`, or — better —
refuse the header outright: under `ac`, `raw->nvars % 4 != 0` means the file's own
`Flags:`/`No. Variables:` pair is inconsistent with the four-column (mag, phase, re, im)
layout the reader is about to build, and there is nothing sensible to store.

---

## Part 3 (LOW) — `No. Variables:` is an unsanitised allocation size

### Mechanism

`raw->names` and `raw->cursor_b_val` (`src/save.c:1017-1018`) are sized straight from the
header with no upper bound. `my_calloc` **soft-fails** — it logs and returns NULL rather
than aborting — and the NULL is then written through at `:1060` (`raw->names[i]`) or
`:1036` (`raw->names[i << 2]`).

The `rawvars <= 0` guard added by the 0213 fix (`:686`) does not cover this: it lives in
`read_raw_data_block()`, which runs at the `Values:` line, long after the header parse has
already allocated and dereferenced these arrays.

### Repro (measured, this tree)

```
Title: p3
Plotname: Transient Analysis
Flags: real
No. Variables: 2000000000
No. Points: 1
Variables:
	0	time	time
Values:
0	0.0

```

```
my_calloc(0,): allocation failure 2000000000 * 8 bytes
my_calloc(0,): allocation failure 2000000000 * 8 bytes
rename dir (null) to /tmp/xschem_emergencysave_untitled-13_gaddcebdeg failed
EMERGENCY SAVE DIR: /tmp/xschem_emergencysave_untitled-13_gaddcebdeg

FATAL: signal 11
```

### Fix, when someone takes it

Two independent things are missing and either alone would stop the crash:

* a sanity bound on `nvars` at the `No. Variables:` branch (`src/save.c:968`), refused
  through the same `"malformed raw file, aborting"` path the `n < 1` case uses;
* a NULL check after each `my_calloc` here, since `my_calloc`'s contract is to return NULL
  on failure — the callers at `:1017-1018` are simply not honouring it.

The second is the more valuable of the two: `raw->names`/`raw->cursor_b_val` are allocated
from `raw->nvars` at three sites (`:1017`, `:1421`, `:1884`) and none of them checks.
