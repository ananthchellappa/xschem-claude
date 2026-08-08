# Signal-search: the shared matcher and everything built on it
# (doc/claude/signal_browser_batch/PLAN.md items 1-7 — per settled decision 9
# this ONE file carries every item-1..7 check; each item APPENDS its group).
#
#   SM01-SM30  wviewer::sig_match — the shared matcher (item 1), plus TWO-PANE
#              item 20's `-key` option (SM29/SM30, appended in place after SM27).
#              Shape; shell `*` `?` `[range]` and the literal-bracket escape;
#              regexp WHOLE-NAME anchoring (SM04, the ViVA trap, see below);
#              case default vs -case 1 on BOTH syntax arms (shell SM09/SM10/SM11,
#              regexp SM27/SM25 — the default is checked per-arm because the two
#              arms carry SEPARATE -nocase flags in the implementation and one
#              can regress without the other); -type filtering
#              alone and combined with a pattern; empty pattern = everything on
#              both arms; an invalid regexp -> {err ...} and NOT the whole list;
#              -sort 0/1/-1; the shell default; a bad option throws.
#              SM28 is APPENDED OUT OF PLACE, at the bottom of the file beside
#              the BAR group, by item 4: settled decision 9 makes this file
#              append-only, and item 1's receipt §6 cross-references the name
#              `SM28`, so it keeps that name rather than a BAR one. It
#              discharges item 1's surviving mutation gap D8/U1 — dropping the
#              non-capturing group from the `^(?:$pat)$` wrap survived all 88
#              pre-item-4 checks.
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
#              over a generated 52-name x 94-pattern matrix (55 blobs — 52
#              single-name, the whole set, and 2 ordering blobs) x both sort
#              directions = 10,340 comparisons (whole file ~0.34 s), asserting
#              ZERO differences except the two SANCTIONED ones (decision 4's
#              invalid-regexp -> {}, and ruling 16 delta 3's ARE director ->
#              error), each excluded by its own narrow three-conjunct predicate.
#              This — not the GS fixtures — is what carries the coverage claim on
#              the strip regsub and the `.*(?:$pat).*` wrap. That claim is
#              BOUNDED, and the bound is measured, not asserted: ANY narrowing of
#              the capture that excludes a PRINTABLE ASCII character fails GSO01
#              — all 95 of them, swept one at a time. The residue it cannot see
#              is item 4 of the "WHAT THIS ORACLE STILL CANNOT SEE" list below.
#              Failures print the differing name/pattern/got/exp as a repro.
#              GSO02-GSO06
#              stop the oracle passing vacuously (matrix ran whole; both
#              sanctioned classes actually exercised; the frozen reference is
#              still the legacy body and not a call to the shipping one; the
#              required real-name classes are still present).
#   BAR01-BAR29 (+BAR18b, +BAR22b, no BAR25 — 30 checks; the two `b` names are
#              anti-vacuity guards, added because their partners were MEASURED
#              to pass without the code they claimed to pin; BAR27-BAR29 are the
#              same story a round later, added in the item-4 FIXUP after a
#              verifier measured three lines of shipped code that no check
#              touched; and BAR25 does not exist — see the ⚠ below)
#              `wviewer::searchbar` — the ViVA Search toolbar megawidget
#              (item 4, src/wave_viewer.tcl). REAL Tk widgets on three throwaway
#              toplevels: the child set and ViVA §3.2's pack order; the three
#              DEFAULTS pinned INDEPENDENTLY (type All / syntax Shell / case
#              OFF, one check each, one widget each — see the group header);
#              the `-showbutton 0` variant; the label->code mappers; the
#              callback contract (four args, mapped codes, reached from ALL
#              FOUR live routes — the KeyRelease binding, the Search button,
#              and a <<ComboboxSelected>> on EACH dropdown, plus the Match-case
#              checkbutton's -command — but NOT from a real X key press, see
#              below); decision 4's error label populating
#              VERBATIM from sig_match and clearing on the next valid
#              keystroke; that the label cannot resize the bar; the theme; that
#              a destroyed bar leaves no namespace state; and that a forget on a
#              still-LIVE bar detaches the checkbutton variable so a later
#              toggle cannot resurrect it.
#              ⚠ THERE IS NO BAR25. An end-to-end "a REAL generated KeyRelease
#              reaches the callback" check was written, soaked 8/8 green, and
#              then FAILED inside a full 283-test audit under load. It was
#              REMOVED, not made conditional: its only oracle is "did the
#              callback fire", which cannot distinguish a WSLg key-delivery
#              stall from a genuinely broken binding, so a self-skipping version
#              would mask the very regression it exists to catch. The claim is
#              narrowed to match: the handler and the binding are pinned
#              (BAR13+BAR14); end-to-end X key delivery is NOT.
#   AT01-AT23  the searchbar INSIDE the Add Trace dialog (item 5,
#              src/wave_viewer.tcl `wviewer::add_trace_dialog`). 20 checks on a
#              REAL dialog over the item-2 group's second xschem context. Two
#              halves: the PLAN's "do not redesign the dialog" regression guard
#              (every pre-existing child still at its contract path, the
#              renumbered grid rows 3-7 with no hole, the Graph combobox on BOTH
#              its arms, the Expression entry still winning focus, and the 0173
#              loan restored); and the filter itself (open = whole inventory,
#              shell pattern shrinks, cleared pattern grows back, invalid regexp
#              -> the BAR's label and NOT the dialog's while HOLDING the last
#              good list, the type dropdown, Match case, and the selection
#              surviving a repopulate by NAME rather than by index).
#              ⚠ THERE IS NO AT05, AT06 or AT15 — those names were never
#              written, nothing was deleted. The gap is inherited from the
#              plan's own numbering; do not go looking for removed checks.
#              ⚠ ROUTES, NOT VARIABLES (item 4's rejection lesson): AT09 drives
#              the Search button's -command, AT12 a real <<ComboboxSelected>>
#              and AT13 `$w.case invoke` — because `select` sets the variable
#              WITHOUT running -command. The <KeyRelease> leg is driven at
#              `searchbar_fire`, NOT by a generated key (see BAR25 below), so
#              end-to-end X key delivery into the dialog is NOT pinned either.
#              AT21 closes item 4's surviving verifier sabotage V-U2 (a THROWING
#              consumer callback lands in the bar's error label) — item 5 is the
#              first item that installs a real consumer, so it is the first that
#              can pin it.
#              ⚠ AT18 READS A FOCUS RECORD, AND A FOCUS RECORD NEEDS A MAPPED
#              TOPLEVEL. It sits behind `at_wait_mapped` (see the ⚠ there) and
#              asserts `ismapped` alongside the record. Do NOT "simplify" it back
#              to a bare `update` + `focus -lastfor`: that form failed 3 times in
#              22 solo runs and was repaired, not invented, in the item-5 FIXUP.
#   MS00-MS18  MULTI-SELECT ADD from the Add Trace dialog (item 6,
#              `wviewer::add_trace_ok`). 19 checks on a REAL dialog, over the
#              MAIN xschem context — NOT the AT group's, see the ⚠ FIXTURE note
#              at the group head (the AT token's win_path is a TAB, and
#              `add_trace` -> `regenerate` -> `viewport_rect` throws on it).
#              An empty Expression adds ONE TRACE PER SELECTED ROW in listbox
#              order, observed through three independent oracles (the model's
#              `vec` list, the trace colors, and the graph rect's `node` text on
#              the CANVAS); a typed Expression still wins and still adds exactly
#              one; the Name field is refused for N>1 with a verbatim contract
#              string and applies at exactly N=1; and the first error aborts the
#              rest while the already-added traces STAY — a DELIBERATE
#              NON-rollback (PLAN item 6), whose message must therefore say how
#              far it got.
#              ⚠ MS01 PINS THE PREMISE OF "LISTBOX ORDER" — that `curselection`
#              answers in DISPLAY order, not click order — so MS03 can assert a
#              hand-written literal instead of recomputing its expectation from
#              the very selection it set. Do not "simplify" MS03 into a loop
#              over `curselection`: that asserts the list against itself.
#              ⚠ EVERY SCENARIO OPENS ITS OWN DIALOG. A successful multi-add
#              DESTROYS the dialog, so a shared handle turns any sabotage that
#              changes the success/refuse verdict into a file-wide abort.
#
# ⚠ THE BAR, AT **AND MS** GROUPS ARE DISPLAY-ARM ONLY — 68 of this file's 158
# checks. They self-skip without X, so the `--nogui` repro below exercises
# NONE of items 4, 5 and 6: a green `--nogui` run (90 checks) proves nothing
# about the search bar, the Add Trace filter OR the multi-select add, and a
# maintainer debugging there must not read it as coverage. `full_audit.sh` runs
# this file in the DISPLAY arm (it is not in `nogui_tests`), so audit coverage
# is real.
# The skip banners are worded `SKIPPED: <group> group (Tk/X arm only)` ON PURPOSE:
# `full_audit.sh:109 is_skip()` matches `RESULT: SKIP`, `skipped: no X` and
# `SKIP: no X connection` ANYWHERE in the output and runs BEFORE `is_pass`, so
# any of those three spellings would score this whole 158-check suite as SKIP
# and silently discard every item-1/2/3 check with it.
#
# Standalone repro (SM/ST/SB/SL/GS/GSO are `--nogui`-safe; BAR is not):
#   ./src/xschem --pipe -q --nolog --nogui --script tests/headless/test_wave_sigsearch.tcl
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_wave_sigsearch.tcl
#
# bgerror IS overridden (below), as the NOTE that stood here for items 4-7 asked
# for: item 4 builds real widgets with real bindings, and a Tcl error reaching
# background level pops a MODAL bgerror dialog under X and HANGS the run. The
# override swallows it, prints it and COUNTS IT AS A FAILURE — the only
# formulation that can neither hang nor hide.
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
# The item-4 group leaves NO widget state: all three throwaway toplevels
# (`.wvsb1`, `.wvsb2`, `.wvsb3`) are destroyed and `::barargs` is unset at group
# end, and BAR24 is the check that a destroyed bar drops its
# `::wviewer::sbcfg` / `sbcase` entries. It DOES leave `::bgerror` overridden
# (items 5-7 want it) and the proc `barcb` defined — there are no `bar_*` helper
# procs any more, `bar_send_key` went with BAR25.
# The item-5 group likewise leaves NO widget state (`.wvat1`/`.wvat2`/`.wvat3`
# destroyed, the `wvat` and `wvat_noraw` entries dict-unset from
# `::wviewer::windows` / `::wviewer::layouts`, and AT19 is the check that a
# closed dialog drops `::wviewer::atdsigs`), and it ends by switching the
# context back to $SLMAIN. It DOES leave the procs `at_open`, `at_lb` and
# `at_throwcb` defined: item 6 appends to this file and reuses the same dialog
# fixture. It creates NO third xschem context — AT23's no-raw arm gets its empty
# inventory from signal_list's landmine-17 refusal, not from a new window.
# The item-6 group is the FIRST that really DRAWS, so it leaves the most behind
# and ITEM 7 INHERITS IT. It EXTENDS the MAIN context's `sl_main.raw` from 2
# vectors to 10 — the 7 SLFIX names plus `db1`, materialized by the RPN check —
# and it does NOT `raw new` (that would drop `wrong_ctx_var`, which SL12 above
# still names in this same process). `regenerate` draws graph rects into the
# MAIN schematic and `with_edit` leaves it `readonly 1`; the group's teardown
# switches back to $SLMAIN, clears readonly, clears the drawing and clears the
# modify flag, and MS18 is the check that it really did (rects=0, readonly=0).
# The raw stays extended — that is deliberate and cannot be undone in place.
# `.wvms1` is destroyed and the `wvms` entries are dict-unset from
# `::wviewer::windows` / `::wviewer::layouts`; it leaves the procs `ms_open` and
# `ms_field` defined, and the globals `MSALL` / `MSREF`. It creates NO third
# xschem context either.
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

# bgerror override (item 4). REQUIRED from here on: the BAR group builds real Tk
# widgets with real bindings, and any error that escapes to background level
# would pop the stock bgerror dialog — MODAL under X, which HANGS a headless
# run. Swallow it, print it, and COUNT IT AS A FAILURE: a silent swallow would
# hide a defect, a re-throw would hang, and only this shape does neither.
proc ::bgerror {msg} { puts "BGERROR: $msg"; incr ::fail }

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

# --- SM29/SM30 — `-key`, item 20's ONE new option -----------------------------
#
# ⚠⚠ WHY AN OPTION AND NOT A REWRITE. `GSO01`-`GSO06` below is a differential
# property oracle: a FROZEN copy of the pre-retrofit `graph_get_signal_list` run
# against the live one over 52 names x 94 patterns x 2 sorts = 10,340
# comparisons with ZERO permitted differences. Any SEMANTIC change inside
# `sig_match` reds it. An option that defaults to identity is not one — and
# these two checks are what say so from this side, while GSO01 says it from the
# other. The bars needed a different match SUBJECT; giving the matcher a key and
# leaving every existing caller alone is the cheapest true statement of that.
#
# THE CONTRACT, in three parts, and all three are pinned below because a break
# in any one of them is silent:
#   1. `-key {}` (and NO -key at all) is the IDENTITY;
#   2. the pattern is applied to `key(element)`;
#   3. the ORIGINAL element is what comes back — never the transformed one.
# (3) is the one with teeth: return the key's output and every gesture
# downstream gets a string that is not in the raw file. Measured as item 11's
# S3, 26 reds over two files.
proc sm_upper {n} { return [string toupper $n] }
check {SM29 -key defaults to the IDENTITY — omitted and `{}` are the same answer, and it is the un-keyed answer} \
  [list [lindex [sig_match $SIGS {l*}] 1] \
        [lindex [sig_match $SIGS {l*} -key {}] 1]] \
  [list [list l1 l2] [list l1 l2]]
check {SM29 the pattern is applied to key(element) — a pattern that matches NO element matches every one of their transforms} \
  [lindex [sig_match $SIGS {L*} -key sm_upper -case 1] 1] [list l1 l2]
check {SM29 ...and the SAME pattern with no key matches nothing, so the key is what did it} \
  [lindex [sig_match $SIGS {L*} -case 1] 1] [list]
