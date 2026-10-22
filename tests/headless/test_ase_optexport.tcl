# tests/headless/test_ase_optexport.tcl -- ASE-L Tools > Export for Optimizer
# (FAQ Q92): the deck, the manifest, measures.py / measures.tcl.
#
# The user's use case: an external optimizer keeps xschem OUT of its loop --
# topology fixed, only sizes change -- so it edits the deck and runs ngspice
# itself, then needs the measures. The export must give it the deck a Run
# writes, and values that match the Outputs pane BY CONSTRUCTION.
#
# Code   src/ase.tcl section "EXPORT FOR OPTIMIZER (FAQ Q92)" (ase::optexport,
#        ase::optexport_compose, ase::optexport_varlines, ase::optexport_measure,
#        ase::optexport_dir_verdict); the ngspice backend's result_answers;
#        src/optexport_measures.py; src/optexport_measures.tcl
#
# Bands
#   OX1   the exported deck is render_deck's, run directory removed, nothing left
#   OX1r  drift fence: ase::run_deck's own deck, prefix removed, is byte-equal
#   OX2   manifest.json (read back by Python's json): key set, names, the
#         variable's deck line, every measure exactly once, disabled rows
#   OX2c  a name collision refuses and writes nothing
#   OX2d  the target directory verdict; re-export replaces only its own files
#   OX3   in-process: optexport_measure's JSON is result_answers, and each
#         record formats to result_probe's cell (same double, %.6e)
#   OX3m  measures.py's parse_meas is ase::meas_parse, key for key; the
#         meas-only path (no xschem) equals the xschem path
#   OX4   END TO END (ngspice + python): fresh directories, every measure
#         equal to result_answers / meas_results as a double
#   OX5   an override moves only what depends on it; write_deck refusals
#   OX6   measures.py starts xschem with no DISPLAY and a private HOME
#   OX7   refusals and harness failures never come back as a number
#   OX8   datasets: two transients in one run are reported and warned, dataset 0 used
#   OX9   README.txt names what the manifest names
#   OX10  the .spiceinit path equals what a Run writes; prepare_rundir copies it
#   OX11  a second run in the same directory reports the second run (M11)
#   OX12  the Measurements-only path (no xschem launched) equals ase::meas_results
#   OX12b exit 0 when every measure is a number or a wave; --log carries the
#         case rule (casemode=distinguish) exactly as the Outputs pane applies it
#   OX13  a second ngspice run over un-deleted results raises MixedResults;
#         run() raises SimulationFailed on a nonzero ngspice exit
#   OX14  harness failures: a broken measures_state.tcl names xschem's error,
#         and a crashing first launch is retried once and said (issue 1706)
#
# REGISTERED IN `hcases`: nothing here needs a display. ngspice is the ASE-L
# registry's (read-only from the real HOME, as test_ase_outputs_eval's OE7);
# when it or python3 is missing the rows needing it print ONE uppercase
# `SKIP:` line naming them and do not run.
#
# ⚠ EVERY CHILD runs as `env -u DISPLAY HOME=<scratch> timeout <n> ...`, and
# every launch that starts xschem is spaced >= 2.2 s from the previous one
# (issue 1706: same-second launches can crash) by ox_gap.
#
# Standalone from the repo ROOT, armed (throwaway HOME, never $DISPLAY):
#   tests/headless/run_suites.sh --nogui test_ase_optexport

source [file join [file dirname [info script]] scratch.tcl]

