# test_raw_case_mode.tcl — the raw reader stores variable names VERBATIM, and
# Raw.case_sensitive is the only thing left of the "case mode".
# Casemode batch item 1. Design: doc/claude/casemode_batch/DESIGN_REVISION.md
# sections 4/6/7/8; spec: doc/claude/specs/raw_case_mode.md.
#
# WHAT CHANGED. read_dataset() used to strtolower() every variable name
# (save.c:1008). That fold was never about display -- get_raw_index() also
# transformed the QUERY (verbatim -> UPPER -> lower -> v(...), all in place on
# one buffer), so with every stored name lowercase, both `v(en)` and `v(EN)`
# resolved. (Item 2 replaced that ladder; see section N and the file's later
# sections for the shape it has now.) The price was the
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
# a broken reader hands back "" or an ERR: string here, and `$tend / 2.0` below
# would then be a Tcl ERROR that ABORTS the whole file -- no RESULT line, every
# later check silently unmeasured, and a sabotage measurement that reads as
# "nothing went red". Degrade to a number and let the checks fail instead.
if {![string is double -strict $tend]} { set tend 0.0 }
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
# both halves must be NUMBERS before arithmetic: a mutation of the exact lookup
# rung empties them, and `abs("" - 1.111)` is a Tcl error that ABORTS the file
# rather than failing this check -- which makes every later check unmeasured and
# a sabotage look harmless. Same hardening as CS40e.
check CS36f-both-readable-from-db \
  [expr {[string is double -strict $dbEN] && [string is double -strict $dben] &&
         abs($dbEN - 1.111) < 1e-4 && abs($dben - 2.222) < 1e-4}] \
  "(EN='$dbEN' en='$dben')"

# ===========================================================================
# ITEM 2 — ONE LOOKUP LADDER (get_raw_index)
# ===========================================================================
# spec doc/claude/specs/raw_case_mode.md section 9; PLAN.md 3b item 2;
# DECISIONS.md D2. The ladder is now
#     exact -> case-folded alias -> v() wrap (exact, then folded)
#           -> `i(v.x` prefix rewritten to `i(` (exact, then folded)
# and it NO LONGER MUTATES THE QUERY, which is what made every bare mixed-case
# name miss after item 1 -- including the correctly spelled one.

# ---------------------------------------------------------------------------
# L. the acceptance check item 1's spec section 2 owed this item
# ---------------------------------------------------------------------------
xschem raw clear
eqcheck CS37-read-preserve [pcall xschem raw read $presraw tran] 1
# `MidNode` is the NORMAL spelling of a graph rect's node= attribute. Before
# item 2 this answered -1 on this very fixture: the ladder lowercased its own
# buffer before building the v(%s) rung, so it could only ever probe
# v(midnode), which is not in this file.
eqcheck CS37b-bare-exact-case    [pcall xschem raw index MidNode] 2
eqcheck CS37c-bare-lower         [pcall xschem raw index midnode] 2
eqcheck CS37d-bare-upper         [pcall xschem raw index MIDNODE] 2
eqcheck CS37e-bare-other-node    [pcall xschem raw index In] 1
# the wrapped forms, in every casing
eqcheck CS37f-wrapped-exact      [pcall xschem raw index {v(MidNode)}] 2
eqcheck CS37g-wrapped-lower      [pcall xschem raw index {v(midnode)}] 2
eqcheck CS37h-wrapped-upper      [pcall xschem raw index {V(MIDNODE)}] 2
# currents are not a special case
eqcheck CS37i-current-lower      [pcall xschem raw index {i(vs)}] 3
eqcheck CS37j-current-upper      [pcall xschem raw index {I(VS)}] 3
# ... and the ladder still says NO. A rung that answers everything is not a
# lookup; this is the check that keeps the ones above from being vacuous.
eqcheck CS37k-absent-still-misses [pcall xschem raw index NoSuchNodeAtAll] -1
eqcheck CS37l-absent-wrapped      [pcall xschem raw index {v(nosuchnode)}] -1

# ---------------------------------------------------------------------------
# M. bare device vectors and the @dev[param] shape (savecurrents, preserve)
# ---------------------------------------------------------------------------
# `.options savecurrents` under `preserve` writes i(@R.X1.Rq[i]); F4 of the
# plan measured it. These are ordinary stored names, so rungs 1-2 resolve them
# -- but the v() rung never could, which is why the pre-item-2 ladder failed
# them outright. `i(V.X1.Vp)` is the hierarchical voltage-source current from
# the same measurement.
wr $tmp/devvec.raw "Title: device vectors, preserve
Date: Sat Aug 16 00:00:00 2026
Plotname: Transient Analysis
Flags: real
No. Variables: 4
No. Points: 2
Variables:
\t0\ttime\ttime
\t1\ti(@R.X1.Rq\[i\])\tcurrent
\t2\ti(V.X1.Vp)\tcurrent
\t3\tMyNode\tvoltage
Values:
0\t0.0
\t1.0
\t2.0
\t3.0

1\t1e-9
\t1.5
\t2.5
\t3.5

"
xschem raw clear
eqcheck CS38-read-devvec [pcall xschem raw read $tmp/devvec.raw tran] 1
eqcheck CS38b-devvec-verbatim [pcall xschem raw list] \
  "time\ni(@R.X1.Rq\[i\])\ni(V.X1.Vp)\nMyNode"
eqcheck CS38c-atdev-exact   [pcall xschem raw index {i(@R.X1.Rq[i])}] 1
eqcheck CS38d-atdev-folded  [pcall xschem raw index {i(@r.x1.rq[i])}] 1
eqcheck CS38e-atdev-upper   [pcall xschem raw index {I(@R.X1.RQ[I])}] 1
eqcheck CS38f-hier-i-folded [pcall xschem raw index {i(v.x1.vp)}] 2
eqcheck CS38g-bare-folded   [pcall xschem raw index mynode] 3
# and the two device shapes are still distinguishable from each other
eqcheck CS38h-not-everything-hits [pcall xschem raw index {i(@R.X1.Rz[i])}] -1

# ---------------------------------------------------------------------------
# N. the `i(v.x` fixup, now case-aware
# ---------------------------------------------------------------------------
# ngspice names the current of a voltage source inside subcircuit x1
# `i(v.x1.vp)` in some versions and `i(x1.vp)` in others; the ladder drops the
# `v.`. The rung broke at item 1 -- not because of the QUERY's case (the old
# in-place strtolower() destroyed that before the rung ever ran) but because the
# STORED name kept its capitals, so the lowercased probe `i(x1.vp)` no longer
# matched `i(X1.Vp)`.
#
# THE BAIT COLUMN, `i(.x1.vp)`, is what makes CS39f a real check. The old rung
# was an UNANCHORED strstr() that rewrote bytes 2 and 3 regardless of where it
# matched, so the query `xi(v.x1.vp)` probed exactly `i(.x1.vp)`. Without a
# stored name of that spelling the query misses under anchored and unanchored
# code alike and the check cannot fail; with it, an unanchored rung resolves it
# to column 2 and CS39f goes red. (Measured: the first version of CS39f stayed
# green under a deliberately unanchored rung -- review finding, fix round.)
wr $tmp/hiercur.raw "Title: hierarchical current
Date: Sat Aug 16 00:00:00 2026
Plotname: Transient Analysis
Flags: real
No. Variables: 3
No. Points: 2
Variables:
\t0\ttime\ttime
\t1\ti(X1.Vp)\tcurrent
\t2\ti(.x1.vp)\tcurrent
Values:
0\t0.0
\t1.0
\t7.0

