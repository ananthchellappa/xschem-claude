# tests/headless/test_wave_sigbrowser_0315.tcl — issue 0315, RULING (1) + (3).
#
# ============================================================================
# WHAT IS UNDER TEST
# ============================================================================
# One `Show in Signal Browser` gesture used to write the SAME sentence to the
# CIW twice — once by `wviewer::browser_say` (unprefixed) and once by
# `ase::show_in_browser_for_current` step 6 (`ase: ` prefixed) — and on the
# fall-through the viewer's copy was tagged `error`, i.e. RED, for a gesture
# whose eyeball verdict is PASS. The user's ruling, taken 2026-08-12, is
# candidates (1) AND (3) of the issue:
#
#   (1) THE ASE COMMAND OWNS THE CIW ACCOUNT of its own gesture. `browser_say`
#       keeps its sidebar status-line write on every branch and skips the CIW
#       echo when an ASE command is driving it. A caller that is NOT an ASE
#       command still gets the viewer's own line.
#   (3) A LANDING THAT FELL THROUGH IS NOT AN ERROR. The `err` that
#       `ase.tcl`'s last-mile retry recovers from must not paint a red line.
#
# The mechanism is a ONE-SHOT per-token flag, `wviewer::sayquiet($token)`:
# `wviewer::browser_say_quiet` arms it, `browser_say_quiet_consume` reads and
# unsets it, and `ase.tcl` arms before each of its three viewer calls.
#
# ⚠ A FLAG AND NOT AN ARGUMENT, AND THAT IS FORCED — the note in
# `src/wave_viewer.tcl` beside the array says why: `test_ase_cosim.tcl` and
# `test_wave_sigbrowser_i12.tcl` both STUB `browser_show_path` /
# `browser_show_db_scope` with their shipped 2-argument arity, so a third
# positional argument passed by `ase.tcl` would red two files for a reason
# unrelated to what they test. BE13 pins that arity so the next person who
# reaches for an argument finds out here.
#
# ============================================================================
# WHAT THIS FILE DOES NOT MEASURE — READ BEFORE TRUSTING IT
# ============================================================================
# The a1/a9 CIW LOG ITSELF is not re-measured here — the reported symptom lives
# in `/tmp/Xschem.log.<N>` after a real Ctrl-Alt-V on the eyeball fixture
# (`/tmp/xschem_eyeball_F/tcl/s4_item5.tcl`), which needs a real session, a real
# selection and a loaded raw, so the verdict on the LOG wants an eyeball.
#
# Everything short of that is driven. BE2x exercise the viewer half on a real
# browser with the real resolver; BE31-BE34 drive
# `ase::show_in_browser_for_current` ITSELF, with only the five design-side reads
# stubbed (the `fd_drive_on` idiom from `test_wave_sigbrowser_digital.tcl`), so
# the ase-prefixed lines that are now the gesture's ONLY account are asserted
# verbatim and the arms are checked at RUN TIME (BE34) rather than by source
# offset. The first version of this file asserted neither, and review measured
# five live defects it stayed green on — see the sabotage table's S20-S25.
#
# ============================================================================
# SABOTAGE TABLE — 28 mutations, each applied to src/, whole file re-run,
# reverted from a byte copy. MEASURED on the FINAL code, not predicted.
#
# ⚠⚠ NINE OF THESE ROWS (S20-S28) AND FOUR CHECKS (BE14 BE15 BE16 BE31-BE34)
# EXIST BECAUSE TWO ADVERSARIAL REVIEWS BROKE THE FIRST VERSION OF THIS FILE.
# The first version was 21/21 green with 19 rows and every one of the following
# defects would have shipped: a constant token in the consume, the two echo arms
# SWAPPED (ruling 3 backwards), the guard's `!` dropped, a fourth UNARMED viewer
# call, and `ase.tcl`'s echo pair DELETED — which is the mirror-image defect, a
# gesture that writes nothing at all. Rows S20-S25 are those five.
# ============================================================================
#  #   mutation                                                    reds (measured)
# --- ruling (1): the suppression exists and is consumed ----------------------
#  S1  browser_say: `![...consume $token]` -> `1` (echo always,     BE07 BE08 BE23
#      i.e. revert the ruling and keep everything else)             BE24 BE25 BE26
#                                                                   BE31 BE33
#  S2  browser_say_quiet: the arm becomes an unset (no-op)          BE02 BE04 BE06
#                                                                   BE23 BE24 BE25
#                                                                   BE26 BE27 BE31
#                                                                   BE33
#  S3  consume: return 1 WITHOUT unsetting (not one-shot)           BE02 BE06 BE25
#  S4  consume: unset + `return 1` always (silence everything)      BE02 BE03 BE04
#                                                                   BE05 BE06 BE21
#                                                                   BE22 BE25
#  S5  consume: unset + `return 0` always (silence nothing)         BE02 BE04 BE06
#                                                                   BE23 BE24 BE25
#                                                                   BE26 BE31 BE33
#  S6  browser_say_quiet: drop the `else` arm (ignore `on 0`)       BE03
#  S7  sayquiet keyed by the constant `ONE` in the ACCESSORS        BE03 BE04 BE27
# --- ruling (1): the status line is NOT suppressed with the echo -------------
#  S8  browser_say: move `browser_status` INSIDE the guard          BE08 BE23 BE24
# --- ruling (1): conditional, NOT deleted (the viewer keeps its arm) ---------
#  S9  browser_say: delete the unarmed `else` echo arm              BE07 BE14 BE21
#                                                                   BE25
# S10  browser_say: collapse both arms to the untagged one          BE07 BE14 BE22
# --- ruling (3) + the arming, in ase.tcl ------------------------------------
# S11  ase.tcl: delete the arm before the last-mile RETRY           BE09 BE10 BE16
#                                                                   BE31 BE34
# S12  ase.tcl: delete the arm before the FIRST show_path           BE09 BE10 BE16
#                                                                   BE31 BE33 BE34
# S13  ase.tcl: delete the arm before show_db_scope                 BE09 BE10 BE16
# S14  ase.tcl: replace all three arms with ONE at the top of       BE09 BE10 BE16
#      step 6 — the shape the one-shot flag makes wrong             BE31 BE33 BE34
# S15  ase.tcl: delete the TAIL disarm                             BE09 BE10 BE34
# S27  ase.tcl: delete the ENTRY disarm (review finding 1's guard)  BE09 BE10 BE34
# --- teardown ---------------------------------------------------------------
# S16  forget: delete `catch {unset sayquiet($token)}`              BE12 BE27
# S17  forget: drop the `variable sayquiet` declaration only        BE12 BE27
#      (the local-array leak this file's siblings document)
# --- the arity the flag exists to protect ----------------------------------
# S18  wave_viewer.tcl: browser_show_path gains a 3rd parameter     BE13
# S19  ase.tcl PASSES a 3rd argument — the design §2 of the receipt BE10 BE11 BE31
#      calls forced. On the FIRST version of this file this was an   BE32 BE33 BE34
#      honest HOLE (21/21 green, and it reddened `test_ase_cosim`
#      5x and `test_wave_sigbrowser_i12` 8x instead, one of them
#      `wrong # args: should be "wviewer::browser_show_path token
#      path"`). BE10/BE11 now pin the call text to its closing
#      brackets, so this file sees it too. HOLE CLOSED.
# --- the five defects the reviews found alive under a green suite ------------
# S20  the consume reads a CONSTANT token (`… _consume ONE`)        BE07 BE23 BE24
#      — one window's arm silences another's, forever               BE25 BE26 BE31
#                                                                   BE33
# S21  the two echo arms SWAPPED: success painted red, failure      BE14 BE21 BE22
#      painted plain — ruling (3) applied backwards                  BE25
# S22  the guard's `!` dropped: echo ONLY when armed — the          BE07 BE21 BE22
#      inverse of BOTH rulings                                       BE23 BE24 BE25
#                                                                   BE26 BE31 BE33
# S23  a FOURTH, UNARMED `browser_show_path $key {}` in ase.tcl     BE16 BE31 BE33
#      — the duplicate-plus-red line restored on that path           BE34
# S24  = S19 (same mutation, kept as one row)                       see S19
# S25  ase.tcl's own echo of the final result DELETED — i.e.        BE31 BE32 BE33
#      candidate (2) on top of (1): a SILENT navigation, which is
#      the mirror-image defect of the one being fixed
# --- the invariant the one-shot design rests on -----------------------------
# S26  a bare `return {}` added to browser_show_path (so a say      BE15
#      can be skipped and the flag left armed)
# S28  browser_status's `-text` write deleted (the compensating     BE23 BE24
#      surface removed while the CIW echo stays suppressed)
# ============================================================================

