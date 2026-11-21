# tests/headless/test_calc_selector_names.tcl — the Calculator's NET PICK, every
# part of it that answers on the COUNTED arm.
#
# The gesture itself (a real press on a seized canvas, the prompt on the design
# window's status slot, undo granularity, Escape arriving) is display-only and
# lives in tests/headless/test_calc_pick.tcl, a `dcases` entry.  What is here is
# everything the stage-J1 lesson says belongs here: the DECISION, factored into
# pure procs so it gates where the gate actually counts, while the ACT is fenced
# where only a display can see it.
#
# ⚠ THE BANNER NAMES NO COUNT AND NO PROC LIST.  Band PK1 derives the id set from
# the grid's own table and PK6 derives the sentence set from the builder's own
# `switch`, so a fifth id or a nineteenth sentence enlists itself instead of
# needing this sentence edited.
#
# Spec     doc/claude/specs/calculator.md §5 (the selector table), §5.1
#          (R201-R208), §6 (R301-R307), §3.1 (the lexer that forces the space)
# Issues   0161 and 0168 (hierarchical names and the SESSION's own base level),
#          0173 (the viewer context loan), 0204 (a probe selects nothing),
#          1303 (the un-snapped pair), 1304 (the fourth seized sequence),
#          1305 (a permanently seized canvas), 1308 (suspended counts as
#          running), 1646 (pin a signature with `info args`, never a text scan)
# Fixture  tests/headless/data/calc_fixture.raw, read as BOTH `tran` and `ac`
#          because `vf` is an AC selector and the inventory read-back had to be
#          shown sound on four-column AC names too.
#
# Standalone from the repo ROOT, headless.  NOT a bare `./src/xschem`, which
# inherits $DISPLAY and paints on the user's real screen:
#   env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script \
#       tests/headless/test_calc_selector_names.tcl
# or, gated and with a throwaway HOME, which is the armed spelling:
#   tests/headless/run_suites.sh --nogui test_calc_selector_names

source [file join [file dirname [info script]] scratch.tcl]

set PKSELF [file normalize [info script]]

