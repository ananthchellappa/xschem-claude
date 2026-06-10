# Phase 3c (c4/c5): proves the 'f' key's graph-vs-canvas routing is now DATA
# (a DEV_KEY dispatch at the top of handle_key_press consults the binding table:
# canvas row -> view.zoom_full, over_graph row -> graph.forward) instead of the
# inline waves_selected guard that used to sit in the switch's case 'f'.
#
# Fires KeyPress events for 'f' (keysym 102) whose pointer lands (a) over a
# waveform graph -> routed to the graph, canvas zoom unchanged; (b) on bare
# canvas -> full zoom (canvas zoom changes).
# Run under X with --pipe:
#   DISPLAY=:0 ./src/xschem --pipe --script tests/headless/test_key_graph_context.tcl
update idletasks
focus -force .drw

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}

# no-modifier key consults the graph only when graph_use_ctrl_key is off
set graph_use_ctrl_key 0

# load a schematic with a graph rect at schematic coords 540,-740 .. 1200,-340
set repo [file normalize [file join [file dirname [info script]] .. ..]]
xschem load [file join $repo xschem_library examples tb_test_evaluated_param.sch]
xschem zoom_full
update idletasks

# schematic -> screen pixel, recomputed live each call because zooming/panning
# shifts xorigin/yorigin/zoom and so moves the graph's screen position:
#   X_TO_XSCHEM(s) = s*zoom - origin  =>  s = (sch+origin)/zoom
proc screen {sx sy} {
  set xo [xschem get xorigin]; set yo [xschem get yorigin]; set zm [xschem get zoom]
  list [expr {int(($sx+$xo)/$zm)}] [expr {int(($sy+$yo)/$zm)}]
}
proc keyat  {x y ks} { xschem callback .drw 2 $x $y $ks 0 0 0; update idletasks }
proc wheelat {x y}   { xschem callback .drw 4 $x $y 0 4 0 0; update idletasks }
set F 102   ;# keysym for 'f'

# --- the data: 'f' rows exist (canvas->zoom_full, over_graph->forward). Ctrl-f gained
#     an over_graph routing row in Phase 3d.1b (property-search canvas behavior stays in
#     C); Alt-f stays entirely in C. So neither has a CANVAS row. -
set dump [xschem bindings dump]
check "canvas f -> view.zoom_full row present" \
  [expr {[lsearch -exact $dump {key 102 0 canvas view.zoom_full}] >= 0}] {}
check "over_graph f -> graph.forward row present" \
  [expr {[lsearch -exact $dump {key 102 0 graph graph.forward}] >= 0}] {}
check "no Ctrl-f / Alt-f CANVAS rows (canvas behavior stays in C)" \
  [expr {[lsearch -glob $dump {key 102 ctrl canvas *}] < 0 &&
         [lsearch -glob $dump {key 102 alt canvas *}]  < 0}] {}

# perturb the canvas zoom away from "full" so a subsequent zoom_full is observable
lassign [screen 870 100] cx cy   ;# below the graph: bare canvas
wheelat $cx $cy                  ;# canvas wheel-up: zoom in
set zp [xschem get zoom]

# (a) 'f' over the graph forwards to the graph -> the *canvas* zoom does NOT change
lassign [screen 870 -540] gx gy  ;# center of the graph rect (live coords)
keyat $gx $gy $F
check "over-graph f leaves canvas zoom" [expr {[xschem get zoom] == $zp}] \
  "(z=$zp @ $gx,$gy)"

# (b) 'f' over bare canvas does a full zoom -> canvas zoom changes back from $zp
lassign [screen 870 100] cx cy   ;# live coords after step (a)
keyat $cx $cy $F
check "over-canvas f zooms full" [expr {[xschem get zoom] != $zp}] \
  "(zp=$zp z1=[xschem get zoom] @ $cx,$cy)"

# ---- arrow keys (Phase 3c c4/c5 batch 2): no-modifier scroll is data-driven ----
set Up 65362; set Down 65364; set Left 65361; set Right 65363
proc origin {} { list [xschem get zoom] [xschem get xorigin] [xschem get yorigin] }

