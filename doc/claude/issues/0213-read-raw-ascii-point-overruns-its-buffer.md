# 0213 — a malformed ASCII `Values:` block overruns `read_raw_ascii_point`'s buffer

**Status:** FIXED 2026-08-09 — `src/save.c`, test
`tests/headless/test_raw_ascii_point_bounds.tcl` (90 checks). See "The fix, as
taken" at the bottom. (Pre-existing C defect; found while probing, NOT
introduced by the signal-browser batch.) The review's second finding, a defect in
the SIBLING function `skip_raw_ascii_points()`, was fixed and then **reverted**;
it is now filed separately as
`doc/claude/issues/0300-skip-raw-ascii-points-loses-a-dataset-it-should-have-skipped-past.md`
and remains open.
**Area:** `src/save.c` — `read_raw_ascii_point()` (:406) and its two call sites
in `read_raw_data_block()` (:504, :531)
**Raised by:** signal-browser PLAN item 13 (Location bar), while hand-writing
rawfile fixtures. Item 13 is Tcl-only under settled decision 8, so it FILED this
rather than fixing it, and routes around it: its malformed-raw check
(`tests/headless/test_wave_sigbrowser_i1315.tcl`, BR46) uses a PLAIN TEXT file,
which is measured safe, never a truncated `Values:` block.

## Symptom

`xschem raw read <file>` on an ASCII rawfile whose per-point blocks are not
terminated by an empty line corrupts the heap. Observed both ways, from the same
defect, depending on what the overflow lands on:

* `Warning: ascii block is not of correct size` … then `FATAL: signal 11`
  (plus an emergency-save directory);
* `Warning: ascii block is not of correct size` … the read *returns 1*, and the
  process dies later in `free_rawfile()` with
  `double free or corruption (out)`.

## Repro (measured, this tree)

```sh
cat > /tmp/bad.raw <<'EOF'
Title: malformed fixture
Date: Wed Jan 1 00:00:00 2026
Plotname: Transient Analysis
Flags: real
No. Variables: 2
No. Points: 2
Variables:
	0	time	time
	1	v(out)	voltage
Values:
0	0.0
	1.0
1	1e-9
	2.0
EOF
cat > /tmp/p.tcl <<'EOF'
puts "RC=[catch {xschem raw read /tmp/bad.raw} r]/$r"
flush stdout
exit 0
EOF
./src/xschem --nogui --pipe -q --nolog --script /tmp/p.tcl
```

Note what makes the file malformed: it is otherwise well-formed — the header
counts are right, the values are right — only the blank line that terminates
each point is missing. A well-formed twin (blank line after each point) reads
cleanly: `points=2, vars=2, datasets=1 sim_type=tran`.

(Since the fix, this exact file reads cleanly too, with the right values and no
warning — see "The fix, as taken" for why recovering it beats refusing it. The
fixture that still refuses is a point with too FEW values.)

## Mechanism

`read_raw_data_block()` allocates the per-point scratch buffer with exactly one
slot per variable:

```c
tmp = my_calloc(_ALLOC_ID_, rawvars, (sizeof(double)));
...
if(read_raw_ascii_point(ac, tmp, fd) != rawvars) {
   dbg(0, "Warning: ascii block is not of correct size\n");
}
```

`read_raw_ascii_point()` takes `tmp` but **not its capacity**, and its loop ends
only on an empty line or EOF:

```c
static int read_raw_ascii_point(int ac, double *tmp, FILE *fd)
{
  ...
  while(1) {
    if(!fgets(line, 1024, fd)) { ... return lines; }
    if(line[0] == '\n' || (line[0] == '\r' && line[1] == '\n')) break;
    ...
    tmp[lines] = my_atof(line);   /* no bound on `lines` */
    lines++;
  }
```

With the terminating blank line missing, the loop keeps consuming the NEXT
point's lines — and the one after that — writing `tmp[lines]` past the end of a
`rawvars`-element buffer. The `!= rawvars` test that produces the warning runs
only *after* the overflow has already happened, and it is a `dbg(0, ...)`
warning, not a refusal: the caller carries on and reports success.

## The fix, when someone takes it

Pass the capacity in and stop at it — the guard has to be inside the loop, since
the existing size check is a post-mortem:

* give `read_raw_ascii_point()` a `int maxvars` parameter (`rawvars` at both
  call sites) and `break` — or return a distinguished negative — as soon as
  `lines` would reach it (for `ac`, two slots are written per line, so the test
  is `lines + 1 >= maxvars`);
* make the two call sites TREAT a short/over-long point as a read FAILURE rather
  than a warning, so `xschem raw read` returns 0 and leaves no half-populated
  `Raw` behind. ⚠ Check what that does to the sweep1/sweep2 pre-count pass at
  :504, which runs the same reader over the same file before rewinding.

