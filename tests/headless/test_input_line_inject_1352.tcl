# tests/headless/test_input_line_inject_1352.tcl
#
# ISSUE 1352 -- `input_line`'s OK button ran what you typed as Tcl.
#
# `proc input_line` (src/xschem.tcl) builds its OK button's -command as a
# double-quoted string that used to contain
#
#     eval $cmd \[.dialog.f1.e get\]
#
# `eval` CONCATENATES its arguments into a script and evaluates that script, so
# the entry contents were spliced into a script instead of being handed to $cmd
# as a value. Typing
#
#     7 ; set ::INJECTED yes
#
# into the shipped Simulation > "Set netlist / graph / annotation precision"
# dialog set the precision AND ran the second command. Every caller shared the
# button, so "Set top level netlist name" (`xschem set netlist_name`) and
# View > "Set snap value" (`xschem set cadsnap`) had it too. This is inherited
# stock xschem code, on the branch that gets handed to other people.
#
# The fix is one line plus its guard:
#
#     if { {$cmd} ne {} && \[.dialog.f1.e get\] ne {} } {
#       eval $cmd \[list \[.dialog.f1.e get\]\]
#     }
#
# `list` makes the typed text exactly ONE list element whatever it holds, so the
# caller's fixed $cmd prefix receives it as a single argument. The emptiness
# guard holds the ONE behaviour `list` would otherwise have changed: with an
# empty entry the old form appended nothing, so `set X` was a harmless read and
# every `xschem ...` caller fell short of its own `argc` guard and did nothing.
# Quoted and unguarded, an empty entry becomes an explicit `{}`, and
# `xschem line_width {}` is change_linewidth(0) while `xschem set cadsnap {}` is
# set_snap(0) -> the default snap. Pressing OK on an emptied field must keep
# doing nothing.
#
# ===========================================================================
# ISSUE 1602 ALSO LIVES HERE -- the precision box accepted a value that broke
# every number it formats.
#
# The same `Simulation > Set netlist / graph / annotation precision` entry used
# to hand `input_line` the literal command `set ev_precision`, so whatever was
# typed became the precision. MEASURED through the shipped menu entry at
# c3ec73a3: `-1  2.5  abc  4x  +4  0x4  6.  6.0` all land VERBATIM, and so --
# since 2a22bfb7 let a value with a space survive -- do `" "`, `"4 5"` and
# `"7 ; set ::ILINJ yes"`. Every one of them then broke `format %.${pr}g`.
# Worse, `4f`, `4s` and `4e0` do NOT raise: they end the format specifier early
# and print a DIFFERENT NUMBER (a true 1.11e-05 became `11.1000gu`, `11.1gu`,
# `1.1100e+010gu`), so issue 1345's raw-text fallback never engages.
#
# The fix is `proc set_ev_precision` (src/xschem.tcl, above `proc to_eng`),
# called on `input_line`'s RETURN VALUE -- not as its $cmd, because input_line
# holds a grab across its OK callback and an alert raised from inside it cannot
# be clicked. Legal is a whole number 1..71, both bounds measured; the comment
# wall on the proc records why.
# ===========================================================================
#
# SECTIONS
#   S0-S5  STRUCTURAL, both arms: the shipped proc carries the quoted form and
#          the guard, carries no bare `eval $cmd \[.dialog.f1.e get\]` anywhere
#          in the file once comments are stripped, has exactly one `eval $cmd`,
#          and the <Return> binding still routes through the same OK button so
#          the Enter key cannot reach an unguarded path.
#   P1-P6  STRUCTURAL, both arms, ISSUE 1602: the precision menu entry routes
#          through set_ev_precision, the literal `set ev_precision` command is
#          gone from the file, and the proc still carries its digits-only
#          pattern, its 1..71 range test and its alert_.
#   B1-B19 BEHAVIOURAL, DISPLAY ARM ONLY: the real dialog is opened, hostile
#   P7-P17 text is put in the real entry widget, and the real OK button is
#          invoked from the event loop. `input_line` builds a Tk toplevel and
#          waits in `tkwait`, so none of it is reachable under --nogui, where
#          `toplevel` and `winfo` do not exist -- those rows print `skip:`.
#
# ARMED SPELLINGS
#   tests/headless/run_suites.sh test_input_line_inject_1352            (both)
#   tests/headless/run_suites.sh --nogui test_input_line_inject_1352    (S,P1-P6)
# Registered in tests/run_regression.tcl in BOTH `hcases` (structural rows, the
# B and P7-P17 rows self-skip) and `dcases` (everything).
#
# FLOOR: 13 checks headless (S0-S5, P1-P6), 58 on the display arm. Measured
# 2026-09-22. RAISED, NEVER LOWERED.

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }
proc skiprow {names why} { puts "skip: $names -- $why" ; flush stdout }

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]