# the data: all 4 arrows have canvas-scroll + over_graph-forward rows, and NO
# modified-arrow rows (Ctrl+Left/Right tab-switch etc. stay in the C switch)
check "arrow scroll rows present" [expr {
  [lsearch -exact $dump {key 65362 0 canvas view.scroll_up}]    >= 0 &&
  [lsearch -exact $dump {key 65363 0 canvas view.scroll_right}] >= 0 &&
  [lsearch -exact $dump {key 65362 0 graph graph.forward}]      >= 0 }] {}
check "no modified-arrow CANVAS rows (pan/tab-switch stays in C)" [expr {
  [lsearch -glob $dump {key 65361 ctrl canvas *}] < 0 &&
  [lsearch -glob $dump {key 65363 ctrl canvas *}] < 0 }] {}

# (c) Up arrow on bare canvas -> vertical scroll (yorigin moves; zoom & xorigin not)
lassign [screen 870 100] cx cy
lassign [origin] z0 x0 y0
keyat $cx $cy $Up
lassign [origin] z1 x1 y1
check "over-canvas Up = vertical scroll" [expr {$z1==$z0 && $x1==$x0 && $y1!=$y0}] \
  "(z:$z0->$z1 x:$x0->$x1 y:$y0->$y1)"

# (d) Right arrow on bare canvas -> horizontal scroll (xorigin moves; zoom & yorigin not)
lassign [screen 870 100] cx cy
lassign [origin] z0 x0 y0
keyat $cx $cy $Right
lassign [origin] z1 x1 y1
check "over-canvas Right = horizontal scroll" [expr {$z1==$z0 && $y1==$y0 && $x1!=$x0}] \
  "(z:$z0->$z1 x:$x0->$x1 y:$y0->$y1)"

# (e) Up arrow over the graph forwards to the graph -> the canvas origin does NOT move
lassign [screen 870 -540] gx gy
lassign [origin] z0 x0 y0
keyat $gx $gy $Up
lassign [origin] z1 x1 y1
check "over-graph Up leaves canvas origin" [expr {$z1==$z0 && $x1==$x0 && $y1==$y0}] \
  "(z:$z0->$z1 x:$x0->$x1 y:$y0->$y1 @ $gx,$gy)"

# ---- Group B routing-only (Phase 3c): canvas behavior stays in C, only the
#      graph-vs-canvas routing is data. Verified with Ctrl+b -> sym_txt.
#      NOTE: 'A' (Shift+a) used to be Group-B routing-only but was fully migrated in
#      Phase 3d.2 batch 3 (now has a canvas row -> view.toggle_show_netlist); its
#      behavioral round-trip below still holds and now exercises the canvas row. ----
proc keyats {x y ks st} { xschem callback .drw 2 $x $y $ks 0 0 $st; update idletasks }
set Akey 65; set bkey 98
set Shift 1; set Ctrl 4

# the data: over_graph rows for the migrated chords, and NO canvas rows for the keys
# whose canvas behavior still falls through to the C switch (a/Ctrl, b/Ctrl). 'A' is
# excluded — it now owns a canvas row (asserted in the batch-3 section below).
check "Group B over_graph rows present" [expr {
  [lsearch -exact $dump {key 97 ctrl graph graph.forward}] >= 0 &&
  [lsearch -exact $dump {key 65 0 graph graph.forward}]    >= 0 &&
  [lsearch -exact $dump {key 98 ctrl graph graph.forward}] >= 0 &&
  [lsearch -exact $dump {key 66 0 graph graph.forward}]    >= 0 }] {}
check "Group B has no canvas rows (behavior stays in C)" [expr {
  [lsearch -glob $dump {key 97 ctrl canvas *}] < 0 &&
  [lsearch -glob $dump {key 98 ctrl canvas *}] < 0 }] {}

# 'A' (Shift+a) toggles netlist_show on the canvas (now via its canvas row); over a
# graph it forwards (no toggle, because A keeps its over_graph row)
lassign [screen 870 100] cx cy
set b0 $netlist_show
keyats $cx $cy $Akey $Shift
check "canvas A toggles netlist_show" [expr {$netlist_show != $b0}] "($b0 -> $netlist_show)"
lassign [screen 870 -540] gx gy
set b1 $netlist_show
keyats $gx $gy $Akey $Shift
check "over-graph A leaves netlist_show" [expr {$netlist_show == $b1}] "($b1 == $netlist_show)"

