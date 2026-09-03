# tests/headless/test_annot_declutter_1244.tcl — item A1 of
# doc/claude/op_param_batch/PLAN.md (feature 1244, the schematic parameter
# declutter). Spec: doc/claude/specs/op_param_lists.md §4.1. Rulings:
# doc/claude/op_param_batch/DECISIONS.md, D-8 in particular.
#
# ============================================================================
# WHAT IS UNDER TEST — AND WHAT DELIBERATELY IS NOT
# ============================================================================
# A1 adds TWO things and nothing else:
#
#   1. `ANNOT_SHOW_NOPARAM 8`, a fourth bit on the `annot_show` mask
#      (src/xschem.h), which NO C CODE READS YET;
#   2. `cadence::annot_declutter` (utils/annot_mode.tcl) and the
#      `<Control-Alt-Key-6>` chord that calls it (src/cadence_style_rc).
#
# So at the end of A1, pressing Ctrl-Alt-6 toggles bit 3 of `annot_show` and
# NOTHING ON SCREEN CHANGES. That is correct, and rows I2/I3 asserted it.
# The draw-time rung is item A3 and the name classifier is item A2; A2 and A3
# add their rows to THIS file.
#
# ⚠ THE FILE NOW COVERS SIX ITEMS, IN SIX PASSES OVER ONE FEATURE:
#   sections D M S T V I   item A1 — the mask bit and the Ctrl-Alt-6 chord
#   section  N             item A2 — TEXT_ANNOT_NAME, the name classifier
#   section  A, A0..A29    item A3 — THE DRAW RUNG, the per-instance D-6 gate,
#                          and the four defects it inherits (1246 1247 1248 1249)
#   sections C/B/E         item A4 — the declutter clause on the other keys'
#                          sentence (issue 1251)
#   section  A, A30..A41   item A5 — D-1 / D-6 CONFORMANCE and the staleness A3
#                          left: the gate must require a VALUE (ruling D-6), the
#                          P6 pin-owned pin names (1253, ruling D-1), the other
#                          symbol_bbox() door (1252), and 1254's two coverage
#                          holes — which are REPAIRED IN PLACE at rows A15 and
#                          A17, keeping their numbers because 1254 names them.
#                          A5 also EDITS two goldens: A22's call-site census
#                          {3 1 1 1 0} -> {4 2 2 1 0}, and E6's fifth leg 0 -> 1.
#   section  A, A42..A56   item A6 — THE TWO HOLES IN THE VALUE GATE and the
#                          LAST bbox DOORS: a descriptor label containing `=`
#                          satisfies the gate (1258), a `dims=0` column's
#                          published zero satisfies it while a genuinely
#                          measured 0.0 must (1259), and four MORE Tcl-reachable
#                          symbol_bbox() doors plus the mask half of the gate
#                          (1260). A6 EDITS one golden: A41's fifth leg,
#                          annot_overlay_sync() in select.c 0 -> 1, which is a
#                          deliberate reversal of the option issue 1252
#                          rejected and is argued out loud beside the row.
# Rows N10 and N14 were written by A2 as "A3 MUST REPLACE" / "1249 PINNED" and
# were flipped in place by A3; row I2 was superseded by row A3 and re-purposed.
# Each carries the reason on itself. Section A's own header lists which of its
# rows are red before A3 lands and which are controls.
#
# ============================================================================
# THE HEADLINE, AND WHY THE CHORD IS NOT FREE
# ============================================================================
# Tk matches a pattern whose modifiers are a SUBSET of the event's. With only
# <Alt-Key-6> bound, a physical Ctrl+Alt+6 falls into the Alt form — measured
# and recorded in doc/claude/specs/op_annotation.md §4.6, and re-measured on
# this tree 2026-09-02 by two independent methods:
#
#   bind .drw <Control-Alt-Key-6>                   ->  {}          (unbound)
#   event generate .drw <Control-Alt-Key-6>         ->  reaches `cadence::annot_mode opvolt`
#   annot_show 1, then Ctrl-Alt-6                   ->  annot_show 3
#
# i.e. TODAY Ctrl-Alt-6 TURNS NODE VOLTAGES ON. Rows D2 and D3 are the two
# statements of the single most important check in this file: it must not.
# D2 says it by DISPATCH (which proc was reached), D3 by MASK. Both are here on
# purpose — a mask value alone is an inference about dispatch, and a dispatch
# recorder alone cannot see a writer that computes the wrong number.
#
# ============================================================================
# WHICH ROWS ARE RED BEFORE A1 LANDS, AND WHICH ARE CONTROLS
# ============================================================================
# Measured against the unmodified tree (src/xschem built 2026-09-01 23:06),
# 21 FAILED / 15 passed. Do not read the fifteen as evidence for A1.
#
#   RED (21), each for the reason recorded above:
#     D1 D2a D2b D3 D4 D5 · M1 M2 M3 · S1 S3 S4 S5 S6 · T4 · V1a V1b V2a V2b V2c V3
#
#   GREEN BEFORE THE CHANGE (15) — controls, invariants and hygiene:
#     D2c T5 T5b  the recorder / the binding table were put back
#     D6 D7       the shipped chords are already ORs, and `_annot_mask none`
#                 already returns a hard 0, so RULING D-8's "Ctrl-6 clears it
#                 with everything else" costs A1 no code at all
#     S2 S7 S8    the neighbour guards: the three shipped chords, the
#                 additive-setter table, and `_annot_msg`'s `& 7` blindness must
#                 all still read exactly as they do today
#     T1 T2 T3    the pinned traps and T2's non-vacuity control
#     I1 I2 I3    invariants I-A and I-C, and "A1 changes nothing on screen"
#     R1          registration
#   A green row here proves nothing about A1 — it proves A1 broke nothing. The
#   sabotage variants in doc/claude/op_param_batch/ name which of them each
#   variant is supposed to redden.
#
# ============================================================================
# ⚠ THE DEFAULT xschemrc DOES NOT SOURCE src/cadence_style_rc
# ============================================================================
# A bare `./src/xschem --pipe --script <t>` gives `bind .drw <Key-6>` = {} and
# NO ::cadence namespace at all. Every row below depends on the explicit
# `source` in the preamble. Measured side effect of running without it: Ctrl-6
# then reaches C and selects drawing layer 6 — which is exactly the displaced
# verb the trailing `break` exists to suppress, and is how row T3 gets its
# non-vacuity control.
#
# ============================================================================
# ⚠ THIS SUITE NEEDS X, AND `event generate` IS FINE HERE
# ============================================================================
# `bind` and `event generate` do not exist under --nogui, so this file must NOT
# be added to full_audit.sh's `nogui_tests`. It registers itself through
# full_audit.sh's `ls "$HERE"/test_*.tcl` glob (row R1); nothing is added to any
# list. The audit denominator moves 377 -> 378 — diff the baseline by NAME and
# STATUS, never by count.
#
# ⚠ tests/headless/test_wave_sigbrowser_i12.tcl:1141 warns that
# <Control-Alt-Key-v> "DOES NOT WORK UNDER event generate". That is true only
# for a C-side handler reading the numeric `%s` state (a synthesised Alt sets
# the virtual META bit, not Mod1, so `state==12` fails). A Tk `bind` PATTERN
# matches a synthesised Tk pattern fine — measured here: mask 1 -> 9 -> 1
# through `event generate .drw <Control-Alt-Key-6>`. This item is entirely
# Tk-side, so the warning does not apply. Do not "fix" the chord below into
# <Control-Mod1-Key-6>.
#
# Needs X. Run from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_annot_declutter_1244.tcl
# or, off the user's screen:
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog \
#       --script tests/headless/test_annot_declutter_1244.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }
## A raise is only the RIGHT raise if it names the thing the caller got wrong.
proc check_raises {name script needle} {
  global fail npass
  set rc [catch {uplevel #0 $script} res]
  if {$rc == 1 && [string match "*$needle*" $res]} {
    puts "ok:   $name"; incr npass
  } else {
    puts "FAIL: $name -> rc=$rc msg={$res} (exp rc=1 naming {$needle}) : FAIL"
    incr fail
  }
}

# --- locations (cwd-independent) --------------------------------------------
set here [file normalize [file dirname [info script]]]      ;# tests/headless
set repo [file normalize [file join $here .. ..]]           ;# repo root
source [file join $here scratch.tcl]
set scratch [test_scratch annot_declutter]

set DC_RC    [file join $repo src cadence_style_rc]
set DC_SRC   [file join $repo utils annot_mode.tcl]
set DC_H     [file join $repo src xschem.h]
set DC_AUDIT [file join $here full_audit.sh]

# ⚠ LOAD-BEARING (see the header): without this there is no ::cadence at all.
source $DC_RC
update idletasks
focus -force .drw
update idletasks

# ============================================================================
# READERS COPIED FROM tests/headless/test_op_annot.tcl
# ============================================================================
# A1 does not own that file, so the three readers it needs are COPIED here
# rather than shared. `opa_n_rcbind` carries ONE addition, marked below: the
# shipped reader regexps for `cadence::annot_mode\s+(\w+)` and then falls back
# to `cadence::annot_tran`, so a `cadence::annot_declutter toggle` body answers
# {NO-MODE 1}. Verified safe for the original: rows N19-N22 and V20 of
# test_op_annot.tcl all match with `string first "bind .drw <chord>"`, and the
# new chord's text is a substring of none of their chords.

## Count the lines of <path> matching <re>; -1 when the file is absent, so a
## missing file reds one row instead of raising out of the section.
proc opa_n_grep {path re} {
  if {![file isfile $path]} { return -1 }
  set fd [open $path r] ; set d [read $fd] ; close $fd
  set n 0
  foreach l [split $d \n] { if {[regexp -- $re $l]} { incr n } }
  return $n
}
## The whole text of <path>, or {} when it is absent.
proc opa_slurp {path} {
  if {![file isfile $path]} { return {} }
  set fd [open $path r] ; set d [read $fd] ; close $fd
  return $d
}
## Count the CODE lines of <path> matching <re> -- whole-line Tcl comments are
## skipped, so a sentence quoted in a header paragraph is not counted as a
## second mint. Copied from opa_v_ngrep, tests/headless/test_op_annot.tcl:11529.
## ⚠ NOT opa_n_grep: that one counts comments too, and item A4's rows count a
## SENTENCE, which the file above them is entitled to quote in prose.
proc dc_ngrep {path re} {
  if {![file isfile $path]} { return -1 }
  set fd [open $path r] ; set d [read $fd] ; close $fd
  set n 0
  foreach l [split $d \n] {
    if {[regexp {^\s*#} $l]} continue
    if {[regexp -- $re $l]} { incr n }
  }
  return $n
}
## THE ANSWER DISCIPLINE -- an absent proc must never satisfy a golden. Copied
## from b_ans, tests/headless/test_annot_blank_cause_0909.tcl:117. Without it
## "invalid command name cadence::_annot_declutter_clause" would satisfy a row
## expecting the empty string, i.e. the whole clause section would read green
## against a tree that never got the clause.
proc dc_ans {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  set rc [catch {uplevel #0 [linsert $args 0 $cmd]} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}
## The source text of ONE proc: from its `proc <name> {` header (column 0) up to
## the next such header, or end of file. {} when the proc is absent.
## ⚠ WHY THE SLICE: `.` matches a newline in Tcl, so a whole-file
## `proc <name> \{.*?<needle>` runs from a renamed no-op shim's header into the
## real body below it and stays green over dead code (issue 0682, S1/S5).
proc opa_proc_src {src name} {
  set s "\n$src"
  set i [string first "\nproc $name \{" $s]
  if {$i < 0} { return {} }
  set rest [string range $s [expr {$i + 1}] end]
  set j [string first "\nproc " $rest]
  if {$j < 0} { return $rest }
  return [string range $rest 0 $j]
}
## -> {mode has-trailing-break} for one `bind .drw <chord>` line of the rc.
## The `break` half is not decoration: measured with `event generate`, with ALL
## the .drw 6-chords removed Ctrl-6 reaches callback.c and selects drawing
## layer 6 (row T3).
proc opa_n_rcbind {path chord} {
  if {![file isfile $path]} { return {NO-FILE 0} }
  set fd [open $path r] ; set d [read $fd] ; close $fd
  foreach l [split $d \n] {
    if {[string first "bind .drw $chord" $l] < 0} continue
    set mode NO-MODE
    if {![regexp {cadence::annot_mode\s+(\w+)} $l -> mode]} {
      if {[regexp {cadence::annot_tran} $l]} { set mode tran }
      ## ⚠ THE ONE ARM THIS COPY ADDS (item A1). The declutter's body is
      ## `cadence::annot_declutter toggle`, which neither of the two forms above
      ## recognises; without this the reader answers NO-MODE and row S1 could
      ## never say WHICH proc the new bind reaches. Tried LAST so the three
      ## shipped chords and the transient chord are bit-for-bit unaffected.
      if {[regexp {cadence::annot_declutter} $l]} { set mode declutter }
    }
    return [list $mode [expr {[regexp {break\s*\}\s*$} $l] ? 1 : 0}]]
  }
  return {NO-BIND 0}
}
## 1 when <path> delegates to src/cadence_style_rc rather than copying it.
proc opa_n_delegates {path} {
  if {![file isfile $path]} { return NO-FILE }
  set fd [open $path r] ; set d [read $fd] ; close $fd
  foreach l [split $d \n] {
    if {[regexp {source\s+\[file join .*\.\.\s+src\s+cadence_style_rc\]} $l]} { return 1 }
  }
  return 0
}
## The value of `#define <name> <value>` in a C header, or MISSING / MULTI.
proc dc_define {path name} {
  set n 0 ; set v MISSING
  foreach l [split [opa_slurp $path] \n] {
    if {[regexp "^\\s*#define\\s+$name\\s+(\\S+)" $l -> hit]} { incr n ; set v $hit }
  }
  if {$n == 0} { return MISSING }
  if {$n > 1}  { return MULTI:$n }
  return $v
}

# ============================================================================
# SESSION HELPERS
# ============================================================================
proc dc_mask {} { set m NO-GET ; catch {set m [xschem get annot_show]} ; return $m }
proc dc_setmask {v} { catch {xschem set annot_show $v} ; return [dc_mask] }
proc dc_fire {seq} { event generate .drw $seq ; update idletasks }
## Fire <seq> from mask <from> and report the mask it produced.
proc dc_from {from seq} { dc_setmask $from ; dc_fire $seq ; return [dc_mask] }

## The dispatch recorder: rename the three bind targets aside, install stubs
## that only record, drive, restore. This is the only honest way to say WHICH
## proc a chord reached — and the only way to cover the Alt-Shift-6 row, whose
## real body refuses without a raw fixture and so leaves the mask at 0.
## (Pattern copied from tests/headless/test_ase_window.tcl:1949-1956.)
proc dc_rec_install {} {
  set ::dc_seen {}
  foreach n {annot_mode annot_tran annot_declutter} {
    if {[llength [info procs ::cadence::$n]]} {
      catch {rename ::cadence::$n ::cadence::__dc_saved_$n}
      set ::dc_saved($n) 1
    } else {
      set ::dc_saved($n) 0
    }
  }
  proc ::cadence::annot_mode {mode} { lappend ::dc_seen "annot_mode:$mode" ; return }
  proc ::cadence::annot_tran {} { lappend ::dc_seen {annot_tran:} ; return }
  proc ::cadence::annot_declutter {{mode toggle}} { lappend ::dc_seen "annot_declutter:$mode" ; return }
}
proc dc_rec_remove {} {
  foreach n {annot_mode annot_tran annot_declutter} {
    catch {rename ::cadence::$n {}}
    if {$::dc_saved($n)} { catch {rename ::cadence::__dc_saved_$n ::cadence::$n} }
  }
}
proc dc_dispatch {seq} { set ::dc_seen {} ; dc_fire $seq ; return $::dc_seen }

# ============================================================================
# THE THREE SENTENCES — UNRATIFIED (status E), asserted byte for byte
# ============================================================================
# Minted in ONE pure proc, `cadence::_annot_declutter_msg {on gated}`, in
# `cadence::_annot_tran_msg`'s shape. <on> is the NEW state of bit 3; <gated> is
# 1 when ANNOT_SHOW_OP is set, i.e. when the declutter actually has an effect.
#
# ⚠ THE FIRST SENTENCE DESCRIBES THE WORLD ITEM A3 CREATES. Between A1 and A3
# landing, it promises a declutter that has not arrived. That is the E question
# recorded against issue 1244 — the wording is written here or nowhere, because
# A3's Files cell does not include utils/annot_mode.tcl.
#
# ⚠ HELD STATUS LINE ONLY, NEVER THE CIW. The declutter publishes nothing; it
# is pure mask arithmetic, exactly like `cadence::annot_mode`, whose success
# tail uses the bar alone. `cadence::annot_tran` uses both sinks because it
# PUBLISHES. Row V3 is what forbids `_annot_say` here.
set DC_ON  {Decluttering the schematic: a device showing operating-point values draws its name and those values only. Press Ctrl-Alt-6 again to bring the rest of its text back.}
set DC_ARM {Decluttering is on, but nothing changes yet: it applies only while operating-point values are showing. Press 6 to show them.}
set DC_OFF {Decluttering is off. Devices draw all of their text again.}

# ============================================================================
# THE FOURTH SENTENCE — ISSUE 1251, AND IT IS A CLAUSE, NOT A SENTENCE
# ============================================================================
# The three above belong to the Ctrl-Alt-6 chord itself and are on the USER's
# queue as rule debt `1244`. This one belongs to the OTHER keys: press `6` after
# a `Ctrl-Alt-6` and, before item A4, the editor said "Showing device
# operating-point values on the schematic" about a sheet it had just stripped
# every parameter from. It is APPENDED to the eight `& 7` arms rather than
# widening the switch, so those arms stay byte-identical and row V21 of
# tests/headless/test_op_annot.tcl (a file item A4 does not own, and which
# sweeps masks 0..7 only) cannot see it.
#
# ⚠ IT COMPOSES WITH A1's THREE, IT DOES NOT REPLACE THEM. Row S10.
# ⚠ IT LEADS WITH A SPACE, like every other clause `cadence::_annot_msg`
#   appends, so the mint stays `append`-shaped. 52 bytes including that space.
# ⚠ IT IS ALSO UNRATIFIED (status E). Ctrl-Alt-6 already says the long version
#   at the moment the user arms the bit; whether every later press should carry
#   this reminder, carry a shorter one, repeat the way out, or say nothing, is
#   the user's call. Recorded against issue 1251.
set DC_CLAUSE { Decluttering is on, so other device text is hidden.}

# ============================================================================
# SECTION D — THE CHORD MATRIX
# ============================================================================

check_true "D1 cadence::annot_declutter exists after sourcing src/cadence_style_rc" \
  [expr {[llength [info procs ::cadence::annot_declutter]] == 1}]

# --- D2: THE HEADLINE, BY DISPATCH -------------------------------------------
dc_rec_install
set d2_6      [dc_dispatch <Key-6>]
set d2_c6     [dc_dispatch <Control-Key-6>]
set d2_a6     [dc_dispatch <Alt-Key-6>]
set d2_circ   [dc_dispatch <Alt-Key-asciicircum>]
set d2_as6    [dc_dispatch <Alt-Shift-Key-6>]
set d2_ca6    [dc_dispatch <Control-Alt-Key-6>]
dc_rec_remove

check "D2a the six chords reach the procs they are supposed to reach" \
  [list $d2_6 $d2_c6 $d2_a6 $d2_circ $d2_as6 $d2_ca6] \
  [list {annot_mode:op} {annot_mode:none} {annot_mode:opvolt} \
        {annot_tran:} {annot_tran:} {annot_declutter:toggle}]

# The same claim isolated, because it is the whole reason this item exists.
check "D2b HEADLINE Ctrl-Alt-6 reaches cadence::annot_declutter and NOT annot_mode opvolt" \
  [list $d2_ca6 [expr {[lsearch -exact $d2_ca6 {annot_mode:opvolt}] >= 0 ? 1 : 0}]] \
  [list {annot_declutter:toggle} 0]

check "D2c the recorder put the three real procs back" \
  [list [llength [info procs ::cadence::annot_mode]] \
        [llength [info procs ::cadence::annot_tran]] \
        [llength [info procs ::cadence::__dc_saved_annot_mode]]] \
  {1 1 0}

# --- D3..D7: THE HEADLINE, BY MASK -------------------------------------------
# ⚠ These rows fire the REAL bodies. `cadence::annot_mode` writes the mask here
# because no raw is loaded: `_annot_op_db_ok` returns 1 on `xschem raw loaded`
# < 0 (utils/annot_mode.tcl), so guard G-0856 does not refuse. Nothing below
# may load a raw.
check "D3 HEADLINE Ctrl-Alt-6 from mask 1 sets bit3 and LEAVES BIT1 (node voltages) ALONE" \
  [dc_from 1 <Control-Alt-Key-6>] 9

check "D4 Ctrl-Alt-6 is a TOGGLE: from mask 9 it restores exactly mask 1" \
  [dc_from 9 <Control-Alt-Key-6>] 1

check "D5 Ctrl-Alt-6 from mask 0 gives exactly 8 - arming ahead of annotation is allowed (I-C)" \
  [dc_from 0 <Control-Alt-Key-6>] 8

check "D6 the three shipped chords PRESERVE bit3 (they are ORs): 6 from 8 -> 9, Alt-6 from 9 -> 11" \
  [list [dc_from 8 <Key-6>] [dc_from 9 <Alt-Key-6>]] {9 11}

check "D7 RULING D-8: Ctrl-6 from mask 11 clears bit3 with everything else" \
  [dc_from 11 <Control-Key-6>] 0

# ============================================================================
# SECTION M — THE WRITER, CALLED DIRECTLY
# ============================================================================
dc_setmask 0
if {[catch {cadence::annot_declutter toggle}]} { set m1a RAISED } else { set m1a [dc_mask] }
if {[catch {cadence::annot_declutter toggle}]} { set m1b RAISED } else { set m1b [dc_mask] }
check "M1 cadence::annot_declutter toggle takes 0 -> 8 -> 0" [list $m1a $m1b] {8 0}

## ⚠ `on`/`off` ARE BIT-WISE AND IDEMPOTENT. They cost two lines, make the
## writer safe for a future menu tick or a user's own rc (invariant I5), and
## keep bits 0/1/2 untouched throughout.
dc_setmask 7
set m2 {}
foreach a {on on off off} {
  if {[catch {cadence::annot_declutter $a}]} { lappend m2 RAISED } else { lappend m2 [dc_mask] }
}
check "M2 on/off are idempotent and bit-wise: 7 -on-> 15 -on-> 15 -off-> 7 -off-> 7" \
  $m2 {15 15 7 7}

check_raises "M3 an unknown spelling RAISES and names the three that work" \
  {cadence::annot_declutter sideways} {use toggle, on or off}

dc_setmask 0

# ============================================================================
# SECTION S — THE SOURCE (what shipped, not what this session happens to hold)
# ============================================================================
check "S1 src/cadence_style_rc binds <Control-Alt-Key-6> to cadence::annot_declutter, with a trailing break" \
  [opa_n_rcbind $DC_RC {<Control-Alt-Key-6>}] {declutter 1}

## Landmine 1's neighbour guard: the four shipped chords must be untouched.
check "S2 the shipped chords still read op / none / opvolt / tran / tran" \
  [list [opa_n_rcbind $DC_RC {<Key-6>}] [opa_n_rcbind $DC_RC {<Control-Key-6>}] \
        [opa_n_rcbind $DC_RC {<Alt-Key-6>}] [opa_n_rcbind $DC_RC {<Alt-Key-asciicircum>}] \
        [opa_n_rcbind $DC_RC {<Alt-Shift-Key-6>}]] \
  {{op 1} {none 1} {opvolt 1} {tran 1} {tran 1}}

check_true "S3 the rc really INSTALLED the bind in this session (not merely carries the text)" \
  [expr {[bind .drw <Control-Alt-Key-6>] ne {}}]

## ⚠ THE MASK GOES THROUGH `xschem set annot_show`, NEVER A BARE
## `set ::annot_show`: the mask is PER-CONTEXT (xctx->annot_show), so the Tcl
## mirror belongs to whichever context wrote it last, and the C field reads
## stale until the next sync. The first leg is scoped to annot_declutter's own
## sliced body — a file-level grep is already satisfied by cadence::annot_tran.
set S4_BODY [opa_proc_src [opa_slurp $DC_SRC] cadence::annot_declutter]
check "S4 annot_declutter writes through `xschem set annot_show`, and utils/annot_mode.tcl has ZERO bare `set ::annot_show`" \
  [list [expr {[regexp {xschem set annot_show} $S4_BODY] ? 1 : 0}] \
        [expr {[regexp {xschem get annot_show} $S4_BODY] ? 1 : 0}] \
        [opa_n_grep $DC_SRC {^\s*set\s+::annot_show}]] \
  {1 1 0}

## Spec landmine 6: ONE bind block reaches all four profiles, because each PDK
## rc merely sources src/cadence_style_rc. Editing three files is the drift this
## tree forbids — so the chord must appear in src/cadence_style_rc and nowhere
## else. This row IS the "under all four profiles" acceptance.
check "S5 landmine 6: the chord is in src/cadence_style_rc ONLY, and the three PDK rcs delegate" \
  [list [opa_n_grep $DC_RC {bind \.drw <Control-Alt-Key-6>}] \
        [opa_n_grep [file join $repo sky130A cadence_style_rc] {bind \.drw <Control-Alt-Key-6>}] \
        [opa_n_grep [file join $repo gf180mcuD cadence_style_rc] {bind \.drw <Control-Alt-Key-6>}] \
        [opa_n_grep [file join $repo ihp-sg13g2 cadence_style_rc] {bind \.drw <Control-Alt-Key-6>}] \
        [opa_n_delegates [file join $repo sky130A cadence_style_rc]] \
        [opa_n_delegates [file join $repo gf180mcuD cadence_style_rc]] \
        [opa_n_delegates [file join $repo ihp-sg13g2 cadence_style_rc]]] \
  {1 0 0 0 1 1 1}

## ⚠ THE VALUE, NOT MERELY THE NAME. A `#define ANNOT_SHOW_NOPARAM 4` would
## collide with ANNOT_SHOW_TRAN, compile clean, and be invisible to every
## behavioural row in this file until item A3 lands. The four bits are asserted
## as a sorted set of four distinct powers of two.
set S6_V [list [dc_define $DC_H ANNOT_SHOW_OP] [dc_define $DC_H ANNOT_SHOW_VOLTAGE] \
               [dc_define $DC_H ANNOT_SHOW_TRAN] [dc_define $DC_H ANNOT_SHOW_NOPARAM]]
## `lsort -integer` raises on MISSING, and a raise here would abort the section
## rather than red one row — so the set is only sorted once every value is a
## number, and the unsorted list is reported when one is not.
set S6_ok 1
foreach v $S6_V { if {![string is integer -strict $v]} { set S6_ok 0 } }
if {$S6_ok} { set S6_SET [lsort -integer -unique $S6_V] } else { set S6_SET $S6_V }
check "S6 src/xschem.h defines ANNOT_SHOW_NOPARAM exactly once as 8, four distinct bits {1 2 4 8}" \
  [list [dc_define $DC_H ANNOT_SHOW_NOPARAM] $S6_SET [llength $S6_V]] \
  {8 {1 2 4 8} 4}

## The toggle is NOT folded into the additive-setter table. `cadence::_annot_mask`
## is the `none|op|opvolt` table row N1 of test_op_annot.tcl golds AS SUCH; a
## toggle in it stops it being that table. `tran` already raises there for the
## same reason (utils/annot_mode.tcl header).
check_raises "S7 cadence::_annot_mask still RAISES on `declutter` - the toggle is a separate proc" \
  {cadence::_annot_mask declutter 0} {unknown mode "declutter"}

## ============================================================================
## S8 — ISSUE 1251. THIS ROW WAS THE PIN; IT IS NOW THE PROOF.
## ============================================================================
## It used to assert that `cadence::_annot_msg` was BLIND to bit 3 -- it switches
## on `[expr {$mask & 7}]` (utils/annot_mode.tcl:906) so the bit never reaches
## the eight arms. That was CORRECT while item A1 was the whole feature: the bit
## moved no pixel, so a sentence ignoring it was accurate, and widening the
## switch would have reddened row V21 of test_op_annot.tcl, a file A1 does not
## own. After item A3's draw rung landed, mask 1 and mask 9 draw DIFFERENT
## SHEETS and produced the SAME SENTENCE -- "Showing device operating-point
## values on the schematic" about a sheet every parameter had just been stripped
## from. Issue 1251 says in as many words that this row must be inverted, and its
## non-vacuity is the behavioural proof of the fix.
##
## THE SWITCH IS STILL NOT WIDENED. Item A4 APPENDS a clause, so the eight arms
## stay byte-identical and V21 keeps passing on the `& 7` part.
##
## THE FOUR LEGS ARE THE FOUR HALVES OF THE GATE, AND THREE OF THEM ARE RULINGS:
##   1. bit 3 WITH bit 0, at a state that is showing numbers -> the sentence
##      CHANGES. The defect, inverted.
##   2. bit 3 WITHOUT bit 0 -> the sentence does NOT change. RULING D-8,
##      verbatim: "Declutter is active ONLY when OP info (6 key triggered) is
##      displayed", and A3's draw rung is AND-ed on both bits (rows A5/A16,
##      invariant I-C, PERMANENT). At masks 8/10/12/14 nothing is hidden, so a
##      clause claiming otherwise would be a caption with no measurement behind
##      it -- save.c RULING D5-1's shape. Note this is why the gate is NOT issue
##      1251's own literal suggestion `if {$mask & 8}`.
##   3. EVERY state carries it, the refusal states included -- and THIS LEG WAS
##      GOLDED THE OTHER WAY ROUND FOR HALF A DAY. Item A4 first shipped the
##      clause behind `$state eq {live} || $state eq {loaded}`, reasoning from
##      issue 0909's `canask` term that a press which found no results file must
##      not ALSO be told its sheet is decluttered. THE PREMISE WAS FALSE AND WAS
##      MEASURED FALSE: item A3's rung is gated on `annot_overlay_gate(n)` AND a
##      NON-BLANK `op_annot::text` block, and src/actions.c:2075 says so in as
##      many words -- "a registered device over a dead raw is therefore
##      decluttered while its block shows empty rows". Driven with NO raw loaded
##      at all (`xschem raw loaded` = -1, the `noraw` state):
##          mask 1 texts = M1 W4GATE W4W=1u {zid =}
##          mask 9 texts = M1 {zid =}
##      i.e. the sheet IS stripped and it was the SILENCE that was inaccurate --
##      in the most common first press there is, `6` before the simulation has
##      been run. Row E6 is that same fact end to end, on this file's own
##      fixture. State `off` is in the list as a can't-happen pairing: the mint
##      is a pure function of its two arguments, and `cadence::annot_mode` only
##      leaves `state` at `off` when the mask is 0 (utils/annot_mode.tcl:1237),
##      where bit 0 is clear and leg 2 covers it.
##   4. the difference is EXACTLY the clause and nothing else -- which is what
##      keeps the eight arms, and therefore V21, byte-identical.
set S8_STATES {off live noop loaded failed noraw nopath stale}
set S8_DIFF {}
foreach st {live loaded} {
  foreach p {1 3 5 7} {
    lappend S8_DIFF [expr {[cadence::_annot_msg $p $st /tmp/zz.raw {}] ne \
                           [cadence::_annot_msg [expr {$p | 8}] $st /tmp/zz.raw {}] ? 1 : 0}]
  }
}
set S8_SAME {}
foreach st $S8_STATES {
  foreach p {0 2 4 6} {
    lappend S8_SAME [expr {[cadence::_annot_msg $p $st /tmp/zz.raw {}] eq \
                           [cadence::_annot_msg [expr {$p | 8}] $st /tmp/zz.raw {}] ? 1 : 0}]
  }
}
## NAMED, not counted: a golden of ones would read the same whichever way the
## comparison ran, and this leg was inverted once already.
set S8_ST {}
foreach st $S8_STATES {
  if {[cadence::_annot_msg 9 $st /tmp/zz.raw {}] ne \
      [cadence::_annot_msg 1 $st /tmp/zz.raw {}]} { lappend S8_ST $st }
}
set S8_ONLY {}
foreach st $S8_STATES {
  lappend S8_ONLY [expr {[string map [list $DC_CLAUSE {}] \
                           [cadence::_annot_msg 9 $st /tmp/zz.raw {}]] eq \
                         [cadence::_annot_msg 1 $st /tmp/zz.raw {}] ? 1 : 0}]
}
check "S8 ISSUE 1251 FIXED: with bit0 set the sentence names the declutter in EVERY state, with bit0 clear it does not (D-8), and the whole difference is the clause" \
  [list $S8_DIFF $S8_SAME $S8_ST $S8_ONLY] \
  [list {1 1 1 1 1 1 1 1} {1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1} \
        {off live noop loaded failed noraw nopath stale} {1 1 1 1 1 1 1 1}]

## ---------------------------------------------------------------------------
## S9 — ONE MINTER, PURE, AND `_annot_msg` CALLS IT RATHER THAN SPELLING IT
## ---------------------------------------------------------------------------
## Invariant I1, in this file's own shape: `cadence::_annot_declutter_msg` and
## `cadence::_annot_tran_msg` are both PURE functions of their arguments -- the
## live mask never reaches them -- and rows V1a/V1b exist to keep that family
## one. The clause joins it: two consumers (`cadence::_annot_msg` and
## `cadence::annot_tran`'s success tail), ONE mint. Two independent builders of
## the same sentence drift SILENTLY, which is the failure invariant I1 names.
##
## ⚠ THE LITERAL IS COUNTED ON CODE LINES ONLY (dc_ngrep). Prose above the proc
## may quote the sentence freely; a SECOND code line spelling it is the defect.
set S9_SRC [opa_slurp $DC_SRC]
dc_setmask 0  ; set S9_P0 [dc_ans ::cadence::_annot_declutter_clause 9]
dc_setmask 15 ; set S9_P1 [dc_ans ::cadence::_annot_declutter_clause 9]
dc_setmask 0
check "S9 the clause is minted in ONE PURE proc, gated on bit3 AND bit0, spelled on exactly one code line, and _annot_msg CALLS the minter" \
  [list [dc_ans ::cadence::_annot_declutter_clause 9] \
        [dc_ans ::cadence::_annot_declutter_clause 15] \
        [dc_ans ::cadence::_annot_declutter_clause 1] \
        [dc_ans ::cadence::_annot_declutter_clause 8] \
        [dc_ans ::cadence::_annot_declutter_clause 0] \
        [expr {$S9_P0 eq $S9_P1 ? 1 : 0}] \
        [dc_ngrep $DC_SRC {Decluttering is on, so other device text is hidden}] \
        [expr {[string first {_annot_declutter_clause} \
                 [opa_proc_src $S9_SRC cadence::_annot_msg]] >= 0 ? 1 : 0}]] \
  [list $DC_CLAUSE $DC_CLAUSE {} {} {} 1 1 1]

## ---------------------------------------------------------------------------
## S10 — IT COMPOSES WITH ITEM A1's THREE SENTENCES, IT DOES NOT REPLACE THEM
## ---------------------------------------------------------------------------
## ⚠ A1's three are on the USER's queue as rule debt `1244` and are NOT item
## A4's to reword. This row is the guard on that: they are asserted byte for
## byte against the same goldens A1 shipped, and the clause is required to be a
## FOURTH string minted by a SECOND proc.
set S10_CL [dc_ans ::cadence::_annot_declutter_clause 9]
check "S10 the clause COMPOSES with A1's three sentences: DC_ON / DC_ARM / DC_OFF byte-identical (rule debt 1244 is the user's, not A4's) and the clause is a fourth string from a second proc" \
  [list [dc_ans ::cadence::_annot_declutter_msg 1 1] \
        [dc_ans ::cadence::_annot_declutter_msg 1 0] \
        [dc_ans ::cadence::_annot_declutter_msg 0 1] \
        [expr {($S10_CL ne {} && $S10_CL ne {NOPROC} && \
                [string trim $S10_CL] ne $DC_ON && \
                [string trim $S10_CL] ne $DC_ARM && \
                [string trim $S10_CL] ne $DC_OFF) ? 1 : 0}] \
        [expr {([llength [info procs ::cadence::_annot_declutter_msg]] == 1 && \
                [llength [info procs ::cadence::_annot_declutter_clause]] == 1) ? 1 : 0}] \
        [dc_ngrep $DC_SRC {Press Ctrl-Alt-6 again to}]] \
  [list $DC_ON $DC_ARM $DC_OFF 1 1 1]

## ---------------------------------------------------------------------------
## S11 — PLAIN ENGLISH, FOR THE ONE SENTENCE ROW A11-7 CANNOT SEE
## ---------------------------------------------------------------------------
## Row A11-7 of tests/headless/test_op_annot.tcl judges every sentence this
## surface can render against RULING 0886's ban list. Verified by reading it:
## it sweeps EIGHT MASKS BY EIGHT STATES, i.e. masks 0..7 only, so a bit-3
## clause is invisible to it -- and A4 does not own that file. The ban list is
## reproduced here for the one sentence A11-7 will never see.
## ⚠ THE SHAPES, NOT JUST THE SPELLINGS. An underscore or an equals sign is an
## identifier, not English; `::` or `xschem ` is the machine talking; and the
## bare state words are names this code calls itself by. Leg 3 is the control
## that stops the detector reading green while unplugged.
set DC_BANNED [list {*_*} {*=*} {*::*} {*xschem *} {*OP *} {*database*} \
                    {*sim_type*} {*annot_show*} {*raw file*} \
                    {*noop*} {*nopath*} {*noraw*} {*notop*} {*notran*} \
                    {*nocursor*} {*staleraw*} {*viewerdiff*} {*okclamped*} \
                    {*nodata*} {*viewerunread*} {*viewergone*} {*viewerfilling*}]
proc dc_jargon {s} {
  set hits {}
  foreach pat $::DC_BANNED { if {[string match $pat $s]} { lappend hits $pat } }
  if {![regexp {^[\x20-\x7e]*$} $s]} { lappend hits NON-ASCII }
  return $hits
}
check "S11 the clause is plain English by RULING 0886's own ban list - no identifier, no operator, no namespace, no internal state word, printable ASCII" \
  [list [expr {$S10_CL eq $DC_CLAUSE ? 1 : 0}] \
        [dc_jargon $S10_CL] \
        [expr {[llength [dc_jargon {_annot_msg: mask & 8 -> ::cadence, xschem get annot_show}]] >= 4 ? 1 : 0}]] \
  [list 1 {} 1]

# ============================================================================
# SECTION T — THE TRAPS, PINNED SO NOBODY "FIXES" THEM
# ============================================================================

## `annot_show` is an INTEGER and scheduler.c calls a bare atoi() on it with no
## clamp and no validation. `true`/`on`/`yes` therefore mean OFF, silently.
## This is spec landmine 8. It is pinned, not repaired: the repair belongs to a
## ruled item, and a crew that "helpfully" made `true` mean 1 would change the
## meaning of every existing rc line that says `annot_show 0`.
set T1 {}
foreach v {true on yes 8 15} { lappend T1 [dc_setmask $v] }
check "T1 the integer trap: true/on/yes all read back 0, while 8 and 15 read back whole" \
  $T1 {0 0 0 8 15}
dc_setmask 0

## Ctrl-6 is a DISPLACED verb (Ctrl+<digit> = select drawing layer <digit>,
## callback.c). Nothing in the matrix may move the drawing layer.
set T2 {}
foreach s {<Key-6> <Control-Key-6> <Alt-Key-6> <Alt-Key-asciicircum> <Alt-Shift-Key-6> <Control-Alt-Key-6>} {
  catch {xschem set rectcolor 4}
  set a [xschem get rectcolor]
  dc_fire $s
  lappend T2 [list $a [xschem get rectcolor]]
}
check "T2 rectcolor is 4 before and after every chord - no chord displaces the drawing layer" \
  $T2 {{4 4} {4 4} {4 4} {4 4} {4 4} {4 4}}
dc_setmask 0

## NON-VACUITY FOR T2, and it needs ALL SIX binds gone, not one.
## ⚠ MEASURED, AND IT CONTRADICTS THE OBVIOUS CONTROL: deleting only
## <Control-Key-6> leaves rectcolor at 4, because Ctrl+6 then falls into
## <Key-6> by the very subset rule this whole item is about. Only with every
## .drw 6-chord removed does the event reach `bind .drw <Key>` -> the C
## dispatcher -> layer select.
##
## ⚠⚠ AND THE RESTORE MUST PUT BACK THE ORDER, NOT JUST THE BODIES. Tk breaks a
## tie between two EQUALLY specific patterns by CREATION ORDER, most recent
## first. Measured on this tree 2026-09-02: destroy `<Control-Key-6>` and
## re-create it LAST, and for the rest of the session `Ctrl+Alt+6` dispatches to
## `cadence::annot_mode none` instead of `opvolt` — i.e. a careless restore
## silently rewrites the subject of every later row in this file. The two rows
## below therefore restore by destroying all six and re-creating them in the
## rc's own order, and row T5 is the receipt that they did.
set T3_SIX {<Key-6> <Control-Key-6> <Alt-Key-6> <Alt-Key-asciicircum> <Alt-Shift-Key-6> <Control-Alt-Key-6>}
proc dc_binds_snap {seqs} { set o {} ; foreach s $seqs { lappend o $s [bind .drw $s] } ; return $o }
proc dc_binds_restore {snap} {
  foreach {s b} $snap { bind .drw $s {} }
  foreach {s b} $snap { if {$b ne {}} { bind .drw $s $b } }
}
set T3_SNAP [dc_binds_snap $T3_SIX]

foreach {s b} $T3_SNAP { bind .drw $s {} }
catch {xschem set rectcolor 4}
dc_fire <Control-Key-6>
set t3_bare [xschem get rectcolor]
dc_binds_restore $T3_SNAP

## only <Control-Key-6> missing: it falls into <Key-6> and displaces nothing
bind .drw <Control-Key-6> {}
catch {xschem set rectcolor 4}
dc_fire <Control-Key-6>
set t3_one [xschem get rectcolor]
dc_binds_restore $T3_SNAP

catch {xschem set rectcolor 4}
dc_fire <Control-Key-6>
set t3_back [xschem get rectcolor]
check "T3 non-vacuity: with ALL SIX 6-chords removed Ctrl-6 selects layer 6; with only Ctrl-6 removed it does not; restored it does not" \
  [list $t3_bare $t3_one $t3_back] {6 4 4}
dc_setmask 0

## THE TRAILING `break` IS LOAD-BEARING FOR A REASON NOBODY WOULD GUESS:
## `bind all <Alt-Key>` is `tk::TraverseToMenu %W %A` — Tk's own menu traversal,
## on the `all` bindtag, which the .drw body falls through to without it.
## Measured here: shipped bind -> 0 calls, the same chord rebound WITHOUT
## `break` -> 1 call.
set ::dc_ttm 0
catch {rename ::tk::TraverseToMenu ::tk::__dc_saved_TTM}
proc ::tk::TraverseToMenu {w a} { incr ::dc_ttm ; return }
set t4_have [expr {[bind .drw <Control-Alt-Key-6>] ne {} ? 1 : 0}]
set T4_SNAP [dc_binds_snap $T3_SIX]
set ::dc_ttm 0 ; dc_fire <Control-Alt-Key-6> ; set t4_shipped $::dc_ttm
bind .drw <Control-Alt-Key-6> {catch {cadence::annot_declutter toggle}}
set ::dc_ttm 0 ; dc_fire <Control-Alt-Key-6> ; set t4_nobreak $::dc_ttm
dc_binds_restore $T4_SNAP
catch {rename ::tk::TraverseToMenu {}}
catch {rename ::tk::__dc_saved_TTM ::tk::TraverseToMenu}
check "T4 the trailing break is LIVE: shipped chord reaches tk::TraverseToMenu 0 times, the same chord without break reaches it once" \
  [list $t4_have $t4_shipped $t4_nobreak] {1 0 1}
dc_setmask 0

## THE RECEIPT FOR T3 AND T4, and it is a HYGIENE row, not a claim about the
## feature: whatever the six chords dispatched to before those two rows mutated
## the binding table, they must dispatch to again afterwards. Compared against
## section D's own readings rather than against a literal, so this row says
## exactly one thing — "the bind table came back" — and reds only for that.
dc_rec_install
set t5 [list [dc_dispatch <Key-6>] [dc_dispatch <Control-Key-6>] [dc_dispatch <Alt-Key-6>] \
             [dc_dispatch <Alt-Key-asciicircum>] [dc_dispatch <Alt-Shift-Key-6>] \
             [dc_dispatch <Control-Alt-Key-6>]]
dc_rec_remove
check "T5 hygiene: T3 and T4 put the binding table back - the six chords dispatch exactly as they did in D2a" \
  $t5 [list $d2_6 $d2_c6 $d2_a6 $d2_circ $d2_as6 $d2_ca6]
dc_setmask 0
catch {rename ::tk::__dc_saved_TTM {}}
check_true "T5b hygiene: tk::TraverseToMenu is the real one again" \
  [expr {[llength [info procs ::tk::TraverseToMenu]] == 1 && \
         [string first {dc_ttm} [info body ::tk::TraverseToMenu]] < 0}]

# ============================================================================
# SECTION V — THE VOICE
# ============================================================================

## The minter is a PURE FUNCTION: the live mask never reaches it. A version that
## read `xschem get annot_show` itself would make the wording depend on session
## state and leave row V2 as its only guard.
set v1 {}
foreach a {{1 1} {1 0} {0 1} {0 0}} {
  if {[catch {cadence::_annot_declutter_msg [lindex $a 0] [lindex $a 1]} r]} { lappend v1 RAISED } \
  else { lappend v1 $r }
}
check "V1a the minter returns the three goldened sentences for on+gated / on+ungated / off" \
  $v1 [list $DC_ON $DC_ARM $DC_OFF $DC_OFF]

dc_setmask 0
if {[catch {cadence::_annot_declutter_msg 1 1} r]} { set v1p0 RAISED } else { set v1p0 $r }
dc_setmask 15
if {[catch {cadence::_annot_declutter_msg 1 1} r]} { set v1p1 RAISED } else { set v1p1 $r }
dc_setmask 0
check "V1b the minter is PURE: the same arguments give the same sentence at mask 0 and at mask 15" \
  [list [expr {$v1p0 eq $v1p1}] [expr {$v1p0 eq $DC_ON}]] {1 1}

## The chord really speaks, on the HELD status line, LAST.
dc_setmask 1 ; dc_fire <Control-Alt-Key-6>
set v2a [list [dc_mask] [xschem get statusmsg]]
dc_fire <Control-Alt-Key-6>
set v2b [list [dc_mask] [xschem get statusmsg]]
dc_setmask 0 ; dc_fire <Control-Alt-Key-6>
set v2c [list [dc_mask] [xschem get statusmsg]]
check "V2a with OP showing, Ctrl-Alt-6 sets mask 9 and says the ON sentence" $v2a [list 9 $DC_ON]
check "V2b a second press restores mask 1 and says the OFF sentence"        $v2b [list 1 $DC_OFF]
check "V2c from mask 0 it sets mask 8 and says so - decluttering armed but inert" $v2c [list 8 $DC_ARM]
dc_setmask 0

## The structural row: the tail order the whole annotation surface uses, and the
## two things this proc must NOT do. Sabotage SB8 (dropping the redraw pair) is
## invisible until A3, so it has to be seen HERE, in the source.
set V3B [opa_proc_src [opa_slurp $DC_SRC] cadence::annot_declutter]
set v3_i_bbox [string first {update_all_sym_bboxes} $V3B]
set v3_i_draw [string first {xschem redraw} $V3B]
set v3_i_stat [string first {statusmsg -hold} $V3B]
check "V3 annot_declutter: integer-guards the pulled mask, tails bboxes -> redraw -> held status line LAST, uses _annot_fit, and never _annot_say" \
  [list [expr {[regexp {string is integer -strict} $V3B] ? 1 : 0}] \
        [expr {$v3_i_bbox > 0 ? 1 : 0}] \
        [expr {$v3_i_draw > $v3_i_bbox ? 1 : 0}] \
        [expr {$v3_i_stat > $v3_i_draw ? 1 : 0}] \
        [expr {[regexp {cadence::_annot_fit} $V3B] ? 1 : 0}] \
        [expr {[regexp {cadence::_annot_say} $V3B] ? 1 : 0}]] \
  {1 1 1 1 1 0}

# ============================================================================
# SECTION I — THE INVARIANTS
# ============================================================================
# ⚠ THE THREE ROWS BELOW ARE GREEN BEFORE A1 LANDS AND THAT IS THE POINT.
# They are CONTROLS, not claims about the writer: I1 is invariant I-A (feature A
# mutates no object), I3 is invariant I-C (with bit0 clear the declutter bit
# changes nothing) and is PERMANENT, and I2 used to say "A1 changes nothing on
# screen".
# ⚠ I2 HAS BEEN SUPERSEDED BY ROW A3 and re-purposed in place; see the note on
# the row itself. The "after A3 the two exports MUST differ" claim lives in row
# A3, on a fixture that can see the mask.

## ⚠ LOAD THE SHIPPED FILE, THEN `saveas` INTO THE SCRATCH DIR — never a plain
## `file copy` of the .sch. Loading the copy resolves its symbols against a
## different directory and the sheet comes up short of instances; and never a
## `xschem save` onto the shipped file, which would write into the working tree.
## The scratch copy is xschem's own output, so the save round trip below is a
## byte-exact comparison of two writes of the same in-memory schematic.
set I_FIX [file join $scratch declutter_fixture.sch]
xschem load [file join $repo xschem_library examples nand2.sch]
xschem saveas $I_FIX schematic
update idletasks

## Viewport form of `xschem print` (scheduler.c) — the no-viewport form yields an
## empty canvas headless. A WARMED export: one throwaway of the same format
## first, so a first-export difference cannot alias into a pass.
set I_VP {1600 1000 -200 -200 2400 1600}
proc dc_print {out} {
  if {[catch {eval [linsert $::I_VP 0 xschem print svg $out]} r]} { return RAISED:$r }
  if {![file isfile $out]} { return NO-FILE }
  set fd [open $out r] ; set d [read $fd] ; close $fd ; return $d
}
proc dc_print2 {out} { dc_print $out.warm ; return [dc_print $out] }
proc dc_annot {v} { dc_setmask $v ; catch {xschem update_all_sym_bboxes} }

set i1_m0 [xschem get modified]
set i1_b0 [opa_slurp $I_FIX]
set i1_mods {}
foreach s {<Key-6> <Control-Alt-Key-6> <Alt-Key-6> <Control-Alt-Key-6> <Control-Key-6>} {
  dc_fire $s ; lappend i1_mods [xschem get modified]
}
catch {xschem save}
set i1_b1 [opa_slurp $I_FIX]
check "I1 invariant I-A: the chord matrix sets no modify flag and leaves the .sch bytes identical" \
  [list $i1_m0 $i1_mods [expr {$i1_b0 eq $i1_b1}] [expr {[string length $i1_b0] > 0}]] \
  {0 {0 0 0 0 0} 1 1}

dc_annot 1 ; set i2_a [dc_print2 [file join $scratch i2_m1.svg]]
dc_annot 9 ; set i2_b [dc_print2 [file join $scratch i2_m9.svg]]
## ⚠ SUPERSEDED BY ROW A3 (item A3, 2026-09-02), AND RE-PURPOSED RATHER THAN
## DELETED. It used to say "A3 MUST REPLACE THIS ROW". Row A3 is that
## replacement, on a fixture that can see the mask (issue 1248: this one cannot
## — every mask exports byte-identically here, INCLUDING 1 vs 3). What is left
## is still worth a row, but it is a DIFFERENT claim: nand2.sch has no
## registered descriptor and no raw, so ruling D-6's per-instance gate never
## opens on it and the declutter must change NOTHING. That is the D-6
## "untouched" case at whole-sheet scale, and it stays byte-identical after A3.
check "I2 SUPERSEDED BY ROW A3 - now the D-6 control: on a sheet with no descriptor and no raw the declutter bit changes NOTHING" \
  [list [expr {$i2_a eq $i2_b}] [expr {[string length $i2_a] > 4000}]] {1 1}

dc_annot 0 ; set i3_a [dc_print2 [file join $scratch i3_m0.svg]]
dc_annot 8 ; set i3_b [dc_print2 [file join $scratch i3_m8.svg]]
check "I3 invariant I-C (PERMANENT): with OP off, the SVG at mask 0 and mask 8 is byte-identical" \
  [list [expr {$i3_a eq $i3_b}] [expr {[string length $i3_a] > 4000}]] {1 1}
dc_annot 0

# ============================================================================
# SECTION N — THE NAME CLASSIFIER (item A2: TEXT_ANNOT_NAME 1024)
# ============================================================================
# Item A2 adds ONE define and ONE arm: `TEXT_ANNOT_NAME 1024` in src/xschem.h,
# set in `set_text_flags()` (src/actions.c) on a WHOLE-STRING match against the
# three shipped name spellings. NOTHING ON SCREEN MOVES — the rung that reads
# the bit is item A3.
#
# ⚠ THE THREE SPELLINGS, AND WHY THREE. Re-measured on this tree 2026-09-02 with
# a brace-balanced record scanner over `git ls-files` (not a line grep):
#     .sym  3,686 files / 47,334 T records ->  @name 3,165 · @symname 1,386 ·
#                                              @spiceprefix@name 81   = 4,632
#     .sch    990 files /  4,009 T records ->  @name   150 · @symname    41 ·
#                                              @spiceprefix@name  0   =   191
# The third spelling is the trap: draw.c's shipped keep-name test compares
# against `@symname` and `@name` only, so gf180's whole FET family and the
# generic xschem_library/devices/nmos4.sym are missed. Row N14 pins that defect
# behaviourally; it is filed, not fixed, by item A2.
#
# ⚠ THE HONESTY LIMIT, SAID OUT LOUD (this is what issue 1248 is about).
# xText.flags is NOT observable from Tcl: `xschem get text_flags` does not even
# raise — it returns the EMPTY STRING through the generic `get` fall-through,
# with or without an index — and scheduler.c neither exposes text_hidden nor
# reads text[i].flags for anything but TEXT_FLOATER. Adding a reflection
# accessor means editing src/scheduler.c, which item A2 does not own. So:
#   * A2's POSITIVE evidence is STRUCTURAL — N1..N8, read out of the C source;
#   * A2's BEHAVIOURAL evidence can only be NEGATIVE — N11..N14, "nothing moved".
# A whole-file grep would be satisfied by A2's own comment (which names all three
# spellings), so every structural row below reads a C FUNCTION-BODY SLICE via
# `dc_cbody`, the C analogue of `opa_proc_src` and for exactly the same reason.
#
# RED BEFORE A2 LANDS (8): N1 N2 N3 N4 N5 N6 N7 N8
# GREEN BEFORE AND AFTER (6) — controls, not evidence for A2:
#   N9  PERMANENT — the catastrophic mis-implementation guard. A NAME arm in the
#       function that maps a content class onto an annot_show bit would make
#       every @name on every symbol follow the mask, and would additionally
#       blank the eleven shipped `@name` FLOATERS on mos_power_ampli.sch /
#       pv_ngspice.sch and their four mirrors. ⚠ ITEM A3 MUST NOT ADD IT THERE
#       EITHER: A3's rung goes in text_hidden AFTER the class tests.
#       ⚠ test_op_annot.tcl's row U35 CANNOT catch this — it counts CALLS.
#   N10 A3 MUST REPLACE THIS ROW (with a raw fixture, per issue 1248).
#   N11 the render oracle. ⚠ ON cmos_inv, NOT nand2 — see below.
#   N12 no file-format change, behavioural.  N13 the same, structural.
#   N14 1249 PINNED — WHOEVER FIXES 1249 FLIPS THIS ROW.
#
# ⚠ WHY NOT ROWS I2/I3's nand2 FIXTURE. src/cadence_style_rc sets
# XSCHEM_LIBRARY_PATH {} and repoints the registry at
# xschem_libs_newsym/library.defs. This suite MUST source that rc (there is no
# ::cadence without it), after which xschem_library/examples/nand2.sch loads
# with eight unresolved symbols and renders ZERO symbol text — so I2/I3 are
# byte-identical at every mask for a reason that has nothing to do with the
# mask. That is issue 1248, and it is item A3's to close. Section N therefore
# brings its own fixture: xschem_libs_newsym/examples/cmos_inv/schematic/
# cmos_inv.sch loads CLEANLY under the same rc (14 instances, 2 texts) and
# carries all three spellings on one sheet — M1/M2 from `@spiceprefix@name`
# (nmos4/pmos4), R1/V1/Vmeas from `@name`, and the schematic-own literals
# `@name` and `@symname`. DO NOT touch row I2 or its fixture from here.

## The body of ONE C function: from the column-0 definition line naming <name>
## followed by '(' — skipping a prototype, which ends in ';' — up to and
## INCLUDING the first later column-0 `}`. Every top-level function in actions.c
## and save.c closes its brace at column 0 (checked: set_text_flags,
## annot_content_class, annot_class_mask, text_hidden, save_text).
## ⚠ WHY A SLICE AND NOT A GREP, exactly as opa_proc_src above: A2's own comment
## names all three spellings, so a whole-file grep is satisfied by prose and
## stays green over a renamed no-op shim.
proc dc_cbody {path name} {
  set lines [split [opa_slurp $path] \n]
  set n [llength $lines] ; set start -1
  for {set i 0} {$i < $n} {incr i} {
    set l [lindex $lines $i]
    if {![regexp "^\[A-Za-z_\].*\[^A-Za-z0-9_\]${name}\\s*\\(" $l]} continue
    if {[string match {*;} [string trimright $l]]} continue     ;# a prototype
    set start $i ; break
  }
  if {$start < 0} { return {} }
  set out {}
  for {set i $start} {$i < $n} {incr i} {
    lappend out [lindex $lines $i]
    if {$i > $start && [regexp {^\}} [lindex $lines $i]]} break
  }
  return [join $out \n]
}

set N_ACTIONS [file join $repo src actions.c]
set N_SAVE    [file join $repo src save.c]
set N_BODY    [dc_cbody $N_ACTIONS annot_name_token]

# --- N1..N4: THE DEFINE AND THE BIT MAP -------------------------------------

## ⚠ NOT A NAIVE GREP. The literal string TEXT_ANNOT_NAME ALREADY appears in
## src/xschem.h — item A1 wrote it into prose — so `grep -c` reads 1 today and a
## feature-absent grep is already satisfied. `dc_define` anchors on `#define`.
check "N1 src/xschem.h defines TEXT_ANNOT_NAME exactly once as 1024" \
  [dc_define $DC_H TEXT_ANNOT_NAME] 1024

## ⚠ THE VALUE, NOT MERELY THE NAME — S6's discipline, one namespace over. A
## `#define TEXT_ANNOT_NAME 512` would collide with TEXT_ANNOT_CURRENT, compile
## clean, and make every @name follow annot_show bit 0. The eleven xText.flags
## bits are asserted as a sorted set of eleven distinct powers of two.
set N2_NAMES {TEXT_BOLD TEXT_OBLIQUE TEXT_ITALIC HIDE_TEXT TEXT_FLOATER \
              HIDE_TEXT_INSTANTIATED HIDE_TEXT_OP HIDE_TEXT_VOLTAGE \
              TEXT_ANNOT_VOLTAGE TEXT_ANNOT_CURRENT TEXT_ANNOT_NAME}
set N2_V {}
foreach n $N2_NAMES { lappend N2_V [dc_define $DC_H $n] }
## `lsort -integer` raises on MISSING; sort only once every value is a number,
## and report the unsorted list when one is not (copied verbatim from row S6).
set N2_ok 1
foreach v $N2_V { if {![string is integer -strict $v]} { set N2_ok 0 } }
if {$N2_ok} { set N2_SET [lsort -integer -unique $N2_V] } else { set N2_SET $N2_V }
check "N2 the eleven xText.flags bits are eleven distinct powers of two ending 1024" \
  [list $N2_SET [llength $N2_V]] \
  {{1 2 4 8 16 32 64 128 256 512 1024} 11}

## The brief's explicit worry, pinned: ANNOT_SHOW_NOPARAM 8 (item A1) lives in
## the xctx->annot_show mask, TEXT_ANNOT_NAME 1024 in xText.flags. Different
## namespaces; src/xschem.h says so in prose and this row says so by value.
check "N3 the two namespaces do not touch: ANNOT_SHOW_NOPARAM is 8, TEXT_ANNOT_NAME is 1024" \
  [list [dc_define $DC_H ANNOT_SHOW_NOPARAM] [dc_define $DC_H TEXT_ANNOT_NAME] \
        [expr {[dc_define $DC_H ANNOT_SHOW_NOPARAM] eq [dc_define $DC_H TEXT_ANNOT_NAME]}]] \
  {8 1024 0}

## The `int flags;` bit map inside xText documents bits 0-9 and closes with
## "(bits 8/9 carry the implicit content class...)". It is the thing the NEXT
## implementer reads before choosing a value, so a stale map is a real defect
## here: A2 must add the `bit 10 : TEXT_ANNOT_NAME` line AND widen the closing
## sentence to `bits 8/9/10`.
check "N4 the xText.flags bit map is not stale: it documents bit 10 and closes with bits 8/9/10" \
  [list [opa_n_grep $DC_H {bit 10 : TEXT_ANNOT_NAME}] [opa_n_grep $DC_H {bits 8/9/10}]] \
  {1 1}

# --- N5..N8: THE CLASSIFIER ITSELF, READ OUT OF THE C -----------------------

## THE HEADLINE STRUCTURAL ROW. The comparison set is EXACTLY three literals: a
## fourth, a dropped third spelling (`@spiceprefixname` re-introduces the shipped
## draw.c bug verbatim) or a renamed no-op shim all red here.
check "N5 annot_name_token compares against exactly the three shipped spellings" \
  [list [lsort [regexp -all -inline {"[^"]*"} $N_BODY]] \
        [llength [regexp -all -inline {"[^"]*"} $N_BODY]]] \
  [list [lsort [list {"@name"} {"@symname"} {"@spiceprefix@name"}]] 3]

## WHOLE-STRING, NOT SUBSTRING — the existing classifier's discipline and the
## whole reason annot_content_class is correct. Each spelling must be compared
## LENGTH-EXACT: the trim walks two pointers into a const string and cannot
## NUL-terminate it, so a length + strncmp pairing is forced, not a style
## preference. The lengths are computed in Tcl, never hardcoded here, so a wrong
## constant in the C reds this row. `strstr` anywhere in the body IS the
## substring rewrite and must not appear.
set N6_PAIR {}
foreach sp {@name @symname @spiceprefix@name} {
  set L [string length $sp] ; set hit 0
  foreach l [split $N_BODY \n] {
    if {[string first "\"$sp\"" $l] < 0} continue
    ## ${L} in braces, NOT $L: bare `$L(` is parsed by Tcl as an ARRAY reference and
    ## raises "variable isn't array". Latent until the C function body is non-empty —
    ## before item A2 landed, dc_cbody returned {} and this line was never reached.
    if {[regexp "(^|\[^0-9\])${L}(\[^0-9\]|\$)" $l]} { set hit 1 ; break }
  }
  lappend N6_PAIR $hit
}
set N6_STRSTR 0
foreach l [split $N_BODY \n] { if {[string first strstr $l] >= 0} { incr N6_STRSTR } }
set N6_AT   [expr {[regexp {\[0\]\s*!=\s*'@'} $N_BODY] ? 1 : 0}]
set N6_TRIM [expr {([regexp {(\+\+s|s\+\+)} $N_BODY] && [regexp {(--e|e--)} $N_BODY]) ? 1 : 0}]
check "N6 whole-string: each spelling paired with its own length, no strstr, the '@' fast reject and the two-ended trim" \
  [list $N6_PAIR $N6_STRSTR $N6_AT $N6_TRIM] \
  {{1 1 1} 0 1 1}

## ⚠ CLOSES A HOLE FOUND BY MUTATION, NOT BY READING (item A2's adversary
## pass, 2026-09-02). N6 above pairs each spelling with its OWN length on the
## same line, but it never reads the OPERATOR — so a `len >= 5` mutation
## survives it, and that mutation classifies `@name_foo`, `@names` and the ~34
## shipped `@name <param>` records: precisely the substring failure the brief's
## ACCEPT list names and the one this item exists to prevent. Assert the
## operator itself: three `len ==` comparisons and no relational length test
## anywhere in the body. The mutation matrix that found this hole is in
## doc/claude/op_param_batch/receipts/A2.md.
set N6b_EQ 0 ; set N6b_REL 0
foreach l [split $N_BODY \n] {
  if {[regexp {len\s*==} $l]} { incr N6b_EQ }
  if {[regexp {len\s*(>=|<=|>|<)} $l]} { incr N6b_REL }
}
check "N6b whole-string: the three length comparisons are EQUALITY and no relational length test exists" \
  [list $N6b_EQ $N6b_REL] {3 0}

## THE NEAR-MISS TABLE. ⚠ STRUCTURAL, NOT BEHAVIOURAL — the bit is invisible to
## Tcl (see the section header), so this row drives a Tcl oracle built FROM THE
## LITERAL SET READ OUT OF THE C rather than from a hardcoded list. It therefore
## reds before A2 and reds on a dropped or renamed spelling, but it tests the
## SET, not the discipline; N6 is the only row that sees a substring rewrite.
## ⚠ THE FIRST FIVE REJECTS OCCUR ZERO TIMES IN THE SHIPPED TREE — legitimate
## synthetic rows, but not evidence about real files. The last two are what the
## tree ACTUALLY ships: 29 multi-line .sym records and 13 .sch records across 11
## distinct strings put the name and a parameter in ONE text record
## (`@name\n@value` in isource/filesource, `@symname\n@file`, `@name\n@wn/@ln\n
## @modeln` in inv-2/passgate/sky130's passgate_nlvt). A trimmed whole-string
## match correctly denies all 42 — which is right for A2, and means that once
## A3's rung lands those devices lose their NAMES along with their parameters.
## That is a design consequence of ruling D-1, not a bug in A2.
proc dc_name_oracle {lst s} {
  return [expr {[lsearch -exact $lst [string trim $s " \t\n\r"]] >= 0 ? 1 : 0}]
}
set N7_SET {}
foreach q [regexp -all -inline {"[^"]*"} $N_BODY] { lappend N7_SET [string range $q 1 end-1] }
set N7_IN [list "@name" "@symname" "@spiceprefix@name" " @name " "@symname\n" \
                "x=@name" "@names" "@name_foo" "tcleval(@name)" "name" \
                "@name\n@value" "@symname\n@file"]
set N7_GOT {}
foreach s $N7_IN { lappend N7_GOT [dc_name_oracle $N7_SET $s] }
check "N7 the three spellings classify (padded too) and the seven near-misses do not" \
  $N7_GOT {1 1 1 1 1 0 0 0 0 0 0 0}

## ADDITIVE AND UNCONDITIONAL, PROVED BY ORDER. Decision (item A2, receipt):
## TEXT_ANNOT_NAME is set OUTSIDE the `if(annot_class_free(t->flags))` gate,
## unlike the two classes beside it. The gate exists for ONE named mechanism —
## the two class bits are a VISIBILITY AUTHORITY that text_hidden early-returns
## on BEFORE show_hidden_texts, so an implicit class stacked on an explicit
## `hide=` would silently move that text from View > Show hidden texts to the
## annotation mask. TEXT_ANNOT_NAME is deliberately not a visibility authority
## (row N9 pins that permanently), so it can move no text between switches and
## the mechanism the gate protects against does not exist for it. Measured
## first, as the brief demanded: ZERO of the 4,823 shipped name records carry
## any `hide=` token, so gated and ungated are byte-identical on every file in
## this tree — the choice is about the USER's own future files only.
## The comparison is LINE-WISE, so a reflow cannot move it, and it is also the
## only row that proves the bit is ever actually ASSIGNED.
set N8_B [dc_cbody $N_ACTIONS set_text_flags]
set N8_i -1 ; set N8_g -1 ; set N8_k 0
foreach l [split $N8_B \n] {
  if {$N8_i < 0 && [regexp {\|=\s*TEXT_ANNOT_NAME} $l]} { set N8_i $N8_k }
  if {$N8_g < 0 && [string first {annot_class_free(t->flags)} $l] >= 0} { set N8_g $N8_k }
  incr N8_k
}
check "N8 set_text_flags sets TEXT_ANNOT_NAME, and does so BEFORE the annot_class_free gate" \
  [list [expr {$N8_i >= 0 ? 1 : 0}] [expr {$N8_g >= 0 ? 1 : 0}] \
        [expr {($N8_i >= 0 && $N8_g > $N8_i) ? 1 : 0}]] \
  {1 1 1}

## ⚠ ALSO FROM THE MUTATION PASS. N8 proves a `|= TEXT_ANNOT_NAME` line
## exists above the gate, but not what the guard READS: changing the call to
## `annot_name_token(t->prop_ptr)` leaves the feature wholly inert — the bit
## is then never set on any real text — and N8 stays green. The bit must be
## computed FROM THE TEXT, so pin the argument. See the mutation matrix in
## doc/claude/op_param_batch/receipts/A2.md.
set N8b_TXT 0 ; set N8b_OTHER 0
foreach l [split $N8_B \n] {
  if {[string first "annot_name_token(" $l] < 0} continue
  if {[regexp {annot_name_token\(\s*t->txt_ptr\s*\)} $l]} { incr N8b_TXT } else { incr N8b_OTHER }
}
check "N8b the name bit is computed FROM THE TEXT: the call in set_text_flags reads t->txt_ptr" \
  [list $N8b_TXT $N8b_OTHER] {1 0}

# --- N9, N10: THE TWO FUNCTIONS A2 MUST NOT TOUCH ---------------------------

## ⚠ PERMANENT — ITEM A3 MUST NOT ADD IT HERE EITHER. The function that maps a
## content class onto an annot_show bit returns 0 for any bit it does not name,
## and THAT is why item A2 is a no-op on screen by construction rather than by
## care. A NAME arm here would make every @name on every symbol follow the mask
## and would additionally blank the eleven shipped `@name` FLOATERS on
## mos_power_ampli.sch / pv_ngspice.sch and their four mirrors (a schematic-own
## floater is NOT exempted by the ctx guard). A3's rung belongs in text_hidden,
## AFTER the class tests. ⚠ test_op_annot.tcl's row U35 cannot catch this: it
## counts CALLS, not contents. The second element is the non-vacuity control —
## a mistyped function name would otherwise slice nothing and pass.
set N9_B [dc_cbody $N_ACTIONS annot_class_mask]
check "N9 PERMANENT: the content-class-to-mask function still names no NAME bit" \
  [list [expr {[string first TEXT_ANNOT_NAME $N9_B] >= 0 ? 1 : 0}] \
        [expr {[string first TEXT_ANNOT_CURRENT $N9_B] >= 0 ? 1 : 0}]] \
  {0 1}

## ⚠ REPLACED BY ITEM A3, exactly as this row's old name demanded. It used to
## say "text_hidden itself is unchanged and names no NAME bit", which was the
## most honest thing item A2 could say about the eleventh call site without a
## raw fixture. A3 has that fixture (section A) and three behavioural windows on
## the predicate, so this row now carries the ONE structural fact behaviour
## cannot see: `text_hidden(flags, ctx)` is a pure DELEGATE onto
## `text_hidden_core(flags, ctx, n)` passing n = -1. That -1 is why the rung is
## unreachable for get_annot_overlay()'s synthetic literal call TWICE OVER —
## once by placement (row A20) and once by the index — so a declutter can never
## switch the annotation overlay off. Rows A9 and A21 are the other two halves.
## ⚠ THE THIRD ELEMENT IS THE NON-VACUITY CONTROL: a renamed or missing function
## slices to {} and would otherwise satisfy two `string first` misses.
set N10_B [dc_cbody $N_ACTIONS text_hidden]
check "N10 REPLACED BY A3: the two-argument entry is a pure delegate onto text_hidden_core, passing n = -1" \
  [list [expr {[string length $N10_B] > 0}] \
        [expr {[string first {text_hidden_core} $N10_B] >= 0 ? 1 : 0}] \
        [expr {[regexp {text_hidden_core\s*\([^)]*-1\s*\)} $N10_B] ? 1 : 0}]] \
  {1 1 1}

# --- N11..N14: NOTHING MOVES ON SCREEN, AND THE .sch IS UNTOUCHED -----------

## ⚠ LOAD THE SHIPPED FILE, THEN `saveas` INTO THE SCRATCH DIR — row I1's
## warnings apply verbatim: never a plain `file copy` of the .sch (the copy
## resolves its symbols against a different directory and comes up short of
## instances), and never a `xschem save` onto the shipped file.
set N_FIX [file join $scratch a2_name_fixture.sch]
xschem load [file join $repo xschem_libs_newsym examples cmos_inv schematic cmos_inv.sch]
xschem saveas $N_FIX schematic
update idletasks

## The viewport form of `xschem print`, and a WARMED export, exactly as section I
## — one throwaway of the same format first, so a first-export difference cannot
## alias into a pass. A separate proc from dc_print because the viewport differs;
## section I's I_VP is left alone.
set N_VP {2000 1600 0 -520 420 -20}
proc dc_nprint {out} {
  if {[catch {eval [linsert $::N_VP 0 xschem print svg $out]} r]} { return RAISED:$r }
  if {![file isfile $out]} { return NO-FILE }
  set fd [open $out r] ; set d [read $fd] ; close $fd ; return $d
}
proc dc_nprint2 {out} { dc_nprint $out.warm ; return [dc_nprint $out] }
## Every <text ...>BODY</text> body of an SVG export, in document order.
proc dc_ntexts {svg} {
  set o {}
  foreach m [regexp -all -inline {<text[^>]*>[^<]*} $svg] {
    lappend o [string range $m [expr {[string first > $m] + 1}] end]
  }
  return $o
}

foreach m {0 1 8 9} { dc_annot $m ; set N_SVG($m) [dc_nprint2 [file join $scratch a2_m$m.svg]] }
dc_annot 0
## NON-VACUITY BY CONTENT, NOT BY LENGTH: the byte count moves with the length of
## the scratch path (it is drawn on the sheet), so it is never asserted. What is
## asserted is that all three spellings, a parameter text item A3 will hide, and
## the two schematic-own literals really do render here.
set N11_MISSING {}
foreach t {>M1< >M2< >R1< >V1< >Vmeas< >WN/LLN/1< >WP/LLP/1< >@name< >@symname<} {
  if {[string first $t $N_SVG(0)] < 0} { lappend N11_MISSING $t }
}
check "N11 A2 changes nothing on screen: the SVG is byte-identical at masks 0, 1, 8 and 9, and is not vacuous" \
  [list [expr {$N_SVG(0) eq $N_SVG(1)}] [expr {$N_SVG(0) eq $N_SVG(8)}] \
        [expr {$N_SVG(0) eq $N_SVG(9)}] $N11_MISSING] \
  {1 1 1 {}}

## The acceptance row "flags is still NEVER serialised, so a saved/reloaded .sch
## is byte-identical", behaviourally. The scratch copy is xschem's own output, so
## this compares two writes of the same in-memory schematic.
set N12_B0 [opa_slurp $N_FIX]
set N12_MODS {}
foreach m {0 1 8 9} { dc_annot $m ; lappend N12_MODS [xschem get modified] }
catch {xschem save}
set N12_B1 [opa_slurp $N_FIX]
dc_annot 0
check "N12 invariant I-A: a mask sweep sets no modify flag and the .sch bytes are identical" \
  [list $N12_MODS [expr {$N12_B0 eq $N12_B1}] [expr {[string length $N12_B0] > 0}]] \
  {{0 0 0 0} 1 1}

## The same acceptance row STRUCTURALLY, which is what makes it honest rather
## than a coincidence of this fixture: save_text writes txt_ptr, six numbers and
## prop_ptr, and never `flags`. So no file-format change and XSCHEM_FILE_VERSION
## does not move. PERMANENT.
set N13_B [dc_cbody $N_SAVE save_text]
check "N13 PERMANENT: save_text writes txt_ptr and prop_ptr and never writes flags" \
  [list [expr {[string first txt_ptr  $N13_B] >= 0 ? 1 : 0}] \
        [expr {[string first prop_ptr $N13_B] >= 0 ? 1 : 0}] \
        [expr {[string first flags    $N13_B] >= 0 ? 1 : 0}] \
        [expr {[string length $N13_B] > 0}]] \
  {1 1 0 1}

## ⚠ 1249 FIXED — THIS ROW WAS FLIPPED BY ITEM A3, DELIBERATELY. Item A2 wrote
## it as a DEFECT RECORDED: the shipped keep-name test was THREE byte-identical
## copies (draw.c, svgdraw.c, psprint.c), each comparing against `@symname` and
## `@name` only, so at hide_symbols=2 a device whose name text is
## `@spiceprefix@name` lost its name on screen, in SVG and in PDF — measured
## here, not read: R1/V1/Vmeas (`@name`) survived and M1/M2 (nmos4/pmos4) did
## not, i.e. {1 1 1 0 0}. Item A2 owned none of those three files and filed the
## issue; item A3 rewrites exactly those three loops and fixes it as it passes,
## replacing all three copies with one call to the exported annot_name_token()
## — four copies of one predicate become one builder (invariant I1). The
## expectation below therefore moved {1 1 1 0 0} -> {1 1 1 1 1} ON PURPOSE.
## Row A18 carries the same flip on section A's fixture WITH the annotation
## live, which is the state row A17 says must not double-strip.
set N14_HS 0 ; catch {set N14_HS $::hide_symbols}
catch {xschem set hide_symbols 2} ; catch {xschem update_all_sym_bboxes}
set N14_T [dc_ntexts [dc_nprint2 [file join $scratch a2_hs2.svg]]]
catch {xschem set hide_symbols $N14_HS} ; catch {xschem update_all_sym_bboxes}
set N14_GOT {}
foreach t {R1 V1 Vmeas M1 M2} { lappend N14_GOT [expr {[lsearch -exact $N14_T $t] >= 0 ? 1 : 0}] }
check "N14 1249 FIXED (was PINNED): at hide_symbols=2 every device keeps its name, including the spiceprefix-at-name FETs" \
  $N14_GOT {1 1 1 1 1}

dc_annot 0

# ============================================================================
# SECTION A — THE DRAW RUNG AND THE PER-INSTANCE GATE (item A3, feature 1244)
# ============================================================================
# ⚠ THE ROW NAMES A0..A29 ARE THE PLAN'S, NOT THE ITEM NAMES. `A1` here is a
# CHECK in this file; item A1 is the mask bit that landed in commit 59b67766.
# doc/claude/op_param_batch/PLAN.md's A3 cell names these rows and the sabotage
# matrix predicts reds by them, so they are kept verbatim.
#
# WHAT A3 ADDS. One rung in the shared visibility predicate: in an INSTANCE
# context, on an instance that actually got operating-point numbers (ruling
# D-6), with BOTH ANNOT_SHOW_OP and ANNOT_SHOW_NOPARAM set, every text that
# carries neither TEXT_ANNOT_NAME nor an annotation class is hidden (ruling
# D-1: pin labels included, "we are only interested in name and annotation of
# OP info"). Plus the four defects the item inherits: 1246, 1247, 1248, 1249.
#
# ⚠ THE FIXTURE IS PURPOSE-BUILT AND THAT IS THE POINT — ISSUE 1248. Rows I2/I3
# above render xschem_library/examples/nand2.sch with no raw and eight
# unresolved symbols, and EVERY mask exports byte-identically there: measured
# 0=1 1=1 2=1 3=1 8=1 9=1 11=1, INCLUDING 1 vs 3, a pair that genuinely differ
# in meaning. A3 can land, work perfectly, and leave I2 green. So this section
# brings a fixture that can SEE the mask: a symbol whose text records cover
# every class the rung must tell apart, two instances of it with a real
# operating-point raw behind them, plus a descriptor-less shipped resistor and a
# type=subcircuit instance for ruling D-6's two "untouched" cases. Row A4 is the
# non-vacuity control the nand2 fixture could never give — mask 1 and mask 3
# differ here BEFORE the rung matters.
#
# THE SYMBOL'S SEVEN TEXT RECORDS, and which arm of the predicate each one is:
#   @name              TEXT_ANNOT_NAME  (item A2)      KEPT under declutter
#   @symname           TEXT_ANNOT_NAME                 KEPT
#   @spiceprefix@name  TEXT_ANNOT_NAME — the spelling  KEPT   (and the one
#                      draw.c's shipped keep-name test misses: issue 1249)
#   A3OPTEXT   hide=op       explicit annotation class KEPT while bit0 is on
#   A3VOLTTEXT hide=voltage  explicit annotation class KEPT while bit1/bit2 on
#   A3TRUETEXT hide=true     ordinary hidden text      hidden; and STILL hidden
#                      under declutter even with View > Show hidden texts ON,
#                      which is what makes the rung's PLACEMENT visible (row A10)
#   A3W=@w             a parameter                     HIDDEN under declutter
#   A3GATE             a pin label                     HIDDEN under declutter (D-1)
# The last two sit far outside the symbol body ON PURPOSE: they are what
# stretches inst[i].x1..y2, so the click-target rows A14/A15 can watch that box
# shrink instead of arguing about it.
#
# RED BEFORE A3 LANDS (18): A1 A3 A10 A11 A12 A14 A15 A18 A19 A20 A22 A23 A24
#                           A25 A27 A29 — plus the two REPLACED rows N10/N14.
# GREEN BEFORE AND AFTER (12) — controls, not evidence for A3:
#   A0 A2 A28   the fixture is live and the strings A1/A27 assert absent really
#               are present at mask 1;
#   A4          issue 1248 hole 1: 1 vs 3 differ here;
#   A5 A16      invariant I-C (PERMANENT): with bit0 clear, bit3 changes nothing,
#               in pixels AND in geometry;
#   A6 A7 A8    ruling D-6's two untouched cases and D-1's kept name;
#   A9          THE 1248 ROW THAT MATTERS: get_annot_overlay() paints exactly
#               when it did. A declutter that switches the annotation overlay
#               off would leave A1 and A3 GREEN;
#   A13         invariant I-A: no byte of the .sch moves;
#   A17         hide_symbols=2 closes the D-6 gate, so the rung must not fire;
#   A21 A26     the eleventh call site is byte-unchanged; 0688 is not weakened.
#
# ⚠ A9 AND A21 ARE THE PAIR THAT MATTER MOST AND BOTH ARE GREEN TODAY. The
# failure they exist for — the declutter switching the annotation overlay off,
# the feature eating itself — looks like SUCCESS in a suite that only checks
# that the parameters vanished.

set A_VP  {2400 1600 100 -420 1000 -20}
set A_SYM [file join $scratch a3fet.sym]
set A_FIX [file join $scratch a3fix.sch]
set A_SAV [file join $scratch a3fix_saved.sch]
set A_RAW [file join $scratch a3fix.raw]

## The fixture symbol. Written here rather than picked off the tree because no
## shipped symbol carries all six visibility classes on one device.
set A_FD [open $A_SYM w]
puts $A_FD {v {xschem version=3.4.5 file_version=1.2}
G {}
K {type=a3nmos
format="@spiceprefix@name @pinlist @model w=@w l=@l m=@m"
template="name=M1 model=a3n w=1u l=0.15u m=1 spiceprefix=X"
}
V {}
S {}
E {}
L 4 -20 -20 20 -20 {}
L 4 20 -20 20 20 {}
L 4 20 20 -20 20 {}
L 4 -20 20 -20 -20 {}
B 5 -22.5 -12.5 -17.5 -7.5 {name=d dir=inout}
B 5 -22.5 7.5 -17.5 12.5 {name=g dir=inout}
T {@name} 0 -40 0 0 0.2 0.2 {}
T {@symname} 0 -25 0 0 0.2 0.2 {}
T {@spiceprefix@name} 0 -10 0 0 0.2 0.2 {}
T {A3OPTEXT} 0 5 0 0 0.2 0.2 {hide=op}
T {A3VOLTTEXT} 0 20 0 0 0.2 0.2 {hide=voltage}
T {A3TRUETEXT} 0 35 0 0 0.2 0.2 {hide=true}
T {A3W=@w} 150 55 0 0 0.2 0.2 {}
T {A3GATE} -150 -80 0 0 0.2 0.2 {}}
close $A_FD

## The sheet. `devices/res` and `examples/nand2` are REGISTRY-qualified and
## resolve through the absolute XSCHEM_LIBRARY_DEFS src/cadence_style_rc set, so
## this file is loadable from the scratch directory (row I1's warning about a
## plain `file copy` is about a RELATIVE resolution, which none of these are).
set A_FD [open $A_FIX w]
puts $A_FD "v {xschem version=3.4.5 file_version=1.2}
G {}
V {}
S {}
E {}
C \{$A_SYM\} 300 -300 0 0 \{name=M1\}
C \{$A_SYM\} 300 -120 0 0 \{name=M2\}
C \{devices/res\} 700 -300 0 0 \{name=R1
value=10
m=1\}
C \{examples/nand2\} 800 -120 0 0 \{name=X1\}"
close $A_FD

## An OP raw in test_op_annot.tcl's opa_o_mkrlraw shape, one point, one value
## per vector. The vector NAMES come from op_annot::vector — invariant I1, ONE
## name builder — so this fixture cannot drift from the descriptor.
##
## ⚠ ITEM A6 EXTENDED THIS WRITER RATHER THAN ADDING A SECOND ONE (invariant I1
## again, one fixture minter). The optional trailing <types> is the per-column
## THIRD field of the `Variables:` block — the field ngspice writes as `voltage`
## / `current`, and as `current dims=0` for a `.save` card the model does not
## publish (doc/claude/code_analysis/1244_op_param_list_measurements.md §22,
## spec landmine 11). It defaults to `voltage` for every column, so every call
## written before A6 mints byte-identical bytes. Rows A45/A46 are the two raws
## that differ ONLY in this field, which is the whole of issue 1259: with it
## stripped they are the same file.
proc a3_mkraw {path pairs {types {}}} {
  set f [open $path w]
  puts -nonewline $f "Title: A3 declutter fixture\nDate: Mon Jan 1 00:00:00 2026\n"
  puts -nonewline $f "Plotname: Operating Point\nFlags: real\n"
  puts -nonewline $f "No. Variables: [expr {[llength $pairs]/2}]\nNo. Points: 1\nVariables:\n"
  set k 0
  foreach {v val} $pairs {
    set a3_ty [lindex $types $k]
    if {$a3_ty eq {}} { set a3_ty voltage }
    puts -nonewline $f "\t$k\t$v\t$a3_ty\n" ; incr k
  }
  puts -nonewline $f "Values:\n"
  set k 0
  foreach {v val} $pairs {
    if {$k == 0} { puts -nonewline $f "0\t$val\n" } else { puts -nonewline $f "\t$val\n" }
    incr k
  }
  close $f
}
## The viewport form of `xschem print`, warmed exactly as sections I and N.
proc a3_pr {out {fmt svg}} {
  if {[catch {eval [linsert $::A_VP 0 xschem print $fmt $out]} r]} { return RAISED:$r }
  if {![file isfile $out]} { return NO-FILE }
  set fd [open $out r] ; set d [read $fd] ; close $fd ; return $d
}
proc a3_pr2 {out {fmt svg}} { a3_pr $out.warm $fmt ; return [a3_pr $out $fmt] }
## 1/0 per name, membership in an SVG text list (dc_ntexts, section N).
proc a3_hasl {lst names} {
  set o {}
  foreach n $names { lappend o [expr {[lsearch -exact $lst $n] >= 0 ? 1 : 0}] }
  return $o
}
## The `Instance:` half of `xschem instance_bbox <n>`, as four numbers.
proc a3_ibox {n} {
  set r {}
  catch {set r [xschem instance_bbox $n]}
  if {[regexp {Instance:\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)} $r -> x1 y1 x2 y2]} {
    return [list $x1 $y1 $x2 $y2]
  }
  return NO-BBOX
}
## op_annot::text without a raise reaching the suite.
proc a3_optext {n} { set r {} ; catch {set r [op_annot::text $n]} ; return $r }
proc a3_ovl {} { set v -1 ; catch {set v [xschem get annot_overlay_count]} ; return $v }
## A numeric comparison that reds instead of aborting the section when a bbox
## reader answered NO-BBOX.
proc a3_lt {a b} { if {[catch {expr {$a < $b}} r]} { return BAD } ; return [expr {$r ? 1 : 0}] }

xschem load $A_FIX
update idletasks
xschem saveas $A_SAV schematic
update idletasks

## The descriptor is registered on a PRIVATE symbol type, so no shipped symbol
## and no PDK registration is disturbed by it, and the `match`-narrowed sky130 /
## gf180 / IHP descriptors rows A27/A28 source later cannot collide with it.
catch {op_annot::register a3nmos \
  [list devpath {@m.@path@name} params {{zid zid 0} {zgm zgm 1}}]}
set A_PAIRS {}
foreach d {M1 M2} vi {1.11e-05 2.22e-05} vg {3.33e-04 4.44e-04} {
  catch {lappend A_PAIRS [op_annot::vector $d zid] $vi [op_annot::vector $d zgm] $vg}
}
a3_mkraw $A_RAW $A_PAIRS
catch {xschem annotate_op $A_RAW 0}
update idletasks

## The warmed exports and the overlay-paint delta of each, in one sweep.
foreach m {0 1 3 8 9 11} {
  dc_annot $m
  set A_C0($m) [a3_ovl]
  set A_SVG($m) [a3_pr2 [file join $scratch a3_m$m.svg]]
  set A_DELTA($m) [expr {[a3_ovl] - $A_C0($m)}]
  set A_T($m) [dc_ntexts $A_SVG($m)]
}
dc_annot 0

set A_NAMES  {M1 a3fet XM1 M2 XM2}
set A_OPROWS {{zid = 11.1u} {zgm = 333u}}
set A_PARAMS {A3W=1u A3GATE}

check "A0 CONTROL the A3 fixture is live: 4 instances, a NUMERIC block on M1, none on R1, and the overlay paints at mask 1" \
  [list [xschem get instances] \
        [expr {[string first {11.1u} [a3_optext M1]] >= 0 ? 1 : 0}] \
        [expr {[string trim [a3_optext R1]] eq {} ? 1 : 0}] \
        $A_DELTA(1)] \
  {4 1 1 8}

## THE HEADLINE. Ruling D-1: name + operating-point block, and nothing else.
check "A1 HEADLINE at mask 9 an annotated device draws its names and its OP rows ONLY - the parameter and the pin label are gone" \
  [list [a3_hasl $A_T(9) $A_NAMES] [a3_hasl $A_T(9) $A_OPROWS] [a3_hasl $A_T(9) $A_PARAMS]] \
  {{1 1 1 1 1} {1 1} {0 0}}

## ⚠ NON-VACUITY FOR A1, BY CONTENT AND NEVER BY BYTE COUNT (the scratch path is
## drawn on the sheet). Every string A1 asserts ABSENT at mask 9 is PRESENT at
## mask 1 on the very same fixture, so A1 cannot pass by rendering nothing.
check "A2 NON-VACUITY for A1: at mask 1 the parameter and the pin label ARE drawn, beside the names and the OP rows" \
  [list [a3_hasl $A_T(1) $A_NAMES] [a3_hasl $A_T(1) $A_OPROWS] [a3_hasl $A_T(1) $A_PARAMS]] \
  {{1 1 1 1 1} {1 1} {1 1}}

## REPLACES ROW I2 (issue 1248). I2 renders a fixture that cannot see the mask;
## this one can, and after A3 the two exports MUST differ.
check "A3 REPLACES ROW I2: the warmed SVG at mask 1 and at mask 9 now DIFFER, and neither is vacuous" \
  [list [expr {$A_SVG(1) ne $A_SVG(9)}] \
        [expr {[string length $A_SVG(1)] > 4000}] \
        [expr {[string length $A_SVG(9)] > 4000}]] \
  {1 1 1}

## ISSUE 1248 HOLE 1, CLOSED. On row I2's nand2 fixture mask 1 and mask 3 export
## byte-identically although they differ in MEANING (bit1 is the node-voltage
## switch). Here they do not: A3VOLTTEXT carries `hide=voltage` and answers bit1.
## This is the control that says the fixture can see the mask at all.
check "A4 1248 HOLE 1 CLOSED: on this fixture mask 1 and mask 3 already differ BEFORE the rung matters" \
  [list [expr {$A_SVG(1) ne $A_SVG(3)}] \
        [a3_hasl $A_T(3) {A3VOLTTEXT}] [a3_hasl $A_T(1) {A3VOLTTEXT}]] \
  {1 1 0}

## ROW I3 REBUILT ON A FIXTURE THAT CAN SEE THE MASK — invariant I-C, PERMANENT.
## Ruling D-8: "declutter is active ONLY when OP info is displayed."
check "A5 INVARIANT I-C (PERMANENT): with ANNOT_SHOW_OP clear the declutter bit changes NOTHING - mask 0 == mask 8, byte for byte" \
  [list [expr {$A_SVG(0) eq $A_SVG(8)}] [expr {[string length $A_SVG(0)] > 4000}]] \
  {1 1}

## RULING D-6, first untouched case: a descriptor-less device. R1 is the shipped
## devices/res; `op_annot::text R1` is blank (row A0), so the gate never opens.
check "A6 D-6: at mask 9 a descriptor-less device is UNTOUCHED - R1 keeps its name, its value and its m= text" \
  [a3_hasl $A_T(9) {R1 10 m=1}] {1 1 1}

## RULING D-6, second untouched case: a type=subcircuit instance. Its name, its
## symbol name and BOTH its parameter texts survive.
check "A7 D-6: at mask 9 a type=subcircuit instance is UNTOUCHED - name, symname and both parameter texts" \
  [a3_hasl $A_T(9) [list X1 nand2 {P: 8u/1u} {N: 5u/1u}]] {1 1 1 1} 

## RULING D-1's other half, isolated: the NAMES survive. All three spellings.
check "A8 D-1: the names survive the declutter - @name, @symname and @spiceprefix@name are all still drawn at mask 9" \
  [a3_hasl $A_T(9) {M1 a3fet XM1 M2 XM2}] {1 1 1 1 1}

## ⚠ THE 1248 ROW THAT MATTERS, AND IT IS GREEN BEFORE AND AFTER. The eleventh
## text_hidden() call site (get_annot_overlay, actions.c) passes a SYNTHETIC
## literal and is asking "would an OP text be visible right now?" as a proxy for
## "should the overlay paint?". A rung placed above it switches the annotation
## overlay OFF — the feature eating itself — and rows A1 and A3 would still
## PASS. Measured before the change, per two warmed exports: 0 at mask 0, 8 at
## mask 1, 0 at mask 8, 8 at mask 9. Those four numbers must not move.
check "A9 get_annot_overlay PAINTS EXACTLY WHEN IT DID: the overlay delta per two warmed exports is 0/8/0/8 at masks 0/1/8/9" \
  [list $A_DELTA(0) $A_DELTA(1) $A_DELTA(8) $A_DELTA(9)] {0 8 0 8}

## ⚠ THE RUNG'S PLACEMENT, AND IT IS FORCED RATHER THAN STYLISTIC. Both shipped
## Op-Annotate menu bodies do `set show_hidden_texts 1` ONE LINE above the mask
## write (src/xschem.tcl), so a rung below the show_hidden_texts arm would be a
## no-op on the exact workflow the feature was written for. The first element is
## the non-vacuity control on this very symbol: at mask 0 the hide=true text DOES
## appear when the switch is on.
## ⚠ THROUGH THE Tcl VARIABLE, NOT `xschem set`: measured on this tree, the C
## field is re-pulled from `show_hidden_texts` by the bulk evaluation
## (draw.c/actions.c), so a bare `xschem set show_hidden_texts 1` followed by
## `update_all_sym_bboxes` is undone before the export and the row would be
## vacuous. The menu bodies write the Tcl variable; so does this row.
set A10_SHT 0 ; catch {set A10_SHT $::show_hidden_texts}
set ::show_hidden_texts 1
dc_annot 0 ; set A10_T0 [dc_ntexts [a3_pr2 [file join $scratch a3_sht0.svg]]]
dc_annot 9 ; set A10_T9 [dc_ntexts [a3_pr2 [file join $scratch a3_sht9.svg]]]
set ::show_hidden_texts $A10_SHT
dc_annot 0
check "A10 show_hidden_texts=1 (the state BOTH Op-Annotate menu bodies create) does NOT defeat the rung" \
  [list [a3_hasl $A10_T0 {A3TRUETEXT}] \
        [a3_hasl $A10_T9 {A3TRUETEXT}] \
        [a3_hasl $A10_T9 $A_PARAMS] \
        [a3_hasl $A10_T9 {M1}]] \
  {1 0 {0 0} 1}

## The rung goes AFTER the class tests, so a text that DECLARED itself an
## annotation is never eaten by it. `hide=op` at mask 11 and `hide=voltage` at
## mask 11 both render; the parameter and the pin label do not.
check "A11 an annotation-classed text survives the rung: at mask 11 both hide=op and hide=voltage texts still render" \
  [list [a3_hasl $A_T(11) {A3OPTEXT A3VOLTTEXT}] [a3_hasl $A_T(11) $A_PARAMS]] \
  {{1 1} {0 0}}

## SVG AND PS MUST AGREE WITH THE SCREEN. psprint.c is the back end a partial fix
## leaves out (issue 0615's sharpest landmine) — an exported PDF that still
## carries the parameters is a defect.
dc_annot 9 ; set A12_P9 [a3_pr2 [file join $scratch a3_m9.ps] ps]
dc_annot 1 ; set A12_P1 [a3_pr2 [file join $scratch a3_m1.ps] ps]
dc_annot 0
check "A12 PS AGREES WITH SVG: at mask 9 the PostScript carries (M1) and not (A3W=1u)/(A3GATE); at mask 1 it carries all three" \
  [list [regexp {\(M1\)} $A12_P9] [regexp {\(A3W=1u\)} $A12_P9] [regexp {\(A3GATE\)} $A12_P9] \
        [regexp {\(M1\)} $A12_P1] [regexp {\(A3W=1u\)} $A12_P1] [regexp {\(A3GATE\)} $A12_P1]] \
  {1 0 0 1 1 1}

## INVARIANT I-A / I4: the overlay and the rung modify NOTHING. `xschem saveas`
## above wrote this file, so the comparison is two writes of the same in-memory
## schematic — the bytes, not the absence of a dirty marker.
set A13_B0 [opa_slurp $A_SAV]
set A13_MODS {}
foreach m {0 1 3 8 9 11} { dc_annot $m ; lappend A13_MODS [xschem get modified] }
catch {xschem save}
set A13_B1 [opa_slurp $A_SAV]
dc_annot 0
check "A13 INVARIANT I-A: a full mask sweep sets no modify flag and leaves the .sch BYTE-IDENTICAL" \
  [list $A13_MODS [expr {$A13_B0 eq $A13_B1}] [expr {[string length $A13_B0] > 0}]] \
  {{0 0 0 0 0 0} 1 1}

## ⚠ THE CLICK TARGET — MEASURED, NOT DISCOVERED LATER. select.c's symbol_bbox
## gates its text loop on the same predicate, so a hidden text SHRINKS the
## with-text box inst[i].x1..y2, and findnet.c's find_closest_element uses
## POINTINSIDE against exactly that box as its candidate gate. `xschem
## instance_at` (scheduler.c) is that pick, read-only. So with the declutter on,
## every decluttered device's clickable area gets smaller. That is arguably
## correct — the text is not there any more — but ITEM B4 CLICKS THESE DEVICES.
## Measured before the change: M1's box is 150 -380 496.601 -233.165 at BOTH
## mask 1 and mask 9, and all three points below answer M1 at both.
##   (430,-245) sits inside the A3W= parameter text, outside the body
##   (180,-380) sits inside the A3GATE pin label, outside the body
##   (300,-300) is the symbol body itself and must NEVER stop answering
dc_annot 1
set A14_M1 [list [xschem instance_at 430 -245] [xschem instance_at 180 -380] [xschem instance_at 300 -300]]
set A14_B1 [a3_ibox 0]
dc_annot 9
set A14_M9 [list [xschem instance_at 430 -245] [xschem instance_at 180 -380] [xschem instance_at 300 -300]]
set A14_B9 [a3_ibox 0]
dc_annot 0
check "A14 CLICK TARGET: at mask 9 the decluttered device's with-text bbox shrinks and the two text-only pick points stop answering it" \
  [list $A14_M1 $A14_M9 \
        [a3_lt [lindex $A14_B9 2] [lindex $A14_B1 2]] \
        [a3_lt [lindex $A14_B1 1] [lindex $A14_B9 1]]] \
  [list {M1 M1 M1} [list {} {} M1] 1 1]

## ⚠ THE BBOX MUST NOT BE ONE PASS STALE. The shipped idiom is
## `annotate_op; update_all_sym_bboxes; redraw`, and symbol_bbox has ~20 callers
## that run outside any draw or export frame. If the per-instance gate is read
## from a cache that only the three DRAW entry points refresh, the click target
## is computed from the PRE-annotate state and the screen and the pick disagree
## for one pass. Nothing is exported or redrawn between the sync and the read
## here, deliberately.
##
## ⚠ REPAIRED IN PLACE BY ITEM A5 — ISSUE 1254 HOLE 1, AND THE ASSERTION FLIPS
## DIRECTION. As written this row was UNFALSIFIABLE: item A3 asserted "the sync
## alone reds A15" and the sabotage variant SB7b (neutralize ONLY
## scheduler.c:14453) reddened NOTHING — 82/492/36 all pass. Two causes, both
## measured. (1) `xschem load $A_SAV` immediately before `annotate_op` leaves the
## overlay cache COLD, so the first gate call after the sync populates it fresh
## and no staleness can exist. (2) Sharper than 1254 knew: `xschem annotate_op`
## itself runs `update_op(); draw();` (scheduler.c:2544-2545) and draw() calls
## annot_overlay_sync() at draw.c:10545, ABOVE the `if(has_x)` guard, so it runs
## HEADLESS too — measured on this very sequence, the line under test flushed
## ZERO times. So the row now WARMS to one annotation state, then moves the epoch
## with an operation that does NOT draw (`xschem raw clear` — scheduler.c's raw
## arm reaches extra_rawfile() and neither draws nor bumps annot_data_changed),
## and only then runs ONE update_all_sym_bboxes. After item A5-a a raw-less sheet
## is NOT decluttered, so the box must have GROWN BACK and the two pick points
## must answer M1 again — the opposite sign of what this row golded before, and
## now falsifiable. Leg 3 is the flush counter, which is what actually reds under
## SB7b; leg 4 is the non-vacuity control that the warm box really was shrunken.
## Row A40 below guards the OTHER door with a DIFFERENT mover, on purpose.
xschem load $A_SAV
update idletasks
dc_setmask 9
catch {xschem annotate_op $A_RAW 0}
catch {xschem update_all_sym_bboxes}
set A15_WARM [a3_ibox 0]
set A15_F0 -1 ; catch {set A15_F0 [xschem get annot_overlay_flushes]}
catch {xschem raw clear}
catch {xschem update_all_sym_bboxes}
set A15_F1 -1 ; catch {set A15_F1 [xschem get annot_overlay_flushes]}
set A15_GOT [list [xschem instance_at 430 -245] [xschem instance_at 300 -300]]
set A15_FIN [a3_ibox 0]
catch {xschem annotate_op $A_RAW 0}
dc_annot 0
check "A15 THE BBOX IS NOT ONE PASS STALE: warm at mask 9, move the epoch with NO draw, and ONE update_all_sym_bboxes must re-read the gate - the box grows back and the sync really flushed" \
  [list $A15_GOT \
        [expr {($A15_F1 - $A15_F0) > 0 ? 1 : 0}] \
        [a3_lt [lindex $A15_WARM 2] [lindex $A15_FIN 2]]] \
  [list {M1 M1} 1 1]

## Invariant I-C in GEOMETRY, not only in pixels: with bit0 clear the declutter
## bit must move no bounding box either.
dc_annot 0 ; set A16_0 {}
for {set i 0} {$i < [xschem get instances]} {incr i} { lappend A16_0 [a3_ibox $i] }
dc_annot 8 ; set A16_8 {}
for {set i 0} {$i < [xschem get instances]} {incr i} { lappend A16_8 [a3_ibox $i] }
dc_annot 0
check "A16 INVARIANT I-C in geometry: with ANNOT_SHOW_OP clear the declutter bit moves NO instance bbox" \
  [list [expr {$A16_0 eq $A16_8}] [expr {[llength $A16_0] == 4}] \
        [expr {[lindex $A16_0 0] ne {NO-BBOX}}]] \
  {1 1 1}

## hide_symbols=2 CLOSES the D-6 gate (get_annot_overlay's own D9 chain refuses
## there), so the rung must not fire and the render is the KEEP-NAME render — not
## a doubly-stripped one. Compared mask-for-mask so this row says exactly one
## thing.
##
## ⚠ REPAIRED IN PLACE BY ITEM A5 — ISSUE 1254 HOLE 2. As written this row could
## not detect the thing its name claims: under sabotage SB-GATE-ALWAYS
## (annot_instance_annotated -> return 1, so hide_symbols is ignored entirely) it
## stayed GREEN, because at hide_symbols=2 the keep-name filter has already
## reduced BOTH renders to names only and the rung has nothing left to remove.
## ⚠ AND 1254's FIRST REPAIR IS REFUTED ON THIS TREE — do not attempt it. It
## says "give A17 a text the keep-name filter keeps and the rung would hide".
## That text CANNOT EXIST: survivor and exempt are ONE predicate —
## annot_name_token(text.txt_ptr) at draw.c:876 / svgdraw.c:931 / psprint.c:1213
## against `flags & TEXT_ANNOT_NAME`, set by annot_name_token(t->txt_ptr) at
## actions.c:1404 on the same string — so the intersection is empty. Take the
## issue's SECOND option and assert the GATE, which the BBOX is the one open
## window on: measured, at hide_symbols=2 the box is the UN-DECLUTTERED box at
## both masks (identical to the hide_symbols=0 mask-1 box), while at
## hide_symbols=0 mask 9 the same instance's box is shrunken. SB-GATE-ALWAYS
## shrinks the hide_symbols=2 mask-9 box and reds legs 3 and 4; leg 5 is the
## non-vacuity control that says the gate is capable of moving this box at all.
## ⚠ THE hide_symbols=0 REFERENCE BOXES ARE TAKEN FIRST, deliberately: row A18
## below runs at hide_symbols=2 and restores it, so this row must leave it set.
set A17_HS 0 ; catch {set A17_HS $::hide_symbols}
dc_annot 1 ; set A17_H0B1 [a3_ibox 0]
dc_annot 9 ; set A17_H0B9 [a3_ibox 0]
catch {xschem set hide_symbols 2}
dc_annot 9 ; set A17_T9 [dc_ntexts [a3_pr2 [file join $scratch a3_hs2m9.svg]]]
set A17_B9 [a3_ibox 0]
dc_annot 1 ; set A17_T1 [dc_ntexts [a3_pr2 [file join $scratch a3_hs2m1.svg]]]
set A17_B1 [a3_ibox 0]
check "A17 hide_symbols=2 CLOSES the D-6 gate, so the declutter does not fire there: the renders AND the bboxes are identical at mask 1 and mask 9, and the box is the UN-decluttered one" \
  [list [expr {$A17_T9 eq $A17_T1}] [expr {[llength $A17_T9] > 0}] \
        [expr {$A17_B9 eq $A17_B1}] [expr {$A17_B9 eq $A17_H0B1}] \
        [a3_lt [lindex $A17_H0B9 2] [lindex $A17_B9 2]]] \
  {1 1 1 1 1}

## ⚠ ROW N14 FLIPPED — ISSUE 1249 FIXED HERE, DELIBERATELY. The shipped
## keep-name test is THREE byte-identical copies comparing against `@symname`
## and `@name` only, so at hide_symbols=2 a device whose name text is
## `@spiceprefix@name` loses its name on screen, in SVG and in PDF. Item A2
## measured it and filed it; item A3 rewrites exactly those three loops and
## fixes it as it passes, with the exported annot_name_token() as the single
## predicate (invariant I1). Row N14 above carries the same flip on section N's
## own fixture; this row carries it WITH the annotation live, which is the state
## A17 says must not double-strip.
dc_annot 9
set A18_T [dc_ntexts [a3_pr2 [file join $scratch a3_hs2names.svg]]]
catch {xschem set hide_symbols $A17_HS}
dc_annot 0
check "A18 ROW N14 FLIPPED (1249 fixed): at hide_symbols=2 every device keeps its name, INCLUDING the two spelled @spiceprefix@name" \
  [list [a3_hasl $A18_T {M1 a3fet XM1 M2 XM2 R1 nand2 X1}] [a3_hasl $A18_T $A_PARAMS]] \
  {{1 1 1 1 1 1 1 1} {0 0}}

# --- A19..A22: THE STRUCTURE THE BEHAVIOURAL ROWS CANNOT SEE ----------------
# ⚠ These four are CORROBORATION, not the proof. Item A2 had to argue
# structurally because xText.flags is invisible from Tcl; A3 does not — it has
# three independent behavioural windows on the predicate (the SVG and PS
# renders, `xschem instance_bbox` and `xschem instance_at`). What they add is
# the two things behaviour cannot see: that the eleventh call site is
# byte-unchanged, and that four copies of one predicate became one.

set A_DRAW [file join $repo src draw.c]
set A_SVGD [file join $repo src svgdraw.c]
set A_PS   [file join $repo src psprint.c]
set A_SEL  [file join $repo src select.c]

## ISSUE 1249, STRUCTURALLY: four copies become one builder (invariant I1).
check "A19 1249 STRUCTURAL: no `@symname` keep-name literal survives in the three render back ends, each calls annot_name_token once, and it is exported" \
  [list [opa_n_grep $A_DRAW {"@symname"}] [opa_n_grep $A_SVGD {"@symname"}] \
        [opa_n_grep $A_PS {"@symname"}] \
        [opa_n_grep $A_DRAW {annot_name_token\(}] [opa_n_grep $A_SVGD {annot_name_token\(}] \
        [opa_n_grep $A_PS {annot_name_token\(}] \
        [opa_n_grep $DC_H {extern int annot_name_token}]] \
  {0 0 0 1 1 1 1}

## REPLACES ROW N10. The rung's PLACEMENT, read out of the C: below the explicit
## HIDE_TEXT_VOLTAGE arm (so the class tests answer first, which is what keeps
## the eleventh call site's answer bit-for-bit unchanged) and above the
## show_hidden_texts arm (row A10's measurement). The second element is the
## anti-hollow half: the name bit must actually be READ somewhere, not merely
## written by item A2.
set A20_B [dc_cbody $N_ACTIONS text_hidden_core]
set A20_iv -1 ; set A20_in -1 ; set A20_is -1 ; set A20_k 0
foreach l [split $A20_B \n] {
  if {$A20_iv < 0 && [string first HIDE_TEXT_VOLTAGE   $l] >= 0} { set A20_iv $A20_k }
  if {$A20_in < 0 && [string first ANNOT_SHOW_NOPARAM  $l] >= 0} { set A20_in $A20_k }
  if {$A20_is < 0 && [string first show_hidden_texts   $l] >= 0} { set A20_is $A20_k }
  incr A20_k
}
set A20_READS 0
foreach l [split [opa_slurp $N_ACTIONS] \n] {
  if {[string first TEXT_ANNOT_NAME $l] < 0} continue
  if {[regexp {\|=\s*TEXT_ANNOT_NAME} $l]} continue
  if {[regexp {^\s*\*} $l] || [regexp {^\s*/\*} $l]} continue
  incr A20_READS
}
check "A20 REPLACES ROW N10: the rung sits in text_hidden_core BELOW the HIDE_TEXT_VOLTAGE arm and ABOVE show_hidden_texts, and the name bit is READ" \
  [list [expr {[string length $A20_B] > 0}] \
        [expr {($A20_iv >= 0 && $A20_in > $A20_iv) ? 1 : 0}] \
        [expr {($A20_is >= 0 && $A20_in >= 0 && $A20_is > $A20_in) ? 1 : 0}] \
        [expr {$A20_READS >= 1 ? 1 : 0}]] \
  {1 1 1 1}

## ⚠ THE ELEVENTH CALL SITE, BYTE-UNCHANGED. get_annot_overlay() asks "would an
## OP text be visible right now?" with a SYNTHETIC literal, as a proxy for
## "should the overlay paint?". It must keep asking exactly that: the
## instance-aware entry point must not appear in this function, or the declutter
## switches the annotation overlay off and A9 is the only row that notices.
set A21_B [dc_cbody $N_ACTIONS get_annot_overlay]
check "A21 THE ELEVENTH SITE, STRUCTURAL: get_annot_overlay still carries the synthetic literal and no instance-aware call" \
  [list [expr {[string first {text_hidden(HIDE_TEXT_OP, TEXT_CTX_INSTANCE)} $A21_B] >= 0 ? 1 : 0}] \
        [expr {[string first {text_hidden_inst} $A21_B] >= 0 ? 1 : 0}] \
        [expr {[string length $A21_B] > 0}]] \
  {1 0 1}

## THE CALL-SITE CENSUS. Six instance sites, and every one of them carries the
## instance index: draw_symbol, draw_temp_symbol, inst_text_bbox, svg_draw_symbol,
## ps_draw_symbol and symbol_bbox. The last element is what says the sweep was
## COMPLETE — a two-argument instance-context call left behind is a site the
## declutter silently does not reach.
## ⚠ THE GOLDEN MOVED {3 1 1 1 0} -> {4 2 2 1 0} WITH ITEM A5, AND DELIBERATELY.
## A5-b (issue 1253, ruling D-1) adds the SEVENTH..NINTH instance-aware sites:
## one `text_hidden_inst(0, n)` in each of the three P6 pin-name loops, which
## walk symptr->rect[PINLAYER] and which text_hidden() never saw. select.c stays
## at 1 — symbol_bbox() has no P6 pass (row A38). The golden is EDITED, not the
## regexp widened: widening it so the count does not move is verbatim the
## "the suite stays green while the feature changes" failure this batch has now
## filed three times against this very suite (1248, 1254).
check "A22 CALL-SITE CENSUS: exactly nine instance-aware calls (draw 4, svg 2, ps 2, select 1) and no two-argument instance-context call left behind" \
  [list [opa_n_grep $A_DRAW {text_hidden_inst\(}] [opa_n_grep $A_SVGD {text_hidden_inst\(}] \
        [opa_n_grep $A_PS {text_hidden_inst\(}]   [opa_n_grep $A_SEL {text_hidden_inst\(}] \
        [expr {[opa_n_grep $A_DRAW {text_hidden\(.*TEXT_CTX_INSTANCE}] + \
               [opa_n_grep $A_SVGD {text_hidden\(.*TEXT_CTX_INSTANCE}] + \
               [opa_n_grep $A_PS   {text_hidden\(.*TEXT_CTX_INSTANCE}] + \
               [opa_n_grep $A_SEL  {text_hidden\(.*TEXT_CTX_INSTANCE}]}]] \
  {4 2 2 1 0}

# --- A23, A24: ISSUE 1246, THE TWO HARD SETS --------------------------------
# `Waves > Op Annotate` and `Graphs > Annotate Operating Point into schematic`
# both HARD SET the mask, which silently clears the declutter bit — so the menu
# item and the chord disagree about ruling D-8. Invisible today; user-visible
# the moment A3 makes bit 3 hide text. The repair is the shipped bit-wise idiom
# at src/ase_window.tcl (`($cur & ~$bit) | ...`), reading `xschem get
# annot_show` and NEVER `$::annot_show` — the mask is PER-CONTEXT, so the Tcl
# mirror belongs to whichever context wrote it last (row N22c of
# test_op_annot.tcl pins that trap).
set A_XSTCL [file join $repo src xschem.tcl]
set A_XSSRC [opa_slurp $A_XSTCL]

check "A23 1246 SOURCE: src/xschem.tcl carries ZERO hard sets of the mask and exactly two bit-wise writers, one under each menu label" \
  [list [opa_n_grep $A_XSTCL {^\s*xschem set annot_show 3\s*$}] \
        [opa_n_grep $A_XSTCL {xschem set annot_show \[expr}] \
        [opa_n_grep $A_XSTCL {xschem set annot_show}] \
        [expr {[regexp {Op Annotate.*?xschem set annot_show \[expr} $A_XSSRC] ? 1 : 0}] \
        [expr {[regexp {Annotate Operating Point into schematic.*?xschem set annot_show \[expr} $A_XSSRC] ? 1 : 0}]] \
  {0 2 2 1 1}

## ⚠ THE EXPRESSION IS EXTRACTED FROM THE SOURCE AND EVALUATED, not eyeballed.
## `| 3` alone is wrong: clearing bit 2 (the held transient snapshot, issue
## 0868) is deliberate and is ruling D5-1's shape, so the merge must take
## 9 -> 11 (bit 3 SURVIVES) and 4 -> 3 (bit 2 is CLEARED).
set A24_EXPR {}
foreach l [split $A_XSSRC \n] {
  if {[regexp {xschem set annot_show \[expr \{(.*)\}\]} $l -> A24_BODY]} {
    set A24_EXPR $A24_BODY ; break
  }
}
proc a3_merge {body cur} {
  if {$body eq {}} { return NO-EXPR }
  set s [string map [list {[xschem get annot_show]} $cur] $body]
  if {[catch {expr $s} r]} { return RAISED }
  return $r
}
set A24_GOT {}
foreach c {9 4 0 15 8} { lappend A24_GOT [a3_merge $A24_EXPR $c] }
check "A24 1246 BEHAVIOUR: the merge expression EXTRACTED FROM THE SOURCE sets bits 0/1, clears bit 2 and leaves bit 3 alone" \
  $A24_GOT {11 3 3 11 11}

# --- A25, A26: ISSUE 1247, THE NET-ZERO PAIR --------------------------------
# annot_show_set() stamps xctx->annot_root for ANY nonzero mask, so two
# Ctrl-Alt-6 presses — a pair whose advertised effect is NOTHING — convert an
# xschemrc-armed annotation into one a later File > Open clears (the 0688
# root-change clear). Pre-existing mechanism; A1 owned no C file that could fix
# it.
# ⚠ HOW THE rc SHAPE IS REACHED FROM A SCRIPT. `xschem set annot_show 3` stamps
# the root immediately, so the armed-with-NULL-stamp state cannot be produced
# through the setter. A bare `set ::annot_show 3` followed by ONE bulk
# evaluation pulls the value into xctx->annot_show WITHOUT stamping — the same
# shape xinit.c gives an rc-armed mask. Measured on this tree: mask 3, stamp
# empty, both before and after.
focus -force .drw
update idletasks
set A25_A [file join $scratch a3_sheetA.sch]
set A25_B [file join $scratch a3_sheetB.sch]
foreach {p n} [list $A25_A A $A25_B B] {
  set fd [open $p w]
  puts $fd "v {xschem version=3.4.5 file_version=1.2}
G {}
V {}
S {}
E {}
T {a3 sheet $n} 0 0 0 0 0.4 0.4 {}"
  close $fd
}
proc a3_rcarm {sheet mask} {
  xschem load $sheet ; update idletasks
  dc_setmask 0
  set ::annot_show $mask
  catch {xschem update_all_sym_bboxes}
  set r {} ; catch {set r [xschem get annot_root]}
  return [list [dc_mask] [expr {$r eq {} ? {EMPTY} : {STAMPED}}]]
}
set A25_CTRL_ARM [a3_rcarm $A25_A 3]
xschem load $A25_B ; update idletasks
set A25_CTRL_OPEN [dc_mask]
set A25_VAR_ARM [a3_rcarm $A25_A 3]
dc_fire <Control-Alt-Key-6>
set A25_VAR_P1 [dc_mask]
dc_fire <Control-Alt-Key-6>
set A25_VAR_P2 [dc_mask]
xschem load $A25_B ; update idletasks
set A25_VAR_OPEN [dc_mask]
check "A25 1247 CONTROL/VARIANT on two root sheets: an rc-armed mask survives File>Open WITH and WITHOUT a net-zero pair of presses" \
  [list $A25_CTRL_ARM $A25_CTRL_OPEN $A25_VAR_ARM $A25_VAR_P1 $A25_VAR_P2 $A25_VAR_OPEN] \
  [list {3 EMPTY} 3 {3 EMPTY} 11 3 3]

## ⚠ THE FIX MUST NOT WEAKEN ISSUE 0688. A mask armed THROUGH THE SETTER still
## belongs to the sheet it was armed for, still names it, and is still cleared
## when the root moves. That is decision D2 of 0688 and it is not A3's to
## reverse.
xschem load $A25_A ; update idletasks
dc_setmask 3
set A26_ROOT {} ; catch {set A26_ROOT [xschem get annot_root]}
set A26_ARM [list [dc_mask] [expr {$A26_ROOT eq $A25_A ? 1 : 0}]]
xschem load $A25_B ; update idletasks
set A26_OPEN [dc_mask]
dc_setmask 0
check "A26 1247 DOES NOT WEAKEN 0688: a SETTER-armed mask names its sheet and is still cleared by opening another root" \
  [list $A26_ARM $A26_OPEN] [list {3 1} 0]

# --- A27, A28: PER PDK (sky130A, gf180mcuD, ihp-sg13g2) ---------------------
# ⚠ THE ACCEPTANCE ROW, ON THE REAL SHIPPED SYMBOLS. Each PDK's procs file is
# sourced (it is what calls op_annot::register, with a `match` glob narrowing to
# that PDK's cell names — issue 0425), one of its FETs is placed, and a raw
# built FROM THE DESCRIPTOR'S OWN params list through op_annot::vector is
# annotated. Then: the device draws its NAME and its OP block and nothing else.
# ⚠ THE SYMBOL IS REFERENCED BY ABSOLUTE PATH, deliberately. The three PDK rcs
# repoint XSCHEM_LIBRARY_DEFS at their own tree, which this session cannot do
# after startup; an absolute reference resolves without it and still yields a
# `cell::name` containing `sky130_fd_pr/` / `gf180mcu_pr/` / `sg13g2_pr/`, which
# is exactly what op_annot::_matches globs against.
# ⚠ NOTE WHICH NAME EACH PDK SPELLS: sky130 and IHP carry `@name`, gf180 carries
# `@spiceprefix@name` — the third spelling, and the one issue 1249 drops.
set A_PDK [list \
  sky130 [file join $repo sky130A sky130_procs.tcl] \
         [file join $repo sky130A xschem_libs sky130_fd_pr nfet_01v8 symbol nfet_01v8.sym] \
         {name=M1 W=1 L=0.15 nf=1 model=nfet_01v8 spiceprefix=X} \
         M1 {nfet_01v8 {1 x 1 / 0.15} nf=1 S D B G} \
  gf180  [file join $repo gf180mcuD gf180_procs.tcl] \
         [file join $repo gf180mcuD xschem_libs gf180mcu_pr nfet_03v3 symbol nfet_03v3.sym] \
         {name=M1 L=0.28u W=0.22u nf=1 m=1 model=nfet_03v3 spiceprefix=X} \
         XM1 {nfet_03v3 {1 x 0.22u / 0.28u} nf=1 S D B G} \
  ihp    [file join $repo ihp-sg13g2 sg13g2_procs.tcl] \
         [file join $repo ihp-sg13g2 xschem_libs sg13g2_pr sg13_lv_nmos symbol sg13_lv_nmos.sym] \
         {name=M1 l=0.13u w=0.15u ng=1 m=1 model=sg13_lv_nmos spiceprefix=X} \
         M1 {sg13_lv_nmos m=1 ng=1 l=0.13u w=0.15u G S D B}]

set A27_GOT {} ; set A28_GOT {}
set A_VP {800 600 200 -420 620 -180}
foreach {tag procs sym props keep drop} $A_PDK {
  catch {source $procs}
  set sch [file join $scratch a3_$tag.sch]
  set fd [open $sch w]
  puts $fd "v {xschem version=3.4.5 file_version=1.2}
G {}
V {}
S {}
E {}
C \{$sym\} 400 -300 0 0 \{$props\}"
  close $fd
  xschem load $sch ; update idletasks
  set d {}
  catch {set d [op_annot::descriptor nmos]}
  set pr {} ; set v 1.0
  catch {
    foreach row [dict get $d params] {
      lappend pr [op_annot::vector M1 [lindex $row 1] [lindex $row 2]] $v
      set v [expr {$v * 2}]
    }
  }
  a3_mkraw [file join $scratch a3_$tag.raw] $pr
  catch {xschem annotate_op [file join $scratch a3_$tag.raw] 0}
  dc_annot 9 ; set t9 [dc_ntexts [a3_pr2 [file join $scratch a3_${tag}_m9.svg]]]
  dc_annot 1 ; set t1 [dc_ntexts [a3_pr2 [file join $scratch a3_${tag}_m1.svg]]]
  dc_annot 0
  lappend A27_GOT [list [a3_hasl $t9 [list $keep]] \
                        [expr {[lsearch -glob $t9 {id *= 1}] >= 0 ? 1 : 0}] \
                        [a3_hasl $t9 $drop]]
  lappend A28_GOT [list [a3_hasl $t1 [list $keep]] \
                        [expr {[lsearch -glob $t1 {id *= 1}] >= 0 ? 1 : 0}] \
                        [a3_hasl $t1 $drop]]
}
set A_VP {2400 1600 100 -420 1000 -20}

check "A27 PER PDK (sky130A, gf180mcuD, ihp-sg13g2): at mask 9 each annotated FET draws its name and its OP block and NOTHING else" \
  $A27_GOT \
  {{1 1 {0 0 0 0 0 0 0}} {1 1 {0 0 0 0 0 0 0}} {1 1 {0 0 0 0 0 0 0 0 0}}}

check "A28 PER PDK NON-VACUITY: the same three FETs at mask 1 still draw @model, their sizing text and their pin labels" \
  $A28_GOT \
  {{1 1 {1 1 1 1 1 1 1}} {1 1 {1 1 1 1 1 1 1}} {1 1 {1 1 1 1 1 1 1 1 1}}}

# --- A29: THE TWO SUITES THIS ITEM DOES NOT OWN BUT MUST KEEP HONEST --------
# ⚠ FIXING 1246 REDS TWO ROWS IN TWO OTHER FILES. Row N22b of
# tests/headless/test_op_annot.tcl and row B6 of
# tests/headless/test_annot_show_menu.tcl both gold the LITERAL hard set against
# the raw src/xschem.tcl text. Worse, as written neither can tell the two writer
# sites apart — `.` matches a newline in Tcl, so both labelled regexps are
# satisfied by whichever site comes first — so fixing only ONE site would leave
# both rows green. They are re-pointed at the bit-wise writer in the same commit
# and each gains a "zero hard sets survive" element. This row is the seam
# between the three files: what those two suites gold must be what src/xschem.tcl
# actually carries.
set A_OPANNOT [file join $here test_op_annot.tcl]
set A_MENU    [file join $here test_annot_show_menu.tcl]
## ⚠ THE GREPS ARE SCOPED TO THE GOLDEN LINES, not to the whole file. Eight
## other lines of test_op_annot.tcl legitimately WRITE `xschem set annot_show 3`
## as test setup (rows L3, O32..O35 and the U section); only a line that carries
## the literal INSIDE a `regexp {...}` is a golden about src/xschem.tcl's text.
check "A29 the 1246 literal rows in the two suites this item does not own are re-pointed at the bit-wise writer, and agree with src/xschem.tcl" \
  [list [opa_n_grep $A_XSTCL {xschem set annot_show \[expr}] \
        [opa_n_grep $A_OPANNOT {regexp \{.*xschem set annot_show 3}] \
        [opa_n_grep $A_MENU    {regexp \{.*xschem set annot_show 3}] \
        [opa_n_grep $A_OPANNOT {regexp \{.*xschem set annot_show \\\[expr}] \
        [opa_n_grep $A_MENU    {regexp \{.*xschem set annot_show \\\[expr}]] \
  {2 0 0 2 2}

dc_annot 0

# ============================================================================
# A30..A41 — ITEM A5: D-1 / D-6 CONFORMANCE, AND THE STALENESS A3 LEFT
# ============================================================================
# Four parts, all of feature 1244, three of them CONFORMANCE GAPS against
# rulings the user has already given (DECISIONS.md D-1 and D-6):
#
#   A30..A35  A5-a — THE GATE MUST REQUIRE A VALUE, NOT A RESOLVING DESCRIPTOR.
#   A36..A39  A5-b — issue 1253: the declutter must reach the P6 pin-owned
#                    pin names, in all three back ends (ruling D-1).
#   A40 A41   A5-c — issue 1252: the per-instance gate must be FRESH at BOTH
#                    `symbol_bbox()` doors, not just at `update_all_sym_bboxes`.
#   A15 A17   A5-d — issue 1254's two coverage holes, REPAIRED IN PLACE above
#   A22 E6           (same row numbers — 1254 names A15 and A17 by number) plus
#                    the two goldens A5-b and A5-a move.
#
# ⚠ WHAT A5-a INVERTS, AND WHY IT IS NOT POLISH. Measured on THIS fixture
# against the pre-A5 binary, with `xschem raw loaded` = -1 (i.e. before any
# simulation has been run at all):
#
#   mask 1 -> M1 a3fet XM1 A3OPTEXT A3W=1u A3GATE {zid =} {zgm =} ...
#   mask 9 -> M1 a3fet XM1 A3OPTEXT                {zid =} {zgm =} ...
#
# The user presses `6`, presses `Ctrl-Alt-6`, and loses `A3W=1u` in exchange for
# two EMPTY labels — strictly worse than before, reachable in the first thirty
# seconds. RULING D-6 says the declutter reaches instances that "got OP
# numbers"; a label with no number did not get one. So the gate must require at
# least one row carrying an ACTUAL VALUE.
#
# ⚠ AND THE OVERLAY MUST NOT FOLLOW IT. `op_annot::text` emits every declared
# row even when nothing resolved, deliberately — the user is entitled to see
# WHICH parameters this device would show. So after A5-a the declutter's gate is
# strictly STRONGER than `get_annot_overlay()`'s D1 term and the two
# DELIBERATELY disagree. Row A31 is that accept criterion; row A9 above is the
# one that catches the feature eating itself, and neither may move.
#
# ⚠ INVALIDATION (issue 0466 §S9b, the recorded case of exactly this going
# wrong: thirteen epoch fields and not one moved on `xschem reload`, so the
# overlay painted the previous file's numbers). The value test is a PURE
# FUNCTION of the block string `annot_overlay_cached_text()` already returns —
# no `xschem raw value`, no `::op_annot::_annotated`, no second tcleval — so the
# gate acquires ZERO invalidation inputs of its own and cannot be staler than
# the block the overlay paints. Row A35's last leg is that guarantee written as
# structure; rows A30/A32/A33 drive the three raw states end to end.
#
# RED BEFORE A5 LANDS (9): A30 A32 A35 A36 A37 A38 A40 A41 — plus the two
#   REPAIRED rows A15 and A22, and E6's fifth leg.
# GREEN BEFORE AND AFTER (5) — controls and accept rows, NOT evidence for A5:
#   A31  the overlay still paints on a label-only block (the accept row, and the
#        row that says gate and overlay now deliberately disagree);
#   A33  the DISCRIMINATION control — a valued device IS still decluttered, so a
#        "fix" that closes the gate by refusing everything reds here;
#   A34  the mint contract `op_annot::text` publishes, pinned from Tcl so the C
#        helper's coupling to src/op_annot.tcl's width pass is visible if item
#        A6 changes the mint;
#   A39  invariant I-C for the pin pass: with ANNOT_SHOW_OP clear the declutter
#        bit touches no pin name;
#   A17  (repaired above) — 1254 hole 2. It is green today and green after; its
#        whole point is that it must go RED under SB-GATE-ALWAYS, which it did
#        not before the repair.

set A_VP {2400 1600 100 -420 1000 -20}
set A5_DEAD [file join $scratch a5dead.raw]
set A5_PSYM [file join $scratch a5pin.sym]
set A5_PFIX [file join $scratch a5pin.sch]
set A5_PRAW [file join $scratch a5pin.raw]

## Count the CODE lines of a C file matching <re> — a line whose first non-blank
## characters are `*`, `/*` or `//` is a comment and is skipped.
## ⚠ NOT opa_n_grep, which counts comments too: every helper A5 adds is NAMED in
## the prose beside it (actions.c's rewritten gate comment names
## annot_block_has_value; 1252's rejected repair is named in scheduler.c's), so a
## comment-blind census would gold a number that prose alone can satisfy.
proc a5_ccount {path re} {
  if {![file isfile $path]} { return -1 }
  set fd [open $path r] ; set d [read $fd] ; close $fd
  set n 0
  foreach l [split $d \n] {
    if {[regexp {^\s*(\*|/\*|//)} $l]} continue
    if {[regexp -- $re $l]} { incr n }
  }
  return $n
}
## 1 when the line IMMEDIATELY AFTER the (trimmed) exact line <anchor> contains
## <needle>; 0 when it does not; -1 when the anchor is absent. The anchor is an
## exact trimmed match on purpose: src/draw.c:949 mentions `pin_name_visible` in
## a COMMENT, and a `string first` reader would anchor on the prose.
proc a5_after_line {path anchor needle} {
  if {![file isfile $path]} { return -1 }
  set fd [open $path r] ; set d [read $fd] ; close $fd
  set lines [split $d \n]
  set n [llength $lines]
  for {set i 0} {$i < $n} {incr i} {
    if {[string trim [lindex $lines $i]] ne $anchor} continue
    if {$i + 1 >= $n} { return 0 }
    return [expr {[string first $needle [lindex $lines [expr {$i + 1}]]] >= 0 ? 1 : 0}]
  }
  return -1
}
## 1 when a CODE line matching <needle> appears within <span> lines after the
## first line matching <anchorRe>; 0 when it does not; -1 when the anchor is
## absent.
proc a5_near {path anchorRe needle span} {
  if {![file isfile $path]} { return -1 }
  set fd [open $path r] ; set d [read $fd] ; close $fd
  set lines [split $d \n]
  set n [llength $lines] ; set start -1
  for {set i 0} {$i < $n} {incr i} {
    if {[regexp -- $anchorRe [lindex $lines $i]]} { set start $i ; break }
  }
  if {$start < 0} { return -1 }
  for {set i $start} {$i < $n && $i <= $start + $span} {incr i} {
    set l [lindex $lines $i]
    if {[regexp {^\s*(\*|/\*|//)} $l]} continue
    if {[regexp -- $needle $l]} { return 1 }
  }
  return 0
}

# --- A30..A35: A5-a, THE GATE MUST REQUIRE A NUMBER -------------------------

## ⚠ STATE 1 — NO RAW LOADED AT ALL, which is the common first press and the
## case item A4 measured. `xschem raw clear` unloads and NOTHING re-reads it
## here (no key press, so no `$::netlist_dir` re-read — the trap row E6 records).
catch {xschem raw clear}
xschem load $A_SAV
update idletasks
set A30_LOADED -99 ; catch {set A30_LOADED [xschem raw loaded]}
set A30_BLOCK [a3_optext M1]
foreach m {0 1 8 9} {
  dc_annot $m
  set A5_NC($m) [a3_ovl]
  set A5_NS($m) [a3_pr2 [file join $scratch a5_nr$m.svg]]
  set A5_ND($m) [expr {[a3_ovl] - $A5_NC($m)}]
  set A5_NT($m) [dc_ntexts $A5_NS($m)]
}
dc_annot 0

## THE HEADLINE OF ITEM A5. Nothing is decluttered before a simulation has been
## run: the mask-9 text list is the mask-1 text list, and both still carry the
## parameter and the pin label.
check "A30 A5-a HEADLINE with NO RAW LOADED AT ALL (raw loaded = -1) the declutter hides NOTHING - mask 9 == mask 1, and the parameter and the pin label survive" \
  [list $A30_LOADED \
        [a3_hasl $A5_NT(1) $A_PARAMS] \
        [a3_hasl $A5_NT(9) $A_PARAMS] \
        [expr {$A5_NT(1) eq $A5_NT(9)}] \
        [expr {[llength $A5_NT(9)] > 0}]] \
  {-1 {1 1} {1 1} 1 1}

## ⚠ THE ACCEPT ROW, AND IT IS GREEN BEFORE AND AFTER. `op_annot::text` emits
## the declared rows with nothing after the `=` when the raw publishes nothing,
## and `get_annot_overlay()` PAINTS that block on purpose. A5-a makes the
## declutter's gate strictly stronger than the overlay's D1 term — they now
## deliberately disagree — so the four paint deltas row A9 golds must not move
## and the blank rows must still reach the page. A fix that "tidied" the overlay
## to match the gate would delete op_annot.tcl's deliberate behaviour and is
## exactly what row A9 exists to catch.
check "A31 A5-a NON-VACUITY: on the SAME no-raw sheet the overlay still paints the label-only block, and its paint delta is unmoved at masks 0/1/8/9" \
  [list [expr {[lsearch -glob $A5_NT(9) {zid *=}] >= 0 ? 1 : 0}] \
        [expr {[lsearch -glob $A5_NT(9) {zgm *=}] >= 0 ? 1 : 0}] \
        [list $A5_ND(0) $A5_ND(1) $A5_ND(8) $A5_ND(9)]] \
  {1 1 {0 8 0 8}}

## ⚠ STATE 2 — A REAL RAW THAT PUBLISHES NOTHING FOR THIS DEVICE. `xschem raw
## loaded` = 0 and the descriptor resolves, so A3's gate opened; the block is
## still label-only, so ruling D-6's "got OP numbers" is still false. This is the
## OTHER half of the ruling, distinct from A30's no-raw half.
a3_mkraw $A5_DEAD {v(a5zzz) 1.0}
catch {xschem annotate_op $A5_DEAD 0}
update idletasks
set A32_LOADED -99 ; catch {set A32_LOADED [xschem raw loaded]}
dc_annot 1 ; set A5_DT1 [dc_ntexts [a3_pr2 [file join $scratch a5_dr1.svg]]]
dc_annot 9 ; set A5_DT9 [dc_ntexts [a3_pr2 [file join $scratch a5_dr9.svg]]]
dc_annot 0
check "A32 A5-a DEAD RAW (raw loaded = 0, descriptor resolves, no matching vectors): the block is label-only, so nothing is decluttered" \
  [list $A32_LOADED \
        [a3_hasl $A5_DT9 $A_PARAMS] \
        [expr {$A5_DT1 eq $A5_DT9}] \
        [expr {[lsearch -glob $A5_DT9 {zid *=}] >= 0 ? 1 : 0}]] \
  {0 {1 1} 1 1}

## ⚠ STATE 3 — THE DISCRIMINATION CONTROL, GREEN BEFORE AND AFTER. A device with
## at least one real value IS decluttered, exactly as item A3 shipped it. This is
## what reds a "fix" that closes the gate by refusing everything (variant
## SB-A5a-NEVER), and it is the same claim rows A1/A27 make one fixture over.
catch {xschem annotate_op $A_RAW 0}
update idletasks
set A33_BLOCK [a3_optext M1]
dc_annot 1 ; set A5_VT1 [dc_ntexts [a3_pr2 [file join $scratch a5_v1.svg]]]
dc_annot 9 ; set A5_VT9 [dc_ntexts [a3_pr2 [file join $scratch a5_v9.svg]]]
dc_annot 0
check "A33 A5-a DISCRIMINATION (the A3 control): with the VALUED raw the same device IS still decluttered at mask 9 and keeps everything at mask 1" \
  [list [a3_hasl $A5_VT9 $A_PARAMS] \
        [a3_hasl $A5_VT1 $A_PARAMS] \
        [expr {[lsearch -glob $A5_VT9 {zid = [0-9]*}] >= 0 ? 1 : 0}]] \
  {{0 0} {1 1} 1}

## ⚠ THE MINT CONTRACT, PINNED FROM THE Tcl SIDE. The value test must be
## answered from the ALREADY-CACHED block string (the whole 0466 argument), which
## couples one C helper to the format `op_annot::text`'s width pass mints —
## src/op_annot.tcl: "A blank row is `label =` with NOTHING after the `=`, not
## even a space; every row ends in exactly one newline." src/op_annot.tcl is item
## A6's file, not A5's, so the coupling is pinned here instead: if the mint
## changes, this row reds rather than the defect silently re-opening.
set A34_BLANKOK 1 ; set A34_BLANKN 0
foreach A34_L [split $A30_BLOCK \n] {
  if {[string trim $A34_L] eq {}} continue
  incr A34_BLANKN
  if {![regexp {^\S+ *=$} $A34_L]} { set A34_BLANKOK 0 }
}
set A34_VALN 0
foreach A34_L [split $A33_BLOCK \n] { if {[regexp {^\S+ *= \S} $A34_L]} { incr A34_VALN } }
check "A34 THE MINT CONTRACT: with no raw EVERY row of op_annot::text is `label =` with nothing after the `=`, and with the valued raw at least one row is `label = <eng>`" \
  [list $A34_BLANKOK [expr {$A34_BLANKN >= 1 ? 1 : 0}] [expr {$A34_VALN >= 1 ? 1 : 0}]] \
  {1 1 1}

## ⚠ ONE HELPER, ONE READER, AND NO SECOND OBSERVER — the 0466 guarantee written
## as structure. Legs 1/2: the value test exists exactly twice (its definition
## and its ONE call) and `annot_instance_annotated()` is the only thing that
## returns it, so invariant I1 holds (one builder, one reader). Leg 3:
## `get_annot_overlay()`'s D1 term is UNCHANGED — the overlay keeps painting the
## label-only block (row A31). Leg 4 is the one that closes issue 0466: the
## helper reads NOTHING but its argument, so it adds no invalidation input of its
## own and rides the wholesale flush `annot_overlay_sync()` already performs.
set A35_HB [dc_cbody $N_ACTIONS annot_block_has_value]
set A35_IB [dc_cbody $N_ACTIONS annot_instance_annotated]
set A35_OB [dc_cbody $N_ACTIONS get_annot_overlay]
check "A35 A5-a STRUCTURAL: one pure helper, ONE call, get_annot_overlay untouched, and the helper reads no Tcl and no raw (issue 0466)" \
  [list [a5_ccount $N_ACTIONS {annot_block_has_value\(}] \
        [expr {[regexp {return\s+annot_block_has_value} $A35_IB] ? 1 : 0}] \
        [expr {[string first {annot_block_has_value} $A35_OB] >= 0 ? 1 : 0}] \
        [expr {[string length $A35_HB] > 0 ? 1 : 0}] \
        [expr {[regexp {tcleval|tclget|tclset|op_annot|annot_overlay|xctx} $A35_HB] ? 1 : 0}]] \
  {2 1 0 1 0}

# --- A36..A39: A5-b / ISSUE 1253, THE P6 PIN-OWNED PIN NAMES ----------------
# RULING D-1, in the user's own words: "even pin labels can be hidden when user
# is hiding other things that are not @name." Item A3's rung sits in
# text_hidden(), which gates the loop over a SYMBOL's text[] records. The P6 pass
# draws a pin's name from the PIN's own tokens — it walks symptr->rect[PINLAYER]
# behind pin_name_visible() (src/draw.c:959, src/svgdraw.c:986,
# src/psprint.c:1279) — so text_hidden() never sees it and a symbol spelling
# show_pinname=true keeps its pin names on a fully decluttered device.
#
# ⚠ WHY THIS FIXTURE AND NOT SECTION A's. Not one pin of a3fet.sym carries a
# show_pinname token at all, and pin_name_visible() returns 0 for an un-owned
# pin, so the P6 pass never runs there. `A3GATE` is a `T` record — a pin LABEL
# that the rung already hides — which is a different thing from a pin's own NAME.
#
# ⚠ AND WHY ONLY TWO BEHAVIOURAL BACK ENDS. draw.c has NO seam: draw()'s body is
# inside `if(has_x)` and pin names bump no counter, and symbol_bbox()
# (src/select.c:670-738) walks only symptr->text[] and has no P6 pass at all — so
# hiding a pin name moves NO bbox and this is unmeasurable through
# instance_bbox / instance_at. The screen leg is row A38's, structurally. Said
# out loud rather than implied: two behavioural rows plus one source row, not
# three behavioural rows.
#
# ⚠ THE ACCEPTANCE ROWS A27/A28 CANNOT SEE THIS. All four pins of each of the
# three PDK FETs the batch accepts against spell show_pinname=false; the 2,968
# `show_pinname=true` records censused in issue 1253 are elsewhere in the
# libraries. That is the whole reason this fixture exists.
set A5_FD [open $A5_PSYM w]
puts $A5_FD {v {xschem version=3.4.5 file_version=1.2}
G {}
K {type=a3nmos
format="@spiceprefix@name @pinlist @model w=@w"
template="name=MP1 model=a3n w=1u spiceprefix=X"
}
V {}
S {}
E {}
L 4 -20 -20 20 -20 {}
L 4 20 -20 20 20 {}
L 4 20 20 -20 20 {}
L 4 -20 20 -20 -20 {}
B 5 -22.5 -12.5 -17.5 -7.5 {name=PD dir=inout show_pinname=true}
B 5 -22.5 7.5 -17.5 12.5 {name=PG dir=inout show_pinname=false}
T {@name} 0 -40 0 0 0.2 0.2 {}
T {A5PW=@w} 150 55 0 0 0.2 0.2 {}}
close $A5_FD
set A5_FD [open $A5_PFIX w]
puts $A5_FD "v {xschem version=3.4.5 file_version=1.2}
G {}
V {}
S {}
E {}
C \{$A5_PSYM\} 300 -300 0 0 \{name=MP1\}"
close $A5_FD

## LOAD, THEN op_annot::vector, THEN mint — section A's own order, and it is
## load-bearing: the vector resolves the device path through the LOADED instance.
catch {xschem raw clear}
xschem load $A5_PFIX
update idletasks
set A5_PP {}
catch {lappend A5_PP [op_annot::vector MP1 zid] 1.11e-05 [op_annot::vector MP1 zgm] 3.33e-04}
a3_mkraw $A5_PRAW $A5_PP
catch {xschem annotate_op $A5_PRAW 0}
update idletasks
foreach m {0 1 8 9} {
  dc_annot $m
  set A5_PT($m) [dc_ntexts [a3_pr2 [file join $scratch a5_p$m.svg]]]
}
dc_annot 9 ; set A5_PS9 [a3_pr2 [file join $scratch a5_p9.ps] ps]
dc_annot 1 ; set A5_PS1 [a3_pr2 [file join $scratch a5_p1.ps] ps]
dc_annot 0

## The last two legs are the NON-VACUITY control that the P6 pass is really what
## is being observed: PG spells show_pinname=false and renders at NEITHER mask,
## so a row that passed by rendering no pin names at all would red here.
check "A36 1253 SVG: at mask 9 the pin's OWN name PD is gone with the parameter, and PG (show_pinname=false) renders at neither mask" \
  [list [a3_hasl $A5_PT(1) {MP1 A5PW=1u PD}] \
        [a3_hasl $A5_PT(9) {MP1 A5PW=1u PD}] \
        [a3_hasl $A5_PT(1) {PG}] \
        [a3_hasl $A5_PT(9) {PG}]] \
  {{1 1 1} {1 0 0} 0 0}

## psprint.c is the back end a partial fix leaves out (issue 0615's sharpest
## landmine) — an exported PDF that still carries the pin names is a defect.
check "A37 1253 PS: the PostScript agrees with the SVG - (MP1) at both masks, (A5PW=1u) and (PD) at mask 1 only, (PG) at neither" \
  [list [regexp {\(MP1\)} $A5_PS1] [regexp {\(A5PW=1u\)} $A5_PS1] \
        [regexp {\(PD\)} $A5_PS1] [regexp {\(PG\)} $A5_PS1] \
        [regexp {\(MP1\)} $A5_PS9] [regexp {\(A5PW=1u\)} $A5_PS9] \
        [regexp {\(PD\)} $A5_PS9] [regexp {\(PG\)} $A5_PS9]] \
  {1 1 1 0 1 0 0 0}

## ⚠ THE draw.c LEG, WHICH HAS NO BEHAVIOURAL WINDOW (see the section header).
## The guard must be the EXISTING predicate — `text_hidden_inst(0, n)`, issue
## 1253's own recommended one-liner — and it must sit on the line immediately
## after pin_name_visible() and BEFORE get_pin_name_layout(), so the pnm/pfont
## malloc/free pair is never reached for a pin the declutter hides. Byte-
## identical in all three back ends; a fourth, pin-specific gate is exactly the
## drift invariant I1 forbids. select.c is asserted at ZERO deliberately:
## symbol_bbox() has no P6 pass and adding one would be new geometry, not a
## conformance gap (recorded as 1253's residue).
set A38_ANCHOR {if(!pin_name_visible(pin->prop_ptr)) continue;}
check "A38 1253 STRUCTURAL: one text_hidden_inst(0, n) in each of the three P6 loops, on the line right after pin_name_visible(), and none in select.c" \
  [list [a5_ccount $A_DRAW {text_hidden_inst\(\s*0\s*,\s*n\s*\)}] \
        [a5_ccount $A_SVGD {text_hidden_inst\(\s*0\s*,\s*n\s*\)}] \
        [a5_ccount $A_PS   {text_hidden_inst\(\s*0\s*,\s*n\s*\)}] \
        [a5_ccount $A_SEL  {text_hidden_inst\(\s*0\s*,\s*n\s*\)}] \
        [a5_after_line $A_DRAW $A38_ANCHOR {text_hidden_inst}] \
        [a5_after_line $A_SVGD $A38_ANCHOR {text_hidden_inst}] \
        [a5_after_line $A_PS   $A38_ANCHOR {text_hidden_inst}]] \
  {1 1 1 0 1 1 1}

## INVARIANT I-C FOR THE PIN PASS (ruling D-8: "declutter is active ONLY when OP
## info is displayed"). Green before and after — it reds a fix that hides pin
## names unconditionally.
check "A39 1253 INVARIANT I-C: with ANNOT_SHOW_OP clear the declutter bit touches no pin name - mask 0 == mask 8 and PD is drawn in both" \
  [list [expr {$A5_PT(0) eq $A5_PT(8)}] \
        [a3_hasl $A5_PT(0) {PD}] [a3_hasl $A5_PT(8) {PD}]] \
  {1 1 1}

# --- A40, A41: A5-c / ISSUE 1252, THE OTHER symbol_bbox() DOOR --------------
# The per-instance gate reads the overlay cache, and that cache is refreshed by
# annot_overlay_sync(), which item A3 wired into `update_all_sym_bboxes` and
# NOWHERE ELSE outside the three draw/export entry points. `xschem
# recompute_inst_bbox` is the OTHER Tcl-reachable symbol_bbox() door and it syncs
# neither cache — so a decluttered device's with-text bbox is right by one path
# and wrong by the other, and findnet.c:461's find_closest_element uses
# POINTINSIDE against exactly that box as its candidate gate. ITEM B4 CLICKS
# THESE DEVICES.
#
# ⚠ ORDER IS LOAD-BEARING AND IS THE WHOLE ROW. Any sync — a draw, an export, an
# `update_all_sym_bboxes` — repairs the cache, after which the two doors agree
# and the row measures nothing. So the epoch is moved with NO draw and NO export,
# and the STALE door is read FIRST.
#
# ⚠ THE EPOCH MOVER IS A RE-REGISTRATION, NOT `xschem raw clear`. Re-registering
# the type with an EMPTY params list blanks the block and bumps
# ::op_annot::gen -> the epoch's desc_gen, with no draw. It closes the gate under
# the OLD gate and the NEW one alike, so this row reds for the 1252 reason ALONE
# and not for A5-a's. (`raw clear` would only close the gate after A5-a lands —
# row A15 above uses it for exactly that reason, which is what makes A15 and A40
# guard two DIFFERENT lines.) Measured against the pre-A5 binary: warm box x2
# 354.835, stale door 354.835 with `instance_at 430 -245` = {}, fresh door
# 496.305 with the same pick answering M1.
catch {xschem raw clear}
xschem load $A_SAV
update idletasks
dc_setmask 9
catch {xschem annotate_op $A_RAW 0}
catch {xschem update_all_sym_bboxes}
set A40_WARM [a3_ibox 0]
catch {op_annot::register a3nmos [list devpath {@m.@path@name} params {}]}
set A40_BLANK [expr {[string trim [a3_optext M1]] eq {} ? 1 : 0}]
catch {xschem recompute_inst_bbox M1}
set A40_STALE [a3_ibox 0]
set A40_PICKS [xschem instance_at 430 -245]
catch {xschem update_all_sym_bboxes}
set A40_FRESH [a3_ibox 0]
set A40_PICKF [xschem instance_at 430 -245]
catch {op_annot::register a3nmos \
  [list devpath {@m.@path@name} params {{zid zid 0} {zgm zgm 1}}]}
catch {xschem annotate_op $A_RAW 0}
dc_annot 0
check "A40 1252 THE TWO symbol_bbox DOORS AGREE, STALE DOOR READ FIRST: recompute_inst_bbox answers the same box and the same pick as update_all_sym_bboxes" \
  [list $A40_BLANK \
        [a3_lt [lindex $A40_WARM 2] [lindex $A40_FRESH 2]] \
        [expr {$A40_STALE eq $A40_FRESH}] \
        $A40_PICKS $A40_PICKF] \
  [list 1 1 1 M1 M1]

## THE CENSUS THE BEHAVIOURAL ROW CANNOT SEE. Two sites in scheduler.c — the
## `update_all_sym_bboxes` arm item A3 added and the `recompute_inst_bbox` arm
## A5-c adds — and the second must sit in the arm it names, not somewhere else in
## a 15k-line file.
##
## ⚠⚠ THE FIFTH GOLDEN MOVED 0 -> 1 WITH ITEM A6, AND IT IS A DELIBERATE REVERSAL
## OF THE OPTION ISSUE 1252 REJECTED. Said out loud rather than done quietly:
## A5-c's per-door repair closed TWO of the 39 symbol_bbox() callers, and item A6
## then measured FOUR MORE Tcl-reachable doors writing the click box from a stale
## gate — `setprop instance`, `move_instance … nodraw`, `reset_inst_prop` (which
## issue 1260 does not even name) and `select_element`'s deselect write — with
## `instance_at` answering EMPTY over a device the very same frame renders in
## full (rows A49..A53). Thirty-nine callers cannot each carry a correct copy of a
## freshness decision (invariant I1), so the sync moves to the ONE function they
## all pass through, `symbol_bbox()` (src/select.c).
##   1252's two reasons are ANSWERED, not ignored:
##     re-entrancy — annot_overlay_sync() early-returns on annot_overlay_busy
##       (src/actions.c), which annot_overlay_cached_text() sets around exactly
##       the tcleval that re-enters, so the ::op_annot::text -> translate ->
##       prepare_netlist_structs -> link_symbols_to_instances -> symbol_bbox
##       cycle is already closed;
##     cost — the sync is behind a bit-3 prefilter, so with the declutter unarmed
##       (every other row in this file, every load, every netlist pass, the whole
##       audit) symbol_bbox does two Tcl var reads and NO sync. Measured on a
##       49-instance sheet: symbol_bbox 9.97 us, a no-op annot_overlay_sync
##       ~0.11 us — about 1%.
## ⚠ THE GOLDEN IS EDITED; THE REGEXP IS NOT WIDENED. Widening the reader so the
## count does not move is verbatim the failure this suite has now filed three
## times against itself (1248, 1254). Rows A55/A56 are the shape and the
## placement that the count alone cannot see.
## ⚠ scheduler.c STAYS AT 2. A5-c's two sites are redundant under the single
## point and are LEFT IN PLACE deliberately — row A40 golds the second one inside
## the arm it names, and removing them is a refactor beyond item A6's step.
check "A41 1252 STRUCTURAL: annot_overlay_sync() is called from draw/svg/ps once each, from scheduler.c TWICE (the second inside the recompute_inst_bbox arm), and ONCE from select.c" \
  [list [a5_ccount $A_DRAW {annot_overlay_sync\(\)}] \
        [a5_ccount $A_SVGD {annot_overlay_sync\(\)}] \
        [a5_ccount $A_PS   {annot_overlay_sync\(\)}] \
        [a5_ccount [file join $repo src scheduler.c] {annot_overlay_sync\(\)}] \
        [a5_ccount $A_SEL  {annot_overlay_sync\(\)}] \
        [a5_near [file join $repo src scheduler.c] \
                 {strcmp\(argv\[1\], "recompute_inst_bbox"\)} {annot_overlay_sync\(\)} 30]] \
  {1 1 1 2 1 1}

dc_annot 0

# ============================================================================
# A42..A56 — ITEM A6: THE TWO HOLES IN THE VALUE GATE, AND THE LAST bbox DOORS
# ============================================================================
# Issues 1258 (a label containing `=` satisfies the gate), 1259 (a published
# zero satisfies it, so a `savecurrents` run still declutters) and 1260 (1252's
# residue: more symbol_bbox() doors, plus the mask half of the gate).
#
# ⚠ ALL FIFTEEN ROWS WERE MEASURED RED (or GREEN, where they are controls)
# AGAINST THE A5 BINARY BEFORE ANY OF THEM WAS WRITTEN. The numbers quoted
# below are from that run, not from reasoning.
#
# ---------------------------------------------------------------------------
# A42..A44 — 1258. THE GATE IS FOOLED BY THE DATA IT INSPECTS.
# ---------------------------------------------------------------------------
# annot_block_has_value() (src/actions.c) latches at the FIRST `=` on a row and
# calls the next non-space character a value. The descriptor `label` is
# USER-EDITABLE by design (invariant I5; item B5 lets people type these), and
# ::op_annot::text prints it verbatim, so a label spelled `v=x` mints the BLANK
# row `v=x =` and the gate reads the `x` as a number. Measured with `xschem raw
# loaded` = -1, i.e. before any simulation has been run:
#     block   = <<v=x =|q   =|>>              (| = newline; NO values at all)
#     mask 1  = M1 a3fet XM1 A3OPTEXT A3W=1u A3GATE {v=x =} {q   =}
#     mask 9  = M1 a3fet XM1 A3OPTEXT         {v=x =} {q   =}
# The user pressed 6, pressed Ctrl-Alt-6, and traded W and the pin label for two
# empty rows — item A5-a's exact defect, reproduced through a label spelling.
#
# ⚠ A44 IS THE ROW THAT SEPARATES THE TWO CANDIDATE REPAIRS, and it is the whole
# reason it exists. Issue 1258's own "Still open" recommends the ` = ` SEPARATOR
# reading. A label spelled `a = b` mints the blank row `a = b =` — measured —
# which contains ` = ` with `b` after it, so the separator reading calls that row
# VALUED and is still fooled. Taking the LAST `=` on the line is strictly
# stronger and is what this suite golds. Both are two-line changes; only one is
# right, and A44 is the difference between them written as a check.
#
# ---------------------------------------------------------------------------
# A45..A48 — 1259. THREE STATES, THREE ROWS, AND NO COLLAPSE IN EITHER DIRECTION.
# ---------------------------------------------------------------------------
# ⚠ THE TWO RAWS A45 AND A46 LOAD DIFFER IN ONE FIELD OF ONE HEADER LINE. That
# is the whole of issue 1259: with the type field stripped they are the same
# file, and everything downstream — `xschem raw value`, ::op_annot::raw_or_blank,
# the block string, the gate — sees the same bytes. Measured against the A5
# binary, the two are INDISTINGUISHABLE:
#     A45 (`current dims=0`)  raw index 0   raw value <0>   block <<zid = 0|...>>
#     A46 (plain `voltage`)   raw index 0   raw value <0>   block <<zid = 0|...>>
# and both declutter at mask 9. One of those is right and the other is the
# defect, so the distinction cannot be made from the block string, from the
# rendered digits, or from anything else the declutter can reach. It has to be
# read where it is written — the raw's own `Variables:` type field, which
# ngspice writes as `current dims=0` for a `.save` card the model does not
# publish (measurements §22, spec landmine 11).
#
#   (1) ABSENT.  No vector at all is row A32 above, and A5-a's gate ALREADY
#       closes on it. `dims=0` is the OTHER absence, and it is row A45: the
#       column IS in the file (`raw index` >= 0, so this is not A32 again) but
#       nothing was computed for it. It must render BLANK — invariant I3, "a
#       missing vector renders BLANK. Not 0, not NaN on screen" — and therefore
#       must NOT satisfy the gate.
#   (2) A REAL COMPUTED 0.0 is row A46, and it MUST still satisfy the gate. A
#       transistor that is off has id = 0 and that is a measurement, not a hole;
#       ::op_annot::eng_or_blank prints a measured 0 deliberately. A46 is the row
#       that reds a "fix" that collapses (1) and (2) toward absent, which would
#       hide a genuinely cut-off device from the user reading it.
#   (3) A NORMAL VALUE is row A47, unchanged.
# A48 is the seam: ONE predicate, at the raw reader, with the numbered-point
# read (`xschem raw value <v> 0` — data inspection, not annotation) deliberately
# still live. That last leg mirrors rows SGN13/SGN14/SGN22 of
# test_spice_get_node_0861.tcl, so a repair that swallows the arm next to it reds
# here as well as there.
#
# ---------------------------------------------------------------------------
# A49..A56 — 1260. THE DRAWN THING AND THE CLICKABLE THING MUST BE ONE OBJECT.
# ---------------------------------------------------------------------------
# Row A40 above closed the `recompute_inst_bbox` door. Driving the verbs rather
# than reading the code found FOUR more, all measured on the A5 binary with the
# A40 protocol (warm at mask 9, move the epoch with a params-{} re-registration,
# NO draw and NO export, read the STALE door FIRST):
#     warm box                              277.5 -340 354.343 -280
#     A49 setprop instance M1 name MZ1  ->  277.5 -340 354.343 -280  pick <>
#     A50 move_instance … nodraw noundo ->  277.5 -340 354.343 -280  pick <>
#     A51 reset_inst_prop M1            ->  277.5 -340 354.343 -280  pick <>
#     A52 select instance M1 clear      ->  277.5 -340 354.343 -280  pick <>
#     update_all_sym_bboxes             ->  150 -380 495.133 -233.026  pick M1
# ⚠ A51 IS A DOOR ISSUE 1260 DOES NOT NAME (scheduler.c's reset_inst_prop arm
# writes the box twice and then ENDS IN draw()) — so it also proves that a full
# redraw does NOT repair a box already written from a stale gate: the draw
# refreshes both caches, but the number was stored before it ran.
# ⚠ A52's door is select_element()'s DESELECT write (src/select.c), which no
# issue in this batch had noticed at all.
# A53 is the headline in one row: on the SAME fixture, with the render taken
# first, the SVG says `MZ1 a3fet XMZ1 A3OPTEXT A3W=1u A3GATE` and
# `instance_at 430 -245` answers EMPTY over it. ITEM B4 CLICKS THESE DEVICES,
# and findnet.c's find_closest_element uses POINTINSIDE against exactly this box.
# A54 is 1260 part 3, the MASK half, in BOTH directions — measured with a bare
# `set ::annot_show`, the two doors answer OPPOSITE picks:
#     C mask 1, bare set 9:  recompute 150 -380 495.133 -233.026 pick M1
#                            update_all 277.5 -340 354.343 -280  pick <>
#     C mask 9, bare set 1:  recompute 277.5 -340 354.757 -280   pick <>
#                            update_all 150 -380 496.307 -232.832 pick M1
# ⚠ THE TWO DOORS ARE COMPARED TO EACH OTHER, NEVER TO LITERAL COORDINATES: the
# two directions differ in the third decimal (495.133 vs 496.307), which is
# sub-pixel text-metric noise and is not the subject of any row here.
#
# RED BEFORE A6 LANDS (10): A42 A44 A45 A48 A49 A50 A51 A52 A53 A54 — plus the
#   REPAIRED row A41, whose fifth golden moves 0 -> 1.
# GREEN BEFORE AND AFTER (4) — controls, NOT evidence for A6:
#   A43  a valued '='-bearing label IS still decluttered (a fix that refuses any
#        row containing two `=` reds here);
#   A46  A REAL COMPUTED ZERO still satisfies the gate — the row that reds the
#        collapse toward "absent";
#   A47  a normal value still satisfies it;
#   A55 A56 are structural and red before A6 lands for the SHAPE, not the
#        behaviour.

## `xschem raw value <v> -1` — THE annotation accessor — and `… 0`, the numbered
## point, which is data inspection and must stay live while the annotation is
## refused. Both answer {} rather than raising into the suite.
proc a6_rval  {v} { set r {} ; catch {set r [xschem raw value $v -1]} ; return $r }
proc a6_rval0 {v} { set r {} ; catch {set r [xschem raw value $v 0]}  ; return $r }
proc a6_ridx  {v} { set r -99 ; catch {set r [xschem raw index $v]}   ; return $r }
## 1 when EVERY non-blank row of a block is `label =` with nothing after the `=`
## (A34's contract), and there is at least one row — so an empty block, which is
## row A32's case and not row A45's, cannot satisfy it.
proc a6_blank_block {t} {
  set n 0
  foreach l [split $t \n] {
    if {[string trim $l] eq {}} continue
    incr n
    if {![regexp {^\S+ *=$} $l]} { return 0 }
  }
  return [expr {$n >= 1 ? 1 : 0}]
}
## ROW A40's PROTOCOL, AS A PROC, because five rows need it and getting it wrong
## measures nothing. Warm BOTH caches at mask 9 over the valued raw, then move
## the epoch with a params-{} re-registration — NOT `xschem raw clear`, so the
## row reds for the 1260 reason alone and not for A5-a's — with no draw and no
## export. Returns the warm (decluttered, narrow) box.
## ⚠ EVERY DOOR GETS A FRESH FIXTURE STILL NAMED M1. Renaming M1 -> MZ1 unmatches
## the descriptor's @name-derived vector names, so a second door driven on a
## renamed sheet never re-opens the gate and reads falsely CLEAN.
proc a6_warm {} {
  catch {xschem raw clear}
  xschem load $::A_SAV
  update idletasks
  catch {op_annot::register a3nmos \
    [list devpath {@m.@path@name} params {{zid zid 0} {zgm zgm 1}}]}
  dc_setmask 9
  catch {xschem annotate_op $::A_RAW 0}
  catch {xschem update_all_sym_bboxes}
  set w [a3_ibox 0]
  catch {op_annot::register a3nmos [list devpath {@m.@path@name} params {}]}
  return $w
}
## A C file with its comments stripped, and the source between two needles.
## Copied from sgn_code / sgn_span, tests/headless/test_spice_get_node_0861.tcl:
## the thing under test is ONE ARM of a dispatcher inside a function thousands of
## lines long, and the comment above that arm quotes the very tokens being
## counted, so an unstripped grep matches prose and stays green over dead code.
proc a6_code {path} {
  if {![file isfile $path]} { return NOFILE }
  set h [open $path r] ; set d [read $h] ; close $h
  regsub -all {/\*.*?\*/} $d " " d
  return $d
}
proc a6_span {src a b} {
  set i [string first $a $src]
  if {$i < 0} { return NOFUNC }
  set j [string first $b $src $i]
  if {$j < 0} { return NOEND }
  return [string range $src $i $j]
}

# --- A42..A44: 1258, A LABEL CONTAINING `=` -------------------------------

set A6_EQRAW [file join $scratch a6eq.raw]

catch {xschem raw clear}
xschem load $A_SAV
update idletasks
catch {op_annot::register a3nmos \
  [list devpath {@m.@path@name} params {{v=x zid 0} {q zgm 1}}]}
set A42_LOADED -99 ; catch {set A42_LOADED [xschem raw loaded]}
set A42_BLOCK [a3_optext M1]
dc_annot 1 ; set A42_T1 [dc_ntexts [a3_pr2 [file join $scratch a6_eq1.svg]]]
dc_annot 9 ; set A42_T9 [dc_ntexts [a3_pr2 [file join $scratch a6_eq9.svg]]]
dc_annot 0

## THE HEADLINE OF ITEM A6-a, and the same claim row A30 makes one label
## spelling over: with no raw loaded NOTHING is decluttered.
check "A42 1258 HEADLINE a descriptor label containing `=` over NO RAW (raw loaded = -1) must NOT satisfy the gate - mask 9 == mask 1, parameter and pin label survive" \
  [list $A42_LOADED \
        [a6_blank_block $A42_BLOCK] \
        [a3_hasl $A42_T1 $A_PARAMS] \
        [a3_hasl $A42_T9 $A_PARAMS] \
        [expr {$A42_T1 eq $A42_T9}]] \
  {-1 1 {1 1} {1 1} 1}

## THE DISCRIMINATION CONTROL FOR A42, GREEN BEFORE AND AFTER. The same
## '='-bearing label over the VALUED raw mints `v=x = 11.1u`, which really did
## get a number, so the device IS still decluttered. A "fix" that refuses any row
## carrying two `=` characters reds here.
catch {xschem annotate_op $A_RAW 0}
update idletasks
set A43_BLOCK [a3_optext M1]
dc_annot 1 ; set A43_T1 [dc_ntexts [a3_pr2 [file join $scratch a6_eqv1.svg]]]
dc_annot 9 ; set A43_T9 [dc_ntexts [a3_pr2 [file join $scratch a6_eqv9.svg]]]
dc_annot 0
check "A43 1258 DISCRIMINATION: the SAME '='-bearing label over the VALUED raw IS still decluttered at mask 9 and keeps everything at mask 1" \
  [list [a3_hasl $A43_T9 $A_PARAMS] \
        [a3_hasl $A43_T1 $A_PARAMS] \
        [expr {[lsearch -glob $A43_T9 {v=x = [0-9]*}] >= 0 ? 1 : 0}]] \
  {{0 0} {1 1} 1}

## ⚠ THE ROW THAT SEPARATES THE LAST-`=` REPAIR FROM THE ` = ` SEPARATOR READING
## ISSUE 1258 RECOMMENDS. Measured: a label spelled `a = b` mints the BLANK row
## `a = b =` (and pads its neighbour to `q     =`). The separator reading finds
## ` = ` at offset 1 with `b` after it and calls the row VALUED — i.e. it is
## fooled by exactly the same class of data. Taking the LAST `=` is not fooled.
catch {xschem raw clear}
xschem load $A_SAV
update idletasks
catch {op_annot::register a3nmos \
  [list devpath {@m.@path@name} params {{{a = b} zid 0} {q zgm 1}}]}
set A44_LOADED -99 ; catch {set A44_LOADED [xschem raw loaded]}
set A44_BLOCK [a3_optext M1]
dc_annot 1 ; set A44_T1 [dc_ntexts [a3_pr2 [file join $scratch a6_ab1.svg]]]
dc_annot 9 ; set A44_T9 [dc_ntexts [a3_pr2 [file join $scratch a6_ab9.svg]]]
dc_annot 0
check "A44 1258 THE LAST-`=` CONTRACT: a label spelled `a = b` mints the blank row `a = b =`, which the ` = ` separator reading calls valued - mask 9 must still equal mask 1" \
  [list $A44_LOADED \
        [expr {[string first "a = b =" $A44_BLOCK] >= 0 ? 1 : 0}] \
        [a3_hasl $A44_T1 $A_PARAMS] \
        [a3_hasl $A44_T9 $A_PARAMS] \
        [expr {$A44_T1 eq $A44_T9}]] \
  {-1 1 {1 1} {1 1} 1}

# --- A45..A48: 1259, ABSENT vs A PUBLISHED ZERO vs A REAL ZERO -------------

set A6_D0RAW [file join $scratch a6dims0.raw]
set A6_Z0RAW [file join $scratch a6zero.raw]

catch {xschem raw clear}
xschem load $A_SAV
update idletasks
catch {op_annot::register a3nmos \
  [list devpath {@m.@path@name} params {{zid zid 0} {zgm zgm 1}}]}
## The SAME vector names and the SAME zero values, twice, differing ONLY in the
## `Variables:` type field. Invariant I1: the names still come from
## op_annot::vector, so neither fixture can drift from the descriptor.
set A6_ZPAIRS {} ; set A6_D0TYPES {}
foreach d {M1 M2} {
  catch {lappend A6_ZPAIRS [op_annot::vector $d zid] 0.0 [op_annot::vector $d zgm] 0.0}
  lappend A6_D0TYPES {current dims=0} {current dims=0}
}
a3_mkraw $A6_D0RAW $A6_ZPAIRS $A6_D0TYPES
a3_mkraw $A6_Z0RAW $A6_ZPAIRS
set A6_V0 [lindex $A6_ZPAIRS 0]

## ⚠ STATE 1b — ABSENT, BY `dims=0`. The column IS in the raw (so `raw index` is
## >= 0 and this is NOT row A32's no-vector case) but the simulator computed
## nothing for it. Invariant I3: it renders BLANK, so the gate stays closed.
catch {xschem annotate_op $A6_D0RAW 0}
update idletasks
set A45_IDX [a6_ridx $A6_V0]
set A45_VAL [a6_rval $A6_V0]
set A45_BLOCK [a3_optext M1]
dc_annot 1 ; set A45_T1 [dc_ntexts [a3_pr2 [file join $scratch a6_d01.svg]]]
dc_annot 9 ; set A45_T9 [dc_ntexts [a3_pr2 [file join $scratch a6_d09.svg]]]
dc_annot 0
check "A45 1259 STATE 1b ABSENT-BY-dims=0: the column is in the raw (index >= 0) but `raw value -1` is EMPTY, the block is label-only, and nothing is decluttered" \
  [list [expr {$A45_IDX >= 0 ? 1 : 0}] \
        [expr {$A45_VAL eq {} ? 1 : 0}] \
        [a6_blank_block $A45_BLOCK] \
        [a3_hasl $A45_T9 $A_PARAMS] \
        [expr {$A45_T1 eq $A45_T9}]] \
  {1 1 1 {1 1} 1}

## ⚠ STATE 2 — A REAL COMPUTED 0.0, AND IT MUST STILL SATISFY THE GATE. The same
## vectors, the same zeros, the type field alone removed. A transistor that is
## off has id = 0 and that is a measurement, not a hole. THIS IS THE ROW THAT
## REDS A COLLAPSE TOWARD "ABSENT" — the wrong answer in the other direction,
## and the one a user can never diagnose from the screen.
catch {xschem annotate_op $A6_Z0RAW 0}
update idletasks
set A46_VAL [a6_rval $A6_V0]
dc_annot 1 ; set A46_T1 [dc_ntexts [a3_pr2 [file join $scratch a6_z1.svg]]]
dc_annot 9 ; set A46_T9 [dc_ntexts [a3_pr2 [file join $scratch a6_z9.svg]]]
dc_annot 0
check "A46 1259 STATE 2 A REAL COMPUTED ZERO: `raw value -1` answers 0, the block reads `zid = 0`, and the device IS decluttered at mask 9" \
  [list $A46_VAL \
        [expr {[lsearch -exact $A46_T9 {zid = 0}] >= 0 ? 1 : 0}] \
        [a3_hasl $A46_T9 $A_PARAMS] \
        [a3_hasl $A46_T1 $A_PARAMS] \
        [expr {$A46_T1 ne $A46_T9 ? 1 : 0}]] \
  {0 1 {0 0} {1 1} 1}

## STATE 3 — an ordinary value, on the same fixture family, so all three states
## are read out of one place. Green before and after.
catch {xschem annotate_op $A_RAW 0}
update idletasks
set A47_VAL [a6_rval $A6_V0]
dc_annot 1 ; set A47_T1 [dc_ntexts [a3_pr2 [file join $scratch a6_n1.svg]]]
dc_annot 9 ; set A47_T9 [dc_ntexts [a3_pr2 [file join $scratch a6_n9.svg]]]
dc_annot 0
check "A47 1259 STATE 3 A NORMAL VALUE: `raw value -1` answers the number, the block reads `zid = 11.1u`, and the device IS decluttered at mask 9" \
  [list $A47_VAL \
        [expr {[lsearch -exact $A47_T9 {zid = 11.1u}] >= 0 ? 1 : 0}] \
        [a3_hasl $A47_T9 $A_PARAMS] \
        [a3_hasl $A47_T1 $A_PARAMS]] \
  {1.11e-05 1 {0 0} {1 1}}

## ⚠ THE SEAM, AND THE ARM NEXT TO IT. The absent/zero distinction exists in
## exactly one place — the raw's own type field — so it is read where it is
## written (src/save.c) and published through ONE predicate that item B1
## inherits, rather than re-derived by anyone downstream (invariant I1; a second
## detector is how 1252 became 1260). The last three legs are the fence copied
## from rows SGN13/SGN14/SGN22 of test_spice_get_node_0861.tcl: the guard belongs
## on the ANNOTATION fall-through alone, so the arm keeps its annot_p term and
## EXACTLY ONE cursor_b_val subscript, and the in-range numbered-point read —
## data inspection, not annotation — still answers 0 for a dims=0 column.
catch {xschem annotate_op $A6_D0RAW 0}
update idletasks
set A48_NUM [a6_rval0 $A6_V0]
set A48_ARM [a6_span [a6_code [file join $repo src scheduler.c]] \
                     "!strcmp(argv\[2\], \"value\")" "!strcmp(argv\[2\], \"del\")"]
check "A48 1259 THE SEAM: one absence predicate in save.c and ONE consumer in scheduler.c, on the annotation fall-through only - the numbered-point read still answers 0" \
  [list [a5_ccount $N_SAVE {raw_vector_absent\(}] \
        [a5_ccount [file join $repo src scheduler.c] {raw_vector_absent\(}] \
        [expr {[regexp {raw_vector_absent} $A48_ARM] ? 1 : 0}] \
        [expr {[regexp {annot_p} $A48_ARM] ? 1 : 0}] \
        [regexp -all {cursor_b_val\[} $A48_ARM] \
        [expr {[regexp {get_raw_value\(dataset, idx, point\)} $A48_ARM] ? 1 : 0}] \
        $A48_NUM] \
  {2 1 1 1 1 1 0}

# --- A49..A54: 1260, THE FOUR MORE DOORS AND THE MASK HALF -----------------

## DOOR 1 — `xschem setprop instance`, issue 1260 part 1. Item A5-a WIDENED this
## one: before A5-a a label-only block still opened the gate, so a rename over a
## dead raw flipped nothing. Now an ordinary property edit is enough.
set A49_WARM [a6_warm]
catch {xschem setprop instance M1 name MZ1}
set A49_STALE [a3_ibox 0]
set A49_PICKS [xschem instance_at 430 -245]
catch {xschem update_all_sym_bboxes}
set A49_FRESH [a3_ibox 0]
set A49_PICKF [xschem instance_at 430 -245]
check "A49 1260 DOOR 1 setprop instance, STALE DOOR READ FIRST: the box it stores and the pick it answers are the ones update_all_sym_bboxes gives" \
  [list [a3_lt [lindex $A49_WARM 2] [lindex $A49_FRESH 2]] \
        [expr {$A49_STALE eq $A49_FRESH}] \
        $A49_PICKS $A49_PICKF] \
  [list 1 1 MZ1 MZ1]

## DOOR 2 — `xschem move_instance … nodraw noundo`, issue 1260 part 2.
set A50_WARM [a6_warm]
catch {xschem move_instance 0 300 -300 0 0 nodraw noundo}
set A50_STALE [a3_ibox 0]
set A50_PICKS [xschem instance_at 430 -245]
catch {xschem update_all_sym_bboxes}
set A50_FRESH [a3_ibox 0]
set A50_PICKF [xschem instance_at 430 -245]
check "A50 1260 DOOR 2 move_instance nodraw noundo, STALE DOOR READ FIRST: same box and same pick as update_all_sym_bboxes" \
  [list [a3_lt [lindex $A50_WARM 2] [lindex $A50_FRESH 2]] \
        [expr {$A50_STALE eq $A50_FRESH}] \
        $A50_PICKS $A50_PICKF] \
  [list 1 1 M1 M1]

## ⚠ DOOR 3 — `xschem reset_inst_prop`, WHICH ISSUE 1260 DOES NOT NAME. Found by
## driving verbs, not by reading. Its arm writes the box TWICE and then ends in
## draw(), so this row also says out loud that a full redraw does NOT repair a
## box already written from a stale gate: the draw refreshes both caches, but the
## number was stored before it ran.
set A51_WARM [a6_warm]
catch {xschem reset_inst_prop M1}
set A51_STALE [a3_ibox 0]
set A51_PICKS [xschem instance_at 430 -245]
catch {xschem update_all_sym_bboxes}
set A51_FRESH [a3_ibox 0]
set A51_PICKF [xschem instance_at 430 -245]
check "A51 1260 DOOR 3 reset_inst_prop (the door 1260 does not name, and its arm ENDS IN draw): same box and same pick as update_all_sym_bboxes" \
  [list [a3_lt [lindex $A51_WARM 2] [lindex $A51_FRESH 2]] \
        [expr {$A51_STALE eq $A51_FRESH}] \
        $A51_PICKS $A51_PICKF] \
  [list 1 1 M1 M1]

## ⚠ DOOR 4 — select_element()'s DESELECT write (src/select.c). Selecting draws
## temp symbols; DEselecting recomputes the box, and no issue in this batch had
## noticed it. Both verbs are under catch so a signature mismatch reds this row
## rather than aborting the section.
set A52_WARM [a6_warm]
catch {xschem select instance M1}
catch {xschem select instance M1 clear}
set A52_STALE [a3_ibox 0]
set A52_PICKS [xschem instance_at 430 -245]
catch {xschem update_all_sym_bboxes}
set A52_FRESH [a3_ibox 0]
set A52_PICKF [xschem instance_at 430 -245]
check "A52 1260 DOOR 4 select_element's deselect write: same box and same pick as update_all_sym_bboxes" \
  [list [a3_lt [lindex $A52_WARM 2] [lindex $A52_FRESH 2]] \
        [expr {$A52_STALE eq $A52_FRESH}] \
        $A52_PICKS $A52_PICKF] \
  [list 1 1 M1 M1]

## ⚠ THE HEADLINE OF A6-c, IN ONE ROW: the drawn thing and the clickable thing
## are ONE object. The render is taken FIRST and the pick straight after it, with
## no update_all_sym_bboxes in between — an export syncs both caches but
## recomputes no bbox, which is why it does not repair this and why the row is
## honest. Measured on the A5 binary: the SVG says
## `MZ1 a3fet XMZ1 A3OPTEXT A3W=1u A3GATE` and the pick answers EMPTY over it.
set A53_WARM [a6_warm]
catch {xschem setprop instance M1 name MZ1}
set A53_T [dc_ntexts [a3_pr2 [file join $scratch a6_d1.svg]]]
set A53_PICK [xschem instance_at 430 -245]
check "A53 1260 THE HEADLINE: the frame renders MZ1 with its parameter and its pin label, and instance_at inside that rendered extent answers MZ1" \
  [list [a3_hasl $A53_T {MZ1 A3W=1u A3GATE}] $A53_PICK] \
  [list {1 1 1} MZ1]

## ⚠ 1260 PART 3 — THE MASK HALF, IN BOTH DIRECTIONS. `annot_show_sync_cache()`
## ends in the 0688 backstop, which can CLEAR the mask, so item A5-c deliberately
## left the mask unsynced at `recompute_inst_bbox` — and the two doors then
## answer OPPOSITE picks for a mask written with a bare `set ::annot_show`. The
## repair is to split the PULL out of the backstop, not to run the backstop on a
## read-only geometry verb. THE DOORS ARE COMPARED TO EACH OTHER, NEVER TO
## LITERAL COORDINATES (the two directions differ in the third decimal).
catch {xschem raw clear}
xschem load $A_SAV
update idletasks
catch {op_annot::register a3nmos \
  [list devpath {@m.@path@name} params {{zid zid 0} {zgm zgm 1}}]}
dc_setmask 1
catch {xschem annotate_op $A_RAW 0}
catch {xschem update_all_sym_bboxes}
set ::annot_show 9
catch {xschem recompute_inst_bbox M1}
set A54_AR [a3_ibox 0] ; set A54_ARP [xschem instance_at 430 -245]
catch {xschem update_all_sym_bboxes}
set A54_AU [a3_ibox 0] ; set A54_AUP [xschem instance_at 430 -245]

catch {xschem raw clear}
xschem load $A_SAV
update idletasks
dc_setmask 9
catch {xschem annotate_op $A_RAW 0}
catch {xschem update_all_sym_bboxes}
set ::annot_show 1
catch {xschem recompute_inst_bbox M1}
set A54_BR [a3_ibox 0] ; set A54_BRP [xschem instance_at 430 -245]
catch {xschem update_all_sym_bboxes}
set A54_BU [a3_ibox 0] ; set A54_BUP [xschem instance_at 430 -245]

## THE LAST LEG IS THE GUARD ON THE SPLIT, AND IT IS GREEN BEFORE AND AFTER: with
## the mask written properly (`xschem set annot_show`, so the C field and the Tcl
## mirror agree) a read-only geometry verb must leave it exactly where it was. A
## bbox path that ran the 0688 backstop instead of the pull could clear it.
dc_setmask 9
catch {xschem recompute_inst_bbox M1}
set A54_KEEP [dc_mask]
check "A54 1260 PART 3 THE MASK HALF, BOTH DIRECTIONS: recompute_inst_bbox and update_all_sym_bboxes answer the same box and the same pick, and a geometry verb does not move the mask" \
  [list [expr {$A54_AR eq $A54_AU}] [expr {$A54_ARP eq $A54_AUP}] \
        [expr {$A54_BR eq $A54_BU}] [expr {$A54_BRP eq $A54_BUP}] \
        $A54_KEEP] \
  {1 1 1 1 9}

# --- A55, A56: 1260 STRUCTURAL - THE SHAPE THE FOUR DOORS CANNOT SEE -------

## ⚠ ONE SYNC POINT, AND THE BACKSTOP IS NOT ON THE GEOMETRY PATH. Row A41 above
## carries the census that moved (select.c 0 -> 1, deliberately, reversing the
## option issue 1252 rejected); this row carries the two things the census cannot
## see. `annot_show_pull_cache()` — the annot_show + annot_voltage_layer pull
## SPLIT OUT of annot_show_sync_cache() — is what the bbox path calls;
## `annot_show_sync_cache()` itself, which ends in the 0688 root backstop and can
## annot_show_set(0), is NOT called from select.c, and its own call sites are
## unmoved so the 0688 semantics and row Y11 of test_op_annot.tcl are untouched.
check "A55 1260 STRUCTURAL: select.c calls the PULL exactly once and the 0688-carrying sync never, and annot_show_check_root's call sites are unmoved" \
  [list [a5_ccount $A_SEL     {annot_show_pull_cache\(}] \
        [a5_ccount $A_SEL     {annot_show_sync_cache\(}] \
        [a5_ccount $N_ACTIONS {annot_show_check_root\(}] \
        [a5_ccount $N_SAVE    {annot_show_check_root\(}] \
        [expr {[opa_n_grep $DC_H {annot_show_pull_cache}] >= 1 ? 1 : 0}]] \
  {1 0 2 1 1}

## ⚠ THE COST ARGUMENT, WRITTEN AS SHAPE. The pair sits in symbol_bbox()'s
## PROLOGUE — once per call, not once per text — and the overlay sync is behind
## the bit-3 prefilter, so with the declutter unarmed the function does two Tcl
## var reads and NO sync and annot_overlay_flushes cannot move (rows O32/O33/O34/
## O35/O38 of test_op_annot.tcl, a file item A6 does not own and must not edit).
check "A56 1260 SHAPE: the sync pair is in symbol_bbox()'s prologue, once each, behind the ANNOT_SHOW_NOPARAM prefilter" \
  [list [a5_near $A_SEL {void symbol_bbox\(} {annot_overlay_sync\(\)} 20] \
        [a5_near $A_SEL {void symbol_bbox\(} {annot_show_pull_cache\(} 20] \
        [a5_ccount $A_SEL {annot_overlay_sync\(\)}] \
        [a5_ccount $A_SEL {ANNOT_SHOW_NOPARAM}]] \
  {1 1 1 1}

## Leave section A as section C found it: the valued descriptor, no raw, mask 0.
catch {op_annot::register a3nmos \
  [list devpath {@m.@path@name} params {{zid zid 0} {zgm zgm 1}}]}
catch {xschem raw clear}
dc_annot 0


# ============================================================================
# SECTION C — THE DECLUTTER CLAUSE ON THE OTHER KEYS' SENTENCE (issue 1251)
# ============================================================================
# Item A4. Section S above proves the MINT; this section proves the SURFACE --
# what the user actually reads after each of the four annotation chords, in both
# declutter states, plus the 255-byte budget nothing else in the tree sweeps for
# bit 3.
#
# ⚠ WHY A FIXTURE OF ITS OWN, AND NOT SECTION A's. Measured on section A's
# fixture with the clause prototyped: at mask 11 the held line is 365 bytes
# unfitted and `cadence::_annot_fit` elides it at 253 -- the CLAUSE survives the
# cut but the sentence is being trimmed for reasons that have nothing to do with
# item A4 (that sheet's raw has no device parameters, so issue 0909's 132-byte
# cause clause is on every press, and its `examples/nand2` instance adds a
# symbol-types clause). A row asserting "the user reads the clause" on that
# fixture would be measuring the elision. This fixture is ONE registered device
# with its ONE vector present in the raw: no cause clause, no types clause, and
# every sentence below fits whole. Measured: 156 / 142 / 111 / 163 / 77 / 67
# bytes for the six chord outcomes.
#
# ⚠ THE BUSY-SHEET CASE IS NOT DROPPED, it is row B1 leg 3 -- where the cause
# and the clause cannot both fit, issue 0909's ordering makes the CAUSE win.
#
# ⚠ EVERY ROW WARMS FIRST. The first press of `6` after an attach reports state
# `loaded` ("Loaded results from <path>.") and every press after it reports
# `live` ("These results were already loaded."). Without a warm-up the
# declutter-on and declutter-off legs would be in DIFFERENT states and the
# "the whole difference is the clause" leg would be comparing two sentences
# that differ for a second reason.

# --- the section's own fixture ----------------------------------------------
set C_SYM [file join $scratch cfet.sym]
set C_FIX [file join $scratch cfix.sch]
set C_RAW [file join $scratch cfix.raw]
set C_TRAW [file join $scratch ctran.raw]

set C_FD [open $C_SYM w]
puts $C_FD {v {xschem version=3.4.5 file_version=1.2}
G {}
K {type=c4fet
format="@name @pinlist @model w=@w"
template="name=MC1 model=c4n w=1u"
}
V {}
S {}
E {}
L 4 -20 -20 20 -20 {}
L 4 20 -20 20 20 {}
L 4 20 20 -20 20 {}
L 4 -20 20 -20 -20 {}
T {@name} 0 -40 0 0 0.2 0.2 {}
T {CW=@w} 60 30 0 0 0.2 0.2 {}}
close $C_FD
set C_FD [open $C_FIX w]
puts $C_FD "v {xschem version=3.4.5 file_version=1.2}
G {}
V {}
S {}
E {}
C \{$C_SYM\} 300 -300 0 0 \{name=MC1\}"
close $C_FD

## ⚠ THE ORDER IS LOAD, THEN REGISTER, THEN `op_annot::vector` -- section A's
## order, and it is load-bearing: `op_annot::vector` resolves the device path
## through the LOADED instance, so calling it before the load answers {} and the
## fixture silently becomes a raw with a nameless vector, a blank block and
## issue 0909's cause clause on every press. Measured while writing this section.
catch {xschem raw clear}
set ::netlist_dir $scratch
xschem load $C_FIX
update idletasks
catch {op_annot::register c4fet [list devpath {@m.@path@name} params {{cid cid 0}}]}
set C_PAIRS {}
catch {lappend C_PAIRS [op_annot::vector MC1 cid] 1.11e-05}
set C_FD [open $C_RAW w]
puts -nonewline $C_FD "Title: 1251 clause fixture\nDate: Mon Jan 1 00:00:00 2026\n"
puts -nonewline $C_FD "Plotname: Operating Point\nFlags: real\n"
puts -nonewline $C_FD "No. Variables: [expr {[llength $C_PAIRS]/2}]\nNo. Points: 1\nVariables:\n"
set C_K 0
foreach {v val} $C_PAIRS { puts -nonewline $C_FD "\t$C_K\t$v\tvoltage\n" ; incr C_K }
puts -nonewline $C_FD "Values:\n0\t[lindex $C_PAIRS 1]\n"
close $C_FD
## A two-point transient for the Alt-Shift-6 leg, with cursor B at 4 ns.
set C_FD [open $C_TRAW w]
puts -nonewline $C_FD "Title: 1251 clause transient\nDate: Mon Jan 1 00:00:00 2026\n"
puts -nonewline $C_FD "Plotname: Transient Analysis\nFlags: real\nNo. Variables: 2\nNo. Points: 2\n"
puts -nonewline $C_FD "Variables:\n\t0\ttime\ttime\n\t1\tv(zzz)\tvoltage\n"
puts -nonewline $C_FD "Values:\n0\t0\n\t1.5\n\n1\t4e-09\n\t2.5\n"
close $C_FD

proc c_msg {} { set m {} ; catch {set m [xschem get statusmsg]} ; return $m }
## THE SPY. `cadence::_annot_fit` is the ONE door every status write in
## utils/annot_mode.tcl goes through -- row A11-2 of test_op_annot.tcl counts the
## lines writing `xschem statusmsg -hold` and requires each to name `_annot_fit`
## on the same line -- so a spy here sees the sentence the mint BUILT, before the
## 255-byte budget touches it, on all four chords including the transient one,
## whose success tail goes through `cadence::_annot_say`. Park/restore engine
## copied from opa_v_spy (test_op_annot.tcl:12308-12318); the restore runs on the
## error path too.
proc c_spy {from seq} {
  dc_setmask $from
  set ::c_fit {}
  if {![llength [info commands ::cadence::_annot_fit]]} { return NOPROC }
  rename ::cadence::_annot_fit ::cadence::__c_saved_fit
  proc ::cadence::_annot_fit {m} { lappend ::c_fit $m ; return [::cadence::__c_saved_fit $m] }
  catch {dc_fire $seq}
  catch {rename ::cadence::_annot_fit {}}
  catch {rename ::cadence::__c_saved_fit ::cadence::_annot_fit}
  return [list [dc_mask] [c_msg] $::c_fit]
}
## Warm to the `live` state (see the header), then press.
proc c_press {from seq} { dc_setmask 1 ; dc_fire <Key-6> ; return [c_spy $from $seq] }
proc c_mask {r} { return [lindex $r 0] }
proc c_bar  {r} { return [lindex $r 1] }
proc c_unf  {r} { return [lindex [lindex $r 2] 0] }
proc c_nfit {r} { return [llength [lindex $r 2]] }
proc c_has  {s} { return [expr {[string first $::DC_CLAUSE $s] >= 0 ? 1 : 0}] }
## The bar really is the fitted form of what the mint built -- the C round trip
## through `statusmsg -hold` and `xschem get statusmsg`, which is the seam issue
## 0887 found broken (bytes against characters).
proc c_trip {r} { return [expr {[c_bar $r] eq [cadence::_annot_fit [c_unf $r]] ? 1 : 0}] }

catch {xschem annotate_op $C_RAW 0}
update idletasks

check "C0 CONTROL the clause fixture is live: one instance, a NUMERIC block on MC1, a resolved vector, and no issue-0909 cause clause on the press" \
  [list [xschem get instances] \
        [expr {[string first {11.1u} [dc_ans ::op_annot::text MC1]] >= 0 ? 1 : 0}] \
        [expr {[lindex $C_PAIRS 0] ne {} ? 1 : 0}] \
        [expr {[string first {Some values are blank} [c_bar [c_press 0 <Key-6>]]] >= 0 ? 1 : 0}]] \
  [list 1 1 1 0]

# ---------------------------------------------------------------------------
# B1 — THE BIT-3 BUDGET, WHICH NOTHING ELSE IN THE TREE SWEEPS
# ---------------------------------------------------------------------------
# ⚠ VERIFIED BY READING THEM, NOT ASSUMED: row A11-10 of test_op_annot.tcl
# (:15741-15779, 386 combinations) and row V21 both iterate masks 0..7 ONLY, and
# item A4 does not own that file. So this is the only place in the tree where a
# bit-3 sentence is held to the 255 bytes of `char statusmsg_text[256]`
# (src/xschem.h:1859).
#
# ⚠ AND A11-10 COULD NOT CATCH THE INTERESTING FAILURE ANYWAY: it asserts the
# FITTED string is <= 255, which a clause that has been silently amputated
# satisfies. Leg 2 is the leg that matters -- the clause must SURVIVE the
# elision, not merely fit when nothing else is competing.
#
# ⚠ LEG 2 IS ALSO THE PLACEMENT ASSERTION, AND THE PLACEMENT WAS MEASURED, NOT
# STYLED. With the clause appended LAST (issue 1251's own literal suggestion),
# mask 15 + live + five symbol types fits to 254 bytes with `clause_in` 0 -- the
# elision eats the clause itself, so the fix would be invisible exactly when the
# line is longest. Appended after issue 0909's cause and BEFORE the state clause,
# the same combination fits to 249 with the clause intact. Measured 2026-09-02.
#
# ⚠ AN ORDINARY RESULTS PATH, NOT THIS SUITE'S SCRATCH PATH. The budget must be
# measured against what a user's tree looks like; the scratch root varies by 50+
# bytes between checkouts, which is issue 1250's whole subject.
set C_PATH /home/user/work/proj/sim/run1/netlist/mycell_ase.raw
set C_TYPES5 {resistor capacitor inductor diode subcircuit}
set C_CAUSE {Some values are blank because the results file has no device values like gm and vth in it. Run the simulation again with them saved.}
set C_STATES {off live noop loaded failed noraw nopath stale}

set C_OVER {}
foreach mask {8 9 10 11 12 13 14 15} {
  foreach st $C_STATES {
    foreach ty [list {} $C_TYPES5] {
      foreach cz [list {} $C_CAUSE] {
        set u [cadence::_annot_msg $mask $st $C_PATH $ty $cz]
        set nb [cadence::_annot_bytes [cadence::_annot_fit $u]]
        if {$nb > 255} { lappend C_OVER "$mask/$st/[llength $ty]/[string length $cz]=$nb" }
      }
    }
  }
}
## ⚠ LEG 2 SWEEPS ALL EIGHT STATES, NOT JUST live/loaded. It used to sweep two,
## because the clause used to be gated on those two -- and that gate was the
## defect the adversary pass found (row S8 leg 3). A survival leg that only
## visits the states the clause is allowed into cannot notice the day the gate
## widens and the budget does not.
set C_SURV {}
foreach st $C_STATES {
  foreach ty [list {} $C_TYPES5] {
    foreach mask {9 15} {
      lappend C_SURV [c_has [cadence::_annot_fit [cadence::_annot_msg $mask $st $C_PATH $ty {}]]]
    }
  }
}
## ⚠ LEG 5 IS A MEASURED LIMIT, RECORDED SO IT CANNOT BE MISREAD AS COVERAGE.
## When issue 0909's cause clause is ALSO present, 132 bytes of it, the wall is
## reached and something must go. Measured over the same 256 sentences: at mask 9
## the clause always survives; at masks 11, 13 and 15 -- the arms whose own base
## sentence is longest -- it never does, in ANY state, with or without symbol
## types. That is A11-12b's ordering doing its job (the answer to the question
## the key just asked outranks the rest), not an accident, and legs 3/4 assert
## the same trade on one worked case. It is also the reason the wording is 52
## bytes and not the 98-byte one issue 1251 costs out.
set C_EAT {}
foreach mask {9 11 13 15} {
  set bad 0
  foreach st $C_STATES {
    foreach ty [list {} $C_TYPES5] {
      if {![c_has [cadence::_annot_fit \
                     [cadence::_annot_msg $mask $st $C_PATH $ty $C_CAUSE]]]} { incr bad }
    }
  }
  lappend C_EAT $mask=$bad
}
## ⚠ LEG 6 CLOSES A HOLE THE SABOTAGE MATRIX FOUND IN THIS VERY ROW. Legs 1..5
## only ever look at masks with bit 0 SET, so a gate widened to `$mask & 8` alone
## -- issue 1251's own literal suggestion -- left B1 green while masks 8/10/12/14
## gained a clause about a sheet nothing had hidden (RULING D-8). Rows S8/S9/E2/E4
## caught it; this row did not, and now does.
set C_NOCL 0
foreach mask {8 10 12 14} {
  foreach st $C_STATES {
    foreach ty [list {} $C_TYPES5] {
      foreach cz [list {} $C_CAUSE] {
        if {[c_has [cadence::_annot_msg $mask $st $C_PATH $ty $cz]]} { incr C_NOCL }
      }
    }
  }
}
set C_L3U [cadence::_annot_msg 15 loaded $C_PATH $C_TYPES5 $C_CAUSE]
set C_L3F [cadence::_annot_fit $C_L3U]
check "B1 the bit-3 budget: 256 sentences all fit 255 bytes, the clause SURVIVES the elision in every no-cause case in every state, and where the cause and the clause cannot both fit issue 0909's ordering makes the CAUSE win" \
  [list $C_OVER $C_SURV \
        [expr {[cadence::_annot_bytes $C_L3F] < [cadence::_annot_bytes $C_L3U] ? 1 : 0}] \
        [expr {[string first {Some values are blank} $C_L3F] >= 0 ? 1 : 0}] \
        [c_has $C_L3F] $C_EAT $C_NOCL] \
  [list {} [lrepeat 32 1] 1 1 0 {9=0 11=16 13=16 15=16} 0]

# ---------------------------------------------------------------------------
# E1 — END TO END, CHORD `6`
# ---------------------------------------------------------------------------
# The brief's acceptance row, driven rather than argued: a real
# `event generate .drw <Key-6>` through src/cadence_style_rc's binding, and what
# `xschem get statusmsg` holds afterwards.
set E1_OFF [c_press 0 <Key-6>]
set E1_ON  [c_press 8 <Key-6>]
check "E1 END TO END chord 6: from mask 8 the held status line NAMES the declutter, from mask 0 it does not, and the two sentences differ by the clause and nothing else" \
  [list [c_mask $E1_OFF] [c_mask $E1_ON] \
        [c_has [c_bar $E1_ON]] [c_has [c_bar $E1_OFF]] \
        [c_nfit $E1_OFF] [c_nfit $E1_ON] \
        [c_trip $E1_OFF] [c_trip $E1_ON] \
        [expr {[string map [list $DC_CLAUSE {}] [c_unf $E1_ON]] eq [c_unf $E1_OFF] ? 1 : 0}]] \
  [list 1 9 1 0 1 1 1 1 1]

# ---------------------------------------------------------------------------
# E2 — END TO END, CHORD `Alt-6`
# ---------------------------------------------------------------------------
# ⚠ THE THIRD LEG IS RULING D-8 AT THE SURFACE. `Alt-6` from mask 8 lands on
# mask 10: the declutter bit is armed and ANNOT_SHOW_OP is not, so A3's rung
# hides nothing and the line must stay silent about it. That is the case issue
# 1251's own suggested gate (`if {$mask & 8}` alone) would get wrong.
set E2_OFF [c_press 1 <Alt-Key-6>]
set E2_ON  [c_press 9 <Alt-Key-6>]
set E2_ARM [c_press 8 <Alt-Key-6>]
set E2_CTL [c_press 0 <Alt-Key-6>]
check "E2 END TO END chord Alt-6: mask 9 -> 11 names the declutter, mask 1 -> 3 does not, and mask 8 -> 10 does NOT either because bit0 is clear and nothing is hidden (D-8)" \
  [list [c_mask $E2_OFF] [c_mask $E2_ON] [c_mask $E2_ARM] [c_mask $E2_CTL] \
        [c_has [c_bar $E2_ON]] [c_has [c_bar $E2_OFF]] [c_has [c_bar $E2_ARM]] \
        [expr {[string map [list $DC_CLAUSE {}] [c_unf $E2_ON]] eq [c_unf $E2_OFF] ? 1 : 0}] \
        [expr {[c_unf $E2_ARM] eq [c_unf $E2_CTL] ? 1 : 0}]] \
  [list 3 11 10 2 1 0 0 1 1]

# ---------------------------------------------------------------------------
# E3 — END TO END, CHORD `Ctrl-6`: THE CAN'T-HAPPEN CONTROL
# ---------------------------------------------------------------------------
# ⚠ GREEN BEFORE AND AFTER ITEM A4, ON PURPOSE. RULING D-8 gives `Ctrl-6` bit 3
# for free: `cadence::_annot_mask none` returns a hard 0, so the chord clears the
# declutter with everything else and there is no "declutter on" state left for
# the sentence to name. Rows D6/D7 say that by mask; this says it by SENTENCE,
# which is the half the brief's acceptance list asks for. A clause appearing here
# would mean the gate had lost its bit-0 term.
set E3_OFF [c_press 3 <Control-Key-6>]
set E3_ON  [c_press 11 <Control-Key-6>]
check "E3 END TO END chord Ctrl-6 (the can't-happen control): from mask 3 and from mask 11 the line is the same Annotation-is-off sentence with no clause, and the mask is a hard 0 both times (D-8, row D7)" \
  [list [c_mask $E3_OFF] [c_mask $E3_ON] \
        [c_has [c_bar $E3_ON]] [c_has [c_bar $E3_OFF]] \
        [expr {[c_bar $E3_ON] eq [c_bar $E3_OFF] ? 1 : 0}] \
        [c_bar $E3_OFF]] \
  [list 0 0 0 0 1 {Annotation is off. The schematic is not showing simulation numbers.}]

# ---------------------------------------------------------------------------
# E4 — END TO END, CHORD `Alt-Shift-6`, AND THE MINTER THAT STAYED PURE
# ---------------------------------------------------------------------------
# ⚠ THIS CHORD DOES NOT GO THROUGH `cadence::_annot_msg` AT ALL, WHICH IS WHY IT
# NEEDED A DECISION RATHER THAN A ONE-LINE APPEND. `cadence::annot_tran` mints
# through `cadence::_annot_tran_msg` (utils/annot_mode.tcl:1754), a PURE
# four-argument function that takes NO mask, RAISES on any unknown state, and is
# golded byte for byte in tests/headless/test_op_annot.tcl -- a file item A4 does
# not own. So the clause is appended at the CALL SITE, on the mask `annot_tran`
# has just WRITTEN, and the minter's signature and every one of its goldens are
# untouched. Leg 6 is that claim: the minter alone still returns the shipped
# sentence, with no clause in it, whatever the mask says.
catch {xschem raw clear}
xschem load $C_FIX
update idletasks
catch {xschem raw read $C_TRAW tran}
catch {xschem cursor 2 1}
catch {xschem set cursor2_x 4e-9}
update idletasks
set E4_CUR [dc_ans ::cadence::_annot_tran_cursor]
set E4_OFF [c_spy 1 <Alt-Shift-Key-6>]
set E4_ON  [c_spy 9 <Alt-Shift-Key-6>]
set E4_ARM [c_spy 8 <Alt-Shift-Key-6>]
check "E4 END TO END chord Alt-Shift-6: from mask 9 the transient sentence names the declutter and the mask lands on 13, from mask 1 it does not and lands on 5, from mask 8 it does not either (bit0 clear), and _annot_tran_msg itself is byte-unchanged and mask-free" \
  [list $E4_CUR [c_mask $E4_OFF] [c_mask $E4_ON] [c_mask $E4_ARM] \
        [c_has [c_bar $E4_ON]] [c_has [c_bar $E4_OFF]] [c_has [c_bar $E4_ARM]] \
        [expr {[string map [list $DC_CLAUSE {}] [c_unf $E4_ON]] eq [c_unf $E4_OFF] ? 1 : 0}] \
        [dc_ans ::cadence::_annot_tran_msg ok 4e-09 B]] \
  [list {4e-09 B sheet} 5 13 12 1 0 0 1 \
        {Showing each node's voltage at 4 ns, where cursor B is on the waveform.}]

# ---------------------------------------------------------------------------
# E5 — STRUCTURAL: THE TRANSIENT TAIL FEEDS THE CLAUSE THE MASK IT JUST WROTE
# ---------------------------------------------------------------------------
# ⚠ NO BEHAVIOURAL ROW CAN SEE THIS ONE. A tail that re-read `xschem get
# annot_show` between the write and the clause would answer identically on this
# bench and differently in a session where anything at all sits between them --
# an rc hook, a menu tick, another window's `annot_show_sync_cache()`. The mask
# the sentence describes must be the mask the press WROTE, and the only way to
# say that is in the source.
set E5_SRC [opa_slurp $DC_SRC]
set E5_AT  [opa_proc_src $E5_SRC cadence::annot_tran]
set E5_TM  [opa_proc_src $E5_SRC cadence::_annot_tran_msg]
set E5_WI  [string first {xschem set annot_show $newmask} $E5_AT]
set E5_CI  [string first {_annot_declutter_clause $newmask} $E5_AT]
check "E5 STRUCTURAL annot_tran's success tail hands the clause the mask it just WROTE, with no second `xschem get annot_show` between them, and _annot_tran_msg is left mask-free" \
  [list [expr {[string length $E5_AT] > 0 ? 1 : 0}] \
        [dc_ngrep $DC_SRC {set newmask \[expr \{\$mask \| 4\}\]}] \
        [expr {$E5_WI >= 0 ? 1 : 0}] \
        [expr {$E5_CI >= 0 ? 1 : 0}] \
        [expr {($E5_WI >= 0 && $E5_CI > $E5_WI) ? 1 : 0}] \
        [expr {[string first {xschem get annot_show} \
                 [string range $E5_AT $E5_WI $E5_CI]] < 0 ? 1 : 0}] \
        [expr {[string first {_annot_declutter_clause} $E5_TM] < 0 ? 1 : 0}] \
        [expr {[string first {mask} [lindex [split $E5_TM "\n"] 0]] < 0 ? 1 : 0}]] \
  [list 1 1 1 1 1 1 1 1]

# ---------------------------------------------------------------------------
# E6 — END TO END WITH NO RESULTS FILE AT ALL, WHICH IS THE COMMON FIRST PRESS
# ---------------------------------------------------------------------------
# ⚠ THIS ROW EXISTS BECAUSE ITEM A4 GOT IT WRONG FIRST, AND EVERY OTHER ROW IN
# THIS SECTION AGREED WITH IT. The clause shipped behind
# `$state eq {live} || $state eq {loaded}`, reasoned from issue 0909's `canask`
# term: a press that found no results file has already been told so, and telling
# it as well that its sheet is decluttered would describe a sheet the press never
# drew. E1..E5 all warm to a LOADED raw first (`c_press` does `dc_setmask 1 ;
# dc_fire <Key-6>` before it measures), so not one of them could see it.
#
# ⚠ AND THE SHEET'S HALF OF THIS ROW WAS INVERTED BY ITEM A5 — LEG 5 FLIPS 0 -> 1.
# Item A4 wrote this row on the reading "the sheet IS decluttered at mask 9 even
# with no raw", which was true of item A3's gate: that gate opened on a RESOLVING
# DESCRIPTOR (`annot_overlay_gate(n)` AND a non-blank `op_annot::text` block),
# not on numbers arriving. Ruling D-6 says the declutter reaches instances that
# "got OP numbers", and a label with no number did not get one, so item A5-a
# requires at least one row carrying an ACTUAL VALUE. With `xschem raw loaded` =
# -1 NOTHING is now hidden and `CW=1u` survives at mask 9. Rows A30/A32 are that
# fact on section A's fixture; this row is it end to end, through the chord.
#
# ⚠ THE KNOWN GAP THIS ROW DELIBERATELY KEEPS ASSERTING — NEW ISSUE 1257. Legs 8
# and 11 still gold the clause PRESENT on that press, i.e. the held status line
# still says other device text is hidden on a sheet where nothing was hidden.
# `cadence::_annot_declutter_clause` is gated on bit3 AND bit0 only, and it lives
# in utils/annot_mode.tcl, which is item A4's landed file and NOT item A5's to
# edit. Filed as 1257 and handed on; the gap is documented here rather than
# hidden, so whoever fixes it flips legs 8/11 and this comment together.
#
# ⚠ THE VIEWPORT IS ITS OWN, and the export is WARMED like sections I, N and A --
# one throwaway of the same format first, so a first-export difference cannot
# alias into a pass.
set C_VP {2000 1600 100 -420 620 -180}
proc c_pr {out} {
  if {[catch {eval [linsert $::C_VP 0 xschem print svg $out]} r]} { return RAISED:$r }
  if {![file isfile $out]} { return NO-FILE }
  set fd [open $out r] ; set d [read $fd] ; close $fd ; return $d
}
proc c_pr2 {out} { c_pr $out.warm ; return [c_pr $out] }
proc c_hasl {lst n} { return [expr {[lsearch -exact $lst $n] >= 0 ? 1 : 0}] }

## ⚠ THE `Run a simulation first` LEG READS THE UNFITTED SENTENCE, NOT THE BAR.
## This suite's scratch root is ~90 bytes and it is pasted into the `noraw`
## clause, so the bar really is elided here -- which is issue 1250's whole
## subject, met head on in the one row of this file that carries a path. The
## clause is asserted on the BAR (it is early, so the elision cannot reach it)
## and the tail on the sentence the mint built; leg 12 is the C round trip that
## ties the two together.

## ⚠ A FIXTURE DIRECTORY OF ITS OWN, WITH NO RAW IN IT. `xschem raw clear` only
## UNLOADS; section C's cfix.raw is still on disk beside $C_FIX, and the press
## re-reads it from `$::netlist_dir` and lands on `loaded`, not `noraw`. Measured
## while writing this row -- the first draft asserted `noraw` and got
## "Loaded results from .../cfix.raw." So the sheet is written into an empty
## subdirectory and `::netlist_dir` points at it for the length of the row.
set E6_DIR [file join $scratch e6noraw]
file mkdir $E6_DIR
set E6_FIX [file join $E6_DIR e6fix.sch]
set C_FD [open $E6_FIX w]
puts $C_FD "v {xschem version=3.4.5 file_version=1.2}
G {}
V {}
S {}
E {}
C \{$C_SYM\} 300 -300 0 0 \{name=MC1\}"
close $C_FD
foreach f [glob -nocomplain [file join $E6_DIR *.raw]] { catch {file delete $f} }
catch {xschem raw clear}
set ::netlist_dir $E6_DIR
xschem load $E6_FIX
update idletasks
set E6_LOADED -99 ; catch {set E6_LOADED [xschem raw loaded]}
dc_annot 1 ; set E6_T1 [dc_ntexts [c_pr2 [file join $scratch e6_m1.svg]]]
dc_annot 9 ; set E6_T9 [dc_ntexts [c_pr2 [file join $scratch e6_m9.svg]]]
dc_annot 0
set E6_ON  [c_spy 8 <Key-6>]
set E6_OFF [c_spy 0 <Key-6>]
check "E6 END TO END with NO results file: ruling D-6 needs a NUMBER so the sheet is NOT decluttered, while the held line still names the declutter (issue 1257) and still names the missing raw" \
  [list $E6_LOADED \
        [c_hasl $E6_T1 MC1] [c_hasl $E6_T1 CW=1u] \
        [c_hasl $E6_T9 MC1] [c_hasl $E6_T9 CW=1u] \
        [c_mask $E6_ON] [c_mask $E6_OFF] \
        [c_has [c_bar $E6_ON]] [c_has [c_bar $E6_OFF]] \
        [expr {[string first {Run a simulation first} [c_unf $E6_ON]] >= 0 ? 1 : 0}] \
        [expr {[string map [list $DC_CLAUSE {}] [c_unf $E6_ON]] eq [c_unf $E6_OFF] ? 1 : 0}] \
        [c_trip $E6_ON]] \
  [list -1 1 1 1 1 9 1 1 0 1 1 1]

set ::netlist_dir $scratch
catch {xschem raw clear}
dc_setmask 0

# ============================================================================
# SECTION R — REGISTRATION
# ============================================================================
# full_audit.sh selects by GLOB (`ls "$HERE"/test_*.tcl | sort`); the three named
# lists are OPT-INS for special run modes. This suite must appear in NONE of
# them — `nogui_tests` would strip X and break `bind` and `event generate`
# outright. So full_audit.sh is NOT edited by item A1, and this row is what says
# so out loud.
set R_ME [file rootname [file tail [info script]]]
set R_TXT [opa_slurp $DC_AUDIT]
check "R1 registered by glob, listed in none of nogui_tests / logdir_tests / nolog_tests" \
  [list [string match {test_*} $R_ME] \
        [expr {[regexp {mapfile -t files < <\(ls "\$HERE"/test_\*\.tcl \| sort\)} $R_TXT] ? 1 : 0}] \
        [expr {[string first $R_ME $R_TXT] >= 0 ? 1 : 0}]] \
  {1 1 0}

# --- clean up ---------------------------------------------------------------
dc_setmask 0
catch {xschem set rectcolor 4}

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; exit 1 }
