#  File: utils/find_helper.tcl        (sourced from cadence_style_rc)
#
#  Find Navigator -- Xschem port of the Tanner S-Edit "Find Navigator" utility.
#  See doc/claude/specs/find_helper.md (design) and references/find_helper_usr_guide.md.
#
#  A modeless Tk form (Ctrl+Shift+G / find_helper::show) that FINDS ports,
#  instances or net-labels by name pattern in the current schematic and can
#  SELECT / COUNT / LIST (screen-ordered CSV) / bulk-RENAME (regsub on Name) them.
#
#  S-Edit -> Xschem primitive mapping (no new C verb -- pure Tcl over existing verbs):
#    find <type> -name -scope -filter/-modify {}  -> a Tcl iterate+match loop over
#                                                    `xschem get instances` / getprop
#    property get/set -name Name -system          -> xschem getprop/setprop instance <N> <tok>
#                                                    with <tok> TYPE-ROUTED: `name` for a
#                                                    component instance, `lab` for a port/label
#    mode renderoff/renderon                       -> push_undo + no_undo + one final redraw
#    clipboard via clip.exe                        -> native Tk clipboard (utils/cadence_clip.tcl)
#
#  Object classification is by SYMBOL TYPE (xschem getprop instance N cell::type),
#  since Xschem stores ports, net-labels and components in ONE instance array:
#    port     : cell::type in {ipin opin iopin}   -> Name lives in the `lab` attr
#    netlabel : cell::type == label               -> Name lives in the `lab` attr
#    instance : anything else (subckt/primitive)  -> Name is the instance name (`name`)
#  (show_label / empty-type are NOT connecting labels and are excluded, same rule as
#   toggle_pins_netlabels.tcl.)
#
#  Hierarchy scope is DEFERRED/REFUSED: Xschem verbs act on the current sheet only and
#  there is no cross-sheet find/-modify primitive (see the spec "Out-of-scope / DEFER").
#
#  Pure Tcl, no C change. The proc DEFINITIONS load headless (no Tk); only show()/the
#  fonts and the trailing `bind .drw` are Tk-guarded, so tests/headless/test_find_helper.tcl
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

namespace eval find_helper {
  # 16 input-field state variables (the History snapshot set).
  variable statevars {ftype fname fscope wildcard regex nocase exact contains \
                      first add sub count gotonone ffrom fto report}

  # --- input-field vars (bound to the widgets) ---
  variable ftype    port
  variable fname    ""
  variable fscope   view
  variable wildcard 0
  variable regex    0
  variable nocase   0
  variable exact    0
  variable contains 0
  variable first    0
  variable add      0
  variable sub      0
  variable count    0
  variable gotonone 1
  variable ffrom    ""
  variable fto      ""
  variable report   0

  # --- run/result state ---
  variable history    {}
  variable histidx    0
  variable hits       {}
  variable fails      {}
  variable results    ""
  variable status     ""
  variable last_guard ""
  variable n_found    0
  variable n_renamed  0
  variable n_failed   0
  variable n_listed   0
}

# ===========================================================================
#  Pure-Tcl core (headless-testable -- no Tk, no engine dependency here).
# ===========================================================================

# The type-dependent Name routing (the single biggest porting hazard):
#   component instance -> the `name` token ; port / net-label -> the `lab` token.
proc find_helper::name_token {objtype} {
  if {$objtype eq "instance"} { return name }
  return lab
}

# Does cell::type $ctype belong to Object class $objtype?
proc find_helper::type_ok {objtype ctype} {
  switch -- $objtype {
    port     { return [expr {[lsearch -exact {ipin opin iopin} $ctype] >= 0}] }
    netlabel { return [expr {$ctype eq "label"}] }
    instance { return [expr {[lsearch -exact {ipin opin iopin label show_label {}} $ctype] < 0}] }
  }
  return 0
}

