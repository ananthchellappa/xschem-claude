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
  # `cosim` follows it for the same reason — it is deck/simulation config the
  # state owns (spec section E, E4). It is POLICY ONLY: it never lists the
  # digital artifacts, which are DERIVED from the netlist at run time.
  variable schema_keys {version simulator design rundir temperature models
                        variables analyses outputs save_all_v save_all_i
                        options includes pre_commands cosim viewer}
  # Schema keys the serializer OMITS when empty. Every v1 key is written even
  # when empty because every state file on disk already carries it; a key added
  # LATER must not rewrite files that predate it — `state_load` merges over
  # state_default, so an old file would otherwise gain `cosim {}` and stop
  # round-tripping byte-identically (which two committed-golden tests assert,
  # and which is what keeps a `git diff` of a state view meaningful). Empty
  # carries no information here: `cosim {}` means exactly "every default".
  variable omit_if_empty {cosim}
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
#
# `version` STAYS 1 when a key is added (spec E4). Nothing reads it, and
# ase::state_load merges the file OVER this dict, so a state written before a
# key existed gains it with its default automatically and keeps every key it
# already had. Bumping the number would buy nothing and would invite an
# equality test somewhere that then rejects older files. It is reserved for a
# change that an old loader could MISREAD, not for a new optional key.
# tests/headless/fixtures/ase_state_v1_pre_cosim.state pins that.
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
    cosim     {} \
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
  variable omit_if_empty
  set lines {}
  foreach k $schema_keys {
    if {[dict exists $state $k]} {
      if {[dict get $state $k] eq {} && [lsearch -exact $omit_if_empty $k] >= 0} { continue }
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

  # --- mixed-signal co-simulation (spec section E) --------------------------
  # Detect at NETLIST time (E1), record the instance<->VCD map beside the
  # artifacts it describes (F2), and rebuild every code-model .so BEFORE
  # ngspice starts (E6). All three are no-ops for a purely analog deck:
  # cosim_map returns {} the moment the netlist carries no d_cosim card.
  # A failed build THROWS out of here on purpose — falling through would run
  # the previous .so, i.e. silently simulate last week's Verilog.
  set cosim [ase::cosim_map $state $netlist_text]
  ase::cosim_save_map $state $cosim
  # Delete the VCDs this deck is about to promise, for the reason ase::netlist
  # gives for deleting its own artifact: a stale one must not mask a failed
  # run. The VCD is written by the SHIM, not by ngspice's `write`, so the analog
  # half can succeed while the digital half writes nothing at all — and then
  # both the E7 missing-artifact check and last_vcdfiles would serve the
  # PREVIOUS run's digital data beside this run's analog raw.
  ase::cosim_clear_artifacts $cosim
  if {[llength $cosim]} {
    foreach r [ase::cosim_build $state $cosim] {
      lassign $r cm cstatus cdetail
      if {$cstatus eq {unavailable}} {
        ::ase::echo "ase: d_cosim model '$cm': $cdetail" error
      } elseif {$cstatus eq {built}} {
        ::ase::echo "ase: d_cosim model '$cm': rebuilt $cdetail"
      }
    }
    foreach e $cosim {
      if {[ase::state_get $e multi 0] ne {1}} continue
      ::ase::echo "ase: d_cosim model '[dict get $e model]' is instantiated\
 [llength [dict get $e insts]] times ([join [dict get $e insts] {, }]) — the netlister emits\
 ONE .model card for them (spice_netlist.c:143-169), so they would all write ONE VCD.\
 Its internal signals are NOT collected." error
    }
  }

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
  # spec E7: a co-simulation can produce a clean exit code and WRONG waveforms.
  # Scan the log for the diagnostics that say so and put them where a user will
  # see them (ase::echo reaches the CIW pane AND the action log), not only in
  # a 50 MB log file nobody scrolls.
  set diags [ase::run_diagnostics $data]
  # ...and the failure the LOG cannot report. Measured: ngspice lower-cases the
  # strings in a device card, so a `sim_args` VCD path it cannot create is not
  # an error it prints — the run exits 0, the analog raw is perfect, and the
  # digital data is simply absent. Any VCD the deck promised and did not
  # produce is therefore reported from the filesystem, not from the log.
  # cosim_load_map is {} for an analog run (run_deck deletes the artifact), so
  # this costs an analog run nothing.
  if {$exitcode == 0} {
    catch {
      foreach cme [ase::cosim_load_map $state] {
        if {[ase::state_get $cme multi 0] eq {1}} continue
        set cmv [ase::state_get $cme vcd]
        if {$cmv eq {} || [file isfile $cmv]} continue
        lappend diags [list error cosim_novcd 1 "the deck asked d_cosim model\
 '[ase::state_get $cme model]' to write [file tail $cmv] into the run directory and it\
 never appeared, so this block's internal signals were not captured (a .so built without\
 -V, or a run directory ngspice could not write to)"]
      }
    }
  }
  set last_run [dict create results $results exitcode $exitcode log $logpath \
                            diagnostics $diags]
  foreach d $diags {
    lassign $d dsev dcode dn dmsg
    if {$dsev ne {error}} continue
    ::ase::echo "ase: *** CO-SIMULATION PROBLEM ($dcode, $dn occurrence[expr {$dn == 1 ? {} : {s}}]):\
 $dmsg. The results of this run cannot be trusted. See $logpath" error
  }
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

# --- Mixed-signal co-simulation (spec section E) -----------------------------
# doc/claude/specs/mixed_signal_signal_browser.md section E. Everything here is
# Tk-free and headless-testable (tests/headless/test_ase_cosim.tcl).
#
# WHAT A "COSIM RUN" IS. An ngspice deck is mixed-signal when it carries at
# least one `.model <name> d_cosim ...` card: that card is what ngspice obeys,
# and it is the ONLY thing that makes the run co-simulate. The DESIGN side
# (an instance whose cell has a `verilog` view, spec B) is what tells us WHICH
# `.v` built that `.so` and which schematic instance owns the resulting VCD.
# Both are needed and neither substitutes for the other, so the map below is
# built from the deck text and then ENRICHED from the design walk.
#
# E1 -- DETECTION IS AT NETLIST TIME, NOT A STATE DECLARATION.  Measured: the
# reference netlist emits exactly one card,
#     .model counter d_cosim simulation="./counter.so" sim_args=["counter.vcd"] delay=0
# from the INSTANCE's `device_model=` attribute (spice_netlist.c:228; the symbol
# K record is only a fallback, :234). A state-dict declaration would be a second
# copy of a fact the netlist already states, and would be wrong the moment a code
# block is added, removed or renamed -- the same argument the spec makes against a
# hand-maintained F2 mapping. The `cosim` state key added by E4 is therefore
# POLICY ONLY (build/trace/supply knobs); it never declares which blocks exist.
#
# E1 uses `cellview_sibling_path`, NOT `library_inst_lcv`, to answer "does this
# cell have a verilog view". `library_inst_lcv` is usable (it is a plain Tcl proc
# taking a symbol reference, library_defs.tcl:505) and IS called here for the
# lib/cell labels, but it only accepts the Cadence nested layout, so on its own it
# would silently miss a flat library. `cellview_sibling_path` (library_defs.tcl:420,
# spec B8) answers the same question in both layouts. The C verb `xschem
# get_inst_lcv` is NOT usable at all here: it requires exactly one SELECTED
# instance (scheduler.c:5020-5027), so it cannot enumerate.
#
# E2 -- ONE VCD PER d_cosim MODEL CARD, named <rundir>/<model>.vcd, written into
# the card's `sim_args` by render_deck.  It cannot be per-INSTANCE: the netlister
# deduplicates `.model` cards on the first two tokens after `.model`
# (spice_netlist.c:143-169, key `counterd_cosim`), so two instances of the same
# cell share ONE card, hence one `.so` and one `sim_args`. Splitting them would
# mean synthesizing per-instance model cards AND rewriting every instance line's
# trailing model token -- deep netlist surgery for a case that does not exist yet.
# So: two DIFFERENT code blocks can never collide (different model names ->
# different files), and the same block instantiated TWICE is DETECTED (the
# instance lines are counted) and reported: its VCD would be two shims writing one
# file, so the map marks it `multi 1` and it is excluded from the attach. The
# upgrade path is per-instance model synthesis, deliberately not taken now.
#
# E6 -- STALENESS IS A STAMP FILE, NOT AN mtime COMPARE.  `<so>.stamp` records the
# source path, its mtime and size, the shim source's mtime and size, and the build
# flags. A bare "is the .so newer than the .v" test is not enough because the
# rundir defaults to $USER_CONF_DIR/simulations for EVERY design (ase::rundir), so
# two libraries that both contain a cell named `counter` build to the same
# `<rundir>/counter.so`; the mtime test would happily reuse the wrong one. The
# stamp also catches a shim edit (a `-V` build links tools/cosim/src) and a flag
# change. No content hash: Tcl 8.6 core has no digest and tcllib is not a
# dependency; path+mtime+size errs toward rebuilding, which is the safe direction.
#
# F2 -- THE INSTANCE <-> VCD MAPPING IS CARRIED NOW, as a RUN-DIRECTORY ARTIFACT
# `<rundir>/<cell>_ase.cosim` written at run time beside the .raw and the .log.
# Not the state file (it is derived data and would go stale on every edit), not
# the Raw struct (a C change to every consumer for zero benefit today). It is a
# deterministic path exactly like ase::raw_file / log_file, so a later session --
# or F2's Signal Browser -- reads it without re-netlisting. Its `scope` field is a
# HINT: Verilator names the DUT scope after the MODULE (measured: the reference
# counter.vcd declares `$scope module TOP` then `$scope module counter`), which is
# read out of the .v here, but inlining can change it, so F2 must verify the scope
# against the DB it actually loaded rather than trust this string.

# The build script that turns a `.v` into a d_cosim `.so`. An rc may point this
# at an installed copy; stock resolution is the in-tree tools/cosim one, then
# PATH. Empty -> no build orchestration is possible (E6 degrades to a notice).
set_ne ASE_COSIM_BUILD {}

# A `cosim` policy value, or `dflt`. The key is POLICY ONLY (see the header):
#   build   auto|always|never   rebuild the .so before the run (default auto)
#   trace   0|1                 build with -V so the shim writes a VCD (default 1)
#   attach  0|1                 attach the VCDs after a run (default 1)
#   vsupply <volts>             digital supply for the default auto_bridge models
#   bridges auto|0|1            emit default auto_bridge pre_sets (default auto)
proc ase::cosim_policy {state key {dflt {}}} {
  set c [ase::state_get $state cosim]
  if {[catch {expr {[dict exists $c $key] ? 1 : 0}} ok]} { return $dflt }
  if {!$ok} { return $dflt }
  set v [dict get $c $key]
  if {$v eq {}} { return $dflt }
  return $v
}

# Digital supply for the default adc/dac bridge models: the `cosim vsupply`
# policy, else a design variable named VDD, else 1.8 (the reference TB's value
# and the upstream example's).
proc ase::cosim_supply {state} {
  set v [ase::cosim_policy $state vsupply {}]
  if {[string is double -strict $v]} { return $v }
  foreach var [ase::state_get $state variables] {
    if {[catch {ase::state_get $var name} nm]} { continue }
    if {[string tolower $nm] ne {vdd}} { continue }
    set val [ase::state_get $var value]
    if {[string is double -strict $val]} { return $val }
  }
  return 1.8
}

# The LOCAL `.so` basename a `simulation=` value names, or {} when this card is
# not something ASE may build or trace. Three rejections, each measured:
#   - not a `.so` at all -> upstream's Icarus arm, `simulation="ivlng"`, whose
#     `sim_args[0]` is the compiled vvp DESIGN name. Rewriting that to a VCD
#     path stops the co-simulation dead, and it is the alternative the reference
#     symbol ships commented out one line below the active card.
#   - a path with a directory in it -> ngspice opens THAT file; building a
#     same-named .so into the run directory would stamp a file nobody loads and
#     report "rebuilt", i.e. silently simulate the old Verilog.
#   - lower-cased, because ngspice folds the card (M18).
proc ase::cosim_so_local {so} {
  if {![string match {*.so} $so]} { return {} }
  set s $so
  if {[string range $s 0 1] eq {./}} { set s [string range $s 2 end] }
  if {[string first / $s] >= 0} { return {} }
  return [string tolower $s]
}

# A model name reduced to a safe filename stem. LOWERCASED, and that is not
# cosmetic -- see cosim_rewrite: ngspice folds the strings inside a device card
# to lower case, so an artifact whose name has any upper case is opened under a
# DIFFERENT name than the one on disk.
proc ase::cosim_safe_name {name} {
  regsub -all {[^A-Za-z0-9_.+-]} $name {_} name
  if {$name eq {}} { set name cosim }
  return [string tolower $name]
}

# SPICE `+` continuations folded onto the card they continue, so a `.model`
# split across lines is still SEEN. (The rewrite side deliberately does NOT
# use this -- it edits physical lines; see cosim_rewrite.)
proc ase::cosim_logical_lines {text} {
  set out {}
  foreach raw [split $text "\n"] {
    set line [string trimright $raw]
    if {[llength $out] && [regexp {^[ \t]*\+} $line]} {
      regsub {^[ \t]*\+} $line { } line
      lset out end "[lindex $out end]$line"
      continue
    }
    lappend out $line
  }
  return $out
}

# Scan a netlist/deck for d_cosim model cards. Returns an ORDERED list of dicts
#   {model <as written> so <simulation= value> sim_args <raw [..] content>
#    insts <XSPICE instance names referencing it> cont <1 if the card is a
#    continued card and cannot be rewritten in place>}
# Lines inside a `.control` block are skipped: `alter`/`altermod` there are not
# device cards and an `a...` control command is not an instance.
proc ase::cosim_scan_deck {text} {
  set logical [ase::cosim_logical_lines $text]
  set phys {}
  foreach raw [split $text "\n"] { lappend phys [string trimright $raw] }
  set order {}
  set info [dict create]
  set incontrol 0
  foreach line $logical {
    if {[regexp -nocase {^[ \t]*\.control\M} $line]} { set incontrol 1; continue }
    if {[regexp -nocase {^[ \t]*\.endc\M} $line]} { set incontrol 0; continue }
    if {$incontrol} { continue }
    if {![regexp -nocase {^[ \t]*\.model[ \t]+(\S+)[ \t]+d_cosim\M} $line -> m]} { continue }
    set key [string tolower $m]
    if {[dict exists $info $key]} { continue }
    set so {}
    if {![regexp -nocase {simulation[ \t]*=[ \t]*"([^"]*)"} $line -> so]} {
      regexp -nocase {simulation[ \t]*=[ \t]*(\S+)} $line -> so
    }
    set sargs {}
    regexp -nocase {sim_args[ \t]*=[ \t]*\[([^\]]*)\]} $line -> sargs
    # a card that only exists in folded form cannot be edited on one physical line
    set cont 0
    if {[lsearch -exact $phys $line] < 0} { set cont 1 }
    lappend order $key
    dict set info $key [dict create model $m so $so sim_args $sargs insts {} ninst 0 cont $cont]
  }
  if {![llength $order]} { return {} }
  set incontrol 0
  set curblk {}
  set mult [ase::cosim_subckt_counts $logical]
  foreach line $logical {
    if {[regexp -nocase {^[ \t]*\.control\M} $line]} { set incontrol 1; continue }
    if {[regexp -nocase {^[ \t]*\.endc\M} $line]} { set incontrol 0; continue }
    if {$incontrol} { continue }
    if {[regexp -nocase {^[ \t]*\.subckt[ \t]+(\S+)} $line -> bnm]} {
      set curblk [string tolower $bnm]; continue
    }
    if {[regexp -nocase {^[ \t]*\.ends\M} $line]} { set curblk {}; continue }
    if {![regexp {^[ \t]*([aA]\S*)[ \t]+(.*\S)[ \t]*$} $line -> instname rest]} { continue }
    set toks [regexp -all -inline {\S+} $rest]
    if {![llength $toks]} { continue }
    set last [string tolower [lindex $toks end]]
    if {![dict exists $info $last]} { continue }
    dict set info $last insts [concat [dict get $info $last insts] [list $instname]]
    # ELABORATED count, not line count: a `.subckt` body appears once however
    # many times the block is instantiated, so `x1 … dig_top` + `x2 … dig_top`
    # around one `a1 … counter` line means TWO shims opening one VCD path.
    # 0, not 1, when the enclosing `.subckt` is never instantiated: that block
    # is dead code and contributes no runtime instance. The top level is always
    # in `mult` with multiplicity 1, so a flat deck still counts 1.
    set n 0
    if {[dict exists $mult $curblk]} { set n [dict get $mult $curblk] }
    dict set info $last ninst [expr {[ase::state_get [dict get $info $last] ninst 0] + $n}]
  }
  set out {}
  foreach k $order { lappend out [dict get $info $k] }
  return $out
}

# How many times each `.subckt` is ELABORATED, counted from the top level.
# `.subckt` bodies are emitted ONCE however many times they are instantiated
# (spice_netlist.c dedups on the cell), so a line scan alone cannot tell one
# code block from N. Returns a dict subckt-name -> multiplicity, plus the key
# {} for the top level (always 1). Computed by bounded relaxation, not by a
# traversal -- see the comment on pass 2 for why a visit-once DFS is wrong here.
proc ase::cosim_subckt_counts {logical} {
  # pass 1: which block each line is in, and the x-instantiations per block
  set blocks [dict create {} [dict create]]
  set cur {}
  foreach line $logical {
    if {[regexp -nocase {^[ \t]*\.subckt[ \t]+(\S+)} $line -> nm]} {
      set cur [string tolower $nm]
      if {![dict exists $blocks $cur]} { dict set blocks $cur [dict create] }
      continue
    }
    if {[regexp -nocase {^[ \t]*\.ends\M} $line]} { set cur {}; continue }
    if {![regexp {^[ \t]*[xX]\S*[ \t]+(.*\S)[ \t]*$} $line -> rest]} { continue }
    # the subckt name is the last token that is not a `param=value` assignment
    set nm {}
    foreach tok [regexp -all -inline {\S+} $rest] {
      if {[string first = $tok] >= 0} { continue }
      set nm $tok
    }
    if {$nm eq {}} { continue }
    set nm [string tolower $nm]
    set b [dict get $blocks $cur]
    dict incr b $nm
    dict set blocks $cur $b
  }
  # pass 2: multiplicity by BOUNDED RELAXATION, re-derived from scratch each
  # round. A visit-once DFS is wrong here and was measured wrong: a block popped
  # before every one of its parents has contributed keeps that partial
  # multiplicity, and its descendants inherit it — `wa`+`wb` both instantiating
  # `mid`, which instantiates the code block, gave the block 1 instead of 2 and
  # so `multi 0`, which is exactly the interleaved-VCD case the flag exists for.
  # One round propagates one level, so `size` rounds reach the deepest block;
  # the fixed bound is also the cycle guard (a self-referential netlist is
  # malformed, not a reason to hang).
  set mult [dict create {} 1]
  set rounds [expr {[dict size $blocks] + 1}]
  for {set pass 0} {$pass < $rounds} {incr pass} {
    set next [dict create {} 1]
    dict for {parent kids} $blocks {
      if {![dict exists $mult $parent]} { continue }
      set m [dict get $mult $parent]
      if {$m == 0} { continue }
      dict for {child n} $kids {
        set add [expr {$m * $n}]
        if {[dict exists $next $child]} {
          dict set next $child [expr {[dict get $next $child] + $add}]
        } else {
          dict set next $child $add
        }
      }
    }
    if {[dict size $next] == [dict size $mult]} {
      set same 1
      dict for {k v} $next { if {![dict exists $mult $k] || [dict get $mult $k] != $v} { set same 0; break } }
      if {$same} { break }
    }
    set mult $next
  }
  return $mult
}

# instname -> {inst symref lib cell module vfile} for every instance of the
# CURRENT schematic whose cell has a `verilog` view (E1's design side). Empty
# when no schematic is loaded or nothing qualifies. Keys are LOWERCASED because
# SPICE instance names are case-insensitive and the deck is the other half of
# the join.
proc ase::cosim_design_scan {} {
  set out [dict create]
  if {[catch {xschem instance_list} lst]} { return $out }
  foreach {inst symref type} $lst {
    if {$inst eq {} || $symref eq {}} { continue }
    set vfile {}
    catch {set vfile [cellview_sibling_path $symref verilog]}
    if {$vfile eq {} || ![file isfile $vfile]} { continue }
    set lib {}; set cell {}
    if {![catch {library_inst_lcv $symref} lcv] && [llength $lcv] == 3} {
      set lib [lindex $lcv 0]
      set cell [lindex $lcv 1]
    }
    if {$cell eq {}} { set cell [file rootname [file tail $vfile]] }
    dict set out [string tolower $inst] [dict create \
      inst $inst symref $symref lib $lib cell $cell \
      vfile [file normalize $vfile] module [ase::cosim_module_of $vfile]]
  }
  return $out
}

# Is the state's design the schematic currently loaded? Mirrors the comparison
# ase::netlist makes before netlisting in place (normalized cellview_path vs
# `xschem get schname`), and for the same reason: those are the only conditions
# under which the current xctx's instances belong to THIS state.
proc ase::cosim_design_is_current {state} {
  set design [ase::state_get $state design]
  if {$design eq {}} { return 0 }
  if {[catch {expr {[dict exists $design lib] && [dict exists $design cell]}} ok]} { return 0 }
  if {!$ok} { return 0 }
  set view schematic
  if {[dict exists $design view] && [dict get $design view] ne {}} {
    set view [dict get $design view]
  }
  if {[catch {xschem cellview_path [dict get $design lib]/[dict get $design cell] $view} p]} {
    return 0
  }
  if {$p eq {}} { return 0 }
  if {[catch {xschem get schname} cur] || $cur eq {}} { return 0 }
  return [expr {[file normalize $cur] eq [file normalize $p] ? 1 : 0}]
}

# The first `module <name>` declared in a Verilog source, or {}. Used only for
# the VCD scope HINT -- Verilator names the DUT trace scope after the module.
proc ase::cosim_module_of {vfile} {
  if {$vfile eq {} || ![file isfile $vfile]} { return {} }
  if {[catch {open $vfile r} f]} { return {} }
  set txt [read $f]
  close $f
  if {[regexp -line {^[ \t]*module[ \t]+([A-Za-z_][A-Za-z0-9_$]*)} $txt -> m]} { return $m }
  return {}
}

# <rundir>/<cell>_ase.cosim -- the co-simulation map artifact (F2). log_file /
# raw_file mirror.
proc ase::cosim_file {state} {
  if {![dict exists $state design cell]} {
    return -code error "ase: state design has no cell (cosim_file)"
  }
  set cell [dict get $state design cell]
  return [file join [ase::rundir $state] ${cell}_ase.cosim]
}

# The full map: the deck scan, enriched with the design walk (when the design is
# the current schematic) and with the previously saved map (so `Run` on an
# existing netlist, which never loads the design, still knows which .v built
# which .so). Adds, per entry: vcd, scope, multi, lib, cell, vfile, module.
proc ase::cosim_map {state netlist_text} {
  set scan [ase::cosim_scan_deck $netlist_text]
  if {![llength $scan]} { return {} }
  # The design walk is trusted ONLY when the state's design is the schematic
  # actually loaded. `ase::run_existing` (ADE-L's "Run", on the existing netlist
  # artifact) never loads it, and the window can be sitting on any other cell —
  # whose instance names would join against this deck's, since `a1` is the
  # default name for a code block. That join would hand the WRONG .v to the E6
  # build. With no trustworthy walk the map falls back to the sidecar below,
  # which is what the artifact exists for.
  set dmap [dict create]
  if {[ase::cosim_design_is_current $state]} { set dmap [ase::cosim_design_scan] }
  set prev [dict create]
  foreach e [ase::cosim_load_map $state] {
    dict set prev [string tolower [ase::state_get $e model]] $e
  }
  set rd [ase::rundir $state]
  set trace [expr {[ase::cosim_policy $state trace 1] eq {0} ? 0 : 1}]
  set dcell {}
  catch {set dcell [dict get [ase::state_get $state design] cell]}
  if {$dcell eq {}} { set dcell cosim }
  set used [dict create]
  set out {}
  foreach e $scan {
    set key [string tolower [dict get $e model]]
    set lib {}; set cell {}; set vfile {}; set module {}
    foreach i [dict get $e insts] {
      set ik [string tolower $i]
      if {![dict exists $dmap $ik]} { continue }
      set d [dict get $dmap $ik]
      set lib [dict get $d lib]; set cell [dict get $d cell]
      set vfile [dict get $d vfile]; set module [dict get $d module]
      break
    }
    if {$vfile eq {} && [dict exists $prev $key]} {
      set p [dict get $prev $key]
      set lib [ase::state_get $p lib]; set cell [ase::state_get $p cell]
      set vfile [ase::state_get $p vfile]; set module [ase::state_get $p module]
      if {$vfile ne {} && ![file isfile $vfile]} { set vfile {} }
    }
    if {$module eq {}} { set module [dict get $e model] }
    dict set e lib $lib
    dict set e cell $cell
    dict set e vfile $vfile
    dict set e module $module
    dict set e scope "TOP.$module"
    # ELABORATED instances, not netlist lines (cosim_scan_deck): N of them share
    # the one `.model` card, so they would all open the one `sim_args[0]` path
    # and interleave their writes. Detected, excluded from the attach, reported.
    set n [ase::state_get $e ninst 0]
    if {$n < [llength [dict get $e insts]]} { set n [llength [dict get $e insts]] }
    dict set e ninst $n
    dict set e multi [expr {$n > 1 ? 1 : 0}]
    dict set e local_so [ase::cosim_so_local [dict get $e so]]
    # `vcd` is BOTH the artifact path and the promise: last_vcdfiles serves it,
    # cosim_rewrite writes its basename into the card, and run_done reports it
    # missing after the run. So it is set ONLY when this run will really write
    # one. Empty for the Icarus arm, for a `.so` outside the run directory, for
    # a `+`-continued card render_deck cannot edit, and for `cosim trace 0`.
    set vcd {}
    if {[dict get $e local_so] ne {} && [ase::state_get $e cont 0] ne {1} && $trace} {
      set vcd [file join $rd "[ase::cosim_safe_name ${dcell}_[dict get $e model]].vcd"]
      # design-qualified, like <cell>_ase.raw / .log / .cosim: the run directory
      # defaults to $USER_CONF_DIR/simulations for EVERY design, so a bare
      # <model>.vcd lets two sessions serve each other's digital data.
      if {[dict exists $used $vcd]} {
        # two model names that differ only where cosim_safe_name folds them
        set vcd [file join $rd \
          "[ase::cosim_safe_name ${dcell}_[dict get $e model]]_[llength $out].vcd"]
      }
      dict set used $vcd 1
    }
    dict set e vcd $vcd
    lappend out $e
  }
  return $out
}

# Delete the VCDs a deck is about to promise. Returns the list deleted.
# Same reasoning ase::netlist gives for deleting its netlist artifact ("a stale
# artifact must not mask a failed netlist"), and here it is load-bearing twice
# over: the VCD is written by the SHIM, not by ngspice's `write`, so the analog
# half can succeed while the digital half writes nothing -- and both the E7
# missing-artifact check and ase::last_vcdfiles decide with `file isfile`, so a
# survivor from the previous run would be silently attached to THIS run's raw.
proc ase::cosim_clear_artifacts {map} {
  set gone {}
  foreach e $map {
    set v [ase::state_get $e vcd]
    if {$v eq {}} { continue }
    if {[file exists $v]} { lappend gone $v }
    file delete -force -- $v
  }
  return $gone
}

# Persist / recover the map artifact. One `list`-quoted dict per line, `#`
# comments skipped. Never throws: a missing or corrupt artifact just means "no
# map" (the deck scan alone still detects the run as mixed-signal).
proc ase::cosim_save_map {state map} {
  if {[catch {ase::cosim_file $state} path]} { return {} }
  if {![llength $map]} { file delete -force -- $path; return $path }
  if {[catch {open $path w} f]} { return {} }
  puts $f "# xschem ASE-L co-simulation map -- generated, do not edit."
  puts $f "# doc/claude/specs/mixed_signal_signal_browser.md section E (F2 consumes it)."
  foreach e $map { puts $f [list $e] }
  close $f
  return $path
}

proc ase::cosim_load_map {state} {
  if {[catch {ase::cosim_file $state} path]} { return {} }
  if {![file isfile $path]} { return {} }
  if {[catch {open $path r} f]} { return {} }
  set txt [read $f]
  close $f
  set out {}
  foreach line [split $txt "\n"] {
    set line [string trim $line]
    if {$line eq {} || [string index $line 0] eq "#"} { continue }
    if {[catch {lindex $line 0} e]} { continue }
    if {[catch {dict size $e}]} { continue }
    lappend out $e
  }
  return $out
}

# Replace (or insert) `sim_args=["<vcd>"]` on ONE physical `.model ... d_cosim`
# line. Index arithmetic, not regsub: a path may contain `&` or `\`, which
# regsub's replacement grammar would eat.
proc ase::cosim_set_sim_args {line vcd} {
  set rep "sim_args=\[\"$vcd\"\]"
  if {[regexp -nocase -indices {sim_args[ \t]*=[ \t]*\[[^\]]*\]} $line rng]} {
    return [string replace $line [lindex $rng 0] [lindex $rng 1] $rep]
  }
  if {[regexp -nocase -indices {^[ \t]*\.model[ \t]+\S+[ \t]+d_cosim} $line rng]} {
    set b [lindex $rng 1]
    return [string replace $line $b $b "[string index $line $b] $rep"]
  }
  return $line
}

