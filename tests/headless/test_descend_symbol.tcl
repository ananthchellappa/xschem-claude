# B6 acceptance: backing-file autosave for SYMBOLS (cellName~.sym) and the
# descend_symbol path. Spec: doc/claude/specs/descend_hierarchy_in_memory.md
#
# Run TRUE HEADLESS from the repo root:
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/test_descend_symbol.tcl
#
# Part A (symbol autosave): editing a .sym buffer writes cellName~.sym via the
#   set_modify hook (backup_file_name handles .sym too), and a real save removes it.
# Part B (descend_symbol): descending into a component's symbol view must NOT pop
#   the save prompt (SY2, RED until B6) and must not lose the parent's unsaved edits
#   on go_back (SY1) -- the parent edit is persisted to parent~.sch and reloaded.
#
# Works on a /tmp copy so the ~ backups never pollute the committed fixtures.

set fixdir [file normalize [file join [file dirname [info script]] fixtures descend]]
set work /tmp/b6_descend_symbol_work
file delete -force $work; file mkdir $work
foreach fn {descend_parent.sch descend_child.sch descend_child.sym} {
  file copy -force $fixdir/$fn $work/$fn
}
if {![info exists XSCHEM_LIBRARY_PATH]} { set XSCHEM_LIBRARY_PATH {} }
set XSCHEM_LIBRARY_PATH "$work:$fixdir:$XSCHEM_LIBRARY_PATH"

set ::fails 0
proc check {name ok} {
  puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name"; flush stdout
  if {!$ok} {incr ::fails}
}
proc result {} {
  puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
  flush stdout
  exit [expr {$::fails != 0}]
}

# Count + decline the save prompt: edits must survive either way.
set ::ask_count 0
proc ask_save {{cmd {}}} { incr ::ask_count; return no }

# ---------------------------------------------------------------------------
# Part A: a .sym buffer is autosaved to cellName~.sym, and a save removes it.
# ---------------------------------------------------------------------------
set symbak $work/descend_child~.sym
file delete -force $symbak
xschem load $work/descend_child.sym
check "loaded symbol buffer (descend_child.sym)" \
  [expr {[file tail [xschem get schname]] eq "descend_child.sym"}]
check "fresh symbol load is not flagged modified" [expr {[xschem get modified] == 0}]
check "no ~ backup before any edit" [expr {![file exists $symbak]}]

# genuine edit to the symbol -> set_modify hook writes the ~.sym
xschem line -40 -40 40 -40
check "symbol edit set the modified flag" [expr {[xschem get modified] == 1}]
check "A: symbol edit autosaved to cellName~.sym" [file exists $symbak]

# a real save commits the edit and drops the ~ backup
xschem save
check "A: real save removed the ~.sym backup" [expr {![file exists $symbak]}]
check "save cleared the modified flag" [expr {[xschem get modified] == 0}]

# ---------------------------------------------------------------------------
# Part B: descend_symbol must not prompt, and must preserve the parent edit.
# ---------------------------------------------------------------------------
set parbak $work/descend_parent~.sch
file delete -force $parbak
set ::ask_count 0
xschem load $work/descend_parent.sch
set base [xschem get wires]
check "loaded parent schematic (1 wire, 1 instance)" \
  [expr {[file tail [xschem get schname]] eq "descend_parent.sch" && $base == 1 && [xschem get instances] == 1}]

# unsaved edit to the PARENT (autosave writes parent~.sch)
xschem wire 200 300 300 300
set edited [xschem get wires]
check "parent edit applied (wire added, modified set)" \
  [expr {$edited == $base + 1 && [xschem get modified] == 1}]
check "parent edit autosaved to parent~.sch" [file exists $parbak]

# descend into the SYMBOL view of the instance, declining any save
xschem unselect_all
xschem select instance 0
xschem descend_symbol
check "descended into the symbol view (descend_child.sym)" \
  [expr {[file tail [xschem get schname]] eq "descend_child.sym"}]

# return to the parent
xschem go_back
check "returned to parent schematic" \
  [expr {[file tail [xschem get schname]] eq "descend_parent.sch"}]

# SY1: the unsaved parent edit must still be there (reloaded from parent~.sch)
check "SY1: parent edit preserved across descend_symbol/go_back" \
  [expr {[xschem get wires] == $edited}]
check "SY1: parent still flagged modified on return" \
  [expr {[xschem get modified] == 1}]

# SY2: descend_symbol must not have prompted at all (RED until B6)
check "SY2: descend_symbol did not pop the save prompt" \
  [expr {$::ask_count == 0}]

