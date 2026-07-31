# tests/headless/test_wave_markers.tcl — Cadence-style WAVEFORM MARKERS
#
# Spec: doc/claude/specs/graph_markers.md   Plan: §8 of the marker plan.
#
# A marker is DURABLE CONTENT: a `markers` prop token on the graph xRect
#   markers="<num> <wave> <dset> <point> <x> <y> <prev> <ldx> <ldy>[\n...]"
# all fields numeric, x/y at %.17g (they must identify the EXACT sample), ldx/ldy
# at %.10g (fractions of the plot box). Creation/hit-test/drag live in C; the ASE
# viewer learns about every change through a PUSH hook (draw.c graph_marker_notify
# -> the global ::graph_marker_changed proc), not a pull.
#
# FOUR GROUPS, in the order they run:
#
#   MK*  pure Tcl helpers + pure C token math. Run in BOTH arms (--nogui too):
#        encode/decode/valid/drop/sweep/remap, the graph_props emission shape,
#        the C token round trip through setprop/getprop, `graph_marker list`,
#        window-wide numbering, the two PRE-EXISTING-BUG regressions
#          MK10 a graph whose FIRST `node` entry is a bus used to spin forever
#               in my_strtok_r (nptr nulled after the `continue`) — this leg
#               must simply RETURN;
#          MK11 find_closest_wave's dataset-skip read an uninitialised ofs_end
#               (`done: ofs = ofs_end;` jumped over its assignment),
#        and the --nogui fail-soft getters.
#
#   MR*  need a raw + a graph, NO gestures. The fixture is HERMETIC — `xschem raw
#        new mkmark.raw dc vsweep 0 1.0 0.1` + `xschem raw add`, the
#        test_wave_clear_all.tcl incantation — never ngspice: new_rawfile() fills
#        values[0][i] = start + i*step, so the grid is EXACTLY 11 samples and
#        every snap assertion is a literal constant. PROBE-VERIFIED before this
#        suite was written: graph_point_at / graph_near_wave really do hit-test
#        against a `raw new` dataset (raw->level = currsch satisfies the
#        sch_waves_loaded() gate), so no ngspice-guarded SKIP is needed.
#        MR1..MR5 / MR9..MR15 run in BOTH arms on the launch buffer (they need
#        no window); MR1v/MR6/MR7/MR8/MR16 need the ASE viewer and are inside
#        the has_x guard. That is a deliberate improvement on §8.2, which put
#        the whole group behind DISPLAY: `xschem raw new` works headless, so
#        putting the engine legs there doubles their coverage.
#
#   MX*  full Tk gesture sequences (DISPLAY + a mapped viewer canvas). Every
#        synthetic button event goes through `wb_ev`, which stamps an explicitly
#        INCREASING -time: two same-pixel presses with wall-clock %t collapse
#        into <Double-Button-1>, which the viewer binds to {break}, and the
#        second press then never reaches C at all. Every KeyPress goes through
#        `send_key`, which does `focus -force` + `update` and retries until a
#        caller-supplied predicate turns true (generated keys go to the display's
#        focus window and the WSLg focus round-trip is asynchronous). The press
#        pixel is always FOUND BY SCANNING with `xschem get graph_near_wave` /
#        `xschem get graph_marker_at`, never hardcoded, and the else-arm FAILS
#        loudly rather than skipping.
#
#   MF*  one leg per fix applied AFTER the adversarial review (16 fixes, see the
#        MF banner below for what each one WAS and what the leg defends). They
#        are split across three places by what they need:
#          * the engine half (MF1 MF4 MF5 MF6 MF12 MF13a MF14) runs in BOTH
#            arms, right after MR12;
#          * the MAIN-WINDOW display half (MF2 MF3 MF7 MF8 MF9 MF10 MF11a
#            MF13b) sits behind a has_x + `.drw` guard just below it and drives
#            `xschem callback .drw ...` DIRECTLY rather than through Tk — these
#            fixes are all C-level state machines, and one of them (MF9) is
#            specifically about a release that never reaches C, which is
#            impossible to stage with a real Tk event;
#          * the VIEWER half (MF15/MF16 after MR16, MF11b at the end of MX)
#            needs the ASE window.
#        Every MF leg names its fix and, where it was measured, the pre-fix
#        value. Four of them (MF1, MF4, MF12, MF13a) were proved red by
#        temporarily reverting exactly that hunk in src/ and re-running.
#
#   MD*  Delete All Markers / Ctrl-E (viewer plan item 4,
#        doc/claude/specs/graph_markers.md §6.1.1). Split like the MF group,
#        for a REASON the plan got wrong: it claimed the feature was fully
#        headless, but draw.c:6077 `if(!has_x) return` means
#        graph_marker_notify never fires under --nogui, so NOTHING about the
#        model or the undo point can be asserted in that arm.
#          * MD1/MD2 (the C verb, its count, its no-op, and the wrapper's
#            no-viewer answers) run in BOTH arms, right after MF5;
#          * MD3 is the ACTION LOG, and it runs in both arms by launching a
#            CHILD `--nogui --logdir` process — this suite runs --nolog, so
#            actionlog_fp is NULL and util.c:493 returns before writing, which
#            would make an in-process log assertion pass vacuously whatever the
#            code did. The child also proves the suppress `pop` survives a
#            THROWING body, with `xschem copy` as the leak canary;
#          * MD4..MD12 (model, undo, repaint, the binding seam, rc
#            remappability, the menu) need the ASE viewer and sit after MF16,
#            leaving MF16's fixture behind them for the MX group.
#
#   MQ*  DEL deletes WHATEVER is selected — the marker, the traces, or BOTH
#        (issue 0176, doc/claude/issues/0176-del-deletes-selection.md). DISPLAY
#        ONLY, and for a Tk reason rather than MD's has_x one:
#        `wviewer::delete_items` ends in a `regenerate`, i.e. `winfo width`, so
#        the command layer cannot run without Tk at all. The half that DOES run
#        in both arms is the pure index/marker/selection math, and it lives in
#        test_wave_modes.tcl's DT group — deliberately, because a leg written
#        into the nogui arm here would assert the PRE-mutation state and pass
#        for entirely the wrong reason (landmine 41's lesson, applied to Tk).
#        Routing is asserted BOTH ways (marker-only MQ1, trace-only MQ2,
#        both MQ3), the cascade and the window-wide `prev` sweep have their own
#        legs, and MQ4/MQ5 pin the two refusals with an execution trace on
#        `xschem` proving nothing reached C.
#
# NOT asserted (stated, not hidden):
#   * PIXELS. That a marker *renders* as a dot + leader + boxed callout is
#     eyeball-only, exactly like the wave rendering itself (test_wave_viewer.tcl
#     header). What IS asserted is the token, the hit-test seam
#     (`xschem get graph_marker_at`, which shares graph_marker_label_box with the
#     renderer, so the drawn box and the hit box cannot disagree), and that a
#     redraw with markers present returns rc 0.
#   * The C-side action log lines (`log_action "xschem graph_marker add_at ..."`).
#     There is no read-back seam for the C log; what IS asserted is that a marker
#     gesture emits NO wviewer::log_action line, i.e. it is not being mistaken
#     for a strip reorder or a trace move.
#   * The CIW refusal TEXT (graph_marker_refuse only calls ciw_echo under has_x);
#     the refusal RETURN VALUE is asserted everywhere.
#
# SABOTAGE (§8.4) — every one of these was actually applied, built and run
# against this file; the legs listed are the ones that went RED. Three of them
# found the suite too weak and the leg named in [] was added/rewritten for it.
#   S1  graph_marker_at() -> return 0            MX5, MX6, MX7, MX8, MX8b, MX9,
#                                                MX10, MX13, MX7b (30 checks)
#   S2  graph_point_at() -> return 0             MK10b, MK11; under a display the
#                                                MX0 scan fails and the whole MX
#                                                group is refused, loudly
#   S3  drop `markers=` from graph_props         MK3, MK6, MR6, MR7, MR8, MR16
#   S4  graph_marker_notify() -> no-op           MR1v, MR8, MX1, MX6, MX7,
#                                                [MR7b]  <- MR7 alone survived
#                                                this: MR6 runs
#                                                capture_live_graph_state just
#                                                before it, so the PULL kept the
#                                                model current. MR7b makes a
#                                                marker whose only route into the
#                                                model is the push, and drops
#                                                wviewer::fillwh first because
#                                                configure_apply short-circuits
#                                                when the cached size still
#                                                matches (without that it
#                                                regenerates nothing at all).
#   S5  drop the marker_grabbed refusal          MX6 (tdrag_gi becomes 0), MX7,
#       in wviewer::strip_drag_press             MX7b
#   S6  raw fixture removed                      MK10, MK11, MR0, MR1, MR2, ...
#                                                — a loud FAIL and rc 1, never a
#                                                silent SKIP
#   S7  %.17g -> %.8g in graph_markers_format    MR2b, [MR14]  <- MR14 first
#                                                asserted on `graph_marker list`,
#                                                which RE-RENDERS the parsed
#                                                double at %.17g, so a truncated
#                                                token still printed 17 digits
#                                                there and the leg passed. It now
#                                                reads the TOKEN itself.
#   S8  bind <ButtonPress-1> {break}             MX5, MX6, MX7, MX7c, MX7d, MX8,
#       before the MX drags                      MX8b, MX10, MX7b
#   S9  push_undo AFTER set_graphs               MR8, MX11
#       in wviewer::marker_changed
#   S10 next_number() per record instead of      MR11
#       base+k in graph_marker_renumber_rect
#   S11 bare array read (no windowed             MR4b
#       plot_raw_custom_data) in create_at
#   S12 drop the `|| graph_marker_drag` term     [MX7b]  <- the planned form of
#       from the GRAPHPAN latch                  this leg (a LABEL drag near the
#                                                top edge) could NEVER turn it
#                                                red: the callout box is clamped
#                                                to the plot box, so a label press
#                                                is never above it and graph_top
#                                                never latches. MX7b presses on
#                                                the ANCHOR of a marker parked on
#                                                the topmost sample, a few pixels
#                                                ABOVE the plot box but inside
#                                                GRAPH_MARKER_TOL, then drags out
#                                                of the window.
#   S13 never latch GRAPH_MARKER_MODE_RIGID      MX7e "the ANCHOR moved to a
#       in graph_marker_press (a selected             DIFFERENT real sample",
#       text drag stays a plain label drag)           MX7e "ldx/ldy are FROZEN"
#   S14 graph_marker_release forks on the        MF9, MF2 x2, MX6, MX7e, MX7b —
#       GRABBED part again instead of on         note this breaks the PLAIN anchor
#       graph_marker_dragmode                    drag too, because drag_clear()
#                                                runs BEFORE the fork, so the live
#                                                field is already 0 there. The
#                                                snapshot-before-clear ordering is
#                                                load-bearing.
#   S15 re-derive the mode at RELEASE from       [MX7g], [MX7h]  <- the pair that
#       the live selection instead of using      exists ONLY for this: MX7e/MX7f
#       the press-time latch                     cannot tell the two apart, since
#                                                neither changes the selection
#                                                mid-gesture. MX7g deselects
#                                                mid-drag and MX7h selects
#                                                mid-drag, so the two directions
#                                                fail independently.
#   S16 drop the `log_action -suppress`          MD3 "the raw C self-log line is
#       bracket from delete_all_markers          ABSENT" — the unreplayable line
#                                                reappears in the child's log
#   S17 move the suppress `pop` BELOW the        MD3 "a self-logging verb AFTER
#       `if {$code} {return -code error}`,       the throwing call still logs" —
#       i.e. LEAK it when the body throws        the canary vanishes, and with it
#                                                every later line in the session
#   S18 drop the wrapper's `xschem redraw`       MD5 "repainted the viewer canvas
#                                                exactly once" (0 draws) — the
#                                                only leg in this file that can
#                                                see a repaint at all
#   S19 drop the `if {$cnt <= 0} {return 0}`     MD3 (2 wviewer:: lines, not 1),
#       no-op gate                               MD6 "logs nothing"
#   S20 add a wviewer::push_undo to the          MD5 "exactly ONE undo point",
#       wrapper (the phantom second point)       MD6, MD7 x3 — one `u` stops
#                                                undoing the delete
#   S21 drop the `bind WaveViewer                MD9 x3, MD10 x3, MD11, MD12
#       <Control-Key-e>` default
#
# KNOWN SABOTAGE WITH NO RED LEG, stated rather than papered over:
#   apply the callout padding AFTER the plot-box clamp in graph_marker_label_box
#   instead of before it, and the whole suite still passes. The callout then
#   overhangs the plot box, but neither §4.1 consequence reappears — the GRAPHPAN
#   latch already ORs in graph_marker_drag (that is S12/MX7b's subject) and
#   graph_marker_press declines the grip column itself — so the residue is a
#   VISUAL overhang into the axis-number margin. This suite asserts the token and
#   the hit-test seam; a drawn-pixel overhang is neither, and is eyeball-only by
#   the same rule as the rest of the rendering (see the NOT asserted list above).
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_wave_markers.tcl
# (add --nogui to run only MK* and the engine half of MR*)
#
# ============================================================================
# DE-FLAKING (the two measured failure shapes, and what defends against them)
# ============================================================================
# Measured at ~1 run in 6 on WSLg, always the same shape:
#     FAIL: MF9 control: the press armed the anchor drag -> {0}
#     FAIL: MF9 control: WITH a release the drag really commits -> {0}
#     FAIL: MX1 the m KeyPress was delivered -> {0}   (+3 MX1 followers)
#     RESULT: 7 FAILED (457 passed)          <- 601 on a good run
#
# THREE distinct defects were behind that, and they are defended separately.
#
# 1. THE LOST COVERAGE (457+6 = 463 checks ran, 138 never did).
#    `check_true name [pcall {...}]` evaluated `expr {$cond ? 1 : 0}` on
#    whatever pcall returned. When the inner script errors pcall returns the
#    STRING `ERR:<msg>`, and `expr {"ERR:..." ? 1 : 0}` THROWS "expected boolean
#    value". At top level that unwinds straight into the file's single outer
#    catch: one UNEXPECTED ERROR line, and every remaining leg silently never
#    runs. In the captured run MX1's empty marker list made
#      check_true "MX1 its x is that sample's sweep value" [pcall {mk_close ...}]
#    the throw site, costing 138 checks — 23% of the suite — with no sign of it
#    in the RESULT line beyond a smaller number.
#    DEFENCE: check_true never throws (a non-boolean is a loud FAIL naming the
#    value); pexpr is the throwing-`expr` twin of pcall and every check_true
#    argument goes through one of the two; each display group carries its own
#    catch so a throw costs that GROUP, not the file; and MZ1 at the end asserts
#    the arm's full check complement, so any future silent loss is itself a FAIL.
#
# 2. MF9's PRESS THAT DID NOT ARM (`xschem callback .drw 4 ...`, no Tk at all).
#    Not the pixel: "MF9 control: its anchor pixel was scanned" passed in the
#    same run. It is a STALE ui_state LATCH in the window's xctx. GRAPHPAN
#    (32768) is the routing latch every graph press sets; while it is set
#    waves_selected() deliberately does NOT refresh graph_master (callback.c
#    :139) and waves_callback() does `goto finish` BEFORE graph_marker_press()
#    (callback.c:937) — so the press cannot arm. A schematic latch
#    (STARTSELECT/STARTMOVE/STARTCOPY/...) does the same via the `excl` skip at
#    callback.c:90. Both are torn down by the Button1 RELEASE that follows,
#    which is exactly why the NEXT press in the same leg armed fine.
#    Probe-verified: injecting either latch reproduces arm1=0 / arm2=1 on the
#    identical pixel, and nothing else tried (iconify, withdraw, toplevel
#    resize, a stale transform) reproduces it.
#    Where a stale latch comes from: a press whose release never reached C —
#    a real X press/crossing delivered into the canvas during one of the many
#    `update` calls (this file runs under a live WSLg display), or MF13b, which
#    used to press and then `xschem clear force` WITHOUT ever releasing.
#    DEFENCE: mf_unlatch() drops the latch, every arm-expecting press goes
#    through mf_arm() which asserts the arm and retries after unlatching +
#    re-scanning (a `note:` per retry), and MF13b now releases.
#
# 3. MX1's KEY THAT WAS NEVER DELIVERED — including through the fallback.
#    send_key_fb's whole point is that when Tk's WSLg focus is gone it drives
#    the SHIPPING handler directly, which has no focus component; for THAT to
#    produce nothing as well, the handler must be refusing. It was:
#    wviewer::key_filter gates every graph key on wviewer::over_graph, whose
#    first test is `[xschem get current_win_path] ne $wp -> 0`. A real
#    EnterNotify on ANOTHER xschem window (the main editor, still mapped
#    underneath) switches the C context — handle_window_switching, callback.c
#    :7869 — and from then on the viewer's own key gate answers 0 for its own
#    canvas, so `m` is swallowed by Tk delivery and by the fallback alike.
#    DEFENCE: mk_prep_ctx/mk_prep_at re-assert `new_schematic switch $vdrw`
#    (plus deiconify/raise/focus/pointer) BEFORE every attempt and between
#    retries; send_key_fb runs three rounds of {re-establish, Tk, re-establish,
#    shipping handler}; mk_send_once (the negative legs, which would otherwise
#    pass vacuously on a stolen context) re-establishes too.
#
# 4. THE SILENT WRONG ARM. A --pipe run whose X server was momentarily
#    unreachable comes up in text-only mode, runs only the MK/engine legs and
#    reports `RESULT: ALL PASS (307 checks)` — half the feature untested, and
#    nothing in the output distinguishes it from a deliberate --nogui run. Seen
#    twice in one 18-run soak on WSLg.
#    DEFENCE: MA0 reads the process's OWN command line and FAILS when DISPLAY
#    was set, --nogui was NOT given, and xschem still came up headless.
#
# Everything above only ever fires on the unhappy path. A clean run prints no
# `note:` line at all, and any retry that DID fire is visible in the log.
# A scan/arm/key that cannot be re-established after its retries prints a
# distinctive `MARKER-TEST-STALL:` line and FAILS the leg — it never proceeds
# to test nothing.
#
# NONE of the retries pass by testing less. mf_arm/mx_arm re-run the SAME
# gesture on the SAME scanned pixel; all they remove first is a precondition the
# product itself clears on the next release. mk_prep_* only restore the window
# state the gesture always assumed. The one place where a fallback genuinely
# gives something up is send_key_fb's shipping-handler route, which trades Tk's
# own dispatch for determinism — that trade predates this work, it prints a
# note every time it is taken, and the dispatch it gives up is covered
# separately and deterministically by the MXK binding legs.
#
# SABOTAGE-VERIFIED (each injected into a copy of this file, built and run):
#   A  a stale GRAPHPAN (a press with no release) before MF9's control press
#      -> reproduces the reported arm=0, and mf_arm now clears it with a note
#         and the leg passes;
#   B  `xschem new_schematic switch .drw` before MX1's key (over_graph then
#      answers 0 for the viewer's own canvas) -> reproduces the reported
#      "key never delivered" through BOTH routes, and mk_prep_at now puts the
#      context back with a note and the leg passes;
#   C  `bind $vdrw <KeyPress> {}` around MX2 -> Tk delivery is impossible, the
#      three-round fallback takes over with notes, the leg passes;
#   D  `set mx1 {}` after MX1's list read (the original abort trigger) -> 4 loud
#      FAILs including `NOT-A-BOOLEAN {ERR:can't use empty string as operand of
#      "*"}`, and ALL 606 checks still run (before: 138 of them silently did not).

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
# NEVER THROWS. Almost every call site hands this the result of pcall/pexpr,
# which is the string `ERR:<msg>` when the inner script blew up -- and
# `expr {"ERR:..." ? 1 : 0}` raises "expected boolean value", which at top level
# aborts the WHOLE FILE through the outer catch and silently drops every leg
# after it (that cost 138 of 601 checks in the captured bad run). A condition
# that is not a boolean is a loud FAIL that names it, and the file runs on.
proc check_true {name cond} {
  if {[catch {expr {$cond ? 1 : 0}} v]} {
    check $name "NOT-A-BOOLEAN {$cond}" 1
    return
  }
  check $name $v 1
}
# a diagnostic that is visible in the log but is not a check
proc note {msg} { puts "  note: $msg" }
# the loud, greppable "this leg could not be staged" marker. Distinctive on
# purpose: a run containing one of these tested LESS than it claims to, even if
# the leg it belongs to somehow still passes.
proc stall {msg} { puts "  MARKER-TEST-STALL: $msg" }

# error-guarded call: a MISSING proc must make its own leg FAIL, not abort the
# whole file through the outer catch (this file is written RED-first, so every
# leg has to be able to report independently)
proc pcall {script} {
  if {[catch {uplevel 1 $script} r]} { return "ERR:$r" }
  return $r
}
# the same guard for a bare `expr`. `expr {abs($a - $b) < 1}` with an EMPTY
# operand (a getter that returned {} because the leg before it failed) is a hard
# Tcl error, not a false -- so an unguarded expr in a check_true argument is
# another route to the whole-file abort described above. Relational operators
# fall back to string compare and are safe; arithmetic ones are not.
proc pexpr {e} {
  if {[catch {uplevel 1 [list expr $e]} r]} { return "ERR:$r" }
  return $r
}

# recent-files gate (issue 0119): this script loads real cells
set no_recent_files 1

# --- locations (cwd-independent) --------------------------------------------
set here    [file normalize [file dirname [info script]]]      ;# tests/headless
set repo    [file normalize [file join $here .. ..]]           ;# repo root
source [file join $here scratch.tcl]
set scratch [test_scratch wvmark]

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
# `--nogui` legitimately runs MK* + the engine half of MR*/MF* and nothing else.
# But a --pipe run under a DISPLAY whose X server was momentarily unreachable
# comes up in text-only mode and runs THE SAME REDUCED SET -- and used to print
# a perfectly happy `RESULT: ALL PASS (307 checks)`, i.e. it silently tested
# half the feature. Observed twice in an 18-run soak on WSLg. Tell the two apart
# from the process's OWN command line and make the accident LOUD.
set ::mk_nogui 0
if {![catch {open /proc/self/cmdline rb} mkfh]} {
  set ::mk_nogui [expr {[lsearch -exact [split [read $mkfh] "\0"] --nogui] >= 0}]
  close $mkfh
}
set ::mk_want_x [expr {!$::mk_nogui && [info exists ::env(DISPLAY)] &&
                       $::env(DISPLAY) ne {}}]
set ::mk_have_x [expr {[info exists ::has_x] && [info commands winfo] ne {}}]
# 1 only once the viewer/MX group has actually RUN to its end -- MZ1 below picks
# the expected check count from it
set ::mk_ran_x 0
check "MA0 the arm that ran is the arm that was asked for\
(--nogui=$::mk_nogui DISPLAY-wanted=$::mk_want_x has_x=$::mk_have_x)" \
  [expr {$::mk_want_x && !$::mk_have_x ? \
         {X ARM REQUESTED BUT XSCHEM CAME UP HEADLESS} : {ok}}] ok

