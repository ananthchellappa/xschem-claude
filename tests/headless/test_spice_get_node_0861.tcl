# tests/headless/test_spice_get_node_0861.tcl -- ISSUE 0861: A SCHEMATIC TEXT
# PAINTS THE NUMBER 0 WHEN NOTHING HAS BEEN PUBLISHED.
#
# ============================================================================
# WHAT THE USER SEES
# ============================================================================
# A schematic carrying a text that asks for a node's simulated value -- a probe
# symbol, or the shipped xschem_library/devices/scope_ammeter.sym -- paints
# **0** after Simulation > Graphs > Annotate Operating Point has REFUSED to
# publish anything. On the scope ammeter that reads as ZERO AMPS FLOWING
# THROUGH THE BRANCH: a plausible-looking measurement, and a number the loaded
# results do not contain.
#
# Two lines of code away the same text, with nothing loaded at all, correctly
# paints a dash. So the codebase already knows the right answer; one reader
# never asks whether anything was published before it prints.
#
# Measured on HEAD e60e1974, the same three data points in the same file,
# differing only in the Plotname line:
#
#   nothing loaded  -> VDNODE=-
#   transient       -> VDNODE=0      <-- FABRICATED, RULING D5-1
#   operating point -> VDNODE=1.8
#
# ============================================================================
# THE TWO FACES, WHICH ARE TWO SEPARATE C SITES
# ============================================================================
# The rendered TEXT comes from spice_get_node in src/token.c, the seventh
# reader of the cursor-B value array and the ONLY one with no published-
# annotation term. The VERB -- xschem raw value <vec> -1, which is what
# op_annot::raw_or_blank is a wrapper over -- comes from a DIFFERENT unguarded
# read in src/scheduler.c. Both answer 0 today.
#
# RULING D5-4 says a user-facing answer is minted once and rendered by callers.
# Section C below reads all three surfaces at the same instant and requires
# them to agree, so a fix that lands on one site and not the other cannot pass:
# fixing only token.c satisfies sections A and B while section C still reds,
# and fixing only scheduler.c leaves the drawn schematic wrong.
#
# ============================================================================
# THE RISK THIS FILE IS MOSTLY MADE OF -- OVER-REFUSAL
# ============================================================================
# This branch has shipped two defects past twenty-eight passing checks, both
# over-refusals. A guard that blanks the OPERATING-POINT case too would look
# like a fix and would silently kill the feature. So more than half the rows
# here are POSITIVE TWINS that are green today and whose job is to STAY green:
#
#   SGN3  SGN7  SGN9  SGN11  the published operating point still paints 1.8
#   SGN13 SGN14              asking for a numbered data point still answers,
#                            even while the annotation is refused -- reading
#                            the data is not the same act as annotating it
#   SGN15 THE BIG ONE        a TRANSIENT that has actually published, because
#                            the user put a cursor on a waveform, still paints
#                            the real value at that time. A guard hung on the
#                            simulation TYPE instead of on whether anything was
#                            published would kill exactly this and nothing else
#                            in the file would notice.
#   SGN16                    a literal ground node still paints 0.0 -- that is
#                            a definition, not a measurement, and I3 does not
#                            reach it
#   SGN17                    a vector that is not in the file still paints a
#                            dash in every state -- invariant I3, unchanged
#   SGN22                    the numbered-point reader is still wired up
#
# ============================================================================
# WHAT THIS FILE DOES NOT MEASURE -- READ BEFORE TRUSTING IT
# ============================================================================
# * NO SCREEN PIXELS. Section B exports the DRAWN sheet through the SVG back
#   end, which shares src/token.c's translate with the X11 renderer, so it is
#   the drawing path and not an API shortcut. It is still not an eyeball on a
#   window. A green run here owes the user a look at the real scope ammeter.
# * NO SIMULATOR. The databases are hand-written ascii, three points, and the
#   transient and operating-point copies differ in ONE LINE. That is the point:
#   it makes causation a measurement rather than an inference.
#
# Runs on BOTH arms, unchanged:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_spice_get_node_0861.tcl
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_spice_get_node_0861.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

