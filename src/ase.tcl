# ase.tcl — ASE-L (Analog Simulation Environment) core: state-file I/O,
# per-simulator backend registry, deck rendering, headless-safe netlist +
# batch simulation run via the `execute` infra, result parsing.
#
# P1+P2+P3 of doc/claude/specs/ase_l.md. Pure Tcl, NO Tk anywhere in this file
# — everything must run under --nogui (tests/headless/test_ase_core.tcl runs
# this file's procs true-headless) — with ONE carve-out: ase::open_state is the
# single Tk-GUARDED GUI seam: under has_x it delegates to the ase::ui widget
# layer (src/ase_window.tcl, the ASE-L session window); headless it does only
# session-model bookkeeping and stays Tk-free. All procs' names are contracts.
#
# State = a single Tcl-dict text file per ngspice_state* view, one `key value`
# per line (see "State file schema" in the spec). Loading merges over
# ase::state_default; unknown keys are PRESERVED (forward compatibility).
# Saving writes canonical schema order then unknown keys sorted, `list`-quoted,
# so a load→save round trip of any state_save-produced file is byte-stable.
#
# Backend seam: ase::backends maps simulator name -> hook dict
# {render_deck run_cmd log_file result_probe raw_file} (proc names). v1
# registers `ngspice` only; the only ngspice literals outside the
# ase::backend::ngspice namespace are the state_default schema defaults.

namespace eval ase {
  # canonical state-file key order (the spec's v1 schema + the UI v2
  # `temperature` session scalar, grouped with the other scalars, and the UI v2
  # blanket-save flags `save_all_v`/`save_all_i`, grouped with outputs whose
  # saving semantics they modify; deck mapping allv -> `.save all`, alli ->
  # `.options savecurrents` in the ngspice render_deck; `viewer` = the item-14
  # waveform-viewer persistence dict, doc/claude/specs/waveform_viewer.md)
  # `pre_commands` sits beside `includes` because it is the same kind of thing —
  # deck preamble the state owns — but it renders INSIDE the .control block:
  # ngspice's `pre_*` family (`pre_osdi <file>.osdi`, `pre_set`, …) runs before
  # the netlist is parsed, which is the only way to load a compiled Verilog-A
  # module; there is no `.osdi` dot-card. IHP SG13G2 needs four of them for its
  # psp103va/mosvar/r3_cmc models (ihp-sg13g2/cadence_style_rc:40-49).
  variable schema_keys {version simulator design rundir temperature models
                        variables analyses outputs save_all_v save_all_i
                        options includes pre_commands viewer}
  # simulator name -> hooks dict {render_deck run_cmd log_file result_probe}
  variable backends [dict create]
  # most recent completed run: {results <dict> exitcode <n> log <path> }
  variable last_run [dict create]
  # session registry (item 03): key ("lib/cell/view") -> entry dict
  # {path <file> state <dict> saved <dict> ...attrs}. Pure dict, headless-safe.
  variable sessions [dict create]
  # untitled-launch synthetic view label (Tools > Launch ASE-L): a real state
  # view is always ngspice_stateN, so this never collides with a LibMgr open.
  variable untitled_view {(unsaved)}
  # notify seam: command prefix invoked with the session key after every
  # session_update/save/load/revert. Default {} (headless: nothing runs);
  # ase::ui (ase_window.tcl) points it at its title-refresh handler.
  variable session_notify {}
}

# --- the user-visible-message seam (issue 0207) ------------------------------
# ASE's notices used to be bare `ciw_echo` calls. `ciw_echo` (src/ciw.tcl) is a
# pure Tk widget append: the CIW pane is the action log's MIRROR (C log_action()
# writes Xschem.log, then mirrors into the pane via log_action_echo), so writing
# to the pane put 66 user-visible ASE messages (10 here + 56 in ase_window.tcl) in
# the mirror of a file they were never in. Route them through here and they land in BOTH.
#
# D1 (issue 0207): a SEAM, not a tee inside ciw_echo. ciw_echo is also the sink
# log_action_echo() calls for lines that are ALREADY in the file, so teeing there
# would double-write every action line unless guarded for re-entrancy.
# Mirrors wviewer::log_action (src/wave_viewer.tcl) and the "both places" idiom
# at src/action_registry.tcl:199-200.
#
# D2: the file half goes through `xschem log_action -result|-error`, i.e.
# log_output() in src/util.c -> `#= ` / `#! ` COMMENT lines, keyed off the same
# pane tag the call site already passes. Comments keep the log source-able (its
# invariant, doc/claude/specs/action_logging.md), and log_output prefixes every
# embedded newline -- which a hand-built `# ase: $msg` line would not, so a
# multi-line message would become live Tcl on replay.
#
# D3: BOTH halves are catch'd here, so a broken message can never break a pick,
# whether or not the call site kept its own catch.
# D4: correct with no Tk and with logging off (log_output no-ops on a NULL
# actionlog_fp), and with both. MEASURED, and it corrected an assumption: ciw.tcl
# IS sourced under --nogui, so `::ciw_echo` exists there and self-no-ops on its
# own `winfo`/`.ciw.l.t` check -- the thing that used to suppress ASE's notices
# headless was the call sites' `[info exists ::has_x]` guard ($::has_x is UNSET
# under --nogui), not the command's absence. Those guards are gone: the pane half
# stays a no-op headless, the file half now runs, which is what makes this
# testable under `--nogui --logdir`. The existence check is a cheap belt: ciw.tcl is
# sourced 37 lines AFTER this file (xschem.tcl:14273 vs 14312), so a future SOURCE-TIME
# ASE notice would otherwise lose its pane half silently.
# It is also the rename-able spy point ASE's tests stub -- they stub ::ciw_echo,
# which this resolves by NAME at call time, so they still intercept. Measured: 5
# ase::echo calls produce exactly 5 ::ciw_echo calls, which is what keeps the
# exact-count assertions in test_ase_locked_wire_pick_0160 / test_sod_pick_no_select_0204
# green -- a tee inside ciw_echo would have doubled them.
#
# Call it as `::ase::echo`, absolutely qualified. The 56 sites in ase_window.tcl run
# inside `namespace eval ase::ui`, where the relative name `ase::echo` resolves against
# the CURRENT namespace first -- a future `ase::ui::ase` namespace would silently hijack
# every one of them, and the tests' ::ciw_echo stubs would not notice.
#
# Two replay landmines, both guarded here:
#  - `xschem log_action -result` with a MISSING value fell through the dispatcher's
#    argc>3 gates to the bare-line arm and wrote the literal line `-result` into
#    Xschem.log, aborting a replay `source`. Many call sites pass a variable that
#    can legitimately be empty, so: an empty message logs NOTHING. (The C side is
#    now a backstop too -- see the log_action arm in src/scheduler.c.)
#  - a Tcl comment whose line ends in a BACKSLASH continues onto the next line, so a
#    message ending in `\` would swallow the FOLLOWING log line on replay. Measured:
#    `#= foo\` + newline + `puts X` never runs `puts X`. An EMBEDDED backslash-newline
#    is harmless (it just extends the comment over the next `#= ` continuation line,
#    which is already comment text) -- but a TRAILING one is not, and it hides behind a
#    trailing newline too: log_output() emits no prefix after the last newline, so
#    "foo\\\n" also lands as `#= foo\`. Hence trimright BEFORE the test. The pad goes on
#    the logged copy only; the pane copy stays byte-identical to before.
#    No format gate catches this: test_selflog_output's source-ability leg accumulates
#    with `info complete`, which treats a leading `#` as a comment and returns 1 even
#    for a trailing backslash. Only test_ase_log_seam_0207's PS12 sees it.
proc ase::echo {msg {tag {}}} {
  # pane half first, unconditionally and unchanged: the tests that capture ASE
  # notices rename ::ciw_echo, and an empty message still echoed a blank line.
  if {[info commands ::ciw_echo] ne {}} { catch {::ciw_echo $msg $tag} }
  if {$msg eq {}} return
  set msg [string trimright $msg "\n"]            ;# log_output supplies the terminator
  if {$msg eq {}} return
  if {[string index $msg end] eq "\\"} { append msg { } }
  if {$tag eq {error}} { catch {xschem log_action -error $msg} } \
  else                 { catch {xschem log_action -result $msg} }
}