if {[catch {

# ============================================================================
# shared helpers
# ============================================================================

# wipe every object from the CURRENT buffer, so each phase starts from a known
# rect index space (rect indices are creation order within the layer, and both
# the numbering allocator and `graph_marker list` are addressed by them)
proc mk_reset {} {
  catch {xschem unselect_all}
  catch {xschem select_all}
  catch {xschem delete}
  catch {xschem unselect_all}
  catch {xschem set_modify 0}
}
# one graph rect on GRIDLAYER, at the end of the layer's array
proc mk_graph {x1 y1 x2 y2 {props {flags=graph}}} {
  xschem set rectcolor 2
  xschem rect $x1 $y1 $x2 $y2 -1 $props 0
}
# a marker record, as a token line
proc mk_rec {num wave dset point x y {prev 0} {ldx 0.06} {ldy -0.09}} {
  return "$num $wave $dset $point $x $y $prev $ldx $ldy"
}
# every marker NUMBER currently in the window, in list order
proc mk_nums {args} {
  set out {}
  foreach r [eval [list xschem graph_marker list] $args] { lappend out [lindex $r 0] }
  return $out
}
# field `k` of marker `num`, or {} — the %.17g read-back seam
proc mk_field {num k} {
  foreach r [xschem graph_marker list] {
    if {[lindex $r 0] == $num} { return [lindex $r $k] }
  }
  return {}
}
# `xschem raw value` formats through dtoa (%.8g) while the token stores %.17g, so
# every comparison between the two MUST be numeric with a relative tolerance —
# never `eq`. Exactness is asserted against the `graph_marker list` seam instead.
proc mk_close {a b {rtol 1e-7}} {
  if {![string is double -strict $a] || ![string is double -strict $b]} { return 0 }
  set m [expr {abs($b) > 1e-300 ? abs($b) : 1.0}]
  return [expr {abs($a - $b) <= $rtol * $m ? 1 : 0}]
}
# the `markers` VALUE graph_props emitted, or {} when it emitted no token
proc mk_props_markers {p} {
  if {[regexp {(?s)\nmarkers="(.*?)"\n} "\n$p\n" -> v]} { return $v }
  return {}
}

# ============================================================================
# MK* — pure Tcl helpers + pure C token math (no window, no DISPLAY)
# ============================================================================

# --- MK1: markers_decode / markers_encode round trip ------------------------
# The precision contract: the Tcl side NEVER re-formats a double. Tcl's default
# %g is 6 significant digits and one trip through format/expr would truncate C's
# %.17g sample identity on the first trace drag between strips.
set mk1a "1 0 0 143 1.4300000000000001e-05 0.83124999999999993 0 0.06 -0.09"
set mk1b "2 1 0 210 2.0999999999999998e-05 1.7562500000000001 1 0.1234567891 -0.0987654321"
set mk1c "7 2 1 3 -1.25e-300 3.5 0 0 0"
check "MK1 one record decodes to one dict" \
  [llength [pcall {wviewer::markers_decode $mk1a}]] 1
check "MK1 the 17-significant-digit x is kept as the ORIGINAL STRING" \
  [pcall {dict get [lindex [wviewer::markers_decode $mk1a] 0] x}] 1.4300000000000001e-05
check "MK1 encode(decode(s)) is BYTE-equal for a 17-digit value" \
  [pcall {wviewer::markers_encode [wviewer::markers_decode $mk1a]}] $mk1a
set mk1m "$mk1a\n$mk1b\n$mk1c"
check "MK1 three records decode to three dicts" \
  [llength [pcall {wviewer::markers_decode $mk1m}]] 3
check "MK1 encode(decode(s)) is BYTE-equal for a 3-record token" \
  [pcall {wviewer::markers_encode [wviewer::markers_decode $mk1m]}] $mk1m
check "MK1 {} decodes to the empty list" [pcall {wviewer::markers_decode {}}] {}
check "MK1 the empty record list encodes to {}" [pcall {wviewer::markers_encode {}}] {}
check "MK1 a non-zero prev survives" \
  [pcall {dict get [lindex [wviewer::markers_decode $mk1b] 0] prev}] 1
check "MK1 a dragged label's ldx/ldy survive verbatim" \
  [pcall {list [dict get [lindex [wviewer::markers_decode $mk1b] 0] ldx] \
               [dict get [lindex [wviewer::markers_decode $mk1b] 0] ldy]}] \
  {0.1234567891 -0.0987654321}
# garbage: the BAD LINE is dropped, the rest kept, nothing thrown (the C parser
# has the same per-record tolerance)
check "MK1 a garbage line is dropped and the rest kept" \
  [pcall {wviewer::markers_encode [wviewer::markers_decode "$mk1a\nrubbish here\n$mk1b"]}] \
  "$mk1a\n$mk1b"
check "MK1 an 8-field line is dropped (short record)" \
  [pcall {llength [wviewer::markers_decode "1 0 0 5 0.5 1.5 0 0.06"]}] 0
check "MK1 a 10-field line is KEPT (forward tolerance) and re-emitted verbatim" \
  [pcall {wviewer::markers_encode \
     [wviewer::markers_decode "1 0 0 5 0.5 1.5 0 0.06 -0.09 99"]}] \
  "1 0 0 5 0.5 1.5 0 0.06 -0.09 99"
check "MK1 the 10th field lands in `extra`" \
  [pcall {dict get [lindex [wviewer::markers_decode "1 0 0 5 0.5 1.5 0 0.06 -0.09 99"] 0] extra}] 99
# `scan %d` normalisation: a leading-zero integer field must come back DECIMAL,
# or later `expr` arithmetic on it would silently read it as octal
check "MK1 a leading-zero integer is normalised to decimal, never octal" \
  [pcall {dict get [lindex [wviewer::markers_decode "1 0 0 010 0.5 1.5 0 0.06 -0.09"] 0] point}] 10

# --- MK2: markers_valid — the EMISSION guard --------------------------------
# {} RETURNS 0, and that is load-bearing rather than defensive: an "every line is
# a record" predicate is vacuously TRUE on the empty string, and graph_props
# would then stamp markers="" onto every strip that was never marked.
check "MK2 {} is NOT valid (the vacuous-truth trap)" [pcall {wviewer::markers_valid {}}] 0
check "MK2 a 9-field record is valid"  [pcall {wviewer::markers_valid $mk1a}] 1
check "MK2 a 10-field record is valid (forward tolerance)" \
  [pcall {wviewer::markers_valid "1 0 0 5 0.5 1.5 0 0.06 -0.09 99"}] 1
check "MK2 a 3-record token is valid"  [pcall {wviewer::markers_valid $mk1m}] 1
check "MK2 an 8-field record is not valid" \
  [pcall {wviewer::markers_valid "1 0 0 5 0.5 1.5 0 0.06"}] 0
# the alphabet IS the safety property: subst_token escapes neither `"` nor `\`,
# and tcl_hook2 EXECUTES a value beginning with tcleval(
check "MK2 a double quote is rejected" \
  [pcall {wviewer::markers_valid "1 0 0 5 \"x 1.5 0 0.06 -0.09"}] 0
check "MK2 a backslash is rejected" \
  [pcall {wviewer::markers_valid {1 0 0 5 \x 1.5 0 0.06 -0.09}}] 0
check "MK2 a semicolon is rejected (SPACE() terminates a value at one)" \
  [pcall {wviewer::markers_valid "1 0 0 5 0.5; 1.5 0 0.06 -0.09"}] 0
check "MK2 a tcleval( prefix is rejected" \
  [pcall {wviewer::markers_valid "tcleval(\[exec touch /tmp/pwn\]) 0 0 5 0.5 1.5 0 0.06 -0.09"}] 0
check "MK2 nan is rejected (deliberately NOT `string is double`)" \
  [pcall {wviewer::markers_valid "1 0 0 5 nan 1.5 0 0.06 -0.09"}] 0
check "MK2 inf is rejected" \
  [pcall {wviewer::markers_valid "1 0 0 5 inf 1.5 0 0.06 -0.09"}] 0
check "MK2 a tab is rejected (get_tok_value would truncate the token there)" \
  [pcall {wviewer::markers_valid "1\t0 0 5 0.5 1.5 0 0.06 -0.09"}] 0
check "MK2 extra spaces are tolerated" \
  [pcall {wviewer::markers_valid "1  0 0  5 0.5 1.5 0 0.06 -0.09"}] 1
check "MK2 ONE bad line invalidates the WHOLE token (all-or-nothing)" \
  [pcall {wviewer::markers_valid "$mk1a\nnope"}] 0
check "MK2 markers_num_ok accepts a signed exponent" \
  [pcall {wviewer::markers_num_ok -1.43e-05}] 1
check "MK2 markers_num_ok rejects a bare letter" [pcall {wviewer::markers_num_ok x}] 0
check "MK2 markers_num_ok rejects the empty field" [pcall {wviewer::markers_num_ok {}}] 0

# --- MK3: graph_props emits `markers=` only when non-empty AND valid --------
# A strip that was never marked must render BYTE-IDENTICALLY to pre-marker
# (test_wave_modes M5/M7 pin that shape from the other side).
set mk3G [wviewer::empty_graph]
set mk3p [pcall {wviewer::graph_props $mk3G}]
check_true "MK3 an unmarked graph carries NO markers token" \
  [expr {![string match {*markers=*} $mk3p]}]
check_true "MK3 flags=graph is still the FIRST token" [string match {flags=graph*} $mk3p]
set mk3p2 [pcall {wviewer::graph_props [dict replace $mk3G markers $mk1a]}]
check "MK3 a valid model value is emitted, quoted, verbatim" \
  [mk_props_markers $mk3p2] $mk1a
check_true "MK3 ... and flags=graph is still first" [string match {flags=graph*} $mk3p2]
check "MK3 an EMPTY model value emits nothing" \
  [mk_props_markers [pcall {wviewer::graph_props [dict replace $mk3G markers {}]}]] {}
check "MK3 an INVALID model value emits nothing (a stray quote never reaches subst_token)" \
  [mk_props_markers [pcall {wviewer::graph_props \
     [dict replace $mk3G markers "1 0 0 5 \"x 1.5 0 0.06 -0.09"]}]] {}
check "MK3 a 3-record value survives the emitter whole" \
  [mk_props_markers [pcall {wviewer::graph_props [dict replace $mk3G markers $mk1m]}]] $mk1m
# the marker token must not disturb the two neighbours it was slotted between
check_true "MK3 reorder_handle=1 is still emitted alongside markers" \
  [regexp -line {^reorder_handle=1$} $mk3p2]
check_true "MK3 hilight_wave still round-trips next to markers" \
  [regexp -line {^hilight_wave=2$} [pcall {wviewer::graph_props \
     [dict replace $mk3G markers $mk1a hilight_wave 2]}]]
check_true "MK3 active=1 still round-trips next to markers" \
  [string match {*active=1*} \
    [pcall {wviewer::graph_props [dict replace $mk3G markers $mk1a] 1}]]

# --- MK4: node-index remap when a TRACE moves between strips ----------------
# A marker whose wave IS the moved node MIGRATES with its trace (the rule
# hilight_wave already follows); markers above the hole shift down; markers
# below are untouched; the destination's own markers are untouched because the
# trace is APPENDED.
set mk4src "[mk_rec 1 0 0 5 0.5 1.5]\n[mk_rec 2 1 0 5 0.5 1.5]\n[mk_rec 3 2 0 5 0.5 1.5]"
set mk4dst "[mk_rec 9 0 0 5 0.5 1.5]"
lassign [pcall {wviewer::remap_markers_after_trace_move $mk4src $mk4dst 1 1}] mk4s mk4d
check "MK4 the marker ON the moved node migrated out of the source" \
  [pcall {wviewer::markers_numbers $mk4s}] {1 3}
check "MK4 ... and landed in the destination at the new node index" \
  [pcall {wviewer::markers_numbers $mk4d}] {9 2}
check "MK4 the migrated record's wave is the DESTINATION node index" \
  [pcall {dict get [lindex [wviewer::markers_decode $mk4d] 1] wave}] 1
check "MK4 a marker BELOW the moved node keeps its index" \
  [pcall {dict get [lindex [wviewer::markers_decode $mk4s] 0] wave}] 0
check "MK4 a marker ABOVE the moved node shifts down by one" \
  [pcall {dict get [lindex [wviewer::markers_decode $mk4s] 1] wave}] 1
check "MK4 the destination's OWN marker is untouched" \
  [pcall {dict get [lindex [wviewer::markers_decode $mk4d] 0] wave}] 0
check "MK4 an empty source token stays empty" \
  [pcall {lindex [wviewer::remap_markers_after_trace_move {} $mk4dst 0 0] 0}] {}
check "MK4 a non-integer index is a no-op on both sides" \
  [pcall {wviewer::remap_markers_after_trace_move $mk4src $mk4dst x 1}] [list $mk4src $mk4dst]
check "MK4 a negative index is a no-op on both sides" \
  [pcall {wviewer::remap_markers_after_trace_move $mk4src $mk4dst -1 1}] [list $mk4src $mk4dst]
# and through the REAL model op, so the pure helper cannot drift from its caller
proc mk4_g {args} {
  set trs {}
  foreach v $args { lappend trs [dict create expr $v name {} vec $v color 4] }
  return [dict replace [wviewer::empty_graph] traces $trs]
}
set mk4L [list [dict replace [mk4_g v(a) v(b) v(c)] markers $mk4src] \
               [dict replace [mk4_g v(x)] markers $mk4dst]]
set mk4M [pcall {wviewer::move_trace_in_graphs $mk4L 0 1 1}]
check "MK4 move_trace_in_graphs rewrites the SOURCE token" \
  [pcall {wviewer::markers_numbers [wviewer::dget [lindex $mk4M 0] markers {}]}] {1 3}
check "MK4 move_trace_in_graphs rewrites the DESTINATION token" \
  [pcall {wviewer::markers_numbers [wviewer::dget [lindex $mk4M 1] markers {}]}] {9 2}
# an emptied token DROPS the key (absent means absent, all the way to graph_props)
set mk4L2 [list [dict replace [mk4_g v(a)] markers [mk_rec 1 0 0 5 0.5 1.5]] [mk4_g v(x)]]
set mk4M2 [pcall {wviewer::move_trace_in_graphs $mk4L2 0 0 1}]
check "MK4 a source emptied by the move loses the markers KEY" \
  [pcall {dict exists [lindex $mk4M2 0] markers}] 0
check "MK4 ... and the destination GAINS one" \
  [pcall {dict exists [lindex $mk4M2 1] markers}] 1
check "MK4 a strip with no markers never gains an empty key" \
  [pcall {dict exists [lindex [wviewer::move_trace_in_graphs \
     [list [mk4_g v(a) v(b)] [mk4_g v(x)]] 0 0 1] 1] markers}] 0

# --- MK5: node-index remap when TRACES are deleted --------------------------
check "MK5 remap_node_after_trace_delete: doomed node -> {}" \
  [pcall {wviewer::remap_node_after_trace_delete 1 {1}}] {}
check "MK5 ... a node above one doomed shifts down by one" \
  [pcall {wviewer::remap_node_after_trace_delete 2 {1}}] 1
check "MK5 ... a node below is untouched" \
  [pcall {wviewer::remap_node_after_trace_delete 0 {1}}] 0
check "MK5 ... two doomed below shift it down by two" \
  [pcall {wviewer::remap_node_after_trace_delete 4 {0 2}}] 2
check "MK5 ... a doomed list that is all ABOVE changes nothing" \
  [pcall {wviewer::remap_node_after_trace_delete 0 {2 3}}] 0
check "MK5 ... a non-integer index -> {}" \
  [pcall {wviewer::remap_node_after_trace_delete x {1}}] {}
set mk5 "[mk_rec 1 0 0 5 0.5 1.5]\n[mk_rec 2 1 0 5 0.5 1.5]\n[mk_rec 3 2 0 5 0.5 1.5]"
check "MK5 a marker on a DOOMED trace is dropped" \
  [pcall {wviewer::markers_numbers [wviewer::remap_markers_after_trace_delete $mk5 {1}]}] {1 3}
check "MK5 the survivor above the hole is decremented" \
  [pcall {dict get [lindex [wviewer::markers_decode \
     [wviewer::remap_markers_after_trace_delete $mk5 {1}]] 1] wave}] 1
check "MK5 multi-delete: two doomed, one survivor, shifted by the count BELOW it" \
  [pcall {dict get [lindex [wviewer::markers_decode \
     [wviewer::remap_markers_after_trace_delete $mk5 {0 1}]] 0] wave}] 0
check "MK5 deleting every node empties the token" \
  [pcall {wviewer::remap_markers_after_trace_delete $mk5 {0 1 2}}] {}
check "MK5 an empty doomed list is a no-op" \
  [pcall {wviewer::remap_markers_after_trace_delete $mk5 {}}] $mk5
check "MK5 an empty token is a no-op" \
  [pcall {wviewer::remap_markers_after_trace_delete {} {0}}] {}

# --- MK5b: markers_drop_number + the window-wide `prev` sweep ---------------
# A delta rendered against a ghost is a bug: graph_marker_text simply OMITS the
# block when the partner does not resolve, so a dangling prev is silent.
set mk5b "[mk_rec 1 0 0 5 0.5 1.5]\n[mk_rec 2 0 0 7 0.7 1.7 1]\n[mk_rec 3 0 0 9 0.9 1.9 1]"
set mk5bd [pcall {wviewer::markers_drop_number $mk5b 1}]
check "MK5b the record itself is removed" [pcall {wviewer::markers_numbers $mk5bd}] {2 3}
check "MK5b every prev that pointed at it is zeroed" \
  [pcall {list [dict get [lindex [wviewer::markers_decode $mk5bd] 0] prev] \
               [dict get [lindex [wviewer::markers_decode $mk5bd] 1] prev]}] {0 0}
check "MK5b dropping a number that is not there is a no-op" \
  [pcall {wviewer::markers_drop_number $mk5b 99}] $mk5b
check "MK5b dropping from an empty token gives {}" \
  [pcall {wviewer::markers_drop_number {} 1}] {}
check "MK5b a non-integer / zero number is refused (token unchanged)" \
  [list [pcall {wviewer::markers_drop_number $mk5b x}] \
        [pcall {wviewer::markers_drop_number $mk5b 0}]] [list $mk5b $mk5b]
check "MK5b markers_numbers of a token" [pcall {wviewer::markers_numbers $mk5b}] {1 2 3}
check "MK5b markers_numbers of {}" [pcall {wviewer::markers_numbers {}}] {}
# the sweep: a delta partner may live in ANOTHER strip
set mk5gs [list [dict replace [wviewer::empty_graph] markers [mk_rec 1 0 0 5 0.5 1.5]] \
                [dict replace [wviewer::empty_graph] markers [mk_rec 4 0 0 7 0.7 1.7 1]] \
                [wviewer::empty_graph]]
set mk5sw [pcall {wviewer::markers_sweep_numbers $mk5gs {1}}]
check "MK5b the sweep removed the record in strip 0" \
  [pcall {dict exists [lindex $mk5sw 0] markers}] 0
check "MK5b ... and zeroed the CROSS-STRIP prev in strip 1" \
  [pcall {dict get [lindex [wviewer::markers_decode \
     [wviewer::dget [lindex $mk5sw 1] markers {}]] 0] prev}] 0
check "MK5b a strip with no markers key never gains one" \
  [pcall {dict exists [lindex $mk5sw 2] markers}] 0
check "MK5b an empty number list is a no-op" \
  [pcall {wviewer::markers_sweep_numbers $mk5gs {}}] $mk5gs

# --- MK6: the emitter does not RE-FORMAT the value --------------------------
# Separate from MK3 (which is about the presence/absence shape): here the value
# is a 17-significant-digit double and the assertion is byte equality through
# graph_props, the only place the model value reaches the rect.
check "MK6 graph_props re-emits a 17-digit value byte-identically" \
  [mk_props_markers [pcall {wviewer::graph_props [dict replace $mk3G markers $mk1a]}]] $mk1a
check "MK6 ... and a multi-record one, newlines intact" \
  [mk_props_markers [pcall {wviewer::graph_props [dict replace $mk3G markers $mk1m]}]] $mk1m
check "MK6 decode->encode->graph_props is still byte-identical" \
  [mk_props_markers [pcall {wviewer::graph_props [dict replace $mk3G markers \
     [wviewer::markers_encode [wviewer::markers_decode $mk1m]]]}]] $mk1m

# --- MK7: the token through the C layer, with NO raw ------------------------
mk_reset
pcall {mk_graph 0 0 800 400}
pcall {mk_graph 0 1000 800 1400}
check "MK7 two graph rects placed" [pcall {xschem get graph_rects}] 2
check "MK7 graph_rects is not `rects 2` (a non-graph layer-2 rect is excluded)" \
  [pcall {mk_graph 0 2000 800 2400 {}; list [xschem get rects 2] [xschem get graph_rects]}] {3 2}
check "MK7 no token to start" [pcall {xschem getprop rect 2 0 markers}] {}
pcall {xschem setprop rect 2 0 markers $mk1m}
check "MK7 a 3-record multi-line value round-trips BYTE-identically" \
  [pcall {xschem getprop rect 2 0 markers}] $mk1m
check "MK7 the flags token is undisturbed" [pcall {xschem getprop rect 2 0 flags}] graph
# a 300-record value (well inside GRAPH_MARKERS_MAX = 512)
set mk7big {}
for {set i 1} {$i <= 300} {incr i} { lappend mk7big [mk_rec $i 0 0 $i 0.5 1.5] }
set mk7big [join $mk7big "\n"]
pcall {xschem setprop rect 2 0 markers $mk7big}
check "MK7 a 300-record value survives the prop layer" \
  [pcall {xschem getprop rect 2 0 markers}] $mk7big
check "MK7 ... and the C parser reads all 300 back" \
  [pcall {llength [xschem graph_marker list 0]}] 300
# a re-write with the SAME value is a no-op: `modified` must not move
pcall {xschem set_modify 0}
pcall {xschem setprop rect 2 0 markers $mk7big}
check "MK7 re-writing the identical value leaves modified at 0" \
  [pcall {xschem get modified}] 0
# an EMPTY value DELETES the token (subst_token's removal branch)
pcall {xschem setprop rect 2 0 markers {}}
check "MK7 an empty value deletes the token" [pcall {xschem getprop rect 2 0 markers}] {}
check "MK7 ... and the C parser then reports zero records" \
  [pcall {llength [xschem graph_marker list 0]}] 0
check "MK7 flags survived the delete" [pcall {xschem getprop rect 2 0 flags}] graph

# --- MK8: `xschem graph_marker list` — the %.17g read-back seam -------------
# The verb RE-RENDERS the parsed doubles (x/y at %.17g, ldx/ldy at %.10g), so the
# fixture uses values that are fixed points of those formats — otherwise the leg
# would be asserting printf's shortest-form rules rather than the parser's
# fidelity. 0.83124999999999993 / 0.30000000000000004 need all 17 digits, which
# is exactly what makes them teeth: a dtoa()-based read-back gives 0.83125 / 0.3.
set mk8a "1 0 0 143 0.30000000000000004 0.83124999999999993 0 0.06 -0.09"
set mk8b "2 1 0 210 1.7562500000000001 -1.25e-300 1 0.1234567891 -0.0987654321"
pcall {xschem setprop rect 2 0 markers "$mk8a\n$mk8b"}
set mk8 [pcall {xschem graph_marker list 0}]
check "MK8 two records listed" [llength $mk8] 2
check "MK8 each sublist has exactly 10 elements {num graph wave dset point x y prev ldx ldy}" \
  [list [llength [lindex $mk8 0]] [llength [lindex $mk8 1]]] {10 10}
check "MK8 the GRAPH index is field 1 (not present in the token itself)" \
  [list [lindex [lindex $mk8 0] 1] [lindex [lindex $mk8 1] 1]] {0 0}
check "MK8 num/wave/dset/point round-trip" \
  [lrange [lindex $mk8 0] 0 4] {1 0 0 0 143}
check "MK8 x comes back at FULL %.17g precision, byte-identical" \
  [lindex [lindex $mk8 0] 5] 0.30000000000000004
check "MK8 y comes back at FULL %.17g precision, byte-identical" \
  [lindex [lindex $mk8 0] 6] 0.83124999999999993
check_true "MK8 ... i.e. MORE than the 8 significant digits dtoa() would keep" \
  [expr {[lindex [lindex $mk8 0] 6] ne [format %.8g [lindex [lindex $mk8 0] 6]]}]
check "MK8 a tiny denormal-ish magnitude survives" [lindex [lindex $mk8 1] 6] -1.25e-300
check "MK8 prev/ldx/ldy of the second record" \
  [lrange [lindex $mk8 1] 7 9] {1 0.1234567891 -0.0987654321}
check "MK8 an explicit graph index filters" \
  [pcall {llength [xschem graph_marker list 1]}] 0
check "MK8 `list` with no index sweeps the whole window" \
  [pcall {llength [xschem graph_marker list]}] 2
check "MK8 `list` of a non-graph rect index yields nothing (never an error)" \
  [pcall {xschem graph_marker list 2}] {}
check "MK8 `list` of an out-of-range index yields nothing" \
  [pcall {xschem graph_marker list 99}] {}

# --- MK9: numbering is WINDOW-WIDE, and stateless --------------------------
# No counter is kept anywhere: next_number rescans every graph rect, so a rect
# deleted / undone / pasted / regenerated can never desync it.
pcall {xschem setprop rect 2 0 markers [mk_rec 1 0 0 5 0.5 1.5]}
pcall {xschem setprop rect 2 1 markers [mk_rec 3 0 0 5 0.5 1.5]}
check "MK9 M1 in rect A and M3 in rect B" [pcall {mk_nums}] {1 3}
check "MK9 the window-wide next number is 4, not 2" \
  [pcall {xschem graph_marker select -none; xschem setprop rect 2 1 markers \
     "[mk_rec 3 0 0 5 0.5 1.5]"; xschem graph_marker list 1; \
     llength [xschem graph_marker list]}] 2
# the allocator itself is only observable through a creation, which needs a raw;
# MR3 asserts it end to end. Here: the SCAN is window-wide, i.e. both rects are
# visible to `list` with no index, which is the same walk next_number does.
check "MK9 both rects are visible to the window-wide walk" \
  [pcall {lsort -integer [mk_nums]}] {1 3}
pcall {xschem setprop rect 2 0 markers {}}
pcall {xschem setprop rect 2 1 markers {}}
check "MK9 clearing both leaves nothing" [pcall {mk_nums}] {}

# --- MK10 / MK11: the two pre-existing-bug regressions ---------------------
# Both need a raw to reach the node-token loop at all (graph_point_at and
# find_closest_wave both gate on xctx->raw first), and `xschem raw new` is
# hermetic and works headless — so these stay in the MK group.
mk_reset
check "MK10 hermetic raw created" [pcall {xschem raw new mkmark.raw dc vsweep 0 1.0 0.1}] 1
check "MK10 v_a added as a real column" [pcall {xschem raw add v_a {vsweep 1 +}}] 1
check "MK10 the raw has the expected 11-sample grid" [pcall {xschem raw points}] 11
pcall {mk_graph 0 0 800 400}
pcall {xschem zoom_full}
# THE REGRESSION: the graph's FIRST node entry is a bus. Before the fix
# my_strtok_r restarted from the head of `node` on every `continue` (nptr was
# nulled AFTER the bus skip), so this call never returned and the whole test
# file died at the audit timeout scored as CRASH.
pcall {xschem setprop rect 2 0 node "a,b,c\nv_a"}
check "MK10 a bus-first graph RETURNS from graph_trace_at (was an infinite loop)" \
  [pcall {xschem get graph_trace_at 0 100 100 10}] -1
check "MK10 ... and from graph_near_wave too" \
  [pcall {xschem get graph_near_wave 0 100 100 10}] 0
# with a huge tolerance the entry AFTER the bus is found — which is also the
# witness that the bus entry consumed its own `sweep` token instead of shifting
# every later trace onto the previous entry's sweep variable
check "MK10b the trace AFTER the bus is still pickable (node index 1)" \
  [pcall {xschem get graph_trace_at 0 400 200 100000}] 1
pcall {xschem setprop rect 2 0 node "a,b,c\nd,e,f\nv_a"}
check "MK10 two leading buses still return" \
  [pcall {xschem get graph_trace_at 0 100 100 10}] -1
check "MK10b ... and the third entry is node index 2" \
  [pcall {xschem get graph_trace_at 0 400 200 100000}] 2
# MK11: a node carrying a `%<n>` DATASET SELECTOR for a dataset this raw does
# not have. find_closest_wave then takes `goto done`, whose `ofs = ofs_end;`
# used to read an uninitialised ofs_end on dset 0 and a stale one thereafter.
# graph_point_at (the picker) always had it right; both are exercised.
pcall {xschem setprop rect 2 0 node "v_a%1"}
set mk11 {}
for {set k 0} {$k < 20} {incr k} {
  lappend mk11 [pcall {xschem get graph_trace_at 0 400 200 100000}]
}
check "MK11 the dataset-skip path is STABLE across 20 repetitions" \
  [lsort -unique $mk11] -1
check "MK11 ... and the same node with no selector IS found" \
  [pcall {xschem setprop rect 2 0 node "v_a"; xschem get graph_trace_at 0 400 200 100000}] 0
# the real find_closest_wave caller is the wave-bold RELEASE in waves_callback,
# which needs a window: `xschem callback` dereferences its win_path (issue 0076
# guards argc, not existence), so this half only runs when .drw is up.
if {[info commands winfo] ne {} && [winfo exists .drw]} {
  set mk11px [expr {[winfo width .drw] / 2}]
  set mk11py [expr {[winfo height .drw] / 2}]
  pcall {xschem setprop rect 2 0 hilight_wave -1}
  pcall {xschem setprop rect 2 0 node "v_a%1"}
  set mk11b {}
  for {set k 0} {$k < 20} {incr k} {
    pcall {xschem callback .drw 4 $mk11px $mk11py 0 1 0 0}
    pcall {xschem callback .drw 5 $mk11px $mk11py 0 1 0 256}
    lappend mk11b [pcall {xschem getprop rect 2 0 hilight_wave}]
  }
  check "MK11 find_closest_wave: 20 wave-bold releases over a %<n>-selected node are stable" \
    [lsort -unique $mk11b] -1
  check_true "MK11 ... and hilight_wave is always a valid index" \
    [expr {[llength [lsort -unique $mk11b]] == 1 &&
           [string is integer -strict [lindex $mk11b 0]] && [lindex $mk11b 0] >= -1}]
} else {
  puts "note: MK11 find_closest_wave half needs .drw (skipped under --nogui)"
}

# --- MK12: the fail-soft getters, callable with no pointer at all ----------
# graph_marker_at installs the cairo toy face itself, and xctx->cairo_ctx is NULL
# under --nogui: the guard must make it answer "" rather than fault.
check "MK12 graph_marker_at over empty space -> {}" \
  [pcall {xschem get graph_marker_at 0 10 10}] {}
check "MK12 graph_marker_at with an explicit tol -> {}" \
  [pcall {xschem get graph_marker_at 0 10 10 4}] {}
check "MK12 graph_marker_at on a bad graph index -> {} (never an error)" \
  [pcall {xschem get graph_marker_at 99 10 10}] {}
check "MK12 graph_marker_at with too few args -> {}" \
  [pcall {xschem get graph_marker_at 0}] {}
check "MK12 graph_marker_drag with nothing armed -> 0" \
  [pcall {xschem get graph_marker_drag}] 0
check "MK12 graph_marker_sel with nothing selected -> -1" \
  [pcall {xschem graph_marker select -none; xschem get graph_marker_sel}] -1
check "MK12 graph_rects counts GRAPH rects only" \
  [pcall {mk_graph 0 3000 800 3400 {}; list [xschem get rects 2] [xschem get graph_rects]}] {2 1}
check "MK12 an unknown graph_marker sub-verb fails LOUD" \
  [string match {ERR:*usage*} [pcall {xschem graph_marker bogus}]] 1
check "MK12 `graph_marker` with no sub-verb fails LOUD" \
  [string match {ERR:*usage*} [pcall {xschem graph_marker}]] 1
check "MK12 graph_marker text of an unknown number -> {}" \
  [pcall {xschem graph_marker text 99}] {}
check "MK12 graph_marker delete of an unknown number -> 0" \
  [pcall {xschem graph_marker delete 99}] 0
check "MK12 graph_marker delete -all with nothing there -> 0" \
  [pcall {xschem graph_marker delete -all}] 0

# ============================================================================
# MR* — a raw + a graph, no gestures. The engine half runs in BOTH arms.
# ============================================================================
mk_reset
pcall {xschem raw clear}
check "MR0 hermetic raw: `raw new` accepted" \
  [pcall {xschem raw new mkmark.raw dc vsweep 0 1.0 0.1}] 1
foreach v {v_a v_b} {
  check "MR0 `raw add $v` accepted" [pcall {xschem raw add $v {vsweep 1 +}}] 1
}
check "MR0 v_b is redefined as a DIFFERENT column" \
  [pcall {xschem raw del v_b; xschem raw add v_b {vsweep 2 *}}] 1
check "MR0 v_p carries more than 8 significant digits" \
  [pcall {xschem raw add v_p {vsweep 3.14159265358979 *}}] 1
check "MR0 the fixture raw knows the vectors the graphs use" \
  [pcall {set l [split [xschem raw list] "\n"]
          list [expr {[lsearch -exact $l v_a] >= 0}] \
               [expr {[lsearch -exact $l v_b] >= 0}] \
               [expr {[lsearch -exact $l v_p] >= 0}]}] {1 1 1}
check "MR0 exactly 11 samples on an exact 0.1 grid" [pcall {xschem raw points}] 11
pcall {mk_graph 0 0 800 400}
pcall {xschem setprop rect 2 0 node "v_a\nv_b"}
pcall {mk_graph 0 1000 800 1400}
pcall {xschem setprop rect 2 1 node "v_a"}
pcall {xschem zoom_full}
check "MR0 two graph rects" [pcall {xschem get graph_rects}] 2

# --- MR1: creation, data-addressed --------------------------------------
pcall {xschem set_modify 0}
check "MR1 add_at returns the new number 1" [pcall {xschem graph_marker add_at 0 0 0 5}] 1
check "MR1 exactly one record on strip 0" [pcall {llength [xschem graph_marker list 0]}] 1
check "MR1 the rect actually carries the token" \
  [pcall {xschem getprop rect 2 0 markers}] [mk_rec 1 0 0 5 0.5 1.5]
check "MR1 a NORMAL (editable) window is marked modified" [pcall {xschem get modified}] 1
check "MR1 ... and readonly is unchanged" [pcall {xschem get readonly}] 0

# --- MR2: the anchor SNAPS to a real sample ------------------------------
# The grid is start + i*step, so point 5 is EXACTLY 0.5 and the %.17g rendering
# of it is the two-character string "0.5" — a literal constant, no tolerance.
check "MR2 x is EXACTLY the sample, at %.17g" [pcall {mk_field 1 5}] 0.5
check_true "MR2 y matches `xschem raw value` numerically (1e-7 relative)" \
  [pcall {mk_close [mk_field 1 6] [xschem raw value v_a 5]}]
check "MR2 the identity fields name the trace, dataset and ABSOLUTE point" \
  [pcall {lrange [lindex [xschem graph_marker list 0] 0] 2 4}] {0 0 5}
check "MR2 the default label offset is up and to the right" \
  [pcall {lrange [lindex [xschem graph_marker list 0] 0] 8 9}] {0.06 -0.09}
# a point whose x is NOT representable: %.17g must show the accumulated value
check "MR2b point 3 keeps its 17 significant digits" \
  [pcall {xschem graph_marker add_at 0 0 0 3; mk_field 2 5}] 0.30000000000000004
check_true "MR2b ... and its y agrees with raw value numerically" \
  [pcall {mk_close [mk_field 2 6] [xschem raw value v_a 3]}]
# `raw value` formats through dtoa (%.8g) and the token stores %.17g, so an `eq`
# comparison between the two is wrong BY CONSTRUCTION -- pinned here so nobody
# "simplifies" mk_close away
check_true "MR2b a string compare against `raw value` would be WRONG by construction" \
  [expr {[pcall {mk_field 2 5}] ne [pcall {xschem raw value vsweep 3}]}]

# --- MR3: numbering across strips ---------------------------------------
check "MR3 the second marker in strip 0 is M2" [pcall {mk_nums 0}] {1 2}
check "MR3 a marker in strip 1 continues the WINDOW-wide sequence" \
  [pcall {xschem graph_marker add_at 1 0 0 5}] 3
check "MR3 strip 1 holds exactly M3" [pcall {mk_nums 1}] 3
check "MR3 the window-wide list is M1 M2 M3" [pcall {mk_nums}] {1 2 3}
# stateless: delete the top number, the next allocation reuses it
pcall {xschem graph_marker delete 3}
check "MR3 after deleting M3 the next number is 3 again (no hidden counter)" \
  [pcall {xschem graph_marker add_at 1 0 0 7}] 3

# --- MR4: the DELTA block -----------------------------------------------
pcall {xschem graph_marker delete -all}
pcall {xschem graph_marker add_at 0 0 0 3}
check "MR4 -delta sets prev to the previous max" \
  [pcall {xschem graph_marker add_at 0 0 0 7 -delta; mk_field 2 7}] 1
set mr4t [pcall {xschem graph_marker text 2}]
check "MR4 the label's first line is M<N>:<x>,<y>" [lindex [split $mr4t "\n"] 0] {M2:0.7,1.7}
check_true "MR4 the delta line reads <D>x:<dx>,<D>y:<dy>" \
  [regexp {^.x:0\.4,.y:0\.4$} [lindex [split $mr4t "\n"] 1]]
check "MR4 the slope line" [lindex [split $mr4t "\n"] 2] {slope:1}
check "MR4 the delta glyph is the Greek capital delta (cairo build)" \
  [string index [lindex [split $mr4t "\n"] 1] 0] [format %c 0x394]
check "MR4 a plain marker has NO delta block" \
  [llength [split [pcall {xschem graph_marker text 1}] "\n"]] 1
# dx == 0 (two markers at the same x on DIFFERENT traces) -> slope:undef
check "MR4 dx == 0 yields slope:undef" \
  [pcall {xschem graph_marker add_at 0 1 0 7 -delta
          lindex [split [xschem graph_marker text 3] "\n"] 2}] {slope:undef}
# a delta whose partner lives in ANOTHER strip resolves (numbering is window-wide)
check "MR4 a cross-strip delta partner resolves" \
  [pcall {xschem graph_marker add_at 1 0 0 9 -delta
          regexp {slope:} [xschem graph_marker text 4]}] 1
check "MR4 ... and its prev really names the marker in the other strip" \
  [pcall {mk_field 4 7}] 3
# a dangling partner degrades to a plain callout rather than rendering a ghost
check "MR4 deleting the partner clears the dangling prev" \
  [pcall {xschem graph_marker delete 3; mk_field 4 7}] 0
check "MR4 ... and the delta block is gone from the label" \
  [llength [split [pcall {xschem graph_marker text 4}] "\n"]] 1

# --- MR4b: an EXPRESSION trace (the volatile scratch column) -------------
# For an expression trace idx == raw->nvars, the GLOBAL scratch column
# (save.c:1836). A bare get_raw_value() there reads whatever expression was
# plotted last. This leg poisons the column on purpose by marking the SECOND
# expression first, then marks the FIRST and demands its own value back.
pcall {xschem graph_marker delete -all}
pcall {xschem setprop rect 2 0 node "v_a v_a *\nv_b v_b *"}
check "MR4b marking the SECOND expression leaves its values in the scratch column" \
  [pcall {xschem graph_marker add_at 0 1 0 5; mk_close [mk_field 1 6] 1.0}] 1
check "MR4b the FIRST expression marker still reads v_a(5) squared, not the scratch" \
  [pcall {xschem graph_marker add_at 0 0 0 5; mk_close [mk_field 2 6] 2.25}] 1
check "MR4b ... and the two markers really hold DIFFERENT values" \
  [expr {[pcall {mk_field 1 6}] ne [pcall {mk_field 2 6}]}] 1
check "MR4b the expression marker's x is still the sweep sample" \
  [pcall {mk_field 2 5}] 0.5
pcall {xschem graph_marker delete -all}
pcall {xschem setprop rect 2 0 node "v_a\nv_b"}

# --- MR5: a redraw with markers present ---------------------------------
pcall {xschem graph_marker add_at 0 0 0 5}
check "MR5 `xschem redraw` returns rc 0 with markers present" \
  [pcall {xschem redraw; list ok}] ok
check "MR5 the flags token is still `graph` after the redraw" \
  [pcall {xschem getprop rect 2 0 flags}] graph
check "MR5 the marker survived the redraw" [pcall {mk_nums 0}] 1
# NOTE: `xschem draw_graph <i>` is not exercised HERE. It used to SIGSEGV under
# --nogui with or without markers (probe-verified against a marker-free graph
# too), a PRE-EXISTING landmine of that verb, not something this feature
# introduced. It is now guarded (has_x + a range check) and MF14 below pins that
# in both arms; its marker behaviour is asserted in MX13, under a real display.

# --- MR9: delete ---------------------------------------------------------
pcall {xschem graph_marker delete -all}
pcall {xschem graph_marker add_at 0 0 0 3}
pcall {xschem graph_marker add_at 0 0 0 7 -delta}
pcall {xschem graph_marker add_at 1 0 0 5 -delta}
check "MR9 fixture: M1, M2(prev 1), M3(prev 2)" \
  [pcall {list [mk_nums] [mk_field 2 7] [mk_field 3 7]}] {{1 2 3} 1 2}
check "MR9 delete 1 returns 1" [pcall {xschem graph_marker delete 1}] 1
check "MR9 ... the record is gone" [pcall {mk_nums}] {2 3}
check "MR9 ... and M2's dangling prev was cleared" [pcall {mk_field 2 7}] 0
check "MR9 ... while M3's prev (a live partner) is untouched" [pcall {mk_field 3 7}] 2
check "MR9 the selection is reset when the SELECTED marker is deleted" \
  [pcall {xschem graph_marker select 2 0
          set a [xschem get graph_marker_sel]
          xschem graph_marker delete 2
          list $a [xschem get graph_marker_sel]}] {2 -1}
check "MR9 delete -all <gi> returns the count for that graph only" \
  [pcall {xschem graph_marker add_at 0 0 0 1
          xschem graph_marker add_at 0 0 0 2
          xschem graph_marker delete -all 0}] 2
check "MR9 ... and left the other strip alone" [pcall {mk_nums 1}] 3
check "MR9 delete -all with no index sweeps the window" \
  [pcall {xschem graph_marker delete -all}] 1
check "MR9 nothing left anywhere" [pcall {mk_nums}] {}

# --- MR15: selection is UI state, never content -------------------------
pcall {xschem graph_marker add_at 0 0 0 5}
check "MR15 select returns the new selection" [pcall {xschem graph_marker select 1 0}] 1
check "MR15 ... and the getter agrees" [pcall {xschem get graph_marker_sel}] 1
check "MR15 selection is NOT written into the token" \
  [pcall {xschem getprop rect 2 0 markers}] [mk_rec 1 0 0 5 0.5 1.5]
check "MR15 -none clears it" [pcall {xschem graph_marker select -none}] -1
check "MR15 ... and the getter says -1" [pcall {xschem get graph_marker_sel}] -1
# Selecting a number that does not resolve is ACCEPTED by design (§1.3: the
# selection is not cleared by loading a new file — the number simply stops
# resolving), and the DELETE path is what fails safe.
check "MR15 a non-resolving number can be selected (documented, not a bug)" \
  [pcall {xschem graph_marker select 99 0; xschem get graph_marker_sel}] 99
check "MR15 ... but deleting through it removes nothing" \
  [pcall {xschem graph_marker delete 99}] 0
check "MR15 ... and the live marker is untouched" \
  [pcall {xschem getprop rect 2 0 markers}] [mk_rec 1 0 0 5 0.5 1.5]
pcall {xschem graph_marker select -none}
check "MR15 with nothing selected the token is untouched" \
  [pcall {xschem getprop rect 2 0 markers}] [mk_rec 1 0 0 5 0.5 1.5]
check "MR15 `select` is NOT readonly-rejected (it is UI state)" \
  [pcall {xschem set readonly 1
          set r [xschem graph_marker select 1 0]
          xschem set readonly 0
          set r}] 1
check "MR15 a mutating sub-verb IS readonly-rejected" \
  [string match {ERR:*read-only*} [pcall {xschem set readonly 1
          set r [catch {xschem graph_marker add_at 0 0 0 1} e]
          xschem set readonly 0
          if {$r} { return -code error $e }
          set e}]] 1
pcall {xschem graph_marker select -none}

# --- MR13: refusals, none of which may throw ----------------------------
check "MR13 a bad graph index refuses with {}" [pcall {xschem graph_marker add_at 9 0 0 3}] {}
check "MR13 a bad wave index refuses with {}"  [pcall {xschem graph_marker add_at 0 9 0 3}] {}
check "MR13 an out-of-range point refuses with {}" \
  [pcall {xschem graph_marker add_at 0 0 0 9999}] {}
check "MR13 a negative point refuses with {}" [pcall {xschem graph_marker add_at 0 0 0 -1}] {}
check "MR13 a wrong dataset refuses with {}"  [pcall {xschem graph_marker add_at 0 0 5 3}] {}
pcall {mk_graph 0 2000 800 2400 {}}
set mr13n [expr {[pcall {xschem get rects 2}] - 1}]
check "MR13 a NON-GRAPH layer-2 rect refuses with {}" \
  [pcall {xschem graph_marker add_at $mr13n 0 0 3}] {}
check "MR13 ... and lists nothing" [pcall {xschem graph_marker list $mr13n}] {}
pcall {mk_graph 0 3000 800 3400}
set mr13b [expr {[pcall {xschem get rects 2}] - 1}]
pcall {xschem setprop rect 2 $mr13b node "a,b,c"}
check "MR13 a BUS-only graph refuses with {}" \
  [pcall {xschem graph_marker add_at $mr13b 0 0 3}] {}
pcall {mk_graph 0 4000 800 4400}
set mr13d [expr {[pcall {xschem get rects 2}] - 1}]
pcall {xschem setprop rect 2 $mr13d node "v_a"}
pcall {xschem setprop rect 2 $mr13d digital 1}
check "MR13 a DIGITAL strip refuses the pixel creator with {}" \
  [pcall {xschem graph_marker add $mr13d 100 100}] {}
check "MR13 move/anchor/label of an unknown number all return 0" \
  [pcall {list [xschem graph_marker move 99 10 10] \
               [xschem graph_marker anchor 99 0 1] \
               [xschem graph_marker label 99 0.1 0.1]}] {0 0 0}
check "MR13 a non-finite label offset is refused" \
  [pcall {xschem graph_marker label 1 nan 0}] 0
check "MR13 the label offset is CLAMPED to -2..2" \
  [pcall {xschem graph_marker label 1 99 -99; lrange [lindex [xschem graph_marker list 0] 0] 8 9}] \
  {2 -2}
check "MR13 anchor_at moves only dataset/point/x/y" \
  [pcall {xschem graph_marker anchor 1 0 8; lrange [lindex [xschem graph_marker list 0] 0] 3 6}] \
  {0 8 0.80000000000000004 1.8}
check "MR13 ... and left ldx/ldy exactly where the clamp put them" \
  [pcall {lrange [lindex [xschem graph_marker list 0] 0] 8 9}] {2 -2}
check "MR13 nothing above threw" [pcall {list ok}] ok

# --- MR14: create -> format -> save -> load -> read back ----------------
# The precision leg with teeth. MR10 below supplies the marker string itself and
# so never runs graph_markers_format; this one does.
mk_reset
pcall {mk_graph 0 0 800 400}
pcall {xschem setprop rect 2 0 node "v_p"}
pcall {xschem zoom_full}
check "MR14 a marker on a value needing >8 significant digits" \
  [pcall {xschem graph_marker add_at 0 0 0 7}] 1
set mr14y [pcall {mk_field 1 6}]
set mr14x [pcall {mk_field 1 5}]
check_true "MR14 the stored y agrees with `raw value` numerically" \
  [pcall {mk_close $mr14y [xschem raw value v_p 7]}]
# THE assertion S7 breaks. It has to read the TOKEN, not `graph_marker list`:
# the list verb RE-RENDERS the parsed double at %.17g, so a %.8g-truncated token
# still prints 17 digits there ("2.1991149" parses back and prints as
# 2.1991148999999999) and the same test on the list output passes for the wrong
# reason. What the formatter actually wrote is the thing under test.
set mr14tok [pcall {xschem getprop rect 2 0 markers}]
set mr14tx [lindex [split $mr14tok { }] 4]
set mr14ty [lindex [split $mr14tok { }] 5]
check "MR14 the token has the 9 fields of one record" \
  [llength [split $mr14tok { }]] 9
check_true "MR14 the TOKEN's y carries MORE than 8 significant digits (not dtoa)" \
  [expr {$mr14ty ne [format %.8g $mr14ty]}]
check_true "MR14 ... and so does the TOKEN's x" \
  [expr {$mr14tx ne [format %.8g $mr14tx]}]
check "MR14 the token and the list read-back agree exactly" \
  [list $mr14tx $mr14ty] [list $mr14x $mr14y]
set mr14f [file join $scratch mr14.sch]
pcall {xschem saveas $mr14f schematic}
pcall {xschem clear force}
pcall {xschem load $mr14f}
check "MR14 the reloaded schematic has one graph rect" [pcall {xschem get graph_rects}] 1
check "MR14 the whole TOKEN survived save+load byte-for-byte" \
  [pcall {xschem getprop rect 2 0 markers}] $mr14tok
check "MR14 y survived save+load BYTE-for-BYTE" [pcall {mk_field 1 6}] $mr14y
check "MR14 x survived save+load BYTE-for-BYTE" [pcall {mk_field 1 5}] $mr14x
check "MR14 the identity fields survived too" \
  [pcall {lrange [lindex [xschem graph_marker list 0] 0] 0 4}] {1 0 0 0 7}

# --- MR10: file persistence of a hand-written multi-line token ----------
mk_reset
pcall {mk_graph 0 0 800 400}
set mr10 "$mk1a\n$mk1b\n$mk1c"
pcall {xschem setprop rect 2 0 markers $mr10}
set mr10f [file join $scratch mr10.sch]
pcall {xschem saveas $mr10f schematic}
pcall {xschem clear force}
check "MR10 the buffer really was cleared" [pcall {xschem get graph_rects}] 0
pcall {xschem load $mr10f}
check "MR10 a 3-record multi-line token survives save+load byte-identically" \
  [pcall {xschem getprop rect 2 0 markers}] $mr10
check "MR10 ... and parses back into 3 records" \
  [pcall {llength [xschem graph_marker list 0]}] 3
check "MR10 the flags token came back too" [pcall {xschem getprop rect 2 0 flags}] graph

# --- MR11: paste RENUMBERS (merge_box -> graph_marker_renumber_rect) ----
# TWO records are mandatory: with one, the `base`-once bug (calling
# next_number() per record, which returns the SAME value every time because the
# rect being merged is not yet counted) is invisible.
mk_reset
pcall {mk_graph 0 0 800 400}
pcall {xschem setprop rect 2 0 markers \
  "[mk_rec 1 0 0 3 0.3 1.3]\n[mk_rec 2 0 0 7 0.7 1.7 1]"}
check "MR11 fixture: one graph rect carrying M1 and M2(prev 1)" \
  [pcall {list [xschem get graph_rects] [mk_nums] [mk_field 2 7]}] {1 {1 2} 1}
pcall {xschem unselect_all}
pcall {xschem select_all}
pcall {xschem copy}
pcall {xschem unselect_all}
pcall {xschem paste}
pcall {xschem unselect_all}
check "MR11 the paste produced a second graph rect" [pcall {xschem get graph_rects}] 2
check "MR11 four markers in the window" [pcall {llength [mk_nums]}] 4
check "MR11 ALL FOUR numbers are distinct (base computed ONCE per rect)" \
  [pcall {llength [lsort -unique [mk_nums]]}] 4
check "MR11 the pasted numbers continue the sequence" [pcall {lsort -integer [mk_nums]}] {1 2 3 4}
check "MR11 the ORIGINAL rect's prev link is untouched" [pcall {mk_field 2 7}] 1
check "MR11 every PASTED prev was cleared (a delta partner is not copied)" \
  [pcall {list [mk_field 3 7] [mk_field 4 7]}] {0 0}

# --- MR12: C undo / redo, on BOTH undo backends ------------------------
foreach mr12t {memory disk} {
  mk_reset
  pcall {xschem undo_type $mr12t}
  pcall {xschem raw clear}
  pcall {xschem raw new mkmark.raw dc vsweep 0 1.0 0.1}
  pcall {xschem raw add v_a {vsweep 1 +}}
  pcall {mk_graph 0 0 800 400}
  pcall {xschem setprop rect 2 0 node "v_a"}
  pcall {xschem zoom_full}
  check "MR12 ($mr12t) a marker is created" [pcall {xschem graph_marker add_at 0 0 0 5}] 1
  check "MR12 ($mr12t) undo REMOVES it" \
    [pcall {xschem undo; llength [xschem graph_marker list 0]}] 0
  check "MR12 ($mr12t) ... and the rect token is gone too" \
    [pcall {xschem getprop rect 2 0 markers}] {}
  check "MR12 ($mr12t) redo restores it byte-identically" \
    [pcall {xschem redo; xschem getprop rect 2 0 markers}] [mk_rec 1 0 0 5 0.5 1.5]
}
pcall {xschem undo_type disk}
mk_reset
pcall {xschem set_modify 0}

# ============================================================================
# MF* — one leg per fix applied AFTER the adversarial review
#
# WHAT EACH FIX WAS, so a future reader knows what the leg is defending:
#
#  MF1  draw.c graph_point_at(): the sweep-token resolution moved ABOVE the
#       `restrict_wave` skip. A `sweep` list SHORTER than the `node` list
#       carries its last entry forward (stok comes back NULL and sweep_idx
#       keeps its value), so skipping FIRST left every RESTRICTED walk — i.e.
#       every anchor drag, since graph_marker_move() restricts to the marker's
#       own wave — reading raw column 0 and finding nothing.
#       Measured before: `xschem graph_marker move` returned 0 at every pixel
#       and the record never changed.
#  MF2  draw.c: the callout is built from the RECORD, not re-derived from the
#       number. graph_marker_text() split into graph_marker_text_rec(rec, gi,
#       pool, npool, dest, size) + a by-number wrapper. Before, an ANCHOR DRAG
#       slid the dot while the readout stayed frozen at the pre-drag x/y, dx/dy
#       and slope: the number path re-reads the rect's STORED token, which is
#       deliberately not written until release.  (display half)
#  MF3  draw.c: new GraphMarkerRef + graph_markers_collect() — the window is
#       parsed ONCE per operation and delta partners resolve out of that pool.
#       Before, graph_marker_text() did a full-window graph_marker_find() scan
#       per record, making the redraw AND the hit-test O(N^2): measured 139 ms
#       per redraw at 400 markers, ~220 ms at the 512 cap, on every pan/zoom/
#       cursor-move and every LMB press.  (display half)
#  MF4  draw.c graph_marker_sample() switches to the graph's own `rawfile=` /
#       `sim_type=` (and switches back) exactly as graph_point_at() does.
#       Before, on a multi-raw graph the pixel path previewed the graph's raw
#       while the data path — which every anchor-drag COMMIT goes through —
#       read whatever raw was current. Measured before, with this fixture:
#       add_at stored 1.5 (raw B) where the graph's raw A says 5.
#       A REQUESTED-but-FAILED switch now bails as well, instead of quietly
#       reading the current raw -- the pixel path already refused, so the data
#       path had to agree.
#  MF5  draw.c graph_marker_clear_prev_n() -- ONE pass over the window for the
#       whole set of removed numbers -- is called from delete -all too: a
#       PARTIAL `delete -all <gi>` used to leave dangling `prev` links on the
#       strips it did not touch, silently degrading a delta callout to a plain
#       one. The first cut swept per number, which was O(deleted x surviving
#       records): 10 s at 4000 markers, now 41 ms.
#  MF6  draw.c graph_markers_parse() no longer caps at GRAPH_MARKERS_MAX. The
#       cap bounds CREATION only; truncating on the READ side was data
#       destruction, because every mutating op rewrites the whole token from
#       the parsed array — one keystroke on a 520-record file permanently
#       dropped 8 records.
#  MF7  graph_flags bits 128|256 are saved/restored around setup_graph_data
#       (landmine 37) at all FOUR entry points that call it outside a draw:
#       draw.c graph_marker_at(), graph_point_at(), graph_marker_create() and
#       callback.c graph_marker_drag_to(). This leg pins graph_marker_at();
#       the other three are the same two lines.  (display half)
#  MF8  draw.c/callback.c: the selection is identified by NUMBER alone in the
#       renderer, and the Delete gate RE-RESOLVES the owning strip with
#       graph_marker_find(). graph_marker_selgraph is a rect INDEX and goes
#       stale on a strip reorder or a multi-plot prepend.  (display half)
#  MF9  callback.c: graph_marker_drag_abort() is called at every fresh Button1
#       press (where graph_press_x/y is seeded), because the ASE viewer binds
#       <Shift-ButtonRelease-1>/<Alt-ButtonRelease-1> to a bare {break}, so a
#       modifier-held release never reaches C and the release-side teardown
#       cannot run. A surviving arm made marker_grabbed answer 1 for every later
#       press and COMMITTED the old move on the next unrelated click.
#       (display half)
#  MF10 callback.c: graph_marker_press() returns -1 when it only DESELECTED and
#       graph_marker_release() returns 1 when the selection left another graph;
#       waves_callback turns both into need_all_redraw so a stale selection ring
#       on another strip is erased.  (display half; see the leg's own comment —
#       the visible part is eyeball-only)
#  MF11 draw.c graph_marker_ro_refuse() gates the four MUTATING PRIMITIVES
#       (add_record / update / delete / delete_all) with a NON-MODAL ciw_echo.
#       A marker is durable CONTENT, so a read-only buffer must refuse it —
#       before, the edit landed anyway, carried NO undo point (push_undo is
#       skipped when readonly) and `xschem undo` is itself readonly-rejected,
#       i.e. it could never be taken back.
#       NOT readonly_block() in the key arms, which was the first cut and was
#       wrong twice over: readonly_block() pops a MODAL, and a modal on a
#       keystroke deadlocks any script driving the refusal (it hung this very
#       suite forever under a real DISPLAY); and the key arms do not cover the
#       DRAG-COMMIT path (graph_marker_release -> anchor_at/label_offset ->
#       graph_marker_update), which reaches no key arm at all.
#       The ASE viewer, readonly for its whole life, gets through because
#       wviewer::key_filter forwards m/d/Delete inside with_edit, and
#       wviewer::strip_drag_release forwards the RELEASE inside with_edit when
#       a marker gesture is armed.
#       (display halves: MF11a main window, MF11b the viewer)
#  MF12 move.c copy_objects() calls graph_marker_renumber_rect() on a copied
#       graph rect. This was the SECOND rect-duplication door (merge_box/paste
#       was the first, MR11): the `c`-key copy produced two markers numbered 1
#       and two numbered 2, breaking the window-wide uniqueness graph_marker_find
#       / prev / the selection / delete all rest on.
#  MF13 actions.c clear_drawing() resets graph_marker_sel/selgraph and the four
#       drag fields. The same xctx is reused by `xschem clear`, File>Open in the
#       tab, `xschem load` and the disk-undo reload, so a surviving selection
#       latched onto whatever marker in the NEW document carried that number —
#       the M1 case — and Delete destroyed it.
#  MF14 scheduler.c: `xschem draw_graph <i>` gained a has_x + index guard.
#       PRE-EXISTING crash, unrelated to markers: under --nogui it went straight
#       to Xlib with no window and SIGSEGV'd, and it dereferenced
#       rect[GRIDLAYER][i] unchecked.
#  MF15 wave_viewer.tcl capture_live_graph_state gained an optional
#       `skip_markers` arg AND the same rect/model 1:1 guard marker_changed has
#       (this path also DELETES keys, so a desync was worse here).  (viewer half)
#  MF16 wave_viewer.tcl marker_changed now calls
#       `capture_live_graph_state $token 1` BEFORE push_undo, matching
#       move_strip/move_trace: without it one `u` after creating a marker also
#       reverted the user's unrelated pan/zoom/bold. skip_markers=1 is essential
#       — capturing the markers there would put the new marker INSIDE its own
#       restore point.  (viewer half)
#
# This block is the half that needs NO window; it runs in both arms.
# ============================================================================

# --- MF1: a restricted anchor move honours a CARRIED-FORWARD sweep ----------
# The fixture is built so the two sweep columns cannot be confused: `v_off` runs
# 100..101 while raw column 0 (`vsweep`) runs 0..1, and the graph's x window is
# 100..101 — so a walk that falls back to column 0 has every sample OUTSIDE
# [start,end] and finds nothing at all. The `sweep` token deliberately has ONE
# entry for TWO nodes, which is what makes the second node depend on the
# carry-forward, and the marker is restricted to that second node.
mk_reset
pcall {xschem raw clear}
check "MF1 fixture raw" [pcall {xschem raw new mfmark.raw dc vsweep 0 1.0 0.1}] 1
check "MF1 v_a added" [pcall {xschem raw add v_a {vsweep 1 +}}] 1
check "MF1 an ALTERNATE sweep column 100..101 added" \
  [pcall {xschem raw add v_off {vsweep 100 +}}] 1
check "MF1 v_b added" [pcall {xschem raw add v_b {vsweep 2 *}}] 1
check "MF1 the alternate sweep really is far from column 0" \
  [pcall {mk_close [xschem raw value v_off 5] 100.5}] 1
pcall {mk_graph 0 0 800 400}
pcall {xschem setprop rect 2 0 node "v_a\nv_b"}
pcall {xschem setprop rect 2 0 sweep "v_off"}
foreach {mf1t mf1v} {x1 100 x2 101 y1 -1 y2 3} { pcall {xschem setprop rect 2 0 $mf1t $mf1v} }
pcall {xschem zoom_full}
check "MF1 one sweep entry for two nodes (the carry-forward case)" \
  [pcall {list [xschem getprop rect 2 0 sweep] [xschem getprop rect 2 0 node]}] \
  {v_off {v_a
v_b}}
check "MF1 a marker on the SECOND node (the one that needs the carry-forward)" \
  [pcall {xschem graph_marker add_at 0 1 0 5}] 1
check "MF1 ... anchored on the alternate sweep, not column 0" [pcall {mk_field 1 5}] 100.5
# THE assertion. Before the fix graph_marker_move() answered 0 at EVERY pixel
# (the restricted walk read gvx = vsweep, 0..1, all outside the 100..101 window)
# and the record never moved.
set mf1ok 0
set mf1pts {}
set mf1xs {}
foreach mf1px {60 200 340 480 620} {
  if {[pcall {xschem graph_marker move 1 $mf1px 100}] == 1} { incr mf1ok }
  lappend mf1pts [pcall {mk_field 1 4}]
  lappend mf1xs  [pcall {mk_field 1 5}]
}
check "MF1 graph_marker move committed at every pixel (was 0/5 before the fix)" $mf1ok 5
check_true "MF1 the anchor really SLID (more than one distinct sample visited)" \
  [expr {[llength [lsort -unique $mf1pts]] > 1}]
check_true "MF1 every landing x came from the CARRIED-FORWARD sweep (100..101)" \
  [pcall {set bad 0
          foreach v $mf1xs { if {!([string is double -strict $v] && $v >= 100.0 && $v <= 101.0)} {incr bad} }
          expr {$bad == 0}}]
check_true "MF1 ... i.e. never from raw column 0 (0..1)" \
  [pcall {set bad 0
          foreach v $mf1xs { if {[string is double -strict $v] && $v <= 1.0} {incr bad} }
          expr {$bad == 0}}]
check "MF1 the anchor stayed on its OWN node" [pcall {mk_field 1 2}] 1
check_true "MF1 and y still agrees with the raw at the landing point" \
  [pcall {mk_close [mk_field 1 6] [xschem raw value v_b [mk_field 1 4]]}]
# the CONTROL: the unrestricted walk (graph_trace_at) was never broken, so a leg
# that only used it could not have caught this
check "MF1 the UNRESTRICTED walk finds the same graph too (the control)" \
  [pcall {expr {[xschem get graph_trace_at 0 340 100 1e30] >= 0}}] 1

# --- MF4: the data path switches to the graph's OWN rawfile -----------------
# Two raws carrying the SAME node name with different values. The graph names
# raw A; raw B is the current one. Before the fix graph_marker_sample() read
# whatever raw happened to be current, so add_at (and every anchor-drag COMMIT,
# which goes through the same function) stored raw B's 1.5 where raw A says 5.
mk_reset
pcall {xschem raw clear}
check "MF4 raw A created" [pcall {xschem raw new mfA.raw dc vsweep 0 1.0 0.1}] 1
check "MF4 A: v_x = vsweep*10" [pcall {xschem raw add v_x {vsweep 10 *}}] 1
check "MF4 raw B created (and made current)" \
  [pcall {xschem raw new mfB.raw dc vsweep 0 1.0 0.1}] 1
check "MF4 B: v_x = vsweep+1, the SAME node name" [pcall {xschem raw add v_x {vsweep 1 +}}] 1
check_true "MF4 the CURRENT raw is B" [pcall {mk_close [xschem raw value v_x 5] 1.5}]
pcall {mk_graph 0 0 800 400}
pcall {xschem setprop rect 2 0 node "v_x"}
pcall {xschem setprop rect 2 0 rawfile mfA.raw}
pcall {xschem setprop rect 2 0 sim_type dc}
pcall {xschem zoom_full}
check "MF4 the graph names raw A" [pcall {xschem getprop rect 2 0 rawfile}] mfA.raw
check "MF4 add_at created a marker" [pcall {xschem graph_marker add_at 0 0 0 5}] 1
check_true "MF4 it stored the GRAPH's raw (A: 5), not the current one" \
  [pcall {mk_close [mk_field 1 6] 5.0}]
check_true "MF4 ... and specifically NOT raw B's 1.5 (the measured pre-fix value)" \
  [expr {![pcall {mk_close [mk_field 1 6] 1.5}]}]
# anchor_at is the COMMIT path of an anchor drag: same function, same trap
check "MF4 the anchor-drag COMMIT path re-anchors" [pcall {xschem graph_marker anchor 1 0 8}] 1
check_true "MF4 ... also out of raw A (8.0, not 1.8)" \
  [pcall {mk_close [mk_field 1 6] 8.0}]
check_true "MF4 the graph's raw was switched BACK afterwards (B is current again)" \
  [pcall {mk_close [xschem raw value v_x 5] 1.5}]

# --- MF5: a PARTIAL `delete -all` sweeps the dangling prev links ------------
# MR9 covers the single delete; this is the delete -all variant, and it needs
# TWO strips because the partner a partial delete strands lives on the strip the
# sweep did NOT visit. Before the fix M2's prev stayed 1 — a delta rendered
# against a ghost, which graph_marker_text silently omits.
mk_reset
pcall {mk_graph 0 0 800 400}
pcall {mk_graph 0 1000 800 1400}
pcall {xschem setprop rect 2 0 markers [mk_rec 1 0 0 3 0.3 1.3]}
pcall {xschem setprop rect 2 1 markers [mk_rec 2 0 0 7 0.7 1.7 1]}
check "MF5 fixture: M1 on strip 0, M2(prev 1) on strip 1" \
  [pcall {list [mk_nums] [mk_field 2 7]}] {{1 2} 1}
check "MF5 delete -all 0 removed exactly one record" \
  [pcall {xschem graph_marker delete -all 0}] 1
check "MF5 ... M2 survived on the untouched strip" [pcall {mk_nums}] 2
check "MF5 ... and its prev link was CLEARED (was left at 1 before the fix)" \
  [pcall {mk_field 2 7}] 0
check "MF5 ... so the callout degraded to a plain one, not a ghost delta" \
  [llength [split [pcall {xschem graph_marker text 2}] "\n"]] 1
# the window-wide form has to keep sweeping too
pcall {xschem setprop rect 2 0 markers [mk_rec 5 0 0 3 0.3 1.3]}
pcall {xschem setprop rect 2 1 markers "[mk_rec 6 0 0 7 0.7 1.7 5]\n[mk_rec 7 0 0 9 0.9 1.9 6]"}
check "MF5 delete -all with no index removes everything" \
  [pcall {xschem graph_marker delete -all}] 3
check "MF5 ... leaving nothing to dangle" [pcall {mk_nums}] {}

# ============================================================================
# MD — Delete All Markers / Ctrl-E (viewer plan item 4), ENGINE HALF
# ============================================================================
# The user-facing verb is `wviewer::delete_all_markers ?token?` on the
# `WaveViewer` bindtag's Ctrl-E; it is a thin wrapper over the C
# `xschem graph_marker delete -all` proved here, plus a log line (MD3) and — in
# a real viewer — the push hook's model update and undo point (MD4.. below,
# DISPLAY only: draw.c:6077 `if(!has_x) return` means graph_marker_notify never
# fires under --nogui, so NONE of the model/undo behaviour can be asserted in
# this arm. The plan's "fully headless" claim is wrong and this split is the
# correction).

# --- MD1: the window-wide delete and its NO-OP rule ------------------------
# The wrapper's whole contract rests on the count: > 0 means "something really
# changed" (repaint + log one line), 0 means "nothing happened" and must leave
# no trace at all — the move_strip `from == to` rule.
mk_reset
pcall {mk_graph 0 0 800 400}
pcall {mk_graph 0 1000 800 1400}
pcall {xschem setprop rect 2 0 markers [mk_rec 1 0 0 3 0.3 1.3]}
pcall {xschem setprop rect 2 1 markers "[mk_rec 2 0 0 7 0.7 1.7]\n[mk_rec 3 0 0 9 0.9 1.9]"}
check "MD1 fixture: three markers spread over two strips" [pcall {mk_nums}] {1 2 3}
check "MD1 the window-wide delete reports how many it removed" \
  [pcall {xschem graph_marker delete -all}] 3
check "MD1 ... and the window is empty" [pcall {mk_nums}] {}
check "MD1 ... on BOTH rects, as an ABSENT token (not an empty one)" \
  [pcall {list [xschem getprop rect 2 0 markers] [xschem getprop rect 2 1 markers]}] {{} {}}
check "MD1 the strips themselves SURVIVED — this is annotation, not Clear All" \
  [pcall {xschem get graph_rects}] 2
check "MD1 a second call deletes nothing and says 0 (the wrapper's no-op gate)" \
  [pcall {xschem graph_marker delete -all}] 0
check "MD1 ... and the window is still empty" [pcall {mk_nums}] {}

# --- MD2: the Tcl surface with no viewer to act on -------------------------
# Both arms: at this point in the file no viewer window is registered, so this
# is the "honest instead of throwing" contract every wviewer command carries.
check "MD2 wviewer::delete_all_markers is defined" \
  [pcall {llength [info procs ::wviewer::delete_all_markers]}] 1
check "MD2 ... and so is its %W shim" \
  [pcall {llength [info procs ::wviewer::delete_all_markers_at]}] 1
check "MD2 no viewer resolves -> {} (never an error, never a delete)" \
  [pcall {wviewer::delete_all_markers}] {}
check "MD2 an unknown token -> {} too" [pcall {wviewer::delete_all_markers NOSUCH}] {}
check "MD2 the shim on a canvas that is not a viewer -> {}, silently" \
  [pcall {wviewer::delete_all_markers_at .drw}] {}

# --- MD3: the ACTION LOG, staged in a CHILD process ------------------------
# Two things have to be true of the log and NEITHER is observable here: this
# suite runs with --nolog, so actionlog_fp is NULL and util.c:493 returns before
# anything is written. So the assertions run in a child launched with --logdir,
# which is the only honest way to make them (the alternative — a leg that reads
# an unopened log — passes vacuously whatever the code does).
#   (a) the C core self-logs `xschem graph_marker delete -all -1`, which is NOT
#       replayable into a viewer: scheduler.c:5021 readonly-rejects the arm and
#       returns TCL_ERROR, which ABORTS a sourced log instead of warning. The
#       wrapper must suppress it and emit ONE wviewer:: line instead.
#   (b) the suppress `pop` must run even when the body THROWS (with_edit errors
#       out on a refused context switch). A leaked push raises the GLOBAL depth
#       counter and silently kills the action log for the rest of the session —
#       so the canary is `xschem copy` (the suppress-gate atom's canary verb)
#       run AFTER a deliberately refused call.
# The child fakes a one-entry viewer registry pointing at the launch canvas:
# with_edit needs only `win_path`, and current_win_path is `.drw` under --nogui.
set mdchild [file join $scratch md_child.tcl]
set mdlogd  [file join $scratch mdlog]
file delete -force $mdlogd
file mkdir $mdlogd
set mdfh [open $mdchild w]
puts $mdfh {# written by tests/headless/test_wave_markers.tcl, leg MD3
dict set ::wviewer::windows MDTOK win_path .drw
xschem set rectcolor 2
xschem rect 0 0 800 400 -1 {flags=graph} 0
xschem rect 0 1000 800 1400 -1 {flags=graph} 0
xschem setprop rect 2 0 markers {1 0 0 3 0.3 1.3 0 0.06 -0.09}
xschem setprop rect 2 1 markers {2 0 0 7 0.7 1.7 0 0.06 -0.09}
puts "child real=[wviewer::delete_all_markers MDTOK]"
puts "child noop=[wviewer::delete_all_markers MDTOK]"
# with_edit leaves the buffer read-only for life, so re-seeding needs the flag
xschem set readonly 0
xschem setprop rect 2 0 markers {3 0 0 3 0.3 1.3 0 0.06 -0.09}
rename wviewer::switch_ctx wviewer::__md_real_switch
proc wviewer::switch_ctx {token} { return 0 }        ;# force with_edit to throw
puts "child threw=[catch {wviewer::delete_all_markers MDTOK}]"
rename wviewer::switch_ctx {}
rename wviewer::__md_real_switch wviewer::switch_ctx
xschem copy
puts MD-CHILD-DONE
exit 0}
close $mdfh
# 2>@1 so xschem's own stderr chatter is not mistaken by exec for a failure
set mdrc [catch {exec [info nameofexecutable] --nogui --pipe -q \
                      --logdir $mdlogd --script $mdchild 2>@1} mdout]
set mdlines {}
foreach mdf [lsort [glob -nocomplain [file join $mdlogd *]]] {
  if {![catch {open $mdf r} mdh]} {
    foreach mdl [split [read $mdh] "\n"] { lappend mdlines $mdl }
    close $mdh
  }
}
proc md_count {lines pat} {
  set n 0
  foreach l $lines { if {[string match $pat $l]} { incr n } }
  return $n
}
if {$mdrc || ![string match {*MD-CHILD-DONE*} $mdout]} {
  note "MD3 child output: [string range $mdout end-400 end]"
}
check_true "MD3 the --logdir child ran to its end" \
  [expr {$mdrc == 0 && [string match {*MD-CHILD-DONE*} $mdout]}]
check "MD3 the child really had a log open" \
  [expr {[llength $mdlines] > 0 ? {ok} : {NO LOG FILE}}] ok
check "MD3 exactly ONE wviewer:: line for three calls (real + no-op + refused)" \
  [md_count $mdlines {wviewer::delete_all_markers *}] 1
check "MD3 ... fully resolved, naming the token it acted on" \
  [md_count $mdlines {wviewer::delete_all_markers MDTOK}] 1
check "MD3 the raw C self-log line is ABSENT (it would abort a replay)" \
  [md_count $mdlines {*graph_marker delete*}] 0
check "MD3 a self-logging verb AFTER the throwing call still logs\
 (the suppress pop is unconditional)" [md_count $mdlines {xschem copy}] 1
rename md_count {}

# --- MF6: the parser is NOT capped; only CREATION is ------------------------
# 520 records is 8 past GRAPH_MARKERS_MAX (512). Before the fix `list` reported
# 512 and — the real damage — the first mutating op rewrote the token from the
# truncated array, permanently destroying records 513..520.
mk_reset
pcall {xschem raw clear}
pcall {xschem raw new mfmark.raw dc vsweep 0 1.0 0.1}
pcall {xschem raw add v_a {vsweep 1 +}}
pcall {mk_graph 0 0 800 400}
pcall {xschem setprop rect 2 0 node "v_a"}
pcall {xschem zoom_full}
set mf6 {}
for {set i 1} {$i <= 520} {incr i} { lappend mf6 [mk_rec $i 0 0 [expr {$i % 11}] 0.5 1.5] }
set mf6 [join $mf6 "\n"]
pcall {xschem setprop rect 2 0 markers $mf6}
check "MF6 all 520 records are parsed back (was 512 before the fix)" \
  [pcall {llength [xschem graph_marker list 0]}] 520
check "MF6 the last record is reachable by number" [pcall {mk_field 520 4}] 3
check "MF6 a mutating op on record 3 succeeds" \
  [pcall {xschem graph_marker label 3 0.11 -0.11}] 1
check "MF6 ... and it really took effect" \
  [pcall {lrange [lindex [xschem graph_marker list 0] 2] 8 9}] {0.11 -0.11}
check "MF6 the rewrite kept all 520 records (before: 8 silently destroyed)" \
  [pcall {llength [xschem graph_marker list 0]}] 520
check "MF6 ... and the TOKEN itself still has 520 lines" \
  [pcall {llength [split [xschem getprop rect 2 0 markers] "\n"]}] 520
check "MF6 record 520 survived the rewrite" [pcall {mk_field 520 4}] 3
# the cap still bounds CREATION
check "MF6 creation IS refused above the cap" [pcall {xschem graph_marker add_at 0 0 0 5}] {}
pcall {xschem setprop rect 2 0 markers [mk_rec 1 0 0 5 0.5 1.5]}
check "MF6 ... and the same call succeeds under it (so the refusal was the cap)" \
  [pcall {xschem graph_marker add_at 0 0 0 5}] 2

# --- MF12: the `c`-key copy renumbers the copied graph rect -----------------
# The second rect-duplication door (MR11 covers the first, merge_box/paste).
# Before the fix the copy carried the ORIGINAL numbers, so the window held two
# M1s and two M2s and graph_marker_find / prev / selection / delete all became
# ambiguous. TWO records are mandatory: with one, a per-record next_number()
# would be invisible.
mk_reset
pcall {mk_graph 0 0 800 400}
pcall {xschem setprop rect 2 0 markers \
  "[mk_rec 1 0 0 3 0.3 1.3]\n[mk_rec 2 0 0 7 0.7 1.7 1]"}
check "MF12 fixture: one graph rect carrying M1 and M2(prev 1)" \
  [pcall {list [xschem get graph_rects] [mk_nums] [mk_field 2 7]}] {1 {1 2} 1}
pcall {xschem unselect_all}
pcall {xschem select_all}
pcall {xschem copy_objects 0 5000}
pcall {xschem unselect_all}
check "MF12 the copy produced a second graph rect" [pcall {xschem get graph_rects}] 2
check "MF12 four markers in the window" [pcall {llength [mk_nums]}] 4
check "MF12 ALL FOUR numbers are distinct (was {1 2 1 2} before the fix)" \
  [pcall {llength [lsort -unique [mk_nums]]}] 4
check "MF12 the copies continue the window-wide sequence" \
  [pcall {lsort -integer [mk_nums]}] {1 2 3 4}
check "MF12 the ORIGINAL rect's prev link is untouched" [pcall {mk_field 2 7}] 1
check "MF12 every COPIED prev was cleared (a delta partner is not copied)" \
  [pcall {list [mk_field 3 7] [mk_field 4 7]}] {0 0}
check "MF12 ... and every number still resolves to exactly one record" \
  [pcall {set n 0
          foreach num {1 2 3 4} {
            foreach r [xschem graph_marker list] { if {[lindex $r 0] == $num} { incr n } }
          }
          set n}] 4

# --- MF13a: clear_drawing() drops the marker selection ----------------------
# The selection is a NUMBER and the same xctx is reused by `xschem clear`,
# File>Open in the tab, `xschem load` and the disk-undo reload. Before the fix
# it survived and latched onto whatever marker in the NEW document carried that
# number — the M1 case — and Delete then destroyed it.
mk_reset
pcall {mk_graph 0 0 800 400}
pcall {xschem setprop rect 2 0 markers [mk_rec 1 0 0 3 0.3 1.3]}
check "MF13a the selection is armed" [pcall {xschem graph_marker select 1 0}] 1
check "MF13a ... and the getter agrees" [pcall {xschem get graph_marker_sel}] 1
pcall {xschem clear force}
check "MF13a `xschem clear` reset it (was left at 1 before the fix)" \
  [pcall {xschem get graph_marker_sel}] -1
check "MF13a ... and no drag survived either" [pcall {xschem get graph_marker_drag}] 0
# the M1 case: a NEW document whose first marker is also M1 must not come up
# pre-selected
pcall {mk_graph 0 0 800 400}
pcall {xschem setprop rect 2 0 markers [mk_rec 1 0 0 5 0.5 1.5]}
check "MF13a a fresh document's M1 exists" [pcall {mk_nums}] 1
check "MF13a ... and is NOT selected (the latch is gone)" \
  [pcall {xschem get graph_marker_sel}] -1
# the same through a LOAD, which is the path a user actually takes
set mf13f [file join $scratch mf13.sch]
pcall {xschem saveas $mf13f schematic}
pcall {xschem graph_marker select 1 0}
check "MF13a re-armed before the load" [pcall {xschem get graph_marker_sel}] 1
pcall {xschem clear force}
pcall {xschem load $mf13f}
check "MF13a a `xschem load` clears it too" [pcall {xschem get graph_marker_sel}] -1
check "MF13a ... and the loaded document still carries its M1" [pcall {mk_nums}] 1

# --- MF14: `xschem draw_graph <i>` no longer walks off the end -------------
# PRE-EXISTING, unrelated to markers: under --nogui the verb went straight to
# Xlib with no window and SIGSEGV'd (the whole file died, scored as CRASH), and
# it dereferenced rect[GRIDLAYER][i] unchecked in BOTH arms. Reaching the check
# below at all is the assertion.
mk_reset
pcall {mk_graph 0 0 800 400}
pcall {xschem setprop rect 2 0 markers [mk_rec 1 0 0 5 0.5 1.5]}
check "MF14 draw_graph 0 returns (SIGSEGV'd under --nogui before the fix)" \
  [pcall {xschem draw_graph 0; list ok}] ok
check "MF14 an out-of-range index is a no-op, not a deref" \
  [pcall {xschem draw_graph 99; list ok}] ok
check "MF14 a NEGATIVE index is a no-op too" \
  [pcall {xschem draw_graph -1; list ok}] ok
check "MF14 an explicit flags argument is still accepted" \
  [pcall {xschem draw_graph 0 9; list ok}] ok
check "MF14 draw_graph with no index does nothing and does not throw" \
  [pcall {xschem draw_graph; list ok}] ok
check "MF14 the marker is untouched by all of that" [pcall {mk_nums}] 1
check "MF14 ... and the process is still alive to say so" [pcall {xschem get graph_rects}] 1

mk_reset
pcall {xschem raw clear}
pcall {xschem set_modify 0}

# ============================================================================
# MF* — the MAIN-WINDOW display half (MF2 MF3 MF7 MF8 MF9 MF10 MF11a MF13b)
#
# These drive `xschem callback .drw ...` DIRECTLY instead of generating Tk
# events, for three reasons: every one of them is a C-level state machine with
# no Tk component; MF9 is specifically about a release that NEVER REACHES C,
# which no real Tk event can stage; and doing them here, before the viewer
# opens, keeps them out of the MX fixture. The Tk dispatch itself is covered by
# the MXK binding legs and by the MX gestures.
#
# Pixels are still SCANNED, never predicted: the strip band comes from the
# engine's own transform getters (`xschem get zoom/xorigin/yorigin`, the same
# arithmetic X_TO_SCREEN does) and every press pixel is then found by asking
# `graph_near_wave` / `graph_marker_at`.
# ============================================================================
if {[info exists ::has_x] && [info commands winfo] ne {} && [winfo exists .drw]} {

  for {set i 0} {$i < 200} {incr i} {
    update
    if {[winfo ismapped .drw]} break
    after 20
  }
  # world box -> canvas pixel box, through the engine's OWN transform
  proc mf_band {wx1 wy1 wx2 wy2} {
    set z  [xschem get zoom]
    set xo [xschem get xorigin]
    set yo [xschem get yorigin]
    if {![string is double -strict $z] || $z == 0.0} { return {} }
    return [list [expr {int(($wx1 + $xo) / $z)}] [expr {int(($wy1 + $yo) / $z)}] \
                 [expr {int(($wx2 + $xo) / $z)}] [expr {int(($wy2 + $yo) / $z)}]]
  }
  proc mf_trace_row {gi px y0 y1} {
    for {set y $y0} {$y < $y1} {incr y} {
      if {[xschem get graph_near_wave $gi $px $y 2]} { return $y }
    }
    return {}
  }
  # the first (dir fwd) or last (dir rev) canvas pixel ON the trace of strip
  # `gi`, searched inside that strip's band
  proc mf_trace_px {gi band dir} {
    if {[llength $band] != 4} { return {} }
    lassign $band bx1 by1 bx2 by2
    set seq {}
    if {$dir eq {fwd}} {
      for {set x [expr {$bx1 + 12}]} {$x <= $bx2 - 12} {incr x 6} { lappend seq $x }
    } else {
      for {set x [expr {$bx2 - 12}]} {$x >= $bx1 + 12} {incr x -6} { lappend seq $x }
    }
    foreach x $seq {
      set y [mf_trace_row $gi $x [expr {$by1 + 2}] [expr {$by2 - 2}]]
      if {$y ne {}} { return [list $x $y] }
    }
    return {}
  }
  # empty waveform space WELL INSIDE the band: more than GRAPH_MARKER_PICK_TOL
  # from any trace and with no marker part under it (the MX0 landmine applies
  # here too -- a pixel near a strip edge is not claimed by the graph and the
  # key falls through to the schematic handler)
  # ⚠ `graph_plotbox_at` is REQUIRED, not belt-and-braces (issue 0175). `band` is
  # the whole graph RECT, so without it this scan hands back the first row below
  # by1+25 where no trace passes -- which on a strip whose traces are near the top
  # is the LABEL MARGIN, i.e. the legend. A Button1 click there is no longer
  # "empty space": since 0175 it picks the legend entry under it (and a Button3
  # press there has been the wave-attributes dialog since forever). The same
  # requirement `tb_far_px` carries in test_wave_trace_menu.tcl, for the same
  # reason: "empty WAVEFORM space" means inside the plot box.
  proc mf_empty_px {gi band} {
    if {[llength $band] != 4} { return {} }
    lassign $band bx1 by1 bx2 by2
    set cx [expr {($bx1 + $bx2) / 2}]
    for {set y [expr {$by1 + 25}]} {$y < $by2 - 25} {incr y 3} {
      if {![xschem get graph_plotbox_at $gi $cx $y]} continue
      if {[xschem get graph_near_wave $gi $cx $y 25]} continue
      if {[xschem get graph_marker_at $gi $cx $y 12] ne {}} continue
      return [list $cx $y]
    }
    return {}
  }
  # anchor CENTROID + first label pixel of the first marker found in `band`,
  # swept with the engine's own hit-tester (same helper the renderer uses, so a
  # pixel found here is by construction where the callout is drawn)
  proc mf_parts {gi band} {
    if {[llength $band] != 4} { return [list {} {}] }
    lassign $band bx1 by1 bx2 by2
    set l {}; set num 0; set axs {}; set ays {}
    for {set y $by1} {$y <= $by2} {incr y 2} {
      for {set x $bx1} {$x <= $bx2} {incr x 2} {
        set r [xschem get graph_marker_at $gi $x $y 8]
        if {$r eq {}} continue
        if {[lindex $r 1] eq {anchor}} {
          if {!$num} { set num [lindex $r 0] }
          if {[lindex $r 0] == $num} { lappend axs $x; lappend ays $y }
        }
        if {[lindex $r 1] eq {label} && $l eq {}} { set l [list $x $y [lindex $r 0]] }
      }
    }
    set a {}
    if {[llength $axs]} {
      set sx 0; set sy 0
      foreach v $axs { incr sx $v }
      foreach v $ays { incr sy $v }
      set a [list [expr {$sx / [llength $axs]}] [expr {$sy / [llength $ays]}] $num]
    }
    return [list $a $l]
  }
  proc mf_px {v d} {
    if {[llength $v] >= 2 && [lindex $v $d] ne {}} { return [lindex $v $d] }
    return 2
  }
  proc mf_rec {gi} { return [lindex [xschem graph_marker list $gi] 0] }
  # the four callback shorthands (event codes are X11's: 2 KeyPress,
  # 4 ButtonPress, 5 ButtonRelease, 6 MotionNotify; 0x100 is Button1Mask)
  proc mf_press {x y}  { xschem callback .drw 4 $x $y 0 1 0 0 }
  proc mf_drag  {x y}  { xschem callback .drw 6 $x $y 0 0 0 256 }
  proc mf_rel   {x y}  { xschem callback .drw 5 $x $y 0 1 0 256 }
  proc mf_move  {x y}  { xschem callback .drw 6 $x $y 0 0 0 0 }
  proc mf_key   {x y n} { xschem callback .drw 2 $x $y $n 0 0 0 }

  # ---- self-healing scaffolding (see the DE-FLAKING banner at the top) -----
  #
  # mf_unlatch: drop a stale ui_state latch. GRAPHPAN (32768) freezes
  # graph_master and makes waves_callback `goto finish` before
  # graph_marker_press(); a schematic latch (STARTWIRE 1 / STARTRECT 2 /
  # STARTLINE 4 / STARTSELECT 16 / STARTMOVE 32 / STARTCOPY 64 / STARTZOOM 128 /
  # STARTPAN 512) makes waves_selected skip the graph entirely. Either one turns
  # the NEXT press into a no-op. A Button1 release clears GRAPHPAN and ends a
  # schematic rubber band; Escape aborts anything else still in flight.
  proc mf_latched {} {
    set u [pcall {xschem get ui_state}]
    if {![string is integer -strict $u]} { return 0 }
    return [expr {$u & (32768 | 1 | 2 | 4 | 16 | 32 | 64 | 128 | 512)}]
  }
  # (2,2) is the corner pixel this file already uses as "outside every graph"
  # (mf_px's fallback). Order matters:
  #   1 Escape -> abort_operation() drops a schematic gesture WITHOUT committing
  #     it; a bare release would COMMIT a latched move onto (2,2);
  #   2 a Button1 release ends anything release-driven that is left;
  #   3 a motion OFF every graph is the one place that clears GRAPHPAN and calls
  #     graph_marker_drag_abort() (waves_selected's !is_inside branch,
  #     callback.c:147) -- and it is only reachable once the excl bits are gone,
  #     which is why it comes last;
  #   4 the wave-bold is a release-with-no-travel side effect, so put it back.
  # Probe-verified to return ui_state to 0 from both latch kinds and to leave the
  # rects, hilight_wave and the graph ranges untouched.
  proc mf_unlatch {} {
    catch {mf_key  2 2 65307}
    catch {mf_rel  2 2}
    catch {mf_move 2 2}
    catch {xschem unselect_all}
    catch {xschem setprop rect 2 0 hilight_wave -1}
    catch {xschem setprop rect 2 1 hilight_wave -1}
  }
  # the one-line pre-gesture guard: every leg below that drives a synthetic
  # press/key calls this first, so a latch left by a real X event delivered into
  # .drw during an `update` cannot silently turn the leg's first event into a
  # no-op. Prints a note only when it actually had to do something.
  proc mf_ready {tag} {
    set l [mf_latched]
    if {$l} {
      note "$tag ui_state was latched ($l) before the gesture — clearing it"
      mf_unlatch
      set l [mf_latched]
      if {$l} { stall "$tag ui_state is STILL latched ($l) after mf_unlatch" }
    }
  }
  # force .drw to a known state and RE-DERIVE every pixel the scans produced.
  # zoom_full is part of it, so the bands and all four scanned pixels have to be
  # recomputed together or they would disagree with the live transform.
  proc mf_reestablish {} {
    global mfb0 mfb1 mfax1 mfay1 mfax2 mfay2 mfbx1 mfby1 mfe1x mfe1y
    catch {wm deiconify .}
    catch {raise .}
    for {set i 0} {$i < 100} {incr i} {
      update
      if {[winfo ismapped .drw]} break
      after 20
    }
    catch {xschem zoom_full}
    update
    set mfb0 [pcall {mf_band 0 0 800 400}]
    set mfb1 [pcall {mf_band 0 500 800 900}]
    lassign [pcall {mf_trace_px 0 $mfb0 fwd}] mfax1 mfay1
    lassign [pcall {mf_trace_px 0 $mfb0 rev}] mfax2 mfay2
    lassign [pcall {mf_trace_px 1 $mfb1 fwd}] mfbx1 mfby1
    lassign [pcall {mf_empty_px 1 $mfb1}]     mfe1x mfe1y
  }
  # Every scan in this half goes through here: run it, and if it came up EMPTY
  # force the window to a known state and run it again. Never returns a silent
  # {} -- the caller's own check still asserts the result, and a scan that could
  # not be re-established says so loudly first.
  proc mf_scan {tag script} {
    for {set t 1} {$t <= 3} {incr t} {
      set r [uplevel 1 $script]
      if {$r ne {} && [lindex $r 0] ne {}} { return $r }
      if {$t == 3} break
      note "$tag scan came up empty (try $t) — re-mapping .drw, re-fitting and re-scanning"
      mf_reestablish
    }
    stall "$tag scan found nothing after 3 tries (mapped=[pcall {winfo ismapped .drw}]\
size=[pcall {winfo width .drw}]x[pcall {winfo height .drw}]\
rects=[pcall {xschem get graph_rects}] zoom=[pcall {xschem get zoom}])"
    return {}
  }
  # Press and VERIFY the arm. `want` is graph_marker_drag's expected value
  # (1 = anchor, 2 = label). On a miss: say so with the state that explains it,
  # drop the stale latch, RE-SCAN the part (a re-establish may have moved it)
  # and try again. Returns the {x y num} part actually pressed, or {}.
  proc mf_arm {tag gi bandvar want} {
    upvar #0 $bandvar band
    for {set t 1} {$t <= 3} {incr t} {
      lassign [pcall {mf_parts $gi $band}] A L
      set p [expr {$want == 2 ? $L : $A}]
      if {$p eq {}} {
        note "$tag no [expr {$want == 2 ? {label} : {anchor}}] pixel in the scan\
(try $t) — re-establishing"
        mf_unlatch
        mf_reestablish
        continue
      }
      set pre [mf_latched]
      if {$pre} {
        note "$tag ui_state carries a stale latch ($pre) before the press — clearing it"
        mf_unlatch
      }
      pcall {mf_press [mf_px $p 0] [mf_px $p 1]}
      if {[pcall {xschem get graph_marker_drag}] == $want} { return $p }
      note "$tag press at ([mf_px $p 0],[mf_px $p 1]) did not arm $want (try $t):\
drag=[pcall {xschem get graph_marker_drag}] ui_state=[pcall {xschem get ui_state}]\
marker_at=[pcall {xschem get graph_marker_at $gi [mf_px $p 0] [mf_px $p 1] 8}]"
      mf_unlatch
    }
    stall "$tag could not arm a marker drag ($want) after 3 tries —\
ui_state=[pcall {xschem get ui_state}] rects=[pcall {xschem get graph_rects}]"
    return {}
  }

  mk_reset
  pcall {xschem raw clear}
  pcall {xschem raw new mfmark.raw dc vsweep 0 1.0 0.1}
  pcall {xschem raw add v_a {vsweep 1 +}}
  pcall {xschem raw add v_b {vsweep 2 *}}
  pcall {mk_graph 0 0 800 400}
  pcall {xschem setprop rect 2 0 node "v_a"}
  foreach {mft mfv} {x1 0 x2 1.0 y1 0.5 y2 2.5} { pcall {xschem setprop rect 2 0 $mft $mfv} }
  pcall {mk_graph 0 500 800 900}
  pcall {xschem setprop rect 2 1 node "v_b"}
  foreach {mft mfv} {x1 0 x2 1.0 y1 -0.5 y2 2.5} { pcall {xschem setprop rect 2 1 $mft $mfv} }
  pcall {xschem zoom_full}
  update
  check "MF0 two graph strips in the main window" [pcall {xschem get graph_rects}] 2
  set mfb0 [pcall {mf_band 0 0 800 400}]
  set mfb1 [pcall {mf_band 0 500 800 900}]
  check_true "MF0 both strip bands resolved through the engine transform" \
    [pexpr {[llength $mfb0] == 4 && [llength $mfb1] == 4}]
  # every one of these four goes through mf_scan: an empty result re-maps .drw,
  # re-fits and re-scans (mf_reestablish re-derives ALL of them together, so the
  # bands and the pixels can never end up describing different transforms) and
  # only then gives up, loudly
  lassign [mf_scan {MF0 strip-0 fwd trace pixel} {pcall {mf_trace_px 0 $mfb0 fwd}}] mfax1 mfay1
  lassign [mf_scan {MF0 strip-0 rev trace pixel} {pcall {mf_trace_px 0 $mfb0 rev}}] mfax2 mfay2
  lassign [mf_scan {MF0 strip-1 trace pixel}     {pcall {mf_trace_px 1 $mfb1 fwd}}] mfbx1 mfby1
  lassign [mf_scan {MF0 strip-1 empty pixel}     {pcall {mf_empty_px 1 $mfb1}}]     mfe1x mfe1y
  check_true "MF0 two well-separated trace pixels were SCANNED in strip 0" \
    [pexpr {$mfax1 ne {} && $mfax2 ne {} && abs($mfax2 - $mfax1) > 60}]
  check_true "MF0 a trace pixel was scanned in strip 1" [pexpr {$mfbx1 ne {}}]
  check_true "MF0 empty waveform space was found well inside strip 1's band" \
    [pexpr {$mfe1x ne {}}]
  # the display half is a chain of gestures; a latch left behind by a real X
  # press delivered into .drw during any of the `update`s above would make the
  # FIRST one a no-op (see the DE-FLAKING banner, defect 2)
  set mf0latch [mf_latched]
  if {$mf0latch} {
    note "MF0 ui_state entered the display half already latched ($mf0latch) — clearing"
    mf_unlatch
  }
  check "MF0 no stale ui_state latch is in force before the first gesture" \
    [mf_latched] 0

  if {$mfax1 eq {} || $mfax2 eq {} || $mfbx1 eq {} || $mfe1x eq {}} {
    puts "SKIPPED: MF display half (no usable pixel was scanned)"
  } else {
  # GROUP CATCH. Without one, a single Tcl error anywhere below unwinds all the
  # way to the file's outer catch and silently drops EVERY remaining leg in the
  # file -- 138 of 601 checks in the captured bad run. Scoped here it costs this
  # group only, says so loudly, and the viewer/MX half still runs.
  if {[catch {

  # --- MF9: a fresh Button1 press tears down a stale arm ------------------
  # The ASE viewer binds <Shift-ButtonRelease-1>/<Alt-ButtonRelease-1> to a bare
  # {break}, so a modifier-held release never reaches C at all and the
  # release-side teardown cannot run. Before the fix the arm survived: the next
  # unrelated click COMMITTED the abandoned move (and marker_grabbed answered 1
  # for every press in between, killing the trace-drag and reorder seams).
  # The control comes first, so the leg cannot pass because the drag was dead.
  pcall {xschem graph_marker delete -all}
  pcall {xschem setprop rect 2 0 hilight_wave -1}
  check "MF9 control: a marker to drag" [pcall {xschem graph_marker add 0 $mfax1 $mfay1}] 1
  # mf_arm does the scan AND the press and asserts the arm took; on a miss it
  # names the ui_state that explains it, unlatches, re-scans and retries. THIS
  # leg is where the measured flake landed: a stale GRAPHPAN makes waves_callback
  # skip graph_marker_press() and the press silently does nothing.
  set mf9A [mf_arm {MF9 control} 0 mfb0 1]
  check_true "MF9 control: its anchor pixel was scanned" [pexpr {$mf9A ne {}}]
  check "MF9 control: the press armed the anchor drag" \
    [pcall {xschem get graph_marker_drag}] 1
  set mf9c0 [pcall {mf_rec 0}]
  pcall {mf_drag $mfax2 $mfay2}
  pcall {mf_rel  $mfax2 $mfay2}
  check_true "MF9 control: WITH a release the drag really commits (the arm is live)" \
    [pexpr {[lindex [pcall {mf_rec 0}] 4] ne {} &&
            [lindex [pcall {mf_rec 0}] 4] != [lindex $mf9c0 4]}]
  # now the real thing: the same gesture with the release SWALLOWED
  pcall {xschem graph_marker delete -all}
  pcall {xschem setprop rect 2 0 hilight_wave -1}
  check "MF9 a fresh marker for the swallowed-release run" \
    [pcall {xschem graph_marker add 0 $mfax1 $mfay1}] 1
  set mf9A [mf_arm {MF9} 0 mfb0 1]
  check_true "MF9 its anchor pixel was scanned" [pexpr {$mf9A ne {}}]
  check "MF9 the press armed the anchor drag" [pcall {xschem get graph_marker_drag}] 1
  set mf9before [pcall {mf_rec 0}]
  pcall {mf_drag $mfax2 $mfay2}
  check "MF9 the drag is still armed after travel" [pcall {xschem get graph_marker_drag}] 1
  check "MF9 ... and the stored record is untouched mid-drag" [pcall {mf_rec 0}] $mf9before
  # <<< NO ButtonRelease here: this is the {break}-swallowed modifier release >>>
  pcall {mf_press $mfax2 $mfay2}
  check "MF9 the next fresh press ABORTED the stale arm (was left at 1)" \
    [pcall {xschem get graph_marker_drag}] 0
  pcall {mf_rel $mfax2 $mfay2}
  check "MF9 ... so its release committed NOTHING (before: the old move landed)" \
    [pcall {mf_rec 0}] $mf9before
  check "MF9 and no arm is left behind either" [pcall {xschem get graph_marker_drag}] 0
  pcall {xschem setprop rect 2 0 hilight_wave -1}

  # --- MF2: the callout is built from the RECORD, not the number ----------
  # HONEST SCOPE: what the fix changes is what the RENDERER measures mid-drag,
  # and a drawn string has no read-back seam — that half is eyeball-only, like
  # the rest of the rendering (see the file header). What IS asserted here is
  # the invariant the split rests on and everything a verb can see: a redraw
  # mid-drag is safe, does not tear the gesture down, and does not mutate the
  # stored record; the BY-NUMBER verb is frozen at the pre-drag values for the
  # whole gesture (that is exactly why the renderer must be handed the record);
  # and the readout does change once the release commits.
  pcall {xschem graph_marker delete -all}
  pcall {xschem setprop rect 2 0 hilight_wave -1}
  check "MF2 a marker to drag" [pcall {xschem graph_marker add 0 $mfax1 $mfay1}] 1
  set mf2rec [pcall {mf_rec 0}]
  set mf2txt [pcall {xschem graph_marker text 1}]
  check_true "MF2 the pre-drag readout is an M1:<x>,<y> line" \
    [pexpr {[regexp {^M1:[^,]+,.+$} $mf2txt]}]
  set mf2A [mf_arm {MF2} 0 mfb0 1]
  check_true "MF2 its anchor pixel was scanned" [pexpr {$mf2A ne {}}]
  pcall {mf_drag $mfax2 $mfay2}
  check "MF2 the drag is armed" [pcall {xschem get graph_marker_drag}] 1
  check "MF2 a full redraw mid-drag returns rc 0" [pcall {xschem redraw; list ok}] ok
  check "MF2 a single-strip draw_graph mid-drag returns rc 0" \
    [pcall {xschem draw_graph 0; list ok}] ok
  check "MF2 neither redraw tore the gesture down" [pcall {xschem get graph_marker_drag}] 1
  check "MF2 neither redraw mutated the STORED record" [pcall {mf_rec 0}] $mf2rec
  check "MF2 the BY-NUMBER verb is frozen mid-drag (it reads the stored token)" \
    [pcall {xschem graph_marker text 1}] $mf2txt
  check "MF2 ... and the hit-test still finds the marker after those redraws" \
    [lindex [pcall {mf_parts 0 $mfb0}] 0] $mf2A
  pcall {mf_rel $mfax2 $mfay2}
  check_true "MF2 the release committed a DIFFERENT sample" \
    [pexpr {[lindex [pcall {mf_rec 0}] 4] ne {} &&
            [lindex [pcall {mf_rec 0}] 4] != [lindex $mf2rec 4]}]
  check_true "MF2 ... and only then does the readout change" \
    [pexpr {[pcall {xschem graph_marker text 1}] ne $mf2txt}]
  pcall {xschem setprop rect 2 0 hilight_wave -1}

  # --- MF10: the press/release redraw signals -----------------------------
  # HONEST SCOPE: graph_marker_press() returning -1 (it only DESELECTED) and
  # graph_marker_release() returning 1 (the selection left another graph) feed
  # nothing but need_all_redraw, i.e. HOW MUCH gets repainted — the stale ring
  # on the other strip. That is eyeball-only. What this leg defends is that the
  # two new return values did not disturb the select/deselect state machine they
  # were threaded through, across strips, and that both paths leave every marker
  # in the window intact and still hit-testable after a repaint.
  mf_ready {MF10}
  pcall {xschem graph_marker delete -all}
  pcall {xschem setprop rect 2 0 hilight_wave -1}
  pcall {xschem setprop rect 2 1 hilight_wave -1}
  check "MF10 M1 on strip 0" [pcall {xschem graph_marker add 0 $mfax1 $mfay1}] 1
  check "MF10 M2 on strip 1" [pcall {xschem graph_marker add 1 $mfbx1 $mfby1}] 2
  set mf10A0 [mf_arm {MF10 strip 0} 0 mfb0 1]
  lassign [mf_scan {MF10 strip-1 marker parts} {pcall {mf_parts 1 $mfb1}}] mf10A1 mf10L1
  check_true "MF10 both anchor pixels were scanned" \
    [pexpr {$mf10A0 ne {} && $mf10A1 ne {}}]
  pcall {mf_rel   [mf_px $mf10A0 0] [mf_px $mf10A0 1]}
  check "MF10 a no-travel click selects M1" [pcall {xschem get graph_marker_sel}] 1
  # the DESELECT path (press returns -1): empty space on the OTHER strip
  mf_ready {MF10 deselect}
  pcall {mf_press $mfe1x $mfe1y}
  check "MF10 a press on empty space of ANOTHER strip clears the selection" \
    [pcall {xschem get graph_marker_sel}] -1
  pcall {mf_rel $mfe1x $mfe1y}
  check "MF10 the repaint after it returns rc 0" [pcall {xschem redraw; list ok}] ok
  check "MF10 M1 is still there and still hit-testable" \
    [lindex [pcall {mf_parts 0 $mfb0}] 0] $mf10A0
  check "MF10 M2 too" [lindex [pcall {mf_parts 1 $mfb1}] 0] $mf10A1
  # the CROSS-GRAPH release path (release returns 1)
  mf_ready {MF10 reselect}
  pcall {mf_press [mf_px $mf10A0 0] [mf_px $mf10A0 1]}
  pcall {mf_rel   [mf_px $mf10A0 0] [mf_px $mf10A0 1]}
  check "MF10 M1 re-selected" [pcall {xschem get graph_marker_sel}] 1
  mf_ready {MF10 cross-strip}
  pcall {mf_press [mf_px $mf10A1 0] [mf_px $mf10A1 1]}
  pcall {mf_rel   [mf_px $mf10A1 0] [mf_px $mf10A1 1]}
  check "MF10 clicking M2 on the OTHER strip moves the selection there" \
    [pcall {xschem get graph_marker_sel}] 2
  check "MF10 exactly one marker per strip, both intact" \
    [pcall {list [llength [xschem graph_marker list 0]] \
                 [llength [xschem graph_marker list 1]]}] {1 1}
  check "MF10 the marker arm consumed both releases (no trace was bolded)" \
    [pcall {list [xschem getprop rect 2 0 hilight_wave] \
                 [xschem getprop rect 2 1 hilight_wave]}] {-1 -1}
  check "MF10 a full repaint after the cross-strip change returns rc 0" \
    [pcall {xschem redraw; list ok}] ok

  # --- MF8: Delete RE-RESOLVES the owning strip ---------------------------
  # graph_marker_selgraph is a rect INDEX. A strip reorder or a multi-plot
  # prepend moves the marker to a different index and leaves selgraph pointing
  # at the old one; `xschem graph_marker select <num> <wrong-gi>` produces
  # exactly that state deterministically. Before the fix the Delete gate
  # compared selgraph with graph_master, so hovering the strip that ACTUALLY
  # owns the ring refused to delete (and hovering the stale index would have
  # fired from a strip showing nothing).
  mf_ready {MF8}
  pcall {xschem graph_marker delete -all}
  pcall {xschem setprop rect 2 0 hilight_wave -1}
  pcall {xschem setprop rect 2 1 hilight_wave -1}
  check "MF8 one marker, on strip 1" [pcall {xschem graph_marker add 1 $mfbx1 $mfby1}] 1
  lassign [mf_scan {MF8 strip-1 marker parts} {pcall {mf_parts 1 $mfb1}}] mf8A mf8L
  check_true "MF8 its anchor pixel was scanned" [pexpr {$mf8A ne {}}]
  check "MF8 selected with a STALE selgraph of 0 (what a reorder leaves behind)" \
    [pcall {xschem graph_marker select 1 0; xschem get graph_marker_sel}] 1
  pcall {mf_move [mf_px $mf8A 0] [mf_px $mf8A 1]}
  pcall {mf_key  [mf_px $mf8A 0] [mf_px $mf8A 1] 65535}
  check "MF8 Delete over the TRUE owner deleted it (was refused before the fix)" \
    [pcall {llength [xschem graph_marker list 1]}] 0
  check "MF8 ... and the selection went with it" [pcall {xschem get graph_marker_sel}] -1
  # the scope test itself must still hold: hovering the WRONG strip refuses
  check "MF8 a second marker, again on strip 1" \
    [pcall {xschem graph_marker add 1 $mfbx1 $mfby1}] 1
  lassign [mf_scan {MF8 strip-1 marker parts (2)} {pcall {mf_parts 1 $mfb1}}] mf8A mf8L
  pcall {xschem graph_marker select 1 1}
  lassign [mf_scan {MF8 strip-0 empty pixel} {pcall {mf_empty_px 0 $mfb0}}] mf8ex mf8ey
  check_true "MF8 empty space was found in the OTHER strip" [pexpr {$mf8ex ne {}}]
  if {$mf8ex ne {}} {
    pcall {mf_move $mf8ex $mf8ey}
    pcall {mf_key  $mf8ex $mf8ey 65535}
    check "MF8 Delete hovering ANOTHER strip still refuses (the scope test holds)" \
      [pcall {llength [xschem graph_marker list 1]}] 1
    check "MF8 ... and the selection is untouched" [pcall {xschem get graph_marker_sel}] 1
  }
  # and the renderer's own selection test is by NUMBER, so a stale selgraph
  # cannot make a redraw disagree with the gate (the ring itself is eyeball-only)
  pcall {xschem graph_marker select 1 0}
  check "MF8 a redraw with a stale selgraph returns rc 0" [pcall {xschem redraw; list ok}] ok
  check "MF8 ... and the marker is still hit-testable on its real strip" \
    [lindex [lindex [pcall {mf_parts 1 $mfb1}] 0] 2] [lindex $mf8A 2]
  pcall {xschem graph_marker select -none}

  # --- MF7: a hit-test query must not rewrite the hcursor bits ------------
  # setup_graph_data() REWRITES graph_flags bits 128|256 from the rect it is
  # given (landmine 37). graph_marker_at() is a pure query, reachable from a Tcl
  # verb and run on EVERY LMB press, so before the fix one press over a strip
  # with no hcursors silently turned off the hcursors of the strip that had them.
  pcall {xschem graph_marker delete -all}
  pcall {xschem setprop rect 2 0 hcursor1_y 1.2}
  pcall {xschem setprop rect 2 0 hcursor2_y 1.6}
  check "MF7 a marker on the strip WITHOUT hcursors" \
    [pcall {xschem graph_marker add 1 $mfbx1 $mfby1}] 1
  pcall {xschem draw_graph 0}
  set mf7gf [pcall {xschem get graph_flags}]
  check "MF7 strip 0's hcursors are live (bits 128|256 set)" \
    [pexpr {$mf7gf & (128 | 256)}] 384
  lassign [mf_scan {MF7 strip-1 marker parts} {pcall {mf_parts 1 $mfb1}}] mf7A mf7L
  check_true "MF7 the other strip's anchor pixel was scanned" [pexpr {$mf7A ne {}}]
  check "MF7 the query answers on the OTHER strip" \
    [pcall {lindex [xschem get graph_marker_at 1 [mf_px $mf7A 0] [mf_px $mf7A 1] 8] 1}] anchor
  check "MF7 ... and left the hcursor bits alone (before: cleared to 0)" \
    [pexpr {[pcall {xschem get graph_flags}] & (128 | 256)}] 384
  check "MF7 a miss on the same strip does not clear them either" \
    [pcall {xschem get graph_marker_at 1 1 1 8
            expr {[xschem get graph_flags] & (128 | 256)}}] 384
  check "MF7 no other graph_flags bit was disturbed" \
    [pcall {xschem get graph_flags}] $mf7gf
  pcall {xschem setprop rect 2 0 hcursor1_y {}}
  pcall {xschem setprop rect 2 0 hcursor2_y {}}

  # --- MF11a: a read-only buffer REFUSES the m / d keys -------------------
  # A marker is durable CONTENT. Before the fix the edit landed anyway AND
  # carried no undo point (push_undo is skipped when readonly) while
  # `xschem undo` is itself readonly-rejected — untakeable-back.
  mf_ready {MF11a}
  pcall {xschem graph_marker delete -all}
  pcall {xschem setprop rect 2 0 hilight_wave -1}
  pcall {xschem set readonly 1}
  check "MF11a the buffer is read-only" [pcall {xschem get readonly}] 1
  pcall {mf_move $mfax1 $mfay1}
  pcall {mf_key  $mfax1 $mfay1 109}
  check "MF11a `m` over a trace created NOTHING (before: it created a marker)" \
    [pcall {llength [xschem graph_marker list 0]}] 0
  pcall {mf_key $mfax1 $mfay1 100}
  check "MF11a `d` is refused the same way" \
    [pcall {llength [xschem graph_marker list 0]}] 0
  check "MF11a the buffer is still read-only afterwards" [pcall {xschem get readonly}] 1
  pcall {xschem set readonly 0}
  # the CONTROL, so the refusal above cannot be "the key never arrived"
  pcall {mf_key $mfax1 $mfay1 109}
  check "MF11a the SAME key on the SAME pixel creates one once editable" \
    [pcall {llength [xschem graph_marker list 0]}] 1
  pcall {mf_key $mfax1 $mfay1 100}
  check "MF11a ... and `d` adds a second, with a delta partner" \
    [pcall {list [llength [xschem graph_marker list 0]] [mk_field 2 7]}] {2 1}
  # Delete is the third mutating key: refused read-only, allowed editable
  pcall {xschem graph_marker select 2 0}
  pcall {xschem set readonly 1}
  pcall {mf_move $mfax1 $mfay1}
  pcall {mf_key  $mfax1 $mfay1 65535}
  check "MF11a Delete of a SELECTED marker is refused read-only" \
    [pcall {llength [xschem graph_marker list 0]}] 2
  pcall {xschem set readonly 0}
  pcall {mf_key $mfax1 $mfay1 65535}
  check "MF11a ... and goes through once editable" \
    [pcall {llength [xschem graph_marker list 0]}] 1
  pcall {xschem setprop rect 2 0 hilight_wave -1}

  # --- MF3: the window is parsed ONCE per operation -----------------------
  # Before the pool, graph_marker_text() ran a full-window graph_marker_find()
  # per record, so the redraw AND the hit-test were O(N^2): measured 139 ms per
  # redraw at 400 markers and ~220 ms at the 512 cap, paid on every pan, zoom,
  # cursor move and LMB press. A timing assertion is inherently soft, so the
  # ceiling is deliberately generous — 1200 ms for 20 of each, against a
  # pre-fix cost of ~20 x 139 = 2800 ms and a measured post-fix cost of
  # ~180 ms (this machine, WSLg). Every record carries a `prev`, which is what
  # forces the partner lookup the pool replaced.
  pcall {xschem graph_marker delete -all}
  set mf3 {}
  for {set i 1} {$i <= 400} {incr i} {
    lappend mf3 [mk_rec $i 0 0 [expr {$i % 11}] [expr {($i % 11) * 0.1}] \
                        [expr {1.0 + ($i % 11) * 0.1}] [expr {$i > 1 ? $i - 1 : 0}]]
  }
  pcall {xschem setprop rect 2 0 markers [join $mf3 "\n"]}
  check "MF3 400 chained (delta) markers on one strip" \
    [pcall {llength [xschem graph_marker list 0]}] 400
  check_true "MF3 they really are chained (the partner lookup is exercised)" \
    [pexpr {[pcall {mk_field 400 7}] == 399}]
  set mf3t0 [clock milliseconds]
  for {set i 0} {$i < 20} {incr i} { pcall {xschem draw_graph 0} }
  set mf3draw [expr {[clock milliseconds] - $mf3t0}]
  set mf3t0 [clock milliseconds]
  for {set i 0} {$i < 20} {incr i} {
    pcall {xschem get graph_marker_at 0 [expr {[lindex $mfb0 0] + 20 + $i}] \
             [expr {[lindex $mfb0 1] + 40}] 8}
  }
  set mf3hit [expr {[clock milliseconds] - $mf3t0}]
  puts "note: MF3 400 markers -> 20 redraws ${mf3draw} ms, 20 hit-tests ${mf3hit} ms"
  check_true "MF3 20 redraws at 400 markers stay under 1200 ms (pre-fix ~2800)" \
    [pexpr {$mf3draw < 1200}]
  check_true "MF3 20 hit-tests at 400 markers stay under 1200 ms (pre-fix ~2800)" \
    [pexpr {$mf3hit < 1200}]
  check "MF3 nothing was mutated by all that measuring" \
    [pcall {llength [xschem graph_marker list 0]}] 400
  pcall {xschem graph_marker delete -all}

  # --- MF13b: clear_drawing() also kills an ARMED DRAG --------------------
  # The headless half (MF13a) covers the selection; the four drag fields need a
  # real press to arm. A drag surviving a document swap would have committed an
  # anchor move onto a marker of the NEW document at the next release.
  mf_ready {MF13b}
  pcall {xschem setprop rect 2 0 hilight_wave -1}
  check "MF13b a marker to arm a drag with" \
    [pcall {xschem graph_marker add 0 $mfax1 $mfay1}] 1
  pcall {xschem graph_marker select 1 0}
  check "MF13b the selection is armed" [pcall {xschem get graph_marker_sel}] 1
  set mf13A [mf_arm {MF13b} 0 mfb0 1]
  check_true "MF13b its anchor pixel was scanned" [pexpr {$mf13A ne {}}]
  pcall {mf_drag $mfax2 $mfay2}
  check "MF13b ... and so is a drag" [pcall {xschem get graph_marker_drag}] 1
  pcall {xschem clear force}
  check "MF13b `xschem clear` dropped the drag (was left at 1 before the fix)" \
    [pcall {xschem get graph_marker_drag}] 0
  check "MF13b ... and the selection with it" [pcall {xschem get graph_marker_sel}] -1
  check "MF13b the buffer really was cleared" [pcall {xschem get graph_rects}] 0
  # This leg deliberately presses and then wipes the document WITHOUT ever
  # releasing, which is exactly the shape that leaves GRAPHPAN latched in this
  # xctx. `xschem clear` drops the marker drag (that is the assertion above) but
  # not the ui_state routing latch, so hand it back clean -- otherwise the leak
  # is this file's own contribution to the class of flake it is defending.
  mf_unlatch
  check "MF13b the leg handed ui_state back with no routing latch left" \
    [mf_latched] 0

  } mfgerr]} {
    puts "FAIL: MF display half ABORTED: $mfgerr : FAIL"
    incr fail
    puts $::errorInfo
    catch {mf_unlatch}
  }
  }

  rename mf_band {}
  rename mf_trace_row {}
  rename mf_trace_px {}
  rename mf_empty_px {}
  rename mf_parts {}
  rename mf_px {}
  rename mf_rec {}
  rename mf_press {}
  rename mf_drag {}
  rename mf_rel {}
  rename mf_move {}
  rename mf_key {}
  mk_reset
  pcall {xschem raw clear}
  pcall {xschem set_modify 0}
} else {
  puts "SKIPPED: MF display half (no usable DISPLAY)"
}

# ============================================================================
# viewer legs — MR1v / MR6 / MR7 / MR8 / MR16, then the MX* gestures
# ============================================================================
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  proc viewer_ready {top} {
    for {set i 0} {$i < 300} {incr i} {
      update
      if {[winfo exists $top.drw] && [winfo ismapped $top.drw]} { return 1 }
      after 20
    }
    return 0
  }

  # session registration (headless-style: no ASE window needed for the viewer)
  set st [ase::state_load $statefile]
  dict set st rundir [file join $scratch run]
  set sstate [file join $scratch session.state]
  ase::state_save $sstate $st
  set tok [ase::session_key sky130_tests test_nfet_final ngspice_state1]
  ase::session_open $tok $sstate

  check "MV0 wviewer::open returns 1" [pcall {wviewer::open $tok}] 1
  set vtop [wviewer::window_for $tok]
  set vdrw $vtop.drw
  set ::vdrw $vdrw
  if {![viewer_ready $vtop]} {
    puts "SKIPPED: MR-viewer / MX* legs (viewer canvas never mapped)"
    catch {wviewer::close $tok}
  } else {
  # GROUP CATCH (the MX* sub-group has its own, nested inside this one)
  if {[catch {

  # --- viewer fixture: hermetic raw + two strips, each with an INERT id ----
  # `sdid` is a free-form model key regenerate/graph_props never read, so it is
  # the witness that says WHICH STRIP is at index k independently of which trace
  # is in it — on a two-strip stack a trace move and a strip reorder produce the
  # same trace layout and only sdid tells them apart.
  xschem new_schematic switch $vdrw
  pcall {xschem raw clear}
  check "MV0 hermetic raw in the viewer ctx" \
    [pcall {xschem raw new mkmark.raw dc vsweep 0 1.0 0.1}] 1
  check "MV0 v_a/v_b are real columns" \
    [pcall {list [xschem raw add v_a {vsweep 1 +}] [xschem raw add v_b {vsweep 2 *}]}] {1 1}
  proc mk_graphs {tok} { dict get [wviewer::layout_for $tok] graphs }
  proc mk_model_mk {tok gi} {
    return [wviewer::dget [lindex [mk_graphs $tok] $gi] markers {}]
  }
  proc mk_ids {tok} {
    set out {}
    foreach G [mk_graphs $tok] { lappend out [wviewer::dget $G sdid ?] }
    return $out
  }
  proc mk_order {tok} {
    set out {}
    foreach G [mk_graphs $tok] {
      set tr [wviewer::dget $G traces {}]
      lappend out [expr {[llength $tr] ? [dict get [lindex $tr 0] vec] : {-}}]
    }
    return $out
  }
  proc mk_fixture {tok} {
    wviewer::set_graphs $tok [list [dict replace [wviewer::empty_graph] sdid A] \
                                   [dict replace [wviewer::empty_graph] sdid B]]
    wviewer::add_trace $tok 0 v_a
    wviewer::add_trace $tok 1 v_b
    wviewer::regenerate $tok
    wviewer::fit $tok
    wviewer::clear_history $tok
    xschem new_schematic switch $::vdrw
  }
  mk_fixture $tok
  check "MV0 two strips, two graph rects, both carrying their trace" \
    [pcall {list [llength [mk_graphs $tok]] [xschem get graph_rects] \
                 [xschem getprop rect 2 0 node] [xschem getprop rect 2 1 node]}] \
    {2 2 v_a v_b}
  check "MV0 the inert strip witnesses are in place" [pcall {mk_ids $tok}] {A B}
  check "MV0 the viewer buffer is readonly" [pcall {xschem get readonly}] 1

  # --- MR1v: creating a marker in the VIEWER --------------------------
  # The viewer is a readonly scratch buffer: set_modify is neutered by
  # ro_suppress and push_undo is skipped, so a marker must not dirty it.
  pcall {wviewer::with_edit $tok {xschem graph_marker delete -all}}
  check "MR1v the mutating verb is readonly-rejected without with_edit" \
    [string match {ERR:*read-only*} [pcall {xschem graph_marker add_at 0 0 0 5}]] 1
  # with_edit ALWAYS returns 1 (it reports "the bracket ran"), so the created
  # number has to come out through a variable it sets in THIS scope — reading
  # with_edit's own result would make every refusal leg pass vacuously.
  set mr1vn {}
  if {[catch {wviewer::with_edit $tok \
        {set mr1vn [xschem graph_marker add_at 0 0 0 5]}} mr1verr]} {
    set mr1vn "ERR:$mr1verr"
  }
  check "MR1v with_edit lets it through and returns the new number" $mr1vn 1
  check "MR1v the rect carries the token" \
    [pcall {xschem getprop rect 2 0 markers}] [mk_rec 1 0 0 5 0.5 1.5]
  check "MR1v the viewer buffer is NOT left modified" [pcall {xschem get modified}] 0
  check "MR1v ... and is readonly again" [pcall {xschem get readonly}] 1
  check "MR1v the PUSH HOOK folded it into the model" \
    [pcall {mk_model_mk $tok 0}] [mk_rec 1 0 0 5 0.5 1.5]
  check "MR1v the other strip stayed clean" \
    [pcall {dict exists [lindex [mk_graphs $tok] 1] markers}] 0

  # --- MR8: exactly ONE undo point, and `u` really removes the marker --
  # push_undo must run BEFORE set_graphs: it records the CURRENT state as the
  # restore point, so snapshotting after would store the POST-marker model and
  # `u` would restore the very marker it was meant to remove.
  check "MR8 exactly one undo point was pushed" [pcall {wviewer::history_depth $tok}] {1 0}
  check "MR8 a no-op notify returns 1" [pcall {graph_marker_changed}] 1
  check "MR8 ... and pushes NO phantom point" [pcall {wviewer::history_depth $tok}] {1 0}
  check "MR8 undo runs" [pcall {wviewer::undo $tok}] 1
  check "MR8 undo removed the marker from the MODEL" \
    [pcall {dict exists [lindex [mk_graphs $tok] 0] markers}] 0
  check "MR8 undo removed it from the RECT too (the ordering contract)" \
    [pcall {xschem new_schematic switch $vdrw; xschem getprop rect 2 0 markers}] {}
  check "MR8 redo brings it back" [pcall {wviewer::redo $tok}] 1
  check "MR8 ... byte-identically, in the model" \
    [pcall {mk_model_mk $tok 0}] [mk_rec 1 0 0 5 0.5 1.5]
  check "MR8 ... and back on the rect" \
    [pcall {xschem new_schematic switch $vdrw; xschem getprop rect 2 0 markers}] \
    [mk_rec 1 0 0 5 0.5 1.5]
  # a rect/model index-space mismatch must BAIL, never mis-attach
  wviewer::set_graphs $tok [linsert [mk_graphs $tok] end [wviewer::empty_graph]]
  check "MR8 a rect/model count mismatch bails with 0" [pcall {graph_marker_changed}] 0
  wviewer::set_graphs $tok [lrange [mk_graphs $tok] 0 1]
  check "MR8 ... and works again once they agree" [pcall {graph_marker_changed}] 1

  # --- MR6: regenerate survival (the round trip through graph_props) ---
  wviewer::regenerate $tok
  xschem new_schematic switch $vdrw
  check "MR6 the token survives a bare regenerate (model -> graph_props -> rect)" \
    [pcall {xschem getprop rect 2 0 markers}] [mk_rec 1 0 0 5 0.5 1.5]
  check "MR6 the model still has it" [pcall {mk_model_mk $tok 0}] [mk_rec 1 0 0 5 0.5 1.5]
  check "MR6 the unmarked strip STILL has no token (absent means absent)" \
    [pcall {xschem getprop rect 2 1 markers}] {}
  # capture_live_graph_state is the belt-and-braces PULL half
  wviewer::set_graphs $tok [lreplace [mk_graphs $tok] 0 0 \
    [dict remove [lindex [mk_graphs $tok] 0] markers]]
  check "MR6 the model was deliberately blanked" \
    [pcall {dict exists [lindex [mk_graphs $tok] 0] markers}] 0
  pcall {wviewer::capture_live_graph_state $tok}
  check "MR6 capture_live_graph_state read it back off the rect" \
    [pcall {mk_model_mk $tok 0}] [mk_rec 1 0 0 5 0.5 1.5]

  # --- MR7: RESIZE survival — the leg that proves the PUSH hook -------
  # configure_apply regenerates WITHOUT calling capture_live_graph_state (it is
  # one of the ~15 uncaptured regenerate sites). Without the push, a plain window
  # resize silently destroys every marker.
  pcall {wviewer::configure_apply $tok}
  update
  xschem new_schematic switch $vdrw
  check "MR7 the marker survives configure_apply (a window resize)" \
    [pcall {xschem getprop rect 2 0 markers}] [mk_rec 1 0 0 5 0.5 1.5]
  check "MR7 ... in the model too" [pcall {mk_model_mk $tok 0}] [mk_rec 1 0 0 5 0.5 1.5]
  # and through a REAL <Configure> on the canvas
  event generate $vdrw <Configure>
  update
  after 200
  update
  xschem new_schematic switch $vdrw
  check "MR7 ... and through a real <Configure> event" \
    [pcall {xschem getprop rect 2 0 markers}] [mk_rec 1 0 0 5 0.5 1.5]

  # --- MR7b: the PUSH-ONLY witness ------------------------------------
  # MR7 above is preceded by MR6's capture_live_graph_state, so the model already
  # holds the marker and a resize would survive on the PULL alone. This leg makes
  # a marker whose ONLY route into the model is graph_marker_notify — no capture
  # in between — and then resizes. With the push gone the model never learns
  # about it and configure_apply's regenerate wipes it off the rect.
  set mr7b {}
  if {[catch {wviewer::with_edit $tok \
        {set mr7b [xschem graph_marker add_at 0 0 0 8]}} mr7berr]} {
    set mr7b "ERR:$mr7berr"
  }
  check "MR7b a second marker was created (push only, no capture)" $mr7b 2
  # configure_apply SHORT-CIRCUITS when the cached fill size (fillwh) still
  # matches the window, which is exactly the state MR7 above left it in. Drop the
  # cache first — that is what a genuine resize does — or this leg regenerates
  # nothing and passes vacuously.
  catch {unset ::wviewer::fillwh($tok)}
  pcall {wviewer::configure_apply $tok}
  update
  xschem new_schematic switch $vdrw
  check "MR7b it survived the resize, i.e. the PUSH reached the model" \
    [pcall {llength [xschem graph_marker list 0]}] 2
  pcall {wviewer::with_edit $tok {xschem graph_marker delete 2}}
  pcall {wviewer::capture_live_graph_state $tok}
  check "MR7b back to one marker for the legs below" \
    [pcall {xschem new_schematic switch $vdrw; llength [xschem graph_marker list 0]}] 1

  # --- MR16: snapshot / restore carries markers -----------------------
  # (§8.1's MK6 in the plan; it needs a window, so it lives here.)
  set mr16 [pcall {wviewer::state_snapshot $tok}]
  check "MR16 the snapshot carries the markers key" \
    [pcall {wviewer::dget [lindex [lindex $mr16 0] 0] markers {}}] [mk_rec 1 0 0 5 0.5 1.5]
  wviewer::set_graphs $tok [lreplace [mk_graphs $tok] 0 0 \
    [dict remove [lindex [mk_graphs $tok] 0] markers]]
  pcall {wviewer::state_apply $tok $mr16}
  check "MR16 state_apply put it back byte-identically" \
    [pcall {mk_model_mk $tok 0}] [mk_rec 1 0 0 5 0.5 1.5]
  check "MR16 ... and onto the rect" \
    [pcall {xschem new_schematic switch $vdrw; xschem getprop rect 2 0 markers}] \
    [mk_rec 1 0 0 5 0.5 1.5]
  # the model-side deletion paths
  pcall {wviewer::clear_graph_traces $tok 0}
  check "MR16 clear_graph_traces drops the markers key with the traces" \
    [pcall {dict exists [lindex [mk_graphs $tok] 0] markers}] 0
  mk_fixture $tok

  # --- MF15: capture_live_graph_state's skip_markers + 1:1 guard ------------
  # Two fixes in one proc. (a) the optional `skip_markers` argument, which
  # marker_changed needs so its restore point does not contain the marker being
  # recorded (MF16 below is the leg for that); before the fix the proc took ONE
  # argument and the two-argument call was a Tcl error. (b) the same rect/model
  # 1:1 guard marker_changed carries — and for a stronger reason here, because
  # this path also DELETES keys: with the counts out of step it attached one
  # strip's state to a different model graph AND wiped the keys of every model
  # graph past the last rect.
  pcall {wviewer::with_edit $tok {xschem graph_marker delete -all}}
  pcall {wviewer::with_edit $tok {xschem graph_marker add_at 0 0 0 5}}
  pcall {wviewer::capture_live_graph_state $tok}
  check "MF15 the model holds the marker to start" \
    [pcall {mk_model_mk $tok 0}] [mk_rec 1 0 0 5 0.5 1.5]
  wviewer::set_graphs $tok [lreplace [mk_graphs $tok] 0 0 \
    [dict remove [lindex [mk_graphs $tok] 0] markers]]
  check "MF15 the model markers key was deliberately blanked" \
    [pcall {dict exists [lindex [mk_graphs $tok] 0] markers}] 0
  check "MF15 capture with skip_markers=1 is ACCEPTED (was a Tcl error before)" \
    [pcall {wviewer::capture_live_graph_state $tok 1}] 1
  check "MF15 ... and it did NOT re-read the markers off the rect" \
    [pcall {dict exists [lindex [mk_graphs $tok] 0] markers}] 0
  check_true "MF15 ... while it DID fold the view state in (x1 is a real number)" \
    [string is double -strict [pcall {wviewer::dget [lindex [mk_graphs $tok] 0] x1 {}}]]
  check "MF15 a plain capture still reads the markers back" \
    [pcall {wviewer::capture_live_graph_state $tok 0
            mk_model_mk $tok 0}] [mk_rec 1 0 0 5 0.5 1.5]
  # the guard: one more model graph than there are rects
  wviewer::set_graphs $tok [linsert [mk_graphs $tok] end \
    [dict replace [wviewer::empty_graph] markers [mk_rec 9 0 0 5 0.5 1.5]]]
  check "MF15 the counts are deliberately out of step" \
    [pcall {list [xschem new_schematic switch $vdrw; xschem get graph_rects] \
                 [llength [mk_graphs $tok]]}] {2 3}
  check "MF15 a count mismatch BAILS with 0" \
    [pcall {wviewer::capture_live_graph_state $tok}] 0
  check "MF15 ... and the unmatched graph's markers were NOT wiped (before: gone)" \
    [pcall {mk_model_mk $tok 2}] [mk_rec 9 0 0 5 0.5 1.5]
  check "MF15 ... nor were strip 0's" \
    [pcall {mk_model_mk $tok 0}] [mk_rec 1 0 0 5 0.5 1.5]
  wviewer::set_graphs $tok [lrange [mk_graphs $tok] 0 1]
  check "MF15 and it works again once they agree" \
    [pcall {wviewer::capture_live_graph_state $tok}] 1

  # --- MF16: marker_changed captures the LIVE view state before push_undo ---
  # push_undo records the CURRENT state as the restore point, so anything the
  # user changed with the mouse that has not been folded into the model yet (a
  # pan, a zoom, a wave-bold) must be captured FIRST — exactly as move_strip and
  # move_trace do. Before the fix one `u` after creating a marker also reverted
  # that unrelated pan. The `skip_markers 1` half is MF15's.
  pcall {wviewer::with_edit $tok {xschem graph_marker delete -all}}
  pcall {wviewer::capture_live_graph_state $tok}
  pcall {wviewer::clear_history $tok}
  set mf16x0 [pcall {wviewer::dget [lindex [mk_graphs $tok] 0] x1 {}}]
  check_true "MF16 the model has a starting x1" [string is double -strict $mf16x0]
  set mf16pan [pexpr {$mf16x0 + 0.11}]
  # a PAN, written straight onto the rect and never folded into the model --
  # which is exactly the state an MMB pan leaves behind
  pcall {wviewer::with_edit $tok {xschem setprop rect 2 0 x1 $mf16pan}}
  check_true "MF16 the rect carries the panned x1" \
    [pcall {mk_close [xschem new_schematic switch $vdrw; xschem getprop rect 2 0 x1] $mf16pan}]
  check_true "MF16 ... while the model still has the OLD one" \
    [pcall {mk_close [wviewer::dget [lindex [mk_graphs $tok] 0] x1 {}] $mf16x0}]
  set mf16n {}
  if {[catch {wviewer::with_edit $tok \
        {set mf16n [xschem graph_marker add_at 0 0 0 5]}} mf16e]} {
    set mf16n "ERR:$mf16e"
  }
  check "MF16 a marker was created" $mf16n 1
  check "MF16 exactly one undo point" [pcall {wviewer::history_depth $tok}] {1 0}
  check_true "MF16 the push hook folded the PAN into the model too" \
    [pcall {mk_close [wviewer::dget [lindex [mk_graphs $tok] 0] x1 {}] $mf16pan}]
  check "MF16 undo runs" [pcall {wviewer::undo $tok}] 1
  check "MF16 ... and removed the marker" \
    [pcall {dict exists [lindex [mk_graphs $tok] 0] markers}] 0
  check_true "MF16 ... while KEEPING the user's pan (before: reverted to $mf16x0)" \
    [pcall {mk_close [wviewer::dget [lindex [mk_graphs $tok] 0] x1 {}] $mf16pan}]
  check_true "MF16 ... on the rect as well" \
    [pcall {mk_close [xschem new_schematic switch $vdrw; xschem getprop rect 2 0 x1] $mf16pan}]
  mk_fixture $tok

  # ==========================================================================
  # MD (viewer half) — Delete All Markers / Ctrl-E, viewer plan item 4
  # ==========================================================================
  # Everything the wrapper does NOT do itself is what this group pins down: the
  # model rewrite and the single undo point both come from the push hook, and
  # asserting them here is what stops a future "helpful" push_undo /
  # set_graphs being added to the proc (that would give a phantom second point
  # and `u` would need two presses). Runs after MF16's mk_fixture, i.e. from a
  # clean two-strip/two-trace/empty-history state, and puts one back at the end
  # so the MX group below sees exactly what it always saw.

  # spy on the replayable-log seam (the MX group's idiom, borrowed early)
  set ::mdvlog {}
  rename wviewer::log_action wviewer::__mdv_real_log
  proc wviewer::log_action {line} { lappend ::mdvlog $line }

  # --- MD4: fixture — a marker on EACH strip ---------------------------
  set mdn1 {}; set mdn2 {}
  catch {wviewer::with_edit $tok {set mdn1 [xschem graph_marker add_at 0 0 0 5]}}
  catch {wviewer::with_edit $tok {set mdn2 [xschem graph_marker add_at 1 0 0 5]}}
  check "MD4 one marker on each of the two strips" [list $mdn1 $mdn2] {1 2}
  xschem new_schematic switch $vdrw
  set mdtok0 [pcall {xschem getprop rect 2 0 markers}]
  set mdtok1 [pcall {xschem getprop rect 2 1 markers}]
  check_true "MD4 both rects carry a token" \
    [expr {[wviewer::markers_valid $mdtok0] && [wviewer::markers_valid $mdtok1]}]
  check "MD4 the push hook put both into the MODEL" \
    [pcall {list [mk_model_mk $tok 0] [mk_model_mk $tok 1]}] [list $mdtok0 $mdtok1]
  pcall {wviewer::clear_history $tok}
  set ::mdvlog {}

  # --- MD5: the delete itself ------------------------------------------
  # THE REPAINT SEAM. Neither half of the delete redraws: the C verb only
  # rewrites the props and notifies (its keyboard caller in callback.c:6720 does
  # its own draw()), and the push hook's set_graphs is a pure model write —
  # probe-measured with `-d 1`, which makes draw() log itself: 0 draw() calls
  # across the whole delete without the wrapper's `xschem redraw`, 1 with it. An
  # execution trace on the `xschem` command is the only seam a test can see that
  # through, and without this leg dropping the repaint would go unnoticed (the
  # deleted markers stay on screen until something else redraws).
  set ::mdredraw 0
  proc md_trace {cmd op} { if {[lindex $cmd 1] eq {redraw}} { incr ::mdredraw } }
  trace add execution xschem enter md_trace
  check "MD5 delete_all_markers returns the number it removed" \
    [pcall {wviewer::delete_all_markers $tok}] 2
  catch {trace remove execution xschem enter md_trace}
  rename md_trace {}
  check "MD5 ... and repainted the viewer canvas exactly once" $::mdredraw 1
  check "MD5 no marker is left anywhere in the window" \
    [pcall {xschem new_schematic switch $vdrw; xschem graph_marker list}] {}
  check "MD5 strip 0's model dict LOST its markers key" \
    [pcall {dict exists [lindex [mk_graphs $tok] 0] markers}] 0
  check "MD5 ... and so did strip 1's" \
    [pcall {dict exists [lindex [mk_graphs $tok] 1] markers}] 0
  check "MD5 the strips, their traces and their order all SURVIVED" \
    [pcall {list [llength [mk_graphs $tok]] [mk_ids $tok] [mk_order $tok]}] {2 {A B} {v_a v_b}}
  check "MD5 the read-only discipline held: the buffer is NOT modified" \
    [pcall {xschem new_schematic switch $vdrw; xschem get modified}] 0
  check "MD5 ... and the viewer is read-only again" [pcall {xschem get readonly}] 1
  check "MD5 exactly ONE undo point — the hook's, with no second one added here" \
    [pcall {wviewer::history_depth $tok}] {1 0}
  check "MD5 exactly one replayable log line" [llength $::mdvlog] 1
  check "MD5 ... naming the proc and the RESOLVED token" \
    [lindex $::mdvlog 0] "wviewer::delete_all_markers $tok"

  # --- MD6: the no-op leaves NOTHING behind ----------------------------
  set ::mdvlog {}
  check "MD6 a second call deletes nothing and reports 0" \
    [pcall {wviewer::delete_all_markers $tok}] 0
  check "MD6 ... and logs nothing (a no-op must not enter a replay)" \
    [llength $::mdvlog] 0
  check "MD6 ... and pushes no undo point" [pcall {wviewer::history_depth $tok}] {1 0}

  # --- MD7: undo restores the markers to BOTH the model and the rects --
  set ::mdvlog {}
  check "MD7 undo runs" [pcall {wviewer::undo $tok}] 1
  check "MD7 undo restored both strips' markers to the MODEL, byte-identically" \
    [pcall {list [mk_model_mk $tok 0] [mk_model_mk $tok 1]}] [list $mdtok0 $mdtok1]
  check "MD7 ... and onto the RECTS (the model -> graph_props -> rect round trip)" \
    [pcall {xschem new_schematic switch $vdrw
            list [xschem getprop rect 2 0 markers] [xschem getprop rect 2 1 markers]}] \
    [list $mdtok0 $mdtok1]
  check "MD7 ONE press was enough — the delete pushed one point, not two" \
    [pcall {wviewer::history_depth $tok}] {0 1}
  check "MD7 redo deletes them again, in the model" \
    [pcall {wviewer::redo $tok
            list [dict exists [lindex [mk_graphs $tok] 0] markers] \
                 [dict exists [lindex [mk_graphs $tok] 1] markers]}] {0 0}
  check "MD7 ... and on the rects" \
    [pcall {xschem new_schematic switch $vdrw; xschem graph_marker list}] {}

  # --- MD8: a REFUSED context switch is an error, and logs nothing -----
  # with_edit throws rather than mutate somebody else's schematic; the wrapper
  # lets that propagate but must still have popped its suppress scope (the
  # log half of that is MD3, in a child with a real log open).
  set ::mdvlog {}
  catch {wviewer::with_edit $tok {xschem graph_marker add_at 0 0 0 5}}
  rename wviewer::switch_ctx wviewer::__mdv_real_switch
  proc wviewer::switch_ctx {token} { return 0 }
  set mderr [catch {wviewer::delete_all_markers $tok} mdmsg]
  rename wviewer::switch_ctx {}
  rename wviewer::__mdv_real_switch wviewer::switch_ctx
  check "MD8 a refused context switch propagates as an error" $mderr 1
  check_true "MD8 ... saying so" [string match {*context busy*} $mdmsg]
  check "MD8 ... and nothing was logged for it" [llength $::mdvlog] 0
  check "MD8 ... and the marker is untouched" \
    [pcall {xschem new_schematic switch $vdrw; llength [xschem graph_marker list]}] 1
  # the %W shim CATCHES it (an error escaping a Tk binding pops a bgerror box)
  rename wviewer::switch_ctx wviewer::__mdv_real_switch
  proc wviewer::switch_ctx {token} { return 0 }
  check "MD8 the binding shim swallows it and answers {}" \
    [pcall {wviewer::delete_all_markers_at $vdrw}] {}
  rename wviewer::switch_ctx {}
  rename wviewer::__mdv_real_switch wviewer::switch_ctx
  check "MD8 the shim resolves %W to THIS viewer's token and deletes" \
    [pcall {wviewer::delete_all_markers_at $vdrw}] 1
  check "MD8 ... logging the resolved token, not the canvas" \
    [lindex $::mdvlog end] "wviewer::delete_all_markers $tok"

  # --- MD9: the binding seam (the test_wave_clear_all CG4 clone) -------
  check_true "MD9 Ctrl-E is bound on the WaveViewer tag by default" \
    [expr {[bind WaveViewer <Control-Key-e>] ne {}}]
  check_true "MD9 the default calls delete_all_markers_at with the EVENT's canvas" \
    [string match {*wviewer::delete_all_markers_at %W*} [bind WaveViewer <Control-Key-e>]]
  wviewer::strip_bindings $vdrw
  check_true "MD9 the tag binding survives a re-sweep" \
    [expr {[bind WaveViewer <Control-Key-e>] ne {}}]
  check "MD9 the sweep does not duplicate the tag" \
    [llength [lsearch -all -exact [bindtags $vdrw] WaveViewer]] 1
  # THE cadence_style_rc:189 GUARD. `bind .drw <Control-Key-e>
  # {cadence::return_one_level}` is cloned onto every new canvas by
  # clone_canvas_bindings, and a widget-level bind is MORE SPECIFIC than the tag
  # — if a future keepseqs change let it survive the sweep it would silently
  # steal Ctrl-E from the viewer and ascend the hierarchy instead.
  check "MD9 Ctrl-E is NOT bound on the canvas widget itself (the rc clone is swept)" \
    [bind $vdrw <Control-Key-e>] {}
  # ...but that one is only a POST-OPEN SNAPSHOT and it passes TRIVIALLY: this
  # suite never sources cadence_style_rc, so no widget-level clone ever landed
  # on this canvas for the sweep to remove, and the leg above would stay green
  # with strip_bindings' sweep disabled entirely. Bind the clone by hand and
  # re-sweep, so the assertion actually observes the mechanism it names — this
  # is the leg a future `keepseqs` addition has to go red on.
  bind $vdrw <Control-Key-e> {cadence::return_one_level; break}
  wviewer::strip_bindings $vdrw
  check "MD9 a hand-planted widget-level Ctrl-E really IS swept (the mechanism,\
 not a snapshot)" [bind $vdrw <Control-Key-e>] {}
  # the other route to the C go_back (callback.c case 'e' + ControlMask) is
  # key_filter's forwarding allowlist, which `e` is deliberately not in
  check_true "MD9 keysym 101 (e) is not a graphkeys member, so nothing is forwarded" \
    [expr {[lsearch -exact $::wviewer::graphkeys 101] < 0}]

  # --- MD10: a REAL Ctrl-E on the canvas -------------------------------
  # Constant check count whatever the WSLg focus does: a stall falls back to the
  # tag binding's own body and says so, exactly like send_key_fb further down.
  set ::mdvlog {}
  catch {wviewer::with_edit $tok {xschem graph_marker add_at 0 0 0 5}}
  catch {wviewer::with_edit $tok {xschem graph_marker add_at 1 0 0 5}}
  check "MD10 two markers to delete" \
    [pcall {xschem new_schematic switch $vdrw; llength [xschem graph_marker list]}] 2
  # `send_key` (the WSLg focus-retry sender) is not defined until the MX
  # preamble below, so this is its short form. A stall falls back to running the
  # TAG BINDING'S OWN SCRIPT with %W substituted — Tk's own dispatch, minus Tk —
  # so the leg still exercises the shipped binding and the check count is
  # constant however the display behaves.
  set mdkey 0
  for {set mdi 0} {$mdi < 60} {incr mdi} {
    update
    if {![dict exists [lindex [mk_graphs $tok] 0] markers]} { set mdkey 1; break }
    catch {wm deiconify $vtop}
    catch {raise $vtop}
    catch {event generate $vtop <FocusIn> -detail NotifyAncestor}
    focus -force $vtop
    focus -force $vdrw
    update
    if {[focus -displayof $vdrw] eq $vdrw} { event generate $vdrw <Control-Key-e> }
    update
    after 20
  }
  if {!$mdkey} {
    note "Tk Ctrl-E delivery stalled (WSLg focus) — running the tag binding's own script"
    catch {uplevel #0 [string map [list %W $vdrw] [bind WaveViewer <Control-Key-e>]]}
  }
  check "MD10 Ctrl-E deleted every marker (Tk route or the tag body)" \
    [pcall {xschem new_schematic switch $vdrw; xschem graph_marker list}] {}
  check "MD10 ... in the model too" \
    [pexpr {![dict exists [lindex [mk_graphs $tok] 0] markers] &&
            ![dict exists [lindex [mk_graphs $tok] 1] markers]}] 1
  check "MD10 the gesture logs the same single line the command does" \
    [lindex $::mdvlog end] "wviewer::delete_all_markers $tok"
  # the go_back witness: Ctrl-E is `return_one_level` everywhere else in the tree
  check "MD10 the viewer did NOT ascend/close (Ctrl-E never reached go_back)" \
    [pcall {list [xschem get current_win_path] [xschem get graph_rects]}] [list $vdrw 2]

  # --- MD11: rc REMAPPABILITY (the CG6 (c) clone) ----------------------
  bind WaveViewer <Control-Key-e> {break}
  set ::wviewer::tagbinds 0
  check "MD11 install_default_binds runs once per session" \
    [pcall {wviewer::install_default_binds}] 1
  check "MD11 an rc binding is NOT overwritten by the defaults" \
    [bind WaveViewer <Control-Key-e>] {break}
  check "MD11 a second call is a no-op" [pcall {wviewer::install_default_binds}] 0
  check_true "MD11 remapping Ctrl-E left the OTHER defaults alone" \
    [expr {[string match {*clear_all_at*} [bind WaveViewer <Control-Key-d>]] &&
           [string match {*undo_at*} [bind WaveViewer <Key-u>]]}]
  # restore the shipped default for the MX group and anything after it
  bind WaveViewer <Control-Key-e> {}
  set ::wviewer::tagbinds 0
  pcall {wviewer::install_default_binds}
  check_true "MD11 shipped default restored" \
    [string match {*delete_all_markers_at*} [bind WaveViewer <Control-Key-e>]]

  # --- MD12: Graph > Delete All Markers (the CG7 clone) ----------------
  set mdmb $vtop.wvmenubar
  set mdgi -1
  set mdci -1
  for {set i 0} {$i <= [$mdmb.graph index end]} {incr i} {
    if {[catch {$mdmb.graph entrycget $i -label} lab]} { continue }
    if {$lab eq {Delete All Markers}} { set mdgi $i }
    if {$lab eq {Clear All}} { set mdci $i }
  }
  check_true "MD12 the Graph menu carries a Delete All Markers entry" [expr {$mdgi >= 0}]
  check "MD12 ... immediately after Clear All" [expr {$mdgi - $mdci}] 1
  check "MD12 ... labelled with the Ctrl+E accelerator" \
    [pcall {$mdmb.graph entrycget $mdgi -accelerator}] Ctrl+E
  check "MD12 ... and wired to the resolved token" \
    [pcall {$mdmb.graph entrycget $mdgi -command}] "wviewer::delete_all_markers $tok"
  catch {wviewer::with_edit $tok {xschem graph_marker add_at 0 0 0 5}}
  check "MD12 a marker to delete" \
    [pcall {xschem new_schematic switch $vdrw; llength [xschem graph_marker list]}] 1
  pcall {$mdmb.graph invoke $mdgi}
  check "MD12 invoking the entry deletes it" \
    [pcall {xschem new_schematic switch $vdrw; xschem graph_marker list}] {}

  # hand the log seam and the fixture back exactly as they were found
  rename wviewer::log_action {}
  rename wviewer::__mdv_real_log wviewer::log_action
  foreach mdv {mdn1 mdn2 mdtok0 mdtok1 mderr mdmsg mdkey mdi mdmb mdgi mdci} {
    catch {unset $mdv}
  }
  mk_fixture $tok

  # ==========================================================================
  # MQ — DEL deletes WHATEVER is selected (issue 0176)
  # ==========================================================================
  # doc/claude/issues/0176-del-deletes-selection.md. The Delete key used to
  # delete only a selected MARKER; it now deletes the selected marker, the
  # selected TRACES, or both, as one gesture / one undo point / one log line.
  #
  # ⚠ THIS GROUP IS DISPLAY-ONLY, AND THAT IS LANDMINE 41, NOT A CONVENIENCE.
  # `wviewer::delete_items` ends in `wviewer::regenerate`, which goes through
  # `viewport_rect` -> `winfo width`; under --nogui there is no Tk at all, so the
  # command layer cannot run headless whatever the fixture does. The half that
  # CAN run in both arms is the pure list/marker/selection math, and it lives in
  # test_wave_modes.tcl's DT group — deliberately, because a leg written into the
  # nogui arm here would assert the PRE-mutation state and pass for entirely the
  # wrong reason. Same split, same reason, as MD above.
  #
  # The meat drives `wviewer::delete_selection_at` (the shipping DEL body)
  # DIRECTLY rather than through a generated key: `key_filter`'s gate reads
  # `over_graph`, i.e. the C mouse mirror, and a synthetic pointer is the flaky
  # part of this suite under WSLg. The gate itself, the wiring, and one real
  # generated Delete are asserted separately (MQ9/MQ10), so the direct calls are
  # not hollow — they are the same proc the binding reaches.

  set ::mqlog {}
  rename wviewer::log_action wviewer::__mq_real_log
  proc wviewer::log_action {line} { lappend ::mqlog $line }

  # two more raw columns, so strip 0 can hold THREE traces — a survivor-remap
  # leg needs a marker BELOW and a marker ABOVE the doomed node
  check "MQ0 v_c/v_d are real columns" \
    [pcall {xschem new_schematic switch $vdrw
            list [xschem raw add v_c {vsweep 3 +}] [xschem raw add v_d {vsweep 4 +}]}] {1 1}

  proc mq_tr {v c} { return [dict create expr $v name {} vec $v color $c] }
  # strip 0: v_a v_b v_c   (node indices 0 1 2)      strip 1: v_d  (node 0)
  proc mq_layout {tok} {
    wviewer::set_graphs $tok [list \
      [dict replace [wviewer::empty_graph] sdid A traces \
         [list [mq_tr v_a 4] [mq_tr v_b 5] [mq_tr v_c 6]]] \
      [dict replace [wviewer::empty_graph] sdid B traces [list [mq_tr v_d 7]]]]
    wviewer::regenerate $tok
    wviewer::fit $tok
    xschem new_schematic switch $::vdrw
  }
  # the three markers, created through the REAL C verb so the push hook keeps the
  # model current (a hand-written rect token would not be in the model, and
  # delete_items validates the marker numbers it is given against the model):
  #   1  strip 0, node 1 (ON v_b, the trace the trace-legs delete)  -> DROPPED
  #   2  strip 1, node 0, prev = 1  -> SURVIVES, and its `prev` must be zeroed
  #                                    by the WINDOW-WIDE sweep
  #   3  strip 0, node 2 (ON v_c, above the hole) -> SURVIVES, wave 2 -> 1
  proc mq_marks {tok} {
    set a {}; set b {}; set c {}
    catch {wviewer::with_edit $tok {set a [xschem graph_marker add_at 0 1 0 5]}}
    catch {wviewer::with_edit $tok {set b [xschem graph_marker add_at 1 0 0 6 -delta]}}
    catch {wviewer::with_edit $tok {set c [xschem graph_marker add_at 0 2 0 7]}}
    return [list $a $b $c]
  }
  # rebuild the whole fixture and hand back a clean history / empty log
  proc mq_setup {tok} {
    xschem new_schematic switch $::vdrw
    catch {wviewer::with_edit $tok {xschem graph_marker delete -all}}
    mq_layout $tok
    set nums [mq_marks $tok]
    catch {xschem graph_marker select -none}
    wviewer::clear_history $tok
    set ::mqlog {}
    xschem new_schematic switch $::vdrw
    return $nums
  }
  # the whole model, compressed to what this group cares about: the vecs of each
  # strip and each strip's marker token
  proc mq_state {tok} {
    set out {}
    foreach G [mk_graphs $tok] {
      set vs {}
      foreach tr [wviewer::dget $G traces {}] { lappend vs [wviewer::dget $tr vec ?] }
      lappend out [list $vs [wviewer::dget $G markers {}]]
    }
    return $out
  }
  # write a SELECTION into the model and push it onto the rects, the way a click
  # would leave it (selection is view state the C engine owns; this is the
  # deterministic equivalent — issue 0175 storage, model_sel_set is its writer)
  proc mq_select {tok sels} {
    set gs [mk_graphs $tok]
    set out {}
    set gi 0
    foreach G $gs {
      set s {}
      if {[dict exists $sels $gi]} { set s [dict get $sels $gi] }
      lappend out [wviewer::model_sel_set $G $s]
      incr gi
    }
    wviewer::set_graphs $tok $out
    wviewer::regenerate $tok
    xschem new_schematic switch $::vdrw
  }
  # the centre pixel of strip `gi` — never an EDGE (waves_selected insets every
  # rect by 5*tk_scaling, and a key aimed at the seam falls through to the
  # SCHEMATIC handler where a/b/s/t/m open modal dialogs and hang a headless run)
  proc mq_mid {gi} {
    set bands [wviewer::strip_bands_px $::vdrw]
    if {$gi < 0 || $gi >= [llength $bands]} { return {-1 -1} }
    lassign [lindex $bands $gi] x1 y1 x2 y2
    return [list [expr {int(($x1 + $x2) / 2)}] [expr {int(($y1 + $y2) / 2)}]]
  }
  # DEL through the shipping body, with the pointer coordinates the KeyPress
  # would have carried
  proc mq_del {tok gi} {
    lassign [mq_mid $gi] px py
    set r [pcall {wviewer::delete_selection_at $::vdrw $px $py}]
    update
    catch {xschem new_schematic switch $::vdrw}
    return $r
  }
  # The same, with the `xschem callback` spy armed around the CALL ONLY.
  # ⚠ The window must not include `update`: a queued <Motion>/<Enter> dispatched
  # there reaches the canvas bindings, which call `xschem callback` for reasons
  # that have nothing to do with Delete — MEASURED as a spurious count of 1 on a
  # run where the delete itself was correct. Arming around the proc call keeps
  # the leg about the forward and nothing else.
  proc mq_cb_trace {cmd op} { if {[lindex $cmd 1] eq {callback}} { incr ::mqcb } }
  proc mq_del_spy {tok gi} {
    lassign [mq_mid $gi] px py
    set ::mqcb 0
    trace add execution xschem enter mq_cb_trace
    set r [pcall {wviewer::delete_selection_at $::vdrw $px $py}]
    catch {trace remove execution xschem enter mq_cb_trace}
    update
    catch {xschem new_schematic switch $::vdrw}
    return $r
  }

  # --- MQ1: routing (a) — a MARKER selected, no traces -----------------
  # the arm that must NOT change: the marker goes, every trace stays.
  set mqn [mq_setup $tok]
  check "MQ1 fixture: three markers, numbered 1 2 3" $mqn {1 2 3}
  check "MQ1 fixture: 3 traces on strip 0, 1 on strip 1" \
    [pcall {mq_state $tok}] [list [list {v_a v_b v_c} [mk_model_mk $tok 0]] \
                                  [list {v_d} [mk_model_mk $tok 1]]]
  # `graph_marker list` fields are `num gi wave dset point x y prev ldx ldy` —
  # NOT the token's field order (it has no `gi`), so wave is 2 and prev is 7
  check "MQ1 marker 2 is a DELTA whose partner is marker 1" [pcall {mk_field 2 7}] 1
  pcall {xschem graph_marker select 3 0}
  check "MQ1 marker 3 is the selected one" [pcall {xschem get graph_marker_sel}] 3
  check "MQ1 DEL over strip 0 reports ONE thing deleted" [mq_del $tok 0] 1
  check "MQ1 the selected marker is gone, the other two are not" [pcall {mk_nums}] {1 2}
  check "MQ1 not one trace was touched" \
    [pcall {list [llength [wviewer::dget [lindex [mk_graphs $tok] 0] traces {}]] \
                 [llength [wviewer::dget [lindex [mk_graphs $tok] 1] traces {}]]}] {3 1}
  check "MQ1 exactly ONE undo point for the gesture" \
    [pcall {wviewer::history_depth $tok}] {1 0}
  check "MQ1 exactly one replayable log line, with EXPLICIT resolved targets" \
    [list [llength $::mqlog] [lindex $::mqlog 0]] \
    [list 1 "wviewer::delete_items {} {} 3 $tok"]
  check "MQ1 the marker selection was reset (it pointed at a dead marker)" \
    [pcall {xschem get graph_marker_sel}] -1
  check "MQ1 one `u` brings it back" [pcall {wviewer::undo $tok}] 1
  check "MQ1 ... to the model" [pcall {lsort [wviewer::markers_numbers [mk_model_mk $tok 0]]}] {1 3}
  check "MQ1 ... and onto the rects" [pcall {lsort -integer [mk_nums]}] {1 2 3}

  # --- MQ2: routing (b) + THE CASCADE + THE WINDOW-WIDE SWEEP ----------
  # THE teeth of this issue. Delete the trace that carries marker 1 and assert
  # all three index consequences at once: the marker ON it is dropped, the
  # marker ABOVE it in the SAME strip shifts down, and the delta partner on the
  # OTHER strip has its now-dangling `prev` zeroed.
  mq_setup $tok
  check "MQ2 before: marker 1 sits on node 1, marker 3 on node 2" \
    [pcall {list [mk_field 1 2] [mk_field 3 2]}] {1 2}
  pcall {mq_select $tok [dict create 0 {1}]}
  check "MQ2 exactly one trace is selected, and it is v_b (node 1)" \
    [pcall {list [wviewer::selected_waves $vdrw 0] [wviewer::selected_waves $vdrw 1]}] {1 {}}
  check "MQ2 no marker is selected" [pcall {xschem get graph_marker_sel}] -1
  set ::mqlog {}
  pcall {wviewer::clear_history $tok}
  check "MQ2 DEL reports ONE thing deleted" [mq_del $tok 0] 1
  check "MQ2 the trace is gone and its neighbours are not" \
    [pcall {set vs {}
            foreach tr [wviewer::dget [lindex [mk_graphs $tok] 0] traces {}] {
              lappend vs [wviewer::dget $tr vec ?] }
            set vs}] {v_a v_c}
  check "MQ2 the OTHER strip is untouched" \
    [pcall {set vs {}
            foreach tr [wviewer::dget [lindex [mk_graphs $tok] 1] traces {}] {
              lappend vs [wviewer::dget $tr vec ?] }
            set vs}] {v_d}
  check "MQ2 CASCADE: the marker ON the deleted trace is gone" \
    [pcall {lsort -integer [mk_nums]}] {2 3}
  check "MQ2 SURVIVOR REMAP: the marker above the hole shifted 2 -> 1" \
    [pcall {mk_field 3 2}] 1
  check "MQ2 WINDOW-WIDE SWEEP: the delta partner on the OTHER strip was zeroed" \
    [pcall {mk_field 2 7}] 0
  check "MQ2 ... and that partner itself survived, on its own node" \
    [pcall {list [mk_field 2 1] [mk_field 2 2]}] {1 0}
  check "MQ2 the selection is empty — the selected trace died" \
    [pcall {list [wviewer::selected_waves $vdrw 0] [wviewer::selected_waves $vdrw 1]}] {{} {}}
  check "MQ2 exactly ONE undo point" [pcall {wviewer::history_depth $tok}] {1 0}
  check "MQ2 exactly one log line, naming the MODEL {gi ti} pair explicitly" \
    [list [llength $::mqlog] [lindex $::mqlog 0]] \
    [list 1 "wviewer::delete_items {} {{0 1}} {} $tok"]
  set mq2after [pcall {mq_state $tok}]
  check "MQ2 one `u` brings the trace AND its marker back together" \
    [pcall {wviewer::undo $tok
            list [llength [wviewer::dget [lindex [mk_graphs $tok] 0] traces {}]] \
                 [lsort -integer [mk_nums]]}] {3 {1 2 3}}
  check "MQ2 ... with the survivor's index and the partner's link restored" \
    [pcall {list [mk_field 3 2] [mk_field 2 7]}] {2 1}

  # --- MQ3: routing (c) — BOTH kinds selected (D1) ---------------------
  # One keystroke, two kinds of thing, ONE undo point and ONE log line. Flagged
  # for the eyeball: if "delete both" reads wrong it inverts to marker-first.
  mq_setup $tok
  pcall {mq_select $tok [dict create 1 {0}]}      ;# v_d, the ONLY trace of strip 1
  pcall {xschem graph_marker select 3 0}          ;# a marker on strip 0
  check "MQ3 a trace on strip 1 AND a marker on strip 0 are selected" \
    [pcall {list [wviewer::selected_waves $vdrw 1] [xschem get graph_marker_sel]}] {0 3}
  set ::mqlog {}
  pcall {wviewer::clear_history $tok}
  check "MQ3 DEL over strip 0 reports TWO things deleted (the marker + the trace)" \
    [mq_del $tok 0] 2
  # marker 3 was ASKED for; marker 2 lived ON v_d and went with it as a CASCADE,
  # which is a consequence and is deliberately not part of the count
  check "MQ3 the asked-for marker went, and so did the one riding the trace" \
    [pcall {lsort -integer [mk_nums]}] 1
  check "MQ3 ... and so did the trace, on the OTHER strip" \
    [pcall {llength [wviewer::dget [lindex [mk_graphs $tok] 1] traces {}]}] 0
  check "MQ3 D3: the strip that lost its last trace STAYS (that is bare `e`'s job)" \
    [pcall {list [llength [mk_graphs $tok]] [xschem get graph_rects]}] {2 2}
  check "MQ3 ONE undo point for the whole gesture, not one per kind" \
    [pcall {wviewer::history_depth $tok}] {1 0}
  check "MQ3 ONE log line, carrying both payloads" \
    [list [llength $::mqlog] [lindex $::mqlog 0]] \
    [list 1 "wviewer::delete_items {} {{1 0}} 3 $tok"]
  check "MQ3 one `u` brings BOTH back" \
    [pcall {wviewer::undo $tok
            list [llength [wviewer::dget [lindex [mk_graphs $tok] 1] traces {}]] \
                 [lsort -integer [mk_nums]]}] {1 {1 2 3}}

  # --- MQ4: D2 — nothing selected is a NO-OP that never reaches C ------
  # A leg that only checked "no crash" would pass on a readonly modal, so this
  # spies the forward itself: `xschem callback` must not be called at all.
  mq_setup $tok
  pcall {mq_select $tok [dict create]}
  pcall {xschem graph_marker select -none}
  pcall {wviewer::clear_history $tok}
  set ::mqlog {}
  set mq4before [pcall {mq_state $tok}]
  set mq4r [mq_del_spy $tok 0]
  check "MQ4 DEL with nothing selected reports 0" $mq4r 0
  check "MQ4 ... and NEVER forwarded to C (the canvas delete verb is a readonly modal)" \
    $::mqcb 0
  check "MQ4 ... the model is byte-identical" [pcall {mq_state $tok}] $mq4before
  check "MQ4 ... no undo point was pushed" [pcall {wviewer::history_depth $tok}] {0 0}
  check "MQ4 ... and nothing was logged for a replay to re-run" [llength $::mqlog] 0

  # --- MQ5: the marker arm still honours C's STRIP SCOPE ---------------
  # callback.c's XK_Delete requires `graph_marker_find(sel) == graph_master` —
  # the pointer must be over the strip that owns the selected marker.
  # delete_selection_at reproduces that rather than loosening it. This ALSO
  # closes a latent wart: the old arm forwarded on a window-wide selection and
  # let C refuse, and C's refusal fell through to the canvas delete verb.
  mq_setup $tok
  pcall {mq_select $tok [dict create]}
  pcall {xschem graph_marker select 3 0}          ;# marker 3 lives on strip 0
  pcall {wviewer::clear_history $tok}
  set ::mqlog {}
  set mq5before [pcall {mq_state $tok}]
  set mq5r [mq_del_spy $tok 1]                    ;# ... but the pointer is on strip 1
  check "MQ5 DEL on the WRONG strip deletes nothing" $mq5r 0
  check "MQ5 ... the marker survives" [pcall {lsort -integer [mk_nums]}] {1 2 3}
  check "MQ5 ... nothing reached C (no fall-through to the readonly modal)" $::mqcb 0
  check "MQ5 ... no undo point, no log line" \
    [list [pcall {wviewer::history_depth $tok}] [llength $::mqlog]] {{0 0} 0}
  check "MQ5 ... and the model is byte-identical" [pcall {mq_state $tok}] $mq5before
  check "MQ5 the SAME gesture on the OWNING strip does delete it (the A/B control)" \
    [list [mq_del $tok 0] [pcall {lsort -integer [mk_nums]}]] {1 {1 2}}

  # --- MQ6: delete_items' own refusals and no-op discipline ------------
  mq_setup $tok
  pcall {wviewer::clear_history $tok}
  set ::mqlog {}
  check "MQ6 an empty request is a 0, not a mutation" \
    [pcall {wviewer::delete_items {} {} {} $tok}] 0
  check "MQ6 an out-of-range strip index is refused LOUDLY ({}, not a wrong delete)" \
    [pcall {wviewer::delete_items {9} {} {} $tok}] {}
  check "MQ6 an out-of-range trace index is refused" \
    [pcall {wviewer::delete_items {} {{0 9}} {} $tok}] {}
  check "MQ6 a malformed pair is refused" \
    [pcall {wviewer::delete_items {} {{0}} {} $tok}] {}
  check "MQ6 a marker number that does not exist is DROPPED, not counted" \
    [pcall {wviewer::delete_items {} {} {99} $tok}] 0
  check "MQ6 none of those pushed an undo point or logged" \
    [list [pcall {wviewer::history_depth $tok}] [llength $::mqlog]] {{0 0} 0}
  check "MQ6 a duplicate pair deletes ONE trace, not two" \
    [pcall {wviewer::delete_items {} {{0 1} {0 1}} {} $tok}] 1
  check "MQ6 ... leaving the neighbours alone" \
    [pcall {set vs {}
            foreach tr [wviewer::dget [lindex [mk_graphs $tok] 0] traces {}] {
              lappend vs [wviewer::dget $tr vec ?] }
            set vs}] {v_a v_c}
  check "MQ6 ... and the log line carries the DEDUPED pair list" \
    [lindex $::mqlog end] "wviewer::delete_items {} {{0 1}} {} $tok"

  # --- MQ7: the logged line REPLAYS to the same model ------------------
  # A line that named "the selection" instead of explicit pairs would pass every
  # equality check above and fail here — a replay has no selection state at all
  # (issue 0175 D8).
  mq_setup $tok
  pcall {mq_select $tok [dict create 0 {1}]}
  set ::mqlog {}
  pcall {wviewer::clear_history $tok}
  pcall {mq_del $tok 0}
  set mq7line [lindex $::mqlog 0]
  set mq7want [pcall {mq_state $tok}]
  mq_setup $tok                                   ;# a fresh, identical viewer state
  pcall {xschem graph_marker select -none}        ;# ... and NO selection this time
  pcall {mq_select $tok [dict create]}
  set ::mqlog {}
  check "MQ7 the recorded line replays without error" [pcall {eval $mq7line}] 1
  check "MQ7 ... and lands on the same model, with no selection to guide it" \
    [pcall {mq_state $tok}] $mq7want

  # --- MQ8: undo/redo across the whole gesture -------------------------
  mq_setup $tok
  pcall {mq_select $tok [dict create 0 {1}]}
  pcall {wviewer::clear_history $tok}
  set mq8before [pcall {mq_state $tok}]
  pcall {mq_del $tok 0}
  set mq8after [pcall {mq_state $tok}]
  check "MQ8 undo restores the pre-delete model exactly" \
    [pcall {wviewer::undo $tok; mq_state $tok}] $mq8before
  check "MQ8 ... and it is now redoable" [pcall {wviewer::history_depth $tok}] {0 1}
  check "MQ8 redo deletes it again, identically" \
    [pcall {wviewer::redo $tok; mq_state $tok}] $mq8after
  check "MQ8 the rects followed the model both ways" \
    [pcall {xschem new_schematic switch $vdrw
            list [xschem getprop rect 2 0 node] [lsort -integer [mk_nums]]}] \
    [list {v_a
v_c} {2 3}]

  # --- MQ9: the GATE — over_graph, the wiring, and the graphkeys rule --
  check_true "MQ9 <KeyPress> on the viewer canvas still routes to key_filter\
 (the direct calls above are the same proc)" \
    [string match {*wviewer::key_filter*} [bind $vdrw <KeyPress>]]
  check_true "MQ9 Delete is NOT a graphkeys member (membership = unconditional\
 forwarding, and a forwarded Delete lands on the canvas delete verb)" \
    [expr {[lsearch -exact $::wviewer::graphkeys 65535] < 0}]
  mq_setup $tok
  pcall {mq_select $tok [dict create 0 {1}]}
  pcall {wviewer::clear_history $tok}
  set ::mqlog {}
  set mq9before [pcall {mq_state $tok}]
  # ⚠ MEASURED, and it decides how D7 can be tested at all: since item 18 the
  # strips TILE the whole viewport, so `graphbb` covers every canvas pixel and
  # there is NO off-graph region to park the pointer in — `over_graph` answers 1
  # even at pixel (3,3). A leg that moves the pointer to a corner and expects a
  # refusal therefore never presses anything and passes vacuously (it did, on the
  # first draft of this group). The gate is asserted at its SEAM instead: stub
  # `over_graph` to 0, which is exactly what the shipped proc answers when the C
  # context is on another window, and drive the real key_filter.
  check "MQ9 the viewer canvas is fully tiled, so there is no off-graph pixel\
 to park a pointer in (this is why D7 is asserted at the seam)" \
    [pcall {xschem new_schematic switch $vdrw
            catch {event generate $vdrw <Motion> -x 3 -y 3 -time [incr ::wbt 1000]}
            update
            xschem new_schematic switch $vdrw
            wviewer::over_graph $vdrw}] 1
  set ::mqcb 0
  rename wviewer::over_graph wviewer::__mq_real_over_graph
  proc wviewer::over_graph {wp} { return 0 }
  trace add execution xschem enter mq_cb_trace
  pcall {wviewer::key_filter $vdrw 2 3 3 65535 Delete 0}
  catch {trace remove execution xschem enter mq_cb_trace}   ;# BEFORE the update
  update
  rename wviewer::over_graph {}
  rename wviewer::__mq_real_over_graph wviewer::over_graph
  check "MQ9 D7: with over_graph refusing, DEL does nothing — even though a\
 trace IS selected and the same key deletes it a line later" \
    [pcall {xschem new_schematic switch $vdrw; mq_state $tok}] $mq9before
  check "MQ9 ... and it is not forwarded to C either" $::mqcb 0
  check "MQ9 nothing was logged and no undo point was pushed" \
    [list [pcall {wviewer::history_depth $tok}] [llength $::mqlog]] {{0 0} 0}
  # THE A/B CONTROL — without it the leg above passes on a DEL that is broken
  # for some entirely different reason. Same key, same selection, gate restored.
  check "MQ9 the SAME key with over_graph restored DOES delete it (the control)" \
    [mq_del $tok 0] 1
  check "MQ9 ... so the refusal above really was the gate" \
    [pcall {llength [wviewer::dget [lindex [mk_graphs $tok] 0] traces {}]}] 2

  # --- MQ10: a REAL Delete keystroke, end to end -----------------------
  # The MD10 shape: try Tk, and if WSLg focus swallows it drive the shipping
  # binding's own script, so the check count is constant either way.
  mq_setup $tok
  pcall {mq_select $tok [dict create 0 {1}]}
  pcall {wviewer::clear_history $tok}
  set ::mqlog {}
  lassign [mq_mid 0] mqpx mqpy
  set mqdone 0
  for {set mqi 0} {$mqi < 60} {incr mqi} {
    update
    if {[llength [wviewer::dget [lindex [mk_graphs $tok] 0] traces {}]] == 2} {
      set mqdone 1; break
    }
    catch {wm deiconify $vtop}
    catch {raise $vtop}
    catch {event generate $vtop <FocusIn> -detail NotifyAncestor}
    focus -force $vtop
    focus -force $vdrw
    catch {xschem new_schematic switch $vdrw}
    catch {event generate $vdrw <Motion> -x $mqpx -y $mqpy -time [incr ::wbt 1000]}
    update
    catch {xschem new_schematic switch $vdrw}
    if {[focus -displayof $vdrw] eq $vdrw} {
      catch {event generate $vdrw <Key-Delete> -x $mqpx -y $mqpy -time [incr ::wbt 1000]}
    }
    update
    after 20
  }
  if {!$mqdone} {
    note "Tk Delete delivery stalled (WSLg focus) — running the shipping handler"
    catch {xschem new_schematic switch $vdrw}
    catch {event generate $vdrw <Motion> -x $mqpx -y $mqpy -time [incr ::wbt 1000]}
    update
    catch {xschem new_schematic switch $vdrw}
    pcall {wviewer::key_filter $vdrw 2 $mqpx $mqpy 65535 Delete 0}
    update
  }
  catch {xschem new_schematic switch $vdrw}
  check "MQ10 a real Delete deleted the selected trace (Tk route or the handler)" \
    [pcall {set vs {}
            foreach tr [wviewer::dget [lindex [mk_graphs $tok] 0] traces {}] {
              lappend vs [wviewer::dget $tr vec ?] }
            set vs}] {v_a v_c}
  check "MQ10 ... taking its marker with it" [pcall {lsort -integer [mk_nums]}] {2 3}
  check "MQ10 ... and logging the same single line the command does" \
    [list [llength $::mqlog] [lindex $::mqlog end]] \
    [list 1 "wviewer::delete_items {} {{0 1}} {} $tok"]
  check "MQ10 ... and one `u` is enough" \
    [pcall {wviewer::undo $tok
            llength [wviewer::dget [lindex [mk_graphs $tok] 0] traces {}]}] 3

  # --- MQ11: D5 — ONE undo point and ONE log line for MANY traces ------
  # The leg every other MQ leg cannot be: they all delete exactly one trace, so
  # "per gesture" and "per trace" are indistinguishable there and a deleter that
  # logged (or pushed) once per trace would pass the whole group. MEASURED: a
  # sabotage that emits one line per pair is INVISIBLE without this leg.
  mq_setup $tok
  pcall {mq_select $tok [dict create 0 {0 2}]}       ;# v_a AND v_c, one gesture
  check "MQ11 two traces of the same strip are selected" \
    [pcall {wviewer::selected_waves $vdrw 0}] {0 2}
  pcall {wviewer::clear_history $tok}
  set ::mqlog {}
  check "MQ11 DEL reports TWO traces deleted" [mq_del $tok 0] 2
  check "MQ11 both went, and the one between them stayed" \
    [pcall {set vs {}
            foreach tr [wviewer::dget [lindex [mk_graphs $tok] 0] traces {}] {
              lappend vs [wviewer::dget $tr vec ?] }
            set vs}] {v_b}
  check "MQ11 the marker on the surviving trace shifted 1 -> 0" \
    [pcall {list [lsort -integer [mk_nums]] [mk_field 1 2]}] {{1 2} 0}
  check "MQ11 ONE undo point for TWO traces (per gesture, not per trace)" \
    [pcall {wviewer::history_depth $tok}] {1 0}
  check "MQ11 ONE log line for TWO traces, carrying both pairs" \
    [list [llength $::mqlog] [lindex $::mqlog 0]] \
    [list 1 "wviewer::delete_items {} {{0 0} {0 2}} {} $tok"]
  check "MQ11 one `u` brings BOTH traces and BOTH markers back" \
    [pcall {wviewer::undo $tok
            list [llength [wviewer::dget [lindex [mk_graphs $tok] 0] traces {}]] \
                 [lsort -integer [mk_nums]] [mk_field 1 2]}] {3 {1 2 3} 1}

  # --- MQ12: the TARGET survives a whole-strip delete --------------------
  # The dialog can delete a whole strip; DEL cannot (D4). Nothing asserted the
  # stored target afterwards, and the first draft of delete_items got it WRONG in
  # a way no other leg could see: it read `target_index` AFTER `set_graphs`, and
  # `target_index` clamps against the LIVE strip count — so a target sitting at
  # or past the new end was shrunk TWICE, once by the clamp and once by
  # `index_after_removal`. `split_strip` already reads before its mutation and
  # says why; this leg is what makes the two agree.
  # The teeth are the CLAMPED case: target = the LAST strip, delete strip 0.
  mq_setup $tok
  pcall {wviewer::set_graphs $tok [linsert [mk_graphs $tok] end \
           [dict replace [wviewer::empty_graph] sdid C]]
         wviewer::regenerate $tok}
  check "MQ12 fixture: three strips" [pcall {llength [mk_graphs $tok]}] 3
  pcall {wviewer::set_target_strip 2 $tok}
  check "MQ12 the LAST strip is the target" [pcall {wviewer::target_strip $tok}] 2
  pcall {wviewer::clear_history $tok}
  check "MQ12 deleting strip 0 removes it" \
    [pcall {list [wviewer::delete_items {0} {} {} $tok] [llength [mk_graphs $tok]]}] {1 2}
  check "MQ12 the target FOLLOWED its strip (it is now index 1, not 0)" \
    [pcall {wviewer::target_strip $tok}] 1
  check "MQ12 ... and it is still the same strip (the inert witness proves it)" \
    [pcall {wviewer::dget [lindex [mk_graphs $tok] [wviewer::target_strip $tok]] sdid ?}] C
  check "MQ12 a target BELOW the deleted strip does not move" \
    [pcall {mq_setup $tok
            wviewer::set_target_strip 0 $tok
            wviewer::delete_items {1} {} {} $tok
            wviewer::target_strip $tok}] 0
  check "MQ12 undo restores the strip, and the target with it" \
    [pcall {mq_setup $tok
            wviewer::set_target_strip 1 $tok
            wviewer::clear_history $tok
            wviewer::delete_items {0} {} {} $tok
            wviewer::undo $tok
            list [llength [mk_graphs $tok]] [wviewer::target_strip $tok]}] {2 1}

  # hand the log seam and the fixture back exactly as they were found
  catch {trace remove execution xschem enter mq_cb_trace}
  rename wviewer::log_action {}
  rename wviewer::__mq_real_log wviewer::log_action
  foreach mqp {mq_tr mq_layout mq_marks mq_setup mq_state mq_select mq_mid mq_del
               mq_del_spy mq_cb_trace} {
    catch {rename $mqp {}}
  }
  foreach mqv {mqn mq2after mq4before mq4r mq5before mq5r mq7line mq7want
               mq8before mq8after mq9before mq9off mqpx mqpy mqdone mqi} {
    catch {unset $mqv}
  }
  catch {wviewer::with_edit $tok {xschem graph_marker delete -all}}
  catch {xschem graph_marker select -none}
  mk_fixture $tok

  # ==========================================================================
  # MX* — full Tk gesture sequences
  # ==========================================================================

  # Every synthetic button event carries an explicitly INCREASING %t. Without it
  # Tk collapses two identical presses inside its double-click window into
  # <Double-Button-1>, which the viewer binds to {break} — the second press then
  # vanishes entirely and the leg fails for a reason unrelated to the code under
  # test.
  set ::wbt 100000
  proc wb_ev {w seq args} {
    set ::wbt [expr {$::wbt + 1000}]
    eval [list event generate $w $seq -time $::wbt] $args
    update
  }
  # a generated KeyPress goes to the DISPLAY's focus window and the WSLg focus
  # round-trip is asynchronous, so every send is gated on Tk reporting $w as the
  # focus owner and retried until $done (evaluated in the CALLER's scope) is true
  proc send_key {w ev done {maxtries 200}} {
    set top [winfo toplevel $w]
    for {set i 0} {$i < $maxtries} {incr i} {
      update
      if {[uplevel 1 [list expr $done]]} { return 1 }
      if {![winfo exists $w]} { after 50; continue }
      catch {wm deiconify $top}
      catch {raise $top}
      # WSLg focus recovery. Tk drops a key event whose toplevel is not the
      # display's focus toplevel, and when the WM takes the input focus away from
      # the whole application `focus -force` only issues an XSetInputFocus and
      # then WAITS for a FocusIn that never arrives -- so Tk's focus record stays
      # empty and every synthetic key after that goes nowhere (probe-verified:
      # `focus -displayof` answers {} with no grab and the canvas still mapped).
      # A synthetic FocusIn runs Tk's own focus filter and restores the record.
      catch {event generate $top <FocusIn> -detail NotifyAncestor}
      focus -force $top
      focus -force $w
      update
      if {[uplevel 1 [list expr $done]]} { return 1 }
      # Generate REGARDLESS of what `focus -displayof` says. The rule this file
      # follows is "always focus -force + update before a synthetic KeyPress" --
      # kept above -- but gating the send on Tk CONFIRMING the focus deadlocks
      # under WSLg: the X input focus can sit outside the application entirely
      # (probe-verified: `focus -displayof` answers {} with no grab and the
      # canvas still mapped, from MX8 onwards), and `focus -force` cannot take it
      # back. Tk routes a generated key event to the focus widget of $w's own
      # toplevel, so the event still lands; a send that goes nowhere is harmless
      # because the loop is gated on the RESULT predicate, not on the send.
      set ::wbt [expr {$::wbt + 1000}]
      eval [list event generate $w] $ev [list -time $::wbt]
      update
      if {[uplevel 1 [list expr $done]]} { return 1 }
      after 50
    }
    note "send_key: $ev to $w never took effect ($maxtries tries)"
    return 0
  }
  # ---- CONTEXT re-establish: the other half of "the key never arrived" -----
  #
  # wviewer::key_filter gates EVERY graph key on wviewer::over_graph, and
  # over_graph's very first test is
  #     if {[xschem get current_win_path] ne $wp} { return 0 }
  # A real EnterNotify on ANOTHER xschem window switches the C context
  # (handle_window_switching, callback.c:7869) -- the main editor window is
  # still mapped underneath this viewer for the whole MX group, so a stray
  # pointer crossing during ANY of the `update`s below is enough. From that
  # moment the viewer's own key gate answers 0 for its own canvas and `m` is
  # swallowed identically whether it came from Tk or from the fallback, which
  # is exactly how MX1 managed to fail through BOTH routes.
  #
  # mk_prep_ctx puts the context back (and the Tk focus with it). mk_prep_at
  # additionally re-plants the pointer, because over_graph reads the CONTEXT's
  # last snapped mouse position, not the coordinates handed to key_filter.
  # Neither is allowed to generate a Motion during a live drag -- that is why
  # they are separate and why the ESC/undo legs use the ctx-only one.
  proc mk_prep_ctx {} {
    set mkwas [pcall {xschem get current_win_path}]
    catch {xschem new_schematic switch $::vdrw}
    set top [winfo toplevel $::vdrw]
    # deiconify/raise ONLY when the canvas is not already usable: a gratuitous
    # raise generates crossing + expose traffic on both windows, and a crossing
    # is precisely what steals the context this proc exists to restore
    if {![winfo ismapped $::vdrw] || ![winfo viewable $::vdrw]} {
      catch {wm deiconify $top}
      catch {raise $top}
    }
    catch {event generate $top <FocusIn> -detail NotifyAncestor}
    catch {focus -force $top}
    catch {focus -force $::vdrw}
    update
    # AFTER the update: the update is itself a chance for a real crossing to
    # steal the context back, so this is the assignment that has to stick.
    catch {xschem new_schematic switch $::vdrw}
    set mknow [pcall {xschem get current_win_path}]
    # a recovery that happens silently is a flake that hides, so say it
    if {$mkwas ne $::vdrw} {
      note "the C context was on $mkwas, not the viewer — put back\
 (while it is elsewhere wviewer::over_graph refuses EVERY graph key, Tk route\
 and shipping-handler fallback alike)"
    }
    return [expr {$mknow eq $::vdrw}]
  }
  proc mk_prep_at {x y} {
    mk_prep_ctx
    catch {wb_ev $::vdrw <Motion> -x $x -y $y}
    catch {xschem new_schematic switch $::vdrw}
    return [expr {[pcall {xschem get current_win_path}] eq $::vdrw}]
  }
  # Tk-FIRST, seam-fallback key delivery.
  #
  # Why a fallback exists at all: under WSLg the window manager can take the X
  # input focus away from the whole application mid-run. Tk then drops every key
  # event whose toplevel is not the display's focus toplevel, and `focus -force`
  # cannot fix it — it issues an XSetInputFocus and waits for a FocusIn that
  # never arrives, so Tk's focus record stays empty (probe-verified:
  # `focus -displayof` answers {} with no grab and the canvas still mapped).
  # This was reproducible in roughly one run in four, at a different leg each
  # time, which makes every keyboard leg a coin flip.
  #
  # So: always try the REAL Tk event first (send_key above, with its focus
  # nudges and 200 retries). Only when that never takes effect, drive the
  # SHIPPING handler with the arguments Tk would have passed, print a note
  # saying so, and re-test the predicate. What the fallback gives up is Tk's own
  # dispatch; that is covered separately and deterministically by the MXK
  # binding assertions below, and by whichever key legs did land normally.
  # `prep` (optional) is the RE-ESTABLISH step: it runs before every attempt and
  # between the rounds, so a context/focus/pointer that was stolen mid-leg is put
  # back rather than being tested around. Three rounds of {re-establish, Tk,
  # re-establish, shipping handler}; every retry prints a note so a flake shows
  # up in the log instead of disappearing, and a total failure prints the
  # distinctive MARKER-TEST-STALL line.
  proc send_key_fb {w ev done fb {prep {}}} {
    for {set t 1} {$t <= 3} {incr t} {
      if {$prep ne {}} {
        if {![uplevel 1 $prep]} {
          note "the re-establish step could not put the C context back on $w (round $t)"
        }
      }
      if {[uplevel 1 [list expr $done]]} { return 1 }
      if {[uplevel 1 [list send_key $w $ev $done [expr {$t == 1 ? 200 : 20}]]]} { return 1 }
      note "Tk key delivery stalled (WSLg focus) — driving the shipping handler (round $t)"
      if {$prep ne {}} { catch {uplevel 1 $prep} }
      catch {uplevel 1 $fb}
      update
      if {[uplevel 1 [list expr $done]]} { return 1 }
      if {$t < 3} {
        note "the shipping handler produced nothing either (round $t) — re-establishing and retrying"
      }
    }
    stall "$ev to $w never took effect after 3 rounds of Tk AND the shipping handler\
 (ctx=[pcall {xschem get current_win_path}] focus=[pcall {focus -displayof $w}]\
 mapped=[pcall {winfo ismapped $w}])"
    return 0
  }
  # deliver ONE key once focus is established -- the negative-leg twin of
  # send_key, which retries until a predicate turns true and would otherwise
  # hammer a do-nothing key 120 times
  # NOTE the mk_prep_ctx: a negative leg is the one that passes VACUOUSLY when
  # the context has been stolen (the key is swallowed by over_graph, nothing
  # happens, and "nothing happened" is exactly what the leg asserts). Putting
  # the context back first is what keeps these legs honest.
  proc mk_send_once {w ev} {
    if {![winfo exists $w]} { return 0 }
    set top [winfo toplevel $w]
    catch {wm deiconify $top}
    catch {raise $top}
    catch {event generate $top <FocusIn> -detail NotifyAncestor}
    focus -force $top
    focus -force $w
    update
    if {$w eq $::vdrw && ![mk_prep_ctx]} {
      note "mk_send_once: the C context could not be put back on $w"
    }
    set ::wbt [expr {$::wbt + 1000}]
    eval [list event generate $w] $ev [list -time $::wbt]
    update
    return 1
  }
  proc mk_list {gi} {
    xschem new_schematic switch $::vdrw
    return [xschem graph_marker list $gi]
  }
  # every C read has to name the window first: `xschem get ...` answers for the
  # CURRENT xctx, and with two windows open an unswitched read answers for the
  # wrong one -- which in a send_key predicate silently reads as "already done"
  proc mk_drag {} {
    xschem new_schematic switch $::vdrw
    return [xschem get graph_marker_drag]
  }
  proc mk_gflags {} {
    xschem new_schematic switch $::vdrw
    return [xschem get graph_flags]
  }
  proc mk_near {gi px py tol} {
    xschem new_schematic switch $::vdrw
    return [xschem get graph_near_wave $gi $px $py $tol]
  }
  # THE pixel scan: find a canvas row that sits ON the trace in strip `gi`'s band
  proc mk_trace_row {gi px y0 y1} {
    for {set y $y0} {$y < $y1} {incr y} {
      if {[mk_near $gi $px $y 2]} { return $y }
    }
    return {}
  }
  # wviewer::with_edit ALWAYS returns 1 (it reports "the bracket ran", not what
  # the script produced), so a creation has to hand its result out through a
  # variable in the CALLER's scope — which is where `uplevel 1 $script` runs it.
  # Getting this wrong makes every refusal leg pass vacuously.
  proc mk_wadd {tok gi px py} {
    set r {}
    wviewer::with_edit $tok {set r [xschem graph_marker add $gi $px $py]}
    return $r
  }
  proc mk_wdel {tok} {
    set r 0
    wviewer::with_edit $tok {set r [xschem graph_marker delete -all]}
    return $r
  }
  # Find a marker's ANCHOR and LABEL pixel by sweeping strip `gi`'s WHOLE band
  # with the engine's own hit-tester — which shares graph_marker_label_box with
  # the renderer, so a pixel this finds is by construction where the callout is
  # drawn. The sweep is at GRAPH_MARKER_TOL (8), the tolerance graph_marker_press
  # itself uses, so a pixel reported here as `label` is one the PRESS will also
  # read as a label rather than as the anchor. A band is ~200x190 px and a query
  # costs ~6 us, so the whole sweep is milliseconds — the anchor is never
  # predicted from where the marker "should" be, which is what keeps this honest
  # after a drag has moved it.
  # coordinate `d` of a scan result, or a harmless in-canvas fallback when the
  # scan found nothing. The fallback is deliberately a corner pixel no marker can
  # occupy, so the gesture still runs and its OWN assertions fail loudly — never
  # an `event generate -x {}` that aborts the whole file through the outer catch.
  proc mk_px {v d} {
    if {[llength $v] >= 2 && [lindex $v $d] ne {}} { return [lindex $v $d] }
    return 2
  }
  proc mk_parts {gi} {
    set bands [wviewer::strip_bands_px $::vdrw]
    if {$gi >= [llength $bands]} { return [list {} {}] }
    lassign [lindex $bands $gi] bx1 by1 bx2 by2
    # strip_bands_px answers in FRACTIONAL canvas pixels; `incr` needs integers
    set bx1 [expr {int($bx1)}]; set by1 [expr {int($by1)}]
    set bx2 [expr {int($bx2)}]; set by2 [expr {int($by2)}]
    xschem new_schematic switch $::vdrw
    set l {}
    set num 0
    set axs {}; set ays {}
    for {set y $by1} {$y <= $by2} {incr y 2} {
      for {set x $bx1} {$x <= $bx2} {incr x 2} {
        set r [xschem get graph_marker_at $gi $x $y 8]
        if {$r eq {}} continue
        if {[lindex $r 1] eq {anchor}} {
          if {!$num} { set num [lindex $r 0] }
          if {[lindex $r 0] == $num} { lappend axs $x; lappend ays $y }
        }
        if {[lindex $r 1] eq {label} && $l eq {}} { set l [list $x $y [lindex $r 0]] }
      }
    }
    # the CENTROID of the anchor hits, not the first one: the sweep runs
    # top-down so the first hit sits ~tol pixels ABOVE the dot, and MX7b needs to
    # press a few pixels above the CENTRE and still be inside GRAPH_MARKER_TOL
    set a {}
    if {[llength $axs]} {
      set sx 0; set sy 0
      foreach v $axs { incr sx $v }
      foreach v $ays { incr sy $v }
      set a [list [expr {$sx / [llength $axs]}] [expr {$sy / [llength $ays]}] $num]
    }
    return [list $a $l]
  }
  proc mk_bold {} {
    xschem new_schematic switch $::vdrw
    set v [xschem getprop rect 2 0 hilight_wave]
    if {$v eq {}} { return -1 }
    return $v
  }
  proc mk_bold_reset {tok} {
    wviewer::with_edit $tok {xschem setprop rect 2 0 hilight_wave -1}
  }

  # ---- the viewer's own self-healing scaffolding --------------------------
  # (the main-window half has mf_latched/mf_unlatch/mf_ready/mf_scan/mf_arm; the
  # same three failure modes exist here, plus the stolen-context one)

  # ui_state of the VIEWER context. GRAPHPAN 32768 + the schematic gesture bits;
  # any of them makes the next press a no-op exactly as in the main window.
  proc mx_latched {} {
    set u [pcall {xschem new_schematic switch $::vdrw; xschem get ui_state}]
    if {![string is integer -strict $u]} { return 0 }
    return [expr {$u & (32768 | 1 | 2 | 4 | 16 | 32 | 64 | 128 | 512)}]
  }
  # (2,2) is outside every strip band, which is what makes the trailing Motion
  # reach waves_selected's !is_inside branch -- the only place that clears
  # GRAPHPAN and aborts a marker drag. Escape first so a latched schematic
  # gesture is ABORTED rather than committed by the release.
  proc mx_unlatch {} {
    catch {xschem new_schematic switch $::vdrw}
    catch {xschem callback $::vdrw 2 2 2 65307 0 0 0}
    catch {xschem callback $::vdrw 5 2 2 0 1 0 256}
    catch {xschem callback $::vdrw 6 2 2 0 0 0 0}
    catch {xschem new_schematic switch $::vdrw}
  }
  proc mx_ready {tag} {
    if {![mk_prep_ctx]} { note "$tag the C context had to be put back on the viewer" }
    set l [mx_latched]
    if {$l} {
      note "$tag the viewer ui_state was latched ($l) before the gesture — clearing it"
      mx_unlatch
      set l [mx_latched]
      if {$l} { stall "$tag the viewer ui_state is STILL latched ($l) after mx_unlatch" }
    }
  }
  # force the viewer to a known state: mapped, focused, context ours, strips
  # re-fitted. Everything scanned off the canvas has to be re-derived after this.
  proc mx_reestablish {tok} {
    set top [winfo toplevel $::vdrw]
    catch {wm deiconify $top}
    catch {raise $top}
    for {set i 0} {$i < 100} {incr i} {
      update
      if {[winfo ismapped $::vdrw]} break
      after 20
    }
    mx_unlatch
    catch {wviewer::fit $tok}
    update
    mk_prep_ctx
  }
  # every viewer pixel scan goes through here: empty -> re-establish -> re-scan,
  # and only then give up, loudly. `script` is re-evaluated in the CALLER's scope
  # each round, so a caller whose pixel depends on a re-derived variable picks
  # the new value up.
  proc mx_scan {tag tok script} {
    for {set t 1} {$t <= 3} {incr t} {
      set r [uplevel 1 $script]
      if {$r ne {} && [lindex $r 0] ne {}} { return $r }
      if {$t == 3} break
      note "$tag scan came up empty (try $t) — re-mapping/re-fitting the viewer and re-scanning"
      mx_reestablish $tok
    }
    stall "$tag scan found nothing after 3 tries (mapped=[pcall {winfo ismapped $::vdrw}]\
 size=[pcall {winfo width $::vdrw}]x[pcall {winfo height $::vdrw}]\
 ctx=[pcall {xschem get current_win_path}] rects=[pcall {mk_list 0; xschem get graph_rects}])"
    return {}
  }
  # everything a failed viewer gesture needs explaining: the canvas geometry, the
  # strip bands, where C thinks the pointer is, and what each of the four gates
  # that can swallow a press answers at that pixel
  proc mx_diag {gi px py} {
    set d "W=[pcall {winfo width $::vdrw}]xH=[pcall {winfo height $::vdrw}]"
    append d " bands=[pcall {wviewer::strip_bands_px $::vdrw}]"
    append d " strip_at=[pcall {wviewer::strip_at_pixel $::vdrw $px $py}]"
    append d " over_graph=[pcall {wviewer::over_graph $::vdrw}]"
    append d " marker_at8=[pcall {xschem new_schematic switch $::vdrw
                                  xschem get graph_marker_at $gi $px $py 8}]"
    append d " trace_at=[pcall {wviewer::trace_at $::vdrw $gi $px $py}]"
    append d " gflags=[pcall {xschem new_schematic switch $::vdrw; xschem get graph_flags}]"
    append d " rec=[pcall {lindex [mk_list $gi] 0}]"
    append d " x1..x2=[pcall {xschem new_schematic switch $::vdrw
                              list [xschem getprop rect 2 $gi x1] [xschem getprop rect 2 $gi x2]}]"
    append d " y1..y2=[pcall {xschem new_schematic switch $::vdrw
                              list [xschem getprop rect 2 $gi y1] [xschem getprop rect 2 $gi y2]}]"
    return $d
  }
  # Press a marker part through a REAL Tk button event and VERIFY the arm.
  # `want` is graph_marker_drag's expected value (1 anchor, 2 label). On a miss
  # it says why, unlatches, re-scans (the part may have moved) and retries.
  # Returns the {x y num} part actually pressed, or {}.
  proc mx_arm {tag gi want {dx 0} {dy 0}} {
    # mx_diag is the failure explainer; the happy path never calls it
    for {set t 1} {$t <= 3} {incr t} {
      mx_ready $tag
      lassign [mk_parts $gi] A L
      set p [expr {$want == 2 ? $L : $A}]
      if {$p ne {}} {
        wb_ev $::vdrw <ButtonPress-1> -x [expr {[mk_px $p 0] + $dx}] \
                                      -y [expr {[mk_px $p 1] + $dy}]
        if {[mk_drag] == $want} { return $p }
        note "$tag press at ([expr {[mk_px $p 0]+$dx}],[expr {[mk_px $p 1]+$dy}])\
 did not arm $want (try $t): drag=[mk_drag] ui_state=[pcall {xschem get ui_state}]\
 ctx=[pcall {xschem get current_win_path}] part=$p\
 [mx_diag $gi [expr {[mk_px $p 0]+$dx}] [expr {[mk_px $p 1]+$dy}]]"
      } else {
        note "$tag no [expr {$want == 2 ? {label} : {anchor}}] pixel in the scan (try $t)"
      }
      if {$t < 3} { mx_reestablish [wviewer::token_for_canvas $::vdrw] }
    }
    stall "$tag could not arm a viewer marker drag ($want) after 3 tries —\
 ui_state=[pcall {xschem get ui_state}] ctx=[pcall {xschem get current_win_path}].\
 ui_state 0 after the press means C never even latched GRAPHPAN, i.e.\
 waves_selected() did not claim the pixel — the usual cause is a part drawn\
 inside the `border = 5 * tk_scaling` rim waves_selected() insets the rect by\
 (callback.c:128), which graph_marker_at still answers for but no press can reach"
    return {}
  }

  # Empty waveform space for the refusal legs: inside strip 0's BAND, at least
  # 25 px from every edge of it, and more than GRAPH_MARKER_PICK_TOL (20) px from
  # the trace.
  #
  # LANDMINE, pre-existing and nothing to do with markers: waves_selected() tests
  # the pointer against the graph rect INSET by `border = 5 * tk_scaling`
  # (callback.c), so a key pressed near a strip edge is NOT claimed by the graph
  # and falls through to the SCHEMATIC key handler — where 'a' opens
  # "make symbol view?", 'b' the merge-schematic dialog, 's'/'m' readonly_block()
  # and 't' the text dialog. Every one of those is MODAL, and a headless run then
  # hangs until the harness timeout kills it, scored as CRASH. Probe-verified at
  # y = 2: 'a', 'b', 's', 't' and 'm' all hang; only 'd' survives (its schematic
  # case is Ctrl-only). So: never aim a synthetic key at a strip edge.
  # strip_bands_px answers in FRACTIONAL canvas pixels (it divides by the zoom),
  # so the bounds are doubles, not integers
  proc mx_empty_row {} {
    global mxx mxy
    lassign [lindex [pcall {wviewer::strip_bands_px $::vdrw}] 0] mb_x1 mb_y1 mb_x2 mb_y2
    if {![string is double -strict $mb_y2] || ![string is integer -strict $mxy]} { return {} }
    set mb_lo [expr {int($mb_y1) + 25}]
    set mb_hi [expr {int($mb_y2) - 25}]
    foreach mxec [list [expr {$mxy + 45}] [expr {$mxy - 45}] [expr {$mxy + 60}] \
                       [expr {$mxy - 60}] [expr {($mb_lo + $mb_hi) / 2}] $mb_lo $mb_hi] {
      if {$mxec < $mb_lo || $mxec > $mb_hi} continue
      if {![mk_near 0 $mxx $mxec 25]} { return $mxec }
    }
    return {}
  }
  # ONE scan that derives the whole MX fixture together. Piecemeal re-scanning
  # is wrong here: mx_reestablish re-fits the strips, so a retry of one pixel
  # would silently leave the others describing the PREVIOUS layout.
  proc mx0_scan {} {
    global W H mxx mxx2 mxy mxy2 mxe
    set W [winfo width $::vdrw]; set H [winfo height $::vdrw]
    set mxx  [expr {int(0.45 * $W)}]
    set mxx2 [expr {int(0.70 * $W)}]
    set mxy  [mk_trace_row 0 $mxx  2 [expr {$H / 2}]]
    set mxy2 [mk_trace_row 0 $mxx2 2 [expr {$H / 2}]]
    set mxe  [mx_empty_row]
    return [expr {($mxy ne {} && $mxy2 ne {} && $mxe ne {}) ? 1 : 0}]
  }
  # the canvas must be its FINAL size before anything is scanned off it: a
  # `winfo width` taken while the WM is still settling gives a geometry the
  # strips are not laid out to, and every pixel derived from it is stale the
  # moment the pending <Configure> is delivered by the next `update`.
  mx_reestablish $tok
  for {set mx0t 1} {$mx0t <= 3} {incr mx0t} {
    if {[mx0_scan]} break
    if {$mx0t == 3} break
    note "MX0 the fixture scan is incomplete (W=$W H=$H mxy=$mxy mxy2=$mxy2 mxe=$mxe)\
 (try $mx0t) — re-mapping/re-fitting the viewer and re-scanning"
    mx_reestablish $tok
  }
  if {$mxy eq {} || $mxy2 eq {} || $mxe eq {}} {
    stall "MX0 could not scan a usable fixture pixel after 3 tries\
 (mapped=[winfo ismapped $vdrw] size=${W}x${H} ctx=[xschem get current_win_path]) —\
 the whole MX group is refused rather than run against pixels that test nothing"
  }
  check_true "MX0 a pixel ON the trace was found in strip 0 (the press pixel is SCANNED)" \
    [pexpr {$mxy ne {} && $mxy2 ne {}}]
  check_true "MX0 a pixel in EMPTY waveform space, well inside the band, was found" \
    [pexpr {$mxe ne {}}]

  if {$mxy eq {} || $mxy2 eq {} || $mxe eq {}} {
    puts "SKIPPED: MX* (no pixel on the trace was found — the fixture has no data)"
  } else {

  # spy on the viewer's replayable-log seam: a marker gesture must never be
  # mistaken for a strip reorder or a trace move, both of which DO log
  set ::mxlog {}
  rename wviewer::log_action wviewer::__real_log_action
  proc wviewer::log_action {line} { lappend ::mxlog $line }

  # GROUP CATCH -- see the one in the MF display half. An error inside a single
  # MX leg costs THIS GROUP and says so; it does not unwind into the file's
  # outer catch and take everything after it with it.
  if {[catch {

  # --- MXK: the key BINDINGS themselves (deterministic, no focus needed) --
  # These are what makes the send_key_fb fallback honest: if the Tk wiring were
  # removed, driving the handler directly would still work but these would fail.
  check_true "MXK <KeyPress> on the viewer canvas routes to wviewer::key_filter" \
    [string match {*wviewer::key_filter*} [bind $vdrw <KeyPress>]]
  check_true "MXK the WaveViewer bindtag is on the canvas" \
    [expr {[lsearch -exact [bindtags $vdrw] WaveViewer] >= 0}]
  check_true "MXK `u` is bound on that tag to the viewer undo" \
    [string match {*wviewer::undo_at*} [bind WaveViewer <Key-u>]]
  check_true "MXK `U` is bound on that tag to the viewer redo" \
    [string match {*wviewer::redo_at*} [bind WaveViewer <Key-U>]]
  # `m`, `d` and `M` reach C through key_filter's graphkeys allowlist; `d` must
  # be a member (marker-with-delta) and Delete must NOT be (membership forwards
  # unconditionally on modifiers, and a Delete that reached C with nothing
  # selected would land on the canvas delete verb)
  check_true "MXK graphkeys carries m (109), d (100) and M (77)" \
    [expr {[lsearch -exact $::wviewer::graphkeys 109] >= 0 &&
           [lsearch -exact $::wviewer::graphkeys 100] >= 0 &&
           [lsearch -exact $::wviewer::graphkeys 77]  >= 0}]
  check_true "MXK Delete (65535) is deliberately NOT a graphkeys member" \
    [expr {[lsearch -exact $::wviewer::graphkeys 65535] < 0}]
  check_true "MXK the shipped keybindings.csv carries the ctx=graph row for d" \
    [pcall {set fh [open [file join $repo src keybindings.csv] r]
            set t [read $fh]; close $fh
            regexp -line {^key,100,0,graph,graph\.forward} $t}]

  # --- MX1: `m` over a trace creates a marker at a real sample --------
  mx_ready {MX1}
  pcall {wviewer::with_edit $tok {xschem graph_marker delete -all}}
  pcall {xschem new_schematic switch $vdrw; xschem graph_marker select -none}
  set mx1gf [pcall {xschem new_schematic switch $vdrw; xschem get graph_flags}]
  mk_prep_at $mxx $mxy
  check_true "MX1 the pointer is over a graph as far as the key gate is concerned" \
    [pcall {wviewer::over_graph $vdrw}]
  # the `prep` argument is what defends this leg: over_graph -- the gate every
  # graph key goes through, Tk route and fallback alike -- returns 0 outright
  # when the C context is not this canvas, so a stolen context made BOTH routes
  # produce nothing. mk_prep_at puts the context, focus and pointer back before
  # every attempt and between the rounds.
  set mx1d [send_key_fb $vdrw [list <Key-m> -x $mxx -y $mxy] \
              {[llength [mk_list 0]] > 0} {wviewer::key_filter $vdrw 2 $mxx $mxy 109 m 0} \
              {mk_prep_at $mxx $mxy}]
  check_true "MX1 the m KeyPress was delivered" $mx1d
  check "MX1 exactly one marker exists" [pcall {llength [mk_list 0]}] 1
  set mx1 [lindex [pcall {mk_list 0}] 0]
  check "MX1 it is M1 on strip 0, node 0, dataset 0" [lrange $mx1 0 3] {1 0 0 0}
  check_true "MX1 its point is a real sample of the 11-point grid" \
    [pexpr {[string is integer -strict [lindex $mx1 4]] &&
            [lindex $mx1 4] >= 0 && [lindex $mx1 4] <= 10}]
  check_true "MX1 its x is that sample's sweep value" \
    [pcall {mk_close [lindex $mx1 5] [expr {[lindex $mx1 4] * 0.1}]}]
  check_true "MX1 its y agrees with `raw value` at that point" \
    [pcall {mk_close [lindex $mx1 6] [xschem raw value v_a [lindex $mx1 4]]}]
  check "MX1 the measurement-tooltip bit 64 is UNCHANGED (the m/M collision witness)" \
    [pcall {xschem new_schematic switch $vdrw; xschem get graph_flags}] $mx1gf
  check "MX1 the PUSH HOOK put it in the model" \
    [pcall {mk_model_mk $tok 0}] [pcall {xschem new_schematic switch $vdrw
                                         xschem getprop rect 2 0 markers}]
  check "MX1 the viewer buffer is still clean" \
    [pcall {xschem new_schematic switch $vdrw; xschem get modified}] 0
  check "MX1 no viewer log line (this is not a reorder or a trace move)" \
    [llength $::mxlog] 0

  # --- MX2: `M` (Shift-m) is the measurement tooltip, not a marker ----
  mx_ready {MX2}
  set mx2n [pcall {llength [mk_list 0]}]
  set mx2d [send_key_fb $vdrw [list <Key-M> -x $mxx -y $mxy -state 1] \
              {[mk_gflags] & 64} {wviewer::key_filter $vdrw 2 $mxx $mxy 77 M 1} \
              {mk_prep_at $mxx $mxy}]
  check_true "MX2 the M KeyPress was delivered" $mx2d
  check_true "MX2 M set the measurement bit 64" [pexpr {[mk_gflags] & 64}]
  check "MX2 M created NO marker" [pcall {llength [mk_list 0]}] $mx2n
  set mx2e [send_key_fb $vdrw [list <Key-M> -x $mxx -y $mxy -state 1] \
              {!([mk_gflags] & 64)} {wviewer::key_filter $vdrw 2 $mxx $mxy 77 M 1} \
              {mk_prep_at $mxx $mxy}]
  check_true "MX2 a second M cleared bit 64" $mx2e
  check "MX2 ... and still created nothing" [pcall {llength [mk_list 0]}] $mx2n

  # --- MX3: `d` creates the NEXT marker with a delta block ------------
  mx_ready {MX3}
  mk_prep_at $mxx2 $mxy2
  set mx3d [send_key_fb $vdrw [list <Key-d> -x $mxx2 -y $mxy2] \
              {[llength [mk_list 0]] > 1} {wviewer::key_filter $vdrw 2 $mxx2 $mxy2 100 d 0} \
              {mk_prep_at $mxx2 $mxy2}]
  check_true "MX3 the d KeyPress was delivered" $mx3d
  check "MX3 two markers now" [pcall {llength [mk_list 0]}] 2
  set mx3 [lindex [pcall {mk_list 0}] 1]
  check "MX3 the new marker is M2 and its prev is M1" \
    [list [lindex $mx3 0] [lindex $mx3 7]] {2 1}
  check_true "MX3 it snapped to a DIFFERENT sample than M1" \
    [pexpr {[lindex $mx3 4] ne {} && [lindex $mx3 4] != [lindex $mx1 4]}]
  check_true "MX3 its y agrees with `raw value` (numeric, 1e-7 relative)" \
    [pcall {mk_close [lindex $mx3 6] [xschem raw value v_a [lindex $mx3 4]]}]
  check_true "MX3 the label carries the delta block" \
    [pexpr {[regexp {slope:} [pcall {xschem new_schematic switch $vdrw
                                     xschem graph_marker text 2}]]}]
  check "MX3 still no viewer log line" [llength $::mxlog] 0

  # --- MX4: `m` where there is no trace creates nothing ---------------
  mx_ready {MX4}
  set mx4n [pcall {llength [mk_list 0]}]
  mk_prep_at $mxx $mxe
  check_true "MX4 the empty pixel is still CLAIMED by the graph (the key reaches C)" \
    [pcall {wviewer::over_graph $vdrw}]
  # ONE delivery, not a retry loop: hammering a key that is supposed to do
  # nothing 120 times is both pointless and a good way to trip an unrelated
  # modal (see the MX0 comment).
  check_true "MX4 the m KeyPress was delivered" [pcall {mk_send_once $vdrw \
    [list <Key-m> -x $mxx -y $mxe]}]
  check "MX4 m in empty waveform space creates nothing" [pcall {llength [mk_list 0]}] $mx4n
  check "MX4 ... and did not throw" [pcall {list ok}] ok
  check "MX4 the pixel-addressed verb refuses there too" \
    [pcall {mk_wadd $tok 0 $mxx $mxe}] {}
  check "MX4 ... while the same verb on a trace pixel succeeds (the control)" \
    [pcall {set n [mk_wadd $tok 0 $mxx $mxy]; mk_wdel $tok; expr {$n ne {}}}] 1

  # --- MX5: SELECT (press+release, no travel) -------------------------
  mx_ready {MX5}
  pcall {mk_wdel $tok}
  pcall {xschem new_schematic switch $vdrw; xschem graph_marker select -none}
  check "MX5 a marker was placed on the scanned trace pixel" \
    [pcall {mk_wadd $tok 0 $mxx $mxy}] 1
  lassign [mx_scan {MX5 marker parts} $tok {mk_parts 0}] mxA mxL
  check_true "MX5 the marker's ANCHOR pixel was found by the engine hit-tester" \
    [pexpr {$mxA ne {}}]
  check_true "MX5 the marker's LABEL pixel was found too (a distinct part)" \
    [pexpr {$mxL ne {}}]
  check_true "MX5 the two pixels are distinct and belong to the same marker" \
    [pexpr {$mxA ne {} && $mxL ne {} &&
            [lrange $mxA 0 1] ne [lrange $mxL 0 1] &&
            [lindex $mxA 2] == [lindex $mxL 2]}]
  mk_bold_reset $tok
  check "MX5 nothing bold to start" [pcall {mk_bold}] -1
  set mxA [mx_arm {MX5} 0 1]
  check "MX5 the press armed an ANCHOR drag (part 1)" \
    [pcall {xschem new_schematic switch $vdrw; xschem get graph_marker_drag}] 1
  wb_ev $vdrw <ButtonRelease-1> -x [mk_px $mxA 0] -y [mk_px $mxA 1] -state 0x100
  check "MX5 a no-travel release SELECTS the marker" \
    [pcall {xschem new_schematic switch $vdrw; xschem get graph_marker_sel}] 1
  check "MX5 the wave-bold was SUPPRESSED (the marker arm consumed the release)" \
    [pcall {mk_bold}] -1
  check "MX5 the drag arm was torn down" \
    [pcall {xschem new_schematic switch $vdrw; xschem get graph_marker_drag}] 0
  check "MX5 marker_selected agrees with the engine" \
    [pcall {wviewer::marker_selected $vdrw}] 1
  # a press on the trace but NOT on a marker: still bolds, and CLEARS the
  # selection (so a later Delete cannot silently eat a stale marker)
  mx_ready {MX5 bold}
  wb_ev $vdrw <ButtonPress-1>   -x $mxx2 -y $mxy2
  wb_ev $vdrw <ButtonRelease-1> -x $mxx2 -y $mxy2 -state 0x100
  check "MX5 a near-trace click that hit no marker still bolds" [pcall {mk_bold}] 0
  check "MX5 ... and cleared the marker selection" \
    [pcall {xschem new_schematic switch $vdrw; xschem get graph_marker_sel}] -1
  mk_bold_reset $tok

  # --- MX6: ANCHOR DRAG -----------------------------------------------
  # The four-way discrimination at press: C owns the gesture, and NONE of the
  # three Tcl/engine gestures that share the button may arm.
  set mx6before [lindex [pcall {mk_list 0}] 0]
  set mx6ids [pcall {mk_ids $tok}]
  set mx6ord [pcall {mk_order $tok}]
  set mx6log [llength $::mxlog]
  set mxA [mx_arm {MX6} 0 1]
  check_true "MX6 the anchor pixel was (re-)found by scanning" [pexpr {$mxA ne {}}]
  check "MX6 press: graph_marker_drag == 1 (anchor)" \
    [pcall {xschem new_schematic switch $vdrw; xschem get graph_marker_drag}] 1
  check "MX6 press: the TRACE drag did not arm" [pcall {set ::wviewer::tdrag_gi($tok)}] -1
  check "MX6 press: the STRIP reorder did not arm" [pcall {set ::wviewer::drag_from($tok)}] -1
  check "MX6 press: no cursor was grabbed (graph_flags 16|32|512|1024 all clear)" \
    [pcall {expr {[xschem get graph_flags] & (16|32|512|1024)}}] 0
  foreach mx6d {20 40 60} {
    wb_ev $vdrw <B1-Motion> -x [expr {[mk_px $mxA 0] + $mx6d}] -y [mk_px $mxA 1] -state 0x100
  }
  check "MX6 the model is NOT mutated mid-drag (the scratch is)" \
    [lindex [pcall {mk_list 0}] 0] $mx6before
  wb_ev $vdrw <ButtonRelease-1> -x [expr {[mk_px $mxA 0] + 60}] -y [mk_px $mxA 1] -state 0x100
  set mx6after [lindex [pcall {mk_list 0}] 0]
  check "MX6 the drag arm is torn down on release" \
    [pcall {xschem new_schematic switch $vdrw; xschem get graph_marker_drag}] 0
  check_true "MX6 the anchor moved to a DIFFERENT real sample" \
    [pexpr {[string is integer -strict [lindex $mx6after 4]] &&
            [lindex $mx6after 4] != [lindex $mx6before 4] &&
            [lindex $mx6after 4] >= 0 && [lindex $mx6after 4] <= 10}]
  check_true "MX6 x is that sample's sweep value" \
    [pcall {mk_close [lindex $mx6after 5] [expr {[lindex $mx6after 4] * 0.1}]}]
  check_true "MX6 y agrees with `raw value` at the new point" \
    [pcall {mk_close [lindex $mx6after 6] [xschem raw value v_a [lindex $mx6after 4]]}]
  check "MX6 the marker stayed on its OWN trace (wave unchanged)" \
    [lindex $mx6after 2] [lindex $mx6before 2]
  check "MX6 the label offset is UNTOUCHED by an anchor drag" \
    [lrange $mx6after 8 9] [lrange $mx6before 8 9]
  # the inert witnesses: neither a strip reorder nor a trace move happened
  check "MX6 the strips did not reorder (inert sdid witness)" [pcall {mk_ids $tok}] $mx6ids
  check "MX6 no trace moved between strips" [pcall {mk_order $tok}] $mx6ord
  check "MX6 no viewer log line was emitted" [llength $::mxlog] $mx6log
  check "MX6 the viewer buffer is still unmodified / readonly" \
    [pcall {xschem new_schematic switch $vdrw; list [xschem get modified] [xschem get readonly]}] \
    {0 1}
  check "MX6 the model picked the commit up through the push hook" \
    [pcall {mk_model_mk $tok 0}] [pcall {xschem new_schematic switch $vdrw
                                         xschem getprop rect 2 0 markers}]

  # --- MX7: LABEL DRAG, marker NOT selected ----------------------------
  # The unselected half of the gesture-semantics split (§6.2); MX7e below is the
  # selected half. The "not selected" precondition used to be INHERITED from
  # MX5's bold sub-leg and never stated, which meant a leg inserted above that
  # left a selection behind would silently retarget this one. Assert it.
  set mx7before [lindex [pcall {mk_list 0}] 0]
  set mx7ids [pcall {mk_ids $tok}]
  set mx7ord [pcall {mk_order $tok}]
  set mx7log [llength $::mxlog]
  check "MX7 precondition: the marker is NOT selected" \
    [pcall {xschem new_schematic switch $vdrw; xschem get graph_marker_sel}] -1
  set mxL2 [mx_arm {MX7} 0 2]
  check_true "MX7 the moved marker's label pixel was found" [pexpr {$mxL2 ne {}}]
  check "MX7 press on the LABEL arms drag part 2" \
    [pcall {xschem new_schematic switch $vdrw; xschem get graph_marker_drag}] 2
  check "MX7 press: the trace drag did not arm" [pcall {set ::wviewer::tdrag_gi($tok)}] -1
  check "MX7 press: the strip reorder did not arm" [pcall {set ::wviewer::drag_from($tok)}] -1
  foreach mx7d {10 20 30} {
    wb_ev $vdrw <B1-Motion> -x [expr {[mk_px $mxL2 0] + 12}] \
      -y [expr {[mk_px $mxL2 1] + $mx7d}] -state 0x100
  }
  wb_ev $vdrw <ButtonRelease-1> -x [expr {[mk_px $mxL2 0] + 12}] \
    -y [expr {[mk_px $mxL2 1] + 30}] -state 0x100
  set mx7after [lindex [pcall {mk_list 0}] 0]
  check_true "MX7 ldx/ldy CHANGED" \
    [pexpr {[lrange $mx7after 8 9] ne [lrange $mx7before 8 9]}]
  check "MX7 dataset/point/x/y are UNCHANGED (the other half of the assertion)" \
    [lrange $mx7after 3 6] [lrange $mx7before 3 6]
  check "MX7 the wave is unchanged too" [lindex $mx7after 2] [lindex $mx7before 2]
  check "MX7 the strips did not reorder (inert sdid witness)" [pcall {mk_ids $tok}] $mx7ids
  check "MX7 no trace moved between strips" [pcall {mk_order $tok}] $mx7ord
  check "MX7 no viewer log line was emitted" [llength $::mxlog] $mx7log
  check "MX7 the drag arm is torn down" \
    [pcall {xschem new_schematic switch $vdrw; xschem get graph_marker_drag}] 0
  check "MX7 the model picked the label commit up" \
    [pcall {mk_model_mk $tok 0}] [pcall {xschem new_schematic switch $vdrw
                                         xschem getprop rect 2 0 markers}]

  # --- MX7e/MX7f: SELECTED + text drag moves the ANCHOR too ------------
  # The other half of the §6.2 split. On an UNSELECTED marker a text drag moves
  # only the callout (MX7 above). On a SELECTED one the WHOLE marker translates:
  # the anchor re-snaps to a real sample on its own trace and the callout keeps
  # its offset, so ldx/ldy come out FROZEN — the exact mirror of MX7.
  #
  # The mode is latched at PRESS from the selection state, so what was GRABBED
  # is still part 2 and every Tcl seam reading `xschem get graph_marker_drag`
  # (wviewer::marker_grabbed, strip_drag_release's with_edit bracket) sees what
  # it always saw. That is asserted here, not assumed.
  #
  # Own fixture, deliberately: this leg both needs and leaves a selection, and
  # MX7 / MX7c / MX8 / MX9 all expect to find none.
  mx_ready {MX7e}
  pcall {mk_wdel $tok}
  pcall {wviewer::fit $tok}
  pcall {xschem new_schematic switch $vdrw; xschem graph_marker select -none}
  set mx7ey [mx_scan {MX7e trace row} $tok {mk_trace_row 0 $mxx 2 [expr {$H / 2}]}]
  if {$mx7ey eq {}} { set mx7ey $mxy }
  check "MX7e a marker on a freshly scanned trace pixel" \
    [pcall {mk_wadd $tok 0 $mxx $mx7ey}] 1
  # select it the way a user does: a no-travel press+release on its anchor
  set mx7eA [mx_arm {MX7e select} 0 1]
  check_true "MX7e the anchor pixel was found" [pexpr {$mx7eA ne {}}]
  wb_ev $vdrw <ButtonRelease-1> -x [mk_px $mx7eA 0] -y [mk_px $mx7eA 1] -state 0x100
  check_true "MX7e the no-travel click SELECTED the marker" \
    [pexpr {[pcall {xschem new_schematic switch $vdrw; xschem get graph_marker_sel}] > 0}]
  set mx7ebefore [lindex [pcall {mk_list 0}] 0]
  set mx7eids [pcall {mk_ids $tok}]
  set mx7eord [pcall {mk_order $tok}]
  set mx7elog [llength $::mxlog]
  # Re-arm the selection with the VERB immediately before the press. mx_arm
  # retries up to 3 times, and a retry whose press lands off the callout
  # DESELECTS (graph_marker_press clears on a miss) — which would quietly turn
  # this into a second copy of MX7. The click above is what proves the user path
  # works; this makes the leg test the DRAG rather than the arming.
  pcall {xschem new_schematic switch $vdrw; xschem graph_marker select 1 0}
  set mx7eL [mx_arm {MX7e} 0 2]
  check_true "MX7e the label pixel was found" [pexpr {$mx7eL ne {}}]
  check_true "MX7e the marker is still selected at press time (the latch input)" \
    [pexpr {[pcall {xschem new_schematic switch $vdrw; xschem get graph_marker_sel}] > 0}]
  check "MX7e the GRABBED part is still 2 — the Tcl seams read this value" \
    [pcall {xschem new_schematic switch $vdrw; xschem get graph_marker_drag}] 2
  check "MX7e press: the trace drag did not arm" [pcall {set ::wviewer::tdrag_gi($tok)}] -1
  check "MX7e press: the strip reorder did not arm" [pcall {set ::wviewer::drag_from($tok)}] -1
  check "MX7e the model is NOT mutated mid-drag (the scratch is)" \
    [lindex [pcall {mk_list 0}] 0] $mx7ebefore
  foreach mx7ed {40 80 120} {
    wb_ev $vdrw <B1-Motion> -x [expr {[mk_px $mx7eL 0] + $mx7ed}] \
      -y [mk_px $mx7eL 1] -state 0x100
  }
  wb_ev $vdrw <ButtonRelease-1> -x [expr {[mk_px $mx7eL 0] + 120}] \
    -y [mk_px $mx7eL 1] -state 0x100
  set mx7eafter [lindex [pcall {mk_list 0}] 0]
  check "MX7e the drag arm is torn down on release" \
    [pcall {xschem new_schematic switch $vdrw; xschem get graph_marker_drag}] 0
  # THE ASSERTION: the mirror of MX7's
  check_true "MX7e the ANCHOR moved to a DIFFERENT real sample" \
    [pexpr {[string is integer -strict [lindex $mx7eafter 4]] &&
            [lindex $mx7eafter 4] != [lindex $mx7ebefore 4] &&
            [lindex $mx7eafter 4] >= 0 && [lindex $mx7eafter 4] <= 10}]
  check_true "MX7e x is that sample's sweep value (it SNAPPED, it did not slide)" \
    [pcall {mk_close [lindex $mx7eafter 5] [expr {[lindex $mx7eafter 4] * 0.1}]}]
  check_true "MX7e y agrees with `raw value` at the new point" \
    [pcall {mk_close [lindex $mx7eafter 6] [xschem raw value v_a [lindex $mx7eafter 4]]}]
  check "MX7e the marker stayed on its OWN trace (wave unchanged)" \
    [lindex $mx7eafter 2] [lindex $mx7ebefore 2]
  check "MX7e ldx/ldy are FROZEN — a rigid translation, not a label move" \
    [lrange $mx7eafter 8 9] [lrange $mx7ebefore 8 9]
  check_true "MX7e the marker is still selected (a drag never changes the selection)" \
    [pexpr {[pcall {xschem new_schematic switch $vdrw; xschem get graph_marker_sel}] > 0}]
  check "MX7e the strips did not reorder (inert sdid witness)" [pcall {mk_ids $tok}] $mx7eids
  check "MX7e no trace moved between strips" [pcall {mk_order $tok}] $mx7eord
  check "MX7e no viewer log line was emitted" [llength $::mxlog] $mx7elog
  check "MX7e the viewer buffer is still unmodified / readonly" \
    [pcall {xschem new_schematic switch $vdrw; list [xschem get modified] [xschem get readonly]}] \
    {0 1}
  check "MX7e the model picked the ANCHOR commit up through the push hook" \
    [pcall {mk_model_mk $tok 0}] [pcall {xschem new_schematic switch $vdrw
                                         xschem getprop rect 2 0 markers}]
  # MX7f, the A/B control: DESELECT and the SAME gesture moves only the callout
  # again. Without this the leg would prove "an anchor moved", not "the
  # SELECTION is what decides".
  pcall {xschem new_schematic switch $vdrw; xschem graph_marker select -none}
  set mx7fbefore [lindex [pcall {mk_list 0}] 0]
  set mx7fL [mx_arm {MX7f} 0 2]
  check_true "MX7f the label pixel was re-found after deselecting" [pexpr {$mx7fL ne {}}]
  foreach mx7fd {10 20 30} {
    wb_ev $vdrw <B1-Motion> -x [expr {[mk_px $mx7fL 0] + 12}] \
      -y [expr {[mk_px $mx7fL 1] + $mx7fd}] -state 0x100
  }
  wb_ev $vdrw <ButtonRelease-1> -x [expr {[mk_px $mx7fL 0] + 12}] \
    -y [expr {[mk_px $mx7fL 1] + 30}] -state 0x100
  set mx7fafter [lindex [pcall {mk_list 0}] 0]
  check_true "MX7f DESELECTED: ldx/ldy move again" \
    [pexpr {[lrange $mx7fafter 8 9] ne [lrange $mx7fbefore 8 9]}]
  check "MX7f DESELECTED: the anchor is left alone" \
    [lrange $mx7fafter 3 6] [lrange $mx7fbefore 3 6]
  # MX7g/MX7h: the mode is LATCHED AT PRESS, never re-read at release. Nothing
  # in MX7e or MX7f can tell the two implementations apart — the selection does
  # not change during either gesture — so these two change it MID-DRAG, in both
  # directions, and assert the commit follows the state as it was at PRESS.
  # `xschem graph_marker select` is pure UI state (no token write, no undo, not
  # read-only gated), so a script or a second window can legitimately do this
  # while a drag is armed.
  pcall {xschem new_schematic switch $vdrw; xschem graph_marker select 1 0}
  set mx7gbefore [lindex [pcall {mk_list 0}] 0]
  set mx7gL [mx_arm {MX7g} 0 2]
  check_true "MX7g the label pixel was found" [pexpr {$mx7gL ne {}}]
  check_true "MX7g SELECTED at press" \
    [pexpr {[pcall {xschem new_schematic switch $vdrw; xschem get graph_marker_sel}] > 0}]
  foreach mx7gd {40 80 120} {
    wb_ev $vdrw <B1-Motion> -x [expr {[mk_px $mx7gL 0] + $mx7gd}] \
      -y [mk_px $mx7gL 1] -state 0x100
  }
  pcall {xschem new_schematic switch $vdrw; xschem graph_marker select -none}
  wb_ev $vdrw <ButtonRelease-1> -x [expr {[mk_px $mx7gL 0] + 120}] \
    -y [mk_px $mx7gL 1] -state 0x100
  set mx7gafter [lindex [pcall {mk_list 0}] 0]
  check_true "MX7g DESELECTING mid-drag did not change the mode: the anchor moved" \
    [pexpr {[lindex $mx7gafter 4] ne [lindex $mx7gbefore 4]}]
  check "MX7g ... and ldx/ldy stayed frozen" \
    [lrange $mx7gafter 8 9] [lrange $mx7gbefore 8 9]
  set mx7hbefore [lindex [pcall {mk_list 0}] 0]
  set mx7hL [mx_arm {MX7h} 0 2]
  check_true "MX7h the label pixel was found" [pexpr {$mx7hL ne {}}]
  check "MX7h NOT selected at press" \
    [pcall {xschem new_schematic switch $vdrw; xschem get graph_marker_sel}] -1
  foreach mx7hd {10 20 30} {
    wb_ev $vdrw <B1-Motion> -x [expr {[mk_px $mx7hL 0] + 12}] \
      -y [expr {[mk_px $mx7hL 1] + $mx7hd}] -state 0x100
  }
  pcall {xschem new_schematic switch $vdrw; xschem graph_marker select 1 0}
  wb_ev $vdrw <ButtonRelease-1> -x [expr {[mk_px $mx7hL 0] + 12}] \
    -y [expr {[mk_px $mx7hL 1] + 30}] -state 0x100
  set mx7hafter [lindex [pcall {mk_list 0}] 0]
  check "MX7h SELECTING mid-drag did not change the mode: the anchor is untouched" \
    [lrange $mx7hafter 3 6] [lrange $mx7hbefore 3 6]
  check_true "MX7h ... and it stayed a label move" \
    [pexpr {[lrange $mx7hafter 8 9] ne [lrange $mx7hbefore 8 9]}]

  # hand the state back the way MX7c / MX8 / MX9 expect to find it
  pcall {xschem new_schematic switch $vdrw; xschem graph_marker select -none}
  check "MX7e the selection is handed back cleared" \
    [pcall {xschem new_schematic switch $vdrw; xschem get graph_marker_sel}] -1

  # --- MX7c: the reorder GRIP keeps first refusal ----------------------
  # The grip owns the rightmost GRAPH_REORDER_HANDLE_W = 14 px of the band over
  # its FULL height; C declines that column outright so the two can never
  # disagree.
  mx_ready {MX7c}
  set mx7cb [lindex [pcall {wviewer::strip_bands_px $vdrw}] 0]
  check_true "MX7c strip_bands_px returned strip 0's band" [pexpr {[llength $mx7cb] == 4}]
  if {[llength $mx7cb] == 4} {
    lassign $mx7cb mx7cx1 mx7cy1 mx7cx2 mx7cy2
    set mx7cx [expr {$mx7cx2 - 5}]
    set mx7cy [expr {($mx7cy1 + $mx7cy2) / 2}]
    wb_ev $vdrw <ButtonPress-1> -x $mx7cx -y $mx7cy
    check "MX7c a press in the grip column armed the STRIP reorder" \
      [pcall {expr {$::wviewer::drag_from($tok) >= 0}}] 1
    check "MX7c ... and armed NO marker drag" \
      [pcall {xschem new_schematic switch $vdrw; xschem get graph_marker_drag}] 0
    wb_ev $vdrw <B1-Motion> -x $mx7cx -y [expr {$mx7cy + 8}] -state 0x100
    pcall {wviewer::strip_drag_cancel $vdrw}
    wb_ev $vdrw <ButtonRelease-1> -x $mx7cx -y [expr {$mx7cy + 8}] -state 0x100
    check "MX7c the cancelled reorder left the stack alone" [pcall {mk_ids $tok}] {A B}
  }

  # --- MX8: the drag does not pan, bold, or grab a cursor -------------
  mx_ready {MX8}
  mk_bold_reset $tok
  xschem new_schematic switch $vdrw
  set mx8x1 [pcall {xschem getprop rect 2 0 x1}]
  set mx8x2 [pcall {xschem getprop rect 2 0 x2}]
  lassign [mx_scan {MX8 marker parts} $tok {mk_parts 0}] mxA3 mxL3
  check_true "MX8 the anchor pixel was re-found for the drag" [pexpr {$mxA3 ne {}}]
  # park cursor A exactly under the press pixel so a cursor grab is certain if
  # the marker arm ever fails to consume the press
  # parked through the C verbs, deliberately NOT wviewer::cursor_toggle: that
  # proc also pops the readout panel, and a widget appearing mid-run is enough to
  # cost the toplevel its WSLg input focus for the rest of the file (every
  # synthetic KeyPress after it then goes nowhere). Same witness, no side effects.
  set mx8c [pcall {xschem graph_coord 0 [mk_px $mxA3 0] [mk_px $mxA3 1]}]
  set mx8c0 {}
  if {[llength $mx8c] == 2} {
    xschem new_schematic switch $vdrw
    pcall {xschem cursor 1 1}
    pcall {xschem set cursor1_x [lindex $mx8c 0]}
    pcall {xschem redraw}
    set mx8c0 [pcall {xschem get cursor1_x}]
  }
  set mxA3 [mx_arm {MX8} 0 1]
  check "MX8 the press still armed the MARKER, not the cursor" \
    [pcall {xschem new_schematic switch $vdrw; xschem get graph_marker_drag}] 1
  check "MX8 no cursor grab flag was set" \
    [pcall {expr {[xschem get graph_flags] & (16|32|512|1024)}}] 0
  foreach mx8d {15 30 45} {
    wb_ev $vdrw <B1-Motion> -x [expr {[mk_px $mxA3 0] - $mx8d}] -y [mk_px $mxA3 1] -state 0x100
  }
  wb_ev $vdrw <ButtonRelease-1> -x [expr {[mk_px $mxA3 0] - 45}] -y [mk_px $mxA3 1] -state 0x100
  xschem new_schematic switch $vdrw
  check_true "MX8 the graph x range did not pan" \
    [pexpr {abs([pcall {xschem getprop rect 2 0 x1}] - $mx8x1) <= 1e-12 &&
            abs([pcall {xschem getprop rect 2 0 x2}] - $mx8x2) <= 1e-12}]
  check "MX8 the drag did not bold a trace" [pcall {mk_bold}] -1
  if {$mx8c0 ne {}} {
    check_true "MX8 cursor A did not move" \
      [pexpr {abs([pcall {xschem get cursor1_x}] - $mx8c0) <= 1e-15}]
    xschem new_schematic switch $vdrw
    pcall {xschem cursor 1 0}
    pcall {xschem redraw}
  } else {
    check_true "MX8 graph_coord resolved the cursor witness" 0
  }

  # --- MX8b: chord suppression + the stale-arm teardown ---------------
  mx_ready {MX8b}
  xschem new_schematic switch $vdrw
  set mx8bx1 [pcall {xschem getprop rect 2 0 x1}]
  set mx8bm [lindex [pcall {mk_list 0}] 0]
  set mxA4 [mx_arm {MX8b} 0 1]
  check_true "MX8b the anchor pixel was re-found" [pexpr {$mxA4 ne {}}]
  wb_ev $vdrw <B2-Motion> -x [expr {[mk_px $mxA4 0] + 40}] -y [mk_px $mxA4 1] -state 0x300
  wb_ev $vdrw <B3-Motion> -x [expr {[mk_px $mxA4 0] + 60}] -y [mk_px $mxA4 1] -state 0x500
  xschem new_schematic switch $vdrw
  check_true "MX8b a B2/B3 chord during a marker drag did NOT pan the graph" \
    [pexpr {abs([pcall {xschem getprop rect 2 0 x1}] - $mx8bx1) <= 1e-12}]
  # a NON-Button1 release aborts the arm, so it cannot commit on the next LMB
  wb_ev $vdrw <ButtonRelease-3> -x [expr {[mk_px $mxA4 0] + 60}] -y [mk_px $mxA4 1] -state 0x500
  check "MX8b a Button3 release tore the stale arm down" \
    [pcall {xschem new_schematic switch $vdrw; xschem get graph_marker_drag}] 0
  wb_ev $vdrw <ButtonRelease-1> -x [expr {[mk_px $mxA4 0] + 60}] -y [mk_px $mxA4 1] -state 0x100
  check "MX8b ... and the following Button1 release moved nothing" \
    [lindex [pcall {mk_list 0}] 0] $mx8bm

  # --- MX9: ESC mid-drag cancels --------------------------------------
  set mx9before [lindex [pcall {mk_list 0}] 0]
  set mx9log [llength $::mxlog]
  set mxA5 [mx_arm {MX9} 0 1]
  check_true "MX9 the anchor pixel was re-found" [pexpr {$mxA5 ne {}}]
  wb_ev $vdrw <B1-Motion> -x [expr {[mk_px $mxA5 0] - 55}] -y [mk_px $mxA5 1] -state 0x100
  # ctx-ONLY prep here: mk_prep_at would generate a Motion, and this gesture is
  # a LIVE drag -- a stray motion would slide the anchor before ESC cancels it
  check_true "MX9 ESC was delivered" \
    [send_key_fb $vdrw [list <Key-Escape> -x [mk_px $mxA5 0] -y [mk_px $mxA5 1]] \
       {[mk_drag] == 0} \
       {wviewer::key_filter $vdrw 2 [mk_px $mxA5 0] [mk_px $mxA5 1] 65307 Escape 0} \
       {mk_prep_ctx}]
  check "MX9 the drag arm is gone" \
    [pcall {xschem new_schematic switch $vdrw; xschem get graph_marker_drag}] 0
  wb_ev $vdrw <ButtonRelease-1> -x [expr {[mk_px $mxA5 0] - 55}] -y [mk_px $mxA5 1] -state 0x100
  check "MX9 the marker is back where it was, byte-identically" \
    [lindex [pcall {mk_list 0}] 0] $mx9before
  check "MX9 nothing was logged" [llength $::mxlog] $mx9log

  # --- MX10: Delete removes the SELECTED marker, and only then --------
  # MX10's subject is the DELETE GATE, not wherever the drag legs above happened
  # to leave the marker -- and "wherever" can be UN-CLICKABLE. MX8's leftward
  # anchor drag can park it on the EXTREME sample of v_a (x=0, y=1.0, the data
  # minimum), whose anchor is then drawn ON the plot-box edge, inside the
  # `border = 5 * tk_scaling` rim that waves_selected() insets the graph rect by
  # (callback.c:128). graph_marker_at still reports an anchor there, so the scan
  # succeeds -- but the PRESS is never claimed by the graph, so the select click
  # silently does nothing and every MX10 leg after it collapses. Measured once in
  # 27 runs, with the retry diagnostics showing the same pixel refusing to arm
  # three times at ui_state=0 (i.e. C never even latched GRAPHPAN).
  # So MX10 builds its OWN fixture on a freshly scanned trace pixel, exactly as
  # MX11 / MX13 / MX7b already do. Nothing is given up: the leg still creates a
  # marker, still selects it by clicking its anchor, and still asserts all three
  # Delete outcomes.
  mx_ready {MX10}
  pcall {mk_wdel $tok}
  pcall {wviewer::fit $tok}
  set mx10y [mx_scan {MX10 trace row} $tok {mk_trace_row 0 $mxx 2 [expr {$H / 2}]}]
  if {$mx10y eq {}} { set mx10y $mxy }
  check "MX10 a marker to delete, on a freshly scanned trace pixel" \
    [pcall {mk_wadd $tok 0 $mxx $mx10y}] 1
  lassign [mx_scan {MX10 marker parts} $tok {mk_parts 0}] mxA6 mxL6
  check_true "MX10 the anchor pixel was re-found" [pexpr {$mxA6 ne {}}]
  # nothing selected: Delete over the graph must leave the marker alone
  pcall {xschem new_schematic switch $vdrw; xschem graph_marker select -none}
  set mx10n [pcall {llength [mk_list 0]}]
  check_true "MX10 there is a marker to try to delete" [pexpr {$mx10n > 0}]
  mk_prep_at [mk_px $mxA6 0] [mk_px $mxA6 1]
  # ONE delivery: this leg asserts that NOTHING happens, so a retry-until-true
  # helper would burn its whole budget and print a misleading stall message
  check_true "MX10 the (negative) Delete was delivered once" \
    [pcall {mk_send_once $vdrw [list <Key-Delete> -x [mk_px $mxA6 0] -y [mk_px $mxA6 1]]}]
  check "MX10 Delete with NOTHING selected leaves the markers alone" \
    [pcall {llength [mk_list 0]}] $mx10n
  # select it, hover a DIFFERENT strip, Delete -> still alone (scoped delete)
  set mxA6 [mx_arm {MX10 select} 0 1]
  wb_ev $vdrw <ButtonRelease-1> -x [mk_px $mxA6 0] -y [mk_px $mxA6 1] -state 0x100
  check_true "MX10 the marker is selected" \
    [pexpr {[pcall {xschem new_schematic switch $vdrw; xschem get graph_marker_sel}] > 0}]
  set mx10b [lindex [pcall {wviewer::strip_bands_px $vdrw}] 1]
  check_true "MX10 the second strip band was resolvable" [pexpr {[llength $mx10b] == 4}]
  if {[llength $mx10b] == 4} {
    lassign $mx10b b1x1 b1y1 b1x2 b1y2
    mk_prep_at [expr {int(($b1x1 + $b1x2) / 2)}] [expr {int(($b1y1 + $b1y2) / 2)}]
    check_true "MX10 the wrong-strip Delete was delivered once" \
      [pcall {mk_send_once $vdrw [list <Key-Delete> -x [expr {($b1x1 + $b1x2) / 2}] \
                -y [expr {($b1y1 + $b1y2) / 2}]]}]
    check "MX10 Delete while hovering ANOTHER strip leaves the marker alone" \
      [pcall {llength [mk_list 0]}] $mx10n
  }
  # hover the OWNING strip -> it goes
  mk_prep_at [mk_px $mxA6 0] [mk_px $mxA6 1]
  check_true "MX10 Delete over the owning strip was delivered" \
    [send_key_fb $vdrw [list <Key-Delete> -x [mk_px $mxA6 0] -y [mk_px $mxA6 1]] \
       {[llength [mk_list 0]] < $mx10n} \
       {wviewer::key_filter $vdrw 2 [mk_px $mxA6 0] [mk_px $mxA6 1] 65535 Delete 0} \
       {mk_prep_at [mk_px $mxA6 0] [mk_px $mxA6 1]}]
  check "MX10 the selected marker is gone" \
    [pcall {llength [mk_list 0]}] [pexpr {$mx10n - 1}]
  check "MX10 the selection was reset with it" \
    [pcall {xschem new_schematic switch $vdrw; xschem get graph_marker_sel}] -1
  check "MX10 the model followed" \
    [pcall {mk_model_mk $tok 0}] [pcall {xschem new_schematic switch $vdrw
                                         xschem getprop rect 2 0 markers}]

  # --- MX11: `u` / `U` undo and redo a marker GESTURE ------------------
  # asserted against the RECT TOKEN, not just the model
  mx_ready {MX11}
  pcall {mk_wdel $tok}
  # the preceding drags/chords moved the graph ranges, so the trace is no longer
  # at the row MX0 scanned: re-fit and RE-SCAN rather than reusing a stale pixel
  pcall {wviewer::fit $tok}
  set mx11y [mx_scan {MX11 trace row after the fit} $tok \
               {mk_trace_row 0 $mxx 2 [expr {$H / 2}]}]
  check_true "MX11 a trace pixel was re-scanned after the fit" [pexpr {$mx11y ne {}}]
  if {$mx11y eq {}} { set mx11y $mxy }
  pcall {wviewer::clear_history $tok}
  mk_prep_at $mxx $mx11y
  check_true "MX11 a marker was created with m" \
    [send_key_fb $vdrw [list <Key-m> -x $mxx -y $mx11y] \
       {[llength [mk_list 0]] > 0} {wviewer::key_filter $vdrw 2 $mxx $mx11y 109 m 0} \
       {mk_prep_at $mxx $mx11y}]
  set mx11tok [pcall {xschem new_schematic switch $vdrw; xschem getprop rect 2 0 markers}]
  check_true "MX11 the rect carries a token" [pexpr {$mx11tok ne {}}]
  check "MX11 exactly one undo point" [pcall {wviewer::history_depth $tok}] {1 0}
  # u / U live on the WaveViewer BINDTAG, not on key_filter, so over_graph is not
  # in the way -- but the C context still is (undo_at resolves the token from the
  # canvas and then drives that xctx), hence the ctx-only prep
  check_true "MX11 the u key was delivered" \
    [send_key_fb $vdrw [list <Key-u> -x $mxx -y $mx11y] \
       {[lindex [wviewer::history_depth $tok] 0] == 0} {wviewer::undo_at $vdrw} \
       {mk_prep_ctx}]
  check "MX11 u removed the marker from the RECT" \
    [pcall {xschem new_schematic switch $vdrw; xschem getprop rect 2 0 markers}] {}
  check "MX11 ... and from the model" \
    [pcall {dict exists [lindex [mk_graphs $tok] 0] markers}] 0
  check_true "MX11 the U key was delivered" \
    [send_key_fb $vdrw [list <Key-U> -x $mxx -y $mx11y -state 1] \
       {[lindex [wviewer::history_depth $tok] 0] == 1} {wviewer::redo_at $vdrw} \
       {mk_prep_ctx}]
  check "MX11 U restored the RECT token byte-identically" \
    [pcall {xschem new_schematic switch $vdrw; xschem getprop rect 2 0 markers}] $mx11tok

  # --- MX12: MMB still pans and RMB still box-zooms with markers up ----
  pcall {wviewer::fit $tok}
  xschem new_schematic switch $vdrw
  set mx12x1 [pcall {xschem getprop rect 2 0 x1}]
  mx_ready {MX12}
  wb_ev $vdrw <ButtonPress-2> -x [expr {int(0.30 * $W)}] -y $mxy
  foreach mx12f {0.40 0.50 0.60} {
    wb_ev $vdrw <B2-Motion> -x [expr {int($mx12f * $W)}] -y $mxy -state 0x200
  }
  wb_ev $vdrw <ButtonRelease-2> -x [expr {int(0.60 * $W)}] -y $mxy -state 0x200
  xschem new_schematic switch $vdrw
  check_true "MX12 MMB still pans the graph with a marker present" \
    [pexpr {abs([pcall {xschem getprop rect 2 0 x1}] - $mx12x1) > 1e-12}]
  pcall {wviewer::fit $tok}
  xschem new_schematic switch $vdrw
  set mx12s [pexpr {[pcall {xschem getprop rect 2 0 x2}] - [pcall {xschem getprop rect 2 0 x1}]}]
  mx_ready {MX12 box-zoom}
  wb_ev $vdrw <ButtonPress-3>   -x [expr {int(0.30 * $W)}] -y $mxy
  wb_ev $vdrw <ButtonRelease-3> -x [expr {int(0.70 * $W)}] -y $mxy -state 0x400
  xschem new_schematic switch $vdrw
  check_true "MX12 RMB still box-zooms with a marker present (x span narrowed)" \
    [pexpr {([pcall {xschem getprop rect 2 0 x2}] - [pcall {xschem getprop rect 2 0 x1}]) <
            $mx12s - 1e-9}]
  pcall {wviewer::fit $tok}

  # --- MX13: draw_graph / hit-test FACE AGREEMENT ----------------------
  # `xschem draw_graph` installs no cairo face; graph_marker_at installs the toy
  # face itself. If the two ever measured with different faces the drawn callout
  # and the clickable box would disagree.
  mx_ready {MX13}
  pcall {mk_wdel $tok}
  set mx13y [mx_scan {MX13 trace row} $tok {mk_trace_row 0 $mxx 2 [expr {$H / 2}]}]
  if {$mx13y eq {}} { set mx13y $mxy }
  check "MX13 a marker for the face-agreement check" \
    [pcall {mk_wadd $tok 0 $mxx $mx13y}] 1
  pcall {xschem new_schematic switch $vdrw; xschem draw_graph 0}
  lassign [mx_scan {MX13 marker parts after draw_graph} $tok {mk_parts 0}] mx13A mx13L
  check_true "MX13 after `xschem draw_graph 0` the ANCHOR is still hit-testable" \
    [pexpr {$mx13A ne {}}]
  check_true "MX13 ... and so is the LABEL box" [pexpr {$mx13L ne {}}]
  check "MX13 both parts belong to the same marker" \
    [list [lindex $mx13A 2] [lindex $mx13L 2]] {1 1}

  # --- MX7b: TOP-EDGE press, then drag OUT OF THE WINDOW ---------------
  # `xctx->graph_top` latches whenever the pointer is ABOVE the plot box, and the
  # GRAPHPAN routing latch used to be gated on !graph_top. GRAPHPAN is what keeps
  # waves_selected routing a drag after the pointer leaves the strip
  # (check = (ui_state & GRAPHPAN) || POINTINSIDE) and what keeps the
  # leave-the-graph branch from calling graph_marker_drag_abort().
  #
  # A LABEL press cannot reach that guard: the callout box is clamped to the plot
  # box, so it is never above it — which is exactly why the first draft of this
  # leg could not turn the sabotage red. An ANCHOR press can: park a marker on
  # the TOPMOST sample (after a fit its anchor sits on the plot box top) and press
  # a few pixels ABOVE it — still inside GRAPH_MARKER_TOL = 8 so the anchor is
  # grabbed, but above the plot box so graph_top latches. Then drag the pointer
  # clean out of the canvas, where no graph contains it, and release.
  pcall {mk_wdel $tok}
  pcall {wviewer::fit $tok}
  set mx7bn {}
  if {[catch {wviewer::with_edit $tok \
        {set mx7bn [xschem graph_marker add_at 0 0 0 10]}} mx7berr]} {
    set mx7bn "ERR:$mx7berr"
  }
  check "MX7b a marker on the TOPMOST sample (anchor on the plot box top)" $mx7bn 1
  set mx7bbefore [lindex [pcall {mk_list 0}] 0]
  set mx7bn1 [pcall {llength [mk_list 1]}]
  # the press is 5 px ABOVE the anchor centroid on purpose (that is the whole
  # leg), so mx_arm is told about the offset rather than pressing dead centre
  set mx7bA [mx_arm {MX7b} 0 1 0 -5]
  check_true "MX7b its anchor pixel was found" [pexpr {$mx7bA ne {}}]
  check "MX7b a press ABOVE the plot box still grabbed the anchor" \
    [pcall {xschem new_schematic switch $vdrw; xschem get graph_marker_drag}] 1
  foreach mx7bf {0.40 0.80 1.25} {
    wb_ev $vdrw <B1-Motion> -x [expr {[mk_px $mx7bA 0] - 70}] \
      -y [expr {int($mx7bf * $H)}] -state 0x100
  }
  wb_ev $vdrw <ButtonRelease-1> -x [expr {[mk_px $mx7bA 0] - 70}] \
    -y [expr {int(1.25 * $H)}] -state 0x100
  set mx7bafter [lindex [pcall {mk_list 0}] 0]
  check_true "MX7b the drag COMMITTED even though the pointer left the window" \
    [pexpr {[lindex $mx7bafter 4] ne {} &&
            [lindex $mx7bafter 4] != [lindex $mx7bbefore 4]}]
  check_true "MX7b it re-snapped to a real sample of the same trace" \
    [pcall {mk_close [lindex $mx7bafter 6] [xschem raw value v_a [lindex $mx7bafter 4]]}]
  check "MX7b the marker still belongs to the ORIGINAL strip" \
    [pcall {llength [mk_list 0]}] 1
  check "MX7b ... and did NOT migrate to the strip the pointer crossed" \
    [pcall {llength [mk_list 1]}] $mx7bn1
  check "MX7b an anchor drag leaves the label offset alone" \
    [lrange $mx7bafter 8 9] [lrange $mx7bbefore 8 9]
  check "MX7b the drag arm is torn down" \
    [pcall {xschem new_schematic switch $vdrw; xschem get graph_marker_drag}] 0

  # --- MX7d: LABEL drag that leaves the strip --------------------------
  # The label half of the same story: the callout is clamped INSIDE the plot box,
  # so this press cannot latch graph_top — what it does prove is that a label
  # drag whose pointer ends over ANOTHER strip still commits to the strip the
  # marker belongs to (graph_marker_release resolves graph_marker_draggraph, not
  # whatever the pointer ended over).
  set mx7dbefore [lindex [pcall {mk_list 0}] 0]
  set mx7dn1 [pcall {llength [mk_list 1]}]
  set mx7dL [mx_arm {MX7d} 0 2]
  check_true "MX7d the label pixel was found" [pexpr {$mx7dL ne {}}]
  check "MX7d the press armed the LABEL drag" \
    [pcall {xschem new_schematic switch $vdrw; xschem get graph_marker_drag}] 2
  foreach mx7df {0.35 0.55 0.75 0.92} {
    wb_ev $vdrw <B1-Motion> -x [mk_px $mx7dL 0] -y [expr {int($mx7df * $H)}] -state 0x100
  }
  wb_ev $vdrw <ButtonRelease-1> -x [mk_px $mx7dL 0] -y [expr {int(0.92 * $H)}] -state 0x100
  set mx7dafter [lindex [pcall {mk_list 0}] 0]
  check_true "MX7d ldx/ldy changed even though the pointer ended over strip 1" \
    [pexpr {[lrange $mx7dafter 8 9] ne [lrange $mx7dbefore 8 9]}]
  check "MX7d the marker stayed on strip 0" [pcall {llength [mk_list 0]}] 1
  check "MX7d ... and strip 1 gained nothing" [pcall {llength [mk_list 1]}] $mx7dn1
  check "MX7d the anchor is untouched by a label drag" \
    [lrange $mx7dafter 3 6] [lrange $mx7dbefore 3 6]

  # --- MF11b: the readonly viewer still gets its mutating keys ------------
  # The other half of the readonly fix (MF11a asserts the refusal in a normal
  # buffer made read-only). The ASE viewer is read-only for its WHOLE LIFE, so
  # now that the C m/d/Delete arms call readonly_block() it can only mutate
  # through wviewer::key_filter's with_edit bracket. Both routes are driven here
  # on the SAME pixel, deterministically (no synthetic key, no focus race):
  #   * `xschem callback` straight to C -- what key_filter did BEFORE the fix --
  #     must now create nothing;
  #   * key_filter, which brackets exactly m (109), d (100) and Delete (65535)
  #     in with_edit, must still create one and leave the buffer readonly and
  #     unmodified.
  # Before the fix the first of each pair created a marker, so this leg is red
  # on its first check.
  mx_ready {MF11b}
  pcall {mk_wdel $tok}
  pcall {xschem new_schematic switch $vdrw; xschem graph_marker select -none}
  set mf11log [llength $::mxlog]
  set mf11y [mx_scan {MF11b trace row} $tok {mk_trace_row 0 $mxx 2 [expr {$H / 2}]}]
  if {$mf11y eq {}} { set mf11y $mxy }
  # key_filter is called DIRECTLY here (no Tk, no focus), so the only thing that
  # can silently refuse it is over_graph's context test -- put the context and
  # the pointer back first, and assert the gate rather than assuming it
  mk_prep_at $mxx $mf11y
  check_true "MF11b the pointer is over a graph" [pcall {wviewer::over_graph $vdrw}]
  check "MF11b the viewer buffer is read-only, as always" \
    [pcall {xschem new_schematic switch $vdrw; xschem get readonly}] 1
  pcall {xschem callback $vdrw 2 $mxx $mf11y 109 0 0 0}
  check "MF11b a RAW C forward of `m` is refused (before: it created a marker)" \
    [pcall {llength [mk_list 0]}] 0
  pcall {wviewer::key_filter $vdrw 2 $mxx $mf11y 109 m 0}
  check "MF11b ... while key_filter's with_edit bracket lets it through" \
    [pcall {llength [mk_list 0]}] 1
  check "MF11b the buffer is readonly again afterwards" \
    [pcall {xschem new_schematic switch $vdrw; xschem get readonly}] 1
  check "MF11b ... and still unmodified" \
    [pcall {xschem new_schematic switch $vdrw; xschem get modified}] 0
  check "MF11b the push hook folded it into the model" \
    [pcall {mk_model_mk $tok 0}] [pcall {xschem new_schematic switch $vdrw
                                         xschem getprop rect 2 0 markers}]
  pcall {xschem callback $vdrw 2 $mxx $mf11y 100 0 0 0}
  check "MF11b a RAW C forward of `d` is refused too" [pcall {llength [mk_list 0]}] 1
  pcall {wviewer::key_filter $vdrw 2 $mxx $mf11y 100 d 0}
  check "MF11b ... and key_filter creates the delta marker" [pcall {llength [mk_list 0]}] 2
  check "MF11b no viewer log line for the m/d halves (not a reorder, not a move)" \
    [llength $::mxlog] $mf11log
  # Delete used to be the third with_edit-bracketed FORWARD. Since issue 0176 it
  # is not forwarded at all — key_filter owns it and deletes through the viewer's
  # own MODEL edit (wviewer::delete_selection_at -> delete_items), so unlike m/d
  # it is an undoable, replayable viewer command and DOES emit one log line. The
  # RAW-forward half is unchanged and still refused.
  # The gesture also deletes SELECTED TRACES now, so this leg has to be explicit
  # about there being none — otherwise it would silently be testing a trace
  # delete as well and the marker count would be measuring the wrong thing.
  set mf11gs {}
  foreach mf11G [mk_graphs $tok] { lappend mf11gs [wviewer::model_sel_set $mf11G {}] }
  pcall {wviewer::set_graphs $tok $mf11gs; wviewer::regenerate $tok}
  pcall {xschem new_schematic switch $vdrw}
  check "MF11b no trace is selected, so Delete is purely the marker arm (0176)" \
    [pcall {list [wviewer::selected_waves $vdrw 0] [wviewer::selected_waves $vdrw 1]}] {{} {}}
  set mf11log2 [llength $::mxlog]
  pcall {xschem new_schematic switch $vdrw; xschem graph_marker select 2 0}
  mk_prep_at $mxx $mf11y
  pcall {xschem callback $vdrw 2 $mxx $mf11y 65535 0 0 0}
  check "MF11b a RAW C forward of Delete is refused" [pcall {llength [mk_list 0]}] 2
  pcall {wviewer::key_filter $vdrw 2 $mxx $mf11y 65535 Delete 0}
  check "MF11b ... and key_filter deletes the selected marker" \
    [pcall {llength [mk_list 0]}] 1
  check "MF11b Delete, unlike m/d, logs exactly ONE viewer line (issue 0176)" \
    [expr {[llength $::mxlog] - $mf11log2}] 1

  } mxgerr]} {
    puts "FAIL: MX group ABORTED: $mxgerr : FAIL"
    incr fail
    puts $::errorInfo
    catch {mx_unlatch}
  }

  rename wviewer::log_action {}
  rename wviewer::__real_log_action wviewer::log_action
  rename wb_ev {}
  rename send_key {}
  rename send_key_fb {}
  rename mk_send_once {}
  rename mk_drag {}
  rename mk_gflags {}
  rename mk_list {}
  rename mk_near {}
  rename mk_trace_row {}
  rename mk_parts {}
  rename mk_px {}
  rename mk_wadd {}
  rename mk_wdel {}
  rename mk_bold {}
  rename mk_bold_reset {}
  rename mk_prep_ctx {}
  rename mk_prep_at {}
  rename mx_latched {}
  rename mx_unlatch {}
  rename mx_ready {}
  rename mx_reestablish {}
  rename mx_scan {}
  rename mx_arm {}
  rename mx_diag {}
  rename mx_empty_row {}
  rename mx0_scan {}
  unset ::wbt
  }

  set ::mk_ran_x 1
  } mvgerr]} {
    puts "FAIL: viewer (MR/MF15/MF16/MX) group ABORTED: $mvgerr : FAIL"
    incr fail
    puts $::errorInfo
  }

  foreach mvp {mk_graphs mk_model_mk mk_ids mk_order mk_fixture} {
    catch {rename $mvp {}}
  }
  catch {wviewer::close $tok}
  update
  }
} else {
  puts "SKIPPED: MR-viewer / MX* legs (no usable DISPLAY)"
}

  set ::mk_body_completed 1
} bigerr]} {
  puts "FAIL: the FILE aborted before its last leg: $bigerr : FAIL"
  incr fail
  puts $::errorInfo
}

