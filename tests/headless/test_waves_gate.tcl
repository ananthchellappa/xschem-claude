# test_waves_gate.tcl -- the Waves menu is GATED on `cadence_compat`, not repaired.
# doc/claude/specs/results_selection.md R505 + section 17.2 + section 7.2 (the
# item-8 rulings R505a..R505d), invariant T-L (section 12);
# doc/claude/results_batch/PLAN.md item 8; doc/claude/results_batch/DECISIONS.md
# U4/U12; issue 0508.
#
# WHAT THIS FILE IS FOR. Item 8 does NOT fix issue 0508 -- `xschem raw_read`
# still clears the whole registry, in C, unchanged, and outside Cadence mode the
# Waves menu still reaches it and still discards every other loaded result. What
# item 8 ships is a GATE, and a gate has exactly two things to prove: that it
# CLOSES under `cadence_compat`, and that it is NOT THERE without it. So every
# drive in this file is run TWICE, once per flag state, and the pass condition
# for `cadence_compat 0` is the destructive legacy behaviour, asserted
# positively. A file that only proved the refusal would leave "we broke the menu
# for everyone" indistinguishable from a pass.
#
# GROUPS
#   WA  T-L, the grep half -- source shape: WHO may reach `xschem raw_clear` /
#       `xschem raw_read`, and that the gate PRECEDES them. Comment-stripped, so
#       no check here can be satisfied by prose (item 2's SEL82 was, once).
#   WB  the sentence -- R505c: it names `cadence_compat`, it points at
#       `ASE-L > Results > Select`, and that door is proved to EXIST so the
#       sentence is a direction and not a promise.
#   WC  the drive, no DISPLAY needed -- `waves <type>` / `load_raw` /
#       `waves_op_annotate` in BOTH flag states, with `select_raw` shimmed (L1:
#       it does NOT return {} headlessly, it returns a guessed path and a real
#       selection).
#   WD  the drive through the REAL MENU (DISPLAY only) -- `$m invoke <i>` on
#       every entry of the cascade, both flag states. A grep test alone does not
#       prove a menu entry refuses.
#
# Runs with or without X. From the repo root:
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog \
#       --script tests/headless/test_waves_gate.tcl
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_waves_gate.tcl
#
# NOTHING HERE MAY WRITE UNDER $HOME. This file never sets
# `::update_recent_files` -- it has no MRU assertion to make -- and it shims the
# five writers that flag ungates anyway, belt and braces, because `xschem load`
# is on its critical path. WG0 asserts the flag really is off before anything
# runs; a `--pipe` session sets it 0 (src/xschem.tcl, the no_recent_files
# block), but a claim is not evidence.

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
proc wr {path body} {
  file mkdir [file dirname $path]
  set fp [open $path w]
  puts -nonewline $fp $body
  close $fp
}
proc rd {path} {
  if {[catch {open $path r} fp]} { return {} }
  set d [read $fp] ; close $fp ; return $d
}

# ---------------------------------------------------------------------------
# $HOME GUARD. Every writer `::update_recent_files` ungates is shimmed to a
# no-op for the whole file: update_recent_file / update_recent_dir /
# write_recent_file (src/xschem.tcl) and wviewer::rawhist_push /
# wviewer::rawhist_write (src/wave_viewer.tcl). Item 4 destroyed the user's
# raw_history and item 5 destroyed their recent_files by shimming fewer than
# all of them.
# ---------------------------------------------------------------------------
foreach p {update_recent_file update_recent_dir write_recent_file
           ::wviewer::rawhist_push ::wviewer::rawhist_write} {
  if {[info procs $p] ne {}} {
    catch {rename $p ${p}_WGORIG}
    proc $p {args} {}
  }
}
set wg_hist_had [info exists ::wviewer::rawhist]
if {$wg_hist_had} { set wg_hist_old $::wviewer::rawhist }

