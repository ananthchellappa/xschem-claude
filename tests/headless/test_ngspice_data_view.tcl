# test_ngspice_data_view.tcl — ONE LOOKUP AUTHORITY, and `ngspice::ngspice_data`
# as a lazy view over it.
#
# Casemode batch **item 5b**. Decision: `doc/claude/casemode_batch/DECISIONS.md`
# **D3** (which supersedes `DESIGN_REVISION.md` section 6 and `PLAN.md` section
# 5.7). Spec: `doc/claude/specs/raw_case_mode.md` **section 13**.
#
# WHAT CHANGED. Backannotation had a SECOND copy of get_raw_index()'s ladder --
# its own `string tolower`, its own hand-rolled `v(...)` rung -- written in Tcl,
# in another file (`ngspice::get_voltage` / `get_current` / `get_diff_voltage` /
# `get_node`, src/xschem.tcl). Every case rule this batch decided would have
# applied to one authority and not the other, forever. Those rungs are DELETED,
# not ported, and what replaces them is nothing at all: the array is a
# read-traced lazy view whose trace calls get_raw_index_in(), so a plain indexed
# read IS the authority call.
#
# THE LOAD-BEARING CHECKS, and why each one cannot pass on the old code:
#   CS96*   PROPERTY 2, the whole item in one shape. Under `distinguish` the
#           EXACT mixed-case query must resolve and the FOLDED one must not.
#           The old procs folded first, so BOTH answered `?`. Nothing else in
#           the suite separates "the fold was deleted" from "the fold happens to
#           be harmless on this fixture".
#   CS100*  PROPERTY 3, and the only oracle that tells a LAZY VIEW from an EAGER
#           COPY: rename a variable in the database AFTER the publisher ran. A
#           frozen copy still answers under the old name; a view follows.
#   CS103*  the array is PINNED TO THE PUBLISHER, not to xctx->raw. A second
#           database becoming current must not change a single answer.
#   CS105*  THE THIRD PUBLISHER, `ngspice::read_raw_dataset` -- pure Tcl,
#           reaching the same array through an `upvar` alias and opening with
#           `unset -nocomplain`. Measured before any of this was written: that
#           unset DESTROYS the C trace, so the two publishers cannot interleave.
#   CS107*/CS108*  MANDATORY SCOPE, passed on five times: `xschem raw casemode`
#           on a VCD and on a `table_read` database. Both were hand-driven only
#           and had no committed check.
#
# Run TRUE HEADLESS from the repo root (needs no display):
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ngspice_data_view.tcl

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
  # one argument is a SCRIPT, several are a command and its words. Without the
  # first branch `pcall {a; b}` evaluates the braced string as a command NAME.
  if {[llength $args] == 1} { set args [lindex $args 0] }
  if {[catch {uplevel 1 $args} r]} { return "ERR:$r" }
  return $r
}
# read one element of the backannotation array the way a user script does.
# `<unset>` covers both "no database has published" (the array does not exist)
# and "the ladder cannot resolve this name" (no such element) -- deliberately
# the same answer, because they are the same answer to the caller.
proc arr_get {n} {
  if {[catch {set ::ngspice::ngspice_data($n)} r]} { return {<unset>} }
  return $r
}
proc arr_names {} { return [lsort [array names ::ngspice::ngspice_data]] }
# resident set size in kB, or 0 where /proc is not there (no check may FAIL for
# that reason: CS111f is written to pass on a 0 reading rather than to skip, and a
# skip word in this file would make full_audit.sh discard every check in it)
proc rss_kb {} {
  if {[catch {open /proc/self/status r} fd]} { return 0 }
  set d [read $fd]; close $fd
  if {[regexp {VmRSS:\s+(\d+)} $d -> k]} { return $k }
  return 0
}
# a number, or the literal we were given: arithmetic on an ERR: string or on {}
# raises a Tcl error that ABORTS THE FILE with no RESULT line, under which every
# later check goes unmeasured and a sabotage reads as "nothing went red".
# (test_backannotate_digital learned this at item 2; same hardening.)
proc num {v {dflt -9999.0}} {
  if {[string is double -strict $v]} { return $v }
  return $dflt
}
proc nearcheck {name got want tol} {
  set g [num $got]
  check $name [expr {[string is double -strict $got] && abs($g - $want) < $tol}] \
    "(got '$got' want ~$want)"
}

set here [file normalize [file dirname [info script]]]
set fixdir [file normalize [file join $here .. .. doc claude casemode_batch fixtures]]
set presraw [file join $fixdir tr_preserve.raw]
set foldraw [file join $fixdir tr_fold.raw]
# ⚠ THE FIXTURES MOVED FROM TRANSIENT TO OPERATING POINT AT THE `annotate` MERGE
# (issue 1240), AND THE SUBJECT DID NOT. Every row here arms the lazy view
# through `xschem update_op`, and update_op() REFUSES a non-op database: the user
# ruled on 2026-08-26 that annotating from a transient must do nothing silently,
# and the array update_op arms is also what `ngspice::get_voltage` reads onto the
# schematic -- so arming it for a transient puts t=0 there wearing the label
# "operating point".
#
# `op_preserve.raw` / `op_fold.raw` carry the SAME four variable names in the
# SAME two spellings as the transient pair, one point, `Plotname: Operating
# Point`. What this suite is about -- the resolution ladder, enumeration, the
# trace, arming across a context switch -- is about NAME SPELLING and is
# identical in every analysis, so nothing here is weakened; the rows now
# exercise the publisher on the analysis kind it actually serves.
set oppres [file join $fixdir op_preserve.raw]
set opfold [file join $fixdir op_fold.raw]

# A missing fixture must FAIL, never skip: full_audit.sh scores a whole file
# SKIP on that substring, and "the fixtures went away" is a finding.
check CS96-fixtures-present [expr {[file exists $presraw] && [file exists $foldraw]}] \
  "($presraw / $foldraw)"
if {$fail} {
  puts "RESULT: $fail FAILED (0 passed)"
  flush stdout
  exit 1
}

