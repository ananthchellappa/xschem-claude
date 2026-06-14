# Tests for the slick property-form CORE (slickprop::). Committed RED first:
# the PF* tests are xcheck (XFAIL) until src/property_form.tcl lands, then flip to
# check. Sourced by wrap.tcl, which provides check/xcheck/::pf_dir.
#
# THE CORE CONTRACT under test:
#   slickprop::to_fields <prop> <template>
#       -> ordered list of field dicts {name value declared default isset}, the
#          declared (template) tokens first (template order), then extra tokens.
#   slickprop::apply <orig> <changes>
#       -> <orig> with ONLY the {tok val ...} pairs in <changes> substituted back
#          (subst-into-original); empty val removes the token; untouched tokens of
#          <orig> are preserved byte-for-byte.
#   slickprop::requote <v>  -> escape "/\ and wrap in quotes (for subst_tok).
#
# A field needs a live xctx for the token primitives, so build a fixture first.

### stub modals
catch {rename tk_messageBox _real_tk_messageBox}
proc tk_messageBox {args} {return ok}

xschem set modified 0
xschem clear force schematic

# tolerant wrappers so missing procs (RED phase) don't abort the suite
proc f_fields {p t} { if {[catch {slickprop::to_fields $p $t} r]} {return -2}; return $r }
proc f_apply  {o c} { if {[catch {slickprop::apply $o $c} r]} {return -2}; return $r }
proc f_dg {d k {dflt {}}} { if {$d eq "-2"} {return $dflt}; if {[catch {dict get $d $k} v]} {return $dflt}; return $v }
# find the field dict for token <tok> in a to_fields result
proc f_row {fields tok} {
  if {$fields eq "-2"} {return {}}
  foreach row $fields { if {[f_dg $row name] eq $tok} {return $row} }
  return {}
}

### PF1 — to_fields builds one row per declared token, in template order, with the
### instance value where set.
set prop {name=E1 TABLE="1.4 0.0 1.6 4.0"}
set tmpl {name=x1 TABLE="0 0 0 0"}
set F [f_fields $prop $tmpl]
check {PF1a to_fields returns 2 rows for a 2-token template} {[llength $F] == 2}
check {PF1b row order follows the template (name then TABLE)} \
  {[f_dg [lindex $F 0] name] eq "name" && [f_dg [lindex $F 1] name] eq "TABLE"}
check {PF1c the instance value is extracted clean (no surrounding quotes)} \
  {[f_dg [f_row $F TABLE] value] eq "1.4 0.0 1.6 4.0"}
check {PF1d declared tokens are marked declared=1} \
  {[f_dg [f_row $F name] declared] == 1}

### PF2 — a declared-but-unset attr: isset=0, value empty, template default carried.
set prop {name=E1}
set tmpl {name=x1 lab=DEFLAB}
set F [f_fields $prop $tmpl]
check {PF2a unset declared token lab has isset=0} \
  {[f_row $F lab] ne "" && [f_dg [f_row $F lab] isset] == 0}
check {PF2b unset declared token lab has empty value (not written unless edited)} \
  {[f_row $F lab] ne "" && [f_dg [f_row $F lab] value] eq ""}
check {PF2c unset declared token carries the template default as a hint} \
  {[f_dg [f_row $F lab] default] eq "DEFLAB"}

### PF3 — an extra (undeclared) instance token appears AFTER declared ones,
### declared=0 (the strict-mode "Extra" section).
set prop {name=E1 foobar=123}
set tmpl {name=x1}
set F [f_fields $prop $tmpl]
check {PF3a extra token foobar is present} {[f_row $F foobar] ne ""}
check {PF3b extra token is declared=0} {[f_dg [f_row $F foobar] declared] == 0}
check {PF3c declared tokens come before extras} \
  {[f_dg [lindex $F 0] name] eq "name" && [f_dg [lindex $F end] name] eq "foobar"}

### PF4 — THE CARDINAL INVARIANT: apply with NO changes is byte-identical, for a
### battery of hostile strings (quoted, multi-line, escaped, extra tokens).
foreach {tag p} {
  simple   {name=E1}
  spaces   {name=E1 TABLE="1.4 0.0 1.6 4.0"}
  extra    {name=E1 lab=PLUS foobar=123}
  multilin "format=\"\n@value\n\""
  escaped  {name=x1 descr="say \"hi\" there"}
} {
  check "PF4-$tag apply(prop,{}) is byte-identical (no-edit no-op)" \
    {[f_apply $p {}] eq $p}
}

