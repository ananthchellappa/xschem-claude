# test_snap_bindkeys.tcl
#
# Alt+Up / Alt+Down = snap spacing x2 / x0.5 (cadence_style_rc).
#
# Covers, in order:
#   1. the two actions exist and are bindable to the arrow chords;
#   2. Alt+Up doubles `cadsnap`, Alt+Down halves it, in a SCHEMATIC;
#   3. the same chords work in the SYMBOL editor (one canvas, one binding table);
#   4. they work on a READ-ONLY view (snap is edit geometry, not saved content);
#   5. EVERY use logs to the action-log FILE and to the CIW pane, as the
#      replayable ABSOLUTE command `xschem set cadsnap <value>` (the 0066 rule --
#      never the relative `xschem snap double`, which replays onto a different
#      value) plus a `#= snap A -> B (xN)` outcome line;
#   6. the logged line REPLAYS to the same snap;
#   7. the chords are REMAPPABLE: unbind makes them inert, rebinding another
#      chord to the same action works;
#   8. plain (unmodified) Up/Down still scroll the viewport, not the snap;
#   9. the shipped src/cadence_style_rc really installs these two rows.
#
# Needs Tk (the CIW is a real toplevel). Run under X with --pipe + --logdir:
#   DISPLAY=:0 ./src/xschem --pipe -q --logdir $(mktemp -d) \
#       --script tests/headless/test_snap_bindkeys.tcl

set ::fail 0
proc check {name ok {info {}}} {
  if {$ok} { puts "ok   - $name" } else { puts "FAIL - $name $info" ; set ::fail 1 }
}

if {![info exists tk_version] || ![winfo exists .drw]} {
  puts "RESULT: SKIP (no X)"
  return
}
update idletasks
focus -force .drw
update idletasks

# KeyPress driver: event type 2, keysym, state (Alt = Mod1Mask = 8).
proc key {ks {st 0}} { xschem callback .drw 2 400 300 $ks 0 0 $st ; update idletasks }
set UP 65362 ; set DOWN 65364 ; set ALT 8

proc loglines {} {
  set f [xschem get actionlog_filename]
  if {$f eq {}} { return {} }
  set fd [open $f r] ; set b [read $fd] ; close $fd
  return [split [string trimright $b \n] \n]
}
# lines appended since index $n0
proc newlines {n0} { lrange [loglines] $n0 end }
proc has {lst pat} { expr {[lsearch -glob $lst $pat] >= 0} }

check "action log open" [expr {[xschem get actionlog_filename] ne {}}]

# --- 1. registered + bindable ----------------------------------------------
check "view.snap_double bindable to Alt+Up" \
  [expr {![catch {xschem bind key $UP alt canvas view.snap_double}]}]
check "view.snap_half bindable to Alt+Down" \
  [expr {![catch {xschem bind key $DOWN alt canvas view.snap_half}]}]
set rows [xschem bindings]
check "Alt+Up row installed"   [has $rows {*key 65362 alt canvas view.snap_double*}]
check "Alt+Down row installed" [has $rows {*key 65364 alt canvas view.snap_half*}]
# the plain-arrow scroll rows must be untouched by the alt rows
check "plain Up still bound to view.scroll_up"     [has $rows {*key 65362 0 canvas view.scroll_up*}]
check "plain Down still bound to view.scroll_down" [has $rows {*key 65364 0 canvas view.scroll_down*}]

# --- 2. schematic: x2 / x0.5 ------------------------------------------------
xschem load xschem_library/examples/nand2.sch
xschem set cadsnap 10
set s0 $cadsnap
key $UP $ALT
check "Alt+Up doubles cadsnap (schematic)" [expr {$cadsnap == $s0 * 2.0}] "got $cadsnap"
key $UP $ALT
check "Alt+Up doubles again" [expr {$cadsnap == $s0 * 4.0}] "got $cadsnap"
key $DOWN $ALT
key $DOWN $ALT
check "Alt+Down halves back to the start" [expr {$cadsnap == $s0}] "got $cadsnap"

# --- 5. logging: absolute command + outcome, to file AND CIW ----------------
ciw_create ; update idletasks
proc ciwtext {} {
  if {![winfo exists .ciw.l.t]} { return {} }
  return [.ciw.l.t get 1.0 end]
}
# Start from a snap value nothing else in this session uses (7 -> 14 -> 7), so
# "appears in the CIW pane" is unambiguous: the pane is a running transcript that
# already holds the section-2 lines, and a bare "contains" would pass on those.
xschem set cadsnap 7
set ciwbefore [ciwtext]
set n0 [llength [loglines]]
key $UP $ALT                                   ;# 7 -> 14
set added [newlines $n0]
check "logs the ABSOLUTE 'xschem set cadsnap 14'" \
  [expr {[lsearch -exact $added {xschem set cadsnap 14}] >= 0}] "added=$added"
check "does NOT log the relative 'xschem snap double'" \
  [expr {[lsearch -exact [loglines] {xschem snap double}] < 0}]
