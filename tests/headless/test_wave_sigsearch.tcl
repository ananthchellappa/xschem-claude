# Signal-search: the shared matcher and everything built on it
# (doc/claude/signal_browser_batch/PLAN.md items 1-7 — per settled decision 9
# this ONE file carries every item-1..7 check; each item APPENDS its group).
#
#   SM01-SM27  wviewer::sig_match — the shared matcher (item 1).
#              Shape; shell `*` `?` `[range]` and the literal-bracket escape;
#              regexp WHOLE-NAME anchoring (SM04, the ViVA trap, see below);
#              case default vs -case 1 on BOTH syntax arms (shell SM09/SM10/SM11,
#              regexp SM27/SM25 — the default is checked per-arm because the two
#              arms carry SEPARATE -nocase flags in the implementation and one
#              can regress without the other); -type filtering
#              alone and combined with a pattern; empty pattern = everything on
#              both arms; an invalid regexp -> {err ...} and NOT the whole list;
#              -sort 0/1/-1; the shell default; a bad option throws.
#   ST01-ST08  wviewer::sig_type (item 1) — v / i / other, incl. the deliberate
#              `@m...[id]` -> other divergence from ase::ui::output_kind.
#   SB01-SB12  the PURE half of item 2 — sig_bare / sig_split / signal_entry.
#              Wrapper stripping and its trailing anchor; path/leaf on the
#              UNWRAPPED name (the declared divergence, see the group header);
#              the entry dict's exact key set, its full-name `name` field
#              (decision 2) and its sig_type-sourced `type` field.
#   SL01-SL15  wviewer::signal_list (item 2) over TWO REAL xschem contexts —
#              the no-raw answer, the raw inventory, the 0173 loan discipline
#              (the context comes back), the landmine-17 refusal, and the
#              unknown-token guard.
#   GS01-GS21  the LEGACY Graph dialog's `::graph_get_signal_list`, retrofitted
#              onto wviewer::sig_match (item 3, src/xschem.tcl; match subject
#              fixed by DRIVER RULING 16). Both sort directions; one NAMED check
#              per part of the legacy `v(...)` strip (see the GS17-GS21 block —
#              under ruling 16 that regsub is not cosmetic, it produces the
#              MATCH SUBJECT, so every piece of it is load-bearing; that block
#              NAMES which part broke, it does NOT prove coverage — GSO01 does);
#              that `i(...)` is NOT stripped — the legacy regsub, not sig_bare;
#              that the sort runs on FULL names and the strip after; that the
#              strip happens BEFORE the match, so the subject is the STRIPPED
#              name (ruling 16); unanchored, case-sensitive matching preserved
#              via the caller-side `.*(?:$pat).*` wrap; and the only two
#              permitted on-screen differences from the pre-retrofit body —
#              GS08 (an invalid regexp -> {} instead of everything) and GS13
#              (the RULED divergence: an ARE director inside the wrap is an
#              error). GS12/GS14 pin the two deltas ruling 16 REVERSED; they
#              must not drift back.
#   GSO01-06   THE DIFFERENTIAL PROPERTY ORACLE for `::graph_get_signal_list`
#              (item 3, DRIVER RULING 17). A FROZEN copy of the pre-item-3 body
#              (`git show afdd44a0^:src/xschem.tcl`) run beside the shipping one
#              over a generated 51-name x 84-pattern matrix (54 blobs — 51
#              single-name, the whole set, and 2 ordering blobs) x both sort
#              directions = 9,072 comparisons in ~0.29 s, asserting ZERO
#              differences except the two SANCTIONED ones (decision 4's
#              invalid-regexp -> {}, and ruling 16 delta 3's ARE director ->
#              error), each excluded by its own narrow three-conjunct predicate.
#              This — not the GS fixtures — is what makes the coverage claim on
#              the strip regsub and the `.*(?:$pat).*` wrap COMPLETE: every
#              behaviour-changing mutation fails GSO01 automatically, with the
#              differing name/pattern/got/exp PRINTED as a repro. GSO02-GSO06
#              stop the oracle passing vacuously (matrix ran whole; both
#              sanctioned classes actually exercised; the frozen reference is
#              still the legacy body and not a call to the shipping one; the
#              required real-name classes are still present).
#
# Standalone repro (every check in this file is `--nogui`-safe today; later
# items' will not be, which is why both spellings stay documented):
#   ./src/xschem --pipe -q --nolog --nogui --script tests/headless/test_wave_sigsearch.tcl
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_wave_sigsearch.tcl
#
# NOTE for items 4-7: items 1-2 install NO `after` handlers and no dialog, so
# this file needs no bgerror override yet. The moment a dialog arrives, add one
# — a Tcl error inside an `after` handler pops bgerror and HANGS the headless
# run.
#
# EXPECTED STDOUT NOISE from the item-2 group, harmless and NOT a failure:
#   can't read "toolbar_visible": no such variable     (xschem new_schematic create, --nogui)
#   new_schematic("switch_tab"...): no tab to switch to found: .wvsl_nosuch.drw
# `full_audit.sh` keys its verdict on the `RESULT:` line only, so neither can
# flip it.
#
# PROCESS STATE LEFT BEHIND by the item-2 group, for items 3-7 which append to
# this same file (settled decision 9): a SECOND xschem context `.x1.drw`; an
# in-memory raw on EACH of the two contexts (`sl_main.raw` with vsweep +
# wrong_ctx_var on `.drw`, `sl_view.raw` with the SLFIX names on `.x1.drw`);
# and two `::wviewer::windows` entries, `wvsl` and `wvsl_bogus`. The group ends
# by switching the context back to the main one. Do not assume a pristine
# process below this line.
# The item-3 group additionally leaves the global `graph_sort` DEFINED and set
# to 0 — the value `set_ne graph_sort 0` gives it when .graphdialog opens, so
# nothing downstream can tell the difference. It must be left at 0, not 1.
# It also leaves the oracle's procs and globals defined: `gsl_frozen_ref` and
# the `gso_*` predicates/counters/lists. Items 4-7 must not reuse those names.
#
# This test writes nothing: no test_scratch dir, no droppings. `xschem raw new`
# is in-memory — no `.raw` file appears (verified with `git status`).

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

