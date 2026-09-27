# Issue 1608 — USER DATA WAS THE FORMAT STRING, AND THE FORMATTER CHECKED ITS BOUNDS
# AFTER WRITING.
#
# Run (armed spelling — it arms the throwaway HOME):
#   tests/headless/run_suites.sh --nogui test_snprintf_fmt_1608
#   tests/headless/run_suites.sh        test_snprintf_fmt_1608
#
# Nothing in this file needs a display. It is registered in `hcases` only, so it reports no
# self-skip on either arm; the display arm runs the identical rows.
#
# ================================================================================
# WHAT WAS WRONG, IN THE ORDER THAT MATTERS
#
# (1) THE DOOR. Five `my_snprintf` call sites passed a value as the FORMAT STRING. Four are
#     in src/svgdraw.c — twice a text object's `font=` attribute out of a .sch or .sym FILE,
#     twice `tclgetvar("svg_font_name")` — and one is src/xinit.c's `--rcfile` argument. So
#     `xschem print svg` on a stranger's schematic was enough, HEADLESS, with no display and
#     no Tcl evaluation of any kind. Driven at 91bb1bd7:
#
#       font=%-2000d      ->  "*** buffer overflow detected ***: terminated"      rc 134
#       font=%nd          ->  "*** %n in writable segments detected ***"          rc 134
#       --rcfile '%s'     ->  SIGSEGV                                             rc 139
#       --rcfile '%-2000d'->  "*** buffer overflow detected ***: terminated"      rc 134
#
#     ⚠ THE `%nd` ONE IS THE SHARP END AND IT IS WHY THE BOUND IS NOT THE FIX. `%n` alone
#     survives my_snprintf's scanner because `n` is not a conversion terminator, but `%n`
#     followed by any handled letter IS a spec: it was strncpy'd into a WRITABLE STACK ARRAY
#     and handed to sprintf. The only obstacle to an arbitrary write was glibc's
#     PRINTF_FORTIFY refusal of %n in a non-read-only format — libc hardening on one
#     platform, not a property of this code, in a tree that also targets C89 and Windows.
#     `%nd` is THREE CHARACTERS PRODUCING NO OUTPUT, so it passes every arithmetic bound.
#     Only the `"%s", <value>` form at the five sites closes it. Section F is those five.
#
#     AND IT IS THE UN-FIXED TWIN OF ISSUE 1351. src/psprint.c carries a comment headed
#     "ISSUE 1351 — THE `font=` ATTRIBUTE IS A PostScript NAME AND A FORMAT STRING, AND IT
#     WAS NEITHER CHECKED NOR QUOTED" and now writes `"%s", ps_font_token(textfont)`, fenced
#     by rows V10/V13 of test_ps_valid_1350.tcl. The SVG back end was simply missed — and two
#     sites inside svgdraw.c already used the correct `"%s"` form, so the four bad ones were
#     an inconsistency within one file. The SVG fix is the `"%s"` ALONE and deliberately not
#     ps_font_token(): that helper maps the generic CSS/Cairo families onto the base-14
#     PostScript names because PostScript has never heard of them, whereas SVG's font-family
#     IS that namespace. Applying it here would discard the user's stated family. Rows F1,
#     F2 and F3 therefore assert the value REACHES THE SVG VERBATIM, not that it was
#     sanitised. F4 and F4b are shaped differently and assert an ABSENCE instead -- the long
#     comment above F4 says why that is the only non-vacuous observable at those two sites.
#
# (2) THE FORMATTER, four unchecked write mechanisms in src/util.c's my_snprintf:
#       (A) `strncpy(nfmt, fmt, l)`   into char[50], l unbounded
#       (B) `nfmt[l] = '\0'`          index l, i.e. one past at l == 50 — SILENT, because a
#                                     plain array store is not fortified while strncpy is,
#                                     so (B) fires FIRST as l grows and quietly
#       (C) `sprintf(nstr, nfmt, i)`  into char[50], output unbounded
#       (D) `string[n+l] = '\0'`      guarded by `if(n+l > size)`, so at n+l == size it wrote
#                                     one byte past THE CALLER'S buffer, on ALL FOUR arms.
#                                     `string` is a pointer parameter, so _FORTIFY_SOURCE
#                                     cannot size it and emits no check — SILENT too.
#     Section G drives all four, plus the three guards that now stop them.
#
# ================================================================================
# ⚠ FOUR TRAPS THIS FILE IS BUILT AROUND — READ BEFORE CHANGING A ROW
#
#  T1 `xschem zoom_full` IS REQUIRED BEFORE `xschem print svg`. Without it the text object
#     falls outside the export viewport and NO `<text>` element is emitted at all (measured:
#     0 occurrences of `<text` in the output), so a row that looked for the font-family
#     attribute would fail on a correct binary. The my_snprintf call still runs either way,
#     which is why the ABORT was reachable without it and the ATTRIBUTE is not.
#
#  T2 ASSERT `rc`, NEVER THE DEATH MARKER. main.c's sig_handler traps SIGINT/SEGV/ILL/TERM/
#     FPE and NOT SIGABRT, so a fortify abort prints ZERO column-0 `FATAL` lines. Across ~40
#     driven aborts in this batch not one appeared, and no emergency save was written either.
#     The rows still assert the marker's ABSENCE because the brief requires both halves and
#     because `--rcfile '%s'` was a SIGSEGV, which IS trapped — but the marker half is inert
#     for every abort shape here and must not be anyone's only assertion.
#
#  T3 THE DEATH MESSAGE DIFFERS BY MECHANISM. `%nd` printed `*** %n in writable segments
#     detected ***` and the width shapes printed `*** buffer overflow detected ***`. A row
#     asserting the buffer-overflow text would miss the %n shape entirely. No row here
#     matches either string.
#
#  T4 A `%*d` ROW ASSERTING THE ABORT WOULD BE FLAKY. At a door where no vararg was pushed
#     the width is stack garbage that moves with the environment block: 5 of 7 measured
#     environments did not abort. So G4 asserts the REFUSAL after the fix, never the abort
#     before it, and it drives `%*d` through a caller that DOES push an argument.
#
# ================================================================================
# HOW EACH GUARD IS FENCED, AND WHY THE BACKBONE IS BEHAVIOURAL
#
# Section F drives the five doors through the REAL src/xschem binary. Those rows are the
# shape a stranger's schematic actually takes.
#
# ⚠ AFTER SECTION F's FIX THERE IS NO LIVE DOOR LEFT INTO THE FORMATTER'S SPEC SCANNER, WHICH
# IS THE POINT AND ALSO A MEASUREMENT PROBLEM. Every remaining format in the tree is a short
# literal -- row P2 asserts that none is 50 characters or longer and reports the longest it
# found in its detail -- so no input any test can write makes
# a shipped caller hand my_snprintf a 50-character spec. Section G therefore COMPILES THE
# TREE'S OWN src/util.c — the real file, not a `sed` extraction, which is the instrument that
# produced a non-fact in the 1606 batch — links it against link stubs and a driver, and calls
# my_snprintf directly, ONE FORK PER CASE so a fortify abort is a recorded outcome rather than
# the end of the run. That is a behavioural row: it runs the tree's code and reports what it
# did. Its named limit is that it measures the SOURCE, so it is independent of whether anyone
# ran `make`; section F covers the shipped binary.
#
# Every guard reddens on its own single removal, measured by sabotage, WITH TWO STATED
# EXCEPTIONS THAT CANNOT CHANGE AN OBSERVABLE (below). ⚠ FIVE GUARDS DID NOT REDDEN WHEN THIS
# FILE SHIPPED, each found by an independent sabotage crew that removed one guard at a time and
# re-ran -- so treat this sentence as a record of what has been driven, never as a property of
# the file:
#   round one, four of them: svg_draw_symbol()'s `svg_font_name` call site, the spec gate in the
#     `p` arm, GUARD 3's digit-run cap, and the (D) refusal's NUL write. They are F4b, G12, G13
#     and G14.
#   round two, one more: the `if(!refuse)` WRAPPER round `strncpy(nfmt, fmt, l); nfmt[l] = 0` --
#     the half of the fix that stops the write rather than the half that shortens the result --
#     in the `p` and g/e/f arms. Removed in either arm alone, every row here stayed green while
#     51- and 60-character dash specs died `*** buffer overflow detected ***`. That is G15, and
#     the d/x/c/u arm's copy of the same wrapper is G1's.
# THE TWO EXCEPTIONS, both behaviourally dead and both stated rather than discovered:
#   the `overflow = 1` uniformity in the four (D) arms -- dead by a proof written out at
#     MY_SNPRINTF_PREFIX_GUARD in src/util.c;
#   the digit loop's bound `i + 1 < len` in my_snprintf_spec_ok() -- writing `i < len` instead
#     reddens nothing and CANNOT change an observable, because the loop advances only while
#     spec[i] is a digit and spec[len-1] is the conversion letter, which GUARD 2 restricts to
#     `s d x c u p g e f`. Both spellings consume the same digits. Recorded here so the next
#     crew does not file it as a sixth unfenced guard.
#
# THE FENCE MAP -- which single removal reddens which row:
#   GUARD 1 (`len >= nfmtsize`)      -> G1 (l == 50 stops refusing, l >= 51 returns to SIGABRT)
#   GUARD 2 (the whitelist)          -> G2 (%nd), G3 (%.0Lf), G4 (%*d %'.0f %zd %jd %td %qd)
#   GUARD 3 (`max + 320 < nstrsize`) -> G6, and G7 for the enlarged scratch
#   (D)'s `>=`                       -> G8 (the canary at index size)
#   the refusal's ORDERING           -> G9
#   the format attribute in util.h   -> W1, kept honest by W2
#   the `"%s"` at the five sites     -> ONE ROW PER SITE, and the reason is ATTRIBUTION rather
#     than reachability: one fixture CAN execute two of these sites (a .sch carrying its own text
#     and an instance whose .sym carries a text runs both `textfont` sites in one export,
#     measured), but no fixture lets a row say WHICH site produced the output unless the others
#     are neutralised, which is what each fixture below does:
#       svg_draw()'s `textfont`              -> F1, F2
#       svg_draw_symbol()'s `textfont`       -> F3
#       svg_draw()'s `svg_font_name`         -> F4
#       svg_draw_symbol()'s `svg_font_name`  -> F4b
#       xinit.c's `--rcfile`                 -> F6, F7, F8
#     F5, F9 and F11 are the controls. Measured by reverting one site at a time: F4's fixture is a
#     .sch with no instance, so svg_draw_symbol() never runs in it and F4 stayed GREEN with
#     that site reverted -- only W1 and P1 caught it, and neither is behavioural. F4b exists
#     for exactly that gap and its fixture instantiates a symbol.
#   `svg_font_family[0] &&` in svg_draw_string_line() -> F10 (.sch door) and F10b (.sym door),
#     with F11 the boundary control. That guard is OUTPUT NEUTRALITY, not memory safety: after the
#     `"%s"` fix a `font=` value too long for char[80] arrives EMPTY instead of being left out of
#     the buffer, and `style="font-family:;"` is an invalid CSS declaration where 91bb1bd7 emitted
#     no attribute at all. ⚠ IT ALSO TOOK F4's AND F4b's SABOTAGE OBSERVABLE AWAY: their reverted
#     shape WAS that empty attribute, so both went green on a reverted site until their fixtures
#     grew a literal prefix (`Zz%-2000d`). Driven and written up at the comment above F4.
#   the `if(!refuse)` WRAPPER round the strncpy -> G1 in the d/x/c/u arm, G15 in the `p` and
#     g/e/f arms. `refuse` does TWO things and only one of them was fenced everywhere: it skips
#     the strncpy AND it breaks after the prefix write. The break is what `g_refused` sees, so
#     until G15 the skipped strncpy had no row in two of the three gated arms.
#   the spec gate in the `p` ARM     -> G12. It had no row at all. With only that one arm's
#     `refuse = !my_snprintf_spec_ok(...)` removed, EVERY OTHER ROW stayed green -- re-driven
#     after G12 was added, `RESULT: 1 FAILED (32 passed)` with G12 the only red -- while
#     `%np` died `*** %n in writable segments detected ***` and `%-2000p` died
#     `*** buffer overflow detected ***` -- the attempted arbitrary write this whole issue is
#     about, in the one arm no hostile spec had been driven through.
#   GUARD 3's digit-run cap `run < 1000000` -> G13. Removed, `%18446744073709551616d` wraps
#     the accumulator to 0, passes the gate, and my_snprintf returns (size_t)-1 -- which five
#     live sites consume as a length.
#   the (D) refusal's `if(n < size) string[n] = '\0'` -> G14. Removed in all four arms, a
#     refused conversion leaves the caller's buffer UNWRITTEN again, which is the (E) shape
#     (D)'s fix exists to avoid.
#   ISSUE 1609's ADDITIONS TO THE MAP -- one row per single removal, driven:
#     the `d` branch's `va_arg(args, long)`            -> M1
#     the `d` branch's `sprintf(nstr, nfmt, lv)`       -> M1 (the other half of the same branch;
#       each half was removed on its own and each reddened M1 alone)
#     the `u`/`x` branch's `va_arg(args, unsigned long)` -> M2
#     the `u`/`x` branch's `sprintf(nstr, nfmt, ulv)`  -> M2
#     GUARD 2b, `if(nmod) return 0;`                   -> M4, kept honest by M5
#     `c`'s ABSENCE from both wide branches            -> M8 ONLY, and that is a source-text row
#       on purpose: driven with `c` added to the `d` branch, EVERY ROW IN THIS FILE STAYED GREEN,
#       because va_arg advances the same eight-byte slot for `int` and `long` and glibc reads
#       four bytes for `%lc` whatever was pushed. There is no observable to assert.
#     the `unsigned long` SPELLING of the `u`/`x` fetch -> M8 ONLY, same reason: a signed fetch
#       gives byte-identical text for `%lu` and `%lx` on this ABI (driven).
#     the ABSENCE of `long long` from src/util.c        -> M7
#   every `row`/`rows` citation of this file in src/ -> X1, which asserts the cited ids EXIST.
#     Five shipped comments cited rows that did not (`row F13` twice, `rows F7-F12`,
#     `rows F1-F6`, `rows F3/F4/F6`); the repo has shipped a wrong row name or citation in EVERY
#     hardening round so far, this one included, so the fix is a row and not five edits. (No
#     count of rounds is written here either -- see L9; it has only ever gone up.)
# GUARD 1 covers (A) AND (B) deliberately with ONE test, because (B)'s threshold is the lower
# one and there is no value of l where one fires and the other does not. Two guards on one
# path would mean neither had a row that reddens on its own removal, which defeated a whole
# fencing plan in the 1606 batch; src/util.c's comment says so at the guard itself.
#
# ================================================================================
# ⚠ NAMED LIMITS — WHAT THIS FILE DOES NOT MEASURE, STATED RATHER THAN IMPLIED
#
#  L1 NO ROW HERE CLAIMS A COUNT OF THE SHAPES THAT COULD ESCAPE IT. Five consecutive rounds
#     of the 1606 batch shipped such a sentence and a crew refuted it every time. P1/W1 name
#     the shapes they drove; the list may grow.
#     ⚠ And see L9 below: the same rule, applied to COMMENTS rather than to rows.
#  L2 NO NON-FORTIFIED AND NO WINDOWS BUILD. Every abort quoted above is
#     `_FORTIFY_SOURCE=3` with `__sprintf_chk`/`__strncpy_chk` on x86-64 glibc. Without
#     fortify, `font=%nd` is a write through an unpushed vararg rather than an abort — which
#     is the reason GUARD 2 refuses `%n` itself instead of trusting libc.
#  L3 THE `%s` ARM'S OWN FIELD WIDTH IS STILL DISCARDED. `%-12s` pads nothing, measured; that
#     arm never builds nfmt. It is a separate output defect, carried forward in issue 1608.
#  L4 ⚠ SUPERSEDED BY ISSUE 1609, AND THE ORIGINAL TEXT IS KEPT BELOW BECAUSE FIVE ROWS IN
#     SECTION M ARE THE ANSWER TO IT. What it said: "`%ld`/`%lu`/`%hu`/`%hhd` STILL MIS-FETCH.
#     GUARD 2 permits `l` and `h` because refusing them would change what live callers in
#     scheduler.c print (G5 is that row), and their output is 20 characters at worst, far inside
#     GUARD 3. The arm fetches `va_arg(args, int)` and sprintf then reads 8 bytes, which works
#     only by x86-64 zero-extension. Named and carried forward in the issue, not fixed, and NOT
#     fenced here."
#     WHAT IS TRUE NOW: the `d/x/c/u` arm fetches BY THE SPEC'S OWN LENGTH MODIFIER -- a `long`
#     for `%ld`, an `unsigned long` for `%lu`/`%lx`, an `int` for everything else including
#     `%lc` -- and rows M1, M2 and M3 drive it. `%hu` and `%hhd` never mis-fetched: a `short` or
#     a `char` argument promotes to `int`, so `va_arg(args, int)` was and is the correct fetch
#     for them (their narrowing is glibc's). `%hhd` is now REFUSED, not because it mis-fetched
#     but because GUARD 2b admits AT MOST ONE length modifier; it has no occurrence in the tree.
#     THE LIMIT THAT REMAINS: this fix is measured on x86-64 LP64 gcc only. On an LLP64 target
#     (Win64) `long` is 4 bytes and there was no defect to fix; on a big-endian LP64 target a
#     4-byte read of an 8-byte slot takes the HIGH half, which is a derivation from endianness
#     and not a measurement -- there is no such target here. Rows M1-M8 measure THIS machine.
#  L5 THE VALUE IN THE EXPORTED SVG IS STILL UNESCAPED. `font=` lands inside a double-quoted
#     XML attribute, so a `"` in the name can still break it. That is an output-escaping
#     defect, not a memory write, and it needs its own issue. F1-F4 and F4b assert the
#     format-string door is shut, not that the SVG is well-formed for every input.
#  L6 SECTIONS G, W AND P NEED gcc AND A `CFLAGS=` LINE IN THE GENERATED Makefile.conf. With
#     either absent they print TWO lowercase `skip:` lines, not one -- driven with gcc off
#     PATH: one names the G/W/P rows, the second names S3, which is preprocessed and needs the
#     same two things, and the run reports `ALL PASS` over only the rows that CAN run -- section
#     F, S1, S2 and X1 -- which is far short of a full run. (Per L9 neither check total is
#     written down here; the `RESULT:` line states whichever one applies on every run, and an
#     earlier version of this paragraph quoted a full-run total that a new row then moved.)
#     Those rows still run because row_skip() feeds every skipped id into X1's row-id set, so a
#     citation of a row that did not RUN is not mistaken for a citation of a row that does not
#     EXIST.
#  L7 X1 READS ONLY src/, AND ONLY FILES THAT MENTION THIS FILE'S NAME. Inside such a file a
#     BARE `row X` with no suite name IS checked -- attributed to the nearest preceding `*.tcl`
#     name, which is how these comments are written and which is a heuristic, not a property.
#     ⚠ THE MISSES ARE ENUMERATED FROM AN ATTACK RUN, NOT REASONED ABOUT. Twelve hostile
#     citations were planted (ten simultaneously, each with its own fabricated id so the
#     `unknown={...}` list attributes every outcome to exactly one plant) and the row was re-run.
#     WHAT IT CAUGHT, all reported by id: a citation inside a `/* */` BLOCK COMMENT; inside a C
#     STRING LITERAL; inside a `#if 0` REGION -- all three because the row scans TEXT and does
#     not care what compiles; a real row id belonging to a DIFFERENT suite, cited as ours; a
#     citation in a `.tcl` file under src/; a RANGE whose endpoints exist and whose middle does
#     not, with and without backticks; and each id WRAPPED IN BACKTICKS, singly, in a range and
#     in a comma list.
#     AND ONE THAT SHIPPED AS A MISS AND IS NOW CAUGHT: a range written with `..` rather than `-`
#     (`Rows A36..A39 of <path>.tcl`, which is how draw.c, svgdraw.c and psprint.c all spell the
#     declutter citation). The id list stopped at the first id, rule 1 never saw the `of <path>`
#     that followed, and rule 3 handed it to whichever suite was named earlier in the file --
#     benign until a 1608 comment was inserted between the two, which is how it surfaced. `..` is
#     a separator in `xIDL` now; the comment there records it.
#     WHAT IT MISSES, each with the mechanism, because a miss nobody has written down is the one
#     that ships:
#       * a LOWERCASE id (`row q7b`). The id shape is `[A-Z][A-Za-z]{0,2}[0-9]+[A-Za-z]?` by
#         design, so that "row 5" and "Row One" are not ids; a lowercase one does not match and
#         is not seen at all.
#       * a HYPHENATED keyword (`row-Q6`). The keyword must be followed by whitespace. Same
#         outcome: no match, no citation, no complaint.
#       * a citation whose spelling of this file's NAME is split across two comment lines. This
#         one depends on the file: in a file that names ONLY this suite the `xonly` fallback
#         still attributes it and it IS CAUGHT (driven); in a file that also names another suite,
#         attribution rule 3 hands it to whichever suite was named last and it is missed.
#       * RULE 3 MISATTRIBUTION, which is that same failure on purpose: a bare `row X` of OURS
#         written after a DIFFERENT suite's file name in the same file is counted in
#         `other_suites` and never checked. Rule 3 is a heuristic about how these comments are
#         written, and this is exactly its failure mode. Both directions are visible in the
#         detail (`other_suites=`, `unattributed=`) rather than silent.
#       * a file with NO source-text extension (driven with src/Makefile). `xwalk` takes only
#         `.c .h .l .y .tcl .awk .in .sh .md .txt`.
#       * a bare `row X` in a file that never names this suite at all (this file's own prose is
#         full of other suites' ids -- `rows V10/V13 of test_ps_valid_1350.tcl`, `1607 row V27`,
#         `1603 rows S1-S4`, `row G2` of test_home_isolation -- which is exactly why a bare-id
#         scan needs an attribution rule and why THIS file is not scanned).
#       * a new gcc-dependent row that is not added to `gwp_rows`.
#     Named, not claimed away. ⚠ And per L9 this paragraph quotes no citation count: the count is
#     a count of src/'s own text and X1 asserts a FLOOR precisely so that it never has to be one.
#  L8 (E) IS NOT CLOSED, AND THE SHAPE THAT SURVIVES IS NOT THE ONE THE ISSUE FIRST NAMED. A
#     format with NO CONVERSION at all that does not fit -- `my_snprintf(u, 2, "abcd")` --
#     returns 0 and leaves the caller's buffer untouched (driven: all 4095 canary bytes
#     intact), because the tail copy is the only writer on that path. The four CONVERSION
#     shapes DO now write, and G14 is the row that keeps them writing. No row asserts the
#     surviving shape, because asserting it would be asserting a defect; it is carried forward
#     in issue 1608's "still open".
#  L9 ⚠ NO COMMENT IN THIS BATCH -- HERE OR IN src/ -- QUOTES A COUNT THAT A COMMAND OVER THE
#     TREE'S OWN TEXT PRODUCES. THIS IS A CONVENTION, NOT AN OBSERVATION, AND IT WAS BOUGHT AT
#     A HIGH PRICE: one sentence about `#pragma` shipped WRONG THREE TIMES IN A ROW, each time
#     in the revision written to correct the previous one.
#       round 1 wrote  "... sums to 0"                  -- the answer was 1
#       round 2 wrote  "... SUMS TO 1 AND NOT 0"        -- the answer was 3
#     Nobody miscounted. `grep -c` counts LINES, the sentence is INSIDE the file the grep reads,
#     and round 2's rewrite happened to spread the word across three lines of itself. A count
#     like that is a hostage to the comment's own wording, so the number is the one part of the
#     claim that cannot be trusted. THE RULE: either a ROW asserts the count -- which re-measures
#     it on every run and reddens when it moves -- or the sentence states the substantive claim
#     with NO number in it. ("There is no `#pragma` DIRECTIVE anywhere in src/" is the substance,
#     and `/usr/bin/grep -rln '#pragma' src/` naming only util.c is how a reader checks it.)
#     SECOND CLAUSE, same rule, different failure: NO FIGURE THE INSTRUMENT CANNOT REPRODUCE.
#     GUARD 1's comment in src/util.c used to quote three specific integers printed by a
#     va_arg on a vararg nobody pushed, in the same paragraph that says the value is stack
#     garbage; a second crew re-drove it and got six different numbers. What reproduces is the
#     SHAPE, and that is what the comment now records.
#     WHAT THIS DOES NOT FORBID: a measurement of the PROGRAM's behaviour with its instrument
#     named next to it -- a formatted width, an exit code, a death message, a count of items a
#     sentence itself enumerates. Those are reproducible independently of the sentence that
#     records them, which is exactly what the two forbidden classes are not.
# ================================================================================

