# create_instance.tcl — Cadence-style "Create Instance".
#
# Two cooperating pieces (see doc/claude/specs/cadence_create_instance.md):
#
#   ciform::  the Create Instance FORM — a properties-form-style dialog with
#             Library Name / Cell Name / View Name / Instance Name entry fields
#             and a Browse button. It owns the placement lifecycle: whenever the
#             fields resolve to a real symbol (.sym) view -- and the cell is not
#             recursive -- the symbol is armed for placement so the preview
#             follows the cursor; click the canvas to drop, repeatedly, until
#             Esc. There is NO Place button: placement is a canvas click. With no
#             View there is no preview and nothing to place. `xschem
#             create_instance` opens it (logged / bindable / singleton).
#
#   mkinst::  the Library BROWSER the form's Browse button opens: the 3-column
#             Library / Cell / (symbol) View selector, with OK / Apply / Cancel.
#             Apply sends the selection to the form and keeps the browser open;
#             OK sends and closes; Cancel just closes. It is a pure selector now
#             -- it no longer arms placement itself.

# ===========================================================================
# ciform — the Create Instance form (owns the fields + the live preview)
# ===========================================================================
namespace eval ciform {
  variable lib      ""
  variable cell     ""
  variable view     ""
  variable instname ""
  # keep-placing: a valid symbol is armed; after each drop it re-arms so the user
  # can place copies until Esc. xschem's place_symbol is one-shot (the drop clears
  # PLACE_SYMBOL), so we re-issue it on the canvas ButtonRelease.
  variable armed         0
  variable hook_installed 0
}

proc ciform::status {msg} { catch {.ciform.status configure -text $msg} }

proc ciform::placing {} { return [expr {[xschem get ui_state] & 8192}] }
proc ciform::abort_if_placing {} { if {[ciform::placing]} { catch {xschem abort_operation} } }

# Bring the (existing) form to the front with keyboard focus (same withdraw/
# deiconify trick the Library Manager uses to defeat focus-stealing prevention,
# doc/claude/specs/library_manager_launch.md).
proc ciform::raise_to_front {} {
  set w .ciform
  if {![winfo exists $w]} return
  # bring to front via the shared helper (stacking-attribute toggle, no re-map / no
  # geometry change, so it doesn't creep on each raise; issue 0054), then focus
  raise_activate_toplevel $w
  catch {focus -force $w.f.elib}
  after idle [list ciform::refocus $w]
}
proc ciform::refocus {w} { if {[winfo exists $w]} { catch {focus -force $w.f.elib} } }

# Re-arm the same symbol after each canvas drop, so placement continues until Esc.
# Appended (+) to the canvas ButtonRelease binding so it runs AFTER xschem has
# handled the drop; a no-op unless a symbol is armed and a drop just completed.
proc ciform::install_drop_hook {} {
  variable hook_installed
  if {$hook_installed} return
  if {![winfo exists .drw]} return
  bind .drw <ButtonRelease> {+ciform::after_drop %b}
  set hook_installed 1
}
proc ciform::after_drop {b} {
  variable armed
  if {$b != 1} return
  if {!$armed} return
  if {![winfo exists .ciform]} { set armed 0; return }
  if {[ciform::placing]} return   ;# preview still attached -> no drop happened
  ciform::arm                     ;# a drop completed -> re-arm the same symbol
}

# Set the Library/Cell/View (and optionally Instance Name) fields from a list,
# like `xschem library_manager` (e.g. `xschem create_instance [libmgr::selection]`
# or `[xschem get_inst_lcv]`). A 4th element, if present, sets the Instance Name;
# otherwise it is left untouched.
proc ciform::set_fields {lcv} {
  variable lib; variable cell; variable view; variable instname
  set lib  [lindex $lcv 0]
  set cell [lindex $lcv 1]
  set view [lindex $lcv 2]
  if {[llength $lcv] >= 4} { set instname [lindex $lcv 3] }
}

