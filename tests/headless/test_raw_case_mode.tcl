# test_raw_case_mode.tcl — the raw reader stores variable names VERBATIM, and
# Raw.case_sensitive is the only thing left of the "case mode".
# Casemode batch item 1. Design: doc/claude/casemode_batch/DESIGN_REVISION.md
# sections 4/6/7/8; spec: doc/claude/specs/raw_case_mode.md.
#
# WHAT CHANGED. read_dataset() used to strtolower() every variable name
# (save.c:1008). That fold was never about display -- get_raw_index()
# transforms the QUERY (verbatim -> UPPER -> lower -> v(...)), so with every
# stored name lowercase, both `v(en)` and `v(EN)` resolved. The price was the
# whole feature a case-capable ngspice exists for: under `preserve` the file
# says v(EN) and the browser said v(en), and under `distinguish` `EN` and `en`
# are two real signals whose folded keys collide, with XINSERT_NOREPLACE
# silently dropping the second.
#
# THE LOAD-BEARING CHECKS, and why:
#   CS2/CS3  the headline. tr_preserve.raw's names must come back with their
#            capitals. Before item 1 these read v(in)/v(midnode)/i(vs).
#   CS8..11  AC derives FOUR names per variable -- v(X), ph(X), re(X), im(X) --
#            from varname AFTER the point the fold used to sit at
#            (save.c AC arm). All four must carry the case, not just the first;
#            item 2's alias work has to cover all four too.
#   CS20     ngspice::ngspice_data KEYS STAY FOLDED. They are a published Tcl
#            interface (ngspice_backannotate.tcl, user scripts doing
#            $ngspice::ngspice_data(v(en))) and were lowercase only because the
#            stored name was. One assertion, both halves: capitals stored AND
#            the published key lowercase. Splitting it would leave a half that
#            passes before the feature exists.
#   CS24/25  `xschem raw case <mode>` RE-READS the file. Proven by a change made
#            only in memory (a rename) being gone afterwards -- a flag flip that
#            happens to look right on a file that was never folded is not
#            evidence of a re-read.
#
# The two fixtures are committed, byte-comparable, and need no ngspice at all:
# doc/claude/casemode_batch/fixtures/tr_{fold,preserve}.raw differ ONLY in their
# Variables section. This suite is their first consumer.
#
# Run TRUE HEADLESS from the repo root (needs no display):
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_raw_case_mode.tcl

source [file join [file dirname [info script]] scratch.tcl]

set fail 0
set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail"; incr npass } \
  else { puts "FAIL: $name $detail"; incr fail }
}
proc eqcheck {name got want} {
  check $name [expr {$got eq $want}] "(got '$got' want '$want')"
}
proc pcall {args} {
  if {[catch {uplevel 1 $args} r]} { return "ERR:$r" }
  return $r
}
# 1 if the command raised a Tcl error (used for the option-parse refusals)
proc errs {args} {
  return [catch {uplevel 1 $args}]
}

set here [file normalize [file dirname [info script]]]
set fixdir [file normalize [file join $here .. .. doc claude casemode_batch fixtures]]
set foldraw [file join $fixdir tr_fold.raw]
set presraw [file join $fixdir tr_preserve.raw]

# A missing fixture must FAIL, never skip: full_audit.sh scores a whole file
# SKIP on the substring, and "the fixtures went away" is a finding.
check CS0-fixtures-present [expr {[file exists $foldraw] && [file exists $presraw]}] \
  "($foldraw / $presraw)"
if {$fail} {
  puts "RESULT: $fail FAILED (0 passed)"
  flush stdout
  exit 1
}

set tmp [test_scratch rawcase]

proc wr {path body} {
  file mkdir [file dirname $path]
  set fp [open $path w]
  puts -nonewline $fp $body
  close $fp
}

# ---------------------------------------------------------------------------
# A. verbatim storage: the fold is gone
# ---------------------------------------------------------------------------
xschem raw clear
eqcheck CS1-read-fold-fixture [pcall xschem raw read $foldraw tran] 1
# an all-lowercase file is unchanged by the deletion: this is the "stock apt
# ngspice sees no difference" row of DESIGN_REVISION.md section 5
eqcheck CS1b-fold-names [pcall xschem raw list] "time\nv(in)\nv(midnode)\ni(vs)"

