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


# ===========================================================================
# SC — issue 0816: the NINE `regsub {^~/}` + tcleval() path splices that live
#      OUTSIDE the raw-file family, and
# SYMP — issue 0825: the three sym-path wrappers in src/actions.c, whose
#      trigger is STRICTLY WORSE than the graph dialog's — a plain
#      `xschem load evil.sch`, headless, no dialog, no gesture.
#
# WHY THEY ARE IN *THIS* FILE. Both are the same sink shape the INJ rows above
# already pin for the raw-file family: a string that came out of a document
# (`argv[N]` from a Tcl caller, an instance's symbol NAME out of a `.sch`)
# spliced into a `{...}` group of a script that is then evaluated. The
# raw-family half was closed by 0812; these are what 0812's scope fence left.
# Keeping them beside INJ/GUARD means one file carries the whole splice family
# and one grep (`SC0`/`SYMP`) finds every row.
#
# THE SC PAYLOAD IS NOT THE INJ PAYLOAD. `regsub {^~/} {<path>} {<home>/}`
# needs a payload that leaves the trailing `{<home>/}` a legal word, so it is
#     x} {y} {z}; set ::SC_PWNED 1; ...; list {a
# and `regsub {^~/} {x} {y} {z}` is a perfectly legal 4-argument regsub that
# writes a variable and returns 0. The `^~/` anchor is irrelevant — the splice
# happens while the SCRIPT IS BUILT, long before any pattern matches anything
# and (SC03) long before any stat().
#
# THREE OF THE NINE ARE NOT DRIVEN, and SC09 is the only thing covering them:
#   compare_schematics  — issue 0815, it SEGFAULTS under --nogui (measured
#                         again while writing these rows: the process dies
#                         mid-run, taking every later row with it)
#   preview_window      — same, measured: the payload FIRES (the host file is
#                         created) and the process then dies before the row can
#                         read the sentinel
#   new_process         — forks a real second xschem
# A source scan is a weaker instrument than a driven row and SC09 says so in
# its own failure text. It is not a substitute; it is what is left.
#
# THE SYMP PAYLOAD is the same brace-escape, delivered as an instance's SYMBOL
# NAME: `C {p\} {\} ; ...; list {a} 0 0 0 0 {name=x1}`. `\}` is the `.sch`
# format's own escape, so this is an ordinary, well-formed schematic file.
# ===========================================================================

# {sentinel host-file-created} for one command, both cleared immediately before
# the call so a 1 can only have been written by the argument.
proc sc_probe {host args} {
  set ::SC_PWNED 0
  catch {file delete -force $host}
  catch {xschem set_modify 0}
  uplevel 1 [list pcall {*}$args]
  set e [file exists $host]
  catch {file delete -force $host}
  return [list $::SC_PWNED $e]
}
# the 0816 payload, with an `exec touch` of $host wired in
proc sc_pay {host} {
  return "x\} \{y\} \{z\}; set ::SC_PWNED 1; exec touch $host; list \{a"
}
# `.sch` brace escaping: the file format escapes a literal brace with `\`
proc sch_esc {s} { return [string map [list \{ \\\{ \} \\\}] $s] }
proc sch_wr {path body} { set fp [open $path w]; puts -nonewline $fp $body; close $fp }
# a one-instance schematic whose SYMBOL NAME is $nm (unescaped; escaped here)
proc symp_sch {path nm} {
  sch_wr $path "v {xschem version=3.4.6 file_version=1.2}\nG {}\nK {}\nV {}\nS {}\nE {}\nC {[sch_esc $nm]} 0 0 0 0 {name=x1}\n"
}

set SC_CWD [pwd]
# SNAPSHOT the repo root BEFORE anything runs, so SC06b can name what THIS
# group created and cannot be reddened by a corpse an earlier session left.
set SC_ROOT_BEFORE [lsort [glob -nocomplain -directory $INJ_REPO -tails *]]
cd $tmp                      ;# every stray file a payload can make lands here

# --- the six verbs a headless run can actually drive ------------------------
set SC_H1 [file join $tmp HOST_SC01]
eqcheck SC01-load-sentinel [sc_probe $SC_H1 xschem load \
  "x\} \{y\} \{z\}; set ::SC_PWNED 1; list \{a"] {0 0}
set SC_H2 [file join $tmp HOST_SC02]
eqcheck SC02-load-hostfile [sc_probe $SC_H2 xschem load [sc_pay $SC_H2]] {0 0}
# the splice runs BEFORE any stat(), so a path that exists nowhere is not a
# defence — the leading directory below does not exist and never will
set SC_H3 [file join $tmp HOST_SC03]
eqcheck SC03-nonexistent-path [sc_probe $SC_H3 xschem load \
  "[file join $tmp no_such_dir_0816 gh]\} \{y\} \{z\}; set ::SC_PWNED 1; list \{a"] {0 0}
set SC_H4 [file join $tmp HOST_SC04]
eqcheck SC04-merge [sc_probe $SC_H4 xschem merge [sc_pay $SC_H4]] {0 0}
set SC_H5 [file join $tmp HOST_SC05]
eqcheck SC05-log [sc_probe $SC_H5 xschem log [sc_pay $SC_H5]] {0 0}
catch {xschem log}                       ;# restore stderr whatever happened
set SC_H6 [file join $tmp HOST_SC06]
eqcheck SC06-saveas [sc_probe $SC_H6 xschem saveas [sc_pay $SC_H6] schematic] {0 0}
# `saveas` is the one verb that WRITES. It must not have written into the repo
# (untracked untitled*.sch in the root reds three OTHER suites — memory note
# "untitled litter fails 3 tests"), which is why every payload above runs with
# the cwd moved into $tmp.
set SC_DROP {}
foreach _t [lsort [glob -nocomplain -directory $INJ_REPO -tails *]] {
  if {[lsearch -exact $SC_ROOT_BEFORE $_t] < 0} { lappend SC_DROP $_t }
}
check SC06b-no-repo-droppings [expr {[llength $SC_DROP] == 0}] \
  "(a payload created a file in the repo root: $SC_DROP)"
set SC_H7 [file join $tmp HOST_SC07]
eqcheck SC07-load_new_window [sc_probe $SC_H7 xschem load_new_window [sc_pay $SC_H7]] {0 0}
set SC_H8 [file join $tmp HOST_SC08]
eqcheck SC08-new_schematic [sc_probe $SC_H8 xschem new_schematic create .x0816 \
  [sc_pay $SC_H8] 0] {0 0}