set ::wvbs_tag  wvsigbrowser_0315
set ::wvbs_name test_wave_sigbrowser_0315
source [file join [file dirname [info script]] wvbs_common.tcl]

set asrc {}
catch {
  set fh [open [file join $repo src ase.tcl] r]
  set asrc [read $fh]
  close $fh
}

# ---------------------------------------------------------------------------
# BE0x — THE FLAG, PURE. No Tk, no browser: these run on every arm.
# ---------------------------------------------------------------------------
check {BE01 both halves of the one-shot flag exist} \
  [list [expr {[info commands ::wviewer::browser_say_quiet] ne {}}] \
        [expr {[info commands ::wviewer::browser_say_quiet_consume] ne {}}]] {1 1}

# ⚠ THE ONE-SHOT CLAIM, and it is the whole reason `ase.tcl` arms three times
# instead of once. Leg 2 is what a non-consuming read would pass.
check {BE02 arm -> consume 1, then 0: the flag is ONE-SHOT} \
  [list [pcall ::wviewer::browser_say_quiet be_t1] \
        [pcall ::wviewer::browser_say_quiet_consume be_t1] \
        [pcall ::wviewer::browser_say_quiet_consume be_t1]] {1 1 0}

check {BE03 the `on 0` disarm clears an armed flag} \
  [list [pcall ::wviewer::browser_say_quiet be_t1] \
        [pcall ::wviewer::browser_say_quiet be_t1 0] \
        [pcall ::wviewer::browser_say_quiet_consume be_t1]] {1 0 0}

