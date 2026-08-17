# test_wave_casemode.tcl — casemode batch ITEM 5: the viewer's Tcl half.
#
# PLAN.md §3b item 5 · DECISIONS.md B2a/D2 ·
# spec doc/claude/specs/raw_case_mode.md §9 and §12.
#
# Three things are under test, and they are not alike:
#
#  1. ONE Tcl MIRROR OF get_raw_index(), NOT TWO. `wviewer::name_rungs` /
#     `name_index` / `name_lookup` are the whole rule; `validate_rpn` and
#     `resolve_signal_db` are their two callers. Before item 5 the second of
#     those was a flat `string tolower` on both sides that ignored D2 entirely
#     and could not see a `distinguish` database at all.
#  2. THE TWO-PANE BROWSER'S GROUP/CLASS PARSER, audited against the
#     `@dev[param]` shape. The shapes here are MEASURED, not invented — on
#     `build-ver_50`, 2026-08-16, with `.options savecurrents`:
#       fold      i(v1)  i(@r1[i])  i(@r.x1.rq[i])
#       preserve  i(V1)  i(@R1[i])  i(@R.X1.Rq[i])
#     (one deck, one top-level R1 and one Rq inside X1, `-D casemode=<mode>`.)
#  3. THE Options > Case Mode CONTROL — B2a's first-ranked source, the explicit
#     user setting, which that decision says belongs in the viewer because that
#     is where the raw is loaded.
#
# THE LOAD-BEARING CHECKS, and why:
#   CS90*  AGREEMENT, in BOTH directions. Every one of these reads the engine's
#          `xschem raw index` AND the Tcl gate's verdict for ONE token and fails
#          if they differ — so "refuse everything" fails exactly as loudly as
#          "approve everything". That is the only honest way to test a mirror.
#   CS89j  rung 4. It is the input on which item 2's gate was measurably NOT
#          get_raw_index's rule: `i(v.x1.vp)` against a database storing
#          `i(x1.vp)`. The engine resolves it; the gate refused it.
#   CS92e2 D2 across databases, and it is CS92e2 and NOT CS92e. `Amb`/`amb`
#          live in the poisoned slot ONLY, so the folded query `AMB` has exactly
#          one slot that could answer and it is ambiguous — the answer must be
#          nothing. CS92e cannot do this job: the clean slot answers `COUNT` on
#          its own and comes first, so inverting the skip left the suite green.
#   CS93b  a FOREIGN database is judged by ITS OWN `case` flag. `xschem raw
#          case` reports the CURRENT database, so before item 5 a `distinguish`
#          slot folded (or a plain one refused) according to wherever the user
#          happened to be standing.
#   CS95q  the Case Mode cache is DROPPED by attach_raw and never recomputed
#          there. Item 3 measured `raw casemode` at up to 189 ms with no cache
#          behind it and told items 5 and 13 not to poll it. CS95o2 is its twin:
#          the cache is actually READ, which an earlier revision's was not.
#   CS95k2 the WIDGET, not the proc. Replacing the radiobutton's -command with a
#   CS95k3 no-op is a dead control that every direct `set_case_mode` check in
#          this file passes through happily; only `invoke` catches it. Same hole
#          CS95e0 closes on the -postcommand half.
#   CS95u  the override SURVIVES a re-attach of the same file (a re-run), and
#   CS95w  does NOT follow onto a different one. The explicit source lives on
#          the Raw and attach_dbs does clear+read, so without this a re-run
#          silently threw the user's setting away.
#   CS95x2 WHICH Raw the override lands on. It is the VIEWER's, and
#   CS95x3 hilight_sender_case_mode() reads the SCHEMATIC window's — a different
#          object. The claim that the cross-probe senders consult this setting
#          was false and these two keep it from coming back.
#   CS89x  the fold key is ASCII-only, because the engine's is byte-wise
#   CS90y  (strtolower(), util.c:1006, no setlocale in the tree). Tcl's
#   CS90z  `string tolower` folds `Ä`->`ä` and invents a D2 collision the engine
#          does not have.
#
# Legs, and what each needs:
#   CS89* N  PURE — no engine, no display. The matcher's rungs and D2.
#   CS90* G  ENGINE, true headless — agreement with `xschem raw index`.
#   CS91* B  PURE — the browser group/class parser on the measured @-shapes.
#   CS92* R  VIEWER (display) — resolve_signal_db over several databases.
#   CS93* A  VIEWER (display) — add_trace's named-database arm.
#   CS94* C  PURE + VIEWER — the Case Mode control.
#
# Run from the repo root. The N/G/B/C-pure legs need no display:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_wave_casemode.tcl
# The R/A/C-viewer legs need one, and self-skip with a NOTE — deliberately NOT
# a `RESULT: SKIP` banner, which would make full_audit.sh score the WHOLE FILE
# as SKIP and silently discard every check that did run:
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog \
#     --script tests/headless/test_wave_casemode.tcl

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
proc wr {path body} {
  set f [open $path w]
  puts -nonewline $f $body
  close $f
}

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
set wvsrc [file join $repo src wave_viewer.tcl]
set tmp [test_scratch wvcase]

# A missing source file must FAIL, never skip. Note a SYNTAX error in
# wave_viewer.tcl cannot be reached here: xschem sources it at startup, so a
# broken file SIGSEGVs before this line runs (measured, casemode item 2).
eqcheck CS89-source-wave-viewer [pcall source $wvsrc] {}

# The SCHEMATIC window's ctx path, captured HERE because this is the last point
# at which it is unambiguous — `ase::session_open` leaves the viewer current, so
# reading it later returns the viewer's own path and CS95x would compare a
# context with itself (it did, and said the two Raws were one). Used by CS95x.
set mainwp [pcall xschem get current_win_path]