# Ctrl+b toggles sym_txt on the canvas; over a graph it forwards (no toggle)
lassign [screen 870 100] cx cy
set b0 $sym_txt
keyats $cx $cy $bkey $Ctrl
check "canvas Ctrl+b toggles sym_txt" [expr {$sym_txt != $b0}] "($b0 -> $sym_txt)"
lassign [screen 870 -540] gx gy
set b1 $sym_txt
keyats $gx $gy $bkey $Ctrl
check "over-graph Ctrl+b leaves sym_txt" [expr {$sym_txt == $b1}] "($b1 == $sym_txt)"

# ---- Ctrl+Left/Right tab-switch: routing is data, tab-switch stays in C ----
# Ctrl+arrow must NOT scroll (that distinguishes it from the no-mod arrow, which
# does); on the canvas it switches tabs (origin unchanged), over a graph it forwards
# (origin unchanged). The strong signal is "origin does not move like a scroll".
check "Ctrl+arrow over_graph rows present" [expr {
  [lsearch -exact $dump {key 65361 ctrl graph graph.forward}] >= 0 &&
  [lsearch -exact $dump {key 65363 ctrl graph graph.forward}] >= 0 }] {}
check "Ctrl+arrow has no canvas rows (tab-switch stays in C)" [expr {
  [lsearch -glob $dump {key 65361 ctrl canvas *}] < 0 &&
  [lsearch -glob $dump {key 65363 ctrl canvas *}] < 0 }] {}

lassign [screen 870 100] cx cy
lassign [origin] z0 x0 y0
keyats $cx $cy $Right $Ctrl
lassign [origin] z1 x1 y1
check "canvas Ctrl+Right does not scroll (tab switch)" [expr {$z1==$z0 && $x1==$x0 && $y1==$y0}] \
  "(z:$z0->$z1 x:$x0->$x1 y:$y0->$y1)"

lassign [screen 870 -540] gx gy
lassign [origin] z0 x0 y0
keyats $gx $gy $Right $Ctrl
lassign [origin] z1 x1 y1
check "over-graph Ctrl+Right leaves canvas origin (forwarded)" [expr {$z1==$z0 && $x1==$x0 && $y1==$y0}] \
  "(z:$z0->$z1 x:$x0->$x1 y:$y0->$y1 @ $gx,$gy)"

# ---- 't' routing (Phase 3c): plain t (place text, EXACT) and Ctrl+t (new schematic,
#      FAMILY rstate&Ctrl). Only the over-graph FORWARD path is exercised here: the
#      canvas behaviors are deliberately not triggered (place_text starts a modal
#      placement; Ctrl+t creates a new schematic/tab — both would mutate the fixture).
set tkey 116
check "'t' over_graph rows present" [expr {
  [lsearch -exact $dump {key 116 0 graph graph.forward}]    >= 0 &&
  [lsearch -exact $dump {key 116 ctrl graph graph.forward}] >= 0 }] {}
check "'t' has no canvas rows (place_text/new_schematic stay in C)" [expr {
  [lsearch -glob $dump {key 116 0 canvas *}]    < 0 &&
  [lsearch -glob $dump {key 116 ctrl canvas *}] < 0 }] {}

# plain 't' over a graph forwards -> place_text must NOT run (PLACE_TEXT=1024 stays clear)
lassign [screen 870 -540] gx gy
set u0 [xschem get ui_state]
keyat $gx $gy $tkey
check "over-graph t forwards (no place_text)" \
  [expr {[xschem get ui_state] == $u0 && !([xschem get ui_state] & 1024)}] \
  "(ui_state $u0 -> [xschem get ui_state])"

# ---- Phase 3d.1: Tcl-command-backed action ('B' = edit header). The whole case 'B'
#      is gone from the switch; canvas -> sch.edit_header (tcleval), graph -> forward.
#      Stub the real proc so the effect is observable without opening the dialog. ----
set ::hdr_calls 0
proc update_schematic_header {} { incr ::hdr_calls }
check "B canvas row -> sch.edit_header" \
  [expr {[lsearch -exact $dump {key 66 0 canvas sch.edit_header}] >= 0}] {}