1\t1e-9
\t1.5
\t7.5

"
xschem raw clear
eqcheck CS39-read-hiercur [pcall xschem raw read $tmp/hiercur.raw tran] 1
eqcheck CS39b-exact           [pcall xschem raw index {i(X1.Vp)}] 1
# the fixup, in the spelling the OLD ladder handled (must not regress) ...
eqcheck CS39c-fixup-lower     [pcall xschem raw index {i(v.x1.vp)}] 1
# ... and in the spellings it could not reach
eqcheck CS39d-fixup-mixed     [pcall xschem raw index {i(V.X1.Vp)}] 1
eqcheck CS39e-fixup-upper     [pcall xschem raw index {I(V.X1.VP)}] 1
# the bait really is in the database (without this CS39f is vacuous) ...
eqcheck CS39g-bait-stored [pcall xschem raw list] "time\ni(X1.Vp)\ni(.x1.vp)"
eqcheck CS39h-bait-resolves-exactly [pcall xschem raw index {i(.x1.vp)}] 2
# ... and the rewrite is ANCHORED, so the query that the unanchored rung turned
# into the bait's own spelling resolves to nothing
eqcheck CS39f-not-anchored-misses [pcall xschem raw index {xi(v.x1.vp)}] -1

# ---------------------------------------------------------------------------
# O. D2 — no folded alias when two DIFFERENT stored names collide
# ---------------------------------------------------------------------------
# VCD is where a case collision is legitimate: Verilog identifiers are
# case-sensitive, so `Count` and `count` are two real signals. Answering a
# `COUNT` query with an arbitrary one of them is the guess D2 forbids.
# receipts/00a-suite-sweep.md finding 4: no committed test exercises a
# collision at all -- TOP and top live in different fixtures of
# test_vcd_read.tcl, never in one database. This is that fixture.
wr $tmp/collide.vcd "\$timescale 1ps \$end
\$scope module m \$end
\$var wire 1 ! Count \$end
\$var wire 1 \" count \$end
\$var wire 1 # Enable \$end
\$upscope \$end
\$enddefinitions \$end
#0
\$dumpvars
1!
0\"
1#
\$end
#1000
"
xschem raw clear
eqcheck CS40-read-vcd-collision [pcall xschem raw read $tmp/collide.vcd vcd] 1
eqcheck CS40b-both-signals-stored [pcall xschem raw list] \
  "time\nm.Count\nm.count\nm.Enable"
# EXACT lookups are untouched by the rule -- that is the whole point of it
eqcheck CS40c-exact-Count [pcall xschem raw index m.Count] 1
eqcheck CS40d-exact-count [pcall xschem raw index m.count] 2
set vCount [pcall xschem raw value m.Count 0]
set vcount [pcall xschem raw value m.count 0]
# string comparison, and both halves required non-empty: `!=` on an empty
# string is a Tcl ERROR, which would abort the whole file rather than fail one
# check -- and a mutation that empties both would otherwise "pass"
check CS40e-exact-values-differ \
  [expr {$vCount ne "" && $vcount ne "" && $vCount ne $vcount}] \
  "(Count='$vCount' count='$vcount')"
# ... and only the FUZZY rung declines. First-wins (plain XINSERT_NOREPLACE)
# would answer this with an arbitrary one of the two.
eqcheck CS40f-ambiguous-declines [pcall xschem raw index m.COUNT] -1
# the helpful case is KEPT: a mixed-case name with no colliding twin still
# resolves from a differently-cased query, in the same database
eqcheck CS40g-noncolliding-still-folds [pcall xschem raw index m.enable] 3
eqcheck CS40h-noncolliding-upper       [pcall xschem raw index M.ENABLE] 3

# the same rule on a spice raw, read WITHOUT -case distinguish, so the flag is
# not what is doing the work: op_case.raw holds v(EN) and v(en)
xschem raw clear
eqcheck CS41-read-spice-collision [pcall xschem raw read $tmp/op_case.raw op] 1
eqcheck CS41b-flag-is-off [pcall xschem raw case] 0
eqcheck CS41c-exact-EN [pcall xschem raw index {v(EN)}] 1
eqcheck CS41d-exact-en [pcall xschem raw index {v(en)}] 2
eqcheck CS41e-ambiguous-declines [pcall xschem raw index {V(EN)}] -1
# the bare forms go through the v() wrap, where the ladder's ORDER decides:
# `EN` and `en` wrap to a name that exists EXACTLY, so they resolve to their
# own column and the collision rule never gets a say ...
eqcheck CS41f-bare-EN-exact-through-wrap [pcall xschem raw index EN] 1
eqcheck CS41g-bare-en-exact-through-wrap [pcall xschem raw index en] 2
# ... and only a spelling that matches NEITHER exactly reaches the folded rung
# and is declined
eqcheck CS41h-bare-mixed-ambiguous [pcall xschem raw index En] -1
eqcheck CS41i-noncolliding-in-same-db [pcall xschem raw index {V(SWEEP)}] 0

# ---------------------------------------------------------------------------
# P. two IDENTICAL stored names are NOT a collision (ngspice upstream 0073)
# ---------------------------------------------------------------------------
# `write f.raw v(In)` writes two columns with byte-identical names. Declining
# there would break a lookup that has exactly one sensible answer, so the rule
# is "two DIFFERENT names", not "two entries".
wr $tmp/dupcol.raw "Title: duplicate column names
Date: Sat Aug 16 00:00:00 2026
Plotname: Transient Analysis
Flags: real
No. Variables: 3
No. Points: 2
Variables:
\t0\ttime\ttime
\t1\tv(Dup)\tvoltage
\t2\tv(Dup)\tvoltage
Values:
0\t0.0
\t1.0
\t1.0

1\t1e-9
\t1.5
\t1.5

"
xschem raw clear
eqcheck CS42-read-dupcol [pcall xschem raw read $tmp/dupcol.raw tran] 1
eqcheck CS42b-exact-first-wins [pcall xschem raw index {v(Dup)}] 1
eqcheck CS42c-folded-still-resolves [pcall xschem raw index {v(dup)}] 1
eqcheck CS42d-folded-bare [pcall xschem raw index DUP] 1

# ---------------------------------------------------------------------------
# Q. suppressed entirely when the database is case_sensitive
# ---------------------------------------------------------------------------
xschem raw clear
eqcheck CS43-read-distinguish [pcall xschem raw read $presraw tran -case distinguish] 1
eqcheck CS43b-flag-set [pcall xschem raw case] 1
# exact spellings, wrapped or not, still resolve: the flag turns off the FOLD,
# not the ladder
eqcheck CS43c-exact-wrapped [pcall xschem raw index {v(MidNode)}] 2
eqcheck CS43d-exact-bare-through-wrap [pcall xschem raw index MidNode] 2
# and every folded form is refused
eqcheck CS43e-folded-bare-refused    [pcall xschem raw index midnode] -1
eqcheck CS43f-folded-wrapped-refused [pcall xschem raw index {v(midnode)}] -1
eqcheck CS43g-folded-upper-refused   [pcall xschem raw index {V(MIDNODE)}] -1
# clearing the flag (which re-reads) brings the folded rung back
eqcheck CS43h-clear-flag [pcall xschem raw case 0] 1
eqcheck CS43i-folded-resolves-again [pcall xschem raw index midnode] 2

