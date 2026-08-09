# copy_form.tcl — Cadence-style Copy form for the Library Manager (pass 1).
# Spec: doc/claude/specs/copy_hierarchical.md
#
# Replaces the two-field libmgr::cell_dialog that RMB > Copy on a CELL used to
# pop. Same job in the collapsed state (destination library + new cell name),
# but it also carries the two things the old dialog could not express:
#
#   * a VIEW SPEC — all views (the Cadence default), an explicit pick from the
#     source cell's actual views, or a filter expression that understands
#     `type:<type>` (e.g. `type:symbol` = every view of symbol type).
#   * a HIERARCHICAL toggle — off, the form is exactly the flat copy the user
#     has today; on, the hierarchical section is REVEALED (exclude-library list,
#     reference handling, name mapping, and the cell table that says what would
#     be copied).
#
# PASS 1 IS LOOK-AND-FEEL. The flat path is wired to the real backend
# (libmgr::do_copy_cell -> library_copy_cell); the hierarchical path and the
# non-"all" view spec build a PLAN dict and stop. copyform::plan is the seam:
# it is pure data, needs no widgets, and is what pass 2 will hand to the
# traversal/copy engine. See "PASS 2 SEAM" at the bottom of this file.
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
    conflict    skip \
    prefix      {} \
    suffix      {} \
  ]
}

# The PASS 2 SEAM. Pure data, no widgets: everything the copy engine needs.
# `views` is already resolved against the source cell.
proc copyform::plan {} {
  variable st
  return [list \
    src        [list $st(srclib) $st(srccell)] \
    dst        [list $st(dstlib) $st(dstcell)] \
    views      [copyform::match_views $st(srclib) $st(srccell) \
                  $st(viewmode) $st(viewsel) $st(viewfilter)] \
    viewmode   $st(viewmode) \
    viewfilter $st(viewfilter) \
    hier       $st(hier) \
    exclude    $st(excl) \
    updaterefs $st(updaterefs) \
    conflict   $st(conflict) \
    prefix     $st(prefix) \
    suffix     $st(suffix)]
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
  ttk::button $w.h.eb.none -text "None"     -width 9 -command {.libmgr.cp.h.excl selection clear 0 end}
  ttk::button $w.h.eb.all  -text "All"      -width 9 -command {.libmgr.cp.h.excl selection set 0 end}
  pack $w.h.eb.def $w.h.eb.none $w.h.eb.all -side top -pady 2

  # Update-references scope, Cadence's three-way "Update Instances":
  #   none    — copy the tree verbatim; every instance in the copies still binds
  #             to the ORIGINAL libraries. An exact/archival snapshot: the copy
  #             keeps tracking the golden cells, and it is also what you want
  #             when the retarget is done later by other means.
  #   copies  — retarget instances inside the newly copied cells to the copies
  #             (the default, and what "hierarchical copy" usually means).
  #   library — also fix up cells ALREADY in the destination library that
  #             reference the originals. Widest blast radius; touches cells the
  #             user did not select.
  ttk::frame       $w.h.ur
  ttk::label       $w.h.ur.l -text "Update instance references:" -anchor w
  ttk::radiobutton $w.h.ur.none   -text "None" \
    -variable copyform::st(updaterefs) -value none    -command copyform::sync_refs
  ttk::radiobutton $w.h.ur.copies -text "New copies only" \
    -variable copyform::st(updaterefs) -value copies  -command copyform::sync_refs
  ttk::radiobutton $w.h.ur.lib    -text "Entire destination library" \
    -variable copyform::st(updaterefs) -value library -command copyform::sync_refs
  pack $w.h.ur.l $w.h.ur.none $w.h.ur.copies $w.h.ur.lib -side left -padx {0 10}
  ttk::frame    $w.h.cf
  ttk::label    $w.h.cf.lc -text "On name conflict:" -anchor w
  ttk::combobox $w.h.cf.conf -state readonly -width 12 \
                -values {skip rename overwrite} -textvariable copyform::st(conflict)
  pack $w.h.cf.lc $w.h.cf.conf -side left -padx {0 6}
  # Name mapping. The widgets are children of the row frame — packing foreign
  # children into it with -in leaves the frame itself 1x1 and the row vanishes.
  ttk::frame $w.h.nm
  ttk::label $w.h.nm.lp  -text "Name prefix:" -anchor w
  ttk::entry $w.h.nm.pre -width 12 -textvariable copyform::st(prefix)
  ttk::label $w.h.nm.ls  -text "suffix:" -anchor w
  ttk::entry $w.h.nm.suf -width 12 -textvariable copyform::st(suffix)
  pack $w.h.nm.lp $w.h.nm.pre $w.h.nm.ls $w.h.nm.suf -side left -padx {0 6}

  ttk::label $w.h.lt -text "Cells to copy:" -anchor w
  # treeview + its scrollbar live in one frame so the bar stays glued to the
  # table instead of drifting out to the exclude-buttons column.
  ttk::frame $w.h.tvf
  ttk::treeview $w.h.tvf.tv -columns {lib cell views action} -show headings -height 6 \
                -yscrollcommand "$w.h.tvf.sb set"
  ttk::scrollbar $w.h.tvf.sb -orient vertical -command "$w.h.tvf.tv yview"
  foreach {c title width} {lib Library 165 cell Cell 140 views Views 240 action Action 80} {
    $w.h.tvf.tv heading $c -text $title
    $w.h.tvf.tv column  $c -width $width -anchor w
  }
  grid $w.h.tvf.tv -row 0 -column 0 -sticky nsew
  grid $w.h.tvf.sb -row 0 -column 1 -sticky ns
  grid rowconfigure    $w.h.tvf 0 -weight 1
  grid columnconfigure $w.h.tvf 0 -weight 1
  ttk::button $w.h.scan -text "Update table" -command copyform::refresh_table

  grid $w.h.le   -row 0 -column 0 -columnspan 3 -sticky w -pady {0 2}
  grid $w.h.excl -row 1 -column 0 -sticky nsew
  grid $w.h.esb  -row 1 -column 1 -sticky ns
  grid $w.h.eb   -row 1 -column 2 -sticky nw -padx {8 0}
  grid $w.h.ur   -row 2 -column 0 -columnspan 3 -sticky w -pady {8 2}
  grid $w.h.cf   -row 3 -column 0 -columnspan 3 -sticky w -pady 2
  grid $w.h.nm   -row 4 -column 0 -columnspan 3 -sticky w -pady 2
  grid $w.h.lt   -row 5 -column 0 -columnspan 3 -sticky w -pady {8 2}
  grid $w.h.tvf  -row 6 -column 0 -columnspan 3 -sticky nsew
  grid $w.h.scan -row 7 -column 0 -sticky w -pady {6 0}
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
    # refresh_table sets the status LAST (it names the excluded libraries, which
    # is the more useful message); do not set one after it or it is clobbered.
    copyform::refresh_table
  } else {
    grid remove $w.h
    copyform::status "flat copy: this cell only"
  }
  catch {wm geometry $w {}}
}

