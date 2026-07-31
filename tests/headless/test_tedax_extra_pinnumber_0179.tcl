# SIGSEGV in the tEDAx netlister when extra= has no extra_pinnumber= (issue 0179).
#
# print_tedax_element() (src/token.c) walks the symbol's `extra=` list and the
# symbol's `extra_pinnumber=` list IN LOCKSTEP with two my_strtok_r() cursors:
#
#   for(extra_ptr = extra, extra_pinnumber_ptr = extra_pinnumber; ;
#       extra_ptr=NULL, extra_pinnumber_ptr=NULL) {
#     extra_pinnumber_token = my_strtok_r(extra_pinnumber_ptr, " ", "", 0, &saveptr1);
#     extra_token           = my_strtok_r(extra_ptr,           " ", "", 0, &saveptr2);
#     if(!extra_token) break;
#
# my_strdup() leaves its destination NULL when the source is absent or empty
# (util.c), so a symbol carrying `extra=` but no `extra_pinnumber=` enters that
# loop with extra_pinnumber == NULL. my_strtok_r() (util.c:159) only assigns
# *saveptr inside `if(str)`, so a NULL first argument skips straight to
# `while(**saveptr ...)` on an UNINITIALISED saveptr1 -- an uncontrolled deref.
# The `extra` side is safe only by accident: the loop is entered only when
# extra != NULL, so saveptr2 is always initialised on the first pass.
#
# The same shape has a second, quieter arm: `extra_pinnumber` present but with
# FEWER tokens than `extra`. There saveptr1 is initialised, but the cursor runs
# dry and extra_pinnumber_token comes back NULL -- straight into
# my_snprintf(..., "net:%s", NULL) and fprintf(..., "conn %s %s %s %s %d", ...).
#
# The fix mirrors what the PIN loop nine lines above already does for a missing
# `pinnumber` attribute: substitute the literal "--UNDEF--" rather than emit or
# dereference a NULL. It changes nothing for a symbol whose two lists line up.
#
# Legs:
#   TX0-TX1  fixture witness: the aligned extra=/extra_pinnumber= case netlists
#            and really does emit a conn line for the extra node
#   TX2-TX3  the crash: extra= with NO extra_pinnumber= must SURVIVE, and its
#            conn line must carry --UNDEF-- rather than vanish
#   TX4-TX5  the short-list arm: extra= with FEWER extra_pinnumber tokens
#   TX6-TX7  controls that must not move: no extra= at all, and the aligned
#            case's output is unchanged by the fix
#   TX8      an instance-level extra_pinnumber= still overrides the symbol's
#
# Every leg that can crash runs the binary as a SUBPROCESS -- a segfault in this
# file's own interpreter would take the whole run down.
#
# Run either arm:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_tedax_extra_pinnumber_0179.tcl
#   ./src/xschem        --pipe -q --nolog --script tests/headless/test_tedax_extra_pinnumber_0179.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

set no_recent_files 1                       ;# issue 0119: keep Open Recent clean

set here    [file normalize [file dirname [info script]]]
set repo    [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch tedax_extra_pinnumber_0179]
set xbin    [file join $repo src xschem]

set f [open [file join $scratch library.defs] w]
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
puts $f "DEFINE t0179 $scratch"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH $scratch