# ---------------------------------------------------------------------------
# R. the alias index is INVISIBLE to every consumer
# ---------------------------------------------------------------------------
# This is the property that licenses building it at all. `xschem raw list` and
# `raw vars` iterate names[], never a hash table, so no alias can show up as a
# phantom signal -- driven AFTER a battery of fuzzy queries has forced the
# index to exist.
#
# THESE ARE ABSOLUTE ASSERTIONS, NOT BEFORE/AFTER COMPARISONS, and that is a
# review finding paid in full: the first version captured `raw list` and
# `raw vars` into `_before` variables and compared them with themselves after
# the fuzzy battery. There is no "before" to capture -- the graph rect built at
# CS23c makes `xschem raw read` itself resolve a node, so the index already
# exists by the time the section starts -- and worse, a self-comparison is green
# for ANY defect stable across two calls. Measured: with raw_build_fold_table()
# appending its alias to names[]/nvars as a real variable, `raw list` returned
# `time v(In) v(MidNode) i(Vs) __alias__` and `raw vars` returned 5, and all
# three checks printed `ok:` with `__alias__` inside the very string they
# compared. Spelling the fixture's own four names out is what makes them fail.
xschem raw clear
xschem raw read $presraw tran
foreach q {midnode MIDNODE v(midnode) I(VS) in nosuch} { pcall xschem raw index $q }
eqcheck CS44-list-unchanged-by-aliases [pcall xschem raw list] \
  "time\nv(In)\nv(MidNode)\ni(Vs)"
eqcheck CS44b-vars-unchanged-by-aliases [pcall xschem raw vars] 4
eqcheck CS44c-list-length-is-vars [llength [split [pcall xschem raw list] \n]] 4

# ---------------------------------------------------------------------------
# S. the alias index is dropped when names[] moves
# ---------------------------------------------------------------------------
# A stale index is worse than no index: after `raw del` every name below the
# deleted one has shifted down a column, so a surviving alias resolves to the
# WRONG DATA rather than missing.
xschem raw clear
xschem raw read $presraw tran
eqcheck CS45-fuzzy-before-rename [pcall xschem raw index midnode] 2
eqcheck CS45b-rename [pcall xschem raw rename {v(MidNode)} ZzTop] 1
eqcheck CS45c-old-fuzzy-name-gone [pcall xschem raw index midnode] -1
eqcheck CS45d-new-fuzzy-name-hits [pcall xschem raw index zztop] 2

# ... and a rename REACHED THROUGH the folded rung must delete the real hash
# entry, not the alias. get_raw_index() hands its caller the entry of the REAL
# name for exactly this reason: raw_renamevar() deletes by entry->token, so a
# folded token would leave `v(In)` in the table pointing at a column now called
# something else -- the old name would keep resolving.
xschem raw clear
xschem raw read $presraw tran
eqcheck CS45e-rename-via-folded-query [pcall xschem raw rename {v(in)} ZzIn] 1
eqcheck CS45f-renamed [pcall xschem raw list] "time\nZzIn\nv(MidNode)\ni(Vs)"
eqcheck CS45g-old-exact-entry-really-gone [pcall xschem raw index {v(In)}] -1
eqcheck CS45h-new-name-resolves [pcall xschem raw index zzin] 1

xschem raw clear
xschem raw read $presraw tran
eqcheck CS46-fuzzy-before-del [pcall xschem raw index {i(vs)}] 3
eqcheck CS46b-del [pcall xschem raw del {v(In)}] 1
eqcheck CS46c-names-shifted [pcall xschem raw list] "time\nv(MidNode)\ni(Vs)"
# 3 here would be a stale alias pointing one column past the end
eqcheck CS46d-fuzzy-follows-the-shift [pcall xschem raw index {i(vs)}] 2
eqcheck CS46e-deleted-name-gone [pcall xschem raw index in] -1

xschem raw clear
xschem raw read $presraw tran
eqcheck CS47-fuzzy-before-add [pcall xschem raw index newcol] -1
eqcheck CS47b-add [pcall xschem raw add NewCol {v(MidNode)}] 1
eqcheck CS47c-added-fuzzy-hits [pcall xschem raw index newcol] 4
eqcheck CS47d-added-exact-hits [pcall xschem raw index NewCol] 4

# ---------------------------------------------------------------------------
# T. a table_read database, which item 1 never drove
# ---------------------------------------------------------------------------
# Carry-forward from item 1's receipt section 5: `raw case` was driven on spice
# and VCD databases only. table_read() stores its header fields verbatim too,
# so the same ladder and the same re-read contract have to hold there.
wr $tmp/tab_mixed.txt "Time,V(Out),I(Rload)
0.0,1.0,0.1
1e-9,2.0,0.2
2e-9,3.0,0.3
"
xschem raw clear
eqcheck CS48-read-table [pcall xschem raw read $tmp/tab_mixed.txt table] 1
eqcheck CS48b-table-names-verbatim [pcall xschem raw list] "Time\nV(Out)\nI(Rload)"
eqcheck CS48c-table-exact  [pcall xschem raw index {V(Out)}] 1
eqcheck CS48d-table-folded [pcall xschem raw index {v(out)}] 1
eqcheck CS48e-table-bare-folded [pcall xschem raw index out] 1
eqcheck CS48f-table-current-folded [pcall xschem raw index {i(rload)}] 2
# `raw case` on a table database: the set re-reads (the in-memory-only rename
# is discarded) and the folded rung then declines
eqcheck CS48g-table-rename [pcall xschem raw rename {V(Out)} zz_tabmark] 1
eqcheck CS48h-table-set-case [pcall xschem raw case distinguish] 1
eqcheck CS48i-table-reread [pcall xschem raw list] "Time\nV(Out)\nI(Rload)"
eqcheck CS48j-table-flag [pcall xschem raw case] 1
eqcheck CS48k-table-folded-refused [pcall xschem raw index {v(out)}] -1
eqcheck CS48l-table-exact-still-hits [pcall xschem raw index {V(Out)}] 1

# ---------------------------------------------------------------------------
# U. the viewer's Tcl gate must not APPROVE what the ladder declines
# ---------------------------------------------------------------------------
# wviewer::validate_rpn is the gate wviewer::add_trace puts in front of
# `xschem raw add`, and it exists because raw_add_vector() swallows
# plot_raw_custom_data()'s -1: an unresolvable token produces a registered,
# plottable, all-ZERO vector, not an error. So a gate that is more permissive
# than get_raw_index() is not merely inconsistent, it is a silent wrong answer
# on the user's screen. Measured before the fix, at the DEFAULT `fold` mode with
# no mode change at all, on the very database D2 exists for:
#   xschem raw index COUNT      -> -1     (D2 declines, correctly)
#   validate_rpn {COUNT 2 *}    -> {}     (VALID -- the gate disagreed)
#   xschem raw add tst {COUNT 2 *} -> 1 ; xschem raw value tst 0 -> 0
# The gate now mirrors the ladder, D2 and `distinguish` included.
set wvsrc [file join $here .. .. src wave_viewer.tcl]
eqcheck CS49-source-wave-viewer [catch {source $wvsrc}] 0

