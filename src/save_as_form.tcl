# save_as_form.tcl — Cadence-style Library / Cell / View Save-As.
# Spec: doc/claude/specs/save_as_cellview.md
#
# Two cooperating pieces (mirroring create_instance.tcl's ciform/mkinst):
#
#   saveform::  the Save-As FORM — Library / Cell / View entry fields + a Browse
#               button + Save / Legacy Xschem / Cancel. It is a BLOCKING chooser:
#               `save_as_cellview_dialog {seed} {type}` builds it, waits, and
#               returns the chosen <cell>.<ext> datafile path (or "" to abort).
#               The C saveas() then save_schematic()s that path (rebinding the
#               buffer identity) exactly as it did for the old file dialog. This
#               is the single hook: every Save/Save-As chooser funnels through
#               C saveas(NULL,type) -> this proc.
#
#   savebrowse:: the Browse browser — the 3-column Library/Cell/View selector that
#               fills the form live (lists ALL views, since Save may target any).
#
# Library must EXIST (typed-but-unknown -> error popup + the Library text is
# selected for quick retype). Cell/View are CREATED if missing (just directories;
# a nested cell/view auto-enumerates once the datafile is written). The datafile
# is always <cell>.<ext>; ext = .sch for a schematic buffer, .sym for a symbol.

# ===========================================================================
# saveform — the Save-As form
# ===========================================================================
namespace eval saveform {
  variable lib    ""
  variable cell   ""
  variable view   ""
  variable type   "schematic"   ;# buffer editor type (schematic|symbol) -> extension
  variable seed   ""            ;# the buffer's current filename (dialog seed)
  variable result ""            ;# what save_as_cellview_dialog returns to C
}

proc saveform::status {msg} { catch {.saveform.status configure -text $msg} }

# --- CORE (headless-testable): validate + build + mkdir the target path -------
# The extension comes from the buffer TYPE, not the view name (a view is freely
# named; its datafile is <cell>.<type-ext>). Throws on an unknown library or an
# incomplete triple; the GUI wraps the throw in an error popup.
proc saveform::resolve_target {lib cell view type} {
  if {$lib eq {} || $cell eq {} || $view eq {}} {
    error "Library, Cell and View are all required"
  }
  set lp [xschem library $lib]
  if {$lp eq {}} { error "no such library: $lib" }
  set ext [expr {$type eq "symbol" ? "sym" : "sch"}]
  set path [file join $lp $cell $view "$cell.$ext"]
  file mkdir [file dirname $path]      ;# create the cell/view dirs if missing
  return $path
}

proc saveform::library_ok {lib} { return [expr {[xschem library $lib] ne {}}] }

# Pre-fill the fields from the buffer's current identity: if the seed path is a
# nested cellview under a registered library, reuse its lib/cell/view; else leave
# Library blank, Cell = the seed's basename (blank for an untitled buffer), and
# View = the type's canonical name.
proc saveform::prefill {seed type} {
  variable lib; variable cell; variable view
  set lib ""; set cell ""; set view ""
  set lcv {}
  catch {set lcv [schematic_cellview $seed]}
  if {[llength $lcv] >= 4 && [lindex $lcv 3] eq "nested"} {
    set lib  [lindex $lcv 0]
    set cell [lindex $lcv 1]
    set view [lindex $lcv 2]
  } else {
    set base [file rootname [file tail $seed]]
    if {![string match "untitled*" $base]} { set cell $base }
    set view [expr {$type eq "symbol" ? "symbol" : "schematic"}]
  }
}

# The blocking entry point C calls in place of the old save_file_dialog. Returns
# the chosen datafile path, or "" to abort the save.
proc save_as_cellview_dialog {seed type} {
  set ::saveform::result ""
  set ::saveform::type   $type
  set ::saveform::seed   $seed
  saveform::prefill $seed $type
  saveform::build
  catch {tkwait window .saveform}
  return $::saveform::result
}