set tmp [test_scratch ngdataview]
proc wr {path body} {
  file mkdir [file dirname $path]
  set fp [open $path w]
  puts -nonewline $fp $body
  close $fp
}

# ===========================================================================
# A. PROPERTY 2 -- the query carries the SCHEMATIC'S OWN SPELLING
# ===========================================================================
# tr_preserve.raw stores time / v(In) / v(MidNode) / i(Vs). Read it under
# `distinguish`, which suppresses the ladder's folded rung: the exact spelling
# is then the ONLY one that can resolve.
xschem raw clear
eqcheck CS96b-read-preserve-distinguish \
  [pcall xschem raw read $oppres op -case distinguish] 1
eqcheck CS96c-case-flag-took [pcall xschem raw case] 1
eqcheck CS96d-update_op [pcall xschem update_op] 1

# THE HEADLINE. Both halves in one assertion on purpose: "the exact spelling
# resolves" alone would pass on any build where the fold happened to be a no-op,
# and "the folded spelling misses" alone passes on a build where NOTHING
# resolves. Together they can only be true if the query reached the ladder with
# its capitals intact. On the pre-item-5b procs both halves read `?`.
set cs97_exact [ngspice::get_voltage MidNode]
set cs97_fold  [ngspice::get_voltage midnode]
check CS97-distinguish-exact-hits-folded-misses \
  [expr {[string is double -strict $cs97_exact] && $cs97_fold eq {?}}] \
  "(MidNode='$cs97_exact' midnode='$cs97_fold')"
# the current arm of the same rule -- get_current builds `i(Vs)` from the
# device name, and its `[ve]` voltage-source test had to become case-blind or
# a device called `Vs` would have built `i(@V.Vs)`, a name nothing writes
set cs97_ci [ngspice::get_current Vs]
set cs97_cf [ngspice::get_current vs]
check CS97b-current-distinguish-exact-hits-folded-misses \
  [expr {[string is double -strict $cs97_ci] && $cs97_cf eq {?}}] \
  "(Vs='$cs97_ci' vs='$cs97_cf')"
# get_node is the FOURTH proc. D3 names three; this is the one the shipped
# ngspice_get_value.sym / device_param_probe.sym symbols actually call.
set cs97_ne [ngspice::get_node {v(MidNode)}]
set cs97_nf [ngspice::get_node {v(midnode)}]
check CS97c-get_node-distinguish-exact-hits-folded-misses \
  [expr {[string is double -strict $cs97_ne] && $cs97_nf eq {?}}] \
  "(v(MidNode)='$cs97_ne' v(midnode)='$cs97_nf')"

# ...and under the DEFAULT mode the folded rung rescues the wrong-case query, so
# nothing a user has today stops working. Same fixture, same capitals stored.
xschem raw clear
xschem raw read $oppres op
xschem update_op
set cs98_e [ngspice::get_voltage MidNode]
set cs98_f [ngspice::get_voltage midnode]
check CS98-fold-mode-resolves-either-spelling \
  [expr {[string is double -strict $cs98_e] && $cs98_e eq $cs98_f}] \
  "(MidNode='$cs98_e' midnode='$cs98_f')"
eqcheck CS98b-a-name-that-is-in-no-database-reads-? [ngspice::get_voltage nosuchnet] {?}
# rung 3 of the ladder -- the `v()` wrap -- is what the deleted hand-rolled rung
# in get_voltage/get_diff_voltage was a copy of. A BARE net name must still
# resolve, or the deletion lost something.
check CS98c-bare-name-still-resolves-through-rung-3 \
  [expr {[string is double -strict $cs98_e]}] "(MidNode='$cs98_e')"

# AGREEMENT WITH THE AUTHORITY ITSELF: for each token, the proc resolves exactly
# when `xschem raw index` does. This is the check that fails if anyone ever
# reintroduces a private rung on either side -- in either direction.
set cs99_bad {}
foreach t {MidNode midnode MIDNODE v(MidNode) v(midnode) In in i(Vs) i(vs) time
           nosuchnet v(nosuchnet) {i(v.x1.vp)} {}} {
  if {$t eq {}} continue
  set viaproc [expr {[ngspice::get_voltage $t] ne {?}}]
  set viaauth [expr {[num [pcall xschem raw index $t] -1] >= 0}]
  if {$viaproc != $viaauth} { lappend cs99_bad "$t proc=$viaproc auth=$viaauth" }
}
eqcheck CS99-proc-and-raw-index-agree-on-every-token $cs99_bad {}

# get_diff_voltage: the two dead rungs were deleted AND the proc was fixed.
# It assigned `res` only in its failure branch, so on the SUCCESS path it read
# an unset variable and raised `can't read "res"` -- it could never return a
# difference. Nothing in the tree called it; the shipped @spice_get_diff_voltage
# floater is token.c's own C implementation.
# ITS OWN FIXTURE, with two DIFFERENT non-zero voltages. tr_preserve.raw's
# point 0 is t = 0, where every node reads 0.0 -- and 0 - 0 == 0, so a proc that
# returned the first operand instead of the difference passed. Measured: that
# mutation left this file 93/93 green until the fixture changed.
wr $tmp/diff.raw "Title: two different voltages
Date: Sat Aug 16 00:00:00 2026
Plotname: Operating Point
Flags: real
No. Variables: 3
No. Points: 1
Variables:
\t0\tv(sweep)\tvoltage
\t1\tv(Aa)\tvoltage
\t2\tv(Bb)\tvoltage
Values:
0\t0.0
\t3.0
\t1.25

"
xschem raw clear
eqcheck CS99b0-diff-fixture-reads [pcall xschem raw read $tmp/diff.raw op] 1
eqcheck CS99b1-and-publishes [pcall xschem update_op] 1
# through pcall, and that is NOT cosmetic: on the pre-item-5b proc this call
# RAISES, and an uncaught raise here aborts the whole file with no RESULT line --
# under which every later check goes unmeasured and the master red-before-green
# drive reads as "nothing went red". Measured: the pristine binary stopped the
# file dead at this line.
set cs99b_d [pcall ngspice::get_diff_voltage Aa Bb]
nearcheck CS99b-get_diff_voltage-returns-the-difference $cs99b_d 1.75 1e-4
# ...and it is a SIGNED difference, not the first operand and not the magnitude
nearcheck CS99b2-and-the-other-way-round \
  [pcall ngspice::get_diff_voltage Bb Aa] -1.75 1e-4