# ---------------------------------------------------------------------------
# Part C: EMBEDDED-symbol descent is deferred -- it must STILL prompt (the
# legacy guard), because go_back's embedded return reloads the parent from disk
# (not from parent~.sch), so dropping the prompt there would silently lose the
# parent's unsaved edits. This pins the deferral boundary: B6 covers only the
# non-embedded case. See doc/claude/specs/descend_hierarchy_in_memory.md.
# ---------------------------------------------------------------------------
set embpar $work/emb_parent.sch
set fp [open $embpar w]
puts $fp "v {xschem version=3.4.4 file_version=1.2}"
puts $fp "G {}"
puts $fp "V {}"
puts $fp "S {}"
puts $fp "E {}"
puts $fp "N 200 200 300 200 {}"
puts $fp "C {descend_child.sym} 0 0 0 0 {name=x1 embed=true}"
close $fp
file delete -force $work/emb_parent~.sch
set ::ask_count 0
xschem load $embpar
xschem wire 200 300 300 300   ;# modify the parent so the guard can fire
xschem unselect_all
xschem select instance 0
xschem descend_symbol
check "descended into embedded symbol view" \
  [expr {[string match ".xschem_embedded_*" [file tail [xschem get schname]]]}]
check "SYC: embedded-symbol descent STILL prompts (data-loss guard kept)" \
  [expr {$::ask_count > 0}]
xschem go_back

# ---------------------------------------------------------------------------
# Part D: the refusal channel (issues 0249 / 0251 / 0254).
#
# descend_symbol() has four refusal exits and one success exit, and today all
# five are indistinguishable at every caller: the dispatcher runs
# Tcl_ResetResult (scheduler.c), so `xschem descend_symbol` evaluates to the
# empty string whether it descended or declined, and three of the four
# refusals emit nothing on any channel. Part D pins the fix:
#
#   * the verb evaluates to "1" on success and "0" on a refusal, mirroring
#     `xschem descend`;
#   * every refusal RECORDS a reason token on a per-context second channel,
#     `xschem get descend_error` (a second channel, never a widened result --
#     the "0"/"1" of `xschem descend` is load-bearing in the PDK glue and in
#     tests/buried_hilight.tcl);
#   * the refusals a user provoked by pressing `i` on something they picked
#     also SPEAK, on the held status line (statusmsg_hold, issue 0248 -- a
#     plain statusmsg is clobbered by select.c's n=/x=/y=/w=/h= info line);
#   * the target rule is phrased against the VISIBLE selection
#     (`xschem selected_set`, ELEMENT-only), not xctx->lastsel, which counts
#     pseudo-selections the user cannot see: an instance plus its own pin
#     reads as lastsel 2 while exactly one symbol is highlighted on screen.
#
# The silent half of the split lives in descend_schematic()'s annotation-class
# guard and is locked by tests/headless/test_descend_inert_class.tcl.
# See doc/claude/code_analysis/descend_silent_refusal_census.md.
# ---------------------------------------------------------------------------
proc d_fresh {} {
  global work
  set g 0
  while {[xschem get currsch] > 0 && $g < 10} { xschem go_back; incr g }
  xschem clear force
  xschem load $work/descend_parent.sch
  xschem unselect_all
}

# R01: a refused call and a successful call must not evaluate to the same string.
d_fresh
set refused [xschem descend_symbol]
d_fresh
xschem select instance x1 fast
set accepted [xschem descend_symbol]
xschem go_back
check "R01: descend_symbol is \"0\" refused / \"1\" accepted (got {$refused}/{$accepted})" \
  [expr {$refused eq "0" && $accepted eq "1"}]

# R02: nothing selected.
d_fresh
set lvl [xschem get currsch]
set ret [xschem descend_symbol]
set derr [xschem get descend_error]
check "R02: nothing selected -> ret 0, descend_error {no-selection}, no move (got ret={$ret} err={$derr})" \
  [expr {$ret eq "0" && $derr eq "no-selection" && [xschem get currsch] == $lvl}]

# R03: a lone selected WIRE -- lastsel is 1, but zero ELEMENTs are selected, so
# the reason is "you selected something, just not an instance".
d_fresh
xschem select wire 0
check "R03 setup: one object selected, no ELEMENT in it" \
  [expr {[xschem get lastsel] == 1 && [llength [xschem selected_set]] == 0}]
set lvl [xschem get currsch]
set ret [xschem descend_symbol]
set derr [xschem get descend_error]
check "R03: a lone WIRE -> ret 0, descend_error {no-instance-selected}, no move (got ret={$ret} err={$derr})" \
  [expr {$ret eq "0" && $derr eq "no-instance-selected" && [xschem get currsch] == $lvl}]

