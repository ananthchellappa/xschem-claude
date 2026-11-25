#
#  File: startup_quiz_bank.tcl
#
#  This file is part of XSCHEM.
#
#  The questions of the tip-of-the-day quiz (src/startup_quiz.tcl,
#  doc/claude/specs/startup_quiz.md). Read the first time a question is needed.
#
#  ONE ENTRY:
#
#    startup_quiz::add <id> {
#      type   tf | mc              true/false, or multiple choice
#      kind   shipped              tf: a true statement about something that is there
#             upcoming             tf: a planned feature, so the answer is false
#                                  mc: "which of these is not built yet?"
#             myth                 tf: a false statement that is not a plan either
#             howto                mc: how do you do this
#      topic  {...}                shown top right; at most 6 questions per topic
#      q      {...}                the statement, or the question
#      a      {{...} {...} ...}    mc only: 3 to 5 options (shuffled on screen)
#      ok     true | false         tf: the answer
#             <index>              mc: the right option, counting from 0
#      last   <index>              mc, optional: an option that stays at the bottom
#      why    {...}                shown after the answer; teach the right way here
#      proof  {...}                see below. REQUIRED.
#      only   {...}                optional: ask this only where the expression is
#                                  true (a key of the Cadence profile, a symbol
#                                  of a PDK workarea). For the Cadence profile
#                                  test a command its rc defines, never the
#                                  cadence namespace: ASE-L creates that in any
#                                  session (utils/annot_mode.tcl)
#    }
#
#  The id may hold a-z, 0-9, '-' and '_'. It is what the "already answered" list
#  remembers, so do not reuse the id of a question that was removed. Text may be
#  wrapped over several lines; runs of white space become one blank. Plain ASCII
#  only. An entry that does not validate is left out and the suite goes red.
#
#  THE PROOF. Every entry states a fact about this program in front of a user, and
#  the program keeps changing. `proof` is an expression that is true while the
#  entry is still right, evaluated by tests/headless/test_startup_quiz.tcl (band
#  A) and by nothing else, over helpers that suite defines:
#
#    [P_proc name]                 a command or proc of that name exists
#    [P_body name text]            that proc's body holds the text
#    [P_bodyre name regexp]        ... or matches the regexp
#    [P_has file text]             the file (path from the repo root) holds the text
#    [P_hasre file regexp]         ... or matches the regexp
#    [P_order file a b]            ... holds a, and b somewhere after it
#    [P_text file]                 the file's text, for a test of your own
#    [P_file path]                 the file exists
#    [P_action id] [P_palette id]  actions.csv has the row / the palette can run it
#    [P_label id label]            the row's label is exactly that
#    [P_bind dev code mods ctx id] the live binding table has exactly that row
#    [P_sub name]                  `xschem <name>` is a subcommand
#    [P_default var value]         xschem.tcl has `set_ne <var> <value>`
#
#  plus any Tcl command that exists in a --nogui session. For a shipped feature
#  the proof says the thing is there (the proc, the menu label, the key); for an
#  upcoming one it says the thing is still absent, so the day somebody builds the
#  feature the suite reddens this question and it gets moved to `shipped`, with a
#  new explanation. Text inside a proof must have balanced braces.
#
#  WHEN YOU SHIP A FEATURE, add a question for it here. When you rename a menu
#  entry or move a key, the proof of every question that mentions it fails; fix
#  the question, not the proof.

