## File: ciw.tcl
##
## CIW (Command Interpreter Window, after Virtuoso's) -- a standalone toplevel
## with a live view of the action log plus a command entry evaluated by the
## xschem Tcl interpreter (starts at one line; dragging the sash grows it).
## Spec: doc/claude/specs/action_logging.md section 3.
##
## Sourced from xschem.tcl at startup; ciw_create is called automatically for
## interactive sessions (spec decision 8). The C action-log sink (log_action()
## in util.c) mirrors every line it writes to Xschem.log into the upper pane
## by calling ciw_echo. Commands typed in the lower entry are echoed here
## (input tag), recorded in Xschem.log via `xschem log_action -noecho`, and
## evaluated at global scope; their result or error is shown in the pane only,
## never written to the file, so the file stays source-able (decision 7).

## Command history state (Up/Down in the entry). hist_pos == llength(history)
## means "on the live line"; the draft typed there is stashed in hist_pending
## by the first Up and restored when Down walks past the newest entry.
set ::ciw_history {}
set ::ciw_hist_pos 0
set ::ciw_hist_pending {}

## Tab-completion: the `xschem` subcommand vocabulary, loaded lazily from the
## build-generated xschem_subcommands.txt (see doc/claude/specs/ciw_autocomplete.md). Empty
## until the first Tab, and stays empty (gracefully) if the file is absent, in
## which case only command/var/path completion work.
set ::ciw_subcommands {}

## Build (or re-show) the CIW. The two panes sit in a vertical panedwindow so
## the split is user-adjustable by dragging the sash (spec decision 9); the
## entry pane starts at its natural one-line height and stays fixed on window
## resize (the log pane takes the extra space).
proc ciw_create {} {
  if {[winfo exists .ciw]} {
    ## a bare `raise` is a no-op under Weston/WSLg (issue 0054): use the shared
    ## withdraw+deiconify+activate helper that the Library Manager uses, then put
    ## the keyboard focus on the command entry so the user can type immediately.
    raise_activate_toplevel .ciw
    catch {focus -force .ciw.c.e}
    return
  }
  toplevel .ciw
  ## title shows the full path of the action-log file being displayed (e.g.
  ## /tmp/Xschem.log.38), so the user always knows which file the pane mirrors.
  set _log [xschem get actionlog_filename]
  if {$_log ne {}} {
    wm title .ciw "xschem CIW - [file normalize $_log]"
  } else {
    wm title .ciw {xschem CIW}
  }
  ## closing the CIW must not exit xschem: withdraw, keeping the accumulated
  ## log so a later ciw_create just re-shows it
  wm protocol .ciw WM_DELETE_WINDOW {wm withdraw .ciw}

  ## fat raised sash: the default is a near-invisible few-pixel strip that is
  ## both undiscoverable and a poor drag target (8px was still too thin on a
  ## HiDPI display -- user feedback). Darker background makes the sash band
  ## read as a control, and the cursor signals draggability on hover.
  panedwindow .ciw.p -orient vertical -sashwidth 14 -sashrelief raised \
    -background gray55 -sashcursor sb_v_double_arrow

  # upper pane: read-only log display, fed by ciw_echo
  frame .ciw.l
  text .ciw.l.t -width 80 -height 14 -font {Monospace 10} -state disabled \
    -yscrollcommand {.ciw.l.yscroll set}
  scrollbar .ciw.l.yscroll -command {.ciw.l.t yview}
  .ciw.l.t tag configure input  -foreground blue
  .ciw.l.t tag configure result -foreground gray30
  .ciw.l.t tag configure error  -foreground red
  pack .ciw.l.yscroll -side right -fill y
  pack .ciw.l.t -side top -fill both -expand yes

  # lower pane: command entry. A text widget (not an entry) so its height
  # actually FOLLOWS the sash: dragging the sash up gives a taller entry area
  # where long commands wrap visibly. It still starts at one line (decision 9)
  # and Return executes instead of inserting a newline ('break' stops the
  # class binding that would).
  frame .ciw.c
  text .ciw.c.e -height 1 -font {Monospace 10} -wrap char -undo 1
  bind .ciw.c.e <Return>   {ciw_exec; break}
  bind .ciw.c.e <KP_Enter> {ciw_exec; break}
  ## shell-style line editing. 'break' everywhere: the Text class bindings
  ## would otherwise also delete one char / move the cursor a display line.
  bind .ciw.c.e <Control-BackSpace> {ciw_delete_word; break}
  bind .ciw.c.e <Up>   {ciw_hist_move -1; break}
  bind .ciw.c.e <Down> {ciw_hist_move  1; break}
  ## Tab completes the token under the cursor (readline/bash style). 'break' is
  ## load-bearing: without it Tk also runs the default <Tab> binding and moves
  ## keyboard focus out of the entry.
  bind .ciw.c.e <Tab> {ciw_complete; break}
  pack .ciw.c.e -side top -fill both -expand yes -padx 3 -pady 5

  .ciw.p add .ciw.l .ciw.c
  ## -stretch needs Tk >= 8.5; without it the default (last pane stretches)
  ## merely makes resizes grow the entry pane instead of the log pane.
  ## -minsize keeps either pane from being collapsed to nothing by the sash.
  catch {
    .ciw.p paneconfigure .ciw.l -stretch always -minsize 60
    .ciw.p paneconfigure .ciw.c -stretch never  -minsize 34
  }
  pack .ciw.p -side top -fill both -expand yes
}