# ===========================================================================
# N — PURE: the ONE matcher. No engine, no display.
# ===========================================================================
# The candidate spellings get_raw_index() probes, in its own order (save.c:2960):
# the query, the v()-wrapped query, and — only for an `i(v.x…` query — the
# `i(v.` prefix cut to `i(`.
eqcheck CS89b-rungs-plain [pcall wviewer::name_rungs MidNode] {MidNode v(MidNode)}
eqcheck CS89c-rungs-wrapped [pcall wviewer::name_rungs {v(MidNode)}] {v(MidNode) v(v(MidNode))}
# THE EXACT REWRITE. `my_snprintf(vnode, "i(%s", node + 4)` — four characters
# go, the `x` STAYS, and nothing is appended after `%s` because `node + 4`
# already carries the closing paren. `i(x1.vp))` is the shape a `"i(...)"`
# rewrite produces and it matches nothing.
eqcheck CS89d-rungs-ivx [pcall wviewer::name_rungs {i(v.x1.vp)}] \
  {i(v.x1.vp) v(i(v.x1.vp)) i(x1.vp)}
# ANCHORED and CASE-BLIND, both halves, exactly as save.c:2994's
# `!my_strncasecmp(node, "i(v.x", 5)` is.
eqcheck CS89e-rungs-ivx-uppercase [pcall wviewer::name_rungs {I(V.X1.VP)}] \
  {I(V.X1.VP) v(I(V.X1.VP)) i(X1.VP)}
check CS89f-rungs-ivx-not-anchored \
  [expr {[llength [pcall wviewer::name_rungs {xi(v.x1.vp)}]] == 2}] \
  "(a match at a non-zero offset earns no rung: [pcall wviewer::name_rungs {xi(v.x1.vp)}])"
# `i(v.foo)` is NOT the shape: the guard tests five characters, so the `x` must
# be there. (The SENDER side keeps its four — spec §11 rules that not a
# disagreement — but the reader's rung is five and this mirrors the reader.)
check CS89g-rungs-ivx-needs-the-x \
  [expr {[llength [pcall wviewer::name_rungs {i(v.foo)}]] == 2}] \
  "([pcall wviewer::name_rungs {i(v.foo)}])"

set nix [pcall wviewer::name_index {v(EN) v(en) v(SWEEP) i(x1.vp) Count count v(dup) v(dup)}]
eqcheck CS89h-exact-hit [pcall wviewer::name_lookup $nix {v(EN)} 1] ok
eqcheck CS89i-folded-hit [pcall wviewer::name_lookup $nix {V(SWEEP)} 1] ok
eqcheck CS89j-rung4-hit [pcall wviewer::name_lookup $nix {i(v.x1.vp)} 1] ok
eqcheck CS89k-bare-wrapped-hit [pcall wviewer::name_lookup $nix SWEEP 1] ok
eqcheck CS89l-miss [pcall wviewer::name_lookup $nix nosuchnode 1] no
# D2: two DIFFERENT stored names folding to one key resolve to NOTHING, and the
# proc says WHICH failure it is so the caller can word its refusal.
eqcheck CS89m-d2-collision [pcall wviewer::name_lookup $nix COUNT 1] ambiguous
eqcheck CS89n-d2-wrapped-collision [pcall wviewer::name_lookup $nix En 1] ambiguous
# ... while an EXACT spelling of a colliding name still resolves. This is the
# half D2 is most often mis-implemented as breaking.
eqcheck CS89o-d2-exact-survives [pcall wviewer::name_lookup $nix Count 1] ok
eqcheck CS89p-d2-exact-wrapped-survives [pcall wviewer::name_lookup $nix {v(en)} 1] ok
# BYTE-IDENTICAL DUPLICATES ARE NOT A COLLISION (ngspice upstream 0073 writes
# two identical columns with identical names; declining there would break a
# lookup that has exactly one answer).
eqcheck CS89q-duplicate-is-not-a-collision [pcall wviewer::name_lookup $nix {V(DUP)} 1] ok
# `fuzzy 0` is a `distinguish` database: raw_fold_index() returns -1 outright
# (save.c:2903), so ONLY the exact rungs may answer.
eqcheck CS89r-distinguish-exact-kept [pcall wviewer::name_lookup $nix {v(EN)} 0] ok
eqcheck CS89s-distinguish-folded-refused [pcall wviewer::name_lookup $nix {V(SWEEP)} 0] no
eqcheck CS89t-distinguish-ambiguous-is-plain-no [pcall wviewer::name_lookup $nix COUNT 0] no
# validate_rpn's `fuzzy` override is what lets a caller judge a FOREIGN name
# list. Omitted, it asks the engine about the CURRENT database.
eqcheck CS89u-validate-override-off \
  [pcall wviewer::validate_rpn {V(SWEEP) 2 *} {v(EN) v(en) v(SWEEP)} 0] \
  {unknown token 'V(SWEEP)' (not an operator/function, number or raw variable)}
eqcheck CS89v-validate-override-on \
  [pcall wviewer::validate_rpn {V(SWEEP) 2 *} {v(EN) v(en) v(SWEEP)} 1] {}
eqcheck CS89w-validate-ambiguous-wording \
  [pcall wviewer::validate_rpn {COUNT 2 *} {Count count} 1] \
  {ambiguous token 'COUNT' (two variables differ only in case; use one of their exact spellings)}

# ⚠ THE FOLD KEY IS ASCII-ONLY, because the authority is byte-wise. The engine
# folds with `raw_fold_key()` -> `strtolower()` (util.c:1006), a `tolower()`
# loop over BYTES with no `setlocale` anywhere in src/, so the two UTF-8 bytes
# of `Ä` come back unchanged. Tcl's `string tolower` is Unicode-aware and folds
# `Ä`->`ä`, which INVENTS a D2 collision the engine does not have — and since
# item 5 made `resolve_signal_db` act on `name_lookup`'s verdict, that turned a
# slot the engine resolves into one that is skipped. The `\u` escapes are
# deliberate: a literal `Ä` in this file would mean different characters
# depending on the system encoding, which is the opposite of what is being
# pinned. The engine half is CS90x-CS90z.
eqcheck CS89x-fold-key-is-ascii-only \
  [pcall wviewer::fold_key "v(C\u00C4)"] "v(c\u00C4)"
set uix [pcall wviewer::name_index [list "v(C\u00C4)" "v(c\u00E4)" v(ok)]]
# `v(C<U+C4>)` and `v(c<U+E4>)` fold to DIFFERENT byte keys, so neither poisons
# the other and both stay resolvable
eqcheck CS89y-nonascii-pair-is-not-a-collision \
  [pcall wviewer::name_lookup $uix "v(C\u00E4)" 1] ok