# --- locations, cwd-independent ---------------------------------------------
set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch spice_get_node_0861]

# ============================================================================
# THE ANSWER DISCIPLINE -- an absent or broken accessor must never satisfy a
# golden that expects a blank
# ============================================================================
# Every row below that expects "nothing" expects the EMPTY STRING. A bare
# catch-and-discard would let "invalid command name" and "no raw file loaded"
# both arrive as an empty string and satisfy it, and the file would go green
# against the very tree it was written to redden. So a raise is reported as
# RAISED:<text> and is never equal to a blank.
proc sgn_rc {script} {
  if {[catch {uplevel 1 $script} r]} { return "RAISED:$r" }
  return $r
}

## The rendered text, exactly as draw.c builds it: translate on the instance.
proc sgn_text {tok} {
  return [string trim [sgn_rc [list xschem translate p1 $tok]]]
}
## The node value token this file is about, rendered.
proc sgn_vd {} { return [sgn_text {VDNODE=@spice_get_node v(d) }] }
## The public verb, at the annotation point.
proc sgn_verb {v} { return [sgn_rc [list xschem raw value $v -1]] }
## The Tcl wrapper over that verb.
proc sgn_blankwrap {v} { return [sgn_rc [list op_annot::raw_or_blank $v]] }
## The three-field annotation state, so a row can say WHICH state it measured.
proc sgn_annot {} { return [sgn_rc {xschem raw annot}] }

## THE ONLY WAY A SCENARIO BELOW STARTS. Without the clear the previous
## scenario's published values are still attached and the next row measures the
## one before it.
proc sgn_arm {sch} {
  catch {xschem raw clear}
  xschem load $sch
}

## Every text of a drawn sheet, read back out of an SVG export. Same back end
## as the screen: svgdraw.c calls the same translate.
proc sgn_drawn {sch tag} {
  global scratch
  set f [file join $scratch ${tag}.svg]
  catch {file delete $f}
  sgn_rc [concat [list xschem print svg $f] $::SGN_VP]
  if {[catch {open $f r} h]} { return NOSVG }
  set d [read $h]; close $h
  set o {}
  foreach {a t} [regexp -all -inline {>([^<>]*)</text>} $d] {
    set t [string trim $t]
    if {$t ne {}} { lappend o $t }
  }
  return $o
}

# --- fixtures ---------------------------------------------------------------
# A probe symbol carrying the pattern src/token.c documents verbatim, one
# instance on a sheet, a sheet carrying the SHIPPED scope ammeter, and two
# three-point databases that differ in exactly one line.
set probe [file join $scratch probe.sym]
set sheet [file join $scratch sheet.sch]
set amm   [file join $scratch amm.sch]
set tran  [file join $scratch tran.raw]
set opraw [file join $scratch op.raw]
set ammsym [file join $repo xschem_library devices scope_ammeter.sym]

proc sgn_put {f txt} { set h [open $f w]; puts -nonewline $h $txt; close $h }

sgn_put $probe "v {xschem version=3.4.4 file_version=1.2}\nG {}\nK {type=probe\ntemplate=\"name=p1\"\n}\nV {}\nS {}\nE {}\nB 5 -1.25 -1.25 1.25 1.25 {name=p dir=in}\nT {VDNODE=@spice_get_node v(d) } -7.5 -8.125 0 0 0.3 0.3 {}\n"
sgn_put $sheet "v {xschem version=3.4.4 file_version=1.2}\nG {}\nK {}\nV {}\nS {}\nE {}\nC {$probe} 0 0 0 0 {name=p1}\n"
sgn_put $amm   "v {xschem version=3.4.4 file_version=1.2}\nG {}\nK {}\nV {}\nS {}\nE {}\nC {$ammsym} 0 0 0 0 {name=l1 device=vd}\n"

