# test_undo_link_symbols.tcl
#
# Regression for issue 0072 (doc/claude/issues/0072-setprop-instance-hangs-on-churned-buffer.md).
#
# Root cause fixed: disk pop_undo() serialized the autosave "~" backup (via
# set_modify(1) -> write_backup()) BEFORE link_symbols_to_instances() had resolved
# the freshly read-back instances, so every restored instance was written with
# .ptr = -1 (unresolved symbol) -- emitting save_inst() ".ptr = -1" warnings and,
# for embedded symbols, failing to clear the EMBEDDED flag on the backup. The fix
# moves set_modify(1) to AFTER link_symbols_to_instances()/synth_pin_views().
#
# This test spawns a CHILD xschem that drives a disk-undo restore of a populated
# schematic and asserts:
#   1. no "save_inst(): WARNING: inst N .ptr = -1" appears (symbols linked first);
#   2. undo/redo preserve the instance population (data integrity);
#   3. `xschem setprop instance <n> ...` on the churned buffer RETURNS in bounded
#      time (acceptance criterion 1: no infinite loop / hang), whether it succeeds
#      or reports "instance not found".
#
# Run under X with --pipe and --logdir, from the repo root:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#       --script tests/headless/test_undo_link_symbols.tcl

set ::fail 0
proc check {name ok} {
  if {$ok} { puts "ok   - $name" } else { puts "FAIL - $name" ; set ::fail 1 }
}

# --- locate the running binary + a scratch area -----------------------------
set xschem [info nameofexecutable]
check "found xschem binary" [expr {[file executable $xschem]}]

# Resolve nand2.sch to an ABSOLUTE path so the child works regardless of cwd
# (full_audit.sh runs from tests/headless, not the repo root). Dev tree puts the
# examples under <repo>/xschem_library/...; an installed tree under $XSCHEM_SHAREDIR.
set nand2 ""
set cand {}
catch { lappend cand [file join [file dirname $::XSCHEM_SHAREDIR] xschem_library examples nand2.sch] }
catch { lappend cand [file join $::XSCHEM_SHAREDIR xschem_library examples nand2.sch] }
lappend cand [file normalize [file join [file dirname [info script]] .. .. xschem_library examples nand2.sch]]
lappend cand xschem_library/examples/nand2.sch
foreach c $cand { if {[file exists $c]} { set nand2 [file normalize $c] ; break } }
check "resolved nand2.sch path" [expr {$nand2 ne "" && [file exists $nand2]}]

# Without --logdir, `xschem get actionlog_filename` is EMPTY, so this used to
# resolve to "./undo_link_child" -- i.e. it created a scratch tree in whatever
# directory the suite was launched from, which for a hand-run is the REPO ROOT.
# (Measured X0498: a --nolog run of this suite left an untracked undo_link_child/
# behind at the repo root; same litter class as the untitled*.sch that reds
# save_as_cellview / untitled_reuse / descend_untitled_preserve.) Fall back to a
# system temp dir when there is no action log. With --logdir -- which is how
# full_audit.sh's logdir_tests list always runs this file -- nothing changes.
set tmpbase [file dirname [xschem get actionlog_filename]]
if {[file pathtype $tmpbase] ne "absolute"} {
  set sys /tmp
  if {[info exists ::env(TMPDIR)] && $::env(TMPDIR) ne ""} { set sys $::env(TMPDIR) }
  set tmpbase [file join $sys xschem_undo_link_[pid]]
}
set tmp [file join $tmpbase undo_link_child]
file mkdir $tmp
set child [file join $tmp drive.tcl]
set out   [file join $tmp out.txt]

