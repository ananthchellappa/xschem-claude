# copy_form.tcl — Cadence-style Copy form for the Library Manager, and the copy
# engine behind it.
# Spec: doc/claude/specs/copy_hierarchical.md
#
# Replaces the two-field libmgr::cell_dialog that RMB > Copy on a CELL used to
# pop. Same job in the collapsed state (destination library + new cell name),
# but it also carries the two things the old dialog could not express:
#
#   * a VIEW SPEC — all views (the Cadence default), an explicit pick from the
#     source cell's actual views, or a filter expression that understands
#     `type:<type>` (e.g. `type:symbol` = every view of symbol type).
#   * a HIERARCHICAL toggle — off, the form is the flat copy of one cell; on,
#     the hierarchical section is REVEALED: the exclude-library list, how
#     instance references are handled, and the table of the cells below this
#     one, each with the name its copy gets and whether it is copied at all.
#
# THREE LAYERS, top of the file to bottom:
#   1. the view type model and the ENGINE (copyform::execute): files only, no
#      widgets, runs in a --nogui session;
#   2. the form's state and its decisions (copyform::rows_build,
#      copyform::row_action, copyform::plan): still no widgets;
#   3. the widgets.
# copyform::plan is the seam between 2 and 1: a dict that says everything the
# engine needs, and the one argument of the replayable libmgr::do_copy_plan.
#
# View TYPE vs view NAME (the ngspice_state1 question):
#   A view is a directory; its TYPE comes from the datafile extension inside it,
#   never from the directory's name — matching how library_defs.tcl already
#   thinks (library_new_view maps type -> extension, cellview_resolve maps
#   extension -> view).
#       <cell>.sch        -> schematic
#       <cell>.sym        -> symbol
#       <cell>.state      -> state   (ASE-L simulation state, doc/claude/specs/ase_l.md)
#       <cell>.v/.sv      -> verilog  (source code; opens in a TEXT editor, never
#                                      `xschem load` — doc/claude/specs/mixed_signal_signal_browser.md)
#       <cell>.va/.vams   -> veriloga
#       <cell>.md/.txt    -> text     (the cell's documentation, in its view list
#                                      — doc/claude/specs/text_view_type.md)
#       anything else     -> data
#   The table itself lives once, in library_defs.tcl (view_type_of_ext and
#   friends); this proc only supplies the datafile.
#   So an ASE-L view named `ngspice_state1` is a view of type `state`. Its NAME
#   encodes simulator + ordinal, which gives a second, narrower type spelling
#   derived by stripping the ordinal: `ngspice_state`. Hence
#       type:state          -> every simulation state, any simulator
#       type:ngspice_state  -> only the ngspice ones
#       ngspice_state1      -> that one view, by name
#   This is the Cadence viewType/viewName split done with the information this
#   repo actually has on disk; no cdsinfo.tag-style side table is invented.

namespace eval copyform {
  variable st            ;# form state, see copyform::init
  variable done -1       ;# vwait latch, like libmgr::dlg_done
  variable result {}     ;# the plan dict copyform::open returns
  variable rows {}       ;# the table of cells, see copyform::rows_build
  variable hcache {}     ;# {key hierarchy}, see copyform::hier_cached
  variable xcache {}     ;# {key referrers}, see copyform::referrers_cached
  variable editing -1    ;# the row whose name is being typed in the table, or -1
  variable edit_text {}  ;# what is being typed
}

# ===========================================================================
# view type model (headless — no widgets touched)
# ===========================================================================

# The type of one view of one cell. Extension-derived; "" if the view has no
# datafile (or the cell/library does not resolve).
proc copyform::view_type {lib cell view} {
  set lp ""
  catch {set lp [library_resolve $lib]}
  if {$lp eq {}} { return {} }
  # legacy flat layout: <lib>/<cell>.sym is the "symbol" view, .sch the "schematic"
  set f [file join $lp $cell $view $cell.*]
  set hits [glob -nocomplain $f]
  if {![llength $hits]} {
    if {$view eq "symbol"    && [file isfile [file join $lp $cell.sym]]} { return symbol }
    if {$view eq "schematic" && [file isfile [file join $lp $cell.sch]]} { return schematic }
    return {}
  }
  # ONE extension->type table, in library_defs.tcl. It also knows .v/.sv ->
  # verilog and .va/.vams -> veriloga, which used to fall through to `data`.
  return [view_type_of_ext [file extension [lindex [lsort $hits] 0]]]
}

# The narrow, simulator-qualified type spelling for a state view: ngspice_state1
# -> ngspice_state. Empty for everything else, so a caller can simply try both.
proc copyform::view_subtype {view type} {
  if {$type ne "state"} { return {} }
  if {[regexp {^(.+_state)[0-9]*$} $view -> base]} { return $base }
  return $type
}

# {view type} pairs for a cell, in cell_views order.
proc copyform::cell_view_types {lib cell} {
  set out {}
  foreach v [cell_views $lib $cell] { lappend out $v [copyform::view_type $lib $cell $v] }
  return $out
}

# Parse a view filter expression into {names {...} types {...}}. Tokens are
# whitespace- or comma-separated; a `type:` prefix makes the token a type, and
# a bare token is a view NAME (glob metacharacters allowed).
proc copyform::parse_view_spec {spec} {
  set names {}; set types {}
  foreach tok [split [string map {, { }} $spec]] {
    set tok [string trim $tok]
    if {$tok eq {}} continue
    if {[string match -nocase "type:*" $tok]} {
      lappend types [string tolower [string range $tok 5 end]]
    } else {
      lappend names $tok
    }
  }
  return [list names $names types $types]
}

# Resolve the current view spec against a cell -> the list of view names to copy.
# mode all      : every view
# mode selected : the explicit pick, filtered to views that still exist
# mode filter   : name globs + type:/subtype: matches from the expression
proc copyform::match_views {lib cell mode selected filter} {
  set all [cell_views $lib $cell]
  switch -- $mode {
    all      { return $all }
    selected {
      set out {}
      foreach v $selected { if {[lsearch -exact $all $v] >= 0} { lappend out $v } }
      return $out
    }
  }
  array set spec [copyform::parse_view_spec $filter]
  set out {}
  foreach v $all {
    set t [copyform::view_type $lib $cell $v]
    set sub [copyform::view_subtype $v $t]
    set hit 0
    foreach n $spec(names) { if {[string match $n $v]} { set hit 1; break } }
    if {!$hit} {
      foreach ty $spec(types) {
        if {$ty eq $t || ($sub ne {} && $ty eq $sub)} { set hit 1; break }
      }
    }
    if {$hit} { lappend out $v }
  }
  return $out
}

# ===========================================================================
# the copy engine (headless: files only, no widget, no schematic is loaded)
# ===========================================================================
#
# WHAT IT DOES. Copies a set of cells under new names, then makes the copies
# point at each other instead of at the originals:
#   * schematics: an instance of a copied cell becomes an instance of its copy;
#   * ASE-L states: `design`, a model or include file that lives inside a copied
#     cell's own directory, and the result files the saved plot setup names;
# and reports what in the copies STILL names an original (copyform::mentions),
# because a name inside a title text or a hand-written SPICE block is not
# something a tool should guess at.
#
# THE FILES ARE EDITED AS TEXT. Loading each schematic into the editor to change
# one reference would clobber the schematic the user has open (the reason
# library_symbol_pins reads its .sym by text too) and would re-save every record
# in today's format. A line this engine does not change comes back byte for
# byte: files are read and written with `-translation binary`, and a name is
# compared as the UTF-8 bytes it has on disk (copyform::b / copyform::u).
#
# ALL OR NOTHING. copyform::plan_why refuses a plan before anything is created;
# a failure after that puts every edited file back and moves every cell made so
# far to the library's trash.

namespace eval copyform {
  variable rcache {}     ;# reference -> cell, for the length of one operation
}

# Start an operation: forget what the last one learned about references (cells
# come and go between two operations, and within one after the copies are made).
proc copyform::fresh {} {
  variable rcache
  set rcache {}
}

# `::open`, spelled out: inside this namespace a bare `open` is copyform::open,
# the form's entry point, which would try to build a window here.
proc copyform::slurp {path} {
  set f [::open $path r]
  fconfigure $f -translation binary
  set c [read $f]
  ::close $f
  return $c
}

# Written beside the file and renamed over it, so a failed write leaves the
# original whole.
proc copyform::spit {path content} {
  set tmp "$path.cp[pid]"
  set f [::open $tmp w]
  fconfigure $f -translation binary
  puts -nonewline $f $content
  ::close $f
  catch {file attributes $tmp -permissions [file attributes $path -permissions]}
  file rename -force -- $tmp $path
}

# A name as the bytes it has inside a file, and back.
proc copyform::b {s} { return [encoding convertto utf-8 $s] }
proc copyform::u {s} { return [encoding convertfrom utf-8 $s] }

