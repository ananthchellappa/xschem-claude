# tests/headless/test_ase_op_measures.tcl -- a committed bench's plain signal
# row whose author plainly meant to READ the operating point is a measure,
# vdc(x)/idc(x), and shows the simulator's number (ase_l.md R-OUT11).
#
# The user (2026-10-13): "Yes, proceed with vdc(vbg) and analogues of that in
# all test-benches where there is an operating point analysis and it is
# obvious that the intention was to display operating point information."
#
# Spec     doc/claude/specs/ase_l.md R-OUT11
# Tool     tools/migrate/op_measures.tcl (derives the table),
#          tools/migrate/op_measures_vars.tcl + op_measures_bench.tcl (the real
#          runs it derives from; this suite's OM7 runs the benches through the
#          same helper)
# Table    tests/headless/data/op_measures.txt, one {state index name old new
#          why} list per candidate row: `new` the measure, or {} when the row
#          stays as it is, and `why` the evidence or the reason
#
# Bands (counted arm)
#   OM1  the table is read, names committed states, and holds converted rows
#        of both kinds of evidence and rows that stay
#   OM2  every converted row is committed as `new`; every row that stays is
#        committed as `old`
#   OM3  the new text is the old one's own signal under vdc()/idc(), and it
#        sorts into Measures
#   OM4  COVERAGE, re-derived without the tool: the table holds exactly the
#        plain signal rows of every bench whose operating point is enabled
#   OM5  OBVIOUSNESS, re-derived without the tool: an `op-only` row's bench
#        enables nothing else and is a test bench (its schematic places no
#        port pin); a `print` row's original prints that exact text after
#        `op`; no row left as "not obvious" has such a print
#   OM6  git: each touched state at 2e1e4ccb with only the converted exprs
#        replaced is byte-identical to the committed file
#   OM7  REAL ngspice (the registry's) on the bundled PDK benches: each
#        converted bench runs, each converted row sits in the Measures tree
#        and the Value that tree shows is a number, the
#        number is the results file's own vector, and it is what ngspice's
#        own `print` of the old text gives at the operating point; rows that
#        stay for a measured reason still have that reason
#
# REGISTERED IN `hcases`: nothing here needs a display.
#
# Standalone from the repo ROOT, armed (throwaway HOME, never $DISPLAY):
#   tests/headless/run_suites.sh --nogui test_ase_op_measures

source [file join [file dirname [info script]] scratch.tcl]

