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
#  This file owns the actions.csv table (menus, command palette, cheat-sheet
#  labels) and the keybindings.csv/mousebindings.csv loader. Input DISPATCH lives
#  in the C input-binding table (callback.c action_registry/input_bindings,
#  remappable via `xschem bind`); the 'accel' column here is a display string only.
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
    # Unterminated quoted field: the closing '"' is missing, so every remaining
    # character (including commas that should have been delimiters) was swallowed
    # into this one field. Warn loudly — silently returning the garbled row makes
    # the resulting wrong menu label / command impossible to trace to its source.
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
  foreach line [split $data "\n"] {
    # Tolerate Windows CRLF. The default channel translation is 'auto', which
    # already maps \r\n -> \n on read, so this is a no-op for the normal path;
    # the trimright keeps the parser correct even if the channel is ever opened
    # in a non-auto (e.g. binary) translation mode where the \r would survive.
    set line [string trimright $line "\r"]
    if {$line eq {}} continue
    if {[string index $line 0] eq "#"} continue
    set fields [action_parse_csv_line $line]
    if {$header eq {}} {
      set header $fields
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
        # action-log (file-menu plan): a menu pick whose command is replayable
        # as-is is recorded after it runs. nolog rows stay silent here: their
        # effect is logged at a resolution hook instead (dialog-resolved
        # load/saveas, the C exit hook) or has no faithful line (dialogs).
        set mcmd [dict get $row command]
        set nolog [expr {[dict exists $row nolog] && [dict get $row nolog] ne {}}]
        if {$mcmd ne {} && !$nolog} {
          set mcmd [list menu_action_logged $mcmd]
        }
        set opts [list -label $label -command $mcmd]
        if {$accel ne {}} { lappend opts -accelerator $accel }
        $m add command {*}$opts
      }
      cascade -
      dynamic {
        set sub [dict get $row submenu]
        set subw $topwin.menubar.$sub
        if {$type eq {dynamic}} {
          # Dynamic submenu: attach the populate hook to the menu widget's
          # -postcommand so it re-runs every time the user posts the submenu and
          # the list stays current. The previous build-time call populated it
          # once and never refreshed (only masked for file.open_recent because
          # add_recent_file also calls setup_recent_menu on each load).
          set hook [dict get $row hook]
          set postcmd [expr {$hook ne {} ? [list $hook $topwin] : {}}]
          if {![winfo exists $subw]} {
            menu $subw -tearoff 0 -takefocus 0 -postcommand $postcmd
          } else {
            $subw configure -postcommand $postcmd
          }
          $m add cascade -label $label -menu $subw
        } else {
          if {![winfo exists $subw]} {
            menu $subw -tearoff 0 -takefocus 0
          }
          $m add cascade -label $label -menu $subw
          build_menu_from_table $topwin $sub
        }
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
    # action-log: record the confirmed reload (the menu row is nolog so the
    # cancelled case leaves no line)
    xschem log_action {xschem reload}
  }
}