# Which match mode is active (default when none checked).
proc find_helper::mode_of {} {
  if {$::find_helper::wildcard} { return wildcard }
  if {$::find_helper::regex}    { return regex }
  if {$::find_helper::exact}    { return exact }
  if {$::find_helper::contains} { return contains }
  return default
}

# Pure matcher: does $val match $pat under $mode (+optional $nocase)?  Returns 0/1.
# The user's pattern is only ever passed as DATA to Tcl's matchers -- never eval'd.
proc find_helper::match {mode pat val nocase} {
  switch -- $mode {
    wildcard {
      if {$nocase} { return [string match -nocase $pat $val] }
      return [string match $pat $val]
    }
    regex {
      if {$nocase} { return [regexp -nocase -- $pat $val] }
      return [regexp -- $pat $val]
    }
    exact {
      return [string equal $pat $val]
    }
    contains {
      if {$nocase} {
        return [expr {[string first [string tolower $pat] [string tolower $val]] >= 0}]
      }
      return [expr {[string first $pat $val] >= 0}]
    }
    default {
      if {$nocase} { return [string equal -nocase $pat $val] }
      return [string equal $pat $val]
    }
  }
}

# The match-mode auto-uncheck rules (mutates only the namespace vars).
proc find_helper::link {which} {
  switch -- $which {
    wildcard { set ::find_helper::regex 0 ; set ::find_helper::exact 0 }
    regex    { set ::find_helper::wildcard 0 ; set ::find_helper::exact 0 }
    exact    { set ::find_helper::wildcard 0 ; set ::find_helper::regex 0
               set ::find_helper::contains 0 ; set ::find_helper::nocase 0 }
    contains { set ::find_helper::exact 0 }
    nocase   { set ::find_helper::exact 0 }
    add      { set ::find_helper::sub 0 }
    sub      { set ::find_helper::add 0 }
  }
}

# Sort {name x y} triples into on-screen reading order and return the names.
#   horizontal spread (x >= y) -> ascending X (left -> right)
#   vertical   spread          -> ascending Y (top of screen first; Xschem screen-Y
#                                 grows DOWNWARD, so top-first == smallest Y first)
# No dedup -- one entry per matched object.
proc find_helper::order_by_screen {triples} {
  if {[llength $triples] == 0} { return {} }
  set xmin ""; set xmax ""; set ymin ""; set ymax ""
  foreach t $triples {
    set x [lindex $t 1] ; set y [lindex $t 2]
    if {$xmin eq "" || $x < $xmin} { set xmin $x }
    if {$xmax eq "" || $x > $xmax} { set xmax $x }
    if {$ymin eq "" || $y < $ymin} { set ymin $y }
    if {$ymax eq "" || $y > $ymax} { set ymax $y }
  }
  set xs [expr {$xmax - $xmin}]
  set ys [expr {$ymax - $ymin}]
  if {$xs >= $ys} {
    set sorted [lsort -real -index 1 $triples]
  } else {
    set sorted [lsort -real -index 2 $triples]
  }
  set names {}
  foreach t $sorted { lappend names [lindex $t 0] }
  return $names
}

# The regsub transform, isolated so it can be unit-tested with pathological
# From/To.  From/To/old are Tcl VARIABLES fed to regsub -- so `[ ] { } $` in any of
# them are inert data, never command/variable substitution.
proc find_helper::rename_transform {from to old} {
  return [regsub -all -- $from $old $to]
}

# Human-readable summary of the query that will run (transparency box; Xschem has
# no single `find` verb to echo verbatim, so this is a summary, not a re-runnable line).
proc find_helper::build_summary {} {
  set p [list "find $::find_helper::ftype"]
  if {$::find_helper::fname ne ""} { lappend p "name=$::find_helper::fname" }
  foreach m {wildcard regex exact contains nocase} {
    if {[set ::find_helper::$m]} { lappend p $m }
  }
  foreach m {first add sub count} {
    if {[set ::find_helper::$m]} { lappend p $m }
  }
  lappend p "scope=$::find_helper::fscope"
  if {!$::find_helper::gotonone} { lappend p goto }
  if {$::find_helper::ffrom ne ""} {
    lappend p "rename:/$::find_helper::ffrom/$::find_helper::fto/"
    if {$::find_helper::report} { lappend p report }
  } elseif {$::find_helper::report} {
    lappend p report
  }
  return [join $p "  "]
}

