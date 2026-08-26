# test_raw_read_dispatch.tcl — `xschem raw_read <file> <type>` must pick its reader
# from <type>, for EVERY reader, and the database must survive the trip.
# doc/claude/issues/0290-raw_read-bypasses-the-non-spice-reader-dispatch.md
#
# THE BUG. `xschem raw_read` does not go through extra_rawfile(); it repeated
# extra_rawfile()'s type->reader dispatch by hand, and the copy had drifted: it
# knew "vcd" and not "table". `raw_read <f> table` therefore handed a tabular
# file to the ngspice raw parser, which looks for `Plotname:` / `No. Variables:`
# / `Values:`, finds none and returns 0 — after the arm's opening
# extra_rawfile(3, ...) had already cleared the WHOLE registry. Net effect: the
# database is gone and nothing replaced it. No crash, no dialog.
#
# WHY IT MATTERS (group E, the load-bearing one). Two shipped Tcl paths carry the
# current database into a new window by round-tripping its own sim_type back
# through this exact command:
#     xschem raw_read $rawfile [xschem raw_query sim_type]
# — open_sub_schematic and hi_descend's new-window arm, both in src/xschem.tcl.
# So the user-visible bug is: load a table, descend into a sub-schematic in a new
# window, waveforms silently gone. Group D alone does NOT prove that; group E
# drives the real procs.
#
# THE SECOND HALF. table_read() does not stamp raw->sim_type (vcd_read() does),
# so the dispatch must stamp it or the database enters the registry with a NULL
# sim_type — which is not cosmetic: both lookup loops in extra_rawfile() SKIP an
# entry whose sim_type is NULL, so `xschem raw switch` can never reach it again,
# and seven sites strcmp() it with no NULL guard. Hence D2/D6/D7 and R9/R10:
# every format group asserts sim_type AND round-trips `raw switch`.
#
# Run TRUE HEADLESS from the repo root (needs no display; verified with DISPLAY
# unset, which is why it is in full_audit.sh's nogui_tests):
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_raw_read_dispatch.tcl

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
proc pcall {args} {
  if {[catch {uplevel 1 $args} r]} { return "ERR:$r" }
  return $r
}

# test_scratch owns the directory's lifetime (issue 0148).
set tmp [test_scratch rawdisp]
proc wr {path body} {
  file mkdir [file dirname $path]
  set fp [open $path w]
  puts -nonewline $fp $body
  close $fp
}
# does `xschem raw info` list this file with this type?
proc info_has {f type} {
  return [string match "*[file tail $f] $type*" [pcall xschem raw info]]
}

# --- the three fixtures, one per reader --------------------------------------
# a tabular file: header row + 3 data rows
wr $tmp/t.table "time\ta\tb\n0.0\t1.0\t2.0\n1e-9\t3.0\t4.0\n2e-9\t5.0\t6.0\n"
# a VCD: one scalar, one edge. Materializes as 4 points (seed, hold at t-1, the
# change, and the final timestamp).
wr $tmp/t.vcd "\$timescale 1ps \$end
\$scope module m \$end
\$var wire 1 ! a \$end
\$upscope \$end
\$enddefinitions \$end
#0
0!
#100
1!
#200
"
# an ascii ngspice raw: the reader that everything NOT in the table falls back to
wr $tmp/an.raw "Title: dispatch
Plotname: Transient Analysis
Flags: real
No. Variables: 2
No. Points: 3
Variables:
\t0\ttime\ttime
\t1\tv(n1)\tvoltage
Values:
0\t0.000000000000000e+00
\t1.000000000000000e+00

1\t1.000000000000000e-08
\t2.000000000000000e+00

2\t2.000000000000000e-08
\t3.000000000000000e+00

"
# a table with no data at all (comments only). table_read() returns 1 but leaves
# raw->values NULL, so sch_waves_loaded() is -1 for it — the case where a stamp
# conditioned on sch_waves_loaded() silently does not happen.
wr $tmp/c.table "# only comments\n# and nothing else\n"

# ===========================================================================
# D — the bypass door itself: `xschem raw_read <file> <type>`
# ===========================================================================
xschem raw clear
# --- table: the arm that was missing (issue 0290) ---------------------------
eqcheck D1-table-read      [pcall xschem raw_read $tmp/t.table table] 1
eqcheck D2-table-simtype   [pcall xschem raw sim_type] table
eqcheck D3-table-vars      [pcall xschem raw vars] 3
eqcheck D4-table-points    [pcall xschem raw points] 3
eqcheck D5-table-value     [pcall xschem raw value a 1] 3
check   D6-table-in-registry [info_has $tmp/t.table table] "(info='[string map {\n |} [pcall xschem raw info]]')"
# the NULL-sim_type trap: extra_rawfile()'s lookup loop skips a NULL sim_type,
# so a DB stamped NULL is unreachable by `raw switch` forever
eqcheck D7-table-switchable [pcall xschem raw switch $tmp/t.table table] 1