# the schematic's own spelling reaches the ladder on BOTH operands
nearcheck CS99b3-both-operands-go-through-the-authority \
  [pcall ngspice::get_diff_voltage aa bb] 1.75 1e-4
eqcheck CS99c-get_diff_voltage-one-bad-node-reads-? \
  [pcall ngspice::get_diff_voltage Aa nosuchnet] {?}
eqcheck CS99d-get_diff_voltage-other-bad-node-reads-? \
  [pcall ngspice::get_diff_voltage nosuchnet Bb] {?}
xschem raw clear
xschem raw read $oppres op
xschem update_op

# ===========================================================================
# B. PROPERTY 3 -- LAZY VIEW, not eager copy
# ===========================================================================
# THE ORACLE. Everything else about a lazy view can be faked by an eager copy
# that happens to hold the right keys. This cannot: change the DATABASE after
# the publisher has run and see whether the array follows. An eager copy was
# taken at publish time and still answers under the old name.
xschem raw clear
xschem raw read $oppres op
xschem update_op
set cs100_before [arr_get {v(MidNode)}]
eqcheck CS100-premise-the-name-resolves-before-the-rename \
  [expr {[string is double -strict $cs100_before]}] 1
eqcheck CS100b-rename-in-memory [pcall xschem raw rename {v(MidNode)} zz_marker] 1
# `zz_marker` DID NOT EXIST when the publisher ran. An eager copy cannot answer
# for it at all; only a view that asks the database at read time can.
check CS100c-THE-VIEW-FOLLOWS-THE-DATABASE \
  [expr {[string is double -strict [arr_get zz_marker]] &&
         [arr_get zz_marker] eq $cs100_before}] \
  "(zz_marker='[arr_get zz_marker]' was v(MidNode)='$cs100_before')"
# DECLARED, not hidden, and CHECKED BEFORE THE ENUMERATION BELOW because that is
# what clears it: an element already materialised by a read keeps its LAST value
# once its name stops resolving.
#
# CORRECTED IN THE ITEM-5b FIX ROUND. This comment used to say "a read trace does
# not fire for an element that already exists", which a reviewer measured to be
# FALSE on tcl 8.6.14 -- the trace fires on every read (section K below pins it).
# The real reason this check is green is that after the rename the ladder can no
# longer resolve `v(MidNode)` at all, so the trace has nothing to answer with and
# leaves the element exactly as it was. Same observable, different mechanism, and
# the mechanism matters: while the name DOES resolve, the element is re-resolved on
# every read and cannot go stale, so it is not a cache in the normal case.
eqcheck CS100e-a-materialised-element-keeps-its-last-value \
  [arr_get {v(MidNode)}] $cs100_before
# ...and enumeration is REBUILT from names[], not accumulated: it drops every
# materialised key first, so the old spelling is gone from it even though it was
# read before the rename.
eqcheck CS100d-and-enumeration-is-rebuilt-from-the-database \
  [expr {[lsearch -exact [arr_names] zz_marker] >= 0 &&
         [lsearch -exact [arr_names] {v(MidNode)}] < 0}] 1
eqcheck CS100f-and-the-rebuild-dropped-the-stale-element [arr_get {v(MidNode)}] <unset>

# the `info exists` anchor. actions.c:4081 asks `info exists
# ngspice::ngspice_data` as "is an operating point loaded?"; a traced but
# UNDEFINED array answers 0 (measured), so the two bookkeeping entries have to
# stay real elements. D3's "Costs, accepted" names exactly this.
xschem raw clear
xschem raw read $oppres op
catch {array unset ::ngspice::ngspice_data}
eqcheck CS101-array-gone-before-publishing [info exists ::ngspice::ngspice_data] 0
eqcheck CS101b-update_op [pcall xschem update_op] 1
eqcheck CS101c-info-exists-answers-yes [info exists ::ngspice::ngspice_data] 1
eqcheck CS101d-n-vars-is-a-real-element [arr_get "n\\ vars"] [pcall xschem raw vars]
eqcheck CS101e-n-points-is-a-real-element [arr_get "n\\ points"] 1

# ENUMERATION. D3 assumed nothing in the tree enumerates this array; six sites
# in four files do (plus one whole-array upvar), so the trace populates on
# `array names` too. The answer is the database's OWN spellings plus the two
# bookkeeping entries -- the set test_wave_cursor_crossdb's XC54 counts.
set cs102_names [arr_names]
eqcheck CS102-enumeration-is-vars-plus-two \
  [llength $cs102_names] [expr {[num [pcall xschem raw vars] 0] + 2}]
eqcheck CS102b-enumeration-uses-the-stored-spelling \
  [expr {[lsearch -exact $cs102_names {v(MidNode)}] >= 0 &&
         [lsearch -exact $cs102_names {v(midnode)}] < 0}] 1
# ...and an odd-spelled READ first does not pollute it. A lazy read has to
# materialise the element it was asked for, so `v(midnode)` becomes a real key;
# enumeration drops those alias keys before it answers, or the count above would
# depend on which spellings a script happened to read earlier.
eqcheck CS102c-premise-the-alias-read-resolves \
  [expr {[string is double -strict [arr_get {v(midnode)}]]}] 1
eqcheck CS102d-alias-keys-do-not-survive-enumeration [arr_names] $cs102_names

# ===========================================================================
# C. PINNED TO THE PUBLISHER, not to whatever is current
# ===========================================================================
# The eager array froze one database's numbers at publish time. A lazy view that
# resolved against xctx->raw would silently start answering out of another
# database after a `raw switch` -- a different answer to the same question, with
# nothing on screen to say so. get_raw_index_in() takes the Raw* for this.
wr $tmp/other.raw "Title: the other database
Date: Sat Aug 16 00:00:00 2026
Plotname: Operating Point
Flags: real
No. Variables: 2
No. Points: 1
Variables:
\t0\tv(sweep)\tvoltage
\t1\tv(other)\tvoltage
Values:
0\t0.0
\t9.999

