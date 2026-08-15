# issue 0213 -- read_raw_ascii_point() overruns its buffer.
#
# The reader took the per-point scratch buffer without its capacity and ended a
# point only on an empty line or EOF. An ASCII rawfile that is well formed in
# every other respect but simply lacks the blank separator between points made
# it keep writing tmp[lines] past the end of my_calloc(rawvars): `xschem raw
# read <f> tran` then reported SUCCESS and the process died in free_rawfile()
# with "double free or corruption (out)" -- SIGABRT, editor gone.
#
# THE LOAD-BEARING PROPERTY OF THIS FILE: on an unfixed binary it does not
# report failures, it ABORTS -- group A never returns from `xschem raw clear`,
# so the RESULT banner is never printed and full_audit scores it FAIL. Every
# group below is therefore both a correctness check and a crash canary.
#
# Groups:
#   A   the issue's own repro: separator-less tran block. Must read, and read
#       CORRECTLY -- the values must not be shifted by the resync.
#   B   a wider/deeper separator-less block (4 vars x 5 points), where the old
#       overrun ran 30 doubles past a 4-double buffer.
#   C   the well-formed twin: no regression.
#   D   a SHORT point (fewer values than No. Variables) is a read FAILURE now,
#       not a dbg(0) warning over a half populated Raw.
#   E   bound 2: a line that does not parse as a number ends the point. Only the
#       first line of a point was ever validated; the rest went to my_atof(),
#       which reads "Plotname:" as 0.0.
#   F   truncated at EOF mid point.
#   G   AC: two doubles per line, so the bound is `lines + 1 >= maxvars`. An
#       off-by-one here writes exactly one double past the buffer.
#   H   the sweep1/sweep2 PRE-COUNT pass, which runs the same reader over the
#       same points before rewinding -- i.e. everything above, twice.
#   I   a separator-less dataset followed by a second dataset: the line that is
#       not our separator must be handed BACK, not eaten, or the next section
#       header disappears.
#   J   "No. Variables: 0": a zero capacity buffer that the reader still wrote
#       into.
#   K   an odd `No. Variables:` on a complex plot: rawvars>>1 rounds down, so
#       the buffer is one double short of what a line writes.
#   L   non finite values (`nan`, `-inf`, `nan(0x1)`, ...). A C library prints
#       these as WORDS, so bound 2 must accept them or one of them costs the
#       whole file -- while `nancy` and `information` stay non-values.
#
# NOT covered here, on purpose: skip_raw_ascii_points(), the sibling that walks
# past a dataset xschem did not ask for. It has the same two weaknesses this
# file pins in the reader (no CRLF separator, no bound) and they cost whole
# files too, but they are PRE-EXISTING and unfixed -- see
# doc/claude/issues/0300-*.md, which carries their measured repros. A fix was
# written and reverted on 2026-08-09 for over-skipping into the next plot; the
# checks that pinned it went with it.
#
# Run headless from the repo root:
#   ./src/xschem --nogui --pipe -q --script tests/headless/test_raw_ascii_point_bounds.tcl

source [file join [file dirname [info script]] scratch.tcl]

set fail 0
set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail"; incr npass } \
  else { puts "FAIL: $name $detail"; incr fail }
}
proc eqcheck {name got want} {
  check $name [expr {$got eq $want}] "(got '$got' want '$want')"
}
proc nearcheck {name got want {tol 1e-12}} {
  set ok [expr {[string is double -strict $got] && abs($got - $want) <= $tol}]
  check $name $ok "(got '$got' want '$want')"
}
proc pcall {args} {
  if {[catch {uplevel 1 $args} r]} { return "ERR:$r" }
  return $r
}

set tmp [test_scratch rawascii]

proc wr {path body} {
  set fp [open $path w]
  puts -nonewline $fp $body
  close $fp
}
# load one rawfile as the only DB; returns the read result (1/0)
proc load1 {f {type tran}} {
  catch {xschem raw clear}
  return [pcall xschem raw read $f $type]
}

