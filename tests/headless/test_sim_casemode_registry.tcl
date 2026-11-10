# test_sim_casemode_registry.tcl — CASE MODE AS A PROPERTY OF THE REGISTERED
# SIMULATOR. Written at the `annotate` merge; it is the surviving half of
# test_sim_profiles.tcl and test_sim_dialog.tcl, which are retired beside it.
#
# WHAT CHANGED, AND WHAT DID NOT. `fluid-editing`'s casemode batch item 6 put the
# requested case mode -- and the exe, the args and the `-n` flag -- on a
# simulator PROFILE, a row of the stock `sim()` array; item 13 gave every row a
# second dialog line to edit them. `annotate` shipped a simulator REGISTRY with
# CRUD, validation, capability probing and a saved list that survives a restart,
# and the user ruled that the registry wins. Two stores describing one machine is
# not a richer configuration, it is one that can disagree with itself: nothing
# kept the case mode on a `sim()` row and the program in the registry talking
# about the same binary, and nothing invalidated either when the other changed.
#
# ⚠ EVERY RULING BELOW IS THE SAME RULING IT ALWAYS WAS. Only the storage moved.
# The rows are named for the checks they descend from so the lineage is
# followable:
#
#   A1  nobody may select a mode their simulator will silently ignore. The
#       selectable set is exactly what was MEASURED; an unmeasured program offers
#       `fold` alone, `fold` being what a released ngspice does whether or not it
#       was asked (it accepts `-D casemode=preserve` and ignores it, measured).
#   B1  per simulator, with a global floor: a simulator with no request of its
#       own takes `$::sim_case_mode`, which the user sets once for all of them.
#   B2b an unmeasured program is UNKNOWN, never a claim.
#
# WHAT IS NOT HERE, deliberately: the PROBE itself (test_sim_probe), the run
# command it composes (test_sim_run_profile), the C netlister bridge
# (test_sim_plain_run), the capability cache's own contract
# (test_ase_simcaps_0948), and the pick path (test_ase_sod_case).
#
# Run TRUE HEADLESS from the repo root (needs no display):
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_sim_casemode_registry.tcl

source [file join [file dirname [info script]] scratch.tcl]

