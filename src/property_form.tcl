# property_form.tcl — the slick per-property "Edit Properties" form.
#
# v1 replaces the single raw-text-box property editor with a structured form: one
# entry per declared symbol attribute (Cadence-style), strict (no free-form add of
# undeclared tokens), single-line fields, Enter=OK / Escape=Cancel.
#
# This file is split in two:
#   * the CORE (namespace slickprop, below) — pure, widget-independent parse and
#     reassemble logic, unit-tested headless by tests/property_form/. It is the
#     correctness gate the form rests on.
#   * the FORM (the Tk dialog) — added on top of the core, see slickprop::edit_form.
#
# The reassembly is "subst-into-original": on OK, start from the object's ORIGINAL
# property string and substitute back ONLY the fields the user actually edited
# (tracked per field). Untouched tokens are preserved byte-for-byte — which is the
# cardinal invariant (open + OK with no edits leaves the string unchanged), proven
# necessary by probe: always-requoting turns `name=E1` into `name="E1"`, so only
# touched fields may be rewritten.
#
# Token primitives used (all pure string ops in the C core):
#   xschem list_tokens <s> 0      -> the token names in <s>
#   xschem get_tok <s> <tok> 2    -> <tok>'s value, CLEAN (quotes/escapes removed,
#                                     no tcl-hook substitution): the editable form
#   xschem subst_tok <s> <tok> <v>-> <s> with <tok>=<v> (v inserted AS-IS; an empty
#                                     v REMOVES the token). Caller must pre-quote.

namespace eval slickprop {}

# 1 while the modeless form is open: the C event handler reads this to allow
# canvas SELECTION at semaphore>=2 and to fire slickprop::on_selection_changed
# (modeless editing, M1). Defined at source so the C tclgetboolvar never misses.
set ::slickprop_form_open 0