# both verdicts on one token: want=1 means the engine resolves it AND the gate
# passes it; want=0 means both refuse. Disagreement in EITHER direction fails.
proc gatecheck {name tok want} {
  set vl [split [pcall xschem raw list] "\n"]
  set gate [pcall wviewer::validate_rpn "$tok 2 *" $vl]
  set eng [pcall xschem raw index $tok]
  set engok [expr {[string is integer -strict $eng] && $eng >= 0}]
  set gateok [expr {$gate eq {}}]
  check $name [expr {$engok == $want && $gateok == $want}] \
    "(token '$tok' engine=$eng gate='$gate' want [expr {$want ? {both resolve} : {both refuse}}])"
}

xschem raw clear
eqcheck CS49b-read-collision [pcall xschem raw read $tmp/op_case.raw op] 1
eqcheck CS49c-default-fold [pcall xschem raw case] 0
# the D2 collision: neither side may resolve `V(EN)` ...
gatecheck CS49d-collision-refused-by-both {V(EN)} 0
gatecheck CS49e-bare-mixed-refused-by-both En 0
# ... while every spelling the ladder DOES resolve still passes the gate, so the
# fix is not "refuse more"
gatecheck CS49f-exact-EN     {v(EN)} 1
gatecheck CS49g-exact-en     {v(en)} 1
gatecheck CS49h-bare-EN      EN 1
gatecheck CS49i-folded-noncolliding {V(SWEEP)} 1
gatecheck CS49j-unknown-refused-by-both nosuchnode 0
# a `distinguish` database turns the folded rung off on BOTH sides
eqcheck CS49k-set-distinguish [pcall xschem raw case distinguish] 1
gatecheck CS49l-folded-refused-under-distinguish {V(SWEEP)} 0
gatecheck CS49m-exact-kept-under-distinguish {v(sweep)} 1
eqcheck CS49n-clear-distinguish [pcall xschem raw case 0] 1
gatecheck CS49o-folded-resolves-again {V(SWEEP)} 1

# ===========================================================================
# CASEMODE ITEM 3 -- MODE RESOLUTION, FOUR SOURCES IN ORDER (CS50-CS64f)
# DECISIONS.md B2a/B2b; doc/claude/specs/raw_case_mode.md section 10.
#
#   explicit user setting -> `Option: casemode=` header -> schematic-name
#   comparison -> capital sniff (off by default)
#
# and none of them answering is UNKNOWN, never `fold`. `xschem raw casemode`
# reports; it does not touch the Raw.case_sensitive flag `xschem raw case` owns,
# and CS59h asserts exactly that.
#
# WHY THE HEADER SHAPES ARE WRITTEN INLINE rather than read from
# doc/claude/ngspice_upstream/feedback/ngspice_upstream/repro/hdr_*.raw, which
# is where they come from: those files are GITIGNORED (`repro/.gitignore` is
# `*.raw`) because they carry a clock and a build stamp and are regenerated by
# `repro/hdr_variants.sh` from a live case-capable ngspice. A committed suite
# cannot read them -- on a clean checkout they do not exist. Every header line
# below is copied byte for byte from the real spliced file it names, and the
# receipt records the same eleven files driven through this binary directly.
# ===========================================================================

# one-point ASCII op raw: <hdr> is everything above `No. Variables:`
proc oprawf {path hdr names} {
  set n [llength $names]
  set body "$hdr\nNo. Variables: $n\nNo. Points: 1\nVariables:\n"
  set i 0
  foreach nm $names { append body "\t$i\t$nm\tvoltage\n" ; incr i }
  append body "Values:\n 0"
  for {set i 0} {$i < $n} {incr i} { append body "\t[expr {$i + 1}].0\n" }
  append body "\n"
  wr $path $body
}
# the Title line is the DECK's own first line and is user text; the one below is
# verbatim from the upstream repro's ascii_raw.cir, splice comment and all
set utitle "Title: * writes an ascii raw, so finding 1's header experiments can splice a line in"
set udate  "Date: Thu Aug 13 15:54:04  2026"
set ucmd   "Command: ngspice-46+, Build Thu Aug 13 22:49:54 UTC 2026"
set uvars  {v(in) v(midnode)}

# ---------------------------------------------------------------------------
# V. source 2: the `Option: casemode=` header, and what is NOT it
# ---------------------------------------------------------------------------
# hdr_option.raw: the line where the writer puts it, immediately after Plotname
oprawf $tmp/h_option.raw \
  "$utitle\n$udate\n$ucmd\nPlotname: Operating Point\nOption: casemode=preserve\nFlags: real" $uvars
xschem raw clear
eqcheck CS50-read-hdr-option [pcall xschem raw read $tmp/h_option.raw op] 1
eqcheck CS50b-header-preserve [pcall xschem raw casemode -header] preserve
eqcheck CS50c-resolves-preserve [pcall xschem raw casemode] preserve
eqcheck CS50d-source-is-header [pcall xschem raw casemode -source] header
eqcheck CS50e-all [pcall xschem raw casemode -all] "preserve header"

# THE KEY ANYWHERE IN THE HEADER, both positions. hdr_option_early.raw puts the
# same line BEFORE Plotname (ngspice itself calls that misplaced but still loads
# the plot); a COPY carries it after `No. Points:` -- RESPONSE.md sections 1(b)
# and 2. A line-5 check would miss the second and is exactly what upstream told
# us not to write.
oprawf $tmp/h_early.raw \
  "$utitle\n$udate\n$ucmd\nOption: casemode=preserve\nPlotname: Operating Point\nFlags: real" $uvars
xschem raw clear
xschem raw read $tmp/h_early.raw op
eqcheck CS51-key-before-plotname [pcall xschem raw casemode -header] preserve
wr $tmp/h_copy.raw "$utitle
$udate
$ucmd
Plotname: Operating Point
Flags: real
No. Variables: 2
No. Points: 1
Option: casemode=preserve
Variables:
\t0\tv(In)\tvoltage
\t1\tv(MidNode)\tvoltage
Values:
 0\t3.0
\t1.0

"
xschem raw clear
eqcheck CS51b-read-copy-position [pcall xschem raw read $tmp/h_copy.raw op] 1
eqcheck CS51c-key-after-no-points [pcall xschem raw casemode -header] preserve

# hdr_newkey.raw -- a `Casemode:` key. REFUSED, and not out of caution: ngspice's
# own reader ABORTS THE LOAD on it ("Error: strange line in rawfile", measured on
# 46 and on ver_50, upstream FINDINGS section 1), so nothing can be writing it.
oprawf $tmp/h_newkey.raw \
  "$utitle\n$udate\n$ucmd\nCasemode: preserve\nPlotname: Operating Point\nFlags: real" $uvars