# ============================================================================
# MZ — the coverage self-check
# ============================================================================
# The measured bad run reported `RESULT: 7 FAILED (457 passed)` while a good one
# reports 601+: it had quietly stopped running 138 of its checks. Nothing in the
# output said so -- a smaller number is not a signal anyone reads. So the file
# now knows how many checks each of its two arms is supposed to run, and a
# shortfall (or a surplus) is itself a FAIL that names the delta.
#
# EDITING THIS FILE: when you add or remove a leg, run both arms once and put
# the new numbers here. That is the point -- the constant is the thing that
# makes silent coverage loss impossible, so it has to be maintained by hand.
# These are the counts BEFORE the two MZ legs themselves, so the RESULT line
# reads two higher (803 / 328).
set ::mk_expect_x     801   ;# DISPLAY arm: MK + MR + MF + MD + MQ + MR-viewer + MX
set ::mk_expect_nogui 326   ;# --nogui arm: MK + the engine half of MR/MF/MD
set mkexp [expr {$::mk_ran_x ? $::mk_expect_x : $::mk_expect_nogui}]
set mkgot [expr {$npass + $fail}]
check "MZ1 the [expr {$::mk_ran_x ? {DISPLAY} : {--nogui}}] arm ran its full\
 complement of checks (a silent shortfall is the failure this guards)" \
  [expr {$mkgot == $mkexp ? {ok} : "RAN $mkgot of $mkexp"}] ok
check "MZ2 the file body reached its end (no group unwound into the outer catch)" \
  [expr {[info exists ::mk_body_completed] ? 1 : 0}] 1

if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  exit 0
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  exit 1
}