Both call sites already have the `rawvars` value in hand, so this is a local
change with no signature ripple beyond the static function itself.

## Not in scope

The binary path (`fread(tmp, sizeof(double), rawvars, fd)`) is already bounded by
`rawvars` and is not affected. Nothing here is specific to the waveform viewer,
the Location bar or the Signal Browser: any route into `xschem raw read` —
`Load raw`, the ASE plot path, a `.state` restore — reaches the same reader.

## Update 2026-08-09 — it TERMINATES the editor, it is not merely an overrun

Re-measured during the section-E adversarial review pass
(`doc/claude/specs/mixed_signal_signal_browser.md`), with no §E code in the path:
a plain `xschem raw read <f> tran` followed by `xschem raw clear` on an ASCII raw
whose point blocks are **not blank-separated** ends in

```
double free or corruption (out)
```

i.e. SIGABRT, taking the whole editor with it — the write past the
`my_calloc(rawvars)` buffer corrupts the allocator's metadata and the next
`free_rawfile()` is where it lands. `read_raw_ascii_point()` (`src/save.c:406-461`)
has no bound against `rawvars` and treats a blank line as its only terminator,
so a missing blank line simply keeps filling `tmp[lines]`.

That raises the severity: the title's "overruns its buffer" reads as a latent
memory bug, but the reachable outcome is an editor crash with unsaved work lost,
from opening a file. Two bounds are needed, not one: stop at `rawvars`, and treat
a line that does not parse as a number as end-of-point.

## The fix, as taken (2026-08-09)

`read_raw_ascii_point()` now takes `int maxvars` (`rawvars` at both call sites)
and ends a point on FOUR conditions, not two: the empty line, EOF, a full
buffer, and a line that does not start a number.

* **Buffer full.** `ac` writes two doubles per line, so a line may only be
  started while two slots are left: `lines + 1 >= maxvars`. On a full point the
  reader looks at the next line: the blank separator is consumed, and **anything
  else is pushed back with `xfseek()`**.
* **Non numeric line.** Only the first line of a point was ever validated
  (`sscanf "%d %lf"`); continuation lines went straight to `my_atof()`, which
  reads `"Plotname:"` as `0.0` and stored it as a sample.

**DECISION where the issue text was ambiguous** — "make the call sites treat a
short/over-long point as a read FAILURE": *short* is a hard failure, *over-long*
does not exist any more. With the bound plus the pushback, a rawfile that merely
omits the blank separators has complete points and reads **correctly**; refusing
it would throw away recoverable data for no safety gain, since the crash is
cured by the bound and not by the refusal. What IS a hard failure is a point
that delivers fewer than `rawvars` values: `read_raw_data_block()` returns 0,
`read_dataset()` stops and leaves `exit_status` alone (the same rule the nvars
mismatch above it already used), so `free_rawfile()` discards the half populated
`Raw`, `xschem raw read` returns 0, and datasets read cleanly *before* the bad
one are kept.

**The ⚠ pre-count pass (`:504`)**: it now stops on the first malformed point,
**still rewinds**, and propagates the failure, so the whole read gives up before
`raw->values` is grown — nothing half allocated, and the stream is left where
that pass found it. Its correctness depends on the pushback above: the pre-count
walks the same points a second time, so a reader that ate a line the first time
round would desynchronise the second. That is verified by group H of the test,
and by sabotage S6 (pre-count reader called without its capacity -> SIGABRT).

Also fixed in the same function: `rawvars <= 0` (a `No. Variables: 0` header)
built a zero capacity buffer that the reader still wrote into, and
`int rawvars = raw->nvars;` dereferenced `raw` one line above the `if(!raw)`
guard.