check {SM29 (THE TEETH) the ORIGINAL element comes back, never the key's output} \
  [lindex [sig_match {v(out)} {V(OUT)} -key sm_upper -case 1] 1] [list v(out)]
# The real key item 20 ships, exercised here rather than only through the bars:
# the composition browser_label(signal_entry(name)) is what the lower pane draws.
check {SM29 (THE SHIPPED KEY) browser_label_of makes the pane's own label the subject, and `net*` — worth 0 against these raw names — finds the two it draws} \
  [list [lindex [sig_match {v(x1.net1) v(x1.net2) v(out)} {net*}] 1] \
        [lindex [sig_match {v(x1.net1) v(x1.net2) v(out)} {net*} \
                  -key wviewer::browser_label_of] 1]] \
  [list {} {v(x1.net1) v(x1.net2)}]
# ⚠⚠ -type IS NOT KEYED, AND THAT IS A RULING. `sig_type` reads the `v(` / `i(`
# prefix, which the label deliberately destroys — `i(v1)` renders `v1:i`, whose
# sig_type is `other`. Key the type filter too and Voltage/Current select
# NOTHING. Both directions are asserted: the type still finds its names under a
# key, and the label the key produces would NOT have satisfied it.
check {SM30 -type is applied to the RAW element even when -key is given} \
  [lindex [sig_match {v(out) i(v1) net1} {*} -key wviewer::browser_label_of -type i] 1] \
  [list i(v1)]
check {SM30 (THE OTHER DIRECTION) the label that element produced is type `other`, so a keyed type filter would have dropped it} \
  [list [wviewer::browser_label_of {i(v1)}] \
        [wviewer::sig_type [wviewer::browser_label_of {i(v1)}]] \
        [wviewer::sig_type {i(v1)}]] \
  [list {v1:i} other i]

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
check {SB07 sig_split @m.x1.m1[id] -> {x1 m1[id]}, the class tag STRIPPED} \
  [::wviewer::sig_split {@m.x1.m1[id]}] [list x1 {m1[id]}]
check {SB08 sig_split v(net_name[3]) -> empty path, bracketed leaf} \
  [::wviewer::sig_split {v(net_name[3])}] [list {} {net_name[3]}]

check {SB10 signal_entry key set is exactly class/leaf/name/path/type} \
  [lsort [dict keys [::wviewer::signal_entry {v(x1.x2.net5)}]]] \
  [list class leaf name path type]
# decision 2: `name` is the FULL raw name, never the bare/stripped form
check {SB11 signal_entry name is the FULL raw name} \
  [dict get [::wviewer::signal_entry {v(x1.x2.net5)}] name] {v(x1.x2.net5)}
# `type` must come from sig_type, case arm included — not a private re-impl
check {SB12 signal_entry type comes from sig_type (i(v1) and I(V2))} \
  [list [dict get [::wviewer::signal_entry {i(v1)}] type] \
        [dict get [::wviewer::signal_entry {I(V2)}] type]] [list i i]

# --- GROUP DC: sig_declass + the `class` field (issue 0217, spec §3) ----------
#
# ngspice tags a signal with a DEVICE-CLASS prefix -- and only when the object
# lives INSIDE a subcircuit. `v(m.x1.x1.xm1.msky…#body)` means "the MOSFET-class
# object at design path x1.x1.xm1"; the leading `m.` is a namespace tag bolted
# on the front, not a hierarchy level. Measured across 22 real ngspice-46 raws:
# 2026 of 2338 hierarchical signals -- 87% -- sat under a fake root before this.
#
# ⚠ THE RULE IS SOUND BY SPICE GRAMMAR, NOT BY HEURISTIC, and DC12 is what pins
# that: a hierarchy level comes from a SUBCIRCUIT INSTANCE, and SPICE requires
# those to begin with `X`. A one-letter segment therefore CANNOT be a subckt
# instance. Corroborated over the corpus: all 85 distinct real path segments
# start with `x`; every fake root matches `^@?[a-z]$`; zero overlap.
#
# ⚠ `pcall`, not a bare call: before the proc exists these must report
# `ERR:invalid command name` as an ASSERTABLE VALUE. An unguarded throw would
# hit the file's outer catch and silently abort every later check while the
# printed fail count still looked plausible (the lesson of the batch's worst
# testing bug -- see the header of test_wave_sigbrowser.tcl).

# The eight tags observed in the corpus, with their measured counts:
#   m 1400 · @m 360 · v 155 · @c 61 · @r 24 · @b 15 · @q 10 · n 1  = 2026
check {DC01 sig_declass strips the `m` tag (1400 corpus signals)} \
  [pcall ::wviewer::sig_declass {m.x1.x1.xm1.msky130_fd_pr__nfet_01v8#body}] \
  [list m {x1.x1.xm1.msky130_fd_pr__nfet_01v8#body}]
check {DC02 sig_declass strips the `v` tag -- an internal source branch} \
  [pcall ::wviewer::sig_declass {v.x1.v1}] [list v {x1.v1}]
check {DC03 sig_declass strips the `n` tag (1 corpus signal)} \
  [pcall ::wviewer::sig_declass {n.xu1.n1#flow(out)}] [list n {xu1.n1#flow(out)}]
check {DC04 sig_declass strips the `@m` tag} \
  [pcall ::wviewer::sig_declass {@m.x1.xm1.msky130_fd_pr__nfet_01v8[id]}] \
  [list @m {x1.xm1.msky130_fd_pr__nfet_01v8[id]}]
check {DC05 sig_declass strips the `@c` tag} \
  [pcall ::wviewer::sig_declass {@c.x1.c1[i]}] [list @c {x1.c1[i]}]
check {DC06 sig_declass strips the `@r` tag} \
  [pcall ::wviewer::sig_declass {@r.x2.xr4.r0[i]}] [list @r {x2.xr4.r0[i]}]
check {DC07 sig_declass strips the `@b` tag} \
  [pcall ::wviewer::sig_declass {@b.x1.b1[ic]}] [list @b {x1.b1[ic]}]
check {DC08 sig_declass strips the `@q` tag} \
  [pcall ::wviewer::sig_declass {@q.x1.q1[ib]}] [list @q {x1.q1[ib]}]

# ⚠ SABOTAGE (a)'s ORACLE -- the `>= 2 following segments` guard. `m.foo` is
# AMBIGUOUS: stripping it would leave an EMPTY path and file a signal at the
# root that belongs one level down. Drop the guard and this check fails.
check {DC09 sig_declass does NOT strip with only ONE following segment} \
  [pcall ::wviewer::sig_declass {m.foo}] [list {} {m.foo}]
# ...and its POSITIVE CONTROL on the same fixture shape: add one more segment
# and it DOES strip. Without this pair, DC09 would also pass on a proc that
# never strips anything at all.
check {DC09 positive control -- ONE more segment and it strips} \
  [pcall ::wviewer::sig_declass {m.foo.bar}] [list m {foo.bar}]

check {DC10 sig_declass leaves a name with NO tag alone} \
  [pcall ::wviewer::sig_declass {x1.x2.net5}] [list {} {x1.x2.net5}]
check {DC11 sig_declass leaves a DOTLESS name alone} \
  [pcall ::wviewer::sig_declass {net1}] [list {} net1]

# ⚠ SABOTAGE (b)'s ORACLE. ngspice lowercases, but a hand-written or foreign
# raw need not, and a case-SENSITIVE match would silently pass the tag through
# as a hierarchy level -- the exact defect, one case-fold away.
check {DC12 sig_declass is CASE-INSENSITIVE on the tag} \
  [pcall ::wviewer::sig_declass {M.X1.X2.FOO}] [list M {X1.X2.FOO}]
check {DC12 positive control -- the lowercase twin strips identically} \
  [lindex [pcall ::wviewer::sig_declass {m.x1.x2.foo}] 0] m

# ⚠ SABOTAGE (c)'s ORACLE -- the rule must NOT over-reach. `xm1` is a REAL
# pcell wrapper instance; strip two-letter heads and every real design path
# loses its first level. This is the check that proves the SPICE-grammar
# argument rather than merely asserting it.
check {DC13 sig_declass does NOT strip a TWO-letter head (a real instance)} \
  [pcall ::wviewer::sig_declass {xm.x1.foo}] [list {} {xm.x1.foo}]
check {DC13 positive control -- the ONE-letter twin DOES strip} \
  [pcall ::wviewer::sig_declass {x.x1.foo}] [list x {x1.foo}]

# Leaf shapes that must survive the strip untouched. `#`, `[..]` and `(..)`
# all appear in real corpus leaves; the longest measured leaf is 54 chars.
check {DC14 a `#` leaf survives the strip} \
  [lindex [pcall ::wviewer::sig_declass {m.x1.xm1.mod#dbody}] 1] {x1.xm1.mod#dbody}
check {DC15 a bracketed leaf survives the strip} \
  [lindex [pcall ::wviewer::sig_declass {@m.x1.xm1.mod[gm]}] 1] {x1.xm1.mod[gm]}
check {DC16 a PARENTHESISED leaf survives the strip} \
  [lindex [pcall ::wviewer::sig_declass {n.xu1.n1#flow(out)}] 1] {xu1.n1#flow(out)}

# sig_split routes through sig_declass. SB07 pins the @m case; these pin that
# the WRAPPER is unwrapped FIRST and the strip happens on the bare form.
check {DC17 sig_split unwraps THEN declasses} \
  [pcall ::wviewer::sig_split {v(m.x1.x1.xm1.mod#body)}] \
  [list {x1.x1.xm1} {mod#body}]
check {DC18 sig_split on i(v.x1.v1) -> path x1, leaf v1} \
  [pcall ::wviewer::sig_split {i(v.x1.v1)}] [list x1 v1]
# ⚠ the DEPTH the fake tag was inflating: 5 segments read as hierarchy before,
# 4 after. Any depth-based assertion elsewhere shifts by exactly one.
check {DC19 sig_split drops the fake level -- depth 4, not 5} \
  [llength [split [lindex [pcall ::wviewer::sig_split \
     {v(m.x1.x1.x1.xm1.msky130_fd_pr__nfet_01v8#body)}] 0] .]] 4

# --- the `class` field -------------------------------------------------------
#
# ⚠ THE CLASSIFIER KEYS ON THE STRIPPED TAG, NEVER ON THE LEAF'S SHAPE, and
# DC25 is the check that forces it. 0217:44 records "100% of device leaves
# contain `#`" -- true FORWARD, FALSE BACKWARD: six REAL design nets end in `#`
# (xschem's auto-generated net names, e.g. v(x2.x1.a_27_47#) in tb_charge_pump).
# A classifier keyed on "the leaf contains #" misfires on every one of them.
proc dc_class {n} { pcall dict get [pcall ::wviewer::signal_entry $n] class }

check {DC20 class of a plain design net is `net`}        [dc_class {v(x1.adj)}]  net
check {DC21 class of a TOP-LEVEL source current is `net`} [dc_class {i(v1)}]      net
check {DC22 class of a device internal node is `devnode`} \
  [dc_class {v(m.x1.xm1.msky130_fd_pr__nfet_01v8#body)}] devnode
check {DC23 class of a device measurement is `devmeas`} \
  [dc_class {i(@m.x1.xm1.msky130_fd_pr__nfet_01v8[id])}] devmeas
check {DC24 class of an internal source branch current is `srcbranch`} \
  [dc_class {i(v.x1.v1)}] srcbranch
# ⚠ THE BACKWARD TRAP, measured on the real corpus.
check {DC25 a REAL design net ending in `#` is `net`, NOT devnode} \
  [dc_class {v(x2.x1.a_27_47#)}] net
check {DC25 positive control -- the same leaf shape WITH a tag is devnode} \
  [dc_class {v(m.x2.x1.a_27_47#)}] devnode
# the `n` tag is the other internal-node class
check {DC26 the `n` tag also classifies devnode} \
  [dc_class {v(n.xu1.n1#flow(out))}] devnode
# a tagless dotless name is a top-level net, whatever its type
check {DC27 class of a bare top-level net is `net`} [dc_class {v(vbg)}] net
check {DC28 class of the sweep variable is `net` (M8: not special-cased)} \
  [dc_class {time}] net

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
#   * COVERAGE IS CARRIED BY GSO01 (the differential property oracle below),
#     and by nothing in this block. Every one of those seven mutations, plus
#     `v`->`v+`, `[^ ]*`, `[[:print:]]*`, `[vV]`, `-nocase`, and the two anchors,
#     now fails GSO01 with a printed repro. GSO01's coverage of the capture is
#     BOUNDED and the bound is MEASURED: any narrowing that excludes a printable
#     ASCII character fails it — all 95 swept individually as `(.*)` -> `([^c]*)`,
#     95/95 caught. It does NOT extend past printable ASCII; see item 4 of the
#     oracle's "WHAT THIS ORACLE STILL CANNOT SEE" list. Do not restore the word
#     "COMPLETE" here — that was the false claim this block was rewritten to kill,
#     and it was re-committed once already in 5f1de36a on an axis that was missing
#     `"`, `\` and backtick.
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
#                  every narrowing that excludes a PRINTABLE ASCII character —
#                  measured, all 95 swept one at a time, 95/95 caught — via a
#                  name axis carrying a comma, a bang, a hash, a hyphen, a space,
#                  a tab, a nested paren, empty content, an all-32-character
#                  ASCII punctuation sweep and an all-62-character alphanumeric
#                  sweep. It does NOT catch a narrowing that excludes only
#                  characters OUTSIDE printable ASCII; that residue is item 4 of
#                  the oracle's "WHAT THIS ORACLE STILL CANNOT SEE" list, and
#                  ruling 17 deliberately withdrew chasing it.
#                  ⚠ As committed in 5f1de36a this sentence read "a full
#                  printable-punctuation sweep" while the sweep name was in fact
#                  missing `"`, `\` and backtick — so it green-lit exactly the
#                  "maintainer tidies `(.*)` into an explicit class and ships the
#                  regression" scenario ruling 17 named, on the authority of a
#                  property the oracle did not have. `[^\\]*`, `[^"]*` and
#                  ``[^`]*`` each changed real behaviour (review measured 150, 84
#                  and 104 differing cells) yet stayed 88/88 GREEN. Re-measured
#                  after widening the axis: each now FAILS GSO01 with 144
#                  unsanctioned differences and a printed repro.
#                  If you widen or trim the axis, RE-MEASURE this claim; do not
#                  reason about it.
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
# That is far stronger than any finite fixture set: a behaviour-changing mutation
# of `graph_get_signal_list` — the strip regsub, the `.*(?:$pat).*` wrap, the sort
# mapping, the split, the err arm — fails GSO01 automatically as soon as the
# matrix contains one cell that distinguishes it, including mutations nobody
# thought of. The GS fixtures are KEPT because they NAME the defect (GS17 tells
# you WHICH part broke; GSO01 only tells you that something did, plus the exact
# repro), but the COVERAGE claim now rests here and nowhere else. See the
# GS17-GS21 map above, which is explicitly labelled as a naming aid and NOT as a
# complete part->check map.
#
# ⚠ "EVERY behaviour-changing mutation" IS THE WRONG WORD AND IT WAS COMMITTED
# ONCE (5f1de36a). An oracle is only as wide as its axes: a mutation the matrix
# cannot distinguish passes, however real it is. The capture's bound is stated
# and measured — every narrowing excluding a printable ASCII character fails,
# 95/95 swept — and the part it does NOT reach is item 4 below. Say "fails GSO01"
# of things you have MEASURED failing GSO01; the whole reason this oracle exists
# is that the previous unmeasured completeness claim was false.
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
#  4. A capture narrowing that excludes ONLY characters outside printable ASCII.
#     The name axis sweeps all 95 printable ASCII characters (0x20-0x7E) through
#     the wrapper, so every `(.*)` -> `([^c]*)` for printable c fails GSO01 —
#     measured, 95/95. Beyond that the axis carries exactly ONE non-printable, a
#     TAB, which is what kills `[[:print:]]*`. So a narrowing that admits every
#     printable character and TAB but excludes, say, a newline, a NUL, a control
#     character or a non-ASCII/UTF-8 byte would still pass. This is the finite-axis
#     regress DRIVER RULING 17 deliberately withdrew — the mutation space of a
#     regex is unbounded, so "find a green mutation" always eventually succeeds
#     and has no fixed point. It is recorded as the honest residue, NOT as a bug
#     and NOT as work: do not open a round to chase it. If a real `.raw` is ever
#     found emitting such a name, THAT is the trigger to widen the axis.
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
#   v(a b!"#$%...)        the PUNCTUATION SWEEP — all 32 ASCII punctuation
#   v(0123..zA..Z)        characters, and the ALPHANUMERIC SWEEP — all 62 letters
#                         and digits. Together with the space in the first name
#                         these two cover all 95 printable ASCII characters
#                         (0x20-0x7E) inside a wrapper, which is what makes the
#                         bounded claim TRUE: any narrowing of the capture that
#                         excludes a printable ASCII character fails GSO01.
#                         MEASURED, not reasoned: `(.*)` -> `([^c]*)` was swept
#                         for all 95 c, 95/95 caught.
#                         ⚠ DO NOT "CLEAN UP" EITHER NAME. As committed in
#                         5f1de36a the punctuation name was missing `"`, `\` and
#                         backtick — no other name carried them — so `[^"]*`,
#                         `[^\\]*` and ``[^`]*`` changed real behaviour and stayed
#                         88/88 GREEN, while six comments called the sweep
#                         complete. The alphanumeric name was added for the same
#                         reason: without it 40 narrowings (`[^q]*`, `[^Z]*`, `[^7]*`
#                         …) stayed green, because no wrapped name contained
#                         those characters. If you touch either, re-run the
#                         95-character sweep — the claim is only as good as the
#                         last time somebody measured it.
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
  {v(a b)} {v(a b!"#$%&'*+,-./:;<=>?@[\]^_`{|}~)} "v(a\tb)" \
  {v(0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ)} \
  {i(v1)} {I(V2)} {i(x1.v2)} {@m.x1.m1[id]} \
  {out} {Out} {OUT} {about} {x1.out} {time} {net1} {net5} {vv} {zz} {tmp} \
  {l1} {l2} {xl1} {a b} {}]

# THE PATTERN AXIS: anchored, unanchored, bracket/class, wildcard, quantifier,
# alternation, backreference, escape, case-varying, INVALID, and DIRECTOR forms.
#
# LEADING-HYPHEN PATTERNS ARE IN THE MATRIX, and the "third difference class"
# that once excluded them DOES NOT EXIST. As committed in 5f1de36a this spot
# carried a "⚠ DELIBERATE MATRIX BOUNDARY" block asserting that no pattern may
# start with `-`, on the premise that the legacy validity probe
# `regexp $pattern {12345}` lacks `--`, so a leading hyphen is parsed there as a
# SWITCH and the legacy body throws / widens to "show everything". THAT PREMISE
# IS FALSE, and it cost the oracle a whole pattern class. Tcl 8.6.14, measured:
#
#   regexp $p {12345}      p = - -- -nocase -zz -line -all -x -expanded -a- -.*
#                          -> err=0, result 0, for EVERY one of them.
#   regexp -nocase {12345} (the same word as a LITERAL)  -> error, wrong # args
#   regexp {*}$p {12345} / eval regexp ...                -> error, bad option
#
# i.e. switch parsing happens for a LITERAL option word, or when the command is
# re-dispatched at runtime by `eval` / `{*}` expansion — NOT for a pattern
# arriving through a variable inside a compiled proc, which is exactly how both
# `gsl_frozen_ref` and the shipping body spell it. Differentially measured on
# the blob "v(x-y)\nzz\nv(out)\n-lead\nv(-a-)", 10 leading-hyphen patterns x
# both sort directions = 20 comparisons: ZERO differences; pattern `-` returns
# {-lead -a- x-y} from BOTH bodies. There is no third class, there is no driver
# decision owed, and `gso_sanctioned` stays at exactly the two classes ruling 17
# sanctions. Putting these patterns in ADDS coverage the oracle was forgoing.
#
# THE PATTERN AXIS: anchored, unanchored, bracket/class, wildcard, quantifier,
# alternation, backreference, escape, case-varying, LEADING-HYPHEN, INVALID, and
# DIRECTOR forms.
set GSO_PATS [list \
  {} {out} {Out} {OUT} {v} {V} {i} {I} {net} {net5} {vv} {time} \
  {.} {.*} {.+} {^} {$} {^$} {^.*$} \
  {^out} {out$} {^out$} {^v} {v$} {^v\(} {v\(.*\)} {^v\(.*\)$} {^i\(} \
  {\(} {\)} {(} {)} {[} {]} "\{" "\}" "*" {+} {?} \
  {[0-9]} {[a-z]+} {[A-Z]} {[^,]*} {[-]} {\-} {,} {.*,.*} {#} {!} {\.} \
  {x1\.out} {a\.b} {x|y} {(a|b)} {time|net} {^(?:out)$} {(?:out)} \
  {\[} {\[3\]} {net\[0-9\]} {[[:alpha:]]+} {o.t} {a{2}} {{2}} \
  {(a)\1} {\1} {\y} {\A} {\Z} {\m} \
  {-} {--} {-nocase} {-all} {-line} {-zz} {-x} {-out} {-.*} {-a-} \
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
#
# ⚠ THE LOOP VARIABLE IS `gso_line`, NOT `gso_b`, AND THAT IS LOAD-BEARING. It
# was `gso_b` as committed in 5f1de36a, which is the class-(b) exercised COUNTER
# that GSO04 asserts on. On any FAILING run this loop overwrote the counter with
# a string like `name={v(a,b)} pat={} ...`; GSO04's `expr {$gso_b > 0}` then
# resolved by STRING comparison, yielded 1, and printed "ok" — so the
# anti-vacuity check went vacuous in exactly the state a reader is inspecting it.
# Measured before the rename (capture `(.*)` -> `([^,]*)` injected): GSO01 FAILED
# while GSO02-GSO06 all printed "ok". The DECISIVE measurement, which is what
# proves the rename is a fix and not a tidy: with the director patterns also
# removed from GSO_PATS so class (b) is exercised ZERO times, the old `gso_b`
# spelling still printed `ok: GSO04`, while `gso_line` correctly FAILS it with
# `{0} (exp {1})`. Do not reuse a counter name here.
if {[llength $gso_bad]} {
  puts "GSORACLE: [llength $gso_bad] UNSANCTIONED difference(s) out of $gso_cmp\
 comparisons. First [expr {[llength $gso_bad] > 8 ? 8 : [llength $gso_bad]}]:"
  foreach gso_line [lrange $gso_bad 0 7] { puts "  GSORACLE DIFF $gso_line" }
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
                    {vv(a)} {v(a b)} {v(a b!"#$%&'*+,-./:;<=>?@[\]^_`{|}~)} \
                    {v(0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ)}] {
  if {[lsearch -exact $GSO_NAMES $gso_n] < 0} { lappend gso_missing $gso_n }
}
check {GSO06 the name axis still carries every required real-name class} \
  $gso_missing {}
set ::graph_sort 0

# --- item 4: wviewer::searchbar — the ViVA Search toolbar megawidget ---------
# PLAN item 4 (PIXEL). Two of the three things the item asks a human to eyeball
# ARE convertible to checks and are converted here — the widget ORDER (BAR03,
# `pack slaves` is exactly what the eye reads left-to-right) and "the error
# label does not resize the bar" (BAR21, `winfo reqwidth` across a 200-char
# message). BAR22+BAR22b pin the theme hookup. What is NOT convertible, and is
# therefore still owed to the human queue: the SPACING as it looks (BAR03 proves
# order, not that no two widgets touch) and the LEGIBILITY of the dark-red
# message and the Match-case indicator against the #f2f2f2 panel.
#
# ⚠ THE DEFAULTS ARE PINNED ONE CHECK PER WIDGET, ON PURPOSE (item 3's P2
# lesson). BAR04 reads ONLY `$w.type get`, BAR05 ONLY `$w.syntax get`, BAR06
# ONLY `sbcase($w)`; every OTHER check that depends on a selector sets it
# explicitly first. That is what makes the named sabotage (syntax default ->
# RegExp) fail BAR05 and nothing else. A "searchbar_get at defaults" check was
# deliberately NOT written: it would duplicate BAR04-06 and hand each of those
# three sabotages a second target.

# SM28 belongs to item 1's group and is appended HERE only because settled
# decision 9 makes this file append-only; it keeps the name item 1's receipt §6
# cross-references. It discharges item 1's D8/U1 gap: dropping the non-capturing
# group from sig_match's `^(?:$pattern)$` wrap (wave_viewer.tcl:1573) survived
# all 88 pre-item-4 checks. An ALTERNATION is what separates them — `^(?:out|l1)$`
# is anchored as a whole and takes `l1` alone, while `^out|l1$` binds `^` to the
# first branch and `$` to the last, so it also takes anything ENDING in l1
# (`xl1`). PURE: it runs in the --nogui arm too.
check {SM28 regexp arm anchors an ALTERNATION as a whole} \
  [lindex [sig_match $SIGS {out|l1} -syntax regexp] 1] [list l1]

# BAR12 is the label->code vocabulary. PURE (no Tk), so it too runs in BOTH
# arms and sits outside the X guard. It sweeps the WHOLE table plus the
# fallbacks, because a mapper that is right for three of four labels is a bug
# that only shows up for the user who picks the fourth.
check {BAR12 sb_type_code / sb_syntax_code map the whole label table} \
  [list [wviewer::sb_type_code All] [wviewer::sb_type_code Voltage] \
        [wviewer::sb_type_code Current] [wviewer::sb_type_code Other] \
        [wviewer::sb_type_code zzz] \
        [wviewer::sb_syntax_code Shell] [wviewer::sb_syntax_code RegExp] \
        [wviewer::sb_syntax_code zzz]] \
  [list all v i other all shell regexp shell]

if {[info exists ::has_x] && [info commands winfo] ne {}} {

  # the recorder: the LAST callback invocation, verbatim
  set ::barargs {}
  proc barcb {args} { set ::barargs $args }

  # distinctive toplevel names: this process already carries a second xschem
  # context (`.x1.drw`, left by the item-2 group), so nothing here may assume a
  # pristine widget tree.
  destroy .wvsb1 .wvsb2
  toplevel .wvsb1
  wm title .wvsb1 {item4 searchbar}
  wm geometry .wvsb1 +60+60
  update
  set w [wviewer::searchbar_build .wvsb1 -command barcb]
  # THE CONTRACT RETURNS AN UNMANAGED FRAME — geometry management is the
  # consumer's (item 5 grids it into a dialog, item 8 packs it above the tree).
  # The test must therefore pack it itself, and not only for looks: an unpacked
  # frame is UNMAPPED, its entry is unmapped with it, and `focus -force` on an
  # unmapped window silently leaves the focus on the toplevel — which is exactly
  # why BAR25 could never see a generated key until this line existed.
  pack $w -fill x
  update

  check {BAR01 searchbar_build returns the frame path, and it is a Frame} \
    [list $w [winfo exists $w] [winfo class $w]] [list .wvsb1.wvsearch 1 Frame]

  set barkids {}
  foreach c {type pat syntax case search err} {
    lappend barkids [winfo exists $w.$c]
  }
  check {BAR02 the six children exist under the contract names} \
    $barkids [list 1 1 1 1 1 1]

  check {BAR03 pack order is ViVA §3.2's: type pat syntax case search err} \
    [pack slaves $w] \
    [list $w.type $w.pat $w.syntax $w.case $w.search $w.err]

  # --- the three defaults, one widget each (see the group header) ---
  check {BAR04 type dropdown default is All} [$w.type get] All
  check {BAR05 syntax dropdown default is Shell} [$w.syntax get] Shell
  check {BAR06 Match case default is OFF} $::wviewer::sbcase($w) 0

  check {BAR07 the type dropdown offers exactly All Voltage Current Other} \
    [$w.type cget -values] [list All Voltage Current Other]
  check {BAR08 the syntax dropdown offers exactly Shell RegExp} \
    [$w.syntax cget -values] [list Shell RegExp]
  check {BAR09 the pattern entry starts empty} [$w.pat get] {}

  # the Filter-bar variant: the button is NOT CREATED, not merely unpacked, so
  # `winfo exists` is a truthful test of which variant a consumer got
  toplevel .wvsb2
  wm geometry .wvsb2 +80+240
  set w2 [wviewer::searchbar_build .wvsb2 -command barcb -showbutton 0]
  pack $w2 -fill x
  check {BAR10 -showbutton 0 omits the button and keeps the other five} \
    [list [winfo exists $w2.search] [pack slaves $w2]] \
    [list 0 [list $w2.type $w2.pat $w2.syntax $w2.case $w2.err]]

  # --- the callback contract ---
  # BAR13 asserts the BINDING SHAPE only. Together with BAR14 (the handler's
  # behaviour when that script is run) it pins the KeyRelease route without
  # depending on X key delivery at all. That is ALL the KeyRelease coverage
  # there is — the end-to-end leg was removed; see the block where BAR25 used
  # to be.
  check {BAR13 the pattern entry's KeyRelease binding names searchbar_fire} \
    [bind $w.pat <KeyRelease>] [list wviewer::searchbar_fire $w]

  set ::barargs {}
  $w.pat delete 0 end
  $w.pat insert 0 abc
  eval [bind $w.pat <KeyRelease>]
  check {BAR14 the callback gets exactly 4 args, pattern first} \
    [list [llength $::barargs] [lindex $::barargs 0]] [list 4 abc]

  # explicit non-default selectors, so BAR11/BAR15 cannot be tripped by a
  # mutated DEFAULT (that is BAR04/05/06's job, and only theirs)
  $w.type set Voltage
  $w.syntax set RegExp
  $w.case select
  $w.pat delete 0 end
  $w.pat insert 0 {^v.*}
  check {BAR11 searchbar_get returns the 4-key dict in sig_match codes} \
    [wviewer::searchbar_get $w] \
    [list pattern {^v.*} syntax regexp case 1 type v]

  set ::barargs {}
  eval [bind $w.pat <KeyRelease>]
  check {BAR15 the four callback args are the MAPPED codes} \
    $::barargs [list {^v.*} regexp 1 v]

  set ::barargs {}
  $w.search invoke
  check {BAR16 the Search button reaches the same callback} \
    $::barargs [list {^v.*} regexp 1 v]

  set ::barargs {}
  event generate $w.syntax <<ComboboxSelected>>
  update
  check {BAR17 a ComboboxSelected on the syntax dropdown reaches the callback} \
    $::barargs [list {^v.*} regexp 1 v]

  # BAR27/BAR28 exist because the gap was MEASURED, not suspected: deleting BOTH
  # the type dropdown's <<ComboboxSelected>> binding AND the checkbutton's
  # -command left all 116 checks green, while the shipped contract comment, the
  # commit message and the receipt all claimed FOUR routes converge on
  # searchbar_fire. BAR17 covered the SYNTAX combobox only, and nothing ran the
  # checkbutton's -command at all — `$w.case select` (used above) writes the
  # variable WITHOUT invoking the command, which is exactly why the hole was
  # invisible. Ruling 17's corollary: widen the coverage. Each of the two changes
  # ONE selector and fires ONE route, so each route is pinned on its own.
  set ::barargs {}
  $w.type set Current
  event generate $w.type <<ComboboxSelected>>
  update
  check {BAR27 a ComboboxSelected on the TYPE dropdown reaches the callback} \
    $::barargs [list {^v.*} regexp 1 i]

  # `invoke` IS the -command route: it toggles the variable and then runs
  # -command. Case is 1 coming in (BAR11's `select`), so the callback must see
  # the TOGGLED value 0 — which also proves the callback read the post-toggle
  # state and not a stale snapshot.
  set ::barargs {}
  $w.case invoke
  update
  check {BAR28 the Match-case checkbutton's -command reaches the callback} \
    $::barargs [list {^v.*} regexp 0 i]

  # --- decision 4's error label: THIS widget owns it (item 3's D4) ---
  # The expectation is COMPUTED from sig_match at test time, never a hard-coded
  # Tcl message string: the check is "the label shows the matcher's message
  # VERBATIM", and hard-coding it would instead pin the Tcl version's wording.
  $w.syntax set RegExp
  $w.pat delete 0 end
  $w.pat insert 0 {[}
  eval [bind $w.pat <KeyRelease>]
  check {BAR18 an invalid regexp puts sig_match's message VERBATIM in the label} \
    [$w.err cget -text] [lindex [wviewer::sig_match {} {[} -syntax regexp] 1]

  set barerrmsg [$w.err cget -text]
  check {BAR18b (guard) that message is non-empty, so BAR18 is not vacuous} \
    [expr {$barerrmsg ne {}}] 1

  $w.pat delete 0 end
  $w.pat insert 0 {v.*}
  eval [bind $w.pat <KeyRelease>]
  check {BAR19 the label clears on the next VALID keystroke} \
    [$w.err cget -text] {}

  # mirrors SM19: `[` is a perfectly ordinary shell pattern, so the SAME
  # keystroke must NOT raise an error in Shell mode
  $w.syntax set Shell
  $w.pat delete 0 end
  $w.pat insert 0 {[}
  eval [bind $w.pat <KeyRelease>]
  check {BAR20 in Shell mode `\[` is not an error and the label stays empty} \
    [$w.err cget -text] {}

  # THE eyeball property, converted: the label's fixed -width means a message
  # of ANY length leaves the bar's requested width untouched.
  update idletasks
  set barw0 [winfo reqwidth $w]
  wviewer::searchbar_error $w [string repeat x 200]
  update idletasks
  set barw1 [winfo reqwidth $w]
  wviewer::searchbar_error $w {}
  update idletasks
  check {BAR21 a 200-char error message does not change the bar's reqwidth} \
    [list [expr {$barw0 > 0}] [expr {$barw1 == $barw0}]] [list 1 1]

  check {BAR22 theme: entry font is AseEntryFont, error label is the accent} \
    [list [$w.pat cget -font] [$w.err cget -foreground]] \
    [list AseEntryFont [ase::theme accent]]

  # BAR22b exists because BAR22 does NOT pin `ase::ui::apply_theme` — MEASURED,
  # not assumed: deleting that call leaves BAR22 green, since the entry names
  # AseEntryFont at creation and the accent is configured on the line AFTER it.
  # The panel BACKGROUND is apply_theme's own contribution and nothing else sets
  # it, so this is the check that goes red when the theming call goes away. It
  # is also the closest a headless check gets to the eyeball line "the Match
  # case indicator is legible against the #f2f2f2 panel" — it pins the
  # background, never the legibility.
  check {BAR22b apply_theme really ran: frame/checkbutton/button/label on panel} \
    [list [$w cget -background] [$w.case cget -background] \
          [$w.search cget -background] [$w.err cget -background]] \
    [lrepeat 4 [ase::theme panel]]

  # BAR25 IS DELIBERATELY ABSENT — see the group header. The end-to-end
  # X-key-delivery leg was written, measured green 8/8 in a `run_suites.sh -n 8`
  # soak, and then FAILED inside a full 283-test audit (`{0 {}}` — the key was
  # never delivered under load). It was REMOVED rather than made conditional:
  # its only oracle is "did the callback fire", which cannot tell a WSLg
  # delivery stall from a genuinely broken binding, so a self-skipping version
  # would mask exactly the regression it exists to catch. BAR13 (the binding
  # names the handler) and BAR14 (running that script calls the callback
  # correctly) keep the KeyRelease route pinned without an ambiguous oracle.
  # THE NARROWED CLAIM: the handler and the binding are pinned; end-to-end X key
  # delivery into this widget is NOT.

  # the documented contract: the consumer is told about an invalid pattern too,
  # and decides for itself what to display (item 5 / item 8's call, not the
  # bar's)
  set ::barargs {}
  $w.type set All
  $w.syntax set RegExp
  $w.case deselect
  $w.pat delete 0 end
  $w.pat insert 0 {[}
  eval [bind $w.pat <KeyRelease>]
  check {BAR26 the callback still fires when the pattern is INVALID} \
    $::barargs [list {[} regexp 0 all]

  # --- searchbar_forget on a LIVE bar: the `-variable {}` detach, pinned ---
  # The comment above `searchbar_forget` used to claim this line is what stops
  # BAR24 seeing the entry leak back. That is FALSE, and the probe that measured
  # it (Tk 8.6.14, this box) is worth restating because the shape is
  # counter-intuitive:
  #   * at the frame's own <Destroy>, `winfo exists $w.case` is already 0 — Tk
  #     destroys children first — so on THAT route the configure just errors into
  #     its catch and BAR24 passes with or without it;
  #   * a bare `unset` of a live checkbutton's variable does NOT re-create it;
  #     the next `invoke` does.
  # The line is therefore load-bearing on exactly one path: a consumer calling
  # `searchbar_forget` by hand on a still-live bar (D3's reason for splitting it
  # from the trampoline). This check is that path, on its OWN throwaway bar so
  # that nothing above is disturbed. Delete the detach and the `invoke` below
  # writes ::wviewer::sbcase($w3) straight back.
  destroy .wvsb3
  toplevel .wvsb3
  wm title .wvsb3 {item4 searchbar forget}
  wm geometry .wvsb3 +100+420
  set w3 [wviewer::searchbar_build .wvsb3 -command barcb]
  pack $w3 -fill x
  update
  wviewer::searchbar_forget $w3
  $w3.case invoke
  update
  # the `1` is the anti-vacuity guard: the widget really was still ALIVE across
  # the forget, so this is the live-bar path and not a second copy of BAR24.
  check {BAR29 forget on a LIVE bar detaches the var, so a later toggle cannot resurrect it} \
    [list [winfo exists $w3.case] [info exists ::wviewer::sbcfg($w3)] \
          [info exists ::wviewer::sbcase($w3)]] [list 1 0 0]
  destroy .wvsb3
  update

  # --- teardown, and what teardown must leave behind: nothing ---
  destroy .wvsb1
  destroy .wvsb2
  update
  check {BAR23 searchbar_get returns {} for a foreign or destroyed widget} \
    [list [wviewer::searchbar_get .nosuchbar] [wviewer::searchbar_get $w]] \
    [list {} {}]
  check {BAR24 destroy drops both sbcfg and sbcase — no namespace leak} \
    [list [info exists ::wviewer::sbcfg($w)] [info exists ::wviewer::sbcase($w)] \
          [info exists ::wviewer::sbcfg($w2)] [info exists ::wviewer::sbcase($w2)]] \
    [list 0 0 0 0]
  unset ::barargs

} else {
  # WORDING IS LOAD-BEARING — see the ⚠ in the file header. None of
  # full_audit.sh:109's three skip spellings may appear here, or the whole
  # suite is scored SKIP instead of PASS.
  puts "SKIPPED: BAR group (Tk/X arm only)"
}

# GROUP AT — item 5: the searchbar INSIDE the Add Trace dialog.
#
# Two halves, and they are different kinds of claim:
#   * the REGRESSION GUARD (AT01-AT04, AT16-AT18, AT22) — the PLAN's "do not
#     redesign the dialog" clause. Every pre-existing widget still at its
#     contract path, the renumbered grid with NO hole, the Graph combobox on
#     both its arms, the Expression entry still winning focus.
#   * the FILTER (AT07-AT14, AT19-AT21, AT23) — the bar actually drives the
#     listbox, through the REAL Tk routes.
#
# ⚠ ROUTES, NOT VARIABLES. Item 4 was rejected because two of its four callback
# routes were pinned by nothing, and the hole was invisible because
# `$w.case select` sets the checkbutton variable WITHOUT running its `-command`.
# So AT09 drives `$atb.search invoke`, AT12 drives
# `event generate $atb.type <<ComboboxSelected>>` and AT13 drives
# `$atb.case invoke` — each the real route, each confirmed to fail when severed.
# The `<KeyRelease>` leg is driven at `searchbar_fire`, NOT by a generated key:
# item 4 measured a generated-key check non-deterministic under audit load and
# deleted it (its BAR25/D9). The claim is narrowed to match — end-to-end X key
# delivery INTO THIS DIALOG IS NOT PINNED.
#
# The fixture reuses the item-2 group's second real xschem context ($SLVWP,
# carrying sl_view.raw), so the inventory, the ctx switch and the 0173 restore
# are all genuine. `top` MUST be a REAL toplevel here (unlike the SL group's
# deliberately fake one): the dialog is built as `$top.wvadd`.
#
# `at_open` is left DEFINED ON PURPOSE — item 6 appends to this file and needs
# the same dialog fixture.
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  destroy .wvat1 .wvat2 .wvat3
  toplevel .wvat1 ; wm geometry .wvat1 +100+420
  dict set ::wviewer::windows wvat [dict create top .wvat1 win_path $SLVWP]

  # Open the Add Trace dialog on a layout of `ngraphs` strips, from the MAIN
  # context (so the 0173 loan really has somewhere to return to). `pcall` so a
  # sabotage that makes the dialog THROW degrades to one ERR: value instead of
  # aborting every remaining check through the outer catch (item 3's lesson).
  proc at_open {ngraphs} {
    set gs {}
    for {set i 0} {$i < $ngraphs} {incr i} { lappend gs [::wviewer::empty_graph] }
    dict set ::wviewer::layouts wvat [dict create sharedx 0 graphs $gs]
    xschem new_schematic switch $::SLMAIN
    return [pcall ::wviewer::add_trace_dialog wvat]
  }
  # the listbox as a Tcl list, in display order
  proc at_lb {w} {
    set o {}
    for {set i 0} {$i < [$w size]} {incr i} { lappend o [$w get $i] }
    return $o
  }
  # ⚠ REQUIRED BY AT18, AND THE REASON IT IS NOT A FLAKE. `focus $ee` at the end
  # of add_trace_dialog runs while the brand-new toplevel is still UNMAPPED, so
  # Tk cannot apply it yet: it records the request and re-applies it at MAP time.
  # Until then `focus -lastfor <toplevel>` answers with the TOPLEVEL, because no
  # per-toplevel focus record exists. Once `winfo ismapped` turns 1 the record
  # IS the entry — Tk applies the deferred request at map time (measured 12/12
  # in a standalone Tk probe, including the iterations that were unmapped after
  # a bare `update`).
  # A single `update` is therefore an UNSOUND wait, and reading AT18 behind one
  # is exactly the flake the item-5 verifier measured (3 fails in 22 solo runs,
  # always `.wvat1.wvadd` vs `.wvat1.wvadd.expr`). Instrumented here on an idle
  # machine, 25 solo runs: 3 of them were still unmapped after the `update`
  # (i.e. the old form would have failed those 3, matching the verifier's rate),
  # and those 3 needed **1.9 s, 3.2 s and 3.5 s** of further waiting to map.
  # Hence the 15 s budget: 4x the worst measurement, and still an eighth of
  # full_audit.sh's 120 s per-test timeout. It costs ~10 ms when the map is
  # prompt, which is the other 22 runs.
  # This polls the PRECONDITION (mapping), never the asserted value — it is not
  # a "wait until green" loop; AT18 still asserts the focus record cold, and
  # still carries `ismapped` in its own tuple so a budget expiry reads as
  # "never mapped" rather than as "the bar stole the focus".
  proc at_wait_mapped {w {budget 1500}} {
    for {set t 0} {$t < $budget && ![winfo ismapped $w]} {incr t} {
      after 10 ; update
    }
    update
    return [winfo ismapped $w]
  }

  set atw [at_open 2] ; set atb $atw.wvsearch ; update
  at_wait_mapped $atw

  # the whole inventory: 7 SLFIX names + the implicit `vsweep` from `raw new`
  set ATALL [list vsweep v(out) i(v1) v(x1.x2.net5) net1 @m.x1.m1\[id\] I(V2) \
                  v(net_name\[3\])]
  set ATV   [list v(out) v(x1.x2.net5) v(net_name\[3\])]

  # --- the regression guard: "do not redesign the dialog" --------------------
  # ⚠ AT01 IS THE ONLY CHECK IN THIS GROUP THAT READS $atw.name / $atw.lname.
  # That is deliberate (D4): a second reader would give named sabotage (b) a
  # second target and stop it failing EXACTLY one check.
  check {AT01 every pre-existing dialog child survives at its contract path} \
    [list [winfo exists $atw.graph] [winfo exists $atw.lgraph] \
          [winfo exists $atw.expr]  [winfo exists $atw.lexpr] \
          [winfo exists $atw.name]  [winfo exists $atw.lname] \
          [winfo exists $atw.lvars] [winfo exists $atw.vars] \
          [winfo exists $atw.vsb]   [winfo exists $atw.err] \
          [winfo exists $atw.btns]] \
    [list 1 1 1 1 1 1 1 1 1 1 1]
  # the PLAN's "renumber every grid call, do not leave a hole": rows 4..8
  # consecutive, all distinct, searchbar between the label and the listbox.
  # ⚠ SHIFTED +1 BY ITEM 7, which inserts a Destination row at row 0. The CLAIM
  # is unchanged and is RE-ASSERTED, not weakened: the same five widgets, still
  # consecutive, still in the same order, still with no hole — only the origin
  # moved. This is the identical renumber the PLAN told item 5 to perform when
  # it inserted the search bar.
  check {AT02 grid rows renumbered with no hole: lvars/bar/vars/err/btns} \
    [list [dict get [grid info $atw.lvars]    -row] \
          [dict get [grid info $atw.wvsearch] -row] \
          [dict get [grid info $atw.vars]     -row] \
          [dict get [grid info $atw.err]      -row] \
          [dict get [grid info $atw.btns]     -row]] \
    [list 4 5 6 7 8]
  check {AT03 Graph combobox still gridded and populated (2-graph arm)} \
    [list [dict get [grid info $atw.graph] -row] [$atw.graph cget -values] \
          [$atw.graph get]] \
    [list 1 [list 0 1] 1]
  check {AT16 the bar is the dialog's child at the contract path, and MANAGED} \
    [list [expr {[winfo parent $atb] eq $atw}] [winfo class $atb] \
          [winfo manager $atb]] \
    [list 1 Frame grid]
  check {AT17 the raw-vars listbox is selectmode extended} \
    [$atw.vars cget -selectmode] extended
  # the PLAN's eyeball clause, as far as a headless check can carry it: the bar
  # must NOT steal focus from the Expression entry. This pins Tk's focus RECORD
  # ONCE THE DIALOG IS MAPPED (see at_wait_mapped above — the record does not
  # exist before that, and reading it behind a bare `update` was measured
  # non-deterministic). That the visible CARET is there, and that the WM then
  # hands the focus to this toplevel at all, remain the eyeball's job.
  check {AT18 mapped, and focus goes to the Expression entry not the search bar} \
    [list [winfo ismapped $atw] [focus -lastfor $atw]] [list 1 $atw.expr]
  # D1: population moved to wviewer::signal_list, which is the 0173 loan
  # bracket. The bare `new_schematic switch` it replaces never switched back.
  check {AT22 opening the dialog leaves the context where it found it (0173)} \
    [xschem get current_win_path] $SLMAIN

  # --- the filter ------------------------------------------------------------
  check {AT07 the dialog opens showing the WHOLE inventory, in raw order} \
    [list [at_lb $atw.vars] [$atw.vars size]] [list $ATALL 8]
  $atb.pat delete 0 end ; $atb.pat insert 0 {v(*)}
  ::wviewer::searchbar_fire $atb ; update
  check {AT08 a shell pattern SHRINKS the listbox to the matching set} \
    [at_lb $atw.vars] $ATV
  # decision 5's other half: the Search BUTTON, driven through its real -command
  $atb.pat delete 0 end ; $atb.search invoke ; update
  check {AT09 clearing the pattern GROWS it back (via the Search button route)} \
    [list [at_lb $atw.vars] [$atw.vars size]] [list $ATALL 8]

  # decision 4: an invalid regexp is an ERROR shown in the SEARCH BAR. It must
  # not land in $w.err, which stays the dialog's RPN/no-raw channel.
  $atb.pat delete 0 end ; $atb.pat insert 0 {v(*)}
  ::wviewer::searchbar_fire $atb ; update
  set atpre [at_lb $atw.vars]
  $atb.syntax set RegExp ; event generate $atb.syntax <<ComboboxSelected>> ; update
  check {AT10 an invalid regexp lands in the BAR err label, NOT the dialog's} \
    [list [expr {[$atb.err cget -text] ne {}}] [$atw.err cget -text]] \
    [list 1 {}]
  # D3: HOLD the last good list rather than blanking. Anti-vacuity is real —
  # $atpre is the 3-name v(*) set, not the whole 8.
  check {AT11 an invalid regexp HOLDS the last good list (D3)} \
    [list [at_lb $atw.vars] $atpre] [list $ATV $ATV]

  # THE DECISION-2 WITNESS. The type dropdown works only because the match
  # subject is the FULL raw name: sig_type reads the `v(`/`i(` prefix, which
  # sig_bare-stripping would destroy. Driven through <<ComboboxSelected>>.
  $atb.syntax set Shell ; $atb.pat delete 0 end
  ::wviewer::searchbar_fire $atb ; update
  $atb.type set Current ; event generate $atb.type <<ComboboxSelected>> ; update
  check {AT12 the type dropdown filters on the FULL raw name (decision 2)} \
    [at_lb $atw.vars] [list i(v1) I(V2)]

  # Match case, off -> on, through `invoke` — `select` would set the variable
  # WITHOUT running -command, which is exactly the hole item 4 shipped.
  $atb.type set All ; event generate $atb.type <<ComboboxSelected>>
  $atb.pat delete 0 end ; $atb.pat insert 0 {I(*)}
  ::wviewer::searchbar_fire $atb ; update
  set atcaseoff [at_lb $atw.vars]
  $atb.case invoke ; update
  check {AT13 Match case off->on narrows I(*) from both to I(V2)} \
    [list $atcaseoff [at_lb $atw.vars]] \
    [list [list i(v1) I(V2)] [list I(V2)]]
  $atb.case invoke ; update                       ;# back to decision 6's default

  # NAMED SABOTAGE (a)'s target. The teeth are real: v(out) moves 1 -> 0,
  # v(x1.x2.net5) moves 3 -> 1, and net1 is filtered away entirely — so an
  # index-based snapshot would land on the wrong rows, not merely survive.
  $atb.pat delete 0 end ; ::wviewer::searchbar_fire $atb ; update
  $atw.vars selection clear 0 end
  foreach atn [list v(out) v(x1.x2.net5) net1] {
    $atw.vars selection set [lsearch -exact [at_lb $atw.vars] $atn]
  }
  set atselpre [$atw.vars curselection]
  $atb.pat insert 0 {v(*)} ; ::wviewer::searchbar_fire $atb ; update
  set atselnm {}
  foreach i [$atw.vars curselection] { lappend atselnm [$atw.vars get $i] }
  check {AT14 the selection SURVIVES the filter, by name not by index} \
    [list $atselpre [$atw.vars curselection] $atselnm] \
    [list [list 1 3 4] [list 0 1] [list v(out) v(x1.x2.net5)]]

  # THE %W GUARD (R2, MEASURED on Tk 8.6.14: `bindtags .top.kid` is
  # {.top.kid Label .top all}, so a CHILD's destroy fires the TOPLEVEL's
  # <Destroy> binding). Without the guard the inventory evaporates here and the
  # filter below silently returns on its `info exists` bail.
  # The listbox is deliberately reset to the FULL list FIRST. Without it the
  # "filter still works" half is vacuous: AT14 leaves the box already showing
  # $ATV, so a filter that bails out on the missing cache leaves exactly the
  # expected content behind and only the `info exists` half has teeth. MEASURED
  # — sabotage E2 initially failed on one half of this check, not two.
  $atb.pat delete 0 end ; ::wviewer::searchbar_fire $atb ; update
  set atfullagain [at_lb $atw.vars]
  label $atw.junk -text x ; destroy $atw.junk ; update
  $atb.pat delete 0 end ; $atb.pat insert 0 {v(*)}
  ::wviewer::searchbar_fire $atb ; update
  check {AT20 destroying a CHILD does not drop the inventory (%W guard)} \
    [list [info exists ::wviewer::atdsigs(wvat)] $atfullagain [at_lb $atw.vars]] \
    [list 1 $ATALL $ATV]

  set atbsaved $atb
  destroy $atw ; update
  check {AT19 closing the dialog leaves no namespace state behind} \
    [list [info exists ::wviewer::atdsigs(wvat)] \
          [info exists ::wviewer::sbcfg($atbsaved)] \
          [info exists ::wviewer::sbcase($atbsaved)]] \
    [list 0 0 0]

  # DRIVER NOTE (c) / item 4's verifier sabotage V-U2, closed here. Item 4
  # shipped the claim "a throwing consumer callback puts its own message in
  # $w.err, so it is visible and never silent" — MEASURED true but pinned by
  # nothing, because item 4 had no consumer. Item 5 is the first one.
  # Anti-vacuity: the label is asserted EMPTY before the throw.
  toplevel .wvat2
  proc at_throwcb {args} { error "consumer blew up: $args" }
  set atb2 [::wviewer::searchbar_build .wvat2 -command at_throwcb]
  pack $atb2 -fill x                              ;# item 4's eyeball trap
  update
  set atb2pre [$atb2.err cget -text]
  $atb2.pat delete 0 end ; $atb2.pat insert 0 abc
  ::wviewer::searchbar_fire $atb2 ; update
  check {AT21 a THROWING consumer surfaces in the bar's own error label} \
    [list $atb2pre [$atb2.err cget -text]] \
    [list {} {consumer blew up: abc shell 0 all}]
  destroy .wvat2 ; update

  # D2: the "no raw data loaded" note now triggers on an EMPTY INVENTORY rather
  # than on `xschem raw list` throwing. Same user-visible result. Driven through
  # a token whose win_path does not exist, so signal_list's landmine-17 refusal
  # returns {} — no third xschem context is created.
  toplevel .wvat3
  dict set ::wviewer::windows wvat_noraw \
    [dict create top .wvat3 win_path .wvsl_nosuch.drw]
  dict set ::wviewer::layouts wvat_noraw \
    [dict create sharedx 0 graphs [list [::wviewer::empty_graph]]]
  set atnw [pcall ::wviewer::add_trace_dialog wvat_noraw] ; update
  check {AT23 an empty inventory still yields the no-raw note (D2)} \
    [list [$atnw.vars size] [$atnw.err cget -text]] \
    [list 0 {no raw data loaded - variable list unavailable}]
  destroy .wvat3 ; update
  dict unset ::wviewer::windows wvat_noraw
  dict unset ::wviewer::layouts wvat_noraw

  # The 1-graph arm, REOPENED rather than freshly built — which also exercises
  # the ordering trap (R6): ase::ui::dialog_frame destroys the old dialog first,
  # firing the old <Destroy> and its cache-forget DURING the new open. The cache
  # is written after dialog_frame returns, so it survives; measured n=8.
  set atw [at_open 1] ; update
  check {AT04 below 2 graphs the Graph combobox exists but is NOT gridded} \
    [list [winfo exists $atw.graph] [grid info $atw.graph] \
          [llength [grid info $atw.graph]]] \
    [list 1 {} 0]

  destroy $atw .wvat1 .wvat2 .wvat3
  update
  dict unset ::wviewer::windows wvat
  dict unset ::wviewer::layouts wvat
  xschem new_schematic switch $SLMAIN

} else {
  # WORDING IS LOAD-BEARING — see the ⚠ in the file header. None of
  # full_audit.sh:109's three skip spellings may appear here, or the whole
  # suite is scored SKIP instead of PASS.
  puts "SKIPPED: AT group (Tk/X arm only)"
}

# --- item 6: multi-select plot from Add Trace (GROUP MS) ---------------------
#
# `wviewer::add_trace_ok` with an EMPTY Expression now adds ONE TRACE PER
# SELECTED ROW, in listbox order, each through the existing
# `wviewer::add_trace`. A typed Expression still WINS and still adds exactly
# one. The Name field applies only to a single row. The first error aborts the
# rest and the already-added traces STAY (a deliberate NON-rollback).
#
# ⚠ FIXTURE: THIS GROUP CANNOT REUSE THE AT GROUP'S CONTEXT, and the reason is
# worth spelling out because it is invisible until `add_trace` actually runs.
# The AT token's win_path is $SLVWP = `.x1.drw`, which is a TAB, not a Tk
# widget (`tabbed_interface` is 1, so `winfo exists .x1.drw` is 0). The DIALOG
# half is fine — it never touches the canvas — but `add_trace` ->
# `wviewer::regenerate` -> `wviewer::viewport_rect` does `winfo width $wp` and
# THROWS `bad window path name ".x1.drw"`, AFTER `set_graphs` has already
# written the trace into the model. Isolated: `viewport_rect .x1.drw` rc=1 vs
# `viewport_rect .drw` rc=0. So the MS token's win_path is $SLMAIN (`.drw`),
# a real mapped canvas. (D1.)
#
# ⚠ EACH SCENARIO OPENS ITS OWN DIALOG (D2). Non-negotiable: on a successful
# multi-add the dialog is DESTROYED, so a shared handle would make the next
# bare `$w.vars selection clear` THROW into the outer catch and turn a
# 5-check sabotage into a file-wide abort (item 3's lesson).
#
# ⚠ ORDER IS ASSERTED AS A LITERAL, NOT RECOMPUTED (driver note (d)). MS03's
# expectation is spelled out by hand; recomputing it from `curselection` would
# assert the selection list against itself and pin nothing. MS01 pins the
# premise separately — that `curselection` comes back ASCENDING, i.e. in
# DISPLAY order and not in click order.
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  # EXTEND the MAIN context's sl_main.raw (no `raw new` — that would drop
  # wrong_ctx_var, which SL12 above still refers to in this same process).
  foreach n $SLFIX { xschem raw add $n {vsweep 1 +} }
  set MSALL [linsert $SLFIX 0 vsweep wrong_ctx_var]
  #  0 vsweep         3 i(v1)            6 @m.x1.m1[id]
  #  1 wrong_ctx_var  4 v(x1.x2.net5)    7 I(V2)
  #  2 v(out)         5 net1             8 v(net_name[3])

  destroy .wvms1
  toplevel .wvms1 ; wm geometry .wvms1 +140+460
  # `top` MUST be a REAL toplevel (like the AT group's): leave_ctx -> retitle
  # does a `wm title` on it.
  dict set ::wviewer::windows wvms [dict create top .wvms1 win_path $SLMAIN]

  proc ms_open {ngraphs} {
    set gs {}
    for {set i 0} {$i < $ngraphs} {incr i} { lappend gs [::wviewer::empty_graph] }
    dict set ::wviewer::layouts wvms [dict create sharedx 0 graphs $gs]
    xschem new_schematic switch $::SLMAIN
    return [pcall ::wviewer::add_trace_dialog wvms]
  }
  # ⚠ THE OTHER HALF OF D2, AND IT WAS MEASURED, NOT GUESSED. The in-dialog
  # error label must be read through THIS, never as a bare `$w.err cget -text`.
  # Every check below that reads the label is preceded by a check that the
  # dialog is still up — and a sabotage that flips a refusal or an abort into a
  # SUCCESS destroys the dialog, so the bare form throws into the outer catch
  # and turns a 5-check sabotage into a file-wide abort. Sabotage (a)-narrow did
  # exactly that on the first measurement: MS03/MS05/MS07/MS13 failed, and then
  # MS14's bare `cget` aborted MS15-MS18 with `invalid command name
  # ".wvms1.wvadd.err"` instead of failing. Returning NO-DIALOG makes "the
  # dialog vanished" an ASSERTABLE VALUE rather than a crash (item 3's lesson).
  proc ms_err {w} {
    if {![winfo exists $w.err]} { return NO-DIALOG }
    return [$w.err cget -text]
  }
  # one model field of every trace on graph $gi, in model order
  proc ms_field {gi key} {
    set G [lindex [dict get [::wviewer::layout_for wvms] graphs] $gi]
    set o {}
    foreach tr [::wviewer::dget $G traces {}] {
      lappend o [::wviewer::dget $tr $key {}]
    }
    return $o
  }

  # --- scenario A: three rows, empty Expression, no Name ---------------------
  set msw [ms_open 2] ; update
  check {MS00 the dialog opens on the real-canvas ctx with the whole inventory} \
    [list [winfo exists $msw] [$msw.vars size] [$msw.graph get]] \
    [list 1 9 1]
  # THE PREMISE OF "LISTBOX ORDER", pinned as a fact rather than assumed:
  # selecting 7 then 3 then 4 must read back {3 4 7}.
  $msw.vars selection clear 0 end
  $msw.vars selection set 7
  $msw.vars selection set 3
  $msw.vars selection set 4
  check {MS01 curselection comes back ASCENDING, not in click order} \
    [$msw.vars curselection] [list 3 4 7]
  check {MS02 OK on 3 selected rows does not throw} \
    [pcall ::wviewer::add_trace_ok wvms] {}
  update
  # LITERAL expectation (driver note (d)) — display order, NOT click order.
  check {MS03 three traces land on the selected graph, in LISTBOX order} \
    [ms_field 1 vec] [list i(v1) v(x1.x2.net5) I(V2)]
  check {MS04 the other graph got nothing} [llength [ms_field 0 vec]] 0
  check {MS05 the batch paints the three traces in DISTINCT colors} \
    [llength [lsort -unique [ms_field 1 color]]] 3
  check {MS06 the dialog closes on a fully successful multi-add} \
    [winfo exists $msw] 0
  # the CANVAS, not just the model: regenerate really ran for every trace
  xschem new_schematic switch $SLMAIN
  check {MS07 the graph rect on the canvas carries all three names} \
    [split [xschem getprop rect 2 1 node] "\n"] \
    [list i(v1) v(x1.x2.net5) I(V2)]

  # --- scenario B: a typed Expression WINS over the selection ---------------
  set msw [ms_open 2] ; update
  $msw.vars selection clear 0 end
  $msw.vars selection set 2 ; $msw.vars selection set 3
  $msw.vars selection set 4
  $msw.expr delete 0 end ; $msw.expr insert 0 {v(out) db20()}
  $msw.name delete 0 end ; $msw.name insert 0 db1
  check {MS08 a typed expression beats 3 selected rows: exactly ONE trace} \
    [list [pcall ::wviewer::add_trace_ok wvms] [ms_field 1 vec] \
          [ms_field 1 name] [ms_field 1 expr]] \
    [list {} [list db1] [list db1] [list {v(out) db20()}]]
  check {MS09 the RPN path still closes the dialog} [winfo exists $msw] 0

  # --- scenario C: Name + several rows is REFUSED ---------------------------
  set msw [ms_open 2] ; update
  $msw.vars selection clear 0 end
  $msw.vars selection set 2 ; $msw.vars selection set 5
  $msw.name delete 0 end ; $msw.name insert 0 mysig
  check {MS10 Name + 2 rows is refused: dialog stays up and NOTHING is added} \
    [list [pcall ::wviewer::add_trace_ok wvms] [winfo exists $msw] \
          [llength [ms_field 1 vec]] [llength [ms_field 0 vec]]] \
    [list {} 1 0 0]
  # EXACT match, like MS15 — the message is the contract, not just "non-empty"
  check {MS11 the refusal message is the contract string, verbatim} \
    [ms_err $msw] \
    {one Name cannot cover 2 traces - clear the Name field, or select a single row}
  destroy $msw ; update

  # --- scenario D: the boundary — Name + EXACTLY ONE row still applies ------
  set msw [ms_open 2] ; update
  $msw.vars selection clear 0 end
  $msw.vars selection set 5
  $msw.name delete 0 end ; $msw.name insert 0 mysig
  check {MS12 Name + exactly ONE row still applies the Name} \
    [list [pcall ::wviewer::add_trace_ok wvms] [ms_field 1 vec] \
          [ms_field 1 name]] \
    [list {} [list net1] [list mysig]]

  # --- scenario E: the first failure aborts the rest, earlier adds STAY -----
  set msw [ms_open 2] ; update
  # a name the raw does not carry, injected INTO the listbox at index 4 so the
  # batch is {good bad good} and the abort is observable from both sides
  $msw.vars insert 4 nosuchvar
  $msw.vars selection clear 0 end
  $msw.vars selection set 3 ; $msw.vars selection set 4
  $msw.vars selection set 6
  check {MS13 the first failure aborts the rest and KEEPS the earlier adds} \
    [list [pcall ::wviewer::add_trace_ok wvms] [winfo exists $msw] \
          [ms_field 1 vec]] \
    [list {} 1 [list i(v1)]]
  # driver note (f): the NON-rollback is only defensible if the message says
  # how far it got, so the user can tell what state the graph is in
  check {MS14 the message reports how many were added before the failure} \
    [list [regexp {added 1 of 3} [ms_err $msw]] \
          [regexp {nosuchvar} [ms_err $msw]]] [list 1 1]
  destroy $msw ; update

  # --- scenario F: nothing typed and nothing picked ------------------------
  set msw [ms_open 2] ; update
  $msw.vars selection clear 0 end
  # D3: routed through add_trace with an EMPTY rpn, so that string has ONE
  # owner. This check is what makes that a claim and not a hope.
  check {MS15 no expression and no pick yields add_trace's own message} \
    [list [pcall ::wviewer::add_trace_ok wvms] [ms_err $msw] \
          [llength [ms_field 1 vec]]] \
    [list {} {empty expression - type one or pick a raw variable} 0]
  destroy $msw ; update

  # --- scenario G: a SINGLE failing pick keeps the message UNSUFFIXED -------
  # DIFFERENTIAL (D4). R7: add_trace returns at validate_rpn before any model
  # write, but it DOES run capture_live_view_state — so the reference is
  # computed into a variable HERE, and the scenario's own layout is built
  # afterwards by ms_open, rather than inlining a mutating call into an
  # expectation.
  set MSREF [pcall ::wviewer::add_trace wvms 1 nosuchvar {}]
  set msw [ms_open 2] ; update
  $msw.vars insert 4 nosuchvar
  $msw.vars selection clear 0 end
  $msw.vars selection set 4
  check {MS16 a single failing pick keeps add_trace's message with NO suffix} \
    [list [pcall ::wviewer::add_trace_ok wvms] [ms_err $msw]] \
    [list {} $MSREF]
  destroy $msw ; update

  # the multi-add path plots EXISTING vectors; only the RPN path materializes
  # a new one (`db1`, from scenario B)
  xschem new_schematic switch $SLMAIN
  check {MS17 the multi-add path creates NO raw vectors; only the RPN path did} \
    [split [xschem raw list] "\n"] [concat $MSALL db1]

  # teardown: `with_edit` leaves the ctx readonly and the graph rects drawn
  destroy .wvms1 ; update
  dict unset ::wviewer::windows wvms
  dict unset ::wviewer::layouts wvms
  xschem new_schematic switch $SLMAIN
  xschem set readonly 0
  xschem clear_drawing
  xschem set_modify 0
  check {MS18 teardown leaves the main context empty and writable} \
    [list [xschem get rects 2] [xschem get readonly]] [list 0 0]

} else {
  # WORDING IS LOAD-BEARING — see the ⚠ in the file header.
  puts "SKIPPED: MS group (Tk/X arm only)"
}

# --- item 7: the PLOT-DESTINATION policy (DS01-DS31) -------------------------
# ViVA's Append / Replace / NewSubWin / NewWin, mapped onto xschem's model as
# `append` `replace` `newstrip` `newtab` and split in two halves:
#   the LANDING half  -> wviewer::plan_plot's 7th argument (PURE, DS01-DS13)
#   the WINDOW half   -> wviewer::dest_prepare (makes the tab; DS26/DS27)
# plus the per-window accessor pair plot_dest / set_plot_dest (DS14, DS28).
#
# ⚠ WHAT CARRIES THE REGRESSION CLAIM IS NOT THIS GROUP. Under `append`,
# plan_plot's answer is BYTE-IDENTICAL to the 6-argument answer it has always
# given — no `clear` key at all — and that is what keeps test_wave_modes' ~25
# whole-dict comparisons and test_wave_viewer's G11/G12/G12b green. DS01/DS02
# state that invariant HERE so a change to the dict shape fails in this file
# too, rather than only in a file a maintainer might not think to run.
#
# ⚠ FIXTURE: the MS group's teardown DESTROYED `.wvms1` and dict-unset BOTH the
# `::wviewer::windows wvms` and the `::wviewer::layouts wvms` entries, so its
# helper procs (`ms_open`, `ms_err`, `ms_field`) are live procs pointing at a
# DEAD token. They are reused UNCHANGED — driver note (d) forbids inventing a
# third waiting/error idiom — but the token must first be RE-REGISTERED against
# a fresh toplevel. win_path is $SLMAIN (`.drw`), a real mapped canvas, for the
# reason spelled out in the MS group's header: $SLVWP is a TAB and every draw
# path throws on it.
#
# ⚠ THE INVENTORY IS 10 ROWS HERE, NOT 9. The MS group's scenario B
# materialized `db1` via the RPN path, so the raw this group sees is MSALL + db1
# (that is exactly what MS17 pins). Row indices below are therefore:
#   0 vsweep  1 wrong_ctx_var  2 v(out)  3 i(v1)  4 v(x1.x2.net5)
#   5 net1    6 @m.x1.m1[id]   7 I(V2)   8 v(net_name[3])  9 db1
# and the listbox order is the RAW order, unsorted — MS03 pinned that premise.
# This group adds NO raw vectors, so MS17's inventory claim above stays true.

# ===== PURE checks: both arms (no Tk) ========================================

# THE SHAPE CLAIM. Two literals, and `clear` ABSENT — the absence is half the
# claim, so it is asserted, not assumed.
check {DS01 plan_plot with 6 args is unchanged, single AND multi, and emits NO clear key} \
  [list [::wviewer::plan_plot single 2 1 3] \
        [::wviewer::plan_plot multi  2 0 3] \
        [dict exists [::wviewer::plan_plot single 2 1 3] clear] \
        [dict exists [::wviewer::plan_plot multi  2 0 3] clear]] \
  [list [dict create new 0 targets {1 1 1}] \
        [dict create new 3 targets {2 1 0}] 0 0]

# DIFFERENTIAL: an explicit `append` must be indistinguishable from omitting the
# argument, over every arm of the policy (multi, single-with-target,
# empty-stack, empty-reuse, auto-strip).
check {DS02 an explicit append is byte-identical to the 6-arg answer on every arm} \
  [list [expr {[::wviewer::plan_plot single 2 1 3] eq [::wviewer::plan_plot single 2 1 3 -1 {} append]}] \
        [expr {[::wviewer::plan_plot multi  2 0 3] eq [::wviewer::plan_plot multi  2 0 3 -1 {} append]}] \
        [expr {[::wviewer::plan_plot single 0 0 2] eq [::wviewer::plan_plot single 0 0 2 -1 {} append]}] \
        [expr {[::wviewer::plan_plot single 3 0 2 -1 {1 2}] eq [::wviewer::plan_plot single 3 0 2 -1 {1 2} append]}] \
        [expr {[::wviewer::plan_plot single 3 1 2 1] eq [::wviewer::plan_plot single 3 1 2 1 {} append]}] \
        [expr {[::wviewer::plan_plot multi  3 0 2 -1 {0 1}] eq [::wviewer::plan_plot multi  3 0 2 -1 {0 1} append]}]] \
  [list 1 1 1 1 1 1]

check {DS03 replace keeps new/targets and adds clear {1}} \
  [::wviewer::plan_plot single 2 1 2 -1 {} replace] \
  [dict create new 0 targets {1 1} clear {1}]

# INDEX SPACE, single arm: when the plan CREATES its landing strip there is
# nothing pre-existing to empty, so `clear` is EMPTY — not {0}, which would
# wipe an unrelated strip.
check {DS04 replace whose plan appends a strip clears nothing (single index space)} \
  [list [::wviewer::plan_plot single 0 0 1 -1 {} replace] \
        [::wviewer::plan_plot single 3 1 2 1 {} replace]] \
  [list [dict create new 1 targets {0} clear {}] \
        [dict create new 1 targets {3 3} clear {}]]

# THE SINGLE ARM'S **REUSE** PATH, which DS04 does NOT reach (both of its cases
# APPEND a strip; neither passes a non-empty empties list). Here the stored
# target is the tool-owned auto strip, so the plan REUSES empty strip 2 instead
# of appending — and a reused-empty strip holds nothing, so clearing it would be
# a no-op clear_graph_traces call: a wavehl remap, a marker sweep and a redraw
# for nothing. `clear` must be EMPTY.
check {DS04b replace that REUSES an empty strip clears nothing (single arm)} \
  [list [::wviewer::plan_plot single 3 1 2 1 {1 2} replace] \
        [::wviewer::plan_plot single 3 0 1 0 {1} replace]] \
  [list [dict create new 0 targets {2 2} clear {}] \
        [dict create new 0 targets {1} clear {}]]

# ...and the NEGATIVE half of that claim, because "clears nothing" is only worth
# anything beside a case that clears something. IDENTICAL call but for the
# target: an EMPTY target strip is not listed, an OCCUPIED one is. This is the
# pair that separates "knows which strips are empty" from "never clears".
check {DS04c the empties list is a FILTER, not an off switch: empty target -> {}, occupied target -> {1}} \
  [list [::wviewer::plan_plot single 3 0 2 -1 {0 2} replace] \
        [::wviewer::plan_plot single 3 1 2 -1 {0 2} replace] \
        [::wviewer::plan_plot single 3 1 2 -1 {} replace]] \
  [list [dict create new 0 targets {0 0} clear {}] \
        [dict create new 0 targets {1 1} clear {1}] \
        [dict create new 0 targets {1 1} clear {1}]]

# ⚠ INDEX SPACE, multi arm — AND THE DECLARED LIMIT OF THE WHOLE POLICY.
# multi-plot lands every signal either in a strip it CREATES or in a REUSED
# EMPTY one; it never lands on an occupied strip, for any destination. So there
# is by construction nothing for Replace to clear there: the key is present (the
# shape still tracks the destination) and it is ALWAYS EMPTY. That is what
# plan_plot's ⚠⚠ declares, and this is where it is pinned. Two sub-cases: a mix
# (one new strip + two reused) and an all-reuse plan.
check {DS05 replace in multi clears NOTHING: every landing strip is new or reused-empty} \
  [list [::wviewer::plan_plot multi 2 0 3 -1 {0 1} replace] \
        [::wviewer::plan_plot multi 3 0 2 -1 {0 1 2} replace]] \
  [list [dict create new 1 targets {2 1 0} clear {}] \
        [dict create new 0 targets {1 0} clear {}]]

# DIFFERENTIAL, and it is the honest statement of the narrowed claim: under
# multi, `replace` IS `append` plus an empty `clear` key — over the mix, the
# all-new, the all-reuse and the auto-strip arms. If a later change ever makes
# multi land on an occupied strip, this check fails and the declaration in
# plan_plot's ⚠⚠ has to be revisited rather than quietly outliving its reason.
set dsdiff {}
foreach dscase {{multi 2 0 3 -1 {0 1}} {multi 3 0 2 -1 {0 1 2}} \
                {multi 2 0 3 -1 {}}    {multi 3 0 1 -1 {2}} \
                {multi 3 0 2 1 {0 1 2}}} {
  set dsapp [::wviewer::plan_plot {*}$dscase append]
  set dsrep [::wviewer::plan_plot {*}$dscase replace]
  lappend dsdiff [expr {[dict remove $dsrep clear] eq $dsapp}] \
                 [dict exists $dsrep clear] [::wviewer::dget $dsrep clear MISSING]
}
check {DS05b DIFFERENTIAL: in multi, replace == append + an empty clear key, on every arm} \
  $dsdiff [list 1 1 {} 1 1 {} 1 1 {} 1 1 {} 1 1 {}]
unset dsdiff dscase dsapp dsrep

check {DS06 newstrip in single forces ONE fresh strip and IGNORES the target} \
  [list [::wviewer::plan_plot single 2 0 2 -1 {} newstrip] \
        [::wviewer::plan_plot single 2 1 2 -1 {} newstrip]] \
  [list [dict create new 1 targets {2 2}] \
        [dict create new 1 targets {2 2}]]

# THE point of New Strip in multi: ONE strip for the whole batch, not one per
# signal the way plot mode would give.
check {DS07 newstrip in multi is ONE strip for the whole batch, not three} \
  [::wviewer::plan_plot multi 3 0 3 -1 {} newstrip] \
  [dict create new 1 targets {0 0 0}]

check {DS08 newstrip ignores reusable empty strips entirely} \
  [list [::wviewer::plan_plot single 3 1 2 -1 {0 2} newstrip] \
        [::wviewer::plan_plot multi  3 0 2 -1 {0 1 2} newstrip]] \
  [list [dict create new 1 targets {3 3}] \
        [dict create new 1 targets {0 0}]]

# newtab reaches the append policy INSIDE plan_plot: dest_prepare has already
# made the tab, and the layout being planned against is the NEW tab's.
# ⚠ BY FALL-THROUGH, not by a collapse statement — plan_plot's body names only
# `newstrip` and `replace`. An explicit `set dest append` line used to sit at the
# top of the proc; it was measured to change nothing and removed, so this check
# is what the callers actually rely on. It is a BEHAVIOUR assertion and it holds
# either way; nothing credits it to a line.
check {DS09 newtab behaves as append inside plan_plot} \
  [list [expr {[::wviewer::plan_plot single 1 0 2 -1 {} newtab] eq [::wviewer::plan_plot single 1 0 2]}] \
        [expr {[::wviewer::plan_plot multi 1 0 2 -1 {} newtab] eq [::wviewer::plan_plot multi 1 0 2]}] \
        [dict exists [::wviewer::plan_plot single 1 0 2 -1 {} newtab] clear]] \
  [list 1 1 0]

check {DS10 an unknown destination falls back to append, not to a destructive one} \
  [list [expr {[::wviewer::plan_plot single 2 1 3 -1 {} bogus] eq [::wviewer::plan_plot single 2 1 3]}] \
        [expr {[::wviewer::plan_plot single 2 1 3 -1 {} {}] eq [::wviewer::plan_plot single 2 1 3]}] \
        [dict exists [::wviewer::plan_plot single 2 1 3 -1 {} bogus] clear]] \
  [list 1 1 0]

# The n<=0 guard runs FIRST, so an empty gesture makes no strip, clears nothing
# and produces no `clear` key, WHATEVER the destination says.
check {DS11 an empty gesture is a no-op for every destination} \
  [list [::wviewer::plan_plot single 2 1 0 -1 {} append] \
        [::wviewer::plan_plot single 2 1 0 -1 {} replace] \
        [::wviewer::plan_plot single 2 1 0 -1 {} newstrip] \
        [::wviewer::plan_plot multi  2 1 0 -1 {} newtab] \
        [::wviewer::plan_plot single 2 1 -3 -1 {} replace]] \
  [list [dict create new 0 targets {}] [dict create new 0 targets {}] \
        [dict create new 0 targets {}] [dict create new 0 targets {}] \
        [dict create new 0 targets {}]]

# The mapper accepts LABELS (the combobox) and CODES (a CIW line, a replayed log
# line, item 9's toolbar), case-insensitively, with the space forms; ViVA's own
# NewSubWin/NewWin are deliberately NOT aliases and land on the fallback.
check {DS12 dest_norm maps 4 labels + 4 codes + case + space forms; junk -> append} \
  [list [::wviewer::dest_norm Append]    [::wviewer::dest_norm Replace] \
        [::wviewer::dest_norm {New Strip}] [::wviewer::dest_norm {New Tab}] \
        [::wviewer::dest_norm append]    [::wviewer::dest_norm replace] \
        [::wviewer::dest_norm newstrip]  [::wviewer::dest_norm newtab] \
        [::wviewer::dest_norm REPLACE]   [::wviewer::dest_norm NeWsTrIp] \
        [::wviewer::dest_norm {new strip}] [::wviewer::dest_norm {new tab}] \
        [::wviewer::dest_norm {  Replace  }] \
        [::wviewer::dest_norm NewSubWin]  [::wviewer::dest_norm NewWin] \
        [::wviewer::dest_norm {}]        [::wviewer::dest_norm zzz]] \
  [list append replace newstrip newtab \
        append replace newstrip newtab \
        replace newstrip newstrip newtab replace \
        append append append append]

check {DS13 dest_label round-trips every code, and junk -> Append} \
  [list [::wviewer::dest_label append] [::wviewer::dest_label replace] \
        [::wviewer::dest_label newstrip] [::wviewer::dest_label newtab] \
        [::wviewer::dest_label zzz] [::wviewer::dest_label {}] \
        [::wviewer::dest_labels] \
        [expr {[::wviewer::dest_norm [::wviewer::dest_label newstrip]] eq {newstrip}}] \
        [expr {[::wviewer::dest_norm [::wviewer::dest_label newtab]] eq {newtab}}]] \
  [list Append Replace {New Strip} {New Tab} Append Append \
        [list Append Replace {New Strip} {New Tab}] 1 1]

# An unknown token gets the HARMLESS policy, and setting on one is a spoken
# refusal ({}), never a throw.
check {DS14 plot_dest defaults to append on an unknown token; set_plot_dest refuses without throwing} \
  [list [pcall ::wviewer::plot_dest ds_nosuch_token] \
        [pcall ::wviewer::set_plot_dest replace ds_nosuch_token] \
        [pcall ::wviewer::plot_dest ds_nosuch_token]] \
  [list append {} append]

if {[info exists ::has_x] && [info commands winfo] ne {}} {

  # RE-REGISTER the `wvms` token the MS teardown unset, against a FRESH
  # toplevel, so ms_open / ms_err / ms_field work again unchanged.
  destroy .wvds1
  toplevel .wvds1 ; wm geometry .wvds1 +160+480
  dict set ::wviewer::windows wvms [dict create top .wvds1 win_path $SLMAIN]
  # needed only by the New Tab checks, but registered up front so no check has
  # to care whether it runs before or after them
  pcall ::wviewer::tabs_init wvms

  # ms_open plus PRE-PLANTED traces: `seeds` is a flat {gi {name ...} ...} list.
  # The seeds go in through the REAL wviewer::add_trace rather than by writing a
  # hand-built trace dict, so a seeded strip is indistinguishable from one the
  # user filled — which is the whole point of Replace and New Strip checks. It
  # is a layout BUILDER, not a third waiting or error idiom (driver note (d)).
  proc ds_open {ngraphs seeds} {
    set gs {}
    for {set i 0} {$i < $ngraphs} {incr i} { lappend gs [::wviewer::empty_graph] }
    dict set ::wviewer::layouts wvms [dict create sharedx 0 graphs $gs]
    xschem new_schematic switch $::SLMAIN
    foreach {gi names} $seeds {
      foreach nm $names { ::wviewer::add_trace wvms $gi $nm {} }
    }
    return [pcall ::wviewer::add_trace_dialog wvms]
  }
  # how many traces on each strip of wvms, in strip order — the one number every
  # destination check is really about
  proc ds_counts {} {
    set o {}
    foreach G [dict get [::wviewer::layout_for wvms] graphs] {
      lappend o [llength [::wviewer::dget $G traces {}]]
    }
    return $o
  }
  # ⚠ A CALL RECORDER for clear_graph_traces, because "the target ended up with
  # the right traces" and "clear_graph_traces ran on exactly the right strips"
  # are DIFFERENT claims, and only the second one can see a NO-OP clear.
  # Clearing an ALREADY-EMPTY strip changes no trace list, so no count check
  # anywhere in this file can catch it — but it is not free: that proc runs
  # wavehl_remap_apply, markers_sweep_numbers and set_graphs (a redraw), which is
  # precisely the "real work with real side effects" plan_replace_clear's header
  # promises never happens. The wrapper DELEGATES to the real proc (nothing is
  # stubbed out) and is torn down immediately; the pcall inside each gesture
  # wrapper guarantees the restore is reached even when the gesture throws.
  proc ds_spy_on {} {
    set ::ds_cgt {}
    rename ::wviewer::clear_graph_traces ::ds_cgt_real
    proc ::wviewer::clear_graph_traces {token gi} {
      lappend ::ds_cgt $gi
      ::ds_cgt_real $token $gi
    }
  }
  proc ds_spy_off {} {
    rename ::wviewer::clear_graph_traces {}
    rename ::ds_cgt_real ::wviewer::clear_graph_traces
  }
  proc ds_spy_ok {} {
    ds_spy_on ; set r [pcall ::wviewer::add_trace_ok wvms] ; ds_spy_off ; return $r
  }
  proc ds_spy_plot {exprs} {
    ds_spy_on ; set r [pcall ::wviewer::plot_signals wvms $exprs] ; ds_spy_off ; return $r
  }
  # pick rows 2 and 3 of the inventory: v(out) and i(v1)
  proc ds_pick2 {w} {
    $w.vars selection clear 0 end
    $w.vars selection set 2
    $w.vars selection set 3
  }

  # --- the form ------------------------------------------------------------
  set dsw [ds_open 2 {}] ; update
  check {DS20 the dialog carries the Destination pair, the 4 labels, default Append} \
    [list [winfo exists $dsw.ldest] [winfo exists $dsw.dest] \
          [$dsw.dest cget -values] [$dsw.dest get] [$dsw.dest cget -state]] \
    [list 1 1 [list Append Replace {New Strip} {New Tab}] Append readonly]
  # the +1 renumber, END TO END and with no hole: nine widgets, rows 0..8.
  check {DS21 every grid row renumbered with no hole: dest 0 ... btns 8} \
    [list [dict get [grid info $dsw.ldest]    -row] \
          [dict get [grid info $dsw.dest]     -row] \
          [dict get [grid info $dsw.lgraph]   -row] \
          [dict get [grid info $dsw.graph]    -row] \
          [dict get [grid info $dsw.lexpr]    -row] \
          [dict get [grid info $dsw.lname]    -row] \
          [dict get [grid info $dsw.lvars]    -row] \
          [dict get [grid info $dsw.wvsearch] -row] \
          [dict get [grid info $dsw.vars]     -row] \
          [dict get [grid info $dsw.err]      -row] \
          [dict get [grid info $dsw.btns]     -row]] \
    [list 0 0 1 1 2 3 4 5 6 7 8]
  destroy $dsw ; update

  # --- APPEND: the seed survives and the batch joins it --------------------
  set dsw [ds_open 2 {1 net1}] ; update
  $dsw.dest set Append
  ds_pick2 $dsw
  check {DS22 APPEND lands beside the seed on the target strip} \
    [list [pcall ::wviewer::add_trace_ok wvms] [ds_counts] [ms_field 1 vec]] \
    [list {} [list 0 3] [list net1 v(out) i(v1)]]

  # --- REPLACE: the seed is GONE, the strip count does not move ------------
  set dsw [ds_open 2 {1 net1}] ; update
  $dsw.dest set Replace
  ds_pick2 $dsw
  check {DS23 REPLACE empties the target first: exactly the 2 new traces remain, one clear call} \
    [list [ds_spy_ok] [ds_counts] [ms_field 1 vec] $::ds_cgt] \
    [list {} [list 0 2] [list v(out) i(v1)] [list 1]]

  # ...and the same gesture onto a target that is ALREADY EMPTY: the traces land
  # identically and NO clear call is made. Counts alone cannot tell these two
  # worlds apart — the recorder can, and this is the ONLY check that reaches the
  # empty-strip list add_trace_ok now hands plan_plot.
  set dsw [ds_open 2 {}] ; update
  $dsw.dest set Replace
  ds_pick2 $dsw
  check {DS23b REPLACE onto an ALREADY-EMPTY target lands the same and clears nothing} \
    [list [ds_spy_ok] [ds_counts] [ms_field 1 vec] $::ds_cgt] \
    [list {} [list 0 2] [list v(out) i(v1)] {}]

  # --- NEW STRIP: a fresh strip appears and the seed is untouched ----------
  set dsw [ds_open 2 {1 net1}] ; update
  $dsw.dest set {New Strip}
  ds_pick2 $dsw
  check {DS24 NEW STRIP appends one strip and leaves the seeded strip alone} \
    [list [pcall ::wviewer::add_trace_ok wvms] [ds_counts] \
          [ms_field 1 vec] [ms_field 2 vec]] \
    [list {} [list 0 1 2] [list net1] [list v(out) i(v1)]]

  # the Graph combobox has NO effect under New Strip — that is what "force a
  # fresh graph regardless" means, and it is the half of the policy a
  # target-respecting implementation would silently get wrong
  set dsw [ds_open 2 {1 net1}] ; update
  $dsw.dest set {New Strip}
  $dsw.graph set 0
  ds_pick2 $dsw
  check {DS25 NEW STRIP ignores the Graph combobox} \
    [list [pcall ::wviewer::add_trace_ok wvms] [ds_counts] [ms_field 2 vec]] \
    [list {} [list 0 1 2] [list v(out) i(v1)]]

  # ⚠ THE REFUSAL MUST RUN BEFORE dest_prepare, and NOTHING ELSE IN THIS BATCH
  # CAN SEE THAT. MS10/MS11 exercise the same refusal, but the MS window's
  # destination is `append`, where dest_prepare does nothing at all — so moving
  # the refusal after it fails NOTHING there. Ruling 17: widen the coverage
  # rather than narrow the claim. Under New Tab a refused OK must leave no tab,
  # no trace and the dialog still up, with the contract string verbatim.
  set dsw [ds_open 2 {1 net1}] ; update
  $dsw.dest set {New Tab}
  ds_pick2 $dsw
  $dsw.name delete 0 end ; $dsw.name insert 0 mysig
  check {DS25b a REFUSED OK under New Tab makes no tab and adds nothing} \
    [list [pcall ::wviewer::add_trace_ok wvms] [winfo exists $dsw] \
          [::wviewer::tab_count wvms] [ds_counts] [ms_err $dsw]] \
    [list {} 1 1 [list 0 1] \
          {one Name cannot cover 2 traces - clear the Name field, or select a single row}]
  destroy $dsw ; update

  # --- NEW TAB -------------------------------------------------------------
  set dsw [ds_open 2 {1 net1}] ; update
  $dsw.dest set {New Tab}
  ds_pick2 $dsw
  set dstabs0 [::wviewer::tab_count wvms]
  set dsok [pcall ::wviewer::add_trace_ok wvms]
  update
  check {DS26 NEW TAB makes a tab, raises it, and lands the batch in its one strip} \
    [list $dsok $dstabs0 [::wviewer::tab_count wvms] [::wviewer::tab_index wvms] \
          [ds_counts] [ms_field 0 vec]] \
    [list {} 1 2 1 [list 2] [list v(out) i(v1)]]
  # ⚠ ASSERTABLE VALUE, NOT AN EXCEPTION (driver note (e)(2)): the dialog is
  # destroyed by new_tab's tab_drop_transients BEFORE the adds happen, so
  # "the error label vanished" must read back as NO-DIALOG. A bare
  # `$dsw.err cget -text` here would throw into the outer catch and silently
  # abort every remaining check in this file.
  #
  # ⚠ AND IT IS THE **ERROR** PATH THAT CARRIES THE CLAIM, ON PURPOSE. Written
  # against a SUCCESSFUL OK this check discriminated NOTHING — a successful OK
  # ends in its own `destroy $w`, so the dialog is gone either way. MEASURED:
  # sabotage U3 (dest_prepare never makes the tab) left the success-path form
  # GREEN. On a FAILING add the two worlds separate cleanly: with the tab really
  # made, the dialog is already gone when the failure is reported and the
  # message can ONLY go to wviewer::echo; without it, the dialog is still up
  # holding the text. Ruling 17 — widen the coverage, do not narrow the claim.
  set dsw [ds_open 2 {}] ; update
  $dsw.dest set {New Tab}
  $dsw.expr delete 0 end ; $dsw.expr insert 0 {v(nosuchnet) db20()}
  set dstabs1 [::wviewer::tab_count wvms]
  check {DS27 NEW TAB destroys the dialog BEFORE the add, so a failure can only reach the CIW} \
    [list [pcall ::wviewer::add_trace_ok wvms] [winfo exists $dsw] [ms_err $dsw] \
          [expr {[::wviewer::tab_count wvms] - $dstabs1}]] \
    [list {} 0 NO-DIALOG 1]
  # back to the original tab: its two strips and its seed are exactly as left.
  # ⚠ select_tab takes the tab's ID, NOT its index — tabs_init seeds id 1, and
  # passing the index 0 is a silent no-op that looks like a broken restore.
  pcall ::wviewer::select_tab 1 wvms ; update
  check {DS28a the original tab is intact after select_tab back} \
    [list [::wviewer::tab_index wvms] [ds_counts] [ms_field 1 vec]] \
    [list 0 [list 0 1] [list net1]]

  # --- persistence: the dropdown IS the per-window setting -----------------
  # (the New Tab OK just above already wrote `newtab`, so this also proves the
  # write happens on the OK of a destination that destroys its own dialog)
  check {DS28b the window's destination persisted through the New Tab OK} \
    [::wviewer::plot_dest wvms] newtab
  set dsw [ds_open 2 {}] ; update
  $dsw.dest set Replace
  ds_pick2 $dsw
  pcall ::wviewer::add_trace_ok wvms ; update
  set dsw [ds_open 2 {}] ; update
  check {DS28 reopening the dialog shows the persisted choice, not the default} \
    [list [::wviewer::plot_dest wvms] [$dsw.dest get]] [list replace Replace]
  destroy $dsw ; update

  # --- REPLACE + a failing pick: the DECLARED non-rollback -----------------
  # The target was already emptied when the add failed, so the strip ends up
  # with FEWER traces than it started with. That is deliberate (item 6's
  # non-rollback, extended); it is pinned so it cannot change silently.
  set dsw [ds_open 2 {1 {net1 v(out)}}] ; update
  $dsw.dest set Replace
  $dsw.vars insert 4 nosuchvar
  $dsw.vars selection clear 0 end
  $dsw.vars selection set 2
  $dsw.vars selection set 4
  check {DS29 REPLACE + a failing pick: the target IS cleared and the message says how far it got} \
    [list [pcall ::wviewer::add_trace_ok wvms] [ds_counts] [ms_field 1 vec] \
          [string match {*added 1 of 2, stopped at 'nosuchvar'*} [ms_err $dsw]]] \
    [list {} [list 0 1] [list v(out)] 1]
  destroy $dsw ; update

  # --- plot_signals honours the WINDOW destination -------------------------
  # THE seam item 9's three browser gestures will come through, so it is pinned
  # independently of the dialog.
  dict set ::wviewer::layouts wvms \
    [dict create sharedx 0 graphs [list [::wviewer::empty_graph] [::wviewer::empty_graph]]]
  xschem new_schematic switch $SLMAIN
  ::wviewer::add_trace wvms 1 net1 {}
  ::wviewer::set_target_strip 1 wvms
  ::wviewer::set_plot_dest replace wvms
  set dsperrs [ds_spy_plot [list v(out) i(v1)]]
  update
  # the POSITIVE control for the recorder: an occupied target IS cleared, once,
  # by index. Without this row the two zero-call checks below would prove only
  # that the recorder never sees anything.
  check {DS30 plot_signals honours the window destination (Replace empties the target, exactly once)} \
    [list $dsperrs [ds_counts] [ms_field 1 vec] $::ds_cgt] \
    [list {} [list 0 2] [list v(out) i(v1)] [list 1]]
  # ...and the same seam under append is the unchanged behaviour
  ::wviewer::set_plot_dest append wvms
  set dsperrs [pcall ::wviewer::plot_signals wvms [list net1]]
  update
  check {DS30b plot_signals under append still accumulates} \
    [list $dsperrs [ds_counts] [ms_field 1 vec]] \
    [list {} [list 0 3] [list v(out) i(v1) net1]]

  # --- REPLACE under MULTI-plot: the DECLARED limit, exercised LIVE ---------
  # ⚠ The pure DS05/DS05b say the plan carries an empty `clear`. This says what
  # that MEANS at the seam: with the window in multi-plot mode, a Replace gesture
  # lands the batch in the reusable empty strip and the OCCUPIED strip beside it
  # keeps all three of its traces. Replace is a single-mode policy (plan_plot's
  # ⚠⚠) and the honest statement of that is a check that shows nothing was
  # destroyed — not the absence of a check.
  # mode is seeded first because set_plot_mode speaks only for a window that
  # already has one (its {} truthfully means "no window"); the real accessor is
  # then used, and its answer asserted, rather than writing the array twice.
  set ::wviewer::mode(wvms) single
  set dsmode [pcall ::wviewer::set_plot_mode multi wvms]
  ::wviewer::set_plot_dest replace wvms
  set dsperrs [ds_spy_plot [list v(out)]]
  update
  # THE ZERO-CALL half is what the trace counts cannot see: the landing strip is
  # a REUSED EMPTY one, so a Replace that listed it would destroy nothing and
  # every count below would still match — it would just do a wavehl remap, a
  # marker sweep and a redraw for nothing, which is exactly what
  # plan_replace_clear's header promises it does not do.
  check {DS30c REPLACE under multi-plot destroys NOTHING and clears NOTHING (zero calls)} \
    [list $dsmode $dsperrs [ds_counts] [ms_field 0 vec] [ms_field 1 vec] $::ds_cgt] \
    [list multi {} [list 1 3] [list v(out)] [list v(out) i(v1) net1] {}]
  pcall ::wviewer::set_plot_mode single wvms

  # ...and the SINGLE arm's own no-op case, which is the one a user meets by
  # simply pressing Replace twice, or Replace into a fresh strip: the target is
  # already empty, so there is nothing to clear.
  dict set ::wviewer::layouts wvms \
    [dict create sharedx 0 graphs [list [::wviewer::empty_graph] [::wviewer::empty_graph]]]
  ::wviewer::set_target_strip 0 wvms
  ::wviewer::set_plot_dest replace wvms
  set dsperrs [ds_spy_plot [list v(out)]]
  update
  check {DS30d REPLACE onto an ALREADY-EMPTY target makes no clear call at all} \
    [list $dsperrs [ds_counts] [ms_field 0 vec] $::ds_cgt] \
    [list {} [list 1 0] [list v(out)] {}]
  rename ds_spy_on {} ; rename ds_spy_off {}
  rename ds_spy_ok {} ; rename ds_spy_plot {}
  catch {unset ::ds_cgt}

  # --- teardown ------------------------------------------------------------
  # Same shape as MS18's, and for the same reason: `with_edit` leaves the ctx
  # readonly with graph rects drawn, and new_tab left BOTH. Item 8 starts a new
  # file, but this process is still shared.
  destroy .wvds1 ; update
  ::wviewer::tabs_forget wvms
  dict unset ::wviewer::windows wvms
  dict unset ::wviewer::layouts wvms
  catch {unset ::wviewer::dest(wvms)}
  catch {unset ::wviewer::target(wvms)}
  # DS30c seeded a plot MODE on this token; it did not exist before the DS group
  # and must not outlive it either
  catch {unset ::wviewer::mode(wvms)}
  xschem new_schematic switch $SLMAIN
  xschem set readonly 0
  xschem clear_drawing
  xschem set_modify 0
  check {DS31 teardown leaves the main context empty and writable, and no tab/dest/mode state} \
    [list [xschem get rects 2] [xschem get readonly] \
          [pcall ::wviewer::tab_count wvms] \
          [info exists ::wviewer::dest(wvms)] \
          [info exists ::wviewer::mode(wvms)]] \
    [list 0 0 0 0 0]

} else {
  # WORDING IS LOAD-BEARING — see the ⚠ in the file header.
  puts "SKIPPED: DS group (Tk/X arm only)"
}

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