# ⚠ PER TOKEN, and the second leg is the discriminator: a flag keyed by anything
# but the token would let one window's gesture silence another window's.
check {BE04 arming one token does not silence another} \
  [list [pcall ::wviewer::browser_say_quiet be_tA] \
        [pcall ::wviewer::browser_say_quiet_consume be_tB] \
        [pcall ::wviewer::browser_say_quiet_consume be_tA]] {1 0 1}

# ⚠ CONSUMING A TOKEN THAT WAS NEVER ARMED MUST NOT CREATE THE ENTRY. A
# read-then-write consume would leave one array entry per unarmed say — a leak
# with no owner, since `forget` only runs on a closed window.
catch {array unset ::wviewer::sayquiet be_tC}
set be_before [llength [array names ::wviewer::sayquiet]]
set be_unarmed [pcall ::wviewer::browser_say_quiet_consume be_tC]
check {BE05 an unarmed consume answers 0 and creates no array entry} \
  [list $be_unarmed [expr {[llength [array names ::wviewer::sayquiet]] - $be_before}] \
        [info exists ::wviewer::sayquiet(be_tC)]] {0 0 0}

check {BE06 two arms with no say between them are ONE arm (no stacking)} \
  [list [pcall ::wviewer::browser_say_quiet be_t2] \
        [pcall ::wviewer::browser_say_quiet be_t2] \
        [pcall ::wviewer::browser_say_quiet_consume be_t2] \
        [pcall ::wviewer::browser_say_quiet_consume be_t2]] {1 1 1 0}
catch {array unset ::wviewer::sayquiet be_t*}
catch {array unset ::wviewer::sayquiet be_tA}
catch {array unset ::wviewer::sayquiet be_tB}

# ---------------------------------------------------------------------------
# BE07-BE13 — SOURCE. The shape the rulings name, where a behavioural check
# cannot see it: that the echo was made CONDITIONAL rather than deleted, that
# the status line stayed out of the condition, and that ase.tcl arms per call.
# ---------------------------------------------------------------------------
set be_say [wvproc_body $wsrc wviewer::browser_say]