"
xschem raw clear
xschem raw read $oppres op
xschem update_op
set cs103_pub [arr_get {v(MidNode)}]
set cs103_ivs [pcall xschem raw value {i(Vs)} 0]
eqcheck CS103-second-database-reads [pcall xschem raw read $tmp/other.raw op] 1
eqcheck CS103b-and-it-is-now-current [pcall xschem raw index {v(other)}] 1
eqcheck CS103c-a-cached-element-still-reads-the-PUBLISHER-s-number \
  [arr_get {v(MidNode)}] $cs103_pub
# ...and so does a name the view has NOT yet materialised, which is the half
# that actually exercises the pin: a cached element would answer the same way
# however the resolver was wired.
check CS103c2-and-so-does-a-name-resolved-AFTER-the-switch \
  [expr {[string is double -strict [arr_get {i(Vs)}]] &&
         abs([num [arr_get {i(Vs)}]] - [num $cs103_ivs]) < 1e-9}] \
  "(i(Vs) via view='[arr_get {i(Vs)}]' via publisher='$cs103_ivs')"
eqcheck CS103d-and-not-the-current-database [arr_get {v(other)}] <unset>

# THE DANGLING POINTER. `xschem raw clear <file>` frees ONE database and leaves
# the registry non-empty -- and that arm of extra_rawfile() does NOT unset the
# array, so the trace is still installed with nd_view.raw pointing at freed
# memory. free_rawfile() calls ngspice_data_forget() for exactly this; without
# it the next read of an unmaterialised name resolves through a dead Raw.
eqcheck CS103e-clear-the-PUBLISHER-and-leave-the-other-loaded \
  [pcall xschem raw clear $oppres op] 1
eqcheck CS103f-the-registry-is-not-empty [pcall xschem raw loaded] 0
# `v(In)` has not been read in this block, so this is a FRESH resolve: a cached
# element would answer out of Tcl without touching the freed Raw at all.
eqcheck CS103g-and-the-view-is-disarmed-not-dangling [arr_get {v(In)}] <unset>
eqcheck CS103h-nor-does-it-fall-through-to-the-survivor [arr_get {v(other)}] <unset>

# ===========================================================================
# D. THE TRACE RESETS -- the five clear sites needed no edit
# ===========================================================================
# MEASURED, and it is what decided the design: unsetting the array DESTROYS the
# trace (tcl 8.6.14; the manual is not explicit). So `array unset` IS the reset,
# and after one nothing resolves lazily until a publisher arms again.
xschem raw clear
xschem raw read $oppres op
xschem update_op
eqcheck CS104-premise-armed [expr {[arr_get {v(In)}] ne {<unset>}}] 1
array unset ::ngspice::ngspice_data
eqcheck CS104b-array-unset-disarms-the-view [arr_get {v(In)}] <unset>
eqcheck CS104c-and-info-exists-answers-no [info exists ::ngspice::ngspice_data] 0
eqcheck CS104d-re-publishing-re-arms-it \
  [expr {[pcall xschem update_op] eq {1} && [arr_get {v(In)}] ne {<unset>}}] 1
# `xschem raw case <mode>` FREES the Raw and re-reads it. free_rawfile() disarms
# a view pinned to that Raw, which is the one place nd_view.raw could dangle.
eqcheck CS104e-a-re-read-frees-the-publisher [pcall xschem raw case distinguish] 1
eqcheck CS104f-and-the-view-is-disarmed [arr_get {v(In)}] <unset>
# RE-ARM before the clear, or this measures an array that was already gone: the
# re-read above unsets it on its way through extra_rawfile(). Measured -- with
# the clear-all arm's `array unset` deleted, an un-re-armed CS104g stayed green.
eqcheck CS104f2-re-arm-so-the-clear-has-something-to-remove \
  [expr {[pcall xschem update_op] eq {1} && [llength [arr_names]] > 2}] 1
xschem raw clear
eqcheck CS104g-raw-clear-leaves-nothing [arr_names] {}

# ===========================================================================
# E. THE THIRD PUBLISHER -- pure Tcl, through an `upvar`, and it wins
# ===========================================================================
# ngspice::read_raw_dataset (src/ngspice_backannotate.tcl) populates the SAME
# array from Tcl: `upvar ::ngspice::ngspice_data arr`, then
# `unset -nocomplain var` and direct indexed writes through the alias. A read
# trace does not see writes and behaves differently again under `unset`, so this
# was measured before the C was written rather than reasoned from the manual.
#
# The measured answer: the unset destroys the trace, so the Tcl publisher
# DISARMS the C view and then owns the array outright. The two cannot interleave
# and no half-C, half-Tcl array can exist. Its keys stay folded -- its own
# `string tolower` at :39 -- and it is NOT the authority and cannot be: it never
# builds a Raw. Recorded in spec section 13 rather than changed.
set cs105_ba [file normalize [file join $here .. .. src ngspice_backannotate.tcl]]
check CS105-the-third-publisher-exists [file exists $cs105_ba] "($cs105_ba)"
if {[file exists $cs105_ba]} {
  catch {source $cs105_ba}
  # read_raw_dataset is driven DIRECTLY, through the same `upvar` alias its own
  # caller uses (ngspice::read_raw:68) -- that alias IS the hazard, and going
  # through read_raw() instead would only add its dataset loop, which on a
  # 229-point tran finds no operating point and ends with the array empty for
  # reasons that have nothing to do with this item.
  proc cs105_tcl_publish {path} {
    upvar ::ngspice::ngspice_data arr    ;# verbatim from ngspice::read_raw
    set fp [open $path r]
    fconfigure $fp -translation binary
    ngspice::read_raw_dataset arr $fp
    close $fp
  }
  # `No. Points: 2` so the parser stops at `Binary:` and skips the binary read;
  # what is under test is who owns the array, not its number crunching.
  wr $tmp/tclpub.raw "Title: the Tcl publisher
Date: Sat Aug 16 00:00:00 2026
Plotname: Operating Point
Flags: real
No. Variables: 2
No. Points: 2
Variables:
\t0\tv(sweep)\tvoltage
\t1\tv(MidNode)\tvoltage
Binary:
"
  xschem raw clear
  xschem raw read $oppres op
  xschem update_op
  eqcheck CS105b-premise-the-C-view-is-armed [expr {[arr_get {i(Vs)}] ne {<unset>}}] 1
  cs105_tcl_publish $tmp/tclpub.raw
  # its keys are ITS OWN, and still folded -- read_raw_dataset:39 has a
  # `string tolower` of its own. Not changed here: it never builds a Raw, so it
  # cannot be the authority, and nothing in the tree calls it. Spec section 13.
  eqcheck CS105c-the-Tcl-publisher-keys-are-its-own-folded-ones \
    [expr {[lsearch -exact [arr_names] {v(midnode)}] >= 0 &&
           [lsearch -exact [arr_names] {v(MidNode)}] < 0}] 1
  # THE HAZARD, CLOSED. If the C trace had survived the `unset -nocomplain`, a
  # name only the C database knows would still resolve and the array would be
  # half one publisher's and half the other's. `i(Vs)` is in tr_preserve.raw and
  # not in the Tcl fixture, so it is exactly that probe.
  eqcheck CS105d-the-C-view-is-disarmed-and-cannot-answer [arr_get {i(Vs)}] <unset>
  eqcheck CS105e-and-the-schematic-overlay-follows-the-Tcl-publisher \
    [ngspice::get_current Vs] {?}
  # ...and the schematic overlay CAN read what the Tcl publisher wrote, under
  # that publisher's own folded spelling: no rung of the C ladder is involved.
  eqcheck CS105f-but-the-Tcl-publisher-s-own-keys-are-readable \
    [ngspice::get_node {v(midnode)}] {}
}

