# doc/claude/specs/text_view_type.md — `text` is a view TYPE.
#
# A cell's documentation is a view: it appears in the Library Manager's view
# list beside `schematic`, and opening it hands the file to a text editor.
#
# LIKE §B's verilog work, this is also a DATA-LOSS regression. Before the table
# row existed:
#     view_type_of_ext .md   -> data
#     view_type_opener data  -> editor   (i.e. `xschem load`)
# and `xschem load` on a Markdown file does not fail — it skips every line and
# leaves an EMPTY schematic whose schname is the .md, marked unmodified, so the
# next save writes an empty .sch over the documentation. TH1/TH2 are the checks
# that close that hole; the rest keep the model consistent around it, and TL1-3
# are the negatives that say the change stayed inside its lane (the `data`
# catch-all still opens in the editor, and `text` is NOT in the Alt-2 ring).
#
# Run headless from the repo root:
#   ./src/xschem --nogui --pipe -q --script tests/headless/test_text_view_model.tcl

source [file join [file dirname [info script]] scratch.tcl]

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}
proc eqcheck {name got want} {
  check $name [expr {$got eq $want}] "(got '$got' want '$want')"
}

set tmp [test_scratch textview]
proc wr {path body} {
  file mkdir [file dirname $path]
  set fp [open $path w]; puts -nonewline $fp $body; close $fp
}
proc emptysch {path} {
  wr $path "v \{xschem version=3.4.8 file_version=1.3\}\nG \{\}\nK \{\}\nV \{\}\nS \{\}\nE \{\}\n"
}
proc emptysym {path} {
  wr $path "v \{xschem version=3.4.8 file_version=1.3\}\nG \{\}\nK \{\}\nV \{\}\nS \{\}\nE \{\}\nB 5 -72.5 -2.5 -67.5 2.5 \{name=a dir=in\}\n"
}

# ===========================================================================
# fixture
# ===========================================================================
# tlib/doc'd  — schematic + symbol + a README view (the SANDBOX cell's shape:
#               the view DIRECTORY is named README, the datafile <cell>.md)
emptysym $tmp/tlib/docd/symbol/docd.sym
emptysch $tmp/tlib/docd/schematic/docd.sch
wr $tmp/tlib/docd/README/docd.md "# docd\n\nprose.\n"
# tlib/canon  — the view directory named `text`, which is what
#               cellview_resolve_typed (and therefore lib_qualified_abs) needs
emptysym $tmp/tlib/canon/symbol/canon.sym
wr $tmp/tlib/canon/text/canon.md "# canon\n"
# tlib/plain  — no text view at all (nothing may materialize out of thin air)
emptysym $tmp/tlib/plain/symbol/plain.sym
emptysch $tmp/tlib/plain/schematic/plain.sch
# tlib/txt    — the .txt alias extension
emptysym $tmp/tlib/txt/symbol/txt.sym
wr $tmp/tlib/txt/notes/txt.txt "plain text\n"
# tlib/newcell — target for library_new_view
emptysym $tmp/tlib/newcell/symbol/newcell.sym
emptysch $tmp/tlib/newcell/schematic/newcell.sch
# flib — LEGACY FLAT layout, a loose <cell>.md beside the symbol
emptysym $tmp/flib/loose.sym
emptysch $tmp/flib/loose.sch
wr $tmp/flib/loose.md "# loose\n"

set defs [file join $tmp library.defs]
wr $defs "DEFINE tlib $tmp/tlib\nDEFINE flib $tmp/flib\n"
set ::XSCHEM_LIBRARY_DEFS $defs

check "TT0 fixture libraries registered" \
  [expr {[library_resolve tlib] ne {} && [library_resolve flib] ne {}}] \
  "(=> [library_resolve tlib] / [library_resolve flib])"

# ===========================================================================
# the shared table
# ===========================================================================
eqcheck "TT1 .md       -> text" [view_type_of_ext .md]       text
eqcheck "TT2 .txt      -> text" [view_type_of_ext .txt]      text
eqcheck "TT3 .markdown -> text" [view_type_of_ext .markdown] text
eqcheck "TT4 .text     -> text" [view_type_of_ext .text]     text
eqcheck "TT5 case-insensitive"  [view_type_of_ext .MD]       text
eqcheck "TT6 type -> exts, canonical first" [view_exts_of_type text] {.md .txt}
eqcheck "TT7 type -> canonical ext"         [view_ext_of_type text]  .md
eqcheck "TT8 opener: prose is TEXT, never the canvas" [view_type_opener text] text
eqcheck "TT9 default view name for the type" [view_default_name text] text
# the four rows that were already there must not have moved
eqcheck "TT10 schematic/symbol/verilog/state untouched" \
  [list [view_type_of_ext .sch] [view_type_of_ext .sym] \
        [view_type_of_ext .v]   [view_type_of_ext .state]] \
  {schematic symbol verilog state}

# ===========================================================================
# TL — the negatives: the change stayed inside its lane
# ===========================================================================
eqcheck "TL1 an unnamed extension is still data"      [view_type_of_ext .gds] data
eqcheck "TL2 data still opens in the EDITOR"          [view_type_opener data] editor
check   "TL3 text is NOT in the Alt-2 toggle ring" \
  [expr {[lsearch -exact [alt2::toggle_types] text] < 0}] \
  "(ring = [alt2::toggle_types])"

