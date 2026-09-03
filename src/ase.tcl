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
# {render_deck run_cmd log_file result_probe raw_file} (proc names), plus one
# OPTIONAL sixth hook, `capabilities` (issue 0948): the PROBE RUN that answers
# what the program that will actually start can do. Optional, and that is a
# decision: a hand-built five-hook registration must keep registering, and a
# future backend must not have to write a probe before it may register at all.
# v1 registers `ngspice` only; the only ngspice literals outside the
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
  # than a literal: state_serialize writes every non-empty schema key, so a
  # literal default would land in all 104 committed .state files and break the
  # five load->save byte-identity rows (F3/G3/R4/V4/R2).
  #
  # ⚠ THE POLARITY IS INVERTED AS OF 2026-08-29 (issue 0927, the user's call).
  # The key is now TRI-STATE and `{}` means "the default", which is ON:
  #     {} / absent  -> ON   (the default; what all 104 committed states carry)
  #     0 / no|false -> OFF  (the ONLY thing a state file ever spells out)
  #     1 / anything -> ON
  # The user's sentence: *"a saved state would have to say NOT to save all OP
  # params, so that users who start using existing test-benches don't need to do
  # more work to get their OP info."* Off is the value that costs a key; on is
  # free. That is what keeps the 104 files byte-identical THROUGH the flip —
  # nothing on disk had to change, because the default is still the empty value.
  # ⚠ ONE CONSEQUENCE, AND IT IS NOT RECOVERABLE: before the flip, OFF was ALSO
  # `{}`. A state a user deliberately unticked is byte-identical to one that
  # never heard of the key, so it flips ON with the rest. Ticking it off again
  # now writes `save_op_params 0` and sticks.
  variable omit_if_empty {cosim save_op_params}
  # simulator name -> hooks dict: the five REQUIRED hooks
  # {render_deck run_cmd log_file result_probe raw_file}, plus the OPTIONAL
  # `capabilities` (issue 0948).
  variable backends [dict create]
  # WHAT THE PROGRAM THAT WILL ACTUALLY START CAN DO (issue 0948).
  # Key   = the RESOLVED ABSOLUTE PROGRAM PATH, never the backend name and
  #         never the registered entry's name. Two entries can name one file,
  #         one name can be re-pointed at another file, and a user can rebuild
  #         the file in place; only the path identifies the thing measured.
  # Value = {stamp <ase::cap_stamp of that file> caps <the answer dict>}.
  # In memory, session-lifetime, and NEVER written to disk beside the
  # simulator list: persisting it would buy one probe per session (measured at
  # ~10 ms) and cost a file format, a corruption arm and a staleness arm.
  # NOTHING IS EVER STORED UNDER AN EMPTY KEY -- see ase::sim_capabilities,
  # where the guards that return before a probe also return before a write.
  variable sim_caps [dict create]
  # HOW LONG THE WHOLE MEASUREMENT MAY TAKE, in milliseconds (issue 0953).
  # ONE budget for the whole probe, shared by every run inside it, not a cap
  # per run: the measured defect was two runs each paying a ten-second cap
  # buried in the runner, so a program slow to start froze the user's Run
  # gesture for 20.0 s and was then called not a simulator.
  # GENEROUS ON PURPOSE. A healthy probe was measured at 0.014 s cold and
  # nothing at all warm, so thirty seconds is never felt by a working
  # simulator, and it is deliberately longer than the eleven-second-to-start
  # build issue 0953 names -- a bound tight enough to cut that one off would
  # keep the defect for the very user the issue is about.
  variable cap_budget_ms 30000
  # Which wall-clock cap this box actually has, worked out once per session by
  # ase::cap_timeout_cmd. ZZUNKNOWN means "not looked for yet"; empty means
  # "looked for, and this box has none".
  variable cap_timeout_prefix ZZUNKNOWN
  # Counter behind the per-measurement scratch directory name (issue 0951).
  # Two probes in ONE process must not be handed the same place either.
  variable cap_seq 0
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
# WARNING, pre-existing and NOT closed here (casemode batch item 6 found it while
# fixing the same defect in its own field expansion): `-nocommands` does NOT stop
# a command substitution that sits inside the ARRAY INDEX of a variable
# reference. MEASURED on 8.6.14 --
#   set ::RAN 0 ; subst -nocommands -nobackslashes {$A([set ::RAN 1])/x}
# leaves ::RAN at 1. So a model path of the form `$env([exec ...])/models` in a
# STATE FILE runs that command when the path is expanded. `::sim_profile_expand_vars`
# (src/xschem.tcl) is the variables-only expander written for the profile fields
# and is what this should use; it is left alone here because model paths are not
# item 6's to change and every consumer of this proc is another item's. Recorded
# in doc/claude/specs/simulator_profiles.md section 5.
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
# --- The simulator binary registry, rc layer (issue 0931) --------------------
#
# WHAT THE USER COULD NOT DO BEFORE THIS. They have an ngspice build of their
# own, somewhere that is not on PATH. There was no place in ASE-L to say so:
# ase::backend::ngspice::run_cmd returned a hardcoded bare `ngspice`, so the
# only lever was the PATH of the shell that launched xschem -- global to the
# whole process, invisible from inside it, and impossible to name, list or
# take back.
#
# ::ASE_SIMULATORS is a list of entry dicts, each
#     name <label>  path <program>  args <extra argv>  backend <name or empty>
# and ::ASE_SIMULATOR names the one to put in force. Both are `set_ne` for the
# same reason ASE_DEFAULT_MODELS is: an rc -- xschemrc, or a PDK's
# cadence_style_rc -- is sourced by xinit.c BEFORE xschem.tcl sources this
# file, so a value the rc set survives, and this line only supplies the stock
# empty default. That ordering is also why an rc CANNOT call ase::sim_register
# directly: the proc does not exist yet when the rc runs. The rc declares data;
# the seed block at the end of the registry section below turns it into
# entries.
#
# REMOVING one is the rc no longer declaring it: the registry is rebuilt from
# these two variables at every startup, so nothing lingers. An entry removed
# in-session with ase::sim_unregister comes back at the next start, and the
# user is told so at the moment they remove it.
set_ne ASE_SIMULATORS {}
set_ne ASE_SIMULATOR  {}

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
#
# THE FIVE BELOW ARE THE WHOLE REQUIREMENT (issue 0948). `capabilities` -- the
# probe run that answers what the registered build can actually do -- rides in
# the same dict when a backend offers one, and is simply carried through by the
# `dict set` below. It is deliberately NOT in this loop: making it required
# would break every hand-built five-hook registration already in the tree
# (tests/headless/test_ase_core.tcl builds two) and would oblige a future
# backend to write a probe before it could register at all. A caller that
# wants the answer asks ase::sim_capabilities, which says "not known" rather
# than guessing when a backend declares no probe.
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
# --- Simulator binary registry (issue 0931) ---------------------------------
#
# ONE resolver answers "which program will actually be started", and every
# caller renders what it says. The whole of ase::backend::ngspice::run_cmd
# used to be
#
#     return [list ngspice -b $deckpath 2>@1]
#
# -- a hardcoded bare name that ignored its own state argument, so a user with
# a build of their own had no lever but the process PATH, and no way to name,
# list or remove what they had chosen.
#
# WHY ONE RESOLVER AND NOT A SECOND SOURCE OF TRUTH. The warning at
# ase::run_deck -- "auto_execok-resolving the command afterwards would be a
# SECOND source of truth about which binary ran, computed at a different
# instant from the exec that ran it" -- forbids RE-deriving argv0 after the
# fact for the log header. It does not forbid deriving it once. Here it is
# derived once, inside run_cmd, and the very same string is both handed to
# `execute` and stamped into the run log's `command` line, so the log still
# records exactly what was launched. ase::sim_status is also the answer a
# future caller asks for "is a simulator available" -- today twelve places
# across twelve test suites answer that with their own `auto_execok ngspice`
# call, by a different rule from the one that launches. Repointing them is a
# separate item; this is the contract they would use.
#
# WHY NOTHING GOES IN ase::schema_keys. The binary is a fact about this
# machine, not about the design; state files are committed and shared. A new
# schema key that is not in the omit-if-empty set is written into all 104
# committed .state files and breaks the five load-then-save byte-identity
# rows. The registry lives entirely in the rc layer plus USER_CONF_DIR.
#
# LAYERS, in the order they are applied:
#   1. the rc layer  -- ::ASE_SIMULATORS / ::ASE_SIMULATOR, seeded at the end
#                       of this section, entries marked origin `rc`
#   2. the user file -- USER_CONF_DIR/ase_simulators, read once at startup by
#                       xschem.tcl beside the other startup loaders, entries
#                       marked origin `conf`
#   3. this session  -- ase::sim_register from the CIW, a script, or the
#                       dialog that item S2 will add, entries marked `session`
# The user file is read AFTER the rc seed on purpose: a personal entry wins a
# same-name collision with a workarea rc. It never carries a copy of an rc
# entry, so a later rc edit is never shadowed by a frozen copy.
#
# WHEN NOTHING IS REGISTERED, NOTHING CHANGES. ase::sim_status then answers
# with the bare backend name and auto_execok's file, and run_cmd builds the
# byte-identical command it always built. That is not a courtesy, it is the
# contract: a user who registers nothing must not be able to tell this
# section exists.

namespace eval ase {
  # entry name -> entry dict. A Tcl dict preserves insertion order, and the
  # order entries were registered in is the order the user sees them.
  variable simulators [dict create]
  # the entry name in force, or empty for "no choice made -- use PATH".
  variable sim_use {}
  # which layer is currently registering, stamped into every entry's `origin`
  # field. Only the seed block and ase::sim_load_conf ever change it, and both
  # restore it, so an ordinary call is always `session`.
  variable sim_origin session
  # EVERY sentence ase::sim_say has said since the last clear, in the order it
  # said them, so a dialog can show the user the very words the CIW got
  # instead of composing a second version of them (issue 0937;
  # ase::sim_said / ase::sim_said_clear).
  #
  # A LIST, NOT ONE STRING, AND THAT IS ISSUE 0941. One gesture can have more
  # than one true thing to say: taking away a simulator that a startup
  # configuration file put there, while it is the one in use, says BOTH which
  # simulator takes over AND that this one will be back the next time xschem
  # starts. A single-string recorder kept only the last of the two, so the one
  # line the Simulators window can show never told the user that the program
  # which will actually run had just changed. What a reader would otherwise
  # assume -- that this holds "the last sentence" -- is exactly what the
  # defect was made of.
  variable sim_said {}
}

# THE MINT. Every user-facing sentence about a simulator entry is written
# here, once, and rendered by callers -- the registration report, the
# resolver's `why`, the refusal ase::sim_exe raises, the warning run_cmd
# echoes. A caller that re-worded one of these would be the defect ruling
# D5-4 is about, and the structural row D6 of
# tests/headless/test_ase_simreg_0931.tcl greps this file for exactly these
# phrases and fails if any of them occurs more than once.
#
# PLAIN ENGLISH IS A REQUIREMENT, NOT A STYLE. Each sentence says what
# happened AND what the user can do about it, at a ninth-grade reading level,
# with no internal vocabulary in it: no proc names, no variable names, no
# state names, nothing about auto_execok. The suite scans these sentences for
# machinery words and reds if it finds any.
#
# ⚠ NOTHING BELOW `switch` MAY CARRY A COMMENT, AND A READER WILL ASSUME IT
# MAY. A switch body is parsed as a LIST of pattern/body pairs, not as a
# script: a `#` line inside it becomes a PATTERN, the next word becomes its
# BODY, and every pair after it shifts by one. Measured on this tree while
# writing issue 0948's two kinds: a comment placed between two cases silently
# ate `path_in_force`, which then fell through to the catch-all sentence and
# reddened row R9 of tests/headless/test_ase_simreg_0931.tcl. Notes about a
# kind go here, above the switch, or inside that kind's own body.
#
# THE TWO 0948 KINDS PUT THE PROGRAM'S LOCATION FIRST, ON PURPOSE. They are
# about a PROGRAM, not about a list entry, so they name the file and never the
# entry's name: a user who registered three builds needs to know which file
# misbehaved, and the entry's name is in front of them in the Simulators
# window already. Location-first is also what keeps the structural row F6 of
# tests/headless/test_ase_simcaps_0948.tcl meaningful -- that row takes the
# sentence apart at the user's own words and demands each fixed piece exist
# exactly once in this file, and a location dropped into the MIDDLE of a
# sentence leaves a fragment of itself glued to the words in front of it,
# which no source line can ever match.
#
# THE THIRD ONE, `cap_no_answer`, SAYS ONLY WHAT WAS ESTABLISHED (issue 0953).
# The program was given a tiny test circuit and had not finished with it inside
# the time the measurement was allowed. That is ALL that was found out, and the
# sentence claims nothing more -- it does not say the program is broken, and it
# does not say it is not a simulator, because neither was measured. It says how
# long it waited, offers the likeliest innocent explanation, and says what
# happens next, because the run is going ahead either way.
#
# NEITHER OF THEM REFUSES ANYTHING. A build that keeps only the last analysis
# still produces that last analysis, and the probe is a heuristic; stranding a
# user mid-gesture on either would be worse than the failure it prevents. They
# say what happened and what to do instead. The ruling that choice needs is on
# the user's queue as issue 0948.
# ISSUE 0975: ONE PLACE CHOOSES BETWEEN A SINGULAR AND A PLURAL WORDING.
#
# WHAT A READER WOULD OTHERWISE ASSUME: that "of $n devices" is fine because a
# run always has several devices in it. It is not -- the shape that produced
# issue 0975 is a run asking about exactly one device, and it rendered "the
# operating-point numbers of 1 devices". Nothing else in this surface is written
# that carelessly and the sentence is one a user is meant to read and act on.
#
# It takes both wordings whole rather than a stem and a suffix, because two of
# its callers are not a word but a clause ("This is the one it did not answer
# for" / "These are the ones it did not answer for").
proc ase::sim_plural {n one many} {
  if {$n eq {1}} { return $one }
  return $many
}

proc ase::sim_why {kind name path {extra {}}} {
  switch -- $kind {
    empty_path {
      return "No program file was given for the simulator named $name. Type the full location of the program you want to start, such as a build of your own."
    }
    missing {
      return "There is no file at $path, which you registered as the simulator named $name. Check that you typed the location correctly, or point this entry at a different file."
    }
    notfile {
      return "$path is a folder, not a program. It is registered as the simulator named $name. Point this entry at the simulator program inside that folder."
    }
    notexec {
      return "The file $path is not marked as a program you can run. It is registered as the simulator named $name. Use chmod +x on it, or point this entry at a different file."
    }
    badvar {
      return "The location given for the simulator named $name mentions a setting this session does not know about, so it cannot be turned into a real file name: $path"
    }
    noentry {
      if {[llength $extra]} {
        return "You asked for the simulator named $name, but nothing by that name has been registered. The ones you can choose from are: [join $extra {, }]."
      }
      return "You asked for the simulator named $name, but no simulator has been registered yet. Register one before choosing it."
    }
    wrongbackend {
      return "The simulator named $name was registered for [lindex $extra 0], so it cannot be used to run [lindex $extra 1]. Pick one that was registered for [lindex $extra 1], or make no choice at all and the program named [lindex $extra 1] on your PATH will be used."
    }
    ambiguous {
      return "More than one simulator is registered and none of them has been picked: [join $extra {, }]. Until you pick one, the program named $name on your PATH is what will start."
    }
    rc_removed {
      return "The simulator named $name was put there by a startup configuration file, so it will be back the next time xschem starts. Edit that file to remove it for good."
    }
    nowrite {
      return "Your simulator list could not be saved to $path, so the simulators you added will be gone when xschem closes. Check that the folder exists and that you can write to it. The system said: $extra"
    }
    badconf {
      return "Your saved simulator list in $path could not be read, so no simulators were restored from it. Fix or delete that file. The system said: $extra"
    }
    badrcentry {
      return "One simulator listed in your startup configuration file could not be set up, so it was skipped and the others were kept. Fix that one entry in that file. The system said: $extra"
    }
    badrclist {
      return "The list of simulators in your startup configuration file could not be read at all, so no simulators were set up from it. Check that the braces and brackets on that line match. The system said: $extra"
    }
    removed_now_path {
      return "You removed $name, which was the simulator being used. Nothing of your own is picked now, so xschem will start the program your system finds on your PATH. Pick or add one in the simulator list whenever you want a program of your own back."
    }
    removed_now_other {
      return "You removed $name, and $extra is now the simulator that will be used, because it is the only one left on your list. Pick a different one if that is not what you want."
    }
    in_force {
      return "The simulator named $name is the one that will be used, and $path is the program that will start."
    }
    path_in_force {
      return "You have not picked a simulator of your own, so xschem will start the program named $name that your system finds on your PATH. Add one to the list, or pick one that is already on it, if you would rather run a build of your own."
    }
    cap_no_append {
      return "$path, which is the program that will run your simulation, keeps only the last analysis of a run and throws the earlier ones away as it goes. Your run has more than one analysis in it, so everything but the last one would be lost. Run one analysis at a time, or use a build that adds each analysis to the results file."
    }
    cap_not_a_simulator {
      return "$path, which is the program the simulator you picked will start, produced no results at all when it was tried on a tiny test circuit. Check that it really is a circuit simulator, or point this entry at a different file."
    }
    cap_no_answer {
      return "$path, which is the program the simulator you picked will start, was given a tiny test circuit to try and had still not finished with it after $extra seconds, so there was no way to find out what it can do. It may simply be slow to start. Your run is going ahead anyway, and this will be tried again the next time you press Run."
    }
    op_tier_blanket {
      return "Your simulator can hand back all of one device's operating-point numbers in a single request, so this run asked once per device instead of once per number. The requests are made just before the operating point and nowhere else, so nothing is recorded at every step of a transient that happens to be in the same run."
    }
    op_numbers_missing {
      set n [lindex $extra 0]
      set back [lindex $extra 1]
      set miss [lindex $extra 2]
      set shown [lrange $miss 0 4]
      set rest [expr {[llength $miss] - [llength $shown]}]
      set tail [join $shown {, }]
      if {$rest > 0} { append tail ", and $rest more" }
      ## ISSUE 0975, defect 2: "of 1 devices". Both clauses that count go
      ## through ase::sim_plural, so the number and the word it agrees with
      ## cannot drift apart. There are two of them, not one: the list intro
      ## "These are the ones" was plural-only as well.
      ##
      ## ISSUE 0975, defect 1, and why the cause clause STAYS here: some came
      ## back and some did not, which is issue 0965's own shape. There a
      ## differently-spelled device really is the likely reason and saying so is
      ## the whole value of the sentence. It is the ALL-OR-NOTHING shape below,
      ## op_numbers_none, where nothing established any cause at all.
      return "This run asked your simulator for the operating-point numbers of $n [ase::sim_plural $n device devices] and only $back of them came back, so the rest will show nothing at all on your schematic. [ase::sim_plural [llength $miss] {This is the one it did not answer for} {These are the ones it did not answer for}]: $tail. That almost always means the deck spells a device differently from the way the schematic does. Save the schematic, netlist it again and re-run; if the same devices keep coming back empty, this run's log is where to look."
    }
    op_numbers_none {
      ## ISSUE 0975, defect 1: WHEN NOTHING CAME BACK, NAME NO CAUSE.
      ##
      ## WHAT THE USER READ BEFORE. The results file is there, it holds the
      ## rest of the run, and it has no operating point in it at all. They were
      ## told the deck spells a device differently from the way the schematic
      ## does -- a cause the code never established, asserted on the one
      ## surface built to stop exactly that kind of confident claim. Measured
      ## in the source it replaced: the arm above reads how many came back and
      ## interpolates it, and the only `if` in the whole body was on how many
      ## names were left off the end of the list. There was no branch on it, so
      ## the same clause fired at three-of-five, where it is right, and at
      ## none-of-any, where nobody knows.
      ##
      ## AND DO NOT PUT A CAUSE BACK HERE. The obvious candidate is an
      ## operating point that did not converge, and it did NOT reproduce: this
      ## pass rendered the shipped bandgap bench and ran it through the real
      ## ngspice -- exit 0, a 284,283-byte results file, an Operating Point
      ## plot complete with 891 vectors, and zero singular-matrix or
      ## convergence lines anywhere in the log. Naming it would repeat the
      ## defect with a different noun. What IS established is that the file
      ## exists, that the operating point is not in it, and that the simulator
      ## wrote a log.
      ##
      ## A COMMENT MAY NOT SIT BETWEEN TWO ARMS OF A BRACED `switch`; Tcl reads
      ## it as an extra pattern with no body and the whole proc raises. That is
      ## why this block is inside the arm rather than above it.
      set n [lindex $extra 0]
      set name [lindex $extra 1]
      return "This run asked your simulator for the operating-point numbers of $n [ase::sim_plural $n device devices] and not one of them came back, so no device numbers will appear on your schematic at all. The results file $name is there and holds the rest of the run, but there is no operating point in it. Something stopped the operating point itself from finishing, and this run cannot tell you what: open the log your simulator wrote for this run and read what it printed there."
    }
    op_numbers_no_file {
      return "Your simulator finished without reporting any problem, but it produced no results file at all -- no [file tail $extra] was written into the run folder. So there are no numbers to put on your schematic and the waveform window has nothing to show either. One thing that causes this: when a run is asked for device numbers on one short line, a single device name the simulator cannot match is enough to make it throw the whole result away and still finish quietly. Open this run's log to see what it printed, then ask for the numbers one device at a time."
    }
    op_tier_perdevice {
      set head "This run asked your simulator for each device's operating-point numbers one request at a time. That is the way that always works, and it is where the numbers on your schematic come from."
      switch -- $extra {
        unknown {
          return "$head xschem was not able to find out anything about what $path can do, so it did not try a shorter way. Nothing is wrong; the deck is just longer than it has to be."
        }
        unsafe {
          return "$head There is a much shorter way your simulator would accept, but it is all or nothing: if a single device in your design has a name the simulator cannot match, it throws the whole operating point away and says nothing. Until that risk is gone, xschem asks the safe way."
        }
        toomany {
          return "$head The shorter way puts every device on one request line, and your design has too many devices to fit on one line, so the safe way is the only one left."
        }
        forced {
          return "$head You asked for it to be done this way."
        }
      }
      return "$head Your simulator cannot do either of the shorter ways, so this is the only one available. Nothing is wrong; the deck is just longer than it has to be."
    }
    op_tier_writeline {
      return "This run asked for every device's operating-point numbers on one short request line, because you chose that by hand. Watch out: if even one device in your design has a name the simulator cannot match, it throws the whole operating point away and writes no results at all, without complaining. If your schematic comes up with no device numbers on it anywhere, that is why — ask one device at a time instead."
    }
    op_tier_forced {
      return "You chose by hand how this run would ask for device operating-point numbers, so what your simulator can actually do was not taken into account. Clear that choice whenever you want xschem to decide for itself again."
    }
  }
  return "Something is wrong with the simulator named $name."
}

# THE RECORDER. Mint a sentence, REMEMBER it, and say it -- the one route by
# which a sentence about a simulator reaches the user. Returns the sentence.
#
# WHY THIS EXISTS AT ALL, AND WHAT A READER WOULD OTHERWISE ASSUME (issue
# 0937). The Simulators dialog has to show the user, IN the dialog, the same
# sentence the CIW just got. Its two ways to get it are to re-derive it --
# which is the very defect ruling D5-4 forbids, and which is not even
# possible for the removal sentences, because after the removal the entry is
# gone -- or to read back what was actually said. So every render-and-echo
# site in this section goes through here, and no caller renders a fresh
# sentence into ase::echo by hand any more. Row R10 of
# tests/headless/test_ase_simreg_0931.tcl greps the comment-stripped file for
# that echo-the-mint construct and reds if one comes back.
#
# The tag is the CIW pane's style name -- input / result / error / note are
# the four the pane actually styles -- and defaults to `error` because most
# of what this section has to say is a refusal.
#
# APPENDED, NEVER OVERWRITTEN (issue 0941). Two say-sites can fire in one
# gesture, and both sentences are true and both are the user's business; the
# recorder that kept only the last one threw away the half that says what
# happens next. Every reader clears first and reads back after, so the record
# is always the sentences of ONE gesture. The RETURN value is unchanged and is
# still this call's own sentence, not the record.
#
# ⚠ THE RECORD IS WRITTEN BY ITS FULL NAME, NOT THROUGH `variable` (issue
# 0963). What a reader would otherwise assume is that the two spellings are the
# same thing. They are not once this command is WRAPPED: `variable sim_said`
# binds to whatever namespace the command lives in AT CALL TIME, so a caller
# that renames ::ase::sim_say aside and puts its own proc in front of it -- how
# every test that wants to know WHICH sentence was said does it, and how a
# future dialog that wants to tee the CIW would do it -- silently starts
# appending to ::sim_said in the global namespace. Measured on Tcl 8.6: the
# sentence still reaches the user, ase::sim_said still answers empty, and the
# dialog that exists to show the user the very words the CIW got shows nothing,
# with no error anywhere.
proc ase::sim_say {kind name path {extra {}} {tag error}} {
  set m [ase::sim_why $kind $name $path $extra]
  lappend ::ase::sim_said $m
  ase::echo $m $tag
  return $m
}

# What was said about a simulator since the last clear, as ONE string a status
# line can show, or empty. A caller that wants to show the user what a gesture
# said clears this first, does the gesture, then reads it back -- so a gesture
# that said nothing is visibly nothing rather than the sentence before it.
#
# JOINED IN THE ORDER THEY WERE SAID (issue 0941). A gesture with two things
# to say hands back both, the what-happens-next one first, which is the order
# the CIW got them in and the order ase::sim_unregister's say-sites are pinned
# in. A gesture with ONE thing to say hands back exactly that sentence and
# nothing else, so every caller written before 0941 sees no change at all.
proc ase::sim_said {} {
  variable sim_said
  return [join $sim_said { }]
}

proc ase::sim_said_clear {} {
  variable sim_said
  set sim_said {}
  return {}
}

# THE VALIDATOR. Four ordered guards, each its own line and its own thing to
# say, returning the `kind` that names what is wrong or empty when the file
# can be started.
#
# THE `file isfile` GUARD IS NOT REDUNDANT AND IT IS THE ONE A READER SKIPS.
# Measured on this tree: `file executable` answers 1 for a DIRECTORY. An
# executable-only check therefore lets a folder through and the user finds
# out when the run fails. ase::cosim_build_script -- this tree's only other
# "an rc variable names an executable" resolver -- has exactly that hole, and
# returns empty with no message in both of its bad arms; the sentence the
# user then reads blames the variable as unset when it is set and merely
# wrong. That silence is the shape this whole section exists not to copy.
proc ase::sim_check {path} {
  if {$path eq {}}               { return empty_path }
  if {![file exists $path]}      { return missing }
  if {![file isfile $path]}      { return notfile }
  if {![file executable $path]}  { return notexec }
  return {}
}

# THE SAME VALIDATOR, ASKED ABOUT A STORED ENTRY RATHER THAN ABOUT A FILE
# NAME. It takes the ENTRY, not the path, because the one question it can add
# to ase::sim_check was already answered once and cannot be asked again.
#
# THE GUARD, AND WHAT A READER WOULD OTHERWISE ASSUME (issues 0933 and 0938).
# A location written the portable way, as $::PDK_ROOT/bin/ngspice, is stored
# as typed when the setting it names is not set in this session --
# registration reports it and skips the normalisation. Handing that literal to
# ase::sim_check answers `missing`, so the list would tell the user "there is
# no file at $::PDK_ROOT/bin/ngspice" and send them looking at a disk,
# contradicting in writing the sentence registration had just given them about
# a setting. Rows R5 and R7 measure exactly that contradiction, so the answer
# about the SETTING has to survive to here somehow.
#
# IT SURVIVES AS A RECORDED VERDICT, AND IT IS NEVER WORKED OUT AGAIN. The
# obvious-looking thing -- try the substitution again here and answer badvar
# when it fails -- is what this proc used to do, and it is issue 0938: turning
# a location into a file name is NOT idempotent. ase::sim_register does it
# once and stores the RESULT, and a result that came back carrying a literal
# dollar sign (a PDK kept under a folder with one in its name) fails the
# second pass. A runnable simulator, registered with ok 1 and shown in the
# list with no problem against it, was then refused at the run with a sentence
# blaming a setting its path never mentions. Row R7 could not see it, because
# the list and the run were wrong together; rows R13 and R18 can.
#
# A MISSING `varok` MEANS "NOTHING TO COMPLAIN ABOUT", so an entry dict built
# anywhere else can never start silently answering badvar.
#
# What is deliberately NOT done here: the FILESYSTEM facts are still worked
# out fresh on every call, because they change under a live entry -- row R6
# deletes the program and row R14 expects the list to say the file is gone
# rather than go on blaming a setting. Only the answer about the setting is
# remembered. The storage half of 0933 stays filed: see
# doc/claude/issues/0938 for what a restart can no longer tell apart.
proc ase::sim_entry_kind {entry} {
  if {[dict exists $entry varok] && ![dict get $entry varok]} { return badvar }
  return [ase::sim_check [dict get $entry path]]
}

# THE PER-ENTRY REASON: the one sentence a list can show against ONE entry,
# or empty when that entry can be started. This is what the Simulators
# dialog's Problem column is filled from (issue 0937).
#
# RE-VALIDATED ON EVERY CALL, NEVER READ BACK FROM THE ENTRY'S `ok` FIELD.
# `ok` is a boolean with no words in it, and it answers a question about the
# PAST -- the file can be deleted, a rebuild can leave it without its
# executable bit, a mount can go away, all without anything re-registering.
# Row R6 deletes the program under a live entry and expects the row to
# explain itself, with `ok` untouched throughout.
proc ase::sim_entry_why {name} {
  variable simulators
  if {![dict exists $simulators $name]} {
    return [ase::sim_why noentry $name {} [dict keys $simulators]]
  }
  set e [dict get $simulators $name]
  set p [dict get $e path]
  set kind [ase::sim_entry_kind $e]
  if {$kind eq {}} { return {} }
  return [ase::sim_why $kind $name $p]
}

