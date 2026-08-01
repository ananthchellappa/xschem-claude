# devices/vpwl — a PWL voltage source that CUSTOMIZES the generic Edit-Properties
# form (not replaces it): friendly DC label + an inline dynamic (time,value) point
# editor for the `pwl` token. Covers the pure helpers, the netlist (DC + PWL,
# spaced-value quoting round-trip), and the slickprop::build_fields integration
# (generic form shows name/DC + a custom pwl widget; reads it back).
#   run:  ./src/xschem --pipe -q --nolog --script tests/headless/test_vpwl.tcl
set fail 0; set npass 0
proc check {name got exp} { global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp})"; incr fail } }
proc check_true {name c} { check $name [expr {$c ? 1 : 0}] 1 }
proc check_match {name got pat} { global fail npass
  if {[regexp -- $pat $got]} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} !~ /$pat/"; incr fail } }
proc symattr {sym tok} { set r {}; catch {set r [string trim [xschem getprop symbol $sym $tok]]}; return $r }
proc find_cls {w cls} { if {[winfo class $w] eq $cls} {return $w}
  foreach c [winfo children $w] { set r [find_cls $c $cls]; if {$r ne {}} {return $r} }; return {} }

set here    [file normalize [file dirname [info script]]]
set repo    [file normalize [file join $here .. ..]]
set symdir  [file join $repo xschem_libs_newsym devices vpwl symbol]
set symsym  [file join $symdir vpwl.sym]
set symtcl  [file join $symdir vpwl.tcl]
source [file join $here scratch.tcl]
set scratch [test_scratch vpwl]

# --- pure helpers + field API (source the companion directly) ---------------
source $symtcl
check "split 4 tok -> 2 pairs"     [vpwl::split_pairs {0 0 1n 1}]            {{0 0} {1n 1}}
check "join full"                  [vpwl::join_pairs {{0 0} {1n 1}}]         {0 0 1n 1}
check "join stops at interior gap" [vpwl::join_pairs {{0 0} {{} {}} {2n 2}}] {0 0}
check "field_custom = pwl"         [vpwl::field_custom]                      pwl
check "field_labels relabels DC"   [dict get [vpwl::field_labels] DC]        {DC Voltage}

# --- symbol declares the cell namespace + the netlist format ----------------
catch {xschem load_symbol $symsym}
check "symbol edit_form ns"   [symattr $symsym edit_form] vpwl
check "symbol netlist format" [symattr $symsym format]    {@name @pinlist @DC PWL(@pwl )}

# The `pwl` default is a QUOTED multi-word value nested inside the already-quoted
# `template="..."`, so the K {...} block must write the inner quotes as `\\"`, not
# `\"`: the file reader unescapes ONE level, so a single backslash leaves a bare
# quote in the stored property and the template silently truncates at it
# (`name=V1 DC=0 pwl=0`, plus junk `0`/`1n`/`1` tokens in the symbol's global
# prop). Stock devices/{asrc,switch,title,isource_table}.sym all use `\\"`.
# Read the template from the SYMBOL — the build_fields legs below pass a literal
# template string, so they cannot see this.
check "symbol template keeps the quoted pwl default" \
  [symattr $symsym template] {name=V1 DC=0 pwl="0 0 1n 1"}
check "symbol global prop has no junk tokens" \
  [xschem list_tokens [xschem getprop symbol $symsym] 0] {type format template edit_form}

# --- netlist: DC + PWL, spaced `pwl` survives save/netlist/setprop ----------
set sch [file join $scratch tb.sch]
set f [open $sch w]
puts $f "v {xschem version=3.4.8RC file_version=1.2}"
puts $f "G {}"; puts $f "V {}"; puts $f "S {}"; puts $f "E {}"
puts $f "C \{$symsym\} 100 100 0 0 \{name=V1 DC=0.5 pwl=\"0 0 1n 1 2n 0\"\}"
close $f
set ::netlist_dir $scratch
catch {xschem set netlist_type spice}
xschem load $sch
xschem netlist
set nl [read [set fp [open [file join $scratch tb.spice] r]]][close $fp]
check_match "netlist V line DC + PWL" $nl {(?i)V1 \S+ \S+ 0\.5 PWL\(0 0 1n 1 2n 0 ?\)}
xschem setprop instance V1 pwl {5 5 6n 6}
check "get_tok back the spaced pwl" [xschem getprop instance V1 pwl] {5 5 6n 6}

# a freshly PLACED vpwl must carry the template's PWL default (the truncation
# above is invisible on a hand-written instance line — only placement copies the
# template), and it must survive a save/reload round trip
xschem clear force
catch {xschem instance $symsym 100 100 0 0}
check "placed instance carries the PWL default" [xschem getprop instance V1 pwl] {0 0 1n 1}
set psch [file join $scratch placed.sch]
xschem saveas $psch
xschem load $psch
check "PWL default survives save+reload"        [xschem getprop instance V1 pwl] {0 0 1n 1}

# --- generic-form integration: build_fields relabels DC + renders pwl as the
#     dynamic editor, and field_value reads it back (GUI-gated) ---------------
if {[info exists ::has_x] && [info commands winfo] ne {}} {
  set ::symbol $symsym
  catch {destroy .tf}
  frame .tf
  slickprop::build_fields .tf {name=V1 DC=0.5 pwl="0 0 1n 1 2n 0"} {name=V1 DC=0 pwl="0 0 1n 1"}
  check "generic form: all tokens present"    $::slickprop::cur(tokens) {name DC pwl}
  set dcfriendly 0
  foreach w [winfo children .tf] { catch { if {[winfo class $w] eq "Label" && [$w cget -text] eq "DC Voltage"} {set dcfriendly 1} } }
  check_true "generic form: DC relabeled 'DC Voltage'"    $dcfriendly
  check_true "generic form: DC stays a plain entry"       [expr {$::slickprop::cur(entry,DC) ne {}}]
  check_true "generic form: pwl is a CUSTOM widget"       [expr {[info exists ::slickprop::cur(custom,pwl)] && $::slickprop::cur(custom,pwl)}]
  check_true "generic form: pwl editor has a spinbox"     [expr {[find_cls .tf Spinbox] ne {}}]
  check "generic form: field_value(pwl) reads the editor" [slickprop::field_value pwl] {0 0 1n 1 2n 0}
  # grow the editor + re-read reflects the new rows
  set ::vpwl::npts 3; vpwl::rebuild_rows
  set ::vpwl::tval(2) 9n; set ::vpwl::vval(2) 0
  check "generic form: field_value picks up added row"    [slickprop::field_value pwl] {0 0 1n 1 9n 0}
  # apply path: collect_changes -> result must carry the edited pwl, re-quoted
  check_match "generic form: result carries edited pwl (requoted)" \
    [slickprop::result] {pwl="0 0 1n 1 9n 0"}
  catch {destroy .tf}
} else { puts "build_fields GUI legs skipped (no DISPLAY)" }

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } \
else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
