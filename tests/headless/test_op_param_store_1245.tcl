# tests/headless/test_op_param_store_1245.tcl — item B2 of
# doc/claude/op_param_batch/PLAN.md (feature 1245, the OP parameter lists).
# Spec: doc/claude/specs/op_param_lists.md §4.3 (the class map) and §4.4 (the
# settings file). Rulings: doc/claude/op_param_batch/DECISIONS.md — D-4, D-7 and
# DRIVER DECISIONS DD-2 and DD-3, which are this item's central rulings.
#
# ============================================================================
# WHAT IS UNDER TEST
# ============================================================================
# B2 adds ONE new pure-Tcl file, src/op_param_lists.tcl, and NO UI, NO C and no
# deck change. It holds four things:
#   (a) the CLASS MAP        `type=` token -> broad class, DATA and not a switch
#   (b) the ORDERED LISTS    per class (DD-2's primary key) and per flavor
#                            (DD-2's optional override), for list names
#                            `annotation` and `summary`
#   (c) the PDK SEED         D-7: a class with no user entry answers what the
#                            PDK registered through op_annot::register
#   (d) the SETTINGS FILE    <pwd>/.xschem/op_param_lists.conf, with
#                            $USER_CONF_DIR/op_param_lists.conf as the
#                            user-global fallback — read by a STRICT parser and
#                            written with the write-beside-and-move idiom.
#
# ⚠ TWO FILES, NOT ONE. Spec §4.4 conflates them and DD-3 corrects it:
# src/op_param_lists.tcl is the IMPLEMENTATION (Tcl code, shipped, installed);
# the SETTINGS FILE is op_param_lists.conf and is DATA. There is no
# `.tcl` settings file anywhere in this suite, deliberately.
#
# ============================================================================
# THE API THIS SUITE PINS — READ THIS BEFORE IMPLEMENTING
# ============================================================================
# The plan's fix_summary spells `owns` and `effective` with the LIST NAME
# FIRST and `set_list` with the SCOPE first. That is an internal inconsistency
# in the plan, not a ruling, and a store whose three sibling verbs disagree
# about their own argument order is a defect waiting for its first caller. This
# suite reconciles them onto ONE order — the order the settings file's own
# grammar uses, `<scope> <key> <listname>` — and says so here rather than
# leaving item B5 to discover it:
#
#   ::op_param_lists::class      <type-token>                    -> broad class
#                                (identity for a token nobody mapped; NEVER a
#                                raise and never {} — see decision 6 below)
#   ::op_param_lists::set_class  <type-token> <broad-class>      -> the class
#   ::op_param_lists::seed       <class>                         -> ordered
#                                {label param kind} triples from the registry
#   ::op_param_lists::owns       <scope> <key> <listname>        -> 1 | 0
#   ::op_param_lists::get_list   <scope> <key> <listname>        -> triples, {}
#                                when unowned
#   ::op_param_lists::set_list   <scope> <key> <listname> <triples> -> 1 | 0
#   ::op_param_lists::effective  <class> <listname> ?cellname?   -> triples
#   ::op_param_lists::reset                                      -> {}
#   ::op_param_lists::said                                       -> a LIST of
#                                report strings, ONE PER REPORT (llength is the
#                                report count; a newline-joined blob reds every
#                                report-count row below)
#   ::op_param_lists::said_clear                                 -> {}
#   ::op_param_lists::conf_path  <project|user>                  -> a path
#   ::op_param_lists::load_conf  <path>                          -> 1 | 0
#   ::op_param_lists::load                                       -> the LIST OF
#                                PATHS actually read, in read order
#   ::op_param_lists::write_conf ?path?                          -> 1 | 0
#   ::op_param_lists::write_body <fp>                            -> 1
#   ::op_param_lists::apply      ?type ...?                      -> the list of
#                                types re-registered through op_annot::register
#
#   scope     : `class` | `flavor`      (flavor keys are cell-name GLOBS)
#   listname  : `annotation` | `summary`
#               `all` is spec §4.2's list 3 and is NEVER PERSISTED (D-4) — it
#               is live from the simulator, so the store answers {} for it,
#               `owns` answers 0 for it, and a conf row naming it is reported
#               and skipped.
#   the triple: {<label> <rawparam> <kind>} — THREE fields, all three carried.
#
# ============================================================================
# THE SETTINGS-FILE GRAMMAR THIS SUITE PINS (DD-3: data, never sourced)
# ============================================================================
#   # anything after a leading # is a comment ; blank lines are skipped
#   version 1
#   class  <type-token> <broad-class>
#   list   <scope> <key> <listname>                             # an OWNED list,
#                                                               # possibly EMPTY
#   param  <scope> <key> <listname> <label> <rawparam> <kind>   # appended
#
# Fields are WHITESPACE-DELIMITED and are split with `regexp -inline -all
# {\S+}`, NEVER with `llength`/`lindex` on the line: measured on this tree,
# `llength {mos annotation { id 0}` RAISES `unmatched open brace in list`, so a
# stray `{` in a teammate's file would kill the reader from inside. Row X3
# carries that `{`.
#
# Every row is SELF-CONTAINED, so skipping a malformed one cannot silently
# reassign the rows after it. A `param` row implicitly declares its list; the
# `list` verb exists only so an EMPTIED list can be expressed, and losing a
# `list` line degrades to the PDK seed, which is the safe direction.
#
# ⚠ THE FIRST `param` OR `list` ROW FOR A GIVEN (scope,key,listname) IN A FILE
# CLEARS WHAT AN EARLIER TIER PUT THERE. That is what makes the project file
# WIN over the user-global one (D-7) rather than append to it — row T2. Within
# one file the rows then accumulate in file order, and a repeated LABEL replaces
# in place and is reported — row P3.
#
# ⚠ A REPORT LINE MUST NOT BEGIN A LINE WITH `FAIL:` AT COLUMN 0.
# full_audit.sh's has_failure() is `^(FAIL[: !]|...)`, so a store that echoed
# its reports to stderr starting with that word would red its own suite from
# the outside. Say "op_param_lists: ..." like action_registry.tcl:329 does.
#
# ============================================================================
# THE THREE MEASUREMENTS THIS SUITE IS BUILT ON, RE-CONFIRMED HERE
# ============================================================================
# 1. THE SEED IS A TRIPLE, NOT A NAME, AND IHP IS THE PROOF. sky130A:401 and
#    gf180mcuD:107 are `{id id 0}`; ihp-sg13g2/sg13g2_procs.tcl:758 is
#    `{id ids 0}` — LABEL `id`, PARAM `ids`, THEY DIFFER. A store that keeps
#    only the name round-trips sky130 and gf180 PERFECTLY and silently rewrites
#    IHP's `id` row into `ids`. Sections S and W therefore run against the IHP
#    descriptors, sourced live at the top of section S — a suite built on
#    sky130's shape cannot see this failure at all.
# 2. THE CLASS MAP IS NOT ONTO. IHP registers `vertical_npn` and NOT
#    `vertical_pnp`, though §4.3's map names both, and `op_annot::descriptor
#    vertical_pnp` answers {} without raising. Row S2.
# 3. THE CLASS-SEED CONFLICT DOES NOT ARISE IN THIS TREE. All three PDKs
#    register `nmos` and `pmos` with byte-identical params, so the
#    first-registered-wins rule is untestable against shipped data. Row S3
#    builds a SYNTHETIC pair rather than leaving the rule unexercised.
#
# ⚠ "FIRST REGISTERED WINS" IS SPELLED "FIRST IN LEXICAL ORDER OF THE `type=`
# TOKEN". `::op_annot::desc` is a Tcl ARRAY; `array names` answers hash order
# and op_annot publishes no enumerator, so registration order is not available
# to any caller. Lexical order is deterministic and coincides with registration
# order for every PDK here (each registers via `foreach t {nmos pmos}`). The
# missing enumerator is filed, not fixed, by this item.
#
# ⚠ AND THE SEED NEVER ENUMERATES `::op_annot::desc`. The candidate types for a
# class are the tokens the CLASS MAP sends there, plus the class name itself,
# sorted; each is looked up through the published `op_annot::descriptor`. So
# the store reaches into no other namespace's internals, and `seed` on a class
# nobody registered is {} rather than a raise.
#
# ============================================================================
# B1's LESSON, PAID FORWARD: THE INPUTS MOST LIKELY TO BREAK THIS PARSER
# ============================================================================
# B1 was GREEN AT 37/37 while its seam returned `nan`, because its suite had no
# non-finite row. A green count is a statement about the FENCE. So the fence
# was named BEFORE the rows were written, and every one of these has a row:
#   duplicate class row (P3) · duplicate param label in one list (P3) ·
#   a short row (P2) · a too-long row (P2) · a non-integer kind (P2) ·
#   an unknown verb (P2) · an unknown scope (P2) · an unknown listname (P2) ·
#   a `param ... all ...` row, D-4 (P2) · an unknown `version` (P2b) ·
#   CRLF (P4) · a truncated last line with no newline (P4) ·
#   a non-ASCII UTF-8 label read in a DIFFERENT LOCALE (P5) ·
#   a class no PDK registered (S2) · a class the map does not name (M2) ·
#   an entry whose label differs from its param, the IHP shape (S1) ·
#   an EMPTIED list that must not fall back to the seed (W3) ·
#   a flavor entry for a class with no class entry (F1b) ·
#   a whitespace-bearing field offered to the writer (W4) ·
#   a payload that WOULD run if the file were sourced (X1) or substituted (X2).
#
# ============================================================================
# WHICH ROWS ARE RED BEFORE B2 LANDS, AND WHY
# ============================================================================
# Measured against the unmodified tree (HEAD 58144934, src/xschem built
# 2026-09-03 03:10): there is no src/op_param_lists.tcl, no ::op_param_lists
# namespace, no source line in src/xschem.tcl, and
# `grep -c op_param_lists.tcl src/Makefile` is 0. Every call below therefore
# answers NOPROC through ol_ans, and every structural row answers NOFILE.
# The RED/GREEN split is printed by the run itself; see the receipt.
# The rows that are GREEN BEFORE THE CHANGE are controls and fences and are
# NOT evidence for B2 — each says only that B2 broke nothing:
#   S0    the registry B2 seeds from is live and carries the IHP triple
#   P5c   the LC_ALL=C child really does run in a non-utf-8 locale (without
#         this control, row P5 could pass vacuously in a utf-8 child)
#   C0    the three PDK recovery recipes (invariant I5) are present and must
#         still be present afterwards
#   R1    registration
#   H1    hygiene
#
# ⚠ EVERY GOLDEN BELOW WAS RUN AGAINST A SCRATCH PROTOTYPE OF THE STORE (the
# plan's own algorithm, OUTSIDE the repo, sourced ahead of this file) BEFORE
# THIS FILE WAS FINISHED, and the prototype scores 33 of 39. The six it cannot
# reach are exactly the six only the DELIVERABLE can — J2 J3 J4 X4 (the file
# must be at src/op_param_lists.tcl, sourced, installed), C1 (the three PDK
# comments) and P5 (the CHILD PROCESS must have the store, which only a shipped
# and sourced file gives it). P5's three goldens were confirmed separately by
# running its child by hand with the prototype sourced: OPLLIST came back
# 7b6964c3a9206964c3a920307d, the written file carried the utf-8 bytes twice
# and the latin-1 bytes zero times — the exact literals below. So a red row
# here is a statement about the tree, not about an unreachable golden.
#
# EIGHT SABOTAGE VARIANTS WERE RUN AGAINST THAT PROTOTYPE AND EVERY ONE WAS
# CAUGHT. Rows named are those RED BEYOND the six structural ones above:
#   the store keeps only the NAME, not the triple  -> S1b P1 P2b P3 X1 W3
#   the writer opens the real file, no `.new`      -> W1
#   `catch {uplevel #0 $line}` in the parser       -> X1 X2   ⚠ AND NOTHING ELSE
#   `owns` always answers 0 (the user never wins)  -> W3 T1 T2 F1 F1b F2 A1
#   the flavor lookup is skipped                   -> F1 F1b
#   `set_class` is a no-op (the map is frozen)     -> M3 S3 P1 P3
#   the parser stores nothing at all               -> M3 S1b P1 P2 P2b P3 P4
#                                                     X1 X2 X3 W3 T2 T3
#   `-encoding utf-8` unpinned on both channels    -> P5, and ONLY P5
#
# ⚠ TWO OF THOSE MEASUREMENTS CONTRADICT THE PLAN'S PREDICTIONS, AND BOTH
# CORRECTIONS ARE THE POINT OF THE SECTION:
#   * `uplevel #0 $line` reds X1 and X2 AND NOTHING ELSE. X3, P2 and P3 stay
#     GREEN — the payload runs, the `catch` swallows the Tcl error, and the
#     ordinary parse then proceeds normally. A suite that read a raise as the
#     evidence would score that file safe. X1 and X2 assert a SENTINEL VARIABLE
#     and a FILE ON DISK for exactly this reason.
#   * a DEAD parser does NOT leave the X rows green, because X1/X2/X3 each
#     carry a positive assertion (the data row after the payload really loaded,
#     and the awkward labels really round-tripped) beside the negative one.
#   * `-encoding utf-8` is invisible to every row but P5, and invisible even to
#     P5 in-process: under the default utf-8 locale every assertion passes. It
#     is visible only in the LC_ALL=C child, and there only on the READ side —
#     a file read as latin-1 and written back as latin-1 round-trips to the
#     same bytes, so P5's FIRST term is the load-bearing one.
#
# ============================================================================
# ITEM B2b ADDED SECTION D AND ROW C2, AND REVISED ROW A1 (1285, 1289, DD-6)
# ============================================================================
# 39 checks -> 51. B2b is the DISPLAY half of the same feature and its rows had
# nowhere else to go: test_op_annot (485 --nogui / 492 Tk) and
# test_annot_declutter_1244 (134) are pinned BY NAME AND COUNT as a hard
# acceptance row for that item, and a suite whose count is pinned cannot also
# be where new rows land.
#
# WHAT B2b ADDS, IN ONE LINE: `op_annot::text` and `op_annot::_cards_for` read
# THE SAME `params` list, so under DD-4's union the sheet gets WIDER when the
# user trims it. DD-6 adds a second descriptor key the display prefers; DD-9
# keeps `derived` rows reading the RUN so a hidden operand still computes.
# Section D's own header carries the measurement, the two amendment guarantees
# and the three premise corrections.
#
# ⚠ ROW A1's `params` GOLDEN MOVED. It golded the annotation list ALONE, which
# is HEAD's behaviour and issue 1280; under DD-4 it is the UNION. A1's other
# seven legs are untouched and a `shown` leg was added beside them.
#
# ⚠ AND TWO OF SECTION D's ROWS CANNOT BE RED AT HEAD — said out loud in that
# section's header rather than left for a reader to discover. HEAD reads no
# display key at all, so a MALFORMED one is inert (D6) and no subset can be
# violated through it. D6 is red against the presence-only guard item B2a-2
# shipped, which is the state it exists to catch.