# Register simulator `name` at `path`. Options: -args <extra argv list>,
# -backend <backend name, or empty for any>.
#
# Returns 1 when the entry can be started, 0 when it was recorded but cannot.
# A malformed CALL -- no name, an unknown option, a -args value that is not a
# list -- raises; a bad PATH does not.
#
# WHY A BAD PATH IS RECORDED AND NOT REFUSED. Refusing would throw the user's
# typing away mid-gesture and leave the list with nothing to show them, so
# there would be nothing to fix. It is recorded with ok 0 and REPORTED out
# loud, because silence is this feature area's failure mode.
proc ase::sim_register {name path args} {
  variable simulators
  variable sim_use
  variable sim_origin
  set eargs {}
  set backend {}
  set p $path
  set kind {}
  # THE CASE-MODE FIELDS, FROM `fluid-editing`, AND THEY LIVE HERE RATHER THAN
  # ON A `sim()` ROW ON PURPOSE (the annotate merge). `fluid-editing` kept the
  # requested case mode and the `-n` flag as fields of a simulator PROFILE in
  # the stock `sim()` array, edited in Simulation > Configure simulators and
  # tools, while this registry held which program runs. Two stores meant two
  # answers about one machine: nothing stopped the case mode describing a
  # binary the user was no longer running, and no gesture invalidated one when
  # the other changed. They are one record now, so "which program" and "how it
  # treats case" cannot drift apart, and ase::sim_caps_clear below invalidates
  # the measurement for both at once.
  #
  # `casemode {}` means "no request of my own" -- ase::sim_casemode_requested
  # then falls to the global floor. It is NOT the same as `fold`: the floor is
  # a setting the user may change once for every simulator.
  set casemode {}
  set nospiceinit 0
  # THE ANSWER ABOUT THE SETTING, WORKED OUT HERE AND ONLY HERE (issue 0938),
  # and recorded on the entry below so no later reader has to work it out
  # again. 1 means "there was nothing in this location this session could not
  # read"; 0 means the sentence about a setting is the one that belongs to
  # this entry for as long as it is registered.
  set varok 1
  if {[llength $args] % 2} {
    return -code error "ase: simulator options come in pairs, like -args or -backend followed by a value: $args"
  }
  foreach {o v} $args {
    switch -- $o {
      -args {
        if {[catch {llength $v}]} {
          return -code error "ase: the extra arguments for simulator '$name' are not a proper list: $v"
        }
        set eargs $v
      }
      -backend { set backend $v }
      -casemode {
        # A BAD MODE IS REFUSED, NOT SILENTLY DOWNGRADED. `sim_casemode_valid`
        # is the same validator the netlister and the run flag read through, so
        # a spelling this line accepts is one every consumer accepts.
        if {$v ne {} && ![sim_casemode_valid $v]} {
          return -code error "ase: '$v' is not a case mode for simulator\
 '$name' (known: fold preserve distinguish, or empty for the global default)"
        }
        set casemode $v
      }
      -nospiceinit {
        if {![string is boolean -strict $v]} {
          return -code error "ase: -nospiceinit for simulator '$name' wants a\
 true/false value, not '$v'"
        }
        set nospiceinit [expr {$v ? 1 : 0}]
      }
      default {
        return -code error "ase: unknown option '$o' registering simulator '$name' (known: -args -backend -casemode -nospiceinit)"
      }
    }
  }
  if {$name eq {}} {
    return -code error "ase: a simulator needs a name to be registered under"
  }
  # The portable form the model files already use -- a path written as
  # $::PDK_ROOT/bin/ngspice -- is expanded here, variables only, no command
  # execution. Failure is a bad path, not a bad call, so it is reported and
  # recorded like any other.
  if {$p ne {}} {
    if {[catch {ase::expand_path $p} out]} {
      # A LOCATION THAT ALREADY NAMES A REAL FILE IS A FILE NAME, NOT A
      # TEMPLATE (issues 0938 and 0945). What a reader would otherwise assume
      # is that failing to read a setting out of a location makes the location
      # unusable. It does not, in the one case that matters: a user whose PDK
      # lives under a folder with a dollar sign in its name has a location
      # that no setting can be read out of AND a program sitting at it. Both
      # ways in land here -- typing that real path (0945), and re-reading the
      # saved list at the next start, since what is saved is the location
      # already turned into a file name (0938's restart half).
      #
      # This can only ever turn a refusal into a run: it fires exactly where
      # the entry was about to be recorded as unusable, and it defers to the
      # four filesystem guards below -- `file exists` only, so a folder is
      # still `notfile` and a file without its executable bit is still
      # `notexec`. A location naming a setting nobody set names nothing on the
      # disk, so that arm is untouched and still says what it always said.
      if {[file exists $p]} {
        set p [file normalize $p]
      } else {
        set kind badvar
        set varok 0
      }
    } else {
      # NORMALISED AT REGISTRATION, AND THIS IS LOAD-BEARING. ase::run_deck
      # does `cd` into the run directory before it launches the simulator, so
      # a path stored the way the user typed it -- bin/ngspice, or ../build/
      # ngspice -- would resolve against the RUN directory rather than
      # against wherever they were standing. Normalising once means the
      # stored value, the value every message shows, and the value handed to
      # `execute` are one string.
      set p [file normalize $out]
    }
  }
  if {$kind eq {}} { set kind [ase::sim_check $p] }
  if {$kind ne {}} { ase::sim_say $kind $name $p {} error }
  dict set simulators $name [dict create name $name path $p args $eargs \
                             backend $backend origin $sim_origin \
                             varok $varok \
                             casemode $casemode nospiceinit $nospiceinit \
                             ok [expr {$kind eq {} ? 1 : 0}]]
  # Registering the FIRST simulator puts it in force. Without this,
  # registering one simulator would do nothing visible at all and the user
  # would have to make a second, separate gesture to mean the obvious thing.
  # A later registration never steals the choice away from it.
  if {$sim_use eq {}} { set sim_use $name }
  # ADDING OR EDITING AN ENTRY MEANS LOOK AT THE PROGRAM AGAIN (issue 0950).
  # What a reader would otherwise assume is that the file stamp already covers
  # every reason an answer could be stale. It does not: a wrong answer taken in
  # a folder the simulator could not write into was served for the whole
  # session, in an ordinary folder, and nothing in the Simulators window could
  # clear it. Editing an entry is the user saying something about their
  # simulators changed, and it is the moment to look again.
  #
  # ⚠ IT GOES ON THE WRITER, NOT ON THE DIALOG, and that placement is the
  # point. Setup > Simulators and the Command window are two doors onto THIS
  # proc; putting the look-again in the dialog would leave the other door
  # broken and would breach src/ase_window.tcl's own rule that no logic is
  # re-implemented there. Row D12 of tests/headless/test_ase_simcaps_0948.tcl
  # reddens on that placement, which no behavioural row can see.
  ase::sim_caps_clear
  return [expr {$kind eq {} ? 1 : 0}]
}

# Remove one registered simulator. Raises on a name that was never
# registered, because the caller asked about something that is not there.
#
# TAKING OUT THE ONE IN FORCE SAYS WHAT HAPPENS NEXT (issue 0937). Measured
# at 439d1087 in all three arms -- the only entry, one of two, one of three --
# removing the simulator that was in force printed NOTHING AT ALL, while the
# program that would actually start changed underneath the user. What a
# reader would otherwise assume is that the silence is the ordinary case: it
# is not, it is the whole point of the removal, and the two arms below are
# the two different things that can happen to the choice.
#
# THE ORDER OF THE THREE SAY-SITES IS A CONTRACT, NOT A STYLE (rows R4, E13).
# The "it will be back the next time xschem starts" sentence must be said
# LAST, because a startup-configuration entry that was also in force says two
# sentences and the one a reader must end on is the one about the file they
# have to edit. Row E13 reads the LAST sentence a removal echoed, so a
# what-happens-next say-site added after the rc one would redden E13 and send
# the next reader bisecting onto the wrong change; row R4 pins the order in
# the source so no behavioural row has to.
proc ase::sim_unregister {name} {
  variable simulators
  variable sim_use
  if {![dict exists $simulators $name]} {
    return -code error "ase: [ase::sim_why noentry $name {} [dict keys $simulators]]"
  }
  set e [dict get $simulators $name]
  # Recorded BEFORE the removal: `sim_use` is about to be rewritten, and
  # afterwards there is no way left to ask whether this entry was the one
  # being used.
  set wasuse [expr {$sim_use eq $name}]
  dict unset simulators $name
  if {$wasuse} {
    set sim_use {}
    # One left after the removal is not a guess, it is the only answer; two
    # or more is a guess, and the choice is left empty so the user makes it.
    if {[dict size $simulators] == 1} {
      set sim_use [lindex [dict keys $simulators] 0]
    }
    # `note` is the CIW pane's dark-orange tag; the tags the pane actually
    # styles are input / result / error / note, and this is news, not an
    # error -- the user asked for the removal and got it.
    if {$sim_use eq {}} {
      ase::sim_say removed_now_path $name {} {} note
    } else {
      ase::sim_say removed_now_other $name {} $sim_use note
    }
  }
  if {[dict get $e origin] eq {rc}} {
    ase::sim_say rc_removed $name {} {} note
  }
  # The removal half of the look-again above (issue 0950). Taking an entry off
  # the list can change which program will start, so what was remembered about
  # the old one must not be served about the new one.
  ase::sim_caps_clear
  # NOT the sentence. Every caller here tests this as a boolean, and row E13
  # pins it at 1 for a removal that also had two things to say.
  return 1
}

# The registered entries, in the order they were registered. With a backend
# name, only those that can serve it -- an entry registered for no particular
# backend serves every backend.
proc ase::sim_list {{backend {}}} {
  variable simulators
  set out {}
  dict for {n e} $simulators {
    if {$backend ne {} && [dict get $e backend] ne {} \
        && [dict get $e backend] ne $backend} { continue }
    lappend out $e
  }
  return $out
}

# Put one registered simulator in force. An empty name clears the choice,
# which puts the program on the PATH back in charge.
proc ase::sim_select {name} {
  variable simulators
  variable sim_use
  if {$name eq {}} { set sim_use {} ; return {} }
  if {![dict exists $simulators $name]} {
    return -code error "ase: [ase::sim_why noentry $name {} [dict keys $simulators]]"
  }
  set sim_use $name
  return $name
}

# The name in force, or empty.
proc ase::sim_selected {} {
  variable sim_use
  return $sim_use
}

# Forget every registered simulator and every choice.
proc ase::sim_clear {} {
  variable simulators
  variable sim_use
  variable sim_said
  set simulators [dict create]
  set sim_use {}
  # THE RECORD OF WHAT WAS SAID GOES TOO (issue 0941). This puts the section
  # back to the state it had before anything was registered, and sentences
  # already said were about entries that no longer exist. It mattered only
  # once the recorder started accumulating: a reader that clears the registry
  # and then reads back what one later gesture said would otherwise get every
  # sentence from before the clear glued in front of it.
  set sim_said {}
  return 1
}

# THE RESOLVER. The single answer to "which program will actually be
# started", for `backend`. NEVER RAISES -- every caller here is either a menu
# predicate or a run about to start, and a resolver that throws would turn a
# wrong path into a stack trace instead of a sentence.
#
# Returns a dict:
#   ok        1 when something can be started, 0 when the user's own choice
#             cannot be honoured
#   exe       argv0, exactly as it will be handed to `execute`
#   args      the extra arguments that go before the deck
#   resolved  the absolute file this names, or auto_execok's answer when the
#             PATH is what is in charge. This is the field a caller asking
#             "is a simulator available" wants.
#   source    `registry` when a registered entry answered, `path` when the
#             program on the PATH did
#   entry     the registered name that answered, or empty
#   why       the one sentence to show the user, or empty when there is
#             nothing to say. NON-EMPTY WITH ok 1 IS REAL: it means the run
#             will proceed on the PATH program and the user should know why.
proc ase::sim_status {backend} {
  variable simulators
  variable sim_use
  set aeo [lindex [auto_execok $backend] 0]
  set pathans [dict create ok 1 exe $backend args {} resolved $aeo \
                           source path entry {} why {}]
  if {$sim_use ne {}} {
    if {![dict exists $simulators $sim_use]} {
      # Reachable from a startup configuration file that names a simulator it
      # never registered, which is a typo the user must be told about by
      # name. Neither honoured nor hidden.
      dict set pathans ok 0
      dict set pathans why [ase::sim_why noentry $sim_use {} [dict keys $simulators]]
      return $pathans
    }
    set e [dict get $simulators $sim_use]
    set eb [dict get $e backend]
    if {$eb ne {} && $eb ne $backend} {
      dict set pathans ok 0
      dict set pathans source registry
      dict set pathans entry $sim_use
      dict set pathans why [ase::sim_why wrongbackend $sim_use {} [list $eb $backend]]
      return $pathans
    }
    set p [dict get $e path]
    # RE-VALIDATED HERE, NOT TRUSTED FROM REGISTRATION TIME. The machine can
    # change between the two: the file gets deleted, a rebuild leaves it
    # without its executable bit, a mount goes away. The `ok` recorded at
    # registration answers a question about the past.
    #
    # ase::sim_entry_kind, not ase::sim_check: the entry-flavoured validator,
    # so what a list shows against this entry and what a run refuses with are
    # ONE sentence in the unknown-setting arm too (issue 0937, row R7). No
    # other field of this answer changes.
    #
    # THE ENTRY, NOT THE PATH (issue 0938). The validator reads the answer
    # about the setting that registration recorded on this entry; handing it
    # the bare path would ask it to work that answer out again, and working it
    # out twice is the regression 0938 is about.
    set kind [ase::sim_entry_kind $e]
    if {$kind ne {}} {
      return [dict create ok 0 exe $p args [dict get $e args] resolved {} \
                          source registry entry $sim_use \
                          why [ase::sim_why $kind $sim_use $p]]
    }
    return [dict create ok 1 exe $p args [dict get $e args] resolved $p \
                        source registry entry $sim_use why {}]
  }
  # No choice made. Registering the first simulator makes one, so an empty
  # choice with entries present means the user cleared it deliberately, and
  # the program on the PATH is what they asked for. More than one waiting is
  # still worth saying out loud -- reported, never guessed at.
  set cands {}
  foreach e [ase::sim_list $backend] { lappend cands [dict get $e name] }
  if {[llength $cands] > 1} {
    dict set pathans why [ase::sim_why ambiguous $backend {} $cands]
  }
  return $pathans
}

# argv0 for `backend`, or a clean refusal carrying the resolver's own
# sentence. The sentence is rendered, never re-worded.
proc ase::sim_exe {backend} {
  set s [ase::sim_status $backend]
  if {![dict get $s ok]} { return -code error "ase: [dict get $s why]" }
  return [dict get $s exe]
}

# --- What the registered simulator can actually do (issue 0948) --------------
#
# THE PROBLEM THIS SECTION EXISTS FOR, MEASURED, NOT ARGUED. The deck ASE-L
# emits asks the simulator to ADD each analysis to the results file (`set
# appendwrite`, see render_deck's 0929 block). A build that does not honour
# that keeps only the LAST analysis and throws the earlier ones away as it
# goes: measured on this box with two decks identical but for that one line,
# the same program, exit 0 both times, and NOT ONE WARNING OR ERROR LINE in
# either log -- one raw with an operating point AND a transient, one raw with
# the transient alone. The operating point the user asked for is computed and
# discarded, and pressing 6 on the schematic then says there are no operating
# point results. That is issue 0929's exact symptom, arriving silently through
# a door 0929 never guarded, and until this section nothing anywhere could
# even ASK whether the registered build honours it.
#
# ⚠ THE METHOD IS A PROBE RUN, NEVER A VERSION STRING. Measured: a stock
# ngspice and a build patched to ignore that one line print the byte-identical
# line "** ngspice-46+ : Circuit level simulation program". A version string
# cannot answer this question, so nothing here asks one.
#
# ⚠ AND THE VERDICT IS THE RESULT, NEVER THE EXIT CODE AND NEVER THE LOG.
# Measured: a blanket device save (`.save @m...[*]`) exits 0, WRITES a results
# file, and logs no warning and no error -- and the file holds a `constants`
# plot and no operating point at all. Anything that asked "did the command
# error" would call that a success. Every answer below is read out of the
# results file the probe's own deck asked for.
#
# ⚠ LAZY, NEVER AT STARTUP. The whole two-deck probe measures ~10 ms, so it is
# affordable on first use and there is no reason to spend it on a session that
# never runs a simulation.

# The identity of ONE program file: everything whose change means a different
# program. Empty when there is no file to stamp, which is the caller's signal
# that there is nothing to remember.
#
# PATH + MTIME + SIZE, and the point of the last two is a user who rebuilds
# their simulator IN PLACE. The path does not change, so a cache keyed on the
# path alone would serve last week's answer about a program that no longer
# exists, forever, with nothing the user could do about it and nothing telling
# them to. Modelled on ase::cosim_stamp, which stamps a build the same way and
# for the same reason.
proc ase::cap_stamp {path} {
  if {$path eq {}} { return {} }
  if {![file isfile $path]} { return {} }
  return [list path [file normalize $path] mtime [file mtime $path] \
                size [file size $path]]
}

# Is what we remember about a program still true of the file on disk?
#
# BIASED TOWARDS RE-MEASURING, exactly as ase::cosim_stale is: any doubt at
# all -- either stamp empty, the two not comparable, anything different --
# answers 1 and costs one ~10 ms probe. Answering 0 wrongly costs the user a
# silently truncated results file and no way to find out why.
#
# ⚠ THE SECOND ARM IS A BELT NO VALUE CAN CURRENTLY REACH, AND SAYING SO HERE
# IS THE POINT: nobody should read it as a measured behaviour. Measured on
# this Tcl, `string equal` handed exactly two values and no options never
# raises, whatever those two values are -- options are only looked for when
# there are more than two arguments, and there are always exactly two here. It
# is kept because the day this proc compares something richer than two strings
# is the day it starts mattering, and because falling INTO it answers
# re-measure while falling out of the proc would abort the run it was only
# reporting on. Row D9 of tests/headless/test_ase_simcaps_0948.tcl pins that
# both arms still answer 1, and says the same thing about reachability.
proc ase::cap_stale {stored live} {
  if {$stored eq {} || $live eq {}} { return 1 }
  if {[catch {string equal $stored $live} same]} { return 1 }
  return [expr {$same ? 0 : 1}]
}

# Forget every measured answer, so the next ask measures again. The lever for
# a user who knows something changed that a file stamp cannot see -- a rebuild
# inside the same second that leaves the file byte-for-byte the same size. The
# same one-second file-time hole is recorded at src/op_annot.tcl:843-847.
proc ase::sim_caps_clear {} {
  variable sim_caps
  set sim_caps [dict create]
  return {}
}

# A PLACE OF ITS OWN FOR ONE MEASUREMENT, or empty when no such place can be
# made. Every call hands back a FRESH, EMPTY directory that no other probe and
# no other process is using, and the caller gives it back with
# ase::cap_workdir_done.
#
# ⚠ THIS USED TO BE ONE FIXED NAME AND THAT WAS ISSUE 0951. What a reader
# would otherwise assume is that overwriting the results files at the top of
# each probe is enough to stop one measurement answering for another. It is
# not: the fixed name `<simulation folder>/.ase_probe/probe_a.raw` is shared by
# every process on the box, and the delete only closes the window between two
# probes inside ONE process. Measured on the built binary: a registered
# program that was literally `#!/bin/sh` + `sleep 3` + `exit 0`, and that wrote
# not one byte, was reported `known 1 usable 1 appendwrite 1` because a
# separate process dropped a healthy results file at that name one second into
# the probe. That is a false yes about a program that did nothing, and the deck
# emitter picks what it writes from exactly these answers -- so a false yes
# here becomes a blank annotation on the user's schematic later, which is issue
# 0929's symptom arriving through a new door.
#
# ABSOLUTE, because ase::run_deck does `cd` around the launch and a relative
# probe directory would then mean two different places in one run. Inside the
# simulation folder, because that is already the folder this session is allowed
# to write simulation artifacts into; a dot-name because it is nobody's
# deliverable. One private directory per measurement is the same pattern
# run_parallel_cmds already uses at tests/test_utility.tcl:82.
#
# EMPTY IS A REAL ANSWER AND ITS OWN GUARD. A simulation folder nothing can be
# written into is a fact about the FOLDER; ase::sim_capabilities turns this
# empty answer into "nothing is known" rather than into an accusation about the
# user's program, which is issue 0949's category error wearing other clothes.
proc ase::cap_workdir {} {
  variable cap_seq
  set tries 0
  set base [set_netlist_dir 0]
  # set_netlist_dir answers empty when the simulation folder could not be made
  # at all. Probing into the current directory is untidy but it is never wrong,
  # and the user has a larger problem than tidiness at that point.
  if {$base eq {}} { set base [pwd] }
  set parent [file normalize [file join $base .ase_probe]]
  if {[catch {file mkdir $parent}]} { return {} }
  if {![file isdirectory $parent]} { return {} }
  while {$tries < 64} {
    incr tries
    incr cap_seq
    set d [file join $parent p[pid]_$cap_seq]
    # NEVER REUSE A NAME SOMETHING IS ALREADY SITTING AT. A recycled process
    # number, or a predecessor that died before it could tidy up, is exactly
    # the collision the fixed name made permanent.
    if {[file exists $d]} { continue }
    if {[catch {file mkdir $d}]} { continue }
    # BELT AND BRACES, AND NO BEHAVIOURAL ROW ON THIS BOX CAN REACH THE SECOND
    # HALF. A folder this line just made is writable here, so only a filesystem
    # that answers otherwise -- a default ACL, a mount going read-only under
    # us -- gets past `file mkdir` and fails `file writable`. It is kept because
    # a place the probe cannot write into is exactly issue 0949's category
    # error waiting to happen, and it is pinned by the STRUCTURAL row I6 of
    # tests/headless/test_ase_simcaps_0948.tcl rather than by a fixture nobody
    # can build.
    if {![file isdirectory $d] || ![file writable $d]} {
      catch {file delete -force -- $d}
      continue
    }
    return $d
  }
  return {}
}

# Give back a place ase::cap_workdir handed out. Never raises, and is called on
# every path out of a measurement including the one where the probe blew up:
# the probe's workings are nobody's deliverable and must not outlive the
# measurement. Measured before this existed -- after a probe the user's own
# simulation folder was left holding probe_a.raw, probe_a.sp and probe_b.sp.
#
# ⚠ THE SHARED PARENT IS DELETED WITHOUT -force, ON PURPOSE. It disappears when
# it is empty and SURVIVES when another process's probe is still working in it,
# or when somebody else's results are sitting in it. A -force here would delete
# a file this measurement never created, which is the other half of issue 0951.
proc ase::cap_workdir_done {dir} {
  if {$dir eq {}} { return {} }
  catch {file delete -force -- $dir}
  catch {file delete -- [file dirname $dir]}
  return {}
}

# BELT AND BRACES FOR ISSUE 0951, asked immediately BEFORE a probe run: is
# nothing sitting at the name this run is about to write?
#
# The private directory above is the belt; this is the braces, and they guard
# different things. A place of its own means no other process can be writing
# where this one reads. Not trusting a results file this run did not see appear
# means a name that collides ANYWAY -- a recycled process number, a predecessor
# that died without tidying up, a caller that handed the probe a directory of
# its own choosing -- still cannot answer for the program being measured.
proc ase::cap_claim {path} {
  if {$path eq {}} { return 0 }
  return [expr {[file exists $path] ? 0 : 1}]
}

# The plots this run actually produced, or empty when it produced none.
#
# ⚠ EMPTY WHEN THE NAME WAS NOT CLAIMED, and that is the whole point: whatever
# is sitting there now was not put there by this run, so no verdict about the
# user's program may be taken from it. Reading it anyway is the false yes issue
# 0951 measured. Note this proc does NOT delete what it found -- results that
# belong to somebody else are theirs.
proc ase::cap_result {path claimed} {
  if {!$claimed} { return {} }
  return [ase::cap_raw_plots $path]
}

# How many whole seconds of the measurement's budget are left, never less than
# one (issue 0953). `t0` is the clock reading taken when the measurement
# started. One budget is shared by every run of one measurement, so a program
# that never comes back costs the user that budget once and not once per run.
proc ase::cap_left {t0} {
  variable cap_budget_ms
  set left [expr {$cap_budget_ms - ([clock milliseconds] - $t0)}]
  set secs [expr {int(($left + 999) / 1000)}]
  if {$secs < 1} { set secs 1 }
  return $secs
}

# How many whole seconds a measurement that started at `t0` has taken so far,
# never less than one -- the number the did-not-answer sentence tells the user
# they waited (issue 0953). Rounded up, because a user who waited 3.2 seconds
# did not wait 3.
#
# ⚠ THE LAST TENTH OF A SECOND DOES NOT BUY A WHOLE EXTRA ONE, and that is not
# a rounding preference, it is the only way this number can ever be the one the
# design chose. The cap above is handed to the program in WHOLE seconds, so a
# program that is cut off always comes back a few milliseconds PAST it -- 30.005
# for a thirty-second budget, measured. Rounding that up without a grace made
# the sentence say "after 31 seconds", every single time, and 30 was a number
# it could never print. A real 3.2-second wait still reads as 4.
proc ase::cap_spent {t0} {
  set spent [expr {[clock milliseconds] - $t0}]
  set secs [expr {int(($spent + 900) / 1000)}]
  if {$secs < 1} { set secs 1 }
  return $secs
}

# The wall-clock cap this box can put on a program, as a command prefix that
# takes the number of seconds next, or empty when the box has none. Worked out
# once per session.
#
# ⚠ THE KILL GRACE IS NOT A REFINEMENT (issue 0953). The plain form sends only
# the polite stop signal, so a program that ignores it is not bounded at all --
# measured on this box, a stop-ignoring program under a three-second plain cap
# ran its full thirty seconds. With the grace it ends at five.
proc ase::cap_timeout_cmd {} {
  variable cap_timeout_prefix
  if {$cap_timeout_prefix ne {ZZUNKNOWN}} { return $cap_timeout_prefix }
  set cap_timeout_prefix {}
  set to [lindex [auto_execok timeout] 0]
  if {$to ne {}} {
    if {![catch {exec $to -k 1 1 true}]} {
      set cap_timeout_prefix [list $to -k 2]
    } elseif {![catch {exec $to 1 true}]} {
      set cap_timeout_prefix [list $to]
    }
  }
  return $cap_timeout_prefix
}

# Every plot in a results file, as a list of {name npoints {varname ...}}.
# Empty for a file that is missing or unreadable -- which is itself an answer
# the callers below use: a program that wrote nothing produced nothing.
#
# ⚠ THIS READER IS THE PROBE'S OWN, AND THAT IS DELIBERATE (ruling 0881). The
# results database the waveform viewer has attached is the USER'S; a probe
# that read its scratch file through `xschem raw` would detach whatever they
# are looking at in order to answer a question about a program. So the header
# is parsed here, from bytes, and nothing in this section touches that
# database.
#
# It reads a BINARY results file as well as a text one. The probe deck asks
# for text (`set filetype=ascii`, measured to still append every analysis on
# ngspice-46+), but a build is free to ignore that, and after a `Binary:` line
# the payload is exactly points x variables x 8 bytes (16 when the plot is
# complex) -- skipped by length, so no byte of it can ever be mistaken for the
# header of a plot that is not there.
#
# ⚠ IT STEPS OVER THE NUMBERS; IT DOES NOT LOAD THEM (issue 0971). This used to
# pull the ENTIRE file into a string first. What a reader would otherwise assume
# is that reading a few header lines is cheap. It is not, once the run report
# added by issue 0965 calls this on the USER'S OWN results file: measured on the
# shipped tb_bandgap bench that file is 69,595,016 bytes, and was 144,455,860
# before issue 0964, on a box with about 7.8 GB. And issue 0964 put the
# operating point LAST, so no read of the first few kilobytes can find the plot
# the report needs -- the file pointer has to walk past the payload, which the
# `Binary:` arithmetic below already knew how to do. Nothing a suite can observe
# changes, which is exactly why row H3 of test_ase_simcaps_0948 is STRUCTURAL as
# well as behavioural.
proc ase::cap_raw_plots {path} {
  set plots {}
  set name {}
  set np -1
  set nv -1
  set cx 0
  set vars {}
  set invars 0
  set have 0
  if {$path eq {} || ![file isfile $path]} { return $plots }
  if {[catch {open $path r} f]} { return $plots }
  fconfigure $f -translation binary
  while {[gets $f rawline] >= 0} {
    set line [string trimright $rawline "\r"]
    if {[string match {Plotname:*} $line]} {
      if {$have} { lappend plots [list $name $np $vars] }
      set have 1
      set name [string trim [string range $line 9 end]]
      set np -1
      set nv -1
      set cx 0
      set vars {}
      set invars 0
      continue
    }
    if {!$have} { continue }
    if {[string match {Flags:*} $line]} {
      set invars 0
      if {[string first complex [string tolower $line]] >= 0} { set cx 1 }
      continue
    }
    if {[string match {No. Variables:*} $line]} {
      set invars 0
      set v [string trim [string range $line 14 end]]
      set nv [expr {[string is integer -strict $v] ? $v : -1}]
      continue
    }
    if {[string match {No. Points:*} $line]} {
      set invars 0
      set v [string trim [string range $line 11 end]]
      set np [expr {[string is integer -strict $v] ? $v : -1}]
      continue
    }
    if {[string match {Variables:*} $line]} { set invars 1 ; continue }
    if {[string match {Values:*} $line]} { set invars 0 ; continue }
    if {[string match {Binary:*} $line]} {
      set invars 0
      if {$np > 0 && $nv > 0} {
        catch {seek $f [expr {$np * $nv * ($cx ? 16 : 8)}] current}
      }
      continue
    }
    if {$invars} {
      set nm [lindex [split [string trim $line] "\t"] 1]
      if {$nm ne {}} { lappend vars $nm }
    }
  }
  catch {close $f}
  if {$have} { lappend plots [list $name $np $vars] }
  return $plots
}