# --- SC09: the source scan, and the ONLY cover for the three undriveable ----
# A live splice is `my_snprintf(f, S(f),"regsub {^~/} ...` — a line of code.
# Every OTHER mention in this file is prose inside a `/* ... */`, whose
# continuation lines all begin with `*`, so trimming and rejecting a leading
# `*` separates the two without a parser. src/xinit.c:3235 is EXCLUDED by
# 0816 itself (it splices the compile-time USER_CONF_DIR macro, which no
# document can reach) and this scan does not read that file.
set SC_HITS {}
set _fd [open [file join $INJ_REPO src scheduler.c] r]; set _b [read $_fd]; close $_fd
set _ln 0
foreach _l [split $_b "\n"] {
  incr _ln
  if {![string match {*regsub \{^~/\}*} $_l]} continue
  set _t [string trimleft $_l]
  if {[string index $_t 0] eq "*" || [string range $_t 0 1] eq "/*"} continue
  lappend SC_HITS "scheduler.c:$_ln"
}
check SC09-no-regsub-splice-in-scheduler [expr {[llength $SC_HITS] == 0}] \
  "(issue 0816: a `regsub {^~/}` path splice is still compiled in — and this row is\
 the ONLY cover for compare_schematics / preview_window / new_process, which no\
 headless row can drive (0815 segfault / fork): [join $SC_HITS { }])"

# --- SC10: ANTI-HOLLOW. Refusing an unusual path is a different bug ---------
# `~/` must still expand (that is ALL the regsub ever did), a real `~/` file
# must still load, and a path with SPACES must still load.
set SC_HLOG [file join $::env(HOME) rawdisp0816probe_[pid].log]
catch {file delete -force $SC_HLOG}
catch {xschem log ~/[file tail $SC_HLOG]}
catch {xschem log}
set SC_TILDE_OK [file exists $SC_HLOG]
catch {file delete -force $SC_HLOG}
set SC_HSCH [file join $::env(HOME) rawdisp0816probe_[pid].sch]
symp_sch $SC_HSCH sc10_no_such_symbol
catch {xschem set_modify 0}
set SC_R1 [pcall xschem load ~/[file tail $SC_HSCH]]
set SC_N1 [file tail [pcall xschem get schname]]
catch {file delete -force $SC_HSCH}
file mkdir [file join $tmp "sc space"]
set SC_SSCH [file join $tmp "sc space" "s c.sch"]
symp_sch $SC_SSCH sc10_no_such_symbol
catch {xschem set_modify 0}
set SC_R2 [pcall xschem load $SC_SSCH]
set SC_N2 [file tail [pcall xschem get schname]]
eqcheck SC10-tilde-and-spaces-still-work \
  [list $SC_TILDE_OK $SC_N1 $SC_N2] \
  [list 1 [file tail $SC_HSCH] "s c.sch"]

# --- SYMP: issue 0825, the three src/actions.c wrappers --------------------
set SYMP_H1 [file join $tmp HOST_SYMP01]
symp_sch [file join $tmp symp_rel.sch] \
  "p\} \{\} ; set ::SC_PWNED 1; exec touch $SYMP_H1; list \{a"
eqcheck SYMP01-abs_sym_path-on-load \
  [sc_probe $SYMP_H1 xschem load [file join $tmp symp_rel.sch]] {0 0}
# an ABSOLUTE symbol name goes the other way, through rel_sym_path()
set SYMP_H2 [file join $tmp HOST_SYMP02]
symp_sch [file join $tmp symp_abs.sch] \
  "/tmp/p\} \{\} ; set ::SC_PWNED 1; exec touch $SYMP_H2; list \{a"
eqcheck SYMP02-rel_sym_path-on-load \
  [sc_probe $SYMP_H2 xschem load [file join $tmp symp_abs.sch]] {0 0}
# COUNTING, not just "did it fire": load reaches the wrappers once, netlist
# three more times (sanitized_abs_sym_path in the netlisters). A row that only
# asked "was the sentinel set" cannot tell a partial fix from a whole one.
symp_sch [file join $tmp symp_cnt.sch] "p\} \{\} ; incr ::SYMP_HIT; list \{a"
set ::SYMP_HIT 0
catch {xschem set_modify 0}
pcall xschem load [file join $tmp symp_cnt.sch]
eqcheck SYMP03-count-on-load $::SYMP_HIT 0
set SYMP_NDIR [expr {[info exists ::netlist_dir] ? $::netlist_dir : {}}]
set ::netlist_dir [file join $tmp symp_nl]
file mkdir $::netlist_dir
set ::SYMP_HIT 0
pcall xschem netlist
eqcheck SYMP04-count-on-netlist $::SYMP_HIT 0
# NON-VACUITY: the payload name really REACHED the resolver and was treated as
# a filename. Captured from the engine's own error channel via `xschem log`,
# because the Tcl result of `xschem load` is the schematic name, not the
# symbol diagnostic. GREEN AT HEAD ON PURPOSE — it is the row that stops
# SYMP01-04 from passing because the name stopped arriving at all.
set SYMP_LOG [file join $tmp symp.log]
catch {file delete -force $SYMP_LOG}
catch {xschem log $SYMP_LOG}
catch {xschem set_modify 0}
pcall xschem load [file join $tmp symp_cnt.sch]
catch {xschem log}
set SYMP_LB {}
if {[file exists $SYMP_LOG]} { set _fd [open $SYMP_LOG r]; set SYMP_LB [read $_fd]; close $_fd }
check SYMP05-name-reached-the-resolver \
  [expr {[string first "Symbol not found: p\} \{\} ; incr ::SYMP_HIT; list \{a" $SYMP_LB] >= 0}] \
  "(the .sch symbol name never reached the path resolver, so SYMP01-04 are vacuous;\
 log was '[string map {\n |} [string range $SYMP_LB 0 200]]')"