# ... and the ASCII half of the same name still folds, which is what makes this
# a fold rule rather than "give up on non-ASCII"
eqcheck CS89z-ascii-half-still-folds \
  [pcall wviewer::name_lookup $uix "V(C\u00C4)" 1] ok

# ===========================================================================
# G — ENGINE: the mirror AGREES with get_raw_index(), in both directions
# ===========================================================================
# want=1 means the engine resolves the token AND the gate passes it; want=0
# means BOTH refuse. Disagreement either way fails. This is the same oracle
# test_raw_case_mode.tcl's CS49* uses, extended to rung 4 and the @-shapes.
proc gatecheck {name tok want} {
  set vl [split [pcall xschem raw list] "\n"]
  set gate [pcall wviewer::validate_rpn "$tok 2 *" $vl]
  set eng [pcall xschem raw index $tok]
  set engok [expr {[string is integer -strict $eng] && $eng >= 0}]
  set gateok [expr {$gate eq {}}]
  check $name [expr {$engok == $want && $gateok == $want}] \
    "(token '$tok' engine=$eng gate='$gate' want [expr {$want ? {both resolve} : {both refuse}}])"
}

# An ASCII raw carrying, verbatim, the four MEASURED shapes plus the
# hierarchical-current spelling rung 4 exists for. `i(x1.vp)` is stored; the
# query `i(v.x1.vp)` is the OTHER spelling ngspice versions use for it.
wr $tmp/dev_preserve.raw "Title: devshapes
Date: Sun Aug 16 00:00:00 2026
Plotname: Operating Point
Flags: real
No. Variables: 9
No. Points: 1
Variables:
\t0\tv(In)\tvoltage
\t1\ti(V1)\tcurrent
\t2\ti(@R1\[i\])\tcurrent
\t3\ti(@R.X1.Rq\[i\])\tcurrent
\t4\ti(x1.vp)\tcurrent
\t5\tv(MidNode)\tvoltage
\t6\ti(.x1.vp)\tcurrent
\t7\tv(C\u00C4)\tvoltage
\t8\tv(c\u00E4)\tvoltage
Values:
0\t1.0
\t0.002
\t0.001
\t0.0005
\t0.003
\t0.5
\t0.004
\t0.006
\t0.007

"
xschem raw clear
eqcheck CS90-read-dev-raw [pcall xschem raw read $tmp/dev_preserve.raw op] 1
eqcheck CS90b-names-verbatim [pcall xschem raw list] \
  "v(In)\ni(V1)\ni(@R1\[i\])\ni(@R.X1.Rq\[i\])\ni(x1.vp)\nv(MidNode)\ni(.x1.vp)\nv(C\u00C4)\nv(c\u00E4)"
eqcheck CS90c-default-is-fold [pcall xschem raw case] 0
# the @dev[param] shape resolves EXACTLY, and in any casing (rungs 1-2 — it
# needs no rung of its own, spec §9)
gatecheck CS90d-devparam-exact {i(@R.X1.Rq[i])} 1
gatecheck CS90e-devparam-folded {i(@r.x1.rq[i])} 1
gatecheck CS90f-devparam-uppercased {I(@R.X1.RQ[I])} 1
gatecheck CS90g-devparam-toplevel-exact {i(@R1[i])} 1
gatecheck CS90h-devparam-toplevel-folded {i(@r1[i])} 1
gatecheck CS90i-devparam-absent {i(@R9[i])} 0
# RUNG 4. `i(x1.vp)` is stored; both spellings of the query must resolve, in
# both casings, on BOTH sides.
gatecheck CS90j-rung4-exact-stored {i(x1.vp)} 1
gatecheck CS90k-rung4-rewrite {i(v.x1.vp)} 1
gatecheck CS90l-rung4-rewrite-uppercase {I(V.X1.VP)} 1
# ⚠ THE BAIT COLUMN `i(.x1.vp)` IS WHAT MAKES THIS CHECK ABLE TO FAIL, and it
# is item 2's own bait (CS39f) on the Tcl side. `xi(v.x1.vp)` is a name the
# ANCHORED rung declines; an UNANCHORED one rewrites it to exactly `i(.x1.vp)`,
# which this database really does store — so with the anchor gone the gate would
# resolve a token the engine refuses. Without the bait both sides refuse for the
# boring reason and the check is vacuous.
gatecheck CS90m-rung4-garbage-offset {xi(v.x1.vp)} 0
# the ordinary rungs, so "the gate refuses more" cannot pass this leg
gatecheck CS90n-bare-wrapped {MidNode} 1
gatecheck CS90o-bare-wrapped-folded {midnode} 1
gatecheck CS90p-unknown {v(nosuchnet)} 0
# a `distinguish` database turns the folded rungs off on BOTH sides, rung 4
# included
eqcheck CS90q-set-distinguish [pcall xschem raw case distinguish] 1
gatecheck CS90r-distinguish-exact-kept {i(@R.X1.Rq[i])} 1
gatecheck CS90s-distinguish-folded-refused {i(@r.x1.rq[i])} 0
gatecheck CS90t-distinguish-rung4-exact-case {i(v.x1.vp)} 1
gatecheck CS90u-distinguish-rung4-wrong-case {I(V.X1.VP)} 0
eqcheck CS90v-clear-distinguish [pcall xschem raw case 0] 1
gatecheck CS90w-folded-resolves-again {i(@r.x1.rq[i])} 1
# ⚠ THE FOLD KEY IS BYTE-WISE, AND THESE THREE ARE THE AGREEMENT HALF OF IT.
# The database stores `v(C<U+00C4>)` and `v(c<U+00E4>)`. `strtolower()` (util.c:1006)
# is a `tolower()` loop over BYTES with no `setlocale` in the tree, so the two
# UTF-8 bytes of each accented letter survive and the two names fold to two
# DIFFERENT keys — the engine resolves all three tokens below. A Unicode-aware
# `string tolower` in the Tcl mirror folds them to ONE key, invents a D2
# collision, and the gate refuses what the engine resolves: measured
# disagreement, and CS90y/CS90z are the two tokens that show it. CS90x is the
# control (an exact hit needs no fold and agreed even before the fix).
gatecheck CS90x-nonascii-exact "v(C\u00C4)" 1
gatecheck CS90y-nonascii-ascii-half-folds "V(C\u00C4)" 1
gatecheck CS90z-nonascii-other-spelling "v(C\u00E4)" 1