set fail 0; set npass 0
proc check {name got exp} {
    global fail npass
    if {$got eq $exp} { puts "ok:   $name"; incr npass } \
    else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc pcall {args} {
    if {[catch {uplevel 1 $args} r]} { return "ERR:[string map [list \{ ( \} )] $r]" }
    return $r
}
set ::abortnames {}
proc group {name script} {
    # code 2 is a band's own `return` (a self-skip), not an abort
    if {[catch {uplevel 1 $script} e] == 1} {
        puts "FAIL: group $name ABORTED -> $e : FAIL"
        puts $::errorInfo
        lappend ::abortnames $name
        incr ::fail
    }
}

set no_recent_files 1
set here [file normalize [file dirname [info script]]]
set scratch [test_scratch ase_optexport]
set fixture [file join $here data calc_fixture.raw]
set XS [file normalize [info nameofexecutable]]
catch {ase::sim_clear}

proc ox_registry_ngspice {} {
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
set NG [ox_registry_ngspice]
set PY [lindex [auto_execok python3] 0]

# ─── issue 1706: space every xschem launch >= 2.2 s from the previous one ───
set ::ox_last [clock milliseconds]
proc ox_gap {} {
    set wait [expr {2200 - ([clock milliseconds] - $::ox_last)}]
    if {$wait > 0} { after $wait }
    set ::ox_last [clock milliseconds]
}

# Run a child: {rc stdout stderr}. DISPLAY removed unless `envs` plants one.
proc ox_run {envs cmd {cwd {}} {tmo 120}} {
    set ef [file join $::scratch stderr.[clock microseconds]]
    set save [pwd]
    if {$cwd ne {}} { cd $cwd }
    set rc [catch {exec env -u DISPLAY -u WAYLAND_DISPLAY HOME=$::scratch {*}$envs \
                      timeout $tmo {*}$cmd 2> $ef} out opts]
    cd $save
    set code 0
    if {$rc} {
        set ec [dict get $opts -errorcode]
        if {[lindex $ec 0] eq {CHILDSTATUS}} { set code [lindex $ec 2] } else { set code -1 }
        regsub {\n?child process exited abnormally$} $out {} out
    }
    set err {}
    catch {set f [open $ef r] ; set err [read $f] ; close $f}
    file delete -force $ef
    return [list $code $out $err]
}
proc ox_py {envs args} {
    return [ox_run $envs [concat [list $::PY] $args]]
}

# JSON -> a Tcl value, by Python's own json module: an object is a dict, an
# array a list, a string itself, null the word null, a number its repr.
set ::ox_j2t [file join $scratch j2t.py]
set f [open $::ox_j2t w]
puts $f {import json, sys, re
def bal(s):
    d = 0
    for c in s:
        d += (c == '{') - (c == '}')
        if d < 0: return False
    return d == 0
def q(s):
    if s == '': return '{}'
    if re.fullmatch(r'[^\s{}\[\]$"\\;#]+', s): return s
    if '\\' not in s and bal(s): return '{' + s + '}'
    return ''.join('\\' + c if c in '\\"[]${};# ' else ('\\n' if c == '\n' else ('\\t' if c == '\t' else c)) for c in s)
def t(v):
    if v is None: return 'null'
    if isinstance(v, bool): return 'true' if v else 'false'
    if isinstance(v, (int, float)): return repr(v)
    if isinstance(v, str): return q(v)
    if isinstance(v, list): return q(' '.join(t(x) for x in v)) if v else '{}'
    return q(' '.join(q(k) + ' ' + t(x) for k, x in v.items())) if v else '{}'
src = sys.argv[1]
text = sys.stdin.read() if src == '-' else open(src, encoding='utf-8').read()
v = json.loads(text)
if isinstance(v, list): sys.stdout.write(' '.join(t(x) for x in v))
elif isinstance(v, dict): sys.stdout.write(' '.join(q(k) + ' ' + t(x) for k, x in v.items()))
else: sys.stdout.write(t(v))}
close $f
# The op plot's value of one variable, by Python's struct: a reader that
# shares no code with ase::raw_scalars or xschem's raw loader.
set ::ox_rawop [file join $scratch rawop.py]
set f [open $::ox_rawop w]
puts $f {import struct, sys
data = open(sys.argv[1], 'rb').read()
want = sys.argv[2].lower()
pos = 0
while pos < len(data):
    end = data.index(b'Binary:\n', pos)
    head = data[pos:end].decode('latin-1').split('\n')
    body = end + len(b'Binary:\n')
    nv = np = 0; names = []; name = ''; cx = False; invars = False
    for l in head:
        if l.startswith('Plotname:'): name = l[9:].strip()
        elif l.startswith('Flags:'): cx = 'complex' in l
        elif l.startswith('No. Variables:'): nv = int(l[14:])
        elif l.startswith('No. Points:'): np = int(l[11:])
        elif l.startswith('Variables:'): invars = True
        elif invars and l.strip(): names.append(l.split()[1].lower())
    size = nv * np * (16 if cx else 8)
    if name == 'Operating Point' and want in names:
        print(repr(struct.unpack_from('<%dd' % nv, data, body)[names.index(want)]))
        sys.exit(0)
    pos = body + size
sys.exit(1)}
close $f
proc ox_json {path} {
    lassign [ox_run {} [list $::PY $::ox_j2t $path]] rc out err
    if {$rc} { return "ERR:$err" }
    return $out
}
proc ox_jtext {text} {
    set p [file join $::scratch jt.[clock microseconds].json]
    set f [open $p w] ; fconfigure $f -encoding utf-8 ; puts -nonewline $f $text ; close $f
    set r [ox_json $p]
    file delete -force $p
    return $r
}
proc ox_get {d args} {
    if {[catch {dict get $d {*}$args} v]} { return ABSENT }
    return $v
}
proc ox_read {p} {
    if {![file isfile $p]} { return NOFILE }
    set f [open $p r] ; fconfigure $f -translation binary ; set t [read $f] ; close $f
    return $t
}

# ─── the fixture bench ───────────────────────────────────────────────────────
# r1 is 1.3k so the op values are not short decimals: a value rounded
# anywhere on its way out differs from the double (OX4's precision legs).
set NL "* ox\nv1 in 0 dc 1 pulse(0 1 1u 100n 100n 3u 8u)\nr1 in mid 1.3k\nr2 mid out 1k\nr3 out 0 {rr}\nc1 out 0 1n\n.param rr=1k\n.end\n"
proc ox_state {cell rundir} {
    set s [ase::state_default]
    dict set s simulator ngspice
    dict set s design [dict create lib ox cell $cell view schematic]
    dict set s rundir $rundir
    dict set s variables {{name rr value 2k}}
    dict set s analyses {{type op enabled 1} {type dc enabled 0} {type ac enabled 0}
                         {type tran enabled 1 stop 20u step 10n}}
    dict set s outputs {{name out expr v(out) save 1 plot 0}
                        {name vin expr {vdc(in) 1 *} save 0 plot 0}
                        {name dbl expr {vdc(mid) 2 *} save 0 plot 0}
                        {name cr expr {cross(vt(out), 0.1, 1, rising)} save 0 plot 0}
                        {name w expr {vt(out) 2 *} save 0 plot 0}
                        {name bad expr {v(nosuch) 2 *} save 0 plot 0}}
    dict set s measurements {{name vmax analysis tran kind max target v(out)}
                             {name vav analysis tran kind avg target v(out)}
                             {name vnever analysis tran kind when target v(out) value 5}
                             {name vold analysis tran kind max target v(in) enabled 0}}
    return $s
}
set R [file join $scratch r]
set E [file join $scratch e]
set ST [ox_state ox7 $R]

# =============================================================================
# OX1 -- THE EXPORTED DECK IS render_deck's, RUN DIRECTORY REMOVED
# =============================================================================
group OX1 {
    set res [pcall ase::optexport $ST $E [dict create netlist_text $::NL]]
    check "OX1 ase::optexport answers its dict (dir files counts warnings)" \
        [lsort [pcall dict keys $res]] {counts dir files warnings}
    set deck [ox_read [file join $E ox7_ase.spice]]
    set ref [pcall ase::backend::ngspice::render_deck $ST $::NL]
    set rel [string map [list "$::R/" {}] $ref]
    check "OX1 the exported deck equals render_deck of the same state with rundir R, R/ removed, byte for byte" \
        [expr {$deck eq $rel}] 1
    set bare {}
    foreach l [split $deck "\n"] {
        if {[regexp {^write\s+(\S+)} $l -> p]} { lappend bare $p }
    }
    check "OX1 it names neither R nor any scratch sentinel, carries no print line, and its write lines are bare, one per enabled analysis" \
        [list [string first $::R $deck] [string first asexp_ $deck] \
              [regexp -line {^print(\s|$)} $deck] $bare] \
        {-1 -1 0 {ox7_ase.raw ox7_ase.raw}}
    check "OX1 its .meas path is bare (the deck writes its results next to itself)" \
        [regexp -line {^echo ASE-MEAS >> ox7_ase\.meas$} $deck] 1
    set left [glob -nocomplain -directory [ase::optexport_sentinel_base] asexp_[pid]_*]
    check "OX1 the scratch sentinel directory no longer exists" $left {}
    check "OX1 the export did not touch the bench's run directory, dotfiles included" \
        [lsearch -all -inline -not -regexp [glob -nocomplain -tails -directory $::R * .*] {^\.\.?$}] {}
}

# =============================================================================
# OX1r -- DRIFT FENCE: ase::run_deck's own deck equals the export's
# =============================================================================
group OX1r {
    file mkdir $::R
    set nf [file join $::scratch ox7.spice]
    set f [open $nf w] ; puts -nonewline $f $::NL ; close $f
    set id [pcall ase::run_deck $::ST $nf]
    if {[string is integer -strict $id]} { catch {ase::wait $id} }
    set run [ox_read [file join $::R ox7_ase.spice]]
    set exp [ox_read [file join $::E ox7_ase.spice]]
    check "OX1r ase::run_deck wrote R/<cell>_ase.spice, and with R/ removed it equals the exported deck byte for byte (run_deck id $id)" \
        [list [expr {$run ne {NOFILE}}] [expr {[string map [list "$::R/" {}] $run] eq $exp}]] {1 1}
}

# =============================================================================
# OX2 -- THE MANIFEST
# =============================================================================
set MAN {}
group OX2 {
    if {$::PY eq {}} { return }
    set m [ox_json [file join $::E manifest.json]]
    set ::MAN $m
    check "OX2 manifest.json is JSON (Python's json.load) of protocol asexp-manifest/1" \
        [ox_get $m protocol] asexp-manifest/1
    check "OX2 its key set is exactly the documented one" [lsort [pcall dict keys $m]] \
        [lsort {protocol exported source xschem run_cwd deck predeck_file simulator artifacts
                delete_before_run variables measures disabled_measurements campaign limits warnings}]
    check "OX2 xschem is this binary (info nameofexecutable)" [ox_get $m xschem] $::XS
    set rstate $::ST
    check "OX2 deck, artifacts.raw and artifacts.meas are the file tails of deck_file, raw_file and meas_path" \
        [list [ox_get $m deck] [ox_get $m artifacts raw] [ox_get $m artifacts meas]] \
        [list [file tail [ase::deck_file $rstate]] \
              [file tail [ase::backend::ngspice::raw_file $rstate]] \
              [file tail [ase::meas_path $rstate]]]
    set deck [split [ox_read [file join $::E ox7_ase.spice]] "\n"]
    set vars [ox_get $m variables]
    set v0 [lindex $vars 0]
    set ln [ox_get $v0 deck_line]
    set nl1k [lsearch -exact $deck {.param rr=1k}]
    check "OX2 the design variable's deck_line points at a line equal to deck_text = .param rr=2k, and not at the netlist's own .param rr=1k" \
        [list [llength $vars] [ox_get $v0 name] [ox_get $v0 nominal] [ox_get $v0 deck_text] \
              [expr {[string is integer -strict $ln] ? [lindex $deck [expr {$ln - 1}]] : "BAD:$ln"}] \
              [expr {$nl1k >= 0 && $ln != $nl1k + 1}]] \
        {1 rr 2k {.param rr=2k} {.param rr=2k} 1}
    set names {} ; set srcs {}
    foreach x [ox_get $m measures] {
        lappend names [ox_get $x name]
        set rd [ox_get $x reader]
        lappend srcs "[ox_get $x name]:[ox_get $x source]:$rd"
    }
    set want {}
    foreach o [dict get $::ST outputs] {
        set ex [dict get $o expr]
        set rd [expr {[ase::result_source ngspice $ex] eq {raw} ? {raw} : {calc}}]
        lappend want "[dict get $o name]:calc:$rd"
    }
    foreach r [dict get $::ST measurements] {
        if {[ase::meas_enabled $r]} { lappend want "[dict get $r name]:meas:ABSENT" }
    }
    check "OX2 every Outputs row and every ENABLED Measurements row appears exactly once, in pane order, source/reader as ase::result_source predicts (population [llength $names])" \
        [list [expr {[llength $names] > 0}] $srcs] [list 1 $want]
    check "OX2 the disabled Measurements row is listed only in disabled_measurements" \
        [list [ox_get $m disabled_measurements] [expr {"vold" in $names}]] {vold 0}
    set an {}
    foreach x [ox_get $m measures] { lappend an [ox_get $x analysis] }
    check "OX2 each measure's analysis: predicted for Outputs rows (op op op tran tran, null for the refusal), the row's own for Measurements" \
        $an {op op op tran tran null tran tran tran}
    check "OX2 the simulator carries its argv words and the requested casemode; delete_before_run names the artifacts a Run deletes" \
        [list [ox_get $m simulator args] [ox_get $m simulator casemode_requested] [ox_get $m delete_before_run]] \
        {-b fold {ox7_ase.raw ox7_ase.meas ox7_ase.plotmap ox7_ase.raw.ckpt ox7_ase.raw.ckpt.tmp .spiceinit}}
}

# =============================================================================
# OX2c -- A NAME COLLISION REFUSES AND WRITES NOTHING
# =============================================================================
group OX2c {
    set s $::ST
    dict set s outputs [linsert [dict get $s outputs] end {name VMAX expr {vdc(in) 3 *} save 0 plot 0}]
    set d [file join $::scratch e_coll]
    set r [pcall ase::optexport $s $d [dict create netlist_text $::NL]]
    check "OX2c an Outputs name equal, case-folded, to a Measurements name refuses with a sentence naming both, and writes no file" \
        [list [string match ERR:* $r] [expr {[string first VMAX $r] >= 0 && [string first vmax $r] >= 0}] \
              [glob -nocomplain -directory $d *]] {1 1 {}}
    set s $::ST
    dict set s outputs [linsert [dict get $s outputs] end {name OUT expr {vdc(in) 3 *} save 0 plot 0}]
    set ms [pcall ase::optexport_measures $s]
    set nm {}
    if {![string match ERR:* $ms]} { foreach x [lindex $ms 0] { lappend nm [dict get $x name] } }
    check "OX2c two OUTPUTS rows differing only in case ('out', 'OUT') are two measures: JSON keys, Python keys and the pane's keys are case-sensitive" \
        [list [string match ERR:* $ms] [lsearch -all -inline -nocase $nm out]] {0 {out OUT}}
    set s $::ST
    dict set s outputs [linsert [dict get $s outputs] end {name out expr {vdc(in) 3 *} save 0 plot 0}]
    set r [pcall ase::optexport_measures $s]
    check "OX2c two Outputs rows with the SAME name refuse, saying so" \
        [list [string match ERR:* $r] [expr {[string first {both named 'out'} $r] >= 0}]] {1 1}
}

# =============================================================================
# OX2d -- THE TARGET DIRECTORY
# =============================================================================
group OX2d {
    set ok {}
    file mkdir [file join $::scratch empty]
    set foreign [file join $::scratch foreign]
    file mkdir $foreign
    set f [open [file join $foreign notes.txt] w] ; puts $f x ; close $f
    foreach {label dir} [list R $::R under [file join $::R sub] foreign $foreign \
                             empty [file join $::scratch empty] previous $::E \
                             missing [file join $::scratch notyet]] {
        lappend ok $label [lindex [ase::optexport_dir_verdict $::ST $dir] 0]
    }
    check "OX2d the verdict refuses R, a path under R and a directory with a foreign file; accepts an empty, a missing and a previous export's directory" \
        $ok {R refuse under refuse foreign refuse empty ok previous ok missing ok}
    set sd $::ST
    dict set sd rundir {}
    set dflt [ase::rundir_default_preview]
    set existed [file exists $dflt]
    check "OX2d a bench on the SHARED default run directory ($dflt) refuses it and a path under it, without creating it" \
        [list [expr {$dflt ne {}}] [lindex [ase::optexport_dir_verdict $sd $dflt] 0] \
              [lindex [ase::optexport_dir_verdict $sd [file join $dflt sub]] 0] \
              [lindex [ase::optexport_dir_verdict $sd [file join $::scratch elsewhere]] 0] \
              [expr {[file exists $dflt] == $existed}]] {1 refuse refuse ok 1}
    set before [lsort [glob -nocomplain -tails -directory $::E * .*]]
    set t0 [file mtime [file join $::E manifest.json]]
    after 1100
    set r [pcall ase::optexport $::ST $::E [dict create netlist_text $::NL]]
    set after [lsort [glob -nocomplain -tails -directory $::E * .*]]
    check "OX2d re-exporting over a previous export replaces exactly its own files and nothing else" \
        [list [expr {$before eq $after}] [expr {[file mtime [file join $::E manifest.json]] > $t0}] \
              [lsort [dict get $r files]]] \
        [list 1 1 [lsort {ox7_ase.spice measures.py measures.tcl measures_state.tcl manifest.json README.txt}]]
    set f [open [file join $::E planted.txt] w] ; puts $f x ; close $f
    check "OX2d ...and a planted foreign file beside them makes it refuse" \
        [lindex [ase::optexport_dir_verdict $::ST $::E] 0] refuse
    file delete [file join $::E planted.txt]
}

# =============================================================================
# OX3 -- IN-PROCESS: optexport_measure's JSON IS result_answers, AND IT
# FORMATS TO result_probe's CELL
# =============================================================================
set skipped {}
if {$PY eq {}} {
    lappend skipped "OX2 OX3 OX3m OX4 OX5 OX6 OX7 OX8 OX9 OX10 -- no python3 on PATH"
}
group OX3 {
    if {$::PY eq {}} { return }
    set d [file join $::scratch fx]
    file mkdir $d
    file copy -force $::fixture [file join $d fx_ase.raw]
    set s [ase::state_default]
    dict set s simulator ngspice
    dict set s design [dict create lib ox cell fx view schematic]
    dict set s outputs {{name lp expr v(lp) save 1}
                        {name dc expr v(dcmid) save 1}
                        {name gm expr @m1[gm] save 1}
                        {name w expr vt(lp) save 1}
                        {name x expr {cross(vt(lp), 0.5, 1, rising)} save 1}
                        {name y expr {idc(@m1[id]) 3 /} save 1}
                        {name bad expr {vdc(nosuch) 2 *} save 1}
                        {name ghost expr v(nosuchnode) save 1}}
    set txt [pcall ase::optexport_measure $s $d {} fold]
    set j [ox_jtext $txt]
    set outs [ox_get $j outputs]
    check "OX3 optexport_measure answers JSON Python accepts, protocol asexp-results/1, complete, one outputs record per Outputs row" \
        [list [ox_get $j protocol] [ox_get $j complete] [llength $outs]] \
        [list asexp-results/1 true [llength [dict get $s outputs]]]
    set ps $s
    dict set ps rundir $d
    set probe [pcall ase::backend::ngspice::result_probe $ps {}]
    set bad {} ; set st {}
    foreach r $outs {
        set k [ox_get $r key]
        set status [ox_get $r status]
        lappend st $status
        set rec [dict create status $status value [ox_get $r value] msg [ox_get $r msg]]
        set cell [ase::backend::ngspice::result_answer_text $rec]
        if {$status eq {novalue}} {
            if {[dict exists $probe $k]} { lappend bad "$k shown although novalue" }
            continue
        }
        if {![dict exists $probe $k] || [dict get $probe $k] ne $cell} {
            lappend bad "$k: [ox_get $probe $k] vs $cell"
        }
        if {$status eq {number} && [format %.6e [ox_get $r value]] ne [dict get $probe $k]} {
            lappend bad "$k %.6e"
        }
    }
    check "OX3 every record formats to result_probe's cell (a number's %.6e IS the cell, so the pane and the export carry the same double); a novalue record is a key result_probe omits" \
        $bad {}
    check "OX3 the population covers number, wave, refused and novalue (statuses $st)" \
        [list [expr {"number" in $st}] [expr {"wave" in $st}] [expr {"refused" in $st}] [expr {"novalue" in $st}]] {1 1 1 1}
    set y {}
    foreach r $outs { if {[ox_get $r key] eq {y}} { set y $r } }
    check "OX3 a postfix number carries MORE than %.8g (Stage 0's full double): idc(@m1\[id\]) 3 / = [ox_get $y value]" \
        [expr {[string length [ox_get $y value]] > 12 && [ox_get $y value] != [format %.8g [ox_get $y value]]}] 1
    check "OX3 the results report the dataset count per analysis of the raw" \
        [ox_get $j datasets] {tran 2 ac 1 op 1}
}

# =============================================================================
# OX3m -- parse_meas IS ase::meas_parse; THE MEAS-ONLY PATH EQUALS XSCHEM'S
# =============================================================================
group OX3m {
    if {$::PY eq {}} { return }
    set text "ASE-MEAS\nVmax = 4.76525e-01 at= 2.0e-05\n\n  vav  =  2.05050e-01\nvmax = 5.00000e-01\nbad line\nx_1 = -3  tail words  \n"
    set mf [file join $::scratch planted.meas]
    set f [open $mf w] ; puts -nonewline $f $text ; close $f
    set code {import sys, json; sys.path.insert(0, sys.argv[1]); import measures; print(json.dumps(measures.parse_meas(open(sys.argv[2]).read())))}
    lassign [ox_py {} -I -c $code $::E $mf] rc out err
    set py [ox_jtext $out]
    set tcl [ase::meas_parse $text]
    set pyl {} ; set tl {}
    foreach k [lsort [dict keys $py]] { lappend pyl $k [dict get $py $k] }
    foreach k [lsort [dict keys $tcl]] { lappend tl $k [dict get $tcl $k] }
    check "OX3m measures.parse_meas equals ase::meas_parse key for key on mixed case, a blank line, a duplicate name and a tail (rc $rc $err)" \
        [list [expr {[llength $tl] > 4}] $pyl] [list 1 $tl]
}

# Real-run rows
set ngrows {OX4 OX5 OX6 OX7 OX8 OX10 OX11 OX12 OX12b OX13 OX14}
if {$NG eq {} && $PY ne {}} {
    lappend skipped "$ngrows -- no executable ngspice registered in [file join [test_real_home] .xschem ase_simulators]"
}
proc ox_ngrun {rundir {cmdenv {}}} {
    lassign [ox_py [list ASEXP_NGSPICE=$::NG] [file join $::F measures.py] --command --rundir $rundir] rc argv err
    set argv [split [string trim $argv] "\n"]
    lassign [ox_run {} $argv $rundir 120] nrc nout nerr
    set f [open [file join $rundir ng.log] w] ; puts -nonewline $f "$nout$nerr" ; close $f
    return [list $rc $argv $nrc]
}
set F [file join $scratch f]
if {$NG ne {} && $PY ne {}} {
group OX4 {
    file delete -force $::F
    file copy $::E $::F
    set G [file join $::scratch g]
    file delete -force $G
    file mkdir $G
    lassign [ox_py {} [file join $::F measures.py] --prepare $G] prc pout perr
    lassign [ox_ngrun $G] crc argv nrc
    check "OX4 --prepare wrote the deck into G, --command gave the registry ngspice's argv with the deck last, and ngspice ran in G (rc)" \
        [list $prc [file isfile [file join $G ox7_ase.spice]] $crc [lindex $argv 0] [lindex $argv end] $nrc] \
        [list 0 1 0 $::NG ox7_ase.spice 0]
    ox_gap
    lassign [ox_py {} [file join $::F measures.py] --rundir $G --json] mrc mout merr
    set py [ox_jtext $mout]
    set s $::ST
    dict set s rundir $G
    set recs [ase::backend::ngspice::result_answers $s fold]
    set meas [ase::meas_results ngspice $s]
    set probe [ase::backend::ngspice::result_probe $s {}]
    set bad {} ; set kinds {} ; set nums {}
    foreach r $recs {
        set k [dict get $r key] ; set v [ox_get $py $k]
        if {[dict get $r status] eq {number}} {
            if {![string is double -strict $v] || double($v) != double([dict get $r value])} {
                lappend bad "$k: $v vs [dict get $r value]"
            } elseif {[format %.6e $v] ne [dict get $probe $k]} {
                lappend bad "$k: %.6e vs [dict get $probe $k]"
            }
            lappend kinds "num:[dict get $r reader]:[expr {[calc::meas_split [dict get $r expr]] ne {} ? {verb} : {other}}]"
            lappend nums $v
        } else {
            if {[ox_get $v status] ne [dict get $r status] || [ox_get $v msg] ne [dict get $r msg]} {
                lappend bad "$k: $v vs [dict get $r status]/[dict get $r msg]"
            }
            lappend kinds [dict get $r status]
        }
    }
    foreach e $meas {
        lassign $e nm verdict val why
        if {$verdict eq {off}} continue
        set v [ox_get $py $nm]
        if {$verdict eq {ok}} {
            if {![string is double -strict $v] || double($v) != double($val)} { lappend bad "$nm: $v vs $val" }
            lappend kinds meas:num ; lappend nums $v
        } else {
            if {[ox_get $v status] ne $verdict || [ox_get $v msg] ne $why} { lappend bad "$nm: $v vs $verdict/$why" }
            lappend kinds meas:$verdict
        }
    }
    check "OX4 EVERY measure from python3 measures.py --json equals result_answers / ase::meas_results on the same rundir: a number as a double (and its %.6e the Outputs cell), a non-number by status and message (mismatches; exit $mrc $merr)" \
        [list [expr {[llength $kinds] == [llength [ox_get $::MAN measures]]}] $bad] {1 {}}
    set sorted [lsort -real -unique $nums]
    set minsp 1e99
    for {set i 1} {$i < [llength $sorted]} {incr i} {
        set a [lindex $sorted [expr {$i-1}]] ; set b [lindex $sorted $i]
        set sp [expr {abs($b - $a) / max(abs($a), abs($b), 1e-300)}]
        if {$sp < $minsp} { set minsp $sp }
    }
    check "OX4 NOT VACUOUS: at least 3 distinct numbers whose closest adjacent pair differs by more than 1e-6 relative (min spread $minsp), and every kind occurs: raw-reader, verb and postfix numbers, a meas number, a wave, a refusal and a meas failed ($kinds)" \
        [list [expr {[llength $sorted] >= 3}] [expr {$minsp > 1e-6}] \
              [expr {"num:raw:other" in $kinds}] [expr {"num:calc:verb" in $kinds}] \
              [expr {"num:calc:other" in $kinds}] [expr {"meas:num" in $kinds}] \
              [expr {"wave" in $kinds}] [expr {"refused" in $kinds}] [expr {"meas:failed" in $kinds}]] \
        {1 1 1 1 1 1 1 1 1}
    # PRECISION, against comparands that do NOT go through result_answers: the
    # raw-reader row against the raw's own double (Python's struct, a second
    # reader), the verb row against calc::eval_texts called directly.
    set rawp [file join $G ox7_ase.raw]
    lassign [ox_py {} -I $::ox_rawop $rawp v(out)] rrc rawv rerr
    set man {}
    foreach x [ox_get $::MAN measures] { if {[ox_get $x name] eq {cr}} { set man $x } }
    set et [lindex [calc::eval_texts [list [ox_get $man text]] $rawp [ox_get $man analysis] 0] 0]
    catch {xschem raw clear}
    set pout [ox_get $py out] ; set pcr [ox_get $py cr]
    check "OX4 FULL PRECISION: 'out' is bit-equal to the raw's own op double ($rawv, read by a second reader) and 'cr' to calc::eval_texts called directly ([ox_get $et value]); both differ from their own %.8g" \
        [list [expr {[string is double -strict $rawv] && [string is double -strict $pout] && $pout == $rawv}] \
              [expr {[dict get $et ok] && [string is double -strict $pcr] && $pcr == [dict get $et value]}] \
              [expr {[string is double -strict $pout] && $pout != [format %.8g $pout]}] \
              [expr {[string is double -strict $pcr] && $pcr != [format %.8g $pcr]}]] {1 1 1 1}
    check "OX4 the CLI exits 1 (the fixture has non-numbers by construction)" $mrc 1
    check "OX4 G holds the raw and the .meas, and neither E nor F does: the relative paths landed where ngspice ran" \
        [list [file isfile [file join $G ox7_ase.raw]] [file isfile [file join $G ox7_ase.meas]] \
              [glob -nocomplain -directory $::E *.raw *.meas] [glob -nocomplain -directory $::F *.raw *.meas]] \
        {1 1 {} {}}
    ox_gap
    lassign [ox_py {} [file join $::F measures.py] --rundir $G] trc tout terr
    set line {}
    foreach l [split $tout "\n"] { if {[string match "w\t*" $l]} { set line $l } }
    check "OX4 the default output is name<TAB>value, a non-number as !<status>" \
        [list $trc $line] [list 1 "w\t!wave\t"]
    set ::G $G
}

# =============================================================================
# OX5 -- AN OVERRIDE MOVES ONLY WHAT DEPENDS ON IT
# =============================================================================
group OX5 {
    set G2 [file join $::scratch g2]
    file delete -force $G2
    lassign [ox_py {} [file join $::F measures.py] --prepare $G2 --set rr=500] prc pout perr
    set a [split [ox_read [file join $::F ox7_ase.spice]] "\n"]
    set b [split [ox_read [file join $G2 ox7_ase.spice]] "\n"]
    set diff {}
    set i 0
    foreach la $a lb $b { incr i ; if {$la ne $lb} { lappend diff $i $lb } }
    set ln [ox_get [lindex [ox_get $::MAN variables] 0] deck_line]
    check "OX5 --prepare --set rr=500 changes exactly the variable's deck line" \
        [list $prc $diff] [list 0 [list $ln {.param rr=500}]]
    check "OX5 the written deck keeps the exported deck's permissions (not mkstemp's 0600)" \
        [file attributes [file join $G2 ox7_ase.spice] -permissions] \
        [file attributes [file join $::F ox7_ase.spice] -permissions]
    ox_ngrun $G2
    ox_gap
    lassign [ox_py {} [file join $::F measures.py] --rundir $G2 --json] mrc mout merr
    set p2 [ox_jtext $mout]
    set ::P2 $p2
    ox_gap
    lassign [ox_py {} [file join $::F measures.py] --rundir $::G --json] mrc1 mout1 merr1
    set p1 [ox_jtext $mout1]
    set moved {}
    foreach k {vmax vav dbl} {
        set x [ox_get $p1 $k] ; set y [ox_get $p2 $k]
        lappend moved $k [expr {[string is double -strict $x] && [string is double -strict $y]
                                && abs($y - $x) > 1e-3 * abs($x)}]
    }
    check "OX5 vmax, vav and vdc(mid) 2 * each move by more than 1e-3 relative ([ox_get $p1 vmax] -> [ox_get $p2 vmax])" \
        $moved {vmax 1 vav 1 dbl 1}
    check "OX5 CONTROL: vdc(in) 1 * does not depend on rr and is identical" \
        [list [ox_get $p1 vin] [expr {[ox_get $p1 vin] eq [ox_get $p2 vin]}]] {1.0 1}
    set code {import sys; sys.path.insert(0, sys.argv[1]); import measures
out = []
for ov, base in (({"nosuch": 1}, None), ({"rr": 1.0}, sys.argv[2]), ({"rr": "1\n2"}, None)):
    try:
        measures.write_deck(sys.argv[3], ov, base=base)
        out.append("wrote")
    except Exception as e:
        out.append(type(e).__name__)
print(" ".join(out))}
    set edited [file join $::scratch edited.spice]
    set f [open $edited w] ; puts -nonewline $f [string map {{.param rr=2k} {.param rr=3k}} [ox_read [file join $::F ox7_ase.spice]]] ; close $f
    lassign [ox_py {} -I -c $code $::F $edited [file join $::scratch wd.spice]] rc out err
    check "OX5 write_deck raises KeyError for an unknown name, DeckMismatch when the base line was edited, and refuses a value with a newline" \
        [string trim $out] {KeyError DeckMismatch ValueError}
}

# =============================================================================
# OX6 -- NO DISPLAY, A PRIVATE HOME
# =============================================================================
group OX6 {
    set fh [file join $::scratch fakehome]
    file mkdir $fh
    set f [open [file join $fh marker] w] ; puts $f x ; close $f
    set before [lsort [glob -nocomplain -directory $fh * .*]]
    ox_gap
    set code {import sys, json, os; sys.path.insert(0, sys.argv[1]); import measures
r = measures.measures_detail(sys.argv[2])
print(r.results_json)}
    lassign [ox_run [list DISPLAY=asexp-planted:0 HOME=$fh] [list $::PY -I -c $code $::F $::G]] rc out err
    set j [ox_jtext $out]
    set seen [ox_get $j env home]
    set after [lsort [glob -nocomplain -directory $fh * .*]]
    check "OX6 with DISPLAY planted (a non-server value) and HOME set, xschem saw NO DISPLAY and a HOME that is neither, and that HOME is gone afterwards (rc $rc $err)" \
        [list [ox_get $j env display] [expr {$seen ne $fh && $seen ne [test_real_home] && $seen ne {ABSENT}}] \
              [file exists $seen]] {false 1 0}
    check "OX6 the HOME it was given is untouched" [expr {$before eq $after}] 1
}

# =============================================================================
# OX7 -- REFUSALS AND HARNESS FAILURES ARE NEVER A NUMBER
# =============================================================================
group OX7 {
    set z [file join $::scratch empty_run]
    file delete -force $z
    file mkdir $z
    ox_gap
    lassign [ox_py {} [file join $::F measures.py] --rundir $z --json] rc out err
    set j [ox_jtext $out]
    set nonnum 1
    dict for {k v} $j { if {[string is double -strict $v]} { set nonnum 0 } }
    set statuses {}
    foreach k {vmax vav vnever} { lappend statuses [ox_get $j $k status] }
    check "OX7a an empty rundir: exit 1, no number anywhere, every meas row failed, and a warning that no results exist" \
        [list $rc $nonnum $statuses [expr {[string first {no results in} $err] >= 0}]] {1 1 {failed failed failed} 1}
    set st [file join $::scratch stale]
    file delete -force $st
    file mkdir $st
    foreach n {ox7_ase.raw ox7_ase.meas} { file copy [file join $::G $n] [file join $st $n] }
    file copy [file join $::G ox7_ase.spice] [file join $st ox7_ase.spice]
    file mtime [file join $st ox7_ase.meas] [expr {[clock seconds] - 100}]
    file mtime [file join $st ox7_ase.raw] [expr {[clock seconds] - 100}]
    file mtime [file join $st ox7_ase.spice] [clock seconds]
    lassign [ox_py {} [file join $::F measures.py] --rundir $st] rc out err
    check "OX7b results older than the deck: exit 2 with StaleResults" \
        [list $rc [expr {[string first StaleResults $err] >= 0}]] {2 1}
    lassign [ox_py [list ASEXP_XSCHEM=/bin/false] [file join $::F measures.py] --rundir $::G] rc out err
    check "OX7c an xschem that writes nothing: exit 2 with the reason" \
        [list $rc [expr {[string first {no results file} $err] >= 0}] $out] {2 1 {}}
    set half [file join $::scratch half.sh]
    set f [open $half w]
    puts $f "#!/bin/sh\nprintf '\{\"protocol\": \"asexp-results/1\", \"outp' > \"\$ASEXP_OUT\"\nexit 0"
    close $f
    file attributes $half -permissions 0755
    lassign [ox_py [list ASEXP_XSCHEM=$half] [file join $::F measures.py] --rundir $::G] rc out err
    check "OX7c a truncated results file: exit 2, never an empty result" \
        [list $rc [expr {[string first {not JSON} $err] >= 0}] $out] {2 1 {}}
    set code {import sys; sys.path.insert(0, sys.argv[1]); import measures
x = measures.NonNumeric("wave", "")
r = []
for f in (lambda: float(x), lambda: x + 1, lambda: x * 2.0):
    try:
        f(); r.append("number")
    except TypeError:
        r.append("TypeError")
r.append(str(bool(x)))
print(" ".join(r))}
    lassign [ox_py {} -I -c $code $::F] rc out err
    check "OX7d float(NonNumeric), arithmetic on it raise TypeError, and it is falsy" \
        [string trim $out] {TypeError TypeError TypeError False}
}

# =============================================================================
# OX8 -- DATASETS: TWO TRANSIENTS IN ONE RUN ARE REPORTED, WARNED, DATASET 0 USED
# (measured: a nested dc sweep is ONE dataset in xschem's reader, and cross on
# a dc sweep is refused, so the multi-dataset shape is two tran analyses)
# =============================================================================
group OX8 {
    set nl8 "* ox8\nv1 in 0 dc 0 pulse(0 1 1u 100n 100n 3u 8u)\nr1 in out 1k\nc1 out 0 1n\n.end\n"
    set s [ase::state_default]
    dict set s simulator ngspice
    dict set s design [dict create lib ox cell ox8 view schematic]
    dict set s rundir [file join $::scratch r8]
    dict set s analyses {{type op enabled 0} {type tran enabled 1 stop 20u step 10n}
                         {type tran enabled 1 stop 10u step 10n}}
    dict set s outputs {{name c8 expr {cross(vt(out), 0.5, 1, rising)} save 0 plot 0}
                        {name w8 expr {vt(out) 2 *} save 0 plot 0}
                        {name a8 expr {value(vt(out), 15u)} save 0 plot 0}}
    set e8 [file join $::scratch e8]
    set r [pcall ase::optexport $s $e8 [dict create netlist_text $nl8]]
    set g8 [file join $::scratch g8]
    file delete -force $g8
    lassign [ox_py {} [file join $e8 measures.py] --prepare $g8] prc pout perr
    lassign [ox_py [list ASEXP_NGSPICE=$::NG] [file join $e8 measures.py] --command --rundir $g8] crc argv cerr
    ox_run {} [split [string trim $argv] "\n"] $g8 120
    ox_gap
    set code {import sys, json; sys.path.insert(0, sys.argv[1]); import measures
r = measures.measures_detail(sys.argv[2])
print(json.dumps({"ds": r.datasets, "w": r.warnings, "c8": repr(r.values["c8"]), "a8": repr(r.values["a8"])}))}
    lassign [ox_py {} -I -c $code $e8 $g8] rc out err
    set j [ox_jtext $out]
    set n [ox_get $j ds tran]
    set ws [ox_get $j w]
    set named {}
    foreach k {c8 w8} {
        foreach w $ws { if {[string match "$k: evaluated on dataset 0 of $n (tran*" $w]} { lappend named $k } }
    }
    check "OX8 the results report more than one dataset for tran ($n; two transient analyses in one run) and the warning names both rows and the count (rc $rc $err)" \
        [list [expr {[string is integer -strict $n] && $n > 1}] $named] {1 {c8 w8}}
    dict set s rundir $g8
    set recs [ase::backend::ngspice::result_answers $s fold]
    set c8 {}
    foreach rr $recs { if {[dict get $rr key] eq {c8}} { set c8 $rr } }
    check "OX8 the value is result_answers' (dataset 0): [ox_get $j c8]" \
        [expr {[dict get $c8 status] eq {number} && [string is double -strict [ox_get $j c8]]
               && double([ox_get $j c8]) == double([dict get $c8 value])}] 1
    # DATASET 0. Measured: only a POSTFIX row honours calc::eval_texts'
    # dataset argument, and on a multi-point analysis a postfix row is a wave,
    # which exports no value; a verb answers from dataset 0 whatever the
    # argument (value at 15u, past dataset 1's 10u stop, is identical for 0
    # and 1). So no exported number can depend on the dataset today. The
    # third leg is a TRIPWIRE: if a verb ever honours the argument it reddens,
    # and the dataset-0 claim then needs a row whose datasets differ.
    set raw8 [file join $g8 ox8_ase.raw]
    set e0 [lindex [calc::eval_texts [list {value(vt(out), 15u)}] $raw8 tran 0] 0]
    set e1 [lindex [calc::eval_texts [list {value(vt(out), 15u)}] $raw8 tran 1] 0]
    catch {xschem raw clear}
    set v0 [dict get $e0 value] ; set v1 [dict get $e1 value] ; set a8 [ox_get $j a8]
    check "OX8 the export's verb row equals calc::eval_texts on dataset 0 ($a8), and (TRIPWIRE) a verb still ignores the dataset argument (ds0 $v0, ds1 $v1)" \
        [list [dict get $e0 ok] [dict get $e0 kind] \
              [expr {[dict get $e1 ok] && $v1 eq $v0}] \
              [expr {[string is double -strict $a8] && $a8 == $v0}]] {1 scalar 1 1}
    lassign [ox_py {} [file join $e8 measures.py] --rundir $g8 --json --detail] drc dout derr
    set dj [ox_jtext $dout]
    set dn 0
    foreach w [ox_get $dj warnings] { if {[string match "*dataset 0 of $n (tran*" $w]} { incr dn } }
    check "OX8 --json --detail carries values, datasets and the per-row warnings (stdout, not only stderr)" \
        [list [lsort [pcall dict keys $dj]] [ox_get $dj datasets tran] $dn [ox_get $dj values a8]] \
        [list {datasets values warnings} $n 3 $a8]
}

# =============================================================================
# OX10 -- THE .spiceinit PATH
# =============================================================================
group OX10 {
    set s $::ST
    dict set s options {{name ngbehavior value hs} {name ps_tpz_delays value 1}}
    set r10 [file join $::scratch r10]
    dict set s rundir $r10
    set e10 [file join $::scratch e10]
    set res [pcall ase::optexport $s $e10 [dict create netlist_text $::NL]]
    check "OX10 exporting a bench WITH pre-deck options writes nothing into its run directory (no .spiceinit there)" \
        [file exists $r10] 0
    file mkdir $r10
    set plan [ase::predeck_plan ngspice $s]
    ase::predeck_deliver ngspice $s $plan
    check "OX10 the exported .spiceinit equals, byte for byte, what predeck_write writes for a real run of the same state" \
        [list [expr {[ox_read [file join $e10 .spiceinit]] ne {NOFILE}}] \
              [expr {[ox_read [file join $e10 .spiceinit]] eq [ox_read [file join $r10 .spiceinit]]}]] {1 1}
    set m10 [ox_json [file join $e10 manifest.json]]
    set rc10 [ase::backend::ngspice::run_cmd $s DECK 1]
    set dw {}
    foreach w $rc10 { if {[string match -D* $w] || [string match *=* $w]} { lappend dw $w } }
    set mw {}
    foreach w [ox_get $m10 simulator args] { if {[string match -D* $w] || [string match *=* $w]} { lappend mw $w } }
    check "OX10 the manifest's argv carries the same pre-deck words as run_cmd ($dw), and names the .spiceinit" \
        [list [expr {[llength $dw] > 0}] $mw [ox_get $m10 predeck_file]] [list 1 $dw .spiceinit]
    set g10 [file join $::scratch g10]
    lassign [ox_py {} [file join $e10 measures.py] --prepare $g10] prc out err
    check "OX10 prepare_rundir copies the .spiceinit" \
        [expr {[ox_read [file join $g10 .spiceinit]] eq [ox_read [file join $e10 .spiceinit]]}] 1
    set f [open [file join $::G .spiceinit] w]
    puts $f [ase::backend::ngspice::predeck_marker] ; puts $f "set x=1" ; close $f
    lassign [ox_py {} [file join $::F measures.py] --prepare $::G] prc out err
    check "OX10 a bench with no pre-deck option exports no .spiceinit, and prepare_rundir deletes a stale one headed by the ASE-L marker" \
        [list [ox_get $::MAN predeck_file] [file exists [file join $::E .spiceinit]] [file exists [file join $::G .spiceinit]]] \
        {null 0 0}
}

# =============================================================================
# OX11 -- A SECOND RUN IN THE SAME DIRECTORY (M11: ngspice APPENDS)
# =============================================================================
# `write` runs under `set appendwrite` and every .meas row appends, so a
# second run in a directory that still holds the first run's results makes
# the raw hold BOTH runs -- dataset 0 is then the OLD run -- and a measurement
# that fails the second time keeps the first time's number. prepare_rundir
# deletes them first, exactly as ase::run_deck does.
group OX11 {
    set g $::G
    foreach n {ox7_ase.raw ox7_ase.meas} {
        set f [open [file join $g $n] a] ; puts $f "" ; close $f
    }
    lassign [ox_py {} [file join $::F measures.py] --prepare $g --set rr=500] prc out err
    check "OX11 --prepare over a used run directory deletes the previous results first" \
        [list $prc [file exists [file join $g ox7_ase.raw]] [file exists [file join $g ox7_ase.meas]]] {0 0 0}
    ox_ngrun $g
    ox_gap
    set code {import sys, json; sys.path.insert(0, sys.argv[1]); import measures
r = measures.measures_detail(sys.argv[2])
print(json.dumps({"ds": r.datasets, "dbl": r.values["dbl"], "vmax": r.values["vmax"]}))}
    lassign [ox_py {} -I -c $code $::F $g] rc out err
    set j [ox_jtext $out]
    check "OX11 the second run's values are the second run's (equal to a fresh directory's at rr=500: dbl [ox_get $j dbl], vmax [ox_get $j vmax]), one dataset per analysis" \
        [list [ox_get $j ds] [expr {[ox_get $j dbl] eq [ox_get $::P2 dbl]}] [expr {[ox_get $j vmax] eq [ox_get $::P2 vmax]}]] \
        {{op 1 tran 1} 1 1}
}

# Export `st` to `e`, prepare `g` with its measures.py and run ngspice in g.
proc ox_bench {st e g} {
    file delete -force $e $g
    set r [pcall ase::optexport $st $e [dict create netlist_text $::NL]]
    lassign [ox_py {} [file join $e measures.py] --prepare $g] prc pout perr
    lassign [ox_py [list ASEXP_NGSPICE=$::NG] [file join $e measures.py] --command --rundir $g] crc argv cerr
    lassign [ox_run {} [split [string trim $argv] "\n"] $g 120] nrc nout nerr
    set f [open [file join $g ngspice.log] w] ; puts -nonewline $f "$nout$nerr" ; close $f
    return [list [expr {[string match ERR:* $r] ? $r : {ok}}] $prc $nrc]
}

# =============================================================================
# OX12 -- THE MEASUREMENTS-ONLY PATH: NO XSCHEM, SAME ANSWERS
# =============================================================================
group OX12 {
    set s [ox_state ox12 [file join $::scratch r12]]
    dict set s outputs {}
    dict set s measurements [lrange [dict get $s measurements] 0 2]
    set e12 [file join $::scratch e12]
    set g12 [file join $::scratch g12]
    check "OX12 a bench with no Outputs rows exports, prepares and runs" [ox_bench $s $e12 $g12] {ok 0 0}
    lassign [ox_py [list ASEXP_XSCHEM=/bin/false] [file join $e12 measures.py] --rundir $g12 --json] mrc mout merr
    set py [ox_jtext $mout]
    dict set s rundir $g12
    set bad {} ; set kinds {}
    foreach e [ase::meas_results ngspice $s] {
        lassign $e nm verdict val why
        if {$verdict eq {off}} continue
        set v [ox_get $py $nm]
        if {$verdict eq {ok}} {
            if {![string is double -strict $v] || $v != double($val)} { lappend bad "$nm: $v vs $val" }
            lappend kinds num
        } else {
            if {[ox_get $v status] ne $verdict || [ox_get $v msg] ne $why} { lappend bad "$nm: $v vs $verdict/$why" }
            lappend kinds $verdict
        }
    }
    check "OX12 with xschem made unlaunchable (/bin/false), every row equals ase::meas_results: numbers as doubles, the failed row by status and message ($kinds; exit $mrc $merr)" \
        [list $mrc [llength [dict keys $py]] [lsort $kinds] $bad] {1 3 {failed num num} {}}
    set ::G12 $g12 ; set ::E12 $e12
}

# =============================================================================
# OX12b -- EXIT 0 WITH A WAVE; --log CARRIES THE CASE RULE
# =============================================================================
group OX12b {
    set s [ox_state ox12b [file join $::scratch r12b]]
    dict set s outputs {{name cr expr {cross(vt(out), 0.1, 1, rising)} save 0 plot 0}
                        {name w expr {vt(out) 2 *} save 0 plot 0}
                        {name uc expr V(OUT) save 0 plot 0}}
    dict set s measurements [lrange [dict get $s measurements] 0 0]
    set e [file join $::scratch e12b]
    set g [file join $::scratch g12b]
    check "OX12b the bench exports, prepares and runs" [ox_bench $s $e $g] {ok 0 0}
    ox_gap
    lassign [ox_py {} [file join $e measures.py] --rundir $g --json] rc out err
    set j [ox_jtext $out]
    check "OX12b every measure a number except one wave: exit 0, and the wave is still a !wave marker, never a number" \
        [list $rc [ox_get $j w status] [string is double -strict [ox_get $j cr]] [string is double -strict [ox_get $j uc]]] \
        {0 wave 1 1}
    set lg [file join $::scratch distinguish.log]
    set f [open $lg w] ; puts $f "Note: casemode=distinguish is in effect" ; close $f
    ox_gap
    lassign [ox_py {} [file join $e measures.py] --rundir $g --json --log $lg] rc2 out2 err2
    set j2 [ox_jtext $out2]
    dict set s rundir $g
    set fold {} ; set dist {}
    ase::quiet {
        foreach r [ase::backend::ngspice::result_answers $s fold] { if {[dict get $r key] eq {uc}} { set fold $r } }
        foreach r [ase::backend::ngspice::result_answers $s distinguish] { if {[dict get $r key] eq {uc}} { set dist $r } }
    }
    check "OX12b a log saying casemode=distinguish turns the wrongly-cased raw row V(OUT) into what the pane shows under that rule (status [ox_get $dist status]), and without --log it is the fold answer; exit 1 then" \
        [list [dict get $fold status] [expr {[ox_get $j uc] == [dict get $fold value]}] \
              [dict get $dist status] [ox_get $j2 uc status] $rc2] {number 1 novalue novalue 1}
    set ::G12b $g ; set ::E12b $e
}

# =============================================================================
# OX14 -- HARNESS FAILURES ARE NAMED; A CRASHED FIRST LAUNCH IS RETRIED, SAID
# =============================================================================
group OX14 {
    set e14 [file join $::scratch e14]
    file delete -force $e14
    file copy $::E12b $e14
    set f [open [file join $e14 measures_state.tcl] w] ; puts $f "state \{ broken" ; close $f
    ox_gap
    lassign [ox_py {} [file join $e14 measures.py] --rundir $::G12b --json] rc out err
    check "OX14 a broken measures_state.tcl: exit 2 with xschem's own failure (the results file's error), no stdout" \
        [list $rc [expr {[string first {xschem failed:} $err] >= 0}] $out] {2 1 {}}
    set mark [file join $::scratch segv.mark]
    file delete -force $mark
    set stub [file join $::scratch segv_once.sh]
    set f [open $stub w]
    puts $f "#!/bin/sh\nif \[ ! -e '$mark' \]; then : > '$mark'; kill -SEGV \$\$; fi\nexec '$::XS' \"\$@\""
    close $f
    file attributes $stub -permissions 0755
    ox_gap
    set code {import sys, json; sys.path.insert(0, sys.argv[1]); import measures
r = measures.measures_detail(sys.argv[2])
print(json.dumps({"w": r.warnings, "cr": repr(r.values["cr"])}))}
    lassign [ox_py [list ASEXP_XSCHEM=$stub] -I -c $code $::E12b $::G12b] rc out err
    set j [ox_jtext $out]
    set said 0
    foreach w [ox_get $j w] { if {[string match {*retried*issue 1706*} $w]} { set said 1 } }
    check "OX14 an xschem that crashes (SIGSEGV) on its first launch is retried once, the retry answers, and a warning says so (rc $rc $err)" \
        [list $rc [file exists $mark] $said [string is double -strict [ox_get $j cr]]] {0 1 1 1}
}

# =============================================================================
# OX13 -- RESULTS OF TWO RUNS ARE REFUSED; A FAILED SIMULATION RAISES
# =============================================================================
# The optimizer edits the deck itself; ngspice APPENDS under `set appendwrite`,
# so a second run over un-deleted results leaves dataset 0 (the Calculator's)
# from the FIRST run and the .meas rows from the LAST -- one dict, two design
# points. The deck says how many PLOT lines and ASE-MEAS markers one run writes.
group OX13 {
    set out {}
    foreach {e g} [list $::E12b $::G12b $::E12 $::G12] {
        set deck [file join $g [file tail [lindex [glob -directory $g *_ase.spice] 0]]]
        set f [open $deck r] ; set t [read $f] ; close $f
        set f [open $deck w] ; puts -nonewline $f [string map {{.param rr=2k} {.param rr=500}} $t] ; close $f
        lassign [ox_py [list ASEXP_NGSPICE=$::NG] [file join $e measures.py] --command --rundir $g] crc argv cerr
        ox_run {} [split [string trim $argv] "\n"] $g 120
        ox_gap
        lassign [ox_py {} [file join $e measures.py] --rundir $g --json] rc mout err
        lappend out [list $rc [expr {[string first MixedResults $err] >= 0}] $mout]
    }
    check "OX13 a second ngspice run over un-deleted results (deck edited in place, the optimizer's own flow) is refused with MixedResults, exit 2, nothing on stdout -- with Calculator rows and Measurements-only" \
        $out {{2 1 {}} {2 1 {}}}
    set code {import sys; sys.path.insert(0, sys.argv[1]); import measures
try:
    measures.run(sys.argv[2])
    print("returned")
except measures.SimulationFailed as e:
    print("SimulationFailed", isinstance(e, measures.MeasuresError))}
    lassign [ox_py [list ASEXP_NGSPICE=/bin/false] -I -c $code $::E12 [file join $::scratch g13f]] rc out err
    check "OX13 run() raises SimulationFailed (a MeasuresError) when ngspice exits nonzero, never a dict of partial results" \
        [string trim $out] {SimulationFailed True}
}
}

# =============================================================================
# OX9 -- README.txt NAMES WHAT THE MANIFEST NAMES
# =============================================================================
group OX9 {
    if {$::PY eq {}} { return }
    set t [ox_read [file join $::E README.txt]]
    set miss {}
    set want [list [ox_get $::MAN deck] [ox_get $::MAN xschem]]
    foreach v [ox_get $::MAN variables] {
        lappend want "[ox_get $v name] = [ox_get $v nominal]" "deck line [ox_get $v deck_line]"
    }
    foreach x [ox_get $::MAN measures] { lappend want [ox_get $x name] }
    foreach w $want { if {[string first $w $t] < 0} { lappend miss $w } }
    check "OX9 README.txt names the manifest's deck, xschem, variables (with deck lines) and every measure (population [llength $want])" \
        [list [expr {[llength $want] > 5}] $miss] {1 {}}
}

foreach s $skipped { puts "SKIP: $s" }

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