## The ONE differing line is Plotname. Everything else is byte-identical, which
## is what makes section A causation and not correlation.
proc sgn_raw {f plotname} {
  sgn_put $f "Title: 0861 fixture\nDate: Mon Jan 1 00:00:00 2026\nPlotname: $plotname\nFlags: real\nNo. Variables: 3\nNo. Points: 3\nVariables:\n\t0\ttime\ttime\n\t1\tv(d)\tvoltage\n\t2\ti(vd)\tcurrent\nValues:\n0\t0\n\t1.8\n\t1.8\n1\t1e-09\n\t1.9\n\t1.9\n2\t2e-09\n\t2.0\n\t2.0\n"
}
sgn_raw $tran  {Transient Analysis}
sgn_raw $opraw {Operating Point}

## Viewport for the 10-argument print form: w h x1 y1 x2 y2.
set SGN_VP  {800 600 -60 -60 60 60}
set SGN_AVP {900 700 -20 -160 170 20}

check {SGN0 FIXTURE the shipped scope ammeter symbol this file draws is present and its value text is not hidden} \
  [list [file exists $ammsym] \
        [expr {[regexp {@spice_get_node} [read [set h [open $ammsym r]]][close $h]] ? 1 : 0}]] \
  {1 1}

# ============================================================================
# SECTION A -- THE RENDERED TEXT, WHICH IS WHAT IS ON THE SCHEMATIC
# ============================================================================
# ACCEPTANCE ROWS 1, 2 and 3 of doc/claude/issues/0861-*.md.
# SGN1 is the control: the codebase's own correct answer, already right today.
# SGN2 is the defect. SGN3 is the positive twin and is the whole risk.
# SGN4 and SGN5 are the OLDER hole -- a plain results read never publishes an
# annotation at all, so both simulation types are wrong there, which is why the
# fix has to hang on "was anything published" and not on the simulation type.

sgn_arm $sheet
check {SGN1 with nothing loaded the node text paints a dash -- the answer the codebase already gives correctly} \
  [list [sgn_annot] [sgn_vd]] \
  [list {RAISED:No raw file loaded} {VDNODE=-}]

sgn_arm $sheet
sgn_rc [list xschem annotate_op $tran]
check {SGN2 ISSUE 0861 annotating a transient publishes nothing, so the node text must paint a dash and not a fabricated 0} \
  [list [sgn_annot] [sgn_vd]] \
  [list {-1 0 -1} {VDNODE=-}]

sgn_arm $sheet
sgn_rc [list xschem annotate_op $opraw]
check {SGN3 POSITIVE TWIN the operating point still paints its real 1.8 -- same three data points, one different line in the file} \
  [list [sgn_annot] [sgn_vd]] \
  [list {0 0 -1} {VDNODE=1.8}]

sgn_arm $sheet
sgn_rc [list xschem raw read $tran tran]
check {SGN4 ISSUE 0861 reading a transient results file without annotating paints a dash too} \
  [list [sgn_annot] [sgn_vd]] \
  [list {-1 0 -1} {VDNODE=-}]

sgn_arm $sheet
sgn_rc [list xschem raw read $opraw op]
check {SGN5 ISSUE 0861 reading an operating point results file without annotating paints a dash -- nothing published means nothing painted, whatever the run type} \
  [list [sgn_annot] [sgn_vd]] \
  [list {-1 0 -1} {VDNODE=-}]

# ============================================================================
# SECTION B -- THE SAME THING AS DRAWN
# ============================================================================
# Section A asks the translator. This section EXPORTS THE DRAWN SHEET and reads
# the number back out of it, through the same translate call the on-screen
# renderer makes. SGN8 and SGN9 use the SHIPPED scope ammeter, unmodified, so
# the row that reds is the one a user of the standard library actually meets.

sgn_arm $sheet
sgn_rc [list xschem annotate_op $tran]
check {SGN6 ISSUE 0861 the DRAWN sheet paints a dash after a transient publishes nothing} \
  [list [sgn_annot] [sgn_drawn $sheet b_tran]] \
  [list {-1 0 -1} {VDNODE=-}]