# Point every d_cosim card in `lines` at the map's per-model VCD (E2).
#
# WHAT GOES INTO THE CARD IS A BARE, LOWER-CASE BASENAME, NOT THE ABSOLUTE PATH,
# and that is measured, not taste. ngspice-46 LOWERCASES the strings inside a
# device card, exactly as M14 records for script-file mode:
#
#   sim_args=["/tmp/vcdprobe/Ecap/x.vcd"]   -> the shim opened
#                    /tmp/vcdprobe/ecap/x.vcd   (proved: pre-creating the
#                    lower-case directory made the file appear there)
#   simulation="./CounterUP.so"             -> ngspice reported
#                    `d_cosim failed to load simulation binary ./counterup.so.`
#
# So an absolute path is silently destroyed by any upper case ANYWHERE in it --
# a run directory under /home/User, or a scratch dir with a capital letter, and
# the VCD simply never appears with NO error at all (the `.so` case at least
# reports; the trace path does not). A bare basename puts nothing but the model
# name through the folder, and cosim_safe_name has already lower-cased that.
#
# The cost is a cwd dependency: the shim resolves it against ngspice's working
# directory. That is sound because ase::run_deck already does `cd $rundir`
# before launching, and because the deck's own `simulation="./<cell>.so"` has
# the identical dependency. ase::cosim_map keeps the ABSOLUTE path in `vcd` --
# that is the one Tcl reads back (E3) and it never goes near ngspice.
#
# A card that only exists as a `+`-continued card is left alone -- editing it
# would need to know which physical line carries `sim_args`.
#
# The model name is matched by CAPTURING it and comparing case-insensitively,
# not by building a regexp around it: a name interpolated into a pattern would
# have to be regexp-quoted, and SPICE compares model names case-insensitively
# anyway (spice_netlist.c's own hash key is lowercased, :150).
proc ase::cosim_rewrite {lines map} {
  set want [dict create]
  foreach e $map {
    # `vcd` is empty for every card this run will not trace -- the Icarus arm, a
    # `.so` ngspice opens from elsewhere, a `+`-continued card, `trace 0`. Those
    # cards are left EXACTLY as the netlist wrote them: for `simulation="ivlng"`
    # sim_args[0] is the compiled vvp design, and overwriting it with a VCD path
    # is the one edit that stops that backend working.
    set vcd [ase::state_get $e vcd]
    if {$vcd eq {}} { continue }
    dict set want [string tolower [dict get $e model]] [file tail $vcd]
  }
  if {![dict size $want]} { return $lines }
  set done [dict create]
  for {set i 0} {$i < [llength $lines]} {incr i} {
    set line [lindex $lines $i]
    if {![regexp -nocase {^[ \t]*\.model[ \t]+(\S+)[ \t]+d_cosim\M} $line -> m]} { continue }
    set k [string tolower $m]
    if {![dict exists $want $k] || [dict exists $done $k]} { continue }
    lset lines $i [ase::cosim_set_sim_args $line [dict get $want $k]]
    dict set done $k 1
  }
  return $lines
}

