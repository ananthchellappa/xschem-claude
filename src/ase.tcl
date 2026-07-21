# ase.tcl — ASE-L (Analog Simulation Environment) core: state-file I/O,
# per-simulator backend registry, deck rendering, headless-safe netlist +
# batch simulation run via the `execute` infra, result parsing.
#
# P1+P2 of doc/claude/specs/ase_l.md. Pure Tcl, NO Tk anywhere in the core
# paths — everything must run under --nogui (tests/headless/test_ase_core.tcl
# runs this file's procs true-headless) — with ONE carve-out: ase::open_state
# is the single Tk-GUARDED GUI seam (every Tk call in it sits behind the has_x
# guard, so it stays headless-callable). GUI (item 03) layers on top of these
# procs; their names are contracts.
#
# State = a single Tcl-dict text file per ngspice_state* view, one `key value`
# per line (see "State file schema" in the spec). Loading merges over
# ase::state_default; unknown keys are PRESERVED (forward compatibility).
# Saving writes canonical schema order then unknown keys sorted, `list`-quoted,
# so a load→save round trip of any state_save-produced file is byte-stable.
#
# Backend seam: ase::backends maps simulator name -> hook dict
# {render_deck run_cmd log_file result_probe} (proc names). v1 registers
# `ngspice` only; the only ngspice literals outside the ase::backend::ngspice
# namespace are the state_default schema defaults.

namespace eval ase {
  # canonical state-file key order (the spec's v1 schema)
  variable schema_keys {version simulator design rundir models variables
                        analyses outputs options includes}
  # simulator name -> hooks dict {render_deck run_cmd log_file result_probe}
  variable backends [dict create]
  # most recent completed run: {results <dict> exitcode <n> log <path> }
  variable last_run [dict create]
}

# dict get with a default (states are open dicts: keys may be absent).
proc ase::state_get {state key {dflt {}}} {
  if {[dict exists $state $key]} { return [dict get $state $key] }
  return $dflt
}

# --- State I/O --------------------------------------------------------------

# The v1 default state (spec "State file schema"). `simulator ngspice` here is
# the one permitted ngspice literal outside the backend namespace.
proc ase::state_default {} {
  return [dict create \
    version   1 \
    simulator ngspice \
    design    {} \
    rundir    {} \
    models    {} \
    variables {} \
    analyses  {{type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 0}} \
    outputs   {} \
    options   {} \
    includes  {}]
}

# Load a state file -> dict merged OVER the defaults (loaded values win,
# unknown keys preserved). The file is a flat Tcl list of key/value pairs; it
# must not contain Tcl comments (they would parse as list elements) — the
# saver never writes any. Clean errors on missing/malformed files.
proc ase::state_load {path} {
  if {![file isfile $path]} {
    return -code error "ase: state file not found: $path"
  }
  set f [open $path r]
  set content [read $f]
  close $f
  if {[catch {llength $content} len]} {
    return -code error "ase: malformed state file (not a Tcl list): $path"
  }
  if {$len % 2} {
    return -code error "ase: malformed state file (odd-length list): $path"
  }
  return [dict merge [ase::state_default] [dict create {*}$content]]
}

# Save a state dict: one `key [list value]` per line, canonical schema order
# first, then unknown keys in lsort order (deterministic ordering + list
# quoting give load→save byte-stability for free). Returns the path.
proc ase::state_save {path state} {
  variable schema_keys
  set lines {}
  foreach k $schema_keys {
    if {[dict exists $state $k]} {
      lappend lines "$k [list [dict get $state $k]]"
    }
  }
  set unknown {}
  dict for {k v} $state {
    if {[lsearch -exact $schema_keys $k] < 0} { lappend unknown $k }
  }
  foreach k [lsort $unknown] {
    lappend lines "$k [list [dict get $state $k]]"
  }
  set f [open $path w]
  puts $f [join $lines "\n"]
  close $f
  return $path
}

# --- Backend registry -------------------------------------------------------