sgn_arm $sheet
sgn_rc [list xschem annotate_op $opraw]
check {SGN7 POSITIVE TWIN the DRAWN sheet still paints 1.8 for the operating point} \
  [list [sgn_annot] [sgn_drawn $sheet b_op]] \
  [list {0 0 -1} {VDNODE=1.8}]

set SGN_VP $SGN_AVP
sgn_arm $amm
sgn_rc [list xschem annotate_op $tran]
check {SGN8 ISSUE 0861 the shipped scope ammeter must not read ZERO AMPS through the branch when nothing was published} \
  [list [sgn_annot] [sgn_drawn $amm b_amm_tran]] \
  [list {-1 0 -1} {vd -}]

sgn_arm $amm
sgn_rc [list xschem annotate_op $opraw]
check {SGN9 POSITIVE TWIN the shipped scope ammeter still reads its real current for the operating point} \
  [list [sgn_annot] [sgn_drawn $amm b_amm_op]] \
  [list {0 0 -1} {vd 1.8}]
set SGN_VP {800 600 -60 -60 60 60}

# ============================================================================
# SECTION C -- ONE ANSWER, NOT TWO -- RULING D5-4
# ============================================================================
# ACCEPTANCE ROW 4. The schematic text, the public verb and the Tcl wrapper are
# three surfaces over one question and they must give one answer. They agree
# today -- on the WRONG answer, all three saying 0 -- so a row that only
# compared them would already be green. Each row therefore pins the AGREED
# VALUE as well as the agreement.
proc sgn_three {} {
  return [list [sgn_vd] [sgn_verb {v(d)}] [sgn_blankwrap {v(d)}]]
}

sgn_arm $sheet
sgn_rc [list xschem annotate_op $tran]
check {SGN10 RULING D5-4 with a transient publishing nothing, the schematic text, the raw value verb and op_annot::raw_or_blank all say nothing} \
  [list [sgn_annot] [sgn_three]] \
  [list {-1 0 -1} [list {VDNODE=-} {} {}]]

sgn_arm $sheet
sgn_rc [list xschem annotate_op $opraw]
check {SGN11 POSITIVE TWIN RULING D5-4 with an operating point published, all three surfaces still say 1.8} \
  [list [sgn_annot] [sgn_three]] \
  [list {0 0 -1} [list {VDNODE=1.8} 1.8 1.8]]

sgn_arm $sheet
check {SGN12 with nothing loaded the three surfaces already agree -- the text dashes, the verb raises, the wrapper turns that raise into a blank} \
  [sgn_three] \
  [list {VDNODE=-} {RAISED:No raw file loaded} {}]

# ============================================================================
# SECTION D -- THE OVER-REFUSAL FENCES
# ============================================================================
# These are green TODAY. Their job is to be green AFTER the fix as well. Every
# one of them is something a guard placed one line too high, or hung on the
# wrong condition, would silently destroy.

sgn_arm $sheet
sgn_rc [list xschem annotate_op $tran]
check {SGN13 FENCE asking for a numbered data point still answers while the annotation is refused -- inspecting the data is not annotating it} \
  [list [sgn_annot] [sgn_rc {xschem raw value {v(d)} 0}] \
        [sgn_rc {xschem raw value {v(d)} 1}] [sgn_rc {xschem raw value {v(d)} 2}]] \
  [list {-1 0 -1} 1.8 1.9000001 2]

sgn_arm $sheet
sgn_rc [list xschem annotate_op $tran]
check {SGN14 FENCE the dataset form of a numbered point read also stays live while the annotation is refused} \
  [list [sgn_annot] [sgn_rc {xschem raw value {v(d)} 2 0}] [sgn_rc {xschem raw index {v(d)}}]] \
  [list {-1 0 -1} 2 1]

