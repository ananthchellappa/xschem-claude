# tests/headless/test_selection_look_plumbing.tcl -- how the selection-look settings reach C
# (doc/claude/selection_look_batch/PLAN.md, stage C).
#
# Four Tcl variables choose how a selection is drawn: selection_style (classic | bright |
# brightbox | halo), selection_text_style (auto | own | colour), selection_text_own_px (a
# rendered font size) and selection_halo_width. src/xschem.tcl gives each a `set_ne` default and
# sel_style_sync() (src/xinit.c) resolves them into the context, where every paint and erase
# reads them. This suite drives that resolution with no display and reads what C made of each
# value through `xschem get selection_look`, which reports the cache and resolves nothing.
#
# Bands:
#   D  the Tcl defaults, and the C default that mirrors selection_text_own_px's
#   S  every selection_style word, and what an empty, unknown, mis-cased or unset one becomes
#      (the branch default, brightbox); compare_schematics forcing classic
#   T  selection_text_style: what each word means in each look
#   O  selection_text_own_px: a number is taken, anything else is the default 16
#      (receipts/M1-verify.md, F2: a non-numeric word used to read as 0, the band on every text)
#   W  selection_halo_width: default and clamps; a number is taken, anything else is the default 3
#      (receipts/C-fences.md, F-C2: atoi() read a non-numeric word as 0, no band at all)
#   K  the cache moves only where sel_style_sync() runs (build_colors, change_linewidth), never
#      on a bare `set`, since an erase must use the look its draw used
#   C  an rc file's value wins over the default (a child xschem started with --rcfile)
#
# The pixels these settings produce, and the View > Selection look menu, are measured on a
# display by test_selection_look_pixels.tcl. Registered in hcases.
# Run it armed:  tests/headless/run_suites.sh --nogui test_selection_look_plumbing
source [file join [file dirname [info script]] scratch.tcl]

set ::fail 0 ; set ::npass 0
proc check {name got want} {
  if {$got eq $want} { puts "ok:   $name" ; incr ::npass } \
  else { puts "FAIL: $name -> {$got} (exp {$want}) : FAIL" ; incr ::fail }
}
set dir [test_scratch sellookplumb]

## what C resolved, after the resolution the View menu runs (xschem build_colors)
proc resolved {} { xschem build_colors ; return [xschem get selection_look] }
proc rget {key} { return [dict get [resolved] $key] }

## ---------------------------------------------------------------------------------------------
## D -- defaults. Nothing in this run sets these four before this line: the suite's own home is
## a throwaway, and run from the source tree xschem reads no user rc (xschem::rc_name).
check "D1 the Tcl defaults (set_ne in src/xschem.tcl): selection_style, selection_text_style,\
 selection_text_own_px, selection_halo_width, selection_color" \
  [list $::selection_style $::selection_text_style $::selection_text_own_px \
        $::selection_halo_width $::selection_color] {brightbox auto 16 3 {}}
check "D2 those defaults resolve to brightbox, colour text, the 16 px cut-off and a 3 px band" \
  [lrange [resolved] 0 7] {style brightbox text_style colour text_own_px 16 halo_px 3}
## SEL_TEXT_OWN_PX (src/xschem.h) is MIRRORED IN TCL: an empty value takes C's, the default
## takes Tcl's, and the two must agree
set ::selection_text_own_px {}
set c_px [rget text_own_px]
set ::selection_text_own_px 16
check "D3 the C default for selection_text_own_px (an empty value) equals the Tcl default" \
  [list $c_px [rget text_own_px]] {16 16}

## ---------------------------------------------------------------------------------------------
## S -- the style word. An exact, case-sensitive match picks a look; anything else is brightbox.
set got {}
foreach w {classic bright brightbox halo} {
  set ::selection_style $w ; lappend got [rget style]
}
check "S1 each of the four words resolves to its own look" $got {classic bright brightbox halo}
set got {}
foreach w {{} unknownword Halo BRIGHT {halo } { classic} brightbox2} {
  set ::selection_style $w ; lappend got [rget style]
}
check "S2 an empty, unknown, mis-cased or padded word resolves to brightbox, the branch default" \
  $got {brightbox brightbox brightbox brightbox brightbox brightbox brightbox}
unset ::selection_style
set unset_style [rget style]
set ::selection_style halo
check "S3 an unset selection_style resolves to brightbox too" $unset_style brightbox
## compare_schematics paints its mismatches through the classic overlay with its own GC
set had_cmp [info exists ::compare_sch]
if {$had_cmp} { set old_cmp $::compare_sch }
set ::compare_sch 1
set got {}
foreach w {bright brightbox halo unknownword} { set ::selection_style $w ; lappend got [rget style] }
if {$had_cmp} { set ::compare_sch $old_cmp } else { set ::compare_sch 0 }
set ::selection_style brightbox
check "S4 while compare_sch is set every word resolves to classic, and back to its own look after" \
  [list $got [rget style]] {{classic classic classic classic} brightbox}

