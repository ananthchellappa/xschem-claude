#  File: utils/instance_update.tcl        (sourced from cadence_style_rc)
#
#  Instance Update -- Xschem port of the Tanner S-Edit "Instance Update" utility.
#  See doc/claude/specs/instance_update.md (design) and
#  references/instance_update_usr_guide.md.
#
#  A modeless Tk form (Ctrl+Shift+I / inst_update::show) that BULK-RETARGETS the
#  master (symbol reference) of instances in the current schematic. The target set
#  is chosen by an optional Name regex + Scope + From-library + From-cell; the
#  replacement is a To-library + To-cell. List previews matches read-only; Build
#  shows the query summary; Run performs the retarget and reports per-instance.
#
#  S-Edit -> Xschem primitive mapping (no new C verb -- pure Tcl over existing verbs):
#    find instance -scope -filter/-modify {}  -> a Tcl iterate+match loop over
#                                                `xschem get instances` / getprop
#    property get -name MasterLibrary/MasterCell -system
#                                              -> schematic_cellview [abs_sym_path
#                                                 [xschem getprop instance N cell::name]]
#                                                 reverse-map to {lib cell view}
#    property set -name MasterLibrary/MasterCell -system
#                                              -> xschem replace_symbol N <symref> fast
#                                                 (Xschem has ONE symbol ref, not a lib+cell
#                                                 pair; both compose into cellview_path arg)
#    property get -name Name -system           -> xschem getprop instance N name
#    database cells / sed_get_library_names    -> xschem lib_cells / xschem libraries
#    sed_get_current_library                   -> schematic_cellview [xschem get schname]
#    mode renderoff/renderon                   -> one push_undo + replace_symbol ... fast
#                                                 + one final redraw (batch atomicity)
#    clipboard via clip.exe                    -> native Tk clipboard (utils/cadence_clip.tcl)
#
#  Hierarchy scope is DEFERRED/REFUSED (reset to view + warn): Xschem verbs act on the
#  current sheet only; there is no cross-sheet find/-modify primitive (see the spec
#  "Out-of-scope / DEFER"). This is the one faithful divergence from the reference.
#
#  Pure Tcl, no C change. The proc DEFINITIONS load headless (no Tk); only show()/the
#  fonts and the trailing `bind .drw` are Tk-guarded, so tests/headless/test_instance_update.tcl
#  can source this file and exercise the core with no Tk present.
#
# ---------------------------------------------------------------------------
#  BINDING NOTE -- why this is a `bind .drw`, not a keybindings.csv row
# ---------------------------------------------------------------------------
#  keybindings.csv rows are replayed through `xschem bind`, which only accepts an
#  action id already present in the COMPILED C action registry (callback.c
#  action_registry[] / find_action_def). There is no runtime "register a Tcl proc
#  as an action" path, so a brand-new Tcl proc like this one CANNOT be dispatched
#  from keybindings.csv without a C-source change. The established no-C-change
#  mechanism (used throughout cadence_style_rc) is a Tk binding on the canvas `.drw`
#  ending in `break`. clone_canvas_bindings copies it to detached/new canvases.
#  Rebind: edit the `bind .drw ...` line at the bottom of this file.
# ---------------------------------------------------------------------------

namespace eval inst_update {
  # dropdown sentinels (parenthesized so they cannot collide with real names)
  variable NONE  "(none)"
  variable ANY   "(any cell)"
  variable KEEP  "(n/a - keep cell)"
  variable REGEX "(Regex)"

  # form state (bound to widgets) -- the History snapshot set is `statevars`.
  variable statevars {nameRegex fromLib fromCell cellRegex toLib toCell fscope gotonone}
  variable nameRegex ""
  variable fromLib   ""
  variable fromCell  "(none)"
  variable cellRegex ""
  variable toLib     ""
  variable toCell    "(n/a - keep cell)"
  variable fscope    view
  variable gotonone  1

  # run-time scratch (the sentinel-resolved copies the match loop reads)
  variable fltName   ""
  variable fltLib    ""
  variable fltCell   ""   ;# empty = any cell
  variable fltCellRe ""   ;# cell-name regex; empty = no regex criterion
  variable newLib    ""
  variable newCell   ""   ;# empty = keep each instance's cell

  # run/result state
  variable hits      {}
  variable fails     {}
  variable results   ""
  variable command   ""
  variable status    ""
  variable last_guard ""

  # history
  variable history   {}
  variable histidx   0
}