check "logs the outcome line '#= snap 7 -> 14 (x2)'" \
  [expr {[lsearch -exact $added {#= snap 7 -> 14 (x2)}] >= 0}] "added=$added"
set ciwafter [ciwtext]
check "CIW pane gains the command line" \
  [expr {[string match {*xschem set cadsnap 14*} $ciwafter] &&
         ![string match {*xschem set cadsnap 14*} $ciwbefore]}] "pane=$ciwafter"
check "CIW pane gains the outcome line" \
  [expr {[string match {*snap 7 -> 14 (x2)*} $ciwafter] &&
         ![string match {*snap 7 -> 14 (x2)*} $ciwbefore]}] "pane=$ciwafter"

set n0 [llength [loglines]]
key $DOWN $ALT                                 ;# 14 -> 7
set added [newlines $n0]
check "Alt+Down logs 'xschem set cadsnap 7'" \
  [expr {[lsearch -exact $added {xschem set cadsnap 7}] >= 0}] "added=$added"
check "Alt+Down logs '#= snap 14 -> 7 (x0.5)'" \
  [expr {[lsearch -exact $added {#= snap 14 -> 7 (x0.5)}] >= 0}] "added=$added"
check "no relative 'xschem snap half' line" \
  [expr {[lsearch -exact [loglines] {xschem snap half}] < 0}]
xschem set cadsnap 10

# `xschem snap half|double` called from a script logs identically (same core)
set n0 [llength [loglines]]
xschem snap double
check "script 'xschem snap double' self-logs the absolute form" \
  [expr {[lsearch -exact [newlines $n0] {xschem set cadsnap 20}] >= 0}]
xschem snap half

# --- 6. replay -------------------------------------------------------------
set n0 [llength [loglines]]
key $UP $ALT                                   ;# 10 -> 20, logs the line
set line [lindex [newlines $n0] 0]
xschem set cadsnap 999
eval $line
check "the logged line replays to the same snap" [expr {$cadsnap == 20}] "line='$line' got $cadsnap"
xschem set cadsnap 10

# --- 3. symbol editor -------------------------------------------------------
xschem load xschem_library/devices/nmos4.sym
check "a .sym is loaded" [string match {*.sym} [xschem get schname]]
set s0 $cadsnap
key $UP $ALT
check "Alt+Up doubles cadsnap (symbol editor)" [expr {$cadsnap == $s0 * 2.0}] "got $cadsnap"
key $DOWN $ALT
check "Alt+Down halves cadsnap (symbol editor)" [expr {$cadsnap == $s0}] "got $cadsnap"

# --- 4. read-only view ------------------------------------------------------
xschem load xschem_library/examples/nand2.sch
xschem set readonly 1
check "the view really is read-only" [expr {[xschem get readonly] == 1}]
set s0 $cadsnap
key $UP $ALT
check "Alt+Up works on a read-only view" [expr {$cadsnap == $s0 * 2.0}] "got $cadsnap"
key $DOWN $ALT
xschem set readonly 0

# --- 7. remappable ----------------------------------------------------------
xschem unbind key $UP alt canvas
xschem unbind key $DOWN alt canvas
set s0 $cadsnap
key $UP $ALT ; key $DOWN $ALT
check "un-bound Alt+Up/Alt+Down are inert" [expr {$cadsnap == $s0}] "got $cadsnap"
# remap the same actions onto the numeric keypad +/- (65451 KP_Add, 65453 KP_Subtract)
xschem bind key 65451 ctrl canvas view.snap_double
xschem bind key 65453 ctrl canvas view.snap_half
key 65451 4                                    ;# ControlMask = 4
check "remapped Ctrl+KP_Add doubles cadsnap" [expr {$cadsnap == $s0 * 2.0}] "got $cadsnap"
key 65453 4
check "remapped Ctrl+KP_Subtract halves cadsnap" [expr {$cadsnap == $s0}] "got $cadsnap"
xschem unbind key 65451 ctrl canvas
xschem unbind key 65453 ctrl canvas
xschem bind key $UP alt canvas view.snap_double
xschem bind key $DOWN alt canvas view.snap_half

# --- 8. plain arrows still scroll ------------------------------------------
set s0 $cadsnap
set o0 [list [xschem get xorigin] [xschem get yorigin]]
key $UP 0
check "plain Up leaves cadsnap alone" [expr {$cadsnap == $s0}] "got $cadsnap"
check "plain Up still scrolls the viewport" \
  [expr {[list [xschem get xorigin] [xschem get yorigin]] ne $o0}]
key $DOWN 0

# --- 8b. real Tk event routing (not just the `xschem callback` shortcut) -----
# A physical Alt+Up puts Mod1Mask (8) on the X event, so `-state 8` is the faithful
# model. Tk's `<Alt-Key-Up>` shorthand must NOT be used here: `event generate` fills
# in Tk's own synthetic ALT_MASK (AnyModifier<<2 = 131072), a bit no real X event
# carries, so the chord would miss the table and silently fall through to the plain
# Up scroll -- which is exactly the false negative this check exists to catch.
set o0 [list [xschem get xorigin] [xschem get yorigin]]
xschem set cadsnap 10
event generate .drw <Key-Up> -state 8 -x 400 -y 300 ; update idletasks
check "Tk <Key-Up> -state 8 reaches view.snap_double" [expr {$cadsnap == 20}] "got $cadsnap"
check "...and does not also scroll" \
  [expr {[list [xschem get xorigin] [xschem get yorigin]] eq $o0}]
event generate .drw <Key-Down> -state 8 -x 400 -y 300 ; update idletasks
check "Tk <Key-Down> -state 8 reaches view.snap_half" [expr {$cadsnap == 10}] "got $cadsnap"

# --- 8c. snap is ORTHOGONAL to how the drawing renders -----------------------
# Stock XSCHEM scaled the automatic line width and the wire-junction / pin dot
# radius with the LIVE cadsnap (`lw = mooz * 0.09 * cadsnap * k`), so doubling the
# snap doubled every wire, symbol line and pin-rectangle outline and grew the dots.
# `linewidth_follows_snap` (default 0) pins the reference to the STARTUP snap.
proc gvar {k} {
  foreach l [split [xschem globals] \n] {
    if {[string match "$k=*" $l]} { return [string range $l [expr {[string length $k] + 1}] end] }
  }
  return {}
}
proc weight {} { list [gvar lw] [gvar cadhalfdotsize] }

xschem load xschem_library/examples/nand2.sch
xschem zoom_full ; update idletasks
check "linewidth_follows_snap defaults to 0" [expr {$linewidth_follows_snap == 0}]
xschem set cadsnap 10
set w0 [weight]
foreach s {20 40 5 80} {
  xschem set cadsnap $s
  check "snap $s leaves line width + dot size alone" [expr {[weight] eq $w0}] "was $w0 now [weight]"
}
xschem set cadsnap 10
# ...and the chords themselves, not just `xschem set cadsnap`
key $UP $ALT ; key $UP $ALT
check "Alt+Up x2 leaves line width + dot size alone" [expr {[weight] eq $w0}] "was $w0 now [weight]"
key $DOWN $ALT ; key $DOWN $ALT

# zoom must STILL drive the line width -- this decouples snap, not zoom
xschem zoom_in ; update idletasks
check "zoom still changes the line width" [expr {[weight] ne $w0}] "was $w0 now [weight]"
xschem zoom_out ; update idletasks

# the same in the symbol editor
xschem load xschem_library/devices/nmos4.sym
xschem zoom_full ; update idletasks
xschem set cadsnap 10
set ws [weight]
xschem set cadsnap 40
check "symbol view: snap 40 leaves line width + dot size alone" \
  [expr {[weight] eq $ws}] "was $ws now [weight]"
xschem set cadsnap 10

# opting back in restores the old stock coupling
xschem load xschem_library/examples/nand2.sch
xschem zoom_full ; update idletasks
xschem set linewidth_follows_snap 1
xschem set cadsnap 10
set w1 [weight]
xschem set cadsnap 40
check "linewidth_follows_snap 1 restores the stock coupling" \
  [expr {[weight] ne $w1}] "was $w1 now [weight]"
xschem set linewidth_follows_snap 0
xschem set cadsnap 40
check "back to 0: the weight is snap-independent again" \
  [expr {[weight] eq $w1}] "was $w1 now [weight]"
xschem set cadsnap 10

# the knob is reachable from the GUI, not only from a script
set found 0
if {[winfo exists .menubar.view]} {
  for {set i 0} {$i <= [.menubar.view index end]} {incr i} {
    if {[catch {.menubar.view entrycget $i -label} lbl]} continue
    if {$lbl eq "Line width follows snap"} { set found 1 ; break }
  }
}
check "View menu offers 'Line width follows snap'" $found

# --- 9. the shipped rc installs the rows ------------------------------------
# Read the file rather than sourcing it: cadence_style_rc pulls in the whole
# Cadence UX (library registry, forms, extra toplevels) and would reshape the
# session under the later checks. The runtime effect of these exact two lines is
# what every check above already exercised.
set rc {}
foreach cand {src/cadence_style_rc ../../src/cadence_style_rc} {
  if {[file exists $cand]} { set rc $cand ; break }
}
if {$rc eq {}} {
  check "src/cadence_style_rc found" 0
} else {
  set fd [open $rc r] ; set body [read $fd] ; close $fd
  check "cadence_style_rc binds Alt+Up to view.snap_double" \
    [regexp {xschem bind key 65362 alt canvas view\.snap_double} $body]
  check "cadence_style_rc binds Alt+Down to view.snap_half" \
    [regexp {xschem bind key 65364 alt canvas view\.snap_half} $body]
}

if {$::fail} { puts "RESULT: FAIL" } else { puts "RESULT: ALL PASS" }