xschem raw clear
eqcheck CS2-read-preserve-fixture [pcall xschem raw read $presraw tran] 1
eqcheck CS2b-preserve-names-verbatim [pcall xschem raw list] \
  "time\nv(In)\nv(MidNode)\ni(Vs)"
eqcheck CS3-exact-query-hits [pcall xschem raw index v(MidNode)] 2
# the data is untouched by the name change: same shape as the folded twin
eqcheck CS4-points [pcall xschem raw points] 229
eqcheck CS4b-vars [pcall xschem raw vars] 4
set pres_v [pcall xschem raw value v(MidNode) 100]
xschem raw clear
xschem raw read $foldraw tran
set fold_v [pcall xschem raw value v(midnode) 100]
check CS5-same-data-both-fixtures [expr {$pres_v eq $fold_v}] \
  "(preserve='$pres_v' fold='$fold_v')"

# ---------------------------------------------------------------------------
# B. AC: all FOUR derived names carry the case (DESIGN_REVISION section 8)
# ---------------------------------------------------------------------------
# Written as an ASCII raw so it needs no simulator. `Flags: complex` + the AC
# plotname put read_dataset() on the AC arm, where names[i<<2 .. +3] are built
# from varname: v(Out) -> v(Out), ph(Out), re(Out), im(Out).
wr $tmp/ac_mixed.raw "Title: ac mixed case
Date: Sat Aug 16 00:00:00 2026
Plotname: AC Analysis
Flags: complex
No. Variables: 2
No. Points: 2
Variables:
\t0\tfrequency\tfrequency
\t1\tv(Out)\tvoltage
Values:
0\t1.0,0.0
\t0.5,0.25

1\t2.0,0.0
\t0.25,0.125

"
xschem raw clear
eqcheck CS6-read-ac [pcall xschem raw read $tmp/ac_mixed.raw ac] 1
eqcheck CS7-ac-vars [pcall xschem raw vars] 8
set aclist [pcall xschem raw list]
eqcheck CS8-ac-mag-verbatim  [expr {[lsearch -exact [split $aclist \n] {v(Out)}]  >= 0}] 1
eqcheck CS9-ac-ph-verbatim   [expr {[lsearch -exact [split $aclist \n] {ph(Out)}] >= 0}] 1
eqcheck CS10-ac-re-verbatim  [expr {[lsearch -exact [split $aclist \n] {re(Out)}] >= 0}] 1
eqcheck CS11-ac-im-verbatim  [expr {[lsearch -exact [split $aclist \n] {im(Out)}] >= 0}] 1
# and no lowercase twin sneaked in beside them
check CS12-no-folded-ac-twins \
  [expr {[lsearch -exact [split $aclist \n] {v(out)}] < 0 &&
         [lsearch -exact [split $aclist \n] {ph(out)}] < 0 &&
         [lsearch -exact [split $aclist \n] {re(out)}] < 0 &&
         [lsearch -exact [split $aclist \n] {im(out)}] < 0}] \
  "(list='[string map {\n |} $aclist]')"
# the sweep variable's own quad is intact (it was already lowercase)
check CS13-ac-sweep-quad \
  [expr {[lsearch -exact [split $aclist \n] {frequency}] >= 0 &&
         [lsearch -exact [split $aclist \n] {ph(frequency)}] >= 0}] \
  "(list='[string map {\n |} $aclist]')"

# ---------------------------------------------------------------------------
# C. Raw.case_sensitive and the -case option
# ---------------------------------------------------------------------------
xschem raw clear
xschem raw read $presraw tran
eqcheck CS14-default-is-case-insensitive [pcall xschem raw case] 0