# ===========================================================================
#  Pure-Tcl core (headless-testable -- no Tk, no engine dependency here).
# ===========================================================================

# Regex matchers: the user's pattern is ONLY ever passed as DATA to regexp --
# never eval'd/subst'd, so `[ ] { } $` in it are inert (structurally safe).
proc inst_update::name_match {re val} { if {[regexp -- $re $val]} { return 1 } ; return 0 }
proc inst_update::cell_match {re val} { if {[regexp -- $re $val]} { return 1 } ; return 0 }

# Copy widget state into the scratch vars, resolving the four sentinels:
#   (any cell)/(none)/(Regex) -> empty fltCell ; (Regex) -> regex text in fltCellRe ;
#   (n/a - keep cell)         -> empty newCell (keep each instance's own cell).
proc inst_update::set_scratch {} {
  variable NONE; variable ANY; variable KEEP; variable REGEX
  variable nameRegex; variable fromLib; variable fromCell; variable cellRegex
  variable toLib; variable toCell
  variable fltName; variable fltLib; variable fltCell; variable fltCellRe
  variable newLib; variable newCell
  set fltName   [string trim $nameRegex]
  set fltLib    $fromLib
  set fltCell   [expr {($fromCell eq $ANY || $fromCell eq $NONE || $fromCell eq $REGEX) ? "" : $fromCell}]
  set fltCellRe [expr {$fromCell eq $REGEX ? [string trim $cellRegex] : ""}]
  set newLib    $toLib
  set newCell   [expr {$toCell eq $KEEP ? "" : $toCell}]
}

# Run-enable predicate: false if (Regex) with empty text, or any required field blank.
proc inst_update::runnable {} {
  variable NONE; variable REGEX
  variable fromLib; variable fromCell; variable cellRegex; variable toLib; variable toCell
  if {$fromCell eq $REGEX && [string trim $cellRegex] eq ""} { return 0 }
  expr {$fromLib ne "" && $toLib ne "" && $toCell ne "" \
        && $fromCell ne "" && $fromCell ne $NONE}
}

# Compose the new master ref (S-Edit MasterLibrary+MasterCell -> one symbol ref).
# newCell empty = keep the instance's own cell (library migration); else many-to-one.
# Empty view (flat-layout libs report "") defaults to `symbol` (masters are symbol views).
# Returns {"<newLib>/<cell>" <view>} for cellview_path.
proc inst_update::compose {mlib mcell mview} {
  variable newLib; variable newCell
  set cell [expr {$newCell eq "" ? $mcell : $newCell}]
  set view [expr {$mview eq "" ? "symbol" : $mview}]
  return [list "$newLib/$cell" $view]
}

# Human-readable summary of the query (Xschem has no single find/retarget verb to
# echo verbatim, so this is a faithful summary, not a re-runnable line).
proc inst_update::build_summary {} {
  variable NONE; variable ANY; variable KEEP; variable REGEX
  variable fscope; variable nameRegex; variable fromLib; variable fromCell
  variable cellRegex; variable toLib; variable toCell
  set p [list "retarget instance"]
  lappend p "scope=$fscope"
  if {$fromCell eq $REGEX} {
    set fcs "regex:[string trim $cellRegex]"
  } elseif {$fromCell eq $ANY} {
    set fcs "(any cell)"
  } elseif {$fromCell eq $NONE} {
    set fcs "(none)"
  } else {
    set fcs $fromCell
  }
  lappend p "from=$fromLib/$fcs"
  set tcs [expr {$toCell eq $KEEP ? "(keep)" : $toCell}]
  lappend p "to=$toLib/$tcs"
  if {[string trim $nameRegex] ne ""} { lappend p "name=[string trim $nameRegex]" }
  return [join $p "  "]
}