# action-log (file-menu plan): run a menu pick's command and record it,
# after evaluation -- a failed pick becomes a '#' comment so the log file
# stays source-able (same rule as CIW-typed commands and Layer A).
proc menu_action_logged {cmd} {
  # self-log-at-core dedup: reset the flag, run the pick, and record the menu
  # command only if the mutating subcommand did not already self-log it.
  xschem log_action -reset
  if {[catch {uplevel #0 $cmd} err]} {
    if {![xschem log_action -emitted]} { xschem log_action "# failed: $cmd" }
    error $err
  }
  if {![xschem log_action -emitted]} { xschem log_action $cmd }
  # D1 (issue 0070): mirror the pick's OUTPUT to the CIW pane + transcript file.
  if {$err ne {}} { ciw_echo $err result ; xschem log_action -result $err }
}

# --- (removed) Phase-2 Tcl-intercept accelerators ------------------------------
# Phase 2 generated Tk key-detail bindings from the 'accel' column
# (migrated_action_ids / bind_accelerators_from_table / remap_action_accel).
# Retired at 3d.5a and deleted at 3d.5b: a Tk key-detail binding pre-empts the
# generic <KeyPress>, shadowing the C binding table and bypassing its idle gate.
# The capability is strictly superseded: bind any chord (including to a
# Tcl-backed action id) with `xschem bind` or keybindings.csv (see below).
# The 'accel' column remains as a DISPLAY string for menus and the palette.

# --- loadable input-binding files (Phase 3d.4b) -------------------------------
# keybindings.csv / mousebindings.csv hold one chord per row,
#   device,code,mods,ctx,action,idle
# in exactly the `xschem bind` token vocabulary: device key|wheel|button; code =
# X keysym number, button number, or up|down (wheel); mods 0 or ctrl|alt|shift|
# super joined by '+'; ctx canvas|graph|global; idle 1 = skip while busy. An
# action of '-' UN-binds the chord. The rows are replayed through `xschem bind`/
# `xschem unbind` once at startup (load_input_bindings below), so editing a file
# remaps or disables any default without recompiling. The shipped files in
# XSCHEM_SHAREDIR are GENERATED from the built-in C table by
# save_input_bindings_file and load as a no-op when untouched; copies in
# USER_CONF_DIR are loaded after them and win.

# Replay one binding file. Returns the number of rows applied; a malformed row
# warns on stderr and is skipped (a typo in a user file must not break startup).
proc load_input_bindings_file {path} {
  if {![file exists $path]} { return 0 }
  set fp [open $path r]
  set data [read $fp]
  close $fp
  set n 0
  set header {}
  foreach line [split $data "\n"] {
    # Tolerate Windows CRLF: the default 'auto' channel translation already maps
    # \r\n -> \n on read, so this is a no-op for the normal path; it keeps the
    # parser correct if the channel is ever opened in a non-auto translation mode
    # where a trailing \r would otherwise corrupt the last field (e.g. 'idle\r').
    set line [string trimright $line "\r"]
    if {$line eq {}} continue
    if {[string index $line 0] eq "#"} continue
    set fields [action_parse_csv_line $line]
    if {$header eq {}} { set header $fields; continue }
    lassign $fields device code mods ctx action idle
    if {$action eq {}} {
      puts stderr "input bindings: $path: row without an action: $line"
      continue
    }
    if {$action eq "-"} {
      set cmd [list xschem unbind $device $code $mods $ctx]
    } else {
      set cmd [list xschem bind $device $code $mods $ctx $action]
      if {$idle eq "1" || $idle eq "idle"} { lappend cmd idle }
    }
    if {[catch $cmd err]} {
      puts stderr "input bindings: $path: $err ($line)"
      continue
    }
    incr n
  }
  return $n
}

# Startup entry point: share-dir defaults first, then the user's overrides.
proc load_input_bindings {} {
  global XSCHEM_SHAREDIR USER_CONF_DIR
  set n 0
  foreach dir [list $XSCHEM_SHAREDIR $USER_CONF_DIR] {
    foreach f {keybindings.csv mousebindings.csv} {
      incr n [load_input_bindings_file [file join $dir $f]]
    }
  }
  return $n
}

# Write the LIVE binding table (`xschem bindings dump`) as a loadable csv,
# keeping only the listed devices (e.g. {key} -> keybindings.csv,
# {wheel button} -> mousebindings.csv). This is the generator for the shipped
# default files: regenerate them after changing the built-in C table so the
# files never drift from the builtins (the smoke test diffs them).
proc save_input_bindings_file {path devices} {
  set fp [open $path w]
  puts $fp "# Generated from the built-in binding table by save_input_bindings_file;"
  puts $fp "# loaded at startup (after which a USER_CONF_DIR copy is loaded and wins)."
  puts $fp "# Edit a row to remap a chord; set action to '-' to un-bind it."
  puts $fp "# device key|wheel|button; code = X keysym / button number / up|down;"
  puts $fp "# mods 0 or ctrl|alt|shift|super joined by '+'; ctx canvas|graph|global;"
  puts $fp "# idle 1 = chord is skipped while the editor is busy."
  puts $fp "device,code,mods,ctx,action,idle"
  foreach row [xschem bindings dump] {
    lassign $row dev code mods ctx id idle
    if {[lsearch -exact $devices $dev] < 0} continue
    set i [expr {$idle eq "idle" ? "1" : ""}]
    puts $fp "$dev,$code,$mods,$ctx,$id,$i"
  }
  close $fp
}

# --- generated keybindings cheat-sheet ---------------------------------------
# Phase 3d.3: the cheat-sheet is now a generated *view of the live binding table*
# (`xschem bindings dump`), so it can never drift from what the C dispatch actually
# does. The decorative actions.csv `accel` column is no longer consulted; only the
# human-readable `label` is joined in (by action id). Since d4a every bound id has
# an actions.csv row; the show-the-id fallback below stays as a safety net so a
# freshly-coined C id is still visible (and flagged by the smoke test) before its
# csv row lands.

# Render one binding signature (device, keysym/code, mods) as a readable chord, e.g.
# {key 107 ctrl} -> "Ctrl+k", {wheel up 0} -> "Wheel up", {button 3 0} -> "Button 3".
proc keybinding_chord_label {dev code mods} {
  set pfx ""
  foreach {tok disp} {ctrl Ctrl+ alt Alt+ super Super+ shift Shift+} {
    if {[string match "*$tok*" $mods]} { append pfx $disp }
  }
  if {$dev eq "wheel"}  { return "${pfx}Wheel $code" }
  if {$dev eq "button"} { return "${pfx}Button $code" }
  # device == key: code is an X keysym number
  set named {65362 Up 65364 Down 65361 Left 65363 Right 65289 Tab 65293 Return \
             65307 Esc 65535 Delete 65288 BackSpace 32 Space}
  if {[dict exists $named $code]} {
    set k [dict get $named $code]
  } elseif {$code >= 33 && $code <= 126} {
    set k [format %c $code]
  } else {
    set k "key$code"
  }
  return "${pfx}$k"
}

proc generate_keybindings_text {} {
  global action_table
  # action id -> human label, from actions.csv (the single source for names)
  set label {}
  foreach row $action_table { dict set label [dict get $row id] [dict get $row label] }

  set lines {}
  lappend lines "XSCHEM KEYBOARD & MOUSE BINDINGS"
  lappend lines "Generated live from the binding table (xschem bindings dump)."
  lappend lines [string repeat - 64]
  lappend lines ""
  set groups {Keys {} Mouse {}}
  foreach row [xschem bindings dump] {
    lassign $row dev code mods ctx id idle
    # graph-routing rows are context plumbing, not user commands -> footnote, not list
    if {$id eq "graph.forward"} continue
    set chord [keybinding_chord_label $dev $code $mods]
    set desc  [expr {[dict exists $label $id] ? [dict get $label $id] : $id}]
    set ann {}
    if {$ctx eq "global"} { lappend ann "global" }
    if {$idle eq "idle"}  { lappend ann "when idle" }
    set suffix [expr {[llength $ann] ? " ([join $ann {, }])" : ""}]
    set g [expr {$dev eq "key" ? "Keys" : "Mouse"}]
    dict lappend groups $g [format "  %-16s %s%s" $chord $desc $suffix]
  }
  foreach g {Keys Mouse} {
    set rows [dict get $groups $g]
    if {![llength $rows]} continue
    lappend lines "\[$g\]"
    foreach r [lsort $rows] { lappend lines $r }
    lappend lines ""
  }
  lappend lines [string repeat - 64]
  lappend lines "  Keys/wheel also forward to a waveform graph when the pointer is over one."
  lappend lines "  Remap any row: xschem bind <device> <code> <mods> <ctx> <action> \[idle\]"
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

# Which palette result row should get the first-launch attention color, or -1 for none.
# Purpose-built for the net highlight style editor (the spec is explicit this is a one-off):
# returns its row's index in $rows while the user has not opened it yet (seen==0). Pure so it
# is unit-testable without a listbox.
proc palette_emphasis_index {rows seen} {
  if {$seen} { return -1 }
  set i 0
  foreach row $rows {
    if {[dict get $row id] eq {tools.net_hilight_style_editor}} { return $i }
    incr i
  }
  return -1
}

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
    # label-only rows (empty command) describe binding-table-backed actions; they
    # carry cheat-sheet metadata, not something the palette could run -> skip.
    if {[dict get $row command] eq {}} continue
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
  # First-launch emphasis: tint the net-highlight style editor's row until the user has opened
  # it once (net_hilight_editor_seen). A Tk listbox can't bold a single item, so use a per-item
  # -foreground (overridable via ::palette_emphasis_color).
  set seen [expr {[info exists ::net_hilight_editor_seen] ? $::net_hilight_editor_seen : 1}]
  set ei [palette_emphasis_index $palette_rows $seen]
  if {$ei >= 0} {
    set acc [expr {[info exists ::palette_emphasis_color] ? $::palette_emphasis_color : {#1a6fff}}]
    catch { $w.l itemconfigure $ei -foreground $acc }
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