# Say on the status bar what the chosen scope actually does — the three-way is
# easy to misread, and "None" silently produces copies that still simulate
# against the source library.
proc copyform::sync_refs {} {
  variable st
  switch -- $st(updaterefs) {
    none    { copyform::status "None: copies keep pointing at the ORIGINAL libraries (exact snapshot)" }
    copies  { copyform::status "New copies only: instances inside the copied cells bind to the copies" }
    library { copyform::status "Entire destination library: also retargets cells already in [expr {$st(dstlib) eq {} ? {the destination} : $st(dstlib)}]" }
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

# PASS 1: the table shows the top cell only, and says so. Pass 2 replaces this
# body with the real traversal (walk instance symbol= references, stop at the
# excluded libraries) — the columns are already the ones that traversal fills.
proc copyform::refresh_table {} {
  variable st
  set tv .libmgr.cp.h.tvf.tv
  if {![winfo exists $tv]} return
  copyform::harvest
  $tv delete [$tv children {}]
  set views [copyform::match_views $st(srclib) $st(srccell) \
               $st(viewmode) $st(viewsel) $st(viewfilter)]
  $tv insert {} end -values [list $st(srclib) $st(srccell) [join $views " "] Copy]
  $tv insert {} end -values [list "…" "descendants" "hierarchy scan: pass 2" "—"]
  copyform::status "excluding: [expr {[llength $st(excl)] ? [join $st(excl) {, }] : {nothing}}]"
}

proc copyform::accept {} {
  variable st
  variable done
  variable result
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
  set result [copyform::plan]
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