# --- child driver -----------------------------------------------------------
# Disk undo is the default; force it explicitly so the test pins the fixed path
# regardless of any rc override. The churn (delete -> undo) restores instances
# through read_xschem_file(), the code path that used to autosave while unlinked.
set fd [open $child w]
puts $fd "set NAND2 [list $nand2]"
puts $fd {
  xschem undo_type disk
  xschem load $NAND2
  set n0 [xschem get instances]
  xschem select_all ; xschem delete
  set n1 [xschem get instances]
  xschem undo            ;# disk pop_undo(): read-back + link + autosave
  set n2 [xschem get instances]
  xschem redo
  set n3 [xschem get instances]
  xschem undo
  set n4 [xschem get instances]
  puts "COUNTS $n0 $n1 $n2 $n3 $n4"
  # setprop on the restored buffer must RETURN (bounded), success or error:
  set rc [catch {xschem setprop instance 0 selflogtok selflogval} res]
  puts "SETPROP rc=$rc res=$res"
  puts "CHILD_DONE"
  flush stdout
  exit 0
}
close $fd

# --- run the child, capturing stdout+stderr; `timeout` bounds a hang --------
# A regression to the infinite-loop hang trips the timeout -> non-empty errmsg
# and the CHILD_DONE / COUNTS / SETPROP assertions below fail loudly.
set logdir [file join $tmp clog] ; file mkdir $logdir
set errmsg ""
if {[catch {
  exec timeout 45 $xschem --pipe -q --logdir $logdir --script $child >& $out
} e]} { set errmsg $e }

set body ""
if {[file exists $out]} { set fd [open $out r] ; set body [read $fd] ; close $fd }

check "child completed (no hang)"        [expr {[string first CHILD_DONE $body] >= 0}]
check "undo does not warn .ptr = -1"     [expr {[string first {WARNING: inst} $body] < 0}]

# instance population round-trips through undo/redo (COUNTS n0 n1 n2 n3 n4)
set counts_ok 0
if {[regexp {COUNTS (\d+) (\d+) (\d+) (\d+) (\d+)} $body -> n0 n1 n2 n3 n4]} {
  set counts_ok [expr {$n0 > 0 && $n1 == 0 && $n2 == $n0 && $n3 == 0 && $n4 == $n0}]
}
check "undo/redo preserve instance count" $counts_ok
check "setprop on churned buffer returns" [expr {[string first {SETPROP rc=} $body] >= 0}]


# ===========================================================================
# Issue 0498 -- a leaked keep_symbols=1 PLUS no_undo=1 across `xschem netlist`
# SEGFAULTS the C core, and where it does not segfault it SILENTLY REPLACES the
# user's document with a sub-sheet.
#
# These rows live here (and not in test_op_annot.tcl) because this suite is
# literally the ".ptr = -1 / unresolved symbol" suite: same subject, same
# exec-a-child-with-timeout idiom, already on full_audit.sh's logdir_tests list.
#
# MEASURED on the unfixed binary (X0498 Measure + Red agents, HEAD 7ad53557):
#   keep_symbols=0 no_undo=0 -> SURVIVED  insts unchanged
#   keep_symbols=0 no_undo=1 -> SURVIVED  symbol table emptied (silent)
#   keep_symbols=1 no_undo=0 -> SURVIVED  insts unchanged
#   keep_symbols=1 no_undo=1 -> FATAL: signal 11   <-- both flags jointly needed
# gdb, both entry points:  #0 draw_hilight_net  (src/hilight.c:4187 as measured;
#   the INST_UNBOUND guard that fixed it now sits at :4169 and the deref at :4195,
#   `symptr = (xctx->inst[i].ptr+ xctx->sym);` with no `.ptr < 0` guard)
#   #1 global_spice_netlist   ... and independently  #1 draw  (a plain redraw).
#
# The CARRIER IS `xschem netlist`, NOT `xschem load` -- issue 0498's own title
# and the step brief are both wrong about that, and it was re-measured here:
# three consecutive `xschem load` calls with both flags leaked survive cleanly
# (scheduler.c:7611's `keep_symbols` is the LOCAL `-keep_symbols` argument of the
# load branch, not the Tcl global). Do not build a load-path row.
#
# The fixture is deliberately PDK-FREE: two hand-written symbols, no sky130 /
# gf180 / ihp tree, so these rows import no library dependency.
#
# Row map:
#   X0   fixture built, and the children littered no untitled*.sch in the repo root
#   X1   the leaked-flag netlist does not take the process down
#   X2   ... and leaves the document it started with (crash fixture)
#   X2b  ... and leaves the document it started with (NON-crashing fixture:
#          this is the row that stops a guard-only fix from converting the
#          SIGSEGV into a silent sub-sheet swap -- save.c RULING D5-1)
#   X3   the deck emitted with the flags leaked is byte-identical to the clean one
#   X3b  ... same, on the non-crashing fixture
#   X4   no_undo is still in force after the netlist (probe by EFFECT: there is
#        no `xschem get no_undo`, only a setter at scheduler.c:12030)
#   X4b  keep_symbols is NOT clobbered -- it is a user preference
#   X5   the clean path's undo behaviour is unchanged
#   X6   a NON-global netlist still pushes no undo slot under no_undo=1
#   X7   all five netlist back ends survive and keep the document (5 children)
#   X8   a plain REDRAW over unbound instances survives (needs a DISPLAY)
#   S1a-d / S2 / S3   source-text guardians (see their own comments)
# ===========================================================================