xschem raw clear
eqcheck CS15-read-case-distinguish [pcall xschem raw read $presraw tran -case distinguish] 1
eqcheck CS15b-flag-set [pcall xschem raw case] 1
# preserve keeps the file's spelling but does NOT make EN and en two signals
xschem raw clear
xschem raw read $presraw tran -case preserve
eqcheck CS16-preserve-is-not-case-sensitive [pcall xschem raw case] 0
xschem raw clear
xschem raw read $presraw tran -case fold
eqcheck CS17-fold-is-not-case-sensitive [pcall xschem raw case] 0
# ... and the names are verbatim under EVERY mode: the mode no longer reaches
# the reader at all
eqcheck CS17b-fold-mode-still-verbatim [pcall xschem raw list] \
  "time\nv(In)\nv(MidNode)\ni(Vs)"

# refusals, and they must refuse BEFORE reading anything
xschem raw clear
xschem raw read $foldraw tran
eqcheck CS18-bad-mode-errors [errs xschem raw read $presraw tran -case sideways] 1
eqcheck CS18b-bad-mode-read-nothing [pcall xschem raw list] "time\nv(in)\nv(midnode)\ni(vs)"
eqcheck CS19-missing-mode-errors [errs xschem raw read $presraw tran -case] 1

# the option must not eat the positional sweep window
xschem raw clear
xschem raw read $presraw tran 0 5e-10
set sweep_pts [pcall xschem raw points]
check CS20-sweep-window-narrows [expr {$sweep_pts > 0 && $sweep_pts < 229}] \
  "(points=$sweep_pts of 229)"
xschem raw clear
xschem raw read $presraw tran 0 5e-10 -case distinguish
eqcheck CS20b-sweep-window-with-option [pcall xschem raw points] $sweep_pts
eqcheck CS20c-and-the-flag-took [pcall xschem raw case] 1

# ---------------------------------------------------------------------------
# D. ngspice_data keys stay FOLDED (DESIGN_REVISION section 6)
# ---------------------------------------------------------------------------
xschem raw clear
xschem raw read $presraw tran
catch {array unset ::ngspice::ngspice_data}
eqcheck CS21-update_op [pcall xschem update_op] 1
# ONE assertion, both halves: the stored name has capitals AND the published
# key is lowercase. Either half alone would pass before the fold was deleted.
check CS22-published-keys-folded \
  [expr {[string first {v(MidNode)} [pcall xschem raw list]] >= 0 &&
         [info exists ::ngspice::ngspice_data(v(midnode))] &&
         ![info exists ::ngspice::ngspice_data(v(MidNode))]}] \
  "(list='[string map {\n |} [pcall xschem raw list]]' keys='[lsort [array names ::ngspice::ngspice_data]]')"
# the current arm too, not just voltages
check CS23-published-current-key-folded \
  [expr {[info exists ::ngspice::ngspice_data(i(vs))] &&
         ![info exists ::ngspice::ngspice_data(i(Vs))]}] \
  "(keys='[lsort [array names ::ngspice::ngspice_data]]')"

# ---------------------------------------------------------------------------
# D2. the SECOND publish site: the cursor-B publisher in callback.c
# ---------------------------------------------------------------------------
# update_op() above is one of two places that write ngspice::ngspice_data; the
# other is backannotate_cursor_b_in_db() (callback.c), reached by placing
# cursor B on a graph. Both had to grow the same strtolower, so both are driven.
# Rect 0 of GRIDLAYER is the one `xschem set cursor2_x` drives (scheduler.c);
# the shape of this setup is test_wave_cursor_crossdb's.
xschem raw clear
xschem raw read $presraw tran
set tend [pcall xschem raw value time 228]
xschem set rectcolor 2
xschem rect 0 0 800 400 -1 {flags=graph} 0
xschem setprop rect 2 0 node "v(MidNode)"
foreach {k v} [list x1 0 x2 $tend y1 -0.3 y2 1.3] { xschem setprop rect 2 0 $k $v }
xschem setprop rect 2 0 fullyzoom
xschem cursor 2 1
catch {array unset ::ngspice::ngspice_data}
xschem set cursor2_x [expr {$tend / 2.0}]
check CS23c-cursor-b-annotated [expr {[lindex [pcall xschem raw annot] 0] >= 0}] \
  "(annot='[pcall xschem raw annot]')"