set fail 0; set npass 0
proc check {name got exp} {
    global fail npass
    if {$got eq $exp} { puts "ok:   $name"; incr npass } \
    else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
# Any command, with a raise turned into a legible `ERR:` sentinel so the ROW
# fails instead of the band dying -- and the sentinel is made LIST-PARSEABLE,
# which is not cosmetic: Tcl's list parser raises on an unmatched `{` or `"` that
# begins a word, a product raise message carries either, and every site that then
# handed the sentinel to `foreach`/`lindex` turned one product raise into a single
# `group ... ABORTED` line that DELETED the band's remaining rows from the
# verdict.  `test_calc_measure.tcl`'s own `pcall`, for its own reasons.
proc pcall {args} {
    if {[catch {uplevel 1 $args} r]} { return "ERR:[pcall_listable $r]" }
    return $r
}
proc pcall_listable {s} {
    if {![catch {llength $s}]} { return $s }
    set m [string map [list \{ ( \} ) \" '] $s]
    if {![catch {llength $m}]} { return $m }
    return [regsub -all {[^A-Za-z0-9 ._:,/()=+*<>?!-]} $s ?]
}
# A band that ABORTS deletes its remaining rows from the verdict, which is
# strictly worse than failing one: the rows vanish and only the check total comes
# in short, which nothing compares against anything.  So the name is RECORDED and
# asserted empty at the foot of this file.
set ::abortnames {}
proc group {name script} {
    if {[catch {uplevel 1 $script} e]} {
        puts "FAIL: group $name ABORTED -> $e : FAIL"
        puts $::errorInfo
        lappend ::abortnames $name
        incr ::fail
    }
}
# ⚠ THE LINE ENDS IN `: FAIL` SO A READER COUNTS IT.  A bare `BGERROR:` line is
# invisible to both readers (run_suites.sh echoes `^(FAIL|FATAL)`, summarize_all
# counts lines ENDING in FAIL) and with no handler at all the error would never
# touch $fail, so the suite would print `OVERALL: ok` over a real failure.
proc ::bgerror {msg} { puts "BGERROR: $msg : FAIL"; incr ::fail }

# ---------------------------------------------------------------------------
# HELPERS, every population DERIVED.

# the pick-capable ids, re-derived from the grid's own table RATHER THAN read
# from calc::pick_ids -- that is the whole point of PK1's comparison.
proc pk_rows {} { return [pcall calc::sel_rows] }
# R208e (2026-10-12): the pick serves the FIRST GROUP OF BOTH ROWS -- spec 5's
# voltage group on row 0 and its current group on row 1.
proc pk_derived_ids {} {
    set r [pk_rows]
    if {[string match ERR:* $r]} { return $r }
    return [concat [lindex [lindex $r 0] 0] [lindex [lindex $r 1] 0]]
}
proc pk_derived_vids {} { return [lindex [lindex [pk_rows] 0] 0] }
proc pk_derived_iids {} { return [lindex [lindex [pk_rows] 1] 0] }
# every id in the grid, in table order
proc pk_all_ids {} {
    set out {}
    foreach rowgroups [pk_rows] {
        foreach group $rowgroups { foreach id $group { lappend out $id } }
    }
    return $out
}
proc pk_disabled_ids {} {
    set d [pcall calc::sel_disabled]
    if {[string match ERR:* $d]} { return $d }
    return [dict keys $d]
}
# a builder's arms, DERIVED from its own `switch` patterns, exactly as
# `mt_sl_arms` in test_calc_measure.tcl does it and for the same reason: a
# comment landing between two patterns balances the braces, satisfies
# `info complete`, and raises out of EVERY arm -- so the only confirmation is
# behavioural, with the arm set taken from the proc itself.
proc pk_arms {nm} {
    if {[info procs ::calc::$nm] eq {}} { return "NOPROC:calc::$nm" }
    set out {}
    foreach ln [split [info body ::calc::$nm] "\n"] {
        if {[regexp {^[ \t]*([a-zA-Z_][a-zA-Z0-9_]*)[ \t]+\{[ \t]*return} $ln -> k]} {
            lappend out $k
        }
    }
    return $out
}
proc pk_in {l nm} { return [expr {[lsearch -exact $l $nm] >= 0 ? {has} : "missing:$nm"}] }
proc pk_sized {got want} { return [expr {$got == $want ? "n$want" : "n$got"}] }
proc pk_atleast {v n} { return [expr {$v >= $n ? "atleast$n" : "only:$v"}] }
proc pk_word {v yes no} { return [expr {$v ? $yes : $no}] }
# the committed fixture, located rather than assumed
proc pk_fixture {} {
    foreach cand [list \
        [file join [file dirname [info script]] data calc_fixture.raw] \
        [file join [file dirname $::XSCHEM_SHAREDIR] tests headless data calc_fixture.raw]] {
        if {[file exists $cand]} { return [file normalize $cand] }
    }
    return {}
}
proc pk_read {type} {
    set f [pk_fixture]
    if {$f eq {}} { return {NOFIXTURE} }
    pcall xschem raw clear
    return [pcall xschem raw read $f $type]
}
# the raw's own inventory, as a list, the way calc::pick_lookup reads it
proc pk_inventory {} {
    set l [pcall xschem raw list]
    if {[string match ERR:* $l]} { return $l }
    return [split [string trim $l] "\n"]
}
# a dict answer's field, with a sentinel rather than a raise when the shape is
# wrong -- so a row FAILS naming the shape instead of taking the band out.
proc pk_fld {d k} {
    if {[string match ERR:* $d]} { return $d }
    if {[catch {dict get $d $k} v]} { return "NOKEY:$k" }
    return $v
}
# the uncommented text of this suite's subject, for the scans that must not read
# their own warning as the defect (issue 1646's shape).
proc pk_decomment {body} {
    set out {}
    foreach ln [split $body "\n"] {
        if {[regexp {^[ \t]*#} $ln]} continue
        lappend out $ln
    }
    return [join $out "\n"]
}
# every <Sequence> literal a proc's uncommented body names
proc pk_seqs {nm} {
    if {[info procs ::$nm] eq {}} { return "NOPROC:$nm" }
    set out {}
    foreach m [regexp -all -inline {<[A-Za-z0-9-]+>} [pk_decomment [info body ::$nm]]] {
        lappend out $m
    }
    return [lsort -unique $out]
}
# the first differing key between two snapshots, so a failure NAMES what moved
# instead of printing two long lists for a reader to diff by eye.
proc pk_nsdiff {a b} {
    foreach {k v} $a {
        set w {}
        if {[dict exists $b $k]} { set w [dict get $b $k] }
        if {$v ne $w} { return "$k {$v} -> {$w}" }
    }
    foreach {k v} $b { if {![dict exists $a $k]} { return "NEW $k {$v}" } }
    return {}
}
# a whole-namespace snapshot of ::calc, so a no-window row can assert that
# NOTHING was written rather than that one named thing was not.
proc pk_nssnap {} {
    set out {}
    foreach v [lsort [info vars ::calc::*]] {
        if {[array exists $v]} {
            set pairs {}
            foreach k [lsort [array names $v]] { lappend pairs $k [set ${v}($k)] }
            lappend out $v "ARRAY:$pairs"
        } elseif {[info exists $v]} {
            lappend out $v [set $v]
        } else {
            lappend out $v {(undefined)}
        }
    }
    return $out
}

# ===========================================================================
# PK1 — THE SCOPE BOUNDARY, DERIVED
# ===========================================================================
# The four voltage ids are the whole of v1 (R208), and the claim that matters is
# that there is only ONE place the scope is written down.  So the row RE-DERIVES
# the set from `calc::sel_rows` and compares, rather than reading `calc::pick_ids`
# and agreeing with itself -- a second id table is the defect this forecloses.
group PK1 {
    set ids   [pcall calc::pick_ids]
    set der   [pk_derived_ids]
    set all   [pk_all_ids]
    set dis   [pk_disabled_ids]
    set enab  {}
    foreach id $all { if {[lsearch -exact $dis $id] < 0} { lappend enab $id } }
    set others {}
    foreach id $enab { if {[lsearch -exact $ids $id] < 0} { lappend others $id } }
    check "PK1 `calc::pick_ids` is DERIVED from the selector grid's own table and not a second list: it equals the first group of BOTH rows of `calc::sel_rows` element for element -- spec §5's VOLTAGE group and, since R208e, its CURRENT group -- the groups, and not the `Emits into buffer` column, which is what made the voltage four look alike and is the defect R208a corrects" \
        [list $ids $der [expr {$ids eq $der ? {same} : {DIFFERENT}}]] \
        [list {vt vf vdc vs it if idc is} {vt vf vdc vs it if idc is} same]
    check "PK1 the grid's population rides along, so a twenty-third selector or a ninth disabled one has to move a number here rather than quietly joining or leaving the pick's scope" \
        [list [pk_sized [llength $all] 22] [pk_sized [llength $ids] 8] \
              [pk_sized [llength $enab] 14] [pk_sized [llength $dis] 8] \
              [pk_sized [llength $others] 6]] \
        {n22 n8 n14 n8 n6}
    # R208e: WHAT a pick picks is the id's GROUP, read off the same table --
    # a net for the voltage group, a source instance for the current group.
    set kinds {}
    foreach id [concat $ids op data __pk_nosuch__] { lappend kinds [pcall calc::pick_kind $id] }
    check "PK1 R208e: `calc::pick_kind` answers `voltage` for row 0's first group, `current` for row 1's, and EMPTY for every other id -- derived from the same table, so a selector that moves group changes what its pick picks with no second edit" \
        [list [pk_derived_vids] [pk_derived_iids] $kinds] \
        [list {vt vf vdc vs} {it if idc is} \
              {voltage voltage voltage voltage current current current current {} {} {}}]
    # R208: the ten other ENABLED ids are not in scope and must say so, through
    # the same `calc::inert` route they used before this stage existed.
    set inert {}
    set armed {}
    foreach id $enab {
        set d [pcall calc::pick_decide $id [dict create ok 1 token __pk_nosuch__]]
        set act [pk_fld $d act]
        if {$act eq {inert}} { lappend inert $id } else { lappend armed $id }
    }
    check "PK1 R208's scope boundary is a ROUTING decision and is drivable here: every one of the six enabled ids outside the two pick groups answers `inert` -- which is what keeps their shipped `calc::inert ... phase 6` sentence -- and not one of the eight pick ids does" \
        [list [lsort $inert] [lsort $armed]] \
        [list [lsort $others] [lsort $ids]]
    # ⚠⚠ THIS ROW IS THE SUPERSESSION OF ITS OWN PREVIOUS SELF, AND THAT IS WHAT
    # ITS OLD WORDING ASKED FOR.  It used to assert *"there is NO analysis gate and
    # one cannot be added quietly"*, ending *"a gate added later must change a
    # signature or name one of these verbs, and either reddens this row"*.  A gate
    # was added later -- by the USER, on 2026-10-07: *"vt and vf both put
    # v(netname) in the calculator buffer. We need different functions because vt
    # and vf are different things."*  So the row reddened exactly as designed and
    # is RESTATED to assert the gate, never weakened to tolerate it.
    #
    # ⚠ THE HALF THAT DOES NOT CHANGE IS THE ONE THAT MATTERS: `calc::pick_name`
    # and `calc::pick_lookup` must STILL be unable to discriminate, because the
    # gate belongs where the id is already in hand.  A later hand "fixing" this by
    # threading an analysis through the name path moves these two signatures and
    # reddens here.
    set dbody [pk_decomment [pcall info body ::calc::pick_decide]]
    set nbody [pk_decomment [pcall info body ::calc::pick_name]]
    set lbody [pk_decomment [pcall info body ::calc::pick_lookup]]
    check "PK1 R208a: there IS an analysis gate and it lives where the id already is.  `calc::pick_decide` asks the loaded database's own analysis; `calc::pick_name` and `calc::pick_lookup` are told a TOKEN and a LEVEL and still CANNOT discriminate, which is what keeps the gate in one place -- a later hand threading an analysis through the name path moves these two signatures and reddens here" \
        [list [pcall info args ::calc::pick_name] [pcall info args ::calc::pick_lookup] \
              [pk_word [regexp {pick_analysis} $dbody] gates UNGATED] \
              [pk_word [regexp {pick_analysis|sim_type|analysis} $nbody] NAMEDISCRIMINATES silent] \
              [pk_word [regexp {pick_analysis|sim_type|analysis} $lbody] LOOKUPDISCRIMINATES silent]] \
        [list {tok baselvl} {cand} gates silent silent]
    # --- the gate itself, with synthetic dicts -------------------------------
    # ⚠ WHY THIS IS NOT A COSMETIC COMPLAINT, measured and carried as a row: the
    # ONE buffer text `v(lp)` resolves in all three databases and answers a
    # DIFFERENT NUMBER in each, and `calc::pick_lookup` approves it every time.
    # That is the wrong-number-with-no-way-to-tell the gate exists to stop.
    set pkvals {}
    foreach ty {tran ac op} {
        pk_read $ty
        set lk [pcall calc::pick_lookup v(lp)]
        # ⚠ THE *LAST* SAMPLE, NOT THE FIRST.  At t=0 a transient and an operating
        # point agree by construction, so the first sample gives only TWO distinct
        # values and the row read `n2` -- measuring a coincidence rather than the
        # divergence it is about.
        lappend pkvals $ty [pk_fld $lk ok] [lindex [pcall xschem raw values v(lp) 0] end]
    }
    pcall xschem raw clear
    check "PK1 R208a's PREMISE, re-measured every run: the same buffer text resolves in ALL THREE analyses -- `calc::pick_lookup` answers ok each time -- and reads a DIFFERENT number in each.  Without the gate nothing in the buffer, the status line or the refusal vocabulary could say which of these the user was looking at" \
        [list [lindex $pkvals 1] [lindex $pkvals 4] [lindex $pkvals 7] \
              [pk_sized [llength [lsort -unique [list [lindex $pkvals 2] [lindex $pkvals 5] [lindex $pkvals 8]]]] 3]] \
        {1 1 1 n3}
    check "PK1 the analysis table is ONE table keyed on the same eight ids as the pick's scope, and it is complete in both directions -- a ninth id with no analysis, or an analysis with no id, reddens here -- and the evaluator's token table IS that table, not a second copy of it (R208e)" \
        [list [pcall calc::pick_analyses] \
              [lsort [pcall dict keys [pcall calc::pick_analyses]]] [lsort $ids] \
              [pcall calc::pick_analysis op] [pcall calc::pick_analysis {}] \
              [expr {[pcall calc::aq_analyses] eq [pcall calc::pick_analyses] ? {same} : {DIFFERENT}}]] \
        [list {vt tran vf ac vdc op vs dc it tran if ac idc op is dc} \
              {idc if is it vdc vf vs vt} {idc if is it vdc vf vs vt} {} {} same]
    # ⚠ THE DESIGN RESOLUTION IS STUBBED, because it sits AFTER the gate and
    # refuses for its own reason -- so without it all eight drives answer `refuse`
    # and the row cannot tell a gate refusal from a missing cellview.  That is what
    # the first spelling of it did.  The stub supplies ASE's resolution; it does not
    # share the gate.
    rename ase::ui::design_path pk_real_dp
    proc ase::ui::design_path {key} { return /tmp/__pk_fake__/cell.sch }
    set pkgate {}
    foreach {id ty} {vt tran vt ac vf ac vf tran vdc op vdc tran vs dc vs ac
                     it tran it ac if ac if tran idc op idc tran is dc is ac} {
        lappend pkgate [pk_fld [pcall calc::pick_decide $id \
            [dict create ok 1 token k type $ty]] act]
    }
    rename ase::ui::design_path {}
    rename pk_real_dp ase::ui::design_path
    check "PK1 ...and the stub was handed back, which the band CHECKS rather than assumes" \
        [pcall ase::ui::design_path __pk_nosuch__] {}
    check "PK1 R208a drivable with no database at all: each of the eight pick ids ARMS on its own analysis and REFUSES on another -- eight matches and eight mismatches, the current ids gated exactly as the voltage ones (R208e), so the row cannot pass by refusing everything or by arming everything" \
        $pkgate {arm refuse arm refuse arm refuse arm refuse arm refuse arm refuse arm refuse arm refuse}
    check "PK1 ...and the refusal NAMES THE ANALYSIS THE RESULT LACKS, in the user's words rather than the simulator's -- acronyms uppercase, one map shared with the success sentence so they cannot disagree.  (R208c restated this sentence: it used to say `needs an AC result; this one is transient`, which stopped being the reason once a selector could read a sibling analysis of the same run)" \
        [list [pk_fld [pcall calc::pick_decide vf [dict create ok 1 token k type tran]] msg] \
              [pk_fld [pcall calc::pick_decide vdc [dict create ok 1 token k type ac]] msg] \
              [pcall calc::analysis_word tran] [pcall calc::analysis_word ac] \
              [pcall calc::analysis_word op] [pcall calc::analysis_word dc] \
              [pcall calc::analysis_word __pk_unknown__]] \
        [list {selector vf: this result has no AC analysis} \
              {selector vdc: this result has no operating point analysis} \
              transient AC {operating point} {DC sweep} __pk_unknown__]
    # --- R208c: the gate asks the RESULT'S FILE, not the current slot ----------
    # The user, 2026-10-11: *"A simulation could have both AC and TRAN
    # simulations. The vt or vf need to intelligently pick FROM the loaded
    # results."*  So a result whose CURRENT analysis is transient arms `vf` when
    # its raw file also holds an AC plot.  The SAME synthetic dict with the path
    # removed is the control: it refuses, so the arm is the file's answer and
    # not a constant.  `vs` is the negative on the real file -- the committed
    # fixture writes tran, AC and op and no DC sweep -- so the row cannot pass by
    # arming everything.
    rename ase::ui::design_path pk_real_dp3
    proc ase::ui::design_path {key} { return /tmp/__pk_fake__/cell.sch }
    set pkpres {}
    foreach id {vt vf vdc vs} {
        lappend pkpres [pk_fld [pcall calc::pick_decide $id \
            [dict create ok 1 token k type tran path [pk_fixture]]] act]
    }
    set pkctl [pk_fld [pcall calc::pick_decide vf [dict create ok 1 token k type tran path {}]] act]
    set pkvs [pk_fld [pcall calc::pick_decide vs \
        [dict create ok 1 token k type tran path [pk_fixture]]] msg]
    rename ase::ui::design_path {}
    rename pk_real_dp3 ase::ui::design_path
    check "PK1 R208c: against a TRANSIENT-current result whose raw file also holds AC and op plots, `vt`, `vf` and `vdc` all ARM and `vs` REFUSES naming the DC sweep the run never wrote; the same `vf` dict with no file refuses -- so presence is read from the file" \
        [list $pkpres $pkctl $pkvs [pcall calc::raw_analyses [pk_fixture]] [pcall calc::raw_analyses {}]] \
        [list {arm arm arm refuse} refuse {selector vs: this result has no DC sweep analysis} {tran ac op} {}]
    rename ase::ui::design_path pk_real_dp2
    proc ase::ui::design_path {key} { return /tmp/__pk_fake__/cell.sch }
    set pkunk [list [pk_fld [pcall calc::pick_decide vt [dict create ok 1 token k]] act] \
                    [pk_fld [pcall calc::pick_decide vt [dict create ok 1 token k type {}]] act]]
    rename ase::ui::design_path {}
    rename pk_real_dp2 ase::ui::design_path
    check "PK1 a result whose analysis is UNKNOWN is NOT refused: an empty or absent `type` arms, because refusing on a fact nobody established would be a restriction ADE-L does not have -- the one direction this project's rulings single out" \
        $pkunk {arm arm}
    check "PK1 the SUCCESS sentence names the analysis in the HEAD of the line, not the elided tail -- the user's whole complaint was that nothing said WHICH analysis produced a number, so a long path must not push it off" \
        [list [pcall calc::pick_fit vt v(lp) /lp tran] \
              [pcall calc::pick_fit vf v(lp) /lp ac] \
              [pcall calc::pick_fit vt v(lp) /lp]] \
        [list {selector vt: v(lp) (transient) from /lp} \
              {selector vf: v(lp) (AC) from /lp} \
              {selector vt: v(lp) from /lp}]
}

# ===========================================================================
# PK3 — THE CANDIDATE NAME, AND THE BUS REFUSAL
# ===========================================================================
# R207's "read them back, do not construct them": `calc::pick_name` delegates the
# hierarchical half to `xschem resolved_net` through `ase::ui::sod_qualify` and
# the wrap to `ase::ui::sod_expr`, so what is asserted here is the DELEGATION's
# observable answers plus the bus guard, which is the one refusal this proc owns.
group PK3 {
    check "PK3 `calc::pick_name`'s signature is pinned with `info args` AND `info default`, never a text scan: issue 1646 cost five rounds in which EVERY text-scanning leg was eventually evaded -- a comment copy, an unqualified callee, a backslash continuation -- and not one `info args` leg was defeated by any of 43 derived sabotages.  `info args` reports names only and cannot see a default, which is its own trap, so both are read" \
        [list [pcall info args ::calc::pick_name] \
              [pcall info args ::calc::pick_cadence] \
              [pcall info args ::calc::pick_lookup] \
              [pcall info args ::calc::pick_classify] \
              [pcall info args ::calc::pick_decide] \
              [pcall info args ::calc::pick_msg] \
              [pcall info default ::calc::pick_msg a __pk_d] \
              [pcall info default ::calc::pick_msg b __pk_d]] \
        [list {tok baselvl} {tok baselvl} {cand} {hit net at} {id g} {kind a b} 1 1]
    check "PK3 ...and `calc::pick_msg`'s two detail slots really DEFAULT TO EMPTY, which is the arity `mt_sl_sentences` in test_calc_measure.tcl calls every `calc::*_msg` with.  With any other arity that sweep's `pcall` turns each call into a short `ERR:` string, the width check passes on it, and band MT20/B goes GREEN while measuring nothing" \
        [list [pcall calc::pick_msg cancelled] [pcall calc::pick_msg cancelled vt]] \
        [list {selector : pick cancelled} {selector vt: pick cancelled}]
    # the engine's `#` strip and the CASE question, both measured
    set a  [pcall calc::pick_name A 0]
    set h  [pcall calc::pick_name #net1 0]
    set e  [pcall calc::pick_name {} 0]
    set b  [pcall calc::pick_name bus\[1:0\] 0]
    check "PK3 a scalar net composes `v(<token>)` with the token's CASE PRESERVED and an unnamed net's leading `#` stripped -- `preserve` and not `fold`, because the database already exists and the only honest question about its spelling is the one R204's read-back asks" \
        [list [pk_fld $a ok] [pk_fld $a cand] [pk_fld $h ok] [pk_fld $h cand]] \
        {1 v(A) 1 v(net1)}
    check "PK3 fixture for the row above: `preserve` and `fold` really do differ on that token, so the case claim is a measurement of the argument and not a constant that would hold either way" \
        [list [pcall ase::ui::sod_expr voltage A preserve] \
              [pcall ase::ui::sod_expr voltage A fold]] \
        {v(A) v(a)}
    check "PK3 a BUS refuses and NAMES ITS BITS, on the counted arm, because the buffer takes one name and the resolver answers a comma-joined multi-bit string the engine will not evaluate (R208's declared v1 limit); and an empty token refuses as `noname` rather than composing `v()`" \
        [list [pk_fld $b ok] [pk_fld $b why] [pk_fld $b detail] \
              [pk_fld $e ok] [pk_fld $e why]] \
        [list 0 bus [list bus\[1\] bus\[0\]] 0 noname]
    check "PK3 fixture for the bus leg: `ase::ui::sod_bits` really expands that token to more than one bit through `xschem expandlabel`, so the guard is measuring an expansion and not a bracket in a string" \
        [list [llength [pcall ase::ui::sod_bits bus\[1:0\]]] \
              [llength [pcall ase::ui::sod_bits A]]] {2 1}
}

# ===========================================================================
# PK4 — R204 AND R207 AGAINST A REAL DATABASE
# ===========================================================================
group PK4 {
    check "PK4 fixture: the committed raw was located" \
        [expr {[pk_fixture] ne {} ? 1 : 0}] 1
    # ⚠ NOTHING LOADED FIRST, because that arm is the one an rc or a stray click
    # reaches and the one where the bare verbs RAISE.
    pcall xschem raw clear
    set n0 [pcall calc::pick_lookup v(sq)]
    check "PK4 with NO database loaded `calc::pick_lookup` ANSWERS `noraw` and does not raise -- the ladder asks `xschem raw loaded` first precisely because it answers -1 silently while `xschem raw index` and `xschem raw list` both raise `No raw file loaded`" \
        [list [pk_fld $n0 ok] [pk_fld $n0 why] [pk_fld $n0 name]] {0 noraw {}}
    check "PK4 fixture for the row above: those two verbs really DO raise with nothing loaded while `raw loaded` really does answer -1, so the ladder's order is forced by a measurement and not by taste" \
        [list [pcall xschem raw loaded] \
              [pk_word [string match ERR:* [pcall xschem raw index v(sq)]] raises quiet] \
              [pk_word [string match ERR:* [pcall xschem raw list]] raises quiet]] \
        {-1 raises raises}
    # ...now the tran arm
    check "PK4 fixture: the raw reads as `tran`" [pk_read tran] 1
    set inv [pk_inventory]
    set ok1 [pcall calc::pick_lookup v(sq)]
    set up1 [pcall calc::pick_lookup V(SQ)]
    set br1 [pcall calc::pick_lookup SQ]
    set no1 [pcall calc::pick_lookup v(nope)]
    set em1 [pcall calc::pick_lookup {}]
    set hp1 [pcall calc::pick_lookup x1.i2.net]
    check "PK4 R207's fence is the INVENTORY READ-BACK and nothing else could be: `xschem raw index` is case-insensitive AND accepts a bare net name, so three different spellings resolve to the same column -- and all three come back as the RAW's own spelling, read by index out of `xschem raw list`, which is the only thing that can catch a case difference" \
        [list [pk_fld $ok1 name] [pk_fld $up1 name] [pk_fld $br1 name]] \
        {v(sq) v(sq) v(sq)}
    check "PK4 ...and the read-back is byte-identical to the inventory row at that index, which is the claim R207 actually makes -- compared against `xschem raw list`'s own element, not against a spelling typed here" \
        [list [pk_fld $up1 name] \
              [lindex $inv [pcall xschem raw index V(SQ)]] \
              [expr {[pk_fld $up1 name] eq [lindex $inv [pcall xschem raw index V(SQ)]] ? {same} : {DIFFERENT}}]] \
        [list v(sq) v(sq) same]
    check "PK4 NON-VACUITY, re-measured every run so neither leg above can go quiet: the two spellings really do differ as strings (or the case claim is vacuous), and the index check alone really cannot see it (or the read-back is redundant)" \
        [list [pk_word [string equal V(SQ) v(sq)] SAME differ] \
              [expr {[pcall xschem raw index V(SQ)] == [pcall xschem raw index v(sq)] ? {sameindex} : {DIFFERENTINDEX}}]] \
        {differ sameindex}
    check "PK4 R204 refuses what the database does not hold, with `unresolved` and no insertion: an absent node, the empty string, and a hierarchical name belonging to some other deck" \
        [list [pk_fld $no1 ok] [pk_fld $no1 why] \
              [pk_fld $em1 ok] [pk_fld $em1 why] \
              [pk_fld $hp1 ok] [pk_fld $hp1 why]] \
        {0 unresolved 0 unlexable 0 unresolved}
    check "PK4 the SWEEP COLUMN is unreachable through the wrap, which is why no `idx >= 1` guard exists or should: `v(time)` resolves to -1 while the bare `time` is index 0, so a guard against index 0 would falsely refuse a legitimate column and buy nothing" \
        [list [pcall xschem raw index v(time)] [pcall xschem raw index time] \
              [pk_fld [pcall calc::pick_lookup v(time)] why]] \
        {-1 0 unresolved}
    # ...and the AC arm, because `vf` is an AC selector and AC names are the
    # four-column expansion `read_dataset` builds by doubling raw->nvars.
    check "PK4 fixture: the same raw reads as `ac`" [pk_read ac] 1
    set inva [pk_inventory]
    set oka [pcall calc::pick_lookup v(sq)]
    set upa [pcall calc::pick_lookup V(SQ)]
    check "PK4 the read-back is sound on an AC database too, which had to be measured because `vf` is an AC selector: `read_dataset` stores four doubles per AC variable and DOUBLES `raw->nvars`, and `xschem raw list` prints `raw->names` element by element for all of them while `raw index` indexes the same array -- so the inventory really is 4x the tran one, the phase column is addressable by name, and the read-back still answers the raw's own spelling" \
        [list [pk_sized [llength $inv] 10] [pk_sized [llength $inva] 40] \
              [pk_fld $oka name] [pk_fld $upa name] \
              [lindex $inva [pcall xschem raw index ph(sq)]] \
              [pcall xschem raw index frequency]] \
        {n10 n40 v(sq) v(sq) ph(sq) 0}
    pcall xschem raw clear
}

# ===========================================================================
# PK2 — R203, PURE AND THEN LIVE
# ===========================================================================
# The pure half first, because that is the half that makes a refusal testable
# with no schematic at all.  Then the same classifier against real geometry on
# the SHIPPED sheet, with every coordinate DERIVED from the object it belongs to
# rather than typed -- `xschem wire_coord <n>` for a wire's own midpoint and
# `xschem instance_pin_coord <i> name <pin>` for a pin, so a sheet edit moves the
# probe with it instead of silently measuring empty canvas.
#
# ⚠ `xschem object_bbox` DOES NOT EXIST -- there is no such branch in
# src/scheduler.c.  The readers are `xschem wire_coord` (four coordinates) and
# `xschem instance_bbox` (two lines, `Instance: x1 y1 x2 y2` then `Symbol: ...`).
#
# ⚠ ONLY `[lindex $hit 0]` AND `[lindex $hit 1]` ARE FILE-STABLE.  `object_at`'s
# fourth field is the object's `id`, which is SESSION-stable and not
# file-stable: the same instance of the same file read `instance 0 1 1` in a
# process that loaded only that file and `instance 0 1 15` in a process that had
# loaded another sheet first.  Pinning it would redden on run order.
#
# ⚠⚠ AND THE `terminal` CLASS IS NOT REACHABLE ON cmos_inv.sch AT ALL, WHICH WAS
# REFUTED RATHER THAN ASSUMED.  `net_at` is `point_on_wire_or_pin()`, so copper is
# (every wire segment, endpoints included) union (exact instance pin
# coordinates) -- and on that sheet every one of the 22 pin coordinates of all 14
# instances answers `net_at` 1 while `object_at` answers `wire` at 20 of them and
# the sheet's dashed boundary `poly` at the other two.  A walk of every wire at a
# step of 0.1 -- 5714 probes -- found `object_at` answering `instance` ZERO times
# on copper: a wire always wins `find_closest_obj` over an instance it crosses.
# So `terminal` needs a device pin that no wire covers, which is what the
# one-`nmos4` fixture below is for, and the shipped sheet can only show the other
# three classes.
proc pk_mid {w} {
    set c [pcall xschem wire_coord $w]
    if {[llength $c] != 4} { return "SHAPE:$c" }
    return [list [expr {([lindex $c 0] + [lindex $c 2]) / 2.0}] \
                 [expr {([lindex $c 1] + [lindex $c 3]) / 2.0}]]
}
# the full triple plus the class, at one point -- what every live leg below
# compares, and the shape a failure prints.
proc pk_probe {x y} {
    set hit [pcall xschem object_at $x $y]
    set net [pcall ase::ui::sod_net_at $x $y $hit]
    set at  [pcall xschem net_at $x $y]
    return [list [lindex $hit 0] $net $at [pcall calc::pick_classify $hit $net $at]]
}
group PK2 {
    # --- the pure half, including the degenerates ------------------------
    set pure {}
    foreach {h n a} [list \
        {wire 3 4 7}     A    0 \
        {wire 3 4 7}     {}   1 \
        {instance 0 1 1} {}   1 \
        {instance 0 1 1} {}   0 \
        {instance 0 1 1} {}   {} \
        {text 1 2 3}     {}   0 \
        {poly 0 2 698}   {}   1 \
        {}               {}   0 \
        {}               VDD  0 \
        {}               {}   {} ] {
        lappend pure [pcall calc::pick_classify $h $n $a]
    }
    check "PK2 R203's classification is a PURE function of three already-measured values, so every refusal is drivable with no schematic and no canvas: a resolved net wins outright even when the hit is empty, an instance ON copper is a device TERMINAL (R203's `and vice versa`), an instance off copper is a body, a non-instance object on copper is still a body because it is neither a net nor a device pin, and an unreadable third value degrades to a refusal rather than inventing a terminal" \
        $pure {net unnamed terminal body body body body nothing net nothing}
    # ⚠ `unnamed` IS WHY THIS ROW EXISTS AND IT FOUND A WRONG SENTENCE.  A WIRE
    # whose net does not resolve is a real case -- `net_name_at` answers empty
    # for a wire the active netlist type skips (`spice_ignore`/`lvs_ignore`) --
    # and folding it into `body` made the refusal read *"that wire is not a
    # net"*, about a wire.  The second drive in the sweep above is that case, and
    # it was the first version's only wrong expectation.
    check "PK2 a WIRE that resolves no name is its OWN class and takes the `no name` sentence rather than the device-body one, which is the difference between telling the user nothing there has a net name and telling them a wire is not a net" \
        [list [pcall calc::pick_classify {wire 3 4 7} {} 1] \
              [pcall calc::pick_classify {wire 3 4 7} {} 0] \
              [pcall calc::pick_msg noname vt] \
              [pcall calc::pick_msg body vt {that wire}]] \
        [list unnamed unnamed {selector vt: nothing there resolves to a net name} \
              {selector vt: that wire is not a net}]
    check "PK2 ...and the vocabulary is CLOSED: ten drives produced exactly five distinct words and no sixth, so a new class has to move this row rather than arrive as an unhandled sentence" \
        [lsort -unique $pure] {body net nothing terminal unnamed}
    # --- the live half, on the shipped sheet ----------------------------------
    set sheet [file normalize [file join [file dirname $::XSCHEM_SHAREDIR] \
                                   xschem_library examples cmos_inv.sch]]
    check "PK2 fixture: the shipped sheet was located and loaded, and it still has the wires and instances the probes below are derived from" \
        [list [file exists $sheet] \
              [expr {[pcall xschem load $sheet] ne {} ? 1 : 0}] \
              [pk_sized [llength [pcall xschem objects -type wire]] 14] \
              [pk_sized [llength [pcall xschem objects -type instance]] 14]] \
        {1 1 n14 n14}
    check "PK2 fixture: this sheet is at its TOP level, which is what makes `ase::ui::sod_rel_path 0` empty and every name below unqualified -- the descended case is PK5's" \
        [list [pcall xschem get sch_path] [pcall xschem get currsch] \
              [pcall ase::ui::sod_rel_path 0]] \
        [list . 0 {}]
    # two NAMED nets, each at its own wire's midpoint
    set p0 [pk_mid 0]
    set p9 [pk_mid 9]
    check "PK2 a click on a wire classifies `net` and resolves that wire's own name, measured at TWO wires' derived midpoints and reported as the whole triple so a failure says which of the three readers moved" \
        [list $p0 [pk_probe {*}$p0] $p9 [pk_probe {*}$p9]] \
        [list {80.0 -200.0} {wire A 1 net} {350.0 -230.0} {wire Z 1 net}]
    # a device BODY, from the instance's own bbox, and the name the sentence uses
    check "PK2 a click inside a device body classifies `body` and `calc::pick_what` answers the INSTANCE'S OWN NAME, so the refusal can say `M1 is not a net` rather than something generic -- and `net_at` really is 0 there, which is what separates this from the terminal class" \
        [list [pk_probe 110 -190] [pcall calc::pick_what [pcall xschem object_at 110 -190]] \
              [pk_probe 188 -237] [pcall calc::pick_what [pcall xschem object_at 188 -237]]] \
        [list {instance {} 0 body} M1 {instance {} 0 body} R1]
    check "PK2 a click on empty canvas classifies `nothing`, and the row checks that `object_at` really is EMPTY there rather than trusting the class word" \
        [list [pcall xschem object_at 9999 9999] [pk_probe 9999 9999]] \
        [list {} {{} {} 0 nothing}]
    # ⚠ THE REFUTATION, CARRIED AS A ROW.  If a future sheet edit uncovered a
    # pin this would redden, and that is the right outcome: the fixture below
    # exists precisely because this sheet cannot show the terminal class.
    set pinhits {}
    foreach i [list 4 5 9] {
        foreach pin [pcall xschem instance_pins $i] {
            set c [pcall xschem instance_pin_coord $i name $pin]
            if {[llength $c] != 3} { lappend pinhits "SHAPE:$c" ; continue }
            lappend pinhits [lindex [pk_probe [lindex $c 1] [lindex $c 2]] 3]
        }
    }
    check "PK2 THE REFUTATION, re-measured every run: not one pin coordinate of three of this sheet's instances classifies `terminal`, because every pin is covered by a wire and a wire always wins `find_closest_obj` -- so the shipped sheet CANNOT fence the terminal arm and the one-instance fixture below is not redundant.  A sheet edit that uncovered a pin reddens this row, which is the correct outcome" \
        [list [pk_atleast [llength $pinhits] 6] \
              [pk_in [lsort -unique $pinhits] terminal]] \
        {atleast6 missing:terminal}
    check "PK2 ...and the pin reader's ELEMENT ORDER is pinned, because getting it wrong is what produced a wrong `net_at` measurement once: the answer is {name} x y, so the pin NAME is element 0 and the coordinates are 1 and 2 -- reading (0,1) probes (a name, an x) and lands nowhere" \
        [list [llength [pcall xschem instance_pin_coord 5 name g]] \
              [lindex [pcall xschem instance_pin_coord 5 name g] 0]] \
        {3 g}
}

# ===========================================================================
# PK2b — THE `terminal` CLASS, ON A FIXTURE THAT CAN SHOW IT
# ===========================================================================
# One `nmos4`, no wires, built by DRIVING xschem rather than by hand-writing
# `.sch` text, so the fixture follows the file format instead of pinning a
# `file_version` nothing re-checks.
#
# ⚠⚠ THE TEXT IS WRITTEN DIRECTLY AND *NOT* BUILT BY DRIVING xschem, AND THAT IS
# A MEASUREMENT RATHER THAN A PREFERENCE.  `xschem instance` + `xschem saveas` is
# the obvious way to build a fixture and it writes a SECOND file: `saveas` of an
# UNTITLED schematic also drops a cwd-relative `untitled~.sch` backup.  It landed
# in the REPO ROOT on the first run of this band -- and `cd`-ing into the scratch
# dir first did NOT move it, so there is no way to drive it safely from a suite
# that must leave the tree alone.  It is gitignored (`*~.sch`), so `git status`
# would never have shown it.
#
# The cost of writing the text is that a `.sch` format change could stale it, and
# that is paid by the fixture row below, which asserts the file LOADS, that it
# holds exactly one instance and no wires, and that the pin reader answers -- so
# a format change reddens a row that names the fixture instead of silently
# measuring an empty sheet.
group PK2b {
    set pkscr [test_scratch calcpick]
    set pksch [file join $pkscr nmos_only.sch]
    set pkfh [open $pksch w]
    puts $pkfh "v {xschem version=3.4.8RC file_version=1.3}"
    foreach k {G K V S F E} { puts $pkfh "$k {}" }
    puts $pkfh "C {nmos4.sym} 0 0 0 0 {name=M1 model=nmos w=5u l=0.18u del=0 m=1}"
    close $pkfh
    check "PK2b fixture: the one-instance, no-wire sheet loads and reads back with exactly one instance and no wires, so a `.sch` format change reddens a row that NAMES the fixture rather than leaving this band measuring an empty sheet" \
        [list [file exists $pksch] \
              [expr {[pcall xschem load $pksch] ne {} ? 1 : 0}] \
              [pk_sized [llength [pcall xschem objects -type instance]] 1] \
              [pk_sized [llength [pcall xschem objects -type wire]] 0] \
              [pcall xschem getprop instance 0 name]] \
        {1 1 n1 n0 M1}
    set g [pcall xschem instance_pin_coord 0 name g]
    check "PK2b fixture: the gate pin's coordinate is READ BACK from the symbol and never a magic number, and it is the three-element {name} x y shape" \
        [list [llength $g] [lindex $g 0]] {3 g}
    set gx [lindex $g 1] ; set gy [lindex $g 2]
    check "PK2b R203's `terminal` class is REAL and is BIT-EXACT: at the pin's own coordinate `object_at` says instance and `net_at` says 1, so the click is a device terminal and the voltage selector refuses it -- which is R203's `a voltage selector must refuse a terminal-only click` with nothing left to assume" \
        [pk_probe $gx $gy] {instance {} 1 terminal}
    set off {}
    foreach d {0.0001 0.5 2 5} {
        lappend off [lindex [pk_probe [expr {$gx + $d}] $gy] 3]
        lappend off [lindex [pk_probe $gx [expr {$gy + $d}]] 3]
    }
    check "PK2b ...and `net_at` is a BIT-EXACT compare, not a tolerance: one ten-thousandth of a unit off the pin it already answers 0 and the class falls to `body`, at every offset and in both axes.  That is the whole reason this predicate is asked at the SNAPPED pair, where a pointer merely near a pin lands on it, and can only choose between two refusals" \
        [list $off [lsort -unique $off]] [list {body body body body body body body body} body]
    check "PK2b the OTHER THREE pins answer `terminal` too, so the fixture gives four independent terminal coordinates and the row above is not resting on one lucky pin" \
        [list [lindex [pk_probe {*}[lrange [pcall xschem instance_pin_coord 0 name d] 1 2]] 3] \
              [lindex [pk_probe {*}[lrange [pcall xschem instance_pin_coord 0 name s] 1 2]] 3] \
              [lindex [pk_probe {*}[lrange [pcall xschem instance_pin_coord 0 name b] 1 2]] 3]] \
        {terminal terminal terminal}
    # ⚠ MEASURED AND DECLARED: five units in -x is OUTSIDE the symbol bbox
    # (-22.5), so `object_at` is empty and the class is `nothing`, not `body`.
    # The row above therefore takes its offsets in +x and +y only -- and this row
    # records why, so nobody "fixes" the asymmetry back into a wrong expectation.
    check "PK2b the declared edge of that sweep: five units in the OTHER direction leaves the symbol's own bounding box, so `object_at` is empty and the class is `nothing` rather than `body` -- which is why the offsets above are taken in one direction and is recorded here rather than left as an unexplained asymmetry" \
        [pk_probe [expr {$gx - 5}] $gy] {{} {} 0 nothing}
    test_scratch_drop $pkscr
}

# ===========================================================================
# PK12 — R208e: THE CURRENT SELECTORS' SOURCE PICK
# ===========================================================================
# `it`/`if`/`idc`/`is` pick a VOLTAGE SOURCE or AMMETER instance by its body and
# insert `it(<inst>)` (or `if`/`idc`/`is`).  The rule for "is this click a
# source" is ASE-L Select-On-Design's, and it is ONE rule:
# `ase::ui::sod_source_at` answers the instance name for a hit whose
# `cell::type` is `vsource` or `ammeter`, and both `ase::ui::sod_click` and the
# Calculator's click (through `calc::pick_imeasure`) call it -- so the two
# gestures cannot disagree about which devices count.  This band is the click
# that is NOT on a device pin; the pin comes first and is band PK13's (R208f).
#
# The sheet is written as text for PK2b's measured reason (a driven `saveas`
# drops an `untitled~.sch` in the repo root).  Every probe point is DERIVED
# from the instance's own bbox, never typed.
proc pk_bbox_mid {i} {
    set b [pcall xschem instance_bbox $i]
    if {![regexp {Instance:\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)} $b -> x1 y1 x2 y2]} { return "SHAPE:$b" }
    return [list [expr {($x1 + $x2) / 2.0}] [expr {($y1 + $y2) / 2.0}]]
}
proc pk_iprobe {x y} {
    set hit [pcall xschem object_at $x $y]
    set src [pcall ase::ui::sod_source_at $hit]
    return [list [lindex $hit 0] $src [pcall calc::pick_iclassify $hit $src]]
}
group PK12 {
    # --- the pure half -------------------------------------------------------
    set pure {}
    foreach {h src} [list {instance 0 1 1} V1 {instance 0 1 1} {} {wire 3 4 7} {} \
                          {text 1 2 3} {} {} {} {} V1] {
        lappend pure [pcall calc::pick_iclassify $h $src]
    }
    check "PK12 R208e's classification is PURE over two measured values: a hit the shared source rule NAMED is a `source`, any other hit -- a device body, a wire, a text -- is `other`, and an empty hit is `nothing` even if a stale name were handed in, so a click on empty canvas can never insert a source" \
        $pure {source other other other nothing nothing}
    check "PK12 ...and the vocabulary is CLOSED at three words" [lsort -unique $pure] {nothing other source}
    # --- ONE rule, shared with ASE-L Select-On-Design --------------------------
    set sodb [pk_decomment [pcall info body ::ase::ui::sod_click]]
    set pcb  [pk_decomment [pcall info body ::calc::pick_click]]
    set pmb  [pk_decomment [pcall info body ::calc::pick_imeasure]]
    set ruleb [pk_decomment [pcall info body ::ase::ui::sod_source_at]]
    check "PK12 the source rule is ONE proc that BOTH gestures call: ASE-L's Select-On-Design click reaches `ase::ui::sod_source_at` itself and the Calculator's click through `calc::pick_imeasure`, the one proc of its pick that asks what is under the cursor; only the rule reads `cell::type` -- so a third source type added there reaches both, and neither can drift" \
        [list [pk_word [regexp {ase::ui::sod_source_at} $sodb] sod MISSING] \
              [pk_word [regexp {ase::ui::sod_source_at} $pmb] calc MISSING] \
              [pk_word [regexp {calc::pick_imeasure} $pcb] click UNMEASURED] \
              [pk_word [regexp {cell::type} $ruleb] rule NORULE] \
              [pk_word [regexp {cell::type} $sodb] SODCOPY one] \
              [pk_word [regexp {cell::type} $pcb$pmb] CALCCOPY one] \
              [pcall info args ::ase::ui::sod_source_at]] \
        {sod calc click rule one one hit}
    check "PK12 the rule ANSWERS rather than raising on a hit it cannot read: empty, a wire, and an instance index that does not exist all answer the empty string" \
        [list [pcall ase::ui::sod_source_at {}] [pcall ase::ui::sod_source_at {wire 0 1 1}] \
              [pcall ase::ui::sod_source_at {instance 9999 1 1}]] {{} {} {}}
    # --- the live half, on a sheet that has every class ------------------------
    set pkscr [test_scratch calcpick]
    set pksch [file join $pkscr isrc.sch]
    set pkfh [open $pksch w]
    puts $pkfh "v {xschem version=3.4.8RC file_version=1.3}"
    foreach k {G K V S F E} { puts $pkfh "$k {}" }
    puts $pkfh "N 600 0 700 0 {}"
    puts $pkfh "C {vsource.sym} 0 0 0 0 {name=V1 value=1}"
    puts $pkfh "C {ammeter.sym} 200 0 0 0 {name=Vam}"
    puts $pkfh "C {nmos4.sym} 400 0 0 0 {name=M1 model=nmos w=5u l=0.18u del=0 m=1}"
    puts $pkfh "C {lab_pin.sym} 600 0 0 0 {name=l1 sig_type=std_logic lab=n1}"
    close $pkfh
    check "PK12 fixture: the sheet loads with its four instances and the two sources really carry the cell types the rule reads, so the live rows below measure the rule and not a symbol that failed to resolve" \
        [list [expr {[pcall xschem load $pksch] ne {} ? 1 : 0}] \
              [pk_sized [llength [pcall xschem objects -type instance]] 4] \
              [pcall xschem getprop instance 0 cell::type] [pcall xschem getprop instance 1 cell::type] \
              [pcall xschem getprop instance 2 cell::type]] \
        {1 n4 vsource ammeter nmos}
    set mv [pk_bbox_mid 0] ; set ma [pk_bbox_mid 1] ; set mm [pk_bbox_mid 2]
    check "PK12 a click anywhere on a voltage source's or an ammeter's BODY names that instance and classifies `source`; a MOSFET body and a labelled wire are `other`; empty canvas is `nothing` -- each the whole triple, so a failure says which reader moved" \
        [list [pk_iprobe {*}$mv] [pk_iprobe {*}$ma] [pk_iprobe {*}$mm] \
              [pk_iprobe 650 0] [pk_iprobe 9999 9999]] \
        {{instance V1 source} {instance Vam source} {instance {} other} {wire {} other} {{} {} nothing}}
    test_scratch_drop $pkscr
    # --- the name ---------------------------------------------------------------
    check "PK12 `calc::pick_iname` composes `i(<inst>)` with the instance's CASE PRESERVED -- the database decides the spelling, through R204's read-back -- and an empty token refuses as `noname` rather than composing `i()`; its signature is pinned with `info args`" \
        [list [pk_fld [pcall calc::pick_iname V1 0] cand] [pk_fld [pcall calc::pick_iname Vam 0] cand] \
              [pk_fld [pcall calc::pick_iname {} 0] ok] [pk_fld [pcall calc::pick_iname {} 0] why] \
              [pcall info args ::calc::pick_iname]] \
        {i(V1) i(Vam) 0 noname {tok baselvl}}
    # the hierarchical half is `sod_qualify current`'s, ASE's own -- stubbed to
    # show the DELEGATION, which a hand-assembled path would not pass.
    rename ase::ui::sod_qualify pk_real_qualify
    proc ase::ui::sod_qualify {kind token {baselvl 0}} {
        if {$kind eq {current}} { return "v.x1.$token" }
        return "WRONGKIND:$kind"
    }
    set hq [pk_fld [pcall calc::pick_iname V1 1] cand]
    rename ase::ui::sod_qualify {}
    rename pk_real_qualify ase::ui::sod_qualify
    check "PK12 a descended source's name is `ase::ui::sod_qualify current`'s -- the same branch-prefix rule Select-On-Design writes into a deck -- and the stub was put back" \
        [list $hq [pcall ase::ui::sod_qualify current V1 0]] {i(v.x1.V1) V1}
    check "PK12 the token a current pick inserts puts the selector id where the read-back's `i` is, any case, exactly as a voltage pick replaces `v`" \
        [list [pcall calc::aq_qualify it i(v1)] [pcall calc::aq_qualify idc I(Vam)] \
              [pcall calc::aq_qualify is i(v.x1.v1)] [pcall calc::aq_qualify vt v(lp)]] \
        {it(v1) idc(Vam) is(v.x1.v1) vt(lp)}
    # --- R204/R207 on a database that holds source currents ---------------------
    set pkscr2 [test_scratch calcpick]
    set praw [file join $pkscr2 isrc.raw]
    set fh [open $praw w]
    puts $fh "Title: pk12\nDate: pk12\nPlotname: Transient Analysis\nFlags: real"
    puts $fh "No. Variables: 4\nNo. Points: 2\nVariables:"
    puts $fh "\t0\ttime\ttime\n\t1\tv(n1)\tvoltage\n\t2\ti(v1)\tcurrent\n\t3\ti(vam)\tcurrent"
    puts $fh "Values:\n 0\t0.0\n\t1.0\n\t-1e-3\n\t2e-3\n\n 1\t1e-6\n\t1.5\n\t-1.5e-3\n\t2.5e-3\n"
    close $fh
    pcall xschem raw clear
    set rd [pcall xschem raw read $praw tran]
    set lk [pcall calc::pick_lookup [pk_fld [pcall calc::pick_iname V1 0] cand]]
    set la [pcall calc::pick_lookup [pk_fld [pcall calc::pick_iname Vam 0] cand]]
    set ln [pcall calc::pick_lookup [pk_fld [pcall calc::pick_iname Vnone 0] cand]]
    pcall xschem raw clear
    test_scratch_drop $pkscr2
    check "PK12 R204/R207 for a SOURCE: the composed `i(V1)` resolves in a database holding the source's branch current and comes back in the RAW's own spelling, which is what the token is built from; a source the result does not hold is `unresolved` and nothing is inserted" \
        [list $rd [pk_fld $lk ok] [pk_fld $lk name] [pk_fld $la name] [pk_fld $ln ok] [pk_fld $ln why] \
              [pcall calc::aq_qualify it [pk_fld $lk name]]] \
        {1 1 i(v1) i(vam) 0 unresolved it(v1)}
    # --- the sentences -----------------------------------------------------------
    check "PK12 the current selectors say their own gesture and their own refusals, terse, each inside the status room: arm, prompt, a click on nothing, and a click on something that has no current to pick -- each naming the three things that DO have one, a device pin, a voltage source and an ammeter (R208f: the sentence used to call terminal currents not supported)" \
        [list [pcall calc::pick_msg iarmed it] [pcall calc::pick_msg iprompt it] \
              [pcall calc::pick_msg inothing it] [pcall calc::pick_msg notsource idc]] \
        [list {selector it: click a device pin, voltage source or ammeter; ESC cancels} \
              {Calculator it: click a device pin, voltage source or ammeter; ESC cancels} \
              {selector it: nothing there; click a device pin, voltage source or ammeter} \
              {selector idc: no current there; click a device pin, voltage source or ammeter}]
}

# ===========================================================================
# PK13 — R208f: THE CURRENT SELECTORS PICK A DEVICE PIN (issue 1724)
# ===========================================================================
# A current selector's click on an instance pin is that TERMINAL's current.  The
# click is three steps, each its own proc so each gates here:
#   calc::pick_imeasure  what the cursor is on -- asked of ASE-L's own pin rule
#                        (`ase::ui::sod_terminal_at`), naming rule
#                        (`ase::ui::sod_terminal_resolve`) and source rule
#                        (`ase::ui::sod_source_at`), and of nothing else;
#   calc::pick_iplan     what to do with it, PURE: a refusal, or the candidates
#                        to look up in order;
#   calc::pick_iresolve  the lookups: the first candidate the result holds.
# The ACT -- the name really reaching the buffer through a real press -- is band
# PG19 of tests/headless/test_calc_pick.tcl, on the display arm.
#
# THE CALCULATOR WRITES NO DECK, so a terminal resolves only when the loaded
# result already holds its vector.  The committed results that do are
# tests/headless/data/probe_1724_tran.raw and probe_1724_op.raw (README.md
# beside them has their vectors).  The reader stores every `:` of a vector name
# as `.`, and the pick inserts the raw's own stored spelling, read back.
#
# THE KEY IS NO SESSION in the live rows (`__pk_nosession__`), which is the
# state of a scripted pick: the pin rule and the naming rule answer with it for
# every device below, the one subcircuit call among them with the caution that
# no header is in hand.  A REAL pick is never in that state -- the arm refuses a
# token whose design does not resolve, which a row here re-measures.
#
# The sheet is written as text for PK2b's measured reason.  Every probe point is
# read off the instance's own pins.
proc pk_probe_raw {type} {
    foreach cand [list \
        [file join [file dirname [info script]] data probe_1724_$type.raw] \
        [file join [file dirname $::XSCHEM_SHAREDIR] tests headless data probe_1724_$type.raw]] {
        if {[file exists $cand]} { return [file normalize $cand] }
    }
    return {}
}
proc pk_readp {type} {
    set f [pk_probe_raw $type]
    if {$f eq {}} { return {NOFIXTURE} }
    pcall xschem raw clear
    return [pcall xschem raw read $f $type]
}
# the index of the instance called `nm` on the sheet shown, -1 when there is none
proc pk_inst {nm} {
    set n [pcall xschem get instances]
    if {![string is integer -strict $n]} { return -1 }
    for {set i 0} {$i < $n} {incr i} {
        if {[pcall xschem getprop instance $i name] eq $nm} { return $i }
    }
    return -1
}
# a pin's own point, as {x y}, from a door that is not the pin rule
proc pk_pin {nm pin} {
    return [lrange [pcall xschem instance_pin_coord [pk_inst $nm] name $pin] 1 2]
}
# a plan in one line: `try {t:<token> s:<source>}` or `refuse <kind> <detail>`
proc pk_plansum {p} {
    if {[pk_fld $p act] eq {try}} {
        set o {}
        foreach st [pk_fld $p steps] {
            if {[pk_fld $st kind] eq {terminal}} {
                lappend o "t:[pk_fld $st token]"
            } else {
                lappend o "s:[pk_fld $st name]"
            }
        }
        return [list try $o]
    }
    return [list [pk_fld $p act] [pk_fld $p kind] [pk_fld $p detail]]
}
# the click at a schematic point, measured and planned
proc pk_tplan {x y} {
    set hit [pcall xschem object_at $x $y]
    return [pcall calc::pick_iplan [pcall calc::pick_imeasure __pk_nosession__ $x $y $hit]]
}
# ...and looked up in the CURRENT context: what the click would insert and say,
# as `insert <token> <path> <kind of the step taken>` or `refuse <arm> <detail>`
proc pk_tclick {id x y} {
    set plan [pk_tplan $x $y]
    if {[pk_fld $plan act] ne {try}} {
        return [list refuse [pk_fld $plan kind] [pk_fld $plan detail]]
    }
    set r [pcall calc::pick_iresolve [pk_fld $plan steps] 0 calc::pick_lookup_in \
               [pcall calc::pick_analysis $id]]
    if {[pk_fld $r ok] eq {1}} {
        return [list insert [pcall calc::aq_qualify $id [pk_fld $r name]] [pk_fld $r path] \
                    [pk_fld [pk_fld $r step] kind]]
    }
    return [list refuse [pk_fld $r why] [pk_fld $r detail]]
}
# ...and the notes that click says before its last sentence: the click's own
# three steps in the click's own order, the lookups in the CURRENT context
proc pk_tnotes {id x y} {
    set hit [pcall xschem object_at $x $y]
    set m [pcall calc::pick_imeasure __pk_nosession__ $x $y $hit]
    set plan [pcall calc::pick_iplan $m]
    set lk {}
    if {[pk_fld $plan act] eq {try}} {
        set lk [pcall calc::pick_iresolve [pk_fld $plan steps] 0 calc::pick_lookup_in \
                    [pcall calc::pick_analysis $id]]
    }
    return [pcall calc::pick_inotes $id $m $lk]
}
# a step of a plan with its `place` key taken out, for a row whose subject is
# the rest of the step; a step that is no dict comes back as it is
proc pk_noplace {st} {
    if {[catch {dict remove $st place} r]} { return $st }
    return $r
}
# is `w` one of the three words a source step's `place` may hold
proc pk_placeword {w} {
    return [expr {[lsearch -exact {first second other} $w] >= 0 ? {aplace} : "NOPLACE:$w"}]
}
# two numbers the same to rounding / clearly apart, as words
proc pk_same {a b} {
    if {![string is double -strict $a] || ![string is double -strict $b]} { return "NAN:$a/$b" }
    set s [expr {abs($a) > abs($b) ? abs($a) : abs($b)}]
    return [expr {abs($a - $b) <= 1e-12 * $s ? {same} : "differ:$a/$b"}]
}
proc pk_apart {a b} {
    if {![string is double -strict $a] || ![string is double -strict $b]} { return "NAN:$a/$b" }
    set s [expr {abs($a) > abs($b) ? abs($a) : abs($b)}]
    return [expr {$s > 0 && abs($a - $b) > 1e-3 * $s ? {apart} : "CLOSE:$a/$b"}]
}
group PK13 {
    check "PK13 the three steps of a current pick, and the notes beside them, are pinned with `info args` and `info default`: the measure takes the session key, the UN-SNAPPED point and the hit already taken there; the plan takes the measure's dict and nothing else, which is what keeps it pure; the lookups take the steps, the base level, a lookup command and the analysis, which defaults to empty" \
        [list [pcall info args ::calc::pick_imeasure] [pcall info args ::calc::pick_iplan] \
              [pcall info args ::calc::pick_iresolve] \
              [pcall info default ::calc::pick_iresolve an __pk_d] \
              [pcall info args ::calc::pick_inotes]] \
        [list {key x y hit} m {steps base lookup an} 1 {id m lk}]
    # --- the plan, PURE: every order and every refusal from synthetic dicts ------
    set T   {inst 3 pin 0 instname M1 pinname d x 420 y -30 others {}}
    set OK1 {ok 1 tokens x1.M1:d label M1:d caution {}}
    set NO  {ok 0 why {flat netlisting renames every device}}
    set BUS {ok 1 tokens {xr[1]:n1 xr[0]:n1} label xr[1:0]:P caution {}}
    set drives [list \
        pin        [dict create hit {instance 3 1 9} src {} term $T res $OK1 tsrc {} err {}] \
        srcpin     [dict create hit {instance 3 1 9} src V1 term $T res $OK1 tsrc V1 err {}] \
        wirepin    [dict create hit {wire 0 1 2}     src {} term $T res $OK1 tsrc {} err {}] \
        overbody   [dict create hit {instance 0 1 9} src V9 term $T res $OK1 tsrc {} err {}] \
        refused    [dict create hit {instance 3 1 9} src {} term $T res $NO  tsrc {} err {}] \
        refusedsrc [dict create hit {instance 3 1 9} src V1 term $T res $NO  tsrc V1 err {}] \
        unasked    [dict create hit {instance 3 1 9} src {} term $T res {}   tsrc {} err {}] \
        bus        [dict create hit {instance 3 1 9} src {} term $T res $BUS tsrc {} err {}] \
        bussrc     [dict create hit {instance 3 1 9} src V1 term $T res $BUS tsrc V1 err {}] \
        body       [dict create hit {instance 0 1 9} src V1 term {} res {} tsrc {} err {}] \
        device     [dict create hit {instance 3 1 9} src {} term {} res {} tsrc {} err {}] \
        wire       [dict create hit {wire 0 1 2}     src {} term {} res {} tsrc {} err {}] \
        empty      [dict create hit {}               src {} term {} res {} tsrc {} err {}] \
        stale      [dict create hit {}               src V1 term {} res {} tsrc {} err {}] \
        garbage    {not a dict at all} \
        badterm    [dict create hit {} src {} term "\{" res {} tsrc {} err {}] \
        badtoks    [dict create hit {} src {} term $T \
                        res [dict create ok 1 tokens "\{x" label L caution {}] tsrc {} err {}]]
    set got {}
    set kinds {} ; set stepkinds {}
    foreach {nm m} $drives {
        set p [pcall calc::pick_iplan $m]
        lappend got $nm [pk_plansum $p]
        if {[pk_fld $p act] eq {refuse}} { lappend kinds [pk_fld $p kind] }
        if {[pk_fld $p act] eq {try}} {
            foreach st [pk_fld $p steps] { lappend stepkinds [pk_fld $st kind] }
        }
    }
    check "PK13 R208f's plan is a PURE function of the measured dict, so every order and every refusal is drivable with no schematic: a device pin is its TERMINAL whatever is under the cursor beside it -- a body, a wire, another source's body; on the pin of a source the source's own current stands SECOND, for a result that does not hold the terminal; a pin the naming rule refuses is refused with that rule's reason, unless it is a source's pin, which is then the source pick it was before pins were picked; a pin that is several vectors is refused listing them, source or not; and with NO pin the click is the source rule exactly as before -- a source's body, something else, nothing.  The last three drives are a text that is no dict, a pin that is no list and a token list that is no list: the plan ANSWERS for each, because an error escaping the canvas binding would let the press through to the editor" \
        $got [list \
            pin        {try t:x1.M1:d} \
            srcpin     {try {t:x1.M1:d s:V1}} \
            wirepin    {try t:x1.M1:d} \
            overbody   {try t:x1.M1:d} \
            refused    {refuse noterm {M1 pin d: flat netlisting renames every device}} \
            refusedsrc {try s:V1} \
            unasked    {refuse noterm {M1 pin d: its name could not be worked out}} \
            bus        {refuse bus {xr[1]:n1, xr[0]:n1}} \
            bussrc     {refuse bus {xr[1]:n1, xr[0]:n1}} \
            body       {try s:V1} \
            device     {refuse notsource {}} \
            wire       {refuse notsource {}} \
            empty      {refuse inothing {}} \
            stale      {refuse inothing {}} \
            garbage    {refuse inothing {}} \
            badterm    {refuse inothing {}} \
            badtoks    {refuse noterm {M1 pin d: its name could not be worked out}}]
    set arms [pk_arms pick_msg]
    set unsaid {}
    foreach k [lsort -unique $kinds] { if {[lsearch -exact $arms $k] < 0} { lappend unsaid $k } }
    check "PK13 ...and the vocabulary is CLOSED: the sweep's refusals are four kinds and no fifth, its steps two kinds, and every refusal kind is an arm `calc::pick_msg` really has -- derived from the builder's own switch, so a plan can never ask for a sentence that does not exist" \
        [list [lsort -unique $kinds] [lsort -unique $stepkinds] $unsaid] \
        [list {bus inothing noterm notsource} {source terminal} {}]
    # what the terminal step carries for the notes
    set TO {inst 3 pin 0 instname M1 pinname d x 420 y -30 others {{R2 P} {R3 M}}}
    set OKC {ok 1 tokens M1:d label M1:d caution {the port name is a guess}}
    set pc [pcall calc::pick_iplan [dict create hit {} src {} term $TO res $OKC tsrc V1 err {}]]
    set st0 [lindex [pk_fld $pc steps] 0]
    set pcalone [pcall calc::pick_iplan [dict create hit {} src {} \
                     term [dict replace $TO others {}] res $OKC tsrc V1 err {}]]
    check "PK13 a terminal step carries what the click will say beside its result: the OTHER device pins on that point with the one the click took, and the naming rule's caution with the pin it is about.  The source step behind it carries the pin it stands in for, by instance and pin name, which node of the source that pin is -- one of three words, read on its own here because the word is ASE-L's rule's and the rows below are about it -- and its OWN word about the shared point -- the same pins, and that the click took the source's current and none of theirs -- but never the caution, which is about a name the source's current does not use; with the pin alone on its point the source step says nothing about a shared point at all" \
        [list [pk_fld $st0 also] [pk_fld $st0 caution] [pk_noplace [lindex [pk_fld $pc steps] 1]] \
              [pk_placeword [pk_fld [lindex [pk_fld $pc steps] 1] place]] \
              [pk_noplace [lindex [pk_fld $pcalone steps] 1]] \
              [pk_placeword [pk_fld [lindex [pk_fld $pcalone steps] 1] place]]] \
        [list {R2 pin P, R3 pin M; the click took M1 pin d} \
              {M1 pin d: the port name is a guess} \
              {kind source name V1 inst M1 pin d also {R2 pin P, R3 pin M; the click took the current of V1}} \
              aplace \
              {kind source name V1 inst M1 pin d} aplace]
    # --- the source stand-in records WHICH NODE its pin is ------------------------
    # A source's branch current is the current into its FIRST node, so on the
    # second node the stand-in is the negative of the pin's own current, and on
    # any other pin it is not that pin's current at all.  The plan says which
    # of the three the pin is, and the word is ASE-L's rule's.  These drives
    # are the ones the rule answers from the naming rule's TOKEN alone, when it
    # names a position (`:n<k>`, the order of the netlist line), so they need
    # no sheet.  The `swapped` drives are a symbol whose format writes its pins
    # in the other order: there the token and the pin's index on the symbol
    # disagree and the token decides.  A pin the naming rule did not name by
    # position is placed by its netlist line, which the live rows below drive.
    set sgot {}
    foreach {nm idx pn res} [list \
        first_tok   0 p  {ok 1 tokens V1:n1 label V1:p caution {}} \
        second_tok  1 m  {ok 1 tokens V1:n2 label V1:m caution {}} \
        swapped_a   0 p  {ok 1 tokens x1.V1:n2 label V1:p caution {}} \
        swapped_b   1 m  {ok 1 tokens x1.V1:n1 label V1:m caution {}} \
        third_tok   2 cp {ok 1 tokens E1:n3 label E1:cp caution {}} \
        tenth       1 m  {ok 1 tokens V1:n10 label V1:m caution {}}] {
        set sp [pcall calc::pick_iplan [dict create hit {instance 0 1 9} src V1 \
                    term [dict create inst 0 pin $idx instname V1 pinname $pn x 0 y 0 others {}] \
                    res $res tsrc V1 err {}]]
        set sst [lindex [pk_fld $sp steps] end]
        lappend sgot $nm [list [pk_fld $sst kind] [pk_fld $sst name] [pk_fld $sst inst] \
                               [pk_fld $sst pin] [pk_fld $sst place]]
    }
    set sbody [lindex [pk_fld [pcall calc::pick_iplan \
                    [dict create hit {instance 0 1 9} src V1 term {} res {} tsrc {} err {}]] steps] end]
    check "PK13 the source's own current stands in for a PIN of that source, and the step RECORDS the pin and which node of the source it is -- because the source's current is the current into its first node: on the second node it is the negative of what the pin's own would be, and on any other pin it is not that pin's current at all.  With the naming rule's token naming a position the place is that position's, also against the pin's index on the symbol: the first, the second, and `other` for the third and for the tenth; a click on the source's BODY is the plain source step, with no pin and no place in it" \
        [list $sgot $sbody] \
        [list [list first_tok   {source V1 V1 p first} \
                    second_tok  {source V1 V1 m second} \
                    swapped_a   {source V1 V1 p second} \
                    swapped_b   {source V1 V1 m first} \
                    third_tok   {source V1 V1 cp other} \
                    tenth       {source V1 V1 m other}] \
              {kind source name V1}]
    # WHICH node the pin is is ASE-L's rule, asked and not re-spelt.  The rule
    # is replaced by a recorder that answers a word the rule itself would not
    # give for that pin, so a plan that worked the place out for itself cannot
    # pass; then by one that raises, and by one that answers a word that is
    # none of the three.  Last, the rule is taken AWAY, with a recorder in the
    # place of the older rule that knows only the first pin from the rest.
    set fpterm [dict create inst 0 pin 0 instname V1 pinname p x 0 y 0 others {}]
    set fpres {ok 1 tokens V1:n1 label V1:p caution {}}
    set fpm [dict create hit {instance 0 1 9} src V1 term $fpterm res $fpres tsrc V1 err {}]
    set fpreal [pcall ase::ui::sod_term_pin_place $fpterm $fpres]
    set fphad [llength [info commands ::ase::ui::sod_term_pin_place]]
    if {$fphad} { rename ase::ui::sod_term_pin_place pk_real_pinplace }
    rename ase::ui::sod_term_first_pin pk_real_firstpin
    set ::pk_fp {}
    set ::pk_fp1 {}
    proc ase::ui::sod_term_first_pin {term nm} { lappend ::pk_fp1 [list $term $nm] ; return 0 }
    proc ase::ui::sod_term_pin_place {term nm} { lappend ::pk_fp [list $term $nm] ; return other }
    set fpasked [pk_fld [lindex [pk_fld [pcall calc::pick_iplan $fpm] steps] end] place]
    set fpcalls $::pk_fp
    set fpolder [llength $::pk_fp1]
    proc ase::ui::sod_term_pin_place {term nm} { error {the rule is down} }
    set fpdown [pk_fld [lindex [pk_fld [pcall calc::pick_iplan $fpm] steps] end] place]
    proc ase::ui::sod_term_pin_place {term nm} { return sideways }
    set fpodd [pk_fld [lindex [pk_fld [pcall calc::pick_iplan $fpm] steps] end] place]
    rename ase::ui::sod_term_pin_place {}
    set ::pk_fp1 {}
    set fpgone [pk_fld [lindex [pk_fld [pcall calc::pick_iplan $fpm] steps] end] place]
    set fpgonecalls $::pk_fp1
    proc ase::ui::sod_term_first_pin {term nm} { return 1 }
    set fpgone1 [pk_fld [lindex [pk_fld [pcall calc::pick_iplan $fpm] steps] end] place]
    proc ase::ui::sod_term_first_pin {term nm} { error {the older rule is down} }
    set fpgonedown [pk_fld [lindex [pk_fld [pcall calc::pick_iplan $fpm] steps] end] place]
    rename ase::ui::sod_term_first_pin {}
    rename pk_real_firstpin ase::ui::sod_term_first_pin
    if {$fphad} { rename pk_real_pinplace ase::ui::sod_term_pin_place }
    check "PK13 WHICH node of the source the pin is is ASKED of ASE-L's own rule, the one Direct Plot's stand-in asks, and not worked out a second time here: for a pin the rule itself calls the first, with the rule replaced by a recorder that answers `other`, the plan's step carries the recorder's word, the rule was asked once with the pin rule's answer and the naming rule's answer exactly as the measure holds them, and the older rule was not asked at all; with a rule that RAISES, and with one that answers a word that is none of the three, the pin is taken for the first, so the click says nothing about a sign" \
        [list $fpreal $fpasked [pk_sized [llength $fpcalls] 1] \
              [expr {[lindex $fpcalls 0] eq [list $fpterm $fpres] ? {asis} : "got=[lindex $fpcalls 0]"}] \
              $fpolder $fpdown $fpodd] \
        {first other n1 asis 0 first first}
    check "PK13 ...and WITHOUT that rule the older one is asked, which knows the first pin from the rest: with the rule taken away and a recorder in the older rule's place, a pin it calls not-the-first is `second` -- the reading the click had before -- it was asked once with the same two answers, a pin it calls the first is `first`, and one it raises for is taken for the first.  Both rules were handed back and the product's answer again: the first for this pin" \
        [list $fpgone [pk_sized [llength $fpgonecalls] 1] \
              [expr {[lindex $fpgonecalls 0] eq [list $fpterm $fpres] ? {asis} : "got=[lindex $fpgonecalls 0]"}] \
              $fpgone1 $fpgonedown \
              [pcall ase::ui::sod_term_pin_place $fpterm $fpres] \
              [pcall ase::ui::sod_term_first_pin $fpterm $fpres] \
              [expr {[info procs ::pk_real_firstpin] eq {} && [info procs ::pk_real_pinplace] eq {} ? {restored} : {LEAKED}}]] \
        {second n1 asis first first first 1 restored}
    # --- the notes, pure ---------------------------------------------------------
    # The source step of the plan above, with the pin written down as the
    # source's first node: this row is about the shared point and the caution,
    # and what the place adds to the notes is the rows after it.
    set st1 [dict replace [lindex [pk_fld $pc steps] 1] place first]
    set mq [dict create err {}]
    set notes [list \
        [pcall calc::pick_inotes it $mq [dict create ok 1 name i(m1.d) path /M1:d step $st0]] \
        [pcall calc::pick_inotes it $mq [dict create ok 0 why absent detail i(M1:d) step $st0]] \
        [pcall calc::pick_inotes it $mq [dict create ok 1 name i(v1) path /V1 step $st1]] \
        [pcall calc::pick_inotes it $mq [dict create ok 0 why noraw detail i(M1:d) step $st0]] \
        [pcall calc::pick_inotes it [dict create err {pk boom}] {}] \
        [pcall calc::pick_inotes it {} {}]]
    set both [list {selector it: that point is also R2 pin P, R3 pin M; the click took M1 pin d} \
                   {selector it: caution, M1 pin d: the port name is a guess}]
    check "PK13 the notes a click says BEFORE its last sentence: the shared point and the caution when the step that decided the click is the TERMINAL -- it was inserted, or it is the one the result does not hold; when the SOURCE's current stood in on that shared point and was inserted, the shared point in the source's own words -- which pins, and that the click took the source's current -- and no caution; NOTHING when the lookup failed for a reason that is not the name; a pin test that raised is said on its own; and nothing at all for a click with nothing to add" \
        $notes [list $both $both \
                     {{selector it: that point is also R2 pin P, R3 pin M; the click took the current of V1}} {} \
                     {{selector it: the pin test failed (pk boom); read as a click off any pin}} {}]
    # the stand-in's own note: said when the source's current was INSERTED for a
    # pin that is not the source's first node, and only then
    set s2 [dict create kind source name V1 inst V1 pin m place second]
    set s1 [dict create kind source name V1 inst V1 pin p place first]
    set s3 [dict create kind source name E1 inst E1 pin cp place other]
    set s0 [dict create kind source name V1 inst V1 pin m]
    set sb [dict create kind source name V1]
    # ...and the same pin sharing its point with another device's: both are said,
    # the shared point first, when the source's current was inserted, and neither
    # when it was not
    set s2x [dict create kind source name V1 inst V1 pin m place second \
                 also {R7 pin P; the click took the current of V1}]
    set xnotes [list \
        [pcall calc::pick_inotes it $mq [dict create ok 1 name i(v1) path /V1 step $s2x]] \
        [pcall calc::pick_inotes it $mq [dict create ok 0 why unresolved detail i(V1) step $s2x]]]
    set snotes [list \
        [pcall calc::pick_inotes it $mq [dict create ok 1 name i(v1) path /V1 step $s2]] \
        [pcall calc::pick_inotes idc $mq [dict create ok 1 name i(v1) path /V1 step $s2]] \
        [pcall calc::pick_inotes it $mq [dict create ok 1 name i(v1) path /V1 step $s1]] \
        [pcall calc::pick_inotes it $mq [dict create ok 1 name i(v1) path /V1 step $sb]] \
        [pcall calc::pick_inotes it $mq [dict create ok 0 why unresolved detail i(V1) step $s2]] \
        [pcall calc::pick_inotes it $mq [dict create ok 0 why noraw detail i(V1) step $s2]] \
        [pcall calc::pick_inotes it $mq [dict create ok 0 why absent detail i(V1:n2) step $s2]] \
        [pcall calc::pick_inotes it [dict create err {pk boom}] \
             [dict create ok 1 name i(v1) path /V1 step $s2]]]
    set sneg {selector it: V1 pin m: inserted the source's current, the negative of this pin's}
    check "PK13 a source that stood in for its SECOND node says so before the last sentence: the token inserted is the source's current, which is the negative of the current into the pin that was clicked -- under whichever selector armed the pick.  It says NOTHING on the source's first node, where the two are the same number; nothing for a click on the source's body, which names no pin; nothing when the source's current was not inserted, whichever sentence the click ends on -- a name the result does not hold, no data at all, or the terminal's own `absent`; and a pin test that raised is still said first" \
        $snotes [list [list $sneg] \
                      {{selector idc: V1 pin m: inserted the source's current, the negative of this pin's}} \
                      {} {} {} {} {} \
                      [list {selector it: the pin test failed (pk boom); read as a click off any pin} $sneg]]
    # a pin that is NEITHER of the source's first two nodes: a controlling pin of
    # a controlled source, a pin the netlist line does not carry.  The source's
    # current says nothing about the current into such a pin, so the click must
    # not say `negative` there.
    set onotes [list \
        [pcall calc::pick_inotes it $mq [dict create ok 1 name i(e1) path /E1 step $s3]] \
        [pcall calc::pick_inotes idc $mq [dict create ok 1 name i(e1) path /E1 step $s3]] \
        [pcall calc::pick_inotes it $mq [dict create ok 0 why unresolved detail i(E1) step $s3]] \
        [pcall calc::pick_inotes it $mq [dict create ok 1 name i(v1) path /V1 step $s0]] \
        [pcall calc::pick_inotes it $mq [dict create ok 1 name i(v1) path /V1 \
                                             step [dict replace $s2 place sideways]]]]
    set soth {selector it: E1 pin cp: inserted the source's current, which is not this pin's}
    check "PK13 ...and a source that stood in for a pin that is NEITHER of its first two nodes says something else: the token inserted is the source's current and is NOT the current of the pin that was clicked -- not that it is its negative, which for a controlling pin of a controlled source would be a false statement about a current that is zero -- under whichever selector armed the pick, and only when the source's current was inserted.  A step that names a pin and no place, and one whose place is none of the three words, say nothing about the pin" \
        [list $onotes [expr {$soth ne $sneg && ![string match *negative* $soth] ? {neutral} : {SAYSNEGATIVE}}]] \
        [list [list [list $soth] \
                    {{selector idc: E1 pin cp: inserted the source's current, which is not this pin's}} \
                    {} {} {}] neutral]
    check "PK13 ...and on a point the source's OTHER pin shares with another device's pin the click says both before its last sentence, the shared point first and the sign after it, when the source's current was inserted; when it was not -- the result holds neither -- it says neither" \
        $xnotes [list [list {selector it: that point is also R7 pin P; the click took the current of V1} $sneg] {}]
    # --- ONE pin rule and ONE naming rule, shared with Select On Design -----------
    # The three ASE-L procs are replaced by recorders, so what is read back is the
    # CALLS the measure makes and the answers it hands on -- not a comparison of
    # two runs of the same proc, which would agree by construction.
    rename ase::ui::sod_terminal_at pk_real_tat
    rename ase::ui::sod_terminal_resolve pk_real_tres
    rename ase::ui::sod_source_at pk_real_sat
    set ::pk_calls {}
    set ::pk_term {inst 7 pin 2 instname PKI pinname PKP x 1 y 2 others {}}
    proc ase::ui::sod_terminal_at {key x y} {
        lappend ::pk_calls [list at $key $x $y]
        return $::pk_term
    }
    proc ase::ui::sod_terminal_resolve {key term} {
        lappend ::pk_calls [list resolve $key $term]
        return {ok 1 tokens PKTOK:n1 label PKL caution {}}
    }
    proc ase::ui::sod_source_at {hit} {
        lappend ::pk_calls [list source $hit]
        return [expr {[lindex $hit 1] == 7 ? {PKSRC} : {}}]
    }
    set m1 [pcall calc::pick_imeasure PKKEY 12.25 -3.5 {wire 4 1 9}]
    set c1 $::pk_calls
    set ::pk_calls {}
    set ::pk_term {}
    set m2 [pcall calc::pick_imeasure PKKEY 12.25 -3.5 {instance 7 1 9}]
    set c2 $::pk_calls
    proc ase::ui::sod_terminal_at {key x y} { error {pk boom} }
    set m3 [pcall calc::pick_imeasure PKKEY 12.25 -3.5 {instance 7 1 9}]
    rename ase::ui::sod_terminal_at {}
    rename ase::ui::sod_terminal_resolve {}
    rename ase::ui::sod_source_at {}
    rename pk_real_tat ase::ui::sod_terminal_at
    rename pk_real_tres ase::ui::sod_terminal_resolve
    rename pk_real_sat ase::ui::sod_source_at
    check "PK13 the pin rule and the naming rule are ASE-L's, and the measure is where they are called: with the three procs replaced by recorders, a click hands the pin rule the session key and the point AS GIVEN, hands the naming rule that key and the pin rule's own answer, asks the source rule about the PIN's instance and about the object under the cursor, and passes all four answers on unchanged" \
        [list $c1 [pk_fld $m1 term] [pk_fld $m1 res] [pk_fld $m1 tsrc] [pk_fld $m1 src] [pk_fld $m1 err]] \
        [list [list {at PKKEY 12.25 -3.5} \
                    [list resolve PKKEY {inst 7 pin 2 instname PKI pinname PKP x 1 y 2 others {}}] \
                    {source {instance 7}} {source {wire 4 1 9}}] \
              {inst 7 pin 2 instname PKI pinname PKP x 1 y 2 others {}} \
              {ok 1 tokens PKTOK:n1 label PKL caution {}} PKSRC {} {}]
    check "PK13 ...with NO pin under the cursor the naming rule is not asked at all and the click is the source rule on the object there; and a pin test that RAISES is kept as text and read as no pin, so the error cannot escape the canvas binding and let the press through to the editor" \
        [list $c2 [pk_fld $m2 term] [pk_fld $m2 res] [pk_fld $m2 src] \
              [pk_fld $m3 err] [pk_fld $m3 term] [pk_plansum [pcall calc::pick_iplan $m3]]] \
        [list [list {at PKKEY 12.25 -3.5} {source {instance 7 1 9}}] {} {} PKSRC \
              {pk boom} {} {try s:PKSRC}]
    check "PK13 ...and the three recorders were handed back, which the band CHECKS: the product's own procs answer again, the pin rule for a point that is not a number and the source rule for a hit it cannot read" \
        [list [pcall ase::ui::sod_terminal_at __pk_nosession__ x y] \
              [pcall ase::ui::sod_source_at {wire 0 1 1}] \
              [expr {[info procs ::pk_real_tat] eq {} && [info procs ::pk_real_tres] eq {}
                     && [info procs ::pk_real_sat] eq {} ? {restored} : {LEAKED}}]] \
        {{} {} restored}
    # the Calculator re-spells neither rule: no proc of its pick names the engine's
    # pin probe, a cell type, or a piece of the naming rule.  Comment-stripped
    # bodies, the population derived, the count riding.
    set respelt {}
    set npick 0
    foreach p [lsort [info procs ::calc::pick_*]] {
        incr npick
        if {[regexp {pin_at|cell::type|sod_term_name|sod_term_ports|flat_netlist|spiceprefix} \
                 [pk_decomment [info body $p]]]} { lappend respelt $p }
    }
    check "PK13 the Calculator RE-SPELLS neither rule: over every `calc::pick_*` proc, derived from the namespace and comment-stripped, not one names the engine's pin probe, a cell type or a piece of ASE-L's naming rule; the click reaches all of it through the measure, and Select On Design's own click and pick call the same two procs -- so the two gestures cannot disagree about which pin is under the cursor or what its current is called" \
        [list $respelt [pk_atleast $npick 30] \
              [pk_word [regexp {ase::ui::sod_terminal_at} [pk_decomment [pcall info body ::calc::pick_imeasure]]] pinrule MISSING] \
              [pk_word [regexp {ase::ui::sod_terminal_resolve} [pk_decomment [pcall info body ::calc::pick_imeasure]]] naming MISSING] \
              [pk_word [regexp {ase::ui::sod_terminal_at} [pk_decomment [pcall info body ::ase::ui::sod_click]]] sodpin MISSING] \
              [pk_word [regexp {ase::ui::sod_terminal_resolve} [pk_decomment [pcall info body ::ase::ui::sod_terminal_pick]]] sodnaming MISSING]] \
        {{} atleast30 pinrule naming sodpin sodnaming}
    # --- the live half: a sheet with every class ----------------------------------
    set pkscr [test_scratch calcpick]
    set pksch [file join $pkscr ipins.sch]
    set pkfh [open $pksch w]
    puts $pkfh "v {xschem version=3.4.8RC file_version=1.3}"
    foreach k {G K V S F E} { puts $pkfh "$k {}" }
    puts $pkfh {N 600 -100 600 -30 {}}
    puts $pkfh {C {vsource.sym} 0 0 0 0 {name=V1 value=1}}
    puts $pkfh {C {ammeter.sym} 200 0 0 0 {name=Vam}}
    puts $pkfh {C {nmos4.sym} 400 0 0 0 {name=M1 model=nmos w=5u l=0.18u del=0 m=1}}
    puts $pkfh {C {res.sym} 600 0 0 0 {name=R9 value=1k m=1}}
    puts $pkfh {C {lab_pin.sym} 600 -100 0 0 {name=l1 sig_type=std_logic lab=out}}
    puts $pkfh {C {res.sym} 1000 0 0 0 {name=Ra value=1k m=1}}
    puts $pkfh {C {res.sym} 1000 60 0 0 {name=Rb value=1k m=1}}
    puts $pkfh {C {res.sym} 1400 0 0 0 {name=Rbus[1:0] value=1k m=1}}
    puts $pkfh {C {nmos4.sym} 1800 0 0 0 {name=XM1 model=nfet_wrap w=5u l=0.18u del=0 m=1}}
    close $pkfh
    check "PK13 fixture: the sheet loads with its nine instances and one wire, the wire ENDS on R9's upper pin, and Ra's lower pin and Rb's upper pin are one point -- read back from the pins, so the rows below are about the classes their names say" \
        [list [expr {[pcall xschem load $pksch] ne {} ? 1 : 0}] \
              [pk_sized [llength [pcall xschem objects -type instance]] 9] \
              [pk_sized [llength [pcall xschem objects -type wire]] 1] \
              [lindex [pcall xschem object_at {*}[pk_pin R9 P]] 0] \
              [expr {[pk_pin Ra M] eq [pk_pin Rb P] ? {onepoint} : {APART}}]] \
        {1 n9 n1 wire onepoint}
    check "PK13 fixture: the key of these rows is NO session -- its design does not resolve and its base level is the window's top -- and a real pick is never there: the arm refuses such a token for a current id exactly as for a voltage one" \
        [list [pcall ase::ui::design_path __pk_nosession__] \
              [pcall ase::ui::sod_base_level __pk_nosession__] \
              [pk_fld [pcall calc::pick_decide it [dict create ok 1 token __pk_nosession__]] act] \
              [pk_fld [pcall calc::pick_decide it [dict create ok 1 token __pk_nosession__]] msg]] \
        [list {} 0 refuse {selector it: cannot resolve this result's design cellview}]
    # the body point of M1: midway between two of its own pins, 20 units from each
    set mg [pk_pin M1 g] ; set mb [pk_pin M1 b]
    set mbody [list [expr {([lindex $mg 0] + [lindex $mb 0]) / 2.0}] \
                    [expr {([lindex $mg 1] + [lindex $mb 1]) / 2.0}]]
    set wmid [pk_mid 0]
    check "PK13 on real geometry, each point read off the object it belongs to: a MOSFET's pin and a resistor's pin a wire ends on are terminals; the pin of a voltage source and of an ammeter is its terminal with the source's own current behind it, while the BODY of either is the source alone; a MOSFET's body, a wire off any pin, and the pin of a net label -- which is no device -- have no current; empty canvas is nothing" \
        [list [pk_plansum [pk_tplan {*}[pk_pin M1 d]]] \
              [pk_plansum [pk_tplan {*}[pk_pin R9 P]]] \
              [pk_plansum [pk_tplan {*}[pk_pin V1 p]]] \
              [pk_plansum [pk_tplan {*}[pk_pin Vam plus]]] \
              [pk_plansum [pk_tplan {*}[pk_bbox_mid [pk_inst V1]]]] \
              [pk_plansum [pk_tplan {*}[pk_bbox_mid [pk_inst Vam]]]] \
              [pk_plansum [pk_tplan {*}$mbody]] \
              [pk_plansum [pk_tplan {*}$wmid]] \
              [pk_plansum [pk_tplan {*}[pk_pin l1 p]]] \
              [pk_plansum [pk_tplan 9999 9999]]] \
        [list {try t:M1:d} {try t:R9:n1} {try {t:V1:n1 s:V1}} {try {t:Vam:n1 s:Vam}} \
              {try s:V1} {try s:Vam} {refuse notsource {}} {refuse notsource {}} \
              {refuse notsource {}} {refuse inothing {}}]
    check "PK13 fixture for the row above: those points stand where it says -- the MOSFET's body point and the wire's midpoint are on no device pin by ASE-L's own rule, while `xschem object_at` really is the instance at the one and the wire at the other" \
        [list [pcall ase::ui::sod_terminal_at __pk_nosession__ {*}$mbody] \
              [lindex [pcall xschem object_at {*}$mbody] 0] \
              [pcall ase::ui::sod_terminal_at __pk_nosession__ {*}$wmid] \
              [lindex [pcall xschem object_at {*}$wmid] 0]] \
        {{} instance {} wire}
    set shared [pk_tplan {*}[pk_pin Ra M]]
    set sst [lindex [pk_fld $shared steps] 0]
    check "PK13 where two devices have a pin on ONE point the click takes one and its step names the other, and a pin that is SEVERAL vectors -- an instance named as a bus -- is refused listing them, because the buffer takes one token per click and a pick has no bit dialog (K4)" \
        [list [pk_plansum $shared] [pk_fld $sst inst] [pk_fld $sst also] \
              [pk_plansum [pk_tplan {*}[pk_pin {Rbus[1:0]} P]]] \
              [pcall calc::pick_msg bus it {Rbus[1]:n1, Rbus[0]:n1}]] \
        [list {try t:Ra:n2} Ra {Rb pin P; the click took Ra pin M} \
              {refuse bus {Rbus[1]:n1, Rbus[0]:n1}} \
              {selector it: Rbus[1]:n1, Rbus[0]:n1 is a bus; pick one bit}]
    # --- K3 on the committed results ------------------------------------------------
    check "PK13 fixture: the committed transient result with terminal vectors was located and reads as `tran`, and its inventory spells the terminals with the reader's dot -- the file's own colon is not what `xschem raw list` shows" \
        [list [expr {[pk_probe_raw tran] ne {} ? 1 : 0}] [pk_readp tran] \
              [pk_in [pk_inventory] i(r9.n1)] [pk_in [pk_inventory] i(x1.xm1.d)] \
              [pk_in [pk_inventory] i(r9:n1)]] \
        {1 1 has has missing:i(r9:n1)}
    # ⚠ THE DESCENDED PICK IS DRIVEN THROUGH A STUBBED `sod_rel_path`, as band PK5
    # drives the Cadence path and for PK5's reason: where the relative path comes
    # from is ASE-L's, and what is measured here is that the naming rule's token
    # and this file's status path both take it.  The device is a REAL instance,
    # `XM1`, whose netlist line is a subcircuit call, so the token is the naming
    # rule's own answer -- and with no `.subckt` header in hand it comes with that
    # rule's caution.
    rename ase::ui::sod_rel_path pk_real_relpath13
    proc ase::ui::sod_rel_path {baselvl} { return x1. }
    set hplan [pk_tplan {*}[pk_pin XM1 d]]
    set hres [pcall calc::pick_iresolve [pk_fld $hplan steps] 0 calc::pick_lookup_in tran]
    rename ase::ui::sod_rel_path {}
    rename pk_real_relpath13 ase::ui::sod_rel_path
    check "PK13 R204/R207 for a TERMINAL the result holds: a click on R9's pin resolves and inserts the raw's own spelling with the selector's id, `it(r9.n1)`; and a pick one level DOWN, on the drain of the instance XM1, is the naming rule's token `x1.XM1:d` in the schematic's case, comes back as the inventory's own row at that index and inserts `it(x1.xm1.d)`.  The path on the status line is the instance's, a colon and the pin as the symbol spells it" \
        [list [pk_tclick it {*}[pk_pin R9 P]] [pk_plansum $hplan] \
              [pk_fld $hres ok] [pk_fld $hres name] \
              [lindex [pk_inventory] [pcall xschem raw index i(x1.XM1:d)]] \
              [pcall calc::aq_qualify it [pk_fld $hres name]] [pk_fld $hres path]] \
        [list {insert it(r9.n1) /R9:P terminal} {try t:x1.XM1:d} \
              1 i(x1.xm1.d) i(x1.xm1.d) it(x1.xm1.d) /x1/XM1:d]
    set hnotes [pcall calc::pick_inotes it [dict create err {}] $hres]
    check "PK13 ...and that pick carries the naming rule's CAUTION, live: the port of a subcircuit call was named from the symbol's pin for want of a header, so the click says so before its last sentence, naming the instance and the pin; the stub was handed back" \
        [list [pk_sized [llength $hnotes] 1] \
              [pk_word [string match {selector it: caution, XM1 pin d: no .subckt header for 'nfet_wrap' is known*} \
                            [lindex $hnotes 0]] cautioned [lindex $hnotes 0]] \
              [pcall ase::ui::sod_rel_path 0] \
              [expr {[info procs ::pk_real_relpath13] eq {} ? {restored} : {LEAKED}}]] \
        [list n1 cautioned {} restored]
    # what was inserted READS the column the pin named: the Calculator's own
    # evaluator against the raw reader's last sample, two different doors
    set rawp [pk_probe_raw tran]
    set vd [pk_fld [pcall calc::eval_text it(x1.xm1.d) $rawp {}] value]
    set vc [pk_fld [pcall calc::eval_text it(x1.xm1:d) $rawp {}] value]
    set vr [pk_fld [pcall calc::eval_text it(r9.n1) $rawp {}] value]
    pk_readp tran
    set rd [lindex [pcall xschem raw values i(x1.xm1.d) 0] end]
    set rr [lindex [pcall xschem raw values i(r9.n1) 0] end]
    check "PK13 ...and the inserted token EVALUATES to the column the pin named: `it(x1.xm1.d)` reads the same number as the raw reader's own last sample of that column, the file's colon spelling typed by hand reads it too, and the resistor's terminal reads its own column -- two columns that are clearly apart, so a token reading the wrong one cannot pass" \
        [list [pk_same $vd $rd] [pk_same $vc $rd] [pk_same $vr $rr] [pk_apart $rd $rr]] \
        {same same same apart}
    check "PK13 DECLARED, and measured so it cannot go stale quietly: the token the pick inserts spells the terminal as the reader STORES it, with a dot, while ASE-L's own predicate for a terminal-current row knows only the file's colon spelling -- so the inserted token is for the Calculator; pasted into an ASE-L Outputs row it would not be asked of the next deck as a probe" \
        [list [pcall ase::probe_split i(x1.xm1.d)] [pcall ase::probe_split i(x1.xm1:d)] \
              [pcall calc::aq_strip [pcall calc::aq_qualify it [pk_fld $hres name]]] \
              [pcall ase::probe_split [pcall calc::aq_strip [pcall calc::aq_qualify it [pk_fld $hres name]]]]] \
        [list {} {x1.xm1 d} i(x1.xm1.d) {}]
    check "PK13 a terminal the result does NOT hold inserts nothing and takes its own sentence, which says where to ask for it -- the generic one would send the user hunting for a typo in a name that is right.  The place it names is ASE-L's Outputs menu and its To Be Plotted cascade, in the menu's own words: a pin picked there is saved AND plotted, and it is the plot after the run that loads the new results into the viewer this window reads" \
        [list [pk_tclick it {*}[pk_pin M1 d]] \
              [pcall calc::pick_msg absent it i(M1:d)]] \
        [list {refuse absent i(M1:d)} \
              {selector it: i(M1:d) is not in this result; ASE-L Outputs: To Be Plotted, rerun}]
    check "PK13 K2b: the PIN of a voltage source whose terminal this result does not hold falls back to the source's own current, which it does hold -- the same token and path a click on the BODY gives, and the step taken says it was the source; an ammeter's pin with NEITHER vector in the result is refused as its source is, naming the branch current" \
        [list [pk_tclick it {*}[pk_pin V1 p]] \
              [pk_tclick it {*}[pk_bbox_mid [pk_inst V1]]] \
              [pk_tclick it {*}[pk_pin Vam plus]] \
              [pcall xschem raw index i(V1:n1)] [pcall xschem raw index i(V1)]] \
        [list {insert it(v1) /V1 source} {insert it(v1) /V1 source} \
              {refuse unresolved i(Vam)} -1 [lsearch -exact [pk_inventory] i(v1)]]
    # the source's LOWER pin, live: the naming rule calls it the second terminal,
    # this result holds neither terminal of V1, so the source stands in on both
    # pins -- and only on the lower one is that the negative of the pin's own
    check "PK13 ...and on the source's OTHER pin the same stand-in is the negative of that pin's own current, which the click says before its last sentence, naming the pin: on real geometry the naming rule's token for V1's lower pin is its second terminal, the click inserts the source's token as on the upper pin, and the note is there for the lower pin alone -- none for the upper pin, none for the body, and none for the ammeter's lower pin, where nothing was inserted" \
        [list [pk_plansum [pk_tplan {*}[pk_pin V1 m]]] \
              [pk_tclick it {*}[pk_pin V1 m]] \
              [pk_tnotes it {*}[pk_pin V1 m]] \
              [pk_tnotes it {*}[pk_pin V1 p]] \
              [pk_tnotes it {*}[pk_bbox_mid [pk_inst V1]]] \
              [pk_tclick it {*}[pk_pin Vam minus]] \
              [pk_tnotes it {*}[pk_pin Vam minus]]] \
        [list {try {t:V1:n2 s:V1}} {insert it(v1) /V1 source} \
              {{selector it: V1 pin m: inserted the source's current, the negative of this pin's}} \
              {} {} {refuse unresolved i(Vam)} {}]
    check "PK13 the same pick under `idc` reads the OPERATING POINT result: the committed op file reads as `op` and R9's pin inserts `idc(r9.n1)`" \
        [list [pk_readp op] [pk_tclick idc {*}[pk_pin R9 P]]] \
        [list 1 {insert idc(r9.n1) /R9:P terminal}]
    # --- K2 with a result that HOLDS a source's terminal ---------------------------
    set praw [file join $pkscr vterm.raw]
    set fh [open $praw w]
    puts $fh "Title: pk13\nDate: pk13\nPlotname: Transient Analysis\nFlags: real"
    puts $fh "No. Variables: 4\nNo. Points: 2\nVariables:"
    puts $fh "\t0\ttime\ttime\n\t1\tv(n1)\tvoltage\n\t2\ti(v1)\tcurrent\n\t3\ti(v1:n1)\tcurrent"
    puts $fh "Values:\n 0\t0.0\n\t1.0\n\t-1e-3\n\t2e-3\n\n 1\t1e-6\n\t1.5\n\t-1.5e-3\n\t2.5e-3\n"
    close $fh
    pcall xschem raw clear
    set rdv [pcall xschem raw read $praw tran]
    check "PK13 K2: with a result that holds BOTH, the PIN of a voltage source is its terminal and its BODY the branch current -- two different tokens from two clicks on one device, terminal first as Select On Design orders them" \
        [list $rdv [pk_tclick it {*}[pk_pin V1 p]] [pk_tclick it {*}[pk_bbox_mid [pk_inst V1]]]] \
        [list 1 {insert it(v1.n1) /V1:p terminal} {insert it(v1) /V1 source}]
    # ...and a result that holds the LOWER pin's own current too: a second small
    # file, so the one above stays as the rows before this one read it
    set praw2 [file join $pkscr vterm2.raw]
    set fh [open $praw2 w]
    puts $fh "Title: pk13b\nDate: pk13b\nPlotname: Transient Analysis\nFlags: real"
    puts $fh "No. Variables: 4\nNo. Points: 2\nVariables:"
    puts $fh "\t0\ttime\ttime\n\t1\ti(v1)\tcurrent\n\t2\ti(v1:n1)\tcurrent\n\t3\ti(v1:n2)\tcurrent"
    puts $fh "Values:\n 0\t0.0\n\t-1e-3\n\t-1e-3\n\t1e-3\n\n 1\t1e-6\n\t-1.5e-3\n\t-1.5e-3\n\t1.5e-3\n"
    close $fh
    pcall xschem raw clear
    set rdv2 [pcall xschem raw read $praw2 tran]
    check "PK13 ...and once the result holds the lower pin's OWN current, the same click on that pin inserts the terminal and says nothing about a sign: the note belongs to the stand-in and goes when the stand-in does" \
        [list $rdv2 [pk_tclick it {*}[pk_pin V1 m]] [pk_tnotes it {*}[pk_pin V1 m]]] \
        [list 1 {insert it(v1.n2) /V1:m terminal} {}]
    # --- the lookups: order, case, and the failures that are not about the name ----
    set vsteps [pk_fld [pk_tplan {*}[pk_pin V1 p]] steps]
    set ::pk_lk {}
    set rec [pcall calc::pick_iresolve $vsteps 0 \
                 [list apply {{c a} { lappend ::pk_lk [list $c $a] ; return {ok 0 why unresolved name {}} }}] tran]
    check "PK13 the candidates are looked up IN ORDER, each as `i(<token>)` with the token's CASE KEPT -- the result decides the spelling, through the read-back -- and in the analysis the selector names: the lookup command is handed the terminal first, then the source, and when neither is held the sentence is the LAST step's" \
        [list $::pk_lk [pk_fld $rec why] [pk_fld $rec detail]] \
        [list {{i(V1:n1) tran} {i(V1) tran}} unresolved i(V1)]
    set ::pk_lk {}
    set skp [pcall calc::pick_iresolve \
                 [list [dict create kind terminal token {} inst X pin p also {} caution {}] \
                       [dict create kind __pk_nokind__ name V1] \
                       [dict create kind source name {}] \
                       [dict create kind source name V1]] 0 \
                 [list apply {{c a} { lappend ::pk_lk $c ; return [calc::pick_lookup_in $c $a] }}] tran]
    check "PK13 a step that names NOTHING is passed over and never looked up as an empty wrapper: an empty token, a kind the lookups do not know and an empty source name each cost no lookup at all, and the one real step behind them is still answered -- against the result this band has loaded, which holds that source's current" \
        [list $::pk_lk [pk_fld $skp ok] [pk_fld $skp name] [pk_fld [pk_fld $skp step] name]] \
        [list i(V1) 1 i(v1) V1]
    pcall xschem raw clear
    set nor [pcall calc::pick_iresolve $vsteps 0 calc::pick_lookup_in tran]
    set bzy [pcall calc::pick_iresolve $vsteps 0 [list error {pk lookup boom}] tran]
    check "PK13 a lookup that fails for a reason that is NOT the name ends the click there and does NOT fall back to the source: with nothing loaded the answer is `noraw` at the terminal step, and a lookup that raises is `busyview` -- a retry is the answer to both, and inserting the source's current instead would be a guess" \
        [list [pk_fld $nor why] [pk_fld [pk_fld $nor step] kind] \
              [pk_fld $bzy why] [pk_fld [pk_fld $bzy step] kind] \
              [pk_fld [pcall calc::pick_iresolve {} 0 calc::pick_lookup_in tran] why]] \
        {noraw terminal busyview terminal noname}
    # --- a pin the naming rule refuses, live ----------------------------------------
    set pkflat {}
    catch {set pkflat $::flat_netlist}
    set ::flat_netlist 1
    set fm [pk_tplan {*}[pk_pin M1 d]]
    set fv [pk_tplan {*}[pk_pin V1 p]]
    set ::flat_netlist $pkflat
    check "PK13 a pin ASE-L's naming rule REFUSES is refused here with that rule's own reason: under flat netlisting a MOSFET's pin cannot be named, and the sentence says which pin, why, and the way that always works; a voltage source's pin there is the source pick it was before pins were picked.  The switch is put back, which the row reads" \
        [list [pk_plansum $fm] [pk_plansum $fv] \
              [pcall calc::pick_msg noterm it [pk_fld $fm detail]] \
              [expr {$::flat_netlist eq $pkflat ? {restored} : {LEFTON}}] \
              [pk_plansum [pk_tplan {*}[pk_pin M1 d]]]] \
        [list {refuse noterm {M1 pin d: flat netlisting renames every device}} {try s:V1} \
              {selector it: cannot name the current of M1 pin d: flat netlisting renames every device; use an ammeter in series} \
              restored {try t:M1:d}]
    # --- a source with pins that are neither of its first two nodes ---------------
    # Two stock symbols of the source class, on a sheet of their own, loaded last
    # so every row above reads the sheet it was written for: `vsource_pwl.sym`,
    # a controlled source whose netlist line carries four pins, the third and
    # the fourth its controlling nodes, behind a token that is no node; and
    # `filesource.sym`, whose netlist line carries its first pin alone.  The
    # result holds the branch current of each and no terminal, so the source's
    # current stands in on every pin.
    set pksch2 [file join $pkscr isrc.sch]
    set pkfh [open $pksch2 w]
    puts $pkfh "v {xschem version=3.4.8RC file_version=1.3}"
    foreach k {G K V S F E} { puts $pkfh "$k {}" }
    puts $pkfh {C {vsource_pwl.sym} 0 0 0 0 {name=E1}}
    puts $pkfh {C {filesource.sym} 400 0 0 0 {name=A1}}
    close $pkfh
    set praw3 [file join $pkscr esrc.raw]
    set fh [open $praw3 w]
    puts $fh "Title: pk13c\nDate: pk13c\nPlotname: Transient Analysis\nFlags: real"
    puts $fh "No. Variables: 3\nNo. Points: 2\nVariables:"
    puts $fh "\t0\ttime\ttime\n\t1\ti(e1)\tcurrent\n\t2\ti(a1)\tcurrent"
    puts $fh "Values:\n 0\t0.0\n\t-3e-3\n\t-1e-3\n\n 1\t1e-6\n\t-3e-3\n\t-1e-3\n"
    close $fh
    set ld2 [expr {[pcall xschem load $pksch2] ne {} ? 1 : 0}]
    pcall xschem raw clear
    set rdv3 [pcall xschem raw read $praw3 tran]
    set eplace {} ; set eclick {} ; set enotes {}
    foreach {inm ipn} {E1 p E1 m E1 cp E1 cm A1 m} {
        set ept [pk_pin $inm $ipn]
        lappend eplace [pk_fld [lindex [pk_fld [pk_tplan {*}$ept] steps] end] place]
        lappend eclick [pk_tclick it {*}$ept]
        lappend enotes [pk_tnotes it {*}$ept]
    }
    set eins {insert it(e1) /E1 source}
    set ains {insert it(a1) /A1 source}
    check "PK13 a source whose pin is NEITHER of its first two nodes, on real geometry: on the stock controlled source E1 the plan's source step calls the output pins the first and the second node and BOTH controlling pins `other`, and on the stock file source A1, whose netlist line does not carry its lower pin, that pin is `other` too.  A click on any of the five pins inserts that source's own current, which this result holds.  The click then says nothing on E1's first node, says the token is the NEGATIVE of the pin's own on its second node, and on the two controlling pins and on A1's lower pin says the token is the source's current and is not that pin's -- the current into a controlling node is zero, so `negative` there would be a false statement" \
        [list $ld2 [pk_sized [llength [pcall xschem objects -type instance]] 2] $rdv3 \
              $eplace $eclick $enotes] \
        [list 1 n2 1 {first second other other other} \
              [list $eins $eins $eins $eins $ains] \
              [list {} \
                    {{selector it: E1 pin m: inserted the source's current, the negative of this pin's}} \
                    {{selector it: E1 pin cp: inserted the source's current, which is not this pin's}} \
                    {{selector it: E1 pin cm: inserted the source's current, which is not this pin's}} \
                    {{selector it: A1 pin m: inserted the source's current, which is not this pin's}}]]
    pcall xschem raw clear
    test_scratch_drop $pkscr
}

# ===========================================================================
# PK5 — THE CADENCE PATH (R208's status half)
# ===========================================================================
# The buffer gets `v(x1.x2.net5)` and the status line gets `/X1/X2/net5`: the
# user's ruling, and the only reason the Cadence spelling appears at all.  It is
# never inserted and never looked up, so the cost of getting it wrong is cosmetic
# -- but it sits beside a name that IS evaluated, so it must not be able to
# disagree with it about where the design starts.  Both halves take the same
# `$baselvl`, which is what this band pins.
group PK5 {
    check "PK5 at a session's own top level there is no path to add, so the Cadence spelling is just a leading slash and the net name -- measured through `ase::ui::sod_rel_path`, which answers empty there" \
        [list [pcall ase::ui::sod_rel_path 0] [pcall calc::pick_cadence net5 0] \
              [pcall calc::pick_cadence A 0]] \
        [list {} /net5 /A]
    check "PK5 an UNLABELLED net's leading `#` is stripped from the Cadence path, exactly as `ase::ui::sod_expr` strips it from the vector name -- it is xschem's marker for an unnamed net and not part of the net's identity, and leaving it in put `/#net1` on the status line beside a buffer holding `v(net1)`: two spellings of one net, side by side, which is the disagreement this sentence exists to prevent" \
        [list [pcall calc::pick_cadence #net1 0] \
              [pk_fld [pcall calc::pick_name #net1 0] cand]] \
        [list /net1 v(net1)]
    # ⚠ THE DESCENDED CASE IS DRIVEN THROUGH A STUBBED `sod_rel_path`, NOT
    # THROUGH A HIERARCHY FIXTURE, AND THE REASON IS SCOPE: what this proc owns
    # is the `.` -> `/` mapping and the slash discipline.  WHERE the path comes
    # from is `ase::ui::sod_rel_path`'s job, fenced by ASE's own suites and
    # anchored live by the row above.  The stub supplies the input; it does not
    # share the mapping, so it cannot agree with a bug in it.
    rename ase::ui::sod_rel_path pk_real_relpath
    proc ase::ui::sod_rel_path {baselvl} { return x1.x2. }
    set desc [pcall calc::pick_cadence net5 0]
    set leaf [pcall calc::pick_cadence a.b 0]
    rename ase::ui::sod_rel_path {}
    rename pk_real_relpath ase::ui::sod_rel_path
    check "PK5 a descended pick renders xschem's own dotted `sch_path` as Cadence's slashed one, with exactly one separator between segments and no trailing or doubled slash -- and the restore really put the product's proc back, which the row checks rather than assumes" \
        [list $desc [pcall ase::ui::sod_rel_path 0]] [list /x1/x2/net5 {}]
    # ⚠ THIS ROW REDDENED ON ITS FIRST RUN AND THE SOURCE COMMENT WAS THE DEFECT,
    # NOT THE CODE.  `calc::pick_cadence`'s header claimed a leaf net containing a
    # dot "renders one level deeper than it is", declared as a limit -- and it does
    # not: only the PATH is mapped, never the token, so `a.b` keeps its dot.  The
    # row now asserts the behaviour; the paragraph that was wrong is gone.
    check "PK5 only the PATH is mapped and never the TOKEN, which is the difference between this and the obvious one-liner: a leaf net whose own name contains a dot KEEPS it, because mapping the whole string would render that net one level deeper than it is and nothing in a token distinguishes the two" \
        $leaf /x1/x2/a.b
}

# ===========================================================================
# PK6 — EVERY SENTENCE, THE ARM SET DERIVED FROM THE BUILDER'S OWN `switch`
# ===========================================================================
# ⚠ THIS IS ALSO THE BEHAVIOURAL CONFIRMATION OF THE `switch`-COMMENT PARITY
# TRAP, which no structural check can see.  A comment between two patterns leaves
# the braces balanced and `info complete` answering 1, and Tcl then raises *"extra
# switch pattern with no body"* out of EVERY arm -- but ONLY when the comment's
# word count is odd, because the trailing argument is parsed as a list and an even
# count re-pairs harmlessly.  So a green run proves the word count, never the
# safety, and the only instrument is calling every arm.  Diagnose this class on
# THIS arm: the display arm's symptom is a 200 s TIMEOUT with zero FAIL lines.
#
# ⚠ AND THE ARM SET IS DERIVED FROM THE PROC, not kept here.  A hand-kept list is
# the same defect one level up: `test_calc_wave_dest`'s equivalent row drove 24
# message kinds against a proc that had 31 arms and stayed green for a stage.
group PK6 {
    set arms [pk_arms pick_msg]
    set bad {} ; set empty {} ; set over {}
    foreach k $arms {
        set s [pcall calc::pick_msg $k vt {a detail}]
        if {[string match ERR:* $s]} { lappend bad "$k:$s" ; continue }
        if {$s eq {}} { lappend empty $k ; continue }
        if {[string length $s] > [pcall calc::status_chars]} { lappend over "$k:[string length $s]" }
    }
    check "PK6 EVERY arm of `calc::pick_msg` composes a sentence and NOT ONE of them raises -- the arm set derived from the proc's own `switch` patterns, so an arm added later is swept with no edit here.  This is the only instrument that can see a comment placed between two patterns, which balances the braces, satisfies `info complete`, and raises out of every arm at odd word counts" \
        [list $bad $empty] {{} {}}
    check "PK6 ...and the sweep is NOT VACUOUS: the arm set clears a floor, holds the arms this stage's refusals actually name, and does NOT hold an invented one -- so an empty failure list above is an empty population only if this row reddens too" \
        [list [pk_atleast [llength $arms] 15] \
              [pk_in $arms armed] [pk_in $arms terminal] [pk_in $arms bus] \
              [pk_in $arms unresolved] [pk_in $arms noraw] [pk_in $arms cancelled] \
              [pk_in $arms prompt] [pk_in $arms iarmed] [pk_in $arms iprompt] \
              [pk_in $arms inothing] [pk_in $arms notsource] \
              [pk_in $arms noterm] [pk_in $arms absent] [pk_in $arms also] \
              [pk_in $arms caution] [pk_in $arms pinerr] [pk_in $arms srcneg] \
              [pk_in $arms srcother] \
              [pk_in $arms __pk_no_such_arm__]] \
        {atleast15 has has has has has has has has has has has has has has has has has has missing:__pk_no_such_arm__}
    check "PK6 an UNKNOWN kind answers the empty string rather than raising, which is what keeps a wiring mistake from taking a band out through `group`'s catch" \
        [list [pcall calc::pick_msg __pk_no_such_arm__ vt] [pcall calc::pick_msg {} vt]] {{} {}}
    check "PK6 every sentence fits the status line WITHOUT the fitter having to elide it, which is a stronger claim than `status_fit` can rescue it and is the one this band can make because these sentences are short by construction" \
        $over {}
    check "PK6 the two sentences this phase REUSES are passed through VERBATIM and are not re-spelled here: `calc::no_result_advice` is U7's RULED wording and `calc::busy_msg` is the context-refusal one, and both are longer than the room -- pre-existing issue 0517, NOT fixed here, and the reason a row about them must read `calc::status_history` and never the widget" \
        [list [pk_word [regexp {No simulation results|no viewer} [pcall calc::no_result_advice]] shaped UNEXPECTED] \
              [pk_word [expr {[string length [pcall calc::no_result_advice]] > [pcall calc::status_chars]}] overflows fits] \
              [pk_word [expr {[string length [pcall calc::busy_msg]] > [pcall calc::status_chars]}] overflows fits] \
              [pk_in [pk_arms pick_msg] no_result]] \
        {shaped overflows overflows missing:no_result}
    # ⚠ THE NON-VACUITY LEG HERE IS NOT "THE STRIP REMOVED SOMETHING", AND THE
    # FIRST VERSION OF THIS ROW ASSERTED BOTH AND CONTRADICTED ITSELF.  The claim
    # is that the builder's body carries NO comment, so a correct strip removes
    # NOTHING from it -- and the stripper is shown to work by running it on a
    # sibling that DOES carry comments.  Asserting both of "no comments" and "the
    # strip changed the text" is unsatisfiable, and it reddened on first run.
    set raw  [pcall info body ::calc::pick_msg]
    set body [pk_decomment $raw]
    # ⚠ THE SIBLING HAD TO BE A SHIPPED PROC, NOT ONE OF THIS PHASE'S: every proc
    # this stage wrote keeps its prose ABOVE itself, so `pick_click`'s body is
    # comment-free too and the first spelling of this leg answered
    # NOTHINGSTRIPPED.  `calc::require_result` carries an inline `# R503f:` note.
    set craw [pcall info body ::calc::require_result]
    check "PK6 the builder's body carries NO comment at all, which is the only arrangement under which the parity trap is not expressible -- so the comment strip leaves it BYTE-IDENTICAL, and the stripper is shown to be working by taking real text out of a SHIPPED sibling that does carry an inline comment" \
        [list [regexp -all -line {^[ \t]*#} $body] \
              [expr {$body eq $raw ? {identical} : {CHANGED}}] \
              [expr {[string length $raw] > 500 ? 1 : "short:[string length $raw]"}] \
              [expr {[string length [pk_decomment $craw]] < [string length $craw] ? {stripped} : {NOTHINGSTRIPPED}}]] \
        {0 identical 1 stripped}
}

# ===========================================================================
# PK7 — THE FITTER, ON THE CHARACTER ARM
# ===========================================================================
# ⚠ THE REFUTATION LEG IS THE POINT OF THIS BAND.  `calc::status_fit` elides the
# MIDDLE of whatever it is given, head-weighted 3/5 -- and the vector NAME is in
# the head, so a long path makes it cut the name in half and leave something that
# still reads like a vector name beside a buffer holding a different one.  That is
# a plausible wrong answer on screen, which is worse than a truncated one.  So the
# row drives the same inputs through BOTH and asserts that the shipped fitter keeps
# the name in every case AND that the general one loses it in at least one -- the
# second half re-measured every run, so the comparison cannot go vacuous if
# `status_fit` is ever changed.
group PK7 {
    set shapes [list \
        [list v(a) /a] \
        [list v(x1.x2.net5) /X1/X2/net5] \
        [list v(x1.x2.x3.x4.longish_internal_node) /X1/X2/X3/X4/longish_internal_node] \
        [list v(tb1.xdut.xbias.xmirror.xcascode.vref_internal) \
              /TB1/XDUT/XBIAS/XMIRROR/XCASCODE/vref_internal] \
        [list v(tb1.xdut.xbias.xmirror.xcascode.xdeep.xdeeper.xdeepest.vref_internal_node) \
              /TB1/XDUT/XBIAS/XMIRROR/XCASCODE/XDEEP/XDEEPER/XDEEPEST/vref_internal_node]]
    set room [pcall calc::status_chars]
    set lost {} ; set oversize {} ; set sflost 0
    foreach sh $shapes {
        set nm [lindex $sh 0] ; set pa [lindex $sh 1]
        set f [pcall calc::pick_fit vt $nm $pa]
        if {[string length $f] > $room} { lappend oversize "[string length $f]/$room" }
        if {[string first $nm $f] < 0} { lappend lost $nm }
        set g [pcall calc::status_fit "selector vt: $nm from $pa"]
        if {[string first $nm $g] < 0} { incr sflost }
    }
    check "PK7 `calc::pick_fit` keeps the VECTOR NAME intact at every path depth and never exceeds the room: the ladder elides the PATH, then drops the ` from <path>` clause entirely, and only then gives up -- the name is never the part that goes, because it is the half the user checks against the buffer" \
        [list $lost $oversize [pk_sized [llength $shapes] 5]] {{} {} n5}
    check "PK7 THE REFUTATION, re-measured every run so this band cannot go vacuous: driving the SAME inputs through the general `calc::status_fit` loses the vector name in at least one of them, which is why this phase has a fitter of its own rather than reusing that one" \
        [pk_word [expr {$sflost > 0}] loses keeps] loses
    check "PK7 fixture: this is the CHARACTER arm, so every figure in this band is a measurement of the DECISION and not of a display -- the pixel arm is a display row's subject and nothing here may assert one" \
        [list [lindex [pcall calc::status_room] 0] [pk_atleast $room 40]] {ch atleast40}
    check "PK7 a sentence already inside the room comes back BYTE-IDENTICAL and carries no elision marker, so a reader can tell a fitted sentence from an unfitted one" \
        [list [pcall calc::pick_fit vt v(a) /a] \
              [pk_word [expr {[string first [pcall calc::status_marker] \
                                   [pcall calc::pick_fit vt v(a) /a]] >= 0}] MARKED clean]] \
        [list {selector vt: v(a) from /a} clean]
}

# ===========================================================================
# PK8 — THE ARM-TIME DECISION
# ===========================================================================
# `calc::pick_decide` takes `calc::require_result`'s dict as an ARGUMENT, which is
# the whole reason every refusal is drivable here with no ASE session, no viewer
# and no window.  The stage-J1 lesson applied in advance: the DECISION is a pure
# proc so it gates on the counted arm, and the ACT -- the window really being
# focused, the canvas really being seized -- is declared where only a display can
# see it.
group PK8 {
    set none [pcall calc::pick_decide vt \
                  [dict create ok 0 origin none msg [pcall calc::no_result_advice]]]
    set busy [pcall calc::pick_decide vt \
                  [dict create ok 0 origin refused msg [pcall calc::busy_msg]]]
    check "PK8 with nothing to pick against, the refusal is U7's RULED sentence passed through UNCHANGED and not a second spelling of it -- compared against `calc::no_result_advice`'s own return value, so the two cannot drift" \
        [list [pk_fld $none act] [pk_fld $none token] \
              [expr {[pk_fld $none msg] eq [pcall calc::no_result_advice] ? {verbatim} : {DIFFERENT}}]] \
        {refuse {} verbatim}
    check "PK8 a REFUSED viewer context is reported as busy with `calc::busy_msg`'s own words, which is the distinction issue 0173's loan makes and the one a user needs: a refused context switch is not an empty result list" \
        [list [pk_fld $busy act] \
              [expr {[pk_fld $busy msg] eq [pcall calc::busy_msg] ? {verbatim} : {DIFFERENT}}]] \
        {refuse verbatim}
    check "PK8 a dict with `ok` present but no `msg` still refuses with the ruled sentence rather than an empty status line, so a caller that hands over a short dict cannot produce a silent arm (R506: silence is a bug)" \
        [list [pk_fld [pcall calc::pick_decide vt [dict create ok 0]] act] \
              [expr {[pk_fld [pcall calc::pick_decide vt [dict create ok 0]] msg] ne {} ? {speaks} : {SILENT}}] \
              [pk_fld [pcall calc::pick_decide vt {}] act]] \
        {refuse speaks refuse}
    check "PK8 an UNRESOLVABLE design refuses with `nodesign` and never reaches the act: `ase::ui::design_path` answers empty for a key with no ASE session -- which is every viewer-origin result -- and it RESOLVES rather than opening, which is what keeps this proc pure" \
        [list [pcall ase::ui::design_path __pk_nosuch_key__] \
              [pk_fld [pcall calc::pick_decide vt [dict create ok 1 token __pk_nosuch_key__]] act] \
              [pk_fld [pcall calc::pick_decide vt [dict create ok 1 token __pk_nosuch_key__]] msg] \
              [pk_fld [pcall calc::pick_decide vt [dict create ok 1 token {}]] act]] \
        [list {} refuse {selector vt: cannot resolve this result's design cellview} refuse]
    # ⚠ THE `arm` ARM IS DRIVEN THROUGH A STUBBED `design_path`, because the only
    # thing standing between this dict and `act arm` is whether ASE can resolve a
    # cellview -- which is ASE's proc, fenced by ASE's own suites.  The stub
    # supplies the resolution; it does not share the decision.
    rename ase::ui::design_path pk_real_designpath
    proc ase::ui::design_path {key} { return /tmp/__pk_fake__/cell.sch }
    set armd {}
    foreach id [pcall calc::pick_ids] {
        lappend armd [pk_fld [pcall calc::pick_decide $id [dict create ok 1 token k]] act]
    }
    set one [pcall calc::pick_decide vt [dict create ok 1 token k]]
    set onei [pcall calc::pick_decide it [dict create ok 1 token k]]
    rename ase::ui::design_path {}
    rename pk_real_designpath ase::ui::design_path
    check "PK8 with a result loaded and a resolvable design, ALL EIGHT pick ids answer `arm` and carry the design path forward beside the token, so the act has both without resolving anything twice -- and the arming sentence names the id and the gesture, a NET for a voltage id and a DEVICE PIN, a voltage source or an ammeter for a current one (R208e, R208f)" \
        [list $armd [pk_fld $one act] [pk_fld $one token] [pk_fld $one design] \
              [pk_fld $one msg] [pk_fld $onei msg]] \
        [list {arm arm arm arm arm arm arm arm} arm k /tmp/__pk_fake__/cell.sch \
              {selector vt: click a net on the schematic; ESC cancels} \
              {selector it: click a device pin, voltage source or ammeter; ESC cancels}]
    check "PK8 ...and the stub was really put back, which the band checks rather than assumes -- a leaked rename would make every later row in this file measure a fake resolver" \
        [pcall ase::ui::design_path __pk_nosuch_key__] {}
    # R301/R303: a scope the strip says is unimplemented must not arm the canvas
    set pksave $::calc::pickscope
    set scoped {}
    foreach sc {wave family} {
        set ::calc::pickscope $sc
        lappend scoped [pk_fld [pcall calc::pick_decide vt [dict create ok 1 token k]] act]
    }
    set ::calc::pickscope $pksave
    check "PK8 R301: a non-`off` pick scope REFUSES to arm rather than silently arming the schematic canvas.  Tk writes a radiobutton's -variable BEFORE firing -command, so `::calc::pickscope` really does move to `wave` when the user clicks it even though the strip's own -command says the scope is unimplemented -- and arming the canvas after that would contradict both that sentence and R301's `in wave scope the schematic canvas is not armed at all`" \
        [list $scoped $::calc::pickscope \
              [pk_fld [pcall calc::pick_decide vt [dict create ok 1 token k]] act]] \
        [list {refuse refuse} off refuse]
}

# ===========================================================================
# PK9 — THE COMMAND-MODE REGISTRATION (R307)
# ===========================================================================
# Source-time, which is exactly what makes it provable here.
group PK9 {
    set reg [pcall cmdmode::registered]
    check "PK9 R307's real mechanism is `cmdmode`, registered at SOURCE time, so this arm can prove it happened at all: the pick is in the registry beside the two modes that were already there, and its callbacks are this phase's own suspend/resume pair" \
        [list [pk_in $reg calc_pick] [pk_in $reg ase_sod] [pk_in $reg rdw_pick] \
              [pk_atleast [llength $reg] 3] \
              [expr {[info procs ::calc::pick_suspend] ne {} ? 1 : 0}] \
              [expr {[info procs ::calc::pick_resume] ne {} ? 1 : 0}] \
              [pcall info args ::calc::pick_resume]] \
        {has has has atleast3 1 1 canvas}
    check "PK9 the registration is GUARDED on the contract existing, and not for tidiness: a suite that sources this file into a bare interpreter to prove nothing runs at source time has no `cmdmode` either, so an unguarded call would fail the very row that polices this file's --nogui survival" \
        [list [pk_word [regexp {info commands ::cmdmode::register} \
                            [pk_decomment [pcall info body ::calc::_register_cmdmode]]] guarded UNGUARDED] \
              [pcall calc::_register_cmdmode]] \
        {guarded 1}
    check "PK9 suspending with NOTHING live is 0 and no damage, which is a PERMANENT obligation and not a convenience: once this file is sourced the suspend arm runs on every descend in every profile forever" \
        [list [pcall calc::pick_suspend] [pcall calc::pick_resume] \
              [pcall calc::pick_running] [info exists ::calc::pick]] \
        {0 0 0 0}
    check "PK9 ...and `cmdmode`'s own round trip over the real registry is a no-op with nothing live, so a descend in a session that never opened the Calculator costs nothing and reports nothing" \
        [list [pcall cmdmode::suspend_all] [pcall cmdmode::resume_all] \
              [pcall cmdmode::is_suspended]] \
        {0 0 0}
}

# ===========================================================================
# PK10 — THE SEIZE SET, THREE COPIES FENCED AGAINST EACH OTHER
# ===========================================================================
# ⚠ ISSUE 1304 IS WHY THE HELD MOTION IS IN THE SET.  A seize without it
# leaves C's rubber band with a start and no end: a motion with Button1Mask
# calls select_rect(START,1) + unselect_all(1) and the ONLY thing that terminates
# it is ButtonRelease's select_rect(...,END,-1) -- which the seized release eats.
# Measured in the RDW with three: twenty objects selected and still selected after
# both the release and a real Escape.  A pick must not change the selection
# (issue 0204) and a one-pixel drift of the hand is enough to break that.
#
# ⚠ AND THE DOUBLE CLICK IS IN IT BECAUSE THE EDITOR BINDS THAT SEQUENCE ON
# EVERY DESIGN CANVAS.  Tk gives the second press of a double click to the most
# specific binding that matches, so with only the press seized that second
# press went past an armed mode to the editor -- its property dialog, or its
# connected-select, which selects.  What each mode does with the press is its
# own (band PG21 of tests/headless/test_calc_pick.tcl presses it for this
# pick); that each one takes the slot and hands it back is what this band holds.
#
# ⚠ THE SCAN'S LIMIT IS DECLARED RATHER THAN CHASED: it is a text scan over
# comment-stripped bodies, so a sequence assembled at run time from a variable
# would be invisible to it.  The `info args`-class instrument that issue 1646
# recommends does not exist for a `bind` sequence; what makes this honest is that
# all four sets are compared against EACH OTHER rather than against a list typed
# here, so one copy drifting from the others reddens even if the scan is blind to
# how.
group PK10 {
    set want {<B1-Motion> <ButtonPress-1> <ButtonRelease-1> <Double-Button-1> <Key-Escape>}
    set a [pk_seqs calc::_pick_seize]
    set b [pk_seqs calc::pick_release]
    set c [pk_seqs rdw::_pick_seize]
    set d [pk_seqs rdw::pick_release]
    set e [pk_seqs calc::pick_held]
    set f [pk_seqs rdw::pick_held]
    check "PK10 the pick seizes and restores exactly FIVE gesture slots -- the press, the release, Escape, the held motion and the double click -- and ALL SIX copies of that set agree: this phase's seize, its restore and the list of what it holds that it gives `cmdmode`, and the RDW's three, which are the prior art issue 1304's sequence was added to.  Compared against each other and not only against a list here, so one copy drifting reddens" \
        [list $a $b $c $d $e $f \
              [expr {$a eq $b && $b eq $c && $c eq $d && $d eq $e && $e eq $f ? {allsix} : {DRIFTED}}] \
              [pk_sized [llength $a] 5]] \
        [list $want $want $want $want $want $want allsix n5]
    check "PK10 ...and the DIFFERENCE from ASE is DECLARED rather than left to drift: `ase::ui::sod_release` hands back the same five slots this pick takes -- the press, the release, Escape, the held motion and the double click -- and one this pick does not take, the canvas going away.  Recorded here so a reader meets the difference as a decision instead of diagnosing it as a bug" \
        [list [pk_seqs ase::ui::sod_release] [pk_sized [llength [pk_seqs ase::ui::sod_release]] 6] \
              [expr {[pk_seqs ase::ui::sod_release] eq [lsort [concat $want <Destroy>]] ? {fiveplusone} : {OTHER}}]] \
        [list {<B1-Motion> <ButtonPress-1> <ButtonRelease-1> <Destroy> <Double-Button-1> <Key-Escape>} n6 fiveplusone]
    check "PK10 the restore is ONE proc shared by the end path AND the suspend path, exactly as `ase::ui::sod_release` and `rdw::pick_release` are, so the seize and the restore cannot drift: both `calc::pick_end` and `calc::pick_suspend` reach `bind` only through it and neither names a sequence of its own" \
        [list [pk_seqs calc::pick_end] [pk_seqs calc::pick_suspend] \
              [pk_word [regexp {calc::pick_release} [pk_decomment [pcall info body ::calc::pick_end]]] routes DIRECT] \
              [pk_word [regexp {calc::pick_release} [pk_decomment [pcall info body ::calc::pick_suspend]]] routes DIRECT] \
              [pk_word [regexp {_pick_seize} [pk_decomment [pcall info body ::calc::pick_resume]]] routes DIRECT]] \
        {{} {} routes routes routes}
}

# ===========================================================================
# PK14 — THE PIECES THE ARM AND THE PROMPT ASK, WITH NO CANVAS
# ===========================================================================
# The ACT is tests/headless/test_calc_pick.tcl: band PG20 (the pick and ASE-L's
# Select On Design never hold the canvas together) and band PG22 (the prompt
# names the pin a click would take).  Here are the decisions, which need no
# display: what `calc::pick_end_sod` does with a live, an absent and a faulty
# Select On Design, where the arm asks it, and when `calc::pick_hover` asks the
# pin rule and what it makes of the answer.
#
# ⚠ THE STUBS ARE TAKEN AND HANDED BACK INSIDE THE BAND, and the last row checks
# that: `ase::ui::sod_end`, `ase::ui::sod_terminal_at`, `calc::pick_canvas` and
# `calc::pick_base` are renamed aside, and `::ase::ui::sod(active)` and
# `::calc::pick` are left as they were found -- absent, which band PK11 reads.
group PK14 {
    # --- calc::pick_end_sod ------------------------------------------------------
    set hadactive [info exists ::ase::ui::sod(active)]
    rename ase::ui::sod_end pk14_real_sodend
    set ::pk14_ended {}
    proc ase::ui::sod_end {key} { lappend ::pk14_ended $key }
    set none [list [pcall calc::pick_end_sod] $::pk14_ended]
    proc ase::ui::sod_end {key} { lappend ::pk14_ended $key ; unset -nocomplain ::ase::ui::sod(active) }
    set ::ase::ui::sod(active) lib/cell/state
    set live [list [pcall calc::pick_end_sod] $::pk14_ended [info exists ::ase::ui::sod(active)]]
    set ::pk14_ended {}
    proc ase::ui::sod_end {key} { lappend ::pk14_ended $key ; error {the mode's end raised} }
    set ::ase::ui::sod(active) lib/cell/state
    set faulty [list [pcall calc::pick_end_sod] $::pk14_ended [info exists ::ase::ui::sod(active)]]
    unset -nocomplain ::ase::ui::sod(active)
    rename ase::ui::sod_end {}
    rename pk14_real_sodend ase::ui::sod_end
    check "PK14 `calc::pick_end_sod` ends a LIVE Select On Design through that mode's own end, handing it the session the mode is up for, and answers 1 once the mode is gone; with none up it calls nothing and answers 0; and an end that RAISES does not raise out of it -- it answers 0, the mode being still up -- because a pick must still arm when the other mode's end fails" \
        [list $none $live $faulty] \
        [list {0 {}} {1 lib/cell/state 0} {0 lib/cell/state 1}]
    # ⚠ A TEXT SCAN, AND ITS LIMIT IS DECLARED: it reads the uncommented body of
    # the arm, so a call assembled at run time would be invisible to it.  The
    # recorded-call leg of band PG20 is the measurement; this is the same order
    # on the arm that has no canvas to arm on.
    set body [pk_decomment [pcall info body ::calc::pick_arm]]
    set iact [string first {$act ne {arm}} $body]
    set isod [string first {calc::pick_end_sod} $body]
    set iwin [string first {ase::ui::design_window} $body]
    set isz  [string first {calc::_pick_seize} $body]
    check "PK14 the arm ends Select On Design only ONCE IT IS GOING AHEAD and BEFORE it raises the design window or seizes: in its own text the call stands after the test that returns a refusal, before the design window is asked for and before the seize -- so a selector that refuses leaves the other mode up, and the raise that mode's end makes cannot land on top of the design window" \
        [list [pk_word [expr {$iact >= 0 && $isod > $iact}] afterrefusal "act=$iact sod=$isod"] \
              [pk_word [expr {$isod >= 0 && $iwin > $isod}] beforewindow "sod=$isod win=$iwin"] \
              [pk_word [expr {$isod >= 0 && $isz > $isod}] beforeseize "sod=$isod seize=$isz"] \
              [regexp -all {calc::pick_end_sod} $body]] \
        {afterrefusal beforewindow beforeseize 1}
    # --- calc::pick_hover_text ----------------------------------------------------
    check "PK14 the words the prompt ends with are made from the pin rule's own answer and from nothing else: an instance and a pin name give ` — pin <instance>:<pin>`; an empty answer, one without the instance, one without the pin and a text that is no list at all give NOTHING, never half a name" \
        [list [pcall calc::pick_hover_text {inst 3 pin 1 instname R9 pinname P x 0 y 0 others {}}] \
              [pcall calc::pick_hover_text {instname {x1.M12} pinname d}] \
              [pcall calc::pick_hover_text {}] \
              [pcall calc::pick_hover_text {instname R9}] \
              [pcall calc::pick_hover_text {pinname P}] \
              [pcall calc::pick_hover_text "\{"]] \
        [list { — pin R9:P} { — pin x1.M12:d} {} {} {} {}]
    # --- calc::pick_hover: when it asks, and that it never raises ---------------
    rename ase::ui::sod_terminal_at pk14_real_tat
    rename calc::pick_canvas calc::pk14_real_canvas
    rename calc::pick_base calc::pk14_real_base
    set ::pk14_asked {}
    proc ase::ui::sod_terminal_at {key x y} {
        lappend ::pk14_asked $key
        return {inst 2 pin 0 instname M1 pinname d x 0 y 0 others {}}
    }
    proc calc::pick_canvas {} { return .pk14.drw }
    proc calc::pick_base {dpath} { return 0 }
    set hov {}
    lappend hov [list [pcall calc::pick_hover] $::pk14_asked]
    array set ::calc::pick {id vt canvas .pk14.drw token lib/cell/state design /d.sch}
    lappend hov [list [pcall calc::pick_hover] $::pk14_asked]
    set ::calc::pick(id) it
    lappend hov [list [pcall calc::pick_hover] $::pk14_asked]
    lappend hov [list [pcall calc::pick_hover] $::pk14_asked]
    unset -nocomplain ::calc::pick(hoverat)
    proc calc::pick_base {dpath} { return -1 }
    lappend hov [list [pcall calc::pick_hover] [llength $::pk14_asked]]
    unset -nocomplain ::calc::pick(hoverat)
    proc calc::pick_base {dpath} { return 0 }
    proc calc::pick_canvas {} { return .other.drw }
    lappend hov [list [pcall calc::pick_hover] [llength $::pk14_asked]]
    unset -nocomplain ::calc::pick(hoverat)
    proc calc::pick_canvas {} { return .pk14.drw }
    proc ase::ui::sod_terminal_at {key x y} { lappend ::pk14_asked $key ; error {the pin rule is down} }
    lappend hov [list [pcall calc::pick_hover] [llength $::pk14_asked]]
    # the record goes the way the product drops it, through a proc that names it
    # as its own variable: unset by its global name the variable would leave the
    # namespace altogether, which is not how any run of the product leaves it
    # and is a difference band PK11's namespace diff sees
    array unset ::calc::pick
    pcall calc::pick_running
    rename ase::ui::sod_terminal_at {}
    rename pk14_real_tat ase::ui::sod_terminal_at
    rename calc::pick_canvas {}
    rename calc::pk14_real_canvas calc::pick_canvas
    rename calc::pick_base {}
    rename calc::pk14_real_base calc::pick_base
    check "PK14 `calc::pick_hover` asks ASE-L's pin rule only for a CURRENT selector and only when what it was worked out from has changed: with nothing armed and with `vt` armed it says nothing and does not ask; with `it` armed it asks once, for the session the pick was armed for, and names the pin; asked again with the pointer where it was it answers the same WITHOUT asking; on a sheet that is not the armed design's, and on a canvas that is not the pick's, it says nothing and does not ask; and a pin rule that RAISES gives nothing and no error" \
        $hov [list {{} {}} {{} {}} {{ — pin M1:d} lib/cell/state} {{ — pin M1:d} lib/cell/state} \
                   {{} 1} {{} 1} {{} 2}]
    check "PK14 the band handed back everything it took: the four procs it renamed aside are the product's again, no Select On Design is recorded as active that was not, and `::calc::pick` is absent" \
        [list [expr {[info procs ::pk14_real_sodend] eq {} ? 1 : 0}] \
              [expr {[info procs ::pk14_real_tat] eq {} ? 1 : 0}] \
              [expr {[info procs ::calc::pk14_real_canvas] eq {} ? 1 : 0}] \
              [expr {[info procs ::calc::pk14_real_base] eq {} ? 1 : 0}] \
              [expr {[info exists ::ase::ui::sod(active)] == $hadactive ? 1 : 0}] \
              [info exists ::calc::pick]] \
        {1 1 1 1 1 0}
}

# ===========================================================================
# PK15 — WHAT THE SEIZE BINDS, AND WHAT THE PICK TELLS `cmdmode` IT HOLDS
# ===========================================================================
# The ACT is tests/headless/test_calc_pick.tcl: band PG24 (a real press is
# resolved at its own pixel) and band PG25 (a window created while the pick is
# armed gets none of its scripts).  Here the seize, the resolved pick's
# re-pointed release, the suspend and the end are RUN, against a STAND-IN for
# Tk's binding table -- this arm has no `bind` -- and the list
# `calc::pick_held` answers is read against that table, slot for slot.
#
# ⚠ THE STAND-IN IS A TABLE AND NOTHING ELSE, AND IT IS THE CALCULATOR'S ALONE:
# `bind w seq` reads a slot, `bind w seq script` writes it, and an empty script
# removes it, as Tk's does.  It is a `bind` defined INSIDE the `calc`
# namespace, which is the one that namespace's procs reach first, so no global
# command is invented on this arm (band PK11 reads that it has no Tk) and Tk's
# own `bind` is untouched where there is one.  It is put in place inside the
# band and taken away at its foot, which the last row checks.
#
# ⚠ EVERY SLOT IS SEEDED WITH A PREDECESSOR OF ITS OWN, all five different, so
# a list that paired a slot with another slot's record cannot pass.
proc pk15_bind {w args} {
    if {[llength $args] == 0} {
        set out {}
        foreach k [lsort [array names ::pk15_tab]] {
            if {[string match "$w,*" $k]} { lappend out [string range $k [string length "$w,"] end] }
        }
        return $out
    }
    set seq [lindex $args 0]
    if {[llength $args] == 1} {
        if {[info exists ::pk15_tab($w,$seq)]} { return $::pk15_tab($w,$seq) }
        return {}
    }
    if {[lindex $args 1] eq {}} {
        unset -nocomplain ::pk15_tab($w,$seq)
    } else {
        set ::pk15_tab($w,$seq) [lindex $args 1]
    }
    return {}
}
set ::PK15_SEQS {<ButtonPress-1> <ButtonRelease-1> <Key-Escape> <B1-Motion> <Double-Button-1>}
proc pk15_slots {cv} {
    set out {}
    foreach q $::PK15_SEQS { lappend out [pk15_bind $cv $q] }
    return $out
}
# a held list read against the table: its sequences in order, the groups whose
# canvas or script is not what the table holds, and its predecessors in order
proc pk15_read {cv held} {
    set seqs {} ; set off {} ; set prevs {}
    foreach {hc hq hs hp} $held {
        lappend seqs $hq
        if {$hc ne $cv || [pk15_bind $cv $hq] ne $hs} { lappend off $hq }
        lappend prevs $hp
    }
    return [list [pk_sized [llength $held] 20] $seqs $off $prevs]
}
group PK15 {
    set cv .pk15canvas
    array unset ::pk15_tab
    proc ::calc::bind {w args} { return [pk15_bind $w {*}$args] }
    proc ::calc::focus {args} { return {} }
    set hadpick [info exists ::calc::pick]
    set seeded {}
    foreach q $::PK15_SEQS w {press release escape motion double} {
        set sc "pk15_was $w"
        pk15_bind $cv $q $sc
        lappend seeded $sc
    }
    set press {xschem callback %W 6 %x %y 0 0 0 %s; calc::pick_click; break}
    set none [pcall calc::pick_held]
    set sz [pcall calc::_pick_seize $cv]
    check "PK15 the press's script, as the seize binds it, FIRST hands the press's own position to the engine as a pointer motion and THEN runs the click, and the double click's slot holds the very same script -- so the click is resolved at the pixel that was pressed whatever the engine's pointer pair held before; the release and the held motion are swallowed and Escape ends the pick" \
        [list $none $sz [pk15_slots $cv]] \
        [list {} $cv [list $press break {calc::pick_end cancel; break} break $press]]
    set held [pcall calc::pick_held]
    check "PK15 with the canvas seized, what the pick tells `cmdmode` it holds is one group of four for each of the five slots, in the seize's own order: this canvas, the sequence, the very script the table holds in that slot, and the predecessor that slot was seeded with -- five different ones, each beside its own slot" \
        [pk15_read $cv $held] \
        [list n20 $::PK15_SEQS {} $seeded]
    set pr {}
    foreach q $::PK15_SEQS { lappend pr [pcall cmdmode::pristine $cv $q [pk15_bind $cv $q]] }
    check "PK15 ...and the list is REGISTERED with `cmdmode`, read off what `cmdmode::pristine` answers and not off the registration's text: asked what each slot of this canvas would hold with no mode up, given the script it holds now, it answers that slot's seeded predecessor; a script the pick does not hold, and the pick's script on a canvas it is not on, come back unchanged" \
        [list $pr [pcall cmdmode::pristine $cv <ButtonPress-1> {pk15 somebody else}] \
              [pcall cmdmode::pristine .pk15other <ButtonPress-1> $press]] \
        [list $seeded {pk15 somebody else} $press]
    # --- a pick that resolved: the release slot is re-pointed until the release ----
    set dn [pcall calc::pick_done]
    set held2 [pcall calc::pick_held]
    check "PK15 once a pick has RESOLVED the release slot holds the script that ends the mode on the release, and the list follows it: still five groups, each script still the one the table holds, the predecessors unmoved -- so a window made between that press and its release copies the slot's predecessor and not the end script" \
        [list $dn [pk15_bind $cv <ButtonRelease-1>] [pk15_read $cv $held2] \
              [pcall cmdmode::pristine $cv <ButtonRelease-1> [pk15_bind $cv <ButtonRelease-1>]]] \
        [list 1 {calc::pick_end picked; break} [list n20 $::PK15_SEQS {} $seeded] [lindex $seeded 1]]
    # --- suspended: every slot is handed back, and nothing is held ------------------
    set su [pcall calc::pick_suspend]
    set susp [list $su [pk15_slots $cv] [pcall calc::pick_held] [pcall calc::pick_running] \
                  [pcall cmdmode::pristine $cv <ButtonPress-1> $press]]
    # the seize a resume makes, on the canvas it lands on
    unset -nocomplain ::calc::pick(suspended)
    pcall calc::_pick_seize $cv
    set back [pk15_read $cv [pcall calc::pick_held]]
    set en [pcall calc::pick_end cancel]
    check "PK15 a SUSPENDED pick holds nothing: the five slots are back at their predecessors, the list is empty although the pick still counts as running, and `cmdmode::pristine` leaves the pick's script alone; seized again, as a resume seizes, the list is whole again with the predecessors latched afresh; and ENDED, the slots are the predecessors again, the list is empty and no record is left" \
        [list $susp $back $en [pk15_slots $cv] [pcall calc::pick_held] [info exists ::calc::pick]] \
        [list [list 1 $seeded {} 1 $press] [list n20 $::PK15_SEQS {} $seeded] 1 $seeded {} 0]
    # --- resumed with the name of a context that is no widget -------------------
    # `cmdmode` hands a resume the name of the window CONTEXT a descend or a
    # return landed on.  With the tabbed interface a schematic in a tab that is
    # not the first is a context called `.x1.drw`, a name no widget has; the
    # canvas that shows it is the main window's `.drw`, which the tabs share,
    # and `xschem windows` lists that context with the main window's toplevel.
    # The pick must land on that canvas.  Taken as it stands the name is no
    # widget, and the resume would fall back to the canvas the pick was on --
    # the window the user has just left.
    #
    # Further stand-ins, for this part alone and the Calculator's own: which
    # names are widgets (`calc::has_win`), and an `xschem` INSIDE the
    # `calc` namespace that answers `windows` from a list written here and
    # hands every other subcommand to the real one.  The pick is first seized
    # on the canvas of a window of its own and suspended, as a descend into a
    # new window leaves it.
    set child .x3.drw
    set ::pk15_wins [list .drw $child]
    set ::pk15_rows [list [list .drw . . 11 a.sch 0 a.sch] [list .x1.drw . . 11 top.sch 1 top.sch] \
                          [list $child .x3 .x3 12 sub.sch 2 {top.sch sub.sch}]]
    rename calc::has_win calc::pk15_real_haswin
    proc calc::has_win {w} { return [expr {[lsearch -exact $::pk15_wins $w] >= 0 ? 1 : 0}] }
    proc ::calc::xschem {args} {
        if {[lindex $args 0] eq {windows}} { return $::pk15_rows }
        return [uplevel 1 [linsert $args 0 ::xschem]]
    }
    array unset ::pk15_tab
    pcall calc::_pick_seize $child
    set tsus [pcall calc::pick_suspend]
    set tres [pcall calc::pick_resume .x1.drw]
    set tab [list $tsus $tres [pcall set ::calc::pick(canvas)] [pk15_slots .drw] \
                  [pk15_bind .x1.drw] [pk15_bind $child]]
    # the controls: a name that is a widget is taken as it is, and a name that
    # is neither a widget nor a context in the list falls back to the canvas
    # the pick was on
    pcall calc::pick_suspend
    set twid [list [pcall calc::pick_resume $child] [pcall set ::calc::pick(canvas)] [pk15_bind .drw]]
    pcall calc::pick_suspend
    set tgone [list [pcall calc::pick_resume .x9.drw] [pcall set ::calc::pick(canvas)]]
    set ten [pcall calc::pick_end cancel]
    check "PK15 a SUSPENDED pick resumed with the name of a context that is NO WIDGET lands on the canvas that shows that context: seized on a window's own canvas, suspended, and resumed with `.x1.drw` -- a tab that is not the first, listed with the main window's toplevel -- it answers 1, the pick is recorded on `.drw`, the five slots of `.drw` hold the pick's scripts, nothing at all is bound under the name `.x1.drw`, and nothing is left on the canvas it was on.  Resumed with a name that IS a widget it takes that canvas and hands `.drw` back; resumed with a name that is neither a widget nor a context in the list it stays on the canvas it was on; and ended, nothing is bound anywhere and no pick is running" \
        [list $tab $twid $tgone $ten [array names ::pk15_tab] [info exists ::calc::pick] \
              [pcall calc::pick_running]] \
        [list [list 1 1 .drw [list $press break {calc::pick_end cancel; break} break $press] {} {}] \
              [list 1 $child {}] [list 1 $child] 1 {} 0 0]
    catch {rename ::calc::xschem {}}
    catch {rename calc::has_win {}}
    catch {rename calc::pk15_real_haswin calc::has_win}
    # --- hand the stand-in back -------------------------------------------------
    catch {rename ::calc::bind {}}
    catch {rename ::calc::focus {}}
    array unset ::pk15_tab
    check "PK15 the band handed back what it took: the stand-ins are gone from the Calculator's namespace, so `bind`, `focus` and `xschem` there are the interpreter's own again or no command at all, the product's test of what is a widget answers again -- no for a name that is none, on this arm with no Tk -- its table is gone, and `::calc::pick` is absent as it was found" \
        [list [info commands ::calc::bind] [info commands ::calc::focus] [info commands ::calc::xschem] \
              [pcall calc::has_win .pk15canvas] \
              [expr {[info procs ::calc::pk15_real_haswin] eq {} ? {restored} : {LEAKED}}] \
              [expr {[info exists ::pk15_tab] ? {TABLE} : {notable}}] \
              [expr {[info exists ::calc::pick] == $hadpick ? {asfound} : {CHANGED}}]] \
        [list {} {} {} 0 restored notable asfound]
}

# ===========================================================================
# PK11 — ABSENCE: NO `winfo`, NO WINDOW, NO WRITES
# ===========================================================================
# ⚠ `winfo` IS ABSENT AS A COMMAND UNDER `--nogui`, NOT MERELY UNABLE TO FIND A
# WINDOW.  So the obvious `if {![winfo exists .calc]}` guard RAISES `invalid
# command name "winfo"` on exactly the arm an rc calling a setter before the
# window exists lands on -- the `info commands winfo` test must come FIRST, which
# is what `calc::has_win` does.  Row CF5 of test_calc_measure.tcl found that bug
# in the font control on its first run; this band is the same instrument pointed
# at the pick, and it is strictly stronger than renaming `winfo` away, because
# here the command really is gone.
group PK11 {
    check "PK11 fixture: `winfo` really is ABSENT on this arm, so every row below is measuring the real hazard and not a rename of it" \
        [list [expr {[info commands winfo] eq {} ? {absent} : {PRESENT}}] \
              [pcall calc::has_win .calc]] \
        {absent 0}
    set before [pk_nssnap]
    set ans {}
    foreach c [list {calc::pick_arm vt} {calc::pick_arm vdc} {calc::pick_click} \
                    {calc::pick_click 80 -200} {calc::pick_end} {calc::pick_end close} \
                    {calc::pick_end moved} {calc::pick_release} {calc::pick_running} \
                    {calc::pick_id} {calc::pick_pump} {calc::pick_suspend} \
                    {calc::pick_resume} {calc::pick_resume .nosuch.drw} \
                    {calc::sel_click vt} {calc::sel_click op} \
                    {calc::pick_arm it} {calc::sel_click idc} \
                    {calc::pick_imeasure __pk_nosession__ 0 0 {}} {calc::pick_iplan {}} \
                    {calc::pick_iresolve {} 0 calc::pick_lookup_in} \
                    {calc::pick_inotes it {} {}} \
                    {calc::pick_end_sod} {calc::pick_dbl_editor .nosuch.drw} \
                    {calc::pick_hover} {calc::pick_hover_text {}} {calc::pick_held}] {
        lappend ans [pcall {*}$c]
    }
    set after [pk_nssnap]
    set raised {}
    foreach a $ans { if {[string match ERR:* $a]} { lappend raised $a } }
    check "PK11 with no `winfo` and no window, EVERY entry point of the pick ANSWERS rather than raising -- the arm, the click with and without coordinates, all four end reasons, the release, the pump, suspend, resume with and without a canvas, every route through the selector click -- a current id's (R208e) included -- the four steps of a current click on a pin (R208f), the four helpers the arm, the seize and the prompt ask: ending Select On Design, the editor's double-click script, and the pin the prompt names -- and the list of what the pick holds that `cmdmode` asks for, which with nothing armed is empty" \
        [list $raised [pk_sized [llength $ans] 27] [lindex $ans end]] {{} n27 {}}
    check "PK11 ...and not one of them WROTE anything, which is R508's `records nothing` about STATE and not only about raising: the whole `::calc` namespace is diffed, variable by variable and array element by array element, so a write to something this row does not name is still caught" \
        [expr {$before eq $after ? {unwritten} : "WROTE:[pk_nsdiff $before $after]"}] unwritten
    check "PK11 `::calc::pick` is still ABSENT, not empty: for an array the normative `nothing is armed` state is absent, which is what `calc::pick_running` and `calc::pick_id` both read -- and a seeded array would make `nothing armed` indistinguishable from `the record was cleared`" \
        [list [info exists ::calc::pick] [pcall calc::pick_running] [pcall calc::pick_id]] \
        {0 0 {}}
    check "PK11 the fixture for the diff itself: the snapshot really is a non-trivial reading of the namespace and not an empty list compared with itself" \
        [list [pk_atleast [llength $before] 40] \
              [pk_word [expr {[lsearch -exact $before ::calc::selmode] >= 0}] reads MISSING]] \
        {atleast40 reads}
}

# ---------------------------------------------------------------------------
check "EVERY band above this one RAN TO ITS END: no band was abandoned through `group`'s catch, which is the failure mode that DELETES a band's remaining rows from the verdict instead of reddening them -- and the names of any that were are the value here, since the only other evidence is a check total that came in short.  Derived from `group`'s own record rather than a list kept here, so a band added later is covered without this row being edited" [list [llength $::abortnames] $::abortnames] {0 {}}

# ⚠⚠ THE `OVERALL: ok` SENTINEL IS WHAT T1 CAN SCORE, AND `RESULT:` IS NOT.
# `banner_complete` in tests/banner_rule.tcl -- the only Tcl reader, the one
# tests/run_regression.tcl sources -- is `^OVERALL: ok([ \t]+\([^)]*\))?[ \t]*$`,
# and that file's header says it implements no `RESULT: ALL PASS` spelling at all.
# A registered suite without this line is scored `HARNESS: ... (exit=0,
# OVERALL_ok=0, died=0)` with every one of its own checks passing, which is issue
# 1615's incident and cost six counted failures.  `RESULT:` stays LAST, because
# `summarize_all` publishes a case's last `RESULT:` line.
if {$fail == 0} {
    puts "OVERALL: ok ($npass checks)"
    puts "RESULT: ALL PASS ($npass checks)"
} else {
    puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
