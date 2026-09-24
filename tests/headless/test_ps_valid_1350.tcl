# Issues 1342 / 1343 / 1350 / 1351 / 1352 — DOES THE PostScript THIS BACK END WRITES
# ACTUALLY DISTIL?  ITEM H5.
#
# --------------------------------------------------------------------------
# ⚠ THE ISSUE NUMBERS IN THIS FILE'S HIERARCHICAL-PDF COMMENTS ARE THE `op-wcard`
# BRANCH'S NUMBERING, NOT THIS TREE'S.  DO NOT FOLLOW ONE INTO doc/claude/issues/.
#
# This code was ported to `fluid-editing` on 2026-09-24 from a finished batch on the
# `op-wcard` branch. That batch's directory (doc/claude/hier_pdf_links_batch/) and its
# eighteen issue files stayed there and are NOT in this clone -- deliberately, because
# EVERY number they use, 1333 through 1360, is already taken HERE by a completely
# unrelated defect: 1333 here is an op-dump reader with no caller, 1342 a simcaps
# count, 1350 an annotation-order dump. A reader who follows one of these numbers into
# this tree's doc/claude/issues/ will find a real file about something else entirely.
# Read the real ones on the branch that has them:
#     git -C <an op-wcard clone> show op-wcard:doc/claude/issues/1334-*.md
#     git -C <an op-wcard clone> show \
#         op-wcard:doc/claude/hier_pdf_links_batch/DECISIONS.md
# Nothing has been renumbered, on purpose: the eighteen colliding files are committed
# in both trees and cited from source comments and commit messages in both. Who moves,
# if anyone, is the USER'S ruling -- carried as issue 1400 in this tree and issue 1347
# on op-wcard, both still open.
# --------------------------------------------------------------------------

#
# The point of `xschem hier_psprint` is a PDF a reviewer without xschem can read. Every
# other suite in this batch reads the .ps, deliberately (a /Link assertion made on a PDF
# fences the distiller, not xschem — CREW_BRIEF). This one is the opposite by design: it
# runs ps2pdf and reads the PDF, because the defect class here is xschem writing bytes
# that are not PostScript, and the .ps looks perfect right up to the moment gs dies on it.
#
# Measured on the UNCHANGED binary, xschem_library/examples/0_examples_top.sch:
#   PostScript      99 pages, 305 links, 7.2 MB      — CORRECT
#   after ps2pdf    10 pages,  67 links, exit 1      — 89 pages LOST
# and 11 of 325 swept sheets die the same way, sky130_tests/top among them (86 -> 39).
# `ps2pdf` exits 1, so xschem's own error path fires and the user simply never gets a PDF.
#
# FOUR defects, each fatal on its own, each `src/psprint.c` writing data into PostScript
# syntax without validating it. Every row below has been seen RED on the HEAD binary.
#
#  1342  a GARBAGE LINE WIDTH. `9.78375e+160 setlinewidth`. PostScript reals are SINGLE
#        precision, so anything past ~3.4e38 is a hard /limitcheck — measured against
#        gs 10.06, 1e38 distils and 1e39 kills the job — and a /limitcheck kills the whole
#        DOCUMENT. Root cause found and fixed at source: add_pinlayer_boxes() (save.c)
#        synthesises an LCC pin's xRect into my_realloc'd storage and set every field
#        except `bus`, which ps_filledrect() multiplies into a line width. Confirmed with
#        `valgrind --track-origins=yes`. set_lw() clamps too, because four other call
#        sites feed the same sink and because NaN/Inf print as the bare tokens `nan`/`inf`.
#        ⚠ 1342 was filed as COSMETIC ("makes a byte-for-byte comparison impossible").
#        It was not: it destroys the document from the first affected page onward.
#
#  1350  a BACKSLASH in schematic text. The escaper handled `(` and `)` and not `\`, so a
#        lone backslash emitted `(\)` — a string containing an escaped `)`, which never
#        terminates — /syntaxerror. xschem_library/devices/intuitive_interface_cheatsheet.sym
#        ships one. The small page title had NO escaping at all and takes a FILENAME.
#
#  1351  the `font=` attribute, written as a PostScript name AND as a printf format string.
#        `font="courier new"` emits `/courier new-Bold FF`: gs pushes /courier and then
#        EXECUTES `new-Bold`. /undefined. And `font=%n` SEGFAULTS the export (row V13).
#
#  1352  a `/Dest` name minted from a FILE NAME. A schematic called `my cell.sch` emits
#        `/Dest /my cell.sch`; gs reads /my and executes `cell.sch`. sanitize() does not
#        cover it — it rewrites generator names only.
#
# Run:
#   ./src/xschem --nogui --pipe -q --script tests/headless/test_ps_valid_1350.tcl

set fail 0
set pass 0
proc check {n ok d} {
  global fail pass
  if {$ok} { puts "ok:   $n $d" ; incr pass } else { puts "FAIL: $n $d" ; incr fail }
}

source [file join [file dirname [info script]] scratch.tcl]
set dir  [test_scratch psvalid]
set repo [file normalize [file join [file dirname [info script]] .. ..]]

