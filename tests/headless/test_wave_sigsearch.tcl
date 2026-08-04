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
# and regexp arms carry two SEPARATE `-nocase` flags (wave_viewer.tcl:1571 and
# :1577), so deleting the regexp one alone makes RegExp-mode search
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