# Escape any embedded " and \ in <v> and wrap the whole thing in double quotes,
# producing a value safe to hand to `subst_tok` (which inserts it verbatim). This
# is the same recipe the legacy "Edit Attr" combobox used.
proc slickprop::requote {v} {
  regsub -all {(["\\])} $v {\\\1} v
  return "\"$v\""
}

# Build the ordered field model for the form from an object's property string
# <prop> and its symbol template <template>. Returns a list of field dicts; each:
#   name      the token name (the fixed field label)
#   value     the current editable value (clean; empty for a declared-but-unset
#             attr, so it is not written unless the user types something)
#   declared  1 if the token is declared in the template, else 0 (an "Extra" token)
#   default   the template default (declared tokens only; {} for extras) — shown as
#             a greyed placeholder when the field is unset
#   isset     1 if the token is actually present in <prop>, else 0
# Declared tokens come first, in template order; then any extra (undeclared)
# instance tokens, in their order of appearance.
proc slickprop::to_fields {prop template} {
  set decl [xschem list_tokens $template 0]
  set inst [xschem list_tokens $prop 0]
  set fields {}
  foreach tok $decl {
    set isset [expr {[lsearch -exact $inst $tok] >= 0}]
    lappend fields [dict create \
      name     $tok \
      value    [expr {$isset ? [xschem get_tok $prop $tok 2] : {}}] \
      declared 1 \
      default  [xschem get_tok $template $tok 2] \
      isset    $isset]
  }
  foreach tok $inst {
    if {[lsearch -exact $decl $tok] >= 0} continue
    lappend fields [dict create \
      name     $tok \
      value    [xschem get_tok $prop $tok 2] \
      declared 0 \
      default  {} \
      isset    1]
  }
  return $fields
}

# Apply edits to <orig>, subst-into-original. <changes> is a flat list
# {tok val tok val ...} of ONLY the fields the user actually edited. For each:
#   * an empty <val> REMOVES the token (the clear / delete path);
#   * otherwise <val> is requoted and substituted in.
# Tokens of <orig> not named in <changes> are preserved byte-for-byte. With an
# empty <changes> the result is identical to <orig> (the cardinal invariant).
proc slickprop::apply {orig changes} {
  set out $orig
  foreach {tok val} $changes {
    if {$val eq {}} {
      set out [xschem subst_tok $out $tok <NULL>]
    } else {
      set out [xschem subst_tok $out $tok [slickprop::requote $val]]
    }
  }
  return $out
}

# ===========================================================================
# Slick enter_text core — discoverable text-appearance attributes.
# Spec: specs/slick_text_dialog.md. A text object's visual attributes all live as
# tokens in its property string (read by C's set_text_flags() into cached fields,
# then drawn). So the panel is pure Tcl: parse the owned tokens out of the prop
# string into per-field widgets, and on OK substitute the edited ones back via
# the subst-into-original slickprop::apply above (no C change). Unlike the
# instance form, there is no symbol template to derive fields from — the field
# set is a fixed, hand-authored per-type schema.
#
# Owned tokens (form order). Each descriptor:
#   tok     the property token the widget reads/writes
#   label   the field label shown in the panel
#   widget  bool  -> checkbox: checked writes <on>, unchecked removes the token
#           combo -> a value chosen from a dropdown (font name)
#           layer -> a layer-index colour-swatch dropdown
#   on      (bool only) the token value written when the box is checked
# Size (hsize/vsize) is intentionally absent: it is the object's xscale/yscale,
# already carried by the dialog as tctx::hsize / tctx::vsize, not a prop token.
proc slickprop::text_schema {} {
  return [list \
    [dict create tok font    label {Font}     widget combo] \
    [dict create tok weight  label {Bold}     widget bool  on bold] \
    [dict create tok slant   label {Italic}   widget bool  on italic] \
    [dict create tok hcenter label {Center H} widget bool  on true] \
    [dict create tok vcenter label {Center V} widget bool  on true] \
    [dict create tok layer   label {Color}    widget layer] \
    [dict create tok hide    label {Hidden}   widget bool  on true] \
    [dict create tok floater label {Floater}  widget bool  on true]]
}

# A per-object-type schema (used by the slick text_line dialog). Each row is the
# same descriptor shape as text_schema. Only prop-string tokens are owned — for
# graphical objects layer/colour is structural (not a token) and is out of scope.
# Value forms (verified in editprop.c): dash int (0=solid); fill enum
# full|false|absent; bus numeric width; bezier bool true; ellipse "a b" angles.
proc slickprop::gfx_schema {type} {
  set dash    [dict create tok dash    label {Dash (0=solid)} widget int]
  set fill    [dict create tok fill    label {Fill} widget enum \
                 choices [dict create Default {} None false Full full]]
  set bus     [dict create tok bus     label {Width} widget num]
  set bezier  [dict create tok bezier  label {Smooth (bezier)} widget bool on true]
  set ellipse [dict create tok ellipse label {Ellipse} widget ellipse]
  switch -- $type {
    rect - rectangle - xRECT { return [list $dash $fill $ellipse] }
    line - LINE              { return [list $dash $bus] }
    poly - polygon - POLYGON { return [list $dash $fill $bezier $bus] }
    arc  - ARC               { return [list $dash $fill $bus] }
    wire - WIRE              { return [list $bus] }
    default { return {} }
  }
}

# Generic core (schema-parameterised). The text_* procs below are thin wrappers
# passing text_schema, so the slick enter_text and text_line dialogs share one
# implementation (TX* tests guard the text path; RL* the graphical path).

# The schema rows with each field's CURRENT value parsed out of <prop>:
#   value    the token's current value in <prop> (clean; empty if absent)
#   present  1 if the token is actually present in <prop>, else 0
# An absent token keeps value "" / present 0 so the form does not write it back
# unless the user edits it.
proc slickprop::schema_fields {schema prop} {
  set have [xschem list_tokens $prop 0]
  set rows {}
  foreach row $schema {
    set tok [dict get $row tok]
    set present [expr {[lsearch -exact $have $tok] >= 0}]
    dict set row present $present
    dict set row value [expr {$present ? [xschem get_tok $prop $tok 2] : {}}]
    lappend rows $row
  }
  return $rows
}

# The leftover "Other properties" string: <prop> with every owned token removed,
# all other tokens (declared-elsewhere or unknown) preserved verbatim.
proc slickprop::schema_extra {schema prop} {
  set out $prop
  foreach row $schema {
    set out [xschem subst_tok $out [dict get $row tok] <NULL>]
  }
  return $out
}

# Assemble the final property string on OK. <desired> is {tok val ...} for EVERY
# owned field (val "" means the field is off / its token should be absent);
# <extra> is the current contents of the "Other properties" box.
#   * extras untouched (== schema_extra of <orig>): subst-into-original — only the
#     owned fields whose value actually changed are written back into <orig>, so
#     unchanged tokens keep their position and an unedited dialog returns <orig>
#     byte-for-byte (no spurious "modified").
#   * extras edited: rebuild from the edited <extra> as the base, overlaying every
#     owned field that is currently set (the Other box IS the non-owned portion).
proc slickprop::schema_assemble {schema orig desired extra} {
  set loaded {}
  foreach row [slickprop::schema_fields $schema $orig] {
    dict set loaded [dict get $row tok] [dict get $row value]
  }
  if {$extra eq [slickprop::schema_extra $schema $orig]} {
    set changes {}
    foreach {tok val} $desired {
      if {$val ne [dict get $loaded $tok]} { lappend changes $tok $val }
    }
    return [slickprop::apply $orig $changes]
  }
  set changes {}
  foreach {tok val} $desired {
    if {$val ne {}} { lappend changes $tok $val }
  }
  return [slickprop::apply $extra $changes]
}

# text_* : the enter_text dialog's view over the generic core (text_schema).
proc slickprop::text_fields   {prop}              { return [slickprop::schema_fields   [slickprop::text_schema] $prop] }
proc slickprop::text_extra    {prop}              { return [slickprop::schema_extra    [slickprop::text_schema] $prop] }
proc slickprop::text_assemble {orig desired extra} { return [slickprop::schema_assemble [slickprop::text_schema] $orig $desired $extra] }

# Should a bool field's checkbox be ticked for the token's CURRENT value? weight
# ticks only on 'bold' (weight=normal is not-bold); slant ticks on italic OR
# oblique (both are slanted); every other bool ticks on any truthy value — which
# includes hide=instance (hide-when-instantiated still means "hidden").
# Generic bool checkbox helpers (shared by the text and graphical panels).
# bool_checked: should the box be ticked for this token's current value? weight
# ticks only on 'bold'; slant on italic OR oblique; every other bool (incl. the
# graphical 'bezier' and hide=instance) ticks on any truthy value.
proc slickprop::bool_checked {tok value} {
  switch -- $tok {
    weight { return [expr {$value eq "bold"}] }
    slant  { return [expr {$value eq "italic" || $value eq "oblique"}] }
    default {
      set v [string tolower $value]
      return [expr {$v ne "" && $v ne "false" && $v ne "0" && $v ne "no"}]
    }
  }
}
# bool_value: the value to write for a bool field on OK. An UNCHANGED box returns
# the loaded raw value verbatim (so a value the on-value does not capture survives
# untouched); a freshly ticked box writes <on>; a freshly unticked box removes
# (empty). <on> is passed in so this is schema-agnostic.
proc slickprop::bool_value {on loaded chk0 chk} {
  if {$chk == $chk0} { return $loaded }
  if {$chk} { return $on }
  return {}
}

# text_* bool helpers: thin wrappers over the generic ones (text_schema knows the
# on-value), kept for the enter_text view and the TX9/TX10 tests.
proc slickprop::text_bool_checked {tok value} { return [slickprop::bool_checked $tok $value] }

# The token value to write back for a bool field on OK. <loaded> is the value the
# field opened with, <chk0> its initial tick state, <chk> its current tick state.
# An UNCHANGED checkbox returns the loaded raw value verbatim, so a value the
# schema's on-value does not capture (slant=oblique, hide=instance, weight=normal)
# is preserved untouched; a freshly ticked box writes the schema on-value; a
# freshly unticked box removes the token (empty).
proc slickprop::text_bool_value {tok loaded chk0 chk} {
  set on {}
  foreach row [slickprop::text_schema] {
    if {[dict get $row tok] eq $tok} { set on [dict get $row on]; break }
  }
  return [slickprop::bool_value $on $loaded $chk0 $chk]
}

# ===========================================================================
# THE FORM (Tk). Built on the core above. State for the single open dialog
# lives in slickprop::cur(...) (only one Edit Properties dialog exists at a
# time). Field-building and change-collection are factored out of the modal
# wrapper so they can be driven headlessly by tests.
# ===========================================================================

# --- Look-and-feel, USER-TUNABLE (Cadence-style: set these in a script or the
# CIW and they take effect the next time the form opens) -------------------
#   set slickprop_fontsize 13       ;# base font size for the whole form
#   set slickprop_entry_width 30    ;# value-entry width in characters
# Defaults: font size = the system TkDefaultFont size + 1 (a touch larger);
# entry width = 36. The form derives named fonts from these so labels/chrome use
# the platform UI font (TkDefaultFont) and editable VALUES use a monospace font
# (TkFixedFont) — values here are numbers/exprs/code (1.4 0.0 1.6 4.0, @value,
# m=@m), which monospace aligns and disambiguates (l/1/I, O/0), like an EDA grid.
# Colors are NOT hardcoded (except grey60 header bars, an xschem convention) so
# the form inherits the dark/light option-db theme.

# (re)create the four named fonts from the current slickprop_fontsize.
proc slickprop::init_fonts {} {
  if {![info exists ::slickprop_fontsize]} { set ::slickprop_fontsize 0 }
  if {$::slickprop_fontsize <= 0} {
    set nat [font actual TkDefaultFont -size]
    set ::slickprop_fontsize [expr {$nat > 0 ? $nat + 1 : 11}]
  }
  if {![info exists ::slickprop_entry_width] || $::slickprop_entry_width <= 0} {
    set ::slickprop_entry_width 36
  }
  set sz $::slickprop_fontsize
  slickprop::_mkfont slickPropLabel  TkDefaultFont $sz             normal
  slickprop::_mkfont slickPropValue  TkFixedFont   $sz             normal
  slickprop::_mkfont slickPropHeader TkDefaultFont [expr {$sz + 1}] bold
  slickprop::_mkfont slickPropHint   TkDefaultFont [expr {$sz - 2}] normal
}
proc slickprop::_mkfont {name base size weight} {
  if {[lsearch -exact [font names] $name] < 0} { font create $name }
  font configure $name {*}[font actual $base] -size $size -weight $weight
}

# accent for the "modified field" dot — a saturated amber, visible on light AND
# dark themes; overridable via ::slickprop_accent.
proc slickprop::accent {} {
  if {[info exists ::slickprop_accent] && $::slickprop_accent ne {}} { return $::slickprop_accent }
  return "#d08000"
}

# Refresh a field's modified-cue: show an accent dot in its indicator column when
# the entry's value differs from what it loaded with, blank when it matches. Bound
# to the entry's edit events so it tracks live as the user types.
proc slickprop::update_dirty {tok} {
  variable cur
  if {![info exists cur(ind,$tok)] || ![winfo exists $cur(ind,$tok)]} return
  if {[slickprop::field_value $tok] ne $cur(loaded,$tok)} {
    $cur(ind,$tok) configure -text "●"
  } else {
    $cur(ind,$tok) configure -text " "
  }
}

# Get the symbol's template (declared attributes), or "" if unavailable. If the
# symbol is not in the table yet (e.g. an identity change to a cell that has not
# been placed/loaded this session — issue 0057), load its definition on demand
# from the resolved absolute path and retry, so changing the cell can read the new
# cell's defaults before anything is applied.
proc slickprop::template_of {symbol} {
  if {![catch {xschem getprop symbol $symbol template} t]} { return $t }
  set abs $symbol
  catch {set abs [abs_sym_path $symbol]}
  catch {xschem load_symbol $abs}
  # load_symbol stores the definition under its rel_sym_path (lib-qualified) name,
  # so a lib/cell/view symbol loaded from an ABSOLUTE path is keyed as e.g.
  # "devices/res" — query every name form, not just the absolute one (issue 0057).
  set rel $abs
  catch {set rel [rel_sym_path $abs]}
  foreach ref [list $symbol $abs $rel] {
    if {$ref ne {} && ![catch {xschem getprop symbol $ref template} t]} { return $t }
  }
  return ""
}

# Build the per-field rows for <prop>+<template> into the frame <parent>,
# recording state in slickprop::cur. Each field is a label + a single-line entry.
# A declared-but-unset attr shows its template default as a greyed placeholder
# (not part of the value). Returns the list of token names placed.
proc slickprop::build_fields {parent prop template} {
  variable cur
  slickprop::init_fonts
  set ew $::slickprop_entry_width
  array unset cur
  # clear any prior field widgets (a rebuild on Next/Prev or Apply reuses the
  # same parent frame; the row widget names .i0/.l0/.e0/.xsep/... would collide)
  foreach w [winfo children $parent] { destroy $w }
  set cur(orig) $prop
  set cur(tokens) {}
  set fields [slickprop::to_fields $prop $template]
  set r 0
  set extras_started 0
  foreach f $fields {
    set tok      [dict get $f name]
    set val      [dict get $f value]
    set declared [dict get $f declared]
    set default  [dict get $f default]
    # a themed divider before the first undeclared "Extra" token (fixed widget
    # names — there is only one Extra section; tying them to $r broke because the
    # widgets are created before the row counter is advanced)
    if {!$declared && !$extras_started} {
      set extras_started 1
      ttk::separator $parent.xsep -orient horizontal
      label $parent.xlbl -text "Extra (undeclared)" -anchor w -font slickPropLabel
      grid $parent.xsep -row $r -column 0 -columnspan 3 -sticky we -pady {10 0} -padx 3
      incr r
      grid $parent.xlbl -row $r -column 1 -columnspan 2 -sticky w -pady {2 3} -padx 3
      incr r
    }
    # col 0: modified-cue dot | col 1: right-aligned label | col 2: monospace entry
    label $parent.i$r -text " " -width 2 -anchor center -font slickPropLabel -fg [slickprop::accent]
    label $parent.l$r -text $tok -anchor e -font slickPropLabel
    entry $parent.e$r -font slickPropValue -relief sunken -borderwidth 1 -width $ew
    grid $parent.i$r -row $r -column 0 -padx {2 0} -pady 4
    grid $parent.l$r -row $r -column 1 -sticky e -padx {2 8} -pady 4
    grid $parent.e$r -row $r -column 2 -sticky w -padx {0 8} -pady 4 -ipady 3 -ipadx 2
    set cur(ind,$tok)         $parent.i$r
    set cur(entry,$tok)       $parent.e$r
    set cur(loaded,$tok)      $val
    set cur(placeholder,$tok) 0
    set cur(normalfg,$tok)    [$parent.e$r cget -foreground] ;# theme default, for placeholder restore
    lappend cur(tokens) $tok
    if {$val ne {}} {
      $parent.e$r insert 0 $val
    } elseif {$default ne {}} {
      slickprop::set_placeholder $tok $default
    }
    # live modified-cue as the user edits
    bind $parent.e$r <KeyRelease> [list slickprop::update_dirty $tok]
    bind $parent.e$r <<Paste>>    [list after idle [list slickprop::update_dirty $tok]]
    bind $parent.e$r <<Cut>>      [list after idle [list slickprop::update_dirty $tok]]
    # P3: flag a varying field in the footer when this field gains focus
    # (appended so it coexists with the placeholder-clear FocusIn handler)
    bind $parent.e$r <FocusIn> +[list slickprop::on_focus $tok]
    incr r
  }
  grid columnconfigure $parent 1 -minsize 90   ;# fixed label column so labels align
  return $cur(tokens)
}

# Show <default> as a greyed placeholder in <tok>'s entry; clears on focus-in,
# restores on focus-out if left empty. While showing, the field value is empty.
proc slickprop::set_placeholder {tok default} {
  variable cur
  set e $cur(entry,$tok)
  $e delete 0 end
  $e insert 0 $default
  $e configure -foreground grey50 ;# muted, readable on both light and dark themes
  set cur(placeholder,$tok) 1
  bind $e <FocusIn>  [list slickprop::placeholder_in $tok]
  bind $e <FocusOut> [list slickprop::placeholder_out $tok $default]
}
proc slickprop::placeholder_in {tok} {
  variable cur
  if {$cur(placeholder,$tok)} {
    set e $cur(entry,$tok)
    $e delete 0 end
    $e configure -foreground $cur(normalfg,$tok) ;# restore the theme's normal fg
    set cur(placeholder,$tok) 0
  }
  slickprop::update_dirty $tok
}
proc slickprop::placeholder_out {tok default} {
  variable cur
  set e $cur(entry,$tok)
  if {[$e get] eq {}} { slickprop::set_placeholder $tok $default }
  slickprop::update_dirty $tok
}

# The effective current value of a field's entry (a showing placeholder is empty).
proc slickprop::field_value {tok} {
  variable cur
  if {$cur(placeholder,$tok)} { return {} }
  return [$cur(entry,$tok) get]
}

# Collect the {tok val ...} list of ONLY the fields whose value changed from what
# they loaded with — the input to slickprop::apply (subst-into-original).
proc slickprop::collect_changes {} {
  variable cur
  set changes {}
  foreach tok $cur(tokens) {
    set v [slickprop::field_value $tok]
    if {$v ne $cur(loaded,$tok)} { lappend changes $tok $v }
  }
  return $changes
}

# The new property string implied by the current field edits (for OK / tests).
proc slickprop::result {} {
  variable cur
  return [slickprop::apply $cur(orig) [slickprop::collect_changes]]
}

# Apply the current change set to the "Apply to" scope via the C engine (P2).
# Sets the symbol global + copy-cell intent (the C side reads them), replicates
# edit_prop's symbol-change / copy-cell file handling, populates tctx::retval
# (the legacy contract), then calls the mid-session `xschem apply_properties`
# command on the DISPLAYED instance (by session-stable id, so it survives any
# reindexing between applies). One Apply = one undo. Returns 1 if anything
# changed and flags tctx::applied so the C caller knows the slick path applied.
proc slickprop::do_apply {} {
  variable cur
  variable nav
  variable loaded_prop
  variable identity_pending
  global symbol prev_symbol copy_cell user_wants_copy_cell
  slickprop::lcv_compose_symbol     ;# fold any Library/Cell/View edit into the ref
  set symbol [.dialog.f1.e2 get]
  set abssymbol [abs_sym_path $symbol]
  set user_wants_copy_cell $copy_cell
  set prev_symbol [abs_sym_path $prev_symbol]
  if { ($abssymbol ne $prev_symbol) && $copy_cell } {
    if { ![regexp {^/} $symbol] && ![regexp {^[a-zA-Z]:} $symbol] } {
      set symlist [file split $symbol]
      set symlen [llength $symlist]
      set abssymbol "[path_head $prev_symbol $symlen]/$symbol"
    }
    if { [file exists "[file rootname $prev_symbol].sch"] } {
      if { ! [file exists "[file rootname ${abssymbol}].sch"] } {
        file copy "[file rootname $prev_symbol].sch" "[file rootname $abssymbol].sch"
      }
    }
    if { [file exists "$prev_symbol"] } {
      if { ! [file exists "$abssymbol"] } { file copy "$prev_symbol" "$abssymbol" }
    }
  }
  set ::tctx::retval [slickprop::result]   ;# keep the legacy C contract populated
  # old_prop baseline for the C diff (set_different_token). Normally this equals
  # cur(orig); after an identity change cur(orig) is the NEW cell's template (the
  # new_prop), while loaded_prop is still the instance's REAL old prop — exactly the
  # pair the diff needs to drop the old cell's tokens and adopt the new ones (0057).
  set oldprop $cur(orig)
  if {[info exists loaded_prop]} { set oldprop $loaded_prop }
  set did 0
  if {[info exists nav(disp_id)] && $nav(disp_id) ne {} && $nav(disp_id) >= 0} {
    set did [xschem apply_properties $::slickprop_apply_scope $nav(disp_id) \
               $::tctx::retval $oldprop]
    if {$did} {
      set ::tctx::applied 1
      # action-log the EFFECT (only when something changed): the replayable
      # command itself, so sourcing the log re-applies the edit. Logged here at
      # the interactive layer — NOT in the C engine, which the replay command and
      # CIW-typed commands reuse and would double-log (see
      # code_analysis/apply_properties_logging_decision.md).
      slickprop::log_apply [list xschem apply_properties \
        $::slickprop_apply_scope $nav(disp_id) $::tctx::retval $oldprop]
    }
  }
  set copy_cell 0
  set prev_symbol $symbol
  set identity_pending 0   ;# applied: identity change consumed
  return $did
}

# Append one replayable apply command to the action log (Xschem.log) and mirror
# it to the CIW pane, via the existing `xschem log_action` bridge. A thin seam:
# one place to evolve the logging, and the spy point the tests hook.
proc slickprop::log_apply {line} {
  catch {xschem log_action $line}
}

# Append one already-built line to the action log (sibling of log_apply, for
# non-command MARKER lines that begin with `#`). The marker is a Tcl comment, so
# sourcing the log on replay skips it — used to record interactive, non-replayable
# events (e.g. the form launch) for audit/readability without breaking replay.
proc slickprop::log_event {line} {
  catch {xschem log_action $line}
}

# The Apply button (P2): apply the change set to the scope and STAY OPEN,
# refreshing the displayed instance so its applied values become the new
# baseline (dirty dots clear, further edits diff against the applied state).
proc slickprop::apply_now {} {
  variable nav
  slickprop::do_apply
  if {[info exists nav(ids)] && [llength $nav(ids)] > 0} {
    slickprop::load_pos $nav(pos)
  }
}

# The OK action: apply the current change set to the scope, then close.
proc slickprop::ok {} {
  slickprop::do_apply
  set ::tctx::rcode {ok}
  set ::slickprop_form_open 0
  catch {set ::slickprop_geometry [wm geometry .dialog]} ;# remember size+pos
  catch {xschem highlight_scope clear}                   ;# remove the scope outline
  # M2: the close cleanup moved here from the (now removed) post-tkwait block.
  catch {trace remove variable ::slickprop_apply_scope write slickprop::apply_scope_greying}
  destroy .dialog
}

proc slickprop::cancel {} {
  global edit_symbol_prop_new_sel
  set ::tctx::rcode {}
  set ::slickprop_form_open 0
  set edit_symbol_prop_new_sel {}
  catch {set ::slickprop_geometry [wm geometry .dialog]} ;# remember size+pos
  catch {xschem highlight_scope clear}                   ;# remove the scope outline
  # M2: the close cleanup moved here from the (now removed) post-tkwait block.
  catch {trace remove variable ::slickprop_apply_scope write slickprop::apply_scope_greying}
  destroy .dialog
}

# ===========================================================================
# Apply-scope highlight (H1): a white outline around exactly the objects an
# OK/Apply would write to — the apply-scope set. C owns the drawing; the form
# just hands it the current scope + the displayed instance's STABLE id and lets
# C resolve the set the same way the apply does (so outlined == applied). Hung
# off the same triggers as P1's greying / P3's warning: the scope write-trace,
# load_pos (open + Next/Prev), and cleared on every close path (ok / cancel).
# Safe to call any time (guards on a displayed id existing); a no-op without a
# main window / when the command is absent.
# ===========================================================================
proc slickprop::update_highlight {} {
  variable nav
  set scope current
  if {[info exists ::slickprop_apply_scope]} { set scope $::slickprop_apply_scope }
  if {[info exists nav(disp_id)] && $nav(disp_id) ne {} && $nav(disp_id) >= 0} {
    catch {xschem highlight_scope $scope $nav(disp_id)}
  } else {
    catch {xschem highlight_scope clear}
  }
}

# ===========================================================================
# Modeless, selection-reactive editing (M1). While the form is open the user can
# keep selecting on the canvas; the C side unlocks SELECTION gestures at
# semaphore>=2 (move/wire/place stay locked) and fires on_selection_changed,
# which adopts the new selection into the nav set and refreshes the form (scope,
# warning, highlight). A selection change with unapplied edits asks first,
# Cadence-style: Apply / Discard / Cancel (Cancel restores the prior selection).
# Decision doc: code_analysis/modeless_property_form_decision.md.
# ===========================================================================

# True iff the active Library/Cell/View rows differ from what they loaded with —
# a pending master-cell change counts as dirty just like any edited field.
proc slickprop::lcv_dirty {} {
  variable loaded_lcv
  variable lcv_active
  if {![info exists lcv_active] || !$lcv_active} { return 0 }
  if {![winfo exists .dialog.flcv]} { return 0 }
  set now [list [string trim [.dialog.flcv.e0 get]] \
                [string trim [.dialog.flcv.e1 get]] \
                [string trim [.dialog.flcv.e2 get]]]
  return [expr {$now ne $loaded_lcv}]
}

# True iff any field's value (or the master L/C/V) differs from what it loaded
# with (gates the Apply/Discard prompt on Next/Prev and selection changes).
proc slickprop::is_dirty {} {
  variable cur
  variable identity_pending
  if {[info exists identity_pending] && $identity_pending} { return 1 }
  if {[slickprop::lcv_dirty]} { return 1 }
  if {![info exists cur(tokens)]} { return 0 }
  return [expr {[llength [slickprop::collect_changes]] > 0}]
}

# The selected instances' stable ids — the source of the nav set.
proc slickprop::selected_inst_ids {} {
  set ids {}
  foreach o [xschem objects -type instance -selected] { lappend ids [dict get $o id] }
  return $ids
}

# A human label for the displayed instance (used in the prompt message).
proc slickprop::disp_name {} {
  variable nav
  if {[info exists nav(disp_id)] && $nav(disp_id) ne {}} {
    set ix [xschem instance_index $nav(disp_id)]
    if {$ix >= 0} {
      set nm [xschem get_tok [xschem getprop instance $ix] name 2]
      if {$nm ne {}} { return $nm }
    }
  }
  return "this instance"
}

# If the form is dirty, ask whether to apply pending edits before leaving the
# current instance, then run <action> (Apply: do_apply first; Discard: just
# <action>) or <cancelaction> (Cancel: stay put / restore). Not dirty -> just
# <action>. Next/Prev and selection changes both route through here.
proc slickprop::maybe_apply_then {action cancelaction} {
  if {![slickprop::is_dirty]} { uplevel #0 $action; return }
  set ans [tk_messageBox -parent .dialog -icon question -type yesnocancel \
    -title "Edit Properties" \
    -message "Apply your changes to [slickprop::disp_name] before switching?"]
  switch -- $ans {
    yes     { slickprop::do_apply; uplevel #0 $action }
    no      { uplevel #0 $action }
    default { uplevel #0 $cancelaction }
  }
}

# Make <newids> the nav set and display the right instance (D4): keep the shown
# one if it is still selected, else the first. An empty selection keeps the form
# on the last instance (D5) — clearing the canvas must not yank the editor away.
proc slickprop::adopt_selection {newids} {
  variable nav
  if {[llength $newids] == 0} {
    set nav(ids) {}
    slickprop::update_nav_ui
    slickprop::update_highlight
    return
  }
  set nav(ids) $newids
  set pos 0
  if {[info exists nav(disp_id)] && $nav(disp_id) ne {}} {
    set ix [lsearch -exact $newids $nav(disp_id)]
    if {$ix >= 0} { set pos $ix }
  }
  slickprop::load_pos $pos
}

# Cancel path: re-select the previous set in the engine (by stable id) so canvas,
# form and highlight agree again, and stay on the current instance (no rebuild).
proc slickprop::restore_selection {oldids} {
  xschem unselect_all
  foreach id $oldids {
    set ix [xschem instance_index $id]
    if {$ix >= 0} { xschem select instance $ix }
  }
  slickprop::update_highlight
}

# Canvas-selection-changed hook (called from C on a Button1 selection while the
# form is open). Adopt the new selection into the nav set + refresh, asking about
# unapplied edits first. No-op if the selection set did not actually change.
proc slickprop::on_selection_changed {} {
  variable nav
  if {![winfo exists .dialog]} return
  set newids [slickprop::selected_inst_ids]
  set oldids {}
  if {[info exists nav(ids)]} { set oldids $nav(ids) }
  if {[lsort $newids] eq [lsort $oldids]} return   ;# unchanged -> no prompt/reload
  slickprop::maybe_apply_then \
    [list slickprop::adopt_selection $newids] \
    [list slickprop::restore_selection $oldids]
}

# ===========================================================================
# "Apply to" scope (multi-instance editing, P1). A sticky session global
# ::slickprop_apply_scope holds the canonical value (current|selected|all);
# the C side (update_symbol) reads it to decide which instances an Apply/OK
# touches. The form shows a readonly dropdown of display labels and greys the
# `name` field whenever the scope spans more than the current instance (a name
# is per-instance and must stay unique, so it is never fanned out).
# ===========================================================================

# canonical scope value  -> display label
proc slickprop::scope_label {v} {
  switch -- $v {
    selected { return "All Selected" }
    all      { return "All (same symbol)" }
    default  { return "Only Current" }
  }
}
# display label -> canonical scope value
proc slickprop::scope_value {label} {
  switch -- $label {
    "All Selected"      { return selected }
    "All (same symbol)" { return all }
    default             { return current }
  }
}

# Grey (disable) the name entry when the scope spans many instances, enable it
# for Only Current. Bound as a write trace on ::slickprop_apply_scope so it
# tracks live as the dropdown changes; safe to call when no name field exists.
# Also refreshes the "values differ" warning, which depends on the scope.
proc slickprop::apply_scope_greying {args} {
  variable cur
  slickprop::update_warning
  slickprop::update_highlight
  if {![info exists cur(entry,name)] || ![winfo exists $cur(entry,name)]} return
  if {![info exists ::slickprop_apply_scope]} { set ::slickprop_apply_scope current }
  if {$::slickprop_apply_scope eq "current"} {
    $cur(entry,name) configure -state normal
  } else {
    $cur(entry,name) configure -state disabled
  }
}

# ===========================================================================
# "Values differ" warning (P3). Under All Selected / All, applying the one
# edited value to many instances overwrites whatever each had. When the FOCUSED
# field's value is not uniform across the in-scope set, the footer hint turns
# red to flag that; it clears for a uniform field or scope=current.
# ===========================================================================

# the warning colour — a saturated red readable on light AND dark themes;
# overridable via ::slickprop_warn.
proc slickprop::warn_color {} {
  if {[info exists ::slickprop_warn] && $::slickprop_warn ne {}} { return $::slickprop_warn }
  return "#d02020"
}

# the instance indices currently in scope, relative to the displayed instance:
#   current  -> just the displayed one
#   selected -> the selected set (nav ids)
#   all      -> every instance of the displayed instance's master (same symbol)
proc slickprop::scope_instances {} {
  variable nav
  set scope current
  if {[info exists ::slickprop_apply_scope]} { set scope $::slickprop_apply_scope }
  set out {}
  if {$scope eq "selected"} {
    if {[info exists nav(ids)]} {
      foreach id $nav(ids) {
        set ix [xschem instance_index $id]
        if {$ix >= 0} { lappend out $ix }
      }
    }
  } elseif {$scope eq "all"} {
    if {[info exists nav(disp_id)] && $nav(disp_id) ne {}} {
      set didx [xschem instance_index $nav(disp_id)]
      if {$didx >= 0} {
        set master [xschem getprop instance $didx cell::name]
        set n [xschem get instances]
        for {set i 0} {$i < $n} {incr i} {
          if {[xschem getprop instance $i cell::name] eq $master} { lappend out $i }
        }
      }
    }
  } else {
    if {[info exists nav(disp_id)] && $nav(disp_id) ne {}} {
      set didx [xschem instance_index $nav(disp_id)]
      if {$didx >= 0} { lappend out $didx }
    }
  }
  return $out
}

# 1 if token <tok>'s clean value is not the same across all <insts>.
proc slickprop::field_varies {tok insts} {
  set first {}; set got 0
  foreach i $insts {
    set v [xschem get_tok [xschem getprop instance $i] $tok 2]
    if {!$got} { set first $v; set got 1 } elseif {$v ne $first} { return 1 }
  }
  return 0
}

# Record the focused field and refresh the warning. Bound to each entry's
# <FocusIn> (alongside the placeholder-clear handler).
proc slickprop::on_focus {tok} {
  variable nav
  set nav(focustok) $tok
  slickprop::update_warning
}

# Set or clear the footer warning for the currently-focused field under the
# current scope. Safe to call any time (guards on the widget existing).
proc slickprop::update_warning {} {
  variable nav
  if {![winfo exists .dialog.fb.hint]} return
  set tok {}
  if {[info exists nav(focustok)]} { set tok $nav(focustok) }
  set scope current
  if {[info exists ::slickprop_apply_scope]} { set scope $::slickprop_apply_scope }
  set warn {}
  if {$tok ne {} && $scope ne "current"} {
    set insts [slickprop::scope_instances]
    if {[llength $insts] > 1 && [slickprop::field_varies $tok $insts]} {
      set warn "⚠  '$tok' differs across [llength $insts] instances — Apply overwrites them"
    }
  }
  if {$warn ne {}} {
    .dialog.fb.hint configure -text $warn -fg [slickprop::warn_color]
  } else {
    .dialog.fb.hint configure -text "Enter: OK    Esc: Cancel" -fg grey50
  }
}

# ===========================================================================
# Next / Prev navigation through the selected set (P2). The nav state lives in
# the separate slickprop::nav array (NOT cur, which build_fields wipes on every
# rebuild): nav(ids) = the selected instances by session-stable id, nav(pos) =
# the displayed index, nav(disp_id) = the displayed instance's id. Scope governs
# what an Apply touches; Next/Prev only change WHICH instance is displayed.
# ===========================================================================

# Load the instance at nav position <pos> into the form: fetch its current props
# + symbol by stable id, refresh the header / symbol entry, and rebuild the field
# grid (which discards any pending edits on the instance being left).
proc slickprop::load_pos {pos} {
  variable cur
  variable nav
  variable loaded_prop
  variable identity_pending
  global symbol prev_symbol
  set n [llength $nav(ids)]
  if {$n == 0} return
  if {$pos < 0} { set pos 0 }
  if {$pos >= $n} { set pos [expr {$n - 1}] }
  set nav(pos) $pos
  set id [lindex $nav(ids) $pos]
  set nav(disp_id) $id
  set idx [xschem instance_index $id]
  if {$idx < 0} return   ;# stale id (should not happen during a modal session)
  set prop [xschem getprop instance $idx]
  set sym  [xschem getprop instance $idx cell::name]
  set symbol $sym
  set prev_symbol $sym
  set loaded_prop $prop          ;# apply baseline (old_prop); survives an identity rebuild
  set identity_pending 0         ;# fresh instance: no pending identity change yet
  if {[winfo exists .dialog.f1.e2]} {
    .dialog.f1.e2 delete 0 end
    .dialog.f1.e2 insert 0 $sym
  }
  set inst_name [xschem get_tok $prop name 2]
  set hdr $sym
  if {$inst_name ne {}} { set hdr "$inst_name  —  $sym" }
  if {[winfo exists .dialog.hdr]} { .dialog.hdr configure -text "  $hdr" }
  slickprop::update_lcv $sym
  slickprop::build_fields .dialog.fa.c.inner $prop [slickprop::template_of $sym]
  slickprop::apply_scope_greying
  slickprop::update_nav_ui
  slickprop::update_warning
}

# Step the displayed instance by <dir> (+1 Next / -1 Prev) within the selected
# set; a no-op past the ends. If the current instance has unapplied edits, ask
# first (Apply / Discard / Cancel) — the same prompt as a selection change, so
# moving away from a dirty instance is consistent everywhere (M1). Cancel stays.
proc slickprop::nav {dir} {
  variable nav
  if {![info exists nav(ids)] || [llength $nav(ids)] == 0} return
  set newpos [expr {$nav(pos) + $dir}]
  if {$newpos < 0 || $newpos >= [llength $nav(ids)]} return
  slickprop::maybe_apply_then [list slickprop::load_pos $newpos] {}
}

# Refresh the "k of N" readout and grey Prev at the first / Next at the last.
proc slickprop::update_nav_ui {} {
  variable nav
  if {![winfo exists .dialog.fnav]} return
  set n [llength $nav(ids)]
  set pos $nav(pos)
  if {$n < 1} { set n 1 }
  .dialog.fnav.pos configure -text "[expr {$pos + 1}] of $n"
  .dialog.fnav.prev configure -state [expr {$pos <= 0     ? "disabled" : "normal"}]
  .dialog.fnav.next configure -state [expr {$pos >= $n - 1 ? "disabled" : "normal"}]
}

# Populate (and show/hide) the master Library / Cell / View rows for the symbol
# reference <sym> of the DISPLAYED instance. Resolved from the OA library registry
# (library_inst_lcv maps the reference to {lib cell view}); it returns {} for
# anything that is not a registered library cell. So the three editable rows show
# for library instances and stay hidden for wires, pins, and non-library symbols
# — in which case the raw Symbol entry row (.dialog.f1) is shown instead. Called
# at build time and on every Next/Prev (load_pos), so the rows track the current
# instance. The registry lookup is `catch`ed: on builds without it the rows never
# appear and the form behaves exactly as before.
proc slickprop::update_lcv {sym} {
  variable loaded_lcv
  variable lcv_active
  if {![winfo exists .dialog.flcv]} return
  set lcv {}
  catch {set lcv [library_inst_lcv $sym]}
  if {[llength $lcv] == 3} {
    lassign $lcv lib cell view
    foreach {i v} [list 0 $lib 1 $cell 2 $view] {
      .dialog.flcv.e$i delete 0 end
      .dialog.flcv.e$i insert 0 $v
    }
    set loaded_lcv $lcv
    set lcv_active 1
    pack .dialog.flcv -side top -fill x -after .dialog.fscope
    catch {pack forget .dialog.f1}            ;# library instance: hide raw Symbol row
  } else {
    set loaded_lcv {}
    set lcv_active 0
    pack forget .dialog.flcv
    catch {pack .dialog.f1 -side top -fill x -pady {4 0} -after .dialog.fscope}
  }
}

# If the Library/Cell/View rows are active (a library instance) AND the user
# edited them, recompose them into the Symbol reference that the apply path
# consumes (.dialog.f1.e2), so an L/C/V edit re-points the instance at a different
# master cell. Unchanged L/C/V is a no-op (the original reference is preserved
# verbatim — no abs/relative churn). An unresolvable or non-symbol combination
# leaves the master untouched and warns, so a typo never blanks the reference.
proc slickprop::lcv_compose_symbol {} {
  variable loaded_lcv
  variable lcv_active
  if {![info exists lcv_active] || !$lcv_active} return
  if {![winfo exists .dialog.flcv]} return
  set lib  [string trim [.dialog.flcv.e0 get]]
  set cell [string trim [.dialog.flcv.e1 get]]
  set view [string trim [.dialog.flcv.e2 get]]
  if {[list $lib $cell $view] eq $loaded_lcv} return    ;# unchanged: keep original ref
  if {$lib eq {} || $cell eq {} || $view eq {}} {
    catch {ciw_echo "Library/Cell/View must all be set — master unchanged" error}
    return
  }
  set f {}
  catch {set f [xschem cellview_path "$lib/$cell" $view]}
  if {$f eq {} || ![string match *.sym $f]} {
    catch {ciw_echo "no '$view' symbol view for $lib/$cell — master unchanged" error}
    return
  }
  if {[winfo exists .dialog.f1.e2]} {
    .dialog.f1.e2 delete 0 end
    .dialog.f1.e2 insert 0 $f
  }
}

# ===========================================================================
# Identity change -> re-read the new cell and repopulate with defaults (0057).
# Changing the master (Library/Cell/View rows, or the raw Symbol entry) makes the
# displayed instance a DIFFERENT cell; the old cell's attributes do not apply to
# it, so the field grid must be rebuilt from the NEW symbol's template defaults —
# exactly as if a fresh instance of that cell had just been placed.
# ===========================================================================

# The symbol reference currently entered in the identity rows. With the L/C/V form
# active, compose lib/cell/view via cellview_path (same resolution as
# lcv_compose_symbol); otherwise read the raw Symbol entry. Returns {} when the
# combination is incomplete or does not resolve to a .sym, so a half-typed edit
# never triggers a reset.
proc slickprop::current_symbol_ref {} {
  variable lcv_active
  if {[info exists lcv_active] && $lcv_active && [winfo exists .dialog.flcv]} {
    set lib  [string trim [.dialog.flcv.e0 get]]
    set cell [string trim [.dialog.flcv.e1 get]]
    set view [string trim [.dialog.flcv.e2 get]]
    if {$lib eq {} || $cell eq {} || $view eq {}} { return {} }
    set f {}
    catch {set f [xschem cellview_path "$lib/$cell" $view]}
    if {$f eq {} || ![string match *.sym $f]} { return {} }
    return $f
  } elseif {[winfo exists .dialog.f1.e2]} {
    return [string trim [.dialog.f1.e2 get]]
  }
  return {}
}

# Commit handler for the identity rows. If the entered reference now names a
# DIFFERENT, resolvable symbol than the one displayed (compared by absolute path)
# AND that symbol has a readable template, adopt the new identity and rebuild the
# field grid from the new template's defaults. Unchanged / unresolvable / template-
# less references are a no-op, so a typo or a partial edit never wipes the fields.
proc slickprop::on_identity_changed {} {
  global symbol
  variable identity_pending
  if {![winfo exists .dialog]} return
  set newref [slickprop::current_symbol_ref]
  if {$newref eq {}} return                                  ;# incomplete / unresolvable
  if {[abs_sym_path $newref] eq [abs_sym_path $symbol]} return ;# same master: nothing to do
  set template [slickprop::template_of $newref]
  if {$template eq {}} return                                ;# unknown symbol: keep fields
  # adopt the new master for the rest of the form + apply machinery (prev_symbol is
  # intentionally left at the ORIGINAL so do_apply still sees a symbol change and the
  # copy-cell path keys off the real previous master)
  set symbol $newref
  if {[winfo exists .dialog.f1.e2]} {
    .dialog.f1.e2 delete 0 end
    .dialog.f1.e2 insert 0 $newref
  }
  set inst_name [xschem get_tok $template name 2]
  set hdr $newref
  if {$inst_name ne {}} { set hdr "$inst_name  —  $newref" }
  if {[winfo exists .dialog.hdr]} { .dialog.hdr configure -text "  $hdr" }
  slickprop::update_lcv $newref                              ;# resync L/C/V rows + loaded_lcv
  # the heart of the fix: defaults of the new cell (prop == template -> declared
  # tokens shown with their default values, like a freshly placed instance)
  slickprop::build_fields .dialog.fa.c.inner $template $template
  set identity_pending 1                                     ;# a real pending change (gates is_dirty)
  catch {slickprop::apply_scope_greying}
  catch {slickprop::update_warning}
}

# Wire the identity-change handler onto the L/C/V entries and the raw Symbol entry,
# firing when an edit is committed (focus leaves the field or Return is pressed).
proc slickprop::bind_identity_rows {} {
  foreach e {.dialog.flcv.e0 .dialog.flcv.e1 .dialog.flcv.e2 .dialog.f1.e2} {
    if {[winfo exists $e]} {
      bind $e <FocusOut>      +[list slickprop::on_identity_changed]
      bind $e <Key-Return>    +[list slickprop::on_identity_changed]
      bind $e <Key-KP_Enter>  +[list slickprop::on_identity_changed]
    }
  }
}

# The slick replacement for the legacy edit_prop dialog: one single-line entry
# per declared symbol attribute (Cadence-style, strict), Enter=OK / Escape=Cancel.
# Same C contract as the old edit_prop: reads tctx::retval (current property
# string) and the `symbol` global on entry; sets tctx::retval (new string) +
# tctx::rcode ({ok}|{}). MODELESS (M2, issue 0009): returns immediately (no
# tkwait) with the form floating; the apply happens later via OK/Apply, so the
# returned rcode is {} and the x==0 instance path ignores it.
proc slickprop::edit_form {txtlabel} {
  global symbol prev_symbol no_change_attrs preserve_unchanged_attrs copy_cell
  global user_wants_copy_cell edit_prop_size edit_prop_pos edit_symbol_prop_new_sel
  variable nav
  set user_wants_copy_cell 0
  set ::tctx::rcode {}
  set ::tctx::retval_orig $::tctx::retval
  if { [winfo exists .dialog] } return
  # sticky "Apply to" scope: default Only Current, retained across opens
  if {![info exists ::slickprop_apply_scope]} { set ::slickprop_apply_scope current }
  slickprop::init_fonts
  set ::slickprop_form_open 1   ;# modeless (M2): form floats, canvas stays fully live
  # record the LAUNCH as a non-replayable marker (every launch route — q / menu /
  # `xschem edit_prop` — converges here). A `#` comment, so replay skips it: the
  # launch is an intention (not an effect); only the apply is replayable (logged
  # separately).
  slickprop::log_event \
    "# xschem edit_prop $::slickprop_apply_scope — Edit Properties form opened (non-replayable)"
  toplevel .dialog -class Dialog
  wm title .dialog {Edit Properties}
  # M2 (issue 0009): a PLAIN toplevel — NOT `wm transient` — so the WM lets the
  # user click/activate the schematic window independently while the form floats.
  # We `raise` it once at the end so it is not born behind the main window.
  set X [expr {[winfo pointerx .dialog] - 60}]
  set Y [expr {[winfo pointery .dialog] - 35}]
  wm geometry .dialog "+$X+$Y"

  set prev_symbol $symbol

  # --- header bar: what is being edited (xschem grey60 bold convention) -----
  set inst_name [xschem get_tok $::tctx::retval name 2]
  set hdr $symbol
  if {$inst_name ne {}} { set hdr "$inst_name  —  $symbol" }
  label .dialog.hdr -text "  $hdr" -bg grey60 -anchor w -font slickPropHeader
  pack .dialog.hdr -side top -fill x

  # --- master Library / Cell / View rows (Cadence-style, editable) ----------
  # Three editable rows identifying the instance's master. Shown for library
  # instances (hidden for wires/pins/non-library, where the raw Symbol row below
  # is shown instead — see update_lcv). Editing a row re-points the instance at a
  # different master on Apply/OK (lcv_compose_symbol folds them into the Symbol
  # reference). Built here unpacked; update_lcv packs + populates it.
  frame .dialog.flcv
  foreach {i lbl} {0 Library 1 Cell 2 View} {
    label .dialog.flcv.l$i -text $lbl -font slickPropLabel -anchor w -width 8
    entry .dialog.flcv.e$i -font slickPropValue -relief sunken -borderwidth 1
    grid  .dialog.flcv.l$i .dialog.flcv.e$i -sticky we -padx {4 6} -pady 1
  }
  grid columnconfigure .dialog.flcv 1 -weight 1

  # --- "Apply to" scope selector (sticky; the C side reads the canonical var) -
  frame .dialog.fscope
  label .dialog.fscope.l -text "Apply to" -font slickPropLabel
  ttk::combobox .dialog.fscope.cb -state readonly -width 20 -font slickPropLabel \
    -values [list "Only Current" "All Selected" "All (same symbol)"]
  .dialog.fscope.cb set [slickprop::scope_label $::slickprop_apply_scope]
  bind .dialog.fscope.cb <<ComboboxSelected>> {
    set ::slickprop_apply_scope [slickprop::scope_value [.dialog.fscope.cb get]]
  }
  pack .dialog.fscope.l  -side left -padx {4 6} -pady {2 0}
  pack .dialog.fscope.cb -side left -pady {2 0}
  pack .dialog.fscope -side top -fill x -after .dialog.hdr

  # --- top: symbol entry + Browse -----------------------------------------
  frame .dialog.f1
  label .dialog.f1.l2 -text "Symbol" -font slickPropLabel
  entry .dialog.f1.e2 -width 30 -font slickPropValue -relief sunken -borderwidth 1
  .dialog.f1.e2 insert 0 $symbol
  button .dialog.f1.b5 -text "Browse" -font slickPropLabel -command {
    set r [tk_getOpenFile -parent .dialog -initialdir $INITIALINSTDIR]
    if {$r ne {}} { .dialog.f1.e2 delete 0 end; .dialog.f1.e2 insert 0 $r }
    raise .dialog .drw
  }
  pack .dialog.f1.l2 -side left -padx {4 6}
  pack .dialog.f1.e2 -side left -fill x -expand yes
  pack .dialog.f1.b5 -side left -padx {6 4}

  # --- options row (the legacy checkbuttons; their globals are read by C) ---
  # "Preserve unchanged props" is omitted: changed-fields-only is now the
  # unconditional contract for instance edits (governed by the "Apply to" scope),
  # so the checkbox would be inert. Its global is still created so any C/Tcl
  # reader sees a defined value.
  frame .dialog.f2
  checkbutton .dialog.f2.r1 -text "No change properties" -variable no_change_attrs -font slickPropLabel
  checkbutton .dialog.f2.r2 -text "Preserve unchanged props" -variable preserve_unchanged_attrs -font slickPropLabel
  checkbutton .dialog.f2.r3 -text "Copy cell" -variable copy_cell -font slickPropLabel
  pack .dialog.f2.r1 .dialog.f2.r3 -side left -padx 2

  # --- scrollable per-field area ------------------------------------------
  frame .dialog.fa
  canvas .dialog.fa.c -yscrollcommand ".dialog.fa.sb set" -highlightthickness 0
  scrollbar .dialog.fa.sb -command ".dialog.fa.c yview" -orient vertical
  frame .dialog.fa.c.inner
  .dialog.fa.c create window 0 0 -anchor nw -window .dialog.fa.c.inner -tags inner
  bind .dialog.fa.c.inner <Configure> {
    .dialog.fa.c configure -scrollregion [.dialog.fa.c bbox all]
    .dialog.fa.c itemconfigure inner -width [winfo width .dialog.fa.c]
  }
  pack .dialog.fa.sb -side right -fill y
  pack .dialog.fa.c -side left -fill both -expand yes

  # --- Next/Prev navigation through the selected set (P2) -------------------
  frame .dialog.fnav
  button .dialog.fnav.prev -text "◀ Prev" -command {slickprop::nav -1} -width 8 -font slickPropLabel
  label  .dialog.fnav.pos  -text "1 of 1" -width 10 -anchor center -font slickPropLabel
  button .dialog.fnav.next -text "Next ▶" -command {slickprop::nav 1} -width 8 -font slickPropLabel
  pack .dialog.fnav.prev .dialog.fnav.pos .dialog.fnav.next -side left -padx 2 -pady {3 0}

  # --- bottom: OK / Apply / Cancel (OK is the default button) + a hint -------
  frame .dialog.fb
  button .dialog.fb.ok     -text "OK"     -command slickprop::ok        -width 8 -default active -font slickPropLabel
  button .dialog.fb.apply  -text "Apply"  -command slickprop::apply_now -width 8 -default normal -font slickPropLabel
  button .dialog.fb.cancel -text "Cancel" -command slickprop::cancel    -width 8 -default normal -font slickPropLabel
  label  .dialog.fb.hint   -text "Enter: OK    Esc: Cancel" -fg grey50 -font slickPropHint
  pack .dialog.fb.cancel -side right -padx {2 6} -pady 4
  pack .dialog.fb.apply  -side right -padx 2 -pady 4
  pack .dialog.fb.ok     -side right -padx 2 -pady 4
  pack .dialog.fb.hint   -side left  -padx 8

  pack .dialog.f1 -side top -fill x -pady {4 0}
  pack .dialog.f2 -side top -fill x
  pack .dialog.fb   -side bottom -fill x
  pack .dialog.fnav -side bottom -fill x
  pack .dialog.fa -side top -fill both -expand yes -pady 2

  # --- nav set + initial display: the selected instances by stable id (P2) ---
  # populate from the ids the C side handed over (tctx::edit_sel_ids / inst_id);
  # fall back to the legacy single-shot path (build from tctx::retval) when no
  # ids are present (e.g. edit_form driven directly by a test).
  array unset nav
  set nav(ids) {}
  set nav(pos) 0
  set nav(disp_id) {}
  if {[info exists ::tctx::edit_sel_ids]} { set nav(ids) $::tctx::edit_sel_ids }
  if {[info exists ::tctx::edit_inst_id] && $::tctx::edit_inst_id ne {} &&
      $::tctx::edit_inst_id >= 0} {
    set ix [lsearch -exact $nav(ids) $::tctx::edit_inst_id]
    if {$ix >= 0} {
      set nav(pos) $ix
    } else {
      set nav(ids) [list $::tctx::edit_inst_id]
      set nav(pos) 0
    }
  }
  if {[llength $nav(ids)] > 0} {
    slickprop::load_pos $nav(pos)
  } else {
    slickprop::build_fields .dialog.fa.c.inner $::tctx::retval [slickprop::template_of $symbol]
    set slickprop::loaded_prop $::tctx::retval   ;# apply baseline for the single-shot path
    set slickprop::identity_pending 0
    slickprop::update_nav_ui
  }
  # show/populate the Library/Cell/View rows for the displayed instance (the nav
  # path already did this via load_pos; this covers the single-shot else path).
  slickprop::update_lcv $symbol
  # react to an identity (Library/Cell/View or Symbol) change: re-read the new cell
  # and repopulate the fields with its defaults (issue 0057)
  slickprop::bind_identity_rows

  # grey the name field live with the scope (and apply the initial state)
  trace add variable ::slickprop_apply_scope write slickprop::apply_scope_greying
  slickprop::apply_scope_greying

  # size the scroll area to the content, capped (so tall forms scroll, short
  # ones are compact) — a light size-to-content.
  update idletasks
  set iw [winfo reqwidth  .dialog.fa.c.inner]
  set ih [winfo reqheight .dialog.fa.c.inner]
  if {$iw < 300} {set iw 300}
  if {$ih > 460} {set ih 460}
  .dialog.fa.c configure -width $iw -height $ih

  # remembered size+position: if the user resized/moved a previous dialog, reuse
  # that geometry instead of the content-derived natural size.
  if {[info exists ::slickprop_geometry] && $::slickprop_geometry ne {}} {
    catch {wm geometry .dialog $::slickprop_geometry}
  }

  # mouse-wheel scrolling over the field area (X11 buttons 4/5 + Win/Mac wheel)
  bind .dialog <Button-4>   {.dialog.fa.c yview scroll -1 units}
  bind .dialog <Button-5>   {.dialog.fa.c yview scroll  1 units}
  bind .dialog <MouseWheel> {.dialog.fa.c yview scroll [expr {%D > 0 ? -1 : 1}] units}

  # --- keyboard contract: Enter = OK, Escape = Cancel, Alt+arrows = Next/Prev
  bind .dialog <Return>     {slickprop::ok}
  bind .dialog <KP_Enter>   {slickprop::ok}
  bind .dialog <Escape>     {slickprop::cancel}
  bind .dialog <Alt-Right>  {slickprop::nav 1}
  bind .dialog <Alt-Left>   {slickprop::nav -1}
  wm protocol .dialog WM_DELETE_WINDOW {slickprop::cancel}

  # focus + select the most-likely-to-edit field (the symbol's `select` attr,
  # else value/lab/name), mirroring the legacy dialog's cursor placement.
  set sel_attr [xschem get_tok $::tctx::retval select]
  if {$sel_attr eq {}} { catch {set sel_attr [xschem getprop symbol $symbol select]} }
  set focused 0
  foreach a [list $sel_attr value lab name] {
    if {$a ne {} && [info exists slickprop::cur(entry,$a)]} {
      set e $slickprop::cur(entry,$a)
      focus $e; $e selection range 0 end; $e icursor end
      set focused 1; break
    }
  }
  if {!$focused && [llength $slickprop::cur(tokens)]} {
    focus $slickprop::cur(entry,[lindex $slickprop::cur(tokens) 0])
  }

  raise .dialog                 ;# M2: float in front initially (no transient), non-capturing
  # M2 (issue 0009): NON-BLOCKING. We deliberately do NOT `tkwait` here — edit_form
  # returns immediately and the launching callback unwinds, so callback()'s
  # re-entrancy semaphore drops back to 0 and the schematic accepts ALL bound
  # commands while the form floats (was: tkwait kept the launching frame on the C
  # stack, pinning semaphore>=2 and blocking everything but zoom + Shift-select).
  # The form lives as an independent toplevel; OK/Cancel (slickprop::ok /
  # ::cancel) do the apply + the close cleanup (clear the flag, remove the scope
  # trace, destroy). rcode is {} here and is ignored by the x==0 instance path,
  # which applies mid-session via `xschem apply_properties`.
  return $::tctx::rcode
}
