# 0299 — a truncated BINARY raw reads as a success with a fabricated final point

**Status:** OPEN. A fix (`res = 0; break;` at both sites) was written under item 0807 on
2026-08-25, measured sound, then **reverted with the rest of that item** — see
[0807](0807-annotate-op-destroys-the-attached-op-database-on-a-truncated-raw.md) §7.
Anchors `:702`/`:738` below have **drifted**; locate the two `fread` sites by name inside
`read_raw_data_block()`.
**Area:** `src/save.c` — the binary arm of `read_raw_data_block()` (`:702` in the
sweep pre-count pass, `:738` in the store pass).
**Found:** 2026-08-09, by the five-lens adversarial review of the issue 0213 fix.
**Pre-existing:** yes. Neither `fread` line is inside a hunk of
`git diff -U0 -- src/save.c` for the 0213 change; both appear in that diff only as
context.
**Deliberately not fixed under 0213**, whose scope is `read_raw_ascii_point()`'s two
bounds — the ASCII path. Reaching across to change what the *binary* path does with a
short block is a different decision with a different blast radius (every binary raw
xschem has ever opened), and making it silently inside a bounds fix would be a scope
expansion. Precedent and reasoning: the closing paragraph of
`doc/claude/issues/0290-raw_read-bypasses-the-non-spice-reader-dispatch.md`.

Numbered 0299 to leave a gap above the local maximum 0297 (`github/open_pdk` is at 0263).

## Since 0213 this is an INCONSISTENCY as much as a bug

The two arms of one function now disagree about what a short block means:

```c
/* src/save.c, read_raw_data_block(), the store pass */
if(binary) {
  if(fread(tmp, sizeof(double), rawvars, fd) != rawvars) {
    dbg(0, "Warning: binary block is not of correct size\n");   /* :738 — warn, carry on */
  }
} else {
  if(read_raw_ascii_point(ac, tmp, rawvars, fd) != rawvars) {
     dbg(0, "Warning: ascii block is not of correct size\n");
     res = 0;                                                    /* 0213 — hard failure */
     break;
  }
}
```

The identical condition — "this point did not deliver `rawvars` values" — is a refusal on
one side of the `if` and a log line on the other. Whatever the right answer is, it should
not depend on which encoding the same simulator happened to write.

## Repro (measured, this tree, with a real ngspice-46 raw)

```sh
cat > /tmp/rc.cir <<'EOF'
* rc transient for binary raw fixture
v1 1 0 dc 0 pulse(0 1 0 1n 1n 50n 100n)
r1 1 2 1k
c1 2 0 1p
.tran 1n 60n
.end
EOF
ngspice -b -r /tmp/rc.raw /tmp/rc.cir          # 2917 bytes: 293 header + 82 points x 4 vars x 8
head -c 2905 /tmp/rc.raw > /tmp/rc_trunc.raw   # lose the last 12 bytes, as a killed sim would

cat > /tmp/b.tcl <<'EOF'
puts "RES=[catch {xschem raw read $env(RAWF) tran} v]/$v"
puts "points=[xschem raw points]"
foreach i {80 81} {
  puts "  time\[$i\]=[xschem raw value time $i] v(2)\[$i\]=[xschem raw value v(2) $i] i(v1)\[$i\]=[xschem raw value i(v1) $i]"
}
flush stdout
exit 0
EOF
RAWF=/tmp/rc.raw       ./src/xschem --nogui --pipe -q --nolog --script /tmp/b.tcl
RAWF=/tmp/rc_trunc.raw ./src/xschem --nogui --pipe -q --nolog --script /tmp/b.tcl
```

Intact file:

```
Raw file data read: /tmp/rc.raw
points=82, vars=4, datasets=1 sim_type=tran
RES=0/1
points=82
  time[80]=5.9427994e-08 v(2)[80]=0.00026858046 i(v1)[80]=2.6858046e-07
  time[81]=6e-08         v(2)[81]=0.00014911757 i(v1)[81]=1.4911757e-07
```

Truncated by 12 bytes:

```
Warning: binary block is not of correct size
Raw file data read: /tmp/rc_trunc.raw
points=82, vars=4, datasets=1 sim_type=tran
RES=0/1
points=82
  time[80]=5.9427994e-08 v(2)[80]=0.00026858046 i(v1)[80]=2.6858046e-07
  time[81]=6e-08         v(2)[81]=0.00026858042 i(v1)[81]=2.6858046e-07
```

