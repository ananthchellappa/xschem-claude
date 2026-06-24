#
#  File: action_registry.tcl
#
#  This file is part of XSCHEM.
#
#  A declarative action registry: a single table (loaded from actions.csv) that
#  drives menus and the command palette. Keeping user actions as data — instead
#  of hand-syncing menu items, accelerators and help text — is what makes UI/UX
#  features (palette, customizable shortcuts, toolbars, tooltips) cheap to add.
#
#  Phase 1 scope: generate the File menu from the table, and offer a command
#  palette over it. The C keysym dispatcher (callback.c handle_key_press) is
#  untouched and remains the source of truth for keyboard handling; the 'accel'
#  column here is a display string only.
#
#  This file is GPL like the rest of XSCHEM (see xschem.tcl header).

# --- CSV parsing -------------------------------------------------------------

# Parse one RFC4180-style CSV line into a list of fields. Handles quoted fields
# containing commas and doubled "" escapes. Embedded newlines are not supported
# (the registry keeps every row on a single line).
proc action_parse_csv_line {line} {
  set fields {}
  set field {}
  set inq 0
  set n [string length $line]
  for {set i 0} {$i < $n} {incr i} {
    set c [string index $line $i]
    if {$inq} {
      if {$c eq "\""} {
        if {[string index $line [expr {$i + 1}]] eq "\""} {
          append field "\""
          incr i
        } else {
          set inq 0
        }
      } else {
        append field $c
      }
    } else {
      if {$c eq "\""} {
        set inq 1
      } elseif {$c eq ","} {
        lappend fields $field
        set field {}
      } else {
        append field $c
      }
    }
  }
  if {$inq} {
    puts stderr "action registry: unterminated quoted field in CSV line: [string range $line 0 60]..."
  }
  lappend fields $field
  return $fields
}

# Load actions.csv from the share dir into the global 'action_table' as an
# ordered list of dicts (one per row). Comment (#) and blank lines are skipped;
# the first non-comment line is the header that names the dict keys.
proc load_action_table {} {
  global XSCHEM_SHAREDIR action_table
  set action_table {}
  set path $XSCHEM_SHAREDIR/actions.csv
  if {![file exists $path]} {
    puts stderr "action registry: $path not found; menus fall back to hand-written items"
    return 0
  }
  set fp [open $path r]
  set data [read $fp]
  close $fp
  set header {}
  foreach rawline [split $data "\n"] {
    set line [string trimright $rawline "\r"]
    if {$line eq {}} continue
    if {[string index $line 0] eq "#"} continue
    set fields [action_parse_csv_line $line]
    if {$header eq {}} {
      set header $fields
      continue
    }
    if {[llength $fields] != [llength $header]} {
      puts stderr "action registry: skipping malformed row (got [llength $fields] fields, expected [llength $header]): $line"
      continue
    }
    set row {}
    foreach col $header val $fields {
      dict set row $col $val
    }
    lappend action_table $row
  }
  return [llength $action_table]
}

# --- menu generation ---------------------------------------------------------

# Build (populate) the menu widget <topwin>.menubar.<menukey> from every table
# row whose 'menu' field equals <menukey>, in table order. Submenus recurse;
# dynamic submenus delegate to their populate hook. The parent menu widget is
# expected to already exist (created in build_widgets like the other menus).
proc build_menu_from_table {topwin menukey} {
  global action_table
  set m $topwin.menubar.$menukey
  foreach row $action_table {
    if {[dict get $row menu] ne $menukey} continue
    set type [dict get $row type]
    set label [dict get $row label]
    set accel [dict get $row accel]
    switch -- $type {
      separator {
        $m add separator
      }
      command {
        set opts [list -label $label -command [dict get $row command]]
        if {$accel ne {}} { lappend opts -accelerator $accel }
        $m add command {*}$opts
      }
      cascade {
        set sub [dict get $row submenu]
        set subw $topwin.menubar.$sub
        if {![winfo exists $subw]} {
          menu $subw -tearoff 0 -takefocus 0
        }
        $m add cascade -label $label -menu $subw
        build_menu_from_table $topwin $sub
      }
      dynamic {
        set sub [dict get $row submenu]
        set subw $topwin.menubar.$sub
        set hook [dict get $row hook]
        if {![winfo exists $subw]} {
          set postcmd [expr {$hook ne {} ? [list $hook $topwin] : {}}]
          menu $subw -tearoff 0 -takefocus 0 -postcommand $postcmd
        }
        $m add cascade -label $label -menu $subw
      }
      default {
        puts stderr "action registry: unknown row type '$type' for [dict get $row id]"
      }
    }
  }
}

