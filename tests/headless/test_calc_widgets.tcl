# tests/headless/test_calc_widgets.tcl — the Calculator's WIDGET INVENTORY.
#
# Spec  doc/claude/specs/calculator.md  §4 (the W-table) and §4.1 (R110-R113a)
# Plan  doc/claude/calculator_batch/PLAN.md step 1.9
# Ledger doc/claude/calculator_batch/LEDGER.md (RULING-1/2/3)
#
# WHAT THIS FILE IS, AND WHAT IT IS NOT.  Spec §4 says of its own table: "This
# table is a test fixture: R1xx assert existence, class, and initial state of
# each row", and "widget paths are normative — tests address widgets by path".
# This file is that fixture, swept row by row.  It is deliberately NOT a
# geometry suite: everything about pixels, sash fractions, first-open
# proportions and the derived minimum lives in tests/headless/test_calc_skeleton
# (S11, S19, S21, S22), which owns them and must not be duplicated here — a
# second file measuring the same pixels is the second table R413 forbids, in
# test form.  Where this file touches geometry at all it is because the SPEC
# ROW says so (W15's "height 4 is a RENDERED requirement") or because a rule is
# only decidable that way (R112's derived minimum).
#
#   CW1   R101 + W01: one .calc, raised not duplicated, and the toplevel's title
#   CW2   THE INVENTORY: every W-row's path exists, has the spec's class, and is
#         MANAGED AND MAPPED — a control that is built and never packed is
#         invisible to the user and perfect to `winfo exists`.  The slave list
#         of every container the spec gives rows to is asserted with it.
#         `MISSING` is an explicit value so absence is assertable rather than
#         being an error that takes the rest of the group with it.
#   CW3   FIRST-OPEN STATE: every W-row's initial state, read before anything in
#         this file has touched the window.  Clip checked (W10), Append (W13),
#         `Special Functions` (W27), undo/redo disabled (W22), an empty Stack
#         (W24), an empty status line and an empty history (W33/W34), nothing
#         armed (W07).
#   CW4   W02: the six cascades, in order, every entry disabled
#   CW5   W07 + R202: the eight rendered-and-disabled ids cannot be armed by
#         `invoke` NOR by a click, and the click says why
#   CW6   W15: the buffer really accepts typing, and its undo stack is live
#   CW7   W23-W25: the Stack is empty and its scrollbar is wired to its listbox
#   CW8   W26-W28 + RULING-3 + catalogue defects D1/D3: the default category
#         renders NON-EMPTY, the fourteen dead-route entries are RENDERED and
#         DISABLED rather than absent, and `returns` tells integ from iinteg
#   CW9   W29-W31 + RULING-2: the twelve operator keys, the four user buttons,
#         and NO DIGIT KEY — asserted positively, because a later hand can undo
#         a ruling silently
#   CW10  W32-W34 + R507-R509: status writes and records, the history caps at
#         50 newest-first, the empty string clears without recording
#   CW11  R110 / R111 / R112 / R112a — what a headless run can honestly decide
#   CW12  R113 + R113a: THE COLOURS COME THROUGH ONE ACCESSOR.  Proved by
#         changing what the accessor returns and observing the widgets, not by
#         comparing two literals — a literal-equality check is vacuous evidence
#         for R113 (spec R113: "no literal colour is written in
#         src/calculator.tcl, and there are no fallback defaults").  The
#         observation is a WALK of the live window (91 widgets x 580 colour
#         options here), not a hand-written table, and the source-literal scan
#         anchors on the option-name SUFFIX so the -active*/-highlight*/
#         -disabled* families are not invisible to it.
#   CW13  PHASE-1 INERTNESS: every enabled control routes through the stub,
#         speaks (R506), and changes neither the buffer nor the Stack.
#
# Needs a DISPLAY (Tk widgets).  Standalone from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_calc_widgets.tcl
# or, gated and on the dev display:
#   tests/headless/run_suites.sh test_calc_widgets

