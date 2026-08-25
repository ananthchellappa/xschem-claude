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
                        save_op_params
                        options includes pre_commands cosim viewer}
  # Schema keys the serializer OMITS when empty. Every v1 key is written even
  # when empty because every state file on disk already carries it; a key added
  # LATER must not rewrite files that predate it — `state_load` merges over
  # state_default, so an old file would otherwise gain `cosim {}` and stop
  # round-tripping byte-identically (which two committed-golden tests assert,
  # and which is what keeps a `git diff` of a state view meaningful). Empty
  # carries no information here: `cosim {}` means exactly "every default".
  # `save_op_params` (plan step S4 / issue 0617) is the THIRD Save-All blanket:
  # the gate that lets ase::netlist capture op_annot::save_cards and render_deck
  # carry the device operating-point `.save` cards into the deck. It joins
  # `cosim` here for exactly the same reason and it MUST default to `{}` rather
  # than `0`: state_serialize writes every non-empty schema key, so a `0`
  # default would land in all 104 committed .state files and break the five
  # load->save byte-identity rows (F3/G3/R4/V4/R2). `{}` = off, `1` = on.
  variable omit_if_empty {cosim save_op_params}
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
# sourced 52 lines AFTER this file (xschem.tcl:14854 vs :14802), so a future SOURCE-TIME
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
# --- 0650: ONE builder, and this is no longer it -----------------------------
# Everything above still describes the BODY -- it just lives in
# `xschem::notify` (src/ciw.tcl) now, moved verbatim, because the channel had
# TWO byte-identical builders before this step (this proc and wviewer::echo,
# src/wave_viewer.tcl:750) and invariant I1 forbids exactly that. ase::echo
# keeps its name, its `{msg {tag {}}}` signature and its 61+ call sites; the
# remedy fields (-menu/-command), the short form and the state-keyed latch are
# reached by calling ::xschem::notify DIRECTLY at the sites that have something
# to say with them (ase::op_cards_capture is the first).
#
# ⚠ ciw.tcl is sourced AFTER this file (src/xschem.tcl:14854 vs :14802), so this
# resolves ::xschem::notify at CALL time and a SOURCE-TIME ase::echo would fail.
# No call site makes one. Catch'd for the same reason both halves always were:
# a broken message may never break a pick or a netlist -- see 0658 below for
# what that catch was quietly costing.
## ⚠ 0658: the catch that used to live here HID the defect. `::xschem::notify`
## lives in src/ciw.tcl, which src/xschem.tcl sources AFTER this file, so one
## unavailable proc in another file turned every call site into a silent no-op
## -- the durable log line included, and that line had been INLINE here before
## 0650. The body is now `::xschem::notify_safe` (src/xschem.tcl, defined before
## every caller): it still never propagates -- a notice may not break a pick or
## a netlist -- but a raise now falls back to the degraded bootstrap channel
## instead of returning a silent, untrue 0. ONE delegate body, shared with
## wviewer::echo, which is what invariant I1 asks for.
##
## ⚠ ISSUE 0666: THE GUARANTEE IS BACK IN THIS BODY. 0658's brief said "a notice
## must never break its caller"; the catch was not deleted, it MOVED into the
## callee, and this line became a bare one-liner that raises `invalid command
## name "::xschem::notify_safe"` straight into a pick or a netlist the moment
## the delegate body is not there.
##
## REACHABILITY, MEASURED, AND NARROWER THAN 0666 CLAIMED: the FILE-LOAD path is
## CLOSED by issue 0663 (src/xinit.c:3571 -- a partially loaded xschem.tcl now
## exits 1 with an announced STARTUP ABORTED), and notify_safe is defined before
## this file is sourced, so no ordering can leave the delegate without it. What
## IS live is a RUNTIME `namespace delete ::xschem`: it succeeds, takes the
## namespace from 13 procs to 0, leaves the C `xschem` command working, and is
## reachable from ciw_exec's `uplevel #0 $cmd` (src/ciw.tcl:557) and from any
## --script. Hence a two-line guard here, and NOT a loader-level one.
##
## The guard is INLINE in each delegate on purpose, four lines duplicated
## deliberately: extracting it into a shared proc would put it in the very
## namespace whose absence it exists to survive (0666: "a guard is not a
## builder"). What it returns is TRUE (0652): nothing reached any sink, and
## stderr is never counted as one (0658 D9), so 0 is the honest answer -- never
## a 0 that merely means "I did not check".
proc ase::echo {msg {tag {}}} {
  if {[catch {::xschem::notify_safe $msg $tag} r]} {
    catch {puts stderr "xschem: notice channel unavailable: $r" ; flush stderr}
    return 0
  }
  return $r
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

# The gate-off OP-card nudge (ase::op_cards_capture): 1 = say it once per design
# cellview per session, 0 = never. Issue 0636 — measured, the shipped version
# fired on EVERY op netlist with no opt-out: three identical lines into the CIW
# pane and the action log, in one session, about one cell, advertising an opt-in
# feature the user may have deliberately declined. On by default, because a user
# who has NOT declined it is the one issue 0617 was filed by.
set_ne ase_op_card_nudge 1

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
    save_op_params {} \
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

# --- The op_annot device-OP save cards: capture at netlist, consume at render -
#
# doc/claude/specs/op_annotation.md section 3 + plan step S4, issue 0617. The
# user's report: enable ONLY the OP analysis, Netlist and Run, press 6 -> six
# blank rows. The raw was correct; the DECK never asked. `save all` does not
# include gm/gds/vth/vdsat/cgg (rule R1) — one explicit card per device per
# parameter is the only way, and `op_annot::save_cards` (src/op_annot.tcl)
# already builds exactly that block. Nothing carried it into the deck.
#
# ⚠ WHY THE CARDS ARE BUILT AT NETLIST TIME AND NOT INSIDE render_deck.
# Every card op_annot emits is ENTRY-RELATIVE: `deck`-based, rooted at the cell
# you are standing in (ruling D2 / issue 0436). `ase::netlist` is the ONE path
# whose context guard proves the design IS the current schematic, so it is the
# one place that precondition holds. Measured on this tree: standing in
# `bandgap_opamp` and calling save_cards yields 103 cards rooted at the WRONG
# cell, which name nothing in a `tb_bandgap` deck — and a card that names
# nothing fails SILENTLY (rc=0, raw written, zero device vectors, empty stderr:
# spec landmine 2). A user pressing Run would get a green run and blank rows,
# which is issue 0617 again with the feature nominally on. Building here also
# keeps the hierarchy walk out of render_deck entirely, so the many suites that
# call render_deck directly with a fixture string can never trigger one.
#
# The cache is keyed on the EXACT netlist text, not on a path + mtime: exact,
# no 1-second-mtime hazard, no path arithmetic inside the backend, and it makes
# the whole feature inert for a hand-written fixture string.
#
#   ase::run             -> ase::netlist -> capture -> render_deck : always a HIT
#   ase::run_existing    -> no netlist; HIT iff the artifact's text is still the
#                           one that was captured (Netlist > Recreate then Run),
#                           MISS + a reported error otherwise. run_existing has
#                           no current-schematic guard and is documented to work
#                           with the design window closed, so emitting there
#                           unconditionally is the silent-wrong-basis defect
#                           above.
#
# {netlist <exact artifact text> block <the save block>}; empty = nothing held.
namespace eval ase { variable op_cards [dict create] }

# Empty the slot. Called first on EVERY capture so a previous cell's block can
# never leak into another design's deck.
proc ase::op_cards_clear {} {
  variable op_cards
  set op_cards [dict create]
}

# The priming seam (also what the tests drive directly).
proc ase::op_cards_put {netlist_text block} {
  variable op_cards
  set op_cards [dict create netlist $netlist_text block $block]
}

# 1 iff the slot holds a record built from EXACTLY this netlist text. This is
# the staleness guard, and it is separate from op_cards_for because a HIT whose
# block is EMPTY ("nothing below this cell is annotatable") and a MISS ("this
# artifact is not the one that was captured — re-netlist") are different user
# situations that need different sentences.
proc ase::op_cards_hit {netlist_text} {
  variable op_cards
  if {![dict exists $op_cards netlist]} { return 0 }
  return [expr {[dict get $op_cards netlist] eq $netlist_text ? 1 : 0}]
}

# The block captured for exactly this netlist text; {} on a miss.
proc ase::op_cards_for {netlist_text} {
  variable op_cards
  if {![ase::op_cards_hit $netlist_text]} { return {} }
  return [dict get $op_cards block]
}

# --- 0635: a refusal must leave a RECORD -------------------------------------
# MEASURED: a refusal echoed TWO sentences and the second contradicted the first
# — capture said "Save the schematic, then netlist again." and render_deck then
# said "Use Simulation > Netlist and Run to regenerate both together.", about an
# artifact THIS SESSION had just written. The mechanism is that every refusal
# returned WITHOUT calling op_cards_put, so `op_cards_hit` read 0 and
# render_deck's stale arm — which exists for a genuinely FOREIGN artifact, the
# ase::run_existing shape — fired on a local one.
#
# THE FIX IS AT THE CAPTURE END, and it is one call before each early return: a
# record for exactly this netlist text with an EMPTY block. That is the truth —
# "this artifact was seen by this session and produced no cards" — and it is
# already a state both readers understand: op_cards_for still answers {} for a
# HIT whose block is empty (so nothing is appended to the deck), while
# op_cards_hit answers 1 (so the staleness complaint stays silent). A genuinely
# DIFFERENT artifact still misses and is still reported, which is what keeps the
# stale arm meaningful rather than merely quiet.
#
# Never raises: the artifact may be unreadable, and a refusal path is the last
# place that should turn into an error.
proc ase::op_cards_note_refusal {netlistpath} {
  if {[catch {open $netlistpath r} f]} { return 0 }
  if {[catch {read $f} text]} { catch {close $f} ; return 0 }
  catch {close $f}
  ase::op_cards_put $text {}
  return 1
}

# --- 0636: the gate-off nudge fires ONCE per design cellview per session ------
# The latch, keyed on lib/cell/view. `ase::netlist` is called by the netlist
# action, by ase::run, and by anything that re-netlists — measured at three
# times in one session on one cell — and the nudge has nothing new to say the
# second time.
## 0650: THE STORAGE MOVED. R-0653-c says to GENERALISE this latch, not to write
## a second one, so it is now xschem::notify_latch_* (src/ciw.tcl) keyed on
## {subject state} with subject `opcards`. The three procs below keep their
## names, their signatures, the `::ase_op_card_nudge` off switch and
## op_cards_nudge_reset as the test seam -- only the dict went away.

# The test seam, and the honest way to re-arm it for a user who wants reminding:
# forget every cellview already nudged.
proc ase::op_cards_nudge_reset {} {
  ::xschem::notify_latch_reset opcards
}

# --- 0648: ONE gate normaliser, ONE latch-key builder ------------------------
# `save_op_params` is read as a gate in THREE places — op_cards_capture's
# `ne {1}`, render_deck's `eq {1}` and (new) the change detector below. Two
# independent normalisations of one key already existed and drift between them
# fails SILENTLY; issue 0637 is the standing proof it bites here. Invariant I1
# (one builder, many consumers) applied to a gate rather than a vector name.
#
# ⚠ 1 IFF THE VALUE IS LITERALLY `1`. `0`, `{}`, absent and truthy-not-1
# (`yes`, `true`, `2`) all read OFF — exactly as both existing call sites read
# today. Do NOT "improve" this to accept truthy values: that would silently
# decide issue 0637, whose ruling is with the user, and it would flip the gate
# for any state hand-edited to `save_op_params yes`.
proc ase::op_gate_on {v} {
  return [expr {$v eq {1} ? 1 : 0}]
}

# The latch key: this state's DESIGN cellview, {lib cell view}. Lifted out of
# op_cards_nudge_ok so the re-arm below cannot rebuild it independently — a
# re-arm that unsets a key nobody ever takes looks like a working fix and
# nudges nothing (I1 again, and the drift would be silent).
proc ase::op_cards_nudge_key {state} {
  set k {}
  catch {
    set d [ase::state_get $state design]
    set k [list [ase::state_get $d lib] [ase::state_get $d cell] \
                [ase::state_get $d view]]
  }
  return $k
}

# THE KEY THE PRINTED REMEDY NAMES (issue 0679) -- a LOOKUP IN THE REGISTRY,
# never a second construction of a key.
#
# ⚠ THIS IS NOT op_cards_nudge_key ABOVE, AND THE TWO MUST NOT BE MERGED.
# op_cards_nudge_key is the 0648 LATCH key: this state's DESIGN cellview,
# {lib cell view} with view `schematic`, consumed at :622 (re-arm) and :654
# (take) and pinned by test_ase_final F19f. Re-scoping it is the defect 0648
# was filed for. A SESSION, meanwhile, is registered under the STATE view --
# `ase::session_key $lib $cell $view` in ase::open_state (~:2798), view
# `ngspice_state1`.
#
# Issue 0679 is what happened when the remedy built its key from the first of
# those while the registry held the second. Measured on the user's bench:
#   REGISTERED: sky130_tests_ase/tb_bandgap/ngspice_state1
#   REMEDYKEY : sky130_tests_ase/tb_bandgap/schematic
# The notice printed `ase::ui::save_op_params_on <lib>/<cell>/schematic`,
# ciw_exec (ciw.tcl:598 `uplevel #0 $cmd`) executed it against a key nobody was
# ever under, and the proc it called reported success anyway. Two independent
# CONSTRUCTIONS of one key -- invariant I1 one level up -- and the drift was
# silent. A lookup cannot drift from the registry, because it reads it.
#
# Resolution order, AND IT REFUSES TO GUESS:
#   1. exactly one session whose live state IS this state  -> that key;
#   2. else exactly one session on this state's design cellview -> that key;
#   3. else {} -- and op_cards_capture then prints the menu path with NO CIW
#      command. R-0653-d req 2's own sentence, "a wrong direction printed with
#      authority is worse than printing none", was written about the menu path;
#      it governs the command field at least as hard, because ciw_exec makes
#      the command the executable one of the two.
# Never raises: the whole body is caught and falls back to {}.
proc ase::op_cards_remedy_key {state} {
  set k {}
  catch {
    set hit [ase::sessions_for_state $state]
    if {[llength $hit] != 1} {
      set hit [ase::sessions_for_design {*}[ase::op_cards_nudge_key $state]]
    }
    if {[llength $hit] == 1} { set k [lindex $hit 0] }
  }
  return $k
}

# Give this state's cellview its turn back. Never raises, idempotent, and it is
# NOT op_cards_nudge_reset — that forgets EVERY cellview and stays the test
# seam. Writes nothing into the state (the `{}`-never-`0` landmine).
proc ase::op_cards_nudge_rearm {state} {
  catch { ::xschem::notify_latch_rearm opcards [ase::op_cards_nudge_key $state] }
  return
}

# Did the user actually move the OP-card gate? Its own proc so the guard is
# independently testable and neutralizable — session_update fires on EVERY
# pane mutation (toggle_flag, variables, outputs, analyses, temperature) and an
# unconditional re-arm there re-creates 0636's three-lines-per-session noise.
proc ase::op_cards_gate_changed {old new} {
  return [expr {[ase::op_gate_on $old] != [ase::op_gate_on $new]}]
}

# 1 iff this state's design cellview may be nudged NOW — and if so the latch is
# taken, so the answer is 1 exactly once per cellview per session. Called ONLY
# where the nudge is actually about to be echoed (never as one term of a wider
# condition), so a state that fails an earlier gate does not silently consume
# its one turn.
#
# ⚠ 0648: "once per cellview per SESSION" is not the whole rule any more. The
# turn is given back when the user ACTS on the setting — a save_op_params
# change through ase::session_update, or an opparams tick DISCARDED by the Save
# All dialog. The gate's VALUE cannot be the trigger: in the user's reported
# sequence the gate is OFF on both runs (the tick never committed), so
# (cellview, off) would be the same key twice and run 2 would still be silent.
proc ase::op_cards_nudge_ok {state} {
  if {[info exists ::ase_op_card_nudge]} {
    if {[catch {expr {$::ase_op_card_nudge ? 1 : 0}} on]} { set on 1 }
    if {!$on} { return 0 }
  }
  ## 0650: the take is the generalised latch's, keyed on (opcards, cellview).
  ## The off switch above stays HERE and is deliberately NOT expressed as
  ## notify's `-once`: -once would bypass ::ase_op_card_nudge entirely.
  return [::xschem::notify_latch_ok opcards [ase::op_cards_nudge_key $state]]
}

# How many device OP save cards a block carries. Named callee so the success
# sentence at the bottom of op_cards_capture has something a sabotage can
# neutralize — the count is the only part of that line that can lie.
proc ase::op_cards_count {block} {
  set n 0
  foreach l [split $block "\n"] { if {[string match {.save @*} $l]} { incr n } }
  return $n
}

# Does the design buffer carry unsaved edits? Exactly `xschem get modified`,
# normalised to 1/0 and safe when the command is unavailable.
proc ase::design_is_dirty {} {
  if {[catch {xschem get modified} m]} { return 0 }
  if {$m eq {} || $m eq {0}} { return 0 }
  return 1
}

# Does this state enable an `op` analysis? (The discoverability nudge fires on
# exactly the configuration issue 0617 was reported from; a tran/ac/digital
# user never sees it.)
proc ase::op_analysis_enabled {state} {
  foreach a [ase::state_get $state analyses] {
    if {[ase::state_get $a type] eq {op} && [ase::state_get $a enabled 0] eq {1}} {
      return 1
    }
  }
  return 0
}

# ALL the policy lives here. Called from ase::netlist right AFTER the artifact
# is written. Never raises: an annotation extra may not break Netlist-and-Run
# (ase_window.tcl:3806/:3818 turn any raise into a red session status, so a
# propagated op_annot refusal would break the run itself for an opt-in feature).
# Every degraded path is REPORTED through ase::echo — under-emission in silence
# is the exact failure class this whole feature exists to delete.
proc ase::op_cards_capture {state netlistpath} {
  ase::op_cards_clear
  set have [expr {[info commands ::op_annot::save_cards] ne {}}]
  if {![ase::op_gate_on [ase::state_get $state save_op_params {}]]} {
    # THE GATE DEFAULTS OFF, so it has to be discoverable. 468 cards on a
    # 31-FET bench (~3000 on a 500-device block, issue 0620) is a real deck
    # cost, and two committed byte-exact deck goldens would redden on an
    # unconditional emit. One line, only when an `op` analysis is enabled.
    ## ⚠ THE LATCH IS CONSULTED LAST AND ONLY HERE (issue 0636). A state that
    ## fails the `op`-analysis gate must not consume its cellview's one turn,
    ## so the two gates are NESTED rather than &&-ed into one condition.
    if {$have && [ase::op_analysis_enabled $state]} {
      if {[ase::op_cards_nudge_ok $state]} {
        ## 0650 / R-0653-d: A NOTICE THAT REPORTS A NON-DELIVERY MUST CARRY THE
        ## REMEDY, and the remedy travels as FIELDS, never as prose. The shipped
        ## sentence said "Tick Outputs > Save All > Save device OP parameters",
        ## which already dropped the menu entry's ellipsis AND the checkbutton's
        ## parenthetical -- a wrong direction printed with authority, which is
        ## worse than printing none. The path now comes from the same three label
        ## constants the menu and the dialog are BUILT from (invariant I1 applied
        ## to a label), and the command is the one the menu's OK path calls, so a
        ## test can EXECUTE it rather than string-compare it.
        ## ⚠ 0679: THE KEY IS LOOKED UP IN THE REGISTRY, NOT REBUILT HERE.
        ## `ase::session_key {*}[ase::op_cards_nudge_key $state]` -- what this
        ## line used to be -- names the DESIGN cellview while every session is
        ## registered under its STATE view, so the printed command addressed a
        ## key no session was ever under. See ase::op_cards_remedy_key (~:617)
        ## for why op_cards_nudge_key must NOT be retargeted instead.
        set opk [ase::op_cards_remedy_key $state]
        set opcmd {}
        if {$opk ne {}} { set opcmd [list ase::ui::save_op_params_on $opk] }
        set opmenu {}
        catch { set opmenu [ase::ui::remedy_op_params_menu] }
        ## ⚠ CAUGHT (issues 0664/0665, decision D10). This is a DIRECT call
        ## on the channel, not a delegate call, so notify_safe's guarantee does
        ## not cover it -- and src/ase.tcl:802's `catch {ase::op_cards_capture
        ## ...}` would swallow a raise here TOGETHER WITH THE ENTIRE OP-CARD
        ## BLOCK, silently killing the user's actually-reported 0617 nudge.
        ## 0665's fix adds a statement to the channel's ENTRY, so the hazard is
        ## one this change creates. notify_safe is NOT the answer here: it drops
        ## -short/-menu/-command, which R-0653-d keeps as distinct fields. The
        ## general class (every direct ::xschem::notify site carrying a remedy
        ## has no safe wrapper) is issue 0674.
        catch {
          ::xschem::notify "ASE: device operating-point parameters (gm, gds,\
 vth, ...) were NOT saved in this deck (issue 0617)." \
            -short {no OP params saved} -menu $opmenu -command $opcmd
        }
      }
    }
    return {}
  }
  if {!$have} {
    ase::op_cards_note_refusal $netlistpath   ;# 0635: ONE sentence, not two
    ase::echo "ASE: save_op_params is on but op_annot::save_cards is not\
 available in this session; no device OP save cards were added to the deck." error
    return {}
  }
  # ⚠ THE PROVISIONAL 0632 REFUSAL. On a DIRTY entry buffer the op_annot walk
  # rewrites the `~.sch` autosave backups of ancestor cells the user never
  # touched (issue 0632) — and over a stale one it silently drops cards (0628).
  # That ruling is with the user and is not this step's to make, so the ASE path
  # takes the SAFE side: it does not walk, and it says why. Recorded as
  # provisional in doc/claude/issues/0633-*.md.
  if {[ase::design_is_dirty]} {
    ase::op_cards_note_refusal $netlistpath   ;# 0635: ONE sentence, not two
    ase::echo "ASE: no device OP save cards were added — this schematic has\
 unsaved edits, and walking a dirty sheet rewrites the `~` autosave backups of\
 ancestor cells you never touched (issue 0632, ruling pending). Save the\
 schematic, then netlist again." error
    return {}
  }
  if {[catch {::op_annot::save_cards} block]} {
    ase::op_cards_note_refusal $netlistpath   ;# 0635: ONE sentence, not two
    ase::echo "ASE: no device OP save cards were added — $block" error
    return {}
  }
  # The under-emission channel: op_annot counts what it could not name and only
  # write_save_file ever consumed it. An ASE deck needs it more, not less.
  if {[info commands ::op_annot::last_warnings] ne {}} {
    foreach w [::op_annot::last_warnings] {
      ase::echo "ASE op cards: [string map [list \n { } \r { }] $w]" error
    }
  }
  ## The record is stored even when the block is EMPTY. An empty block is a
  ## real answer — "nothing below this cell is annotatable" — and it is not the
  ## same situation as "this deck was rendered from an artifact nobody
  ## captured". render_deck must be able to tell them apart to report them
  ## apart, and op_cards_hit is what lets it.
  set f [open $netlistpath r]
  set text [read $f]
  close $f
  ase::op_cards_put $text $block
  if {$block eq {}} {
    ase::echo "ASE: no device below this cell produced an OP save card — no\
 registered op_annot PDK descriptor matched, or nothing below it is\
 annotatable. The deck asks for no device parameters." error
    return {}
  }
  ase::echo "ASE: [ase::op_cards_count $block] device OP save card(s) added to\
 the deck."
  return $block
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
  ## THE OP-CARD CAPTURE, HERE AND ONLY HERE (plan step S4 / issue 0617).
  ## AFTER the artifact is written, so the oracle's own forced netlist settings
  ## (op_annot.tcl:1294-1362) cannot perturb the deck the user is about to
  ## simulate; and inside the guard above, which is what proves the design IS
  ## the current schematic — the precondition the entry-relative card basis
  ## needs. Never raises (op_cards_capture catches everything), so an
  ## annotation extra can never break Netlist-and-Run.
  catch {ase::op_cards_capture $state $nl}
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

  ## --- 0618: the log's provenance ------------------------------------------
  ## MEASURED BEFORE THE CHANGE: `string equal $logtext $::execute(data,last)`
  ## was 1 — the log file WAS the simulator's stdout and nothing else, and a
  ## user reading it a week later could not tell which command produced it,
  ## from which directory, over which deck, with what exit code, or how long it
  ## took. FOUR of those five are already in hand right here (deckpath, logpath,
  ## cmd, and the `cd $rd` directory) and were simply thrown away; only the
  ## elapsed time needs a new stamp, and it MUST be taken here and CARRIED —
  ## ase::run_done fires from execute_fileevent on EOF, so a stamp taken there
  ## measures the wrong interval entirely.
  ##
  ## ⚠ THE HEADER IS WRITTEN HERE, BEFORE THE LAUNCH, AND THAT IS THE POINT.
  ## Measured, a failed run splits in two: a failed LAUNCH (`execute` returns
  ## -1, a missing binary) raises out of this proc and run_done NEVER FIRES, so
  ## the old code left NO log file at all — in precisely the case a user
  ## debugs. run_done then REWRITES the whole file (mode `w`, unchanged
  ## truncation semantics), so nothing accumulates.
  ##
  ## ⚠ THE COMMAND IS RECORDED AS THE EXACT ARGUMENT LIST HANDED TO `execute`,
  ## `2>@1` included and argv0 unresolved. auto_execok-resolving it would be a
  ## SECOND source of truth about which binary ran, computed at a different
  ## instant from the exec that ran it.
  set meta [dict create cell $cell simulator $sim cmd $cmd dir $rd \
                        deck $deckpath started [clock seconds] \
                        t0 [clock milliseconds]]
  catch {ase::run_log_write $logpath $meta {} {}}

  set ::execute(callback) [list ase::run_done $logpath $state $callback $meta]
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

# --- 0618: the simulation log's framing --------------------------------------
# A header before the simulator's output and a footer after it, both clearly
# delimited, so the log is a record of the RUN and not merely of the run's
# chatter. Split into three tiny procs because each is a separate claim a test
# can pin, and because ase::run_log_body is the one that must never do anything.

# The five facts, as the file's opening block. Ends with the delimiter line, so
# a caller that has nothing else to write (the pre-launch call) still produces a
# file that reads as a complete header.
proc ase::run_log_header {meta} {
  set when {}
  catch {set when [clock format [ase::state_get $meta started [clock seconds]]]}
  set out "=== ase run [ase::state_get $meta cell] $when ===\n"
  append out "simulator : [ase::state_get $meta simulator]\n"
  append out "command   : [ase::state_get $meta cmd]\n"
  append out "directory : [ase::state_get $meta dir]\n"
  append out "deck      : [ase::state_get $meta deck]\n"
  return $out
}

# ⚠ THE SIMULATOR'S OWN REGION, AND IT IS THE LANDMINE THAT MATTERS MOST IN
# 0618. ase::run_done parses $data for results and the `result_probe` backend
# hook reads it; the framing goes in the FILE and the simulator's bytes must
# come through UNTOUCHED. No trim, no re-wrap, no line ending fixed up, no
# "helpful" blank-line collapse. This proc exists so that requirement has a
# name, one call site and a test row of its own.
proc ase::run_log_body {data} {
  return $data
}

# The footer. The framing owns the newline that ENDS the simulator's region:
# `$data` may end with a newline or not, and may be empty, and in all three
# cases the footer must start its own line while the region above it stays
# byte-exact.
#
# ⚠ SECONDS TO TWO DECIMALS, not one. A simulator that gives up in 40 ms is the
# signal a user is looking for when they open this file, and `%.1f` renders it
# as `0.0 s`. Elapsed is measured from the stamp run_deck took immediately
# before `eval execute`, never recomputed here: run_done fires on EOF.
proc ase::run_log_footer {meta exitcode} {
  ## ⚠ NO `string is integer` GUARD HERE, and that is not laziness. Measured
  ## while implementing: `clock milliseconds` is a WIDE integer (1.7e12) and
  ## `string is integer -strict` is a 32-bit test that answers 0 for it, so a
  ## guarded version silently printed `0.00 s` for every run — an elapsed time
  ## that is always zero is a fabricated number, not a missing one (I3's shape).
  ## The catch is the guard: a missing or non-numeric stamp raises out of `expr`
  ## and leaves 0.0, which is the only case where zero is the truth.
  set secs 0.0
  catch {
    set secs [expr {([clock milliseconds] - [ase::state_get $meta t0]) / 1000.0}]
    if {$secs < 0} { set secs 0.0 }
  }
  return [format "\n=== exit %s after %.2f s ===\n" $exitcode $secs]
}

# Write the log. `w` in every case, so a run's log is that run's whole record
# and nothing accumulates across the two calls (header-only before the launch,
# then the complete file on completion).
#
# ⚠ AN EMPTY <meta> WRITES $data WITH NO FRAMING AT ALL, byte-identical to what
# this proc's ancestor wrote. That is what keeps the three-argument
# `ase::run_done` shape (tests/headless/test_ase_cosim.tcl drives it at six
# sites) meaningful: with no metadata there is nothing truthful to frame with,
# and synthesising a header from `$::execute(cmd,last)` would stamp whatever ran
# most recently onto this file.
# <exitcode> {} means "the run has not finished": header only.
proc ase::run_log_write {logpath meta data exitcode} {
  if {[catch {open $logpath w} f]} { return 0 }
  if {[catch {
    if {[llength $meta]} {
      puts -nonewline $f [ase::run_log_header $meta]
      if {$exitcode ne {}} {
        puts -nonewline $f "--- simulator output ---\n"
        puts -nonewline $f [ase::run_log_body $data]
        puts -nonewline $f [ase::run_log_footer $meta $exitcode]
      }
    } else {
      puts -nonewline $f [ase::run_log_body $data]
    }
  } e]} {
    catch {close $f}
    return 0
  }
  catch {close $f}
  return 1
}

# Completion hook (runs from execute_fileevent on EOF). execute(data,last) /
# execute(exitcode,last) are written immediately before the callback in the
# same event dispatch, so reading them here is race-free.
# ⚠ <meta> IS DEFAULTED, AND IT HAS TO BE. tests/headless/test_ase_cosim.tcl
# calls `ase::run_done <logpath> <state> {}` DIRECTLY at six sites; a required
# fourth parameter kills that suite's 341 checks with `wrong # args`. With no
# metadata the file is written exactly as it always was (see run_log_write).
proc ase::run_done {logpath state callback {meta {}}} {
  variable last_run
  set data {}
  if {[info exists ::execute(data,last)]} { set data $::execute(data,last) }
  set exitcode -1
  if {[info exists ::execute(exitcode,last)]} { set exitcode $::execute(exitcode,last) }
  ## 0618: the framing goes in the FILE. $data itself is never touched — every
  ## consumer below (result_probe, run_diagnostics) reads it in memory.
  ase::run_log_write $logpath $meta $data $exitcode
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

# "Session `key` has simulation results" -- ONE named boolean, ONE implementation
# (issue 0682 decision D3).
#
# This is a facade, deliberately: `[ase::last_rawfile $key] ne {}` was ALREADY the
# shipped test for exactly this question at three call sites
# (ase_window.tcl :2077, :3392 -- whose own comment reads `file existence ==
# "has results"` -- and :3904). 0682 needs the same question asked in two more
# places (whether ASE-L's `Results > Annotate` entries are live, and issue 0683's
# reasoning about the orphan state), and a predicate written out longhand in five
# places drifts SILENTLY when one copy learns something the others do not -- the
# same argument invariant I1 makes for op_annot::vector. So the name exists and
# the expression does not get copied again.
#
# ⚠ SESSION-SCOPED AND FILE-BASED, and that is the right scope for a menu hung off
# an ASE-L window. The two neighbouring predicates are CONTEXT-scoped and answer a
# different question: `xschem raw loaded` (scheduler.c:10325) asks whether a
# database is attached to the CURRENT xschem context -- read from a plain Tk
# toplevel it measures whichever design happens to be current -- and
# op_annot::_annotated (op_annot.tcl:781) additionally requires that the annotation
# already be live, which would grey the control precisely when the user wants to
# turn annotation ON.
proc ase::has_results {key} {
  return [expr {[ase::last_rawfile $key] ne {}}]
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

# --- F2: which VCD scope holds THIS instance's digital signals ---------------
#
# CONTRACT: doc/claude/specs/mixed_signal_signal_browser.md, section "Open
# decision 5, ruled" (RULINGS 5a-5f). Read it before changing anything here;
# the three load-bearing points are:
#
#   * the mapping is THREE facts with three owners, not one artifact --
#     f1 instance->cell is QUERY time (the live design), f2 cell->file is
#     NETLIST time (<rundir>/<cell>_ase.cosim), f3 file->scope is DERIVED from
#     the database actually loaded;
#   * the join key is the CELL (lib/cell, four rungs), NEVER the instance path:
#     one .subckt instantiated twice puts the same code block at x1.a1 AND
#     x2.a1, so a path is not a key even when it is recorded;
#   * `scope` in the map artifact is a HINT and the DERIVED answer WINS.
#     Inlining can move or delete the module the hint names, so the hint is
#     only ever a starting guess; what is returned is what the loaded DB says.
#
# Nothing here concatenates the schematic path with a VCD scope (RULING 5d: the
# prefix is DROPPED, not translated) and nothing ever falls back to `TOP`
# (RULING 5e: TOP is the shim's port mirror, whose signals are precisely the
# ones already bridged into the analog raw -- landing there would show the user
# what they could already see and call it success).

# f1 -- the QUERY-TIME read, and it MUST run in the DESIGN context, before any
# viewer raise (F1's existing warning, src/ase.tcl "show_in_browser" region: a
# read placed after the raise answers about the viewer's own untitled buffer).
# All four facts come out of this one read because rung 4 needs the `model=`
# property and nothing above the raise is readable afterwards.
#
# Returns {} when the path's LAST segment names no instance of the current
# schematic; otherwise a dict {inst symref lib cell module vfile model} whose
# `vfile` is empty when the cell has no `verilog` view.
#
# The prefix of `x1.a1` is consumed here -- it is how the leaf was identified --
# and then discarded (RULING 5d). The design walk is flat (issue 0307), which is
# why this resolves against the schematic the user is actually IN: descend into
# x1 and `a1` is a plain instance of the current schematic.
proc ase::cosim_f1 {instpath} {
  set leaf [lindex [split $instpath .] end]
  if {$leaf eq {}} { return {} }
  if {[catch {xschem instance_list} lst]} { return {} }
  set inst {}; set symref {}
  foreach {i s t} $lst {
    if {$i eq {}} { continue }
    if {$i eq $leaf} { set inst $i; set symref $s; break }
    # a case-insensitive hit is kept only until an exact one turns up: the deck
    # side folds case (SPICE), the canvas side does not.
    if {$inst eq {} && [string equal -nocase $i $leaf]} { set inst $i; set symref $s }
  }
  if {$inst eq {} || $symref eq {}} { return {} }
  set vfile {}
  catch {set vfile [cellview_sibling_path $symref verilog]}
  if {$vfile ne {} && ![file isfile $vfile]} { set vfile {} }
  set lib {}; set cell {}
  if {![catch {library_inst_lcv $symref} lcv] && [llength $lcv] == 3} {
    set lib [lindex $lcv 0]
    set cell [lindex $lcv 1]
  }
  if {$cell eq {} && $vfile ne {}} { set cell [file rootname [file tail $vfile]] }
  set model {}
  catch {set model [xschem getprop instance $inst model]}
  if {$vfile ne {}} { set vfile [file normalize $vfile] }
  return [dict create inst $inst symref $symref lib $lib cell $cell \
    vfile $vfile module [ase::cosim_module_of $vfile] model $model]
}

# f2 -- RULING 5b's four-rung key ladder over a loaded map. Each rung names BOTH
# operands, because a rung with only one is not a key. Comparisons are
# case-INSENSITIVE (SPICE folds, and cosim_map already lower-cases its join
# keys); the case-SENSITIVE test is the VCD one in cosim_scope_derive.
#
#   {ok <entry> <rung>} | {none ambiguous <why>} | {none nomap <why>}
#
# A rung matching >1 entry REFUSES and does NOT fall through: a multi-match is
# evidence of a real collision, and first-won there would plot another cell's
# internals under this cell's name.
proc ase::cosim_map_match {map f1} {
  set fl [string tolower [dict get $f1 lib]]
  set fc [string tolower [dict get $f1 cell]]
  set fm [string tolower [dict get $f1 module]]
  set fd [string tolower [dict get $f1 model]]
  foreach rung {1 2 3 4} {
    set hits {}
    foreach e $map {
      set el [string tolower [ase::state_get $e lib]]
      set ec [string tolower [ase::state_get $e cell]]
      set em [string tolower [ase::state_get $e module]]
      set ed [string tolower [ase::state_get $e model]]
      set ev [ase::state_get $e vfile]
      switch -- $rung {
        1 { if {$el ne {} && $ec ne {} && $fl ne {} && $fc ne {} &&
                $el eq $fl && $ec eq $fc} { lappend hits $e } }
        2 { if {$ec ne {} && $el eq {} && $fc ne {} && $ec eq $fc} { lappend hits $e } }
        3 { if {$ev ne {} && $em ne {} && $fm ne {} && $em eq $fm} { lappend hits $e } }
        4 { if {$ed ne {} && $fd ne {} && $ed eq $fd} { lappend hits $e } }
      }
    }
    if {[llength $hits] == 1} { return [list ok [lindex $hits 0] $rung] }
    if {[llength $hits] > 1} {
      set names {}
      foreach e $hits { lappend names [ase::state_get $e model] }
      return [list none ambiguous "the co-simulation map has [llength $hits] entries\
 matching this cell on [ase::cosim_rung_name $rung] ([join $names {, }]): xschem cannot\
 tell which one holds this instance's signals (f2)"]
    }
  }
  return [list none nomap "no entry of the co-simulation map matches cell\
 '[dict get $f1 lib]/[dict get $f1 cell]' (module '[dict get $f1 module]', model\
 '[dict get $f1 model]'): this cell was not part of the last run's netlist, or the\
 run predates it (f2)"]
}

proc ase::cosim_rung_name {rung} {
  switch -- $rung {
    1 { return {lib/cell} }
    2 { return {cell} }
    3 { return {verilog module name} }
    4 { return {model card name} }
  }
  return "rung $rung"
}

# Every scope prefix present in a list of VCD signal names, outermost first,
# de-duplicated. `TOP.counter.clk` contributes `TOP` and `TOP.counter`. A name
# with no dot is a bare signal at the root and contributes no scope.
proc ase::cosim_scopes_of {names} {
  set out {}
  set seen [dict create]
  foreach n $names {
    set segs [split $n .]
    if {[llength $segs] < 2} { continue }
    set pre {}
    foreach s [lrange $segs 0 end-1] {
      lappend pre $s
      set sc [join $pre .]
      if {![dict exists $seen $sc]} { dict set seen $sc 1; lappend out $sc }
    }
  }
  return $out
}

# f3 -- RULING 5c/5f. THE DERIVED ANSWER WINS.
#
#   {hint <scope> {}} | {derived <scope> <note>} | {none noscope <why>}
#
# `hint` is the recorded TOP.<module> string, `vfile` the map ENTRY's vfile and
# `module` f1's OWN module name, read from the live .v -- not the entry's, which
# for a code block below the netlisted schematic is a .model card name (0307).
#
# Order:
#   1. the hint is ELIGIBLE only when the entry's vfile is non-empty. An empty
#      vfile means no .v was ever opened and `TOP.$module` is `TOP.<the .model
#      card's name>` (src/ase.tcl, cosim_map's `if {$module eq {}} {set module
#      [dict get $e model]}`) -- a guess, not a hint.
#   2. an eligible hint is accepted iff >= 1 name of the LOADED DB starts with
#      "<hint>." -- literally, CASE-SENSITIVELY. vcd_read.c stores names
#      verbatim and Verilog is case-sensitive; get_raw_index() must not be used
#      for this (it folds the query, so it MISSES a mixed-case name, and it
#      resolves whole signal names, never a scope prefix).
#   3. otherwise DERIVE: the DEEPEST scope whose leaf segment is f1's module
#      name; else, if exactly one NON-ROOT scope exists, that one; else refuse.
#      The module rung may legitimately land on a root scope when the root IS
#      the module (Verilator elaborating the module as its own top) -- that is
#      evidence. The count rung may not: a root scope chosen merely for being
#      the only one left is the `TOP` fall-back RULING 5e forbids.
# A hint that was eligible and REJECTED is not silent: it comes back in <note>.
proc ase::cosim_scope_derive {names hint vfile module} {
  set rejected {}
  if {$hint ne {} && $vfile ne {}} {
    set pfx "$hint."
    set n [string length $pfx]
    foreach nm $names {
      if {[string range $nm 0 [expr {$n - 1}]] eq $pfx} { return [list hint $hint {}] }
    }
    set rejected $hint
  }
  set scopes [ase::cosim_scopes_of $names]
  set best {}
  set bestd 0
  set ties 0
  if {$module ne {}} {
    foreach sc $scopes {
      set segs [split $sc .]
      if {[lindex $segs end] ne $module} { continue }
      set d [llength $segs]
      if {$d > $bestd} { set best $sc; set bestd $d; set ties 1 } \
      elseif {$d == $bestd} { incr ties }
    }
  }
  if {$best ne {} && $ties == 1} {
    return [list derived $best [ase::cosim_hint_note $rejected $best]]
  }
  if {$best ne {} && $ties > 1} {
    return [list none noscope "the loaded database has $ties scopes named '$module' at the\
 same depth, so which one holds this instance's signals is not decidable (f3)"]
  }
  set nonroot {}
  foreach sc $scopes { if {[string first . $sc] >= 0} { lappend nonroot $sc } }
  if {[llength $nonroot] == 1} {
    return [list derived [lindex $nonroot 0] \
      [ase::cosim_hint_note $rejected [lindex $nonroot 0]]]
  }
  set found [expr {[llength $scopes] ? "scopes found: [join $scopes {, }]" \
                                     : {the database declares no scope at all}}]
  return [list none noscope "the loaded database holds no scope for module\
 '$module' ($found): the digital data exists but xschem cannot tell which part of\
 it belongs to this instance (f3)"]
}

proc ase::cosim_hint_note {rejected chosen} {
  if {$rejected eq {}} { return {} }
  return "the recorded scope hint '$rejected' is not in the loaded database --\
 using '$chosen', derived from the database itself"
}

# EVERY loaded results database as {idx path names}, for step 4/5.
#
# With a viewer token this is wviewer::signal_list_all, which does its own
# context enter/leave -- so f1 can be read in the DESIGN context and the
# registry in the VIEWER's, which is the whole reason the token is a parameter.
# With no token (headless, or a resolve before any viewer exists) the current
# context's registry is read directly, with the same switch-and-restore shape.
proc ase::cosim_db_inventory {{token {}} {statusVar {}}} {
  # `status` is `ok` (this IS the registry) or `refused` (it could not be read;
  # the empty list below says nothing about what is loaded). Optional, so every
  # older caller is unchanged -- but a caller that turns an empty answer into a
  # USER-FACING CAUSE must read it. See step 4 of ase::cosim_scope_for_f1.
  if {$statusVar ne {}} { upvar 1 $statusVar status }
  set status ok
  if {$token ne {} && [llength [info commands ::wviewer::signal_list_all]]} {
    set sst ok
    # ⚠ A THROW IS A FOURTH NON-ANSWER, and the pre-0314 `![catch ...]` quietly
    # converted it into the honest-empty case (review finding). signal_list_all
    # really does re-raise — its body's errors, and anything its leave_ctx tail
    # throws — so an unparseable `xschem raw info` during a gesture would fall
    # through to the design registry and mint 0314's sentence through the error
    # door. `sst` is pre-seeded `ok` and no writer runs on that path, so the
    # catch code is the only thing that knows.
    set scode [catch {wviewer::signal_list_all $token sst} inv]
    if {$scode} { set sst refused }
    if {!$scode && [llength $inv]} {
      set out {}
      foreach e $inv {
        lappend out [dict create idx [ase::state_get $e idx -1] \
          path [ase::state_get $e path] names [ase::state_get $e names]]
      }
      return $out
    }
    # AN EMPTY ANSWER IS NOT "the registry is empty", and treating it as one is
    # how a loaded database gets reported as `notloaded`. signal_list_all
    # (src/wave_viewer.tcl) returns {} for THREE different situations: the token
    # is not in `windows` (stale -- and a token goes stale exactly during viewer
    # teardown), enter_ctx refused the ticket (its own comment documents the
    # window-alloc window where current_win_path is transiently empty), and the
    # viewer genuinely has no databases. Only the third is an answer.
    #
    # ⚠⚠ AND THE FALL-THROUGH BELOW IS NOT SAFE FOR THE OTHER TWO -- issue 0314,
    # the degradation this comment forbade, reached through the door it left
    # open. The argument used to be "the current context reports {} by itself
    # when nothing is loaded -- the honest empty -- and the real DBs when the
    # token was simply unusable". That holds only where the current context IS
    # the viewer. On the gesture path it is the DESIGN window, which never has
    # databases, so the fall-through converted "I could not ask" into "there are
    # none" and minted `notloaded` for a VCD that was attached and listed.
    #
    # So a REFUSED loan returns here, saying so. Only the honest empty and the
    # stale token fall through -- and for those the current context's registry
    # is still the better answer than nothing (a headless resolve, or a resolve
    # taken before any viewer existed, has no token at all and lands there by
    # the same route).
    if {$sst eq {refused}} { set status refused ; return {} }
  }
  set cur [ase::raw_current]
  if {$cur < 0} { return {} }
  if {[catch {xschem raw info} info] || $info eq {}} { return {} }
  set dbs {}
  foreach line [lrange [split [string trimright $info "\n"] "\n"] 1 end] {
    if {[regexp {^\s*(\d+)\s+(.*\S)\s+(\S+)\s*$} $line -> n p t]} { lappend dbs [list $n $p] }
  }
  set here $cur
  set out {}
  foreach db $dbs {
    lassign $db idx path
    if {$idx != $here} {
      set sw 0
      catch {set sw [xschem raw switch $idx]}
      if {$sw != 1} { continue }
      set here $idx
    }
    set names {}
    if {![catch {xschem raw list} rl]} { set names [split [string trimright $rl "\n"] "\n"] }
    lappend out [dict create idx $idx path $path names $names]
  }
  # unconditional restore, outside every per-DB failure path
  catch {xschem raw switch $cur}
  return $out
}

# THE F2 RESOLVER. `key` is an ASE session key, `instpath` the browser's
# hierarchical instance path (its prefix is dropped, 5d), `token` an optional
# viewer token for step 4.
#
#   {ok <vcdpath> <scope> <how> <note>}   how = hint | derived
#   {none <code> <human sentence>}        code = nodigital | nomap | ambiguous |
#                                                multi | notraced | notloaded |
#                                                notread | noscope
#
# <note> is the 5f slot: empty on a clean answer, and on a `derived` answer that
# overrode an eligible hint it says so. Every refusal names which of f1/f2/f3
# failed -- that is F5's notice, not a separate cosmetic item.
proc ase::cosim_scope_for_instance {key instpath {token {}}} {
  return [ase::cosim_scope_for_state [ase::session_state $key] $instpath $token]
}

# The same resolver against an explicit state dict (the session lookup is the
# only thing the key form adds).
#
# ⚠ IT IS A TWO-LINE WRAPPER, AND THE SPLIT IS F1's (batch F item 5). Step 1 --
# the f1 read -- MUST happen in the DESIGN context, before any viewer raise;
# steps 2-5 need only the state, the map and the registry. A caller that has
# already taken its one design-context read (`ase::show_in_browser_for_current`,
# which cannot re-read the design after `wviewer::open` has moved the context to
# the viewer's own untitled buffer) hands that f1 straight to
# `cosim_scope_for_f1`. Re-reading it there would answer about the VIEWER, which
# is the exact silent degradation F1's ⚠ block exists to forbid.
proc ase::cosim_scope_for_state {state instpath {token {}}} {
  return [ase::cosim_scope_for_f1 $state [ase::cosim_f1 $instpath] $instpath $token]
}

# Steps 1's REFUSALS and steps 2-5, against an f1 the caller has already read.
# `f1` is `ase::cosim_f1`'s answer ({} when the path's last segment names no
# instance of the schematic that was open when it was read).
proc ase::cosim_scope_for_f1 {state f1 instpath {token {}}} {
  set leaf [lindex [split $instpath .] end]
  # 1 -- f1's own refusals (5f-4: ONE code, two sentences)
  if {$f1 eq {}} {
    return [list none nodigital "'$leaf' is not an instance of the schematic\
 currently open, so xschem cannot tell which cell it is (f1)"]
  }
  if {[dict get $f1 vfile] eq {}} {
    return [list none nodigital "cell '[dict get $f1 lib]/[dict get $f1 cell]' has no\
 verilog view, so instance '[dict get $f1 inst]' has no digital signals of its own (f1)"]
  }
  # 2 -- f2, by the 5b key ladder
  set m [ase::cosim_map_match [ase::cosim_load_map $state] $f1]
  if {[lindex $m 0] ne {ok}} { return $m }
  set e [lindex $m 1]
  # 3 -- the entry's OWN refusals, before anything touches the registry.
  # `multi` first: last_vcdfiles already excludes such a file deliberately, so a
  # `notloaded` answer here would name the wrong cause.
  if {[ase::state_get $e multi 0] eq {1}} {
    return [list none multi "the .model card '[ase::state_get $e model]' serves\
 [ase::state_get $e ninst 2] instances, which would all write one VCD and interleave it:\
 that file was deliberately not produced (f2)"]
  }
  # cosim_map writes `scope` unconditionally, INCLUDING for entries whose `vcd`
  # is empty, so a scope hint exists for files that will never exist. Check the
  # promise, not the hint.
  set vcd [ase::state_get $e vcd]
  if {$vcd eq {}} {
    return [list none notraced "the last run promised no VCD for '[ase::state_get $e model]'\
 (co-simulation tracing off, a non-Verilator shim, a .so outside the run directory, or a\
 continued .model card), so there is no digital data to show (f2)"]
  }
  # 4 -- the DB must actually be in the registry
  set names {}
  set found 0
  set nvcd [file normalize $vcd]
  set inv_status ok
  foreach db [ase::cosim_db_inventory $token inv_status] {
    if {[file normalize [dict get $db path]] eq $nvcd} {
      set names [dict get $db names]
      set found 1
      break
    }
  }
  # ⚠ "COULD NOT READ THE REGISTRY" IS NOT "IT IS NOT LOADED" (issue 0314). The
  # two answers are indistinguishable in the inventory's return value and the
  # difference is everything: `notloaded` tells the user to run a simulation
  # whose results are, on this path, already attached and listed one window
  # away. A refused loan therefore gets its OWN cause and a sentence that asks
  # for the one thing that helps -- the gesture again, once the editor is idle.
  # ⚠ AND IT SAYS ONLY WHAT A REFUSAL ESTABLISHES (review finding). `refused` is
  # the union of three unrelated causes -- the semaphore said busy, the window
  # was being allocated or torn down, the target window is gone -- so naming any
  # ONE of them as fact would be the same overreach as `notloaded`, one step
  # smaller. It does not claim the database IS loaded either: the refusal is
  # defined as not knowing. What it does carry is the only advice the state
  # supports, and the absence of the advice that made this issue: nobody is told
  # to re-run anything.
  if {!$found && $inv_status eq {refused}} {
    return [list none notread "the waveform viewer's results registry could not be\
 read just now, so '[file tail $vcd]' could not be confirmed loaded: try the\
 gesture again in a moment (f3)"]
  }
  if {!$found} {
    return [list none notloaded "'[file tail $vcd]' is not among the loaded results\
 databases: run the simulation, or re-attach its results (f3)"]
  }
  # 5 -- f3, derived and VERIFIED against that DB
  set d [ase::cosim_scope_derive $names [ase::state_get $e scope] \
           [ase::state_get $e vfile] [dict get $f1 module]]
  if {[lindex $d 0] eq {none}} {
    return [list none noscope "[lindex $d 2] -- database '[file tail $vcd]'"]
  }
  set note [lindex $d 2]
  # THE DISAGREEMENT IS NOT SILENT (5f). It also reaches the user directly, so
  # it does not depend on a caller remembering to render <note>.
  if {$note ne {}} { ase::echo "ase: $note" note }
  return [list ok $vcd [lindex $d 1] [lindex $d 0] $note]
}

# --- F1/F5: the verilog-only branch of "Show in Signal Browser" --------------
#
# CONTRACT: doc/claude/specs/mixed_signal_signal_browser.md §F, rows F1 and F5,
# and RULING 5f-3 ("F5 renders this sentence rather than composing its own").
#
# THE PROBE IS THE WHOLE DESIGN-CONTEXT READ, and it is called from step 3c of
# `ase::show_in_browser_for_current` -- beside the selection read, above the
# viewer raise, for that block's ⚠⚠ reason. It takes its OWN f1 read here and
# hands it to `ase::cosim_scope_for_f1`, so nothing about the design is read
# again after `wviewer::open` has moved the xschem context to the viewer.
#
#   {}                          this is not a digital cell -- the branch is NOT
#                               entered and NOTHING is said (see below)
#   {ok <vcd> <scope> <how> <note>}
#   {none <code> <sentence>}    F5's notice, verbatim from the resolver
#
# ⚠⚠ THE GATE IS "THE CELL HAS A `verilog` VIEW", WHICH IS f1's `vfile`, AND IT
# IS DELIBERATELY NOT "the cell has ONLY a verilog view" (RULING F1a, written
# into §F of the spec by this item). Two reasons, and the first is decisive:
#   * an ordinary analog instance must not pay for this branch, and must not be
#     told anything about co-simulation. `cosim_f1` answers `nodigital` for a
#     cell with no `.v`, and rendering that as a notice would put "has no
#     digital signals of its own" in the CIW on every Ctrl-Alt-V in an analog
#     design. So a `{}` vfile short-circuits to `{}` and the shipped analog path
#     runs untouched -- which is also what keeps every pre-item BX check green.
#   * whether the cell is a code block in THIS run is a question only the run's
#     own map can answer (RULING 5a), and the ladder answers it: a cell with a
#     `verilog` view that the last run did not netlist as a `d_cosim` card comes
#     back `nomap`, with a sentence saying so. Gating on "no schematic view"
#     instead would silently skip a cell that IS a code block but also happens to
#     carry a stale schematic view, which is the wrong-answer direction.
proc ase::browser_digital_probe {key selname {token {}}} {
  if {$selname eq {}} { return {} }
  set f1 {}
  catch {set f1 [ase::cosim_f1 $selname]}
  if {$f1 eq {}} { return {} }
  set vf {}
  catch {set vf [dict get $f1 vfile]}
  if {$vf eq {}} { return {} }
  set r {}
  if {[catch {ase::cosim_scope_for_f1 [ase::session_state $key] $f1 $selname \
                $token} r]} {
    return {}
  }
  return $r
}

# F5's SENTENCE. PURE -- which is what lets a headless check assert WHICH cause
# produced WHICH text without a viewer.
#
# ⚠⚠ IT RENDERS THE RESOLVER'S OWN SENTENCE VERBATIM (RULING 5f-3). The three
# causes F5's spec row names are already three different sentences minted at the
# point each is DECIDED -- `notloaded` ("not among the loaded results
# databases"), `notread` (issue 0314: the registry could not be READ, which is a
# different fact and must never carry `notloaded`'s "run the simulation"),
# `notraced` ("the last run promised no VCD ... tracing off ...")
# and the no-mapping family (`nomap`/`ambiguous`/`noscope`/`multi`/`nodigital`).
# A notice that re-worded them here would be a second account of the same event,
# free to drift from what the code does; item 4's receipt states the failure
# mode plainly -- "a notice that describes a different no-match behaviour than
# the code implements is worse than no notice". So this proc adds a PREFIX that
# says which surface is empty and nothing else.
proc ase::browser_digital_msg {res} {
  if {[lindex $res 0] ne {none}} { return {} }
  return "no digital signals to show: [lindex $res 2]"
}

# 1 when the viewer's lower pane is listing nothing at all (RULING F1e). TOTAL:
# it rides the same key binding as everything else in this file, and it is
# consulted to decide whether to SAY something -- so anything it cannot
# establish (no viewer proc, no window, no pane state) is `0`, "no claim", never
# a guessed yes. `wviewer::browser_sea_empty` already answers 0 for every state
# it cannot make the claim about — no window, no pane state, and (since the
# review pass) a node whose names a Search/Filter bar has hidden rather than a
# node that has none; this adds the last one, a viewer whose Tcl is not loaded
# at all (headless).
#
# ⚠ IT IS ONLY MEANINGFUL ONCE THE PANE HAS SETTLED. `browsersea` is rebuilt by
# the <<TreeviewSelect>> handler, which a tree landing only QUEUES — so asked
# before step 6c's flush this answers about the node the user just LEFT. That
# is why the flush exists and why it is above the only call site (RULING F1f).
proc ase::browser_pane_unread {token} {
  if {![llength [info commands ::wviewer::browser_sea_empty]]} { return 0 }
  set r 0
  catch {set r [wviewer::browser_sea_empty $token]}
  return [expr {$r ? 1 : 0}]
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
  ## 0648: THE USER ACTED ON THE OP-CARD GATE -> give the nudge its turn back.
  ## Compared OLD vs NEW and never cleared unconditionally: this proc is the
  ## write path for every pane mutation (toggle_flag, the variables/outputs/
  ## analyses editors, the temperature field) and an unconditional clear here
  ## re-creates the three-identical-lines-per-session defect of issue 0636.
  ## Under `catch` because a session write must never fail on an extra.
  catch {
    if {[ase::op_cards_gate_changed \
           [ase::state_get [dict get $sessions $key state] save_op_params {}] \
           [ase::state_get $newstate save_op_params {}]]} {
      ase::op_cards_nudge_rearm $newstate
    }
  }
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

# EVERY session key whose state.design targets {lib cell view}, in registry
# (insertion) order.
#
# ⚠ ONE LOOKUP IMPLEMENTATION, TWO CONSUMERS (invariant I1). Launch's
# ase::session_for_design below is exactly this list's FIRST element, and issue
# 0679's remedy-key resolver (ase::op_cards_remedy_key, ~:617) uses the PLURAL
# form because it has to tell "exactly one" from "more than one": a reverse
# lookup that silently returned the first of several would print a plausible
# SIBLING session's key and repeat 0679's own defect class -- advice that
# half-works. A second private loop inside the resolver would be the exact
# two-builders shape that issue is about.
proc ase::sessions_for_design {lib cell view} {
  variable sessions
  set out {}
  dict for {k entry} $sessions {
    set d [ase::state_get [dict get $entry state] design]
    if {[dict exists $d lib]  && [dict get $d lib]  eq $lib  \
     && [dict exists $d cell] && [dict get $d cell] eq $cell \
     && [dict exists $d view] && [dict get $d view] eq $view} {
      lappend out $k
    }
  }
  return $out
}

# EVERY session key whose LIVE state IS $state, compared through the canonical
# serialization ase::session_dirty uses (total, and it cannot raise on a
# well-formed state; a state that will not serialize resolves to no match
# rather than to a wrong one).
#
# This is the EXACT route issue 0679's remedy key resolves through first, and
# on the user's bench it is the one that fires: the GUI's two netlist entry
# points (ase_window.tcl:4139 Netlist, :4309 Netlist-and-Run) pass
# `ase::session_state $key` verbatim into ase::netlist / ase::run, and
# ase::netlist forwards that same dict unmodified to ase::op_cards_capture
# (:842). So the answer is measured, not inferred from the design cellview.
proc ase::sessions_for_state {state} {
  variable sessions
  set out {}
  if {[catch {ase::state_serialize $state} want]} { return {} }
  dict for {k entry} $sessions {
    if {[catch {ase::state_serialize [dict get $entry state]} s]} { continue }
    if {$s eq $want} { lappend out $k }
  }
  return $out
}

# The session key (if any) whose state.design targets {lib cell view}. Used by
# Launch to RAISE rather than duplicate a session already on this design.
# FIRST match wins, and that contract is depended on by name (test_ase_launch
# L7 :146 / :186 / :214, test_wave_modes:2163, test_wave_sigbrowser_i12:760),
# so it is preserved exactly by being element 0 of the plural lookup above --
# never re-implemented here.
proc ase::session_for_design {lib cell view} {
  return [lindex [ase::sessions_for_design $lib $cell $view] 0]
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

# --- ISSUE 0319: A HIERARCHY PATH SPELLS AN INSTANCE THE WAY THE NETLIST DOES --
#
# PURE. Given the three facts that decide it, the name a raw's hierarchy path
# uses for one instance. It is a SEPARATE proc from the reads below for
# `browser_origin_drop`'s reason, one item over: the RULE is then assertable
# without a design, a raw or a viewer.
#
# ⚠⚠ THE RULE IS THE NETLISTER'S, MIRRORED — src/token.c:2468-2479 and 2676.
# `print_spice_element` builds the element line from `@format`, and sky130's
# device symbols begin theirs `@spiceprefix@name`. So a FET DRAWN as `M18` is
# NETLISTED `XM18` and ngspice lower-cases that to `xm18`; the raw then carries
# `v(m.x1.x1.xm18.msky130_fd_pr__nfet_01v8_lvt#body)` and the browser's tree a
# group row `xm18` under `x1 > x1`. The schematic's own `M18` matches that row
# neither exactly nor `-nocase`, which is the whole of issue 0319: the asked
# path stalled one segment short of the device, two-pane item 18's probe could
# never answer yes, and the gesture landed on the parent `x1 > x1` — the exact
# symptom reported. (The issue GUESSED that a primitive contributes no segment
# at all. It contributes one; it is spelled differently. Measured, receipt 19.)
#
# TWO CONDITIONS, AND BOTH ARE REACHABLE — neither is a defensive guard that no
# sabotage could get to (the third, obvious one is discussed and rejected
# below):
#
#  * `name` must not be empty. `browser_sel_segment`'s `none` shape is an empty
#    name, and a bare prefix would match the ROOT rather than nothing.
#  * `fmt` — the format string has to actually USE `@spiceprefix`. NOT
#    hypothetical: `devices/netlist_options` carries `spiceprefix=true` in its
#    template and has NO format at all (it configures the netlister instead of
#    being netlisted), so without this condition selecting one and pressing
#    Ctrl-Alt-V would ask the browser for a segment named `trueNETLIST_OPTIONS`.
#    Measured: 122 `.sym` files across xschem_library (26), xschem_libs_newsym
#    (26) and sky130A/xschem_libs (70) mention `spiceprefix`, and exactly TWO
#    never use `@spiceprefix` — the same `netlist_options` symbol, once per
#    library layout. Nothing else in the shipped tree reaches this condition,
#    and nothing at all reaches it by ACCIDENT: no shipped format escapes the
#    token (`\@spiceprefix`) or hides it inside a `@tcleval`, both checked.
#
# ⚠ AND THERE IS DELIBERATELY NO `$prefix eq {}` GUARD, which is the third
# question this rule is asked and the one the CONCATENATION already answers:
# an empty prefix makes `"$prefix$name"` the name, byte for byte, in every
# state. A guard for it would be a line no sabotage could reach — the sabotage
# battery measured exactly that, S6 reddening one SOURCE check and nothing
# else. The early return that DOES earn its keep is the reader's below, and it
# earns it by saving two reads rather than by changing an answer.
#
# ⚠ THE CASE IS NOT FOLDED, and that is `browser_sel_segment`'s decision kept
# rather than a new one: `X` + `M18` is `XM18`, not `xm18`. The resolver's
# exact-first/`-nocase`-fallback per level (`browser_node_for`) is what lands it
# on the raw's lower-cased row, the same way BX42 lands a schematic `X1.X2` on
# `g:x1.x2`. Lower-casing here would be a SECOND answer to that one question.
proc ase::spice_seg_name {name prefix fmt} {
  if {$name eq {}} { return $name }
  if {[string first {@spiceprefix} $fmt] < 0} { return $name }
  return "$prefix$name"
}

# The reads that feed the rule above, for one instance of the CURRENT design.
# Returns `$nm` unchanged for anything it cannot establish.
#
# ⚠⚠ THE PREFIX IS ASKED OF THE NETLISTER, NOT RE-DERIVED — `xschem translate
# <inst> {@spiceprefix}` runs `translate()` (token.c), the very substitution
# `print_spice_element` uses to write the element line. THREE facts come with it
# that a hand-rolled reader has to get right separately, and the first cost this
# fix its first cut:
#   1. THE SYMBOL TEMPLATE IS A FALLBACK. `xschem getprop instance M1
#      spiceprefix` reads inst.prop_ptr ONLY (scheduler.c:5224). `test_nfet_final`
#      draws its FET as plain `name=M1 W=1 L=0.15 nf=1` with NO spiceprefix
#      token of its own and inherits `spiceprefix=X` from the symbol's template
#      — and the netlist duly writes `XM1`. A getprop reader answers `{}` there
#      and silently does nothing, which is the bug again on the commoner of the
#      two shapes. MEASURED, by running the top-level control the issue asked
#      for. (⚠ BOTH sky130 AND gf180 ship a cell of that name; the raw in
#      `~/.xschem/simulations/test_nfet_final_ase.raw`, whose first variable is
#      `i(@m.xm1.m0[id])`, is **gf180mcuD's** — its Title line says so. The
#      sky130 one is what the check loads, and it answers `XM1` too.)
#   2. THE GLOBAL TOGGLE IS HONOURED. Simulation > "Use 'spiceprefix' attribute"
#      (xschem.tcl:15148, `set_ne spiceprefix 1` at :15708) makes token.c:2676
#      expand `@spiceprefix` to nothing, and translate answers `{}` to match, so
#      with that box unticked this returns the bare name the netlist will use.
#   3. It cannot drift from the netlister, because it IS the netlister.
#
# ⚠⚠ THE FORMAT IS READ WITH `instance_notcl`, AND THAT IS NOT A STYLE CHOICE.
# Plain `getprop instance` looks the token up with `with_quotes = 0`
# (scheduler.c:5213/5221/5224), which routes through `tcl_hook2`
# (token.c:533-537) and **EXECUTES** any value beginning `tcleval(`.
# `print_spice_element` reads the same attribute with `with_quotes = 2`
# (token.c:2471-2479) and never does. MEASURED with a symbol whose format is
# `tcleval([boom])`: the plain read ran `boom`, `instance_notcl` did not — so
# the plain read would fire a symbol's embedded Tcl on every Ctrl-Alt-V, and
# `xschem_library/analyses/command_block.sym` is a shipped symbol whose format
# is `tcleval([::analyses::netlister spice])`, i.e. a read that runs the
# NETLISTER. DECLARED LIMIT, and it is the right way round: a format whose
# `@spiceprefix` appears only AFTER evaluation reads as "no prefix" here and
# degrades to the shipped `partial`, which is a miss, not a wrong node. (No
# shipped symbol is like that: ihp's `ntap1` and friends carry `@spiceprefix`
# literally inside their `tcleval(...)`.)
#
# ⚠⚠ THE ATTRIBUTE CHAIN IS token.c:2468-2479's, MIRRORED WHOLE — the active
# format attribute (instance, then symbol), then a fall back to plain `format`
# at both levels. `lvs_format` IS consulted: an earlier cut skipped it on a
# measurement that swept only THREE of this repo's FIVE symbol libraries, and
# the two it missed are the two the user actually runs. **54 symbols disagree**
# about `@spiceprefix` between `format` and `lvs_format` — 19 in
# `gf180mcuD/xschem_libs/gf180mcu_pr` (e.g. `nfet_03v3.sym:20` vs `:24`) and 35
# in `ihp-sg13g2/xschem_libs/sg13g2_pr`, where lvs hardcodes a DIFFERENT letter
# per class (`M@name`, `C@name`, `R@name`, `L@name`, `Q@name`). With LVS
# netlisting on, gf180's `M1` is emitted BARE — so prefixing it would not merely
# fail to help, it would break a segment that used to match. Measured on gf180
# `test_nfet_final` with `lvs_netlist 1`: the element line is `M1 D G GND GND
# nfet_03v3 …`.
#
# ⚠ DECLARED LIMIT: `xschem set format <attr>` (scheduler.c:11356) can point the
# netlister at an arbitrary attribute (`xctx->format`, token.c:2469) and this
# still reads `format`/`lvs_format`. No in-tree caller sets it. Same class:
# the global `spiceprefix` switch is read at gesture time, not at simulation
# time, so flipping it AFTER a run makes this disagree with the raw on disk.
# Both degrade to `partial`, never to a wrong node.
#
# ⚠⚠ NEVER THROWS, and it rides Ctrl-Alt-V, where a Tcl error pops bgerror
# (modal under X). `xschem translate` DOES throw on an unknown instance
# ("xschem translate: instance not found", measured), so every read is caught
# and every unreadable answer degrades to the bare name — the shipped
# behaviour — rather than to an error.
#
# ⚠ TWO READS IN THE COMMON CASE: a selection with no prefix (every subcircuit)
# leaves after the first and never spends the format reads.
proc ase::inst_path_segment {nm} {
  if {$nm eq {}} { return $nm }
  # ⚠⚠ `get_instance()` READS AN ALL-DIGIT STRING AS AN INDEX
  # (scheduler.c:187-190), so on a schematic whose instance is called `2` every
  # by-name read below silently answers about instance number 2 instead — no
  # throw, no empty result, just a different device's prefix. MEASURED on a
  # sheet whose instance `2` is a vsource while index 2 is a prefixed FET:
  # `getprop instance 2 name` answers `M2` and `translate 2 {@spiceprefix}`
  # answers `X`, so without this line the segment for a device the netlist calls
  # `2` would be `X2`. REFUSE rather than guess; `hier_resolve` guards the
  # MIRROR direction against this same rule (wave_viewer.tcl:10725-10732).
  if {[string is digit -strict $nm]} { return $nm }
  set pfx {}
  catch {set pfx [xschem translate $nm {@spiceprefix}]}
  if {$pfx eq {}} { return $nm }
  set attr format
  if {[info exists ::lvs_netlist] && $::lvs_netlist ne {} &&
      ![catch {expr {$::lvs_netlist ? 1 : 0}} lv] && $lv} { set attr lvs_format }
  set fmt {}
  catch {set fmt [xschem getprop instance_notcl $nm $attr]}
  if {$fmt eq {}} { catch {set fmt [xschem getprop instance_notcl $nm cell::$attr]} }
  if {$fmt eq {} && $attr ne {format}} {
    catch {set fmt [xschem getprop instance_notcl $nm format]}
    if {$fmt eq {}} { catch {set fmt [xschem getprop instance_notcl $nm cell::format]} }
  }
  return [ase::spice_seg_name $nm $pfx $fmt]
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
      # ⚠⚠ ISSUE 0319: THE PATH GETS THE NETLIST'S SPELLING AND `$selname` KEEPS
      # THE SCHEMATIC'S. Two different values on purpose. The raw calls the FET
      # the user drew as `M18` `xm18`, so the SEGMENT has to be `XM18` or the
      # path stalls one short of the device (see `ase::spice_seg_name`), while
      # `$selname` is what the user actually pointed at and is used for two
      # other things this must not break: F1's digital probe at step 3c, whose
      # `xschem getprop instance <name> model` only answers for the schematic's
      # own spelling, and 6b's "'<name>' has no level in the simulation data"
      # sentence, which must name what the user selected. Folding the two into
      # one value breaks a lookup and starts reporting a name nobody typed.
      #
      # ⚠ AND IT IS READ HERE, IN THE DESIGN CONTEXT, FOR STEP 3b's REASON.
      # `inst_path_segment` is an `xschem translate` and up to two `getprop
      # instance` reads; after step 4's raise they answer about the VIEWER's own
      # untitled buffer, which has no instances — so they would throw, be
      # caught, and the prefix would silently never be applied while every
      # direct check of the rule stayed green. Moving this below step 4 is a
      # declared sabotage (S14).
      lappend segs [ase::inst_path_segment $selname]
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
  # 3c. F1: THE VERILOG-ONLY BRANCH, PROBED HERE AND NOWHERE LOWER.
  #
  # ⚠⚠ IT IS ABOVE STEP 4 FOR STEP 3b's REASON, AND THE FAILURE MODE IS WORSE,
  # not milder. The probe's first act is `ase::cosim_f1`, which reads `xschem
  # instance_list` and `xschem getprop instance <name> model` — both of them
  # about the schematic THIS window holds. `wviewer::open` moves the xschem
  # context to the viewer's own untitled buffer, which has no instances at all,
  # so a probe placed after it does not fail: it answers `{}` ("not a digital
  # cell"), the branch quietly never fires, and every check that calls the probe
  # or the resolver DIRECTLY stays green. Moving this call below step 4 is a
  # declared sabotage: `FV33` watches the live call ORDER (f1 before open) and
  # `FV39` the source layout, so the two cannot both be satisfied by a move.
  #
  # ⚠ THE VIEWER TOKEN IS PASSED, and it is what makes the one-read rule
  # possible at all (RULING 5f-2): step 4 of the resolver needs the VIEWER's
  # registry, and with a token it reaches it through
  # `wviewer::signal_list_all`, which takes its own context loan. So the design
  # is read here, the registry is read in the viewer, and nothing is re-read
  # after the raise. The token IS the session key — every other viewer call in
  # this proc passes the same value.
  set dig {}
  if {$selname ne {}} {
    set dig [ase::browser_digital_probe $key $selname $key]
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
  # 6. the node — the DIGITAL scope when F1's branch resolved one, else the
  # shipped analog path, unchanged.
  #
  # ⚠ A REFUSAL FALLS THROUGH, IT DOES NOT STRAND THE USER (RULING F1b). The
  # analog path still runs and still lands where it always did; F5's notice,
  # written at the very end of this proc, is what says why the digital pane the
  # user asked for is not there. Refusing outright would replace a partial
  # answer with none, and the shipped last-mile retry below is already the right
  # behaviour for a code block: its own level does not exist in the analog raw.
  set res {}
  set done 0
  # issue 0315, RULING (1): THIS COMMAND OWNS THE CIW ACCOUNT OF ITS OWN GESTURE.
  # Every viewer call below is armed so that `wviewer::browser_say` writes the
  # sidebar status line and NOT a second CIW copy of the sentence step 6 is about
  # to echo with the `ase: ` prefix. Before the ruling one Ctrl-Alt-V wrote the
  # same sentence twice, and on the fall-through the viewer's copy was tagged
  # `error` — a red line in the log for a gesture whose verdict is PASS.
  #
  # ⚠ ARMED PER CALL, NOT ONCE FOR THE PROC. The flag is one-shot: each of the
  # three calls below consumes its own, and a single arm at the top would silence
  # only the first. The tail disarm is the leak guard, not the mechanism.
  #
  # ⚠⚠ AND THE GESTURE STARTS FROM A KNOWN STATE, which review measured to be the
  # half the tail disarm cannot give. The three calls below are unguarded, so an
  # error raised between an arm and its say propagates out of this proc and skips
  # the tail — leaving the flag armed. Tcl 8.4 is still a target here, so there is
  # no `finally` to lean on; clearing on ENTRY is what makes the leak unable to
  # reach anything, because the next thing that reads the flag is this gesture's
  # own first arm.
  catch {wviewer::browser_say_quiet $key 0}
  if {[lindex $dig 0] eq {ok}} {
    catch {wviewer::browser_say_quiet $key}
    set res [wviewer::browser_show_db_scope $key [lindex $dig 1] [lindex $dig 2]]
    if {[lindex $res 0] ne {err}} {
      set done 1
    } else {
      # THE SCOPE RESOLVED AND THE TREE COULD NOT REACH IT. That is a fourth
      # cause, minted here because it is decided here, and it carries the
      # browser's own sentence for the same no-second-account reason F5 renders
      # the resolver's (RULING 5f-3).
      set dig [list none nopane "the digital scope '[lindex $dig 2]' of\
 '[file tail [lindex $dig 1]]' could not be shown in the Signal Browser:\
 [wviewer::browser_msg $res]"]
    }
  }
  if {!$done} {
    catch {wviewer::browser_say_quiet $key}
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
      # ⚠ issue 0315, RULING (3), AND THE ARM IS WHAT DELIVERS IT. This retry is
      # the fall-through the a9 control exercises: the extended path resolved
      # nothing, so the call above answered `err` — a benign outcome that the
      # next line RECOVERS from. Unarmed, that `err` reached the CIW tagged
      # `error`, painting a red line for a gesture that then landed somewhere
      # sensible and reported so. The account the log keeps is the two `ase: `
      # lines below, neither of which is an error, and a red line is now
      # produced only when the retry ALSO fails — i.e. when nothing landed.
      catch {wviewer::browser_say_quiet $key}
      set res [wviewer::browser_show_path $key [join $base .]]
      set where [expr {[llength $base] ? "[join $base .]" : {the design root}}]
      catch {::ase::echo "ase: signal browser: '$selname' has no level in the\
 simulation data; showing $where instead"}
    }
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
  # 6c. THE SETTLE, AND WITHOUT IT EVERYTHING BELOW IS WRITTEN INTO A PANE THAT
  # HAS NOT HAPPENED YET (salvage pass, review findings R1/R2 — MEASURED on the
  # real viewer, not predicted).
  #
  # ⚠⚠ THE NOTICE STEP 7 WRITES IS ERASED BEFORE THE USER CAN READ IT WITHOUT
  # THIS LINE. `browser_reveal`'s `$tv selection set` only QUEUES
  # <<TreeviewSelect>>; the bind runs `wviewer::browser_sea_refresh`, whose
  # FIRST act is `set browserseanote($token) {}` and whose last act re-captions
  # the pane from the shipped `seaempty`/`seacount` arms. That event is
  # delivered on the very next turn of the event loop — i.e. the instant this
  # key binding returns — so a notice written above it lives for microseconds
  # and reaches nobody. Measured on BOTH arms before this line existed: the
  # caption held the notice on return and read "'TOP.m' has no signals of its
  # own" one `update` later, which is the exact falsehood F5 exists to remove.
  #
  # ⚠⚠ AND IT IS WHAT MAKES STEP 7b's PREDICATE HONEST. `ase::browser_pane_unread`
  # reads the pane MODEL (`browsersea`), which that same queued refresh has not
  # rebuilt yet — so without this flush the arm decides using the pane the user
  # has just LEFT, firing or not according to stale state rather than to what is
  # on screen. Measured: settled root then re-scope answered 0 ("pane lists
  # things") for a scope whose pane was about to list nothing.
  #
  # ⚠ `update`, NOT `update idletasks`. <<TreeviewSelect>> is a virtual event on
  # the MAIN queue, and idletasks does not deliver it — `browser_reveal` already
  # calls `update idletasks` and the note still died. Measured.
  #
  # ⚠ HERE, AND ONLY HERE. Everything above still had a selection change to
  # make (step 6, its `partial` fall-through and 6b's last-mile retry all move
  # the tree); nothing below moves it. So this is the first point at which one
  # flush is sufficient and the last at which one is needed. It re-enters the
  # event loop, which is why it is at the tail rather than in the middle: only
  # the notice write follows it.
  catch {update}
  # 7. F5: THE EMPTY-PANE NOTICE, AND IT IS WRITTEN LAST.
  #
  # ⚠⚠ LAST, ON PURPOSE. The fall-through above has just written the sidebar's
  # status line, the lower pane's caption and a CIW line of its own about where
  # it landed instead; a notice written before them would be the sentence the
  # user never sees. The CIW keeps BOTH lines — what was shown, then why the
  # digital pane is not there — which is the account the log needs.
  #
  # ⚠ IT IS RENDERED, NOT COMPOSED (RULING 5f-3, and item 4's receipt: "a notice
  # that describes a different no-match behaviour than the code implements is
  # worse than no notice"). `ase::browser_digital_msg` prefixes and nothing
  # else; the sentence naming the cause is the resolver's own.
  #
  # ⚠ `error`, THE TAG §F's F5 ROW NAMES — the pane is empty because something
  # refused, and the `note` tag is 5f-6's colour for a disagreement the resolver
  # RECOVERED from. Two different events, two different tags.
  if {[lindex $dig 0] eq {none}} {
    set nm [ase::browser_digital_msg $dig]
    catch {::ase::echo "ase: signal browser: $nm" error}
    catch {wviewer::browser_notice $key $nm}
  } elseif {[lindex $dig 0] eq {ok} && $done && [ase::browser_pane_unread $key]} {
    # 7b. F5's OTHER EMPTY PANE, AND IT IS THE ONE THE HAPPY PATH PRODUCES
    # (RULING F1e, added by the salvage pass — MEASURED, not predicted).
    #
    # ⚠⚠ WITHOUT THIS ARM A SUCCESSFUL SHOW CAN CAPTION ITSELF AS A BARE
    # EMPTINESS. The scope really is shown: the tree re-scopes and the row is
    # selected. When the landing has no signals OF ITS OWN — a pure ancestor,
    # and every `partial` landing is one — the pane draws nothing and
    # `browser_sea_refresh`'s `seaempty` arm captions it "'TOP' has no signals
    # of its own", a true sentence that says nothing about the database, nothing
    # about the scope that was asked for, and nothing about the fact that the
    # gesture SUCCEEDED. F5's row is "say WHY the pane is empty, do not show an
    # empty pane". So the fuller reason overwrites it, on the same three
    # surfaces, through the same renderer — and it survives to be read only
    # because step 6c settled the pane first (without that flush this whole arm
    # is written and erased inside one event-loop turn; see 6c's ⚠⚠).
    #
    # ⚠⚠ THE CAUSE THIS SENTENCE NAMES WAS REWRITTEN BY §F ITEM F6 (issue 0308),
    # AND THE ARM WAS KEPT RATHER THAN DELETED — a ruling, RULING F1g, taken
    # against issue 0308's own closing suggestion and recorded in the spec with
    # its reason. As shipped by RULING F1e the sentence blamed the LOWER PANE's
    # single-database reader ("the lower pane lists only the current results
    # database"), which was then the truth and is now false: the pane reads the
    # row's own database. What is NOT false is the predicate. `browser_sea_empty`
    # asks whether the selected NODE has anything to list, and F6 made it ask
    # that of the node's own database — so it now fires exactly when the landing
    # is a pure ancestor. Deleting the arm would hand that landing back to a
    # caption that never says the digital show succeeded or which run it landed
    # in, which is the contradiction RULING F1e was minted to remove; only its
    # stated cause had to change with the fix.
    #
    # ⚠⚠ THE SENTENCE NAMES `[lindex $res 2]`, THE LANDING, NEVER `[lindex $dig
    # 2]`, THE SCOPE THAT WAS ASKED FOR. They differ on a `partial` — the walk
    # reached only an ancestor of the resolved scope — and a review reproducer
    # got there on the first try with nothing more exotic than a Filter pattern:
    # asked TOP.m, landed TOP, and the sentence claimed "showing the digital
    # scope 'TOP.m' in the tree" one statement after the CIW had said "no
    # signals under 'TOP.m' - showing TOP instead". Two sentences from one
    # command contradicting each other is worse than either alone.
    #
    # ⚠ AND A `partial` STILL GETS THE NOTICE, which is why the guard is `$done`
    # and not `[lindex $res 0] in {ok alldbs}`. The pane's emptiness is a fact
    # about where the tree LANDED, and an ancestor inside a foreign VCD lists
    # exactly as little as the scope itself would: excluding `partial` would
    # hand that landing straight back to the shipped `seaempty` arm and its
    # "'TOP' has no signals of its own", i.e. it would restore the falsehood on
    # the very path the reproducer found. Naming the landing removes the
    # contradiction; dropping the arm would only hide it.
    #
    # ⚠ THIS SENTENCE IS COMPOSED HERE, not rendered from the resolver, for
    # `nopane`'s reason one line up: the resolver did not refuse — it answered
    # `ok` — so there IS no resolver sentence. It is minted where the fact is
    # decided, which is the rule 5f-3 actually states.
    #
    # ⚠ NOT the `error` tag. Nothing failed and nothing was refused; the user
    # got what they asked for with a caveat, which is exactly what 5f-6 minted
    # the `note` tag for.
    #
    # ⚠ IT DOES OVERWRITE THE SIDEBAR STATUS LINE that `browser_say` has just
    # written ("showing every results database to reach <node>"), and that is
    # the ordering choice, not an accident: one line, two candidate sentences,
    # and the one the user needs is the one about the pane they are staring at.
    # Nothing is lost — the CIW keeps BOTH, in the order they happened, which is
    # the account the action log needs and the reason this arm echoes as well as
    # renders.
    set nm "showing the digital scope '[lindex $res 2]' of\
 '[file tail [lindex $dig 1]]' in the tree, but that scope has no signals of its\
 own - open one of its sub-scopes to see any"
    catch {::ase::echo "ase: signal browser: $nm" note}
    catch {wviewer::browser_notice $key $nm}
  }
  # issue 0315: THE LEAK GUARD, not the mechanism. Every arm above is consumed by
  # the say of the call it was armed for, so this normally unsets nothing. It is
  # here because the cost of being wrong about that is a LATER, unrelated
  # navigation reporting nothing at all, and the flag has no other owner.
  catch {wviewer::browser_say_quiet $key 0}
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
    # --- the op_annot device operating-point save cards (plan step S4) -------
    # A PURE CONSUMER: the block was built by op_annot::save_cards at netlist
    # time (ase::op_cards_capture) and is appended VERBATIM here.
    #
    # ⚠ DECK LEVEL, IMMEDIATELY ABOVE `.control`, AND NOT ONE LINE LOWER.
    # Inside a .control block a dot-card is `save: no such command available`
    # at rc 0 (op_annot.tcl:2112-2118) — it would fail silently.
    #
    # ⚠ THE BLOCK'S OWN `.save all` LEADER IS LOAD-BEARING; DO NOT TIDY IT AWAY
    # AS A DUPLICATE. Any explicit `save` cancels ngspice's implicit
    # save-everything (rule R2 / invariant I2), and the `.save all` at :3161
    # above is emitted ONLY when save_all_v is 1 — the schema default is 0.
    # Measured on the committed save_all_v=0 sky130_tests/test_nfet_final
    # state: block WITH the leader -> 13 vectors, 6 device parameters, 5 node
    # v(); block WITHOUT it -> 7 vectors, 6 device parameters, ZERO node v().
    # Two `.save all` lines in one deck were re-measured harmless.
    #
    # ⚠ AND THE CARDS GO THROUGH BARE. `.save @m.x1.xm4.m<model>[id]`, never
    # `.save i(@...)` — the wrapper is the READ shape (op_annot::vector), and a
    # wrapped card produces no vector and no diagnostic (rule R4 / spec
    # landmine 1 / issue 0607). One name builder, two consumers (invariant I1):
    # nothing here rebuilds, re-wraps, sorts or dedupes a card.
    if {[ase::op_gate_on [ase::state_get $state save_op_params {}]]} {
      set opblk [ase::op_cards_for $netlist_text]
      if {$opblk ne {}} {
        lappend lines \
          "* op_annot device operating-point save cards (Outputs > Save All)"
        foreach opl [split [string trimright $opblk "\n"] "\n"] {
          lappend lines $opl
        }
      } elseif {![ase::op_cards_hit $netlist_text]} {
        # No record for THIS netlist text: the artifact is one this session
        # never netlisted, or one edited since (the ase::run_existing shape).
        # Emitting the held block anyway would name devices that may not be in
        # this deck, and a wrong name fails SILENTLY — a green run with blank
        # rows (spec landmine 2). So: no cards, and say so.
        ase::echo "ASE: this deck was rendered from a netlist artifact that\
 carries no captured OP save cards, so device operating-point parameters were\
 NOT saved. Use Simulation > Netlist and Run to regenerate both together." \
          error
      }
      # else: a HIT whose block is empty — nothing below this cell is
      # annotatable. op_cards_capture already reported that, in its own words;
      # repeating it here as a staleness complaint would be a lie.
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