# --- actions extracted from inline menu scripts ------------------------------
# These were inline -command {...} bodies in the File menu; promoting them to
# named procs keeps every 'command' field in the table a clean single call.

proc action_component_browser {} {
  global new_file_browser
  if {$new_file_browser} {
    file_chooser
  } else {
    load_file_dialog {Insert symbol} *.sym INITIALINSTDIR 2
  }
}

proc action_reload {} {
  if {[alert_ "Are you sure you want to reload?" {} 0 1] == 1} {
    xschem reload
  }
}

# --- data-driven keyboard accelerators ---------------------------------------
# Phase 2: generate real key bindings from the table's 'accel' column instead of
# hardcoding them in the C handle_key_press chain (callback.c). Each generated
# binding is installed on the drawing widget in set_bindings; because a binding
# with a key detail (e.g. <Control-Key-z>) is more *specific* than the generic
# <KeyPress> binding on the same widget, Tk fires only the specific one, so the
# C keysym dispatcher is bypassed for migrated keys ONLY. The C side is untouched
# and still owns every key not migrated here.
#
# Migration is deliberately incremental: only action ids in migrated_action_ids
# are bound. Keys that depend on in-progress editing state, infix-mode placement,
# or whether the mouse is over a waveform graph stay in C and are NOT listed.

# Action ids whose keyboard shortcut is generated from the table (and so bypass
# the C handle_key_press chain). Grown one small, empirically-verified batch at a
# time. Anything not listed here is still handled exactly as before by C.
set migrated_action_ids {
  edit.undo
  edit.redo
  view.zoom_in
  view.zoom_out
}