# Register simulator `name` with a hooks dict providing proc names for all of
# render_deck, run_cmd, log_file, result_probe.
proc ase::register_backend {name hooks} {
  variable backends
  foreach h {render_deck run_cmd log_file result_probe} {
    if {![dict exists $hooks $h]} {
      return -code error "ase: backend '$name' missing hook '$h'"
    }
  }
  dict set backends $name $hooks
  return $name
}

# The proc implementing `hook` for simulator `sim`; clean error on unknown
# simulator / hook.
proc ase::backend_hook {sim hook} {
  variable backends
  if {![dict exists $backends $sim]} {
    return -code error "ase: unknown simulator '$sim' (registered: [lsort [dict keys $backends]])"
  }
  if {![dict exists $backends $sim $hook]} {
    return -code error "ase: unknown hook '$hook' for simulator '$sim'"
  }
  return [dict get $backends $sim $hook]
}

# --- Run directory ----------------------------------------------------------

# The run directory for a state: non-empty `rundir` -> normalized + created;
# empty -> the netlist_dir default ($USER_CONF_DIR/simulations), headless-safe
# via set_netlist_dir 0 (xschem.tcl).
proc ase::rundir {state} {
  set rd [ase::state_get $state rundir]
  if {$rd ne {}} {
    set rd [file normalize $rd]
    if {![file isdirectory $rd]} { file mkdir $rd }
    return $rd
  }
  return [set_netlist_dir 0]
}

# --- Netlist ----------------------------------------------------------------

# Netlist the state's design cellview -> <rundir>/<cell>.spice; returns the
# netlist path. The artifact stays a clean circuit netlist (deck additions
# never touch it). Context guard (never clobber an open GUI window):
#   (a) the design already IS the current schematic -> netlist in place;
#   (b) headless (no has_x) -> xschem load, then netlist;
#   (c) GUI with another schematic current -> clean error (item 03's Design
#       Window flow guarantees (a)); reloading to "restore" would destroy
#       unsaved edits, so no save/restore trickery.
proc ase::netlist {state} {
  set design [ase::state_get $state design]
  if {$design eq {}} {
    return -code error "ase: state has no design (need {lib .. cell .. view ..})"
  }
  if {![dict exists $design lib] || ![dict exists $design cell]} {
    return -code error "ase: design must provide lib and cell"
  }
  set lib  [dict get $design lib]
  set cell [dict get $design cell]
  set view schematic
  if {[dict exists $design view] && [dict get $design view] ne {}} {
    set view [dict get $design view]
  }
  set path [xschem cellview_path $lib/$cell $view]
  if {$path eq {}} {
    return -code error "ase: cannot resolve design $lib/$cell view '$view'"
  }
  set path [file normalize $path]
  if {[file normalize [xschem get schname]] ne $path} {
    if {![info exists ::has_x]} {
      xschem load $path
    } else {
      return -code error "ase: design $lib/$cell is not the current schematic;\
 open its design window first (Session > Design Window)"
    }
  }
  set rd [ase::rundir $state]
  set nl [file join $rd $cell.spice]
  file delete -force -- $nl   ;# a stale artifact must not mask a failed netlist
  xschem netlist -noalert $nl
  if {![file isfile $nl]} {
    return -code error "ase: netlist not produced: $nl"
  }
  return $nl
}

# --- Run --------------------------------------------------------------------