# --- History (recall states you actually ran) ------------------------------
proc find_helper::snapshot {} {
  set s {}
  foreach v $::find_helper::statevars { lappend s $v [set ::find_helper::$v] }
  return $s
}
proc find_helper::apply_state {s} {
  foreach {v val} $s { set ::find_helper::$v $val }
  find_helper::sync_widgets
}
proc find_helper::history_save {} {
  variable history
  variable histidx
  set s [find_helper::snapshot]
  if {[llength $history] == 0 || [lindex $history end] ne $s} {
    lappend history $s
  }
  set histidx [llength $history]
  find_helper::hist_update_label
}
proc find_helper::history_up {} {
  variable history
  variable histidx
  if {[llength $history] == 0} return
  if {$histidx > 0} { incr histidx -1 }
  find_helper::apply_state [lindex $history $histidx]
  find_helper::hist_update_label
}
proc find_helper::history_down {} {
  variable history
  variable histidx
  set n [llength $history]
  if {$n == 0} return
  if {$histidx < $n} { incr histidx }
  if {$histidx < $n} { find_helper::apply_state [lindex $history $histidx] }
  find_helper::hist_update_label
}
proc find_helper::histlabel {} {
  variable history
  variable histidx
  set n [llength $history]
  if {$n == 0} { return "(empty)" }
  if {$histidx >= $n} { return "$n saved" }
  return "[expr {$histidx + 1}] / $n"
}

proc find_helper::reset {} {
  variable history
  set ::find_helper::ftype  port
  set ::find_helper::fname  ""
  set ::find_helper::fscope view
  foreach v {wildcard regex nocase exact contains first add sub count} {
    set ::find_helper::$v 0
  }
  set ::find_helper::gotonone 1
  set ::find_helper::ffrom ""
  set ::find_helper::fto   ""
  set ::find_helper::report 0
  # keep history; re-park the cursor at the end
  set ::find_helper::histidx [llength $history]
  find_helper::hist_update_label
  find_helper::sync_widgets
}

# ===========================================================================
#  Engine-backed core (needs a running xschem document; still Tk-free).
# ===========================================================================

# Instance identifiers to enumerate for the current Scope:
#   view      -> 0 .. [xschem get instances]-1  (integer indices)
#   selection -> the selected instance NAMES (getprop/setprop/select all accept a name)
proc find_helper::scope_indices {} {
  switch -- $::find_helper::fscope {
    view {
      set out {}
      set n [xschem get instances]
      for {set i 0} {$i < $n} {incr i} { lappend out $i }
      return $out
    }
    selection { return [xschem selected_set] }
  }
  return {}
}

# Enumerate + filter by Object type + match by Name -> matched identifier list.
proc find_helper::collect {} {
  set objtype $::find_helper::ftype
  set tok     [find_helper::name_token $objtype]
  set pat     $::find_helper::fname
  set mode    [find_helper::mode_of]
  set nocase  $::find_helper::nocase
  set out {}
  foreach i [find_helper::scope_indices] {
    set ctype [xschem getprop instance $i cell::type]
    if {![find_helper::type_ok $objtype $ctype]} continue
    set val [xschem getprop instance $i $tok]
    if {$pat eq "" || [find_helper::match $mode $pat $val $nocase]} {
      lappend out $i
      if {$::find_helper::first} break
    }
  }
  return $out
}

