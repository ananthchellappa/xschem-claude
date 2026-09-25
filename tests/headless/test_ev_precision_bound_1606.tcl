# tests/headless/test_ev_precision_bound_1606.tcl
#
# ISSUE 1606 -- thirteen sprintf() statements took their precision INDIRECTLY
# ("%.*g") and none of them bounded it, so a precision of 73 or more overran an
# 80-byte buffer and the fortified sprintf killed the process:
#
#     *** buffer overflow detected ***: terminated        SIGABRT, rc 134
#
# and main.c's sig_handler does NOT trap SIGABRT, so there is no emergency save
# either. The smallest reproducer is one line:
#
#     set ::ev_precision 200 ; xschem eval_expr {expr_eng(1e300*1.0)}
#
# ⚠ AND IT IS FILE-BORNE, WHICH IS WHAT MAKES IT MORE THAN A MISCONFIGURATION.
# A .sch carrying a `floater=true` T record whose value is
# `tcleval([set ::ev_precision 200]...)`, or a .sym whose `format=` attribute is
# a `tcleval(...)`, sets ev_precision while the file is merely OPENED (the load
# draws, the draw evaluates the floater) or NETLISTED. Section B7 drives that.
#
# ⚠ AND THE HONEST HALF, IN THE SAME BREATH: the mechanism is tcl_hook2 ->
# tclpropeval2 -> `uplevel #0 "subst \{$s\}"`, and `subst` performs COMMAND
# substitution, so a .sch/.sym already gives arbitrary Tcl at global level (and a
# generator name gives arbitrary shell through popen). That is a documented xschem
# feature, far larger than 1606. FIXING 1606 DOES NOT MAKE OPENING A STRANGER'S
# SCHEMATIC SAFE. This suite fences a buffer overflow, nothing more.
#
# THE FIX, in three layers, all of which this file fences:
#   1. ONE helper, `clamp_prec_g(int prec, size_t avail)` in src/editprop.c,
#      cap = avail - 9 (worst case for "%.*g%c" is prec+8 chars plus the NUL),
#      with prec <= 0 returned UNCHANGED because 0 is eval_expr's "engineering
#      off" flag and a negative means "printf's default".
#   2. `dtoa_eng` clamps its OWN parameter, above the suffix branch -- the only
#      thing that makes it correct for all 24 of its callers, including
#      graph_marker_text_rec, whose prec no writer clamp reaches. Its "%.*gMEG"
#      arm then clamps ONCE MORE against `sizeof(s) - 2`, because "MEG" is three
#      format bytes where "%c" is one: at the 71 the clamp above yields, that arm's
#      static worst case is 82 bytes into 80. GCC FOUND THAT, not this suite (see
#      section Y and K3); the value range hid it from every sweep.
#   3. Every writer of xctx->ev_precision (draw(), draw_graph(), kklex()) and
#      every indirect-precision sprintf site clamps against its own buffer.
#
# ⚠ WHY MOST OF THIS SUITE IS STATIC, AND IT IS NOT LAZINESS -- READ THIS BEFORE
# "STRENGTHENING" A ROW INTO A BEHAVIOURAL ONE.
# The clamps are deliberately REDUNDANT: the writers cap ev_precision at
# DTOA_ENG_BUFSIZE - 9 == 71, and every use site caps again against its own
# buffer. Measured during this batch: with either the kklex() clamp or the
# dtoa_eng clamp alone still present, removing the OTHER leaves the behavioural
# reproducer GREEN, because the survivor produces the same 71-digit string. Two
# redundant clamps on one path means neither has a behavioural row that reddens
# on its own removal. So the per-clamp fence is a STATIC row asserted BY NAME,
# and the behavioural rows are end-to-end: each one's comment states which
# clamps must ALL be gone before it reddens.
#
# ⚠ AND THE STATIC ROWS READ WHAT THE COMPILER READS, NOT WHAT THE FILE SAYS.
# This tree has defeated a whole-file regexp twice before this issue: a `#if 0`
# region holding a byte-for-byte clone of the live code (issue 1607 row V27) and a
# source COMMENT quoting the very guard the row grepped for (issue 1603 rows
# S1-S4). The fix's own comments quote `clamp_prec_g` repeatedly, so a raw grep
# here would pass on a tree with every clamp deleted. So ONE C tokeniser (`ctok`)
# removes comments and marks string and char literals, a three-valued preprocessor
# (`cs_pp`) drops the branches that are DEAD ON THIS BUILD using a MEASURED macro
# table, and `cfind`/`ccount` match only at code positions. Whitespace is collapsed
# because at least one shipped clamp spans two physical lines. Section Z fences all
# of that, clause by clause, and the section-Z header lists the ten decoy shapes
# three rounds of independent sabotage actually used.
#
# ⚠⚠ NAMED LIMITS OF STATIC FENCING HERE -- WHAT IS STILL OUT OF REACH, AND WHY
# THIS PARAGRAPH IS THE DELIVERABLE RATHER THAN AN APOLOGY.
# Each of FOUR hardening rounds found a new decoy SPELLING, which is the signature
# of chasing spellings instead of classes. The preprocessor/comment/literal classes are
# closed by section Z; the fourth round's three were not preprocessor shapes at all but
# legal C spelled differently from the needle, and they are closed by `cs_norm` and by
# W4/W4c asking their question of a SHAPE rather than of a string (see the section-Z
# header's second table). The limits below are not closed, they are named on purpose,
# and none of them is closed by adding another regexp:
#
#  1. `if(0) precision = clamp_prec_g(precision, sizeof(s));` -- decoy N1. It uses
#     NO preprocessor, no comment and no literal: the text is at a true statement
#     position and every static row in this file must accept it. There is no
#     principled static fix and a special case for `if(0)` would only move the
#     spelling on (`if(never)`, `while(0)`, `0 && (...)`, an `#if` on a macro this
#     suite cannot decide). ⚠ THE FENCE THAT DOES CATCH IT IN editprop.c IS ROW Y1a,
#     and only there: with the clamp's result not reaching the conversion, gcc at
#     -Wformat-overflow=2 reports `'%.*g' directive writing between 1 and 310 bytes
#     into a region of size 80` TWICE. MEASURED 2026-09-25, and the count is two and
#     not three because the "%.*gMEG" arm now carries its own clamp and is bounded,
#     so only two of dtoa_eng's three conversions are unbounded under N1 -- an earlier
#     revision of this paragraph said three and contradicted the Y1a proof line
#     (`{2 {...}}`) in the receipt it shipped with, doc/claude/issue_1606_batch/
#     receipts/C3-close.md. That works ONLY because clamp_prec_g and those
#     conversions are in the SAME translation unit; -flto was not driven.
#     ⚠ AND AT THE OTHER TWELVE CALL SITES THE SHAPE IS NOT UNFENCED -- THE LIMIT IS
#     ONE SITE WIDE, NOT TWELVE. An earlier revision said it was "caught by NOTHING in
#     this file" at all twelve. MEASURED (receipts/C3v-final.md §2.3, re-driven this
#     round as Q_cur2/Q_wgraph/Q_snm2): of the fourteen clamp_prec_g call sites, TWO are
#     dtoa_eng's own and Y1a sees them; at the THREE WRITER sites an `if(0)` in front
#     of the clamped write leaves the unclamped one for W4 (and W4c); at EIGHT sprintf
#     sites it leaves an unclamped `%.*` argument for X1. EXACTLY ONE SITE IS EXPOSED:
#     `show_node_measures`, because its formats are `char *` variables so X1 is blind
#     there (limit 2 below) and its clamp is a separate `int prec = ...` statement that
#     an `if(0)` satisfies textually -- G5 is its only fence, which is the same single
#     point decoy N4 established. 2 + 3 + 8 + 1 = 14.
#  2. A format string assembled from a macro or a variable -- `#define F "%.*g"` and
#     then `sprintf(b, F, p, v);`, or show_node_measures' real `char *fmt1/fmt2`.
#     X1 cannot see a `%.*` that is not in the statement. G5/G5b fence the one real
#     instance BY VARIABLE NAME; a new one would be unfenced by X1.
#  3. A decoy `#define DTOA_ENG_BUFSIZE` under an UNDECIDABLE `#ifdef` at file scope
#     in src/xschem.h, with the real macro raised. H5 is a whole-file row, so
#     section Z (which reads function BODIES) does not cover it. The behavioural
#     digit-count rows do -- see the section-Z header.
#  4. `.y` and `.l` are not C, so the tokeniser is approximate on them and can drop
#     text. Dropping text is a defeat for a NEGATIVE row, not a harmless over-strip.
#     Today the only `.y`/`.l` row is W3, which is positive.
#  5. Anything a sabotage puts in THIS FILE rather than in the product: D1b's own
#     fixture, and the two provenance comments R5a/R5b, are unfenced by
#     construction and said to be (receipts/C2-repair.md deviation 8).
#  6. A write to xctx->ev_precision that does not SPELL the field: through a pointer
#     or an aliased struct copy (`p = xctx; p->ev_precision = 200;`), or through a
#     macro alias for the field itself (`#define ZZEVP xctx->ev_precision` then
#     `ZZEVP += 200;`). W4 reads the field by name and W4c reads the Tcl variable by
#     name; neither follows an alias, and no textual row can.
#     ⚠ AND THE REASSURANCE THAT USED TO STAND HERE WAS FALSE, MEASURED. It said a
#     value that never comes from `tclgetintvar("ev_precision")` cannot be the 1606
#     input, and one that does is caught at the read wherever it goes. Driven (decoy
#     M8b): draw_graph's own properly-wrapped read, which W4c correctly ACCEPTS, then
#     `ZZEVP += 200;` immediately after -- the field reaches 271 and NO STATIC ROW
#     reddens. D2/D3/D4 catch it, and they are display-arm rows that self-skip on the
#     arm CLAUDE.md requires the zero to hold on. So this limit is wider than W4c
#     narrows it to, and the fix for anyone who needs it is a read-back seam
#     (`xschem get ev_precision`), which this tree does not have.
#  7. Y1c proves the compile can emit a -Wformat-OVERFLOW diagnostic. A CFLAGS
#     carrying only `-Wno-format-truncation` leaves Y1c green while silencing the
#     truncation half of Y1b. ⚠ It does NOT silence Y1a: `ycompile` emits
#     `$cc $cflags $extra`, so Y1a's own explicit `-Wformat-truncation=2` comes AFTER
#     the `-Wno-` and gcc honours the later flag (measured: trunc_diag=1 at Y1a's flag
#     set, 0 at Y1b's). `-w` is position-independent by design and IS caught in both
#     positions, which is why the -w measurement does not generalise to a specific
#     `-Wno-`. A second synthetic for the truncation half is the fix if anyone ever
#     writes such a CFLAGS line.
#  8. A `%.*` that is not CONTIGUOUS TEXT in the statement. C concatenates adjacent
#     string literals in translation phase 6, so `sprintf(b, "%." "*g", p, v);` has
#     `%.*g` as its real format while the statement's text does not contain `%.*`.
#     X1 and X2 both open by requiring that substring, so they SKIP such a statement,
#     and nothing else in this file looks at it. Siblings: `"%" ".*g"` and an escaped
#     `"%.\052g"`. Driven in src/actions.c AND in src/draw.c with a 24-byte
#     destination: the suite stays green and `make` emits no warning either, because
#     the build's own -Wformat-overflow level says nothing about a `%.*g` whose
#     precision gcc cannot range, and Y1a is scoped to editprop.c. This is the widest
#     hole named here.
#  9. A `#define` alias chain of more than one hop to `sprintf`
#     (`#define SPA sprintf` / `#define SPB SPA` / `SPB(b, "%.*g", p, v);`).
#     `sprintf_aliases` matches a replacement list that IS `sprintf`, so a two-hop
#     chain yields nothing and X1/X2 see no statement.
#
# ⚠ NO COUNT OF THESE LIMITS IS CLAIMED, AND THAT IS DELIBERATE. Five consecutive
# hardening rounds each shipped a sentence saying how many shapes escape these rows,
# and a crew refuted the number every time -- rounds two and three found four and then
# eleven new spellings, and the round that wrote "ONE shape is still out of reach" had
# three more sitting in the tree. A static row over C text decides a SET OF SPELLINGS,
# never a property of the program, so the honest form is a named list that may grow,
# not a total. Limits 1-9 are the shapes someone has actually driven. The fences that
# do not have this weakness are the BEHAVIOURAL rows (sections B and D) and the
# COMPILER-DIAGNOSTIC rows (Y1a/Y1b, themselves fenced by Y1c) -- prefer adding one of
# those over widening a regexp.
#
# ⚠ AND `show_node_measures` IS A THIRD SHAPE OF THE SAME TRAP: its format
# strings are `char *` VARIABLES (fmt1/fmt2), not literals, so a row grepping
# near that site for a literal "%.*g" matches NOTHING. G5/G5b fence it by the
# variable names and by the clamped local.
#
# SECTIONS
#   H1-H6   THE HELPER and the single source of the number. clamp_prec_g exists,
#           passes prec <= 0 through, refuses an avail too small for any
#           conversion, derives its cap as avail - 9, and DTOA_ENG_BUFSIZE is
#           what dtoa_eng's buffer and the writers use, so the number 71 is
#           written down nowhere in C.
#   K1-K3   dtoa_eng CLAMPS ITS OWN PARAMETER, above the branch (adjudication C4).
#   W1-W6   THE THREE WRITERS of xctx->ev_precision, plus two rows proving there is
#           no fourth UNCLAMPED one: W4 asks it of every WRITE to the field (any
#           spacing, one statement or two, compound assignment included) and W4c of
#           every READ of the Tcl variable, which catches a value that reaches a
#           formatter through a local instead. W4d is the unit row for both rules,
#           because neither can be fenced by sabotaging the tree.
#           W3 greps src/eval_expr.y, because
#           src/eval_expr.c is GENERATED and gitignored and does not exist in a
#           fresh clone before a build. W5 and W5b fence the two COMMENTS that
#           carry the writer list a reader trusts instead of grepping, over the
#           RAW file, because there the comment IS the artefact.
#   G1-G11  THE PER-SITE CLAMPS, one row per site, by name. G3/G4 also assert the
#           `- 2` that pays for the two literal spaces in " %.*g%c ". G10 is the
#           SECOND defect fixed here: callback.c's y tooltip branch used to test
#           gr->unitx while its body formatted gr->unity.
#   X1-X2   THE SWEEP: in every sprintf statement whose own format LITERAL carries a
#           `%.*`, anywhere in the hand-written sources, the argument in the `%.*`
#           POSITION is a clamp_prec_g() call whose avail NAMES the destination --
#           parsed, not grepped, because a token-presence test passed a clamp
#           discarded through the comma operator and a clamp against the wrong
#           buffer's size (decoys N7, N8). A format held in a `char *` VARIABLE is
#           out of reach and said to be (NAMED LIMIT 2). X1b/X1c fence the two
#           verbatim exemption lists, X1d the two rules, X1e the statement FINDER
#           (which must see `sprintf (` and a `#define SP sprintf` alias -- decoys M2
#           and M7). X2 names the files that must carry one, so X1 cannot be vacuous.
#           The file list is a `glob` over src/*.c *.h *.y *.l minus the four
#           GENERATED files.
#   Z0-Z4   WHAT IS ACTUALLY COMPILED: the tokeniser's own unit rows (Z0, Z0b), the
#           punctuation normaliser's (Z0c -- whitespace around `= ( ) ,` and `->`
#           cannot change a match, decoys M1 and M2), the preprocessor's (Z3), the
#           invariant that the ten function bodies the static rows read carry NO
#           preprocessor line at all (Z1), that every condition in the four that do
#           is one this suite DECIDES (Z2), and that the dead-branch removal is wired
#           into what the rows read (Z4).
#   Y1a-Y1c THE COMPILER'S OWN OPINION: zero -Wformat-overflow/-Wformat-truncation
#           diagnostics, at level 2 for editprop.c (where gcc can see the clamp's
#           range) and at the build's own flags for all four files. gcc found a real
#           defect 51 rows had missed; Y1a is also the ONLY fence here that catches
#           decoy N1, a clamp whose result never reaches the conversion. Y1c is their
#           anti-vacuity row: it proves the compile can still EMIT the diagnostic, so
#           a `-w` in the generated Makefile.conf's CFLAGS cannot make the other two
#           pass on a tree with no clamp. All three skip cleanly with no compiler.
#   B0-B7   BEHAVIOURAL, BOTH ARMS. B0/B0b fence the harness's own exit-status
#           decode, so a reddened row names 134 (the defect's SIGABRT) rather
#           than a collapsed 1. Then the reproducer, the negative case, a
#           precision sweep across the old abort threshold, the token.c door, the
#           save.c nd_view_set door, the graph-marker readout, and the file-borne
#           .sch door.
#   D1-D4   BEHAVIOURAL, DISPLAY ARM. The four draw.c cursor readouts and the
#           callback.c measurement tooltip are only reached by a real draw with
#           a real graph on a real display (headless, `xschem print svg` strips
#           the cursor chrome and never formats them). Spawned through
#           tests/headless/devdisplay.sh exec (:99, GUI_GATE=0) so this stays an
#           `hcases` suite; self-skips with a lowercase `skip:` line when
#           devdisplay.sh status does not report the dev display alive. D3/D4 are
#           the C14 before/after.
#
# ARMED SPELLINGS
#   tests/headless/run_suites.sh --nogui test_ev_precision_bound_1606
#   tests/headless/run_suites.sh         test_ev_precision_bound_1606
# Registered in tests/run_regression.tcl in `hcases` ONLY: nothing here creates a
# widget, and the one display-needing section spawns its own child on :99, so a
# `dcases` entry would cost gate time for zero extra rows.
#
# FLOOR: 63 checks with the dev display up, 58 without it (D1-D4 and D1b skip as
# ONE `skip:` line). Measured 2026-09-25, same count on both arms -- the D rows
# spawn their own :99 child, so `--nogui` does not suppress them. A box with no C
# compiler and no Makefile.conf skips Y1a/Y1b/Y1c as a SECOND `skip:` line and reports
# three fewer (60 with the dev display up, measured). RAISED, NEVER LOWERED.
# (43/38 as first landed; 51/46 after the first
# independent sabotage -- H2b, W4b, W5b, Z0, Z1, Z2, B0, B0b, receipts/C2-repair.md;
# 58/53 after the second -- X1c, X1d, Z0b, Z3, Z4, Y1a, Y1b, receipts/C3-close.md;
# 63/58 after the third -- W4c, W4d, X1e, Z0c, Y1c, receipts/C4-claims.md.)

set fail 0
set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond {detail {}}} {
  global fail npass
  if {$cond} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name $detail : FAIL"; incr fail }
}

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set dir [test_scratch evprec1606]

proc slurp {path} {
  if {![file exists $path]} { return ZZNOFILE }
  set fp [open $path r] ; set t [read $fp] ; close $fp
  return $t
}

