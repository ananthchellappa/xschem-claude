# §B of doc/claude/specs/mixed_signal_signal_browser.md — `verilog` and
# `veriloga` are view TYPES.
#
# THIS IS A DATA-LOSS REGRESSION, not a feature test. Before §B:
#     copyform::view_type  <verilog view>  -> data
#     libmgr::view_handler <.v>            -> editor   (i.e. `xschem load`)
#     lib_qualified_abs    lib/cell.v      -> the SYMBOL view
# and `xschem load` on a .v does not fail: it skips every line and leaves an
# EMPTY schematic whose schname is the Verilog source, marked unmodified — so
# the next save writes an empty .sch over the source file. The check that
# closes that hole is VH1/VH2 below (view_handler must never say `editor` for
# a source file); everything else keeps the type model consistent around it.
#
# Covers B1 view_type, B2 library_new_view, B4 seed template, B5 view_handler,
# B6 lib_qualified_abs, B7 alt2 candidates, B8 cellview_sibling_path — over
# verilog AND veriloga views, in BOTH the nested lib/cell/view layout and the
# legacy flat layout.
#
# Run headless from the repo root:
#   ./src/xschem --nogui --pipe -q --script tests/headless/test_verilog_view_model.tcl

source [file join [file dirname [info script]] scratch.tcl]

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}
proc eqcheck {name got want} {
  check $name [expr {$got eq $want}] "(got '$got' want '$want')"
}

# ===========================================================================
# fixture: one nested library (vlib) + one legacy flat library (flib)
# ===========================================================================
# test_scratch owns the directory's lifetime (issue 0148).
set tmp [test_scratch verilogview]

proc wr {path body} {
  file mkdir [file dirname $path]
  set fp [open $path w]; puts -nonewline $fp $body; close $fp
}
# a minimal but REAL symbol: the seed template reads these B records
proc symfile {path pins} {
  set body "v \{xschem version=3.4.8 file_version=1.3\}\nG \{\}\nK \{\}\nV \{\}\nS \{\}\nE \{\}\n"
  set y 0
  foreach p $pins {
    lassign $p pname pdir
    append body [format "B 5 %g %g %g %g \{name=%s dir=%s\}\n" \
                        -72.5 [expr {$y-2.5}] -67.5 [expr {$y+2.5}] $pname $pdir]
    incr y 20
  }
  wr $path $body
}

# vlib/counter — symbol + verilog views (the reference cell's shape)
symfile $tmp/vlib/counter/symbol/counter.sym {{count\[3..0\] out} {clk in} {en in} {bus\[1..0\] inout}}
wr $tmp/vlib/counter/verilog/counter.v "module counter(clk); endmodule\n"
# vlib/amp — symbol + veriloga views
symfile $tmp/vlib/amp/symbol/amp.sym {{vin in} {vout out}}
wr $tmp/vlib/amp/veriloga/amp.va "module amp(vin, vout); endmodule\n"
# vlib/sv — a .sv datafile, and vlib/vams — a .vams datafile (alias extensions)
symfile $tmp/vlib/sv/symbol/sv.sym {{a in}}
wr $tmp/vlib/sv/verilog/sv.sv "module sv(); endmodule\n"
wr $tmp/vlib/vams/veriloga/vams.vams "module vams(); endmodule\n"
# vlib/plain — the classic pair, plus a state view (must stay untouched)
symfile $tmp/vlib/plain/symbol/plain.sym {{p in}}
wr $tmp/vlib/plain/schematic/plain.sch "v \{xschem version=3.4.8 file_version=1.3\}\nG \{\}\nK \{\}\nV \{\}\nS \{\}\nE \{\}\n"
wr $tmp/vlib/plain/ngspice_state1/plain.state "state 1\n"
# vlib/nosym — a verilog view with NO symbol view (seed has no ports to read)
wr $tmp/vlib/nosym/verilog/nosym.v "module nosym(); endmodule\n"
# vlib/mixed — all three toggle-able types at once (Alt-2 ordering)
symfile $tmp/vlib/mixed/symbol/mixed.sym {{m in}}
wr $tmp/vlib/mixed/schematic/mixed.sch "v \{xschem version=3.4.8 file_version=1.3\}\nG \{\}\nK \{\}\nV \{\}\nS \{\}\nE \{\}\n"
wr $tmp/vlib/mixed/verilog/mixed.v "module mixed(m); endmodule\n"