set fail 0
set pass 0
## THE SET OF ROW IDS THAT EXIST, DERIVED AND NEVER HAND-LISTED. Row X1 checks that every
## `row`/`rows` citation of this file in src/ names a row that exists, and it needs to know
## which ids those are. A hand-maintained list would be the very defect X1 is about, one level
## up -- so `check` records the first token of every row name it is handed, and `row_skip`
## records the ids of the rows it says did not run. The set is therefore the rows this run
## knows about, and a renamed row makes its own citation red instead of silently agreeing
## with itself.
set rowids {}
proc row_seen {id} {
  global rowids
  if {[lsearch -exact $rowids $id] < 0} { lappend rowids $id }
}
proc check {n ok d} {
  global fail pass
  if {[regexp {^([A-Z][A-Za-z0-9]*)[ \t]} $n . id]} { row_seen $id }
  if {$ok} { puts "ok:   $n $d" ; incr pass } else { puts "FAIL: $n $d" ; incr fail }
}
## THE ONE PLACE A `skip:` LINE IS WRITTEN. Routing every skip through here is what keeps X1
## honest when a section does not run: the skipped ids still reach the row-id set, so X1 does
## not mistake a citation of a row that DID NOT RUN for a citation of a row that DOES NOT
## EXIST. ⚠ Lowercase, and the reason must not end in FAIL/GOLD?/RESULT? nor start with FATAL
## -- summarize_all tests those shapes first, wherever they appear.
proc row_skip {ids reason} {
  foreach id $ids { row_seen $id }
  puts "skip: [join $ids { }] -- $reason"
  flush stdout
}

source [file join [file dirname [info script]] scratch.tcl]
set dir  [test_scratch snpfmt1608]
set repo [file normalize [file join [file dirname [info script]] .. ..]]
set lib  [file join $repo xschem_library]

proc slurp {f} { if {![file exists $f]} { return "" } ; set fd [open $f rb] ; set d [read $fd] ; close $fd ; return $d }
proc spew {f d} { set fd [open $f w] ; puts -nonewline $fd $d ; close $fd }

# ------------------------------------------------------------------- fixtures ---
## A schematic whose only content is ONE text object carrying the given font= value, plus a
## symbol instance whose SYMBOL text carries it -- so both `textfont` sites are reachable from
## one fixture. Written per-case because the value is the thing under test.
proc wr_sym {path font} {
  spew $path "v {xschem version=3.4.6 file_version=1.2}\nG {}\nK {type=subcircuit}\nV {}\nS {}\nE {}\nL 4 -20 -20 20 -20 {}\nL 4 20 -20 20 20 {}\nL 4 20 20 -20 20 {}\nL 4 -20 20 -20 -20 {}\nT {SYMTXT} -15 -8 0 0 0.3 0.3 {layer=4 font=$font}\n"
}
proc wr_sch {path font symname} {
  set body "v {xschem version=3.4.8 file_version=1.3}\nG {}\nK {}\nV {}\nS {}\nE {}\n"
  append body "T {SCHTXT} 60 -30 0 0 0.4 0.4 {layer=4 font=$font}\n"
  if {$symname ne {}} { append body "C {$symname} 0 0 0 0 {name=x1}\n" }
  spew $path $body
}