# --- History (recall states you actually ran) ------------------------------
proc inst_update::snapshot {} {
  variable statevars
  set s {}
  foreach v $statevars { lappend s $v [set ::inst_update::$v] }
  return $s
}
proc inst_update::apply_state {s} {
  foreach {v val} $s { set ::inst_update::$v $val }
  # refresh the dependent cell lists for the recalled libraries (populate only
  # sets -values, so the recalled cell selections survive) -- widget-guarded no-op headless
  inst_update::populate_from_cells
  inst_update::populate_to_cells
  inst_update::refresh_run_state
}
proc inst_update::history_save {} {
  variable history; variable histidx
  set s [inst_update::snapshot]
  if {[llength $history] == 0 || [lindex $history end] ne $s} { lappend history $s }
  set histidx [llength $history]
  inst_update::hist_update_label
}
proc inst_update::history_up {} {
  variable history; variable histidx
  if {[llength $history] == 0} return
  if {$histidx > 0} { incr histidx -1 }
  inst_update::apply_state [lindex $history $histidx]
  inst_update::hist_update_label
}
proc inst_update::history_down {} {
  variable history; variable histidx
  set n [llength $history]
  if {$n == 0} return
  if {$histidx < $n} { incr histidx }
  if {$histidx < $n} { inst_update::apply_state [lindex $history $histidx] }
  inst_update::hist_update_label
}
proc inst_update::histlabel {} {
  variable history; variable histidx
  set n [llength $history]
  if {$n == 0} { return "(empty)" }
  if {$histidx >= $n} { return "$n saved" }
  return "[expr {$histidx + 1}] / $n"
}

# --- Change handlers (sentinel/linkage rules) ------------------------------
proc inst_update::on_from_lib_changed {} {
  variable NONE; variable fromLib; variable fromCell
  set fromCell $NONE      ;# the old cell belonged to the old library
  set n [inst_update::populate_from_cells]
  inst_update::set_status "From library '$fromLib': $n cell(s)"
  inst_update::refresh_run_state
}
proc inst_update::on_to_lib_changed {} {
  variable KEEP; variable toLib; variable toCell
  set n [inst_update::populate_to_cells]
  # keep the chosen cell if the new library also has it, else fall back
  if {$toCell ne $KEEP && [lsearch -exact [inst_update::get_cells $toLib] $toCell] < 0} {
    set toCell $KEEP
  }
  inst_update::set_status "To library '$toLib': $n cell(s)"
  inst_update::refresh_run_state
}
proc inst_update::on_from_cell_changed {} {
  variable ANY; variable KEEP; variable REGEX; variable fromCell; variable toCell
  if {$fromCell eq $ANY} { set toCell $KEEP }
  inst_update::refresh_run_state
  if {$fromCell eq $REGEX && [inst_update::has_widgets] && [winfo exists .instUpdate.tgt.cre]} {
    catch { focus .instUpdate.tgt.cre }
  }
}

# --- hierarchy guard (reset hierarchy -> view + warn; return 1 if it fired) --
proc inst_update::hier_guard {} {
  variable fscope
  if {$fscope ne "hierarchy"} { return 0 }
  set fscope view
  inst_update::set_results "WARNING: scope was 'hierarchy' - reset to 'view'.\nXschem verbs act on the current sheet only; there is no cross-sheet find/-modify\nprimitive, so hierarchy-wide retarget is not available from this form. Descend\ninto each sub-sheet and re-run per sheet."
  return 1
}

# ===========================================================================
#  Engine-backed core (needs a running xschem document; still Tk-free).
# ===========================================================================

# {lib cell view} of instance $i's master (reverse-map); {} when unresolvable.
proc inst_update::inst_master {i} {
  set abs [abs_sym_path [xschem getprop instance $i cell::name]]
  if {$abs ne ""} { set abs [file normalize $abs] }
  set cv [schematic_cellview $abs]
  if {[lindex $cv 0] eq ""} { return {} }
  return [lrange $cv 0 2]
}

# First instance index whose Name is $nm, or -1. (selection scope maps names->indices
# up front so the retarget loop can address by index even as refdes names change.)
proc inst_update::name_to_index {nm} {
  set n [xschem get instances]
  for {set i 0} {$i < $n} {incr i} {
    if {[xschem getprop instance $i name] eq $nm} { return $i }
  }
  return -1
}

# Instance indices to enumerate for the current Scope.
proc inst_update::scope_indices {} {
  variable fscope
  switch -- $fscope {
    view {
      set out {}
      set n [xschem get instances]
      for {set i 0} {$i < $n} {incr i} { lappend out $i }
      return $out
    }
    selection {
      set out {}
      foreach nm [xschem selected_set] {
        set idx [inst_update::name_to_index $nm]
        if {$idx >= 0} { lappend out $idx }
      }
      return $out
    }
  }
  return {}
}

# The -filter port: Name regex (optional) + master-lib + master-cell(-regex). Reads
# the scratch vars, so set_scratch MUST have run first.
proc inst_update::match_inst {i} {
  variable fltName; variable fltLib; variable fltCell; variable fltCellRe
  set m [inst_update::inst_master $i]
  if {$m eq ""} { return 0 }                       ;# unresolvable -> never match
  lassign $m mlib mcell mview
  if {$fltName ne "" && ![inst_update::name_match $fltName [xschem getprop instance $i name]]} { return 0 }
  if {$mlib ne $fltLib} { return 0 }
  if {$fltCell   ne "" && $mcell ne $fltCell}                        { return 0 }
  if {$fltCellRe ne "" && ![inst_update::cell_match $fltCellRe $mcell]} { return 0 }
  return 1
}