# flib — LEGACY FLAT layout: <cell>.sym / <cell>.sch / <cell>.v side by side,
# which is upstream's own convention (a loose counter.v next to its symbol).
symfile $tmp/flib/loose.sym {{clk in} {q out}}
wr $tmp/flib/loose.sch "v \{xschem version=3.4.8 file_version=1.3\}\nG \{\}\nK \{\}\nV \{\}\nS \{\}\nE \{\}\n"
wr $tmp/flib/loose.v "module loose(clk, q); endmodule\n"
symfile $tmp/flib/aonly.sym {{a in}}
wr $tmp/flib/aonly.va "module aonly(a); endmodule\n"

set defs [file join $tmp library.defs]
wr $defs "DEFINE vlib $tmp/vlib\nDEFINE flib $tmp/flib\n"
set ::XSCHEM_LIBRARY_DEFS $defs

check "VM0 fixture libraries registered" \
  [expr {[library_resolve vlib] ne {} && [library_resolve flib] ne {}}] \
  "(=> [library_resolve vlib] / [library_resolve flib])"

# ===========================================================================
# the shared table itself
# ===========================================================================
eqcheck "VT1 .v   -> verilog"    [view_type_of_ext .v]     verilog
eqcheck "VT2 .sv  -> verilog"    [view_type_of_ext .sv]    verilog
eqcheck "VT3 .va  -> veriloga"   [view_type_of_ext .va]    veriloga
eqcheck "VT4 .vams-> veriloga"   [view_type_of_ext .vams]  veriloga
eqcheck "VT5 .sch -> schematic"  [view_type_of_ext .sch]   schematic
eqcheck "VT6 .sym -> symbol"     [view_type_of_ext .sym]   symbol
eqcheck "VT7 .state -> state"    [view_type_of_ext .state] state
eqcheck "VT8 unknown -> data"    [view_type_of_ext .gds]   data
eqcheck "VT9 extension match is case-insensitive" [view_type_of_ext .V] verilog
eqcheck "VT10 type -> canonical ext" \
  [list [view_ext_of_type verilog] [view_ext_of_type veriloga] \
        [view_ext_of_type schematic] [view_ext_of_type symbol] \
        [view_ext_of_type ngspice_state1]] {.v .va .sch .sym .state}
eqcheck "VT11 unknown type has no ext" [view_ext_of_type gds] {}
eqcheck "VT12 opener: source code is TEXT, never the canvas" \
  [list [view_type_opener verilog] [view_type_opener veriloga]] {text text}
eqcheck "VT13 opener: canvas types unchanged" \
  [list [view_type_opener schematic] [view_type_opener symbol] [view_type_opener data]] \
  {editor editor editor}
eqcheck "VT14 opener: state still ASE" \
  [list [view_type_opener state] [view_type_opener ngspice_state1]] {ase ase}

# ===========================================================================
# B1 — copyform::view_type over the real fixture views
# ===========================================================================
eqcheck "B1a verilog view types as verilog"   [copyform::view_type vlib counter verilog]  verilog
eqcheck "B1b veriloga view types as veriloga" [copyform::view_type vlib amp veriloga]     veriloga
eqcheck "B1c .sv datafile types as verilog"   [copyform::view_type vlib sv verilog]       verilog
eqcheck "B1d .vams datafile types as veriloga" [copyform::view_type vlib vams veriloga]   veriloga
eqcheck "B1e symbol still symbol"             [copyform::view_type vlib plain symbol]     symbol
eqcheck "B1f schematic still schematic"       [copyform::view_type vlib plain schematic]  schematic
eqcheck "B1g state still state"               [copyform::view_type vlib plain ngspice_state1] state
eqcheck "B1h flat layout symbol still types"  [copyform::view_type flib loose symbol]     symbol
# the type also flows into copyform's filter language for free
eqcheck "B1i type:verilog selects the verilog view" \
  [copyform::match_views vlib counter filter {} "type:verilog"] {verilog}

