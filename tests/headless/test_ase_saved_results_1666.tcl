# tests/headless/test_ase_saved_results_1666.tcl -- ISSUE 1666: SAVE A RESULT
# UNDER A NAME, SELECT IT LATER, DELETE IT (ADE-L's Results > Save / Select /
# Delete). Spec: doc/claude/specs/results_selection.md §20.
#
# Runs still overwrite `<rundir>/<cell>_ase.*` in place. Save COPIES the result
# in view into `<results_dir>/<lib>/<cell>/<folder>/` with a `result.meta`;
# selecting a saved result presents the session's state with `rundir` pointed
# at that folder (`ase::result_state`), so every reader follows it.
#
# THE FIXTURE IS SYNTHESISED, NEVER SIMULATED: two hand-written ASCII raws whose
# values differ (row SVR0 asserts it), a log with an exit footer, a plotmap, a
# meas sidecar, a deck, a run state, a co-simulation map and VCD, an OP dump
# under its lowercased name, `<cell>.spice`, both `.s2p` spellings, a
# checkpoint, excluded build files and PLANTED HAZARDS (a stale `<cell>.spice`,
# an old `.s2p`, a symlinked raw). Only SVR20/SVR32 start a "simulator", and it
# is a two-line shell stand-in that exits 0, so no ngspice is needed and no
# lowercase skip line is ever printed.
#
# SECTIONS
#   SVR0-SVR33, SVR-D1, SVR-D2   the pure layer, headless (both arms)
#   SVR40-SVR47, SVR50           the forms, display arm only (an UPPERCASE
#                                `SKIP:` line names them headless)
#
# SECTIONS (the verify round, each built against a named sabotage or defect)
#   SVR2b SVR12b SVR13b SVR14b SVR17c SVR18e SVR23b SVR25b SVR27e SVR27f
#   SVR28b SVR29d SVR30c SVR31b SVR32b SVR51 SVR51b   headless (both arms)
#   SVR45b SVR47b                                       display arm only
#
# DECLARED LIMITS (not measured here)
# * SVR48 (Plot Outputs / Direct Plot keep another loaded slot under a saved
#   view) is NOT a row: the viewer attach under a saved view still goes through
#   `wviewer::attach_raw`. The OP-dump LOOKUP is fenced (SVR14/SVR14b), and the
#   annotation re-attach DECISION is fenced with the engine stubbed (SVR51,
#   SVR51b); the window path that paints the numbers through Annotate is not.
# * `ase::ui::rsave_ok`'s disabled-button guard is a second copy of
#   `saved_save_body`'s busy refusal (OK is disabled exactly when that refuses),
#   so deleting the guard alone is unobservable; SVR43 asserts the outcome
#   through both the button and the Return binding.
# * `saved_target_ok`'s symlink and containment terms repeat `saved_meta` /
#   `saved_list`'s; deleting one copy alone is unobservable through Delete.
# * Selecting a saved row through the dialog (the candidate's path and the
#   view moving) is display-only (SVR45, SVR45b); its OPTIONS are fenced
#   headless (SVR25b).
# * SVR-D1's caller scan is TEXTUAL: a computed proc name or an alias is
#   invisible to it.
# * The registry drop after overwrite/delete (R907a) acts in the CURRENT xschem
#   context only.
#
# Arms (the armed spelling keeps your HOME and screen untouched):
#   tests/headless/run_suites.sh --nogui test_ase_saved_results_1666
#   tests/headless/run_suites.sh test_ase_saved_results_1666