# The optional argument is a {lib cell view [instname]} list: when given it
# pre-fills the form (overwriting the current fields) and re-arms. With no arg the
# singleton keeps whatever it last held.
proc ciform::open {{lcv {}}} {
  # Creating an instance IS an edit: refuse it on a read-only view (issue 0051).
  # This is the single chokepoint every route funnels through — the Cadence `i`
  # key (bind .drw <Key-i> {xschem create_instance}), Edit > Create Instance, and
  # any scripted `xschem create_instance [lcv]` — so one guard covers them all.
  if {[xschem get readonly]} { readonly_notice; return }
  set w .ciform
  ciform::install_drop_hook
  set have [expr {[llength $lcv] > 0}]
  if {[winfo exists $w]} {
    # singleton: optionally re-fill from the list, then raise and re-arm.
    if {$have} { ciform::set_fields $lcv }
    ciform::raise_to_front
    ciform::arm
    return
  }
  catch {slickprop::init_fonts}   ;# reuse the slick property-form fonts for the look

  toplevel $w
  wm title $w "Create Instance"

  ttk::frame $w.f -padding 8
  pack $w.f -side top -fill both -expand 1
  set row 0
  foreach {key label} {lib "Library Name" cell "Cell Name" view "View Name" \
                       instname "Instance Name"} {
    ttk::label $w.f.l$key -text $label -anchor w
    ttk::entry $w.f.e$key -textvariable ciform::$key -width 34
    catch {$w.f.l$key configure -font slickPropLabel}
    catch {$w.f.e$key configure -font slickPropValue}
    grid $w.f.l$key -row $row -column 0 -sticky w  -padx {0 10} -pady 3
    grid $w.f.e$key -row $row -column 1 -sticky we -pady 3
    # editing any field re-evaluates the selection and re-arms the preview
    bind $w.f.e$key <KeyRelease> {+ciform::on_change}
    incr row
  }
  grid columnconfigure $w.f 1 -weight 1
  ttk::button $w.f.browse -text "Browse…" -command ciform::browse
  grid $w.f.browse -row $row -column 1 -sticky e -pady {8 0}

  ttk::label $w.status -anchor w -relief sunken -padding {4 2} \
    -text "type a Library / Cell / View or Browse — a valid symbol arms for placement; Esc finishes"
  pack $w.status -side bottom -fill x

  ttk::frame $w.b
  ttk::button $w.b.legacy -text "Legacy Xschem" -command ciform::legacy
  ttk::button $w.b.close  -text "Close"         -command "destroy $w"
  pack $w.b.legacy -side left  -padx 4 -pady 4
  pack $w.b.close  -side right -padx 4 -pady 4
  pack $w.b -side bottom -fill x

  # Esc ends placement AND dismisses the form (and the browser), whether the
  # canvas or the form has focus. `break` on the canvas pre-empts the generic
  # <KeyPress> -> C dispatcher.
  bind .drw <Key-Escape> {ciform::escape; break}
  bind $w   <Key-Escape> {ciform::escape}
  bind $w   <Destroy>    {if {{%W} eq {.ciform}} {ciform::on_destroy}}

  if {$have} { ciform::set_fields $lcv }
  ciform::raise_to_front
  ciform::arm   ;# pre-filled (or a reopened singleton) -> arm immediately
}

proc ciform::on_change {} { ciform::arm }

# Browse: open the Library Browser, which sends its selection back via set_lcv.
proc ciform::browse {} { mkinst::open }

# Called by the Library Browser (Apply / OK): fill the lib/cell/view fields and
# re-arm. The Instance Name field is left untouched (it is the user's to set).
proc ciform::set_lcv {l c v} {
  variable lib; variable cell; variable view
  set lib $l; set cell $c; set view $v
  ciform::arm
}

# The .sym datafile for the current fields, or "" when the fields do not name a
# real symbol view (the requirement: no view -> no preview -> cannot place).
proc ciform::resolve {} {
  variable lib; variable cell; variable view
  if {$lib eq "" || $cell eq "" || $view eq ""} { return "" }
  set f [xschem cellview_path "$lib/$cell" $view]
  if {$f eq "" || ![string match {*.sym} $f]} { return "" }
  return $f
}

# A circuit is physical: a cell may not contain itself, directly OR through an
# ancestor. A selection is recursive when its schematic view is ANY schematic in
# the current hierarchy stack (the open schematic and every parent descended
# through) -- instantiating it there would close a loop.
proc ciform::is_recursive {lib cell} {
  set sch [xschem cellview_path "$lib/$cell" schematic]
  if {$sch eq {}} { return 0 }
  set sch [file normalize $sch]
  set top [xschem get currsch]
  for {set n 0} {$n <= $top} {incr n} {
    set anc [xschem get schname $n]
    if {$anc ne {} && [file normalize $anc] eq $sch} { return 1 }
  }
  return 0
}