check "bind accepts a Tcl-backed id" [expr {![catch {xschem bind key 66 0 canvas sch.edit_header}]}] {}
check "bind still rejects an unknown id" [catch {xschem bind key 66 0 canvas no.such.action}] {}

# canvas 'B' runs the Tcl command; over a graph it forwards (command NOT run)
lassign [screen 870 100] cx cy
set n $::hdr_calls
keyat $cx $cy 66
check "canvas B runs update_schematic_header" [expr {$::hdr_calls == $n + 1}] "(calls=$::hdr_calls)"
lassign [screen 870 -540] gx gy
set n $::hdr_calls
keyat $gx $gy 66
check "over-graph B forwards (command not run)" [expr {$::hdr_calls == $n}] "(calls=$::hdr_calls)"

# ---- Phase 3d.2: canvas-only command keys (H = C-backed, Alt-h = Tcl-backed).
#      The point of the dispatch refinement: a canvas-only key must still work when
#      the pointer is over a graph (it never forwarded). Proven with Alt-h/schpins. ----
set ::schpins_calls 0
proc schpins_to_sympins {} { incr ::schpins_calls }
set Alt 8   ;# Mod1Mask
check "H / Alt-h rows present" [expr {
  [lsearch -exact $dump {key 72 0 canvas sym.attach_net_labels_to_component_instance}] >= 0 &&
  [lsearch -exact $dump {key 72 ctrl canvas sym.make_schematic_and_symbol_from_selected_components}] >= 0 &&
  [lsearch -exact $dump {key 104 alt canvas sym.create_symbol_pins_from_selected_schematic_pins}] >= 0 }] {}
check "H / Alt-h are canvas-only (no over_graph rows)" [expr {
  [lsearch -glob $dump {key 72 * graph *}]   < 0 &&
  [lsearch -glob $dump {key 104 alt graph *}] < 0 }] {}
# Alt-h on canvas runs the Tcl command
lassign [screen 870 100] cx cy
set n $::schpins_calls
keyats $cx $cy 104 $Alt
check "canvas Alt-h runs schpins_to_sympins" [expr {$::schpins_calls == $n + 1}] "(calls=$::schpins_calls)"
# Alt-h OVER A GRAPH still runs it (canvas-only key; refinement keeps it working)
lassign [screen 870 -540] gx gy
set n $::schpins_calls
keyats $gx $gy 104 $Alt
check "over-graph Alt-h still runs schpins (canvas-only)" [expr {$::schpins_calls == $n + 1}] "(calls=$::schpins_calls)"

# ---- Phase 3d.2 batch 2: clean canvas-only command keys (y, G, g, T, O). All
#      C-backed; verified via the Tcl vars they flip/scale. Cases y and G are gone;
#      g/T/O keep their Ctrl branch. ----
check "batch-2 canvas rows present" [expr {
  [lsearch -exact $dump {key 121 0 canvas edit.toggle_stretch}] >= 0 &&
  [lsearch -exact $dump {key 103 0 canvas view.snap_half}] >= 0 &&
  [lsearch -exact $dump {key 71 0 canvas view.snap_double}] >= 0 &&
  [lsearch -exact $dump {key 84 0 canvas prop.toggle_ignore_attribute_on_selected_instances}] >= 0 &&
  [lsearch -exact $dump {key 79 0 canvas view.toggle_colorscheme}] >= 0 }] {}
check "batch-2 keys are canvas-only (no graph rows)" [expr {
  [lsearch -glob $dump {key 121 * graph *}] < 0 && [lsearch -glob $dump {key 71 * graph *}] < 0 &&
  [lsearch -glob $dump {key 103 * graph *}] < 0 && [lsearch -glob $dump {key 84 * graph *}] < 0 &&
  [lsearch -glob $dump {key 79 * graph *}] < 0 }] {}

lassign [screen 870 100] cx cy
set b $enable_stretch; keyat $cx $cy 121
check "y toggles enable_stretch" [expr {$enable_stretch != $b}] "($b -> $enable_stretch)"
set b $dark_colorscheme; keyat $cx $cy 79
check "O toggles dark_colorscheme" [expr {$dark_colorscheme != $b}] "($b -> $dark_colorscheme)"
set b $cadsnap; keyat $cx $cy 71; set d $cadsnap; keyat $cx $cy 103
check "G doubles then g halves cadsnap (round-trip)" [expr {$d == $b*2 && $cadsnap == $b}] \
  "($b -> $d -> $cadsnap)"