# --- vcd: the arm §C added; it must still work through the same dispatch ----
xschem raw clear
eqcheck D8-vcd-read        [pcall xschem raw_read $tmp/t.vcd vcd] 1
eqcheck D9-vcd-simtype     [pcall xschem raw sim_type] vcd
eqcheck D10-vcd-vars       [pcall xschem raw vars] 2
eqcheck D11-vcd-value      [pcall xschem raw value m.a 3] 1
eqcheck D12-vcd-switchable [pcall xschem raw switch $tmp/t.vcd vcd] 1

# --- the spice fall-through must be untouched -------------------------------
xschem raw clear
eqcheck D13-spice-read     [pcall xschem raw_read $tmp/an.raw tran] 1
eqcheck D14-spice-simtype  [pcall xschem raw sim_type] tran
eqcheck D15-spice-value    [pcall xschem raw value v(n1) 2] 3
# no type at all == "first analysis found in the file"
xschem raw clear
eqcheck D16-notype-read    [pcall xschem raw_read $tmp/an.raw] 1
eqcheck D17-notype-simtype [pcall xschem raw sim_type] tran
# an EMPTY type is the same thing as no type — open_sub_schematic passes
# [xschem raw_query sim_type] straight through, which can be empty. Before the
# fix this reached read_dataset() as "", matched no analysis, and read nothing.
xschem raw clear
eqcheck D18-emptytype-read    [pcall xschem raw_read $tmp/an.raw {}] 1
eqcheck D19-emptytype-simtype [pcall xschem raw sim_type] tran

# --- the discriminators: the type IS the key, it is not sniffed -------------
# a table file declared "tran" must FAIL, not be rescued by content sniffing.
# (test_vcd_time_base's S19 pins the same expectation for a VCD read as "tran".)
xschem raw clear
eqcheck D20-table-as-tran-fails [pcall xschem raw_read $tmp/t.table tran] 0
# an unknown token is not silently treated as a non-spice format either
xschem raw clear
eqcheck D21-unknown-type-fails  [pcall xschem raw_read $tmp/t.table tabular] 0

# ===========================================================================
# R — the registry door (extra_rawfile) must agree with the bypass door.
#     Both now consult the same dispatch table, so these are the anti-drift
#     checks: any type the one door knows, the other knows.
# ===========================================================================
xschem raw clear
eqcheck R1-raw-read-table     [pcall xschem raw read $tmp/t.table table] 1
eqcheck R2-raw-read-simtype   [pcall xschem raw sim_type] table
xschem raw clear
eqcheck R3-raw-table_read     [pcall xschem raw table_read $tmp/t.table] 1
eqcheck R4-raw-table_read-st  [pcall xschem raw sim_type] table
xschem raw clear
eqcheck R5-raw-read-vcd       [pcall xschem raw read $tmp/t.vcd vcd] 1
eqcheck R6-raw-read-vcd-st    [pcall xschem raw sim_type] vcd
xschem raw clear
eqcheck R7-raw-vcd_read       [pcall xschem raw vcd_read $tmp/t.vcd] 1
eqcheck R8-raw-vcd_read-st    [pcall xschem raw sim_type] vcd

# The top-level `xschem table_read` / `xschem vcd_read` verbs also paired a
# reader call with a hand-written sim_type stamp — and hung that stamp on
# sch_waves_loaded(), which is FALSE for a data-less table (raw->values NULL).
# Such a DB used to enter the registry with sim_type <NULL>: listed as <NULL>
# by `raw info` and unreachable by `raw switch` forever.
xschem raw clear
pcall xschem table_read $tmp/c.table
check   R9-dataless-table-typed [info_has $tmp/c.table table] \
  "(info='[string map {\n |} [pcall xschem raw info]]')"
eqcheck R10-dataless-table-switchable [pcall xschem raw switch $tmp/c.table table] 1
xschem raw clear
pcall xschem vcd_read $tmp/t.vcd
eqcheck R11-topverb-vcd-simtype [pcall xschem raw sim_type] vcd
xschem raw clear