# Why NAME cannot be the name of a cell, or {} when it can. A cell name becomes
# a directory, a file name, a word of a Tcl list in a state file and part of an
# instance reference, so it has to be one plain word.
proc copyform::name_why {name} {
  if {$name eq {}} { return "a cell name is required" }
  if {[regexp {[/\\\s{}"$;\[\]]} $name]} {
    return "'$name' cannot be a cell name: no spaces, slashes, braces, brackets, quotes, \$ or ;"
  }
  if {[string index $name 0] eq "." || [string index $name 0] eq "-"} {
    return "'$name' cannot be a cell name: it starts with '[string index $name 0]'"
  }
  return {}
}

# Every datafile of a cell as a flat {view path type ...} list. A nested cell
# gives one triple per view directory; a flat one its loose .sym and .sch.
proc copyform::cell_files {lib cell} {
  set lp {}
  catch {set lp [library_resolve $lib]}
  set out {}
  if {$lp eq {}} { return $out }
  foreach f [lsort [glob -nocomplain [file join $lp $cell * $cell.*]]] {
    lappend out [file tail [file dirname $f]] $f [view_type_of_ext [file extension $f]]
  }
  foreach {ext view} {.sym symbol .sch schematic} {
    set f [file join $lp $cell$ext]
    if {[file isfile $f]} { lappend out $view $f [view_type_of_ext $ext] }
  }
  return $out
}

# Is P the directory DIR or something inside it? Compared by path component,
# never as a string prefix. On 1 the components below DIR are left in restVar.
proc copyform::under {p dir restVar} {
  upvar 1 $restVar rest
  set pl [file split $p]
  set dl [file split $dir]
  set n [llength $dl]
  if {[llength $pl] < $n || [lrange $pl 0 [expr {$n - 1}]] ne $dl} { return 0 }
  set rest [lrange $pl $n end]
  return 1
}

# --- instance references ----------------------------------------------------

# The instance records of a schematic, given its lines: {index reference ...},
# the reference still in file form (bytes, braces escaped). An instance record
# is a line that starts `C {` OUTSIDE every attribute block; the writer
# (save_ascii_string, src/save.c) escapes each brace and backslash inside a
# string, so counting the unescaped braces says exactly where a block ends.
proc copyform::sch_scan {lines} {
  set out {}
  set depth 0
  set i -1
  foreach line $lines {
    incr i
    if {$depth == 0 && [string match "C \{*" $line]} {
      if {[regexp {^C \{((?:[^\\\}]|\\.)*)\}} $line -> ref]} { lappend out $i $ref }
    }
    regsub -all {\\.} $line {} bare
    incr depth [expr {[regexp -all {\{} $bare] - [regexp -all {\}} $bare]}]
    if {$depth < 0} { set depth 0 }
  }
  return $out
}

# Where a reference that is not `library/cell` leads, as abs_sym_path would find
# it, except that a relative one is taken from the schematic's own directory
# instead of from the process's current one. {} when nothing is there.
proc copyform::ref_abs {ref schdir} {
  global pathlist
  if {[file pathtype $ref] eq "absolute"} { return [file normalize $ref] }
  if {[regexp {^\.\.?/} $ref]} { return [file normalize [file join $schdir $ref]] }
  set q {}
  catch {set q [lib_qualified_abs $ref]}
  if {$q ne {}} { return [file normalize $q] }
  if {[info exists pathlist]} {
    foreach p $pathlist {
      if {$p eq "."} { set p $schdir }
      set f [file join $p $ref]
      if {[file exists $f]} { return [file normalize $f] }
    }
  }
  set f [file join $schdir $ref]
  if {[file exists $f]} { return [file normalize $f] }
  return {}
}

# The cell an instance reference names: {lib cell ext how view}, or {} when it
# is not a cell of a registered library (a generator, a URL, a loose file).
#   how  lq   `library/cell[.ext]`, the spelling this program writes itself
#        rel  a path found on the search list or beside the schematic
#        abs  an absolute path
#   view the view directory a path spelling pointed into ({} for a flat cell
#        and for the lq spelling, whose extension alone picks the view)
proc copyform::ref_cell {ref schdir} {
  variable rcache
  # a library/cell reference means the same wherever it is written, so it is
  # remembered once; anything else is remembered per schematic directory
  if {[dict exists $rcache [list {} $ref]]} { return [dict get $rcache [list {} $ref]] }
  set ck [list $schdir $ref]
  if {[dict exists $rcache $ck]} { return [dict get $rcache $ck] }
  set ans {}
  if {$ref ne {} && ![regexp {^https?://} $ref]} {
    set ext [file extension $ref]
    if {[regexp {^([^/]+)/([^/]+)$} $ref -> l rest] && [library_resolve $l] ne {}} {
      set ck [list {} $ref]
      set c [file rootname $rest]
      if {[library_cell_layout $l $c] ne {}} { set ans [list $l $c $ext lq {}] }
    } else {
      set abs [copyform::ref_abs $ref $schdir]
      if {$abs ne {}} {
        set cv [schematic_cellview $abs]
        if {$cv ne {}} {
          lassign $cv l c v layout
          set how [expr {[file pathtype $ref] eq "absolute" ? "abs" : "rel"}]
          set ans [list $l $c $ext $how $v]
        }
      }
    }
  }
  dict set rcache $ck $ans
  return $ans
}

# The reference to write once the cell RC names (a copyform::ref_cell answer)
# has the copy dl/dc. The spelling is kept: a library/cell reference stays one,
# and so does an ordinary path found on the search list (library/cell is how
# this program writes those itself). An absolute path, or a path into a view
# with a name of its own, becomes the path of the same file in the copy. {}
# when that file is not there: the reference is then left as it is.
proc copyform::ref_new {rc dl dc} {
  lassign $rc l c ext how v
  if {$how eq "lq"} { return "$dl/$dc$ext" }
  set plain [expr {$v eq {} || ($v eq "symbol" && $ext eq ".sym") ||
                   ($v eq "schematic" && $ext eq ".sch")}]
  if {$how eq "rel" && $plain} {
    return "$dl/$dc[expr {$ext eq {.sch} ? {.sch} : {}}]"
  }
  set cands {}
  if {$v ne {}} { lappend cands [file join [library_resolve $dl] $dc $v $dc$ext] }
  lappend cands [cellview_resolve $dl $dc [expr {$ext eq {.sch} ? {schematic} : {symbol}}]]
  foreach f $cands {
    if {$f ne {} && [file isfile $f]} { return $f }
  }
  return {}
}

# Re-point the instances of one schematic file. MAP is a dict whose keys are
# {lib cell} of an original and whose values are {lib cell} of what replaces it.
# Returns {old new ...}, one pair per instance changed. The file is written
# only when something changed.
proc copyform::retarget_sch {path map} {
  set lines [split [copyform::slurp $path] \n]
  set schdir [file dirname $path]
  set done {}
  foreach {i refb} [copyform::sch_scan $lines] {
    regsub -all {\\(.)} $refb {\1} plain
    set ref [copyform::u $plain]
    set rc [copyform::ref_cell $ref $schdir]
    if {$rc eq {}} continue
    set key [lrange $rc 0 1]
    if {![dict exists $map $key]} continue
    lassign [dict get $map $key] dl dc
    set new [copyform::ref_new $rc $dl $dc]
    if {$new eq {} || $new eq $ref} continue
    set newb [regsub -all {[\\{}]} [copyform::b $new] {\\&}]
    set rest [string range [lindex $lines $i] [expr {[string length $refb] + 4}] end]
    lset lines $i "C \{$newb\}$rest"
    lappend done $ref $new
  }
  if {[llength $done]} { copyform::spit $path [join $lines \n] }
  return $done
}

# The cells a cell instantiates, read from its schematic views: {{lib cell} ...}
# in the order first met, each once, the cell itself left out.
proc copyform::cell_children {lib cell} {
  set out {}
  foreach {view path type} [copyform::cell_files $lib $cell] {
    if {$type ne "schematic"} continue
    if {[catch {copyform::slurp $path} raw]} continue
    set dir [file dirname $path]
    foreach {i refb} [copyform::sch_scan [split $raw \n]] {
      regsub -all {\\(.)} $refb {\1} plain
      set rc [copyform::ref_cell [copyform::u $plain] $dir]
      if {$rc eq {}} continue
      set key [lrange $rc 0 1]
      if {$key eq [list $lib $cell]} continue
      if {[lsearch -exact $out $key] < 0} { lappend out $key }
    }
  }
  return $out
}

# Everything below a cell, depth first, each cell once: {{lib cell depth} ...}.
# A cell of an excluded library is left out and nothing below it is visited,
# so a PDK never enters the table.
proc copyform::hier {lib cell exclude} {
  copyform::fresh
  set seen [list [list $lib $cell]]
  set out {}
  copyform::hier_walk $lib $cell 1 $exclude seen out
  return $out
}

proc copyform::hier_walk {lib cell depth exclude seenVar outVar} {
  upvar 1 $seenVar seen $outVar out
  foreach key [copyform::cell_children $lib $cell] {
    lassign $key l c
    if {[lsearch -exact $exclude $l] >= 0} continue
    if {[lsearch -exact $seen $key] >= 0} continue
    lappend seen $key
    lappend out [list $l $c $depth]
    copyform::hier_walk $l $c [expr {$depth + 1}] $exclude seen out
  }
}

# --- ASE-L states -----------------------------------------------------------

# A state file is a flat list of key/value pairs, written one `key value` per
# line (ase::state_serialize, src/ase.tcl). This writes the same form, in the
# order the pairs came in, so a pair that was not touched keeps its line.
proc copyform::state_text {pairs} {
  set lines {}
  foreach {k v} $pairs { lappend lines "$k [list $v]" }
  return "[join $lines \n]\n"
}

# A model or include file a state names: where it should point after the copy,
# or {} to leave it alone. TEXT is what the state holds, variables included
# (`$::HDO_DIR/lib/.../includes/x.spice`). It is re-pointed only when it lies
# inside the directory of a cell in MAP and the same file exists in what
# replaces that cell. Whatever the user wrote in front of the cell is kept, so
# a path spelled with a variable still is.
proc copyform::retarget_path {text map} {
  set real $text
  catch {set real [uplevel #0 [list subst -nocommands -nobackslashes $text]]}
  if {$real eq {} || [file pathtype $real] ne "absolute"} { return {} }
  set real [file normalize $real]
  dict for {src dst} $map {
    lassign $src sl sc
    lassign $dst dl dc
    set slp [library_resolve $sl]
    set dlp [library_resolve $dl]
    if {$slp eq {} || $dlp eq {}} continue
    set slp [file normalize $slp]
    set dlp [file normalize $dlp]
    if {![copyform::under $real [file join $slp $sc] rest] || ![llength $rest]} continue
    set target [file join $dlp $dc {*}$rest]
    if {![file exists $target]} { return {} }
    set tail /$sc/[join $rest /]
    set n [string length $tail]
    if {[string range $text end-[expr {$n - 1}] end] ne $tail} { return $target }
    set head [string range $text 0 end-$n]
    if {$sl eq $dl} { return $head/$dc/[join $rest /] }
    set st [file tail $slp]
    if {[file dirname $slp] eq [file dirname $dlp] &&
        [string range $head end-[string length $st] end] eq "/$st"} {
      return [string range $head 0 end-[string length $st]][file tail $dlp]/$dc/[join $rest /]
    }
    return $target
  }
  return {}
}

# A bench writes its results into a file named after its cell: <cell>_ase.raw
# with the ngspice backend. PATH renamed for the cell NEW when its last
# component is that file of the cell OLD, else {} (also when the cell keeps its
# name, as in a copy into another library: there is then nothing to rename).
proc copyform::raw_rename {path old new} {
  if {$old eq $new} { return {} }
  set i [string last / $path]
  set tail [string range $path [expr {$i + 1}] end]
  set n [string length $old]
  if {[string range $tail 0 [expr {$n - 1}]] ne $old} { return {} }
  set rest [string range $tail $n end]
  if {![regexp {^(_ase)?\.[^/]+$} $rest]} { return {} }
  return [string range $path 0 $i]$new$rest
}

# The traces of a saved plot setup that are pinned to the old bench's result
# file (a trace picked from another analysis of the same run carries the file it
# came from, see wviewer::db_suffix) are pinned to the copy's instead. D is a
# viewer dict or a tab's layout; cntVar counts what changed.
proc copyform::retarget_traces {d old new cntVar} {
  upvar 1 $cntVar cnt
  if {[catch {dict size $d}]} { return $d }
  if {[dict exists $d graphs] && ![catch {llength [dict get $d graphs]}]} {
    set gs {}
    foreach g [dict get $d graphs] {
      if {![catch {dict exists $g traces} has] && $has && ![catch {llength [dict get $g traces]}]} {
        set ts {}
        foreach t [dict get $g traces] {
          if {![catch {dict exists $t rawfile} pinned] && $pinned} {
            set nr [copyform::raw_rename [dict get $t rawfile] $old $new]
            if {$nr ne {}} {
              dict set t rawfile $nr
              incr cnt
            }
          }
          lappend ts $t
        }
        dict set g traces $ts
      }
      lappend gs $g
    }
    dict set d graphs $gs
  }
  if {[dict exists $d tabs] && ![catch {llength [dict get $d tabs]}]} {
    set tabs {}
    foreach tab [dict get $d tabs] {
      if {![catch {dict exists $tab layout} has] && $has} {
        dict set tab layout [copyform::retarget_traces [dict get $tab layout] $old $new cnt]
      }
      lappend tabs $tab
    }
    dict set d tabs $tabs
  }
  return $d
}

# Re-point one state file. Returns one short sentence per thing changed; {}
# means nothing applied and the file was not written.
#   design    a design that is a cell of MAP becomes what replaces it. A state
#             the user pointed at some other cell (Setup > Design) is left.
#   models, includes   see copyform::retarget_path.
#   viewer    only when the design moved: the selected result is cleared, which
#             is how a state says "my own last run", and pinned traces follow
#             (copyform::retarget_traces). Without this the copy of a bench
#             would open on, and keep plotting, the old bench's numbers.
proc copyform::retarget_state {path map} {
  set pairs [copyform::slurp $path]
  if {[catch {llength $pairs} n] || $n % 2} {
    error "[file tail $path] is not a state file (not a list of key/value pairs)"
  }
  set moved {}
  foreach {k v} $pairs {
    if {$k ne "design"} continue
    if {[catch {dict get $v lib} lb] || [catch {dict get $v cell} cb]} break
    set key [list [copyform::u $lb] [copyform::u $cb]]
    if {[dict exists $map $key]} { set moved [list [lindex $key 1] {*}[dict get $map $key]] }
    break
  }
  set out {}
  set did {}
  foreach {k v} $pairs {
    if {$k eq "design" && $moved ne {}} {
      lassign $moved oc dl dc
      dict set v lib [copyform::b $dl]
      dict set v cell [copyform::b $dc]
      lappend did "design is now $dl/$dc"
    } elseif {($k eq "models" || $k eq "includes") && ![catch {llength $v}]} {
      set rows {}
      set n 0
      foreach row $v {
        if {![catch {dict exists $row file} has] && $has} {
          set np [copyform::retarget_path [copyform::u [dict get $row file]] $map]
          if {$np ne {}} {
            dict set row file [copyform::b $np]
            incr n
          }
        }
        lappend rows $row
      }
      if {$n} {
        set v $rows
        set what [expr {$k eq "models" ? "model" : "include"}]
        lappend did "$n $what file[expr {$n > 1 ? {s} : {}}] now read from the copy"
      }
    } elseif {$k eq "viewer" && $moved ne {} && ![catch {dict size $v}]} {
      lassign $moved oc dl dc
      set n 0
      set nv [copyform::retarget_traces $v [copyform::b $oc] [copyform::b $dc] n]
      if {[dict exists $nv rawfile] && [dict get $nv rawfile] ne {}} {
        dict set nv rawfile {}
        incr n
      }
      if {$n} {
        set v $nv
        lappend did "saved plot setup now follows the copy's own results"
      }
    }
    lappend out $k $v
  }
  if {[llength $did]} { copyform::spit $path [copyform::state_text $out] }
  return $did
}

# The states of one cell, re-pointed. Returns {{path {sentence ...}} ...} for
# the files that changed. Used by the copy below and by a rename, where the
# cell's own states have to follow its new name (libmgr::do_rename_cell).
proc copyform::retarget_states {lib cell map} {
  set out {}
  foreach {view path type} [copyform::cell_files $lib $cell] {
    if {$type ne "state"} continue
    set did [copyform::retarget_state $path $map]
    if {[llength $did]} { lappend out [list $path $did] }
  }
  return $out
}

# --- what is left -----------------------------------------------------------

# Lines of FILES that still name one of NAMES as a whole word (a longer name
# that merely contains it does not count, a result file `<name>_ase.raw` does).
# Returns {{file line name excerpt} ...}, at most 20 per file. Binary files and
# files over 4 MB are skipped.
proc copyform::mentions {files names} {
  # the longest name first, so a line that holds my_buf3_tb is reported under
  # that name and not under my_buf3
  set pats {}
  foreach nm [lsort -command {apply {{a b} {expr {[string length $b] - [string length $a]}}}} $names] {
    set q [regsub -all {[][{}()*+?.\\^$|]} [copyform::b $nm] {\\&}]
    lappend pats $nm "(^|\[^A-Za-z0-9_\])${q}(\$|\[^A-Za-z0-9_\]|_ase\\.)"
  }
  set out {}
  foreach f $files {
    if {[catch {file size $f} sz] || $sz > 4000000} continue
    if {[catch {copyform::slurp $f} raw]} continue
    if {[string first \0 $raw] >= 0} continue
    set ln 0
    set hits 0
    foreach line [split $raw \n] {
      incr ln
      foreach {nm pat} $pats {
        if {![regexp -indices -- $pat $line where]} continue
        lassign $where s e
        set txt [string trim [string range $line [expr {$s - 40}] [expr {$e + 40}]]]
        lappend out [list $f $ln $nm [copyform::u $txt]]
        incr hits
        break
      }
      if {$hits >= 20} break
    }
  }
  return $out
}

# Every regular file under a cell's directory (a nested cell), or its loose
# datafiles (a flat one): what copyform::mentions is asked to read.
proc copyform::cell_all_files {lib cell} {
  set lp {}
  catch {set lp [library_resolve $lib]}
  if {$lp eq {}} { return {} }
  set out {}
  set todo [list [file join $lp $cell]]
  while {[llength $todo]} {
    set d [lindex $todo 0]
    set todo [lrange $todo 1 end]
    if {![file isdirectory $d]} continue
    foreach f [lsort [glob -nocomplain -directory $d *]] {
      if {[file isdirectory $f]} { lappend todo $f } elseif {[file isfile $f]} { lappend out $f }
    }
  }
  foreach ext {.sym .sch} {
    set f [file join $lp $cell$ext]
    if {[file isfile $f]} { lappend out $f }
  }
  return $out
}

# The cells that instantiate lib/cell: {{lib cell} ...}. Every library is read
# except the ones a design only refers to (copyform::default_excludes): the
# PDK, the device library, a library that cannot be written.
proc copyform::cell_users {lib cell} {
  copyform::fresh
  set skip [copyform::default_excludes $lib]
  set want [list $lib $cell]
  set out {}
  foreach pair [library_list] {
    set l [lindex $pair 0]
    if {[lsearch -exact $skip $l] >= 0} continue
    foreach c [library_cells $l] {
      if {$l eq $lib && $c eq $cell} continue
      if {[lsearch -exact [copyform::cell_children $l $c] $want] >= 0} { lappend out [list $l $c] }
    }
  }
  return $out
}

# The states, in any cell of those same libraries, whose design is lib/cell:
# {{lib cell view} ...}. A state simulates a cell without instantiating it.
proc copyform::state_users {lib cell} {
  set skip [copyform::default_excludes $lib]
  set out {}
  foreach pair [library_list] {
    set l [lindex $pair 0]
    if {[lsearch -exact $skip $l] >= 0} continue
    foreach c [library_cells $l] {
      if {$l eq $lib && $c eq $cell} continue
      foreach {view path type} [copyform::cell_files $l $c] {
        if {$type ne "state"} continue
        if {[catch {copyform::slurp $path} raw] || [catch {dict get $raw design} d]} continue
        if {[catch {dict get $d lib} dl] || [catch {dict get $d cell} dc]} continue
        if {[copyform::u $dl] eq $lib && [copyform::u $dc] eq $cell} { lappend out [list $l $c $view] }
      }
    }
  }
  return $out
}

# --- the plan and its execution ---------------------------------------------

# A plan's view choice as {mode selected filter}; a plan that says nothing
# copies every view.
proc copyform::plan_views {plan} {
  set mode all
  set sel {}
  set flt {}
  catch {set mode [dict get $plan viewmode]}
  catch {set sel [dict get $plan viewsel]}
  catch {set flt [dict get $plan viewfilter]}
  if {$mode ni {all selected filter}} { set mode all }
  return [list $mode $sel $flt]
}

# Why a plan cannot run, or {} when it can. Nothing is created before this has
# said {}. `cells` rows are {srclib srccell dstlib dstcell action}:
#   copy   make dstlib/dstcell from srclib/srccell
#   use    dstlib/dstcell is already there: copy nothing, point references at it
#   keep   leave references to srclib/srccell alone (the row is only a record)
proc copyform::plan_why {plan} {
  if {![dict exists $plan cells]} { return "the plan names no cells" }
  lassign [copyform::plan_views $plan] mode sel flt
  set dsts {}
  set srcs {}
  set copies 0
  foreach row [dict get $plan cells] {
    lassign $row sl sc dl dc act
    if {$act eq "keep"} continue
    if {$act ne "copy" && $act ne "use"} { return "unknown action '$act' for $sl/$sc" }
    if {[library_cell_layout $sl $sc] eq {}} { return "no such cell: $sl/$sc" }
    if {[lsearch -exact $srcs [list $sl $sc]] >= 0} { return "$sl/$sc is listed twice" }
    lappend srcs [list $sl $sc]
    set dlp [library_resolve $dl]
    if {$dlp eq {}} { return "no such library: $dl" }
    set why [copyform::name_why $dc]
    if {$why ne {}} { return $why }
    if {$act eq "use"} {
      if {$sl eq $dl && $sc eq $dc} { return "$sl/$sc: nothing to re-point, that is the same cell" }
      if {[library_cell_layout $dl $dc] eq {}} { return "no such cell: $dl/$dc" }
      continue
    }
    incr copies
    if {[library_cell_layout $dl $dc] ne {}} { return "cell already exists: $dl/$dc" }
    if {[lsearch -exact $dsts [list $dl $dc]] >= 0} { return "two cells would be copied to $dl/$dc" }
    lappend dsts [list $dl $dc]
    if {![file writable $dlp]} { return "library $dl cannot be written" }
    if {$mode ne "all"} {
      if {[library_cell_layout $sl $sc] ne "nested" || [library_layout_style $dl] ne "nested"} {
        return "$sl/$sc -> $dl: a choice of views needs cells kept as cell/view directories; copy all views"
      }
      if {![llength [copyform::match_views $sl $sc $mode $sel $flt]]} {
        return "no view of $sl/$sc matches the view choice"
      }
    }
  }
  if {!$copies} { return "nothing to copy" }
  return {}
}

# One cell copied: every view, or the views the plan chose.
proc copyform::copy_one {sl sc dl dc mode sel flt} {
  if {$mode eq "all"} {
    library_copy_cell $sl $sc $dl $dc
    return
  }
  foreach v [copyform::match_views $sl $sc $mode $sel $flt] {
    library_copy_view $sl $sc $v $dl $dc $v
  }
}

# Schematic files that are loaded in some window right now, normalized. A file
# that is open is never edited under its editor: the editor would write its own
# copy back over the change on the next save.
proc copyform::open_files {} {
  set out {}
  if {[catch {xschem windows} wins]} { return $out }
  foreach w $wins {
    # field 4 is what the window shows, field 6 the stack it descended through
    foreach f [concat [list [lindex $w 4]] [lindex $w 6]] {
      if {$f ne {}} { catch {lappend out [file normalize $f]} }
    }
  }
  return $out
}

# Cells ALREADY in the destination library that instantiate an original this
# plan replaces: what "Entire destination library" also edits. {{lib cell} ...}
proc copyform::library_referrers {plan} {
  copyform::fresh
  set map {}
  set mine {}
  set dstlibs {}
  foreach row [dict get $plan cells] {
    lassign $row sl sc dl dc act
    if {$act eq "keep"} continue
    dict set map [list $sl $sc] [list $dl $dc]
    # not a referrer: the original itself (a bench copied inside its library
    # must go on testing the old cell) and a copy this plan is about to make.
    # A cell that is merely pointed at (`use`) is a cell of that library like
    # any other.
    lappend mine [list $sl $sc]
    if {$act eq "copy"} { lappend mine [list $dl $dc] }
    if {[lsearch -exact $dstlibs $dl] < 0} { lappend dstlibs $dl }
  }
  set out {}
  foreach dl $dstlibs {
    foreach c [library_cells $dl] {
      if {[lsearch -exact $mine [list $dl $c]] >= 0} continue
      foreach kid [copyform::cell_children $dl $c] {
        if {[dict exists $map $kid]} {
          lappend out [list $dl $c]
          break
        }
      }
    }
  }
  return $out
}

# Run a plan. Returns the report, a dict:
#   copied  {{srclib srccell dstlib dstcell} ...}
#   used    the same shape, for references re-pointed at a cell that was there
#   kept    {{srclib srccell} ...}
#   sch     {{path {old new ...}} ...}      instance references re-pointed
#   states  {{path {sentence ...}} ...}     state files re-pointed
#   edited  {{lib cell} ...}                cells of the destination library whose
#                                           instances were re-pointed too
#   skipped {{path why} ...}                such files left alone; why is `open`
#                                           (loaded in a window: its editor would
#                                           write its own copy back) or `readonly`
#                                           (not checked out, or not ours to edit)
#   left    {{path line name excerpt} ...}  what in the copies still names an original
# Raises, with nothing left changed, when the plan cannot run.
#
# `updaterefs`: none leaves every instance on its original; copies (the default)
# re-points the instances inside the copies; library also re-points the cells
# already in the destination library. A STATE always follows its own cell, in
# all three: a state stored under one cell and simulating another is never what
# a copy is for.
proc copyform::execute {plan} {
  copyform::fresh
  set why [copyform::plan_why $plan]
  if {$why ne {}} { error $why }
  lassign [copyform::plan_views $plan] mode sel flt
  set upd copies
  catch {set upd [dict get $plan updaterefs]}
  if {$upd ni {none copies library}} { set upd copies }
  set rep [dict create copied {} used {} kept {} sch {} states {} edited {} skipped {} left {}]
  set map {}
  set todo {}
  foreach row [dict get $plan cells] {
    lassign $row sl sc dl dc act
    switch -exact -- $act {
      keep { dict lappend rep kept [list $sl $sc] }
      use  {
        dict set map [list $sl $sc] [list $dl $dc]
        dict lappend rep used [list $sl $sc $dl $dc]
      }
      copy {
        dict set map [list $sl $sc] [list $dl $dc]
        lappend todo [list $sl $sc $dl $dc]
      }
    }
  }
  set referrers {}
  if {$upd eq "library"} { set referrers [copyform::library_referrers $plan] }
  set made {}
  set saved {}
  if {[catch {
    foreach row $todo {
      lassign $row sl sc dl dc
      lappend made [list $dl $dc]
      copyform::copy_one $sl $sc $dl $dc $mode $sel $flt
      dict lappend rep copied $row
    }
    copyform::fresh
    foreach row $todo {
      lassign $row sl sc dl dc
      set own [dict create [list $sl $sc] [list $dl $dc]]
      foreach {view path type} [copyform::cell_files $dl $dc] {
        if {$type eq "schematic" && $upd ne "none"} {
          set ch [copyform::retarget_sch $path $map]
          if {[llength $ch]} { dict lappend rep sch [list $path $ch] }
        } elseif {$type eq "state"} {
          set ch [copyform::retarget_state $path [expr {$upd eq "none" ? $own : $map}]]
          if {[llength $ch]} { dict lappend rep states [list $path $ch] }
        }
      }
    }
    set open [copyform::open_files]
    foreach ref $referrers {
      lassign $ref l c
      set hit 0
      foreach {view path type} [copyform::cell_files $l $c] {
        if {$type ne "schematic"} continue
        if {[lsearch -exact $open [file normalize $path]] >= 0} {
          dict lappend rep skipped [list $path open]
          continue
        }
        if {![file writable $path]} {
          dict lappend rep skipped [list $path readonly]
          continue
        }
        set before [copyform::slurp $path]
        set ch [copyform::retarget_sch $path $map]
        if {[llength $ch]} {
          dict set saved $path $before
          dict lappend rep sch [list $path $ch]
          set hit 1
        }
      }
      if {$hit} { dict lappend rep edited $ref }
    }
  } err]} {
    dict for {p bytes} $saved { catch {copyform::spit $p $bytes} }
    foreach m $made {
      lassign $m dl dc
      if {[catch {library_delete_cell $dl $dc}]} {
        set d [file join [library_resolve $dl] $dc]
        if {[file exists $d]} { catch {library_trash_move [library_resolve $dl] $d} }
      }
    }
    error "nothing was copied: $err"
  }
  set names {}
  dict for {src dst} $map { lappend names [lindex $src 1] }
  set files {}
  foreach row $todo {
    lassign $row sl sc dl dc
    lappend files {*}[copyform::cell_all_files $dl $dc]
  }
  if {$upd ne "none"} {
    dict set rep left [copyform::mentions $files [lsort -unique $names]]
  } else {
    set own {}
    foreach row $todo { lappend own [lindex $row 1] }
    dict set rep left [copyform::mentions $files [lsort -unique $own]]
  }
  return $rep
}

# A file of a copied cell, named the short way: cell/view/file.
proc copyform::short_path {path} {
  return [join [lrange [file split $path] end-2 end] /]
}

# The report in words. `summary` is one line for a status bar, `extras` the
# same line without its first clause (for a caller that words the copy itself),
# and `lines` the whole account, one sentence a line, for the CIW.
proc copyform::report_text {rep} {
  set nc [llength [dict get $rep copied]]
  set parts [list "copied $nc cell[expr {$nc == 1 ? {} : {s}}]"]
  set ni 0
  foreach e [dict get $rep sch] { incr ni [expr {[llength [lindex $e 1]] / 2}] }
  if {$ni} { lappend parts "$ni instance[expr {$ni == 1 ? {} : {s}}] re-pointed" }
  set ns [llength [dict get $rep states]]
  if {$ns} { lappend parts "$ns state[expr {$ns == 1 ? {} : {s}}] re-pointed" }
  set nl [llength [dict get $rep left]]
  if {$nl} { lappend parts "$nl place[expr {$nl == 1 ? {} : {s}}] still name[expr {$nl == 1 ? {s} : {}}] an original (see the CIW)" }
  set nk [llength [dict get $rep skipped]]
  if {$nk} { lappend parts "$nk file[expr {$nk == 1 ? {} : {s}}] left alone (see the CIW)" }
  set lines {}
  foreach row [dict get $rep copied] {
    lassign $row sl sc dl dc
    lappend lines "copy: $sl/$sc -> $dl/$dc"
  }
  foreach row [dict get $rep used] {
    lassign $row sl sc dl dc
    lappend lines "copy: references to $sl/$sc now go to $dl/$dc, which was already there"
  }
  foreach e [dict get $rep sch] {
    lassign $e path ch
    foreach {old new} $ch { lappend lines "copy: [file tail $path]: instance of $old is now $new" }
  }
  foreach e [dict get $rep states] {
    lassign $e path ch
    set view [file tail [file dirname $path]]
    lappend lines "copy: [file rootname [file tail $path]] $view: [join $ch {; }]"
  }
  foreach e [dict get $rep skipped] {
    lassign $e path why
    set because [expr {$why eq "open" ? "is open in a window" : "is read-only"}]
    lappend lines "copy: [copyform::short_path $path] $because and was left as it is"
  }
  foreach e [dict get $rep left] {
    lassign $e path ln name txt
    lappend lines "copy: still names $name: [copyform::short_path $path] line $ln: $txt"
  }
  return [dict create summary [join $parts {, }] extras [lrange $parts 1 end] lines $lines]
}

# ===========================================================================
# form state
# ===========================================================================

# Libraries excluded by default: the ones a design must keep REFERENCING rather
# than copying — primitive/standard-cell libraries and read-only ones. The
# Cadence default exclude list, derived instead of hand-maintained.
#
# Match on the PRIMITIVE naming the PDKs share, not on the PDK's prefix. Every
# registry in this tree names its primitives `<pdk>_pr` (sky130_fd_pr,
# gf180mcu_pr, sg13g2_pr) and its cells `*stdcells`, while the DESIGN libraries
# that ship beside them are `sky130_tests`, `sky130_tests_ase`, `gf180mcu_tests`,
# `sg13g2_tests`, `mips_cpu`. A `sky130*`-style prefix glob swallows those design
# libraries — including, for a copy out of sky130_tests_ase, the source library
# itself, which would leave the traversal with nothing to copy.
#
# `srclib` is never excluded, whatever it is named: excluding the library you
# are copying out of is always a mistake.
proc copyform::default_excludes {{srclib {}}} {
  set out {}
  foreach pair [library_list] {
    lassign $pair name path
    if {$name eq $srclib} { continue }
    if {$name eq "devices" || [string match "*_pr" $name] || [string match "*stdcells" $name]} {
      lappend out $name
      continue
    }
    # a library you cannot write is one you cannot be maintaining: reference it
    if {$path ne {} && [file isdirectory $path] && ![file writable $path]} { lappend out $name }
  }
  return [lsort -unique $out]
}

proc copyform::init {lib cell} {
  variable st
  variable rows
  variable hcache
  variable editing
  array unset st
  array set st [list \
    srclib      $lib \
    srccell     $cell \
    dstlib      $lib \
    dstcell     $cell \
    viewmode    all \
    viewsel     {} \
    viewfilter  {} \
    hier        0 \
    excl        [copyform::default_excludes $lib] \
    updaterefs  copies \
    prefix      {} \
    suffix      {} \
  ]
  set rows {}
  set hcache {}
  set xcache {}
  set editing -1
  copyform::rows_build
}

# --- the table of cells: decisions, no widgets -------------------------------
#
# `rows` is the table: one {lib cell depth name on edited} per cell. Row 0 is
# the cell being copied; the rest, present only while Copy Hierarchical is
# ticked, are the cells below it (copyform::hier).
#   name    what the copy is called (row 0: the form's To cell)
#   on      1 = copy it or point at a cell of that name, 0 = leave references
#           to the original alone
#   edited  1 once the user set name or on by hand; such a row keeps what the
#           user chose when the table is rebuilt

# The name the form proposes for the copy of CHILD, a cell below the one being
# copied, once that one is renamed TOPSRC -> TOPDST. Two naming habits are
# followed and nothing else is guessed:
#   * a bench is named after what it tests: copying my_buf3_tb as fast_buf3_tb
#     proposes fast_buf3 for my_buf3 (the child's name is inside the old name,
#     and what surrounds it there surrounds the new name too);
#   * a block is named after its owner: copying my_buf3 as fast_buf3 proposes
#     fast_buf3_bias for my_buf3_bias.
# Otherwise the child keeps its name.
proc copyform::suggest {topsrc topdst child} {
  if {$topsrc eq $topdst || $child eq {} || $topdst eq {}} { return $child }
  set i [string first $child $topsrc]
  if {$i >= 0 && $child ne $topsrc} {
    set pre  [string range $topsrc 0 [expr {$i - 1}]]
    set post [string range $topsrc [expr {$i + [string length $child]}] end]
    set n  [string length $topdst]
    set lp [string length $pre]
    set lq [string length $post]
    if {$n > $lp + $lq && [string range $topdst 0 [expr {$lp - 1}]] eq $pre &&
        [string range $topdst [expr {$n - $lq}] end] eq $post} {
      return [string range $topdst $lp [expr {$n - $lq - 1}]]
    }
  }
  set i [string first $topsrc $child]
  if {$i >= 0} {
    return [string range $child 0 [expr {$i - 1}]]$topdst[string range $child [expr {$i + [string length $topsrc]}] end]
  }
  return $child
}

# The name a row gets when the user has not typed one.
proc copyform::default_name {cell} {
  variable st
  return $st(prefix)[copyform::suggest $st(srccell) [string trim $st(dstcell)] $cell]$st(suffix)
}

# Is a cell below the one being copied copied by default? Yes when the form has
# a new place or a new name for it: a copy into another library takes the
# hierarchy along, a copy inside one library takes only the cells a name was
# proposed for. So copying a bench inside its library never duplicates a block
# by surprise.
proc copyform::default_on {lib cell name} {
  variable st
  if {$st(dstlib) ne $st(srclib)} { return [expr {!($st(dstlib) eq $lib && $name eq $cell)}] }
  return [expr {$name ne $cell}]
}

# The hierarchy below the cell being copied, remembered until the excluded
# libraries change or a rescan is asked for (the form asks again on every
# keystroke in a name field, and the answer is a walk over schematic files).
proc copyform::hier_cached {} {
  variable st
  variable hcache
  set key [list $st(srclib) $st(srccell) $st(excl)]
  if {[lindex $hcache 0] ne $key} { set hcache [list $key [copyform::hier $st(srclib) $st(srccell) $st(excl)]] }
  return [lindex $hcache 1]
}

# copyform::library_referrers for the form, remembered while the plan replaces
# the same originals in the same libraries: which cells of a library use them
# does not change with the NAME a copy is given, and the form asks on every
# keystroke.
proc copyform::referrers_cached {plan} {
  variable xcache
  set key {}
  foreach row [dict get $plan cells] {
    lassign $row sl sc dl dc act
    if {$act ne "keep"} { lappend key [list $sl $sc $dl [expr {$act eq "copy" ? $dc : {}}]] }
  }
  if {[lindex $xcache 0] ne $key} { set xcache [list $key [copyform::library_referrers $plan]] }
  return [lindex $xcache 1]
}

proc copyform::rows_build {} {
  variable st
  variable rows
  set old $rows
  set rows [list [list $st(srclib) $st(srccell) 0 [string trim $st(dstcell)] 1 0]]
  if {!$st(hier)} return
  foreach h [copyform::hier_cached] {
    lassign $h l c depth
    set mine {}
    foreach r $old {
      if {[lindex $r 0] eq $l && [lindex $r 1] eq $c && [lindex $r 5]} { set mine $r }
    }
    if {$mine ne {}} {
      lappend rows [lreplace $mine 2 2 $depth]
      continue
    }
    set name [copyform::default_name $c]
    lappend rows [list $l $c $depth $name [copyform::default_on $l $c $name] 0]
  }
}

# What the plan does with row IDX: copy | use | keep (copyform::plan_why says
# what each means). Row 0 is always copied. A row that is on becomes `use` when
# a cell of its name is already in the destination library: nothing is copied
# over it, references are pointed at it. That is also how a bench is copied
# AFTER its new device already exists.
proc copyform::row_action {row idx} {
  variable st
  lassign $row l c depth name on
  if {$idx == 0} { return copy }
  if {!$on || $name eq {}} { return keep }
  if {$st(dstlib) eq $l && $name eq $c} { return keep }
  if {[library_cell_layout $st(dstlib) $name] ne {}} { return use }
  return copy
}

proc copyform::action_label {act} {
  switch -exact -- $act {
    copy { return "Copy" }
    use  { return "Use existing" }
    keep { return "Keep" }
  }
  return $act
}

# Name row IDX by hand. Row 0 is the form's To cell.
proc copyform::row_set_name {idx name} {
  variable st
  variable rows
  set name [string trim $name]
  if {$idx < 0 || $idx >= [llength $rows]} { return 0 }
  if {$idx == 0} {
    set st(dstcell) $name
  } else {
    set r [lindex $rows $idx]
    lset rows $idx [lreplace $r 3 5 $name [expr {$name ne {}}] 1]
  }
  return 1
}

# Switch row IDX between copied and kept. Row 0 has no such switch.
proc copyform::row_toggle {idx} {
  variable rows
  if {$idx <= 0 || $idx >= [llength $rows]} { return 0 }
  set r [lindex $rows $idx]
  lset rows $idx [lreplace $r 4 5 [expr {![lindex $r 4]}] 1]
  return 1
}

# The plan: everything copyform::execute needs, as plain data. `views` is the
# view choice resolved against the cell being copied (what the form shows);
# the engine resolves the same choice again for every other cell it copies.
proc copyform::plan {} {
  variable st
  variable rows
  if {![llength $rows]} { copyform::rows_build }
  set cells {}
  set i 0
  foreach r $rows {
    lassign $r l c depth name on
    if {$i == 0} { set name [string trim $st(dstcell)] }
    lappend cells [list $l $c $st(dstlib) $name [copyform::row_action $r $i]]
    incr i
  }
  return [list \
    src        [list $st(srclib) $st(srccell)] \
    dst        [list $st(dstlib) [string trim $st(dstcell)]] \
    views      [copyform::match_views $st(srclib) $st(srccell) \
                  $st(viewmode) $st(viewsel) $st(viewfilter)] \
    viewmode   $st(viewmode) \
    viewsel    $st(viewsel) \
    viewfilter $st(viewfilter) \
    hier       $st(hier) \
    exclude    $st(excl) \
    updaterefs $st(updaterefs) \
    prefix     $st(prefix) \
    suffix     $st(suffix) \
    cells      $cells]
}

# The part of a plan the engine reads, without the rows it does nothing with:
# what the action log records, so a replay runs the same copy.
proc copyform::plan_min {plan} {
  set cells {}
  foreach row [dict get $plan cells] {
    if {[lindex $row 4] ne "keep"} { lappend cells $row }
  }
  set out [dict create cells $cells]
  foreach k {viewmode viewsel viewfilter updaterefs} {
    if {[dict exists $plan $k]} { dict set out $k [dict get $plan $k] }
  }
  if {[dict exists $out viewmode] && [dict get $out viewmode] eq "all"} {
    dict unset out viewmode
    dict unset out viewsel
    dict unset out viewfilter
  }
  return $out
}

# What a plan will do, in one line, for the form's status bar.
proc copyform::plan_summary {plan} {
  set n(copy) 0
  set n(use) 0
  set n(keep) 0
  foreach row [dict get $plan cells] { incr n([lindex $row 4]) }
  set parts [list "$n(copy) cell[expr {$n(copy) == 1 ? {} : {s}}] to copy"]
  if {$n(use)}  { lappend parts "$n(use) already there (references go to [expr {$n(use) == 1 ? {it} : {them}}])" }
  if {$n(keep)} { lappend parts "$n(keep) kept (still referenced where [expr {$n(keep) == 1 ? {it is} : {they are}}])" }
  return [join $parts {; }]
}

# ===========================================================================
# the form
# ===========================================================================

proc copyform::status {msg} { catch {.libmgr.cp.status configure -text $msg} }

# Blocking entry point: build, wait, return the plan dict (or {} on Cancel).
proc copyform::open {lib cell} {
  variable done
  variable result
  copyform::init $lib $cell
  set result {}
  copyform::build
  set done -1
  vwait copyform::done
  copyform::release
  catch {destroy .libmgr.cp}
  return $result
}

proc copyform::build {} {
  variable st
  set w .libmgr.cp
  catch {destroy $w}
  catch {slickprop::init_fonts}      ;# same named fonts as save_as_form / property_form
  toplevel $w
  wm title $w "Copy Cell"
  catch {wm transient $w .libmgr}
  # The WM close button must land on the same exit path as Cancel, or the vwait
  # in copyform::open is left waiting on a latch nobody sets (on_destroy is the
  # backstop, this is the explicit route).
  wm protocol $w WM_DELETE_WINDOW copyform::cancel

  # --- From ---------------------------------------------------------------
  ttk::labelframe $w.src -text "From" -padding 8
  ttk::label $w.src.l1 -text "Library:" -anchor w
  ttk::label $w.src.v1 -textvariable copyform::st(srclib)  -anchor w
  ttk::label $w.src.l2 -text "Cell:"    -anchor w
  ttk::label $w.src.v2 -textvariable copyform::st(srccell) -anchor w
  grid $w.src.l1 $w.src.v1 -sticky w -padx {0 10} -pady 2
  grid $w.src.l2 $w.src.v2 -sticky w -padx {0 10} -pady 2
  grid columnconfigure $w.src 1 -weight 1

  # --- To -----------------------------------------------------------------
  ttk::labelframe $w.dst -text "To" -padding 8
  ttk::label    $w.dst.l1 -text "Library:" -anchor w
  ttk::combobox $w.dst.lib -state readonly -width 26 \
                -values [libmgr::lib_names] -textvariable copyform::st(dstlib)
  ttk::label    $w.dst.l2 -text "Cell:" -anchor w
  ttk::entry    $w.dst.cell -width 28 -textvariable copyform::st(dstcell)
  grid $w.dst.l1 $w.dst.lib  -sticky w  -padx {0 10} -pady 2
  grid $w.dst.l2 $w.dst.cell -sticky we -padx {0 10} -pady 2
  grid columnconfigure $w.dst 1 -weight 1
  # the names proposed below follow the name and the library typed here
  bind $w.dst.cell <KeyRelease> {copyform::refresh_table}
  bind $w.dst.lib <<ComboboxSelected>> {copyform::refresh_table}

  # --- Views --------------------------------------------------------------
  # Three exclusive modes; only the active one's widget is enabled, so the form
  # states what it will copy without a modal sub-dialog.
  ttk::labelframe $w.vw -text "Views" -padding 8
  ttk::radiobutton $w.vw.rall -text "All views" \
    -variable copyform::st(viewmode) -value all      -command copyform::sync_viewmode
  ttk::radiobutton $w.vw.rsel -text "Selected views:" \
    -variable copyform::st(viewmode) -value selected -command copyform::sync_viewmode
  ttk::radiobutton $w.vw.rflt -text "Filter:" \
    -variable copyform::st(viewmode) -value filter   -command copyform::sync_viewmode
  listbox $w.vw.lb -selectmode extended -exportselection 0 -height 5 -width 30 \
          -yscrollcommand "$w.vw.sb set" -activestyle dotbox
  ttk::scrollbar $w.vw.sb -orient vertical -command "$w.vw.lb yview"
  ttk::entry $w.vw.flt -width 30 -textvariable copyform::st(viewfilter)
  ttk::label $w.vw.hint -anchor w -justify left \
    -text "view names and/or type:<type> — type:symbol, type:schematic,\ntype:state (all ASE states), type:ngspice_state, globs ok"
  catch {$w.vw.hint configure -font slickPropHint}
  grid $w.vw.rall -row 0 -column 0 -columnspan 3 -sticky w -pady 1
  grid $w.vw.rsel -row 1 -column 0 -sticky nw -pady 1
  grid $w.vw.lb   -row 1 -column 1 -sticky nsew -pady 1
  grid $w.vw.sb   -row 1 -column 2 -sticky ns   -pady 1
  grid $w.vw.rflt -row 2 -column 0 -sticky w  -pady {4 1}
  grid $w.vw.flt  -row 2 -column 1 -sticky we -pady {4 1}
  grid $w.vw.hint -row 3 -column 1 -sticky w
  grid columnconfigure $w.vw 1 -weight 1

  foreach {v t} [copyform::cell_view_types $st(srclib) $st(srccell)] {
    $w.vw.lb insert end [format "%-16s %s" $v "($t)"]
  }

  # --- the reveal ---------------------------------------------------------
  ttk::checkbutton $w.hchk -text "Copy Hierarchical" \
    -variable copyform::st(hier) -command copyform::sync_hier

  # --- hierarchical section (revealed by the checkbox) --------------------
  ttk::labelframe $w.h -text "Hierarchy" -padding 8

  ttk::label $w.h.le -text "Exclude libraries (cells stay referenced in place):" -anchor w
  listbox $w.h.excl -selectmode extended -exportselection 0 -height 6 -width 24 \
          -yscrollcommand "$w.h.esb set" -activestyle dotbox
  ttk::scrollbar $w.h.esb -orient vertical -command "$w.h.excl yview"
  ttk::frame $w.h.eb
  ttk::button $w.h.eb.def  -text "Defaults" -width 9 -command copyform::excl_defaults
  ttk::button $w.h.eb.none -text "None"     -width 9 \
    -command {.libmgr.cp.h.excl selection clear 0 end; copyform::refresh_table}
  ttk::button $w.h.eb.all  -text "All"      -width 9 \
    -command {.libmgr.cp.h.excl selection set 0 end; copyform::refresh_table}
  pack $w.h.eb.def $w.h.eb.none $w.h.eb.all -side top -pady 2
  bind $w.h.excl <<ListboxSelect>> {copyform::refresh_table}

  # Update-references scope, Cadence's three-way "Update Instances":
  #   none    — every instance in the copies still binds to the ORIGINAL cells.
  #             An exact snapshot that keeps tracking the golden cells, and what
  #             you want when the re-pointing is done later by other means.
  #   copies  — instances inside the newly copied cells are re-pointed to the
  #             copies (the default, and what "hierarchical copy" usually means).
  #   library — cells ALREADY in the destination library that reference the
  #             originals are re-pointed as well. It edits cells the user did
  #             not pick, so the table lists each of them before OK is pressed.
  ttk::frame       $w.h.ur
  ttk::label       $w.h.ur.l -text "Update instance references:" -anchor w
  ttk::radiobutton $w.h.ur.none   -text "None" \
    -variable copyform::st(updaterefs) -value none    -command copyform::sync_refs
  ttk::radiobutton $w.h.ur.copies -text "New copies only" \
    -variable copyform::st(updaterefs) -value copies  -command copyform::sync_refs
  ttk::radiobutton $w.h.ur.lib    -text "Entire destination library" \
    -variable copyform::st(updaterefs) -value library -command copyform::sync_refs
  pack $w.h.ur.l $w.h.ur.none $w.h.ur.copies $w.h.ur.lib -side left -padx {0 10}
  # Name mapping. The widgets are children of the row frame — packing foreign
  # children into it with -in leaves the frame itself 1x1 and the row vanishes.
  ttk::frame $w.h.nm
  ttk::label $w.h.nm.lp  -text "Name prefix:" -anchor w
  ttk::entry $w.h.nm.pre -width 12 -textvariable copyform::st(prefix)
  ttk::label $w.h.nm.ls  -text "suffix:" -anchor w
  ttk::entry $w.h.nm.suf -width 12 -textvariable copyform::st(suffix)
  pack $w.h.nm.lp $w.h.nm.pre $w.h.nm.ls $w.h.nm.suf -side left -padx {0 6}
  bind $w.h.nm.pre <KeyRelease> {copyform::refresh_table}
  bind $w.h.nm.suf <KeyRelease> {copyform::refresh_table}

  ttk::label $w.h.lt -anchor w \
    -text "Cells (double-click a new name to change it, click Action to switch Copy and Keep):"
  # treeview + its scrollbar live in one frame so the bar stays glued to the
  # table instead of drifting out to the exclude-buttons column.
  ttk::frame $w.h.tvf
  ttk::treeview $w.h.tvf.tv -columns {lib cell name action} -show headings -height 6 \
                -selectmode browse -yscrollcommand "$w.h.tvf.sb set"
  ttk::scrollbar $w.h.tvf.sb -orient vertical -command "$w.h.tvf.tv yview"
  foreach {c title width} {lib Library 150 cell Cell 190 name {New name} 190 action Action 100} {
    $w.h.tvf.tv heading $c -text $title
    $w.h.tvf.tv column  $c -width $width -anchor w
  }
  grid $w.h.tvf.tv -row 0 -column 0 -sticky nsew
  grid $w.h.tvf.sb -row 0 -column 1 -sticky ns
  grid rowconfigure    $w.h.tvf 0 -weight 1
  grid columnconfigure $w.h.tvf 0 -weight 1
  # the name being typed: an entry laid over the cell (copyform::edit_begin)
  ttk::entry $w.h.tvf.tv.ed -textvariable copyform::edit_text
  bind $w.h.tvf.tv.ed <Return>   {copyform::edit_commit; break}
  bind $w.h.tvf.tv.ed <KP_Enter> {copyform::edit_commit; break}
  bind $w.h.tvf.tv.ed <Escape>   {copyform::edit_cancel; break}
  bind $w.h.tvf.tv.ed <FocusOut> {copyform::edit_focusout %W}
  bind $w.h.tvf.tv <Double-1> {copyform::table_click %x %y 2; break}
  bind $w.h.tvf.tv <ButtonRelease-1> {copyform::table_click %x %y 1}
  bind $w.h.tvf.tv <Key-F2>    {copyform::edit_begin [copyform::table_row]; break}
  bind $w.h.tvf.tv <Key-space> {copyform::table_toggle [copyform::table_row]; break}
  ttk::frame  $w.h.tb
  ttk::button $w.h.tb.ren  -text "Rename" \
    -command {copyform::edit_begin [copyform::table_row]}
  ttk::button $w.h.tb.tog  -text "Copy / Keep" \
    -command {copyform::table_toggle [copyform::table_row]}
  ttk::button $w.h.scan -text "Rescan" -command {copyform::refresh_table 1}
  pack $w.h.tb.ren $w.h.tb.tog -side left -padx {0 6}

  grid $w.h.le   -row 0 -column 0 -columnspan 3 -sticky w -pady {0 2}
  grid $w.h.excl -row 1 -column 0 -sticky nsew
  grid $w.h.esb  -row 1 -column 1 -sticky ns
  grid $w.h.eb   -row 1 -column 2 -sticky nw -padx {8 0}
  grid $w.h.ur   -row 2 -column 0 -columnspan 3 -sticky w -pady {8 2}
  grid $w.h.nm   -row 4 -column 0 -columnspan 3 -sticky w -pady 2
  grid $w.h.lt   -row 5 -column 0 -columnspan 3 -sticky w -pady {8 2}
  grid $w.h.tvf  -row 6 -column 0 -columnspan 3 -sticky nsew
  grid $w.h.tb   -row 7 -column 0 -sticky w -pady {6 0}
  grid $w.h.scan -row 7 -column 2 -sticky e -pady {6 0}
  grid rowconfigure    $w.h 6 -weight 1
  grid columnconfigure $w.h 0 -weight 1

  # --- status + buttons ---------------------------------------------------
  ttk::label $w.status -anchor w -relief sunken -padding {4 2} -text ""
  ttk::frame $w.b
  ttk::button $w.b.ok     -text OK     -command copyform::accept
  ttk::button $w.b.cancel -text Cancel -command copyform::cancel
  pack $w.b.ok -side left -padx 4 -pady 4
  pack $w.b.cancel -side right -padx 4 -pady 4

  grid $w.src  -row 0 -column 0 -sticky nsew -padx 8 -pady {8 4}
  grid $w.dst  -row 1 -column 0 -sticky nsew -padx 8 -pady 4
  grid $w.vw   -row 2 -column 0 -sticky nsew -padx 8 -pady 4
  grid $w.hchk -row 3 -column 0 -sticky w    -padx 12 -pady {6 2}
  grid $w.h    -row 4 -column 0 -sticky nsew -padx 8 -pady 4
  grid $w.status -row 5 -column 0 -sticky we
  grid $w.b      -row 6 -column 0 -sticky we
  grid columnconfigure $w 0 -weight 1
  grid rowconfigure    $w 4 -weight 1

  bind $w <Return> {copyform::accept}
  bind $w <Escape> {copyform::cancel}
  bind $w <Destroy> {if {{%W} eq {.libmgr.cp}} {copyform::on_destroy}}

  copyform::excl_defaults
  copyform::sync_hier
  copyform::sync_viewmode
  catch {raise_activate_toplevel $w}
  # Modal like every other Library Manager dialog (cell_dialog, view_dialog,
  # maintain_picker): without the grab the user can re-select in the panes
  # underneath and the form's From fields go stale. .libmgr.cp is a child PATH
  # of .libmgr, so any sub-toplevel added later stays live under this grab.
  catch {grab $w}
  catch {focus -force $w.dst.cell; $w.dst.cell selection range 0 end}
}

# Reveal / hide the hierarchical block. `grid remove` keeps the row config, and
# clearing wm geometry lets the toplevel shrink back to the collapsed size
# instead of leaving a hole where the section was.
proc copyform::sync_hier {} {
  variable st
  set w .libmgr.cp
  if {![winfo exists $w]} return
  if {$st(hier)} {
    grid $w.h -row 4 -column 0 -sticky nsew -padx 8 -pady 4
  } else {
    grid remove $w.h
  }
  # refresh_table sets the status LAST; do not set one after it or it is clobbered.
  copyform::refresh_table
  catch {wm geometry $w {}}
}

# Say on the status bar what the chosen scope actually does: the three-way is
# easy to misread, and "None" produces copies whose instances still bind to the
# originals. The table is rebuilt first, because "Entire destination library"
# adds the rows of the cells it would edit.
proc copyform::sync_refs {} {
  variable st
  copyform::refresh_table
  switch -- $st(updaterefs) {
    none    { copyform::status "None: instances in the copies keep pointing at the ORIGINAL cells (exact snapshot)" }
    copies  { copyform::status "New copies only: instances inside the copied cells are pointed at the copies" }
    library {
      set n 0
      catch {set n [llength [lsearch -all -glob [.libmgr.cp.h.tvf.tv children {}] x*]]}
      set lib [expr {$st(dstlib) eq {} ? {the destination} : $st(dstlib)}]
      copyform::status "Entire destination library: $n cell[expr {$n == 1 ? {} : {s}}] already in $lib re-pointed too[expr {$n ? { (listed below)} : {}}]"
    }
  }
}

proc copyform::sync_viewmode {} {
  variable st
  set w .libmgr.cp
  if {![winfo exists $w]} return
  $w.vw.lb  configure -state [expr {$st(viewmode) eq "selected" ? "normal" : "disabled"}]
  $w.vw.flt configure -state [expr {$st(viewmode) eq "filter"   ? "normal" : "disabled"}]
  if {$st(viewmode) eq "filter"} { catch {focus $w.vw.flt} }
}

proc copyform::excl_defaults {} {
  variable st
  set w .libmgr.cp.h.excl
  if {![winfo exists $w]} return
  $w delete 0 end
  set names [libmgr::lib_names]
  foreach n $names { $w insert end $n }
  set st(excl) [copyform::default_excludes $st(srclib)]
  set first -1
  foreach n $st(excl) {
    set i [lsearch -exact $names $n]
    if {$i >= 0} {
      $w selection set $i
      if {$first < 0 || $i < $first} { set first $i }
    }
  }
  # Scroll the first exclusion into view: with a real PDK registry the defaults
  # (sky130_fd_pr, sky130_stdcells, …) sit well below the fold, so an unscrolled
  # list reads as "nothing is excluded".
  if {$first >= 0} { $w see $first }
  copyform::refresh_table
}

# Pull the listbox selections back into the state array (the two multi-select
# listboxes have no -textvariable, so they are read on demand).
proc copyform::harvest {} {
  variable st
  set w .libmgr.cp
  if {![winfo exists $w]} return
  set sel {}
  foreach i [$w.h.excl curselection] { lappend sel [$w.h.excl get $i] }
  set st(excl) $sel
  set vs {}
  foreach i [$w.vw.lb curselection] { lappend vs [lindex [$w.vw.lb get $i] 0] }
  set st(viewsel) $vs
}

# Rebuild the table from the form: the cell being copied, the cells below it
# (Copy Hierarchical), and, for "Entire destination library", the cells already
# there that would be edited. The table IS the plan, shown before OK: every
# row says what happens to that cell. RESCAN 1 reads the schematics again.
proc copyform::refresh_table {{rescan 0}} {
  variable st
  variable rows
  variable hcache
  variable editing
  set tv .libmgr.cp.h.tvf.tv
  if {![winfo exists $tv]} return
  # A name still being typed is kept, not dropped: a click on a radio button or
  # on Rescan does not take the focus away from the name field, so nothing else
  # would have kept it. edit_commit comes back here once the name is in.
  if {$editing >= 0} {
    if {$rescan} {
      set hcache {}
      set copyform::xcache {}
    }
    copyform::edit_commit
    return
  }
  copyform::harvest
  if {$rescan} {
    set hcache {}
    set copyform::xcache {}
  }
  copyform::rows_build
  set sel [$tv selection]
  $tv delete [$tv children {}]
  set plan [copyform::plan]
  set i 0
  foreach r $rows row [dict get $plan cells] {
    lassign $r l c depth
    set act [lindex $row 4]
    $tv insert {} end -id r$i -values [list $l "[string repeat {   } $depth]$c" \
      [expr {$act eq "keep" ? {} : [lindex $row 3]}] [copyform::action_label $act]]
    incr i
  }
  set extra 0
  if {$st(hier) && $st(updaterefs) eq "library" && [copyform::plan_why $plan] eq {}} {
    foreach ref [copyform::referrers_cached $plan] {
      lassign $ref l c
      $tv insert {} end -id x$extra -values [list $l $c {} "Re-point"]
      incr extra
    }
  }
  foreach it $sel {
    if {[$tv exists $it]} { $tv selection set $it }
  }
  if {!$st(hier)} {
    copyform::status "flat copy: this cell only"
    return
  }
  set msg [copyform::plan_summary $plan]
  if {$extra} { append msg "; $extra cell[expr {$extra == 1 ? {} : {s}}] already in $st(dstlib) re-pointed too" }
  copyform::status $msg
}

# The table row that is selected, as an index into `rows`, or -1.
proc copyform::table_row {} {
  set tv .libmgr.cp.h.tvf.tv
  if {![winfo exists $tv]} { return -1 }
  if {[regexp {^r(\d+)$} [lindex [$tv selection] 0] -> idx]} { return $idx }
  return -1
}

# A click in the table. Double-click on a New name starts typing it; a click on
# an Action switches that row between copied and kept.
proc copyform::table_click {x y n} {
  set tv .libmgr.cp.h.tvf.tv
  if {![winfo exists $tv]} return
  if {[$tv identify region $x $y] ne "cell"} return
  if {![regexp {^r(\d+)$} [$tv identify item $x $y] -> idx]} return
  set col [$tv column [$tv identify column $x $y] -id]
  if {$n == 2 && $col eq "name"} {
    copyform::edit_begin $idx
  } elseif {$n == 1 && $col eq "action"} {
    copyform::table_toggle $idx
  }
}

# Switch a row between copied and kept, and show it. A row switched to copied
# whose name is still the original's, in the original's own library, cannot be
# a copy yet: the name field opens so the new name can be typed straight away.
proc copyform::table_toggle {idx} {
  variable rows
  variable st
  if {![copyform::row_toggle $idx]} return
  copyform::refresh_table
  set tv .libmgr.cp.h.tvf.tv
  catch {$tv selection set r$idx}
  set r [lindex $rows $idx]
  if {[lindex $r 4] && [copyform::row_action $r $idx] eq "keep"} {
    copyform::status "[lindex $r 1] stays in $st(dstlib): type a new name to copy it"
    copyform::edit_begin $idx
  }
}

# Type the name of row IDX in place: an entry laid over that cell of the table.
proc copyform::edit_begin {idx} {
  variable rows
  variable st
  variable editing
  variable edit_text
  set tv .libmgr.cp.h.tvf.tv
  if {![winfo exists $tv] || $idx < 0 || $idx >= [llength $rows]} return
  copyform::edit_commit
  if {![$tv exists r$idx]} return
  $tv see r$idx
  update idletasks
  set bb [$tv bbox r$idx name]
  if {[llength $bb] != 4} return
  lassign $bb x y w h
  set editing $idx
  set edit_text [expr {$idx == 0 ? [string trim $st(dstcell)] : [lindex $rows $idx 3]}]
  place $tv.ed -x $x -y $y -width $w -height $h
  focus $tv.ed
  $tv.ed selection range 0 end
  $tv.ed icursor end
}

proc copyform::edit_commit {} {
  variable editing
  variable edit_text
  if {$editing < 0} return
  set idx $editing
  set editing -1
  catch {place forget .libmgr.cp.h.tvf.tv.ed}
  copyform::row_set_name $idx $edit_text
  copyform::refresh_table
  catch {
    .libmgr.cp.h.tvf.tv selection set r$idx
    focus .libmgr.cp.h.tvf.tv
  }
}

# The name field lost the focus: keep what was typed. A FocusOut that arrives
# late, after the field was opened again and has the focus back, is not a
# reason to close it.
proc copyform::edit_focusout {w} {
  if {[focus] eq $w} return
  copyform::edit_commit
}

proc copyform::edit_cancel {} {
  variable editing
  if {$editing < 0} return
  set editing -1
  catch {place forget .libmgr.cp.h.tvf.tv.ed}
  catch {focus .libmgr.cp.h.tvf.tv}
}

# OK. A plan that cannot run is refused HERE, with the reason on the form's own
# status bar and everything the user typed still in front of them.
proc copyform::accept {} {
  variable st
  variable done
  variable result
  copyform::edit_commit
  copyform::harvest
  if {[string trim $st(dstcell)] eq {}} { copyform::status "destination cell name required"; return }
  if {$st(dstlib) eq {}} { copyform::status "destination library required"; return }
  if {$st(viewmode) eq "selected" && ![llength $st(viewsel)]} {
    copyform::status "pick at least one view, or choose All views"; return
  }
  if {$st(viewmode) eq "filter" && [string trim $st(viewfilter)] eq {}} {
    copyform::status "type a filter, or choose All views"; return
  }
  set st(dstcell) [string trim $st(dstcell)]
  copyform::rows_build
  set plan [copyform::plan]
  set why [copyform::plan_why $plan]
  if {$why ne {}} { copyform::status $why; return }
  set result $plan
  set done 1
}

proc copyform::cancel {} {
  variable done
  variable result
  set result {}
  set done 0
}

proc copyform::release {} { catch {grab release .libmgr.cp} }

proc copyform::on_destroy {} {
  variable done
  if {$done == -1} { set done 0 }
}