# T (toggle_ignore) has no clean observable: assert it dispatches without error
check "T (toggle_ignore) dispatches without error" [expr {![catch {keyat $cx $cy 84}]}] {}

# ---- Phase 3d.2 batch 3: clean canvas-only command keys (A, L, =, $).
#      A (Shift+a) was Group-B graph-routed, so it gets a canvas row AND keeps its
#      over_graph row (behavioral round-trip asserted above). L/=/$ are canvas-only
#      (no over_graph row). A/L/$ are C-backed; '=' reuses the csv id
#      tools.execute_tcl_command (Tcl-backed -> tclcmd). ----
check "A has both canvas and over_graph rows" [expr {
  [lsearch -exact $dump {key 65 0 canvas view.toggle_show_netlist}] >= 0 &&
  [lsearch -exact $dump {key 65 0 graph graph.forward}]            >= 0 }] {}
check "batch-3 canvas-only rows present" [expr {
  [lsearch -exact $dump {key 76 0 canvas edit.toggle_orthogonal_wiring}] >= 0 &&
  [lsearch -exact $dump {key 61 0 canvas tools.execute_tcl_command}]     >= 0 &&
  [lsearch -exact $dump {key 36 0 canvas view.toggle_draw_pixmap}]       >= 0 }] {}
check "L/=/\$ are canvas-only (no graph rows)" [expr {
  [lsearch -glob $dump {key 76 * graph *}] < 0 &&
  [lsearch -glob $dump {key 61 * graph *}] < 0 &&
  [lsearch -glob $dump {key 36 * graph *}] < 0 }] {}

lassign [screen 870 100] cx cy
# L toggles orthogonal_wiring; round-trip back
set b $orthogonal_wiring; keyat $cx $cy 76; set d $orthogonal_wiring; keyat $cx $cy 76
check "L toggles orthogonal_wiring then back (round-trip)" [expr {$d != $b && $orthogonal_wiring == $b}] \
  "($b -> $d -> $orthogonal_wiring)"
# '=' runs the Tcl-backed console command: stub the proc as a counter
set ::tclcmd_calls 0
proc tclcmd {} { incr ::tclcmd_calls }
set n $::tclcmd_calls; keyat $cx $cy 61
check "= runs tools.execute_tcl_command (tclcmd)" [expr {$::tclcmd_calls == $n + 1}] "(calls=$::tclcmd_calls)"
# '$' toggles a C-only flag (draw_pixmap, no tcl var): assert it dispatches without error
check "\$ (toggle_draw_pixmap) dispatches without error" [expr {![catch {keyat $cx $cy 36}]}] {}

# ---- Phase 3d.1b: semaphore idle_only flag. The 4 deferred sem-first chords (plain a,
#      plain b, Ctrl+f, Ctrl+s) get an idle_only over_graph -> graph.forward row; the
#      dispatch skips an idle_only chord while the editor is busy (semaphore>=2), BEFORE
#      the side-effectful current_input_ctx/waves_selected runs. Their destructive canvas
#      ops stay in C, so the GATE is proven with a non-destructive probe binding. ----
set d1b [xschem bindings dump]
check "4 sem-first chords have idle_only over_graph rows" [expr {
  [lsearch -exact $d1b {key 97 0 graph graph.forward idle}]    >= 0 &&
  [lsearch -exact $d1b {key 98 0 graph graph.forward idle}]    >= 0 &&
  [lsearch -exact $d1b {key 102 ctrl graph graph.forward idle}] >= 0 &&
  [lsearch -exact $d1b {key 115 ctrl graph graph.forward idle}] >= 0 }] {}
# a non-idle migrated chord (plain f over_graph) carries NO idle marker
check "non-idle row has no idle marker" [expr {
  [lsearch -exact $d1b {key 102 0 graph graph.forward}]      >= 0 &&
  [lsearch -exact $d1b {key 102 0 graph graph.forward idle}] <  0 }] {}