# ===========================================================================
# GUARD / INJ / ORD / VAR / KEY — issue 0812: A FILENAME IS DATA, NOT SCRIPT.
#   doc/claude/issues/0812-extra-rawfile-substs-the-raw-path-so-a-crafted-filename-executes-tcl.md
#
# THE DEFECT. extra_rawfile() (save.c) resolves its `file` argument by BUILDING
# THE TCL SCRIPT `subst { <file> }` and evaluating it — six call sites (two read
# arms, two switch arms, two clear arms; the two behind isonlydigit() cannot be
# reached with a metacharacter, so FOUR of the six fire). A `}` anywhere in the
# filename CLOSES the brace group and the rest of the name RUNS AS TCL. The
# scheduler.c verbs `raw_read` / `table_read` / `vcd_read` / `embed_rawfile`
# reach the same end by a different road: `regsub {^~/} {<argv>} {<home>/}`
# spliced into tcleval().
#
# ⚠ THREE SINK SHAPES, THREE PAYLOADS, NOT INTERCHANGEABLE. This is the trap
# that under-reports the defect, and it is why there are three payload files:
#     subst sink, brace escape   q}; set ::SC_PWNED 1; list {a.raw
#     regsub sink                x} {y} {z}; set ::SC_PWNED 1; list {a   (NO
#                   slash, or the name becomes a directory path and never
#                   reaches the splice)
#     VARIABLE ARRAY INDEX       $noar0812([set ::SC_PWNED 1]).raw
# Feed the FIRST to the regsub sink and it lands as `regsub {^~/} {...q}` — too
# few arguments, the script errors on command 1, the sentinel never runs, and
# the row reports a clean PWNED=0 over a live defect.
#
# ⚠ THE ARRAY-INDEX SHAPE IS THE ONE THAT REFUTED ATTEMPT 1 (0812 §1, §3). That
# attempt sanitized with `subst -nobackslashes -nocommands`, believing `[` and
# `]` were thereby literal. `-nocommands` suppresses only TOP-LEVEL command
# substitution: a command substitution inside a VARIABLE ARRAY INDEX is still
# evaluated, BEFORE the (failing) array lookup, so the array need not even
# exist. Its four suites were ALL PASS with the defect fully live. Any row set
# without INJ11-INJ17 here is the same green-over-live-ACE.
#
# ⚠ EVERY INJ ROW ASSERTS A SIDE EFFECT — the sentinel ::SC_PWNED, or a FILE
# CREATED ON DISK — NEVER A RETURN CODE. The payload can run AND the command can
# then fail; a row that only checks for an error has not tested this.
#
# THE ORD/VAR/KEY ROWS ARE THE COUNTERWEIGHT — the easy wrong fix is to refuse
# anything unusual. Six of them are FIXES, not regression guards: measured at
# HEAD through `xschem raw read`, plain 1 / spaces 1 / relative 1 but brackets 0
# / dollar 0 / backslash 0 / `~/` 0 / array-shaped 0 / `$scalar(1)` 0. A `[` or
# `$` makes subst FAIL and the code then my_strncpy's the FAILED result, so the
# filename silently becomes the EMPTY STRING (`failed to open file  for
# reading`, nothing between the two spaces); a `\` is EATEN (a real
# `back\slash.raw` is opened as `backslash.raw`); `~/` never worked through this
# verb at all (subst does no tilde expansion and my_fopen() just stat()s) — it
# works through `xschem annotate_op` ONLY because scheduler.c expands it in C
# one frame up, which is the whole shape of the fix.
#
# VAR0-VAR4 ARE LOAD-BEARING AND ARE GREEN AT HEAD. The substitution is not
# gratuitous: nine draw.c/callback.c sites hand extra_rawfile() a graph
# `rawfile=` attribute UNSUBSTITUTED and the shipped corpus spells it
# `$netlist_dir/...`. VAR0 asserts that PREMISE against the shipped files at run
# time (so it cannot rot silently) and VAR2-VAR4 load each exact shipped
# spelling. A fix that buys safety by deleting the expansion reds all five.
#
# KEY1/KEY2/KEY3 pin the ONE-RESOLVER invariant (I1). read / switch / clear all
# strcmp() against the string the READ arm stored, so if the arms resolve
# differently `xschem raw clear $f` stops matching what `xschem raw read $f`
# stored — src/ase.tcl:2040-2044 does exactly that pair and is first to break.
# KEY3 adds IDEMPOTENCE, which scheduler.c's annotate_op needs by construction:
# it feeds the already-resolved xctx->raw->rawfile back through the clear arm.
# ===========================================================================
set INJ_OK   [file join $tmp inj_ok.raw]
file copy -force $tmp/an.raw $INJ_OK
# the payload-named files, all VALID ascii tran raws so a fixed resolver must
# OPEN them rather than merely refuse them (INJ10)
set INJ_SUBST  [file join $tmp "q\}; set ::SC_PWNED 1; list \{a.raw"]
set INJ_REGSUB [file join $tmp "x\} \{y\} \{z\}; set ::SC_PWNED 1; list \{a"]
file copy -force $INJ_OK $INJ_SUBST
file copy -force $INJ_OK $INJ_REGSUB
# the ordinary-case names: a space, a literal bracket, a literal backslash, a
# literal `$` naming a variable that does not exist, and an ARRAY-SHAPED name
# that really is on disk
set INJ_SPACE [file join $tmp "with space.raw"]
set INJ_BRACK [file join $tmp "br\[1\].raw"]
set INJ_BSLSH [file join $tmp "back\\slash.raw"]
set INJ_DOLLR [file join $tmp "pay\$no_such_var_0812.raw"]
set INJ_AIDXF [file join $tmp "\$noar0812(1).raw"]
set INJ_PAREN [file join $tmp "zz(1).raw"]
foreach _p [list $INJ_SPACE $INJ_BRACK $INJ_BSLSH $INJ_DOLLR $INJ_AIDXF $INJ_PAREN] {
  file copy -force $INJ_OK $_p
}