# SGN15 -- THE BIG ONE. A transient that HAS published, because the user put
# cursor B on a waveform, must still paint the real value at that time. This is
# the row that separates "nothing was published" from "the run was a transient".
# A guard written on the second reading passes every other row in this file and
# destroys the feature.
sgn_arm $sheet
sgn_rc [list xschem raw read $tran tran]
xschem set rectcolor 2
sgn_rc {xschem rect 0 -400 800 0 -1 {flags=graph} 0}
sgn_rc {xschem setprop rect 2 0 node {v(d)}}
foreach {k v} [list x1 0 x2 3e-9 y1 -1 y2 5] { sgn_rc [list xschem setprop rect 2 0 $k $v] }
sgn_rc {xschem setprop rect 2 0 fullyzoom}
sgn_rc {xschem cursor 2 1}
sgn_rc {xschem set cursor2_x 1e-9}
sgn_rc {xschem draw_graph 0}
check {SGN15 FENCE THE BIG ONE a transient WITH a waveform cursor has published, so the node text still paints the real value at that time} \
  [list [sgn_annot] [sgn_vd] [sgn_verb {v(d)}]] \
  [list {0 1e-09 0} {VDNODE=1.9} 1.9000001]

sgn_arm $sheet
sgn_rc [list xschem annotate_op $tran]
set sgn_g_tran [list [sgn_text {G=@spice_get_node 0 }] [sgn_text {G=@spice_get_node GND }]]
sgn_arm $sheet
sgn_rc [list xschem annotate_op $opraw]
set sgn_g_op [list [sgn_text {G=@spice_get_node 0 }] [sgn_text {G=@spice_get_node GND }]]
sgn_arm $sheet
set sgn_g_none [list [sgn_text {G=@spice_get_node 0 }] [sgn_text {G=@spice_get_node GND }]]
check {SGN16 FENCE a literal ground node still paints 0.0 in every state -- ground is a definition, not a measurement} \
  [list $sgn_g_tran $sgn_g_op $sgn_g_none] \
  [list {G=0.0 G=0.0} {G=0.0 G=0.0} {G=0.0 G=0.0}]

sgn_arm $sheet
sgn_rc [list xschem annotate_op $tran]
set sgn_m_tran [sgn_text {M=@spice_get_node v(nope) }]
sgn_arm $sheet
sgn_rc [list xschem annotate_op $opraw]
set sgn_m_op [sgn_text {M=@spice_get_node v(nope) }]
sgn_arm $sheet
set sgn_m_none [sgn_text {M=@spice_get_node v(nope) }]
check {SGN17 FENCE INVARIANT I3 a vector that is not in the results file still paints a dash in every state} \
  [list $sgn_m_tran $sgn_m_op $sgn_m_none] \
  {M=- M=- M=-}

# SGN18 -- the arm this fix lands on serves TWO cases, and the second one is a
# trap. Besides the annotation read, the same fall-through catches an explicit
# point that is OUT OF RANGE, and answers it with the annotation value wearing
# the label of a point that does not exist. This row pins BOTH halves so the
# outcome is decided rather than inherited from where a brace landed: after the
# fix the refused half blanks, and the PUBLISHED half is unchanged. That the
# published half still answers 1.8 for point 99 is its own defect, measured and
# filed as issue 0920, and deliberately not fixed here.
sgn_arm $sheet
sgn_rc [list xschem annotate_op $tran]
set sgn_oor_tran [sgn_rc {xschem raw value {v(d)} 99}]
sgn_arm $sheet
sgn_rc [list xschem annotate_op $opraw]
set sgn_oor_op [sgn_rc {xschem raw value {v(d)} 99}]
check {SGN18 an out-of-range point blanks while the annotation is refused, and is unchanged where one was published -- issue 0920} \
  [list $sgn_oor_tran $sgn_oor_op] \
  [list {} 1.8]