# R04: two instances -- genuinely ambiguous, so it still refuses, but it says so.
d_fresh
xschem instance $work/descend_child.sym 500 500 0 0 {name=x2}
xschem unselect_all
xschem select instance x1 fast
xschem select instance x2 fast
check "R04 setup: two ELEMENTs selected" \
  [expr {[llength [xschem selected_set]] == 2}]
set lvl [xschem get currsch]
set ret [xschem descend_symbol]
set derr [xschem get descend_error]
check "R04: two instances -> ret 0, descend_error {multi-selection}, no move (got ret={$ret} err={$derr})" \
  [expr {$ret eq "0" && $derr eq "multi-selection" && [xschem get currsch] == $lvl}]

# R05: an instance and its OWN pin. lastsel is 2, but the user sees ONE selected
# symbol and `xschem selected_set` agrees -- the legacy `lastsel > 1` guard
# refuses a selection that does not exist. issue 0249.
d_fresh
xschem select instance x1 fast
xschem select pin x1 0
check "R05 setup: lastsel is 2 while exactly one ELEMENT is selected" \
  [expr {[xschem get lastsel] == 2 && [llength [xschem selected_set]] == 1}]
set lvl [xschem get currsch]
set ret [xschem descend_symbol]
check "R05: instance + its own pin -> descends into descend_child.sym (got ret={$ret} sch=[file tail [xschem get schname]])" \
  [expr {$ret eq "1" && [xschem get currsch] == $lvl + 1 &&
         [file tail [xschem get schname]] eq "descend_child.sym"}]
xschem go_back

# R06: a rubber-band that swept up the instance AND a wire. Same shape, and the
# one the GUI actually produces.
d_fresh
xschem select_inside -1000 -1000 1000 1000
check "R06 setup: rubber-band selected >1 object, exactly one ELEMENT" \
  [expr {[xschem get lastsel] > 1 && [llength [xschem selected_set]] == 1}]
set lvl [xschem get currsch]
set ret [xschem descend_symbol]
check "R06: instance co-selected with a wire -> descends into descend_child.sym (got ret={$ret} sch=[file tail [xschem get schname]])" \
  [expr {$ret eq "1" && [xschem get currsch] == $lvl + 1 &&
         [file tail [xschem get schname]] eq "descend_child.sym"}]
xschem go_back

# R07/R08: the ---MISSING SYMBOL--- placeholder. The unresolved name is a live
# local one line above the refusal, and today it is never told to anyone.
d_fresh
xschem instance no_such_cell_0254.sym 700 700 0 0 {name=XM}
xschem unselect_all
xschem select instance XM fast
set lvl [xschem get currsch]
set ret [xschem descend_symbol]
set derr [xschem get descend_error]
check "R07: missing-symbol placeholder -> ret 0, {missing-symbol:<name>}, no move (got ret={$ret} err={$derr})" \
  [expr {$ret eq "0" && $derr eq "missing-symbol:no_such_cell_0254.sym" &&
         [xschem get currsch] == $lvl}]
set sm [xschem get statusmsg]
check "R08: the refusal NAMES the unresolved symbol on the HELD status line (got hold=[xschem get statusmsg_hold] msg={$sm})" \
  [expr {[string match {*no_such_cell_0254.sym*} $sm] && [xschem get statusmsg_hold] == 1}]

# R10: the -inst form bypasses the selection guard but must not bypass this one.
d_fresh
xschem instance no_such_cell_0254.sym 700 700 0 0 {name=XM}
xschem unselect_all
set ret [xschem descend_symbol -inst XM]
set derr [xschem get descend_error]
check "R10: descend_symbol -inst on the placeholder -> same {missing-symbol:} token (got ret={$ret} err={$derr})" \
  [expr {$ret eq "0" && $derr eq "missing-symbol:no_such_cell_0254.sym"}]

# R09: success clears the channel, so a stale reason can never be read as a
# fresh one. Dirty it with a refusal first, in the SAME context.
d_fresh
xschem descend_symbol
check "R09 setup: the channel is dirty after a refusal" \
  [expr {[xschem get descend_error] ne {}}]
xschem select instance x1 fast
set ret [xschem descend_symbol]
set derr [xschem get descend_error]
check "R09: a successful descend_symbol clears descend_error (got ret={$ret} err={$derr})" \
  [expr {$ret eq "1" && $derr eq {}}]
xschem go_back