# The `~/` probe MUST live directly under $HOME — that is the only place the
# `~/` form can name. Same 0148-class discipline as
# tests/headless/test_perform_action_embed_rawfile.tcl check (d): delete on
# EVERY exit path, and sweep dead-pid corpses of earlier runs on the way in,
# because nothing else ever sweeps $HOME.
set INJ_HNAME rawdisp0812probe_[pid].raw
set INJ_HRAW  [file join $::env(HOME) $INJ_HNAME]
foreach _f [glob -nocomplain -directory $::env(HOME) rawdisp0812probe_*.raw] {
  if {![regexp {^rawdisp0812probe_([0-9]+)\.raw$} [file tail $_f] -> _p]} continue
  if {$_p eq [pid] || [__scratch_pid_alive $_p]} continue
  catch {file delete -force $_f}
}
if {[info commands ::__inj_real_exit] eq {}} {
  rename ::exit ::__inj_real_exit
  proc ::exit {{code 0}} { catch {file delete -force $::INJ_HRAW}; ::__inj_real_exit $code }
}
file copy -force $INJ_OK $INJ_HRAW

# Drive one command with the sentinel armed; answer {sentinel result}. The
# sentinel is set to 0 IMMEDIATELY before the call, so a 1 can only have been
# written by the filename.
proc inj_probe {args} {
  set ::SC_PWNED 0
  set r [uplevel 1 [list pcall {*}$args]]
  return [list $::SC_PWNED $r]
}
# Drive one command and answer whether the named HOST FILE was created. The
# sentinel proves a Tcl command ran; this proves the process reached out and
# touched the filesystem, which is the shape a reader cannot argue with.
proc inj_owned {path args} {
  catch {file delete -force $path}
  uplevel 1 [list pcall {*}$args]
  set e [file exists $path]
  catch {file delete -force $path}
  return $e
}

# --- GUARD: the STRUCTURAL rows. No evaluator may be reached at all ---------
# ⚠ NECESSARY, NOT SUFFICIENT, and the comment must stay honest about that: a
# resolver that called Tcl_SubstObj() from C would evaluate the path WITHOUT
# dispatching through the `subst` COMMAND, so these two rows would stay green
# over a live sink. They exist because they are the rows that name the DEFECT'S
# MECHANISM rather than one of its payloads — attempt 1 was refuted by a payload
# nobody had written a row for, and a mechanism row does not depend on guessing
# the payload. The INJ rows are the sufficient half.
proc guard_arm_subst {} {
  set ::GUARD_SUBST {}
  if {[info commands ::__guard_real_subst] eq {}} {
    rename ::subst ::__guard_real_subst
    ## uplevel 1, so the forwarded subst still resolves variables in the frame
    ## the C caller evaluated in (TCL_EVAL_GLOBAL) and the trap does not itself
    ## change what the sink does.
    proc ::subst {args} {
      lappend ::GUARD_SUBST $args
      return [uplevel 1 [list ::__guard_real_subst {*}$args]]
    }
  }
}
proc guard_disarm_subst {} {
  if {[info commands ::__guard_real_subst] ne {}} {
    rename ::subst {}
    rename ::__guard_real_subst ::subst
  }
}
## Only a `^~/` first argument is recorded: that is the splice's own literal
## pattern, so an incidental regsub somewhere in the Tcl layer cannot false-red
## this row.
proc guard_arm_regsub {} {
  set ::GUARD_REGSUB {}
  if {[info commands ::__guard_real_regsub] eq {}} {
    rename ::regsub ::__guard_real_regsub
    proc ::regsub {args} {
      foreach _a $args { if {$_a eq {^~/}} { lappend ::GUARD_REGSUB $args; break } }
      return [uplevel 1 [list ::__guard_real_regsub {*}$args]]
    }
  }
}
proc guard_disarm_regsub {} {
  if {[info commands ::__guard_real_regsub] ne {}} {
    rename ::regsub {}
    rename ::__guard_real_regsub ::regsub
  }
}

