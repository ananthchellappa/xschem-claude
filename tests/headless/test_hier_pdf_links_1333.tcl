# Issues 1333 / 1334 / 1335 — the /Link pdfmarks written by `xschem hier_psprint`.  ITEMS H1a + H1b.
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
# The hierarchical PDF export writes one `/Subtype /Link` annotation per subcircuit symbol so a
# reviewer can click the symbol and land on that cell's page. Item H1a closes the two defects in
# that emitter (src/psprint.c, the pdfmark block in ps_draw_symbol()) that can be fixed by ADDING
# behaviour only — it does not remove a single link from any sheet:
#
#   1333  `xctx->sym[inst[n].ptr].type` was dereferenced UNGUARDED, while the SAME value is
#         loaded into the `type` local at the top of the function and treated as nullable 70
#         lines above (`if( type && strcmp(type, "launcher") && ...`). A symbol with no `type`
#         attribute segfaulted the whole hierarchical export. This is not hypothetical: the
#         shipped xschem_library/devices/bindkeys_cheatsheet.sym carries `K {}`, so the shipped
#         example xschem_library/examples/0_examples_top.sch dies with `FATAL: signal 11` on
#         the pre-change binary. Row S1b runs that very file.
#   1335  spice_netlist.c:96 gives a page to `subcircuit` OR `primitive`; this emitter tested
#         only `subcircuit`, so a primitive-with-a-schematic got a page nothing linked to,
#         reachable only by scrolling.
#
#   1334  a link was emitted for a cell that gets NO page — the silent dead click. Item **H1b**
#         (rows S40..S52) closes it, and it closes it by asking a question the two REFUTED
#         attempts before it did not ask. Those asked "would this cell pass hier_psprint()'s
#         page filter?" and re-derived the filter (`type`/`noprint_libs`/`default_schematic`)
#         from the instance's BASE symbol — but get_additional_symbols() (actions.c:5451) MINTS
#         a separate symbol per instance-level `schematic=` and deletes its default_schematic,
#         and it is the MINTED symbol that gets paged. Reading one object while vetting the
#         other fails in BOTH directions, and it DELETED LIVE LINKS from shipped sheets. H1b
#         instead runs hier_psprint()'s own walk once in a collect-only mode, records the
#         destination name each page will anchor, and has the emitter look its own /Dest up in
#         that set: emit a link only if the export really contains a page of that name. See
#         ruling DD-6 in the op-wcard branch's doc/claude/hier_pdf_links_batch/DECISIONS.md.
#
# ⚠ EVERY H1b ROW EXISTS BECAUSE A PREVIOUS ATTEMPT GOT THAT CASE WRONG. S43 (a base symbol
# under noprint_libs whose instance overrides to a printable cell) and S47 (the SHIPPED
# xschem_library/examples/tb_test_evaluated_param.sch, which exists to demonstrate
# `default_schematic=ignore` + per-instance overrides) are LIVE links that H1 and H1-2 deleted;
# S44 is a dead link H1-2 left behind; S49 is the generator route filed as issue 1340. S41 and
# S48 fence H1b's own first control: **the page set must not move**, because the collect pass
# is a read. The 30-check H1/H1-2 version is preserved verbatim at
# the op-wcard branch's
# doc/claude/hier_pdf_links_batch/test_hier_pdf_links_1333_H1-2_30checks_DEFERRED.tcl — its
# S16..S29 are NOT these rows and its predicate is the one DD-6 rejects.
#
# The 1333 rows run in SPAWNED --nogui children: the defect they fence is a segfault, which
# would take this script's own process with it. S1 constructs a real symbol with no `type` line
# — it does not assert on a mock — and S1b uses the shipped file that actually crashes.
#
# DD-3 control rows (S12..S15): xschem_library/examples/greycnt.sch must still export its 14
# congruent link rects. Those rows are NON-REDDENING under any sabotage of an H1a hunk, and that
# is their job: they fence the ABSENCE of change. They do redden if the emitter is broken in the
# other direction (measured: forcing the condition false takes S12/S13/S15 red).
#
# Run:
#   ./src/xschem --nogui --pipe -q --script tests/headless/test_hier_pdf_links_1333.tcl
# (also passes with a display; it draws nothing to the screen and opens no dialog — the
# destination file is given to `hier_psprint`, so ps_draw()'s save-file dialog never arms.)

set fail 0
set pass 0
proc check {n ok d} {
  global fail pass
  if {$ok} { puts "ok:   $n $d" ; incr pass } else { puts "FAIL: $n $d" ; incr fail }
}

source [file join [file dirname [info script]] scratch.tcl]
set dir [test_scratch h1links]

set repo [file normalize [file join [file dirname [info script]] .. ..]]
set greycnt [file join $repo xschem_library examples greycnt.sch]
set exdir   [file join $repo xschem_library examples]

# ---------------------------------------------------------------- fixtures ---
# Six cells, one per route through the page filter. Bodies are 60x40 user units and the
# instances sit 200 apart, so every instance stays well over the 3-px floor at which
# ps_draw_symbol() bails out early (that floor is issue 1337, item H2 — not this suite).
proc wsym {path k} {
  set fd [open $path w]
  puts $fd "v {xschem version=3.4.6 file_version=1.2}"
  puts $fd "G {}"
  puts $fd "K {$k}"
  puts $fd "V {}"
  puts $fd "S {}"
  puts $fd "E {}"
  puts $fd "L 4 -30 -20 30 -20 {}"
  puts $fd "L 4 30 -20 30 20 {}"
  puts $fd "L 4 -30 20 30 20 {}"
  puts $fd "L 4 -30 -20 -30 20 {}"
  close $fd
}
proc wsch {path label} {
  set fd [open $path w]
  puts $fd "v {xschem version=3.4.6 file_version=1.2}"
  puts $fd "G {}"
  puts $fd "K {}"
  puts $fd "V {}"
  puts $fd "S {}"
  puts $fd "E {}"
  puts $fd "T {$label} 0 0 0 0 0.4 0.4 {}"
  close $fd
}

set sub "type=subcircuit\ntemplate=\"name=x1\""
wsym [file join $dir good.sym]   $sub                                          ;# normal -> page + link
wsym [file join $dir np.sym]     $sub                                          ;# excluded by noprint_libs
wsym [file join $dir ign.sym]    "type=subcircuit\ndefault_schematic=ignore\ntemplate=\"name=x1\""
wsym [file join $dir miss.sym]   $sub                                          ;# its .sch is not written
wsym [file join $dir prim.sym]   "type=primitive\ntemplate=\"name=x1\""        ;# 1335
wsym [file join $dir primns.sym] "type=primitive\ntemplate=\"name=x1\""        ;# 1335, but NO .sch
wsym [file join $dir notype.sym] ""                                            ;# 1333: NO type line at all
foreach c {good np ign prim notype} { wsch [file join $dir $c.sch] $c }        ;# miss.sch deliberately absent

proc wtop {path cells} {
  set fd [open $path w]
  puts $fd "v {xschem version=3.4.6 file_version=1.2}"
  puts $fd "G {}"
  puts $fd "K {}"
  puts $fd "V {}"
  puts $fd "S {}"
  puts $fd "E {}"
  set x 0 ; set i 1
  foreach c $cells {
    puts $fd "C {$c.sym} $x 0 0 0 {name=x$i}"
    incr x 200 ; incr i
  }
  close $fd
}
wtop [file join $dir top.sch]     {good np ign miss prim primns}
wtop [file join $dir h1notype.sch] {good np ign miss prim notype}

# ------------------------------------------- H1b fixtures (issue 1334, DD-6) ---
# Every one of these is a case a previous attempt got WRONG. They all turn on the same
# mechanism: get_additional_symbols() (actions.c:5451) MINTS a symbol for each instance-level
# `schematic=` override, deletes its default_schematic, and it is the MINTED symbol that
# hier_psprint() pages — so the base symbol's attributes say nothing about whether the page
# the link names exists.
wsym [file join $dir good2.sym] $sub              ;# printable override TARGET (S43)
wsym [file join $dir nbase.sym] $sub              ;# base is matched by noprint_libs (S43)
wsym [file join $dir obase.sym] $sub              ;# printable base (S44)
wsym [file join $dir npx.sym]   $sub              ;# override target matched by noprint_libs (S44)
foreach c {good2 nbase obase npx} { wsch [file join $dir $c.sch] $c }

# Two libraries, one cell name — the homonym that proved half of H1 unfenced. A PDF named
# destination is a FLAT basename, so both libraries' `inv` share one /Dest.
file mkdir [file join $dir A] [file join $dir B]
wsym [file join $dir A inv.sym] "type=subcircuit\ndefault_schematic=ignore\ntemplate=\"name=x1\""
wsym [file join $dir B inv.sym] $sub
wsch [file join $dir A inv.sch] invA
wsch [file join $dir B inv.sch] invB

## like wtop, but each element is {symfile extra-attrs}
proc wtopa {path cells} {
  set fd [open $path w]
  puts $fd "v {xschem version=3.4.6 file_version=1.2}"
  puts $fd "G {}"
  puts $fd "K {}"
  puts $fd "V {}"
  puts $fd "S {}"
  puts $fd "E {}"
  set x 0 ; set i 1
  foreach c $cells {
    lassign $c sym attrs
    puts $fd "C {$sym} $x 0 0 0 {name=x$i$attrs}"
    incr x 200 ; incr i
  }
  close $fd
}
# S43: the base symbol is excluded by noprint_libs; the instance overrides to a PRINTABLE cell.
wtopa [file join $dir topN.sch] {{nbase.sym "\nschematic=good2.sch"}}
# S44: printable base; one instance overridden to a cell noprint_libs excludes, one not.
wtopa [file join $dir topO.sch] {{obase.sym "\nschematic=npx.sch"} {obase.sym ""}}
# S45: only the `default_schematic=ignore` twin is instantiated -> nothing pages inv.sch.
wtopa [file join $dir topH1.sch] {{A/inv.sym ""} {good.sym ""}}
# S46: the PRINTABLE twin is instantiated first, so inv.sch IS a page -> BOTH links live.
wtopa [file join $dir topH3.sch] {{B/inv.sym ""} {A/inv.sym ""} {good.sym ""}}

# ------------------------------------------- H2 fixtures (issue 1337) ---
# ps_draw_symbol() draws an instance as a filled blob and RETURNS EARLY when
#   (inst.x2-inst.x1)*mooz < 3 && (inst.y2-inst.y1)*mooz < 3
# -- and that return was before the pdfmark block, so the small subcircuit instances on a
# dense sheet, exactly the ones a reviewer most needs to click through, had no link at all.
# This is a SEPARATE, WIDER sheet on purpose: H1b's fixtures are 60x40 bodies at 200 pitch and
# are far above the floor, and shrinking THEM would silently disarm S40..S46 (H1b's receipt,
# "what binds H2"). Here the same 60x40 bodies are spread over 400000 user units, so zoom_full
# puts every one of them at ~0.15 px and every instance on the sheet takes the small branch --
# measured on the pre-change binary: 2 blob `R` rects, 2 pages, ZERO links.
proc wtopp {path cells pitch} {
  set fd [open $path w]
  puts $fd "v {xschem version=3.4.6 file_version=1.2}"
  puts $fd "G {}"
  puts $fd "K {}"
  puts $fd "V {}"
  puts $fd "S {}"
  puts $fd "E {}"
  set x 0 ; set i 1
  foreach c $cells {
    puts $fd "C {$c.sym} $x 0 0 0 {name=x$i}"
    incr x $pitch ; incr i
  }
  close $fd
}
# One extra symbol, ONLY for this sheet: a 60x40 body plus a text well outside it. It exists so
# S64 can see WHICH box the emitter uses. The H1b fixture symbols carry no text at all, so for
# them inst.x1..y2 (text-inflated) and inst.xx1..yy2 (body, what the blob is drawn from) are the
# same four numbers and a coverage assertion on them cannot tell the two apart. This one's boxes
# differ by more than a factor of two.
set fh [open [file join $dir tinf.sym] w]
puts $fh "v {xschem version=3.4.6 file_version=1.2}"
puts $fh "G {}"
puts $fh "K {type=subcircuit\ntemplate=\"name=x1\"}"
puts $fh "V {}"
puts $fh "S {}"
puts $fh "E {}"
puts $fh "L 4 -30 -20 30 -20 {}"
puts $fh "L 4 30 -20 30 20 {}"
puts $fh "L 4 -30 20 30 20 {}"
puts $fh "L 4 -30 -20 -30 20 {}"
puts $fh "T {WIDE_TEXT_OUTSIDE_THE_BODY} 100 0 0 0 0.4 0.4 {}"
close $fh
wsch [file join $dir tinf.sch] tinf

# good x2 (linked), ign (no page -> no link), notype (no type -> no link, 1333's guard),
# prim (primitive WITH a schematic -> linked, 1335), tinf (linked, and its text-inflated box is
# much bigger than its blob). All six under the 3-px floor.
wtopp [file join $dir tinytop.sch] {good good ign notype prim tinf} 100000

# One more symbol, for row S66 only: a type=subcircuit cell with NO graphics and NO text, so
# symbol_bbox() gives it inst.x1==x2 and y1==y2. It is the only shape that can make the emitter
# write a rect with no interior, and it is reachable ONLY through issue 1337's new call site --
# a zero-extent instance is always under the 3-px floor, so the pre-1337 binary returned before
# the emitter and there was never a link here to lose. Its .sch exists and is printable, so the
# H1b dest test passes and nothing but the degeneracy guard can stop the link.
set fh [open [file join $dir zero.sym] w]
puts $fh "v {xschem version=3.4.6 file_version=1.2}"
puts $fh "G {}"
puts $fh "K {type=subcircuit\ntemplate=\"name=x1\"}"
puts $fh "V {}"
puts $fh "S {}"
puts $fh "E {}"
close $fh
wsch [file join $dir zero.sch] zero
wtopp [file join $dir degtop.sch] {good zero} 100000

# ------------------------------------------- H3 fixtures (issues 1338, 1339) ---
# lnsym.sym: a 60x40 body PLUS the instance name. symbol_bbox() stores the body box (from
# sym->minx..maxy, which EXCLUDE symbol text -- actions.c:2528) into inst.xx1..yy2
# (select.c:730-740) and THEN unions every expanded symbol text into inst.x1..y2
# (select.c:742-778). So two instances of this ONE symbol, named `x1` and
# `xLONGLONGLONGLONGNAME`, have the SAME body box and very different text-inflated boxes --
# issue 1339 on a single sheet, with the symbol held constant.
set fh [open [file join $dir lnsym.sym] w]
puts $fh "v {xschem version=3.4.6 file_version=1.2}"
puts $fh "G {}"
puts $fh "K {type=subcircuit\ntemplate=\"name=x1\"}"
puts $fh "V {}"
puts $fh "S {}"
puts $fh "E {}"
puts $fh "L 4 -30 -20 30 -20 {}"
puts $fh "L 4 30 -20 30 20 {}"
puts $fh "L 4 -30 20 30 20 {}"
puts $fh "L 4 -30 -20 -30 20 {}"
puts $fh "T {@name} -30 -34 0 0 0.4 0.4 {}"
close $fh
wsch [file join $dir lnsym.sch] lnsym
set fh [open [file join $dir lntop.sch] w]
puts $fh "v {xschem version=3.4.6 file_version=1.2}"
puts $fh "G {}"
puts $fh "K {}"
puts $fh "V {}"
puts $fh "S {}"
puts $fh "E {}"
puts $fh "C {lnsym.sym} 0 0 0 0 {name=x1}"
puts $fh "C {lnsym.sym} 600 0 0 0 {name=xLONGLONGLONGLONGNAME}"
close $fh

# tonly.sym: THE LANDMINE. type=subcircuit, a printable schematic, NO graphics and ONE text.
# Its BODY box is fully degenerate (xx1==xx2, yy1==yy2) while its text-inflated box is not, so
# under `ps_link_bbox body` a naive switch hands ps_link_pdfmark()'s degeneracy guard (row S66,
# issue 1337) a zero-area rect and the link DISAPPEARS -- a link lost by flipping a preference
# that is supposed to change only the hotspot SIZE. Row S74 is that case.
set fh [open [file join $dir tonly.sym] w]
puts $fh "v {xschem version=3.4.6 file_version=1.2}"
puts $fh "G {}"
puts $fh "K {type=subcircuit\ntemplate=\"name=x1\"}"
puts $fh "V {}"
puts $fh "S {}"
puts $fh "E {}"
puts $fh "T {@name} 0 0 0 0 0.4 0.4 {}"
close $fh
wsch [file join $dir tonly.sch] tonly
set fh [open [file join $dir tontop.sch] w]
puts $fh "v {xschem version=3.4.6 file_version=1.2}"
puts $fh "G {}"
puts $fh "K {}"
puts $fh "V {}"
puts $fh "S {}"
puts $fh "E {}"
puts $fh "C {tonly.sym} 0 0 0 0 {name=xTEXTONLYCELL}"
puts $fh "C {lnsym.sym} 600 0 0 0 {name=x1}"
close $fh

# vline.sym / hline.sym: THE LANDMINE'S OTHER HALF, and the one H3's first draft SHIPPED BROKEN.
# type=subcircuit, a printable schematic, graphics that collapse to ONE axis, plus a text. The
# body box is degenerate in exactly one axis (xx1==xx2 XOR yy1==yy2), so a switch guarded on
# "the body box has an EXTENT" (`bx1 != bx2 || by1 != by2`) FIRES, and the resulting rect has no
# interior: measured 0.000 x 29.217 pt for the vline and 43.825 x 0.000 pt for the hline. The
# fully-degenerate guard in ps_link_pdfmark() (row S66) does not catch it, because that one is
# deliberately AND. The annotation is still EMITTED, so a link-count or LINKS-LOST control reads
# clean while the link is dead in every viewer. The guard must therefore test for AREA, not
# extent. Row S74b. Refuted by item H3's adversary before the item was committed.
set fh [open [file join $dir vline.sym] w]
puts $fh "v {xschem version=3.4.6 file_version=1.2}"
puts $fh "G {}"
puts $fh "K {type=subcircuit\ntemplate=\"name=x1\"}"
puts $fh "V {}"
puts $fh "S {}"
puts $fh "E {}"
puts $fh "L 4 0 -20 0 20 {}"
puts $fh "T {@name} 0 -34 0 0 0.3 0.3 {}"
close $fh
set fh [open [file join $dir hline.sym] w]
puts $fh "v {xschem version=3.4.6 file_version=1.2}"
puts $fh "G {}"
puts $fh "K {type=subcircuit\ntemplate=\"name=x1\"}"
puts $fh "V {}"
puts $fh "S {}"
puts $fh "E {}"
puts $fh "L 4 -30 0 30 0 {}"
puts $fh "T {@name} 0 -34 0 0 0.3 0.3 {}"
close $fh
wsch [file join $dir vline.sch] vline
wsch [file join $dir hline.sch] hline
set fh [open [file join $dir axtop.sch] w]
puts $fh "v {xschem version=3.4.6 file_version=1.2}"
puts $fh "G {}"
puts $fh "K {}"
puts $fh "V {}"
puts $fh "S {}"
puts $fh "E {}"
puts $fh "C {vline.sym} 0 0 0 0 {name=x1}"
puts $fh "C {hline.sym} 400 0 0 0 {name=x2}"
puts $fh "C {lnsym.sym} 800 0 0 0 {name=x3}"
close $fh

# ------------------------------------------------------------ PDF readers ---
proc pdf_read {f} {
  if {![file exists $f]} { return "" }
  set fd [open $f rb] ; set d [read $fd] ; close $fd ; return $d
}
## ITEM H6 -- EVERY PDF READER BELOW ANSWERS ABOUT THE SYMBOL LINKS ONLY, and it does so by
## parsing whole annotation OBJECTS rather than by grepping the file for a key. H6 puts a
## navigation strip on every page (a Back button and the page's parent references), so from
## this item on a PDF written by a hierarchical export contains two kinds of /Subtype /Link
## annotation and a flat `/Rect` grep no longer means "the symbol hotspots".
##
## The two kinds are told apart by `/F 4`, which item H6 writes on the strip's annotations and
## on nothing else. `/F` is the PDF annotation Flags entry and 4 is the Print bit: it is INERT
## here (the strip's ink lives in the page content stream, so it prints either way), and it is
## written so the two kinds are SELF-IDENTIFYING at the PDF level. That is what stops row N6's
## non-overlap proof from being circular -- partitioning the annotations by their y band and
## then asserting they do not overlap in y would be assuming the conclusion.
##
## Anchored on `>>endobj` rather than on `/Subtype` being the last key, and row N0 checks the
## parse against a raw count of the subtype literal, because a reader that silently returns
## fewer annotations than the file has reads exactly like a pass. ⚠ THE LEADING
## `[[:space:]]*?` IS LOAD-BEARING AND IS NOT COSMETIC: Tcl's ARE takes the greediness of the
## WHOLE branch from its FIRST quantified atom (re_syntax(n), "Matching"), so the same pattern
## written `<</Type\s*/Annot(.*?)>>` is GREEDY and swallows all fourteen greycnt annotations
## into one match. Measured: 1 annotation parsed where the file has 14, and every DD-3 row
## then reds on a correct binary.
proc pdf_annots {d} {
  set r {}
  foreach {m body} [regexp -all -inline \
      {<</Type[[:space:]]*?/Annot(.*?)>>[[:space:]]*?endobj} $d] {
    set rect "" ; set bord "" ; set cc "" ; set dest "" ; set nav 0 ; set gb 0
    regexp {/Rect\s*\[([^\]]*)\]} $body . rect
    regexp {/Border\s*\[([^\]]*)\]} $body . bord
    regexp {/C\s*\[([^\]]*)\]} $body . cc
    regexp {/Dest\s*\(([^)]*)\)} $body . dest
    if {[regexp {/F\s+4} $body]} { set nav 1 }
    if {[regexp {/S\s*/Named\s*/N\s*/GoBack} $body]} { set gb 1 }
    lappend r [list [string trim $rect] [string trim $bord] [string trim $cc] $dest $nav $gb]
  }
  return $r
}
## the H6 strip's annotations, and only those
proc pdf_nav_annots {d} {
  set r {} ; foreach a [pdf_annots $d] { if {[lindex $a 4]} { lappend r $a } } ; return $r
}
## names an annotation points at:  /Dest(good.sch).  SYMBOL links only.
proc pdf_link_dests {d} {
  set r {}
  foreach a [pdf_annots $d] {
    if {![lindex $a 4] && [lindex $a 3] ne ""} { lappend r [lindex $a 3] }
  }
  return $r
}
## names the document actually defines: the /Dests name tree leaves
proc pdf_dest_names {d} {
  set r {}
  foreach {m body} [regexp -all -inline {/Names\s*\[([^\]]*)\]} $d] {
    foreach {mm n} [regexp -all -inline {\(([^)]*)\)\s+[0-9]+\s+[0-9]+\s+R} $body] { lappend r $n }
  }
  return $r
}
proc pdf_rects {d} {
  set r {} ; foreach a [pdf_annots $d] { if {![lindex $a 4]} { lappend r [lindex $a 0] } } ; return $r
}