## Append one line to the CIW log pane. 'tag' selects the style: {} for
## mirrored action-log lines, input/result/error for CIW command traffic.
## Called from C (the log_action mirror) and from ciw_exec; safe no-op when
## the CIW does not exist.
proc ciw_echo {line {tag {}}} {
  # headless-safe: under --nogui there is no Tk, so `winfo` itself is undefined
  if {![llength [info commands winfo]] || ![winfo exists .ciw.l.t]} return
  .ciw.l.t configure -state normal
  .ciw.l.t insert end $line\n $tag
  .ciw.l.t configure -state disabled
  .ciw.l.t see end
}

## Run the command in the entry: echo it (visually distinct), evaluate at
## global scope, show the result or error in the pane, and record it in the
## action log file. Recording happens AFTER evaluation so the file stays
## source-able: a command that errored is written as a '# failed:' comment
## (replaying it would abort the source), a successful one is written raw.
## Delete the word before the cursor, shell-style: skip any whitespace
## immediately behind the cursor first, then eat to the start of the word.
proc ciw_delete_word {} {
  set w .ciw.c.e
  set i [$w index insert]
  while {[$w compare $i > 1.0] && [string is space -strict [$w get "$i -1c"]]} {
    set i [$w index "$i -1c"]
  }
  if {[$w compare $i > 1.0]} { set i [$w index "$i -1c wordstart"] }
  $w delete $i insert
}

## Walk the command history (dir -1 = older, +1 = newer) into the entry.
## History-always semantics (terminal/Virtuoso style): Up recalls even when
## the cursor sits inside a tall wrapped command.
proc ciw_hist_move {dir} {
  set w .ciw.c.e
  set n [llength $::ciw_history]
  if {!$n} return
  set pos [expr {$::ciw_hist_pos + $dir}]
  if {$pos < 0 || $pos > $n} return
  if {$::ciw_hist_pos == $n} { set ::ciw_hist_pending [$w get 1.0 end-1c] }
  set ::ciw_hist_pos $pos
  $w delete 1.0 end
  if {$pos == $n} { $w insert end $::ciw_hist_pending } \
  else           { $w insert end [lindex $::ciw_history $pos] }
}

## Route a captured `puts` (its raw arg list) to the CIW log pane: a stdout write (`puts STRING`
## or `puts stdout STRING`) uses the `result` tag, a `puts stderr STRING` uses the `error` (red)
## tag, and any OTHER channel (a file/socket) or a malformed call is delegated VERBATIM to the real
## puts (saved as ::ciw_saved_puts while capture is active). `-nonewline` is accepted and ignored
## for the console channels (the log pane is line-oriented), but preserved when delegating. Only
## installed for the dynamic extent of a CIW command -- see ciw_exec. Spec: doc/claude/specs/ciw_puts_capture.md.
proc ciw_capture_puts {argl} {
  set a $argl
  if {[lindex $a 0] eq "-nonewline"} {set a [lrange $a 1 end]}
  set n [llength $a]
  if {$n == 1} {
    ciw_echo [lindex $a 0] result
  } elseif {$n == 2 && [lindex $a 0] eq "stdout"} {
    ciw_echo [lindex $a 1] result
  } elseif {$n == 2 && [lindex $a 0] eq "stderr"} {
    ciw_echo [lindex $a 1] error
  } else {
    eval [linsert $argl 0 ::ciw_saved_puts]   ;# 8.4-safe form of: ::ciw_saved_puts {*}$argl
  }
}