check CS23d-cursor-publisher-keys-folded \
  [expr {[string first {v(MidNode)} [pcall xschem raw list]] >= 0 &&
         [info exists ::ngspice::ngspice_data(v(midnode))] &&
         ![info exists ::ngspice::ngspice_data(v(MidNode))]}] \
  "(keys='[lsort [array names ::ngspice::ngspice_data]]')"
xschem unselect_all

# ---------------------------------------------------------------------------
# E. `xschem raw case <mode>` RE-READS the file
# ---------------------------------------------------------------------------
xschem raw clear
xschem raw read $presraw tran
eqcheck CS24-rename-in-memory [pcall xschem raw rename v(MidNode) zz_marker] 1
eqcheck CS24b-rename-took [pcall xschem raw list] "time\nv(In)\nzz_marker\ni(Vs)"
eqcheck CS25-set-case-rereads [pcall xschem raw case distinguish] 1
# the in-memory-only edit is GONE: the database came off disk again
eqcheck CS25b-marker-gone [pcall xschem raw list] "time\nv(In)\nv(MidNode)\ni(Vs)"
eqcheck CS25c-marker-unresolvable [pcall xschem raw index zz_marker] -1
eqcheck CS25d-flag-set-by-the-set [pcall xschem raw case] 1
# the re-read kept everything else about the database
eqcheck CS25e-points-survive [pcall xschem raw points] 229
eqcheck CS25f-simtype-survives [pcall xschem raw sim_type] tran
eqcheck CS25g-rawfile-survives [pcall xschem raw rawfile] $presraw

# the getter's own output round-trips through the setter
eqcheck CS26-roundtrip-back-to-0 [pcall xschem raw case 0] 1
eqcheck CS26b-flag-cleared [pcall xschem raw case] 0
eqcheck CS27-bad-mode-errors [errs xschem raw case sideways] 1
eqcheck CS27b-flag-unchanged-after-refusal [pcall xschem raw case] 0

# ---------------------------------------------------------------------------
# F. BARE names -- no parentheses anywhere (fix round, review finding)
# ---------------------------------------------------------------------------
# Every mixed-case name in sections A-E has the shape func(Name), so a partial
# fold that lowercased only names WITHOUT a '(' passed all 47 of them. Real raws
# are full of bare names: device vectors `@M1[Id]`, the dc sweep variable
# `v-sweep`, Xyce-style bare nodes. These are also the names get_raw_index()'s
# `v(...)` rung cannot rescue, so item 2 needs the same fixture.
wr $tmp/barenames.raw "Title: bare names
Date: Sat Aug 16 00:00:00 2026
Plotname: Transient Analysis
Flags: real
No. Variables: 3
No. Points: 2
Variables:
\t0\ttime\ttime
\t1\t@M1\[Id\]\tcurrent
\t2\tMyNode\tvoltage
Values:
0\t0.0
\t1.0
\t2.0

1\t1e-9
\t1.5
\t2.5

"
xschem raw clear
eqcheck CS28-read-barenames [pcall xschem raw read $tmp/barenames.raw tran] 1
eqcheck CS28b-barenames-verbatim [pcall xschem raw list] "time\n@M1\[Id\]\nMyNode"

# ---------------------------------------------------------------------------
# G. AC with an UPPERCASE function prefix (fix round, review finding)
# ---------------------------------------------------------------------------
# The AC arm recognises a `v(` prefix to build ph()/re()/im() off the node name
# alone. That test used to be case-SENSITIVE and only ever matched because the
# deleted fold had just lowercased varname. Left alone, `V(Out)` fell to the
# else-branch and derived ph(V(Out)) -- a different STRING, not a differently
# cased one, which item 2's folded-alias rung could never repair (folding
# ph(V(Out)) yields ph(v(out)), never ph(out)). Uppercase `V(` is exactly the
# Xyce shape section 5 of the spec rules about.
wr $tmp/ac_upper.raw "Title: ac upper prefix
Date: Sat Aug 16 00:00:00 2026
Plotname: AC Analysis
Flags: complex
No. Variables: 2
No. Points: 2
Variables:
\t0\tfrequency\tfrequency
\t1\tV(Out)\tvoltage
Values:
0\t1.0,0.0
\t0.5,0.25