# ---------------------------------------------------------------- Command palette
startup_quiz::add palette-open {
  type mc  kind howto  topic {Command palette}
  q   {Which chord opens the command palette, a searchable list of commands?}
  a   {{Ctrl+Shift+P} {Ctrl+P} {Ctrl+Q} {Alt+F5}}
  ok  0
  why {Ctrl+Shift+P, also Help > Command palette. Type a few letters, use the arrows,
       press Return. Ctrl+P places an input port, Ctrl+Q quits, and Alt+F5 raises the CIW.}
  proof {[P_has src/xschem.tcl {<Control-Shift-Key-P> "command_palette}] && [P_proc ::command_palette]
         && [P_bind key 65474 alt canvas tools.raise_ciw]}
}
startup_quiz::add palette-search {
  type mc  kind howto  topic {Command palette}
  q   {In the command palette, what can you type to find a command?}
  a   {{Part of its label, its one-line description or its action id}
       {Its keyboard shortcut, such as Ctrl+N}
       {Only the first letters of its menu label}
       {The name of an instance or net in the schematic}}
  ok  0
  why {The palette matches the letters you type, in order, against each command's label,
       description and id, so a word from the description works even when you have
       forgotten the menu name. The shortcut is shown, but not searched.}
  proof {[P_bodyre ::palette_refilter {foreach field \{help id\}}]}
}
startup_quiz::add palette-scope {
  type tf  kind myth  topic {Command palette}
  q   {The command palette only offers what is already on the menus.}
  ok  false
  why {It also runs commands that have no menu entry at all, such as Raise CIW window,
       Select same net (incl. label-connected) and Double snap factor.}
  proof {[P_palette tools.raise_ciw] && [P_palette select.same_net_by_label]
         && [P_palette view.snap_double] && ![P_has src/xschem.tcl {-label "Raise CIW window"}]
         && ![P_has src/xschem.tcl {-label "Double snap factor"}]}
}

# ------------------------------------------------------------------- Key bindings
startup_quiz::add keys-remap {
  type mc  kind howto  topic {Key bindings}
  q   {To change the key binding of your most-used command, you would:}
  a   {{Put the changed rows in a keybindings.csv in ~/.xschem and restart}
       {Edit the shortcut column of actions.csv}
       {Open Help > Keybindings (from table), edit the row and save}
       {Rebuild XSCHEM: key bindings are compiled in}}
  ok  0
  why {Key chords are data. The defaults ship in keybindings.csv; rows in your own copy
       under ~/.xschem are read after them and win. For a quick try, 'xschem bind' does
       the same in a running session. The shortcut text in actions.csv and beside the
       menu entries is display only.}
  proof {[P_bodyre ::load_input_bindings {XSCHEM_SHAREDIR \$USER_CONF_DIR}]
         && [P_file src/keybindings.csv] && [P_sub bind] && [P_sub unbind]}
}
startup_quiz::add keys-unbind {
  type mc  kind howto  topic {Key bindings}
  q   {In your own ~/.xschem/keybindings.csv, how do you switch a default chord off?}
  a   {{Set that row's action to -}
       {Leave that row's action empty}
       {Set that row's action to none}
       {Leave the row out of your file}}
  ok  0
  why {An action of - un-binds the chord. An empty or unknown action is only warned
       about and skipped, and leaving the row out changes nothing, because the shipped
       default still applies.}
  proof {[P_body ::load_input_bindings_file {if {$action eq "-"}}]
         && [P_body ::load_input_bindings_file {row without an action}]}
}
startup_quiz::add keys-live {
  type mc  kind howto  topic {Key bindings}
  q   {You remapped some chords. Where do you see what is really bound now?}
  a   {{Help > Keybindings (from table)}
       {The shortcut text beside each menu entry}
       {Help > Keys}
       {Help > Show Keybindings}}
  ok  0
  why {Keybindings (from table) is generated from the live binding table each time you
       open it. The shortcut text in the menus and the two older Help entries are fixed
       text and do not follow a remap.}
  proof {[P_has src/xschem.tcl {-label "Keybindings (from table)" -command "show_keybindings_help"}]
         && [P_body ::generate_keybindings_text {xschem bindings dump}]}
}
startup_quiz::add keys-ownproc {
  type mc  kind howto  topic {Key bindings}
  q   {To make F9 run a Tcl proc of your own, which line goes in a file you pass with --script?}
  a   {{bind .drw <Key-F9> {my_proc; break}}
       {xschem bind key F9 0 canvas my_proc}
       {set replace_key(F9) my_proc}
       {set accel(my_proc) F9}}
  ok  0
  why {'xschem bind' and keybindings.csv attach only the built-in action ids. For your own
       Tcl, bind the key on the canvas (.drw) yourself, as the Cadence profile does for its
       extra keys.}
  proof {[P_has src/cadence_style_rc {bind .drw <Key-i> {xschem create_instance; break}}]
         && [P_has src/callback.c {bind: unknown action}]}
}

startup_quiz::add keys-menu-text {
  type tf  kind myth  topic {Key bindings}
  q   {When you remap a key, the shortcut shown beside the menu entry changes with it.}
  ok  false
  why {The text beside a menu entry is fixed. Help > Keybindings (from table) is the list
       that follows what is really bound.}
  proof {[P_body ::generate_keybindings_text {xschem bindings dump}]
         && [P_has src/actions.csv {The 'accel'}] && [P_has src/actions.csv {DISPLAY string only and binds nothing}]}
}

# -------------------------------------------------------------------- Starting up
startup_quiz::add rc-script {
  type mc  kind howto  topic {Starting up}
  q   {Which launch option runs a Tcl file after the window is up and the schematic is loaded?}
  a   {{--script <file>} {--rcfile <file>} {--preinit <file>} {--tcl <file>}}
  ok  0
  why {--script runs last of the startup files, so it can use every xschem command and
       every window. --rcfile is read before the xschem command exists, and --preinit
       and --tcl take Tcl text, not a file.}
  proof {[P_order src/xinit.c {Tcl_CreateCommand(interp, "xschem"} {source_tcl_file(cli_opt_tcl_script)}]
         && [P_order src/xinit.c {load_schematic(1, fname} {source_tcl_file(cli_opt_tcl_script)}]}
}
startup_quiz::add rc-norecent {
  type mc  kind howto  topic {Starting up}
  q   {You want to open a few files without them showing up under File > Open recent.
       You start XSCHEM with:}
  a   {{--norecent} {--nolog} {-q} {-i}}
  ok  0
  why {--norecent leaves the recent-files list alone for the whole session. --nolog
       switches off the action log and the CIW, -q quits when the command line is done,
       and -i skips the rc files.}
  proof {[P_has src/options.c {!strcmp("norecent", opt)}] && [P_has src/options.c {!strcmp("nolog", opt)}]}
}
startup_quiz::add rc-local {
  type mc  kind howto  topic {Starting up}
  q   {With an installed XSCHEM, how do you give one project its own settings?}
  a   {{Put a file named xschemrc in the directory you start from}
       {Put a file named .xschemrc in the directory you start from}
       {Put a file named xschemrc next to the schematic}
       {Name the project in the XSCHEM_PROJECT environment variable}}
  ok  0
  why {A file named xschemrc (no dot) in the start directory is read instead of
       ~/.xschem/xschemrc, not after it, so copy over anything you still need from your
       personal one.}
  proof {[P_has src/xinit.c {"%s/xschemrc",pwd_dir}] && ![P_has src/xinit.c {.xschemrc}]
         && ![P_has src/xinit.c XSCHEM_PROJECT] && ![P_has src/xschem.tcl XSCHEM_PROJECT]}
}
startup_quiz::add rc-intree {
  type tf  kind shipped  topic {Starting up}
  q   {Run straight from the source tree, XSCHEM does not read ~/.xschem/xschemrc.}
  ok  true
  why {True, and deliberate: an in-tree run reads only the xschemrc beside the program.
       Name your own with --rcfile, or put your settings in a file passed with --script.}
  proof {[P_order src/xinit.c {if(!running_in_src_dir)} {"%s/xschemrc", user_conf_dir}]}
}
startup_quiz::add rc-xschem-cmd {
  type tf  kind myth  topic {Starting up}
  q   {You can put xschem commands, such as 'xschem bind ...', straight into xschemrc.}
  ok  false
  why {xschemrc is read before the xschem command exists, so such a line fails. Put it in
       a file passed with --script, or in the postinit_commands variable, which is run
       once startup is done.}
  proof {[P_order src/xinit.c {END SOURCING xschemrc} {Tcl_CreateCommand(interp, "xschem"}]
         && [P_has src/xschem.tcl postinit_commands]}
}

# ------------------------------------------------------------- CIW and action log
startup_quiz::add ciw-raise {
  type mc  kind howto  topic {CIW and action log}
  q   {You closed the CIW, the log and command window. How do you get it back?}
  a   {{Press Alt+F5 on the schematic}
       {View > Show / Hide > CIW}
       {Press F5 on the schematic}
       {Restart XSCHEM: a closed CIW is gone}}
  ok  0
  why {Closing the CIW only hides it, and it keeps its text. Alt+F5 brings it back, and so
       does Raise CIW window in the command palette.}
  proof {[P_bind key 65474 alt canvas tools.raise_ciw] && [P_palette tools.raise_ciw]
         && [P_has src/ciw.tcl {wm protocol .ciw WM_DELETE_WINDOW {wm withdraw .ciw}}]
         && [llength [lsearch -all -glob [xschem bindings dump] {key 65474 *}]] == 1}
}
startup_quiz::add log-what {
  type tf  kind shipped  topic {CIW and action log}
  q   {XSCHEM writes what you do to a log as Tcl commands, which can be replayed like a macro.}
  ok  true
  why {Each session keeps an action log of replayable commands, mirrored live in the CIW.
       Tools > Replay action log... runs one back into the session.}
  proof {[P_sub log_action] && [P_proc ::replay_action_log] && [P_palette tools.replay_action_log]
         && [P_has src/xschem.tcl {menubar.tools add command -label "Replay action log..."}]}
}
startup_quiz::add log-where {
  type mc  kind howto  topic {CIW and action log}
  q   {With no --logdir option, where is a session's action log written?}
  a   {{In $TMPDIR, or /tmp: Xschem.log, Xschem.log.1, ...}
       {In the directory XSCHEM was started from}
       {In ~/.xschem, as Xschem.log}
       {Next to the schematic, as <cell>.log}}
  ok  0
  why {The log is a throw-away file, so it goes to the temp directory; --logdir puts it
       somewhere lasting. The CIW's title bar shows the exact file of this session.}
  proof {[P_has src/util.c {getenv("TMPDIR")}] && [P_has src/util.c {"%s/Xschem.log"}]
         && [P_has src/ciw.tcl {wm title .ciw "xschem CIW - }]}
}
startup_quiz::add log-undo {
  type tf  kind upcoming  topic {CIW and action log}
  q   {After you replay an action log, a single Undo takes back the whole replay.}
  ok  false
  why {Today each replayed command is its own undo step, so a 50-line log takes 50 undos.
       Making a replay one step is planned.}
  proof {[P_proc ::replay_action_log] && ![P_bodyre ::replay_action_log {(?i)undo}]
         && ![regexp {undo_barrier|undo_group|undo_transaction} [P_text src/actions.c][P_text src/scheduler.c]]}
}
startup_quiz::add ciw-tab {
  type tf  kind shipped  topic {CIW and action log}
  q   {In the CIW's command line, Tab completes commands, xschem subcommands, variables
       and file names.}
  ok  true
  why {Up and Down walk through the commands you typed before, and Ctrl+BackSpace deletes
       a word.}
  proof {[P_has src/ciw.tcl {bind .ciw.c.e <Tab> {ciw_complete; break}}] && [P_proc ::ciw_complete]
         && [P_proc ::ciw_hist_move] && [P_proc ::ciw_delete_word]}
}

startup_quiz::add ciw-close-log {
  type tf  kind myth  topic {CIW and action log}
  q   {Closing the CIW window stops the action log.}
  ok  false
  why {Closing only hides the window. The log file keeps being written, and Alt+F5 shows
       the window again.}
  proof {[P_has src/ciw.tcl {wm protocol .ciw WM_DELETE_WINDOW {wm withdraw .ciw}}]
         && ![P_hasre src/ciw.tcl {\.ciw WM_DELETE_WINDOW[^\n]*(nolog|log_action|destroy)}]}
}

# ---------------------------------------------------------------------- Selection
startup_quiz::add sel-look {
  type mc  kind howto  topic {Selection}
  q   {How do you change the way selected objects are drawn, for instance to a halo?}
  a   {{View > Selection look}
       {Options > Selection look}
       {Add sel_style=halo to the object's attributes}
       {Properties > Selection colour}}
  ok  0
  why {View > Selection look offers Classic, Bright, Bright with box (the default) and
       Halo. In an rc file: set selection_style halo.}
  proof {[P_has src/xschem.tcl {menubar.view add cascade -label "Selection look"}]
         && [P_has src/xschem.tcl {{Classic classic Bright bright {Bright with box} brightbox Halo halo}}]
         && [P_default selection_style brightbox] && ![P_has src/xschem.tcl {Selection colour}]}
}
startup_quiz::add sel-deselect-one {
  type mc  kind howto  topic {Selection}
  q   {On the schematic, away from any graph, what does pressing d do?}
  a   {{Starts a mode where clicking a selected object deselects just that one}
       {Deletes the selection}
       {Duplicates the selection}
       {Descends into the selected instance}}
  ok  0
  why {d starts 'deselect one object at a time': click what you want out of the selection,
       Esc to finish. Over a waveform graph the same key drops a delta marker instead.}
  proof {[P_bind key 100 0 canvas edit.deselect_mode] && [P_sub deselect_mode]
         && [P_bind key 100 0 graph graph.forward]}
}
startup_quiz::add sel-same-net {
  type tf  kind shipped  topic {Selection}
  q   {One command selects a whole net, including the pieces that are joined to it only by
       sharing a label.}
  ok  true
  why {Command palette: Select same net (incl. label-connected). Its sibling, Add same net
       to selection, adds the net to what is already selected.}
  proof {[P_palette select.same_net_by_label] && [P_palette select.same_net_by_label_add]
         && [P_sub select_same_net]}
}

# ---------------------------------------------------------------------- Highlight
startup_quiz::add nh-save {
  type mc  kind howto  topic {Net highlight}
  q   {You tuned colours and patterns in Tools > Net highlight styles... How do you keep
       them for the next session?}
  a   {{Press Save... and keep the offered file in ~/.xschem}
       {Press OK}
       {Press Apply}
       {Nothing to do: every change is saved as you make it}}
  ok  0
  why {Only Save... writes the styles to disk, and only the offered location,
       ~/.xschem/net_hilight_style, is loaded by itself at the next start. OK and Apply
       change the running session only.}
  proof {[P_body ::nhse_save {-initialfile net_hilight_style}]
         && [P_body ::load_net_hilight_conf {net_hilight_style}]}
}
startup_quiz::add nh-ants {
  type tf  kind shipped  topic {Net highlight}
  q   {A highlighted net can blink or show marching ants, and each highlight style has its
       own colour, width and dash pattern.}
  ok  true
  why {Tools > Net highlight styles... edits all of that with a live preview, with no rc
       file to write by hand.}
  proof {[P_proc ::net_hilight_style_editor] && [P_palette tools.net_hilight_style_editor]
         && [P_has src/xschem.tcl march_fwd]}
}
startup_quiz::add flylines {
  type tf  kind shipped  topic {Net highlight}
  q   {XSCHEM can draw dashed fly-lines from the net under the pointer to the places it is
       connected to by name only, with no wire between them.}
  ok  true
  why {Options > Show hover fly-lines (implicit connectivity). It is off by default.}
  proof {[P_has src/xschem.tcl {-label "Show hover fly-lines (implicit connectivity)"}]
         && [P_default flylines 0] && [P_file src/flyline.c]}
}

startup_quiz::add fly-freeze {
  type tf  kind upcoming  topic {Net highlight}
  q   {While hover fly-lines are showing, a key freezes them so that they stay on screen
       when the pointer moves away.}
  ok  false
  why {Fly-lines follow the pointer for now and go when it leaves the net. A key to pin
       them is planned.}
  proof {![info exists ::flylines_freeze] && ![info exists ::flylines_frozen]
         && ![regexp -nocase {fly} [P_text src/keybindings.csv][P_text src/actions.csv]]
         && ![P_has src/flyline.c fly_frozen]}
}

# ------------------------------------------------------------------------ Editing
startup_quiz::add fluid-grab {
  type tf  kind myth  topic {Editing}
  q   {You have to select a wire before you can drag its end.}
  ok  false
  why {With fluid editing, on by default, the first click on the end of a wire, or on a
       corner or edge of a rectangle, grabs it and you drag straight away. The switch is
       Options > Fluid editing (first-click tip/edge grab).}
  proof {[P_default fluid_editing 1]
         && [P_has src/xschem.tcl {-label "Fluid editing (first-click tip/edge grab)"}]}
}
startup_quiz::add fluid-refuse {
  type tf  kind shipped  topic {Editing}
  q   {If dragging connected objects would short two nets together or break a connection,
       XSCHEM refuses the move and leaves the schematic as it was.}
  ok  true
  why {On by default, with a line in the CIW saying why the move was refused. The escape
       hatch, should you ever need it, is the fluid_enforce_invariants variable.}
  proof {[P_default fluid_enforce_invariants 1] && [P_has src/move.c fluid_enforce_invariants]}
}
startup_quiz::add rotate-in-place {
  type tf  kind shipped  topic {Editing}
  q   {Alt+R rotates the selection where it stands, and it also turns objects that are in
       the middle of being dragged.}
  ok  true
  why {Alt+F and Alt+V flip the same way, horizontally and vertically.}
  proof {[P_bind key 114 alt canvas edit.rotate_in_place] && [P_bind key 102 alt canvas edit.flip_in_place]
         && [P_bind key 118 alt canvas edit.flipv_in_place]}
}
startup_quiz::add pin-stubs {
  type mc  kind howto  topic {Editing}
  q   {You select an instance and press Space. What happens?}
  a   {{Each unconnected pin gets a short wire stub with a net label}
       {The instance is rotated by 90 degrees}
       {The view is centred on the instance}
       {The instance's properties open}}
  ok  0
  why {Space adds a stub and an outward net label to every unconnected pin of the selected
       instance, or to just the pins you selected. It is also Symbol > Add pin stubs + labels.}
  proof {[P_bind key 32 0 canvas edit.add_pin_stubs] && [P_label edit.add_pin_stubs {Add pin stubs + labels}]
         && [P_sub add_pin_stubs]}
}
startup_quiz::add hover-outline {
  type tf  kind shipped  topic {Editing}
  q   {Before you click, the object under the pointer gets a dashed outline, so you can see
       what the click would pick.}
  ok  true
  why {On by default. The variables hover_highlight and hover_highlight_color (yellow) in
       an rc file switch it off or recolour it.}
  proof {[P_default hover_highlight 1] && [P_default hover_highlight_color yellow]
         && [P_has src/callback.c {tclgetboolvar("hover_highlight")}]}
}

# Issue 1740. Asked where the connected drag is what a plain drag does (the Cadence
# profile) and fluid editing is on, which is where the answer holds.
startup_quiz::add wire-drag-junction {
  type tf  kind myth  topic {Wires}
  q   {A wire ends on the middle of another wire, with a solder dot where they meet. If you
       drag the first wire far enough to one side, the wire it ends on is pulled along.}
  ok  false
  why {The wire it ends on stays where it is, however far you drag: the dot slides along it
       and the dragged wire stretches or shrinks. A corner at the dragged wire's other end
       follows it. Options > Fluid editing switches this on; the Cadence profile has it on.}
  only  {[llength [info commands ::cadence::q_key]] > 0
         && [info exists ::fluid_editing] && $::fluid_editing}
  proof {[P_has src/move.c {static int fluid_place_wire_junctions(void)}]
         && [P_hasre src/move.c {tclgetboolvar\("fluid_editing"\)\) \{\n\s+fluid_place_wire_junctions\(\);}]
         && [P_has src/move.c {if(k == 0 && fluid_junction_placed(n)) break;}]
         && [P_has src/cadence_style_rc {set fluid_editing 1}]
         && [P_has tests/headless/test_wire_drag_junction_1740.tcl {B1 the bare T in four orientations}]}
}
# Issue 1741. Same gate as the question above.
startup_quiz::add wire-drag-escape {
  type tf  kind shipped  topic {Wires}
  q   {You start dragging a wire and press Escape before letting go. Afterwards only the wire
       you dragged is selected, not the wires that were attached to its ends.}
  ok  true
  why {The attached wires follow the drag but are not yours: Escape puts every wire back and
       leaves selected only what you had picked. The same holds after a finished drag.}
  only  {[llength [info commands ::cadence::q_key]] > 0
         && [info exists ::fluid_editing] && $::fluid_editing}
  proof {[P_order src/move.c {issue 1741: an aborted connected drag leaves only} {my_free(_ALLOC_ID_, &xctx->fluid_startsel_id);}]
         && [P_has src/move.c {if(fluid_was_dirty || abort_sel_changed) draw();}]
         && [P_has tests/headless/test_wire_drag_junction_1740.tcl {G7 click the bar's upper half, drag it, press Escape}]}
}

# ---------------------------------------------------------------- Labels and pins
startup_quiz::add wire-label {
  type mc  kind howto  topic {Labels and pins}
  q   {Which key opens the Add Wire Label form, where each click then drops the next label
       on a wire or a pin?}
  a   {{l} {w} {t} {p}}
  ok  0
  why {l opens Add Wire Label, also on the Symbol menu: type one or more names and click
       where each should go. w draws a wire, t places text and p places a symbol pin.}
  proof {[P_bind key 108 0 canvas edit.add_wire_label] && [P_bind key 112 0 canvas sym.place_symbol_pin]
         && [P_has src/xschem.tcl {-label "Insert wire" -command "xschem wire" -accelerator W}]
         && [P_has src/xschem.tcl {-label "Insert text" -command "xschem place_text" -accelerator T}]}
}
startup_quiz::add pin-rename {
  type tf  kind myth  topic {Labels and pins}
  q   {When you rename a schematic pin, the net labels that carried the old name keep it.}
  ok  false
  why {The labels in that schematic are renamed along with the pin. On by default; the
       switch is Symbol > Renaming a pin renames its net labels.}
  proof {[P_default pin_rename_propagate 1]
         && [P_has src/xschem.tcl {-label "Renaming a pin renames its net labels"}]}
}

# ---------------------------------------------------------------------- Hierarchy
startup_quiz::add view-toggle {
  type mc  kind howto  topic {Hierarchy}
  q   {Which chord switches between a cell's schematic and its symbol?}
  a   {{Alt+2} {Alt+S} {Ctrl+Tab} {Shift+E}}
  ok  0
  why {Alt+2 opens the other view of the current cell; the command palette has it as Toggle
       schematic/symbol view.}
  proof {[P_bind key 50 alt canvas view.toggle_view_type] && [P_palette view.toggle_view_type]
         && [llength [lsearch -all -glob [xschem bindings dump] {* view.toggle_view_type*}]] == 1}
}
startup_quiz::add descend-dialog {
  type tf  kind shipped  topic {Hierarchy}
  q   {When you press e on an instance, you can choose which view to open, read only or
       editable, and whether it opens here, in a new window or in a new tab.}
  ok  true
  why {The Descend dialog asks all three. Edit > Push schematic opens the same dialog.}
  proof {[P_proc ::hi_descend] && [P_has src/xschem.tcl {if {![info exists hi_descend_key]} { set hi_descend_key e }}]
         && [P_has src/xschem.tcl {-text "Read only" -variable ::hi_descend_dlg_mode}]
         && [P_has src/xschem.tcl {$w.dest.tab -text "New tab"}]
         && [P_has src/xschem.tcl {$w.dest.win -text "New window"}]}
}
startup_quiz::add make-editable {
  type mc  kind howto  topic {Hierarchy}
  q   {A schematic opened read only. How do you start editing it?}
  a   {{Edit > Make Editable}
       {File > Unlock}
       {Options > Read only}
       {Press Ctrl+E}}
  ok  0
  why {Edit > Make Editable switches the window to editing; the same entry reads Make Read
       Only while the window is editable. Ctrl+E goes back up one level of the hierarchy.}
  proof {[P_has src/xschem.tcl {"Make Editable" : "Make Read Only"}] && [P_proc ::toggle_readonly]
         && ![P_has src/xschem.tcl {-label "Unlock"}] && ![P_has src/xschem.tcl {-label "Read only"}]
         && [P_has src/actions.csv {edit.pop,command,edit,Pop,Ctrl+E,xschem go_back}]}
}

# --------------------------------------------------------------- Windows and tabs
startup_quiz::add tab-detach {
  type tf  kind shipped  topic {Windows and tabs}
  q   {A schematic tab can be pulled out into a window of its own.}
  ok  true
  why {Right-click the tab and choose Detach to window. The first, main schematic stays
       where it is.}
  proof {[P_has src/xschem.tcl {-text {Detach to window}}] && [P_has src/xinit.c detach_tab]}
}
startup_quiz::add tabs-off {
  type mc  kind howto  topic {Windows and tabs}
  q   {You would rather have every schematic in a window of its own than in a tab. You:}
  a   {{Untick View > Tabbed interface}
       {Untick Options > Tabbed interface}
       {Start XSCHEM with --no_tabs}
       {Set open_in_new_window to 1 in your rc file}}
  ok  0
  why {View > Tabbed interface, or 'set tabbed_interface 0' in an rc file. Change it while
       only one schematic is open. open_in_new_window only stops File > Open from replacing
       what you have; with tabs on, the new one is still a tab.}
  proof {[P_has src/xschem.tcl {menubar.view add checkbutton -label "Tabbed interface" -variable tabbed_interface}]
         && [P_default tabbed_interface 1] && ![P_has src/options.c no_tabs]
         && [P_default open_in_new_window 0]}
}

# -------------------------------------------------------------------------- Files
startup_quiz::add autosave {
  type tf  kind myth  topic {Files}
  q   {If a session ends without saving, the edits made since the last save are gone.}
  ok  false
  why {Each edit is written to a backup beside the cell, and the next time you open the
       cell XSCHEM asks 'Recover unsaved changes?' when a newer backup is there. On by
       default (autosave_backup).}
  proof {[P_default autosave_backup 1] && [P_proc ::xschem_recover_backup]
         && [P_has src/xschem.tcl {-title {Recover unsaved changes?}}] && [P_sub backup]}
}
startup_quiz::add check-and-save {
  type tf  kind shipped  topic {Files}
  q   {File > Check and Save checks the sheet against its symbol and its connectivity,
       saves it, and lists what it found as lines you can click to jump there.}
  ok  true
  why {Esc closes the report. On a read-only view nothing is saved.}
  proof {[P_palette file.check_and_save] && [P_proc ::check_and_save]
         && [P_has src/xschem.tcl {chksave::show}]}
}

# ---------------------------------------------------------------------- Libraries
startup_quiz::add lib-copy-bench {
  type mc  kind howto  topic {Library Manager}
  q   {You copied the cell my_buf3 as fast_buf3. To get a bench fast_buf3_tb that tests the
       new cell, saved simulation states included, you would:}
  a   {{Right-click my_buf3_tb > Copy, tick Copy Hierarchical, name the my_buf3 row fast_buf3}
       {Copy the my_buf3_tb folder in a file manager: the instance is re-pointed on first open}
       {Right-click my_buf3_tb > Rename and type fast_buf3_tb}
       {Copy my_buf3_tb with "Update instance references" set to None}}
  ok  0
  why {The Copy form lists the cells a bench uses. A row named after a cell that is already
       there reads Use existing: nothing is copied over it and the copied bench instantiates
       it. Name the bench fast_buf3_tb first and the form proposes fast_buf3 by itself. The
       copy's saved states simulate the copy.}
  proof {[P_proc ::copyform::execute] && [P_body ::copyform::row_action {return use}]
         && [P_body ::copyform::action_label {Use existing}]
         && [P_has src/copy_form.tcl {-text "Copy Hierarchical"}]
         && [P_body ::libmgr::do_copy_plan {copyform::execute}]}
}
startup_quiz::add lib-copy-state {
  type tf  kind myth  topic {Library Manager}
  q   {A test bench copied in the Library Manager keeps saved simulation states that still
       run the original bench.}
  ok  false
  why {The states of a copy are re-pointed: their design becomes the copy, an include file
       kept inside the cell is read from the copy, and saved plots follow the copy's own
       results. The status bar says how many states were re-pointed, the CIW lists them.}
  proof {[P_body ::copyform::retarget_state {design is now}]
         && [P_body ::libmgr::do_copy_cell {copyform::execute}]
         && [P_body ::copyform::execute {copyform::retarget_state}]}
}
startup_quiz::add lib-autostart {
  type mc  kind howto  topic {Library Manager}
  q   {To have the Library Manager open at every start, your xschemrc would contain:}
  a   {{set launch_library_manager 1}
       {xschem library_manager}
       {set new_file_browser 1}
       {set library_manager_autostart yes}}
  ok  0
  why {launch_library_manager is looked at once the window is up. A bare 'xschem
       library_manager' fails in xschemrc, which is read before the xschem command
       exists; in a --script file it works. By hand: Tools > Library Manager.}
  proof {[P_has src/xinit.c {tclgetboolvar("launch_library_manager")}] && [P_default launch_library_manager 0]
         && ![P_has src/xschem.tcl library_manager_autostart]
         && [P_order src/xinit.c {END SOURCING xschemrc} {Tcl_CreateCommand(interp, "xschem"}]}
}
startup_quiz::add lib-git {
  type tf  kind shipped  topic {Library Manager}
  q   {The Library Manager can keep cells under git revision control: right-click a cell
       to check it out, check it in or cancel the checkout.}
  ok  true
  why {Tools > Library Manager; the entries are on the right-click menus of the Cell and
       View columns.}
  proof {[P_has src/library_manager.tcl {-label "Check out"}]
         && [P_has src/library_manager.tcl {-label "Cancel checkout"}]
         && [P_proc ::libmgr::ctx_checkout_cell] && [P_file src/library_git.tcl]}
}
# Issue 1738. The key is the Cadence profile's, so it is asked there.
startup_quiz::add libmgr-raise-key {
  type mc  kind howto  topic {Library Manager}
  q   {The Library Manager is hidden behind other windows, and the schematic in front of
       you is a new, untitled one. Which key brings the Library Manager to the front?}
  a   {{Ctrl-Alt-S}
       {Ctrl-Alt-N}
       {Ctrl-Alt-H}
       {None: Ctrl-Alt-S needs a schematic that is in a library}}
  ok  0  last 3
  why {Ctrl-Alt-S shows the cell you are viewing, or the selected instance's cell, in the
       Library Manager. When there is nothing to show, as on an untitled schematic, it
       still raises the Library Manager and gives it the keyboard, and the CIW says why no
       cell was located. Ctrl-Alt-N places the cell selected in the Library Manager, and
       Ctrl-Alt-H selects every instance of it in the schematic.}
  only  {[llength [info commands ::cadence::q_key]] > 0}
  proof {[P_hasre src/cadence_style_rc {bind \.drw <Control-Alt-Key-s>\s+.locate_selected_in_libmgr;}]
         && [P_hasre src/cadence_style_rc {bind \.drw <Control-Alt-Key-n>\s+.place_libmgr_selection;}]
         && [P_hasre src/cadence_style_rc {bind \.drw <Control-Alt-Key-h>\s+.select_same_cell;}]
         && [P_order utils/lib_mgr_helpers.tcl {set tag result} {Library Manager raised, nothing located}]
         && [P_hasre utils/lib_mgr_helpers.tcl {\n\s+xschem library_manager\n\s+ciw_echo}]}
}

# -------------------------------------------------------------------------- ASE-L
# ase-open's proof also holds its two menu wrong options to the source: no File
# row of src/actions.csv (build_menu_from_table builds that menu from it) names
# ASE-L as a word in its label or ase::launch in its command, and no Simulation
# entry of src/xschem.tcl names ASE-L as a word, annot_lbl_launch_ase or
# ase::launch, read with continued lines joined. Case is ignored in both.
# test_startup_quiz rows A23 to A28.
startup_quiz::add ase-open {
  type mc  kind howto  topic {ASE-L}
  q   {How do you open ASE-L, the simulation environment, for the schematic in front of you?}
  a   {{Tools > Launch ASE-L}
       {Simulation > Launch ASE-L}
       {File > New ASE-L session}
       {Click Simulate on the menu bar}}
  ok  0
  why {Tools > Launch ASE-L opens a session for the current schematic, or raises the one
       already open for it. The Simulate button is the older, one-shot simulate.}
  proof {[P_has src/xschem.tcl {menubar.tools add command -label [annot_lbl_launch_ase] -command "ase::launch_for_current"}]
         && [annot_lbl_launch_ase] eq {Launch ASE-L} && ![P_has src/xschem.tcl {New ASE-L session}]
         && ![regexp -nocase -line {^[^,]*,[^,]*,file(\.[^,]*)?,("[^"]*|[^,"]*)\mASE-L\M} [P_text src/actions.csv]]
         && ![regexp -nocase -line {^[^,]*,[^,]*,file(\.[^,]*)?,("[^"]*"|[^,"]*),("[^"]*"|[^,"]*),("[^"]*|[^,"]*)\mase::launch} [P_text src/actions.csv]]
         && ![regexp -nocase {menubar\.simulation add[^\n]*(\mASE-L\M|annot_lbl_launch_ase|ase::launch)} [regsub -all {\\\n\s*} [P_text src/xschem.tcl] { }]]}
}
startup_quiz::add ase-xyce {
  type tf  kind upcoming  topic {ASE-L}
  q   {ASE-L can run a simulation with Xyce as well as with ngspice.}
  ok  false
  why {ASE-L drives ngspice only for now, though it is built so that other simulators can
       be added. The older Simulation menu can already use Xyce.}
  proof {[P_proc ::ase::backend_names] && [ase::backend_names] eq {ngspice}}
}
startup_quiz::add ase-state {
  type tf  kind shipped  topic {ASE-L}
  q   {An ASE-L setup can be saved as a view of the cell, next to its schematic and symbol,
       and loaded again later.}
  ok  true
  why {In ASE-L: Session > Save State and Session > Load State. The saved state also shows
       up in the Library Manager as a view of the cell.}
  proof {[P_has src/ase_window.tcl {mb.session add command -label {Save State}}]
         && [P_has src/ase_window.tcl {mb.session add command -label {Load State}}]}
}
startup_quiz::add ase-tilde {
  type mc  kind howto  topic {ASE-L}
  q   {In ASE-L, what does Ctrl-clicking the ~ button do?}
  a   {{Updates the output values without plotting}
       {Plots the outputs into a new window}
       {Runs the simulation again}
       {Clears the Outputs list}}
  ok  0
  why {A plain click on ~ plots the outputs and updates their values; with Ctrl it only
       updates the values.}
  proof {[P_proc ::ase::ui::lbl_plot_outputs]
         && [ase::ui::lbl_plot_outputs] eq {Plot outputs and update values (Ctrl-click: values only)}
         && [P_has src/ase_window.tcl {bind $top.strip.plot <Control-Button-1>}]}
}
startup_quiz::add ase-results {
  type tf  kind shipped  topic {ASE-L}
  q   {ASE-L can keep a run's results under a name of your choice, and later switch back to
       them or delete them.}
  ok  true
  why {In ASE-L: Results > Save..., Select... and Delete...}
  proof {[P_proc ::ase::ui::rsave_dialog] && [P_proc ::ase::ui::rsel_dialog] && [P_proc ::ase::ui::rdel_dialog]}
}
startup_quiz::add ase-dest {
  type mc  kind howto  topic {ASE-L}
  q   {Where do the plots of ASE-L's ~ button go, unless you say otherwise?}
  a   {{They replace what the viewer shows}
       {They are added to what is already there}
       {Into a new sub-window}
       {Into a new viewer window}}
  ok  0
  why {The drop-down in ASE-L's status bar offers Append, Replace, New SubWin and New Win,
       and starts at Replace. 'set ase_plot_dest append' in an rc file changes the start.}
  proof {[P_proc ::ase::ui::plot_dest_labels]
         && [ase::ui::plot_dest_labels] eq {Append Replace {New SubWin} {New Win}}
         && [P_proc ::ase::plot_dest_default] && [P_default ase_plot_dest {}]}
}

# -------------------------------------------------------------------- Direct Plot
startup_quiz::add direct-plot {
  type tf  kind shipped  topic {Plotting}
  q   {With Direct Plot you click nets on the schematic, press Esc, and they are plotted in
       the waveform viewer.}
  ok  true
  why {ASE-L: Results > Direct Plot. Click a wire or net label for its voltage, the body
       of a source or ammeter for its current, or a device pin for the current into it; the
       pin gets an ellipse in its trace's colour. A pin's current is plotted only if the
       last run saved it (Outputs > To Be Saved > Select On Design, run). Otherwise a
       source's or ammeter's pin plots the device's current, sign reversed on its second
       pin.}
  proof {[P_has src/ase_window.tcl {mb.results add command -label {Direct Plot}}] && [P_proc ::ase::ui::direct_plot]
         && [P_sub pin_at] && [P_body ::ase::ui::sod_click {ase::ui::sod_terminal_at}]
         && [P_body ::ase::ui::sod_terminal_pick {ase::raw_vectors_present}]
         && [P_body ::ase::ui::sod_terminal_pick {ase::ui::sod_terminal_as_source}]
         && [P_body ::ase::ui::sod_terminal_pick {ase::ui::sod_source_standin_notes}]
         && [P_body ::ase::ui::sod_source_standin_notes {is the negative of that trace}]
         && [P_sub pin_marker] && [P_body ::ase::ui::dp_hilight {xschem pin_marker add}]}
}
startup_quiz::add viewer-plot-mode-key {
  type tf  kind shipped  topic {Plotting}
  q   {In a waveform viewer window, Ctrl+Shift+M switches the plot between single-plot and
       multi-plot mode.}
  ok  true
  why {The same as Options > Plot Mode in the viewer. The pointer only has to be over the
       plot: a viewer takes its keys without a click in it first, and a schematic editing
       key typed there does nothing. In the Cadence profile, Ctrl+Shift+4 switches the
       mode from the schematic window.}
  proof {[P_has src/wave_viewer.tcl {bind WaveViewer <Control-Shift-Key-M> {wviewer::plot_mode_toggle_at %W; break}}]
         && [P_has src/wave_viewer.tcl {proc wviewer::plot_mode_toggle_at }]
         && [P_has src/wave_viewer.tcl {-accelerator Ctrl+Shift+M}]
         && [P_has src/wave_viewer.tcl {add cascade -label {Plot Mode}}]
         && [P_hasre src/cadence_style_rc {bind \.drw <Control-Shift-Key-4>\s+\{ase::plot_mode_for_current invert;\s+break\}}]}
}

# ---------------------------------------------------------------- Waveform viewer
startup_quiz::add wv-open {
  type mc  kind howto  topic {Waveform viewer}
  q   {The Waveform Viewer is a window of its own, with tabs, strips and a signal browser.
       Where do you open it by hand?}
  a   {{In the ASE-L window: Tools > Waveform Viewer}
       {In the schematic window: View > Waveform Viewer}
       {In the schematic window: File > Waveform Viewer}
       {It opens by itself whenever a schematic is loaded}}
  ok  0
  why {The viewer belongs to an ASE-L session, so it is on ASE-L's own Tools menu. It also
       comes up by itself when a run ends with outputs to plot.}
  proof {[P_proc ::ase::ui::lbl_waveform_viewer] && [ase::ui::lbl_waveform_viewer] eq {Waveform Viewer}
         && [P_has src/ase_window.tcl {mb.tools add command -label [ase::ui::lbl_waveform_viewer]}]
         && ![P_has src/xschem.tcl {-label "Waveform Viewer"}] && ![P_has src/xschem.tcl {-label {Waveform Viewer}}]}
}
startup_quiz::add wv-tabs {
  type tf  kind shipped  topic {Waveform viewer}
  q   {The waveform viewer has tabs, and a tab can be divided into sub-windows.}
  ok  true
  why {Inside the viewer: File > New Tab (Ctrl+N) and Graph > New SubWin (Ctrl+Shift+N).}
  proof {[P_proc ::wviewer::new_tab_at] && [P_proc ::wviewer::new_subwin_at]
         && [P_has src/wave_viewer.tcl {bind WaveViewer <Control-Key-n> {wviewer::new_tab_at %W; break}}]}
}
startup_quiz::add wv-divider {
  type tf  kind upcoming  topic {Waveform viewer}
  q   {In the waveform viewer you can drag the divider between two sub-windows to make one
       of them bigger.}
  ok  false
  why {Sub-windows share the space equally for now. Dragging the divider is planned.}
  proof {[P_proc ::wviewer::sw_bound] && [info args ::wviewer::sw_bound] eq {j m v1 v2}
         && ![regexp {sw_drag|sw_resize|sw_divider|sw_frac|sw_ratio|sw_weight} [P_text src/wave_viewer.tcl]]}
}
startup_quiz::add wv-strips {
  type mc  kind upcoming  topic {Waveform viewer}
  q   {Which of these waveform viewer commands is not built yet?}
  a   {{Split Strip} {Move to Separate Strip} {Delete Empty Strips} {Combine Strips}}
  ok  3
  why {Split Strip, Move to Separate Strip and Delete Empty Strips are all there. Combine
       Strips is on the wish list.}
  proof {[P_has src/wave_viewer.tcl {Split Strip}] && [P_has src/wave_viewer.tcl {-label {Move to Separate Strip}}]
         && [P_has src/wave_viewer.tcl {Delete Empty Strips}]
         && ![regexp -nocase {combine} [P_text src/wave_viewer.tcl]]}
}
startup_quiz::add wv-clear {
  type mc  kind howto  topic {Waveform viewer}
  q   {In the waveform viewer, what does Ctrl+D (Clear All) remove?}
  a   {{Every strip and trace; the loaded results stay, so you can plot again at once}
       {Every strip and trace, and the loaded results, so you must simulate again}
       {Only the selected traces}
       {Only the markers}}
  ok  0
  why {Clear All empties the window but keeps the results it was showing, the plot mode and
       the cursors. Ctrl+E deletes all markers, and e deletes the empty strips.}
  proof {[P_has src/wave_viewer.tcl {bind WaveViewer <Control-Key-d> {wviewer::clear_all_at %W; break}}]
         && [P_has src/wave_viewer.tcl {bind WaveViewer <Control-Key-e> {wviewer::delete_all_markers_at %W; break}}]
         && [P_has src/wave_viewer.tcl {bind WaveViewer <Key-e> {wviewer::delete_empty_strips_at %W; break}}]
         && [P_proc ::wviewer::clear_all] && ![P_body ::wviewer::clear_all {xschem raw clear}]}
}
startup_quiz::add wv-undo {
  type tf  kind shipped  topic {Waveform viewer}
  q   {In the waveform viewer, u undoes your last change to the layout, such as moving or
       deleting a trace, and Shift+U redoes it.}
  ok  true
  why {The viewer keeps its own undo history, separate from the schematic's.}
  proof {[P_has src/wave_viewer.tcl {bind WaveViewer <Key-u> {wviewer::undo_at %W; break}}]
         && [P_has src/wave_viewer.tcl {bind WaveViewer <Key-U> {wviewer::redo_at %W; break}}]}
}

# --------------------------------------------------------------- Waveform markers
startup_quiz::add wv-markers {
  type mc  kind howto  topic {Waveform markers}
  q   {With the pointer over a waveform, which key drops a marker that also shows the
       difference to the marker before it?}
  a   {{d} {m} {x} {Ctrl+M}}
  ok  0
  why {m drops a plain marker on the nearest sample; d drops one that also reads out the
       delta to the previous marker.}
  proof {[P_bind key 100 0 graph graph.forward] && [P_sub graph_marker]
         && [P_has src/callback.c {mousey), 1) > 0)}] && [P_has src/callback.c {mousey), 0) > 0)}]}
}
startup_quiz::add wv-resnap {
  type tf  kind upcoming  topic {Waveform markers}
  q   {After you re-run a simulation, one command moves the waveform markers onto the new
       traces.}
  ok  false
  why {Markers keep the values they were placed at, so after a re-run you place them again.
       A re-snap command is planned.}
  proof {[P_sub graph_marker] && ![P_has src/scheduler.c resnap] && ![P_has src/draw.c resnap]}
}
startup_quiz::add wv-logaxis {
  type mc  kind howto  topic {Waveform markers}
  q   {In the waveform viewer, how do you switch an axis between linear and logarithmic?}
  a   {{Right-click the axis numbers and pick Linear or Log}
       {Re-run the simulation with a logarithmic sweep}
       {Edit the axis line of the raw file}
       {You cannot: the axis follows the analysis}}
  ok  0
  why {Right-click in the number margin of the X or the Y axis. Graph > Axes... has the same
       two switches as checkboxes.}
  proof {[P_proc ::wviewer::axis_menu_build] && [P_proc ::wviewer::set_axis_scale]
         && [P_has src/wave_viewer.tcl {-text {Log X}}]}
}

# ----------------------------------------------------------------- Signal browser
startup_quiz::add sb-show {
  type tf  kind shipped  topic {Signal browser}
  q   {From the schematic, Ctrl+Alt+V shows where you are in the hierarchy, or the selected
       instance, in the waveform viewer's Signal Browser.}
  ok  true
  why {Also Tools > Show in Signal Browser. Inside the viewer, Ctrl+B shows and hides the
       browser, and its Descend to here takes the schematic window to the level picked there.}
  proof {[P_bind key 118 ctrl+alt canvas wave.show_in_signal_browser]
         && [P_has src/xschem.tcl {-label "Show in Signal Browser"}]
         && [P_has src/wave_viewer.tcl {bind WaveViewer <Control-Key-b> {wviewer::browser_toggle_at %W; break}}]
         && [P_has src/wave_viewer.tcl {-label {Descend to here}}]}
}

# --------------------------------------------------------------------- Calculator
startup_quiz::add calc-open {
  type mc  kind howto  topic {Calculator}
  q   {Where do you open the waveform Calculator?}
  a   {{Tools > Calculator}
       {Simulation > Calculator}
       {Press = on the schematic}
       {Waves > Calculator}}
  ok  0
  why {Tools > Calculator in the schematic window; it is also in the command palette and on
       ASE-L's Tools menu. The = key opens a Tcl command prompt instead.}
  proof {[P_has src/xschem.tcl {menubar.tools add command -label "Calculator" -command "calc::open"}]
         && [P_palette calc.open] && [P_bind key 61 0 canvas tools.execute_tcl_command]
         && [regexp -all -- {-label "Calculator"} [P_text src/xschem.tcl]] == 1}
}
startup_quiz::add calc-table {
  type tf  kind upcoming  topic {Calculator}
  q   {The Calculator's Table button lists the X and Y values of the expression in a
       scrollable table.}
  ok  false
  why {The Table button is there but not wired yet. Eval gives you a number and Plot a
       curve; the table is planned.}
  proof {[P_body ::calc::build_mode {calc::inert {Table} 10}]}
}
startup_quiz::add calc-memories {
  type tf  kind upcoming  topic {Calculator}
  q   {The Calculator's M+ and ME buttons store expressions in memories and recall them
       later.}
  ok  false
  why {Those two buttons are placeholders for now. The expression stack already works:
       Enter pushes the expression, and a double-click on a stack entry brings it back.}
  proof {[P_bodyre ::calc::build_buf {mplus\s+\{M\+\}\s+9\s+\{\}}] && [P_proc ::calc::stk_enter]}
}
startup_quiz::add calc-eye {
  type mc  kind upcoming  topic {Calculator}
  q   {Which of these Calculator functions is not built yet?}
  a   {{riseTime} {phaseMargin} {dutyCycle} {eyeDiagram}}
  ok  3
  why {riseTime, phaseMargin and dutyCycle all measure today. eyeDiagram is in the function
       list but still to come.}
  proof {[P_proc ::calc::meas_verb] && [calc::meas_verb riseTime] && [calc::meas_verb phaseMargin]
         && [calc::meas_verb dutyCycle] && ![calc::meas_verb eyeDiagram]}
}
startup_quiz::add calc-pick {
  type tf  kind shipped  topic {Calculator}
  q   {In the Calculator, after choosing vt you can click a net on the schematic instead of
       typing its name.}
  ok  true
  why {The selectors vt, vf, vdc and vs pick a net with a click. it, if, idc and is pick a
       current the same way: click a pin of a device for the current into that pin, or the
       body of a voltage source or an ammeter for its own current. A pin's current is
       inserted only if the loaded result holds it. To get it there, pick the pin in ASE-L
       under Outputs > To Be Plotted > Select On Design and run again.}
  proof {[P_proc ::calc::pick_click] && [P_proc ::calc::sel_click]
         && [lindex [calc::sel_rows] 0 0] eq {vt vf vdc vs} && [lindex [calc::sel_rows] 1 0] eq {it if idc is}
         && [P_body ::calc::pick_imeasure {ase::ui::sod_terminal_at}]
         && [P_body ::calc::pick_imeasure {ase::ui::sod_source_at}]
         && [P_body ::calc::pick_click {calc::pick_imeasure}]
         && [P_body ::calc::pick_msg {is not in this result; ASE-L Outputs: To Be Plotted}]
         && ![P_body ::calc::pick_msg {terminal currents not supported}]
         && [P_sub pin_at] && [P_body ::ase::ui::sod_click {ase::ui::sod_terminal_at}]}
}
startup_quiz::add calc-measure {
  type tf  kind shipped  topic {Calculator}
  q   {The Calculator can measure the rise time, delay, duty cycle, overshoot, bandwidth
       and phase margin of a waveform.}
  ok  true
  why {Pick the function in the Calculator's function list and fill in its small form;
       slewRate, settlingTime, frequency, gainMargin and gainBwProd are there too.}
  proof {[calc::meas_verb riseTime] && [calc::meas_verb delay] && [calc::meas_verb dutyCycle]
         && [calc::meas_verb overshoot] && [calc::meas_verb bandwidth] && [calc::meas_verb phaseMargin]
         && [calc::meas_verb slewRate] && [calc::meas_verb settlingTime] && [calc::meas_verb frequency]
         && [calc::meas_verb gainMargin] && [calc::meas_verb gainBwProd]}
}

# ---------------------------------------------------------------- Operating point
startup_quiz::add rdw {
  type tf  kind shipped  topic {Operating point}
  q   {The Results Display Window shows a device's operating-point values as text that you
       can select and copy.}
  ok  true
  why {Tools > Results Display Window. Ctrl+C copies, and its Help button lists the keys
       that fill it.}
  proof {[P_has src/xschem.tcl {-label "Results Display Window" -command "rdw::open"}]
         && [P_has src/rdw.tcl {bind .rdw <Control-Key-c>}] && [P_proc ::rdw::help]}
}
startup_quiz::add annot-tran {
  type tf  kind shipped  topic {Operating point}
  q   {Node voltages from a transient run can be written onto the schematic for the moment
       a waveform cursor points at.}
  ok  true
  why {In ASE-L: Results > Annotate > Transient Node Voltages (at cursor). The same menu
       has Operating Point info and DC Node Voltages.}
  proof {[P_has src/ase_window.tcl {-label {Transient Node Voltages (at cursor)}}]
         && [P_has src/ase_window.tcl {-label {Operating Point info}}]}
}

# --------------------------------------------------------------------- PDF export
startup_quiz::add pdf-nav {
  type mc  kind howto  topic {PDF export}
  q   {The hierarchical PDF export can put a Back button and a list of parent sheets on
       every page. How do you switch that on?}
  a   {{Set ps_hier_nav to back, up or both in your rc file}
       {Tick Options > PDF navigation}
       {Add nav=1 to the top-level schematic}
       {Nothing to do: it is always on}}
  ok  0
  why {ps_hier_nav is none by default. Then use File > Image export > Hierarchical PDF/PS
       Export as usual.}
  proof {[P_default ps_hier_nav none] && [P_has src/psprint.c ps_hier_nav_strip]
         && [P_label file.im_exp.pdf_hier {Hierarchical PDF/PS Export}]
         && ![P_has src/xschem.tcl {PDF navigation}]}
}

# ------------------------------------------------------------------------ Colours
startup_quiz::add color-key {
  type mc  kind howto  topic {Colours}
  q   {Which chord flips between the dark and the light colour scheme?}
  a   {{Shift+O} {Ctrl+O} {Alt+O} {Ctrl+Shift+O}}
  ok  0
  why {Shift+O, or View > Toggle colorscheme. Ctrl+O opens a file, Alt+O opens one in a new
       tab or window, and Ctrl+Shift+O reopens the most recent file.}
  proof {[P_bind key 79 0 canvas view.toggle_colorscheme] && [P_palette view.toggle_colorscheme]}
}
startup_quiz::add colors-session {
  type tf  kind myth  topic {Colours}
  q   {A layer colour you change is forgotten when you quit.}
  ok  false
  why {A colour picked with View > Change current layer color is saved to ~/.xschem/colors
       at once and read back at the next start. View > Reset all colors to default takes
       you back to the shipped colours.}
  proof {[P_has src/xschem.tcl {Change current layer color}] && [P_has src/xschem.tcl {Reset all colors to default}]
         && [P_body ::change_color {write_data $savedata ${USER_CONF_DIR}/colors}]
         && [P_body ::reset_colors {file delete ${USER_CONF_DIR}/colors}]}
}

# ------------------------------------------------------------------------ Options
startup_quiz::add cadence-compat {
  type mc  kind howto  topic {Options}
  q   {How do you turn on Cadence-compatible mouse and key behaviour in a running session?}
  a   {{Tick Options > Cadence Compatible}
       {Tick View > Cadence mode}
       {Restart XSCHEM with --cadence}
       {Open ASE-L, which turns it on}}
  ok  0
  why {Options > Cadence Compatible, or 'set cadence_compat 1' in an rc file. The full
       Cadence profile, with its extra keys, is the cadence_style_rc file passed with
       --script.}
  proof {[P_has src/xschem.tcl {menubar.option add checkbutton -label "Cadence Compatible"}]
         && [P_default cadence_compat 0] && ![P_has src/options.c {"cadence"}]
         && ![P_has src/xschem.tcl {-label "Cadence mode"}] && [P_file src/cadence_style_rc]}
}

# ---------------------------------------------------------------- Cadence profile
# Asked only where the profile's rc (src/cadence_style_rc, which every PDK's
# profile sources) has run: cadence::q_key is defined there and nowhere else. Not
# the cadence namespace, which utils/annot_mode.tcl creates in any session that
# opens ASE-L (ase::ui::annot_tran_helper). test_startup_quiz rows A21 and A22.
startup_quiz::add cad-hilight {
  type mc  kind howto  topic {Cadence profile}
  q   {In the Cadence profile, which keys highlight a net, remove one net's highlight, and
       remove every highlight?}
  a   {{9, 8 and 0} {1, 2 and 3} {4, 5 and 6} {Ctrl+1, Ctrl+2 and Ctrl+3}}
  ok  0
  why {9 highlights, stepping to the next style each time; 8 removes one net's highlight
       and 0 clears them all. In the waveform viewer the same three keys do it for traces.}
  only  {[llength [info commands ::cadence::q_key]] > 0}
  proof {[P_hasre src/cadence_style_rc {bind \.drw <Key-9>\s+\{xschem hilight_net_interactive;\s+break\}}]
         && [P_hasre src/cadence_style_rc {bind \.drw <Key-8>\s+\{xschem unhilight_net_interactive;\s+break\}}]
         && [P_hasre src/cadence_style_rc {bind \.drw <Key-0>\s+\{xschem unhilight_all;\s+break\}}]
         && [P_has src/wave_viewer.tcl {bind WaveViewer <Key-9> {wviewer::hilight_traces_at %W; break}}]}
}
startup_quiz::add cad-annot {
  type mc  kind howto  topic {Cadence profile}
  q   {In the Cadence profile, after a run, which key puts the devices' operating-point
       info on the schematic?}
  a   {{6} {7} {Ctrl+6} {Alt+6}}
  ok  0
  why {6 adds the device info, Alt+6 the node voltages, and Ctrl+6 clears both.}
  only  {[llength [info commands ::cadence::q_key]] > 0}
  proof {[P_hasre src/cadence_style_rc {bind \.drw <Key-6>\s+\{cadence::annot_mode op;\s+break\}}]
         && [P_hasre src/cadence_style_rc {bind \.drw <Alt-Key-6>\s+\{cadence::annot_mode opvolt;\s+break\}}]
         && [P_hasre src/cadence_style_rc {bind \.drw <Control-Key-6>\s+\{cadence::annot_mode none;\s+break\}}]
         && ![P_has src/cadence_style_rc {bind .drw <Key-7>}]}
}
startup_quiz::add cad-rdw {
  type tf  kind shipped  topic {Cadence profile}
  q   {In the Cadence profile, the keys 1, 2 and 3 send the selected device's
       operating-point values to the Results Display Window.}
  ok  true
  why {1 sends its annotation list, 2 its summary list and 3 everything the run holds; 4
       refreshes. With nothing selected, the key waits for you to click a device.}
  only  {[llength [info commands ::cadence::q_key]] > 0}
  proof {[P_has src/cadence_style_rc {rdw::key annotation}] && [P_has src/cadence_style_rc {rdw::key summary}]
         && [P_has src/cadence_style_rc {rdw::key all}] && [P_has src/cadence_style_rc {rdw::key refresh}]
         && [P_proc ::rdw::key]}
}
startup_quiz::add cad-find {
  type tf  kind shipped  topic {Cadence profile}
  q   {In the Cadence profile, Ctrl+Shift+G opens a Find Navigator that finds ports,
       instances or net labels by name and can rename them in bulk.}
  ok  true
  why {It works on the sheet in front of you: select, count or list the matches, or rename
       them all in one step.}
  only  {[llength [info commands ::cadence::q_key]] > 0}
  proof {[P_has utils/find_helper.tcl {bind .drw <Control-Shift-Key-G> {find_helper::show; break}}]
         && [P_has src/cadence_style_rc find_helper.tcl]}
}
startup_quiz::add plot-difference {
  type mc  kind howto  topic {Cadence profile}
  q   {In the Cadence profile, Alt+Shift+D on the schematic asks you to click one net and
       then another. What is plotted in the waveform viewer?}
  a   {{The second net's voltage minus the first's} {The first net's voltage minus the second's}
       {The two nets, as two traces} {The sum of the two voltages}}
  ok  0
  why {Second minus first, as one trace, read from the transient analysis of the result;
       Esc before the second click cancels. For an AC or a DC sweep result, copy the
       Alt-Key-D bind line of cadence_style_rc to a key of your own and change the word
       tran to ac or dc. Ctrl+4 is Direct Plot, which plots each net you click.}
  only  {[llength [info commands ::cadence::q_key]] > 0}
  proof {[P_hasre src/cadence_style_rc {bind \.drw <Alt-Key-D>\s+\{ase::plot_difference_for_current tran;\s+break\}}]
         && [P_hasre src/cadence_style_rc {# bind \.drw <Alt-Key-A>\s+\{ase::plot_difference_for_current ac;\s+break\}}]
         && [P_hasre src/cadence_style_rc {# bind \.drw <Alt-Key-S>\s+\{ase::plot_difference_for_current dc;\s+break\}}]
         && [P_proc ::ase::plot_difference_for_current]
         && [P_body ::ase::diff_text {return "$b - $a"}]
         && [P_body ::ase::ui::pd_msg {click second net (second minus first)}]
         && [P_hasre src/cadence_style_rc {bind \.drw <Control-Key-4>\s+\{ase::direct_plot_for_current;\s+break\}}]}
}
# Issue 1737. A topic of its own: the topic ASE-L holds as many questions as a
# topic may.
startup_quiz::add ase-pane-dividers {
  type mc  kind howto  topic {ASE-L window}
  q   {The Outputs pane of the ASE-L window shows fewer rows than you have measures. How do
       you bring more of them into view?}
  a   {{Drag the gap between the Analyses and Outputs panes upward}
       {Delete analyses until the Outputs pane grows}
       {Set a pane height in the state file and load the state again}
       {You cannot: the three panes have a fixed split}}
  ok  0  last 3
  why {The gap between two panes is a divider. Over it the pointer turns into a double
       arrow; drag it with the left button. The one between Design Variables and the two
       panes at its right drags left and right. Resizing the window keeps the proportions,
       and a window closed and opened again in the same xschem comes back with your split.}
  proof {[P_body ::ase::ui::pane_layout {panedwindow $pw -orient $orient}]
         && [P_body ::ase::ui::pane_layout {-sashcursor $cur}]
         && [P_body ::ase::ui::pane_add {-stretch always}]
         && [P_body ::ase::ui::pane_drop {dict set panesplit($key)}]
         && [P_body ::ase::ui::build {ase::ui::pane_layout $key $top}]
         && ![P_bodyre ::ase::ui::close {unset\s+panesplit}]}
}
# The double-click grow is the Cadence profile's (`set cadence_compat 1` in its rc),
# so this one is asked where the others above are.
startup_quiz::add dblclick-labels {
  type tf  kind myth  topic {Selection}
  q   {In the Cadence profile, double-clicking a wire to grow the selection along the net
       takes wires only: the net-name labels sitting on them are left out.}
  ok  false
  why {Each double click selects one more ring of connected wires, the third reaching the
       whole net, and with them the net-name labels on those wires. So Delete after the
       third removes the net with its labels. Ports, probes, devices and the global power
       symbols (vdd, gnd) are left.}
  only  {[llength [info commands ::cadence::q_key]] > 0}
  proof {[P_has src/cadence_style_rc {set cadence_compat 1}] && [P_sub select_grow_connected]
         && [P_has src/select.c {static int dblgrow_select_labels(void)}]
         && [P_has src/select.c {static int dblgrow_is_netname_label(int i)}]
         && [P_has src/callback.c {select_grow_connected_step(xctx->mousex, xctx->mousey, 1);}]}
}

# ---------------------------------------------------------------- ASE-L run checks
startup_quiz::add rename-correction {
  type tf  kind shipped  topic {ASE-L run checks}
  q   {After you rename an instance, ASE-L can rewrite the outputs that still name the old
       instance path, so you do not have to edit them one by one.}
  ok  true
  why {Run stops before the simulator and lists each stale name with its correction, such
       as v(x1.a1) -> v(xdut.a1); Apply Corrections rewrites them. It is offered when
       exactly one instance makes every refused name resolve. .nodeset and .ic names in the
       session's include files are checked the same way and rewritten after asking; Setup >
       Include Files lists those files.}
  proof {[P_proc ::ase::preflight_rename_solve] && [P_proc ::ase::preflight_fix_session]
         && [P_body ::ase::preflight_apply_label {Apply Corrections}]
         && [P_proc ::ase::include_card_idents]
         && [P_proc ::ase::ui::lbl_include_files_menu] && [P_proc ::ase::ui::include_files_dialog]}
}

# ------------------------------------------------------------------ sky130 symbols
startup_quiz::add sky-pin-voltages {
  type tf  kind shipped  topic {sky130 symbols}
  q   {On the sky130 FET symbols, node-voltage annotation shows the voltage right at the
       drain, gate and source pins.}
  ok  true
  why {After an operating-point run, turn the node voltages on (Alt+6 in the Cadence
       profile, or ASE-L: Results > Annotate > DC Node Voltages).}
  only  {[llength [info commands ::sky130_fet_limits]] > 0}
  proof {[P_has sky130A/xschem_libs/sky130_fd_pr/nfet_01v8/symbol/nfet_01v8.sym {T {@#D:spice_get_voltage}}]
         && [P_has sky130A/xschem_libs/sky130_fd_pr/nfet_01v8/symbol/nfet_01v8.sym {T {@#G:spice_get_voltage}}]
         && [P_has sky130A/xschem_libs/sky130_fd_pr/nfet_01v8/symbol/nfet_01v8.sym {T {@#S:spice_get_voltage}}]
         && [P_has sky130A/sky130_procs.tcl {proc sky130_fet_limits}]}
}
startup_quiz::add sky-res-series {
  type tf  kind shipped  topic {sky130 symbols}
  q   {A sky130 resistor can be drawn once and netlisted as several resistors in series, by
       setting its ns property.}
  ok  true
  why {ns is 1 by default. With ns greater than 1 the one symbol netlists as a chain of
       that many segments.}
  only  {[llength [info commands ::sky130_fet_limits]] > 0}
  proof {[P_has sky130A/xschem_libs/sky130_fd_pr/res_high_po/symbol/res_high_po.sym {ns=@ns}]
         && [P_has sky130A/xschem_libs/sky130_fd_pr/res_high_po/symbol/res_high_po.sym sky130_res_series]}
}

# ----------------------------------------------------------------- User interface
startup_quiz::add voice {
  type tf  kind upcoming  topic {User interface}
  q   {XSCHEM can be driven by voice commands such as 'run sim' or 'plot vbg'.}
  ok  false
  why {Voice control is a plan on paper and nothing more yet. Until then, the command
       palette (Ctrl+Shift+P) is the quickest way to run a command by name.}
  proof {![P_file src/voice.tcl] && [llength [info commands ::voice::*]] == 0
         && [llength [info commands ::recipe::*]] == 0}
}

# ---------------------------------------------------------------------- This quiz
startup_quiz::add quiz-switch {
  type mc  kind howto  topic {This quiz}
  q   {How do you turn this tip of the day off, or back on?}
  a   {{The 'Don't show anymore' box below}
       {Help > Tip of the day at startup}
       {Command palette: Toggle tip of the day at startup}
       {Any of these}}
  ok  3
  last 3
  why {All three are the same switch. In an rc file it is 'set startup_quiz 0'. Help > Tip
       of the day (quiz)... asks a question whenever you like, switch or no switch.}
  proof {[P_palette help.tip_of_the_day_startup] && [P_palette help.tip_of_the_day]
         && [P_has src/xschem.tcl {-label "Tip of the day at startup" -variable startup_quiz}]
         && [P_body ::startup_quiz::window {-text {Don't show anymore} -variable ::startup_quiz}]
         && [P_default startup_quiz 1]}
}
startup_quiz::add quiz-close {
  type tf  kind myth  topic {This quiz}
  q   {Closing this window stops the tip of the day from coming up again.}
  ok  false
  why {Closing only closes. To stop it, tick 'Don't show anymore'; to bring it back, use the
       command palette or the Help menu.}
  proof {[P_body ::startup_quiz::dismiss destroy] && ![P_body ::startup_quiz::dismiss startup_quiz_done]
         && ![P_bodyre ::startup_quiz::dismiss {set\s+::startup_quiz\M}]}
}