set XTCL [file join $repo src xschem.tcl]

proc slurp {path} {
  if {![file exists $path]} { return ZZNOFILE }
  set fp [open $path r] ; set t [read $fp] ; close $fp
  return $t
}
## Comment lines removed. The fix's own comment block QUOTES the defective line
## verbatim, so a structural row that reads the raw file would answer "the bug
## is still here" forever.
proc nocomment {text} {
  set out {}
  foreach l [split $text "\n"] {
    if {[regexp {^[ \t]*#} $l]} { continue }
    lappend out $l
  }
  return [join $out "\n"]
}
proc scount {hay needle} {
  if {$needle eq {}} { return 0 }
  set n 0 ; set i 0
  while {[set i [string first $needle $hay $i]] >= 0} { incr n ; incr i }
  return $n
}
## The body of `proc input_line` only: from its `proc` line to the first
## column-0 `}`. Returns ZZNOPROC if the proc is not there at all, so a row
## cannot pass by finding nothing.
proc proc_body {src name} {
  set on 0 ; set out {}
  foreach l [split $src "\n"] {
    if {$on} {
      if {[regexp {^\}} $l]} { return [join $out "\n"] }
      lappend out $l
      continue
    }
    if {[regexp "^proc\[ \t\]+$name\[ \t\]" $l]} { set on 1 }
  }
  if {$on} { return [join $out "\n"] }
  return ZZNOPROC
}

set SRC  [slurp $XTCL]
set BODY [proc_body [nocomment $SRC] input_line]
set FILE [nocomment $SRC]

# ===========================================================================
# SECTION S -- STRUCTURAL. These run on BOTH arms and are what reddens if the
# fix is edited away textually without anybody opening a dialog.
# ===========================================================================
check_true {S0 proc input_line is still in src/xschem.tcl} \
  [expr {$BODY ne {ZZNOPROC} && $BODY ne {}}]

## S1 -- the quoted form is there, exactly once.
check {S1 OK button passes the entry through `list`} \
  [scount $BODY {eval $cmd \[list \[.dialog.f1.e get\]\]}] 1

## S2 -- and the defective form is not, anywhere in the proc.
check {S2 no bare `eval $cmd \[.dialog.f1.e get\]` in input_line} \
  [scount $BODY {eval $cmd \[.dialog.f1.e get\]}] 0

## S2b -- nor anywhere else in the file. A second dialog copied from this one
## would be the same defect under another name.
check {S2b no bare `eval $cmd \[.dialog.f1.e get\]` anywhere in xschem.tcl} \
  [scount $FILE {eval $cmd \[.dialog.f1.e get\]}] 0

## S3 -- exactly one `eval $cmd` in the proc, so S1 cannot be satisfied by an
## added line while a defective one survives beside it.
check {S3 exactly one `eval $cmd` in input_line} [scount $BODY {eval $cmd}] 1

## S4 -- the emptiness guard, which is the half that keeps `{}` from reaching
## change_linewidth() and set_snap().
check_true {S4 OK button guards an empty entry} \
  [expr {[scount $BODY {\[.dialog.f1.e get\] ne {}}] == 1}]

## S5 -- Enter must not be a second, unguarded door into the same dialog.
check_true {S5 <Return> routes through the OK button} \
  [expr {[scount $BODY {bind .dialog <Return> {.dialog.f2.ok invoke}}] == 1}]

# ===========================================================================
# SECTION P1-P6 -- STRUCTURAL, ISSUE 1602. Both arms. These are what reddens if
# the precision box's validation is edited away without anybody opening a menu.
# ===========================================================================
set PBODY [proc_body $FILE set_ev_precision]

## P1 -- the shipped menu entry calls the validator on input_line's RETURN
## VALUE. The exact line, so a rename or a re-pointing at $cmd reddens.
check {P1 the precision menu entry routes through set_ev_precision} \
  [scount $FILE {set_ev_precision [input_line "Enter precision (int 1-71):" {} $ev_precision]}] 1

## P2 -- and the defective form is gone: no caller hands input_line the literal
## command that made anything typed become the precision.
check {P2 no `"set ev_precision"` command handed to input_line} \
  [scount $FILE {"set ev_precision"}] 0

## P3 -- the validator exists at all, so P4-P6 cannot pass by finding nothing.
check_true {P3 proc set_ev_precision is in src/xschem.tcl} \
  [expr {$PBODY ne {ZZNOPROC} && $PBODY ne {}}]

## P4 -- the digits-only pattern. Without it `4f`, `4e0`, `2.5` and `abc` walk in.
check {P4 set_ev_precision matches a plain decimal integer only} \
  [scount $PBODY {regexp {^0*([0-9]{1,3})$} $t -> d}] 1

## P5 -- the range test. 71 is the largest precision measured safe against
## dtoa_eng's `static char s[80]`; at 73 the binary aborts with a detected
## buffer overflow. 0 turns engineering notation off in C but not in Tcl.
check {P5 set_ev_precision holds the measured 1..71 range} \
  [scount $PBODY {$n < 1 || $n > 71}] 1

## P6 -- and it SAYS SO. The driver decision on 1602 is refuse-and-tell, not
## quietly keep the last good value, because the defect's nature is silence.
check_true {P6 set_ev_precision tells the user it refused} \
  [expr {[scount $PBODY {alert_ }] == 1}]

# ===========================================================================
# SECTION B -- BEHAVIOURAL. The real widget, the real OK button, the real
# event loop. DISPLAY ARM ONLY.
# ===========================================================================
set BROWS {B1a/B1b/B2/B3a/B3b/B4/B5/B6/B7/B8/B9/B10/B11a/B11b/B12a/B12b/B13a/B13b/B14/B15/B16a/B16b/B17a/B17b/B18a/B18b/B19/P7a/P7b/P8a/P8b/P9a/P9b/P10a/P10b/P11a/P11b/P11c/P12/P13/P14/P15a/P15b/P16/P17}

if {![info exists ::has_x]} {
  skiprow $BROWS "these rows open the real input_line dialog and invoke its OK\
 button from the event loop; input_line builds a Tk toplevel and blocks in\
 tkwait, and neither toplevel nor winfo exists under --nogui, so the arm that\
 measures them is tests/headless/run_suites.sh test_input_line_inject_1352"
} else {

## --- the driver ------------------------------------------------------------
## Polls until the dialog is up AND `input_line` has taken its grab, because the
## grab is set between `tkwait visibility` and `tkwait window`: firing before it
## would destroy the toplevel while input_line is still in `tkwait visibility`,
## and the proc would raise instead of returning.
proc il_poke {typed tries} {
  if {[winfo exists .dialog.f2.ok] && [winfo exists .dialog.f1.e]} {
    set g {}
    catch {set g [grab current .dialog]}
    if {$g eq {.dialog} || $tries <= 0} {
      catch {.dialog.f1.e delete 0 end}
      catch {.dialog.f1.e insert 0 $typed}
      if {[catch {.dialog.f2.ok invoke} e]} { set ::il_err "INVOKE: $e" }
      catch {destroy .dialog}
      return
    }
  } elseif {$tries <= 0} {
    set ::il_err NODIALOG
    catch {destroy .dialog}
    return
  }
  set ::il_after [after 40 [list il_poke $typed [expr {$tries - 1}]]]
}

## Open input_line with $cmd, type $typed, press OK. Returns the proc's own
## return value (which must always be the typed text, untouched).
proc il_drive {cmd typed {preset 4}} {
  set ::il_err none
  set ::il_after [after 40 [list il_poke $typed 120]]
  set ::il_guard [after 20000 {catch {destroy .dialog}}]
  set rv IL_RAISED
  if {[catch {input_line {issue 1352 probe} $cmd $preset 30} rv]} {
    set ::il_err "OUTER: $rv" ; set rv IL_RAISED
  }
  catch {after cancel $::il_after}
  catch {after cancel $::il_guard}
  catch {destroy .dialog}
  il_note "drive {$cmd}"
  return $rv
}

## ⚠ WITHOUT THIS, TWO ROWS COULD PASS BY NOT HAPPENING. B12a and B13a are
## "nothing was executed" assertions: a drive whose dialog never appeared
## satisfies them silently. Every drive therefore records whether it actually
## reached the OK button, and B19 -- one row, at the end -- says so out loud.
proc il_note {what} {
  if {$::il_err eq {none}} { return }
  lappend ::il_errlog "$what -> $::il_err"
  set ::il_err none
}

## Invoke the shipped menu entry with this -label, then type $typed into the
## dialog it opens. Returns {} on success, a reason otherwise.
proc il_menu {menu label typed} {
  if {![winfo exists $menu]} { return "NOMENU $menu" }
  set n -1
  catch {set n [$menu index end]}
  for {set i 0} {$i <= $n} {incr i} {
    set l {}
    if {[catch {$menu entrycget $i -label} l]} { continue }
    if {$l ne $label} { continue }
    set ::il_err none
    set ::il_after [after 40 [list il_poke $typed 120]]
    set ::il_guard [after 20000 {catch {destroy .dialog}}]
    catch {$menu invoke $i}
    catch {after cancel $::il_after}
    catch {after cancel $::il_guard}
    catch {destroy .dialog}
    il_note "menu {$label}"
    return {}
  }
  return "NOENTRY {$label}"
}

set ::il_errlog {}

## The canary. `info exists` on it is the whole question: it is set only by a
## command the user typed being EXECUTED.
proc il_armed {} { catch {unset ::ILINJ} ; return 1 }
proc il_fired {} { return [expr {[info exists ::ILINJ] ? "FIRED-$::ILINJ" : "no"}] }

proc il_mw {a b c} { set ::ILV "$a|$b|$c" }

# --- B1: the issue's own line, through input_line directly ------------------
il_armed ; set ::ILV SENTINEL
set rv [il_drive {set ::ILV} {7 ; set ::ILINJ yes}]
check {B1a the typed text lands as ONE value} $::ILV {7 ; set ::ILINJ yes}
check {B1b the second command did NOT run}    [il_fired] no
check {B2 input_line still returns the typed text} $rv {7 ; set ::ILINJ yes}

# --- B3: command substitution is not performed ------------------------------
il_armed ; set ::ILV SENTINEL
il_drive {set ::ILV} {[set ::ILINJ cmdsub]}
check {B3a `\[...\]` reaches $cmd literally} $::ILV {[set ::ILINJ cmdsub]}
check {B3b `\[...\]` was NOT executed}       [il_fired] no

# --- B4: variable substitution is not performed -----------------------------
set ::ILV SENTINEL
il_drive {set ::ILV} {$::env(HOME)}
check {B4 `$...` reaches $cmd literally} $::ILV {$::env(HOME)}

# --- B5..B10: the characters that used to raise or split --------------------
set ::ILV SENTINEL ; il_drive {set ::ILV} {a b c}
check {B5 spaces stay one value} $::ILV {a b c}
set ::ILV SENTINEL ; il_drive {set ::ILV} "\{"
check {B6 a lone open brace lands} $::ILV "\{"
set ::ILV SENTINEL ; il_drive {set ::ILV} "\}"
check {B7 a lone close brace lands} $::ILV "\}"
set ::ILV SENTINEL ; il_drive {set ::ILV} "\""
check {B8 a lone double quote lands} $::ILV "\""
set ::ILV SENTINEL ; il_drive {set ::ILV} "a\nb"
check {B9 an embedded newline lands} $::ILV "a\nb"
set ::ILV SENTINEL ; il_drive {set ::ILV} {a\tb}
check {B10 a backslash escape is not expanded} $::ILV {a\tb}

# --- B11: a MULTI-WORD $cmd prefix still gets its own words -----------------
il_armed ; set ::ILV SENTINEL
il_drive {il_mw one two} {3 ; set ::ILINJ yes}
check {B11a a multi-word $cmd prefix keeps its words, text is the last arg} \
  $::ILV {one|two|3 ; set ::ILINJ yes}
check {B11b and nothing was injected through it} [il_fired] no

# --- B12: an EMPTY $cmd runs nothing and still returns the text -------------
il_armed
set rv [il_drive {} {9 ; set ::ILINJ yes}]
check {B12a an empty $cmd executes nothing} [il_fired] no
check {B12b an empty $cmd still returns the typed text} $rv {9 ; set ::ILINJ yes}

# --- B13: an EMPTY ENTRY is still a no-op (the guard) -----------------------
set ::ILV SENTINEL
set rv [il_drive {set ::ILV} {}]
check {B13a an empty entry does not call $cmd} $::ILV SENTINEL
check {B13b an empty entry returns the empty string} $rv {}

# --- B14/B15: xschem set netlist_name, the second shipped caller ------------
set nn_before [xschem get netlist_name]
il_drive {xschem set netlist_name} {plain_name.spice}
check {B14 netlist_name: a plain value lands} [xschem get netlist_name] plain_name.spice
## ⚠ A NAME WITH A SPACE USED TO BE IMPOSSIBLE: `eval xschem set netlist_name my
## file.spice` reached the dispatcher as five words. It works now.
il_drive {xschem set netlist_name} {my file.spice}
check {B15 netlist_name: a name with a SPACE lands whole} \
  [xschem get netlist_name] {my file.spice}
il_armed
il_drive {xschem set netlist_name} {zz.spice ; set ::ILINJ yes}
check {B16a netlist_name: the hostile text lands as the name} \
  [xschem get netlist_name] {zz.spice ; set ::ILINJ yes}
check {B16b netlist_name: nothing was executed} [il_fired] no
catch {xschem set netlist_name $nn_before}

# --- B17: the shipped View > "Set snap value" menu entry --------------------
set snap_before $::cadsnap
set r [il_menu .menubar.view {Set snap value} {2.5}]
if {$r ne {}} {
  skiprow {B17a/B17b} "the View menu entry could not be reached ($r): this\
 xschem was started without its menubar, so the shipped entry that carries\
 `xschem set cadsnap` is not there to invoke"
} else {
  check {B17a View > Set snap value: the value lands} $::cadsnap 2.5
  il_armed
  il_menu .menubar.view {Set snap value} {5 ; set ::ILINJ yes}
  check {B17b View > Set snap value: nothing was executed} [il_fired] no
}
catch {xschem set cadsnap $snap_before}

# --- the precision driver, for B18 and section P ----------------------------
## ⚠ SINCE ISSUE 1602 THE PRECISION ENTRY CAN OPEN TWO WINDOWS, NOT ONE.
## `input_line` returns, and `set_ev_precision` then pops an `alert_` toplevel
## for a value it refuses. `alert_` blocks in `tkwait window .alert`, so
## `il_menu` -- which only ever destroys `.dialog` -- would hang here until the
## suite watchdog. This driver polls both windows in one `after` chain.
## ⚠ IT WAITS FOR alert_ TO BIND <Return> before touching `.alert`: that bind
## is the first statement after alert_'s own `tkwait visibility`, and destroying
## the toplevel before then makes THAT tkwait raise instead of returning.
set ::pr_errlog {}
proc pr_poke {typed tries state} {
  if {$state eq {dialog}} {
    if {[winfo exists .dialog.f2.ok] && [winfo exists .dialog.f1.e]} {
      set g {}
      catch {set g [grab current .dialog]}
      if {$g eq {.dialog} || $tries <= 0} {
        catch {.dialog.f1.e delete 0 end}
        catch {.dialog.f1.e insert 0 $typed}
        if {[catch {.dialog.f2.ok invoke} e]} { set ::pr_err "INVOKE: $e" }
        catch {destroy .dialog}
        ## A legal value opens no alert at all, so the second leg gets its own
        ## short budget -- alert_ is reached within a few event loop passes.
        set state alert
        set tries 30
      }
    } elseif {$tries <= 0} {
      set ::pr_err NODIALOG
      catch {destroy .dialog}
      return
    }
  }
  if {$state eq {alert}} {
    if {[winfo exists .alert.b1] && [winfo ismapped .alert] && [bind .alert <Return>] ne {}} {
      catch {set ::pr_alert [.alert.l1 cget -text]}
      catch {.alert.b1 invoke}
      catch {destroy .alert}
      return
    }
    if {$tries <= 0} { catch {destroy .alert} ; return }
  }
  set ::pr_after [after 40 [list pr_poke $typed [expr {$tries - 1}] $state]]
}

## Invoke the shipped precision menu entry and type $typed. Leaves ::pr_alert
## holding the refusal text, or {} when the value was accepted silently.
proc pr_menu {typed} {
  set menu .menubar.simulation
  set label {Set netlist / graph / annotation precision}
  if {![winfo exists $menu]} { return "NOMENU $menu" }
  set n -1
  catch {set n [$menu index end]}
  for {set i 0} {$i <= $n} {incr i} {
    set l {}
    if {[catch {$menu entrycget $i -label} l]} { continue }
    if {$l ne $label} { continue }
    set ::pr_err none ; set ::pr_alert {}
    set ::pr_after [after 40 [list pr_poke $typed 120 dialog]]
    set ::pr_guard [after 20000 {catch {destroy .alert} ; catch {destroy .dialog}}]
    catch {$menu invoke $i}
    catch {after cancel $::pr_after}
    catch {after cancel $::pr_guard}
    catch {destroy .alert}
    catch {destroy .dialog}
    if {$::pr_err ne {none}} { lappend ::pr_errlog "precision {$typed} -> $::pr_err" }
    set ::pr_err none
    return {}
  }
  return "NOENTRY {$label}"
}

# --- B18: 1352'S OWN REPRO, through the shipped precision menu entry --------
## ⚠ WHAT B18a MEASURES CHANGED WITH ISSUE 1602, AND IT STILL MEASURES 1352.
## Before 1602 this row read the hostile text back out of `ev_precision`, which
## is exactly what 1602 stopped: the value is now REFUSED. The 1352 property --
## the typed text is handed on as ONE value and never spliced into a script --
## is now read off the refusal, which quotes back what it was given. A splice
## would have delivered `7` alone, and the row would see `"7"` in the message.
set prec_before $::ev_precision
set ::ev_precision 4
il_armed
set r [pr_menu {7 ; set ::ILINJ yes}]
if {$r ne {}} {
  skiprow {B18a/B18b} "the Simulation menu entry could not be reached ($r):\
 this xschem was started without its menubar, so the shipped entry issue 1352\
 was reported against is not there to invoke"
} else {
  check_true {B18a Simulation > Set precision: the WHOLE hostile text arrived as one value} \
    [string match {*"7 ; set ::ILINJ yes"*} $::pr_alert]
  check {B18b Simulation > Set precision: `set ::ILINJ yes` did NOT run} \
    [il_fired] no
}
catch {set ::ev_precision $prec_before}

# --- B19: every drive above really reached the OK button --------------------
## The empty-$cmd and empty-entry rows assert that NOTHING ran. A dialog that
## never opened would satisfy them without measuring anything, so this row is
## what stops the B section passing by not happening.
check {B19 every drive reached the real OK button} $::il_errlog {}

# ===========================================================================
# SECTION P7-P17 -- BEHAVIOURAL, ISSUE 1602. The real menu entry, the real
# dialog, the real refusal. DISPLAY ARM ONLY.
# ===========================================================================
set prec_before $::ev_precision

## Type $typed at the real menu entry and assert the precision did not move AND
## that the user was told, with what they typed quoted back at them.
proc pr_refused {row typed} {
  set ::ev_precision 4
  set r [pr_menu $typed]
  if {$r ne {}} { skiprow "${row}a/${row}b" "menu entry unreachable ($r)" ; return }
  check "${row}a refused {$typed}: precision did not move" $::ev_precision 4
  check_true "${row}b refused {$typed}: and the user was told, naming it" \
    [string match "*\"$typed\"*" $::pr_alert]
}

## P7 -- the issue's own `abc`: a value `format %.Ng` raises on.
pr_refused P7 {abc}
## P8 -- `4f` is the class that does NOT raise. It ends the format specifier
## early, so 1345's raw-text fallback never engages and a true 1.11e-05 used to
## print as `11.1000gu` -- a wrong number wearing engineering notation.
pr_refused P8 {4f}
## P9 -- 72 is one past the measured ceiling. At 73 this binary aborts with
## `*** buffer overflow detected ***` inside dtoa_eng's sprintf.
pr_refused P9 {72}
## P10 -- 0 is refused at the floor: eval_expr.y reads it as "engineering off",
## so C prints 1.11e-05 where Tcl prints 1e+01u, and the two surfaces disagree.
pr_refused P10 {0}

## P11 -- a hostile string is refused like any other bad value, is quoted back
## WHOLE (the 1352 property), and still executes nothing.
set ::ev_precision 4
il_armed
set r [pr_menu {9 ; set ::ILINJ yes}]
if {$r ne {}} {
  skiprow {P11a/P11b/P11c} "menu entry unreachable ($r)"
} else {
  check {P11a a hostile precision does not move the value} $::ev_precision 4
  check_true {P11b and the refusal quotes the WHOLE string, not its first word} \
    [string match {*"9 ; set ::ILINJ yes"*} $::pr_alert]
  check {P11c and nothing was executed} [il_fired] no
}

## P12-P14 -- a LEGAL value still lands, silently. A validator that refused
## everything would satisfy P7-P11 perfectly.
set ::ev_precision 4
set r [pr_menu {6}]
if {$r ne {}} { skiprow {P12} "menu entry unreachable ($r)" } else {
  check {P12 a legal precision lands with no alert} "$::ev_precision|$::pr_alert" {6|}
}
set ::ev_precision 4
set r [pr_menu {71}]
if {$r ne {}} { skiprow {P13} "menu entry unreachable ($r)" } else {
  check {P13 71, the measured ceiling, is legal} "$::ev_precision|$::pr_alert" {71|}
}
## `format %.007g` and atoi("007") both mean SEVEN, so 007 is legal -- and it is
## stored normalised, because Tcl's expr would otherwise read a leading-zero
## value as octal.
set ::ev_precision 4
set r [pr_menu {007}]
if {$r ne {}} { skiprow {P14} "menu entry unreachable ($r)" } else {
  check {P14 007 is legal and is stored as 7} "$::ev_precision|$::pr_alert" {7|}
}

## P15 -- an EMPTIED field is Cancel, not an error: nothing changes and nothing
## is said. input_line's own emptiness guard (issue 1352) is the other half.
set ::ev_precision 4
set r [pr_menu {}]
if {$r ne {}} { skiprow {P15a/P15b} "menu entry unreachable ($r)" } else {
  check {P15a an emptied field leaves the precision alone} $::ev_precision 4
  check {P15b an emptied field says nothing} $::pr_alert {}
}

## P16 -- THE WHOLE POINT. After a refused value the formatter still works, so
## the Results Display Window and the annotation sheet still print a number.
set ::ev_precision 4
pr_menu {abc}
set fmt IL
catch {to_eng 1.11e-05} fmt
check {P16 after a refusal the formatter still formats} $fmt {11.1u}

## P17 -- and every precision drive above really reached the real OK button.
check {P17 every precision drive reached the real OK button} $::pr_errlog {}
catch {set ::ev_precision $prec_before}

}
# --- verdict ---------------------------------------------------------------
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
## Both sentinels: run_suites.sh scores `RESULT: ALL PASS`, tests/banner_rule.tcl
## -- the rule run_regression.tcl consumes -- scores ONLY a whole-line
## `OVERALL: ok`. A suite printing one of them is scored a HARNESS FAILURE by the
## other however many of its own checks passed.
if {$fail == 0} {
  puts "OVERALL: ok"
} else {
  puts "OVERALL: notok"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