set fail 0; set npass 0
proc check {name got exp} {
    global fail npass
    if {$got eq $exp} { puts "ok:   $name"; incr npass } \
    else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
set ::abortnames {}
proc group {name script} {
    if {[catch {uplevel 1 $script} e]} {
        puts "FAIL: group $name ABORTED -> $e : FAIL"
        puts $::errorInfo
        lappend ::abortnames $name
        incr ::fail
    }
}

set no_recent_files 1
set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
set scratch [test_scratch ase_op_measures]
set BASE 2e1e4ccb

proc om_table {} {
    set f [open [file join $::here data op_measures.txt] r]
    set t [read $f]
    close $f
    set out {}
    foreach ln [split $t "\n"] {
        if {[string trim $ln] eq {} || [string index $ln 0] eq {#}} continue
        lappend out $ln
    }
    return $out
}
proc om_read {rel} {
    set fh [open [file join $::repo $rel] r] ; set t [read $fh] ; close $fh
    return $t
}
proc om_outputs {text} {
    foreach ln [split $text "\n"] { if {[string match {outputs *} $ln]} { return [lindex $ln 1] } }
    return {}
}
proc om_enabled {text} {
    set en {}
    foreach ln [split $text "\n"] {
        if {![string match {analyses *} $ln]} continue
        foreach a [lindex $ln 1] {
            if {[dict exists $a enabled] && [dict get $a enabled] eq {1}} { lappend en [dict get $a type] }
        }
    }
    return $en
}
# A plain signal row: ASE-L's own save test, or a bare name (not a number).
proc om_plain {e} {
    if {[ase::output_is_save $e]} { return 1 }
    return [expr {[regexp {^[A-Za-z_#][A-Za-z0-9_.:#$<>\[\]]*$} $e] && ![string is double -strict $e]}]
}
set ROWS [om_table]

# =============================================================================
# OM1 -- THE TABLE
# =============================================================================
group OM1 {
    set nostate {} ; set nconv 0 ; set nop 0 ; set npr 0 ; set nstay 0
    foreach r $ROWS {
        lassign $r rel idx name old new why
        if {![file isfile [file join $repo $rel]]} { lappend nostate $rel }
        if {$new eq {}} { incr nstay ; continue }
        incr nconv
        if {$why eq {op-only}} { incr nop } elseif {[string match {print after op in *} $why]} { incr npr }
    }
    check "OM1 the table is read and every state it names is committed (rows > 0, states it could not open)" \
        [list [expr {[llength $ROWS] > 0}] $nostate] {1 {}}
    check "OM1 not vacuous: converted rows of BOTH kinds of evidence (op-only bench; printed after op) and rows that stay all exist, and every converted row names its evidence (op-only > 0, print > 0, stay > 0, converted rows with neither)" \
        [list [expr {$nop > 0}] [expr {$npr > 0}] [expr {$nstay > 0}] [expr {$nconv - $nop - $npr}]] {1 1 1 0}
}

# =============================================================================
# OM2 -- THE COMMITTED ROWS HOLD THE TABLE'S TEXT
# =============================================================================
group OM2 {
    set cache [dict create] ; set wrong {} ; set nconv 0
    foreach r $ROWS {
        lassign $r rel idx name old new why
        if {![dict exists $cache $rel]} { dict set cache $rel [om_outputs [om_read $rel]] }
        set o [lindex [dict get $cache $rel] $idx]
        set want [expr {$new eq {} ? $old : $new}]
        if {$new ne {}} { incr nconv }
        set got [list [ase::state_get $o name] [string trim [ase::state_get $o expr]]]
        if {$got ne [list $name $want]} { lappend wrong "$rel#$idx: $got != [list $name $want]" }
    }
    check "OM2 every converted row is committed as its measure and every row that stays as its old text, name unchanged (rows that differ, first five)" \
        [list [llength $wrong] [lrange $wrong 0 4]] {0 {}}
}

# =============================================================================
# OM3 -- THE SPELLING
# =============================================================================
group OM3 {
    set bad {} ; set tabs {} ; set ndoor 0 ; set nbare 0 ; set nwrap 0
    foreach r $ROWS {
        lassign $r rel idx name old new why
        if {$new eq {}} continue
        if {[regexp {^([vViI])\((.*)\)$} $old -> f sig]} {
            incr nwrap
            set want "[string tolower $f]dc($sig)"
        } else {
            incr nbare
            set want "vdc($old)"
        }
        if {$new ne $want} { lappend bad "$rel#$idx: $old -> $new, want $want" }
        if {[ase::output_tab $new] ne {measures}} { lappend tabs "$rel#$idx: $new" }
        if {[lindex [ase::output_admit measures $new] 0] eq {ok}} { incr ndoor }
    }
    check "OM3 every new text is the old row's OWN signal, its spelling and case kept, under vdc() for a voltage or a bare node and idc() for a current: v(CLK) -> vdc(CLK), I(Vce) -> idc(Vce), Vc -> vdc(Vc) (rows that differ)" \
        $bad {}
    check "OM3 ...both shapes were converted (wrapped saves > 0, bare nodes > 0), and every new text sorts into Measures and its door admits it (rows that do not; rows the door refused)" \
        [list [expr {$nwrap > 0}] [expr {$nbare > 0}] $tabs [expr {$nwrap + $nbare - $ndoor}]] {1 1 {} 0}
}

# =============================================================================
# OM4 -- COVERAGE, without the tool
# =============================================================================
group OM4 {
    set conv [dict create] ; set keys [dict create]
    foreach r $ROWS {
        lassign $r rel idx name old new
        dict set keys "$rel#$idx" 1
        if {$new ne {}} { dict set conv "$rel#$idx" $new }
    }
    set lst {}
    catch {set lst [split [string trim [exec git -C $repo ls-files *.state]] "\n"]}
    if {$lst eq {}} { set lst [lmap f [glob -nocomplain -directory $repo */xschem_libs/*/*/*/*.state] {string range $f [string length $repo/] end}] }
    set want [dict create] ; set nop 0
    foreach rel $lst {
        set t [om_read $rel]
        if {{op} ni [om_enabled $t]} continue
        incr nop
        set i -1
        foreach o [om_outputs $t] {
            incr i
            set e [string trim [ase::state_get $o expr]]
            # a plain row, or an operating-point measure of one signal -- so a
            # converted row the table forgot is missed here, not passed
            if {[om_plain $e] || [regexp -nocase {^[vi]dc\([^()]*\)$} $e]
                || [dict exists $conv "$rel#$i"]} { dict set want "$rel#$i" 1 }
        }
    }
    set missing {} ; set extra {}
    foreach k [dict keys $want] { if {![dict exists $keys $k]} { lappend missing $k } }
    foreach k [dict keys $keys] { if {![dict exists $want $k]} { lappend extra $k } }
    check "OM4 the table holds EXACTLY the plain signal rows (a save or a bare name) and the one-signal vdc()/idc() rows of every committed bench whose operating point is enabled -- derived here by ASE-L's own save test, not the tool's (benches > 0; rows it lacks; rows it holds that are not such a row)" \
        [list [expr {$nop > 0}] [lrange $missing 0 4] [lrange $extra 0 4]] {1 {} {}}
}

# =============================================================================
# OM5 -- OBVIOUSNESS, without the tool
# =============================================================================
# The original's .control text as one string; for an exact token `e`, whether
# some `print` line naming it follows an `op` with no other analysis between.
proc om5_printed_after_op {orel e} {
    if {$orel eq {} || ![file isfile [file join $::repo $orel]]} { return 0 }
    set s [om_read $orel]
    set hit 0
    foreach blk [regexp -all -inline -nocase {\.control\M.*?\.endc} $s] {
        set state none
        foreach ln [split [string map {"\n+" " "} $blk] "\n"] {
            set w [regexp -all -inline {\S+} $ln]
            set h [string tolower [lindex $w 0]]
            if {$h in {op dc ac tran noise pz tf sens disto reset}} { set state $h ; continue }
            if {$h eq {print} && $state eq {op} && [lsearch -exact [lmap t [lrange $w 1 end] {string trim $t {"}}] $e] >= 0} {
                set hit 1
            }
        }
    }
    return $hit
}
proc om5_original {rel} {
    set p [file split $rel]
    if {![regsub {_ase$} [lindex $p 2] {} olib]} { return {} }
    return [file join [lindex $p 0] xschem_libs $olib [lindex $p 3] schematic [lindex $p 3].sch]
}
# The port pins the bench's own schematic places, counted by xschem itself
# (each instance's symbol `type`), not by a text scan: a cell with ports is a
# circuit some bench instantiates, and run alone its inputs float.
proc om5_ports {rel} {
    if {[dict exists $::om5_pc $rel]} { return [dict get $::om5_pc $rel] }
    set p [file split $rel]
    xschem load [file join $::repo [lindex $p 0] xschem_libs [lindex $p 2] [lindex $p 3] schematic [lindex $p 3].sch]
    set n 0
    for {set i 0} {$i < [xschem get instances]} {incr i} {
        if {[xschem getprop instance $i cell::type] in {ipin opin iopin}} { incr n }
    }
    dict set ::om5_pc $rel $n
    return $n
}
set ::om5_pc [dict create]
group OM5 {
    set bad {} ; set nno 0 ; set npr 0 ; set nop 0 ; set cellbad {} ; set ncell 0 ; set nbench 0
    foreach r $ROWS {
        lassign $r rel idx name old new why
        set en [om_enabled [om_read $rel]]
        set pr [om5_printed_after_op [om5_original $rel] $old]
        if {$why eq {op-only} || [string match {* (op-only)} $why]} {
            incr nop
            if {$en ne {op}} { lappend bad "$rel#$idx says op-only, bench enables $en" }
            set np [om5_ports $rel]
            if {[regexp {^not a test bench: the cell places (\d+) port pins} $why -> said]} {
                incr ncell
                if {$np == 0 || $said != $np} { lappend cellbad "$rel#$idx says $said port pins, xschem counts $np" }
            } elseif {$np > 0} {
                lappend cellbad "$rel#$idx: op-only on a cell with $np port pins, [expr {$new eq {} ? {kept} : {converted}}] as '$why'"
            } elseif {$new ne {}} { incr nbench }
        } elseif {[string match {print after op in *} $why] || [string match {* (print after op in *} $why]} {
            incr npr
            if {$en eq {op} || {op} ni $en || !$pr} { lappend bad "$rel#$idx says printed after op: enabled $en, printed $pr" }
        } elseif {[string match {not obvious: *} $why]} {
            incr nno
            if {$en eq {op} || {op} ni $en || $pr} { lappend bad "$rel#$idx left not obvious: enabled $en, printed after op $pr" }
        } else {
            lappend bad "$rel#$idx: no evidence or reason: $why"
        }
    }
    check "OM5 every row's evidence holds, re-derived from the bench and its original by this suite's own scan: an op-only row's bench enables ONLY op; a printed row's bench enables op and more, and its original prints that exact text after op; a row left not obvious has no such print (rows that disagree)" \
        $bad {}
    check "OM5 ...and every kind was judged (op-only > 0, printed > 0, not obvious > 0)" \
        [list [expr {$nop > 0}] [expr {$npr > 0}] [expr {$nno > 0}]] {1 1 1}
    check "OM5 an op-only bench is evidence only when the cell IS a test bench: no row converted on op-only alone sits on a cell whose schematic places a port pin (ipin, opin, iopin, counted by xschem's own symbol types), and every row kept as 'not a test bench' sits on one, with the count it states (rows that disagree)" \
        $cellbad {}
    check "OM5 ...not vacuous: op-only rows converted on a test bench > 0, rows kept because the cell is not a test bench > 0" \
        [list [expr {$nbench > 0}] [expr {$ncell > 0}]] {1 1}
}

# =============================================================================
# OM6 -- ONLY THE EXPR FIELDS MOVED (git)
# =============================================================================
if {[catch {exec git -C $repo cat-file -e $BASE^{commit}}]} {
    puts "skip: OM6 (no git history for $BASE in this checkout)"
} else {
    group OM6 {
        set bystate [dict create]
        foreach r $ROWS {
            lassign $r rel idx name old new
            if {$new ne {}} { dict lappend bystate $rel [list $idx $old $new] }
        }
        set differ {} ; set oldwrong {}
        dict for {rel chg} $bystate {
            set base [exec -keepnewline git -C $repo show $BASE:$rel]
            set outs [om_outputs $base]
            foreach c $chg {
                lassign $c idx old new
                set o [lindex $outs $idx]
                if {[string trim [dict get $o expr]] ne $old} { lappend oldwrong "$rel#$idx" }
                dict set o expr $new
                lset outs $idx $o
            }
            set lines {}
            foreach ln [split $base "\n"] {
                if {[string match {outputs *} $ln]} { set ln "outputs [list $outs]" }
                lappend lines $ln
            }
            if {[join $lines "\n"] ne [om_read $rel]} { lappend differ $rel }
        }
        check "OM6 every touched state is its $BASE text with only the converted rows' expr replaced, byte for byte, and every table row's old text is the row at $BASE (states touched > 0; states that differ; rows whose old text is not git's)" \
            [list [expr {[dict size $bystate] > 0}] $differ $oldwrong] {1 {} {}}
    }
}

# =============================================================================
# OM7 -- THE REAL SIMULATOR, ON THE BUNDLED PDK BENCHES
# =============================================================================
proc om_registry_ngspice {} {
    set f [file join [test_real_home] .xschem ase_simulators]
    if {![file readable $f]} { return {} }
    set fh [open $f r] ; set t [read $fh] ; close $fh
    foreach ln [split $t "\n"] {
        if {[regexp {^\s*ase::sim_reg[i]ster\s+(\S+)\s+(\S+)} $ln -> nm path]} {
            if {[file executable $path]} { return $path }
        }
    }
    return {}
}
# ngspice's own print of each text at the operating point: the run's own
# rendered deck, run again with `print` lines right after its `op` and its
# results written beside it.  Answers {printed raw} per text, `raw` being that
# second run's own vector -- a mismatch bench draws new numbers every run, so
# a print is held to the run that printed it.
proc om_print {deck texts vecs dir} {
    set fh [open $deck r] ; set d [read $fh] ; close $fh
    set raw2 [file join $dir om_print.raw]
    set out {}
    set put 0
    foreach ln [split $d "\n"] {
        if {[regexp {^(\s*write)\s} $ln -> w]} { set ln "$w $raw2" }
        lappend out $ln
        if {!$put && [regexp {^\s*op\s*$} $ln]} {
            foreach t $texts { lappend out "print $t" }
            set put 1
        }
    }
    set pf [file join $dir om_print.cir]
    set fh [open $pf w] ; puts -nonewline $fh [join $out "\n"] ; close $fh
    file delete -force $raw2
    catch {exec env -u DISPLAY HOME=$::scratch timeout 120 $::NG -b $pf 2>@1} log
    catch {xschem raw clear}
    set rd [expr {[file isfile $raw2] && ![catch {xschem raw read $raw2 op}]}]
    set ans {}
    foreach t $texts v $vecs {
        set re "^[string map {( \\( ) \\) . \\.} [string tolower $t]] = (\\S+)"
        set p NOPRINT
        regexp -line -nocase $re $log -> p
        set r NORAW
        if {$rd} { catch {set r [lindex [xschem raw values $v 0] 0]} }
        lappend ans [list $p $r]
    }
    catch {xschem raw clear}
    return $ans
}
# `v` agrees with `ref` to `digits` significant digits: within `half` of the
# last one (one rounding is 0.5).
proc om_near {v ref digits {half 0.5}} {
    if {![string is double -strict $v] || ![string is double -strict $ref]} { return 0 }
    if {$ref == 0} { return [expr {$v == 0}] }
    set ulp [expr {pow(10, floor(log10(abs($ref))) - ($digits - 1))}]
    return [expr {abs($v - $ref) <= $half * $ulp * (1 + 1e-9)}]
}
set NG [om_registry_ngspice]
if {$NG eq {}} {
    puts "skip: OM7 -- no executable ngspice registered in [file join [test_real_home] .xschem ase_simulators], so the real-bench rows did not run"
} else {
    group OM7 {
        source [file join $repo tools migrate op_measures_bench.tcl]
        opm::setup $repo $NG
        set bystate [dict create]
        foreach r $ROWS {
            lassign $r rel idx name old new why
            if {$new ne {} || [string match {not in this circuit:*} $why]
                || [string match {stays a save:*} $why]} {
                dict lappend bystate $rel $r
            }
        }
        set norun {} ; set notnum {} ; set rawoff {} ; set prtoff {} ; set same {}
        set absent {} ; set pair {} ; set nconv 0 ; set nbench 0 ; set shown {}
        dict for {rel rs} $bystate {
            set k [string map {/ %} $rel]
            set dir [file join $::scratch run $k]
            set r [opm::run $repo $rel $dir]
            set conv [lsearch -all -inline -index 4 -not -exact $rs {}]
            if {[llength $conv]} { incr nbench }
            if {[dict get $r rc] ne {0}} { lappend norun "$rel: [dict get $r rc] [dict get $r why]" ; continue }
            set raw [dict get $r raw]
            set res [dict get $r results]
            set have [dict get $r opvars]
            set cells {} ; set vecs {} ; set olds {}
            foreach c $conv {
                lassign $c - idx name old new
                incr nconv
                # the cell the Measures tree shows: the row must BE in that
                # tree (a save has no Value column), and its Value is what
                # the populate writes there
                set outs [dict get $r outputs]
                set o [lindex $outs $idx]
                if {$idx ni [ase::ui::measures_order $outs $res 0]} {
                    set cell "NOT IN MEASURES (tab [ase::output_tab [ase::state_get $o expr]])"
                } else {
                    # the number the populate hands ase::format_value, whose
                    # engineering spelling is display only
                    set cell [ase::ui::output_value $o $res]
                    if {$cell eq {}} { set cell BLANK }
                }
                lappend shown "[lindex [file split $rel] 3] $new=$cell"
                if {![string is double -strict $cell]} { lappend notnum "$rel#$idx $new: $cell" ; continue }
                # the results file's own vector, at full precision
                regexp {^(.)dc\((.*)\)$} $new -> f sig
                set vn [lindex $have [lsearch -exact -nocase $have "$f\($sig\)"]]
                catch {xschem raw clear}
                xschem raw read $raw op
                set rv [lindex [xschem raw values $vn 0] 0]
                catch {xschem raw clear}
                set ev [calc::eval_text $new $raw {}]
                # the Calculator answers `%.8g` (eight digits) and the cell is
                # that answer again through `%.6e` (seven): rounded twice, so
                # within 0.5 + 0.05 of its last digit -- measured on the
                # mismatch bench, whose draws land on the boundary; the raw's
                # own vector is full precision
                if {![dict get $ev ok] || ![om_near [dict get $ev value] $rv 8]
                    || ![om_near $cell $rv 7 0.55]} {
                    lappend rawoff "$rel#$idx $new: cell $cell, evaluated $ev, raw $vn=$rv"
                }
                lappend cells $cell
                lappend vecs $vn
                lappend olds [expr {[regexp {^[vViI]\(} $old] ? $old : "v($old)"}]
            }
            if {[llength $olds]} {
                # held to as many digits as the print itself carries
                foreach pr [om_print [dict get $r deck] $olds $vecs $dir] t $olds {
                    lassign $pr p rv2
                    set dg 0
                    regexp {^-?([0-9])\.?([0-9]*)} $p -> d1 dr
                    catch {set dg [expr {1 + [string length $dr]}]}
                    if {$dg < 5 || ![om_near $p $rv2 $dg]} { lappend prtoff "$rel $t: print $p, raw $rv2" }
                }
                if {[llength [lsort -unique $cells]] != [llength $cells]} {
                    lappend same "$rel: [list $olds] show [list $cells]"
                }
            }
            foreach c $rs {
                lassign $c - idx name old new why
                if {[string match {not in this circuit:*} $why]} {
                    regexp {holds no (\S+)} $why -> vn
                    if {[lsearch -exact -nocase $have $vn] >= 0} { lappend absent "$rel#$idx: $vn is there now" }
                } elseif {[string match {stays a save:*} $why]} {
                    regexp {^.\((.*)\)$} $old -> sig
                    set ev [calc::eval_text "vdc($sig)" $raw {}]
                    if {[dict get $ev ok]} { lappend pair "$rel#$idx: vdc($sig) now reads [dict get $ev value]" }
                }
            }
        }
        foreach s $shown { puts "note: OM7 shown $s" }
        check "OM7 every bench holding a converted row RUNS on the registry ngspice -- ASE-L's pre-flight admits each measure, the simulator exits 0 (benches > 0; benches that did not)" \
            [list [expr {$nbench > 0}] $norun] {1 {}}
        check "OM7 every converted row is in the MEASURES tree and the Value cell that tree shows is a NUMBER -- not a save without a value, not a refusal, not wave, not blank (rows > 0; rows that are not)" \
            [list [expr {$nconv > 0}] $notnum] {1 {}}
        check "OM7 ...and it is the results file's OWN operating-point vector of that signal (xschem raw values): the Calculator's answer agrees to its eight digits and the cell to its seven (rows that differ)" \
            $rawoff {}
        check "OM7 ...and that vector is what ngspice's own print of the author's text gives at the operating point, on the bench's own deck run again (rows whose print and vector differ)" \
            $prtoff {}
        check "OM7 DISTINCTNESS: on each bench the converted rows' cells differ pairwise as shown, so no row could pass the comparisons above by reading another row's signal (benches with a repeated cell)" \
            $same {}
        check "OM7 the rows that stay for a measured reason still have it: a 'not in this circuit' signal is still absent from the bench's operating point, and the Calculator still reads no vdc(a,b) (rows whose reason no longer holds -- convert them)" \
            [list $absent $pair] {{} {}}
    }
}

catch {xschem raw clear}
check "EVERY band above this one RAN TO ITS END (names of any abandoned band)" \
    [list [llength $::abortnames] $::abortnames] {0 {}}

if {$fail == 0} {
    puts "OVERALL: ok ($npass checks)"
    puts "RESULT: ALL PASS ($npass checks)"
} else {
    puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
