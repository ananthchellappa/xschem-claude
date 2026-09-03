# tests/headless/test_rdw_seam_1245.tcl — item B1 of
# doc/claude/op_param_batch/PLAN.md (feature 1245, the Results Display Window).
# Spec: doc/claude/specs/op_param_lists.md §4.2. Rulings:
# doc/claude/op_param_batch/DECISIONS.md — D-3, D-4, D-5 and DRIVER DECISION
# DD-1, which is this item's central ruling.
#
# ============================================================================
# WHAT IS UNDER TEST
# ============================================================================
# B1 adds the BACKEND SEAM and nothing else — no UI, no deck change, no C:
#
#   ase::backend::ngspice::op_param_set <devpath>   an ANSWER DICT
#         devices   ordered {<rawdev> {{<param> <value>} ...}}, raw-file order
#         absent    ordered {<rawdev> <param>} pairs — columns the raw NAMES
#                   but the simulator did not compute
#         complete  the honesty flag, AS DATA (DD-1's corollary)
#         state     no_devpath | no_raw | not_op | not_annotated | ok
#   ase::backend::ngspice::op_param_enumerable      a DECLARED constant, 0
#   ase::op_param_split <rawname>  -> {dev param} or {}   (the ONE reverse map)
#   ase::op_param_of    <name>     -> the parameter half, beside op_dev_of
#
# Both hooks ride in the ngspice registration dict beside `capabilities`
# (src/ase.tcl:8521-8527) and are reached ONLY through ase::backend_hook
# (src/ase.tcl:540). NEITHER joins the required-hook `foreach` at ase.tcl:528 —
# row S3 is the fence, because tests/headless/test_ase_core.tcl:1116 and :1171
# hand-build FIVE-hook registrations that would raise, in a suite that already
# carries a baseline red (its C11 phantom) where a second red is easy to
# misread as pre-existing.
#
# ============================================================================
# THE ONE SENTENCE EACH, PER A7's LESSON
# ============================================================================
# WHAT op_param_set ANSWERS: which parameter columns THIS RUN'S CURRENTLY
# SELECTED RAW SLOT actually holds and actually computed for exactly this
# device path, in the order the file lists them.
# WHAT IT DOES NOT ANSWER: which parameters this device HAS — it cannot see a
# parameter nobody saved, it cannot see a device the raw does not name, it is
# blind to absence on any raw written by `ngspice -b -r` (issue 1263), and it
# says nothing about a slot that is not the current one.
#
# ============================================================================
# DD-1 — THE CAPABILITY IS DECLARED, NEVER MEASURED
# ============================================================================
# Today's ngspice answers NO: it has no wildcard operating-point save. That
# answer may NOT be obtained by probing, by parsing `show`, by trying a save
# and seeing what came back, or by reading the EXISTING measured key
# `blanket_op_save` (src/ase.tcl:8460-8467), which asks B1's own question —
# "can one card save every parameter of a device at once" — the forbidden way.
# Reaching that key is also operationally poisonous: ase::sim_capabilities
# (ase.tcl:1777) builds a workdir and STARTS THE USER'S SIMULATOR on a cache
# miss, and ase.tcl:3813's own comment forbids putting that on a path with no
# Run behind it. A key-3 press is exactly such a path.
# Rows C3 (structural) and C4 (behavioural) are DRIVER ADD (2): they red if a
# later reader "fixes" the duplication in the forbidden direction.
#
# ============================================================================
# WHY POINT -1, AND WHY ABSENCE IS REPORTED ONLY IN STATE `ok`
# ============================================================================
# MEASURED ON THIS BINARY, 2026-09-03, against the fabricated raws below:
#   after annotate_op   a live column answers its number at point -1
#                       a `dims=0` column answers THE EMPTY STRING at point -1
#                       and `0` at point 0 — the fabricated zero I3 forbids
#                       a genuinely computed 0.0 answers `0` at BOTH points
#   before annotate_op  point -1 is EMPTY FOR EVERY VECTOR, good ones included
# So `xschem raw value <v> -1` — reached through ::op_annot::raw_or_blank
# (op_annot.tcl:998), the existing three-outcome accessor — is the ONLY reader
# carrying the absent/zero distinction, and a reader that filled `absent`
# before update_op() published would report "the simulator did not compute id"
# when in truth nobody had asked it to yet. That is A7's lesson applied to this
# item's own seam, and it is why rows G1..G4 exist.
#
# ============================================================================
# WHICH ROWS ARE RED BEFORE B1 LANDS
# ============================================================================
# Measured against the unmodified tree (src/xschem built 2026-09-03 03:10,
# HEAD 9f1d9153): `ase::backend_hook ngspice op_param_set` raises
# "ase: unknown hook 'op_param_set' for simulator 'ngspice'", the four procs do
# not exist, and the registered hook set is exactly
#   {capabilities log_file raw_file render_deck result_probe run_cmd}.
# Every behavioural row therefore answers NOHOOK and every structural row
# answers NOPROC. Measured before the change: 29 FAILED / 8 passed, identical
# under --nogui and on the dev display.
#
#   RED (29), each for that one reason:
#     S1 S2a · V1a V1b V1c V2 · P1 P2 P3 P4 · A1 A1c A2 A3 · D1 D1b D2 D3
#     C1 C2 C4 · G1 G2 G3 G3b G4 G5 · Q10b · I3
#   GREEN BEFORE THE CHANGE (8) — controls, fences and hygiene. NONE of them is
#   evidence for B1; each says only that B1 broke nothing:
#     S0    the machinery B1 builds on is live
#     S2b   the ONE dispatch still refuses a hook nobody registered
#     S3    the required-hook loop still names exactly the five (a FENCE — it
#           must stay green, and SAB-HOOK is what reds it)
#     P0    the fixture is live and the reader really does tell absent from zero
#     C3    ⚠ GREEN BY ABSENCE, and it proves nothing today: it counts forbidden
#           tokens in two bodies that do not exist yet, so the counts are 0 for
#           the wrong reason. It earns its keep only against the GREEN tree and
#           against a later probe (verified: it reds under SAB-PROBE).
#     Q10a  it measures the RAW READER, not B1 — and its answer is the record
#           this batch owes spec question Q10: YES, reading a two-plot OP+TRAN
#           file lands on the operating point.
#     R1    registration
#     H1    hygiene
#
# ⚠ EVERY GOLDEN BELOW WAS RUN AGAINST A SCRATCH PROTOTYPE OF THE SEAM (the
# plan's own algorithm, outside the repo) BEFORE THIS FILE WAS FINISHED, and
# the prototype scores ALL PASS (37 checks). A red row here is therefore a
# statement about the tree, not about an unreachable golden. Eight sabotage
# variants were run against that prototype and every one of them was caught:
#   read at point 0 instead of -1        -> A1 A2 I3
#   exact-match device test              -> D1 D1b       (P1/P2 stay green: control)
#   substring device test                -> P1 D1 D1b D2
#   capability declared 1                -> C1 C2 C4 + every state row's flag
#   capability read from the PROBE       -> C3 C4
#   `complete` retyped as a literal      -> C2           (C1 stays green: control)
#   the state gate removed               -> G1 G2 G3 G3b G4
#   the new hook made REQUIRED           -> S3           (locally, as intended)
#
# ============================================================================
# THIS SUITE NEEDS NO X AND MUST STILL NOT BE ADDED TO ANY full_audit.sh LIST
# ============================================================================
# There is no `bind` and no `event generate` here, so it runs identically under
# --nogui and under a display. full_audit.sh selects by GLOB
# (`ls "$HERE"/test_*.tcl | sort`, :393) and the three named lists are OPT-INS;
# row R1 says out loud that this file is in none of them and that
# full_audit.sh is NOT edited. The audit denominator moves 378 -> 379 — diff
# the baseline by NAME and STATUS, never by count.
#
# Run from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_rdw_seam_1245.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# --- locations (cwd-independent) --------------------------------------------
set here [file normalize [file dirname [info script]]]      ;# tests/headless
set repo [file normalize [file join $here .. ..]]           ;# repo root
source [file join $here scratch.tcl]
set scratch [test_scratch rdw_seam]
set RS_AUDIT [file join $here full_audit.sh]

