# Signal-search: the shared matcher and everything built on it
# (doc/claude/signal_browser_batch/PLAN.md items 1-7 — per settled decision 9
# this ONE file carries every item-1..7 check; each item APPENDS its group).
#
#   SM01-SM26  wviewer::sig_match — the shared matcher (item 1).
#              Shape; shell `*` `?` `[range]` and the literal-bracket escape;
#              regexp WHOLE-NAME anchoring (SM04, the ViVA trap, see below);
#              case default vs -case 1 on both syntax arms; -type filtering
#              alone and combined with a pattern; empty pattern = everything on
#              both arms; an invalid regexp -> {err ...} and NOT the whole list;
#              -sort 0/1/-1; the shell default; a bad option throws.
#   ST01-ST08  wviewer::sig_type (item 1) — v / i / other, incl. the deliberate
#              `@m...[id]` -> other divergence from ase::ui::output_kind.
#
# Standalone repro (item 1's checks need no X — later items' do):
#   ./src/xschem --pipe -q --nolog --nogui --script tests/headless/test_wave_sigsearch.tcl
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_wave_sigsearch.tcl
#
# NOTE for items 4-7: item 1 installs NO `after` handlers, so this file needs no
# bgerror override yet. The moment a dialog arrives, add one — a Tcl error
# inside an `after` handler pops bgerror and HANGS the headless run.
#
# This test writes nothing: no test_scratch dir, no droppings.

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

# recent-files gate (issue 0119)
set no_recent_files 1

# short local spellings; the procs themselves live in ::wviewer
proc sig_match {args} { uplevel 1 [linsert $args 0 ::wviewer::sig_match] }
proc sig_type  {n}    { ::wviewer::sig_type $n }