# ===========================================================================
# F. D2 -- two names differing only in case, through the view
# ===========================================================================
# Under `distinguish` a database may legitimately hold both. The folded-key
# publisher collapsed them onto one key and one value was unpublishable; the
# view resolves each exactly, and DECLINES the ambiguous middle spelling rather
# than guessing (DECISIONS.md D2).
wr $tmp/collide.raw "Title: case collision
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
eqcheck CS106-read-collision [pcall xschem raw read $tmp/collide.raw op -case distinguish] 1
eqcheck CS106b-update_op [pcall xschem update_op] 1
nearcheck CS106c-uppercase-reads-its-own-column [arr_get {v(EN)}] 1.111 1e-4
# THE EXACT STRING, not just the number: update_op() printed "%.4g" and a script
# reading this array must see byte-for-byte what it saw before item 5b. The view
# is armed with that same 4, so a wrong precision reddens here and nowhere else.
eqcheck CS106c2-and-with-update_op-s-own-4-digit-precision [arr_get {v(EN)}] 1.111
nearcheck CS106d-lowercase-reads-its-own-column [arr_get {v(en)}] 2.222 1e-4
eqcheck CS106e-the-ambiguous-spelling-DECLINES [arr_get {v(En)}] <unset>
eqcheck CS106f-both-names-enumerate \
  [expr {[lsearch -exact [arr_names] {v(EN)}] >= 0 &&
         [lsearch -exact [arr_names] {v(en)}] >= 0}] 1
# and the schematic overlay says the same thing in its own vocabulary
nearcheck CS106g-overlay-EN [ngspice::get_voltage EN] 1.111 1e-4
nearcheck CS106h-overlay-en [ngspice::get_voltage en] 2.222 1e-4
eqcheck CS106i-overlay-En-is-? [ngspice::get_voltage En] {?}

# ===========================================================================
# G. MANDATORY SCOPE -- `xschem raw casemode` on a VCD database
# ===========================================================================
# Passed on by items 2, 3, 4 and 5. Both readers were hand-driven only and
# neither had a committed check, so nothing stopped a later change to
# raw_resolve_case_mode() from erroring or answering nonsense on them. Item 5b
# is the last item that touches this code, so it closes here.
#
# The VCD reader stores names VERBATIM (it always did -- Verilog is
# case-sensitive), which is why a mixed-case scope is the right fixture.
wr $tmp/mixed.vcd "\$timescale 1ns \$end
\$scope module top \$end
 \$scope module M \$end
  \$var wire 1 ! Count \$end
  \$var wire 1 & en \$end
 \$upscope \$end
\$upscope \$end
\$enddefinitions \$end
#0
0!
0&
#50
1!
1&
#100
"
xschem raw clear
eqcheck CS107-vcd-reads [pcall xschem raw read $tmp/mixed.vcd vcd] 1
eqcheck CS107b-vcd-stores-names-verbatim [pcall xschem raw list] \
  "time\ntop.M.Count\ntop.M.en"
# B2b: with no schematic to compare against, no header, and the sniff off, the
# answer is UNKNOWN and the source is NONE -- never `fold`.
eqcheck CS107c-vcd-casemode-is-unknown [pcall xschem raw casemode] unknown
eqcheck CS107d-vcd-source-is-none [pcall xschem raw casemode -source] none
eqcheck CS107e-vcd-all-reports-both [pcall xschem raw casemode -all] {unknown none}
eqcheck CS107f-vcd-header-source-is-silent [pcall xschem raw casemode -header] unknown
eqcheck CS107g-vcd-schematic-source-is-silent [pcall xschem raw casemode -schematic] unknown
# the sniff answers whatever `raw_case_sniff` says, because "what WOULD it have
# said?" is a fair question to ask of a source that is off (item 3's rule).
# `Count` carries a capital, so it reads `preserve`.
eqcheck CS107h-vcd-sniff-sees-the-capital [pcall xschem raw casemode -sniff] preserve
# and the explicit source, source 1 of 4, works on a VCD like anywhere else
eqcheck CS107i-vcd-explicit-starts-unset [pcall xschem raw casemode -explicit] unknown
eqcheck CS107j-vcd-explicit-sets [pcall xschem raw casemode distinguish] 1
eqcheck CS107k-vcd-explicit-reports [pcall xschem raw casemode -all] {distinguish explicit}
eqcheck CS107l-vcd-explicit-clears [pcall {xschem raw casemode unknown; xschem raw casemode -all}] \
  {unknown none}