# ---------------------------------------------------------------------------
# A -- the issue 0213 repro, verbatim: header counts right, values right, only
#      the blank line that terminates each point is missing.
# ---------------------------------------------------------------------------
wr $tmp/bad.raw "Title: malformed fixture
Date: Wed Jan 1 00:00:00 2026
Plotname: Transient Analysis
Flags: real
No. Variables: 2
No. Points: 2
Variables:
\t0\ttime\ttime
\t1\tv(out)\tvoltage
Values:
0\t0.0
\t1.0
1\t1e-9
\t2.0
"
eqcheck A1-repro-reads [load1 $tmp/bad.raw] 1
eqcheck A2-points [pcall xschem raw points] 2
eqcheck A3-vars [pcall xschem raw vars] 2
# the resync must not shift the columns: point p keeps ITS values
nearcheck A4-t0 [pcall xschem raw value time 0] 0.0
nearcheck A5-t1 [pcall xschem raw value time 1] 1e-9
nearcheck A6-v0 [pcall xschem raw value v(out) 0] 1.0
nearcheck A7-v1 [pcall xschem raw value v(out) 1] 2.0
# THE ABORT SITE: the overrun wrecked the allocator metadata and free_rawfile()
# was where it landed. Reaching the next line at all is the check.
eqcheck A8-clear-survives [pcall xschem raw clear] 1
check A9-alive-after-clear 1 "(process survived free_rawfile)"

# ---------------------------------------------------------------------------
# B -- wider and deeper: 4 variables, 5 points, no separators anywhere. The old
#      reader ran 16 doubles past a 4-double buffer on the first point alone.
# ---------------------------------------------------------------------------
set body ""
for {set p 0} {$p < 5} {incr p} {
  append body "$p\t[expr {$p * 1e-8}]\n"
  foreach v {1 2 3} { append body "\t[expr {$p * 10 + $v}].0\n" }
}
wr $tmp/wide.raw "Title: wide
Plotname: Transient Analysis
Flags: real
No. Variables: 4
No. Points: 5
Variables:
\t0\ttime\ttime
\t1\tv(a)\tvoltage
\t2\tv(b)\tvoltage
\t3\tv(c)\tvoltage
Values:
$body"
eqcheck B1-reads [load1 $tmp/wide.raw] 1
eqcheck B2-points [pcall xschem raw points] 5
eqcheck B3-vars [pcall xschem raw vars] 4
set okvals 1
set detail ""
for {set p 0} {$p < 5} {incr p} {
  foreach {n v} [list time [expr {$p * 1e-8}] v(a) [expr {$p*10+1}].0 \
                      v(b) [expr {$p*10+2}].0 v(c) [expr {$p*10+3}].0] {
    set got [pcall xschem raw value $n $p]
    if {![string is double -strict $got] || abs($got - $v) > 1e-12} {
      set okvals 0; append detail " $n\[$p\]=$got!=$v"
    }
  }
}
check B4-all-20-values-correct $okvals "($detail)"
eqcheck B5-clear-survives [pcall xschem raw clear] 1

# ---------------------------------------------------------------------------
# C -- the well-formed twin must be unaffected
# ---------------------------------------------------------------------------
wr $tmp/good.raw "Title: good
Plotname: Transient Analysis
Flags: real
No. Variables: 2
No. Points: 3
Variables:
\t0\ttime\ttime
\t1\tv(out)\tvoltage
Values:
0\t0.0
\t1.0

1\t1e-8
\t2.0

2\t2e-8
\t3.0

"
eqcheck C1-reads [load1 $tmp/good.raw] 1
eqcheck C2-points [pcall xschem raw points] 3
eqcheck C3-vars [pcall xschem raw vars] 2
nearcheck C4-t2 [pcall xschem raw value time 2] 2e-8
nearcheck C5-v1 [pcall xschem raw value v(out) 1] 2.0
eqcheck C6-simtype [pcall xschem raw sim_type] tran
eqcheck C7-datasets [pcall xschem raw datasets] 1

# ---------------------------------------------------------------------------
# D -- a SHORT point is a read FAILURE, and leaves nothing behind
# ---------------------------------------------------------------------------
wr $tmp/short.raw "Title: short point
Plotname: Transient Analysis
Flags: real
No. Variables: 2
No. Points: 2
Variables:
\t0\ttime\ttime
\t1\tv(out)\tvoltage
Values:
0\t0.0
\t1.0

1\t1e-8