proc saveform::build {} {
  variable type
  set w .saveform
  catch {destroy $w}
  catch {slickprop::init_fonts}   ;# reuse the slick property-form fonts
  toplevel $w
  wm title $w "Save As ($type)"

  ttk::frame $w.f -padding 8
  pack $w.f -side top -fill both -expand 1
  set row 0
  foreach {key label} {lib "Library" cell "Cell" view "View"} {
    ttk::label $w.f.l$key -text $label -anchor w
    ttk::entry $w.f.e$key -textvariable saveform::$key -width 34
    catch {$w.f.l$key configure -font slickPropLabel}
    catch {$w.f.e$key configure -font slickPropValue}
    grid $w.f.l$key -row $row -column 0 -sticky w  -padx {0 10} -pady 3
    grid $w.f.e$key -row $row -column 1 -sticky we -pady 3
    incr row
  }
  grid columnconfigure $w.f 1 -weight 1
  ttk::button $w.f.browse -text "Browse…" -command saveform::browse
  grid $w.f.browse -row $row -column 1 -sticky e -pady {8 0}

  ttk::label $w.status -anchor w -relief sunken -padding {4 2} \
    -text "choose a Library / Cell / View (or Browse) — Save writes <cell>.<ext>"
  pack $w.status -side bottom -fill x

  ttk::frame $w.b
  ttk::button $w.b.save   -text "Save"          -command saveform::save
  ttk::button $w.b.legacy -text "Legacy Xschem" -command saveform::legacy
  ttk::button $w.b.cancel -text "Cancel"        -command saveform::cancel
  pack $w.b.save   -side left  -padx 4 -pady 4
  pack $w.b.legacy -side left  -padx 4 -pady 4
  pack $w.b.cancel -side right -padx 4 -pady 4
  pack $w.b -side bottom -fill x

  bind $w <Key-Return> {saveform::save}
  bind $w <Key-Escape> {saveform::cancel}
  bind $w <Destroy>    {if {{%W} eq {.saveform}} {saveform::on_destroy}}

  raise_activate_toplevel $w
  catch {focus -force $w.f.elib}
}

proc saveform::browse {} { savebrowse::open }

# Called by the browser to fill the fields live.
proc saveform::set_lcv {l c v} {
  variable lib; variable cell; variable view
  set lib $l; set cell $c; set view $v
}

proc saveform::save {} {
  variable lib; variable cell; variable view; variable type
  if {$lib eq {} || $cell eq {} || $view eq {}} {
    saveform::status "specify Library, Cell and View to save"
    return
  }
  # Library must exist. Typed-but-unknown -> error popup + select the Library text
  # so the user can immediately retype it (per the spec).
  if {![saveform::library_ok $lib]} {
    catch {tk_messageBox -parent .saveform -icon error -type ok -title "Save As" \
      -message "Library \"$lib\" does not exist.\n\nPick an existing library (Browse), or create one in the Library Manager."}
    catch {
      focus -force .saveform.f.elib
      .saveform.f.elib selection range 0 end
      .saveform.f.elib icursor end
    }
    saveform::status "no such library: $lib"
    return
  }
  if {[catch {saveform::resolve_target $lib $cell $view $type} path]} {
    catch {tk_messageBox -parent .saveform -icon error -type ok -title "Save As" -message $path}
    return
  }
  # Overwrite confirmation when a DIFFERENT existing cellview would be replaced
  # (re-saving the current buffer's own file is silent).
  if {[file exists $path] &&
      [file normalize $path] ne [file normalize [xschem get schname]]} {
    set ans [tk_messageBox -parent .saveform -icon question -type yesno -title "Overwrite?" \
      -message "$lib/$cell ($view) already exists.\n\nOverwrite [file tail $path]?"]
    if {$ans ne "yes"} { return }
  }
  set ::saveform::result $path
  catch {destroy .savebrowse}
  destroy .saveform
}

# Drop to the old file-path dialog (unchanged behavior); its result flows back to
# the same C save plumbing.
proc saveform::legacy {} {
  variable seed
  set r ""
  catch {set r [save_file_dialog {Save file} * INITIALLOADDIR $seed]}
  set ::saveform::result $r
  catch {destroy .savebrowse}
  catch {destroy .saveform}
}

proc saveform::cancel {} {
  set ::saveform::result ""
  catch {destroy .savebrowse}
  catch {destroy .saveform}
}
proc saveform::on_destroy {} { catch {destroy .savebrowse} }

# ===========================================================================
# savebrowse — the Library/Cell/View browser (pure live selector)
# ===========================================================================
namespace eval savebrowse {
  variable sel_lib  ""
  variable sel_cell ""
  variable suppress 0
}

proc savebrowse::cursel {lb} {
  set i [$lb curselection]
  if {$i eq {}} { return {} }
  return [$lb get [lindex $i 0]]
}