# The named plot out of a cap_raw_plots answer, or empty.
proc ase::cap_plot {plots want} {
  foreach p $plots {
    if {[string equal -nocase [lindex $p 0] $want]} { return $p }
  }
  return {}
}

# Run ONE program with ONE set of arguments and hand back
# {exitcode output was-it-cut-off elapsed-milliseconds}.
#
# ⚠ THE EXIT CODE IS RECORDED AND USED FOR NOTHING. It is here so a failing
# probe can be described in a bug report; every verdict is taken from the
# results file. See this section's header for the measured case where exit 0,
# a clean log and a written file all say success over a destroyed result.
#
# ⚠ THIS RUNNER BELONGS TO NO ONE SIMULATOR (issue 0954). It used to append
# one program's batch-mode flag itself, so every backend ever added would
# inherit a switch that means something else, or nothing, to it. EVERYTHING
# after the program name now comes from the caller: the arguments the user
# registered, the backend's own flags, and the deck.
#
# ⚠ THE PROGRAM IS RUN WITH `workdir` UNDER IT, AND THAT IS THE FIX FOR ISSUE
# 0949, not a tidiness. A simulation folder whose name has a space in it made a
# healthy ngspice be told it is not a circuit simulator, on every Run. The
# mechanism is not a truncated path: the program reads the second whitespace
# word of the deck's results line as a VECTOR name, finds no such vector, and
# writes nothing anywhere. Six write forms were measured against five hostile
# folder names and NO quoting form inside the deck covers them all -- a dollar
# sign survives double quotes, backslashes, a .control-level cd and an
# indirection through a variable alike, because the program expands it
# regardless of quoting. The one form that produced the file for a space, a
# dollar, a bracket, a quote and a semicolon is this one: give the program the
# target folder as its own current directory and let the deck name its results
# with a bare file name.
#
# A PROGRAM NAMED BY A RELATIVE LOCATION IS RESOLVED BEFORE THE MOVE, or the
# user who registered their simulator as ./build/ngspice would stop being able
# to run it. A bare name with no folder in it is left alone: that is a PATH
# lookup, which the move cannot affect.
#
# STDIN IS REDIRECTED AWAY, AND THAT IS NOT A DETAIL. A program handed a deck
# it does not understand may drop into its own interactive prompt and sit
# there reading; without this the user's Run would hang forever on a probe.
#
# ⚠ WAS IT CUT OFF IS ANSWERED BY THREE THINGS TOGETHER, AND EACH ONE CLOSES
# A HOLE THE OTHERS LEAVE OPEN (issue 0953). The runner used to hand back the
# catch code -- Tcl's own 1, not the child's -- so a program cut off at ten
# seconds was indistinguishable from one that failed instantly, and the only
# place the truth survived was ::errorCode, which was thrown away. A cap that
# was never applied cannot manufacture a cut-off; a real simulator that chooses
# to exit 124 on its own is not called one; and the elapsed time is what tells
# those two apart with neither hole. ::errorCode is read on the very next line,
# before restoring the folder can overwrite it.
proc ase::cap_run {exe exeargs workdir secs} {
  set nul [expr {$::tcl_platform(platform) eq {windows} ? {NUL} : {/dev/null}}]
  set prog $exe
  if {[file pathtype $prog] eq {relative} && [file dirname $prog] ne {.}} {
    set prog [file normalize $prog]
  }
  set cap [ase::cap_timeout_cmd]
  set cmd {}
  if {[llength $cap]} { set cmd [concat $cap [list $secs]] }
  lappend cmd $prog
  foreach a $exeargs { lappend cmd $a }
  set save [pwd]
  if {$workdir ne {}} {
    if {[catch {cd $workdir} cderr]} { return [list 1 $cderr 0 0] }
  }
  set t0 [clock milliseconds]
  set rc [catch {exec {*}$cmd < $nul 2>@1} out]
  set ec $::errorCode
  set ms [expr {[clock milliseconds] - $t0}]
  catch {cd $save}
  set cut 0
  if {[llength $cap] && $rc && [lindex $ec 0] eq {CHILDSTATUS} \
      && [lindex $ec 2] == 124 && $ms >= ($secs * 1000) - 250} { set cut 1 }
  return [list $rc $out $cut $ms]
}

# WHAT THE PROGRAM THAT WILL ACTUALLY START CAN DO -- the front door, lazy and
# cached. Returns a dict:
#
#   {known 0}                     nothing was measured, and nothing is claimed
#   {known 0 unmeasured <reason> ...}   the same, plus why nobody found out
#   {known 1 usable 0|1 appendwrite 0|1 blanket_op_save 0|1 hier_op_names 0|1}
#
# ⚠ `known 0` CARRIES NO CAPABILITY KEYS AT ALL, and callers must read `known`
# first. Absent means "not measured"; 0 means "measured, and the answer is
# no". A reader that treated a missing key as a no would turn "we never asked"
# into a statement about the user's simulator, which is the fabricated-number
# defect wearing different clothes.
#
# THE THREE GUARDS RETURN BEFORE THE PROBE **AND BEFORE ANY CACHE WRITE**:
#
#  1. the resolver said no. Issue 0935: that answer still carries a `resolved`
#     naming a real file on the PATH -- the file a WRONG choice would have
#     started. Probing it would measure a program the resolver has already
#     refused to run, and would attribute the answer to a simulator the user
#     is not using. run_cmd already refuses and says why, so nothing is said
#     here.
#  2. nothing resolved. Issue 0935's other half: `ok` is 1 while `resolved` is
#     EMPTY, whenever nothing is registered and nothing of that name is on the
#     PATH. Two unrunnable backends both answer that way, so a cache keyed on
#     an empty string would fuse them into one answer about neither.
#  3. the backend declares no probe. Answer "not known" and never a guessed
#     yes; ase::register_backend keeps `capabilities` optional for exactly the
#     backends that reach this line.
proc ase::sim_capabilities {backend} {
  variable sim_caps
  variable backends
  set s [ase::sim_status $backend]
  if {[dict get $s ok] == 0} { return [dict create known 0] }
  set resolved [dict get $s resolved]
  if {$resolved eq {}} { return [dict create known 0] }
  if {![dict exists $backends $backend capabilities]} {
    return [dict create known 0]
  }
  set live [ase::cap_stamp $resolved]
  if {[dict exists $sim_caps $resolved]} {
    set stored [dict get $sim_caps $resolved]
    if {![ase::cap_stale [dict get $stored stamp] $live]} {
      return [dict get $stored caps]
    }
  }
  # NO PLACE TO WORK IS A FACT ABOUT THE FOLDER, NOT ABOUT THE PROGRAM (issues
  # 0949 and 0950). What a reader would otherwise assume is that a probe which
  # could not run says something about the simulator. It does not: a simulation
  # folder nothing can be written into would otherwise make a perfectly healthy
  # build be reported as producing no results at all, and -- before the rule
  # below -- that accusation was then remembered for the whole session.
  set wd [ase::cap_workdir]
  if {$wd eq {}} { return [dict create known 0 unmeasured noplace] }
  # THE PLACE IS GIVEN BACK ON EVERY PATH, INCLUDING THE ONE WHERE THE PROBE
  # BLEW UP -- and the failure is then RE-RAISED, so a defect in a probe stays
  # as loud as it was. Tidying up must not swallow it.
  set rc [catch {[ase::backend_hook $backend capabilities] $resolved \
                   [dict get $s args] $wd} caps]
  set einfo $::errorInfo
  set ecode $::errorCode
  ase::cap_workdir_done $wd
  if {$rc} { return -code error -errorinfo $einfo -errorcode $ecode $caps }
  # ⚠ AN ANSWER NOBODY WORKED OUT IS NEVER REMEMBERED (issue 0950). What a
  # reader would otherwise assume is that the cache holds facts about a
  # program. It holds facts about a program AND, before this line, failures of
  # the RUN dressed up as facts about the program: measured, a wrong answer
  # taken in a folder the simulator could not write into was then served for
  # the rest of the session, in an ordinary folder, with nothing in the
  # Simulators window able to clear it. One line covers the folder that cannot
  # be written into, the program that did not answer in time, and every reason
  # anyone adds later, because all of them say `known 0`.
  if {[dict exists $caps known] && [dict get $caps known] == 1} {
    dict set sim_caps $resolved [list stamp $live caps $caps]
  }
  return $caps
}

# --- CASE MODE, AS A PROPERTY OF THE REGISTERED SIMULATOR --------------------
#
# THE THREE PROCS BELOW REPLACE ELEVEN `sim_profile_*` PROCS from
# `fluid-editing`, and the change is a change of STORE, not of rules. Every
# ruling those procs carried is restated here against the same words, because
# the rules were measured and the storage was not:
#
#   A1  nobody may select a mode their simulator will silently ignore. So the
#       selectable set is exactly what was MEASURED, and an unmeasured program
#       offers `fold` alone -- `fold` being what a released ngspice does whether
#       or not it was asked (it accepts `-D casemode=preserve` and ignores it,
#       measured), i.e. the one request no binary can silently fail.
#   B2b an unmeasured program is UNKNOWN, never a claim. `{}` from
#       ase::sim_casemode_detected means "nobody asked", exactly as `known 0`
#       does in the capability dict it reads.
#   B1  per simulator, with a global floor: a program with no request of its own
#       takes `$::sim_case_mode`, which the user sets once for all of them.
#
# WHY THE MOVE. `fluid-editing` kept these on a `sim()` profile row and cached
# the measurement in a `detected`/`probed` pair on that same row, which nothing
# invalidated -- point the row at another binary and the old measurement was
# still sitting there, not stale, so nothing ever re-probed it. The capability
# cache these read through is keyed on the resolved path AND its mtime stamp and
# is cleared on every registry edit (ase::sim_caps_clear, issue 0950), so the
# same answer now expires for the three reasons it should.

# WHAT THE PROGRAM WAS MEASURED TO DELIVER, canonical order, garbage dropped.
# `{}` means "not measured", which is also what a `known 0` capability answer
# and a capability answer with no casemode key both mean -- see the ⚠ on
# ase::sim_capabilities: absent is never a no.
proc ase::sim_casemode_detected {backend} {
  set c [ase::sim_capabilities $backend]
  if {![dict exists $c known] || [dict get $c known] == 0} { return {} }
  if {![dict exists $c casemode_detected]} { return {} }
  set d [dict get $c casemode_detected]
  set r {}
  foreach m {fold preserve distinguish} {
    if {[lsearch -exact $d $m] >= 0} { lappend r $m }
  }
  return $r
}

# THE MODES A USER MAY SELECT (A1). Measured => exactly what was measured, the
# EMPTY answer included: `casemode_detected {}` from a completed probe means
# "measured, and it delivers nothing we recognise", and offering a mode then
# would break A1 for the one binary we actually know about. Never measured =>
# `fold` alone.
#
# ⚠ THE TWO EMPTIES ARE NOT THE SAME and the difference is the whole row. A
# completed probe that recognised nothing publishes the key with an empty value;
# a probe that never ran publishes no key at all. ase::sim_casemode_detected
# collapses both to `{}`, so this proc must ask the dict itself.
proc ase::sim_casemode_selectable {backend} {
  set c [ase::sim_capabilities $backend]
  if {[dict exists $c known] && [dict get $c known] == 1 \
      && [dict exists $c casemode_detected]} {
    return [ase::sim_casemode_detected $backend]
  }
  return fold
}

# THE MODE THIS SIMULATOR REQUESTS: its own field, else the global floor, else
# `fold` (B1). The floor is validated here too -- a `set sim_case_mode sideways`
# in an rc must not become a request.
proc ase::sim_casemode_requested {backend} {
  set s [ase::sim_status $backend]
  # ⚠ A REFUSED RESOLUTION YIELDS NO MODE OF ITS OWN. `ok 0` still carries an
  # `entry` -- the entry the user chose, whose program has since gone or was
  # never for this backend -- and reading a case mode off it would attribute a
  # request to a simulator that is not going to run. The floor answers instead,
  # which is what a backend with nothing registered gets, and is the same answer
  # this proc gave before anybody registered anything.
  if {![dict get $s ok]} {
    if {[info exists ::sim_case_mode] && [sim_casemode_valid $::sim_case_mode]} {
      return $::sim_case_mode
    }
    return fold
  }
  set e [dict get $s entry]
  if {$e ne {}} {
    variable simulators
    if {[dict exists $simulators $e]} {
      set m [ase::state_get [dict get $simulators $e] casemode {}]
      if {$m ne {} && [sim_casemode_valid $m]} { return $m }
    }
  }
  if {[info exists ::sim_case_mode] && [sim_casemode_valid $::sim_case_mode]} {
    return $::sim_case_mode
  }
  return fold
}

# Does this simulator want ngspice's `--no-spiceinit`? A field of the registry
# entry, off by default -- A2's point is to probe with the real argv and run in
# whatever mode came back, not to suppress `.spiceinit` and pretend.
proc ase::sim_nospiceinit {backend} {
  set s [ase::sim_status $backend]
  set e [dict get $s entry]
  if {$e eq {}} { return 0 }
  variable simulators
  if {![dict exists $simulators $e]} { return 0 }
  return [expr {[ase::state_get [dict get $simulators $e] nospiceinit 0] ? 1 : 0}]
}

# TELL THE USER WHEN THE PROGRAM THAT IS ABOUT TO RUN CANNOT DO WHAT THIS
# RUN NEEDS. `nwrites` is how many analyses this run has enabled.
#
# Returns the kind that was said, or empty when there was nothing to say --
# which is a real answer, not an absence: a caller can tell "kept quiet"
# apart from "never asked".
#
# THE TWO ARMS, AND WHY THE SECOND ONE IS CONDITIONAL. A build that keeps only
# the last analysis loses nothing on a run with ONE analysis in it, so saying
# so then would be a nag about a run that is going to be perfectly fine. A
# program that produced NO results at all on the probe's tiny test circuit is
# reported whatever the run looks like: never a silent failure.
#
# It never re-words, and never echoes the resolver's own `why`: the sentences
# are minted in ase::sim_why and rendered by ase::sim_say (ruling D5-4), and
# run_cmd already owns the resolver's sentence.
proc ase::cap_report {backend nwrites} {
  set c [ase::sim_capabilities $backend]
  set path [dict get [ase::sim_status $backend] resolved]
  # THE PROGRAM THAT DID NOT ANSWER IN TIME GETS ITS OWN SENTENCE (issue
  # 0953). What a reader would otherwise assume is that a probe which learned
  # nothing has nothing to say. It has: the user has just waited, and the
  # measured behaviour was to wait 20.0 s and then be told the program is not a
  # circuit simulator -- a claim the probe never established. "It had not
  # finished" and "it is not a simulator" are different statements about
  # somebody's program, and only the first one was measured. Every OTHER
  # known-0 answer is silent, exactly as before: nothing was measured and
  # nothing is claimed.
  if {![dict exists $c known] || [dict get $c known] == 0} {
    if {[dict exists $c unmeasured] && [dict get $c unmeasured] eq {timeout}} {
      ase::sim_say cap_no_answer $backend $path [dict get $c secs]
      return cap_no_answer
    }
    return {}
  }
  if {[dict exists $c usable] && [dict get $c usable] == 0} {
    ase::sim_say cap_not_a_simulator $backend $path
    return cap_not_a_simulator
  }
  if {[dict exists $c appendwrite] && [dict get $c appendwrite] == 0 \
      && $nwrites > 1} {
    ase::sim_say cap_no_append $backend $path
    return cap_no_append
  }
  return {}
}

# The file the user's own simulator list is saved in.
proc ase::sim_conf_file {} {
  if {![info exists ::USER_CONF_DIR]} { return {} }
  return [file join $::USER_CONF_DIR ase_simulators]
}

# Save the simulator list so it survives a restart. Returns 1 on success, 0
# with a report on failure; never raises.
#
# THIS IS THE WRITER A DIALOG CALLS. It takes no widget and touches no Tk, so
# the Setup dialog item S2 adds calls exactly this and nothing is duplicated
# behind the dialog.
#
# The file is a Tcl script of ase::sim_register lines, the same shape a user
# could type by hand, modelled on write_net_hilight_style_conf in xschem.tcl.
proc ase::sim_write_conf {{path {}}} {
  variable simulators
  variable sim_use
  if {$path eq {}} { set path [ase::sim_conf_file] }
  # WRITTEN BESIDE THE REAL FILE AND MOVED OVER IT, NEVER STRAIGHT INTO IT
  # (issue 0937). `open <path> w` TRUNCATES before a single line is written,
  # so a failure anywhere after that -- a full disk, a close that reports the
  # write it had buffered -- left the user with an EMPTY simulator list and,
  # because `close` raised out of a proc that promises never to raise, no
  # sentence about it either. That was survivable while nothing in the tree
  # called this writer; the Simulators dialog now calls it on every Add, Edit,
  # Remove and choice, so the odds moved. The file the user has keeps whatever
  # it had until a complete new one is ready to take its place.
  set tmp $path.new
  set mode {}
  if {[file exists $path]} { catch {set mode [file attributes $path -permissions]} }
  if {[catch {open $tmp w} fp]} {
    ase::sim_say nowrite {} $path $fp error
    return 0
  }
  if {[catch {ase::sim_write_body $fp} err]} {
    catch {close $fp}
    catch {file delete -force $tmp}
    ase::sim_say nowrite {} $path $err error
    return 0
  }
  if {[catch {file rename -force $tmp $path} err]} {
    catch {file delete -force $tmp}
    ase::sim_say nowrite {} $path $err error
    return 0
  }
  # A move replaces the file, and with it whatever permissions the user had
  # put on their own copy; the old truncate-in-place kept them.
  if {$mode ne {}} { catch {file attributes $path -permissions $mode} }
  return 1
}

# The body of the saved list. Split out only so the writer above can wrap the
# whole of it in ONE catch: every `puts` and the `close` are failures the user
# has to be told about, and the file being written is a temporary one, so a
# failure here costs nothing that was already saved.
proc ase::sim_write_body {fp} {
  variable simulators
  variable sim_use
  puts $fp "# xschem ASE-L simulator list -- written by xschem, issue 0931."
  puts $fp "# Read once at startup. Edit by hand if you like: it is a plain"
  puts $fp "# Tcl script of ase::sim_register lines."
  # ENTRIES A STARTUP CONFIGURATION FILE DECLARES ARE DELIBERATELY NOT
  # WRITTEN. The rc re-declares them at every start, so a copy here would
  # only be a stale second declaration -- and it would shadow a later edit to
  # the rc, which is the one place the user would think to make the change.
  dict for {n e} $simulators {
    if {[dict get $e origin] eq {rc}} { continue }
    # ⚠ EVERY FIELD THE RECORD CARRIES, OR THE RESTART IS A SILENT EDIT. The
    # case mode and the `-n` flag joined this record at the annotate merge; a
    # writer that knows about `-args` and `-backend` alone would hand a user
    # who set `distinguish` a `fold` run at their next start, with nothing said
    # and nothing to see. Written unconditionally rather than only when
    # non-default, so the file states the whole record and reading it back
    # cannot depend on what this writer's defaults happened to be.
    puts $fp [list ase::sim_register $n [dict get $e path] \
                   -args [dict get $e args] -backend [dict get $e backend] \
                   -casemode [ase::state_get $e casemode {}] \
                   -nospiceinit [ase::state_get $e nospiceinit 0]]
  }
  # "NONE OF MINE -- USE THE PROGRAM ON MY PATH" IS A CHOICE, AND IT IS
  # WRITTEN DOWN LIKE ANY OTHER (issue 0932, on the Simulators dialog's path
  # rather than beside it). What a reader would assume is that an empty
  # choice is the absence of a line: it is not. Registering the first
  # simulator puts it in force, so a file with register lines and no
  # selection line reads back with the FIRST entry in force -- and the user
  # who deliberately handed control back to their PATH gets one of their own
  # builds silently put back in charge at the next start. Measured before
  # this arm existed: cleared the choice, saved, restarted, `in force = a`.
  #
  # The consequence, recorded and unratified: a cleared choice now overrides
  # a startup configuration file's own ::ASE_SIMULATOR at the next start,
  # because the user file is read after the rc seed and their later gesture
  # wins over the rc's default.
  #
  # Same reason the selection line is skipped when what is in force came from
  # an rc: this file must not mention rc entries at all, or reading it back
  # in a session where the rc no longer declares that name would fail.
  if {$sim_use eq {}} {
    puts $fp [list ase::sim_select {}]
  } elseif {[dict exists $simulators $sim_use] \
      && [dict get $simulators $sim_use origin] ne {rc}} {
    puts $fp [list ase::sim_select $sim_use]
  }
  close $fp
  return 1
}


