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
proc pk_derived_ids {} {
    set r [pk_rows]
    if {[string match ERR:* $r]} { return $r }
    return [lindex [lindex $r 0] 0]
}
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
    check "PK1 `calc::pick_ids` is DERIVED from the selector grid's own table and not a second list: it equals row 0's first group of `calc::sel_rows` element for element, which is spec §5's VOLTAGE group -- the group, and not the `Emits into buffer` column, which is what made these four look alike and is the defect R208a corrects" \
        [list $ids $der [expr {$ids eq $der ? {same} : {DIFFERENT}}]] \
        [list {vt vf vdc vs} {vt vf vdc vs} same]
    check "PK1 the grid's population rides along, so a twenty-third selector or a ninth disabled one has to move a number here rather than quietly joining or leaving the pick's scope" \
        [list [pk_sized [llength $all] 22] [pk_sized [llength $ids] 4] \
              [pk_sized [llength $enab] 14] [pk_sized [llength $dis] 8] \
              [pk_sized [llength $others] 10]] \
        {n22 n4 n14 n8 n10}
    # R208: the ten other ENABLED ids are not in scope and must say so, through
    # the same `calc::inert` route they used before this stage existed.
    set inert {}
    set armed {}
    foreach id $enab {
        set d [pcall calc::pick_decide $id [dict create ok 1 token __pk_nosuch__]]
        set act [pk_fld $d act]
        if {$act eq {inert}} { lappend inert $id } else { lappend armed $id }
    }
    check "PK1 R208's scope boundary is a ROUTING decision and is drivable here: every one of the ten enabled non-voltage ids answers `inert` -- which is what keeps their shipped `calc::inert ... phase 6` sentence -- and not one of the four voltage ids does" \
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
    check "PK1 the analysis table is ONE table keyed on the same four ids as the pick's scope, and it is complete in both directions -- a fifth id with no analysis, or an analysis with no id, reddens here" \
        [list [pcall calc::pick_analyses] \
              [lsort [pcall dict keys [pcall calc::pick_analyses]]] [lsort $ids] \
              [pcall calc::pick_analysis op] [pcall calc::pick_analysis {}]] \
        [list {vt tran vf ac vdc op vs dc} {vdc vf vs vt} {vdc vf vs vt} {} {}]
    # ⚠ THE DESIGN RESOLUTION IS STUBBED, because it sits AFTER the gate and
    # refuses for its own reason -- so without it all eight drives answer `refuse`
    # and the row cannot tell a gate refusal from a missing cellview.  That is what
    # the first spelling of it did.  The stub supplies ASE's resolution; it does not
    # share the gate.
    rename ase::ui::design_path pk_real_dp
    proc ase::ui::design_path {key} { return /tmp/__pk_fake__/cell.sch }
    set pkgate {}
    foreach {id ty} {vt tran vt ac vf ac vf tran vdc op vdc tran vs dc vs ac} {
        lappend pkgate [pk_fld [pcall calc::pick_decide $id \
            [dict create ok 1 token k type $ty]] act]
    }
    rename ase::ui::design_path {}
    rename pk_real_dp ase::ui::design_path
    check "PK1 ...and the stub was handed back, which the band CHECKS rather than assumes" \
        [pcall ase::ui::design_path __pk_nosuch__] {}
    check "PK1 R208a drivable with no database at all: each voltage id ARMS on its own analysis and REFUSES on another -- four matches and four mismatches, so the row cannot pass by refusing everything or by arming everything" \
        $pkgate {arm refuse arm refuse arm refuse arm refuse}
    check "PK1 ...and the refusal NAMES BOTH analyses, in the user's words rather than the simulator's -- acronyms uppercase, one map shared with the success sentence so they cannot disagree" \
        [list [pk_fld [pcall calc::pick_decide vf [dict create ok 1 token k type tran]] msg] \
              [pk_fld [pcall calc::pick_decide vdc [dict create ok 1 token k type ac]] msg] \
              [pcall calc::analysis_word tran] [pcall calc::analysis_word ac] \
              [pcall calc::analysis_word op] [pcall calc::analysis_word dc] \
              [pcall calc::analysis_word __pk_unknown__]] \
        [list {selector vf: needs an AC result; this one is transient} \
              {selector vdc: needs an operating point result; this one is AC} \
              transient AC {operating point} {DC sweep} __pk_unknown__]
    check "PK1 the ARTICLE is chosen and not hardcoded, which the first spelling of this got wrong (`needs an tran result`, `an dc result`) -- a sentence the user reads has to read" \
        [list [pcall calc::pick_wants vt] [pcall calc::pick_wants vf] \
              [pcall calc::pick_wants vdc] [pcall calc::pick_wants vs] \
              [pcall calc::pick_wants op]] \
        [list {a transient result} {an AC result} {an operating point result} \
              {a DC sweep result} {its own analysis}]
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
              [pk_in $arms prompt] [pk_in $arms __pk_no_such_arm__]] \
        {atleast15 has has has has has has has missing:__pk_no_such_arm__}
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
    rename ase::ui::design_path {}
    rename pk_real_designpath ase::ui::design_path
    check "PK8 with a result loaded and a resolvable design, ALL FOUR voltage ids answer `arm` and carry the design path forward beside the token, so the act has both without resolving anything twice -- and the arming sentence names the id and the gesture" \
        [list $armd [pk_fld $one act] [pk_fld $one token] [pk_fld $one design] \
              [pk_fld $one msg]] \
        [list {arm arm arm arm} arm k /tmp/__pk_fake__/cell.sch \
              {selector vt: click a net on the schematic; ESC cancels}]
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
# ⚠ ISSUE 1304 IS WHY THERE ARE FOUR SEQUENCES AND NOT THREE.  A three-sequence
# seize leaves C's rubber band with a start and no end: a motion with Button1Mask
# calls select_rect(START,1) + unselect_all(1) and the ONLY thing that terminates
# it is ButtonRelease's select_rect(...,END,-1) -- which the seized release eats.
# Measured in the RDW with three: twenty objects selected and still selected after
# both the release and a real Escape.  A pick must not change the selection
# (issue 0204) and a one-pixel drift of the hand is enough to break that.
#
# ⚠ THE SCAN'S LIMIT IS DECLARED RATHER THAN CHASED: it is a text scan over
# comment-stripped bodies, so a sequence assembled at run time from a variable
# would be invisible to it.  The `info args`-class instrument that issue 1646
# recommends does not exist for a `bind` sequence; what makes this honest is that
# all four sets are compared against EACH OTHER rather than against a list typed
# here, so one copy drifting from the others reddens even if the scan is blind to
# how.
group PK10 {
    set want {<B1-Motion> <ButtonPress-1> <ButtonRelease-1> <Key-Escape>}
    set a [pk_seqs calc::_pick_seize]
    set b [pk_seqs calc::pick_release]
    set c [pk_seqs rdw::_pick_seize]
    set d [pk_seqs rdw::pick_release]
    check "PK10 the pick seizes and restores exactly FOUR gesture slots, and ALL FOUR copies of that set agree -- this phase's seize, this phase's restore, and the RDW's two, which are the prior art issue 1304's fourth sequence was added to.  Compared against each other and not only against a list here, so one copy drifting reddens" \
        [list $a $b $c $d \
              [expr {$a eq $b && $b eq $c && $c eq $d ? {allfour} : {DRIFTED}}] \
              [pk_sized [llength $a] 4]] \
        [list $want $want $want $want allfour n4]
    check "PK10 ...and the ASYMMETRY with ASE is DECLARED rather than left to drift: `ase::ui::sod_release` takes the known-narrower THREE, because it predates issue 1304 and its own mode has not been re-measured against the rubber band.  Recorded here so a reader meets the difference as a decision instead of diagnosing it as a bug" \
        [list [pk_seqs ase::ui::sod_release] [pk_sized [llength [pk_seqs ase::ui::sod_release]] 3]] \
        [list {<ButtonPress-1> <ButtonRelease-1> <Key-Escape>} n3]
    check "PK10 the restore is ONE proc shared by the end path AND the suspend path, exactly as `ase::ui::sod_release` and `rdw::pick_release` are, so the seize and the restore cannot drift: both `calc::pick_end` and `calc::pick_suspend` reach `bind` only through it and neither names a sequence of its own" \
        [list [pk_seqs calc::pick_end] [pk_seqs calc::pick_suspend] \
              [pk_word [regexp {calc::pick_release} [pk_decomment [pcall info body ::calc::pick_end]]] routes DIRECT] \
              [pk_word [regexp {calc::pick_release} [pk_decomment [pcall info body ::calc::pick_suspend]]] routes DIRECT] \
              [pk_word [regexp {_pick_seize} [pk_decomment [pcall info body ::calc::pick_resume]]] routes DIRECT]] \
        {{} {} routes routes routes}
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
                    {calc::sel_click vt} {calc::sel_click op}] {
        lappend ans [pcall {*}$c]
    }
    set after [pk_nssnap]
    set raised {}
    foreach a $ans { if {[string match ERR:* $a]} { lappend raised $a } }
    check "PK11 with no `winfo` and no window, EVERY entry point of the pick ANSWERS rather than raising -- the arm, the click with and without coordinates, all four end reasons, the release, the pump, suspend, resume with and without a canvas, and both routes through the selector click" \
        [list $raised [pk_sized [llength $ans] 16]] {{} n16}
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