xschem raw clear
eqcheck CS52-read-newkey [pcall xschem raw read $tmp/h_newkey.raw op] 1
eqcheck CS52b-newkey-refused [pcall xschem raw casemode -header] unknown
# hdr_cmdset.raw -- casemode nested in a Command: line. `Command:` is free-text
# provenance and is never parsed (that is also why item 1 could not identify a
# Xyce raw). hdr_cmd.raw proves a header may carry a key TWICE.
oprawf $tmp/h_cmdset.raw \
  "$utitle\n$udate\n$ucmd\nPlotname: Operating Point\nCommand: set casemode=preserve\nFlags: real" $uvars
xschem raw clear
xschem raw read $tmp/h_cmdset.raw op
eqcheck CS52c-command-line-refused [pcall xschem raw casemode -header] unknown
oprawf $tmp/h_cmd.raw \
  "$utitle\n$udate\n$ucmd\nPlotname: Operating Point\nCommand: echo COMMAND-LINE-EXECUTED\nFlags: real" $uvars
xschem raw clear
eqcheck CS52d-second-command-line-reads [pcall xschem raw read $tmp/h_cmd.raw op] 1
eqcheck CS52e-second-command-line-silent [pcall xschem raw casemode -header] unknown

# THE INJECTION. `Title:` is the deck's own first line and it is whatever the
# user or the netlister wrote. A deck titled `* casemode=distinguish` must not
# set the mode, and a deck titled `Option: casemode=distinguish` must not either
# -- it arrives as `Title: Option: ...`, which the start-of-line anchor refuses.
oprawf $tmp/h_title1.raw \
  "Title: * casemode=distinguish\n$udate\n$ucmd\nPlotname: Operating Point\nFlags: real" $uvars
xschem raw clear
xschem raw read $tmp/h_title1.raw op
eqcheck CS53-title-casemode-ignored [pcall xschem raw casemode -header] unknown
oprawf $tmp/h_title2.raw \
  "Title: Option: casemode=distinguish\n$udate\n$ucmd\nPlotname: Operating Point\nFlags: real" $uvars
xschem raw clear
xschem raw read $tmp/h_title2.raw op
eqcheck CS53b-title-option-line-ignored [pcall xschem raw casemode -header] unknown
# and the other user-controlled text in a header: a VARIABLE NAME. Variable rows
# are tab-indented, so the anchor refuses them too -- and the name still reads
# back verbatim, so the refusal is not a parse failure.
oprawf $tmp/h_varname.raw \
  "$utitle\n$udate\n$ucmd\nPlotname: Operating Point\nFlags: real" \
  {{Option: casemode=distinguish} v(midnode)}
xschem raw clear
xschem raw read $tmp/h_varname.raw op
eqcheck CS53c-variable-named-like-option [pcall xschem raw casemode -header] unknown
# (the `:` comes back as `.`: read_dataset() rewrites every colon in a variable
# name to a dot, the Xyce hierarchy-separator rule, which is itself evidence
# that this line went down the ordinary VARIABLE path and not the header one)
eqcheck CS53d-that-variable-still-stored [pcall xschem raw list] \
  "Option. casemode=distinguish\nv(midnode)"

# THE KEY IS EXACT. Measured 2026-08-16 on build-ver_50: `-D CaseMode=preserve`
# and `-D CASEMODE=preserve` both leave $curcasemode at `fold`, silently --
# ngspice variable names are case-SENSITIVE, so those record another variable.
foreach {id spelling} {CS54-key-CASEMODE CASEMODE CS54b-key-CaseMode CaseMode} {
  oprawf $tmp/h_key.raw \
    "$utitle\n$udate\n$ucmd\nPlotname: Operating Point\nOption: $spelling=preserve\nFlags: real" $uvars
  xschem raw clear
  xschem raw read $tmp/h_key.raw op
  eqcheck $id-refused [pcall xschem raw casemode -header] unknown
}
# THE VALUE IS NOT. Measured on the same build: `-D casemode=PRESERVE` and
# `-D casemode=Preserve` both give $curcasemode == preserve.
foreach {id spelling} {CS55-value-PRESERVE PRESERVE CS55b-value-Preserve Preserve} {
  oprawf $tmp/h_val.raw \
    "$utitle\n$udate\n$ucmd\nPlotname: Operating Point\nOption: casemode=$spelling\nFlags: real" $uvars
  xschem raw clear
  xschem raw read $tmp/h_val.raw op
  eqcheck $id-accepted [pcall xschem raw casemode -header] preserve
}
# the trim upstream tells us to keep: a foreign Option: value is re-emitted with
# spaces around the `=`
oprawf $tmp/h_spaces.raw \
  "$utitle\n$udate\n$ucmd\nPlotname: Operating Point\nOption:   casemode = distinguish  \nFlags: real" $uvars
xschem raw clear
xschem raw read $tmp/h_spaces.raw op
eqcheck CS56-trim-both-halves [pcall xschem raw casemode -header] distinguish
# other Option: keys are not ours (hdr_ngb.raw / hdr_numdgt.raw)
foreach {id line} {CS56b-option-ngbehavior {Option: ngbehavior = hs}
                   CS56c-option-numdgt {Option: numdgt = 12}} {
  oprawf $tmp/h_other.raw \
    "$utitle\n$udate\n$ucmd\nPlotname: Operating Point\n$line\nFlags: real" $uvars
  xschem raw clear
  xschem raw read $tmp/h_other.raw op
  eqcheck $id [pcall xschem raw casemode -header] unknown
}
# an unknown VALUE is unknown, never a guess
oprawf $tmp/h_bogus.raw \
  "$utitle\n$udate\n$ucmd\nPlotname: Operating Point\nOption: casemode=bogus\nFlags: real" $uvars
xschem raw clear
xschem raw read $tmp/h_bogus.raw op
eqcheck CS57-bogus-value-unknown [pcall xschem raw casemode -header] unknown
# two casemode lines that disagree: the FIRST wins, so an appended line cannot
# overrule the writer
oprawf $tmp/h_two.raw \
  "$utitle\n$udate\n$ucmd\nPlotname: Operating Point\nOption: casemode=fold\nFlags: real\nOption: casemode=distinguish" \
  $uvars
xschem raw clear
xschem raw read $tmp/h_two.raw op
eqcheck CS57b-first-of-two-wins [pcall xschem raw casemode -header] fold
# ...AND THE LINE BELONGS TO ITS OWN DATASET, not to the file. An earlier
# revision stamped any casemode line anywhere in the header chain, on the
# premise that one raw is one session in one mode. ngspice's own writer
# contradicts it: rawfile.c:204 emits the line only for a plot that is NOT
# `pl_fromfile`, while rawfile.c:222/262 RE-EMIT a from-file plot's own
# `Option: casemode=` out of pl_env -- so `write all.raw <a plot loaded from a
# preserve file> <this session's fold plot>` produces two disagreeing lines in
# one file, and the first-wins rule above then reported the mode of a dataset
# the user did not load. (Item 3 fix round, lens 1.)
wr $tmp/h_twoplot.raw "$utitle
$udate
Plotname: Operating Point
Option: casemode=fold
Flags: real
No. Variables: 2
No. Points: 1
Variables:
\t0\tv(in)\tvoltage
\t1\tv(midnode)\tvoltage
Values:
 0\t1.0
\t2.0

Plotname: Transient Analysis
Option: casemode=preserve
Flags: real
No. Variables: 2
No. Points: 1
Variables:
\t0\ttime\ttime
\t1\tv(In)\tvoltage
Values:
 0\t0.0