# ---------------------------------------------------------------- the stripper ---
## ⚠ ONE C TOKENISER, AND EVERY STATIC ROW READS ITS OUTPUT. `ctok` walks the text
## ONCE, tracking the four states a C character can be in -- code, block comment,
## line comment, and inside a string or char literal -- and returns a PAIR
## {full code}:
##
##   full   comments removed, STRING AND CHAR LITERALS INTACT
##   code   the same text, exactly the same LENGTH, with every literal's interior
##          character replaced by \x01 -- except whitespace, which is left alone so
##          that `collapse` cuts the two halves at identical positions and an index
##          into one stays comparable with an index into the other (K3 compares two)
##
## ⚠ WHY THE SECOND HALF EXISTS: A STRING LITERAL IS THE THIRD DECOY WARDROBE.
## Decoy N3 of receipts/C2v-reprove.md parked K2's asserted statement inside
## `static const char *zz = "precision = clamp_prec_g(precision, sizeof(s));";`,
## deleted the real clamp, and got ALL PASS (51 checks) -- issue 1603's
## comment-decoy defeat wearing quotes. `cfind`/`ccount` below choose the half by
## the NEEDLE, so no row has to remember which to read.
##
## ⚠ AND WHY THE TOKENISER HAD TO BE SHARED RATHER THAN TWO STRIPPERS IN A ROW.
## Before this round the `//` stripper was literal-aware and the BLOCK stripper was
## not, so `dbg(1, "/*\n");` opened a comment that ran to the next real `*/` and
## swallowed live code (decoys N10 and N12), and a `//` appearing on the
## CONTINUATION LINE of a multi-line string literal did the same (N9).
## ⚠ THAT IS A DEFEAT, NOT A HARMLESS OVER-STRIP. `W4`, `X1` and `X2` are NEGATIVE
## rows -- they hunt for something bad and pass when they find nothing -- so hiding
## text from them is precisely how you pass them with a live unclamped site in the
## tree. An earlier revision of this file reassured the reader that over-stripping
## "can only make the stripper drop MORE text" and was therefore harmless. It is
## not, it was measured not to be (N9/N10/N12 all reached ALL PASS), and that
## sentence is gone.
##
## ⚠ AND THE REASON THE LITERAL AWARENESS IS NOT THEORETICAL, re-counted 2026-09-25
## over the 43 hand-written sources this suite scans: **54** lines contain a `//`,
## and every one of them is inside a block comment or inside a string literal --
## there is NO `//` line comment in code anywhere in this tree. `"http://"` and
## `"https://"` (save.c), `"file://%s%s"` (scheduler.c), `"// sch_path: %s\n"` in
## TWO netlisters (spectre_netlist.c and verilog_netlist.c -- spice, tedax and vhdl
## write `**`, `##` and `--`), `"//// begin user architecture code\n"`
## (spectre_netlist.c), and a `'/'` char literal in ELEVEN files. A naive `//` strip
## truncates those lines and starts hiding sprintf statements from X1. (An earlier
## revision of this comment said 59 lines -- that figure counts the four GENERATED
## files the same sentence excludes -- and said "four netlisters".)
##
## NOT MODELLED, and none of it is in this tree: trigraphs (`??/` for `\`; the
## build passes no -trigraphs, so a trigraph-split needle does not even compile),
## digraphs, and `\` line-continuation INSIDE a token. A literal that is continued
## across a newline with a trailing `\` IS modelled -- that is N9.
proc blank_lit {s} { return [regsub -all {[^ \t\r]} $s "\x01"] }
proc ctok {t} {
  set of {} ; set oc {} ; set incom 0 ; set lit {}
  foreach l [split $t "\n"] {
    set n [string length $l] ; set i 0 ; set lf {} ; set lc {}
    while {$i < $n} {
      if {$incom} {
        set e [string first "*/" $l $i]
        if {$e < 0} { break }
        set incom 0 ; set i [expr {$e + 2}]
        append lf { } ; append lc { }
        continue
      }
      if {$lit ne {}} {
        ## the closing delimiter, skipping an ESCAPED one: a delimiter preceded by
        ## an odd number of backslashes is escaped, by an even number is real.
        set j $i ; set closed 0
        while {1} {
          set j [string first $lit $l $j]
          if {$j < 0} break
          set k $j
          while {$k > $i && [string index $l [expr {$k - 1}]] eq "\\"} { incr k -1 }
          if {(($j - $k) % 2) == 0} { set closed 1 ; break }
          incr j
        }
        if {$closed} {
          append lf [string range $l $i $j]
          append lc [blank_lit [string range $l $i [expr {$j - 1}]]] $lit
          set lit {} ; set i [expr {$j + 1}]
        } else {
          append lf [string range $l $i end]
          append lc [blank_lit [string range $l $i end]]
          set i $n
        }
        continue
      }
      ## code: jump to whichever of `"` `'` `/*` `//` comes first
      set best -1 ; set kind {}
      foreach {k pat} [list str "\"" chr "'" blk "/*" lin "//"] {
        set p [string first $pat $l $i]
        if {$p >= 0 && ($best < 0 || $p < $best)} { set best $p ; set kind $k }
      }
      if {$best < 0} {
        append lf [string range $l $i end] ; append lc [string range $l $i end]
        break
      }
      append lf [string range $l $i [expr {$best - 1}]]
      append lc [string range $l $i [expr {$best - 1}]]
      switch -- $kind {
        lin { break }
        blk { set incom 1 ; set i [expr {$best + 2}] ; append lf { } ; append lc { } }
        str { set lit "\"" ; append lf "\"" ; append lc "\"" ; set i [expr {$best + 1}] }
        chr { set lit "'"  ; append lf "'"  ; append lc "'"  ; set i [expr {$best + 1}] }
      }
    }
    append of $lf "\n" ; append oc $lc "\n"
    ## a literal survives the newline ONLY through a trailing `\` (N9's shape);
    ## anything else would not compile, so do not carry a runaway quote onward.
    if {$lit ne {} && ![string match "*\\\\" $l]} { set lit {} }
  }
  return [list $of $oc]
}