# --- E6: build orchestration -------------------------------------------------

# The build script, or {} when none can be found.
proc ase::cosim_build_script {} {
  if {[info exists ::ASE_COSIM_BUILD] && $::ASE_COSIM_BUILD ne {}} {
    if {[file executable $::ASE_COSIM_BUILD]} { return $::ASE_COSIM_BUILD }
    return {}
  }
  if {[info exists ::XSCHEM_SHAREDIR]} {
    set p [file normalize [file join $::XSCHEM_SHAREDIR .. tools cosim build_cosim_so.sh]]
    if {[file executable $p]} { return $p }
  }
  set p [auto_execok build_cosim_so.sh]
  if {$p ne {}} { return [lindex $p 0] }
  return {}
}

# The shim source directory the build links, mirrored EXACTLY from
# build_cosim_so.sh so the stamp can see a shim edit: NGSPICE_COSIM_SRC wins;
# else a `-V` (trace) build uses the in-repo patched copy and a plain build uses
# the system one. Mirroring the trace arm matters — recording the repo shim for
# a build that actually linked the system shim would make a system upgrade
# invisible to the staleness test.
proc ase::cosim_shim_dir {script {trace 1}} {
  if {[info exists ::env(NGSPICE_COSIM_SRC)] && $::env(NGSPICE_COSIM_SRC) ne {}} {
    return $::env(NGSPICE_COSIM_SRC)
  }
  if {!$trace} { return /usr/local/share/ngspice/scripts/src }
  if {$script eq {}} { return {} }
  return [file join [file dirname $script] src]
}