# Translate an accelerator DISPLAY string (e.g. "Ctrl+S", "Shift+Z", "Alt-F",
# "U") into a real Tk event sequence (e.g. <Control-Key-s>, <Shift-Key-Z>,
# <Alt-Key-f>, <Key-u>). Returns {} when the accel is not a single, bindable
# keyboard shortcut (empty, mouse button, "Print Scrn", multi-key alternatives
# like "Ins, Shift-I", a still-unhandled symbol key, or an unknown modifier);
# the caller logs and leaves those to C.
#
# IMPORTANT: the real keysym, not the display casing, decides the binding. A
# bare letter with no Shift maps to the LOWERCASE keysym ("U" undo -> <Key-u>,
# matching C's case 'u'); a letter WITH Shift maps to the uppercase keysym
# ("Shift+U" redo -> <Shift-Key-U>, matching C's case 'U'). This mirrors how C
# strips ShiftMask and switches on the character keysym.
proc accel_to_tk_sequence {accel} {
  if {$accel eq {}} { return {} }
  # Not single keyboard shortcuts: alternatives, mouse buttons, special labels.
  if {[string match *,* $accel]}      { return {} } ;# e.g. "Ins, Shift-I"
  if {[string match *Butt.* $accel]}  { return {} } ;# mouse button
  if {[string match *Scrn* $accel]}   { return {} } ;# "Print Scrn"
  if {[string match {* *} $accel]}    { return {} } ;# any space => multi-word

  # Split into modifier tokens + a final key token. '+' and '-' both separate.
  set tokens {}
  foreach t [split [string map {+ -} $accel] -] {
    if {$t ne {}} { lappend tokens $t }
  }
  if {[llength $tokens] == 0} { return {} }
  set keytok [lindex $tokens end]
  set modtoks [lrange $tokens 0 end-1]

  # Normalize modifiers; bail on anything we don't recognize.
  set mods {}
  set shift 0
  foreach m $modtoks {
    switch -- $m {
      Ctrl - Control { lappend mods Control }
      Alt            { lappend mods Alt }
      Shift          { set shift 1 }
      default        { return {} } ;# unknown modifier (Meta/Super/...) -> leave to C
    }
  }

  # Resolve the key token into a Tk keysym.
  set symkeys {
    # numbersign    = equal         * asterisk
    & ampersand     ! exclam        @ at           ^ asciicircum
    ~ asciitilde    | bar           \\ backslash     > greater
    < less          ? question
  }
  set namedkeys {
    Del Delete       Ins Insert      Esc Escape     Tab Tab
    Return Return    BackSpace BackSpace  Space space
    F1 F1  F2 F2  F3 F3  F4 F4  F5 F5  F6 F6
    F7 F7  F8 F8  F9 F9  F10 F10  F11 F11  F12 F12
    Up Up  Down Down  Left Left  Right Right
    Home Home  End End  PgUp Prior  PgDn Next
  }

  if {[string length $keytok] == 1 && [string is alpha $keytok]} {
    if {$shift} {
      set keysym [string toupper $keytok]
    } else {
      set keysym [string tolower $keytok]
    }
  } elseif {[string length $keytok] == 1 && [string is digit $keytok]} {
    set keysym $keytok
    if {$shift} { lappend mods Shift } ;# digit row keeps Shift as a real modifier
  } elseif {[string length $keytok] == 1 && [dict exists $symkeys $keytok]} {
    set keysym [dict get $symkeys $keytok]
    if {$shift} { lappend mods Shift }
  } elseif {[string length $keytok] > 1 && [dict exists $namedkeys $keytok]} {
    set keysym [dict get $namedkeys $keytok]
    if {$shift} { lappend mods Shift }
  } else {
    # Unhandled key
    return {}
  }

  # Emit modifiers in canonical order (Control, Alt, Shift) like the palette
  # binding <Control-Shift-Key-P>, then the keysym.
  set seq {}
  if {[lsearch -exact $mods Control] >= 0} { lappend seq Control }
  if {[lsearch -exact $mods Alt] >= 0}     { lappend seq Alt }
  if {$shift && [string length $keytok] == 1 && [string is alpha $keytok]} { lappend seq Shift }
  if {[lsearch -exact $mods Shift] >= 0}   { lappend seq Shift } ;# digit, sym, or named Shift
  lappend seq Key $keysym
  return "<[join $seq -]>"
}