# ===========================================================================
# B — PURE: the two-pane browser's group/class parser, audited on @dev[param]
# ===========================================================================
# The AUDIT ITEM 5 was asked for. The finding is that the shape IS handled —
# `sig_declass`'s `^@?[A-Za-z]$` and `sig_class`'s `@*` are @-shape handling,
# and both are case-blind — with ONE asymmetry, recorded at CS91h-CS91j.
proc bcheck {name nm want} {
  set e [pcall wviewer::signal_entry $nm]
  set got [list [wviewer::dget $e class {}] [wviewer::dget $e path {}] \
                [wviewer::dget $e leaf {}] [pcall wviewer::browser_label $e]]
  eqcheck $name $got $want
}
# the `preserve` spelling, measured
bcheck CS91-devparam-in-subckt {i(@R.X1.Rq[i])} {devmeas X1 {Rq[i]} Rq:i}
# ... and the `fold` spelling of the same signal: same class, same shape
bcheck CS91b-devparam-in-subckt-folded {i(@r.x1.rq[i])} {devmeas x1 {rq[i]} rq:i}
# the class tag survives an ALL-CAPITALS spelling too (nothing here may be
# case-sensitive: `sig_declass`'s regexp is [A-Za-z], `sig_class` matches `@*`)
bcheck CS91c-devparam-uppercase {I(@R.X1.RQ[I])} {devmeas X1 {RQ[I]} RQ:I}
# an UNWRAPPED @-name (no `i(...)` around it) parses identically — sig_bare
# leaves it alone because `@` is not a legal wrapper-function first character
bcheck CS91d-devparam-unwrapped {@r.x1.rq[i]} {devmeas x1 {rq[i]} rq:i}
# deeper hierarchy: only the leading tag is a tag, the rest is path
bcheck CS91e-devparam-two-levels {i(@r.x1.x2.rq[i])} {devmeas x1.x2 {rq[i]} rq:i}
# the neighbouring classes, so a change that broke the tag test would move more
# than one row
bcheck CS91f-srcbranch {i(v.x1.vs)} {srcbranch x1 vs vs:i}
bcheck CS91g-toplevel-source {i(vs)} {net {} vs vs:i}
# ⚠⚠ THE ASYMMETRY, RECORDED AS A FINDING AND DELIBERATELY NOT FIXED HERE.
# `i(@r1[i])` is a MEASURED shape — a TOP-LEVEL device parameter, ver_50 with
# `.options savecurrents`, in the same raw as `i(@r.x1.rq[i])`. It has no dots,
# so `sig_declass`'s "3 or more segments" guard (DC09, load-bearing: it is what
# stops `m.foo` from being stripped to an EMPTY path) never sees the `@` tag,
# and the signal classes `net`. Consequence: `browser_class_filter` with
# `Show device internals` OFF hides its in-subcircuit twin and KEEPS this one,
# so one device parameter sits among the design nets and the other does not.
# It is not item 5's to change: relaxing the guard for `@`-headed names moves
# `sig_declass`, which is pinned by DC09/DC12/DC13 and by the two-pane suites'
# counts, and item 5's audit contract is an EMPTY diff. Stated as the behaviour
# it is, so the next reader finds a check rather than a surprise.
bcheck CS91h-devparam-toplevel-classes-net {i(@r1[i])} {net {} {@r1[i]} r1:i}
check CS91i-toplevel-devparam-escapes-the-device-filter \
  [expr {[llength [pcall wviewer::browser_class_filter \
      [list [wviewer::signal_entry {i(@r1[i])}] \
            [wviewer::signal_entry {i(@r.x1.rq[i])}]] 0 1]] == 1}] \
  "(devint 0 hides the in-subckt @-param and keeps the top-level one)"
eqcheck CS91j-both-are-device-shaped-to-a-person \
  [list [wviewer::sig_is_device [wviewer::dget [wviewer::signal_entry {i(@r1[i])}] class {}]] \
        [wviewer::sig_is_device [wviewer::dget [wviewer::signal_entry {i(@r.x1.rq[i])}] class {}]]] \
  {0 1}
# the `-type` filter's documented divergence still holds for the @-shapes: an
# UNWRAPPED @-name is `other`, a wrapped one follows its wrapper (ST05)
eqcheck CS91k-type-follows-the-wrapper \
  [list [pcall wviewer::sig_type {i(@R.X1.Rq[i])}] [pcall wviewer::sig_type {@r.x1.rq[i]}]] \
  {i other}