# The build stamp for one entry: every input whose change must force a rebuild.
proc ase::cosim_stamp {vfile script shimdir trace} {
  set out [list src $vfile trace $trace]
  foreach {k p} [list src $vfile tool $script shim [file join $shimdir verilator_shim.cpp]] {
    if {$p ne {} && [file isfile $p]} {
      lappend out ${k}_mtime [file mtime $p] ${k}_size [file size $p]
    } else {
      lappend out ${k}_mtime {} ${k}_size {}
    }
  }
  return $out
}

# Is `so` missing, or built from different inputs than `stamp` describes?
proc ase::cosim_stale {so stamp} {
  if {![file isfile $so]} { return 1 }
  set sf $so.stamp
  if {![file isfile $sf]} { return 1 }
  if {[catch {open $sf r} f]} { return 1 }
  set old [read $f]
  close $f
  if {[catch {string equal [string trim $old] [string trim $stamp]} same]} { return 1 }
  return [expr {$same ? 0 : 1}]
}

# Build every d_cosim `.so` the map names, before the deck runs (E6).
# Returns a list of {model status detail}; status is one of
#   built | uptodate | skipped | unavailable.
# A FAILED build throws -- falling through to run the previous `.so` is exactly
# the "silently simulating last week's Verilog" failure this item exists to
# prevent.
proc ase::cosim_build {state map} {
  set res {}
  if {![llength $map]} { return $res }
  set mode [ase::cosim_policy $state build auto]
  if {$mode eq {never}} {
    foreach e $map { lappend res [list [dict get $e model] skipped "cosim build=never"] }
    return $res
  }
  set trace [expr {[ase::cosim_policy $state trace 1] eq {0} ? 0 : 1}]
  set script [ase::cosim_build_script]
  set shimdir [ase::cosim_shim_dir $script $trace]
  set rd [ase::rundir $state]
  foreach e $map {
    set model [dict get $e model]
    set so [ase::state_get $e so]
    set vfile [ase::state_get $e vfile]
    set local [ase::state_get $e local_so]
    if {$local eq {}} { set local [ase::cosim_so_local $so] }
    if {$local eq {}} {
      lappend res [list $model skipped "simulation=$so is not a run-directory .so\
 (Icarus arm, or a path ngspice opens directly) — not ASE's to build"]
      continue
    }
    # LOWER-CASED by cosim_so_local: ngspice folds `simulation="./Counter.so"` to
    # `./counter.so` and reports `d_cosim failed to load simulation binary
    # ./counter.so` (measured), so the file must exist under the folded name.
    set target [file join $rd $local]
    # NEVER ABORT THE RUN BECAUSE ASE CANNOT CHECK.  A code block one level down
    # in the hierarchy has no resolvable `.v` at all: `xschem instance_list`
    # enumerates the CURRENT schematic only (scheduler.c:6426-6440) while the
    # netlister hoists the `.model` card to the top of the deck
    # (spice_netlist.c:575-591), so the deck names a block the design walk never
    # saw. That was a working configuration before section E and must stay one:
    # ASE says what it cannot check and gets out of the way. If the `.so` really
    # is absent, ngspice itself reports `d_cosim failed to load simulation
    # binary` and E7's cosim_load matcher surfaces it.
    if {$vfile eq {} || $script eq {}} {
      set why [expr {$vfile eq {} ?
        "no verilog view resolved for '$model' (a code block below the top level\
 of the design is not reachable by the instance walk)" :
        "build_cosim_so.sh not found (set ::ASE_COSIM_BUILD)"}]
      lappend res [list $model unavailable "$why — $local is NOT being checked for\
 staleness; build it yourself if it is out of date"]
      continue
    }
    set stamp [ase::cosim_stamp $vfile $script $shimdir $trace]
    if {$mode ne {always} && ![ase::cosim_stale $target $stamp]} {
      lappend res [list $model uptodate [file tail $target]]
      continue
    }
    set cmd [list $script]
    if {$trace} { lappend cmd -V }
    lappend cmd -o $rd $vfile
    ::ase::echo "ase: building [file tail $target] from [file tail $vfile] (d_cosim model $model)"
    # {*} expands the list directly into words. `eval exec [linsert $cmd end
    # 2>@1]` would also work — Tcl's list quoting braces an element containing a
    # space, `$`, `;` or `[`, so it round-trips (checked, not assumed) — but it
    # only works because of that quoting, and one hand-built string in $cmd
    # would break it silently. {*} cannot be broken that way.
    if {[catch {exec {*}$cmd 2>@1} out]} {
      return -code error "ase: co-simulation build FAILED for '$model'\
 ([file tail $vfile]):\n$out"
    }
    # build_cosim_so.sh names the .so after the SOURCE FILE; the deck names it in
    # `simulation=`. Reconcile rather than fail: the two differ whenever the .v
    # basename is not the model/cell name.
    set produced [file join $rd "[file rootname [file tail $vfile]].so"]
    if {[file normalize $produced] ne [file normalize $target]} {
      if {![file isfile $produced]} {
        return -code error "ase: build of '$model' produced no $produced"
      }
      file copy -force -- $produced $target
    }
    if {![file isfile $target]} {
      return -code error "ase: build of '$model' produced no [file tail $target]"
    }
    if {![catch {open $target.stamp w} f]} { puts $f $stamp; close $f }
    lappend res [list $model built [file tail $target]]
  }
  return $res
}