# ⚠ BOTH ARMS ALIVE. Ruling (1) is "the ASE command owns the account", NOT "the
# viewer stops reporting": deleting either arm passes every behavioural check
# that only ever drives the armed path, which is why the count is pinned here.
# Leg 3 is the guard itself — exactly one consume, so the echo cannot be
# suppressed twice or read a flag it does not clear.
#
# ⚠⚠ LEGS 3 AND 4 EXIST BECAUSE REVIEW MEASURED THE WEAKER FORM GOING GREEN ON A
# LIVE DEFECT. `regexp -all {browser_say_quiet_consume}` == 1 also passes for
# `browser_say_quiet_consume ONE` — a constant token, i.e. one window's arm
# silencing another's and the gesture keeping its duplicate forever (13/13 green
# headless). And the polarity is not implied by the count: dropping the `!` makes
# the echo fire ONLY when armed, the exact inverse of both rulings, also 13/13
# green headless. Both are pinned as EXACT TEXT, which is the only thing a source
# check can do about them on an arm with no X.
check {BE07 (SOURCE) browser_say keeps BOTH echo arms and gates them on ONE consume,
       with the token and the polarity pinned as text} \
  [list [regexp -all {wviewer::echo "signal browser:} $be_say] \
        [regexp -all {error} $be_say] \
        [regexp -all {browser_say_quiet_consume \$token} $be_say] \
        [regexp -all \
          {if \{!\[wviewer::browser_say_quiet_consume \$token\]\} \{} $be_say]] {2 1 1 1}

# ⚠⚠ WHICH ARM CARRIES THE TAG, NOT HOW MANY TAGS THERE ARE. Review swapped the
# two echo arms — every successful landing painted red, every failure painted
# plain, ruling (3) applied backwards — and BE07 stayed green because the count of
# `error` is 1 either way. The order of the three substrings is what says the
# `err` branch is the tagged one.
set be_i_err  [string first "\[lindex \$r 0\] eq \{err\}" $be_say]
set be_i_tag  [string first "signal browser: \$m\" error" $be_say]
set be_i_flat [string first "signal browser: \$m\"\}" $be_say]
check {BE14 (SOURCE) the `error` tag is on the `err` arm and the other arm is plain} \
  [list [expr {$be_i_err >= 0 && $be_i_err < $be_i_tag}] \
        [expr {$be_i_tag >= 0 && $be_i_tag < $be_i_flat}]] {1 1}

# ⚠⚠ THE INVARIANT THE ONE-SHOT FLAG RESTS ON, AND IT WAS HAND-COUNTED WRONG
# ONCE ALREADY (the source comment said 10 for the second proc; it is 11).
# An armed flag is consumed exactly once only because EVERY return in both entry
# points is `return [wviewer::browser_say …]`. A future early `return {}` leaves
# it armed; a path that says TWICE leaves the second say unsuppressed. Nothing
# else in the tree pins this.
set be_sp_body [wvproc_body $wsrc wviewer::browser_show_path]
set be_db_body [wvproc_body $wsrc wviewer::browser_show_db_scope]
proc be_returns {b} {
  return [list [regexp -all {return \[wviewer::browser_say} $b] \
               [regexp -all {\mreturn\M} $b]]
}
check {BE15 (SOURCE) every return in BOTH entry points is a browser_say — no bare return} \
  [list [be_returns $be_sp_body] [be_returns $be_db_body]] {{8 8} {11 11}}

# ⚠ THE STATUS LINE IS DECISION 4's SURFACE AND NOBODY RULED IT AWAY. The
# one-line temptation is to wrap the whole tail in the guard; this says the
# status write happens BEFORE the guard is even read.
check {BE08 (SOURCE) browser_status is written OUTSIDE the suppression guard} \
  [expr {[string first {browser_status} $be_say] >= 0 &&
         [string first {browser_status} $be_say] <
         [string first {browser_say_quiet_consume} $be_say]}] 1

set be_fv [wvproc_body $asrc ase::show_in_browser_for_current]
# ⚠ TWO DISARMS, AND THE SECOND ONE IS A REVIEW FINDING. The three viewer calls
# are unguarded, so an error between an arm and its say skips the TAIL disarm and
# leaves the flag armed; Tcl 8.4 is a target so there is no `finally`. Clearing on
# ENTRY is what stops that leak reaching anything — the next reader of the flag is
# this gesture's own first arm. BE10 pins which disarm is which.
check {BE09 (SOURCE) ase.tcl arms once per viewer call, and disarms on entry AND at the tail} \
  [list [regexp -all {browser_say_quiet \$key\}} $be_fv] \
        [regexp -all {browser_say_quiet \$key 0\}} $be_fv]] {3 2}

# ⚠⚠ THE ORDER, AND THIS IS THE CHECK S14 EXISTS FOR. Three arms at the top of
# step 6 would count three in BE09 and silence only the FIRST call, because the
# flag is one-shot. Each arm has to sit immediately before the call it is for,
# and the disarm after all of them.
set be_arm1 [string first "browser_say_quiet \$key\}" $be_fv]
#
# ⚠ THE CALL TEXT IS PINNED TO ITS CLOSING BRACKETS, not to a prefix. With a
# prefix (`… [join $segs`) an APPENDED THIRD ARGUMENT is invisible here, and that
# is precisely the design S19 shows reds two other suites — so this file should
# see it too rather than leaving the whole protection off-file.
set be_db   [string first {browser_show_db_scope $key [lindex $dig 1] [lindex $dig 2]]} $be_fv]
set be_sp1  [string first {browser_show_path $key [join $segs .]]} $be_fv]
set be_sp2  [string first {browser_show_path $key [join $base .]]} $be_fv]
set be_on0  [string first "browser_say_quiet \$key 0\}" $be_fv]
set be_off  [string last  "browser_say_quiet \$key 0\}" $be_fv]
set be_arm2 [string first "browser_say_quiet \$key\}" $be_fv [expr {$be_db + 1}]]
set be_arm3 [string first "browser_say_quiet \$key\}" $be_fv [expr {$be_sp1 + 1}]]
check {BE10 (SOURCE) entry disarm, then an arm before each call it is for, then the tail disarm} \
  [list [expr {$be_on0 >= 0 && $be_on0 < $be_arm1}] \
        [expr {$be_arm1 >= 0 && $be_arm1 < $be_db}] \
        [expr {$be_arm2 >= 0 && $be_arm2 < $be_sp1}] \
        [expr {$be_arm3 >= 0 && $be_arm3 < $be_sp2}] \
        [expr {$be_off  >  $be_sp2}]] {1 1 1 1 1}