# The rows below write a fixture tree. On a --nolog run the suite's $tmp resolves
# to "./undo_link_child", i.e. the REPO ROOT -- the exact litter class that reds
# save_as_cellview / untitled_reuse / descend_untitled_preserve. Fall back to a
# system temp dir in that case.
set tmp0498 $tmp
if {[file pathtype $tmp0498] ne "absolute"} {
  set tmpbase "/tmp"
  if {[info exists ::env(TMPDIR)] && $::env(TMPDIR) ne ""} { set tmpbase $::env(TMPDIR) }
  set tmp0498 [file join $tmpbase xschem_0498_[pid]]
}
set tmp0498 [file join $tmp0498 x0498]
file delete -force $tmp0498
file mkdir $tmp0498

set repo0498 [file normalize [file join [file dirname [info script]] .. ..]]
set srcdir0498 [file join $repo0498 src]

proc x0498_write {path text} {
  set fd [open $path w] ; puts -nonewline $fd $text ; close $fd
}

proc x0498_read {path} {
  if {![file exists $path]} { return "" }
  set fd [open $path r] ; set d [read $fd] ; close $fd ; return $d
}

# PDK-free fixture:
#   wp.sym     a leaf device (type=nmos)
#   wstop.sym  a subcircuit that STOPS the descent in all five back ends -- the
#              stop arm calls load_schematic(0,...) i.e. load_symbols=0, which is
#              what leaves the child sheet's instances with .ptr unresolved
#   wstop.sch  100 leaf instances   -> child sheet BIGGER than the top  (crash)
#   wbare.sch  1 instance of wstop  -> the crash fixture
#   wsmall.sch 3 leaf instances     -> child sheet SMALLER than the top (no OOB)
#   wtop.sch   1 wsmall + 19 leaves -> the silent-corruption fixture
proc x0498_fixture {dir} {
  file mkdir $dir
  x0498_write [file join $dir wp.sym] \
"v {xschem version=3.4.4 file_version=1.2}
G {type=nmos
format=\"@name @pinlist @model\"
template=\"name=M1 model=nch\"}
V {}
S {}
E {}
B 5 -22.5 -2.5 -17.5 2.5 {name=D dir=inout}
"
  set stop \
"v {xschem version=3.4.4 file_version=1.2}
G {type=subcircuit
spice_stop=true
vhdl_stop=true
verilog_stop=true
spectre_stop=true
tedax_stop=true
format=\"@name @pinlist @symname\"
template=\"name=x1\"}
V {}
S {}
E {}
B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout}
"
  x0498_write [file join $dir wstop.sym]  $stop
  x0498_write [file join $dir wsmall.sym] $stop
  set hdr "v {xschem version=3.4.4 file_version=1.2}\nG {}\nV {}\nS {}\nE {}\n"
  set s $hdr
  for {set i 1} {$i <= 100} {incr i} { append s "C {wp.sym} [expr {$i*100}] 0 0 0 {name=MP$i model=nch}\n" }
  x0498_write [file join $dir wstop.sch] $s
  x0498_write [file join $dir wbare.sch] "${hdr}C {wstop.sym} 120 0 0 0 {name=xstop}\n"
  set s $hdr
  for {set i 1} {$i <= 3} {incr i} { append s "C {wp.sym} [expr {$i*100}] 0 0 0 {name=MS$i model=nch}\n" }
  x0498_write [file join $dir wsmall.sch] $s
  set s "${hdr}C {wsmall.sym} 0 0 0 0 {name=xsm}\n"
  for {set i 1} {$i <= 19} {incr i} { append s "C {wp.sym} [expr {$i*100}] 200 0 0 {name=MT$i model=nch}\n" }
  x0498_write [file join $dir wtop.sch] $s
}

# Run one child xschem on a generated script; returns {rc body}. rc != 0 means the
# child died (a SIGSEGV shows up here AND as "FATAL: signal" in the body).
# gui=1 keeps the window (X8 needs a real draw); everything else runs --nogui.
proc x0498_child {xschem dir name body {gui 0}} {
  set child [file join $dir $name.tcl]
  set out   [file join $dir $name.out]
  set ldir  [file join $dir ${name}_log] ; file mkdir $ldir
  x0498_write $child $body
  set flags [list --pipe -q --logdir $ldir]
  if {!$gui} { set flags [linsert $flags 0 --nogui] }
  set rc 0
  if {[catch { exec timeout 45 $xschem {*}$flags --script $child >& $out } e]} { set rc 1 }
  return [list $rc [x0498_read $out]]
}

set lib0498 [file join $tmp0498 lib]
x0498_fixture $lib0498
check "X0 fixture built (PDK-free, 7 files)" [expr {
  [file exists [file join $lib0498 wp.sym]] && [file exists [file join $lib0498 wstop.sym]] &&
  [file exists [file join $lib0498 wstop.sch]] && [file exists [file join $lib0498 wbare.sch]] &&
  [file exists [file join $lib0498 wsmall.sym]] && [file exists [file join $lib0498 wsmall.sch]] &&
  [file exists [file join $lib0498 wtop.sch]]}]

# snapshot repo-root untitled litter BEFORE the children, so a pre-existing stray
# from another suite cannot red this row -- only a file THESE children create can
set untitled_before [lsort [glob -nocomplain -directory $repo0498 untitled*.sch]]

set devs0498 [file join $repo0498 xschem_library devices]
set pre0498 "set LIB [list $lib0498]\nset DEV [list $devs0498]\n"

# --- child A: the crash fixture, both flags leaked --------------------------
lassign [x0498_child $xschem $tmp0498 a_bare_leak "$pre0498
  set XSCHEM_LIBRARY_PATH \":\$LIB:\$DEV\"
  set ::netlist_dir \[file join \$LIB .. nl_a\]
  file mkdir \$::netlist_dir
  xschem undo_type disk
  xschem load \[file join \$LIB wbare.sch\]
  set i0 {} ; catch {set i0 \[xschem getprop instance 0 name\]}
  puts \"A_BEFORE insts=\[xschem get instances\] syms=\[xschem get symbols\] i0=\$i0\"
  set ::keep_symbols 1
  xschem set no_undo 1
  xschem netlist
  set i1 {} ; catch {set i1 \[xschem getprop instance 0 name\]}
  puts \"A_AFTER insts=\[xschem get instances\] syms=\[xschem get symbols\] i0=\$i1\"
  puts \"A_KS \$::keep_symbols\"
  xschem select_all ; xschem delete
  set d \[xschem get instances\]
  xschem undo
  puts \"A_UNDO del=\$d after=\[xschem get instances\]\"
  puts SURVIVED
  puts CHILD_DONE
  flush stdout
  exit 0
"] rcA bodyA

check "X1 leaked-flag netlist does not crash the process" [expr {
  [string first SURVIVED $bodyA] >= 0 &&
  [string first {FATAL: signal} $bodyA] < 0 &&
  [string first {EMERGENCY SAVE} $bodyA] < 0 && $rcA == 0}]

set a_ok 0
if {[regexp {A_BEFORE insts=(\d+) syms=(\d+) i0=(\S*)} $bodyA -> ab as ai] &&
    [regexp {A_AFTER insts=(\d+) syms=(\d+) i0=(\S*)} $bodyA -> nb ns ni]} {
  set a_ok [expr {$ab == 1 && $ai eq "xstop" && $nb == $ab && $ni eq $ai}]
}
check "X2 document survives the netlist (1 inst, i0=xstop)" $a_ok

check "X4 no_undo still in force after the netlist (undo is a no-op)" \
  [expr {[string first {A_UNDO del=0 after=0} $bodyA] >= 0}]
check "X4b keep_symbols not clobbered by the core" \
  [expr {[string first {A_KS 1} $bodyA] >= 0}]

# --- child B: same fixture, clean flags -> the reference deck ---------------
lassign [x0498_child $xschem $tmp0498 b_bare_clean "$pre0498
  set XSCHEM_LIBRARY_PATH \":\$LIB:\$DEV\"
  set ::netlist_dir \[file join \$LIB .. nl_b\]
  file mkdir \$::netlist_dir
  xschem load \[file join \$LIB wbare.sch\]
  xschem netlist
  puts \"B_AFTER insts=\[xschem get instances\]\"
  puts CHILD_DONE
  flush stdout
  exit 0
"] rcB bodyB
check "X3 pre: clean run emitted the reference deck" \
  [expr {$rcB == 0 && [file exists [file join $tmp0498 nl_b wbare.spice]]}]

set deck_a [x0498_read [file join $tmp0498 nl_a wbare.spice]]
set deck_b [x0498_read [file join $tmp0498 nl_b wbare.spice]]
check "X3 leaked-flag deck is byte-identical to the clean deck" \
  [expr {$deck_b ne "" && $deck_a eq $deck_b}]

# --- child C: the NON-crashing fixture, both flags leaked -------------------
# child sheet (3 insts) is SMALLER than the top (20), so the stored_flags read
# stays in bounds and nothing faults -- what is left behind is a DIFFERENT
# DOCUMENT under the original cell's name, with rc=0 and no warning.
lassign [x0498_child $xschem $tmp0498 c_top_leak "$pre0498
  set XSCHEM_LIBRARY_PATH \":\$LIB:\$DEV\"
  set ::netlist_dir \[file join \$LIB .. nl_c\]
  file mkdir \$::netlist_dir
  xschem load \[file join \$LIB wtop.sch\]
  set i0 {} ; catch {set i0 \[xschem getprop instance 0 name\]}
  puts \"C_BEFORE insts=\[xschem get instances\] i0=\$i0\"
  set ::keep_symbols 1
  xschem set no_undo 1
  xschem netlist
  set i1 {} ; catch {set i1 \[xschem getprop instance 0 name\]}
  puts \"C_AFTER insts=\[xschem get instances\] i0=\$i1\"
  puts CHILD_DONE
  flush stdout
  exit 0
"] rcC bodyC

set c_ok 0
if {[regexp {C_BEFORE insts=(\d+) i0=(\S*)} $bodyC -> cb ci] &&
    [regexp {C_AFTER insts=(\d+) i0=(\S*)} $bodyC -> ca cai]} {
  set c_ok [expr {$cb == 20 && $ci eq "xsm" && $ca == $cb && $cai eq $ci}]
}
check "X2b document not silently swapped for a sub-sheet (20 insts, i0=xsm)" $c_ok

# --- child D: the same fixture, clean flags -> reference deck ---------------
lassign [x0498_child $xschem $tmp0498 d_top_clean "$pre0498
  set XSCHEM_LIBRARY_PATH \":\$LIB:\$DEV\"
  set ::netlist_dir \[file join \$LIB .. nl_d\]
  file mkdir \$::netlist_dir
  xschem load \[file join \$LIB wtop.sch\]
  xschem netlist
  puts CHILD_DONE
  flush stdout
  exit 0
"] rcD bodyD
set deck_c [x0498_read [file join $tmp0498 nl_c wtop.spice]]
set deck_d [x0498_read [file join $tmp0498 nl_d wtop.spice]]
check "X3b non-crashing leaked deck byte-identical to the clean deck" \
  [expr {$deck_d ne "" && $deck_c eq $deck_d}]

# --- children E1..E5: all five back ends, both flags leaked ----------------
# ONE CHILD PER FORMAT on purpose: a single looping child dies at the first
# segfaulting back end and takes the other four legs' evidence with it.
foreach fmt {spice vhdl verilog spectre tedax} {
  lassign [x0498_child $xschem $tmp0498 e_$fmt "$pre0498
    set XSCHEM_LIBRARY_PATH \":\$LIB:\$DEV\"
    set ::netlist_dir \[file join \$LIB .. nl_e_$fmt\]
    file mkdir \$::netlist_dir
    xschem set netlist_type $fmt
    xschem load \[file join \$LIB wbare.sch\]
    set ::keep_symbols 1
    xschem set no_undo 1
    xschem netlist
    set i1 {} ; catch {set i1 \[xschem getprop instance 0 name\]}
    puts \"FMT $fmt insts=\[xschem get instances\] i0=\$i1\"
    puts CHILD_DONE
    flush stdout
    exit 0
  "] rcE bodyE
  set e_ok 0
  if {[regexp "FMT $fmt insts=(\\d+) i0=(\\S*)" $bodyE -> en ei]} {
    set e_ok [expr {$en == 1 && $ei eq "xstop"}]
  }
  check "X7 $fmt back end survives and keeps the document" \
    [expr {$e_ok && $rcE == 0 && [string first {FATAL: signal} $bodyE] < 0}]
}

# --- child F: the CLEAN paths must be unchanged by the fix ------------------
# X5 and X6 are REGRESSION GUARDS: both are GREEN on the unfixed binary
# (measured 20 0 0 20 / 20 0 0 20). They exist so the corrective half cannot buy
# crash-safety by changing what undo does on a normal run, and to pin the
# `global` narrowing (sabotage SV7 widens the shield -> X6 reds).
lassign [x0498_child $xschem $tmp0498 f_clean_undo "$pre0498
  set XSCHEM_LIBRARY_PATH \":\$LIB:\$DEV\"
  set ::netlist_dir \[file join \$LIB .. nl_f\]
  file mkdir \$::netlist_dir
  xschem undo_type disk
  xschem load \[file join \$LIB wtop.sch\]
  set n0 \[xschem get instances\]
  xschem select_all ; xschem delete
  set n1 \[xschem get instances\]
  xschem netlist
  set n2 \[xschem get instances\]
  xschem undo
  puts \"F_X5 \$n0 \$n1 \$n2 \[xschem get instances\]\"
  xschem load \[file join \$LIB wtop.sch\]
  set m0 \[xschem get instances\]
  xschem select_all ; xschem delete
  set m1 \[xschem get instances\]
  set ::keep_symbols 1
  xschem set no_undo 1
  xschem netlist -nohier
  set m2 \[xschem get instances\]
  xschem set no_undo 0
  xschem undo
  puts \"F_X6 \$m0 \$m1 \$m2 \[xschem get instances\]\"
  puts CHILD_DONE
  flush stdout
  exit 0
"] rcF bodyF
check "X5 clean-path global netlist leaves undo intact (20 0 0 20)" \
  [expr {[string first {F_X5 20 0 0 20} $bodyF] >= 0}]
check "X6 non-global netlist under no_undo pushes no undo slot (20 0 0 20)" \
  [expr {[string first {F_X6 20 0 0 20} $bodyF] >= 0}]

# --- child G (X8): a plain REDRAW over unbound instances -------------------
# The netlister is not the only door to that deref (hilight.c:4195 post-fix). Highlight, then drop the
# symbol table (`xschem remove_symbols`, scheduler.c:10864, sets every
# inst[].ptr = -1), then redraw: measured #0 draw_hilight_net #1 draw. This is
# the ONE behavioural oracle for the defensive guard that involves no netlister,
# so sabotage SV2 (unguard hilight.c) must red it. It needs a real DISPLAY.
if {[info exists ::env(DISPLAY)] && $::env(DISPLAY) ne ""} {
  lassign [x0498_child $xschem $tmp0498 g_redraw "$pre0498
    set XSCHEM_LIBRARY_PATH \":\$LIB:\$DEV\"
    xschem load \[file join \$LIB wtop.sch\]
    xschem select_all
    xschem hilight
    puts \"G_HILIGHT insts=\[xschem get instances\]\"
    xschem remove_symbols
    puts \"G_REMOVED syms=\[xschem get symbols\]\"
    xschem redraw
    puts SURVIVED
    puts CHILD_DONE
    flush stdout
    exit 0
  " 1] rcG bodyG
  check "X8 redraw over unbound instances survives" [expr {
    [string first {G_REMOVED syms=0} $bodyG] >= 0 &&
    [string first SURVIVED $bodyG] >= 0 &&
    [string first {FATAL: signal} $bodyG] < 0 && $rcG == 0}]
} else {
  puts "SKIP - X8 redraw-over-unbound-instances needs a DISPLAY (run under xvfb)"
}

# --- X0 (second half): the children littered nothing in the repo root -------
set untitled_after [lsort [glob -nocomplain -directory $repo0498 untitled*.sch]]
check "X0 children created no untitled*.sch in the repo root" \
  [expr {$untitled_after eq $untitled_before}]

# ===========================================================================
# SOURCE-TEXT GUARDIANS.
# Stated plainly, per the 0499 lesson: S1b, S1c, S2 and S3 are NOT behavioural.
# Measured here on the unfixed binary, an SVG export and a PS export over a
# document whose every inst[].ptr == -1 both SURVIVE (exit 0), so psprint.c and
# svgdraw.c have no reachable behavioural oracle in this suite, and once the
# shield holds the stored_flags clamp is unreachable by construction. These rows
# can fail on a revert; they cannot prove a behaviour. Their real oracle is the
# valgrind before/after recorded in doc/claude/issues/0498-*.md.
# ===========================================================================

proc x0498_lines {path} { return [split [x0498_read $path] "\n"] }

# 1-based index of the first line in [from,to] matching $re, or -1
proc x0498_findln {lines re from to} {
  set n [llength $lines]
  if {$to > $n} { set to $n }
  for {set i $from} {$i <= $to} {incr i} {
    if {[regexp $re [lindex $lines [expr {$i-1}]]]} { return $i }
  }
  return -1
}

# {start end} line range of a C function whose signature matches $sigre; the end
# is the first line that is exactly "}" at column 0.
proc x0498_fnrange {lines sigre} {
  set s [x0498_findln $lines $sigre 1 [llength $lines]]
  if {$s < 0} { return [list -1 -1] }
  for {set i [expr {$s+1}]} {$i <= [llength $lines]} {incr i} {
    if {[lindex $lines [expr {$i-1}]] eq "\}"} { return [list $s $i] }
  }
  return [list $s [llength $lines]]
}

# S1a/S1b/S1c: draw.c:676, psprint.c:988 and svgdraw.c:751 each USED TO dereference
# xctx->sym[xctx->inst[n].ptr] one to three lines ABOVE the `ptr == -1` guard
# that was written to prevent exactly that (upstream commit 40fd937d hoisted the
# assignment). draw.c:1009 draw_temp_symbol() is the in-tree correct ordering.
foreach {rid file sigre} {
  S1a draw.c    {^void draw_symbol\(int what}
  S1b psprint.c {ps_draw_symbol\(int c, int n}
  S1c svgdraw.c {svg_draw_symbol\(int c, int n}
} {
  set lines [x0498_lines [file join $srcdir0498 $file]]
  lassign [x0498_fnrange $lines $sigre] fs fe
  check "$rid located $file symbol drawer" [expr {$fs > 0 && $fe > $fs}]
  set deref -1 ; set guard -1
  if {$fs > 0} {
    set deref [x0498_findln $lines {xctx->sym\[xctx->inst\[n\]\.ptr\]} $fs $fe]
    set guard [x0498_findln $lines {INST_UNBOUND\(n\)|xctx->inst\[n\]\.ptr\s*(==\s*-1|<\s*0)} $fs $fe]
  }
  check "$rid $file guards inst\[n\].ptr BEFORE dereferencing sym\[\]" \
    [expr {$guard > 0 && ($deref < 0 || $guard < $deref)}]
}

# S1d: THE CRASH SITE. hilight.c draw_hilight_net()'s per-layer instance loop
# reaches `symptr = (xctx->inst[i].ptr+ xctx->sym);` with no guard at all;
# propagate_hilights() (hilight.c:1886) already guards `.ptr < 0` and only prints.
set hl [x0498_lines [file join $srcdir0498 hilight.c]]
lassign [x0498_fnrange $hl {^void draw_hilight_net\(int on_window\)}] hs he
check "S1d located hilight.c draw_hilight_net()" [expr {$hs > 0 && $he > $hs}]
set hderef -1 ; set hguard -1
if {$hs > 0} {
  set hderef [x0498_findln $hl {xctx->inst\[i\]\.ptr\s*\+\s*xctx->sym} $hs $he]
  set hguard [x0498_findln $hl {INST_UNBOUND\(i\)|xctx->inst\[i\]\.ptr\s*(<\s*0|==\s*-1)} $hs $he]
}
check "S1d draw_hilight_net guards inst\[i\].ptr before sym\[\] deref" \
  [expr {$hguard > 0 && ($hderef < 0 || $hguard < $hderef)}]

# S2: stored_flags is calloc'd to the ENTRY instance count and read back over the
# CURRENT one; the invariant "those are equal" is enforced by nothing but
# pop_undo. Five byte-identical copies of the same wrong assumption.
foreach nf {spice_netlist.c spectre_netlist.c vhdl_netlist.c verilog_netlist.c tedax_netlist.c} {
  set nl [x0498_lines [file join $srcdir0498 $nf]]
  set rl [x0498_findln $nl {xctx->inst\[i\]\.color\s*=\s*stored_flags\[i\]} 1 [llength $nl]]
  check "S2 located $nf stored_flags restore loop" [expr {$rl > 0}]
  set bounded 0
  if {$rl > 0} {
    set lo [expr {$rl - 3}] ; if {$lo < 1} { set lo 1 }
    set bounded [expr {[x0498_findln $nl {stored_flags_n} $lo $rl] > 0}]
  }
  check "S2 $nf stored_flags restore loop bounded by stored_flags_n" $bounded
}

# S3: the five global_*_netlist drivers and hier_psprint restore the user's
# document by exactly one mechanism -- their own push_undo/pop_undo pair -- which
# xctx->no_undo silently no-ops (save.c:4713/4795, in_memory_undo.c:439/600).
# That pair is the WALK'S save/restore, not editing undo, so it must not be
# disableable by an editing flag. Each driver must take the shield and drop it on
# every exit path (the tail AND the early `return 1` on fopen failure) -- I6.
# NOTE TO THE IMPLEMENTER: these rows encode the plan's chosen names
# undo_shield_push / undo_shield_pop. If you name them differently, update these
# three rows in the same commit; do not weaken the behavioural rows instead.
foreach nf {spice_netlist.c spectre_netlist.c vhdl_netlist.c verilog_netlist.c tedax_netlist.c} {
  set txt [x0498_read [file join $srcdir0498 $nf]]
  set np [regexp -all {undo_shield_push} $txt]
  set nq [regexp -all {undo_shield_pop} $txt]
  check "S3 $nf takes the undo shield" [expr {$np >= 1}]
  check "S3 $nf drops the shield on every exit path (>=2 pops)" [expr {$nq >= 2}]
}
set sl [x0498_lines [file join $srcdir0498 spice_netlist.c]]
lassign [x0498_fnrange $sl {^void hier_psprint\(}] ps pe
check "S3 located hier_psprint()" [expr {$ps > 0 && $pe > $ps}]
set php -1 ; set phq -1
if {$ps > 0} {
  set php [x0498_findln $sl {undo_shield_push} $ps $pe]
  set phq [x0498_findln $sl {undo_shield_pop}  $ps $pe]
}
check "S3 hier_psprint takes and drops the undo shield" [expr {$php > 0 && $phq > 0}]
if {$::fail} { puts "RESULT: FAIL" } else { puts "RESULT: ALL PASS" }
exit $::fail