# The -modify port: regsub Name via getprop/setprop, one undo transaction. Fills
# hits (old->new that changed) and fails (per-item error). getprop AND setprop are
# inside the per-item catch, so an unresolvable identifier or a rejected setprop
# lands in `fails` and the sweep continues (S-Edit's half-updated FAILED reporting).
proc find_helper::do_rename {indices} {
  set from    $::find_helper::ffrom
  set to      $::find_helper::fto
  set tok     [find_helper::name_token $::find_helper::ftype]
  set ::find_helper::hits  {}
  set ::find_helper::fails {}
  xschem push_undo
  xschem set no_undo 1
  set emsg ""
  catch {
    foreach i $indices {
      if {[catch {
        set old [xschem getprop instance $i $tok]
        set new [find_helper::rename_transform $from $to $old]
        if {$new ne $old} {
          xschem setprop -fast instance $i $tok $new
          lappend ::find_helper::hits [list $old $new]
        }
      } m]} {
        lappend ::find_helper::fails [list $i $m]
      }
    }
  } emsg
  xschem set no_undo 0
  xschem set_modify 1
  xschem redraw
  return $emsg
}

# Apply the Selection flags to the matched identifiers (nodraw batch).
proc find_helper::apply_selection {indices} {
  if {$::find_helper::count} { return }
  if {$::find_helper::add} {
    foreach i $indices { xschem select instance $i nodraw }
  } elseif {$::find_helper::sub} {
    foreach i $indices { xschem select instance $i clear nodraw }
  } else {
    xschem unselect_all
    foreach i $indices { xschem select instance $i nodraw }
  }
}

# Guard: symbol-view / hierarchy always; readonly only when $check_ro. Returns the
# guard name ("" = clear).
proc find_helper::guard_check {check_ro} {
  if {[string match {*.sym} [xschem get current_name]]} { return symbol }
  if {$::find_helper::fscope eq "hierarchy"} { return hierarchy }
  if {$check_ro && [xschem get readonly]} { return readonly }
  return ""
}
proc find_helper::guard_refuse {g} {
  set ::find_helper::last_guard $g
  switch -- $g {
    symbol    { set m "not available in symbol view (ports/labels are pin rects there)" }
    hierarchy { set m "hierarchy scope is not supported -- Xschem acts on the current sheet only; descend and re-run per sheet" }
    readonly  { set m "schematic is read-only (use Edit > Make Editable to enable editing)" }
    default   { set m "refused" }
  }
  find_helper::ui_set_status $m red
  catch { ciw_echo "Find Navigator: $m" error }
}

# Build (or refresh) the Results box + Status line for a run.
proc find_helper::run {} {
  set ::find_helper::last_guard ""
  set ::find_helper::n_found   0
  set ::find_helper::n_renamed 0
  set ::find_helper::n_failed  0
  set ::find_helper::hits  {}
  set ::find_helper::fails {}
  set g [find_helper::guard_check 1]
  if {$g ne ""} { find_helper::guard_refuse $g ; return }

  find_helper::history_save
  set idx [find_helper::collect]
  set ::find_helper::n_found [llength $idx]

  set lines {}
  set do_rename [expr {$::find_helper::ffrom ne "" || $::find_helper::report}]
  if {$do_rename} {
    if {$::find_helper::ffrom ne ""} {
      find_helper::do_rename $idx
      set ::find_helper::n_renamed [llength $::find_helper::hits]
      set ::find_helper::n_failed  [llength $::find_helper::fails]
      foreach h $::find_helper::hits { lappend lines "[lindex $h 0]  ->  [lindex $h 1]" }
      if {[llength $::find_helper::fails]} {
        lappend lines "FAILED:"
        foreach f $::find_helper::fails { lappend lines "  [lindex $f 0] : [lindex $f 1]" }
      }
    } else {
      # report-only: collect the current Name of every match
      set tok [find_helper::name_token $::find_helper::ftype]
      foreach i $idx { lappend ::find_helper::hits [xschem getprop instance $i $tok] }
      set lines $::find_helper::hits
    }
  }

  find_helper::apply_selection $idx

  # status line
  if {$::find_helper::ffrom ne ""} {
    set st "$::find_helper::n_found found, $::find_helper::n_renamed renamed, $::find_helper::n_failed failed"
  } elseif {$::find_helper::count} {
    set st "$::find_helper::n_found found"
  } else {
    set st "$::find_helper::n_found found"
  }
  find_helper::ui_set_results [join $lines \n]
  find_helper::ui_set_status $st
  catch { ciw_echo "Find Navigator: $st" }
  catch { xschem redraw }
}