1\t2.0,0.0
\t0.25,0.125

"
xschem raw clear
eqcheck CS29-read-ac-upper [pcall xschem raw read $tmp/ac_upper.raw ac] 1
# the magnitude name keeps the file's own spelling ...
eqcheck CS29b-ac-upper-mag-verbatim [pcall xschem raw index {V(Out)}] 4
# ... and the three derived names are built off the NODE, not off "V(Out)"
eqcheck CS29c-ac-upper-derived-shape [pcall xschem raw list] \
  "frequency\nph(frequency)\nre(frequency)\nim(frequency)\nV(Out)\nph(Out)\nre(Out)\nim(Out)"
eqcheck CS29d-ac-upper-ph-resolves [pcall xschem raw index ph(Out)] 5

# ---------------------------------------------------------------------------
# H. a failed re-read must not destroy the database (fix round, review finding)
# ---------------------------------------------------------------------------
# `raw case <mode>` has to delete the registry entry before it can re-read the
# same filename, so it used to free the data before it knew the read could
# work: an unreadable backing file silently annihilated the database and
# reported it as the string "0". Not exotic -- a re-running simulator replaces
# its raw file, and raw_read_from_attr() unlink()s the temp file whose name it
# leaves in raw->rawfile, so an embedded spice_data raw is ALWAYS in that state.
file copy -force $presraw $tmp/vanish.raw
xschem raw clear
eqcheck CS30-read-copy [pcall xschem raw read $tmp/vanish.raw tran] 1
set before_vanish [pcall xschem raw list]
file delete $tmp/vanish.raw
eqcheck CS30b-set-on-missing-file-errors [errs xschem raw case distinguish] 1
eqcheck CS30c-database-survives [pcall xschem raw list] $before_vanish
eqcheck CS30d-still-loaded [expr {[pcall xschem raw loaded] >= 0}] 1
eqcheck CS30e-flag-unchanged [pcall xschem raw case] 0

# ... and a database with no backing file at all is refused the same way
xschem raw clear
eqcheck CS31-new-synthetic [pcall xschem raw new synthdb dc tsweep 0 1 10] 1
eqcheck CS31b-set-on-synthetic-errors [errs xschem raw case distinguish] 1
eqcheck CS31c-synthetic-survives [pcall xschem raw list] tsweep

# ---------------------------------------------------------------------------
# I. the re-read uses the type the CALLER asked for (fix round, finding)
# ---------------------------------------------------------------------------
# read_dataset() PROMOTES a multi-point "Operating Point" raw to sim_type "dc",
# and the type argument is matched against the Plotname line -- so re-reading
# that file as "dc" can never match. The set therefore failed on every ordinary
# multi-point .op raw, and (before the fix above) destroyed it on the way out.
wr $tmp/multiop.raw "Title: multi point op
Date: Sat Aug 16 00:00:00 2026
Plotname: Operating Point
Flags: real
No. Variables: 2
No. Points: 3
Variables:
\t0\tv-sweep\tvoltage
\t1\tv(Out)\tvoltage
Values:
0\t0.0
\t1.0

1\t1.0
\t2.0

2\t2.0
\t3.0

"
xschem raw clear
eqcheck CS32-read-multiop [pcall xschem raw read $tmp/multiop.raw op] 1
eqcheck CS32b-promoted-to-dc [pcall xschem raw sim_type] dc
eqcheck CS32c-set-case-succeeds [pcall xschem raw case distinguish] 1
eqcheck CS32d-multiop-survives [pcall xschem raw list] "v-sweep\nv(Out)"
eqcheck CS32e-points-survive [pcall xschem raw points] 3

# the sweep window survives the re-read too: the spec says "same file/sim_type/
# sweep window", and CS25e only ever measured a FULL read
xschem raw clear
xschem raw read $presraw tran 0 5e-10
set win_pts [pcall xschem raw points]
eqcheck CS33-window-set [expr {$win_pts > 0 && $win_pts < 229}] 1
eqcheck CS33b-set-case-keeps-window-read [pcall xschem raw case distinguish] 1
eqcheck CS33c-window-survives-reread [pcall xschem raw points] $win_pts