# Netlist + render deck -> <rundir>/<cell>_ase.spice, then batch-run the
# simulator through the `execute` infra (status 0: no viewdata popup, headless
# safe; no $terminal anywhere). Returns the execute id (use ase::wait).
# Output accumulates in execute(data,$id) and is flushed to the backend's log
# file by ase::run_done, which then parses results and finally evals the
# optional user callback at global level.
proc ase::run {state {callback {}}} {
  set sim [ase::state_get $state simulator]
  if {$sim eq {}} {
    return -code error "ase: state has no simulator"
  }
  # resolve every hook up front: clean error on an unknown simulator before
  # any netlisting / file I/O happens
  set render_deck [ase::backend_hook $sim render_deck]
  set run_cmd     [ase::backend_hook $sim run_cmd]
  set log_file    [ase::backend_hook $sim log_file]
  ase::backend_hook $sim result_probe

  set nl [ase::netlist $state]
  set f [open $nl r]
  set netlist_text [read $f]
  close $f

  set rd   [ase::rundir $state]
  set cell [dict get [dict get $state design] cell]
  set deck [$render_deck $state $netlist_text]
  set deckpath [file join $rd ${cell}_ase.spice]
  set f [open $deckpath w]
  puts -nonewline $f $deck
  close $f

  set logpath [$log_file $state]
  set cmd [$run_cmd $state $deckpath]

  set ::execute(callback) [list ase::run_done $logpath $state $callback]
  set save [pwd]
  cd $rd
  set id [eval execute 0 $cmd]   ;# simulate-proc precedent (xschem.tcl)
  cd $save
  if {$id == -1} {
    # execute already moved execute(callback) into execute(callback,<id>);
    # drop the stale copy so it can't fire on an unrelated later process
    catch {unset ::execute(callback,$::execute(id))}
    return -code error "ase: cannot start simulator '$sim' ([lindex $cmd 0] not runnable)"
  }
  return $id
}

# Completion hook (runs from execute_fileevent on EOF). execute(data,last) /
# execute(exitcode,last) are written immediately before the callback in the
# same event dispatch, so reading them here is race-free.
proc ase::run_done {logpath state callback} {
  variable last_run
  set data {}
  if {[info exists ::execute(data,last)]} { set data $::execute(data,last) }
  set exitcode -1
  if {[info exists ::execute(exitcode,last)]} { set exitcode $::execute(exitcode,last) }
  if {![catch {open $logpath w} f]} {
    puts -nonewline $f $data
    close $f
  }
  set results [dict create]
  catch {
    set sim [ase::state_get $state simulator]
    set results [[ase::backend_hook $sim result_probe] $state $data]
  }
  set last_run [dict create results $results exitcode $exitcode log $logpath]
  if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
    ciw_echo "ase: simulation finished (exit $exitcode), log: $logpath"
  }
  if {$callback ne {}} { uplevel #0 $callback }
}

# Wait for a run started by ase::run: vwait on execute(pipe,$id) (fires on the
# unset at EOF — execute_wait precedent); returns the exit code.
proc ase::wait {id} {
  if {![string is integer -strict $id] || $id < 0} { return -1 }
  if {[info exists ::execute(pipe,$id)]} {
    xschem set semaphore [expr {[xschem get semaphore] + 1}]
    vwait ::execute(pipe,$id)
    xschem set semaphore [expr {[xschem get semaphore] - 1}]
  }
  if {[info exists ::execute(exitcode,$id)]} { return $::execute(exitcode,$id) }
  return -1
}

# Results dict (output name -> parsed value) of the most recent completed run;
# empty dict if none.
proc ase::last_result {} {
  variable last_run
  if {[dict exists $last_run results]} { return [dict get $last_run results] }
  return [dict create]
}

# --- View open (P2 dispatch target) ------------------------------------------

# Open an ngspice_state* cellview (the LibMgr / hi_descend dispatch target).
# THE single Tk-guarded GUI seam of ase.tcl: every Tk call sits behind the
# has_x guard, so headless callers get path resolution + the return code with
# no Tk side effects. v0 = read-only textwindow on the .state file + a
# ciw_echo notice; item 03 replaces this BODY with the full ASE-L window — the
# name and signature `ase::open_state <lib> <cell> <view>` are the item-03
# contract, keep them stable. Returns 1 when the view resolved (viewer shown
# under X), 0 when it does not exist (no error thrown).
proc ase::open_state {lib cell view} {
  set path [xschem cellview_path $lib/$cell $view]
  if {$path eq {}} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "ase: no '$view' view for $lib/$cell" error
    }
    return 0
  }
  if {[info exists ::has_x]} {
    textwindow $path ro
    if {[info commands ::ciw_echo] ne {}} {
      ciw_echo "ase: opened $lib/$cell/$view read-only; the full ASE-L window arrives in a later phase"
    }
  }
  return 1
}

# --- ngspice backend --------------------------------------------------------

namespace eval ase::backend::ngspice {