# Arm the current fields' symbol for placement (preview attaches to the cursor on
# the canvas). Re-arming aborts the previous, undropped preview first. A no-op
# (with an explanatory status) when the fields are incomplete, name no symbol
# view, or would recurse. The Instance Name, if set, becomes the instance's
# name= attribute.
proc ciform::arm {} {
  variable lib; variable cell; variable view; variable instname; variable armed
  if {![winfo exists .ciform]} { set armed 0; return }
  set f [ciform::resolve]
  if {$f eq ""} {
    set armed 0
    ciform::abort_if_placing
    if {$lib eq "" || $cell eq "" || $view eq ""} {
      ciform::status "specify Library, Cell and View to place an instance"
    } else {
      ciform::status "no symbol view for $lib/$cell ($view)"
    }
    return
  }
  if {[ciform::is_recursive $lib $cell]} {
    set armed 0
    ciform::abort_if_placing
    ciform::status "cannot instantiate $cell here — it is in the current hierarchy (recursion)"
    return
  }
  ciform::abort_if_placing
  if {$instname ne ""} {
    xschem place_symbol $f "name=$instname"
  } else {
    xschem place_symbol $f
  }
  set armed 1
  ciform::status "placing $lib/$cell ($view) — click the canvas to place; Esc to finish"
}

# Esc / close: end placement, dismiss the browser AND the form.
proc ciform::escape {} {
  variable armed
  set armed 0
  ciform::abort_if_placing
  catch {destroy .mkinst}
  catch {destroy .ciform}
}
# Form destroyed by any means: abort an armed placement, restore default Esc,
# and take the browser down with it.
proc ciform::on_destroy {} {
  variable armed
  set armed 0
  catch {bind .drw <Key-Escape> {}}
  ciform::abort_if_placing
  catch {destroy .mkinst}
}

# Drop to the classic flat symbol-picker dialog (unchanged behavior).
proc ciform::legacy {} { xschem place_symbol }


# ===========================================================================
# mkinst — the Library Browser (a pure selector: OK / Apply / Cancel)
# ===========================================================================
namespace eval mkinst {
  variable sel_lib  ""
  variable sel_cell ""
  # set while restore_from_form repositions the panes, to mute the live push
  variable suppress_push 0
}

proc mkinst::cursel {lb} {
  set i [$lb curselection]
  if {$i eq {}} { return {} }
  return [$lb get [lindex $i 0]]
}

proc mkinst::status {msg} { catch {.mkinst.status configure -text $msg} }

proc mkinst::raise_to_front {} {
  set w .mkinst
  if {![winfo exists $w]} return
  if {[winfo ismapped $w]} {
    set geo [wm geometry $w]; wm withdraw $w; wm deiconify $w; catch {wm geometry $w $geo}
  } else {
    catch {wm deiconify $w}
  }
  raise $w
  catch {focus -force $w.pw.lib.lb}
  after idle [list mkinst::refocus $w]
}
proc mkinst::refocus {w} { if {[winfo exists $w]} { catch {focus -force $w.pw.lib.lb} } }