if {[catch {

proc wfile {p body} { set f [open $p w]; puts $f $body; close $f }

# --- fixture ------------------------------------------------------------------
# A subcircuit symbol carrying a tedax_format. That combination is what makes
# print_tedax_element() take the conn-emitting path at all: without a
# tedax_format it returns early, and a type=subcircuit symbol without one is
# expanded hierarchically instead. NO stock symbol pairs the two, which is why
# this has never been seen.
#
# `pins` is the extra= list, `pinnums` the extra_pinnumber= list; either may be
# empty, which is the whole point of the test.
proc write_sym {path pins pinnums} {
  set k "type=subcircuit\nformat=\"@name @pinlist @symname\"\ntedax_format=\"footprint @name dip8\""
  append k "\ntemplate=\"name=x1\""
  if {$pins ne {}}    { append k "\nextra=\"$pins\"" }
  if {$pinnums ne {}} { append k "\nextra_pinnumber=\"$pinnums\"" }
  set f [open $path w]
  puts $f {v {xschem version=3.4.8RC file_version=1.3}}
  puts $f "G {}"
  puts $f "K {$k}"
  foreach x {V S F E} { puts $f "$x {}" }
  puts $f {L 4 -20 -20 20 -20 {}}
  puts $f {L 4 20 -20 20 20 {}}
  puts $f {L 4 20 20 -20 20 {}}
  puts $f {L 4 -20 20 -20 -20 {}}
  puts $f {B 5 -22.5 -2.5 -17.5 2.5 {name=A dir=inout pinnumber=1}}
  puts $f {T {@symname} -20 -34 0 0 0.2 0.2 {}}
  close $f
}

# The child schematic behind the symbol. Its own nets are irrelevant to the
# crash but it must exist or the symbol cannot be expanded.
wfile [file join $scratch t0179_child.sch] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 200 -30 200 -100 {}
N 200 30 200 100 {}
C {devices/res} 200 0 0 0 {name=R1 value=1k}
C {devices/iopin} 200 -100 0 0 {name=pA lab=A}
C {devices/lab_pin} 200 100 0 0 {name=lHN lab=HN}}

# The top cell. `attrs` goes onto the instance, so a leg can add an
# instance-level extra_pinnumber=.
proc write_top {path attrs} {
  set f [open $path w]
  puts $f {v {xschem version=3.4.8RC file_version=1.3}}
  foreach x {G K V S F E} { puts $f "$x {}" }
  puts $f {N 0 -30 0 -100 {}}
  puts $f {N 0 30 0 100 {}}
  puts $f {N 200 0 380 0 {}}
  puts $f {C {devices/vsource} 0 0 0 0 {name=V1 value=1}}
  puts $f {C {devices/lab_pin} 0 -100 0 0 {name=lT lab=topn}}
  puts $f {C {devices/gnd} 0 100 0 0 {name=g1 lab=GND}}
  puts $f "C {t0179/t0179_child.sym} 400 0 0 0 {name=X1 HN=hnet $attrs}"
  puts $f {C {devices/lab_pin} 200 0 0 0 {name=lT2 lab=topn}}
  close $f
}

# Run a tEDAx netlist in a fresh --nogui child. Returns "ok" if it exited 0
# having printed SURVIVED, "signal" on a segfault, else a short diagnosis.
# A crash here MUST NOT be allowed to kill this interpreter.
proc tedax_child {tag} {
  global scratch xbin
  set sp [file join $scratch child_$tag.tcl]
  set f [open $sp w]
  puts $f "set no_recent_files 1"
  puts $f "set ::XSCHEM_LIBRARY_DEFS [list $::XSCHEM_LIBRARY_DEFS]"
  puts $f {set ::library_registry_defs_only 1}
  puts $f "set ::XSCHEM_LIBRARY_PATH [list $::XSCHEM_LIBRARY_PATH]"
  puts $f "set ::netlist_dir [list $scratch]"
  puts $f "xschem load [list [file join $scratch t0179_top.sch]]"
  puts $f {xschem set netlist_type tedax}
  puts $f {xschem netlist}
  puts $f {puts SURVIVED ; flush stdout ; exit 0}
  close $f
  set out {}
  set rc [catch {exec $xbin --nogui --pipe -q --nolog --script $sp 2>@1} out]
  if {[string match {*SURVIVED*} $out]} { return ok }
  if {[string match {*signal 11*} $out] || [string match {*SIGSEGV*} $out] \
      || [string match {*Segmentation*} $out]} { return signal }
  return "rc=$rc other"
}

# Read back the .tdx the child produced. Returns {} if it never got written.
proc tdx {} {
  global scratch
  set p [file join $scratch t0179_top.tdx]
  if {![file exists $p]} { return {} }
  set f [open $p r]; set t [read $f]; close $f; return $t
}

# tEDAx spells one connection as a PAIR of lines, and the extra= token appears
# only on the second of them:
#     conn    <netvalue> <inst> <pinnumber>
#     pinname <inst>     <pinnumber> <token>
# So look the token up in the `pinname` line to learn its pin number, then find
# the `conn` line carrying that number. Returns the trimmed conn line, or {}.
proc words {ln} { return [regexp -all -inline {\S+} $ln] }
proc connline {txt tok} {
  set num {}
  foreach ln [split $txt \n] {
    set w [words $ln]
    if {[lindex $w 0] eq {pinname} && [lindex $w 3] eq $tok} { set num [lindex $w 2] }
  }
  if {$num eq {}} { return {} }
  foreach ln [split $txt \n] {
    set w [words $ln]
    if {[lindex $w 0] eq {conn} && [lindex $w 3] eq $num} { return [join $w " "] }
  }
  return {}
}

set symp [file join $scratch t0179_child.sym]
set topp [file join $scratch t0179_top.sch]

# --- TX0-TX1  fixture witness: the ALIGNED case -------------------------------
# If this does not emit a conn line for the extra node then the fixture never
# reaches the loop under test and every later leg is asserting nothing.
write_sym $symp {HN} {9}
write_top $topp {}
file delete -force [file join $scratch t0179_top.tdx]
check "TX0 (fixture witness) extra= WITH extra_pinnumber= netlists to tEDAx" \
  [tedax_child aligned] ok
set aligned_txt [tdx]
check "TX1 (fixture witness) the extra node really produces a conn line" \
  [connline $aligned_txt HN] {conn hnet X1 9}

# --- TX2-TX3  the crash: extra= with NO extra_pinnumber= ----------------------
write_sym $symp {HN} {}
file delete -force [file join $scratch t0179_top.tdx]
check "TX2 extra= with NO extra_pinnumber= must not crash the netlister" \
  [tedax_child noextrapin] ok
check "TX3 the missing pin number becomes --UNDEF--, the conn line still emits" \
  [connline [tdx] HN] {conn hnet X1 --UNDEF--}

# --- TX4-TX5  the short-list arm ----------------------------------------------
# saveptr1 IS initialised here, so this arm does not segfault on the first
# token -- it runs the cursor dry and hands NULL to my_snprintf/fprintf.
write_sym $symp {HN HN2} {9}
file delete -force [file join $scratch t0179_top.tdx]
check "TX4 fewer extra_pinnumber tokens than extra tokens must not crash" \
  [tedax_child shortlist] ok
set short_txt [tdx]
check "TX5 the aligned token keeps its number, the runover gets --UNDEF--" \
  [list [connline $short_txt HN] [connline $short_txt HN2]] \
  [list {conn hnet X1 9} {conn --UNDEF-- X1 --UNDEF--}]

# --- TX6-TX7  controls --------------------------------------------------------
write_sym $symp {} {}
file delete -force [file join $scratch t0179_top.tdx]
check "TX6 (control) a symbol with no extra= at all still netlists" \
  [tedax_child noextra] ok
set noextra_txt [tdx]
check "TX7 (control) with no extra= there is no extra conn line" \
  [connline $noextra_txt HN] {}

# TX7b: the aligned case is BEHAVIOUR-NEUTRAL under the fix -- re-netlist it and
# demand byte equality with the run at the top of this file. If a future change
# to this loop alters the normal path, this is what catches it.
write_sym $symp {HN} {9}
file delete -force [file join $scratch t0179_top.tdx]
check "TX7b (control) the aligned case is byte-identical on a re-run" \
  [expr {[tedax_child aligned2] eq {ok} && [tdx] eq $aligned_txt}] 1

# --- TX8  instance-level extra_pinnumber= overrides the symbol's --------------
# print_tedax_element reads the INSTANCE first and only falls back to the
# symbol, so a symbol with no extra_pinnumber= is still safe if the instance
# supplies one. This pins the precedence the fix must not disturb.
write_sym $symp {HN} {}
write_top $topp {extra_pinnumber="7"}
file delete -force [file join $scratch t0179_top.tdx]
check "TX8 an instance-level extra_pinnumber= supplies the missing number" \
  [list [tedax_child instpin] [connline [tdx] HN]] [list ok {conn hnet X1 7}]

} err]} { puts "FATAL: $err" ; incr fail }

# House banner form: full_audit.sh is_pass() scores on "RESULT: ALL PASS".
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