## ⚠ THIS GUARD USED TO BE A PASS THAT HAD ASSERTED NOTHING, and it is worth spelling out
## why, because the shape is easy to write again. It printed `SKIP: no ps2pdf on this box`
## and then `RESULT: ALL PASS`, and exited 0. Every reader in this tree scored that GREEN:
##   - run_suites.sh scores a suite from its `^RESULT` line -> PASS;
##   - T1's regression_case_failed wants exit 0 and a completion banner -> PASS;
##   - T1's summarize_all collects lowercase `^skip:` lines into the verdict's `skips=`
##     count (issue 1487) and `SKIP:` is NOT that line, so the verdict said
##     `counted_failures=0 skips=0` for a case that ran ZERO of its 21 rows.
## CLAUDE.md's rule is that `counted_failures=0` is a claim about correctness and `skips=`
## is the second number that says what was measured at all. A suite that can silently
## contribute 21 imaginary checks breaks the only place the answer is.
##
## So: a lowercase `skip:` line that NAMES the rows that did not run and why, and a banner
## that states a count of zero. The reason text must not end in the words FAIL, GOLD? or
## RESULT? -- summarize_all tests those shapes FIRST and a skip matching one is scored as a
## counted failure (CLAUDE.md, rows V5a-V5f of test_regression_concurrency_1476).
##
## EVERY row of this suite needs ps2pdf: the whole point of the file is the opposite of the
## rest of the batch -- it distils the PostScript and reads the PDF back, because the defect
## class is xschem writing bytes that are not PostScript and the .ps looks perfect right up
## to the moment gs dies on it. There is no subset that can run without it, which is why the
## skip names the whole range rather than a list.
##
## `ps2pdf -h` exits non-zero even when it is installed, so the `catch` alone cannot answer
## the question; the explicit /usr/bin/ps2pdf test is the second half and both must miss.
if {[catch {exec ps2pdf -h} ] && ![file executable /usr/bin/ps2pdf]} {
  puts "skip: V1-V21 -- ps2pdf is not installed, so NONE of this suite's 21 rows ran; every\
 row distils the PostScript and reads the PDF back, and there is no .ps-only subset that\
 would fence the right artifact"
  puts "RESULT: ALL PASS (0 checks -- ps2pdf missing, see the skip: line)"
  puts "OVERALL: ok (0 checks -- ps2pdf missing)"
  flush stdout ; exit 0
}

# ------------------------------------------------------------------ helpers ---
proc slurp {f} { if {![file exists $f]} { return "" } ; set fd [open $f rb] ; set d [read $fd] ; close $fd ; return $d }

## Spawn a child xschem that loads $sch and exports to $ps. `pre` is Tcl run first.
## Spawned, not in-process: two of these rows fence a SEGFAULT, which would take this
## script's own interpreter with it.
##
## ⚠ EVERY CHILD TURNS THE NAVIGATION STRIP ON EXPLICITLY, because the SHIPPED DEFAULT IS
## `none` (the user's 2026-09-24 ruling -- see the note beside `set_ne ps_hier_nav none` in
## src/xschem.tcl). When this suite was written the default was `both` and row V16 counted
## the strip's annotations without ever asking for them; flipping the default turned V16 red
## for a reason that had nothing to do with distillation. A row that relies on a default is a
## row that makes the default impossible to change.
##
## `both` and not `none` is deliberate: the strip puts a second kind of /Subtype /Link, its
## own RGB and its own text into every page, so the ON state is the SUPERSET this suite's
## question is about -- "does what xschem writes actually distil". The shipped `none` output
## is that output with the strip removed and nothing else (proved byte for byte by row N25 of
## test_hier_pdf_links_1333.tcl), so sweeping the superset covers both.
proc child_export {dir tag sch ps {pre {}}} {
  set t [file join $dir $tag.tcl]
  catch {file delete $ps}
  set fd [open $t w]
  puts $fd "set ps_hier_nav both"
  foreach l $pre { puts $fd $l }
  puts $fd "xschem load {$sch}"
  puts $fd "xschem hier_psprint {$ps}"
  puts $fd "puts CHILD_DONE" ; puts $fd "flush stdout" ; puts $fd "exit 0"
  close $fd
  set here [pwd] ; cd $dir
  set rc 0
  if {[catch {exec [info nameofexecutable] --nogui --pipe -q --script $t 2>@1} out]} { set rc 1 }
  cd $here
  return [list $rc [regexp {FATAL: signal} $out] $out]
}

## ITEM H6 -- the page NAVIGATION STRIP (a Back button and the page's parent references) that
## src/psprint.c writes above the drawing area of every page of a hierarchical export, fenced
## by two PostScript comments. It puts a second kind of `/Subtype /Link` annotation and its own
## `RGB` and text into the file, so every row below that counts SYMBOL links, symbol rects or
## drawing colours strips it first and keeps the meaning it had. `distil` deliberately does NOT
## strip: its whole question is "did the PDF keep every page and every link the PostScript
## had", and the strip's annotations are part of that.
proc ps_strip_nav {d} {
  set out "" ; set in 0
  foreach line [split $d "\n"] {
    if {[string match "% xschem hier nav begin*" $line]} { set in 1 ; continue }
    if {[string match "% xschem hier nav end*" $line]}   { set in 0 ; continue }
    if {!$in} { append out $line "\n" }
  }
  return $out
}
## the number of Link annotations the strip contributes to a .ps
proc ps_nav_links {d} {
  return [expr {[regexp -all {/Subtype /Link} $d] - [regexp -all {/Subtype /Link} [ps_strip_nav $d]]}]
}
## SYMBOL-link rects out of a distilled PDF: the strip marks its own annotations `/F 4`.
proc pdf_sym_rects {d} {
  set r {}
  foreach {m body} [regexp -all -inline \
      {<</Type[[:space:]]*?/Annot(.*?)>>[[:space:]]*?endobj} $d] {
    if {[regexp {/F\s+4} $body]} { continue }
    if {[regexp {/Rect\s*\[([^\]]*)\]} $body . v]} { lappend r [string trim $v] }
  }
  return $r
}