## ---------------------------------------------------------------------------------------------
## T -- the text style. auto (the default) and any other word: own in halo, colour in the rest
## (the 2026-11-15 rulings in PLAN.md); own and colour/color mean themselves in every look.
set got {}
foreach st {bright brightbox halo} {
  set ::selection_style $st
  set row {}
  foreach ts {auto own colour color other {}} {
    set ::selection_text_style $ts ; lappend row [rget text_style]
  }
  lappend got $row
}
set ::selection_text_style auto ; set ::selection_style brightbox
check "T1 selection_text_style auto/own/colour/color/other/empty, in bright, brightbox and halo" \
  $got {{colour own colour colour colour colour} {colour own colour colour colour colour} {own own colour colour own own}}

## ---------------------------------------------------------------------------------------------
## O -- selection_text_own_px (item 2 of stage C). Each value, what C keeps.
foreach {id v want} {
  O1 16 16   O2 12.5 12.5   O3 { 20 } 20   O4 0 0   O5 -5 0   O6 3e1 30
  O7 {} 16   O8 abc 16   O9 16px 16   O10 nan 16   O11 inf 16   O12 {  } 16
  O13 1e400 16   O14 {12 13} 16   O15 - 16
} {
  set ::selection_text_own_px $v
  check "$id selection_text_own_px '$v' resolves to $want" [rget text_own_px] $want
}
set ::selection_text_own_px 16

## ---------------------------------------------------------------------------------------------
## W -- selection_halo_width: default 3, clamped to 0..20
set got {}
foreach v {{} 0 5 -2 20 21 99} { set ::selection_halo_width $v ; lappend got [rget halo_px] }
set ::selection_halo_width 3
check "W1 selection_halo_width empty/0/5/-2/20/21/99 resolves to 3/0/5/0/20/20/20" \
  $got {3 0 5 0 20 20 20}
set got {}
foreach v {abc 5px nan inf 1e400 { 7 } {  } 2.6 -0.5 1e9 - {4 5}} {
  set ::selection_halo_width $v ; lappend got [rget halo_px]
}
set ::selection_halo_width 3
check "W2 selection_halo_width 'abc' '5px' 'nan' 'inf' '1e400' ' 7 ' blanks '2.6' '-0.5' '1e9' '-'\
 '4 5' resolves to 3 3 3 3 3 7 3 2 0 20 3 3 (not a number: the default)" \
  $got {3 3 3 3 3 7 3 2 0 20 3 3}

## ---------------------------------------------------------------------------------------------
## K -- where the resolution runs. A bare `set` leaves the cache alone; build_colors (the View
## menu's command) and change_linewidth() (zoom, `xschem line_width`) resolve.
set ::selection_style bright ; xschem build_colors
set ::selection_style halo
set k_bare [dict get [xschem get selection_look] style]
xschem build_colors
set k_bc [dict get [xschem get selection_look] style]
set ::selection_style classic
set lw [xschem get line_width]
xschem line_width $lw
set k_lw [dict get [xschem get selection_look] style]
set ::selection_style brightbox ; xschem build_colors
check "K1 a bare set leaves the resolved look alone; build_colors and change_linewidth resolve it" \
  [list $k_bare $k_bc $k_lw] {bright halo classic}

## ---------------------------------------------------------------------------------------------
## C -- an rc file's value wins over the default. A child xschem, armed as this run is (it
## inherits this HOME), reads an rc file through --rcfile, the site that reads
## ~/.xschem/xschemrc in an installed xschem; set_ne then leaves the value alone.
proc child {tag rclines} {
  set t [file join $::dir $tag.tcl]
  set f [open $t w]
  puts $f {xschem build_colors}
  puts $f {puts "CHILD [list [list $::selection_style $::selection_text_own_px] [xschem get selection_look]]"}
  puts $f {flush stdout}
  puts $f {exit 0}
  close $f
  set pre {}
  if {[llength $rclines]} {
    set rc [file join $::dir $tag.rc]
    set f [open $rc w] ; foreach l $rclines { puts $f $l } ; close $f
    set pre [list --rcfile $rc]
  }
  set here [pwd] ; cd $::dir
  set rcode [catch {exec env -u DISPLAY timeout 60 [info nameofexecutable] --nogui --pipe -q \
    --nolog --norecent {*}$pre --script $t 2>@1} out]
  cd $here
  if {![regexp -line {^CHILD (.*)$} $out -> line]} { return [list NOCHILD rc=$rcode] }
  return $line
}
set c0 [child c0 {}]
set c1 [child c1 {{set selection_style bright} {set selection_text_own_px abc}}]
set c2 [child c2 {{set selection_style halo}}]
check "C1 a child with no rc: brightbox at the default cut-off" \
  [list [lindex $c0 0] [lrange [lindex $c0 1] 0 5]] \
  {{brightbox 16} {style brightbox text_style colour text_own_px 16}}
check "C2 an rc setting selection_style bright (and a non-numeric cut-off) wins: bright at 16" \
  [list [lindex $c1 0] [lrange [lindex $c1 1] 0 5]] {{bright abc} {style bright text_style colour text_own_px 16}}
check "C3 an rc setting halo wins, and halo's auto text style is own" \
  [list [lindex $c2 0] [lrange [lindex $c2 1] 0 5]] {{halo 16} {style halo text_style own text_own_px 16}}

if {$::fail == 0} {
  puts "RESULT: ALL PASS ($::npass checks)"
  puts "OVERALL: ok ($::npass checks)"
} else {
  puts "RESULT: $::fail FAILED ($::npass passed)"
}
flush stdout
exit [expr {$::fail == 0 ? 0 : 1}]