# Build Command only -- assemble the summary, do not execute, do not push history.
proc find_helper::build_only {} {
  set s [find_helper::build_summary]
  find_helper::ui_set_command $s
  catch { ciw_echo "Find Navigator: $s" }
  return $s
}

# The List action: collect + screen-order names -> CSV to Results. Never selects,
# never renames, pushes no history.
proc find_helper::list_names {} {
  set ::find_helper::last_guard ""
  set ::find_helper::n_listed 0
  set g [find_helper::guard_check 0]
  if {$g ne ""} { find_helper::guard_refuse $g ; return }

  set tok [find_helper::name_token $::find_helper::ftype]
  set triples {}
  foreach i [find_helper::collect] {
    set nm [xschem getprop instance $i $tok]
    set c  [xschem instance_coord $i]
    lappend triples [list $nm [lindex $c 2] [lindex $c 3]]
  }
  set names [find_helper::order_by_screen $triples]
  set ::find_helper::n_listed [llength $names]
  find_helper::ui_set_results [join $names ,]
  find_helper::ui_set_status "$::find_helper::n_listed listed"
  catch { ciw_echo "Find Navigator: $::find_helper::n_listed listed" }
}

# ===========================================================================
#  UI plumbing -- all no-ops when the form is not built (headless-safe).
# ===========================================================================
proc find_helper::has_widgets {} {
  return [expr {[llength [info commands winfo]] && [winfo exists .fh]}]
}
proc find_helper::ui_set_results {txt} {
  set ::find_helper::results $txt
  if {[find_helper::has_widgets]} {
    catch {
      .fh.res.t configure -state normal
      .fh.res.t delete 1.0 end
      .fh.res.t insert end $txt
      .fh.res.t configure -state disabled
    }
  }
}
proc find_helper::ui_set_command {txt} {
  set ::find_helper::status $txt
  if {[find_helper::has_widgets]} {
    catch {
      .fh.cmd configure -state normal
      .fh.cmd delete 1.0 end
      .fh.cmd insert end $txt
      .fh.cmd configure -state disabled
    }
  }
}
proc find_helper::ui_set_status {txt {color {}}} {
  set ::find_helper::status $txt
  if {[find_helper::has_widgets]} {
    catch {
      set fg [expr {$color eq "red" ? "#c0392b" : "black"}]
      .fh.status configure -text $txt -foreground $fg
    }
  }
}
proc find_helper::hist_update_label {} {
  if {[find_helper::has_widgets]} {
    catch { .fh.body.hist.lbl configure -text [find_helper::histlabel] }
  }
}
# Push the namespace vars back onto the live widgets (comboboxes are -textvariable
# bound so they track automatically; this is a hook for anything that needs a nudge).
proc find_helper::sync_widgets {} {
  find_helper::hist_update_label
}

# Copy a read-only pane's selection (or whole text) via native Tk clipboard.
proc find_helper::copy_results {{t {}}} {
  if {$t eq ""} { set t .fh.res.t }
  set txt ""
  if {[catch { set txt [$t get sel.first sel.last] }]} {
    catch { set txt [$t get 1.0 end-1c] }
  }
  if {[catch { cadence::clip_put $txt }]} {
    catch { ciw_echo "Find Navigator (copy): $txt" }
  }
  return
}