proc savebrowse::open {} {
  set w .savebrowse
  if {[winfo exists $w]} {
    raise $w
    savebrowse::populate_libs
    savebrowse::restore_from_form
    return
  }
  toplevel $w
  wm title $w "Library Browser"
  wm geometry $w 640x420

  ttk::panedwindow $w.pw -orient horizontal
  pack $w.pw -side top -fill both -expand 1
  foreach {col title} {lib Library cell Cell view View} {
    set f [ttk::frame $w.pw.$col]
    ttk::label $f.h -text $title -anchor w -padding {4 2}
    listbox $f.lb -exportselection 0 -activestyle dotbox \
            -yscrollcommand "$f.sb set" -width 16 -height 18
    ttk::scrollbar $f.sb -orient vertical -command "$f.lb yview"
    grid $f.h  -row 0 -column 0 -columnspan 2 -sticky we
    grid $f.lb -row 1 -column 0 -sticky nsew
    grid $f.sb -row 1 -column 1 -sticky ns
    grid rowconfigure $f 1 -weight 1
    grid columnconfigure $f 0 -weight 1
    $w.pw add $f -weight 1
  }

  ttk::label $w.status -anchor w -relief sunken -padding {4 2} \
    -text "pick a Library / Cell / View — choices fill the form live; Esc or Cancel to close"
  pack $w.status -side bottom -fill x

  ttk::frame $w.b
  ttk::button $w.b.cancel -text "Cancel" -command savebrowse::cancel
  pack $w.b.cancel -side right -padx 4 -pady 4
  pack $w.b -side bottom -fill x

  bind $w.pw.lib.lb  <<ListboxSelect>> savebrowse::on_lib
  bind $w.pw.cell.lb <<ListboxSelect>> savebrowse::on_cell
  bind $w.pw.view.lb <<ListboxSelect>> savebrowse::on_view
  bind $w <Key-Escape> {savebrowse::cancel; break}

  savebrowse::populate_libs
  raise $w
  savebrowse::restore_from_form
}

proc savebrowse::cancel {} { catch {destroy .savebrowse} }

proc savebrowse::push {} {
  variable sel_lib; variable sel_cell; variable suppress
  if {$suppress} return
  saveform::set_lcv $sel_lib $sel_cell [savebrowse::cursel .savebrowse.pw.view.lb]
}

proc savebrowse::populate_libs {} {
  variable sel_lib; variable sel_cell
  set lb .savebrowse.pw.lib.lb
  if {![winfo exists $lb]} return
  $lb delete 0 end
  set names {}
  foreach pair [xschem libraries] { lappend names [lindex $pair 0] }
  foreach n [lsort $names] { $lb insert end $n }
  .savebrowse.pw.cell.lb delete 0 end
  .savebrowse.pw.view.lb delete 0 end
  set sel_lib  ""
  set sel_cell ""
}

proc savebrowse::on_lib {} {
  variable sel_lib; variable sel_cell
  set sel_lib [savebrowse::cursel .savebrowse.pw.lib.lb]
  set sel_cell ""
  set cl .savebrowse.pw.cell.lb
  $cl delete 0 end
  .savebrowse.pw.view.lb delete 0 end
  if {$sel_lib ne {}} {
    foreach c [xschem lib_cells $sel_lib] { $cl insert end $c }
  }
  savebrowse::push
}

proc savebrowse::on_cell {} {
  variable sel_lib; variable sel_cell
  set sel_cell [savebrowse::cursel .savebrowse.pw.cell.lb]
  set vl .savebrowse.pw.view.lb
  $vl delete 0 end
  if {$sel_lib eq {} || $sel_cell eq {}} { savebrowse::push; return }
  set vs [xschem cell_views $sel_lib $sel_cell]
  foreach v $vs { $vl insert end $v }
  if {[llength $vs] == 1} { $vl selection set 0; $vl activate 0 }
  savebrowse::push
}

proc savebrowse::on_view {} { savebrowse::push }

proc savebrowse::restore_from_form {} {
  variable suppress
  set lib  [expr {[info exists ::saveform::lib]  ? $::saveform::lib  : {}}]
  set cell [expr {[info exists ::saveform::cell] ? $::saveform::cell : {}}]
  set view [expr {[info exists ::saveform::view] ? $::saveform::view : {}}]
  if {$lib eq {}} return
  set suppress 1
  savebrowse::restore_path $lib $cell $view
  set suppress 0
}

proc savebrowse::restore_path {lib cell view} {
  set ll .savebrowse.pw.lib.lb
  set i [lsearch -exact [$ll get 0 end] $lib]
  if {$i < 0} return
  $ll selection clear 0 end; $ll selection set $i; $ll activate $i; $ll see $i
  savebrowse::on_lib
  if {$cell eq {}} return
  set cl .savebrowse.pw.cell.lb
  set i [lsearch -exact [$cl get 0 end] $cell]
  if {$i < 0} return
  $cl selection clear 0 end; $cl selection set $i; $cl activate $i; $cl see $i
  savebrowse::on_cell
  if {$view eq {}} return
  set vl .savebrowse.pw.view.lb
  set i [lsearch -exact [$vl get 0 end] $view]
  if {$i >= 0} { $vl selection clear 0 end; $vl selection set $i; $vl activate $i; $vl see $i; savebrowse::on_view }
}