  # Render the simulation deck: the circuit netlist minus its trailing `.end`
  # (spice_netlist.c emits it last for top-level .spice netlists), then .lib
  # models, .param variables, .options, .save outputs, one .control block from
  # the enabled analyses in fixed order (op, dc, ac, tran) + a print per saved
  # output for log-based result probing, then .end + trailing newline.
  proc render_deck {state netlist_text} {
    set lines [split [string trimright $netlist_text "\n"] "\n"]
    while {[llength $lines] > 0 && [string trim [lindex $lines end]] eq {}} {
      set lines [lrange $lines 0 end-1]
    }
    if {[llength $lines] > 0 && [string trim [lindex $lines end]] eq ".end"} {
      set lines [lrange $lines 0 end-1]
    }
    foreach m [ase::state_get $state models] {
      lappend lines ".lib [dict get $m file] [dict get $m section]"
    }
    foreach v [ase::state_get $state variables] {
      lappend lines ".param [dict get $v name]=[dict get $v value]"
    }
    foreach o [ase::state_get $state options] {
      set val 1
      if {[dict exists $o value]} { set val [dict get $o value] }
      if {$val eq {0}} { continue }
      if {$val eq {1}} {
        lappend lines ".options [dict get $o name]"
      } else {
        lappend lines ".options [dict get $o name]=$val"
      }
    }
    foreach o [ase::state_get $state outputs] {
      if {[ase::state_get $o save 0] eq {1}} {
        lappend lines ".save [dict get $o expr]"
      }
    }
    lappend lines ".control"
    foreach type {op dc ac tran} {
      foreach a [ase::state_get $state analyses] {
        if {[ase::state_get $a type] ne $type} { continue }
        if {[ase::state_get $a enabled 0] ne {1}} { continue }
        switch -- $type {
          op   { lappend lines "op" }
          dc   { lappend lines "dc [dict get $a source] [dict get $a start]\
 [dict get $a stop] [dict get $a step]" }
          ac   { lappend lines "ac dec [dict get $a points] [dict get $a start]\
 [dict get $a stop]" }
          tran { lappend lines "tran [dict get $a step] [dict get $a stop]" }
        }
      }
    }
    foreach o [ase::state_get $state outputs] {
      if {[ase::state_get $o save 0] eq {1}} {
        lappend lines "print [dict get $o expr]"
      }
    }
    lappend lines ".endc"
    lappend lines ".end"
    return "[join $lines "\n"]\n"
  }

  # Batch invocation arg list. 2>@1 folds stderr warnings into the captured
  # log; stdout must flow into execute(data,$id), so no -o here.
  proc run_cmd {state deckpath} {
    return [list ngspice -b $deckpath 2>@1]
  }

  # <rundir>/<cell>_ase.log
  proc log_file {state} {
    if {![dict exists $state design cell]} {
      return -code error "ase: state design has no cell (log_file)"
    }
    set cell [dict get $state design cell]
    return [file join [ase::rundir $state] ${cell}_ase.log]
  }

  # Parse `<expr> = <float>` lines out of the log text (e.g.
  # `-i(v1) = 4.096837e-04`) -> dict output-name -> value, for every state
  # output whose line appears.
  proc result_probe {state logtext} {
    set results [dict create]
    foreach o [ase::state_get $state outputs] {
      if {![dict exists $o name] || ![dict exists $o expr]} { continue }
      regsub -all {\W} [dict get $o expr] {\\&} esc
      set pat [format {^\s*%s\s*=\s*([-+]?[0-9.]+(?:[eE][-+]?[0-9]+)?)\s*$} $esc]
      if {[regexp -line $pat $logtext -> val]} {
        dict set results [dict get $o name] $val
      }
    }
    return $results
  }

  # Register at source time. Kept inside this namespace eval so the only
  # ngspice literals outside ase::backend::ngspice stay the state_default
  # schema defaults.
  ::ase::register_backend ngspice [dict create \
    render_deck  ::ase::backend::ngspice::render_deck \
    run_cmd      ::ase::backend::ngspice::run_cmd \
    log_file     ::ase::backend::ngspice::log_file \
    result_probe ::ase::backend::ngspice::result_probe]
}