\t1.0

"
xschem raw clear
eqcheck CS57c-read-tran-of-two-plots [pcall xschem raw read $tmp/h_twoplot.raw tran] 1
eqcheck CS57d-loaded-dataset-owns-the-line [pcall xschem raw casemode -all] "preserve header"
# and the other way round, so this is attribution and not a "last one wins"
# rewrite of CS57b: load the OP plot out of the same file and its own `fold`
# line is what answers
xschem raw clear
eqcheck CS57e-read-op-of-two-plots [pcall xschem raw read $tmp/h_twoplot.raw op] 1
eqcheck CS57f-other-dataset-owns-its-own [pcall xschem raw casemode -all] "fold header"

# ---------------------------------------------------------------------------
# W. B2b: absence is UNKNOWN, never `fold`
# ---------------------------------------------------------------------------
# The two committed fixtures carry no Option: line -- like every file from every
# released ngspice, and every ver_50 file written without `set casemodewrite`,
# whose default has no scheduled flip because the upstream patch is written and
# NOT SENT (RESPONSE.md section 9). No schematic is loaded here, so sources 3
# and 4 are silent too.
xschem raw clear
xschem raw read $presraw tran
eqcheck CS58-preserve-fixture-no-header [pcall xschem raw casemode -header] unknown
eqcheck CS58b-preserve-fixture-unknown [pcall xschem raw casemode] unknown
eqcheck CS58c-source-none [pcall xschem raw casemode -source] none
xschem raw clear
xschem raw read $foldraw tran
# an all-lowercase file is NOT evidence of fold: that is exactly what a
# lowercase design under `preserve` writes
eqcheck CS58d-fold-fixture-unknown [pcall xschem raw casemode] unknown
# the lookup flag is a different question and still answers it
eqcheck CS58e-lookup-flag-independent [pcall xschem raw case] 0
xschem raw clear
eqcheck CS58f-no-database-errors [errs xschem raw casemode] 1

# ---------------------------------------------------------------------------
# X. source 1: the explicit user setting, and it beats the header
# ---------------------------------------------------------------------------
xschem raw clear
xschem raw read $tmp/h_option.raw op
eqcheck CS59-set-explicit [pcall xschem raw casemode distinguish] 1
eqcheck CS59b-explicit-readback [pcall xschem raw casemode -explicit] distinguish
eqcheck CS59c-explicit-wins-over-header [pcall xschem raw casemode -all] "distinguish explicit"
eqcheck CS59d-header-still-visible [pcall xschem raw casemode -header] preserve
# REPORTING ONLY: recording a mode must not silently make the lookup exact --
# that is `xschem raw case`, and its setter re-reads the file
eqcheck CS59e-lookup-flag-untouched [pcall xschem raw case] 0
eqcheck CS59f-clear-explicit [pcall xschem raw casemode unknown] 1
eqcheck CS59g-back-to-header [pcall xschem raw casemode -all] "preserve header"
eqcheck CS59h-bad-token-errors [errs xschem raw casemode sideways] 1
# `upper` is a VERDICT the schematic comparison can reach, never a setting
eqcheck CS59i-upper-not-settable [errs xschem raw casemode upper] 1
eqcheck CS59j-unknown-option-errors [errs xschem raw casemode -nosuchoption] 1
# an explicit statement is about the DATABASE and survives the `raw case`
# re-read, which destroys and rebuilds the Raw
eqcheck CS59k-set-explicit-again [pcall xschem raw casemode preserve] 1
eqcheck CS59l-reread [pcall xschem raw case distinguish] 1
eqcheck CS59m-explicit-survived-reread [pcall xschem raw casemode -explicit] preserve
eqcheck CS59n-reread-did-set-the-flag [pcall xschem raw case] 1
xschem raw clear

# ---------------------------------------------------------------------------
# Y. source 3: comparison against the names the SCHEMATIC owns
# ---------------------------------------------------------------------------
# Two labelled nets whose spelling carries case, matching the committed
# fixtures' nets (In / MidNode). `en` is deliberately lowercase: a name with no
# capital in it can give no signal and must not be counted.
wr $tmp/div_case.sch {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
C {devices/lab_pin} 200 -100 0 0 {name=l1 lab=In}
C {devices/lab_pin} 200 100 0 0 {name=l2 lab=MidNode}
C {devices/lab_pin} 300 100 0 0 {name=l3 lab=en}}
xschem clear force
xschem load $tmp/div_case.sch
eqcheck CS60-schematic-loaded [pcall xschem get instances] 3
xschem raw clear
xschem raw read $foldraw tran
eqcheck CS60b-folded-against-schematic [pcall xschem raw casemode -all] "fold schematic"
xschem raw clear
xschem raw read $presraw tran
eqcheck CS60c-case-kept-reads-preserve [pcall xschem raw casemode -all] "preserve schematic"
# THE THIRD OUTCOME, and the reason this source replaced the capital sniff: a
# net drawn `MidNode` arriving as `V(MIDNODE)` is neither mode. The sniff calls
# it `preserve` and is wrong; CS63d proves the sniff would.
oprawf $tmp/upper.raw \
  "$utitle\n$udate\n$ucmd\nPlotname: Operating Point\nFlags: real" {V(IN) V(MIDNODE)}
xschem raw clear
xschem raw read $tmp/upper.raw op
eqcheck CS60d-uppercased-is-neither [pcall xschem raw casemode -all] "upper schematic"
# the header outranks the comparison, and BOTH are computable at once, so the
# order is proven rather than assumed
oprawf $tmp/h_over_sch.raw \
  "$utitle\n$udate\n$ucmd\nPlotname: Operating Point\nOption: casemode=preserve\nFlags: real" \
  {v(in) v(midnode)}
xschem raw clear
xschem raw read $tmp/h_over_sch.raw op
eqcheck CS60e-header-outranks-schematic [pcall xschem raw casemode -all] "preserve header"
eqcheck CS60f-comparison-said-fold [pcall xschem raw casemode -schematic] fold

# THE LIMITS B2a RECORDS, implemented and not merely documented.
# (a) one hit is not enough -- "most of them agree", not a single coincidence
oprawf $tmp/one_hit.raw \
  "$utitle\n$udate\n$ucmd\nPlotname: Operating Point\nFlags: real" {v(midnode) v(nosuchnet)}
xschem raw clear
xschem raw read $tmp/one_hit.raw op
eqcheck CS61-single-hit-decides-nothing [pcall xschem raw casemode -schematic] unknown
# (b) a tie decides nothing either
oprawf $tmp/tie.raw \
  "$utitle\n$udate\n$ucmd\nPlotname: Operating Point\nFlags: real" {v(in) V(MIDNODE)}
xschem raw clear
xschem raw read $tmp/tie.raw op
eqcheck CS61b-tie-is-unknown [pcall xschem raw casemode -schematic] unknown
# (c) a strict majority does decide: two folded against one disagreeing spelling
oprawf $tmp/major.raw \
  "$utitle\n$udate\n$ucmd\nPlotname: Operating Point\nFlags: real" {v(in) v(midnode) v(mIdNoDe)}