# Error-guarded call: run `args`, return its value, or `ERR:<message>` when it
# throws. REQUIRED, not stylistic — item 2's checks call code that a sabotage
# can make THROW, and an unguarded throw would hit the outer `catch ... bigerr`
# and abort every remaining check, turning a one-target sabotage into a
# file-wide abort. Every item-2 check that touches a context goes through this.
proc pcall {args} {
  if {[catch {uplevel 1 $args} r]} { return "ERR:$r" }
  return $r
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

# decision 7, asserted against an INDEPENDENT literal (not against another
# sig_match call): under the shell default `l*` is a glob and takes l1/l2; if the
# default flipped to regexp, `^(?:l*)$` takes nothing. Deliberately NOT also
# asserting it differs from the regexp result — that would give sabotage (a) a
# second target.
check {SM23 default syntax is shell} \
  [sig_match $SIGS {l*}] [list ok [list l1 l2]]

check {SM24 an unknown option throws} \
  [catch {sig_match $SIGS x -bogus 1}] 1

check {SM25 regexp arm honours -case 1} \
  [lindex [sig_match $SIGS {v\(.*\)} -syntax regexp -case 1] 1] \
  [list v(out) v(l1) v(x1.x2.net5) v(net_name\[3\])]

# decision 2: the subject is the FULL raw name, so a bare `out` must NOT find
# `v(out)` the way the legacy stripped dialog would.
check {SM26 subject is the full raw name, never the stripped form} \
  [lindex [sig_match $SIGS {out}] 1] [list]

# SM27 — the regexp arm's case-INsensitive DEFAULT (decision 6), with NO -case
# flag. REQUIRED, and it may not be traded away for sabotage hygiene: the shell
# and regexp arms carry two SEPARATE `-nocase` flags (wave_viewer.tcl:1584 and
# :1590 — re-measured by item 3; item 2's insertion drifted them +13 from the
# :1571/:1577 this comment used to cite), so deleting the regexp one alone
# makes RegExp-mode search
# case-SENSITIVE by default while every shell check stays green — measured, a
# real coverage hole that shipped past 33 green checks. Item 4's search bar
# ships Shell+RegExp with Match-case OFF, so this is the exact default a user
# hits. Consequence, declared: sabotage (b) (flip the -case default) now fails
# TWO checks, SM09 and SM27 — both of them case-DEFAULT checks and nothing else.
# That is correct scoping, not leakage; coverage wins over a one-target count.
check {SM27 regexp arm is case-INsensitive by DEFAULT} \
  [lindex [sig_match $SIGS {V\(OUT\)} -syntax regexp] 1] [list v(out)]

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

# --- item 2: wviewer::signal_list — the typed signal inventory ---------------
#
# GROUP SB — the PURE half. No context, no raw.
#
# ⚠ DECLARED DIVERGENCE, pinned by SB04/SB07/SL10: `path`/`leaf` are computed
# on the UNWRAPPED name, not on a literal dot-split of the full raw name. The
# PLAN's contract line reads "leaf <last dot-segment> path <all but last>";
# read literally against `v(x1.x2.net5)` that yields path `v(x1` and leaf
# `net5)`, so item 8's hierarchy tree would grow a node called `v(x1`. The
# `name` field is still the FULL raw name (SB11) and the type filter still
# reads the prefix off the full name (SB12), so settled decision 2 — which
# governs the MATCH SUBJECT — is untouched. See receipts/02_receipt.md.
#
# The `[list ...]` quoting rule from the item-1 group applies here too, and
# harder: SB07/SB08/SL04 all carry bracketed names.

check {SB01 sig_bare strips the v(...) wrapper} \
  [::wviewer::sig_bare {v(out)}] out
check {SB02 sig_bare leaves @m.x1.m1[id] alone (no wrapper)} \
  [::wviewer::sig_bare {@m.x1.m1[id]}] {@m.x1.m1[id]}
check {SB03 sig_bare leaves a bare name alone} \
  [::wviewer::sig_bare {net1}] net1
# SB09 pins the trailing `$` anchor: `v(a)b` does not END in `)`, so there is
# no wrapper to strip. Drop the anchor and it becomes `a)b`.
check {SB09 sig_bare v(a)b is UNCHANGED (trailing anchor)} \
  [::wviewer::sig_bare {v(a)b}] {v(a)b}

check {SB04 sig_split v(x1.x2.net5) -> {x1.x2 net5}} \
  [::wviewer::sig_split {v(x1.x2.net5)}] [list x1.x2 net5]
check {SB05 sig_split v(out) -> empty path} \
  [::wviewer::sig_split {v(out)}] [list {} out]
check {SB06 sig_split net1 -> empty path} \
  [::wviewer::sig_split {net1}] [list {} net1]
check {SB07 sig_split @m.x1.m1[id] -> {@m.x1 m1[id]}} \
  [::wviewer::sig_split {@m.x1.m1[id]}] [list @m.x1 {m1[id]}]
check {SB08 sig_split v(net_name[3]) -> empty path, bracketed leaf} \
  [::wviewer::sig_split {v(net_name[3])}] [list {} {net_name[3]}]

check {SB10 signal_entry key set is exactly leaf/name/path/type} \
  [lsort [dict keys [::wviewer::signal_entry {v(x1.x2.net5)}]]] \
  [list leaf name path type]
# decision 2: `name` is the FULL raw name, never the bare/stripped form
check {SB11 signal_entry name is the FULL raw name} \
  [dict get [::wviewer::signal_entry {v(x1.x2.net5)}] name] {v(x1.x2.net5)}
# `type` must come from sig_type, case arm included — not a private re-impl
check {SB12 signal_entry type comes from sig_type (i(v1) and I(V2))} \
  [list [dict get [::wviewer::signal_entry {i(v1)}] type] \
        [dict get [::wviewer::signal_entry {I(V2)}] type]] [list i i]

# GROUP SL — signal_list over TWO REAL xschem contexts.
#
# The `::wviewer::windows` entries are FABRICATED rather than produced by
# `wviewer::open`: going through the real open path would drag in
# ase::session_open plus the sky130A cellview scaffolding (and its documented
# P4/P6/P8 gesture flakes) for no extra coverage of signal_list itself. What
# matters is genuine: the token points at a REAL second xschem context created
# by `new_schematic create`, so the ctx switch, the per-context raw and the
# 0173 restore are all real. Only the toplevel is fake — and it MUST be a
# NON-EXISTENT widget path, because leave_ctx -> wviewer::retitle guards
# `winfo exists` but not `wm title`, so pointing `top` at a real non-toplevel
# would throw out of leave_ctx under X while passing under --nogui.

set SLMAIN [xschem get current_win_path]
# a raw on the WRONG context, so SL12 can prove the switch really happened
xschem raw new sl_main.raw dc vsweep 0 1.0 0.5
xschem raw add wrong_ctx_var {vsweep 1 +}
xschem new_schematic create
set SLVWP [xschem get current_win_path]
dict set ::wviewer::windows wvsl \
  [dict create top .wvsl_no_such_top  win_path $SLVWP]
dict set ::wviewer::windows wvsl_bogus \
  [dict create top .wvsl_no_such_top2 win_path .wvsl_nosuch.drw]
xschem new_schematic switch $SLMAIN

# Phase A — the viewer context exists but carries NO raw yet.
# `xschem raw list` THROWS "No raw file loaded" there; signal_list must turn
# that into the ANSWER {}, which is what feeds the legacy dialog's
# "no raw data loaded" note.
check {SL01 no raw on the viewer ctx -> {} and no throw} \
  [pcall ::wviewer::signal_list wvsl] {}
check {SL02 the context is back on the main win after a no-raw read} \
  [xschem get current_win_path] $SLMAIN

# Phase B — build a raw on the VIEWER context, then read it from the MAIN one.
set SLFIX [list v(out) i(v1) v(x1.x2.net5) net1 @m.x1.m1\[id\] I(V2) \
                v(net_name\[3\])]
xschem new_schematic switch $SLVWP
xschem raw new sl_view.raw dc vsweep 0 1.0 0.5
foreach n $SLFIX { xschem raw add $n {vsweep 1 +} }
xschem new_schematic switch $SLMAIN

set SLL [pcall ::wviewer::signal_list wvsl]
set SLCTX [xschem get current_win_path]
set SLNAMES {}
catch { foreach d $SLL { lappend SLNAMES [dict get $d name] } }

# 7 fixture names + the implicit `vsweep` that `raw new` creates
check {SL03 signal_list count is the raw's var count} [llength $SLL] 8
check {SL04 names are the raw's names, in raw order} \
  $SLNAMES [linsert $SLFIX 0 vsweep]
check {SL05 the context is back on the main win after a real read} \
  $SLCTX $SLMAIN

proc slfind {name field} {
  global SLL
  foreach d $SLL { if {[dict get $d name] eq $name} { return [dict get $d $field] } }
  return {NOT-FOUND}
}
check {SL06 v(out) classifies v}                 [slfind {v(out)} type] v
check {SL07 i(v1) classifies i}                  [slfind {i(v1)} type] i
check {SL08 I(V2) classifies i (case, via sig_type)} [slfind {I(V2)} type] i
check {SL09 net1 classifies other}               [slfind net1 type] other
check {SL10 v(x1.x2.net5) splits into x1.x2 / net5} \
  [list [slfind {v(x1.x2.net5)} path] [slfind {v(x1.x2.net5)} leaf]] \
  [list x1.x2 net5]
check {SL11 v(out) has an empty path} \
  [list [slfind {v(out)} path] [slfind {v(out)} leaf]] [list {} out]
# the MAIN context's own raw carries wrong_ctx_var; seeing it here would mean
# the read never left the caller's context
check {SL12 the MAIN ctx's wrong_ctx_var is ABSENT (the switch happened)} \
  [lsearch -exact $SLNAMES wrong_ctx_var] -1

# Phase C — the refusal (landmine 17) and the unknown token.
set SLBOGUS [pcall ::wviewer::signal_list wvsl_bogus]
check {SL13 a token whose win_path does not exist -> {}} $SLBOGUS {}
check {SL14 a refused switch does not move the context} \
  [xschem get current_win_path] $SLMAIN
check {SL15 an unknown token -> {} (the dict-exists guard)} \
  [pcall ::wviewer::signal_list nosuchtoken] {}

xschem new_schematic switch $SLMAIN

# --- item 3: graph_get_signal_list retrofitted onto the shared matcher -------
# `::graph_get_signal_list` (src/xschem.tcl) is the LEGACY Graph-dialog filter.
# Item 3 reimplements its body as a `wviewer::sig_match` call; its ON-SCREEN
# behaviour must not change except where a check below says DECLARED.
#
# `graph_sort` does not exist until .graphdialog is built, and the proc reads it
# as a global — measured: an unset graph_sort throws "can't read graph_sort".
# This group sets it explicitly and leaves it at 0 (which is what
# `set_ne graph_sort 0` would have made it anyway).
#
# ⚠ FIXTURE RULE, same discipline as SM05: GSPLAIN deliberately carries NO
# `v(...)`-wrapped name, so the named sabotage (revert the display strip) fails
# GS03 and ONLY GS03; GS05 stays strip-INSENSITIVE by construction (it asserts a
# strip-invariant element) for the same reason. Do not "improve" these fixtures
# by folding them together or reusing a wrapped list — that silently hands the
# strip sabotage extra targets. Every check that DOES need a wrapped name gets
# its own one-element blob (GS03, GS16-GS21) or its own tiny blob (GS12/GS14),
# so the fixtures stay separable.
#
# ⚠ WHAT CHANGED UNDER RULING 16, and why the old "assert a length" trick is
# now wrong: the regsub is no longer a cosmetic display step run after the
# match — it produces the MATCH SUBJECT. GS12/GS13/GS14 used to assert only
# `llength` precisely so the strip sabotage would gain no extra targets; that
# reasoning is dead (the strip SHOULD gain targets now), and a count-only
# assertion is strictly weaker — GS14's "length 1" was equally satisfied by the
# WRONG element. They assert CONTENT below.
set GSPLAIN "time\nabout\ni(v1)\nx1.out\nnet5\nOut"
proc gsl {blob pat} { uplevel 1 [list pcall graph_get_signal_list $blob $pat] }

set ::graph_sort 1
check {GS01 graph_sort 1 is -increasing -dictionary} \
  [gsl $GSPLAIN {}] [list about i(v1) net5 Out time x1.out]
set ::graph_sort 0
check {GS02 graph_sort 0 is -decreasing -dictionary} \
  [gsl $GSPLAIN {}] [list x1.out time Out net5 i(v1) about]
set ::graph_sort 1
# NAMED SABOTAGE TARGET: delete the strip -> this check fails (and, since
# ruling 16, so do GS12/GS14 — one strip now serves BOTH the match subject and
# the display, so deleting it is two defects at once. MOVING it back after the
# match, which is the pre-ruling-16 body, fails GS12+GS14 and leaves this green).
check {GS03 the legacy v(...) display strip still happens} \
  [gsl {v(out)} {}] out
check {GS04 i(...) is NOT stripped (the legacy regsub, not sig_bare)} \
  [gsl {i(v1)} {}] {i(v1)}
# strip-insensitive on purpose: `mm` sorts before `v(aa)` but AFTER `aa`, so
# this sees the sort/strip ORDER without ever looking at a stripped element.
check {GS05 the sort runs on FULL names, the strip after} \
  [lindex [gsl "v(aa)\nmm" {}] 0] mm
check {GS06 matching stays UNANCHORED (legacy semantics)} \
  [gsl $GSPLAIN {out}] [list about x1.out]
check {GS07 matching stays case-SENSITIVE (-case 1)} \
  [gsl $GSPLAIN {Out}] [list Out]
# the ONE sanctioned on-screen change (settled decision 4). Legacy returned all
# six names here, which is the worst possible failure for a search box.
check {GS08 an invalid regexp yields {} and NOT the whole list} \
  [gsl $GSPLAIN {[}] {}
check {GS09 an empty signal blob -> {} and no throw} [gsl {} {}] {}
check {GS10 the unanchor wrap keeps a user ALTERNATION whole} \
  [gsl "xa\nay\nzz" {x|y}] [list ay xa]
check {GS11 a user's own ^...$ anchors still work on an unwrapped name} \
  [gsl $GSPLAIN {^time$}] [list time]
# GS12/GS13/GS14 pin the three deltas DRIVER RULING 16 ruled on (receipt 03 D3).
# GS12 and GS14 pin the two it REVERSED — the match subject is the STRIPPED name
# again, as in the pre-retrofit body — and GS13 pins the one it ACCEPTED. All
# three assert CONTENT, not `llength`: see the ruling-16 note in the group header
# for why the old count-only form was both moot and weaker. Do NOT "fix" GS13 by
# hoisting directors out of the `.*(?:$pat).*` wrap: it is a RULED, documented
# divergence, and this check is what stops it drifting back silently in either
# direction.
#
# GS12's blob carries `vv` so the check pins WHICH name a bare `v` returns, not
# merely how many. Delta 1 reintroduced (match the FULL name) would return
# `out vv`; the shipping subject is the stripped name, so only `vv` carries a v.
check {GS12 RULED 16: a bare `v` finds vv only, NOT the stripped v(out)} \
  [gsl "v(out)\nzz\nvv" {v}] [list vv]
check {GS13 RULED 16 (accepted divergence): an embedded ARE option (?i) is an error -> {}} \
  [gsl "Out\nzz" {(?i)out}] {}
# content, not `llength 1`: the count alone was equally satisfied by `zz`.
check {GS14 RULED 16: a user's own ^out$ matches the wrapped v(out) again, and shows `out`} \
  [gsl "v(out)\nzz" {^out$}] out
check {GS15 the blob is split on NEWLINES, not on whitespace} \
  [gsl "a b\nc" {}] [list {a b} c]
# The ONE fixture element with a `v(...)` prefix AND trailing text. Without it,
# dropping the regsub's trailing `$` anchor left every check green (receipt 03
# P2). Deliberately its own one-element blob, so it does not hand the strip
# sabotage extra targets via GSPLAIN (see the FIXTURE RULE above).
check {GS16 the display strip is END-ANCHORED: v(a)x is NOT stripped to ax} \
  [gsl {v(a)x} {}] {v(a)x}

# --- GS17-GS21: the strip regsub, one NAMED check per part -------------------
#
# ⚠ READ THIS FIRST — WHAT THIS BLOCK IS AND IS NOT. It is a DEFECT-NAMING AID,
# not a completeness proof. An earlier revision of this comment presented the
# map below as a complete part->check map and its commit message claimed "every
# one of its five parts now fails a named check when mutated". BOTH CLAIMS WERE
# FALSE, and dangerously so: a maintainer reading them beside a green suite
# would reasonably "tidy" `(.*)` into an explicit character class and ship the
# regression. The corrected statement, which is the one that is actually true:
#
#   * These five checks catch the DELETION of each part, and — for the `v`
#     literal and the capture group — the specific narrowings/widenings named
#     below. They do NOT catch arbitrary mutation. Measured after the claim was
#     written: `(.*)` -> `[^,]*` / `[^)]*` / `.+` / `[a-zA-Z0-9_.\[\]]*` /
#     `[\w.\[\]]*`, `\(` -> `.`, and `v` -> `v?` ALL stayed green here while
#     changing between 144 and 1966 real comparisons.
#   * COMPLETENESS IS PROVED BY GSO01 (the differential property oracle below),
#     and by nothing in this block. Every one of those seven mutations, plus
#     `v`->`v+`, `[^ ]*`, `[[:print:]]*`, `[vV]`, `-nocase`, and the two anchors,
#     now fails GSO01 with a printed repro.
#   * What this block still buys, and why it is kept: GSO01 tells you THAT the
#     dialog diverged from its pre-item-3 self and hands you one differing
#     name/pattern; GS17-GS21 tell you WHICH PART of the regsub you broke,
#     without reading the matrix output. Naming, not coverage.
#
# `regsub {^v\((.*)\)$} $i {\1} i` has five moving parts — a leading anchor, a
# trailing anchor, the `v` literal, the two paren literals, and the capture
# group. Under DRIVER RULING 16 that regsub is NOT a cosmetic display step run
# after the match: it produces the MATCH SUBJECT, so a mutation to any one part
# is a silent on-screen AND on-search regression. GS16 alone pinned the trailing
# anchor (receipt 03 P2, closed by the ruling-16 fixup); the LEADING anchor was
# the same hole one element over, and it survived a full green run of all 77
# checks. Part -> the named check that fails when it is DELETED (and, where
# stated, when it is altered in the specific way named):
#
#   leading `^`    GS17 (display) + GS18 (subject). Verifier-measured: with the
#                  `^` dropped, `xv(b)` displays as `xb` and a user's `^xv`
#                  returns {} — 1872 differing comparisons against the legacy
#                  body in the 22560-comparison differential fuzz — while every
#                  one of the 77 pre-fixup checks stayed GREEN.
#   trailing `$`   GS16 (display) + GS21 (subject).
#   the `v`        GS03 (DELETE it and `v(out)` stops stripping),
#                  GS04 (widen it to `[vi]`/`.` and `i(v1)` starts stripping),
#                  GS20 (case-fold it and `V(OUT)` starts stripping — the legacy
#                  regsub is case-SENSITIVE, and `V(OUT)` is a name real
#                  simulators emit).
#                  NOT caught here: `v` -> `v?` or `v+`. GSO01 catches both.
#   the parens     GS03 (DELETE `\(` -> `(out`; DELETE `\)` -> `out)`).
#                  NOT caught here: WIDENING either one to `.` — asymmetric with
#                  the `v` literal above, and measured green. GSO01 catches it.
#   the capture    GS03 (replacement `\1` -> `&`, or a non-capturing group)
#                  + GS19, which pins a DOT and a BRACKET and nothing else.
#                  NOT caught here: any other narrowing of `.*`. GSO01 catches
#                  them, via a name axis that carries a comma, a bang, a hash, a
#                  hyphen, a space, a tab, a nested paren, empty content, and a
#                  full printable-punctuation sweep.
#
# Each gets its OWN one-element blob, per the FIXTURE RULE, so they stay
# separable. GS17, GS18, GS20 and GS21 are strip-DELETION-insensitive by
# construction — an absent strip leaves `xv(b)`, `V(OUT)` and `v(a)x` unchanged,
# which is exactly what they assert — so the named GS03 sabotage gains nothing
# from them. DECLARED consequence: GS19 alone DOES become a further target for
# it, because its fixture really is `v(...)`-wrapped. That is correct under
# ruling 16, where deleting the strip is two defects at once (see GS03's own
# comment, which already records the same widening onto GS12/GS14).
check {GS17 the display strip is START-ANCHORED: xv(b) is NOT stripped to xb} \
  [gsl {xv(b)} {}] {xv(b)}
check {GS18 RULED 16: the START anchor is in the MATCH SUBJECT too (^xv finds xv(b))} \
  [gsl {xv(b)} {^xv}] {xv(b)}
# NAME NARROWED TO MATCH WHAT IT ACTUALLY PINS. It was "the capture takes ANY
# content — dots and brackets alike", which is a property claim this ONE fixture
# cannot support: it pins exactly two characters, and five capture narrowings
# sailed past it. The ANY-content property is real, and it is asserted by GSO01.
check {GS19 the capture takes a DOT and a BRACKET (ANY content: see GSO01)} \
  [gsl {v(x1.x2.net_name[3])} {}] [list {x1.x2.net_name[3]}]
check {GS20 the strip regsub is case-SENSITIVE: V(OUT) is NOT stripped} \
  [gsl {V(OUT)} {}] {V(OUT)}
check {GS21 RULED 16: the END anchor is in the MATCH SUBJECT too} \
  [gsl {v(a)x} {^v\(a\)x$}] {v(a)x}

# --- GSO01-GSO06: the DIFFERENTIAL PROPERTY ORACLE (DRIVER RULING 17) --------
#
# WHY THIS EXISTS, and why the GS fixtures above are not enough on their own.
# Everything above is a FIXTURE SET, and a fixture set can never prove a
# regexp's identity: the mutation space of `^v\((.*)\)$` is unbounded — a
# character class can always be narrowed by one more character — so "find a
# mutation that stays green" always succeeds eventually. Two review rounds did
# exactly that, seven times, and every one of the seven was a REAL on-screen
# regression: round 1 found the dropped leading `^` (1872 differing comparisons
# against the legacy body); round 2 found five narrowings of the capture group
# (`[a-zA-Z0-9_.\[\]]*`, `[\w.\[\]]*`, `[^,]*`, `[^)]*`, `.+`), a `\(` widened
# to `.`, and `v` widened to `v?` (144-1966 differing each). DRIVER RULING 17
# withdrew "a green mutation = FAIL" as an acceptance criterion — it has no
# fixed point, so it generates an infinite regress — and replaced it with this:
#
#   a regex whose identity is load-bearing is covered when the test file carries
#   a DIFFERENTIAL PROPERTY ORACLE — a frozen copy of the reference
#   implementation, exercised over a generated name x pattern matrix, asserting
#   ZERO differences except the explicitly sanctioned ones.
#
# That is strictly stronger than any finite fixture set: EVERY behaviour-changing
# mutation of `graph_get_signal_list` — the strip regsub, the `.*(?:$pat).*`
# wrap, the sort mapping, the split, the err arm — fails GSO01 automatically,
# including the mutations nobody thought of. The GS fixtures are KEPT because
# they NAME the defect (GS17 tells you WHICH part broke; GSO01 only tells you
# that something did, plus the exact repro), but the COMPLETENESS claim now
# rests here and nowhere else. See the GS17-GS21 map above, which is explicitly
# labelled as a naming aid and NOT as a complete part->check map.
#
# WHAT THIS ORACLE STILL CANNOT SEE, stated so nobody over-reads GSO01:
#  1. A mutation that REMOVES a sanctioned difference — e.g. restoring the
#     legacy `if {$err} {set pattern {}}` widening — makes the shipping body MORE
#     like the frozen reference, and an equivalence oracle is blind to that by
#     construction. GS08 and GS13 are what pin those two, and they are NOT
#     redundant with GSO01. (Measured: that mutation fails GS08+GS13 — and, as it
#     happens, GSO01/GSO03/GSO05 too, because it also un-empties the DIRECTOR
#     patterns, which is a difference in the other direction.)
#  2. Mutations that are genuinely BEHAVIOUR-PRESERVING. Three were found and
#     they all survive on purpose: `(.*)` -> `(.*?)` and `regsub` -> `regsub -all`
#     (both anchored `^...$`, so the total match is unique and lazy/greedy and
#     -all cannot change the capture), and dropping the `$pattern ne {}` guard
#     (`^(?:.*(?:).*)$` matches every name, exactly as the short-circuit does).
#     A test that failed on those would be pinning the source text, not the
#     behaviour.
#  3. Anything outside `graph_get_signal_list` itself. `wviewer::sig_match` has
#     its own group (SM01-SM27); this oracle would not notice a sig_match change
#     that the dialog's call happens not to reach.
#
# ⚠⚠ `gsl_frozen_ref` IS A FROZEN ORACLE — DO NOT EDIT IT TO MAKE A TEST PASS.
# It is the pre-retrofit body, copied verbatim from
# `git show afdd44a0^:src/xschem.tcl` (lines 4469-4486, the whole proc). It is
# NOT a second implementation to keep in sync with the first; it is the
# historical record of what the Graph dialog did before item 3 touched it, and
# its entire value is that it CANNOT drift. Changing BOTH
# `::graph_get_signal_list` and this proc so that they agree again is not fixing
# a test — it is deleting the test while leaving it green, on purpose, and a
# reviewer should read any diff that touches this proc as exactly that until
# proven otherwise. If shipped behaviour must legitimately change, the change
# goes in the SANCTIONED-DIFFERENCE predicate below, with the driver ruling that
# authorised it cited on the line that adds it.
proc gsl_frozen_ref {siglist pattern} {
  global graph_sort
  set siglist [split $siglist \n]
  set direction {-decreasing}
  if {$graph_sort} {set direction {-increasing}}
  set result {}
  set siglist [lsort $direction -dictionary $siglist]
  # just check if pattern is a valid regexp
  set err [catch {regexp $pattern {12345}} res]
  if {$err} {set pattern {}}
  foreach i $siglist {
    regsub {^v\((.*)\)$} $i {\1} i
    if {[regexp $pattern $i] } {
       lappend result $i
    }
  }
  return $result
}

# THE SANCTIONED DIFFERENCES, and there are exactly TWO (driver ruling 17,
# restating decision 4 and ruling 16 delta 3). The predicate is deliberately
# NARROW — three conjuncts each — and NOT a broad "ignore anything that errors",
# which would swallow real defects wholesale:
#
#  (a) decision 4 — a regexp the LEGACY body rejected yields {} instead of the
#      entire signal list. Narrow: the legacy validity probe must actually
#      reject it, the new body must return EXACTLY {}, and the reference must
#      have returned EXACTLY its everything-answer. A mutation that turns a
#      rejected pattern into a partial list is NOT class (a) and is reported.
#  (b) ruling 16 delta 3 — an ARE director / embedded option (`(?i)x`,
#      `***=x`) is legal only at the very START of an RE, so the `.*(?:$pat).*`
#      wrap makes it an error. Narrow: the RAW pattern must be valid, the
#      WRAPPED pattern must be invalid, the pattern must actually BE a director
#      form, and the new body must return EXACTLY {}.
#
# `gso_wrapped_invalid` restates the wrap as a LITERAL rather than reading it
# out of the implementation on purpose: a predicate that derived the wrap from
# the code under test would move with it and stop being a predicate.
proc gso_legacy_invalid {pat} { return [catch {regexp $pat {12345}}] }
proc gso_wrapped_invalid {pat} {
  if {$pat eq {}} { return 0 }
  return [catch {regexp -- "^(?:.*(?:$pat).*)\$" {}}]
}
proc gso_is_director {pat} {
  if {[regexp {^\(\?[a-zA-Z]} $pat]} { return 1 }
  if {[string range $pat 0 3] eq {***=}} { return 1 }
  if {[string range $pat 0 3] eq {***:}} { return 1 }
  return 0
}
proc gso_sanctioned {pat got exp every} {
  if {[gso_legacy_invalid $pat] && $got eq {} && $exp eq $every} { return a }
  if {![gso_legacy_invalid $pat] && [gso_wrapped_invalid $pat] &&
      [gso_is_director $pat] && $got eq {}} { return b }
  return {}
}

# THE NAME AXIS. Every class below is here because a real `.raw` emits it and
# because omitting it is exactly how the seven mutations stayed green:
#   v(a,b) / v(out,outb)  ngspice DIFFERENTIAL voltage — an ordinary line in a
#                         real raw, and the whole reason `[^,]*` survived.
#   v(vdd!) v(!)          bang in a supply name.
#   v(net#1) v(...n#2)    hash in a generated node name.
#   v(x-y) x-y            hyphen.
#   v()                   empty wrapper content (kills `.+`).
#   v(a(b)) v((y))        a paren INSIDE the wrapper (kills `[^)]*`).
#   (x)                   wrapper with no `v` (kills `v` -> `v?`).
#   vx(y)                 `v` + a non-paren + `(...)` (kills `\(` -> `.`).
#   xv(b) / v(a)x v(a)b   text before / after the wrapper (the two anchors).
#   V(OUT) V(out)         upper case (the regsub is case-SENSITIVE).
#   vv(a)                 a DOUBLED `v` (kills `v` -> `v+`).
#   v(a b!#$%...)         the PUNCTUATION SWEEP — every printable ASCII
#                         punctuation char inside one wrapper, so that ANY
#                         narrowing of the capture to a character class fails,
#                         not just the six classes review happened to try. This
#                         one name is what makes "the capture takes ANY content"
#                         a true statement rather than an aspiration; it is the
#                         difference between pinning a property and pinning a
#                         list of examples. Do not "clean up" its punctuation.
#   v(a<TAB>b)            a NON-PRINTABLE inside the wrapper, so that even
#                         `[[:print:]]*` — the narrowest class that survives the
#                         sweep above — is caught.
#   v(x1.x2.net5) etc     dotted hierarchy, bracketed bus, i()-wrapped, bare,
#                         `@m...[id]`, a name with a SPACE, and the empty name.
set GSO_NAMES [list \
  {v(out)} {v(l1)} {v(A)} {V(OUT)} {V(out)} \
  {v(a,b)} {v(out,outb)} {v(,)} \
  {v(vdd!)} {v(!)} {vdd!} \
  {v(net#1)} {net#1} {v(top.x1.sub.n#2)} \
  {v(x-y)} {x-y} \
  {v(x1.x2.net5)} {v(net_name[3])} {v(x[3:0])} \
  {v()} {v(a)x} {v(a)b} {xv(b)} {vx(y)} {(x)} {v(a(b))} {v((y))} {vv(a)} \
  {v(a b)} {v(a b!#$%&'*+,-./:;<=>?@[]^_{|}~)} "v(a\tb)" \
  {i(v1)} {I(V2)} {i(x1.v2)} {@m.x1.m1[id]} \
  {out} {Out} {OUT} {about} {x1.out} {time} {net1} {net5} {vv} {zz} {tmp} \
  {l1} {l2} {xl1} {a b} {}]

# THE PATTERN AXIS: anchored, unanchored, bracket/class, wildcard, quantifier,
# alternation, backreference, escape, case-varying, INVALID, and DIRECTOR forms.
#
# ⚠ DELIBERATE MATRIX BOUNDARY, declared rather than hidden: no pattern here
# STARTS WITH `-`. The legacy validity probe is `regexp $pattern {12345}` with
# no `--` (see gsl_frozen_ref), so a leading `-` is parsed there as a SWITCH and
# the legacy body widens to "show everything"; the new body passes the pattern
# as data (`sig_match` guards with `--`) and filters on it. That is a genuine
# third difference class, but it is an artefact of the legacy PROBE's missing
# `--`, not of the strip regsub or the wrap that this oracle exists to pin, and
# ruling 17 sanctions exactly two classes. It is recorded as a divergence in
# doc/claude/signal_browser_batch/receipts/03_round3_oracle.md §5; do not "fix"
# it by broadening gso_sanctioned. Hyphen
# MATCHING is still covered, by `[-]`, `\-` and `x-y` below.
set GSO_PATS [list \
  {} {out} {Out} {OUT} {v} {V} {i} {I} {net} {net5} {vv} {time} \
  {.} {.*} {.+} {^} {$} {^$} {^.*$} \
  {^out} {out$} {^out$} {^v} {v$} {^v\(} {v\(.*\)} {^v\(.*\)$} {^i\(} \
  {\(} {\)} {(} {)} {[} {]} "\{" "\}" "*" {+} {?} \
  {[0-9]} {[a-z]+} {[A-Z]} {[^,]*} {[-]} {\-} {,} {.*,.*} {#} {!} {\.} \
  {x1\.out} {a\.b} {x|y} {(a|b)} {time|net} {^(?:out)$} {(?:out)} \
  {\[} {\[3\]} {net\[0-9\]} {[[:alpha:]]+} {o.t} {a{2}} {{2}} \
  {(a)\1} {\1} {\y} {\A} {\Z} {\m} \
  {(?i)out} {(?i)OUT} {(?i)} {(?x)out} {***=out} {***:out} \
  {v\(a,b\)} {a,b} {x-y} {vdd} {net_name} {sub} {@m} {[3:0]}]

# Blobs: one per name (so a failure names the exact signal), plus the whole set
# in one blob and two ordering blobs (a single-name blob cannot see a sort or a
# sort/strip ORDER defect). Both `graph_sort` directions, so the sort mapping
# and the sort-before-strip contract are inside the oracle too.
set GSO_BLOBS {}
foreach gso_n $GSO_NAMES { lappend GSO_BLOBS [list $gso_n $gso_n] }
lappend GSO_BLOBS [list {<ALL NAMES>}  [join $GSO_NAMES \n]]
lappend GSO_BLOBS [list {<SORT aa/mm>} "v(aa)\nmm"]
lappend GSO_BLOBS [list {<SORT mixed>} "v(zz)\naa\nv(a)x\nxv(b)\nV(BB)"]

set gso_cmp 0 ; set gso_diff 0 ; set gso_a 0 ; set gso_b 0 ; set gso_bad {}
foreach gso_dir {1 0} {
  set ::graph_sort $gso_dir
  foreach gso_be $GSO_BLOBS {
    set gso_label [lindex $gso_be 0]
    set gso_blob  [lindex $gso_be 1]
    if {[catch {gsl_frozen_ref $gso_blob {}} gso_every]} {
      set gso_every "ORACLE-ERR:$gso_every"
    }
    foreach gso_pat $GSO_PATS {
      incr gso_cmp
      if {[catch {gsl_frozen_ref $gso_blob $gso_pat} gso_exp]} {
        set gso_exp "ERR:$gso_exp"
      }
      if {[catch {graph_get_signal_list $gso_blob $gso_pat} gso_got]} {
        set gso_got "ERR:$gso_got"
      }
      if {$gso_got eq $gso_exp} continue
      incr gso_diff
      switch -exact -- [gso_sanctioned $gso_pat $gso_got $gso_exp $gso_every] {
        a { incr gso_a }
        b { incr gso_b }
        default {
          lappend gso_bad "name={$gso_label} pat={$gso_pat} graph_sort=$gso_dir\
 got={$gso_got} exp={$gso_exp}"
        }
      }
    }
  }
}
set ::graph_sort 1

# The repro is printed, not just counted: whoever trips this gets the exact
# name/pattern/got/exp to paste into a one-liner, instead of a bare number.
if {[llength $gso_bad]} {
  puts "GSORACLE: [llength $gso_bad] UNSANCTIONED difference(s) out of $gso_cmp\
 comparisons. First [expr {[llength $gso_bad] > 8 ? 8 : [llength $gso_bad]}]:"
  foreach gso_b [lrange $gso_bad 0 7] { puts "  GSORACLE DIFF $gso_b" }
} else {
  puts "GSORACLE: $gso_cmp comparisons, $gso_diff differences, all sanctioned\
 (a=$gso_a decision-4 invalid-regexp, b=$gso_b ruling-16 director), 0 unexplained."
}

# GSO01 is THE check. Its `got` carries the first offending case so the FAIL
# line itself is a repro.
check {GSO01 differential oracle: ZERO unsanctioned legacy-vs-shipping differences} \
  [expr {[llength $gso_bad] ? [lindex $gso_bad 0] : 0}] 0
# GSO02-GSO04 stop the oracle from passing VACUOUSLY: a matrix that never ran, a
# loop that broke out early, or a sanctioned class that is never exercised (and
# so is never proved to be narrow) would otherwise all read as green.
check {GSO02 the matrix really ran, whole (>5000 comparisons, none skipped)} \
  [list [expr {$gso_cmp > 5000}] \
        [expr {$gso_cmp == 2 * [llength $GSO_BLOBS] * [llength $GSO_PATS]}]] \
  [list 1 1]
check {GSO03 sanctioned class (a) (decision 4) is actually exercised} \
  [expr {$gso_a > 0}] 1
check {GSO04 sanctioned class (b) (ruling 16 delta 3) is actually exercised} \
  [expr {$gso_b > 0}] 1
# GSO05 is the anti-tamper check: it pins a behaviour the frozen reference has
# and the shipping body deliberately does NOT (the legacy widening of an invalid
# regexp). Replace gsl_frozen_ref with a call to graph_get_signal_list — the
# cheapest way to make the oracle trivially green — and this fails instantly.
check {GSO05 the frozen oracle is the LEGACY body, not a call to the shipping one} \
  [list [gsl_frozen_ref "v(out)\nzz" {[}] [graph_get_signal_list "v(out)\nzz" {[}]] \
  [list [list out zz] {}]
# GSO06 stops a later "tidy" from quietly dropping a name class. Every entry
# here is a class that a green run once depended on being ABSENT.
set gso_missing {}
foreach gso_n [list {v(a,b)} {v(out,outb)} {v(vdd!)} {v(net#1)} {v(x-y)} \
                    {v(x1.x2.net5)} {v(net_name[3])} {i(v1)} {out} {} \
                    {v()} {(x)} {vx(y)} {v(a(b))} {v(a)x} {xv(b)} {V(OUT)} \
                    {vv(a)} {v(a b)} {v(a b!#$%&'*+,-./:;<=>?@[]^_{|}~)}] {
  if {[lsearch -exact $GSO_NAMES $gso_n] < 0} { lappend gso_missing $gso_n }
}
check {GSO06 the name axis still carries every required real-name class} \
  $gso_missing {}
set ::graph_sort 0

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