set INJ_NDIR_SAVE [expr {[info exists ::netlist_dir] ? $::netlist_dir : {}}]
set ::netlist_dir $tmp

xschem raw clear
guard_arm_subst
catch {xschem raw read {$netlist_dir/inj_ok.raw} tran}
catch {xschem raw read $INJ_SUBST tran}
catch {xschem raw read {$noar0812([set ::SC_PWNED 1]).raw} tran}
guard_disarm_subst
check GUARD1-no-subst-command [expr {[llength $::GUARD_SUBST] == 0}] \
  "(the `subst` COMMAND was invoked [llength $::GUARD_SUBST] time(s) while resolving a path: {[join $::GUARD_SUBST { | }]})"

xschem raw clear
guard_arm_regsub
catch {xschem raw_read $INJ_OK tran}
xschem raw clear
catch {xschem table_read $tmp/t.table}
xschem raw clear
catch {xschem vcd_read $tmp/t.vcd}
xschem raw clear
catch {xschem embed_rawfile $INJ_OK}
catch {xschem annotate_op $INJ_OK 0}
guard_disarm_regsub
check GUARD2-no-regsub-splice [expr {[llength $::GUARD_REGSUB] == 0}] \
  "(a `regsub {^~/} ...` splice ran [llength $::GUARD_REGSUB] time(s): {[join $::GUARD_REGSUB { | }]})"

## GUARD3 — issue 0819. The resolver's only Tcl call is Tcl_GetVar2Ex, which is
## a variable READ, and a variable read RUNS ANY `trace ... read` attached to
## that global. Measured on this tree: a read trace on `::trapvar` fired from
## `xschem raw read {$trapvar/plain.raw}`, did `exec touch` (host file created)
## and REWROTE the resolved path to /etc/plain.raw. The reason that gadget has
## no target is an accident of the current tree — every shipped trace is a
## `write` trace — and nothing pinned it, so a single `trace ... read` added in
## passing would silently re-arm a .sch-reachable evaluator with no suite going
## red. This row is that pin. It cannot cover a user's own ~/.xschem/xschemrc:
## by the time that file runs, the user has already executed their own Tcl.
set ::GUARD3_HITS {}
foreach _f [glob -nocomplain [file join [file normalize [file join [file dirname [info script]] .. ..]] src *.tcl]] {
  set _fd [open $_f r]; set _b [read $_fd]; close $_fd
  set _ln 0
  foreach _l [split $_b "\n"] {
    incr _ln
    if {[regexp {trace\s+add\s+variable\s+\S+\s+(\S+)} $_l -> _ops] && [string match *read* $_ops]} {
      lappend ::GUARD3_HITS "[file tail $_f]:$_ln"
    } elseif {[regexp {trace\s+variable\s+\S+\s+([rwu]+)\s} $_l -> _ops] && [string match *r* $_ops]} {
      lappend ::GUARD3_HITS "[file tail $_f]:$_ln (legacy)"
    }
  }
}
check GUARD3-no-shipped-read-trace [expr {[llength $::GUARD3_HITS] == 0}] \
  "(a Tcl variable READ TRACE ships in src/*.tcl, so the path resolver can reach\
 an evaluator after all — issue 0819: [join $::GUARD3_HITS { | }])"

# --- the subst sink, save.c extra_rawfile() --------------------------------
xschem raw clear
set inj1 [inj_probe xschem raw read $INJ_SUBST tran]
eqcheck INJ1-read-subst-sink   [lindex $inj1 0] 0
# ...and the SAME call must OPEN the file: refusing an unusual name is a
# regression, not a fix. (save.c:1813, the arm `xschem annotate_op` reaches.)
eqcheck INJ10-payload-name-loads [lindex $inj1 1] 1
eqcheck INJ10b-payload-name-stored [pcall xschem raw rawfile] $INJ_SUBST