## ps2pdf the file and report what came out. THE ROW THAT DECIDES THIS SUITE IS THIS PROC:
## exit code AND empty stderr AND page counts agreeing AND link counts agreeing. A row that
## merely greps the .ps for a known-bad string would pass while a fifth defect ships.
proc distil {ps} {
  set pdf [file rootname $ps].pdf
  set err [file rootname $ps].err
  catch {file delete $pdf}
  set rc 0 ; set eo ""
  if {[catch {exec ps2pdf $ps $pdf 2>$err} ]} { set rc 1 }
  set eo [slurp $err]
  set d [slurp $ps]
  set psp [regexp -all {(?n)^%%Page:} $d]
  set psl [regexp -all {/Subtype /Link} $d]
  set pdfp 0 ; set pdfl 0
  if {[file exists $pdf] && [file size $pdf] > 0} {
    catch {set pdfp [string trim [lindex [split [exec gs -q -dNODISPLAY -dNOSAFER \
        -c "($pdf) (r) file runpdfbegin pdfpagecount = quit"] "\n"] end]]}
    set pdfl [regexp -all {/Subtype\s*/Link} [slurp $pdf]]
  }
  catch {file delete $pdf}
  return [list $rc [string length $eo] $psp $psl $pdfp $pdfl [string range $eo 0 120]]
}
## clean == distilled with exit 0, nothing on stderr, and the PDF carrying every page and
## every link the PostScript had.
proc clean {r} {
  lassign $r rc eb psp psl pdfp pdfl
  return [expr {$rc == 0 && $eb == 0 && $psp > 0 && $pdfp == $psp && $pdfl == $psl}]
}

proc wsym {path k} {
  set fd [open $path w]
  foreach l [list "v {xschem version=3.4.6 file_version=1.2}" "G {}" "K {$k}" "V {}" "S {}" "E {}" \
    "L 4 -30 -20 30 -20 {}" "L 4 30 -20 30 20 {}" "L 4 -30 20 30 20 {}" "L 4 -30 -20 -30 20 {}"] {
    puts $fd $l
  }
  close $fd
}
proc wsch {path body} {
  set fd [open $path w]
  foreach l [list "v {xschem version=3.4.6 file_version=1.2}" "G {}" "K {}" "V {}" "S {}" "E {}"] {
    puts $fd $l
  }
  foreach l $body { puts $fd $l }
  close $fd
}

set sub "type=subcircuit\ntemplate=\"name=x1\""

# ======================================================= 1350: string literals ==
# V1 — the exact shape that kills the shipped 0_examples_top: ONE backslash as a text.
# ⚠ THE FIXTURE IS THE FIDDLY PART AND IT IS COUNTED, NOT REASONED. A `T {...}` record is
# an escaped string: TWO raw backslashes in the file are ONE character at the emitter, and
# that one character is what produces `(\)`. A fixture with one backslash reaches the
# emitter EMPTY and a fixture with four reaches it as two -- which PRE escapes correctly by
# accident and which therefore passes on the broken binary. Both were measured before this
# line was written; the first draft of this row used one and read `doubled=0 bare=0`, i.e.
# neither string present, a green-looking nothing. (The shipped case is
# xschem_library/devices/bindkeys_cheatsheet.sym line 141, the `\` key of its keyboard
# graphic, instantiated by xschem_library/examples/0_examples_top.sch; it is written with
# four and reaches the emitter as one, because instance text also goes through translate().)
set bsl [string repeat "\\" 2]
wsch [file join $dir bs.sch] [list "T {$bsl} 0 0 0 0 0.4 0.4 {}"]
lassign [child_export $dir bs [file join $dir bs.sch] [file join $dir bs.ps]] rc sig out
set bsd [slurp [file join $dir bs.ps]]
check "V1 (1350) a lone backslash in schematic text emits an ESCAPED PostScript string and\
 the document distils (HEAD emits the unterminated `(\\)` and gs dies with /syntaxerror)" \
  [expr {$rc == 0 && !$sig && [regexp {\(\\\\\)} $bsd] && ![regexp {(?n)^\(\\\)$} $bsd] \
         && [clean [distil [file join $dir bs.ps]]]}] \
  "(rc=$rc sig=$sig doubled=[regexp {\(\\\\\)} $bsd] bare=[regexp {(?n)^\(\\\)$} $bsd]\
 distil={[distil [file join $dir bs.ps]]})"

# V2 — backslash mixed with the two characters the escaper DID handle, plus a trailing one.
# A trailing `\` is the nastiest: it escapes the closing paren the emitter writes itself.
wsch [file join $dir bs2.sch] [list "T {a${bsl}b(c)d${bsl}} 0 0 0 0 0.4 0.4 {}"]
lassign [child_export $dir bs2 [file join $dir bs2.sch] [file join $dir bs2.ps]] rc2 sig2 out2
set r2 [distil [file join $dir bs2.ps]]
check "V2 (1350) backslash + parens + a TRAILING backslash still distils" \
  [expr {$rc2 == 0 && !$sig2 && [clean $r2]}] "(rc=$rc2 sig=$sig2 distil={$r2})"

# V3 — THE PAGE TITLE TAKES A FILENAME AND HAD NO ESCAPING AT ALL. `ps_page_title` is a
# shipped preference; the string it writes is xctx->current_name.
file mkdir [file join $dir t3]
wsch [file join $dir t3 "pa(re)n.sch"] [list "T {t} 0 0 0 0 0.4 0.4 {}"]
lassign [child_export $dir t3a [file join $dir t3 "pa(re)n.sch"] [file join $dir t3.ps] \
        [list "set ps_page_title 1"]] rc3 sig3 out3
