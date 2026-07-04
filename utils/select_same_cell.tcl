# Ctrl-Alt-H "select all instances of the same cell / view".
# Loaded from cadence_style_rc, AFTER cadence_nav.tcl (cadence::selkind) and
# lib_mgr_helpers.tcl / library_defs.tcl (libmgr::selection, schematic_cellview,
# cellview_path, abs_sym_path). Pure Tcl, no C change -- the inverse of Ctrl-Alt-S
# (locate_selected_in_libmgr). See doc/claude/specs/select_same_cell.md.
#
# Identity model: a symbol view IS a specific .sym datafile, so
#   same lib/cell/view  <=> same normalized abs symbol path        (view mode)
#   same lib/cell        <=> same {lib cell} from schematic_cellview (cell mode)
# and a whole library is matched by that {lib} (lib mode).

namespace eval selsame {}

# ---- pure text parse -----------------------------------------------------
# First "lib/cell[/view]" slash token in $text -> {lib cell view} (view "" when only
# two components are present); {} if there is no lib/cell token. Charset \w, matching
# cadence::first_libcell. A three-component token wins over two.
proc selsame::parse_libcellview {text} {
  if {[regexp {(\w+)/(\w+)/(\w+)} $text -> lib cell view]} { return [list $lib $cell $view] }
  if {[regexp {(\w+)/(\w+)} $text -> lib cell]}            { return [list $lib $cell {}] }
  return {}
}

# ---- pure matcher --------------------------------------------------------
# idents = list of {idx lib cell view abs} (abs pre-normalized by the caller).
#   mode lib  : target = {lib}          -> inst.lib == lib (lib non-empty)
#   mode cell : target = {lib cell}     -> inst.lib/inst.cell == target (lib non-empty)
#   mode view : target = {lib cell abs} -> inst.abs == abs; a same lib/cell instance with
#               a different abs is reported in 'other' (a different symbol view, not added)
# Returns {matched other}: matched = list of idx, other = list of {idx view}.
proc selsame::match {mode target idents} {
  set matched {}; set other {}
  foreach it $idents {
    lassign $it idx lib cell view abs
    switch -- $mode {
      lib {
        if {$lib ne "" && $lib eq [lindex $target 0]} { lappend matched $idx }
      }
      cell {
        if {$lib ne "" && $lib eq [lindex $target 0] && $cell eq [lindex $target 1]} {
          lappend matched $idx
        }
      }
      view {
        lassign $target tlib tcell tabs
        if {$abs ne "" && $abs eq $tabs} {
          lappend matched $idx
        } elseif {$tlib ne "" && $lib eq $tlib && $cell eq $tcell} {
          lappend other [list $idx $view]
        }
      }
    }
  }
  return [list $matched $other]
}

# ---- per-instance identity (needs the running engine + registry) ---------
# {lib cell view abs} for instance index $i. abs = normalized resolved symbol datafile
# ("" if unresolvable); lib/cell/view from schematic_cellview ("" when the symbol is not
# under a registered library -- then only abs-path (view-mode) matching is meaningful).
proc selsame::inst_ident {i} {
  set ref [xschem getprop instance $i cell::name]
  set abs [abs_sym_path $ref]
  if {$abs ne ""} { set abs [file normalize $abs] }
  lassign [schematic_cellview $abs] lib cell view
  return [list $lib $cell $view $abs]
}

# ---- reference resolution ------------------------------------------------
# The Library-Manager decision, factored out of the winfo/libmgr plumbing so it is
# testable with a real registry: sel = {} | {lib} | {lib cell} | {lib cell view}.
# A .sym (symbol-type) view -> view mode; a .sch/unresolved view -> cell mode
# (per the spec: a schematic-type view == no symbol view selected).
proc selsame::target_from_libsel {sel} {
  switch -- [llength $sel] {
    1 { lassign $sel lib      ; return [list lib  [list $lib]       "library $lib"] }
    2 { lassign $sel lib cell ; return [list cell [list $lib $cell] "$lib/$cell (any view)"] }
    3 {
      lassign $sel lib cell view
      set f [xschem cellview_path "$lib/$cell" $view]
      if {[string match *.sym $f]} {
        return [list view [list $lib $cell [file normalize $f]] "$lib/$cell/$view"]
      }
      return [list cell [list $lib $cell] "$lib/$cell (any view)"]
    }
    default { return {} }
  }
}

proc selsame::target_from_libmgr {} {
  if {![llength [info commands winfo]] || ![winfo exists .libmgr]} {
    ciw_echo "nothing selected, and the Library Manager is not open" error ; return {}
  }
  set sel [libmgr::selection]
  if {![llength $sel]} {
    ciw_echo "select a library, cell or view in the Library Manager first" error ; return {}
  }
  return [selsame::target_from_libsel $sel]
}

# {mode target label} for the current context, or {} (after a CIW hint) if nothing usable.
proc selsame::target {} {
  set k [cadence::selkind]
  switch -- [lindex $k 0] {
    inst {
      lassign [selsame::inst_ident [lindex $k 1]] lib cell view abs
      if {$abs eq ""} { ciw_echo "cannot resolve the selected instance's symbol" error ; return {} }
      set lbl [expr {$lib ne "" ? "$lib/$cell/$view" : [file tail $abs]}]
      return [list view [list $lib $cell $abs] $lbl]
    }
    text {
      set p [selsame::parse_libcellview [lindex $k 2]]
      if {$p eq {}} { ciw_echo "no lib/cell(/view) token in the selected note" error ; return {} }
      lassign $p lib cell view
      if {$view eq ""} { return [list cell [list $lib $cell] "$lib/$cell (any view)"] }
      set f [xschem cellview_path "$lib/$cell" $view]
      if {$f eq ""} { ciw_echo "no $view view for $lib/$cell" error ; return {} }
      return [list view [list $lib $cell [file normalize $f]] "$lib/$cell/$view"]
    }
    none    { return [selsame::target_from_libmgr] }
    default {
      ciw_echo "select one instance, one lib/cell(/view) note, or nothing (use the Library Manager)" error
      return {}
    }
  }
}

# ---- the action entry point (global proc, named by the .drw binding) -----
proc select_same_cell {} {
  set spec [selsame::target]
  if {$spec eq {}} return
  lassign $spec mode target label

  # identity of every instance at the current schematic level
  set idents {}
  set n [xschem get instances]
  for {set i 0} {$i < $n} {incr i} {
    lappend idents [linsert [selsame::inst_ident $i] 0 $i]
  }
  lassign [selsame::match $mode $target $idents] matched other

  # replace the current selection with the matches
  xschem unselect_all
  foreach i $matched { xschem select instance $i }
  xschem redraw

  ciw_echo "selected [llength $matched] instance(s) of $label"
  if {$mode eq "view" && [llength $other]} {
    lassign $target tlib tcell
    set views {}
    foreach o $other {
      set v [lindex $o 1]
      if {$v ne "" && [lsearch -exact $views $v] < 0} { lappend views $v }
    }
    set vtxt [expr {[llength $views] ? " ([join $views {, }])" : ""}]
    ciw_echo "warning: [llength $other] instance(s) of $tlib/$tcell use a different symbol view (not selected)$vtxt" error
  }
}