# the switch arm (save.c:1864) is skipped wholesale when the registry is EMPTY
# (`what == 2 && extra_raw_n > 0`), so it must be probed with something loaded
# or the row is green over a live sink.
xschem raw clear
pcall xschem raw read $INJ_OK tran
eqcheck INJ2-switch-subst-sink [lindex [inj_probe xschem raw switch $INJ_SUBST tran] 0] 0

# both clear arms (save.c:1954), with a non-empty registry so the arm does work
xschem raw clear
pcall xschem raw read $INJ_OK tran
eqcheck INJ3-clear-with-type   [lindex [inj_probe xschem raw clear $INJ_SUBST tran] 0] 0
xschem raw clear
pcall xschem raw read $INJ_OK tran
eqcheck INJ4-clear-no-type     [lindex [inj_probe xschem raw clear $INJ_SUBST] 0] 0

# the NON-SPICE read arm (save.c:1766) — a different arm, the same sink
xschem raw clear
eqcheck INJ5-raw-table_read    [lindex [inj_probe xschem raw table_read $INJ_SUBST] 0] 0
xschem raw clear
eqcheck INJ6-raw-vcd_read      [lindex [inj_probe xschem raw vcd_read $INJ_SUBST] 0] 0

# --- the regsub sink, scheduler.c ------------------------------------------
# NOTE THE OTHER PAYLOAD. These three verbs never reach extra_rawfile()'s subst
# with their argument; they splice it into `regsub {^~/} {%s} {%s/}` themselves.
xschem raw clear
eqcheck INJ7-raw_read-verb     [lindex [inj_probe xschem raw_read $INJ_REGSUB tran] 0] 0
xschem raw clear
eqcheck INJ8-table_read-verb   [lindex [inj_probe xschem table_read $INJ_REGSUB] 0] 0
xschem raw clear
eqcheck INJ9-vcd_read-verb     [lindex [inj_probe xschem vcd_read $INJ_REGSUB] 0] 0

# --- the VARIABLE ARRAY INDEX sink — the shape that refuted attempt 1 ------
# The array `noar0812` DOES NOT EXIST. It does not need to: Tcl substitutes a
# variable reference's INDEX before it looks the element up, so the command in
# the index runs and only then does the lookup fail.
xschem raw clear
eqcheck INJ11-aidx-read \
  [lindex [inj_probe xschem raw read {$noar0812([set ::SC_PWNED 1]).raw} tran] 0] 0
xschem raw clear
eqcheck INJ12-aidx-read-namespaced \
  [lindex [inj_probe xschem raw read {$::nsx0812::a0812([set ::SC_PWNED 1]).raw} tran] 0] 0
xschem raw clear
pcall xschem raw read $INJ_OK tran
eqcheck INJ13-aidx-clear \
  [lindex [inj_probe xschem raw clear {$noar0812([set ::SC_PWNED 1]).raw} tran] 0] 0
xschem raw clear
pcall xschem raw read $INJ_OK tran
eqcheck INJ14-aidx-switch \
  [lindex [inj_probe xschem raw switch {$noar0812([set ::SC_PWNED 1]).raw} tran] 0] 0

# --- THE HOST SIDE EFFECT, on paths that DO NOT EXIST ON DISK --------------
# `exec touch` is not a sentinel a test wrote into its own interpreter: it is
# the process creating a file. And the named path exists nowhere — the resolver
# runs BEFORE any stat(), so non-existence is not a defence.
set INJ_OWN1  [file join $tmp OWNED_READ]
set INJ_OWN2  [file join $tmp OWNED_TABLE]
set INJ_EXEC1 "\$noar0812(\[exec touch $INJ_OWN1\]).raw"
set INJ_EXEC2 "\$noar0812(\[exec touch $INJ_OWN2\]).raw"
xschem raw clear
eqcheck INJ15-exec-hostfile-read  [inj_owned $INJ_OWN1 xschem raw read $INJ_EXEC1 tran] 0
xschem raw clear
eqcheck INJ16-exec-hostfile-table [inj_owned $INJ_OWN2 xschem raw table_read $INJ_EXEC2] 0

# ...and the brace payload on a path that was NEVER CREATED, for the same reason
xschem raw clear
set INJ_GHOST [file join $tmp "ghost_q\}; set ::SC_PWNED 1; list \{b.raw"]
catch {file delete -force $INJ_GHOST}
eqcheck INJ17-nonexistent-path [inj_probe xschem raw read $INJ_GHOST tran] {0 0}