set t3d [slurp [file join $dir t3.ps]]
set r3 [distil [file join $dir t3.ps]]
# (the title prints xctx->current_name, which is the full PATH -- hence the loose prefix)
set t3re {MT \([^\n]*pa\\\(re\\\)n\.sch\) show}
check "V3 (1350) the small page title escapes the file name it prints, and the sheet distils" \
  [expr {$rc3 == 0 && [regexp $t3re $t3d] && [clean $r3]}] \
  "(rc=$rc3 escaped=[regexp $t3re $t3d] distil={$r3})"

# ============================================================ 1352: /Dest names ==
# V4 — a cell whose FILE NAME contains a space. Both the page anchor and the link that
# points at it must be one token, and they must be the SAME token — the whole value of a
# link is that its /Dest matches a /DEST the document defines.
file mkdir [file join $dir lib]
wsym [file join $dir lib "my cell.sym"] $sub
wsch [file join $dir lib "my cell.sch"] [list "T {child} 0 0 0 0 0.4 0.4 {}"]
wsch [file join $dir sptop.sch] [list "C {my cell.sym} 0 0 0 0 {name=x1}"]
lassign [child_export $dir sp [file join $dir sptop.sch] [file join $dir sp.ps] \
        [list "set XSCHEM_LIBRARY_PATH \"[file join $dir lib]\""]] rc4 sig4 out4
set spd [slurp [file join $dir sp.ps]]
set anch {} ; set lnk {}
foreach {m n} [regexp -all -inline {/Dest /(\S+) /DEST} $spd] { lappend anch $n }
foreach {m n} [regexp -all -inline {/Dest /(\S+) /Subtype /Link} [ps_strip_nav $spd]] { lappend lnk $n }
set r4 [distil [file join $dir sp.ps]]
check "V4 (1352) a cell file name with a SPACE gives a single-token /Dest, the page anchor\
 and the link agree, and the export distils (HEAD: `/Dest /my cell.sch`, gs /undefined,\
 ZERO pages out)" \
  [expr {$rc4 == 0 && [lsearch -exact $anch "my_cell.sch"] >= 0 && $lnk eq [list my_cell.sch] \
         && [clean $r4]}] \
  "(anchors={$anch} links={$lnk} distil={$r4})"

# V5 — the other delimiters, on the name a page anchors itself with.
file mkdir [file join $dir t5]
wsch [file join $dir t5 "a(b)c%d\[e\].sch"] [list "T {t} 0 0 0 0 0.4 0.4 {}"]
lassign [child_export $dir t5a [file join $dir t5 "a(b)c%d\[e\].sch"] [file join $dir t5.ps]] rc5 s5 o5
set t5d [slurp [file join $dir t5.ps]]
set r5 [distil [file join $dir t5.ps]]
check "V5 (1352) parens, percent and brackets in a file name are substituted, not emitted" \
  [expr {$rc5 == 0 && [regexp {/Dest /a_b_c_d_e_\.sch /DEST} $t5d] && [clean $r5]}] \
  "(dest={[regexp -inline {/Dest /\S+ /DEST} $t5d]} distil={$r5})"

# ============================================================== 1351: font names ==
# V6 — THE SHIPPED FATAL ONE. xschem_library/ngspice_verilog_cosim/counter.sym carries
# font="courier new"; with TEXT_BOLD that emitted `/courier new-Bold FF`.
wsch [file join $dir f6.sch] [list "T {bold text} 0 0 0 0 0.4 0.4 {font=\"courier new\" weight=bold}"]
lassign [child_export $dir f6 [file join $dir f6.sch] [file join $dir f6.ps]] rc6 s6 o6
set f6d [slurp [file join $dir f6.ps]]
set f6names {}
foreach {m n} [regexp -all -inline {(?n)^/(\S+) FF$} $f6d] { lappend f6names $n }
set r6 [distil [file join $dir f6.ps]]
check "V6 (1351) `font=\"courier new\"` + bold emits ONE name token that findfont can\
 resolve, and the sheet distils (HEAD: `/courier new-Bold`, gs /undefined)" \
  [expr {$rc6 == 0 && [lsearch -exact $f6names "Courier-Bold"] >= 0 \
         && ![regexp {(?n)^/\S+ \S+ FF$} $f6d] && [clean $r6]}] \
  "(names={[lsort -unique $f6names]} distil={$r6})"

# V7 — the generic CSS/Cairo family names xschem's own renderer resolves through
# fontconfig and PostScript has never heard of. gs substitutes EVERY unknown name with
# Courier (measured -- /Monospace, /monospace and /serif all resolve to /Courier), so
# `font=serif` renders MONOSPACED today: this row is the repair, and it is a TYPEFACE
# CHANGE on sheets that already distilled. ONE TEXT PER CHILD: several texts on one sheet
# and the page bbox clips some of them away, and the row then silently measures fewer
# fonts than it wrote (measured -- the first draft lost 2 of 5).
set v7map {serif Times monospace Courier Monospace Courier sans-serif Helvetica
           Symbol Symbol {courier new} Courier}
set v7bad {} ; set v7got {}
set v7i 0
foreach {want got} $v7map {
  set tag v7[incr v7i]
  wsch [file join $dir $tag.sch] [list "T {x} 0 0 0 0 0.4 0.4 {font=\"$want\"}"]
  lassign [child_export $dir $tag [file join $dir $tag.sch] [file join $dir $tag.ps]] rc7 s7 o7
  set names {}
  foreach {m n} [regexp -all -inline {(?n)^/(\S+) FF$} [slurp [file join $dir $tag.ps]]] {
    lappend names $n
  }
  lappend v7got "$want->{$names}"
  if {$rc7 != 0 || $s7 || [lsearch -exact $names $got] < 0} { lappend v7bad "$want!=$got" }
}
check "V7 (1351) the generic families map to the base-14 set: serif->Times,\
 monospace/Monospace->Courier, sans-serif->Helvetica, Symbol->Symbol, courier new->Courier" \
  [expr {[llength $v7bad] == 0}] "(bad={$v7bad} got={$v7got})"