"
eqcheck D1-short-point-fails [load1 $tmp/short.raw] 0
# nothing half populated is left current: `raw points` must not report a dataset
set pts [pcall xschem raw points]
check D2-no-phantom-dataset [expr {$pts eq "" || $pts eq "0" || [string match "ERR:*" $pts]}] "(points='$pts')"
# and a good file still loads afterwards
eqcheck D3-recovers [load1 $tmp/good.raw] 1
eqcheck D4-recovered-points [pcall xschem raw points] 3

# the failed read must not clobber a raw that IS loaded (the restore path)
eqcheck D5-good-loaded [load1 $tmp/good.raw] 1
eqcheck D6-bad-read-fails [pcall xschem raw read $tmp/short.raw tran] 0
eqcheck D7-previous-still-current [pcall xschem raw sim_type] tran
eqcheck D8-previous-points-intact [pcall xschem raw points] 3
nearcheck D9-previous-values-intact [pcall xschem raw value v(out) 2] 3.0
catch {xschem raw clear}

# ---------------------------------------------------------------------------
# E -- bound 2: a non numeric line ends the point (my_atof would store 0.0)
# ---------------------------------------------------------------------------
wr $tmp/junkline.raw "Title: junk inside Values
Plotname: Transient Analysis
Flags: real
No. Variables: 2
No. Points: 2
Variables:
\t0\ttime\ttime
\t1\tv(out)\tvoltage
Values:
0\t0.0
Plotname: this is not a number
\t1.0

1\t1e-8
\t2.0

"
eqcheck E1-junk-line-fails [load1 $tmp/junkline.raw] 0
eqcheck E2-recovers [load1 $tmp/good.raw] 1

# THE DISCRIMINATING ONE. Above, the junk line is followed by more values, so
# the point desynchronises and fails at the NEXT point whether or not bound 2
# exists. Here the junk line is the LAST line of the point and the separator
# follows it, so without bound 2 my_atof() quietly stores 0.0 for v(out), the
# point is "the right size" and the whole file reads as a SUCCESS carrying a
# fabricated sample. With bound 2 the point is short and the read refuses.
wr $tmp/junktail.raw "Title: junk as the last line of a point
Plotname: Transient Analysis
Flags: real
No. Variables: 2
No. Points: 2
Variables:
\t0\ttime\ttime
\t1\tv(out)\tvoltage
Values:
0\t0.0
Plotname: not a number

1\t1e-8
\t2.0

"
eqcheck E3-junk-tail-fails [load1 $tmp/junktail.raw] 0
set v [pcall xschem raw value v(out) 0]
check E4-no-fabricated-sample [expr {[string match "ERR:*" $v]}] "(v(out)\[0\]='$v')"
eqcheck E5-recovers [load1 $tmp/good.raw] 1

# ---------------------------------------------------------------------------
# F -- truncated mid point at EOF (a killed simulator leaves one)
# ---------------------------------------------------------------------------
wr $tmp/trunc.raw "Title: truncated
Plotname: Transient Analysis
Flags: real
No. Variables: 2
No. Points: 2
Variables:
\t0\ttime\ttime
\t1\tv(out)\tvoltage
Values:
0\t0.0
\t1.0

1\t1e-8"
eqcheck F1-truncated-fails [load1 $tmp/trunc.raw] 0
eqcheck F2-recovers [load1 $tmp/good.raw] 1

# ---------------------------------------------------------------------------
# G -- AC: two doubles per line. maxvars counts DOUBLES, not lines, so the bound
#      is `lines + 1 >= maxvars`; `lines >= maxvars` writes one double past.
# ---------------------------------------------------------------------------
wr $tmp/ac.raw "Title: ac no separators
Plotname: AC Analysis
Flags: complex
No. Variables: 2
No. Points: 2
Variables:
\t0\tfrequency\tfrequency
\t1\tv(out)\tvoltage
Values:
0\t1.0,0.0
\t3.0,4.0
1\t2.0,0.0
\t6.0,8.0
"
eqcheck G1-ac-reads [load1 $tmp/ac.raw ac] 1
eqcheck G2-ac-points [pcall xschem raw points] 2
# 2 file variables -> mag, phase, real, imag each = 8 columns
eqcheck G3-ac-vars [pcall xschem raw vars] 8
nearcheck G4-freq0 [pcall xschem raw value frequency 0] 1.0
nearcheck G5-freq1 [pcall xschem raw value frequency 1] 2.0
nearcheck G6-mag0 [pcall xschem raw value v(out) 0] 5.0 1e-6
nearcheck G7-mag1 [pcall xschem raw value v(out) 1] 10.0 1e-6
nearcheck G8-re0 [pcall xschem raw value re(out) 0] 3.0 1e-6
nearcheck G9-im0 [pcall xschem raw value im(out) 0] 4.0 1e-6
nearcheck G10-re1 [pcall xschem raw value re(out) 1] 6.0 1e-6
eqcheck G11-clear-survives [pcall xschem raw clear] 1