# ===========================================================================
# B5 — routing. THE hunk that closes the data-loss hole.
# ===========================================================================
set VP [xschem cellview_path vlib/counter verilog]
eqcheck "VH0 the verilog view resolves to the .v" $VP $tmp/vlib/counter/verilog/counter.v
check "VH1 a .v NEVER routes to the schematic loader" \
  [expr {[libmgr::view_handler verilog $VP] ne {editor}}] \
  "(=> [libmgr::view_handler verilog $VP])"
eqcheck "VH2 a .v routes to the text handler" \
  [libmgr::view_handler verilog $VP] libmgr::open_text_view
eqcheck "VH3 a .va routes to the text handler" \
  [libmgr::view_handler veriloga [xschem cellview_path vlib/amp veriloga]] libmgr::open_text_view
eqcheck "VH4 a .sv routes to the text handler" \
  [libmgr::view_handler verilog [xschem cellview_path vlib/sv verilog]] libmgr::open_text_view
eqcheck "VH5 a .vams routes to the text handler" \
  [libmgr::view_handler veriloga [xschem cellview_path vlib/vams veriloga]] libmgr::open_text_view
# the extension stays authoritative in BOTH mismatch directions
eqcheck "VH6 view named verilog holding a .sch still opens in the editor" \
  [libmgr::view_handler verilog /x/c/verilog/c.sch] editor
eqcheck "VH7 view named schematic holding a .v does NOT open in the editor" \
  [libmgr::view_handler schematic /x/c/schematic/c.v] libmgr::open_text_view
# name-only fallback (no datafile resolved)
eqcheck "VH8 name-only: verilog -> text"  [libmgr::view_handler verilog]  libmgr::open_text_view
eqcheck "VH9 name-only: veriloga -> text" [libmgr::view_handler veriloga] libmgr::open_text_view
eqcheck "VH10 name-only: schematic/symbol unchanged" \
  [list [libmgr::view_handler schematic] [libmgr::view_handler symbol]] {editor editor}
eqcheck "VH11 name-only: ngspice_state1 unchanged" \
  [libmgr::view_handler ngspice_state1] ase::open_state
eqcheck "VH12 .state unchanged" [libmgr::view_handler mystate /x/c/mystate/c.state] ase::open_state
check "VH13 the text handler exists and is callable" \
  [expr {[llength [info procs ::libmgr::open_text_view]] == 1}] {}

# --- the two Library Manager open paths, driven for real -------------------
# Both must reach edit_file and neither may reach `xschem load`. Stubbing
# current_view (the widget read) and edit_file (the external process) is enough
# to run them headless; libmgr::status is already catch-wrapped.
proc libmgr::current_view {} { return $::STUB_LCV }
rename edit_file __real_edit_file
proc edit_file {f} { lappend ::EDITED $f; return {} }
set ::STUB_LCV [list vlib counter verilog]
set ::EDITED {}
set schname_before [xschem get schname]
set rc [libmgr::open_view]
eqcheck "VH14 open_view on a verilog view hands the .v to the text editor" \
  [list $rc $::EDITED] [list 1 [list $VP]]
eqcheck "VH14a ...and the current schematic was NOT replaced by the .v" \
  [xschem get schname] $schname_before
set ::EDITED {}
libmgr::open_view_ro
eqcheck "VH15 open_view_ro dispatches the resolved handler, not ase::open_state" \
  $::EDITED [list $VP]
# and the ASE arm still works through the same generic dispatch
set ::STUB_LCV [list vlib plain ngspice_state1]
set ::EDITED {}
libmgr::open_view
eqcheck "VH16 a .state view still reaches ase::open_state, never edit_file" \
  [list [libmgr::view_handler ngspice_state1 [xschem cellview_path vlib/plain ngspice_state1]] \
        $::EDITED] {ase::open_state {}}