`xschem raw read` returns **1**. `raw points` reports the full 82. The final point is
fabricated: `i(v1)[81]` is byte-for-byte point 80's value, and `v(2)[81]` is a splice —
`fread` returned 2 complete items but still deposited the 4 leading bytes of the third
double, so the low half of `v(2)[81]` is point 81's and the high half is point 80's
(0.00026858042 vs the true 0.00014911757 and the stale 0.00026858046). No caller can tell:
the one `dbg(0)` line goes to the log, the command reports success, and every downstream
consumer — the viewer, `raw value`, ASE annotation — sees a full-length dataset.

A simulator killed mid-write (Ctrl-C, a full disk, a scheduler timeout) is the ordinary way
to produce this file.

## Mechanism

`read_raw_data_block()` allocates `tmp` once, outside the point loop, and reuses it for
every point. A short `fread` leaves the untouched tail of `tmp` holding the *previous*
point's values, and the store loop below copies all `rawvars` slots regardless:

```c
for(v = 0; v < raw->nvars; v++) raw->values[v][offset + p] = (SPICE_DATA)tmp[v];
```

`p` is then incremented, so the point counts up to the header's `No. Points:` no matter how
little was read, and `raw->npoints[raw->datasets]` keeps that number.

The same unchecked `fread` appears in the sweep1/sweep2 pre-count pass at `:702`.

## Fix, when someone takes it

Mirror what the ASCII arm now does — it is two lines, and the `res`/`break`/`return 0`
plumbing the 0213 fix added is already in place for exactly this:

```c
if(fread(tmp, sizeof(double), rawvars, fd) != rawvars) {
  dbg(0, "Warning: binary block is not of correct size\n");
  res = 0;
  break;
}
```

at both `:702` and `:738`. `read_dataset()` already turns a `read_raw_data_block()` failure
into "keep the datasets that read cleanly, discard this one, return 0 if there were none".

⚠ Decide deliberately whether a truncated binary raw should be **refused** or **truncated
to the points that were actually read**. Refusing matches the ASCII arm and is the safer
default, but a killed long simulation is precisely the case where a user wants the first
99% plotted; if that is the goal, the fix is to stop at the short point and set
`raw->npoints[raw->datasets] = p` rather than the header's count — and then the ASCII arm
should be revisited to match, since the argument applies equally there. What is not
defensible is the present answer: report success and serve a point that was never in the
file.


---

## Addendum, 2026-08-25 (item 0807) — measured, and the cost of "refuse" is larger than it looks

0807 needed this fixed to have any effect at all: ngspice writes **binary** raws by default,
so the user's reported bench case goes through this arm, and a swap-only-on-success fix in
`annotate_op` swaps happily because this read *reports success*.

Two measurements worth keeping:

* **The asymmetry is total.** ASCII truncation is all-or-nothing — at 14 truncation offsets
  of a 194-byte op raw and 10 of a 197-byte 5-point tran raw, every short read already
  failed. Binary truncation **never** failed. The same condition gets opposite answers
  purely from the encoding the simulator chose.
* **Refusing is not free, and this is the number the decision needs.** A real
  `/usr/local/bin/ngspice-46+` **59-point binary transient missing 3 bytes** currently loads
  all 59 points with the last one fabricated; under the `res = 0; break;` fix it loads
  **nothing at all**. Well-formed files were confirmed unaffected: op (267 B), tran (2148 B,
  59 pts), ac (4177 B, 61 pts), concatenated pairs, and each with 16 bytes of trailing junk
  all still read with unchanged point counts — **trailing junk is not truncation**.

**The open question is therefore user-facing and unratified**, which is why item 0807 came
back status **E**: *a binary raw from a simulation killed mid-write today loads with its last
point fabricated and plots; should it instead refuse and plot nothing?* Refusing is right for
a 1-point op raw — there is no 99% of one point. For a long transient polled while ngspice is
still writing it, refusing turns a slightly-wrong plot into no plot. The one-line alternative
(`raw->npoints[raw->datasets] = p`) is in the same place, and adopting it obliges revisiting
the ASCII arm to match.