# Enumerate in-scope indices + filter by match_inst -> matched index list.
proc inst_update::collect {} {
  set out {}
  foreach i [inst_update::scope_indices] {
    if {[inst_update::match_inst $i]} { lappend out $i }
  }
  return $out
}

# The -modify port for one instance: compose the new master ref + replace_symbol fast.
# The cellview_path existence/`*.sym` check is MANDATORY -- replace_symbol crashes on
# an empty path -- so a missing target cell becomes a FAILED row, never a mutation.
proc inst_update::retarget_one {i} {
  variable hits; variable fails
  set name [xschem getprop instance $i name]     ;# read BEFORE the swap (refdes may change)
  set m [inst_update::inst_master $i]
  if {$m eq ""} { lappend fails [list $name "?" "?" "unresolvable master"] ; return }
  lassign $m mlib mcell mview
  lassign [inst_update::compose $mlib $mcell $mview] ref view
  set path [xschem cellview_path $ref $view]
  if {$path eq "" || ![string match *.sym $path]} {
    lappend fails [list $name $mlib $mcell "no such cell/view: $ref:$view"]
    return
  }
  if {[catch {xschem replace_symbol $i $path fast} err]} {
    lappend fails [list $name $mlib $mcell $err]
  } else {
    lappend hits [list $name $mlib $mcell [lindex [split $ref /] 1]]
  }
}

# Guard refuse (symbol view / readonly): red status + CIW echo.
proc inst_update::guard_refuse {g} {
  variable last_guard
  set last_guard $g
  switch -- $g {
    symbol   { set msg "not available in symbol view (no schematic instances to retarget)" }
    readonly { set msg "schematic is read-only (use Edit > Make Editable to enable editing)" }
    default  { set msg "refused" }
  }
  inst_update::set_results $msg
  inst_update::set_status $msg
  catch { ciw_echo "Instance Update: $msg" error }
}

# Build Command only -- assemble the summary, do not execute, do not push history.
proc inst_update::build_only {} {
  variable last_guard
  set last_guard ""
  set was_hier [inst_update::hier_guard]
  inst_update::set_scratch
  inst_update::show_cmd [inst_update::build_summary]
  if {$was_hier} {
    inst_update::set_status "scope hierarchy -> view; command built (not run)"
  } elseif {[inst_update::runnable]} {
    inst_update::set_status "command built (not run)"
  } else {
    inst_update::set_status "command built (not run); pick a From-cell (or fill the regex) to enable Run"
  }
  return $::inst_update::command
}

# Run: guards -> history_save -> single-undo retarget sweep -> report.
proc inst_update::run {} {
  variable REGEX; variable fromCell
  variable hits; variable fails; variable last_guard
  set last_guard ""
  set hits {}; set fails {}
  if {[string match {*.sym} [xschem get current_name]]} { inst_update::guard_refuse symbol; return }
  if {[xschem get readonly]} { inst_update::guard_refuse readonly; return }
  if {[inst_update::hier_guard]} {
    inst_update::set_status "Run blocked: scope hierarchy -> view (see Results)"
    return
  }
  if {![inst_update::runnable]} {
    if {$fromCell eq $REGEX} {
      inst_update::set_status "Run blocked: From-cell regex is empty"
    } else {
      inst_update::set_status "Run blocked: From-cell is (none)"
    }
    return
  }
  inst_update::set_scratch
  inst_update::history_save
  inst_update::show_cmd [inst_update::build_summary]

  set idx [inst_update::collect]
  if {[llength $idx]} {
    xschem push_undo               ;# ONE undo slot for the whole batch
    foreach i $idx { inst_update::retarget_one $i }
    catch { xschem set_modify 1 }
    catch { xschem redraw }
  }
  inst_update::report_results
}