# --- E5: the digital side of the deck ----------------------------------------

# The default adc/dac auto-bridge `pre_set`s for a mixed-signal deck. ngspice
# inserts an `auto_bridge` whenever a digital (event) node meets an analog one;
# without these two `pre_set`s it uses built-in thresholds that have nothing to
# do with the design's supply. Upstream's example hand-writes them into the
# testbench's `code_shown` block; ASE-L owns simulation config, so a state that
# has none and a deck that has d_cosim gets these (spec E5). A state that
# already carries an auto_bridge pre_set is left completely alone.
proc ase::cosim_default_bridges {state} {
  set v [ase::cosim_supply $state]
  return [list \
    "pre_set auto_bridge_d_in = ( \".model auto_adc adc_bridge( in_low = '0.9 * $v / 2'\
 in_high = '1.1 * $v / 2' rise_delay=1e-11 fall_delay=1e-11 )\" \"auto_bridge%d \[ %s \] \[ %s \] auto_adc\" )" \
    "pre_set auto_bridge_d_out = ( \".model auto_dac dac_bridge( out_low = 0 out_high = $v\
 t_rise=1e-11 t_fall=1e-11 )\" \"auto_bridge%d \[ %s \] \[ %s \] auto_dac\" )"]
}

# Does the design already configure the auto bridges by hand?
#
# BOTH places count. The state's `pre_commands` is where ASE-L keeps them and
# where the migrator put them -- but upstream's shipped testbench writes them
# into a `code_shown` block, i.e. into the NETLIST, and that text reaches
# render_deck as `netlist_text`. Checking only the state made ASE append its own
# defaults AFTER the design's, and the later `pre_set` wins (measured,
# ngspice-46), so a 3.3 V design silently got 1.8 V bridge thresholds.
proc ase::cosim_has_bridges {state {netlist_text {}}} {
  foreach pc [ase::state_get $state pre_commands] {
    set t $pc
    if {[llength $pc] >= 2 && [catch {dict exists $pc cmd} ok] == 0 && $ok} {
      set t [dict get $pc cmd]
    }
    if {[string first auto_bridge_d_ [string tolower $t]] >= 0} { return 1 }
  }
  if {[string first auto_bridge_d_ [string tolower $netlist_text]] >= 0} { return 1 }
  return 0
}