proc ciw_exec {} {
  set cmd [string trim [.ciw.c.e get 1.0 end-1c]]
  if {$cmd eq {}} return
  ## record into history (failed commands too, bash-style; consecutive
  ## duplicates collapse) and reset the cursor to the live line
  if {$cmd ne [lindex $::ciw_history end]} { lappend ::ciw_history $cmd }
  set ::ciw_hist_pos [llength $::ciw_history]
  set ::ciw_hist_pending {}
  .ciw.c.e delete 1.0 end
  ciw_echo "> $cmd" input
  ## Capture the command's stdout/stderr `puts` into the log pane, scoped to exactly this command
  ## (spec: ciw_puts_capture.md). Redefine puts around the eval and restore it right after; the
  ## rename pair is balanced and the catch keeps an error from skipping the restore. puts still
  ## returns "" so the result-echo below does not print captured text a second time.
  ## Dedup + echo-suppress (self-log-at-core): reset the flag, and while the command runs tell a
  ## core self-log to write the FILE but skip the CIW mirror (we already echoed the input line).
  xschem log_action -reset
  xschem log_action -suppressecho 1
  rename ::puts ::ciw_saved_puts
  proc ::puts {args} {ciw_capture_puts $args}
  set code [catch {uplevel #0 $cmd} res]
  rename ::puts {}
  rename ::ciw_saved_puts ::puts
  xschem log_action -suppressecho 0
  if {$code} {
    ciw_echo $res error
    ## D1 (issue 0070): record the error OUTPUT as a source-able comment in the file.
    xschem log_action -error $res
    ## record the command itself only if the core did not already self-log it.
    if {![xschem log_action -emitted]} { xschem log_action -noecho "# failed: $cmd" }
  } else {
    if {$res ne {}} {ciw_echo $res result ; xschem log_action -result $res}
    if {![xschem log_action -emitted]} { xschem log_action -noecho $cmd }
  }
}

## --- Tab completion ---------------------------------------------------------
## Readline/bash-style completion of the token under the cursor. Spec:
## doc/claude/specs/ciw_autocomplete.md.

## Load the xschem-subcommand vocabulary once, on the first Tab. The file is
## build-generated from scheduler.c (see the Makefile rule) and shipped to
## XSHAREDIR alongside ciw.tcl. A missing file is not an error: the list simply
## stays empty and subcommand completion is a no-op while the other sources work.
proc ciw_load_subcommands {} {
  if {[llength $::ciw_subcommands]} return
  global XSCHEM_SHAREDIR
  set f [file join $XSCHEM_SHAREDIR xschem_subcommands.txt]
  if {[catch {open $f r} fh]} return
  set ::ciw_subcommands [split [string trim [read $fh]] \n]
  close $fh
}

## Longest common prefix of a non-empty list of strings (case-sensitive). Used
## to advance an ambiguous token as far as is unambiguous before listing.
proc ciw_lcp {strings} {
  set pfx [lindex $strings 0]
  foreach s [lrange $strings 1 end] {
    while {![string equal -length [string length $pfx] $pfx $s]} {
      set pfx [string range $pfx 0 end-1]
      if {$pfx eq {}} return {}
    }
  }
  return $pfx
}

## Filesystem candidates for a path token (the fallback source: arguments to
## load/save/instance/... without having to know which subcommands take a path).
## Directories come back with a trailing '/' so a single match descends instead
## of terminating the token. glob expands a leading '~'.
proc ciw_path_candidates {tok} {
  set out {}
  foreach p [glob -nocomplain ${tok}*] {
    if {[file isdirectory $p]} { append p / }
    lappend out $p
  }
  return $out
}

## Candidate list for the token at position 'idx' (tok), given all tokens to the
## left of the cursor. Sources, most-specific first: $variable, xschem
## subcommand (2nd token), Tcl command/proc (1st token), else file path.
proc ciw_candidates {toks idx tok} {
  if {[string index $tok 0] eq "\$"} {
    set pfx [string range $tok 1 end]
    set out {}
    foreach v [info globals ${pfx}*] { lappend out "\$$v" }
    return $out
  }
  if {$idx == 1 && [lindex $toks 0] eq {xschem}} {
    ciw_load_subcommands
    set out {}
    foreach c $::ciw_subcommands {
      if {[string match ${tok}* $c]} { lappend out $c }
    }
    return $out
  }
  if {$idx == 0} {
    return [lsort -unique [info commands ${tok}*]]
  }
  return [ciw_path_candidates $tok]
}

## Replace the current token (its last [string length tok] chars before the
## cursor) with 'full'. A unique, non-directory completion (addspace) gets a
## trailing space so the next token can be typed straight away; a directory
## (ends in '/') and longest-common-prefix insertions never do.
proc ciw_insert_completion {tok full addspace} {
  set w .ciw.c.e
  set n [string length $tok]
  if {$n} { $w delete "insert - $n chars" insert }
  $w insert insert $full
  if {$addspace && [string index $full end] ne "/"} { $w insert insert { } }
}

## The <Tab> handler. The current token is the trailing run of non-whitespace
## before the cursor (empty when the cursor follows a space or the line is
## empty -- then Tab lists everything valid in that position).
proc ciw_complete {} {
  set line [.ciw.c.e get 1.0 insert]
  set toks [regexp -all -inline {\S+} $line]
  if {$line eq {} || [regexp {\s$} $line]} {
    set tok {}
    set idx [llength $toks]
  } else {
    set tok [lindex $toks end]
    set idx [expr {[llength $toks] - 1}]
  }
  set cands [ciw_candidates $toks $idx $tok]
  if {![llength $cands]} { bell; return }
  if {[llength $cands] == 1} {
    ciw_insert_completion $tok [lindex $cands 0] 1
  } else {
    set lcp [ciw_lcp $cands]
    if {[string length $lcp] > [string length $tok]} {
      ciw_insert_completion $tok $lcp 0
    } else {
      ciw_echo [join [lsort $cands] {  }] result
    }
  }
}