# REPORTING ONLY: `raw casemode` must not touch the LOOKUP flag, on any reader.
eqcheck CS107m-vcd-lookup-flag-untouched \
  [pcall {xschem raw casemode preserve; xschem raw case}] 0

# ===========================================================================
# H. MANDATORY SCOPE -- `xschem raw casemode` on a `table_read` database
# ===========================================================================
# A table file is columns of real numbers with a header row of names -- an
# analog result by another reader. Its names are stored verbatim too.
wr $tmp/mixed_table.txt "time V(EN) V(Out)
0.0 1.0 2.0
1.0 1.5 2.5
2.0 2.0 3.0
"
xschem raw clear
eqcheck CS108-table-reads [pcall xschem raw read $tmp/mixed_table.txt table] 1
eqcheck CS108b-table-stores-names-verbatim [pcall xschem raw list] "time\nV(EN)\nV(Out)"
eqcheck CS108c-table-casemode-is-unknown [pcall xschem raw casemode] unknown
eqcheck CS108d-table-source-is-none [pcall xschem raw casemode -source] none
eqcheck CS108e-table-all-reports-both [pcall xschem raw casemode -all] {unknown none}
eqcheck CS108f-table-header-source-is-silent [pcall xschem raw casemode -header] unknown
eqcheck CS108g-table-schematic-source-is-silent [pcall xschem raw casemode -schematic] unknown
eqcheck CS108h-table-sniff-sees-the-capitals [pcall xschem raw casemode -sniff] preserve
eqcheck CS108i-table-explicit-sets [pcall xschem raw casemode fold] 1
eqcheck CS108j-table-explicit-reports [pcall xschem raw casemode -all] {fold explicit}
eqcheck CS108k-table-lookup-flag-untouched [pcall xschem raw case] 0
# ...and the lookup itself is case-blind on a table database, which is the thing
# the mode question was always REALLY about
eqcheck CS108l-table-exact-query-resolves [pcall xschem raw index {V(EN)}] 1
eqcheck CS108m-table-folded-query-resolves [pcall xschem raw index {v(en)}] 1
eqcheck CS108n-table-under-distinguish-only-the-exact-one \
  [pcall {xschem raw case distinguish; list [xschem raw index {V(EN)}] [xschem raw index {v(en)}]}] \
  {1 -1}

# ===========================================================================
# I. A DIGITAL DATABASE STILL PUBLISHES NOTHING (RULING D5-3, unchanged)
# ===========================================================================
# The refusal path unsets the array and does not arm, so the view cannot answer
# either -- "no analog database is current" must not become "the lazy view
# quietly resolved it anyway".
xschem raw clear
xschem raw read $tmp/mixed.vcd vcd
eqcheck CS109-premise-the-current-database-is-digital [pcall xschem raw is_digital] 1
eqcheck CS109b-update_op-refuses [pcall xschem update_op] 0
eqcheck CS109c-and-the-array-is-empty [arr_names] {}
eqcheck CS109d-and-nothing-resolves-lazily [arr_get top.M.Count] <unset>
eqcheck CS109e-and-the-overlay-says-? [ngspice::get_voltage top.M.Count] {?}

# ===========================================================================
# J. A TCL CONTEXT SWITCH MUST NOT DESTROY THE VIEW  (item 5b FIX ROUND)
# ===========================================================================
# THE DEFECT THIS SECTION EXISTS FOR. `ngspice::ngspice_data` was a member of
# `tctx::global_array_list` (src/xschem.tcl), the list of global arrays a tab or
# window switch snapshots and restores. restore_ctx's arm over that list opens
# with `unset -nocomplain <arr>` -- and an unset DESTROYS every trace on the
# variable, the same measured fact CS104b pins and the whole design rests on. So
# one Ctrl-T replaced the lazy view with a frozen eager copy keyed only by the
# database's stored spellings, and because item 5b DELETED the Tcl-side fold and
# `v(...)` rungs, the schematic operating-point overlay then read `?` for every
# node, lowercase ones included. Measured before the fix, on the real road
# (`xschem new_schematic create` + `switch`) and here.
#
# The array is no longer in that list. These checks drive the SHIPPED save_ctx /
# restore_ctx over the REAL list, so they fail again if it is put back.
# `tctx::global_list` (the scalars) is emptied around the pair for the duration:
# restoring the GUI scalars runs variable traces that call `winfo`, which does not
# exist under --nogui and aborts the file. The array arm -- the one under test --
# is untouched by that.
xschem raw clear
xschem raw read $oppres op -case preserve
eqcheck CS110-premise-published [pcall xschem update_op] 1
eqcheck CS110b-and-the-overlay-reads-a-number \
  [expr {[string is double -strict [ngspice::get_voltage MidNode]]}] 1
eqcheck CS110c-the-array-is-NOT-per-window-tcl-state \
  [lsearch -exact $tctx::global_array_list ngspice::ngspice_data] -1
set ::dircolor(cs110_marker) keepme
set ::has_x 1
set cs110_gl $tctx::global_list
set tctx::global_list {}
pcall save_ctx .drw
set ::dircolor(cs110_marker) clobbered
pcall restore_ctx .drw
set tctx::global_list $cs110_gl
unset ::has_x
# THE BLOCKER, in one line.
eqcheck CS110d-THE-OVERLAY-STILL-READS-A-NUMBER-AFTER-A-CONTEXT-SWITCH \
  [expr {[string is double -strict [ngspice::get_voltage MidNode]]}] 1
# both halves stated, because "they are equal" is satisfied by two `?`s
check CS110e-and-so-does-the-folded-spelling \
  [expr {[string is double -strict [ngspice::get_voltage midnode]] &&
         [ngspice::get_voltage midnode] eq [ngspice::get_voltage MidNode]}] \
  "(midnode='[ngspice::get_voltage midnode]' MidNode='[ngspice::get_voltage MidNode]')"