if {[catch {

# --- item 1: wviewer::sig_match / wviewer::sig_type --------------------------

# The fixture is DELIBERATELY UNSORTED, so SM20 can see that "raw order" really
# is the input order and not an accidental lsort.
#
# ⚠ QUOTING TRAP — build EVERY multi-element expectation with `[list ...]`,
# never a `{...}` literal. Raw names here contain brackets (`v(net_name[3])`,
# `@m.x1.m1[id]`) and Tcl's canonical list string-rep BRACE-QUOTES such an
# element, so `{v(net_name[3])}` written as a literal can never compare equal to
# the returned list. This cost the scout five phantom reds.
set SIGS [list v(out) v(l1) l1 l2 xl1 i(v1) I(V2) @m.x1.m1\[id\] \
               v(x1.x2.net5) net1 net5 v(net_name\[3\]) tmp]

check {SM01 sig_match returns an ok/err-tagged pair} \
  [lindex [sig_match $SIGS {}] 0] ok

# shell `l*` is whole-name anchored (string match already is) AND the subject is
# the full raw name: it takes l1/l2, but not xl1 and not v(l1).
check {SM02 shell l* matches l.. not xl.. not v(l1)} \
  [lindex [sig_match $SIGS {l*}] 1] [list l1 l2]

# SM04 — THE ViVA TRAP, ASSERTED INVERTED (declared, not silent).
# PLAN item 1's test bullet says regexp `l*` "matches everything (the documented
# ViVA trap)". Settled decision 3 says regexp patterns are wrapped `^(?:$pat)$`.
# Both cannot hold: under the wrapper `l*` is zero-or-more-`l` ANCHORED, so it
# matches only names made entirely of `l` — nothing here. Decision 3 wins (it is
# Settled, the bullet is illustrative; and sabotage (a) — "drop the anchoring" —
# only has a target under the anchored reading, since unanchored `l*` matching
# everything would PASS, not fail). Unanchored/ViVA would return all 13 names.
check {SM04 regexp l* is WHOLE-NAME anchored (ViVA trap killed)} \
  [sig_match $SIGS {l*} -syntax regexp] [list ok {}]

# Purpose-built list: `xl1` is OMITTED ON PURPOSE so that sabotage (a)
# (drop the anchoring) fails SM04 and ONLY SM04. Do NOT "improve" this by
# reusing $SIGS — that would give sabotage (a) a second target.
check {SM05 regexp l.* matches l.. only} \
  [lindex [sig_match [list l1 l2 net1] {l.*} -syntax regexp] 1] [list l1 l2]

check {SM06 shell net[0-9] range} \
  [lindex [sig_match $SIGS {net[0-9]}] 1] [list net1 net5]

check {SM07 shell literal-bracket escape *net_name[[]*} \
  [lindex [sig_match $SIGS {*net_name[[]*}] 1] [list v(net_name\[3\])]

check {SM08 shell ? single char} \
  [lindex [sig_match $SIGS {l?}] 1] [list l1 l2]

check {SM09 case-INsensitive by default (V(OUT) finds v(out))} \
  [lindex [sig_match $SIGS {V(OUT)}] 1] [list v(out)]

check {SM10 -case 1 is case-sensitive (V(OUT) finds nothing)} \
  [lindex [sig_match $SIGS {V(OUT)} -case 1] 1] [list]

# proves -case 1 is genuinely case-SENSITIVE and not "match nothing"
check {SM11 -case 1 still matches an exact-case name} \
  [lindex [sig_match $SIGS {I(V2)} -case 1] 1] [list I(V2)]

check {SM12 -type v} [lindex [sig_match $SIGS {} -type v] 1] \
  [list v(out) v(l1) v(x1.x2.net5) v(net_name\[3\])]
check {SM13 -type i excludes v(...)} [lindex [sig_match $SIGS {} -type i] 1] \
  [list i(v1) I(V2)]
check {SM14 -type other} [lindex [sig_match $SIGS {} -type other] 1] \
  [list l1 l2 xl1 @m.x1.m1\[id\] net1 net5 tmp]

check {SM15 -type v combined with a pattern} \
  [lindex [sig_match $SIGS {*net*} -type v] 1] \
  [list v(x1.x2.net5) v(net_name\[3\])]

check {SM16 empty pattern = everything (shell)} \
  [lindex [sig_match $SIGS {}] 1] $SIGS
check {SM17 empty pattern = everything (regexp)} \
  [lindex [sig_match $SIGS {} -syntax regexp] 1] $SIGS

# ONE check carrying BOTH halves of the requirement (err AND not-the-whole-list)
# so that sabotage (c) — restoring the legacy `if {$err} {set pattern {}}` —
# has exactly one target.
set r [sig_match $SIGS {[} -syntax regexp]
check {SM18 invalid regexp -> err, and NOT the whole list} \
  [list [lindex $r 0] [expr {[lindex $r 1] eq $SIGS}]] [list err 0]

# glob has no invalid patterns, so the same `[` is a plain no-match here —
# untouched by sabotage (c).
check {SM19 shell [ is not an error, just no match} \
  [sig_match $SIGS {[}] [list ok {}]

check {SM20 -sort default is RAW order} \
  [lindex [sig_match $SIGS {}] 1] $SIGS
check {SM21 -sort 1 is -increasing -dictionary} \
  [lindex [sig_match $SIGS {} -sort 1] 1] [lsort -increasing -dictionary $SIGS]
check {SM22 -sort -1 is -decreasing -dictionary} \
  [lindex [sig_match $SIGS {} -sort -1] 1] [lsort -decreasing -dictionary $SIGS]

# decision 7. Deliberately NOT also asserting it differs from the regexp
# result — that would give sabotage (a) a second target.
check {SM23 default syntax is shell} \
  [sig_match $SIGS {l*}] [sig_match $SIGS {l*} -syntax shell]

check {SM24 an unknown option throws} \
  [catch {sig_match $SIGS x -bogus 1}] 1

# regexp-arm case coverage that is insensitive to the -case DEFAULT, so
# sabotage (b) keeps exactly one target (SM09).
check {SM25 regexp arm honours -case 1} \
  [lindex [sig_match $SIGS {v\(.*\)} -syntax regexp -case 1] 1] \
  [list v(out) v(l1) v(x1.x2.net5) v(net_name\[3\])]

# decision 2: the subject is the FULL raw name, so a bare `out` must NOT find
# `v(out)` the way the legacy stripped dialog would.
check {SM26 subject is the full raw name, never the stripped form} \
  [lindex [sig_match $SIGS {out}] 1] [list]

check {ST01 sig_type v(out) -> v}      [sig_type {v(out)}] v
check {ST02 sig_type V(OUT) -> v}      [sig_type {V(OUT)}] v
check {ST03 sig_type i(v1) -> i}       [sig_type {i(v1)}] i
check {ST04 sig_type I(V2) -> i}       [sig_type {I(V2)}] i
# deliberate divergence from ase::ui::output_kind (which calls a leading @
# `current`) — pinned so the disagreement is visible, flagged for item 9
check {ST05 sig_type @m.x1.m1[id] -> other (NOT i)} [sig_type {@m.x1.m1[id]}] other
check {ST06 sig_type net1 -> other}    [sig_type {net1}] other
check {ST07 sig_type vout -> other}    [sig_type {vout}] other
check {ST08 sig_type {} -> other}      [sig_type {}] other

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  incr fail
}

# --- verdict -----------------------------------------------------------------
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