# ---------------------------------------------------------------------------
# J. `-case` on an ALREADY-LOADED database re-reads too (fix round, finding)
# ---------------------------------------------------------------------------
# extra_rawfile() only SWITCHES to a file it already holds, so `raw read <same
# file> -case <mode>` used to stamp the flag with nothing read -- exactly the
# flag flip section 3 forbids, reached by the other verb. Measured by the same
# in-memory-only rename CS25b uses.
xschem raw clear
xschem raw read $presraw tran
eqcheck CS34-rename-again [pcall xschem raw rename v(MidNode) zz_marker2] 1
eqcheck CS34b-reread-same-file [pcall xschem raw read $presraw tran -case distinguish] 1
eqcheck CS34c-marker-gone [pcall xschem raw list] "time\nv(In)\nv(MidNode)\ni(Vs)"
eqcheck CS34d-flag-took [pcall xschem raw case] 1
# and the non-zero value round-trips through the setter, which is the reason the
# spec gives for accepting the 0/1 tokens at all (CS26 only round-tripped 0)
eqcheck CS35-roundtrip-1 [pcall xschem raw case [pcall xschem raw case]] 1
eqcheck CS35b-still-1 [pcall xschem raw case] 1

# ---------------------------------------------------------------------------
# K. two names differing only in case collide on ONE published key
# ---------------------------------------------------------------------------
# Folding the publish key is the same lossy operation the read path was
# condemned for. Under `distinguish` a database can hold v(EN) and v(en); they
# collapse onto one ngspice_data key. FIRST WRITER WINS (matching the read
# side's XINSERT_NOREPLACE) and the loser is named in a dbg(0) -- lossy is
# tolerable here until item 5b, silent is not. Both values stay reachable from
# the DATABASE under their own spelling, which is what the last two check.
wr $tmp/op_case.raw "Title: case collision
Date: Sat Aug 16 00:00:00 2026
Plotname: Operating Point
Flags: real
No. Variables: 3
No. Points: 1
Variables:
\t0\tv(sweep)\tvoltage
\t1\tv(EN)\tvoltage
\t2\tv(en)\tvoltage
Values:
0\t0.0
\t1.111
\t2.222

"
xschem raw clear
eqcheck CS36-read-collision [pcall xschem raw read $tmp/op_case.raw op -case distinguish] 1
eqcheck CS36b-both-stored [pcall xschem raw list] "v(sweep)\nv(EN)\nv(en)"
catch {array unset ::ngspice::ngspice_data}
eqcheck CS36c-update_op [pcall xschem update_op] 1
# one key, and it holds the FIRST variable's value, not the last one's
# (the array key has to come out through a plain variable: `v(en)` inside an
# expr{} reads as a function call and dies on the parens)
set collide_key <missing>
catch {set collide_key [set ::ngspice::ngspice_data(v(en))]}
set collide_upper <missing>
catch {set collide_upper [set ::ngspice::ngspice_data(v(EN))]}
check CS36d-first-writer-keeps-the-key \
  [expr {[string is double -strict $collide_key] && abs($collide_key - 1.111) < 1e-4}] \
  "(key v(en)='$collide_key')"
# and the loser was NOT published under a capitalised key either: the array's
# keys stay folded (section 4), the second value simply is not in the array
eqcheck CS36e-no-capitalised-key $collide_upper <missing>
# nothing is lost from the DATABASE itself
set dbEN [pcall xschem raw value {v(EN)} 0]
set dben [pcall xschem raw value {v(en)} 0]
check CS36f-both-readable-from-db \
  [expr {abs($dbEN - 1.111) < 1e-4 && abs($dben - 2.222) < 1e-4}] \
  "(EN='$dbEN' en='$dben')"

xschem raw clear
catch {test_scratch_drop $tmp}
puts "----"
puts "test_raw_case_mode: $npass passed, $fail failed"
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