# ---------------------------------------------------------------------------
# H -- the sweep1/sweep2 PRE-COUNT pass: read_raw_data_block() runs the same
#      reader over the same points, then rewinds. Everything above, twice.
# ---------------------------------------------------------------------------
catch {xschem raw clear}
eqcheck H1-sweep-good-reads [pcall xschem raw read $tmp/good.raw tran 0 1.5e-8] 1
eqcheck H2-sweep-window-applied [pcall xschem raw points] 2
nearcheck H3-sweep-t0 [pcall xschem raw value time 0] 0.0
nearcheck H4-sweep-t1 [pcall xschem raw value time 1] 1e-8
catch {xschem raw clear}
# the separator-less 5 point block, windowed
eqcheck H5-sweep-noblank-reads [pcall xschem raw read $tmp/wide.raw tran 1e-8 3.5e-8] 1
eqcheck H6-sweep-noblank-points [pcall xschem raw points] 3
nearcheck H7-sweep-noblank-t0 [pcall xschem raw value time 0] 1e-8
nearcheck H8-sweep-noblank-v [pcall xschem raw value v(b) 0] 12.0
catch {xschem raw clear}
# a malformed block under a sweep window fails in the pre-count pass, before any
# storage is allocated -- and the stream is rewound, so nothing is left dangling
eqcheck H9-sweep-short-fails [pcall xschem raw read $tmp/short.raw tran 0 1e-3] 0
eqcheck H10-sweep-recovers [pcall xschem raw read $tmp/good.raw tran 0 1e-3] 1
eqcheck H11-sweep-recovered-points [pcall xschem raw points] 3
catch {xschem raw clear}

# ---------------------------------------------------------------------------
# I -- the pushback: a line that is not our separator goes BACK to the stream.
#      Dataset 2 here starts with its Plotname line and nothing else before it,
#      so a reader that swallowed the peeked line would swallow that header and
#      never see the second dataset at all.
# ---------------------------------------------------------------------------
wr $tmp/two.raw "Title: two datasets, first without separators
Plotname: Transient Analysis
Flags: real
No. Variables: 2
No. Points: 2
Variables:
\t0\ttime\ttime
\t1\tv(out)\tvoltage
Values:
0\t0.0
\t1.0
1\t1e-8
\t2.0
Plotname: Transient Analysis
Flags: real
No. Variables: 2
No. Points: 2
Variables:
\t0\ttime\ttime
\t1\tv(out)\tvoltage
Values:
0\t2e-8
\t3.0

1\t3e-8
\t4.0

"
eqcheck I1-two-datasets-read [load1 $tmp/two.raw] 1
eqcheck I2-second-header-survived [pcall xschem raw datasets] 2
eqcheck I3-all-points [pcall xschem raw points] 4
nearcheck I4-ds1-v [pcall xschem raw value v(out) 1] 2.0
nearcheck I5-ds2-v [pcall xschem raw value v(out) 3] 4.0
nearcheck I6-ds2-t [pcall xschem raw value time 2] 2e-8
catch {xschem raw clear}

# ...and a second dataset that IS malformed must not throw away the first
wr $tmp/two_bad2.raw "Title: good dataset then a short one
Plotname: Transient Analysis
Flags: real
No. Variables: 2
No. Points: 2
Variables:
\t0\ttime\ttime
\t1\tv(out)\tvoltage
Values:
0\t0.0
\t1.0

1\t1e-8
\t2.0

Plotname: Transient Analysis
Flags: real
No. Variables: 2
No. Points: 2
Variables:
\t0\ttime\ttime
\t1\tv(out)\tvoltage
Values:
0\t2e-8