# ...and it is still a LAZY VIEW, not the frozen copy the restore used to leave:
# `zz_after_ctx` did not exist when the publisher ran, so only a live view answers.
eqcheck CS110f-and-it-is-still-a-view-not-a-frozen-copy \
  [pcall xschem raw rename {v(In)} zz_after_ctx] 1
check CS110g-the-renamed-name-resolves-through-the-restored-view \
  [expr {[string is double -strict [arr_get zz_after_ctx]]}] \
  "(zz_after_ctx='[arr_get zz_after_ctx]')"
# the COUNT alone cannot tell a live rebuild from the frozen copy the restore used
# to leave (both are vars + 2), so the renamed name has to be IN it
eqcheck CS110h-and-enumeration-is-still-rebuilt-from-the-database \
  [expr {[llength [arr_names]] == [num [pcall xschem raw vars] 0] + 2 &&
         [lsearch -exact [arr_names] zz_after_ctx] >= 0 &&
         [lsearch -exact [arr_names] {v(In)}] < 0}] 1
# the same arm still saves and restores the arrays that ARE per-window state --
# so this section cannot be satisfied by gutting the loop instead
eqcheck CS110i-the-list-arm-still-restores-its-other-members \
  [expr {[info exists ::dircolor(cs110_marker)] ? $::dircolor(cs110_marker) : {<gone>}}] keepme
unset -nocomplain ::dircolor(cs110_marker)

# ===========================================================================
# K. WHAT A READ TRACE REALLY DOES  (item 5b FIX ROUND -- a corrected premise)
# ===========================================================================
# An earlier revision of this file, of save.c's comment block and of spec section
# 13.6 all stated "a read trace does not fire for an element that already exists".
# THAT IS FALSE on tcl 8.6.14 and a reviewer measured it. The trace fires on every
# read and re-resolves. These checks pin the truth, because two things depend on
# it: the growth fix below, and CS100e's real reason (which is that the ladder can
# no longer resolve the renamed name -- NOT that the trace was skipped).
xschem raw clear
xschem raw read $oppres op -case preserve
eqcheck CS111-premise-published [pcall xschem update_op] 1
set cs111_v [arr_get {v(In)}]
eqcheck CS111b-premise-materialised [string is double -strict $cs111_v] 1
set ::ngspice::ngspice_data(v(In)) CS111_BOGUS
eqcheck CS111c-the-trace-fires-on-an-existing-element-and-re-resolves-it \
  [arr_get {v(In)}] $cs111_v
# ...which is the same fact from the other side: a script's write into the armed
# array is DISCARDED. Declared, not fixed: the eager array accepted it.
eqcheck CS111d-so-a-script-write-into-the-armed-array-is-discarded \
  [expr {[arr_get {v(In)}] eq {CS111_BOGUS}}] 0
# AND THE MATERIALISED-KEY LIST MUST NOT GROW WITH THE READ COUNT. It did: one
# strdup'd key per read, ~40 bytes, on the path every redraw of an annotated
# schematic walks (measured: 200000 repeat reads of ONE element grew RSS by 7808 kB;
# an untraced control array in the same loop grew 0).
#
# THE COUNT IS THE ORACLE, NOT RSS, and that is a deliberate choice: RSS reuses heap
# this suite has already allocated and freed, so the same 20000-read loop that grew
# RSS by 896 kB in a fresh process grew it by 0 here -- an RSS assertion at this
# point in the file passed with the defect in place. `xschem raw view_keys` reports
# the list length exactly. Enumeration (CS111e) does not catch it either: the
# rebuild unsets each duplicate, so the answer stays `vars + 2` however long the
# list got. Both stated, so nobody mistakes either for the pin.
set cs111_n0 [llength [arr_names]]
set cs111_k0 [pcall xschem raw view_keys]
eqcheck CS111e-premise-one-key-per-stored-name-after-an-enumeration \
  $cs111_k0 [pcall xschem raw vars]
for {set i 0} {$i < 20000} {incr i} { set cs111_x [arr_get {v(In)}] }
eqcheck CS111f-20000-REPEAT-READS-RECORD-NO-NEW-KEY \
  [pcall xschem raw view_keys] $cs111_k0
eqcheck CS111g-and-the-enumeration-is-unchanged-too \
  [llength [arr_names]] $cs111_n0
# a name never read before still records exactly one
eqcheck CS111h-premise-a-fresh-spelling-resolves \
  [string is double -strict [arr_get {v(in)}]] 1
# `num` on BOTH sides, not decoration: on a pristine-HEAD binary `xschem raw
# view_keys` does not exist, `pcall` hands back `ERR:Wrong command`, and bare
# arithmetic on that raises a Tcl error that ABORTS THE FILE with no RESULT line --
# under which the whole red-before-green drive reads as "nothing went red".
# Measured: it did exactly that on the first pristine run of this section.
eqcheck CS111i-and-records-exactly-one-key \
  [pcall xschem raw view_keys] [expr {[num $cs111_k0 -1] + 1}]
set cs111_r0 [rss_kb]
for {set i 0} {$i < 20000} {incr i} { set cs111_x [arr_get {v(In)}] }
set cs111_r1 [rss_kb]
# reported, not asserted tightly, for the reason above -- 4000 kB is a floor no
# healthy build approaches and the only thing this arm rules out is a runaway
check CS111j-and-does-not-run-memory-away \
  [expr {$cs111_r0 == 0 || $cs111_r1 - $cs111_r0 < 4000}] \
  "(rss $cs111_r0 -> $cs111_r1 kB over 20000 more repeat reads)"

# ===========================================================================
# L. UNSETTING ONE ELEMENT MUST NOT DISARM THE WHOLE VIEW  (FIX ROUND)
# ===========================================================================
# The trace is installed on the array with name2 == NULL, so TCL_TRACE_UNSETS
# fires for an unset of ONE ELEMENT as well as for the destruction of the array,
# and the handler used to call nd_view_reset() either way. `unset arr(v(In))`
# therefore disarmed the entire lazy view while leaving the two sentinels behind:
# `info exists ngspice::ngspice_data` still said "an operating point is loaded",
# nothing resolved lazily any more, and `array names` stopped being rebuilt from
# names[] and started reporting stale alias keys. Measured.
xschem raw clear
xschem raw read $oppres op -case preserve
eqcheck CS112-premise-published [pcall xschem update_op] 1
eqcheck CS112b-premise-one-element-materialised \
  [string is double -strict [arr_get {v(In)}]] 1