# --- E3: attach the analog raw AND every digital VCD -------------------------

# Load `rawfile` (as `sim_type`) plus every VCD in `vcdfiles` into the raw
# registry, leaving N DBs with the ANALOG one current.
#
# ORDERING, and why. `xschem raw read` APPENDS to xctx->extra_raw_arr[] and makes
# the file it just read CURRENT (save.c:1277-1280 / :1320-1323, verified
# empirically) -- so reading the raw and then two VCDs leaves a VCD current. Every
# existing consumer (annotate_op, `xschem raw value`, wviewer's add_trace) resolves
# names against the CURRENT DB and expects analog vector names, so the analog DB is
# switched back to explicitly. It is slot 0 because it is read first.
#
# PARTIAL RUNS. A missing/unreadable RAW returns 0 and clears NOTHING -- a
# stale-but-loaded DB beats an empty viewer, which is attach_raw's existing
# policy. A missing or unreadable VCD is skipped with a notice and does not stop
# the analog attach: an analog-only result is still a correct, useful result.
#
# Returns {n <dbs attached> current <index> vcds <attached> skipped <not>}.
# `xschem raw read` returns "1"/"0" WITHOUT throwing on a parse failure, so the
# return value is checked, not just the catch.
proc ase::attach_dbs {rawfile sim_type {vcdfiles {}}} {
  if {$rawfile eq {} || ![file isfile $rawfile]} {
    return [dict create n 0 current -1 vcds {} skipped $vcdfiles]
  }
  # READ FIRST, DROP THE OLD DBs AFTER. `xschem raw read` APPENDS and makes what
  # it read current (save.c:1277-1280), so the incoming raw can be validated
  # while the outgoing one is still loaded. Clearing first -- which is what
  # attach_raw did before section E -- destroys the previous DB and then leaves
  # an EMPTY registry when the new file exists but does not parse: a truncated
  # raw, or one whose requested analysis is not in it because the run died after
  # `op`. "A stale-but-loaded DB beats an empty viewer" is the stated policy;
  # this is the order that actually delivers it.
  # DROP ANY STALE COPY OF THE INCOMING FILE FIRST. `xschem raw read` does not
  # re-read a path already in the registry -- save.c:1335-1339, "file found:
  # switch to it", no disk access -- and the raw path is deterministic
  # (<rundir>/<cell>_ase.raw, overwritten in place by every run). Without this
  # targeted clear the SECOND attach of a session would switch to the DB read
  # from the FIRST run and plot last run's waveforms. (The old body was immune
  # only because it cleared the whole registry first, which is the behaviour the
  # read-before-clear order below is here to stop.)
  catch {xschem raw clear $rawfile $sim_type}
  if {$sim_type ne {}} {
    set ok [expr {![catch {xschem raw read $rawfile $sim_type} r] && $r eq {1}}]
  } else {
    set ok [expr {![catch {xschem raw read $rawfile} r] && $r eq {1}}]
  }
  if {!$ok} {
    return [dict create n 0 current -1 vcds {} skipped $vcdfiles]
  }
  # drop everything that is not the DB just read, HIGHEST INDEX FIRST: `raw
  # clear <n>` compacts the array, so removing a larger index never disturbs a
  # smaller one.
  set cur [ase::raw_current]
  foreach i [lsort -integer -decreasing [ase::raw_indices]] {
    if {$i == $cur} { continue }
    catch {xschem raw clear $i}
  }
  set got {}; set skipped {}
  foreach v $vcdfiles {
    if {$v eq {} || ![file isfile $v]} { lappend skipped $v; continue }
    if {[catch {xschem raw read $v vcd} r] || $r ne {1}} { lappend skipped $v; continue }
    lappend got $v
  }
  # the analog DB is slot 0: it is the only survivor of the loop above, and
  # `raw clear <n>` leaves extra_idx at 0 (save.c:1417-1421).
  if {[llength $got]} { catch {xschem raw switch 0} }
  return [dict create n [expr {1 + [llength $got]}] current 0 vcds $got skipped $skipped]
}