if {[catch {

eqcheck SEL417-WG0-recent-files-flag-is-OFF-before-anything-runs \
  [list [info exists ::update_recent_files] \
        [expr {[info exists ::update_recent_files] ? $::update_recent_files : {?}}]] \
  {1 0}

# ===========================================================================
# WA -- T-L, THE GREP HALF.
#       "No Waves-menu LOAD entry reaches `xschem raw_clear` or the
#       registry-clearing `xschem raw_read`; the `Clear` entry is the sole
#       permitted caller." That sentence is about REACHABILITY, and after item 8
#       it is true in a specific shape: the eight loading entries all funnel
#       into ONE proc, `load_raw`, whose FIRST executable statement is the gate.
#       So the assertions are (a) a census of every call site of those two verbs
#       in src/xschem.tcl, classified, and (b) the gate's position INSIDE
#       load_raw and inside waves_op_annotate.
#
#       Comment lines are stripped first. What a file SAYS about a rule is not
#       what it DOES, and the fixer round of item 2 had to rewrite a check that
#       a comment naming the proc had satisfied.
# ===========================================================================
set wg_root [file normalize [file join [file dirname [info script]] .. ..]]
set wg_xtcl [file join $wg_root src xschem.tcl]
set wg_lines [split [rd $wg_xtcl] "\n"]

# CODE lines only, keeping the original 0-based line index so ranges stay real.
proc wg_code_lines {lines} {
  set out {}
  set i 0
  foreach line $lines {
    set l [string trim $line]
    if {[string index $l 0] ne "#"} { lappend out [::list $i $l] }
    incr i
  }
  return $out
}
# {first last} 0-based line indices of a proc body, or {} -- from `proc NAME`
# to the next line that is a lone close-brace at column 0, which is how every proc in
# src/xschem.tcl is closed.
proc wg_proc_range {lines name} {
  set i 0 ; set start -1
  foreach line $lines {
    if {$start < 0} {
      if {[regexp "^proc\\s+$name\\s" $line]} { set start $i }
    } elseif {$line eq "\}"} {
      return [::list $start $i]
    }
    incr i
  }
  return {}
}
# {first last} of the Waves cascade construction block.
proc wg_cascade_range {lines} {
  set i 0 ; set start -1
  foreach line $lines {
    if {$start < 0} {
      if {[string match {*add cascade -label "Waves"*} $line]} { set start $i }
    } elseif {[string match {*set simulate_bg *} $line]} {
      return [::list $start $i]
    }
    incr i
  }
  return {}
}
set wg_code    [wg_code_lines $wg_lines]
set wg_lr      [wg_proc_range $wg_lines load_raw]
set wg_opann   [wg_proc_range $wg_lines waves_op_annotate]
set wg_casc    [wg_cascade_range $wg_lines]

# --- the census. Every CODE line that calls one of the two destructive verbs,
#     classified by where it sits. `other` is enumerated by shape so that a NEW
#     unclassified call site cannot hide inside the count.
# ALL THREE registry-wiping verbs. `raw_read_from_attr`
# (src/scheduler.c:10898-10909) does the SAME `extra_rawfile(3, NULL, NULL, ...)`
# wipe as `raw_read`, and a `raw_(clear|read)\M` pattern could not see it BY
# CONSTRUCTION -- so a future Waves entry or palette row wired to it would have
# passed this census green. `read_from_attr` is listed before `read` so the
# alternation cannot stop at the shorter verb.
set wg_verb_re {xschem\s+raw_(clear|read_from_attr|read)\M}
set wg_cens {}
set wg_other {}
foreach pair $wg_code {
  set ln [lindex $pair 0] ; set l [lindex $pair 1]
  if {![regexp $wg_verb_re $l]} continue
  if {$wg_lr ne {} && $ln >= [lindex $wg_lr 0] && $ln <= [lindex $wg_lr 1]} {
    lappend wg_cens load_raw
  } elseif {$wg_casc ne {} && $ln >= [lindex $wg_casc 0] && $ln <= [lindex $wg_casc 1]} {
    lappend wg_cens [expr {[string match {*-label Clear -command {xschem raw_clear}*} $l]
                           ? "waves-Clear-entry" : "waves-OTHER-ENTRY"}]
  } else {
    lappend wg_cens other
    lappend wg_other $l
  }
}
# The `Clear` entry is the ONE permitted caller on this surface; the three
# `load_raw` sites are the ones the gate now stands in front of; the three
# `other` sites are the declared bypasses of spec section 18 (the descend
# new-window carry, twice) plus the `Add waveform reload launcher` symbol text
# -- a PLACED OBJECT, U10's territory, not a Waves entry.
eqcheck SEL418-WA-census-of-raw_clear-raw_read-call-sites-in-xschem.tcl \
  [lsort $wg_cens] {load_raw load_raw load_raw other other other waves-Clear-entry}
eqcheck SEL419-WA-the-three-non-Waves-sites-are-the-KNOWN-declared-ones \
  [lsort [lmap l $wg_other {expr {
      [string match {*raw_read $rawfile $sim_type*} $l] ? "descend-carry" :
      [string match {*tclcommand=*raw_read*} $l] ? "launcher-symbol" : "UNKNOWN:$l"}}]] \
  {descend-carry descend-carry launcher-symbol}
# the classifier is not vacuous: it must SEE a call it is not told about.
# ...and it uses THE SAME pattern the census does ($wg_verb_re), so weakening
# the census cannot leave its own control green.
eqcheck SEL420-WA-census-classifier-fires-on-an-unknown-call-site \
  [llength [lsearch -all -inline -regexp \
      [::list {xschem raw_read $f} {set a 1} {  xschem raw_clear} \
              {xschem raw_read_from_attr ac} {xschem raw read $f tran}] $wg_verb_re]] 3

# --- THE SECOND DISPATCH SURFACE. The Waves group is not only the hand-written
#     cascade in xschem.tcl: src/actions.csv carries a NINE-ROW `waves` action
#     group (`waves.external_viewer` .. `waves.spectrum`) consumed by the command
#     palette (src/action_registry.tcl). A census that reads only xschem.tcl
#     cannot see a palette row wired straight to a wiping verb -- which is
#     exactly the regression T-L exists to prevent. The eight LOADING rows there
#     are gated because they say `waves <type>` and R505a put the guard in
#     `load_raw`; the only direct call on that surface is the Clear row, and it
#     is the sole permitted one, same rule as the menu.
set wg_csvlines [split [rd [file join $wg_root src actions.csv]] "\n"]
set wg_csv_cens {}
foreach line $wg_csvlines {
  set l [string trim $line]
  if {$l eq {} || [string index $l 0] eq "#"} continue
  if {![regexp $wg_verb_re $l]} continue
  lappend wg_csv_cens [expr {[string match {waves.clear,command,waves,Clear,,xschem raw_clear,*} $l]
                             ? "palette-Clear-row" : "UNKNOWN:$l"}]
}
eqcheck SEL457-WA-census-of-the-PALETTE-surface-src-actions.csv \
  [lsort $wg_csv_cens] {palette-Clear-row}

# --- the gate's POSITION. Inside load_raw, `waves_gate_blocked` must come
#     before every destructive verb; a gate after the clear is not a gate.
proc wg_gate_pos {code first last} {
  set gate -1 ; set verb -1
  foreach pair $code {
    set ln [lindex $pair 0] ; set l [lindex $pair 1]
    if {$ln < $first || $ln > $last} continue
    if {$gate < 0 && [string match {*waves_gate_blocked *} $l]} { set gate $ln }
    if {$verb < 0 && [regexp {xschem\s+raw_(clear|read)\M} $l]} { set verb $ln }
  }
  if {$gate < 0} { return no-gate }
  if {$verb < 0} { return gate-only }
  return [expr {$gate < $verb ? "gate-first" : "GATE-TOO-LATE"}]
}
eqcheck SEL421-WA-load_raw-is-gated-BEFORE-it-clears-or-reads \
  [expr {$wg_lr eq {} ? "no-proc" : [wg_gate_pos $wg_code [lindex $wg_lr 0] [lindex $wg_lr 1]]}] \
  gate-first
# the position detector is not vacuous: an ungated body and a late gate must
# both be reported, or SEL421 proves nothing.
set wg_fake [wg_code_lines [::list "proc x \{\} \{" "  xschem raw_clear" "  if \{\[waves_gate_blocked \{q\}\]\} \{ return \}" "\}"]]
eqcheck SEL422-WA-position-detector-discriminates-ungated-and-late-gate \
  [::list [wg_gate_pos [wg_code_lines [::list "proc x \{\} \{" "  xschem raw_clear" "\}"]] 0 2] \
          [wg_gate_pos $wg_fake 0 3]] \
  {no-gate GATE-TOO-LATE}
# --- Op Annotate: it never touches those two verbs, so the thing to pin is that
#     its gate precedes the SELECTION it would otherwise make (R505b).
proc wg_gate_before {code first last needle} {
  set gate -1 ; set hit -1
  foreach pair $code {
    set ln [lindex $pair 0] ; set l [lindex $pair 1]
    if {$ln < $first || $ln > $last} continue
    if {$gate < 0 && [string match {*waves_gate_blocked *} $l]} { set gate $ln }
    if {$hit < 0 && [string match $needle $l]} { set hit $ln }
  }
  if {$gate < 0} { return no-gate }
  if {$hit < 0} { return no-hit }
  return [expr {$gate < $hit ? "gate-first" : "GATE-TOO-LATE"}]
}
eqcheck SEL423-WA-waves_op_annotate-is-gated-BEFORE-it-calls-select_raw \
  [expr {$wg_opann eq {} ? "no-proc" : [wg_gate_before $wg_code [lindex $wg_opann 0] [lindex $wg_opann 1] {*select_raw *}]}] \
  gate-first

# ===========================================================================
# WB -- THE SENTENCE (R505c). It must say WHY, NAME the setting, and POINT at a
#       door that EXISTS. Item 7 shipped that door, which is the only reason
#       item 8 is sequenced after it.
# ===========================================================================
# R505e: the sentence takes an entry name AND a reason, so the two probes below
# carry a REASON THE CODE NEVER USES -- what is asserted here is that the
# composition carries whatever the call site gave it. WHICH reason each real call
# site gives is asserted in WC (SEL451), off the wire, where the defect was.
set wg_msg  [pcall waves_gate_msg {Loading a simulation result} {ZZWHYZZ}]
set wg_msg2 [pcall waves_gate_msg {Waves > Op Annotate} {ZZWHYZZ}]
eqcheck SEL424-WB-the-sentence-NAMES-cadence_compat \
  [expr {[string match {*cadence_compat*} $wg_msg] ? 1 : 0}] 1
eqcheck SEL425-WB-the-sentence-POINTS-at-ASE-L-Results-Select \
  [expr {[string match {*ASE-L > Results > Select*} $wg_msg] ? 1 : 0}] 1
eqcheck SEL426-WB-the-sentence-says-WHY-it-is-blocked \
  [expr {[string match {*is blocked in Cadence mode (cadence_compat) because ZZWHYZZ;*} $wg_msg] ? 1 : 0}] 1
eqcheck SEL427-WB-the-sentence-names-the-way-OUT-of-the-block \
  [expr {[string match {*turn cadence_compat off*} $wg_msg] ? 1 : 0}] 1
# composed ONCE but not a fixed literal: each entry says which entry it was.
eqcheck SEL428-WB-the-entry-name-is-carried-into-the-sentence \
  [::list [expr {[string match {Loading a simulation result is blocked*} $wg_msg] ? 1 : 0}] \
          [expr {[string match {Waves > Op Annotate is blocked*} $wg_msg2] ? 1 : 0}] \
          [expr {$wg_msg eq $wg_msg2 ? 1 : 0}]] \
  {1 1 0}
# NOT A PROMISE. The door the sentence names has to exist -- in the running
# binary (the proc the ASE-L menu entry runs) and in the source (the entry
# itself, comment-stripped so a comment naming it cannot answer for it).
set wg_asetcl [rd [file join $wg_root src ase_window.tcl]]
set wg_asecode {}
foreach line [split $wg_asetcl "\n"] {
  set l [string trim $line]
  if {[string index $l 0] eq "#"} continue
  lappend wg_asecode $l
}
set wg_door_label 0 ; set wg_door_cmd 0
foreach l $wg_asecode {
  if {[string first {add command -label "Select} $l] >= 0} { incr wg_door_label }
  if {[string first {ase::ui::rsel_dialog $key} $l] >= 0} { incr wg_door_cmd }
}
# ...AND IT IS FOLLOWABLE FROM WHERE THE USER IS STANDING. `Results > Select...`
# lives ONLY on an ASE-L session window's menubar (ase_window.tcl, "ASE-L ONLY",
# user ruling U5), so a Cadence-mode user with no session open cannot find that
# cascade anywhere in the window they just clicked in. The sentence therefore has
# to name the step that OPENS it, and that step has to exist in the schematic
# editor's own menubar (comment-stripped, so a comment cannot answer for it).
set wg_launch 0
foreach pair $wg_code {
  if {[string match {*add command -label "Launch ASE-L"*} [lindex $pair 1]]} { incr wg_launch }
}
eqcheck SEL452-WB-the-pointer-is-FOLLOWABLE-it-names-the-step-that-opens-the-door \
  [::list [expr {[string match {*Tools > Launch ASE-L*} $wg_msg] ? 1 : 0}] $wg_launch] {1 1}
eqcheck SEL429-WB-the-door-it-points-at-EXISTS \
  [::list [expr {[info procs ::ase::ui::rsel_dialog] ne {} ? 1 : 0}] \
          $wg_door_label $wg_door_cmd] \
  {1 1 1}

# ===========================================================================
# WC -- THE DRIVE, BOTH FLAG STATES, NO DISPLAY NEEDED.
#       `select_raw` is shimmed: landmine L1 says it does NOT return {}
#       headlessly -- it computes $netlist_dir/<cell>.raw first and only
#       overwrites it with tk_getOpenFile under `has_x`, so an unshimmed drive
#       makes a REAL selection of a guessed path.
# ===========================================================================
set tmp [test_scratch wavesgate]
wr $tmp/cellA.sch "v {xschem version=3.4.4 file_version=1.2}\nG {}\nV {}\nS {}\nE {}\nN 0 0 200 0 {}\n"
proc mkraw {p title node} {
  wr $p "Title: $title
Plotname: Transient Analysis
Flags: real
No. Variables: 2
No. Points: 2
Variables:
\t0\ttime\ttime
\t1\tv($node)\tvoltage
Values:
0\t0.000000000000000e+00
\t1.000000000000000e+00

1\t1.000000000000000e-08
\t2.000000000000000e+00

"
}
mkraw $tmp/an.raw A n1
mkraw $tmp/bn.raw B n2
set ::netlist_dir $tmp
pcall xschem load -inplace $tmp/cellA.sch
pcall xschem unselect_all

# the registry's slot list, in order: `xschem raw info` prints "<idx> current"
# and then one line per slot (test_results_select's helper, same shape).
proc slot_list {} {
  set out {}
  foreach line [split [pcall xschem raw info] "\n"] {
    set line [string trim $line]
    if {$line eq ""} continue
    if {[regexp {^[0-9]+ current$} $line]} continue
    if {[regexp {^[0-9]+ } $line]} { lappend out [lindex $line 1] }
  }
  return $out
}
proc tails {l} { set o {} ; foreach p $l { lappend o [file tail $p] } ; return $o }
# two databases loaded with the APPENDING verb (L2: `raw read`, with a space).
proc wg_two {} {
  catch {xschem raw clear}
  pcall xschem raw read $::tmp/an.raw tran
  pcall xschem raw read $::tmp/bn.raw tran
  return [tails [slot_list]]
}

# --- shims. select_raw records the call and answers a real file; ciw_echo and
#     alert_ record the refusal channel (R505d); set_netlist_dir keeps
#     `waves external` from launching an actual waveform viewer.
foreach p {select_raw ciw_echo alert_ set_netlist_dir} {
  if {[info procs $p] ne {}} { catch {rename $p ${p}_WGORIG} }
}
set wg_selcalls 0 ; set wg_said {} ; set wg_alerts 0 ; set wg_ext 0
proc select_raw {{parent {.}}} { incr ::wg_selcalls ; return $::tmp/an.raw }
proc ciw_echo {line {tag {}}} { lappend ::wg_said $line }
proc alert_ {txt {position {}} {nowait 0} {yesno 0}} { incr ::wg_alerts ; return 1 }
proc set_netlist_dir {{a 0} {b {}}} { incr ::wg_ext ; return {} }
proc wg_reset {} { set ::wg_selcalls 0 ; set ::wg_said {} ; set ::wg_alerts 0 ; set ::wg_ext 0 }
proc wg_said_ok {} {
  if {[llength $::wg_said] != 1} { return "said:[llength $::wg_said]" }
  set m [lindex $::wg_said 0]
  if {![string match {*cadence_compat*} $m]} { return no-setting }
  if {![string match {*ASE-L > Results > Select*} $m]} { return no-door }
  return refused
}

# --- cadence_compat 0: the legacy behaviour, ASSERTED POSITIVELY. This is what
#     issue 0508 describes and what U4 declined to repair: two loaded results in,
#     ONE out, no prompt, no message.
set cadence_compat 0
set wg_before [wg_two] ; wg_reset
pcall load_raw tran
eqcheck SEL430-WC-cc0-load_raw-still-DISCARDS-the-whole-registry-0508-unrepaired \
  [::list $wg_before [tails [slot_list]] $wg_selcalls] {{an.raw bn.raw} an.raw 1}
eqcheck SEL431-WC-cc0-nothing-is-said-and-no-alert-is-raised \
  [::list [llength $wg_said] $wg_alerts] {0 0}

# --- cadence_compat 1: refused, and NOTHING moved.
set cadence_compat 1
set wg_before [wg_two] ; wg_reset
set wg_cur_before [pcall xschem raw_query loaded]
pcall load_raw tran
eqcheck SEL432-WC-cc1-load_raw-REFUSES-and-the-registry-is-untouched \
  [::list $wg_before [tails [slot_list]] \
          [expr {[pcall xschem raw_query loaded] eq $wg_cur_before ? "same-current" : "MOVED"}]] \
  {{an.raw bn.raw} {an.raw bn.raw} same-current}
eqcheck SEL433-WC-cc1-the-refusal-is-SAID-and-names-both-the-setting-and-the-door \
  [wg_said_ok] refused
# the gate fires BEFORE the file dialog: a blocked entry must not first ask the
# user to pick a file and then refuse it.
eqcheck SEL434-WC-cc1-select_raw-is-never-reached \
  $wg_selcalls 0

# --- all EIGHT loading entries, through the command each menu entry actually
#     carries (`waves <type>`), in both flag states. Sp and Spectrum are both
#     `waves ac` -- that is upstream's wiring, not a typo here.
set wg_entrycmds {{} op dc ac tran noise ac ac}
set cadence_compat 1
set wg_res {}
foreach t $wg_entrycmds {
  wg_two ; wg_reset
  pcall waves $t
  lappend wg_res [::list [tails [slot_list]] [wg_said_ok] $wg_selcalls]
}
eqcheck SEL435-WC-cc1-all-EIGHT-loading-entry-commands-refuse-and-move-nothing \
  [lsort -unique $wg_res] {{{an.raw bn.raw} refused 0}}
eqcheck SEL436-WC-cc1-eight-of-them-were-actually-driven \
  [llength $wg_res] 8
set cadence_compat 0
set wg_res0 {}
foreach t $wg_entrycmds {
  wg_two ; wg_reset
  pcall waves $t
  lappend wg_res0 [expr {[lsearch -exact [tails [slot_list]] bn.raw] < 0 ? "wiped" : "kept"}]
}
eqcheck SEL437-WC-cc0-all-EIGHT-still-wipe-the-other-result-legacy-behaviour-intact \
  [lsort -unique $wg_res0] wiped

# --- Op Annotate (R505b). It does not route through load_raw; it calls
#     select_raw itself. Blocked under cadence_compat, live without it.
set cadence_compat 1
wg_two ; wg_reset
pcall waves_op_annotate
eqcheck SEL438-WC-cc1-Op-Annotate-refuses-before-it-selects \
  [::list [tails [slot_list]] [wg_said_ok] $wg_selcalls] {{an.raw bn.raw} refused 0}
set cadence_compat 0
wg_two ; wg_reset
pcall waves_op_annotate
eqcheck SEL439-WC-cc0-Op-Annotate-runs-and-selects-as-it-always-did \
  [::list [wg_said_ok] $wg_selcalls] {said:0 1}

# --- WHAT KEEPS WORKING IN BOTH MODES. `Clear` and `External viewer` never
#     load a result, so neither is gated -- and `Clear`'s `xschem raw_clear` is
#     the one permitted caller of that verb on this surface.
# The Clear entry's command is taken FROM THE SOURCE and evaluated, so this is
# a drive of the entry and not of a hand-typed verb the entry need not agree
# with. (Headless there is no menubar to read `entrycget -command` from; group
# WD clicks the real entry.)
set wg_clearcmd {}
foreach pair $wg_code {
  set ln [lindex $pair 0] ; set l [lindex $pair 1]
  if {$wg_casc eq {} || $ln < [lindex $wg_casc 0] || $ln > [lindex $wg_casc 1]} continue
  if {[regexp {add command -label Clear -command \{(.*)\}\s*$} $l -> body]} { set wg_clearcmd $body }
}
set wg_clear {} ; set wg_extres {}
foreach cc {0 1} {
  set cadence_compat $cc
  wg_two ; wg_reset
  pcall eval $wg_clearcmd
  lappend wg_clear [::list $cc [llength [slot_list]] [llength $wg_said]]
  wg_two ; wg_reset
  pcall waves external
  lappend wg_extres [::list $cc [tails [slot_list]] $wg_ext [llength $wg_said]]
}
eqcheck SEL440-WC-the-Clear-ENTRYS-OWN-COMMAND-works-and-says-nothing-in-BOTH-flag-states \
  [::list $wg_clearcmd $wg_clear] {{xschem raw_clear} {{0 0 0} {1 0 0}}}
eqcheck SEL441-WC-External-viewer-reaches-its-own-branch-in-BOTH-flag-states \
  $wg_extres {{0 {an.raw bn.raw} 1 0} {1 {an.raw bn.raw} 1 0}}

# --- R505e: THE REASON IS THE ENTRY'S OWN, read off the wire. The first draft of
#     this gate composed ONE reason -- "it discards every other result already
#     loaded" -- and said it to `Op Annotate` too, which the gate's own comment
#     block and src/scheduler.c:2410-2427 both say is FALSE: `annotate_op` does a
#     TARGETED delete of a standing 1-point op/dc slot plus an APPENDING read,
#     and wipes nothing. The one sentence a blocked user reads may not assert
#     something this item measured to be untrue, so the two entries carry
#     different reasons and this check pins them APART.
set cadence_compat 1
wg_two ; wg_reset
pcall waves tran
set wg_why_load [lindex $wg_said 0]
wg_two ; wg_reset
pcall waves_op_annotate
set wg_why_op [lindex $wg_said 0]
# ...and the ENTRY NAME each call site passes is asserted here too, off the wire,
# because SEL428 above composes with the TEST's own literal and so cannot see what
# `load_raw` actually passes. `load_raw` is reached from three surfaces -- the
# eight menu entries, the toolbar `Waves` button and `-W`/`--waves` -- so its name
# must be SURFACE-NEUTRAL: a user who pressed a toolbar button was being told a
# MENU had blocked them.
eqcheck SEL451-WC-cc1-EACH-blocked-entry-states-its-OWN-true-reason-and-name \
  [::list [string match {Loading a simulation result is blocked in Cadence mode (cadence_compat) because it discards every other result already loaded;*} $wg_why_load] \
          [string match {*Waves menu*} $wg_why_load] \
          [string match {Waves > Op Annotate is blocked in Cadence mode (cadence_compat) because it adopts a result without going through Results > Select;*} $wg_why_op] \
          [string match {*discards every other result*} $wg_why_op]] \
  {1 0 1 0}

# --- R505f: THE FLAG IS READ AS A BOOLEAN. C reads the same variable with
#     tclgetboolvar("cadence_compat") (src/callback.c:633 -> Tcl_GetBoolean,
#     src/scheduler.c:14601-14613), which takes true/yes/on/TRUE as well as 1 and
#     answers 0 for a non-boolean. A `!= 1` gate therefore stood WIDE OPEN --
#     registry silently wiped -- while C considered the editor to be in Cadence
#     mode. Every row here is a real load_raw drive, not a predicate call.
set wg_bool {}
foreach v {1 true yes on TRUE 0 false no off zzgarbage} {
  set cadence_compat $v
  wg_two ; wg_reset
  pcall load_raw tran
  lappend wg_bool [::list $v [expr {[lsearch -exact [tails [slot_list]] bn.raw] < 0 ? "wiped" : "kept"}] \
                          [llength $wg_said]]
}
eqcheck SEL453-WC-the-flag-is-read-AS-A-BOOLEAN-the-way-C-reads-it \
  $wg_bool [::list {1 kept 1} {true kept 1} {yes kept 1} {on kept 1} {TRUE kept 1} \
                   {0 wiped 0} {false wiped 0} {no wiped 0} {off wiped 0} {zzgarbage wiped 0}]

# --- THE EMPTY REGISTRY. Every other drive in this file is preceded by `wg_two`,
#     so a gate conditioned on "something is already loaded" -- e.g.
#     `if {[xschem raw_query loaded] != -1 && [waves_gate_blocked ...]}` -- would
#     pass all of them while a Cadence-mode user with nothing loaded could still
#     adopt a result through the Waves menu. Drive both flag states with the
#     registry EMPTY.
set cadence_compat 1
catch {xschem raw clear} ; wg_reset
set wg_empty_before [tails [slot_list]]
pcall waves tran
eqcheck SEL454-WC-cc1-a-blocked-entry-refuses-with-an-EMPTY-registry-too \
  [::list $wg_empty_before [tails [slot_list]] [wg_said_ok] $wg_selcalls] {{} {} refused 0}
set cadence_compat 0
catch {xschem raw clear} ; wg_reset
pcall waves tran
eqcheck SEL455-WC-cc0-with-an-EMPTY-registry-it-still-LOADS-as-it-always-did \
  [::list [tails [slot_list]] [llength $wg_said] $wg_selcalls] {an.raw 0 1}

# --- A REFUSED ENTRY CHANGES NOTHING BUT THE MESSAGE. The checks above watch the
#     registry, the sentence and the select_raw count -- so a gate placed AFTER
#     `set show_hidden_texts 1` in waves_op_annotate would keep every one of them
#     green while a refused click still flipped a global that changes what is
#     drawn. Watch the other two pieces of state the two blocked bodies touch.
namespace eval tctx {}
set wg_shx_had [info exists ::show_hidden_texts]
if {$wg_shx_had} { set wg_shx_old $::show_hidden_texts }
set wg_rv_had [info exists ::tctx::retval]
if {$wg_rv_had} { set wg_rv_old $::tctx::retval }
set cadence_compat 1
set ::show_hidden_texts 0
set ::tctx::retval WG-SENTINEL
wg_two ; wg_reset
pcall waves_op_annotate
set wg_sideA [::list $::show_hidden_texts $::tctx::retval]
wg_reset
pcall waves tran
set wg_sideB [::list $::show_hidden_texts $::tctx::retval]
eqcheck SEL456-WC-cc1-a-refused-entry-leaves-NO-other-state-behind \
  [::list $wg_sideA $wg_sideB] {{0 WG-SENTINEL} {0 WG-SENTINEL}}
if {$wg_shx_had} { set ::show_hidden_texts $wg_shx_old } else { catch {unset ::show_hidden_texts} }
if {$wg_rv_had} { set ::tctx::retval $wg_rv_old } else { catch {unset ::tctx::retval} }

# --- the gate reads the flag LIVE. A user who turns cadence_compat off
#     mid-session gets their menu back on the very next click.
set cadence_compat 1
wg_reset ; set wg_g1 [pcall waves_gate_blocked probe {a reason}]
set cadence_compat 0
set wg_g0 [pcall waves_gate_blocked probe {a reason}]
eqcheck SEL442-WC-waves_gate_blocked-answers-1-then-0-as-the-flag-changes \
  [::list $wg_g1 $wg_g0 [llength $wg_said]] {1 0 1}

# ===========================================================================
# WD -- THE DRIVE THROUGH THE REAL MENU (DISPLAY only).
#       A grep test does not prove a menu entry refuses. These invoke the
#       cascade entries the user clicks, by index, in both flag states.
# ===========================================================================
if {[info exists ::has_x] && [info commands winfo] ne {} && [winfo exists .menubar.waves]} {
  set m .menubar.waves
  # A menu index that is no longer a command entry must NAME a red, not abort
  # the leg with `unknown option "-label"`. Measured: sabotage S14 inserts a
  # ninth entry, every index below it shifts, and an unguarded `entrycget
  # -label` on the separator that lands at index 4 kills the whole group --
  # item 7 paid for the same lesson with its SEL413 recipe.
  proc wg_lbl {m i} {
    set t [$m type $i]
    if {$t ne "command"} { return "NOT-A-COMMAND:$t" }
    return [$m entrycget $i -label]
  }
  # the inventory, in order: nothing was added, removed, reordered or disabled.
  set wg_inv {}
  for {set i 0} {$i <= [$m index end]} {incr i} {
    set t [$m type $i]
    if {$t eq "separator"} { lappend wg_inv separator ; continue }
    lappend wg_inv [::list [$m entrycget $i -label] [$m entrycget $i -state]]
  }
  eqcheck SEL443-WD-the-Waves-cascade-inventory-is-unchanged-and-nothing-is-greyed-out \
    $wg_inv [::list {{External viewer} normal} separator {Clear normal} separator \
                    {{Load first analysis found} normal} {{Op Annotate} normal} \
                    {Op normal} {Dc normal} {Ac normal} {Tran normal} \
                    {Noise normal} {Sp normal} {Spectrum normal}]
  # U12 says a blocked entry SAYS WHY when clicked. It is not disabled -- a
  # greyed-out entry explains nothing.
  set cadence_compat 1
  set wg_inv1 {}
  for {set i 0} {$i <= [$m index end]} {incr i} {
    if {[$m type $i] eq "separator"} continue
    lappend wg_inv1 [$m entrycget $i -state]
  }
  eqcheck SEL444-WD-cadence_compat-greys-out-NOTHING-blocked-is-not-disabled \
    [lsort -unique $wg_inv1] normal
  eqcheck SEL445-WD-Op-Annotate-is-wired-to-the-lifted-proc \
    [::list [wg_lbl $m 5] [pcall $m entrycget 5 -command]] {{Op Annotate} waves_op_annotate}

  # --- cadence_compat 1: click each of the eight loading entries, plus
  #     Op Annotate. Indices 4..12 of the cascade.
  set cadence_compat 1
  set wg_click {}
  foreach i {4 5 6 7 8 9 10 11 12} {
    wg_two ; wg_reset
    pcall $m invoke $i
    lappend wg_click [::list [wg_lbl $m $i] [tails [slot_list]] \
                             [wg_said_ok] $wg_alerts $wg_selcalls]
  }
  eqcheck SEL446-WD-cc1-every-blocked-entry-refuses-alerts-once-and-moves-nothing \
    [lsort -unique [lmap e $wg_click {lrange $e 1 end}]] {{{an.raw bn.raw} refused 1 0}}
  eqcheck SEL447-WD-cc1-NINE-entries-were-clicked-eight-loaders-plus-Op-Annotate \
    [lmap e $wg_click {lindex $e 0}] \
    [::list {Load first analysis found} {Op Annotate} Op Dc Ac Tran Noise Sp Spectrum]

  # --- RE-ENTRANCY, DRIVEN WITH THE REAL MODAL `alert_`. Every check above
  #     counts a SHIM, so none of them can see this class: the real `alert_`
  #     blocks in `tkwait window .alert` and takes NO grab (its `grab set .alert`
  #     is commented out, see proc alert_), so the menubar stays LIVE while the
  #     refusal box is up and a second blocked click re-enters the gate from
  #     inside the first refusal's own event loop -- which is exactly how a real
  #     second click arrives. Before R505g the second `toplevel .alert` threw
  #     `window name "alert" already exists in parent` out of a menu -command and
  #     the user got Tk's background-error dialog instead of a refusal.
  #     The `after` below is delivered by the event loop `tkwait` is spinning.
  set cadence_compat 1
  wg_two ; wg_reset
  # NB `alert__WGORIG`, two underscores: the shim loop above saves under
  # `${p}_WGORIG` and this proc's name already ends in one.
  rename alert_ wg_alert_shim
  rename alert__WGORIG alert_
  set ::wg_re {}
  proc wg_second_click {} {
    # a DIFFERENT blocked entry, so the standing box's text must CHANGE
    set rc [catch {.menubar.waves invoke 5} m]          ;# Op Annotate
    set txt {}
    catch {set txt [.alert.l1 cget -text]}
    set ::wg_re [::list $rc $m [expr {[winfo exists .alert] ? 1 : 0}] \
                        [expr {[string match {*Waves > Op Annotate is blocked*} $txt] ? 1 : 0}]]
    after 150 {catch {destroy .alert}}
  }
  set wg_guard [after 20000 {catch {destroy .alert}}]   ;# never hang the suite
  after 600 wg_second_click
  set wg_rc1 [catch {.menubar.waves invoke 9} wg_m1]    ;# Tran -- blocks in tkwait
  catch {after cancel $wg_guard}
  catch {destroy .alert}
  rename alert_ alert__WGORIG
  rename wg_alert_shim alert_
  eqcheck SEL458-WD-cc1-a-SECOND-blocked-click-REFUSES-instead-of-throwing \
    [::list $wg_rc1 $wg_re [llength $wg_said] [tails [slot_list]]] \
    [::list 0 {0 {} 1 1} 2 {an.raw bn.raw}]

  # --- the two that keep working, clicked for real.
  set wg_keep {}
  foreach cc {1 0} {
    set cadence_compat $cc
    wg_two ; wg_reset
    pcall $m invoke 2                             ;# Clear
    lappend wg_keep [::list $cc Clear [llength [slot_list]] [llength $wg_said] $wg_alerts]
    wg_two ; wg_reset
    pcall $m invoke 0                             ;# External viewer
    lappend wg_keep [::list $cc External [tails [slot_list]] $wg_ext [llength $wg_said] $wg_alerts]
  }
  eqcheck SEL448-WD-Clear-and-External-viewer-are-unaffected-by-the-flag-when-CLICKED \
    $wg_keep [::list {1 Clear 0 0 0} {1 External {an.raw bn.raw} 1 0 0} \
                     {0 Clear 0 0 0} {0 External {an.raw bn.raw} 1 0 0}]

  # --- cadence_compat 0: the same nine clicks, and the legacy behaviour is
  #     still there. Without this half, "we broke the menu for everyone" would
  #     read as a pass.
  set cadence_compat 0
  set wg_click0 {}
  foreach i {4 6 7 8 9 10 11 12} {
    wg_two ; wg_reset
    pcall $m invoke $i
    lappend wg_click0 [::list [expr {[lsearch -exact [tails [slot_list]] bn.raw] < 0 ? "wiped" : "kept"}] \
                              [llength $wg_said] $wg_alerts]
  }
  eqcheck SEL449-WD-cc0-every-loading-entry-still-wipes-and-says-nothing \
    [lsort -unique $wg_click0] {{wiped 0 0}}
  wg_two ; wg_reset
  pcall $m invoke 5                               ;# Op Annotate
  eqcheck SEL450-WD-cc0-Op-Annotate-still-selects-a-file-as-it-always-did \
    [::list [llength $wg_said] $wg_alerts $wg_selcalls] {0 0 1}
  set cadence_compat 0
} else {
  puts "gui legs not run (no usable DISPLAY)"
}

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  incr fail
}

# ---------------------------------------------------------------------------
catch {set cadence_compat 0}
foreach p {select_raw ciw_echo alert_ set_netlist_dir} {
  if {[info procs ${p}_WGORIG] ne {}} { catch {rename $p {}} ; catch {rename ${p}_WGORIG $p} }
}
foreach p {update_recent_file update_recent_dir write_recent_file
           ::wviewer::rawhist_push ::wviewer::rawhist_write} {
  if {[info procs ${p}_WGORIG] ne {}} { catch {rename $p {}} ; catch {rename ${p}_WGORIG $p} }
}
if {[info exists wg_hist_had] && $wg_hist_had} { set ::wviewer::rawhist $wg_hist_old }
catch {xschem raw clear}
catch {test_scratch_drop $tmp}
puts "----"
puts "test_waves_gate: $npass passed, $fail failed"
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