# dict get with a default (states are open dicts: keys may be absent).
proc ase::state_get {state key {dflt {}}} {
  if {[dict exists $state $key]} { return [dict get $state $key] }
  return $dflt
}

# Expand Tcl variable references in a path coming from a state file (model
# files store the portable form `$::SKYWATER_MODELS/sky130.lib.spice` — the
# workarea rc sets the variable; a literal absolute path would break other
# checkouts). Variables-ONLY: no command execution from state files
# (-nocommands) and backslashes are kept verbatim for Windows paths
# (-nobackslashes). Substitutes at global level so unqualified names resolve
# like the rc wrote them. Clean error when a referenced variable is unset.
proc ase::expand_path {p} {
  if {[catch {uplevel #0 [list subst -nocommands -nobackslashes $p]} out]} {
    return -code error "ase: cannot expand model path '$p': $out"
  }
  return $out
}

# --- Display formatting (UI v2 item 09) -------------------------------------

# Engineering-notation display for the Variables/Outputs pane Value columns:
# exponent a multiple of 3, SPICE SI suffix (f p n u m k Meg G T), ~4
# significant digits with trailing zeros trimmed (1.04e-4 -> 104u,
# 4.096837e-4 -> 409.7u). Display-ONLY — state files and the edit dialogs
# always carry raw values; only pane-render call sites (ase_window.tcl) wrap
# through here. Gated by the global ase_eng_notation (rc may preset; 0 ->
# the stored value is returned verbatim, i.e. the plain %g/scientific form
# it was entered/parsed as). |v| >= 1e15 or nonzero |v| < 1e-18 falls back
# to %g; non-numeric input (expressions, blanks) is returned verbatim.
set_ne ase_eng_notation 1

proc ase::format_value {v} {
  if {![string is double -strict $v]} { return $v }
  if {![info exists ::ase_eng_notation] || !$::ase_eng_notation} { return $v }
  # Inf/NaN (accepted by `string is double`) error out of the numeric arm ->
  # verbatim. NOTE the helper call: a `return` INSIDE this catch body would
  # read as TCL_RETURN (caught!) and silently fall back for every input.
  if {[catch {ase::format_value_num $v} out]} { return $v }
  return $out
}

# Numeric arm of ase::format_value (kept separate — see the catch note above).
proc ase::format_value_num {v} {
  set d [expr {double($v)}]
  if {$d == 0} { return 0 }
  set sign {}
  set a [expr {abs($d)}]
  if {$d < 0} { set sign - }
  if {$a >= 1e15 || $a < 1e-18} { return [format %g $d] }
  set e3 [expr {int(floor(log10($a)/3.0)*3)}]
  # clamp into the suffix range: [1e-18,1e-15) renders with a fractional
  # mantissa on `f` (5e-16 -> 0.5f); nothing above needs the top clamp but
  # it keeps the table lookup total
  if {$e3 < -15} { set e3 -15 }
  if {$e3 > 12}  { set e3 12 }
  set m [expr {$a / pow(10.0,$e3)}]
  set ms [format %.4g $m]
  # rounding can carry the mantissa to 1000 (999.96e-6): roll to the next
  # suffix instead of printing a 4-digit mantissa
  if {$ms == 1000 && $e3 < 12} { set e3 [expr {$e3 + 3}]; set ms 1 }
  set sfx [dict create -15 f -12 p -9 n -6 u -3 m 0 {} 3 k 6 Meg 9 G 12 T]
  return $sign$ms[dict get $sfx $e3]
}

# --- State I/O --------------------------------------------------------------

# Per-technology ASE default models: a list of {file <portable-path> section
# <sec>} dicts a fresh session/state view inherits (empty in stock xschem; a
# workarea rc sets it — sky130A: sky130.lib.spice tt; gf180mcuD: sm141064
# typical). set_ne so an rc value set before ase.tcl is sourced survives.
set_ne ASE_DEFAULT_MODELS {}

# Same, but for `.include` files (not `.lib` sections) a fresh session/state view
# inherits — e.g. gf180mcuD's design.ngspice global-switch .params that the model
# subckts reference. Each entry is a {file <path>} dict. set_ne so an rc value set
# before ase.tcl is sourced survives.
set_ne ASE_DEFAULT_INCLUDES {}

# The v1 default state (spec "State file schema"). `simulator ngspice` here is
# the one permitted ngspice literal outside the backend namespace.
proc ase::state_default {} {
  return [dict create \
    version   1 \
    simulator ngspice \
    design    {} \
    rundir    {} \
    temperature 27 \
    models    [expr {[info exists ::ASE_DEFAULT_MODELS] ? $::ASE_DEFAULT_MODELS : {}}] \
    variables {} \
    analyses  {{type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 0}} \
    outputs   {} \
    save_all_v 0 \
    save_all_i 0 \
    options   {} \
    includes  [expr {[info exists ::ASE_DEFAULT_INCLUDES] ? $::ASE_DEFAULT_INCLUDES : {}}] \
    pre_commands [expr {[info exists ::ASE_DEFAULT_PRE_COMMANDS] ?
                        $::ASE_DEFAULT_PRE_COMMANDS : {}}] \
    viewer    {}]
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
  set st [dict merge [ase::state_default] [dict create {*}$content]]
  # issue 0159 migration: a state saved before the bit dialog can carry one
  # output row whose expr is a whole bus -- `v(a[1:0])` -- which is not a valid
  # ngspice vector and, if it is the only `.save` in the deck, aborts the run.
  # Expand such a row per bit on load (user decision). Idempotent: an expanded
  # row is scalar and expands to itself.
  #
  # `catch`ed on purpose, and it is not hiding a bug: opening a session must
  # never FAIL because a cosmetic migration tripped over an odd stored row (a
  # row that is not a dict, say). The failure mode of the catch is "no
  # migration ran", which is exactly the pre-fix behavior — the outputs list is
  # left byte-identical to the file. `bus_expr_bits` already catches
  # `expandlabel` itself, so this only fires on a malformed outputs list.
  catch {dict set st outputs [ase::expand_bus_outputs [ase::state_get $st outputs]]}
  return $st
}

# The per-bit expressions a bus output expr stands for, or {} if it is not one.
# Only used by the load-time migration, and deliberately much narrower than
# `ase::ui::sod_bits`, because here the string is OPAQUE: a picked token came
# from the schematic and is known to be a net, but a stored expr may have been
# typed by hand in the Add-Output dialog.
#
# Two guards:
#  * only a bare `v(<label>)` is a candidate, so a DERIVED expression
#    (`v(a)-v(b)`, an RPN row, anything with an operator or a nested paren) is
#    never rewritten. `i(...)` is an instance name and can never be a bus.
#  * the label must carry an explicit `[n:m]` RANGE. The comma form is
#    deliberately left alone even though a comma-bus PICK produces it, because
#    `v(a,b)` is also ngspice's DIFFERENTIAL voltage and `print v(a,b)` is a
#    real thing a user can have typed into the Add-Output dialog; expanding it
#    would silently destroy their row. Giving that case up costs nothing
#    measurable: unlike the bracket form, `.save v(d,e)` does NOT abort the run
#    (measured, ngspice-42 — it saves v(d) and v(e)), so a legacy comma row is
#    the benign half of issue 0159.
proc ase::bus_expr_bits {ex} {
  if {![regexp {^v\(([^()]+)\)$} $ex -> inner]} { return {} }
  if {[regexp {[+*/ ]} $inner]} { return {} }
  if {![regexp {\[[^\]]*:[^\]]*\]} $inner]} { return {} }
  set r {}
  if {[catch {xschem expandlabel $inner} r]} { return {} }
  set exp [lindex $r 0]
  if {$exp eq {} || [string first , $exp] < 0} { return {} }
  set out {}
  foreach b [split $exp ,] { lappend out "v($b)" }
  return $out
}