check {BE11 (SOURCE) the three viewer calls this ruling covers are all still there} \
  [list [expr {$be_db > 0}] [expr {$be_sp1 > 0}] [expr {$be_sp2 > $be_sp1}]] {1 1 1}

# ⚠⚠ THE ARM COUNT BOUNDS NOTHING ON ITS OWN, AND REVIEW PROVED IT: a FOURTH,
# UNARMED `browser_show_path $key {}` added just before step 6's echo left all
# thirteen source checks green and restored the duplicate-plus-red line on that
# path. What has to match is CALLS to ARMS. BE34 is the runtime twin of this.
set be_ncalls [expr {[regexp -all {browser_show_path \$key} $be_fv] +
                     [regexp -all {browser_show_db_scope \$key} $be_fv]}]
check {BE16 (SOURCE) the number of viewer CALLS equals the number of arms} \
  [list $be_ncalls [regexp -all {browser_say_quiet \$key\}} $be_fv]] {3 3}

# ⚠ THE TEARDOWN, BY SOURCE AND BY BEHAVIOUR (BE27). Both legs are needed: an
# unset without the `variable` declaration addresses a LOCAL array, fails, and
# is swallowed by its own catch — the exact leak this file's siblings document
# for `gridshow`, `dest` and `browserwidth`.
set be_forget [wvproc_body $wsrc wviewer::forget]
check {BE12 (SOURCE) forget both DECLARES and unsets sayquiet} \
  [list [regexp -all {variable sayquiet} $be_forget] \
        [regexp -all {unset sayquiet\(\$token\)} $be_forget]] {1 1}

# ⚠⚠ THE ARITY THE FLAG EXISTS TO PROTECT. Two suites stub these two procs with
# two/three arguments; if `ase.tcl` ever passes an extra positional the stubs
# throw and those files red for an unrelated reason. Pinned HERE so the reason
# is findable from the file that made the choice.
check {BE13 (SOURCE) both viewer entry points keep their shipped arity} \
  [list [expr {[string first "proc wviewer::browser_show_path \{token path\}" $wsrc] >= 0}] \
        [expr {[string first "proc wviewer::browser_show_db_scope \{token dbpath scope\}" $wsrc] >= 0}]] \
  {1 1}