set fail 0; set npass 0
set ::seen {}
proc check {name got exp} {
  global fail npass
  lappend ::seen [lindex $name 0]
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

set no_recent_files 1

# --- the answer discipline -----------------------------------------------------
proc pcall {args} {
  set cmd [lindex $args 0]
  if {![llength [info commands $cmd]]} { return NOPROC }
  if {[catch {uplevel #0 $args} r]} { return "RAISED: $r" }
  return $r
}
## dict get through a sentinel: a band never aborts on a raise sentinel
proc dg {d k {dflt ZZNOKEY}} {
  if {[catch {dict exists $d $k} e] || !$e} { return $dflt }
  return [dict get $d $k]
}
## run a band; an abort is ONE counted failure naming the band
proc group {id body} {
  if {[catch {uplevel #0 $body} e]} {
    check "$id band ran to the end" "ABORTED: $e" {}
  }
}
proc slurp {path} {
  if {![file exists $path]} { return ZZNOFILE }
  if {[catch {open $path rb} fp]} { return ZZNOREAD }
  set t [read $fp] ; close $fp
  return $t
}
proc wr {path text {mode {}}} {
  file mkdir [file dirname $path]
  set f [open $path wb] ; puts -nonewline $f $text ; close $f
  if {$mode ne {}} { file attributes $path -permissions $mode }
  return $path
}
proc wex {w} {
  if {[catch {winfo exists $w} e]} { return 0 }
  return $e
}
## a snapshot of a directory tree: {relpath size mtime md5ish} sorted
proc tree {dir} {
  if {![file isdirectory $dir]} { return ZZNODIR }
  set out {}
  foreach p [lsort [glob -nocomplain -directory $dir * .*]] {
    set t [file tail $p]
    if {$t in {. ..}} { continue }
    if {[file type $p] eq {link}} {
      lappend out [list $t link [file readlink $p]]
    } elseif {[file isdirectory $p]} {
      foreach e [tree $p] { lappend out [list $t/[lindex $e 0] {*}[lrange $e 1 end]] }
    } else {
      set sz -1 ; set mt -1
      catch {set sz [file size $p]} ; catch {set mt [file mtime $p]}
      lappend out [list $t $sz $mt [string length [slurp $p]]]
    }
  }
  return $out
}

# --- locations ---------------------------------------------------------------
set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch saved_1666]
test_sim_registry_isolate

set NDSAVE [expr {[info exists ::netlist_dir] ? $::netlist_dir : {ZZUNSET}}]
set LNDSAVE [expr {[info exists ::local_netlist_dir] ? $::local_netlist_dir : {ZZUNSET}}]
set UCDSAVE [expr {[info exists ::USER_CONF_DIR] ? $::USER_CONF_DIR : {ZZUNSET}}]
set ::local_netlist_dir 0
set ::netlist_dir [file join $scratch simdir]
file mkdir $::netlist_dir
set ::USER_CONF_DIR [file join $scratch conf]
file mkdir $::USER_CONF_DIR

## ase::echo recorder (the channel is the CIW; nothing here may print to it)
set ::echoes {}
rename ::ase::echo ::svr_real_echo
proc ::ase::echo {msg {tag {}}} { lappend ::echoes $msg ; return 1 }

# =============================================================================
# THE FIXTURE
# =============================================================================
set CELL tb

## an ASCII raw: a transient (v(out) = base + i) and an operating point
proc mkraw {path base} {
  set b "Title: svr fixture\nDate: Thu Jan  1 00:00:00 2026\n"
  append b "Plotname: Transient Analysis\nFlags: real\nNo. Variables: 2\nNo. Points: 3\n"
  append b "Variables:\n\t0\ttime\ttime\n\t1\tv(out)\tvoltage\nValues:\n"
  for {set i 0} {$i < 3} {incr i} {
    append b "$i\t[expr {$i * 1e-9}]\n\t[expr {$base + $i}]\n\n"
  }
  append b "Plotname: Operating Point\nFlags: real\nNo. Variables: 1\nNo. Points: 1\n"
  append b "Variables:\n\t0\tv(out)\tvoltage\nValues:\n0\t[expr {$base * 10.0}]\n\n"
  wr $path $b
}
## a raw with an operating point only (SVR30b's typeless select)
proc mkraw_op {path base} {
  set b "Title: svr op\nDate: Thu Jan  1 00:00:00 2026\n"
  append b "Plotname: Operating Point\nFlags: real\nNo. Variables: 1\nNo. Points: 1\n"
  append b "Variables:\n\t0\tv(out)\tvoltage\nValues:\n0\t[expr {$base * 10.0}]\n\n"
  wr $path $b
}

## a session on a state file; `rundir` DIR. Outputs: one op-qualified row.
proc mksession {key dir {lib L} {cell tb} {extra {}}} {
  set p [file join $::scratch [string map {/ _} $key].state]
  set st [ase::state_default]
  dict set st design [dict create lib $lib cell $cell view schematic]
  dict set st rundir $dir
  dict set st outputs {{name VO expr v(out) save 1 plot 0}}
  foreach {k v} $extra { dict set st $k $v }
  ase::state_save $p $st
  ase::session_open $key $p
  return $p
}

## a complete run directory. VARIANT 1 or 2 gives different values. Every
## artifact is given an explicit, ordered mtime so freshness is deterministic.
set T0 [expr {[clock seconds] - 7200}]
proc mkrun {dir variant {cell tb}} {
  global T0
  set t [expr {$T0 + $variant * 600}]
  file mkdir $dir
  set deck [wr [file join $dir ${cell}_ase.spice] "* deck v$variant\n.end\n"]
  file mtime $deck $t
  set raw [file join $dir ${cell}_ase.raw]
  mkraw $raw [expr {$variant == 1 ? 1.0 : 5.0}]
  file mtime $raw [expr {$t + 20}]
  set log [wr [file join $dir ${cell}_ase.log] \
             "run v$variant\n\n=== exit 0 after 1.00 s ===\n"]
  file mtime $log [expr {$t + 21}]
  foreach {ext txt} [list plotmap "PLOT op 0 |Operating Point|\n" \
                          meas "ASE-MEAS\nm1 = $variant.5\n" \
                          effective "set x=$variant\n" \
                          raw.ckpt "ckpt v$variant\n"] {
    set p [wr [file join $dir ${cell}_ase.$ext] $txt]
    file mtime $p [expr {$t + 15}]
  }
  set rs [ase::state_default]
  dict set rs design [dict create lib L cell $cell view schematic]
  dict set rs outputs {{name VO expr v(out) save 1 plot 0}}
  dict set rs temperature [expr {$variant == 1 ? 27 : 85}]
  set p [wr [file join $dir ${cell}_ase.runstate] [ase::state_serialize $rs]]
  file mtime $p [expr {$t + 1}]
  ## co-simulation map + its VCD (absolute vcd field in the run directory)
  set vcd [wr [file join $dir ctr.vcd] "\$date x \$end\n#0\n"]
  file mtime $vcd [expr {$t + 18}]
  set p [wr [file join $dir ${cell}_ase.cosim] \
           "# map\n[list [dict create model ctr vcd $vcd multi 0]]\n"]
  file mtime $p [expr {$t + 18}]
  set ev [wr [file join $dir ${cell}_ase_evt.vcd] "\$date e \$end\n#0\n"]
  file mtime $ev [expr {$t + 18}]
  ## fresh-only artifacts, fresh
  foreach f [list ${cell}.spice ${cell}_ase.s2p ${cell}_ase_sp0.s2p .spiceinit] {
    set p [wr [file join $dir $f] "fresh $f v$variant\n"]
    file mtime $p [expr {$t + 10}]
  }
  ## the OP dump, under the name the simulator was given (lowercased)
  set od [op_annot::opdump_path $raw]
  set p [wr $od "OP dump v$variant\n"]
  file mtime $p [expr {$t + 20}]
  ## never copied
  foreach f [list ${cell}_ase_evtprobe.spice ctr.so ctr.stamp ${cell}_ase.raw.ckpt.tmp] {
    set p [wr [file join $dir $f] "never\n"]
    file mtime $p [expr {$t + 5}]
  }
  return $dir
}

set LIVE [file normalize [file join $scratch run]]
mkrun $LIVE 1
set KEY L/tb/s1
mksession $KEY $LIVE
set RUN2 [file normalize [file join $scratch run2src]]
mkrun $RUN2 2

## planted hazards in a separate run directory: a stale `<cell>.spice` (newer
## than the raw) and an old `.s2p` (older than the deck), and a symlinked raw.
set HZ [file normalize [file join $scratch runhz]]
mkrun $HZ 1
set HZT [file mtime [file join $HZ tb_ase.raw]]
file mtime [file join $HZ tb.spice] [expr {$HZT + 300}]
file mtime [file join $HZ tb_ase_sp0.s2p] [expr {[file mtime [file join $HZ tb_ase.spice]] - 300}]
set HZREAL [file join $scratch realraw tb_ase.raw]
file mkdir [file dirname $HZREAL]
file rename -force [file join $HZ tb_ase.raw] $HZREAL
file mtime $HZREAL $HZT
set HASLINK [expr {![catch {file link -symbolic [file join $HZ tb_ase.raw] $HZREAL}]}]
set HZKEY L/tb/hz
mksession $HZKEY $HZ

# --- SVR0: the fixture is present and the two runs really differ ---------------
group SVR0 {
  set want {tb_ase.raw tb_ase.log tb_ase.plotmap tb_ase.meas tb_ase.spice
            tb_ase.runstate tb_ase.raw.ckpt tb_ase.effective tb_ase.cosim ctr.vcd
            tb_ase_evt.vcd tb.spice tb_ase.s2p tb_ase_sp0.s2p .spiceinit tb_ase.opinfo
            tb_ase_evtprobe.spice ctr.so ctr.stamp tb_ase.raw.ckpt.tmp}
  set miss {}
  foreach f $want {
    if {![file exists [file join $LIVE $f]]} { lappend miss L:$f }
    if {![file exists [file join $RUN2 $f]]} { lappend miss 2:$f }
  }
  check {SVR0 every planted artifact exists in both runs} [list [llength $want] $miss] {20 {}}
  ## byte-wise AND in the values the rows compare (the adjacent-pair rule)
  xschem raw_read [file join $LIVE tb_ase.raw] op
  set v1 [xschem raw value v(out) 0]
  xschem raw clear
  xschem raw_read [file join $RUN2 tb_ase.raw] op
  set v2 [xschem raw value v(out) 0]
  xschem raw clear
  check {SVR0 the live and second-run raws differ byte-wise and in the OP value the rows read} \
    [list [expr {[slurp [file join $LIVE tb_ase.raw]] ne [slurp [file join $RUN2 tb_ase.raw]]}] \
          $v1 $v2] {1 10 50}
  check {SVR0 the hazard run has its symlinked raw, stale netlist and old s2p} \
    [list $HASLINK [file type [file join $HZ tb_ase.raw]] \
       [expr {[file mtime [file join $HZ tb.spice]] > $HZT}] \
       [expr {[file mtime [file join $HZ tb_ase_sp0.s2p]] < [file mtime [file join $HZ tb_ase.spice]]}]] \
    {1 link 1 1}
}

# =============================================================================
# SVR1-SVR5: names, folders, roots, scoping, schema
# =============================================================================
group SVR1 {
  set acc {} ; set ref {}
  foreach n [list TT_27C {TT 27C after fix} a [string repeat x 64] {ü café}] {
    lappend acc [lindex [pcall ase::saved_name_ok $n] 0]
  }
  foreach n [list {} {   } a/b {a\b} [string repeat x 65] "a\tb" "a\nb" "x\x01"] {
    lappend ref [lindex [pcall ase::saved_name_ok $n] 0]
  }
  check {SVR1 saved_name_ok accepts free text and refuses empty, blank, separators, >64 and control characters} \
    [list [llength $acc] [lsort -unique $acc] [llength $ref] [lsort -unique $ref] \
          [lindex [pcall ase::saved_name_ok a/b] 1]] \
    [list 5 1 8 0 [ase::ui::lbl_rsave_badname]]
}
group SVR1b {
  set r [file join $scratch fold]
  file mkdir [file join $r TT]
  check {SVR1b saved_folder_for: space to _, leading dot prefixed, reserved stem suffixed, case-insensitive clash} \
    [list [pcall ase::saved_folder_for $r {TT 27C}] [pcall ase::saved_folder_for $r .x] \
          [pcall ase::saved_folder_for $r CON] [pcall ase::saved_folder_for $r lpt1.txt] \
          [pcall ase::saved_folder_for $r tt] [pcall ase::saved_folder_for $r a.]] \
    {TT_27C _.x CON_ lpt1_.txt tt-2 a}
}
group SVR2 {
  set rt [file mtime [file join $LIVE tb_ase.raw]]
  set want "tb_[clock format $rt -format %Y%m%d_%H%M]"
  set d1 [pcall ase::saved_default_name $KEY [expr {$rt + 99999}]]
  check {SVR2 the default name comes from when the run HAPPENED (the raw), not the clock, and is a valid name} \
    [list $d1 [lindex [pcall ase::saved_name_ok $d1] 0]] [list $want 1]
}
group SVR3 {
  set k L/tb/s3
  set nd [file join $scratch nope3 run]
  mksession $k $nd
  set r0 [pcall ase::saved_root $k]
  set st [ase::session_state $k] ; dict set st results_dir [file join $scratch nope3 res]
  ase::session_update $k $st
  set r1 [pcall ase::saved_root $k]
  set r2 [pcall ase::saved_root $k [file join $scratch nope3 other]]
  set l1 [pcall ase::saved_list $k]
  check {SVR3 saved_root: default <rundir>/saved, results_dir honoured, ?dir? honoured, lib/cell levels; nothing is created} \
    [list $r0 $r1 $r2 $l1 [file exists $nd] [file exists [file join $scratch nope3]]] \
    [list [file join [file normalize $nd] saved L tb] [file join [file normalize $scratch] nope3 res L tb] \
          [file join [file normalize $scratch] nope3 other L tb] {} 0 0]
}
group SVR4 {
  ## two cells and the same cell in two libraries share one fallback directory
  set sh [file join $scratch shared4]
  mkrun $sh 1 ca
  mkrun $sh 1 cb
  mksession A/ca/v $sh A ca
  mksession B/ca/v $sh B ca
  mksession A/cb/v $sh A cb
  set a [pcall ase::saved_save A/ca/v one {} {} 0]
  set b [pcall ase::saved_save B/ca/v two {} {} 0]
  set c [pcall ase::saved_save A/cb/v three {} {} 0]
  ## a meta with another design planted under A/ca's root
  set fo [file join $sh saved A ca forged]
  file mkdir $fo
  wr [file join $fo result.meta] [dict create format 1 folder forged name forged cell ca \
                                    design {Z ca schematic} saved 1]
  proc names {k} { set o {} ; foreach r [pcall ase::saved_list $k] { lappend o [dg $r name] } ; return $o }
  check {SVR4 each cell and each library lists only its own; a meta with another design is not listed} \
    [list [dg $a ok] [dg $b ok] [dg $c ok] [names A/ca/v] [names B/ca/v] [names A/cb/v]] \
    {1 1 1 one two three}
}
group SVR5 {
  check {SVR5 results_dir is a schema key and omitted when empty} \
    [list [expr {{results_dir} in $::ase::schema_keys}] [expr {{results_dir} in $::ase::omit_if_empty}] \
          [string first results_dir [ase::state_serialize [ase::state_default]]]] {1 1 -1}
  source [file join $repo tests headless state_roundtrip.tcl]
  set rt [ase_state_roundtrip $repo [file join $scratch rt.tmp]]
  check {SVR5 every committed .state file round-trips byte-identical (count > 0)} \
    [list [expr {[dg $rt tracked 0] > 0}] [dg $rt bad] [dg $rt control_disagrees] [dg $rt control_agrees]] \
    {1 {} 1 1}
}

# =============================================================================
# SVR10-SVR16: what is copied, and the refusals
# =============================================================================
set SROOT [file join $LIVE saved L tb]
group SVR10 {
  set r [pcall ase::saved_save $KEY {TT_27C} "first line\nsecond line" {} 0]
  set d [dg $r dir]
  ## the LITERAL expected set, built from the fixture, not from saved_artifacts
  set want [lsort {tb_ase.raw tb_ase.log tb_ase.plotmap tb_ase.meas tb_ase.spice
            tb_ase.runstate tb_ase.raw.ckpt tb_ase.effective tb_ase.cosim ctr.vcd
            tb_ase_evt.vcd tb.spice tb_ase.s2p tb_ase_sp0.s2p .spiceinit tb_ase.opinfo}]
  set have [lsort [glob -nocomplain -tails -directory $d * .*]]
  set have [lsearch -all -inline -not -exact [lsearch -all -inline -not -exact $have .] ..]
  set meta [pcall ase::saved_meta $d]
  set bad {}
  foreach f $want {
    set s [file join $LIVE $f] ; set c [file join $d $f]
    if {$f eq {tb_ase.cosim}} { continue }
    if {[slurp $s] ne [slurp $c] || [file size $s] != [file size $c] ||
        [file mtime $s] != [file mtime $c] || [file type $c] ne {file}} { lappend bad $f }
  }
  check {SVR10 Save copies the literal artifact set, byte-, size- and mtime-equal real files, plus result.meta} \
    [list [dg $r ok] [dg $r how] [file tail $d] $have [lsort [dg $meta files]] $bad] \
    [list 1 saved TT_27C [lsort [concat $want result.meta]] $want {}]
  ## the symlinked raw is copied as its TARGET's bytes, not as a link
  set h [pcall ase::saved_save $HZKEY hz {} {} 0]
  set hd [dg $h dir]
  check {SVR10 a symlinked raw is copied as a real file with the target's bytes and mtime} \
    [list [dg $h ok] [file type [file join $hd tb_ase.raw]] \
          [expr {[slurp [file join $hd tb_ase.raw]] eq [slurp $HZREAL]}] \
          [expr {[file mtime [file join $hd tb_ase.raw]] == [file mtime $HZREAL]}]] \
    {1 file 1 1}
}
group SVR11 {
  set tmp [file join $scratch run11]
  mkrun $tmp 1
  mksession L/tb/s11 $tmp
  set r [pcall ase::saved_save L/tb/s11 keep {} {} 0]
  set before [slurp [file join [dg $r dir] tb_ase.raw]]
  foreach f [glob -directory $tmp tb_ase.*] { file delete $f }
  check {SVR11 deleting the live files leaves the saved copy readable and byte-equal} \
    [list [dg $r ok] [expr {[slurp [file join [dg $r dir] tb_ase.raw]] eq $before}] \
          [expr {[string length $before] > 100}]] {1 1 1}
}
group SVR12 {
  set h [file join $HZ saved L tb hz]
  set m [pcall ase::saved_meta $h]
  check {SVR12 excluded files are never copied; a stale tb.spice and an old s2p are skipped as stale; fresh ones and both s2p spellings are copied} \
    [list [lsort [dg $m skipped]] \
          [file exists [file join $h tb.spice]] [file exists [file join $h tb_ase_sp0.s2p]] \
          [file exists [file join $SROOT TT_27C tb_ase.s2p]] [file exists [file join $SROOT TT_27C tb_ase_sp0.s2p]] \
          [file exists [file join $SROOT TT_27C ctr.so]] [file exists [file join $SROOT TT_27C tb_ase_evtprobe.spice]] \
          [file exists [file join $SROOT TT_27C tb_ase.raw.ckpt.tmp]]] \
    {{{tb.spice stale} {tb_ase_sp0.s2p stale}} 0 0 1 1 0 0 0}
}
group SVR13 {
  set d [file join $SROOT TT_27C]
  set st [ase::session_state $KEY] ; dict set st rundir $d
  set map [pcall ase::cosim_load_map $st]
  set v [dg [lindex $map 0] vcd]
  check {SVR13 the saved cosim map's vcd fields point INTO the saved folder, and the file exists} \
    [list [llength $map] [file dirname $v] [file isfile $v]] [list 1 $d 1]
}
group SVR14 {
  set r1 [pcall ase::saved_save $KEY tt_27c_low {} {} 0]
  set up [file join $SROOT TT_27C tb_ase.raw]
  set lo [file join [dg $r1 dir] tb_ase.raw]
  set fu [pcall op_annot::opdump_find $up]
  set fl [pcall op_annot::opdump_find $lo]
  set mu [pcall op_annot::opdump_merge $up]
  check {SVR14 the OP dump lands case-kept and opdump_find finds it for an UPPERCASE and a lowercase saved name; the merge reads it} \
    [list [file tail [file dirname $fu]] [file isfile $fu] [file isfile $fl] \
          [slurp $fu] [expr {[dg $mu error {}] ne {} || [dg $mu stale 0] == 0}]] \
    [list TT_27C 1 1 "OP dump v1\n" 1]
  check {SVR14 the lowercased spelling is unchanged (the simulator is handed it)} \
    [pcall op_annot::opdump_path /A/B.raw] /a/b.opinfo
}
group SVR15 {
  set d [file join $SROOT TT_27C]
  set m [pcall ase::saved_meta $d]
  set keys {format name folder comment saved ran cell design simulator source exit stopped
            types viewtype state_source files skipped}
  set miss {}
  foreach k $keys { if {![dict exists $m $k]} { lappend miss $k } }
  check {SVR15 the meta parses as a dict with every key, viewtype is one of types, ran is the raw's mtime} \
    [list $miss [dg $m name] [dg $m comment] [dg $m types] [dg $m viewtype] \
          [expr {[dg $m viewtype] in [dg $m types]}] \
          [expr {[dg $m ran] == [file mtime [file join $LIVE tb_ase.raw]]}] [dg $m state_source] \
          [dg $m design]] \
    [list {} TT_27C "first line\nsecond line" {tran op} [dg $m viewtype] 1 1 run {L tb schematic}]
  ## a meta holding a command is READ, never evaluated
  set ev [file join $scratch evil15 evil]
  file mkdir $ev
  catch {unset ::svr15_pwned}
  wr [file join $ev result.meta] {format 1 folder evil name {[set ::svr15_pwned 1]} comment x}
  set em [pcall ase::saved_meta $ev]
  check {SVR15 a meta holding a command substitution is read as text and never evaluated} \
    [list [info exists ::svr15_pwned] [dg $em name]] [list 0 {[set ::svr15_pwned 1]}]
}
group SVR16 {
  proc nodot {root} {
    return [llength [glob -nocomplain -types {d hidden} -directory $root .*.partial.* .*.old.*]]
  }
  ## busy live run
  set ::svr16_busy 1
  rename ::ase::rundir_busy ::svr16_real_busy
  proc ::ase::rundir_busy {key} { if {$::svr16_busy} { return run } ; return {} }
  set b [pcall ase::saved_save $KEY busy1 {} {} 0]
  rename ::ase::rundir_busy {}
  rename ::svr16_real_busy ::ase::rundir_busy
  ## no raw
  set nr [file join $scratch run16]
  file mkdir $nr
  mksession L/tb/s16 $nr
  set n [pcall ase::saved_save L/tb/s16 nr {} {} 0]
  ## empty raw (the constants plot)
  set er [file join $scratch run16e]
  file mkdir $er
  wr [file join $er tb_ase.raw] "Title: Constant values\nDate: x\nPlotname: constants\nFlags: real\nNo. Variables: 12\nNo. Points: 1\nVariables:\n\t0\tpi\tnotype\nValues:\n0\t3.14\n"
  mksession L/tb/s16e $er
  set e [pcall ase::saved_save L/tb/s16e er {} {} 0]
  set bn [pcall ase::saved_save $KEY {a/b} {} {} 0]
  check {SVR16 refusals answer ok 0 with the exact sentence and leave no folder and no staging} \
    [list [dg $b ok] [dg $b msg] [file exists [file join $SROOT busy1]] \
          [dg $n ok] [dg $n msg] [file exists [file join $nr saved]] \
          [dg $e ok] [dg $e msg] [dg $bn ok] [dg $bn msg] [nodot $SROOT]] \
    [list 0 [ase::ui::lbl_rsave_busy] 0 0 [ase::ui::lbl_rsave_noraw] 0 \
          0 [ase::ui::lbl_rsave_empty] 0 [ase::ui::lbl_rsave_badname] 0]
}
group SVR16b {
  rename ::ase::rundir_busy ::svr16_real_busy
  proc ::ase::rundir_busy {key} { return campaign }
  set c [pcall ase::saved_save $KEY camp1 {} {} 0]
  proc ::ase::rundir_busy {key} { return run }
  ## a saved folder as the source while a run is busy: saves
  ase::result_sel_note $KEY [file join $SROOT TT_27C tb_ase.raw]
  set s [pcall ase::saved_save $KEY fromsaved {} {} 0]
  ase::result_sel_note $KEY {}
  rename ::ase::rundir_busy {}
  rename ::svr16_real_busy ::ase::rundir_busy
  check {SVR16b a running campaign does not block Save (the note says so); a saved source saves while a run is busy} \
    [list [dg $c ok] [dg $c note] [dg $s ok]] [list 1 [ase::ui::lbl_rsave_campaign] 1]
}

# =============================================================================
# SVR17-SVR19: overwrite, atomicity, sweep, listing
# =============================================================================
group SVR17 {
  set before [slurp [file join $SROOT TT_27C tb_ase.raw]]
  set src2 [slurp [file join $RUN2 tb_ase.raw]]
  set u [pcall ase::saved_save $KEY TT_27C {} {} 0]
  set mid [slurp [file join $SROOT TT_27C tb_ase.raw]]
  ## make the live run the SECOND run, then overwrite confirmed
  foreach f [glob -directory $RUN2 -tails * .*] {
    if {$f in {. ..}} continue
    file copy -force [file join $RUN2 $f] [file join $LIVE $f]
  }
  set c [pcall ase::saved_save $KEY tt_27c {} {} 1]
  set after [slurp [file join $SROOT TT_27C tb_ase.raw]]
  check {SVR17 an existing name (any case): unconfirmed asks and changes nothing; confirmed overwrites with the second run} \
    [list [expr {$before ne $src2}] [dg $u how] [dg $u msg] [expr {$mid eq $before}] \
          [dg $c how] [expr {$after eq $src2}] [dg [pcall ase::saved_meta [file join $SROOT TT_27C]] name]] \
    [list 1 needconfirm [ase::ui::lbl_rsave_overwrite TT_27C] 1 overwritten 1 tt_27c]
}
group SVR17b {
  ## a meta-less folder where the name's folder would land is never reached:
  ## it is not listed, so the name derives a fresh folder beside it
  file mkdir [file join $SROOT plain]
  wr [file join $SROOT plain x.txt] keep
  set p [pcall ase::saved_save $KEY plain {} {} 1]
  ## target_ok on a meta-less folder, on a symlink, on the run directory
  set t1 [pcall ase::saved_target_ok $SROOT plain $LIVE]
  set lk [file join $SROOT linked]
  catch {file link -symbolic $lk [file join $SROOT TT_27C]}
  set t2 [pcall ase::saved_target_ok $SROOT linked $LIVE]
  set rdm [file join $scratch q17 L tb run]
  file mkdir $rdm
  wr [file join $rdm result.meta] [dict create format 1 folder run name run cell tb design {L tb schematic}]
  set t3 [pcall ase::saved_target_ok [file dirname $rdm] run $rdm]
  check {SVR17b a folder that is not a saved result, a symlink and the run directory are never targets} \
    [list [dg $p ok] [file tail [dg $p dir]] [slurp [file join $SROOT plain x.txt]] \
          [lindex $t1 0] [lindex $t2 0] [lindex $t3 0] [file type [file join $SROOT TT_27C]]] \
    {1 plain-2 keep 0 0 0 directory}
  ## a Directory whose saved folder IS the run directory, or lies in its
  ## campaign tree, is refused
  set k17 L/tb/s17b
  set rd [file join $scratch q17b L tb run]
  mkrun $rd 1
  mksession $k17 $rd
  set rdb [tree $rd]
  set a [pcall ase::saved_save $k17 run {} [file join $scratch q17b] 0]
  set c [pcall ase::saved_save $k17 cmp {} [file join $rd campaign] 0]
  check {SVR17b a name equal to the run directory's folder derives a new folder and never writes into it; a destination in the campaign tree is refused} \
    [list [dg $a ok] [file tail [dg $a dir]] [expr {[tree $rd] eq $rdb}] \
          [dg $c ok] [dg $c msg] [file exists [file join $rd campaign]]] \
    [list 1 run-2 1 0 [ase::ui::lbl_rsave_badroot] 0]
}
group SVR18 {
  set n0 [llength [glob -nocomplain -directory $SROOT *]]
  set ::svr18_n 0
  rename ::ase::saved_copy_file ::svr18_real_copy
  proc ::ase::saved_copy_file {s d} {
    incr ::svr18_n
    if {$::svr18_n == 3} { error "disk said no" }
    ::svr18_real_copy $s $d
  }
  set r [pcall ase::saved_save $KEY fail18 {} {} 0]
  rename ::ase::saved_copy_file {}
  rename ::svr18_real_copy ::ase::saved_copy_file
  ## and a failing rename of the old result during an overwrite
  set old [slurp [file join $SROOT TT_27C tb_ase.raw]]
  rename ::ase::saved_rename ::svr18_real_rename
  proc ::ase::saved_rename {a b} {
    if {[string match {*.old.*} $b]} { error "rename refused" }
    ::svr18_real_rename $a $b
  }
  set o [pcall ase::saved_save $KEY TT_27C {} {} 1]
  rename ::ase::saved_rename {}
  rename ::svr18_real_rename ::ase::saved_rename
  check {SVR18 a copy failing on the third file, or the overwrite rename failing, leaves no folder, no staging and the old result intact} \
    [list [expr {$::svr18_n >= 3}] [dg $r ok] [string match {Save failed: *} [dg $r msg]] \
          [file exists [file join $SROOT fail18]] [nodot $SROOT] \
          [dg $o ok] [expr {[slurp [file join $SROOT TT_27C tb_ase.raw]] eq $old}] \
          [llength [glob -nocomplain -directory $SROOT *]]] \
    [list 1 0 1 0 0 0 1 $n0]
}
group SVR18b {
  rename ::ase::saved_copy_file ::svr18_real_copy
  set ::svr18b_n 0
  proc ::ase::saved_copy_file {s d} {
    incr ::svr18b_n
    ::svr18_real_copy $s $d
    if {$::svr18b_n == 2} {
      set f [open [file join $::LIVE tb_ase.log] a] ; puts $f "moved" ; close $f
    }
  }
  set r [pcall ase::saved_save $KEY moved18 {} {} 0]
  rename ::ase::saved_copy_file {}
  rename ::svr18_real_copy ::ase::saved_copy_file
  check {SVR18b a source that changes during the copy aborts with the sentence and leaves nothing} \
    [list [dg $r ok] [dg $r msg] [file exists [file join $SROOT moved18]] [nodot $SROOT]] \
    [list 0 [ase::ui::lbl_rsave_changed] 0 0]
}
group SVR18c {
  ## a dead pid: find one that is not running
  set dead 999999
  while {[file exists /proc/$dead]} { incr dead -1 }
  set pz [file join $SROOT .zz.partial.$dead]
  file mkdir $pz
  wr [file join $pz junk] x
  set orig [file join $SROOT TT_27C]
  set oldp [file join $SROOT .rec.old.$dead]
  file copy $orig $oldp
  set m [dict create {*}[slurp [file join $oldp result.meta]]]
  dict set m folder rec ; dict set m name rec
  ase::saved_write_meta [file join $oldp result.meta] $m
  set live [file join $SROOT .yy.partial.[pid]]
  file mkdir $live
  set l [pcall ase::saved_list $KEY]
  set names {} ; foreach x $l { lappend names [dg $x name] }
  check {SVR18c a dead .partial is swept, a dead .old with a valid meta and no folder is restored, a live one is left} \
    [list [file exists $pz] [file isdirectory [file join $SROOT rec]] [file exists $oldp] \
          [file exists $live] [expr {{rec} in $names}]] {0 1 0 1 1}
  file delete -force $live
}
group SVR18d {
  rename ::ase::saved_df_kb ::svr18d_real_df
  proc ::ase::saved_df_kb {dir} { return 1 }
  set r [pcall ase::saved_save $KEY space18 {} {} 0]
  proc ::ase::saved_df_kb {dir} { return {} }
  set s [pcall ase::saved_save $KEY nodf18 {} {} 0]
  rename ::ase::saved_df_kb {}
  rename ::svr18d_real_df ::ase::saved_df_kb
  check {SVR18d too little space refuses with the sentence; df unavailable still saves} \
    [list [dg $r ok] [dg $r msg] [file exists [file join $SROOT space18]] [dg $s ok]] \
    [list 0 [ase::ui::lbl_rsave_space] 0 1]
}
group SVR19 {
  ## metas planted with `saved` opposite to alphabetical AND creation order
  set k L/tb/s19
  set d19 [file join $scratch run19]
  mkrun $d19 1
  mksession $k $d19
  set root [file join $d19 saved L tb]
  set i 0
  foreach {nm sv} {aa 300 bb 200 cc 100} {
    set r [pcall ase::saved_save $k $nm {} {} 0]
    set m [pcall ase::saved_meta [dg $r dir]]
    dict set m saved [expr {$sv}]
    ase::saved_write_meta [file join [dg $r dir] result.meta] $m
  }
  ## then make creation order oppose: rewrite so cc is newest
  foreach {nm sv} {aa 100 cc 300} {
    set m [pcall ase::saved_meta [file join $root $nm]]
    dict set m saved $sv
    ase::saved_write_meta [file join $root $nm result.meta] $m
  }
  file mkdir [file join $root .hidden]
  file mkdir [file join $root nometa]
  set w [file join $root wrongfolder]
  file copy [file join $root bb] $w
  catch {file link -symbolic [file join $root alink] [file join $root bb]}
  set names {} ; foreach x [pcall ase::saved_list $k] { lappend names [dg $x name] }
  check {SVR19 the list ignores dot-folders, meta-less, wrong-folder metas and symlinks, newest saved first} \
    $names {cc bb aa}
}

# =============================================================================
# SVR20-SVR24b: the run never touches a saved copy; the readers follow the view
# =============================================================================
## a stand-in simulator that exits 0 at once (no ngspice needed)
set SBIN [file join $scratch bin]
wr [file join $SBIN svrsim] "#!/bin/sh\nexit 0\n" 0755
catch {ase::sim_register svrstub [file join $SBIN svrsim]}
catch {ase::sim_select svrstub}
proc drive_run {key} {
  set st [ase::session_state $key]
  dict set st sim_entry {name svrstub}
  set nl [file join [ase::state_get $st rundir] tb.spice]
  wr $nl "* svr\nR1 out 0 1k\nV1 out 0 1\n.end\n"
  set rc [catch {ase::run_deck $st $nl} id]
  if {!$rc} { catch {ase::wait $id} }
  return [list $rc $id]
}
group SVR20 {
  set before [tree [file join $LIVE saved]]
  set r [drive_run $KEY]
  check {SVR20 a run (stub simulator) leaves the saved results byte-identical} \
    [list [lindex $r 0] [expr {[tree [file join $LIVE saved]] eq $before}] \
          [expr {[llength $before] > 10}]] {0 1 1}
  ## the cleanup deletes NAMED files only: no -force, no glob, in run_deck
  set body [info body ase::run_deck]
  set bad 0
  foreach l [split $body "\n"] {
    if {[regexp {^\s*#} $l]} continue
    if {[regexp {file delete} $l] && ([regexp {\-force} $l] || [regexp {glob} $l])} { incr bad }
  }
  check {SVR20 run_deck's pre-run cleanup never deletes with -force or a glob} $bad 0
}
group SVR20b {
  set v1 [pcall ase::rundir_validate [file join $SROOT TT_27C]]
  set v2 [pcall ase::rundir_validate [file join $SROOT TT_27C sub]]
  set v3 [pcall ase::rundir_validate [file join $scratch fine20b]]
  check {SVR20b the run-directory door refuses a saved result and a path inside one} \
    [list [lindex $v1 0] [lindex $v1 2] [lindex $v2 0] [lindex $v3 0]] \
    [list refuse [ase::ui::lbl_rundir_in_saved] refuse ok]
}
group SVR20c {
  set st [ase::session_state $KEY]
  set new [pcall ase::rundir_set $st [file join $scratch moved20c]]
  set st2 $st ; dict set st2 results_dir /x
  set new2 [pcall ase::rundir_set $st2 [file join $scratch moved20c]]
  check {SVR20c moving the run directory pins results_dir to the old default when it holds saved results} \
    [list [ase::state_get $new results_dir] [ase::state_get $new2 results_dir]] \
    [list [file join $LIVE saved] /x]
}
group SVR21 {
  ## under a saved view, a write door replaces the LIVE files and not the saved ones
  set sv [file join $SROOT TT_27C]
  ase::result_sel_note $KEY [file join $sv tb_ase.raw]
  set before [tree $sv]
  set r [drive_run $KEY]
  set livedeck [file join $LIVE tb_ase.spice]
  set rsdir [ase::state_get [ase::result_state $KEY] rundir]
  check {SVR21 under a saved view the run writes the live directory and leaves the saved folder untouched} \
    [list [lindex $r 0] [expr {[tree $sv] eq $before}] [file isfile $livedeck] \
          [string match {*R1 out 0 1k*} [slurp $livedeck]] $rsdir] \
    [list 0 1 1 1 $sv]
  ase::result_sel_note $KEY {}
  ## the stub wrote no results: put the second run back as the live one
  foreach f [glob -directory $RUN2 -tails * .*] {
    if {$f in {. ..}} continue
    file copy -force [file join $RUN2 $f] [file join $LIVE $f]
  }
}
group SVR22 {
  set sv [file join $SROOT TT_27C]
  ase::result_sel_note $KEY [file join $sv tb_ase.raw]
  set a [ase::result_state $KEY]
  set b [ase::session_state $KEY]
  dict unset a rundir ; dict unset b rundir
  set same [expr {$a eq $b}]
  ase::result_sel_note $KEY [file join $SROOT nometa_x tb_ase.raw]
  set m1 [pcall ase::result_view $KEY]
  ase::result_sel_note $KEY [file join $LIVE tb_ase.raw]
  set m2 [pcall ase::result_view $KEY]
  ## other-design meta
  set fo [file join $scratch other22 o]
  file mkdir $fo
  wr [file join $fo result.meta] [dict create format 1 folder o name o cell tb design {Z tb schematic}]
  ase::result_sel_note $KEY [file join $fo tb_ase.raw]
  set m3 [pcall ase::result_view $KEY]
  ase::result_sel_note $KEY {}
  check {SVR22 result_state swaps only rundir; a meta-less, live or other-design path is no saved view} \
    [list $same $m1 $m2 $m3] {1 {} {} {}}
}
group SVR22b {
  set k L/tb/s22b
  set d [file join $scratch run22b]
  mkrun $d 1
  mksession $k $d
  set r [pcall ase::saved_save $k gone {} {} 0]
  set g [dg $r dir]
  ase::result_sel_note $k [file join $g tb_ase.raw]
  file delete -force $g
  foreach p {ase::last_rawfile ase::has_results ase::results_stale ase::run_failed
             ase::last_vcdfiles ase::result_state ase::ui::results_from_disk
             ase::ui::meas_ran ase::ui::conv_logtext ase::ui::conv_netlist_text
             ase::result_plotmap_state} {
    pcall $p $k
  }
  check {SVR22b a deleted saved folder is not recreated by any reader} [file exists $g] 0
}
group SVR23 {
  set k L/tb/s23
  set d [file join $scratch run23]
  mkrun $d 1
  mksession $k $d
  set r [pcall ase::saved_save $k first {} {} 0]
  set sv [dg $r dir]
  ## the live run becomes run 2 (failed: exit 1), and its sidecars differ
  foreach f [glob -directory $RUN2 -tails * .*] {
    if {$f in {. ..}} continue
    file copy -force [file join $RUN2 $f] [file join $d $f]
  }
  wr [file join $d tb_ase.log] "run v2\n\n=== exit 1 after 1.00 s ===\n"
  proc readers {k} {
    return [list [file dirname [pcall ase::last_rawfile $k]] [pcall ase::has_results $k] \
                 [pcall ase::results_stale $k] [expr {[pcall ase::run_failed $k] ne {}}] \
                 [llength [pcall ase::last_vcdfiles $k]] [pcall ase::ui::results_from_disk $k] \
                 [pcall ase::ui::meas_ran $k] \
                 [string trim [pcall ase::ui::conv_logtext $k]] \
                 [string trim [pcall ase::ui::conv_netlist_text $k]] \
                 [slurp [ase::meas_path [ase::result_state $k]]]]
  }
  set live [readers $k]
  set fv [ase::ui::lbl_run_failed_value [dict create exit 1]]
  ase::result_sel_note $k [file join $sv tb_ase.raw]
  set saved [readers $k]
  ase::result_sel_note $k {}
  check {SVR23 live view: every reader answers the live run} $live \
    [list [file normalize $d] 1 0 1 2 [list VO $fv] 1 "run v2\n\n=== exit 1 after 1.00 s ===" \
          {fresh tb.spice v2} "ASE-MEAS\nm1 = 2.5\n"]
  check {SVR23 saved view: every reader answers the saved run} $saved \
    [list $sv 1 0 0 2 {VO 1.000000e+01} 1 "run v1\n\n=== exit 0 after 1.00 s ===" \
          {fresh tb.spice v1} "ASE-MEAS\nm1 = 1.5\n"]
}
group SVR24 {
  set sv [file join $SROOT TT_27C]
  ase::result_sel_note $KEY [file join $sv tb_ase.raw]
  set ps [pcall ase::result_plotmap_state $KEY]
  ase::result_sel_note $KEY {}
  set lp [pcall ase::plotmap_path [ase::session_state $KEY]]
  check {SVR24 under a saved view the plotmap is read against the saved run state, rundir swapped to the saved folder} \
    [list [ase::state_get $ps rundir] [ase::state_get $ps temperature] \
          [expr {[slurp [ase::plotmap_path $ps]] ne {ZZNOFILE}}] \
          [expr {[ase::plotmap_path $ps] ne $lp}]] \
    [list $sv 85 1 1]
}
group SVR24b {
  set d [file join $SROOT TT_27C]
  set m [pcall ase::saved_meta $d]
  dict set m state_source current
  set nd [file join $SROOT cur24b]
  file copy $d $nd
  dict set m folder cur24b ; dict set m name cur24b
  ase::saved_write_meta [file join $nd result.meta] $m
  ase::result_sel_note $KEY [file join $nd tb_ase.raw]
  set ps [pcall ase::result_plotmap_state $KEY]
  ase::result_sel_note $KEY {}
  check {SVR24b a saved result whose run state was synthesised has no plotmap mapping} $ps {}
}
group SVR25 {
  set sv [file join $SROOT TT_27C]
  xschem raw clear
  xschem raw_read [file join $LIVE tb_ase.raw] tran
  set r [pcall results::select [file join $sv tb_ase.raw] op \
           [dict create host none rundir $sv derived [ase::live_rawfile $KEY]]]
  set n [llength [pcall results::list]]
  check {SVR25 the R910 select binds the saved raw ok (not stale) and keeps the live slot} \
    [list [dg $r status] [dg $r how] $n] {ok read 2}
  xschem raw clear
}
group SVR26 {
  set sv [file join $SROOT TT_27C]
  check {SVR26 a saved raw labels as its name and type} \
    [list [pcall ase::saved_name_of [file join $sv tb_ase.raw]] \
          [pcall results::_label [file join $sv tb_ase.raw] tran] \
          [pcall results::_label [file join $LIVE tb_ase.raw] tran]] \
    {tt_27c {tt_27c (tran)} {tb_ase.raw (tran)}}
}
group SVR27 {
  ## the same saved raw through the result-recording door, spelled four ways
  set sv [file join $SROOT TT_27C]
  set out {}
  foreach p [list [file join $sv tb_ase.raw] [file join $sv . tb_ase.raw] \
                  [file join $sv .. TT_27C tb_ase.raw] "$sv//tb_ase.raw"] {
    ase::result_sel_note $KEY {}
    pcall results::persist $p op [dict create token $KEY]
    lappend out [pcall ase::result_view $KEY]
  }
  ase::result_sel_note $KEY {}
  check {SVR27 every spelling of one saved raw through the recording door gives the same view} \
    [lsort -unique $out] [list $sv]
}
group SVR27b {
  ## the launch doors, derived from the callers of ase::run / ase::run_existing
  ## / the campaign start in ase_window.tcl; each reaches result_view_reset
  set src [slurp [file join $repo src ase_window.tcl]]
  set doors {}
  foreach l [split $src "\n"] {
    if {[regexp {^proc (ase::ui::\S+)} $l -> cur]} { continue }
  }
  set procs {}
  foreach p [info procs ::ase::ui::*] {
    set b [info body $p]
    if {[regexp {ase::run(_existing)? \[ase::session_state} $b] ||
        [regexp {ase::campaign_run } $b]} { lappend procs $p }
  }
  set ok {}
  foreach p $procs {
    set b [info body $p]
    lappend ok [expr {[string first ase::result_view_reset $b] >= 0 ||
                      [string first ase::ui::run_started $b] >= 0}]
  }
  check {SVR27b every launch door (derived) resets the view, directly or through run_started} \
    [list [expr {[llength $procs] >= 3}] [lsort -unique $ok] \
          [expr {[string first ase::result_view_reset [info body ase::ui::run_started]] >= 0}]] \
    {1 1 1}
}
group SVR27c {
  set sv [file join $SROOT TT_27C]
  ase::result_sel_note $KEY [file join $sv tb_ase.raw]
  rename ::ase::ui::run_busy ::svr27c_busy
  proc ::ase::ui::run_busy {key} { return /busy }
  rename ::ase::run_refuse ::svr27c_refuse
  proc ::ase::run_refuse {lk} { return 0 }
  pcall ase::ui::do_run_existing $KEY
  set a [pcall ase::result_view $KEY]
  rename ::ase::ui::run_busy {}
  rename ::svr27c_busy ::ase::ui::run_busy
  rename ::ase::run_refuse {}
  rename ::svr27c_refuse ::ase::run_refuse
  rename ::ase::run_existing ::svr27c_rx
  proc ::ase::run_existing {st cb} { return 4242 }
  rename ::ase::ui::run_started ::svr27c_started
  proc ::ase::ui::run_started {key id} { ase::result_view_reset $key }
  pcall ase::ui::do_run_existing $KEY
  set b [pcall ase::result_view $KEY]
  rename ::ase::run_existing {}
  rename ::svr27c_rx ::ase::run_existing
  rename ::ase::ui::run_started {}
  rename ::svr27c_started ::ase::ui::run_started
  check {SVR27c a refused Run keeps the saved view; a launch that succeeded returns to the live run} \
    [list $a $b] [list $sv {}]
}
group SVR27d {
  set sv [file join $SROOT TT_27C]
  ase::result_sel_note $KEY [file join $sv tb_ase.raw]
  set rows [pcall ase::ui::rsel_saved_rows $KEY]
  set last [lindex $rows 0]
  check {SVR27d under a saved view the Last run row binds the LIVE raw} \
    [list [dg $last kind] [dg $last path] [pcall ase::last_rawfile $KEY]] \
    [list lastrun [file join $LIVE tb_ase.raw] [file join $sv tb_ase.raw]]
  ase::result_sel_note $KEY {}
}
group SVR28 {
  ## Save State with a saved selection and the viewer CLOSED, then reload
  set sv [file join $SROOT TT_27C]
  set k L/tb/s28
  set p [mksession $k $LIVE]
  ase::result_sel_note $k [file join $sv tb_ase.raw]
  pcall ase::ui::viewer_snapshot $k
  ase::session_save $k
  ase::session_close $k
  ase::session_open $k $p
  set a [pcall ase::result_view $k]
  set lr [file dirname [pcall ase::last_rawfile $k]]
  ## back to the live run, saved, reloaded
  ase::result_view_reset $k
  pcall ase::ui::viewer_snapshot $k
  ase::session_save $k
  ase::session_close $k
  ase::session_open $k $p
  set b [pcall ase::result_view $k]
  ## a deleted folder falls back
  set st [ase::session_state $k]
  dict set st viewer [dict create rawfile [file join $SROOT nosuch tb_ase.raw]]
  ase::session_update $k $st
  set c [pcall ase::result_view $k]
  check {SVR28 Save State with the viewer closed keeps the saved view across a reload, readers follow, Last run comes back, a missing folder falls back} \
    [list $a $lr $b $c] [list $sv $sv {} {}]
}
group SVR29 {
  set k L/tb/s29
  set d [file join $scratch run29]
  mkrun $d 1
  mksession $k $d
  pcall ase::saved_save $k del1 {} {} 0
  pcall ase::saved_save $k keep1 {} {} 0
  set root [file join $d saved L tb]
  ## del1 made OLDER than keep1, so "the newest" and "the named one" differ
  set m [pcall ase::saved_meta [file join $root del1]]
  dict set m saved [expr {[dg $m saved 0] - 100}]
  ase::saved_write_meta [file join $root del1 result.meta] $m
  set r [pcall ase::saved_delete $k {del1} {}]
  set lk [file join $root alink]
  catch {file link -symbolic $lk [file join $root keep1]}
  set r2 [pcall ase::saved_delete $k {alink nometa} {}]
  check {SVR29 Delete removes a saved result; a symlink, a meta-less name and an unknown name are refused and the target survives} \
    [list [dg $r ok] [dg $r deleted] [dg $r msg] [file exists [file join $root del1]] \
          [dg $r2 ok] [llength [dg $r2 refused]] [file isdirectory [file join $root keep1]]] \
    [list 1 del1 [ase::ui::lbl_rdel_done 1] 0 0 2 1]
  check {SVR29 Delete removes the NAMED result, not the newest} \
    [list [file isdirectory [file join $root del1]] [file isdirectory [file join $root keep1]]] {0 1}
}
group SVR29b {
  set k L/tb/s29
  set d [file join $scratch run29]
  set root [file join $d saved L tb]
  ase::result_sel_note $k [file join $root keep1 tb_ase.raw]
  set v0 [pcall ase::result_view $k]
  xschem raw clear
  xschem raw read [file join $root keep1 tb_ase.raw] tran
  set in0 0
  foreach row [pcall results::list] { if {[dg $row path] eq [file join $root keep1 tb_ase.raw]} { set in0 1 } }
  set ::echoes {}
  set r [pcall ase::saved_delete $k {keep1} {}]
  set in1 0
  foreach row [pcall results::list] { if {[dg $row path] eq [file join $root keep1 tb_ase.raw]} { set in1 1 } }
  xschem raw clear
  check {SVR29b deleting the result in view is allowed and the view falls back to the live run} \
    [list [expr {$v0 ne {}}] [dg $r ok] [pcall ase::result_view $k] [file exists [file join $root keep1]]] \
    {1 1 {} 0}
  check {SVR29b ... the window repaints (it echoes the live run) and the deleted result's loaded slot is dropped} \
    [list [expr {[ase::ui::lbl_results_live] in $::echoes}] $in0 $in1] {1 1 0}
}
group SVR29c {
  set root [file join $scratch c29 r]
  file mkdir $root
  ## a valid saved result planted at every escape target
  foreach t [list [file join $scratch c29 x] [file join $scratch c29 b] [file join $scratch c29 abs] \
                  [file join $root .x.partial.1]] {
    file mkdir $t
    wr [file join $t result.meta] [dict create format 1 folder [file tail $t] name n]
  }
  set out {}
  foreach f [list ../x a/../../b [file join $scratch c29 abs] .x.partial.1 {} . ..] {
    lappend out [lindex [pcall ase::saved_target_ok $root $f] 0]
  }
  set d [pcall ase::saved_delete $KEY [list ../x a/../../b [file join $scratch c29 abs]] {}]
  check {SVR29c path-shaped and dot names are refused by saved_target_ok and unreachable through saved_delete names; targets intact} \
    [list [lsort -unique $out] [dg $d deleted] [file isdirectory [file join $scratch c29 x]] \
          [file isdirectory [file join $scratch c29 b]] [file isdirectory [file join $scratch c29 abs]]] \
    {0 {} 1 1 1}
}
group SVR30 {
  set k L/tb/s30
  set d [file join $scratch run30]
  mkrun $d 1
  wr [file join $d tb_ase.log] "boom\n\n=== exit 1 after 1.00 s ===\n"
  mksession $k $d
  set r [pcall ase::saved_save $k failed1 {} {} 0]
  set m [pcall ase::saved_meta [dg $r dir]]
  ase::result_sel_note $k [file join [dg $r dir] tb_ase.raw]
  set f [pcall ase::run_failed $k]
  set v [pcall ase::ui::results_from_disk $k]
  ase::result_sel_note $k {}
  check {SVR30 a failed run with a raw is saved with its exit code, and selecting it says the run failed} \
    [list [dg $r ok] [dg $m exit] [dg $f exit] [string match *fail* [dg $v VO]]] {1 1 1 1}
}
group SVR30b {
  set k L/tb/s30b
  set d [file join $scratch run30b]
  file mkdir $d
  wr [file join $d tb_ase.log] "stopped\n\n=== exit 9 after 1.00 s ===\n"
  wr [file join $d tb_ase.raw.ckpt] "ckpt\n"
  mksession $k $d
  set r [pcall ase::saved_save $k noraw1 {} {} 0]
  set m [pcall ase::saved_meta [dg $r dir]]
  ## an op-only raw selects by its types
  set d2 [file join $scratch run30c]
  file mkdir $d2
  mkraw_op [file join $d2 tb_ase.raw] 3.0
  set k2 L/tb/s30c
  mksession $k2 $d2 L tb {analyses {{type tran enabled 1}}}
  set r2 [pcall ase::saved_save $k2 oponly {} {} 0]
  set m2 [pcall ase::saved_meta [dg $r2 dir]]
  check {SVR30b a run with no raw (log + checkpoint) is saved; an op-only raw records viewtype op from its types} \
    [list [dg $r ok] [dg $m exit] [lsort [dg $m files]] [dg $m2 types] [dg $m2 viewtype]] \
    {1 9 {tb_ase.log tb_ase.raw.ckpt tb_ase.runstate} op op}
}
group SVR31 {
  set sv [file join $SROOT TT_27C]
  ase::result_sel_note $KEY [file join $sv tb_ase.raw]
  set r [pcall ase::saved_save $KEY copyofsaved {} {} 0]
  ase::result_sel_note $KEY {}
  set m [pcall ase::saved_meta [dg $r dir]]
  check {SVR31 Save of a viewed saved result copies the SAVED folder (Save As)} \
    [list [dg $r ok] [dg $m source] \
          [expr {[slurp [file join [dg $r dir] tb_ase.raw]] eq [slurp [file join $sv tb_ase.raw]]}]] \
    [list 1 $sv 1]
}
group SVR32 {
  set k L/tb/s32
  set d [file join $scratch run32]
  file mkdir $d
  mksession $k $d
  wr [file join $d tb_ase.runstate] "stale {}\n"
  set r [drive_run $k]
  set rs [slurp [file join $d tb_ase.runstate]]
  set st [ase::session_state $k] ; dict set st sim_entry {name svrstub}
  ## none at all -> state_source current
  set d2 [file join $scratch run32b]
  file mkdir $d2
  mkraw [file join $d2 tb_ase.raw] 2.0
  mksession L/tb/s32b $d2
  set r2 [pcall ase::saved_save L/tb/s32b norunstate {} {} 0]
  check {SVR32 run_deck writes the rendered state beside the deck (replacing the old one); with none, Save records state_source current} \
    [list [lindex $r 0] [expr {[string trim $rs] eq [string trim [ase::state_serialize $st]]}] \
          [dg [pcall ase::saved_meta [dg $r2 dir]] state_source]] {0 1 current}
}
group SVR33 {
  ## every sentence the pure layer can return is an lbl_* proc's
  set src [slurp [file join $repo src ase.tcl]]
  set used [regexp -all -inline {ase::saved_say (r[a-z_]+)} $src]
  set names {}
  foreach {m n} $used { lappend names $n }
  set names [lsort -unique $names]
  set missing {}
  foreach n $names { if {[info commands ::ase::ui::lbl_$n] eq {}} { lappend missing $n } }
  ## no inline sentence in saved_save/saved_delete: every `msg` set from saved_say
  ## DERIVED population: every ase::saved_* proc; a sentence-bearing line is
  ## one that sets `msg`, returns a refusal pair or records a refusal, and it
  ## is inline when it carries a quoted word instead of going through saved_say
  set inline 0
  set scanned 0
  foreach p [info procs ::ase::saved_*] {
    incr scanned
    foreach l [split [info body $p] "\n"] {
      if {[regexp {^\s*#} $l]} { continue }
      if {![regexp {dict set r msg|list 0 |lappend refused} $l]} { continue }
      if {[regexp {saved_say} $l]} { continue }
      if {[regexp {"[^"]*[A-Za-z]{2}[^"]*"} $l]} { incr inline }
    }
  }
  check {SVR33 every sentence key the pure layer uses has an lbl_* proc, and none is inline} \
    [list [expr {[llength $names] >= 12}] $missing $inline [expr {$scanned >= 20}]] {1 {} 0 1}
  check {SVR33 plurals are spelled for 1 and 3; echo sentences start with ase:} \
    [list [ase::ui::lbl_rdel_confirm 1] [ase::ui::lbl_rdel_confirm 3] [ase::ui::lbl_rdel_done 3] \
          [string match {ase: *} [ase::ui::lbl_results_live]] \
          [string match {ase: *} [ase::ui::lbl_results_view n d]] \
          [string match {ase: *} [ase::ui::lbl_rsave_pinned d]]] \
    {{Delete 1 saved result?} {Delete 3 saved results?} {Deleted 3 saved results.} 1 1 1}
}

# =============================================================================
# SVR-D1 / SVR-D2: the two derived classifications
# =============================================================================
group SVR-D1 {
  ## every proc in the five files that calls an artifact-path proc, classified.
  ## reader -> must reach result_state/last_rawfile (never session_state alone
  ## for artifact paths); writer -> must never reach result_state; neither ->
  ## run-completion/run-time readers of the live run, path definitions.
  set CLASS {
    ase::campaign_index_row neither  ase::ckpt_path neither  ase::ckpt_report neither
    ase::ckpt_tmp_path neither  ase::cosim_file neither  ase::cosim_load_map neither
    ase::cosim_save_map writer  ase::deck_file neither  ase::event_vcd_clear writer
    ase::event_vcd_files neither  ase::has_results reader  ase::last_rawfile reader
    ase::last_vcdfiles reader  ase::meas_path neither  ase::meas_read neither
    ase::op_report_missing neither  ase::plotmap_path neither  ase::reconcile_report neither
    ase::register_backend neither  ase::results_stale reader  ase::run writer
    ase::run_deck writer  ase::run_existing writer  ase::run_failed reader
    ase::run_lock_key writer  ase::stimuli_nvec neither  cosim_shim_verdict neither
    log_file neither  meas_block neither  predeck_file neither  predeck_write writer
    raw_file neither  render_deck writer  result_probe neither  result_probe_calc neither
    result_probe_raw neither  s2p_file neither  sp_export_lines writer
    ase::ui::annot_ensure_loaded reader  ase::ui::auto_plot reader  ase::ui::conv_logtext reader
    ase::ui::dp_finish reader  ase::ui::matrix_dialog reader  ase::ui::meas_ran reader
    ase::ui::run_finished neither  ase::ui::show_log neither  ase::ui::viewer_restore reader
    ase::saved_artifacts neither  ase::runstate_path neither  ase::saved_save_body neither
    ase::saved_runstate_raw neither  ase::live_rawfile listing
    ase::result_plotmap_state neither  ase::ui::meas_results_list reader
  }
  set pat {raw_file|log_file|plotmap_path|meas_path|deck_file|cosim_file|event_vcd_files|s2p_file|ckpt_path|last_rawfile|last_vcdfiles}
  set found {}
  foreach f {ase.tcl ase_window.tcl wave_viewer.tcl op_annot.tcl calculator.tcl} {
    set cur {}
    foreach l [split [slurp [file join $repo src $f]] "\n"] {
      if {[regexp {^\s*proc\s+(\S+)} $l -> p]} { set cur $p ; continue }
      if {[regexp {^\s*#} $l]} { continue }
      if {$cur ne {} && [regexp $pat $l] && $cur ni $found} { lappend found $cur }
    }
  }
  set uncl {} ; set wbad {} ; set rbad {}
  foreach p $found {
    if {![dict exists $CLASS $p]} { lappend uncl $p ; continue }
    set c [dict get $CLASS $p]
    set body {}
    catch {set body [info body ::$p]}
    if {$c eq {writer} && [string first result_state $body] >= 0} { lappend wbad $p }
    if {$c eq {reader} && $body ne {} &&
        [string first result_state $body] < 0 && [string first last_rawfile $body] < 0 &&
        [string first last_vcdfiles $body] < 0 && [string first has_results $body] < 0 &&
        [string first meas_ran $body] < 0} { lappend rbad $p }
  }
  check {SVR-D1 every artifact-path caller is classified; no writer reaches result_state; every reader follows the view (textual scan)} \
    [list [expr {[llength $found] >= 30}] $uncl $wbad $rbad] {1 {} {} {}}
  ## listing never reaches result_state (I-L)
  set lbad {}
  foreach p {ase::saved_root ase::saved_list ase::saved_default_base} {
    if {[string first result_state [info body $p]] >= 0} { lappend lbad $p }
  }
  check {SVR-D1 the listing procs never reach result_state (I-L)} $lbad {}
}
group SVR-D2 {
  ## the population: every file in a live run directory matching <cell>_ase*,
  ## <cell>.spice or .spiceinit, plus every ase::*_path proc taking a state
  set DECL {
    tb_ase.raw copy tb_ase.log copy tb_ase.plotmap copy tb_ase.meas copy
    tb_ase.spice copy tb_ase.runstate copy tb_ase.raw.ckpt copy tb_ase.effective copy
    tb_ase.cosim copy tb_ase_evt.vcd copy tb.spice fresh tb_ase.s2p fresh
    tb_ase_sp0.s2p fresh .spiceinit fresh tb_ase.opinfo fresh
    tb_ase_evtprobe.spice never tb_ase.raw.ckpt.tmp never
  }
  set pop {}
  foreach p [glob -nocomplain -tails -directory $RUN2 tb_ase* tb.spice .spiceinit] {
    lappend pop $p
  }
  set uncl {}
  foreach p $pop { if {![dict exists $DECL $p]} { lappend uncl $p } }
  set paths {}
  foreach p [info procs ::ase::*_path] {
    set a [info args $p]
    if {[lindex $a 0] eq {state}} { lappend paths [namespace tail $p] }
  }
  set PATHDECL {meas_path copy plotmap_path copy ckpt_path copy ckpt_tmp_path never
                effective_path copy runstate_path copy event_vcd_path copy
                facts_design_path never opstate_path never event_probe_path never
                campaign_deck_path never campaign_index_path never}
  set upath {}
  foreach p $paths { if {![dict exists $PATHDECL $p]} { lappend upath $p } }
  ## the declaration agrees with what Save actually copies
  set art [pcall ase::saved_artifacts [ase::session_state L/tb/s23]]
  set copied {}
  foreach e [dg $art copy] { lappend copied [lindex $e 1] }
  set disagree {}
  dict for {f c} $DECL {
    if {$c eq {copy} && $f ni $copied} { lappend disagree $f }
    if {$c eq {never} && $f in $copied} { lappend disagree $f }
  }
  check {SVR-D2 every run-directory artifact and every ase::*_path proc is classified, and Save honours the classification} \
    [list [expr {[llength $pop] >= 15}] $uncl $upath $disagree] {1 {} {} {}}
}

# =============================================================================
# SVR2b-SVR51: the hardening rows (issue 1666's verify round). Each names the
# defect or the sabotage it was built against; every one was re-run with that
# sabotage in place and reddened.
# =============================================================================
group SVR2b {
  ## the `_2, _3` loop: a listed name equal to the default (any case) pushes it on
  set k L/tb/s2b
  set d [file join $scratch run2b]
  mkrun $d 1
  mksession $k $d
  set d0 [pcall ase::saved_default_name $k]
  pcall ase::saved_save $k [string toupper $d0] {} {} 0
  set d1 [pcall ase::saved_default_name $k]
  pcall ase::saved_save $k $d1 {} {} 0
  set d2 [pcall ase::saved_default_name $k]
  check {SVR2b a default already taken (case-insensitively) becomes _2, then _3} \
    [list [expr {$d0 ne {}}] $d1 $d2] [list 1 ${d0}_2 ${d0}_3]
}
group SVR12b {
  ## Run on an existing netlist: the deck is NEW, `<cell>.spice` is OLD and is
  ## what was simulated -- it must be copied, not skipped as stale
  set k L/tb/s12b
  set d [file join $scratch run12b]
  mkrun $d 1
  file mtime [file join $d tb.spice] [expr {[file mtime [file join $d tb_ase.spice]] - 3600}]
  mksession $k $d
  set r [pcall ase::saved_save $k rx {} {} 0]
  set m [pcall ase::saved_meta [dg $r dir]]
  check {SVR12b a netlist OLDER than the deck (Run on an existing netlist) is copied, byte-equal} \
    [list [dg $r ok] [file isfile [file join [dg $r dir] tb.spice]] \
          [expr {[slurp [file join [dg $r dir] tb.spice]] eq [slurp [file join $d tb.spice]]}] \
          [lsearch -index 0 -all -inline [dg $m skipped] tb.spice]] {1 1 1 {}}
}
group SVR13b {
  ## two co-simulation blocks whose VCDs share one file name in two directories
  set k L/tb/s13b
  set d [file join $scratch run13b]
  mkrun $d 1
  set va [wr [file join $d blka ctr.vcd] "\$date A \$end\n#0\n"]
  set vb [wr [file join $d blkb ctr.vcd] "\$date B-longer \$end\n#0\n"]
  set t [file mtime [file join $d tb_ase.raw]]
  file mtime $va $t ; file mtime $vb $t
  set cf [wr [file join $d tb_ase.cosim] \
            "# map\n[list [dict create model a vcd $va multi 0]]\n[list [dict create model b vcd $vb multi 0]]\n"]
  file mtime $cf $t
  file delete [file join $d ctr.vcd]
  mksession $k $d
  set r [pcall ase::saved_save $k two {} {} 0]
  set st [ase::session_state $k] ; dict set st rundir [dg $r dir]
  set map [pcall ase::cosim_load_map $st]
  set got {}
  foreach e $map {
    set v [dg $e vcd]
    lappend got [list [dg $e model] [expr {[file dirname $v] eq [dg $r dir]}] [string trim [slurp $v]]]
  }
  check {SVR13b two VCDs with one file name each keep their OWN copy, and the saved map points each block at it} \
    [list [dg $r ok] [llength $map] $got \
          [expr {[dg [lindex $map 0] vcd] ne [dg [lindex $map 1] vcd]}]] \
    [list 1 2 [list [list a 1 "\$date A \$end\n#0"] [list b 1 "\$date B-longer \$end\n#0"]] 1]
}
group SVR14b {
  ## a cell spelled with an uppercase letter: the dump is handed to the
  ## simulator lowercased, and lands in the saved folder CASE-KEPT
  set k L/Tb/s14b
  set d [file join $scratch run14b]
  mkrun $d 1 Tb
  mksession $k $d L Tb
  set r [pcall ase::saved_save $k up {} {} 0]
  set have [lsort [glob -nocomplain -tails -directory [dg $r dir] *.opinfo]]
  check {SVR14b an uppercase cell's OP dump is saved as <Cell>_ase.opinfo (the raw's rootname), not the lowercased source tail} \
    [list [dg $r ok] $have] [list 1 Tb_ase.opinfo]
}
group SVR17c {
  ## an overwrite drops the registry slot of the folder it replaced
  set sv [file join $SROOT TT_27C]
  xschem raw clear
  xschem raw read [file join $sv tb_ase.raw] tran
  set in0 0
  foreach row [pcall results::list] { if {[dg $row path] eq [file join $sv tb_ase.raw]} { set in0 1 } }
  set c [pcall ase::saved_save $KEY TT_27C {} {} 1]
  set in1 0
  foreach row [pcall results::list] { if {[dg $row path] eq [file join $sv tb_ase.raw]} { set in1 1 } }
  xschem raw clear
  check {SVR17c a confirmed overwrite drops the replaced folder's loaded slot} \
    [list $in0 [dg $c how] $in1] {1 overwritten 0}
}
group SVR18e {
  set k L/tb/s18e
  set d [file join $scratch run18e]
  mkrun $d 1
  mksession $k $d
  set root [file join $d saved L tb]
  pcall ase::saved_save $k ow {} {} 0
  set old [slurp [file join $root ow tb_ase.raw]]
  ## the SECOND rename (staging into place) fails: the old result comes back
  rename ::ase::saved_rename ::svr18e_real_rename
  proc ::ase::saved_rename {a b} {
    if {[string match {*.partial.*} $a]} { error "rename refused" }
    ::svr18e_real_rename $a $b
  }
  set o [pcall ase::saved_save $k ow {} {} 1]
  rename ::ase::saved_rename {}
  rename ::svr18e_real_rename ::ase::saved_rename
  set hidden [llength [glob -nocomplain -types {d hidden} -directory $root .*.partial.* .*.old.*]]
  check {SVR18e the staged copy failing to move into place puts the old result back, intact and listed} \
    [list [dg $o ok] [file isdirectory [file join $root ow]] \
          [expr {[slurp [file join $root ow tb_ase.raw]] eq $old}] $hidden \
          [dg [pcall ase::saved_find $k ow] name]] {0 1 1 0 ow}
  ## the removal of the replaced copy failing leaves no `.old` behind ...
  rename ::ase::saved_rmtree ::svr18e_real_rm
  proc ::ase::saved_rmtree {p} { error "rm refused" }
  set o2 [pcall ase::saved_save $k ow {} {} 1]
  rename ::ase::saved_rmtree {}
  rename ::svr18e_real_rm ::ase::saved_rmtree
  set olds [llength [glob -nocomplain -types {d hidden} -directory $root .*.old.*]]
  ## ... and an `.old` another LIVE process left (the sweep must not touch it
  ## while that process runs, and would rename it back over the deleted folder
  ## once it exits) goes with the result it belonged to
  set oldp [file join $root .ow.old.1]
  file copy [file join $root ow] $oldp
  set live1 [file exists $oldp]
  set dl [pcall ase::saved_delete $k ow {}]
  set after [pcall ase::saved_list $k]
  set names {} ; foreach x $after { lappend names [dg $x name] }
  check {SVR18e a failed cleanup of the replaced copy leaves no .old; Delete also removes a live process's .old of that result, so no sweep can restore it} \
    [list [dg $o2 ok] $olds $live1 [file isdirectory /proc/1] [dg $dl deleted] [expr {{ow} in $names}] \
          [file exists $oldp] [file exists [file join $root ow]]] {1 0 1 1 ow 0 0 0}
  foreach p [glob -nocomplain -types {d hidden} -directory $root .*.partial.*] { file delete -force $p }
}
group SVR23b {
  ## three readers the SVR23 table cannot see, each driven through a stub that
  ## reports the run directory it was handed
  set k L/tb/s23
  set sv [file join $scratch run23 saved L tb first]
  ase::result_sel_note $k [file join $sv tb_ase.raw]
  rename ::ase::meas_results ::svr23b_mr
  proc ::ase::meas_results {sim state {text {}}} { return [dict get $state rundir] }
  rename ::ase::ui::meas_state ::svr23b_ms
  proc ::ase::ui::meas_state {key} { return [ase::session_state $key] }
  set mr [pcall ase::ui::meas_results_list $k]
  rename ::ase::meas_results {} ; rename ::svr23b_mr ::ase::meas_results
  rename ::ase::ui::meas_state {} ; rename ::svr23b_ms ::ase::ui::meas_state
  rename ::ase::stimuli_nvec ::svr23b_nv
  proc ::ase::stimuli_nvec {sim state idx} { return [list [dict get $state rundir] [dict get $state temperature]] }
  rename ::ase::ui::chana_row_idx ::svr23b_ri
  proc ::ase::ui::chana_row_idx {key type} { return 0 }
  set nv [pcall ase::ui::nz_nvec $k ngspice noise]
  rename ::ase::stimuli_nvec {} ; rename ::svr23b_nv ::ase::stimuli_nvec
  rename ::ase::ui::chana_row_idx {} ; rename ::svr23b_ri ::ase::ui::chana_row_idx
  ## the LIVE run is stopped; the saved one ran and failed (exit 1)
  set dfail [file join $scratch run23f]
  mkrun $dfail 1
  wr [file join $dfail tb_ase.log] "boom\n\n=== exit 1 after 1.00 s ===\n"
  mksession L/tb/s23f $dfail
  set rf [pcall ase::saved_save L/tb/s23f failedsaved {} {} 0]
  ase::session_setattr L/tb/s23f stopped 1
  ase::result_sel_note L/tb/s23f [file join [dg $rf dir] tb_ase.raw]
  set f [pcall ase::run_failed L/tb/s23f]
  ase::result_sel_note L/tb/s23f {}
  set flive [pcall ase::run_failed L/tb/s23f]
  ase::session_setattr L/tb/s23f stopped 0
  ase::result_sel_note $k {}
  check {SVR23b under a saved view: the measurement sidecar, the noise plotmap (saved run state) and the failure verdict are the saved run's, not the live one's} \
    [list $mr $nv [dg $f exit] $flive] [list $sv [list $sv 27] 1 {}]
}
group SVR25b {
  set sv [file join $SROOT TT_27C tb_ase.raw]
  set o [pcall ase::ui::rsel_saved_opts $KEY saved $sv [dict create netlist /x/tb.spice rundir $LIVE keep 1]]
  set l [pcall ase::ui::rsel_saved_opts $KEY lastrun $sv [dict create netlist /x/tb.spice]]
  check {SVR25b a saved row binds with no netlist, its own folder as rundir and the LIVE raw as fallback; other rows are untouched} \
    [list [dict exists $o netlist] [dg $o rundir] [dg $o derived] [dg $o keep] $l] \
    [list 0 [file dirname $sv] [file join $LIVE tb_ase.raw] 1 [dict create netlist /x/tb.spice]]
}
group SVR27e {
  ## the viewer's own select doors (results::persist with a token) repaint the
  ## session at idle when the view MOVED, and only then
  set sv [file join $SROOT TT_27C]
  rename ::ase::ui::result_view_changed ::svr27e_real
  set ::svr27e_n 0
  proc ::ase::ui::result_view_changed {key} { incr ::svr27e_n ; ::svr27e_real $key }
  ase::result_sel_note $KEY {}
  ase::ui::result_view_changed $KEY
  update
  set ::svr27e_n 0
  pcall results::persist [file join $sv tb_ase.raw] op [dict create token $KEY]
  set n0 $::svr27e_n
  update
  set n1 $::svr27e_n
  pcall results::persist [file join $sv tb_ase.raw] op [dict create token $KEY]
  update
  set n2 $::svr27e_n
  ase::result_sel_note $KEY {}
  ase::ui::result_view_changed $KEY
  update
  rename ::ase::ui::result_view_changed {}
  rename ::svr27e_real ::ase::ui::result_view_changed
  check {SVR27e a select through the recording door repaints once at idle; the same selection again does not} \
    [list $n0 $n1 $n2] {0 1 1}
}
group SVR27f {
  ## a saved result selected WHILE a run ran: the finished run takes the view
  set sv [file join $SROOT TT_27C]
  ase::result_sel_note $KEY [file join $sv tb_ase.raw]
  set v0 [pcall ase::result_view $KEY]
  pcall ase::ui::run_finished $KEY
  set v1 [pcall ase::result_view $KEY]
  ase::result_sel_note $KEY {}
  catch {after cancel [list ase::ui::auto_plot_idle $KEY]}
  catch {after cancel [list ase::ui::annot_refresh_idle $KEY]}
  check {SVR27f a finished run returns the view to the live run} [list $v0 $v1] [list $sv {}]
}
group SVR28b {
  set sv [file join $SROOT TT_27C]
  set k L/tb/s28b
  set p [mksession $k $LIVE]
  ase::result_sel_note $k [file join $sv tb_ase.raw]
  set a [lindex [ase::result_sel_get $k] 0]
  ase::session_close $k
  set b [lindex [ase::result_sel_get $k] 0]
  ## a record left by anything else is dropped when the session (re)opens
  dict set ::ase::resultsel $k [file join $sv tb_ase.raw]
  ase::session_open $k $p
  set c [lindex [ase::result_sel_get $k] 0]
  set v [pcall ase::result_view $k]
  ase::session_close $k
  check {SVR28b closing a session forgets its selection, and opening one starts from its state} \
    [list $a $b $c $v] {1 0 0 {}}
}
group SVR29d {
  ## a name is matched WHOLE: `kk` never reaches `kk_27C`
  set k L/tb/s29d
  set d [file join $scratch run29d]
  mkrun $d 1
  mksession $k $d
  pcall ase::saved_save $k kk_27C {} {} 0
  pcall ase::saved_save $k kk {} {} 0
  ## kk made OLDER, so the listing reaches kk_27C first and a prefix match
  ## would take it
  set root [file join $d saved L tb]
  set m [pcall ase::saved_meta [file join $root kk]]
  dict set m saved [expr {[dg $m saved 0] - 100}]
  ase::saved_write_meta [file join $root kk result.meta] $m
  set f [dg [pcall ase::saved_find $k kk] name]
  set r [pcall ase::saved_delete $k kk {}]
  set left {} ; foreach x [pcall ase::saved_list $k] { lappend left [dg $x name] }
  check {SVR29d find and Delete match the whole name, never a prefix} \
    [list $f [dg $r deleted] $left] {kk kk kk_27C}
}
group SVR30c {
  ## a STOPPED live run is saved as stopped
  set k L/tb/s30d
  set d [file join $scratch run30d]
  mkrun $d 1
  mksession $k $d
  ase::session_setattr $k stopped 1
  set r [pcall ase::saved_save $k st1 {} {} 0]
  ase::session_setattr $k stopped 0
  set r2 [pcall ase::saved_save $k st0 {} {} 0]
  check {SVR30c the live run's stopped flag is recorded in the meta} \
    [list [dg [pcall ase::saved_meta [dg $r dir]] stopped] [dg [pcall ase::saved_meta [dg $r2 dir]] stopped]] {1 0}
}
group SVR31b {
  ## a copy of a saved result whose run state was SYNTHESISED stays `current`
  set src [file join $SROOT cur24b]
  ase::result_sel_note $KEY [file join $src tb_ase.raw]
  set r [pcall ase::saved_save $KEY copy31b {} {} 0]
  ase::result_sel_note $KEY {}
  set m [pcall ase::saved_meta [dg $r dir]]
  ase::result_sel_note $KEY [file join [dg $r dir] tb_ase.raw]
  set ps [pcall ase::result_plotmap_state $KEY]
  ase::result_sel_note $KEY {}
  check {SVR31b Save As of a result with a synthesised run state records state_source current and still maps nothing} \
    [list [dg $r ok] [file isfile [file join [dg $r dir] tb_ase.runstate]] [dg $m state_source] $ps] \
    {1 1 current {}}
}
group SVR32b {
  ## a run that dies before writing its own run state leaves NONE, not the old one
  set k L/tb/s32c
  set d [file join $scratch run32c]
  file mkdir $d
  mksession $k $d
  set stale [wr [file join $d tb_ase.runstate] "stale {}\n"]
  rename ::ase::deck_file ::svr32b_df
  proc ::ase::deck_file {state} { return [file join $::scratch nosuchdir32b deep tb_ase.spice] }
  set r [drive_run $k]
  rename ::ase::deck_file {}
  rename ::svr32b_df ::ase::deck_file
  check {SVR32b a run that dies before its deck is written removes the previous run state} \
    [list [lindex $r 0] [file exists $stale]] {1 0}
}
group SVR51 {
  ## Annotate under a changed view: the database attached is THIS session's
  ## other result (the live raw), whose stamp would call it current -- the
  ## saved raw in view must be attached instead; a foreign one is left alone
  set sv [file join $SROOT TT_27C]
  xschem raw clear
  xschem raw_read [file join $LIVE tb_ase.raw] op
  set ::svr51 {}
  foreach {p body} {
    ::op_annot::_annotated {return 0}
    ::op_annot::db_current {return 1}
    ::op_annot::db_detach {lappend ::svr51 detach ; return 1}
    ::op_annot::db_attach {lappend ::svr51 [list attach [lindex $args 0]] ; return {1 {}}}
    ::ase::results_stale {return 0}
  } {
    rename $p ${p}__svr51
    proc $p {args} $body
  }
  ase::result_sel_note $KEY [file join $sv tb_ase.raw]
  pcall ase::ui::annot_ensure_loaded $KEY
  set a $::svr51 ; set ::svr51 {}
  ase::result_sel_note $KEY {}
  pcall ase::ui::annot_ensure_loaded $KEY
  set b $::svr51 ; set ::svr51 {}
  ## a FOREIGN database (not this session's): first-sight trust holds, unless
  ## the view changed (force)
  xschem raw clear
  xschem raw_read [file join $RUN2 tb_ase.raw] op
  pcall ase::ui::annot_ensure_loaded $KEY
  set c $::svr51 ; set ::svr51 {}
  pcall ase::ui::annot_ensure_loaded $KEY 1
  set e $::svr51 ; set ::svr51 {}
  foreach p {::op_annot::_annotated ::op_annot::db_current ::op_annot::db_detach
             ::op_annot::db_attach ::ase::results_stale} {
    rename $p {}
    rename ${p}__svr51 $p
  }
  xschem raw clear
  check {SVR51 a saved view re-attaches over the live raw; the live view keeps it; a foreign database is replaced only on a view change} \
    [list $a $b $c $e] \
    [list [list [list attach [file join $sv tb_ase.raw]]] {} {} \
          [list [list attach [file join $LIVE tb_ase.raw]]]]
}
group SVR51b {
  ## a change of view schedules the forced re-attach
  set src [info body ase::ui::result_view_changed]
  set idle [info body ase::ui::annot_view_idle]
  check {SVR51b result_view_changed schedules annot_view_idle, which re-attaches with force} \
    [list [expr {[string first {ase::ui::annot_view_idle $key} $src] >= 0}] \
          [expr {[string first {annot_refresh_after_run $key 1} $idle] >= 0}] \
          [info args ase::ui::annot_refresh_after_run] [info args ase::ui::annot_refresh_here]] \
    {1 1 {key force} {key force}}
}

# =============================================================================
# SVR40-SVR50: the forms -- display arm only
# =============================================================================
set sch_text {v {xschem version=3.4.7RC file_version=1.2}
G {}
K {}
V {}
S {}
E {}
N 420 -330 600 -330 {}
C {devices/vsource} 600 -300 0 0 {name=V1 value=1}
C {devices/gnd} 510 -270 0 0 {name=GND1 lab=GND}
C {devices/lab_wire} 500 -330 0 0 {name=lD lab=out}
}
## press a Tk button the way a hand does: Enter, press, release, Leave
proc press {b} {
  if {![wex $b]} { return NOWIDGET }
  event generate $b <Enter> -x 4 -y 4
  if {[wex $b]} { event generate $b <ButtonPress-1> -x 4 -y 4 }
  if {[wex $b]} { event generate $b <ButtonRelease-1> -x 4 -y 4 }
  ## the release may have run a -command that destroyed the button
  if {[wex $b]} { event generate $b <Leave> }
  update
  return OK
}
proc mlabels {m} {
  set out {}
  if {[catch {$m index end} last] || $last eq {none}} { return {} }
  for {set i 0} {$i <= $last} {incr i} {
    if {[$m type $i] eq {separator}} { lappend out -- } \
    else { lappend out [$m entrycget $i -label] }
  }
  return $out
}

set DISPLAY_ROWS {SVR40 SVR41 SVR42 SVR43 SVR44 SVR45 SVR45b SVR46 SVR47b SVR47 SVR50}
if {[info exists ::has_x] && [info commands winfo] ne {}} {
  set FIXOK 1
  set drun [file normalize [file join $scratch drun]]
  if {[catch {
    file mkdir [file join $scratch aselib dcell schematic]
    wr [file join $scratch aselib dcell schematic dcell.sch] $sch_text
    set f [open [file join $scratch library.defs] w]
    puts $f "DEFINE aselib [file join $scratch aselib]"
    puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
    close $f
    set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
    set ::library_registry_defs_only 1
    set ::XSCHEM_LIBRARY_PATH {}
    library_new_view aselib dcell ngspice_state1 ngspice_state1
    set spath [xschem cellview_path aselib/dcell ngspice_state1]
    if {$spath eq {}} { error "fixture: state view did not resolve" }
    set DK [ase::session_key aselib dcell ngspice_state1]
    ase::session_open $DK [file normalize $spath]
    set st [ase::session_state $DK]
    dict set st rundir $drun
    dict set st outputs {{name VO expr v(out) save 1 plot 0}}
    ase::session_update $DK $st
    ase::session_save $DK
    ase::session_close $DK
    mkrun $drun 1 dcell
  } fixerr]} {
    set FIXOK 0
    puts "FIXTURE ERROR: $fixerr"
  }
  if {!$FIXOK} {
    foreach r $DISPLAY_ROWS { check "$r display fixture" FIXFAIL {} }
  } else {
  ase::open_state aselib dcell ngspice_state1
  update
  set top [ase::ui::window_for $DK]
  set DROOT [file join $drun saved aselib dcell]

  group SVR40 {
    check {SVR40 the Results menu is results_menu_labels, Save first, each wired to its form} \
      [list [mlabels $top.mb.results] \
            [$top.mb.results entrycget [ase::ui::lbl_rsave_menu] -command] \
            [$top.mb.results entrycget [ase::ui::lbl_rdel_menu] -command]] \
      [list [ase::ui::results_menu_labels] [list ase::ui::rsave_dialog $DK] \
            [list ase::ui::rdel_dialog $DK]]
  }
  group SVR41 {
    focus -force $top
    update
    set parked [focus]
    $top.mb.results invoke [ase::ui::lbl_rsave_menu]
    update
    set W $top.rsave
    set e $W.name
    check {SVR41 Save opens with focus in Save As and the default name selected} \
      [list [expr {$parked ne {}}] [wex $W] [focus] [$e selection present] [$e get] \
            [$W.src cget -text]] \
      [list 1 1 $e 1 [ase::saved_default_name $DK] \
            [ase::ui::rsave_source_text $DK]]
  }
  group SVR42 {
    set W $top.rsave
    $W.name delete 0 end ; $W.name insert 0 first
    $W.comment insert end "line one\nline two"
    press $W.btns.proceed
    set m1 [ase::saved_meta [file join $DROOT first]]
    ase::ui::rsave_dialog $DK
    update
    $W.name delete 0 end ; $W.name insert 0 FIRST
    press $W.btns.proceed
    set cw $top.confirm
    set c1 [list [wex $cw] [$cw.msg cget -text]]
    set before [tree [file join $DROOT first]]
    press $cw.btns.cancel
    set same [expr {[tree [file join $DROOT first]] eq $before}]
    press $W.btns.proceed
    press $cw.btns.proceed
    set m2 [ase::saved_meta [file join $DROOT first]]
    check {SVR42 OK saves; on an existing name the confirm opens, Cancel leaves it, OK overwrites} \
      [list [dg $m1 name] [dg $m1 comment] $c1 $same [dg $m2 name] [wex $W]] \
      [list first "line one\nline two" [list 1 [ase::ui::lbl_rsave_overwrite FIRST]] 1 FIRST 0]
  }
  group SVR43 {
    rename ::ase::ui::run_busy ::svr43_busy
    proc ::ase::ui::run_busy {key} { return /busy }
    ase::ui::rsave_dialog $DK
    update
    set W $top.rsave
    $W.name delete 0 end ; $W.name insert 0 busy43
    set st [$W.btns.proceed cget -state]
    $W.btns.proceed invoke
    update
    check {SVR43 while the live run is busy OK is disabled, says why, and invoking it saves nothing} \
      [list $st [$W.status cget -text] [file exists [file join $DROOT busy43]]] \
      [list disabled [ase::ui::lbl_rsave_busy] 0]
    ## Return in Save As / Directory goes round the button: it must still save
    ## nothing (the guard is in rsave_ok, which both bindings call)
    set rb [list [bind $W.name <Return>] [bind $W.dir <Return>]]
    uplevel #0 [bind $W.name <Return>]
    update
    check {SVR43 Return in Save As (the binding OK's guard must also stop) saves nothing while busy} \
      [list $rb [file exists [file join $DROOT busy43]]] \
      [list [list [list ase::ui::rsave_ok $DK] [list ase::ui::rsave_ok $DK]] 0]
  }
  group SVR44 {
    rename ::ase::ui::run_busy {}
    rename ::svr43_busy ::ase::ui::run_busy
    set W $top.rsave
    ase::ui::run_finished $DK
    update
    after 50 ; update
    check {SVR44 a finished run re-enables OK and clears the busy sentence} \
      [list [$W.btns.proceed cget -state] [$W.status cget -text]] {normal {}}
    ase::ui::rsave_close $DK
    update
  }
  group SVR45 {
    set ::echoes {}
    $top.mb.results invoke [ase::ui::lbl_rsel_menu]
    update
    set W $top.rsel
    ## make the live run differ from the saved one
    mkrun $drun 2 dcell
    ase::ui::results_refill $DK
    set live [ase::session_getattr $DK results]
    set tv $W.saved.list.tv
    set ids [$tv children {}]
    set target {}
    foreach id $ids {
      if {[dg $::ase::ui::dlg($DK,rselmap,rsel-saved,$id) name] eq {FIRST}} { set target $id }
    }
    $tv selection set $target
    update
    ase::ui::rsel_commit $DK
    update
    set saved [ase::session_getattr $DK results]
    set t1 [wm title $top]
    set s1 [$top.status.state cget -text]
    set e1 [lsearch -inline -glob $::echoes {ase: results: FIRST*}]
    $tv selection set [lindex [$tv children {}] 0]
    update
    ase::ui::rsel_commit $DK
    update
    set back [ase::session_getattr $DK results]
    set t2 [wm title $top]
    set s2 [$top.status.state cget -text]
    check {SVR45 committing a saved row changes the Outputs value and the title (R914 order); Last run restores both} \
      [list [expr {$live ne $saved}] [dg $saved VO] [string match "Analog Sim Environment dcell — FIRST*" $t1] \
            [expr {$e1 ne {}}] [expr {$back eq $live}] [string first "—" $t2]] \
      [list 1 1.000000e+01 1 1 1 -1]
    check {SVR45 the status bar's State field carries the saved name, and loses it on Last run} \
      [list [string match "*— FIRST" $s1] [string first "—" $s2]] {1 -1}
  }
  group SVR45b {
    ## a select door that records the selection ITSELF (results::persist does,
    ## when a viewer is open): the dialog must still repaint, synchronously
    set W $top.rsel
    set tv $W.saved.list.tv
    set target {}
    foreach id [$tv children {}] {
      if {[dg $::ase::ui::dlg($DK,rselmap,rsel-saved,$id) name] eq {FIRST}} { set target $id }
    }
    rename ::results::select ::svr45b_select
    proc ::results::select {path {t {}} {opts {}}} {
      set r [::svr45b_select $path $t $opts]
      ase::result_sel_note $::DK [file normalize $path]
      return $r
    }
    $tv selection set $target
    update
    ase::ui::rsel_commit $DK
    set t1 [wm title $top]
    rename ::results::select {}
    rename ::svr45b_select ::results::select
    $tv selection set [lindex [$tv children {}] 0]
    update
    ase::ui::rsel_commit $DK
    update
    check {SVR45b a door that records the selection before the dialog reads it still repaints the title at once} \
      [string match "Analog Sim Environment dcell — FIRST*" $t1] 1
  }
  group SVR46 {
    set W $top.rsel
    ase::saved_save $DK c46 "alpha\nbeta" {} 0
    set d0 [ase::session_dirty $DK]
    $W.saved.dirf.e delete 0 end
    $W.saved.dirf.e insert 0 [file join $scratch elsewhere46]
    ase::ui::saved_relist $DK rsel
    update
    set n1 [llength [$W.saved.list.tv children {}]]
    $W.saved.dirf.e delete 0 end
    $W.saved.dirf.e insert 0 [ase::ui::rsave_dir_default $DK]
    ase::ui::saved_relist $DK rsel
    update
    set tv $W.saved.list.tv
    foreach id [$tv children {}] {
      if {[dg $::ase::ui::dlg($DK,rselmap,rsel-saved,$id) name] eq {c46}} { $tv selection set $id }
    }
    update
    set ct [string trimright [$W.saved.comment get 1.0 end] "\n"]
    check {SVR46 Select's Directory re-lists without dirtying; the Comment area shows the full comment} \
      [list $n1 [ase::session_dirty $DK] $d0 $ct] [list 1 $d0 $d0 "alpha\nbeta"]
    ase::ui::rsel_close $DK
    update
  }
  group SVR47b {
    ## Delete's row map survives Select refilling (both forms open)
    ase::saved_save $DK s47b {} {} 0
    $top.mb.results invoke [ase::ui::lbl_rsel_menu]
    $top.mb.results invoke [ase::ui::lbl_rdel_menu]
    update
    set tv $top.rdel.saved.list.tv
    set pick {}
    foreach id [$tv children {}] {
      if {[dg $::ase::ui::dlg($DK,rselmap,rdel-saved,$id) name] eq {s47b}} { set pick $id }
    }
    $tv selection set $pick
    update
    ase::ui::rsel_fill $DK
    set n1 [ase::ui::rdel_names $DK]
    ase::ui::rsel_close $DK
    set n2 [ase::ui::rdel_names $DK]
    check {SVR47b Select refilling or closing leaves Delete's highlighted rows mapped} \
      [list $n1 $n2] {s47b s47b}
    ase::ui::rdel_close $DK
    update
  }
  group SVR47 {
    ase::saved_save $DK second {} {} 0
    ase::saved_save $DK third {} {} 0
    $top.mb.results invoke [ase::ui::lbl_rdel_menu]
    update
    set W $top.rdel
    set tv $W.saved.list.tv
    set pick {}
    foreach id [$tv children {}] {
      if {[dg $::ase::ui::dlg($DK,rselmap,rdel-saved,$id) name] in {second third}} { lappend pick $id }
    }
    $tv selection set $pick
    update
    press $W.btns.delete
    set cw $top.confirm
    set txt [$cw.msg cget -text]
    press $cw.btns.cancel
    set kept [list [file exists [file join $DROOT second]] [file exists [file join $DROOT third]]]
    $tv selection set $pick
    press $W.btns.delete
    press $cw.btns.proceed
    check {SVR47 Delete's confirm spells the count; Cancel keeps both, OK deletes both} \
      [list [llength $pick] $txt $kept [file exists [file join $DROOT second]] \
            [file exists [file join $DROOT third]]] \
      [list 2 [ase::ui::lbl_rdel_confirm 2] {1 1} 0 0]
    ase::ui::rdel_close $DK
    update
  }
  group SVR50 {
    focus -force $top
    update
    set f0 [focus]
    set ::echoes {}
    ase::result_sel_note $DK [file join $DROOT FIRST dcell_ase.raw]
    ase::ui::result_view_changed $DK
    update
    ase::result_view_reset $DK
    update
    check {SVR50 a change of view echoes and moves no focus} \
      [list [expr {[llength $::echoes] >= 2}] [focus]] [list 1 $f0]
  }
  catch {ase::ui::close $DK}
  update
  }
} else {
  puts "SKIP: SVR40-SVR50 need a display -- the forms are their subject. Every\
 SVR0-SVR33 row ran."
}

# --- teardown ----------------------------------------------------------------
rename ::ase::echo {}
rename ::svr_real_echo ::ase::echo
if {$NDSAVE eq {ZZUNSET}} { catch {unset ::netlist_dir} } else { set ::netlist_dir $NDSAVE }
if {$LNDSAVE eq {ZZUNSET}} { catch {unset ::local_netlist_dir} } else { set ::local_netlist_dir $LNDSAVE }
if {$UCDSAVE eq {ZZUNSET}} { catch {unset ::USER_CONF_DIR} } else { set ::USER_CONF_DIR $UCDSAVE }

# --- missing rows: a band that vanished is a failure, not a silence ---------------
set EXPECTED {SVR0 SVR1 SVR1b SVR2 SVR3 SVR4 SVR5 SVR10 SVR11 SVR12 SVR13 SVR14 SVR15
              SVR16 SVR16b SVR17 SVR17b SVR18 SVR18b SVR18c SVR18d SVR19 SVR20 SVR20b
              SVR20c SVR21 SVR22 SVR22b SVR23 SVR24 SVR24b SVR25 SVR26 SVR27 SVR27b
              SVR27c SVR27d SVR28 SVR29 SVR29b SVR29c SVR30 SVR30b SVR31 SVR32 SVR33
              SVR-D1 SVR-D2 SVR2b SVR12b SVR13b SVR14b SVR17c SVR18e SVR23b
              SVR25b SVR27e SVR27f SVR28b SVR29d SVR30c SVR31b SVR32b SVR51 SVR51b}
if {[info exists ::has_x] && [info commands winfo] ne {}} {
  set EXPECTED [concat $EXPECTED $DISPLAY_ROWS]
}
set missing {}
foreach r $EXPECTED { if {$r ni $::seen} { lappend missing $r } }
puts "ROWS: expected=[llength $EXPECTED] missing=[llength $missing] $missing"
if {[llength $missing]} { incr fail }

# --- verdict -----------------------------------------------------------------
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  puts "OVERALL: ok ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  puts "OVERALL: notok"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