# The idle gate, proven on a safe probe: bind an UNUSED key (96 = grave) idle_only on
# canvas to the Tcl-backed counter; it must fire when idle and be skipped when busy.
check "bind accepts the optional 'idle' token" \
  [expr {![catch {xschem bind key 96 0 canvas tools.execute_tcl_command idle}]}] {}
check "the probe binding dumps with idle marker" \
  [expr {[lsearch -exact [xschem bindings dump] {key 96 0 canvas tools.execute_tcl_command idle}] >= 0}] {}
lassign [screen 870 100] cx cy
xschem set semaphore 0
set n $::tclcmd_calls; keyat $cx $cy 96
check "idle chord FIRES when editor is idle (sem=0)" [expr {$::tclcmd_calls == $n + 1}] "(calls=$::tclcmd_calls)"
xschem set semaphore 2
set n $::tclcmd_calls; keyat $cx $cy 96
check "idle chord is SKIPPED when editor is busy (sem=2)" [expr {$::tclcmd_calls == $n}] "(calls=$::tclcmd_calls)"
xschem set semaphore 0
# regression: a NON-idle migrated chord still fires while busy (gate must not over-reach).
# Bind key 96 again WITHOUT idle, raise the semaphore, and confirm it still dispatches.
xschem bind key 96 0 canvas tools.execute_tcl_command
xschem set semaphore 2
set n $::tclcmd_calls; keyat $cx $cy 96
check "non-idle chord still fires when busy (sem=2)" [expr {$::tclcmd_calls == $n + 1}] "(calls=$::tclcmd_calls)"
xschem set semaphore 0
xschem unbind key 96 0 canvas

# ---- Phase 3d.2 sem-gated batch 1: the first FULLY-migrated sem-gated command keys via
#      idle_only. n (netlist + clear, case deleted whole), U (redo, deleted whole),
#      u (undo, branch — case kept for Alt/Ctrl). All Tcl-backed reusing verified-identical
#      actions.csv ids; all idle_only canvas rows (canvas-only, no graph routing). ----
set sg [xschem bindings dump]
check "sem-gated batch-1 idle_only canvas rows present" [expr {
  [lsearch -exact $sg {key 110 0 canvas toolbar.netlist idle}]         >= 0 &&
  [lsearch -exact $sg {key 110 ctrl canvas file.clear_schematic idle}] >= 0 &&
  [lsearch -exact $sg {key 85 0 canvas edit.redo idle}]                >= 0 &&
  [lsearch -exact $sg {key 117 0 canvas edit.undo idle}]               >= 0 }] {}
check "sem-gated batch-1 keys are canvas-only (no graph rows)" [expr {
  [lsearch -glob $sg {key 110 * graph *}] < 0 &&
  [lsearch -glob $sg {key 85 * graph *}]  < 0 &&
  [lsearch -glob $sg {key 117 * graph *}] < 0 }] {}

# The idle gate on REAL migrated keys (undo/redo, reversible & observable). Do a delete
# that pushes undo, then drive u/U with the semaphore busy vs idle. (Keep this LAST — it
# mutates the fixture; restored at the end.)
lassign [screen 870 100] cx cy
set i0 [xschem get instances]
xschem select_all; xschem delete
set i1 [xschem get instances]
check "setup: select_all+delete dropped instances" [expr {$i1 == 0 && $i0 > 0}] "($i0 -> $i1)"
xschem set semaphore 2
keyat $cx $cy 117
check "u (undo) is SKIPPED when busy (sem=2)" [expr {[xschem get instances] == $i1}] "(inst=[xschem get instances])"
xschem set semaphore 0
keyat $cx $cy 117
check "u (undo) FIRES when idle (sem=0)" [expr {[xschem get instances] == $i0}] "(inst=[xschem get instances])"
keyat $cx $cy 85
check "U (redo) re-applies the delete (idle)" [expr {[xschem get instances] == $i1}] "(inst=[xschem get instances])"
keyat $cx $cy 117   ;# restore the fixture
xschem set semaphore 0
# clear-schematic (Ctrl+n) and netlist (n) are not key-pressed here: clear pops a confirm
# dialog and netlist -erc writes files — their data rows above are the assertion.