1\t3e-8

"
eqcheck I7-partial-still-reads [load1 $tmp/two_bad2.raw] 1
eqcheck I8-bad-dataset-dropped [pcall xschem raw datasets] 1
eqcheck I9-good-dataset-kept [pcall xschem raw points] 2
nearcheck I10-good-values-kept [pcall xschem raw value v(out) 1] 2.0
catch {xschem raw clear}

# ---------------------------------------------------------------------------
# J -- "No. Variables: 0": a zero capacity buffer the reader still wrote into
# ---------------------------------------------------------------------------
wr $tmp/novars.raw "Title: no variables
Plotname: Transient Analysis
Flags: real
No. Variables: 0
No. Points: 2
Variables:
Values:
0\t0.0

1\t1e-8

"
eqcheck J1-zero-vars-fails [load1 $tmp/novars.raw] 0
eqcheck J2-recovers [load1 $tmp/good.raw] 1

# ---------------------------------------------------------------------------
# K -- an ODD per-point capacity under `ac`. `ac` writes TWO doubles per line,
#      so the bound must guarantee two free slots (`lines + 1 >= maxvars`), not
#      one (`lines >= maxvars`). Every header the parser normally builds gives
#      an even capacity, which hides the difference -- EXCEPT here: `Flags:
#      complex` placed AFTER `No. Variables:` means nvars is not doubled, so
#      rawvars = 7 >> 1 = 3, an odd capacity. With the one-slot bound the second
#      line writes tmp[3] eight bytes past a 24 byte my_calloc() and the next
#      free() dies with "double free or corruption (out)".
#      (No `Variables:` section on purpose: raw->names is sized from the
#      undoubled nvars and the ac naming path writes names[i<<2], which would
#      overrun a DIFFERENT buffer and mask what this fixture is aiming at.)
# ---------------------------------------------------------------------------
wr $tmp/oddcap.raw "Title: odd per point capacity
Plotname: Transient Analysis
No. Variables: 7
No. Points: 1
Flags: complex
Values:
0\t1.0,2.0
\t3.0,4.0

"
eqcheck K1-odd-capacity-refuses [load1 $tmp/oddcap.raw] 0
check K2-alive-after-refusal 1 "(process survived the free of the odd sized buffer)"
eqcheck K3-recovers [load1 $tmp/good.raw] 1

# ---------------------------------------------------------------------------
# L -- NON FINITE VALUES. Bound 2 above classifies a value line by its first
#      character, and a C library prints a non finite double as a WORD: glibc
#      "%e" gives `nan`/`-nan`/`inf`/`-inf`, "%E" gives `NAN`/`INF`, C99 also
#      allows `nan(chars)` and `infinity`. ngspice-46 itself writes them (`set
#      filetype=ascii` + `write` of `1e300*1e300`, `ln(0)`, `inf-inf`), and
#      xschem also reads raws it did not write.
#
#      This is a REGRESSION GUARD, not a new feature: before the 0213 fix such
#      a line fell through to my_atof(), the point was full size and the file
#      loaded with every healthy signal intact. A digits-only predicate made
#      the point short -> the dataset a read failure -> ONE non finite sample
#      anywhere cost the WHOLE file (`raw_read(): no useful data found`, and
#      every later query "No raw file loaded"). Measured, exactly so.
#
#      What the words STORE is unchanged (my_atof() answers 0.0 on the
#      continuation path); the point of these checks is that the file READS.
# ---------------------------------------------------------------------------
wr $tmp/nonfinite.raw "Title: one nan sample among healthy ones
Plotname: Transient Analysis
Flags: real
No. Variables: 2
No. Points: 3
Variables:
\t0\ttime\ttime
\t1\tv(out)\tvoltage
Values:
0\t0.0
\t1.0

1\t1e-8
\tnan

2\t2e-8
\t3.0

"
eqcheck L1-nan-does-not-lose-the-file [load1 $tmp/nonfinite.raw] 1
eqcheck L2-all-points-present [pcall xschem raw points] 3
# the healthy samples on either side of the nan must survive untouched -- this
# is the whole cost of the regression: one bad sample took all of them
nearcheck L3-healthy-before-nan [pcall xschem raw value v(out) 0] 1.0
nearcheck L4-healthy-after-nan [pcall xschem raw value v(out) 2] 3.0
nearcheck L5-sweep-column-intact [pcall xschem raw value time 1] 1e-8