# ===========================================================================
# TH — handler dispatch (the data-loss hole)
# ===========================================================================
set mdpath $tmp/tlib/docd/README/docd.md
eqcheck "TH1 .md datafile -> the text handler, NOT editor" \
  [libmgr::view_handler README $mdpath] libmgr::open_text_view
eqcheck "TH2 .txt datafile -> the text handler" \
  [libmgr::view_handler notes $tmp/tlib/txt/notes/txt.txt] libmgr::open_text_view
eqcheck "TH3 no datafile: the view NAME decides" \
  [libmgr::view_handler text] libmgr::open_text_view
# extension beats the name, in BOTH directions (the view_handler doctrine)
eqcheck "TH4 a view named README holding a .sch still opens in the editor" \
  [libmgr::view_handler README $tmp/tlib/docd/schematic/docd.sch] editor
eqcheck "TH5 a view named schematic holding a .md does NOT reach xschem load" \
  [libmgr::view_handler schematic $mdpath] libmgr::open_text_view

# ===========================================================================
# TE — enumeration and resolution
# ===========================================================================
eqcheck "TE1 the README view is enumerated" \
  [lsort [cell_views tlib docd]] {README schematic symbol}
eqcheck "TE2 cellview_path resolves it" \
  [cellview_path tlib/docd README] [file normalize $mdpath]
eqcheck "TE3 copyform types it by its datafile" [copyform::view_type tlib docd README] text
eqcheck "TE4 and types a .txt view the same way" [copyform::view_type tlib txt notes] text
eqcheck "TE5 a cell with no text view types as nothing" \
  [copyform::view_type tlib plain README] {}
# lib_qualified_abs: a `lib/cell.md` reference must not hand back the SYMBOL
eqcheck "TE6 lib/cell.md -> the text view" \
  [lib_qualified_abs tlib/canon.md] [file normalize $tmp/tlib/canon/text/canon.md]
eqcheck "TE7 flat layout: the loose <cell>.md is found" \
  [lib_qualified_abs flib/loose.md] [file normalize $tmp/flib/loose.md]
eqcheck "TE8 a bare lib/cell still means the SYMBOL" \
  [lib_qualified_abs tlib/canon] [file normalize $tmp/tlib/canon/symbol/canon.sym]
eqcheck "TE9 lib/cell.sch still means the schematic" \
  [lib_qualified_abs tlib/docd.sch] [file normalize $tmp/tlib/docd/schematic/docd.sch]

# ===========================================================================
# TN — creating one
# ===========================================================================
check "TN1 library_new_view text succeeds" \
  [expr {![catch {library_new_view tlib newcell README text} e]}] "($e)"
set newf $tmp/tlib/newcell/README/newcell.md
check "TN2 it wrote <cell>.md, not a .sch" \
  [expr {[file isfile $newf] && ![file exists $tmp/tlib/newcell/README/newcell.sch]}] \
  "(md=[file isfile $newf])"
set seed {}
catch {set seed [read_data $newf]}
check "TN3 the seed carries the cell heading" \
  [expr {[string first "# newcell" $seed] == 0}] "([string range $seed 0 40])"
check "TN4 the seed lists the cell's OTHER views" \
  [expr {[string first "schematic" $seed] >= 0 && [string first "symbol" $seed] >= 0}] ""
eqcheck "TN5 the new view enumerates and types as text" \
  [copyform::view_type tlib newcell README] text
check "TN6 creating it twice is an error, not an overwrite" \
  [catch {library_new_view tlib newcell README text}] 1

# ===========================================================================
# TA — Alt-2 must not offer prose as a toggle target
# ===========================================================================
set cands [alt2::target_candidates $tmp/tlib/docd/schematic/docd.sch]
set types {}
foreach c $cands { lappend types [lindex $c 2] }
check "TA1 Alt-2 from the schematic offers symbol, not the README" \
  [expr {[lsearch -exact $types symbol] >= 0 && [lsearch -exact $types text] < 0}] \
  "(types = $types)"

# ===========================================================================
# TR — the first real user, if this tree has it
# ===========================================================================
set repo [file normalize [file join [file dirname [info script]] .. ..]]
set sandbox [file join $repo xschem_libs_newsym]
if {[file isfile [file join $sandbox library.defs]]} {
  set ::XSCHEM_LIBRARY_DEFS [file join $sandbox library.defs]
  set ::library_registry_defs_only 1
  eqcheck "TR1 the testbench's README view is in its view list" \
    [lsort [cell_views SANDBOX tb_counter_wrapper]] \
    {README ngspice_state1 schematic symbol}
  eqcheck "TR2 it types as text" [copyform::view_type SANDBOX tb_counter_wrapper README] text
  set p [cellview_path SANDBOX/tb_counter_wrapper README]
  eqcheck "TR3 its datafile is <cell>.md" [file tail $p] tb_counter_wrapper.md
  eqcheck "TR4 opening it goes to the text handler" \
    [libmgr::view_handler README $p] libmgr::open_text_view
} else {
  puts "note: TR1-4 not run -- xschem_libs_newsym/library.defs absent"
}

if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