# ---- Phase 3d.2 sem-gated batch 2: hilight cluster k, K (both cases deleted whole).
#      All Tcl-backed reusing verified-identical csv ids. k/K plain+Ctrl are sem-gated
#      -> idle_only; k Alt (select_hilight_net) has no sem guard -> non-idle. ----
set hl [xschem bindings dump]
check "batch-2 hilight idle_only rows present" [expr {
  [lsearch -exact $hl {key 107 0 canvas hilight.highlight_selected_net_pins idle}]       >= 0 &&
  [lsearch -exact $hl {key 107 ctrl canvas hilight.un_highlight_selected_net_pins idle}] >= 0 &&
  [lsearch -exact $hl {key 75 0 canvas hilight.un_highlight_all_net_pins idle}]          >= 0 &&
  [lsearch -exact $hl {key 75 ctrl canvas hilight.propagate_highlight_selected_net_pins idle}] >= 0 }] {}
# Alt-k (select_hilight_net) is NON-idle (no " idle" marker). NOTE: the Mod4/Super row
# dumps with mods "0" (mods_name doesn't render Mod4 yet — cosmetic, like Alt-h), so we
# assert the Mod1/alt row only.
check "batch-2 Alt-k row present and NON-idle" [expr {
  [lsearch -exact $hl {key 107 alt canvas hilight.select_hilight_nets_pins}]      >= 0 &&
  [lsearch -glob  $hl {key 107 alt canvas hilight.select_hilight_nets_pins idle}] <  0 }] {}
check "batch-2 k/K canvas-only (no graph rows)" [expr {
  [lsearch -glob $hl {key 107 * graph *}] < 0 &&
  [lsearch -glob $hl {key 75 * graph *}]  < 0 }] {}

# Idle gate on real hilight keys via bbox_hilighted ("-100 -100 100 100" = nothing hilighted).
lassign [screen 870 100] cx cy
set none {-100 -100 100 100}
xschem unhilight_all
xschem select instance 0
xschem set semaphore 2
keyat $cx $cy 107
check "k (hilight) is SKIPPED when busy (sem=2)" [expr {[xschem get bbox_hilighted] eq $none}] "(bbox=[xschem get bbox_hilighted])"
xschem set semaphore 0
keyat $cx $cy 107
check "k (hilight) FIRES when idle (sem=0)" [expr {[xschem get bbox_hilighted] ne $none}] "(bbox=[xschem get bbox_hilighted])"
keyat $cx $cy 75
check "K (clear hilights, idle) clears" [expr {[xschem get bbox_hilighted] eq $none}] "(bbox=[xschem get bbox_hilighted])"
xschem unhilight_all
xschem set semaphore 0

# ---- Phase 3d.2 sem-gated batch 3: j hilight-list (BRANCH migration). The 3 exact-chord
#      sem-gated branches (plain/Ctrl/Alt -> print_hilight_net 1/0/4) become idle_only
#      canvas rows (Tcl `xschem print_hilight_net N`, identical). case 'j' keeps its 4th
#      branch (SET_MODMASK && Ctrl -> show 3, a non-sem family). ----
set jl [xschem bindings dump]
check "batch-3 j idle_only rows present" [expr {
  [lsearch -exact $jl {key 106 0 canvas sym.list.print_list_of_highlight_nets idle}]     >= 0 &&
  [lsearch -exact $jl {key 106 ctrl canvas sym.list.create_pins_from_highlight_nets idle}] >= 0 &&
  [lsearch -exact $jl {key 106 alt canvas sym.list.create_labels_from_highlight_nets idle}] >= 0 }] {}
check "batch-3 j canvas-only (no graph rows)" [expr {[lsearch -glob $jl {key 106 * graph *}] < 0}] {}
# print_hilight_net isn't cleanly observable (show 1/3 open a viewdata window; 0/4 run
# tmpfile procs that are no-ops here). Assert j Ctrl (create pins) dispatches without
# error; do NOT press j plain (opens a window). The idle gate is proven elsewhere.
lassign [screen 870 100] cx cy
xschem set semaphore 0
check "j Ctrl (create pins) dispatches without error" [expr {![catch {keyats $cx $cy 106 4}]}] {}

if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