unset -nocomplain ::ngspice::ngspice_data(v(In))
eqcheck CS112c-the-array-survives [info exists ::ngspice::ngspice_data] 1
# a name NEVER READ BEFORE: only a still-armed view can answer it
eqcheck CS112d-THE-VIEW-IS-STILL-ARMED-a-new-name-resolves-lazily \
  [string is double -strict [arr_get {v(MidNode)}]] 1
eqcheck CS112e-and-the-unset-element-resolves-again \
  [string is double -strict [arr_get {v(In)}]] 1
eqcheck CS112f-and-enumeration-is-still-rebuilt-from-the-database \
  [llength [arr_names]] [expr {[num [pcall xschem raw vars] 0] + 2}]
eqcheck CS112g-and-the-overlay-still-reads-a-number \
  [string is double -strict [ngspice::get_voltage MidNode]] 1
# ...while destroying the WHOLE array still disarms it, which is what the five
# clear sites rely on (CS104b/CS104c pin the Tcl half of this)
array unset ::ngspice::ngspice_data
eqcheck CS112h-but-unsetting-the-ARRAY-still-disarms \
  [info exists ::ngspice::ngspice_data] 0

# ===========================================================================
# M. THE THIRD PUBLISHER'S ROAD MUST STILL READ  (item 5b FIX ROUND)
# ===========================================================================
# `ngspice::read_raw_dataset` / `ngspice::read_raw` (src/ngspice_backannotate.tcl)
# publish this array from PURE TCL, through `upvar ::ngspice::ngspice_data arr`,
# under keys folded by their own `string tolower` (`v(midnode)`). They never build a
# `Raw`, so there is no authority on that road to reach -- and section E above pins
# that their `unset -nocomplain` disarms the C view before they write.
#
# THE DEFECT. Deleting the procs' `string tolower` and `v(...)` rungs (the point of
# this item) left that road unable to read ANYTHING: every node, all-lowercase ones
# included, answered `?` where HEAD answered a number. Found in review.
#
# THE FIX is one gated fallback inside `ngspice::lookup`, and CS114i is the gate:
# while `xschem raw view_armed` says a C view owns the array, not one fallback probe
# happens, so every case rule still comes from `get_raw_index_in()` alone.
#
# The file must be BINARY: read_raw_dataset only understands `Binary:` + doubles
# (there is no `Values:` arm), and an ASCII fixture dies at its `binary scan`.
if {[file exists $cs105_ba]} {
  set cs114_f $tmp/tclpub_op.raw
  set cs114_fd [open $cs114_f w]
  fconfigure $cs114_fd -translation binary
  puts -nonewline $cs114_fd "Title: the Tcl publisher, one point\nDate: Sun Aug 17 00:00:00 2026\nPlotname: Operating Point\nFlags: real\nNo. Variables: 3\nNo. Points: 1\nVariables:\n\t0\tv(in)\tvoltage\n\t1\tv(midnode)\tvoltage\n\t2\ti(vs)\tcurrent\nBinary:\n"
  puts -nonewline $cs114_fd [binary format d3 {3.0 2.25 -0.00075}]
  close $cs114_fd
  xschem raw clear
  pcall ngspice::read_raw $cs114_f
  eqcheck CS114-premise-the-tcl-publisher-owns-the-array-with-folded-keys \
    [arr_names] [list i(vs) {n points} {n vars} v(in) v(midnode)]
  eqcheck CS114b-premise-no-C-view-is-armed [pcall xschem raw view_armed] 0
  # THE FIX, in the shape the defect was reported in: the SCHEMATIC's spelling.
  eqcheck CS114c-the-overlay-reads-the-schematic-s-spelling \
    [pcall ngspice::get_voltage MidNode] 2.25
  eqcheck CS114d-and-the-publisher-s-own-spelling [pcall ngspice::get_voltage midnode] 2.25
  eqcheck CS114e-and-a-bare-name-needing-the-v-wrap [pcall ngspice::get_voltage In] 3.0
  eqcheck CS114e2-lowercase-too [pcall ngspice::get_voltage in] 3.0
  eqcheck CS114f-and-a-current [pcall ngspice::get_current Vs] -0.00075
  eqcheck CS114g-and-get_node-the-proc-the-shipped-symbols-call \
    [pcall ngspice::get_node {v(In)}] 3.0
  # a name NO publisher has still declines -- the fallback is a ladder, not a guess
  eqcheck CS114h-a-name-in-no-database-still-reads-? \
    [pcall ngspice::get_voltage nosuchnet_zz] {?}
}
# THE GATE. Back on the C road, under `distinguish`, with BOTH `v(EN)` and `v(en)`
# stored: the ambiguous middle spelling must still DECLINE. If the fallback were
# ungated it would fold `En` to `en` and answer `v(en)`'s value -- precisely what D2
# and CS106i forbid. This is CS106i's subject re-asked with the fallback in the tree.
xschem raw clear
eqcheck CS114i-premise-the-collision-fixture-reads \
  [pcall xschem raw read $tmp/collide.raw op -case distinguish] 1
eqcheck CS114i2-premise-published [pcall xschem update_op] 1
eqcheck CS114i3-premise-a-C-view-IS-armed [pcall xschem raw view_armed] 1
eqcheck CS114j-THE-FALLBACK-IS-GATED-the-ambiguous-spelling-still-declines \
  [pcall ngspice::get_voltage En] {?}
eqcheck CS114j2-while-both-exact-spellings-resolve-to-their-own-column \
  [list [pcall ngspice::get_voltage EN] [pcall ngspice::get_voltage en]] {1.111 2.222}

xschem raw clear
if {$fail} { puts "RESULT: $fail FAILED ($npass passed)" } \
else { puts "RESULT: ALL PASS ($npass checks)" }
flush stdout
exit [expr {$fail ? 1 : 0}]