# every spelling a printf can produce, one per point. The read must survive all
# of them; `time` is the witness that no point was dropped or shifted.
set spellings {nan -nan +nan inf -inf INF NaN Infinity nan(0x8000000000000)}
set body ""
set p 0
foreach s $spellings {
  append body "$p\t[expr {$p * 1e-8}]\n\t$s\n\n"
  incr p
}
wr $tmp/spellings.raw "Title: every non finite spelling
Plotname: Transient Analysis
Flags: real
No. Variables: 2
No. Points: [llength $spellings]
Variables:
\t0\ttime\ttime
\t1\tv(out)\tvoltage
Values:
$body"
eqcheck L6-all-spellings-read [load1 $tmp/spellings.raw] 1
eqcheck L7-all-spellings-points [pcall xschem raw points] [llength $spellings]
set okt 1
set detail ""
for {set p 0} {$p < [llength $spellings]} {incr p} {
  set got [pcall xschem raw value time $p]
  if {![string is double -strict $got] || abs($got - $p * 1e-8) > 1e-12} {
    set okt 0; append detail " [lindex $spellings $p]:time\[$p\]=$got"
  }
}
check L8-no-point-dropped-or-shifted $okt "($detail)"

# ngspice's own byte-for-byte spelling: the index line carries a LEADING SPACE
# and the value line is a bare "\t-nan". Taken from a real ngspice-46 ascii raw
# produced on this box.
wr $tmp/ngnan.raw "Title: * ngspice spelling
Date: Sun Aug  9 02:33:13  2026
Command: ngspice-46, Build Sun Aug  2 23:29:26 UTC 2026
Plotname: Operating Point
Flags: real
No. Variables: 3
No. Points: 1
Variables:
\t0\tV(1)\tvoltage
\t1\tn\tnotype
\t2\tm\tnotype
Values:
 0\t1.000000000000000e+00
\t-nan
\t-nan

"
catch {xschem raw clear}
eqcheck L9-ngspice-nan-raw-reads [pcall xschem raw read $tmp/ngnan.raw op] 1
nearcheck L10-ngspice-healthy-var [pcall xschem raw value v(1) 0] 1.0

# THE DISCRIMINATING ONES. A word that merely BEGINS with an accepted spelling
# is not a value: the ruling is that the word must END there (see the comment on
# raw_ascii_number_line() in src/save.c). Were it otherwise, my_atof() would
# store its 0.0 as a fabricated sample -- exactly what bound 2 exists to stop.
# Each of these is the tail line of its point followed by a separator, so the
# point is "the right size" if the line is accepted, and short if it is not.
proc nfbad {path word} {
  global tmp
  wr $path "Title: not a non finite spelling
Plotname: Transient Analysis
Flags: real
No. Variables: 2
No. Points: 2
Variables:
\t0\ttime\ttime
\t1\tv(out)\tvoltage
Values:
0\t0.0
\t$word

1\t1e-8
\t2.0

"
}
nfbad $tmp/nancy.raw "nancy"
nfbad $tmp/infoword.raw "information"
nfbad $tmp/nanopen.raw "nan(0x1"
nfbad $tmp/nanword.raw "nan"
eqcheck L11-nancy-is-not-a-value [load1 $tmp/nancy.raw] 0
eqcheck L12-information-is-not-a-value [load1 $tmp/infoword.raw] 0
eqcheck L13-unclosed-payload-is-not-a-value [load1 $tmp/nanopen.raw] 0
# ...and the same file with a real spelling in the same slot DOES read: the
# refusals above are about the word, not about the position.
eqcheck L14-bare-nan-in-the-same-slot-reads [load1 $tmp/nanword.raw] 1
eqcheck L15-and-keeps-both-points [pcall xschem raw points] 2
eqcheck L16-recovers [load1 $tmp/good.raw] 1

catch {xschem raw clear}
catch {test_scratch_drop $tmp}
puts "----"
puts "test_raw_ascii_point_bounds: $npass passed, $fail failed"
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