# --- SYMP06: ANTI-HOLLOW, as a GOLDEN STRING -------------------------------
# A symbol whose absolute path contains a SPACE must still resolve, and the
# `** sym_path:` line the spice netlister emits comes out of
# sanitized_abs_sym_path() itself (spice_netlist.c:688, the base_name==NULL
# arm) — so this one line is a receipt for the wrapper AND for spaces.
# tests/headless/run.sh's six golden netlists are the shipped-corpus half of
# the same check.
file mkdir [file join $tmp symp_lib]
sch_wr [file join $tmp symp_lib "sy m.sym"] \
"v {xschem version=3.4.6 file_version=1.2}
G {}
K {type=subcircuit
format=\"@name @pinlist @symname\"
template=\"name=x1\"}
V {}
S {}
E {}
B 5 -10 -10 10 10 {name=A dir=in}
"
lappend ::pathlist [file join $tmp symp_lib]
symp_sch [file join $tmp symp_ok.sch] {sy m.sym}
catch {xschem set_modify 0}
pcall xschem load [file join $tmp symp_ok.sch]
set SYMP_SYMS [pcall xschem get symbols]
pcall xschem netlist
set SYMP_SP [file join $::netlist_dir symp_ok.spice]
set SYMP_PATHLINE {}
if {[file exists $SYMP_SP]} {
  set _fd [open $SYMP_SP r]; set _b [read $_fd]; close $_fd
  foreach _l [split $_b "\n"] {
    if {[string match {** sym_path:*} $_l]} { set SYMP_PATHLINE $_l ; break }
  }
}
eqcheck SYMP06-space-path-golden [list $SYMP_SYMS $SYMP_PATHLINE] \
  [list 1 "** sym_path: [file join $tmp symp_lib {sy m.sym}]"]
set ::netlist_dir $SYMP_NDIR

# --- SYMP07: the source scan -----------------------------------------------
# All three wrappers splice with a `{%s}` group; the scan names the shape
# rather than one spelling, so `sanitized_abs_sym_path`'s
# `abs_sym_path [regsub ...] {%s}` is caught by the same rule.
set SYMP_HITS {}
set _fd [open [file join $INJ_REPO src actions.c] r]; set _b [read $_fd]; close $_fd
set _ln 0
foreach _l [split $_b "\n"] {
  incr _ln
  if {![string match {*sym_path*} $_l] || ![string match "*\{%s\}*" $_l]} continue
  set _t [string trimleft $_l]
  if {[string index $_t 0] eq "*" || [string range $_t 0 1] eq "/*"} continue
  lappend SYMP_HITS "actions.c:$_ln"
}
check SYMP07-no-brace-splice-in-sym-path-wrappers [expr {[llength $SYMP_HITS] == 0}] \
  "(issue 0825: a sym-path wrapper still splices its argument into a `{%s}` group:\
 [join $SYMP_HITS { }])"

# ===========================================================================
# CVP — issue 0827: cellview_sch_path() (src/actions.c:4215) builds
#       `cellview_path {<ref>} schematic` BY CONCATENATION and tcleval()s it.
#       `<ref>` is `.sch` text: at actions.c:4291 the instance's `schematic=`
#       property value, at actions.c:4314 the symbol's own name. `\}` is the
#       `.sch` format's OWN escape for a literal brace, so the fixture below is
#       a WELL-FORMED schematic, not a corrupt one — and one `}` closes the
#       brace group so the remainder of the attribute is parsed as SCRIPT.
#
# FN  — issue 0817 §Z.2: the same defect on the `load` verb, where the string
#       is the FILENAME. `is_xschem_file` (save.c:4399), `get_directory`
#       (save.c:4414/4428/4437) and `update_recent_file` (scheduler.c:7693…)
#       are all called by concatenation.
#
# NL  — issue 0829: the five netlisters spell it
#       `get_directory [list <path>]`. `[list …]` READS as the safe form and is
#       not: the bracket is a command substitution in the OUTER script, so it
#       runs while that script's words are being parsed — before `list` is
#       reached, and the brace-escape defence is irrelevant to it.
#
# WHY THEY ARE IN *THIS* FILE. Same sink shape as SC/SYMP above — a string out
# of a document spliced into a `{...}` group of a script that is then
# evaluated — so one file carries the whole splice family and one grep
# (`SC0`/`SYMP`/`CVP`/`FN0`/`NL0`) finds every row.
#
# ⚠ THE PAYLOAD SHAPE IS SINK-SPECIFIC, AND SC02/SC07 ARE A FALSE GREEN
# BECAUSE OF IT. `sc_pay` is shaped for 0816's `regsub {^~/} {…} {…}` sink:
# spliced into a ONE-argument call it makes `is_xschem_file {x} {y} {z}` and
# Tcl throws `wrong # args` BEFORE the attacker's own commands — so SC02 and
# SC07 pass over a live sink. FN01/FN03 are the same verbs with a payload
# shaped for THIS sink, and they are the rows that go red.
#
# FN02 IS SHAPED FOR A SINK *BEYOND* save.c ON PURPOSE. Its leading fragment
# carries TWO words, which is `wrong # args` at `is_xschem_file f` and at
# `get_directory f` (both take exactly one) and legal at
# `update_recent_file {f {topwin {}}}`. So a fix that stops inside save.c
# leaves FN02 red, and FN02 is the row that says the scheduler.c sites were
# swept too.
#
# ⚠ CLAIMS (issue 0823). A `.sch` is executable BY DESIGN: a `tcleval(` in a
# text record fires on DRAW (token.c:78, tcl_hook2). No row here may be read
# as "opening a schematic no longer runs their Tcl". What these rows pin is
# narrower and is the whole point: the paths that execute WITHOUT SAYING SO.
# ===========================================================================

set CVP_EMPTY "v {xschem version=3.4.6 file_version=1.2}\nG {}\nK {}\nV {}\nS {}\nE {}\n"
sch_wr [file join $tmp cvp_plain.sch] $CVP_EMPTY
## return the context to a plain sheet at the top of the hierarchy, whether the
## descend under test succeeded, failed, or landed on a payload's own tail
proc cvp_reset {} {
  catch {xschem go_back 2} ; catch {xschem go_back 2}
  catch {xschem set_modify 0}
  pcall xschem load [file join $::tmp cvp_plain.sch]
}
## the 0827 payload in CLEAN form (what the resolver must end up seeing);
## sch_esc escapes it into the file, so a reader sees it without decoding
proc cvp_pay {host} { return "x\} schematic ; set ::SC_PWNED 1 ; exec touch $host ; list \{y" }
## the lead's own fixture: ONE mailed .sch referencing examples/rlc.sym, a
## symbol that SHIPS WITH XSCHEM, so nothing else has to be delivered
proc cvp_inst_sch {path pay} {
  sch_wr $path "v {xschem version=3.4.6 file_version=1.2}\nG {}\nK {}\nV {}\nS {}\nE {}\nC {examples/rlc.sym} 0 0 0 0 {name=x1 schematic=\"[sch_esc $pay]\"}\n"
}
## THE USER'S DOOR: load the mailed sheet, descend into the block. No dialog,
## no gesture beyond the descend. Answers {sentinel host-file-created}.
proc cvp_descend {host path} {
  set ::SC_PWNED 0
  catch {file delete -force $host}
  catch {xschem set_modify 0}
  pcall xschem load $path
  pcall xschem descend -inst x1
  set e [file exists $host]
  catch {file delete -force $host}
  cvp_reset
  return [list $::SC_PWNED $e]
}

# --- CVP01: actions.c:4291, the instance `schematic=` property -------------
set CVP_H1 [file join $tmp HOST_CVP01]
cvp_inst_sch [file join $tmp cvp1.sch] [cvp_pay $CVP_H1]
eqcheck CVP01-descend-schematic-attr [cvp_descend $CVP_H1 [file join $tmp cvp1.sch]] {0 0}

# --- CVP02: actions.c:4314, the SYMBOL NAME ------------------------------
# A disk symbol cannot reach this site: fopen fails, the instance falls back to
# systemlib/missing.sym, type becomes "missing" and descend_schematic's type
# guard (actions.c:4620) returns 0 before get_sch_from_sym is called. An
# EMBEDDED subcircuit symbol reaches it with the payload intact, so the second
# door needs its own fixture and cannot be waved through as "same wrapper".
set CVP_H2 [file join $tmp HOST_CVP02]
sch_wr [file join $tmp cvp2.sch] "v {xschem version=3.4.6 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
C {[sch_esc [cvp_pay $CVP_H2]]} 0 0 0 0 {name=x1}
\[
v {xschem version=3.4.6 file_version=1.2}
G {}
K {type=subcircuit}
V {}
S {}
E {}
L 4 0 0 20 0 {}
B 5 -5 -5 5 5 {name=A dir=inout}
T {@name} 0 0 0 0 0.2 0.2 {}
\]
"
eqcheck CVP02-descend-symbol-name [cvp_descend $CVP_H2 [file join $tmp cvp2.sch]] {0 0}

# --- CVP03/CVP04: the resolver's own ANSWER, and the non-vacuity twin ------
# 0827 acceptance row 2: `xschem get_sch_from_sym` must return a path or empty,
# never the payload's own tail. Measured at head it returns `y schematic` —
# the value of the payload's closing `list {y} schematic`, which is the receipt
# that the attribute really was parsed as script.
# CVP04 is the twin that stops CVP01-CVP03 from passing because the name
# stopped ARRIVING: the same answer must still carry the literal attribute
# bytes, i.e. the resolver was handed the whole string as ONE word.
set CVP_H3 [file join $tmp HOST_CVP03]
set CVP_PAY3 [cvp_pay $CVP_H3]
cvp_inst_sch [file join $tmp cvp3.sch] $CVP_PAY3
catch {xschem set_modify 0}
pcall xschem load [file join $tmp cvp3.sch]
set ::SC_PWNED 0
catch {file delete -force $CVP_H3}
set CVP_G3 [pcall xschem get_sch_from_sym 0]
set CVP_E3 [file exists $CVP_H3]
catch {file delete -force $CVP_H3}
eqcheck CVP03-answer-is-not-the-payload-tail \
  [list [expr {$CVP_G3 eq {y schematic}}] $::SC_PWNED $CVP_E3] {0 0 0}
check CVP04-attribute-reached-the-resolver-whole \
  [expr {[string first $CVP_PAY3 $CVP_G3] >= 0}] \
  "(the .sch schematic= value never reached the path resolver, so CVP01-CVP03 are\
 vacuous; get_sch_from_sym answered '$CVP_G3')"
cvp_reset

# --- CVP05: the sharpest discriminator — WHAT THE PROC WAS CALLED WITH -----
# A test-local recorder over `cellview_path`. This is a proc RENAME, not a
# `trace ... read`, so GUARD3 (issue 0819) is untouched and nothing is added to
# the shipped src/*.tcl this suite scans.
# At head the recorder sees ONE argument word `x` — everything after the `}`
# left the argument list and became script. Fixed, it must see the WHOLE
# attribute as argument 1 and exactly two arguments.
set ::CVREC {}
set CVP_RENAMED 0
if {[catch {
  rename ::cellview_path ::__cvp_real
  proc ::cellview_path {args} {
    lappend ::CVREC $args
    return [uplevel 1 [list ::__cvp_real {*}$args]]
  }
  set CVP_RENAMED 1
} CVP_RERR]} { set CVP_RERR "recorder could not be installed: $CVP_RERR" }
catch {xschem set_modify 0}
pcall xschem load [file join $tmp cvp3.sch]
set ::CVREC {}
pcall xschem get_sch_from_sym 0
if {$CVP_RENAMED} {
  catch {rename ::cellview_path {}}
  catch {rename ::__cvp_real ::cellview_path}
}
eqcheck CVP05-resolver-called-with-one-whole-word \
  [list [llength $::CVREC] [llength [lindex $::CVREC 0]] [lindex [lindex $::CVREC 0] 0]] \
  [list 1 2 $CVP_PAY3]
cvp_reset

# --- CVP06: ANTI-HOLLOW. Breaking a LEGITIMATE name is a different bug -----
# A real, valid schematic whose filename simply contains a `}` — legal on every
# filesystem xschem runs on — named by an absolute `schematic=` override. All
# three halves are measured, because two of them are red at head:
#   schname            the descend must land on the real file
#   current_dirname    the `get_directory {%s}` splice BLANKS it (0817 Z.2)
#   a clean log        `cellview_path {…}` must not throw on an ordinary name
file mkdir [file join $tmp cvlib]
sch_wr [file join $tmp cvlib cvsub.sym] "v {xschem version=3.4.6 file_version=1.2}
G {}
K {type=subcircuit
format=\"@name @pinlist @symname\"
template=\"name=x1\"}
V {}
S {}
E {}
L 4 0 0 20 0 {}
B 5 -5 -5 5 5 {name=A dir=inout}
"
lappend ::pathlist [file join $tmp cvlib]
set CVP_TGT [file join $tmp "w\}x.sch"]
sch_wr $CVP_TGT $CVP_EMPTY
sch_wr [file join $tmp cvp6.sch] "v {xschem version=3.4.6 file_version=1.2}\nG {}\nK {}\nV {}\nS {}\nE {}\nC {cvsub.sym} 0 0 0 0 {name=x1 schematic=\"[sch_esc $CVP_TGT]\"}\n"
set CVP_LOG [file join $tmp cvp6.log]
catch {file delete -force $CVP_LOG}
catch {xschem set_modify 0}
pcall xschem load [file join $tmp cvp6.sch]
catch {xschem log $CVP_LOG}
pcall xschem descend -inst x1
catch {xschem log}
set CVP_L6 {}
if {[file exists $CVP_LOG]} { set _fd [open $CVP_LOG r]; set CVP_L6 [read $_fd]; close $_fd }
eqcheck CVP06-legit-brace-name-still-descends \
  [list [pcall xschem get schname] [pcall xschem get current_dirname] \
        [expr {[string first "evaluation of script: cellview_path" $CVP_L6] >= 0}]] \
  [list $CVP_TGT $tmp 0]
cvp_reset

# --- CVP07: the sibling verb, scheduler.c:2699 ----------------------------
# Same Tcl proc, same brace-group concat, argv-derived words. Leaving it while
# fixing actions.c is the half-sweep 0817 §Z.4 exists to prevent.
set CVP_H7 [file join $tmp HOST_CVP07]
eqcheck CVP07-cellview_path-verb [sc_probe $CVP_H7 xschem cellview_path \
  "x\} \{y\}; set ::SC_PWNED 1; exec touch $CVP_H7; list \{a" schematic] {0 0}
cvp_reset

# --- FN01: the DRIVEN 0817 §Z.2 vector — a crafted FILENAME to `load` ------
set FN_H1 [file join $tmp HOST_FN01]
eqcheck FN01-load-is_xschem_file-sink [sc_probe $FN_H1 xschem load \
  "[file join $tmp x]\} ; set ::SC_PWNED 1; exec touch $FN_H1; is_xschem_file \{a"] {0 0}
# --- FN02: shaped for update_recent_file, which is BEYOND save.c ----------
set FN_H2 [file join $tmp HOST_FN02]
eqcheck FN02-load-update_recent_file-sink [sc_probe $FN_H2 xschem load \
  "[file join $tmp x]\} \{\} ; set ::SC_PWNED 1; exec touch $FN_H2; update_recent_file \{a"] {0 0}
# --- FN03: the same door SC07 covers, with a payload shaped for THIS sink --
set FN_H3 [file join $tmp HOST_FN03]
eqcheck FN03-load_new_window-is_xschem_file-sink [sc_probe $FN_H3 xschem load_new_window \
  "[file join $tmp x]\} ; set ::SC_PWNED 1; exec touch $FN_H3; is_xschem_file \{a"] {0 0}

# --- FN04/FN05/FN06: ANTI-HOLLOW. An ordinary filename must still work ----
# FN04 is red at head: a `}` in a real filename makes both the is_xschem_file
# and the get_directory scripts throw, and current_dirname comes back EMPTY —
# a legitimate file that opens with a broken working directory.
# FN05 and FN06 are GREEN AT HEAD ON PURPOSE. They are the rows that stop the
# fix from being paid for with a blanked or re-expanded filename: `$` and `[`
# must stay literal (no second resolver, 0812 decision D2 / 0819) and an
# ordinary load must still report its own directory.
set FN_EMPTY $CVP_EMPTY
set FN_F4 [file join $tmp "x\} y.sch"]
sch_wr $FN_F4 $FN_EMPTY
catch {xschem set_modify 0}
pcall xschem load $FN_F4
eqcheck FN04-brace-filename-loads-with-its-own-dirname \
  [list [pcall xschem get schname] [pcall xschem get current_dirname]] [list $FN_F4 $tmp]
set FN_F5 [file join $tmp "a\$b\[1\].sch"]
sch_wr $FN_F5 $FN_EMPTY
catch {xschem set_modify 0}
pcall xschem load $FN_F5
eqcheck FN05-dollar-and-bracket-filename-stay-literal \
  [list [pcall xschem get schname] [pcall xschem get current_dirname]] [list $FN_F5 $tmp]
set FN_F6 [file join $tmp fn_plain.sch]
sch_wr $FN_F6 $FN_EMPTY
catch {xschem set_modify 0}
pcall xschem load $FN_F6
eqcheck FN06-ordinary-load-reports-its-dirname \
  [list [pcall xschem get schname] [pcall xschem get current_dirname]] [list $FN_F6 $tmp]

# --- FN07: THE ANTI-HALF-SWEEP SCAN ---------------------------------------
# 0817 §Z.4 exists because a family was reported swept while siblings stayed
# live. This names the SHAPE (a Tcl proc called by string concatenation with a
# C variable spliced into a `{…}` or `[list …]` group) rather than one
# spelling, across the load / descend / netlist path.
#
# ⚠ THIS SCAN IS SPELLING-ANCHORED, not shape-anchored. Every needle begins
# with the literal `tclvareval("`, so a call routed through ANY other
# concatenating helper -- my_snprintf() into a buffer then tcleval(), or a
# private wrapper -- is invisible to it. A green here is "these NAMES are not
# spliced by tclvareval", nothing wider. Issue 0831 is what that blind spot
# cost: the list below carried nine names while seven live sinks in the
# library-manager / insert-symbol family sat one line apart from them, and this
# row stayed green through all of it.
#
# ⚠ TWO OF THE ENTRIES ARE MULTI-WORD ON PURPOSE. `scheduler.c:9707`,
# `callback.c:559` and `scheduler.c:12393` spell their splices
# `tclvareval("set INITIALINSTDIR [file dirname {` and
# `tclvareval("xschem replace_symbol {` -- words between the paren and the proc
# name. Measured against this very loop: the six single-word 0831 names find
# 6 of the 9 sites and SILENTLY MISS those three. Do not "tidy" the two
# multi-word entries into single words.
#
# ⚠ WHAT IT DOES NOT COVER, so nobody reads a green here as "the family is
# closed": the `ask_save`/`alert_` message sites (they compose program text and
# a path together, and no mechanical rule separates them), the
# `xschem load_new_window <argv>` splice, token.c's `regsub`-based sanitize(),
# hilight.c's gaw `copyvar` protocol lines and parselabel.c's modal
# tk_messageBox. And three sites that are LIVE at the time of writing and are
# filed, not fixed, so a green here can never be read as a sweep:
#   move.c:9135        `c_toolbar::add {` + abs_sym_path(sym->name)   (0833)
#   scheduler.c:7472   `join [lsort ... {` + .sch net names + argv `sep` (0833)
#   scheduler.c:8107   log_action("xschem library_manager {%s}") -- the action
#                      log is a replayable Tcl script BY DESIGN and this one
#                      line is unguarded where its four siblings are          (0832)
#   draw.c:121  psprint.c:1790  svgdraw.c:1108   `save_file_dialog {` + the
#                      SCHEMATIC'S OWN PATH via get_cell(xctx->sch[currsch],0)
#                      -- 0817 Z.2's crafted-FILENAME vector                  (0833)
#   draw.c:126  psprint.c:1795  svgdraw.c:1113   `file dirname {` +
#                      xctx->plotfile, the dialog's returned name             (0833)
#
# ⚠ TWO DIFFERENT REASONS THOSE ESCAPE, and an earlier version of this note
# got it wrong by giving only one. move.c, draw.c, psprint.c and svgdraw.c are
# NOT IN FN_FILES, so no proc-name extension reaches them at all. But
# scheduler.c IS in FN_FILES: 7472 and 8107 escape because this scan is
# anchored on `tclvareval("` + a NAME, and those lines spell `tclvareval("join`
# and `log_action(`. Fixing either class needs more than another word here --
# the first needs FN_FILES widened, the second needs a different rule. Note
# also that adding `{file dirname}` as a needle would match the CONVERTED
# tcl_call("file dirname", ...) sites too; it only works behind the
# `tclvareval("` anchor this loop already applies.
# Finally, token.c:90 `tclpropeval2` is Tcl evaluation from a `.sch` BY DESIGN
# (issue 0823) and must never appear in this list.
set FN_PROCS {is_xschem_file get_directory update_recent_file download_url
              try_download_url cellview_path launcher hi_descend_pick_done
              xschem_recover_backup
              cell_views ciform::open library_inst_lcv library_resolve
              library_cells libmgr::open
              {xschem replace_symbol} {set INITIALINSTDIR [file dirname}}
set FN_FILES {save.c actions.c scheduler.c xinit.c callback.c spice_netlist.c
              vhdl_netlist.c spectre_netlist.c verilog_netlist.c tedax_netlist.c}
set FN_HITS {}
foreach _f $FN_FILES {
  set _fd [open [file join $INJ_REPO src $_f] r]; set _b [read $_fd]; close $_fd
  set _ln 0
  foreach _l [split $_b "\n"] {
    incr _ln
    set _t [string trimleft $_l]
    if {[string index $_t 0] eq "*" || [string range $_t 0 1] eq "/*"} continue
    foreach _p $FN_PROCS {
      set _hit -1
      foreach _n [list "tclvareval(\"$_p \{" "tclvareval(\"$_p \[list " "\"$_p \{%s\}"] {
        set _i [string first $_n $_l]
        if {$_i < 0} continue
        ## program text spliced into program text is not this defect: skip a
        ## site whose next argument is a C string LITERAL -- scheduler.c's two
        ## launcher calls splice the compile-time file:// sharedir -- and keep
        ## the ones that splice a variable.
        if {[string first "\", \"" [string range $_l $_i end]] == [string length $_n]} continue
        set _hit $_i
        break
      }
      if {$_hit >= 0} { lappend FN_HITS "$_f:$_ln" ; break }
    }
  }
}
check FN07-no-concat-splice-in-the-load-path [expr {[llength $FN_HITS] == 0}] \
  "(issues 0817 Z.2 / 0827 / 0829 / 0831: a load-path proc is still called by CONCATENATION,\
 so a close-brace or a bracket in the string it splices is script:\
 [join $FN_HITS { }])"

# --- FN08: ANTI-TYPO for a mechanical multi-site sweep --------------------
# A misspelled proc name in a converted call compiles fine and degrades
# SILENTLY — the C caller ignores the eval result. A child run doing
# load + descend + go_back + netlist + saveas over a directory whose name
# merely contains a `}` must emit no Tcl diagnostics at all. Red at head: the
# same ordinary directory throws at is_xschem_file, get_directory and
# update_recent_file today.
set FN_D8 [file join $tmp "d\}8"]
file mkdir $FN_D8
sch_wr [file join $FN_D8 c8.sch] "v {xschem version=3.4.6 file_version=1.2}\nG {}\nK {}\nV {}\nS {}\nE {}\nC {examples/cmos_inv.sym} 0 0 0 0 {name=x1}\n"
set FN_DRV [file join $tmp drive8.tcl]
sch_wr $FN_DRV "set ::netlist_dir [list $FN_D8]
xschem set netlist_type spice
xschem load [list [file join $FN_D8 c8.sch]]
xschem descend -inst x1
xschem go_back 2
xschem netlist
xschem saveas [list [file join $FN_D8 out8.sch]] schematic
"
set FN_ERR {}
catch {exec [file join $INJ_REPO src xschem] --nogui --pipe -q --nolog --script $FN_DRV 2>@1} FN_ERR
set FN_BAD {}
foreach _l [split $FN_ERR "\n"] {
  if {[string match {*invalid command name*} $_l] ||
      [string match {*evaluation of script*} $_l] ||
      [string match {*error executing*} $_l]} { lappend FN_BAD $_l }
}
check FN08-no-tcl-diagnostics-on-an-ordinary-run [expr {[llength $FN_BAD] == 0}] \
  "([llength $FN_BAD] diagnostic line(s) from a plain load/descend/netlist/saveas:\
 [string map {\n |} [join [lrange $FN_BAD 0 3] { | }]])"

# --- NL01/NL02: issue 0829, the five netlisters' `get_directory [list …]` --
# `[list …]` is not a defence: the bracket is a command substitution in the
# OUTER script and runs while that script's words are parsed. Measured at head:
# a schematic whose FILENAME contains `[exec touch …]` creates the host file on
# `xschem netlist` — one verb past the `load` vector, same door.
# NL02 is the anti-hollow twin: the netlist must still be written, with the
# subcircuit body in it, and the working directory must still be right.
set NL_H [file join $tmp HOST_NL01]
set NL_F [file join $tmp "a\[exec touch HOST_NL01\]b.sch"]
sch_wr $NL_F "v {xschem version=3.4.6 file_version=1.2}\nG {}\nK {}\nV {}\nS {}\nE {}\nC {examples/cmos_inv.sym} 0 0 0 0 {name=x1}\n"
set NL_NDIR [expr {[info exists ::netlist_dir] ? $::netlist_dir : {}}]
set ::netlist_dir [file join $tmp nl]
file mkdir $::netlist_dir
xschem set netlist_type spice
set ::SC_PWNED 0
catch {file delete -force $NL_H}
catch {xschem set_modify 0}
pcall xschem load $NL_F
set NL_LOADED [file exists $NL_H]
pcall xschem netlist
set NL_AFTER [file exists $NL_H]
catch {file delete -force $NL_H}
eqcheck NL01-netlist-list-splice [list $NL_LOADED $NL_AFTER] {0 0}
set NL_SP [file join $::netlist_dir "a\[exec touch HOST_NL01\]b.spice"]
set NL_B {}
if {[file exists $NL_SP]} { set _fd [open $NL_SP r]; set NL_B [read $_fd]; close $_fd }
eqcheck NL02-netlist-still-emits-the-subcircuit \
  [list [regexp {\.subckt\s+cmos_inv\M} $NL_B] [regexp -line {^M1 } $NL_B] \
        [regexp -line {^M2 } $NL_B] [pcall xschem get current_dirname]] \
  [list 1 1 1 $tmp]
set ::netlist_dir $NL_NDIR
cvp_reset

# ===========================================================================
# LM — issue 0831: the library-manager / insert-symbol brace-concat sinks
# ===========================================================================
# THE SAME DEFECT AS CVP/FN, ONE FAMILY LATER. 0817 §Z.4 named nine procs on one
# line; the 0827+0817+0828 item converted the FIRST of them (cellview_path) and
# left the rest concatenating — and FN07 above did not list any of them, so the
# anti-half-sweep guard stayed GREEN while seven sinks were live. That is 0831.
#
# THE DRIVEN DOOR IS FILE-DERIVED. `scheduler.c:5527`:
#     tclvareval("library_inst_lcv {", xctx->inst[n].name, "}", NULL);
# `inst[].name` is the instance's SYMBOL REFERENCE read straight out of the
# `.sch`, so a mailed sheet plus the stock gesture (click an instance, ask the
# Library Manager which lib/cell/view it is) runs the sender's Tcl. `\}` is the
# `.sch` format's OWN escape for a literal brace, so the fixture below is a
# WELL-FORMED schematic, not a corrupt one. Measured at head, --nogui, no
# dialog: the host file appears and `xschem get_inst_lcv` ANSWERS `y` — the
# payload's own `list {y}` tail, which is the receipt that the reference was
# parsed as SCRIPT and not as data.
#
# THE ARGV SIBLINGS are the identical spelling with argv[] in the slot:
# cell_views (2708), ciform::open (2726), library_resolve (8068),
# library_cells (8077), libmgr::open (8097). ⚠ 0831 §3 is binding: NOT ONE of
# them is "protected because the first token errors on wrong args" — a
# wrong-args abort is an accident of PAYLOAD SHAPE, not a defence. LM04 is the
# proof: it hands the two-argument `cell_views` a two-word payload and the sink
# executes anyway. (ciform::open and libmgr::open are has_x-gated and cannot be
# driven from a --nogui run; their rows are CI16 in test_create_instance.tcl and
# LL8 in test_lib_manager_launch.tcl.)
#
# THE TWO INITIALINSTDIR DOORS (scheduler.c:9707 and callback.c:559, byte-
# identical) are file-derived AND sit inside a `[file dirname {…}]` COMMAND
# SUBSTITUTION, so they carry 0829's bracket problem on top of 0827's brace
# problem. 0831 §4 recorded them "verified present, NOT individually driven";
# LM10/LM11 drive the verb half here and CI17 (test_create_instance.tcl) drives
# the key-`I` half, so that claim is upgraded on a MEASUREMENT, not a reading.
#
# NOT CLAIMED HERE, deliberately: scheduler.c:12393 `xschem replace_symbol`.
# Both of its spliced words are PROGRAM-derived (`num` is `%d` of a loop index;
# dir_pin_sym() returns one of three compile-time literals, paste.c:56-61), so
# no attacker data reaches it. It is a hygiene conversion — covered by FN07's
# `{xschem replace_symbol}` needle and by test_pin_type_edit.tcl (5 rows go red
# when that call site is gutted, measured) — and no row below may be read as
# calling it a vector.
# ⚠ NOT by test_perform_action_replace_symbol.tcl: this comment used to name it
# and that was WRONG (issue 0835). That suite tests the `xschem replace_symbol`
# SUBCOMMAND — the CALLEE — whereas scheduler.c:12393 is a CALLER of it from
# set_pin_type, so gutting the caller cannot fail the callee's own suite. It
# stayed ALL PASS under exactly that sabotage. test_pin_type_edit is the ONLY
# cover for this site.
#
# ⚠ ANTI-HOLLOW (issue 0828). `xschem get_inst_lcv` had ZERO coverage anywhere
# in this repo before these rows — every grep hit was documentation — so the
# negatives below would ALL pass against a verb that had been gutted.
# LM03/LM07/LM08/LM09/LM12 are the positives, driven on a real nested
# lib/cell/view library, and they are what goes red if a conversion misspells a
# proc name or stops calling it at all.
#
# ⚠ THE PAYLOAD MUST LIVE IN A TCL VARIABLE and reach the verb through
# `[list …]` (sc_probe already does that). Written literally into this script's
# own `catch {…}` body it would set THIS script's sentinel and every row would
# lie — measured while writing them, and the false PWNED is indistinguishable
# from the real one by eye.
#
# ⚠ CLAIMS (issue 0823). A `.sch` is executable BY DESIGN — a `tcleval(` in a
# text record fires on DRAW (token.c:78 tcl_hook2), and scheduler.c:9708 /
# callback.c:560 call tcl_hook2() on the instance name THEMSELVES, which no
# conversion here changes. Nothing in this group may be read as "opening a
# schematic no longer runs their Tcl". What it pins is the narrower,
# load-bearing thing: the paths that execute WITHOUT SAYING SO.
# ===========================================================================

## the 0831 payload, arity 1 (a symbol reference, a library name, a cell name)
proc lm_pay {host} { return "x\} ; set ::SC_PWNED 1; exec touch $host; list \{y" }
## the SINK-SHAPED arity-2 payload, for `cell_views <lib> <cell>` (0831 §3)
proc lm_pay2 {host} { return "x\} \{y\} ; set ::SC_PWNED 1; exec touch $host; list \{z" }

# --- the fixture: ONE real Cadence-layout library, plus the mailed sheet ----
set LM_DEFS_HAD [info exists ::XSCHEM_LIBRARY_DEFS]
set LM_DEFS_OLD [expr {$LM_DEFS_HAD ? $::XSCHEM_LIBRARY_DEFS : {}}]
set LM_IID_HAD  [info exists ::INITIALINSTDIR]
set LM_IID_OLD  [expr {$LM_IID_HAD ? $::INITIALINSTDIR : {}}]
file mkdir [file join $tmp plib cellA symbol]
sch_wr [file join $tmp plib cellA symbol cellA.sym] \
  "v {xschem version=3.4.6 file_version=1.2}\nG {}\nK {}\nV {}\nS {}\nE {}\nL 4 0 0 20 0 {}\n"
sch_wr [file join $tmp lm_library.defs] "DEFINE plib [file join $tmp plib]\n"
set ::XSCHEM_LIBRARY_DEFS [file join $tmp lm_library.defs]
symp_sch [file join $tmp lm_ok.sch] plib/cellA

## THE USER'S DOOR: load the mailed sheet, select the instance, ask the Library
## Manager's reverse-map verb what it is. Answers {sentinel host-after-LOAD
## host-after-VERB} and leaves the verb's own answer in ::LM_ANS. The load is
## sampled separately because at head it does NOT fire (measured) — the row must
## be red for the VERB, which is the gesture the user makes.
proc lm_lcv_probe {host path} {
  set ::SC_PWNED 0
  catch {file delete -force $host}
  catch {xschem set_modify 0}
  pcall xschem load $path
  set l [file exists $host]
  pcall xschem select_all
  set ::LM_ANS [pcall xschem get_inst_lcv]
  set e [file exists $host]
  catch {file delete -force $host}
  return [list $::SC_PWNED $l $e]
}

# --- LM01/LM02: scheduler.c:5527, THE DRIVEN SITE --------------------------
set LM_H1 [file join $tmp HOST_LM01]
symp_sch [file join $tmp lm_evil.sch] [lm_pay $LM_H1]
eqcheck LM01-get_inst_lcv-sch-symbol-reference \
  [lm_lcv_probe $LM_H1 [file join $tmp lm_evil.sch]] {0 0 0}
check LM02-get_inst_lcv-answer-is-not-the-payload-tail [expr {$::LM_ANS ne {y}}] \
  "(the verb answered '$::LM_ANS' — the value of the payload's own `list \{y\}`\
 tail, which is the receipt that the .sch symbol reference was parsed as SCRIPT)"
cvp_reset

# --- LM03: ANTI-HOLLOW. The reverse map must still ANSWER -------------------
catch {xschem set_modify 0}
pcall xschem load [file join $tmp lm_ok.sch]
pcall xschem select_all
eqcheck LM03-get_inst_lcv-still-answers-lib-cell-view \
  [pcall xschem get_inst_lcv] {plib cellA symbol}
cvp_reset

# --- LM04/LM05/LM06: the argv-derived siblings a headless run can drive -----
set LM_H4 [file join $tmp HOST_LM04]
eqcheck LM04-cell_views-sink-shaped-two-word-payload \
  [sc_probe $LM_H4 xschem cell_views [lm_pay2 $LM_H4] zz] {0 0}
set LM_H5 [file join $tmp HOST_LM05]
eqcheck LM05-library-resolve-sink \
  [sc_probe $LM_H5 xschem library [lm_pay $LM_H5]] {0 0}
set LM_H6 [file join $tmp HOST_LM06]
eqcheck LM06-lib_cells-sink \
  [sc_probe $LM_H6 xschem lib_cells [lm_pay $LM_H6]] {0 0}

# --- LM07/LM08/LM09: ANTI-HOLLOW twins for the three above -----------------
eqcheck LM07-library-still-resolves [pcall xschem library plib] [file join $tmp plib]
eqcheck LM08-lib_cells-still-lists-the-cell [pcall xschem lib_cells plib] cellA
eqcheck LM09-cell_views-still-lists-the-view [pcall xschem cell_views plib cellA] symbol

# --- LM10/LM11: scheduler.c:9707, the INITIALINSTDIR command substitution ---
## `xschem place_symbol` reads the SELECTED instance's name and splices it into
## `set INITIALINSTDIR [file dirname {…}]`. Answers {sentinel host} and leaves
## the variable's value in ::LM_IID. The trailing abort_operation matters: the
## verb ARMS a placement, and an armed preview leaking into the next row is a
## different failure wearing this one's name.
proc lm_place_probe {host path} {
  set ::SC_PWNED 0
  catch {file delete -force $host}
  catch {xschem set_modify 0}
  pcall xschem load $path
  pcall xschem select_all
  set ::INITIALINSTDIR NOTSET
  pcall xschem place_symbol devices/lab_pin.sym {}
  set ::LM_IID $::INITIALINSTDIR
  set e [file exists $host]
  catch {file delete -force $host}
  catch {xschem abort_operation}
  catch {xschem set_modify 0}
  return [list $::SC_PWNED $e]
}
## its OWN fixture: the payload has to name THIS row's host file, or the
## host-file leg is vacuous and only the sentinel is doing any work
set LM_H10 [file join $tmp HOST_LM10]
symp_sch [file join $tmp lm_evil10.sch] [lm_pay $LM_H10]
eqcheck LM10-place_symbol-INITIALINSTDIR-sink \
  [lm_place_probe $LM_H10 [file join $tmp lm_evil10.sch]] {0 0}
check LM11-INITIALINSTDIR-is-not-the-payload-tail [expr {$::LM_IID ne {y}}] \
  "(INITIALINSTDIR is '$::LM_IID' — the value of the payload's own `list \{y\}`,\
 returned THROUGH the `\[file dirname \{…\}\]` command substitution: 0829's\
 bracket problem riding on top of 0827's brace problem)"
cvp_reset

# --- LM12: ANTI-HOLLOW twin. The Insert-symbol initial dir must still be set -
# ::INITIALINSTDIR is pre-set to NOTSET inside the probe, so this row also
# detects a conversion that stops setting the variable at ALL — which the
# negatives above would happily call a pass.
lm_place_probe [file join $tmp HOST_LM12] [file join $tmp lm_ok.sch]
eqcheck LM12-INITIALINSTDIR-still-points-at-the-symbol-directory \
  [list $::LM_IID [file isdirectory $::LM_IID]] \
  [list [file join $tmp plib cellA symbol] 1]
cvp_reset

# --- LM13: hygiene. No payload may have written into the repo root ---------
set LM_DROP {}
foreach _t [lsort [glob -nocomplain -directory $INJ_REPO -tails *]] {
  if {[lsearch -exact $SC_ROOT_BEFORE $_t] < 0} { lappend LM_DROP $_t }
}
check LM13-no-repo-droppings-from-the-0831-payloads [expr {[llength $LM_DROP] == 0}] \
  "(an 0831 payload created a file in the repo root — memory note\
 'untitled litter fails 3 tests': $LM_DROP)"
if {$LM_DEFS_HAD} { set ::XSCHEM_LIBRARY_DEFS $LM_DEFS_OLD } else { catch {unset ::XSCHEM_LIBRARY_DEFS} }
if {$LM_IID_HAD}  { set ::INITIALINSTDIR $LM_IID_OLD }       else { catch {unset ::INITIALINSTDIR} }

cd $SC_CWD
catch {xschem set_modify 0}

xschem raw clear
catch {test_scratch_drop $tmp}
puts "----"
puts "test_raw_read_dispatch: $npass passed, $fail failed"
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