# ---------------------------------------------------------------------------
# BE2x — THE SEAM, DRIVEN on a real browser with the real resolver (X only).
# ---------------------------------------------------------------------------
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  catch {destroy .wvbe1}
  toplevel .wvbe1
  wm title .wvbe1 {issue 0315 CIW-account fixture}
  wm geometry .wvbe1 900x400+60+60
  canvas .wvbe1.drw -background white -width 700 -height 360
  pack .wvbe1.drw -side right -fill both -expand true
  dict set ::wviewer::windows wvbe [dict create top .wvbe1 win_path .wvbe1.drw]
  pcall ::wviewer::browser_build wvbe .wvbe1
  set BEF .wvbe1.wvbrowser
  set BETV $BEF.pw.tvf.tv
  pack $BEF -side left -fill y -before .wvbe1.drw
  set be_mapped [bs_wait_mapped .wvbe1.drw]
  catch {bs_wait_mapped $BETV}
  update

  # the BX20 fixture idiom, verbatim in shape: seed the inventory and the tree
  # directly, so the resolver runs for real with no `xschem raw` behind it.
  proc be_seed {names} {
    global BETV
    set ::wviewer::browsersigs(wvbe) $names
    set e {}
    foreach n $names { lappend e [wviewer::signal_entry $n] }
    set r [wviewer::browser_rows $e]
    set ::wviewer::browserrows(wvbe) $r
    wviewer::browser_populate $BETV $r
    update
    return [llength $r]
  }

  # THE CAPTURE. `wviewer::echo` hands the pane half to `::ciw_echo` before it
  # does anything else, which is the hook every notice-capturing test in this
  # tree uses. Only the browser's own sentences are collected: a `signal
  # browser:` prefix filter keeps an unrelated echo from another subsystem out
  # of a count that is the whole evidence.
  # ⚠⚠ TWO LISTS, AND THE SECOND ONE IS A REVIEW FINDING. A filter that kept only
  # `signal browser:` discarded every `ase: ` line — so the line that this ruling
  # makes the gesture's SOLE CIW account was asserted by nothing, here or anywhere
  # in the tree (`grep -rn "ase: signal browser" tests/` was empty). Deleting
  # ase.tcl's echo pair on top of this change would then be a SILENT navigation,
  # the mirror-image defect, with every check green. BE31/BE32/BE33 read this list.
  if {[info commands ::ciw_echo] ne {}} { rename ::ciw_echo ::be_saved_ciw_echo }
  proc ::ciw_echo {msg {tag {}}} {
    if {[string first {ase: signal browser:} $msg] == 0} {
      lappend ::be_ase [list $tag $msg]
    } elseif {[string first {signal browser:} $msg] == 0} {
      lappend ::be_echoed [list $tag $msg]
    }
    if {[info commands ::be_saved_ciw_echo] ne {}} {
      catch {::be_saved_ciw_echo $msg $tag}
    }
  }
  proc be_reset {} { set ::be_echoed {} ; set ::be_ase {} }
  proc be_lines {} { return $::be_echoed }
  proc be_aselines {} { return $::be_ase }
  proc be_ntag {t} {
    set n 0
    foreach e [concat $::be_echoed $::be_ase] { if {[lindex $e 0] eq $t} { incr n } }
    return $n
  }
  # the sidebar status line, as the user reads it (browser_status writes
  # "Signal Browser\n<msg>"), or {} when the label is not there
  proc be_status {} {
    if {[catch {.wvbe1.wvbrowser.ph cget -text} r]} { return {} }
    return [lindex [split $r "\n"] end]
  }
  be_reset

  set be_names {v(x1.x2.net5) v(x1.y3.net7) v(out)}
  check {BE20 (FIXTURE) the sidebar built, is mapped, the tree is seeded, capture is live} \
    [list $be_mapped [winfo exists $BETV] [expr {[be_seed $be_names] > 0}] \
          [expr {[info commands ::ciw_echo] ne {}}]] {1 1 1 1}

  # ⚠⚠ POSITIVE CONTROL, AND WITHOUT IT EVERY "no line" CLAIM BELOW IS
  # WORTHLESS: prove this very call DOES echo exactly one line when nothing
  # armed the flag. That arm is the viewer's own contract, which ruling (1)
  # keeps.
  be_reset
  set be_ok [pcall ::wviewer::browser_show_path wvbe x1.x2]
  check {BE21 (POSITIVE CONTROL) UNARMED, the viewer echoes its own ONE line, untagged} \
    [list $be_ok [llength [be_lines]] [lindex [be_lines] 0]] \
    [list {ok g:x1.x2 x1.x2} 1 {{} {signal browser: showing x1.x2}}]

  # ⚠ THE SHIPPED RED, on the same call shape ruling (3) is about. Unarmed it is
  # still red — that is the viewer reporting a navigation nobody recovered from.
  be_reset
  set be_err [pcall ::wviewer::browser_show_path wvbe z9.q1]
  check {BE22 (POSITIVE CONTROL) UNARMED, an err echoes ONE line tagged error} \
    [list $be_err [llength [be_lines]] [be_ntag error]] \
    [list {err {no signals under 'z9.q1'}} 1 1]

  # THE RULING, HALF (1): armed, the CIW gets nothing and the STATUS LINE still
  # gets the sentence. Both legs, because suppressing the status line too would
  # pass a check that only counted CIW lines.
  be_reset
  pcall ::wviewer::browser_say_quiet wvbe
  set be_ok2 [pcall ::wviewer::browser_show_path wvbe x1.x2]
  check {BE23 ARMED: no CIW line, same result, and the status line still says it} \
    [list $be_ok2 [llength [be_lines]] [be_status]] \
    [list {ok g:x1.x2 x1.x2} 0 {showing x1.x2}]

  # THE RULING, HALF (3): the fall-through `err` — the a9 shape — produces NO
  # red line. This is the exact line the issue exhibits as `#! signal browser:
  # no signals under 'a9'`.
  #
  # ⚠⚠ THE SENTINEL IS A REVIEW FINDING AND IT IS NOT TIDINESS. BE22 leaves the
  # IDENTICAL sentence on `.ph`, so without stamping the label first this check's
  # status leg passes on a stale write — it was discriminating only because BE23
  # happened to interpose a different sentence. `.ph` has ~20 writers; a sentinel
  # makes "the status line was written BY THIS CALL" the thing being read.
  be_reset
  catch {.wvbe1.wvbrowser.ph configure -text "Signal Browser\nBE24-SENTINEL"}
  pcall ::wviewer::browser_say_quiet wvbe
  set be_err2 [pcall ::wviewer::browser_show_path wvbe z9.q1]
  check {BE24 ARMED: the fall-through err is NOT reported and NOT red} \
    [list $be_err2 [llength [be_lines]] [be_ntag error] [be_status]] \
    [list {err {no signals under 'z9.q1'}} 0 0 {no signals under 'z9.q1'}]

  # ⚠ ONE-SHOT AT THE REAL SEAM, not just against the accessor: one arm covers
  # one say, and the NEXT navigation reports itself again.
  be_reset
  pcall ::wviewer::browser_say_quiet wvbe
  pcall ::wviewer::browser_show_path wvbe x1.x2
  set be_mid [llength [be_lines]]
  pcall ::wviewer::browser_show_path wvbe x1.y3
  check {BE25 one arm silences ONE say; the next navigation speaks again} \
    [list $be_mid [llength [be_lines]] [lindex [be_lines] 0]] \
    [list 0 1 {{} {signal browser: showing x1.y3}}]

  # ⚠⚠ THE a9 PAIR, IN THE ORDER ase.tcl ISSUES IT — arm, walk the extended path
  # (which fails), arm, walk the base path (which lands). What the log used to
  # get from the viewer for this gesture was two lines, one of them red; what it
  # gets now is nothing, and the account is `ase.tcl`'s two prefixed lines.
  #
  # ⚠ THIS REPLAYS THE PAIR, IT DOES NOT DRIVE `show_in_browser_for_current` —
  # that needs a session, a selection and a map. BE09/BE10 are what tie this
  # order to the shipped caller; see the header's "WHAT THIS FILE DOES NOT
  # MEASURE".
  be_reset
  pcall ::wviewer::browser_say_quiet wvbe
  set be_a9a [pcall ::wviewer::browser_show_path wvbe z9.q1]
  pcall ::wviewer::browser_say_quiet wvbe
  set be_a9b [pcall ::wviewer::browser_show_path wvbe x1.x2]
  check {BE26 the a9 fall-through pair writes ZERO viewer lines and ZERO red} \
    [list [lindex $be_a9a 0] [lindex $be_a9b 0] [llength [be_lines]] [be_ntag error]] \
    {err ok 0 0}

  # =========================================================================
  # BE30-BE34 — THE REAL COMMAND, DRIVEN. Review's finding: "we cannot drive
  # `ase::show_in_browser_for_current`" was FALSE — two precedents exist
  # (`fv_arm` in test_ase_cosim.tcl, `fd_drive_on` in
  # test_wave_sigbrowser_digital.tcl), and without a drive three real defects
  # stayed green: (a) deleting ase.tcl's echo pair leaves the gesture SILENT,
  # (b) a FOURTH, UNARMED viewer call restores the duplicate-plus-red line,
  # (c) the arms' source ORDER is not their runtime order.
  #
  # Only the five DESIGN-side reads are stubbed — the same five `fd_drive_on`
  # stubs, and for the same reason: this fixture has no schematic and no session.
  # Steps 6, 6b, 6c and 7 are the shipped code, running against the real
  # treeview and the real resolver.
  # =========================================================================
  proc be_drive_on {} {
    foreach p {::ase::session_for_current ::wviewer::hier_now \
               ::ase::browser_sel_segment ::wviewer::browser_origin_drop \
               ::ase::browser_digital_probe ::wviewer::open \
               ::wviewer::browser_shown} {
      if {[info commands $p] ne {}} { rename $p ${p}_besaved }
    }
    proc ::ase::session_for_current {} { return [list wvbe 0] }
    proc ::wviewer::hier_now {} { return {} }
    proc ::ase::browser_sel_segment {} { return [list ok $::be_sel] }
    proc ::wviewer::browser_origin_drop {level lv} { return 0 }
    proc ::ase::browser_digital_probe {key selname token} { return {} }
    # ⚠ THESE TWO ARE STUBBED AND `fd_drive_on` DOES NOT STUB THEM: that file
    # drives a REAL viewer window, this fixture is a bare toplevel carrying a
    # real browser. `open` would try to build a viewer around it. Neither is on
    # the seam under test — the flag is armed and consumed entirely inside step 6.
    proc ::wviewer::open {token} { return 1 }
    proc ::wviewer::browser_shown {{token {}}} { return 1 }
  }
  proc be_drive_off {} {
    foreach p {::ase::session_for_current ::wviewer::hier_now \
               ::ase::browser_sel_segment ::wviewer::browser_origin_drop \
               ::ase::browser_digital_probe ::wviewer::open \
               ::wviewer::browser_shown} {
      if {[info commands ${p}_besaved] ne {}} {
        catch {rename $p {}}
        rename ${p}_besaved $p
      }
    }
  }
  # THE INTERLEAVING SPY. Delegates to the real procs, so what it records is the
  # order the SHIPPED command executed in — an unarmed call shows up as a bare
  # `show_path` with no `arm` in front of it.
  proc be_spy_on {} {
    set ::be_seq {}
    foreach p {::wviewer::browser_say_quiet ::wviewer::browser_show_path} {
      rename $p ${p}_bespy
    }
    proc ::wviewer::browser_say_quiet {token {on 1}} {
      lappend ::be_seq [expr {$on ? {arm} : {disarm}}]
      return [::wviewer::browser_say_quiet_bespy $token $on]
    }
    proc ::wviewer::browser_show_path {token path} {
      lappend ::be_seq show_path
      return [::wviewer::browser_show_path_bespy $token $path]
    }
  }
  proc be_spy_off {} {
    foreach p {::wviewer::browser_say_quiet ::wviewer::browser_show_path} {
      catch {rename $p {}}
      rename ${p}_bespy $p
    }
  }

  # (a) THE a9 SHAPE, FOR REAL: a selection with no level in the data. Step 6
  # walks `a9`, fails, 6b retries the base path and lands on the sim root.
  set ::be_sel a9
  be_reset
  be_drive_on
  set be_ret [pcall ase::show_in_browser_for_current]
  be_drive_off
  update
  check {BE31 the REAL command on the a9 shape: no viewer line, TWO ase lines, no red} \
    [list $be_ret [llength [be_lines]] [llength [be_aselines]] [be_ntag error]] \
    {wvbe 0 2 0}

  # ⚠⚠ THE ACCOUNT ITSELF, VERBATIM — the sentences that are now the ONLY record
  # of this gesture in the log. Before the ruling the same two facts arrived as
  # four lines, one of them red. If ase.tcl's echo pair is ever deleted this is
  # the check that reds instead of the log going quiet.
  check {BE32 the two ase sentences ARE the gesture's whole account} \
    [be_aselines] \
    [list [list {} "ase: signal browser: 'a9' has no level in the simulation\
 data; showing the design root instead"] \
          [list {} {ase: signal browser: showing the simulation top level}]]

  # (b) A LANDING THAT SUCCEEDS: one ase line, still no viewer line, still no red.
  set ::be_sel x1
  be_reset
  be_drive_on
  set be_ret2 [pcall ase::show_in_browser_for_current]
  be_drive_off
  update
  check {BE33 the REAL command on a landing: ONE ase line, no viewer line, no red} \
    [list $be_ret2 [llength [be_lines]] [be_aselines] [be_ntag error]] \
    [list wvbe 0 [list [list {} {ase: signal browser: showing x1}]] 0]

  # (c) THE RUNTIME ORDER, which is what BE09/BE10 can only approximate from
  # source offsets — and the only behavioural check the DISARMS have.
  set ::be_sel a9
  be_reset
  be_spy_on
  be_drive_on
  pcall ase::show_in_browser_for_current
  be_drive_off
  be_spy_off
  check {BE34 the shipped command's runtime sequence: every call has its own arm} \
    $::be_seq {disarm arm show_path arm show_path disarm}

  # ⚠ TEARDOWN, BEHAVIOURALLY. An armed-but-unconsumed flag on a closed window
  # is the one way this array can leak, and `forget` is its only sweeper.
  pcall ::wviewer::browser_say_quiet wvbe
  set be_armed [info exists ::wviewer::sayquiet(wvbe)]
  pcall ::wviewer::forget wvbe
  check {BE27 forget drops an armed flag with the window} \
    [list $be_armed [info exists ::wviewer::sayquiet(wvbe)]] {1 0}

  catch {rename ::ciw_echo {}}
  if {[info commands ::be_saved_ciw_echo] ne {}} {
    rename ::be_saved_ciw_echo ::ciw_echo
  }
  catch {destroy .wvbe1}
  catch {dict unset ::wviewer::windows wvbe}
} else {
  puts "SKIP: BE2x need X (no \$has_x)"
}

wvbs_finish