proc inst_update::report_results {} {
  variable hits; variable fails; variable newLib
  set nhit  [llength $hits]
  set nfail [llength $fails]
  set lines {}
  if {$nhit == 0} {
    lappend lines "(no instances updated)"
  } else {
    lappend lines "$nhit instance(s) updated:"
    foreach h $hits {
      lassign $h n oldl oldc newc
      lappend lines [format "  %-20s %s/%s  ->  %s/%s" $n $oldl $oldc $newLib $newc]
    }
  }
  if {$nfail > 0} {
    lappend lines ""
    lappend lines "FAILED (unchanged):"
    foreach f $fails {
      lassign $f n oldl oldc err
      lappend lines [format "  %-20s %s/%s : %s" $n $oldl $oldc $err]
    }
  }
  inst_update::set_results [join $lines "\n"]
  set msg "$nhit updated"
  if {$nfail > 0} { append msg ", $nfail failed" }
  inst_update::set_status $msg
  catch { ciw_echo "Instance Update: $msg" }
}

# List (read-only preview; no mutation, no history, no undo). Reset hierarchy -> view
# (there is no engine to traverse it), then tabulate the matches sorted by name.
proc inst_update::list_matches {} {
  variable fltCell; variable last_guard
  set last_guard ""
  if {[string match {*.sym} [xschem get current_name]]} { inst_update::guard_refuse symbol; return }
  inst_update::hier_guard
  inst_update::set_scratch
  set incell ""
  catch { set incell [lindex [schematic_cellview [xschem get schname]] 1] }
  set rows {}
  foreach i [inst_update::collect] {
    lappend rows [list [xschem getprop instance $i name] [lindex [inst_update::inst_master $i] 1]]
  }
  set rows [lsort -dictionary -index 0 $rows]
  set n [llength $rows]
  set lines {}
  if {$n == 0} {
    lappend lines "(nothing matched)"
  } else {
    lappend lines "$n matching instance(s):"
    if {$fltCell eq ""} {
      lappend lines [format "  %-20s %-20s %s" "In cell" "Instance" "Master cell"]
      foreach r $rows {
        lassign $r inst master
        lappend lines [format "  %-20s %-20s %s" $incell $inst $master]
      }
    } else {
      lappend lines [format "  %-20s %s" "In cell" "Instance"]
      foreach r $rows {
        lassign $r inst master
        lappend lines [format "  %-20s %s" $incell $inst]
      }
    }
  }
  inst_update::set_results [join $lines "\n"]
  inst_update::set_status "$n listed"
  catch { ciw_echo "Instance Update: $n listed" }
}

# Get: seed From-library / From-cell from the current selection (never disturbs it).
proc inst_update::get_from_selection {} {
  variable NONE; variable fromLib; variable fromCell
  set pairs {}
  foreach nm [xschem selected_set] {
    set idx [inst_update::name_to_index $nm]
    if {$idx < 0} continue
    set m [inst_update::inst_master $idx]
    if {$m eq ""} continue
    lappend pairs [lrange $m 0 1]
  }
  if {![llength $pairs]} {
    inst_update::set_results "Get: no instance is selected."
    inst_update::set_status "Get: nothing selected"
    return
  }
  set libs {}; set cells {}
  foreach p $pairs {
    lassign $p l c
    if {[lsearch -exact $libs  $l] < 0} { lappend libs  $l }
    if {[lsearch -exact $cells $c] < 0} { lappend cells $c }
  }
  if {[llength $libs] > 1} {
    inst_update::set_results "Get: the [llength $pairs] selected instance(s) come from multiple libraries ([join $libs {, }]) - nothing set."
    inst_update::set_status "Get: multiple libraries"
    return
  }
  set fromLib [lindex $libs 0]
  inst_update::populate_from_cells
  if {[llength $cells] == 1} {
    set fromCell [lindex $cells 0]
    inst_update::set_status "Get: $fromLib/$fromCell from [llength $pairs] selected instance(s)"
  } else {
    set fromCell $NONE
    inst_update::set_results "Get: [llength $pairs] selected instance(s) from '$fromLib' but with differing cells ([join $cells {, }]).\nFrom-cell left at $NONE - pick one manually."
    inst_update::set_status "Get: library set; multiple cells"
  }
  inst_update::refresh_run_state
}

# ===========================================================================
#  Library / cell queries.
# ===========================================================================
proc inst_update::get_libs {} {
  set out {}
  if {[catch {set libs [xschem libraries]}]} { return {} }
  foreach p $libs { lappend out [lindex $p 0] }
  return [lsort -dictionary $out]
}
proc inst_update::get_cells {lib} {
  if {$lib eq ""} { return {} }
  if {[catch {set cells [xschem lib_cells $lib]}]} { return {} }
  return [lsort -dictionary $cells]
}
# current library derived from the open cellview (S-Edit sed_get_current_library)
proc inst_update::current_lib {} {
  if {[catch {set lcv [schematic_cellview [xschem get schname]]}]} { return "" }
  return [lindex $lcv 0]
}