# --- PostScript readers. THE BIG SHEETS MUST BE READ AS .ps, NOT .pdf: ps2pdf aborts with
# `Error: /limitcheck` on 0_examples_top, loading, bus_keeper, poweramp_lcc and LCC_instances,
# truncating a 99-page export to one page and orphaning every link, while the PostScript is
# correct. A link/page assertion made on the PDF for those files fences the distiller, not
# xschem. The small fixtures above keep their PDF reading, which is the stronger check.
proc ps_read {f} { if {![file exists $f]} { return "" } ; set fd [open $f r] ; set d [read $fd] ; close $fd ; return $d }
## ITEM H6 -- the page navigation strip src/psprint.c writes above the drawing area of every
## page of a hierarchical export, fenced by two PostScript comments. Everything a pre-H6 reader
## in this file is about lives OUTSIDE it, so each of them strips the block first and keeps the
## meaning it had. A marker rather than a geometric test on purpose: the block's own rows must
## be able to prove where the strip sits without the readers having assumed it.
proc ps_strip_nav {d} {
  set out "" ; set in 0
  foreach line [split $d "\n"] {
    if {[string match "% xschem hier nav begin*" $line]} { set in 1 ; continue }
    if {[string match "% xschem hier nav end*" $line]}   { set in 0 ; continue }
    if {!$in} { append out $line "\n" }
  }
  return $out
}
## Per page, in page order: {page-dest back-button-count parent-dests nav-rects}. Reads the
## strip and nothing else; a page with no strip at all is absent from the result.
proc ps_nav_map {d} {
  set res {} ; set cur "" ; set nb 0 ; set pl {} ; set nr {} ; set have 0
  foreach line [split $d "\n"] {
    if {[regexp {^\[ /Dest /(\S+) /DEST pdfmark} $line . p]} {
      if {$have} { lappend res [list $cur $nb $pl $nr] }
      set cur $p ; set nb 0 ; set pl {} ; set nr {} ; set have 1 ; continue
    }
    if {[regexp {^\[ /Rect \[ (\S+) (\S+) (\S+) (\S+) \].*/F 4 } $line . a b c e]} {
      lappend nr [list $a $b $c $e]
      if {[string match "*GoBack*" $line]} {
        incr nb
      } elseif {[regexp {/Dest /(\S+) /Subtype /Link} $line . t]} {
        lappend pl $t
      }
    }
  }
  if {$have} { lappend res [list $cur $nb $pl $nr] }
  return $res
}
## the text of the nav strip(s) on the page whose /Dest is `page`
proc ps_nav_blocks_of {d page} {
  set out {} ; set cur "" ; set innav 0 ; set buf ""
  foreach line [split $d "\n"] {
    if {[regexp {^\[ /Dest /(\S+) /DEST pdfmark} $line . p]} { set cur $p ; continue }
    if {[string match "% xschem hier nav begin*" $line]} { set innav 1 ; set buf "" ; continue }
    if {[string match "% xschem hier nav end*" $line]} {
      set innav 0 ; if {$cur eq $page} { lappend out $buf } ; continue
    }
    if {$innav} { append buf $line "\n" }
  }
  return $out
}
## the parent map the strip actually claims: dict page -> sorted parent dests
proc ps_nav_parents {d} {
  set m [dict create]
  foreach e [ps_nav_map $d] { dict set m [lindex $e 0] [lsort [lindex $e 2]] }
  return $m
}
## the same, in EMISSION order. Row N22 needs it: ps_nav_parents sorts, so a map comparison
## cannot see an unsorted emission, and an unsorted one is a real defect -- hash order decides
## which parent a reader sees first and it is not stable across cells.
proc ps_nav_parents_raw {d} {
  set m [dict create]
  foreach e [ps_nav_map $d] { dict set m [lindex $e 0] [lindex $e 2] }
  return $m
}
proc ps_link_dests {d} {
  set r {}
  foreach {m n} [regexp -all -inline {/Dest /(\S+) /Subtype /Link} [ps_strip_nav $d]] { lappend r $n }
  return $r
}
proc ps_page_dests {d} {
  set r {}
  foreach {m n} [regexp -all -inline {/Dest /(\S+) /DEST} $d] { lappend r $n }
  return $r
}
# The four raw PostScript-user-space numbers of every /Link rect, in emission order. Only row
# S66 uses this: it asks whether a rect is DEGENERATE (no interior), which is a property the
# page CTM preserves exactly -- an affine map sends equal coordinates to equal coordinates --
# so it is the one geometric question DD-5 does not force onto the distilled PDF.
proc ps_link_rects {d} {
  set r {}
  foreach {m a b c e} [regexp -all -inline \
      {/Rect \[ (-?[0-9.e+-]+) (-?[0-9.e+-]+) (-?[0-9.e+-]+) (-?[0-9.e+-]+) \][^\n]*/Subtype /Link} \
      [ps_strip_nav $d]] {
    lappend r [list $a $b $c $e]
  }
  return $r
}
proc ps_dead {d} {
  set pages [ps_page_dests $d] ; set out {}
  foreach l [ps_link_dests $d] { if {[lsearch -exact $pages $l] < 0} { lappend out $l } }
  return [lsort -unique $out]
}

# ---------------------------------------------------------- spawned runner ---
# Runs a child xschem and reports (rc, signalled). Run FROM the scratch dir: when a 1333 row is
# RED the child dies mid-print and ps_draw()'s trailer drops a stray `plot.pdf` in the cwd —
# which, run from the audit, is the repo root. A red row must not litter the working tree
# (AUDIT_STRICT_SCRATCH / TREE).
proc spawn_export {dir script} {
  set out ""
  set rc 0
  set here [pwd]
  cd $dir
  if {[catch {exec [info nameofexecutable] --nogui --pipe -q --script $script 2>@1} out]} { set rc 1 }
  cd $here
  return [list $rc [regexp {FATAL: signal} $out] $out]
}

# ============================================================ 1333: the crash ==
# S1 — the constructed case: a symbol with K {} and no type= anywhere.
set child [file join $dir crash.tcl]
set cpdf  [file join $dir crash.pdf]
set fd [open $child w]
puts $fd "if {!\[info exists XSCHEM_LIBRARY_PATH\]} { set XSCHEM_LIBRARY_PATH {} }"
puts $fd "set XSCHEM_LIBRARY_PATH \"$dir:\$XSCHEM_LIBRARY_PATH\""
puts $fd "set noprint_libs {{np\\.sym}}"
puts $fd "xschem load [file join $dir h1notype.sch]"
puts $fd "xschem hier_psprint $cpdf"
puts $fd "puts CHILD_DONE"
puts $fd "flush stdout"
puts $fd "exit 0"
close $fd
lassign [spawn_export $dir $child] crash_rc signalled crash_out
check "S1 a symbol with NO type does not crash hierarchical export (1333)" \
  [expr {$crash_rc == 0 && !$signalled}] \
  "(rc=$crash_rc signal=[expr {$signalled ? 1 : 0}])"
set cd [pdf_read $cpdf]
check "S2 that export produced a PDF" [expr {[string length $cd] > 500}] \
  "(bytes=[string length $cd])"
set cdests [pdf_link_dests $cd]
check "S3 the untyped cell is not linked, and the sheet's normal subcircuit still is (not hollow)" \
  [expr {[lsearch -exact $cdests notype.sch] < 0 && [lsearch -exact $cdests good.sch] >= 0}] \
  "(dests={$cdests})"

# S1b — THE SHIPPED CASE. xschem_library/devices/bindkeys_cheatsheet.sym has K {} with no type=,
# intuitive_interface_cheatsheet.sch instantiates it, and 0_examples_top.sch instantiates that.
# Measured on the pre-change binary:
#     EMERGENCY SAVE DIR: /tmp/xschem_emergencysave_intuitive_interface_cheatsheet_ffgebeabfb
#     FATAL: signal 11
#     while editing: intuitive_interface_cheatsheet
# This row is the reason 1333 is worth a commit on its own: a user exporting a shipped example
# loses the whole document, not one link.
set shipped [file join $exdir 0_examples_top.sch]
if {[file exists $shipped]} {
  set schild [file join $dir shipped.tcl]
  set sps    [file join $dir shipped.ps]
  set fd [open $schild w]
  puts $fd "xschem load {$shipped}"
  puts $fd "xschem hier_psprint {$sps}"
  puts $fd "puts SHIPPED_DONE"
  puts $fd "flush stdout"
  puts $fd "exit 0"
  close $fd
  lassign [spawn_export $dir $schild] srca ssig sout
  check "S1b the SHIPPED xschem_library/examples/0_examples_top.sch exports without a signal (1333)" \
    [expr {$srca == 0 && !$ssig}] "(rc=$srca signal=[expr {$ssig ? 1 : 0}])"
  check "S1c ... and that export really produced its pages (not a hollow pass)" \
    [expr {[file exists $sps] && [file size $sps] > 100000}] \
    "(exists=[file exists $sps] bytes=[expr {[file exists $sps] ? [file size $sps] : 0}])"
} else {
  check "S1b shipped 0_examples_top.sch present" 0 "(missing $shipped)"
  check "S1c shipped 0_examples_top.sch present" 0 "(missing $shipped)"
}

# ============================================ 1335: the primitive, and what H1a MUST NOT do ==
if {![info exists XSCHEM_LIBRARY_PATH]} { set XSCHEM_LIBRARY_PATH {} }
set XSCHEM_LIBRARY_PATH "$dir:$XSCHEM_LIBRARY_PATH"
set noprint_libs {{np\.sym}}

set bpdf [file join $dir top.pdf]
xschem load [file join $dir top.sch]
xschem hier_psprint $bpdf
set bd [pdf_read $bpdf]
set links [pdf_link_dests $bd]
set pages [pdf_dest_names $bd]

check "S9 a type=primitive cell WITH a schematic IS linked (1335)" \
  [expr {[lsearch -exact $links prim.sch] >= 0}] "(links={$links})"
check "S9b ... and that link resolves: prim.sch is a page the document defines (1335 was a page\
 nothing linked to)" \
  [expr {[lsearch -exact $pages prim.sch] >= 0 && [lsearch -exact $links prim.sch] >= 0}] \
  "(links={$links} pages={$pages})"

# S9c IS WHY THE PRIMITIVE ARM CARRIES A FILE TEST THAT THE SUBCIRCUIT ARM DOES NOT.
# Most type=primitive symbols have NO schematic — they are defined by their `format=` string —
# and hier_psprint() gives them no page. Extending the type test alone therefore manufactures a
# fresh dead link on every one of them, which is issue 1334, the defect this batch exists to
# CLOSE. Measured on the shipped tree with the naive one-line extension: five new dead links on
# three shipped sheets — inv_bsource / an2 / nr2-1 / or2 on flop.sch and sr_flop.sch, and lm324
# on test_lm324.sch, none of which has a .sch anywhere in the repo. The gate reads no symbol
# attribute, only whether the file the /Dest is about to name exists, so it cannot repeat the
# base-symbol / minted-symbol confusion that refuted the two attempts before this one (DD-6).
check "S9c a type=primitive cell with NO schematic is NOT linked — extending the type test\
 alone would manufacture a dead link (1334) while fixing 1335" \
  [expr {[lsearch -exact $links primns.sch] < 0 && [lsearch -exact $pages primns.sch] < 0}] \
  "(links={$links} pages={$pages})"

# ==================================================== 1334 (H1b): the dead links ==
# `np` (noprint_libs), `ign` (default_schematic=ignore) and `miss` (no .sch) get NO page, so
# their links were dead clicks. H1b suppresses exactly those three and NOTHING else. Asserting
# the set EXACTLY (not a subset) catches both directions: an over-suppression that eats a live
# link, and a widened type test that links something new.
# Measured on the pre-H1b binary this row read {good.sch ign.sch miss.sch np.sch prim.sch}.
set want [lsort {good.sch prim.sch}]
check "S40 (1334) the three page-less cells lose their links and the two paged cells keep\
 theirs" [expr {[lsort $links] eq $want}] "(got={[lsort $links]} want={$want})"

# S41 IS H1b'S OWN FIRST CONTROL AND IT IS NOT OPTIONAL. The fix works by running the SAME
# hierarchy walk once more in a collect-only mode. That walk is a READ: if the page set moves,
# hier_psprint() has been broken by its own pre-pass, and every other row here would still pass.
set pwant [lsort {top.sch good.sch prim.sch}]
check "S41 (1334) THE PAGE SET DID NOT MOVE: the collect pass is a read" \
  [expr {[lsort $pages] eq $pwant}] "(got={[lsort $pages]} want={$pwant})"

set fdead {}
foreach l $links { if {[lsearch -exact $pages $l] < 0} { lappend fdead $l } }
check "S42 (1334) every surviving link on the fixture resolves to a page the document defines" \
  [expr {[llength $fdead] == 0}] "(dead={$fdead} pages={$pages})"

# --------------- the instance-level `schematic=` routes, in BOTH directions ---
# S43 and S44 are the pair that refuted H1 and H1-2. A predicate reading the BASE symbol gets
# S43 wrong in one direction (it deletes a LIVE link) and S44 wrong in the other (it leaves a
# DEAD one). Asking whether the document contains a page of that name gets both right without
# knowing why.
set noprint_libs {{np\.sym} {nbase\.sym} {npx\.sym}}

proc export_links_pages {dir sch tag} {
  set out [file join $dir $tag.pdf]
  xschem load $sch
  xschem hier_psprint $out
  set d [pdf_read $out]
  return [list [lsort [pdf_link_dests $d]] [lsort [pdf_dest_names $d]] $d]
}

lassign [export_links_pages $dir [file join $dir topN.sch] n] nlinks npages
check "S43 (1334) noprint_libs matches the BASE symbol but the instance overrides to a\
 PRINTABLE cell: the link SURVIVES (H1 and H1-2 deleted it)" \
  [expr {[lsearch -exact $nlinks good2.sch] >= 0 && [lsearch -exact $npages good2.sch] >= 0}] \
  "(links={$nlinks} pages={$npages})"

lassign [export_links_pages $dir [file join $dir topO.sch] o] olinks opages
check "S44 (1334) printable base, override target excluded by noprint_libs: THAT link is\
 suppressed and the un-overridden sibling's is not (H1-2 left this one dead)" \
  [expr {[lsearch -exact $olinks npx.sch] < 0 && [lsearch -exact $olinks obase.sch] >= 0 \
         && [lsearch -exact $opages obase.sch] >= 0}] \
  "(links={$olinks} pages={$opages})"

# --------------------------------- the two-library homonym, in both directions ---
lassign [export_links_pages $dir [file join $dir topH1.sch] h1] h1links h1pages
check "S45 (1334) homonym, only the default_schematic=ignore twin instantiated: nothing pages\
 inv.sch, so its link goes and good.sch's stays" \
  [expr {[lsearch -exact $h1links inv.sch] < 0 && [lsearch -exact $h1links good.sch] >= 0}] \
  "(links={$h1links} pages={$h1pages})"

# S46 IS THE ROW THAT SAYS THE LOOKUP CANNOT OVER-SUPPRESS. A PDF /Dest is a flat basename, so
# once ANY library's `inv` has a page, a click on either instance really does navigate — and
# both links must stay, including the one whose own cell carries default_schematic=ignore.
# A predicate that reasons about the symbol deletes that second link; this one cannot.
lassign [export_links_pages $dir [file join $dir topH3.sch] h3] h3links h3pages
check "S46 (1334) homonym with the printable twin paged: BOTH inv.sch links survive — the\
 lookup is on the flat /Dest name and cannot suppress a link that navigates" \
  [expr {[llength [lsearch -all -exact $h3links inv.sch]] == 2 \
         && [lsearch -exact $h3pages inv.sch] >= 0}] \
  "(links={$h3links} pages={$h3pages})"
set noprint_libs {}

# ================================ 1334 on SHIPPED and REAL designs, read off the .ps ==
# Helper: run a child export with an explicit library path and return its PostScript.
proc child_ps {dir tag body} {
  set t  [file join $dir $tag.tcl]
  set ps [file join $dir $tag.ps]
  catch {file delete $ps}
  set fd [open $t w]
  puts $fd $body
  puts $fd "xschem hier_psprint {$ps}"
  puts $fd "puts CHILD_DONE" ; puts $fd "flush stdout" ; puts $fd "exit 0"
  close $fd
  lassign [spawn_export $dir $t] rc sig out
  return [list $rc $sig [ps_read $ps] $out]
}

# S47 IS THE FIXTURE THAT REFUTED BOTH PREVIOUS ATTEMPTS, AND IT IS A SHIPPED FILE.
# xschem_library/examples/tb_test_evaluated_param.sch EXISTS to demonstrate a base symbol with
# default_schematic=ignore plus a per-instance `schematic=` override on each of its two
# instances. Give it the two view files it names and BOTH pages print and BOTH links must live.
# H1 and H1-2 took it from 2 live links to 0 while still printing both pages — which is issue
# 1335 (a page nothing links to) manufactured while claiming to fix 1334.
set evtb [file join $exdir tb_test_evaluated_param.sch]
set evsrc [file join $exdir test_evaluated_param.sch]
if {[file exists $evtb] && [file exists $evsrc]} {
  # The two views go in a SUBDIRECTORY, not in $dir: spawn_export runs the child with its cwd
  # set to $dir, and abs_sym_path() searches the cwd, so a copy alongside the fixtures would
  # still be found by S48 — which needs them absent — and S48 would silently pass for the
  # wrong reason. (Measured: it failed for exactly that reason first.)
  set evdir [file join $dir evp] ; file mkdir $evdir
  file copy -force $evsrc [file join $evdir test_evaluated_param1.sch]
  file copy -force $evsrc [file join $evdir test_evaluated_param2.sch]
  set pre "set ::XSCHEM_LIBRARY_PATH \"$evdir:$exdir:[file join $repo xschem_library devices]\"\nset_paths\nset ::noprint_libs {}\nxschem load {$evtb}"
  lassign [child_ps $dir evp $pre] erc esig ed
  set el [lsort [ps_link_dests $ed]] ; set ep [lsort [ps_page_dests $ed]]
  check "S47 (1334) SHIPPED tb_test_evaluated_param.sch with its two views on the path: BOTH\
 per-instance override links SURVIVE (H1 and H1-2 deleted them)" \
    [expr {$erc == 0 && !$esig && $el eq [lsort {test_evaluated_param1.sch test_evaluated_param2.sch}] \
           && [lsearch -exact $ep test_evaluated_param1.sch] >= 0 \
           && [lsearch -exact $ep test_evaluated_param2.sch] >= 0}] \
    "(rc=$erc links={$el} pages={$ep})"

  # S48: the SAME shipped sheet with the views NOT on the path. get_additional_symbols() then
  # points the minted symbol at the base cell's own .sch, so the pages are {tb…, test_evaluated_param}
  # and the two links name files that are not there — dead. They go, and THE PAGE SET DOES NOT MOVE.
  set pre2 "set ::XSCHEM_LIBRARY_PATH \"$exdir:[file join $repo xschem_library devices]\"\nset_paths\nset ::noprint_libs {}\nxschem load {$evtb}"
  lassign [child_ps $dir evp2 $pre2] e2rc e2sig e2d
  set e2l [ps_link_dests $e2d] ; set e2p [lsort [ps_page_dests $e2d]]
  check "S48 (1334) same shipped sheet WITHOUT those views: both links are dead and go, and the\
 page set is unchanged at 2" \
    [expr {$e2rc == 0 && [llength $e2l] == 0 \
           && $e2p eq [lsort {tb_test_evaluated_param.sch test_evaluated_param.sch}]}] \
    "(rc=$e2rc links={$e2l} pages={$e2p})"
} else {
  check "S47 shipped tb_test_evaluated_param.sch present" 0 "(missing)"
  check "S48 shipped tb_test_evaluated_param.sch present" 0 "(missing)"
}

# S49 — ROUTE 5, THE GENERATORS (issue 1340). xschem_library/generators/test_symbolgen.sch has
# FIVE links of which FOUR resolve through is_generator(): schematicgen_tcl_inv and
# schematicgen_tcl_buf are real pages. Only x4's `schematic="schematicgen.tcl(buf,4)"` names
# something hier_psprint() never pages. A blanket "refuse generator links" rule would delete the
# four that work — which is exactly why 1340 was FILED rather than closed. This row asserts the
# discrimination, not the refusal.
set gensch [file join $repo xschem_library generators test_symbolgen.sch]
if {[file exists $gensch]} {
  lassign [child_ps $dir gen "set ::noprint_libs {}\nxschem load {$gensch}"] grc gsig gdd
  set gl [ps_link_dests $gdd] ; set gp [ps_page_dests $gdd]
  check "S49 (1334/1340) generators: the four resolving generator links SURVIVE and only\
 schematicgen_tcl_buf_4 goes" \
    [expr {$grc == 0 && [llength $gl] == 4 && [llength [ps_dead $gdd]] == 0 \
           && [lsearch -exact $gl schematicgen_tcl_buf_4] < 0 \
           && [lsearch -exact $gl schematicgen_tcl_inv] >= 0 \
           && [lsearch -exact $gl schematicgen_tcl_buf] >= 0}] \
    "(rc=$grc links={$gl} pages={$gp} dead={[ps_dead $gdd]})"
} else {
  check "S49 xschem_library/generators/test_symbolgen.sch present" 0 "(missing)"
}

# S50 — THE SHIPPED 99-PAGE EXPORT, re-using the PostScript S1b already produced. It carried
# EIGHT dead annotations before H1b (comp3_file, comp3_pex, comp3_pex2, comp3_read.sch,
# ne555.sch, schematicgen_tcl_buf_4, test_evaluated_param1.sch, test_evaluated_param2.sch).
if {[info exists sps] && [file exists $sps]} {
  set shd [ps_read $sps]
  check "S50 (1334) the SHIPPED 99-page 0_examples_top export has 0 dead links, and still 99\
 pages and 300+ live ones" \
    [expr {[llength [ps_dead $shd]] == 0 && [llength [ps_page_dests $shd]] == 99 \
           && [llength [ps_link_dests $shd]] > 300}] \
    "(pages=[llength [ps_page_dests $shd]] links=[llength [ps_link_dests $shd]]\
 dead={[ps_dead $shd]})"
} else {
  check "S50 0_examples_top PostScript from S1b present" 0 "(missing)"
}

# S51 — A REAL sky130 OA HIERARCHY. The registry is MANDATORY: without those three lines
# cellview_path returns empty, the export is ONE page, and the run looks exactly like a descent
# bug (PLAN.md's CORRECTION box). The row asserts cellview_path resolved before it believes any
# number. Before H1b this export shipped 2 dead `passgate_lvtp` annotations, from
# bandgap/schematic/bandgap.sch:120,122 naming a cell that exists nowhere.
set oatb [file join $repo sky130A xschem_libs sky130_tests_ase tb_bandgap schematic tb_bandgap.sch]
set oadefs [file join $repo sky130A xschem_libs library.defs]
if {[file exists $oatb] && [file exists $oadefs]} {
  set opre "set ::XSCHEM_LIBRARY_DEFS {$oadefs}\nset ::library_registry_defs_only 1\nset ::XSCHEM_LIBRARY_PATH {}\nset ::noprint_libs {}\nputs \"CELLVIEW |\[cellview_path sky130_tests_ase/bandgap schematic\]|\"\nxschem load {$oatb}"
  lassign [child_ps $dir oa $opre] orc osig od oout
  regexp {CELLVIEW \|([^|]*)\|} $oout . cvpath
  if {![info exists cvpath]} { set cvpath "" }
  check "S51 (1334) sky130 OA hierarchy tb_bandgap, registry loaded: 8 pages, 24 links, 0 dead\
 (2 dead passgate_lvtp before)" \
    [expr {$orc == 0 && $cvpath ne "" && [llength [ps_page_dests $od]] == 8 \
           && [llength [ps_link_dests $od]] == 24 && [llength [ps_dead $od]] == 0}] \
    "(cellview_path=|$cvpath| pages=[llength [ps_page_dests $od]]\
 links=[llength [ps_link_dests $od]] dead={[ps_dead $od]})"
} else {
  check "S51 sky130 OA fixture present" 0 "(missing $oatb)"
}

# S52 — THE COLLECT PASS MUST NOT HIJACK `xschem list_hierarchy`. The pre-pass reuses
# hier_psprint()'s walk and had to switch the library filter to the PRINT one (noprint_libs).
# list_hierarchy is a menu-visible command and filters with nolist_libs; writing the filter
# unconditionally would silently re-filter that list. greycnt -> xnor with noprint_libs matching
# xnor: the PRINT drops xnor's page, the LIST still names it.
set noprint_libs {{xnor\.sym}}
xschem load $greycnt
set lh {}
foreach line [split [xschem list_hierarchy] "\n"] {
  set line [string trim $line]
  if {$line ne ""} { lappend lh [file tail [string trim [lindex $line 1] "{}"]] }
}
set lhps [file join $dir lh.ps]
xschem hier_psprint $lhps
set lhd [ps_read $lhps]
check "S52 (1334) the collect pass takes noprint_libs and `list_hierarchy` keeps nolist_libs:\
 the list still names xnor.sch while the export no longer pages or links it" \
  [expr {[lsearch -exact $lh xnor.sch] >= 0 \
         && [lsearch -exact [ps_page_dests $lhd] xnor.sch] < 0 \
         && [lsearch -exact [ps_link_dests $lhd] xnor.sch] < 0}] \
  "(list={[lsort $lh]} pages={[ps_page_dests $lhd]} links={[lsort -unique [ps_link_dests $lhd]]})"
set noprint_libs {}

# ====================================================== DD-3 regression control ==
# greycnt.sch -> xnor.sch is measured correct: 14 link rects, all congruent at
# 61.487 x 35.135 pt, MediaBox [0 0 842 595]. Nothing in this batch may move those.
set noprint_libs {}
set gpdf [file join $dir grey.pdf]
xschem load $greycnt
xschem hier_psprint $gpdf
set gd [pdf_read $gpdf]
set grects [pdf_rects $gd]
check "S12 DD-3: greycnt still exports 14 link rects" [expr {[llength $grects] == 14}] \
  "(n=[llength $grects])"

# Congruence is the display-independent half of DD-3. THE ABSOLUTE SIZE IS ASSERTED IN EVERY
# ARM -- an earlier revision of this comment was wrong to skip it on a display, on the strength
# of a 56.695 x 32.397 figure that has never reproduced -- but THE ABSOLUTE IS NOT ONE NUMBER.
#
# ⚠ CORRECTED AGAIN 2026-09-09 (item H3). THE ABSOLUTE IS NOW MEASURED IN A SPAWNED `--nogui`
# CHILD, not in this interpreter, and that is a determinism fix rather than a loosening.
#
# What was found: this row was RED on `:99` -- on the 7f8d72a8 binary as well as on H3's,
# identical numbers, so not this batch's doing. The parent measured 61.494 x 35.140
# ({385.254 281.245 446.748 316.385}) where headless gives 61.487 x 35.135
# ({385.366 281.367 446.853 316.502}), a 0.007 pt gap that the 0.005 tolerance rejects. Then,
# two full audits and three throwaway Xvfb servers later, the SAME command on the SAME display
# went back to 61.487 and stayed there for six consecutive runs. So the display arm's value is
# not a second constant to assert -- it is BISTABLE within one session, and an absolute
# asserted there is a latent flake that happens to be green today.
#
# The mechanism is DD-3's own amendment: create_ps() takes its bounding box from
# xctx->areax1..areay2 (psprint.c), the canvas, which exists only when Tk does and whose size
# on a display is whatever the window manager hands the process. It is NOT a screen-size
# effect -- Xvfb at 1920x1080, 1280x1024, 800x600 and the dev display all give identical raw
# PostScript -- and in PS user space the two arms are 11% apart (75.923 vs 84.274), nearly all
# of which the page CTM divides back out. Filed as issue **1345**; same family as 1341 (the page
# scale is not a property of the design) on a different axis, and neither is this batch's to fix.
#
# CLAUDE.md's rule for a bug only one environment reproduces: force it deterministically rather
# than hope the environment supplies it. So the constant is read from a child that has no
# canvas at all. The proof that this is the right knob is in this suite's own transcript: in the
# run where the parent measured 61.494 on `:99`, row S71's spawned child measured 61.487 in the
# same process tree, the same second. The display-independent halves of DD-3 -- 14 rects (S12),
# mutual congruence (S13), MediaBox (S14), all resolving (S15) -- stay in-process and unchanged.
# What 1341 moves is a SECOND walk in the same process: every measurement here is a first walk.
set w0 "" ; set h0 "" ; set bad 0 ; set seen {}
foreach r $grects {
  lassign $r x1 y1 x2 y2
  set w [expr {abs($x2 - $x1)}] ; set h [expr {abs($y2 - $y1)}]
  if {$w0 eq ""} { set w0 $w ; set h0 $h }
  lappend seen "[format %.3f $w]x[format %.3f $h]"
  if {abs($w - $w0) > 0.005 || abs($h - $h0) > 0.005} { incr bad }
}
check "S13 DD-3: all 14 rects congruent with one another (0.005 pt)" \
  [expr {$bad == 0 && [llength $grects] == 14}] "(off=$bad sizes={[lsort -unique $seen]})"

set arm [expr {[catch {winfo exists .}] ? "--nogui" : "display [lindex [split $env(DISPLAY) .] 0]"}]
## The spawned first-walk measurement S13b asserts on. One constant, every arm, no canvas.
set s13child [file join $dir dd3.tcl]
set s13pdf   [file join $dir dd3.pdf]
set s13ps    [file join $dir dd3.ps]
catch {file delete $s13ps $s13pdf}
set fd [open $s13child w]
puts $fd "set noprint_libs {}"
puts $fd "xschem load {$greycnt}"
puts $fd "xschem hier_psprint {$s13ps}"
puts $fd "puts DD3_DONE"
puts $fd "flush stdout"
puts $fd "exit 0"
close $fd
lassign [spawn_export $dir $s13child] s13rc s13sig s13out
catch {exec ps2pdf $s13ps $s13pdf}
set sw0 "" ; set sh0 "" ; set s13n 0
foreach r [pdf_rects [pdf_read $s13pdf]] {
  incr s13n
  if {$sw0 eq ""} { set sw0 [expr {abs([lindex $r 2] - [lindex $r 0])}]
                    set sh0 [expr {abs([lindex $r 3] - [lindex $r 1])}] }
}
if {$sw0 eq ""} {
  # Nothing to measure: S12 has already redded. Report rather than die — an export that
  # emits no annotation at all used to take this script down with `can't use empty string
  # as operand of "-"`, which reads like a harness bug rather than the failure it is.
  check "S13b DD-3: and at the measured 61.487 x 35.135 pt, read from a spawned --nogui child so\
 the constant is the SAME in every arm (issue 1345)" 0 \
    "(the child produced no link rects -- rc=$s13rc sig=$s13sig; parent arm=$arm)"
} else {
  check "S13b DD-3: and at the measured 61.487 x 35.135 pt, read from a spawned --nogui child so\
 the constant is the SAME in every arm (issue 1345)" \
    [expr {$s13n == 14 && abs($sw0 - 61.487) <= 0.005 && abs($sh0 - 35.135) <= 0.005}] \
    "(child n=$s13n [format %.3f $sw0] x [format %.3f $sh0]; this interpreter measured\
 [format %.3f $w0] x [format %.3f $h0] in arm=$arm -- see 1345 if those differ)"
}

set mb [regexp -all -inline {/MediaBox\s*\[([^\]]*)\]} $gd]
check "S14 DD-3: MediaBox is 842 x 595" \
  [expr {[llength $mb] > 0 && [string match "0 0 842 595*" [lindex $mb 1]]}] \
  "(mediabox={[lindex $mb 1]})"
set gdead {}
set gpages [pdf_dest_names $gd]
foreach l [pdf_link_dests $gd] { if {[lsearch -exact $gpages $l] < 0} { lappend gdead $l } }
check "S15 DD-3: all 14 greycnt links resolve" [expr {[llength $gdead] == 0}] \
  "(dead={[lsort -unique $gdead]} pages={$gpages})"

# ============================================ H2 -- 1336 and 1337, the geometry ==
# ⚠ A PostScript /Rect IS NOT A PDF /Rect. ps_draw_symbol() writes X_TO_PS()/Y_TO_PS() values,
# i.e. the flipped user space the PAGE CTM establishes -- `11.6197 583.38 translate` then
# `0.809859 -0.809859 scale`, emitted by create_ps() at psprint.c's page block. The distiller
# applies that CTM to the annotation, so raw PS y reaches 604.3 on a 595 pt page and that is
# CORRECT. Ruling DD-5: EVERY geometric assertion below is made on the PDF, after ps2pdf, never
# on the PostScript byte order. Ghostscript KEEPS an out-of-bounds or inverted annotation rather
# than dropping it (measured), so a geometry bug here has no error path and ships silently.

## returns {llx lly urx ury} normalised, plus a flag saying whether it already was
proc rect_normalised {r} {
  lassign $r x1 y1 x2 y2
  return [expr {$x1 < $x2 && $y1 < $y2}]
}

# S60 -- ISSUE 1336, on the DD-3 control itself. Measured on the pre-change binary, all 14:
#   /Rect [385.366 316.502 446.853 281.367]      <- 316.502 > 281.367
# PDF 32000-1 s12.5.2 defines /Rect as lower-left/upper-right; s7.9.5 only tells CONSUMERS to
# normalise, which is the sole reason Acrobat, poppler and pdf.js work on this file today. The
# document is out of spec and depends on reader leniency.
set unnorm {}
foreach r $grects { if {![rect_normalised $r]} { lappend unnorm $r } }
check "S60 (1336) every greycnt /Rect in the PDF is normalised: llx<urx AND lly<ury" \
  [expr {[llength $grects] == 14 && [llength $unnorm] == 0}] \
  "(n=[llength $grects] inverted=[llength $unnorm] first={[lindex $grects 0]})"

# S61 -- the same question asked of EVERY PDF this suite has written, not just greycnt: the
# fixtures, the 1333 crash export and the two instance-override sheets. One emitter, so one
# answer, but a row that only ever looked at greycnt would not have seen a rect whose x pair
# came out reversed by a rotated or flipped instance.
set allrects 0 ; set allbad {} ; set seenpdf {}
foreach f [glob -nocomplain [file join $dir *.pdf]] {
  set rr [pdf_rects [pdf_read $f]]
  if {[llength $rr] == 0} continue
  lappend seenpdf "[file tail $f]:[llength $rr]"
  foreach r $rr {
    incr allrects
    if {![rect_normalised $r]} { lappend allbad "[file tail $f] {$r}" }
  }
}
check "S61 (1336) and every /Rect in every PDF this suite wrote is normalised" \
  [expr {$allrects >= 14 && [llength $allbad] == 0}] \
  "(rects=$allrects inverted=[llength $allbad] files={[lsort $seenpdf]} bad={[lrange $allbad 0 2]})"

# ------------------------------------------------------------------------------
# S62 -- DD-3's "same VALUES, only reordered", measured rather than claimed, and it is the row
# that names the CTM. Export greycnt ONCE to PostScript and distil THAT SAME FILE ourselves, so
# the .ps and the .pdf are one document (issue 1341: a second in-process walk rescales the page,
# so two separate exports would not correspond). Then for each link:
#     PDF /Rect  ==  sort( CTM applied to the four PostScript numbers )
# If that holds, the four numbers in the PDF are exactly the ones the emitter always computed --
# H2 reordered them and changed nothing else. It was RED before H2 because the pre-change order
# survived the CTM un-normalised.
set g2ps [file join $dir grey2.ps] ; set g2pdf [file join $dir grey2.pdf]
catch {file delete $g2ps $g2pdf}
xschem load $greycnt
xschem hier_psprint $g2ps
set g2s [ps_read $g2ps]
set distil_err ""
if {[catch {exec ps2pdf $g2ps $g2pdf} distil_err]} { set distil_err "ps2pdf: $distil_err" }
# page 1's CTM: the first `tx ty translate` / `sx sy scale` pair AFTER the first /DEST pdfmark
set ctm {}
set tail [string range $g2s [string first "/DEST pdfmark" $g2s] end]
if {[regexp {\n(-?[0-9.e+-]+) (-?[0-9.e+-]+) translate\n(-?[0-9.e+-]+) (-?[0-9.e+-]+) scale\n} \
     $tail . tx ty sx sy]} { set ctm [list $tx $ty $sx $sy] }
set psr {}
foreach {m v} [regexp -all -inline {/Rect \[ ([^\]]*)\] /Border} [ps_strip_nav $g2s]] { lappend psr $v }
set pdfr [pdf_rects [pdf_read $g2pdf]]
set mism 0 ; set shown ""
if {[llength $ctm] == 4 && [llength $psr] == [llength $pdfr] && [llength $psr] > 0} {
  lassign $ctm tx ty sx sy
  foreach a $psr b $pdfr {
    lassign $a ax1 ay1 ax2 ay2
    set xs [lsort -real [list [expr {$tx + $sx*$ax1}] [expr {$tx + $sx*$ax2}]]]
    set ys [lsort -real [list [expr {$ty + $sy*$ay1}] [expr {$ty + $sy*$ay2}]]]
    set want [list [lindex $xs 0] [lindex $ys 0] [lindex $xs 1] [lindex $ys 1]]
    foreach w $want g $b { if {abs($w - $g) > 0.002} { incr mism } }
    if {$shown eq ""} { set shown "ps={$a} -> want={[lmap q $want {format %.3f $q}]} got={$b}" }
  }
} else { set mism -1 }
check "S62 (1336/DD-3) the PDF rect is the page CTM applied to the SAME four PostScript numbers,\
 sorted -- H2 reordered the emission and changed no value" \
  [expr {$mism == 0 && [llength $psr] == 14}] \
  "(ctm={$ctm} n=[llength $psr]/[llength $pdfr] mismatches=$mism $shown $distil_err)"

# ============================================================== 1337: the blobs ==
# S63 -- the defect. Every instance on tinytop.sch is under the 3-px floor, so on the
# pre-change binary ps_draw_symbol() drew five blobs and returned before the pdfmark block:
# 2 pages, 0 links. The blob HAS a bounding box; there is no reason it cannot carry the link.
# The row also asserts the OTHER three of the four tests the H1b call site performs still run on
# this path, in order: `notype` (no type= at all -- issue 1333's guard) and `ign`
# (default_schematic=ignore, so no page -- issue 1334's dest lookup) must NOT be linked, while
# `prim` (type=primitive WITH a schematic -- issue 1335) must be. A sub-3px branch that emitted
# a bare fprintf of its own would fail exactly here.
set tpps [file join $dir tinytop.ps] ; set tppdf [file join $dir tinytop.pdf]
catch {file delete $tpps $tppdf}
set noprint_libs {}
xschem load [file join $dir tinytop.sch]
xschem hier_psprint $tpps
set tps [ps_read $tpps]
set tlinks [lsort [ps_link_dests $tps]]
set tpages [lsort [ps_page_dests $tps]]
set twant [lsort {good.sch good.sch prim.sch tinf.sch}]
set tpwant [lsort {tinytop.sch good.sch prim.sch tinf.sch}]
check "S63 (1337) sub-3px instances get their links -- exactly {good good prim tinf}, the untyped and\
 the page-less ones still get none, and the PAGE SET does not move" \
  [expr {$tlinks eq $twant && $tpages eq $tpwant}] \
  "(links={$tlinks} want={$twant} pages={$tpages} want={$tpwant})"

# S64 -- and the rect is on the blob. ps_filledrect() draws the blob as `x y w h R` from the
# instance's BODY box (inst.xx1..yy2) while the link rect uses the emitter's one and only box,
# the text-inflated inst.x1..y2 -- which select.c:730-778 builds by storing the body box and
# THEN unioning every symbol text into it, so it strictly contains the blob. Asserted on the
# PDF (DD-5): the blob is mapped through the page CTM read out of the PostScript, the link rect
# is read from the distilled PDF, and each link's rect must be normalised, non-degenerate and
# contain the blob drawn immediately before it. Pairing is by position in the file: the small
# branch emits ps_filledrect() and then the pdfmark, with nothing between them.
set tpdf_err ""
if {[catch {exec ps2pdf $tpps $tppdf} tpdf_err]} { set tpdf_err "ps2pdf: $tpdf_err" }
set tctm {}
set ttail [string range $tps [string first "/DEST pdfmark" $tps] end]
if {[regexp {\n(-?[0-9.e+-]+) (-?[0-9.e+-]+) translate\n(-?[0-9.e+-]+) (-?[0-9.e+-]+) scale\n} \
     $ttail . ttx tty tsx tsy]} { set tctm [list $ttx $tty $tsx $tsy] }
# walk the PostScript in order, remembering the last blob before each annotation
set blobs {}
## ps_strip_nav: item H6 puts Link annotations OUTSIDE the page CTM too, and this scanner
## pairs each annotation with the last blob before it -- a nav annotation would pair with a
## stale blob from the page before. Measured: blobs 4 -> 10 without this.
foreach line [split [ps_strip_nav $tps] "\n"] {
  if {[regexp {^(-?[0-9.e+-]+) (-?[0-9.e+-]+) (-?[0-9.e+-]+) (-?[0-9.e+-]+) R$} $line . bx by bw bh]} {
    set lastblob [list $bx $by $bw $bh]
  } elseif {[string match "*/Subtype /Link*" $line] && [info exists lastblob]} {
    lappend blobs $lastblob
  }
}
set trects [pdf_rects [pdf_read $tppdf]]
# eps: the PostScript and the PDF both print with %g, i.e. 6 significant digits, so on
# coordinates of order 20 pt the two sides agree only to ~1e-4. 0.002 pt is two decades under
# the inflation S64b measures and two decades over the printing noise.
set eps 0.002
set nocover 0 ; set tshow "" ; set widest 0.0 ; set widestblob 0.0
if {[llength $tctm] == 4 && [llength $blobs] == [llength $trects] && [llength $trects] == 4} {
  lassign $tctm ttx tty tsx tsy
  foreach bl $blobs r $trects {
    lassign $bl bx by bw bh
    set bxs [lsort -real [list [expr {$ttx + $tsx*$bx}] [expr {$ttx + $tsx*($bx+$bw)}]]]
    set bys [lsort -real [list [expr {$tty + $tsy*$by}] [expr {$tty + $tsy*($by+$bh)}]]]
    lassign $r rx1 ry1 rx2 ry2
    if {!($rx1 < $rx2 && $ry1 < $ry2)} { incr nocover ; continue }
    if {$rx1 > [lindex $bxs 0] + $eps || $rx2 < [lindex $bxs 1] - $eps ||
        $ry1 > [lindex $bys 0] + $eps || $ry2 < [lindex $bys 1] - $eps} { incr nocover }
    if {$rx2 - $rx1 > $widest} {
      set widest [expr {$rx2 - $rx1}]
      set widestblob [expr {[lindex $bxs 1] - [lindex $bxs 0]}]
    }
    if {$tshow eq ""} {
      set tshow "rect={[lmap q $r {format %.4f $q}]} blob=[format %.4f [lindex $bxs 0]],[format\
 %.4f [lindex $bys 0]]..[format %.4f [lindex $bxs 1]],[format %.4f [lindex $bys 1]]"
    }
  }
} else { set nocover -1 }
check "S64 (1337) each of those link rects is normalised, non-degenerate and COVERS the blob\
 ps_filledrect() drew for that instance (asserted on the PDF, blob mapped through the page CTM)" \
  [expr {$nocover == 0}] \
  "(ctm={$tctm} blobs=[llength $blobs] rects=[llength $trects] notcovering=$nocover $tshow $tpdf_err)"

# S64b -- WHICH BOX, said out loud. The small branch passes ps_link_pdfmark() the same
# inst.x1..y2 the normal path passes, NOT the inst.xx1..yy2 body box the blob is drawn from, so
# there is one rect rule in psprint.c rather than two and H3 can switch it in one place when it
# ships `ps_link_bbox` (issue 1339). tinf.sym's text sits 100 units to the right of a 60-unit
# body, so on that instance the two boxes differ by more than a factor of two: the widest link
# rect on the sheet must be strictly wider than the blob under it. A sub-3px branch that had
# quietly used the body box instead would pass S64 and fail here.
check "S64b (1337) the small branch uses the emitter's ONE box, inst.x1..y2 -- the widest rect\
 is strictly wider than its blob because tinf.sym's text is outside its body" \
  [expr {$nocover == 0 && $widest > $widestblob + 0.01}] \
  "(widest rect=[format %.4f $widest] pt, its blob=[format %.4f $widestblob] pt)"

# S65 -- A STATIC ROW, and it is static because the runtime case cannot be built.
# (a) The SIBLING early return above the small branch, `RECT_OUTSIDE(...) -> return`, is CORRECT:
#     an instance entirely off the page must get NO link, and H2 must not "fix" it too. Measured
#     with an instrumented build: under `hier_psprint` that branch fires ZERO times on greycnt,
#     0_examples_top, loading and poweramp_lcc, because ps_draw(2, fullzoom=1) zoom_full()s every
#     page at 0.97 fill, so nothing is ever outside. There is therefore no black-box fixture that
#     can reach it, and a row asserting "no link for an off-page instance" would be vacuous.
#     What CAN be fenced is that the return is still unconditional and still ahead of the emitter.
# (b) DD-2's spirit: there must be exactly ONE fprintf of a /Link pdfmark in the file. Two copies
#     of a rule that must agree IS issue 1334, the defect this batch exists to close, so a sub-3px
#     branch carrying its own copy of the emission would be the same defect in a new place.
set psrc [file join $repo src psprint.c]
set src ""
if {[file exists $psrc]} { set fh [open $psrc r] ; set src [read $fh] ; close $fh }
set nlink [regexp -all {/Subtype /Link} $src]
set outside_returns_first \
  [regexp {RECT_OUTSIDE\([^\n]*\n\s*\{\s*\n\s*xctx->inst\[n\]\.flags\|=1;\s*\n\s*return;} $src]
check "S65 (1337) src/psprint.c still returns unconditionally from the RECT_OUTSIDE branch (an\
 off-page instance gets no link) and emits the /Link pdfmark from exactly ONE place" \
  [expr {$src ne "" && $nlink == 1 && $outside_returns_first}] \
  "(bytes=[string length $src] link_fprintfs=$nlink rect_outside_return=$outside_returns_first)"

# S66 -- ISSUE 1337's OWN REGRESSION, caught by this batch's adversary and fixed before commit.
# A `type=subcircuit` symbol with no graphics and no text has inst.x1==x2 and y1==y2. It is
# therefore ALWAYS under the 3-px floor, so the pre-1337 binary returned before the emitter and
# emitted nothing. 1337's new call site reached it and wrote
#     [ /Rect [ 985 611.062 985 611.062 ] ... /Subtype /Link /ANN pdfmark
# -- a rect with no interior, unclickable in every viewer, and a direct violation of the
# llx<urx && lly<ury property S60/S61 assert. ps_link_pdfmark() now returns on the fully
# degenerate case.
#
# The guard is AND, not OR, and this row says so: `good` is a 60x40 body on the same sheet and
# must KEEP its link, because a symbol that is zero-wide but tall clears the floor on its y
# extent, takes the NORMAL path, and had a (zero-width, spec-legal, merely empty) link on the
# pre-change binary too. An `||` guard would delete that one, and "H2 removes no link from any
# sheet" is this item's whole control.
set dgps [file join $dir degtop.ps] ; set dgpdf [file join $dir degtop.pdf]
catch {file delete $dgps $dgpdf}
set noprint_libs {}
xschem load [file join $dir degtop.sch]
xschem hier_psprint $dgps
set dgs [ps_read $dgps]
set dglinks [lsort [ps_link_dests $dgs]]
set dgpages [lsort [ps_page_dests $dgs]]
set dgdegen 0
foreach r [ps_link_rects $dgs] {
  lassign $r a b c d
  if {$a == $c && $b == $d} { incr dgdegen }
}
check "S66 (1337) a zero-extent subcircuit instance gets NO link -- a rect with no interior is\
 not a link -- while the normal-sized cell on the same sheet keeps its own, and BOTH still get\
 pages" \
  [expr {$dglinks eq [list good.sch] && $dgdegen == 0 &&
         $dgpages eq [lsort {degtop.sch good.sch zero.sch}]}] \
  "(links={$dglinks} degenerate_rects=$dgdegen pages={$dgpages})"


# ============================================= H3 -- 1338 and 1339, the two preferences ==
# ⚠ DD-4: BOTH DEFAULT TO EXACTLY TODAY'S BEHAVIOUR. `ps_link_border` defaults to 0 (the
# `/Border [0 0 0]` xschem has always written -- the third element is border WIDTH, so nothing
# is drawn) and `ps_link_bbox` defaults to `full` (the text-inflated inst.x1..y2). Neither
# default is ratified: they are the USER's call, recorded as rule debts 1338 and 1339
# (tests/headless/owed.sh). S70, S72 and S76 are "nothing moved" controls -- non-reddening by
# design, exactly like S12..S15 -- and S71, S73, S74, S75 were RED before the change.
#
# EVERY H3 ARM RUNS IN A SPAWNED CHILD. Issue 1341: the page scale depends on how many times the
# hierarchy has been walked in the process, so two exports in THIS interpreter are not
# comparable to the digit. One child per arm makes every measurement a FIRST walk, which is what
# lets S71 assert DD-3's absolute and S73/S74 compare widths ACROSS arms.
#
# ⚠ AND EVERY ARM TURNS THE NAVIGATION STRIP ON EXPLICITLY (the `set ps_hier_nav both` below),
# because the SHIPPED DEFAULT IS `none`. The user ruled on 2026-09-24 that this branch takes
# the export fix with the new visible navigation off until they have looked at it -- see the
# note beside `set_ne ps_hier_nav none` in src/xschem.tcl. When this suite was written the
# default was `both` and every H6 arm got the strip without asking for it: flipping the
# default silently turned NINETEEN rows red (N1, N3-N11b, N13, N15, N17-N21, N24) and the
# reason was never about the strip, only about who had set the variable. A row that relies on
# a default is a row that makes the default impossible to change, so every arm now says what
# it needs. An arm's own `pref` lines are written AFTER this one and still win, which is what
# N12/N13/N14's `none`/`back`/`up`/`sideways` arms depend on.
proc h3_child {dir name body} {
  set f [file join $dir $name.tcl]
  set fd [open $f w]
  puts $fd "if {!\[info exists XSCHEM_LIBRARY_PATH\]} { set XSCHEM_LIBRARY_PATH {} }"
  puts $fd "set XSCHEM_LIBRARY_PATH \"$dir:\$XSCHEM_LIBRARY_PATH\""
  puts $fd "set noprint_libs {}"
  puts $fd "set ps_hier_nav both"
  puts $fd $body
  puts $fd "puts H3_DONE"
  puts $fd "flush stdout"
  puts $fd "exit 0"
  close $fd
  return [spawn_export $dir $f]
}
## One arm. `pref` is a list of literal Tcl lines run in the child before the load.
## Returns {pdf-rects pdf-bytes ps-bytes err}.
proc h3_arm {dir tag sheet pref} {
  set ps [file join $dir h3_$tag.ps] ; set pdf [file join $dir h3_$tag.pdf]
  catch {file delete $ps $pdf}
  set body ""
  foreach l $pref { append body "$l\n" }
  append body "xschem load {$sheet}\nxschem hier_psprint {$ps}"
  lassign [h3_child $dir h3c_$tag $body] rc sig out
  set err ""
  if {$rc != 0 || $sig} { set err "child rc=$rc sig=$sig" }
  if {[catch {exec ps2pdf $ps $pdf} e]} { append err " ps2pdf: $e" }
  set pd [pdf_read $pdf]
  return [list [pdf_rects $pd] $pd [ps_read $ps] $err]
}
proc rect_w {r} { lassign $r a b c d ; return [expr {abs($c-$a)}] }
proc rect_h {r} { lassign $r a b c d ; return [expr {abs($d-$b)}] }
## /Border and /C arrays in file order, SYMBOL links only (item H6: see pdf_annots above).
proc pdf_borders {d} {
  set r {} ; foreach a [pdf_annots $d] { if {![lindex $a 4]} { lappend r [lindex $a 1] } } ; return $r
}
proc pdf_cvals {d} {
  set r {}
  foreach a [pdf_annots $d] { if {![lindex $a 4] && [lindex $a 2] ne ""} { lappend r [lindex $a 2] } }
  return $r
}
## Issue 1342: the PS back end emits garbage from uninitialised reads (`9.62282e+39
## setlinewidth`) on the UNCHANGED binary and the values move with heap layout, so a
## byte-for-byte PostScript comparison of this back end is impossible without dropping them.
proc ps_filter {d} {
  set out {}
  foreach line [split $d "\n"] {
    if {[regexp {setlinewidth|setlinejoin|setlinecap|RGB} $line]} continue
    lappend out $line
  }
  return [join $out "\n"]
}

# ---------------------------------------------------------------- 1338: the border ---
lassign [h3_arm $dir gdef $greycnt {}]                       gdr gdd gdps gderr
lassign [h3_arm $dir gbor $greycnt {{set ps_link_border 1}}] gbr gbd gbps gberr

# S70 -- 1338's DD-4 control. At the default the annotation is what xschem has always written:
# /Border [0 0 0] on all 14 links, and no /C key anywhere in the document. This row cannot go
# red on the unmodified binary and that IS its job: it fences the ABSENCE of a change, which is
# the one property of this item that must not be waved through.
set gdborders [lsort -unique [pdf_borders $gdd]]
set gdc [pdf_cvals $gdd]
# ⚠ ITEM H4 CHANGED THIS ROW'S REASON WITHOUT CHANGING ITS PREDICATE, AND THAT IS WORTH
# READING TWICE. The default is no longer `ps_link_border 0`; it is `hier`, the user's ruling.
# greycnt still comes out with /Border [0 0 0] on all 14 and no /C anywhere -- but now because
# greycnt -> xnor is ONE level deep, so xnor is a leaf and nothing on the sheet is worth
# advertising. The assertion is untouched and still passes on the pre-H4 binary; only the
# sentence below is H4's. Row S89 is the row that says this out loud and proves the feature is
# not simply dead by turning it on for the same 14 links.
check "S70 (1338/DD-4/RULE-1) at the default every greycnt annotation still carries\
 /Border \[0 0 0\] and the document has no /C colour at all -- H3's bytes, and now for H4's\
 reason: the default is `hier` and greycnt's only link target, xnor, is a LEAF" \
  [expr {[llength $gdr] == 14 && $gdborders eq [list "0 0 0"] && [llength $gdc] == 0}] \
  "(n=[llength $gdr] borders={$gdborders} C={$gdc} $gderr)"

# S71 -- ISSUE 1338. At ps_link_border 1 the emitter writes /Border [0 0 1] /C [0 0 1]: the
# third element of /Border is the border WIDTH (PDF 32000-1 s12.5.4, the /Border entry of an
# annotation dictionary), so 1 means a solid 1-unit-wide rectangle drawn on the annotation's
# /Rect, and /C is its colour in DeviceRGB -- 0 0 1 is blue. A viewer draws a thin blue box
# round every clickable symbol; at 0 0 0 it draws nothing, which is why a reviewer today has no
# cue that the sheet is clickable at all. The row also asserts the preference moves NO geometry:
# the same 14 rects, congruent, normalised, at DD-3's 61.487 x 35.135 pt (a first walk, so the
# absolute is assertable -- issue 1341). It is the HEADLESS constant, not S13b's per-arm one:
# every H3 arm is a spawned `--nogui` child, so this row reads 61.487 x 35.135 whatever the
# parent is running under. That is deliberate -- issue 1345 is not H3's subject.
set gbborders [lsort -unique [pdf_borders $gbd]]
set gbc [lsort -unique [pdf_cvals $gbd]]
set gbbad 0 ; set gbw "" ; set gbh ""
foreach r $gbr {
  if {![rect_normalised $r]} { incr gbbad ; continue }
  if {$gbw eq ""} { set gbw [rect_w $r] ; set gbh [rect_h $r] }
  if {abs([rect_w $r] - $gbw) > 0.005 || abs([rect_h $r] - $gbh) > 0.005} { incr gbbad }
}
check "S71 (1338) at ps_link_border 1 every link carries /Border \[0 0 1\] and /C \[0 0 1\] -- a\
 viewer draws a 1 pt solid BLUE box on the /Rect -- and the geometry does not move: 14\
 congruent normalised rects still at DD-3's 61.487 x 35.135 pt" \
  [expr {[llength $gbr] == 14 && $gbborders eq [list "0 0 1"] && $gbc eq [list "0 0 1"] &&
         [llength [pdf_cvals $gbd]] == 14 && $gbbad == 0 &&
         $gbw ne "" && abs($gbw - 61.487) <= 0.005 && abs($gbh - 35.135) <= 0.005}] \
  "(n=[llength $gbr] borders={$gbborders} C={$gbc} nC=[llength [pdf_cvals $gbd]] offshape=$gbbad\
 size=[format %.3f $gbw]x[format %.3f $gbh] $gberr)"

# ------------------------------------------------------------------ 1339: the hotspot ---
lassign [h3_arm $dir ldef [file join $dir lntop.sch] {}]                      ldr ldd ldps lderr
lassign [h3_arm $dir lbod [file join $dir lntop.sch] {{set ps_link_bbox body}}] lbr lbd lbps lberr

# S72 -- 1339's control, and it is the DEFECT stated as a measurement. lntop.sch holds TWO
# instances of the SAME symbol; only the instance NAME differs. The emitter uses inst.x1..y2,
# which select.c:742-778 inflates with every expanded symbol text, so the hotspot of a cell
# tracks the length of the name a user happened to type. Non-reddening: it records today.
set ldw {}
foreach r $ldr { lappend ldw [rect_w $r] }
set ldspread 0
if {[llength $ldw] == 2} { set ldspread [expr {abs([lindex $ldw 0] - [lindex $ldw 1])}] }
check "S72 (1339/DD-4) at the DEFAULT ps_link_bbox full the two instances of ONE symbol get\
 DIFFERENT hotspots -- the rect tracks the instance NAME, which is the defect" \
  [expr {[llength $ldr] == 2 && [lsort [pdf_link_dests $ldd]] eq [lsort {lnsym.sch lnsym.sch}] &&
         $ldspread > 20.0}] \
  "(n=[llength $ldr] widths={[lmap q $ldw {format %.3f $q}]} spread=[format %.3f $ldspread] pt\
 $lderr)"

# S73 -- ISSUE 1339. At `body` the rect comes from inst.xx1..yy2, the box symbol_bbox() stores
# BEFORE the text union (select.c:730-740) and the very box ps_filledrect() draws the sub-3px
# blob from two lines away in psprint.c -- the internal inconsistency that makes this an issue
# and not merely a taste. The row asserts the two widths are EQUAL, not merely that one shrank:
# a "fix" that made the hotspot track the name at a different rate would pass a shrink test.
# It also pins the SHAPE to the body's own 60x40 aspect, so a fix that emitted some other
# constant box would fail, and requires both to be strictly narrower than the narrower default.
set lbw {} ; set lbh {}
foreach r $lbr { lappend lbw [rect_w $r] ; lappend lbh [rect_h $r] }
set lbeq 0 ; set lbaspect -1
if {[llength $lbr] == 2} {
  set lbeq [expr {abs([lindex $lbw 0] - [lindex $lbw 1]) <= 0.005 &&
                  abs([lindex $lbh 0] - [lindex $lbh 1]) <= 0.005}]
  if {[lindex $lbh 0] > 0} { set lbaspect [expr {[lindex $lbw 0] / [lindex $lbh 0]}] }
}
# ⚠ Compare PER INSTANCE, by position in the file: the SHORT-named instance's default WIDTH is
# already the body width, because `x1` at the body's left edge does not stick out past its right
# edge -- what the text union adds for it is HEIGHT. A row that demanded "every width shrank"
# would fail on a correct fix. It is the LONG name that widens the box, and both names raise it.
set ldh {}
foreach r $ldr { lappend ldh [rect_h $r] }
check "S73 (1339) at ps_link_bbox body the two instances of that ONE symbol get the SAME\
 hotspot -- equal widths AND heights to 0.005 pt, in the body's own 60x40 aspect -- and the\
 long-named one loses the 217 pt the name was adding, while BOTH lose the height the name added" \
  [expr {[llength $lbr] == 2 && $lbeq &&
         abs($lbaspect - 1.5) < 0.03 &&
         [lindex $lbw 1] < [lindex $ldw 1] - 1.0 &&
         [lindex $lbh 0] < [lindex $ldh 0] - 1.0 &&
         [lindex $lbh 1] < [lindex $ldh 1] - 1.0}] \
  "(body w={[lmap q $lbw {format %.3f $q}]} h={[lmap q $lbh {format %.3f $q}]}\
 w/h=[format %.4f $lbaspect] | full w={[lmap q $ldw {format %.3f $q}]}\
 h={[lmap q $ldh {format %.3f $q}]} $lberr)"

# S74 -- THE LANDMINE, and it is the input most likely to break this change. ps_link_pdfmark()
# returns on a fully degenerate rect (row S66, issue 1337's own regression). A type=subcircuit
# symbol with NO graphics but WITH text has a degenerate BODY box and a perfectly good
# text-inflated one, so switching boxes naively DELETES its link -- a link lost by flipping a
# preference whose whole purpose is to change the hotspot SIZE, and "this batch removes no link
# from any sheet" is the control every item in it has been judged on. The emitter therefore
# keeps the text-inflated box when the body box is fully degenerate: `body` is a request for a
# smaller hotspot, never for a missing one, and a symbol drawn entirely out of text IS its text.
# The RULE-2 ruling owed to the user includes this sub-question; the receipt says so.
lassign [h3_arm $dir tdef [file join $dir tontop.sch] {}]                       tdr tdd tdps tderr
lassign [h3_arm $dir tbod [file join $dir tontop.sch] {{set ps_link_bbox body}}] tbr tbd tbps tberr
set tddests [lsort [pdf_link_dests $tdd]]
set tbdests [lsort [pdf_link_dests $tbd]]
# widths keyed by dest, so the comparison survives any reordering of the annotations
## dest -> rect AREA in pt^2. AREA, not width: on this sheet the normal cell is named `x1`,
## whose text does not stick out past the body's right edge, so only its HEIGHT shrinks under
## `body`. A width-only comparison reads a correct fix as no change at all.
proc h3_by_dest {d} {
  set out {}
  set rr [pdf_rects $d] ; set dd [pdf_link_dests $d]
  foreach r $rr n $dd { lappend out $n [expr {[rect_w $r] * [rect_h $r]}] }
  return $out
}
array set tdmap [h3_by_dest $tdd]
array set tbmap [h3_by_dest $tbd]
set tonly_ok [expr {[info exists tbmap(tonly.sch)] && [info exists tdmap(tonly.sch)] &&
                    abs($tbmap(tonly.sch) - $tdmap(tonly.sch)) <= 0.05}]
set shrank [expr {[info exists tbmap(lnsym.sch)] && [info exists tdmap(lnsym.sch)] &&
                  $tbmap(lnsym.sch) < $tdmap(lnsym.sch) * 0.9}]
check "S74 (1339) THE LANDMINE: under `body` a bodyless-but-texted subcircuit KEEPS its link on\
 its text box -- the degeneracy guard must not eat it -- while the normal cell on the same\
 sheet really does shrink to its body" \
  [expr {$tddests eq [lsort {lnsym.sch tonly.sch}] && $tbdests eq $tddests &&
         $tonly_ok && $shrank}] \
  "(default={$tddests} body={$tbdests} areas pt^2: tonly [format %.1f [expr {[info exists\
 tdmap(tonly.sch)] ? $tdmap(tonly.sch) : -1}]] -> [format %.1f [expr {[info exists\
 tbmap(tonly.sch)] ? $tbmap(tonly.sch) : -1}]], lnsym [format %.1f [expr {[info exists\
 tdmap(lnsym.sch)] ? $tdmap(lnsym.sch) : -1}]] -> [format %.1f [expr {[info exists\
 tbmap(lnsym.sch)] ? $tbmap(lnsym.sch) : -1}]] $tderr $tberr)"

# S74b -- THE SHAPE H3's FIRST DRAFT SHIPPED BROKEN, and the reason S74 alone was not enough.
# S74 fences the FULLY degenerate body box (no graphics at all). A body box degenerate in exactly
# ONE axis -- a bare vertical or horizontal line plus a text -- passed the first draft's
# "has an extent" test, took the body box, and produced a rect with no interior:
#     ps_link_bbox full   vline.sch   22.205 x 63.108 pt
#     ps_link_bbox body   vline.sch    0.000 x 46.747 pt   <- emitted, and dead
# ps_link_pdfmark()'s own guard (S66) is deliberately AND, so it does not catch a rect that is
# degenerate in one axis only; and because the annotation IS still written, the item's
# LINKS-LOST control read zero throughout. A dead link that counts as a live one is precisely
# issue 1334's defect class, which is what this whole batch exists to close.
# The row asserts AREA on both degenerate shapes, not merely that the link survived -- and it
# asserts the normal cell on the SAME sheet still shrinks, so a "fix" that simply disabled
# `body` everywhere would fail here rather than pass.
lassign [h3_arm $dir axdef [file join $dir axtop.sch] {}]                       axdr axdd axdps axderr
lassign [h3_arm $dir axbod [file join $dir axtop.sch] {{set ps_link_bbox body}}] axbr axbd axbps axberr
set axddests [lsort [pdf_link_dests $axdd]]
set axbdests [lsort [pdf_link_dests $axbd]]
set axdegen {}
foreach r [pdf_rects $axbd] n [pdf_link_dests $axbd] {
  if {[rect_w $r] <= 0.005 || [rect_h $r] <= 0.005} { lappend axdegen $n }
}
array set axdmap [h3_by_dest $axdd]
array set axbmap [h3_by_dest $axbd]
set axkept [expr {$axbdests eq $axddests && $axddests eq [lsort {hline.sch lnsym.sch vline.sch}]}]
set axshrank [expr {[info exists axbmap(lnsym.sch)] && [info exists axdmap(lnsym.sch)] &&
                    $axbmap(lnsym.sch) < $axdmap(lnsym.sch) * 0.9}]
check "S74b (1339) a one-axis-degenerate body (a bare line + text) falls back to the text box\
 under `body` -- every rect keeps a NON-ZERO width AND height, so no link is emitted dead --\
 while the normal cell on the same sheet still shrinks to its body" \
  [expr {$axkept && [llength $axdegen] == 0 && $axshrank}] \
  "(default={$axddests} body={$axbdests} zero-area={$axdegen} lnsym area pt^2 [format %.1f\
 [expr {[info exists axdmap(lnsym.sch)] ? $axdmap(lnsym.sch) : -1}]] -> [format %.1f [expr\
 {[info exists axbmap(lnsym.sch)] ? $axbmap(lnsym.sch) : -1}]] $axderr $axberr)"

# S75 -- THE SWITCH IS INSIDE THE EMITTER, so it reaches the sub-3px branch too. That branch
# (issue 1337) draws the blob from inst.xx1..yy2 and passes ps_link_pdfmark() the text-inflated
# box, which S64b measures. Under `body` the two must COINCIDE -- so S64b's strict inequality
# inverts here -- and, critically, all four links must still be present: this is LINKS-LOST 0
# across the preference flip on the one sheet where every instance takes the small branch.
# H2's sabotage E was exactly the mistake this row catches: switch boxes at a CALL SITE and the
# small branch keeps the old one.
lassign [h3_arm $dir ybod [file join $dir tinytop.sch] {{set ps_link_bbox body}}] ybr ybd ybps yberr
set yblinks [lsort [ps_link_dests $ybps]]
set ybctm {}
set ybtail [string range $ybps [string first "/DEST pdfmark" $ybps] end]
if {[regexp {\n(-?[0-9.e+-]+) (-?[0-9.e+-]+) translate\n(-?[0-9.e+-]+) (-?[0-9.e+-]+) scale\n} \
     $ybtail . ybtx ybty ybsx ybsy]} { set ybctm [list $ybtx $ybty $ybsx $ybsy] }
set ybblobs {}
unset -nocomplain ylastblob
foreach line [split [ps_strip_nav $ybps] "\n"] {
  if {[regexp {^(-?[0-9.e+-]+) (-?[0-9.e+-]+) (-?[0-9.e+-]+) (-?[0-9.e+-]+) R$} $line . bx by bw bh]} {
    set ylastblob [list $bx $by $bw $bh]
  } elseif {[string match "*/Subtype /Link*" $line] && [info exists ylastblob]} {
    lappend ybblobs $ylastblob
  }
}
set ybmiss 0 ; set ybmaxdiff 0.0
if {[llength $ybctm] == 4 && [llength $ybblobs] == [llength $ybr] && [llength $ybr] == 4} {
  lassign $ybctm ybtx ybty ybsx ybsy
  foreach bl $ybblobs r $ybr {
    lassign $bl bx by bw bh
    set bxs [lsort -real [list [expr {$ybtx + $ybsx*$bx}] [expr {$ybtx + $ybsx*($bx+$bw)}]]]
    set d [expr {abs([rect_w $r] - ([lindex $bxs 1] - [lindex $bxs 0]))}]
    if {$d > $ybmaxdiff} { set ybmaxdiff $d }
    if {$d > 0.002} { incr ybmiss }
  }
} else { set ybmiss -1 }
check "S75 (1339) the switch is INSIDE ps_link_pdfmark(), so the sub-3px branch gets it too:\
 under `body` every small-instance rect COINCIDES with the blob drawn from the same box (S64b's\
 inequality inverts) and all four links survive the flip" \
  [expr {$yblinks eq [lsort {good.sch good.sch prim.sch tinf.sch}] && $ybmiss == 0}] \
  "(links={$yblinks} blobs=[llength $ybblobs] rects=[llength $ybr] mismatched=$ybmiss\
 maxdiff=[format %.4f $ybmaxdiff] pt $yberr)"

# S76 -- DD-4 AGAIN, on the path a cherry-pick can actually break. src/psprint.c and
# src/xschem.tcl are two files; if the emitter ever lands without its two `set_ne` lines
# tclgetvar() returns NULL, and the NULL path must be the DEFAULT path, not some third
# behaviour. The arm below unsets both variables after xschem.tcl has been sourced and asserts
# the PostScript is byte-identical to the plain default arm, filtered for issue 1342's garbage.
# Also the degeneracy row under `body`: zero.sym has no text either, so the fallback must NOT
# resurrect its link and S66's answer must be unchanged.
lassign [h3_arm $dir lnul [file join $dir lntop.sch] \
          {{unset -nocomplain ps_link_border ps_link_bbox ps_link_noborder_libs}}] \
          lnr lnd lnps lnerr
lassign [h3_arm $dir dbod [file join $dir degtop.sch] {{set ps_link_bbox body}}] dbr dbd dbps dberr
set dblinks [lsort [ps_link_dests $dbps]]
set dbdegen 0
foreach r [ps_link_rects $dbps] {
  lassign $r a b c e
  if {$a == $c && $b == $e} { incr dbdegen }
}
check "S76 (DD-4) with ALL THREE variables unset the PostScript is byte-identical to the\
 default arm (the NULL path IS the default path, so psprint.c landing without xschem.tcl's\
 set_ne lines changes no output -- H4 made that three lines, not two, and an unset REGEXP LIST\
 must not raise a Tcl error per page either), and under `body` the zero-extent cell still gets\
 NO link" \
  [expr {$lnps ne "" && [ps_filter $lnps] eq [ps_filter $ldps] &&
         $dblinks eq [list good.sch] && $dbdegen == 0}] \
  "(unset_bytes=[string length $lnps] default_bytes=[string length $ldps]\
 filtered_equal=[expr {[ps_filter $lnps] eq [ps_filter $ldps]}] degtop_links={$dblinks}\
 degenerate=$dbdegen $lnerr $dberr)"


# ============================================ 1338 / RULE-1 (item H4): THE SCOPED HIGHLIGHT ==
# THE USER RULED, 2026-09-10, verbatim:
#     "Only a symbol for a non-PDK cell that has real hierarchy (worth descending into) should
#      have the clickable link highlight in the PDF"
# H3 shipped the border at `ps_link_border 0` -- invisible -- pending exactly that ruling, so
# this is the FIRST item in the batch that deliberately changes what a user's export looks
# like. DD-4's byte-identity control does NOT apply to it and the rows below say so.
#
# Mechanically: advertise a link iff its TARGET page itself contains at least one instance that
# also gets a page, AND the target is not in an excluded (PDK) library.
#
#   * `ps_link_border` is now THREE states, not two: `none` (no border on any link, H3's
#     shipped default and the way back), `hier` (the ruling -- THE NEW DEFAULT), `all` (H3's
#     `ps_link_border 1`, a border on every link). `0` and `1` still parse as `none` and `all`.
#   * `ps_link_noborder_libs` is a list of regexps in the `noprint_libs` / `nolist_libs` idiom,
#     matched against the SCHEMATIC path of the target page.
#
# ⚠ THE LINK IS NOT SCOPED, ONLY THE HIGHLIGHT. Dropping the 22 unadvertised links would
# recreate issue 1335 (a page nothing links to) and break H1b's invariant that a link exists
# iff a page of that name does -- the control every item in this batch has been judged on. So
# every row below asserts the link count and the page set are UNCHANGED as well.
#
# ⚠ AND DD-3's greycnt CONTROL CANNOT SEE THIS ITEM AT ALL. greycnt -> xnor is ONE level deep,
# so xnor is a LEAF, so under the ruling greycnt's 14 links are all unadvertised and its
# default output is byte-identical to H3's. S70 therefore still passes for a NEW reason, and
# rows S80-S89 below are on sheets where the highlight actually fires. That is the recurring
# failure of this batch -- a control that cannot see the defect it is named for -- named here
# rather than discovered later.

# ---------------------------------------------------------------------- H4 fixtures ---
# (a) The 2x2: condition A (real hierarchy) and condition B (non-PDK) are INDEPENDENT, so all
#     four combinations get a fixture and exactly one of them is advertised.
file mkdir [file join $dir pdklib]
wsym [file join $dir hnp.sym]  $sub                 ;# A yes, B yes -> HIGHLIGHT
wsym [file join $dir lnp.sym]  $sub                 ;# A no,  B yes -> no
wsym [file join $dir pdklib hpdk.sym] $sub          ;# A yes, B no  -> no
wsym [file join $dir pdklib lpdk.sym] $sub          ;# A no,  B no  -> no
wtop [file join $dir hnp.sch]  {good}               ;# hierarchical: `good` gets a page
wsch [file join $dir lnp.sch]  lnp                  ;# leaf
wtop [file join $dir pdklib/hpdk.sch] {good}     ;# hierarchical, but in the excluded lib
wsch [file join $dir pdklib/lpdk.sch] lpdk          ;# leaf, in the excluded lib
wtopa [file join $dir indtop.sch] \
  {{hnp.sym ""} {pdklib/hpdk.sym ""} {lnp.sym ""} {pdklib/lpdk.sym ""}}

# (a2) THE FIFTH QUADRANT, and it exists because the SHIPPED DEFAULT once failed it.
# S81a..S81d all run with `ps_link_noborder_libs {/pdklib/}` -- an override -- so not one of
# them ever exercised the list this tree actually ships. That list contained `{/stdcells/}`,
# an UNANCHORED regexp matched against the target page's schematic PATH, and `stdcells` is one
# of the commonest directory names in an IC project. It therefore matched
#     /home/me/myproject/stdcells/myblock.sch
# a NON-PDK cell with real hierarchy -- exactly what the user's ruling grants the highlight to
# -- and it matched this repo's own sky130_tests/stdcells/schematic/stdcells.sch, a cell named
# `stdcells` in a library that is not a PDK. It protected nothing: sky130A/xschem_libs/stdcells
# ships 76 symbols and ZERO .sch, so no cell in it can get a page, a link or a border by any
# route. The pattern was dropped; this row is what stops it, or anything like it, coming back.
# The cell below lives in a directory literally named `stdcells` and IS hierarchical, and the
# row runs with NO preference override at all -- whatever src/xschem.tcl ships is what it tests.
file mkdir [file join $dir stdcells]
wsym [file join $dir stdcells scblk.sym] $sub
wtop [file join $dir stdcells/scblk.sch] {good}     ;# hierarchical, in a dir named `stdcells`
wtopa [file join $dir sctop.sch] {{stdcells/scblk.sym ""}}

# (b) A three-level chain. "Hierarchical" is a property of the TARGET page's own contents, not
#     of how deep the target sits: d1 and d2 are advertised, d3 is not.
foreach c {d1 d2 d3} { wsym [file join $dir $c.sym] $sub }
wtop [file join $dir d1.sch] {d2}
wtop [file join $dir d2.sch] {d3}
wsch [file join $dir d3.sch] d3
wtop [file join $dir dtop.sch] {d1}

# (c) THE INPUT MOST LIKELY TO BREAK THIS, and it is the shape that refuted H1 and H1-2.
#     ovwrap.sch's ONLY child is an instance-level `schematic=` override: the BASE symbol
#     nbase.sym is matched by noprint_libs and gets no page, while the OVERRIDE target good2.sch
#     does. So ovwrap is hierarchical ONLY if the child's destination is resolved from the
#     INSTANCE (get_sch_from_sym(..., n, ...)) rather than from the base symbol (..., -1, ...).
#     A collect pass that asked the base symbol reads ovwrap as a leaf and advertises nothing.
wsym [file join $dir ovwrap.sym] $sub
wtopa [file join $dir ovwrap.sch] {{nbase.sym "\nschematic=good2.sch"}}
wtop [file join $dir ovtop.sch] {ovwrap}

# (d) The mirror image: a page whose children are ALL dead-link candidates -- np (noprint_libs),
#     ign (default_schematic=ignore), miss (no .sch). None of them gets a page, so H1b emits no
#     link for any of them and lwrap is a LEAF. A collect pass that recorded an edge for every
#     subcircuit instance WITHOUT checking that the child really gets a page would advertise it.
wsym [file join $dir lwrap.sym] $sub
wtop [file join $dir lwrap.sch] {np ign miss}
wtop [file join $dir lwtop.sch] {lwrap}

# ------------------------------------------------------------------- H4 readers ---
## {dest border} for every /Link in the PostScript, in emission order.
## ⚠ MATCHED PER LINE WITH `.*` BETWEEN THE TWO KEYS, AND THAT IS NOT COSMETIC. An advertised
## annotation carries `/C [0 0 1]` BETWEEN /Border and /Dest, so a regexp that demands they be
## adjacent -- which is what this proc did in its first draft -- matches only the UNadvertised
## links and silently reports every advertised one as missing. It cost an hour of bisecting a
## C change that was correct from the first build, and it is exactly this batch's recurring
## failure wearing a reader's clothes: a control that cannot see the thing it is named for.
proc ps_links_full {d} {
  set r {}
  foreach line [split [ps_strip_nav $d] "\n"] {
    if {[regexp {/Border \[([^\]]*)\].*/Dest /(\S+) /Subtype /Link} $line . b t]} {
      lappend r [list $t [string trim $b]]
    }
  }
  return $r
}
## The dests of the links that carry a NON-ZERO border width, i.e. the advertised ones.
proc ps_hilit {d} {
  set r {}
  foreach e [ps_links_full $d] {
    lassign $e t b
    if {[lindex $b 2] != 0} { lappend r $t }
  }
  return $r
}
## THE INDEPENDENT ORACLE. Recomputes condition A from the DOCUMENT rather than from the C
## code under test: walk the PostScript in page order and collect, per page, the links emitted
## on it; a page is hierarchical iff one of its own links names another page of this document.
## Nothing here consults xschem's answer, so a row comparing this with ps_hilit is comparing
## two independent derivations.
proc ps_hier_pages {d} {
  set pages {} ; set order {} ; set cur ""
  foreach line [split [ps_strip_nav $d] "\n"] {
    if {[regexp {^\[ /Dest /(\S+) /DEST pdfmark} $line . p]} {
      set cur $p ; lappend order $p
      if {![dict exists $pages $p]} { dict set pages $p {} }
      continue
    }
    if {[regexp {/Dest /(\S+) /Subtype /Link} $line . t] && $cur ne ""} {
      dict set pages $cur [concat [dict get $pages $cur] [list $t]]
    }
  }
  set hier {}
  foreach p $order {
    foreach t [dict get $pages $p] {
      if {[dict exists $pages $t]} { lappend hier $p ; break }
    }
  }
  return [lsort -unique $hier]
}

# ------------------------------------------------------------- S80: the real design ---
# THE ROW THAT DECIDES THE ITEM. sky130 OA `sky130_tests_ase/tb_bandgap`, registry loaded:
# 8 pages, 24 links, and under the ruling EXACTLY TWO of those 24 keep the box -- the link to
# `bandgap` and the link to `bandgap_opamp`, the only two cells on that hierarchy that
# instantiate something worth descending into. The other 22 include all FIFTEEN `not`
# instances, which is the noise the ruling exists to remove. Measured on the unmodified
# binary before this item: 24 links, 0 advertised, /Border [0 0 0] on every one.
if {[file exists $oatb] && [file exists $oadefs]} {
  set opre4 [list \
    "set ::XSCHEM_LIBRARY_DEFS {$oadefs}" \
    "set ::library_registry_defs_only 1" \
    "set ::XSCHEM_LIBRARY_PATH {}" \
    "puts \"CELLVIEW |\[cellview_path sky130_tests_ase/bandgap schematic\]|\""]
  lassign [h3_arm $dir oa4 $oatb $opre4] oa4r oa4d oa4ps oa4err
  set oa4links [ps_link_dests $oa4ps]
  set oa4pages [ps_page_dests $oa4ps]
  set oa4hilit [lsort [ps_hilit $oa4ps]]
  check "S80 (1338/RULE-1) THE RULING ON A REAL DESIGN: tb_bandgap keeps all 24 links and all 8\
 pages, and exactly TWO of the 24 are advertised -- bandgap.sch and bandgap_opamp.sch. The 15\
 `not` links, and zero_opamp/passgate/passgate_nlvt/lvnand, are leaves and stay plain" \
    [expr {[llength $oa4links] == 24 && [llength $oa4pages] == 8 &&
           [llength [ps_dead $oa4ps]] == 0 &&
           $oa4hilit eq [lsort {bandgap.sch bandgap_opamp.sch}]}] \
    "(links=[llength $oa4links] pages=[llength $oa4pages] dead={[ps_dead $oa4ps]}\
 advertised=[llength $oa4hilit] {$oa4hilit} $oa4err)"

  check "S80b (RULE-1) ... and the ORACLE agrees: the advertised set recomputed from the\
 DOCUMENT (a page is hierarchical iff its own page carries a link to another page of this\
 document) is the same set, minus the top page which nothing links to" \
    [expr {[lsort -unique $oa4hilit] eq \
           [lsort [lsearch -all -inline -not -exact [ps_hier_pages $oa4ps] tb_bandgap.sch]]}] \
    "(emitted={[lsort -unique $oa4hilit]} oracle={[ps_hier_pages $oa4ps]})"
} else {
  check "S80 sky130 OA fixture present" 0 "(missing $oatb)"
  check "S80b sky130 OA fixture present" 0 "(missing $oatb)"
}

# ------------------------------------------- S81/S82: the two conditions are independent ---
# indtop.sch instantiates all four cells of the 2x2. `ps_link_noborder_libs {/pdklib/}` makes
# pdklib the stand-in PDK -- there is no real one to use, because EVERY sky130 PDK library on
# this box (sky130_fd_pr, sky130_stdcells, stdcells) ships ZERO .sch files, so no PDK cell can
# get a page, so no PDK cell can get a link, so condition B cannot bite on real work here. It
# still has to exist: a PDK that ships transistor-level standard cells is exactly the case
# condition A cannot catch, and that is the whole reason the ruling has two halves.
set indpref {{set ps_link_noborder_libs {{/pdklib/}}}}
lassign [h3_arm $dir ind $dir/indtop.sch $indpref] indr indd indps inderr
set indlinks [ps_links_full $indps]
set indhilit [lsort [ps_hilit $indps]]
set indwant {}
foreach e $indlinks { lassign $e t b ; lappend indwant "$t=[lindex $b 2]" }
## border width of the link naming `dest` on this sheet, or "" if there is no such link.
proc ind_border {links dest} {
  foreach e $links { lassign $e t b ; if {$t eq $dest} { return [lindex $b 2] } }
  return ""
}
# FOUR FIXTURES, FOUR ROWS -- one per quadrant of the 2x2, each asserting that the cell still
# HAS a link (the ruling scopes the highlight, never the link) and what its border width is.
check "S81a (RULE-1) A yes, B yes -- hnp has a paged child and is not in an excluded library:\
 its link is ADVERTISED (border width 1)" \
  [expr {[ind_border $indlinks hnp.sch] eq "1"}] \
  "(hnp border=|[ind_border $indlinks hnp.sch]| $inderr)"
check "S81b (RULE-1) A yes, B NO -- hpdk has the SAME paged child as hnp and differs only in\
 living under ps_link_noborder_libs: its link is NOT advertised, which is the half condition A\
 alone cannot produce" \
  [expr {[ind_border $indlinks hpdk.sch] eq "0"}] \
  "(hpdk border=|[ind_border $indlinks hpdk.sch]|)"
check "S81c (RULE-1) A NO, B yes -- lnp is a leaf in a perfectly ordinary library: not\
 advertised, which is the half condition B alone cannot produce" \
  [expr {[ind_border $indlinks lnp.sch] eq "0"}] \
  "(lnp border=|[ind_border $indlinks lnp.sch]|)"
check "S81d (RULE-1) A NO, B NO -- lpdk fails both and is not advertised" \
  [expr {[ind_border $indlinks lpdk.sch] eq "0"}] \
  "(lpdk border=|[ind_border $indlinks lpdk.sch]|)"
# ... and the SET, which four independent rows cannot give: an extra advertisement on a fifth
# link would pass all four above and fail this one.
# S81e -- THE SHIPPED DEFAULT, tested as shipped. No `ps_link_noborder_libs` override: this row
# reads whatever src/xschem.tcl sets. A hierarchical cell in a directory named `stdcells` is a
# non-PDK cell with real hierarchy and MUST be advertised. See the (a2) fixture comment for the
# defect this fences -- it shipped for one commit and no row could see it, because every other
# condition-B row overrides the list it was testing.
lassign [h3_arm $dir sc $dir/sctop.sch {}] scr scd scps scerr
set scadv [lsort [ps_hilit $scps]]
set scall [lsort [ps_link_dests $scps]]
check "S81e (RULE-1) THE SHIPPED DEFAULT: a hierarchical cell in a directory named `stdcells`\
 is a NON-PDK cell with real hierarchy and keeps its highlight -- the default list must name\
 PDK LIBRARIES, not directory names a PDK happens to use" \
  [expr {[lsearch -exact $scall scblk.sch] >= 0 &&
         [lsearch -exact $scadv scblk.sch] >= 0}] \
  "(links={$scall} advertised={$scadv} default={[expr {[info exists\
 ::ps_link_noborder_libs] ? $::ps_link_noborder_libs : {UNSET}}]} $scerr)"

check "S81 (RULE-1) A and B are INDEPENDENT, and the advertised SET on indtop.sch is exactly\
 {hnp.sch} -- nothing else on the sheet, and all six links still present and live" \
  [expr {$indhilit eq [list hnp.sch] &&
         [llength $indlinks] == 6 && [llength [ps_dead $indps]] == 0}] \
  "(links=[llength $indlinks] {$indwant} advertised={$indhilit} dead={[ps_dead $indps]} $inderr)"

check "S82 (RULE-1) ... and the link set is UNTOUCHED: all four cells still get a link and a\
 page. The ruling scopes the HIGHLIGHT, never the link -- dropping the three would recreate\
 issue 1335 and break H1b's link-iff-page invariant" \
  [expr {[lsort -unique [ps_link_dests $indps]] eq \
           [lsort {good.sch hnp.sch hpdk.sch lnp.sch lpdk.sch}] &&
         [lsort [ps_page_dests $indps]] eq \
           [lsort {indtop.sch hnp.sch hpdk.sch lnp.sch lpdk.sch good.sch}]}] \
  "(links={[lsort -unique [ps_link_dests $indps]]} pages={[lsort [ps_page_dests $indps]]})"

# --------------------------------------------------- S83: depth, not distance from the top ---
lassign [h3_arm $dir dep $dir/dtop.sch {}] depr depd depps deperr
check "S83 (RULE-1) on a three-level chain d1->d2->d3 the advertised set is {d1,d2}: being\
 worth descending into is a property of the TARGET page's own contents, not of how deep the\
 target sits, and the bottom cell is a leaf however long the chain above it is" \
  [expr {[lsort [ps_hilit $depps]] eq [lsort {d1.sch d2.sch}] &&
         [llength [ps_link_dests $depps]] == 3 && [llength [ps_page_dests $depps]] == 4}] \
  "(advertised={[lsort [ps_hilit $depps]]} links={[ps_link_dests $depps]}\
 pages={[ps_page_dests $depps]} oracle={[ps_hier_pages $depps]} $deperr)"

# ----------------------------------- S84: the instance-level override -- the H1/H1-2 shape ---
lassign [h3_arm $dir ovr $dir/ovtop.sch {{set noprint_libs {{nbase\.sym}}}}] ovrr ovrd ovrps ovrerr
check "S84 (RULE-1) ovwrap is hierarchical ONLY through an instance-level `schematic=`\
 override whose BASE symbol is excluded by noprint_libs: the child destination must be\
 resolved from the INSTANCE, not the base symbol. Asking the base symbol reads ovwrap as a\
 leaf and advertises nothing -- the axis that refuted H1 and H1-2" \
  [expr {[lsort [ps_hilit $ovrps]] eq [list ovwrap.sch] &&
         [lsort [ps_link_dests $ovrps]] eq [lsort {good2.sch ovwrap.sch}] &&
         [llength [ps_dead $ovrps]] == 0}] \
  "(advertised={[lsort [ps_hilit $ovrps]]} links={[lsort [ps_link_dests $ovrps]]}\
 pages={[lsort [ps_page_dests $ovrps]]} dead={[ps_dead $ovrps]} $ovrerr)"

# ------------------------------- S85: a page whose only children are dead-link candidates ---
lassign [h3_arm $dir lwr $dir/lwtop.sch {{set noprint_libs {{np\.sym}}}}] lwrr lwrd lwrps lwrerr
check "S85 (RULE-1) lwrap instantiates ONLY cells that get no page (noprint_libs /\
 default_schematic=ignore / no .sch), so it is a LEAF and is not advertised. Recording an edge\
 for every subcircuit instance without checking the child really gets a page would advertise\
 it -- and every link-count and dead-link control would still read clean" \
  [expr {[ps_hilit $lwrps] eq {} &&
         [lsort [ps_link_dests $lwrps]] eq [list lwrap.sch] &&
         [llength [ps_dead $lwrps]] == 0}] \
  "(advertised={[ps_hilit $lwrps]} links={[lsort [ps_link_dests $lwrps]]}\
 pages={[lsort [ps_page_dests $lwrps]]} dead={[ps_dead $lwrps]} $lwrerr)"

# ------------------------------------------------------------ S86/S87: the escape hatches ---
# `ps_link_border 0` must still mean NO borders at all, and there must still be a way to get
# H3's border-on-every-link. Both are asserted on a sheet where the default DOES advertise
# something, so a hatch that silently did nothing would be caught.
lassign [h3_arm $dir hnone $dir/indtop.sch \
  [concat $indpref {{set ps_link_border none}}]] hnr hnd hnps hnerr
lassign [h3_arm $dir hzero $dir/indtop.sch \
  [concat $indpref {{set ps_link_border 0}}]] hzr hzd hzps hzerr
check "S86 (RULE-1) `ps_link_border none` gives ZERO borders on a sheet the default DOES\
 advertise, and the legacy spelling `0` is byte-identical to it -- the way back to H3's\
 shipped behaviour" \
  [expr {[ps_hilit $hnps] eq {} && [llength [pdf_cvals $hnd]] == 0 &&
         [lsort -unique [pdf_borders $hnd]] eq [list "0 0 0"] &&
         [llength [ps_link_dests $hnps]] == 6 &&
         [ps_filter $hzps] eq [ps_filter $hnps]}] \
  "(none_advertised={[ps_hilit $hnps]} nC=[llength [pdf_cvals $hnd]]\
 borders={[lsort -unique [pdf_borders $hnd]]} links=[llength [ps_link_dests $hnps]]\
 zero_eq_none=[expr {[ps_filter $hzps] eq [ps_filter $hnps]}] $hnerr $hzerr)"

lassign [h3_arm $dir hall $dir/indtop.sch \
  [concat $indpref {{set ps_link_border all}}]] har had haps haerr
lassign [h3_arm $dir hone $dir/indtop.sch \
  [concat $indpref {{set ps_link_border 1}}]] hor hod hops hoerr
check "S87 (RULE-1) `ps_link_border all` advertises EVERY link -- H3's `ps_link_border 1`\
 behaviour, and the legacy spelling `1` is byte-identical to it. `all` ignores\
 ps_link_noborder_libs on purpose: it is the escape hatch, not a second scope" \
  [expr {[llength [ps_hilit $haps]] == 6 &&
         [lsort -unique [pdf_borders $had]] eq [list "0 0 1"] &&
         [llength [pdf_cvals $had]] == 6 &&
         [ps_filter $hops] eq [ps_filter $haps]}] \
  "(all_advertised=[llength [ps_hilit $haps]] borders={[lsort -unique [pdf_borders $had]]}\
 nC=[llength [pdf_cvals $had]] one_eq_all=[expr {[ps_filter $hops] eq [ps_filter $haps]}]\
 $haerr $hoerr)"

# ------------------------------------------- S88: the library list behaves like noprint_libs ---
lassign [h3_arm $dir libe $dir/indtop.sch {{set ps_link_noborder_libs {}}}] lber lbed lbeps lbeerr
lassign [h3_arm $dir libu $dir/indtop.sch \
  {{unset -nocomplain ps_link_noborder_libs}}] lbur lbud lbups lbuerr
check "S88 (RULE-1) ps_link_noborder_libs is a regexp list in the noprint_libs idiom: EMPTY\
 excludes nothing, so hpdk joins hnp and both hierarchical cells are advertised; and with the\
 variable UNSET the emitter must not error and must behave as empty" \
  [expr {[lsort [ps_hilit $lbeps]] eq [lsort {hnp.sch hpdk.sch}] &&
         [lsort [ps_hilit $lbups]] eq [lsort {hnp.sch hpdk.sch}] &&
         [ps_filter $lbups] eq [ps_filter $lbeps] &&
         [llength [ps_link_dests $lbeps]] == 6}] \
  "(empty={[lsort [ps_hilit $lbeps]]} unset={[lsort [ps_hilit $lbups]]}\
 unset_eq_empty=[expr {[ps_filter $lbups] eq [ps_filter $lbeps]}]\
 links=[llength [ps_link_dests $lbeps]] $lbeerr $lbuerr)"

# --------------------------------------- S89: what the ruling does to DD-3's own control ---
# greycnt -> xnor is ONE level deep, so xnor is a LEAF and the DEFAULT advertises NOTHING on
# DD-3's control sheet -- its default output is byte-identical to H3's. This row exists so that
# fact is asserted rather than assumed, and so the control is not mistaken for evidence that
# the new default does nothing: at `all` the same sheet advertises all 14.
lassign [h3_arm $dir ghd $greycnt {}] ghdr ghdd ghdps ghderr
lassign [h3_arm $dir gha $greycnt {{set ps_link_border all}}] ghar ghad ghaps ghaerr
check "S89 (RULE-1/DD-3) DD-3's greycnt control CANNOT SEE THIS ITEM: greycnt -> xnor is one\
 level deep, xnor is a LEAF, so at the new default all 14 links stay plain and the sheet is\
 byte-identical to H3's default output. At `all` the same 14 are advertised, which is what\
 proves the row is not passing because the feature is dead" \
  [expr {[ps_hilit $ghdps] eq {} && [llength [ps_link_dests $ghdps]] == 14 &&
         [llength [ps_hilit $ghaps]] == 14 &&
         [lsort [ps_page_dests $ghdps]] eq [lsort {greycnt.sch xnor.sch}]}] \
  "(default_advertised={[ps_hilit $ghdps]} links=[llength [ps_link_dests $ghdps]]\
 all_advertised=[llength [ps_hilit $ghaps]] pages={[lsort [ps_page_dests $ghdps]]}\
 $ghderr $ghaerr)"


# ------------------------------------------- S90: the border mode is read ONCE PER EXPORT ---
# Issue 1346 records that H3's preferences are read from Tcl once per LINK; H4 was told not to
# make that worse and did not -- ps_link_border is now read ONCE PER EXPORT, beside the collect
# pass, and the emitter does a hash lookup with no Tcl at all. The obvious way to get that
# wrong is to read it once per PROCESS instead, which every spawned-child row in this suite
# would pass. So this row runs TWO exports IN ONE INTERPRETER with the variable changed in
# between, which is also what a user gets from two File > Print runs in one session.
set b4save [expr {[info exists ps_link_border] ? $ps_link_border : " "}]
set noprint_libs {}
set rr1 [file join $dir rr1.ps] ; set rr2 [file join $dir rr2.ps] ; set rr3 [file join $dir rr3.ps]
xschem load $greycnt
xschem hier_psprint $rr1
set ps_link_border all
xschem hier_psprint $rr2
set ps_link_border none
xschem hier_psprint $rr3
set rr1h [llength [ps_hilit [ps_read $rr1]]]
set rr2h [llength [ps_hilit [ps_read $rr2]]]
set rr3h [llength [ps_hilit [ps_read $rr3]]]
check "S90 (1338/1346) ps_link_border is re-read on EVERY export, not cached for the life of\
 the process: three hier_psprint runs in ONE interpreter with the variable changed between\
 them give 0, 14 and 0 advertised links. A once-per-process read passes every other row here,\
 because every other H4 arm is a fresh spawned child" \
  [expr {$rr1h == 0 && $rr2h == 14 && $rr3h == 0 &&
         [llength [ps_link_dests [ps_read $rr2]]] == 14}] \
  "(default=$rr1h all=$rr2h none=$rr3h links=[llength [ps_link_dests [ps_read $rr2]]])"

# S91 -- an unrecognised value must take the DEFAULT, not silently disable the feature. A typo
# in an xschemrc is the likely source, and `hier` is the answer that shows the user something.
set ps_link_border bluish
set rr4 [file join $dir rr4.ps]
xschem hier_psprint $rr4
xschem load [file join $dir dtop.sch]
set rr5 [file join $dir rr5.ps]
xschem hier_psprint $rr5
if {$b4save eq " "} { unset -nocomplain ps_link_border } else { set ps_link_border $b4save }
check "S91 (1338) an unrecognised ps_link_border value falls back to the DEFAULT `hier`, not\
 to `none`: on greycnt (all leaves) it advertises nothing, and on the three-level chain it\
 advertises exactly the two cells the ruling names" \
  [expr {[ps_hilit [ps_read $rr4]] eq {} &&
         [lsort [ps_hilit [ps_read $rr5]]] eq [lsort {d1.sch d2.sch}]}] \
  "(greycnt={[ps_hilit [ps_read $rr4]]} chain={[lsort [ps_hilit [ps_read $rr5]]]})"

# ---------------------------------- S92: the flat /Dest basename, where it is OBSERVABLE ---
# A PDF destination is a FLAT basename, so the whole scope is keyed on one. Normally that is
# invisible: hier_psprint()'s subckt_table gives one page per destination name, so each name
# has exactly one set of outgoing edges. The TOP page is not in subckt_table, so a top whose
# file basename equals a child's is the one shape where TWO pages share a destination -- and
# then the two pages' edges are UNIONED, deliberately and in the permissive direction (a page
# hierarchical under either name is worth descending into; nothing here can suppress a LINK,
# only its border).
#
# The consequence, asserted rather than argued: HD/inv.sch instantiates HC/inv.sym, so both
# pages anchor /Dest /inv.sch, the top's edge inv.sch -> inv.sch resolves against the page set,
# and the link is ADVERTISED although the page a reader lands on is a leaf. This is downstream
# of a destination collision the PDF itself cannot represent (the /Dests name tree binds ONE
# object per name), which H1b already documented; the border merely inherits it. Suppressing
# self-edges is a one-line alternative and would make this read as a leaf -- but it would also
# under-advertise a genuine two-library homonym, which is the direction this batch does not
# take. Recorded here so a future change has to face the choice instead of rediscovering it.
file mkdir [file join $dir HC] [file join $dir HD]
wsym [file join $dir HC inv.sym] $sub
wsch [file join $dir HC inv.sch] leafC
wtopa [file join $dir HD inv.sch] {{HC/inv.sym ""}}
lassign [h3_arm $dir hom [file join $dir HD inv.sch] {}] homr homd homps homerr
check "S92 (RULE-1) the scope is keyed on the FLAT /Dest basename, and where a top page and a\
 child page share one -- the only shape that reaches it -- the two pages' edges are UNIONED in\
 the permissive direction, so the link is advertised although the page behind it is a leaf.\
 The destination collision itself is pre-existing (a /Dests name tree binds ONE object per\
 name); the border inherits it" \
  [expr {[llength [ps_page_dests $homps]] == 2 &&
         [lsort -unique [ps_page_dests $homps]] eq [list inv.sch] &&
         [ps_hilit $homps] eq [list inv.sch] &&
         [llength [ps_link_dests $homps]] == 1}] \
  "(pages={[ps_page_dests $homps]} links={[ps_link_dests $homps]}\
 advertised={[ps_hilit $homps]} $homerr)"


# ============================================================ ITEM H6: THE NAV STRIP ==
# The user asked for this twice and it did not exist:
#     "How difficult to add references on a child cell to have links to parent schematics?"
#     "did we succeed in putting Back buttons? I know Alt-Left is a back button, but a
#      clickable button means user can keep one hand on the mouse"
# Every link this feature wrote before item H6 was one-way, symbol -> child. These rows fence
# the two things H6 adds to EVERY page of a hierarchical export, drawn in the 10 pt band above
# the drawing area:
#   * a BACK BUTTON -- a PDF named action, `/A<</S/Named /N/GoBack>>`, which is the viewer's
#     own history Back, identical to Alt-Left. It returns the reader wherever they came FROM,
#     so it does nothing useful for a reader who SCROLLED to the page rather than clicking
#     into it. That is the honest limit and no row pretends otherwise.
#   * a PARENT REFERENCE -- `Up: <sheet>`, one clickable /Dest per sheet that instantiates
#     this cell. A cell instantiated in five places has five parents, so it is a LIST.
# The top page has no parent and shows no `Up:`; it still gets a Back button (uniform
# furniture, and a viewer's Back is meaningful after any navigation, including scrolling).
#
# The parent relation is NOT a new walk: item H4's collect pass already records one edge per
# instance per page, and read the other way that edge set IS the parent map.

## the 10 pt band the strip lives in, from the page's own MediaBox: [pagey-margin, pagey]
proc pdf_mediabox {d} {
  if {[regexp {/MediaBox\s*\[([^\]]*)\]} $d . v]} { return [string trim $v] }
  return ""
}
proc rects_overlap {a b} {
  lassign $a ax1 ay1 ax2 ay2 ; lassign $b bx1 by1 bx2 by2
  return [expr {$ax1 < $bx2 && $bx1 < $ax2 && $ay1 < $by2 && $by1 < $ay2}]
}
## the parent map the DOCUMENT implies, recomputed from the forward links alone: page P is a
## parent of page C iff P's own page carries a link naming C. Nothing here consults the C
## code's answer, so a row comparing this with ps_nav_parents compares two derivations.
proc ps_doc_parents {d} {
  set m [dict create] ; set cur ""
  foreach line [split [ps_strip_nav $d] "\n"] {
    if {[regexp {^\[ /Dest /(\S+) /DEST pdfmark} $line . p]} {
      set cur $p ; if {![dict exists $m $p]} { dict set m $p {} } ; continue
    }
    if {[regexp {/Dest /(\S+) /Subtype /Link} $line . t] && $cur ne ""} {
      if {![dict exists $m $t]} { dict set m $t {} }
      dict set m $t [lsort -unique [concat [dict get $m $t] [list $cur]]]
    }
  }
  return $m
}

# ------------------------------------------------------------------ H6 fixtures ---
# FIVE PARENTS. mp.sch is a leaf instantiated by five different sheets, which is the shape the
# item's brief names as most likely to break a design that assumed one parent per page.
wsym [file join $dir mp.sym] $sub
wsch [file join $dir mp.sch] mp
for {set i 1} {$i <= 5} {incr i} {
  wsym [file join $dir mpp$i.sym] $sub
  wtopa [file join $dir mpp$i.sch] {{mp.sym ""}}
}
wtopa [file join $dir mptop.sch] {{mpp1.sym ""} {mpp2.sym ""} {mpp3.sym ""} {mpp4.sym ""} {mpp5.sym ""}}

# TRUE RECURSION. rec.sch instantiates rec.sym, so the page's own parent is itself. H4's
# receipt left this standing and disclosed it; H6 has to answer it in ink.
wsym [file join $dir rec.sym] $sub
wtopa [file join $dir rec.sch] {{rec.sym ""}}
wsym [file join $dir rtop.sym] $sub
wtopa [file join $dir rectop.sch] {{rec.sym ""}}

# A PARENT LIST TOO WIDE FOR THE PAGE. Eight parents at ~44 characters each is 1480 pt of
# Courier 7 against 802 pt of usable page.
set widenames {}
for {set i 1} {$i <= 8} {incr i} {
  set n "wide_parent_sheet_number_${i}_with_a_long_name"
  lappend widenames $n
  wsym [file join $dir $n.sym] $sub
  wtopa [file join $dir $n.sch] {{wleaf.sym ""}}
}
wsym [file join $dir wleaf.sym] $sub
wsch [file join $dir wleaf.sch] wleaf
set wcells {}
foreach n $widenames { lappend wcells [list $n.sym ""] }
wtopa [file join $dir wtop.sch] $wcells

# A PARENT LIST TUNED TO PUT THE `+N` COUNT OFF THE PAGE. Row N19's list truncates at 3 of 8
# and stops 170 pt clear of the margin, so it is STRUCTURALLY BLIND to what happens when the
# last drawn name ends JUST short of the right margin. That is a narrow window -- the count is
# then drawn at up to `right + 2*cw` -- and it is where `+N` used to be clipped by the media
# box and rendered `+20` as `+2`. Solved rather than guessed: Courier 7 is exactly 4.2 pt per
# glyph, names start at margin+10 + (6*cw+6) + 10 + 4*cw = 78.0, each costs 4.2*len + 8.4, and
# `right` is 842-10-4 = 828, so a 10-character name (`pa01ab.sch`) with 30 parents stops the
# loop at x = 834.0 and puts a three-glyph count's ink at 846.6 on an 842 pt page.
set inknames {}
for {set i 1} {$i <= 30} {incr i} {
  set n [format "pa%02dab" $i]                    ;# 6 chars + ".sch" = 10 glyphs exactly
  lappend inknames $n
  wsym [file join $dir $n.sym] $sub
  wtopa [file join $dir $n.sch] {{inkc.sym ""}}
}
wsym [file join $dir inkc.sym] $sub
wsch [file join $dir inkc.sch] inkc
set inkcells {}
foreach n $inknames { lappend inkcells [list $n.sym ""] }
wtopa [file join $dir inktop.sch] $inkcells

# A PORTRAIT PAGE. create_ps() decides orientation PER PAGE from that page's own drawing
# bbox and swaps pagex/pagey, so one document really can carry both -- measured over the
# tree: 902 landscape pages and 21 portrait. The strip is placed from `pagey`, so a fixture
# with only landscape pages cannot see a placement that used the wrong dimension. (This is
# not hypothetical: the first PDF-level version of row N7 took ONE MediaBox for the whole
# file and reported 41 false violations on the tree for exactly this reason.)
wsym [file join $dir tall.sym] $sub
wsch [file join $dir tall.sch] tall
set fh [open [file join $dir talltop.sch] w]
foreach l [list "v {xschem version=3.4.6 file_version=1.2}" "G {}" "K {}" "V {}" "S {}" "E {}"] {
  puts $fh $l
}
for {set i 0} {$i < 6} {incr i} { puts $fh "C {tall.sym} 0 [expr {$i*600}] 0 0 {name=x$i}" }
close $fh

# A NAME WHOSE POSTSCRIPT STRING IS LONGER THAN ITS INK. `ps_string_body()` (issue 1350)
# recodes a two-byte UTF-8 sequence into ONE `\ddd` escape, and escapes `(`, `)` and `\`, so
# the number of BYTES a name occupies in a PostScript literal is not the number of glyphs it
# shows. `escep.sch` with an e-acute is 10 bytes on disk, 12 in the literal (`esc\351p.sch`)
# and NINE glyphs on the page: a hotspot sized from either byte count is wrong, and the wrong
# one silently slides under the next parent's ink.
set escname "escép"
wsym [file join $dir $escname.sym] $sub
wtopa [file join $dir $escname.sch] {{mp.sym ""}}
wtopa [file join $dir esctop.sch] [list [list $escname.sym ""]]

# ------------------------------------------------------------------- N0: the reader ---
# The reader that every PDF row below leans on, checked against a raw count. It has already
# been wrong once in this suite -- Tcl's ARE took its greediness from the first quantified
# atom and parsed 1 annotation where the file had 14, which reads exactly like a code defect.
lassign [h3_arm $dir n0 $greycnt {}] n0r n0d n0ps n0err
set n0raw [regexp -all {/Subtype\s*/Link} $n0d]
check "N0 the PDF annotation reader parses every /Subtype /Link object the file contains" \
  [expr {$n0raw > 0 && [llength [pdf_annots $n0d]] == $n0raw}] \
  "(parsed=[llength [pdf_annots $n0d]] raw=$n0raw $n0err)"

# ------------------------------------------------------- N1: the strip, on DD-3's sheet ---
set nvps $n0ps
set nvmap [ps_nav_map $nvps]
set nvpar [ps_nav_parents $nvps]
check "N1 (H6) greycnt: BOTH pages carry a nav strip -- one Back button each -- and the strip\
 names the parent: xnor.sch is instantiated by greycnt.sch, and the TOP page has no parent so\
 it shows none" \
  [expr {[llength $nvmap] == 2 &&
         [lindex $nvmap 0 1] == 1 && [lindex $nvmap 1 1] == 1 &&
         [dict exists $nvpar greycnt.sch] && [dict get $nvpar greycnt.sch] eq {} &&
         [dict exists $nvpar xnor.sch] && [dict get $nvpar xnor.sch] eq [list greycnt.sch]}] \
  "(map={$nvmap} $n0err)"

# ------------------------------------------------------------------ N2: DD-3 unmoved ---
# H6 ADDS annotations and removes none. The forward rects must be the same fourteen numbers.
set nvfwd [pdf_rects $n0d]
set nvw {} ; set nvh {} ; set nvcong 1
foreach r $nvfwd {
  lassign $r a b c e
  lappend nvw [expr {abs($c-$a)}] ; lappend nvh [expr {abs($e-$b)}]
}
foreach w $nvw h $nvh {
  if {abs($w-[lindex $nvw 0]) > 0.005 || abs($h-[lindex $nvh 0]) > 0.005} { set nvcong 0 }
}
check "N2 (H6/DD-3) the control does not move: greycnt still exports 14 forward link rects,\
 mutually congruent at 61.487 x 35.135 pt, MediaBox 842x595, and every one still points at\
 xnor.sch" \
  [expr {[llength $nvfwd] == 14 && $nvcong &&
         abs([lindex $nvw 0] - 61.487) <= 0.005 && abs([lindex $nvh 0] - 35.135) <= 0.005 &&
         [lsort -unique [pdf_link_dests $n0d]] eq [list xnor.sch] &&
         [pdf_mediabox $n0d] eq "0 0 842 595"}] \
  "(n=[llength $nvfwd] congruent=$nvcong first=[lindex $nvw 0] x [lindex $nvh 0]\
 dests={[lsort -unique [pdf_link_dests $n0d]]} media={[pdf_mediabox $n0d]})"

# --------------------------------------------- N3: the action, read out of the PDF ---
# NOT "a rectangle exists". The distilled annotation must carry a real PDF named action.
set nvnav [pdf_nav_annots $n0d]
set nvgb 0 ; set nvup 0
foreach a $nvnav { if {[lindex $a 5]} { incr nvgb } elseif {[lindex $a 3] ne ""} { incr nvup } }
check "N3 (H6) the Back button distils to a REAL PDF named action -- /A<</S/Named /N/GoBack>>\
 -- one per page, and greycnt's single parent reference is the only other nav annotation" \
  [expr {[llength $nvnav] == 3 && $nvgb == 2 && $nvup == 1}] \
  "(nav=[llength $nvnav] goback=$nvgb up=$nvup)"

# --------------------------------------- N4: 1334's rule, applied in the NEW direction ---
set nvbaddest {}
foreach a $nvnav {
  set dst [lindex $a 3]
  if {$dst ne "" && [lsearch -exact [pdf_dest_names $n0d] $dst] < 0} { lappend nvbaddest $dst }
}
check "N4 (H6/1334) every parent reference points at a page the document ACTUALLY CONTAINS --\
 the dead-link rule of issue 1334 asked backwards" \
  [expr {$nvup > 0 && [llength $nvbaddest] == 0}] \
  "(up=$nvup bad={$nvbaddest} defined={[lsort -unique [pdf_dest_names $n0d]]})"

# ------------------------------------------------- N5/N6/N7: geometry, on the PDF ---
# Collected over EVERY pdf this suite has written, not just this one.
set nvfiles [lsort [glob -nocomplain -directory $dir *.pdf]]
set nvbadnorm {} ; set nvoverlap {} ; set nvbadband {} ; set nvtot 0
foreach f $nvfiles {
  set fd2 [pdf_read $f]
  if {[string length $fd2] < 200} { continue }
  set mb [pdf_mediabox $fd2]
  if {$mb eq ""} { continue }
  set pgy [lindex $mb 3]
  set nav {} ; set fwd {}
  foreach a [pdf_annots $fd2] {
    if {[lindex $a 4]} { lappend nav [lindex $a 0] } else { lappend fwd [lindex $a 0] }
  }
  incr nvtot [llength $nav]
  foreach r $nav {
    lassign $r a b c e
    if {!($a < $c && $b < $e)} { lappend nvbadnorm "[file tail $f]:{$r}" }
    # the drawing area of a page can reach pagey-margin and no higher (margin is 10 and the
    # translate puts the top of the bbox at pagey-(scaley-scale)*dy-margin), so a rect whose
    # lly is above that CANNOT be a forward hotspot. That is the structural half of N6.
    if {$b < $pgy - 10.0} { lappend nvbadband "[file tail $f]:{$r} pagey=$pgy" }
    foreach g $fwd { if {[rects_overlap $r $g]} { lappend nvoverlap "[file tail $f]:{$r}|{$g}" } }
  }
}
check "N5 (H6/1336) every nav rect in every PDF this suite wrote is normalised after ps2pdf:\
 llx<urx AND lly<ury" \
  [expr {$nvtot > 0 && [llength $nvbadnorm] == 0}] \
  "(nav rects=$nvtot files=[llength $nvfiles] bad={[lrange $nvbadnorm 0 3]})"
check "N6 (H6) NO nav rect overlaps ANY forward link rect, in any PDF this suite wrote. The\
 two sets are told apart by /F 4, NOT by where they sit, so this is a proof and not a\
 restatement: a reviewer clicking a symbol cannot hit the Back button" \
  [expr {$nvtot > 0 && [llength $nvoverlap] == 0}] \
  "(nav rects=$nvtot overlaps=[llength $nvoverlap] {[lrange $nvoverlap 0 2]})"

# ----------------------------------------------- N8/N9: THE ROW THAT DECIDES THE ITEM ---
# sky130_tests_ase/tb_bandgap with the registry loaded: 8 pages, 24 links. The parent of every
# page checked by hand against the schematics -- and `not` is instantiated by BOTH bandgap and
# bandgap_opamp, which is the case a one-parent design gets wrong.
if {[file exists $oatb] && [file exists $oadefs]} {
  set opre6 [list \
    "set ::XSCHEM_LIBRARY_DEFS {$oadefs}" \
    "set ::library_registry_defs_only 1" \
    "set ::XSCHEM_LIBRARY_PATH {}" \
    "puts \"CELLVIEW |\[cellview_path sky130_tests_ase/bandgap schematic\]|\""]
  lassign [h3_arm $dir oa6 $oatb $opre6] oa6r oa6d oa6ps oa6err
  set oa6map [ps_nav_map $oa6ps]
  set oa6par [ps_nav_parents $oa6ps]
  set oa6back 0
  foreach e $oa6map { incr oa6back [lindex $e 1] }
  set want6 [dict create \
    tb_bandgap.sch {} \
    bandgap.sch {tb_bandgap.sch} \
    bandgap_opamp.sch {bandgap.sch} \
    zero_opamp.sch {bandgap.sch} \
    passgate.sch {bandgap.sch} \
    lvnand.sch {bandgap.sch} \
    not.sch {bandgap.sch bandgap_opamp.sch} \
    passgate_nlvt.sch {bandgap.sch}]
  dict set want6 passgate_nlvt.sch {bandgap_opamp.sch}
  set oa6ok 1 ; set oa6diff {}
  foreach k [dict keys $want6] {
    if {![dict exists $oa6par $k] || [dict get $oa6par $k] ne [dict get $want6 $k]} {
      set oa6ok 0
      lappend oa6diff "$k got={[expr {[dict exists $oa6par $k] ? [dict get $oa6par $k] : "MISSING"}]}\
 want={[dict get $want6 $k]}"
    }
  }
  check "N8 (H6) THE ROW THAT DECIDES THE ITEM. tb_bandgap, registry loaded: all 8 pages and\
 all 24 forward links survive, every page carries a Back button, and the parent named on each\
 page is the sheet that really instantiates it -- checked by hand against the schematics" \
    [expr {[llength [ps_page_dests $oa6ps]] == 8 && [llength [ps_link_dests $oa6ps]] == 24 &&
           [llength [ps_dead $oa6ps]] == 0 && [llength $oa6map] == 8 && $oa6back == 8 && $oa6ok}] \
    "(pages=[llength [ps_page_dests $oa6ps]] links=[llength [ps_link_dests $oa6ps]]\
 dead={[ps_dead $oa6ps]} strips=[llength $oa6map] back=$oa6back diff={$oa6diff} $oa6err)"

  set oa6notrects {}
  foreach e $oa6map { if {[lindex $e 0] eq "not.sch"} { set oa6notrects [lindex $e 3] } }
  check "N9 (H6) THE MULTI-PARENT CASE, which is the one a design assuming one parent gets\
 wrong: `not` is instantiated in bandgap AND in bandgap_opamp, so its page lists BOTH, each as\
 its own clickable rect (Back + 2 parents = 3 nav rects on that page)" \
    [expr {[dict exists $oa6par not.sch] &&
           [dict get $oa6par not.sch] eq [lsort {bandgap.sch bandgap_opamp.sch}] &&
           [llength $oa6notrects] == 3}] \
    "(parents={[expr {[dict exists $oa6par not.sch] ? [dict get $oa6par not.sch] : {}}]}\
 navrects=[llength $oa6notrects])"

  check "N11a (H6) ... and an INDEPENDENT ORACLE agrees: the parent map recomputed from the\
 DOCUMENT alone (page P is a parent of C iff P's page carries a link naming C) is exactly the\
 map the strip prints, on all 8 pages" \
    [expr {[ps_doc_parents $oa6ps] eq $oa6par}] \
    "(doc={[ps_doc_parents $oa6ps]} strip={$oa6par})"
} else {
  check "N8 sky130 OA fixture present" 0 "(missing $oatb)"
  check "N9 sky130 OA fixture present" 0 "(missing $oatb)"
  check "N11a sky130 OA fixture present" 0 "(missing $oatb)"
}

# ------------------------------------------------------------ N10/N11b: five parents ---
lassign [h3_arm $dir mp [file join $dir mptop.sch] {}] mpr mpd mpps mperr
set mppar [ps_nav_parents $mpps]
set mpmap [ps_nav_map $mpps]
set mprects {}
foreach e $mpmap { if {[lindex $e 0] eq "mp.sch"} { set mprects [lindex $e 3] } }
set mpwant [lsort {mpp1.sch mpp2.sch mpp3.sch mpp4.sch mpp5.sch}]
set mpnavd {}
foreach a [pdf_nav_annots $mpd] { if {[lindex $a 3] ne ""} { lappend mpnavd [lindex $a 3] } }
check "N10 (H6) FIVE PARENTS. mp.sch is instantiated on five different sheets: the strip lists\
 all five, each with its own annotation (Back + 5 = 6 nav rects on that page), and every one\
 of the five is a /Dest the PDF defines" \
  [expr {[dict exists $mppar mp.sch] && [dict get $mppar mp.sch] eq $mpwant &&
         [llength $mprects] == 6 &&
         [llength [lsearch -all -inline -exact $mpnavd mpp1.sch]] == 1}] \
  "(parents={[expr {[dict exists $mppar mp.sch] ? [dict get $mppar mp.sch] : {}}]}\
 navrects=[llength $mprects] pdfnavdests={[lsort $mpnavd]} $mperr)"
check "N11b (H6) ... and the oracle agrees on that sheet too" \
  [expr {[ps_doc_parents $mpps] eq $mppar}] \
  "(doc={[ps_doc_parents $mpps]} strip={$mppar})"


# --------------------------- N21: condition B scopes the HIGHLIGHT, never the parent map ---
# The 2x2 of rows S81a-S81d, read from the other side. `pdklib/hpdk.sch` is in the excluded
# library and is NOT advertised (S81b) -- but it really does instantiate `good`, so `good.sch`
# must name it as a parent alongside `hnp.sch`. Item H4 skipped recording edges AT ALL for an
# excluded page, which was right for the highlight and would have made this page lie about
# where it is used; H6 moved the exclusion into the edge's VALUE for exactly this. If it had
# not, nothing here would have said so -- every condition-B row asks about a BORDER.
set indpar [ps_nav_parents $indps]
check "N21 (H6/RULE-1) an excluded (PDK) library scopes the HIGHLIGHT and not the structure:\
 pdklib/hpdk is not advertised (S81b) and still appears as a parent of the cell it really\
 contains, beside hnp -- good.sch names BOTH" \
  [expr {[dict exists $indpar good.sch] &&
         [dict get $indpar good.sch] eq [lsort {hnp.sch hpdk.sch}] &&
         [ind_border $indlinks hpdk.sch] eq "0"}] \
  "(good parents={[expr {[dict exists $indpar good.sch] ? [dict get $indpar good.sch] : {}}]}\
 hpdk border=|[ind_border $indlinks hpdk.sch]| $inderr)"

# ------------------------------------------------ N22: the list is emitted already SORTED ---
# Hash iteration order is arbitrary, so without the sort in hier_psprint_resolve_hier() the
# name a reader sees FIRST depends on where a cell landed in a hash table -- unstable between
# cells and between exports, which is also what every byte comparison in this batch rests on.
# ps_nav_parents sorts, so no other row here can see it.
set n22bad {}
foreach d [list $mpps $indps $oa6ps] {
  if {$d eq ""} continue
  dict for {pg pl} [ps_nav_parents_raw $d] {
    if {[llength $pl] > 1 && $pl ne [lsort $pl]} { lappend n22bad "$pg={$pl}" }
  }
}
check "N22 (H6) the parent list is emitted in SORTED order, not in hash order: on the\
 five-parent sheet, the 2x2 and tb_bandgap every multi-parent page is already sorted as it\
 comes out of psprint.c. Every other row here compares sorted maps and cannot see this" \
  [expr {[llength $n22bad] == 0}] "(unsorted={$n22bad})"

# ------------------------------------------------------------ N12/N13/N14: the knob ---
lassign [h3_arm $dir nvnone [file join $dir mptop.sch] {{set ps_hier_nav none}}] nnr nnd nnps nnerr
lassign [h3_arm $dir nvback [file join $dir mptop.sch] {{set ps_hier_nav back}}] nbr nbd nbps nberr
lassign [h3_arm $dir nvup   [file join $dir mptop.sch] {{set ps_hier_nav up}}]   nur nud nups nuerr
lassign [h3_arm $dir nvjunk [file join $dir mptop.sch] {{set ps_hier_nav sideways}}] njr njd njps njerr
proc nav_counts {ps} {
  set b 0 ; set u 0
  foreach e [ps_nav_map $ps] { incr b [lindex $e 1] ; incr u [llength [lindex $e 2]] }
  return [list $b $u]
}
lassign [nav_counts $mpps]  d_b d_u
lassign [nav_counts $nnps]  n_b n_u
lassign [nav_counts $nbps]  b_b b_u
lassign [nav_counts $nups]  u_b u_u
lassign [nav_counts $njps]  j_b j_u
check "N12 (H6/DD-4) `ps_hier_nav none` is the way back: ZERO nav annotations, and the forward\
 output is byte-identical to the default arm once the strip is removed -- the feature adds\
 links, it never moves one" \
  [expr {$n_b == 0 && $n_u == 0 &&
         [llength [pdf_nav_annots $nnd]] == 0 &&
         [ps_filter [ps_strip_nav $nnps]] eq [ps_filter [ps_strip_nav $mpps]] &&
         [llength [ps_link_dests $nnps]] == [llength [ps_link_dests $mpps]]}] \
  "(none b=$n_b u=$n_u navannots=[llength [pdf_nav_annots $nnd]]\
 fwd_identical=[expr {[ps_filter [ps_strip_nav $nnps]] eq [ps_filter [ps_strip_nav $mpps]]}] $nnerr)"
check "N13 (H6) the two halves answer different questions and each can be had alone: on a\
 7-page sheet `back` gives 7 Back buttons and no parent reference, `up` gives the 10 parent\
 references (5 sheets under mptop, and mp.sch listing all five of them) and no Back button,\
 and `both` gives both" \
  [expr {$b_b == 7 && $b_u == 0 && $u_b == 0 && $u_u == 10 && $d_b == 7 && $d_u == 10}] \
  "(both=$d_b/$d_u back=$b_b/$b_u up=$u_b/$u_u)"
check "N14 (H6) an UNRECOGNISED ps_hier_nav value takes `both`, not `none`: a typo in an\
 xschemrc means a user who ASKED for the strip and mistyped which half, and deleting the\
 navigation would hide their own request from them (H4's row S91, same rule). This is NOT\
 the shipped default, which is `none` and is row N25" \
  [expr {$j_b == 7 && $j_u == 10}] "(junk=$j_b/$j_u)"

# --------------------------------------- N25: THE SHIPPED DEFAULT IS `none`, and it is MEASURED ---
# The user ruled on 2026-09-24: this branch takes the hierarchical-export FIX (the crash, the
# lost pages, the dead and the missing /Link annotations) and ships the new VISIBLE navigation
# OFF, because its presentation -- a Back link on the top page too, an `Up:` strip on every
# page, that wording, that position -- is the crew's own and nobody outside the batch has
# looked at it. Every other row in this section SETS the variable, which is what lets the
# default be changed at all; this one is the row that says what the default IS, so the next
# person to flip it flips a red row rather than a silent one.
#
# TWO routes, because they are two different answers in hier_psprint_read_nav_mode():
#   - the variable at its shipped value (a child that sets nothing) -> `none`, from
#     src/xschem.tcl's set_ne;
#   - the variable UNSET (an xschemrc that does `unset ps_hier_nav` after xschem.tcl ran) ->
#     `none`, from the `!m || !m[0]` arm in src/spice_netlist.c. That arm used to be `both`,
#     which was the one route by which the strip could still appear on a page nobody asked
#     for it on. An UNRECOGNISED value is deliberately NOT this case -- see N14.
# This child does NOT go through h3_child, which sets `both` for every other arm.
#
# ps_strip_nav is applied to BOTH sides of the byte comparison and hides nothing: it only
# equalises the trailing newline it adds, and a strip on the default arm is already caught
# three ways over -- df_b/df_u, the `xschem hier nav` marker, and the link count.
proc n25_child {dir tag sheet pre} {
  set ps [file join $dir n25_$tag.ps]
  set f  [file join $dir n25c_$tag.tcl]
  catch {file delete $ps}
  set fd [open $f w]
  puts $fd "if {!\[info exists XSCHEM_LIBRARY_PATH\]} { set XSCHEM_LIBRARY_PATH {} }"
  puts $fd "set XSCHEM_LIBRARY_PATH \"$dir:\$XSCHEM_LIBRARY_PATH\""
  puts $fd "set noprint_libs {}"
  foreach l $pre { puts $fd $l }
  puts $fd "xschem load {$sheet}"
  puts $fd "xschem hier_psprint {$ps}"
  puts $fd "puts H3_DONE" ; puts $fd "flush stdout" ; puts $fd "exit 0"
  close $fd
  lassign [spawn_export $dir $f] rc sig out
  return [list [ps_read $ps] [expr {$rc != 0 || $sig}]]
}
lassign [n25_child $dir shipped [file join $dir mptop.sch] {}]                        dfps dferr
lassign [n25_child $dir unset   [file join $dir mptop.sch] {{unset -nocomplain ps_hier_nav}}] unps unerr
lassign [nav_counts $dfps] df_b df_u
lassign [nav_counts $unps] un_b un_u
check "N25 (H6/ruling 2026-09-24) THE SHIPPED DEFAULT IS `none`: a child that sets nothing\
 exports a 7-page hierarchy with ZERO Back buttons, ZERO parent references and no `xschem\
 hier nav` marker in the file at all -- and the forward links are untouched, byte for byte\
 the `both` arm with its strip removed. Unsetting the variable outright lands on the SAME\
 answer, which is the only other route to a strip nobody asked for" \
  [expr {!$dferr && !$unerr &&
         $df_b == 0 && $df_u == 0 && $un_b == 0 && $un_u == 0 &&
         ![regexp {xschem hier nav} $dfps] && ![regexp {xschem hier nav} $unps] &&
         [ps_filter [ps_strip_nav $dfps]] eq [ps_filter [ps_strip_nav $mpps]] &&
         [llength [ps_link_dests $dfps]] == [llength [ps_link_dests $mpps]] &&
         [llength [ps_page_dests $dfps]] == 7}] \
  "(shipped=$df_b/$df_u unset=$un_b/$un_u marker=[regexp {xschem hier nav} $dfps]/[regexp\
 {xschem hier nav} $unps] pages=[llength [ps_page_dests $dfps]]\
 fwd_identical=[expr {[ps_filter [ps_strip_nav $dfps]] eq [ps_filter [ps_strip_nav $mpps]]}]\
 links=[llength [ps_link_dests $dfps]]/[llength [ps_link_dests $mpps]] err=$dferr/$unerr)"

# ------------------------------------------------- N15: once per EXPORT, not per process ---
# This row runs IN THIS INTERPRETER, so it does not go through h3_child and does not get its
# `set ps_hier_nav both`. Run 1 used to read the variable's ambient value, which was the
# shipped default `both`; the shipped default is now `none` (the user's 2026-09-24 ruling)
# and run 1 would measure nothing. Say what run 1 needs, exactly as every spawned arm now
# does -- the row is about the variable being RE-READ, not about what it happens to hold.
set nvsave [expr {[info exists ps_hier_nav] ? $ps_hier_nav : " "}]
set noprint_libs {}
set nv1 [file join $dir nv1.ps] ; set nv2 [file join $dir nv2.ps] ; set nv3 [file join $dir nv3.ps]
set ps_hier_nav both
xschem load $greycnt
xschem hier_psprint $nv1
set ps_hier_nav none
xschem hier_psprint $nv2
set ps_hier_nav both
xschem hier_psprint $nv3
if {$nvsave eq " "} { unset -nocomplain ps_hier_nav } else { set ps_hier_nav $nvsave }
lassign [nav_counts [ps_read $nv1]] r1b r1u
lassign [nav_counts [ps_read $nv2]] r2b r2u
lassign [nav_counts [ps_read $nv3]] r3b r3u
check "N15 (H6/1346) ps_hier_nav is re-read on EVERY export, not cached for the life of the\
 process: three hier_psprint runs in ONE interpreter with the variable changed between them\
 give 2/1, 0/0 and 2/1. Every other H6 arm is a fresh spawned child and would pass a\
 once-per-process read" \
  [expr {$r1b == 2 && $r1u == 1 && $r2b == 0 && $r2u == 0 && $r3b == 2 && $r3u == 1}] \
  "(run1=$r1b/$r1u run2=$r2b/$r2u run3=$r3b/$r3u)"

# --------------------------------------- N16: a single-page print is not a hierarchy ---
# `xschem print` (ps_draw(7,...)) emits no pdfmarks at all and has no other page to go back
# to. The strip must not appear there, and the gate is the SAME one the /Link emitter uses:
# no hierarchical walk owns a destination set.
set spps [file join $dir single.ps]
xschem load $greycnt
xschem print ps $spps
set spd [ps_read $spps]
check "N16 (H6) a single-page `xschem print` gets NO nav strip: there is no other page to go\
 back to, and the gate is the same one the /Link emitter uses -- no hierarchical walk owns a\
 destination set" \
  [expr {[string length $spd] > 1000 && [lindex [nav_counts $spd] 0] == 0 &&
         [lindex [nav_counts $spd] 1] == 0 &&
         ![regexp {GoBack} $spd] && ![regexp {xschem hier nav} $spd]}] \
  "(bytes=[string length $spd] nav=[nav_counts $spd] goback=[regexp {GoBack} $spd]\
 marker=[regexp {xschem hier nav} $spd])"

# ----------------------------------- N17: the instance-level `schematic=` override route ---
# DD-6's refutation axis. topN.sch's only instance is nbase.sym overridden to good2.sch, so
# the page the reader lands on is good2 and its parent is topN -- named from the INSTANCE, not
# from the base symbol.
lassign [h3_arm $dir nvov [file join $dir topN.sch] {{set noprint_libs {{nbase\.sym}}}}] ovr ovd ovps overr
set ovpar [ps_nav_parents $ovps]
check "N17 (H6/DD-6) a page reached only through an instance-level `schematic=` override names\
 the OVERRIDING sheet as its parent: topN.sch instantiates nbase.sym overridden to good2.sch,\
 and good2's page says Up: topN.sch. Reading the BASE symbol here is the confusion that\
 refuted H1 and H1-2" \
  [expr {[dict exists $ovpar good2.sch] && [dict get $ovpar good2.sch] eq [list topN.sch] &&
         [dict exists $ovpar topN.sch] && [dict get $ovpar topN.sch] eq {}}] \
  "(map={$ovpar} $overr)"

# ------------------------------------------------------------------- N18: recursion ---
lassign [h3_arm $dir nvrec [file join $dir rectop.sch] {}] rcr rcd rcps rcerr
set rcpar [ps_nav_parents $rcps]
check "N18 (H6) TRUE RECURSION, answered in ink rather than left standing: rec.sch\
 instantiates rec.sym, so the page's own parent is itself and the strip says so. Clicking Up\
 returns the reader to the page they are on -- structurally true, and the alternative\
 (suppress self-edges) would hide a real two-library homonym" \
  [expr {[dict exists $rcpar rec.sch] &&
         [dict get $rcpar rec.sch] eq [lsort {rec.sch rectop.sch}]}] \
  "(map={$rcpar} $rcerr)"

# ---------------------------------------------------------------- N19: the wide list ---
lassign [h3_arm $dir nvwide [file join $dir wtop.sch] {}] wr wd wps werr
set wmap [ps_nav_map $wps]
set wleafrects {} ; set wleafpar {}
foreach e $wmap {
  if {[lindex $e 0] eq "wleaf.sch"} { set wleafrects [lindex $e 3] ; set wleafpar [lindex $e 2] }
}
set wover 0
foreach r $wleafrects { if {[lindex $r 2] > 832.0} { incr wover } }
## the `+N` must be the dropped COUNT, printed inside the strip -- not any `+` in the file
## (issue 1342's `1e+39` would satisfy a bare regexp, and the first draft of this row used one)
set wplus ""
foreach b [ps_nav_blocks_of $wps wleaf.sch] {
  if {[regexp {MT \(\+([0-9]+)\) show} $b . n]} { set wplus $n }
}
check "N19 (H6) EIGHT parents at 44 characters each is 1480 pt of Courier 7 against 802 pt of\
 usable page: the strip stops at the right margin, emits no annotation past it, and the\
 parents it did not draw are not silently dropped -- the count is printed" \
  [expr {[llength $wleafpar] > 0 && [llength $wleafpar] < 8 && $wover == 0 &&
         $wplus ne "" && $wplus == 8 - [llength $wleafpar]}] \
  "(drawn=[llength $wleafpar] of 8 rects=[llength $wleafrects] past_margin=$wover\
 plus=|$wplus| $werr)"

# ------------------------------------------- N24: WHERE THE STRIP'S INK ENDS ---------------
# THE CLASS OF ROW THIS SUITE DID NOT HAVE, and its absence let a defect ship. Every other
# geometry row here reads `/Rect`: N5, N6, N7 and N19 all ask where the ANNOTATIONS are. The
# `+N` truncation count is drawn text with no annotation at all, so no rect exists for it and
# nothing could see it. It was emitted at whatever x the parent loop happened to stop at, with
# no right-margin test of its own -- every NAME was bounded and the COUNT was not -- so on a
# page whose last drawn parent ends just short of the margin the count ran past the page edge
# and was CLIPPED by the media box: `+20` rendered as `+2`, a readable, believable, WRONG
# statement about how many parents were hidden. Worse than printing nothing.
#
# This row asks the other question: for every `show` inside a nav strip, on every page of every
# nav-bearing export this suite produces, does the INK stay on the page? Courier is a fixed
# 4.2 pt per glyph at 7 pt, and glyphs are counted the way ps_string_body() writes them --
# `\ddd`, `\(`, `\)` and `\\` are ONE glyph each, which is the same correction row N20 makes
# for the hotspot width.
proc ps_nav_glyphs {str} {
  set n 0
  for {set i 0} {$i < [string length $str]} {incr i} {
    if {[string index $str $i] eq "\\"} {
      set nxt [string index $str [expr {$i+1}]]
      if {[string is digit -strict $nxt]} { incr i 3 } else { incr i 1 }
    }
    incr n
  }
  return $n
}
## every piece of INK in a nav strip, as {page x_end pagex text}
proc ps_nav_ink_violations {d} {
  set out {} ; set px 0.0 ; set innav 0 ; set pg 0
  foreach line [split $d "\n"] {
    if {[regexp {^<< /PageSize \[(\S+) (\S+)\]} $line . a b]} { set px $a ; incr pg ; continue }
    if {[string match "% xschem hier nav begin*" $line]} { set innav 1 ; continue }
    if {[string match "% xschem hier nav end*" $line]}   { set innav 0 ; continue }
    if {!$innav} continue
    if {[regexp {^NP (\S+) (\S+) MT \((.*)\) show$} $line . x y txt]} {
      if {$px <= 0.0} { lappend out "page$pg:no PageSize" ; continue }
      set xend [expr {$x + 4.2 * [ps_nav_glyphs $txt]}]
      if {$xend > $px} { lappend out "page$pg:ink ($txt) ends $xend > pagex $px" }
    }
  }
  return $out
}
lassign [h3_arm $dir nvink [file join $dir inktop.sch] {}] ikr ikd ikps ikerr
## the tuned fixture must actually REACH the truncation, or this row proves nothing
set ikplus ""
foreach b [ps_nav_blocks_of $ikps inkc.sch] {
  if {[regexp {MT \(\+([0-9]+)\) show} $b . n]} { set ikplus $n }
}
set ikink {}
## every nav-bearing export this suite has produced BY THIS POINT -- `tlps` (the portrait
## fixture) is assigned later, in N7's block, and is swept there instead of being forward-
## referenced. A missing variable used to take this script down with a Tcl error that reads
## like a harness bug rather than the row it is.
foreach v {ikps nvps mpps indps oa6ps wps} {
  if {![info exists $v]} continue
  set f [set $v]
  if {$f eq ""} continue
  foreach z [ps_nav_ink_violations $f] { lappend ikink $z }
}
check "N24 (H6) the strip's INK stays on the page, not just its rects -- the `+N` truncation\
 count has no annotation, so every rect-based row here is blind to it, and it used to be\
 clipped by the media box and report +20 as +2" \
  [expr {$ikplus ne "" && $ikplus > 0 && [llength $ikink] == 0}] \
  "(fixture truncated with plus=|$ikplus| ink_violations=[llength $ikink] {$ikink} $ikerr)"

# ------------------------------------------- N20: the rect is sized in GLYPHS, not bytes ---
# The parent named on mp.sch's page is `escép.sch`: 10 bytes on disk, 12 bytes in the
# PostScript literal, NINE glyphs of Courier. Only the glyph count gives a rect that matches
# the ink, and only ps_string_body() itself can count it without a second copy of the
# escaping rule (DD-2).
lassign [h3_arm $dir nvesc [file join $dir esctop.sch] {}] er ed eps eerr
set emap [ps_nav_map $eps]
set erect {}
foreach e $emap { if {[lindex $e 0] eq "mp.sch"} { set erect [lindex $e 3] } }
set ewidth ""
if {[llength $erect] == 2} {
  set rr [lindex $erect 1]
  set ewidth [expr {[lindex $rr 2] - [lindex $rr 0]}]
}
check "N20 (H6/1350) the parent hotspot is sized in GLYPHS, not in escaped bytes: the parent\
 name is 9 glyphs and 12 bytes in its PostScript literal, so its rect is 9 x 4.2 = 37.8 pt\
 wide -- a rect sized from the literal would be 50.4 pt and would slide under the next name" \
  [expr {$ewidth ne "" && abs($ewidth - 37.8) < 0.05}] \
  "(width=$ewidth want=37.8 rects=[llength $erect] $eerr)"


# ------------------------------- N23: a ONE-PAGE export gets no strip, and that is 2/3 of the tree ---
# `xschem hier_psprint` on a schematic with no printable children produces ONE page. There is
# nothing to go back to and nothing above it, so a Back button there is ink that can never do
# anything. **216 of the 321 sheets in this tree are single-page**, so a strip that did not ask
# would have put a dead button on two thirds of every export anyone runs -- and the first draft
# of this item did exactly that, with every H6 row green, because every fixture in this suite is
# hierarchical. That is this batch's signature failure (a control that cannot see the defect it
# is named for) and it is fenced here rather than found later.
wsym [file join $dir solo.sym] "type=subcircuit\ntemplate=\"name=x1\""
wsch [file join $dir solotop.sch] solo   ;# no instances at all -> exactly one page
lassign [h3_arm $dir nvsolo [file join $dir solotop.sch] {}] slr sld slps slerr
lassign [nav_counts $slps] sl_b sl_u
check "N23 (H6) a ONE-PAGE hierarchical export gets NO strip at all: no Back button with\
 nowhere to go, no marker, no annotation -- and therefore a one-page export is byte-identical\
 to the pre-H6 binary. 216 of this tree's 321 sheets are one page" \
  [expr {[llength [ps_page_dests $slps]] == 1 && $sl_b == 0 && $sl_u == 0 &&
         ![regexp {xschem hier nav} $slps] && [llength [pdf_nav_annots $sld]] == 0}] \
  "(pages=[llength [ps_page_dests $slps]] nav=$sl_b/$sl_u marker=[regexp {xschem hier nav} $slps]\
 pdfnav=[llength [pdf_nav_annots $sld]] $slerr)"

# ------------------------------- N7: the band, per page, and the portrait case ---
# N7 reads the POSTSCRIPT, not the PDF, and that is the one place in this suite where the .ps
# is the stronger artifact rather than the weaker one. The claim is about `create_ps()`'s own
# page geometry -- the strip sits above `pagey - margin`, where the translate two lines below
# it puts the top of the drawing -- and a page's size is stated per page in its
# `setpagedevice`, while a PDF states a MediaBox per page that a flat regex cannot pair with
# an annotation. The nav rects are emitted OUTSIDE the page CTM, so these are the same numbers
# that reach the PDF; N5 and N6 check the distilled side.
proc ps_nav_band_violations {d} {
  set out {} ; set px 0.0 ; set py 0.0 ; set innav 0 ; set pg 0
  foreach line [split $d "\n"] {
    if {[regexp {^<< /PageSize \[(\S+) (\S+)\]} $line . a b]} {
      set px $a ; set py $b ; incr pg ; continue
    }
    if {[string match "% xschem hier nav begin*" $line]} { set innav 1 ; continue }
    if {[string match "% xschem hier nav end*" $line]}   { set innav 0 ; continue }
    if {!$innav} continue
    if {[regexp {^\[ /Rect \[ (\S+) (\S+) (\S+) (\S+) \]} $line . x1 y1 x2 y2]} {
      if {$py <= 0.0} { lappend out "page$pg:no PageSize" ; continue }
      if {!($x1 < $x2 && $y1 < $y2)} { lappend out "page$pg:notnorm {$x1 $y1 $x2 $y2}" }
      if {$y1 < $py - 10.0} { lappend out "page$pg:band y1=$y1 pagey=$py" }
      if {$x2 > $px - 10.0} { lappend out "page$pg:right x2=$x2 pagex=$px" }
    }
  }
  return $out
}
lassign [h3_arm $dir nvtall [file join $dir talltop.sch] {}] tlr tld tlps tlerr
## N24's ink sweep, for the one export that did not exist when N24 ran
foreach z [ps_nav_ink_violations $tlps] { lappend ikink $z }
check "N24b (H6) and the strip's ink stays on the PORTRAIT page too -- orientation is decided\
 per page, so a row that only ever saw landscape would miss a narrower right margin" \
  [expr {[llength $ikink] == 0}] "(ink_violations={$ikink} $tlerr)"
set nvband {} ; set nvbandn 0 ; set nvpsz {}
foreach f [list $nvps $mpps $indps $oa6ps $tlps $wps] {
  if {$f eq ""} continue
  incr nvbandn [regexp -all {/F 4 } $f]
  foreach z [ps_nav_band_violations $f] { lappend nvband $z }
  foreach {m a b} [regexp -all -inline {(?n)^<< /PageSize \[(\S+) (\S+)\]} $f] { lappend nvpsz "${a}x$b" }
}
check "N7 (H6) ... and the reason it CAN never overlap, asserted per page against that page's\
 own PageSize: every nav rect sits above pagey-margin, where create_ps()'s translate puts the\
 top of the drawing at the highest, and inside pagex-margin. The fixtures include a PORTRAIT\
 sheet, because orientation is decided per page and a landscape-only corpus cannot see a\
 placement computed from the wrong dimension" \
  [expr {$nvbandn > 0 && [llength $nvband] == 0 &&
         [llength [lsearch -all -inline -exact [lsort -unique $nvpsz] 595x842]] == 1}] \
  "(nav rects=$nvbandn violations={[lrange $nvband 0 3]} pagesizes={[lsort -unique $nvpsz]})"

# A red 1333 row leaves an emergency-save directory behind; sweep only the ones this suite's own
# schematic names can produce.
foreach pat {h1notype intuitive_interface_cheatsheet} {
  foreach d [glob -nocomplain /tmp/xschem_emergencysave_${pat}_*] { catch {file delete -force $d} }
}

## ⚠ THIS SUITE PRINTS BOTH BANNERS, AND IT MUST.
# `tests/headless/run_suites.sh` scores a headless suite from its `^RESULT` line;
# `tests/run_regression.tcl` (T1) scores it through `regression_case_failed` in
# tests/banner_rule.tcl, which requires a WHOLE-LINE `OVERALL: ok` and knows nothing about
# `RESULT:`. This suite printed only the first, so registering it in T1's `hcases` as it
# stood would have appended `HARNESS: ... did not complete cleanly` and counted a failure in
# the one file whose baseline is ZERO, with every one of its own checks passing -- issue
# 0689's false red arriving from the other side, exactly as it did for
# test_untitled_autosave_1486. The parenthesised check count is the shape banner_complete
# tolerates, and it is what T1's verdict carries as this case's coverage figure (issue 1487),
# so a suite that silently loses rows is visible in the verdict instead of reading as a pass.
if {$fail == 0} {
  puts "RESULT: ALL PASS ($pass checks)"
  puts "OVERALL: ok ($pass checks)"
} else {
  puts "RESULT: $fail FAILED ($pass passed)"
  puts "OVERALL: notok"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