## ------------------------------------------- the preprocessor, three-valued ---
## ⚠ THIS REPLACES BOTH THE OLD `#if 0`-ONLY STRIPPER AND THE OLD Z2 ALLOWLIST,
## AND THE ALLOWLIST WAS THE DESIGN FLAW. Z2 used to ask "is this condition one of
## the seven spellings the tree uses?" instead of "is the region it opens LIVE on
## this build?" -- so `#ifndef __unix__`, `#if HAS_CAIRO!=1` and
## `#if !defined(__unix__) && HAS_CAIRO==1`, all DEAD here, were on the allowlist,
## and decoys N4 (G5, on show_node_measures, whose ONLY fence G5 is), N5 and N6
## (G9) satisfied their rows from inside a region the compiler throws away.
## `#if 1` was allowed while Z2 never looked at its `#else` (N6).
##
## So: the macro table is MEASURED (pp_table), every condition is EVALUATED, dead
## branches are dropped, `#else`/`#elif` chains are walked, and a condition this
## suite cannot decide leaves EVERY branch in place and is REPORTED by Z2 rather
## than guessed at. Only the CONDITIONAL directives are dropped; `#define`,
## `#include`, `#pragma` and `#undef` survive, because H5 reads a `#define`.
proc pp_table {repo} {
  set m [dict create] ; set d {}
  foreach l [split [slurp [file join $repo config.h]] "\n"] {
    if {[regexp {^[ \t]*#[ \t]*define[ \t]+([A-Za-z_][A-Za-z0-9_]*)[ \t]+(-?[0-9]+)[ \t]*$} \
         $l . nm v]} { dict set m $nm $v ; lappend d $nm } \
    elseif {[regexp {^[ \t]*#[ \t]*define[ \t]+([A-Za-z_][A-Za-z0-9_]*)([ \t]|$)} $l . nm]} {
      lappend d $nm
    }
  }
  ## gcc defines __unix__ on every unix target; `gcc -dM` was checked by hand and
  ## agrees. Taken from the interpreter's own platform rather than assumed.
  if {$::tcl_platform(platform) eq {unix}} { dict set m __unix__ 1 ; lappend d __unix__ }
  return [list $m [lsort -unique $d]]
}
## 1, 0, or U ("this suite cannot decide"). `defined(X)` for an X that is not in
## the measured table is U and NOT 0: this suite does not know the whole macro
## universe and must not pretend it does. Anything left with a letter in it after
## substitution is U, which is also what makes the final `expr` safe -- the string
## is checked against a digits-and-operators charset first, so it can hold neither
## a command substitution nor a variable reference.
proc pp_eval {cond} {
  set c $cond
  regsub -all {defined[ \t]*\([ \t]*([A-Za-z_][A-Za-z0-9_]*)[ \t]*\)} $c {defined \1} c
  while {[regexp -indices {defined[ \t]+([A-Za-z_][A-Za-z0-9_]*)} $c sp np]} {
    set nm [string range $c [lindex $np 0] [lindex $np 1]]
    if {[lsearch -exact $::PPDEF $nm] < 0} { return U }
    set c [string replace $c [lindex $sp 0] [lindex $sp 1] 1]
  }
  while {[regexp -indices {0[xX][0-9a-fA-F]+} $c sp]} {
    set h [string range $c [lindex $sp 0] [lindex $sp 1]]
    set c [string replace $c [lindex $sp 0] [lindex $sp 1] [expr {$h + 0}]]
  }
  regsub -all {([0-9])[uUlL]+} $c {\1} c
  while {[regexp -indices {(^|[^A-Za-z0-9_])([A-Za-z_][A-Za-z0-9_]*)} $c . . np]} {
    set nm [string range $c [lindex $np 0] [lindex $np 1]]
    if {![dict exists $::PPMAC $nm]} { return U }
    set c [string replace $c [lindex $np 0] [lindex $np 1] [dict get $::PPMAC $nm]]
  }
  if {![regexp {^[0-9 \t()!&|<>=+*/%~^-]+$} $c]} { return U }
  if {[catch {expr $c} v]} { return U }
  return [expr {$v ? 1 : 0}]
}
proc pp_cond {line kw} {
  set rest {}
  regexp "^\[ \t\]*#\[ \t\]*${kw}(.*)\$" $line . rest
  set rest [string trim $rest]
  switch -- $kw {
    ifdef  { return "defined($rest)" }
    ifndef { return "!defined($rest)" }
  }
  return $rest
}
proc cs_pp {cs} {
  lassign $cs full code
  set of {} ; set oc {} ; set st {}
  foreach f [split $full "\n"] c [split $code "\n"] {
    set emit 1
    foreach lev $st { if {[dict get $lev state] eq {dead}} { set emit 0 ; break } }
    if {[regexp {^[ \t]*#[ \t]*(ifdef|ifndef|if|elif|else|endif)([ \t]|$)} $c . kw]} {
      switch -- $kw {
        if - ifdef - ifndef {
          if {!$emit} {
            lappend st [dict create state dead taken 1 unknown 0]
          } else {
            set v [pp_eval [pp_cond $f $kw]]
            if {$v eq {U}} { lappend st [dict create state undecided taken 0 unknown 1] } \
            elseif {$v} { lappend st [dict create state live taken 1 unknown 0] } \
            else { lappend st [dict create state dead taken 0 unknown 0] }
          }
        }
        elif - else {
          if {[llength $st]} {
            set top [lindex $st end]
            if {[dict get $top unknown]} { dict set top state undecided } \
            elseif {[dict get $top taken]} { dict set top state dead } \
            else {
              set v [expr {$kw eq {else} ? 1 : 0}]
              if {$kw eq {elif}} { set v [pp_eval [pp_cond $f $kw]] }
              if {$v eq {U}} { dict set top state undecided ; dict set top unknown 1 } \
              elseif {$v} { dict set top state live ; dict set top taken 1 } \
              else { dict set top state dead }
            }
            lset st end $top
          }
        }
        endif { if {[llength $st]} { set st [lrange $st 0 end-1] } }
      }
      lappend of {} ; lappend oc {} ; continue
    }
    if {$emit} { lappend of $f ; lappend oc $c } else { lappend of {} ; lappend oc {} }
  }
  return [list [join $of "\n"] [join $oc "\n"]]
}
## What every row reads: comments out, literals marked, dead branches dropped.
proc cstrip {t} { return [cs_pp [ctok $t]] }
## What section Z reads: comments out, literals marked, every `#` line KEPT,
## because Z's whole job is to see the directives cstrip resolves away.
proc ccstrip {t} { return [ctok $t] }

## ------------------------------------------------------ matching, and ONLY here ---
## Whitespace collapsed to one space: at least one shipped clamp spans two physical
## lines, so a row matching a single-line spelling would redden on a correct tree.
## The two halves collapse in lockstep because their whitespace sits at identical
## positions (blank_lit leaves whitespace alone), so they stay the same length.
proc collapse {t} { return [string trim [regsub -all {[ \t\n\r]+} $t { }]] }
## Whitespace only, in lockstep. Z0 compares this against an expected STRING, so it
## must not also normalise punctuation; every matching row uses `cs_collapse` below.
proc cs_ws {cs} {
  return [list [collapse [lindex $cs 0]] [collapse [lindex $cs 1]]]
}
## ⚠ AND THEN PUNCTUATION NORMALISATION, BECAUSE COLLAPSING RUNS ALONE MATCHES A
## SPELLING AND NOT A SHAPE -- MEASURED, THREE TIMES, ON THIS TREE.
## `collapse` folds RUNS of whitespace but never INSERTS any, so a needle written
## `xctx->ev_precision = tclgetintvar(` simply is not the string
## `xctx->ev_precision=tclgetintvar(`, and `sprintf(` is not `sprintf (`. The fourth
## round of independent sabotage (receipts/C3v-final.md §2.2) planted exactly those
## two legal C spellings -- a FIFTH UNCLAMPED WRITER with no spaces around the `=`
## (M1) and a NEW UNCLAMPED indirect-precision site with one space before the paren
## (M2) -- and the whole suite stayed at `RESULT: ALL PASS (58 checks)`. Neither was
## a new CLASS: both are inside what their rows' own names claimed in general, which
## is the defect. So the repair is at the class level and not another spelling:
## whitespace ADJACENT TO `= ( ) ,` OR TO `->` IS REMOVED, from the haystack and
## from the needle, by the same proc, so those spellings become one canonical form.
##
## ⚠ AND IT IS DRIVEN OFF THE BLANKED HALF, WHICH IS THE WHOLE REASON IT IS SAFE.
## The two halves differ only at literal-interior positions (there the code half
## holds \x01, and whitespace is left alone by `blank_lit`), so a `,` or a `(` INSIDE
## a format string is invisible here: `"%s, %s"` keeps its space, because the space's
## neighbours in the blanked half are \x01 and not a comma. Deciding on one half and
## cutting BOTH at the same indices is what keeps them the same length and keeps an
## index into one comparable with an index into the other (K3 compares two).
## One pass suffices and is idempotent: `cs_ws` has already folded every run, so no
## two spaces are adjacent and no deletion can create a new candidate.
## ⚠ WHAT IT COSTS, STATED RATHER THAN DISCOVERED LATER: normalising away the space
## in `#define X (1)` erases the OBJECT-LIKE / FUNCTION-LIKE macro distinction, and
## `a == b` becomes `a==b`. Erasing whitespace can never join two identifiers (an
## identifier is never adjacent to one of these five punctuators in a way that would
## paste), so any text that matches a normalised needle is a genuine token-for-token
## equivalent of it -- but two DIFFERENT texts that differ only in such a space are
## now the same string here. No row in this file matches a parenthesised macro
## definition; H5's needle and Z3's `#define KEPT_DEFINE 1` carry no punctuation at
## all. Row Z0c is this proc's unit fence.
set ::CSNORM {((?:[=(),]|->)) +| +(?=[=(),]|->)}
proc cs_norm {cs} {
  lassign $cs full code
  set hits [regexp -all -inline -indices -- $::CSNORM $code]
  if {![llength $hits]} { return $cs }
  set of {} ; set oc {} ; set pos 0
  foreach {m g} $hits {
    set a [lindex $m 0] ; set b [lindex $m 1]
    ## case A matched the punctuator too (capture group participated); only the
    ## spaces after it go. Case B is the space run alone, in front of a punctuator.
    if {[lindex $g 0] >= 0} { set a [expr {[lindex $g 1] + 1}] }
    append of [string range $full $pos [expr {$a - 1}]]
    append oc [string range $code $pos [expr {$a - 1}]]
    set pos [expr {$b + 1}]
  }
  append of [string range $full $pos end]
  append oc [string range $code $pos end]
  return [list $of $oc]
}
proc cs_collapse {cs} { return [cs_norm [cs_ws $cs]] }
## A NEEDLE, THROUGH EXACTLY THE SAME MILL AS THE HAYSTACK -- `ctok` first, so a
## needle that carries a string literal has that literal's interior excluded from the
## normalisation just as the file's is.
proc nrm {t} { return [cs_text [cs_collapse [ctok $t]]] }
proc cs_text {cs} { return [lindex $cs 0] }
proc scount {hay needle} {
  if {$needle eq {}} { return 0 }
  set n 0 ; set i 0
  while {[set i [string first $needle $hay $i]] >= 0} { incr n ; incr i }
  return $n
}
## ⚠ THE ONE MATCHER, and it picks the half by the NEEDLE so no row has to.
## A needle with no `"` and no `'` in it cannot legitimately be part of a string or
## char literal, so it is matched against the literal-BLANKED half: a decoy parked
## in a literal (N3) is simply not there. A needle that DOES carry a literal is
## matched against the intact half -- and cannot be hidden inside an OUTER literal
## either, because the inner quotes would have to be escaped (`\"`) and then the
## needle no longer matches. A needle with no quote in it can also never straddle a
## literal boundary, because crossing one would require a `"` the needle does not
## contain; so "the match starts at a code character" and "the whole match is code"
## are the same statement here.
proc cs_half {cs needle} {
  if {[string first "\"" $needle] >= 0 || [string first "'" $needle] >= 0} {
    return [lindex $cs 0]
  }
  return [lindex $cs 1]
}
## ⚠ ARGUMENT ORDER: `cfind` takes (needle, cs) like `string first`, and `ccount`
## takes (cs, needle) like `scount`. Each keeps the order of the proc it replaces,
## so a reader checking a row against the shape they already know is not the person
## who introduces a silent swap. Neither may be handed a RAW file: W5, W5b and
## doc_comment_before read the raw text on purpose, because there the comment IS
## the artefact, and they keep using `string first`/`scount`.
## ⚠ BOTH NORMALISE THE NEEDLE (`nrm`), so every row in this file is written in
## ordinary C spelling and matches the shape rather than the spelling. The haystack
## is normalised by `cs_collapse`, which every producer of a haystack here ends with.
proc cfind {needle cs} {
  set n [nrm $needle]
  return [string first $n [cs_half $cs $n]]
}
proc ccount {cs needle} {
  set n [nrm $needle]
  return [scount [cs_half $cs $n] $n]
}
## $word as a whole identifier inside $hay.
proc word_in {hay word} {
  if {$word eq {}} { return 0 }
  set i 0 ; set wl [string length $word]
  while {[set p [string first $word $hay $i]] >= 0} {
    set b {} ; if {$p > 0} { set b [string index $hay [expr {$p - 1}]] }
    set a [string index $hay [expr {$p + $wl}]]
    if {![regexp {[A-Za-z0-9_]} $b] && ![regexp {[A-Za-z0-9_]} $a]} { return 1 }
    set i [expr {$p + 1}]
  }
  return 0
}
## The body of a C function DEFINITION named $name: from its column-0 definition
## line to the first column-0 `}`. Declarations (the line ends in `;`) are
## skipped, so a prototype cannot be mistaken for the body. {ZZNOFUNC ZZNOFUNC}
## when the function is not there at all, so no row can pass by finding nothing.
## cfunc_raw KEEPS THE NEWLINES -- section Z needs them, because a
## conditional-compilation directive is defined by being at the start of a line.
proc cfunc_raw {cs name} {
  lassign $cs full code
  set on 0 ; set of {} ; set oc {}
  foreach f [split $full "\n"] c [split $code "\n"] {
    if {$on} {
      lappend of $f ; lappend oc $c
      if {[regexp {^\}} $c]} { return [list [join $of "\n"] [join $oc "\n"]] }
      continue
    }
    if {[regexp "^\[A-Za-z_\].*\[^A-Za-z0-9_\]$name\[ \t\]*\\(" $c] \
        && ![regexp {;[ \t]*$} $c]} { set on 1 ; lappend of $f ; lappend oc $c }
  }
  if {$on} { return [list [join $of "\n"] [join $oc "\n"]] }
  return [list ZZNOFUNC ZZNOFUNC]
}
proc cfunc {cs name} {
  set b [cfunc_raw $cs $name]
  if {[cs_text $b] eq {ZZNOFUNC}} { return $b }
  return [cs_collapse $b]
}
## ⚠ AN OBJECT-LIKE ALIAS FOR sprintf, WHICH IS THE OTHER HALF OF M2's MECHANISM.
## `#define SP sprintf` then `SP(zb, "%.*g", xctx->ev_precision, zv);` is a sprintf
## statement that the literal needle `sprintf(` never sees. The fourth adversary
## named this shape and did not drive it (receipts/C3v-final.md §7); it is closed
## here rather than left as a note. Read off the BLANKED half so a `#define`-looking
## line inside a string literal is not one, and line-anchored, so this must be handed
## the text BEFORE it is collapsed. Only the whole-replacement-list form counts: a
## macro whose body merely CONTAINS sprintf carries its own `sprintf(` and is found
## as a statement anyway.
proc sprintf_aliases {cs} {
  set out {}
  foreach c [split [lindex $cs 1] "\n"] {
    if {[regexp {^[ \t]*#[ \t]*define[ \t]+([A-Za-z_][A-Za-z0-9_]*)[ \t]+sprintf[ \t]*$} \
         $c . nm]} { lappend out $nm }
  }
  return [lsort -unique $out]
}
## Every `sprintf(...)` STATEMENT in $ncs -- which must ALREADY be collapsed and
## normalised (`cs_collapse`), so `sprintf (zb, ...)` with a space before the paren is
## the same statement as `sprintf(zb, ...)`. That spelling was decoy M2 and it left
## the whole suite green. `$aliases` comes from `sprintf_aliases` on the UNcollapsed
## text. An identifier-prefixed name (`my_sprintf(`; `my_snprintf` does not contain
## the needle at all) is excluded by requiring a non-identifier character before the
## name. ⚠ BOTH THE `sprintf(` AND THE TERMINATING `;` ARE FOUND IN THE BLANKED
## HALF, so a `sprintf(` inside a format string is not a statement and a `;`
## inside one does not end a statement -- the old version relied on "no format
## string in this tree contains a `;`", which was true and was not a reason.
## Statements are returned in source order for every name, which is all any caller
## needs (they iterate, none indexes).
proc sprintf_stmts {ncs {aliases {}}} {
  lassign $ncs full code
  set out {}
  foreach nm [concat [list sprintf] $aliases] {
    set tgt "${nm}("   ;# the braces are required: `$nm(` parses as an array element
    set tl [string length $tgt]
    set i 0
    while {[set s [string first $tgt $code $i]] >= 0} {
      set i [expr {$s + $tl}]
      if {$s > 0 && [regexp {[A-Za-z0-9_]} [string index $code [expr {$s - 1}]]]} { continue }
      set e [string first ";" $code $s]
      if {$e < 0} { set e [string length $code] }
      lappend out [cs_collapse [list [string range $full $s $e] [string range $code $s $e]]]
    }
  }
  return $out
}
## The ARGUMENT LIST of a `f(...)` call, as a list of collapsed PAIRS, split at
## TOP-LEVEL commas only. The structure (parens, brackets, commas) is read off the
## BLANKED half, so a comma or a paren inside a string literal cannot change the
## split; the pieces are cut out of both halves at the same indices. Empty list if
## the parentheses do not balance, which a row must treat as a failure and not as
## "no arguments".
proc call_args {cs} {
  lassign $cs full code
  set o [string first "(" $code]
  if {$o < 0} { return {} }
  set n [string length $code] ; set depth 0 ; set args {} ; set start [expr {$o + 1}]
  for {set i $o} {$i < $n} {incr i} {
    set c [string index $code $i]
    if {$c eq "(" || $c eq "\["} { incr depth ; continue }
    if {$c eq ")" || $c eq "\]"} {
      incr depth -1
      if {$depth == 0} {
        lappend args [cs_collapse [list [string range $full $start [expr {$i - 1}]] \
                                        [string range $code $start [expr {$i - 1}]]]]
        return $args
      }
      continue
    }
    if {$c eq "," && $depth == 1} {
      lappend args [cs_collapse [list [string range $full $start [expr {$i - 1}]] \
                                      [string range $code $start [expr {$i - 1}]]]]
      set start [expr {$i + 1}]
    }
  }
  return {}
}
## The 0-based VARARGS index of the argument that supplies the first `.*`
## precision in a printf format literal, or -1. Every conversion before it
## consumes one argument, and a `*` WIDTH consumes one of its own.
proc star_arg_index {fmt} {
  set n [string length $fmt] ; set i 0 ; set k 0
  while {$i < $n} {
    if {[string index $fmt $i] ne "%"} { incr i ; continue }
    incr i
    if {[string index $fmt $i] eq "%"} { incr i ; continue }
    while {$i < $n && [string first [string index $fmt $i] {-+ #0123456789.*hlLqjzt}] >= 0} {
      if {[string index $fmt $i] eq "*"} {
        if {[string index $fmt [expr {$i - 1}]] eq "."} { return $k }
        incr k
      }
      incr i
    }
    incr i ; incr k
  }
  return -1
}
## Is this argument text a clamp_prec_g() call AND NOTHING ELSE? `(clamp_prec_g(
## ...), xctx->ev_precision)` -- decoy N7, the comma operator, which computes the
## clamp and throws it away -- is not, and neither is a clamp buried in a larger
## expression.
proc is_clamp_call {a} {
  if {![string match {clamp_prec_g(*)} $a]} { return 0 }
  set n [string length $a] ; set d 0
  for {set i 12} {$i < $n} {incr i} {
    set c [string index $a $i]
    if {$c eq "("} { incr d } elseif {$c eq ")"} {
      incr d -1
      if {$d == 0} { return [expr {$i == $n - 1}] }
    }
  }
  return 0
}

# ------------------------------------------------- every hand-written source ---
## ⚠ BY GLOB, NOT BY A HAND-KEPT LIST. W4, X1 and X2 used to iterate seven named
## files while their own row names said "hand-written source(s)"; the independent
## sabotage planted a FIFTH unclamped `xctx->ev_precision = tclgetintvar(...)` and
## a NEW unclamped `sprintf(b, "%.*g%c", p, v, 84);` in src/actions.c and all
## three rows stayed GREEN (probes C1 and C2 of receipts/Cv-sabotage.md). No live
## site was missed -- the over-claim was in the names, not in the answer -- but the
## honest fix is to scan everything rather than narrow the names. Measured cost:
## 130 ms for all 43 files, the whole of it in cstrip.
##
## THE FOUR GENERATED FILES ARE EXCLUDED BY NAME, and each for a stated reason:
## eval_expr.c (bison, from eval_expr.y), expandlabel.c and expandlabel.h (bison,
## from expandlabel.y) and parselabel.c (flex, from parselabel.l). All four are
## gitignored, absent from a fresh clone before a build, and not editable by hand
## -- the CLAUDE.md rule is "do not hand-edit the .c". Their inputs (.y/.l) ARE
## scanned. W6 separately asserts that a generated eval_expr.c, if a build has
## produced one, carries kklex()'s clamp, so excluding it here hides nothing.
## ⚠ .y AND .l ARE NOT C, so the tokeniser is approximate on them: parselabel.l's
## flex character classes contain stray `"` and `/*`, and a stray quote puts the
## tokeniser into a literal it then carries to the end of the line. That DROPS
## TEXT, AND DROPPING TEXT IS NOT HARMLESS -- W4, X1 and X2 pass when they find
## nothing, so text they cannot see is text they cannot object to. It is named here
## as a residual blind spot, in the same paragraph as the others (see the NAMED
## LIMITS block at the top of this file), and not papered over. Today the only
## `.y`/`.l` row is W3, a POSITIVE row on eval_expr.y's kklex(), where dropping
## text can only cause a false FAIL.
set PPT [pp_table $repo]
set ::PPMAC [lindex $PPT 0]
set ::PPDEF [lindex $PPT 1]
set GENERATED [list eval_expr.c expandlabel.c expandlabel.h parselabel.c]
## $SRC keeps its NEWLINES (cfunc_raw, Z1, Z2 and sprintf_aliases are line-oriented);
## $SRCN is the same text collapsed and punctuation-normalised ONCE per file, which is
## what W4, W4c, X1 and X2 match against. Computed once because `cs_norm` walks the
## whole tree and there is no reason to walk it four times.
set SRC [dict create]
set SRCN [dict create]
foreach pat {*.c *.h *.y *.l} {
  foreach p [lsort [glob -nocomplain -directory [file join $repo src] $pat]] {
    if {[lsearch -exact $GENERATED [file tail $p]] >= 0} { continue }
    set _cs [cstrip [slurp $p]]
    dict set SRC [file tail $p] $_cs
    dict set SRCN [file tail $p] [cs_collapse $_cs]
  }
}
set C_CALLBACK [dict get $SRC callback.c]
set C_DRAW     [dict get $SRC draw.c]
set C_EDITPROP [dict get $SRC editprop.c]
set C_SAVE     [dict get $SRC save.c]
set H_XSCHEM   [dict get $SRC xschem.h]
set Y_EVAL     [dict get $SRC eval_expr.y]

# ===========================================================================
# SECTION H -- THE HELPER, AND THE ONE SOURCE OF THE NUMBER 71
# ===========================================================================
set F_CLAMP [cfunc $C_EDITPROP clamp_prec_g]

check_true {H1 int clamp_prec_g(int prec, size_t avail) is DEFINED in src/editprop.c\
 (comments, literals and every branch dead on this build stripped first, so its own\
 doc comment does not count)} \
  [expr {[cs_text $F_CLAMP] ne {ZZNOFUNC} && [cs_text $F_CLAMP] ne {}}] \
  "(body={[cs_text $F_CLAMP]})"

## prec <= 0 MUST pass through. 0 is eval_expr's own "engineering off" flag
## (kklex sets `engineering = xctx->ev_precision`), and a negative asks printf for
## its default. Raising either would change behaviour rather than bound it, and
## issue 1602's dialog already refuses 0 on the Tcl side for the same reason.
check {H2 clamp_prec_g returns a prec <= 0 UNCHANGED} \
  [expr {[cfind {if(prec <= 0) return prec;} $F_CLAMP] >= 0 ? 1 : 0}] 1

## ⚠ H2b FENCES AN UNDERFLOW GUARD, AND IT IS NOT A SAFETY FLOOR -- read the
## comment on the line itself in src/editprop.c. `cap = avail - 9` is size_t
## arithmetic: with avail < 9 it wraps to a huge cap and H4's clamp below becomes
## a NO-OP, i.e. deleting this line silently disables the whole helper for a small
## buffer. That is all it buys. The returned 1 is NOT itself safe --
## clamp_prec_g(200, 8) gives 1, and "%.*g%c" at precision 1 on a
## three-digit-exponent value is "1e+287T", 7 chars + NUL = 8 bytes and 9 with a
## sign -- so for avail in 2..9 an overflow is still possible.
## UNREACHABLE TODAY, and here are ALL FOURTEEN call sites rather than a claim about
## "every other caller" (the previous revision of this comment said eleven, and
## omitted graph_marker_fmt's 80 while claiming to cover every other one):
##    78  editprop.c dtoa_eng, the "%.*gMEG" arm's own clamp, `sizeof(s) - 2`
##        <- THE SMALLEST IN THE TREE, and it is new: it was 80 before gcc showed
##           the MEG arm's static bound was violated (see K3 and section Y)
##    80  editprop.c dtoa_eng, the clamp above the branch, `sizeof(s)`
##    80  draw.c draw_graph, draw.c draw, eval_expr.y kklex -- the three writers,
##        `DTOA_ENG_BUFSIZE`
##    80  draw.c graph_marker_fmt, `(size_t)destsize`; all four of its callers pass
##        S(sx)/S(sy)/S(sdx)/S(sdy) from `char sx[80], sy[80], sdx[80], sdy[80]`
##    98  draw.c draw_hcursor, draw_hcursor_difference -- `S(tmpstr) - 2`, tmpstr[100]
##   100  draw.c draw_cursor, draw_cursor_difference -- `S(tmpstr)`, tmpstr[100]
##   100  callback.c waves_callback x2 -- `S(sx)`, `S(sy)`, `char sx[100], sy[100]`
##   100  save.c nd_view_set -- `S(s)`, `char s[100]`
##  1024  draw.c show_node_measures -- `S(tmpstr)`, tmpstr[1024]
## A future caller with a smaller buffer needs more than this line.
## The independent sabotage deleted this line and the suite stayed ALL PASS
## (cycle S04 of receipts/Cv-sabotage.md): this row is that hole closed.
check {H2b clamp_prec_g refuses an avail too small to hold any conversion, so\
 `cap = avail - 9` can never underflow size_t and silently disable the clamp} \
  [expr {[cfind {if(avail <= 9) return 1;} $F_CLAMP] >= 0 ? 1 : 0}] 1

## The arithmetic, not a literal: worst case for "%.*g%c" is prec+8 characters
## (sign, leading digit, point, prec-1 fraction digits, 'e', exponent sign, three
## exponent digits, suffix) and prec+9 bytes with the NUL.
check {H3 clamp_prec_g's cap is DERIVED as avail - 9, not written as a number} \
  [expr {[cfind {cap = avail - 9;} $F_CLAMP] >= 0 ? 1 : 0}] 1

check {H4 clamp_prec_g actually applies the cap} \
  [expr {[cfind {if((size_t)prec > cap) return (int)cap;} $F_CLAMP] >= 0 ? 1 : 0}] 1

check {H5 src/xschem.h defines DTOA_ENG_BUFSIZE as 80} \
  [expr {[cfind {#define DTOA_ENG_BUFSIZE 80} $H_XSCHEM] >= 0 ? 1 : 0}] 1

## THE POINT OF H6: the ceiling 71 is DTOA_ENG_BUFSIZE - 9 and exists nowhere as a
## literal in C. If someone grows dtoa_eng's buffer, every clamp moves with it.
check {H6 dtoa_eng's static buffer is sized by the macro, not by a literal 80} \
  [expr {[cfind {static char s[DTOA_ENG_BUFSIZE];} \
           [cfunc $C_EDITPROP dtoa_eng]] >= 0 ? 1 : 0}] 1

# ===========================================================================
# SECTION K -- dtoa_eng CLAMPS ITS OWN PARAMETER (adjudication C4)
# ===========================================================================
set F_DTOA [cfunc $C_EDITPROP dtoa_eng]

check_true {K1 char *dtoa_eng(double, int) is still in src/editprop.c} \
  [expr {[cs_text $F_DTOA] ne {ZZNOFUNC} && [cs_text $F_DTOA] ne {}}]

## THE LOAD-BEARING EDIT. dtoa_eng has 24 call sites; 13 hand it
## xctx->ev_precision, 1 hands it eval_expr's `engineering`, 8 hand it a hardcoded
## 5 and 2 hand it graph_marker_text_rec's own `prec`. That last one is reached by
## NO writer clamp, so only a clamp inside the function itself makes it correct by
## construction for every caller.
check {K2 dtoa_eng clamps its own `precision` parameter against its own buffer} \
  [expr {[cfind {precision = clamp_prec_g(precision, sizeof(s));} $F_DTOA] >= 0 ? 1 : 0}] 1

## K2 would pass on a gutted function, so pin the three conversions it protects.
## ⚠ THE ONE CLAMP SITS ABOVE THE SUFFIX BRANCH AND IS SIZED FOR "%.*g%c", AND THE
## "%.*gMEG" ARM TAKES A SECOND, TIGHTER ONE OF ITS OWN. That is a change from the
## first landing of this fix, and GCC IS WHO FOUND IT: "MEG" is three format bytes
## where "%c" is one, so that arm's static worst case is prec+11 bytes with the NUL
## and 71+11 == 82 > 80 -- the bound really was violated. `editprop.c:231:11:
## warning: '__builtin___sprintf_chk' may write a terminating nul past the end of
## the destination [-Wformat-overflow=]`, with the note "output between 5 and 82
## bytes into a destination of size 80". No sweep found it because that arm has
## already divided by 1e6, so |i| lands in (0.999999, 999.999], a double there has
## at most ~55 exact significant digits, and %g strips the rest: cap 71 and cap 69
## print byte-identical strings (measured, driven to precision 4000 at both signs).
## So the second clamp is arithmetic, not behaviour, and `sizeof(s) - 2` is the same
## accounting as draw_hcursor's `S(tmpstr) - 2` for its two literal spaces. Row Y1a
## is the fence that will not let the arithmetic rot again -- it asks the compiler.
##
## ⚠ AND THE `>= 0` ON THE FIRST INDEX IS THE WHOLE POINT OF THE POSITION CLAUSE.
## `cfind`, like `string first`, returns -1 when the needle is MISSING, and -1 < N
## is true, so without it the clause said "the clamp precedes the branch" on a tree
## with no clamp at all. Measured: under a sabotage that deleted the clamp outright,
## K3 PASSED and only K2 reddened (cycle S07 of receipts/Cv-sabotage.md). Chained
## with a decoy comment that satisfies K2, K3 then asserted nothing whatsoever. It
## is the only two-index comparison in this file; every other row tests one index
## against `>= 0` already. Both indices here come from quote-free needles, so both
## are indices into the same (blanked) half -- if either needle ever grows a `"`,
## `cs_half` would hand it the other half and the comparison would be meaningless.
check {K3 the three conversions the clamp protects are all still there, the clamp\
 is PRESENT and precedes the suffix branch, and the MEG arm carries its own\
 tighter clamp} \
  [expr {[ccount $F_DTOA {sprintf(s, "%.*gMEG", clamp_prec_g(precision, sizeof(s) - 2), i)}] == 1
         && [ccount $F_DTOA {sprintf(s, "%.*g%c", precision, i, suffix)}] == 1
         && [ccount $F_DTOA {sprintf(s, "%.*g", precision, i)}] == 1
         && [cfind {clamp_prec_g(precision, sizeof(s));} $F_DTOA] >= 0
         && [cfind {if (absi == 0.0)} $F_DTOA] >= 0
         && [cfind {clamp_prec_g(precision, sizeof(s));} $F_DTOA]
            < [cfind {if (absi == 0.0)} $F_DTOA] ? 1 : 0}] 1

# ===========================================================================
# SECTION W -- THE WRITERS OF xctx->ev_precision
# ===========================================================================
set CLAMPED_WRITE {xctx->ev_precision = clamp_prec_g(tclgetintvar("ev_precision"), DTOA_ENG_BUFSIZE);}

check {W1 draw_graph() clamps the ev_precision it copies out of Tcl} \
  [expr {[cfind $CLAMPED_WRITE [cfunc $C_DRAW draw_graph]] >= 0 ? 1 : 0}] 1

check {W2 draw() clamps the ev_precision it copies out of Tcl} \
  [expr {[cfind $CLAMPED_WRITE [cfunc $C_DRAW draw]] >= 0 ? 1 : 0}] 1

## ⚠ THE FOURTH WRITER, AND THE ONE THE ISSUE'S OWN REPRODUCER GOES THROUGH.
## kklex() writes ev_precision UNCONDITIONALLY, once per lexer token, and then
## `engineering = xctx->ev_precision` hands it straight to dtoa_eng. It is in
## src/eval_expr.y: src/eval_expr.c is GENERATED by bison and GITIGNORED, so it
## does not exist in a fresh clone before a build and a row grepping it would read
## "clean" for the wrong reason.
check {W3 kklex() in src/eval_expr.y clamps the ev_precision it copies out of Tcl} \
  [expr {[cfind $CLAMPED_WRITE [cfunc $Y_EVAL kklex]] >= 0 ? 1 : 0}] 1

## THE ROW THAT CATCHES A FIFTH WRITER. Every WRITE to xctx->ev_precision anywhere in
## the hand-written sources must pass the value through clamp_prec_g, or be one
## verbatim exemption.
## ⚠ THIS NOW REALLY IS EVERY HAND-WRITTEN SOURCE (the $SRC glob above), not the
## seven files it used to be. The independent sabotage planted a fifth unclamped
## writer in src/actions.c and this row stayed green.
## ⚠ AND IT IS NO LONGER ONE LITERAL SPELLING OF THE ASSIGNMENT, WHICH IS WHAT THE
## FOURTH ROUND BROKE. This row used to count the string
## `xctx->ev_precision = tclgetintvar(`, so THREE legal C spellings of the very thing
## its name forbids walked through it (receipts/C3v-final.md §2.2), all three leaving
## `ALL PASS (58 checks)`:
##   M1  `xctx->ev_precision=tclgetintvar("ev_precision");`   -- no spaces round the `=`
##   M6  `int t = tclgetintvar("ev_precision"); xctx->ev_precision = t;` -- two statements
##   (and any compound form: `xctx->ev_precision += 200;`, `xctx->ev_precision++;`)
## M1 is closed by `cs_norm`; M6 and the compound forms are closed by asking the
## question from the OTHER END -- not "does this one string appear?" but "for every
## write to the field, is the value written a clamp_prec_g() call?". A write is
## recognised as `=` (and not `==`), a compound assignment, or `++`/`--`, and what
## counts is the text from the field to the terminating `;`, so a write buried in a
## larger statement is still a write.
## ⚠ THE ONE EXEMPTION IS ITSELF A FENCE (the X1b/X1c principle): xinit.c's initial
## value needs no clamp because 4 is already below every cap, and it is listed here
## VERBATIM, so editing that line reddens this row as an unclamped writer. The third
## element of the answer asserts the exemption is USED, so an exemption for a line
## that no longer exists reddens too. It is spelled `xctx->ev_precision= 4;` in
## src/xinit.c -- no space before the `=` -- which is exactly the spelling M1 used and
## a standing reminder that the C in this tree is not written to one house style.
## ⚠ NAMED RESIDUE, because this row cannot see it: a write reached through a POINTER
## or an aliased struct copy (`p = xctx; p->ev_precision = 200;`), and the `if(0)`
## shape of NAMED LIMIT 1, which is at a true statement position. W4c closes the
## related hole from the source end: any read of the Tcl variable at all.
set W4exempt [list {xctx->ev_precision = 4;}]
set W4exemptn {} ; foreach _e $W4exempt { lappend W4exemptn [nrm $_e] }
set W4CLAMPED [nrm {xctx->ev_precision = clamp_prec_g(tclgetintvar("ev_precision"), DTOA_ENG_BUFSIZE);}]
## Every write to `xctx->ev_precision` in a collapsed+normalised pair, as a list of
## {write-text enclosing-statement}: the write is the field through the `;`, the
## statement reaches back to the previous `;`, `{` or `}` so a failing line can be read.
proc ev_writes {ncs} {
  lassign $ncs full code
  set F {xctx->ev_precision}
  set fl [string length $F] ; set n [string length $code]
  set out {} ; set i 0
  while {[set p [string first $F $code $i]] >= 0} {
    set i [expr {$p + $fl}]
    if {$p > 0 && [regexp {[A-Za-z0-9_]} [string index $code [expr {$p - 1}]]]} { continue }
    if {[regexp {[A-Za-z0-9_]} [string index $code $i]]} { continue }
    if {![regexp {^(=[^=]|\+\+|--|<<=|>>=|[-+*/%&|^]=)} [string range $code $i end]]} { continue }
    set e [string first ";" $code $p]
    if {$e < 0} { set e [expr {$n - 1}] }
    set s 0
    for {set j [expr {$p - 1}]} {$j >= 0} {incr j -1} {
      if {[string first [string index $code $j] ";\{\}"] >= 0} { set s [expr {$j + 1}] ; break }
    }
    lappend out [list [string range $full $p $e] \
                      [string trim [string range $full $s $e]]]
  }
  return $out
}
## ⚠ THE PER-WRITE DECISION IS ITS OWN PROC FOR THE SAME REASON X1's IS (see the note
## above `x1_verdict`), AND THE MEASUREMENT IS RECORDED HERE BECAUSE IT WAS TAKEN: W4 is
## a NEGATIVE row, so WEAKENING ITS RULE CANNOT BE CAUGHT BY SABOTAGING THE TREE.
## Measured 2026-09-25 (cycle SAB_w4lit of receipts/C4-claims.md): replacing the exact
## shape test below with the old token-presence test
## (`[string first {clamp_prec_g} $wr] >= 0`) left the suite at `RESULT: ALL PASS
## (62 checks)` -- on a correct tree there is nothing for the weakened rule to miss.
## So the rule gets a UNIT row, W4d, exactly as X1's rules get X1d.
proc w4_verdict {wr} {
  if {$wr eq $::W4CLAMPED} { return clamped }
  if {[lsearch -exact $::W4exemptn $wr] >= 0} { return exempt }
  return bad
}
## ... and the read-side one. `clamp_prec_g(` is 13 characters, so a read at index $p is
## wrapped only if the whole accepted call text starts exactly 13 characters earlier.
proc w4c_wrapped {full p} {
  set w [expr {$p - 13}]
  return [expr {$w >= 0 && [string first $::W4cWRAP $full $w] == $w}]
}
## ⚠ AND THE LAST CLAUSE IS THE ANTI-VACUITY ONE, BY NAME (the X2 principle). This row
## is NEGATIVE: if `ev_writes` ever returned nothing -- a renamed field, a tokeniser
## regression, an off-by-one in the write recogniser -- it would pass on a tree it had
## not read, and W1/W2/W3 would not notice because they match their own statements
## directly. So the WRITE SITES ARE ASSERTED BY FILE AND COUNT: two in draw.c (draw and
## draw_graph), one in eval_expr.y (kklex), one in xinit.c (the exempt initial 4). A new
## file appearing here is a new writer and is meant to redden.
set W4bad {} ; set W4seen {} ; set W4at {}
dict for {f ncs} $SRCN {
  set n 0
  foreach w [ev_writes $ncs] {
    lassign $w wr stmt
    incr n
    switch -exact -- [w4_verdict $wr] {
      clamped { }
      exempt  { lappend W4seen $wr }
      default { lappend W4bad "$f: UNCLAMPED WRITE TO xctx->ev_precision: $stmt" }
    }
  }
  if {$n} { lappend W4at "$f x$n" }
}
check {W4 every write SPELLED THROUGH THE FIELD NAME `xctx->ev_precision` in the\
 hand-written sources passes its value through clamp_prec_g -- whatever the spacing,\
 and whether it is one statement or two; the one exemption (xinit.c's initial 4) is\
 still used, and those writes are at exactly the four sites this suite fences by name.\
 THIS ROW DOES NOT CLAIM THERE IS NO UNCLAMPED WRITER: a write that never spells the\
 field is invisible to it (NAMED LIMIT 6)} \
  [list [llength $W4bad] $W4bad [lsort $W4seen] [lsort $W4at]] \
  [list 0 {} [lsort $W4exemptn] {{draw.c x2} {eval_expr.y x1} {xinit.c x1}}]

## ⚠ W4c IS THE SAME QUESTION FROM THE SOURCE END, AND IT IS WHAT MAKES W4's NAME
## SAFE RATHER THAN MERELY TRUE TODAY. W4 watches the FIELD; a value can reach
## dtoa_eng without ever touching it (graph_marker_text_rec does exactly that, and its
## `prec` is reached by no writer clamp at all). So: every read of the Tcl
## `ev_precision` variable in the hand-written sources is either the argument of
## `clamp_prec_g(..., DTOA_ENG_BUFSIZE)` or one verbatim exemption. That closes M6 a
## second time -- a local the read is parked in is a read wherever it later goes.
## ⚠ THE EXEMPTION, AND WHY IT IS ONE: graph_marker_text_rec's getter reads the Tcl
## var directly and must not write the field (draw_graph owns it). It is safe for a
## different reason, fenced by different rows -- G7 caps it at 17 for display, and
## dtoa_eng plus graph_marker_fmt clamp against their own buffers (K2, G6, G6b). It
## is listed verbatim, so editing that line reddens this row.
## ⚠ THE FAILURE DIRECTION, STATED: the accepted form is the exact wrapped text, so a
## clamped read spelled `clamp_prec_g((tclgetintvar("ev_precision")))` or clamped
## against something other than DTOA_ENG_BUFSIZE reddens this row. That is a false
## FAIL on a tree nobody has yet written, which for a NEGATIVE row is the safe
## direction; a false PASS is what M1/M2/M6 were.
set W4READ {tclgetintvar("ev_precision")}
set W4cWRAP [nrm "clamp_prec_g($W4READ, DTOA_ENG_BUFSIZE)"]
set W4cexempt [list {prec = tclgetintvar("ev_precision");}]
set W4cexemptn {} ; foreach _e $W4cexempt { lappend W4cexemptn [nrm $_e] }
set W4cbad {} ; set W4cseen {} ; set W4cfiles {}
dict for {f ncs} $SRCN {
  set full [lindex $ncs 0] ; set code [lindex $ncs 1]
  set rn [nrm $W4READ] ; set rl [string length $rn]
  set i 0
  while {[set p [string first $rn $full $i]] >= 0} {
    set i [expr {$p + $rl}]
    lappend W4cfiles $f
    if {[w4c_wrapped $full $p]} { continue }
    set e [string first ";" $code $p]
    if {$e < 0} { set e [expr {[string length $code] - 1}] }
    set s 0
    for {set j [expr {$p - 1}]} {$j >= 0} {incr j -1} {
      if {[string first [string index $code $j] ";\{\}"] >= 0} { set s [expr {$j + 1}] ; break }
    }
    set stmt [string trim [string range $full $s $e]]
    if {[lsearch -exact $W4cexemptn $stmt] >= 0} { lappend W4cseen $stmt ; continue }
    lappend W4cbad "$f: UNCLAMPED READ of the Tcl ev_precision var: $stmt"
  }
}
## The last clause is the anti-vacuity one, BY NAME and not by count (the X2
## principle): if the read needle ever stops matching -- a renamed accessor, a
## tokeniser regression -- this row would otherwise pass on a tree it never read. A
## NEW file appearing here is a new door onto the Tcl variable and is meant to redden.
check {W4c ... and every READ of the Tcl ev_precision var in the hand-written sources\
 is wrapped in clamp_prec_g(.., DTOA_ENG_BUFSIZE) at the read itself, so a value that\
 reaches a formatter through a LOCAL rather than through the field is caught too --\
 with exactly one exemption (graph_marker_text_rec's getter), and the reads are in\
 exactly the two files this suite fences by name} \
  [list [llength $W4cbad] $W4cbad [lsort $W4cseen] [lsort -unique $W4cfiles]] \
  [list 0 {} [lsort $W4cexemptn] {draw.c eval_expr.y}]

## ⚠ W4d IS THE UNIT ROW FOR W4's AND W4c's RULES AND FOR THE WRITE RECOGNISER, and it
## exists because MEASUREMENT said it had to: weakening `w4_verdict` to the old
## token-presence test left the suite at ALL PASS (cycle SAB_w4lit). A negative row
## cannot fence its own strictness -- the same argument as X1d and X1e.
## The cases, and what each one is:
##   1-2  the real clamped writer, in BOTH spellings -- with spaces round the `=` and
##        without (decoy M1's spelling). Both must read `clamped`, or `cs_norm` is not
##        doing its job and W4 is matching a spelling again.
##   3-4  xinit.c's exempt initial 4, in both spellings. The tree really writes
##        `xctx->ev_precision= 4;` with no space before the `=`, so case 4 is the one
##        that matters and case 3 is the one a reader would have written.
##   5    the unclamped writer decoys N12/M1 plant
##   6    M6's SECOND statement -- the value arrives through a local, and the write
##        itself names no clamp at all. This is the case the old literal needle missed.
##   7    clamped against a LITERAL instead of DTOA_ENG_BUFSIZE: the N8 shape moved to a
##        writer. Accepted by a token-presence test, rejected here.
##   8-9  a compound assignment and an increment -- writes that carry no `=` needle
##   10   ev_writes must not mistake a COMPARISON for a write (`== 4`)
##   11   ... and must find a write inside a larger statement, whatever the spacing
##   12-14 the read-side test: the accepted wrap, a wrap against the wrong ceiling, and
##        a bare unwrapped read
proc w4d {t} { return [w4_verdict [nrm $t]] }
proc w4d_reads {t} {
  set ncs [cs_collapse [ctok $t]]
  set full [lindex $ncs 0] ; set rn [nrm $::W4READ]
  set out {} ; set i 0
  while {[set p [string first $rn $full $i]] >= 0} {
    set i [expr {$p + [string length $rn]}]
    lappend out [expr {[w4c_wrapped $full $p] ? 1 : 0}]
  }
  return $out
}
set W4dwrites [cs_collapse [ctok "if(k) xctx->ev_precision=zt;\nif(xctx->ev_precision == 4) f();\n"]]
check {W4d and the rules themselves, on synthetic text: the clamped writer in both\
 spellings, xinit.c's exempt 4 in both, a bare unclamped writer, M6's second statement,\
 a writer clamped against a LITERAL instead of DTOA_ENG_BUFSIZE, a compound assignment,\
 an increment, a COMPARISON that is not a write, a write inside a larger statement, and\
 the read-side wrap test on the accepted form, the wrong ceiling and a bare read} \
  [list [w4d {xctx->ev_precision = clamp_prec_g(tclgetintvar("ev_precision"), DTOA_ENG_BUFSIZE);}] \
        [w4d {xctx->ev_precision=clamp_prec_g(tclgetintvar("ev_precision"),DTOA_ENG_BUFSIZE);}] \
        [w4d {xctx->ev_precision = 4;}] \
        [w4d {xctx->ev_precision= 4;}] \
        [w4d {xctx->ev_precision = tclgetintvar("ev_precision");}] \
        [w4d {xctx->ev_precision = zt;}] \
        [w4d {xctx->ev_precision = clamp_prec_g(tclgetintvar("ev_precision"), 1024);}] \
        [w4d {xctx->ev_precision += 200;}] \
        [w4d {xctx->ev_precision++;}] \
        [llength [ev_writes $W4dwrites]] \
        [lindex [lindex [ev_writes $W4dwrites] 0] 0] \
        [w4d_reads {p = clamp_prec_g(tclgetintvar("ev_precision"), DTOA_ENG_BUFSIZE);}] \
        [w4d_reads {p = clamp_prec_g(tclgetintvar("ev_precision"), 1024);}] \
        [w4d_reads {p = tclgetintvar("ev_precision");}]] \
  [list clamped clamped exempt exempt bad bad bad bad bad \
        1 {xctx->ev_precision=zt;} 1 0 0]

## ⚠ W4 (AND X1 AND X2) WOULD READ "CLEAN" IF THE FILE LIST WERE EVER NARROWED
## AGAIN, so the exclusion list is WRITTEN OUT A SECOND TIME HERE, verbatim, and
## this row asserts the scanned set is exactly `glob minus those four`. Same
## principle as X1's exemption list: the exemption is itself the fence. Measured --
## a first attempt at this row derived its expectation from $GENERATED and was
## therefore vacuous: adding actions.c to $GENERATED left it GREEN.
## `actions.c`, `token.c`, `xinit.c` and `scheduler.c` are named explicitly because
## actions.c is where the independent sabotage planted its fifth writer and its new
## unclamped sprintf, and the other three are the files the old seven-file list
## either covered or (scheduler.c) never did.
set W4gen {eval_expr.c expandlabel.c expandlabel.h parselabel.c}
set W4want {}
foreach pat {*.c *.h *.y *.l} {
  foreach fp [lsort [glob -nocomplain -directory [file join $repo src] $pat]] {
    set t [file tail $fp]
    if {[lsearch -exact $W4gen $t] >= 0} { continue }
    lappend W4want $t
  }
}
set W4diff {}
foreach t [lsort -unique [concat [dict keys $SRC] $W4want]] {
  set a [expr {[dict exists $SRC $t] ? 1 : 0}]
  set b [expr {[lsearch -exact $W4want $t] >= 0 ? 1 : 0}]
  if {$a != $b} { lappend W4diff "$t scanned=$a should-be=$b" }
}
set W4inputs {}
foreach t {eval_expr.y expandlabel.y parselabel.l actions.c token.c xinit.c \
           scheduler.c xschem.h} {
  if {![dict exists $SRC $t]} { lappend W4inputs "MISSING:$t" }
}
check {W4b ... and the file list W4/X1/X2 scan is EVERY src/*.c *.h *.y *.l minus\
 exactly the four GENERATED files -- the generated parsers' hand-written .y/.l\
 INPUTS included, so excluding the twins excludes no source} \
  [list [llength $W4diff] $W4diff $W4inputs] {0 {} {}}

## The initial value in xinit.c is the fourth place ev_precision is written, and 4
## needs no clamp. What it DID need is a truthful comment: it used to name only
## draw() and draw_graph(), which is the list a reader trusts instead of grepping.
## Comments are stripped everywhere else in this suite; this one row reads the RAW
## file on purpose, because the comment IS the artefact.
set XINIT_RAW [slurp [file join $repo src xinit.c]]
check {W5 xinit.c's comment on the initial 4 now names kklex() too, so the writer\
 list a reader trusts is complete} \
  [expr {[regexp {ev_precision var in draw\(\) and draw_graph\(\) \(draw\.c\) and in} $XINIT_RAW]
         && [regexp {kklex\(\)} $XINIT_RAW] ? 1 : 0}] 1

## ⚠ W5b IS THE SAME ARGUMENT AT THE COMMENT A READER HITS FIRST. The
## `Xschem_ctx.ev_precision` FIELD comment in src/xschem.h also carried the
## incomplete writer list (draw() and draw_graph() only); the fix corrected it and
## then declined to fence it as "prose with no distinctive token". But W5 fences
## the xinit.c comment over the RAW file for exactly that reason -- the comment IS
## the artefact -- and the independent sabotage reverted this one to its pre-fix
## text with nothing reddening (cycle S32 of receipts/Cv-sabotage.md). Anchored on
## `kklex` appearing inside the comment that precedes `int ev_precision;`, so a
## kklex() mention elsewhere in this 4000-line header cannot satisfy it.
set XSCHEMH_RAW [slurp [file join $repo src xschem.h]]
## The block comment that IMMEDIATELY precedes `int ev_precision;` -- nothing but
## whitespace may sit between them, so a kklex() mention anywhere else in this
## 4000-line header cannot satisfy the row.
proc doc_comment_before {raw decl} {
  if {[scount $raw $decl] != 1} { return ZZNOTONCE }
  set i [string first $decl $raw]
  set e [string last "*/" [string range $raw 0 $i]]
  if {$e < 0} { return ZZNOCOMMENT }
  set s [string last "/*" [string range $raw 0 $e]]
  if {$s < 0} { return ZZNOCOMMENT }
  if {[string trim [string range $raw [expr {$e + 2}] [expr {$i - 1}]]] ne {}} {
    return ZZNOTADJACENT
  }
  return [string range $raw $s [expr {$e + 1}]]
}
set W5bdoc [doc_comment_before $XSCHEMH_RAW {int ev_precision;}]
check {W5b the Xschem_ctx.ev_precision FIELD comment in src/xschem.h names kklex()\
 too, so the writer list the first reader trusts is complete} \
  [expr {[string first {kklex} $W5bdoc] >= 0
         && [string first {draw_graph} $W5bdoc] >= 0
         && [string first {clamp_prec_g} $W5bdoc] >= 0 ? 1 : 0}] 1

## src/eval_expr.c is generated and gitignored. If a build has produced one it must
## carry the clamp, or the binary under test is stale; if it is absent (fresh
## clone) that is correct and this row passes.
set EVALC [file join $repo src eval_expr.c]
check {W6 a GENERATED src/eval_expr.c, if one exists, carries kklex()'s clamp (a\
 stale one would mean the binary under test predates the fix)} \
  [expr {![file exists $EVALC]
         || [cfind $CLAMPED_WRITE [cs_collapse [cstrip [slurp $EVALC]]]] >= 0 ? 1 : 0}] 1

# ===========================================================================
# SECTION G -- THE PER-SITE CLAMPS, ONE ROW PER SITE, BY NAME
#
# Each of these is the ONLY fence on its clamp. A behavioural row cannot isolate
# them: the writers already cap ev_precision at 71, so removing any one use-site
# clamp leaves the observable output unchanged. That redundancy is deliberate
# defence in depth -- and it is exactly why the fence has to be static.
# ===========================================================================
check {G1 draw_cursor's "%.*g%c" readout clamps against its whole 100-byte buffer} \
  [expr {[cfind {sprintf(tmpstr, "%.*g%c", clamp_prec_g(xctx->ev_precision, S(tmpstr)), gr->unitx * active_cursorx , gr->unitx_suffix);} \
           [cfunc $C_DRAW draw_cursor]] >= 0 ? 1 : 0}] 1

check {G2 draw_cursor_difference's "%.*g%c" readout clamps against its whole\
 100-byte buffer} \
  [expr {[cfind {sprintf(tmpstr, "%.*g%c", clamp_prec_g(xctx->ev_precision, S(tmpstr)), gr->unitx * diffw , gr->unitx_suffix);} \
           [cfunc $C_DRAW draw_cursor_difference]] >= 0 ? 1 : 0}] 1

## ⚠ THE `- 2` IS NOT SLOP: the format is " %.*g%c ", with a LITERAL SPACE on each
## side of the conversion. Those two bytes are not available to the number, and
## without the subtraction the clamp would permit a string that is exactly two
## bytes too long for tmpstr.
check {G3 draw_hcursor's " %.*g%c " readout clamps against S(tmpstr) - 2, paying\
 for the two literal spaces} \
  [expr {[cfind {sprintf(tmpstr, " %.*g%c ", clamp_prec_g(xctx->ev_precision, S(tmpstr) - 2), gr->unity * active_cursory , gr->unity_suffix);} \
           [cfunc $C_DRAW draw_hcursor]] >= 0 ? 1 : 0}] 1

check {G4 draw_hcursor_difference's " %.*g%c " readout clamps against\
 S(tmpstr) - 2, paying for the two literal spaces} \
  [expr {[cfind {sprintf(tmpstr, " %.*g%c ", clamp_prec_g(xctx->ev_precision, S(tmpstr) - 2), gr->unity * diffh , gr->unity_suffix);} \
           [cfunc $C_DRAW draw_hcursor_difference]] >= 0 ? 1 : 0}] 1

## ⚠ show_node_measures IS THE SITE PLAN.md POINTED AT draw_graph_variables.
## draw_graph_variables exists and owns its own char tmpstr[1024], but it has no
## indirect-precision sprintf; the 1024-byte indirect site is this function,
## immediately below it.
set F_SNM [cfunc $C_DRAW show_node_measures]
check {G5 show_node_measures (NOT draw_graph_variables) clamps the local `prec`\
 it prints its 1024-byte tmpstr with} \
  [expr {[cfind {int prec = clamp_prec_g(xctx->ev_precision, S(tmpstr));} $F_SNM] >= 0 ? 1 : 0}] 1

## ⚠ AND THE REASON G5b EXISTS. This site's format strings are `char *` VARIABLES,
## so a row grepping near it for a literal "%.*g" matches nothing at all. Fence it
## by the variable names and the four assignments, and pin `prec = 2` -- which is
## what makes the %e arm (the only arm that CAN grow without limit, because %e
## zero-pads) safe, and which a reader "hardening" the %g arm would delete.
check {G5b show_node_measures still formats through the fmt1/fmt2 VARIABLES, and\
 its %e arm is still pinned at prec = 2} \
  [expr {[ccount $F_SNM {fmt1="%.*e"; fmt2="%.*e%c";}] == 1
         && [ccount $F_SNM {fmt1="%.*g"; fmt2="%.*g%c";}] == 1
         && [ccount $F_SNM {prec = 2;}] == 1
         && [ccount $F_SNM {sprintf(tmpstr, fmt2, prec, yy * gr->unity, gr->unity_suffix);}] == 1
         && [ccount $F_SNM {sprintf(tmpstr, fmt1, prec, yy);}] == 1 ? 1 : 0}] 1

## graph_marker_fmt now HONOURS its destsize on the sprintf arm, so the signature
## stops lying and a fifth caller with a smaller dest is covered. Its `prec` comes
## from graph_marker_text_rec's own tclgetintvar, which no writer clamp reaches.
check {G6 graph_marker_fmt clamps against its own destsize parameter} \
  [expr {[cfind {sprintf(dest, "%.*g%c", clamp_prec_g(prec, (size_t)destsize), unit * v, suffix);} \
           [cfunc $C_DRAW graph_marker_fmt]] >= 0 ? 1 : 0}] 1

check {G6b graph_marker_fmt refuses a NULL dest or a destsize <= 0 instead of\
 casting it to a huge size_t} \
  [expr {[cfind {if(!dest || destsize <= 0) return;} \
           [cfunc $C_DRAW graph_marker_fmt]] >= 0 ? 1 : 0}] 1

## The 17 is now a DISPLAY choice, not the safety bound -- but section D's marker
## row is what it is because of it, so it is fenced here rather than left to drift.
check {G7 graph_marker_text_rec still caps its marker readout at 17 significant\
 digits (a display choice now, and what B6 measures)} \
  [expr {[cfind {if(prec > 17) prec = 17;} \
           [cfunc $C_DRAW graph_marker_text_rec]] >= 0 ? 1 : 0}] 1

set F_WAVES [cfunc $C_CALLBACK waves_callback]
check {G8 the callback.c measurement tooltip's x readout clamps against its own\
 100-byte sx} \
  [expr {[cfind {sprintf(sx, "%.*g%c", clamp_prec_g(xctx->ev_precision, S(sx)), gr->unitx * xval, gr->unitx_suffix);} \
           $F_WAVES] >= 0 ? 1 : 0}] 1

check {G9 the callback.c measurement tooltip's y readout clamps against its own\
 100-byte sy} \
  [expr {[cfind {sprintf(sy, "%.*g%c", clamp_prec_g(xctx->ev_precision, S(sy)), gr->unity * yval, gr->unity_suffix);} \
           $F_WAVES] >= 0 ? 1 : 0}] 1

## ⚠ G10 IS A SECOND DEFECT, NOT AN ev_precision ONE, FIXED HERE BECAUSE IT IS AT
## ONE OF 1606'S OWN SITES AND IT MOVES 1606'S OWN THRESHOLD. The y branch tested
## `gr->unitx != 1.0` while its body formatted `gr->unity * yval` with
## `gr->unity_suffix`. Two live consequences: a graph with `unity=T` and no
## `unitx` -- an ordinary configuration -- sent the y readout through dtoa_eng's
## 80-byte static instead of this 100-byte sy, dropping that readout's abort
## threshold from 93 to 73; and `unitx=T` alone formatted the y value with
## unity == 1.0 and unity_suffix == 0, so the %c wrote a NUL where a suffix was
## meant. D3/D4 measure the behaviour; this row fences the guard itself.
check {G10 (second defect) the tooltip's y branch tests gr->unity, and the\
 gr->unitx guard over a gr->unity body is gone} \
  [expr {[ccount $F_WAVES {if(gr->unity != 1.0) sprintf(sy,}] == 1
         && [ccount $F_WAVES {if(gr->unitx != 1.0) sprintf(sy,}] == 0
         && [ccount $F_WAVES {if(gr->unitx != 1.0) sprintf(sx,}] == 1 ? 1 : 0}] 1

## save.c's nd_view_set is the annotation-read door: place a cursor, read
## ngspice::ngspice_data(<node>), and this sprintf runs with the publisher's
## precision -- which for the cursor-B publisher is xctx->ev_precision.
check {G11 save.c's nd_view_set clamps the publisher precision it prints with} \
  [expr {[cfind {sprintf(s, "%.*g", clamp_prec_g(nd_view.prec, S(s)), nd_view.raw->cursor_b_val[idx]);} \
           [cfunc $C_SAVE nd_view_set]] >= 0 ? 1 : 0}] 1

# ===========================================================================
# SECTION X -- THE SWEEP. This is the row that catches a NEW site nobody
# remembered to clamp, which is the failure mode every per-site row above
# is blind to.
# ===========================================================================
## ⚠ X1 USED TO BE A TOKEN-PRESENCE TEST AND THAT WAS NOT ENOUGH. Its filter was
## `[string first {clamp_prec_g} $st] >= 0 { continue }` -- the TOKEN, anywhere in
## the statement, nothing about where its result goes. Two decoys walked through it
## (N7 and N8 of receipts/C2v-reprove.md), both reaching ALL PASS (51 checks):
##
##   sprintf(zb, "%.*g", (clamp_prec_g(...), xctx->ev_precision), zv);
##       -- the COMMA OPERATOR: the clamp is computed and thrown away, and the
##          unclamped value is what reaches the conversion
##   sprintf(zb, "%.*g", clamp_prec_g(xctx->ev_precision, 1024), zv);  /* char zb[24] */
##       -- clamped, against the WRONG BUFFER's size
##
## So this row now PARSES the statement instead of grepping it. For every sprintf
## whose format literal carries a `%.*`:
##   1. the argument in the `%.*` POSITION (computed from the format, counting every
##      conversion and every `*` width before it) must BE a clamp_prec_g() call and
##      nothing else -- a call inside a larger expression is not the argument;
##   2. the clamp's own `avail` argument must NAME THE DESTINATION as a whole
##      identifier, so `S(tmpstr)`, `S(tmpstr) - 2`, `S(sx)`, `S(s)` and
##      `sizeof(s) - 2` pass and a bare `1024` does not.
##
## ⚠ THE THIRTEEN EXISTING SITES ARE ALL FENCED BY NAME ELSEWHERE, BUT NOT ALL BY A
## `G<n>` ROW, and the previous revision of this sentence said "their exact-text G
## rows" for all thirteen. Counted: EIGHT have a per-site `G` row (G1 G2 G3 G4 G6 G8
## G9 G11 -- a swapped-argument sabotage reddens G6, measured), THREE are dtoa_eng's
## own and are fenced by K2/K3 (its two above-the-branch arms plus the "%.*gMEG" arm),
## and TWO are show_node_measures', which X1 cannot see at all because its formats are
## `char *` variables -- G5 and G5b fence those by the variable names. So this row is
## about a NEW site, and the map of who fences the old ones is 8 + 3 + 2.
##
## ⚠ TWO EXEMPTION LISTS, BOTH VERBATIM, BECAUSE AN EXEMPTION IS ITSELF A FENCE:
## editing the exempted statement reddens this row as an unfenced site.
##   X1exempt      dtoa_eng's "%.*g%c" and bare "%.*g" arms, whose clamp sits ONE
##                 STATEMENT ABOVE the suffix branch (adjudication C4: one clamp
##                 correct for all 24 callers, not three). K2/K3 fence it and its
##                 position. ⚠ THE "%.*gMEG" ARM IS NO LONGER ON THIS LIST -- it
##                 now carries its own clamp (see K3) and passes rules 1 and 2 like
##                 any other site.
##   X1sizeexempt  graph_marker_fmt's, which receives its buffer and that buffer's
##                 size as TWO SEPARATE PARAMETERS (`dest`, `destsize`), so no
##                 textual rule can link them -- `(size_t)destsize` does not
##                 contain `dest` as a whole word. Rule 1 still applies to it; only
##                 rule 2 is waived, and G6 plus G6b (which refuses a NULL dest or a
##                 destsize <= 0) are what fence the link instead.
## ⚠ BOTH LISTS GO THROUGH `nrm`, THE SAME NORMALISER THE HAYSTACK GOES THROUGH,
## because they are compared with `lsearch -exact` against a normalised statement --
## and they stay written here in ordinary C spelling so a reader can match them
## against the source by eye.
set X1exempt {} ; set X1sizeexempt {}
foreach _e [list \
  {sprintf(s, "%.*g%c", precision, i, suffix);} \
  {sprintf(s, "%.*g", precision, i);}] { lappend X1exempt [nrm $_e] }
foreach _e [list \
  {sprintf(dest, "%.*g%c", clamp_prec_g(prec, (size_t)destsize), unit * v, suffix);}] \
  { lappend X1sizeexempt [nrm $_e] }
## ⚠ THE PER-STATEMENT DECISION IS ITS OWN PROC, AND THAT IS NOT TIDINESS.
## X1 is a NEGATIVE row, so WEAKENING EITHER RULE CANNOT BE CAUGHT BY SABOTAGING
## THE TREE: on a correct tree there is nothing for the weakened rule to miss.
## Measured 2026-09-25 -- replacing `is_clamp_call` with the old token-presence test,
## and dropping the destination-naming test outright, each left the suite at
## `RESULT: ALL PASS (57 checks)`. So the rules get a UNIT row (X1d) on synthetic
## statements, exactly as the stripper gets Z0 and the preprocessor gets Z3, and the
## adversarial half is the N7/N8 plants, which do redden X1.
proc x1_verdict {f stcs exempt sizeexempt} {
  set st [cs_text $stcs]
  ## ⚠ THE ONE TEST IN THIS FILE THAT MUST READ THE INTACT HALF, and it is not an
  ## exception to the rule but the rule applied: a `%.*` is BY DEFINITION inside a
  ## format string literal, so looking for it in the blanked half would find nothing
  ## ever and this row would be vacuous. Reading the intact half can only make this
  ## row consider MORE statements, which is the safe direction for a negative row;
  ## the decoy-hiding direction is the one `cfind` protects.
  if {[string first {%.*} $st] < 0} { return {skip {}} }
  if {$f eq {editprop.c} && [lsearch -exact $exempt $st] >= 0} {
    return {exempt above-the-branch}
  }
  set args [call_args $stcs]
  if {[llength $args] < 3} { return {bad {ARGUMENTS DO NOT PARSE}} }
  set k [star_arg_index [cs_text [lindex $args 1]]]
  if {$k < 0} { return {bad {`%.*` IS NOT IN THE FORMAT ARGUMENT}} }
  set pa [lindex $args [expr {2 + $k}]]
  if {$pa eq {}} { return {bad {NO ARGUMENT IN THE `%.*` POSITION}} }
  if {![is_clamp_call [cs_text $pa]]} {
    return [list bad "`%.*` ARGUMENT IS NOT A clamp_prec_g() CALL ([cs_text $pa])"]
  }
  if {[lsearch -exact $sizeexempt $st] >= 0} { return {exempt destination-naming} }
  set av [cs_text [lindex [call_args $pa] 1]]
  if {![word_in $av [cs_text [lindex $args 0]]]} {
    return [list bad "the clamp's avail ($av) does not NAME the destination\
 ([cs_text [lindex $args 0]])"]
  }
  return {ok {}}
}
set X1bad {} ; set X1seen {} ; set X1sizeseen {}
dict for {f src} $SRC {
  foreach stcs [sprintf_stmts [dict get $SRCN $f] [sprintf_aliases $src]] {
    lassign [x1_verdict $f $stcs $X1exempt $X1sizeexempt] v d
    if {$v eq {bad}} { lappend X1bad "$f: $d: [cs_text $stcs]" } \
    elseif {$v eq {exempt} && $d eq {above-the-branch}} { lappend X1seen [cs_text $stcs] } \
    elseif {$v eq {exempt}} { lappend X1sizeseen [cs_text $stcs] }
  }
}
## ⚠ THE SCOPE IS EVERY HAND-WRITTEN SOURCE. The independent sabotage added a new
## unclamped `sprintf(b, "%.*g%c", p, v, 84);` to src/actions.c -- outside the seven
## files this row used to iterate -- and X1 AND X2 both stayed GREEN (probe C2 of
## receipts/Cv-sabotage.md). W4b states the scope.
## ⚠ THE ROW NAME SAYS WHAT THIS ROW DELIVERS, NOT WHAT WOULD BE NICE. It used to say
## "in every indirect-precision sprintf statement in the hand-written sources", and
## that was measurably false twice over: decoy M2 spelled one `sprintf (zb, ...)` and
## walked through (closed now, by `cs_norm`), and show_node_measures' two real sites
## are indirect-precision sprintf statements this row STILL cannot see, because their
## `%.*` lives in a `char *` variable and not in the statement (NAMED LIMIT 2; G5/G5b
## fence them by the variable names). So the name is scoped to the statements whose own
## FORMAT LITERAL carries the `%.*`, which is exactly the set this row decides.
check {X1 in every sprintf statement whose own format literal carries the CONTIGUOUS\
 TEXT `%.*` -- including one spelled `sprintf (` or through a one-hop object-like\
 `#define` alias -- the argument in the `%.*` position IS a clamp_prec_g() call and\
 that clamp's avail NAMES the destination buffer, not merely a clamp_prec_g token\
 somewhere in the statement. THIS ROW DOES NOT CLAIM TO SEE EVERY INDIRECT-PRECISION\
 sprintf: a format in a `char *` variable (NAMED LIMIT 2) and one whose `%.*` is not\
 contiguous text (NAMED LIMIT 8) are both out of its reach} \
  [list [llength $X1bad] $X1bad] {0 {}}

## Neither exemption may grow silently: exactly dtoa_eng's two above-the-branch arms
## use the first, exactly graph_marker_fmt's statement uses the second, and all
## three must still be there.
check {X1b the above-the-branch exemption is used by exactly dtoa_eng's two\
 unclamped arms, both present} [lsort $X1seen] [lsort $X1exempt]

check {X1c the destination-naming exemption is used by exactly graph_marker_fmt's\
 statement, which takes its buffer and its size as separate parameters} \
  [lsort $X1sizeseen] [lsort $X1sizeexempt]

## ⚠ X1d IS THE UNIT ROW FOR THE TWO RULES, on synthetic statements, because a
## negative row cannot fence its own strictness (see the note above x1_verdict).
## Cases 1-2 and 9-11 are shapes this tree really contains, 3 and 4 are decoys N7
## and N8 verbatim, 5 and 6 are the plain-unclamped and swapped-argument shapes, and
## 7 and 8 are the two shapes the SABOTAGE OF THIS ROW found it could not see -- a
## clamp inside a larger expression (`4 + clamp_prec_g(...)`, which only rule 1
## catches, because rule 2 then reads the clamp's own second argument and is happy)
## and an avail naming a DIFFERENT buffer whose name merely CONTAINS the
## destination's (`S(zball)` for dest `zb`, which only the whole-identifier test in
## `word_in` catches). Without those two, weakening either `is_clamp_call` or
## `word_in` left the suite at ALL PASS: measured, and the reason this row has
## fourteen cases and not twelve. 9 and 10 exercise the format scan: a `*` WIDTH
## before the `%.*` precision consumes an argument of its own, and `%%` consumes
## none.
proc x1_case {text} { return [cs_collapse [ctok $text]] }
set X1dcases [list \
  editprop.c {sprintf(tmpstr, "%.*g%c", clamp_prec_g(xctx->ev_precision, S(tmpstr)), a, b);} \
  editprop.c {sprintf(tmpstr, " %.*g%c ", clamp_prec_g(xctx->ev_precision, S(tmpstr) - 2), a, b);} \
  draw.c     {sprintf(zb, "%.*g", (clamp_prec_g(xctx->ev_precision, S(zb)), xctx->ev_precision), zv);} \
  draw.c     {sprintf(zb, "%.*g", clamp_prec_g(xctx->ev_precision, 1024), zv);} \
  draw.c     {sprintf(zb, "%.*g", xctx->ev_precision, zv);} \
  draw.c     {sprintf(zb, "%.*g", clamp_prec_g(S(zb), xctx->ev_precision), zv);} \
  draw.c     {sprintf(zb, "%.*g", 4 + clamp_prec_g(p, S(zb)), zv);} \
  draw.c     {sprintf(zb, "%.*g", clamp_prec_g(p, S(zball)), zv);} \
  draw.c     {sprintf(zb, "%*d %.*g", w, n, clamp_prec_g(p, S(zb)), zv);} \
  draw.c     {sprintf(zb, "100%% %.*g", clamp_prec_g(p, S(zb)), zv);} \
  editprop.c {sprintf(s, "%.*gMEG", clamp_prec_g(precision, sizeof(s) - 2), i);} \
  editprop.c {sprintf(s, "%.*g", precision, i);} \
  draw.c     {sprintf(dest, "%.*g%c", clamp_prec_g(prec, (size_t)destsize), unit * v, suffix);} \
  draw.c     {sprintf(zb, "%g", zv);}]
set X1dgot {}
foreach {f text} $X1dcases {
  lappend X1dgot [lindex [x1_verdict $f [x1_case $text] $X1exempt $X1sizeexempt] 0]
}
check {X1d and the rules themselves, on synthetic statements: the two real shapes,\
 decoys N7 (a clamp discarded through the comma operator) and N8 (clamped against\
 the wrong size), a plain unclamped site, a swapped-argument clamp, a `*` WIDTH\
 before the precision, a `%%`, the MEG arm, both exemptions, and a direct-precision\
 sprintf} $X1dgot \
  {ok ok bad bad bad bad bad bad ok ok ok exempt exempt skip}

## ⚠ X1e IS THE UNIT ROW FOR THE STATEMENT FINDER, and it exists for the same reason
## X1d does: `sprintf_stmts` feeds a NEGATIVE row, so a statement it fails to find is a
## statement X1 cannot object to, and NO SABOTAGE OF THE TREE CAN CATCH THAT -- on a
## correct tree there is nothing to miss. Two of these cases are decoys that really did
## leave the suite at `ALL PASS (58 checks)`: `sprintf (` with one space before the
## paren (M2), and `#define SP sprintf` (named by the fourth adversary, not driven).
## The rest are the shapes the finder must NOT be fooled by, each of which broke it or
## a neighbour once: an identifier-prefixed `zz_sprintf(`, a `sprintf(` inside a
## STRING LITERAL, and a `;` inside a string literal
## ending the statement early -- the old version relied on "no format string in this
## tree contains a `;`", which was true and was not a reason.
proc x1e_stmts {text} {
  set cs [ctok $text]
  set out {}
  foreach stcs [sprintf_stmts [cs_collapse $cs] [sprintf_aliases $cs]] {
    lappend out [cs_text $stcs]
  }
  return [lsort $out]
}
set X1elines [list \
  {  sprintf (zb, "%.*g", p, zv);} \
  {  zz_sprintf(zb, S(zb), "%.*g", p, zv);} \
  {  q("sprintf(hidden, x);");} \
  {  sprintf(zb, "a;b", 1);}]
set X1eal [list \
  {#define SP sprintf} \
  {  SP(zc, "%.*g", p, zv);}]
check {X1e the statement finder finds a `sprintf (` with a space before the paren\
 (decoy M2) and an object-like `#define SP sprintf` alias call, is not fooled by an\
 identifier-prefixed `zz_sprintf(`, does not treat a `sprintf(` inside a string LITERAL\
 as a statement, and does not let a `;` inside a format string end one early} \
  [list [x1e_stmts [join $X1elines "\n"]] \
        [sprintf_aliases [ctok [join $X1eal "\n"]]] \
        [x1e_stmts [join $X1eal "\n"]]] \
  [list [list {sprintf(zb,"%.*g",p,zv);} {sprintf(zb,"a;b",1);}] \
        {SP} \
        [list {SP(zc,"%.*g",p,zv);}]]

## X1 is vacuous if nothing matched, so name the files that must still contain one.
## A NEW file appearing here is a site this suite does not fence by name.
set X2files {}
dict for {f src} $SRC {
  foreach stcs [sprintf_stmts [dict get $SRCN $f] [sprintf_aliases $src]] {
    if {[string first {%.*} [cs_text $stcs]] >= 0} { lappend X2files $f ; break }
  }
}
check {X2 and the files carrying a statement X1 CAN SEE are exactly the four this\
 suite fences by name, so a new file among them is a new unfenced site -- with X1's\
 own reach, not more: a file carrying only a shape from NAMED LIMIT 2 or 8 does not\
 appear here} \
  [lsort -unique $X2files] {callback.c draw.c editprop.c save.c}

# ===========================================================================
# SECTION Z -- WHAT IS ACTUALLY COMPILED, NOT WHAT IS MERELY WRITTEN
#
# ⚠ THIS SECTION EXISTS BECAUSE TEXT IS NOT CODE, AND IT HAS BEEN DEFEATED ONCE
# PER ROUND. Three rounds of independent sabotage (receipts/Cv-sabotage.md,
# receipts/C2v-reprove.md) parked a row's asserted statement somewhere the compiler
# throws away, deleted the real one, and got a green suite:
#
#   /* ... */                     a block comment                  (V1)   stripped
#   // ...                        a line comment                   (V4)   stripped
#   #if 0 / #if 0 && 1 / #if (0)  a dead region                    (V5)   resolved
#   "..."                         a STRING LITERAL                 (N3)   blanked
#   #define ZZ <the statement>    a macro nobody invokes           (N2)   Z1/Z2
#   #ifdef XSCHEM_NEVER           an undecidable region            (V3)   Z1/Z2
#   #ifndef __unix__              a region that is DEAD HERE       (N4)   resolved
#   #if HAS_CAIRO!=1              ditto                            (N5)   resolved
#   #if 1 / #else / the statement the DEAD BRANCH of a live #if    (N6)   resolved
#   if(0) <the statement>         no preprocessor at all           (N1)   NOT FENCED
#
# AND A FOURTH ROUND FOUND THREE MORE, NONE OF THEM A PREPROCESSOR SHAPE AT ALL --
# just legal C spelled differently from the needle (receipts/C3v-final.md §2.2):
#
#   xctx->ev_precision=tclget…    no spaces round the `=`           (M1)   cs_norm
#   sprintf (zb, …)               one space before the paren        (M2)   cs_norm
#   int t = tclget…; field = t;   the write in TWO statements       (M6)   W4 by shape
#   #define SP sprintf            an object-like alias             (M7)   sprintf_aliases
#
# ⚠ SO DO NOT WRITE "THE ONE SHAPE NO STRIPPER CAN REMOVE" OF ANY OF THEM. An
# earlier revision of this file said that of `#ifdef <undefined>`, and called it
# "THE FOURTH SHAPE, WHICH A STRIPPER CANNOT CATCH AT ALL". There were three more
# after it, and the one that is still open (N1) is not a preprocessor shape at all.
# The list of what remains out of reach is at the top of this file, under NAMED
# LIMITS, and it is the deliverable rather than an embarrassment.
#
# HOW THE FOUR KINDS ARE HANDLED NOW:
#   comments and literals   `ctok`, one tokeniser, both at once (Z0, Z0b)
#   decidable #if regions   `cs_pp`, a three-valued preprocessor over a MEASURED
#                           macro table -- dead branches dropped, `#else`/`#elif`
#                           walked (Z3, and Z4 proves it is wired in)
#   undecidable #if regions kept, and REPORTED: no directive of any kind may appear
#                           in the ten function bodies the static rows read (Z1),
#                           and in the four that legitimately carry one, every
#                           condition must be one `cs_pp` can decide (Z2)
#
# ⚠ WHAT SECTION Z DOES NOT COVER: H5, which greps the whole of src/xschem.h for
# `#define DTOA_ENG_BUFSIZE 80` rather than a function body. A decoy `#define`
# under an UNDECIDABLE `#ifdef` there, with the real one raised, would leave H5
# green -- one under a DEAD region would not any more, because cs_pp drops it. Every
# "exactly 71 significant digits" assertion in B1, B2, B3, B4, B5, B7 and D2 reddens
# on that tree anyway (measured as cycle S05 and re-measured as P05 this round, where
# raising the macro to 100 produced a self-consistent binary printing 91 digits).
# ⚠ H6 DOES NOT. An earlier revision of this sentence named it first and omitted B4.
# H6 asserts `static char s[DTOA_ENG_BUFSIZE];`, which neither raising the macro nor
# parking a decoy `#define` touches, so it stays GREEN under both -- measured twice.
# Stated, not fenced twice.
# ===========================================================================
## ⚠ Z0 AND Z0b FENCE THE TOKENISER ITSELF, on a synthetic snippet rather than on
## the tree, because the tree cannot fence it: this tree contains NO `//` line
## comment in code, so a naive `//` strip that truncated `"http://"` or
## `"// sch_path: %s\n"` (both real format strings here) would break no row today
## and would silently start hiding statements from X1 the day someone writes one.
## Every clause below is a shape the sabotage or this tree actually produced:
##   `/* */` spanning lines             -- the original stripper's only job
##   `//` after a STRING literal        -- save.c's "http://", two netlisters' "// sch_path:"
##   `//` after a CHAR literal          -- '/' appears in eleven files
##   `/*` INSIDE a string literal       -- decoys N10/N12: `dbg(1, "/*\n");` used to
##                                         open a comment that ran to the next real
##                                         `*/` and swallowed live code
##   `//` on the CONTINUATION line of a multi-line string literal -- decoy N9
##   `*/` inside a string literal       -- the same trick from the other end
##   the asserted statement inside a literal -- decoy N3, which Z0b is about
set Z0BS "\\"
set Z0lines [list \
  {int a; /* block} \
  { gone */ int b;} \
  {f("http://x"); // gone} \
  {if(c == '/') g(); // gone} \
  {dbg(1, "/*"); live1;} \
  "dbg(2, \"a$Z0BS" \
  {b // not a comment"); live2;} \
  {q("*/ still inside"); live3;} \
  {const char *zz = "precision = clamp_prec_g(precision, sizeof(s));"; live4;} \
  {int z;}]
## ⚠ TWO HAYSTACKS, ON PURPOSE. Z0 compares against an EXPECTED STRING, so it reads
## the whitespace-only collapse (`cs_ws`) and stays a unit row for `ctok` alone. Z0b
## asserts found/not-found through `cfind`, so it must read what every row in this
## file reads -- `cs_collapse`, punctuation normalisation included -- or its first
## clause would be vacuous for the wrong reason.
set Z0cs [cs_ws [ccstrip [join $Z0lines "\n"]]]
set Z0ncs [cs_collapse [ccstrip [join $Z0lines "\n"]]]
check {Z0 the tokeniser removes block comments and `//` to end of line, and does\
 NOT treat a `/*`, a `*/` or a `//` INSIDE a string or char literal as a comment --\
 including a `//` on the continuation line of a multi-line literal, which is where\
 decoys N9, N10 and N12 hid live code from the negative rows} \
  [cs_text $Z0cs] \
  [join [list {int a; int b; f("http://x"); if(c == '/') g(); dbg(1, "/*"); live1;} \
              "dbg(2, \"a$Z0BS b // not a comment\"); live2;" \
              {q("*/ still inside"); live3; const char *zz = "precision =} \
              {clamp_prec_g(precision, sizeof(s));"; live4; int z;}] { }]

## ⚠ Z0b IS THE HALF THAT CLOSES N3. Everything inside a string or char literal is
## blanked in the half a quote-free needle is matched against, so K2's statement
## parked in `static const char *zz = "..."` is simply not there -- while every
## statement the hiding tricks above tried to swallow still is. Asserted as
## found/not-found rather than as an expected string, because the blanked half is a
## run of \x01 that nobody could read in a diff.
check {Z0b and in the literal-BLANKED half a statement parked INSIDE a string\
 literal is unfindable, while all four live statements the hiding tricks tried to\
 swallow are still found} \
  [list [expr {[cfind {precision = clamp_prec_g(precision, sizeof(s));} $Z0ncs] < 0}] \
        [expr {[cfind {live1;} $Z0ncs] >= 0}] \
        [expr {[cfind {live2;} $Z0ncs] >= 0}] \
        [expr {[cfind {live3;} $Z0ncs] >= 0}] \
        [expr {[cfind {live4;} $Z0ncs] >= 0}] \
        [expr {[cfind {int b;} $Z0ncs] >= 0}] \
        [expr {[cfind {int z;} $Z0ncs] >= 0}]] \
  {1 1 1 1 1 1 1}

## ⚠ Z0c FENCES THE PUNCTUATION NORMALISER, AND IT IS THE ROW THE FOURTH ROUND OF
## SABOTAGE BOUGHT. `cs_ws` folds runs of whitespace but never inserts any, so before
## this normaliser every row matched a SPELLING: decoys M1 (`xctx->ev_precision=` with
## no spaces) and M2 (`sprintf (` with one space) are legal C, are inside what W4's and
## X1's names claimed, and left the whole suite at `ALL PASS (58 checks)`.
## Four clauses, and the last two are the safety conditions rather than the feature:
##   1-3  the three spellings of the writer, and the two of the sprintf, collapse to ONE
##        canonical string -- which is what makes the rows shape-matchers
##   4    A `,` INSIDE A STRING LITERAL DOES NOT MOVE. The decision is taken on the
##        BLANKED half, where a literal's punctuation is \x01, so `t("%s, %s", u, v)`
##        keeps the space inside the format and loses the ones outside it. Normalising
##        the intact half instead would cut the two halves at DIFFERENT indices.
##   5    the two halves are still the SAME LENGTH, which every index comparison in this
##        file (K3) and `cs_half` depend on
##   6    NORMALISATION HAS NOT MERGED TWO DISTINCT NEEDLES -- the four verbatim
##        exemption entries this file matches with `lsearch -exact` are still pairwise
##        distinct. A merge would silently widen an exemption, which is the one way this
##        normaliser could weaken a negative row rather than strengthen it.
set Z0clit [cs_collapse [ctok {t("%s, %s", u, v);}]]
set Z0cex [concat $X1exempt $X1sizeexempt $W4exemptn $W4cexemptn]
check {Z0c the punctuation normaliser makes whitespace around `= ( ) ,` and `->`\
 unable to change a match (decoys M1 and M2), leaves whitespace INSIDE a string literal\
 alone because it decides on the blanked half, keeps the two halves the same length,\
 and has not merged any two of this file's verbatim exemption entries} \
  [list [nrm {xctx->ev_precision = tclgetintvar("ev_precision");}] \
        [nrm {xctx->ev_precision=tclgetintvar("ev_precision");}] \
        [nrm {xctx -> ev_precision = tclgetintvar ( "ev_precision" ) ;}] \
        [nrm {sprintf (zb, "%.*g", p, zv);}] \
        [nrm {sprintf(zb, "%.*g", p, zv);}] \
        [cs_text $Z0clit] \
        [nrm {int a; int b;}] \
        [expr {[string length [lindex $Z0clit 0]] == [string length [lindex $Z0clit 1]]}] \
        [expr {[llength $Z0cex] == [llength [lsort -unique $Z0cex]] && [llength $Z0cex] >= 4}]] \
  [list {xctx->ev_precision=tclgetintvar("ev_precision");} \
        {xctx->ev_precision=tclgetintvar("ev_precision");} \
        {xctx->ev_precision=tclgetintvar("ev_precision");} \
        {sprintf(zb,"%.*g",p,zv);} \
        {sprintf(zb,"%.*g",p,zv);} \
        {t("%s, %s",u,v);} \
        {int a; int b;} 1 1]

## ⚠ Z3 FENCES THE PREPROCESSOR, on a synthetic snippet, with the SAME macro table
## the tree is read with. The table is MEASURED (./config.h plus the platform), and
## the row prints it, so a reddened Z3 says which build it was deciding for.
## Every clause is a condition this tree really contains at one of the four sites
## section Z2 covers, plus the two decoy shapes:
##   #if HAS_CAIRO==1 / #else               live / DEAD          draw(), 5 sites
##   #if HAS_CAIRO!=1                       DEAD                 draw()       (N5)
##   #ifndef __unix__ / #else                DEAD / live          draw()       (N4)
##   #if !defined(__unix__) && HAS_CAIRO==1  DEAD                 draw(), draw_graph()
##   #if 0 / #else                           DEAD / live          save.c read_raw_ascii_point
##   #if 1 / #else                           live / DEAD          draw_graph() (N6)
##   #if 0 && 1                              DEAD                              (V5)
##   #ifdef XSCHEM_NEVER                     UNDECIDABLE -> KEPT, and Z1/Z2 report it
##   a nested #if inside a dead region       DEAD                 issue 1607 row V27
##   #define                                 KEPT -- H5 reads one
set Z3lines [list \
  {#if HAS_CAIRO==1} {cairo_live;} {#else} {cairo_dead;} {#endif} \
  {#if HAS_CAIRO!=1} {nocairo_dead;} {#endif} \
  {#ifndef __unix__} {win_dead;} {#else} {unix_live;} {#endif} \
  {#if !defined(__unix__) && HAS_CAIRO==1} {both_dead;} {#endif} \
  {#if 0} {zero_dead;} {#else} {zero_else_live;} {#endif} \
  {#if 1} {one_live;} {#else} {one_else_dead;} {#endif} \
  {#if 0 && 1} {andzero_dead;} {#endif} \
  {#ifdef XSCHEM_NEVER} {undecided_kept;} {#endif} \
  {#if 0} {out1_dead;} {#ifdef NEST} {nest_dead;} {#endif} {out2_dead;} {#endif} \
  {#define KEPT_DEFINE 1} \
  {tail;}]
set Z3got [cs_text [cs_collapse [cstrip [join $Z3lines "\n"]]]]
set Z3want {cairo_live; unix_live; zero_else_live; one_live; undecided_kept; #define KEPT_DEFINE 1 tail;}
check_true {Z3 cs_pp keeps the branches that are LIVE on this build and drops the\
 ones that are dead -- walking `#else` and `#elif` -- while an UNDECIDABLE condition\
 leaves every branch in place for Z1/Z2 to report, and a `#define` survives because\
 H5 reads one} [expr {$Z3got eq $Z3want}] \
  "(measured macro table={$::PPMAC} defined-names=[llength $::PPDEF]\
 got={$Z3got} want={$Z3want})"

## Read the SAME files the rows read, but with every `#` line KEPT, because Z1 and
## Z2 are about the directives cs_pp resolves away.
set ZSRC [dict create]
foreach f {editprop.c draw.c callback.c save.c eval_expr.y} {
  dict set ZSRC $f [ccstrip [slurp [file join $repo src $f]]]
}
## Every function whose body a static row above reads, with the row(s) that read
## it, so a reader can see what Z1 is protecting.
set Z1funcs [list \
  editprop.c  clamp_prec_g            {H1 H2 H2b H3 H4} \
  editprop.c  dtoa_eng                {H6 K1 K2 K3} \
  draw.c      draw_cursor             {G1} \
  draw.c      draw_cursor_difference  {G2} \
  draw.c      draw_hcursor            {G3} \
  draw.c      draw_hcursor_difference {G4} \
  draw.c      graph_marker_fmt        {G6 G6b} \
  draw.c      graph_marker_text_rec   {G7} \
  save.c      nd_view_set             {G11} \
  eval_expr.y kklex                   {W3}]
## ⚠ EVERY `#` LINE, NOT JUST THE CONDITIONALS. It used to be
## `#(if|ifdef|ifndef|else|elif)`, and decoy N2 walked straight through the gap with
## `#define ZZ_CLAMP_IT precision = clamp_prec_g(precision, sizeof(s));` -- never
## invoked, so the clamp was gone from the binary, and K2 found its text. Measured
## 2026-09-25: these ten bodies contain ZERO `#` lines of ANY kind, so widening the
## invariant to every preprocessor line costs nothing and closes `#define`,
## `#undef`, `#pragma`, `#line` and `#include` at once. The `#` is required to be at
## a CODE position (the blanked half), so a `#` inside a string literal is not a
## false directive.
set Z1bad {} ; set Z1seen 0
foreach {f fn rows} $Z1funcs {
  set body [cfunc_raw [dict get $ZSRC $f] $fn]
  if {[cs_text $body] eq {ZZNOFUNC}} { lappend Z1bad [list $f $fn ZZNOFUNC] ; continue }
  incr Z1seen
  foreach bf [split [lindex $body 0] "\n"] bc [split [lindex $body 1] "\n"] {
    if {[regexp {^[ \t]*#} $bc]} { lappend Z1bad [list $f $fn rows $rows [string trim $bf]] }
  }
}
check {Z1 none of the ten function bodies the static rows read carries ANY\
 preprocessor line at all -- not a conditional and not a `#define` either -- so a\
 decoy parked in one is itself the failure, whatever it is named} \
  [list $Z1seen [llength $Z1bad] $Z1bad] {10 0 {}}

## ⚠ THE FOUR EXCLUSIONS, BY NAME AND WITH THEIR REAL DIRECTIVES, so Z1 stays an
## invariant instead of being quietly weakened:
##   draw_graph            (W1)          #if 0 / #if 1 / #if !defined(__unix__) && HAS_CAIRO==1
##   draw                  (W2)          #if HAS_CAIRO==1 / #if HAS_CAIRO!=1 / #ifndef __unix__ / #else
##   show_node_measures    (G5 G5b)      #if HAS_CAIRO == 1
##   waves_callback        (G8 G9 G10)   #if HAS_CAIRO==1
##
## ⚠ Z2 IS NO LONGER AN ALLOWLIST OF SPELLINGS, AND THE ALLOWLIST IS WHY THIS ROW
## HAD TO BE REBUILT. It used to hold the seven conditions the tree writes, and
## four of them are DEAD on this build -- so a decoy in a dead region satisfied its
## row while the live code did something else. Measured, all three reaching ALL PASS
## (51 checks): N4 put G5's asserted statement in an `#ifndef __unix__` inside
## show_node_measures -- where G5 is the ONLY fence, X1 being blind there because
## the formats are `char *` variables -- and left the live code reading
## `int prec = xctx->ev_precision;`. N5 did the same to G9 with `#if HAS_CAIRO!=1`,
## N6 with the `#else` of a `#if 1`.
##
## ⚠ AND THE SENTENCE THAT USED TO STAND HERE WAS FALSE, which is why it is quoted
## rather than deleted: *"An `#ifdef XSCHEM_NEVER` is not on the list, so the V3
## decoy reddens here too -- which is why W1, W2, G5, G5b, G8, G9 and G10 are not
## left unfenced by Z1's exclusions."* The first clause was true; the conclusion was
## measured FALSE by N4, N5 and N6, every one of which used a condition ON THAT VERY
## LIST. The fix is not a longer list: cs_pp now DROPS the dead branches, so those
## three decoys redden the rows they were hiding from, and Z2's job shrinks to the
## one question a list cannot answer -- can this suite DECIDE every condition in
## these four bodies? An undecidable one (`#ifdef XSCHEM_NEVER`) keeps its region,
## so it must be reported, and a non-conditional directive (N2's `#define`) has no
## business in one of these bodies at all.
set Z2funcs [list draw.c draw_graph {W1} draw.c draw {W2} \
                  draw.c show_node_measures {G5 G5b} \
                  callback.c waves_callback {G8 G9 G10}]
set Z2bad {} ; set Z2seen 0 ; set Z2decided 0
foreach {f fn rows} $Z2funcs {
  set body [cfunc_raw [dict get $ZSRC $f] $fn]
  if {[cs_text $body] eq {ZZNOFUNC}} { lappend Z2bad [list $f $fn ZZNOFUNC] ; continue }
  incr Z2seen
  foreach bf [split [lindex $body 0] "\n"] bc [split [lindex $body 1] "\n"] {
    if {![regexp {^[ \t]*#} $bc]} { continue }
    if {![regexp {^[ \t]*#[ \t]*(ifdef|ifndef|if|elif|else|endif)([ \t]|$)} $bc . kw]} {
      lappend Z2bad [list $f $fn rows $rows NOT-A-CONDITIONAL [collapse $bf]] ; continue
    }
    if {$kw eq {else} || $kw eq {endif}} { incr Z2decided ; continue }
    if {[pp_eval [pp_cond $bf $kw]] eq {U}} {
      lappend Z2bad [list $f $fn rows $rows UNDECIDABLE [collapse $bf]]
    } else { incr Z2decided }
  }
}
check {Z2 ... and in the four functions Z1 excludes, every preprocessor line is a\
 conditional whose condition cs_pp DECIDES on this build, so no row there can be\
 satisfied from a region the compiler throws away and an undecidable condition is\
 named here instead of guessed at} \
  [list $Z2seen [llength $Z2bad] $Z2bad] {4 0 {}}

## ⚠ Z4 IS THE ANTI-VACUITY ROW FOR ALL OF THE ABOVE: it proves cs_pp is actually
## WIRED INTO what W1, W2, G5, G5b and G8-G10 read, and not merely defined. draw()
## carries a dead `#if HAS_CAIRO!=1`, a dead `#ifndef __unix__` nested inside a live
## `#if HAS_CAIRO==1`, and a dead `#if !defined(__unix__) && HAS_CAIRO==1`; it also
## carries a live `#if HAS_CAIRO==1` whose `#else` is dead. The last clause reads
## the SAME statement out of the regions-kept text, so "absent" cannot mean "the
## statement was never in the file".
set Z4live [cfunc $C_DRAW draw]
set Z4keep [cfunc [dict get $ZSRC draw.c] draw]
check {Z4 and the dead branches really are gone from the text the rows read:\
 draw()'s `#if HAS_CAIRO!=1`, `#ifndef __unix__` and\
 `#if !defined(__unix__) && HAS_CAIRO==1` bodies are absent from it and the `#else`\
 of its live `#if HAS_CAIRO==1` is too, while that `#if`'s own body is present and\
 the regions-KEPT text still has all of them} \
  [list [expr {[cfind {drawrect(textlayer, END, 0.0, 0.0, 0.0, 0.0, 0.0, 0, -1, -1);} $Z4live] < 0}] \
        [expr {[cfind {clear_cairo_surface(xctx->cairo_save_ctx,} $Z4live] < 0}] \
        [expr {[cfind {my_cairo_fill(xctx->cairo_sfc,} $Z4live] < 0}] \
        [expr {[cfind {if(c != GRIDLAYER || !(r->flags & 1) )} $Z4live] < 0}] \
        [expr {[cfind {if(c != GRIDLAYER || !(r->flags & (1 + 1024)))} $Z4live] >= 0}] \
        [expr {[cfind {drawrect(textlayer, END, 0.0, 0.0, 0.0, 0.0, 0.0, 0, -1, -1);} $Z4keep] >= 0}] \
        [expr {[cfind {clear_cairo_surface(xctx->cairo_save_ctx,} $Z4keep] >= 0}] \
        [expr {[cfind {my_cairo_fill(xctx->cairo_sfc,} $Z4keep] >= 0}] \
        [expr {[cfind {if(c != GRIDLAYER || !(r->flags & 1) )} $Z4keep] >= 0}]] \
  {1 1 1 1 1 1 1 1 1}

# ===========================================================================
# SECTION Y -- THE COMPILER'S OWN OPINION
#
# ⚠ THIS IS THE ONLY FENCE IN THIS FILE THAT NO DECOY CAN TALK ROUND, AND IT IS
# HERE BECAUSE GCC FOUND A REAL DEFECT THIS SUITE'S 51 ROWS DID NOT. The first
# landing of the 1606 fix compiled with exactly one new warning, absent at
# 34913077:
#
#   editprop.c:231:11: warning: '__builtin___sprintf_chk' may write a terminating
#   nul past the end of the destination [-Wformat-overflow=]
#     231 |       n = sprintf(s, "%.*gMEG", precision, i);
#   .../stdio2.h:30:10: note: '__builtin___sprintf_chk' output between 5 and 82
#   bytes into a destination of size 80
#
# and gcc was RIGHT: "%.*gMEG" is prec+10 chars, prec+11 bytes with the NUL, and
# the one clamp above the branch yields 71, so 82 > 80. Every sweep this batch ran
# missed it because that arm divides by 1e6 first and its output is pinned near 59
# characters at any precision. A VALUE RANGE IS NOT A BOUND. K3 now fences the
# second, tighter clamp; this section fences the property that found it.
#
# TWO ROWS, BECAUSE THE TWO LEVELS SEE DIFFERENT THINGS -- both measured 2026-09-25:
#
#  Y1a  editprop.c at -Wformat-overflow=2 -Wformat-truncation=2. Here the clamp and
#       the three conversions are in the SAME translation unit, so gcc can bound the
#       precision itself. ⚠ THAT MAKES Y1a THE ONE FENCE IN THIS FILE THAT CATCHES A
#       CLAMP WHOSE RESULT NEVER REACHES THE CONVERSION -- decoys N1 (`if(0)` in
#       front of the real statement), N2 (a `#define` nobody invokes) and N3 (the
#       statement inside a string literal) all leave dtoa_eng's precision unbounded,
#       and gcc then says `'%.*g' directive writing between 1 and 310 bytes into a
#       region of size 80` TWICE -- not three times: the "%.*gMEG" arm carries its own
#       clamp now, so two of the three conversions are unbounded, and the Y1a proof
#       line in receipts/C3-close.md prints `{2 {...}}`. ⚠ AND ONLY N1 IS CAUGHT HERE
#       AND NOWHERE ELSE: N2 also reddens Z1, N3 also reddens K2 and K3 (measured,
#       receipts/C3v-final.md §4.6). N1 is the one no static row in this file can see
#       (see NAMED LIMITS at the top), and it is exposed at exactly ONE of the
#       fourteen clamp sites -- see limit 1.
#  Y1c  THE ANTI-VACUITY ROW FOR BOTH OF THEM, and they had none until this round.
#       They take their flags from Makefile.conf, which ./configure GENERATES and
#       which accepts user CFLAGS: a `-w` anywhere in that line silenced both AND the
#       only fence N1 has, and the suite stayed green (measured, §5.4 of
#       receipts/C3v-final.md, both with `-w` prepended and with it appended after an
#       explicit `-Wformat-overflow=2`). Y1c compiles a synthetic snippet that MUST
#       warn, at both flag sets, and requires the diagnostic.
#  Y1b  all four files that carry an indirect-precision sprintf, at the BUILD'S OWN
#       flags out of Makefile.conf and nothing added. This is the row that would have
#       caught the MEG arm: it is the diagnostic a plain `make -C src` prints, and
#       this repo reads `make` output.
#
# ⚠ AND THE MEASURED LIMIT, SO NOBODY PROMOTES Y1b TO LEVEL 2: at
# -Wformat-overflow=2 the OTHER three files each report `'%.*g' directive writing
# between 1 and 310 bytes into a region of size 100` at their clamped sites, because
# clamp_prec_g is defined in editprop.c and gcc cannot see its return range across
# translation units. Those are not defects and not suppressible without -flto (which
# was NOT driven here). So level 2 is scoped to editprop.c by measurement, not by
# taste, and the other three get the level the build itself uses.
# ===========================================================================
## ⚠ TAKES A SOURCE DIRECTORY, NOT THE REPO ROOT, because Y1c compiles a SYNTHETIC
## file out of the scratch dir with the same compiler and the same flags. That is the
## only difference from the version that shipped with receipts/C3-close.md.
proc ycompile {cc cflags extra files srcdir ydir tag} {
  set cmd {}
  foreach f $files {
    append cmd "$cc $cflags $extra -c -o [file join $ydir $tag.$f.o]\
 [file join $srcdir $f] 2> [file join $ydir $tag.$f.log] & "
  }
  append cmd "wait"
  catch {exec sh -c $cmd}
  set bad {} ; set missing {}
  foreach f $files {
    if {![file exists [file join $ydir $tag.$f.o]]} { lappend missing $f ; continue }
    foreach l [split [slurp [file join $ydir $tag.$f.log]] "\n"] {
      if {[string first {-Wformat-overflow} $l] >= 0 \
          || [string first {-Wformat-truncation} $l] >= 0} {
        lappend bad "$f: [string trim $l]"
      }
    }
  }
  return [list $bad $missing]
}
set YCC [lindex [auto_execok gcc] 0]
set YMK [file join $repo Makefile.conf]
set YCFLAGS ZZNONE
if {[file exists $YMK]} {
  foreach l [split [slurp $YMK] "\n"] {
    if {[regexp {^CFLAGS=(.*)$} $l . v]} { set YCFLAGS $v }
  }
}
if {$YCC eq {} || $YCFLAGS eq {ZZNONE}} {
  ## Lowercase, and the reason must not end in FAIL/GOLD?/RESULT? nor start with
  ## FATAL -- summarize_all tests those shapes first, wherever they appear.
  puts "skip: Y1a Y1b Y1c -- no gcc on PATH ([string length $YCC] chars) or no CFLAGS\
 line in Makefile.conf, so the compiler's own -Wformat-overflow/-Wformat-truncation\
 opinion could not be taken; K3 and G1-G11 fence the same clamps by name on either\
 arm, and a plain `make -C src` prints the same diagnostic"
  flush stdout
} else {
  set ydir [file join $dir ydiag] ; file mkdir $ydir
  set YEXTRA {-Wformat -Wformat-overflow=2 -Wformat-truncation=2}
  set YSRC [file join $repo src]

  ## ⚠ Y1c FIRST, BECAUSE IT IS WHAT MAKES THE OTHER TWO MEAN ANYTHING. X1 has X2 and
  ## `cs_pp` has Z4; Y1a and Y1b had NOTHING, and they are the two rows in this file
  ## that read their flags out of a GENERATED, gitignored file (`Makefile.conf`, written
  ## by ./configure, which accepts user CFLAGS). MEASURED (receipts/C3v-final.md §5.4) on
  ## the N1-sabotaged editprop.c: level 2 with no `-w` reports 2 diagnostics; with `-w`
  ## PREPENDED to CFLAGS, 0; with `-w` APPENDED after an explicit `-Wformat-overflow=2`,
  ## also 0 -- gcc accepts the later explicit flag and still says nothing, so "the
  ## explicit flag wins" is not a defence. A single `-w` in that line therefore silenced
  ## both rows AND the only fence this file has for decoy N1, and the suite stayed green.
  ## So: compile a snippet that MUST warn, at BOTH flag sets, and require the diagnostic.
  ## `%s` and not `%.*g`, so this row cannot be satisfied or broken by anything to do with
  ## the precision clamps it is fencing; the destination is four bytes and the argument is
  ## ten, which is a static overflow gcc reports at -Wformat-overflow=1 -- the level the
  ## build's own flags already give through the fortified `__builtin___sprintf_chk`.
  set ysyn [file join $ydir zz_must_warn.c]
  set fd [open $ysyn w]
  puts $fd "#include <stdio.h>"
  puts $fd "void zz_must_warn(void);"
  puts $fd "void zz_must_warn(void)"
  puts $fd "{"
  puts $fd "  char b\[4\];"
  puts $fd "  sprintf(b, \"%s\", \"0123456789\");"
  puts $fd "}"
  close $fd
  set Y1c2 [ycompile $YCC $YCFLAGS $YEXTRA {zz_must_warn.c} $ydir $ydir syn2]
  set Y1c1 [ycompile $YCC $YCFLAGS {} {zz_must_warn.c} $ydir $ydir syn1]
  check_true {Y1c the compile Y1a and Y1b take their opinion from can actually EMIT a\
 -Wformat-overflow diagnostic, at BOTH flag sets -- a synthetic sprintf of 10 bytes into\
 a 4-byte buffer is reported -- so a `-w` anywhere in the generated Makefile.conf's\
 CFLAGS reddens this row instead of making Y1a and Y1b pass on a tree with no clamp} \
    [expr {[llength [lindex $Y1c2 0]] >= 1 && [llength [lindex $Y1c1 0]] >= 1
           && [lindex $Y1c2 1] eq {} && [lindex $Y1c1 1] eq {}}] \
    "(level2=[llength [lindex $Y1c2 0]] diagnostics build-flags=[llength [lindex $Y1c1 0]]\
 missing2={[lindex $Y1c2 1]} missing1={[lindex $Y1c1 1]} cflags={$YCFLAGS}\
 l2={[lindex $Y1c2 0]} bld={[lindex $Y1c1 0]})"

  set Y1a [ycompile $YCC $YCFLAGS $YEXTRA {editprop.c} $YSRC $ydir l2]
  ## ⚠ THE EXCLUSIVITY CLAUSE IS N1's ALONE, AND THE PREVIOUS REVISION OF THIS NAME
  ## CLAIMED IT FOR ALL THREE. Measured (receipts/C3v-final.md §4.6): N2, the `#define`
  ## nobody invokes, also reddens Z1; N3, the statement inside a string literal, also
  ## reddens K2 and K3. Only N1 -- `if(0)` in front of the real statement, which uses no
  ## preprocessor and no literal and sits at a true statement position -- is caught here
  ## and nowhere else, which is exactly what NAMED LIMIT 1 says.
  check {Y1a src/editprop.c compiles with ZERO -Wformat-overflow/-Wformat-truncation\
 diagnostics at level 2, where gcc can see clamp_prec_g's own return range -- so a\
 clamp whose result never reaches the conversion is caught here (N1 here and NOWHERE\
 else in this file; N2 also reddens Z1, N3 also reddens K2 and K3)} \
    [list [llength [lindex $Y1a 0]] [lindex $Y1a 0] [lindex $Y1a 1]] {0 {} {}}

  set Y1b [ycompile $YCC $YCFLAGS {} \
             {editprop.c draw.c callback.c save.c} $YSRC $ydir bld]
  check {Y1b and all four files that carry an indirect-precision sprintf compile with\
 ZERO such diagnostics at the BUILD'S OWN flags from Makefile.conf -- the warning a\
 plain `make -C src` prints, which is how the MEG arm's violated bound was found} \
    [list [llength [lindex $Y1b 0]] [lindex $Y1b 0] [lindex $Y1b 1]] {0 {} {}}
}

# ===========================================================================
# SECTION B -- BEHAVIOURAL, BOTH ARMS
#
# ⚠ EVERY ROW IN THIS SECTION SHARES ONE LIMIT, AND EACH COMMENT REPEATS IT:
# the clamps on these paths are REDUNDANT (a writer clamp plus a use-site clamp),
# so a row here reddens only when EVERY clamp on its path is gone. The per-clamp
# fences are the static rows above. Measured during this batch: with either the
# kklex() clamp or the dtoa_eng clamp alone present, removing the other leaves
# B1 green, because the survivor produces the same 71-digit string.
#
# Each row asserts BOTH the child's exit code AND the absence of a column-0
# `FATAL: signal` marker: xschem traps some signals itself, and rc alone would
# read a death as "an empty answer".
#
# ⚠ AND `death=0` IN A FAILING DETAIL DOES NOT MEAN THE CHILD WAS FINE.
# `death` is a column-0 `FATAL: signal` line, which main.c's sig_handler prints
# for the signals it traps -- and it does NOT trap SIGABRT. THE 1606 DEFECT IS A
# glibc _FORTIFY_SOURCE SIGABRT, so no `FATAL:` line is ever printed for it: every
# reddened row in the independent sabotage reported `death=0` while the child had
# really aborted with rc 134. The clause is correct but PERMANENTLY INERT for this
# defect class; it is insurance against a DIFFERENT death (a trapped SIGSEGV, say)
# and never a second opinion on this one. The rc is the signal here, which is why
# B0/B0b exist: read the `rc=` field, not `death=`.
# ===========================================================================
## THE REAL EXIT STATUS, not a collapsed 1 -- the repair the independent sabotage
## asked for (§3.3 of receipts/Cv-sabotage.md). `child` used to `set rc 1` for any
## failure, so rc 134 (this issue's SIGABRT), rc 124 (its own `timeout 90`) and rc
## 1 (a Tcl error in the fixture) all printed the same `(rc=1 ...)` and no row
## could tell a defect from a broken fixture.
##
## MEASURED, both arms, 2026-09-25 (an abort() stub under the same spellings):
##   nogui arm    `exec env -u DISPLAY timeout 90 xschem ...`
##                -> errorCode {CHILDKILLED <pid> SIGABRT SIGABRT}, because GNU
##                   timeout re-raises the child's terminating signal to itself
##                   and Tcl's direct child IS timeout (env exec'd over itself).
##   display arm  `exec devdisplay.sh exec timeout 90 xschem ...`
##                -> errorCode {CHILDSTATUS <pid> 134}, because cmd_exec runs the
##                   command as bash's LAST command and bash exits 128+6 for it.
## So both paths have to be decoded, and 134 comes out of each.
array set ::SIGNUM {SIGINT 2 SIGQUIT 3 SIGILL 4 SIGABRT 6 SIGBUS 7 SIGFPE 8 \
                    SIGKILL 9 SIGSEGV 11 SIGPIPE 13 SIGTERM 15}
proc child_rc {ec} {
  switch -exact -- [lindex $ec 0] {
    CHILDSTATUS { return [lindex $ec 2] }
    CHILDKILLED {
      set s [lindex $ec 2]
      if {[info exists ::SIGNUM($s)]} { return [expr {128 + $::SIGNUM($s)}] }
      return 128
    }
  }
  return -1
}
## What a non-zero rc MEANS, spelled out in the failing line so nobody has to come
## back here. Never ends in FAIL/GOLD?/RESULT? and never starts with FATAL.
proc rcwhy {rc} {
  switch -exact -- $rc {
    0   { return 0 }
    134 { return {134/SIGABRT-the-1606-overflow} }
    139 { return {139/SIGSEGV-a-different-crash} }
    124 { return {124/TIMEOUT-of-the-suite-own-90s} }
    1   { return {1/Tcl-error-in-the-FIXTURE-not-an-overflow} }
    -1  { return {-1/exec-never-started-the-child} }
  }
  return $rc
}
## Spawn a child xschem running `body`. SPAWNED, NOT IN-PROCESS: the defect is a
## SIGABRT, which in-process would take this suite's own interpreter down and turn
## a named FAIL into a dead suite with no verdict at all.
## `arm`: `nogui` is `--nogui` with no display; `display` routes through
## tests/headless/devdisplay.sh exec, which pins DISPLAY=:99 and GUI_GATE=0 so
## this file can stay in `hcases`.
## ⚠ THE `timeout` GOES INSIDE `devdisplay.sh exec`, NOT AROUND IT: devdisplay.sh
## runs the command as a child rather than exec'ing over itself, so a timeout
## wrapped around the wrapper would kill the wrapper and leave xschem alive on
## :99 with nobody waiting on it.
proc child {tag body {arm nogui}} {
  set t [file join $::dir $tag.tcl]
  set fd [open $t w]
  puts $fd "set netlist_dir {$::dir}"
  foreach l $body { puts $fd $l }
  puts $fd "puts CHILD_DONE" ; puts $fd "flush stdout" ; puts $fd "exit 0"
  close $fd
  set save [pwd] ; cd $::dir
  set rc 0 ; set out ""
  if {$arm eq {display}} {
    set dd [file join $::repo tests headless devdisplay.sh]
    if {[catch {exec $dd exec timeout 90 [info nameofexecutable] \
                --pipe -q --script $t 2>@1} out]} { set rc [child_rc $::errorCode] }
  } else {
    if {[catch {exec env -u DISPLAY timeout 90 [info nameofexecutable] \
                --nogui --pipe -q --script $t 2>@1} out]} { set rc [child_rc $::errorCode] }
  }
  cd $save
  return [list $rc [regexp {(?n)^FATAL: signal} $out] $out]
}
proc kv {out name} {
  if {[regexp -- "(?:^|\n)$name=<(\[^>\]*)>" $out . v]} { return $v }
  return <<absent>>
}
proc done {out} { return [regexp {(?n)^CHILD_DONE$} $out] }
## Significant digits in a %g string: the mantissa's digits, with the decimal
## point and the exponent removed. This is what makes a row assert the CLAMP
## rather than merely "it did not abort" -- at ev_precision 200 a correct tree
## prints exactly DTOA_ENG_BUFSIZE - 9 == 71 of them.
proc sigdigits {s} {
  regsub {[eE][-+]?[0-9]+.*$} $s {} m
  regsub -all {[^0-9]} $m {} d
  return [string length $d]
}

## THE GRAPH FIXTURE. Two things about it are load-bearing.
##  * unitx/unity MUST be non-1.0, or every "%.*g" arm in draw.c and callback.c is
##    skipped for the `dtoa_eng(..., 5)` else-arm, which takes a HARDCODED 5 and
##    was never the defect.
##  * the VALUE must have many EXACT decimal digits, not merely be large. %g
##    strips trailing zeros, so 1e15 prints as 1000000000000000 at any precision.
##    The double nearest 1e300 is an exact integer with ~289 significant digits,
##    which is why this sweep reproduces and a 0..1 sweep does not.
set GFIX [list \
  {xschem raw new f.raw dc vsweep 0 1 0.1} \
  {xschem raw add v_big {vsweep 1e300 *}} \
  {xschem set rectcolor 2} \
  "xschem rect 0 0 800 400 -1 \{flags=graph\nnode=v_big\nunitx=T\nunity=T\nx1=0\nx2=1\ny1=-1e300\ny2=1e300\} 0" \
  {xschem zoom_full} \
  {xschem redraw}]

# --- B0/B0b: the harness's own exit-status decode --------------------------
## ⚠ THE DECODE IS ITSELF A GUARD, SO IT GETS A ROW. Every rule in this repo's
## crew brief about fencing applies to the test harness too: if `child_rc` is ever
## collapsed back to `set rc 1`, every behavioural row below keeps passing on a
## correct tree and every FAILURE stops naming what happened. B0 is a unit check
## of the decode table on the four errorCode shapes measured above; B0b proves the
## decode is actually WIRED INTO `child` by spawning a real child that exits 134.
check {B0 child_rc decodes the four errorCode shapes a spawned child can produce\
 -- a signal death (SIGABRT), a plain non-zero exit, a timeout, and an exec that\
 never started -- instead of collapsing them all to 1} \
  [list [child_rc {CHILDKILLED 123 SIGABRT SIGABRT}] \
        [child_rc {CHILDSTATUS 123 134}] \
        [child_rc {CHILDSTATUS 123 124}] \
        [child_rc {CHILDSTATUS 123 1}] \
        [child_rc {CHILDKILLED 123 SIGSEGV SIGSEGV}] \
        [child_rc {POSIX ENOENT {no such file or directory}}]] \
  {134 134 124 1 139 -1}

## The plumbing, not the table: a real spawned child, on the arm every B row uses.
## `exit 134` runs before `child`'s appended `exit 0`, so CHILD_DONE is absent too.
set b0 [child b0 [list {puts "Z=<alive>"} {flush stdout} {exit 134}]]
lassign $b0 b0rc b0death b0out
check_true "B0b ... and `child` really returns it: a spawned child that exits 134\
 is reported as 134, so a reddened row below names the SIGABRT instead of a 1" \
  [expr {$b0rc == 134 && !$b0death && ![done $b0out] && [kv $b0out Z] eq {alive}}] \
  "(rc=[rcwhy $b0rc] death=$b0death z=[kv $b0out Z] done=[done $b0out])"

# --- B1: the reproducer from the issue -------------------------------------
## Reddens only when the kklex() clamp AND the dtoa_eng clamp are both gone
## (W3 and K2 fence them individually). Before the fix this was rc 134.
set b1 [child b1 [list {set ::ev_precision 200} \
  {puts "R=<[xschem eval_expr {expr_eng(1e300*1.0)}]>"}]]
lassign $b1 b1rc b1death b1out
check_true "B1 the issue's own reproducer SURVIVES at ev_precision 200 and prints\
 exactly 71 significant digits (DTOA_ENG_BUFSIZE - 9); this was\
 *** buffer overflow detected ***, SIGABRT, rc 134" \
  [expr {$b1rc == 0 && !$b1death && [done $b1out]
         && [sigdigits [kv $b1out R]] == 71}] \
  "(rc=[rcwhy $b1rc] death=$b1death digits=[sigdigits [kv $b1out R]] r=[kv $b1out R])"

# --- B2: the negative case, which is the byte the arithmetic is built on ----
## ⚠ WRITE THE NEGATION AS `-1.0*v`. In this evaluator `(0.0-1.0)*v` returns 0,
## which would make this row measure a short string and pass for the wrong reason.
## 71 digits + sign + point + "e+288" + suffix = 79 bytes, so the 80-byte buffer
## is EXACTLY full: this is the case the cap - 9 arithmetic is chosen for.
set b2 [child b2 [list {set ::ev_precision 200} \
  {puts "R=<[xschem eval_expr {expr_eng(-1.0*1e300)}]>"}]]
lassign $b2 b2rc b2death b2out
check_true "B2 the NEGATIVE worst case fills dtoa_eng's 80-byte buffer exactly (79\
 bytes + NUL) and survives" \
  [expr {$b2rc == 0 && !$b2death && [done $b2out]
         && [sigdigits [kv $b2out R]] == 71
         && [string length [kv $b2out R]] == 79
         && [string index [kv $b2out R] 0] eq {-}}] \
  "(rc=[rcwhy $b2rc] death=$b2death len=[string length [kv $b2out R]]\
 digits=[sigdigits [kv $b2out R]])"

# --- B3: a sweep across the OLD abort threshold ----------------------------
## 71 and 72 survived before the fix; 73 was the abort. The sweep goes well past
## it so a clamp that merely moved the ceiling would still redden here.
set b3 [child b3 [list \
  {foreach p {4 71 72 73 200 4000} {
     set ::ev_precision $p
     set r [xschem eval_expr {expr_eng(1e300*1.0)}]
     puts "P${p}=<[string length $r]>"
   }}]]
lassign $b3 b3rc b3death b3out
check_true "B3 a precision sweep of 4 71 72 73 200 4000 all survive, and every one\
 at or above 71 produces the same 78-byte string -- 73 was the abort, and 4000 shows\
 the clamp is a ceiling and not a shifted threshold" \
  [expr {$b3rc == 0 && !$b3death && [done $b3out]
         && [kv $b3out P4] eq {7} && [kv $b3out P71] eq {78}
         && [kv $b3out P72] eq {78} && [kv $b3out P73] eq {78}
         && [kv $b3out P200] eq {78} && [kv $b3out P4000] eq {78}}] \
  "(rc=[rcwhy $b3rc] death=$b3death p4=[kv $b3out P4] p71=[kv $b3out P71]\
 p73=[kv $b3out P73] p4000=[kv $b3out P4000])"

# --- B4: the token.c door --------------------------------------------------
## @spice_get_node is one of seven token.c sites that hand xctx->ev_precision to
## dtoa_eng. Reddens only when the draw() writer clamp AND the dtoa_eng clamp are
## both gone (W2 and K2 fence them individually).
set b4 [child b4 [concat [list {set ::ev_precision 200}] $GFIX [list \
  {xschem cursor 2 1} {xschem set cursor2_x 1.0} \
  {puts "T=<[xschem translate -1 {@spice_get_node v_big}]>"}]]]
lassign $b4 b4rc b4death b4out
check_true "B4 token.c's @spice_get_node translation SURVIVES at ev_precision 200\
 and prints exactly 71 significant digits; this was rc 134 at 73" \
  [expr {$b4rc == 0 && !$b4death && [done $b4out]
         && [sigdigits [kv $b4out T]] == 71}] \
  "(rc=[rcwhy $b4rc] death=$b4death digits=[sigdigits [kv $b4out T]] t=[kv $b4out T])"

# --- B5: the save.c nd_view_set door --------------------------------------
## Place a cursor and READ THE ANNOTATION -- no export, no display, no eval_expr.
## This is the door the file-borne reproducer reaches during ordinary editor work
## on a fixture the poisoned file never mentions.
## ⚠ nd_view_set's OWN clamp is defence in depth here and this row cannot isolate
## it: nd_view.prec is xctx->ev_precision, already capped at 71 by the writers, so
## the 91 this site would allow is unreachable. G11 is its fence.
set b5 [child b5 [concat [list {set ::ev_precision 200}] $GFIX [list \
  {xschem cursor 2 1} {xschem set cursor2_x 1.0} \
  {puts "V=<$::ngspice::ngspice_data(v_big)>"}]]]
lassign $b5 b5rc b5death b5out
check_true "B5 reading the cursor-B annotation (save.c nd_view_set) SURVIVES at\
 ev_precision 200 and prints exactly 71 significant digits" \
  [expr {$b5rc == 0 && !$b5death && [done $b5out]
         && [sigdigits [kv $b5out V]] == 71}] \
  "(rc=[rcwhy $b5rc] death=$b5death digits=[sigdigits [kv $b5out V]] v=[kv $b5out V])"

# --- B6: the graph-marker readout -----------------------------------------
## ⚠ THIS ROW FENCES THE 17, NOT graph_marker_fmt's CLAMP, AND THE DIFFERENCE
## MATTERS. graph_marker_text_rec reads ev_precision itself, so no writer clamp
## reaches it; the caller then caps at 17. Raise or delete that 17 and this row
## reddens (the readout jumps to 71 digits). Remove graph_marker_fmt's clamp ALONE
## and it stays green, because 17 digits fit in 80 bytes -- G6 is that clamp's
## fence. Remove both and the child aborts, which this row also catches.
## ⚠ AND ONE MEASURED LIMIT, SO NOBODY OVERSTATES THIS ROW: raising the cap from
## 17 to 18 does NOT redden it. `%g` STRIPS TRAILING ZEROS, and the 18th digit of
## this x value is a zero, so `%.18g` and `%.17g` print the same string. It reddens
## from a substantial raise (measured at 200: 71 digits). The EXACT value 17 is
## fenced by G7, which is why both rows exist.
set b6 [child b6 [concat [list {set ::ev_precision 200}] $GFIX [list \
  {set n [xschem graph_marker add_at 0 0 0 10]} \
  {puts "N=<$n>"} \
  {set mt [xschem graph_marker text $n]} \
  {puts "M=<$mt>"} \
  {puts "MX=<[lindex [split [string range $mt [expr {[string first : $mt] + 1}] end] ,] 0]>"}]]]
lassign $b6 b6rc b6death b6out
check_true "B6 the graph-marker callout SURVIVES at ev_precision 200 and shows 17\
 significant digits -- the DISPLAY cap in graph_marker_text_rec, which is the only\
 thing between ev_precision and graph_marker_fmt's 80-byte buffers" \
  [expr {$b6rc == 0 && !$b6death && [done $b6out] && [kv $b6out N] eq {1}
         && [sigdigits [kv $b6out MX]] == 17}] \
  "(rc=[rcwhy $b6rc] death=$b6death n=[kv $b6out N] digits=[sigdigits [kv $b6out MX]]\
 mx=[kv $b6out MX] m=[kv $b6out M])"

# --- B7: the FILE-BORNE door ----------------------------------------------
## ⚠ THE ROW THAT SAYS WHAT THIS ISSUE ACTUALLY IS. The .sch below does nothing
## but set ev_precision; everything after the load is ordinary editor work on a
## fixture the file never mentions. Headless this needs the `xschem print svg`,
## because the floater is evaluated by a DRAW -- on a display the load alone does
## it, and two traces in this batch's receipts disagreed only because neither
## named its arm.
## ⚠ USE `"` NOT `{}` INSIDE `tcleval(`: braces break both the T record parse and
## tclpropeval2's own `subst {...}`.
## ⚠ AND THIS ROW IS NOT A SECURITY FENCE. The same mechanism runs arbitrary Tcl
## at global level; ev_precision is merely one thing it can reach. All this row
## shows is that the OVERFLOW is gone.
set b7sch [file join $dir poison.sch]
set fd [open $b7sch w]
foreach l [list {v {xschem version=3.4.8RC file_version=1.3}} {G {}} {K {}} {V {}} \
                {S {}} {F {}} {E {}} \
                {T {tcleval([set ::ev_precision 200]POISONED)} 0 0 0 0 0.4 0.4 {floater=true}}] {
  puts $fd $l
}
close $fd
set b7 [child b7 [list \
  {puts "BEFORE=<$::ev_precision>"} \
  "xschem load [file join $dir poison.sch]" \
  "xschem print svg [file join $dir poison.svg]" \
  {puts "AFTER=<$::ev_precision>"} \
  {puts "R=<[xschem eval_expr {expr_eng(1e300*1.0)}]>"}]]
lassign $b7 b7rc b7death b7out
check_true "B7 a .sch that does nothing but `set ::ev_precision 200` in a floater\
 still poisons ev_precision on open+export (4 -> 200), and the ORDINARY work that\
 follows now survives with 71 significant digits instead of aborting" \
  [expr {$b7rc == 0 && !$b7death && [done $b7out]
         && [kv $b7out BEFORE] eq {4} && [kv $b7out AFTER] eq {200}
         && [sigdigits [kv $b7out R]] == 71}] \
  "(rc=[rcwhy $b7rc] death=$b7death before=[kv $b7out BEFORE] after=[kv $b7out AFTER]\
 digits=[sigdigits [kv $b7out R]])"

# ===========================================================================
# SECTION D -- BEHAVIOURAL, DISPLAY ARM ONLY
#
# The four draw.c cursor readouts and the callback.c measurement tooltip are
# reached only by a real draw of a real graph on a real display. Headless,
# `xschem print svg` strips the cursor chrome and never formats them (driven at
# 4, 92, 93 and 200 during this batch: rc 0 every time, and the SVG carries no
# cursor), and `xschem callback .drw ...` needs a Tk widget that does not exist
# under --nogui.
#
# ⚠ WITH NO DEV DISPLAY THIS WHOLE SECTION SELF-SKIPS with ONE lowercase `skip:`
# line, which T1's summarize_all collects into the verdict's `skips=` count
# (issue 1487) -- a coverage figure, not a failure. Which is why the reason text
# must not end in the words FAIL, GOLD? or RESULT?, and must not start with
# FATAL: summarize_all tests those shapes FIRST. G1-G4 and G8-G10 are the static
# halves and run on BOTH arms, so nothing here is unfenced when this skips.
# ===========================================================================
## The tooltip fixture, parameterised: `attrs` picks which axis units exist and
## `scale` picks the y magnitude, because D3/D4 turn on the DIFFERENCE between the
## unit-scaled sprintf arm and dtoa_eng's own engineering suffix.
proc d_probe_body {attrs scale y2} {
  return [list \
    {xschem raw new f.raw dc vsweep 0 1 0.1} \
    "xschem raw add v_a \{vsweep $scale *\}" \
    {xschem set rectcolor 2} \
    "xschem rect 0 0 800 400 -1 \{flags=graph\nnode=v_a\n$attrs\nx1=0\nx2=1\ny1=0\ny2=$y2\} 0" \
    {xschem zoom_full} \
    {xschem redraw} \
    {set z [xschem get zoom] ; set xo [xschem get xorigin] ; set yo [xschem get yorigin]} \
    {set px [expr {int((400 + $xo)/$z)}] ; set py [expr {int((200 + $yo)/$z)}]} \
    {xschem callback .drw 2 $px $py 77 0 0 0} \
    {xschem callback .drw 6 $px $py 0 0 0 0} \
    {puts "HASX=<[info exists has_x]>"} \
    {regsub -all "\n" $::measure_text { | } __mt ; puts "MT=<$__mt>"}]
}

set ddsh [file join $repo tests headless devdisplay.sh]
if {[catch {exec $ddsh status 2>@1} ddout]} {
  puts "skip: D1 D2 D3 D4 -- tests/headless/devdisplay.sh status does not report the\
 persistent dev display alive, so the four draw.c cursor readouts and the callback.c\
 measurement tooltip did not run; bring it up with tests/headless/devdisplay.sh start.\
 G1-G4 and G8-G10 fence the same clamps statically on either arm"
  flush stdout
} else {

# --- D1: the four draw.c cursor readouts, via a real draw -----------------
## Both cursors on, both units non-1.0, a value with ~289 exact digits: this draw
## runs draw_cursor, draw_cursor_difference, draw_hcursor and
## draw_hcursor_difference. There is no read-back seam for what they formatted
## (`xschem globals` does not print ev_precision either), so the assertion is
## survival: rc 0 and no column-0 FATAL marker.
## ⚠ ITS LIMIT: reddens only when the draw_graph() writer clamp AND the per-site
## clamp are both gone. W1 and G1-G4 are the individual fences.
## ⚠ THE hcursors ARE RECT ATTRIBUTES, NOT A SETTING. setup_graph_data() reads
## `hcursor1_y`/`hcursor2_y` off the rect's prop_ptr and sets graph_flags bits
## 128/256 from their PRESENCE, so `xschem set ...` reaches neither. They are put
## on the rect here, and D1b asserts both bits came on, or the two hcursor
## readouts -- the only two sites with the `- 2` in their clamp -- would never run.
##
## ⚠ AND D1 NEEDS ITS OWN FIXTURE, NOT $GFIX, FOR A REASON THAT COST A ROW.
## `%g` STRIPS TRAILING ZEROS, so a precision of 200 only produces a long string
## if the VALUE has that many exact decimal digits. $GFIX sweeps x over 0..1, so
## draw_cursor formats `1e-12 * 1.0` -- about 52 exact digits -- and stays inside
## its 100-byte buffer at ANY precision. D1 was GREEN under a sabotage that removed
## both draw_graph()'s writer clamp and draw_cursor's own, i.e. it measured nothing,
## until the sweep was widened to 0..1e300 and the cursors moved onto values whose
## exact expansion is ~289 digits.
##
## ⚠ THE REACHABILITY EVIDENCE, CORRECTED -- AND THE CORRECTION IS THE POINT.
## An earlier revision of this comment said "VERIFIED by reachability probe:
## shrinking ONLY draw_cursor's tmpstr to 16 bytes aborts this fixture". THAT IS
## FALSE, and it was measured false on the tree this comment shipped with (cycle L2
## of receipts/Cv-sabotage.md): `RESULT: ALL PASS (43 checks)`, rc 0. It cannot
## abort, because of the fix itself -- the clamp's `avail` IS S(tmpstr), so shrinking
## the buffer shrinks the cap with it (16 -> cap 7) and precision 7 fits. Anyone
## trying that probe on a correct tree reproduces nothing.
## WHAT REALLY PROVES THE SITE LIVE, two independent sabotages:
##   L2b  tmpstr[16] AND draw_cursor's own clamp removed -> FOUR rows redden, not
##        one. RE-DRIVEN 2026-09-25 on this tree, and quoted as it prints now:
##        `FAIL: D1 ... (rc=134/SIGABRT-the-1606-overflow death=0 hasx=<<absent>>
##         done=0 flags=<<absent>>)`
##        `FAIL: D1b ... -> {<<absent>>} (exp {390})`   (the child aborts inside the
##         very redraw that would have printed FLAGS)
##        `FAIL: G1 draw_cursor's "%.*g%c" readout clamps against its whole 100-byte
##         buffer -> {0} (exp {1})`
##        `FAIL: X1 ... -> {1 {{draw.c: `%.*` ARGUMENT IS NOT A clamp_prec_g() CALL
##         (xctx->ev_precision): sprintf(tmpstr, "%.*g%c", xctx->ev_precision, ...)}}}`
##        ⚠ AN EARLIER REVISION OF THIS PARAGRAPH QUOTED `(rc=1 death=0 ...)` here,
##        and it printed that BEFORE the same repair round taught `child` to decode
##        the real exit status -- so the paragraph that exists to correct a stale
##        quoted probe shipped a stale quoted probe of its own. Re-drive before
##        quoting; that is the whole lesson of this comment.
##   L3   draw_graph()'s writer clamp AND draw_cursor's clamp removed, buffer
##        untouched -> `D1 D1b D2` all redden, and a direct probe on that binary
##        gave `*** buffer overflow detected ***: terminated`, rc 134.
## The CONCLUSION was right; only the evidence sentence was wrong.
set D1FIX [list \
  {set ::ev_precision 200} \
  {xschem raw new f.raw dc vsweep 0 1e300 1e299} \
  {xschem raw add v_big {vsweep 1 *}} \
  {xschem set rectcolor 2} \
  "xschem rect 0 0 800 400 -1 \{flags=graph\nnode=v_big\nunitx=T\nunity=T\nx1=0\nx2=1e300\ny1=-1e300\ny2=1e300\} 0" \
  {xschem zoom_full} \
  {xschem redraw} \
  {xschem setprop rect 2 0 hcursor1_y 1e299} \
  {xschem setprop rect 2 0 hcursor2_y -1e299} \
  {xschem cursor 1 1} {xschem set cursor1_x 9e299} \
  {xschem cursor 2 1} {xschem set cursor2_x 1e299} \
  {xschem redraw} \
  {puts "FLAGS=<[expr {[xschem get graph_flags] & (2|4|128|256)}]>"} \
  {puts "HASX=<[info exists has_x]>"}]
set d1 [child d1 $D1FIX display]
lassign $d1 d1rc d1death d1out
check_true "D1 a real graph draw with both cursors and both axis units SURVIVES at\
 ev_precision 200 on the dev display -- the four draw.c cursor readouts\
 (draw_cursor, draw_cursor_difference, draw_hcursor, draw_hcursor_difference), none\
 of which is reached headless" \
  [expr {$d1rc == 0 && !$d1death && [done $d1out] && [kv $d1out HASX] eq {1}}] \
  "(rc=[rcwhy $d1rc] death=$d1death hasx=[kv $d1out HASX] done=[done $d1out]\
 flags=[kv $d1out FLAGS])"

## D1 WOULD BE VACUOUS IF THE FIXTURE NEVER TURNED THE CURSORS ON. All four bits
## must be live: 2 and 4 are cursor1/cursor2 (draw_cursor twice plus
## draw_cursor_difference), 128 and 256 are the two hcursors (draw_hcursor twice
## plus draw_hcursor_difference) -- and the hcursor pair is the only place the
## `- 2` in G3/G4's clamp is exercised at all.
## ⚠ THIS IS AN ANTI-VACUITY ROW ON THE FIXTURE, NOT A FENCE ON A PRODUCT GUARD,
## and it is the one row here whose sabotage is a change to THIS FILE: dropping the
## hcursor2_y line gives 134 instead of 390 (measured). It cannot be reddened
## independently of D1 by a source sabotage, because the abort D1 catches happens
## inside the very redraw that sets bits 128/256.
check {D1b ... and the fixture really did arm both cursors AND both hcursors\
 (graph_flags 2|4|128|256), so D1 exercises all four readouts} \
  [kv $d1out FLAGS] [expr {2|4|128|256}]

# --- D2: the callback.c measurement tooltip -------------------------------
## `M` toggles graph_flags & 64, then a MotionNotify fills ::measure_text. Unlike
## D1 this one HAS a read-back seam, so it asserts the clamped digit count as well
## as survival. 71, not 91: the draw_graph() writer clamp is the tighter of the two
## on this path, and the per-site clamp (G9) is defence in depth.
set d2 [child d2 [concat [list {set ::ev_precision 200}] \
  [d_probe_body "unitx=T\nunity=T" 1e300 1e300]] display]
lassign $d2 d2rc d2death d2out
regexp {y=([^ |]*)} [kv $d2out MT] . d2y
check_true "D2 the callback.c measurement tooltip SURVIVES at ev_precision 200 on\
 the dev display and its y readout carries exactly 71 significant digits; before\
 the fix this aborted at 93 (and at 73 with only one axis unit set)" \
  [expr {$d2rc == 0 && !$d2death && [done $d2out] && [kv $d2out HASX] eq {1}
         && [info exists d2y] && [sigdigits $d2y] == 71}] \
  "(rc=[rcwhy $d2rc] death=$d2death digits=[expr {[info exists d2y] ? [sigdigits $d2y] : -1}]\
 mt=[kv $d2out MT])"

# --- D3/D4: the SECOND defect, measured ----------------------------------
## ⚠ D3 AND D4 ARE THE ONLY ROWS IN THIS FILE THAT MEASURE A CHANGE IN WHAT THE
## USER SEES, and they are the C14 before/after. ev_precision is 4 here on
## purpose: these rows are about WHICH unit is applied, not about buffer sizes.
##
## D3, `unity=T` and no `unitx`, y = 5.011: the y readout was `5.011` -- the
## UNSCALED dtoa_eng form, because the guard tested unitx -- and is now
## `5.011e-12T`, the value scaled by the y unit the user actually set, with that
## unit's suffix. (This is also where the abort threshold for that readout was 73
## instead of 93, because the readout went through dtoa_eng's 80-byte static.)
set d3 [child d3 [concat [list {set ::ev_precision 4}] [d_probe_body {unity=T} 5 10]] display]
lassign $d3 d3rc d3death d3out
check_true "D3 (second defect) with `unity=T` and no `unitx`, the y readout is now\
 scaled by the y unit and carries its suffix (y=5.011e-12T); before the fix the\
 guard tested unitx, so it read the unscaled y=5.011 and went through dtoa_eng's\
 tighter 80-byte buffer" \
  [expr {$d3rc == 0 && !$d3death && [done $d3out]
         && [kv $d3out MT] eq {y=5.011e-12T | x=0.4439}}] \
  "(rc=[rcwhy $d3rc] death=$d3death mt=[kv $d3out MT])"

## D4, `unitx=T` and no `unity`, y = 5.011e-06: the y readout was `5.011e-06` with
## a NUL written where the suffix belonged (`sprintf(..., "%c", 0)` -- measured:
## the string ends at the NUL, so the suffix simply vanished), and is now
## dtoa_eng's `5.011u`. The x readout is unaffected in both.
set d4 [child d4 [concat [list {set ::ev_precision 4}] \
  [d_probe_body {unitx=T} 5e-06 1e-05]] display]
lassign $d4 d4rc d4death d4out
check_true "D4 (second defect) with `unitx=T` and no `unity`, the y readout is now\
 dtoa_eng's engineering form (y=5.011u); before the fix the unitx guard sent it\
 through the sprintf arm with unity == 1.0 and unity_suffix == 0, so the %c wrote a\
 NUL where the suffix was meant and the readout was y=5.011e-06" \
  [expr {$d4rc == 0 && !$d4death && [done $d4out]
         && [kv $d4out MT] eq {y=5.011u | x=4.439e-13T}}] \
  "(rc=[rcwhy $d4rc] death=$d4death mt=[kv $d4out MT])"

}

# --- verdict ---------------------------------------------------------------
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
## Both sentinels: run_suites.sh scores `RESULT: ALL PASS`, tests/banner_rule.tcl
## -- the rule run_regression.tcl consumes -- scores ONLY a whole-line
## `OVERALL: ok`. A suite printing one of them is scored a HARNESS FAILURE by the
## other however many of its own checks passed.
if {$fail == 0} {
  puts "OVERALL: ok"
} else {
  puts "OVERALL: notok"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