`tests/headless/test_raw_ascii_point_bounds.tcl` (90 checks, groups A–L,
`--nogui`, in the audit's `nogui_tests`) covers the repro, a 4x5 separator-less
block, the well formed twin, short points, junk lines, truncation, `ac`, the
sweep pre-count pass, the pushback (a second dataset whose header would
otherwise be eaten), `No. Variables: 0`, an odd per-point capacity and non finite
values (group L). Against the unfixed binary it does not merely fail, it
**aborts** (`double free or corruption (out)`, exit 134) before printing a single
named check, and never prints its RESULT banner.

Also fixed here, and KEPT through the revert below: `npoints` and `nvars` in
`read_dataset()` were uninitialised locals, while the `Values:`/`Binary:`
handlers read both unconditionally — four `dbg()` calls (`dbg()` is a function
in `util.c`, so its varargs are always evaluated), `skip_raw_ascii_points()`, and
`xfseek(fd, nvars * npoints * sizeof(double), SEEK_CUR)`, which seeks by an
indeterminate amount. A `Values:`/`Binary:` line ahead of either header line
reaches them with both unset. That defect predates this fix; the initialisers
address it and are not part of anything the fix added.

## Review follow-ups, same day — one regression, one false claim

An adversarial review of the fix above found two things. The first is fixed here.
The second turned out not to belong to this function at all: its fix was
reverted and it is now issue 0300, OPEN.

### 1. Bound 2 rejected non finite values, which cost the WHOLE file

`raw_ascii_number_line()` classified a value line as junk unless it started with
a digit, sign or dot — and `nan`, `-nan`, `inf`, `-inf` are exactly what a C
library's `%e` prints for a non finite double. Under bound 2 such a line ended
the point, the point was short, the dataset was a read failure, and one bad
sample anywhere cost every point of every signal in the file:

```
$ xschem raw read nan.raw tran           # 3 points, ONE `nan` sample in point 1
Warning: ascii block is not of correct size
read_dataset(): malformed ascii data block, aborting
raw_read(): no useful data found
RC=0 RES=0
points=1/No raw file loaded
```

Before the fix (HEAD binary, same file) the line fell through to `my_atof()`
(`src/util.c`), which answers 0.0 for a non numeric token, so the point was full
size and the file loaded intact:

```
Raw file data read: nan.raw
points=3, vars=2, datasets=1 sim_type=tran
RC=0 RES=1
points=0/3   v0=1  v1=0  v2=3
```

That is a *degraded* read turned into a *total* one — a regression, and the only
new defect the review found. `raw_ascii_number_line()` now accepts, case
insensitively and with an optional sign, `nan` (with an optional parenthesised
payload) and `inf`/`infinity`, and requires the word to END there, so `nancy`
and `information` still terminate the point. The reasoning is in the function's
comment; what the words STORE is unchanged (0.0 on the `my_atof` path).

**It is not a hypothetical foreign-writer case: ngspice-46 on this box writes
them.** `set filetype=ascii` in a `.control` block, then `write f.raw` of
`1e300*1e300` (`inf`), `ln(0)` (`-inf`) and `inf-inf` (`-nan`) produces an ASCII
raw whose value lines read `\tinf`, `\t-inf`, `\t-nan`. All of them now read;
group L pins nine spellings including ngspice's own byte-for-byte one.

### 2. The pushback's "reads CORRECTLY" claim was false for a SKIPPED block

`skip_raw_ascii_points()` is `read_raw_ascii_point()`'s sibling — it walks the
`Values:` block of a dataset the caller did not ask for — and it had not been
given the same treatment: `line[0] == '\n'` was its only point terminator (so it
did not know the CRLF separator the new `raw_ascii_blank_line()` helper knows)
and it had no per-point bound at all. Two measured losses, both of a perfectly
well formed Transient Analysis sitting behind a skipped Operating Point plot,
read with `xschem raw read <f> tran`:

* first plot separator-less → the skip runs past its own block, eats the tran
  header and the tran block's first point → `raw_read(): no useful data found`,
  returns 0. Adding one blank line after the skipped point makes the same file
  return 1 with `points=2`;
* the same file with CRLF endings throughout → `line[0]` is `'\r'`, nothing ever
  terminates a point, the skip eats the rest of the file → 0 again. The control
  isolates it: that CRLF file read as its FIRST plot (nothing skipped) reads
  fine.

**Fixed, then REVERTED, and finally NARROWED (2026-08-09).** The first attempt
made the skip count VALUE LINES (`npoints * lines_per_point`, taken from the same
header the block was written from, `nvars>>1` per line for `ac`) and treat any
blank line as a separator, so separator-full, separator-less and CRLF files all
landed in the same place. It was pinned by a group M of 20 checks.

That was reverted, because measurement showed it trusts a header that may
**over-declare** its own block, and then over-skips into the following plot's
`Plotname:` line with nothing to stop it. On a three-plot raw (tran, an
Operating Point plot declaring `No. Variables: 6` while writing 2, tran) read as
`tran`, HEAD gives `read=1, datasets=2, points=4, time = 10 20 50 60` and the
counting version gives `read=1` — still SUCCESS — with `datasets=1`,
`points=2`, `time = 10 20`: the second dataset silently deleted, no diagnostic.
Silent deletion under a successful return is worse than the loud
`no useful data found` it was curing, so the trade was refused.

`skip_raw_ascii_points()` is therefore back to its HEAD body, group M is gone
(90 checks remain, groups A–L, all passing), and `read_raw_ascii_point()`'s
comment now claims only what it delivers: the pushback recovers a separator-less
block **this reader reads**; a separator-less block it **skips** is still lost.
That residual defect, with both reproductions re-verified against the reverted
tree and a "why the obvious fix is not obvious" section carrying the measurements
above and the `nvars`-not-reset-per-plot trap, is filed as **issue 0300** and is
OPEN.