# Rewrite an outputs list, expanding any bus row into one row per bit and
# keeping every other field (name, plot/save flags) as it was. Row order is
# preserved, with the expanded rows sitting where the bus row was.
proc ase::expand_bus_outputs {outputs} {
  set out {}
  foreach o $outputs {
    set ex {}
    catch {set ex [dict get $o expr]}
    set bits [ase::bus_expr_bits $ex]
    if {[llength $bits] < 2} { lappend out $o ; continue }
    foreach b $bits {
      set row $o
      dict set row expr $b
      lappend out $row
    }
  }
  return $out
}

# Canonical text form of a state dict: one `key [list value]` per line,
# canonical schema order first, then unknown keys in lsort order (deterministic
# ordering + list quoting give load→save byte-stability for free). This is
# ALSO the session dirty-compare form: two states are "equal" iff their
# serializations match byte-for-byte.
proc ase::state_serialize {state} {
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
  return [join $lines "\n"]
}

# Save a state dict in the canonical serialized form. Returns the path.
proc ase::state_save {path state} {
  set f [open $path w]
  puts $f [ase::state_serialize $state]
  close $f
  return $path
}

# --- Backend registry -------------------------------------------------------

# Register simulator `name` with a hooks dict providing proc names for all of
# render_deck, run_cmd, log_file, result_probe, raw_file.
proc ase::register_backend {name hooks} {
  variable backends
  foreach h {render_deck run_cmd log_file result_probe raw_file} {
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

# Registered simulator names, sorted (the ASE window's simulator combobox).
proc ase::backend_names {} {
  variable backends
  return [lsort [dict keys $backends]]
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

# Netlist + run: regenerate the circuit netlist artifact, then hand off to
# ase::run_deck (the shared post-netlist body). Every hook is resolved up
# front so an unknown simulator errors before any netlisting / file I/O.
# Returns the execute id (use ase::wait).
proc ase::run {state {callback {}}} {
  set sim [ase::state_get $state simulator]
  if {$sim eq {}} {
    return -code error "ase: state has no simulator"
  }
  foreach h {render_deck run_cmd log_file result_probe} {
    ase::backend_hook $sim $h
  }
  set nl [ase::netlist $state]
  return [ase::run_deck $state $nl $callback]
}

# Run on the EXISTING netlist artifact <rundir>/<cell>.spice (ADE-L "Run":
# applies the state's current analyses/outputs but does NOT re-netlist, so
# hand-edits to the circuit netlist survive; needs no current-schematic guard
# because no netlisting happens — works with the design window closed).
# Clean error when the artifact is absent.
proc ase::run_existing {state {callback {}}} {
  set sim [ase::state_get $state simulator]
  if {$sim eq {}} {
    return -code error "ase: state has no simulator"
  }
  foreach h {render_deck run_cmd log_file result_probe} {
    ase::backend_hook $sim $h
  }
  set design [ase::state_get $state design]
  if {$design eq {} || ![dict exists $design cell]} {
    return -code error "ase: state has no design cell"
  }
  set nl [file join [ase::rundir $state] [dict get $design cell].spice]
  if {![file isfile $nl]} {
    return -code error "ase: no netlist artifact: $nl (run Simulation >\
 Netlist > Recreate first)"
  }
  return [ase::run_deck $state $nl $callback]
}

# The shared post-netlist run body: render deck from `netlistfile` ->
# <rundir>/<cell>_ase.spice, then batch-run the simulator through the
# `execute` infra (status 0: no viewdata popup, headless safe; no $terminal
# anywhere). Returns the execute id (use ase::wait). Output accumulates in
# execute(data,$id) and is flushed to the backend's log file by ase::run_done,
# which then parses results and finally evals the optional user callback at
# global level.
proc ase::run_deck {state netlistfile {callback {}}} {
  set sim [ase::state_get $state simulator]
  if {$sim eq {}} {
    return -code error "ase: state has no simulator"
  }
  set render_deck [ase::backend_hook $sim render_deck]
  set run_cmd     [ase::backend_hook $sim run_cmd]
  set log_file    [ase::backend_hook $sim log_file]
  ase::backend_hook $sim result_probe

  set f [open $netlistfile r]
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
  ::ase::echo "ase: simulation finished (exit $exitcode), log: $logpath"
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

# --- Waveform-viewer seams (item 13) -----------------------------------------

# The `xschem raw read` type argument (and the op-only "nothing plottable"
# gate) for a state's results: the LAST enabled analysis type in the FIXED
# emit order op dc ac tran ({} when none is enabled). COUPLING: the ngspice
# render_deck emits the enabled analyses into one .control block in exactly
# this order, so when the trailing `write` executes, ngspice's CURRENT plot
# (the one the raw file carries) belongs to the FINAL analysis — this proc
# must mirror render_deck's emit order forever.
proc ase::plot_sim_type {state} {
  set out {}
  foreach type {op dc ac tran} {
    foreach a [ase::state_get $state analyses] {
      if {[ase::state_get $a type] ne $type} { continue }
      if {[ase::state_get $a enabled 0] ne {1}} { continue }
      set out $type
    }
  }
  return $out
}

# The raw-file artifact of session `key` when it has results: {} for an
# unknown session, else the backend raw_file path — returned ONLY when the
# file exists ({} otherwise). The path is deterministic per rundir/cell and
# runs overwrite it in place, so file existence == "this session has
# simulation results"; it also lets a fresh xschem session attach a PREVIOUS
# run's raw (the waveform_viewer.md saved-results seam).
proc ase::last_rawfile {key} {
  set state [ase::session_state $key]
  if {$state eq {}} { return {} }
  set sim [ase::state_get $state simulator]
  if {[catch {[ase::backend_hook $sim raw_file] $state} rf]} { return {} }
  if {$rf ne {} && [file isfile $rf]} { return $rf }
  return {}
}

# --- Session model (item 03) --------------------------------------------------
# Headless-testable bookkeeping behind the ASE-L window: one session per state
# view, keyed "lib/cell/view". An entry holds the state file path, the CURRENT
# state dict (what the window edits) and the SAVED state dict (last disk
# content); dirty = the two serialize differently. The GUI layer never touches
# `sessions` directly — it goes through these procs, so every leg runs headless.

# The canonical session key for a state view.
proc ase::session_key {lib cell view} {
  return "$lib/$cell/$view"
}

# Fire the notify seam (session_update/save/load/revert). Guarded: a broken
# GUI hook must never abort the session mutation that already happened.
proc ase::session_notify_fire {key} {
  variable session_notify
  if {$session_notify ne {}} {
    catch {uplevel #0 [concat $session_notify [list $key]]}
  }
  return {}
}

# Register (or re-open) a session on state file `path`. First open loads the
# file; a re-open refreshes from disk only when the session is NOT dirty (a
# dirty session keeps its in-memory edits — re-open just raises the window).
# Returns the key.
proc ase::session_open {key path} {
  variable sessions
  if {[dict exists $sessions $key] && [ase::session_dirty $key]} {
    dict set sessions $key path $path
    return $key
  }
  set st [ase::state_load $path]
  dict set sessions $key [dict create path $path state $st saved $st]
  return $key
}

# The session's state file path ({} if the key is unknown).
proc ase::session_path {key} {
  variable sessions
  if {[dict exists $sessions $key path]} { return [dict get $sessions $key path] }
  return {}
}

# The session's CURRENT state dict ({} if the key is unknown).
proc ase::session_state {key} {
  variable sessions
  if {[dict exists $sessions $key state]} { return [dict get $sessions $key state] }
  return {}
}

# Replace the session's current state (the ONE write path the GUI panes use).
# Returns 1, or 0 for an unknown key.
proc ase::session_update {key newstate} {
  variable sessions
  if {![dict exists $sessions $key]} { return 0 }
  dict set sessions $key state $newstate
  ase::session_notify_fire $key
  return 1
}

# 1 when the current state differs from the last-saved one (canonical
# serialization compare), else 0.
proc ase::session_dirty {key} {
  variable sessions
  if {![dict exists $sessions $key]} { return 0 }
  set s [dict get $sessions $key]
  return [expr {[ase::state_serialize [dict get $s state]] ne
                [ase::state_serialize [dict get $s saved]]}]
}

# Write the current state to the session's file (Session > Save State);
# saved <- state. Returns 1, or 0 for an unknown key.
proc ase::session_save {key} {
  variable sessions
  if {![dict exists $sessions $key]} { return 0 }
  set s [dict get $sessions $key]
  ase::state_save [dict get $s path] [dict get $s state]
  dict set sessions $key saved [dict get $s state]
  ase::session_notify_fire $key
  return 1
}

# First Save-As of a never-saved (untitled Launch) session: adopt `newpath` as
# the session's real identity (classic Save-As on an untitled document). saved
# <- current state so ase::session_dirty -> 0; the `untitled` attr is cleared so
# refresh_title drops " (unsaved)" (and " *"); notify fires (title + status
# refresh). The CALLER must have ALREADY written `state` to `newpath`
# (do_save_state_as does), so saved matches disk. TITLED sessions (own path
# already set) must NOT call this — their deliberate "save-as to a DIFFERENT
# view stays dirty" behavior (item 14 D5) depends on saved being left alone.
# The session KEY is deliberately NOT re-homed (it is an opaque handle: ~91
# build() bindings + WM_DELETE/Ctrl-W bake it in; Launch dedup keys on
# state.design, not the key). Returns 1, or 0 for an unknown key.
proc ase::session_adopt {key newpath} {
  variable sessions
  if {![dict exists $sessions $key]} { return 0 }
  dict set sessions $key path $newpath
  dict set sessions $key saved [dict get $sessions $key state]
  dict set sessions $key untitled 0
  ase::session_notify_fire $key
  return 1
}

# Re-read the state file from disk (Session > Load State); saved <- state <-
# file, discarding in-memory edits. Returns 1, or 0 for an unknown key.
proc ase::session_load {key} {
  variable sessions
  if {![dict exists $sessions $key]} { return 0 }
  set st [ase::state_load [dict get $sessions $key path]]
  dict set sessions $key state $st
  dict set sessions $key saved $st
  ase::session_notify_fire $key
  return 1
}

# Discard in-memory edits: state <- saved (Session > Revert). Returns 1, or 0
# for an unknown key.
proc ase::session_revert {key} {
  variable sessions
  if {![dict exists $sessions $key]} { return 0 }
  dict set sessions $key state [dict get $sessions $key saved]
  ase::session_notify_fire $key
  return 1
}

# Unregister a session (window close). Unknown keys are a no-op.
proc ase::session_close {key} {
  variable sessions
  if {[dict exists $sessions $key]} { dict unset sessions $key }
  return 1
}

# Extra per-session attributes (e.g. the GUI's live run_id). Stored on the
# session entry beside path/state/saved — those three names are reserved.
proc ase::session_setattr {key name value} {
  variable sessions
  if {![dict exists $sessions $key]} { return 0 }
  dict set sessions $key $name $value
  return 1
}
proc ase::session_getattr {key name {dflt {}}} {
  variable sessions
  if {[dict exists $sessions $key $name]} { return [dict get $sessions $key $name] }
  return $dflt
}

# --- View open (P2 dispatch target) ------------------------------------------

# Open an ngspice_state* cellview (the LibMgr / hi_descend dispatch target).
# THE single Tk-guarded GUI seam of ase.tcl: every Tk call sits behind the
# has_x guard, so headless callers get path resolution + session registration
# (pure dict) + the return code with no Tk side effects. Under X this opens
# the ASE-L session window (ase::ui, src/ase_window.tcl) — ONE toplevel per
# state view; re-opening an already-open session just raises its window (no
# new window number is consumed). The name and the 3-arg call shape
# `ase::open_state <lib> <cell> <view>` are a stable contract; the TRAILING
# OPTIONAL `ro` flag (item 07 D7) records whether this open was read-only in
# the session attr `readonly` — EVERY open sets it (last open wins, so a
# later plain open upgrades the session to editable). v1 scope: the flag
# gates only the Save-As overwrite confirmation (no edit blocking). Returns
# 1 when the view resolved, 0 when it does not exist or its state file does
# not load (no error thrown).
proc ase::open_state {lib cell view {ro 0}} {
  set path [xschem cellview_path $lib/$cell $view]
  if {$path eq {}} {
    ::ase::echo "ase: no '$view' view for $lib/$cell" error
    return 0
  }
  set key [ase::session_key $lib $cell $view]
  if {[catch {ase::session_open $key $path} err]} {
    # view exists but its state file is unloadable: clean report, no throw
    ::ase::echo $err error
    return 0
  }
  # D7: both the fresh-open and the raise arm pass through here, so every
  # successful open records the flag
  ase::session_setattr $key readonly $ro
  if {![info exists ::has_x]} { return 1 }
  set w [ase::ui::window_for $key]
  if {$w ne {} && [winfo exists $w]} {
    catch {wm deiconify $w}
    catch {raise $w}
    catch {focus $w}
    return 1
  }
  ase::ui::open $key $lib $cell $view
  return 1
}

# --- Launch ASE-L for the current schematic (Tools > Launch ASE-L) -----------

# Reverse an absolute cellview datafile path to {lib cell view}, or throw a
# clean error. ASE simulates SCHEMATIC designs only: any non-.sch current view
# (symbol/state/…) is refused up front (the create_instance.tcl *.sym idiom).
# Reuses schematic_cellview (library_defs.tcl) for the library-root matching;
# a flat-library hit (view {}) defaults to the schematic view.
proc ase::design_of_path {abspath} {
  if {$abspath eq {}} {
    return -code error "ase: no current design (empty schematic path)"
  }
  if {[string tolower [file extension $abspath]] ne {.sch}} {
    return -code error "ase: current view is not a schematic\
 (ASE simulates schematic designs)"
  }
  set r [schematic_cellview $abspath]
  if {$r eq {}} {
    return -code error "ase: '$abspath' is not under a registered library"
  }
  lassign $r lib cell view layout
  if {$view eq {}} { set view schematic }
  return [list $lib $cell $view]
}

# {lib cell view} of the CURRENT schematic, or {} after an ase::echo'd honest
# error (symbol view / unsaved / outside every library).
proc ase::design_of_current {} {
  set p {}
  catch {set p [file normalize [xschem get schname]]}
  if {[catch {ase::design_of_path $p} r]} {
    catch {::ase::echo $r error}
    return {}
  }
  return $r
}

# The session key (if any) whose state.design targets {lib cell view}. Used by
# Launch to RAISE rather than duplicate a session already on this design.
proc ase::session_for_design {lib cell view} {
  variable sessions
  dict for {k entry} $sessions {
    set d [ase::state_get [dict get $entry state] design]
    if {[dict exists $d lib]  && [dict get $d lib]  eq $lib  \
     && [dict exists $d cell] && [dict get $d cell] eq $cell \
     && [dict exists $d view] && [dict get $d view] eq $view} {
      return $k
    }
  }
  return {}
}

# The ASE-L session bound to the current schematic OR to any of its ANCESTORS in
# the hierarchy stack (issue 0168). Returns {key level lib cell view}, or {}.
#
# The whole point of the walk: after a run the user DESCENDS into an instance to
# probe its internals, and the descended cell has no session of its own -- the
# session that ran the simulation is one (or five) levels up. `design_of_current`
# only ever sees `xschem get schname`, i.e. the CHILD, so every descended Ctrl-4 /
# Results > Direct Plot died on "no ASE-L session for this design" with the right
# session sitting in the stack above it.
#
# NEAREST ancestor wins, not the top: a session bound to an intermediate cell
# simulates THAT cell as its deck's top, so node names for a pick below it must be
# measured from there (`level` is exactly that measuring stick -- see
# ase::ui::sod_base_level, which recomputes it from the session side). With the
# usual single session on the top design both rules agree.
#
# A level that resolves to no registered cellview (a child from outside every
# library) is SKIPPED, not fatal -- it is a perfectly ordinary thing to descend
# into, and its parent may still hold the session. All errors are swallowed here
# on purpose; ase::no_session_notice does the one honest report at the end.
proc ase::session_for_current {} {
  set lvl 0
  catch {set lvl [xschem get currsch]}
  if {![string is integer -strict $lvl] || $lvl < 0} { set lvl 0 }
  for {set l $lvl} {$l >= 0} {incr l -1} {
    set p {}
    catch {set p [xschem get schname $l]}
    if {$p eq {}} { continue }
    if {[catch {ase::design_of_path [file normalize $p]} d]} { continue }
    lassign $d lib cell view
    set key [ase::session_for_design $lib $cell $view]
    if {$key ne {}} { return [list $key $l $lib $cell $view] }
  }
  return {}
}

# The single honest report for "session_for_current found nothing", shared by all
# its callers (issue 0168). Two distinct failures, two distinct messages:
#   - NO level of the stack resolves to a schematic design (a symbol view, an
#     unsaved buffer, a hierarchy entirely outside every library): re-raise
#     design_of_path's own wording for the current view, exactly as
#     design_of_current always did;
#   - some level does resolve but none owns a session: say so, and say that the
#     parents were searched too, so a descended user is not left thinking the
#     parent's session was ignored.
proc ase::no_session_notice {} {
  # (issue 0207) no `[info commands ::ciw_echo] eq {}` early return any more: the
  # notice now goes to the action log as well as the pane, and the log exists
  # under --nogui, where ciw_echo does not. ase::echo self-guards on the pane half.
  set lvl 0
  catch {set lvl [xschem get currsch]}
  if {![string is integer -strict $lvl] || $lvl < 0} { set lvl 0 }
  set resolved 0
  for {set l $lvl} {$l >= 0} {incr l -1} {
    set p {}
    catch {set p [xschem get schname $l]}
    if {$p ne {} && ![catch {ase::design_of_path [file normalize $p]}]} {
      set resolved 1
      break
    }
  }
  if {!$resolved} {
    set p {}
    catch {set p [file normalize [xschem get schname]]}
    if {[catch {ase::design_of_path $p} r]} { catch {::ase::echo $r error} }
    return
  }
  if {$lvl > 0} {
    catch {::ase::echo "ase: no ASE-L session for this design nor for any of its\
 $lvl parent level(s) -- Launch ASE-L (Tools menu) or open its ngspice_state\
 view first" error}
  } else {
    catch {::ase::echo "ase: no ASE-L session for this design -- Launch ASE-L\
 (Tools menu) or open its ngspice_state view first" error}
  }
}

# Register a BLANK untitled session bound to design {lib cell schview} (Tools >
# Launch ASE-L). Distinct from session_open (which loads a .state file): NO file
# on disk (path {}), state = state_default (already carrying ::ASE_DEFAULT_MODELS
# + empty vars/outputs) with design pointing at the schematic view; saved ==
# state so the session is NOT dirty until edited (item-16's close-prompt will not
# fire on an untouched launch). Key/meta view = the synthetic untitled_view;
# saveview seeds the Save-As View prefill. Returns the session key.
proc ase::new_session {lib cell schview} {
  variable sessions
  variable untitled_view
  set key [ase::session_key $lib $cell $untitled_view]
  set st [ase::state_default]
  dict set st design [list lib $lib cell $cell view $schview]
  dict set sessions $key [dict create path {} state $st saved $st \
    untitled 1 metaview $untitled_view saveview ngspice_state1]
  return $key
}

# Tools > Launch ASE-L: open a FRESH untitled ASE session for the current
# schematic's design (Cadence Tools>ADE-L). Raise-not-duplicate: if any session
# already targets this design, raise it (under X) and return its key. Returns
# the session key, or {} when the current view does not resolve to a schematic
# design (design_of_current already reported the honest error). Headless-safe:
# all Tk work is behind the has_x guard (the open_state carve-out doctrine).
proc ase::launch_for_current {} {
  variable untitled_view
  set d [ase::design_of_current]
  if {$d eq {}} { return {} }
  lassign $d lib cell view
  set ek [ase::session_for_design $lib $cell $view]
  if {$ek ne {}} {
    if {[info exists ::has_x]} {
      set w [ase::ui::window_for $ek]
      if {$w ne {} && [winfo exists $w]} {
        catch {wm deiconify $w}; catch {raise $w}; catch {focus $w}
      }
    }
    return $ek
  }
  set key [ase::new_session $lib $cell $view]
  if {[info exists ::has_x]} {
    ase::ui::open $key $lib $cell $untitled_view
  }
  return $key
}

# Ctrl-4 (Cadence "select signals to plot"): enter ASE Direct Plot for the
# session bound to the CURRENT schematic -- or, once descended, to the nearest
# ANCESTOR of it (issue 0168) -- without going through the ASE window's Results
# menu. Resolution is ase::session_for_current, which walks the hierarchy stack;
# it then hands off to ase::ui::direct_plot -- the click mode where a wire/net-label
# queues a voltage trace, a source/ammeter queues a current trace, and ESC plots
# the queue into the session's waveform viewer (opening it if closed). Honest
# no-op with an ase::echo when the current view is not a schematic or nothing in
# the stack has an ASE session yet (ase::no_session_notice tells the two apart).
# Headless-safe: the Tk click mode is behind the has_x guard. Returns the session
# key, or {}.
proc ase::direct_plot_for_current {} {
  set r [ase::session_for_current]
  if {$r eq {}} { ase::no_session_notice; return {} }
  set key [lindex $r 0]
  if {[info exists ::has_x]} { ase::ui::direct_plot $key 0 }
  return $key
}

# Ctrl-Shift-4 (issue 0151, doc/claude/specs/waveform_viewer_modes.md): change
# the PLOT MODE of the waveform viewer belonging to the ASE-L session bound to
# the CURRENT schematic, without leaving the design window. `mode` is
# single | multi | invert (default invert — the chord flips). Resolution is
# the Ctrl-4 path: ase::session_for_current (hierarchy-aware) -> the session key
# IS the viewer token. Returns the resolved mode, or {} with an honest
# ase::echo when the current view is not a schematic, no session is bound, or
# that session has no viewer WINDOW open (the mode is per-window state — there
# is nothing to flip until the window exists).
proc ase::plot_mode_for_current {{mode invert}} {
  set r [ase::session_for_current]
  if {$r eq {}} { ase::no_session_notice; return {} }
  set key [lindex $r 0]
  if {[wviewer::plot_mode $key] eq {}} {
    catch {::ase::echo "ase: no waveform viewer open for $key -- open it first\
 (ASE-L Tools > Waveform Viewer, or the ~ button)" error}
    return {}
  }
  set new [wviewer::set_plot_mode $mode $key]
  if {$new ne {}} {
    catch {::ase::echo "ase: waveform viewer plot mode = $new ($key)"}
  }
  return $new
}

# Ctrl-5 / Tools > "Show in Signal Browser" — THE MIRROR of the waveform
# viewer's `Descend to here` (PLAN item 12; item 11 is the other direction).
# From wherever the schematic is standing — top level or three levels down —
# open/raise the session's viewer, un-hide the Signal Browser sidebar, and
# select + SCROLL INTO VIEW the tree node for this hierarchy position.
# Returns the session key, or {} when nothing could be reached.
#
# THE ALGORITHM, written out because the ORDER of two of these steps is
# load-bearing and a plausible reordering is silently wrong:
#
#  0. CONTEXT. A menu/key body knows which window it fired in (`%W`); switch
#     there and VERIFY BY READBACK (landmine 17 — `new_schematic switch`
#     silently no-ops under a raised semaphore).
#  1. SESSION: `ase::session_for_current` — issue 0168's hierarchy-aware
#     resolution, the SAME entry point Ctrl-4's Direct Plot uses, so a descended
#     invocation resolves against the ancestor that owns the raw. `level` is
#     where that design sits in this window's stack.
#  2. ⚠ THE PIVOT IS READ NOW, BEFORE THE VIEWER IS TOUCHED. `wviewer::open`
#     and the sidebar show both MOVE the xschem context to the viewer window
#     (measured), and `sim_sch_path` read there answers about the viewer's own
#     untitled buffer. Reading it after the raise is the defect this comment
#     exists to prevent.
#     `wviewer::hier_now` is item 11's reader: `sim_sch_path` (settled decision
#     10), trailing-dot normalised by `hier_split`. NOTHING here reads sch_path.
#  3. ORIGIN: turn the window-relative position into a browser-relative one by
#     dropping `browser_origin_drop` segments. A negative drop (the raw was read
#     BELOW the session's design) is REFUSED, never guessed.
#  4. `wviewer::open $key` — already raise-or-open, 0 for an unknown token and
#     0 headless. Not re-implemented here.
#  5. SIDEBAR: un-hide it if it is hidden (item 8's mirror). `browser_toggle`
#     returns early when the state already matches, so an already-shown sidebar
#     is deliberately NOT repopulated — see browser_show_path's D6 note.
#  6. `wviewer::browser_show_path`, which speaks on every branch; its message is
#     echoed on the ASE side too, because the user is looking at the SCHEMATIC.
#  7. CONTEXT IS LEFT ON THE VIEWER. Declared, not accidental: the exact mirror
#     of item 11 leaving it on the design window, and consistent with the raise
#     — the window the user is now looking at is the one the context points at.
proc ase::show_in_browser_for_current {{win {}}} {
  # 0. the window the gesture happened in
  if {$win ne {}} {
    set cur {}
    catch {set cur [xschem get current_win_path]}
    if {$cur ne $win} {
      catch {xschem new_schematic switch $win}
      set cur {}
      catch {set cur [xschem get current_win_path]}
      if {$cur ne $win} {
        catch {::ase::echo "ase: could not switch to the design window $win" error}
        return {}
      }
    }
  }
  # 1. the session (issue 0168: nearest ANCESTOR wins)
  set r [ase::session_for_current]
  if {$r eq {}} { ase::no_session_notice ; return {} }
  set key [lindex $r 0]
  set level [lindex $r 1]
  # 2. THE PIVOT — read in the DESIGN context, before anything raises a viewer
  set segs [wviewer::hier_now]
  # 3. the origin mapping
  set lv -1
  catch {set lv [xschem raw loaded]}
  set drop [wviewer::browser_origin_drop $level $lv]
  if {$drop < 0} {
    catch {::ase::echo "ase: the simulation data is read below this session's\
 design; cannot map the schematic position onto the Signal Browser" error}
    return {}
  }
  set segs [lrange $segs $drop end]
  # 4. the viewer (raise-or-open; 0 headless or unknown)
  if {![wviewer::open $key]} {
    catch {::ase::echo "ase: no waveform viewer could be opened for $key" error}
    return {}
  }
  # 5. the sidebar (item 8's mirror)
  if {![wviewer::browser_shown $key]} {
    catch {wviewer::browser_toggle 1 $key}
  }
  # 6. the node
  set res [wviewer::browser_show_path $key [join $segs .]]
  # ⚠ THE SAME SENTENCE, from the SAME formatter, as the sidebar's status line —
  # a second wording composed here would drift from it (a `partial` reported as
  # a plain success is exactly the silent failure decision 11 forbids).
  set m [wviewer::browser_msg $res]
  if {[lindex $res 0] eq {err}} {
    catch {::ase::echo "ase: signal browser: $m" error}
  } else {
    catch {::ase::echo "ase: signal browser: $m"}
  }
  return $key
}

# The window NUMBER of the ASE-L window bound to the CURRENT schematic, or {}
# (issue 0151). Same resolution chain as above; {} with an honest ase::echo for
# a non-schematic view, no bound session, or a session whose window is not
# built (headless, or the session was only registered).
proc ase::window_number_for_current {} {
  set r [ase::session_for_current]
  if {$r eq {}} { ase::no_session_notice; return {} }
  set key [lindex $r 0]
  set n [ase::ui::number_for $key]
  if {$n eq {}} {
    catch {::ase::echo "ase: session $key has no ASE-L window open" error}
  }
  return $n
}

# --- ngspice backend --------------------------------------------------------

namespace eval ase::backend::ngspice {

  # Render the simulation deck: the circuit netlist minus its trailing `.end`
  # (spice_netlist.c emits it last for top-level .spice netlists), then
  # .include files, .lib models, .param variables, .options, .save outputs, one
  # .control block from the enabled analyses in fixed order (op, dc, ac, tran) +
  # a print per saved output for log-based result probing, then .end + trailing
  # newline.
  proc render_deck {state netlist_text} {
    set lines [split [string trimright $netlist_text "\n"] "\n"]
    while {[llength $lines] > 0 && [string trim [lindex $lines end]] eq {}} {
      set lines [lrange $lines 0 end-1]
    }
    if {[llength $lines] > 0 && [string trim [lindex $lines end]] eq ".end"} {
      set lines [lrange $lines 0 end-1]
    }
    # .include cards (top-level, before .lib models so any global .params they
    # define — gf180's design.ngspice switches sw_stat_global/mc_skew/fnoicor/…
    # that sm141064's typical section references — are in scope when the models
    # evaluate). v1 schema: each entry is a {file <portable-path>} dict, same
    # $::VAR-expansion contract as models (ase::expand_path). A bare-string
    # entry (hand-written state) is taken verbatim as the path.
    foreach inc [ase::state_get $state includes] {
      if {[llength $inc] >= 2 && [dict exists $inc file]} {
        set incfile [dict get $inc file]
      } else {
        set incfile $inc
      }
      lappend lines ".include [ase::expand_path $incfile]"
    }
    foreach m [ase::state_get $state models] {
      lappend lines ".lib [ase::expand_path [dict get $m file]] [dict get $m section]"
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
    # UI v2 Save-All blanket (item 07 D12): all-terminal-currents ->
    # `.options savecurrents`, emitted unconditionally while the flag is 1 —
    # a duplicate line from an explicit `savecurrents` options row above is
    # harmless to ngspice
    if {[ase::state_get $state save_all_i 0] eq {1}} {
      lappend lines ".options savecurrents"
    }
    # simulation temperature (UI v2): always emitted, default 27 (= ngspice's
    # own default). Non-numeric values error honestly — the GUI validates at
    # commit, so only hand-edited states can ever get here.
    set T [ase::state_get $state temperature 27]
    if {![string is double -strict $T]} {
      return -code error "ase: temperature must be numeric: '$T'"
    }
    lappend lines ".temp $T"
    # UI v2 Save-All blanket (item 07 D12): all-voltages -> `.save all`,
    # ahead of the per-output .save lines
    if {[ase::state_get $state save_all_v 0] eq {1}} {
      lappend lines ".save all"
    }
    foreach o [ase::state_get $state outputs] {
      if {[ase::state_get $o save 0] eq {1}} {
        lappend lines ".save [dict get $o expr]"
      }
    }
    lappend lines ".control"
    # `pre_*` first, before anything that could need the modules they load.
    # Position inside the block does not actually matter — ngspice runs every
    # pre_ command before parsing the netlist, probe-verified on ngspice-46 with
    # psp103.osdi in this trailing block — but first reads as what it is.
    # v1 schema: each entry is a {cmd <text>} dict; a bare string (hand-written
    # state) is taken verbatim. Same $::VAR-expansion contract as models.
    foreach pc [ase::state_get $state pre_commands] {
      if {[llength $pc] >= 2 && [dict exists $pc cmd]} {
        set cmdtext [dict get $pc cmd]
      } else {
        set cmdtext $pc
      }
      lappend lines [ase::expand_path $cmdtext]
    }
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
        lappend lines "print [ase::backend::ngspice::print_arg [dict get $o expr]]"
      }
    }
    # waveform-viewer raw artifact (item 11 D3): with a .control block,
    # ngspice's `-b -r <file>` is DEAD (probe-verified: no raw file written),
    # so emit an explicit `write <raw_file path>` of the CURRENT (= last
    # analysis) plot — only when >= 1 analysis is enabled (a plot-less
    # `write` would error). `remzerovec` first: `.options savecurrents`
    # leaves zero-length @m...[ib]-class vectors in the plot and ngspice's
    # write then aborts SILENTLY (probe-verified, ngspice-42) — remzerovec
    # prunes them and is harmless when there are none.
    set n_enabled 0
    foreach a [ase::state_get $state analyses] {
      if {[ase::state_get $a enabled 0] eq {1}} { incr n_enabled }
    }
    if {$n_enabled > 0} {
      lappend lines "remzerovec"
      lappend lines "write [raw_file $state]"
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

  # <rundir>/<cell>_ase.raw — the raw-file artifact the waveform viewer feeds
  # from (item 11 D3, log_file mirror). render_deck emits an in-.control
  # `write` of this path whenever >= 1 analysis is enabled.
  proc raw_file {state} {
    if {![dict exists $state design cell]} {
      return -code error "ase: state design has no cell (raw_file)"
    }
    set cell [dict get $state design cell]
    return [file join [ase::rundir $state] ${cell}_ase.raw]
  }

  # `print` argument for an output expression. ngspice's expression parser reads
  # the `[0]` in `print a[0]` as a SUBSCRIPT of a vector named `a`, so a bus-bit
  # name prints nothing at all — "Warning from checkvalid: vector a is not
  # available or has zero length" (measured, ngspice-42; `print v(a[0])`,
  # `print {a[0]}` and `print a\[0\]` fail the same way). Double-quoting makes it
  # a literal vector name: `print "a[0]"` prints `"a[0]" = 1.500000e+00`. The
  # `.save` side is NOT affected — `.save a[0]` saves the vector correctly — and
  # quoting a `@dev[param]` name is harmless (measured), so the rule is simply:
  # a bracketed expression is quoted. result_probe below accepts the quoted
  # label ngspice then echoes.
  proc print_arg {ex} {
    if {[string first {[} $ex] < 0} { return $ex }
    if {[string first {"} $ex] >= 0} { return $ex }   ;# hand-quoted already
    return "\"$ex\""
  }

  # Parse `<expr> = <float>` lines out of the log text (e.g.
  # `-i(v1) = 4.096837e-04`, or `"a[0]" = 1.5` for a print_arg-quoted bit)
  # -> results dict, for every state output whose line appears. Keyed by the
  # output's `name` when present and non-empty, else by its `expr` (UI v2: the
  # Outputs pane needs a Value for unnamed rows too); outputs without an `expr`
  # are skipped.
  proc result_probe {state logtext} {
    set results [dict create]
    foreach o [ase::state_get $state outputs] {
      if {![dict exists $o expr]} { continue }
      set rkey [dict get $o expr]
      if {[dict exists $o name] && [dict get $o name] ne {}} {
        set rkey [dict get $o name]
      }
      regsub -all {\W} [dict get $o expr] {\\&} esc
      set pat [format {^\s*"?%s"?\s*=\s*([-+]?[0-9.]+(?:[eE][-+]?[0-9]+)?)\s*$} $esc]
      if {[regexp -line $pat $logtext -> val]} {
        dict set results $rkey $val
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
    result_probe ::ase::backend::ngspice::result_probe \
    raw_file     ::ase::backend::ngspice::raw_file]
}