# V8 — AND IT MAPS ONLY THE GENERIC ONES. A real face name must reach findfont unchanged:
# the distiller may actually have it, and substituting Helvetica for a font gs could
# resolve would LOSE fidelity. This row is what stops the alias table growing into a
# blanket rewrite.
wsch [file join $dir f8.sch] [list \
  "T {a} 0 0 0 0 0.4 0.4 {font=Garamond}" \
  "T {b} 0 -40 0 0 0.4 0.4 {font=FreeMono}" \
  "T {c} 0 -80 0 0 0.4 0.4 {font=Times-Roman}"]
lassign [child_export $dir f8 [file join $dir f8.sch] [file join $dir f8.ps]] rc8 s8 o8
set f8d [slurp [file join $dir f8.ps]]
set f8names {}
foreach {m n} [regexp -all -inline {(?n)^/(\S+) FF$} $f8d] { lappend f8names $n }
check "V8 (1351) a REAL face name is not rewritten -- Garamond, FreeMono and Times-Roman\
 reach findfont as themselves" \
  [expr {$rc8 == 0 && [lsearch -exact $f8names Garamond] >= 0 \
         && [lsearch -exact $f8names FreeMono] >= 0 \
         && [lsearch -exact $f8names Times-Roman] >= 0}] \
  "(names={[lsort -unique $f8names]})"

# V9 — a font name that is nothing but delimiters must not emit `/ FF`, which is the empty
# name and reads as the next token.
wsch [file join $dir f9.sch] [list "T {x} 0 0 0 0 0.4 0.4 {font=\"( )\"}"]
lassign [child_export $dir f9 [file join $dir f9.sch] [file join $dir f9.ps]] rc9 s9 o9
set f9d [slurp [file join $dir f9.ps]]
set r9 [distil [file join $dir f9.ps]]
check "V9 (1351) a font= made only of delimiters falls back to Helvetica, not to the empty\
 name" \
  [expr {$rc9 == 0 && ![regexp {(?n)^/ FF$} $f9d] && [regexp {(?n)^/Helvetica FF$} $f9d] \
         && [clean $r9]}] "(rc=$rc9 distil={$r9})"

# V10 — THE FORMAT-STRING BUG, AND IT IS A CRASH. `my_snprintf(buf, S(buf), textfont)`
# passed a schematic attribute as the FORMAT. Spawned: on HEAD this is `FATAL: signal 11`.
wsch [file join $dir f10.sch] [list "T {x} 0 0 0 0 0.4 0.4 {font=\"%s %n %s %s %s\"}"]
lassign [child_export $dir f10 [file join $dir f10.sch] [file join $dir f10.ps]] rc10 s10 o10
set r10 [distil [file join $dir f10.ps]]
check "V10 (1351) `font=` containing printf conversions does not crash the export\
 (HEAD: FATAL: signal 11)" \
  [expr {$rc10 == 0 && !$s10 && [file exists [file join $dir f10.ps]] && [clean $r10]}] \
  "(rc=$rc10 sig=$s10 distil={$r10})"