proc mkinst::open {} {
  set w .mkinst
  if {[winfo exists $w]} {
    mkinst::raise_to_front
    mkinst::populate_libs
    mkinst::restore_from_form
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
    -text "pick a Library / Cell / symbol View — choices fill the form live; Esc or Cancel to close"
  pack $w.status -side bottom -fill x

  # No OK/Apply: every selection is applied to the form immediately (see
  # mkinst::push). Only Cancel remains; Esc dismisses too.
  ttk::frame $w.b
  ttk::button $w.b.cancel -text "Cancel" -command mkinst::cancel
  pack $w.b.cancel -side right -padx 4 -pady 4
  pack $w.b -side bottom -fill x

  bind $w.pw.lib.lb  <<ListboxSelect>> mkinst::on_lib
  bind $w.pw.cell.lb <<ListboxSelect>> mkinst::on_cell
  bind $w.pw.view.lb <<ListboxSelect>> mkinst::on_view
  bind $w <Key-Escape> {mkinst::cancel; break}

  mkinst::populate_libs
  mkinst::raise_to_front
  mkinst::restore_from_form
}

# Dismiss the browser (Esc / Cancel). The form keeps whatever was applied live.
proc mkinst::cancel {} { catch {destroy .mkinst} }

# Apply the browser's current selection to the Create Instance form (every
# selection change calls this). Suppressed while restore_from_form is positioning
# the panes, so reopening does not clobber the form with transient partial state.
proc mkinst::push {} {
  variable sel_lib; variable sel_cell; variable suppress_push
  if {$suppress_push} return
  ciform::set_lcv $sel_lib $sel_cell [mkinst::cursel .mkinst.pw.view.lb]
}

proc mkinst::populate_libs {} {
  variable sel_lib; variable sel_cell
  set lb .mkinst.pw.lib.lb
  if {![winfo exists $lb]} return
  $lb delete 0 end
  set names {}
  foreach pair [xschem libraries] { lappend names [lindex $pair 0] }
  foreach n [lsort $names] { $lb insert end $n }
  .mkinst.pw.cell.lb delete 0 end
  .mkinst.pw.view.lb delete 0 end
  set sel_lib  ""
  set sel_cell ""
}

# Library chosen -> fill the Cell column, clear Cell/View, push {lib "" ""} so the
# form tracks the (now incomplete) selection.
proc mkinst::on_lib {} {
  variable sel_lib; variable sel_cell
  set sel_lib [mkinst::cursel .mkinst.pw.lib.lb]
  set sel_cell ""
  set cl .mkinst.pw.cell.lb
  $cl delete 0 end
  .mkinst.pw.view.lb delete 0 end
  if {$sel_lib ne {}} {
    foreach c [xschem lib_cells $sel_lib] { $cl insert end $c }
  }
  mkinst::push
}

# symbol views of <lib/cell>: those whose datafile resolves to a .sym
proc mkinst::symbol_views {lib cell} {
  set out {}
  foreach v [xschem cell_views $lib $cell] {
    if {[string match {*.sym} [xschem cellview_path "$lib/$cell" $v]]} { lappend out $v }
  }
  return $out
}

# Cell chosen -> list its symbol views. If the cell has EXACTLY ONE symbol view,
# select it so clicking the cell also fills the form's View field; with several,
# leave the View unselected (the user picks one) and the form's View stays empty.
proc mkinst::on_cell {} {
  variable sel_lib; variable sel_cell
  set sel_cell [mkinst::cursel .mkinst.pw.cell.lb]
  set vl .mkinst.pw.view.lb
  $vl delete 0 end
  if {$sel_lib eq {} || $sel_cell eq {}} { mkinst::push; return }
  set sv [mkinst::symbol_views $sel_lib $sel_cell]
  foreach v $sv { $vl insert end $v }
  if {[llength $sv] == 1} {
    $vl selection set 0; $vl activate 0
    mkinst::status "$sel_lib/$sel_cell ([lindex $sv 0])"
  } elseif {[llength $sv] == 0} {
    mkinst::status "no symbol view for $sel_lib/$sel_cell"
  } else {
    mkinst::status "$sel_lib/$sel_cell — choose a symbol View"
  }
  mkinst::push
}

proc mkinst::on_view {} {
  variable sel_lib; variable sel_cell
  set v [mkinst::cursel .mkinst.pw.view.lb]
  if {$v ne {}} { mkinst::status "$sel_lib/$sel_cell ($v)" }
  mkinst::push
}

# On (re)open, highlight whatever the form currently holds, so the browser comes
# up positioned on the form's Library / Cell / View.
proc mkinst::restore_from_form {} {
  variable suppress_push
  # Read ciform's vars by ABSOLUTE name (::ciform::…): from a mkinst:: proc a relative
  # `ciform::lib` resolves to ::mkinst::ciform::lib under Tcl 9 (TIP 278, no global
  # fallback) and would silently read nothing. The info exists guard also avoids a
  # "no such variable" error if the form was never opened / the namespace was reset.
  set lib  [expr {[info exists ::ciform::lib]  ? $::ciform::lib  : {}}]
  set cell [expr {[info exists ::ciform::cell] ? $::ciform::cell : {}}]
  set view [expr {[info exists ::ciform::view] ? $::ciform::view : {}}]
  if {$lib eq {}} return
  set suppress_push 1   ;# positioning only — do not echo back to the form
  mkinst::restore_path $lib $cell $view
  set suppress_push 0
}
proc mkinst::restore_path {lib cell view} {
  set ll .mkinst.pw.lib.lb
  set i [lsearch -exact [$ll get 0 end] $lib]
  if {$i < 0} return
  $ll selection clear 0 end; $ll selection set $i; $ll activate $i; $ll see $i
  mkinst::on_lib
  if {$cell eq {}} return
  set cl .mkinst.pw.cell.lb
  set i [lsearch -exact [$cl get 0 end] $cell]
  if {$i < 0} return
  $cl selection clear 0 end; $cl selection set $i; $cl activate $i; $cl see $i
  mkinst::on_cell
  if {$view eq {}} return
  set vl .mkinst.pw.view.lb
  set i [lsearch -exact [$vl get 0 end] $view]
  if {$i >= 0} { $vl selection clear 0 end; $vl selection set $i; $vl activate $i; $vl see $i; mkinst::on_view }
}