# The registry slot indices, and the current one; {} / -1 when nothing is
# loaded. `xschem raw info` prints "<cur> current" then one "<i> <path> <type>"
# line per slot (save.c:1469-1477) and nothing at all with no raw loaded.
proc ase::raw_indices {} {
  if {[catch {xschem raw info} txt] || $txt eq {}} { return {} }
  set out {}
  foreach line [lrange [split [string trimright $txt "\n"] "\n"] 1 end] {
    if {[regexp {^(\d+) } $line -> i]} { lappend out $i }
  }
  return $out
}
proc ase::raw_current {} {
  if {[catch {xschem raw info} txt] || $txt eq {}} { return -1 }
  if {[regexp {^(\d+) current} [lindex [split $txt "\n"] 0] -> i]} { return $i }
  return -1
}

# The VCD artifacts of session `key`'s last run that exist on disk (E3's input).
# Reads the run-directory map artifact, so it works in a fresh xschem session
# that never netlisted -- the same "file existence == has results" contract
# ase::last_rawfile uses. A `multi 1` entry is EXCLUDED: two shims writing one
# file produce an interleaved VCD that must not be presented as data.
proc ase::last_vcdfiles {key} {
  set state [ase::session_state $key]
  if {$state eq {}} { return {} }
  if {[ase::cosim_policy $state attach 1] eq {0}} { return {} }
  set out {}
  foreach e [ase::cosim_load_map $state] {
    if {[ase::state_get $e multi 0] eq {1}} { continue }
    set v [ase::state_get $e vcd]
    if {$v ne {} && [file isfile $v]} { lappend out $v }
  }
  return $out
}

# --- E7: report a desynchronized co-simulation honestly ----------------------

# Diagnostics extracted from a simulator log: a list of {severity code count
# message}. `error` means the run's numbers are WRONG, not merely noisy.
#
# The strings are the literals inside /usr/local/lib/ngspice/digital.cm (they are
# separate NUL-terminated literals, so the M9 diagnostic is a multi-line emission
# whose header `XSPICE time is behind vtime:` is the only reliable probe -- a
# regexp spanning the value lines would never match). ase's run_cmd folds stderr
# into stdout (`2>@1`), so a stderr-only diagnostic still reaches the log.
#
# `dump call ignored` is Verilator's own message and is NOT an error: the patched
# shim clamps a repeated/back-stepped dump to the previous time (M16/M9) and
# VerilatedVcd then declines the duplicate. The reference run emits 61 of them
# while producing a correct VCD, so it is reported as a note with a count.
proc ase::run_diagnostics {logtext} {
  set out {}
  # The patterns are LITERAL substrings, matched with a string-first loop rather
  # than `regexp -all`. Two reasons: the reference log is ~50 MB (issue 0278's
  # print flood), and six regexp passes over that is real wall clock for a scan
  # that must never be the reason someone turns diagnostics off; and a literal
  # scan cannot be broken later by a `.` or `(` sneaking into a message string.
  foreach {code sev pat msg} [list \
    cosim_desync error {XSPICE time is behind vtime:} \
      "the co-simulation DESYNCHRONIZED (ngspice stepped back and Verilator cannot\
 un-step): the digital waveforms do NOT match the analog ones" \
    cosim_past error {Warning simulated event is in the past:} \
      "a digital event was simulated in the past: co-simulation event ordering is broken" \
    cosim_out_past error {client simulator requested output in the past:} \
      "the co-simulator requested an output in the past: event ordering is broken" \
    cosim_portcount error {mismatched XSPICE/co-simulator} \
      "XSPICE and the co-simulator disagree on the port count: the block is wired wrong" \
    cosim_load error {failed to load simulation binary} \
      "ngspice could not load the d_cosim shared object" \
    cosim_dumpskip note {dump call ignored} \
      "repeated VCD dump requests at the same time were coalesced (expected; the\
 shim clamps non-monotonic dumps)"] {
    set n [ase::count_substr $logtext $pat]
    if {$n} { lappend out [list $sev $code $n $msg] }
  }
  return $out
}

# Occurrences of the literal substring `needle` in `hay`. `string first` is a
# C-level scan, so this stays linear over a multi-megabyte log.
proc ase::count_substr {hay needle} {
  set n 0
  set i 0
  while {[set i [string first $needle $hay $i]] >= 0} { incr n; incr i }
  return $n
}

