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
# ⚠ THE FILE NOW COVERS ALL THREE ITEMS, IN THREE PASSES OVER ONE FEATURE:
#   sections D M S T V I   item A1 — the mask bit and the Ctrl-Alt-6 chord
#   section  N             item A2 — TEXT_ANNOT_NAME, the name classifier
#   section  A             item A3 — THE DRAW RUNG, the per-instance D-6 gate,
#                          and the four defects it inherits (1246 1247 1248 1249)
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

## `cadence::_annot_msg` switches on `[expr {$mask & 7}]`, so it is BLIND to
## bit 3 by construction. Do NOT widen it: row V21 of test_op_annot.tcl golds
## its eight arms byte for byte and A1 does not own that file. This row pins the
## blindness so a later "improvement" reds here instead of there.
check "S8 _annot_msg is blind to bit3: mask 1 == mask 9 and mask 3 == mask 11, byte for byte" \
  [list [expr {[cadence::_annot_msg 1 off {} {}] eq [cadence::_annot_msg 9 off {} {}]}] \
        [expr {[cadence::_annot_msg 3 off {} {}] eq [cadence::_annot_msg 11 off {} {}]}]] \
  {1 1}

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
proc a3_mkraw {path pairs} {
  set f [open $path w]
  puts -nonewline $f "Title: A3 declutter fixture\nDate: Mon Jan 1 00:00:00 2026\n"
  puts -nonewline $f "Plotname: Operating Point\nFlags: real\n"
  puts -nonewline $f "No. Variables: [expr {[llength $pairs]/2}]\nNo. Points: 1\nVariables:\n"
  set k 0
  foreach {v val} $pairs { puts -nonewline $f "\t$k\t$v\tvoltage\n" ; incr k }
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
xschem load $A_SAV
update idletasks
dc_setmask 9
catch {xschem annotate_op $A_RAW 0}
catch {xschem update_all_sym_bboxes}
set A15_GOT [list [xschem instance_at 430 -245] [xschem instance_at 300 -300]]
dc_annot 0
check "A15 THE BBOX IS NOT ONE PASS STALE: after annotate_op + ONE update_all_sym_bboxes (no redraw, no export) the box is ALREADY the shrunken one" \
  $A15_GOT [list {} M1]

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
set A17_HS 0 ; catch {set A17_HS $::hide_symbols}
catch {xschem set hide_symbols 2}
dc_annot 9 ; set A17_T9 [dc_ntexts [a3_pr2 [file join $scratch a3_hs2m9.svg]]]
dc_annot 1 ; set A17_T1 [dc_ntexts [a3_pr2 [file join $scratch a3_hs2m1.svg]]]
check "A17 hide_symbols=2 CLOSES the D-6 gate, so the declutter does not fire there: the mask-1 and mask-9 renders are identical" \
  [list [expr {$A17_T9 eq $A17_T1}] [expr {[llength $A17_T9] > 0}]] {1 1}

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
check "A22 CALL-SITE CENSUS: exactly six instance-aware calls (draw 3, svg 1, ps 1, select 1) and no two-argument instance-context call left behind" \
  [list [opa_n_grep $A_DRAW {text_hidden_inst\(}] [opa_n_grep $A_SVGD {text_hidden_inst\(}] \
        [opa_n_grep $A_PS {text_hidden_inst\(}]   [opa_n_grep $A_SEL {text_hidden_inst\(}] \
        [expr {[opa_n_grep $A_DRAW {text_hidden\(.*TEXT_CTX_INSTANCE}] + \
               [opa_n_grep $A_SVGD {text_hidden\(.*TEXT_CTX_INSTANCE}] + \
               [opa_n_grep $A_PS   {text_hidden\(.*TEXT_CTX_INSTANCE}] + \
               [opa_n_grep $A_SEL  {text_hidden\(.*TEXT_CTX_INSTANCE}]}]] \
  {3 1 1 1 0}

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