set fail 0
set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail"; incr npass } \
  else { puts "FAIL: $name $detail"; incr fail }
}
proc eqcheck {name got want} { check $name [expr {$got eq $want}] "(got '$got' want '$want')" }
# a proc that does not exist yet must FAIL a check, never abort with no RESULT
proc pcall {args} {
  if {[catch {uplevel 1 $args} r]} { return "ERR:$r" }
  return $r
}
proc raises {args} { return [catch {uplevel 1 $args}] }
proc slurp {p} { set f [open $p r] ; set d [read $f] ; close $f ; return $d }
proc strip_tcl_comments {body} {
  set out {}
  foreach l [split $body "\n"] {
    if {[regexp {^[ \t]*#} $l]} continue
    regsub {;[ \t]*#.*$} $l {} l
    lappend out $l
  }
  return [join $out "\n"]
}

set tmp [test_scratch sim_casemode_registry]

## ⚠ THIS SUITE REGISTERS SIMULATORS, AND REGISTRATION NOW REACHES THE DISK
## (2026-09-08). ase::sim_register persists the registry into
## $::USER_CONF_DIR/ase_simulators at the moment it changes, which is the
## developer's own ~/.xschem/ase_simulators here. The stubs below are /bin/sh
## and deliberately broken files; writing them over the user's real list would
## take away the build they actually use. This suite is not ABOUT the saving,
## so it opts out of it -- the one test seam ase::sim_touch honours.
catch {set ::ase::sim_autosave 0}
set fixdir [file join [file dirname [info script]] fixtures]
proc reset {} { ase::sim_clear ; set ::sim_case_mode fold }

if {[catch {

# ===========================================================================
# A — VALIDATION AT THE DOOR  (was CS154*)
# ===========================================================================
# The READ side is the half that matters, and it moved with the store. A
# hand-edited simrc was plain Tcl and never passed through `sim_profile_set`, so
# item 6 had to treat `casemode sideways` as UNSET on the way OUT. The registry's
# saved list is also plain Tcl -- a file of ase::sim_register lines -- but it
# comes back THROUGH the same door it went out of, so a bad value is refused at
# the point it is stated, by name, instead of being silently ignored later.
reset
eqcheck CS154-a-bad-casemode-is-REFUSED-not-downgraded \
  [raises ase::sim_register bad /bin/sh -casemode sideways] 1
eqcheck CS154b-...and-the-refusal-names-the-modes-and-the-simulator \
  [expr {[catch {ase::sim_register bad /bin/sh -casemode sideways} e] &&
         [string match {*'bad'*} $e] && [string match {*fold preserve distinguish*} $e]}] 1
eqcheck CS154c-nothing-is-registered-by-a-refused-call \
  [pcall ase::sim_list] {}
eqcheck CS154d-an-EMPTY-casemode-is-legal-and-means-no-request-of-my-own \
  [raises ase::sim_register ok1 /bin/sh -casemode {}] 0
reset
eqcheck CS154e-nospiceinit-refuses-garbage \
  [raises ase::sim_register bad /bin/sh -nospiceinit sideways] 1
reset
# every Tcl boolean spelling, since A2's field legitimately arrives as any of them
set nsi {}
foreach v {1 0 true false yes no on off} {
  reset
  pcall ase::sim_register b /bin/sh -nospiceinit $v
  lappend nsi [pcall ase::sim_nospiceinit ngspice]
}
eqcheck CS154f-nospiceinit-accepts-every-boolean-spelling-and-canonicalises \
  $nsi {1 0 1 0 1 0 1 0}
reset
eqcheck CS154g-an-unknown-option-is-refused-and-the-message-lists-the-known-ones \
  [expr {[catch {ase::sim_register x /bin/sh -nosuchopt 1} e] &&
         [string match {*-casemode*} $e] && [string match {*-nospiceinit*} $e]}] 1

# ===========================================================================
# B — B1: PER SIMULATOR, WITH A GLOBAL FLOOR  (was CS155*)
# ===========================================================================
reset
eqcheck CS155-nothing-registered-falls-to-the-floor \
  [pcall ase::sim_casemode_requested ngspice] fold
set ::sim_case_mode preserve
eqcheck CS155b-the-floor-is-the-floor-not-a-constant \
  [pcall ase::sim_casemode_requested ngspice] preserve
pcall ase::sim_register mine /bin/sh -casemode distinguish
eqcheck CS155c-the-simulators-own-mode-beats-the-floor \
  [pcall ase::sim_casemode_requested ngspice] distinguish
# ...and a simulator that states NO mode of its own falls back through to it,
# which is what makes the floor a floor rather than a default nobody can reach
pcall ase::sim_register mine /bin/sh -casemode {}
eqcheck CS155c2-a-simulator-with-no-mode-of-its-own-uses-the-floor \
  [pcall ase::sim_casemode_requested ngspice] preserve
reset
set ::sim_case_mode sideways
eqcheck CS155d-a-garbage-floor-is-not-a-request-it-folds \
  [pcall ase::sim_casemode_requested ngspice] fold
# ⚠ AND A GARBAGE FLOOR DOES NOT SMUGGLE ITSELF PAST A REGISTERED SIMULATOR
# EITHER. The entry's own mode is validated at the door, so this is really
# asserting that the fallback ladder cannot be entered from the middle.
pcall ase::sim_register mine /bin/sh -casemode preserve
eqcheck CS155e-a-garbage-floor-under-a-registered-mode-still-answers-the-mode \
  [pcall ase::sim_casemode_requested ngspice] preserve
reset

# ⚠ A REFUSED RESOLUTION YIELDS NO MODE OF ITS OWN. `ok 0` still carries the
# entry the user chose -- whose program has since gone, or was never for this
# backend -- and reading a case mode off it would attribute a request to a
# simulator that is not going to run. This is the row that reddens if the ladder
# is shortened to "read the entry".
pcall ase::sim_register gone /nonexistent/ngspice -casemode distinguish
set ::sim_case_mode preserve
eqcheck CS155f-an-unrunnable-simulator-contributes-no-mode \
  [::list [pcall dict get [ase::sim_status ngspice] ok] \
          [pcall ase::sim_casemode_requested ngspice]] {0 preserve}
reset

# ===========================================================================
# C — A1: REQUESTED AND MEASURED ARE DIFFERENT QUESTIONS  (was CS156*, SDG7*)
# ===========================================================================
# The two must stay separable or the dropdown cannot refuse a mode the binary
# will silently ignore. `requested` is a FIELD of the record; `detected` is an
# ANSWER from the capability probe and is never stored on the record at all --
# which is a strengthening, not a weakening, of item 6's split: there is no
# second field to go stale.
reset
pcall ase::sim_register mine /bin/sh -casemode distinguish
pcall ase::sim_caps_clear
eqcheck CS156-requested-and-measured-are-separate \
  "req=[pcall ase::sim_casemode_requested ngspice]\
 det=<[pcall ase::sim_casemode_detected ngspice]>" \
  {req=distinguish det=<>}
# B2b: never probed supports NOTHING, not even fold. An unmeasured binary is
# unknown, not a claim.
eqcheck CS156b-never-probed-detects-nothing-not-even-fold \
  [pcall ase::sim_casemode_detected ngspice] {}
# A1: ...but it may still be OFFERED fold, which is the one request no binary
# can silently fail. The two rows are the same distinction the whole ruling
# rests on and they are asserted next to each other on purpose.
eqcheck CS156c-selectable-is-fold-alone-until-probed \
  [pcall ase::sim_casemode_selectable ngspice] fold
reset

# ===========================================================================
# D — THE VARIABLE EXPANDER IS NOT AN EVALUATOR  (was CS157k / CS157l)
# ===========================================================================
# MEASURED on Tcl 8.6.14: `subst -nocommands` is NOT a sandbox -- Tcl still
# evaluates a `[...]` sitting inside the ARRAY INDEX of a variable substitution,
# because the index is parsed as a script word before the (suppressed)
# command-substitution pass applies. Driven end to end on this tree, an `exe` of
# `$env([exec touch .../PWNED])/ngspice` created the file during a pure
# STALENESS query. `sim_expand_vars` is the hardened answer.
#
# ⚠ THESE ROWS ARE WHAT KEPT IT ALIVE WHILE IT HAD NO CALLER. Its last caller
# went with the profile layer, and it is the only expander in the tree that
# refuses, so deleting it as dead code would have thrown away the fix. It has a
# caller again as of issue 1239: `ase::expand_path` -- model paths, `.include`
# paths, `pre_` command text and SIMULATOR paths out of ase::sim_register --
# routes through it, and CS157n..CS157v below measure that end.
set ::PWN [file join $tmp PWNED]
catch {file delete -force $::PWN}
set ::RAN 0
eqcheck CS157k-a-command-substitution-does-not-run \
  "raised=[raises sim_expand_vars {$env([set ::RAN 1])/x}] ran=$::RAN" \
  {raised=1 ran=0}
catch {sim_expand_vars "\$env(\[exec touch $::PWN\])/ngspice"}
eqcheck CS157l-...and-a-command-inside-an-ARRAY-INDEX-does-not-run-either \
  [file exists $::PWN] 0
eqcheck CS157m-an-ordinary-variable-still-expands \
  [pcall sim_expand_vars {$tcl_platform(platform)/x}] "$::tcl_platform(platform)/x"

# ---------------------------------------------------------------------------
# ISSUE 1239 -- THE CALLER. Everything above measures the safe expander in
# isolation; these rows measure the proc that model paths, .include paths,
# `pre_` command text and REGISTERED SIMULATOR PATHS actually go through.
# `ase::sim_register` expands the exe, and `ase::sim_load_conf` runs at STARTUP
# on a plain Tcl script in $USER_CONF_DIR, so the array-index hole was reachable
# from a pure staleness query on a machine whose owner only ever registered a
# simulator.
#
# ⚠ THE ATTACK IS DRIVEN, NOT DESCRIBED. CS157n watches a flag that the payload
# would set, and CS157o watches for a FILE the payload would create -- a row
# that only asserted "it raised" would stay green for an expander that ran the
# command and then complained about the result.
set ::PWN2 [file join $tmp PWNED_EXPAND_PATH]
catch {file delete -force $::PWN2}
set ::RAN2 0
eqcheck CS157n-expand_path-refuses-a-command-substitution-in-an-ARRAY-INDEX \
  "raised=[raises ase::expand_path {$env([set ::RAN2 1])/x}] ran=$::RAN2" \
  {raised=1 ran=0}
catch {ase::expand_path "\$env(\[exec touch $::PWN2\])/ngspice"}
eqcheck CS157o-...and-the-command-in-that-index-really-did-not-run \
  [file exists $::PWN2] 0

# THE OTHER HALF OF THE SAME CHANGE, and the half a hardening is most likely to
# break: ordinary paths must still expand, or every committed bench stops
# netlisting. `$name`, `${name}`, `$::ns::name` and `$env(index)` are the four
# spellings the tree actually contains.
set ::CS157ROOT [file join $tmp pdkroot]
set ::CS157SEC tt
eqcheck CS157p-a-plain-name-still-expands \
  [pcall ase::expand_path {$CS157ROOT/models/x.lib}] "$::CS157ROOT/models/x.lib"
eqcheck CS157q-a-braced-name-and-a-namespaced-name-still-expand \
  [pcall ase::expand_path {${CS157ROOT}/m/$::CS157SEC.lib}] "$::CS157ROOT/m/tt.lib"
eqcheck CS157r-an-env-array-element-still-expands \
  [pcall ase::expand_path {$env(HOME)/models/x.lib}] "$::env(HOME)/models/x.lib"
eqcheck CS157s-a-plain-absolute-path-comes-back-verbatim \
  [pcall ase::expand_path {/opt/pdk/models/sky130.lib.spice}] \
  {/opt/pdk/models/sky130.lib.spice}
eqcheck CS157t-an-unset-variable-is-still-an-ERROR-not-a-silent-empty-path \
  [raises ase::expand_path {$CS157_no_such_variable_/x.lib}] 1

# THE SURVEY, KEPT AS A ROW. Issue 1239 says this change may not land until
# every committed `.state` fixture's expanded fields have been checked against
# the refusing expander, because an index it refuses is an ERROR. The survey was
# run over all 104 committed `.state` files (22 distinct strings, zero refused,
# zero expanding differently); these are the SEVEN DISTINCT SHAPES that survey
# found, so a future tightening that starts refusing one of them reddens here
# instead of at a user's netlist.
#
# ⚠ THE LAST SHAPE IS WHY THIS IS NOT "REFUSE ANY BRACKET". The shipped
# mixed-signal `pre_commands` carry LITERAL `[ %s ]` -- ngspice auto_bridge
# cards -- and they go through this same proc. Refusing brackets outright would
# have passed every other row in this file and broken those benches.
set cs157had {}
set cs157vars {MODELS_NGSPICE SG13G2_OSDI SKYWATER_MODELS 180MCU_MODELS
               SKYWATER_STDCELLS SKYWATER_HVL_STDCELLS PDK_ROOT PDK}
foreach v $cs157vars {
  if {[info exists ::$v]} { dict set cs157had $v [set ::$v] }
  set ::$v "/CS157/$v"
}
set cs157bad {}
foreach shape {
  {$::SKYWATER_MODELS/sky130.lib.spice}
  {$::MODELS_NGSPICE/cornerMOSlv.lib}
  {$::180MCU_MODELS/sm141064.ngspice}
  {$::SKYWATER_STDCELLS/sky130_fd_sc_hd.spice}
  {$PDK_ROOT/$PDK/libs.ref/sky130_fd_sc_hvl/spice/sky130_fd_sc_hvl.spice}
  {$::SKYWATER_HVL_STDCELLS/sky130_fd_sc_hvl.spice}
  {pre_osdi $::SG13G2_OSDI/psp103.osdi}
  {pre_set auto_bridge_d_in = ( ".model auto_adc adc_bridge(in_low = 0.6 in_high = 1.2)" "auto_bridge%d [ %s ] [ %s ] auto_adc" )}
} {
  if {[catch {ase::expand_path $shape} r]} {
    lappend cs157bad "REFUSED <$shape> -> $r" ; continue
  }
  if {[string first "\$" $r] >= 0} { lappend cs157bad "UNEXPANDED <$shape> -> $r" }
}
foreach v $cs157vars {
  if {[dict exists $cs157had $v]} { set ::$v [dict get $cs157had $v] } \
  else { unset -nocomplain ::$v }
}
eqcheck CS157u-every-shape-the-committed-state-fixtures-contain-still-expands \
  $cs157bad {}

# STRUCTURAL, because no behavioural row can see it. The hole is not "an unsafe
# call somewhere"; it is that this proc reached for a general-purpose evaluator
# at all. A reader who "fixes" it by blacklisting a few characters in front of
# the same evaluator passes CS157n..o for as long as the blacklist happens to be
# complete, and Tcl's parser is not a thing to be guessed at. So the row states
# the invariant directly: ONE expander, and it is the refusing one. Comments are
# stripped first, so a paragraph about it cannot satisfy the row.
set cs157body [strip_tcl_comments [info body ase::expand_path]]
set cs157deleg [expr {[string first {sim_expand_vars} $cs157body] >= 0}]
set cs157subst [regexp {(^|[^a-zA-Z0-9_])subst([^a-zA-Z0-9_]|$)} $cs157body]
set cs157eval  [regexp {(^|[^a-zA-Z0-9_])(eval|expr)([^a-zA-Z0-9_]|$)} $cs157body]
eqcheck CS157v-STRUCTURAL-expand_path-delegates-to-the-refusing-expander-and-evaluates-nothing-itself \
  "delegates=$cs157deleg subst=$cs157subst eval=$cs157eval" \
  {delegates=1 subst=0 eval=0}

# ---------------------------------------------------------------------------
# ISSUE 1239, THE OTHER DIRECTION -- A `$` MUST NOT SURVIVE INTO A FILENAME.
# ---------------------------------------------------------------------------
# The rows above measure the LOOSENING the hardening was for: shapes the old
# `subst -nocommands` accepted (and executed) are now refused. This block
# measures the direction the first pass missed, and it was found by a
# differential fuzz, not by reading: shapes the OLD expander RAISED on came back
# from the new one SILENTLY, as a literal, with the dollar sign still in the
# path. A model path that used to fail loudly at load became a filename with a
# `$` in it, which fails later, somewhere else, with a worse message.
#
# TWO MECHANISMS, and both are in the parser rather than in any one shape:
#
#   M1 NO MATCH AT ALL -> the `$` was emitted as a literal and the scan moved on.
#      Tcl's own parser, though, DOES read `$(idx)` (a variable whose name is
#      empty), `${}`, an unterminated brace form, and a bare `$::` as
#      references, and raises on every one of them.
#   M2 A SHORTER MATCH THAN TCL'S -> the reference expanded and the REMAINDER
#      became literal text. `$V::` gave `<value>::`, `$V(` gave `<value>(`,
#      where Tcl read the name `V::` / an unterminated index and raised.
#
# So the expander now refuses at exactly the two seams: a `$` it declined that
# Tcl would have read (a brace form, a `(`, or a `::` run), and a name it
# stopped short of that Tcl would have continued (`::` or `(` right after).
#
# ⚠ `$` IS STILL A LITERAL WHERE TCL LEAVES IT ONE -- CS157z. `$/x`, `$$V`, a
# trailing `$`, `$V:x` (ONE colon ends a name for Tcl too) all still pass
# through, because tightening those would refuse paths that both expanders
# always accepted and no defect was ever reported about.
# Helpers for the block below. `cs157_refusals` names every shape that came back
# with a VALUE where a refusal was wanted, so a red row says which shape and what
# it returned instead of just "0 != 1".
proc cs157_refusals {shapes} {
  set bad {}
  foreach sh $shapes {
    if {![catch {ase::expand_path $sh} r]} { lappend bad "ACCEPTED <$sh> -> <$r>" }
  }
  return $bad
}
proc cs157_expansions {shapes} {
  set out {}
  foreach sh $shapes {
    if {[catch {ase::expand_path $sh} r]} { lappend out "ERR:$r" } else { lappend out $r }
  }
  return $out
}
# The differential corpus: variable-reference shapes only, NO `[` (see the note
# on CS157aa -- the old expander is the oracle and a bracket in an index is the
# payload). ::CS157V is set; ::CS157W is deliberately never set.
proc cs157_corpus {} {
  return [list \
    "\$CS157V/x" "\$\{CS157V\}/x" "\$::CS157V/x" "\$env(HOME)/x" "/plain/abs" \
    "\$(V)/x" "\$()/x" "\$(CS157V)/x" "\$\{\}/x" "\$\{abc/x" "\$::/x" "\$:/x" \
    "\$CS157V::/x" "\$CS157V:::W/x" "\$::CS157V::/x" "\$CS157V::W/x" \
    "\$CS157V(/x" "\$CS157V(k" "\$CS157V()/x" "\$CS157V(a(b))/x" \
    "\$CS157V(k)(j)/x" "\$env(HOME)(j)/x" "\$env(HOME/x" \
    "\$/x" "\$\$CS157V/x" "\$CS157V:x" "\$CS157V-2/x" "\$CS157V.lib" "\$CS157V/a\$" \
    "\$CS157W/x" "\$env(CS157_NO_SUCH_ENV_)/x" "\$1CS157V/x" \
    "\$CS157V\\x" "a\\\$CS157V/x" "\$\{CS157V\}::/x" "\$\{CS157V\}(k)/x"]
}
proc cs157_loosened {} {
  set bad {}
  foreach sh [cs157_corpus] {
    set orc [catch {uplevel #0 [list subst -nocommands -nobackslashes $sh]} oo]
    set nrc [catch {ase::expand_path $sh} no]
    if {$orc && !$nrc} { lappend bad "LOOSENED <$sh> old<$oo> new<$no>" }
  }
  return $bad
}
set ::CS157V /CS157/varset
eqcheck CS157w-a-dollar-this-expander-cannot-read-is-an-ERROR-not-a-literal-in-a-path \
  [cs157_refusals [list "\$(V)/x" "\$()/x" "\$\{\}/x" "\$\{abc/x" "\$::/x"]] {}
eqcheck CS157x-a-reference-the-parser-stops-short-of-is-an-ERROR-not-a-half-expansion \
  [cs157_refusals [list "\$CS157V::/x" "\$CS157V:::W/x" "\$::CS157V::/x" \
                        "\$CS157V(/x" "\$CS157V(k" "\$CS157V(a(b))/x"]] {}
eqcheck CS157y-...and-the-half-expansion-really-is-gone-not-merely-flagged \
  [pcall ase::expand_path {$CS157V::/x}] "ERR:ase: cannot expand model path\
'\$CS157V::/x': sim_expand_vars: refusing a variable reference this expander\
would read differently from Tcl: \$CS157V::"
eqcheck CS157z-a-dollar-Tcl-itself-leaves-literal-is-still-passed-through \
  [cs157_expansions [list "\$/x" "\$\$CS157V/x" "\$CS157V:x" "\$CS157V-2/x" \
                          "/plain/\$" "\$CS157V/a\$"]] \
  [list "\$/x" "\$/CS157/varset/x" "/CS157/varset:x" "/CS157/varset-2/x" \
        "/plain/\$" "/CS157/varset/a\$"]

# THE DIFFERENTIAL, KEPT AS A ROW. This is the fuzz that found the family,
# reduced to the corpus it found it with: every shape is expanded through BOTH
# the old `subst -nocommands -nobackslashes` and `ase::expand_path`, and any
# shape the OLD raised on while the NEW returned a value is reported by name.
# The row is the invariant, not the list: a later loosening anywhere in the
# parser reddens here even if nobody thought to write a row for its shape.
#
# ⚠ THE CORPUS CARRIES NO `[`, ON PURPOSE. The old expander is the oracle here
# and it EXECUTES a command substitution sitting in an array index -- that is
# the whole defect. Running the oracle over a payload would be running the
# payload. The bracket direction is CS157n/CS157o's, driven there.
eqcheck CS157aa-DIFFERENTIAL-no-shape-the-old-expander-refused-comes-back-as-a-literal \
  [cs157_loosened] {}

# THE STRICTER DIRECTION, PINNED SO IT IS NOT A SURPRISE. Two shapes went the
# other way: `subst` resolved a colon run of three or more (`$:::V` is `::V` to
# Tcl's namespace lookup), and this expander refuses it rather than growing a
# second spelling of the separator. It is on the ledger with the rest of issue
# 1239's residue; nothing in the tree, in any committed `.state` file or in any
# shipped `xschemrc`, spells a variable that way.
eqcheck CS157ab-a-colon-run-of-three-or-more-is-REFUSED-where-subst-resolved-it \
  [cs157_refusals [list "\$:::CS157V/x" "\$::::CS157V/x"]] {}

# ===========================================================================
# E — PERSISTENCE: THE FIELDS SURVIVE A RESTART  (was CS158*)
# ===========================================================================
# A writer that knows about `-args` and `-backend` alone would hand a user who
# set `distinguish` a `fold` run at their next start, with nothing said and
# nothing to see. Both new fields are written unconditionally, so the file
# states the whole record and reading it back cannot depend on what the writer's
# defaults happened to be.
reset
set conf [file join $tmp ase_simulators]
pcall ase::sim_register persisted /bin/sh -args {-r out.raw} -casemode distinguish -nospiceinit 1
pcall ase::sim_write_conf $conf
set conftxt [slurp $conf]
eqcheck CS158-the-written-line-states-both-new-fields \
  "cm=[string match {*-casemode distinguish*} $conftxt]\
 nsi=[string match {*-nospiceinit 1*} $conftxt]" \
  {cm=1 nsi=1}
reset
pcall ase::sim_load_conf $conf
eqcheck CS158b-...and-they-come-back \
  "cm=[pcall ase::sim_casemode_requested ngspice]\
 nsi=[pcall ase::sim_nospiceinit ngspice]\
 args=<[pcall dict get [ase::sim_status ngspice] args]>" \
  {cm=distinguish nsi=1 args=<-r out.raw>}
# ...and the round trip is a FIXED POINT: writing what was read produces the
# same bytes, so a restart cannot drift the record one field at a time.
set conf2 [file join $tmp ase_simulators_2]
pcall ase::sim_write_conf $conf2
eqcheck CS158c-the-round-trip-is-a-fixed-point [expr {[slurp $conf2] eq $conftxt}] 1
reset

# ===========================================================================
# F — WHAT THE PROFILE LAYER LEFT BEHIND, AND MUST STILL BE TRUE  (was CS150)
# ===========================================================================
# `save_sim_defaults` used to append the six profile fields to every configured
# row. It does not any more, and the property CS150 asserted is now easier to
# hold and MORE important to check: a simrc written before any of this existed
# must round-trip byte-identically. The fixture is the pre-item-6 one, which is
# also what a stock xschem writes.
set pre [file join $fixdir simrc_pre_casemode]
if {![file isfile $pre]} {
  check CS150-pre-batch-simrc-fixture-missing 0 "($pre)"
} else {
  set pretxt [slurp $pre]
  catch {unset ::sim}
  pcall uplevel #0 [::list source $pre]
  pcall set_sim_defaults
  set out [file join $tmp resaved_simrc]
  pcall save_sim_defaults $out
  # ⚠ THE SECOND TERM IS THE ANTI-VACUOUS HALF, AND IT INVERTED AT THIS MERGE.
  # It used to assert that the profile fields WERE planted in memory, so the row
  # could not pass by the feature being absent. The feature is now deliberately
  # absent, so what has to be asserted is the opposite and it is a real claim:
  # nothing plants a profile field any more, on any route.
  eqcheck CS150-a-stock-simrc-round-trips-byte-identical \
    "identical=[expr {[slurp $out] eq $pretxt}]\
 no_profile_fields=[expr {![info exists ::sim(spice,0,exe)]}]" \
    {identical=1 no_profile_fields=1}
}

# THE RULING (spec section 6): `sim_is_xyce` reads the configured `cmd`, and only
# `cmd`. Item 4 built hilight.c's Xyce sender fallback on its answer, so what
# feeds it changes fold-vs-uppercase behaviour four items away. It never read the
# profile's `exe`, and now there is no `exe` to read; what this row still pins is
# that a REGISTERED Xyce does not change its answer either -- the same ruling,
# against the store that replaced the one it was written about.
reset
set ::netlist_type spice
pcall set_sim_defaults
set ::sim(spice,default) 2
pcall ase::sim_register xy /opt/Xyce/bin/Xyce
eqcheck CS160-sim_is_xyce-ignores-a-registered-Xyce [pcall sim_is_xyce] 0
set ::sim(spice,default) 3
eqcheck CS160b-sim_is_xyce-still-answers-from-cmd [pcall sim_is_xyce] 1
set ::sim(spice,default) 0
reset

# ===========================================================================
# G — THE ASE-L STATE FILE  (was CS165*)
# ===========================================================================
# The pre-batch fixture must still round-trip byte-identically. It could only do
# so before because `sim_profile` was in ase::omit_if_empty; the key is gone
# entirely now, so the round trip holds for a stronger reason -- there is no
# 17th key to omit.
set sfix [file join $fixdir ase_state_v1_pre_cosim.state]
if {![file isfile $sfix]} {
  check CS165-pre-batch-state-fixture-missing 0 "($sfix)"
} else {
  set ftxt [slurp $sfix]
  set old [pcall ase::state_load $sfix]
  set rt [file join $tmp roundtrip.state]
  pcall ase::state_save $rt $old
  eqcheck CS165-pre-batch-state-round-trips-byte-identical \
    "identical=[expr {[slurp $rt] eq $ftxt}]\
 no_sim_profile_key=[expr {![dict exists $old sim_profile]}]\
 kept_unknown=[dict exists $old zz_unknown_future_key]" \
    {identical=1 no_sim_profile_key=1 kept_unknown=1}
}

# ===========================================================================
# H — NO Tk  (was CS166 / SDG15)
# ===========================================================================
# src/ase.tcl is sourced at startup and runs true-headless. SDG15 used to assert
# that item 13's MODEL procs answered with no dialog open; there is no dialog
# any more, so the claim is simply that none of these reaches for Tk.
# (strip_tcl_comments is a preamble helper -- section D uses it too.)
# ⚠ COMMAND POSITION, not merely a non-word character. Half these names are
# ordinary English -- `entry`, `label`, `text` -- and a bare `[^a-zA-Z0-9_]`
# context matches them inside `dict get $s entry`, which reddens the row for a
# proc that has never touched Tk. A false positive is not harmless: the fix a
# reader reaches for is to rename the innocent variable, which is how a true
# detector gets turned off.
set tkre {(^|[\[\{;|]|^[ \t]*|[\[\{;|][ \t]*)(tk_[a-zA-Z_]+|winfo|wm|toplevel|grab|ttk::[a-z]+|bind|focus|frame|button|entry|label|canvas|listbox|checkbutton|radiobutton|menu|text|scrollbar)([^a-zA-Z0-9_:.]|$)}
set tk_blind {}
foreach s {{ set w [toplevel .p] } { button .b -text x } { winfo exists .x }} {
  if {![regexp $tkre $s]} { lappend tk_blind $s }
}
set tk_hits {}
foreach p {ase::sim_register ase::sim_unregister ase::sim_select ase::sim_status
           ase::sim_casemode_requested ase::sim_casemode_detected
           ase::sim_casemode_selectable ase::sim_nospiceinit
           ase::sim_write_conf ase::sim_write_body ase::sim_load_conf
           sim_casemode_valid sim_expand_vars sim_netlist_casemode} {
  if {[catch {info body $p} b]} { lappend tk_hits MISSING:$p ; continue }
  if {[regexp $tkre [strip_tcl_comments $b] -> _pre cmdname]} { lappend tk_hits $p:$cmdname }
}
eqcheck CS166-no-Tk-in-any-registry-casemode-proc-and-the-detector-can-see-Tk \
  "hits=<$tk_hits> blind=<$tk_blind>" {hits=<> blind=<>}

} err]} {
  puts "FATAL: $err"
  puts "  $::errorInfo"
  incr fail
}

catch {ase::sim_clear}
catch {test_scratch_drop $tmp}
puts "----"
puts "test_sim_casemode_registry: $npass passed, $fail failed"
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