# ============================================================================
# SECTION E -- STRUCTURAL, FOR THE ONE THING NO BEHAVIOUR CAN SEE
# ============================================================================
# SGN19 is the row that is NOT optional. src/save.c carries a committed comment
# asserting that a seventh reader of the cursor value array is UNGUARDED and
# that six is the count of the guarded ones. Both sentences describe a live
# defect. Once it is fixed they are false, and NO behavioural row anywhere can
# tell, because a comment cannot be executed. A wrong comment about a guard is
# how the guard gets removed two years from now.
#
# SGN20 to SGN22 lock the SHAPE of the two guards so a sabotage variant maps to
# exactly one row. C comments are stripped BEFORE matching -- the comment text
# in both files quotes the very tokens being counted, so an unstripped grep
# would match prose and stay green over deleted code.
proc sgn_code {rel} {
  global repo
  set h [open [file join $repo $rel] r]; set d [read $h]; close $h
  regsub -all {/\*.*?\*/} $d " " d
  return $d
}
proc sgn_raw_src {rel} {
  global repo
  set h [open [file join $repo $rel] r]; set d [read $h]; close $h
  return $d
}
## The body of one function, from its head to the next closing brace in column
## zero. Written with no brace characters in this comment on purpose.
proc sgn_body {src head} {
  set i [string first $head $src]
  if {$i < 0} { return NOFUNC }
  set j [string first "\n\}" $src $i]
  if {$j < 0} { return NOEND }
  return [string range $src $i $j]
}
## The source between two needles -- used where the thing under test is one arm
## of a dispatcher and the enclosing function is thousands of lines long, so a
## brace scan would swallow every neighbour.
proc sgn_span {src a b} {
  set i [string first $a $src]
  if {$i < 0} { return NOFUNC }
  set j [string first $b $src $i]
  if {$j < 0} { return NOEND }
  return [string range $src $i $j]
}
## 0 when the extraction succeeded, and the marker itself when it did not -- so
## a needle that stopped matching reds its own row instead of quietly making
## every regexp below answer 0 and look like a missing guard.
proc sgn_found {b} {
  if {$b eq "NOFUNC" || $b eq "NOEND"} { return $b }
  return 0
}

set sgn_save [sgn_raw_src src/save.c]
check {SGN19 src/save.c no longer tells a future reader that a seventh reader of the cursor values is unguarded, nor that six is the count} \
  [list [regexp {INVENTORY IS SHORT BY ONE} $sgn_save] \
        [regexp {six live_cursor2 sites} $sgn_save] \
        [regexp {annot_p} $sgn_save]] \
  {0 0 1}

set sgn_tok  [sgn_code src/token.c]
set sgn_fn   [sgn_body $sgn_tok "const char \*spice_get_node(const char \*token)"]
check {SGN20 the schematic-text reader asks whether an annotation was published before it reads the cursor values} \
  [list [sgn_found $sgn_fn] \
        [regexp {get_raw_index} $sgn_fn] \
        [regexp {annot_p} $sgn_fn] \
        [regexp -all {cursor_b_val\[} $sgn_fn]] \
  {0 1 1 1}

set sgn_sch  [sgn_code src/scheduler.c]
set sgn_arm2 [sgn_span $sgn_sch "!strcmp(argv\[2\], \"value\")" "!strcmp(argv\[2\], \"del\")"]
check {SGN21 the raw value verb asks the same question before it falls through to the cursor values} \
  [list [sgn_found $sgn_arm2] \
        [regexp {get_raw_index} $sgn_arm2] \
        [regexp {annot_p} $sgn_arm2] \
        [regexp -all {cursor_b_val\[} $sgn_arm2]] \
  {0 1 1 1}

check {SGN22 FENCE the numbered-point reader inside that same verb is untouched -- the guard did not swallow the arm next to it} \
  [list [regexp {get_raw_value\(dataset, idx, point\)} $sgn_arm2] \
        [regexp {point < raw->npoints\[dataset\]} $sgn_arm2]] \
  {1 1}

# --- teardown ----------------------------------------------------------------
catch {xschem raw clear}

# --- verdict -----------------------------------------------------------------
# The DUAL banner is required by tests/run_regression.tcl's hcases list, which
# this file is registered in. banner_complete needs a WHOLE-LINE "OVERALL: ok"
# as well as the RESULT line; registering a suite there without one reproduces
# the completion-sentinel false red filed four times as 0420 / 0492 / 0629 / 0689.
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  puts "OVERALL: ok"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  puts "OVERALL: notok"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
