# 0213 — a malformed ASCII `Values:` block overruns `read_raw_ascii_point`'s buffer

**Status:** OPEN (pre-existing C defect; found while probing, NOT introduced by
the signal-browser batch)
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
