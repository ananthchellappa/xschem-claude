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
# NOTHING ON SCREEN CHANGES. That is correct, and rows I2/I3 assert it.
# The draw-time rung is item A3 and the name classifier is item A2; A2 and A3
# add their rows to THIS file.
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
# changes nothing) and is PERMANENT, and I2 says "A1 changes nothing on screen".
# ⚠ ITEM A3 MUST REPLACE I2 — after A3 the two exports MUST differ.

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
check "I2 A3 MUST REPLACE THIS ROW: with OP on, the SVG at mask 1 and mask 9 is byte-identical - A1 adds the bit and the chord only" \
  [list [expr {$i2_a eq $i2_b}] [expr {[string length $i2_a] > 4000}]] {1 1}

dc_annot 0 ; set i3_a [dc_print2 [file join $scratch i3_m0.svg]]
dc_annot 8 ; set i3_b [dc_print2 [file join $scratch i3_m8.svg]]
check "I3 invariant I-C (PERMANENT): with OP off, the SVG at mask 0 and mask 8 is byte-identical" \
  [list [expr {$i3_a eq $i3_b}] [expr {[string length $i3_a] > 4000}]] {1 1}
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