## Anything this session might be tempted to write goes to the scratch dir --
## including ase::cap_workdir's `.ase_probe`, which is what row C4 watches for.
set ::netlist_dir $scratch

# ============================================================================
# THE ANSWER DISCIPLINE — AN ABSENT SEAM MUST NEVER SATISFY A GOLDEN
# ============================================================================
# Copied from dc_ans (tests/headless/test_annot_declutter_1244.tcl:227) and
# a_body (tests/headless/test_ase_simcaps_0948.tcl:168). Two rules, both of
# them lessons this batch already paid for:
#   * a row must be able to FIRE in the RED state. A bare call to a proc that
#     does not exist raises, and a raise at global level under --pipe stops
#     Tcl_AppInit DEAD — the whole file dies mid-run with `ok` lines and NO
#     verdict (item A2's lesson 6). Every call below goes through a wrapper.
#   * "invalid command name ..." must not be able to satisfy a row expecting
#     the empty string.

## The comment-stripped BODY of a proc, read at RUN TIME rather than grepped
## out of the file, so a seam that grew a helper cannot hide a forbidden
## command behind a proc name this file never heard of.
proc rs_nocomment {t} {
  set out {}
  foreach l [split $t "\n"] { if {[regexp {^\s*#} $l]} continue ; lappend out $l }
  return [join $out "\n"]
}
proc rs_body {cmd} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  if {[catch {info body $cmd} b]} { return "RAISED:$b" }
  return [rs_nocomment $b]
}
proc rs_count {hay needle} {
  if {$needle eq {}} { return 0 }
  set n 0 ; set i 0
  while {[set i [string first $needle $hay $i]] >= 0} { incr n ; incr i }
  return $n
}
proc rs_has {hay needle} { return [expr {[string first $needle $hay] >= 0 ? 1 : 0}] }
proc rs_slurp {path} {
  if {![file isfile $path]} { return {} }
  set fd [open $path r] ; set d [read $fd] ; close $fd ; return $d
}
## A C file with its /* */ comments blanked, so a sentence quoted in a header
## paragraph is not counted as a second guard. Copied from a6_code,
## tests/headless/test_annot_declutter_1244.tcl:2887.
proc rs_code {path} {
  if {![file isfile $path]} { return NOFILE }
  set d [rs_slurp $path]
  regsub -all {/\*.*?\*/} $d " " d
  return $d
}
## Call any proc without letting it abort the suite.
proc rs_ans {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  set rc [catch {uplevel #0 [linsert $args 0 $cmd]} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}

# ============================================================================
# THE SEAM, ALWAYS THROUGH THE ONE DISPATCH
# ============================================================================
# Every behavioural row calls ase::backend_hook rather than the proc name, so
# each of them implicitly asserts that the hook resolves. There is ONE dispatch
# and this file never reaches around it.
proc rs_hookname {h} {
  if {[catch {ase::backend_hook ngspice $h} p]} { return NOHOOK }
  return $p
}
proc rs_hookbody {h} {
  set p [rs_hookname $h]
  if {$p eq {NOHOOK}} { return NOPROC }
  return [rs_body $p]
}
proc rs_call {h args} {
  set p [rs_hookname $h]
  if {$p eq {NOHOOK}} { return NOHOOK }
  if {![llength [info commands $p]]} { return "NOPROC:$p" }
  set rc [catch {uplevel #0 [linsert $args 0 $p]} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}
proc rs_set {dev} { return [rs_call op_param_set $dev] }
proc rs_cap {}    { return [rs_call op_param_enumerable] }
## Dict readers that red instead of raising when the answer is not a dict.
proc rs_key {ans k}  { if {[catch {dict get $ans $k} v]} { return "NOKEY-$k" } ; return $v }
proc rs_dkeys {d}    { if {[catch {dict keys $d} k]} { return NODICT } ; return $k }
proc rs_dget {d k}   { if {[catch {dict get $d $k} v]} { return "NOKEY-$k" } ; return $v }
## The four fields of one answer, in one list — the shape most rows assert on.
proc rs_sda {dev} {
  set a [rs_set $dev]
  return [list [rs_key $a state] [rs_key $a devices] [rs_key $a absent] [rs_key $a complete]]
}
## Just the parameter NAMES a device came back with, in order.
proc rs_params {devs dev} {
  set p [rs_dget $devs $dev]
  if {[catch {llength $p}]} { return $p }
  set out {}
  foreach pair $p { lappend out [lindex $pair 0] }
  return $out
}

# ============================================================================
# THE FIXTURE MINTER — a3_mkraw's SHAPE, WITH THE PLOTNAME LIFTED OUT
# ============================================================================
# Copied from a3_mkraw (tests/headless/test_annot_declutter_1244.tcl:1499),
# which already carries the optional per-column THIRD `Variables:` field — the
# one ngspice writes as `voltage` / `current`, and as `current dims=0` for a
# `.save` card the model does not publish (spec landmine 11,
# doc/claude/code_analysis/1244_op_param_list_measurements.md §22). TWO things
# are lifted out of it and nothing else is changed:
#   * the `Plotname:` literal, so this file can mint a TRANSIENT and a NOISE
#     plot for the sim_type gate (rows G3/G3b) as well as an Operating Point;
#   * the plot LIST, so it can mint the two-plot OP+TRAN file row Q10 needs.
# It is ONE minter, not two (invariant I1). <plots> is a list of
# {plotname pairs types} triples; `pairs` is {name value name value ...} and
# `types` is one type word per column, defaulting to `voltage`.
#
# ⚠ NO SIMULATOR IS NEEDED OR WANTED. A suite that needs a simulator is a suite
# that will rot; every number below is a byte this file wrote.
proc rs_mkraw {path plots} {
  set f [open $path w]
  puts -nonewline $f "Title: B1 rdw seam fixture\nDate: Mon Jan 1 00:00:00 2026\n"
  foreach spec $plots {
    set pname [lindex $spec 0] ; set pairs [lindex $spec 1] ; set types [lindex $spec 2]
    puts -nonewline $f "Plotname: $pname\nFlags: real\n"
    puts -nonewline $f "No. Variables: [expr {[llength $pairs]/2}]\nNo. Points: 1\nVariables:\n"
    set k 0
    foreach {v val} $pairs {
      set ty [lindex $types $k]
      if {$ty eq {}} { set ty voltage }
      puts -nonewline $f "\t$k\t$v\t$ty\n" ; incr k
    }
    puts -nonewline $f "Values:\n"
    set k 0
    foreach {v val} $pairs {
      if {$k == 0} { puts -nonewline $f "0\t$val\n" } else { puts -nonewline $f "\t$val\n" }
      incr k
    }
  }
  close $f
}
## Write a BINARY raw. THIS IS NOT A CONVENIENCE — IT IS THE ONLY FIXTURE THAT
## CAN CARRY A NON-FINITE, AND ITS ABSENCE IS WHY ITEM B1 CAME BACK [F].
##
## src/save.c's fast my_atof() continuation path has never parsed the words
## `nan` / `inf`, so an ASCII raw carrying either reads back as a confident `0`
## and the defect is INVISIBLE — the first version of this suite was green at
## 37/37 with a seam that returned `nan` in the value bucket. A real ngspice
## `write` produces a BINARY raw, so the reachable case is this one.
##
## `binary format d` cannot express a non-finite (Tcl raises on the literal),
## so the two IEEE bit patterns are written as bytes, little-endian:
##     NaN  0x7ff8000000000000 -> 00 00 00 00 00 00 f8 7f
##     +Inf 0x7ff0000000000000 -> 00 00 00 00 00 00 f0 7f
## A value spelled `NAN` or `INF` in the pairs list is emitted as that pattern;
## anything else goes through `binary format d`.
proc rs_mkraw_bin {path pairs types} {
  set f [open $path w]
  fconfigure $f -translation binary
  puts -nonewline $f "Title: B1 rdw seam binary fixture\nDate: Mon Jan 1 00:00:00 2026\n"
  puts -nonewline $f "Plotname: Operating Point\nFlags: real\n"
  puts -nonewline $f "No. Variables: [expr {[llength $pairs]/2}]\nNo. Points: 1\nVariables:\n"
  set k 0
  foreach {v val} $pairs {
    set ty [lindex $types $k]
    if {$ty eq {}} { set ty voltage }
    puts -nonewline $f "\t$k\t$v\t$ty\n" ; incr k
  }
  puts -nonewline $f "Binary:\n"
  foreach {v val} $pairs {
    switch -exact -- $val {
      NAN     { puts -nonewline $f [binary format H* 000000000000f87f] }
      INF     { puts -nonewline $f [binary format H* 000000000000f07f] }
      default { puts -nonewline $f [binary format d $val] }
    }
  }
  close $f
}
## Load a fabricated raw the way the RDW's own path does, and publish it.
proc rs_annot {f} {
  catch {xschem raw clear}
  catch {xschem annotate_op $f 0}
  catch {update idletasks}
}

# ============================================================================
# THE FIXTURES
# ============================================================================
# ⚠ EVERY GOLDEN NUMBER BELOW IS THE READER'S OWN dtoa OF THE BYTE THIS FILE
# WROTE, MEASURED 2026-09-03. The six values of F_SIX were chosen because they
# round-trip BYTE-IDENTICALLY through the raw reader (1.11e-05, 0, 0.75, 0.001,
# 1.25, 0.5): a golden that carries a float artifact reads as a defect and
# invites someone to "fix" it. The decoy 9.5e-09 does not round-trip and is
# never asserted — it exists only to be excluded.

## F_SIX — SIX saved parameters for @m.x1.m1, in raw-file order, with:
##   * two vectors carrying NO `@` at all (v(in), i(v1)) — never reportable;
##   * a GENUINELY COMPUTED ZERO (is), which is a measurement, not an absence:
##     a transistor that is off has id = 0;
##   * all three spellings issue 0963 records — i(...), v(...) and BARE;
##   * @m.x1.m1foo, whose device name has @m.x1.m1 as a PREFIX. Row Q7 of
##     tests/headless/test_ase_optier_0963.tcl exists because a substring test
##     sweeps it in. Row D2 is this file's statement of the same rule.
set F_SIX {
  v(in)              1.5
  i(@m.x1.m1[id])    1.11e-05
  i(@m.x1.m1[is])    0
  v(@m.x1.m1[vth])   0.75
  @m.x1.m1[gm]       0.001
  v(@m.x1.m1[vds])   1.25
  v(@m.x1.m1[vgs])   0.5
  i(@m.x1.m1foo[id]) 9.5e-09
  i(v1)              -0.001
}
set T_SIX {voltage current current voltage notype voltage voltage current current}

## F_OTHER — the SAME nine vectors, six DIFFERENT values. Row P2 uses it to say
## that the numbers come from the raw that is loaded NOW and not from a cache,
## a memo or a literal.
set F_OTHER {
  v(in)              1.5
  i(@m.x1.m1[id])    2e-06
  i(@m.x1.m1[is])    0.25
  v(@m.x1.m1[vth])   0.5
  @m.x1.m1[gm]       1e-06
  v(@m.x1.m1[vds])   2.5
  v(@m.x1.m1[vgs])   1.5
  i(@m.x1.m1foo[id]) 9.5e-09
  i(v1)              -0.001
}

## F_ABS / F_ZERO — THE 1259 PAIR, AND THEY DIFFER IN ONE FIELD OF ONE LINE.
## Both name a SEVENTH parameter `ib` and both write 0 for it. In F_ABS the
## column's type field is `current dims=0`, i.e. ngspice saying "you asked, the
## model does not publish it"; in F_ZERO it is a plain `current`, i.e. the
## simulator computed zero. Strip the `dims=0` token and the two files are the
## same bytes. Rows A1/A2 and the A1 control are the whole of the distinction.
## ⚠ TWO absent columns, not one, and in this order: `absent` claims to be
## ORDERED, and a single element cannot tell an ordered list from a set, from a
## dict, or from a reversed list.
set F_ABS  [concat $F_SIX [list "i(@m.x1.m1\[ib\])" 0 "v(@m.x1.m1\[cgg\])" 0]]
set T_ABS  [concat $T_SIX [list {current dims=0} {voltage dims=0}]]
set T_ZERO [concat $T_SIX [list current voltage]]

## F_XR1 — RULING D-3, one instance resolving to SEVERAL primitives. This is
## what a single XR1 becomes: two resistor ends, two capacitor primitives one
## subcircuit deeper, and the body diode a savecurrents run adds. FIVE devpaths,
## THREE different element letters, different depths, and their only common
## token is the segment `xr1.`. @r.xr10.x0.rend1 is the decoy: `xr1` must not
## match `xr10`, which is the same boundary rule as m1 / m1foo one level up.
set F_XR1 {
  v(net1)                1.5
  i(@r.xr1.x0.rend1[i])  1e-06
  i(@r.xr1.x0.rend2[i])  2e-06
  i(@c.xr1.x0.xc0.c0[c]) 1e-15
  i(@c.xr1.x0.xc1.c0[c]) 2e-15
  i(@b.xr1.x0.brbody[i]) 4e-06
  i(@r.xr10.x0.rend1[i]) 8e-06
}

## The transient and noise plots the sim_type gate must refuse, and the
## DC transfer characteristic it must accept (update_op's own allow-list).
set F_TRAN {time 0.0 v(in) 1.5 v(out) 0.5 i(v1) -0.001}
set F_NOISE {frequency 1000.0 v(onoise_total) 1e-09}

set R_SIX   [file join $scratch six.raw]
set R_OTHER [file join $scratch other.raw]
set R_ABS   [file join $scratch abs.raw]
set R_ZERO  [file join $scratch zero.raw]
set R_XR1   [file join $scratch xr1.raw]
set R_TRAN  [file join $scratch tran.raw]
set R_NOISE [file join $scratch noise.raw]
set R_DC    [file join $scratch dc.raw]
set R_TWO   [file join $scratch two.raw]
set R_NF    [file join $scratch nf.raw]
set R_ONE   [file join $scratch onechar.raw]

rs_mkraw $R_SIX   [list [list {Operating Point} $F_SIX   $T_SIX]]
rs_mkraw $R_OTHER [list [list {Operating Point} $F_OTHER $T_SIX]]
rs_mkraw $R_ABS   [list [list {Operating Point} $F_ABS   $T_ABS]]
rs_mkraw $R_ZERO  [list [list {Operating Point} $F_ABS   $T_ZERO]]
rs_mkraw $R_XR1   [list [list {Operating Point} $F_XR1   {}]]
rs_mkraw $R_TRAN  [list [list {Transient Analysis} $F_TRAN {}]]
rs_mkraw $R_NOISE [list [list {Noise Spectral Density Curves} $F_NOISE {}]]
rs_mkraw $R_DC    [list [list {DC transfer characteristic} $F_SIX $T_SIX]]

## F_NF — THE NON-FINITE FIXTURE, AND IT MUST BE BINARY. Four columns on one
## device: a NaN, an +Inf, an ordinary finite number, and a GENUINELY COMPUTED
## ZERO. The zero is not padding — issue 1272's acceptance row 3 is that fixing
## the non-finites must not sweep up a real 0, because a cut-off transistor has
## id = 0 and that is a measurement (1259's other half).
set F_NF {
  v(in)             1.5
  i(@m.x1.m1[id])   NAN
  v(@m.x1.m1[vth])  INF
  @m.x1.m1[gm]      0.5
  i(@m.x1.m1[is])   0
}
set T_NF {voltage current voltage notype current}
rs_mkraw_bin $R_NF $F_NF $T_NF

## F_ONE — a device whose hierarchical path STARTS WITH A ONE-CHARACTER
## SEGMENT. `a` is an ordinary subcircuit instance name. This is the second
## blocker that returned item B1 [F]: the normaliser stripped any leading
## one-char segment from either side, so a request for `a.b.c` became `b.c` and
## the device vanished while the seam still answered `state ok`.
set F_ONE {
  v(net1)          1.5
  i(@m.a.b.c[id])  7
  @m.a.b.c[gm]     8
}
rs_mkraw $R_ONE [list [list {Operating Point} $F_ONE {voltage current notype}]]
## Q10's file: ONE raw holding an Operating Point plot and then a Transient
## Analysis plot, which is what an ordinary OP+TRAN run writes.
rs_mkraw $R_TWO   [list [list {Operating Point} $F_SIX $T_SIX] \
                        [list {Transient Analysis} $F_TRAN {}]]

## The six pairs F_SIX publishes for @m.x1.m1, in raw-file order. Spelled ONCE
## here because five rows assert it and a second copy is a second golden.
set SIX_PAIRS {{id 1.11e-05} {is 0} {vth 0.75} {gm 0.001} {vds 1.25} {vgs 0.5}}
set SIX_NAMES {id is vth gm vds vgs}

# ============================================================================
# SECTION S — THE SEAM EXISTS, AND IS REACHED THROUGH THE ONE DISPATCH
# ============================================================================
# RED before B1: S1 S2a.  GREEN before B1 (controls / fences): S0 S2b S3.

check {S0 CONTROL the machinery this item builds on is live: the ONE dispatch, the ONE value accessor, the ONE published-yet gate} \
  [list [expr {[llength [info commands ::ase::backend_hook]] ? 1 : 0}] \
        [expr {[llength [info commands ::op_annot::raw_or_blank]] ? 1 : 0}] \
        [expr {[llength [info commands ::op_annot::_annotated]] ? 1 : 0}] \
        [expr {[llength [info commands ::ase::op_dev_of]] ? 1 : 0}]] \
  {1 1 1 1}

check {S1 ase::backend_hook ngspice op_param_set resolves to a proc that exists} \
  [list [rs_hookname op_param_set] \
        [expr {[llength [info commands [rs_hookname op_param_set]]] ? 1 : 0}]] \
  {::ase::backend::ngspice::op_param_set 1}

check {S2a the companion capability hook resolves too, and is a SECOND hook rather than a field of the answer} \
  [list [rs_hookname op_param_enumerable] \
        [expr {[llength [info commands [rs_hookname op_param_enumerable]]] ? 1 : 0}]] \
  {::ase::backend::ngspice::op_param_enumerable 1}

## The neighbour guard: one dispatch, and it still refuses what it does not
## know. A second dispatch would make this row green while the seam was
## unreachable through the first.
check {S2b CONTROL the ONE dispatch still raises for a hook nobody registered, naming it} \
  [list [catch {ase::backend_hook ngspice op_param_nosuchhook} e] \
        [rs_has $e {unknown hook}] [rs_has $e op_param_nosuchhook]] \
  {1 1 1}

## STRUCTURAL FENCE, and it is not style. Making either new hook REQUIRED
## raises on tests/headless/test_ase_core.tcl:1116 and :1171, which hand-build
## five-hook registrations — in a suite that already carries a baseline red.
set S3_B [rs_body ::ase::register_backend]
set S3_LINE {}
foreach l [split $S3_B "\n"] {
  if {[string first foreach $l] >= 0 && [string first render_deck $l] >= 0} { set S3_LINE $l }
}
set S3_SAVED {}
catch {set S3_SAVED $::ase::backends}
set S3_REG [rs_ans ase::register_backend zzb1five [dict create \
  render_deck  [rs_ans ase::backend_hook ngspice render_deck] \
  run_cmd      [rs_ans ase::backend_hook ngspice run_cmd] \
  log_file     [rs_ans ase::backend_hook ngspice log_file] \
  result_probe [rs_ans ase::backend_hook ngspice result_probe] \
  raw_file     [rs_ans ase::backend_hook ngspice raw_file]]]
if {$S3_SAVED ne {}} { set ::ase::backends $S3_SAVED }
check {S3 STRUCTURAL the required-hook loop still names exactly the five, and a hand-built FIVE-hook registration still succeeds} \
  [list [rs_has $S3_LINE {render_deck run_cmd log_file result_probe raw_file}] \
        [rs_has $S3_LINE op_param_set] \
        [rs_has $S3_LINE op_param_enumerable] \
        [rs_has $S3_LINE capabilities] \
        $S3_REG \
        [expr {[dict exists $::ase::backends zzb1five] ? 1 : 0}]] \
  {1 0 0 0 zzb1five 0}

# ============================================================================
# SECTION V — THE REVERSE MAPPER: ONE SPLITTER, THREE SPELLINGS
# ============================================================================
# op_annot::_wrap (op_annot.tcl:427) is the FORWARD direction and B1 is the
# reverse. Issue 0963 measured that ONE run can spell the same parameter
# `i(@dev[id])` in one results file and bare `@dev[id]` in another, so the
# reverse map must accept all three shapes — and it must be ONE stripper, or
# the two directions drift and the failure is SILENT (invariant I1).
# RED before B1: every row of this section except V2's op_dev_of control leg.

check {V1a all THREE spellings issue 0963 records split to the same device and the same parameter} \
  [list [rs_ans ase::op_param_split {i(@m.x1.m1[id])}] \
        [rs_ans ase::op_param_split {v(@m.x1.m1[id])}] \
        [rs_ans ase::op_param_split {@m.x1.m1[id]}]] \
  {{@m.x1.m1 id} {@m.x1.m1 id} {@m.x1.m1 id}}

## THE BUS TRAP, issue 0972: the parameter's bracket is the LAST one, never the
## first. ase::op_dev_of already cuts this way and the parameter half must
## agree, or the two halves of one name are cut in two different places.
## ⚠ THE GOLDEN IS BUILT WITH `list`, NOT TYPED OUT. Tcl brace-quotes a list
## element containing `[`, so a hand-typed {{@m.x1.m1[3] id} id} does NOT equal
## what `list` produces and the row would red against a correct answer. Both
## sides go through the same constructor here.
check {V1b the bus trap: a bussed device name keeps its index and the LAST bracket is the parameter's} \
  [list [rs_ans ase::op_param_split {i(@m.x1.m1[3][id])}] \
        [rs_ans ase::op_param_of {@m.x1.m1[3][id]}]] \
  [list [list {@m.x1.m1[3]} id] id]

check {V1c a vector that is not a device parameter splits to NOTHING rather than to a guess} \
  [list [rs_ans ase::op_param_split {v(in)}] \
        [rs_ans ase::op_param_split {time}] \
        [rs_ans ase::op_param_split {i(v1)}] \
        [rs_ans ase::op_param_split {@m.x1.m1}] \
        [rs_ans ase::op_param_of {@m.x1.m1}]] \
  {{} {} {} {} {}}

## STRUCTURAL, INVARIANT I1 — ONE splitter, and the two halves of one name are
## cut in the SAME place. op_param_set must not cut brackets itself; when it
## does, the reverse map exists twice and only one copy follows op_annot::_wrap
## when token.c's kind table moves — and that failure is SILENT.
## ⚠ THE ROW NAMES NO MECHANISM ON PURPOSE, except where it is a CONTROL. It
## asks that op_param_split delegates each half rather than re-cutting it, which
## is the plan's own wording; it does not require `string last` of the two new
## procs, because a row that pins how a correct implementation spells its cut is
## a broken test, not a fence. The last two legs ARE mechanism, and they are the
## CONTROL that says ase::op_dev_of was not edited at all — row Q11 of
## tests/headless/test_ase_optier_0963.tcl:2029 fences it independently, reads
## the bodies of op_dev_of / op_cards_devices / op_report_missing ONLY, and a
## THIRD caller does not move it (verified on this tree).
set V2_SET [rs_hookbody op_param_set]
set V2_OF  [rs_body ::ase::op_param_of]
set V2_SPL [rs_body ::ase::op_param_split]
set V2_DEV [rs_body ::ase::op_dev_of]
check {V2 STRUCTURAL one splitter (I1): op_param_set calls op_param_split, cuts no bracket of its own, and each half of a name is cut where it was already cut} \
  [list [rs_has $V2_SET op_param_split] \
        [rs_count $V2_SET {string last}] \
        [rs_has $V2_SPL op_dev_of] \
        [rs_has $V2_SPL op_param_of] \
        [rs_count $V2_DEV {string last}] \
        [rs_count $V2_DEV {string range}]] \
  {1 0 1 1 1 1}

# ============================================================================
# SECTION P — THE PAIRS: WHAT THIS RUN'S RAW ACTUALLY HOLDS
# ============================================================================
# RED before B1: all four rows. The section's own control is P0.

rs_annot $R_SIX
set P_ANN {} ; catch {set P_ANN [xschem raw annot]}
set P_ST  {} ; catch {set P_ST  [xschem raw sim_type]}
set P_NV  {} ; catch {set P_NV  [xschem raw vars]}
check {P0 CONTROL the fixture is live and published: an op slot, nine vectors, an annotation point, and the reader tells absent from zero at point -1} \
  [list [lindex $P_ANN 0] $P_ST $P_NV \
        [rs_ans op_annot::raw_or_blank {i(@m.x1.m1[is])}] \
        [rs_ans op_annot::raw_or_blank {i(@m.x1.m1[id])}]] \
  {0 op 9 0 1.11e-05}

set P1_A [rs_set {@m.x1.m1}]
set P1_D [rs_key $P1_A devices]
check {P1 HEADLINE six saved parameters come back as SIX pairs, under ONE device, in RAW-FILE order} \
  [list [rs_key $P1_A state] [rs_dkeys $P1_D] [rs_dget $P1_D {@m.x1.m1}]] \
  [list ok {@m.x1.m1} $SIX_PAIRS]

## NOT A RESTATEMENT OF P1. This row loads a SECOND raw with the same nine
## vector names and six different values: the seam must answer from the raw
## that is loaded NOW. A cached answer, a memo or a literal passes P1 and fails
## here — "read FROM THE RUN'S OWN RAW" is the brief's own wording.
rs_annot $R_OTHER
set P2_D [rs_key [rs_set {@m.x1.m1}] devices]
rs_annot $R_SIX
set P2_BACK [rs_dget [rs_key [rs_set {@m.x1.m1}] devices] {@m.x1.m1}]
check {P2 the numbers are THIS run's: re-annotating from a second raw with the same vectors changes every one of them, and going back changes them back} \
  [list [rs_dget $P2_D {@m.x1.m1}] $P2_BACK] \
  [list {{id 2e-06} {is 0.25} {vth 0.5} {gm 1e-06} {vds 2.5} {vgs 1.5}} $SIX_PAIRS]

## ISSUE 1259's OTHER HALF, AND IT IS THE HALF THAT MUST NOT BE "FIXED".
## A transistor that is off has id = 0 and that IS a measurement. Blanking
## every zero would hide a genuinely cut-off device.
check {P3 a genuinely computed 0.0 is RETURNED as 0 and is NOT called absent} \
  [list [lindex [rs_dget $P1_D {@m.x1.m1}] 1] \
        [rs_key $P1_A absent]] \
  [list {is 0} {}]

## The seam answers about DEVICE PARAMETERS. A node voltage and a source
## current are in the same raw, in the same slot, and are none of its business.
check {P4 a vector carrying no @ is never reported - not as a device, not as a parameter, not as an absence} \
  [list [rs_params $P1_D {@m.x1.m1}] \
        [rs_key [rs_set {in}] devices] \
        [rs_key [rs_set {v(in)}] devices] \
        [rs_key [rs_set {v1}] devices]] \
  [list $SIX_NAMES {} {} {}]

# ============================================================================
# SECTION A — ABSENCE IS A FIRST-CLASS ANSWER (issue 1259, DD-1's corollary)
# ============================================================================
# THE PAIR OF FIXTURES DIFFERS IN ONE FIELD OF ONE LINE. R_ABS types the `ib`
# column `current dims=0`; R_ZERO types it `current`. Everything else — the
# name, the value 0, the byte count of the Values block — is identical. If the
# seam reads at point 0 instead of point -1 both files answer `ib = 0` and row
# A1 goes green while the seam is lying; if it blanks every zero, A1's control
# and row P3 red together.
# RED before B1: A1 A1c A2 A3.

rs_annot $R_ABS
set A_ANS [rs_set {@m.x1.m1}]
set A_D   [rs_key $A_ANS devices]
rs_annot $R_ZERO
set AC_D  [rs_key [rs_set {@m.x1.m1}] devices]
set AC_AB [rs_key [rs_set {@m.x1.m1}] absent]

check {A1 a dims=0 column is OMITTED from the pairs - six parameters come back where the raw NAMES eight} \
  [list [rs_params $A_D {@m.x1.m1}] [llength [rs_dget $A_D {@m.x1.m1}]]] \
  [list $SIX_NAMES 6]

## NON-VACUITY FOR A1, AND IT IS THE WHOLE OF ISSUE 1259. The same seven
## columns with the dims=0 token stripped give SEVEN pairs, the seventh being
## the measured zero. A1 therefore cannot pass by dropping zeros.
check {A1c CONTROL strip the dims=0 token from those two lines and the SAME columns come back as measured zeros - eight pairs, none absent} \
  [list [rs_params $AC_D {@m.x1.m1}] [lindex [rs_dget $AC_D {@m.x1.m1}] 6] \
        [lindex [rs_dget $AC_D {@m.x1.m1}] 7] $AC_AB] \
  [list {id is vth gm vds vgs ib cgg} {ib 0} {cgg 0} {}]

check {A2 THE HONEST ANSWER: every column the raw NAMED but the simulator did not compute is reported in `absent`, with its device, in raw order} \
  [rs_key $A_ANS absent] \
  {{@m.x1.m1 ib} {@m.x1.m1 cgg}}

rs_annot $R_SIX
check {A3 on a raw with no dims=0 column at all, `absent` is EMPTY - absence is reported, never invented} \
  [rs_key [rs_set {@m.x1.m1}] absent] \
  {}

# ============================================================================
# SECTION D — RULING D-3 (all the primitives) AND ROW Q7's BOUNDARY
# ============================================================================
# D-3: "a multi-primitive instance prints ALL its primitives, if the simulator
# has the data and it is easy to find." The data is in the raw and the only
# common token is the segment `xr1.`, across THREE element letters. The rule
# that finds them must not be a substring test — that is exactly the flaw row
# Q7 of tests/headless/test_ase_optier_0963.tcl exists to forbid, and rows D1's
# decoy and D2 are the two statements of it.
# RED before B1: D1 D1b D2 D3.

rs_annot $R_XR1
set D1_A [rs_set {@r.xr1}]
set D1_D [rs_key $D1_A devices]
check {D1 RULING D-3 one XR1 returns ALL FIVE of its primitives, across three element letters and two depths, in raw-file order} \
  [list [rs_key $D1_A state] [rs_dkeys $D1_D]] \
  [list ok {@r.xr1.x0.rend1 @r.xr1.x0.rend2 @c.xr1.x0.xc0.c0 @c.xr1.x0.xc1.c0 @b.xr1.x0.brbody}]

check {D1b and each of the five carries its own parameter and its own number, with the xr10 decoy excluded} \
  [list [rs_dget $D1_D {@r.xr1.x0.rend1}] [rs_dget $D1_D {@r.xr1.x0.rend2}] \
        [rs_dget $D1_D {@c.xr1.x0.xc0.c0}] [rs_dget $D1_D {@c.xr1.x0.xc1.c0}] \
        [rs_dget $D1_D {@b.xr1.x0.brbody}] \
        [expr {[lsearch -exact [rs_dkeys $D1_D] {@r.xr10.x0.rend1}] >= 0 ? 1 : 0}]] \
  [list {{i 1e-06}} {{i 2e-06}} {{c 1e-15}} {{c 2e-15}} {{i 4e-06}} 0]

rs_annot $R_SIX
set D2_A [rs_set {@m.x1.m1}]
check {D2 ROW Q7's RULE: a request for @m.x1.m1 collects NOTHING belonging to @m.x1.m1foo - one device, six pairs, no substring sweep} \
  [list [rs_dkeys [rs_key $D2_A devices]] [llength [rs_dget [rs_key $D2_A devices] {@m.x1.m1}]]] \
  [list {@m.x1.m1} 6]

## An unknown device is EMPTY, not an error, and the state still says the seam
## was able to look — "nothing matched" must be distinguishable from "nothing
## was published", which is what section G is about.
check {D3 an unknown device returns EMPTY at rc=0, in state ok - empty, never a raise} \
  [rs_sda {@m.zz.nothere}] \
  {ok {} {} 0}

# ============================================================================
# SECTION C — DD-1: THE CAPABILITY IS DECLARED, NEVER MEASURED
# ============================================================================
# RED before B1: C1 C2. C3/C4 are DRIVER ADD (2) and are GREEN-BY-ABSENCE
# before B1 (the bodies do not exist), which is stated here rather than
# discovered: they earn their keep only against the GREEN tree and against the
# SAB-PROBE variant, and they are the rows that red if a later reader replaces
# the declaration with a probe.

check {C1 DD-1 today's ngspice DECLARES that it cannot enumerate a device's parameters, and says so as 0} \
  [rs_cap] 0

set C2_A [rs_set {@m.x1.m1}]
set C2_B [rs_hookbody op_param_set]
check {C2 the honesty flag rides in the ANSWER as data, and is READ FROM THE DECLARATION rather than retyped as a literal} \
  [list [rs_key $C2_A complete] \
        [rs_has $C2_B op_param_enumerable] \
        [expr {[regexp {complete\s+[01]([^0-9]|$)} $C2_B] ? 1 : 0}]] \
  {0 1 0}

## DRIVER ADD (2), STRUCTURAL. The forbidden shapes, by name. `blanket_op_save`
## is on the list because it is the EXISTING measured key that asks B1's own
## question the forbidden way (src/ase.tcl:8460-8467); reading it would look
## like removing a duplication and would be the D-4 violation.
set C3_SET [rs_hookbody op_param_set]
set C3_CAP [rs_hookbody op_param_enumerable]
set C3_GOT {}
foreach n {{exec } sim_capabilities cap_workdir sim_probe_capability blanket_op_save {open |} {open "|}} {
  lappend C3_GOT [expr {[rs_count $C3_SET $n] + [rs_count $C3_CAP $n]}]
}
check {C3 DRIVER ADD 2 STRUCTURAL neither body probes: no exec, no sim_capabilities, no cap_workdir, no probe pipe, and NOT the measured blanket_op_save key} \
  $C3_GOT {0 0 0 0 0 0 0}

## DRIVER ADD (2), BEHAVIOURAL — the half a rename cannot dodge, because it
## does not read the source at all: it watches the three doors a measurement
## has to go through and asks whether any of them opened.
##
## ⚠ THE OBVIOUS FORM OF THIS ROW DOES NOT WORK, MEASURED. `ase::sim_capabilities`
## is LAZY AND CACHED: the first call runs the probe (328 ms and a real ngspice
## launch on this bench, measured 2026-09-03) and every later call is served
## from ::ase::sim_caps. So a plain before/after snapshot taken here sees
## nothing, because rows C1 and C2 above have already warmed the cache — and a
## probe-based op_param_enumerable then passes this row while launching the
## user's simulator. The cache is therefore CLEARED first, and the doors are
## RECORDED rather than inferred. (Also measured: ase::cap_workdir_done removes
## the whole `.ase_probe` tree on the way out, so the folder leg alone catches
## only a probe that died mid-run. It is kept for exactly that case.)
##
## The recorder pattern is tests/headless/test_annot_declutter_1244.tcl's
## dc_rec_install: rename the door aside, install a stub that records, restore.
proc rs_tree {dir} {
  set out {}
  foreach f [lsort [glob -nocomplain -directory $dir -tails * .*]] {
    if {$f eq {.} || $f eq {..}} continue
    set p [file join $dir $f]
    if {[file isdirectory $p]} {
      lappend out "D $f"
      foreach s [rs_tree $p] { lappend out "  $s" }
    } else { lappend out "F $f [file size $p]" }
  }
  return $out
}
set ::rs_probe_seen {}
proc rs_probe_arm {} {
  set ::rs_probe_seen {}
  if {[llength [info commands ::ase::sim_capabilities]]} {
    rename ::ase::sim_capabilities ::rs_real_sim_capabilities
    proc ::ase::sim_capabilities {b} {
      lappend ::rs_probe_seen sim_capabilities
      return [::rs_real_sim_capabilities $b]
    }
  }
  if {[llength [info commands ::ase::cap_workdir]]} {
    rename ::ase::cap_workdir ::rs_real_cap_workdir
    proc ::ase::cap_workdir {} {
      lappend ::rs_probe_seen cap_workdir
      return [::rs_real_cap_workdir]
    }
  }
  ## The backend's own probe hook, recorded and NOT delegated: by the time it
  ## is reached the violation is already proved and there is no reason to spend
  ## a simulator launch on it.
  if {[llength [info commands ::ase::backend::ngspice::capabilities]]} {
    rename ::ase::backend::ngspice::capabilities ::rs_real_ngcapabilities
    proc ::ase::backend::ngspice::capabilities {exe exeargs workdir} {
      lappend ::rs_probe_seen backend_capabilities
      return [dict create known 0]
    }
  }
}
proc rs_probe_disarm {} {
  foreach {stub real} {::ase::sim_capabilities ::rs_real_sim_capabilities \
                       ::ase::cap_workdir ::rs_real_cap_workdir \
                       ::ase::backend::ngspice::capabilities ::rs_real_ngcapabilities} {
    if {[llength [info commands $real]]} {
      catch {rename $stub {}}
      rename $real $stub
    }
  }
}
set C4_CSAVE {} ; catch {set C4_CSAVE $::ase::sim_caps}
catch {set ::ase::sim_caps {}}
set C4_T0 [rs_tree $scratch]
set C4_C0 {} ; catch {set C4_C0 $::ase::sim_caps}
rs_probe_arm
set C4_V [rs_cap]
rs_probe_disarm
set C4_T1 [rs_tree $scratch]
set C4_C1 {} ; catch {set C4_C1 $::ase::sim_caps}
if {$C4_CSAVE ne {}} { catch {set ::ase::sim_caps $C4_CSAVE} }
check {C4 DRIVER ADD 2 BEHAVIOURAL asking the capability opens no door to the simulator: no capability probe, no probe folder, no cached answer} \
  [list $::rs_probe_seen \
        [expr {$C4_T0 eq $C4_T1 ? 1 : 0}] \
        [expr {$C4_C0 eq $C4_C1 ? 1 : 0}] \
        $C4_V] \
  {{} 1 1 0}

# ============================================================================
# SECTION G — THE STATES, AND WHY ABSENCE IS REPORTED IN ONLY ONE OF THEM
# ============================================================================
# MEASURED, and this is the item's central constraint: `xschem raw value <v> -1`
# returns THE EMPTY STRING FOR EVERY VECTOR — good ones included — until
# update_op() has published. So a seam that reported `absent` outside state `ok`
# would say "the simulator did not compute id" about a run nobody had annotated.
# The states exist so a caller can tell FOUR different silences apart.
# RED before B1: G1 G2 G3 G3b's Tcl legs G4 G5.  GREEN before B1: G3b's C leg.

catch {xschem raw clear}
set G1_L {} ; catch {set G1_L [xschem raw loaded]}
check {G1 no raw loaded at all: state no_raw, nothing reported, and NO raise - the caller is told which silence this is} \
  [list $G1_L [rs_sda {@m.x1.m1}]] \
  [list -1 {no_raw {} {} 0}]

catch {xschem raw clear}
catch {xschem raw read $R_SIX op}
set G2_ANN {} ; catch {set G2_ANN [xschem raw annot]}
check {G2 a raw READ but never annotated: state not_annotated, and `absent` is EMPTY - nothing published means no fabricated absence either} \
  [list [lindex $G2_ANN 0] [rs_sda {@m.x1.m1}]] \
  [list -1 {not_annotated {} {} 0}]

## THE ORDER OF THE TWO GATES IS LOAD-BEARING. A transient with cursor B placed
## has annot_p >= 0 (callback.c's backannotate_at_cursor_b_pos), so `raw value
## <v> -1` answers INTERPOLATED TRANSIENT NUMBERS. Publishing those as
## operating-point parameters is a plausible wrong answer, which is the failure
## RULING D5-1 and invariant I3 exist to prevent. The sim_type gate must be
## asked FIRST, and this row's fixture is unannotated so a seam that asked the
## annotated gate first would answer not_annotated here.
catch {xschem raw clear}
catch {xschem raw read $R_NOISE noise}
set G3_ST {} ; catch {set G3_ST [xschem raw sim_type]}
set G3NOISE [lindex [rs_sda {@m.x1.m1}] 0]
check {G3 a slot that is not an operating point is refused as not_op, and the sim_type gate is asked BEFORE the published-yet gate} \
  [list $G3_ST [rs_sda {@m.x1.m1}]] \
  [list noise {not_op {} {} 0}]

catch {xschem raw clear}
catch {xschem raw read $R_TRAN tran}
set G3T [lindex [rs_sda {@m.x1.m1}] 0]
rs_annot $R_DC
set G3DC [lindex [rs_sda {@m.x1.m1}] 0]
rs_annot $R_SIX
set G3OP [lindex [rs_sda {@m.x1.m1}] 0]
## THE CROSS-LANGUAGE FENCE. The Tcl allow-list is COPIED from update_op()'s own
## guard (src/save.c:3780); the C leg reds if that list moves and leaves the
## copy behind.
set G3_C [rs_code [file join $repo src save.c]]
check {G3b CROSS-LANGUAGE FENCE the allow-list is exactly op and dc on BOTH sides - tran and noise refused, dc accepted, and update_op still compares those two literals and no others} \
  [list $G3OP $G3DC $G3T $G3NOISE \
        [regexp -all {strcmp\(xctx->raw->sim_type, "op"\)} $G3_C] \
        [regexp -all {strcmp\(xctx->raw->sim_type, "dc"\)} $G3_C] \
        [regexp -all {strcmp\(xctx->raw->sim_type, "} $G3_C]] \
  {ok ok not_op not_op 1 1 2}

check {G4 an EMPTY devpath is told so: state no_devpath, so "you gave me nothing" is distinguishable from "nothing matched"} \
  [rs_sda {}] \
  {no_devpath {} {} 0}

check {G5 the ordinary case one more time, by state alone: a published operating point answers ok} \
  [rs_key [rs_set {@m.x1.m1}] state] \
  ok

# ============================================================================
# SECTION Q — SPEC QUESTION Q10, THE SIMULATOR-FREE HALF
# ============================================================================
# Q10: "is the RDW reachable after an ordinary OP+TRAN run?" DECISIONS.md says
# it is to be VERIFIED as the RDW suite's first check, not assumed either way.
# The real-ngspice half is recorded in doc/claude/op_param_batch/receipts/B1.md;
# this is the half a fixture can carry, and it is the half that will not rot.
# MEASURED against a real `ngspice -b -r q10m.raw q10m.cir` on this box,
# 2026-09-03: one file, two plots, `xschem raw read <f>` lands on the OP plot,
# `annotate_op` publishes and `raw value <v> -1` returns real numbers. The
# fixture below is that file's shape.
# RED before B1: Q10b.  GREEN before B1: Q10a (it measures the reader, not B1).

catch {xschem raw clear}
catch {xschem raw read $R_TWO op}
set Q10_ST {} ; catch {set Q10_ST [xschem raw sim_type]}
set Q10_NV {} ; catch {set Q10_NV [xschem raw vars]}
check {Q10a the OP slot of a two-plot OP+TRAN file is reachable: reading it lands on the operating point, not on the transient} \
  [list $Q10_ST $Q10_NV] {op 9}

rs_annot $R_TWO
set Q10_A [rs_set {@m.x1.m1}]
check {Q10b and the seam answers from it - the RDW is reachable after an ordinary OP+TRAN run} \
  [list [rs_key $Q10_A state] [rs_dget [rs_key $Q10_A devices] {@m.x1.m1}] [rs_key $Q10_A absent]] \
  [list ok $SIX_PAIRS {}]

# ============================================================================
# SECTION NF — THE NON-FINITE. ISSUE 1272, AND THE REASON B1 CAME BACK [F].
# ============================================================================
# The first version of this suite was GREEN AT 37/37 while the seam returned
# `devices {@m.x1.m1 {{id nan} {gm 0.5}}}` — a NaN in the VALUE bucket, which
# item B3 would have painted on a schematic as `id = nan`, verbatim what
# invariant I3 forbids. Nothing was wrong with the code the suite checked; the
# suite had no non-finite row. That is A7's lesson in a new costume: not a
# measurement taken at the wrong seam, but a fence built around every question
# its author had thought of.
#
# ⚠ EVERY ROW HERE NEEDS THE BINARY FIXTURE. The same NaN in an ASCII raw
# reads back as a confident `0` (src/save.c's my_atof continuation path never
# parsed the words), so an ASCII version of this section passes against the
# defect. NF0 exists to prove the fixture really carries a non-finite, so that
# the five rows after it cannot pass vacuously.
# RED before the 1272 repair: NF1, NF2, NF5, NF6, NF7.

rs_annot $R_NF
set NF_RAWID {} ; catch {set NF_RAWID [xschem raw value {i(@m.x1.m1[id])} -1]}
check_true {NF0 the BINARY fixture really carries a non-finite: the C reader hands back something op_annot::_finite rejects, so the rows below are not vacuous} \
  [expr {$NF_RAWID ne {} && ![::op_annot::_finite $NF_RAWID]}]

check {NF1 1272/1: a NaN column answers BLANK through the accessor - not the string nan, and not a fabricated 0} \
  [::op_annot::raw_or_blank {i(@m.x1.m1[id])}] {}

check {NF2 1272/2: an Inf column answers the same} \
  [::op_annot::raw_or_blank {v(@m.x1.m1[vth])}] {}

check {NF3 1272/3: a GENUINELY COMPUTED ZERO still answers 0 - a cut-off device is a measurement and must not be swept up with the non-finites} \
  [::op_annot::raw_or_blank {i(@m.x1.m1[is])}] 0

check {NF4 a finite value in the same file is untouched} \
  [::op_annot::raw_or_blank {@m.x1.m1[gm]}] 0.5

check {NF5 raw_class tells all three outcomes apart in one call: nonfinite / value / value(zero) / absent} \
  [list [lindex [::op_annot::raw_class {i(@m.x1.m1[id])}] 0] \
        [lindex [::op_annot::raw_class {@m.x1.m1[gm]}] 0] \
        [lindex [::op_annot::raw_class {i(@m.x1.m1[is])}] 0] \
        [lindex [::op_annot::raw_class {i(@m.x1.m1[nosuch])}] 0]] \
  {nonfinite value value absent}

## THE ROW THE WHOLE ITEM TURNS ON. The non-finite must reach the caller as its
## OWN fact: not as a value (B3 paints `id = nan`), and not as an absence
## (a non-converged operating point is a RESULT, and the one a designer most
## wants to be told about).
set NF_A [rs_set {@m.x1.m1}]
check {NF6 THE SEAM: a NaN and an Inf land in `nonfinite` with their text, the finite and the real zero stay in `devices`, and `absent` stays empty} \
  [list [rs_dget [rs_key $NF_A devices] {@m.x1.m1}] \
        [rs_key $NF_A absent] \
        [lsort [lmap e [rs_key $NF_A nonfinite] {lrange $e 0 1}]] \
        [rs_key $NF_A state]] \
  [list {{gm 0.5} {is 0}} {} {{@m.x1.m1 id} {@m.x1.m1 vth}} ok]

## STRUCTURAL, 1272 acceptance row 6. The finite gate lives INSIDE the
## accessor now; before the repair it lived only in the habit of five separate
## callers, and item B1 is the measured case of a sixth that did not inherit it.
set NF_B {} ; catch {set NF_B [rs_nocomment [info body ::op_annot::raw_class]]}
check {NF7 STRUCTURAL the finite test is inside the accessor, not left to the caller: raw_class names _finite in its own body} \
  [rs_has $NF_B _finite] 1

# ============================================================================
# SECTION DN — THE ONE-CHARACTER PATH SEGMENT. B1'S SECOND BLOCKER.
# ============================================================================
# ase::op_dev_norm dropped ANY leading one-character segment, to make ngspice's
# element letter irrelevant per ruling D-3. `a` in `a.b.c` is not an element
# letter, it is a one-character subcircuit instance name, and the device
# silently vanished — answered as `state ok, devices {}`, byte-identical to
# "no such device". A wrong answer wearing a healthy state is worse than an
# error. The repair gates the strip on the leading `@`, which every real
# producer of raw spelling carries and a typed hierarchical path does not.
# RED before the repair: DN1, DN3.

check {DN1 a path with NO leading @ keeps every segment: a one-character first segment is a subcircuit instance, not an element letter} \
  [::ase::op_dev_norm {a.b.c}] {a.b.c}

check {DN2 and a path WITH the leading @ still loses the element letter, which is ruling D-3 and must not regress} \
  [::ase::op_dev_norm {@m.a.b.c}] {a.b.c}

rs_annot $R_ONE
set DN_A [rs_set {a.b.c}]
set DN_B [rs_set {@m.a.b.c}]
check {DN3 BOTH SPELLINGS FIND THE DEVICE: the hierarchical path the user would type answers exactly what the raw's own spelling answers} \
  [list [rs_dget [rs_key $DN_A devices] {@m.a.b.c}] [rs_key $DN_A state] \
        [rs_dget [rs_key $DN_B devices] {@m.a.b.c}] [rs_key $DN_B state]] \
  [list {{id 7} {gm 8}} ok {{id 7} {gm 8}} ok]

check {DN4 REGRESSION the segment-boundary rule survives the repair: m1 must still not collect m1foo (row Q7 of test_ase_optier_0963)} \
  [list [::ase::op_dev_covers {@m.x1.m1} {@m.x1.m1foo}] \
        [::ase::op_dev_covers {@m.x1.m1} {@m.x1.m1}] \
        [::ase::op_dev_covers {xr1} {@r.xr1.x0.rend1}] \
        [::ase::op_dev_covers {xr1} {@r.xr10.x0.rend1}]] \
  {0 1 1 0}

# ============================================================================
# SECTION I — INVARIANT I3, STRUCTURALLY: ONE VALUE ACCESSOR
# ============================================================================
# op_annot::raw_class is the three-outcome accessor — absent / nonfinite /
# value — and it reads at point -1, which is the only point carrying the
# absent/zero distinction. A private `xschem raw value` inside op_param_set is
# a second reader of the same thing, and the moment it reaches for point 0
# (which is unguarded on purpose, scheduler.c:11067) the seam publishes a
# fabricated zero.
#
# ⚠ THIS ROW NAMED raw_or_blank UNTIL 2026-09-03 AND IT CAUGHT THE REPAIR THAT
# FIXED ITS OWN ITEM. That is the row working, not the row being wrong: B1 came
# back [F] because raw_or_blank answers a TWO-outcome question and this seam
# asks a three-outcome one (issue 1272), so the accessor moved and the fence
# had to be re-aimed at the new one. What the row protects is unchanged and is
# the half that matters — op_param_set reads through ONE published accessor and
# calls `xschem raw value` nowhere itself.
#
# ⚠ THE READER STRIPS WHOLE-LINE `#` COMMENTS ONLY. A TRAILING `;# ... raw
# value ...` on a code line of op_param_set reds this row. Say it in prose
# above the proc, the way this file does, not on the code line.
# RED before B1: I3.

set I3_B [rs_hookbody op_param_set]
check {I3 STRUCTURAL one value accessor: op_param_set reads through op_annot::raw_class and calls `xschem raw value` nowhere itself} \
  [list [rs_has $I3_B raw_class] [rs_count $I3_B {raw value}]] \
  {1 0}

# ============================================================================
# SECTION R — REGISTRATION
# ============================================================================
# full_audit.sh selects by GLOB; the three named lists are OPT-INS for special
# run modes. This suite needs no X and is in NONE of them, and full_audit.sh is
# NOT edited by item B1. GREEN before B1.
set R_ME  [file rootname [file tail [info script]]]
set R_TXT [rs_slurp $RS_AUDIT]
check {R1 registered by glob, listed in none of nogui_tests / logdir_tests / nolog_tests} \
  [list [string match {test_*} $R_ME] \
        [expr {[regexp {mapfile -t files < <\(ls "\$HERE"/test_\*\.tcl \| sort\)} $R_TXT] ? 1 : 0}] \
        [expr {[string first $R_ME $R_TXT] >= 0 ? 1 : 0}]] \
  {1 1 0}

# ============================================================================
# SECTION H — HYGIENE (hard rule 6)
# ============================================================================
# An untracked untitled*.sch in the repo root turns THREE tests red. This suite
# loads no schematic and saves none; the row says so out loud rather than
# leaving it to be discovered. ⚠ The repo root ALREADY holds untitled~.sch and
# untitled~.sym, and they are DELIBERATELY LEFT THERE (they are the known cause
# of test_ase_core's C11 baseline red, a phantom nothing in this batch may
# "fix"), so the row compares the glob against itself rather than asserting it
# is empty.
set H_ROOT0 [lsort [glob -nocomplain -directory $repo -tails untitled*]]
check {H1 HYGIENE the suite creates no untitled* anywhere: the repo root glob is unchanged and neither the scratch dir nor tests/headless gained one} \
  [list [expr {[lsort [glob -nocomplain -directory $repo -tails untitled*]] eq $H_ROOT0 ? 1 : 0}] \
        [llength [glob -nocomplain -directory $scratch -tails untitled*]] \
        [llength [glob -nocomplain -directory $here -tails untitled*]]] \
  {1 0 0}

# --- clean up ---------------------------------------------------------------
catch {xschem raw clear}

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; exit 1 }