set fail 0; set npass 0
proc check {name got exp} {
    global fail npass
    if {$got eq $exp} { puts "ok:   $name"; incr npass } \
    else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
# ⚠ `check_expr`, not the house `check_true`.  The house helper
# (test_calc_skeleton.tcl:33, wvbs_common.tcl:78) is
# `check $name [expr {$cond ? 1 : 0}] 1`, which takes an already-EVALUATED
# boolean; every predicate in an inventory file is a script over a widget that
# may not exist, so passing it evaluated means the abort happens at the CALL
# site, outside the group's catch, and takes the rest of the group with it.
# This one takes the expression as a script and evaluates it in the caller's
# frame, so a throw is the check's own failure and nothing behind it is lost.
proc check_expr {name cond} {
    if {[catch {uplevel 1 [list expr $cond]} v]} { set v "ERR:$v" }
    check $name [expr {$v eq {1} ? 1 : 0}] 1
}
proc pcall {args} { if {[catch {uplevel 1 $args} r]} { return "ERR:$r" } ; return $r }
proc ::bgerror {msg} { puts "BGERROR: $msg"; incr ::fail }

# ⚠ WHOLE-FILE gate, and the banner spelling matters.  full_audit.sh's is_skip
# (:237) runs BEFORE is_pass and matches `RESULT: SKIP`; that is CORRECT for a
# file that ran no checks at all, and wrong for a per-group skip (it would
# discard every check that did run).  This file has no per-group skip: every
# group needs Tk, so it is all-or-nothing.  test_calc_skeleton.tcl:100 prints
# `RESULT: ALL PASS (0 checks)` here, which matches none of the three is_skip
# spellings and scores a hollow PASS — deliberately not copied.
if {![info exists ::has_x] || [info commands winfo] eq {}} {
    puts "RESULT: SKIP (no X: the Calculator widget inventory is Tk-only)"
    flush stdout
    exit 0
}

# --- readers that never throw -------------------------------------------------
# A widget-inventory check must be able to say "not there" as a VALUE.  If
# absence threw, one missing widget would abort the group and delete every
# check behind it — the trap item 4 hit twice (receipt 04 §3).
proc wcls {p} {
    if {![winfo exists $p]} { return MISSING }
    return [winfo class $p]
}
proc wcg {p opt} {
    if {![winfo exists $p]} { return MISSING }
    if {[catch {$p cget $opt} v]} { return "NOOPT" }
    return $v
}
# the children of a widget that may not exist
proc wkids {p} {
    if {![winfo exists $p]} { return {} }
    return [winfo children $p]
}
# a calc:: namespace variable that may not have been declared.  `NOVAR` is an
# explicit value for the same reason `MISSING` is: against a tree where the
# feature is absent, reading it must be a failed CHECK and not an abort that
# deletes the rest of the group.
proc nsv {name} {
    if {[info exists ::calc::$name]} { return [set ::calc::$name] }
    return NOVAR
}
# ⚠ a RESTORER, not a creator: `set ::calc::selmode {}` on a tree that has no
# such variable MINTS it, and every later check that reads it then passes on a
# value this file wrote.  It only writes what it found.
proc nsset {name val} {
    if {[info exists ::calc::$name]} { catch {set ::calc::$name $val} }
}
# pack slaves of a widget that may not exist.  `pcall` would answer with an
# `ERR:...` STRING, whose word count is 5 — enough to satisfy a `[llength ...]
# > 1` guard, which is how an absent row once looked like a populated one.
proc pslaves {p} {
    if {![winfo exists $p]} { return {} }
    if {[catch {pack slaves $p} v]} { return {} }
    return $v
}
# every widget under .calc, skipping menus (a menubar clone `.calc.#calc#mbar`
# is a child of the toplevel and is not a control) and combobox popdowns.
proc cwalk {w {acc {}}} {
    if {![winfo exists $w]} { return $acc }
    if {[winfo class $w] in {Menu}} { return $acc }
    if {[string match {*#*} $w]} { return $acc }
    lappend acc $w
    if {[winfo class $w] eq {TCombobox}} { return $acc }
    foreach c [winfo children $w] { set acc [cwalk $c $acc] }
    return $acc
}
proc group {name script} {
    if {[catch {uplevel 1 $script} e]} {
        puts "FAIL: group $name ABORTED -> $e : FAIL"
        puts $::errorInfo
        incr ::fail
    }
}

if {[catch {

# =============================================================================
# CW1 — R101 (one instance) and W01 (the toplevel)
# =============================================================================
group CW1 {
    check "R101 no .calc before the first open" [winfo exists .calc] 0
    check "R101 calc::open returns the normative path" [pcall calc::open] .calc
    update idletasks
    set first [pcall winfo id .calc]
    check "R101 a second calc::open returns the SAME toplevel" [pcall calc::open] .calc
    update idletasks
    # the X window id is the identity of the toplevel: a second `toplevel .calc`
    # would have thrown, but a destroy-and-rebuild would not, and R101 says the
    # existing window is RAISED, not replaced.
    check "R101 the second open RAISED it, it did not rebuild it" \
        [pcall winfo id .calc] $first
    check "R101 exactly one Calculator toplevel exists" \
        [llength [lsearch -all -inline [winfo children .] .calc]] 1
    check "W01 the toplevel exists, and is a toplevel" [wcls .calc] Toplevel
    check "W01 title" [pcall wm title .calc] {xschem Calculator}
    check "W01 WM_DELETE_WINDOW closes it rather than destroying it blind" \
        [pcall wm protocol .calc WM_DELETE_WINDOW] calc::close
}

# =============================================================================
# CW2 — THE INVENTORY.  Spec §4's table, path by path, class by class.
# =============================================================================
# {W-row  path  class}, transcribed from spec §4.  A row with several widgets
# appears once per widget so a single absent control names itself.
proc cw_wtable {} {
    return {
        W01 .calc               Toplevel
        W02 .calc.mbar          Menu
        W03 .calc.res           Frame
        W03 .calc.res.tog       Button
        W04 .calc.res.lab       Label
        W05 .calc.res.path      Entry
        W06 .calc.sel           Frame
        W08 .calc.mode          Frame
        W09 .calc.mode.off      Radiobutton
        W09 .calc.mode.family   Radiobutton
        W09 .calc.mode.wave     Radiobutton
        W10 .calc.mode.clip     Checkbutton
        W11 .calc.mode.plot     Button
        W12 .calc.mode.eval     Button
        W13 .calc.mode.dest     TCombobox
        W14 .calc.mode.table    Button
        W15 .calc.buf           Text
        W16 .calc.btb           Frame
        W17 .calc.btb.enter     Button
        W18 .calc.btb.pop       Button
        W19 .calc.btb.swap      Button
        W19 .calc.btb.roll      Button
        W19 .calc.btb.clrbuf    Button
        W19 .calc.btb.clrstk    Button
        W20 .calc.btb.mplus     Button
        W21 .calc.btb.me        Button
        W22 .calc.btb.undo      Button
        W22 .calc.btb.redo      Button
        W23 .calc.stk           Labelframe
        W24 .calc.stk.list      Listbox
        W24 .calc.stk.sb        Scrollbar
        W25 .calc.stk.push      Button
        W25 .calc.stk.pop       Button
        W25 .calc.stk.del       Button
        W25 .calc.stk.recall    Button
        W26 .calc.fn            Frame
        W27 .calc.fn.cat        TCombobox
        W28 .calc.fn.list       Canvas
        W28 .calc.fn.hsb        Scrollbar
        W28 .calc.fn.vsb        Scrollbar
        W29 .calc.pad           Frame
        W32 .calc.status        Frame
        W33 .calc.status.msg    Entry
        W34 .calc.status.hist   TCombobox
    }
}
# W07's 22 ids, in spec §5's two rows.  Their ORDER and grouping are
# test_calc_skeleton S17's; what this file pins is that every one of the 22 the
# spec names is present, at .calc.sel.<id>, as a Radiobutton.
proc cw_selids {} {
    return {vt vf vdc vs op var vn sp vswr hp zm
            it if idc is opt mp vn2 zp yp gd data}
}
proc cw_seldis {} { return {sp zp yp hp vswr zm gd mp} }

# geometry-manager readers, for the ON-SCREEN leg below.  Same never-throw rule
# as wcls/wcg: absence is a VALUE.
proc wmgr {p} {
    if {![winfo exists $p]} { return MISSING }
    set m [winfo manager $p]
    if {$m eq {}} { return UNMANAGED }
    return $m
}
proc wmapped {p} {
    if {![winfo exists $p]} { return MISSING }
    return [winfo ismapped $p]
}
# geometry readers with the same never-throw contract.  A negative sentinel
# rather than `MISSING`, so an arithmetic comparison against them is FALSE (a
# failed check) instead of an error that aborts the group and deletes the rest.
proc wh   {p} { if {![winfo exists $p]} { return -1 } ; return [winfo height $p] }
proc wrh  {p} { if {![winfo exists $p]} { return -2 } ; return [winfo reqheight $p] }
proc ww   {p} { if {![winfo exists $p]} { return -1 } ; return [winfo width $p] }
proc wrw  {p} { if {![winfo exists $p]} { return -2 } ; return [winfo reqwidth $p] }
proc gslaves {p} {
    if {![winfo exists $p]} { return {} }
    if {[catch {grid slaves $p} v]} { return {} }
    return $v
}

group CW2 {
    set missing {}
    set wrongclass {}
    foreach {row path cls} [cw_wtable] {
        set got [wcls $path]
        if {$got eq {MISSING}} { lappend missing "$row $path" ; continue }
        if {$got ne $cls} { lappend wrongclass "$row $path=$got want $cls" }
    }
    check "CW2 every singleton W-row's path exists" $missing {}
    check "CW2 every singleton W-row has the spec's class" $wrongclass {}
    # ...and the per-row legs, so a failure names its own spec row rather than a
    # list.  Same data, one check each: an inventory that only reports a list is
    # a single point of failure for 44 rows.
    foreach {row path cls} [cw_wtable] { check "$row $path class" [wcls $path] $cls }

    # W07 — the 22 selectors
    set m {} ; set c {}
    foreach id [cw_selids] {
        set got [wcls .calc.sel.$id]
        if {$got eq {MISSING}} { lappend m $id }
        # ⚠ MISSING counts as a WRONG CLASS here as well as an absence.  A
        # "wrong class" list that is empty because every widget is absent is a
        # check that is green on a tree with no selector grid at all.
        if {$got ne {Radiobutton}} { lappend c "$id=$got" }
    }
    check "W07 all 22 selector ids exist at .calc.sel.<id>" $m {}
    check "W07 all 22 are Radiobuttons" $c {}
    # ...and nothing BEYOND the 22.  Counting children would count the two
    # hairline group separators (.calc.sel.sep1/.sep2, which are Frames), so the
    # count is of Radiobuttons: a 23rd selector is what this is looking for.
    set extra {} ; set nrb 0
    foreach w [wkids .calc.sel] {
        if {[wcls $w] ne {Radiobutton}} continue
        incr nrb
        if {[lsearch -exact [cw_selids] [winfo name $w]] < 0} { lappend extra $w }
    }
    # the COUNT rides along, or "no selector beyond the 22" is green on a window
    # that has none.
    check "W07 the grid is exactly the spec's 22 selectors, no more" \
        [list $nrb $extra] {22 {}}

    # W30 — the keypad keys .calc.pad.k<n>, and W31 — .calc.pad.u1..u4
    set nk [llength [pcall calc::pad_keys]]
    set m {}
    for {set i 1} {$i <= $nk} {incr i} {
        if {[wcls .calc.pad.k$i] ne {Button}} { lappend m k$i }
    }
    check "W30 every .calc.pad.k<n> exists and is a Button" $m {}
    # ⚠ the ABSENCE of a k13 rides on the PRESENCE of k1..k12: a bare
    # `winfo exists .calc.pad.k13` is 0 on a window with no keypad at all.
    set kn {}
    foreach w [wkids .calc.pad] {
        if {[regexp {^k([0-9]+)$} [winfo name $w] -> i]} { lappend kn $i }
    }
    set want {}
    for {set i 1} {$i <= $nk} {incr i} { lappend want $i }
    check "W30 the pad holds exactly k1..k$nk, no more" [lsort -integer $kn] $want
    set m {}
    for {set i 1} {$i <= 4} {incr i} {
        if {[wcls .calc.pad.u$i] ne {Button}} { lappend m u$i }
    }
    check "W31 user 1..4 exist and are Buttons" $m {}
    set un {}
    foreach w [wkids .calc.pad] {
        if {[regexp {^u([0-9]+)$} [winfo name $w] -> i]} { lappend un $i }
    }
    check "W31 the pad holds exactly u1..u4, no more" [lsort -integer $un] {1 2 3 4}

    # --- ON SCREEN, not merely BUILT -------------------------------------------
    # ⚠ THE HOLE THIS CLOSES, and it is the one src/calculator.tcl's own build
    # comment records as previously MEASURED: "`winfo ismapped .calc.btb` was 0
    # and the whole button row was simply not on screen, with every widget check
    # green because the widgets all existed".  `winfo exists` + class + `cget`
    # cannot see a control that was created and never handed to a geometry
    # manager — it is invisible to the user and perfect to the inventory.
    # Measured on the shipped build (2026-08-15, fixer round): deleting
    # `pack .calc.mode.clip`, `pack .calc.mode.dest`, `pack .calc.mode.table`,
    # `pack .calc.status.hist` or the `grid` of `.calc.stk.recall`/`.calc.stk.sb`
    # left BOTH this file and test_calc_skeleton entirely green.  So: every
    # W-row widget must be MANAGED and MAPPED, and the containers the skeleton
    # does not pin have their slave lists asserted in order below.
    set unmanaged {} ; set unmapped {}
    foreach {row path cls} [cw_wtable] {
        # `.calc.mbar` is the one exemption and it is checked by name below: a
        # menubar is attached with `-menu`, so its manager is `wm` and it is
        # never mapped as a child.  `.calc` itself is a toplevel: `wm` is its
        # correct manager, and it must be mapped.
        if {$path eq {.calc.mbar}} continue
        if {[wmgr $path] in {MISSING UNMANAGED}} { lappend unmanaged "$row $path=[wmgr $path]" }
        if {[wmapped $path] ne {1}} { lappend unmapped "$row $path=[wmapped $path]" }
    }
    foreach id [cw_selids] {
        if {[wmgr .calc.sel.$id] in {MISSING UNMANAGED}} { lappend unmanaged "W07 $id" }
        if {[wmapped .calc.sel.$id] ne {1}} { lappend unmapped "W07 $id" }
    }
    for {set i 1} {$i <= $nk} {incr i} {
        if {[wmgr .calc.pad.k$i] in {MISSING UNMANAGED}} { lappend unmanaged "W30 k$i" }
        if {[wmapped .calc.pad.k$i] ne {1}} { lappend unmapped "W30 k$i" }
    }
    for {set i 1} {$i <= 4} {incr i} {
        if {[wmgr .calc.pad.u$i] in {MISSING UNMANAGED}} { lappend unmanaged "W31 u$i" }
        if {[wmapped .calc.pad.u$i] ne {1}} { lappend unmapped "W31 u$i" }
    }
    check "CW2 every W-row widget is handed to a geometry manager" $unmanaged {}
    # ...and the COUNT rides along, or "nothing unmapped" is green on a window
    # with no widgets in it at all.
    set nmapped 0
    foreach {row path cls} [cw_wtable] {
        if {$path eq {.calc.mbar}} continue
        if {[wmapped $path] eq {1}} { incr nmapped }
    }
    # the floor is the spec table's own row count (minus the exempt menubar), so
    # it is the SPEC that says how many controls must be on screen, not a number
    # this file made up.
    check "CW2 every W-row widget is MAPPED — built-but-unpacked is invisible" \
        [list [expr {$nmapped >= [expr {[llength [cw_wtable]]/3 - 1}]}] $unmapped] {1 {}}
    check "W02 the menubar is the ONE exemption: attached with -menu, not packed" \
        [list [wmgr .calc.mbar] [pcall .calc cget -menu]] {wm .calc.mbar}

    # ...and the slave lists, IN ORDER, of every container the spec's table
    # gives rows to.  A mapped-ness list says "on screen somewhere"; a slave
    # list says "in this box, in this order", which is what catches a control
    # quietly re-parented or a strip re-ordered.  (test_calc_skeleton S19 owns
    # `.calc.btb`'s; it is restated here so one file carries the whole window.)
    check "CW2 .calc packs the status bar and the pane tree, in that order" \
        [pslaves .calc] {.calc.status .calc.pw}
    check "W03-W05 the Results Dir row's slaves, in order" [pslaves .calc.res] \
        {.calc.res.tog .calc.res.lab .calc.res.browse .calc.res.path}
    # ⚠ `lrange … 0 end` re-forms the expected list on ONE line: `check` is a
    # string comparison and a brace group split over two source lines carries a
    # newline the live `pack slaves` answer does not have.
    check "W08-W14 the mode strip's slaves, in order" [pslaves .calc.mode] \
        [lrange {.calc.mode.off .calc.mode.family .calc.mode.wave .calc.mode.clip
                 .calc.mode.plot .calc.mode.eval .calc.mode.dest .calc.mode.table} 0 end]
    check "W16-W22 the toolbar's slaves, in order" [pslaves .calc.btb] \
        [lrange {.calc.btb.enter .calc.btb.pop .calc.btb.swap .calc.btb.roll
                 .calc.btb.clrbuf .calc.btb.clrstk .calc.btb.mplus .calc.btb.me
                 .calc.btb.undo .calc.btb.redo} 0 end]
    check "W32-W34 the status bar's slaves" [pslaves .calc.status] \
        {.calc.status.hist .calc.status.msg}
    # gridded containers: `grid slaves` answers in stacking order, which is not
    # the spec's reading order, so these are sorted — what is asserted is the
    # SET that is really gridded, not the order (the order is S17's/S19's).
    check "W06-W07 the selector grid's gridded slaves" [lsort [gslaves .calc.sel]] \
        [lsort {.calc.sel.sep1 .calc.sel.sep2 .calc.sel.vt .calc.sel.vf .calc.sel.vdc
                .calc.sel.vs .calc.sel.op .calc.sel.var .calc.sel.vn .calc.sel.sp
                .calc.sel.vswr .calc.sel.hp .calc.sel.zm .calc.sel.it .calc.sel.if
                .calc.sel.idc .calc.sel.is .calc.sel.opt .calc.sel.mp .calc.sel.vn2
                .calc.sel.zp .calc.sel.yp .calc.sel.gd .calc.sel.data}]
    check "W23-W25 the Stack's gridded slaves" [lsort [gslaves .calc.stk]] \
        [lsort {.calc.stk.list .calc.stk.sb .calc.stk.push .calc.stk.pop
                .calc.stk.del .calc.stk.recall}]
    check "W26-W28 the function browser's gridded slaves" [lsort [gslaves .calc.fn]] \
        [lsort {.calc.fn.cat .calc.fn.list .calc.fn.hsb .calc.fn.vsb}]
    set padwant {}
    for {set i 1} {$i <= $nk} {incr i} { lappend padwant .calc.pad.k$i }
    for {set i 1} {$i <= 4} {incr i} { lappend padwant .calc.pad.u$i }
    check "W29-W31 the keypad's gridded slaves" [lsort [gslaves .calc.pad]] \
        [lsort $padwant]
}

# =============================================================================
# CW3 — FIRST-OPEN STATE.  Read before this file has touched anything.
# =============================================================================
group CW3 {
    # W05 — readonly, and it says something rather than being blank: an empty
    # readonly entry and a broken one look identical.
    check "W05 the path entry is readonly" [wcg .calc.res.path -state] readonly
    check "W05 it is driven by the namespace variable, not `configure -text`" \
        [wcg .calc.res.path -textvariable] ::calc::respath
    # ⚠ read through the WIDGET, not the variable: `nsv` answers NOVAR on a tree
    # that has no such variable, and NOVAR is a non-empty string.
    check_expr "W05 with no raw it says so in words, not blank" \
        {[string match {*raw*} [pcall .calc.res.path get]]}
    # W04 — the provenance-bearing label (spec W04, ruled item 13).  With no raw
    # anywhere the wording is phase 1a's, unchanged.
    check_expr "W04 the label reads as a caption" \
        {[string match {Results Dir*} [wcg .calc.res.lab -text]]}
    check "W03 the collapse toggle is live (layout, not behaviour)" \
        [wcg .calc.res.tog -command] calc::res_toggle

    # W07 — nothing armed.  `{}` is the normative unarmed value (spec §4 W07,
    # and R201 returns to it), and the variable is SEEDED rather than created by
    # the first radiobutton — the wave_viewer.tcl:8051 rule: a -variable that
    # does not exist yet is created at the widget's off value, and no check can
    # then tell "deliberately unarmed" from "happened to be empty".
    check "W07 ::calc::selmode exists (seeded, not minted by a widget)" \
        [info exists ::calc::selmode] 1
    check "W07 nothing is armed at first open" [nsv selmode] {}
    set v {} ; set bad {}
    foreach id [cw_selids] {
        if {[wcg .calc.sel.$id -variable] ne {::calc::selmode}} { lappend v $id }
        if {[wcg .calc.sel.$id -value] ne $id} { lappend bad $id }
    }
    check "W07 all 22 share ONE radio variable" $v {}
    check "W07 each selector's -value is its own id" $bad {}
    # ⚠ and the tristate sentinel is the thing that must never be the empty
    # string.  Tk's DEFAULT -tristatevalue IS `{}`, which is exactly the unarmed
    # value, so without this every selector renders in the mixed look at first
    # open (spec §4 W07, ruled phase 1b).
    set t {}
    foreach id [cw_selids] {
        set tv [wcg .calc.sel.$id -tristatevalue]
        # MISSING/NOOPT count as offenders: a window with no selectors would
        # otherwise satisfy "none of them renders half-armed" trivially.
        if {$tv in [list {} NOOPT MISSING]} { lappend t "$id=$tv" }
        if {[lsearch -exact [cw_selids] $tv] >= 0} { lappend t "$id holds a real id" }
    }
    check "W07 no selector's -tristatevalue is the unarmed value, for all 22" $t {}

    # W07/§1.2 — the eight rendered-and-DISABLED ids
    set st {}
    foreach id [cw_seldis] {
        if {[wcg .calc.sel.$id -state] ne {disabled}} { lappend st $id }
    }
    check "W07 the RF block and mp are rendered DISABLED" $st {}
    set en {}
    foreach id [cw_selids] {
        if {[lsearch -exact [cw_seldis] $id] >= 0} continue
        if {[wcg .calc.sel.$id -state] ne {normal}} { lappend en $id }
    }
    check "W07 the other 14 are enabled" $en {}
    check "W07 `data` is an ENABLED selector (§5 marks it v1)" \
        [wcg .calc.sel.data -state] normal

    # W09/W10 — the mode strip
    check "W09 ::calc::pickscope initial" [nsv pickscope] off
    set v {}
    foreach id {off family wave} {
        if {[wcg .calc.mode.$id -variable] ne {::calc::pickscope}} { lappend v $id }
    }
    check "W09 Off/Family/Wave are ONE radio group" $v {}
    check "W09 each -value is its own scope" \
        [list [wcg .calc.mode.off -value] [wcg .calc.mode.family -value] \
              [wcg .calc.mode.wave -value]] {off family wave}
    # ⚠ THE SUITE'S OWN SABOTAGE (plan 1.9): flip Clip's default to 0 and this
    # is what goes red.
    check "W10 Clip is CHECKED at first open" [nsv clip] 1
    check "W10 Clip's variable" [wcg .calc.mode.clip -variable] ::calc::clip
    check "W10 ...and -onvalue is 1, so `checked` really means clip ON" \
        [wcg .calc.mode.clip -onvalue] 1

    # W11/W12/W14 — labels are TEXT here, ruled phase 1b (no icon set exists)
    check "W11 Plot label"  [wcg .calc.mode.plot -text]  {Plot}
    check "W12 Eval label"  [wcg .calc.mode.eval -text]  {Eval}
    check "W14 Table label" [wcg .calc.mode.table -text] {Table}

    # W13 — the plot destination combobox
    check "W13 values" [wcg .calc.mode.dest -values] {Append Replace {New Strip}}
    check "W13 initial" [pcall .calc.mode.dest get] {Append}
    check "W13 readonly" [wcg .calc.mode.dest -state] readonly
    check_expr "W13 a readonly combobox is given the letter-cycle bind" \
        {[string match {*combo_letter_cycle*} [pcall bind .calc.mode.dest <Key>]]}

    # W15 — the buffer
    check "W15 -height 4" [wcg .calc.buf -height] 4
    check "W15 -undo 1" [wcg .calc.buf -undo] 1
    check "W15 editable" [wcg .calc.buf -state] normal
    check "W15 empty at first open" [pcall .calc.buf get 1.0 end-1c] {}

    # W17-W22 — the toolbar, in spec order, with the labels the spec pins
    check "W18 Pop label" [wcg .calc.btb.pop -text] {Pop}
    check "W20 M+ label"  [wcg .calc.btb.mplus -text] {M+}
    check "W21 ME label"  [wcg .calc.btb.me -text] {ME}
    check "W22 undo starts disabled" [wcg .calc.btb.undo -state] disabled
    check "W22 redo starts disabled" [wcg .calc.btb.redo -state] disabled
    set en {}
    foreach id {enter pop swap roll clrbuf clrstk mplus me} {
        if {[wcg .calc.btb.$id -state] ne {normal}} { lappend en $id }
    }
    check "W17-W21 every other toolbar button is enabled" $en {}
    check "W16 the toolbar holds exactly the ten spec buttons" \
        [lsort [lmap w [wkids .calc.btb] {winfo name $w}]] \
        {clrbuf clrstk enter me mplus pop redo roll swap undo}

    # W23-W25 — the Stack
    check "W23 caption" [wcg .calc.stk -text] {Stack}
    check "W23 the PANE that holds it carries no second caption" \
        [wcg .calc.pw.stk -text] {}
    check "W24 the Stack list is EMPTY at first open" [pcall .calc.stk.list size] 0
    check "W24 nothing is selected in it" [pcall .calc.stk.list curselection] {}

    # W27 — the category chooser
    check "W27 initial category" [pcall .calc.fn.cat get] {Special Functions}
    check "W27 readonly" [wcg .calc.fn.cat -state] readonly
    # ⚠ the expected value is §7.1's list SPELLED OUT, not [calc::fn_categories]:
    # comparing the widget to the proc that filled it moves both together, and a
    # reordered catalogue chooser would stay green.
    check "W27 §7.1's categories, in order" [lrange [wcg .calc.fn.cat -values] 0 end] \
        {{Special Functions} Arithmetic Trigonometric Exponential Complex Sequence Constants All}
    check "W27 ...and the widget really was filled from calc::fn_categories" \
        [wcg .calc.fn.cat -values] [pcall calc::fn_categories]

    # W33/W34 — the status area starts silent
    check "W33 readonly" [wcg .calc.status.msg -state] readonly
    check "W33 empty at first open" [pcall .calc.status.msg get] {}
    check "W34 readonly" [wcg .calc.status.hist -state] readonly
    check "W34 the history is empty at first open" [wcg .calc.status.hist -values] {}
    check "W34 ...and so is the model behind it" [pcall calc::status_history] {}
}

# =============================================================================
# CW4 — W02, the menubar
# =============================================================================
# ⚠ `menu index end` answers `none` on an empty menu and an ERR: string on one
# that does not exist, and `for {set i 0} {$i <= <that>}` THROWS on both — which
# would abort this group rather than fail its checks.  Every bound goes through
# here first.
proc mlast {m} {
    set n [pcall $m index end]
    if {![string is integer -strict $n]} { return -1 }
    return $n
}
group CW4 {
    check "W02 the menubar is the toplevel's -menu" [wcg .calc -menu] .calc.mbar
    set labels {}
    for {set i 0} {$i <= [mlast .calc.mbar]} {incr i} {
        lappend labels [pcall .calc.mbar entrycget $i -label]
    }
    check "W02 the six cascades, in the reference's order" $labels \
        {File Tools View Options Constants Help}
    set notcascade {} ; set live {}
    for {set i 0} {$i <= [mlast .calc.mbar]} {incr i} {
        if {[pcall .calc.mbar type $i] ne {cascade}} { lappend notcascade $i ; continue }
        set sub [pcall .calc.mbar entrycget $i -menu]
        if {![winfo exists $sub]} { lappend notcascade $i ; continue }
        for {set j 0} {$j <= [mlast $sub]} {incr j} {
            if {[pcall $sub entrycget $j -state] ne {disabled}} {
                lappend live "$sub $j"
            }
        }
    }
    check "W02 all six are cascades onto a real menu" $notcascade {}
    # phase 1 owns layout, not behaviour: a live entry here would be a phase
    # that ran ahead of its plan row.
    check "W02 every entry in every cascade is disabled" $live {}
}

# =============================================================================
# CW5 — W07 + R202: a disabled selector cannot be armed, and says why
# =============================================================================
group CW5 {
    set armed {} ; set silent {} ; set notip {}
    foreach id [cw_seldis] {
        # absence is an offender, or "none of them can be armed" is green on a
        # window that has no selector grid.
        if {[wcls .calc.sel.$id] ne {Radiobutton}} {
            lappend armed "missing:$id" ; lappend silent "missing:$id"
            lappend notip "missing:$id" ; continue
        }
        nsset selmode {}
        # (a) Tk's own invoke: returns early on a disabled widget, so -command
        #     never fires — which is exactly why R202's line cannot come from
        #     -command (spec §5.1).
        pcall .calc.sel.$id invoke
        if {[nsv selmode] ne {}} { lappend armed "invoke:$id" }
        # (b) a real click.  X still delivers events to a disabled widget, and
        #     the <Button-1> bind is what speaks.
        pcall calc::status {}
        pcall event generate .calc.sel.$id <Button-1> -x 3 -y 3
        if {[nsv selmode] ne {}} { lappend armed "click:$id" }
        if {[nsv statusmsg] eq {}} { lappend silent $id }
        if {![string match "*$id*" [nsv statusmsg]]} { lappend silent "name:$id" }
        # the tooltip §1.2 asks for is `balloon`, which BAKES its string into the
        # <Enter> script at attach time — so the script text is the oracle.
        if {![string match {*balloon_show*} [pcall bind .calc.sel.$id <Enter>]]} {
            lappend notip $id
        }
    }
    check "R202 no disabled selector can be armed, by invoke OR by click" $armed {}
    check "R202 each one explains itself, naming itself" $silent {}
    check "§1.2 each disabled selector carries a tooltip" $notip {}
    check_expr "R202 the refusal says WHY (the reason, not just the name)" \
        {[string match {*not available*} [nsv statusmsg]]}
    # ⚠ read BEFORE resetting: `nsset selmode {}` here and then asserting it is
    # `{}` would be the test agreeing with itself.  The loop left the window in
    # whatever state eight refusals put it in, and that is the question.
    check "R202 selmode is still unarmed after eight refusals" [nsv selmode] {}
    nsset selmode {}
    pcall calc::status {}
}

# =============================================================================
# CW6 — W15: the buffer really is a working text widget
# =============================================================================
group CW6 {
    pcall .calc.buf delete 1.0 end
    pcall .calc.buf insert end {v(out) v(in) / db20()}
    check "W15 the buffer accepts typing" [pcall .calc.buf get 1.0 end-1c] \
        {v(out) v(in) / db20()}
    # ⚠ an explicit separator, because -autoseparators only inserts one on an
    # idle/keystroke boundary: without it a single `edit undo` reverts BOTH
    # inserts and the check below would be asserting an empty buffer, which is
    # also what a dead undo stack produces.
    pcall .calc.buf edit separator
    pcall .calc.buf insert end "\nsecond line"
    check "W15 ...and more than one line" \
        [pcall .calc.buf get 2.0 end-1c] {second line}
    # -undo 1 is not decoration: R505 makes W22 cover buffer edits, and the
    # widget's own stack is what phase 2 will drive.
    check "W15 the undo stack is live" [pcall .calc.buf edit undo] {}
    check "W15 ...and undo really reverted the last edit" \
        [pcall .calc.buf get 1.0 end-1c] {v(out) v(in) / db20()}
    # ⚠ "height 4" is a RENDERED requirement, not just a -height option (spec
    # W15): phase 1b shipped -height 4 in a pane that allotted 29 px of the 72
    # requested and drew one and a half lines while `cget -height` said 4 and
    # 299 checks stayed green.  `bbox 4.0` needs a fourth line to ask about, so
    # the four lines are typed first — an EMPTY buffer has no index 4.0 and the
    # check would then be green for a one-line-tall widget.  The full pixel
    # proof (every pane against its request, at the declared minimum too) is
    # test_calc_skeleton S21's; this is W15's own row, in W15's own file.
    pcall .calc.buf delete 1.0 end
    pcall .calc.buf insert end "l1\nl2\nl3\nl4"
    update idletasks
    check_expr "W15 fixture: the buffer really holds four lines now" \
        {[pcall .calc.buf index end-1c] eq {4.2}}
    set unseen {}
    foreach i {1 2 3 4} {
        set bb [pcall .calc.buf bbox $i.0]
        if {$bb eq {} || [string match {ERR:*} $bb]} { lappend unseen $i }
    }
    check "W15 all four of its lines are really drawn" $unseen {}
    pcall .calc.buf delete 1.0 end
    check "W15 the buffer is clear again" [pcall .calc.buf get 1.0 end-1c] {}
}

# =============================================================================
# CW7 — W23-W25: the Stack's wiring
# =============================================================================
group CW7 {
    # W24: "scrolled by .calc.stk.sb".  Both halves, because either alone is a
    # scrollbar that is pure decoration (the M4 gotcha, recon/widgets.md §4d).
    check "W24 the listbox drives the scrollbar" \
        [wcg .calc.stk.list -yscrollcommand] {.calc.stk.sb set}
    check "W24 the scrollbar drives the listbox" \
        [wcg .calc.stk.sb -command] {.calc.stk.list yview}
    check "W24 top of stack is index 0 — an empty list has no index 0" \
        [pcall .calc.stk.list index end] 0
    check "W25 the four side buttons, in the spec's order" \
        [lmap id {push pop del recall} {wcg .calc.stk.$id -text}] \
        {Push Pop Del Recall}
}

# =============================================================================
# CW8 — W26-W28, the function browser, over the ONE catalogue (R413)
# =============================================================================
proc cw_fnitems {} {
    set d {}
    if {![winfo exists .calc.fn.list]} { return $d }
    foreach i [.calc.fn.list find withtag fnentry] {
        dict set d [.calc.fn.list itemcget $i -text] $i
    }
    return $d
}
proc cw_deadnames {} {
    return {dft psd convolve spectrum spectralPower harmonic harmonicFreq thd
            dftbb psdbb evmQAM evmQpsk pzbode pzfilter}
}

group CW8 {
    check "W28 the list canvas drives BOTH scrollbars" \
        [list [wcg .calc.fn.list -xscrollcommand] [wcg .calc.fn.list -yscrollcommand]] \
        {{.calc.fn.hsb set} {.calc.fn.vsb set}}
    check "W28 ...and both scrollbars drive the canvas, on their own axis" \
        [list [wcg .calc.fn.hsb -command] [wcg .calc.fn.hsb -orient] \
              [wcg .calc.fn.vsb -command] [wcg .calc.fn.vsb -orient]] \
        {{.calc.fn.list xview} horizontal {.calc.fn.list yview} vertical}

    # D1 — the defect that would have shipped a browser whose DEFAULT category
    # rendered empty: the special rows carried `Special`, §7.1's combobox value
    # is `Special Functions`.  The check is deliberately "the rows carry the
    # value the combobox actually holds", not a literal comparison.
    set items [cw_fnitems]
    check_expr "D1 the DEFAULT category renders a non-empty list" \
        {[dict size $items] > 0}
    set cat [pcall .calc.fn.cat get]
    set inspec {}
    foreach row [pcall calc::catalogue] {
        if {[lindex $row 1] eq $cat} { lappend inspec [lindex $row 0] }
    }
    check_expr "D1 ...and it renders EVERY row whose category is what the combobox holds" \
        {[llength $inspec] > 0}
    # ⚠ the non-emptiness rides along: two empty sets are equal, so this check
    # alone is green on a browser that rendered nothing.
    check "D1 rendered set == the table's rows for that exact category string" \
        [list [expr {[llength $inspec] > 0}] [lsort [dict keys $items]]] \
        [list 1 [lsort $inspec]]
    set badcat {}
    foreach row [pcall calc::catalogue] {
        if {[lsearch -exact [pcall calc::fn_categories] [lindex $row 1]] < 0} {
            lappend badcat [lindex $row 0]
        }
    }
    check "D1 no row carries a category the chooser does not offer" $badcat {}
    set cat_rows [pcall calc::catalogue]
    if {[string match {ERR:*} $cat_rows]} { set cat_rows {} }
    check "§7.1 `All` is SYNTHETIC — no row carries it" \
        [list [expr {[llength $cat_rows] > 0}] \
              [lsearch -exact [lmap r $cat_rows {lindex $r 1}] All]] {1 -1}

    # RULING-3 — rendered AND disabled, not absent.  Both halves, because the
    # cheap way to satisfy "no N-route function in v1" is to delete the rows,
    # and that would be a lie about what the tool is.
    set absent {} ; set notgrey {}
    set dfg [pcall calc::color disabledfg]
    set lfg [pcall calc::color fieldfg]
    foreach n [cw_deadnames] {
        # an ABSENT entry is an offender on both lists: "every dead entry is
        # grey" must not be satisfiable by deleting them, which is exactly the
        # shortcut RULING-3 forbids.
        if {![dict exists $items $n]} { lappend absent $n ; lappend notgrey "absent:$n" ; continue }
        if {[.calc.fn.list itemcget [dict get $items $n] -fill] ne $dfg} {
            lappend notgrey $n
        }
    }
    check "RULING-3 every N-route/out-of-scope entry is RENDERED" $absent {}
    check "RULING-3 ...and every one of them is GREY" $notgrey {}
    check_expr "RULING-3 grey is a different colour from a live entry" {$dfg ne $lfg}
    set wronglive {}
    dict for {n i} $items {
        if {[lsearch -exact [cw_deadnames] $n] >= 0} continue
        if {[.calc.fn.list itemcget $i -fill] ne $lfg} { lappend wronglive $n }
    }
    check "RULING-3 ...and no LIVE entry was greyed with them" \
        [list [expr {[dict size $items] > 0}] $wronglive] {1 {}}
    # the greying is read off the ROUTE field of the one table, not a second list
    set byroute {}
    foreach row [pcall calc::catalogue] {
        if {[lsearch -exact [pcall calc::fn_dead_routes] [lindex $row 2]] >= 0} {
            lappend byroute [lindex $row 0]
        }
    }
    check "RULING-3 the dead set comes from the table's route field" \
        [lsort $byroute] [lsort [cw_deadnames]]
    # ...and the click HANDLER refuses with a reason rather than doing nothing.
    # ⚠ NAMED FOR WHAT IT CALLS, not for the gesture.  This calls `calc::fn_click`
    # directly, so it proves the handler and NOT that a click on the canvas item
    # reaches it: deleting `$c bind fn$i <Button-1>` in calc::fn_fill leaves this
    # file entirely green (measured).  The WIRING is test_calc_skeleton S23's
    # ("every entry carries its own click and hover binding" + "a real click on
    # an entry reaches its handler"), which goes 2 FAILED under that same break.
    pcall calc::status {}
    pcall calc::fn_click dft
    check_expr "RULING-3 calc::fn_click on a dead entry refuses, and names it (the canvas WIRING is test_calc_skeleton S23's)" \
        {[string match {*dft*not available*} [nsv statusmsg]]}

    # D3 — `returns` is what tells integ (scalar, the area) from iinteg (wave,
    # the running integral).  Without it the two rows were byte-identical.
    set ri [pcall calc::fn_row integ]
    set rii [pcall calc::fn_row iinteg]
    check "D3 the row schema is six fields" [pcall calc::fn_fields] \
        {name category route returns insert help}
    # ⚠ with the NAME dropped: the two rows always differ by their name, so
    # comparing them whole is a check that cannot fail.  D3's finding was that
    # everything AFTER the name was identical.
    # ⚠ the three fields D3 found byte-identical — category, route, returns —
    # not the whole row: two rows always differ by their NAME, and comparing
    # them whole (or including `help`, which was never the complaint) is a check
    # that a re-broken `returns` would walk straight past.
    check "D3 integ and iinteg differ in category/route/returns, not just in help" \
        [expr {[lrange $ri 1 3] eq [lrange $rii 1 3]}] 0
    check "D3 ...and it is `returns` that separates them" \
        [list [lindex $ri 3] [lindex $rii 3]] {scalar wave}
    set short {}
    foreach row [pcall calc::catalogue] {
        if {[llength $row] != 6} { lappend short [lindex $row 0] }
    }
    check "D3 every row really has all six fields" $short {}

    # R413 — one table, and the hover help comes out of it.
    # ⚠ same naming rule as the click leg above: this calls `calc::fn_hover`
    # directly and proves the HANDLER.  Deleting `$c bind fn$i <Enter>` in
    # calc::fn_fill leaves this file green (measured); test_calc_skeleton S23
    # goes 1 FAILED, and owns the wiring.
    pcall calc::status {}
    nsset statushist {}
    pcall calc::fn_hover average
    check "R413 calc::fn_hover writes the table's own help line (the <Enter> WIRING is test_calc_skeleton S23's)" [nsv statusmsg] \
        [lindex [pcall calc::fn_row average] 5]
    check "R413 ...and does NOT spend the 50-entry history on a tooltip" \
        [pcall calc::status_history] {}
    pcall calc::fn_unhover average
    pcall calc::status {}

    # W28's category switch really repopulates from the table
    pcall .calc.fn.cat set Constants
    set n [pcall calc::fn_fill]
    check "W28 switching category repopulates the canvas" \
        [lsort [dict keys [cw_fnitems]]] {e() k() pi() q()}
    check "W28 ...and fn_fill reports what it drew" $n 4
    pcall .calc.fn.cat set {Special Functions}
    pcall calc::fn_fill
    check "W28 back to the default category" \
        [list [expr {[llength $inspec] > 0}] [dict size [cw_fnitems]]] \
        [list 1 [llength $inspec]]
}

# =============================================================================
# CW9 — W29-W31 + RULING-2: operators, user buttons, and NO DIGITS
# =============================================================================
group CW9 {
    set keys [pcall calc::pad_keys]
    check "W30 the keypad set is the twelve operator tokens (RULING-2, crew)" \
        $keys {+ - * / ** ? == != > < >= <=}
    set wrong {}
    set n 1
    foreach tok $keys {
        if {[wcg .calc.pad.k$n -text] ne $tok} { lappend wrong "k$n" }
        incr n
    }
    check "W30 each k<n> carries its token, in reading order" $wrong {}
    # ⚠ ABSENCE, ASSERTED POSITIVELY.  RULING-2 is a ruling a later hand can
    # undo silently by adding a key, so this looks for a digit rather than
    # counting the keys.
    set digits {}
    foreach w [cwalk .calc.pad] {
        if {[winfo class $w] ne {Button}} continue
        set t [wcg $w -text]
        if {[string match {user *} $t]} continue
        if {[regexp {[0-9]} $t]} { lappend digits "$w=$t" }
    }
    # the absence of a digit rides on the presence of the ruled twelve
    check "W30 NO keypad button carries a digit (RULING-2)" \
        [list [expr {[llength $keys] == 12}] $digits] {1 {}}
    set stray {}
    foreach tok $keys {
        if {[string is double -strict $tok]} { lappend stray $tok }
        if {$tok in {. ±}} { lappend stray $tok }
    }
    check "W30 no key emits a numeric literal, a `.` or a `±`" \
        [list [expr {[llength $keys] == 12}] $stray] {1 {}}
    # every key emits a token the engine really lexes: the pad's set must be a
    # subset of §3.2's operator tokens, which is what makes a key a shortcut
    # rather than a trap (§3.1: one unknown token returns -1 for the WHOLE
    # expression).
    set ops {+ - * / ** == != > < >= <= ?}
    set unlexable {}
    foreach tok $keys { if {$tok ni $ops} { lappend unlexable $tok } }
    check "W30 every key is one of §3.2's operator tokens" $unlexable {}
    set lbl {}
    for {set i 1} {$i <= 4} {incr i} { lappend lbl [wcg .calc.pad.u$i -text] }
    check "W31 user 1..4 labels" $lbl {{user 1} {user 2} {user 3} {user 4}}
    set dis {}
    foreach w [cwalk .calc.pad] {
        if {[winfo class $w] eq {Button} && [wcg $w -state] ne {normal}} { lappend dis $w }
    }
    check "W29 every key and user button is pressable (present-and-inert, not disabled)" \
        [list [llength [cwalk .calc.pad]] $dis] [list 17 {}]
}

# =============================================================================
# CW10 — W32-W34 and R507/R508/R509, the status contract
# =============================================================================
group CW10 {
    pcall calc::status {}
    nsset statushist {}
    pcall .calc.status.hist configure -values {}

    check "R507 status returns the message it wrote" \
        [pcall calc::status {first line}] {first line}
    check "R507 ...and the field shows it" [pcall .calc.status.msg get] {first line}
    check "R507 ...and it was recorded" [pcall calc::status_history] {{first line}}
    pcall calc::status {second line}
    check "R509 the history is NEWEST FIRST" [lindex [pcall calc::status_history] 0] \
        {second line}
    check "W34 the dropdown reveals the history" [wcg .calc.status.hist -values] \
        {{second line} {first line}}
    pcall calc::status {second line}
    check "R509 consecutive duplicates are KEPT (two events happened)" \
        [llength [pcall calc::status_history]] 3

    # R509's cap.  60 in, 50 kept, the OLDEST dropped.
    nsset statushist {}
    for {set i 1} {$i <= 60} {incr i} { pcall calc::status "msg $i" }
    set h [pcall calc::status_history]
    check "R509 the history CAPS at 50" [llength $h] 50
    check "R509 the newest is kept" [lindex $h 0] {msg 60}
    check "R509 the oldest is what dropped" [lindex $h end] {msg 11}
    check "W34 the dropdown is capped too" [llength [wcg .calc.status.hist -values]] 50

    # R507 — the empty string CLEARS and records nothing
    # (the history is the capped 50 by now — see the cap block above)
    check "R507 the empty string returns nothing" [pcall calc::status {}] {}
    check "R507 ...clears the field" [pcall .calc.status.msg get] {}
    # ⚠ the number is the CAP, spelled out: comparing "after" to a "before"
    # taken in the same run is green when both are the same wrong thing.
    # ⚠ the LENGTH alone cannot see this: at the cap, prepending one more entry
    # still leaves 50.  The newest entry is the oracle.
    check "R507 ...and records nothing (still 50, and the newest is untouched)" \
        [list [llength [pcall calc::status_history]] \
              [lindex [pcall calc::status_history] 0]] {50 {msg 60}}

    # R507's `record 0` — the one caller is R413's hover help
    # (still 50)
    check "R507 record 0 still shows the line" [pcall calc::status {shown only} 0] \
        {shown only}
    check "R507 ...and really did not record it (still 50, newest untouched)" \
        [list [llength [pcall calc::status_history]] \
              [lindex [pcall calc::status_history] 0]] {50 {msg 60}}

    # R509 — recall re-displays without re-recording
    pcall .calc.status.hist set {msg 42}
    pcall calc::status_recall
    check "R509 recall re-displays the chosen line" [pcall .calc.status.msg get] {msg 42}
    check "R509 ...without re-recording it" \
        [list [llength [pcall calc::status_history]] \
              [lindex [pcall calc::status_history] 0]] {50 {msg 60}}
    check "W34 ...and the two-character button is emptied again" \
        [pcall .calc.status.hist get] {}
    nsset statushist {}
    pcall .calc.status.hist configure -values {}
    pcall calc::status {}
}

# =============================================================================
# CW11 — R110 / R111 / R112 / R112a, as far as a headless run can honestly go
# =============================================================================
group CW11 {
    # R110 — collapse from the View menu is plan 10.1.  What phase 1 owes is the
    # INERT control, and it has it: the View cascade exists with a disabled
    # placeholder (CW4 pins that).  The one collapse that IS implemented is the
    # Results Dir row's own toggle (W03), so that is what is asserted here.
    check "R110 the View cascade exists (its entries are phase 10's)" \
        [winfo exists .calc.mbar.view] 1
    set before [pslaves .calc.res]
    pcall calc::res_toggle
    check "R110/W03 collapsing hides every slave but the toggle" \
        [pslaves .calc.res] {.calc.res.tog}
    check "R110/W03 ...and the toggle relabels so it can be re-opened" \
        [wcg .calc.res.tog -text] {>}
    pcall calc::res_toggle
    check "R110/W03 expanding restores the row exactly" \
        [list [expr {[llength $before] > 1}] [pslaves .calc.res]] \
        [list 1 $before]
    check "R110/W03 ...and the label goes back" [wcg .calc.res.tog -text] {v}

    # R111 — the growth rules, read off the panes.  ⚠ AMENDED by this item: the
    # spec's list named widgets and was written before the pane tree existed; it
    # omitted the function browser, which .calc.pw.bot -stretch always is what
    # feeds.  See the receipt and spec §4.1 R111.
    check "R111 the selector pane never takes vertical growth" \
        [pcall .calc.pw panecget .calc.pw.sel -stretch] never
    check "R111 the buffer pane does" \
        [pcall .calc.pw panecget .calc.pw.buf -stretch] always
    check "R111 the Stack pane does" \
        [pcall .calc.pw panecget .calc.pw.stk -stretch] always
    check "R111 the bottom pane does, which is what feeds the browser (R112)" \
        [pcall .calc.pw panecget .calc.pw.bot -stretch] always
    check "R111 the function browser takes the bottom pane's width" \
        [pcall .calc.pw.bot panecget .calc.pw.bot.fn -stretch] always
    check "R111 the keypad keeps its natural width" \
        [pcall .calc.pw.bot panecget .calc.pw.bot.pad -stretch] never
    # ⚠ AND ITS HEIGHT IS NOT PINNED — the amendment's second half, added by the
    # fixer round because R111's sentence ("the keypad … keeps natural height")
    # had no oracle at all and the build does not do it.  Measured: at first open
    # `.calc.pad` is 198 px tall against a reqheight of 115, and at 900x1000 it
    # is 345 px, because `.calc.pw.bot -stretch always` (the clause that feeds
    # the browser, R112) grows the WHOLE bottom pane and `.calc.pad` is packed
    # `-expand 1 -fill both` inside its half.  What IS pinned is the keypad's
    # WIDTH (the leg above) and the KEYS' own natural height; the dead space
    # under the keys is item 4's open look debt, not a rule this file may fix.
    set _geo [pcall wm geometry .calc]
    set _padh0 [wh .calc.pad]
    set _kh0   [wh .calc.pad.k1]
    set _both0 [wh .calc.pw.bot]
    pcall wm geometry .calc 900x1000
    for {set _i 0} {$_i < 60} {incr _i} {
        update idletasks
        if {[wh .calc.pad] > $_padh0} break
        after 25 ; update
    }
    check_expr "R111 the keypad's FRAME grows with the bottom pane (amended: only its width is pinned)" \
        {[wh .calc.pad] > $_padh0 && [wh .calc.pad] > [wrh .calc.pad] && $_padh0 > 0}
    check_expr "R111 ...while the KEYS keep their natural height" \
        {[wh .calc.pad.k1] == [wrh .calc.pad.k1] && [wh .calc.pad.k1] == $_kh0 && $_kh0 > 0}
    check_expr "R111 fixture: the window really grew (or the two legs above are vacuous)" \
        {[wh .calc.pw.bot] > $_both0 && [ww .calc.pad] == [wrw .calc.pad] && $_both0 > 0}
    pcall wm geometry .calc $_geo
    for {set _i 0} {$_i < 60} {incr _i} {
        update idletasks
        if {[wh .calc.pad] == $_padh0} break
        after 25 ; update
    }
    check "R111 ...and the window went back to the size the rest of this file measures" \
        [list [wh .calc.pad] [expr {$_padh0 > 0}]] [list $_padh0 1]
    check "R111 the status bar is not a pane at all" \
        [pcall winfo manager .calc.status] pack
    check "R111 ...it is packed in the toplevel, so a sash cannot move it" \
        [lsearch -exact [pcall pack slaves .calc] .calc.status] 0

    # R112 — "minimum size must keep every control reachable", made mechanical
    # (spec §4.2 rule 1): the width is DERIVED from the selector pane's request,
    # never a constant.  test_calc_skeleton S21 owns the pixel proof; this pins
    # the derivation, which is the part a later widget silently breaks.
    update idletasks
    set mn [pcall wm minsize .calc]
    check_expr "R112 the declared minimum width covers the selector grid" \
        {[lindex $mn 0] >= [winfo reqwidth .calc.pw.sel]}
    check_expr "R112 ...and is not below the floor either" \
        {[lindex $mn 0] >= [lindex [calc::min_floor] 0]
         && [lindex $mn 1] >= [lindex [calc::min_floor] 1]}
    check_expr "R112 the browser is what SCROLLS: both its scrollbars are real" \
        {[llength [pcall .calc.fn.list xview]] == 2
         && [llength [pcall .calc.fn.list yview]] == 2}
    check_expr "R112 ...and its content really overflows, so they are not decoration" \
        {[lindex [pcall .calc.fn.list xview] 1] < 1.0}

    # R112a — every scrollable region scrolls under the POINTER.  The depth is
    # test_calc_skeleton S25's; what belongs in an inventory is that each
    # region's holder and a non-target child carry the binding at all.
    set unbound {}
    foreach w {.calc.pw.bot.fn .calc.fn.vsb .calc.fn.hsb
               .calc.pw.stk .calc.stk.push
               .calc.pw.buf .calc.btb .calc.btb.enter} {
        if {![string match {*calc::wheel_scroll*} [pcall bind $w <Button-4>]]} {
            lappend unbound $w
        }
    }
    check "R112a all three regions are wheel-bound, holders and children alike" \
        $unbound {}
    set nobreak {}
    foreach w {.calc.fn.vsb .calc.stk.push .calc.btb.enter} {
        if {![string match {*break*} [pcall bind $w <Button-4>]]} { lappend nobreak $w }
    }
    check "R112a every binding breaks, or a class binding scrolls it twice" $nobreak {}
    check "R112a a ttk::combobox keeps its own wheel (it steps the VALUE)" \
        [pcall bind .calc.fn.cat <Button-4>] {}
}

# =============================================================================
# CW12 — R113 / R113a.  ONE ACCESSOR, and the widgets were configured FROM it.
# =============================================================================
# ⚠ WHY THIS IS A SHIM AND NOT A COMPARISON.  A check that reads
# `.calc.sel cget -background` and compares it to `ase::palette panel` is green
# for a hardcoded `#f2f2f2` too — it compares two literals that happen to agree,
# which is vacuous evidence for R113 ("colours come from the signal browser's
# palette, THROUGH ONE ACCESSOR").  Changing what the source returns and
# watching the widget move is the only assertion that separates "reads the
# palette" from "was painted the same colour once".
#
# ⚠ AND WHY THE COMPARISON IS A WALK, NOT A TABLE.  The first draft named 22
# widgets and one colour option each.  Measured on the shipped build: the window
# carries 91 widgets and 580 colour options, of which 326 are palette-fed — so a
# 22-row table left 73 widgets and every `-active*`/`-highlight*`/`-disabled*`/
# `-select*`/`-insert*` option outside the proof, and a widget divorced from the
# accessor kept the file green.  `cw_census` walks the live window instead:
# every widget × every option whose NAME ends in background/foreground/colour,
# whatever they turn out to be.  (The named table below is kept as well: it
# names paths in its failure message, and it reaches `.calc.mbar`, a Menu, which
# `cwalk` deliberately skips.)
proc cw_census {} {
    set out {}
    foreach w [cwalk .calc] {
        if {[catch {$w configure} specs]} continue
        foreach spec $specs {
            if {[llength $spec] != 5} continue
            set opt [lindex $spec 0]
            if {![regexp -nocase {(background|foreground|colou?r)$} $opt]} continue
            dict set out "$w $opt" [lindex $spec 4]
        }
    }
    return $out
}
group CW12 {
    check "R113 calc::color is the accessor, and it resolves every role" \
        [lsort [dict keys [pcall calc::palette]]] [lsort [pcall calc::color_roles]]
    set roles [pcall calc::color_roles]
    if {[string match {ERR:*} $roles]} { set roles {} }
    set empty {}
    foreach role $roles {
        if {[pcall calc::color $role] eq {}} { lappend empty $role }
    }
    # the role COUNT rides along: an accessor that does not exist yields an
    # ERR: string whose words all "resolve" to another ERR: string, which is
    # non-empty, so the offender list alone would be green.
    check "R113 no role resolves to the empty string" \
        [list [expr {[llength $roles] >= 9}] $empty] {1 {}}
    # ...and the throw is only evidence next to a role that does NOT throw.
    check "R113 an unknown role THROWS — there are no fallback defaults" \
        [list [string match {ERR:*} [pcall calc::color panel]] \
              [string match {ERR:*} [pcall calc::color no_such_role]]] {0 1}

    # R113, the source-level half: no literal colour is executable in the file.
    # ⚠ $XSCHEM_SHAREDIR is a Tcl GLOBAL the C core sets (xinit.c), not an
    # environment variable: `$::env(XSCHEM_SHAREDIR)` throws here.  It is where
    # xschem.tcl:14560 sourced calculator.tcl from, so it is the file that is
    # actually running, not whatever a relative path finds.
    set src {}
    if {[info exists ::XSCHEM_SHAREDIR]} {
        set src [file join $::XSCHEM_SHAREDIR calculator.tcl]
    }
    if {$src eq {} || ![file exists $src]} { set src src/calculator.tcl }
    check_expr "R113 fixture: the running calculator.tcl was located" \
        {[file exists $src]}
    # ⚠ ANCHORED ON THE OPTION-NAME SUFFIX, NOT ON A LIST OF OPTION NAMES.  The
    # first draft alternated `-(fg|bg|foreground|background|selectcolor|
    # troughcolor)` followed by one of four colour words, which requires a `-`
    # immediately before the option word and so could not see ANY of the
    # prefixed families — and the file carries 60 palette-fed colour options
    # under prefixed names (`-activebackground` x16, `-activeforeground` x13,
    # `-disabledforeground` x12, `-selectbackground` x4, `-selectforeground` x4,
    # `-highlightbackground` x3, `-readonlybackground` x2, `-fieldbackground` x2,
    # `-insertbackground` x1).  Measured on the shipped build: replacing all 16
    # `-activebackground [calc::color header]` with `-activebackground grey85`,
    # or `.calc.res.lab`'s pair with `-background red -foreground blue`, left the
    # old scan reporting NO offenders.  The rule now is a WHITELIST of value
    # forms instead of a blacklist of colour words: after any
    # `-<anything>(background|foreground|color|colour)` the value must be a
    # command substitution, a variable, a brace group or a quoted string —
    # anything else is a literal.  Two rules ride along: any executable
    # `#`-hex of any length, and any X11 colour WORD on a line that carries a
    # colour option (which is what catches `[list readonly white]` inside a
    # ttk state map, where the value token itself is a `[`).
    set cw_cnames {grey gray white black red green blue cyan magenta yellow
                   orange purple pink brown navy maroon olive teal silver gold
                   violet indigo beige ivory khaki salmon azure coral plum
                   orchid wheat snow linen bisque tomato thistle sienna
                   firebrick turquoise lavender aquamarine chartreuse}
    set cw_cre "(?:[join $cw_cnames |])\[0-9\]*"
    set lits {}
    set ln 0
    set f [open $src r] ; set body [read $f] ; close $f
    foreach line [split $body \n] {
        incr ln
        if {[regexp {^\s*#} $line]} continue
        set why {}
        if {[regexp -- {#[0-9a-fA-F]{3,}\M} $line]} { lappend why hex }
        set opts [regexp -all -inline -nocase -- \
            {-([a-z]*(?:background|foreground|colou?r))\s+(\S+)} $line]
        foreach {m opt val} $opts {
            if {[string index $val 0] in {[ $ \{ \"}} continue
            lappend why "-$opt=$val"
        }
        if {[llength $opts] && [regexp -nocase -- "\\m($cw_cre)\\M" $line -> w]} {
            lappend why "name:$w"
        }
        if {[llength $why]} { lappend lits "$ln:$why" }
    }
    check "R113 src/calculator.tcl writes no executable colour literal" $lits {}

    # ⚠ R113 says a role whose SOURCE does not resolve THROWS, and that there are
    # no fallback defaults — because a colour that silently defaults renders
    # plausibly, cannot be told from a deliberate one by any `cget`, and then
    # never tracks the palette again.  The only way to ask is to break a source.
    set _pbody0 [info body ase::palette]
    proc ase::palette {{name {}}} {
        set pal [dict create panel {} table #ffffff header #e8e8e8 accent #8b0000 \
                             fieldfg #000000 selectbg #4a6984 selectfg #ffffff \
                             disabledbg #d9d9d9 disabledfg #a3a3a3]
        if {$name ne {}} { return [dict get $pal $name] }
        return $pal
    }
    # (the palette is resolved WHOLESALE, so one dead source takes every role
    # down with it — which is the point: nothing is left plausibly painted.)
    set threw [string match {ERR:*} [pcall calc::color panel]]
    proc ase::palette {{name {}}} $_pbody0
    check "R113 a role whose SOURCE does not resolve throws, it does not default" \
        [list $threw [string match {ERR:*} [pcall calc::color panel]]] {1 0}

    # ...and now the load-bearing half.  Close, move the SOURCE the accessor
    # reads, rebuild, and look at the widgets.
    set real_panel  [pcall calc::color panel]
    set real_accent [pcall calc::color accent]
    set real_field  [pcall calc::color field]
    # the BASELINE walk, taken while the real palette is still in force: every
    # widget the window has × every colour option that widget really has.  See
    # `cw_census` and the walk check below for why this is not a hand table.
    set cw_realpal [pcall calc::palette]
    set cw_base [cw_census]
    pcall calc::close
    set _pbody [info body ase::palette]
    # ⚠ EVERY role the calculator sources from the browser moves, `selectbg` and
    # `selectfg` included — a role the shim leaves alone is a role the walk
    # below cannot decide, and those two paint the buffer's and both entries'
    # selection.  `disabledbg`/`disabledfg` are deliberately left: R113 sources
    # `disabledfg` from the option database, and the check below asserts it did
    # NOT move with the palette.
    proc ase::palette {{name {}}} {
        set pal [dict create panel #123456 table #654321 header #445566 \
                             accent #abcdef fieldfg #0f0f0f \
                             selectbg #778899 selectfg #99aabb \
                             disabledbg #d9d9d9 disabledfg #a3a3a3]
        if {$name ne {}} { return [dict get $pal $name] }
        return $pal
    }
    check "R113 fixture: the accessor now answers with the shimmed value" \
        [pcall calc::color panel] {#123456}
    check_expr "R113 fixture: the real palette is a colour, and not the shim's" \
        {[regexp -- {^#[0-9a-fA-F]{6}$} $real_panel]
         && [regexp -- {^#[0-9a-fA-F]{6}$} $real_accent]
         && $real_panel ne {#123456} && $real_accent ne {#abcdef}}
    # ⚠ EVERYTHING FROM HERE TO THE RESTORE RUNS UNDER A CATCH.  A throw between
    # installing the shim and putting it back would leave `ase::palette` lying
    # for the rest of the process, and CW13 would then measure a window painted
    # from a fixture.  The restore below is unconditional; the catch is reported
    # as a failure of its own rather than as a check, so the count cannot move.
    set _rc [catch {
    pcall calc::open
    update idletasks
    set wrong {}
    foreach {path opt want} {
        .calc              -background #123456
        .calc.sel          -background #123456
        .calc.mode         -background #123456
        .calc.status       -background #123456
        .calc.res          -background #123456
        .calc.btb          -background #123456
        .calc.pw           -background #123456
        .calc.mbar         -background #123456
        .calc.pw.sel       -background #123456
        .calc.stk          -background #123456
        .calc.pad          -background #123456
        .calc.fn           -background #123456
        .calc.buf          -background #654321
        .calc.stk.list     -background #654321
        .calc.fn.list      -background #654321
        .calc.status.msg   -readonlybackground #654321
        .calc.res.path     -readonlybackground #654321
        .calc.stk          -foreground #abcdef
        .calc.pw.sel       -foreground #abcdef
        .calc.res.tog      -foreground #abcdef
        .calc.buf          -foreground #0f0f0f
        .calc.sel.vt       -foreground #0f0f0f
    } {
        set got [wcg $path $opt]
        if {$got ne $want} { lappend wrong "$path $opt=$got want $want" }
    }
    check "R113 every NAMED widget followed the accessor to the shimmed value" $wrong {}

    # --- THE WALK.  Every widget, every colour option, no hand table. --------
    # A pair is IN SCOPE when its baseline value was a value the shim moved; it
    # then has to arrive at one of the shimmed values that role could produce.
    # (A SET, not a value: two roles can share one real colour — `field` and
    # `selectfg` are both #ffffff on the shipped palette — so demanding a single
    # target would fail on a correct build.)  A pair painted with a hardcoded
    # literal EQUAL to the palette's own colour, which is the regression R113
    # exists for because it is invisible to the eye and to any `cget`, stays put
    # and lands in `stuck`.  A hardcoded literal that is NOT a palette colour
    # leaves this scope entirely and is caught by the source scan above instead.
    set cw_shimpal [pcall calc::palette]
    set cw_shim [cw_census]
    set movemap {}
    foreach {role real} $cw_realpal {
        set now [dict get $cw_shimpal $role]
        if {$now eq $real} continue
        dict lappend movemap $real $now
    }
    set stuck {} ; set gone {} ; set followed 0
    foreach {k v} $cw_base {
        if {![dict exists $movemap $v]} continue
        if {![dict exists $cw_shim $k]} { lappend gone $k ; continue }
        set now [dict get $cw_shim $k]
        if {[lsearch -exact [dict get $movemap $v] $now] < 0} {
            lappend stuck "$k was $v now $now"
        } else { incr followed }
    }
    check "R113 every colour option of EVERY widget followed the accessor (live walk)" \
        [list $stuck $gone] {{} {}}
    # ...and the walk's own coverage, or an empty offender list is green on a
    # walk that visited nothing.  Measured on the shipped build: 91 widgets, 580
    # colour options, 326 of them palette-fed.  These are FLOORS against
    # vacuity, not a pinned count — the detector is the `stuck` list above.  A
    # later phase that legitimately removes controls lowers them and says why.
    check_expr "R113 fixture: the walk really covered the window (91 widgets / 326 palette-fed options here)" \
        {[llength [cwalk .calc]] >= 85 && [dict size $cw_base] >= 550 && $followed >= 320}
    check_expr "R113 ...including the ones a `cget` on a live window would hide" \
        {[wcg .calc.sel.vt -selectcolor] eq {#654321}
         && [wcg .calc.fn.vsb -troughcolor] eq {#445566}}
    # R113a — a readonly combobox is painted by the style's STATE MAP, not by
    # `ttk::style configure`; the check that covers it reads the MAP.
    check "R113a the readonly field colour is MAPPED, and follows the accessor" \
        [pcall ttk::style map Calc.Field.TCombobox -fieldbackground] \
        {readonly #654321}
    check "R113a ...for the status history's style too" \
        [pcall ttk::style map Calc.TCombobox -fieldbackground] {readonly #654321}
    check "R113a ...and the foreground is mapped with it (a bg with no fg is a bug)" \
        [pcall ttk::style map Calc.Field.TCombobox -foreground] {readonly #0f0f0f}
    # the disabledfg role is deliberately NOT a browser colour (spec R113): it is
    # xschem's own option database.  The shim moved every ase::palette role, so a
    # widget wearing the shimmed disabled colour would mean the mapping moved.
    check "R113 disabledfg still comes from the option database, not the palette" \
        [pcall calc::color disabledfg] \
        [pcall option get . disabledForeground DisabledForeground]
    } _shimerr]

    # restore — unconditional — and prove the restore took
    pcall calc::close
    proc ase::palette {{name {}}} $_pbody
    if {$_rc} {
        puts "FAIL: CW12 the shimmed block aborted -> $_shimerr : FAIL"
        incr ::fail
    }
    pcall calc::open
    update idletasks
    check "R113 the shim is gone and the palette is the browser's again" \
        [list [pcall calc::color panel] [pcall calc::color accent] \
              [pcall calc::color field] [pcall ase::palette panel]] \
        [list $real_panel $real_accent $real_field $real_panel]
    check "R113 ...and the widgets came back with it" \
        [list [wcg .calc.sel -background] [wcg .calc.stk -foreground] \
              [wcg .calc.buf -background]] \
        [list $real_panel $real_accent $real_field]
    check "R113a ...and so did the style map" \
        [pcall ttk::style map Calc.Field.TCombobox -fieldbackground] \
        [list readonly $real_field]
}

# =============================================================================
# CW13 — PHASE-1 INERTNESS.  Every enabled control is provably inert.
# =============================================================================
# The plan's rule for phase 1: "every real control exists in its box, correct
# class and initial state, COMPLETELY INERT".  The trap this group exists for is
# the opposite one — wiring a behaviour a later phase owns so that a check goes
# green.  So: what a control's -command IS, what pressing it does to the two
# things the tool owns (the buffer and the Stack), and that it SPEAKS (R506:
# silence is a bug).
group CW13 {
    set ctrls {}
    foreach w [cwalk .calc] {
        if {[winfo class $w] in {Button Radiobutton Checkbutton}} { lappend ctrls $w }
    }
    check_expr "CW13 fixture: the sweep really found the window's controls" \
        {[llength $ctrls] >= 40}
    # (a) every -command routes through the phase-1 stubs.  calc::inert is the
    #     one that names the owning phase; sel_click/pad_click/dest_changed
    #     compose a message and hand it to inert; res_toggle is LAYOUT, which
    #     phase 1 does own; status is R202's refusal path.
    #
    # ⚠ RESTATED, results batch item 10: TWO MORE ENTRIES, and neither is a
    # phase leaking in early.  `calc::eval_click` (W12) resolves the session's
    # result and either refuses in U7's ruled words or FALLS THROUGH TO
    # `calc::inert` — the phase-3 stub is still what a press with a result
    # reaches, which is why part (b) below still finds it inert.
    # `calc::browse_inert` (Browse) replaced `{calc::status {Browse: not
    # implemented}}`: U9 ruled that control permanently inert rather than
    # unfinished, and "not implemented" is a promise that may only be made
    # where a phase really is coming.  Both were pinned by name here, so the
    # list is the honest place to record the change rather than a hole to widen.
    set allowed {calc::inert calc::status calc::sel_click calc::sel_refuse
                 calc::pad_click calc::dest_changed calc::res_toggle
                 calc::eval_click calc::browse_inert}
    set rogue {} ; set mute {}
    foreach w $ctrls {
        set cmd [wcg $w -command]
        if {$cmd eq {}} {
            if {[wcg $w -state] ne {disabled}} { lappend mute $w }
            continue
        }
        if {[lindex $cmd 0] ni $allowed} { lappend rogue "$w -> [lindex $cmd 0]" }
    }
    # ⚠ every one of these four rides on the CONTROL COUNT.  An offender list
    # over an empty sweep is empty, so without it "nothing is wired to a later
    # phase" is green on a window with no controls at all.
    check "CW13 no control is wired to anything but a phase-1 stub" \
        [list [expr {[llength $ctrls] >= 40}] $rogue] {1 {}}
    check "CW13 no ENABLED control is silent (R506)" \
        [list [expr {[llength $ctrls] >= 40}] $mute] {1 {}}

    # (b) pressing every enabled control changes neither the buffer nor the Stack
    pcall .calc.buf delete 1.0 end
    pcall .calc.buf insert end {SENTINEL}
    check "CW13 fixture: the pre-press snapshot is real text" \
        [pcall .calc.buf get 1.0 end-1c] {SENTINEL}
    set stk0 [pcall .calc.stk.list size]
    set touched {} ; set silent {} ; set npressed 0
    foreach w $ctrls {
        if {[wcg $w -state] eq {disabled}} continue
        incr npressed
        pcall calc::status {}
        pcall $w invoke
        if {[pcall .calc.buf get 1.0 end-1c] ne {SENTINEL}} { lappend touched "buf:$w" }
        if {[pcall .calc.stk.list size] != $stk0} { lappend touched "stk:$w" }
        if {[nsv statusmsg] eq {}} { lappend silent $w }
    }
    check "CW13 no control touched the buffer or the Stack" \
        [list [expr {$npressed >= 40}] $touched] {1 {}}
    check "CW13 every one of them wrote a status line" \
        [list [expr {$npressed >= 40}] $silent] {1 {}}
    # the Results Dir toggle was pressed once by the sweep, so put it back
    if {[nsv rescollapsed] eq {1}} { pcall calc::res_toggle }
    check "CW13 the sweep left the Results Dir row expanded again" \
        [nsv rescollapsed] 0
    pcall .calc.buf delete 1.0 end

    # (c) the two disabled toolbar buttons stay disabled: R505 makes undo/redo
    #     cover buffer AND stack as one history, which is phases 2 and 4.
    check "W22 undo/redo are still disabled after the sweep" \
        [list [wcg .calc.btb.undo -state] [wcg .calc.btb.redo -state]] \
        {disabled disabled}
    # (d) and the canvas entries, which are items rather than widgets
    pcall .calc.buf insert end {SENTINEL}
    set stk0 [pcall .calc.stk.list size]
    pcall calc::fn_click average
    pcall calc::pad_click +
    check "CW13 a live function entry and an operator key are inert too" \
        [list [pcall .calc.buf get 1.0 end-1c] [pcall .calc.stk.list size]] \
        [list {SENTINEL} $stk0]
    check_expr "CW13 ...and both name the phase that owns them" \
        {[string match {*not implemented (phase 2)*} [nsv statusmsg]]}
    pcall .calc.buf delete 1.0 end
    pcall calc::status {}
}

# teardown: the window must not outlive the suite
calc::close
check "CW13 calc::close tore the window down" [winfo exists .calc] 0

} bigerr]} { puts "UNEXPECTED ERROR: $bigerr"; puts $::errorInfo; incr fail }

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } \
else            { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