# ===========================================================================
#  The modeless Tk form (Tk-only; never reached headless).
# ===========================================================================
proc find_helper::init_fonts {} {
  foreach {f fam sz wt} {
    FhBold   Arial   13 bold
    FhLabel  Arial   13 normal
    FhEntry  Courier 14 normal
    FhButton Arial   13 bold
    FhSmall  Arial   11 normal
  } {
    if {[lsearch -exact [font names] $f] < 0} {
      catch { font create $f -family $fam -size $sz -weight $wt }
    }
  }
  catch { option add *TCombobox*Listbox.font FhEntry }
}

proc find_helper::show {} {
  if {![llength [info commands winfo]]} return   ;# no Tk -> nothing to show
  if {[winfo exists .fh]} { wm deiconify .fh ; raise .fh ; focus .fh ; return }
  find_helper::init_fonts

  toplevel .fh
  wm title .fh "Find Navigator"
  wm resizable .fh 0 1

  set b .fh.body
  frame $b -padx 8 -pady 6
  pack $b -side top -fill both -expand 1

  # --- row: Object / Scope ---
  set r1 $b.r1 ; frame $r1 ; pack $r1 -side top -fill x -pady 2
  label $r1.ol -text "Object:" -font FhBold
  ttk::combobox $r1.obj -state readonly -width 10 -font FhEntry \
      -values {port instance netlabel} -textvariable ::find_helper::ftype
  label $r1.sl -text "   Scope:" -font FhBold
  ttk::combobox $r1.sc -state readonly -width 10 -font FhEntry \
      -values {selection view hierarchy} -textvariable ::find_helper::fscope
  pack $r1.ol $r1.obj $r1.sl $r1.sc -side left

  # --- row: Name ---
  set r2 $b.r2 ; frame $r2 ; pack $r2 -side top -fill x -pady 2
  label $r2.l -text "Name:" -font FhBold
  entry $r2.e -textvariable ::find_helper::fname -font FhEntry -width 40
  pack $r2.l -side left ; pack $r2.e -side left -fill x -expand 1

  # --- match-mode frame ---
  set r3 $b.mm ; labelframe $r3 -text "Match mode" -font FhBold -padx 4 -pady 2
  pack $r3 -side top -fill x -pady 2
  foreach {w var} {wc wildcard re regex nc nocase ex exact co contains} {
    checkbutton $r3.$w -text "-$var" -font FhLabel \
        -variable ::find_helper::$var -command [list find_helper::link $var]
  }
  button $r3.list -text "List" -font FhButton -command find_helper::list_names
  grid $r3.wc $r3.re $r3.nc $r3.list -sticky w -padx 2
  grid $r3.ex $r3.co -sticky w -padx 2

  # --- selection frame ---
  set r4 $b.sel ; labelframe $r4 -text "Selection" -font FhBold -padx 4 -pady 2
  pack $r4 -side top -fill x -pady 2
  foreach {w var} {fi first ad add su sub cn count} {
    checkbutton $r4.$w -text "-$var" -font FhLabel \
        -variable ::find_helper::$var -command [list find_helper::link $var]
  }
  # add/sub linkage; first/count have no linkage but share the -command harmlessly
  $r4.fi configure -command {}
  $r4.cn configure -command {}
  checkbutton $r4.goto -text "-goto none" -font FhLabel -variable ::find_helper::gotonone
  grid $r4.fi $r4.ad $r4.su $r4.cn -sticky w -padx 2
  grid $r4.goto -sticky w -padx 2 -columnspan 4

  # --- rename + history row ---
  set r5 $b.rn ; frame $r5 ; pack $r5 -side top -fill x -pady 2
  labelframe $r5.rename -text "Rename (regsub on Name)" -font FhBold -padx 4 -pady 2
  label $r5.rename.fl -text "From (regex):" -font FhLabel
  entry $r5.rename.fe -textvariable ::find_helper::ffrom -font FhEntry -width 24
  label $r5.rename.tl -text "To   (subst):" -font FhLabel
  entry $r5.rename.te -textvariable ::find_helper::fto -font FhEntry -width 24
  checkbutton $r5.rename.rep -text "Report modified (pre-existing) names" \
      -font FhLabel -variable ::find_helper::report
  grid $r5.rename.fl $r5.rename.fe -sticky w
  grid $r5.rename.tl $r5.rename.te -sticky w
  grid $r5.rename.rep -sticky w -columnspan 2
  labelframe $r5.hist -text "History" -font FhBold -padx 4 -pady 2
  button $r5.hist.up -text "▲ Prev" -font FhButton -command find_helper::history_up
  button $r5.hist.dn -text "▼ Next" -font FhButton -command find_helper::history_down
  label  $r5.hist.lbl -text [find_helper::histlabel] -font FhSmall
  pack $r5.hist.up $r5.hist.dn $r5.hist.lbl -side top -pady 1
  pack $r5.rename -side left -fill x -expand 1
  pack $r5.hist -side left -fill y -padx 4

  # --- buttons ---
  set r6 $b.btn ; frame $r6 ; pack $r6 -side top -fill x -pady 4
  button $r6.build -text "Build Command" -font FhButton -command find_helper::build_only
  button $r6.run   -text "Run"           -font FhButton -command find_helper::run
  button $r6.copy  -text "Copy Results"  -font FhButton -command find_helper::copy_results
  button $r6.reset -text "Reset"         -font FhButton -command find_helper::reset
  button $r6.close -text "Close"         -font FhButton -command {destroy .fh}
  pack $r6.build $r6.run $r6.copy $r6.reset $r6.close -side left -padx 2

  # --- command box ---
  label $b.cl -text "Command:" -font FhSmall -anchor w
  pack $b.cl -side top -fill x
  text .fh.cmd -height 2 -font FhEntry -wrap word -state disabled
  pack .fh.cmd -side top -fill x -padx 8

  # --- results box ---
  label $b.rl -text "Results:" -font FhSmall -anchor w
  pack $b.rl -side top -fill x
  set rf .fh.res ; frame $rf ; pack $rf -side top -fill both -expand 1 -padx 8
  text $rf.t -height 8 -font FhEntry -wrap none -state disabled \
      -yscrollcommand "$rf.sb set"
  scrollbar $rf.sb -command "$rf.t yview"
  pack $rf.sb -side right -fill y ; pack $rf.t -side left -fill both -expand 1

  # --- status line ---
  label .fh.status -textvariable ::find_helper::status -font FhSmall -anchor w
  pack .fh.status -side top -fill x -padx 8 -pady 2

  # copy bindings preempt the crashing/again-shadowed class binding
  foreach tw [list .fh.cmd $rf.t] {
    bind $tw <<Copy>>         {find_helper::copy_results %W; break}
    bind $tw <Control-c>      {find_helper::copy_results %W; break}
    bind $tw <Control-Insert> {find_helper::copy_results %W; break}
  }
  find_helper::hist_update_label
}

# ---------------------------------------------------------------------------
# Keybind: Ctrl+Shift+G (the reference's own request; verified free -- no key,71,ctrl
# row in keybindings.csv, no existing Control-Shift-Key-G bind). Shift makes 'g' emit
# the capital "G" keysym, so bind Key-G. `break` stops the chord reaching the generic
# <KeyPress> -> `xschem callback` -> C dispatcher. Guarded so sourcing headless (no Tk,
# no `bind`) is a no-op. clone_canvas_bindings propagates it to detached/new canvases.
# ---------------------------------------------------------------------------
if {[llength [info commands bind]]} {
  catch { bind .drw <Control-Shift-Key-G> {find_helper::show; break} }
}