# ===========================================================================
#  UI plumbing -- all no-ops / var-only when the form is not built (headless-safe).
# ===========================================================================
proc inst_update::has_widgets {} {
  return [expr {[llength [info commands winfo]] && [winfo exists .instUpdate]}]
}
proc inst_update::set_txt {path text} {
  if {![inst_update::has_widgets] || ![winfo exists $path]} return
  catch {
    $path configure -state normal
    $path delete 1.0 end
    $path insert 1.0 $text
    $path configure -state disabled
  }
}
proc inst_update::set_results {text} {
  set ::inst_update::results $text
  inst_update::set_txt .instUpdate.res.t $text
}
proc inst_update::show_cmd {text} {
  set ::inst_update::command $text
  inst_update::set_txt .instUpdate.cmdf.t $text
}
proc inst_update::set_status {text} {
  set ::inst_update::status $text
}
proc inst_update::hist_update_label {} {
  if {[inst_update::has_widgets] && [winfo exists .instUpdate.rrow.hist.lbl]} {
    catch { .instUpdate.rrow.hist.lbl configure -text [inst_update::histlabel] }
  }
}
# populate procs only set combobox -values; safe as -postcommand and after recall.
proc inst_update::populate_libs {} {
  if {![inst_update::has_widgets]} { return 0 }
  set libs [inst_update::get_libs]
  foreach cb {.instUpdate.tgt.fle .instUpdate.rrow.rep.tle} {
    if {[winfo exists $cb]} { $cb configure -values $libs }
  }
  return [llength $libs]
}
proc inst_update::populate_from_cells {} {
  variable NONE; variable ANY; variable REGEX; variable fromLib
  if {![inst_update::has_widgets]} { return 0 }
  set cb .instUpdate.tgt.fce
  if {![winfo exists $cb]} { return 0 }
  set cells [inst_update::get_cells $fromLib]
  $cb configure -values [concat [list $NONE $REGEX] $cells [list $ANY]]
  return [llength $cells]
}
proc inst_update::populate_to_cells {} {
  variable KEEP; variable toLib
  if {![inst_update::has_widgets]} { return 0 }
  set cb .instUpdate.rrow.rep.tce
  if {![winfo exists $cb]} { return 0 }
  set cells [inst_update::get_cells $toLib]
  $cb configure -values [concat [list $KEEP] $cells]
  return [llength $cells]
}
proc inst_update::refresh_run_state {} {
  variable REGEX; variable fromCell
  if {![inst_update::has_widgets]} return
  set e .instUpdate.tgt.cre
  if {[winfo exists $e]} {
    catch { $e configure -state [expr {$fromCell eq $REGEX ? "normal" : "disabled"}] }
  }
  set b .instUpdate.bb.run
  if {[winfo exists $b]} {
    catch { $b configure -state [expr {[inst_update::runnable] ? "normal" : "disabled"}] }
  }
}

# Copy a read-only pane's selection (or whole text) via native Tk clipboard.
proc inst_update::copy_results {{t {}}} {
  if {$t eq ""} { set t .instUpdate.res.t }
  set txt ""
  if {[catch { set txt [$t get sel.first sel.last] }]} {
    catch { set txt [$t get 1.0 end-1c] }
  }
  if {$txt eq ""} { inst_update::set_status "nothing to copy"; return }
  if {[catch { cadence::clip_put $txt }]} {
    catch { ciw_echo "Instance Update (copy): $txt" }
  }
  return
}

# Reset the form fields to defaults (KEEP history). Field-only variant is
# document/widget-light so the headless tests can call it directly.
proc inst_update::reset_fields {} {
  variable NONE; variable KEEP; variable history; variable histidx
  set ::inst_update::nameRegex ""
  set ::inst_update::cellRegex ""
  set ::inst_update::fscope    view
  set ::inst_update::gotonone  1
  set ::inst_update::fromCell  $NONE
  set ::inst_update::toCell    $KEEP
  set cur [inst_update::current_lib]
  set libs [inst_update::get_libs]
  if {$cur eq "" || [lsearch -exact $libs $cur] < 0} { set cur [lindex $libs 0] }
  set ::inst_update::fromLib $cur
  set ::inst_update::toLib   $cur
  set histidx [llength $history]
  inst_update::hist_update_label
}
proc inst_update::reset {} {
  inst_update::reset_fields
  inst_update::populate_libs
  inst_update::populate_from_cells
  inst_update::populate_to_cells
  inst_update::set_status ""
  inst_update::set_results ""
  inst_update::show_cmd ""
  inst_update::refresh_run_state
}

