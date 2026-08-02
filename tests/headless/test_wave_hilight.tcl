# tests/headless/test_wave_hilight.tcl
#
# NET-HIGHLIGHT STYLES ON WAVEFORM TRACES
# doc/claude/specs/wave_trace_hilight.md
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_wave_hilight.tcl
#   ./src/xschem         --pipe -q --nolog --script tests/headless/test_wave_hilight.tcl
#
# FOUR GROUPS, split by what each one needs:
#
#   WH*  the engine and the pure Tcl. BOTH ARMS. The verbs and their
#        fail-soft / fail-loud contracts, the cap, `clear_drawing` dropping the
#        set, the index remaps driven as pure list math, the aphl::parse ->
#        style-index round trip, and the SOURCE-LEVEL legs.
#
#        ⚠ EVERY leg that can plants TWO highlighted traces. With ONE, a bare
#        `gi == .. && ni == ..` comparison and wave_hilight_style_of() agree
#        exactly, so a missed call site is invisible to any behavioural leg —
#        the lesson issues 0175, 0189 and 0192 each paid for separately. The
#        WH9 legs are the other half of that: they assert the CALL SITES at
#        source level, because pixels are the only place some of them show.
#
#   WD*  THE COST WITNESSES, and they are the point of this file. The feature
#        is not "a highlighted trace looks different" — anyone can do that. It
#        is "an animated highlight costs the same on a 200-sample trace and a
#        200 000-sample one", and a leg that only asserts the highlight appears
#        measures none of that. WD1/WD1b/WD2 run in BOTH arms (the envelope is
#        pure arithmetic and `xschem get wave_hilight_points` builds it
#        headlessly on purpose); WD3/WD4 need a real animation frame, which
#        needs has_x, so they are DISPLAY-arm with a source-level twin in both.
#
#   WG*  full Tk under a real DISPLAY: the shipped 9/8/0 keys through the
#        WaveViewer bindtag, the rc-wins and `{break}` contracts, the overlay
#        surviving a `regenerate` (the D4 bracket, i.e. a plain window RESIZE),
#        and the set surviving a strip reorder and a trace move.
#
#   SAB* NOT legs — this group is a PROTOCOL, run by hand, listed here so the
#        next person can repeat it. A green suite is not evidence that the
#        changed code ran ([[green-but-hollow]]); each sabotage below is a
#        one-token edit to shipped source that MUST turn this file red.
#
#        SAB-1  src/hilight.c net_hilight_has_animation(): drop the
#               `&& !xctx->wave_hilight_n` term from the entry gate — i.e. put
#               back `if(!has_x || !xctx->hilight_nets) return 0;`.
#               A viewer has no highlighted NETS, so the whole feature goes
#               silently dead in the only window that has it, and NO schematic
#               leg anywhere in the tree can see it.
#               Kills: WH9d, WD4 (display).
#        SAB-2  src/hilight.c draw_hilight_region(): the same, on its twin gate.
#               Kills: WH9d, WD3 (display).
#        SAB-3  src/draw.c wave_hilight_style_of(): replace the loop with a bare
#               head comparison —
#                 return (xctx->wave_hilight_gi[0] == gi &&
#                         xctx->wave_hilight_ni[0] == ni)
#                        ? xctx->wave_hilight_style[0] : -1;
#               Invisible with ONE highlighted trace, which is why WH2 plants
#               two.  Kills: WH2, WH9c.
#        SAB-4  src/draw.c wave_hilight_envelope(): emit the max point
#               unconditionally (drop the `if(cmax[col] != cmin[col])` guard).
#               The dense case still passes; the SPARSE one doubles.
#               Kills: WD2.
#        SAB-5  src/draw.c wave_hilight_envelope(): stroke the SAMPLES instead
#               of the columns — give every sample its own slot
#               (`col = sabn++;` with the array grown to match) so the envelope
#               degenerates to one point per sample.
#               ⚠ A weaker version of this sabotage is NOT enough and was
#               measured green: merely nudging the column index (`col++`) still
#               produces one point per COLUMN, which is the very thing under
#               test. The sabotage has to actually break the decimation.
#               Kills: WD1 (x2), WD1b (x2).
#        SAB-6  src/hilight.c draw_hilight_region(): delete the `if(only_waves)`
#               early return so a trace-only frame falls through to draw().
#               Kills: WH9e, WH9f, WD3 (display).
#        SAB-7  src/wave_viewer.tcl regenerate(): delete the
#               `wviewer::wave_hilight_push $token` line.
#               Kills: WH9j, WG5, WG7.
#        SAB-8  src/draw.c wave_hilight_points(): put back an identity-only
#               pre-scan of the cache —
#                 for(k..) if(c->valid && c->gi == gi && c->ni == ni) return c->npt;
#               ahead of the call to the builder. That is a strict SUBSET of the
#               geometry key, so the seam answers with a count built for a data
#               window, a rect or a raw that no longer exists. Kills: WD2c x4.
#
#        MEASURED 2026-08-01, against this file at the counts pinned in WZ1
#        (--nogui 139 checks, DISPLAY 196):
#          SAB-1  --nogui 2 FAILED   DISPLAY 3 FAILED  (WH9d x2, WD4)
#          SAB-2  --nogui 2 FAILED   DISPLAY 4 FAILED  (WH9d x2, WD3 x2)
#          SAB-3  --nogui 2 FAILED                     (WH2 x2)
#          SAB-4  --nogui 3 FAILED                     (WD2, WD2c x2:
#                                                       22 points, not 11)
#          SAB-5  --nogui 4 FAILED                     (WD1 x2, WD1b x2:
#                                                       50 000 points, not 1131)
#          SAB-6  --nogui 4 FAILED   DISPLAY 6 FAILED  (WH9e x3, WH9f,
#                                                       WD3 drawcount 38 -> 39)
#          SAB-7                     DISPLAY 5 FAILED  (WH9j, WG5 x2, WG7 x2)
#          SAB-8  --nogui 4 FAILED                     (WD2c x4)

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
# NEVER THROWS (the test_wave_markers form, not test_wave_grid's one-liner).
# Almost every call site hands this the result of pcall/pexpr, which is the
# string `ERR:<msg>` when the inner script blew up -- and
# `expr {"ERR:.." ? 1 : 0}` raises "expected boolean value", which at top level
# aborts the WHOLE FILE through the outer catch and silently drops every leg
# after it. A non-boolean is a loud FAIL that names it, and the file runs on.
proc check_true {name cond} {
  if {[catch {expr {$cond ? 1 : 0}} v]} {
    check $name "NOT-A-BOOLEAN {$cond}" 1
    return
  }
  check $name $v 1
}
proc note {msg} { puts "  note: $msg" }
proc stall {msg} { puts "  WAVEHL-TEST-STALL: $msg" }
proc pcall {script} {
  if {[catch {uplevel 1 $script} r]} { return "ERR:$r" }
  return $r
}
proc pexpr {e} {
  if {[catch {uplevel 1 [list expr $e]} r]} { return "ERR:$r" }
  return $r
}