xschem raw clear
xschem raw read $tmp/major.raw op
eqcheck CS61c-majority-decides [pcall xschem raw casemode -schematic] fold
# (d) a database made only of hierarchy-prefixed and simulator-constructed
# names -- `v(x1.…)`, a Xyce `v(x1:…)` (the reader rewrites the colon to a dot),
# the .dc axis `v(v-sweep)`, every device current -- produces no verdict at all.
# (This one is over-determined: those names also match no schematic net, so it
# stays green when the candidate filter is loosened. CS61h is the check that
# holds the filter down.)
oprawf $tmp/constructed.raw \
  "$utitle\n$udate\n$ucmd\nPlotname: Operating Point\nFlags: real" \
  {v(x1.MidNode) v(x1:In) v(v-sweep) i(Vs) i(V.X1.Vp)}
xschem raw clear
xschem raw read $tmp/constructed.raw op
eqcheck CS61d-constructed-names-never-vote [pcall xschem raw casemode -schematic] unknown
# (d2) and the sharp version of the same limit: a schematic that happens to own
# a net called `V-Sweep`, read against a sweep whose axis ngspice spells
# `v(v-sweep)`. Counting the axis would give a confident `fold` off ONE real net
# plus a name the simulator invented. The dash keeps it out of the candidate
# set, one comparable name is left, and the answer is unknown.
wr $tmp/div_sweep.sch {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
C {devices/lab_pin} 200 -100 0 0 {name=l1 lab=In}
C {devices/lab_pin} 200 100 0 0 {name=l2 lab=V-Sweep}}
xschem raw clear
xschem clear force
xschem load $tmp/div_sweep.sch
oprawf $tmp/sweep_axis.raw \
  "$utitle\n$udate\n$ucmd\nPlotname: Operating Point\nFlags: real" {v(v-sweep) v(in)}
xschem raw read $tmp/sweep_axis.raw op
eqcheck CS61h-sweep-axis-is-not-evidence [pcall xschem raw casemode -schematic] unknown
xschem raw clear
xschem clear force
xschem load $tmp/div_case.sch
# (e) an all-CAPITALS schematic name that came back unchanged is ambiguous --
# `preserve` and `upper` produce the same bytes for `EN` -- so it does not vote,
# and CS61g proves the skip is not over-broad: the FOLDED spelling of the same
# name is still unambiguous evidence and still votes.
wr $tmp/div_caps.sch {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
C {devices/lab_pin} 200 -100 0 0 {name=l1 lab=EN}
C {devices/lab_pin} 200 100 0 0 {name=l2 lab=MidNode}}
xschem raw clear
xschem clear force
xschem load $tmp/div_caps.sch
oprawf $tmp/caps_kept.raw \
  "$utitle\n$udate\n$ucmd\nPlotname: Operating Point\nFlags: real" {v(EN) v(MidNode)}
xschem raw read $tmp/caps_kept.raw op
eqcheck CS61f-all-caps-kept-is-ambiguous [pcall xschem raw casemode -schematic] unknown
oprawf $tmp/caps_folded.raw \
  "$utitle\n$udate\n$ucmd\nPlotname: Operating Point\nFlags: real" {v(en) v(midnode)}
xschem raw clear
xschem raw read $tmp/caps_folded.raw op
eqcheck CS61g-all-caps-folded-still-votes [pcall xschem raw casemode -schematic] fold
# (f) an all-lowercase design gives no signal AT ALL, in either direction
wr $tmp/div_lower.sch {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
C {devices/lab_pin} 200 -100 0 0 {name=l1 lab=in}
C {devices/lab_pin} 200 100 0 0 {name=l2 lab=midnode}}
xschem raw clear
xschem clear force
xschem load $tmp/div_lower.sch
xschem raw read $foldraw tran
eqcheck CS61e-lowercase-design-no-signal [pcall xschem raw casemode -schematic] unknown
# (g) A DESIGN THAT LEGITIMATELY OWNS TWO NETS DIFFERING ONLY IN CASE cannot be
# read at all -- and it is exactly the design a case-capable simulator exists
# for. Resolving the raw's `en` against the schematic's `EN` (the FIRST
# case-insensitive hit) scored a confident `fold` for a file that had PRESERVED
# every name, gave the identical verdict for the folded and the case-kept file,
# and flipped when the two labels were merely REORDERED in the .sch. The lookup
# now prefers the exact spelling and calls the rest ambiguous, so nothing votes.
# Residual limit, in the spec's table: a fold run over such a design is
# genuinely undecidable. (Item 3 fix round, lenses 1 and 2.)
wr $tmp/div_twin.sch {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
C {devices/lab_pin} 200 -100 0 0 {name=l1 lab=EN}
C {devices/lab_pin} 200 -60 0 0 {name=l2 lab=en}
C {devices/lab_pin} 200 -20 0 0 {name=l3 lab=OUT}
C {devices/lab_pin} 200 20 0 0 {name=l4 lab=out}}
# the same four labels with the LOWERCASE one of each pair written first
wr $tmp/div_twin2.sch {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
C {devices/lab_pin} 200 -100 0 0 {name=l1 lab=en}
C {devices/lab_pin} 200 -60 0 0 {name=l2 lab=EN}
C {devices/lab_pin} 200 -20 0 0 {name=l3 lab=out}
C {devices/lab_pin} 200 20 0 0 {name=l4 lab=OUT}}
oprawf $tmp/twin_kept.raw \
  "$utitle\n$udate\n$ucmd\nPlotname: Operating Point\nFlags: real" {v(en) v(out) v(EN) v(OUT)}
oprawf $tmp/twin_fold.raw \
  "$utitle\n$udate\n$ucmd\nPlotname: Operating Point\nFlags: real" {v(en) v(out)}
xschem raw clear
xschem clear force
xschem load $tmp/div_twin.sch
xschem raw read $tmp/twin_kept.raw op
set twin1 [pcall xschem raw casemode -schematic]
eqcheck CS61i-case-twin-kept-is-not-fold [pcall xschem raw casemode -all] "unknown none"
xschem raw clear
xschem raw read $tmp/twin_fold.raw op
eqcheck CS61j-case-twin-folded-is-unknown-too [pcall xschem raw casemode -schematic] unknown
# ...and the verdict does not depend on the ORDER of the two labels in the .sch,
# which is how the defect was found: uppercase-first said `fold`, lowercase-first
# said `unknown`, for one unchanged file
xschem raw clear
xschem clear force
xschem load $tmp/div_twin2.sch
xschem raw read $tmp/twin_kept.raw op
set twin2 [pcall xschem raw casemode -schematic]
check CS61k-label-order-does-not-decide [expr {$twin1 eq $twin2 && $twin1 eq "unknown"}] \
  "(uppercase-first='$twin1' lowercase-first='$twin2', want both 'unknown')"
# the sharp half of the same rule, which exactness alone does NOT cover: a raw
# name that matches NEITHER twin exactly. `V(MIDNODE)` against a design owning
# both `MidNode` and `midnode` would read `upper` off the first spelling and
# `no signal` off the second -- one file, two answers, decided by .sch order. Two
# spellings folding to one key means no spelling may speak for it.
wr $tmp/div_twin3.sch {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
C {devices/lab_pin} 200 -100 0 0 {name=l1 lab=MidNode}
C {devices/lab_pin} 200 -60 0 0 {name=l2 lab=midnode}
C {devices/lab_pin} 200 -20 0 0 {name=l3 lab=OtherNode}
C {devices/lab_pin} 200 20 0 0 {name=l4 lab=othernode}}
oprawf $tmp/twin_upper.raw \
  "$utitle\n$udate\n$ucmd\nPlotname: Operating Point\nFlags: real" {V(MIDNODE) V(OTHERNODE)}