# Run a table command at global scope, reporting (not raising) errors so a bad
# binding can't take down the event loop. Mirrors the command palette's runner.
proc run_action {cmd} {
  if {[catch {uplevel #0 $cmd} err]} {
    puts stderr "action registry: error running '$cmd': $err"
  }
}

# Install the generated accelerators on the drawing widget <topwin>. Only rows in
# migrated_action_ids are bound; each pre-empts the generic <KeyPress> binding so
# C never sees that key. Untranslatable accels are logged and left to C.
#
# Re-runnable: any sequence this proc bound on a previous call for $topwin is
# removed first, so editing an accel in the table and re-running moves the
# binding (the old key reverts to the generic <KeyPress> -> C path). This is what
# makes shortcuts genuinely remappable, not just generated once at startup.
proc bind_accelerators_from_table {topwin} {
  global action_table migrated_action_ids accel_bound_seqs
  # release previously generated bindings for this widget
  if {[info exists accel_bound_seqs($topwin)]} {
    foreach seq $accel_bound_seqs($topwin) { bind $topwin $seq {} }
  }
  set accel_bound_seqs($topwin) {}
  foreach row $action_table {
    set id [dict get $row id]
    if {[lsearch -exact $migrated_action_ids $id] < 0} continue
    if {[dict get $row type] ne {command}} continue
    set accel [dict get $row accel]
    set seq [accel_to_tk_sequence $accel]
    if {$seq eq {}} {
      puts stderr "action registry: '$id' accel '$accel' not translatable; left to C"
      continue
    }
    set cmd [dict get $row command]
    bind $topwin $seq "if {\[should_handle_unmodified %s\]} { run_action [list $cmd]; break }"
    lappend accel_bound_seqs($topwin) $seq
  }
}

# Run $cmd only if no modifier keys are held (modifier bitmask %s == 0).
# This prevents plain-key bindings (e.g. <Key-u>) from stealing modifier
# combinations (e.g. Ctrl+U, Alt+U) that C handles via rstate.
proc should_handle_unmodified {state} {
  # Allow NumLock (Mod2Mask=0x10) and CapsLock (LockMask=0x02) as "no modifier"
  set ignore [expr {[winfo pixels . 1] ? 0x12 : 0x12}]  ;# Mod2|LockMask
  return [expr {($state & ~0x12) == 0}]
}

# Change one action's accelerator at runtime and re-install bindings so the new
# key takes effect immediately (old key reverts to C). Returns the new Tk
# sequence, or {} if the new accel isn't a bindable shortcut. This is the
# programmatic core a future "customize shortcuts" dialog would call; it proves
# the table is the single source of truth for keys.
proc remap_action_accel {id new_accel} {
  global action_table accel_bound_seqs
  set found 0
  set newtab {}
  foreach row $action_table {
    if {[dict get $row id] eq $id} {
      dict set row accel $new_accel
      set found 1
    }
    lappend newtab $row
  }
  if {!$found} { puts stderr "remap_action_accel: no such id '$id'"; return {} }
  set action_table $newtab
  foreach topwin [array names accel_bound_seqs] {
    bind_accelerators_from_table $topwin
  }
  return [accel_to_tk_sequence $new_accel]
}

# --- generated keybindings cheat-sheet ---------------------------------------
# Build the keyboard-shortcut cheat-sheet FROM the action table, so it can never
# drift from the actual bindings (which are also generated from the same table).
# Replaces the hand-maintained prose in keys.help. Rows migrated to the
# data-driven binding (migrated_action_ids) are flagged with '*'; the rest show
# the accel that the C handle_key_press chain implements.
proc generate_keybindings_text {} {
  global action_table migrated_action_ids
  set lines {}
  lappend lines "XSCHEM KEYBOARD SHORTCUTS"
  lappend lines "Generated from actions.csv - do not edit by hand."
  lappend lines [string repeat - 64]
  lappend lines ""
  # menus in first-seen table order
  set menus {}
  foreach row $action_table {
    set m [dict get $row menu]
    if {$m ne {} && [lsearch -exact $menus $m] < 0} { lappend menus $m }
  }
  foreach m $menus {
    set section {}
    foreach row $action_table {
      if {[dict get $row menu] ne $m} continue
      if {[dict get $row type] ne {command}} continue
      set accel [dict get $row accel]
      if {$accel eq {}} continue
      set mark [expr {[lsearch -exact $migrated_action_ids [dict get $row id]] >= 0 ? "*" : " "}]
      lappend section [format "  %s %-24s %s" $mark $accel [dict get $row label]]
    }
    if {[llength $section]} {
      lappend lines "\[$m\]"
      foreach s $section { lappend lines $s }
      lappend lines ""
    }
  }
  lappend lines [string repeat - 64]
  lappend lines "  * = data-driven binding (remappable, set in actions.csv)."
  return [join $lines "\n"]
}

# Show the generated cheat-sheet in a read-only window.
proc show_keybindings_help {} {
  viewdata [generate_keybindings_text] ro .keybindings_help
}

# --- command palette ---------------------------------------------------------
# Fuzzy-searchable launcher over the action table. Reuses fuzzy_subseq_score
# (the file-chooser matcher in xschem.tcl). Bound to Ctrl+Shift+P in
# set_bindings; runs entirely in the UI layer (does not go through the C
# keysym dispatcher).

# Rebuild the result list to match the current query. Guarded so that arrow/
# Return key releases (which also fire <KeyRelease>) don't rebuild and reset
# the selection while the user is navigating.
proc palette_refilter {} {
  global action_table palette_rows palette_query palette_last_query
  set w .cmd_palette
  if {![winfo exists $w]} return
  if {[info exists palette_last_query] && $palette_last_query eq $palette_query} return
  set palette_last_query $palette_query
  set q $palette_query
  set scored {}
  foreach row $action_table {
    if {[dict get $row type] ne {command}} continue
    if {$q eq {}} {
      lappend scored [list 0 $row]
      continue
    }
    set sc [fuzzy_subseq_score $q [dict get $row label]]
    foreach field {help id} {
      set s [fuzzy_subseq_score $q [dict get $row $field]]
      if {$s > $sc} { set sc $s }
    }
    if {$sc >= 0} { lappend scored [list $sc $row] }
  }
  if {$q ne {}} { set scored [lsort -decreasing -integer -index 0 $scored] }
  set palette_rows {}
  $w.l delete 0 end
  set n 0
  foreach pair $scored {
    if {$n >= 200} break
    set row [lindex $pair 1]
    lappend palette_rows $row
    set label [dict get $row label]
    set accel [dict get $row accel]
    if {$accel ne {}} {
      $w.l insert end [format "%-46s %s" $label "\[$accel\]"]
    } else {
      $w.l insert end $label
    }
    incr n
  }
  if {[llength $palette_rows] > 0} {
    $w.l selection clear 0 end
    $w.l selection set 0
    $w.l activate 0
  }
}

# Move the listbox selection by $dir (+1/-1), clamped.
proc palette_move {dir} {
  set w .cmd_palette
  if {![winfo exists $w]} return
  set last [expr {[$w.l index end] - 1}]
  if {$last < 0} return
  set cur [$w.l index active]
  if {$cur eq {}} { set cur 0 }
  set new [expr {$cur + $dir}]
  if {$new < 0} { set new 0 }
  if {$new > $last} { set new $last }
  $w.l selection clear 0 end
  $w.l selection set $new
  $w.l activate $new
  $w.l see $new
}

# Run the highlighted action and close the palette.
proc palette_run {} {
  global palette_rows
  set w .cmd_palette
  if {![winfo exists $w]} return
  set sel [$w.l curselection]
  if {[llength $sel]} {
    set idx [lindex $sel 0]
  } else {
    set idx [$w.l index active]
  }
  if {$idx eq {} || $idx < 0 || $idx >= [llength $palette_rows]} return
  set cmd [dict get [lindex $palette_rows $idx] command]
  destroy $w
  if {$cmd ne {}} {
    if {[catch {uplevel #0 $cmd} err]} { puts stderr "command palette: $err" }
  }
}

# Open (or re-open) the command palette as a small dialog near the top of the
# parent toplevel.
proc command_palette { {parent {}} } {
  global palette_query palette_last_query
  if {$parent eq {} || ![winfo exists $parent]} { set parent . }
  set parent [winfo toplevel $parent]
  set w .cmd_palette
  if {[winfo exists $w]} { destroy $w }
  toplevel $w
  wm title $w {Command palette}
  catch {wm transient $w $parent}
  set palette_query {}
  catch {unset palette_last_query}
  entry $w.q -textvariable palette_query
  listbox $w.l -height 14 -width 72 -activestyle dotbox -exportselection 0
  pack $w.q -side top -fill x -padx 2 -pady 2
  pack $w.l -side top -fill both -expand 1 -padx 2 -pady 2
  bind $w.q <KeyRelease> palette_refilter
  bind $w.q <Down>   {palette_move 1 ; break}
  bind $w.q <Up>     {palette_move -1 ; break}
  bind $w.q <Next>   {palette_move 10 ; break}
  bind $w.q <Prior>  {palette_move -10 ; break}
  bind $w.q <Return> {palette_run ; break}
  bind $w.q <Escape> {destroy .cmd_palette ; break}
  bind $w.l <Double-Button-1> palette_run
  bind $w.l <Return> palette_run
  bind $w <Escape> {destroy .cmd_palette}
  palette_refilter
  # center horizontally near the top of the parent window
  catch {
    update idletasks
    set x [expr {[winfo rootx $parent] + ([winfo width $parent] - [winfo reqwidth $w]) / 2}]
    set y [expr {[winfo rooty $parent] + 80}]
    if {$x < 0} { set x 0 }
    wm geometry $w +$x+$y
  }
  focus $w.q
}