rename edit_file {}
rename __real_edit_file edit_file

# ===========================================================================
# B6 — reference resolution
# ===========================================================================
eqcheck "B6a lib/cell.v -> the VERILOG view (was: the symbol)" \
  [lib_qualified_abs vlib/counter.v] $tmp/vlib/counter/verilog/counter.v
eqcheck "B6b lib/cell.va -> the VERILOGA view" \
  [lib_qualified_abs vlib/amp.va] $tmp/vlib/amp/veriloga/amp.va
eqcheck "B6c bare lib/cell still -> the symbol view" \
  [lib_qualified_abs vlib/counter] $tmp/vlib/counter/symbol/counter.sym
eqcheck "B6d lib/cell.sym still -> the symbol view" \
  [lib_qualified_abs vlib/counter.sym] $tmp/vlib/counter/symbol/counter.sym
eqcheck "B6e lib/cell.sch still -> the schematic view" \
  [lib_qualified_abs vlib/plain.sch] $tmp/vlib/plain/schematic/plain.sch
eqcheck "B6f FLAT layout: lib/cell.v -> the loose .v, not the .sym" \
  [lib_qualified_abs flib/loose.v] $tmp/flib/loose.v
eqcheck "B6g FLAT layout: lib/cell.va -> the loose .va" \
  [lib_qualified_abs flib/aonly.va] $tmp/flib/aonly.va
eqcheck "B6h FLAT layout: bare lib/cell still -> the .sym" \
  [lib_qualified_abs flib/loose] $tmp/flib/loose.sym
eqcheck "B6i a .v reference to a cell with no verilog view resolves to nothing" \
  [lib_qualified_abs vlib/plain.v] {}
# abs_sym_path rule 2 is the real consumer
eqcheck "B6j abs_sym_path lib/cell.v -> the .v" \
  [abs_sym_path vlib/counter.v] $tmp/vlib/counter/verilog/counter.v

# ===========================================================================
# B8 — "this cell's <view> view", self-referential (no library name hardcoded)
# ===========================================================================
set CV $tmp/vlib/counter/verilog/counter.v
eqcheck "B8a from a lib-qualified ref"   [cellview_sibling_path vlib/counter verilog]     $CV
eqcheck "B8b from a lib/cell.sym ref"    [cellview_sibling_path vlib/counter.sym verilog] $CV
eqcheck "B8c from an absolute .sym path" \
  [cellview_sibling_path $tmp/vlib/counter/symbol/counter.sym verilog] $CV
eqcheck "B8d veriloga sibling"           [cellview_sibling_path vlib/amp veriloga] $tmp/vlib/amp/veriloga/amp.va
eqcheck "B8e .sv datafile found under the verilog type" \
  [cellview_sibling_path vlib/sv verilog] $tmp/vlib/sv/verilog/sv.sv
eqcheck "B8f FLAT layout: loose .v beside the symbol" \
  [cellview_sibling_path flib/loose verilog] $tmp/flib/loose.v
eqcheck "B8g FLAT layout via an absolute .sym path" \
  [cellview_sibling_path $tmp/flib/loose.sym verilog] $tmp/flib/loose.v
eqcheck "B8h missing view -> empty, never a wrong-type path" \
  [cellview_sibling_path vlib/plain verilog] {}
eqcheck "B8i empty ref -> empty" [cellview_sibling_path {} verilog] {}
eqcheck "B8j unknown library -> empty" [cellview_sibling_path nosuchlib/counter verilog] {}

# ===========================================================================
# B2 + B4 — creation and the seed template
# ===========================================================================
library_new_view vlib counter verilog2 verilog
set NV $tmp/vlib/counter/verilog2/counter.v
check "B2a new verilog view writes a .v (NOT a .sch)" [file isfile $NV] \
  "(dir => [glob -nocomplain -tails -directory $tmp/vlib/counter/verilog2 *])"
check "B2b no .sch was created alongside" \
  [expr {![file exists $tmp/vlib/counter/verilog2/counter.sch]}] {}