xschem raw clear
xschem clear force
xschem load $tmp/div_twin3.sch
xschem raw read $tmp/twin_upper.raw op
eqcheck CS61o-two-spellings-one-key-is-ambiguous [pcall xschem raw casemode -all] "unknown none"
# (h) NAMES THE SCHEMATIC OWNS INCLUDES A WIRE'S `lab=`, not only an instance's.
# The wire half of the lookup had no committed check at all: deleting the whole
# wire loop left this suite ALL PASS while a design whose nets are wire labels
# silently stopped resolving. (Item 3 fix round, lens 3.)
wr $tmp/div_wire.sch {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 0 0 100 0 {lab=In}
N 0 20 100 20 {lab=MidNode}}
xschem raw clear
xschem clear force
xschem load $tmp/div_wire.sch
# fixture precondition, not feature coverage: no item-3 code sits under it (it
# is the wire-arm twin of CS60, and only a DATA drive can move it)
check CS61l-wire-only-design \
  [expr {[pcall xschem get instances] == 0 && [pcall xschem get wires] == 2}] \
  "(instances=[pcall xschem get instances] wires=[pcall xschem get wires], want 0 and 2)"
xschem raw read $foldraw tran
eqcheck CS61m-wire-labels-fold [pcall xschem raw casemode -all] "fold schematic"
xschem raw clear
xschem raw read $presraw tran
eqcheck CS61n-wire-labels-preserve [pcall xschem raw casemode -all] "preserve schematic"
# (i) and it needs a schematic at all -- the File->Open-raw path may have none
wr $tmp/empty.sch {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
}
xschem raw clear
xschem clear force
xschem load $tmp/empty.sch
xschem raw read $presraw tran
eqcheck CS62-no-schematic-no-answer [pcall xschem raw casemode -all] "unknown none"
# (j) AND IT ONLY SPEAKS FOR ITS OWN SCHEMATIC. `xschem load` does not clear a
# loaded database, so with no gate on raw->schname, opening an unrelated design
# flipped an untouched file from an honest `unknown` to a confident and wrong
# verdict -- evidence manufactured out of two files that have nothing to do with
# each other. (Item 3 fix round, lens 2.)
xschem raw clear
xschem clear force
xschem load $tmp/div_lower.sch
xschem raw read $presraw tran
eqcheck CS62b-honest-unknown-for-its-own-sch [pcall xschem raw casemode -all] "unknown none"
xschem load $tmp/div_case.sch
eqcheck CS62c-the-raw-survived-the-load [pcall xschem raw list] \
  "time\nv(In)\nv(MidNode)\ni(Vs)"
eqcheck CS62d-unrelated-schematic-does-not-vote [pcall xschem raw casemode -all] "unknown none"
# section Z below assumes the evidence-free schematic again
xschem raw clear
xschem clear force
xschem load $tmp/empty.sch

# ---------------------------------------------------------------------------
# Z. source 4: the capital sniff, last resort, off by default
# ---------------------------------------------------------------------------
# ABORT-PROOFED: on a binary whose xschem.tcl does not define the variable at
# all, a bare `$raw_case_sniff` raises a Tcl error that kills the FILE with no
# RESULT line -- under which the whole item reads as "nothing went red".
check CS63-sniff-defaults-off \
  [expr {[info exists raw_case_sniff] && $raw_case_sniff == 0}] \
  "(defined=[info exists raw_case_sniff] value='[expr {[info exists raw_case_sniff] ? $raw_case_sniff : {}}]')"
xschem raw clear
xschem raw read $tmp/upper.raw op
# it WOULD answer -- and the resolver still says unknown, so the gate is real
eqcheck CS63b-sniff-would-say-preserve [pcall xschem raw casemode -sniff] preserve
eqcheck CS63c-but-is-not-consulted [pcall xschem raw casemode -all] "unknown none"
set raw_case_sniff 1
eqcheck CS63d-sniff-consulted-when-on [pcall xschem raw casemode -all] "preserve sniff"
# it NEVER answers `fold`: an all-lowercase file is what a lowercase design
# under `preserve` writes, so "no capitals" carries no information
xschem raw clear
xschem raw read $foldraw tran
eqcheck CS63e-sniff-never-says-fold [pcall xschem raw casemode -sniff] unknown
eqcheck CS63f-still-unknown-with-sniff-on [pcall xschem raw casemode -all] "unknown none"
# IT READS EVERY STORED NAME, not just the first. The realistic tran shape has
# the capital-free `time` in names[0]; restricting the scan to names[0] left
# this suite ALL PASS while the sniff answered `unknown` for the committed
# preserve fixture, because every other sniff check here runs against upper.raw
# whose FIRST name already carries a capital. (Item 3 fix round, lens 3.)
xschem raw clear
xschem raw read $presraw tran
eqcheck CS63i-sniff-reads-past-names0 [pcall xschem raw casemode -sniff] preserve
eqcheck CS63j-sniff-answers-with-time-first [pcall xschem raw casemode -all] "preserve sniff"
# and the schematic comparison OUTRANKS it -- on the uppercased file the sniff
# says `preserve` (wrong) while the comparison says `upper` (right)
xschem clear force
xschem load $tmp/div_case.sch
xschem raw clear
xschem raw read $tmp/upper.raw op
eqcheck CS63g-schematic-outranks-sniff [pcall xschem raw casemode -all] "upper schematic"
eqcheck CS63h-sniff-would-have-been-wrong [pcall xschem raw casemode -sniff] preserve
set raw_case_sniff 0

# ---------------------------------------------------------------------------
# AA. the global REQUESTED-mode floor for the no-profile path
# ---------------------------------------------------------------------------
# Not about this file: it is what we ask a simulator for when no profile names a
# mode, and it is the ONE place `fold` is asserted without evidence -- which is
# legitimate, because it is a request about a run, not a claim about a file.
eqcheck CS64-floor-defaults-fold [pcall xschem raw casemode -floor] fold
xschem raw clear
eqcheck CS64b-floor-with-no-database [pcall xschem raw casemode -floor] fold
set sim_case_mode preserve
eqcheck CS64c-floor-follows-the-global [pcall xschem raw casemode -floor] preserve
set sim_case_mode sideways
eqcheck CS64d-garbage-floors-to-fold [pcall xschem raw casemode -floor] fold
set sim_case_mode unknown
eqcheck CS64e-unknown-floors-to-fold [pcall xschem raw casemode -floor] fold
# THE B2b GUARD: the floor must not leak into the resolution of a file. With the
# global set as loudly as it can be, an evidence-free database is still unknown.
set sim_case_mode distinguish
xschem clear force
xschem load $tmp/empty.sch
xschem raw read $presraw tran
eqcheck CS64f-floor-never-answers-for-a-file [pcall xschem raw casemode -all] "unknown none"
set sim_case_mode fold

xschem raw clear
catch {test_scratch_drop $tmp}
puts "----"
puts "test_raw_case_mode: $npass passed, $fail failed"
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
