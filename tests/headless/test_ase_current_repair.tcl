# POST-LOAD CURRENT REPAIR — casemode batch item 12 (PLAN.md §3b item 12 and
# §D6 part 2; DECISIONS.md D2; spec doc/claude/specs/simulator_profiles.md §16).
#
# WHAT IS BEING REPAIRED. A current expression is CONSTRUCTED. For a device
# inside a subcircuit ase::ui::sod_qualify composes the branch prefix (the
# device's own first character), the instance path and the name, and
# ase::ui::sod_expr maps the case; a voltage instead comes back from
# `xschem resolved_net`, which is the engine's own answer. So a current name is
# only as right as our model of how the simulator builds one, and after the run
# the database itself is the authority. Unmatched current -> looked up
# case-insensitively against the attached databases' own name lists -> rewritten
# to the spelling they carry, DECLINING (D2) when two spellings differ from it
# only in case.
#
# MEASURED 2026-08-18 on this tree, with build-ver_50 and the real engine, and
# it narrows the item much further than PLAN §D6 assumed:
#
#   * item 9's construction model is RIGHT. `.subckt Blk` with `Vs`/`E1` inside
#     `X1`, run three ways, gives exactly what sod_qualify composes:
#        fold        i(v.x1.vs)  i(e.x1.e1)  i(v1)
#        preserve    i(V.X1.Vs)  i(E.X1.E1)  i(V1)
#        distinguish i(V.X1.Vs)  i(E.X1.E1)  i(V1)
#   * so a MIS-CASED current can only miss where item 2's folded rung is
#     SUPPRESSED — on a `case_sensitive` database. Measured through the engine:
#        h_distinguish.raw -case distinguish   raw index i(v.x1.vs) = -1
#        h_preserve.raw    -case preserve      raw index i(v.x1.vs) =  4
#     On any other database "unmatched" and "matchable case-insensitively" are
#     DISJOINT, so the repair is a theorem-quiet no-op there (CU236b).
#   * nothing in ASE-L's attach path passes `-case` (ase::attach_dbs), so a
#     session's own raw is never case_sensitive and the repair is a standing
#     guard on that path — the shape item 11 keeps its own D2 decline in
#     (spec §15.5). It fires today for `xschem raw read -case distinguish` /
#     `xschem raw case 1`, i.e. the scripted and File->Open-raw routes.
#   * §13.6's narrowing ("a constructed current name") is ONE PRODUCER SHORT,
#     the same way it was for item 11: the Add/Edit Output dialog, a
#     hand-written state file and ase::expand_bus_outputs all ship a current
#     expression VERBATIM, and plot_map_expr turns `-i(V1)` into an RPN, so the
#     repair is token-wise and covers all four (CU234b, CU239b).
#
# Legs (CU*):
#   CU231  the CURRENT-only predicate, and why a voltage is out
#   CU232  the repair itself, on a case_sensitive slot
#   CU232b the theorem: a folding slot resolves it, so nothing is repaired
#   CU233  D2 — two case-variant spellings decline; one spelling twice does not
#   CU234  a batch with nothing to fix comes back BYTE-IDENTICAL
#   CU235  the ladder's own rungs, not a paraphrase: the `i(v.x` -> `i(x` rung,
#          and an agreement leg against resolve_signal_db
#   CU236  THE REAL ENGINE, on the committed fixture: the repaired spelling
#          resolves in `xschem raw index` and the original one does not
#   CU237  the same, hierarchical, on build-ver_50 (SKIPPED, never failed)
#   CU238  dp_finish is WIRED: plot_signals gets the repaired queue, qcolors
#          stay aligned
#   CU239  auto_plot is WIRED: add_trace gets the repaired expression
#   CU240  the announcements — repair at `note`, decline at `error`, and a
#          token nothing folds to says nothing HERE
#   CU241  the length contract, and the session that is NOT rewritten
#   CU242  one inventory read per batch, never per expression
#
# True headless (no X, no Tk). Run from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_current_repair.tcl

set fail 0
set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp})"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }
# ABORT-PROOFING (LEDGER carry-forward from items 1, 2, 5b, 6, 7, 8, 11): a proc
# sabotaged away must FAIL a check, never abort the file with no RESULT line —
# under which every sabotage reads as "nothing went red".
proc pcall {args} {
  if {[catch {uplevel 1 $args} r]} { return "ERR:$r" }
  return $r
}

set no_recent_files 1                       ;# issue 0119: keep Open Recent clean
set here [file normalize [file dirname [info script]]]
source [file join $here scratch.tcl]
set scratch [test_scratch ase_current_repair]
set ::USER_CONF_DIR [file join $scratch conf]
file mkdir $::USER_CONF_DIR
set fixtures [file normalize [file join $here .. .. doc claude casemode_batch fixtures]]

# the CIW spy: ase::echo resolves ::ciw_echo BY NAME at call time, and the TAG
# matters as much as the text (item 14's finding: a channel can be correct and
# still reach nobody).
set ::said {}
if {[info commands ::ciw_echo] ne {}} { rename ::ciw_echo ::ciw_echo_orig }
proc ::ciw_echo {line {tag {}}} { lappend ::said [list $tag $line] }
proc said_clear {} { set ::said {} }
proc said_count {pat {tag {}}} {
  set n 0
  foreach e $::said {
    if {$tag ne {} && [lindex $e 0] ne $tag} { continue }
    if {[string match $pat [lindex $e 1]]} { incr n }
  }
  return $n
}