# ===========================================================================
# C(pure) — the Case Mode control's pure half
# ===========================================================================
eqcheck CS94-choices [pcall wviewer::casemode_choices] {auto fold preserve distinguish}
# B2b: the readout names the SOURCE, and says `unknown` rather than asserting
# `fold` when nothing could tell.
eqcheck CS94b-label-schematic [pcall wviewer::casemode_label {fold schematic}] \
  {Case mode: fold — compared with the schematic's net names}
eqcheck CS94c-label-explicit [pcall wviewer::casemode_label {distinguish explicit}] \
  {Case mode: distinguish — your setting}
eqcheck CS94d-label-header [pcall wviewer::casemode_label {preserve header}] \
  {Case mode: preserve — the file's Option: casemode= header}
eqcheck CS94e-label-none [pcall wviewer::casemode_label {unknown none}] \
  {Case mode: unknown — nothing could tell}
eqcheck CS94f-label-no-database [pcall wviewer::casemode_label {}] \
  {Case mode: no database loaded}
eqcheck CS94g-label-sniff [pcall wviewer::casemode_label {preserve sniff}] \
  {Case mode: preserve — a capital-letter sniff}
# `upper` is a verdict the schematic comparison can reach but not a mode anyone
# runs in, so it is not offered — and the readout still renders it if it arrives.
check CS94h-upper-not-offered \
  [expr {[lsearch -exact [pcall wviewer::casemode_choices] upper] < 0 \
      && [lsearch -exact [pcall wviewer::casemode_choices] auto] >= 0}] \
  "([pcall wviewer::casemode_choices])"
# THE DRAW-SAFE READ never calls the engine, so it answers for a token that has
# no window at all.
eqcheck CS94i-cached-empty-for-unknown-token [pcall wviewer::casemode_cached nosuchtoken] {}
eqcheck CS94j-refresh-refuses-an-unknown-token [pcall wviewer::casemode_refresh nosuchtoken] {}
eqcheck CS94k-set-refuses-a-bad-mode [pcall wviewer::set_case_mode nosuchtoken sideways] 0

# ===========================================================================
# R / A / C(viewer) — the legs that need a window
# ===========================================================================
if {![info exists ::has_x] || [info commands winfo] eq {}} {
  puts "NOTE: CS92*/CS93*/CS95* not run (no DISPLAY; the N/G/B/C-pure legs above did run)"
} else {

# Two ASCII raws that a viewer can register side by side. The SECOND carries the
# D2 collision (`Count` and `count`); the FIRST carries only `count`, so a
# `COUNT` query must skip the poisoned slot and land on the clean one.
wr $tmp/clean.raw "Title: clean
Date: Sun Aug 16 00:00:00 2026
Plotname: Transient Analysis
Flags: real
No. Variables: 3
No. Points: 2
Variables:
\t0\ttime\ttime
\t1\tv(anlg)\tvoltage
\t2\tcount\tvoltage
Values:
0\t0.0
\t0.1
\t1.0

1\t1e-9
\t0.2
\t2.0

"
# ⚠ `Amb`/`amb` exist ONLY here, and they are what makes the D2-skip check able
# to fail. `COUNT` cannot do it: the CLEAN slot answers it on its own and comes
# first, so the poisoned slot is never on the critical path and a mutation that
# ACCEPTS an ambiguous slot instead of skipping it changes nothing (measured —
# the check stayed green through exactly that inversion). A token only the
# poisoned slot could answer has nowhere else to land.
wr $tmp/collide.raw "Title: collide
Date: Sun Aug 16 00:00:00 2026
Plotname: Transient Analysis
Flags: real
No. Variables: 6
No. Points: 2
Variables:
\t0\ttime\ttime
\t1\tCount\tvoltage
\t2\tcount\tvoltage
\t3\tv(OnlyHere)\tvoltage
\t4\tAmb\tvoltage
\t5\tamb\tvoltage
Values:
0\t0.0
\t1.0
\t2.0
\t3.0
\t4.0
\t5.0

1\t1e-9
\t1.5
\t2.5
\t3.5
\t4.5
\t5.5

"

proc viewer_ready {top} {
  for {set i 0} {$i < 300} {incr i} {
    update
    if {[winfo exists $top.drw] && [winfo ismapped $top.drw]} { return 1 }
    after 20
  }
  return 0
}

set no_recent_files 1
set f [open [file join $tmp library.defs] w]
puts $f "DEFINE sky130_tests [file join $repo sky130A xschem_libs sky130_tests]"
puts $f "DEFINE sky130_fd_pr [file join $repo sky130A xschem_libs sky130_fd_pr]"
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $tmp library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

set cellroot  [file join $repo sky130A xschem_libs sky130_tests test_nfet_final]
set statefile [file join $cellroot ngspice_state1 test_nfet_final.state]
set st [ase::state_load $statefile]
dict set st rundir [file join $tmp run]
set sstate [file join $tmp session.state]
ase::state_save $sstate $st
set tok [ase::session_key sky130_tests test_nfet_final ngspice_state1]
ase::session_open $tok $sstate

eqcheck CS92-viewer-opens [pcall wviewer::open $tok] 1
set vtop [wviewer::window_for $tok]
set vdrw $vtop.drw
if {![viewer_ready $vtop]} {
  puts "NOTE: CS92*/CS93*/CS95* not run (viewer canvas never mapped)"
  catch {wviewer::close $tok}
} else {

xschem new_schematic switch $vdrw
xschem raw clear
xschem raw read $tmp/clean.raw tran
xschem raw read $tmp/collide.raw tran
xschem raw switch 0

set dbs [pcall wviewer::signal_list_all $tok]
eqcheck CS92b-two-databases [llength $dbs] 2
# THE NEW KEY. Each slot carries its OWN lookup flag, read while the engine was
# standing on it — `xschem raw case` can only ever answer for the current one.
eqcheck CS92c-each-slot-carries-its-own-case \
  [list [wviewer::dget [lindex $dbs 0] case x] [wviewer::dget [lindex $dbs 1] case x]] {0 0}
# the ordinary resolve: a name only the FOREIGN database has
# ⚠ EVERY `resolve_signal_db` CALL IN THIS LEG IS HOISTED ONTO ITS OWN LINE,
# for the reason CS92f2's comment gives and five earlier checks ignored: written
# inline as `[pcall dict get [wviewer::resolve_signal_db ...] idx]` the inner
# call runs during ARGUMENT SUBSTITUTION, before `pcall` exists to catch it, so
# a mutation that makes the proc throw kills the file with no `RESULT:` line at
# all — which an automated sabotage driver reads as "nothing went red".
set r92d [pcall wviewer::resolve_signal_db $tok {v(OnlyHere)}]
eqcheck CS92d-foreign-name-resolves [pcall dict get $r92d idx] 1
# ⚠ D2 ACROSS DATABASES, and the two halves are SEPARATE checks because they
# fail to different mutations. CS92e is the useful half: a clean slot still
# answers a token another slot has poisoned. It does NOT pin the skip — slot 0
# answers `COUNT` first, so an ambiguous slot could be accepted or skipped and
# this line would read 0 either way (measured).
set r92e [pcall wviewer::resolve_signal_db $tok COUNT]
eqcheck CS92e-d2-poisoned-slot-still-lets-a-clean-one-answer \
  [pcall dict get $r92e idx] 0
# ⚠⚠ THIS is the skip. `Amb`/`amb` are in slot 1 ONLY, so the folded query
# `AMB` has exactly one slot that could answer and that slot is poisoned. D2
# says decline to guess WHICH of the two the user meant, so the answer is
# nothing — an accepted ambiguous slot would return idx 1 here.
eqcheck CS92e2-ambiguous-slot-is-skipped-with-nowhere-else-to-go \
  [pcall wviewer::resolve_signal_db $tok AMB] {}
# ... and the name really is there, so CS92e2's {} is D2's refusal and not an
# absent signal.
set r92e3 [pcall wviewer::resolve_signal_db $tok Amb]
eqcheck CS92e3-the-exact-spelling-of-the-poisoned-name-resolves \
  [pcall dict get $r92e3 idx] 1
# ⚠ THE TIE-BREAK IS "THE FIRST SLOT THAT RESOLVES", NOT "EXACT BEATS FOLDED",
# and this check exists because the first draft of it assumed otherwise and
# went red. `Count` is stored EXACTLY in slot 1; slot 0 holds `count`, which
# slot 0's folded rung answers — so slot 0 wins, because signal_list_all yields
# the CURRENT database first (settled decision 4). Pinned rather than "fixed":
# ranking an exact hit in a foreign database above a folded hit in the one the
# user is standing on would change the answer for every existing single-DB add.
set r92f [pcall wviewer::resolve_signal_db $tok Count]
eqcheck CS92f-current-db-wins-even-on-a-folded-hit [pcall dict get $r92f idx] 0
# ... and slot 1 judged ALONE really does tell the two apart, which is what
# makes CS92e's skip D2 rather than an accident of ordering.
set nm1 [dict get [pcall wviewer::db_by_index $tok 1] names]
# ⚠ the index is built through `pcall` on its OWN line, not inline in the two
# calls below: a sabotage that deletes `name_index` would otherwise throw during
# argument substitution and ABORT the file with no RESULT line, under which
# every check reads as "nothing went red" (the trap item 2 recorded).
set nmi1 [pcall wviewer::name_index $nm1]
eqcheck CS92f2-slot1-exact-spelling-resolves \
  [pcall wviewer::name_lookup $nmi1 Count 1] ok
eqcheck CS92f3-slot1-folded-key-is-ambiguous \
  [pcall wviewer::name_lookup $nmi1 COUNT 1] ambiguous
eqcheck CS92g-absent-everywhere [pcall wviewer::resolve_signal_db $tok v(nope)] {}
# the v()-wrap rung reaches across databases too
set r92h [pcall wviewer::resolve_signal_db $tok OnlyHere]
eqcheck CS92h-bare-name-wraps [pcall dict get $r92h idx] 1

# --- A: add_trace's named-database arm ---------------------------------------
# Slot 1 is made `distinguish`, so its folded rungs must go off — for a caller
# standing on slot 0, which is NOT distinguish. That is the residue item 2
# declared and item 5 closes.
xschem raw switch 1
eqcheck CS93-set-foreign-distinguish [pcall xschem raw case distinguish] 1
xschem raw switch 0
eqcheck CS93b-current-db-still-folds [pcall xschem raw case] 0
set dbs2 [pcall wviewer::signal_list_all $tok]
eqcheck CS93c-foreign-slot-reports-distinguish \
  [list [wviewer::dget [lindex $dbs2 0] case x] [wviewer::dget [lindex $dbs2 1] case x]] {0 1}
set hit1 [pcall wviewer::db_by_index $tok 1]
eqcheck CS93d-db_by_index-carries-case [wviewer::dget $hit1 case x] 1
# the named-DB arm judges by THAT slot's flag: an exact spelling passes, a
# folded one is refused, while the CURRENT database would have folded both
eqcheck CS93e-named-db-exact-accepted \
  [pcall wviewer::validate_rpn {v(OnlyHere) 2 *} [dict get $hit1 names] \
     [expr {[wviewer::dget $hit1 case 0] ? 0 : 1}]] {}
eqcheck CS93f-named-db-folded-refused \
  [pcall wviewer::validate_rpn {v(onlyhere) 2 *} [dict get $hit1 names] \
     [expr {[wviewer::dget $hit1 case 0] ? 0 : 1}]] \
  {unknown token 'v(onlyhere)' (not an operator/function, number or raw variable)}
# and the same list judged by the CURRENT database's mode (the pre-item-5
# behaviour) would have ACCEPTED it — the check that makes the one above mean
# something
eqcheck CS93g-the-pre-item5-answer-was-accept \
  [pcall wviewer::validate_rpn {v(onlyhere) 2 *} [dict get $hit1 names] 1] {}
# resolve_signal_db honours it too: slot 1 no longer answers a folded query,
# and no other slot has the name
eqcheck CS93h-resolve-honours-the-foreign-flag \
  [pcall wviewer::resolve_signal_db $tok {v(onlyhere)}] {}
set r93i [pcall wviewer::resolve_signal_db $tok {v(OnlyHere)}]
eqcheck CS93i-resolve-still-takes-the-exact-spelling [pcall dict get $r93i idx] 1
# ⚠ AND THE WHOLE GESTURE, not just the argument the arm computes. `add_trace`
# with an explicit `db` is the browser's own route (a row id carries the
# database the user clicked), so this drives the arm rather than re-deriving
# what it should have passed. The refusal must NAME the database, which is
# DEFECT 2's rule, and the folded spelling must be the one that is refused.
wviewer::set_graphs $tok [list [dict replace [wviewer::empty_graph] \
  x1 0 x2 1e-9 y1 -1 y2 5]]
eqcheck CS93k-add_trace-named-db-exact-accepted \
  [pcall wviewer::add_trace $tok 0 {v(OnlyHere)} {} 4 1] {}
set cs93r [pcall wviewer::add_trace $tok 0 {v(onlyhere)} {} 5 1]
check CS93l-add_trace-named-db-folded-refused \
  [expr {[string match "*is not in*" $cs93r] \
      && [string match "*unknown token 'v(onlyhere)'*" $cs93r]}] "(got '$cs93r')"
xschem raw switch 1
eqcheck CS93m-clear-foreign-distinguish [pcall xschem raw case 0] 1
xschem raw switch 0
# with the flag cleared the SAME call is accepted, so CS93l is the flag's doing
# and not a name that was never there
eqcheck CS93n-folded-accepted-once-the-flag-is-off \
  [pcall wviewer::add_trace $tok 0 {v(onlyhere)} {} 6 1] {}

# --- C(viewer): the Options > Case Mode control ------------------------------
set cmm $vtop.wvmenubar.options.casemode
eqcheck CS95-cascade-exists [pcall winfo exists $cmm] 1
eqcheck CS95b-entry0-is-the-disabled-readout \
  [list [pcall $cmm entrycget 0 -state] [pcall $cmm type 0]] {disabled command}
eqcheck CS95c-four-radio-entries \
  [list [pcall $cmm type 2] [pcall $cmm type 3] [pcall $cmm type 4] [pcall $cmm type 5]] \
  {radiobutton radiobutton radiobutton radiobutton}
# ⚠ NO NEW TOP-LEVEL CASCADE: test_wave_viewer G2 pins the menubar's cascade set
# to exactly {File View Graph Cursors Options}, so this must live under Options.
eqcheck CS95d-lives-under-options \
  [pcall $vtop.wvmenubar.options entrycget end -label] {Case Mode}
# THE POSTCOMMAND is the only thing that asks the engine, and it fills BOTH the
# readout and the radio tick. This raw carries no `Option:` header and the
# session's schematic owns no comparable name, so the honest answer is
# `unknown none` — B2b, not `fold`.
# ⚠⚠ POSTED FOR REAL, not just called. The first cut of this leg invoked
# `casemode_menu_post` directly, and a sabotage that removed the cascade's
# `-postcommand` stayed GREEN at 110/110 — the proc worked, and nothing on
# earth would ever have called it. Tk fires -postcommand when the menu is
# posted, so posting it is the only thing that tests the WIRING. The sentinel
# label is what makes the rebuild observable.
pcall $cmm entryconfigure 0 -label {SENTINEL}
pcall $cmm post 0 0
pcall update
pcall $cmm unpost
pcall update
eqcheck CS95e0-posting-the-menu-fires-the-refresh [pcall $cmm entrycget 0 -label] \
  {Case mode: unknown — nothing could tell}
pcall $cmm entryconfigure 0 -label {SENTINEL}
pcall wviewer::casemode_menu_post $tok $cmm
eqcheck CS95e-readout-after-post [pcall $cmm entrycget 0 -label] \
  {Case mode: unknown — nothing could tell}
eqcheck CS95f-pick-follows-the-engine [pcall set ::wviewer::casemodepick($tok)] auto
eqcheck CS95g-cache-filled-by-the-post [pcall wviewer::casemode_cached $tok] {unknown none}
# THE OVERRIDE. It writes the EXPLICIT source — ranked first of B2a's four — and
# nothing else: the lookup flag is untouched, so the database is NOT re-read.
# ⚠ THE IN-MEMORY RENAME IS THE ORACLE FOR "IT DID NOT RE-READ", and a bare
# name-list comparison is NOT: a re-read of the same file gives back the same
# names, so it looks identical to having done nothing. `xschem raw rename` is
# an in-memory-only change, so it SURVIVES if nothing re-read and is GONE if
# something did. Item 1 used exactly this technique to prove the opposite
# direction (CS24/CS25, that `xschem raw case <mode>` really does re-read).
eqcheck CS95h0-mark-the-database \
  [pcall wviewer::in_ctx $tok {xschem raw rename count zz_casemark}] 1
eqcheck CS95h-override-takes [pcall wviewer::set_case_mode $tok distinguish] 1
eqcheck CS95i-resolution-now-says-explicit [pcall wviewer::casemode_cached $tok] \
  {distinguish explicit}
pcall wviewer::casemode_menu_post $tok $cmm
eqcheck CS95j-readout-follows [pcall $cmm entrycget 0 -label] \
  {Case mode: distinguish — your setting}
eqcheck CS95k-tick-follows [pcall set ::wviewer::casemodepick($tok)] distinguish
# ⚠⚠ THE WIDGET, NOT THE PROC. CS95h/CS95i/CS95k call `set_case_mode` directly,
# which is the exact hole CS95e0 was written to close on the -postcommand half
# and which was left open on this one: replacing the radiobutton's
# `-command [list wviewer::set_case_mode $token $cm_m]` with a no-op leaves a
# dead control that every other check in this file calls fine (measured — the
# suite stayed fully green through it). `invoke` fires -command exactly as a
# click does. Entry 2 is `auto` and entry 5 `distinguish`, the order
# `casemode_choices` returns.
# ⚠ EACH INVOKE MOVES OFF THE VALUE THE PREVIOUS ONE LEFT, so a dead -command
# fails BOTH: entering here the override is `distinguish`, so a no-op radio
# leaves `distinguish` where CS95k2 wants `preserve` and CS95k3 wants `unknown`.
pcall $cmm invoke 4
eqcheck CS95k2-a-mode-radio-writes-the-override \
  [pcall wviewer::in_ctx $tok {xschem raw casemode -explicit}] preserve
pcall $cmm invoke 2
eqcheck CS95k3-the-auto-radio-clears-it \
  [pcall wviewer::in_ctx $tok {xschem raw casemode -explicit}] unknown
# ⚠⚠ THE RULING THIS PINS: the control does NOT touch Raw.case_sensitive. Its
# setter re-reads the file (scheduler.c:10697), and item 3 separated reporting
# from acting on purpose (CS59e). A menubar pick must not silently rebuild a
# loaded database.
eqcheck CS95l-lookup-flag-untouched [pcall wviewer::in_ctx $tok {xschem raw case}] 0
eqcheck CS95m-database-not-re-read \
  [pcall wviewer::in_ctx $tok {xschem raw list}] "time\nv(anlg)\nzz_casemark"
eqcheck CS95m2-restore-the-mark \
  [pcall wviewer::in_ctx $tok {xschem raw rename zz_casemark count}] 1
# `auto` clears the override and the resolution falls back through the other
# three sources — which, on this file, is back to `unknown none`.
eqcheck CS95n-auto-clears [pcall wviewer::set_case_mode $tok auto] 1
eqcheck CS95o-back-to-unknown [pcall wviewer::casemode_cached $tok] {unknown none}
# ⚠ THE CACHE IS ACTUALLY READ, which an earlier revision's was not: both engine
# sites called `casemode_refresh` and it re-asked unconditionally, so the array,
# its invalidation sites and the checks around them guarded a value nothing
# consumed. A warm entry now short-circuits the engine — poked to a value the
# engine would never return, so a hit is unmistakable.
set ::wviewer::casemode($tok) {preserve header}
eqcheck CS95o2-a-warm-entry-short-circuits-the-engine \
  [pcall wviewer::casemode_refresh $tok] {preserve header}
# ... and the one caller that has just CHANGED the answer forces past it, or the
# readout would show the pre-change verdict for the rest of the session.
eqcheck CS95o3-set-case-mode-forces-past-the-cache-1 [pcall wviewer::set_case_mode $tok fold] 1
eqcheck CS95o3b-set-case-mode-forces-past-the-cache-2 \
  [pcall wviewer::casemode_cached $tok] {fold explicit}
# ⚠ THE ACTION LOG. `set_case_mode` is a state-changing menubar command and
# every sibling in this file logs one line per use (set_plot_mode, set_plot_dest,
# grid_toggle, browser_toggle); a replay that skipped it would leave the replayed
# session answering a different `xschem raw casemode`. Spied by rename, which is
# the only way to see a `log_action` line without a live action log.
set ::CSLOG {}
rename ::wviewer::log_action ::wviewer::log_action_cs95y
proc ::wviewer::log_action {line} { lappend ::CSLOG $line ; ::wviewer::log_action_cs95y $line }
pcall wviewer::set_case_mode $tok preserve
rename ::wviewer::log_action {}
rename ::wviewer::log_action_cs95y ::wviewer::log_action
eqcheck CS95y-the-override-is-action-logged $::CSLOG \
  [list [list wviewer::set_case_mode $tok preserve]]
pcall wviewer::set_case_mode $tok auto
# THE PERFORMANCE CONTRACT. attach_raw DROPS the cache; it does not recompute
# it, because `raw casemode` costs up to 189 ms with no cache behind it and
# nothing needs the value until a menu is posted.
pcall wviewer::casemode_menu_post $tok $cmm
eqcheck CS95p-cache-warm-before-attach [pcall wviewer::casemode_cached $tok] {unknown none}
pcall wviewer::attach_raw $tok $tmp/clean.raw tran
eqcheck CS95q-attach_raw-drops-the-cache [pcall wviewer::casemode_cached $tok] {}
# ⚠⚠ THE OVERRIDE'S LIFETIME, WHICH NOTHING COVERED. `explicit_case_mode` is a
# field on the Raw and `ase::attach_dbs` does clear+read, so the object carrying
# the user's setting is destroyed by a re-run — the commonest viewer action
# there is. Measured before the fix: `-explicit` went from `distinguish` to
# `unknown`, `casemodepick` was unset, and the next menu post silently showed
# the tick back on `auto`. The C side already refuses this loss on ITS re-read
# path (`keep_explicit`, scheduler.c:10125/10148, "losing it here would mean an
# unrelated `raw case` set silently discarding something the user said").
# RULED per-FILE per-WINDOW, and both halves are pinned.
eqcheck CS95t-set-an-override-to-carry [pcall wviewer::set_case_mode $tok distinguish] 1
pcall wviewer::attach_raw $tok $tmp/clean.raw tran
eqcheck CS95u-the-override-survives-a-re-attach-of-the-same-file \
  [pcall wviewer::in_ctx $tok {xschem raw casemode -explicit}] distinguish
eqcheck CS95v-and-the-radio-tick-comes-back-with-it \
  [pcall set ::wviewer::casemodepick($tok)] distinguish
# ... but NOT onto a different file. A statement about one simulator's output is
# not a statement about another's, so a different path gets a fresh four-source
# detection.
pcall wviewer::attach_raw $tok $tmp/collide.raw tran
eqcheck CS95w-a-different-file-gets-a-fresh-detection \
  [pcall wviewer::in_ctx $tok {xschem raw casemode -explicit}] unknown
# ⚠⚠ WHICH Raw THE OVERRIDE LANDS ON, and it is ONE of them. An earlier revision
# of this feature claimed in two places that "item 4's cross-probe senders
# consult that answer"; they do not. `hilight_sender_case_mode()` (hilight.c:364)
# reads `xctx->raw` of the window the Ctrl-K gesture happens in — the SCHEMATIC
# window — and the viewer is a separate context with its own Raw. This loads the
# SAME FILE into the schematic window and shows the two answers diverging. The
# call is made from OUT HERE, standing in the schematic ctx, so a `set_case_mode`
# that failed to loan into the viewer would fail CS95x2 as well.
xschem new_schematic switch $mainwp
catch {xschem raw clear}
eqcheck CS95x-schematic-window-loads-the-same-file \
  [pcall xschem raw read $tmp/clean.raw tran] 1
eqcheck CS95x2-the-override-lands-on-the-viewers-raw \
  [list [pcall wviewer::set_case_mode $tok preserve] \
        [pcall wviewer::in_ctx $tok {xschem raw casemode -explicit}]] {1 preserve}
eqcheck CS95x3-and-not-on-the-schematic-windows-raw \
  [pcall xschem raw casemode -explicit] unknown
catch {xschem raw clear}
xschem new_schematic switch $vdrw
# and `forget` leaves no per-token entry behind
pcall wviewer::casemode_menu_post $tok $cmm
check CS95r-entry-exists-before-close [info exists ::wviewer::casemode($tok)] {}
catch {wviewer::close $tok}
# all THREE arrays, `casemodeuser` included — it is deliberately the one
# `casemode_invalidate` does NOT drop, so `forget` is the only thing that can.
check CS95s-no-leak-after-close \
  [expr {![info exists ::wviewer::casemode($tok)] \
      && ![info exists ::wviewer::casemodepick($tok)] \
      && ![info exists ::wviewer::casemodeuser($tok)]}] \
  "(casemode [info exists ::wviewer::casemode($tok)] pick [info exists ::wviewer::casemodepick($tok)] user [info exists ::wviewer::casemodeuser($tok)])"

}
}

catch {xschem raw clear}
catch {test_scratch_drop $tmp}
puts "----"
puts "test_wave_casemode: $npass passed, $fail failed"
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