# ============================================================================
# THIS SUITE NEEDS NO X, AND full_audit.sh IS NOT EDITED
# ============================================================================
# There is no `bind` and no `event generate` here, so it runs identically under
# --nogui and under a display. full_audit.sh selects by GLOB
# (`ls "$HERE"/test_*.tcl | sort`, :393) and its three named lists are OPT-INS;
# row R1 says out loud that this file is in none of them. The audit denominator
# moves 379 -> 380 — diff the baseline by NAME and STATUS, never by count.
#
# Run from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_op_param_store_1245.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# --- locations (cwd-independent) --------------------------------------------
set here [file normalize [file dirname [info script]]]      ;# tests/headless
set repo [file normalize [file join $here .. ..]]           ;# repo root
source [file join $here scratch.tcl]
set scratch [test_scratch op_param_store]
set OL_AUDIT [file join $here full_audit.sh]
set OL_TCL   [file join $repo src op_param_lists.tcl]
set OL_XTCL  [file join $repo src xschem.tcl]
set OL_MKIN  [file join $repo src Makefile.in]
set OL_MK    [file join $repo src Makefile]
set OL_BIN   [file join $repo src xschem]

## Anything this session might be tempted to write goes to the scratch dir.
set ::netlist_dir $scratch

# ============================================================================
# THE ANSWER DISCIPLINE — AN ABSENT STORE MUST NEVER SATISFY A GOLDEN
# ============================================================================
# Copied from rs_ans (tests/headless/test_rdw_seam_1245.tcl:196). Two rules,
# both lessons this batch already paid for:
#   * a row must be able to FIRE in the RED state. A bare call to a proc that
#     does not exist raises, and a raise at global level under --pipe stops
#     Tcl_AppInit DEAD — the whole file dies mid-run with `ok` lines and NO
#     verdict (item A2's lesson 6). Every call below goes through a wrapper.
#   * "invalid command name ..." must not be able to satisfy a row expecting
#     the empty string.
proc ol_ans {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  set rc [catch {uplevel #0 [linsert $args 0 $cmd]} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}
proc ol_defined {cmd} { return [expr {[llength [info commands $cmd]] ? 1 : 0}] }
proc ol_nocomment {t} {
  set out {}
  foreach l [split $t "\n"] { if {[regexp {^\s*#} $l]} continue ; lappend out $l }
  return [join $out "\n"]
}
proc ol_body {cmd} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  if {[catch {info body $cmd} b]} { return "RAISED:$b" }
  return [ol_nocomment $b]
}
proc ol_count {hay needle} {
  if {$needle eq {}} { return 0 }
  set n 0 ; set i 0
  while {[set i [string first $needle $hay $i]] >= 0} { incr n ; incr i }
  return $n
}
proc ol_has {hay needle} { return [expr {[string first $needle $hay] >= 0 ? 1 : 0}] }
proc ol_slurp {path} {
  if {![file isfile $path]} { return {} }
  set fd [open $path r] ; fconfigure $fd -encoding utf-8
  set d [read $fd] ; close $fd ; return $d
}
## Exact bytes, for the encoding rows and for byte-identity comparisons.
proc ol_bytes {path} {
  if {![file isfile $path]} { return NOFILE }
  set fd [open $path r] ; fconfigure $fd -translation binary -encoding binary
  set d [read $fd] ; close $fd ; return $d
}
proc ol_hex {path} {
  set d [ol_bytes $path]
  if {$d eq {NOFILE}} { return NOFILE }
  return [binary encode hex $d]
}
## Write a fixture with EXACT bytes: no translation, no re-encoding. The CRLF
## and UTF-8 rows depend on this writer not helping.
proc ol_put {path bytes} {
  file mkdir [file dirname $path]
  set fd [open $path w] ; fconfigure $fd -translation binary -encoding binary
  puts -nonewline $fd $bytes ; close $fd
  return $path
}
## A conf fixture from a list of LINES, with the line ending named explicitly.
proc ol_conf {path lines {eol "\n"} {trailing 1}} {
  set t [join $lines $eol]
  if {$trailing} { append t $eol }
  return [ol_put $path [encoding convertto utf-8 $t]]
}
## The store's own report count. NOPROC-safe, and `said` MUST be a list.
proc ol_nsaid {} {
  set s [ol_ans ::op_param_lists::said]
  if {$s eq {NOPROC}} { return NOPROC }
  if {[catch {llength $s} n]} { return "BADSAID:$s" }
  return $n
}
## How many SEPARATE reports name <needle>. Counting substring hits inside one
## report is wording-dependent — a sentence that names the losing type twice
## would read as two reports — and "reported once" is a statement about the
## number of times the user is told, not about the prose.
proc ol_saidhits {needle} {
  set s [ol_ans ::op_param_lists::said]
  if {$s eq {NOPROC}} { return NOPROC }
  if {[catch {llength $s} n]} { return "BADSAID:$s" }
  set hits 0
  foreach r $s { if {[string first $needle $r] >= 0} { incr hits } }
  return $hits
}
proc ol_saidtext {} {
  set s [ol_ans ::op_param_lists::said]
  if {$s eq {NOPROC}} { return {} }
  if {[catch {join $s "\n"} t]} { return $s }
  return $t
}
proc ol_reset {} {
  ol_ans ::op_param_lists::reset
  ol_ans ::op_param_lists::said_clear
  return {}
}

# ============================================================================
# THE DISPLAY-KEY HELPERS (item B2b — rulings DD-6, its AMENDMENT, and DD-9)
# ============================================================================
# Section D below asks three questions HEAD cannot be asked directly, so the
# reading of an answer needs the same discipline `ol_ans` gives a call:
#
#   * `dict get $d shown` RAISES at HEAD (`key "shown" not known in
#     dictionary`), and a raise at global level under --pipe stops
#     Tcl_AppInit DEAD — MEASURED: the planner's own driver died mid-file at
#     its first bare `dict get ... shown`, printing four sections and no
#     verdict. `ol_dkey` answers the DATA word NOKEY instead, so a row can
#     FIRE in the red state and say WHY.
#   * a rendered annotation block is a formatted STRING, not a list, and the
#     interesting question is which LABELS reached the sheet and what value
#     each carries. `ol_rowlabels` / `ol_rowval` read the mint actions.c:2172
#     parses (`label = value`, and `label =` with nothing after it for a blank
#     row — ruling D9b's format, pinned from the C side by
#     test_annot_declutter_1244.tcl:2336).
proc ol_rc {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  return [catch {uplevel #0 [linsert $args 0 $cmd]}]
}
## one key of one descriptor, without a raise: NOPROC / RAISED:... / NOKEY.
proc ol_dkey {type key} {
  set d [ol_ans ::op_annot::descriptor $type]
  if {$d eq {NOPROC}} { return NOPROC }
  if {[string match {RAISED:*} $d]} { return $d }
  if {[catch {dict exists $d $key} e]} { return BADDESC }
  if {!$e} { return NOKEY }
  if {[catch {dict get $d $key} v]} { return "RAISED:$v" }
  return $v
}
## the LABELS a rendered block actually drew, in draw order.
proc ol_rowlabels {block} {
  set out {}
  foreach l [split [string trimright $block "\n"] "\n"] {
    if {[string trim $l] eq {}} continue
    set i [string first "=" $l]
    if {$i < 0} { lappend out "NOEQ:$l" ; continue }
    lappend out [string trim [string range $l 0 [expr {$i - 1}]]]
  }
  return $out
}
## the VALUE drawn against <label>: {} for a blank row, NOROW when not drawn.
proc ol_rowval {block label} {
  foreach l [split [string trimright $block "\n"] "\n"] {
    set i [string first "=" $l]
    if {$i < 0} continue
    if {[string trim [string range $l 0 [expr {$i - 1}]]] ne $label} continue
    return [string trim [string range $l [expr {$i + 1}] end]]
  }
  return NOROW
}
## is <label> drawn at all?
proc ol_drawn {block label} {
  return [expr {[ol_rowval $block $label] eq {NOROW} ? 0 : 1}]
}

# --- the goldens the PDKs ship ----------------------------------------------
# ⚠ IHP's, NOT sky130's. The whole point of the item is the first triple.
set OL_MOS6 {{id ids 0} {gm gm 1} {gds gds 1} {vgs vgs 2} {vth vth 2} {vds vds 2}}
set OL_NPN6 {{ic ic 0} {ib ib 0} {gm gm 1} {go go 1} {vbe vbe 2} {vbc vbc 2}}

# ============================================================================
# SECTION J — WIRED UP SO IT ACTUALLY SHIPS
# ============================================================================
# A new helper .tcl that is SOURCED but not INSTALLED is a known failure class
# in this tree (issue 0424: the installed binary segfaulted at startup, exit
# 139, with 275 in-tree checks green). Its MIRROR — installed but never sourced
# — is dead code in-tree and dead code installed, with every structural check
# still green. Both halves are pinned here, plus the runtime half: `info
# commands` inside the RUNNING binary is the only one of the four that cannot
# be satisfied by a comment.
#
# ⚠ B2's Files cell OMITS src/xschem.tcl and is wrong: without a bare
# `source $XSCHEM_SHAREDIR/op_param_lists.tcl` line after :16749's op_annot.tcl
# row J1 cannot pass. Item B3 also edits src/xschem.tcl, for a menu entry in a
# different region; the two edits do not overlap.
# Copied from SEL75-SEL81, tests/headless/test_results_select.tcl:518-541.
# ALL FOUR ROWS RED BEFORE B2.

## the words of Makefile.in's install list (r2_shares, test_results_select.tcl:466)
proc ol_shares {text} {
  if {![regexp {put\s+/local/install_shares\s*\{([^\}]*)\}} $text -> blk]} { return {} }
  return [regexp -all -inline {\S+} $blk]
}
set OL_API {class set_class seed owns get_list set_list effective reset said
            said_clear conf_path load_conf load write_conf write_body apply}
set J1_GOT {}
foreach _p $OL_API { lappend J1_GOT [ol_defined ::op_param_lists::$_p] }
set J1_EXP {}
foreach _p $OL_API { lappend J1_EXP 1 }
check {J1 the whole store API is defined IN THE RUNNING BINARY, which is the one half of the wiring a comment cannot satisfy} \
  $J1_GOT $J1_EXP

check {J2 the file is on disk and src/xschem.tcl carries exactly ONE UNCOMMENTED bare source line for it} \
  [list [expr {[file isfile $OL_TCL] ? 1 : 0}] \
        [llength [lsearch -all -inline -regexp [split [ol_slurp $OL_XTCL] "\n"] \
                    {^\s*source\s+\$XSCHEM_SHAREDIR/op_param_lists\.tcl\s*$}]]] \
  {1 1}

# THE ./configure RECEIPT, AS A TEST RATHER THAN A TRANSCRIPT LINE. Editing
# Makefile.in alone installs nothing: src/Makefile is GENERATED, gitignored and
# has no self-regeneration rule, so a tracked-correct .in sits happily beside a
# stale Makefile and `make` never notices. The parse is proved, not assumed —
# it must find a name that IS in the list and must not find one that is not.
check {J3 the ./configure receipt: the word is in Makefile.in's install_shares, the parse discriminates, and the GENERATED Makefile carries BOTH the install and the uninstall rule} \
  [list [expr {[lsearch -exact [ol_shares [ol_slurp $OL_MKIN]] op_param_lists.tcl] >= 0 ? 1 : 0}] \
        [expr {[lsearch -exact [ol_shares [ol_slurp $OL_MKIN]] op_annot.tcl] >= 0 ? 1 : 0}] \
        [expr {[lsearch -exact [ol_shares [ol_slurp $OL_MKIN]] no_such_helper.tcl] >= 0 ? 1 : 0}] \
        [expr {[string match {*install -f op_param_lists.tcl*} [ol_slurp $OL_MK]] ? 1 : 0}] \
        [expr {[string match "*rm \"\$(XSHAREDIR)\"/op_param_lists.tcl*" [ol_slurp $OL_MK]] ? 1 : 0}]] \
  {1 1 0 1 1}

# SOURCE-TIME PURITY, BEHAVIOURALLY. A bare source line puts this file inside
# tests/headless/test_startup_guard_0663's contract: a raise at SOURCE TIME
# aborts startup. op_annot.tcl:224-231 states the rule for itself and B2
# inherits it — define procs and literal namespace variables, and nothing else.
# The strongest statement of that is that the file sources CLEANLY INTO A BARE
# TCL INTERPRETER, which has no `xschem` command, no ::op_annot and no
# XSCHEM_SHAREDIR: if it needs any of them at source time, this row reds.
# Sourcing it TWICE must also be a no-op, the way op_annot.tcl's
# `if {![array exists desc]}` guard makes its own re-source one.
set J4_RC1 NOFILE ; set J4_RC2 NOFILE ; set J4_NS 0 ; set J4_LITTER 1
if {[file isfile $OL_TCL]} {
  set J4_PROBE [file join $scratch j4probe]
  file mkdir $J4_PROBE
  catch {interp delete ol_j4}
  interp create ol_j4
  set J4_RC1 [catch {ol_j4 eval [list source $OL_TCL]} J4_E1]
  set J4_RC2 [catch {ol_j4 eval [list source $OL_TCL]} J4_E2]
  set J4_NS  [ol_j4 eval {expr {[namespace exists ::op_param_lists] ? 1 : 0}}]
  ## nothing was read, stat'ed into existence or written at source time
  set J4_LITTER [llength [glob -nocomplain -directory $J4_PROBE *]]
  interp delete ol_j4
}
check {J4 SOURCE-TIME PURITY: the file sources cleanly, and twice, into a BARE Tcl interpreter that has no xschem command and no ::op_annot — so a bare source line at startup cannot abort it} \
  [list $J4_RC1 $J4_RC2 $J4_NS $J4_LITTER] {0 0 1 0}

# ============================================================================
# SECTION M — THE CLASS MAP IS DATA, NOT A `switch`
# ============================================================================
# §3.4: the classification vocabulary is ragged and sky130 spells a resistor
# three ways. Measured beyond that, the shipped `type=` census also carries
# tokens §4.3's map does not name at all — sky130 ships `varactor`, `npn`,
# `pnp`, `pwell_resistor`, `p_diffusion_resistor`, `n_diffusion_resistor`,
# `high_precision_p`; IHP ships `pnp` (not `vertical_pnp`), `inductor`, `esd`;
# and xschem_library uses `type=` for arbitrary part numbers (2N3906, 4001,
# 12SK7). The token space is OPEN, so a `switch` is provably wrong.
#
# ⚠ AN UNMAPPED TOKEN IS ITS OWN CLASS — identity, never {} and never a raise.
# Returning {} would silently lose the lists of every token nobody anticipated,
# which is the failure that makes the tool useless on the next PDK; raising
# would contradict op_annot::descriptor's own rule that "this type is not
# annotated" is a DATA condition. Identity makes the map an OVERRIDE table
# rather than a gate.
#
# ⚠ THE SHIPPED DEFAULT IS EXACTLY §4.3's FIVE GROUPS AND NOTHING MORE. A map
# entry is a CLAIM that two tokens share one list, and `varactor -> capacitor`
# or `esd -> diode` are groupings no ruling covers: inventing them is the shape
# D-4 forbids, one level up. Row M2 is what makes leaving them out harmless.
# ALL THREE ROWS RED BEFORE B2.
ol_reset
set M1_TOK {nmos pmos res poly_resistor high_precision_poly_resistor
            high_precision_poly_p capacitor moscap diode vertical_npn
            vertical_pnp}
set M1_GOT {}
foreach _t $M1_TOK { lappend M1_GOT [ol_ans ::op_param_lists::class $_t] }
check {M1 the shipped default map is §4.3's five groups, including sky130's THREE resistor spellings} \
  $M1_GOT \
  {mos mos resistor resistor resistor resistor capacitor capacitor diode bipolar bipolar}

set M2_TOK {varactor esd inductor pnp npn 2N3906 pwell_resistor}
set M2_GOT {}
foreach _t $M2_TOK { lappend M2_GOT [ol_ans ::op_param_lists::class $_t] }
check {M2 a token nobody mapped is its OWN class and does not raise — every one of these is a `type=` token measured present in a shipped library} \
  $M2_GOT $M2_TOK

ol_reset
set M3_CONF [ol_conf [file join $scratch m3.conf] {
  {version 1}
  {class esd diode}
  {class nmos widget}
}]
set M3_L1 [ol_ans ::op_param_lists::load_conf $M3_CONF]
set M3_A  [list [ol_ans ::op_param_lists::class esd] [ol_ans ::op_param_lists::class nmos]]
set M3_W  [ol_ans ::op_param_lists::write_conf [file join $scratch m3.out]]
ol_reset
set M3_L2 [ol_ans ::op_param_lists::load_conf [file join $scratch m3.out]]
set M3_B  [list [ol_ans ::op_param_lists::class esd] [ol_ans ::op_param_lists::class nmos] \
                [ol_ans ::op_param_lists::class pmos] [ol_ans ::op_param_lists::class diode]]
check {M3 the map is EXTENDABLE and OVERRIDABLE, not a switch: `class` carries no switch, a conf row adopts a new token and overrides a shipped one, both survive a write+reload, and the shipped defaults the file never mentioned still apply} \
  [list [ol_count [ol_body ::op_param_lists::class] switch] \
        $M3_L1 $M3_A $M3_W $M3_L2 $M3_B] \
  [list 0 1 {diode widget} 1 1 {diode widget mos diode}]

# ============================================================================
# SECTION S — THE PDK SEED (D-7), AND THE THREE MEASUREMENTS
# ============================================================================
# The registry is EMPTY at a bare headless launch: descriptors arrive when a
# PDK's *_procs.tcl is sourced from a --script rc (op_annot.tcl:227 explains
# why never from xschemrc). This suite sources IHP's, and IHP's ONLY, because
# it is the one PDK in the tree whose first triple has LABEL != PARAM.
set S_PDK [file join $repo ihp-sg13g2 sg13g2_procs.tcl]
set S_SRC [catch {uplevel #0 [list source $S_PDK]} S_ERR]
check {S0 CONTROL the registry B2 seeds from is live and really does carry the IHP triple whose label differs from its param — without this the whole section is vacuous} \
  [list $S_SRC \
        [ol_ans ::op_annot::descriptor vertical_pnp] \
        [expr {[catch {dict get [::op_annot::descriptor nmos] params} p] ? "RAISED" : $p}] \
        [expr {[catch {dict get [::op_annot::descriptor vertical_npn] params} q] ? "RAISED" : $q}]] \
  [list 0 {} $OL_MOS6 $OL_NPN6]

ol_reset
set S1_SEED [ol_ans ::op_param_lists::seed mos]
check {S1 THE IHP TRIPLE: seed mos answers six {label param kind} triples whose first is {id ids 0} — label `id`, param `ids`, THEY DIFFER — and all three fields are carried} \
  [list $S1_SEED \
        [expr {[catch {lindex $S1_SEED 0 0} a] ? "RAISED" : $a}] \
        [expr {[catch {lindex $S1_SEED 0 1} b] ? "RAISED" : $b}] \
        [expr {[catch {lindex $S1_SEED 0 2} c] ? "RAISED" : $c}] \
        [expr {[catch {llength [lindex $S1_SEED 0]} n] ? "RAISED" : $n}]] \
  [list $OL_MOS6 id ids 0 3]

# THE ROW THAT SEES THE SILENT REWRITE. A store keeping only the name
# round-trips sky130 and gf180 perfectly and turns IHP's `id` row into `ids`
# on the way back in.
ol_reset
set S1B_P [file join $scratch s1b.conf]
ol_ans ::op_param_lists::set_list class mos annotation [ol_ans ::op_param_lists::seed mos]
set S1B_W [ol_ans ::op_param_lists::write_conf $S1B_P]
ol_reset
set S1B_L [ol_ans ::op_param_lists::load_conf $S1B_P]
check {S1b the IHP triple survives write -> reset -> load with LABEL AND PARAM AND KIND intact — a store that persists only the name reds here and nowhere else} \
  [list $S1B_W $S1B_L [ol_ans ::op_param_lists::get_list class mos annotation] [ol_nsaid]] \
  [list 1 1 $OL_MOS6 0]

# THE MAP IS NOT ONTO, AND THAT IS NORMAL.
ol_reset
::op_annot::register zznoparams {devpath {@x.foo}}
ol_ans ::op_param_lists::set_class zznoparams zznp
check {S2 the map is NOT ONTO and must not raise: bipolar seeds from vertical_npn alone though `vertical_pnp` is unregistered, three mapped classes NO PDK registers answer {}, and a descriptor with no `params` key contributes nothing} \
  [list [ol_ans ::op_param_lists::seed bipolar] \
        [ol_ans ::op_param_lists::seed resistor] \
        [ol_ans ::op_param_lists::seed capacitor] \
        [ol_ans ::op_param_lists::seed diode] \
        [ol_ans ::op_param_lists::seed zznp]] \
  [list $OL_NPN6 {} {} {} {}]

# THE CLASS-SEED CONFLICT, WHICH NO SHIPPED PDK PRODUCES. Every PDK registers
# nmos and pmos with byte-identical params, so this rule ships unexercised
# unless the suite builds the disagreement itself. FIRST BY LEXICAL TYPE-TOKEN
# ORDER WINS, NOTHING IS EVER MERGED — a merged list is one no PDK ever
# declared, which is the invented data D-4 forbids — and the divergence is
# reported ONCE, not once per call.
ol_reset
::op_annot::register zzalpha {params {{aa aa 0} {bb bb 1}}}
::op_annot::register zzbeta  {params {{cc cc 0} {dd dd 1} {ee ee 2}}}
ol_ans ::op_param_lists::set_class zzalpha zzsyn
ol_ans ::op_param_lists::set_class zzbeta  zzsyn
ol_ans ::op_param_lists::said_clear
set S3_A [ol_ans ::op_param_lists::seed zzsyn]
set S3_B [ol_ans ::op_param_lists::seed zzsyn]
set S3_SAID [ol_saidtext]
check {S3 two types in one class that DISAGREE: the first by lexical type-token order wins byte for byte, nothing is merged, and the divergence is reported ONCE across two calls and names the loser} \
  [list $S3_A $S3_B \
        [expr {[catch {llength $S3_A} n] ? "RAISED" : $n}] \
        [ol_saidhits zzbeta] \
        [ol_has $S3_SAID zzsyn]] \
  [list {{aa aa 0} {bb bb 1}} {{aa aa 0} {bb bb 1}} 2 1 1]

# ============================================================================
# SECTION P — THE STRICT PARSER (DD-3)
# ============================================================================
# The reader does NO source, NO eval, NO subst and NO substitution of any kind.
# Anything it does not recognise is REPORTED and SKIPPED, and the rest of the
# file still loads. Precedent: action_registry.tcl:66 (skip blank, skip `#`,
# trim a trailing \r) and :329 (report-and-skip per malformed row).
# ALL RED BEFORE B2.
ol_reset
set P1_LINES [list \
  {version 1} \
  {# a comment line, and the blank line below it} \
  {} \
  {class esd diode} \
  {param class mos annotation id ids 0} \
  {param class mos annotation gm gm 1} \
  {param class mos summary vth vth 2} \
  {param flavor *nfet_01v8_lvt* annotation vdsat vdsat 5}]
set P1_CONF [ol_conf [file join $scratch p1.conf] $P1_LINES]
set P1_L [ol_ans ::op_param_lists::load_conf $P1_CONF]
check {P1 a good file loads in FILE ORDER with all three fields intact, across both scopes and both list names, and an integer kind the wrapper does not name (5) survives unchanged} \
  [list $P1_L \
        [ol_ans ::op_param_lists::get_list class mos annotation] \
        [ol_ans ::op_param_lists::get_list class mos summary] \
        [ol_ans ::op_param_lists::get_list flavor *nfet_01v8_lvt* annotation] \
        [ol_ans ::op_param_lists::class esd] \
        [ol_nsaid]] \
  [list 1 {{id ids 0} {gm gm 1}} {{vth vth 2}} {{vdsat vdsat 5}} diode 0]

# SEVEN MALFORMED SHAPES, EACH REPORTED EXACTLY ONCE AND SKIPPED, WITH THE ROW
# AFTER THEM STILL LOADING. The `all` row is D-4: list 3 is LIVE from the
# simulator and is never persisted, so a file that tries to persist it is
# telling the store something the store must refuse.
ol_reset
set P2_CONF [ol_conf [file join $scratch p2.conf] [list \
  {version 1} \
  {param class mos} \
  {param class mos annotation id id 0 extra} \
  {param class mos annotation vth vth two} \
  {wibble class mos annotation} \
  {param class mos all id id 0} \
  {param zzz mos annotation id id 0} \
  {param class mos frobnicate id id 0} \
  {param class mos annotation gm gm 1}]]
set P2_L [ol_ans ::op_param_lists::load_conf $P2_CONF]
check {P2 a short row, a long row, a non-integer kind, an unknown verb, a `param ... all ...` row (D-4), an unknown scope and an unknown list name are each REPORTED ONCE and SKIPPED — and the good row after all seven still loads} \
  [list $P2_L [ol_nsaid] \
        [ol_ans ::op_param_lists::get_list class mos annotation] \
        [ol_ans ::op_param_lists::get_list class mos summary] \
        [ol_ans ::op_param_lists::owns class mos all] \
        [ol_ans ::op_param_lists::effective mos all]] \
  [list 1 7 {{gm gm 1}} {} 0 {}]

ol_reset
set P2B_CONF [ol_conf [file join $scratch p2b.conf] [list \
  {version 99} \
  {param class mos annotation id ids 0}]]
set P2B_L [ol_ans ::op_param_lists::load_conf $P2B_CONF]
check {P2b an unknown `version` is reported and the file is STILL parsed row by row — a settings file from a newer xschem must degrade, not vanish} \
  [list $P2B_L [ol_nsaid] [ol_ans ::op_param_lists::get_list class mos annotation]] \
  [list 1 1 {{id ids 0}}]

ol_reset
set P3_CONF [ol_conf [file join $scratch p3.conf] [list \
  {version 1} \
  {param class mos annotation id ids 0} \
  {param class mos annotation gm gm 1} \
  {param class mos annotation id idd 3} \
  {class esd diode} \
  {class esd capacitor}]]
set P3_L [ol_ans ::op_param_lists::load_conf $P3_CONF]
check {P3 a repeated LABEL inside one list replaces IN PLACE and keeps the order, a repeated `class` row takes the LATER mapping, and both are reported} \
  [list $P3_L [ol_nsaid] \
        [ol_ans ::op_param_lists::get_list class mos annotation] \
        [ol_ans ::op_param_lists::class esd]] \
  [list 1 2 {{id idd 3} {gm gm 1}} capacitor]

# CRLF, LF AND A TRUNCATED LAST LINE ALL PRODUCE THE SAME STORE. Measured on
# this tree: CRLF is already handled by the DEFAULT `auto` translation and
# breaks only if a reader copies the tree's `-translation binary` idiom
# (ase.tcl:1625, xschem.tcl:7910). Pin the ENCODING, leave the TRANSLATION
# alone, and keep action_registry's defensive `string trimright $line "\r"`.
# The comparison is on the WRITTEN FILE, so it is a byte comparison of the
# whole store rather than of the two or three keys this row happened to think of.
ol_reset
ol_ans ::op_param_lists::load_conf [ol_conf [file join $scratch p4lf.conf] $P1_LINES "\n" 1]
ol_ans ::op_param_lists::write_conf [file join $scratch p4lf.out]
set P4_LF [ol_bytes [file join $scratch p4lf.out]]
ol_reset
ol_ans ::op_param_lists::load_conf [ol_conf [file join $scratch p4crlf.conf] $P1_LINES "\r\n" 1]
ol_ans ::op_param_lists::write_conf [file join $scratch p4crlf.out]
set P4_CRLF [ol_bytes [file join $scratch p4crlf.out]]
ol_reset
ol_ans ::op_param_lists::load_conf [ol_conf [file join $scratch p4trunc.conf] $P1_LINES "\n" 0]
ol_ans ::op_param_lists::write_conf [file join $scratch p4trunc.out]
set P4_TRUNC [ol_bytes [file join $scratch p4trunc.out]]
check {P4 a CRLF file, an LF file and a file whose last line has no newline at all produce a BYTE-IDENTICAL store, and all three really were written and are not empty} \
  [list [expr {$P4_LF ne {NOFILE} ? 1 : 0}] \
        [expr {$P4_CRLF ne {NOFILE} ? 1 : 0}] \
        [expr {$P4_TRUNC ne {NOFILE} ? 1 : 0}] \
        [expr {$P4_LF eq $P4_CRLF ? 1 : 0}] \
        [expr {$P4_LF eq $P4_TRUNC ? 1 : 0}] \
        [expr {[ol_count $P4_LF {vdsat}] >= 1 ? 1 : 0}]] \
  {1 1 1 1 1 1}

# ============================================================================
# P5 — THE LOCALE ROW, AND IT SPAWNS A CHILD ON PURPOSE
# ============================================================================
# MEASURED ON THIS BOX: `encoding system` is utf-8 here and iso8859-1 under
# LC_ALL=C. The SAME BYTES therefore read back as a DIFFERENT STRING depending
# on the reader's locale unless `-encoding utf-8` is pinned on BOTH the read
# and the write channel. A file whose headline feature is that it is SHAREABLE
# WITH TEAMMATES cannot depend on the teammate's LANG.
#
# ⚠ NOTHING IN THE TREE PINS THIS TODAY (the only fconfigure calls are
# `-translation binary`), so it will not arrive by copying a neighbour.
#
# ⚠ THIS ROW IS THE ONLY ONE THAT CAN SEE AN UNPINNED ENCODING, and it can see
# it only from a child process — in-process the parent is already utf-8 and
# every assertion passes vacuously. That is why it execs rather than testing in
# place. Row P5c is the positive control: if the child comes back utf-8 the
# arm never existed and P5 proves nothing.
set P5_LBL   "idé"
set P5_UTF8  [binary encode hex [encoding convertto utf-8 $P5_LBL]]
set P5_LAT1  [binary encode hex [encoding convertto iso8859-1 $P5_LBL]]
set P5_IN    [file join $scratch p5in.conf]
set P5_OUT   [file join $scratch p5out.conf]
set P5_KID   [file join $scratch p5child.tcl]
ol_put $P5_IN [encoding convertto utf-8 \
  "version 1\nparam class mos annotation $P5_LBL $P5_LBL 0\n"]
## ⚠ BUILT WITH `string map`, NOT `subst`. The child text is full of Tcl the
## PARENT must not evaluate; substituting it here would raise on the first
## variable the child owns and would be the very habit DD-3 forbids in the
## store itself.
set P5_KIDSRC {
set ::netlist_dir {@SCRATCH@}
puts "OPLENC=[encoding system]"
if {![llength [info commands ::op_param_lists::load_conf]]} { puts "OPLLIST=NOPROC" ; exit 0 }
catch {::op_param_lists::reset}
set rc1 [catch {::op_param_lists::load_conf {@IN@}} r1]
set rc2 [catch {::op_param_lists::get_list class mos annotation} lst]
set rc3 [catch {::op_param_lists::write_conf {@OUT@}} r3]
if {$rc2} { set lst {} }
puts "OPLLIST=[binary encode hex [encoding convertto utf-8 $lst]]"
puts "OPLRC=$rc1$rc2$rc3"
exit 0
}
ol_put $P5_KID [encoding convertto utf-8 \
  [string map [list @SCRATCH@ $scratch @IN@ $P5_IN @OUT@ $P5_OUT] $P5_KIDSRC]]
catch {file delete -force $P5_OUT}
set P5_RC [catch {exec env LC_ALL=C LANG=C $OL_BIN --nogui --pipe -q --nolog \
                       --script $P5_KID 2>@1} P5_TXT]
if {![regexp {OPLENC=(\S+)} $P5_TXT -> P5_ENC]}   { set P5_ENC NOENC }
if {![regexp {OPLLIST=(\S+)} $P5_TXT -> P5_GOT]}  { set P5_GOT NOLIST }
set P5_OUTHEX [ol_hex $P5_OUT]
check {P5c CONTROL the LC_ALL=C child really does run in a non-utf-8 locale — without this P5 could pass vacuously in a utf-8 child} \
  [list [expr {$P5_ENC ne {utf-8} && $P5_ENC ne {NOENC}}] $P5_ENC] {1 iso8859-1}
check {P5 a non-ASCII UTF-8 label round-trips byte for byte through a reader AND a writer running under LC_ALL=C: the child reads the same characters, and the file it writes carries the utf-8 bytes and not the latin-1 ones} \
  [list $P5_GOT \
        [expr {$P5_OUTHEX eq {NOFILE} ? "NOFILE" : [ol_count $P5_OUTHEX $P5_UTF8]}] \
        [expr {$P5_OUTHEX eq {NOFILE} ? "NOFILE" : [ol_count $P5_OUTHEX $P5_LAT1]}]] \
  [list [binary encode hex [encoding convertto utf-8 [list [list $P5_LBL $P5_LBL 0]]]] 2 0]

# ============================================================================
# SECTION X — NOTHING IN THE SETTINGS FILE IS EVER EXECUTED (DD-3)
# ============================================================================
# MEASURED ON THIS TREE, not cited: feeding a plausible shared conf to the
# `uplevel #0 [list source $path]` idiom that ase::sim_load_conf:2096 uses, with
# the payload placed FIRST under a friendly `# share freely` header, gives
#     SOURCED: OPL_PWNED=1  marker_on_disk=1  err={invalid command name "mos"}
# The variable was set AND a file was created, and the Tcl error that follows
# is COSMETIC — the payload had already run.
#
# ⚠ SO EVERY ROW HERE ASSERTS A SIDE EFFECT — a sentinel variable or a FILE ON
# DISK — AND NEVER A RETURN CODE. A row that only checked for a raise would
# have scored that exact file SAFE. (test_raw_read_dispatch.tcl:217 records the
# same rule the hard way.)
#
# ⚠ THE PAYLOAD-FIRST ORDERING IS LOAD-BEARING. Payload-last aborts the source
# before it runs, which is the arrangement that makes a sourced file look safe.
# ALL RED BEFORE B2.
proc ol_pwn2 {} {
  set ::OPL_PWNED2 1
  catch {close [open $::OPL_PWNPATH2 w]}
  return SUBSTITUTED
}
set ::OPL_TRAP  SUBSTITUTED
set ::OPL_PWNPATH  [file join $scratch PWNED]
set ::OPL_PWNPATH2 [file join $scratch PWNED2]
catch {unset ::OPL_PWNED} ; catch {unset ::OPL_PWNED2}
catch {file delete -force $::OPL_PWNPATH} ; catch {file delete -force $::OPL_PWNPATH2}

ol_reset
set X1_CONF [ol_conf [file join $scratch x1.conf] [list \
  {# op_param_lists — share this file freely with your team} \
  {set ::OPL_PWNED 1} \
  "exec touch $::OPL_PWNPATH" \
  {version 1} \
  {param class mos annotation id ids 0}]]
set X1_L [ol_ans ::op_param_lists::load_conf $X1_CONF]
check {X1 a conf whose FIRST two lines would run if the file were sourced sets NO variable and creates NO file, both lines are reported and skipped, and the data row after them still loads} \
  [list [expr {[info exists ::OPL_PWNED] ? 1 : 0}] \
        [expr {[file exists $::OPL_PWNPATH] ? 1 : 0}] \
        $X1_L [ol_nsaid] \
        [ol_ans ::op_param_lists::get_list class mos annotation]] \
  [list 0 0 1 2 {{id ids 0}}]

ol_reset
set X2_LINES [list \
  {version 1} \
  "param class mos annotation \[ol_pwn2\] \[ol_pwn2\] 0" \
  "param class mos annotation \$::OPL_TRAP \$::OPL_TRAP 1" \
  "param class mos annotation \$\{OPL_TRAP\} \$\{OPL_TRAP\} 2" \
  "param class mos annotation \$env(HOME) \$env(HOME) 2"]
set X2_EXP [list \
  [list {[ol_pwn2]} {[ol_pwn2]} 0] \
  [list {$::OPL_TRAP} {$::OPL_TRAP} 1] \
  [list "\$\{OPL_TRAP\}" "\$\{OPL_TRAP\}" 2] \
  [list {$env(HOME)} {$env(HOME)} 2]]
set X2_CONF [ol_conf [file join $scratch x2.conf] $X2_LINES]
set X2_L [ol_ans ::op_param_lists::load_conf $X2_CONF]
check {X2 command, scalar, braced and array-index substitution shapes are stored as LITERAL TEXT: none of them fires, no sentinel is set and no file appears} \
  [list $X2_L [ol_ans ::op_param_lists::get_list class mos annotation] \
        [expr {[info exists ::OPL_PWNED2] ? 1 : 0}] \
        [expr {[file exists $::OPL_PWNPATH2] ? 1 : 0}] \
        [ol_nsaid]] \
  [list 1 $X2_EXP 0 0 0]

# THE COUNTERWEIGHT. The easy wrong fix is a parser that refuses anything
# unusual, and a suite made only of attack rows scores that as a fix. These are
# ORDINARY awkward labels — including the lone `{` that kills an `llength`-based
# reader from inside, and the backslash an `lindex`-based one silently eats —
# and every one of them must LOAD and ROUND-TRIP.
ol_reset
set X3_LINES [list \
  {version 1} \
  "param class mos annotation d\$ollar d\$ollar 0" \
  "param class mos annotation br\[1\] br\[1\] 1" \
  "param class mos annotation ob\{ ob\{ 2" \
  "param class mos annotation ba\\ck ba\\ck 0" \
  "param class mos annotation a/b a/b 1" \
  "param class mos annotation id#2 id#2 2"]
set X3_EXP [list \
  [list {d$ollar} {d$ollar} 0] \
  [list {br[1]} {br[1]} 1] \
  [list "ob\{" "ob\{" 2] \
  [list "ba\\ck" "ba\\ck" 0] \
  [list a/b a/b 1] \
  [list {id#2} {id#2} 2]]
set X3_CONF [ol_conf [file join $scratch x3.conf] $X3_LINES]
set X3_L  [ol_ans ::op_param_lists::load_conf $X3_CONF]
set X3_G1 [ol_ans ::op_param_lists::get_list class mos annotation]
set X3_W  [ol_ans ::op_param_lists::write_conf [file join $scratch x3.out]]
ol_reset
set X3_L2 [ol_ans ::op_param_lists::load_conf [file join $scratch x3.out]]
set X3_G2 [ol_ans ::op_param_lists::get_list class mos annotation]
check {X3 COUNTERWEIGHT ordinary awkward labels — a dollar, a bracket, a lone open brace, a backslash, a slash and a mid-token hash — all LOAD, report nothing, and survive a write and a reload unchanged} \
  [list $X3_L [ol_nsaid] $X3_G1 $X3_W $X3_L2 $X3_G2] \
  [list 1 0 $X3_EXP 1 1 $X3_EXP]

# THE STRUCTURAL HALF. ⚠ THE READER STRIPS WHOLE-LINE `#` COMMENTS ONLY: a
# trailing `;# ... subst ...` on a code line reds this row. Say it in prose
# above the proc, the way this file does, not on the code line.
set X4_CODE NOFILE
if {[file isfile $OL_TCL]} {
  set X4_CODE [ol_nocomment [ol_slurp $OL_TCL]]
  ## `namespace eval` is the one legitimate `eval` a Tcl file has; removing the
  ## literal first is what lets the rest of the count mean something.
  set X4_CODE [string map {{namespace eval} {namespace NS}} $X4_CODE]
}
check {X4 STRUCTURAL the shipped implementation contains no subst, no uplevel, no source, no exec and no bare eval anywhere outside its comments — DD-3's forty lines of parser instead of a one-line source} \
  [list [expr {$X4_CODE eq {NOFILE} ? "NOFILE" : [ol_count $X4_CODE subst]}] \
        [expr {$X4_CODE eq {NOFILE} ? "NOFILE" : [ol_count $X4_CODE uplevel]}] \
        [expr {$X4_CODE eq {NOFILE} ? "NOFILE" : [ol_count $X4_CODE {source }]}] \
        [expr {$X4_CODE eq {NOFILE} ? "NOFILE" : [ol_count $X4_CODE {exec }]}] \
        [expr {$X4_CODE eq {NOFILE} ? "NOFILE" : [ol_count $X4_CODE eval]}]] \
  {0 0 0 0 0}

# ============================================================================
# SECTION W — THE WRITER (issue 0937): AN INTERRUPTED WRITE NEVER TRUNCATES
# ============================================================================
# `open <path> w` TRUNCATES before a single byte is written, so a failure
# anywhere after that leaves the user with an EMPTY settings file. The house
# idiom is ase::sim_write_conf / ase::sim_write_body (src/ase.tcl:1999-2036):
# capture the permissions, write to `$path.new`, ONE catch around the whole
# body and the close, `file delete -force` the temp on EVERY failure arm,
# `file rename -force`, restore the permissions after the move, return 1/0 and
# never raise.
#
# ⚠ ROW W1 MAKES THE WRITE FAIL IN A WAY THAT WORKS FOR ROOT TOO — the
# temporary is already a DIRECTORY, and no user can open a directory for
# writing. It therefore PINS THE TEMPORARY NAME AS `$path.new`: if that name
# ever changes the write SUCCEEDS and the second term reds rather than the row
# going quietly vacuous. Copied from R11/R12,
# tests/headless/test_ase_simreg_0931.tcl:1307-1352.
# ALL RED BEFORE B2.
proc ol_perms {path} {
  if {![file exists $path]} { return NOFILE }
  if {[catch {file attributes $path -permissions} m]} { return NOPERM }
  set v 0
  if {![scan $m {%o} v]} { return "NOSCAN-$m" }
  return [format %04o [expr {$v & 0777}]]
}
set W1DIR [file join $scratch wconf]
file mkdir $W1DIR
set W1   [file join $W1DIR op_param_lists.conf]
set W1N  $W1.new
ol_reset
ol_ans ::op_param_lists::set_list class mos annotation {{keepw1 keepw1 0}}
set W1_R1 [ol_ans ::op_param_lists::write_conf $W1]
set W1_BEFORE [ol_bytes $W1]
ol_ans ::op_param_lists::set_list class mos summary {{gonew1 gonew1 1}}
catch {file delete -force $W1N}
file mkdir $W1N
ol_ans ::op_param_lists::said_clear
set W1_R2 [ol_ans ::op_param_lists::write_conf $W1]
set W1_SAID [ol_saidtext]
catch {file delete -force $W1N}
set W1_AFTER [ol_bytes $W1]
check {W1 a save that cannot happen leaves the settings file you already had exactly as it was — it never empties it first and then fails — and you are told in plain English} \
  [list $W1_R1 [expr {[ol_count $W1_BEFORE keepw1] >= 1 ? 1 : 0}] \
        $W1_R2 [expr {$W1_AFTER eq $W1_BEFORE ? 1 : 0}] \
        [expr {$W1_AFTER eq {NOFILE} ? "NOFILE" : [ol_count $W1_AFTER gonew1]}] \
        [expr {$W1_SAID ne {} ? 1 : 0}]] \
  [list 1 1 0 1 0 1]

set W2DIR [file join $scratch projW2]
set W2    [file join $W2DIR .xschem op_param_lists.conf]
ol_reset
ol_ans ::op_param_lists::set_list class mos annotation {{permw2 permw2 0}}
set W2_R1 [ol_ans ::op_param_lists::write_conf $W2]
set W2_EX [expr {[file isfile $W2] ? 1 : 0}]
catch {file attributes $W2 -permissions 0600}
set W2_M0 [ol_perms $W2]
ol_ans ::op_param_lists::set_list class mos summary {{permw2b permw2b 1}}
set W2_R2 [ol_ans ::op_param_lists::write_conf $W2]
set W2_M1 [ol_perms $W2]
check {W2 a `.xschem` directory that does not exist yet is created rather than reported, and the 0600 you put on your own copy survives the rename} \
  [list $W2_R1 $W2_EX $W2_M0 $W2_R2 $W2_M1 \
        [expr {[ol_count [ol_bytes $W2] permw2b] >= 1 ? 1 : 0}]] \
  [list 1 1 0600 1 0600 1]

# THE FULL ROUND TRIP, INCLUDING THE ONE CASE THAT IS EASY TO LOSE: AN EMPTIED
# LIST. `owns` 1 with an empty list and `owns` 0 are DIFFERENT FACTS — "I chose
# to show nothing" against "I never customised this" — and a store that
# collapsed them would answer the PDK seed to a user who had deliberately
# cleared the list. That is the same absent-vs-empty collapse issue 1272 cost
# this batch one item, one class further out.
ol_reset
set W3 [file join $scratch w3.conf]
ol_ans ::op_param_lists::set_list class mos annotation {{id ids 0} {gm gm 1}}
ol_ans ::op_param_lists::set_list flavor {*nfet_01v8_lvt*} annotation {{vth vth 2}}
ol_ans ::op_param_lists::set_list class bipolar summary {}
set W3_W [ol_ans ::op_param_lists::write_conf $W3]
ol_reset
set W3_L [ol_ans ::op_param_lists::load_conf $W3]
check {W3 FULL ROUND TRIP seed -> set_list -> write -> reset -> load: a class entry, a flavor entry and an EMPTIED list all come back identical, and the emptied one stays EMPTY instead of falling back to the PDK seed} \
  [list $W3_W $W3_L \
        [ol_ans ::op_param_lists::get_list class mos annotation] \
        [ol_ans ::op_param_lists::get_list flavor {*nfet_01v8_lvt*} annotation] \
        [ol_ans ::op_param_lists::owns class bipolar summary] \
        [ol_ans ::op_param_lists::get_list class bipolar summary] \
        [ol_ans ::op_param_lists::effective bipolar summary] \
        [ol_nsaid]] \
  [list 1 1 {{id ids 0} {gm gm 1}} {{vth vth 2}} 1 {} {} 0]

# THE WRITER WRITES ONLY WHAT THE USER OWNS (D-7: nothing has to be checked in
# until something is changed), and it REFUSES a field it could not read back
# rather than writing a line that would be reported as malformed at the next
# load. ⚠ Only `list` and `param` rows are counted, because the class map is
# written whole or as overrides at the implementer's choice and either way it
# legitimately mentions every default class.
## Data rows naming <key>. `verbs` selects which of the two data verbs count:
## `param` alone for "the entry really was written", both for "this class is
## not mentioned at all". The class-map rows are deliberately NOT counted —
## whether the writer emits the whole effective map or only the overrides is
## the implementer's choice, and either way it legitimately names every
## default class.
proc ol_datarows {text key {verbs {param list}}} {
  if {$text eq {NOFILE}} { return NOFILE }
  set n 0
  foreach line [split $text "\n"] {
    set f [regexp -inline -all {\S+} $line]
    if {[llength $f] < 3} continue
    if {[lsearch -exact $verbs [lindex $f 0]] < 0} continue
    if {[lindex $f 2] eq $key} { incr n }
  }
  return $n
}
ol_reset
set W4 [file join $scratch w4.conf]
ol_ans ::op_param_lists::set_list class mos annotation {{id ids 0}}
ol_ans ::op_param_lists::said_clear
set W4_BAD [ol_ans ::op_param_lists::set_list class resistor annotation {{{id x} idx 0}}]
set W4_NS  [ol_nsaid]
set W4_OWN [ol_ans ::op_param_lists::owns class resistor annotation]
set W4_W   [ol_ans ::op_param_lists::write_conf $W4]
set W4_TXT [ol_bytes $W4]
check {W4 the writer writes ONLY the lists the user owns — a class left on the PDK seed produces no `list` and no `param` row at all — and a field carrying whitespace is REFUSED with a report instead of being written back unreadable} \
  [list $W4_BAD $W4_NS $W4_OWN $W4_W \
        [ol_datarows $W4_TXT mos param] [ol_datarows $W4_TXT bipolar] \
        [ol_datarows $W4_TXT resistor]] \
  [list 0 1 0 1 1 0 0]

# WRITING THE SAME STORE TWICE MUST GIVE THE SAME BYTES. Not in the plan's row
# list, and it is what makes P4's byte comparison mean anything: a header
# carrying a timestamp, a pid or a hostname would make every write differ from
# the last and would make the file undiffable in the project it is checked into
# — which is the point of "shareable with teammates, written once per project".
ol_reset
ol_ans ::op_param_lists::load_conf $P1_CONF
ol_ans ::op_param_lists::write_conf [file join $scratch w5a.conf]
ol_ans ::op_param_lists::write_conf [file join $scratch w5b.conf]
check {W5 writing the same store twice produces BYTE-IDENTICAL files: no timestamp, no pid, no hostname, so the file a team checks in diffs only when someone changed something} \
  [list [expr {[ol_bytes [file join $scratch w5a.conf]] eq [ol_bytes [file join $scratch w5b.conf]] ? 1 : 0}] \
        [expr {[ol_bytes [file join $scratch w5a.conf]] eq {NOFILE} ? "NOFILE" : "FILE"}]] \
  {1 FILE}

# ============================================================================
# SECTION T — THE TWO TIERS (D-7), AND WHAT `<project>` MEANS
# ============================================================================
# ⚠ THE PROJECT TIER IS `<pwd>/.xschem/op_param_lists.conf`, NOT
# `[xschem get current_dirname]`. Measured: after loading a schematic from
# elsewhere current_dirname MOVES while pwd does not, so a Save taken while
# descended into a PDK library cell would write the project file into the PDK
# tree and the next read, back at the top, would not find it. pwd is stable for
# the whole session, so the reader and the writer can never silently disagree —
# and it matches the tree's ONLY project-vs-user precedent, xinit.c:3500-3515's
# `./xschemrc` in pwd. This is an L2 ladder decision and is on the owed ledger
# as a `rule` debt for the user to overrule.
#
# ⚠ THE WIN IS PER (scope,key,listname), NOT PER CLASS. DD-3's own sentence
# says "per class"; per-list is FINER, never coarser, so a project file that
# customises `mos annotation` no longer silently discards the user-global's
# `mos summary`. Row T2 is the row that flips if the driver disagrees.
# ALL RED BEFORE B2.
set T_HOME [file join $scratch tierhome]
set T_PROJ [file join $scratch tierproj]
file mkdir $T_HOME
file mkdir [file join $T_PROJ .xschem]
ol_conf [file join $T_HOME op_param_lists.conf] {
  {version 1}
  {param class mos annotation userid userid 0}
  {param class mos summary usersum usersum 1}
}
ol_conf [file join $T_PROJ .xschem op_param_lists.conf] {
  {version 1}
  {param class mos annotation projid projid 0}
}
set T_OLDPWD [pwd]
set T_OLDUCD $::USER_CONF_DIR

ol_reset
set ::USER_CONF_DIR $T_HOME
cd $T_PROJ
set T1_SEED [ol_ans ::op_param_lists::seed mos]
ol_ans ::op_param_lists::set_list class mos annotation {{t1a t1a 0}}
set T1_GOT [list [ol_ans ::op_param_lists::effective mos annotation] \
                 [ol_ans ::op_param_lists::effective bipolar annotation] \
                 [ol_ans ::op_param_lists::owns class mos annotation] \
                 [ol_ans ::op_param_lists::owns class bipolar annotation]]
check {T1 THE ACCEPTANCE ROW, BOTH HALVES IN ONE CHECK: a user entry for `mos annotation` overrides its class AND `bipolar annotation` is still the PDK seed} \
  [list $T1_SEED $T1_GOT] \
  [list $OL_MOS6 [list {{t1a t1a 0}} $OL_NPN6 1 0]]

ol_reset
set T2_PATHS [ol_ans ::op_param_lists::load]
set T2_CP [list [ol_ans ::op_param_lists::conf_path user] \
                [ol_ans ::op_param_lists::conf_path project]]
check {T2 the project file beats the user-global one PER LIST: the project's `mos annotation` wins, and the user-global's `mos summary` SURVIVES that file rather than being dropped along with its class} \
  [list $T2_PATHS $T2_CP \
        [ol_ans ::op_param_lists::get_list class mos annotation] \
        [ol_ans ::op_param_lists::get_list class mos summary] \
        [ol_ans ::op_param_lists::effective mos annotation] \
        [ol_ans ::op_param_lists::effective mos summary] \
        [ol_nsaid]] \
  [list [list [file join $T_HOME op_param_lists.conf] \
              [file join $T_PROJ .xschem op_param_lists.conf]] \
        [list [file join $T_HOME op_param_lists.conf] \
              [file join $T_PROJ .xschem op_param_lists.conf]] \
        {{projid projid 0}} {{usersum usersum 1}} \
        {{projid projid 0}} {{usersum usersum 1}} 0]

# A MISSING FILE AT EITHER TIER IS THE ORDINARY FIRST-RUN CASE, not a failure
# (ase.tcl:2101 states it explicitly), and two tiers that resolve to the SAME
# path are read ONCE.
set T3_EMPTY [file join $scratch tierempty]
file mkdir $T3_EMPTY
ol_reset
set ::USER_CONF_DIR $T3_EMPTY
cd $T3_EMPTY
set T3_P1 [ol_ans ::op_param_lists::load]
set T3_N1 [ol_nsaid]
set T3_E1 [ol_ans ::op_param_lists::effective mos annotation]

set T3_SAME [file join $scratch tiersame]
file mkdir [file join $T3_SAME .xschem]
ol_conf [file join $T3_SAME .xschem op_param_lists.conf] {
  {version 1}
  {param class mos annotation sameid sameid 0}
}
ol_reset
set ::USER_CONF_DIR [file join $T3_SAME .xschem]
cd $T3_SAME
set T3_P2 [ol_ans ::op_param_lists::load]
set T3_G2 [ol_ans ::op_param_lists::get_list class mos annotation]
cd $T_OLDPWD
set ::USER_CONF_DIR $T_OLDUCD
check {T3 a missing file at either tier is the ordinary first-run case — nothing is reported and the seed still answers — and two tiers resolving to the SAME path are read once, not twice} \
  [list $T3_P1 $T3_N1 $T3_E1 \
        [expr {[catch {llength $T3_P2} n] ? "RAISED" : $n}] $T3_G2] \
  [list {} 0 $OL_MOS6 1 {{sameid sameid 0}}]

# ============================================================================
# SECTION F — DD-2: THE LISTS KEY ON THE CLASS, FLAVOR IS AN OVERRIDE
# ============================================================================
# The flavor key is a CELL-NAME GLOB matched with `string match -nocase`, which
# is the narrowing op_annot::_matches (op_annot.tcl:411) already performs over
# `getprop instance <n> cell::name`. Inventing a second flavor concept keyed on
# anything else would fork the narrowing — spec §2.1 already calls the `match`
# glob "the device-flavor narrowing the user's broad/narrow dialog needs".
# BOTH RED BEFORE B2.
ol_reset
ol_ans ::op_param_lists::set_list class mos annotation {{clsid clsid 0}}
ol_ans ::op_param_lists::set_list flavor {*nfet_01v8_lvt*} annotation {{flvid flvid 0}}
check {F1 DD-2's override half: a flavor entry whose glob matches the cell name WINS over the class entry, case-insensitively, while a SIBLING cell that does not match still gets the class list — and with no cell name at all the class answers} \
  [list [ol_ans ::op_param_lists::effective mos annotation sky130_fd_pr/nfet_01v8_lvt.sym] \
        [ol_ans ::op_param_lists::effective mos annotation SKY130_FD_PR/NFET_01V8_LVT.SYM] \
        [ol_ans ::op_param_lists::effective mos annotation sky130_fd_pr/nfet_01v8.sym] \
        [ol_ans ::op_param_lists::effective mos annotation]] \
  [list {{flvid flvid 0}} {{flvid flvid 0}} {{clsid clsid 0}} {{clsid clsid 0}}]

# A FLAVOR ENTRY FOR A CLASS WITH NO CLASS ENTRY — the shape a B5 scope dialog
# writes first, and the one most likely to be lost: with nothing owned at the
# class level the flavor must still win, and the class must still fall through
# to the PDK seed for every other cell.
ol_reset
ol_ans ::op_param_lists::set_list flavor {*nfet_01v8_lvt*} annotation {{onlyflv onlyflv 0}}
check {F1b a flavor entry for a class that owns nothing: the flavor still wins for its own cell, and every other cell of that class still gets the PDK seed} \
  [list [ol_ans ::op_param_lists::effective mos annotation sky130_fd_pr/nfet_01v8_lvt.sym] \
        [ol_ans ::op_param_lists::effective mos annotation sky130_fd_pr/nfet_01v8.sym] \
        [ol_ans ::op_param_lists::owns class mos annotation]] \
  [list {{onlyflv onlyflv 0}} $OL_MOS6 0]

ol_reset
ol_ans ::op_param_lists::set_list class mos annotation {{clsid clsid 0}}
check {F2 DD-2's own sentence as a check: `nfet_01v8_lvt` with no entry of its own uses the `mos` lists, and `owns` says 0 for the flavor and 1 for the class} \
  [list [ol_ans ::op_param_lists::effective mos annotation sky130_fd_pr/nfet_01v8_lvt.sym] \
        [ol_ans ::op_param_lists::owns flavor {*nfet_01v8_lvt*} annotation] \
        [ol_ans ::op_param_lists::owns class mos annotation]] \
  [list {{clsid clsid 0}} 0 1]

# ============================================================================
# SECTION A — THE APPLY DOOR IS op_annot::register, AND NOTHING ELSE (I5)
# ============================================================================
# Invariant I5 requires a changed list to take effect ON REDRAW — no restart,
# no rebuild. Only op_annot::register bumps ::op_annot::gen (op_annot.tcl:346),
# which annot_overlay_sync() folds into the overlay's epoch (actions.c:2032). A
# direct `set ::op_annot::desc(...)` is stored, correct in Tcl, and INVISIBLE
# ON SCREEN until an unrelated redraw — I5 failing silently.
#
# ⚠ `apply` IS DEFINED HERE AND CALLED FROM NOWHERE IN B2. Defining the door is
# what stops item B5 writing a second one. It is deliberately unwired: an
# auto-apply at startup is PROVABLY WRONG ORDERING, because op_param_lists.tcl
# is sourced from xschem.tcl before any PDK `_procs.tcl` runs, so it would
# write into an empty registry and register's REPLACE semantics would then
# discard it at the PDK's own registration.
#
# ⚠ THIS SECTION MUTATES THE REGISTRY and therefore runs LAST, after every row
# that reads the shipped IHP descriptors.
# RED BEFORE B2.
ol_reset
set A1_G0 $::op_annot::gen
ol_ans ::op_param_lists::set_list class mos annotation {{aid aid 0} {agm agm 1}}
set A1_RET [ol_ans ::op_param_lists::apply]
set A1_G1 $::op_annot::gen
set A1_NMOS [expr {[catch {dict get [::op_annot::descriptor nmos] params} p] ? "RAISED" : $p}]
set A1_PMOS [expr {[catch {dict get [::op_annot::descriptor pmos] params} q] ? "RAISED" : $q}]
set A1_NPN  [expr {[catch {dict get [::op_annot::descriptor vertical_npn] params} r] ? "RAISED" : $r}]
set A1_MATCH [expr {[catch {dict get [::op_annot::descriptor nmos] match} m] ? "RAISED" : $m}]
set A1_SHOWN [ol_dkey nmos shown]
set A1_BODY [ol_body ::op_param_lists::apply]
## the three PDK files' RECOVERY recipe (invariant I5) must still round-trip
set A1_D [::op_annot::descriptor nmos]
dict set A1_D params {{vdsat vdsat 2}}
::op_annot::register nmos $A1_D
set A1_REC [expr {[catch {dict get [::op_annot::descriptor nmos] params} s] ? "RAISED" : $s}]
# ⚠ THIS ROW'S `params` GOLDEN CHANGED WITH ITEM B2b, AND THAT IS THE POINT.
# Under ruling DD-4 `apply` writes the UNION of the annotation and summary
# lists into `params` — what the RUN computes — and the narrowed annotation
# list into the display key `shown`, which is what the SHEET draws (DD-6). The
# union is taken over `effective`, never `get_list`, so an UNOWNED summary
# answers the PDK seed and `params` can only ever be a SUPERSET of what it held
# before. Here the user owns `annotation` only, so the summary half is IHP's
# own six ($OL_MOS6) and no label collides — the union is the two user rows
# followed by all six. `shown` is those six-plus-two FILTERED by the annotation
# list's labels, which is what makes `shown` a subset of `params` BY
# CONSTRUCTION (see section D, row D5).
# The row's other seven legs are UNCHANGED and must stay so: gen moves, both
# mos types take it, a class the user owns nothing for is left alone, `match`
# survives, `apply` assigns ::op_annot::desc nowhere, and the PDK recovery
# recipe still round-trips. RED BEFORE B2b on the `params` and `shown` legs.
## ⚠ ONE LINE ON PURPOSE: `check` compares STRINGS, so a golden broken across
## two lines carries the newline and the indent into the comparison.
set A1_UNION {{aid aid 0} {agm agm 1} {id ids 0} {gm gm 1} {gds gds 1} {vgs vgs 2} {vth vth 2} {vds vds 2}}
check {A1 the apply door is op_annot::register: gen MOVES, both mos types take the UNION in `params` and the user's narrowed list in `shown`, a class the user owns nothing for is left alone, the rest of the descriptor survives, `apply` assigns ::op_annot::desc nowhere, and the PDK recovery recipe still round-trips afterwards} \
  [list [expr {$A1_G1 > $A1_G0 ? 1 : 0}] \
        [lsort $A1_RET] $A1_NMOS $A1_PMOS $A1_NPN $A1_MATCH $A1_SHOWN \
        [ol_count $A1_BODY {op_annot::desc(}] \
        [ol_count $A1_BODY {desc(}] \
        [ol_has $A1_BODY {op_annot::register}] \
        $A1_REC] \
  [list 1 {nmos pmos} $A1_UNION $A1_UNION $OL_NPN6 \
        {*sg13g2_pr/*} {{aid aid 0} {agm agm 1}} 0 0 1 {{vdsat vdsat 2}}]

# ============================================================================
# SECTION D — WHAT THE SHEET DRAWS (item B2b: 1285, 1289, DD-6 + AMENDMENT)
# ============================================================================
# ONE FIELD, TWO CONSUMERS, AND THAT IS THE DEFECT. `op_annot::text` iterates
# `dict get $d params` (op_annot.tcl:1742) and `op_annot::_cards_for` iterates
# THE SAME LIST (:2816). DD-4's union makes `params` a SUPERSET of what the
# user asked to see, so with one field the sheet gets WIDER when the user trims
# it — the opposite of *declutter*, the word the feature is named after, and
# item B5's Delete button would have no visible effect at all.
#
# DD-6 adds a SECOND descriptor key, `shown`, which the display PREFERS and
# `_cards_for` never reads. `op_param_lists::apply` writes BOTH: the UNION into
# `params` (what the run computes) and the narrowed list into `shown` (what the
# sheet draws).
#
# ⚠ THE AMENDMENT IS WHY THIS SECTION EXISTS AT ALL. Item B2a-2 shipped a
# `shown` key whose two written guarantees were both MEASURED FALSE, and it was
# reverted for exactly that. Both are attacked here, not asserted:
#   (1) SUBSET BY CONSTRUCTION — row D5 does not read a comment claiming
#       `shown` ⊆ `params`; it computes the membership of every `shown` triple
#       under issue 1288's LIVE duplicate-label door, which is the input that
#       produced the violation last time.
#   (2) A MALFORMED KEY NEVER RAISES — row D6 registers two DIFFERENT broken
#       shapes, because a guard that closes one leaves the other open.
#       MEASURED on this tree: `shown` = `{broken` makes even `llength` raise
#       `unmatched open brace in list`, but `shown` = `{id id 0} {d "x}` has
#       `llength` 2 and raises `unmatched open quote in list` only at the
#       `lindex` of its SECOND ROW. A `catch {llength ...}` — which issue
#       1285's "Still open" item 2 and spec §4(b) both recommend, at REGISTER
#       time — does not close the second shape. The guard must walk the rows.
#
# ⚠ AND THE OTHER DOOR MUST STAY OPEN. Row D7 is the fence: a malformed
# `params` STILL raises, exactly as test_op_annot's K17 (:2586-2599) golds it.
# A fallback implemented as a blanket catch around the row build would swallow
# that raise too, silently closing issue 0447 and moving a count this item's
# acceptance pins at 485/492. D7 is red against that mistake and nothing else.
#
# ============================================================================
# WHICH OF THESE ARE RED BEFORE B2b, AND WHICH ARE NOT — SAY IT OUT LOUD
# ============================================================================
# MEASURED at HEAD 81ecfc4d against src/xschem as built 2026-09-03 14:21:
#   RED    D2 D3 D4 D5 D8 D10 and C2, and the REVISED A1 above.
#   GREEN  D0 D1 D9, which are CONTROLS AND FENCES and prove nothing about the
#          fix: D1 is invariant I7 (all four shipped PDK register sites declare
#          `params` alone, so every shipped PDK is D1's case and must draw
#          exactly as it does today), D0 says the fixture is live, D9 says the
#          draw-time proc gained no `xschem` call.
#   GREEN VACUOUSLY  D6 and D7. HEAD reads no display key at all, so a
#          malformed one is INERT — D6 cannot be red at HEAD and a receipt
#          claiming otherwise would be false. D6 is red against the PRESENCE-
#          ONLY guard item B2a-2 shipped, and that is the state it is written
#          to catch; the landing shows it red there before showing it green.
#          D7 is a fence on an existing behaviour and is green in every state
#          except the mistake it names.
#
# ============================================================================
# THE FIXTURE, AND WHY IT IS BUILT RATHER THAN READ OFF A PDK
# ============================================================================
# ⚠ THE BRIEF'S "IHP SHIPS THE FIXTURE: gm/id AND ft" IS FALSE ON THIS TREE,
# and so are issue 1289's line 39 ("IHP registers exactly such rows (`gm/id`,
# `ft`) in `ihp-sg13g2/sg13g2_procs.tcl`") and its line 74. MEASURED: all four
# shipped register sites — sky130_procs.tcl:407, gf180_procs.tcl:113,
# sg13g2_procs.tcl:764 and :814 — carry `devpath`/`devproc` + `match` +
# `params` AND NOTHING ELSE. Every `derived` in the three PDK files sits inside
# the RECOVERY-RECIPE COMMENT, and test_op_annot's own gold table P_DERIVEDACC
# (:904-911) golds `derived` = {} for all seven shipped types, because ruling
# D9 removed them. So DD-9's substance is untouched, but its fixture must be
# BUILT from that documented recipe under invariant I5 — which is what the
# recipe is FOR — and no row here may assert that IHP registers a `derived`
# key, because it does not.
#
# Both of the brief's named rows are exercised: `gm/id` AND `ft`.
#
# ⚠ THE RAW'S VECTOR NAMES COME FROM `op_annot::vector`, NEVER TYPED BY HAND
# (invariant I1: ONE name builder, two consumers). A fixture with hand-typed
# names cannot drift from the reader and therefore cannot see the failure I1
# exists to prevent.
#
# ⚠ THIS SECTION MUTATES THE REGISTRY AND LOADS A SCHEMATIC, so it runs after
# every row that reads the shipped IHP descriptors. It writes only under the
# scratch tree, changes no directory, and creates no untitled* — row H1 still
# has to pass at the end.
ol_reset
set D_LIB [file join $scratch b2blib]
file mkdir $D_LIB
set D_SCH [file join $D_LIB b2bd.sch]
set D_SYM [file join $repo xschem_library devices nmos.sym]
set _fd [open $D_SCH w]
puts $_fd "v \{xschem version=3.4.4 file_version=1.2\}"
puts $_fd "G \{\}"
puts $_fd "V \{\}"
puts $_fd "S \{\}"
puts $_fd "E \{\}"
puts $_fd "C \{$D_SYM\} 0 0 0 0 \{name=M1 model=nmosmod W=1 L=0.15\}"
close $_fd
set D_LOAD [catch {xschem load $D_SCH}]

## The RECOVERY RECIPE's own rows (sg13g2_procs.tcl:747-749, sky130:394,
## gf180:100), applied the way the recipe says to apply them (I5). `cgg` is
## there so `ft` has an operand; `gm/id` and `ft` are DD-9's two subjects.
set D_BASE [list devpath {@m.@path@name} \
                 params  {{id id 0} {gm gm 1} {cgg cgg 1}} \
                 derived {{gm/id {$gm/$id}} {ft {$gm/(2*3.14159265*$cgg)}}}]
## the same descriptor with NO derived rows — row D10's second half needs the
## difference between "the block emptied" and "only the params rows went".
set D_NODER [list devpath {@m.@path@name} \
                   params  {{id id 0} {gm gm 1} {cgg cgg 1}}]
ol_ans ::op_annot::register nmos $D_BASE
ol_ans ::op_annot::register pmos $D_BASE

set D_RAW [file join $scratch b2bd.raw]
set D_NAMES {}
foreach _p {id gm cgg} { lappend D_NAMES [ol_ans ::op_annot::vector M1 $_p] }
set _fp [open $D_RAW w]
puts -nonewline $_fp "Title: b2bd\nDate: Mon Jan 1 00:00:00 2026\n"
puts -nonewline $_fp "Plotname: Operating Point\nFlags: real\n"
puts -nonewline $_fp "No. Variables: [llength $D_NAMES]\nNo. Points: 1\nVariables:\n"
set _i 0
foreach _n $D_NAMES { puts -nonewline $_fp "\t$_i\t$_n\tnotype\n" ; incr _i }
## id = 10u, gm = 100u, cgg = 10f  ->  gm/id = 10, ft = 1.592G
puts -nonewline $_fp "Values:\n0\t1e-05\n\t1e-04\n\t1e-14\n"
close $_fp
set D_ANN [catch {xschem annotate_op $D_RAW}]

## THE GOLDEN BLOCKS, spelled out rather than eyeballed. The mint is
## `%-<w>s = %s` with w the widest LABEL (5, for `gm/id`), and a blank row is
## `label =` with nothing after the `=` — ruling D9b's format.
set D_ALL5   "id    = 10u\ngm    = 100u\ncgg   = 10f\ngm/id = 10\nft    = 1.592G\n"
set D_NARROW "id    = 10u\ngm/id = 10\nft    = 1.592G\n"
set D_CARDS3 {{.save m1[id]} {.save m1[gm]} {.save m1[cgg]}}
set D_CARDS4 {{.save m1[id]} {.save m1[gm]} {.save m1[cgg]} {.save m1[vth]}}

set D0_FIN {}
foreach _p {id gm cgg} {
  lappend D0_FIN [ol_ans ::op_annot::_finite \
                    [ol_ans ::op_annot::raw_or_blank [ol_ans ::op_annot::vector M1 $_p]]]
}
check {D0 CONTROL the fixture is live: the schematic loaded, the OP raw annotated, M1 is an nmos the registry claims, and all three vectors read back finite — without this every row below could pass by drawing nothing} \
  [list $D_LOAD $D_ANN [ol_ans ::op_annot::type M1] \
        [ol_ans ::op_annot::_annotated] [ol_ans ::op_annot::_claims M1] $D0_FIN] \
  {0 0 nmos 1 1 {1 1 1}}

# ---------------------------------------------------------------------------
# D1 — RED (b) OF THE BRIEF, AND INVARIANT I7. THIS ONE MUST NOT MOVE.
# A descriptor a PDK registered with NO narrowing key draws every `params` row
# exactly as it does today, and the save side is untouched. All four shipped
# register sites are this case, so D1 is the row that says the three PDKs draw
# exactly as they do now. GREEN BEFORE THE CHANGE — a control, not evidence.
set D1_TXT [ol_ans ::op_annot::text M1]
check {D1 CONTROL (invariant I7) a descriptor with NO display key draws EVERY params row and its derived rows, byte for byte as today, and _cards_for emits one card per params row} \
  [list [ol_dkey nmos shown] $D1_TXT [ol_rowlabels $D1_TXT] \
        [ol_ans ::op_annot::_cards_for M1 {}]] \
  [list NOKEY $D_ALL5 {id gm cgg gm/id ft} $D_CARDS3]

# ---------------------------------------------------------------------------
# D2 — RED (a): THE SHEET NARROWS AND THE DESCRIPTOR CARRIES BOTH FIELDS.
# RED AT HEAD: `params` is the annotation list ALONE ({{id id 0}}, issue 1280 —
# DD-4's union is not implemented at HEAD) and `shown` does not exist, so
# ol_dkey answers NOKEY.
ol_reset
ol_ans ::op_param_lists::set_list class mos annotation {{id id 0}}
ol_ans ::op_param_lists::set_list class mos summary    {{gm gm 1} {cgg cgg 1}}
set D2_RET [ol_ans ::op_param_lists::apply nmos]
set D2_TXT [ol_ans ::op_annot::text M1]
check {D2 after apply with a trimmed annotation list the descriptor carries BOTH lists — `params` is the UNION the run computes and `shown` is the narrowed list the sheet draws — and the sheet draws the annotation row and the derived rows and NOTHING ELSE} \
  [list $D2_RET [ol_dkey nmos params] [ol_dkey nmos shown] \
        $D2_TXT [ol_rowlabels $D2_TXT] \
        [ol_drawn $D2_TXT gm] [ol_drawn $D2_TXT cgg]] \
  [list nmos {{id id 0} {gm gm 1} {cgg cgg 1}} {{id id 0}} \
        $D_NARROW {id gm/id ft} 0 0]

# ---------------------------------------------------------------------------
# D3 — RED (a), THE OTHER HALF: THE SAVE SIDE DOES NOT NARROW WITH THE DISPLAY.
# `_cards_for` and `_claims` and `_kind` read `params` and must be blind to the
# display key — that is the whole reason DD-6 adds a second field instead of
# trimming the first. RED AT HEAD: one card, and `_kind M1 gm` RAISES because
# today's apply dropped `gm` out of `params` altogether.
check {D3 the SAVE side is blind to the display key: _cards_for still emits one card per params row including the two the sheet no longer draws, _claims still claims the instance, and _kind answers for a hidden parameter instead of raising} \
  [list [ol_ans ::op_annot::_cards_for M1 {}] \
        [ol_ans ::op_annot::_claims M1] \
        [ol_ans ::op_annot::_kind M1 gm] \
        [ol_ans ::op_annot::_kind M1 cgg]] \
  [list $D_CARDS3 1 1 1]

# ---------------------------------------------------------------------------
# D4 — RED (c), RULING DD-9: A DERIVED ROW READS THE RUN, NOT THE SHEET.
# `op_annot::text` evaluates its `vars` dict over `params` and DISPLAYS over
# the narrowed key, so a derived row keeps working when its operand is merely
# hidden. Both of the brief's named rows are here: `gm/id` needs `gm`, `ft`
# needs `gm` AND `cgg`, and neither operand is drawn.
# RED AT HEAD: both values are EMPTY — issue 1289's exact failure, reproduced
# at HEAD through `params` because today's apply removes the operand from the
# only list there is.
check {D4 DD-9 a derived row whose operand is in `params` but not in the display key STILL CARRIES A VALUE — gm/id and ft both compute while neither gm nor cgg is drawn} \
  [list [ol_rowval $D2_TXT gm/id] [ol_rowval $D2_TXT ft] \
        [ol_rowval $D2_TXT gm] [ol_rowval $D2_TXT cgg] \
        [ol_rowval $D2_TXT id]] \
  {10 1.592G NOROW NOROW 10u}

# ---------------------------------------------------------------------------
# D5 — RED (d): THE SUBSET IS ATTACKED, NOT ASSERTED.
# Issue 1288 is LIVE on this tree: `set_list class mos annotation {{A ids 0}
# {A vth 2}}` returns 1 with ZERO reports and `get_list` hands both rows back.
# So a `shown` built by COPYING the annotation list wholesale — which is what
# item B2a-2 shipped — can contain a triple that the union's label-dedup kept
# OUT of `params`, and `op_annot::_kind` raises on exactly that. The row
# computes the membership itself; it does not read a comment claiming it.
# RED AT HEAD (there is no `shown` key at all) AND RED against B2a-2's
# wholesale copy (`shown` would carry {A gm 1}, which is in no params list).
ol_ans ::op_annot::register nmos $D_BASE
ol_reset
ol_ans ::op_param_lists::set_list class mos annotation {{A id 0} {A gm 1}}
ol_ans ::op_param_lists::set_list class mos summary    {{cgg cgg 1}}
set D5_DUP [ol_ans ::op_param_lists::get_list class mos annotation]
set D5_RET [ol_ans ::op_param_lists::apply nmos]
set D5_P   [ol_dkey nmos params]
set D5_S   [ol_dkey nmos shown]
set D5_SUB 1
if {[catch {
  foreach _t $D5_S { if {[lsearch -exact $D5_P $_t] < 0} { set D5_SUB 0 } }
} _e]} { set D5_SUB "RAISED:$_e" }
set D5_TXT [ol_ans ::op_annot::text M1]
check {D5 THE SUBSET HOLDS BY CONSTRUCTION under issue 1288's live duplicate-label door: every `shown` triple is literally an element of `params`, the second duplicate is deduped out of both, and the draw does not raise} \
  [list $D5_DUP $D5_RET $D5_P $D5_S $D5_SUB \
        [ol_rc ::op_annot::text M1] [ol_rowlabels $D5_TXT]] \
  [list {{A id 0} {A gm 1}} nmos {{A id 0} {cgg cgg 1}} {{A id 0}} 1 \
        0 {A gm/id ft}]

# ---------------------------------------------------------------------------
# D6 — RED (e): A MALFORMED DISPLAY KEY DRAWS THE `params` ROWS AND NEVER
# RAISES. `op_annot::text` runs PER INSTANCE PER REDRAW from C
# (actions.c:2085-2090). That call IS already `catch`-wrapped, so a raise is
# not literally a black schematic — MEASURED, it is worse in one way: the
# instance's WHOLE annotation block silently becomes empty, and because
# actions.c:1764 -> annot_instance_annotated() -> annot_block_has_value() reads
# the rendered block, the declutter then switches OFF for that instance too,
# with no message anywhere.
# ⚠ GREEN VACUOUSLY AT HEAD — no display key is read, so nothing can be
# malformed. This row is red against B2a-2's presence-only guard, and against
# any guard that checks only the OUTER list.
set D_OB "\x7b"      ;# a literal open brace, K17's trick (test_op_annot.tcl:2586)
set _d $D_BASE ; dict set _d shown "${D_OB}broken"
ol_ans ::op_annot::register nmos $_d
set D6_RC1  [ol_rc ::op_annot::text M1]
set D6_TXT1 [ol_ans ::op_annot::text M1]
## the NESTED break: `llength` is 2 and only the `lindex` of row 2 raises
set _d $D_BASE ; dict set _d shown {{id id 0} {d "x}}
ol_ans ::op_annot::register nmos $_d
set D6_LEN  [ol_ans ::llength [ol_dkey nmos shown]]
set D6_RC2  [ol_rc ::op_annot::text M1]
set D6_TXT2 [ol_ans ::op_annot::text M1]
check {D6 a MALFORMED display key is treated as ABSENT and the params rows draw: BOTH measured shapes — the outer unmatched brace AND the nested one whose llength is 2 and which raises only at the lindex of its second row} \
  [list $D6_RC1 $D6_TXT1 $D6_LEN $D6_RC2 $D6_TXT2] \
  [list 0 $D_ALL5 2 0 $D_ALL5]

# ---------------------------------------------------------------------------
# D7 — THE FENCE ON THE OTHER DOOR. A malformed `params` STILL raises, with or
# without a well-formed display key beside it. test_op_annot's K17 (:2586-2599)
# golds that raise from the other suite; a fallback written as a blanket catch
# around the row build would swallow it, close issue 0447 by accident, and move
# a count this item's acceptance pins at 485/492. GREEN BEFORE THE CHANGE.
set _d $D_BASE ; dict set _d params "{id id 0} ${D_OB}broken"
ol_ans ::op_annot::register nmos $_d
set D7_A [ol_ans ::op_annot::text M1]
dict set _d shown {{id id 0}}
ol_ans ::op_annot::register nmos $_d
set D7_B [ol_ans ::op_annot::text M1]
check {D7 FENCE issue 0447's existing raise door SURVIVES: a malformed `params` still raises at draw time, both with no display key and with a WELL-FORMED one present — the fallback must not become a blanket catch} \
  [list $D7_A $D7_B] \
  [list {RAISED:unmatched open brace in list} {RAISED:unmatched open brace in list}]

# ---------------------------------------------------------------------------
# D8 — apply's OWNERSHIP GUARD, AND ITS TWO PASSES.
# HEAD's guard is `owns class $c annotation` ALONE, so a user who owns only a
# SUMMARY list gets nothing written: the deck never saves her parameters and
# every summary row renders permanently blank (invariant I3) with no report —
# the precise failure DD-4 exists to prevent. Under the union the guard must be
# `annotation OR summary`, and the cost is DD-4's stated one, a slightly larger
# raw: the SHEET here is byte-identical to D1's.
# The pmos leg is the two-pass fence. `_save_set` reads the PDK seed through
# ::op_annot::descriptor and the second pass rewrites exactly those
# descriptors, so a single loop would hand pmos the `params` apply had just
# rewritten for nmos.
# RED AT HEAD: apply returns {} and writes nothing at all.
ol_ans ::op_annot::register nmos $D_BASE
ol_ans ::op_annot::register pmos $D_BASE
ol_reset
ol_ans ::op_param_lists::set_list class mos summary {{vth vth 2}}
set D8_RET [ol_ans ::op_param_lists::apply nmos pmos]
set D8_TXT [ol_ans ::op_annot::text M1]
check {D8 with ONLY a summary list owned, apply still writes both fields: `params` GAINS the summary row so the deck saves it, `shown` is the PDK seed unchanged, the sheet is BYTE-IDENTICAL to D1's, and pmos gets the seed too rather than the list nmos was just given} \
  [list $D8_RET [ol_dkey nmos params] [ol_dkey nmos shown] [ol_dkey pmos shown] \
        [expr {$D8_TXT eq $D_ALL5 ? 1 : 0}] \
        [ol_ans ::op_annot::_cards_for M1 {}]] \
  [list {nmos pmos} {{id id 0} {gm gm 1} {cgg cgg 1} {vth vth 2}} \
        {{id id 0} {gm gm 1} {cgg cgg 1}} {{id id 0} {gm gm 1} {cgg cgg 1}} \
        1 $D_CARDS4]

# ---------------------------------------------------------------------------
# D9 — DD-9's BINDING CONSTRAINT, STRUCTURALLY: `op_annot::text` may gain NO
# new `xschem` call and NO new raise site (issue 0447). It is a draw-time proc
# and 1289's own acceptance says so. MEASURED at HEAD: the comment-stripped
# body carries exactly ONE `xschem ` literal (the pinexpr `xschem translate` at
# :1775, already inside a catch) and ZERO `return -code`.
# ⚠ AT HEAD THE DISPLAY-HELPER GLOB MATCHES NOTHING, so its two legs are
# vacuously 0 and the live legs are `text`'s. They arm the moment the helper
# exists — which is the point of a fence. GREEN BEFORE THE CHANGE.
set D9_TBODY [ol_body ::op_annot::text]
set D9_DBODY {}
foreach _p [lsort [info procs ::op_annot::_display*]] { append D9_DBODY [ol_body $_p] "\n" }
check {D9 FENCE the draw-time proc gains no `xschem` call and no raise site: op_annot::text's comment-stripped body still carries exactly ONE `xschem ` literal and ZERO `return -code`, and the display helper adds neither} \
  [list [ol_count $D9_TBODY {xschem }] [ol_count $D9_TBODY {return -code}] \
        [ol_count $D9_DBODY {xschem }] [ol_count $D9_DBODY {return -code}]] \
  {1 0 0 0}

# ---------------------------------------------------------------------------
# D10 — PRESENT-AND-EMPTY IS NOT ABSENT. *** STATUS E: THE USER HAS NOT RULED
# ON THIS. *** Only an ABSENT key falls back to `params`; a key that is present
# and EMPTY draws no params rows at all. The default falls this way because the
# alternative makes item B5's Delete of the LAST row a silent no-op, which is
# the invisible-Delete failure DD-6 exists to prevent.
# THE QUESTION FOR THE USER, recorded as rule debt `1285_empty_display_key`:
# when a user deletes EVERY row from a device's annotation list, that device's
# whole OP block disappears from the sheet — and because actions.c:1764 reads
# the rendered block, the device also drops OUT of the declutter, so the texts
# the declutter was hiding come back. Is that what "delete them all" should do?
# Note the effect is NOT uniform: a descriptor that also carries `derived` or
# `pinexpr` rows still draws a block, which is the second half of this row.
# RED AT HEAD (no key is read, so both descriptors draw their full block).
set _d $D_NODER ; dict set _d shown {}
ol_ans ::op_annot::register nmos $_d
set D10_A [ol_ans ::op_annot::text M1]
set _d $D_BASE ; dict set _d shown {}
ol_ans ::op_annot::register nmos $_d
set D10_B [ol_ans ::op_annot::text M1]
check {D10 a display key PRESENT AND EMPTY is not the same as ABSENT: with no derived rows the instance draws NO BLOCK AT ALL, and with derived rows it still draws those — only an absent key falls back to `params`} \
  [list $D10_A $D10_B [ol_rowlabels $D10_B]] \
  [list {} "gm/id = 10\nft    = 1.592G\n" {gm/id ft}]

## leave the registry as section D found it for anything appended after it
ol_ans ::op_annot::register nmos $D_BASE
ol_ans ::op_annot::register pmos $D_BASE
ol_reset

# ============================================================================
# SECTION C — THE SHIPPED COMMENT THIS ITEM FINALLY ANSWERS
# ============================================================================
# All three PDK procs files carry "A first-class means for a user to choose her
# own set is OWED and TBD." B2 IS that means, so all three must now point at
# it. ⚠ FOUND BY TEXT, NEVER BY LINE NUMBER: the brief and spec §1 both give
# sky130's line as :405 and IHP's as :749, and MEASURED they are :396 and :750
# — sky130's :405 is `} else {` and IHP's :749 is a recovery-recipe line. Only
# gf180's :102 is right.
#
# The RECOVERY recipe above each comment is invariant I5's documented path and
# must keep working — row C0 is the control that it was there to begin with and
# row C1 is the assertion that it still is.
set C_FILES [list [file join $repo sky130A sky130_procs.tcl] \
                  [file join $repo gf180mcuD gf180_procs.tcl] \
                  [file join $repo ihp-sg13g2 sg13g2_procs.tcl]]
set C0_GOT {} ; set C1_GOT {}
foreach _f $C_FILES {
  set _t [ol_slurp $_f]
  lappend C0_GOT [ol_has $_t {set d [op_annot::descriptor nmos]}] \
                 [ol_has $_t {op_annot::register nmos $d}]
  lappend C1_GOT [ol_has $_t {op_param_lists.tcl}] \
                 [ol_has $_t {is OWED and TBD}] \
                 [ol_has $_t {set d [op_annot::descriptor nmos]}] \
                 [ol_has $_t {op_annot::register nmos $d}]
}
check {C0 CONTROL all three PDK files carry the invariant-I5 recovery recipe today, so C1's claim that it survived is not vacuous} \
  $C0_GOT {1 1 1 1 1 1}
check {C1 all three PDK procs files now POINT AT src/op_param_lists.tcl instead of saying the means is OWED and TBD, and each one's recovery recipe is untouched} \
  $C1_GOT {1 0 1 1 1 0 1 1 1 0 1 1}

# C2 — WHICH LIST IS WHICH, SAID IN THE PDK FILE ITSELF (item B2b, DD-6).
# A PDK author reading these files sees ONE list today and there are now TWO,
# with different jobs: `params` is what the RUN computes — the .save cards are
# built from it — and the display key `shown` is what the SHEET draws. Getting
# that backwards is how DD-4's union un-declutters the schematic, so it is
# named where a PDK author will actually read it rather than only in the spec.
# The two sentences are pinned as LITERALS because a row that greps for the
# word `shown` alone would be satisfied by the word appearing in any sentence,
# including a wrong one.
# ⚠ The recovery recipe above each must stay byte-identical — that is row C0's
# job, and C0 is checked again here by still being green.
# RED BEFORE B2b: neither sentence is in any of the three files.
set C2_GOT {}
foreach _f $C_FILES {
  set _t [ol_slurp $_f]
  lappend C2_GOT [ol_has $_t {params is what the run computes}] \
                 [ol_has $_t {shown is what the sheet draws}]
}
check {C2 all three PDK procs files now say WHICH LIST IS WHICH: params is what the run computes and the display key is what the sheet draws} \
  $C2_GOT {1 1 1 1 1 1}

# ============================================================================
# SECTION R — REGISTRATION
# ============================================================================
# full_audit.sh selects by GLOB; the three named lists are OPT-INS for special
# run modes. This suite needs no X and is in NONE of them, and full_audit.sh is
# NOT edited by item B2. GREEN before B2.
set R_ME  [file rootname [file tail [info script]]]
set R_TXT [ol_slurp $OL_AUDIT]
check {R1 registered by glob, listed in none of nogui_tests / logdir_tests / nolog_tests} \
  [list [string match {test_*} $R_ME] \
        [expr {[regexp {mapfile -t files < <\(ls "\$HERE"/test_\*\.tcl \| sort\)} $R_TXT] ? 1 : 0}] \
        [expr {[string first $R_ME $R_TXT] >= 0 ? 1 : 0}]] \
  {1 1 0}

# ============================================================================
# SECTION H — HYGIENE (hard rule 6)
# ============================================================================
# An untracked untitled*.sch in the repo root turns THREE tests red. This suite
# loads no schematic and saves none. ⚠ The repo root ALREADY holds untitled~.sch
# and untitled~.sym and they are DELIBERATELY LEFT THERE (they are the known
# cause of test_ase_core's C11 baseline red, a phantom nothing in this batch may
# "fix"), so the row compares the glob against itself rather than asserting it
# is empty. It also asserts that this suite created no `.xschem` directory in
# the repo root — the tier rows `cd` into the scratch tree precisely so that a
# writer cannot drop one on the developer.
# ============================================================================
# SECTION Z — ISSUE 1291: THE PDK'S `params` IS AN UNVALIDATED STRING
# ============================================================================
# A descriptor may be registered from a user's own rc (invariant I5, the
# documented way to choose a different parameter set), so `params` can be any
# string at all. Every guard in `_params` asked a question about the DICT and
# none asked whether the value parses as a LIST.
#
# Item B2b opened the door without meaning to: HEAD's `apply` never called
# `seed`, and B2b's union is what made the seed reachable from `apply`. The
# vulnerable shape is the user owning `annotation` ONLY, because `summary` then
# falls through to the seed. Measured before the fix: apply rc 0 -> 1, message
# `unmatched open brace in list`, nothing written, and the descriptor
# permanently un-applyable for the rest of the session.
#
# ⚠ THE FIXTURE STRING IS BUILT, NOT WRITTEN AS A LITERAL. An unbalanced brace
# in this file would make the FILE fail `info complete`. That is not a
# hypothetical: it is how the fix's own comment was first written, and it was
# caught immediately by a syntax check rather than by a test.
# RED before the 1291 fix: Z1, Z2, Z3.

set Z_BAD "[format %c 123]id id 0[format %c 125] [format %c 123]bad"

check_true {Z0 the fixture really is malformed: llength raises on it, so the rows below are not vacuous} \
  [catch {llength $Z_BAD}]

catch {op_param_lists::reset}
op_annot::register nmos [list devpath {@m.@path@name} params $Z_BAD]
check {Z1 a params list that does not parse answers EMPTY instead of raising, and says which type it dropped} \
  [list [catch {op_param_lists::_params nmos} zp] $zp \
        [expr {[string match {*does not parse*} [op_param_lists::said]] ? 1 : 0}]] \
  {0 {} 1}

## ⚠ BOTH TYPES OF THE CLASS ARE POISONED HERE, AND THE FIRST DRAFT OF THIS ROW
## DID NOT DO THAT AND FAILED. Class `mos` seeds from `nmos` AND `pmos`, and an
## earlier fixture in this file leaves `pmos` valid — so poisoning `nmos` alone
## leaves `seed mos` answering pmos's list, which is CORRECT (the map is not
## onto; one bad type does not blind the class). The row's golden was wrong, not
## the code. To assert "nothing leaks" the class must have no valid type left.
op_annot::register pmos [list devpath {@m.@path@name} params $Z_BAD]
check {Z2 with EVERY type of the class poisoned, nothing leaks through seed or effective either} \
  [list [catch {op_param_lists::seed mos} zs] $zs \
        [catch {op_param_lists::effective mos annotation} ze] $ze] \
  {0 {} 0 {}}

## THE ROW THE ISSUE TURNS ON: the exact vulnerable shape, user owns
## `annotation` only. apply must still apply, must not raise, and must report.
catch {op_param_lists::reset}
op_annot::register nmos [list devpath {@m.@path@name} params $Z_BAD]
op_param_lists::set_list class mos annotation {{id id 0}}
check {Z3 THE 1291 SHAPE: apply does not raise, still applies to both mos types, and reports why the seed was dropped} \
  [list [catch {op_param_lists::apply} za] $za \
        [expr {[string match {*does not parse*} [op_param_lists::said]] ? 1 : 0}]] \
  {0 {nmos pmos} 1}

## A well-formed OUTER list holding a malformed ELEMENT raises one line later,
## at the `lindex` that reads the triple. Both levels are checked, so both are
## fenced.
set Z_BADROW [list {id id 0} "[format %c 123]bad"]
catch {op_param_lists::reset}
op_annot::register nmos [list devpath {@m.@path@name} params $Z_BADROW]
check {Z4 a well-formed list holding a malformed ROW is dropped whole, not half-read} \
  [list [catch {op_param_lists::_params nmos} zr] $zr] {0 {}}

catch {op_param_lists::reset}

set H_ROOT0 [lsort [glob -nocomplain -directory $repo -tails untitled*]]
check {H1 HYGIENE the suite creates no untitled* anywhere and no .xschem directory in the repo root, and it left the cwd where it found it} \
  [list [expr {[lsort [glob -nocomplain -directory $repo -tails untitled*]] eq $H_ROOT0 ? 1 : 0}] \
        [llength [glob -nocomplain -directory $scratch -tails untitled*]] \
        [llength [glob -nocomplain -directory $here -tails untitled*]] \
        [expr {[file isdirectory [file join $repo .xschem]] ? 1 : 0}] \
        [expr {[pwd] eq $T_OLDPWD ? 1 : 0}]] \
  {1 0 0 0 1}

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; exit 1 }