# --- ORD: the ordinary filenames that must still load ----------------------
# Answer {rc rawfile} so a row that "loads" something under a MANGLED name is
# not mistaken for a pass.
proc inj_rd {f {t tran}} {
  xschem raw clear
  set r [pcall xschem raw read $f $t]
  return [list $r [pcall xschem raw rawfile]]
}
eqcheck ORD1-plain     [inj_rd $INJ_OK]    [list 1 $INJ_OK]
eqcheck ORD2-spaces    [inj_rd $INJ_SPACE] [list 1 $INJ_SPACE]
eqcheck ORD3-brackets  [inj_rd $INJ_BRACK] [list 1 $INJ_BRACK]
eqcheck ORD4-backslash [inj_rd $INJ_BSLSH] [list 1 $INJ_BSLSH]
eqcheck ORD5-dollar    [inj_rd $INJ_DOLLR] [list 1 $INJ_DOLLR]
set INJ_CWD [pwd]
cd $tmp
eqcheck ORD6-relative  [lindex [inj_rd inj_ok.raw] 0] 1
cd $INJ_CWD
eqcheck ORD7-tilde     [inj_rd ~/$INJ_HNAME] [list 1 $INJ_HRAW]
# an ARRAY-SHAPED name that really is a file: neither executed nor refused. The
# `$noar0812` reference is undefined, so it is copied through literally and the
# whole name opens as itself. (Nothing here can create a file — the point is
# that a name of this SHAPE is ordinary data.)
eqcheck ORD8-array-shaped-name [inj_rd $INJ_AIDXF] [list 1 $INJ_AIDXF]
# `(` IS NEVER AN INDEX OPENER (issue 0812 decision D2). With ::a0812 holding
# `<tmp>/zz`, the name `$a0812(1).raw` must open the file literally called
# `zz(1).raw` — a value followed by literal parens, NOT an array element. This
# row is where D2's cost is priced, rather than only in a code comment.
set ::a0812 [file join $tmp zz]
eqcheck ORD9-paren-not-index [inj_rd {$a0812(1).raw}] [list 1 $INJ_PAREN]

# --- VAR: the substitution that must SURVIVE (the shipped corpus) ----------
# VAR0 is the PREMISE, asserted against the shipped files at run time: if
# nothing shipped spells a rawfile with a variable any more, VAR1-VAR4 would be
# guarding nothing and this row says so out loud.
set INJ_REPO [file normalize [file join [file dirname [info script]] .. ..]]
proc inj_grep {rel needle} {
  set p [file join $::INJ_REPO $rel]
  if {![file exists $p]} { return "MISSING:$p" }
  set fd [open $p r]; set b [read $fd]; close $fd
  return [expr {[string first $needle $b] >= 0 ? 1 : 0}]
}
check VAR0-shipped-corpus-premise \
  [expr {[inj_grep xschem_library/ngspice/autozero_comp.sch {rawfile=$netlist_dir/autozero_comp.raw}] eq 1 &&
         [inj_grep xschem_library/ngspice/solar_panel.sch  {xrawfile=$netlist_dir/solar_panel.raw}] eq 1 &&
         [inj_grep xschem_library/examples/cmos_example.sch {xrawfile=$netlist_dir/cmos_example_ngspice.raw}] eq 1}] \
  "(the three shipped schematics must still spell rawfile= with \$netlist_dir)"
foreach _n {inj_ok.raw autozero_comp.raw solar_panel.raw cmos_example_ngspice.raw} {
  file copy -force $INJ_OK [file join $tmp $_n]
}
eqcheck VAR1-netlist_dir [inj_rd {$netlist_dir/inj_ok.raw}] [list 1 [file join $tmp inj_ok.raw]]
eqcheck VAR2-shipped-autozero [inj_rd {$netlist_dir/autozero_comp.raw}] \
  [list 1 [file join $tmp autozero_comp.raw]]
eqcheck VAR3-shipped-solar [inj_rd {$netlist_dir/solar_panel.raw}] \
  [list 1 [file join $tmp solar_panel.raw]]
eqcheck VAR4-shipped-cmos [inj_rd {$netlist_dir/cmos_example_ngspice.raw}] \
  [list 1 [file join $tmp cmos_example_ngspice.raw]]

# --- KEY: ONE resolver, or the registry key drifts (invariant I1) ----------
# `raw clear <f>` must match what `raw read <f>` stored, for every spelling.
proc inj_keypair {spell} {
  xschem raw clear
  set rr [pcall xschem raw read $spell tran]
  set rc [pcall xschem raw clear $spell tran]
  return [list $rr $rc]
}
eqcheck KEY1-read-clear-agree \
  [list [inj_keypair ~/$INJ_HNAME] [inj_keypair {$netlist_dir/inj_ok.raw}] \
        [inj_keypair $INJ_SUBST]] \
  {{1 1} {1 1} {1 1}}