eqcheck "B2c the new view types as verilog" [copyform::view_type vlib counter verilog2] verilog
library_new_view vlib amp veriloga2 veriloga
check "B2d new veriloga view writes a .va" [file isfile $tmp/vlib/amp/veriloga2/amp.va] {}
library_new_view vlib plain sch2 schematic
library_new_view vlib plain sym2 symbol
check "B2e schematic/symbol creation unchanged" \
  [expr {[file isfile $tmp/vlib/plain/sch2/plain.sch] && [file isfile $tmp/vlib/plain/sym2/plain.sym]}] {}
check "B2f an unknown type is REFUSED, not silently written as a .sch" \
  [expr {[catch {library_new_view vlib plain bogus gds} e] && ![file exists $tmp/vlib/plain/bogus/plain.sch]}] \
  "(=> $e)"

set seed [read_data $NV]
check "B4a seed declares the module with the cell name" \
  [regexp {module counter \(} $seed] "(seed head: [lindex [split $seed \n] 0])"
check "B4b inputs come first, in symbol order" \
  [regexp {module counter \(\n    input clk,\n    input en,} $seed] {}
check "B4c an output bus keeps its range, translated to Verilog spelling" \
  [regexp {output \[3:0\] count} $seed] {}
check "B4d inouts are declared inout" [regexp {inout \[1:0\] bus} $seed] {}
check "B4e outputs come after inputs (the d_cosim port order)" \
  [expr {[string first "input en" $seed] < [string first "output \[3:0\] count" $seed] &&
         [string first "output \[3:0\] count" $seed] < [string first "inout \[1:0\] bus" $seed]}] {}
check "B4f seed is closed with endmodule" [regexp {\nendmodule\n} $seed] {}
check "B4g seed carries a timescale (the VCD time base, A6)" \
  [regexp {timescale} $seed] {}
check "B4h the seed says the symbol owns the ports" \
  [regexp {PORTS ARE FIXED BY THE SYMBOL VIEW} $seed] {}

library_new_view vlib nosym verilog2 verilog
set seed0 [read_data $tmp/vlib/nosym/verilog2/nosym.v]
check "B4i no symbol view -> a valid portless module, and it says so" \
  [expr {[regexp {module nosym \(\);} $seed0] && [regexp {No symbol view found} $seed0]}] \
  "(=> [string range $seed0 0 0])"

library_new_view vlib amp veriloga3 veriloga
set vaseed [read_data $tmp/vlib/amp/veriloga3/amp.va]
check "B4j veriloga seed declares disciplines and an analog block" \
  [expr {[regexp {disciplines\.vams} $vaseed] && [regexp {electrical vin;} $vaseed] &&
         [regexp {analog begin} $vaseed]}] {}
check "B4k veriloga seed uses the Verilog-A port style (names in the header)" \
  [regexp {module amp\(vin, vout\);} $vaseed] {}

# pin reader + bus splitting, the pieces the seed is built from
eqcheck "B4l library_symbol_pins reads {name dir} in symbol order" \
  [library_symbol_pins vlib amp] {{vin in} {vout out}}
eqcheck {B4m bus split: xschem [n..m] -> verilog [n:m]} \
  [library_pin_split_bus {count[3..0]}] {count {[3:0]}}
eqcheck "B4n bus split: a colon spelling is accepted too" \
  [library_pin_split_bus {d[7:0]}] {d {[7:0]}}
eqcheck "B4o a scalar pin has no range" [library_pin_split_bus clk] {clk {}}
eqcheck "B4p no symbol view -> no pins" [library_symbol_pins vlib nosym] {}

# library_new_cell: the same type->ext drift lived there too
library_new_cell vlib brandnew verilog
check "B2g new CELL with a verilog view writes a .v, not a .sym" \
  [expr {[file isfile $tmp/vlib/brandnew/verilog/brandnew.v] &&
         ![file exists $tmp/vlib/brandnew/verilog/brandnew.sym]}] \
  "(dir => [glob -nocomplain -tails -directory $tmp/vlib/brandnew/verilog *])"
library_new_cell vlib brandsch schematic
library_new_cell vlib brandsym symbol
check "B2h new CELL schematic/symbol unchanged" \
  [expr {[file isfile $tmp/vlib/brandsch/schematic/brandsch.sch] &&
         [file isfile $tmp/vlib/brandsym/symbol/brandsym.sym]}] {}

# ===========================================================================
# B7 — Alt-2's candidate model widens from a hard sch/sym binary
# ===========================================================================
eqcheck "B7a path_type reads the table" \
  [list [alt2::path_type /a/b.v] [alt2::path_type /a/b.sch]] {verilog schematic}
eqcheck "B7b state and data are NOT toggle candidates" \
  [expr {[lsearch [alt2::toggle_types] state] < 0 && [lsearch [alt2::toggle_types] data] < 0}] 1
eqcheck "B7c views_of_type finds the verilog views" \
  [alt2::views_of_type vlib counter verilog] {verilog verilog2}

set c1 [alt2::target_candidates $tmp/vlib/counter/symbol/counter.sym]
set c1types {}; foreach c $c1 { lappend c1types [lindex $c 2] }
check "B7d from the symbol, the verilog views are now candidates" \
  [expr {[lsearch $c1types verilog] >= 0}] "(=> $c1types)"
check "B7e a candidate row carries {view path type}" \
  [expr {[llength [lindex $c1 0]] == 3}] "(=> [lindex $c1 0])"
check "B7f a source candidate opens as TEXT, never via xschem load" \
  [expr {[view_type_opener [lindex [lindex $c1 0] 2]] eq {text}}] "(=> [lindex $c1 0])"

# the classic pair must behave EXACTLY as before when no source view exists
set c2 [alt2::target_candidates $tmp/vlib/plain/schematic/plain.sch]
eqcheck "B7g sch -> exactly the two symbol views, state NOT offered" \
  [lsort [list [lindex [lindex $c2 0] 0] [lindex [lindex $c2 1] 0]]] {sym2 symbol}
eqcheck "B7h and nothing else (the state view stayed out)" [llength $c2] 2
set c3 [alt2::target_candidates $tmp/vlib/plain/symbol/plain.sym]
eqcheck "B7i sym -> the schematic views only" [llength $c3] 2
# the other-ext type is offered FIRST, so the chooser default stays on top even
# when a source view has joined the list
set c5 [alt2::target_candidates $tmp/vlib/mixed/schematic/mixed.sch]
set c5types {}; foreach c $c5 { lappend c5types [lindex $c 2] }
eqcheck "B7j classic partner type still leads the list" $c5types {symbol verilog}

# flat/unregistered layout: the loose sibling, plus the loose source file
set c4 [alt2::target_candidates $tmp/flib/loose.sch]
set c4paths {}; foreach c $c4 { lappend c4paths [lindex $c 1] }
check "B7k FLAT: the .sym sibling is still the first candidate" \
  [expr {[lindex $c4paths 0] eq [file normalize $tmp/flib/loose.sym]}] "(=> $c4paths)"
check "B7l FLAT: the loose .v is offered too" \
  [expr {[lsearch $c4paths [file normalize $tmp/flib/loose.v]] >= 0}] "(=> $c4paths)"

# ===========================================================================
# B9 — veriloga is RECOGNIZED, and deliberately nothing more
# ===========================================================================
# Verilog-A modules are analog: their nodes reach the ngspice raw file through
# OSDI, so unlike a d_cosim `verilog` block they need no VCD reader and no
# second waveform DB (§C/§D of the spec). The whole of B9 is that .va/.vams
# type, create, route and resolve like any other view — asserted above — and
# that nothing here quietly assumes the digital path.
eqcheck "B9a veriloga types, routes and resolves like a first-class view" \
  [list [copyform::view_type vlib amp veriloga] \
        [libmgr::view_handler veriloga [xschem cellview_path vlib/amp veriloga]] \
        [expr {[lib_qualified_abs vlib/amp.va] eq "$tmp/vlib/amp/veriloga/amp.va"}]] \
  {veriloga libmgr::open_text_view 1}
eqcheck "B9b veriloga is NOT typed as verilog anywhere" \
  [expr {[view_type_of_ext .va] ne "verilog" && [view_type_of_ext .vams] ne "verilog"}] 1

# ===========================================================================
# The measured repro, against the real reference cell on disk
# ===========================================================================
# xschem_libraries_oa/ngspice_verilog_cosim_ase/counter has a symbol view and a
# verilog view and no schematic — the §G cell the whole mixed-signal spec is
# built around. This is the exact probe that found the bug. Skipped cleanly if
# the library is not present (it is not part of the minimal checkout).
set repo [file normalize [file join [file dirname [info script]] .. ..]]
set oadefs [file join $repo xschem_libraries_oa library.defs]
set refv   [file join $repo xschem_libraries_oa ngspice_verilog_cosim_ase counter verilog counter.v]
if {[file isfile $oadefs] && [file isfile $refv]} {
  set ::XSCHEM_LIBRARY_DEFS $oadefs
  set L ngspice_verilog_cosim_ase
  set rp [xschem cellview_path $L/counter verilog]
  eqcheck "REF1 the reference cell still enumerates its verilog view" \
    [xschem cell_views $L counter] {symbol verilog}
  eqcheck "REF2 view_type is verilog (was 'data')" [copyform::view_type $L counter verilog] verilog
  check "REF3 view_handler does NOT route the .v to the schematic loader (was 'editor')" \
    [expr {[libmgr::view_handler verilog $rp] ne {editor}}] "(=> [libmgr::view_handler verilog $rp])"
  eqcheck "REF4 lib_qualified_abs .v is the SOURCE, not the symbol" \
    [lib_qualified_abs $L/counter.v] $refv
  eqcheck "REF5 the symbol's self-referential lookup finds its own .v" \
    [cellview_sibling_path $L/counter verilog] $refv
  check "REF6 the source file was not modified by any of this" \
    [expr {[string first "module counter" [read_data $refv]] >= 0}] {}

  # B8 end to end: the symbol's display text is
  #   tcleval([read_data [cellview_sibling_path @symref verilog]])
  # with NO library name in it. Drive the real token substitution + tcleval on
  # a real instance, which is what the canvas does at draw time.
  set tb [file join $repo xschem_libraries_oa $L tb_counter_wrapper schematic tb_counter_wrapper.sch]
  if {[file isfile $tb]} {
    xschem load $tb
    set inst -1
    for {set i 0} {$i < [xschem get instances]} {incr i} {
      if {[string match */counter [xschem translate $i @symref]]} { set inst $i; break }
    }
    check "REF7 the counter instance is found in the reference testbench" \
      [expr {$inst >= 0}] "(instances=[xschem get instances])"
    if {$inst >= 0} {
      eqcheck "REF8 @symref carries no hardcoded library in the symbol" \
        [xschem translate $inst @symref] "$L/counter"
      set rendered [xschem translate $inst \
        {tcleval([read_data [cellview_sibling_path @symref verilog]])}]
      check "REF9 the symbol's self-referential text renders the real Verilog source" \
        [expr {[string first "module counter" $rendered] >= 0 &&
               [string first "endmodule" $rendered] >= 0}] \
        "([string length $rendered] chars)"
    }
    # ...and the symbol on disk must actually USE that form (G6): the old
    # `[xschem cellview_path ngspice_verilog_cosim_ase/counter verilog]` nails
    # the library name into the symbol, so the cell breaks the moment it is
    # copied elsewhere.
    set symtxt [read_data [file join $repo xschem_libraries_oa $L counter symbol counter.sym]]
    check "REF10 the symbol looks its verilog view up self-referentially" \
      [expr {[string first "cellview_sibling_path @symref verilog" $symtxt] >= 0 &&
             [string first "cellview_path $L/counter" $symtxt] < 0}] {}
  }
} else {
  puts "skip: REF1-6 (xschem_libraries_oa/ngspice_verilog_cosim_ase not present)"
}

if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