### PF5 — apply ONE change touches only that token; the rest is byte-identical.
set p {name=E1 TABLE="1.4 0.0 1.6 4.0"}
set out [f_apply $p [list TABLE "9.9 8.8"]]
check {PF5a editing TABLE changes only TABLE's value} \
  {$out eq {name=E1 TABLE="9.9 8.8"}}
check {PF5b name token is untouched (still bare, not requoted)} \
  {[xschem get_tok $out name 2] eq "E1" && [string match {name=E1 *} $out]}

### PF6 — EDIT FIDELITY: re-inserting a value preserves its MEANING (get_tok before
### == after) even for spaces / multi-line / escaped quotes. (Not byte-identical —
### requoting may add quotes — but semantically lossless.)
foreach {tag p tok} {
  spaces   {name=E1 TABLE="1.4 0.0 1.6 4.0"}        TABLE
  multilin "v=\"\n@value\n\""                         v
  escaped  {d="say \"hi\" there"}                     d
} {
  set v [xschem get_tok $p $tok 2]
  set out [f_apply $p [list $tok $v]]
  check "PF6-$tag re-inserting a value preserves its meaning" \
    {[xschem get_tok $out $tok 2] eq $v}
}

### PF7 — clearing a field (empty new value) removes the token.
set p {name=E1 lab=PLUS}
set out [f_apply $p [list lab {}]]
check {PF7 clearing lab removes the token but keeps the rest} \
  {[string match {*name=E1*} $out] && ![string match {*lab=*} $out]}

### PF8 — requote escapes "/\ and wraps in quotes.
check {PF8a requote wraps a plain value in quotes} \
  {[catch {slickprop::requote abc} r] == 0 && $r eq {"abc"}}
check {PF8b requote escapes embedded double quotes} \
  {[catch {slickprop::requote {a"b}} r] == 0 && $r eq {"a\"b"}}

### PF9 — THE RELEASE GATE: across every instance of a real schematic, apply with
### no edits is byte-identical AND every declared token survives a re-insert with
### its meaning intact. This is run on real device prop strings at scale.
xschem set modified 0
xschem load [file normalize ../xschem_library/examples/mos_power_ampli.sch]
xschem set modified 0
set ninst [xschem get instances]
set noop_ok 1; set fidel_ok 1; set tested 0
for {set i 0} {$i < $ninst} {incr i} {
  set prop [xschem getprop instance $i]
  if {$prop eq ""} continue
  incr tested
  # no-op invariant
  if {[f_apply $prop {}] ne $prop} { set noop_ok 0 }
  # edit fidelity per declared token
  set tmpl [xschem getprop instance $i cell::template]
  foreach tok [xschem list_tokens $tmpl 0] {
    set v [xschem get_tok $prop $tok 2]
    set out [f_apply $prop [list $tok $v]]
    if {[xschem get_tok $out $tok 2] ne $v} { set fidel_ok 0 }
  }
}
# corpus-size precondition (not a module test) — a plain check
check {PF9a tested a meaningful number of real instances (> 50)} {$tested > 50}
check {PF9b no-op apply is byte-identical across all real instances} {$noop_ok == 1}
check {PF9c every declared token survives re-insert with meaning intact} {$fidel_ok == 1}

### PF10 — the multi-line `code` symbol: a fresh instance round-trips its big
### `value`/`format` attributes byte-for-byte under a no-op apply.
xschem set modified 0
xschem clear force schematic
xschem instance code.sym 0 0 0 0 {name=s1}
set prop [xschem getprop instance 0]
check {PF10 a code.sym instance's multi-line props survive a no-op apply} \
  {[f_apply $prop {}] eq $prop}

# ===========================================================================
# PF11-PF15 — the FORM layer (build_fields/placeholder/collect_changes/result),
# exercised through real Tk widgets (a display is available headless). These
# prove the widget-level dirty-tracking and placeholder logic feed the proven
# core correctly. Built in a withdrawn toplevel so nothing pops up.
# ===========================================================================
proc gui_ok {} { return [expr {[catch {toplevel .pf; wm withdraw .pf; frame .pf.f; pack .pf.f} ] == 0}] }
proc gui_done {} { catch {destroy .pf} }

### PF11 — build the form, make NO edits, result() == orig (cardinal invariant
### carried through the widget layer).
if {[gui_ok]} {
  set prop {name=E1 TABLE="1.4 0.0 1.6 4.0"}
  set tmpl {name=x1 TABLE="0 0 0 0" lab=DEF}
  slickprop::build_fields .pf.f $prop $tmpl
  check {PF11a build_fields placed an entry for each declared token} \
    {[winfo exists $slickprop::cur(entry,name)] && [winfo exists $slickprop::cur(entry,TABLE)]}
  check {PF11b no edits -> result() is byte-identical to the original} \
    {[slickprop::result] eq $prop}
  gui_done
} else { check {PF11 (skipped: no display)} {1} }

### PF12 — edit ONE entry; result() reflects only that change.
if {[gui_ok]} {
  set prop {name=E1 TABLE="1.4 0.0 1.6 4.0"}
  slickprop::build_fields .pf.f $prop {name=x1 TABLE="0 0 0 0"}
  $slickprop::cur(entry,TABLE) delete 0 end
  $slickprop::cur(entry,TABLE) insert 0 {9.9 8.8}
  check {PF12 editing the TABLE entry updates only TABLE in result()} \
    {[slickprop::result] eq {name=E1 TABLE="9.9 8.8"}}
  gui_done
} else { check {PF12 (skipped)} {1} }

### PF13 — a declared-but-unset attr shows its default as a placeholder; its
### effective value is empty and, if untouched, it is NOT written.
if {[gui_ok]} {
  set prop {name=E1}
  slickprop::build_fields .pf.f $prop {name=x1 lab=DEFLAB}
  check {PF13a unset attr lab shows the placeholder (default text, flagged)} \
    {$slickprop::cur(placeholder,lab) == 1 && [$slickprop::cur(entry,lab) get] eq "DEFLAB"}
  check {PF13b lab's effective value is empty (placeholder != content)} \
    {[slickprop::field_value lab] eq ""}
  check {PF13c untouched placeholder -> lab not written, result()==orig} \
    {[slickprop::result] eq $prop}
  gui_done
} else { check {PF13 (skipped)} {1} }

### PF14 — typing into a placeholder field adds the token.
if {[gui_ok]} {
  slickprop::build_fields .pf.f {name=E1} {name=x1 lab=DEFLAB}
  slickprop::placeholder_in lab   ;# simulate focus-in clearing the placeholder
  $slickprop::cur(entry,lab) insert 0 MYNET
  check {PF14 typing a value into an unset attr adds it} \
    {[xschem get_tok [slickprop::result] lab 2] eq "MYNET"}
  gui_done
} else { check {PF14 (skipped)} {1} }

### PF15 — clearing a set field removes its token.
if {[gui_ok]} {
  slickprop::build_fields .pf.f {name=E1 lab=PLUS} {name=x1 lab=DEF}
  $slickprop::cur(entry,lab) delete 0 end
  check {PF15 clearing a set field removes the token from result()} \
    {![string match {*lab=*} [slickprop::result]] && [string match {*name=E1*} [slickprop::result]]}
  gui_done
} else { check {PF15 (skipped)} {1} }

### PF16 — the FULL modal edit_form: build the real dialog, edit a field via a
### scheduled callback, click OK, and assert the C contract (rcode + tctx::retval).
### A safety timer cancels the modal if the field isn't found, so the suite can
### never hang. Guarded so an environment without a usable main window just skips.
proc gui2_ok {} { return [expr {[catch {winfo exists .drw} x]==0 && $x}] }
if {[gui2_ok]} {
  xschem set modified 0
  xschem clear force schematic
  xschem instance res.sym 0 0 0 0 {name=RTEST}
  set ::symbol res.sym
  set ::tctx::retval {name=RTEST value=1k}
  set ::no_change_attrs 0; set ::preserve_unchanged_attrs 0; set ::copy_cell 0
  set ::pf16_built 0
  after 500 {
    if {[info exists slickprop::cur(entry,value)]} {
      set ::pf16_built 1
      slickprop::placeholder_in value
      $slickprop::cur(entry,value) delete 0 end
      $slickprop::cur(entry,value) insert 0 2k
      slickprop::ok
    }
  }
  after 4000 {catch {slickprop::cancel}}  ;# safety: never hang the suite
  set pf16_rc [catch {slickprop::edit_form {Input property:}} pf16_ret]
  check {PF16a edit_form built per-field entries from the live template} {$::pf16_built == 1}
  check {PF16b edit_form returned rcode ok after OK} {$pf16_ret eq "ok"}
  check {PF16c OK wrote the edited value into tctx::retval (subst-into-original)} \
    {[xschem get_tok $::tctx::retval value 2] eq "2k" && [string match {name=RTEST*} $::tctx::retval]}
  check {PF16d the dialog geometry was remembered on close (WxH+X+Y)} \
    {[info exists ::slickprop_geometry] && [regexp {^[0-9]+x[0-9]+} $::slickprop_geometry]}
} else {
  check {PF16a (skipped: no main window)} {1}
  check {PF16b (skipped)} {1}
  check {PF16c (skipped)} {1}
  check {PF16d (skipped)} {1}
}

### PF17 — user-tunable font size (the Cadence-style preference variable). Setting
### ::slickprop_fontsize drives the rendered named fonts on the next init.
set ::slickprop_fontsize 16
slickprop::init_fonts
check {PF17a slickprop_fontsize drives the value font size} \
  {[font configure slickPropValue -size] == 16}
check {PF17b the value font is the monospace TkFixedFont family} \
  {[font configure slickPropValue -family] eq [font actual TkFixedFont -family]}
check {PF17c the label font tracks the same size} \
  {[font configure slickPropLabel -size] == 16}
unset ::slickprop_fontsize  ;# back to auto-default for any later use

### PF18 — the modified-field cue (Batch 2): the dot appears on a field whose
### value changed and stays blank on untouched fields, tracking live.
if {[gui_ok]} {
  slickprop::build_fields .pf.f {name=E1 value=1k} {name=x1 value=0}
  set clean0 [$slickprop::cur(ind,value) cget -text]
  $slickprop::cur(entry,value) delete 0 end
  $slickprop::cur(entry,value) insert 0 2k
  slickprop::update_dirty value
  set dirty1 [$slickprop::cur(ind,value) cget -text]
  slickprop::update_dirty name
  set namemark [$slickprop::cur(ind,name) cget -text]
  check {PF18a field is clean (no dot) before editing} {[string trim $clean0] eq ""}
  check {PF18b an edited field shows the modified dot} {$dirty1 eq "●"}
  check {PF18c an untouched field shows no dot} {[string trim $namemark] eq ""}
  gui_done
} else { check {PF18a (skip)} {1}; check {PF18b (skip)} {1}; check {PF18c (skip)} {1} }

### PF19 — the "Extra (undeclared)" path builds via ttk::separator without error.
if {[gui_ok]} {
  set toks [slickprop::build_fields .pf.f {name=E1 foobar=9} {name=x1}]
  check {PF19a build with an undeclared token succeeds (ttk::separator path)} \
    {[lsearch -exact $toks foobar] >= 0}
  check {PF19b the undeclared token's entry exists (Extra section)} \
    {[winfo exists $slickprop::cur(entry,foobar)]}
  gui_done
} else { check {PF19a (skip)} {1}; check {PF19b (skip)} {1} }

# ===========================================================================
# PF20-PF25 — P1 multi-instance "Apply to" scope (the default-behavior FIX +
# the sticky scope selector + name-greying + per-Apply undo). The apply runs
# through the REAL C path (xschem edit_prop -> edit_property(0) -> update_symbol),
# driven modally with an after-callback that edits the `value` field and clicks
# OK (mirroring PF16). A safety timer guarantees the suite can never hang.
# Throughout, ONLY changed fields are applied — instances keep their own names.
# ===========================================================================

# place 3 res.sym (R1..R3, value=1k) + one capa.sym (different master, value=1p)
proc pf_setup_insts {} {
  xschem set modified 0
  xschem clear force schematic
  xschem instance res.sym    0 0 0 0 {name=R1 value=1k}
  xschem instance res.sym  100 0 0 0 {name=R2 value=1k}
  xschem instance res.sym  200 0 0 0 {name=R3 value=1k}
  xschem instance capa.sym 300 0 0 0 {name=C1 value=1p}
}
# count instances whose `value` token == <v>
proc pf_count_value {v} {
  set n [xschem get instances]; set c 0
  for {set i 0} {$i < $n} {incr i} {
    if {[xschem get_tok [xschem getprop instance $i] value 2] eq $v} { incr c }
  }
  return $c
}

# --- generic modal driver (shared by P1 + P2 tests) ------------------------
# Open the real modal form under <scope> and run <body> once the field grid is
# actually built, by POLLING (not a fixed delay — under WSLg the build time
# varies and a fixed `after` races it). <body> runs at global scope and may
# close the dialog itself (ok/cancel); otherwise the poller cancels it. Pending
# timers are dropped on return so a stale one can't cancel a later test's dialog.
proc pf_tick {} {
  if {$::pf_done} return
  if {[winfo exists .dialog] && [info exists slickprop::cur(tokens)]} {
    set ::pf_ran 1
    if {[catch {uplevel #0 $::pf_body} m]} { set ::pf_err $m }
    catch {if {[winfo exists .dialog]} {slickprop::cancel}}
    return
  }
  incr ::pf_ticks
  if {$::pf_ticks > 150} { catch {if {[winfo exists .dialog]} {slickprop::cancel}}; return }
  after 40 pf_tick
}
proc pf_form_run {scope body} {
  set ::slickprop_apply_scope $scope
  set ::edit_symbol_prop_new_sel {}
  set ::pf_body $body
  set ::pf_ran 0
  set ::pf_err {}
  set ::pf_done 0
  set ::pf_ticks 0
  set a2 [after 12000 {catch {slickprop::cancel}}]  ;# hard safety: never hang
  after 40 pf_tick
  catch {xschem edit_prop}
  set ::pf_done 1                                   ;# stop any lingering poll
  after cancel $a2
  if {$::pf_err ne {}} { puts $::logfd "PFERR($scope): $::pf_err"; flush $::logfd }
}

# run one modal property edit through the C path under scope <scope>, editing
# the value field to <editval> and pressing OK.
proc pf_edit_value {scope editval} {
  set ::pf_editval $editval
  set ::pf_built 0
  pf_form_run $scope {
    set ::pf_built 1
    slickprop::placeholder_in value
    $slickprop::cur(entry,value) delete 0 end
    $slickprop::cur(entry,value) insert 0 $::pf_editval
    slickprop::ok
  }
}

if {[gui2_ok]} {
  ### PF20 — THE FIX: default scope = Only Current. Selecting 3 instances and
  ### editing `value` touches ONLY the displayed (first-selected) one — multi-
  ### select no longer silently edits them all.
  catch {unset ::slickprop_apply_scope}
  pf_setup_insts
  xschem select instance R1; xschem select instance R2; xschem select instance R3
  pf_edit_value current 2k
  check {PF20a the modal form built (value field present)} {$::pf_built == 1}
  check {PF20b scope=current edits exactly ONE instance} {[pf_count_value 2k] == 1}
  check {PF20c the other two are NOT silently edited (still 1k)} {[pf_count_value 1k] == 2}

  ### PF21 — scope = All Selected: all three selected get value=2k, each keeps
  ### its OWN name (changed-fields-only — name is never fanned out).
  pf_setup_insts
  xschem select instance R1; xschem select instance R2; xschem select instance R3
  pf_edit_value selected 2k
  check {PF21a scope=selected applies to all three selected} {[pf_count_value 2k] == 3}
  check {PF21b each instance kept its own name (changed-only)} \
    {[xschem get_tok [xschem getprop instance 0] name 2] eq "R1" &&
     [xschem get_tok [xschem getprop instance 1] name 2] eq "R2" &&
     [xschem get_tok [xschem getprop instance 2] name 2] eq "R3"}

  ### PF22 — scope = All (same master): selecting ONE res fans the change to
  ### ALL res instances by master; the capa (different master) is untouched.
  pf_setup_insts
  xschem select instance R1
  pf_edit_value all 2k
  check {PF22a scope=all fans to every same-master instance} {[pf_count_value 2k] == 3}
  check {PF22b a different-master instance is NEVER touched} \
    {[xschem get_tok [xschem getprop instance 3] value 2] eq "1p"}

  ### PF25 — one Apply = one undo: a single undo reverses the whole All-Selected
  ### change across every affected instance.
  pf_setup_insts
  xschem select instance R1; xschem select instance R2; xschem select instance R3
  pf_edit_value selected 2k
  set ::pf_n2k [pf_count_value 2k]
  xschem undo
  check {PF25 one undo reverses the entire All-Selected apply} \
    {$::pf_n2k == 3 && [pf_count_value 2k] == 0 && [pf_count_value 1k] == 3}
} else {
  foreach t {PF20a PF20b PF20c PF21a PF21b PF22a PF22b PF25} { check "$t (skipped: no main window)" {1} }
}

### PF23 — name greying: under scope selected/all the name entry is disabled;
### under current it is enabled. Live-toggled by slickprop::apply_scope_greying.
if {[gui_ok]} {
  slickprop::build_fields .pf.f {name=R1 value=1k} {name=R1 value=1k}
  set ::slickprop_apply_scope current; slickprop::apply_scope_greying
  set s_cur [$slickprop::cur(entry,name) cget -state]
  set ::slickprop_apply_scope selected; slickprop::apply_scope_greying
  set s_sel [$slickprop::cur(entry,name) cget -state]
  set ::slickprop_apply_scope all; slickprop::apply_scope_greying
  set s_all [$slickprop::cur(entry,name) cget -state]
  check {PF23a name entry ENABLED under scope=current}  {$s_cur eq "normal"}
  check {PF23b name entry DISABLED under scope=selected} {$s_sel eq "disabled"}
  check {PF23c name entry DISABLED under scope=all}      {$s_all eq "disabled"}
  set ::slickprop_apply_scope current
  gui_done
} else { foreach t {PF23a PF23b PF23c} { check "$t (skip)" {1} } }

### PF24 — the scope label<->value mapping round-trips, and the scope var is
### STICKY (edit_form must not reset an already-set ::slickprop_apply_scope).
check {PF24a scope_value inverts scope_label for every canonical value} \
  {[slickprop::scope_value [slickprop::scope_label current]]  eq "current" &&
   [slickprop::scope_value [slickprop::scope_label selected]] eq "selected" &&
   [slickprop::scope_value [slickprop::scope_label all]]      eq "all"}
if {[gui2_ok]} {
  pf_setup_insts
  xschem select instance R1
  set ::slickprop_apply_scope all
  after 300 {catch {slickprop::cancel}}
  catch {xschem edit_prop}
  check {PF24b scope persists across a form open (sticky, not reset)} \
    {$::slickprop_apply_scope eq "all"}
} else { check {PF24b (skipped: no main window)} {1} }

# ===========================================================================
# PF26-PF30 — P2: the Apply button (apply + stay open) and Next/Prev navigation
# through the selected set, with per-Apply undo and navigation-discards-pending.
# These step the displayed instance and apply mid-session via the new
# `xschem apply_properties` command, all inside a single after-callback (every
# step — edit, Apply, Next/Prev — is synchronous; only the modal wait blocks).
# ===========================================================================

# the value token of the (first) instance whose name == <nm>
proc pf_value_of_name {nm} {
  set n [xschem get instances]
  for {set i 0} {$i < $n} {incr i} {
    if {[xschem get_tok [xschem getprop instance $i] name 2] eq $nm} {
      return [xschem get_tok [xschem getprop instance $i] value 2]
    }
  }
  return {}
}
# set a field's entry value (clearing a placeholder first)
proc pf_setfield {tok v} {
  slickprop::placeholder_in $tok
  $slickprop::cur(entry,$tok) delete 0 end
  $slickprop::cur(entry,$tok) insert 0 $v
}

if {[gui2_ok]} {
  ### PF26 — the Apply button applies the change set to the scope and KEEPS the
  ### dialog open (scope=current touches only the displayed instance).
  pf_setup_insts
  xschem select instance R1; xschem select instance R2; xschem select instance R3
  pf_form_run current {
    pf_setfield value 2k
    slickprop::apply_now
    set ::pf26_open  [winfo exists .dialog]
    set ::pf26_n2k   [pf_count_value 2k]
    set ::pf26_dispv [slickprop::field_value value]
  }
  check {PF26a the form ran} {$::pf_ran == 1}
  check {PF26b Apply leaves the dialog OPEN (apply + stay)} {$::pf26_open == 1}
  check {PF26c Apply applied to exactly one instance (scope=current)} {$::pf26_n2k == 1}
  check {PF26d after Apply the displayed value is the applied value (new baseline)} \
    {$::pf26_dispv eq "2k"}

  ### PF27 — Next/Prev walk the selected set: the displayed instance changes,
  ### the position readout tracks, Prev is disabled at first / Next at last.
  pf_setup_insts
  xschem select instance R1; xschem select instance R2; xschem select instance R3
  pf_form_run current {
    set ::pf27_n     [llength $slickprop::nav(ids)]
    set ::pf27_pos0  $slickprop::nav(pos)
    set ::pf27_name0 [slickprop::field_value name]
    set ::pf27_prev0 [.dialog.fnav.prev cget -state]
    slickprop::nav 1
    set ::pf27_name1 [slickprop::field_value name]
    set ::pf27_pos1  $slickprop::nav(pos)
    slickprop::nav 1
    set ::pf27_next2 [.dialog.fnav.next cget -state]
  }
  check {PF27a all three selected are the nav set} {$::pf27_n == 3}
  check {PF27b Prev is disabled at the first instance} {$::pf27_prev0 eq "disabled"}
  check {PF27c Next advances the displayed instance (name changes)} \
    {$::pf27_name0 ne $::pf27_name1 && $::pf27_name0 ne "" && $::pf27_name1 ne ""}
  check {PF27d the position advances by one} {$::pf27_pos1 == $::pf27_pos0 + 1}
  check {PF27e Next is disabled at the last instance} {$::pf27_next2 eq "disabled"}

  ### PF28 — navigating away from a DIRTY instance now ASKS (M1): the prompt's
  ### Discard drops the edit and steps; stepping shows the next with its own
  ### values. (Was a silent discard; M1 folds Next/Prev into the apply prompt.)
  pf_setup_insts
  xschem select instance R1; xschem select instance R2; xschem select instance R3
  pf_form_run current {
    proc ::tk_messageBox {args} {return no}   ;# Discard
    pf_setfield value 9k
    slickprop::nav 1
    slickprop::nav -1
    set ::pf28_back [slickprop::field_value value]
    set ::pf28_n9k  [pf_count_value 9k]
  }
  proc ::tk_messageBox {args} {return ok}
  check {PF28a Discard on nav: stepping back shows the original value} {$::pf28_back eq "1k"}
  check {PF28b no instance was modified by the discarded edit} {$::pf28_n9k == 0}

  ### PF28c — Cancel on a dirty nav stays put (does not step, keeps the edit).
  pf_setup_insts
  xschem select instance R1; xschem select instance R2; xschem select instance R3
  pf_form_run current {
    set ::pf28c_pos0 $slickprop::nav(pos)
    proc ::tk_messageBox {args} {return cancel}
    pf_setfield value 8k
    slickprop::nav 1
    set ::pf28c_pos1 $slickprop::nav(pos)
    set ::pf28c_val  [slickprop::field_value value]
  }
  proc ::tk_messageBox {args} {return ok}
  check {PF28c-pos Cancel on nav does not change position} {$::pf28c_pos1 == $::pf28c_pos0}
  check {PF28c-val Cancel on nav keeps the pending edit} {$::pf28c_val eq "8k"}

  ### PF29 — OK after stepping applies to the CURRENTLY displayed instance only
  ### (scope=current), not the originally-displayed one.
  pf_setup_insts
  xschem select instance R1; xschem select instance R2; xschem select instance R3
  pf_form_run current {
    set ::pf29_name0 [slickprop::field_value name]
    slickprop::nav 1
    set ::pf29_name1 [slickprop::field_value name]
    pf_setfield value 5k
    slickprop::ok
  }
  check {PF29a OK applied to the stepped-to instance} {[pf_value_of_name $::pf29_name1] eq "5k"}
  check {PF29b the originally-displayed instance is untouched} {[pf_value_of_name $::pf29_name0] eq "1k"}
  check {PF29c exactly one instance changed (not the whole selection)} {[pf_count_value 5k] == 1}

  ### PF30 — per-Apply undo: two Applies on two instances are two separate undo
  ### entries; one undo reverses only the most recent.
  pf_setup_insts
  xschem select instance R1; xschem select instance R2; xschem select instance R3
  pf_form_run current {
    set ::pf30_nm0 [slickprop::field_value name]
    pf_setfield value 2k
    slickprop::apply_now
    slickprop::nav 1
    set ::pf30_nm1 [slickprop::field_value name]
    pf_setfield value 3k
    slickprop::apply_now
    slickprop::cancel
  }
  check {PF30a both per-instance applies took} \
    {[pf_value_of_name $::pf30_nm0] eq "2k" && [pf_value_of_name $::pf30_nm1] eq "3k"}
  xschem undo
  check {PF30b one undo reverses only the most recent apply} \
    {[pf_value_of_name $::pf30_nm1] eq "1k" && [pf_value_of_name $::pf30_nm0] eq "2k"}
  xschem undo
  check {PF30c a second undo reverses the earlier apply} {[pf_value_of_name $::pf30_nm0] eq "1k"}
} else {
  foreach t {PF26a PF26b PF26c PF26d PF27a PF27b PF27c PF27d PF27e PF28a PF28b
             PF28c-pos PF28c-val
             PF29a PF29b PF29c PF30a PF30b PF30c} { check "$t (skipped: no main window)" {1} }
}

# ===========================================================================
# PF31-PF34 — P3: the "values differ" warning. Under All Selected / All, when
# the FOCUSED field's value is not uniform across the in-scope instances, the
# footer hint turns into a red warning (applying would overwrite those differing
# values). It clears when the field is uniform across the set or scope=current.
# ===========================================================================

# place 3 res with DIFFERING values (R1/R3 = 1k, R2 = 2k) + a capa (other master)
proc pf_setup_varied {} {
  xschem set modified 0
  xschem clear force schematic
  xschem instance res.sym    0 0 0 0 {name=R1 value=1k}
  xschem instance res.sym  100 0 0 0 {name=R2 value=2k}
  xschem instance res.sym  200 0 0 0 {name=R3 value=1k}
  xschem instance capa.sym 300 0 0 0 {name=C1 value=1p}
}

if {[gui2_ok]} {
  ### PF31 — scope=selected: a varying field (value) warns red; a uniform field
  ### (footprint, unset on all) restores the muted hint.
  pf_setup_varied
  xschem select instance R1; xschem select instance R2; xschem select instance R3
  pf_form_run selected {
    slickprop::on_focus value
    set ::pf31_fg  [.dialog.fb.hint cget -foreground]
    set ::pf31_tx  [.dialog.fb.hint cget -text]
    slickprop::on_focus footprint
    set ::pf31_fg2 [.dialog.fb.hint cget -foreground]
  }
  check {PF31a a varying focused field warns in the warn color} \
    {$::pf31_fg eq [slickprop::warn_color]}
  check {PF31b the warning text names the field} {[string match {*value*} $::pf31_tx]}
  check {PF31c a uniform field restores the muted hint (not warn color)} \
    {$::pf31_fg2 ne [slickprop::warn_color]}

  ### PF32 — scope=current never warns, even for a field that varies across the
  ### (unviewed) selection.
  pf_setup_varied
  xschem select instance R1; xschem select instance R2; xschem select instance R3
  pf_form_run current {
    slickprop::on_focus value
    set ::pf32_fg [.dialog.fb.hint cget -foreground]
  }
  check {PF32 scope=current suppresses the varying-value warning} \
    {$::pf32_fg ne [slickprop::warn_color]}

  ### PF33 — scope=all: the in-scope set is every same-master instance, and a
  ### value varying across them warns.
  pf_setup_varied
  xschem select instance R1
  pf_form_run all {
    set ::pf33_n  [llength [slickprop::scope_instances]]
    slickprop::on_focus value
    set ::pf33_fg [.dialog.fb.hint cget -foreground]
  }
  check {PF33a all-scope sees every same-master instance (3 res, not the capa)} \
    {$::pf33_n == 3}
  check {PF33b all-scope varying value warns} {$::pf33_fg eq [slickprop::warn_color]}

  ### PF34 — live: switching scope current->selected updates the warning without
  ### re-focusing (the scope-change path refreshes it).
  pf_setup_varied
  xschem select instance R1; xschem select instance R2; xschem select instance R3
  pf_form_run current {
    slickprop::on_focus value
    set ::pf34_cur [.dialog.fb.hint cget -foreground]
    set ::slickprop_apply_scope selected
    set ::pf34_sel [.dialog.fb.hint cget -foreground]
  }
  check {PF34a current scope: focused varying field does not warn} \
    {$::pf34_cur ne [slickprop::warn_color]}
  check {PF34b switching to selected live-updates to the warning} \
    {$::pf34_sel eq [slickprop::warn_color]}
} else {
  foreach t {PF31a PF31b PF31c PF32 PF33a PF33b PF34a PF34b} {
    check "$t (skipped: no main window)" {1} }
}

# ===========================================================================
# PF35 — `xschem edit_prop <scope>`: an optional scope arg pins "Apply to" for
# this open (and persists it, since the scope is sticky), so a keybinding can
# launch the form straight into Only Current / All Selected / All. A bad scope
# is rejected without opening the dialog.
# ===========================================================================

# open via `xschem edit_prop <arg>`, return the scope the built form sees, cancel
proc pf_edit_prop_arg {arg} {
  set ::pf_done 0; set ::pf_ticks 0; set ::pf_seen {}
  proc ::pf_argtick {} {
    if {$::pf_done} return
    if {[winfo exists .dialog] && [info exists slickprop::cur(tokens)]} {
      set ::pf_seen $::slickprop_apply_scope
      catch {slickprop::cancel}
      return
    }
    incr ::pf_ticks
    if {$::pf_ticks > 150} { catch {if {[winfo exists .dialog]} {slickprop::cancel}}; return }
    after 40 ::pf_argtick
  }
  set safe [after 12000 {catch {slickprop::cancel}}]
  after 40 ::pf_argtick
  catch {eval xschem edit_prop $arg}
  set ::pf_done 1
  after cancel $safe
  return $::pf_seen
}

if {[gui2_ok]} {
  pf_setup_insts
  xschem select instance R1; xschem select instance R2; xschem select instance R3
  set ::slickprop_apply_scope current
  check {PF35a edit_prop selected launches the form in All Selected scope} \
    {[pf_edit_prop_arg selected] eq "selected"}
  check {PF35b the arg persists (scope is sticky)} {$::slickprop_apply_scope eq "selected"}
  check {PF35c edit_prop current launches in Only Current} \
    {[pf_edit_prop_arg current] eq "current"}
  check {PF35d edit_prop all launches in All (same symbol)} \
    {[pf_edit_prop_arg all] eq "all"}
  check {PF35e a bad scope is rejected (error, no dialog)} \
    {[catch {xschem edit_prop bogus}] == 1 && ![winfo exists .dialog]}
  check {PF35f the rejected arg did NOT change the sticky scope} \
    {$::slickprop_apply_scope eq "all"}
} else {
  foreach t {PF35a PF35b PF35c PF35d PF35e PF35f} { check "$t (skipped: no main window)" {1} }
}

# ===========================================================================
# PF36-PF39 — H1 of the apply-scope highlight: the white-outline overlay
# primitive + the Only Current scope, driven by a stable id. The overlay marks
# exactly the OK/Apply target set; C resolves it the same way apply_symbol_prop
# does (shared scope_targets()), so "outlined set == applied set" by
# construction. Commands (decision doc D3):
#   xschem highlight_scope <scope> <displayed_id> -> set+redraw, returns the
#       resolved stable-id list (so a test can assert it == the apply set);
#   xschem highlight_scope            -> the current overlay count;
#   xschem highlight_scope ids        -> the stored stable-id list;
#   xschem highlight_scope clear      -> empty the overlay + redraw;
#   xschem highlight_objects <type> <id> [<type> <id> ...] -> general primitive
#       (any drawable type in its natural shape; the dialog only ever feeds
#       instances, but this proves a WIRE is accepted/outlined as its line).
# These assertions are pixel-FREE (state, not colour); the look (white, halo,
# distinct from selection) is a manual eyeball item, noted in the spec.
# Every new-command call is guarded (catch / inside a check) so the RED phase
# fails cleanly instead of aborting the suite.
# ===========================================================================

### PF36 — Only Current: highlight_scope resolves to exactly the displayed
### instance (the applied set for scope=current), the count is 1, and clear
### empties it. Pixel-free, display-independent (the set is computed regardless
### of has_x), so this runs unconditionally.
catch {xschem highlight_scope clear}
pf_setup_insts
set ::pf36_rid [xschem instance_id R1]
check {PF36a current scope resolves to exactly the displayed instance id} \
  {[catch {xschem highlight_scope current $::pf36_rid} r] == 0 && $r eq $::pf36_rid}
check {PF36b the overlay holds exactly one object} \
  {[catch {xschem highlight_scope} c] == 0 && $c == 1}
check {PF36c the stored id list is the displayed instance} \
  {[catch {xschem highlight_scope ids} ids] == 0 && $ids eq $::pf36_rid}
catch {xschem highlight_scope clear}
check {PF36d clear empties the overlay} \
  {[catch {xschem highlight_scope} c] == 0 && $c == 0}

### PF37 — the form drives the overlay: active (count 1 under Only Current) while
### the modal is open, cleared to 0 on every close path. Needs the GUI + the
### property_form wiring (update_highlight on open, clear in ok/cancel).
if {[gui2_ok]} {
  catch {xschem highlight_scope clear}
  pf_setup_insts
  xschem select instance R1; xschem select instance R2; xschem select instance R3
  set ::pf37_open -1
  pf_form_run current {
    catch {xschem highlight_scope} ::pf37_open
  }
  if {[catch {xschem highlight_scope} ::pf37_closed]} { set ::pf37_closed -1 }
  check {PF37a overlay is active while the form is open (current = 1)} {$::pf37_open == 1}
  check {PF37b overlay is cleared after the form closes} {$::pf37_closed == 0}
} else {
  foreach t {PF37a PF37b} { check "$t (skipped: no main window)" {1} }
}

### PF38 — live update on Next/Prev: under Only Current the single outline
### follows the displayed instance as the user steps through the selected set.
if {[gui2_ok]} {
  catch {xschem highlight_scope clear}
  pf_setup_insts
  xschem select instance R1; xschem select instance R2; xschem select instance R3
  pf_form_run current {
    set ::pf38_disp0 $slickprop::nav(disp_id)
    set ::pf38_hi0   [xschem highlight_scope ids]
    slickprop::nav 1
    set ::pf38_disp1 $slickprop::nav(disp_id)
    set ::pf38_hi1   [xschem highlight_scope ids]
  }
  check {PF38a the displayed instance actually changed on Next} \
    {$::pf38_disp0 ne $::pf38_disp1}
  check {PF38b the overlay initially marks the displayed instance} \
    {$::pf38_hi0 eq $::pf38_disp0}
  check {PF38c after Next the overlay follows to the new displayed instance} \
    {$::pf38_hi1 eq $::pf38_disp1}
} else {
  foreach t {PF38a PF38b PF38c} { check "$t (skipped: no main window)" {1} }
}

### PF39 — the primitive is GENERAL: highlight_objects accepts a WIRE and holds
### it in the overlay (rendered as its line segment, not a box). Proves the
### per-type dispatch exists even though the dialog only feeds instances.
catch {xschem highlight_scope clear}
xschem set modified 0
xschem clear force schematic
xschem wire 0 0 100 0
set ::pf39_wid [xschem wire_id 0]
check {PF39a highlight_objects accepts a wire (general primitive, wire-as-line)} \
  {[catch {xschem highlight_objects wire $::pf39_wid} r] == 0 &&
   [catch {xschem highlight_scope} c] == 0 && $c == 1}
catch {xschem highlight_scope clear}
check {PF39b clear empties the general overlay too} \
  {[catch {xschem highlight_scope} c] == 0 && $c == 0}

# ===========================================================================
# PF40-PF46 — M1 of the modeless, selection-reactive form: while the dialog is
# open the user can keep selecting on the canvas, and the form reacts (the nav
# set, scope, "values differ" warning and the white highlight follow the new
# selection). The C side unlocks SELECTION gestures at semaphore>=2 (move/wire/
# place stay locked) and fires `slickprop::on_selection_changed`; these tests
# drive that Tcl reaction directly (selection changed via `xschem select`, then
# the hook called) the same way the P3/H1 tests drive on_focus / nav — the C
# event gate itself is a manual eyeball item (synthetic ButtonPress is WSLg-
# flaky). Decision doc: code_analysis/modeless_property_form_decision.md.
#
# Pending-edit policy (D2, ratified = Cadence prompt): a selection change while
# the form is dirty pops a 3-way tk_messageBox — Apply / Discard / Cancel (the
# last restores the previous selection and stays put). A clean change switches
# silently. Tests stub tk_messageBox per case (and restore the suite's default).
# ===========================================================================

if {[gui2_ok]} {
  ### PF40 — is_dirty: a freshly opened form is clean; editing a field makes it
  ### dirty (the gate that decides whether a selection change prompts).
  catch {xschem highlight_scope clear}
  pf_setup_insts
  xschem select instance R1
  pf_form_run current {
    set ::pf40_clean [slickprop::is_dirty]
    pf_setfield value 9k
    set ::pf40_dirty [slickprop::is_dirty]
  }
  check {PF40a a freshly opened form is not dirty} {$::pf40_clean == 0}
  check {PF40b an edited field makes the form dirty} {$::pf40_dirty == 1}

  ### PF41 — clean selection change adopts the new selection: the nav set follows
  ### the canvas, and (current scope, single click) the displayed instance
  ### retargets to the newly selected one.
  pf_setup_insts
  xschem select instance R1; xschem select instance R2; xschem select instance R3
  pf_form_run current {
    xschem unselect_all
    xschem select instance R3
    slickprop::on_selection_changed
    set ::pf41_ids  $slickprop::nav(ids)
    set ::pf41_disp $slickprop::nav(disp_id)
  }
  set ::pf41_r3 [xschem instance_id R3]
  check {PF41a the nav set follows the new canvas selection} {$::pf41_ids eq $::pf41_r3}
  check {PF41b displayed instance retargets to the newly selected one} {$::pf41_disp eq $::pf41_r3}

  ### PF42 — the white highlight follows a selection change (ties M1 to H1):
  ### under All Selected, outlined set == the new selected set.
  pf_setup_insts
  xschem select instance R1; xschem select instance R2; xschem select instance R3
  pf_form_run selected {
    xschem unselect_all
    xschem select instance R1
    xschem select instance R2
    slickprop::on_selection_changed
    set ::pf42_hc  [xschem highlight_scope]
    set ::pf42_ids [lsort [xschem highlight_scope ids]]
  }
  set ::pf42_exp [lsort [list [xschem instance_id R1] [xschem instance_id R2]]]
  check {PF42a highlight count tracks the new selection (2)} {$::pf42_hc == 2}
  check {PF42b outlined set == the new selected set} {$::pf42_ids eq $::pf42_exp}

  ### PF43 — dirty change, Apply path: the prompt's "Apply" writes the edited
  ### (old) instance, then the form moves to the new selection.
  pf_setup_insts
  xschem select instance R1; xschem select instance R2; xschem select instance R3
  pf_form_run current {
    pf_setfield value 7k
    proc ::tk_messageBox {args} {return yes}
    xschem unselect_all; xschem select instance R3
    slickprop::on_selection_changed
    set ::pf43_disp $slickprop::nav(disp_id)
  }
  proc ::tk_messageBox {args} {return ok}
  check {PF43a Apply writes the edited (old) instance} {[pf_value_of_name R1] eq "7k"}
  check {PF43b after Apply the form moves to the new instance} {$::pf43_disp eq [xschem instance_id R3]}
  check {PF43c only the edited instance changed (scope=current)} {[pf_count_value 7k] == 1}

  ### PF44 — dirty change, Discard path: edits dropped, old instance unchanged,
  ### form still moves to the new selection.
  pf_setup_insts
  xschem select instance R1; xschem select instance R2; xschem select instance R3
  pf_form_run current {
    pf_setfield value 6k
    proc ::tk_messageBox {args} {return no}
    xschem unselect_all; xschem select instance R3
    slickprop::on_selection_changed
    set ::pf44_disp $slickprop::nav(disp_id)
  }
  proc ::tk_messageBox {args} {return ok}
  check {PF44a Discard leaves the old instance unedited} {[pf_value_of_name R1] eq "1k"}
  check {PF44b Discard still moves the form to the new instance} {$::pf44_disp eq [xschem instance_id R3]}

  ### PF45 — dirty change, Cancel path: stay on the original instance, drop
  ### nothing/write nothing, and RESTORE the previous canvas selection so the
  ### form, selection and highlight stay in agreement.
  pf_setup_insts
  xschem select instance R1; xschem select instance R2; xschem select instance R3
  pf_form_run current {
    set ::pf45_disp0 $slickprop::nav(disp_id)
    pf_setfield value 5k
    proc ::tk_messageBox {args} {return cancel}
    xschem unselect_all; xschem select instance R3
    slickprop::on_selection_changed
    set ::pf45_disp1  $slickprop::nav(disp_id)
    set ::pf45_selids [lsort [slickprop::selected_inst_ids]]
  }
  proc ::tk_messageBox {args} {return ok}
  set ::pf45_all [lsort [list [xschem instance_id R1] [xschem instance_id R2] [xschem instance_id R3]]]
  check {PF45a Cancel keeps the form on the original instance} {$::pf45_disp1 eq $::pf45_disp0}
  check {PF45b Cancel leaves the old instance unedited} {[pf_value_of_name R1] eq "1k"}
  check {PF45c Cancel restores the previous selection} {$::pf45_selids eq $::pf45_all}

  ### PF46 — a CLEAN selection change does not prompt (no nag on every click).
  pf_setup_insts
  xschem select instance R1; xschem select instance R2; xschem select instance R3
  set ::pf46_calls 0
  pf_form_run current {
    proc ::tk_messageBox {args} {incr ::pf46_calls; return ok}
    xschem unselect_all; xschem select instance R2
    slickprop::on_selection_changed
  }
  proc ::tk_messageBox {args} {return ok}
  check {PF46 a clean selection change does not prompt} {$::pf46_calls == 0}
} else {
  foreach t {PF40a PF40b PF41a PF41b PF42a PF42b PF43a PF43b PF43c
             PF44a PF44b PF45a PF45b PF45c PF46} { check "$t (skipped: no main window)" {1} }
}

# ===========================================================================
# PF47 — action-logging the property apply. An interactive form Apply/OK should
# append its replayable EFFECT to the action log:
#     xschem apply_properties <scope> <displayed_id> <new_prop> <old_prop>
# Logged at the INTERACTIVE layer (slickprop::do_apply), NOT in the engine
# apply_instance_properties() — logging the engine would double-log CIW-typed
# applies and re-log on replay (the action-log invariant; see
# code_analysis/apply_properties_logging_decision.md). The emit goes through a
# thin seam slickprop::log_apply (wrapping `xschem log_action`); tests SPY on
# that seam (same technique as the tk_messageBox stub) so the assertions cover
# the decision logic (when + exact line) without depending on the log file path.
# ===========================================================================

if {[gui2_ok]} {
  # spy: capture every logged apply line (overrides the real seam for the suite)
  proc slickprop::log_apply {line} { lappend ::pf47_log $line }

  ### PF47a/b/c — OK with an edit logs exactly one replayable apply line that
  ### names the scope, the new value, and (for changed-fields-only replay) the
  ### old value.
  pf_setup_insts
  xschem select instance R1
  set ::pf47_log {}
  pf_form_run current {
    pf_setfield value 2k
    slickprop::ok
  }
  check {PF47a OK-with-edit logs exactly one apply line} {[llength $::pf47_log] == 1}
  check {PF47b the line is the replayable apply command (scope + new value)} \
    {[string match "xschem apply_properties current *value=*2k*" [lindex $::pf47_log 0]]}
  check {PF47c the line carries the old value too (changed-fields-only replay)} \
    {[string match "*value=1k*" [lindex $::pf47_log 0]]}

  ### PF47d — a no-op OK (no edit) logs nothing (log effects, not intentions).
  pf_setup_insts
  xschem select instance R1
  set ::pf47_log {}
  pf_form_run current {
    slickprop::ok
  }
  check {PF47d a no-op OK logs nothing} {[llength $::pf47_log] == 0}

  ### PF47e — the Apply button (apply_now) also logs (it routes through do_apply).
  pf_setup_insts
  xschem select instance R1
  set ::pf47_log {}
  pf_form_run current {
    pf_setfield value 3k
    slickprop::apply_now
  }
  check {PF47e the Apply button also logs the apply} \
    {[llength $::pf47_log] == 1 && [string match "*value=*3k*" [lindex $::pf47_log 0]]}
} else {
  foreach t {PF47a PF47b PF47c PF47d PF47e} { check "$t (skipped: no main window)" {1} }
}

# ===========================================================================
# PF48 — log the form LAUNCH as a NON-REPLAYABLE marker. Opening the form should
# record that the editor was launched — but as a `#` comment, NOT a replayable
# `xschem edit_prop` line: edit_prop opens a modal, so a replayable line would
# re-open/hang the dialog on replay (and the launch is an intention, not an
# effect — only the apply is replayable). Emitted via slickprop::log_event at
# slickprop::edit_form (the one point every launch route converges on); the test
# spies on that seam. Read AFTER the run (the marker is emitted synchronously in
# edit_form, before tkwait — so this is robust to the modal-build flake).
# Decision doc §6: code_analysis/apply_properties_logging_decision.md.
# ===========================================================================

if {[gui2_ok]} {
  proc slickprop::log_event {line} { lappend ::pf48_log $line }
  catch {xschem highlight_scope clear}
  pf_setup_insts
  xschem select instance R1
  set ::pf48_log {}
  pf_form_run current { slickprop::cancel }
  check {PF48a opening the form logs exactly one launch marker} {[llength $::pf48_log] == 1}
  check {PF48b the marker is a NON-replayable comment (begins with #)} \
    {[string index [lindex $::pf48_log 0] 0] eq "#"}
  check {PF48c the marker names edit_prop and the scope} \
    {[string match "#*edit_prop*current*" [lindex $::pf48_log 0]]}
} else {
  foreach t {PF48a PF48b PF48c} { check "$t (skipped: no main window)" {1} }
}

# ===========================================================================
# PF49-PF50 — H2: drive the scope highlight for All Selected + All (same symbol),
# and prove "outlined == applied" for those scopes incl. the mixed-master D7 rule
# (the displayed instance's master decides the edited kind). PF49 asserts the
# highlight TARGET SET per scope directly via `xschem highlight_scope <scope>
# <id>` (pixel-free, standalone — the set is resolved by the shared scope_targets
# the apply also uses). PF50 proves the APPLY side of the same rule (the
# previously-untested mixed-master selected apply). Decision doc §7/D7.
# ===========================================================================

catch {xschem highlight_scope clear}
pf_setup_insts        ;# R1,R2,R3 = res (1k); C1 = capa (1p) — a different master
set ::pf49_r1 [xschem instance_id R1]
set ::pf49_r2 [xschem instance_id R2]
set ::pf49_r3 [xschem instance_id R3]
set ::pf49_c1 [xschem instance_id C1]
set ::pf49_res [lsort [list $::pf49_r1 $::pf49_r2 $::pf49_r3]]

### PF49a — All Selected: outline the selected same-master instances.
xschem unselect_all
xschem select instance R1; xschem select instance R2; xschem select instance R3
check {PF49a All Selected outlines the selected same-master set (3 res)} \
  {[lsort [xschem highlight_scope selected $::pf49_r1]] eq $::pf49_res}

### PF49b — All (same symbol): outline every same-master instance, including the
### ones not selected (only R1 selected here, but R2/R3 still outline).
xschem unselect_all
xschem select instance R1
check {PF49b All (same symbol) outlines every same-master instance incl. unselected} \
  {[lsort [xschem highlight_scope all $::pf49_r1]] eq $::pf49_res}

### PF49c — mixed selection + D7: select 3 res AND the capa, edit a res, scope
### selected -> only the res are outlined; the capa (different master) is excluded.
xschem unselect_all
xschem select instance R1; xschem select instance R2; xschem select instance R3
xschem select instance C1
set ::pf49_mix [lsort [xschem highlight_scope selected $::pf49_r1]]
check {PF49c mixed selection outlines only the displayed master (capa excluded)} \
  {$::pf49_mix eq $::pf49_res && [lsearch -exact $::pf49_mix $::pf49_c1] < 0}

### PF49d — All from a res never reaches the capa (different master).
check {PF49d All (same symbol) never includes a different master} \
  {[lsearch -exact [xschem highlight_scope all $::pf49_r1] $::pf49_c1] < 0 &&
   [llength [xschem highlight_scope all $::pf49_r1]] == 3}
catch {xschem highlight_scope clear}

### PF50 — the APPLY side of D7 (was untested: PF21 used a homogeneous selection).
### Select 3 res + the capa, edit `value` under All Selected: only the same-master
### res are written; the capa is left alone. Proves outlined(PF49c) == applied.
if {[gui2_ok]} {
  pf_setup_insts
  xschem select instance R1; xschem select instance R2; xschem select instance R3
  xschem select instance C1
  pf_edit_value selected 2k
  check {PF50a selected apply writes only the same-master instances (3 res)} \
    {[pf_count_value 2k] == 3}
  check {PF50b the capa (different master) is untouched} \
    {[xschem get_tok [xschem getprop instance 3] value 2] eq "1p"}
} else {
  foreach t {PF50a PF50b} { check "$t (skipped: no main window)" {1} }
}

# ===========================================================================
# PF51 — H3 polish: (a/b) the overlay SURVIVES a redraw — the D2 persistence the
# whole design rests on (re-stroked at the end of draw(), so pan/zoom keep it);
# (c) the completed per-type primitive renders every drawable type, including
# TEXT (its bounding box), without error. Pixel correctness (colour on both
# themes, halo thickness, distinct-from-selection, the text box shape) is a
# manual eyeball item — see code_analysis/apply_scope_highlight_decision.md.
# ===========================================================================

catch {xschem highlight_scope clear}
pf_setup_insts
set ::pf51_r1 [xschem instance_id R1]
xschem unselect_all; xschem select instance R1
set ::pf51_ids [lsort [xschem highlight_scope all $::pf51_r1]]
xschem redraw
check {PF51a the overlay survives a redraw (count unchanged)} \
  {[xschem highlight_scope] == 3}
check {PF51b the overlay survives a redraw (stored ids unchanged)} \
  {[lsort [xschem highlight_scope ids]] eq $::pf51_ids}

# the completed primitive: a mixed overlay incl. a TEXT redraws cleanly
xschem set modified 0
xschem clear force schematic
xschem instance res.sym 0 0 0 0 {name=R1 value=1k}
xschem wire 0 0 100 0
xschem text 0 50 0 0 hello {} 0.4 0
set ::pf51_iid [xschem instance_id R1]
set ::pf51_wid [xschem wire_id 0]
set ::pf51_tid [xschem text_id 0]
check {PF51c instance+wire+text overlay renders without error (count 3)} \
  {[catch {xschem highlight_objects instance $::pf51_iid wire $::pf51_wid text $::pf51_tid} r] == 0 &&
   [catch {xschem redraw} e] == 0 && [xschem highlight_scope] == 3}
catch {xschem highlight_scope clear}

xschem set modified 0

# ===========================================================================
# Slick enter_text dialog — discoverable text attributes.
# Spec: specs/slick_text_dialog.md. Scope: enter_text first, common visual
# attrs. Widget-independent CORE under test:
#   slickprop::text_schema          -> ordered static field descriptors for the
#                                      tokens the Appearance panel OWNS.
#   slickprop::text_fields <props>  -> the schema list with each token's current
#                                      value parsed out of <props> (+present flag).
#   slickprop::text_extra  <props>  -> the leftover "Other properties" string:
#                                      <props> with the owned tokens stripped, the
#                                      rest preserved (round-trips verbatim).
# Assembly reuses the existing subst-into-original slickprop::apply (no new proc).
# RED first: text_schema/text_fields/text_extra do not exist yet -> TX1..TX5 fail;
# TX6..TX7 exercise the already-present apply (the reuse contract).
# ===========================================================================

proc f_tschema {}  { if {[catch {slickprop::text_schema} r]}   {return -2}; return $r }
proc f_tfields {p} { if {[catch {slickprop::text_fields $p} r]} {return -2}; return $r }
proc f_textra  {p} { if {[catch {slickprop::text_extra $p} r]}  {return -2}; return $r }
proc f_trow {fields tok} {
  if {$fields eq "-2"} {return {}}
  foreach row $fields { if {[f_dg $row tok] eq $tok} {return $row} }
  return {}
}
proc tx_toks {fields} {
  if {$fields eq "-2"} {return {}}
  set t {}; foreach r $fields { lappend t [f_dg $r tok] }; return $t
}

### TX1 — the static schema: the owned tokens, in form-display order, each with
### its widget kind. Size (hsize/vsize) is NOT here — it is a separate xscale/
### yscale pair the dialog already carries.
set ::SC [f_tschema]
check {TX1a schema lists 8 owned fields} {[llength $::SC] == 8}
check {TX1b schema order = font weight slant hcenter vcenter layer hide floater} \
  {[tx_toks $::SC] eq {font weight slant hcenter vcenter layer hide floater}}
check {TX1c weight is a bool widget whose checked value is 'bold'} \
  {[f_dg [f_trow $::SC weight] widget] eq "bool" && [f_dg [f_trow $::SC weight] on] eq "bold"}
check {TX1d slant is a bool widget whose checked value is 'italic'} \
  {[f_dg [f_trow $::SC slant] widget] eq "bool" && [f_dg [f_trow $::SC slant] on] eq "italic"}
check {TX1e hcenter is a bool widget whose checked value is 'true'} \
  {[f_dg [f_trow $::SC hcenter] widget] eq "bool" && [f_dg [f_trow $::SC hcenter] on] eq "true"}
check {TX1f font is a combo widget} {[f_dg [f_trow $::SC font] widget] eq "combo"}
check {TX1g layer is a layer (colour swatch) widget} {[f_dg [f_trow $::SC layer] widget] eq "layer"}

### TX2 — parse current values out of a populated text prop string.
set ::P2 {font=Sans weight=bold slant=italic hcenter=true vcenter=true layer=4 hide=true floater=true}
set ::TF2 [f_tfields $::P2]
check {TX2a font value extracted clean}  {[f_dg [f_trow $::TF2 font] value]  eq "Sans"}
check {TX2b weight value 'bold'}         {[f_dg [f_trow $::TF2 weight] value] eq "bold"}
check {TX2c slant value 'italic'}        {[f_dg [f_trow $::TF2 slant] value]  eq "italic"}
check {TX2d hcenter value 'true'}        {[f_dg [f_trow $::TF2 hcenter] value] eq "true"}
check {TX2e layer value '4'}             {[f_dg [f_trow $::TF2 layer] value]   eq "4"}
check {TX2f hide value 'true'}           {[f_dg [f_trow $::TF2 hide] value]    eq "true"}
check {TX2g present flag set for a token in the string} {[f_dg [f_trow $::TF2 weight] present] == 1}

### TX3 — absent owned tokens: empty value, present=0 (so they are not written
### back unless the user actually toggles them).
set ::TF3 [f_tfields {font=Sans}]
check {TX3a absent weight -> empty value}  {[f_dg [f_trow $::TF3 weight] value] eq ""}
check {TX3b absent weight -> present=0}     {[f_dg [f_trow $::TF3 weight] present] == 0}
check {TX3c present font  -> present=1}      {[f_dg [f_trow $::TF3 font] present] == 1}

### TX4 — hide carries the non-bool value 'instance' (hide-when-instantiated);
### the value is preserved verbatim, not coerced to a bool.
check {TX4 hide=instance value preserved} {[f_dg [f_trow [f_tfields {hide=instance}] hide] value] eq "instance"}

### TX5 — the leftover "Other properties" string: owned tokens stripped, every
### other token (incl. unknown ones) preserved with its value.
set ::X5 [f_textra {name=note1 weight=bold font=Sans xyz=99}]
check {TX5a owned token weight removed from extra} {[lsearch [xschem list_tokens $::X5 0] weight] < 0}
check {TX5b owned token font removed from extra}   {[lsearch [xschem list_tokens $::X5 0] font] < 0}
check {TX5c unknown token name preserved in extra} {[lsearch [xschem list_tokens $::X5 0] name] >= 0}
check {TX5d unknown token xyz preserved in extra}  {[lsearch [xschem list_tokens $::X5 0] xyz] >= 0}
check {TX5e extra keeps the unknown token's value} {[xschem get_tok $::X5 name 2] eq "note1"}

### TX6 — assembly reuses slickprop::apply (subst-into-original): overlay the
### edited owned values onto a base string; unknown tokens survive, owned tokens
### land, an emptied value removes its token (Bold turned off).
set ::OUT6 [f_apply {name=note1 weight=bold font=Sans} {weight {} font Mono}]
check {TX6a unknown token name survives}     {[xschem get_tok $::OUT6 name 2] eq "note1"}
check {TX6b weight removed when turned off}  {[xschem get_tok $::OUT6 weight 2] eq ""}
check {TX6c font updated to Mono}            {[xschem get_tok $::OUT6 font 2] eq "Mono"}

### TX7 — the cardinal invariant carried to text props: assembling with no edits
### is byte-identical (apply with empty changes returns the original string).
check {TX7 no-edit assembly is byte-identical} {[f_apply {font=Sans weight=bold name=note1} {}] eq {font=Sans weight=bold name=note1}}

### TX8 — slickprop::text_assemble <orig> <desired> <extra>: the OK-time merge.
### <desired> is {tok val ...} for every owned field (val ""=off/absent); <extra>
### is the (maybe edited) Other-properties box. When <extra> is untouched it
### substs only the owned fields that changed into <orig> (byte-identical on no
### change); when <extra> is edited it rebuilds from <extra> + the set owned tokens.
proc f_assemble {o d e} { if {[catch {slickprop::text_assemble $o $d $e} r]} {return -2}; return $r }
set ::A_ORIG  {font=Sans weight=bold name=note1}
set ::A_EXTRA [f_textra $::A_ORIG]
set ::A_DES   {font Sans weight bold slant {} hcenter {} vcenter {} layer {} hide {} floater {}}
check {TX8a no change + extras untouched -> byte-identical} \
  {[f_assemble $::A_ORIG $::A_DES $::A_EXTRA] eq $::A_ORIG}
set ::A_DES2  {font Sans weight {} slant {} hcenter {} vcenter {} layer {} hide {} floater {}}
set ::A_OUT2  [f_assemble $::A_ORIG $::A_DES2 $::A_EXTRA]
check {TX8b Bold off removes weight; name preserved in place} \
  {[xschem get_tok $::A_OUT2 weight 2] eq "" && [xschem get_tok $::A_OUT2 name 2] eq "note1"}
set ::A_OUT3  [f_assemble $::A_ORIG $::A_DES {foo=bar}]
check {TX8c edited extras: new token foo present} {[xschem get_tok $::A_OUT3 foo 2] eq "bar"}
check {TX8d edited extras: set owned tokens still applied} \
  {[xschem get_tok $::A_OUT3 font 2] eq "Sans" && [xschem get_tok $::A_OUT3 weight 2] eq "bold"}
check {TX8e edited extras replace the old extras (orig-only name dropped)} \
  {[xschem get_tok $::A_OUT3 name 2] eq ""}

### TX9 — slickprop::text_bool_checked <tok> <value>: should a bool field's box be
### ticked for this current token value? (weight ticks only on 'bold'; slant ticks
### on italic OR oblique; the rest tick on any truthy, incl. hide=instance).
proc f_bchecked {t v} { if {[catch {slickprop::text_bool_checked $t $v} r]} {return -2}; return $r }
check {TX9a weight=bold -> ticked}        {[f_bchecked weight bold] == 1}
check {TX9b weight=normal -> unticked}    {[f_bchecked weight normal] == 0}
check {TX9c slant=italic -> ticked}       {[f_bchecked slant italic] == 1}
check {TX9d slant=oblique -> ticked}      {[f_bchecked slant oblique] == 1}
check {TX9e hcenter=true -> ticked}       {[f_bchecked hcenter true] == 1}
check {TX9f hide=instance -> ticked}      {[f_bchecked hide instance] == 1}
check {TX9g empty -> unticked}            {[f_bchecked floater {}] == 0}
check {TX9h false -> unticked}            {[f_bchecked hcenter false] == 0}

### TX10 — slickprop::text_bool_value <tok> <loaded> <chk0> <chk>: the token value
### to write on OK. Unchanged box (chk==chk0) preserves the LOADED raw value so an
### un-touched oblique/instance/normal is never clobbered; toggled on writes the
### schema on-value; toggled off removes (empty).
proc f_bvalue {t l c0 c} { if {[catch {slickprop::text_bool_value $t $l $c0 $c} r]} {return -2}; return $r }
check {TX10a unchanged keeps loaded 'oblique'}    {[f_bvalue slant oblique 1 1] eq "oblique"}
check {TX10b unchanged keeps loaded 'instance'}   {[f_bvalue hide instance 1 1] eq "instance"}
check {TX10c toggled on writes schema on-value}   {[f_bvalue weight {} 0 1] eq "bold"}
check {TX10d toggled off removes (empty)}         {[f_bvalue weight bold 1 0] eq ""}
check {TX10e unchanged-unticked keeps 'normal'}   {[f_bvalue weight normal 0 0] eq "normal"}
