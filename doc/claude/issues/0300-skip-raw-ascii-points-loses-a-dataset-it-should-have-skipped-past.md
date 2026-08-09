# 0300 — `skip_raw_ascii_points()` walks past the dataset it should have skipped, and costs the whole read

Status: **OPEN**. A fix was written and **REVERTED** on 2026-08-09 (see "Why the
obvious fix is not obvious"); nothing in the tree fixes this today.
Area: `src/save.c` — `skip_raw_ascii_points()` (:411) and its one call site in
`read_dataset()` (:841).
Tests: none. `tests/headless/test_raw_ascii_point_bounds.tcl` covers the sibling
reader `read_raw_ascii_point()` (90 checks, groups A–L) and explicitly says in
its header that the skip is out of scope and lives here.
Found: 2026-08-09, in the adversarial review of the issue 0213 fix — the fix's
own comment claimed a property ("a separator-less file reads correctly") that is
false for a block xschem *skips*, and checking that claim turned this up.
**Pre-existing**: present at `HEAD` (299a9bc2) and long before; the 0213 fix
neither introduced nor worsened it.
Numbered 0300 to leave a gap above the local maximum 0299 (`github/open_pdk` is
at 0263).

## The shape of it

`read_dataset()` walks every plot in a rawfile, but only *reads* the one whose
`Plotname:` matches the requested type. Every other plot's `Values:` block has to
be **skipped** — the file pointer must land exactly on the line after the block,
because the next thing `read_dataset()` does is keep scanning for headers.

`skip_raw_ascii_points()` does that skip by walking to a blank line, `npoints`
times, and it has exactly one terminator and no bound at all:

```c
/* src/save.c:411 */
static void skip_raw_ascii_points(int npoints, FILE *fd)
{
  char line[1024];
  int i;
  for(i = 0; i < npoints; i++) {
    while(1) {
      if(!fgets(line, 1024, fd)) { dbg(1, "premature end of ascii block\n"); return; }
      if(line[0] == '\n') { dbg(1, "found empty line --> break\n"); break; }
    }
  }
}
```

Two ways a legal rawfile has no `line[0] == '\n'` where this expects one:

* **the writer omitted the blank separators.** The points are complete and the
  header counts are right; only the separators are missing. The sibling reader
  `read_raw_ascii_point()` handles exactly this shape since issue 0213 (it is
  0213's own repro file), so the *read* path recovers it and the *skip* path
  does not.
* **the file uses CRLF line endings.** A blank line is then `"\r\n"`, and
  `line[0]` is `'\r'`. `read_raw_ascii_point()` has known this since before 0213
  (`line[0] == '\n' || (line[0] == '\r' && line[1] == '\n')`, now the shared
  helper `raw_ascii_blank_line()` at `src/save.c:390`); the skip never learned it.

In both cases the inner `while(1)` does not stop at the end of the block. It
keeps eating lines — through the next plot's `Plotname:`, `No. Variables:`,
`Values:` and into its data — until it happens to find a blank line or hits EOF.
`read_dataset()` resumes from wherever that left off, so the plot the caller
actually wanted is gone: its header was consumed inside the skip loop and never
reached the header scan.

## Repro (measured, this tree, 2026-08-09, binary built from the reverted tree)

Two plots. The first is an Operating Point plot the caller does not want, the
second is a **completely well-formed** Transient Analysis. The only irregularity
in the whole file is the missing blank line after the op plot's single point:

```sh
cat > /tmp/skip_noblank.raw <<'EOF'
Title: separator-less op, then a good tran
Plotname: Operating Point
Flags: real
No. Variables: 2
No. Points: 1
Variables:
	0	v(1)	voltage
	1	v(2)	voltage
Values:
0	1.0
	2.0
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

1	1e-8
	2.0

EOF
cat > /tmp/p.tcl <<'EOF'
puts "RES=[catch {xschem raw read $env(F) tran} r]/$r"
puts "points=[catch {xschem raw points} p]/$p"
flush stdout
exit 0
EOF
F=/tmp/skip_noblank.raw ./src/xschem --nogui --pipe -q --nolog --script /tmp/p.tcl
```

Observed:

```
free_rawfile(): clearing data
raw_read(): no useful data found
extra_rawfile() read: /tmp/skip_noblank.raw not found or no "tran" analysis
RES=0/0
points=1/No raw file loaded
```

**The control that isolates it to the separator**: insert ONE blank line after
the op plot's `\t2.0` and change nothing else. Same command, same binary:

```
Raw file data read: /tmp/skip_blank.raw
points=2, vars=2, datasets=1 sim_type=tran
RES=0/1
points=0/2
```

### Repro 2 — CRLF

The same two plots, *with* the blank separators, written with CRLF endings
throughout (every line, separators included):

```
free_rawfile(): clearing data
raw_read(): no useful data found
extra_rawfile() read: /tmp/skip_crlf.raw not found or no "tran" analysis
RES=0/0
points=1/No raw file loaded
```

Here the skip does not merely over-run its own block, it eats the **rest of the
file**: no line in a CRLF file ever satisfies `line[0] == '\n'`, so the inner
loop only ends at EOF.

**The control that isolates it to the SKIP**, not to CRLF parsing in general:
the same CRLF Transient plot with nothing in front of it — i.e. the wanted plot
is the first one and nothing is skipped — reads fine:

```
Raw file data read: /tmp/crlf_only.raw
points=2, vars=2, datasets=1 sim_type=tran
RES=0/1
points=0/2
```

## Why the obvious fix is not obvious

The obvious fix is to stop walking to a blank line and instead **count value
lines**: the plot's own header says `No. Points:` and `No. Variables:`, a point
occupies one value line per variable (half that for a complex/`ac` plot, which
puts `re,im` on one line), so the block is `npoints * lines_per_point` value
lines — treat any blank line as a separator and `continue` past it, and
separator-full, separator-less and CRLF files all land in the same place.

That was written, and it does cure both reproductions above. **It was reverted
the same day**, because it trades one loss for a worse one: it *trusts a header
that may over-declare its own block*, and an over-declared count marches
straight through the next plot's `Plotname:` line with nothing to stop it.
Measured against the counting version:

* a three-plot raw — Transient, then an Operating Point plot declaring
  `No. Variables: 6` while listing 2 variables and writing 2 value lines, then a
  second Transient — read as `tran`. The reverted tree (= HEAD) gives
  `read=1, datasets=2, points=4, time = 10 20 50 60`. The counting version gives
  **`read=1` (still SUCCESS), `datasets=1`, `points=2`, `time = 10 20`** — the
  second Transient dataset is silently deleted, with no diagnostic anywhere. The
  over-skip ate its `Plotname:` line, so as far as `read_dataset()` is concerned
  that plot never existed.
* the two-plot shape of the same lie — a skipped op with a too-large
  `No. Variables:` followed by the *only* Transient — is total loss: the
  counting version answers `read=0`, `no useful data found`, where the reverted
  tree answers `read=1` with `points=2`. Same outcome for a fixture whose
  `No. Points:` is over by one plus a spare blank line.

Silent single-dataset deletion under a successful return is a strictly worse
failure than the loud `no useful data found` this issue is about, so the trade
is not acceptable.

There is a second trap waiting for any per-plot sizing scheme, found in the same
review: **`nvars` is never reset per plot.** It is a `read_dataset()`-scope
local (`src/save.c:797`) written only by the `No. Variables:` header branch
(`src/save.c:950`); the `Values:`/`Binary:` handlers reset `done_points` and
`ac` but not `nvars` or `npoints`. A plot whose header carries no
`No. Variables:` line therefore does not get "no size available", it silently
**inherits the previous plot's size** and over-runs with that. Any
`lines_per_point <= 0` fallback is unreachable for every plot after the first —
and a test that exercises that fallback in the FIRST-plot position (where the
variable is still at its initial 0) will pass while proving nothing.

## Fix, when someone takes it

The count is usable, but only as a **bound**, never as the walk itself. A
correct skip has to satisfy all three of:

1. **resynchronise on a blank separator** — CRLF-aware, i.e. via the existing
   `raw_ascii_blank_line()` helper (`src/save.c:390`). A blank line ends the
   current point no matter what the count says, so a file whose header
   *under*-declares cannot desynchronise the walk either.
2. **stop dead at a line that begins a new header** — `Plotname:` at minimum,
   and cheaply also `Title:`/`Date:`/`Flags:`/`No. `/`Variables:`/`Values:`/
   `Binary:`. This is the property that makes a lying header harmless: whatever
   the count claims, the skip can never carry the reader past the next plot. It
   needs the same pushback discipline `read_raw_ascii_point()` uses (`xftell()`
   before the read, `xfseek()` back) so the header line is handed to
   `read_dataset()`'s scan rather than eaten.
3. **use `npoints * lines_per_point` only as an upper bound** on how far to walk
   before giving up, so a block with neither separators nor a following header
   (i.e. the last plot in the file) still terminates.

Sizing input must be taken per plot: reset `nvars`/`npoints` to 0 at each
`Plotname:` (or pass them explicitly), or point 3 inherits the previous plot's
numbers per the trap above. `nvars` has already been doubled for an `ac` plot by
the time the `Values:` handler runs, so the value-lines-per-point there is
`nvars >> 1`.

Worth pinning with a regression group in
`tests/headless/test_raw_ascii_point_bounds.tcl` alongside groups A–L, covering
at least: separator-less skipped plot, CRLF skipped plot, CRLF control (wanted
plot first), skipped `ac` plot, truncated skipped block, an over-declared
`No. Variables:` in front of a plot that must survive, an over-declared
`No. Points:`, and a sizeless plot in NON-first position.

## Not in scope

`read_raw_ascii_point()` is a different function and is already bounded — issue
0213, fixed. The binary skip path
(`xfseek(fd, nvars * npoints * sizeof(double), SEEK_CUR)`, `src/save.c:866`)
trusts the same header arithmetic but seeks rather than parses, so a lying
header there lands the stream in the middle of the next section instead of
deleting it; that is issue 0298's territory ("the ascii raw reader trusts its
own header"), not this one.