# The `error`-severity diagnostics of the most recent completed run.
proc ase::last_diagnostics {} {
  variable last_run
  if {[dict exists $last_run diagnostics]} { return [dict get $last_run diagnostics] }
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

# Ctrl-Alt-V / Tools > "Show in Signal Browser" — THE MIRROR of the waveform
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
# --- ITEM 17: THE SELECTION IS THE DIRECT OBJECT ------------------------------
#
# The schematic's selection, reduced to the ONE question "Show in Signal
# Browser" asks of it — which single instance, if any, should extend the
# hierarchy path?
#
#   {ok <name>}   exactly one instance is selected; <name> is the SCHEMATIC's
#                 own spelling, passed through verbatim
#   {none}        nothing selected, or the read failed — the caller keeps its
#                 pre-item-17 answer, the hierarchy position
#   {many <n>}    two or more (ruling 2)
#
# ⚠ THE NAME IS NOT CASE-FOLDED HERE, and that is a decision. `browser_node_for`
# (wave_viewer.tcl:9325) already matches each segment EXACT-first with a
# `string equal -nocase` fallback — which is how BX42 lands a schematic `X1.X2`
# on the raw's `g:x1.x2` today. Folding here as well would be a SECOND answer to
# one question, and on this very fixture (which carries both `X1` and `x1`) the
# two answers can differ: an exact hit must keep winning.
#
# ⚠ `-type instance`, NOT the bare selection. A rubber band takes wires and text
# with it, and a WIRE contributing a segment would put a net name into a
# hierarchy path. `xschem objects` documents its row shape at scheduler.c:8466 —
# `{type T index I layer C id ID name {N}}` — so the name is a dict key and no
# `getprop`/`get_tok` round trip is needed. (`xschem selected_set` answers names
# directly and would also do; `objects` is used because it is the reader
# `slickprop::selected_inst_ids` already established for this question.)
#
# NEVER THROWS: it rides a menu/key path, and a Tcl error there pops bgerror,
# which is modal under X.
proc ase::browser_sel_segment {} {
  set sel {}
  if {[catch {xschem objects -type instance -selected} sel]} { return [list none] }
  set n [llength $sel]
  if {$n == 0} { return [list none] }
  if {$n > 1}  { return [list many $n] }
  set nm {}
  catch {set nm [dict get [lindex $sel 0] name]}
  # an instance with no `name=` token answers `{}` (instname is "" and never
  # NULL — actions.c:989 uses my_strdup2), and an empty segment would match the
  # ROOT rather than nothing. `none` is the honest reduction of it.
  if {$nm eq {}} { return [list none] }
  return [list ok $nm]
}

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
  # 3b. ITEM 17: THE SELECTION EXTENDS THE PATH.
  #
  # ⚠⚠ IT IS READ HERE, IN THE DESIGN CONTEXT, FOR STEP 2's REASON AND A WORSE
  # FAILURE MODE. `wviewer::open` and the sidebar show both MOVE the xschem
  # context to the viewer window; `xschem objects -selected` read there answers
  # about the VIEWER's own untitled buffer, which has no instances at all — so a
  # read placed after the raise degrades silently to `none` and the whole item
  # does nothing, while every check that drives the reducer directly stays
  # green. Moving this call below step 4 is a declared sabotage.
  #
  # ⚠ AFTER the `$drop` trim, never before. The drop takes ANCESTOR segments off
  # the FRONT (the raw was read above this window's position); the selection
  # appends at the END. Appending first would feed the selected instance to the
  # origin mapping and eat it whenever drop > 0 — BX48's level>0 case.
  set base $segs
  set selname {}
  set selr [ase::browser_sel_segment]
  switch -- [lindex $selr 0] {
    ok {
      set selname [lindex $selr 1]
      lappend segs $selname
    }
    many {
      # RULING 2. The lower pane shows ONE level, so N targets is not a question
      # it can answer — the same reasoning `browser_sea_target_path` uses when
      # it refuses two cells at different levels rather than picking first-won.
      #
      # ⚠ THE SENTENCE NAMES BOTH HALVES, and that is the ruling too: what was
      # ambiguous AND what was done instead. A notice that reports only the
      # ambiguity is a warning the user cannot act on. NO `error` tag — this is
      # a comment about an ambiguous request, not a failure, and the tag is what
      # picks `log_action -error` over `-result`.
      set where [expr {[llength $base] ? "[join $base .]" : {the design root}}]
      catch {::ase::echo "ase: signal browser: [lindex $selr 1] instances are\
 selected and the lower pane shows one level, so ignoring the selection and\
 showing $where instead"}
    }
  }
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
  # 6b. RULING 1's LAST MILE, and it is NOT redundant with `partial`.
  #
  # `browser_show_path` lands on the deepest ancestor that exists and reports
  # `partial` — but only when AT LEAST ONE segment matched. A non-hierarchical
  # instance picked at the TOP level makes the whole path a single unresolvable
  # segment, so `matched` is 0 and the answer is `err` with the selection left
  # alone (wave_viewer.tcl:9513-9521). That is not "land on the parent".
  #
  # So: when the SELECTION is what extended the path and the extended path
  # resolved nothing, ask again WITHOUT it. The retry is confined to that case —
  # a path that failed on its own merits still fails, because that is the user's
  # own hierarchy position and there is nothing better to show.
  if {$selname ne {} && [lindex $res 0] eq {err}} {
    set res [wviewer::browser_show_path $key [join $base .]]
    set where [expr {[llength $base] ? "[join $base .]" : {the design root}}]
    catch {::ase::echo "ase: signal browser: '$selname' has no level in the\
 simulation data; showing $where instead"}
  }
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
    # Mixed-signal (spec E2): give every `.model <m> d_cosim` card a VCD of its
    # own inside the run directory. The card reaches us verbatim in the circuit
    # netlist (spice_netlist.c:575-591 emits it just before `.end`, which the
    # strip above has already removed), and it is the ONLY place the digital
    # artifact's path can be set — `sim_args[0]` is what the shim opens.
    # `simulation=` is deliberately NOT touched: it is the user's choice of
    # backend (`./counter.so` vs upstream's `ivlng` Icarus arm).
    # Empty for any analog deck, so this is inert unless a code block exists.
    set cosim [ase::cosim_map $state $netlist_text]
    if {[llength $cosim]} { set lines [ase::cosim_rewrite $lines $cosim] }
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
    # Mixed-signal (spec E5): the adc/dac auto-bridge models are simulation
    # config, so ASE-L owns them. ngspice inserts an `auto_bridge` wherever a
    # digital (event) node meets an analog one; with no `pre_set` it uses
    # built-in thresholds unrelated to the design's supply. The migrator only
    # ever CARRIED these out of upstream's `code_shown` block, so a hand-built
    # mixed-signal state had none at all. Emitted only when the deck really has
    # a code block AND the state configures no bridge of its own — a state that
    # hand-writes them is left completely alone. `cosim bridges 0` opts out.
    if {[llength $cosim] && ![ase::cosim_has_bridges $state $netlist_text] &&
        [ase::cosim_policy $state bridges auto] ne {0}} {
      foreach b [ase::cosim_default_bridges $state] { lappend lines $b }
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