# ========================================================= 1342: the line width ==
# V11 — the sink. A line width that no page can mean must not reach the file, and the two
# shapes are "past the single-precision ceiling" and "not a number at all".
set lwsrc [slurp [file join $repo src psprint.c]]
check "V11 (1342) set_lw() rejects non-finite and out-of-range widths before printing them" \
  [expr {[regexp {w != w \|\| w < 0\.0 \|\| w > PS_LW_MAX} $lwsrc] \
         && [regexp {#define PS_LW_MAX} $lwsrc]}] \
  "(guard=[regexp {w != w \|\| w < 0\.0 \|\| w > PS_LW_MAX} $lwsrc])"

# V21 (1342) — THE CLAMP IS NOT ONLY DEFENCE IN DEPTH: IT CLOSES A ROUTE THE SOURCE FIX
# CANNOT. `bus=` is a user attribute and ps_filledrect() multiplies it straight into a line
# width, so a rect written `bus=1e300` or `bus=inf` kills the export from the .sch file —
# nothing uninitialised about it. Measured on HEAD: `3.4241e+300 setlinewidth` and the literal
# token `inf setlinewidth` (which PostScript reads as an executable NAME), ps2pdf exit 1 in
# both cases. This row is why sabotage A — removing the clamp — must redden something
# behavioural and not only the static row V11. (`bus=nan` does NOT reach the sink: NaN fails
# the `bus > 0.0` test in ps_filledrect() and the width is never emitted. Checked, not assumed.)
set v21bad {}
foreach v {1e300 inf -1e300} {
  wsch [file join $dir bw.sch] [list "B 4 -100 -100 100 100 {bus=$v}" "T {t} 0 0 0 0 0.4 0.4 {}"]
  lassign [child_export $dir bw [file join $dir bw.sch] [file join $dir bw.ps]] wrc wsg wout
  set d [slurp [file join $dir bw.ps]]
  set outofrange 0
  foreach {m w} [regexp -all -inline {(?n)^(\S+) setlinewidth$} $d] {
    if {![string is double -strict $w] || $w < 0.0 || $w > 1e6} { incr outofrange }
  }
  set r [distil [file join $dir bw.ps]]
  if {$wrc != 0 || $wsg || $outofrange || ![clean $r]} { lappend v21bad "bus=$v:{$r} bad=$outofrange" }
  catch {file delete [file join $dir bw.ps]}
}
check "V21 (1342) a `bus=` attribute of 1e300, inf or -1e300 cannot put a number PostScript\
 has no room for into the file, and the sheet still distils" \
  [expr {[llength $v21bad] == 0}] "(bad={$v21bad})"

# V12 — THE SOURCE, not the sink. The garbage is an uninitialised `bus` in the xRect
# add_pinlayer_boxes() synthesises for an LCC pin. The two shipped LCC sheets are the
# fixture; on HEAD they emit `9.7725e+160` / `6.46175e+274 setlinewidth` and ps2pdf
# truncates them to one page.
set lcc 0 ; set lccbad {} ; set lccdet {}
foreach s {LCC_instances poweramp_lcc} {
  set f [file join $repo xschem_library examples $s.sch]
  if {![file exists $f]} continue
  incr lcc
  lassign [child_export $dir lcc$s $f [file join $dir lcc$s.ps]] lrc lsg lout
  set d [slurp [file join $dir lcc$s.ps]]
  foreach {m v} [regexp -all -inline {(?n)^(\S+) setlinewidth$} $d] {
    if {[string is double -strict $v] && (abs($v) > 3.4e38)} { lappend lccbad "$s:$v" }
  }
  set rr [distil [file join $dir lcc$s.ps]]
  lappend lccdet "$s={$rr}"
  if {![clean $rr]} { lappend lccbad "$s:DISTIL" }
}
check "V12 (1342) the two shipped LCC sheets emit no out-of-range real and distil whole\
 -- the uninitialised xRect.bus is fixed at SOURCE in add_pinlayer_boxes()" \
  [expr {$lcc == 2 && [llength $lccbad] == 0}] "(bad={$lccbad} $lccdet)"

# V18 — THE BEHAVIOURAL FENCE FOR THE SOURCE FIX, and it exists because the two 1342 hunks
# each cover for the other. Sabotage measured: removing the set_lw() clamp reddens only the
# static row V11, and removing the save.c initialisation reddens only the static row V13 --
# each alone keeps the corpus clean, so neither hunk had a row that could SEE it. This one
# can: an uninitialised `bus` is not only a width, it also takes ps_filledrect()'s BUS
# BRANCH, which brackets the rect with `0 setlinejoin 2 setlinecap`. The clamp cannot undo
# that; only initialising the field can. Seven shipped sheets that contain no `bus=` rect at
# all emitted those brackets on HEAD -- bus_keeper, LCC_instances, loading, poweramp_lcc,
# voltage_protection, 0_pcb_top, hierarchical_tedax -- and it is what painted the solid grey
# block over the left half of hierarchical_tedax's only page.
set v18bad {} ; set v18n 0
foreach s {LCC_instances poweramp_lcc loading bus_keeper} {
  set f [file join $repo xschem_library examples $s.sch]
  if {![file exists $f]} continue
  incr v18n
  set src [slurp $f]
  lassign [child_export $dir bus$s $f [file join $dir bus$s.ps]] brc bsg bout
  set d [slurp [file join $dir bus$s.ps]]
  set nbus [regexp -all {(?n)^0 setlinejoin 2 setlinecap$} $d]
  # the sheet must have no bus rect to begin with -- assert that, do not assume it
  if {[regexp {bus=} $src] || $brc != 0 || $nbus != 0} { lappend v18bad "$s:bus=$nbus,rc=$brc" }
  catch {file delete [file join $dir bus$s.ps]}
}
check "V18 (1342) a sheet with no `bus=` rect emits no bus-styled stroke: the uninitialised xRect.bus also took ps_filledrect()'s BUS BRANCH, which the sink clamp cannot undo"   [expr {$v18n == 4 && [llength $v18bad] == 0}] "(n=$v18n bad={$v18bad})"

# V19 (1353) — THE COLOUR HALF OF 1342, AND IT IS AN OUT-OF-BOUNDS READ, NOT AN
# UNINITIALISED ONE. `ps_colors` is my_calloc(cadlayers, ...), but create_ps() runs the text
# pass as `ps_draw_symbol(c + 1, i, c + 1, ...)` when c == cadlayers - 1, and that pass ends
# with `if(textlayer != c) set_ps_colors(c)` -- restoring the colour of a pseudo-layer.
# valgrind: "Invalid read of size 4 ... 8 bytes after a block of size 264" (264 = cadlayers x
# sizeof(Ps_color)). setrgbcolor CLAMPS, so it never killed a document -- which is exactly why
# 1342 was believed cosmetic and why this needed a row of its own.
#
# THE FIXTURE IS BUILT FOR DETERMINISM, because the VALUE is heap garbage and the COUNT is
# not: two texted instances over two pages emit four pseudo-layer restores. Measured, same
# fixture: HEAD 12 RGB lines / THREE distinct triples (the third `0.128906 0 7.30277e+06`);
# fixed 8 lines / TWO. So the row asserts the DISTINCT count and the channel range together --
# a garbage triple that happened to land inside 0..1 would still be a third distinct value.
# The distinct count is what is deterministic here; the TOTAL is not (it moves with how many
# colour changes the page happens to make), and a first draft of this row asserted 8 and
# redded on a correct binary at 5.
set tfd [open [file join $dir lib txt.sym] w]
foreach l [list "v {xschem version=3.4.6 file_version=1.2}" "G {}" "K {$sub}" "V {}" "S {}" "E {}" \
  "L 4 -30 -20 30 -20 {}" "L 4 30 -20 30 20 {}" "L 4 -30 20 30 20 {}" "L 4 -30 -20 -30 20 {}" \
  "T {@name} -30 -32 0 0 0.3 0.3 {}"] { puts $tfd $l }
close $tfd
wsch [file join $dir lib txt.sch] [list "T {leaf} 0 0 0 0 0.4 0.4 {}"]
wsch [file join $dir txtop.sch] [list "C {txt.sym} 0 0 0 0 {name=x1}" "C {txt.sym} 200 0 0 0 {name=x2}"]
lassign [child_export $dir txt [file join $dir txtop.sch] [file join $dir txt.ps] \
        [list "set XSCHEM_LIBRARY_PATH \"[file join $dir lib]\""]] rc19 s19 o19
set rgb {} ; set rgbbad 0
foreach {m r g b} [regexp -all -inline {(?n)^(\S+) (\S+) (\S+) RGB$} \
                   [ps_strip_nav [slurp [file join $dir txt.ps]]]] {
  lappend rgb [list $r $g $b]
  foreach v [list $r $g $b] {
    if {![string is double -strict $v] || $v < 0.0 || $v > 1.0} { incr rgbbad }
  }
}
check "V19 (1353) set_ps_colors() does not claim a colour for the pseudo-layer the text pass\
 runs at: every RGB triple is a real palette entry, in range (HEAD: 3 distinct triples on this\
 fixture, the third out of range on a 0..1 scale)" \
  [expr {$rc19 == 0 && [llength $rgb] > 0 && $rgbbad == 0 \
         && [llength [lsort -unique $rgb]] == 2}] \
  "(lines=[llength $rgb] distinct=[llength [lsort -unique $rgb]] outofrange=$rgbbad)"

set svsrc [slurp [file join $repo src save.c]]
check "V13 (1342) add_pinlayer_boxes() initialises every field of the xRect it synthesises" \
  [expr {[regexp {bb\[PINLAYER\]\[i\]\.bus = 0\.0;} $svsrc] \
         && [regexp {bb\[PINLAYER\]\[i\]\.id = 0;} $svsrc]}] \
  "(bus=[regexp {bb\[PINLAYER\]\[i\]\.bus = 0\.0;} $svsrc] id=[regexp {bb\[PINLAYER\]\[i\]\.id = 0;} $svsrc])"

# ================================================ THE CORPUS ROW — 1343 ITSELF ==
# The row that decides the item. Not a grep for three known-bad strings: EXPORT the sheet,
# RUN the distiller, READ the resulting PDF. A grep would pass while a fifth defect ships.
# Every shipped example, every generator, every gschem_import sheet, the four other
# directories issue 1343 named, and six real sky130 OA hierarchies with the registry
# loaded. Issue 1343's five named files are all in here; so are the six MORE this item
# found (0_pcb_top, hierarchical_tedax, voltage_protection, intuitive_interface_cheatsheet,
# tb_counter_wrapper, and sky130_tests/top).
set corpus {}
foreach sub {examples generators gschem_import pcb ngspice_verilog_cosim devices} {
  foreach f [lsort [glob -nocomplain [file join $repo xschem_library $sub *.sch]]] {
    # xschem drops gitignored `<name>~.sch` backups beside the originals when a test saves,
    # so a bare *.sch glob makes this row's sheet COUNT depend on who ran what last. Four
    # were present in the tree this row was written in and absent from a clean checkout.
    if {[string match {*~} [file rootname [file tail $f]]]} continue
    lappend corpus [list [file join $sub [file tail $f]] $f {}]
  }
}
set oadefs [file join $repo sky130A xschem_libs library.defs]
set oapre [list "set ::XSCHEM_LIBRARY_DEFS {$oadefs}" "set ::library_registry_defs_only 1" \
                "set ::XSCHEM_LIBRARY_PATH {}"]
set oacells {}
if {[file exists $oadefs]} {
  foreach c {sky130_tests/top sky130_tests_ase/top sky130_tests/tb_bandgap
             sky130_tests/test_carry_lookahead sky130_tests/test_generators
             sky130_tests_ase/tb_charge_pump sky130_tests/mips} {
    set lib [file dirname $c] ; set cell [file tail $c]
    set f [file join $repo sky130A xschem_libs $lib $cell schematic $cell.sch]
    if {[file exists $f]} {
      lappend corpus [list "OA/$c" $f [concat $oapre \
        [list "puts \"CELLVIEW |\[cellview_path $c schematic\]|\""]]]
      lappend oacells $c
    }
  }
}
set bad {} ; set nsheets 0 ; set npages 0 ; set nlinks 0 ; set nocv {}
set rgbtot 0 ; set rgbsheets {}
foreach e $corpus {
  lassign $e name f pre
  set tag c[incr nsheets]
  set ps [file join $dir $tag.ps]
  lassign [child_export $dir $tag $f $ps $pre] crc csg cout
  if {[string match OA/* $name]} {
    if {![regexp {CELLVIEW \|([^|]*)\|} $cout . cv] || $cv eq ""} { lappend nocv $name ; continue }
  }
  if {$crc != 0 || $csg} { lappend bad "$name:EXPORT" ; continue }
  set r [distil $ps]
  lassign $r rc eb psp psl pdfp pdfl etxt
  incr npages $psp ; incr nlinks $psl
  if {![clean $r]} { lappend bad "$name:rc=$rc,err=$eb,pg=$psp/$pdfp,lk=$psl/$pdfl" }
  # 1353 over the whole corpus, on the SAME exports -- cheap, and the only row that can say
  # how big it was. HEAD wrote 61029 out-of-range triples over a 325-sheet corpus on one sweep
  # -- but that figure is HEAP-DEPENDENT and must not be read as a categorical: the same binary
  # on the same file gives 27/0/27, and 77 of 321 sheets showed zero on another sweep. The
  # deterministic half is the one this row asserts: ZERO, after the fix, every time. Was, on one sweep,
  # of them.
  foreach {m r g b} [regexp -all -inline {(?n)^(\S+) (\S+) (\S+) RGB$} [ps_strip_nav [slurp $ps]]] {
    foreach v [list $r $g $b] {
      if {![string is double -strict $v] || $v < 0.0 || $v > 1.0} {
        incr rgbtot ; if {[lsearch -exact $rgbsheets $name] < 0} { lappend rgbsheets $name }
      }
    }
  }
  catch {file delete $ps}
}
check "V14 (1343) THE CORPUS: every one of $nsheets sheets distils with exit 0, EMPTY\
 stderr, and a PDF carrying every page and every link the PostScript had\
 ($npages PostScript pages, $nlinks links). On HEAD 11 of them die" \
  [expr {[llength $bad] == 0 && $nsheets > 90}] "(bad={$bad})"
check "V20 (1353) and not one of those $nsheets exports writes an RGB channel outside 0..1\
 (HEAD: 61029 such triples on one sweep of a 325-sheet corpus; heap-dependent, not a categorical)" \
  [expr {$rgbtot == 0}] "(bad triples=$rgbtot on [llength $rgbsheets] sheets: [lrange $rgbsheets 0 4] ...)"

check "V15 (1343) the OA arm really had the registry -- cellview_path resolved for all\
 [llength $oacells] sky130 hierarchies (an empty registry silently exports ONE page and\
 looks like a pass)" \
  [expr {[llength $nocv] == 0 && [llength $oacells] >= 6}] "(cells={$oacells} noresolve={$nocv})"

# V16 — 0_examples_top BY NAME AND BY NUMBER. This is the row in the item's brief.
set topsch [file join $repo xschem_library examples 0_examples_top.sch]
if {[file exists $topsch]} {
  lassign [child_export $dir big $topsch [file join $dir big.ps]] brc bsg bout
  set r16 [distil [file join $dir big.ps]]
  lassign $r16 rc16 eb16 psp16 psl16 pdfp16 pdfl16
  set nav16 [ps_nav_links [slurp [file join $dir big.ps]]]
  check "V16 (1343/H6) xschem_library/examples/0_examples_top.sch: 99 PostScript pages and 305\
 SYMBOL links become 99 PDF pages and every annotation the PostScript had, ps2pdf exit 0,\
 stderr empty (HEAD: 10 pages, 67 links, exit 1). Item H6 ADDS the navigation strip's own\
 annotations and removes none, so the 305 is asserted separately from the total" \
    [expr {$brc == 0 && !$bsg && $psp16 == 99 && $psl16 - $nav16 == 305 && $nav16 > 99 \
           && $pdfp16 == 99 && $pdfl16 == $psl16 && $rc16 == 0 && $eb16 == 0}] \
    "(ps=$psp16/$psl16 pdf=$pdfp16/$pdfl16 nav=$nav16 forward=[expr {$psl16-$nav16}]\
 rc=$rc16 errbytes=$eb16)"
  catch {file delete [file join $dir big.ps]}
} else {
  check "V16 0_examples_top.sch present" 0 "(missing)"
}

# V17 — DD-3, the batch's regression control, read through the DISTILLER rather than off
# the .ps: greycnt -> xnor, 14 congruent link rects. This item changes line widths and font
# selection; if either moved a link rect, this row says so. The absolute is a --nogui
# number (issue 1345) and this suite is --nogui.
set gc [file join $repo xschem_library examples greycnt.sch]
if {[file exists $gc]} {
  lassign [child_export $dir gc $gc [file join $dir gc.ps]] grc gsg gout
  set gps [file join $dir gc.ps]
  set gpdf [file join $dir gc.pdf]
  set grects {}
  if {![catch {exec ps2pdf $gps $gpdf}]} {
    foreach v [pdf_sym_rects [slurp $gpdf]] {
      lassign $v a b c d
      lappend grects [list [format %.3f [expr {abs($c-$a)}]] [format %.3f [expr {abs($d-$b)}]]]
    }
  }
  set gw {} ; set gh {}
  foreach r $grects { lappend gw [lindex $r 0] ; lappend gh [lindex $r 1] }
  set gcong 1
  foreach w $gw h $gh {
    if {abs($w - [lindex $gw 0]) > 0.005 || abs($h - [lindex $gh 0]) > 0.005} { set gcong 0 }
  }
  # DD-3's constant carries a 0.005 pt tolerance and this row keeps it: 61.487 x 35.135 is a
  # --nogui number (issue 1345) and the PDF rounds the CTM product, so the fourteen rects
  # measure 61.486-61.487 x 35.135-35.136 in one export. Congruence is asserted at the same
  # tolerance rather than by string equality -- which is what this row did first, and it
  # redded on a correct binary.
  check "V17 (DD-3) greycnt still exports 14 mutually congruent link rects at\
 61.487 x 35.135 pt (+/-0.005) after distillation" \
    [expr {$grc == 0 && [llength $grects] == 14 && $gcong \
           && abs([lindex $gw 0] - 61.487) <= 0.005 && abs([lindex $gh 0] - 35.135) <= 0.005}] \
    "(n=[llength $grects] congruent=$gcong first=[lindex $gw 0] x [lindex $gh 0])"
  catch {file delete $gps $gpdf}
} else {
  check "V17 greycnt.sch present" 0 "(missing)"
}

## Both banners, for the same reason as test_hier_pdf_links_1333.tcl: run_suites.sh scores
## a headless suite from its `^RESULT` line and T1 scores it from banner_rule.tcl's
## whole-line `OVERALL: ok`, which knows nothing about `RESULT:`. A suite registered in
## T1's `hcases` with only the first is scored `HARNESS: ... did not complete cleanly` --
## a counted failure with every one of its own checks green.
if {$fail == 0} {
  puts "RESULT: ALL PASS ($pass checks)"
  puts "OVERALL: ok ($pass checks)"
} else {
  puts "RESULT: $fail FAILED ($pass passed)"
  puts "OVERALL: notok"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