# ===========================================================================
#  The modeless Tk form (Tk-only; never reached headless).
# ===========================================================================
proc inst_update::init_fonts {} {
  foreach {f fam sz wt} {
    IuBold   Arial   13 bold
    IuLabel  Arial   13 normal
    IuEntry  Courier 14 normal
    IuButton Arial   13 bold
    IuSmall  Arial   11 normal
  } {
    if {[lsearch -exact [font names] $f] < 0} {
      catch { font create $f -family $fam -size $sz -weight $wt }
    }
  }
  catch { option add *TCombobox*Listbox.font IuEntry }
}

proc inst_update::show {} {
  if {![llength [info commands winfo]]} return    ;# no Tk -> nothing to show
  set w .instUpdate
  if {[winfo exists $w]} {
    inst_update::populate_libs
    wm deiconify $w ; raise $w ; focus $w ; return
  }
  inst_update::init_fonts

  toplevel $w
  wm title $w "Instance Update"
  wm resizable $w 1 1

  # --- target ---
  labelframe $w.tgt -text "Target (which instances)" -font IuBold
  pack $w.tgt -side top -fill x -padx 10 -pady {10 4}
  label $w.tgt.nml -text "Name regex (optional):" -font IuLabel
  entry $w.tgt.nme -textvariable ::inst_update::nameRegex -font IuEntry -width 26
  label $w.tgt.scl -text "Scope:" -font IuLabel
  ttk::combobox $w.tgt.sce -state readonly -width 10 \
      -values {view selection hierarchy} -textvariable ::inst_update::fscope -font IuEntry
  button $w.tgt.list -text "List" -font IuButton -command inst_update::list_matches
  grid $w.tgt.nml $w.tgt.nme $w.tgt.scl $w.tgt.sce $w.tgt.list -sticky w -padx 4 -pady 2
  grid configure $w.tgt.list -sticky ew

  label $w.tgt.fll -text "From library:" -font IuLabel
  ttk::combobox $w.tgt.fle -state readonly -width 22 \
      -textvariable ::inst_update::fromLib -font IuEntry -postcommand inst_update::populate_libs
  label $w.tgt.fcl -text "From cell:" -font IuLabel
  ttk::combobox $w.tgt.fce -state readonly -width 24 \
      -textvariable ::inst_update::fromCell -font IuEntry -postcommand inst_update::populate_from_cells
  button $w.tgt.get -text "Get" -font IuButton -command inst_update::get_from_selection
  grid $w.tgt.fll $w.tgt.fle $w.tgt.fcl $w.tgt.fce $w.tgt.get -sticky w -padx 4 -pady 2
  grid configure $w.tgt.get -sticky ew
  grid configure $w.tgt.fce -sticky ew
  grid columnconfigure $w.tgt 3 -weight 1
  bind $w.tgt.fle <<ComboboxSelected>> inst_update::on_from_lib_changed
  bind $w.tgt.fce <<ComboboxSelected>> inst_update::on_from_cell_changed

  label $w.tgt.crl -text "From-cell regex:" -font IuLabel
  entry $w.tgt.cre -textvariable ::inst_update::cellRegex -font IuEntry -width 26 -state disabled
  grid $w.tgt.crl -row 2 -column 0 -sticky w  -padx 4 -pady 2
  grid $w.tgt.cre -row 2 -column 1 -columnspan 3 -sticky ew -padx 4 -pady 2
  bind $w.tgt.cre <KeyRelease> inst_update::refresh_run_state

  # --- -goto none ---
  checkbutton $w.goto -text "-goto none  (do not pan/zoom to matches)" \
      -variable ::inst_update::gotonone -font IuLabel
  pack $w.goto -side top -anchor w -padx 14 -pady 2

  # --- replacement + history (side by side) ---
  set rrow [frame $w.rrow]
  pack $rrow -side top -fill x -padx 10 -pady 4
  labelframe $rrow.rep -text "Replacement (new master)" -font IuBold
  pack $rrow.rep -side left -fill both -expand 1
  label $rrow.rep.tll -text "To library:" -font IuLabel
  ttk::combobox $rrow.rep.tle -state readonly -width 22 \
      -textvariable ::inst_update::toLib -font IuEntry -postcommand inst_update::populate_libs
  label $rrow.rep.tcl -text "To cell:" -font IuLabel
  ttk::combobox $rrow.rep.tce -state readonly -width 24 \
      -textvariable ::inst_update::toCell -font IuEntry -postcommand inst_update::populate_to_cells
  grid $rrow.rep.tll $rrow.rep.tle -sticky w -padx 4 -pady 2
  grid $rrow.rep.tcl $rrow.rep.tce -sticky w -padx 4 -pady 2
  grid configure $rrow.rep.tle $rrow.rep.tce -sticky ew
  grid columnconfigure $rrow.rep 1 -weight 1
  bind $rrow.rep.tle <<ComboboxSelected>> inst_update::on_to_lib_changed
  bind $rrow.rep.tce <<ComboboxSelected>> inst_update::refresh_run_state

  labelframe $rrow.hist -text "History" -font IuBold
  pack $rrow.hist -side left -fill y -padx {10 0}
  button $rrow.hist.up -text "▲ Prev" -font IuButton -command inst_update::history_up
  button $rrow.hist.dn -text "▼ Next" -font IuButton -command inst_update::history_down
  label $rrow.hist.lbl -text [inst_update::histlabel] -font IuSmall -anchor center
  pack $rrow.hist.up  -side top -padx 8 -pady {4 2} -fill x
  pack $rrow.hist.dn  -side top -padx 8 -pady 2 -fill x
  pack $rrow.hist.lbl -side top -padx 8 -pady {2 4} -fill x

  # --- buttons ---
  set bb [frame $w.bb]
  pack $bb -side top -fill x -padx 10 -pady 6
  button $bb.build -text "Build Command" -font IuButton -command inst_update::build_only
  button $bb.run   -text "Run"           -font IuButton -command inst_update::run
  button $bb.copy  -text "Copy Results"  -font IuButton -command inst_update::copy_results
  button $bb.reset -text "Reset"         -font IuButton -command inst_update::reset
  button $bb.close -text "Close"         -font IuButton -command [list destroy $w]
  pack $bb.build $bb.run $bb.copy $bb.reset -side left -padx 4
  pack $bb.close -side right -padx 4

  # --- command box ---
  label $w.cmdl -text "Command:" -font IuBold -anchor w
  pack $w.cmdl -side top -fill x -padx 10
  frame $w.cmdf
  pack $w.cmdf -side top -fill x -padx 10
  text $w.cmdf.t -height 2 -wrap word -font IuEntry -yscrollcommand [list $w.cmdf.sb set]
  scrollbar $w.cmdf.sb -command [list $w.cmdf.t yview]
  pack $w.cmdf.sb -side right -fill y
  pack $w.cmdf.t -side left -fill x -expand 1
  $w.cmdf.t configure -state disabled

  # --- results box ---
  label $w.resl -text "Results:" -font IuBold -anchor w
  pack $w.resl -side top -fill x -padx 10
  frame $w.res
  pack $w.res -side top -fill both -expand 1 -padx 10 -pady {0 4}
  text $w.res.t -height 10 -wrap none -font IuEntry -yscrollcommand [list $w.res.sb set]
  scrollbar $w.res.sb -command [list $w.res.t yview]
  pack $w.res.sb -side right -fill y
  pack $w.res.t -side left -fill both -expand 1
  $w.res.t configure -state disabled

  foreach _t [list $w.res.t $w.cmdf.t] {
    bind $_t <<Copy>>         {inst_update::copy_results %W; break}
    bind $_t <Control-c>      {inst_update::copy_results %W; break}
    bind $_t <Control-Insert> {inst_update::copy_results %W; break}
  }

  # --- status ---
  label $w.status -textvariable ::inst_update::status -font IuSmall -anchor w
  pack $w.status -side top -fill x -padx 10 -pady {2 8}

  inst_update::reset
}

# ---------------------------------------------------------------------------
# Keybind: Ctrl+Shift+I ("Instance"; verified free -- no key,73 row in
# keybindings.csv, no existing Control-Shift-Key-I bind). Shift makes 'i' emit the
# capital "I" keysym, so bind Key-I. `break` stops the chord reaching the generic
# <KeyPress> -> `xschem callback` -> C dispatcher. Guarded so sourcing headless
# (no Tk, no `bind`) is a no-op. clone_canvas_bindings propagates it to new canvases.
# ---------------------------------------------------------------------------
if {[llength [info commands bind]]} {
  catch { bind .drw <Control-Shift-Key-I> {inst_update::show; break} }
}