# ---------------------------------------------------------------------------
# Part E: symbol_in_new_window and the tab that already holds the .sym.
# Issue 0258. The OTHER "edit this symbol" verb (Alt+i / File > Open selected
# symbol in new window), which does not descend but answers the same question.
#
# check_loaded() reports TWO things -- "is it open" and WHERE. symbol_in_new_window()
# asked for both (it passes a win_path buffer) and consumed only the boolean, so an
# already-open symbol produced: no window opened, no window switched, nothing said, and
# a scheduler branch that ended in Tcl_ResetResult so no caller could tell. Measured
# 2026-08-10: `xschem check_loaded <sym>` returned ".x1.drw" -- the exact value the C
# code had in hand -- while `xschem symbol_in_new_window` returned empty and left
# current_win_path on the parent. One level down, `xschem new_schematic create {} <sym> 1`
# both SAYS "already open" and SWITCHES there. The pre-check was deleting the message AND
# the navigation the user asked for.
#
# Return shape (0251's): 0 nothing done, 1 opened, 2 switched, 3 refused and said why.
# MUST run before nothing else needs the window table; it leaves it clean.
# ---------------------------------------------------------------------------
proc snw_ntabs {} { return [llength [xschem windows]] }
proc snw_home {} { catch {xschem new_schematic switch .drw} }

d_fresh
catch {xschem new_schematic destroy_all force}
set symfile [file normalize $work/descend_child.sym]
set t0 [snw_ntabs]
xschem unselect_all
xschem select instance x1 fast
xschem statusmsg { }
set ret [xschem symbol_in_new_window]
check "SNW4: not open yet -> returns 1, one more tab, and that tab holds the .sym (got ret={$ret} tabs=$t0->[snw_ntabs] name=[file tail [xschem get schname]])" \
  [expr {$ret eq "1" && [snw_ntabs] == $t0 + 1 &&
         [file tail [xschem get schname]] eq "descend_child.sym"}]
set symwin [xschem get current_win_path]

snw_home
check "SNW1 setup: back on the parent, and check_loaded names the tab that holds the .sym (got cur=[xschem get current_win_path] loaded=[xschem check_loaded $symfile] want=$symwin)" \
  [expr {[xschem get current_win_path] eq ".drw" &&
         [file tail [xschem get schname]] eq "descend_parent.sch" &&
         [xschem check_loaded $symfile] eq $symwin}]

set t1 [snw_ntabs]
xschem unselect_all
xschem select instance x1 fast
xschem statusmsg { }
set ret [xschem symbol_in_new_window]
check "SNW2: already open -> returns 2, SWITCHES to the tab holding it, opens nothing new (got ret={$ret} cur=[xschem get current_win_path] want=$symwin tabs=$t1->[snw_ntabs])" \
  [expr {$ret eq "2" && [xschem get current_win_path] eq $symwin && [snw_ntabs] == $t1 &&
         [file tail [xschem get schname]] eq "descend_child.sym"}]
set sm [xschem get statusmsg]
check "SNW3: and the switch SPEAKS it, held (got hold=[xschem get statusmsg_hold] msg={$sm})" \
  [expr {[string match {*already open*} $sm] && [string match {*descend_child.sym*} $sm] &&
         [xschem get statusmsg_hold] == 1}]

# SNW5: new_process keeps its guard but now refuses OUT LOUD (ruling D5). The .sym is
# still open in $symwin, so this can never reach new_xschem_process() and spawn anything.
snw_home
set t2 [snw_ntabs]
xschem unselect_all
xschem select instance x1 fast
xschem statusmsg { }
set ret [xschem symbol_in_new_window new_process]
set sm [xschem get statusmsg]
check "SNW5: new_process on an already-open .sym -> returns 3, nothing spawned, nothing moved, and it says why (got ret={$ret} tabs=$t2->[snw_ntabs] cur=[xschem get current_win_path] msg={$sm})" \
  [expr {$ret eq "3" && [snw_ntabs] == $t2 && [xschem get current_win_path] eq ".drw" &&
         [string match {*already open*} $sm] && [string match {*descend_child.sym*} $sm] &&
         [xschem get statusmsg_hold] == 1}]

# SNW6: the arm this fix deliberately did NOT touch -- nothing selected, so the verb
# means "open another view of the CURRENT schematic's own .sym". It must still answer 1.
# (That arm can also answer 1 without having opened anything; filed as issue 0383.)
snw_home
xschem unselect_all
set ret [xschem symbol_in_new_window]
check "SNW6: the untouched nothing-selected arm still returns 1 (got ret={$ret})" \
  [expr {$ret eq "1"}]
catch {xschem new_schematic destroy_all force}
snw_home

result
