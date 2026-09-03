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
set A1_BODY [ol_body ::op_param_lists::apply]
## the three PDK files' RECOVERY recipe (invariant I5) must still round-trip
set A1_D [::op_annot::descriptor nmos]
dict set A1_D params {{vdsat vdsat 2}}
::op_annot::register nmos $A1_D
set A1_REC [expr {[catch {dict get [::op_annot::descriptor nmos] params} s] ? "RAISED" : $s}]
check {A1 the apply door is op_annot::register: gen MOVES, both mos types take the user's list, a class the user owns nothing for is left alone, the rest of the descriptor survives, `apply` assigns ::op_annot::desc nowhere, and the PDK recovery recipe still round-trips afterwards} \
  [list [expr {$A1_G1 > $A1_G0 ? 1 : 0}] \
        [lsort $A1_RET] $A1_NMOS $A1_PMOS $A1_NPN $A1_MATCH \
        [ol_count $A1_BODY {op_annot::desc(}] \
        [ol_count $A1_BODY {desc(}] \
        [ol_has $A1_BODY {op_annot::register}] \
        $A1_REC] \
  [list 1 {nmos pmos} {{aid aid 0} {agm agm 1}} {{aid aid 0} {agm agm 1}} $OL_NPN6 \
        {*sg13g2_pr/*} 0 0 1 {{vdsat vdsat 2}}]

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