## an inventory slot in signal_list_all's own shape — the two keys
## resolve_signal_db reads (`names`, `case`) plus the labelling it carries
proc slot {names {case 0} {idx 0} {cur 1}} {
  return [dict create idx $idx path /tmp/s$idx.raw type tran cur $cur \
                      label db$idx case $case names $names]
}
## a distinguish database written by a preserve/distinguish run of the deck in
## the header: `.subckt Blk` holding `Vs` and `E1`, instantiated as `X1`
set DIST [slot {time i(E.X1.E1) v(In) v(Out) i(V.X1.Vs) i(V1) v(X1.n1)} 1]
## the SAME run under `fold` — every name lower-cased, and NOT case_sensitive
set FOLD [slot {time i(e.x1.e1) v(in) v(out) i(v.x1.vs) i(v1) v(x1.n1)} 0]

if {[catch {

# ===========================================================================
# CU231 — CURRENTS ONLY. A voltage carries the schematic's own net name back
# from `xschem resolved_net`; there is no construction to be wrong about, and
# the viewer's voltage matching is casemode item 5's ground. Widening the
# predicate is the whole of what a later item would have to do.
# ===========================================================================
check "CU231 i(...) is a current reference" \
  [list [pcall wviewer::is_current_ref {i(V1)}] \
        [pcall wviewer::is_current_ref {I(v.x1.vs)}] \
        [pcall wviewer::is_current_ref {i(@r.x1.rq[i])}]] {1 1 1}
check "CU231b a voltage, a bare net and an operator are NOT" \
  [list [pcall wviewer::is_current_ref {v(In)}] \
        [pcall wviewer::is_current_ref {In}] \
        [pcall wviewer::is_current_ref {-1}] \
        [pcall wviewer::is_current_ref {i()}] \
        [pcall wviewer::is_current_ref {@}] \
        [pcall wviewer::is_current_ref {}]] {0 0 0 0 0 0}
## THE OTHER SHIPPED CURRENT FORM. `.options savecurrents` (ASE-L's `alli` save
## flavour) writes TERMINAL currents as `@m.x1.m0[id]`, and ase::ui::output_kind
## already classifies those as `current` (it matches `i(*` OR `@*`). Two
## predicates in one feature disagreeing about what a current is would repair
## one form and silently skip the other; the `@` name is composed exactly the
## same way — device letter, instance path, name — so it is wrong the same ways.
check {CU231d the savecurrents @dev[term] form is a current too} \
  [list [pcall wviewer::is_current_ref {@m.x1.m0[id]}] \
        [pcall wviewer::is_current_ref {@r.x1.rq[i]}] \
        [pcall wviewer::is_current_ref {@M.X1.M0[id]}]] {1 1 1}
## and the predicate GOVERNS the repair, not just answers about it: a voltage
## that would repair perfectly well if it were a current is left alone
check "CU231c a mis-cased VOLTAGE is left alone on the very slot that repairs a current" \
  [list [pcall wviewer::repair_current_token {v(in)} [list $DIST]] \
        [lindex [pcall wviewer::repair_current_token {i(v1)} [list $DIST]] 0]] \
  {{keep v(in) {}} repaired}

# ===========================================================================
# CU232 — THE REPAIR. A current picked (or typed) in the wrong case against a
# `case_sensitive` database: item 2's folded rung is suppressed there, so the
# ladder declines and the database's own spelling is the only answer.
# ===========================================================================
check "CU232 a folded hierarchical current is repaired to the database's spelling" \
  [pcall wviewer::repair_current_token {i(v.x1.vs)} [list $DIST]] \
  {repaired i(V.X1.Vs) i(V.X1.Vs)}
check "CU232b a NON-v prefix letter repairs the same way (the vsource_pwl E1 class)" \
  [pcall wviewer::repair_current_token {i(e.x1.e1)} [list $DIST]] \
  {repaired i(E.X1.E1) i(E.X1.E1)}
check "CU232c a flat top-level current too" \
  [pcall wviewer::repair_current_token {i(v1)} [list $DIST]] \
  {repaired i(V1) i(V1)}
## THE THEOREM, and it is why this item is a standing guard on the ASE-L run
## path: on a database that is not case_sensitive the ladder ALREADY resolves
## every case-only mismatch, so `unmatched` and `matchable case-insensitively`
## are disjoint and the repair can never fire.
check "CU232d the SAME token on a FOLDING database is kept — the ladder has it" \
  [list [pcall wviewer::repair_current_token {i(V.X1.Vs)} [list $FOLD]] \
        [pcall wviewer::repair_current_token {i(v.x1.vs)} [list $FOLD]]] \
  {{keep i(V.X1.Vs) {}} {keep i(v.x1.vs) {}}}
## a name no database has in ANY casing is `none`, not a repair and not a
## decline — add_trace/plot_signals already report that one per expression
check "CU232e a name nothing folds to is `none`" \
  [pcall wviewer::repair_current_token {i(v.x9.vzz)} [list $DIST]] \
  {none i(v.x9.vzz) {}}
## …and the `@` form is repaired by the SAME pass, not merely recognised by the
## predicate: a savecurrents database stores `@m.X1.M0[id]` and the row asks for
## the folded spelling.
set ATCUR [slot {time @m.X1.M0[id] @r.X1.Rq[i] v(In)} 1]
check "CU232f a mis-cased savecurrents `@` current is repaired too" \
  [list [pcall wviewer::repair_current_token {@m.x1.m0[id]} [list $ATCUR]] \
        [pcall wviewer::repair_current_token {@m.X1.M0[id]} [list $ATCUR]]] \
  [list [list repaired {@m.X1.M0[id]} [list {@m.X1.M0[id]}]] \
        [list keep {@m.X1.M0[id]} {}]]

# ===========================================================================
# CU233 — D2. Two stored spellings differing from the token only in case is a
# GUESS, and a guess written into a trace plots another signal's waveform under
# this one's legend entry. Spellings are counted, not slots.
# ===========================================================================
set COLL [slot {time i(V.X1.Vs) i(v.x1.vs)} 1]
check "CU233 a stale hierarchical current onto TWO case-variant spellings declines" \
  [pcall wviewer::repair_current_token {i(V.x1.Vs)} [list $COLL]] \
  {ambiguous i(V.x1.Vs) {i(V.X1.Vs) i(v.x1.vs)}}
check "CU233b a near miss is not a collision — it is `none`" \
  [pcall wviewer::repair_current_token {i(V1)} [list [slot {i(V1x) i(v1X)} 1]]] \
  {none i(V1) {}}
set COLL2 [slot {time i(VS) i(vs)} 1]
check "CU233c a token that folds onto BOTH stored spellings declines, listing them" \
  [pcall wviewer::repair_current_token {i(Vs)} [list $COLL2]] \
  {ambiguous i(Vs) {i(VS) i(vs)}}
## …and the SAME spelling in two attached databases is ONE answer, not a
## collision (item 11 §15.5's rule: spellings, not occurrences)
check "CU233d one spelling in two databases is not a collision" \
  [pcall wviewer::repair_current_token {i(v1)} \
     [list [slot {time i(V1)} 1 0 1] [slot {time i(V1)} 1 1 0]]] \
  {repaired i(V1) i(V1)}
## and two DIFFERENT spellings, one per database, DO collide
check "CU233e two databases offering two DIFFERENT spellings decline" \
  [pcall wviewer::repair_current_token {i(vs)} \
     [list [slot {time i(VS)} 1 0 1] [slot {time i(Vs)} 1 1 0]]] \
  {ambiguous i(vs) {i(VS) i(Vs)}}
## THE THEOREM'S ONE EXCEPTION, and it is a FOLDING database — spec §16.3 cited
## CU233c for it, but CU233c's slot is `case 1`. This is the real shape: a
## database that is NOT case_sensitive whose folded key is D2-POISONED. The
## ladder declines there (name_lookup answers `ambiguous`, not `ok`), so the
## token reaches the repair — which finds two spellings and declines as well,
## out loud. Without this the only route by which a folding database can reach
## the repair at all has no coverage (a `continue` on `case 0` slots was green).
check "CU233f a poisoned FOLDING slot reaches the repair and still declines" \
  [list [pcall wviewer::name_lookup [pcall wviewer::name_index {time i(VS) i(vs)}] {i(Vs)} 1] \
        [pcall wviewer::repair_current_token {i(Vs)} [list [slot {time i(VS) i(vs)} 0]]]] \
  {ambiguous {ambiguous i(Vs) {i(VS) i(vs)}}}

# ===========================================================================
# CU234 — the expression level. Byte-identity when nothing is repaired, and
# token-wise repair of the RPN plot_map_expr builds for `-i(V1)`.
# ===========================================================================
check "CU234 an untouched expression comes back BYTE-identical, spacing and all" \
  [pcall wviewer::repair_current_expr {  v(in)   i(V.X1.Vs)  } [list $DIST]] \
  [list {  v(in)   i(V.X1.Vs)  } {}]
check "CU234b the `-i(v1)` RPN is repaired token-wise" \
  [lindex [pcall wviewer::repair_current_expr {i(v1) -1 *} [list $DIST]] 0] \
  {i(V1) -1 *}
check "CU234c a batch preserves its LENGTH and repairs only what misses" \
  [lindex [pcall wviewer::repair_current_expr {i(v1) i(V.X1.Vs) v(in)} [list $DIST]] 0] \
  {i(V1) i(V.X1.Vs) v(in)}
## the notes carry every non-keep token, in order, with its candidates
check "CU234d the notes name each token, its status, its answer and its candidates" \
  [lindex [pcall wviewer::repair_current_expr {i(v1) i(zz) i(Vs)} [list $COLL2]] 1] \
  {{none i(v1) i(v1) {}} {none i(zz) i(zz) {}} {ambiguous i(Vs) i(Vs) {i(VS) i(vs)}}}

# ===========================================================================
# CU235 — IT IS NOT A SECOND LADDER. The candidate scan runs over
# wviewer::name_rungs, so the `i(v.x` -> `i(x` rewrite item 2 owns is honoured
# rather than re-implemented: a database that names the branch WITHOUT the
# prefix (the other ngspice convention, spec raw_case_mode.md §9 rung 4) is
# still repaired to its own spelling.
# ===========================================================================
set NOPFX [slot {time i(X1.Vs) v(In)} 1]
check "CU235 the i(v.x rung is honoured: i(v.x1.vs) -> the DB's i(X1.Vs)" \
  [pcall wviewer::repair_current_token {i(v.x1.vs)} [list $NOPFX]] \
  {repaired i(X1.Vs) i(X1.Vs)}
## AGREEMENT: the "does it already resolve" half is resolve_signal_db's own
## verdict, run over the same slots — a divergence here is the thing item 5's
## mirror ruling exists to forbid.
rename wviewer::signal_list_all wviewer::signal_list_all_real
set ::inv {}
set ::ninv 0
## `attached` makes the ORDER observable: before a database is attached there
## is no inventory to repair against, exactly as in the shipped program, so a
## repair hoisted above attach_raw resolves nothing and CU238 goes red.
set ::attached 1
## …and the stub is TOKEN-AWARE, mirroring the real proc's first line
## (`if {![dict exists $windows $token]} { return {} }`). A stub that ignored
## the token could not tell whether the repair asks the RIGHT viewer window for
## its inventory: `signal_list_all {}` in place of `signal_list_all $token` is a
## one-word mutation that makes the feature a permanent no-op in the shipped
## program, and against a token-blind stub every check stayed green.
set ::known_tokens {CURKEY tok}
proc wviewer::signal_list_all {token {statusVar {}}} {
  if {$statusVar ne {}} { upvar 1 $statusVar st ; set st ok }
  incr ::ninv
  if {[lsearch -exact $::known_tokens $token] < 0} { return {} }
  if {!$::attached} { return {} }
  return $::inv
}
set agree 1
set disagree {}
foreach probe {{i(V.X1.Vs)} {i(v.x1.vs)} {i(V1)} {i(v1)} {i(E.X1.E1)} {i(zz)}} {
  foreach ::inv [list [list $DIST] [list $FOLD] [list $COLL2]] {
    set resolves [expr {[pcall wviewer::resolve_signal_db tok $probe] ne {}}]
    set kept [expr {[lindex [pcall wviewer::repair_current_token $probe $::inv] 0] eq {keep}}]
    if {$resolves != $kept} { set agree 0 ; lappend disagree [list $probe $::inv] }
  }
}
check "CU235b `keep` and resolve_signal_db agree on every probe (the mirror)" \
  [list $agree $disagree] {1 {}}

# ===========================================================================
# CU238 — dp_finish IS WIRED. Item 5's lesson: a control nothing drives can be
# green and dead. The queue plot_signals receives must be the REPAIRED one, and
# `qcolors` must still line up with it position for position.
# ===========================================================================
rename wviewer::open wviewer::open_real
rename wviewer::attach_raw wviewer::attach_raw_real
rename wviewer::plot_signals wviewer::plot_signals_real
rename ase::last_rawfile ase::last_rawfile_real
rename ase::last_vcdfiles ase::last_vcdfiles_real
proc wviewer::open {token args} { return 1 }
proc wviewer::attach_raw {token rawfile sim_type {vcdfiles {}}} {
  incr ::nattach ; set ::attached 1 ; return 1
}
proc wviewer::plot_signals {token exprs {colors {}} {destover {}}} {
  set ::got_exprs $exprs ; set ::got_colors $colors ; return {}
}
proc ase::last_rawfile {key} { return $::fake_raw }
proc ase::last_vcdfiles {key} { return {} }
set ::fake_raw [file join $fixtures tr_preserve.raw]
set ::nattach 0
set ::got_exprs {}
set ::got_colors {}
set ::inv [list $DIST]
set ::ninv 0
set ::attached 0            ;# nothing is attached until dp_finish attaches it
said_clear
pcall ase::ui::dp_finish CURKEY {i(v.x1.vs) v(in)} {c1 c2}
check "CU238 dp_finish hands plot_signals the REPAIRED queue" \
  $::got_exprs {i(V.X1.Vs) v(in)}
check "CU238b qcolors are still aligned with it, and the attach happened first" \
  [list $::got_colors $::nattach] {{c1 c2} 1}
## the ORDER is the point of "post-load": with the repair hoisted above
## attach_raw there is no database to repair against and CU238 above goes red
check "CU238c the repair is announced once, at tag `note`, naming both spellings" \
  [list [said_count {*i(v.x1.vs)*i(V.X1.Vs)*} note] [said_count {*} error]] {1 0}
## an EMPTY queue never reaches the repair (dp_finish returns before it) and a
## queue with nothing to fix is passed through untouched
set ::got_exprs {}
said_clear
pcall ase::ui::dp_finish CURKEY {v(in) i(V.X1.Vs)} {c1 c2}
check "CU238d a queue with nothing to repair is passed through and says nothing" \
  [list $::got_exprs [said_count {*spelling*}]] {{v(in) i(V.X1.Vs)} 0}
## THE NO-RUN PATH REPAIRS NOTHING, and "post-load" is why. dp_finish's own
## notice one line above promises the queued trace "resolves after the run" —
## but the viewer window can already hold a FOREIGN raw somebody opened by hand
## (rawbar_load), so a repair that ran here would rewrite the queued current to
## that unrelated database's spelling and pin it there, contradicting the notice
## in the same breath. Nothing attached -> nothing to repair against.
set ::got_exprs {}
set ::got_colors {}
set ::nattach 0
set save_raw $::fake_raw
set ::fake_raw {}           ;# ase::last_rawfile -> {} : no run yet
set ::attached 1            ;# …but a FOREIGN database is open in that window
said_clear
pcall ase::ui::dp_finish CURKEY {i(v.x1.vs)} {c1}
check "CU238e no run yet: nothing attached, so the queue is NOT rewritten" \
  [list $::nattach $::got_exprs [said_count {*spelling*} note]] {0 i(v.x1.vs) 0}
set ::fake_raw $save_raw
set ::attached 0
## …and when the repair DOES run it can collapse two distinct queued spellings
## into one string, which dp_queue's pick-time `lsearch -exact` could not have
## caught. Plotting it twice is two strips (multi-plot) or two same-data traces
## (single-plot) at two DIFFERENT colours, so one of issue 0153's schematic net
## cues could never match its trace. First occurrence and its colour survive.
set ::got_exprs {}
set ::got_colors {}
set ::nattach 0
said_clear
pcall ase::ui::dp_finish CURKEY {i(v.x1.vs) v(in) i(V.x1.Vs)} {c1 c2 c3}
check "CU238f two spellings repaired onto one string collapse, colours in lockstep" \
  [list $::got_exprs $::got_colors] {{i(V.X1.Vs) v(in)} {c1 c2}}
## PURE: a colour list that is not positional (empty — a scripted/replayed call,
## where plot_signals derives them) is handed back untouched rather than
## silently truncated.
check "CU238g a non-positional colour list is left alone by the dedupe" \
  [list [pcall ase::ui::dedupe_plot_queue {a b a c b} {}] \
        [pcall ase::ui::dedupe_plot_queue {a b a} {x y}]] \
  {{{a b c} {}} {{a b} {x y}}}

# ===========================================================================
# CU239 — auto_plot IS WIRED, and it is the seam the OTHER three producers of a
# current expression arrive on: the Add/Edit Output dialog, a hand-written
# state file and ase::expand_bus_outputs all store an expression VERBATIM
# (spec §15.2's whole-file grep), so none of them is "constructed" and all of
# them can be mis-cased.
# ===========================================================================
rename wviewer::ensure_auto_graph wviewer::ensure_auto_graph_real
rename wviewer::clear_graph_traces wviewer::clear_graph_traces_real
rename wviewer::regenerate wviewer::regenerate_real
rename wviewer::add_trace wviewer::add_trace_real
rename ase::session_state ase::session_state_real
proc wviewer::ensure_auto_graph {token} { return 0 }
proc wviewer::clear_graph_traces {token gi} { return }
proc wviewer::regenerate {token args} { return }
proc wviewer::add_trace {token gi rpn {name {}} {color {}} {db {}}} {
  lappend ::added [list $rpn $name] ; return {}
}
proc ase::session_state {key} { return $::fake_state }
set ::fake_state [dict create outputs [list \
   [dict create name {} expr {i(v.x1.vs)} plot 1 save 0] \
   [dict create name isrc expr {-i(v1)} plot 1 save 0] \
   [dict create name {} expr {v(in)} plot 1 save 0]]]
set ::added {}
said_clear
pcall ase::ui::auto_plot CURKEY
check "CU239 auto_plot repairs a typed/state-file current before add_trace" \
  $::added {{i(V.X1.Vs) {}} {{i(V1) -1 *} isrc} {v(in) {}}}
check "CU239b the `-i(v1)` row is repaired in its RPN form, and the name survives" \
  [list [lindex $::added 1] [said_count {*'i(v1)'*'i(V1)'*} note]] {{{i(V1) -1 *} isrc} 1}

# ===========================================================================
# CU240 — the announcements. A repair the user never typed appearing in a
# legend is exactly the surprise item 14's relay ruling is about; a D2 decline
# is item 11's `error` line naming every candidate; a `none` says nothing HERE
# because add_trace/plot_signals already report it per expression.
# ===========================================================================
set ::inv [list $COLL2]
set ::added {}
set ::fake_state [dict create outputs [list \
   [dict create name {} expr {i(Vs)} plot 1 save 0] \
   [dict create name {} expr {i(nosuch)} plot 1 save 0]]]
said_clear
pcall ase::ui::auto_plot CURKEY
check "CU240 a D2 decline is ONE `error` line naming every candidate" \
  [list [said_count {*i(VS)*i(vs)*} error] [said_count {*} note]] {1 0}
check "CU240b a declined expression is handed on UNCHANGED, not dropped" \
  [lindex $::added 0] {i(Vs) {}}
check "CU240c a name nothing folds to is not announced by the repair" \
  [said_count {*i(nosuch)*}] 0
## THE DECLINE DESCRIBES THE CANDIDATES ACCURATELY. They come off `name_rungs`,
## so one of them can differ by the whole dropped branch prefix (item 2's
## `i(v.x` -> `i(x` rung), not only by case — "differ from it only in case" was
## simply false for that one.
set ::inv [list [slot {time i(v.x1.vs) i(X1.Vs)} 1]]
set ::added {}
set ::fake_state [dict create outputs [list \
   [dict create name {} expr {i(V.X1.VS)} plot 1 save 0]]]
said_clear
pcall ase::ui::auto_plot CURKEY
check "CU240d the decline says the names MATCH case-insensitively, not `differ only in case`" \
  [list [said_count {*match case-insensitively*i(X1.Vs)*i(v.x1.vs)*} error] \
        [said_count {*only in case*} error]] {1 0}
## ONE OFFENDER, ONE LINE. Three output rows referencing the same mis-cased
## current used to produce three byte-identical CIW lines — exactly the noise
## item 10's per-offender rule and item 11 §15.5's spellings-not-occurrences
## counting were written against, and the proc's own comment cites both.
set ::inv [list $DIST]
set ::added {}
set ::fake_state [dict create outputs [list \
   [dict create name {} expr {i(v.x1.vs)} plot 1 save 0] \
   [dict create name a expr {i(v.x1.vs) -1 *} plot 1 save 0] \
   [dict create name b expr {i(v.x1.vs) 2 *} plot 1 save 0]]]
said_clear
pcall ase::ui::auto_plot CURKEY
check "CU240e one offending spelling used three times is announced ONCE" \
  [list [said_count {*i(v.x1.vs)*i(V.X1.Vs)*} note] [llength $::added]] {1 3}

# ===========================================================================
# CU241 — the contracts the caller cannot afford to trust: the list LENGTH
# (dp_finish pairs it with qcolors positionally, so a short answer would
# repaint the survivors in the wrong colours), and the SESSION, which this item
# never rewrites — DECISIONS.md D1's precedent and item 10's explicit
# `ase::preflight_fix_session`, not a silent edit.
# ===========================================================================
## abort-proofing: under the MASTER RED there is no proc to rename, and a
## `rename` throw here would abort the file before the engine legs ever run —
## the state under which every sabotage reads as "nothing went red"
set had_rc [expr {[info commands wviewer::repair_currents] ne {}}]
if {$had_rc} { rename wviewer::repair_currents wviewer::repair_currents_real }
proc wviewer::repair_currents {token exprs} { return [list {only-one} {}] }
check "CU241 a short answer from the resolver is refused; the input survives" \
  [pcall ase::ui::repair_currents CURKEY {i(v1) v(in)}] {i(v1) v(in)}
proc wviewer::repair_currents {token exprs} { error "boom" }
check "CU241b a THROW leaves the expressions exactly as they were" \
  [pcall ase::ui::repair_currents CURKEY {i(v1) v(in)}] {i(v1) v(in)}
rename wviewer::repair_currents {}
if {$had_rc} { rename wviewer::repair_currents_real wviewer::repair_currents }
## the session's stored expression is the USER'S text and stays untouched: the
## repair is in memory, for this attach, and the next attach repairs again
set ::inv [list $DIST]
set ::fake_state [dict create outputs [list \
   [dict create name {} expr {i(v.x1.vs)} plot 1 save 0]]]
set before $::fake_state
set ::added {}
pcall ase::ui::auto_plot CURKEY
check "CU241c the SESSION STATE is not rewritten by the repair (D1's precedent)" \
  [list [expr {$::fake_state eq $before ? 1 : 0}] [lindex $::added 0]] \
  {1 {i(V.X1.Vs) {}}}

# ===========================================================================
# CU242 — ONE inventory read per BATCH. signal_list_all moves the engine's
# current-database pointer once per attached database and puts it back; item 3
# measured the neighbouring resolution at up to 189 ms with no cache and item 4
# ruled "resolve once per gesture". Per-expression calls would multiply it by
# the size of the queue.
# ===========================================================================
set ::ninv 0
pcall wviewer::repair_currents tok {i(v1) i(v.x1.vs) v(in) i(zz) i(e.x1.e1)}
check "CU242 five expressions cost ONE inventory read" $::ninv 1
set ::ninv 0
check "CU242b an empty batch costs none, and answers with itself" \
  [list [pcall wviewer::repair_currents tok {}] $::ninv] {{{} {}} 0}
## …and an inventory that cannot be read leaves everything alone
proc wviewer::signal_list_all {token {statusVar {}}} { error "no window" }
check "CU242c an unreadable inventory is not an excuse to change an expression" \
  [pcall wviewer::repair_currents tok {i(v1)}] {i(v1) {}}
proc wviewer::signal_list_all {token {statusVar {}}} { return {} }
check "CU242d no attached database at all: unchanged" \
  [pcall wviewer::repair_currents tok {i(v1)}] {i(v1) {}}
## THE INVENTORY IS ASKED OF THIS WINDOW. The real signal_list_all bails on its
## first line for a token it has no window for, so a repair that passed the
## wrong key (or `{}`) would silently answer "no databases" for everybody.
proc wviewer::signal_list_all {token {statusVar {}}} {
  if {$statusVar ne {}} { upvar 1 $statusVar st ; set st ok }
  incr ::ninv
  if {[lsearch -exact $::known_tokens $token] < 0} { return {} }
  if {!$::attached} { return {} }
  return $::inv
}
set ::attached 1
set ::inv [list $DIST]
check "CU242e a token with no viewer window repairs nothing; the right one does" \
  [list [pcall wviewer::repair_currents nosuchtoken {i(v.x1.vs)}] \
        [lindex [pcall wviewer::repair_currents tok {i(v.x1.vs)}] 0]] \
  {{i(v.x1.vs) {}} i(V.X1.Vs)}
## ONE NAME INDEX PER SLOT PER BATCH, not per token. `name_index`'s own contract
## says "built ONCE per name list and reused for every token", and it is O(names)
## — built inside the token loop, a batch of N currents over M names costs N*M
## (measured before the hoist: 30 expressions over 10001 names = 581.2 ms, all
## of it rebuilds, every token answering `keep`). CU242 counts inventory reads
## and is blind to this one.
rename wviewer::name_index wviewer::name_index_counted
set ::nidx 0
proc wviewer::name_index {names} { incr ::nidx ; return [wviewer::name_index_counted $names] }
set ::inv [list $DIST $COLL2]
set ::nidx 0
pcall wviewer::repair_currents tok {i(v1) i(v.x1.vs) v(in) i(zz) i(e.x1.e1) i(Vs)}
set nidx_batch $::nidx
rename wviewer::name_index {}
rename wviewer::name_index_counted wviewer::name_index
check "CU242f six expressions over two slots build TWO name indexes, not twelve" \
  $nidx_batch 2
set ::inv [list $DIST]
proc wviewer::signal_list_all {token {statusVar {}}} { return {} }

## --- restore every stub before the engine legs -----------------------------
foreach p {signal_list_all open attach_raw plot_signals ensure_auto_graph \
           clear_graph_traces regenerate add_trace} {
  rename wviewer::$p {}
  rename wviewer::${p}_real wviewer::$p
}
foreach p {last_rawfile last_vcdfiles session_state} {
  rename ase::$p {}
  rename ase::${p}_real ase::$p
}

# ===========================================================================
# CU236 — THE REAL ENGINE, on the committed fixture. tr_preserve.raw carries
# `v(In) v(MidNode) i(Vs)`; read `-case distinguish` it is exactly the database
# on which item 2's folded rung is suppressed. The repair's OUTPUT must resolve
# where its INPUT did not — that is the whole claim, checked against
# get_raw_index itself rather than against another Tcl mirror.
# ===========================================================================
set fx [file join $fixtures tr_preserve.raw]
check_true "CU236 fixture present" [file isfile $fx]
pcall xschem raw clear
check "CU236b the fixture reads as a case_sensitive database" \
  [list [pcall xschem raw read $fx tran -case distinguish] [pcall xschem raw case]] {1 1}
set names [split [pcall xschem raw list] "\n"]
set live [list [slot $names [pcall xschem raw case]]]
check "CU236c the engine MISSES the folded spelling on it" \
  [pcall xschem raw index {i(vs)}] -1
set rep [pcall wviewer::repair_current_token {i(vs)} $live]
check "CU236d the repair answers with the database's own spelling" \
  $rep {repaired i(Vs) i(Vs)}
check_true "CU236e and THAT spelling resolves in the engine" \
  [expr {[pcall xschem raw index [lindex $rep 1]] >= 0}]
## THE THEOREM, through the real engine: the same file read `-case preserve`
## resolves the folded spelling itself, so the repair has nothing to do
pcall xschem raw clear
pcall xschem raw read $fx tran -case preserve
set livep [list [slot [split [pcall xschem raw list] "\n"] [pcall xschem raw case]]]
check "CU236f on a FOLDING read the engine resolves it and the repair keeps it" \
  [list [expr {[pcall xschem raw index {i(vs)}] >= 0}] \
        [pcall wviewer::repair_current_token {i(vs)} $livep]] \
  {1 {keep i(vs) {}}}
pcall xschem raw clear

# ===========================================================================
# CU237 — the hierarchical shape, on the case-capable binary. SKIPPED, never
# failed, when it is absent or has stopped honouring `-D casemode=` (the ver_50
# fork keeps moving; the LEDGER records four rebuilds in five days). Nothing
# printed here contains a substring full_audit.sh scores a whole file on.
# ===========================================================================
set ng /home/qflow/dev/ngspice_test/build-ver_50/src/ngspice
set hraw [file join $scratch h_distinguish.raw]
set built 0
if {[file executable $ng]} {
  set deck [file join $scratch h.cir]
  set fh [open $deck w]
  puts $fh "* item 12 hierarchical current probe"
  puts $fh ".subckt Blk A B"
  puts $fh "Vs A n1 DC 0"
  puts $fh "R1 n1 B 1k"
  puts $fh ".ends"
  puts $fh "X1 In Out Blk"
  puts $fh "V1 In 0 DC 3"
  puts $fh "Rl Out 0 1k"
  puts $fh ".control"
  puts $fh "tran 1u 10u"
  puts $fh "write [file nativename $hraw]"
  puts $fh "quit"
  puts $fh ".end"
  close $fh
  catch {exec $ng -b -D casemode=distinguish $deck} ignore
  if {[file isfile $hraw]} { set built 1 }
}
if {!$built} {
  puts "note: CU237 not run (no case-capable ngspice here)"
} else {
  pcall xschem raw clear
  pcall xschem raw read $hraw tran -case distinguish
  set hnames [split [pcall xschem raw list] "\n"]
  set hlive [list [slot $hnames [pcall xschem raw case]]]
  ## the run must actually have kept the case, or the leg proves nothing
  if {[lsearch -exact $hnames {i(V.X1.Vs)}] < 0} {
    puts "note: CU237 not run (this build did not keep the case: $hnames)"
  } else {
    set hr [pcall wviewer::repair_current_token {i(v.x1.vs)} $hlive]
    check "CU237 a real distinguish raw: the constructed folded current is repaired" \
      [list [pcall xschem raw index {i(v.x1.vs)}] $hr] \
      [list -1 {repaired i(V.X1.Vs) i(V.X1.Vs)}]
    check_true "CU237b and the repaired spelling resolves in the engine" \
      [expr {[pcall xschem raw index [lindex $hr 1]] >= 0}]
  }
  pcall xschem raw clear
}

# ===========================================================================
# CU243 — THE ONE IMPURE CALL, THROUGH A REAL VIEWER. Everywhere above,
# `wviewer::signal_list_all` is stubbed; here it is the shipped proc, asked for
# the inventory of a REAL viewer window holding a REAL `-case distinguish`
# database. Needs a display, so it announces itself and stands down when there
# is none (nothing printed here is a substring full_audit.sh scores a file on).
# ===========================================================================
set repo [file normalize [file join $here .. ..]]
set cellroot  [file join $repo sky130A xschem_libs sky130_tests test_nfet_final]
set statefile [file join $cellroot ngspice_state1 test_nfet_final.state]
if {![info exists ::has_x] || [info commands winfo] eq {} || ![file isfile $statefile]} {
  puts "note: CU243 not run (no display, or no sky130 workarea)"
} else {
  proc viewer_ready {top} {
    for {set i 0} {$i < 300} {incr i} {
      update
      if {[winfo exists $top.drw] && [winfo ismapped $top.drw]} { return 1 }
      after 20
    }
    return 0
  }
  set lf [open [file join $scratch library.defs] w]
  puts $lf "DEFINE sky130_tests [file join $repo sky130A xschem_libs sky130_tests]"
  puts $lf "DEFINE sky130_fd_pr [file join $repo sky130A xschem_libs sky130_fd_pr]"
  puts $lf "DEFINE devices [file join $repo xschem_libs_newsym devices]"
  close $lf
  set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
  set ::library_registry_defs_only 1
  set ::XSCHEM_LIBRARY_PATH {}
  set st [ase::state_load $statefile]
  dict set st rundir [file join $scratch run]
  set sstate [file join $scratch session.state]
  ase::state_save $sstate $st
  set vtok [ase::session_key sky130_tests test_nfet_final ngspice_state1]
  ase::session_open $vtok $sstate
  set opened [pcall wviewer::open $vtok]
  set vtop [pcall wviewer::window_for $vtok]
  if {$opened ne {1} || ![viewer_ready $vtop]} {
    puts "note: CU243 not run (the viewer canvas never mapped)"
    catch {wviewer::close $vtok}
  } else {
    xschem new_schematic switch $vtop.drw
    pcall xschem raw clear
    pcall xschem raw read $fx tran -case distinguish
    set rdbs [pcall wviewer::signal_list_all $vtok]
    check "CU243 the REAL signal_list_all answers for the viewer's own token" \
      [list [llength $rdbs] [wviewer::dget [lindex $rdbs 0] case x]] {1 1}
    ## the whole feature, impure half included: the inventory really comes from
    ## THIS window, and a token with no window really answers with nothing
    check "CU243b the REAL repair rewrites i(vs) to the database's own i(Vs)" \
      [pcall wviewer::repair_currents $vtok {i(vs)}] \
      {i(Vs) {{repaired i(vs) i(Vs) i(Vs)}}}
    check "CU243c and the WRONG token repairs nothing (signal_list_all's own bail)" \
      [pcall wviewer::repair_currents nosuchtoken {i(vs)}] {i(vs) {}}
    pcall xschem raw clear
    catch {wviewer::close $vtok}
  }
}

} err]} { puts "FATAL: $err" ; incr fail }

## restore the real ciw_echo OUTSIDE the catch, so a FATAL cannot leave the stub
if {[info commands ::ciw_echo_orig] ne {}} {
  catch {rename ::ciw_echo {}}
  catch {rename ::ciw_echo_orig ::ciw_echo}
}

if {$fail} { puts "RESULT: $fail FAILED ($npass passed)" } \
else        { puts "RESULT: ALL PASS ($npass checks)" }
flush stdout
exit 0