xschem raw clear
pcall xschem raw read $INJ_SUBST tran
check KEY2-info-literal-name [info_has $INJ_SUBST tran] \
  "(info='[string map {\n |} [pcall xschem raw info]]')"
# IDEMPOTENCE. scheduler.c's annotate_op feeds the ALREADY-RESOLVED
# xctx->raw->rawfile straight back through the clear arm, so resolving twice
# must equal resolving once or that clear misses its own entry.
xschem raw clear
set KEY3rr [pcall xschem raw read {$netlist_dir/inj_ok.raw} tran]
set KEY3abs [pcall xschem raw rawfile]
set KEY3rc [pcall xschem raw clear $KEY3abs tran]
eqcheck KEY3-resolve-twice-is-resolve-once [list $KEY3rr $KEY3rc] {1 1}

set ::netlist_dir $INJ_NDIR_SAVE
file delete -force $INJ_HRAW    ;# early drop; the exit hook above is the backstop
xschem raw clear

# ===========================================================================
# E — END TO END: the two shipped procs that generate the failing command.
#     This is the bug as the user meets it. Group D can be green while these
#     fail (they were, for `table`), because these go through the Tcl round trip
#     `xschem raw_read $rawfile [xschem raw_query sim_type]` in a NEW window.
# ===========================================================================
set fixroot [file normalize [file join [file dirname [info script]] fixtures hi_descend]]
set lib [file join $fixroot hidlib]
lappend pathlist $lib                 ;# register hidlib (lib/cell/view layout)
set top [file join $lib top schematic top.sch]

# --- E1..E10: a TABLE database carried by open_sub_schematic ----------------
xschem raw clear
xschem load $top
xschem unselect_all
eqcheck E1-table-loaded-at-top [pcall xschem raw_read $tmp/t.table table] 1
check   E2-table-waves-live [expr {[pcall xschem raw loaded] >= 0}] \
  "(loaded=[pcall xschem raw loaded])"
set win0 [xschem get current_win_path]
eqcheck E3-open_sub_schematic [pcall open_sub_schematic x1] 1
set win1 [xschem get current_win_path]
check   E4-new-window [expr {$win1 ne $win0}] "(was '$win0' now '$win1')"
check   E5-really-descended [string match "*/leaf/schematic/leaf.sch" [xschem get schname]] \
  "(schname=[xschem get schname])"
# THE ISSUE: before the fix these five found <no database at all> in the new window
eqcheck E6-table-simtype-survives [pcall xschem raw sim_type] table
eqcheck E7-table-vars-survive     [pcall xschem raw vars] 3
eqcheck E8-table-data-survives    [pcall xschem raw value b 2] 6
check   E9-table-in-new-registry  [info_has $tmp/t.table table] \
  "(info='[string map {\n |} [pcall xschem raw info]]')"
eqcheck E10-table-switchable-in-new-window [pcall xschem raw switch $tmp/t.table table] 1

# --- E11..E19: a VCD database carried by hi_descend's new-window arm --------
xschem raw clear
xschem load $top
xschem unselect_all
eqcheck E11-vcd-loaded-at-top [pcall xschem raw_read $tmp/t.vcd vcd] 1
set win0 [xschem get current_win_path]
eqcheck E12-hi_descend-newwin [pcall hi_descend inst=x1 target=new_window] 1
set win1 [xschem get current_win_path]
check   E13-new-window [expr {$win1 ne $win0}] "(was '$win0' now '$win1')"
check   E14-really-descended [string match "*/leaf/*leaf.s*" [xschem get schname]] \
  "(schname=[xschem get schname])"
eqcheck E15-vcd-simtype-survives [pcall xschem raw sim_type] vcd
eqcheck E16-vcd-vars-survive     [pcall xschem raw vars] 2
eqcheck E17-vcd-data-survives    [pcall xschem raw value m.a 3] 1
check   E18-vcd-in-new-registry  [info_has $tmp/t.vcd vcd] \
  "(info='[string map {\n |} [pcall xschem raw info]]')"
eqcheck E19-vcd-switchable-in-new-window [pcall xschem raw switch $tmp/t.vcd vcd] 1

xschem raw clear
catch {test_scratch_drop $tmp}
puts "----"
puts "test_raw_read_dispatch: $npass passed, $fail failed"
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