# --------------------------------------------------------------------- runner ---
## Spawn a child xschem. SPAWNED, NOT IN-PROCESS: every row in section F fences a process
## death, which in-process would take this script's own interpreter down and turn a named FAIL
## into a dead suite with no verdict.
##
## Returns {rc death out}. `rc` is the child's exit status -- 134 for a fortify abort, 139 for
## a SIGSEGV, 1 for xschem's own Tcl_Exit(EXIT_FAILURE), 0 for success. `death` is whether a
## column-0 `FATAL: signal` marker was printed; see trap T2 for why it is inert for SIGABRT
## and asserted anyway.
##
## `pre` are extra xschem command-line arguments placed BEFORE --script, which is how the
## --rcfile door is reached. `arm`: `nogui` adds --nogui and runs with no display; `display`
## routes the child through devdisplay.sh exec, which pins DISPLAY=:99 and GUI_GATE=0.
## ⚠ THE `timeout` GOES INSIDE `devdisplay.sh exec`, NOT AROUND IT: devdisplay.sh runs the
## command as a child rather than exec'ing over itself, so a timeout wrapped around the
## wrapper would kill the wrapper and leave xschem alive on :99 with nobody waiting on it.
proc child {dir tag body {pre {}} {arm nogui}} {
  set t [file join $dir $tag.tcl]
  set fd [open $t w]
  puts $fd "set XSCHEM_LIBRARY_PATH {$dir:$::lib}"
  puts $fd "set netlist_dir {$dir}"
  foreach l $body { puts $fd $l }
  puts $fd "puts CHILD_DONE" ; puts $fd "flush stdout" ; puts $fd "exit 0"
  close $fd
  set here [pwd] ; cd $dir
  set rc 0 ; set out ""
  set xs [info nameofexecutable]
  if {$arm eq {display}} {
    set dd [file join $::repo tests headless devdisplay.sh]
    if {[catch {exec $dd exec timeout 60 $xs --pipe -q {*}$pre --script $t 2>@1} out opt]} {
      set rc [__rc $opt]
    }
  } else {
    if {[catch {exec timeout 60 $xs --nogui --pipe -q {*}$pre --script $t 2>@1} out opt]} {
      set rc [__rc $opt]
    }
  }
  cd $here
  return [list $rc [regexp {(?n)^FATAL: signal} $out] $out]
}
## The child's REAL exit status out of Tcl's -errorcode. `CHILDSTATUS pid n` gives n; a signal
## death arrives as `CHILDKILLED pid SIGxxx name`, which is what a fortify abort looks like
## through `timeout` only when timeout is absent -- with `timeout` in front, an abort is
## reported as CHILDSTATUS 134. Both are handled so a row can assert the number the shell
## prints. Anything else (NONE, a POSIX error) becomes -1, which no row expects.
proc __rc {opt} {
  set ec [dict get $opt -errorcode]
  if {[lindex $ec 0] eq {CHILDSTATUS}} { return [lindex $ec 2] }
  if {[lindex $ec 0] eq {CHILDKILLED}} { return [expr {128 + [__signum [lindex $ec 2]]}] }
  return -1
}
proc __signum {s} {
  switch -- $s { SIGABRT { return 6 } SIGSEGV { return 11 } default { return 0 } }
}
## every font-family value the export emitted, deduplicated, whitespace-trimmed
proc svg_fams {f} {
  set out {}
  foreach m [regexp -all -inline {font-family:[^;"]*} [slurp $f]] {
    lappend out [string trim [string range $m 12 end]]
  }
  return [lsort -unique $out]
}

# ============================================================================
# SECTION F — THE FIVE CALL SITES, DRIVEN THROUGH THE REAL src/xschem
# ============================================================================
# ⚠ NO ROW HERE IS SATISFIED BY SURVIVAL ALONE. "rc 0" would also be satisfied by a binary
# that dropped the font= attribute entirely, which is what the pre-1608 refusal path does for
# an over-long value -- so a survival-only row could go green on a fix that silently discarded
# the user's font. What each row adds to rc, exactly:
#   F1, F2, F3, F5    the value reached the exported font-family VERBATIM
#   F6, F7, F8        the value came back VERBATIM in `cannot find <value>`
#   F4, F4b           an ABSENCE -- ZERO per-text `style="font-family:"` attributes -- plus two
#                     companion assertions that stop the absence being vacuous. Those two
#                     sites have no verbatim observable at all; the long comment above F4 says
#                     why, and it is measured, not assumed.
#   F5, F9            the CONTROLS, and F9 is NOT a verbatim row: its --rcfile names a file that
#                     EXISTS, so nothing prints `cannot find` and the assertion is `SOURCED=<1>`
#                     in the child's output. An earlier version of this table grouped it with
#                     F6-F8, which is the one row in section F it does not describe -- and it
#                     did so inside the paragraph that replaced a false sentence about every row.

set f1sch [file join $dir f1.sch]
wr_sch $f1sch {%-2000d} {}
set f1 [child $dir f1 [list "xschem load $f1sch" "xschem zoom_full" \
  "xschem print svg [file join $dir f1.svg]" "puts SVG-OK"]]
lassign $f1 f1rc f1death f1out
check "F1 (1608) a .sch text object whose `font=` attribute is the seven-character\
 `%-2000d` survives `xschem zoom_full; xschem print svg` headless AND the value reaches the\
 exported font-family verbatim. This is svg_draw()'s `textfont` site. At 91bb1bd7 the same\
 fixture printed `*** buffer overflow detected ***: terminated` and exited 134 -- see trap\
 T3: this row matches no death text, only rc and the emitted value" \
  [expr {$f1rc == 0 && !$f1death && [string first SVG-OK $f1out] >= 0 \
         && [lsearch -exact [svg_fams [file join $dir f1.svg]] {%-2000d}] >= 0}] \
  "(rc=$f1rc death=$f1death fams={[svg_fams [file join $dir f1.svg]]})"

set f2sch [file join $dir f2.sch]
wr_sch $f2sch {%nd} {}
set f2 [child $dir f2 [list "xschem load $f2sch" "xschem zoom_full" \
  "xschem print svg [file join $dir f2.svg]" "puts SVG-OK"]]
lassign $f2 f2rc f2death f2out
check "F2 (1608) the SAME door with `font=%nd`, which is the shape every arithmetic bound\
 misses -- three characters producing no output. At 91bb1bd7 it printed `*** %n in writable\
 segments detected ***` and exited 134, i.e. an ATTEMPTED ARBITRARY WRITE stopped only by\
 glibc's PRINTF_FORTIFY. Now it exports `%nd` as an ordinary font name" \
  [expr {$f2rc == 0 && !$f2death && [string first SVG-OK $f2out] >= 0 \
         && [lsearch -exact [svg_fams [file join $dir f2.svg]] {%nd}] >= 0}] \
  "(rc=$f2rc death=$f2death fams={[svg_fams [file join $dir f2.svg]]})"

wr_sym [file join $dir f3.sym] {%nd}
set f3sch [file join $dir f3.sch]
wr_sch $f3sch {plainsch} f3.sym
set f3 [child $dir f3 [list "xschem load $f3sch" "xschem zoom_full" \
  "xschem print svg [file join $dir f3.svg]" "puts SVG-OK"]]
lassign $f3 f3rc f3death f3out
check "F3 (1608) the `font=` attribute of a text object inside a .sym, reached through an\
 instance -- svg_draw_symbol()'s `textfont` site, a DIFFERENT one of the four from F1/F2.\
 A stranger's SYMBOL LIBRARY is the door here, not their schematic" \
  [expr {$f3rc == 0 && !$f3death && [string first SVG-OK $f3out] >= 0 \
         && [lsearch -exact [svg_fams [file join $dir f3.svg]] {%nd}] >= 0}] \
  "(rc=$f3rc death=$f3death fams={[svg_fams [file join $dir f3.svg]]})"

## ⚠ THE `Zz` PREFIX ON F4's AND F4b's svg_font_name IS LOAD-BEARING, AND THE ROWS WERE GREEN
## WITH A REAL SITE REVERTED WITHOUT IT. Both rows' observable is an ABSENCE -- zero per-text
## `style="font-family:"` attributes -- and until the output-neutrality guard landed in
## svg_draw_string_line() the sabotage produced `style="font-family:;"`, i.e. a PRESENT
## attribute, which is what made the absence non-vacuous. That guard now suppresses an EMPTY
## family, so a refusal produces no attribute either and the absence stopped distinguishing
## anything. Driven, with only svg_draw()'s `svg_font_name` call reverted and the bare
## `%-2000d` fixture: `RESULT: 3 FAILED (31 passed)` with F4 GREEN and the three reds W1, P1 and
## X1 -- the compiler's opinion, the preprocessed census and the citation checker, NOT ONE OF
## WHICH RUNS THE BINARY. Exactly the gap F4b itself was invented to close, reopened one level
## down.
## THE CURE IS IN THE FIXTURE, NOT THE ASSERTION: give the value a LITERAL PREFIX. On a correct
## binary `Zz%-2000d` round-trips through the `"%s"` form whole and matches the variable, so the
## absence still holds. With the site reverted, my_snprintf writes the prefix `Zz` and THEN
## refuses the spec -- that ordering is the subject of G9 -- so svg_font_family is `Zz`, which is
## NON-EMPTY and differs from svg_font_name, and `style="font-family:Zz;"` appears. Both rows'
## details print the attribute count, so the red says which shape arrived.
## The prefix also removes a second-order flake: nothing pushes a vararg at these doors, and with
## `Zz%-2000d` the refusal happens before sprintf() is reached, so the garbage int is never read.
##
## ⚠ F4 IS SHAPED DIFFERENTLY FROM F1-F3, AND ITS FIRST DRAFT WAS VACUOUS. The obvious row --
## set svg_font_name to a spec and look for it in the output -- PASSES WITH BOTH SITES
## REVERTED, measured: svgdraw.c emits the family TWICE by two different paths, and only one
## goes through my_snprintf. `svg_embedded_style` writes a CSS rule `text {font-family: %s;}`
## straight from tclgetvar("svg_font_name") with no my_snprintf anywhere near it, so the value
## the first draft found had never touched the code under test.
## The two sites under test PRE-LOAD svg_font_family from svg_font_name, and svg_draw_string's
## reader emits the per-text `style="font-family:..."` attribute ONLY IF svg_font_family
## DIFFERS from svg_font_name. So on a correct binary, a schematic with no font= attribute at
## all produces ZERO such attributes -- the round trip through my_snprintf preserved the value
## and the strcmp matched. With the sites reverted, my_snprintf refuses the spec, leaves
## svg_font_family empty, the strcmp differs, and `style="font-family:;"` appears. That
## ABSENCE is the observable, and the two companion assertions stop it being vacuous: a <text>
## element must exist at all, and the CSS rule must carry the value, which is what says the
## variable really was set.
set f4sch [file join $dir f4.sch]
spew $f4sch "v {xschem version=3.4.8 file_version=1.3}\nG {}\nK {}\nV {}\nS {}\nE {}\nT {SCHTXT} 60 -30 0 0 0.4 0.4 {layer=4}\n"
set f4 [child $dir f4 [list "xschem load $f4sch" "xschem zoom_full" \
  "set svg_font_name {Zz%-2000d}" \
  "xschem print svg [file join $dir f4.svg]" "puts SVG-OK"]]
lassign $f4 f4rc f4death f4out
set f4svg [slurp [file join $dir f4.svg]]
set f4attr [regexp -all {style="font-family:} $f4svg]
set f4css  [regexp -all -inline {text \{font-family:[^\}]*\}} $f4svg]
set f4txt  [regexp -all {<text} $f4svg]
check "F4 (1608) svg_draw()'s `svg_font_name` site -- the THIRD of the four svgdraw.c sites.\
 The DEFAULT family comes from the Tcl variable `svg_font_name`, which any xschemrc, --preinit\
 or script can set, so this door needs no file at all. With it set to `Zz%-2000d` and a\
 schematic carrying no `font=` attribute, the export emits the text and ZERO per-text\
 `style=\"font-family:\"` attributes -- which is what says the value round-tripped through\
 my_snprintf intact and matched the variable it came from. Reverting THIS site makes\
 my_snprintf write the literal prefix and then refuse the spec, so svg_font_family is `Zz`, the\
 comparison differs, and `style=\"font-family:Zz;\"` appears instead. ⚠ THE `Zz` IS WHY THIS ROW\
 STILL REDDENS: with a bare `%-2000d` the refusal leaves the family EMPTY, and an empty family\
 now emits no attribute at all, which is indistinguishable from the pass -- driven, F4 green on\
 a reverted site. See the long comment above. ⚠ IT DOES NOT COVER svg_draw_symbol()'s svg_font_name SITE, measured: this fixture\
 is a .sch with NO INSTANCE, so that function never runs in it and reverting that site leaves\
 this row GREEN (only W1 and P1 caught it, and neither is behavioural). F4b is that site" \
  [expr {$f4rc == 0 && !$f4death && [string first SVG-OK $f4out] >= 0 \
         && $f4attr == 0 && $f4txt >= 1 \
         && [lsearch -glob $f4css {*Zz%-2000d*}] >= 0}] \
  "(rc=$f4rc death=$f4death per_text_attrs=$f4attr want=0 text_elements=$f4txt\
 css={$f4css})"

## ⚠ F4b IS THE FOURTH SITE, AND IT IS HERE BECAUSE F4 DOES NOT REACH IT. Driven one site at a
## time on the shipped tree: reverting svg_draw_symbol()'s `svg_font_name` call reddened only
## W1 and P1 -- the compiler's opinion and the preprocessed census, NEITHER OF WHICH RUNS THE
## BINARY -- while EVERY BEHAVIOURAL ROW, F4 included, stayed green. (So the 28-row suite did
## redden; what it did not do was redden on anything that had exported an SVG.) The cause is
## F4's FIXTURE, not F4's assertion: it is a .sch with no instance, so svg_draw_symbol() is
## never entered.
## So this fixture instantiates a symbol and has NO schematic text of its own. That matters
## twice over: the instance is what enters svg_draw_symbol(), and the absent schematic text is
## what keeps svg_draw()'s own `svg_font_name` site (F4's) from writing svg_font_family in this
## run -- so the value in the output can only have come through the site under test. The symbol
## text carries NO `font=` attribute, which is what keeps svg_draw_symbol()'s OTHER site (F3's
## `textfont`) out of the way as well.
## The observable is F4's: svg_draw_string() emits the per-text `style="font-family:..."` only
## when svg_font_family DIFFERS from svg_font_name, so a correct round trip emits ZERO of them,
## and a refusal leaves svg_font_family holding just the `Zz` prefix and emits
## `style="font-family:Zz;"`. Measured with the site reverted: per_text_attrs=1,
## `style="font-family:Zz;"`.
## NOT wr_sym: that writes a `font=` token, and this fixture needs the attribute ABSENT so the
## `textfont` site is not entered at all.
spew [file join $dir f4b.sym] "v {xschem version=3.4.6 file_version=1.2}\nG {}\nK {type=subcircuit}\nV {}\nS {}\nE {}\nL 4 -20 -20 20 -20 {}\nL 4 20 -20 20 20 {}\nL 4 20 20 -20 20 {}\nL 4 -20 20 -20 -20 {}\nT {SYMTXT4B} -15 -8 0 0 0.3 0.3 {layer=4}\n"
set f4bsch [file join $dir f4b.sch]
spew $f4bsch "v {xschem version=3.4.8 file_version=1.3}\nG {}\nK {}\nV {}\nS {}\nE {}\nC {f4b.sym} 0 0 0 0 {name=x1}\n"
set f4b [child $dir f4b [list "xschem load $f4bsch" "xschem zoom_full" \
  "set svg_font_name {Zz%-2000d}" \
  "xschem print svg [file join $dir f4b.svg]" "puts SVG-OK"]]
lassign $f4b f4brc f4bdeath f4bout
set f4bsvg [slurp [file join $dir f4b.svg]]
set f4battr [regexp -all {style="font-family:} $f4bsvg]
set f4bcss  [regexp -all -inline {text \{font-family:[^\}]*\}} $f4bsvg]
set f4btxt  [regexp -all {<text} $f4bsvg]
check "F4b (1608) svg_draw_symbol()'s `svg_font_name` site -- the FOURTH of the four svgdraw.c\
 sites and the one that had no behavioural row. A stranger's SYMBOL LIBRARY plus any xschemrc,\
 --preinit or script that sets `svg_font_name` is the door; no schematic file needs to carry\
 anything. With it set to `Zz%-2000d`, a .sch holding ONLY an instance (no text of its own) and a\
 .sym text carrying NO `font=`, the export emits the symbol text and ZERO per-text\
 `style=\"font-family:\"` attributes, and the embedded CSS rule carries the value -- which\
 together say the value round-tripped through my_snprintf at THIS site and matched the variable\
 it came from. Reverting only this site gives per_text_attrs=1 and `style=\"font-family:Zz;\"` --\
 and the `Zz` prefix is what keeps that true now that an EMPTY family emits nothing; see the\
 long comment above F4" \
  [expr {$f4brc == 0 && !$f4bdeath && [string first SVG-OK $f4bout] >= 0 \
         && $f4battr == 0 && $f4btxt >= 1 \
         && [lsearch -glob $f4bcss {*Zz%-2000d*}] >= 0}] \
  "(rc=$f4brc death=$f4bdeath per_text_attrs=$f4battr want=0 text_elements=$f4btxt\
 css={$f4bcss})"

## ⚠ THE CONTROL, AND IT IS NOT DECORATION. F1-F4 would all pass on a binary whose SVG export
## had stopped emitting font-family for any value -- `lsearch` on an empty list simply fails,
## but a binary that emitted a CONSTANT would satisfy nothing while a binary that emitted the
## requested name for ordinary inputs and dropped it for odd ones would look identical to F1's
## eye if F1 only checked rc. So: an ordinary family name must come through the same path.
set f5sch [file join $dir f5.sch]
wr_sch $f5sch {Monospace} {}
set f5 [child $dir f5 [list "xschem load $f5sch" "xschem zoom_full" \
  "xschem print svg [file join $dir f5.svg]" "puts SVG-OK"]]
lassign $f5 f5rc f5death f5out
check "F5 (1608 control) the same export path carries an ORDINARY `font=Monospace` through to\
 the exported font-family, so F1-F4 are measuring a value that arrived and not an attribute\
 the exporter stopped emitting" \
  [expr {$f5rc == 0 && !$f5death \
         && [lsearch -exact [svg_fams [file join $dir f5.svg]] {Monospace}] >= 0}] \
  "(rc=$f5rc death=$f5death fams={[svg_fams [file join $dir f5.svg]]})"

## ---- the command-line door: xinit.c's Tcl_AppInit. It is reached BEFORE the GUI exists and
## is not gated by running_in_src_dir, so it works in-tree. A --rcfile that does not resolve
## makes xschem print the composed name and Tcl_Exit(EXIT_FAILURE), so this door PRINTS the
## formatted result -- which is what lets these rows assert the value verbatim.
foreach {rid spec was} {F6 {%-2000d} {rc 134, *** buffer overflow detected ***}
                        F7 {%nd}     {rc 134, *** %n in writable segments detected ***}
                        F8 {%s}      {rc 139, SIGSEGV in the %s arm's strlen of an unpushed vararg}} {
  set r [child $dir [string tolower $rid] [list "puts RC-OK"] [list --rcfile $spec]]
  lassign $r rrc rdeath rout
  check "$rid (1608) `--rcfile '$spec'` -- xinit.c's Tcl_AppInit passed the command-line\
 argument itself as the format string. It now reports the name it could not find, VERBATIM,\
 and exits 1. At 91bb1bd7: $was" \
    [expr {$rrc == 1 && !$rdeath && [string first "cannot find $spec" $rout] >= 0}] \
    "(rc=$rrc death=$rdeath want=1 out={[string range [string trim $rout] end-60 end]})"
}

## the --rcfile control: a real file is still sourced, so F6-F8 are not passing because the
## option stopped working.
set f9rc_file [file join $dir ok_rc.tcl]
spew $f9rc_file "set ::zz_1608_rc_sourced 1\n"
set f9 [child $dir f9 [list "puts \"SOURCED=<\$::zz_1608_rc_sourced>\""] [list --rcfile $f9rc_file]]
lassign $f9 f9rc f9death f9out
check "F9 (1608 control) a --rcfile naming a file that EXISTS is still sourced and the run\
 continues, so F6-F8 are measuring a rejected name and not a broken option" \
  [expr {$f9rc == 0 && !$f9death && [string first {SOURCED=<1>} $f9out] >= 0}] \
  "(rc=$f9rc death=$f9death out={[string range [string trim $f9out] end-40 end]})"

## ============================================================================
## F10, F10b, F11 -- THE OUTPUT-NEUTRALITY GUARD IN svg_draw_string_line()
## ============================================================================
## THE ONE BEHAVIOUR DELTA THE `"%s"` FIX INTRODUCED IN EXPORTED OUTPUT, AND WHY IT IS FENCED
## RATHER THAN ACCEPTED. svg_font_family is char[80]. Before the fix a `font=` value with no `%`
## in it that did not fit was left out of the buffer ENTIRELY -- with no conversion in the format
## the tail copy is my_snprintf's only writer and it skips a run that does not fit -- so the
## array still held the svg_font_name it had been pre-loaded with two lines earlier, the strcmp
## in svg_draw_string_line() matched, and NO ATTRIBUTE WAS EMITTED. After the fix the value goes
## through the `%s` arm, which writes the '\0' first and then finds the value too long, so the
## array comes back EMPTY and the strcmp differs: `style="font-family:;"` -- an INVALID CSS
## declaration, since an empty value is not a font name. Hence the `svg_font_family[0] &&` guard
## at the emission site, which restores the absence.
##
## MEASURED, a from-scratch build of 91bb1bd7 against this tree, `font=` runs of Q of 78, 79, 80,
## 81 and 2000 characters, both doors (a .sch's own text and a .sym text reached through an
## instance), `--nogui` with DISPLAY unset: 79 and below emit the value verbatim on BOTH trees;
## 80 and above emit no attribute on BOTH trees; and all ten exported .svg files are
## BYTE-IDENTICAL between the two binaries. The threshold is 80 = S(svg_font_family), not 81:
## the `%s` arm needs n+l+1 <= size for l = strlen(value).
##
## ⚠ TWO ROWS, AND NEITHER IS SUFFICIENT ALONE. F10/F10b assert the ABSENCE for an over-long
## value, which a binary that stopped emitting font-family at all would also satisfy; F11
## asserts an ordinary long-but-fitting value still arrives VERBATIM, which is what makes the
## absence mean something. F5 is the same control at a short value; F11 is the one at the
## boundary.
## ⚠ AND THE LENGTHS ARE CHOSEN SO A BUFFER RESIZE READS CORRECTLY: F10/F10b use 2000, far over
## any plausible size, so ENLARGING svg_font_family cannot redden them; F11 uses 79, which IS
## S(svg_font_family)-1 at this commit, so SHRINKING the buffer reddens F11 and its detail prints
## the emitted family, saying the boundary moved rather than leaving a mystery.
## ⚠ NOT A ROW, AND STATED HERE BECAUSE IT IS THE ONE PLACE THE GUARD IS NOT THE PRE-FIX OUTPUT:
## svg_draw_symbol()'s pin-name pass takes svg_font_family from a PINLAYER rect's `name_font` and
## already used the `"%s"` form at 91bb1bd7, with no pre-load of svg_font_name before it, so an
## 80-character `name_font` emitted `style="font-family:;"` on BOTH trees -- driven, with a
## symbol carrying `B 5 ... {name=PA dir=in show_pinname=true name_font=<80 chars>}`. The guard
## suppresses that too, which is a deliberate improvement on the pre-fix output rather than a
## match to it.

set f10sch [file join $dir f10.sch]
wr_sch $f10sch [string repeat Q 2000] {}
set f10 [child $dir f10 [list "xschem load $f10sch" "xschem zoom_full" \
  "xschem print svg [file join $dir f10.svg]" "puts SVG-OK"]]
lassign $f10 f10rc f10death f10out
set f10svg [slurp [file join $dir f10.svg]]
set f10attr [regexp -all {style="font-family:} $f10svg]
set f10txt  [regexp -all {<text} $f10svg]
check "F10 (1608) a .sch text object whose `font=` value is 2000 characters -- far longer than\
 svg_font_family's char\[80\] and containing no `%` at all -- exports with the text present and\
 ZERO per-text `style=\"font-family:\"` attributes, which is byte-for-byte what 91bb1bd7 did.\
 THE GUARD IS `svg_font_family\[0\] &&` in svg_draw_string_line(): without it the `\"%s\"` fix\
 emits `style=\"font-family:;\"`, an invalid CSS declaration asserting an empty font name where\
 the absent attribute correctly says nothing. This is svg_draw()'s door" \
  [expr {$f10rc == 0 && !$f10death && [string first SVG-OK $f10out] >= 0 \
         && $f10attr == 0 && $f10txt >= 1}] \
  "(rc=$f10rc death=$f10death per_text_attrs=$f10attr want=0 text_elements=$f10txt)"

wr_sym [file join $dir f10b.sym] [string repeat Q 2000]
set f10bsch [file join $dir f10b.sch]
spew $f10bsch "v {xschem version=3.4.8 file_version=1.3}\nG {}\nK {}\nV {}\nS {}\nE {}\nC {f10b.sym} 0 0 0 0 {name=x1}\n"
set f10b [child $dir f10b [list "xschem load $f10bsch" "xschem zoom_full" \
  "xschem print svg [file join $dir f10b.svg]" "puts SVG-OK"]]
lassign $f10b f10brc f10bdeath f10bout
set f10bsvg [slurp [file join $dir f10b.svg]]
set f10battr [regexp -all {style="font-family:} $f10bsvg]
set f10btxt  [regexp -all {<text} $f10bsvg]
check "F10b (1608) the same over-long `font=` value reached through svg_draw_symbol()'s door --\
 a .sym text carrying it, instantiated in a .sch with no text of its own, so the emission can\
 only have come from the symbol pass. Same absence, same reason. The two doors share ONE reader\
 (svg_draw_string_line), so this row does not fence a second guard; it fences the claim that the\
 threshold and the absence are the same at both, which is what makes the byte-identity claim in\
 the comment above cover a stranger's SYMBOL LIBRARY and not only their schematic" \
  [expr {$f10brc == 0 && !$f10bdeath && [string first SVG-OK $f10bout] >= 0 \
         && $f10battr == 0 && $f10btxt >= 1}] \
  "(rc=$f10brc death=$f10bdeath per_text_attrs=$f10battr want=0 text_elements=$f10btxt)"

set f11sch [file join $dir f11.sch]
wr_sch $f11sch [string repeat Q 79] {}
set f11 [child $dir f11 [list "xschem load $f11sch" "xschem zoom_full" \
  "xschem print svg [file join $dir f11.svg]" "puts SVG-OK"]]
lassign $f11 f11rc f11death f11out
set f11fams [svg_fams [file join $dir f11.svg]]
## lengths, not the 79-character strings themselves, so the detail line stays readable. Spelled
## with foreach rather than lmap: this file is run by whatever tclsh is on PATH and the tree
## targets 8.4 upward.
set f11lens {} ; foreach x $f11fams { lappend f11lens [string length $x] }
check "F11 (1608 control, the BOUNDARY one) a `font=` value of 79 characters -- one less than\
 S(svg_font_family) at this commit -- still reaches the exported font-family VERBATIM, all 79\
 characters of it. This is what stops F10/F10b being satisfied by a binary that dropped the\
 attribute for everything, and it is the assertion that pins WHERE the boundary is: 79 emitted,\
 80 absent. A red here with an empty family means svg_font_family was made SMALLER -- the\
 detail prints the length that did arrive" \
  [expr {$f11rc == 0 && !$f11death && [string first SVG-OK $f11out] >= 0 \
         && [lsearch -exact $f11fams [string repeat Q 79]] >= 0}] \
  "(rc=$f11rc death=$f11death emitted_lengths={$f11lens} want=79 nfams=[llength $f11fams])"

# ============================================================================
# SECTION W and P and G — everything that needs the compiler
# ============================================================================
set CC [lindex [auto_execok gcc] 0]
set MKC [file join $repo Makefile.conf]
set CFLAGS ZZNONE
if {[file exists $MKC]} {
  foreach l [split [slurp $MKC] "\n"] {
    if {[regexp {^CFLAGS=(.*)$} $l . v]} { set CFLAGS $v }
  }
}
## The rows that cannot run without gcc, in ONE place: row_skip() names them in the skip line
## AND feeds them to X1's row-id set. X1 additionally asserts that every id here was actually
## exercised when gcc IS present, so a renamed or deleted G/W/P row cannot leave a stale name
## in the skip line -- the one direction a list like this can be kept honest in.
set gwp_rows {G1 G2 G3 G4 G5 G6 G7 G8 G9 G10 G11 G12 G13 G14 G15 W1 W2 P1 P2 P3 \
              M1 M2 M3 M4 M5 M6}
if {$CC eq {} || $CFLAGS eq {ZZNONE}} {
  row_skip $gwp_rows "no gcc on PATH ([string length $CC] chars) or no CFLAGS line in the\
 generated Makefile.conf, so neither the formatter can be linked into a driver nor the\
 compiler's own -Wformat opinion taken. Section F still drove the five call sites through the\
 built binary, and S1, S2 and X1 still ran"
} else {
set cdir [file join $dir cc] ; file mkdir $cdir
set SRC [file join $repo src]

# ----------------------------------------------------------------------------
# SECTION W — THE COMPILER'S OWN OPINION
# ----------------------------------------------------------------------------
## ⚠ NEITHER FLAG ALONE IS THE ANSWER, AND THE TWO NAME DIFFERENT THINGS. Measured over all of
## src/*.c at the build's own CFLAGS: -Wformat-security warns ONLY for a non-literal format with
## NO arguments, so `my_snprintf(buf, n, userfmt, 7)` produces nothing from it at all and needs
## -Wformat-nonliteral; while all five of 1608's real call sites ARE zero-argument, so a probe
## with one of them reverted is tagged `[-Wformat-security]` under `-Wformat` alone, under
## `-Wformat -Wformat-security` AND under `-Wformat -Wformat-nonliteral` -- the tag never becomes
## -Wformat-nonliteral, which is why a filter keyed on that flag NAME went green on a tree with a
## real door reopened. Conversely the clean tree's own diagnostics all carry an argument and are
## all `[-Wformat-nonliteral]`, with -Wformat-security reporting none of them. So W1 collects the
## WHOLE `[-Wformat` family and W2 drives both shapes. Nor does -Wformat-overflow ever apply to a
## user function carrying the format attribute -- only to the builtins whose destination gcc knows.
proc wcompile {cc cflags extra files srcdir wdir tag} {
  set cmd {}
  foreach f $files {
    append cmd "$cc -fsyntax-only $cflags $extra [file join $srcdir $f]\
 > [file join $wdir $tag.[file tail $f].log] 2>&1 ; echo done >\
 [file join $wdir $tag.[file tail $f].ran] & "
  }
  append cmd "wait"
  catch {exec sh -c $cmd}
  set diags {} ; set missing {}
  foreach f $files {
    if {![file exists [file join $wdir $tag.[file tail $f].ran]]} { lappend missing $f ; continue }
    foreach l [split [slurp [file join $wdir $tag.[file tail $f].log]] "\n"] {
      ## ⚠ THE WHOLE -Wformat FAMILY, NOT ONLY -Wformat-nonliteral, AND THAT IS A MEASURED
      ## REQUIREMENT. Reverting one of the five real call sites and running this row with a
      ## `-Wformat-nonliteral`-only filter left it GREEN: gcc reports a non-literal format
      ## with NO ARGUMENTS as `-Wformat-security`, and all five 1608 call sites are
      ## zero-argument calls, so the one filter that mattered was the one missing. On the clean
      ## tree every diagnostic of the whole family falls on one of the two deliberate sprintf
      ## shapes W1 names BY THEIR TEXT -- and W1 permits them by that text and not by any count,
      ## per named limit L9: the total moves the day anyone adds another deliberate non-literal
      ## sprintf, which is a spelling change and not a regression.
      if {[string first {[-Wformat} $l] >= 0} { lappend diags [string trim $l] }
    }
  }
  return [list $diags $missing]
}
## every diagnostic's source line, read back out of the file gcc named, so the row keys on the
## TEXT at the site and not on a line number (line numbers rot; the brief says cite by symbol).
proc wdiag_lines {diags} {
  set out {}
  foreach d $diags {
    if {[regexp {^([^:]+):([0-9]+):[0-9]+:} $d . f n]} {
      set txt ""
      set i 1
      if {[file exists $f]} {
        set fd [open $f r]
        while {[gets $fd ln] >= 0} { if {$i == $n} { set txt [string trim $ln] ; break } ; incr i }
        close $fd
      }
      lappend out [list [file tail $f]:$n $txt]
    } else { lappend out [list $d {}] }
  }
  return $out
}

set wsrcs {}
foreach f [lsort [glob -nocomplain -directory $SRC *.c]] { lappend wsrcs [file tail $f] }
set W1 [wcompile $CC $CFLAGS {-Wformat -Wformat-nonliteral} $wsrcs $SRC $cdir w1]
set w1lines [wdiag_lines [lindex $W1 0]]
## THE RULE: a -Wformat-nonliteral diagnostic may fall only on a line that is a plain
## `sprintf(` with a non-literal format -- the `sprintf(nstr, nfmt, <value>)` calls inside
## my_snprintf itself, which are its whole design and are what my_snprintf_spec_ok() guards,
## and draw.c's `sprintf(tmpstr, fmt1/fmt2, ...)` calls, which are issue 1606's class and
## carry their own comment saying so. It may NEVER fall on a line spelling `my_snprintf(`.
## ⚠ NO NUMBER OF SITES IS WRITTEN HERE, AND THAT IS NAMED LIMIT L9 EARNING ITS KEEP. An earlier
## version of this paragraph said "the three `sprintf(nstr, nfmt, i)` calls" and issue 1609 made
## it wrong the same week, by splitting the d/x/c/u arm's single call into one per argument type
## (`i`, `lv`, `ulv`) -- a spelling change and not a regression. The permitted TEXT is
## `sprintf(nstr, nfmt,` up to the comma, which is why it already covered the new spellings and
## needed no edit; the two SHAPES this row enumerates are still two. The detail line reports
## `total_nonliteral_diags` so a reader can see the figure without anyone writing it down.
## ⚠ THIS IS THE 1608 PROPERTY AND NOT A TREE-WIDE ZERO. A tree-wide zero would need a real
## `#pragma GCC diagnostic` at every one of the deliberate sites, and THIS TREE HAS NO `#pragma`
## DIRECTIVE ANYWHERE: `/usr/bin/grep -rln '#pragma' src/` names src/util.c and nothing else, and
## the hit in util.c is the sentence in its own comment saying so. ⚠ NO COUNT IS QUOTED HERE, AND
## THAT IS NAMED LIMIT L9: the grep reads the file this sentence lives in, so any number written
## down here is a hostage to how this sentence happens to be laid out -- which is exactly how the
## same claim shipped wrong twice before, `-rc` counting LINES and the rewrite spreading the word
## over three of them. 1608 is not the issue that should introduce a real pragma at draw.c's
## sites. So the row asserts what it can defend, and names the two permitted shapes rather than
## any count of diagnostics.
set w1bad {}
foreach p $w1lines {
  set txt [lindex $p 1]
  if {[string first {my_snprintf(} $txt] >= 0} { lappend w1bad $p ; continue }
  if {[string first {sprintf(nstr, nfmt,} $txt] >= 0} continue
  if {[regexp {sprintf\(tmpstr, fmt[12],} $txt]} continue
  lappend w1bad $p
}
check "W1 (1608) compiling every src/*.c with the build's own CFLAGS plus `-Wformat\
 -Wformat-nonliteral` and collecting the WHOLE -Wformat family puts NO diagnostic on a line\
 spelling `my_snprintf(`, and none anywhere except the two DELIBERATE non-literal sprintf\
 shapes, matched by their text: `sprintf(nstr, nfmt,` inside my_snprintf (which\
 my_snprintf_spec_ok guards) and draw.c's `sprintf(tmpstr, fmt1/fmt2,` (issue 1606's class).\
 With the format(printf,3,4) attribute on util.h's declaration any call passing a non-literal\
 format -- or the wrong argument type to a literal one -- is the compiler's own complaint, and\
 no decoy in the source text can fool it. ⚠ The family and not one flag: a\
 -Wformat-nonliteral-only filter left this row GREEN with a real site reverted, because gcc\
 reports a non-literal format with NO ARGUMENTS as -Wformat-security and all five real sites\
 are zero-argument calls" \
  [expr {[llength $w1bad] == 0 && [lindex $W1 1] eq {}}] \
  "(offending={$w1bad} total_nonliteral_diags=[llength $w1lines] missing={[lindex $W1 1]})"

## W2 — ANTI-VACUITY, AND WITHOUT IT W1 IS WORTHLESS. Remove the attribute from util.h and W1
## goes green on a tree with every door reopened, because gcc then has no opinion to give. A
## `-w` or a `-Wno-format` anywhere in the generated Makefile.conf's CFLAGS does the same. So:
## compile a synthetic file that #includes the REAL src/xschem.h and MUST produce the
## diagnostic, at the build's own flags and with the extras, and require it.
## Both shapes are driven on purpose: the zero-argument one (which is all -Wformat-security
## would have seen) and the one WITH an argument (which only -Wformat-nonliteral sees).
set w2f [file join $cdir zz_nonlit_1608.c]
spew $w2f "#include \"xschem.h\"\nvoid zz_nonlit_1608(const char *uf);\nvoid zz_nonlit_1608(const char *uf)\n\{\n  char b\[80\];\n  my_snprintf(b, sizeof b, uf);\n  my_snprintf(b, sizeof b, uf, 7);\n\}\n"
set W2 [wcompile $CC "$CFLAGS -I$SRC" {-Wformat -Wformat-nonliteral} \
          [list [file tail $w2f]] $cdir $cdir w2]
set w2log [slurp [file join $cdir w2.[file tail $w2f].log]]
check "W2 (1608 anti-vacuity for W1) a synthetic file that #includes the tree's real\
 src/xschem.h and calls `my_snprintf(b, sizeof b, uf)` and `my_snprintf(b, sizeof b, uf, 7)`\
 DOES produce a -Wformat-nonliteral diagnostic for the second shape. If util.h loses the format\
 attribute, or a `-w` reaches the generated Makefile.conf's CFLAGS, this row reddens instead of\
 letting W1 pass on a tree with every door reopened. ⚠ `-Wno-format` in CFLAGS does NOT redden\
 it, driven: this row appends `-Wformat -Wformat-nonliteral` AFTER CFLAGS, so a later enable\
 beats the earlier disable -- and W1, which appends the same, is not weakened by it either\
 (measured: `-Wno-format` in CFLAGS plus a real site reverted still reddens W1). `-w` is\
 different because it is not overridden by a later -W flag" \
  [expr {[llength [lindex $W2 0]] >= 1 && [lindex $W2 1] eq {} \
         && [string first {-Wformat-nonliteral} $w2log] >= 0}] \
  "(nonliteral_diags=[llength [lindex $W2 0]] missing={[lindex $W2 1]}\
 security_seen=[string first {-Wformat-security} $w2log]\
 log={[string range [string trim $w2log] 0 200]})"

# ----------------------------------------------------------------------------
# SECTION P — THE CENSUS, OVER gcc -E OUTPUT
# ----------------------------------------------------------------------------
## ⚠ A CENSUS OVER SOURCE TEXT IS A CENSUS OF SPELLINGS, MEASURED. Four plants at one real
## caller, each driven to rc 134 in this batch: a `#define`d width (`"%" WPFX "d"`) and a
## `#define`d format are MIS-BUCKETED as non-literal, and `#define XSNP my_snprintf` makes the
## call VANISH FROM THE CENSUS ENTIRELY. `gcc -E` with the tree's real CFLAGS is immune to all
## four, and to comments, `#if 0`, adjacent-literal splitting and dead preprocessor arms --
## and it is the only instrument that answers what COMPILES.
proc cens_calls {txt} {
  set out {} ; set n [string length $txt] ; set i 0
  while {1} {
    set p [string first "my_snprintf" $txt $i]
    if {$p < 0} break
    set i [expr {$p + 11}]
    if {$p > 0 && [string match {[A-Za-z0-9_]} [string index $txt [expr {$p - 1}]]]} continue
    ## the preceding non-space token `size_t` means a DECLARATION or the DEFINITION, not a
    ## call. util.h's declaration is inlined into every translation unit and would otherwise
    ## be counted as a non-literal format once per file.
    set before [string range $txt [expr {$p - 40 < 0 ? 0 : $p - 40}] [expr {$p - 1}]]
    if {[regexp {(^|[^A-Za-z0-9_])size_t\s*\*?\s*$} $before]} continue
    set j $i
    while {$j < $n && [string is space [string index $txt $j]]} { incr j }
    if {[string index $txt $j] ne "("} continue
    set depth 0 ; set args {} ; set cur "" ; set k $j ; set st code ; set closed 0
    while {$k < $n} {
      set c [string index $txt $k]
      if {$st eq "code"} {
        if {$c eq "\""} { set st str ; append cur $c } \
        elseif {$c eq "'"} { set st chr ; append cur $c } \
        elseif {$c eq "("} { incr depth ; if {$depth > 1} { append cur $c } } \
        elseif {$c eq ")"} {
          incr depth -1
          if {$depth == 0} { lappend args $cur ; set closed 1 ; incr k ; break }
          append cur $c
        } elseif {$c eq "," && $depth == 1} { lappend args $cur ; set cur "" } \
        else { append cur $c }
      } elseif {$st eq "str"} {
        append cur $c
        if {$c eq "\\"} { incr k ; append cur [string index $txt $k] } \
        elseif {$c eq "\""} { set st code }
      } else {
        append cur $c
        if {$c eq "\\"} { incr k ; append cur [string index $txt $k] } \
        elseif {$c eq "'"} { set st code }
      }
      incr k
    }
    set i $k
    if {!$closed || [llength $args] < 3} continue
    lappend out $args
  }
  return $out
}
## Adjacent string literals are JOINED, which C does in translation phase 6 -- so a `%.*`
## split across two literals is a real shape this sees and a grep for the token does not.
proc cens_literal {arg} {
  set a [string trim $arg]
  if {![string match "\"*" $a]} { return [list 0 {}] }
  set res "" ; set i 0 ; set n [string length $a]
  while {$i < $n} {
    while {$i < $n && [string is space [string index $a $i]]} { incr i }
    if {$i >= $n} break
    if {[string index $a $i] ne "\""} { return [list 0 {}] }
    incr i
    while {$i < $n} {
      set c [string index $a $i]
      if {$c eq "\\"} {
        set e [string index $a [expr {$i + 1}]]
        switch -- $e {
          n { append res "\n" } t { append res "\t" } r { append res "\r" }
          "\\" { append res "\\" } "\"" { append res "\"" } "'" { append res "'" }
          default { append res $e }
        }
        incr i 2 ; continue
      }
      if {$c eq "\""} { incr i ; break }
      append res $c ; incr i
    }
  }
  return [list 1 $res]
}
## my_snprintf's OWN scanner semantics, deliberately: fmt is re-set at every `%` and a
## conversion closes at the next s/d/x/c/u/p/g/e/f. A stray `%` far from a letter therefore
## shows up as a LONG spec, which is exactly what GUARD 1 would refuse.
proc cens_specs {fmt} {
  set out {} ; set start -1 ; set n [string length $fmt]
  for {set i 0} {$i < $n} {incr i} {
    set c [string index $fmt $i]
    if {$c eq "%"} { set start $i }
    if {$start >= 0 && [string first $c "sdxcupgef"] >= 0} {
      lappend out [list [string range $fmt $start $i] $c] ; set start -1
    }
  }
  return $out
}
## The three guards re-implemented over the spec TEXT, with the same thresholds. ⚠ WHAT THIS
## CANNOT DO, because the first version of this comment claimed it could: it CANNOT see a
## divergence between itself and src/util.c's my_snprintf_spec_ok(). It is a Tcl copy measured
## against the tree's literals, so it answers "are the tree's own literals inside these
## thresholds?" and nothing else. Driven, both directions: on a tree with the whole 1608 fix
## reverted -- where my_snprintf_spec_ok() does not exist at all -- P2 is GREEN; and with
## GUARD 2's flags/`.` line removed, so the C guard began refusing the LIVE specs `%.16g` and
## `%.17g`, P2 stayed GREEN while G7 and G10 caught it. The C guard's behaviour is section G's
## job, and only section G's.
proc cens_verdict {spec nfmtsize nstrsize} {
  set len [string length $spec]
  if {$len >= $nfmtsize} { return "GUARD1 spec is $len chars, nfmt is $nfmtsize" }
  set max 0
  for {set i 1} {$i + 1 < $len} {incr i} {
    set c [string index $spec $i]
    if {[string match {[0-9]} $c]} {
      set run 0
      while {$i + 1 < $len && [string match {[0-9]} [string index $spec $i]]} {
        if {$run < 1000000} { set run [expr {$run * 10 + [string index $spec $i]}] }
        incr i
      }
      if {$run > $max} { set max $run }
      incr i -1
    } elseif {$c in {- + " " # .}} { continue } elseif {$c in {l h}} { continue } \
      else { return "GUARD2 whitelist rejects '$c'" }
  }
  if {$max + 320 >= $nstrsize} { return "GUARD3 digit run $max + 320 >= $nstrsize" }
  return ok
}

set pdir [file join $cdir pp] ; file mkdir $pdir
set pcalls 0 ; set plits 0 ; set pnonlit {} ; set pconv 0 ; set pmax 0
set prefused {} ; set pstars {} ; set pmissing {}
## ⚠ PER-ARM COUNTS, BECAUSE P3's NAME USED TO CLAIM THEM AND NOTHING TRACKED THEM. The four
## arms of my_snprintf() are keyed by the conversion letter, and cens_specs() already returns
## it, so the census can answer per arm instead of the row's name asserting it on trust.
array set parm {s 0 i 0 p 0 f 0}
proc parm_of {c} {
  if {$c eq {s}} { return s }
  if {[string first $c {dxcu}] >= 0} { return i }
  if {$c eq {p}} { return p }
  return f
}
set pcmd {}
foreach f [lsort [glob -nocomplain -directory $SRC *.c]] {
  append pcmd "$CC -E $CFLAGS $f > [file join $pdir [file tail $f].i] 2>/dev/null & "
}
append pcmd "wait"
catch {exec sh -c $pcmd}
foreach f [lsort [glob -nocomplain -directory $SRC *.c]] {
  set e [file join $pdir [file tail $f].i]
  if {![file exists $e] || [file size $e] == 0} { lappend pmissing [file tail $f] ; continue }
  foreach a [cens_calls [slurp $e]] {
    incr pcalls
    lassign [cens_literal [lindex $a 2]] ok fmt
    if {!$ok} { lappend pnonlit "[file tail $f]: [string trim [lindex $a 2]]" ; continue }
    incr plits
    foreach sp [cens_specs $fmt] {
      incr pconv
      set spec [lindex $sp 0]
      incr parm([parm_of [lindex $sp 1]])
      if {[string length $spec] > $pmax} { set pmax [string length $spec] }
      if {[string first "*" $spec] >= 0} { lappend pstars "[file tail $f]: |$spec|" }
      if {[lindex $sp 1] ne "s"} {
        set v [cens_verdict $spec 50 512]
        if {$v ne "ok"} { lappend prefused "[file tail $f]: |$spec| $v" }
      }
    }
  }
}
check "P1 (1608) censusing `gcc -E` output of every src/*.c at the build's own CFLAGS finds\
 ZERO my_snprintf calls whose format argument is not a string literal. A second, independent\
 instrument for the same property W1 asks the compiler about -- and the one immune to the\
 four spelling decoys this batch planted and drove, including `#define XSNP my_snprintf`,\
 which makes a call vanish from any source-text census" \
  [expr {[llength $pnonlit] == 0 && $pmissing eq {}}] \
  "(nonliteral={$pnonlit} calls=$pcalls literal=$plits conversions=$pconv\
 missing={$pmissing})"

check "P2 (1608) no LITERAL conversion spec in the compiled tree that REACHES A GATED ARM is\
 refused by any of my_snprintf_spec_ok()'s three guards, re-implemented over the preprocessed\
 spec text: none is 50 characters or longer, none contains a character outside the\
 flags/digits/`.` whitelist plus `l` and `h`, and none carries a digit run within 320 of nstr;\
 and separately, NO spec at all in the tree -- gated arm or not -- contains a `*`. So the guards\
 cost no live caller its output -- which is the claim a reviewer would most reasonably doubt.\
 ⚠ `%s` SPECS ARE DELIBERATELY NOT SUBMITTED TO THE THREE GUARDS HERE, because my_snprintf's\
 `%s` arm does not submit them either: it never builds nfmt and never calls\
 my_snprintf_spec_ok(). So a long `%s` spec is outside this row by construction and not by\
 oversight -- it is also outside the product's gate, which is named limit L3's defect and not\
 this one's. An earlier version of this name said `anywhere in the compiled tree`, which reads\
 as covering the one arm the row skips" \
  [expr {[llength $prefused] == 0 && [llength $pstars] == 0}] \
  "(refused={$prefused} stars={$pstars} max_literal_spec_len=$pmax)"

## ⚠ ANTI-VACUITY FOR P1 AND P2, AND IT IS A FLOOR, NOT A COUNT. A parser that found nothing
## would satisfy both rows silently. The floor is deliberately far below the measured figure
## so that adding or removing callers never reddens it: four different totals for this one
## question already exist in this batch's receipts (769 grep lines, 752 source-text calls, 722
## by an independent preprocessed parser at 91bb1bd7, and Stage A's 729), which is exactly why
## no row here asserts one.
## ⚠ THE ARM CLAIM IS ASSERTED NOW, AND NOT FOR ALL FOUR ARMS. The first version of this row
## said it "found at least one conversion in each of the four arms" and NOTHING IN THE ROW
## TRACKED ARMS AT ALL -- the claim happened to be true and was not measured. It is measured
## here for the three arms with many live callers. The `p` arm deliberately gets NO floor: the
## whole tree has exactly ONE live `%p` literal (util.c's pointer trace behind `debug_var > 2`),
## so a floor of one on it would redden the day someone deletes a debug line, which is a
## spelling change and not a regression. Its count is REPORTED instead, in the detail.
check "P3 (1608 anti-vacuity for P1 and P2) the preprocessed census actually parsed the tree:\
 it resolved more than 600 my_snprintf call expressions with at least three arguments, over\
 more than 30 preprocessed translation units, and found at least one conversion in EACH OF THE\
 THREE ARMS WITH MANY LIVE CALLERS -- `%s`, the integer arm (d/x/c/u) and the float arm\
 (g/e/f). FLOORS, never counts. The `p` arm's count is reported and not asserted, because the\
 tree has exactly one live `%p` literal" \
  [expr {$pcalls > 600 && $plits > 600 && $pconv > 1000 \
         && $parm(s) >= 1 && $parm(i) >= 1 && $parm(f) >= 1 \
         && [llength [glob -nocomplain -directory $pdir *.i]] > 30}] \
  "(calls=$pcalls literal=$plits nonliteral=[llength $pnonlit] conversions=$pconv\
 arm_s=$parm(s) arm_int=$parm(i) arm_float=$parm(f) arm_p=$parm(p)\
 units=[llength [glob -nocomplain -directory $pdir *.i]] max_literal_spec_len=$pmax\
 instrument={gcc -E over src/*.c at Makefile.conf CFLAGS, this suite's own parser})"

# ----------------------------------------------------------------------------
# SECTION G — my_snprintf DRIVEN DIRECTLY, THE TREE'S OWN src/util.c COMPILED IN
# ----------------------------------------------------------------------------
## ⚠ THE REAL FILE, NOT AN EXTRACTION. The 1606 batch's post-mortem names a `sed`-extracted
## copy of a function body as the instrument that produced a non-fact, and Stage B of this
## batch disclosed using one. This links the tree's own src/util.c, compiled with the build's
## own CFLAGS, against link stubs for the 22 globals and helpers it references but does not
## define. ONE FORK PER CASE, so a fortify abort is a recorded outcome.
spew [file join $cdir stubs.c] {/* link stubs: the REAL src/util.c linked into a driver */
#include <stdio.h>
#include <limits.h>
#ifndef PATH_MAX
#define PATH_MAX 4096
#endif
FILE *errfp;
int has_x = 0;
int debug_var = 0;
void *xctx = 0;
void *interp = 0;
FILE *actionlog_fp = 0;
char actionlog_filename[PATH_MAX];
char actionlog_pending[300];
int actionlog_pending_inst = -1;
int actionlog_suppress = 0;
int actionlog_suppress_echo = 0;
int actionlog_cmd_logged = 0;
char cli_opt_logdir[PATH_MAX];
int cli_opt_nolog = 0;
char home_dir[PATH_MAX];
int isonlydigit(const char *s){ (void)s; return 0; }
double snap_to_grid(double c){ return c; }
int str_is_blank(const char *s){ (void)s; return 1; }
const char *tcleval(const char str[]){ (void)str; return ""; }
const char *tclresult(void){ return ""; }
void tclsetvar(const char *s, const char *value){ (void)s; (void)value; }
char *Tcl_GetString(void *o){ (void)o; return (char *)""; }
void *Tcl_GetVar2Ex(void *a, const char *b, const char *c, int d)
{ (void)a; (void)b; (void)c; (void)d; return 0; }
}
spew [file join $cdir drv.c] {/* issue 1608: one fork per case; prints id|rc|sig|ret|canary|len|out */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <float.h>
#include <unistd.h>
#include <sys/wait.h>
extern unsigned long my_snprintf(char *s, unsigned long n, const char *f, ...);
#define BLOB 4096
#define CAN  'Q'
static char blob[BLOB];
typedef struct { const char *id; const char *fmt; char kind; long i; double d;
                 unsigned long size; } Case;
static void run_one(const Case *c)
{
  char spec[300];
  const char *fmt = c->fmt;
  unsigned long ret = 0;
  size_t i;
  /* a '#' format means "%<i dashes>d" and a '@' format "%<i dashes>p"; a '!' format means
   * "%<i dashes><fmt[1]>", i.e. the conversion letter is named explicitly, which is how the
   * g/e/f arm is reached with a dash run. The SPEC length varies while the OUTPUT stays
   * short -- which isolates GUARD 1 (the nfmt bound) from GUARD 3 (the nstr bound). '@'
   * exists so G12 can drive an over-long spec through the `p` arm, whose gate had no row at
   * all; '!' exists so G15 can drive one through the g/e/f arm, where the `if(!refuse)`
   * wrapper round the strncpy had no row that reddened on its own removal. */
  if(c->fmt[0] == '#' || c->fmt[0] == '@' || c->fmt[0] == '!') {
    char term = (c->fmt[0] == '@') ? 'p' : (c->fmt[0] == '!') ? c->fmt[1] : 'd';
    spec[0] = '%';
    for(i = 0; i < (size_t)c->i; i++) spec[1 + i] = '-';
    spec[1 + i] = term; spec[2 + i] = '\0';
    fmt = spec;
  }
  for(i = 0; i < BLOB; i++) blob[i] = CAN;
  /* ⚠ ONE NUL AT THE VERY END, AND IT IS LOAD-BEARING FOR G14. An UNWRITTEN destination is
   * G14's observable, and reporting strlen() of a buffer with no NUL in it at all would read
   * past the array. With this, "untouched" reports len 4095 and 40 canary bytes, while every
   * shape that writes reports its own short length -- measured identical to the pre-G14
   * figures for all six (D) cases. The canary at index size is unaffected: every size here
   * is far below BLOB-1. */
  blob[BLOB - 1] = '\0';
  switch(c->kind) {
    case 'i': ret = my_snprintf(blob, c->size, fmt, (int)c->i); break;
    /* ISSUE 1609: 'l' pushes a long and 'U' an unsigned long -- which is exactly what `%ld`
     * and `%lu`/`%lx` ask for, and what util.h's format attribute already forces every real
     * caller to hand them. The value is PLANTED: see the comment above row M1 for why no live
     * caller can ever produce one that discriminates. */
    case 'l': ret = my_snprintf(blob, c->size, fmt, (long)c->i); break;
    case 'U': ret = my_snprintf(blob, c->size, fmt, (unsigned long)c->i); break;
    case 'd': ret = my_snprintf(blob, c->size, fmt, c->d); break;
    case 's': ret = my_snprintf(blob, c->size, fmt, "xy"); break;
    case 'p': ret = my_snprintf(blob, c->size, fmt, (void *)0x58); break;
    default:  ret = my_snprintf(blob, c->size, fmt); break;
  }
  /* THE CANARY IS THE BYTE AT INDEX size -- exactly where mechanism (D) wrote */
  printf("%s|0|0|%lu|%s|%lu|", c->id, ret,
         blob[c->size] == CAN ? "intact" : "CLOBBERED",
         (unsigned long)(c->size ? strlen(blob) : 0));
  if(c->size) { for(i = 0; i < 40 && blob[i]; i++) putchar(blob[i]); }
  putchar('\n');
  fflush(stdout);
}
int main(int argc, char **argv)
{
  static const Case tab[] = {
    { "A1", "#", 'i', 47, 0.0, 80 },
    { "A2", "#", 'i', 48, 0.0, 80 },
    { "A3", "#", 'i', 49, 0.0, 80 },
    { "A4", "#", 'i', 200, 0.0, 80 },
    { "B1", "%nd",   'i', 7, 0.0, 80 },
    { "B2", "%.0Lf", 'd', 0, -DBL_MAX, 80 },
    { "B3", "%*d",   'i', 7, 0.0, 80 },
    { "B4", "%'.0f", 'd', 0, -DBL_MAX, 80 },
    { "B5", "%zd",   'i', 7, 0.0, 80 },
    { "B6", "%jd",   'i', 7, 0.0, 80 },
    { "B7", "%td",   'i', 7, 0.0, 80 },
    { "B8", "%qd",   'i', 7, 0.0, 80 },
    { "B9", "%ld",   'i', 65535, 0.0, 80 },
    { "BA", "%hu",   'i', 513, 0.0, 80 },
    { "C1", "%-2000d", 'i', 7, 0.0, 80 },
    { "C2", "%.192f",  'd', 0, -DBL_MAX, 900 },
    { "C3", "%.191f",  'd', 0, -DBL_MAX, 900 },
    { "C4", "%.60g",   'd', 0, -DBL_MAX, 900 },
    { "C5", "%.6f",    'd', 0, -DBL_MAX, 900 },
    { "D1", "abcd%d", 'i', 7, 0.0, 4 },
    { "D2", "abc%d",  'i', 7, 0.0, 4 },
    { "D3", "abcd%s", 's', 0, 0.0, 4 },
    { "D4", "abcd%g", 'd', 0, 1.5, 4 },
    { "D5", "abcd%p", 'p', 0, 0.0, 4 },
    { "D6", "%d",     'i', 7, 0.0, 0 },
    { "E1", "zz%.192f",  'd', 0, -DBL_MAX, 80 },
    { "E2", "zz%-2000d", 'i', 7, 0.0, 80 },
    { "E3", "zz%nd",     'i', 7, 0.0, 80 },
    { "I1", "x=%d",    'i', -2147483647L - 1, 0.0, 80 },
    { "I2", "x=%02x",  'i', 255, 0.0, 80 },
    { "I3", "x=%.16g", 'd', 0, 1.0 / 3.0, 80 },
    { "I4", "x=%g",    'd', 0, 1.0 / 3.0, 80 },
    { "I5", "x=%c",    'i', 65, 0.0, 80 },
    { "I6", "x=%u",    'i', 4294967295U, 0.0, 80 },
    { "I7", "x=%p",    'p', 0, 0.0, 80 },
    { "I8", "x=%s",    's', 0, 0.0, 80 },
    { "I9", "x=%.17g", 'd', 0, 1.0 / 3.0, 80 },
    { "IA", "a%db%gc", 'i', 0, 0.0, 80 },
    /* G12: hostile specs through the `p` ARM, the one arm whose gate had no row */
    { "PN", "%np",     'p', 0, 0.0, 80 },
    { "PW", "%-2000p", 'p', 0, 0.0, 80 },
    { "PL", "%.191Lp", 'p', 0, 0.0, 80 },
    { "PS", "%*p",     'p', 0, 0.0, 80 },
    { "PO", "@",       'p', 48, 0.0, 80 },
    /* G13: GUARD 3's digit-run overflow cap. 18446744073709551616 is 2^64 (wraps to 0) and
     * 18446744073709551716 is 2^64 + 100 (wraps to 100) -- both inside GUARD 1's 50. */
    { "R1", "%18446744073709551616d", 'i', 7, 0.0, 80 },
    { "R2", "%18446744073709551716d", 'i', 7, 0.0, 80 },
    /* G15: spec length 51 -- ONE PAST nfmt[50] -- through the `p` arm and through each of the
     * three conversion letters of the g/e/f arm. These are the two arms in which the
     * `if(!refuse)` wrapper round `strncpy(nfmt, fmt, l); nfmt[l] = '\0';` reddened NOTHING
     * when it was removed on its own. 51 and not 50: at 50 the store is the SILENT
     * one-byte-past (B), at 51 strncpy itself writes past the array and __strncpy_chk aborts,
     * so the DEATH is the discriminator. G1's 51- and 202-character dash runs already cover
     * the d/x/c/u arm. */
    { "PY", "@",  'p', 49, 0.0, 80 },
    { "FG", "!g", 'd', 49, 0.0, 80 },
    { "FF", "!f", 'd', 49, 0.0, 80 },
    { "FE", "!e", 'd', 49, 0.0, 80 },
    /* ===== ISSUE 1609: FETCH BY THE SPEC'S OWN LENGTH MODIFIER =====
     * Rows M1 (the `long` fetch) and M2 (the `unsigned long` fetch). Every value below is
     * PLANTED and MUST BE -- see the comment above row M1. */
    { "L1", "%ld",     'l', 4294967338L, 0.0, 80 },            /* 2^32 + 42 */
    { "L2", "%ld",     'l', -1L, 0.0, 80 },
    { "L3", "%ld",     'l', 9223372036854775807L, 0.0, 80 },   /* LONG_MAX */
    { "L4", "[%12ld]", 'l', 4294967338L, 0.0, 80 },
    { "L5", "a=%ld b", 'l', 4294967338L, 0.0, 80 },
    { "L6", "%lu",     'U', 4294967338L, 0.0, 80 },
    { "L7", "%lx",     'U', 20015998341291L, 0.0, 80 },        /* 0x1234567890AB */
    { "L8", "%lu",     'U', -1L, 0.0, 80 },                    /* ULONG_MAX */
    { "L9", "%lx",     'U', -1L, 0.0, 80 },
    /* M3: the AGREEING BAND [0, 2^32), where the pre-1609 tree was already right and this
     * fix must therefore change NOTHING. Every live caller's values are in here. */
    { "LA", "%ld",     'l', 4294967295L, 0.0, 80 },
    { "LB", "%lu",     'U', 2147483649L, 0.0, 80 },
    { "LC", "%lx",     'U', 4294967295L, 0.0, 80 },
    { "LD", "[%12ld]", 'l', 4294967295L, 0.0, 80 },
    /* M4: GUARD 2b -- a REPEATED or MIXED length modifier is refused. MJ carries a literal
     * prefix so the refusal's own shape (prefix kept, conversion dropped) is visible too. */
    { "MA", "%lld",    'l', 42L, 0.0, 80 },
    { "MB", "%llu",    'U', 42L, 0.0, 80 },
    { "MC", "%llx",    'U', 42L, 0.0, 80 },
    { "MD", "%hhd",    'i', -1, 0.0, 80 },
    { "ME", "%hhu",    'i', 300, 0.0, 80 },
    { "MF", "%lhd",    'l', 7L, 0.0, 80 },
    { "MG", "%hld",    'i', 7, 0.0, 80 },
    { "MH", "%llld",   'l', 7L, 0.0, 80 },
    { "MI", "%hhhhd",  'i', 7, 0.0, 80 },
    { "MJ", "X%lldY",  'l', 7L, 0.0, 80 },
    /* M5: GUARD 2b's anti-vacuity -- a SINGLE modifier still formats, `l` on `c` included */
    { "MK", "%hd",     'i', -1, 0.0, 80 },
    { "ML", "%lc",     'i', 65, 0.0, 80 },
    { "MM", "[%lc]",   'i', 65, 0.0, 80 },
    /* M6: issue 1612's boundary -- `%c` of a byte >= 128 must stay a `%c` */
    { "MN", "[%c]",    'i', 233, 0.0, 80 },
    /* M4's OTHER TWO ARMS. GUARD 2b lives in the shared gate, so it is arm-independent, and
     * each of these was ACCEPTED before it. `X%llfY` is the sharp one: driven at 9fa31dd0 it
     * returned 6 and printed `X-nanY` from a correctly-pushed 1.5 -- glibc's `ll` on a
     * floating conversion is undefined and it does not report an error. */
    { "MO", "X%llfY",  'd', 0, 1.5, 80 },
    { "MP", "X%llpY",  'p', 0, 0.0, 80 },
    /* G14: the (D) refusal's NUL write, at a size well below the literal run, one per arm */
    { "N1", "abcd%d", 'i', 7, 0.0, 2 },
    { "N2", "abcd%s", 's', 0, 0.0, 2 },
    { "N3", "abcd%g", 'd', 0, 1.5, 2 },
    { "N4", "abcd%p", 'p', 0, 0.0, 2 },
    { NULL, NULL, 0, 0, 0.0, 0 }
  };
  int k;
  (void)argc; (void)argv;
  for(k = 0; tab[k].id; k++) {
    pid_t p;
    fflush(stdout);
    p = fork();
    if(p == 0) {
      if(!strcmp(tab[k].id, "IA")) {
        size_t i2; unsigned long r;
        for(i2 = 0; i2 < BLOB; i2++) blob[i2] = CAN;
        blob[BLOB - 1] = '\0';                  /* same bound as run_one(); see there */
        r = my_snprintf(blob, 80, "a%db%gc", 5, 2.5);
        printf("IA|0|0|%lu|%s|%lu|%s\n", r, blob[80] == CAN ? "intact" : "CLOBBERED",
               (unsigned long)strlen(blob), blob);
        fflush(stdout);
      } else run_one(&tab[k]);
      _exit(0);
    } else {
      int st = 0;
      waitpid(p, &st, 0);
      if(!WIFEXITED(st) || WEXITSTATUS(st) != 0) {
        printf("%s|%d|%d|-|-|-|DIED\n", tab[k].id,
               WIFEXITED(st) ? WEXITSTATUS(st) : -1,
               WIFSIGNALED(st) ? WTERMSIG(st) : 0);
        fflush(stdout);
      }
    }
  }
  printf("DRV-DONE\n");
  return 0;
}
}
set gbuilt 0 ; set gerr {} ; set G [dict create] ; set gout {}
set gcmd "$CC -c $CFLAGS -o [file join $cdir stubs.o] [file join $cdir stubs.c]\
 > [file join $cdir stubs.log] 2>&1 && \
 $CC -c $CFLAGS -o [file join $cdir util_t.o] [file join $SRC util.c]\
 > [file join $cdir util.log] 2>&1 && \
 $CC $CFLAGS -o [file join $cdir drv] [file join $cdir drv.c] [file join $cdir stubs.o]\
 [file join $cdir util_t.o] -lm > [file join $cdir link.log] 2>&1"
catch {exec sh -c $gcmd} gerr
if {[file executable [file join $cdir drv]]} {
  if {[catch {exec timeout 120 [file join $cdir drv] 2>@1} gout]} { }
  foreach ln [split $gout "\n"] {
    set p [split [string trim $ln] "|"]
    if {[llength $p] == 7} { dict set G [lindex $p 0] [lrange $p 1 end] }
  }
  set gbuilt [expr {[string first DRV-DONE $gout] >= 0}]
}
## {rc sig ret canary len out} for a case id, or {} if the driver never reported it
proc g {id} { if {[dict exists $::G $id]} { return [dict get $::G $id] } ; return {} }
proc g_ok   {id} { set v [g $id] ; expr {$v ne {} && [lindex $v 0] == 0 && [lindex $v 1] == 0} }
proc g_ret  {id} { lindex [g $id] 2 }
proc g_can  {id} { lindex [g $id] 3 }
proc g_len  {id} { lindex [g $id] 4 }
proc g_out  {id} { lindex [g $id] 5 }
## "refused" is this function's own overflow shape: the conversion and everything after it is
## dropped and the prefix written so far stays, NUL-terminated. With an empty prefix that is
## a zero-length result and a zero return.
proc g_refused {id} { expr {[g_ok $id] && [g_ret $id] == 0 && [g_len $id] == 0} }

check "G11 (1608 anti-vacuity for every G row) the driver built from the tree's own\
 src/util.c and ran to completion, and a control conversion still works: `x=%d` of INT_MIN\
 prints `x=-2147483648`. Without this row a compile failure would make every `refused` row\
 below pass on an empty dictionary" \
  [expr {$gbuilt && [g_out I1] eq {x=-2147483648} && [g_ret I1] == 13}] \
  "(built=$gbuilt rows=[dict size $::G] I1={[g I1]} err={[string range $gerr 0 200]}\
 util={[string range [slurp [file join $cdir util.log]] 0 200]}\
 link={[string range [slurp [file join $cdir link.log]] 0 200]})"

check "G1 (1608 GUARD 1, mechanisms A and B together) a spec of `%` + N dashes + `d` -- whose\
 OUTPUT stays two characters, so only the nfmt\[50\] bound is in play -- formats at length 49\
 and is refused at 50 and above. Length 50 is the one that matters: at 91bb1bd7 it returned a\
 formatted value and rc 1 while storing nfmt\[50\] ONE BYTE PAST the array, silently, because\
 a plain array store is not fortified. Length 51 aborted with SIGABRT. ONE guard covers both\
 because (B)'s threshold is the lower one" \
  [expr {[g_ok A1] && [g_ret A1] == 2 && [g_out A1] ne {} \
         && [g_refused A2] && [g_refused A3] && [g_refused A4]}] \
  "(l49={[g A1]} l50={[g A2]} l51={[g A3]} l202={[g A4]})"

check "G2 (1608 GUARD 2, and the reason the bound alone was never the fix) `%nd` is refused by\
 the spec whitelist with no signal. It is three characters producing no output, so it passes\
 GUARD 3 and every arithmetic bound; at 91bb1bd7 it was strncpy'd into a writable stack array\
 and handed to sprintf, and the process died with `*** %n in writable segments detected ***`\
 -- an attempted arbitrary write stopped only by glibc's PRINTF_FORTIFY, which is libc\
 hardening on one platform and not a property of this code" \
  [g_refused B1] "(pct_n={[g B1]})"

check "G3 (1608 GUARD 2, the L modifier that refutes GUARD 3's arithmetic) `%.0Lf` is refused.\
 It is a long double conversion, and LDBL_MAX reaches ~1.19e4932, so its output measures 4933\
 characters against GUARD 3's estimate of 320 -- the one shape a digit scan cannot bound. It\
 also mis-fetches, the arm reading va_arg(args, double): at 91bb1bd7 this case returned `nan`\
 formatted out of 10 uninitialised stack bytes" \
  [g_refused B2] "(L={[g B2]})"

check "G4 (1608 GUARD 2, the rest of the closed set) `%*d`, `%'.0f`, `%zd`, `%jd`, `%td` and\
 `%qd` are all refused, each driven through a caller that DOES push an argument. `*` takes its\
 width from a vararg this function never pushes; `'` is thousands grouping, dormant here only\
 because nothing in src/ calls setlocale, and 412 characters wide for THIS row's `%'.0f` in a\
 grouping locale -- 1 sign + 309 digits + 102 separators, measured against a locale built with\
 `localedef -i en_US -f UTF-8`, where `%'.6f` is the one that measures 419 and `%'.180f` 593;\
 the four size modifiers are unimplemented and returned garbage at 91bb1bd7. ⚠ This row asserts\
 the REFUSAL, never the abort -- see trap T4: at a door with no pushed vararg `%*d`'s width is\
 stack garbage and 5 of 7 measured environments did not abort at all" \
  [expr {[g_refused B3] && [g_refused B4] && [g_refused B5] && [g_refused B6] \
         && [g_refused B7] && [g_refused B8]}] \
  "(star={[g B3]} quote={[g B4]} z={[g B5]} j={[g B6]} t={[g B7]} q={[g B8]})"

check "G5 (1608 GUARD 2's PERMITTED set, and the row that makes the whitelist honest) `%ld`\
 and `%hu` still format. They are permitted deliberately: live callers in scheduler.c use\
 them -- `%hu`, `%ld` and `%lu`, in the getters that print the first selection, XMaxRequestSize,\
 XExtendedMaxRequestSize and a window id -- refusing them would change what `xschem globals`\
 prints, and their widest output is 20 characters -- far inside GUARD 3. ⚠ This name quotes NO\
 TOTAL of those callers (named limit L9): an earlier version said `three` and the itemisation\
 under it named four, one of which was a `%ld` inside a comment. They still mis-fetch, which is named and carried forward\
 in the issue and is NOT fixed. Without this row the whitelist could be tightened to refuse\
 every modifier and nothing here would notice the regression" \
  [expr {[g_ok B9] && [g_out B9] eq {65535} && [g_ok BA] && [g_out BA] eq {513}}] \
  "(ld={[g B9]} hu={[g BA]})"

check "G6 (1608 GUARD 3, the output bound) `%-2000d` and `%.192f` are refused. Both abort at\
 91bb1bd7. The bound is `largest digit run + 320`, from the measured max(width, 311 +\
 precision): sprintf(\"%f\", -DBL_MAX) is 317 and sprintf(\"%.200f\", -DBL_MAX) is 511 on this\
 glibc, and width and precision never add. ⚠ THE TWO CASES ARE REFUSED FOR DIFFERENT REASONS\
 AND THE DIFFERENCE IS NOT COSMETIC. `%-2000d` genuinely overflows: seven characters producing\
 2000 bytes in the INTEGER arm, far past the 512-byte scratch. `%.192f` does NOT overflow --\
 measured on this glibc, sprintf(\"%.192f\", -DBL_MAX) is 503 characters and the scratch holds\
 it comfortably. It is refused by the OVER-ESTIMATE, because 192 + 320 is 512 and the test is\
 `< 512`. That is the estimate being deliberately loose rather than per-arm casework (1606 lost\
 a hand-derived per-branch bound to a branch it did not cover), and G7's `%.191f` is the row\
 that says the looseness costs nothing live" \
  [expr {[g_refused C1] && [g_refused C2]}] "(w2000={[g C1]} p192={[g C2]})"

check "G7 (1608 GUARD 3's other half -- the ENLARGED scratch, and a live death fixed) with\
 nstr grown from 50 to MY_SNPRINTF_NSTR, `%.191f`, `%.60g` and `%.6f` of -DBL_MAX all FORMAT\
 instead of aborting: 502, 67 and 317 characters. ⚠ `%.6f` IS A LIVE LITERAL CALLER --\
 scheduler.c's net_hilight_march_offset getter -- so this is the one row here fencing a death\
 that needed no hostile input at all, only a large enough argument. A 50-byte scratch could\
 not hold it at any buffer size tried, which is why a pre-write check alone was not enough" \
  [expr {[g_ok C3] && [g_len C3] == 502 && [g_ok C4] && [g_len C4] == 67 \
         && [g_ok C5] && [g_len C5] == 317}] \
  "(p191={[g_len C3]}/{[g_ret C3]} g60={[g_len C4]} f6={[g_len C5]}\
 c5out={[string range [g_out C5] 0 24]})"

check "G8 (1608 mechanism D -- one byte past THE CALLER'S buffer, on all four arms) a canary\
 byte planted at index `size` survives. The guard read `if(n+l > size)`, so at n+l == size it\
 PASSED and `string\[size\]` was written; `string` is a pointer parameter, so\
 _FORTIFY_SOURCE cannot size it and emitted no check -- this one was SILENT. Driven here on\
 the d, s, g and p arms at size 4 with a four-character literal run, and at size 0, where the\
 old test also wrote string\[0\]. At 91bb1bd7 five of these six cases reported CLOBBERED with\
 rc 0 and no message" \
  [expr {[g_can D1] eq {intact} && [g_can D2] eq {intact} && [g_can D3] eq {intact} \
         && [g_can D4] eq {intact} && [g_can D5] eq {intact} && [g_can D6] eq {intact} \
         && [g_out D2] eq {abc}}] \
  "(d={[g D1]} fits={[g D2]} s={[g D3]} g={[g D4]} p={[g D5]} size0={[g D6]})"

check "G9 (1608 the refusal's ORDERING, which a crew drove to rc 0 on the wrong rc file) a\
 refused spec still leaves the caller the literal prefix already written: `zz%.192f`,\
 `zz%-2000d` and `zz%nd` all return 2 with the buffer holding exactly `zz`. The spec gate has\
 to run BEFORE strncpy, but a `break` there left the destination ENTIRELY UNWRITTEN -- driven\
 on a tree that did it, a planted caller printed uninitialised stack and the live `--rcfile\
 zz%.192f` returned RC 0 HAVING SILENTLY SOURCED A DIFFERENT RC FILE. Hence the `refuse`\
 flag: skip strncpy, fall through the prefix write, THEN break, which is the path this\
 function's existing overflow already takes" \
  [expr {[g_ok E1] && [g_out E1] eq {zz} && [g_ret E1] == 2 \
         && [g_ok E2] && [g_out E2] eq {zz} && [g_ok E3] && [g_out E3] eq {zz}}] \
  "(p192={[g E1]} w2000={[g E2]} pct_n={[g E3]})"

check "G10 (1608 identity -- the guards change no live conversion's output) every arm still\
 prints byte-for-byte what it printed at 91bb1bd7: `%d` of INT_MIN, `%02x` of 255, `%.16g`\
 and `%.17g` and `%g` of 1/3, `%c`, `%u` of UINT_MAX, `%p`, `%s`, and a two-conversion format\
 mixing the integer and float arms. Measured against the pre-1608 util.c with this same\
 driver: identical" \
  [expr {[g_out I1] eq {x=-2147483648} && [g_out I2] eq {x=ff} \
         && [g_out I3] eq {x=0.3333333333333333} && [g_out I4] eq {x=0.333333} \
         && [g_out I5] eq {x=A} && [g_out I6] eq {x=4294967295} \
         && [g_out I7] eq {x=0x58} && [g_out I8] eq {x=xy} \
         && [g_out I9] eq {x=0.33333333333333331} && [g_out IA] eq {a5b2.5c}}] \
  "(d={[g_out I1]} x={[g_out I2]} g16={[g_out I3]} g={[g_out I4]} c={[g_out I5]}\
 u={[g_out I6]} p={[g_out I7]} s={[g_out I8]} g17={[g_out I9]} mixed={[g_out IA]})"

## ⚠ G12 EXISTS BECAUSE THE `p` ARM'S GATE HAD NO ROW, AND THAT IS THE MOST SERIOUS GAP AN
## INDEPENDENT SABOTAGE CREW FOUND IN THIS FILE. Driven on the shipped tree with ONLY the `p`
## arm's `refuse = !my_snprintf_spec_ok(...)` replaced by `refuse = 0` and nothing else changed:
##   %np      -> DIED sig 6, "*** %n in writable segments detected ***"
##   %-2000p  -> DIED sig 6, "*** buffer overflow detected ***"
##   %<48 dashes>p (a 50-character spec) -> ret 4, formatted "0x58", i.e. GUARD 1 bypassed and
##                nfmt[50] written ONE BYTE PAST the array, silently
##   %.191Lp and %*p -> NOT a death: ret 0, len 0. Recorded because the sabotage receipt that
##                found this gap reports both as sig 6, and driven here through this arm with a
##                pushed `void *` they simply format nothing. So the row asserts the REFUSAL and
##                never the abort, and the discriminators are the two deaths plus that ret 4.
## and EVERY OTHER ROW IN THIS FILE STAYED GREEN -- re-driven after this row was added, the same
## removal gives `RESULT: 1 FAILED (32 passed)` with G12 the only red, so the 28 rows that
## existed before it are all in that 32. The %n case is the same attempted-arbitrary-write shape
## the whole issue is about.
## ⚠ NO PRODUCT DOOR REACHES THIS ARM ANY MORE, AND THAT IS WHY THIS IS A DIRECT-CALL ROW. P1
## asserts that ZERO my_snprintf calls in the compiled tree pass a non-literal format, so after
## the section F fix there is no input a test can write that makes a shipped caller hand the
## `p` arm a hostile spec -- the tree's only live `%p` is util.c's own pointer trace behind
## `debug_var > 2`, and its format is the literal "%p". So the instrument is section G's: the
## tree's own src/util.c, compiled with the build's own CFLAGS and called directly, one fork
## per case. That is not a planted caller in the product; nothing was added to src/ for it.
check "G12 (1608 GUARD 2 and GUARD 1 IN THE `p` ARM) `%np`, `%-2000p`, `%.191Lp`, `%*p` and a\
 50-character `%<48 dashes>p` are ALL refused by the `p` arm, WITH NO SIGNAL: rc 0, sig 0,\
 ret 0, len 0. ⚠ THE CANARY IS REPORTED IN THE DETAIL AND NOT ASSERTED HERE -- an earlier\
 version of this name claimed `an intact canary`, which `g_refused` does not read; the canary\
 at index `size` is G8's, and asserting it in this row would add a condition no sabotage can\
 reach, because every case here refuses with an EMPTY prefix and nothing on that path writes\
 near index 80. The other G rows drive the d/x/c/u and g/e/f arms; before this row the `p` arm's\
 gate call could be deleted on its own and every row here stayed green while `%np` died\
 `*** %n in writable segments detected ***`. Its companion is G10's `x=%p`, which says the arm\
 still formats an ordinary pointer, and G15's, which drives the same arm one character further" \
  [expr {[g_refused PN] && [g_refused PW] && [g_refused PL] && [g_refused PS] \
         && [g_refused PO]}] \
  "(pct_n={[g PN]} w2000={[g PW]} L={[g PL]} star={[g PS]} len50={[g PO]})"

## ⚠ G13 FENCES THE ACCUMULATOR CAP, WHICH ALSO HAD NO ROW. `if(run < 1000000)` inside
## my_snprintf_spec_ok()'s digit scan stops a long digit string wrapping a size_t. Removed, and
## nothing else changed, the wrapped run passes GUARD 3 and the spec is EXECUTED: glibc rejects
## the impossible width, sprintf returns -1, `n += nlen` makes n (size_t)-1 and my_snprintf
## RETURNS 18446744073709551615 with an empty buffer. That return is consumed as a LENGTH by
## five live sites -- my_itoa(), dtoa(), dtoa_prec() (all three into xctx->tok_size) and the two
## accumulators in hilight.c and token.c -- so the safe direction is to refuse, which a capped
## run does: the cap freezes `run` at or above 1000000, and 1000000 + 320 is not < 512.
check "G13 (1608 GUARD 3's digit-run overflow cap) a 20-digit field width whose value wraps\
 size_t is REFUSED and returns 0, not a wrapped length. `%18446744073709551616d` is 2^64 (the\
 accumulator would wrap to 0) and `%18446744073709551716d` is 2^64 + 100 (it would wrap to\
 100); both specs are 22 characters, so GUARD 1 does not reach them and the cap is the only\
 thing refusing. With the cap removed both return (size_t)-1 -- 18446744073709551615 -- which\
 five live sites consume as a length" \
  [expr {[g_refused R1] && [g_refused R2] && [g_ret R1] == 0 && [g_ret R2] == 0}] \
  "(w2_64={[g R1]} w2_64p100={[g R2]})"

## ⚠ G14 FENCES THE ONE LINE THAT SEPARATES A (D) REFUSAL FROM THE (E) DEFECT. When the prefix
## does not fit, all four arms do `overflow = 1; if(n < size) string[n] = '\0'; break;`. Remove
## those four NUL writes and `my_snprintf(u, 2, "abcd%d", 7)` returns 0 having written NOTHING
## -- the caller then reads an uninitialised buffer, which is exactly the (E) class (D)'s fix
## exists to avoid. Driven with all four removed: every case below reports len 4095 and 40
## canary bytes instead of len 0 and an empty string, on the shipped tree, with all other rows
## green. Both sizes are driven: size 2 (the destination is shorter than the literal run by more
## than one) and size 4 (n+l == size exactly, which is the off-by-one (D) itself was).
check "G14 (1608 the (D) refusal WRITES the terminator) when the literal run before a\
 conversion does not fit, all four arms leave the caller a NUL-terminated empty string and\
 return 0 -- never an untouched buffer. Driven on the d, s, g and p arms at size 2, and on the\
 same four at size 4 where n+l == size exactly. The observable is len 0 AND an empty reported\
 string; with the four `if(n < size) string\[n\] = '\\0'` writes removed the same cases report\
 the untouched canary instead. size 0 is excluded deliberately: there is no byte to write, and\
 D6 already asserts nothing is written there" \
  [expr {[g_refused N1] && [g_out N1] eq {} && [g_refused N2] && [g_out N2] eq {} \
         && [g_refused N3] && [g_out N3] eq {} && [g_refused N4] && [g_out N4] eq {} \
         && [g_refused D1] && [g_out D1] eq {} && [g_refused D3] && [g_out D3] eq {} \
         && [g_refused D4] && [g_out D4] eq {} && [g_refused D5] && [g_out D5] eq {}}] \
  "(sz2_d={[g N1]} sz2_s={[g N2]} sz2_g={[g N3]} sz2_p={[g N4]} sz4_d={[g D1]}\
 sz4_s={[g D3]} sz4_g={[g D4]} sz4_p={[g D5]})"

## ⚠ G15 FENCES THE HALF OF THE FIX THAT STOPS THE WRITE, IN THE TWO ARMS WHERE NOTHING DID.
## `refuse` does TWO things at each of the four gated arms: it skips
## `strncpy(nfmt, fmt, l); nfmt[l] = '\0';`, and it breaks after the prefix write. Only the
## BREAK was observable to the rows above, because `g_refused` is rc 0 && sig 0 && ret 0 &&
## len 0 -- and no case drove a spec of 51 characters or more through the `p` or the g/e/f arm.
## G1's 49/51/202-character dash runs all go through the d/x/c/u arm, and G12's longest `p` spec
## is exactly 50, which is the SILENT (B) store. So a second independent sabotage crew removed
## the `if(!refuse)` wrapper in ONE ARM AT A TIME and measured, on the shipped tree:
##   d arm     -> `RESULT: 1 FAILED (32 passed)`, FAIL: G1     (fenced)
##   `p` arm   -> `RESULT: ALL PASS (33 checks)` while a 51- and a 60-character `%<dashes>p`
##                both DIED sig 6 `*** buffer overflow detected ***`      (UNFENCED)
##   g/e/f arm -> `RESULT: ALL PASS (33 checks)` while 51- and 60-character `g`/`f`/`e` dash
##                runs all DIED sig 6 the same way                        (UNFENCED)
## That is mechanism (A) -- `__strncpy_chk` on `char nfmt[50]` -- back in the tree from a
## single-conditional edit that restores exactly the pre-1608 shape (the strncpy was
## unconditional at 91bb1bd7), with the suite green. It is also the most plausible refactor
## there is: "we break right after, so the copy is harmless."
## THE DISCRIMINATOR IS THE DEATH, not the return value: `g_refused` includes `g_ok`, which is
## rc 0 && sig 0, so a case that aborts fails this row. 51 is the threshold that aborts; at 50
## the store is one byte past and unfortified, i.e. silent, which is why this row does not use
## it. Each of g, e and f is driven separately because one arm handles all three letters and a
## row naming the arm should drive the arm, not one spelling of it.
check "G15 (1608 the `if(!refuse)` WRAPPER ROUND THE strncpy, in the `p` and g/e/f arms) a\
 51-character spec -- `%` + 49 dashes + the conversion letter, ONE PAST nfmt\[50\] -- is REFUSED\
 and the process SURVIVES, driven through the `p` arm and through each of `g`, `e` and `f`.\
 Removing `if(!refuse)` in either of those two arms alone left every other row in this file\
 green while these four specs died `*** buffer overflow detected ***` (sig 6), because the only\
 half of `refuse` the other rows can see is the break AFTER the prefix write, never the skipped\
 strncpy. G1 covers the same wrapper in the d/x/c/u arm. The canary and the returned length are\
 in the detail; what this row asserts is rc 0, no signal, ret 0 and an empty result" \
  [expr {[g_refused PY] && [g_refused FG] && [g_refused FF] && [g_refused FE] \
         && [g_out PY] eq {} && [g_out FG] eq {} && [g_out FF] eq {} && [g_out FE] eq {}}] \
  "(p51={[g PY]} g51={[g FG]} f51={[g FF]} e51={[g FE]})"

# ----------------------------------------------------------------------------
# SECTION M — ISSUE 1609: THE ARGUMENT FETCH, NOT THE FORMAT STRING
# ----------------------------------------------------------------------------
## ⚠ EVERY VALUE IN SECTION M IS PLANTED, AND IT HAS TO BE. NO LIVE CALLER CAN EVER REDDEN ONE
## OF THESE ROWS -- not "does not today", but CANNOT, by construction. The pre-1609 arm fetched
## `va_arg(args, int)` for every spec and then handed that `int` to a `sprintf` reading eight
## bytes for `%ld`; gcc materialises the argument with a 32-bit register write, which on x86-64
## zeroes the upper half, so the truncated value round-trips AS AN UNSIGNED 32-BIT QUANTITY and
## the two halves of the defect agree on exactly [0, 2^32). Every value the tree's own `l`
## callers can produce lies inside that band: `Display.max_request_size` is an `unsigned` in
## Xlib.h, and an XID is a CARD32. So a row driving `xschem globals` or the window-id getter
## would fence NOTHING, forever, however many values it tried. The discriminator has to be a
## `long` above 2^32 or below 0, and only a planted caller can push one. Measured, with a plain
## `sprintf` control for each value, in doc/claude/issue_1609_batch/receipts/.
##
## ⚠ AND THE FETCH'S CORRECTNESS IS NOT OBSERVABLE FROM THE ARGUMENT LIST EITHER. On x86-64
## `va_arg(args, int)` and `va_arg(args, long)` advance the SAME one eight-byte slot, so a
## format with a second conversion after the `%ld` consumes its argument identically under both
## spellings. That is why these rows read the FORMATTED TEXT and not the subsequent arguments.
check "M1 (1609 the `long` fetch for `%ld`) a PLANTED `long` outside \[0, 2^32) formats as\
 itself, byte for byte with a plain-sprintf control: 2^32+42 prints `4294967338`, -1 prints\
 `-1`, LONG_MAX prints `9223372036854775807`, and the field width and the surrounding literal\
 runs still work (`\[%12ld\]` and `a=%ld b`). Before the fix these printed `42`, `4294967295`\
 and `4294967295` -- the low 32 bits, zero-extended. The value is PLANTED and MUST BE: see the\
 comment above this row for why no live caller can ever produce one. This row reddens when\
 EITHER half of the `d` branch goes -- the `va_arg(args, long)` or the\
 `sprintf(nstr, nfmt, lv)` -- each driven separately by removal" \
  [expr {[g_ok L1] && [g_out L1] eq {4294967338} \
         && [g_ok L2] && [g_out L2] eq {-1} \
         && [g_ok L3] && [g_out L3] eq {9223372036854775807} \
         && [g_ok L4] && [g_out L4] eq {[  4294967338]} \
         && [g_ok L5] && [g_out L5] eq {a=4294967338 b}}] \
  "(p32={[g L1]} neg={[g L2]} lmax={[g L3]} w12={[g L4]} run={[g L5]})"

check "M2 (1609 the `unsigned long` fetch for `%lu` and `%lx`) a PLANTED `unsigned long`\
 outside \[0, 2^32) formats as itself: 2^32+42 prints `4294967338`, 0x1234567890AB prints\
 `1234567890ab`, ULONG_MAX prints `18446744073709551615` and `ffffffffffffffff`. Before the fix\
 they printed `42`, `567890ab`, `4294967295` and `ffffffff`. It is a SEPARATE branch from M1's\
 and it is fenced separately: `d` wants a `long` and `u`/`x` want an `unsigned long`, because\
 fetching one as the other is only defined while the value is representable in both types. This\
 row reddens when either half of the `u`/`x` branch goes. ⚠ THE SPLIT IS A TYPE-COMPATIBILITY\
 REQUIREMENT AND NOT AN OUTPUT ONE, MEASURED: on this ABI a signed and an unsigned fetch of the\
 same pushed argument produce IDENTICAL text for `%lu` and `%lx`, because both read the same\
 eight bytes and both conversions reinterpret them. So this row and M1 would both stay green\
 under a single signed fetch -- which is why the `unsigned long` spelling is asserted by row M8\
 over the source text as well" \
  [expr {[g_ok L6] && [g_out L6] eq {4294967338} \
         && [g_ok L7] && [g_out L7] eq {1234567890ab} \
         && [g_ok L8] && [g_out L8] eq {18446744073709551615} \
         && [g_ok L9] && [g_out L9] eq {ffffffffffffffff}}] \
  "(u32={[g L6]} x48={[g L7]} umax={[g L8]} xmax={[g L9]})"

check "M3 (1609 NEUTRALITY inside the agreeing band -- the property that keeps this fix out of\
 the user's way) for every value in \[0, 2^32), which is exactly the set the tree's own `l`\
 callers can produce, the output is UNCHANGED: `%ld` of 2^32-1 is `4294967295`, `%lu` of\
 2^31+1 is `2147483649`, `%lx` of 2^32-1 is `ffffffff`, `\[%12ld\]` of 2^32-1 is\
 `\[  4294967295\]`. Driven before and after against the same driver and the same util.o build\
 recipe: the whole band table plus every plain `%d`/`%u`/`%x`/`%c` and the live `%hu` came back\
 BYTE-IDENTICAL, and only the out-of-band lines moved. G5 and G10 hold the `%ld` 65535, `%hu`\
 513 and plain-spec halves of the same claim" \
  [expr {[g_ok LA] && [g_out LA] eq {4294967295} \
         && [g_ok LB] && [g_out LB] eq {2147483649} \
         && [g_ok LC] && [g_out LC] eq {ffffffff} \
         && [g_ok LD] && [g_out LD] eq {[  4294967295]} \
         && [g_out B9] eq {65535} && [g_out BA] eq {513}}] \
  "(ld={[g LA]} lu={[g LB]} lx={[g LC]} w12={[g LD]} ld65535={[g_out B9]} hu={[g_out BA]})"

check "M4 (1609 GUARD 2b -- AT MOST ONE length modifier, which is ONE guard and not two) every\
 REPEATED or MIXED modifier is refused: `%lld`, `%llu`, `%llx`, `%hhd`, `%hhu`, `%lhd`, `%hld`,\
 `%llld` and `%hhhhd`, and `X%lldY` keeps its `X` and drops the rest, which is this function's\
 own overflow shape. All nine were ACCEPTED before, because GUARD 2's whitelist was a\
 PER-CHARACTER loop (`else if(c == 'l' || c == 'h') continue;`) that could not see a\
 repetition -- so `%llld` reached glibc and came back as the literal `%ld`, with no number in\
 it at all. `ll` is REFUSED AND NOT IMPLEMENTED because this tree is C89 and C89 has no `long\
 long`; row M7 is the row that keeps it that way. It is deliberately ONE guard\
 (`if(nmod) return 0;`) covering both the repeated and the mixed case, because two guards on\
 one path would mean neither had a row that reddens on its own removal. ⚠ IT IS IN THE SHARED\
 GATE, SO IT REACHES THE OTHER TWO ARMS TOO, and that closed two things nobody had named:\
 `X%llfY` returned 6 and printed `X-nanY` from a correctly-pushed 1.5 -- `ll` on a floating\
 conversion is undefined and glibc reports no error for it -- and `X%llpY` was accepted with the\
 modifier silently dropped. Both now keep the `X` and drop the rest" \
  [expr {[g_refused MA] && [g_refused MB] && [g_refused MC] && [g_refused MD] \
         && [g_refused ME] && [g_refused MF] && [g_refused MG] && [g_refused MH] \
         && [g_refused MI] \
         && [g_ok MJ] && [g_out MJ] eq {X} && [g_ret MJ] == 1 \
         && [g_ok MO] && [g_out MO] eq {X} && [g_ret MO] == 1 \
         && [g_ok MP] && [g_out MP] eq {X} && [g_ret MP] == 1}] \
  "(lld={[g MA]} llu={[g MB]} llx={[g MC]} hhd={[g MD]} hhu={[g ME]} lhd={[g MF]}\
 hld={[g MG]} llld={[g MH]} hhhhd={[g MI]} prefixed={[g MJ]} llf={[g MO]} llp={[g MP]})"

check "M5 (1609 anti-vacuity for M4, and without it M4 passes on a gate that refuses every\
 modifier) a SINGLE length modifier still formats: `%hd` of -1 is `-1`, `%lc` of 65 is `A` and\
 `\[%lc\]` is `\[A\]`. G5 carries the two LIVE spellings, `%ld` and `%hu`. Tightening GUARD 2\
 into a modifier whitelist had to refuse `ll` and `hh` without touching `l` or `h`, and M4\
 alone cannot tell those two outcomes apart" \
  [expr {[g_ok MK] && [g_out MK] eq {-1} \
         && [g_ok ML] && [g_out ML] eq {A} \
         && [g_ok MM] && [g_out MM] eq {[A]} \
         && [g_ok B9] && [g_ok BA]}] \
  "(hd={[g MK]} lc={[g ML]} lcbr={[g MM]} ld={[g B9]} hu={[g BA]})"

## ⚠ M6 IS A FENCE AGAINST A SHORTCUT NOBODY HAS TAKEN, AND THAT IS WHY IT EXISTS. The tempting
## one-line shape for 1609 is to normalise every integer spec to carry `l` so that one
## `va_arg`/`sprintf` pair serves the whole arm. That would turn every live `%c` in the tree
## into `%lc`, and `%lc` of a byte with no multibyte representation makes glibc's sprintf return
## -1 -- which this function never checks, driving its `size_t` length to SIZE_MAX (issue 1612).
## One of the tree's `%c` sites is fed a graph rectangle's `unitx=` attribute out of a .sch FILE,
## so the shortcut would convert an unreachable defect into a file-borne one. This row drives
## the byte value that triggers it. ⚠ The output bytes are NOT asserted, deliberately: the
## formatted byte is >= 128 and would be an encoding question rather than a measurement. The
## return and the length are the discriminators, and under the shortcut they are 1 and 1.
check "M6 (1609/1612 `%c` is NOT normalised to `%lc`) `\[%c\]` of 233 returns 3 and leaves a\
 three-byte result -- one literal `\[`, one formatted byte, one literal `\]`. Under the\
 normalise-to-`l` shortcut this returns 1 with the result `\]`, because glibc's `%lc` of that\
 value returns -1 and the unchecked negative wraps the accumulated length to SIZE_MAX before\
 the prefix is overwritten. `%lc` itself stays ACCEPTED and stays on the `int` fetch (M5 drives\
 it): `wint_t` is four bytes on glibc and promotes to `int` on Windows, so the pre-existing\
 fetch was already the right width for it. Whether `%lc` should be refused outright is issue\
 1612's question, not this one's" \
  [expr {[g_ok MN] && [g_ret MN] == 3 && [g_len MN] == 3}] \
  "(cbyte={[lrange [g MN] 0 4]})"
}

# ============================================================================
# SECTION S — WHERE NOTHING ELSE REACHES
# ============================================================================
## ⚠ THESE THREE ROWS EXIST BECAUSE THE PROPERTY IS INVISIBLE TO EVERY OTHER INSTRUMENT.
## The deleted `#ifdef HAS_SNPRINTF` arm was NEVER COMPILED, so `gcc -E` output, the linked
## binary and `xschem globals` are all byte-identical with it present or absent -- there is
## nothing behavioural to measure and the compiler has no opinion. Source text is the only
## instrument, and it is the weak one, which is why each row's NAME says exactly what text it
## greps and none of them claims a count -- neither of what could escape (L1) nor of what the
## grep finds (L9). An earlier version of the paragraph below claimed a figure for how many
## times util.c's own comment spells `HAS_SNPRINTF`, and it was wrong: a count of the tree's
## text, written into the tree's text, in a file whose own named limits forbid exactly that.
## And the text MUST be comment-stripped: src/util.c's replacement comment spells both
## `#ifdef HAS_SNPRINTF` and the bare `HAS_SNPRINTF` repeatedly and on purpose, so a raw grep
## would be RED on the correct tree -- and a raw grep for the old arm would be GREEN on a tree that
## restored it inside a `#if 0`. This tree has defeated a whole-file regexp twice: a `#if 0`
## region holding a byte-for-byte clone of live code (1607 row V27) and a comment quoting the
## very guard the row grepped for (1603 rows S1-S4).
proc live_code {src} {
  regsub -all {(?s)/\*.*?\*/} $src { } src
  regsub -all {(?n)//[^\n]*$} $src { } src
  set out {} ; set dead 0 ; set depth 0
  foreach ln [split $src \n] {
    set t [string trim $ln]
    if {!$dead && [regexp {^#[ \t]*if[ \t]+0\M} $t]} { set dead 1 ; set depth 1 ; continue }
    if {$dead} {
      if {[regexp {^#[ \t]*(if|ifdef|ifndef)\M} $t]} { incr depth }
      if {[regexp {^#[ \t]*endif\M} $t]} { incr depth -1 ; if {$depth <= 0} { set dead 0 } }
      continue
    }
    lappend out $ln
  }
  regsub -all {\s+} [join $out \n] { } src
  return $src
}
set s1src [slurp [file join $repo src util.c]]
set s1live [live_code $s1src]
check "S1 (1608) after comments, `//` lines and depth-counted `#if 0` regions are removed,\
 src/util.c contains the text `HAS_SNPRINTF` ZERO times and `vsnprintf` zero times, while the\
 ORIGINAL text still contains `HAS_SNPRINTF` (the replacement comment that records what was\
 deleted and why enabling it was never safe). Both halves are asserted: the first says the\
 dead arm is gone, the second says this row is reading a stripped copy and not an empty\
 string. There is nothing behavioural to measure -- the arm never compiled, so the binary and\
 `gcc -E` are identical either way" \
  [expr {[string length $s1src] > 1000 \
         && [regexp -all {HAS_SNPRINTF} $s1live] == 0 \
         && [regexp -all {vsnprintf} $s1live] == 0 \
         && [regexp -all {HAS_SNPRINTF} $s1src] > 0}] \
  "(live_hits=[regexp -all {HAS_SNPRINTF} $s1live]\
 live_vsnprintf=[regexp -all {vsnprintf} $s1live]\
 raw_hits=[regexp -all {HAS_SNPRINTF} $s1src] src=[string length $s1src]B\
 live=[string length $s1live]B)"

set s2src [slurp [file join $repo src scheduler.c]]
set s2live [live_code $s2src]
check "S2 (1608) the same stripped read of src/scheduler.c contains `HAS_SNPRINTF` ZERO\
 times, so the `xschem globals` line that advertised the dead arm -- and handed `%s` whatever\
 integer the macro would have been -- is gone, while the raw text still carries the comment\
 that records it. `xschem globals` output is unchanged, because that line never printed: the\
 macro is defined nowhere in this tree" \
  [expr {[string length $s2src] > 1000 \
         && [regexp -all {HAS_SNPRINTF} $s2live] == 0 \
         && [regexp -all {HAS_SNPRINTF} $s2src] > 0}] \
  "(live_hits=[regexp -all {HAS_SNPRINTF} $s2live]\
 raw_hits=[regexp -all {HAS_SNPRINTF} $s2src] src=[string length $s2src]B)"

## M7 and M8 — ISSUE 1609's TWO SOURCE-TEXT ROWS, AND WHY THEY ARE SOURCE-TEXT ROWS.
## Both assert something the driven rows CANNOT see, which is the only reason to reach for the
## weak instrument at all:
##   M7 asserts an ABSENCE that has no behaviour: a tree that implemented `ll` instead of
##     refusing it would pass M4 (which only demands a refusal) on a compiler that HAS
##     `long long`, and then fail to compile under `./configure --debug`'s -std=c89 -pedantic.
##     The C89 constraint is a property of the text, so the row is over the text.
##   M8 asserts that `c` is absent from the wide branches. That routing is NOT behaviourally
##     observable on this ABI -- driven, with the exclusion deliberately sabotaged: `va_arg`
##     advances the same eight-byte slot for `int` and for `long`, and glibc reads four bytes
##     for `%lc` whatever type the argument had, so `%lc` printed the same character either
##     way and every row in this file stayed green. It also asserts the `unsigned long`
##     SPELLING, which M2 cannot: a signed fetch produces identical text for `%lu` and `%lx`.
## ⚠ BOTH READ live_code()'s OUTPUT, so a comment quoting the guard, a `//` line and a
## depth-counted `#if 0` clone are all stripped first -- this tree has defeated a whole-file
## regexp with each of those. M8 additionally removes ALL whitespace before matching, because a
## reformatting of `mod == 'l'` to `mod=='l'` is not a regression and must not redden it.
check "M7 (1609 `ll` is REFUSED, NEVER IMPLEMENTED -- C89 has no `long long`) the\
 comment-stripped, `//`-stripped, depth-counted-`#if 0`-stripped text of src/util.c contains\
 the two-word token `long long` ZERO times, while that same stripped text DOES contain\
 `va_arg(args, long)` -- the second half is the anti-vacuity, so an empty or unstripped read\
 cannot pass this row. This tree is C89 (`./configure --debug` asks gcc for `-std=c89\
 -pedantic`, under which `long long` is a diagnostic), so implementing `%lld` was never\
 available and GUARD 2b refuses it instead; M4 is the row that drives the refusal. A row\
 asserting only the refusal would stay green on a tree that implemented `ll` under a compiler\
 that has it" \
  [expr {[regexp -all {long long} $s1live] == 0 \
         && [string first {va_arg(args, long)} $s1live] >= 0}] \
  "(long_long_hits=[regexp -all {long long} $s1live]\
 wide_fetch_seen=[expr {[string first {va_arg(args, long)} $s1live] >= 0}]\
 live=[string length $s1live]B)"

## the `;`-delimited statements of the stripped text whose whitespace-free form mentions the
## modifier test -- i.e. exactly the statements that dispatch on `mod == 'l'`
set m8stmts {} ; set m8bad {} ; set m8lfetch 0 ; set m8ufetch 0
foreach frag [split $s1live {;}] {
  set t $frag
  regsub -all {\s+} $t {} t
  if {[string first {mod=='l'} $t] < 0} continue
  lappend m8stmts $t
  if {[string first {'c'} $t] >= 0} { lappend m8bad $t }
  if {[string first {va_arg(args,long)} $t] >= 0} { incr m8lfetch }
  if {[string first {va_arg(args,unsignedlong)} $t] >= 0} { incr m8ufetch }
}
check "M8 (1609 the wide branches never name `c`, and the `u`/`x` one fetches UNSIGNED) taking\
 every `;`-delimited statement of that same stripped src/util.c text, whitespace removed, whose\
 text mentions `mod=='l'`: there are at least four of them (two `va_arg` fetches and two\
 `sprintf` calls), NONE contains the character constant `'c'`, exactly one fetches\
 `va_arg(args, long)` and exactly one fetches `va_arg(args, unsigned long)`. `%lc` must stay on\
 the `int` fetch: `wint_t` is four bytes on glibc and promotes to `int` on Windows, and\
 normalising `%c` to `%lc` is what would make issue 1612 reachable from a .sch file (row M6\
 drives that boundary). ⚠ THIS IS A SOURCE-TEXT ROW BECAUSE THERE IS NOTHING TO DRIVE:\
 sabotaged by adding `c` to the `d` branch, `%lc` printed the identical character and every row\
 in this file stayed green, because `va_arg` advances one eight-byte slot for `int` and for\
 `long` alike and glibc reads four bytes for `%lc` regardless. The `unsigned long` half is here\
 for the same reason -- a signed fetch produces byte-identical text for `%lu` and `%lx` on this\
 ABI, so no driven row can tell them apart" \
  [expr {[llength $m8stmts] >= 4 && [llength $m8bad] == 0 \
         && $m8lfetch == 1 && $m8ufetch == 1}] \
  "(stmts=[llength $m8stmts] naming_c={$m8bad} long_fetches=$m8lfetch\
 ulong_fetches=$m8ufetch)"

## S3 — PREPROCESSED, not grepped, because the thing it is about was twice mis-reported by
## grepping. Two crews on this batch filed src/parselabel.l's
## `extern int my_snprintf(char *str, int size, ...)` as a live conflicting prototype. It is
## inside a `/* ... */` block, so it never compiled and there was never a conflict.
##
## ⚠ THIS ROW WAS RE-POINTED, BECAUSE ITS FIRST VERSION COULD NOT REDDEN ON ANYTHING SAFE. It
## asserted only "zero declarations taking an `int size`", which is a property of ONE SPELLING:
##   * un-commenting parselabel.l's dead declaration AS IT NOW STANDS (`size_t`/`size_t`) left
##     this row green, because there is no `int size` in it;
##   * the only edit that DID redden it -- restoring the old `int`/`int` spelling -- is a hard
##     compile error (`conflicting types for 'my_snprintf'`, make rc 2), so `make` never
##     completes and every behavioural row would be scoring a stale binary. A row whose only
##     sabotage is one that cannot build is not a fence.
## It now asserts the property its name always claimed: that the preprocessed translation unit
## contains EXACTLY ONE declaration of my_snprintf and that the one it has carries the format
## attribute. Un-commenting the dead declaration -- the act the comment in parselabel.l
## forbids -- makes it two, builds clean, and reddens this row. Removing the attribute from
## util.h reddens it too, by a different instrument from W2's.
## ⚠ And for the record, measured: un-commenting the WHOLE dead block does not build either --
## `extern int xctx;` conflicts with xschem.h's `Xschem_ctx *xctx` and `my_free`'s signature
## disagrees as well. Only the my_snprintf line on its own compiles, which is exactly the
## plausible edit and the one this row now catches.
if {$CC ne {} && $CFLAGS ne {ZZNONE}} {
  set s3i [file join $dir parselabel.i]
  catch {exec sh -c "$CC -E $CFLAGS [file join $SRC parselabel.c] > $s3i 2>/dev/null"}
  set s3txt [slurp $s3i]
  set s3decl [regexp -all {my_snprintf[ \t]*\([^)]*int[ \t]+size} $s3txt]
  ## a DECLARATION is `my_snprintf` with a return type immediately before it; the call site in
  ## expandlabel()'s error path has none, so this counts declarations and not uses
  set s3ndecl [regexp -all {(size_t|int|unsigned[ \t]+long)[ \t\n]+my_snprintf[ \t\n]*\(} $s3txt]
  set s3attr 0
  if {[regexp -indices {(size_t|int|unsigned[ \t]+long)[ \t\n]+my_snprintf[ \t\n]*\(} $s3txt mi]} {
    ## 300 characters after the declaration's start: enough for the parameter list, any cpp
    ## line marker and the attribute, and keyed on the TEXT near the declaration rather than on
    ## one exact formatting of it
    set s3win [string range $s3txt [lindex $mi 0] [expr {[lindex $mi 0] + 300}]]
    set s3attr [regexp {format[ \t\n]*\([ \t\n]*printf[ \t\n]*,[ \t\n]*3[ \t\n]*,[ \t\n]*4} $s3win]
  }
  set s3any  [regexp -all {my_snprintf} $s3txt]
  check "S3 (1608) `gcc -E` of src/parselabel.c -- the flex-generated file, which is what the\
 compiler actually sees -- contains EXACTLY ONE declaration of my_snprintf (matched as a return\
 type immediately followed by the name and an open paren), that declaration carries\
 `format(printf, 3, 4)`, and ZERO declarations take an `int size`. So the program has one live\
 declaration and the format attribute on it cannot be fought by a second, disagreeing one.\
 Preprocessed and not grepped on purpose: the dead copy in parselabel.l sits inside a block\
 comment and was filed twice in this batch as a live conflict by crews grepping the text. ⚠ The\
 one-declaration half is the half that reddens: un-commenting that dead copy builds CLEAN and\
 makes it two" \
    [expr {$s3any > 0 && $s3decl == 0 && $s3ndecl == 1 && $s3attr}] \
    "(decls=$s3ndecl want=1 attr_on_it=$s3attr int_size_decls=$s3decl\
 any_my_snprintf=$s3any preprocessed=[string length $s3txt]B)"
} else {
  row_skip {S3} "no gcc or no CFLAGS line, so parselabel.c could not be preprocessed; S1 and S2\
 still read the source text"
}

# ============================================================================
# SECTION X — EVERY ROW CITATION IN src/, CHECKED AGAINST THE ROWS THAT EXIST
# ============================================================================
## ⚠ WHY THIS IS A ROW AND NOT FIVE HAND EDITS. The first version of this file was cited by
## five comments in src/, and FIVE OF THE FIVE named a row that does not exist:
##   src/util.c   `row F13`     -- the row is W1
##   src/util.h   `row F13`     -- the row is W1
##   src/util.c   `rows F7-F12` -- F10, F11, F12 do not exist; (D) and the ordering are G8/G9
##   src/svgdraw.c `rows F1-F6` -- F6 is the --rcfile row in xinit.c; svgdraw's are F1, F2, F3,
##                                 F4, F4b and F5, which `F1-F5` as a range does not spell either
##   src/xinit.c  `rows F3/F4/F6` -- the --rcfile rows are F6/F7/F8
## Counting this batch, the repo has shipped a wrong row name or citation in SIX consecutive
## hardening rounds. So the five were fixed and this row was added, because the next
## hand-written citation would have been wrong too.
##
## THE ID SET IS DERIVED, NEVER HAND-LISTED: `check` records the first token of every row name
## and `row_skip` records the ids of rows that did not run (see the top of this file). A
## hand-maintained list of "the rows that exist" would be the same defect one level up.
##
## ⚠ ATTRIBUTION IS THE WHOLE DIFFICULTY, AND A NAIVE SCAN GETS IT WRONG BOTH WAYS. Measured on
## the six files that mention this suite: src/svgdraw.c also carries `Row V27 of
## tests/headless/test_ps_valid_1350.tcl` and `Rows A36..A39 of test_annot_declutter_1244.tcl`,
## and src/xinit.c carries `test_startup_guard_0663.tcl (rows SG0-SG21)` -- so checking every
## `row X` in a file that mentions this suite would redden on three correct citations of OTHER
## suites. Meanwhile src/util.c and src/util.h refer to `Row G6`, `row G7`, `row G13`, `Row G14`
## and `Row W2` with no suite name at all, because the enclosing comment named the suite once
## already -- so requiring the name next to every row list silently skips five real citations of
## OURS. An earlier draft of this row did exactly that and missed svgdraw.c's list entirely.
## So each `row(s) <ids>` mention is ATTRIBUTED to a suite, by three rules in order:
##   1. `rows X of <path>.tcl`               -> that path
##   2. `<path>.tcl [`] [(] rows X`          -> that path
##   3. a BARE mention                       -> the nearest PRECEDING `*.tcl` name in the file,
##      which is how these comments are written: name the suite once, then cite rows by id
## and only the mentions attributed to THIS file are checked. The counts for the other two
## outcomes are reported in the detail, so an attribution going wrong is visible rather than
## silent.
##
## SCOPE, stated rather than implied (named limit L7): only files under src/ with a source-text
## extension. A row id is matched only in the shape `[A-Z][A-Za-z]{0,2}[0-9]+[A-Za-z]?` after a
## `row`/`rows` keyword, so "row 5" and "Row One" are not row ids and are not checked.
## The GENERATED src/parselabel.c is read when it exists and carries parselabel.l's comment
## verbatim, so the citation count is ONE HIGHER AFTER A BUILD THAN BEFORE ONE. That -- and named
## limit L9 -- is why the assertion is a FLOOR of 3 and why no number is written down here: the
## count is a count of src/'s own text, it moves with every comment anyone adds, and the row
## reports it in the detail where it is re-measured on every run.
##
## Comment continuation (`\n * `) is folded away first: a citation routinely straddles it, and
## src/xinit.c's really does.
proc xflat {txt} {
  regsub -all "\n\[ \t\]*\\*?\[ \t\]*" $txt { } txt
  regsub -all {[ \t]+} $txt { } txt
  return $txt
}
## expand one citation's id list into ids: `F13`, `F7-F12`, `F3/F4/F6`, `F1, F2 and F3`
proc xids {s} {
  set out {} ; set prev {} ; set range 0
  foreach t [regexp -all -inline {[A-Z][A-Za-z0-9]*|-} $s] {
    if {$t eq {-}} { set range 1 ; continue }
    if {$range && $prev ne {} && [regexp {^([A-Z]+)([0-9]+)$} $prev . pa pn] \
        && [regexp {^([A-Z]+)([0-9]+)$} $t . ta tn] && $pa eq $ta && $tn > $pn} {
      for {set k [expr {$pn + 1}]} {$k <= $tn} {incr k} { lappend out $pa$k }
    } else {
      lappend out $t
    }
    set range 0 ; set prev $t
  }
  return [lsort -unique $out]
}
proc xwalk {dir} {
  set out {}
  foreach f [lsort [glob -nocomplain -directory $dir *]] {
    if {[file isdirectory $f]} { set out [concat $out [xwalk $f]] } \
    elseif {[regexp {\.(c|h|l|y|tcl|awk|in|sh|md|txt)$} $f] && [file isfile $f]} { lappend out $f }
  }
  return $out
}
## X1 is registered BEFORE its own expression runs, because `check` records the id only when it
## is called -- by which time the expression has already been evaluated. Without this a comment
## citing X1 would be reported as citing a row that does not exist.
row_seen X1
set xsuite  [file tail [info script]]
set xID  {[A-Z][A-Za-z]{0,2}[0-9]+[A-Za-z]?}
## ⚠ EACH ID MAY BE WRAPPED IN BACKTICKS, AND THAT IS THE ONE UNDISCLOSED MISS AN ATTACK RUN
## FOUND. This repo writes row ids in backticks constantly -- ``rows `F1`, `F2` and `F3` `` --
## so a scan that required the id to follow the keyword with nothing but a space between was the
## likeliest future miss of the lot: it would go green on a citation nobody had checked. The
## backtick is optional on each side of every id in the list, so the single, the range and the
## comma form all match with or without them; `xids` extracts `[A-Z]...` tokens and `-` and
## ignores the backticks themselves.
set xIDB "`?${xID}`?"
## ⚠ `..` IS A SEPARATOR BECAUSE THIS TREE WRITES RANGES THAT WAY AND ONE SUCH CITATION WAS
## SILENTLY UNATTRIBUTED. `Rows A36..A39 of tests/headless/test_annot_declutter_1244.tcl` appears
## in draw.c, svgdraw.c and psprint.c (the declutter guard's comment is byte-identical in all
## three back ends). With `..` missing from this alternation the id list stopped at `A36`, the
## text after the match was `..A39 of tests/...`, so RULE 1 did not fire and rule 3 attributed it
## to whichever suite was named earlier in the file. That was invisible only by luck -- the
## nearest preceding name in svgdraw.c happened to be another suite's -- and it broke the moment
## a 1608 comment was added between the two, which is how it was found. xids() then yields A36
## and A39 separately (it makes a range only out of `-`), which is the safe reading: no
## fabricated middle ids.
set xIDL "${xIDB}(?:(?:-|\\.\\.|/|, | and |, and )${xIDB})*"
set xrow "\[Rr\]ows?\[ \]+($xIDL)"
set xpath {[A-Za-z0-9_./-]+\.tcl}
set xbad {} ; set xcits 0 ; set xhitfiles {} ; set xelsewhere 0 ; set xunattr {}
foreach f [xwalk [file join $repo src]] {
  set t [slurp $f]
  if {[string first test_snprintf_fmt $t] < 0} continue
  set t [xflat $t]
  ## every *.tcl name in the file with its position, for attribution rule 3
  set xtcls {}
  foreach {ps pe} [join [regexp -all -inline -indices $xpath $t]] {
    lappend xtcls [list $ps [file tail [string range $t $ps $pe]]]
  }
  set xnames {}
  foreach p $xtcls { if {[lsearch -exact $xnames [lindex $p 1]] < 0} { lappend xnames [lindex $p 1] } }
  set xonly [expr {[llength $xnames] == 1}]
  foreach {mi gi} [regexp -all -inline -indices $xrow $t] {
    set idl [string range $t [lindex $gi 0] [lindex $gi 1]]
    set ms [lindex $mi 0] ; set me [lindex $mi 1]
    set cited {}
    ## rule 1 -- `rows X of <path>.tcl`
    if {[regexp "^\[ \]*(?:of|in|from)\[ \]+($xpath)" \
           [string range $t [expr {$me + 1}] [expr {$me + 90}]] . p]} {
      set cited [file tail $p]
    } else {
      ## rule 2 -- `<path>.tcl [`] [(] rows X`
      set head [string range $t [expr {$ms - 90 < 0 ? 0 : $ms - 90}] [expr {$ms - 1}]]
      if {[regexp "($xpath)`?\[ \]*\\(?\[ \]*\$" $head . p]} {
        set cited [file tail $p]
      } else {
        ## rule 3 -- the nearest PRECEDING *.tcl name in the file
        foreach p $xtcls { if {[lindex $p 0] < $ms} { set cited [lindex $p 1] } else break }
      }
    }
    if {$cited eq {} && $xonly} { set cited $xsuite }
    if {$cited eq {}} { lappend xunattr "[file tail $f]: \"$idl\"" ; continue }
    if {$cited ne $xsuite} { incr xelsewhere ; continue }
    incr xcits
    if {[lsearch -exact $xhitfiles [file tail $f]] < 0} { lappend xhitfiles [file tail $f] }
    foreach id [xids $idl] {
      if {[lsearch -exact $rowids $id] < 0} {
        lappend xbad "[file tail $f]: cites $id (in \"$idl\") -- no such row"
      }
    }
  }
}
## the other direction for the one list this file does keep by hand
set xgwpmissing {}
if {$CC ne {} && $CFLAGS ne {ZZNONE}} {
  foreach r $gwp_rows { if {[lsearch -exact $rowids $r] < 0} { lappend xgwpmissing $r } }
}
check "X1 (1608) every `row`/`rows` citation ATTRIBUTED TO THIS SUITE in src/ names a row that\
 EXISTS. Scanned: every file under src/ with a source-text extension that mentions this file's\
 name, C-comment continuation folded, for every `row`/`rows` followed by an id-shaped token,\
 with `X-Y` expanded as a range and `X/Y/Z`, `X, Y and Z` split. Each mention is attributed to\
 a suite -- by `of <path>.tcl` after it, by `<path>.tcl` before it, else by the nearest\
 preceding `*.tcl` name in the file -- and only this suite's are checked, so three correct\
 citations of other suites in the same two files are not false reds. The set of ids that EXIST\
 is DERIVED from the rows this run exercised plus the ids named in its own `skip:` lines, never\
 from a list in this file; it also checks that `gwp_rows`, the one list this file does keep by\
 hand, names only rows that ran. FLOORS and not counts: at least 3 citations in at least 2\
 files, so a tree with every citation deleted reddens instead of passing silently" \
  [expr {[llength $xbad] == 0 && [llength $xunattr] == 0 && $xcits >= 3 \
         && [llength $xhitfiles] >= 2 && [llength $xgwpmissing] == 0}] \
  "(unknown={$xbad} citations=$xcits files={$xhitfiles} other_suites=$xelsewhere\
 unattributed={$xunattr} rows_known=[llength $rowids] gwp_rows_missing={$xgwpmissing}\
 suite=$xsuite)"

## Both banners, for the same reason as test_ps_valid_1350.tcl: run_suites.sh scores a headless
## suite from its `^RESULT` line and T1 scores it from banner_rule.tcl's whole-line
## `OVERALL: ok`, which knows nothing about `RESULT:`. A suite registered in T1's `hcases` with
## only the first is scored `HARNESS: ... did not complete cleanly` -- a counted failure with
## every one of its own checks green.
if {$fail == 0} {
  puts "RESULT: ALL PASS ($pass checks)"
  puts "OVERALL: ok ($pass checks)"
} else {
  puts "RESULT: $fail FAILED ($pass passed)"
  puts "OVERALL: notok"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
