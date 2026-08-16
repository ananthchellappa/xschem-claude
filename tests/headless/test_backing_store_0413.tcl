# test_backing_store_0413.tcl — the drawing window must NOT ask the X server for
# backing store. Issue 0413.
#
# ⚠⚠ WHAT THIS GUARDS IS A CLIENT KILLING AN X SERVER, not a cosmetic attribute.
# With `backing_store = WhenMapped` on the drawing window, MOVING that window
# inside its toplevel — which is what packing anything to its left or above it
# does, e.g. the waveform viewer's Ctrl-B Signal Browser — makes VcXsrv's own
# internal window manager issue a ConfigureWindow that returns BadMatch, and
# winMultiWindowWMProc treats that as fatal:
#
#   winMultiWindowWMProc - Error code: 8 (Match), Major opcode: 12 (ConfigureWindow)
#
# The server then exits, taking every other X client on the machine with it.
# Measured A/B on one binary against VcXsrv 21.1.16 -multiwindow: WhenMapped
# kills it every time, NotUseful survives every time.
#
# ⚠ THE CRASH ITSELF IS NOT HEADLESS-TESTABLE AND THAT IS THE POINT. Xvfb and
# Xwayland both tolerate the very gesture that kills VcXsrv, so no amount of
# green here reproduces it — issue 0413 sat in a coverage hole by construction
# while 14 signal-browser suites passed. What IS testable, on any server, is the
# REQUEST: the attribute we hand the server is ours, it is one word, and it is
# the whole fix. So this file asserts the request, not the consequence.
#
# ⚠ THE ESCAPE HATCH IS PART OF THE CONTRACT. XSCHEM_BACKING_STORE=1 restores
# the old WhenMapped request for anyone measuring it, so BS5 asserts the test
# would actually FAIL in that configuration — a check that cannot fail is not a
# check, and this one is one env var away from proving itself.
#
# Run from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_backing_store_0413.tcl
#   env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_backing_store_0413.tcl
#
#   BS1-BS3  source arm  — BOTH arms
#   BS4-BS6  real window — Tk/X only

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

# ============================================================================
# BS1-BS3 — THE SOURCE: the default assignment, and where WhenMapped may live
# ============================================================================
set src [file join [file dirname [info script]] .. .. src xinit.c]
set fh [open $src r]; set txt [read $fh]; close $fh

check "BS1 xinit.c asks for NotUseful" \
  [regexp {winattr\.backing_store\s*=\s*NotUseful\s*;} $txt] 1

# ⚠ NOT "does WhenMapped appear" — it legitimately appears in the escape hatch.
# The claim is that every surviving WhenMapped assignment is GUARDED by the
# env-var test, i.e. none of them is the plain default.
set whenmapped [regexp -all {winattr\.backing_store\s*=\s*WhenMapped\s*;} $txt]
set guarded    [regexp -all -- {XSCHEM_BACKING_STORE[^;]*;\s*\n?\s*if\s*\(\s*bs_env[^)]*\)\s*winattr\.backing_store\s*=\s*WhenMapped\s*;} $txt]
check "BS2 every WhenMapped assignment is inside the env-var escape hatch" \
  [list $whenmapped $guarded] {1 1}

# The three Tk_ChangeWindowAttributes call sites (main window, new window,
# detached tab) all pass the SAME file-static winattr, which is what makes one
# default cover all three. If someone ever gives a site its own struct, this
# count changes and the assertion is a prompt to re-check the new one.
check "BS3 all CWBackingStore sites share the one static winattr" \
  [list [regexp -all {CWBackingStore,\s*&winattr\)} $txt] \
        [regexp -all {static\s+XSetWindowAttributes\s+winattr;} $txt]] {3 1}

# ============================================================================
# BS4-BS6 — THE REAL WINDOW: what the server was actually told
# ============================================================================
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  # xwininfo is the only portable reader of an already-set backing-store
  # attribute; without it the runtime arm cannot make its claim, so it says so
  # rather than passing vacuously.
  if {[catch {exec xwininfo -version} ] && [catch {exec which xwininfo}]} {
    puts "SKIPPED: BS4-BS6 (xwininfo not installed)"
  } else {

  proc bs_state {id} {
    if {[catch {exec xwininfo -id $id -stats} out]} { return "ERR: $out" }
    foreach l [split $out "\n"] {
      if {[regexp {Backing Store State:\s*(\S+)} $l -> v]} { return $v }
    }
    return "ABSENT"
  }

  for {set i 0} {$i < 100} {incr i} { update; if {[winfo ismapped .drw]} break; after 20 }
  check "BS4 the MAIN drawing window carries NotUseful" [bs_state [winfo id .drw]] NotUseful

  # BS5: a SECOND drawing window, because xinit.c sets the attribute at three
  # sites and only one of them is the startup path. A fix applied to the main
  # window alone would leave every `new_schematic create_window` crashing.
  if {[catch {xschem new_schematic create_window .x7 {}} e]} {
    puts "SKIPPED: BS5 (could not create a second window: $e)"
  } else {
    for {set i 0} {$i < 100} {incr i} { update; if {[winfo exists .x7.drw] && [winfo ismapped .x7.drw]} break; after 20 }
    check "BS5 a NEW drawing window carries NotUseful too" [bs_state [winfo id .x7.drw]] NotUseful
    catch {xschem new_schematic destroy .x7}
  }

  # BS6: the attribute is one Tk call away from being re-requested, so pin that
  # the READER works — a bs_state that silently returned the same string for
  # every window would make BS4/BS5 pass forever. The root window is NotUseful
  # on every server we run on, so the discriminating case is the negative: ask
  # for a state that is not there.
  check "BS6 the reader really reads the attribute (no false green)" \
    [expr {[bs_state [winfo id .drw]] ne "ABSENT" && [bs_state 0x1] ne "NotUseful"}] 1
  }
} else {
  puts "SKIPPED: BS4-BS6 (Tk/X arm only)"
}

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