# Read the saved simulator list back. Returns 1 when a file was read, 0 when
# there was none or it could not be read. NEVER RAISES: it runs at startup,
# and a damaged file must not stop xschem from starting.
proc ase::sim_load_conf {{path {}}} {
  variable sim_origin
  if {$path eq {}} { set path [ase::sim_conf_file] }
  if {$path eq {}} { return 0 }
  # A missing file is the ordinary first-run case, not a failure, and saying
  # anything about it would be noise in every fresh install.
  if {![file isfile $path]} { return 0 }
  set sim_origin conf
  set rc [catch {uplevel #0 [list source $path]} err]
  set sim_origin session
  if {$rc} {
    ase::sim_say badconf {} $path $err error
    return 0
  }
  return 1
}

# --- the rc seed ------------------------------------------------------------
# Turn what a startup configuration file declared into entries, at the moment
# this file is sourced -- which is the only moment at which both the rc's
# values and these procs exist.
#
# EVERY STEP IS CAUGHT, AND THAT IS NOT DEFENSIVE PADDING. An error raised
# here is raised while xschem.tcl is sourcing this file: it would abort the
# source and take the entire ASE-L namespace out at startup, over a typo in
# somebody's PDK rc. A mistake in the rc must cost the user a sentence, not
# the feature.
#
# THE LOOP HEADER IS INSIDE THE CATCH TOO, AND THAT IS THE PART A READER
# SKIPS. `foreach x $v` parses $v AS A LIST before it runs the body even
# once, so an unbalanced brace in the rc's value raises in the HEADER --
# outside any catch the body owns. Measured before this was fixed: an
# unmatched brace in ::ASE_SIMULATORS aborted the source of this file and
# xschem exited with no schematic editor at all ("STARTUP ABORTED ... Failing
# file: ase.tcl"), while the identical typo in ::ASE_DEFAULT_MODELS and
# ::ASE_DEFAULT_INCLUDES -- the two rc variables this seed was modelled on --
# started normally. Row E12 of tests/headless/test_ase_simreg_0931.tcl
# measures the two side by side, so the parity is a check and not a comment.
if {[info exists ::ASE_SIMULATORS] && $::ASE_SIMULATORS ne {}} {
  set ::ase::sim_origin rc
  if {[catch {
    foreach ase_seed_e $::ASE_SIMULATORS {
      if {[catch {
        set ase_seed_a {}
        set ase_seed_b {}
        catch {set ase_seed_a [dict get $ase_seed_e args]}
        catch {set ase_seed_b [dict get $ase_seed_e backend]}
        ase::sim_register [dict get $ase_seed_e name] [dict get $ase_seed_e path] \
                          -args $ase_seed_a -backend $ase_seed_b
      } ase_seed_err]} {
        catch {ase::sim_say badrcentry {} {} $ase_seed_err error}
      }
    }
  } ase_seed_lerr]} {
    catch {ase::sim_say badrclist {} {} $ase_seed_lerr error}
  }
  set ::ase::sim_origin session
  catch {unset ase_seed_e} ; catch {unset ase_seed_a}
  catch {unset ase_seed_b} ; catch {unset ase_seed_err}
  catch {unset ase_seed_lerr}
}
if {[info exists ::ASE_SIMULATOR] && $::ASE_SIMULATOR ne {}} {
  if {[catch {ase::sim_select $::ASE_SIMULATOR} ase_seed_serr]} {
    catch {ase::echo $ase_seed_serr error}
  }
  catch {unset ase_seed_serr}
}

# How many analyses this run has enabled.
#
# ONE OWNER, BECAUSE TWO PLACES NOW NEED THE SAME COUNT (issue 0948). The
# ngspice render_deck has always counted them to decide whether the deck needs
# the add-each-analysis line at all; ase::cap_report needs the same count to
# decide whether a build that keeps only the LAST analysis is about to lose
# anything. Counted twice, the two could disagree and the warning would be
# about a run that is not the one being launched.
#
# An enabled analysis whose type this backend does not recognise IS counted --
# unchanged from the loop this was lifted out of, so the rendered deck is
# byte-identical to before.
proc ase::n_enabled_analyses {state} {
  set n 0
  foreach a [ase::state_get $state analyses] {
    if {[ase::state_get $a enabled 0] eq {1}} { incr n }
  }
  return $n
}

# --- THE SIMULATOR-PROFILE LAYER WAS HERE AND IS GONE ------------------------
#
# `fluid-editing`'s casemode batch item 6 put the requested case mode -- and the
# exe, the args and the `-n` flag -- on a simulator PROFILE, a row of the stock
# `sim()` array configured through Simulation > Configure simulators and tools,
# and ASE-L's part was only to NAME the row a session ran with: the `sim_profile`
# state key, and the six procs that resolved it (ase::backend_tool,
# ase::sim_profile_resolve / _casemode / _stamp / _clear, and the
# `backend_tools` map).
#
# ALL OF IT IS RETIRED AT THE `annotate` MERGE, and the reason is not tidiness.
# `annotate` shipped a simulator REGISTRY -- ase::sim_register and friends, with
# CRUD, validation, a capability probe and a saved list that survives a restart.
# Keeping both would have left the user's simulator described by two stores that
# nothing kept in agreement: the registry saying which program runs, a `sim()`
# row saying how it treats case, and no gesture invalidating one when the other
# changed. The case mode is now a FIELD of the registry entry
# (ase::sim_casemode_requested), the measurement is a key of that entry's
# capability answer (ase::sim_casemode_detected), and there is one record.
#
# WHAT WAS LOST, SAID PLAINLY: a `sim()` row could carry a per-row case mode for
# a tool ASE-L does not run, and a session could pin itself to one row of several
# configured for the same tool. Neither has a user today -- ASE-L runs one
# in-force simulator -- and both are recoverable by registering the second
# program as its own entry, which is a better shape anyway because the entry
# carries its own measured capabilities.
#
# WHAT WAS GAINED: `stale` and `invalid` are gone as resolve statuses, because
# they were properties of addressing a row by INDEX. See the note where
# ase::run_status_note used to live.

# --- THE RUN PROBE (casemode batch item 7) -----------------------------------
#
# "What case mode will THIS run get?", asked with the run's own argv from the
# DECK'S OWN DIRECTORY, immediately before the simulation. It is the probe a
# `.spiceinit` can override, and the reason DECISIONS.md A2 chose "no `-n`, probe
# and report" over passing `-n`: MEASURED on this tree 2026-08-17, with today's
# build-ver_50,
#
#   .spiceinit beside the deck, `set casemode=fold`, -D casemode=preserve -> fold
#   the same, plus -n                                                     -> preserve
#   NO .spiceinit anywhere,          -D casemode=preserve                 -> preserve
#   HOME/.spiceinit says fold,       -D casemode=preserve                 -> fold
#
# The last row is why there is no shortcut: it is not enough to look beside the
# deck, and `~/.spiceinit` cannot be excluded from any cwd. The simulator has to
# be ASKED.
#
# THIS RECORDS NOTHING on the profile, deliberately. `detected` is a claim about
# the binary that item 13's dropdown is built from (A1); an answer skewed by one
# directory's `.spiceinit` is a fact about one run. The capability probe
# (`sim_profile_probe_capability`, xschem.tcl) is the one that records.
#
# The B4 POLICY -- `preserve` mismatch reports and continues, `distinguish`
# mismatch REFUSES -- is item 8's, and is not here: this returns the measurement
# (`requested`, `mode`, `delivers`, `agree`) and nobody's verdict. `mode` is the
# raw parse (empty when the binary has no `$curcasemode` at all); `delivers` is
# the mode the run will actually get, which for that binary is `fold`; `agree`
# compares `delivers` against `requested`, and is {} only when NOTHING was
# measured.
#
# Options:
#   -deck <path>   the deck about to run; its DIRECTORY becomes the cwd
#   -cwd <dir>     the cwd outright (wins over -deck)
#   -exe <path>    override the resolved profile's executable. Item 8 owns what
#                  ASE-L falls back to when a profile names no exe (today a bare
#                  `ngspice` off PATH, hardcoded in run_cmd), so this proc does
#                  NOT reimplement that fallback -- it reports status `noexe` and
#                  lets its caller pass the executable it is really going to run.
#   -args <list>   override the profile's extra args
#   -timeout <ms>  the hard timeout (default: the global `sim_probe_timeout`)
proc ase::sim_probe_run {state args} {
  set deck {} ; set cwd {} ; set exe {} ; set arglist {} ; set tmo {}
  set haveargs 0
  foreach {o v} $args {
    switch -exact -- $o {
      -deck    { set deck $v }
      -cwd     { set cwd $v }
      -exe     { set exe $v }
      -args    { set arglist $v ; set haveargs 1 }
      -timeout { set tmo $v }
      default  { return -code error "ase::sim_probe_run: unknown option '$o'" }
    }
  }
  set p [ase::run_profile $state]
  set requested [dict get $p requested]
  if {$cwd eq {}} {
    if {$deck ne {}} {
      set cwd [file dirname [file normalize $deck]]
    } else {
      catch {set cwd [ase::rundir $state]}
    }
  }
  set nsi [dict get $p nospiceinit]
  # ⚠ THE RUN FILTER'S OUTPUT, NOT THE RAW FIELD. The run about to happen is
  # composed from the filtered args (ase::run_cmd), so a probe asking with the
  # unfiltered ones would measure a command nobody is going to run -- and a `-o`
  # in the entry's args would send the probe's own answer into a file, which is
  # the measured way to turn a three-mode binary into `mode {}`.
  if {!$haveargs} { set arglist [dict get $p args] }
  if {$exe eq {}} { set exe [dict get $p exe] }
  set out [dict create entry [dict get $p entry] profile_status [dict get $p status] \
               requested $requested cwd $cwd]
  if {$exe eq {}} {
    # `delivers` is present and empty here too: every return from this proc
    # carries the same keys, so item 8 can read one field without first asking
    # which branch produced the dict.
    return [dict merge $out [dict create status noexe mode {} answered 0 \
                                 delivers {} agree {} \
                                 nocasemode 0 ms 0 argv {} out {} \
                                 err {the registry names no runnable simulator}]]
  }
  set pr [::sim_probe_once $exe [::sim_probe_argv $arglist $requested $nsi] $cwd $tmo]
  # `delivers` is WHAT THIS RUN WILL GET, and `agree` is the comparison against
  # what was requested -- not a verdict. Both are {} when nothing was measured
  # (B2b -- no answer is unknown, never `fold`).
  #
  # `nocasemode` IS A MEASURED DELIVERY OF `fold`, and getting that wrong made
  # the two halves of this item disagree about the same reply: the capability
  # probe records `Error: curcasemode: no such variable.` + an empty `CCM=` as
  # `detected {fold}` (spec 11.4), while this proc used to answer `agree {}`,
  # i.e. "nothing was measured", for the single commonest real mismatch there is
  # -- a released ngspice under a `distinguish` request, which is precisely the
  # case B4 tells item 8 to REFUSE. The binary did answer: it named `curcasemode`
  # as a variable it does not have, which is a statement that it folds.
  set delivers {}
  if {[dict get $pr status] eq {ok}} {
    if {[dict get $pr answered] && [dict get $pr mode] ne {}} {
      set delivers [dict get $pr mode]
    } elseif {[dict get $pr nocasemode]} {
      set delivers fold
    }
  }
  set agree {}
  if {$delivers ne {}} { set agree [expr {$delivers eq $requested ? 1 : 0}] }
  return [dict merge $out $pr [dict create delivers $delivers agree $agree]]
}

# --- THE PROFILE-AWARE RUN (casemode batch item 8) ---------------------------
#
# Spec: doc/claude/specs/simulator_profiles.md section 12. Authority:
# DECISIONS.md B1 (the profile the command is built from), A2 (no `-n` by
# default), B4 (requested != measured: `preserve` reports, `distinguish`
# REFUSES).
#
# Until this item `run_cmd` was one hardcoded line -- `ngspice -b <deck> 2>@1`,
# a bare `ngspice` off PATH -- so ASE-L could not be pointed at a specific
# simulator at all. Casemode is one consequence of that, not the whole of it.
#
# THE BACKWARD-COMPATIBILITY CONTRACT, and it is a check (CS175), not a hope:
# with no profile configured the composed command is BYTE-IDENTICAL to
# `[list ngspice -b $deckpath 2>@1]`. Everything below is inert until a row
# carries an `exe`, `args`, `nospiceinit`, or a `casemode` other than `fold`.

# RULING -- the run filter drops exec-syntax redirection and pipeline words, and
# ONE class of simulator option: the ones that redirect the STDOUT ASE-L reads
# the run back out of (`-o` / `--output`). It KEEPS every other option, `-r` /
# `--rawfile` / `--soa-log` included, because those write a file BESIDE the run
# without taking the pipe away.
#
# This is NOT `sim_probe_safe_args` (xschem.tcl) and MUST NOT become it. That
# filter is a PROBE filter and its reasons are about a probe: a probe may have
# no side effects, so `-r` had to go because it made the probe overwrite the
# previous run's raw, and `> zap.txt` had to go because it wrote a file into the
# probe's cwd -- the user's own rundir. A REAL RUN's output files are the point,
# and `-r` is exactly what xschem's own shipped batch row carries
# (`sim(spice,2,cmd)` is `ngspice -b -r "$n.raw" "$N"` -- xschem.tcl:4086; note
# it carries NO `-o`, and no shipped row anywhere does). Inheriting the probe's
# whole filter here would break configured simulators for a reason nobody could
# find, so `-r` stays; `-o` is a separate, MEASURED case, below.
#
# What is dropped, and why each shape is a defect rather than a preference:
#
# (A) TCL EXEC SYNTAX -- `execute` does `open "|$args"`, so these words are not
#     arguments at all:
#   1. `>` / `>>` / `2>` / `>&` ... : ASE-L reads the run's output back through
#      `execute(data,$id)` and writes it to the log; a redirection silently
#      empties that, so the log is written EMPTY and `result_probe` finds no
#      values -- a run that looks fine and reports nothing.
#   2. A BARE redirection operator additionally EATS THE NEXT WORD as its
#      filename. `run_cmd` appends `$deckpath` last, so a trailing `>` would
#      consume the deck and ngspice would run with no deck at all.
#   3. `|` / `|&` splice a foreign program into a pipeline we then report to the
#      user as "the simulator"; everything after one was written for another
#      program, so it goes too. `&` would be handed to ngspice as a literal
#      argument (it only backgrounds a Tcl pipeline as the LAST word, and
#      `run_cmd` always appends the deck and `2>@1` after these), so it goes as
#      the meaningless word it is.
#
# (B) `-o <file>` / `--output=<file>` / `-o<file>` -- the ONE simulator option
#     that is incompatible with ASE-L existing. MEASURED, 2026-08-17, real
#     /usr/local/bin/ngspice on a `v1 a 0 1 / r1 a 0 1k` deck:
#       ngspice -b d.cir            -> `v(a) = 1.000000e+00` on STDOUT
#       ngspice -b -o o.log d.cir   -> STDOUT says only "Comments and warnings
#                                      go to log-file: o.log"; the numbers are
#                                      in o.log
#     Driven through `ase::run_deck` + `ase::wait` the second shape exits 0,
#     writes a banner-only `<cell>_ase.log`, and `ase::last_result` comes back
#     EMPTY -- the exact "runs fine and reports nothing" failure (A) exists to
#     prevent, reached by a different route. `-r`/`--rawfile` were driven the
#     same way and are unaffected (`result=<va 1.000000e+00>`), which is why
#     this is a one-option carve-out and not a return to the probe's filter.
#
# A dropped word is REPORTED, never silent (ase::run_precheck): the user typed
# it into a profile field and it is not reaching the simulator.
#
# `2>@1` stays run_cmd's own, appended after this filter, so a profile cannot
# unfold stderr out of the captured log either.
#
# DECLARED: the option list is ngspice's, enumerated, not derived -- and `-o` is
# assumed to be the only ngspice option whose short form starts with `o` (it is,
# in ngspice 46: -b -s -i -n -t -r -o -p -q -a -D -h -v).
proc ase::run_filter_args {arglist} {
  set keep {}
  set drop {}
  set skip 0
  set n [llength $arglist]
  for {set i 0} {$i < $n} {incr i} {
    set w [lindex $arglist $i]
    if {$skip} { set skip 0 ; lappend drop $w ; continue }
    if {$w eq {|} || $w eq {|&}} {
      foreach r [lrange $arglist $i end] { lappend drop $r }
      break
    }
    if {$w eq {&}} { lappend drop $w ; continue }
    if {[regexp {^(<|<<|<@|>|>>|>&|>>&|>@|>&@|2>|2>>|2>@)$} $w]} {
      lappend drop $w ; set skip 1 ; continue
    }
    if {[string index $w 0] eq {<} || [string index $w 0] eq {>}} { lappend drop $w ; continue }
    if {[string range $w 0 1] eq {2>}} { lappend drop $w ; continue }
    if {$w eq {-o} || $w eq {--output}} { lappend drop $w ; set skip 1 ; continue }
    if {[regexp {^--output=} $w]} { lappend drop $w ; continue }
    if {[regexp {^-o.} $w]} { lappend drop $w ; continue }
    lappend keep $w
  }
  return [dict create keep $keep drop $drop]
}

proc ase::run_safe_args {arglist} {
  return [dict get [ase::run_filter_args $arglist] keep]
}

# What the run is composed from, as ONE dict, so `run_cmd` and the B4 gate
# cannot disagree about which binary is about to run:
#   backend             the state's simulator name
#   entry               the in-force registry entry, {} = nothing registered and
#                       the program on PATH is what runs
#   source              `registry` or `path`, from ase::sim_status
#   why                 the resolver's own sentence, {} when it has nothing to say
#   status              ok | invalid
#   exe                 what will actually start, {} when the resolver refused
#   exe_named           1 when a registry entry names it
#   args                the entry's args, run-filtered
#   dropped             the words the run filter REMOVED from those args ({} is
#                       the normal case); ase::run_precheck reports them, so a
#                       field the user typed never disappears silently
#   nospiceinit         A2's `-n`, 0/1
#   requested           the requested mode (entry -> global floor -> fold)
#
# ⚠ IT READS THE REGISTRY, NOT A `sim()` PROFILE ROW, AS OF THE `annotate`
# MERGE. `fluid-editing` resolved a (tool, index) pair here and carried both
# keys in this dict; they are gone, along with the `stale`/`invalid` row
# statuses that only an index-addressed store can have. A registry entry is
# addressed by NAME, so nothing re-points a saved session by being inserted
# above it -- which retires ase::run_status_note's whole subject rather than
# reimplementing it.
proc ase::run_profile {state} {
  set backend [ase::state_get $state simulator ngspice]
  set st [ase::sim_status $backend]
  set ok [dict get $st ok]
  set fa [ase::run_filter_args [dict get $st args]]
  return [dict create backend $backend entry [dict get $st entry] \
              source [dict get $st source] why [dict get $st why] \
              status [expr {$ok ? {ok} : {invalid}}] \
              exe [expr {$ok ? [dict get $st exe] : {}}] \
              exe_named [expr {[dict get $st entry] ne {} ? 1 : 0}] \
              args [dict get $fa keep] dropped [dict get $fa drop] \
              nospiceinit [ase::sim_nospiceinit $backend] \
              requested [ase::sim_casemode_requested $backend]]
}

# RULING -- `-D casemode=` is emitted only for a request that is NOT `fold`.
#
# `fold` is what every user gets by default (A1, and `set_ne sim_case_mode
# fold`), and appending `-D casemode=fold` to every ASE-L run forever would buy
# exactly nothing:
#   * a released ngspice ACCEPTS AND IGNORES the flag (measured, A1), so the
#     command changes and the run does not;
#   * a case-capable ngspice defaults to `fold` anyway (measured here: the
#     capability probe's "ask for nothing" leg answers `CCM=fold`);
#   * a `.spiceinit` overrides `-D casemode=` regardless (measured, A2, both
#     beside the deck and in $HOME), so the flag cannot even enforce it.
# What it WOULD buy is a changed command line for every existing user, which is
# the one thing this item's compatibility contract forbids.
#
# The floor counts as a request: `sim_case_mode` is documented as "the mode we
# ask a simulator for when no simulator profile names one" (xschem.tcl), so a
# user who sets it to `preserve` in an rc gets `-D casemode=preserve` with no
# profile row at all -- B1's "per profile, with a global floor".
proc ase::run_casemode_flag {state} {
  set m [dict get [ase::run_profile $state] requested]
  if {$m eq {} || $m eq {fold}} { return {} }
  return [list -D casemode=$m]
}

# B4's POLICY, as a PURE FUNCTION of a request and item 7's measurement, so the
# ruling can be driven without launching anything. Returns a dict:
#   action    ok | report | refuse
#   delivers  the measured mode ({} when nothing was measured)
#   reason    why, in the user's words
#
# B4, in full, and WHY it is split (this overturned a flat "run and report"):
#   * requested `preserve`, got `fold` -> RUN AND REPORT. Cosmetic: same
#     circuit, same numbers, lower-case labels. Blocking work over that would
#     be silly.
#   * requested `distinguish`, got anything else -> REFUSE. A `distinguish`
#     downgrade means the simulator MERGES nets the user deliberately kept
#     separate -- the same deck file, a DIFFERENT CIRCUIT. The run exits
#     cleanly and the numbers are wrong, which is the silent-wrong-answer class
#     A1 was chosen to avoid; and on a stock binary the merge is completely
#     silent, because the fold-collision warning does not exist there. So
#     `distinguish` may only ever run on a binary CONFIRMED to support it,
#     immediately before the run.
#
# RULING -- "not confirmed" is a REFUSAL under `distinguish`, not a warning.
# A timeout, an unlocatable executable, a probe that errored: none of them
# confirm anything, and B4's clause is "confirmed to support it", not "not
# known to fail". This is the clause that catches B4's own third route -- the
# binary changing under the path -- because a moved ver_50 probes as `noexe`.
#
# RULING -- a mismatch that is NOT a `distinguish` REQUEST reports, never
# refuses. B4 scopes the refusal to the request, and that is where the harm is:
# only a `distinguish` request states "these nets are different", so only its
# downgrade merges anything. The reverse (asked `fold`, got `distinguish` from
# a `.spiceinit`) cannot merge nets -- it can only split them, which shows up
# as an absent vector rather than as a wrong number, and item 10's pre-flight
# owns that. It is reported so it is never silent. Note the gate is not even
# ARMED for a `fold` request (see ase::run_precheck), so in practice this arm
# is reached for an explicit `preserve` request.
proc ase::run_casemode_verdict {requested probe} {
  set delivers {}
  catch {set delivers [dict get $probe delivers]}
  set status {} ; catch {set status [dict get $probe status]}
  if {$requested eq {} || $requested eq {fold} || $delivers eq $requested} {
    return [dict create action ok delivers $delivers reason {}]
  }
  if {$delivers ne {}} {
    set reason "the simulator was measured to deliver '$delivers'"
  } elseif {$status eq {noexe}} {
    set reason {no executable could be located for this profile, so nothing could be measured}
  } elseif {$status eq {timeout}} {
    set ms 0 ; catch {set ms [dict get $probe ms]}
    set reason "the simulator did not answer within ${ms} ms, so nothing could be measured"
  } else {
    set e {} ; catch {set e [dict get $probe err]}
    set reason "its case mode could not be measured[expr {$e eq {} ? {} : " ($e)"}]"
  }
  if {$requested eq {distinguish}} {
    return [dict create action refuse delivers $delivers reason $reason]
  }
  return [dict create action report delivers $delivers reason $reason]
}

# Does this backend's `run_cmd` compose from the simulator registry? Identity,
# not a name: the policy below describes exactly what
# ::ase::backend::ngspice::run_cmd builds (`-D casemode=`, `-n`, the registry
# entry's exe/args), so it may only be applied where that proc is the composer.
# A test backend with its own run_cmd (test_ase_core E2) hardcodes its own
# binary and reads no registry, so a refusal about an entry it never runs would
# be a lie. A sixth registered hook was rejected: `register_backend` requires
# all five it knows, so adding one would break every already-registered backend.
#
# (Named `..._profile` on `fluid-editing`, for the store that is now gone.)
proc ase::run_composes_registry {sim} {
  if {[catch {ase::backend_hook $sim run_cmd} h]} { return 0 }
  return [expr {$h eq {::ase::backend::ngspice::run_cmd}}]
}

# The pre-run gate. Called from ase::run_deck BEFORE ANY ARTEFACT IS TOUCHED --
# before the netlist is read, before the cosim VCDs are deleted, before the
# .so rebuild, before the deck is written -- so a refusal leaves NOTHING
# half-written that a later read could mistake for a result (item 10 is about
# exactly that class of defect and this must not manufacture a new instance of
# it). It returns the text to prepend to the run log ({} = nothing to say), or
# raises with a `ase: ...` message for a refusal.
#
# WHAT "REFUSE" MEANS, CONCRETELY, and it is stated here because the three
# possible meanings behave very differently: it is a refusal BEFORE ANYTHING IS
# GENERATED, not a refusal after the deck is written and not a started-then-
# killed run. `ase::run_deck` raises before its first `open`, so: no deck, no
# raw, no log, no VCD deleted, no `.so` rebuilt, no process started, no
# `last_run` update, and no completion callback. The one thing that HAS
# happened when `ase::run` is the entry point is the circuit netlist artifact
# (`<rundir>/<cell>.spice`), regenerated by `ase::netlist` before run_deck is
# reached -- that is a source artifact, never a result, and it is what the
# state already said the design is. The user sees the refusal on the CIW pane
# (red) and in the action log, and the message says in so many words that any
# raw/log already in the rundir belongs to an EARLIER run.
#
# ARMING -- the probe runs only when the requested mode is not `fold`. A1 is
# explicit that the mismatch warning "never fires for a stock user -- only for
# someone who deliberately requested a mode and did not get it", and a probe on
# every run would cost every ASE-L user up to `sim_probe_timeout` ms to compare
# `fold` against `fold`. The consequence is declared in spec section 12: a
# `.spiceinit` that turns a `fold` request into `preserve` is not detected.
#
# THE EXE CHECK IS NOT GATED ON THE MODE and runs on every profile-composed run:
# a row that NAMES an `exe` we cannot locate must never fall back to the bare
# `ngspice` off PATH. That fallback would run a DIFFERENT SIMULATOR than the one
# configured, silently -- and with ver_50 having moved three times in four days,
# "the configured exe is gone" is the normal case here, not an edge case.
#
# NEITHER IS THE RESOLVE-STATUS REPORT, NOR THE DROPPED-ARGS REPORT. Both are
# about a command that is not the command the user configured, which is a harm
# independent of the mode, so both run for a `fold` request too.

# `ase::run_status_note` WAS HERE AND IS GONE, at the `annotate` merge.
#
# Its whole subject was the `stale` and `invalid` resolve statuses, and those
# can only exist in a store addressed by INDEX: `fluid-editing` numbered the
# simulator rows, so inserting or renaming one silently re-pointed every saved
# session that had stored an index, and this proc existed to say so out loud
# (item 6 delegated the decision here; spec section 12.9's ruling was REPORT,
# never refuse, because refusing would make a saved session unrunnable because
# somebody renamed a row).
#
# The ASE-L registry addresses an entry by NAME. There is no index to shift, so
# there is no substitution to report, and the sentence has nothing left to be
# about. What survives of the concern is stronger, not weaker: ase::sim_status
# RE-VALIDATES the program at every run rather than trusting what registration
# recorded, and mints its own `why` for the cases that remain (the entry is
# gone, the file lost its executable bit, the mount went away). That sentence
# reaches the CIW from ase::run_cmd and the run log through ase::run_precheck's
# notes -- the same two channels, minted once.


# The advice clause of a mismatch message. RULING -- it must not tell a user to
# fix "the profile" when the session HAS no profile row. On the global-floor
# path (`status default`, which is every user who has configured nothing but an
# `rc` line) there is no row to re-point and no `-n` checkbox to turn on: the
# user's actual lever is `sim_case_mode`. Naming the wrong lever is how a
# diagnostic wastes more time than the defect.
proc ase::run_mode_advice {p kind} {
  # ⚠ `floor` NOW MEANS "NOTHING REGISTERED", not `status default`. The status
  # vocabulary lost `default` with the profile rows; what the ruling is actually
  # about is whether the user has a per-simulator lever to reach for at all, and
  # that is whether a registry entry is in force.
  set floor [expr {[dict get $p entry] eq {} ? 1 : 0}]
  if {$kind eq {refuse}} {
    if {$floor} {
      return "No simulator is registered — the request came from the global\
 floor 'sim_case_mode'. Set sim_case_mode to a mode this binary delivers, or\
 register a simulator that supports distinguish (ASE-L, Setup > Simulators…)\
 and give it that case mode."
    }
    return "Point the registered simulator at a program that supports distinguish,\
 or turn on the registered simulator's -n if a .spiceinit is overriding the\
 request, or request a mode the binary delivers."
  }
  if {$floor} {
    return "A .spiceinit — beside the deck or in \$HOME — overrides -D casemode=.\
 No simulator is registered, so the mode came from the global floor\
 'sim_case_mode'; there is no simulator -n to turn on."
  }
  return "A .spiceinit — beside the deck or in \$HOME — overrides -D casemode=;\
 turn on the registered simulator's -n if that is the cause."
}

proc ase::run_precheck {state} {
  set p [ase::run_profile $state]
  # THE RESOLVER'S REFUSAL IS THE REFUSAL, re-raised HERE so nothing is
  # generated. ase::run_cmd refuses too, but it is called AFTER the deck has
  # been rendered and the run directory prepared; this gate runs before any
  # artefact is read, deleted, rebuilt or written, which is the property item 8
  # asked for and the reason there is a precheck at all. The sentence is
  # ase::sim_why's, rendered and never re-worded (ruling D5-4).
  if {[dict get $p status] ne {ok}} {
    set msg "ase: REFUSED — [dict get $p why] Nothing was generated: no deck, no\
 raw, no log. Any files already in [ase::rundir $state] are from an earlier run."
    ::ase::echo $msg error
    return -code error $msg
  }
  # Everything that is not a refusal accumulates here, one line each, and every
  # line reaches BOTH channels: the CIW pane now and the head of the run log
  # when the run finishes (run_deck -> run_done's `notes`).
  set notes {}
  # ⚠ APPENDED, NOT ECHOED. The resolver's `why` for a runnable-but-noteworthy
  # answer (more than one simulator waiting and no choice made) already reaches
  # the CIW from ase::run_cmd. Echoing it here as well would put one event's
  # sentence on the screen twice, which is exactly what R604's "reported ONCE"
  # forbids -- so this arm carries it to the LOG only, the channel run_cmd
  # cannot reach.
  if {[dict get $p why] ne {}} { lappend notes "ase: [dict get $p why]" }
  if {[llength [dict get $p dropped]]} {
    set dn "ase: profile args — dropped [join [dict get $p dropped] { }] from the\
 simulator command. ASE-L reads the run's output back out of the pipe to write\
 the run log and to parse the results, so a word that redirects or pipes that\
 output (>, |, -o/--output) would give a clean exit, an empty log and no\
 results. -r/--rawfile/--soa-log are NOT affected and are passed through. Remove\
 the word from the profile's args."
    ::ase::echo $dn note
    lappend notes $dn
  }
  set requested [dict get $p requested]
  if {$requested eq {} || $requested eq {fold}} { return [join $notes "\n"] }
  # The executable the run is really going to use -- item 7's run probe does not
  # reimplement run_cmd's bare-`ngspice` fallback and documents that its caller
  # passes what it is really going to run.
  set exe [dict get $p exe]
  if {$exe eq {}} { set exe [lindex [auto_execok ngspice] 0] }
  set probe [ase::sim_probe_run $state -cwd [ase::rundir $state] -exe $exe]
  set v [ase::run_casemode_verdict $requested $probe]
  set act [dict get $v action]
  if {$act eq {ok}} { return [join $notes "\n"] }
  set who [expr {$exe eq {} ? {the simulator} : $exe}]
  if {$act eq {refuse}} {
    set msg "ase: REFUSED — this session requests casemode 'distinguish' but\
 [dict get $v reason] ($who). Under 'distinguish' a simulator that folds MERGES\
 nets you deliberately kept apart: the same deck file, a different circuit, a\
 clean exit and wrong numbers — and on a stock binary the merge is completely\
 silent. Nothing was generated: no deck, no raw, no log. Any files already in\
 [ase::rundir $state] are from an earlier run. [ase::run_mode_advice $p refuse]"
    ::ase::echo $msg error
    return -code error $msg
  }
  set msg "ase: casemode — this session requested '$requested' but\
 [dict get $v reason] ($who). The run CONTINUES: the circuit and the numbers are\
 the same, only the vector names differ. [ase::run_mode_advice $p report]"
  ::ase::echo $msg note
  lappend notes $msg
  return [join $notes "\n"]
}

# --- casemode batch item 10: the three defences ------------------------------
#
# `PLAN.md` §3b item 10 and §D5; `DECISIONS.md` **C3** (build both defences),
# **C4** (all three, none redundant) and **D1** (the pre-flight OFFERS the
# legacy corrections, never a silent rewrite). Long form, with every
# measurement: doc/claude/specs/simulator_profiles.md §14.
#
# THE DEFECT, and it is MODE-INDEPENDENT — a `.save` of a node that is not in
# the circuit does not produce an error a caller can see. Measured 2026-08-17 on
# BOTH binaries (/usr/local/bin/ngspice 46 and build-ver_50), in render_deck's
# own deck shape (analyses inside `.control`, bare `write`, no vector list):
#
#   .save v(nosuchnode) + tran  ->  rc=1, and a 569-byte raw IS WRITTEN:
#       Title: Constant values / Plotname: constants / No. Variables: 12
#       Date: == the `Command: ngspice-46, Build <stamp>` build stamp
#   ... and NOTHING on either stream names the bad token.
#
# So the run leaves a file that exists, parses, and holds twelve mathematical
# constants. `rc` is a real corroborating signal but it arrives WITH the file
# already written, which is why C3 rules it cannot replace the content check.
#
# THREE DEFENCES, and C4's table says why none of them is redundant:
#
#   (a) the pre-flight below  names the SPECIFIC bad expression before any
#                             simulator starts; blind to a name that is legal
#                             only because an .include'd PDK file defines it
#   (b) the $sim_status guard catches ANY failed analysis and leaves no
#                             artefact at all (render_deck); blind to a file we
#                             did not generate
#   (c) ase::raw_content_verdict  catches a bad file from ANYWHERE — old,
#                             another tool's, written before the guard existed —
#                             but cannot say WHY it is bad. Cheapest of the
#                             three (one comparison against `Plotname:`).
#
# The pre-flight is the only one that can refuse BEFORE the run, so it is the
# only one that can be wrong in the expensive direction: a false refusal blocks
# work that would have succeeded. Every ruling below therefore leans the same
# way — the map OVER-approximates, and anything it cannot adjudicate is
# `unknown` and passes.

# The identifiers an output expression names, WITH THE SPAN each one occupies
# in the expression text: {kind name first last} ..., in order.
#
# An expr is not always one identifier: it can be derived (`v(a)-v(b)`), an RPN
# row, negated (`-i(v1)`, test_ase_core's D1 golden), or differential
# (`v(a,b)`, which names TWO nodes — ase::bus_expr_bits' comment records that
# ngspice reads it as a difference and that `.save v(d,e)` saves both).
# `@dev[param]` shapes come back too and the resolver declines them.
#
# THE SPANS ARE WHAT MAKES D1's CORRECTION HONEST. A token-level `string map` of
# `v(<ident>)` cannot see `v(a,b)` at all (the ident is not wrapped in its own
# parens), so a differential row was refused with a remedy that silently did
# nothing; and two corrections for the same row could not both be applied,
# because the second no longer matched the string the first had already
# rewritten. Replacing by POSITION, right to left, repairs a row of any shape in
# one pass. (Fix round, item 10: two independently-reproduced defects.)
#
# THE LEADING ANCHOR IS LOAD-BEARING, NOT TIDINESS. Unanchored, `([vi])\(` also
# matches the `i(` inside ngspice's standard AC output form `vi(...)` and the
# `v(` inside `deriv(...)`: `vi(out)` was read as a CURRENT named `out`, found
# absent in the device table, and the whole run REFUSED with a nonsense
# diagnosis — a live false refusal of a legitimate expression, reachable
# straight from the Expression entry of the output editor. Requiring a
# non-identifier character (or the string start) before the letter costs the
# `vi`/`vdb`/`vm`/`vp`/`vr` family their pre-flight, which is a MISS (defences
# (b) and (c) still catch it) and never a false refusal — the direction every
# ruling in this file leans.
proc ase::preflight_ident_spans {ex} {
  set out {}
  foreach {wp kp ip} [regexp -all -inline -indices -nocase \
                        {(?:^|[^A-Za-z0-9_])([vi])\(([^()]*)\)} $ex] {
    set kind [expr {[string tolower [string index $ex [lindex $kp 0]]] eq {v}
                    ? {voltage} : {current}}]
    lassign $ip is ie
    if {$ie < $is} continue                       ;# `v()` — nothing named
    set inner [string range $ex $is $ie]
    set off $is
    foreach part [split $inner ,] {
      set len [string length $part]
      set lead 0
      while {$lead < $len && [string is space [string index $part $lead]]} { incr lead }
      set trail 0
      while {$trail < $len - $lead &&
             [string is space [string index $part end-$trail]]} { incr trail }
      set name [string range $part $lead [expr {$len - 1 - $trail}]]
      if {$name ne {}} {
        lappend out [list $kind $name [expr {$off + $lead}] \
                          [expr {$off + $len - 1 - $trail}]]
      }
      incr off [expr {$len + 1}]                  ;# +1 for the comma
    }
  }
  return $out
}

# The same identifiers as {kind name} pairs, spans dropped.
proc ase::preflight_idents {ex} {
  set out {}
  foreach s [ase::preflight_ident_spans $ex] {
    lappend out [list [lindex $s 0] [lindex $s 1]]
  }
  return $out
}

# The netlist's own name map: what the SIMULATOR will see, parsed out of the
# circuit netlist artifact rather than asked of the schematic — the deck is what
# runs, and `ase::run_existing` runs a netlist the design may no longer match.
#
#   scopes  <subckt name, folded> -> {nodes {<name> 1 ...}
#                                     devs  {<name> 1 ...}
#                                     insts {<inst> <master> ...}}
#           the TOP level is the scope named {}.
#   globals nodes visible in every scope (`.global`, plus `0`).
#   includes <scope> -> 1 for every scope that carries an `.include`/`.inc`/
#           `.lib` card, i.e. every scope whose contents this netlist only
#           PARTLY knows. C4's named blind spot, written down where the
#           resolver can act on it.
#
# A `+` CONTINUATION IS FOLDED ONTO ITS CARD, not skipped. Skipping it was a
# false refusal: a node declared only on a continuation was missing from the
# map and a legal run was refused. The premise that xschem never emits them for
# element cards is false — the user's own `~/.xschem/simulations/tb_bandgap.spice`
# carries 46, and `0_examples_top.spice` 439. Folding also fixes the X-card
# master being taken from the wrong token when the wrap lands between the last
# node and the master. (Fix round, item 10.)
#
# DELIBERATE OVER-APPROXIMATION, and it is the safe direction: a device card's
# node count is device-dependent (`M` has four, `X` has as many as its master),
# and a model name or a bare value is indistinguishable from a node without a
# device grammar. So every non-`k=v` token after the instance name is recorded
# as a node. That can only make a name look PRESENT that is not — a miss, which
# defences (b) and (c) still catch — and never the reverse, which would be a
# false refusal.
proc ase::netlist_map {netlist_text} {
  set scopes [dict create {} [dict create nodes {} devs {} insts {}]]
  set globals [dict create 0 1]
  set includes [dict create]
  set stack [list {}]
  # fold `+` continuations onto the card above before anything is parsed
  set logical {}
  foreach raw [split $netlist_text "\n"] {
    set t [string trimleft $raw]
    if {[string index $t 0] eq {+}} {
      if {[llength $logical]} {
        lset logical end "[lindex $logical end] [string range $t 1 end]"
      }
      continue                        ;# a stray continuation joins nothing
    }
    lappend logical $raw
  }
  foreach line $logical {
    set toks [regexp -all -inline {\S+} $line]
    if {![llength $toks]} continue
    set first [lindex $toks 0]
    set c [string index $first 0]
    if {$c eq {*} || $c eq {;} || $c eq {+}} continue
    if {$c eq {.}} {
      set kw [string tolower $first]
      if {$kw eq {.subckt}} {
        set key [string tolower [lindex $toks 1]]
        if {![dict exists $scopes $key]} {
          dict set scopes $key [dict create nodes {} devs {} insts {}]
        }
        foreach p [lrange $toks 2 end] {
          if {[string first = $p] >= 0} continue
          dict set scopes $key nodes $p 1
        }
        lappend stack $key
      } elseif {$kw eq {.ends} || $kw eq {.eom}} {
        if {[llength $stack] > 1} { set stack [lrange $stack 0 end-1] }
      } elseif {$kw eq {.global}} {
        foreach g [lrange $toks 1 end] { dict set globals $g 1 }
      } elseif {$kw eq {.include} || $kw eq {.inc} || $kw eq {.lib}} {
        dict set includes [lindex $stack end] 1
      }
      continue
    }
    set keep {}
    foreach t $toks { if {[string first = $t] < 0} { lappend keep $t } }
    set scope [lindex $stack end]
    dict set scopes $scope devs $first 1
    set rest [lrange $keep 1 end]
    if {[string match -nocase {x*} $first] && [llength $rest]} {
      dict set scopes $scope insts $first [lindex $rest end]
      set rest [lrange $rest 0 end-1]
    }
    foreach t $rest { dict set scopes $scope nodes $t 1 }
  }
  return [dict create scopes $scopes globals $globals includes $includes]
}

# One lookup in one name table. `cs` is the case-sensitivity of the comparison,
# NOT the mode: spec §13.6 — under `distinguish` a case-sensitive comparison is
# the right one, under `fold` the EXPRESSION is already folded and the map is
# not, so both sides must be folded or every mixed-case net reads as absent.
#
# -> {status present|absent  real <the netlist's own spelling>  ambiguous 0|1}
# An exact hit wins in either mode. A case-sensitive miss that folds to exactly
# ONE stored name yields that name as `real` — this is D1's correction, computed
# by the comparison the pre-flight was doing anyway. Two stored names folding
# together yield `ambiguous`: there is no correction to offer, only a question.
proc ase::preflight_pick {tbl name cs} {
  if {[dict exists $tbl $name]} {
    return [dict create status present real $name ambiguous 0]
  }
  set hits {}
  set f [string tolower $name]
  dict for {k v} $tbl {
    if {[string tolower $k] eq $f} { lappend hits $k }
  }
  if {![llength $hits]} {
    return [dict create status absent real {} ambiguous 0]
  }
  if {!$cs} {
    return [dict create status present real [lindex $hits 0] ambiguous 0]
  }
  if {[llength $hits] > 1} {
    return [dict create status absent real {} ambiguous 1]
  }
  return [dict create status absent real [lindex $hits 0] ambiguous 0]
}

# Resolve ONE identifier against the map.
#
# -> {status present|absent|unknown  real <the corrected identifier, or {}>
#     ambiguous 0|1  why <text, for unknown>}
#
# `unknown` is not a weaker `absent`, it is a REFUSAL TO JUDGE, and every arm
# that reaches it is a place where the netlist genuinely cannot answer:
#   * an `@dev[param]` shape (item 12 / issue 0419 territory);
#   * a bracketed name that is not an exact hit — a bus bit is a whole
#     sub-language (issue 0159) and the base name of `bus[1]` is not itself a
#     node, so a base-name test would false-refuse every bus;
#   * a hierarchy segment whose master subckt is not IN this netlist, i.e. it
#     came from an `.include`d PDK file — C4's named blind spot, and the one
#     place the pre-flight must stand down rather than guess.
#   * a name NOTHING in its scope even folds to, when that scope carries an
#     `.include`/`.inc`/`.lib` card. See the RULING below.
# An instance path segment that names NOTHING in a scope we did parse is
# `absent`, not `unknown`: that we can prove.
#
# RULING (fix round, item 10; spec §14.2) — AN INCLUDE-BEARING SCOPE STANDS
# DOWN, BUT ONLY WHERE IT HAS NOTHING TO SAY. A design whose stimulus or supply
# cards live in an `.include`d file was REFUSED outright: `i(V1)` with `V1` in
# `stim.sp` is absent from our map and the simulator runs it perfectly (measured:
# rc=0, a 2071-byte transient raw). C4 says the pre-flight is BLIND there, and
# blind means stand down, not refuse. But downgrading EVERY miss in an
# include-bearing scope would gut defence (a) for every real design, because
# every real design `.include`s a PDK. So the downgrade is narrowed to the case
# where the netlist genuinely has nothing to say: no stored name in that scope
# even FOLDS to the one asked about. A fold hit is a proof about THIS netlist —
# it is D1's correction and issue 0503's whole subject — and it keeps refusing.
proc ase::netlist_map_resolve {map kind name cs} {
  set unk [dict create status unknown real {} ambiguous 0 why {}]
  set includes {}
  catch {set includes [dict get $map includes]}
  if {[string first @ $name] >= 0} {
    dict set unk why {an @dev[param] name is constructed by the simulator}
    return $unk
  }
  set scopes [dict get $map scopes]
  set segs [split $name .]
  set prefix {}
  # A hierarchical CURRENT carries the branch prefix letter as its first
  # segment: `i(v.x1.x2.v1)`. It follows the TOKEN, not the mode (item 9 §13.3,
  # hilight.c's sender_current_prefix()), so the corrected spelling below
  # re-derives it from the device's own first character.
  if {$kind eq {current} && [llength $segs] > 1 &&
      [string length [lindex $segs 0]] == 1} {
    set prefix [lindex $segs 0]
    set segs [lrange $segs 1 end]
  }
  set scope {}
  set real {}
  # Whether ANY segment of the instance path came back mis-cased. The leaf's
  # verdict alone is not the identifier's verdict: with the netlist spelling the
  # instance `X1`, a stale fold-picked `v(x1.out)` under `distinguish` used to
  # resolve `present` on the strength of its leaf, so the pre-flight passed
  # through the exact 0503 row it exists to catch — while the case-keeping
  # binary aborted the analysis (measured: rc=1, RUN-FAILED, no raw).
  # (Fix round, item 10.)
  set segstale 0
  foreach s [lrange $segs 0 end-1] {
    if {![dict exists $scopes $scope]} {
      dict set unk why "subcircuit '$scope' is not defined in this netlist"
      return $unk
    }
    set insts [dict get $scopes $scope insts]
    if {[string first {[} $s] >= 0 && ![dict exists $insts $s]} {
      dict set unk why "bracketed instance name '$s'"
      return $unk
    }
    set hit [ase::preflight_pick $insts $s $cs]
    if {[dict get $hit real] eq {}} {
      if {![dict get $hit ambiguous] && [dict exists $includes $scope]} {
        dict set unk why "nothing in this netlist is named '$s', but an\
 .include'd file can add cards to this scope"
        return $unk
      }
      return [dict create status absent real {} ambiguous [dict get $hit ambiguous] \
                          why "no instance '$s'"]
    }
    if {[dict get $hit status] ne {present}} { set segstale 1 }
    lappend real [dict get $hit real]
    set master [dict get $insts [dict get $hit real]]
    set scope [string tolower $master]
    if {![dict exists $scopes $scope]} {
      dict set unk why "instance '$s' is a '$master', which this netlist does\
 not define (an .include'd model or subcircuit)"
      return $unk
    }
  }
  set leaf [lindex $segs end]
  set space [expr {$kind eq {current} ? {devs} : {nodes}}]
  set tbl [dict get $scopes $scope $space]
  if {$kind eq {voltage}} { set tbl [dict merge [dict get $map globals] $tbl] }
  if {[string first {[} $leaf] >= 0 && ![dict exists $tbl $leaf]} {
    dict set unk why "bracketed name '$leaf' (a bus bit is not adjudicable here)"
    return $unk
  }
  set hit [ase::preflight_pick $tbl $leaf $cs]
  if {[dict get $hit real] eq {}} {
    if {![dict get $hit ambiguous] && [dict exists $includes $scope]} {
      dict set unk why "nothing in this netlist is named '$leaf', but an\
 .include'd file can add cards to this scope"
      return $unk
    }
    return [dict create status absent real {} ambiguous [dict get $hit ambiguous] why {}]
  }
  lappend real [dict get $hit real]
  # the corrected identifier, in the netlist's own spelling from end to end
  set fixed [join $real .]
  if {$prefix ne {}} {
    set fixed "[string index [lindex $real end] 0].$fixed"
  }
  # a mis-cased HIERARCHY SEGMENT is as fatal as a mis-cased leaf, and `fixed`
  # already carries every segment's own spelling
  set st [dict get $hit status]
  if {$segstale} { set st absent }
  return [dict create status $st real $fixed \
                      ambiguous [dict get $hit ambiguous] why {}]
}

# THE PRE-FLIGHT. A pure function of a state and the circuit netlist text, so
# every ruling here is drivable with no simulator and no files.
#
#   -> {mode <requested>  cs 0|1  absent {<row> ...}  unknown {<row> ...}}
#      row = {expr <e> kind <k> ident <n> correction <c> ambiguous 0|1 why <w>}
#
# The mode is the RUN's REQUEST — item 9 §13.4's ruling, and the same value item
# 8's gate uses (profile `casemode` -> global floor `sim_case_mode` -> fold).
# It decides one thing only: whether the comparison is case-sensitive.
proc ase::preflight_scan {state netlist_text} {
  set mode fold
  # The same value item 8's gate uses. ⚠ ITEM 9's `init 0` READ-ONLY FORM IS
  # GONE WITH THE PROFILE LAYER, and it is not missed: the reason it existed was
  # that resolving a `sim()` row lazily called `::set_sim_defaults`, which with
  # the Simulation Configuration dialog open slurped every unsaved `cmd` edit
  # into the global array -- so asking a question CHANGED the configuration
  # (spec §13.4). The registry has no lazy init and no such side effect: reading
  # it is a read.
  catch {set mode [ase::sim_casemode_requested \
                    [ase::state_get $state simulator ngspice]]}
  if {$mode eq {}} { set mode fold }
  set cs [expr {$mode eq {distinguish}}]
  set map [ase::netlist_map $netlist_text]
  set absent {}
  set unknown {}
  set seen [dict create]
  foreach o [ase::state_get $state outputs] {
    if {[ase::state_get $o save 0] ne {1}} continue
    set ex [ase::state_get $o expr]
    if {$ex eq {}} continue
    foreach id [ase::preflight_idents $ex] {
      lassign $id kind ident
      set skey [list $ex $ident]
      if {[dict exists $seen $skey]} continue
      dict set seen $skey 1
      set r [ase::netlist_map_resolve $map $kind $ident $cs]
      set row [dict create expr $ex kind $kind ident $ident \
                 correction [dict get $r real] ambiguous [dict get $r ambiguous] \
                 why [dict get $r why]]
      switch -- [dict get $r status] {
        absent  { lappend absent $row }
        unknown { lappend unknown $row }
      }
    }
  }
  return [dict create mode $mode cs $cs absent $absent unknown $unknown]
}

# A scan's absent rows grouped by the OUTPUT ROW they came from, in
# first-appearance order: -> {<expr> {<row> ...} ...}. One output row can name
# several absent identifiers (`v(a)-v(b)`, `v(a,b)`), and every consumer below
# has to treat those as ONE thing to report and ONE thing to repair.
proc ase::preflight_group_rows {rows} {
  set g [dict create]
  foreach row $rows { dict lappend g [dict get $row expr] $row }
  return $g
}

# The corrected expression for ONE output row, with EVERY correction the scan
# found for it applied — each identifier replaced by the netlist's own spelling
# AT ITS OWN POSITION, right to left so no earlier span moves, leaving the rest
# of a derived expression (`v(a)-v(b)`, an RPN row, a leading `-`) untouched.
# {} when there is nothing to offer.
#
# `rows` is the LIST of that expression's absent rows (see
# ase::preflight_group_rows). It used to be a single row rewritten by a
# `string map` of the literal `v(<ident>)`, which had two reproduced defects:
# `v(a,b)` matched nothing at all, so the refusal named a remedy command that
# silently did nothing; and a second correction for the same row could never
# match, because the first had already rewritten the string it was looking for —
# yet the apply reported success. (Fix round, item 10.)
proc ase::preflight_fixed_expr {rows} {
  if {![llength $rows]} { return {} }
  set ex [dict get [lindex $rows 0] expr]
  set want [dict create]
  foreach row $rows {
    set c [dict get $row correction]
    if {$c eq {}} continue
    # keyed by KIND as well as name: the same spelling can be a node and a device
    dict set want [list [dict get $row kind] [dict get $row ident]] $c
  }
  if {![dict size $want]} { return {} }
  set out $ex
  foreach s [lsort -integer -index 2 -decreasing [ase::preflight_ident_spans $ex]] {
    lassign $s kind nm st en
    set k [list $kind $nm]
    if {![dict exists $want $k]} continue
    set out [string replace $out $st $en [dict get $want $k]]
  }
  if {$out eq $ex} { return {} }
  return $out
}

# D1 — the corrections are APPLIED ON CONFIRMATION, never silently. This is the
# apply half, and it is deliberately a separate, explicitly-invoked command:
# a silent rewrite of a saved session means that when our map is wrong about
# something we corrupt saved work with no trace.
#
# Rewrites session `key`'s output rows from the corrections the pre-flight found
# against the CURRENT netlist artifact, marks the session dirty (the user still
# has to save), and says what it changed. -> the number of rows rewritten.
proc ase::preflight_fix_session {key} {
  set state [ase::session_state $key]
  if {$state eq {}} { return -code error "ase: no such session: $key" }
  set design [ase::state_get $state design]
  if {$design eq {} || ![dict exists $design cell]} {
    return -code error "ase: session $key has no design cell"
  }
  set nl [file join [ase::rundir $state] [dict get $design cell].spice]
  if {![file isfile $nl]} {
    return -code error "ase: no netlist artifact to check against: $nl\
 (Simulation > Netlist > Recreate first)"
  }
  set f [open $nl r] ; set txt [read $f] ; close $f
  set scan [ase::preflight_scan $state $txt]
  # ONE REWRITE PER OUTPUT ROW, carrying ALL of that row's corrections. Applying
  # them one absent identifier at a time matched rows by the ORIGINAL expr, so
  # after the first rewrite every later correction for the same row silently
  # failed to match and was dropped — while the count still reported success and
  # the only signal was the next run refusing again. (Fix round, item 10.)
  set n 0
  set nskip 0
  dict for {ex grows} [ase::preflight_group_rows [dict get $scan absent]] {
    set fixed [ase::preflight_fixed_expr $grows]
    if {$fixed eq {}} { incr nskip ; continue }
    set outs {}
    foreach o [ase::state_get $state outputs] {
      if {[ase::state_get $o expr] eq $ex} {
        dict set o expr $fixed
        incr n
        ::ase::echo "ase: pre-flight — output '$ex' rewritten to\
 '$fixed' (the netlist's own spelling). The session is now unsaved."
      }
      lappend outs $o
    }
    dict set state outputs $outs
  }
  if {$n} { ase::session_update $key $state }
  # SAY SO WHEN THERE WAS NOTHING TO DO. A silent `0` from a command the refusal
  # itself told the user to run reads as "it worked".
  if {!$n} {
    ::ase::echo "ase: pre-flight — nothing was rewritten in session '$key':\
 [expr {$nskip ? "the $nskip refused output row(s) have no correction to offer"
        : {the pre-flight found nothing to correct}}]." note
  }
  return $n
}

# THE GATE. Called from ase::run_deck once the circuit netlist has been READ and
# before anything at all has been written, deleted or rebuilt — the same place
# in the sequence item 8's gate occupies (spec §12.5): a refusal must not
# manufacture a new instance of the very defect this item exists to kill.
#
# Refuses on `absent`, never on `unknown`. Every offending expression is named,
# one CIW line each — item 14's lesson is that a channel can be correct and
# still reach nobody, and a one-line summary of twelve corrections is a summary
# nobody can act on.
#
# `ase_preflight 0` disables the refusal. It is a real lever, named in the
# message, because the map's blind spot is real (a top-level node that only an
# .include'd file defines) and a user who is right must not be locked out of
# their own simulator. Defences (b) and (c) are unaffected by it.
proc ase::preflight_gate {state netlist_text} {
  if {[info exists ::ase_preflight] && !$::ase_preflight} { return {} }
  set scan [ase::preflight_scan $state $netlist_text]
  set rows [dict get $scan absent]
  if {![llength $rows]} { return {} }
  # COUNT EXPRESSIONS, NOT IDENTIFIERS. `[llength $rows]` is the number of
  # offending identifiers, and one output row naming two absent nodes was
  # reported as "2 output expressions". The per-identifier detail lines below
  # still get one line each. (Fix round, item 10.)
  set groups [ase::preflight_group_rows $rows]
  set nex [dict size $groups]
  set head "ase: REFUSED — $nex output expression[expr {$nex == 1 ? {} : {s}}]\
 name[expr {$nex == 1 ? {s} : {}}] something this circuit does not have.\
 ngspice does NOT fail usefully on that: NOTHING on either stream names the bad\
 token, and what lands in the run directory is a raw file holding TWELVE\
 MATHEMATICAL CONSTANTS (Plotname: constants) which reads back as a perfectly\
 valid result. Nothing was generated: no deck, no raw,\
 no log. Any files already in [ase::rundir $state] are from an earlier run."
  ::ase::echo $head error
  set lines [list $head]
  # Every offending IDENTIFIER gets its own line — item 14's lesson is that a
  # summary nobody can act on reaches nobody — but the CORRECTION is composed
  # once per expression and offered once, on that expression's last line: a row
  # naming two mis-cased nodes has ONE repaired spelling, not two mutually
  # exclusive halves.
  set nfix 0
  dict for {ex grows} $groups {
    set fixed [ase::preflight_fixed_expr $grows]
    set glines {}
    foreach row $grows {
      set l "ase:   '$ex' — [dict get $row kind] '[dict get $row ident]'\
 is not in the netlist"
      if {$fixed eq {} && [dict get $row ambiguous]} {
        append l ". Two netlist names differ from it only in case, so there is no\
 single correction to offer"
      }
      lappend glines $l
    }
    if {$fixed ne {}} {
      incr nfix
      set l [lindex $glines end]
      append l ". Same name in another case IS: '$ex' -> '$fixed'"
      lset glines end $l
    }
    foreach l $glines {
      ::ase::echo $l error
      lappend lines $l
    }
  }
  if {$nfix} {
    set l "ase: $nfix of them look like a CASE mismatch — an output row picked\
 under a 'fold' profile and run under 'distinguish' stores the folded spelling\
 forever (issue 0503). Nothing is rewritten automatically: run\
 `ase::preflight_fix_session <key>` to apply the corrections above to this\
 session's output rows, then save."
    ::ase::echo $l error
    lappend lines $l
  }
  set l "ase: set ase_preflight 0 to disable this check (the \$sim_status guard\
 and the constants-raw rejection stay on)."
  ::ase::echo $l error
  lappend lines $l
  return -code error [join $lines "\n"]
}
set_ne ase_preflight 1

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

# <rundir>/<cell>_ase.spice — the deck ase::run writes immediately before it
# launches the simulator (:995 renders into exactly this path, through this
# proc, so the two cannot drift). Named because issue 0838 needs to COMPARE it
# with the raw, and a second inline `file join [ase::rundir …] ${cell}_ase.spice`
# would go stale the day the naming changes.
#
# {} rather than an error for a state with no cell: every caller here is a
# predicate on a menu -postcommand or a key press, and neither may raise.
proc ase::deck_file {state} {
  if {$state eq {} || ![dict exists $state design cell]} { return {} }
  set cell [dict get $state design cell]
  set rd {}
  if {[catch {ase::rundir $state} rd]} { return {} }
  return [file join $rd ${cell}_ase.spice]
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
# `save_op_params` is read as a gate in THREE places — op_cards_capture,
# render_deck and the change detector below. Two independent normalisations of
# one key already existed and drift between them fails SILENTLY; issue 0637 is
# the standing proof it bites here. Invariant I1 (one builder, many consumers)
# applied to a gate rather than a vector name.
#
# ⚠ THE DEFAULT IS ON (issue 0927, 2026-08-29 — the user's call). Read the
# schema comment at the top of this file for the whole rule; the short form is
# that only an EXPLICIT false turns the feature off:
#     {} / absent -> 1     0 | no | false | off -> 0     everything else -> 1
#
# ⚠ THIS ALSO CLOSES ISSUE 0637 ITEM 1, in the only direction the flip leaves
# open. Before the flip a state hand-edited to `save_op_params yes` read OFF and
# the only report was a nudge telling the user to tick a box they thought they
# had ticked. `yes` now reads ON, and a hand-edited `no`/`false`/`off` reads OFF
# rather than silently reverting to the default. `string is false -strict` is
# what makes that true in both directions; it is deliberately -strict so that
# `{}` (the default) does NOT count as false.
proc ase::op_gate_on {v} {
  if {[string is false -strict $v]} { return 0 }
  return 1
}

# THE ONE WRITER, paired with the one reader above (invariant I1). Given a
# boolean the UI collected, return the value to store in the state.
#
# ⚠ ON IS `{}`, NOT `1`. `save_op_params` is in ase::omit_if_empty, so an on
# value keeps the key OUT of the serialized state entirely — a user who opens
# Save All on an existing bench, leaves the box at its default and presses OK
# gets a byte-identical .state file. OFF is the value that costs a key, which is
# exactly the user's requirement. Do NOT "improve" this to write a literal 1:
# that puts the key into every state anyone ever saves for no information gain.
proc ase::op_gate_value {on} {
  return [expr {$on ? {} : 0}]
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

# ============================================================================
# ISSUE 0963 — WHICH SHAPE THE DECK ASKS FOR DEVICE NUMBERS IN, AND WHY
# ============================================================================
# Three shapes, and the run picks ONE of them. The probe (issue 0948) already
# measures what the program that will start can do; until this section existed
# its answer had exactly one reader, ase::cap_report, which warns about three
# unrelated things and never touched the deck.
#
#   a  WILDCARD     one request per DEVICE, wildcarded over that device's own
#                   parameters, inside `.control` immediately before `op` --
#                   the exact shape the capability probe measures. O(devices)
#                   rather than O(devices x parameters): 78 FETs and 468 cards
#                   become 78 entries. No released ngspice can do it, so on this
#                   box it is COLD CODE by construction and is exercised only by
#                   a stand-in that claims the capability (test_ase_optier_0963
#                   section A). Cold code behind a green suite is what shipped
#                   issues 0928 and 0929.
#                   ⚠ IT WAS A DEVICE-LESS DECK-LEVEL PAIR UNTIL ISSUE 0966+0968
#                   and that was two defects at once: it answered a question the
#                   probe never asked, and a dot-card cannot be scoped to one
#                   analysis, so the device numbers rode the transient again.
#   b  WRITE LINE   `write <raw> all @dev1 @dev2 …` — each device named once,
#                   no parameter, on the OPERATING-POINT write only. O(devices)
#                   rather than O(devices x parameters): 78 FETs and 468 cards
#                   become one line with 78 names.
#   c  PER DEVICE   today's `.save @dev[param]` cards, one per device per
#                   parameter. What every automatic choice lands on.
#
# ⚠ SHAPE b IS NEVER CHOSEN AUTOMATICALLY, AND THAT IS DELIBERATE (guard G4).
# What a reader would otherwise assume is that a simulator which accepts the
# short form should be given it. MEASURED on the user's own tb_bandgap: naming
# all 78 devices on the operating-point write line produces a results file with
# NO OPERATING POINT IN IT AT ALL, at exit 0. Two of the 78 names this tree
# emits cannot be resolved (issue 0965) and ONE unresolvable name aborts the
# WHOLE write — "Error during 'write': no writable vector found.", no file. The
# same two names cost shape c 12 blank rows out of 468 and it keeps the other
# 456. So the short form trades 468 independently-degradable requests for one
# all-or-nothing request, on the one surface whose whole job is to stop numbers
# going missing quietly. It is built, it is exercised, and it is reachable
# through the override — nothing chooses it for anybody.
#
# ⚠ AND A SIMULATOR NOTHING WAS MEASURED ABOUT LANDS ON c, NEVER ON A GUESS
# (guard G2). `known` is tested FIRST and by its own key: an answer that
# carries no capability keys at all is "nothing was measured", not "no to
# everything". Row T11 pins that ordering structurally, because no behavioural
# row can tell a missing key from a measured 0.
namespace eval ase { variable op_tier_force {} }

# THE MEASURED BOUNDS, minted once each because both are quoted in comments and
# consumed in two places, and a bound that drifts between them fails silently.
#
# ⚠ THESE ARE NOT THE SAME NUMBER AND MUST NOT BE MERGED. ngspice takes at most
# 1000 arguments after a command word, and the two commands spend that budget
# differently — `write <file> all @d1…@dK` spends two on the file and the
# save-everything word, `save all @n1…@nK` spends one. MEASURED, ngspice-46+:
#   write : 998 names fine; at 999 it prints `write: too many args.`, writes NO
#           FILE AT ALL, and exits 0.
#   save  : 999 names fine; at 1000 it prints `save: too many args.` and the
#           results file is still written, with the node voltages and zero
#           device vectors, at exit 0.
# Both failures are silent-under-emission, which is why neither is guessed.
proc ase::op_write_max_names {} { return 998 }
proc ase::op_save_max_names {} { return 999 }

# THE OVERRIDE (issue 0963). Force one shape regardless of what was measured,
# for support and for the suites — `a`, `b`, `c`, or {} to hand the decision
# back. Tcl-level on purpose: no menu item and nothing in the Save All dialog,
# which is the smallest blast radius that still covers both stated users. That
# choice is on the user's queue.
#
# ⚠ THIS IS THE ONLY DOOR TO SHAPES a AND b. Shape a needs a simulator nobody
# has, and shape b is refused by guard G4 above; without the override both arms
# would be paths only somebody else's machine ever runs, which is the specific
# failure that produced issues 0928 and 0929.
proc ase::op_tier_force_set {t} {
  variable op_tier_force
  if {$t ne {} && [lsearch -exact {a b c} $t] < 0} {
    return -code error "ase: op_tier_force_set: expected a, b, c or {}, got '$t'"
  }
  set op_tier_force $t
  return $t
}

# What the override is set to, or {} when the measurement decides.
proc ase::op_tier_forced {} {
  variable op_tier_force
  return $op_tier_force
}

# The captured block itself, whatever netlist text it was built from — {} when
# nothing is held.
#
# ⚠ DELIBERATELY NOT ase::op_cards_for, AND THE DIFFERENCE MATTERS. op_cards_for
# answers only for EXACTLY one netlist text, because emitting a block into a
# deck it was not built from names devices that deck may not contain. Choosing
# a SHAPE is a different question: it needs only how many devices there are,
# and it is asked from ase::op_save_tier, whose caller has already decided
# whether the block is emittable at all.
proc ase::op_cards_block {} {
  variable op_cards
  if {![dict exists $op_cards block]} { return {} }
  return [dict get $op_cards block]
}

# The bare `@dev[param]` names carried by a captured block, in block order.
#
# ⚠ DERIVED FROM THE BLOCK, NEVER REBUILT (invariant I1). op_annot::save_cards
# is the one place a device name is composed; this reads the names back out of
# what it produced. A second walk of the hierarchy here would be a second name
# builder, and the two would drift on exactly the cells issue 0965 is about.
proc ase::op_cards_names {block} {
  set out {}
  foreach l [split $block "\n"] {
    if {[regexp {^\.save[ \t]+(@[^ \t]+)[ \t]*$} $l -> nm]} {
      if {[string first {[} $nm] >= 0} { lappend out $nm }
    }
  }
  return $out
}

# THE DEVICE HALF OF A `@dev[param]` NAME — ONE SPLITTER, ISSUE 0972.
#
# ⚠ THE PARAMETER BRACKET IS THE LAST ONE, NEVER THE FIRST, AND A BUS IS WHY.
# What a reader would otherwise assume is that a device name has no bracket in
# it. It does whenever the instance is a VECTOR: `M1[9:0]` netlists as ten
# element lines `XM1[9]` .. `XM1[0]`, and the save card then reads
#
#     .save @m.xm1[9:0].msky130_fd_pr__nfet_01v8[id]
#
# Measured on the shipped sky130_tests_ase/sky130_mismatch bench, where cutting
# at the first bracket answered `@m.xm1` — not a device, and the SAME key for
# every member, so ten different transistors became one. That cost two things
# at once: the short-and-wide form put `@m.xm1` on its write line (a name the
# deck does not contain, which costs the whole operating point at exit 0), and
# the did-not-come-back report went quiet, because one member answering covered
# for the other nine.
#
# A parameter name never contains a bracket, so the last bracket is always the
# parameter's. Both callers hand in a name that HAS a parameter suffix
# (ase::op_cards_names keeps only cards that carry one; a results-file variable
# for a device parameter always carries one), and a name with no bracket at all
# answers {} rather than guessing.
#
# ⚠ SPELLED ONCE (invariant I1). ase::op_cards_devices and
# ase::op_report_missing must cut identically or the report compares a name
# against a differently-cut copy of itself; row Q11 keeps them on this proc.
proc ase::op_dev_of {nm} {
  set i [string last {[} $nm]
  if {$i <= 0} { return {} }
  return [string range $nm 0 [expr {$i - 1}]]
}

# The distinct devices a captured block names, in block order, with the
# `[param]` suffix cut off — one entry per device however many parameters it
# carries. This is what shape b puts on the write line.
proc ase::op_cards_devices {block} {
  set out {}
  set seen [dict create]
  foreach nm [ase::op_cards_names $block] {
    set dev [ase::op_dev_of $nm]
    if {$dev eq {}} { continue }
    if {[dict exists $seen $dev]} { continue }
    dict set seen $dev 1
    lappend out $dev
  }
  return $out
}

# THE WILDCARD THE CAPABILITY QUESTION IS ASKED WITH, AND ANSWERED WITH — ONE
# LITERAL, ISSUE 0966.
#
# ⚠ IT LIVES WITH THE PROBE ON PURPOSE, AND THE EMITTER BORROWS IT. The name
# says whose literal it is: the capability question's. Row C3 of
# test_ase_simcaps_0948 unions the `ase::cap_*` family's bodies and requires the
# wildcard to be findable in them, which is why this is `cap_` and not `op_`.
#
# ⚠ IT IS SPELLED HERE AND NOWHERE ELSE, AND THAT IS THE WHOLE OF THE FIX. What
# a reader would otherwise assume is that a capability measured with one shape
# can be used with another. It cannot: the probe deck asked
# `save @<device>[<this>]` — one request per device, wildcarded over that
# device's own parameters, inside `.control` — and the deck a YES answer used to
# get was a device-less `.save all` plus `.options saveopparams` at DECK level.
# (That word appears here ONLY in this comment. Row E18 counts it in the
# comment-stripped file and in render_deck's comment-stripped body, and expects
# zero of each, so this sentence is invisible to it -- deliberately, because the
# history is worth keeping and the code word must not be.)
# Two different questions with one answer between them is a false YES with extra
# steps, and the deck-level half is how issue 0928's per-analysis scoping was
# lost before (issue 0968). Both the probe and the emitter now read this proc,
# so the measured shape and the emitted shape cannot drift apart again. Row E15
# counts this literal in the comment-stripped file and expects exactly one.
#
# ⚠ WRITTEN WITH THE BACKSLASHES A TCL SOURCE FILE NEEDS, and they are not
# decoration: an unescaped `[...]` in a Tcl word is a command to run. The proc
# RETURNS the three characters; the file CONTAINS the escaped five.
proc ase::cap_param_wildcard {} { return \[*\] }

# The wildcard request for each DISTINCT device a captured block names — the
# shape the probe measured, one entry per device, covering every parameter that
# device has. Derived from the block, never rebuilt (invariant I1).
proc ase::op_cards_wildcards {block} {
  set out {}
  foreach d [ase::op_cards_devices $block] {
    lappend out "$d[ase::cap_param_wildcard]"
  }
  return $out
}

# The `save` command lines shape c emits INSIDE `.control` (issue 0964), split
# at the measured bound with the save-everything word on the FIRST line only.
#
# ⚠ A SPLIT `save` ACCUMULATES; A SPLIT `write` DOES NOT. MEASURED: two `save`
# lines of 300 names each leave 500 distinct device vectors in the plot, byte
# for byte what one line of 600 gives. Two `write` lines under `set appendwrite`
# instead produce TWO plots BOTH named `Operating Point`, and `xschem raw read
# <file> op` picks one of them — half the devices become silently unreadable.
# That asymmetry is the whole reason shape b has a hard one-line ceiling
# (guard G6) while shape c has none.
proc ase::op_ctl_saves {names} {
  set out {}
  set max [ase::op_save_max_names]
  set n [llength $names]
  set i 0
  while {$i < $n} {
    set chunk [lrange $names $i [expr {$i + $max - 1}]]
    if {$i == 0} {
      lappend out "save all [join $chunk { }]"
    } else {
      lappend out "save [join $chunk { }]"
    }
    incr i $max
  }
  return $out
}

# THE DECISION. Returns {tier a|b|c reason <token> ndev N ncards M}.
#
# Every arm is testable on a box with no simulator at all by priming
# ase::sim_caps, and that is how the whole of section T drives it.
#
# ⚠ IT IS NOT SIDE-EFFECT FREE, and an earlier version of this comment said
# it was. `ase::sim_capabilities` is lazy: on a cache MISS it makes a scratch
# folder and STARTS THE USER'S SIMULATOR (twice, under a timeout) before it can
# answer. Every test row states the answer outright, so no row has ever taken
# that path from here -- and in production `ase::run_deck` warms the cache one
# line earlier, so a Run pays for the measurement once, where the user expects
# a simulator to start. Do NOT move this call onto a path that renders a deck
# without a Run behind it, and do not read the comment two hundred lines up
# about the walk staying out of render_deck as covering this one: it does not.
#
# The guards, in order, each on its own line and each with its own reason token
# so a reader of the CIW and a test row can both tell which one fired:
#
#   G1 forced   the override is set                       -> that shape
#   G2 unknown  nothing was measured about the program    -> c
#   G3 blanket  it can save every device in one request   -> a
#   G4 unsafe   it could take the short form              -> c   (the demotion)
#   G5 nocap    it can take neither shorter form          -> c
#   G6 toomany  the short form will not fit on one line   -> c
#
# ⚠ G4 AND G5 RETURN THE SAME SHAPE, so nothing behavioural can tell them apart
# and only the reason token separates them. That is why test_ase_optier_0963
# carries a STRUCTURAL row (T12) asserting G4 exists at all: delete its body and
# the suite would otherwise stay green while every ngspice on earth was silently
# switched onto the all-or-nothing write.
#
# ⚠ G6 BEATS THE OVERRIDE, and it is the one place a forced choice is refused.
# Splitting is not available (see ase::op_ctl_saves), so the alternative to
# refusing is an operating point with half its devices missing and no complaint
# anywhere — the defect this whole surface exists to delete.
proc ase::op_save_tier {state} {
  variable op_tier_force
  set blk [ase::op_cards_block]
  set ndev [llength [ase::op_cards_devices $blk]]
  set ncards [ase::op_cards_count $blk]
  set tier c
  set reason nocap
  if {$op_tier_force ne {}} {
    set tier $op_tier_force
    set reason forced
  } else {
    # ⚠ CAUGHT, AND A RAISE IS READ AS "NOTHING WAS MEASURED". What a reader
    # would otherwise assume is that this call cannot fail: ase::sim_capabilities
    # deliberately RE-RAISES a backend probe's own error so a defect in it stays
    # loud (issues 0949-0954). It stays loud where it should -- ase::cap_report
    # and the probe's own suite call it uncaught -- but THIS caller is on the
    # deck-rendering path of an opt-in annotation extra, and op_cards_capture's
    # rule applies to it word for word: an annotation extra may not break
    # Netlist-and-Run. So a probe that blew up lands on the per-device form,
    # which is the one that always works.
    if {[catch {ase::sim_capabilities \
                  [ase::state_get $state simulator ngspice]} caps]} {
      set caps [dict create known 0]
    }
    if {![dict exists $caps known] || [dict get $caps known] != 1} {
      set tier c
      set reason unknown
    } elseif {[dict exists $caps blanket_op_save] &&
              [dict get $caps blanket_op_save] == 1} {
      set tier a
      set reason blanket
    } elseif {[dict exists $caps appendwrite] && [dict get $caps appendwrite] == 1 &&
              [dict exists $caps hier_op_names] && [dict get $caps hier_op_names] == 1} {
      set tier c
      set reason unsafe
    } else {
      set tier c
      set reason nocap
    }
  }
  if {$tier eq {b} && $ndev > [ase::op_write_max_names]} {
    set tier c
    set reason toomany
  }
  return [dict create tier $tier reason $reason ndev $ndev ncards $ncards]
}

# SAY WHICH SHAPE THE RUN USED, ONCE, IN THE USER'S OWN WORDS. Called from
# ase::run_deck; returns the kind that was said, or {} when there was nothing
# to say — a real answer, not an absence.
#
# ⚠ SILENT WHEN NO DEVICE NUMBERS WERE ASKED FOR AT ALL. The three conditions
# are exactly render_deck's own: the user's tick, an enabled operating point,
# and a block captured from THIS netlist text. A run that emits no device
# requests has no shape to report, and a sentence about one would be a claim
# about a deck that does not carry it.
#
# ⚠ THE SENTENCES ARE MINTED IN ase::sim_why AND SAID THROUGH ase::sim_say
# (ruling D5-4), never rendered here. The Simulators dialog reads back what was
# said; a sentence composed at a say-site cannot be read back, and row S4 greps
# the comment-stripped file for exactly that construct.
proc ase::op_tier_report {sim state netlist_text} {
  if {![ase::op_gate_on [ase::state_get $state save_op_params {}]]} { return {} }
  if {![ase::op_analysis_enabled $state]} { return {} }
  if {[ase::op_cards_for $netlist_text] eq {}} { return {} }
  set d [ase::op_save_tier $state]
  set path {}
  catch {set path [dict get [ase::sim_status $sim] resolved]}
  set kind op_tier_perdevice
  switch -- [dict get $d tier] {
    a { set kind op_tier_blanket }
    b { set kind op_tier_writeline }
  }
  ase::sim_say $kind $sim $path [dict get $d reason] note
  if {[dict get $d reason] eq {forced}} {
    ase::sim_say op_tier_forced $sim $path {} note
  }
  return $kind
}

# ============================================================================
# ISSUE 0965 — A DEVICE THAT CAME BACK WITH NOTHING IS NEVER SILENT AGAIN
# ============================================================================
# MEASURED FIRST-HAND, ngspice-46+. A `.save` card naming a device that is not
# in the deck is accepted without one character of complaint: exit 0, a normal
# results file, and the bad name lands in it as a zero-length entry that
# `remzerovec` then strips, so not even the file remembers it was asked for.
# In-`.control` `save` behaves the same. The one shape that does speak is the
# short one-line form, and it speaks by throwing the WHOLE operating point away
# and writing no file at all, still at exit 0.
#
# On the user's own tb_bandgap that cost 12 blank annotation rows out of 468
# with nothing said anywhere: op_annot's warnings were empty, its counts read
# all zeroes, and the 561-line run log had no occurrence of "no such". The only
# count the user was ever shown is how many requests went IN (op_cards_capture's
# last line). Nothing compared that with what came back.
#
# ⚠ THIS SILENCE IS OURS TO REMOVE, NOT THE SIMULATOR'S. What a reader would
# otherwise assume is that a run which exits 0 with a results file succeeded.
# It is exactly the failure this whole surface exists to delete, and it is the
# reason the two sentences below are minted at all.
#
# ⚠ A MISSING `Operating Point` PLOT IS "NONE OF THEM CAME BACK", NOT AN ERROR
# TO SWALLOW. Measured on the bench with the short form and one unmatchable
# name: on an operating-point-only deck no file is written, but with a transient
# in the same run the file EXISTS, holds the transient, and simply has no
# operating point in it. A report that only asked "did a file appear" would say
# nothing in the shape the user actually runs.
#
# CAUGHT BY ITS CALLER, and everything it says is advisory: a defect in a report
# may never break a run. Returns the kind it said, or {} when there was nothing
# to say -- a real answer, not an absence.
proc ase::op_report_missing {state meta exitcode} {
  ## ⚠ A RUN THAT ALREADY FAILED LOUDLY IS NOT ALSO TOLD ITS DEVICES ARE
  ## MISSING. On a nonzero exit the user has a real error in front of them and
  ## every device is "missing" by construction; a second sentence counting them
  ## buries the first. Row Q10.
  if {$exitcode ne {0}} { return {} }
  set blk [ase::state_get $meta opblock {}]
  if {$blk eq {}} { return {} }
  set devs [ase::op_cards_devices $blk]
  if {![llength $devs]} { return {} }
  set sim [ase::state_get $state simulator ngspice]
  set path {}
  catch {set path [dict get [ase::sim_status $sim] resolved]}
  ## ⚠ "I COULD NOT WORK OUT WHERE THE FILE WOULD BE" IS NOT "THERE IS NO FILE".
  ## A backend with no raw_file hook, or one that raises, leaves nothing to
  ## check; saying the run produced no results then would be a claim about a
  ## file this proc never looked for. Silence is the honest answer there.
  ## Row Q9 drives both halves: an unregistered simulator (the hook LOOKUP
  ## raises) and a state the ngspice hook itself refuses (no cell).
  set raw {}
  if {[catch {[ase::backend_hook $sim raw_file] $state} raw]} { return {} }
  if {[string trim $raw] eq {}} { return {} }
  if {![file isfile $raw]} {
    ase::sim_say op_numbers_no_file $sim $path $raw error
    return op_numbers_no_file
  }
  set vars {}
  catch {
    set vars [lindex [ase::cap_plot [ase::cap_raw_plots $raw] {Operating Point}] 2]
  }
  ## Which devices the results file actually answered for, as a set, taken by
  ## EXACT device name -- everything from the `@` up to the PARAMETER bracket,
  ## cut by the one splitter the save cards were cut with (ase::op_dev_of).
  ##
  ## ⚠ NOT A SUBSTRING TEST, AND THAT IS THE WHOLE POINT OF THIS PROC.
  ## `@m.x1.xm1.mfoo` is a substring of `@m.x1.xm1.mfoobar`, so a substring test
  ## would call a device present because a LONGER-NAMED one came back -- i.e. it
  ## would go quiet about a device that produced nothing, which is the exact
  ## silence this proc exists to remove. Row Q7 is that guard's witness. It is
  ## also O(vars + devices) rather than O(vars x devices), on a plot that holds
  ## 879 entries on the user's own bench.
  ##
  ## ⚠ THE CUT IS THE LAST BRACKET, NOT THE FIRST (issue 0972). A bussed
  ## instance carries a bracket INSIDE its device name, so cutting at the first
  ## one collapses every member of the bus onto one key and one member
  ## answering covers for all the rest -- the same silence again, wearing a bus
  ## index. Row Q8. Both cuts go through ase::op_dev_of so the two sides of this
  ## comparison cannot be cut differently; row Q11.
  set answered [dict create]
  foreach v $vars {
    set a [string first {@} $v]
    if {$a < 0} { continue }
    set d [ase::op_dev_of [string range $v $a end]]
    if {$d eq {}} { continue }
    dict set answered $d 1
  }
  set miss {}
  foreach d $devs {
    if {![dict exists $answered $d]} { lappend miss $d }
  }
  if {![llength $miss]} { return {} }
  ## GUARD NB-ZERO, ISSUE 0975. Two different things happened and they are not
  ## the same sentence. SOME came back and some did not: a device the deck
  ## spells differently is the likely reason and the run says so, which is what
  ## issue 0965 was closed on. NONE came back at all: the results file is there,
  ## the operating point is not in it, and NOTHING here established why -- so
  ## the run says what it found, names no cause, and points at the log the
  ## simulator itself wrote. A reader would otherwise assume one sentence covers
  ## both; it did, and that was the defect.
  ##
  ## The kind is RETURNED, not merely said, so a caller (and row Q12) can tell
  ## which shape the run decided it was in without reading the prose.
  ##
  ## ⚠ AND THE TEST IS NOT "DID EVERY DEVICE I ASKED ABOUT COME BACK EMPTY".
  ## Those are two different facts and this proc holds the one that separates
  ## them, `vars`, read three dozen lines up: the operating-point plot itself.
  ## A sheet with ONE device whose name is spelled differently in the deck
  ## leaves every requested device missing while the operating point sits
  ## complete in the results file -- and issue 0975's own worked example is
  ## exactly that shape. Deciding on the count alone told that user their
  ## operating point never finished and sent them to a log with nothing wrong
  ## in it, which is the same defect 0975 is about wearing the fix's clothes.
  ## The all-or-nothing sentence is for a file with NO operating point in it.
  ## Row Q17.
  if {[llength $miss] == [llength $devs] && ![llength $vars]} {
    ase::sim_say op_numbers_none $sim $path \
      [list [llength $devs] [file tail $raw]] error
    return op_numbers_none
  }
  ase::sim_say op_numbers_missing $sim $path \
    [list [llength $devs] [expr {[llength $devs] - [llength $miss]}] $miss] error
  return op_numbers_missing
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
    # ⚠ THE GATE NO LONGER DEFAULTS OFF (issue 0927): reaching here means the
    # state says `save_op_params 0`, i.e. the user turned it off by hand. The
    # nudge stays anyway — it is still the one line that explains a deck with no
    # device parameters in it, and it now names a setting the user themselves
    # changed. 468 cards on a 31-FET bench (~3000 on a 500-device block, issue
    # 0620) is a real deck cost, which is why turning it off stays possible.
    # One line, only when an `op` analysis is enabled.
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
  ## ⚠ 0928: DEVICE OPERATING-POINT CARDS ARE FOR AN OPERATING-POINT ANALYSIS.
  ## Nothing gated the EMIT on one. `ase::op_analysis_enabled` existed and was
  ## consulted by exactly ONE caller -- the gate-off nudge above -- so a
  ## transient-only bench collected a `.save` card per device per parameter that
  ## no feature in this tree can read: `6` annotates an operating point, and
  ## `Alt+Shift+6` reads node voltages from the raw, never a device parameter.
  ##
  ## MEASURED, and it is why this guard is not cosmetic: a deck-level `.save` is
  ## sampled at EVERY timepoint of EVERY analysis in the deck. 3000 cards (500
  ## devices x 6) cost +0.03 s and +107 KB under `.op` -- free -- and +8.6 s and
  ## +242 MB under a 10068-point `.tran`, on a raw that grows 6.9x. Harmless
  ## while the gate defaulted off; a tax on every transient run the moment 0927
  ## turned it on.
  ##
  ## Records an EMPTY HIT rather than returning bare: render_deck's
  ## stale-artifact arm fires on a cache MISS, and a bare return would make it
  ## tell the user to re-netlist an artifact this session just wrote (issue
  ## 0635's contradiction, C13's subject).
  if {![ase::op_analysis_enabled $state]} {
    ase::op_cards_note_refusal $netlistpath
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

  # casemode batch item 8 (B4): the pre-run gate, FIRST, before any artefact is
  # read, deleted, rebuilt or written. A refusal raises from here, so nothing
  # half-written can be left behind; a `preserve` mismatch returns the line to
  # put in the run log and has already reached the CIW pane.
  set casenote {}
  if {[ase::run_composes_registry $sim]} {
    set casenote [ase::run_precheck $state]
  }

  set f [open $netlistfile r]
  set netlist_text [read $f]
  close $f

  # casemode batch item 10 (C3/C4, defence (a)): the PRE-FLIGHT, and it sits
  # here for the same reason item 8's gate sits above — everything before this
  # line only READS, so a refusal leaves no deck, no raw, no log, no deleted
  # VCD, no rebuilt .so and no started process. It needs the netlist text, so it
  # cannot be item 8's neighbour any earlier than this.
  ase::preflight_gate $state $netlist_text

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
  ## 0929: AND THE RAW, for the same reason one line up — plus a new one. The
  ## deck now emits `set appendwrite` and one `write` per analysis, so a raw
  ## left over from the previous run would not be truncated: this run's plots
  ## would be APPENDED to it, and `xschem raw read <file> op` would hand `6` the
  ## PREVIOUS run's operating point. Deleting it also restores the plain
  ## property the single-`write` deck used to have for free — a run that dies
  ## before it writes leaves no raw, instead of serving last run's numbers as
  ## though they were this one's.
  catch {file delete -- [[ase::backend_hook $sim raw_file] $state]}
  ## 0948: AND SAY SO IF THE PROGRAM ABOUT TO START CANNOT DO WHAT THIS RUN
  ## NEEDS. The deletion one line up, and the `set appendwrite` the deck is
  ## about to carry, BOTH assume the simulator adds each analysis to the
  ## results file. Nothing checked that until here, and a build that does not
  ## honour it exits 0, logs no warning and no error, and leaves the user with
  ## issue 0929's symptom and no word of explanation.
  ##
  ## HERE AND NOT IN run_cmd: run_cmd's returned command and its echo
  ## behaviour are pinned byte for byte by row D4 of
  ## tests/headless/test_ase_simreg_0931.tcl, and every row there counts the
  ## echoes. The report belongs to the RUN, which is this proc.
  ##
  ## CAUGHT, BECAUSE A PROBE THAT CANNOT RUN MUST NEVER STOP THE RUN IT WAS
  ## ONLY REPORTING ON. Everything it says is advisory; nothing downstream
  ## reads its answer. The suite calls ase::cap_report directly, uncaught, so
  ## a defect in it is still loud where it should be.
  catch {ase::cap_report $sim [ase::n_enabled_analyses $state]}
  ## 0963: AND SAY, IN PLAIN WORDS, HOW THIS RUN ASKED FOR DEVICE
  ## OPERATING-POINT NUMBERS AND WHY. Until this line the probe's answer had one
  ## reader (cap_report, one line up) that never touched the deck, and the whole
  ## of what a user was told about the strategy was a count of cards emitted at
  ## netlist time. The sentence names no capability, no internal word and no
  ## letter for the shape -- ase::sim_why mints all four of them.
  ##
  ## HERE AND NOT IN run_cmd, for cap_report's reason one line up: run_cmd's
  ## returned command and its echo behaviour are pinned byte for byte by row D4
  ## of tests/headless/test_ase_simreg_0931.tcl. The report belongs to the RUN.
  ##
  ## CAUGHT, for cap_report's reason too: everything it says is advisory and
  ## nothing downstream reads it, so a defect in it must never stop a run. The
  ## suite calls ase::op_tier_report and ase::op_save_tier directly, uncaught.
  ##
  ## SILENT when this deck asks for no device numbers at all -- op_tier_report
  ## re-checks render_deck's own two gates and the captured block.
  catch {ase::op_tier_report $sim $state $netlist_text}
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
  set deckpath [ase::deck_file $state]      ;# ONE owner of this path (issue 0838)
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
  ## 0965: WHAT THIS DECK ASKED FOR, CARRIED TO THE ONLY PLACE THAT CAN SEE
  ## WHAT CAME BACK. ase::run_done fires from execute_fileevent on EOF and is
  ## handed the state and this metadata, never the netlist text -- so the
  ## captured block has to travel with the run. Taken HERE, after the deck was
  ## rendered from it, so the record is what this run really asked, including
  ## anything a caller put into the block between netlisting and rendering.
  ##
  ## The two gates are render_deck's own: without the user's tick and an enabled
  ## operating point the deck carries no device requests, and a report about
  ## requests that were never made is a claim about a deck that does not exist.
  ## Empty means "nothing to compare", which is what every run that asks for no
  ## device numbers leaves behind.
  set opblock {}
  if {[ase::op_gate_on [ase::state_get $state save_op_params {}]] &&
      [ase::op_analysis_enabled $state]} {
    catch {set opblock [ase::op_cards_for $netlist_text]}
  }
  ## `casenote` is `fluid-editing`'s casemode batch item 8, section 3b: "report
  ## in the log AND the CIW". The CIW half already happened in
  ## ase::run_precheck, before the simulator started; the log half can only
  ## happen after it. It arrives as a FIELD of this record rather than as a
  ## rival fourth argument to ase::run_done, because 0618 had already claimed
  ## that parameter for the metadata and two callbacks disagreeing about what
  ## argument four means is the defect neither branch would have caught alone.
  ## ase::run_log_header renders it; empty writes nothing.
  set meta [dict create cell $cell simulator $sim cmd $cmd dir $rd \
                        deck $deckpath started [clock seconds] \
                        opblock $opblock casenote $casenote \
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
  ## THE CASEMODE NOTE, from `fluid-editing`'s casemode batch item 8 section 3b.
  ## It goes in the HEADER and not above it: item 8 asked for "the head of the
  ## file, the one place a reader who scrolls nothing at all still sees", and
  ## since 0618 the head of the file IS this block -- prefixing the whole file
  ## instead would put a run's most important sentence ABOVE the line that says
  ## which run it was.
  ##
  ## ⚠ IT IS THE LAST FIELD, AND MULTI-LINE. ase::run_precheck joins its notes
  ## with newlines and can return two of them (a status note and a dropped-args
  ## note), so a fixed-width `key : value` line cannot hold it. Anything empty
  ## writes NOTHING -- the ordinary run's log is byte-identical to a run with no
  ## casemode question at all, which is what keeps 0618's committed log goldens
  ## green.
  set cn [ase::state_get $meta casenote {}]
  if {$cn ne {}} {
    append out "notes     :\n"
    foreach l [split [string trimright $cn "\n"] "\n"] { append out "  $l\n" }
  }
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
  ## 0965: AND SAY, BEFORE THE FINISH LINE, HOW MANY DEVICES WERE ASKED ABOUT
  ## AND HOW MANY CAME BACK -- because a simulator that could not match a device
  ## name says nothing at all about it, and a blank row on a schematic with no
  ## diagnostic anywhere is the single largest cost this feature has.
  ##
  ## CAUGHT, for ase::cap_report's and ase::op_tier_report's reason: everything
  ## it says is advisory, nothing downstream reads it, and a defect in a report
  ## must never break a run. The suite calls ase::op_report_missing directly,
  ## uncaught.
  catch {ase::op_report_missing $state $meta $exitcode}
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
# order op dc ac tran ({} when none is enabled).
#
# ⚠ THIS PROC NO LONGER MIRRORS render_deck's EMIT ORDER, AND ITS OWN COMMENT
# USED TO SAY IT MUST, FOREVER (issue 0964). That coupling was true of a deck
# with ONE trailing `write`, where the results file carried whichever analysis
# happened to run last. Two changes broke it and neither can be undone here:
# issue 0929 made the deck write once PER analysis, so the file carries every
# one of them; and issue 0964 made the operating point run LAST when its device
# requests moved inside `.control`, so "last to run" became `op` on exactly the
# op+tran benches whose waveform window should open on the TRANSIENT.
#
# What the answer means now is "the analysis this state's results should be
# SHOWN as", and both readers find their plot BY NAME — `xschem raw read <file>
# op` picks the operating point out of a multi-plot file and `... tran` picks
# the transient (measured against this tree). So the fixed order below is a
# preference, not a mirror: the transient wins over the operating point because
# it is what a user who enabled both wants to look at. Row R6 pins it, and it
# is the only place the reorder could have silently changed the user's waveform
# window.
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
# op_annot::_annotated (`src/op_annot.tcl`) additionally requires that the annotation
# already be live, which would grey the control precisely when the user wants to
# turn annotation ON.
proc ase::has_results {key} {
  if {[ase::last_rawfile $key] eq {}} { return 0 }
  return [expr {[ase::results_stale $key] ? 0 : 1}]
}

# "Session `key`'s raw is OLDER than the deck it claims to describe" — issue 0838.
#
# A raw file DESCRIBES A DECK. It is usable as this session's results iff it is
# at least as new as the deck it claims to describe:
#
#     mtime(<rundir>/<cell>_ase.raw) >= mtime(<rundir>/<cell>_ase.spice)
#
# ⚠ WHY THIS EXISTS. `has_results` used to be `[file isfile <raw>]` and nothing
# more, and the user hit the consequence on the bench: with every analysis
# unticked, `Netlist and Run` wrote a fresh deck, ngspice refused it ("Error:
# incomplete or empty netlist … no simulations run!", exit 1) and left the
# PREVIOUS run's raw untouched on disk. File existence still said "has results",
# so `Results > Annotate` stayed live and annotating painted 08:52's operating
# point onto 08:57's netlist — with nothing on screen to distinguish it from a
# good run. Measured: raw 5m28s OLDER than the deck. Silent wrong data is the
# worst failure this tool has, and file existence cannot see it.
#
# ⚠ THE EXIT CODE CANNOT DO THIS JOB. ase::run_finished does record it, but into
# a SINGLE namespace variable (ase.tcl:61 `variable last_run`) that is neither
# per-session nor persistent — so it is gone the moment xschem restarts, which is
# the case the user hit twice. The evidence has to come off the filesystem.
#
# ⚠ NO DECK -> CURRENT, deliberately. A rundir holding a raw and no deck is a
# saved-results session; there is nothing to contradict the raw, and refusing it
# would break the legitimate "open last week's results and read them" flow that
# Cadence also allows. The test only ever fires when a deck EXISTS and is NEWER.
#
# ⚠ THIS IS NOT A CONTENT CHECK, and must not be mistaken for one. A raw that is
# newer than its deck can still be a well-formed ZERO-POINT file — ngspice writes
# `No. Points: 0` at the start of a run and backfills at the end (issue 0299) —
# and reading one crashes update_op (issue 0836). 0838 guards what is OFFERED;
# 0836 guards what is READ. The two compose and neither replaces the other.
# ASE's own decks `write` the raw from inside .control at the END of the run, so
# the streaming case does not arise on this route; it does on hand-written ones.
# ⚠ IT IS A POSITIVE CLAIM, AND THAT IS WHY IT IS SPELLED "stale" RATHER THAN
# "current". Every arm that cannot JUDGE -- unknown session key, no state, no
# deck on disk, an unreadable mtime -- answers 0, "I have no evidence against
# this raw", never "condemn it". A `current`-shaped predicate has to answer 0 in
# those same cases and 0 there means REFUSE, so it silently conflates "I don't
# know" with "it's stale" -- measured: it made cadence::_annot_raw_candidate
# report `stale` for any session whose state it could not resolve. Two callers
# want opposite defaults from the unknown case and only the positive spelling
# gives both of them what they want:
#
#   has_results        -- last_rawfile has ALREADY answered the existence half,
#                         so an unresolvable session is 0 there regardless;
#   the `6` chord      -- holds a real path from a real session and must not
#                         refuse it on an inability to look up a state dict.
proc ase::results_stale {key} {
  set state [ase::session_state $key]
  if {$state eq {}} { return 0 }
  set rf {}
  if {[catch {ase::last_rawfile $key} rf]} { return 0 }
  if {$rf eq {}} { return 0 }
  set deck [ase::deck_file $state]
  if {$deck eq {} || ![file isfile $deck]} { return 0 }   ;# nothing to contradict it
  set rt 0
  set dt 0
  if {[catch {file mtime $rf} rt]}   { return 0 }
  if {[catch {file mtime $deck} dt]} { return 0 }
  return [expr {$rt < $dt}]
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
# --- casemode item 10, defence (c): CONTENT-BASED REJECTION ------------------
#
# `DECISIONS.md` C3/C4; spec §14.4. The cheapest of the three defences (one
# comparison against `Plotname:`) and the only one that protects a raw file we
# did NOT generate — one from an older xschem, from another tool, or from a run
# that predates the $sim_status guard. It cannot say WHY the file is bad, which
# is why it does not replace the pre-flight.
#
# THE SIGNATURE, measured 2026-08-17 on ngspice-46 and build-ver_50 alike, from
# a deck whose only fault is one `.save` of a node that does not exist:
#
#   Title: Constant values
#   Date: Sun Aug  2 23:29:26 UTC 2026        <- the BUILD stamp, not the run
#   Command: ngspice-46, Build Sun Aug  2 23:29:26 UTC 2026
#   Plotname: constants
#   No. Variables: 12                          <- yes false true boltz c e
#   No. Points: 1                                 echarge i kelvin no pi planck
#
# `Plotname: constants` is decisive ONLY WHILE THE COUNTS AGREE WITH IT; the
# other three markers are recorded in the verdict so the message can show its
# work, and so a future ngspice that renames the plot still trips at least one
# of them.
#
# THE COUNT MAY CONTRADICT THE NAME, NOT ONLY CORROBORATE IT (fix round, item
# 10; RULING, spec §14.4). `let`-created vectors written from the constants
# plot land in a file whose header says `Plotname: constants` and which holds
# real user data — the tree's own
# `doc/claude/ngspice_upstream/feedback/.../repro/letonly.raw` is 14 variables
# over 5 points. Rejecting it wholesale threw away genuine data while asserting
# it "holds ngspice's twelve built-in mathematical constants", which it
# demonstrably does not. More than twelve variables, or more than one point, and
# the file is REPORTED rather than rejected — the same treatment the
# `appendwrite` shape already gets, and the same lean as everywhere else here.
#
# The `set appendwrite` shape C3 names — a constants plot appended BEHIND a real
# one — is detected but NOT rejected: plot 1 is genuine data, and the C reader
# selects a plot by `sim_type`, which `constants` never matches. It is reported.
#
# BOUNDED: the first and last 64 KB only. A raw's plot header is a few hundred
# bytes at the very start, and an appended constants plot is 569 bytes at the
# very end, so both shapes are reachable without reading a 50 MB file on every
# attach. Declared limit: a constants plot buried in the MIDDLE of a
# three-plot file is not seen.
proc ase::raw_head_tail {path {n 65536}} {
  set f [open $path rb]
  set head [read $f $n]
  set size [file size $path]
  set tail {}
  if {$size > $n} {
    seek $f [expr {$size - $n}]
    set tail [read $f $n]
  }
  close $f
  return [list $head $tail $size]
}

# The first plot header in `text`, as a dict of the fields that matter. Empty
# `plotname` means "this does not look like a spice raw at all" — a VCD, a table
# file, garbage — and the caller must then say nothing: judging a format we did
# not parse is how a content check turns into a false rejection.
proc ase::raw_first_header {text} {
  set d [dict create title {} date {} command {} plotname {} nvars {} npoints {}]
  foreach line [split $text "\n"] {
    set line [string trimright $line "\r"]
    if {[regexp {^Title:[ \t]*(.*)$} $line -> v]} {
      if {[dict get $d title] eq {}} { dict set d title [string trim $v] }
    } elseif {[regexp {^Date:[ \t]*(.*)$} $line -> v]} {
      if {[dict get $d date] eq {}} { dict set d date [string trim $v] }
    } elseif {[regexp {^Command:[ \t]*(.*)$} $line -> v]} {
      if {[dict get $d command] eq {}} { dict set d command [string trim $v] }
    } elseif {[regexp {^Plotname:[ \t]*(.*)$} $line -> v]} {
      dict set d plotname [string trim $v]
    } elseif {[regexp {^No\. Variables:[ \t]*(.*)$} $line -> v]} {
      dict set d nvars [string trim $v]
    } elseif {[regexp {^No\. Points:[ \t]*(.*)$} $line -> v]} {
      dict set d npoints [string trim $v]
      break                       ;# the header ends here; Variables/Binary follow
    }
  }
  return $d
}

# -> {ok 0|1  constants 0|1  appended 0|1  plotname .. nvars .. npoints ..
#     signature {..} why <one sentence, or {}>}
proc ase::raw_content_verdict {path} {
  set v [dict create ok 1 constants 0 appended 0 plotname {} nvars {} npoints {} \
                     signature {} why {}]
  if {$path eq {} || ![file isfile $path]} { return $v }
  if {[catch {ase::raw_head_tail $path} ht]} { return $v }
  lassign $ht head tail size
  set h [ase::raw_first_header $head]
  set pn [dict get $h plotname]
  dict set v plotname $pn
  dict set v nvars [dict get $h nvars]
  dict set v npoints [dict get $h npoints]
  if {$pn eq {}} { return $v }                  ;# not a spice raw; say nothing
  # The four markers C3 names. The count is a FLOOR and is only ever
  # corroboration: a legitimate plot can hold twelve vectors, so it is recorded
  # only once a decisive marker (the plot name, or the title ngspice gives the
  # constants plot) has already fired. Otherwise this would print
  # "No. Variables: 2 (the constants plot has 12)" about a perfectly good raw.
  set sig {}
  set nv [dict get $h nvars]
  if {[string equal -nocase $pn constants]} { lappend sig {Plotname: constants} }
  if {[string equal -nocase [dict get $h title] {Constant values}]} {
    lappend sig {Title: Constant values}
  }
  if {[llength $sig]} {
    # the Date is the BUILD stamp, which the Command line repeats verbatim
    if {[regexp {Build[ \t]+(.+)$} [dict get $h command] -> stamp] &&
        [string trim $stamp] eq [dict get $h date] && [dict get $h date] ne {}} {
      lappend sig {Date: == the simulator's own build stamp}
    }
    if {[string is integer -strict $nv] && $nv <= 12} {
      lappend sig "No. Variables: $nv (the constants plot has 12)"
    }
  }
  dict set v signature $sig
  set np [dict get $h npoints]
  if {[string equal -nocase $pn constants]} {
    dict set v constants 1
    set nvi [expr {[string is integer -strict $nv] ? $nv : -1}]
    set npi [expr {[string is integer -strict $np] ? $np : -1}]
    if {$nvi > 12 || $npi > 1} {
      # the counts CONTRADICT the plot name: vectors the constants plot does not
      # have, or more than its single point. Report; do not reject.
      dict set v why "this raw file's first plot is named 'constants' but carries\
 $nv variable(s) over $np point(s) — more than ngspice's twelve built-in\
 constants over one point, so it holds real vectors (the `let`-into-the-constants-plot\
 shape). It is NOT rejected: the extra vectors are data."
      return $v
    }
    dict set v ok 0
    dict set v why "this raw file holds ngspice's twelve built-in mathematical\
 constants, not simulation data — the analysis did not run (typically a .save of\
 a node the circuit does not have). Signature: [join $sig {; }]."
    return $v
  }
  # ⚠ ZERO POINTS IS NOT AN EMPTY RESULT, AND THIS GUARD USED TO SAY IT WAS
  # (the `annotate` merge). `fluid-editing` rejected `np == 0` OR `nv == 0` alike
  # as "an analysis that did not run". MEASURED on `annotate` and written up in
  # issue 0896: ngspice writes `No. Points: 0` at the START of a run and backfills
  # the count when it finishes, so EVERY simulation leaves a well-formed
  # zero-point raw on disk for its whole duration -- and reading it is how the
  # waveform window watches a run fill. Rejecting it made that impossible: the
  # window could not attach a run until the run was over.
  #
  # The same fact is already load-bearing one layer down: update_op()'s zero-point
  # guard (save.c, issue 0836) exists precisely because a zero-point database is
  # the ORDINARY path and used to SIGSEGV there. A guard here that treats it as
  # malformed contradicts a guard there that treats it as normal.
  #
  # ⚠ `nv == 0` STILL REJECTS, and the split is the point. A file with no
  # VARIABLES holds nothing and never will; a file with variables and no points
  # yet holds a run that has not got there. And the case this guard was written
  # for -- a finished analysis that produced nothing, typically a `.save` of a
  # node the circuit does not have -- is caught by the `constants`-plot arm
  # above, which is untouched. The guard is narrower and sharper, not weaker.
  if {[string is integer -strict $nv] && $nv == 0} {
    dict set v ok 0
    dict set v why "this raw file's first plot '$pn' carries no variables at all\
 over $np point(s) — an empty result, which is what an analysis that did not run\
 leaves behind."
    return $v
  }
  if {[string first "Plotname: constants" $tail] >= 0 ||
      [string first "Plotname: constants" $head] >= 0} {
    dict set v appended 1
    dict set v why "a 'constants' plot is appended behind the real data in this\
 file (the `set appendwrite` shape). The real plot is used; the appended one is\
 not simulation data."
  }
  return $v
}

proc ase::attach_dbs {rawfile sim_type {vcdfiles {}}} {
  if {$rawfile eq {} || ![file isfile $rawfile]} {
    return [dict create n 0 current -1 vcds {} skipped $vcdfiles]
  }
  # casemode batch item 10 (C3/C4, defence (c)): a file that LOOKS like a result
  # and is not. Judged BEFORE the registry is touched, so a rejected file leaves
  # the previously loaded database exactly where it was -- "a stale-but-loaded DB
  # beats an empty viewer", the same policy the read-before-clear order below is
  # here to deliver. The verdict says nothing at all about a file it could not
  # parse as a spice raw, so VCD and table databases are unaffected.
  set verdict [ase::raw_content_verdict $rawfile]
  if {![dict get $verdict ok]} {
    ::ase::echo "ase: NOT ATTACHED -- [file tail $rawfile]: [dict get $verdict why]" error
    return [dict create n 0 current -1 vcds {} skipped $vcdfiles \
                        rejected [dict get $verdict why]]
  }
  # An ACCEPTED file can still be worth a word: the `appendwrite` shape, and a
  # 'constants'-named plot whose counts contradict the name (fix round, item 10).
  if {[dict get $verdict why] ne {}} {
    ::ase::echo "ase: [file tail $rawfile]: [dict get $verdict why]" note
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
  # `raw clear <n>` leaves extra_idx at 0 (save.c:2207-2211).
  if {[llength $got]} { catch {xschem raw switch 0} }
  return [dict create n [expr {1 + [llength $got]}] current 0 vcds $got skipped $skipped]
}

# The registry slot indices, and the current one; {} / -1 when nothing is
# loaded. `xschem raw info` prints "<cur> current" then one "<i> <path> <type>"
# line per slot (save.c:2475-2488, what == 4; re-grepped 2026-09-02, item A6)
# and nothing at all with no raw.
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
#
# ⚠ 0691: THE RETURN IS MEASURED, NOT MANUFACTURED. This proc used to end in a
# hardcoded `return 1` after a guarded `dict unset`, so it reported success for
# a key it never held and for a second close of a key it had already dropped
# (measured at HEAD: live=1 second=1 never=1). A witness that cannot fail is not
# a witness — issue 0652's class, the same shape 0679 repaired in
# `ase::ui::save_all_apply` and this pass repaired in
# `ase::ui::do_load_state_from`.
#
# It is INERT today, deliberately recorded as such: the one production caller
# (ase_window.tcl:310, inside `ase::ui::close`) discards the value, and no test
# asserted it before F20a. That is what makes the fix cheap — and what made
# leaving it dangerous, because the next caller to read it would inherit the
# lie. ⚠ `ase::ui::close` now has two guards in a row (its own
# `dict exists $wins` check, then this answer). They are NOT the same predicate
# — a window can be gone while the session is live — so do not wire them
# together.
#
# Returns 1 when a session was dropped, 0 for a key it never held.
proc ase::session_close {key} {
  variable sessions
  if {![dict exists $sessions $key]} { return 0 }
  dict unset sessions $key
  return 1
}

# Is a session registered under this key? The registration predicate the GUI
# layer never had: before this, callers that needed it either poked
# `$::ase::sessions` directly (several suites still do) or inferred it from
# `ase::session_path` returning {} — which is WRONG, because {} is also the
# marker for a registered-but-UNTITLED session (issue 0141). That conflation is
# exactly how `ase::ui::do_save_state_as` came to run its untitled-adopt arm for
# a key nobody was under (0691's weaker second arm). Returns 1 or 0.
proc ase::session_exists {key} {
  variable sessions
  return [expr {[dict exists $sessions $key] ? 1 : 0}]
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

# --- 0683: THE BINDING GUARD ON THE TWO STOCK ANNOTATION ENTRY POINTS ---------
#
# THE USER'S RULING, 2026-08-25, verbatim:
#
#   "Refuse without a bound session. Both stock items check for a live bound
#    session and refuse with a clear message naming the ASE-L path if there is
#    none."
#
# The two items are `Waves > Op Annotate` and
# `Simulation > Graphs > Annotate Operating Point into schematic`
# (src/xschem.tcl). The trade was stated in the question and accepted: stock
# xschem with no ASE-L can no longer annotate at all. This is the entry half of
# the fix ONLY -- a producer-side guard does nothing about a mask that is
# ALREADY on, which is why issue 0688 (the mask now belongs to the loaded ROOT
# sheet, src/actions.c annot_show_set / annot_show_check_root) had to land first.
# Read 0688 section 2 before touching either half.
#
# THE PREDICATE IS `ase::session_for_current` ALONE -- a session bound to this
# design or to one of its ancestors. NOT `session && ase::has_results`: the
# ruling's words are "a live bound session", and `Op Annotate` exists precisely
# to let the user point at ANY raw file through the chooser, so results already
# loaded IN the session are not a precondition for the gesture. The narrower
# predicate also refuses less of a shipped feature, which is the smaller blast
# radius on a user-visible removal.
#
# Returns 1 when the caller may proceed. Returns 0 AFTER speaking the refusal --
# the caller must not add a second message, or issue 0168's one-spelling rule is
# broken by the guard's own users.
proc ase::annot_binding_ok {{menupath {}}} {
  set k {}
  catch {set k [ase::session_for_current]}
  if {$k ne {}} { return 1 }
  ase::annot_no_binding_notice $menupath
  return 0
}

# The refusal itself. ONE sentence: what did not happen, why, and where the
# function lives now.
#
# ⚠ WHY THIS IS A NEW PROC AND NOT `ase::no_session_notice` (~:3036), which is
# the one honest report for "session_for_current found nothing" and which issue
# 0168 says must not acquire a second spelling. Two reasons, and the second is
# the binding one:
#   * DIFFERENT SCOPE. no_session_notice answers "no session for this design".
#     This answers "the menu item you just clicked did not annotate, and here is
#     the item that would" -- it names the CLICKED path, which no_session_notice
#     has no way to know. Same subject, different question; not a second spelling.
#   * IT MUST CARRY R-0653-d's FIELDS. no_session_notice goes through
#     `ase::echo` -> `xschem::notify_safe`, and notify_safe DROPS -menu and
#     -command (issue 0674). A remedy that travels as prose cannot be EXECUTED by
#     a test or pasted by a user, which is the whole of req 1. Giving
#     no_session_notice those fields would change all six of its shipped call
#     sites; adding them here changes none.
#
# ⚠ THE REMEDY IS DERIVED, NEVER TYPED. `annot_remedy_menu` composes it from the
# same two label constants the menubar is BUILT from (src/xschem.tcl), so the
# printed path cannot drift from the widget -- issue 0661 is the measured example
# of that drift, one word apart and entirely plausible. The command is
# `ase::launch_for_current`, which is exactly what `Tools > Launch ASE-L` invokes:
# ciw_exec runs `uplevel #0 $cmd`, so a printed remedy is an executable contract
# and issue 0679 is the precedent for printing one that does not resolve.
#
# ⚠ THE SHORT FORM NAMES ASE-L, AND THAT IS A CONTRACT. Under `--nolog` with no
# CIW the ONLY sink is `.statusbar.12`, which receives the 28-character short
# form and never the rendered sentence (src/ciw.tcl notify_short). A short form
# that did not name ASE-L would reach that user as an unexplained blank, which is
# the state the ruling exists to prevent.
#
# ⚠ CAUGHT, like the other direct `::xschem::notify` site in this file (~:757).
# This is a DIRECT call on the channel, not a delegate call, so notify_safe's
# guarantee does not cover it; issue 0674 is the standing class.
proc ase::annot_no_binding_notice {menupath} {
  set what $menupath
  if {$what eq {}} { set what {annotation} }
  set remedy {}
  catch {set remedy [annot_remedy_menu]}
  catch {
    ::xschem::notify "ASE: $what did not put anything on the schematic. Annotation is driven by ASE-L, and no ASE-L session is bound to this design or to any of its parents." \
      -tag error -short {not annotated: no ASE-L} \
      -menu $remedy -command {ase::launch_for_current}
  }
  return 0
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
    # time (ase::op_cards_capture) and is never rebuilt here. Which SHAPE the
    # request takes is ase::op_save_tier's answer (issue 0963); this switch only
    # renders it. Nothing below re-wraps, sorts or dedupes a card, and every
    # device name still originates in op_annot's own walk (invariant I1).
    #
    # ⚠ THE TWO GATES ABOVE THE SHAPE ARE UNCHANGED, AND THEY ARE WHAT DECIDES
    # WHETHER DEVICE NUMBERS ARE ASKED FOR AT ALL: the user's tick, and an
    # enabled operating point. The shape decides only HOW.
    #
    # ⚠ A DOT-CARD MUST STAY AT DECK LEVEL, ABOVE `.control`, AND A `save`
    # COMMAND MUST STAY INSIDE IT. Inside a .control block a dot-card is
    # `save: no such command available` at rc 0 (op_annot.tcl:2112-2118) and
    # above it a bare `save` is not a card at all — both fail silently. That is
    # why the per-device shape has two arms below and they are not
    # interchangeable.
    #
    # ⚠ THE BLOCK'S OWN `.save all` LEADER IS LOAD-BEARING; DO NOT TIDY IT AWAY
    # AS A DUPLICATE, AND DO NOT MOVE IT INSIDE `.control` (guard G-LEADER,
    # issue 0964). Any explicit `save` cancels ngspice's implicit
    # save-everything (rule R2 / invariant I2), and the `.save all` at :3161
    # above is emitted ONLY when save_all_v is 1 — the schema default is 0.
    # Measured on the committed save_all_v=0 sky130_tests/test_nfet_final
    # state: block WITH the leader -> 13 vectors, 6 device parameters, 5 node
    # v(); block WITHOUT it -> 7 vectors, 6 device parameters, ZERO node v().
    # And measured again when the reorder arm below was built: with the leader
    # moved into `.control` alongside the device requests, a bench carrying
    # per-output `.save <expr>` lines lost every OTHER node voltage from its
    # TRANSIENT — the plot fell from 6 vectors to 2, `time` and the one named
    # output, silently. So every arm below emits the leader at deck level.
    # Two `.save all` lines in one deck were re-measured harmless.
    #
    # ⚠ THE LITERAL THE ARMS BELOW EMIT IS THE BLOCK'S OWN, NOT A SECOND
    # SPELLING OF IT: op_annot::save_cards builds `[linsert $cards 0 {.save
    # all}]` (op_annot.tcl:2611) and returns {} rather than a lone leader for an
    # empty walk, so a non-empty block always begins with exactly that line and
    # always carries at least one card. That is what makes "emit the leader,
    # move the cards" an exact substitution rather than an approximation.
    #
    # ⚠ AND THE NAMES GO THROUGH BARE, IN EVERY SHAPE. `@m.x1.xm4.m<model>[id]`,
    # never `i(@...)` — the wrapper is the READ shape (op_annot::vector), and a
    # wrapped request produces no vector and no diagnostic (rule R4 / spec
    # landmine 1 / issue 0607). That survives the move into `.control`: row E11
    # is what stops a later hand "fixing" the spelling on the way in.
    ## ⚠ 0928: AND THE CONSUMER CHECKS IT TOO, not only the capture. The cache
    ## outlives one netlist -- `ase::run_existing` renders from a block an
    ## EARLIER netlist primed -- so a user who turns the `op` analysis off and
    ## re-runs would otherwise get a deck full of device cards nothing reads,
    ## sampled at every timepoint of whatever analysis is left. The capture-side
    ## guard saves the walk; this one is what makes the deck correct.
    ##
    ## The two carriers below are read by the `.control` block further down.
    ## Empty means "this shape puts nothing there", which is the state every
    ## deck that emits no device requests at all is left in — and that is what
    ## keeps such a deck byte-identical to what it has always been (row E12).
    set optier_write {}
    set optier_ctl {}
    if {[ase::op_gate_on [ase::state_get $state save_op_params {}]] &&
        [ase::op_analysis_enabled $state]} {
      set opblk [ase::op_cards_for $netlist_text]
      if {$opblk ne {}} {
        set optier [dict get [ase::op_save_tier $state] tier]
        lappend lines \
          "* op_annot device operating-point save cards (Outputs > Save All)"
        switch -- $optier {
          a {
            # THE BLANKET SHAPE (issue 0963 tier a): one device-less request,
            # so the deck is the same length for 1 device as for 5000. NO
            # DEVICE IS NAMED ANYWHERE — that is the whole property, and row E1
            # is what holds it. Cold code on every released ngspice, which is
            # why a stand-in that claims the capability exercises it.
            #
            # ⚠ IT ASKS THE SHAPE THE PROBE MEASURED, AND IT ASKS IT INSIDE
            # THE RUN (issues 0966 and 0968). What a reader would otherwise
            # assume is that a blanket capability is best spent on a blanket
            # request. Two things say otherwise, and both were measured:
            #   * the probe's question is `save @<device>[<wildcard>]` — see
            #     ase::cap_param_wildcard — so a device-less request is an
            #     answer to a question nobody asked, and the YES it leans on
            #     was never about it;
            #   * a dot-card applies to EVERY analysis in the deck and cannot
            #     be scoped to one, which is issue 0928 section 7 exactly: the
            #     device numbers get recorded at every time point of the
            #     transient, where nothing reads them. On the user's own
            #     tb_bandgap that was +74.9 MB and +4.08 s.
            # So the requests go in `optier_ctl`, which the analysis loop below
            # emits immediately before `op` — and filling it is also what turns
            # on the 0964 reorder that keeps `op` last. Rows E14, E16 and E18.
            #
            # STILL O(devices) AND NOT O(devices x parameters): one entry per
            # device, whatever its parameter count. On tb_bandgap that is 78
            # entries against 468 cards.
            lappend lines ".save all"
            set optier_ctl [ase::op_ctl_saves [ase::op_cards_wildcards $opblk]]
          }
          b {
            # THE ONE-LINE SHAPE (issue 0963 tier b): no cards at all here, and
            # each device named ONCE — with no parameter — on the
            # OPERATING-POINT write line built further down. MEASURED: naming a
            # bare device on a write line dumps ALL of that device's parameters,
            # 75 for a level-1 MOS and 89 for BSIM4, so this is O(devices) and
            # not O(devices x parameters).
            #
            # ⚠ THE OPERATING-POINT WRITE AND NOTHING ELSE. MEASURED: the same
            # bare name on a `.tran` or `.dc` write is SILENTLY WRONG — every
            # device vector arrives dims=1 with one non-zero sample parked at
            # index 0 holding the end-of-run value and 0.0 at all 208 remaining
            # points, no warning, well-formed file. It round-trips exactly under
            # `op` alone. Rows E5 and M1 are what stop the line being moved.
            #
            # ⚠ NOTHING SELECTS THIS AUTOMATICALLY (guard G4). See
            # ase::op_save_tier for the measurement: one unresolvable device
            # name throws the ENTIRE operating point away at exit 0.
            lappend lines ".save all"
            set optier_write [ase::op_cards_devices $opblk]
          }
          default {
            if {[ase::n_enabled_analyses $state] > 1} {
              # THE PER-DEVICE SHAPE, WITH ANOTHER ANALYSIS IN THE SAME RUN
              # (issue 0964, which is issue 0928 section 7). A deck-level
              # `.save` applies to EVERY analysis, so today's cards are
              # recorded at every time point of the transient, where nothing
              # reads them. MEASURED on the user's own tb_bandgap: +74.9 MB of
              # results file (144,455,860 against 69,595,016) and +4.08 s of
              # wall clock, for 456 device vectors whose operating-point copy
              # occupies one point and about 3.6 KB.
              #
              # ⚠ THE REQUESTS MOVE INSIDE `.control` AND THE OPERATING POINT
              # MOVES LAST, and BOTH halves are needed. MEASURED: `unsave` does
              # not exist in ngspice and a later `save all` does not reset the
              # list, so the save list is sticky forward-only — asking inside
              # `.control` but leaving `op` first would put the requests right
              # back onto every analysis that follows it. The reorder is in the
              # analysis loop below, keyed on this list being non-empty.
              lappend lines ".save all"
              set optier_ctl [ase::op_ctl_saves [ase::op_cards_names $opblk]]
            } else {
              # THE PER-DEVICE SHAPE ON ITS OWN. Nothing else runs, so nothing
              # can ride along: the block goes through EXACTLY as it always
              # has, byte for byte, leader included (row E8).
              foreach opl [split [string trimright $opblk "\n"] "\n"] {
                lappend lines $opl
              }
            }
          }
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
    # --- 0929: ONE `write` PER ANALYSIS, NOT ONE PER RUN ----------------------
    # ngspice's `write` writes the CURRENT plot, and every analysis makes a new
    # one. A single trailing `write` therefore stored ONLY the last analysis and
    # silently discarded every earlier one. On the user's own tb_bandgap -- op
    # AND tran both enabled, 468 device OP save cards emitted, run exit 0 -- the
    # raw came back holding one plot, `Transient Analysis`, and pressing `6` said
    # "No operating point results are loaded. These are from a 'tran' run
    # instead." The operating point had been computed and thrown away.
    #
    # `set appendwrite` makes each `write` APPEND its plot to the file instead of
    # truncating it, so one raw carries `Operating Point` then `Transient
    # Analysis` (MEASURED, ngspice-46+). No reader change is needed:
    # `xschem raw read <file> op` already picks the operating-point plot out of a
    # multi-plot raw and `... tran` picks the transient one (MEASURED against
    # this very tree).
    #
    # ⚠ APPEND MEANS THE FILE MUST NOT PRE-EXIST. ase::run_deck deletes it before
    # the run for exactly this reason -- without that, every run's plots pile up
    # on the previous run's and `6` annotates whichever stale operating point
    # happens to come first. See the deletion beside cosim_clear_artifacts.
    if {[ase::n_enabled_analyses $state] > 0} { lappend lines "set appendwrite" }
    # --- 0964: THE OPERATING POINT RUNS LAST WHEN ITS REQUESTS MOVED IN ------
    # The emit order is normally the fixed `op dc ac tran` this block has always
    # used, and every deck that carries no in-`.control` device requests renders
    # byte-identically (row E12, and it is what keeps test_ase_core's committed
    # deck goldens green with nobody editing them).
    #
    # ⚠ THE ONE EXCEPTION IS NOT COSMETIC AND IS NOT REORDERABLE BY TASTE. When
    # the per-device requests moved inside `.control` (issue 0964), they are
    # asked for immediately before `op` — and ngspice's save list is sticky
    # FORWARD ONLY: `unsave` does not exist and a later `save all` does not
    # reset it (both measured, ngspice-46+). So `op` must be the LAST analysis
    # or every analysis after it records the device numbers again, which is the
    # 74.9 MB this change exists to delete.
    #
    # ⚠ AND `ase::plot_sim_type` NO LONGER MIRRORS THIS ORDER. Its own comment
    # used to say it must, forever; read the one there before changing either.
    # Both readers pick their plot BY NAME out of the multi-plot results file,
    # so nothing downstream depends on which analysis ran last.
    set anorder {op dc ac tran}
    # --- 0967: WHERE THE PRINTED OUTPUTS SIT IS NOT THE REORDER'S TO DECIDE --
    # `print` reads whichever plot the simulator is standing in, and these lines
    # used to sit after every analysis -- so before the 0964 reorder above they
    # read the LAST analysis of `op dc ac tran`, and after it they would have
    # read the operating point instead. The Outputs pane's Value column is filled
    # from them (see result_probe), so ticking a box about DEVICE numbers would
    # have changed which analysis that column reports, with nothing said. That is
    # ruling D5-1's class, and the tick that caused it is about something else
    # entirely.
    #
    # So the anchor is computed from the ENABLED SET alone and the emit order
    # cannot move it. WHICH analysis it picks is issue 1243's ruling, below --
    # 0967 only established that a checkbox about device parameters does not get
    # to answer that question. Rows P1/P2/P3 of
    # tests/headless/test_ase_optier_0963.tcl.
    set printlines {}
    foreach o [ase::state_get $state outputs] {
      if {[ase::state_get $o save 0] eq {1}} {
        lappend printlines "print [ase::backend::ngspice::print_arg [dict get $o expr]]"
      }
    }
    # --- 1243: THE PRINTS GO WITH THE OPERATING POINT WHEN THERE IS ONE -----
    # RULED BY THE USER 2026-09-02, on their own tb_bandgap: "in the ASE-L
    # output pane, nothing is displayed for values if both OP and TRAN are
    # enabled, whereas, if only OP is enabled, then values are displayed after
    # simulation."
    #
    # ⚠ THIS IS THE RULING ISSUE 0967 DEFERRED, and section P of
    # tests/headless/test_ase_optier_0963.tcl said so in as many words: "0967 IS
    # NOT BEING SETTLED HERE. Which analysis the Outputs Value column reads is
    # the user's ruling to make." 0967 measured the two candidate answers and
    # chose neither; it only froze the answer against an unrelated checkbox. The
    # deferred half is settled here, and the rows in section P now pin the
    # ruling rather than the freeze.
    #
    # WHY THE OPERATING POINT AND NOT "THE LAST ANALYSIS". The Value column is a
    # SCALAR column: `result_probe` accepts `<expr> = <number>` and nothing else,
    # and `print` reads whichever plot the simulator is standing in. On a
    # multi-point plot `print VBG` emits a paged `Index time vbg` TABLE, so the
    # column has never had a value to show for a transient -- measured on the
    # user's own run log, 20,514 rows per printed output and 108,275 log lines
    # for five of them, from which `result_probe` extracts exactly nothing. The
    # operating point is the only analysis in the set that yields a scalar, so
    # "prefer the last analysis" was preferring the one answer that cannot be
    # read.
    #
    # ⚠ NOTHING DISPLAYED CHANGES VALUE, and that is what keeps this clear of
    # ruling D5-1. With op+tran the column was EMPTY before this line, so no
    # number is being replaced by a differently-measured one; a number appears
    # where there was none, and it is the operating point's. Side effect,
    # measured on the same bench: the run log loses those ~102,000 table rows.
    #
    # THE ORDER BELOW IS THE ANCHOR'S, NOT THE EMIT ORDER'S. It is the canonical
    # `op dc ac tran` with `op` moved to the END so that last-enabled-wins picks
    # it whenever it is enabled. With the operating point OFF the two orders
    # select the same analysis, so every op-less deck -- transient-only included
    # -- renders byte-identically and its Value column stays exactly as empty or
    # as full as it was.
    #
    # ⚠ TRANSIENT-ONLY IS STILL BLANK, deliberately and on the ledger. What a
    # scalar column should show for a waveform (the final point? t=0? nothing?)
    # is a separate ruling, recorded as a `rule` debt rather than guessed at
    # here -- guessing would put an unlabelled number beside a row, which is the
    # defect 0967 was filed about.
    set printanchor {}
    foreach type {dc ac tran op} {
      set ai -1
      foreach a [ase::state_get $state analyses] {
        incr ai
        if {[ase::state_get $a type] ne $type} { continue }
        if {[ase::state_get $a enabled 0] ne {1}} { continue }
        set printanchor [list $type $ai]
      }
    }
    set printsdone 0
    if {[llength $optier_ctl]} { set anorder {dc ac tran op} }
    foreach type $anorder {
      set ai -1
      foreach a [ase::state_get $state analyses] {
        incr ai
        if {[ase::state_get $a type] ne $type} { continue }
        if {[ase::state_get $a enabled 0] ne {1}} { continue }
        # 0964: the device requests, immediately before the analysis that is
        # the only one able to use them. A `save` COMMAND, not a dot-card:
        # dot-cards are not commands in here (see the shape switch above).
        if {$type eq {op}} {
          foreach opsl $optier_ctl { lappend lines $opsl }
        }
        switch -- $type {
          op   { lappend lines "op" }
          dc   { lappend lines "dc [dict get $a source] [dict get $a start]\
 [dict get $a stop] [dict get $a step]" }
          ac   { lappend lines "ac dec [dict get $a points] [dict get $a start]\
 [dict get $a stop]" }
          tran { lappend lines "tran [dict get $a step] [dict get $a stop]" }
        }
        # casemode item 10, defence (b), from `fluid-editing`: after EVERY
        # analysis, never once at the end -- $sim_status is last-writer-wins per
        # analysis (C4). Measured with a failing `dc` followed by a good `tran`:
        # one guard at the end -> rc=0 and a 2198-byte raw written, the failure
        # completely masked; a guard after each -> rc=1, RUN-FAILED, no file.
        #
        # ⚠ IT PRECEDES THE WRITE BLOCK BELOW, AND THAT IS THE WHOLE POINT. The
        # guard's job is to `quit 1` before a failed analysis can put a plot into
        # the results file; placed after the write it would report the failure and
        # ship the bad raw anyway, which is the defect it was written against.
        foreach g [::ase::backend::ngspice::sim_status_guard] { lappend lines $g }
        # `remzerovec` before every write, not once at the end: `.options
        # savecurrents` leaves zero-length @m...[ib]-class vectors in the plot
        # and ngspice's write then aborts SILENTLY (probe-verified, ngspice-42).
        # It is per-PLOT, so one call at the end would only ever have cleaned
        # the last analysis's.
        lappend lines "remzerovec"
        # 0963 tier b: the device names ride THIS write and no other. A bare
        # `@dev` on a multi-point write is silently wrong -- dims=1, one
        # non-zero sample parked at index 0, 0.0 everywhere else, no warning.
        # Rows E5 and M1 fail if this condition is loosened.
        if {$type eq {op} && [llength $optier_write]} {
          lappend lines "write [raw_file $state] all [join $optier_write { }]"
        } else {
          lappend lines "write [raw_file $state]"
        }
        # 0967: the printed outputs sit with the analysis they have always read.
        if {[list $type $ai] eq $printanchor} {
          foreach pl $printlines { lappend lines $pl }
          set printsdone 1
        }
      }
    }
    # A deck with no enabled analysis at all still carries its print lines, in
    # the one place there is for them -- exactly where they were before.
    if {!$printsdone} {
      foreach pl $printlines { lappend lines $pl }
    }
    # waveform-viewer raw artifact (item 11 D3): with a .control block,
    # ngspice's `-b -r <file>` is DEAD (re-probed 2026-08-29: with a .control
    # block and no explicit `write`, `-r` produces NO raw file at all), so the
    # writes are emitted explicitly — see the per-analysis block above, which
    # replaced the single trailing `write` this comment used to describe.
    lappend lines ".endc"
    lappend lines ".end"
    return "[join $lines "\n"]\n"
  }

  # Batch invocation arg list. 2>@1 folds stderr warnings into the captured
  # log; stdout must flow into execute(data,$id), so no -o here.
  #
  # ISSUE 0931: argv0 is no longer the hardcoded word `ngspice`. It is
  # whatever ase::sim_status says will actually start -- a simulator the user
  # registered, or the program on their PATH when they registered none. This
  # is the single resolution: the string built here is both what `execute`
  # launches and what the run log records as the command, so the two cannot
  # disagree.
  #
  # IT REFUSES RATHER THAN FALLING BACK. When the simulator the user chose
  # cannot be started -- deleted, or no longer marked runnable -- quietly
  # launching a different program and mentioning it in a pane they may not be
  # reading is the same defect as putting an unmeasured number on a
  # schematic. The `why` sentence is minted by ase::sim_why and rendered here.
  #
  # ============ THE `fluid-editing` MERGE: THE CASE-MODE HALF ================
  #
  # Word order, which now mirrors the capability probe's (ase::sim_probe_argv)
  # so the measurement describes the run:
  #
  #   <exe> -b <registry args...> [-n] [-D casemode=<mode>] <deckpath> 2>@1
  #
  #   exe    the in-force registry entry's program, resolved by ase::sim_status.
  #          `fluid-editing` resolved this through a `sim()` PROFILE ROW
  #          instead; that layer is gone -- one record now carries the program,
  #          its args, its requested case mode and its `-n` flag together, so
  #          there is no way for "which binary" and "how it treats case" to be
  #          answers about two different programs.
  #   args   the entry's own args, run-filtered by ase::run_filter_args:
  #          exec-syntax redirections and pipelines out, and `-o`/`--output`
  #          with them because they take away the stdout ASE-L parses. `-r`,
  #          `--rawfile`, `--soa-log` and every other option are KEPT.
  #          ⚠ ase::sim_probe_safe_args is the PROBE filter, drops `-r` too, and
  #          is deliberately NOT used here. Anything dropped is REPORTED by
  #          ase::run_precheck, never silent.
  #   -n     ngspice's `--no-spiceinit`, OFF BY DEFAULT and only when the entry
  #          asks for it. A2's whole point is to probe with the real argv and
  #          run in whatever mode came back, rather than suppressing
  #          `.spiceinit` and pretending.
  #   -D     only for a request that is not `fold` (ase::run_casemode_flag).
  #
  # ⚠ `-b` MOVED, AND IT MOVES annotate's COMMITTED COMMAND GOLDENS BY ONE
  # TOKEN. 0931 appended `-b` after the user's args so that a user who
  # registered nothing got a byte-identical command; `fluid-editing` puts it
  # first so the run and the probe compose their argv the same way. The probe's
  # ordering wins, because a probe that measures a differently-shaped command
  # from the one that runs is measuring the wrong thing -- which is the class of
  # defect the whole case-mode batch exists to close. The goldens are
  # re-baselined, deliberately, and this paragraph is the reason.
  proc run_cmd {state deckpath} {
    set s [ase::sim_status ngspice]
    if {![dict get $s ok]} {
      return -code error "ase: [dict get $s why]"
    }
    if {[dict get $s why] ne {}} {
      ase::echo "ase: [dict get $s why]" error
    }
    set cmd [list [dict get $s exe] -b]
    # ⚠ run_safe_args, NOT run_filter_args. The latter returns the REPORT --
    # `{keep {...} drop {...}}` -- which ase::run_precheck reads to tell the user
    # what it removed. Splicing it here put the literal words `keep` and `drop`
    # onto the simulator's command line; measured during the merge, and F3-shaped
    # checks ("the -o was dropped") still passed while it did.
    foreach a [ase::run_safe_args [dict get $s args]] { lappend cmd $a }
    if {[ase::sim_nospiceinit ngspice]} { lappend cmd -n }
    foreach w [ase::run_casemode_flag $state] { lappend cmd $w }
    lappend cmd $deckpath 2>@1
    return $cmd
  }

  # DEFENCE (b) -- casemode batch item 10, DECISIONS.md C4. The lines that go
  # into the .control block after EVERY analysis.
  #
  # MEASURED 2026-08-17, both binaries (/usr/local/bin/ngspice 46 and
  # build-ver_50), in this deck's own shape:
  #
  #   bad run  (.save of a node that does not exist)  -> rc=1, `RUN-FAILED` on
  #                                                      stdout, and NO FILE AT
  #                                                      ALL where the 569-byte
  #                                                      constants raw used to be
  #   good run                                        -> rc=0, the real raw
  #
  # Two traps, both C4's, both re-measured here:
  #
  #  * `$sim_status` DOES NOT EXIST before the first analysis, and on a build
  #    that has no such variable at all defence (b) is INERT. The `$?` test is
  #    the MARKER that says so: `NO-SIM-STATUS` in the log means this run was
  #    protected by (a) and (c) only.
  #    IT IS NOT AN ERROR SUPPRESSOR, and an earlier revision of this comment
  #    said it was. Re-measured 2026-08-17 on ngspice-46, guard alone in a
  #    .control block with no analysis before it: `Error: sim_status: no such
  #    variable.` is printed at PARSE time, with the `$?` block present
  #    (rc=1, log line 1) exactly as without it. Byte-identical logs but for the
  #    `NO-SIM-STATUS` line. render_deck never emits that shape anyway --
  #    no analysis, no guard (PF218e) -- so the guard as shipped is only ever
  #    parsed in a deck where an analysis precedes it.
  #  * it is LAST-WRITER-WINS PER ANALYSIS, so ONE guard at the end is the
  #    defect, not the fix. Measured with a failing `dc` followed by a good
  #    `tran`: guard only at the end -> rc=0 and a 2198-byte raw written, the
  #    failure completely masked; guard after each -> rc=1, RUN-FAILED, no file.
  #
  # `echo`, not a comment: the words are what ase::run_diagnostics-class readers
  # and a human reading the log actually see. The deck shape itself is untouched
  # otherwise -- no dot card, no `run`, and the `write` line still names no
  # vectors (upstream 0073; CREW_BRIEF §4).
  proc sim_status_guard {} {
    return [list \
      {if $?sim_status = 0} \
      {  echo NO-SIM-STATUS} \
      {end} \
      {if $sim_status ne 0} \
      {  echo RUN-FAILED} \
      {  quit 1} \
      {end}]
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
  #
  # CASE (casemode batch item 11; spec doc/claude/specs/simulator_profiles.md
  # §15). `print` does NOT always echo the spelling it was given: measured today
  # on this tree, a deck whose net is drawn `In` and whose card says
  # `print v(In)` echoes `v(in) = 3.000000e+00` on every folding binary
  # (`/usr/local/bin/ngspice`, and build-ver_50 under `-D casemode=fold`),
  # while build-ver_50 under `-D casemode=preserve` echoes `v(In)` (PLAN §F3).
  # A literal match therefore silently leaves the Outputs pane's Value column
  # EMPTY for every mixed-case expression whenever the run folded and the
  # expression did not -- B4's run-and-report path (requested `preserve`,
  # measured `fold`), and equally a `fold` run whose expression came from
  # anywhere other than item 9's pick path (the Add/Edit Output dialog stores
  # what was typed, ase_window.tcl output_editor_ok; a hand-written state file
  # stores what it says).
  #
  # So the match is a LADDER, the same shape every other lookup in this batch
  # uses (item 2's get_raw_index, item 5's resolve_signal_db):
  #
  #   1. the expression's own spelling, first-wins -- unchanged, and it is what
  #      answers under `fold` (both sides folded) and delivered `preserve`
  #      (both sides case-kept);
  #   2. a case-insensitive pass, WHICH DECLINES TO GUESS when the log offers
  #      more than one differently-cased label for it (DECISIONS.md D2's
  #      no-alias-on-collision rule: `v(EN)` binding to `v(en) = ...` is a wrong
  #      number in a Value column, which is worse than an empty one).
  #
  # Rung 2 is OFF under `distinguish`, and that is not caution, it is measured:
  # there `print v(in)` against a design that only has `In` prints NOTHING
  # (a checkvalid warning), so an ungated rung 2 hands the `v(in)` row the
  # `v(In) = 3.000000e+00` line sitting beside it -- a number for a signal the
  # simulator just said it does not have. That mode's contract is byte-exact
  # (item 2 suppresses its own folded rung on a case_sensitive database for the
  # same reason), and item 8 refuses a `distinguish` run that is not confirmed
  # to be delivered, so nothing is lost by being strict here.
  #
  # The mode is the RUN'S REQUEST (item 9 §13.4's ruling), asked in item 9's
  # READ-ONLY form (`init 0`): a probe is a question, and `::set_sim_defaults`
  # is not a read. Resolved once per log, not once per output row.
  #
  # ...BUT THE REQUEST IS ONLY THE FLOOR, because the request is not what the
  # binary did (spec §15.4b). `~/.spiceinit` overrides `-D casemode=` (CREW_BRIEF
  # §4), and item 7's capability probe / item 8's mismatch report only run for a
  # request that is NOT `fold` (§12.6), so a plain `fold` run against a
  # `set casemode=distinguish` init file is measured by nobody. Measured today
  # on build-ver_50: that run answers `print v(in)` on a design that only has
  # `In` with `Warning: no vector named 'in'; 'In' differs only in case
  # (casemode=distinguish)` and NO value line, while `v(In) = 3.000000e+00`
  # prints two lines away -- so a request-gated rung 2 hands the `v(in)` row
  # the number belonging to a signal the simulator explicitly refused it.
  # The log ANNOUNCES the delivery, so read it: a distinguish banner or a
  # differs-only-in-case warning forces the strict path regardless of the
  # request. A false positive costs an empty Value cell, which is exactly the
  # pre-item-11 behaviour -- the safe direction (§14.2's over-approximate rule).
  #
  # The KEY is untouched by all of this: `name` when the row has one, else the
  # `expr` exactly as stored. Only the MATCH is case-blind -- fold the key and a
  # named row's value lands where ase::ui::output_result_key will not look.
  proc result_probe {state logtext} {
    set results [dict create]
    set mode fold
    catch {set mode [ase::sim_casemode_requested \
                      [ase::state_get $state simulator ngspice]]}
    if {$mode eq {}} { set mode fold }
    # what the run DELIVERED outranks what it asked for, in the strict
    # direction only. Announced once per log, because a request that did not
    # survive contact with the simulator is exactly the surprise a user cannot
    # otherwise see: a requested `distinguish` says nothing new and stays quiet.
    if {$mode ne {distinguish} && [regexp -nocase \
          {casemode[ =]'?distinguish|differs only in case} $logtext]} {
      ::ase::echo "ase: result -- this log says the simulator ran with\
 casemode=distinguish although the run asked for '$mode', so output\
 expressions are matched case-sensitively: a row whose spelling the simulator\
 refused gets no value rather than a differently-cased one." note
      set mode distinguish
    }
    foreach o [ase::state_get $state outputs] {
      if {![dict exists $o expr]} { continue }
      set ex [dict get $o expr]
      set rkey $ex
      if {[dict exists $o name] && [dict get $o name] ne {}} {
        set rkey [dict get $o name]
      }
      # every non-word character backslash-escaped, so the parentheses and
      # brackets of `v(In)` / `"a[0]"` are literals and not regexp syntax; the
      # label is captured so rung 2 can see WHICH spelling it matched
      regsub -all {\W} $ex {\\&} esc
      set pat [format {^\s*"?(%s)"?\s*=\s*([-+]?[0-9.]+(?:[eE][-+]?[0-9]+)?)\s*$} $esc]
      if {[regexp -line $pat $logtext -> lbl val]} {
        dict set results $rkey $val
        continue
      }
      if {$mode eq {distinguish}} { continue }
      set labels {}
      foreach {whole lbl val} [regexp -all -inline -line -nocase $pat $logtext] {
        if {[lsearch -exact $labels $lbl] < 0} { lappend labels $lbl }
      }
      if {![llength $labels]} { continue }
      if {[llength $labels] > 1} {
        # D2: decline, and SAY SO. An empty Value cell with no explanation is
        # the defect this item exists to remove; replacing it with a silently
        # arbitrary number would be a worse one.
        ::ase::echo "ase: result -- output '$ex' matches [llength $labels]\
 log labels that differ only in case ([join [lsort $labels] {, }]), so no\
 value is recorded for it: which one it means cannot be known, and a guess\
 would put a wrong number in the Outputs pane." error
        continue
      }
      # exactly one spelling on offer -- take its FIRST line, as rung 1 does
      regexp -line -nocase $pat $logtext -> lbl val
      dict set results $rkey $val
    }
    return $results
  }

  # WHAT THIS BUILD OF NGSPICE CAN ACTUALLY DO (issue 0948). Two probe runs of
  # a PDK-free circuit -- a level-1 MOS transistor two subcircuits deep, so
  # nothing on the user's machine has to be installed for this to work -- and
  # every answer read out of the results file the deck itself asked for.
  #
  # TWO DECKS, NOT ONE, AND THAT IS A CONTRACT. Deck A asks for an operating
  # point AND a transient with the add-each-analysis line set, so the shape of
  # its results file answers whether this build honours it. Deck B asks for
  # every parameter of one device at once, which is a different question with
  # a different right answer, and merging them would make each unreadable.
  #
  # ⚠ NOT ONE VERDICT COMES FROM THE EXIT CODE OR THE LOG. Measured on this
  # box: deck B's shape exits 0, writes a results file, and logs no warning
  # and no error, while holding no operating point at all. The exit codes are
  # collected for a bug report and used for nothing.
  #
  # ⚠ THE PROBE NEVER DELETES A RESULTS FILE AND NEVER BELIEVES ONE IT DID NOT
  # SEE APPEAR (issue 0951). It used to do the opposite -- delete two fixed
  # names at the top and trust whatever was sitting there afterwards -- and a
  # program that wrote not one byte was reported healthy because a separate
  # process dropped its own results at one of those names mid-probe.
  # ase::cap_workdir now hands this proc a place of its own, and ase::cap_claim
  # / ase::cap_result are the second guard for a caller that hands it a place
  # somebody else is already using.
  #
  # ⚠ THE DECK NAMES ITS RESULTS WITH A BARE FILE NAME, and the program is run
  # with `workdir` under it (issue 0949). An absolute name on the `write` line
  # is what made a simulation folder with a space -- or a dollar, a quote or a
  # semicolon -- in its name produce no results at all from a perfectly healthy
  # ngspice, which was then reported to the user as not being a circuit
  # simulator. No quoting form inside the deck fixes it; see ase::cap_run.
  #
  # `set filetype=ascii` is asked for because a text results file cannot be
  # misread; measured on ngspice-46+, it still appends every analysis. A build
  # free to ignore it is still read correctly -- ase::cap_raw_plots reads both
  # shapes.
  proc capabilities {exe exeargs workdir} {
    set ckt "* ase capability probe (issue 0948): PDK-free, level-1 MOS,\
 two hierarchy levels deep
.model nm1 nmos level=1 vto=0.7 kp=100u
.subckt inner d g s
m1 d g s s nm1 w=1u l=1u
.ends
.subckt outer d g s
xi1 d g s inner
.ends
vdd dd 0 1.8
vg gg 0 1.2
xo1 dd gg 0 outer
"
    set rawa [file join $workdir probe_a.raw]
    set rawb [file join $workdir probe_b.raw]
    set decka [file join $workdir probe_a.sp]
    set deckb [file join $workdir probe_b.sp]
    set usable 0
    set appendwrite 0
    set hier 0
    set blanket 0
    set f [open $decka w]
    puts -nonewline $f "$ckt.control
set filetype=ascii
save @m.xo1.xi1.m1\[id\] @m.xo1.xi1.m1\[gm\] @m.xo1.xi1.m1\[vdsat\]
set appendwrite
op
remzerovec
write probe_a.raw
tran 1n 5n
remzerovec
write probe_a.raw
.endc
.end
"
    close $f
    set f [open $deckb w]
    puts -nonewline $f "$ckt.control
set filetype=ascii
save @m.xo1.xi1.m1[ase::cap_param_wildcard]
op
remzerovec
write probe_b.raw
.endc
.end
"
    close $f
    # ONE BUDGET FOR THE WHOLE MEASUREMENT, NOT ONE PER RUN (issue 0953). The
    # measured 20.0 s freeze of the user's Run gesture was two runs each paying
    # a ten-second cap that nothing could ask to be smaller. And once one run
    # has been cut off, the second is NOT attempted: nothing more can be
    # learned from a program that is not answering, and the user is already
    # waiting.
    #
    # A CUT-OFF MAKES THE WHOLE ANSWER `known 0`, DELIBERATELY. Keeping the
    # half that was measured would mean either claiming 0 about a question
    # nobody asked -- ruling D5-1's shape -- or handing every reader a known-1
    # answer with keys missing from it, which this section's own contract
    # forbids. `secs` is how long the user actually waited, so the sentence can
    # say it.
    set t0 [clock milliseconds]
    set ca [ase::cap_claim $rawa]
    set ra [ase::cap_run $exe [concat $exeargs [list -b $decka]] $workdir \
              [ase::cap_left $t0]]
    if {[lindex $ra 2]} {
      return [dict create known 0 unmeasured timeout \
                secs [ase::cap_spent $t0]]
    }
    set cb [ase::cap_claim $rawb]
    set rb [ase::cap_run $exe [concat $exeargs [list -b $deckb]] $workdir \
              [ase::cap_left $t0]]
    if {[lindex $rb 2]} {
      return [dict create known 0 unmeasured timeout \
                secs [ase::cap_spent $t0]]
    }
    set pa [ase::cap_result $rawa $ca]
    set pb [ase::cap_result $rawb $cb]
    # USABLE: did anything with data in it come back at all, from either run.
    # A program that produced no plot with a single data point in it is not
    # simulating this circuit, whatever it printed and whatever it exited.
    foreach pl [concat $pa $pb] {
      if {[lindex $pl 1] >= 1} { set usable 1 }
    }
    set op [ase::cap_plot $pa {Operating Point}]
    # APPENDWRITE: DID THE SECOND WRITE ADD TO THE FILE, OR REPLACE IT. Deck A
    # asks for two analyses and two writes into one file; two plots coming back
    # in that one file means they were added, whatever the plots are called.
    #
    # ⚠ THIS USED TO BE DECIDED BY WHETHER THE VECTORS THE PROBE EXPECTED WERE
    # FOUND UNDER THE NAMES IT EXPECTED, AND THAT WAS ISSUE 0952. What a reader
    # would otherwise assume is that a missing operating point means an
    # analysis was thrown away. It does not: a build that adds every analysis
    # correctly but spells its device parameters differently saves no vector
    # this probe named, so its operating point degenerates to a `constants`
    # plot -- and the measured file plainly held TWO plots. The user was told
    # their build "keeps only the last analysis" and advised to run one
    # analysis at a time, which is a wrong diagnosis AND advice that changes
    # nothing. Whether the writes added up, and whether the device parameter
    # names are the ones this tree reads, are two different questions and
    # neither may be allowed to fail the other.
    set appendwrite [expr {[llength $pa] >= 2 ? 1 : 0}]
    # HIER_OP_NAMES: the device is INSIDE two subcircuits, and its numbers
    # have to arrive under the exact names this tree's annotation reader
    # builds -- the three spellings op_annot::_wrap emits, at
    # src/op_annot.tcl:419-425. A build that answers with flat names has an
    # operating point that this tree cannot read a single device out of.
    #
    # THE POINT COUNT MOVED HERE FROM APPENDWRITE, AND IT IS NOT A FORMALITY:
    # measured, a blanket save leaves a results file whose plot carries
    # `No. Points: 0`, and an operating point with no data points in it holds
    # no device numbers for anyone to read. This is the key that owns that
    # claim; letting it answer the append question is what produced 0952.
    if {$op ne {} && [lindex $op 1] >= 1} {
      set hier 1
      foreach want {i(@m.xo1.xi1.m1[id]) @m.xo1.xi1.m1[gm]
                    v(@m.xo1.xi1.m1[vdsat])} {
        if {[lsearch -exact [lindex $op 2] $want] < 0} { set hier 0 }
      }
    }
    # BLANKET_OP_SAVE: can one card save every parameter of a device at once.
    # NO RELEASED NGSPICE CAN, and this probe must keep answering that
    # honestly rather than by assumption -- measured here, the run exits 0 and
    # writes a file holding only a `constants` plot.
    set bop [ase::cap_plot $pb {Operating Point}]
    if {$bop ne {} && [lindex $bop 1] >= 1} {
      foreach nm [lindex $bop 2] {
        if {[string first {@m.xo1.xi1.m1[} $nm] >= 0} { set blanket 1 }
      }
    }
    # ---- CASE MODE: THE THIRD MEASUREMENT, from `fluid-editing` --------------
    #
    # WHICH CASE MODES THIS BUILD CAN ACTUALLY DELIVER. It is the same kind of
    # question as the three above -- what can the program that will really start
    # do -- so it is answered in the same place, out of the same budget, and
    # cached and invalidated by the same machinery. `fluid-editing` asked it
    # from a dialog and stored the answer on a `sim()` profile row that nothing
    # invalidated; here ase::sim_caps_clear expires it on every registry edit
    # and ase::cap_stamp expires it when the binary itself changes.
    #
    # ⚠ EACH MODE IS PROBED SEPARATELY AND THAT IS NOT WASTE. `$curcasemode`
    # reports the CURRENT mode, never the supported SET, so "the variable
    # exists, therefore all three work" is an inference -- and a measured-false
    # one: a wrong-case KEY (`-D CaseMode=`) leaves `$curcasemode` at `fold`
    # SILENTLY because it is a different variable, while a wrong-case VALUE
    # (`=PRESERVE`) works. Only a request-versus-answer comparison catches that.
    # Measured cost ~65 ms for all three on build-ver_50.
    #
    # ⚠ THE KEY IS PUBLISHED ONLY FOR A COMPLETE MEASUREMENT, and its ABSENCE
    # is meaningful: this dict's standing contract is that a missing key means
    # "not measured", never "no". A partial probe -- one leg killed on a loaded
    # box, the others fine -- must publish nothing, because recording the
    # survivors would PERMANENTLY narrow the answer, and when the stalled leg is
    # `fold` it would claim the program cannot deliver the one request no binary
    # can fail. Worse than never having asked, because an unmeasured program
    # still answers `fold` and a cached one is not stale.
    #
    # ⚠ IT DOES NOT MAKE THE WHOLE ANSWER `known 0` WHEN IT ALONE TIMES OUT.
    # The three questions above were answered; discarding them because a fourth
    # could not be would throw away a measurement the user already waited for.
    # A casemode leg that times out is reported by its own absence.
    set cmdet {}
    set cmok 0
    if {[ase::cap_left $t0] > 0} {
      if {![catch {sim_probe_capability $exe $exeargs 0 \
                     -cwd $workdir -timeout [expr {[ase::cap_left $t0] * 1000}]} cmr]} {
        if {[dict get $cmr complete]} {
          set cmok 1
          set cmdet [dict get $cmr detected]
        }
      }
    }
    set out [dict create known 1 usable $usable appendwrite $appendwrite \
                         blanket_op_save $blanket hier_op_names $hier]
    if {$cmok} { dict set out casemode_detected $cmdet }
    return $out
  }

  # Register at source time. Kept inside this namespace eval so the only
  # ngspice literals outside ase::backend::ngspice stay the state_default
  # schema defaults.
  ::ase::register_backend ngspice [dict create \
    render_deck  ::ase::backend::ngspice::render_deck \
    run_cmd      ::ase::backend::ngspice::run_cmd \
    log_file     ::ase::backend::ngspice::log_file \
    result_probe ::ase::backend::ngspice::result_probe \
    raw_file     ::ase::backend::ngspice::raw_file \
    capabilities ::ase::backend::ngspice::capabilities]
}