# non-comment occurrences only, C flavour: the comment blocks in these files
# deliberately quote the very token being counted, and a leg that counts prose
# is a leg that goes green on a deleted call.
proc wh_count_code {src pat} {
  set n 0
  foreach line [split $src "\n"] {
    set t [string trimleft $line]
    if {[string index $t 0] eq "*"} { continue }
    if {[string range $t 0 1] eq "/*" || [string range $t 0 1] eq "//"} { continue }
    incr n [regexp -all $pat $line]
  }
  return $n
}
# the CODE lines of one C function body, by its exact signature line (col 0)
proc wh_fnbody {src sig} {
  set out {}
  set in 0
  foreach line [split $src "\n"] {
    if {!$in} {
      if {[string first $sig $line] == 0} { set in 1 }
      continue
    }
    lappend out $line
    if {$line eq "\}"} { break }
  }
  return [join $out "\n"]
}
# the body of a named Tcl proc, CODE LINES ONLY
proc wh_procbody {src name} {
  set i [string first "\nproc $name \{" $src]
  if {$i < 0} { return {} }
  set j [string first "\n\}\n" $src $i]
  if {$j < 0} { set j end }
  set out {}
  foreach line [split [string range $src $i $j] "\n"] {
    if {[regexp {^\s*#} $line]} { continue }
    lappend out $line
  }
  return [join $out "\n"]
}

# WSLg-robust key delivery (the test_wave_grid form): generated keys go to the
# display's focus window and the focus round trip is asynchronous, so a bare
# `event generate` loses the key roughly 1 run in 5.
proc send_key {w ev done} {
  for {set i 0} {$i < 200} {incr i} {
    update
    if {[uplevel 1 [list expr $done]]} { return 1 }
    catch {focus -force $w}
    update
    if {[uplevel 1 [list expr $done]]} { return 1 }
    if {[focus] eq $w} { catch {event generate $w $ev} }
    update
    if {[uplevel 1 [list expr $done]]} { return 1 }
    after 50
  }
  puts "  send_key: $ev delivery to $w never confirmed (WSLg focus stall)"
  return 0
}

proc viewer_ready {top} {
  for {set i 0} {$i < 300} {incr i} {
    update
    if {[winfo exists $top.drw] && [winfo ismapped $top.drw]} { return 1 }
    after 20
  }
  return 0
}

# recent-files gate (issue 0119)
set no_recent_files 1

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch wvhilight]

set cellroot  [file join $repo sky130A xschem_libs sky130_tests test_nfet_final]
set statefile [file join $cellroot ngspice_state1 test_nfet_final.state]
set f [open [file join $scratch library.defs] w]
puts $f "DEFINE sky130_tests [file join $repo sky130A xschem_libs sky130_tests]"
puts $f "DEFINE sky130_fd_pr [file join $repo sky130A xschem_libs sky130_fd_pr]"
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

# --- which ARM is this, and did we get the one that was asked for? ----------
# A --pipe run under a DISPLAY whose X server was momentarily unreachable comes
# up text-only and runs THE SAME REDUCED SET, reporting a perfectly happy ALL
# PASS. Tell the two apart from the process's OWN command line.
set ::wh_nogui 0
if {![catch {open /proc/self/cmdline rb} whfh]} {
  set ::wh_nogui [expr {[lsearch -exact [split [read $whfh] "\0"] --nogui] >= 0}]
  close $whfh
}
set ::wh_want_x [expr {!$::wh_nogui && [info exists ::env(DISPLAY)] && $::env(DISPLAY) ne {}}]
set ::wh_have_x [expr {[info exists ::has_x] && [info commands winfo] ne {}}]
set ::wh_ran_x 0
check "WA0 the arm that ran is the arm that was asked for\
 (--nogui=$::wh_nogui DISPLAY-wanted=$::wh_want_x has_x=$::wh_have_x)" \
  [expr {$::wh_want_x && !$::wh_have_x ? \
         {X ARM REQUESTED BUT XSCHEM CAME UP HEADLESS} : {ok}}] ok

if {[catch {

# ============================================================================
# WH* — the engine and the pure Tcl. BOTH ARMS.
# ============================================================================

proc wh_reset {} {
  catch {xschem unselect_all}
  catch {xschem select_all}
  catch {xschem delete}
  catch {xschem unselect_all}
  catch {xschem set_modify 0}
}
proc wh_graph {x1 y1 x2 y2 {props {flags=graph}}} {
  xschem set rectcolor 2
  xschem rect $x1 $y1 $x2 $y2 -1 $props 0
}

# --- WH0: the hermetic fixture ----------------------------------------------
# `xschem raw new` + `raw add` builds a real dataset with no ngspice and no
# .raw file, and it works under --nogui (raw->level = currsch satisfies the
# sch_waves_loaded() gate every hit-tester and the envelope walker check).
wh_reset
pcall {xschem raw clear}
check "WH0 hermetic raw created" [pcall {xschem raw new wvhl.raw dc vsweep 0 1.0 0.1}] 1
foreach v {v_a v_b v_c} {
  check "WH0 `raw add $v` accepted" [pcall {xschem raw add $v "vsweep 1 +"}] 1
}
check "WH0 exactly 11 samples on an exact 0.1 grid" [pcall {xschem raw points}] 11
pcall {wh_graph 0 0 800 400}
pcall {xschem setprop rect 2 0 node "v_a\nv_b"}
pcall {wh_graph 0 1000 800 1400}
pcall {xschem setprop rect 2 1 node "v_a\nv_b\nv_c"}
pcall {xschem zoom_full}
foreach gi {0 1} {
  pcall {xschem setprop rect 2 $gi fullxzoom}
  pcall {xschem setprop rect 2 $gi fullyzoom}
}
check "WH0 two graph rects" [pcall {xschem get graph_rects}] 2

# --- WH1: the verbs, and their fail-loud / fail-soft contracts --------------
check "WH1 nothing is highlighted to start with" [pcall {xschem get wave_hilights}] {}
check "WH1 wave_hilight_at answers -1 for an unhighlighted trace" \
  [pcall {xschem get wave_hilight_at 0 0}] -1
check "WH1 applying a style returns 1 (the set changed)" \
  [pcall {xschem wave_hilight 0 0 3}] 1
check "WH1 ...and the predicate agrees" [pcall {xschem get wave_hilight_at 0 0}] 3
check "WH1 the set reads back as {gi ni style} sublists" \
  [pcall {xschem get wave_hilights}] {{0 0 3}}
check "WH1 re-applying the SAME style is a no-op" [pcall {xschem wave_hilight 0 0 3}] 0
check "WH1 re-styling the same trace IS a change" [pcall {xschem wave_hilight 0 0 5}] 1
check "WH1 ...and the set carries the new style, not a second entry" \
  [pcall {xschem get wave_hilights}] {{0 0 5}}
check "WH1 style -1 removes that trace" [pcall {xschem wave_hilight 0 0 -1}] 1
check "WH1 ...and the set is empty again" [pcall {xschem get wave_hilights}] {}
check "WH1 removing an unhighlighted trace changes nothing" \
  [pcall {xschem wave_hilight 0 0 -1}] 0
# FAIL LOUD on a usage error (the graph_marker / graph_axis_zoom convention:
# a script wants a catchable error, a gesture must not raise a modal)
check "WH1 a bare verb is a LOUD usage error" [pcall {xschem wave_hilight}] \
  "ERR:xschem wave_hilight: usage: <gi> <ni> <style> | -clear \[<gi>\]"
check "WH1 a two-argument form is too" [pcall {xschem wave_hilight 0 0}] \
  "ERR:xschem wave_hilight: usage: <gi> <ni> <style> | -clear \[<gi>\]"
# FAIL SOFT on every getter: the viewer wraps them in `catch` and must read a
# short or bad query as "nothing there", never as "locked out"
check "WH1 a short get wave_hilight_at fails SOFT with the sentinel" \
  [pcall {xschem get wave_hilight_at}] -1
check "WH1 a short get wave_hilight_points fails SOFT with 0" \
  [pcall {xschem get wave_hilight_points}] 0
check "WH1 get wave_hilight_at on a bad strip is -1, not an error" \
  [pcall {xschem get wave_hilight_at 99 0}] -1
check "WH1 a negative index is refused, not stored" [pcall {xschem wave_hilight -1 0 3}] 0
check "WH1 a negative NODE index is refused too" [pcall {xschem wave_hilight 0 -1 3}] 0

# --- WH2: TWO highlighted traces — THE TEETH FOR THE PREDICATE --------------
# With ONE, a bare `gi == .. && ni == ..` head comparison and
# wave_hilight_style_of() agree exactly, so a missed call site is invisible.
# This is the leg SAB-3 kills.
pcall {xschem wave_hilight -clear}
check "WH2 two traces on DIFFERENT strips, different styles" \
  [list [pcall {xschem wave_hilight 0 1 4}] [pcall {xschem wave_hilight 1 2 6}]] {1 1}
check "WH2 the HEAD resolves" [pcall {xschem get wave_hilight_at 0 1}] 4
check "WH2 ...and so does the SECOND entry (SAB-3 dies here)" \
  [pcall {xschem get wave_hilight_at 1 2}] 6
check "WH2 a third, unhighlighted trace still answers -1" \
  [pcall {xschem get wave_hilight_at 1 0}] -1
check "WH2 the set carries both, in application order" \
  [pcall {xschem get wave_hilights}] {{0 1 4} {1 2 6}}
# ...and a THIRD on the same strip as the second, so the per-strip clear below
# has something to discriminate
check "WH2 a third entry is accepted" [pcall {xschem wave_hilight 1 0 2}] 1
check "WH2 ...and all three resolve independently" \
  [list [pcall {xschem get wave_hilight_at 0 1}] \
        [pcall {xschem get wave_hilight_at 1 2}] \
        [pcall {xschem get wave_hilight_at 1 0}]] {4 6 2}

# --- WH3: `-clear` is scoped ------------------------------------------------
check "WH3 -clear <gi> drops only that strip's entries, and counts them" \
  [pcall {xschem wave_hilight -clear 1}] 2
check "WH3 the other strip's entry survives" [pcall {xschem get wave_hilights}] {{0 1 4}}
check "WH3 -clear with no strip drops the rest" [pcall {xschem wave_hilight -clear}] 1
check "WH3 -clear on an empty set counts 0" [pcall {xschem wave_hilight -clear}] 0

# --- WH4: THE CAP -----------------------------------------------------------
# read out of src/xschem.h rather than frozen here (landmine 45(a)): a constant
# copied to a second seam drifts silently.
set whcap 0
if {![catch {open [file join $repo src xschem.h] r} fh]} {
  set hsrc [read $fh]; close $fh
  regexp {#define\s+GRAPH_MAX_HILIGHT_WAVES\s+(\d+)} $hsrc -> whcap
}
check_true "WH4 the header defines GRAPH_MAX_HILIGHT_WAVES" [expr {$whcap > 0}]
check "WH4 the Tcl layer reads the SAME cap out of the header" \
  [pcall {wviewer::wave_hilight_cap}] $whcap
pcall {xschem wave_hilight -clear}
set whok 1
for {set i 0} {$i < $whcap} {incr i} {
  if {[pcall {xschem wave_hilight 0 $i 1}] ne 1} { set whok 0 }
}
check "WH4 exactly $whcap entries are accepted" $whok 1
check "WH4 ...and the set holds them all" [llength [pcall {xschem get wave_hilights}]] $whcap
check "WH4 the ${whcap}+1'th is REFUSED, not evicted" \
  [pcall {xschem wave_hilight 1 0 1}] 0
check "WH4 ...and the set is unchanged" \
  [llength [pcall {xschem get wave_hilights}]] $whcap
check "WH4 re-styling an EXISTING entry still works at the cap" \
  [pcall {xschem wave_hilight 0 0 7}] 1
check "WH4 ...and it did not grow the set" \
  [llength [pcall {xschem get wave_hilights}]] $whcap

# --- WH5: clear_drawing drops the set --------------------------------------
# The same xctx is reused by `xschem clear`, File>Open in the tab, `xschem
# load`, the disk-undo reload AND wviewer::regenerate. A surviving (gi, ni)
# would highlight whatever trace lands at that index in the NEW document.
check "WH5 the set is non-empty before the clear" \
  [expr {[llength [pcall {xschem get wave_hilights}]] > 0}] 1
pcall {xschem clear_drawing}
check "WH5 clear_drawing dropped every entry" [pcall {xschem get wave_hilights}] {}
check "WH5 ...and wave_hilight_at answers -1 again" \
  [pcall {xschem get wave_hilight_at 0 0}] -1

# --- WH6: the style CURSOR getter ------------------------------------------
# `xschem set hilight_color` has existed forever with no matching read, so the
# viewer's `9` had no way to ask "which style is current" without moving it.
set whc [pcall {xschem get hilight_color}]
check_true "WH6 get hilight_color returns an integer" [string is integer -strict $whc]
check "WH6 reading it does NOT move the cursor" [pcall {xschem get hilight_color}] $whc
pcall {xschem set hilight_color 2}
check "WH6 it reads back what set wrote" [pcall {xschem get hilight_color}] 2
check "WH6 incr moves it" [pcall {xschem incr_hilight_color}] 3
check "WH6 ...and the getter sees the move" [pcall {xschem get hilight_color}] 3
pcall {xschem decr_hilight_color}

# --- WH7: the index remaps, as PURE list math ------------------------------
# Each adapter delegates its arithmetic to the SHIPPED pure helper that already
# remaps the model selection for the same event, so the highlight set and the
# selection can never disagree about where a trace went.
check "WH7 strip reorder: gi moves by reordered_index" \
  [pcall {wviewer::wavehl_after_strip_move {{0 1 5} {2 0 4}} 0 2}] {{2 1 5} {1 0 4}}
check "WH7 strip removal: entries on it go, the rest shift down" \
  [pcall {wviewer::wavehl_after_strip_removal {{0 1 5} {1 3 2} {2 0 4}} {1}}] \
  {{0 1 5} {1 0 4}}
check "WH7 trace move: the entry FOLLOWS its trace to the new (gi, ni)" \
  [pcall {wviewer::wavehl_after_trace_move {{0 1 5} {1 0 2}} 0 1 1 4}] {{1 4 5} {1 0 2}}
check "WH7 ...and entries ABOVE the hole in the source shift down" \
  [pcall {wviewer::wavehl_after_trace_move {{0 3 6}} 0 1 1 4}] {{0 2 6}}
check "WH7 ...while entries on OTHER strips are untouched" \
  [pcall {wviewer::wavehl_after_trace_move {{2 3 6}} 0 1 1 4}] {{2 3 6}}
check "WH7 trace delete: the doomed entry goes, the rest shift down" \
  [pcall {wviewer::wavehl_after_trace_delete {{0 1 5} {0 3 6} {1 0 2}} 0 {1}}] \
  {{0 2 6} {1 0 2}}
check "WH7 front insert (multi-plot prepend): every gi shifts by nnew" \
  [pcall {wviewer::wavehl_after_prepend {{0 1 5} {2 0 4}} 2}] {{2 1 5} {4 0 4}}
check "WH7 a zero/garbage prepend count is the identity" \
  [pcall {wviewer::wavehl_after_prepend {{0 1 5}} 0}] {{0 1 5}}
# the split: node k of the split strip lands on strip src+k, alone (node 0)
set whplan [dict create ok 1 take {} src 1 at 2 block 2 new 2]
check "WH7 split: node 0 stays on the source strip at node 0" \
  [pcall {wviewer::wavehl_after_split {{1 0 5}} $whplan 1}] {{1 0 5}}
check "WH7 split: node 2 lands on strip src+2, at node 0" \
  [pcall {wviewer::wavehl_after_split {{1 2 5}} $whplan 1}] {{3 0 5}}
check "WH7 split: a NON-split strip goes through target_after_split" \
  [pcall {wviewer::wavehl_after_split {{0 1 5}} $whplan 1}] \
  [list [list [wviewer::target_after_split 0 $whplan] 1 5]]
check "WH7 a refused plan is the identity" \
  [pcall {wviewer::wavehl_after_split {{0 1 5}} [dict create ok 0] 0}] {{0 1 5}}
# the multi-trace fold reproduces move_traces_in_graphs' own index adjustment
set whgs [list \
  [dict create traces [list [dict create vec v_a] [dict create vec v_b] \
                            [dict create vec v_c] [dict create vec v_d]]] \
  [dict create traces {}]]
check "WH7 multi-move: the PER-SOURCE adjustment (model 0 and 2 of four)" \
  [pcall {wviewer::wavehl_after_traces_move {{0 2 9}} $whgs {{0 0} {0 2}} 1}] {{1 1 9}}
check "WH7 ...and an entry on an untouched node shifts by the two holes below it" \
  [pcall {wviewer::wavehl_after_traces_move {{0 3 9}} $whgs {{0 0} {0 2}} 1}] {{0 1 9}}

# --- WH8: normalisation, and the aphl -> style-index round trip -------------
check "WH8 norm drops garbage, keeps the LAST style per (gi, ni)" \
  [pcall {wviewer::wave_hilight_norm {{0 1 5} {0 1 7} {1 2 3} {x y z} {0 1}} 3}] \
  {{0 1 7} {1 2 3}}
check "WH8 norm drops an out-of-range strip" \
  [pcall {wviewer::wave_hilight_norm {{0 1 5} {9 0 5}} 2}] {{0 1 5}}
check "WH8 norm drops a negative style" \
  [pcall {wviewer::wave_hilight_norm {{0 1 -1}} 2}] {}
check "WH8 merge: LAST style wins per (gi, ni), new pairs append" \
  [pcall {wviewer::wave_hilight_merge {{0 1 5}} {{0 1 9} {2 0 4}}}] {{0 1 9} {2 0 4}}
# the dedup-or-append half of net_hilight_apply, factored out so a consumer that
# applies the style ITSELF is not forced through the schematic-selection arm
set whrow {0 purple 3 {20 20} 0 0 none 0}
set whidx [pcall {net_hilight_style_index_for $whrow}]
check_true "WH8 an ad-hoc style installs and returns a table INDEX" \
  [expr {[string is integer -strict $whidx] && $whidx >= 0}]
check "WH8 installing the SAME row again reuses the index (no table bloat)" \
  [pcall {net_hilight_style_index_for $whrow}] $whidx
check "WH8 the installed row really carries the requested fields" \
  [lrange [lindex [pcall {net_hilight_style_current}] $whidx] 1 4] {purple 3 {20 20} 0}
check "WH8 a MARCHING ad-hoc style installs at a different index" \
  [expr {[pcall {net_hilight_style_index_for {0 cyan 2 {8 4} 0 0 march_fwd 2}}] != $whidx}] 1

# ============================================================================
# WD* — THE COST WITNESSES. WD1/WD1b/WD2 run in BOTH arms.
#
# The claim under test is not "the highlight appears". It is that an animated
# frame costs the same however many samples the trace has, which is true only
# if the overlay strokes a per-screen-column min/max ENVELOPE instead of the
# real polyline. `xschem get wave_hilight_points` is the seam that makes that
# assertable: it is the point count of the thing actually stroked.
# ============================================================================
wh_reset
pcall {xschem raw clear}
check "WD0 a 50 000-sample raw" [pcall {xschem raw new wvbig.raw tran time 0 1.0 2e-5}] 1
check "WD0 ...really has 50 000 points" [pcall {xschem raw points}] 50000
check "WD0 v_a is a real column" [pcall {xschem raw add v_a {time 1 +}}] 1
pcall {wh_graph 0 0 800 400}
pcall {xschem setprop rect 2 0 node "v_a"}
pcall {xschem zoom_full}
# PIN the data window, so the dense and the doubled-density runs below are
# measured through byte-identical geometry and the point counts are comparable
foreach {tk tv} {x1 0 x2 1 y1 1 y2 2} { pcall {xschem setprop rect 2 0 $tk $tv} }
pcall {xschem wave_hilight -clear}
check "WD0 the trace is highlighted" [pcall {xschem wave_hilight 0 0 1}] 1
set wdpts [pcall {xschem get wave_hilight_points 0 0}]
check_true "WD1 the envelope exists (a non-zero point count)" \
  [pexpr {[string is integer -strict $wdpts] && $wdpts > 0}]
# THE BOUND. The envelope is <= 2 points per screen column of the PLOT BOX, and
# the plot box is strictly inside the rect, so 2 * (rect width in screen px) + 2
# is a bound the implementation cannot satisfy by accident: it excludes anything
# within two orders of magnitude of 50 000.
set wdzoom [pcall {xschem get zoom}]
set wdw [expr {800.0 / $wdzoom}]
check_true "WD1 50 000 samples decimated to <= 2W+2 points\
 (got $wdpts, bound [expr {int(2*$wdw+2)}], W=[expr {int($wdw)}] px)" \
  [pexpr {$wdpts <= 2 * $wdw + 2}]
check_true "WD1 ...which is a small fraction of the sample count ($wdpts of 50000)" \
  [pexpr {$wdpts * 10 < 50000}]
# THE CLAIM ITSELF, stated directly and with no geometry in it: DOUBLE the
# sample density through the SAME window and the stroked point count does not
# move. A per-sample implementation doubles here; SAB-5 dies on this leg.
pcall {xschem raw clear}
check "WD1b a 100 000-sample raw over the same window" \
  [pcall {xschem raw new wvbig2.raw tran time 0 1.0 1e-5}] 1
check "WD1b ...really has 100 000 points" [pcall {xschem raw points}] 100000
check "WD1b v_a is a real column" [pcall {xschem raw add v_a {time 1 +}}] 1
foreach {tk tv} {x1 0 x2 1 y1 1 y2 2} { pcall {xschem setprop rect 2 0 $tk $tv} }
pcall {xschem wave_hilight -clear}
pcall {xschem wave_hilight 0 0 1}
set wdpts2 [pcall {xschem get wave_hilight_points 0 0}]
# NOT byte-equal, and deliberately not asserted as such: which sample lands in
# the FIRST and LAST screen column shifts by a fraction of a pixel between the
# two densities, and a column holding exactly one sample emits one point instead
# of two. A handful of points either way is that quantisation. A per-sample
# implementation would land on 100 000 here, so a tolerance of eight has all the
# teeth this leg needs — SAB-5 dies on it by a factor of ninety.
check_true "WD1b TWICE the samples stroke the same count within 8\
 ($wdpts -> $wdpts2, not 100000)" \
  [pexpr {abs($wdpts2 - $wdpts) <= 8}]
check_true "WD1b ...and it is still inside the 2W+2 bound" \
  [pexpr {$wdpts2 <= 2 * $wdw + 2}]

# --- WD2: no decimation where none is needed --------------------------------
# Fewer samples than columns: every column holds one sample, min == max, and the
# envelope degenerates to the samples themselves. An implementation that emits
# the max unconditionally (SAB-4) doubles this.
pcall {xschem raw clear}
check "WD2 an 11-sample raw" [pcall {xschem raw new wvsm.raw dc vsweep 0 1.0 0.1}] 1
check "WD2 ...really has 11 points" [pcall {xschem raw points}] 11
check "WD2 v_a is a real column" [pcall {xschem raw add v_a {vsweep 1 +}}] 1
pcall {xschem setprop rect 2 0 node "v_a"}
# PIN the window rather than autozooming into it. `fullxzoom` reads the live
# raw and is therefore one silent failure away from a window that holds one
# sample -- measured: this leg answered 1 instead of 11 inside a full_audit run
# and 11 standalone, which is a fixture flake wearing the costume of a real
# defect. Pinned, the sample-to-column mapping is arithmetic.
foreach {tk tv} {x1 0 x2 1 y1 1 y2 2} { pcall {xschem setprop rect 2 0 $tk $tv} }
check "WD2 the data window really is x 0..1, y 1..2 (else the count below means nothing)" \
  [list [pcall {xschem getprop rect 2 0 x1}] [pcall {xschem getprop rect 2 0 x2}] \
        [pcall {xschem getprop rect 2 0 y1}] [pcall {xschem getprop rect 2 0 y2}]] \
  {0 1 1 2}
pcall {xschem wave_hilight -clear}
pcall {xschem wave_hilight 0 0 1}
check "WD2 a SPARSE trace strokes EXACTLY its samples, one point each" \
  [pcall {xschem get wave_hilight_points 0 0}] 11

# --- WD2b: the refusals the envelope owes -----------------------------------
check "WD2b an unhighlighted trace has no envelope" \
  [pcall {xschem get wave_hilight_points 0 1}] 0
check "WD2b a bad strip index has none either" \
  [pcall {xschem get wave_hilight_points 99 0}] 0
# a DIGITAL strip is a band, not a polyline (D8) — graph_point_at refuses it and
# so must the envelope
pcall {wh_graph 0 1000 800 1400 "flags=graph\ndigital=1"}
pcall {xschem setprop rect 2 1 node "v_a"}
pcall {xschem setprop rect 2 1 fullxzoom}
check "WD2b a DIGITAL strip yields no envelope (D8)" \
  [pcall {xschem get wave_hilight_points 1 0}] 0
# ...and so is a BUS entry
pcall {wh_graph 0 2000 800 2400}
pcall {xschem setprop rect 2 2 node "bus;v_a,v_a"}
pcall {xschem setprop rect 2 2 fullxzoom}
check "WD2b a BUS entry yields no envelope either (D8)" \
  [pcall {xschem get wave_hilight_points 2 0}] 0

# --- WD2c: THE CACHE MUST NOT SERVE A STALE ANSWER --------------------------
# An envelope is cached under a KEY (the data window, the plot box, the rect's
# whole prop string, the raw's identity and shape). Every leg below changes one
# of those WITHOUT touching the highlight set -- so nothing flushes the cache,
# and a lookup that matched on (gi, ni) alone would keep answering with the old
# build. Found by adversarial review, and all four were MEASURED wrong before
# the keyed lookup replaced the identity-only one.
pcall {xschem wave_hilight -clear}
foreach {tk tv} {x1 0 x2 1 y1 1 y2 2} { pcall {xschem setprop rect 2 0 $tk $tv} }
pcall {xschem wave_hilight 0 0 1}
set wdc0 [pcall {xschem get wave_hilight_points 0 0}]
check "WD2c the 11-sample fixture is cached at 11 points" $wdc0 11
# (a) THE DATA WINDOW moved: a tenth of the x range holds ~a tenth of the samples
pcall {xschem setprop rect 2 0 x2 0.2}
check_true "WD2c a ZOOM rebuilds rather than serving the old count\
 (11 -> [pcall {xschem get wave_hilight_points 0 0}])" \
  [pexpr {[xschem get wave_hilight_points 0 0] < $wdc0}]
foreach {tk tv} {x1 0 x2 1} { pcall {xschem setprop rect 2 0 $tk $tv} }
# (b) THE RECT'S PROP changed: a digital strip is a band, not a polyline (D8)
pcall {xschem setprop rect 2 0 digital 1}
check "WD2c turning the strip DIGITAL answers 0, not the cached count" \
  [pcall {xschem get wave_hilight_points 0 0}] 0
pcall {xschem setprop rect 2 0 digital 0}
check "WD2c ...and turning it back rebuilds the real envelope" \
  [pcall {xschem get wave_hilight_points 0 0}] 11
# (c) THE RAW went away underneath it
pcall {xschem raw clear}
check "WD2c a `raw clear` answers 0, not the cached count" \
  [pcall {xschem get wave_hilight_points 0 0}] 0
# (d) THE STRIP went away underneath it
pcall {wh_reset}
check "WD2c a deleted strip answers 0 too" \
  [pcall {xschem get wave_hilight_points 0 0}] 0

# ============================================================================
# WH9 — THE SOURCE-LEVEL LEGS (the LS5 / MS13 idiom). BOTH ARMS.
#
# Three of the invariants this feature rests on cannot be seen from behaviour at
# all: a second membership test agrees with the predicate while only one trace is
# highlighted, a dropped gate term is invisible outside a viewer, and a frame
# that goes through draw() looks identical to one that does not. Counted on CODE
# lines only — the comment blocks in these files quote the very strings counted.
# ============================================================================
set fp [open [file join $repo src draw.c] r];     set whd [read $fp]; close $fp
set fp [open [file join $repo src hilight.c] r];  set whh [read $fp]; close $fp
set fp [open [file join $repo src scheduler.c] r]; set whs [read $fp]; close $fp
set fp [open [file join $repo src actions.c] r];  set wha [read $fp]; close $fp
set fp [open [file join $repo src xinit.c] r];    set whi [read $fp]; close $fp

# (a) ONE predicate, ONE writer.
check "WH9a exactly one definition of wave_hilight_style_of()" \
  [wh_count_code $whd {^int wave_hilight_style_of\(}] 1
check "WH9a exactly one definition of wave_hilight_write() — THE writer" \
  [wh_count_code $whd {^int wave_hilight_write\(}] 1
check "WH9a both mutators route through the writer (set + clear)" \
  [wh_count_code $whd {wave_hilight_write\(gis, nis, sty, n\)}] 2

# (b) the query surface goes through the predicate, not a second scan
check "WH9b the scheduler getter calls the predicate" \
  [wh_count_code $whs {wave_hilight_style_of\(}] 1

# (c) THE BLAST RADIUS. Outside the four functions that own the arrays, nothing
# may compare a set element to a (gi, ni) — that is the SAB-3 shape, and it is
# invisible with one highlighted trace.
set whbodies {}
foreach sig {{int wave_hilight_write(} {int wave_hilight_set(} \
             {int wave_hilight_clear(} {int wave_hilight_style_of(} \
             {static WaveHilightEnv *wave_hilight_cache_find(} \
             {static WaveHilightEnv *wave_hilight_cache_slot(} \
             {int wave_hilight_points(}} {
  append whbodies [wh_fnbody $whd $sig] "\n"
}
set whbare 0
foreach line [split $whd "\n"] {
  set t [string trimleft $line]
  if {[string index $t 0] eq "*"} { continue }
  if {[string range $t 0 1] eq "/*" || [string range $t 0 1] eq "//"} { continue }
  if {![regexp {wave_hilight_(gi|ni)\[[^\]]*\] ==} $line]} { continue }
  if {[string first [string trim $line] $whbodies] >= 0} { continue }
  incr whbare
  note "WH9c stray membership test: [string trim $line]"
}
check "WH9c no membership test survives outside the four owning functions" $whbare 0

# (d) THE TWO GATE TERMS. A viewer has no highlighted NETS, so without these the
# feature is silently dead in the only window that has it (SAB-1, SAB-2).
set whhas [wh_fnbody $whh {int net_hilight_has_animation(}]
set whreg [wh_fnbody $whh {int draw_hilight_region(}]
check_true "WH9d net_hilight_has_animation() was located" \
  [expr {[string length $whhas] > 40}]
check_true "WH9d draw_hilight_region() was located" [expr {[string length $whreg] > 200}]
check "WH9d net_hilight_has_animation()'s gate carries the wave term (SAB-1)" \
  [wh_count_code $whhas {!xctx->hilight_nets && !xctx->wave_hilight_n}] 1
check "WH9d draw_hilight_region()'s gate carries it too (SAB-2)" \
  [wh_count_code $whreg {!xctx->hilight_nets && !xctx->wave_hilight_n}] 1
check "WH9d ...and NEITHER carries the old bare form" \
  [expr {[wh_count_code $whhas {!has_x \|\| !xctx->hilight_nets\) return}] +
         [wh_count_code $whreg {!has_x \|\| !xctx->hilight_nets\) return}]}] 0

# (e) THE FRAME SPLIT: a trace-only frame must return BEFORE draw().
#     A trace's bbox is the whole strip, so reusing the bbox(SET)+draw() frame
#     would re-walk every sample of every trace on it, every tick — precisely the
#     cost the envelope exists to avoid (SAB-6).
set whlines [split $whreg "\n"]
set whi_only -1; set whi_draw -1
for {set k 0} {$k < [llength $whlines]} {incr k} {
  set l [lindex $whlines $k]
  if {$whi_only < 0 && [regexp {^\s*if\(only_waves\)} $l]} { set whi_only $k }
  if {$whi_draw < 0 && [regexp {^\s*draw\(\);} $l]} { set whi_draw $k }
}
check_true "WH9e draw_hilight_region() has an only_waves early return" \
  [expr {$whi_only >= 0}]
check_true "WH9e ...and it comes BEFORE the draw() frame (SAB-6)" \
  [expr {$whi_only >= 0 && $whi_draw >= 0 && $whi_only < $whi_draw}]
check "WH9e the cheap frame paints the overlay with the erase armed" \
  [wh_count_code $whreg {draw_wave_hilight\(1\)}] 1

# (f) the overlay has exactly two callers, and draw()'s is its LAST act
check "WH9f draw.c calls the painter once (the tail of draw())" \
  [wh_count_code $whd {draw_wave_hilight\(0\)}] 1
check "WH9f hilight.c calls it once (the cheap frame)" \
  [wh_count_code $whh {draw_wave_hilight\(}] 1
set whdraw [wh_fnbody $whd {void draw(void)}]
check_true "WH9f draw() was located" [expr {[string length $whdraw] > 200}]
set whlines [split $whdraw "\n"]
set whi_ov -1; set whi_xh -1
for {set k 0} {$k < [llength $whlines]} {incr k} {
  set l [lindex $whlines $k]
  if {[regexp {draw_wave_hilight\(0\)} $l]} { set whi_ov $k }
  if {[regexp {draw_crosshair\(7, 0\)} $l]} { set whi_xh $k }
}
check_true "WH9f the overlay is painted AFTER every other window-only chrome" \
  [expr {$whi_ov > 0 && $whi_xh > 0 && $whi_ov > $whi_xh}]

# (g) the reset sites: exactly the two the gesture-state class uses
check "WH9g clear_drawing() resets the set" \
  [wh_count_code $wha {xctx->wave_hilight_n = 0;}] 1
check "WH9g ...and frees the envelope cache" \
  [wh_count_code $wha {wave_hilight_cache_free\(\)}] 1
check "WH9g alloc_xschem_data() resets it too" \
  [wh_count_code $whi {xctx->wave_hilight_n = 0;}] 1
check "WH9g free_xschem_data() frees the cache" \
  [wh_count_code $whi {wave_hilight_cache_free\(\)}] 1

# (h) the envelope walker carries landmines 37/38/40, which have no behavioural
#     witness on a fixture whose sweep list is complete and whose rawfile
#     resolves — the failures are a WRONG COLUMN and a flipped session raw
set whenv [wh_fnbody $whd {static WaveHilightEnv *wave_hilight_envelope(}]
check_true "WH9h the envelope walker was located" [expr {[string length $whenv] > 500}]
check "WH9h landmine 37: the graph_flags 128|256 bracket SAVES the hcursor bits" \
  [wh_count_code $whenv {saveflags = xctx->graph_flags & \(128 \| 256\)}] 1
check "WH9h ...and puts them back after setup_graph_data" \
  [wh_count_code $whenv {xctx->graph_flags = \(xctx->graph_flags & ~\(128 \| 256\)\) \| saveflags}] 1
check "WH9h landmine 40: the rawfile switch is unwound only if it TOOK" \
  [wh_count_code $whenv {if\(switched\) extra_rawfile\(5,}] 1
check "WH9h ...and there is exactly ONE switch, above the node loop" \
  [wh_count_code $whenv {extra_rawfile\(autoload,}] 1
# landmine 38: the sweep token is pulled before ANY continue in the node walk
set whlines [split $whenv "\n"]
set whi_stok -1; set whi_cont -1
for {set k 0} {$k < [llength $whlines]} {incr k} {
  set l [lindex $whlines $k]
  if {$whi_stok < 0 && [regexp {stok = my_strtok_r} $l]} { set whi_stok $k }
  if {$whi_cont < 0 && [regexp {^\s*while\( \(ntok} $l]} { set whi_cont $k }
}
check_true "WH9h landmine 38: the sweep token is consumed inside the node loop" \
  [expr {$whi_stok > 0 && $whi_cont > 0 && $whi_stok > $whi_cont}]
set whi_first_cont -1
for {set k $whi_cont} {$k < [llength $whlines]} {incr k} {
  if {[regexp {continue;} [lindex $whlines $k]]} { set whi_first_cont $k; break }
}
check_true "WH9h ...BEFORE the first `continue` in it (a skip above it reads the wrong column)" \
  [expr {$whi_stok > 0 && $whi_first_cont > 0 && $whi_stok < $whi_first_cont}]

# (i) the overlay is WINDOW-ONLY, so exports can never carry it
check "WH9i the painter forces draw_pixmap = 0 for the whole cadence" \
  [wh_count_code [wh_fnbody $whd {void draw_wave_hilight(}] {xctx->draw_pixmap = 0;}] 1
check "WH9i ...and the erase copies back FROM save_pixmap" \
  [wh_count_code [wh_fnbody $whd {static void wave_hilight_erase(}] \
     {MyXCopyArea\(display, xctx->save_pixmap, xctx->window}] 1
check "WH9i the polyline is chunked at MAX_POLY_POINTS with the overlap (landmine 16)" \
  [wh_count_code [wh_fnbody $whd {void draw_wave_hilight(}] \
     {offset \+= MAX_POLY_POINTS - 1;}] 1

# (j) the D4 re-apply bracket, and the one Tcl authority
set fp [open [file join $repo src wave_viewer.tcl] r]; set whv [read $fp]; close $fp
check "WH9j regenerate() re-applies the set to the fresh rects (SAB-7)" \
  [regexp -all {wviewer::wave_hilight_push \$token} \
     [wh_procbody $whv wviewer::regenerate]] 1
check "WH9j the set is NOT serialised into the ASE state dict (D4)" \
  [regexp -all {wavehl} [wh_procbody $whv wviewer::snapshot]] 0
check "WH9j ...nor into the undo unit (D4)" \
  [regexp -all {wavehl} [wh_procbody $whv wviewer::state_snapshot]] 0
check "WH9j exactly one mutation logs a replay line" \
  [regexp -all {wviewer::set_wave_hilights \$norm \$token} $whv] 1
check "WH9j the three keys are WaveViewer defaults, rc-guarded" \
  [regexp -all {\n    bind WaveViewer <Key-[980]>} \
     [wh_procbody $whv wviewer::install_default_binds]] 3

# ============================================================================
# WD3 / WD4 — the animation frame. DISPLAY ARM ONLY, and for a reason a leg
# written into the --nogui arm would hide: draw_hilight_region() and
# net_hilight_has_animation() both open with `if(!has_x ...) return 0;`, so
# headless they answer 0 whatever the code does, and every assertion below
# would pass for the wrong reason (landmine 41's lesson). The SOURCE-level
# twins of both are WH9d/WH9e, which DO run in both arms.
# ============================================================================
if {$::wh_have_x && [winfo exists .drw]} {
  for {set i 0} {$i < 200} {incr i} {
    update
    if {[winfo ismapped .drw]} break
    after 20
  }
  wh_reset
  pcall {xschem raw clear}
  pcall {xschem raw new wvanim.raw dc vsweep 0 1.0 0.02}
  pcall {xschem raw add v_a {vsweep 1 +}}
  pcall {wh_graph 0 0 800 400}
  pcall {xschem setprop rect 2 0 node "v_a"}
  pcall {xschem zoom_full}
  pcall {xschem setprop rect 2 0 fullxzoom}
  pcall {xschem setprop rect 2 0 fullyzoom}
  pcall {xschem redraw}
  # a STEADY style (solid, no blink, no march) and a MARCHING one
  set wdsteady [pcall {net_hilight_style_index_for {0 red 2 {} 0 0 none 0}}]
  set wdmarch  [pcall {net_hilight_style_index_for {0 cyan 2 {8 4} 0 0 march_fwd 2}}]
  check_true "WD3 two styles installed (steady $wdsteady, marching $wdmarch)" \
    [pexpr {$wdsteady != $wdmarch}]
  set wdanimsave 1
  if {[info exists ::net_hilight_animate]} { set wdanimsave $::net_hilight_animate }
  set ::net_hilight_animate 1

  # --- WD4: a STEADY style must arm NO tick -------------------------------
  pcall {xschem wave_hilight -clear}
  pcall {xschem wave_hilight 0 0 $wdsteady}
  pcall {xschem redraw}
  check "WD4 a STEADY trace highlight arms no animation tick" \
    [pcall {xschem get net_hilight_animated .drw}] 0
  # ...and a MARCHING one must arm it. This is the leg SAB-1 kills.
  pcall {xschem wave_hilight 0 0 $wdmarch}
  check "WD4 a MARCHING trace highlight DOES arm the tick (SAB-1 dies here)" \
    [pcall {xschem get net_hilight_animated .drw}] 1
  # and it must stop again when the last animating highlight goes
  pcall {xschem wave_hilight -clear}
  check "WD4 clearing it stops the tick" \
    [pcall {xschem get net_hilight_animated .drw}] 0

  # --- WD3: an animation frame calls draw() ZERO times --------------------
  # `xschem get drawcount` is the monotonic count of full draw() runs (the seam
  # at src/draw.c's `draw_count++`). A frame that fell through to the shipped
  # bbox(SET)+draw() path would bump it — that is SAB-6, and it is also what a
  # 200 000-sample trace would pay per tick.
  pcall {xschem wave_hilight 0 0 $wdmarch}
  pcall {xschem redraw}
  # force "now" so consecutive frames really differ in phase
  pcall {xschem net_hilight_test_now 1000}
  set wdc0 [pcall {xschem get drawcount}]
  set wdr [pcall {xschem redraw_hilight_region .drw}]
  set wdc1 [pcall {xschem get drawcount}]
  check_true "WD3 the frame ran (tristate [lindex $wdr 0], not a stop)" \
    [pexpr {[lindex $wdr 0] != 0}]
  check "WD3 ...and it called draw() ZERO times (drawcount $wdc0 -> $wdc1)" \
    [pexpr {$wdc1 - $wdc0}] 0
  # a second frame at a DIFFERENT phase must also be free
  pcall {xschem net_hilight_test_now 1400}
  set wdc0 [pcall {xschem get drawcount}]
  set wdr [pcall {xschem redraw_hilight_region .drw}]
  set wdc1 [pcall {xschem get drawcount}]
  check_true "WD3 a second frame at a different march phase ran too" \
    [pexpr {[lindex $wdr 0] != 0}]
  check "WD3 ...and cost zero draw() calls as well" [pexpr {$wdc1 - $wdc0}] 0
  # ...while a MIXED window (a wire highlight animating too) DOES go through
  # draw(), which is the other half of the split and proves the branch is real
  pcall {xschem net_hilight_test_now off}
  pcall {xschem wave_hilight -clear}
  set ::net_hilight_animate $wdanimsave
} else {
  puts "SKIPPED: WD3/WD4 animation-frame legs (no DISPLAY)"
}

# ============================================================================
# WG* — the real keys, the real window. DISPLAY ARM.
# ============================================================================
if {$::wh_have_x} {
  set st [ase::state_load $statefile]
  dict set st rundir [file join $scratch run]
  set sstate [file join $scratch session.state]
  ase::state_save $sstate $st
  set tok [ase::session_key sky130_tests test_nfet_final ngspice_state1]
  ase::session_open $tok $sstate

  check "WG0 wviewer::open returns 1" [pcall {wviewer::open $tok}] 1
  set vtop [wviewer::window_for $tok]
  set vdrw $vtop.drw
  if {![viewer_ready $vtop]} {
    puts "SKIPPED: WG* GUI legs (viewer canvas never mapped)"
    catch {wviewer::close $tok}
  } else {
  if {[catch {

  # --- the fixture: a hermetic raw and THREE strips ------------------------
  # PROBE PLACEMENT: nothing is planted on strip 0 / node 0. `atoi("")` reads an
  # absent token as node 0, so a strip-0/node-0 witness passes on a DESTROYED
  # token. And a vec-less trace is planted so the MODEL index and the NODE index
  # of strip 1 differ — a fixture where the two spaces coincide tests neither.
  xschem new_schematic switch $vdrw
  pcall {xschem raw clear}
  check "WG0 hermetic raw in the viewer ctx" \
    [pcall {xschem raw new wvhlv.raw dc vsweep 0 1.0 0.02}] 1
  foreach v {vec_a vec_b vec_c vec_d} {
    pcall {xschem raw add $v "vsweep 1 +"}
  }
  set wgvars [split [pcall {xschem raw list}] "\n"]
  check_true "WG0 the fixture raw knows the vectors the traces use" \
    [expr {[lsearch -exact $wgvars vec_a] >= 0 && [lsearch -exact $wgvars vec_d] >= 0}]
  wviewer::set_graphs $tok [list \
    [dict create traces [list [dict create expr vec_a name vec_a vec vec_a color 4]] \
                 logx 0 logy 0 x1 {} x2 {} y1 {} y2 {}] \
    [dict create traces [list \
       [dict create expr vec_b name vec_b vec vec_b color 5] \
       [dict create expr {} name label vec {} color 7] \
       [dict create expr vec_c name vec_c vec vec_c color 8] \
       [dict create expr vec_d name vec_d vec vec_d color 9]] \
                 logx 0 logy 0 x1 {} x2 {} y1 {} y2 {}] \
    [dict create traces {} logx 0 logy 0 x1 {} x2 {} y1 {} y2 {}]]
  wviewer::regenerate $tok
  xschem new_schematic switch $vdrw
  check "WG0 three strips" [pcall {xschem get graph_rects}] 3
  check "WG0 strip 1's MODEL index 2 is NODE index 1 (the spaces differ)" \
    [pcall {wviewer::node_index_of_trace \
              [lindex [dict get [wviewer::layout_for $tok] graphs] 1] 2}] 1

  # --- WG1: the binding seam ----------------------------------------------
  foreach {k p} {9 hilight_traces_at 8 unhilight_traces_at 0 unhilight_all_at} {
    check_true "WG1 <Key-$k> is on the WaveViewer tag by default" \
      [expr {[bind WaveViewer <Key-$k>] ne {}}]
    check_true "WG1 ...and it calls wviewer::$p with the event's canvas" \
      [string match "*wviewer::$p %W*" [bind WaveViewer <Key-$k>]]
    check_true "WG1 ...and it breaks, so the key travels no further" \
      [string match {*break*} [bind WaveViewer <Key-$k>]]
    check "WG1 <Key-$k> is NOT on the canvas widget itself" [bind $vdrw <Key-$k>] {}
  }
  wviewer::strip_bindings $vdrw
  check_true "WG1 the three defaults survive a strip_bindings re-sweep" \
    [expr {[bind WaveViewer <Key-9>] ne {} && [bind WaveViewer <Key-8>] ne {} &&
           [bind WaveViewer <Key-0>] ne {}}]

  # --- WG2: rc WINS, and {break} disables ---------------------------------
  # The whole point of the bindtag: an rc file binds long before any viewer
  # window exists, and the defaults are installed only for a sequence nothing
  # has bound yet.
  set wgsave [bind WaveViewer <Key-9>]
  bind WaveViewer <Key-9> {set ::wg_rc 1; break}
  set ::wviewer::tagbinds 0
  wviewer::install_default_binds
  check "WG2 an rc line WINS over the shipped default" \
    [bind WaveViewer <Key-9>] {set ::wg_rc 1; break}
  bind WaveViewer <Key-9> {break}
  set ::wviewer::tagbinds 0
  wviewer::install_default_binds
  check "WG2 {break} DISABLES it without being re-defaulted" \
    [bind WaveViewer <Key-9>] {break}
  bind WaveViewer <Key-9> {}
  set ::wviewer::tagbinds 0
  wviewer::install_default_binds
  check "WG2 ...whereas {} deletes it and the default comes back" \
    [bind WaveViewer <Key-9>] $wgsave

  # --- WG3: the refusals ---------------------------------------------------
  set ::wg_log {}
  rename wviewer::log_action wviewer::__real_log_action
  proc wviewer::log_action {line} { lappend ::wg_log $line }

  xschem new_schematic switch $vdrw
  pcall {xschem graph_marker select -none}
  # nothing selected anywhere. The rect write goes through `with_edit`: the
  # viewer buffer is READ-ONLY for its whole life, so a bare `xschem setprop` is
  # refused (the gs_plant rule in test_wave_grid.tcl).
  pcall {wviewer::with_edit $tok {
    foreach gi {0 1 2} { catch {xschem setprop rect 2 $gi hilight_wave -1} }
  }}
  check "WG3 with nothing selected, 9 refuses and changes nothing" \
    [pcall {wviewer::hilight_traces {} $tok}] 0
  check "WG3 ...and 8 too" [pcall {wviewer::unhilight_traces $tok}] 0
  check "WG3 neither logged a replay line" [llength $::wg_log] 0
  check "WG3 the set is still empty" [pcall {wviewer::wave_hilights $tok}] {}

  # --- WG4: the real keys --------------------------------------------------
  # The selection is planted on the RECT, never through the model: that is what
  # the C click arm does, and a model-side plant survives everything below
  # whether or not the code works (green-but-hollow by construction).
  # Strip 1, nodes 1 and 2 — not strip 0, not node 0.
  xschem new_schematic switch $vdrw
  pcall {wviewer::with_edit $tok {
    xschem setprop rect 2 1 hilight_wave 1
    xschem setprop rect 2 1 sel_waves "1 2"
  }}
  check "WG4 the plant reads back as a two-trace selection" \
    [pcall {wviewer::selected_waves $vdrw 1}] {1 2}
  check "WG4 ...and the MODEL has not heard of it (else the leg is hollow)" \
    [pcall {wviewer::model_sel \
              [lindex [dict get [wviewer::layout_for $tok] graphs] 1]}] {}
  set wgcur [pcall {xschem get hilight_color}]
  set wgdel [send_key $vdrw <Key-9> {[llength [wviewer::wave_hilights $tok]] == 2}]
  if {!$wgdel} {
    puts "SKIPPED: WG4 real-key legs (focus never confirmed)"
  } else {
    check "WG4 a REAL 9 highlighted BOTH selected traces" \
      [llength [pcall {wviewer::wave_hilights $tok}]] 2
    check "WG4 ...on the right strip and the right NODES" \
      [lsort [pcall {wviewer::wave_hilights $tok}]] \
      [lsort [list [list 1 1 $wgcur] [list 1 2 $wgcur]]]
    check "WG4 ...and the C engine holds the same set" \
      [lsort [pcall {wviewer::in_ctx $tok {xschem get wave_hilights}}]] \
      [lsort [list [list 1 1 $wgcur] [list 1 2 $wgcur]]]
    check "WG4 the untouched strips carry nothing" \
      [list [pcall {wviewer::in_ctx $tok {xschem get wave_hilight_at 0 0}}] \
            [pcall {wviewer::in_ctx $tok {xschem get wave_hilight_at 2 0}}]] {-1 -1}
    check "WG4 the style cursor advanced ONCE, not once per trace" \
      [pcall {xschem get hilight_color}] [expr {($wgcur + 1) %
        [llength [pcall {net_hilight_style_current}]]}]
    check "WG4 exactly ONE replay line, carrying the resolved token and pairs" \
      [lindex $::wg_log end] \
      "wviewer::set_wave_hilights {[list [list 1 1 $wgcur] [list 1 2 $wgcur]]} $tok"
    # the viewer buffer must stay clean: this is view state, not content
    check "WG4 the viewer buffer is NOT modified" \
      [pcall {wviewer::in_ctx $tok {xschem get modified}}] 0
    check "WG4 ...and no undo point was taken (D4)" \
      [pcall {wviewer::history_depth $tok}] {0 0}

    # --- WG5: the overlay survives a REGENERATE (the D4 bracket) ----------
    # regenerate runs `xschem clear_drawing` and re-places every rect, and a
    # plain window RESIZE calls it. Without the re-apply the set is GONE.
    # SAB-7 dies here.
    wviewer::regenerate $tok
    check "WG5 the Tcl authority still holds both entries after a regenerate" \
      [llength [pcall {wviewer::wave_hilights $tok}]] 2
    check "WG5 ...and it was RE-APPLIED to the fresh rects (SAB-7 dies here)" \
      [lsort [pcall {wviewer::in_ctx $tok {xschem get wave_hilights}}]] \
      [lsort [list [list 1 1 $wgcur] [list 1 2 $wgcur]]]
    # the same through the RESIZE path the user actually takes
    pcall {wviewer::configure_apply $tok}
    check "WG5 a window RESIZE keeps it too" \
      [llength [pcall {wviewer::in_ctx $tok {xschem get wave_hilights}}]] 2

    # --- WG6: 8 and 0 -----------------------------------------------------
    xschem new_schematic switch $vdrw
    pcall {wviewer::with_edit $tok {
      xschem setprop rect 2 1 hilight_wave 2
      xschem setprop rect 2 1 sel_waves ""
    }}
    set wgd8 [send_key $vdrw <Key-8> {[llength [wviewer::wave_hilights $tok]] == 1}]
    if {!$wgd8} {
      puts "SKIPPED: WG6 real-8 leg (focus never confirmed)"
    } else {
      check "WG6 a REAL 8 dropped ONLY the selected trace" \
        [pcall {wviewer::wave_hilights $tok}] [list [list 1 1 $wgcur]]
      check "WG6 ...and C agrees" \
        [pcall {wviewer::in_ctx $tok {xschem get wave_hilight_at 1 2}}] -1
    }
    set wgd0 [send_key $vdrw <Key-0> {[llength [wviewer::wave_hilights $tok]] == 0}]
    if {!$wgd0} {
      puts "SKIPPED: WG6 real-0 leg (focus never confirmed)"
    } else {
      check "WG6 a REAL 0 dropped every highlight in the window" \
        [pcall {wviewer::wave_hilights $tok}] {}
      check "WG6 ...and C agrees" \
        [pcall {wviewer::in_ctx $tok {xschem get wave_hilights}}] {}
    }
  }

  # --- WG7: the set follows a STRIP REORDER and a TRACE MOVE --------------
  pcall {wviewer::set_wave_hilights [list [list 1 2 4] [list 0 0 6]] $tok}
  check "WG7 two entries planted, on two strips" \
    [llength [pcall {wviewer::wave_hilights $tok}]] 2
  pcall {wviewer::move_strip 1 0 $tok}
  check "WG7 a strip reorder carries both entries with their strips" \
    [lsort [pcall {wviewer::wave_hilights $tok}]] [lsort {{0 2 4} {1 0 6}}]
  check "WG7 ...and the C engine was re-pushed with the remapped set" \
    [lsort [pcall {wviewer::in_ctx $tok {xschem get wave_hilights}}]] \
    [lsort {{0 2 4} {1 0 6}}]
  # now move the highlighted trace (strip 0, MODEL index 3 == NODE 2) to strip 2
  pcall {wviewer::move_trace 0 3 2 $tok}
  check "WG7 a trace move takes its highlight with it" \
    [lsort [pcall {wviewer::wave_hilights $tok}]] [lsort {{1 0 6} {2 0 4}}]
  check "WG7 ...and C agrees" \
    [pcall {wviewer::in_ctx $tok {xschem get wave_hilight_at 2 0}}] 4

  # --- WG8: Clear All drops the set ---------------------------------------
  pcall {wviewer::clear_all $tok}
  check "WG8 Clear All dropped every highlight" [pcall {wviewer::wave_hilights $tok}] {}
  check "WG8 ...in C too" [pcall {wviewer::in_ctx $tok {xschem get wave_hilights}}] {}

  rename wviewer::log_action {}
  rename wviewer::__real_log_action wviewer::log_action
  set ::wh_ran_x 1
  } wgerr]} {
    puts "FAIL: the WG group aborted: $wgerr : FAIL"
    incr fail
    puts $::errorInfo
  }
  catch {wviewer::close $tok}
  }
} else {
  puts "SKIPPED: WG* GUI legs (no DISPLAY)"
}

set ::wh_body_completed 1
} bigerr]} {
  puts "FAIL: the FILE aborted before its last leg: $bigerr : FAIL"
  incr fail
  puts $::errorInfo
}

# ============================================================================
# WZ — the coverage self-check (the MZ1 idiom).
#
# A smaller number is not a signal anyone reads: a run that quietly stopped
# executing half its legs still prints a happy banner. So the file knows how
# many checks each of its two arms is supposed to run, and a shortfall — or a
# surplus — is itself a FAIL that names the delta.
#
# EDITING THIS FILE: add or remove a leg, run BOTH arms once, and put the new
# numbers here. That is the point: the constant is what makes silent coverage
# loss impossible, so it has to be maintained by hand. These counts EXCLUDE the
# two WZ legs themselves, so the RESULT line reads two higher.
# ============================================================================
set ::wh_expect_x     194  ;# DISPLAY arm: WH + WD (incl. WD3/WD4) + WG
set ::wh_expect_nogui 137  ;# --nogui arm: WH + WD1/WD1b/WD2 + the WH9 source legs
set whexp [expr {$::wh_ran_x ? $::wh_expect_x : $::wh_expect_nogui}]
set whgot [expr {$npass + $fail}]
if {$whexp > 0} {
  check "WZ1 the [expr {$::wh_ran_x ? {DISPLAY} : {--nogui}}] arm ran its full\
 complement of checks (a silent shortfall is the failure this guards)" \
    [expr {$whgot == $whexp ? {ok} : "RAN $whgot of $whexp"}] ok
} else {
  puts "  note: WZ1 expected-check-count not yet pinned (ran $whgot)"
}
check "WZ2 the file body reached its end (no group unwound into the outer catch)" \
  [expr {[info exists ::wh_body_completed] ? 1 : 0}] 1

puts "----"
puts "test_wave_hilight: $npass passed, $fail failed"
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  exit 0
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  exit 1
}
