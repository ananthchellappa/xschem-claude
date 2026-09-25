# Issue 1603 — A SYMBOL WITH NO `type=` IS A NULL POINTER, NOT AN EMPTY STRING.
# The fixture item 1 of the issue asked for, and the fence for the four guards the
# 1603 batch landed.
#
# Run (armed spelling):
#   tests/headless/run_suites.sh --nogui test_typeless_symbol_1603
#   tests/headless/run_suites.sh        test_typeless_symbol_1603
#
# --------------------------------------------------------------------------------
# ⚠ THE ISSUE'S OWN PREMISE WAS WRONG, AND GETTING THE FIXTURE RIGHT IS THE WHOLE
# DIFFICULTY OF THIS FILE. "A symbol with no `type=` property" is NOT enough to
# produce a NULL `xSymbol.type`:
#
#   * load_sym_def() (save.c, cases 'K' and 'G') does
#     `load_ascii_string(&symbol[symbols].prop_ptr, ...); if(!symbol[symbols].prop_ptr)
#     break;` and only THEN calls set_sym_flags().
#   * load_ascii_string() ends in my_strdup, whose own comment reads "empty source
#     string -> dest=NULL". So `K {}` yields prop_ptr == NULL and the `break` skips
#     set_sym_flags() entirely.
#   * set_sym_flags() does `my_strdup2(..., &sym->type, get_tok_value(sym->prop_ptr,
#     "type", 0))`. get_tok_value() NEVER returns NULL -- it returns "" for a missing
#     token -- and my_strdup2 duplicates the empty string.
#
# So prop_ptr == NULL <=> set_sym_flags was skipped <=> type == NULL, and the reachable
# NULL state is a symbol whose GLOBAL-ATTRIBUTE RECORD IS EMPTY OR ABSENT (`K {}`, or a
# .sym file with neither a G nor a K record). A symbol carrying some OTHER property but
# no `type=` gets "" and is completely harmless. A first draft of this suite that wrote
# a .sym with `K {format=...}` and no `type=` would measure NOTHING: rows C1/C2 exist to
# make that impossible to do silently, and `someprop.sym` is kept as the CONTROL that
# shows the harmless half really is harmless.
# --------------------------------------------------------------------------------
#
# THE TWO DEFECTS THIS SUITE FENCES BEHAVIOURALLY, both driven to a gdb-confirmed
# SIGSEGV on the tree before the batch:
#
#  N1  `xschem sch_pinlist` (scheduler.c, xschem_cmds_s()). TRULY HEADLESS, two lines of
#      Tcl, no other state: `if( !strcmp((xctx->inst[i].ptr + xctx->sym)->type, "ipin") )`
#      with two `else if` arms on the same pointer and no type test anywhere in the
#      branch. ONE guard had to cover all three arms -- guarding only the first would
#      have moved the fault to the second.
#  N2  draw_temp_symbol() (draw.c). DISPLAY ONLY, and the bug was that THE GUARD NAMED
#      THE WRONG FIELD: it tested `->prop_ptr &&` and then dereferenced `->type`, where
#      draw_symbol() 336 lines above tests `->type` correctly. On a freshly loaded
#      typeless symbol prop_ptr is ALSO NULL, so the `&&` short-circuited and the wrong
#      guard held by accident. `xschem setprop symbol <s> device widget` sets prop_ptr
#      WITHOUT calling set_sym_flags(), breaking the coupling, and the next
#      draw_selection() with hide_symbols == 1 died.
#
# AND THE TWO THAT CANNOT BE REDDENED BY INPUT ALONE, WHICH IS WHY S1/S2 ARE STATIC.
# prepare_netlist_structs() calls reset_caches(), which runs set_sym_flags() over EVERY
# symbol including one whose prop_ptr is NULL, so the NULL is HEALED TO "" before any
# netlister, hilighter or net resolver is reached. Measured on the batch's fixture: 5
# netlisters x 3 schematics + list_nets = 260 visits, 216 on the typeless symbol, type
# always "", ZERO NULL; a broader driver covering delete+undo, redo, copy_objects,
# descend/go_back and reloads gives 1576 visits, 1312 typeless, ZERO NULL. So no input
# this suite can write makes netlist.c see a NULL, and a behavioural row there would be
# a row that fences nothing. The static rows are the instrument, in test_ps_valid_1350's
# V24/V27 shape and for V27's measured reason.
#
# ⚠ THAT SAFETY RESTS ON ONE TOKEN IN A THIRD FILE, WHICH IS WHAT S3 IS FOR. Flip
# set_sym_flags()'s `my_strdup2` for the `my_strdup` this tree uses almost everywhere
# else -- one which NULLs the destination on an empty source -- and the batch's verify
# crew got two sequential gdb-confirmed segfaults, netlist.c's IS_LABEL_OR_PIN test
# first and then instcheck()'s bus_tap initialiser, and a clean run once both were
# guarded. So S1 and S2 are defence in depth backed by a MEASUREMENT, not by style.
#
# WHY THERE IS NO PURELY BEHAVIOURAL CONTROL FOR "type IS NULL HERE". On a correct
# binary NULL and "" are deliberately indistinguishable from Tcl: every guard the batch
# added gives a typeless symbol the same answer an empty-typed one gets, which is the
# point of the guards. Nothing in the `xschem` command surface reports the cached
# xSymbol.type field. So the control is a PAIR: C1 measures the load-time discriminator
# that IS observable (`xschem getprop symbol <n>` returns prop_ptr verbatim, so an empty
# answer means prop_ptr == NULL), and C2 statically asserts the code in save.c that makes
# prop_ptr == NULL imply type == NULL. If anyone makes set_sym_flags() unconditional at
# load, C2 reddens and tells the reader that this suite's fixture has just stopped being
# typeless -- which no other row in this file would notice.

set fail 0
set pass 0
proc check {n ok d} {
  global fail pass
  if {$ok} { puts "ok:   $n $d" ; incr pass } else { puts "FAIL: $n $d" ; incr fail }
}

source [file join [file dirname [info script]] scratch.tcl]
set dir  [test_scratch typeless1603]
set repo [file normalize [file join [file dirname [info script]] .. ..]]
set lib  [file join $repo xschem_library]

proc slurp {f} { if {![file exists $f]} { return "" } ; set fd [open $f rb] ; set d [read $fd] ; close $fd ; return $d }

# ------------------------------------------------------------------- fixtures ---
## THE typeless symbol: a .sym with NO G and NO K record at all, so load_sym_def()
## never gets a prop_ptr and never calls set_sym_flags(). Two pin rects, because a
## symbol with no pins is skipped by paths this suite wants to reach.
## ⚠ DO NOT "TIDY" THIS BY ADDING `G {}` / `V {}` / `S {}` / `E {}` LINES TO MATCH THE
## OTHER FIXTURE WRITERS IN THIS TREE. `G {}` would still give prop_ptr == NULL, but a
## reader who adds `G {type=...}` or any other global attribute has silently converted
## this fixture into the CONTROL and every behavioural row below into a tautology.
proc sym_notype {path} {
  set fd [open $path w]
  foreach l [list "v {xschem version=3.4.6 file_version=1.2}" \
    "L 4 -10 -20 10 -20 {}" "L 4 10 -20 10 20 {}" \
    "L 4 10 20 -10 20 {}" "L 4 -10 20 -10 -20 {}" \
    "B 5 -2.5 -22.5 2.5 -17.5 {name=P dir=inout}" \
    "B 5 -2.5 17.5 2.5 22.5 {name=M dir=inout}"] { puts $fd $l }
  close $fd
}
## THE CONTROL: the same symbol with a non-empty global-attribute record that carries no
## `type=`. prop_ptr is non-NULL, set_sym_flags() runs, get_tok_value() answers "" for
## the missing token and my_strdup2 duplicates it -- so type == "", not NULL.
proc sym_k {path k} {
  set fd [open $path w]
  foreach l [list "v {xschem version=3.4.6 file_version=1.2}" "G {}" "K {$k}" "V {}" "S {}" "E {}" \
    "L 4 -10 -20 10 -20 {}" "L 4 10 -20 10 20 {}" \
    "L 4 10 20 -10 20 {}" "L 4 -10 20 -10 -20 {}" \
    "B 5 -2.5 -22.5 2.5 -17.5 {name=P dir=inout}" \
    "B 5 -2.5 17.5 2.5 22.5 {name=M dir=inout}"] { puts $fd $l }
  close $fd
}
proc wsch {path body} {
  set fd [open $path w]
  foreach l [list "v {xschem version=3.4.6 file_version=1.2}" "G {}" "K {}" "V {}" "S {}" "E {}"] {
    puts $fd $l
  }
  foreach l $body { puts $fd $l }
  close $fd
}

sym_notype [file join $dir noprop.sym]
sym_k      [file join $dir someprop.sym] "format=\"@name @pinlist somemodel\"\ntemplate=\"name=x1\""

## ONE schematic carries BOTH the typeless symbol and the control, plus three REAL pins
## of the three directions sch_pinlist knows. That is deliberate: the answer N1 asserts
## is not "it did not crash" but "exactly the three real pins came back", which is the
## only shape that shows the guard SKIPS the typeless instance instead of, say, emitting
## it with an empty direction or aborting the loop at it.
wsch [file join $dir mix.sch] [list \
  "N 0 -60 0 -20 {lab=A}" "N 0 20 0 60 {lab=B}" "N 100 -60 100 -20 {lab=C}" \
  "C {noprop.sym} 0 0 0 0 {name=x1}" \
  "C {someprop.sym} 100 0 0 0 {name=x2}" \
  "C {devices/ipin.sym} 0 -60 0 0 {name=p1 lab=A}" \
  "C {devices/opin.sym} 0 60 0 0 {name=p2 lab=B}" \
  "C {devices/iopin.sym} 100 -60 0 0 {name=p3 lab=C}"]

# --------------------------------------------------------------------- runner ---
## Spawn a child xschem that runs `body` after loading nothing. SPAWNED, NOT IN-PROCESS:
## every behavioural row here fences a SIGSEGV, which in-process would take this script's
## own interpreter down and turn a named FAIL into a dead suite with no verdict.
##
## Returns {rc death out}: the child's exit status, whether a column-0 death marker was
## printed, and the output. ⚠ BOTH OF THE FIRST TWO ARE ASSERTED BY EVERY ROW AND NEITHER
## IS REDUNDANT. xschem traps SIGSEGV in its own handler, prints `FATAL: signal 11` and
## exits 1, so a row that only diffed expected text against actual would read a segfault
## as "an empty answer" -- which is exactly what the crashing spelling produces, because
## the crash happens BEFORE the puts. The marker is matched at column 0 (banner_rule.tcl's
## convention) so a row that merely quotes the words cannot fake it.
##
## `arm`: `nogui` runs `--nogui` with no display at all. `display` routes the child through
## tests/headless/devdisplay.sh exec, which pins DISPLAY=:99 and GUI_GATE=0, so this stays
## an `hcases` suite instead of moving to `dcases` for one row.
## ⚠ THE `timeout` GOES INSIDE `devdisplay.sh exec`, NOT AROUND IT: devdisplay.sh runs the
## command as a child rather than exec'ing over itself, so a timeout wrapped around the
## wrapper would kill the wrapper and leave xschem alive on :99 with nobody waiting on it.
proc child {dir tag body {arm nogui}} {
  set t [file join $dir $tag.tcl]
  set fd [open $t w]
  puts $fd "set XSCHEM_LIBRARY_PATH {$dir:$::lib}"
  puts $fd "set netlist_dir {$dir}"
  foreach l $body { puts $fd $l }
  puts $fd "puts CHILD_DONE" ; puts $fd "flush stdout" ; puts $fd "exit 0"
  close $fd
  set here [pwd] ; cd $dir
  set rc 0 ; set out ""
  if {$arm eq {display}} {
    set dd [file join $::repo tests headless devdisplay.sh]
    if {[catch {exec $dd exec timeout 60 [info nameofexecutable] \
                --pipe -q --script $t 2>@1} out]} { set rc 1 }
  } else {
    if {[catch {exec timeout 60 [info nameofexecutable] --nogui --pipe -q --script $t 2>@1} out]} {
      set rc 1
    }
  }
  cd $here
  return [list $rc [regexp {(?n)^FATAL: signal} $out] $out]
}
## the `X=<...>` echoes the child scripts below use, pulled back out of its output.
## ⚠ MULTI-LINE ON PURPOSE, AND NOT TIDINESS: a symbol's prop_ptr is a NEWLINE-SEPARATED
## attribute list, so `xschem getprop symbol <n>` with two attributes echoes a value that
## spans two lines. A `regexp -line "^$name=<(.*)>$"` version of this proc returned
## `<<absent>>` for exactly that case, which made C1 compare an absence against a pattern
## and FAIL on a correct binary.
## ⚠ AND THE CAPTURE IS `[^>]*`, NOT `(?s)(.*?)`. The non-greedy spelling READ GREEDILY here
## and swallowed everything up to the LAST `>` in the whole child output: Tcl's ARE assigns
## greediness to the branch rather than to the individual quantifier, and with the leading
## `(?:^|\n)` alternation in front of it `.*?` ran to the end. Measured, not guessed -- it
## made C1's noprop value the rest of the transcript. A character class cannot do that, and
## no value any child here echoes contains `>`.
proc kv {out name} {
  if {[regexp -- "(?:^|\n)$name=<(\[^>\]*)>" $out . v]} { return $v }
  return "<<absent>>"
}

## the LIVE code of a C file: block comments removed, `#if 0` regions removed, every run of
## whitespace (newlines included) collapsed to one space. Lifted from v27_live in
## test_ps_valid_1350.tcl, and load-bearing here for the SAME reason and then one more:
##  - EVERY GUARD S1-S4 ASSERTS IS QUOTED IN PROSE IN THE COMMENT DIRECTLY ABOVE IT. The
##    batch wrote those comments on purpose (F2: the rule goes in the source so the next
##    reader does not re-derive it), and they name the exact spellings. Without the comment
##    strip all four rows would be satisfied by their own documentation and would stay green
##    on a file with every guard deleted. This is not a hypothetical: `netlist.c`'s comment
##    contains the words `type && IS_LABEL_OR_PIN(type)` and actions.c's contains both
##    `my_strdup2` and `my_strdup`.
##  - a `#if 0` copy of a guard is dead code that must not stand in for the live one
##    (measured in the 1607 batch: svgdraw.c's disabled region holds a byte-for-byte copy of
##    one clamp, and a whole-file regexp stayed green with the live clamp deleted).
## The #if 0 strip is a depth-counting #if/#endif scan and not a non-greedy regexp, so a
## nested #if inside a future dead region cannot terminate it early. `//` is deliberately
## NOT treated as a comment start: this tree is C89 and `//` appears inside string literals.
proc live_code {src} {
  regsub -all {(?s)/\*.*?\*/} $src { } src
  set out {} ; set dead 0 ; set depth 0
  foreach ln [split $src \n] {
    set t [string trim $ln]
    if {!$dead && [regexp {^#[ \t]*if[ \t]+0[ \t]*$} $t]} { set dead 1 ; set depth 1 ; continue }
    if {$dead} {
      if {[regexp {^#[ \t]*(if|ifdef|ifndef)\M} $t]} { incr depth }
      if {[regexp {^#[ \t]*endif\M} $t]} { incr depth -1 ; if {$depth <= 0} { set dead 0 } }
      continue
    }
    lappend out $ln
  }
  regsub -all {\s+} [join $out \n] { } src
  return $src
}
## a whitespace-tolerant regexp from a token list: every metacharacter quoted, the tokens
## joined with ` ?` so at most ONE optional space separates each pair. Against the collapsed
## text above that accepts the shipped spelling and any reformat that adds or drops single
## spaces (`if (j` for `if(j`, `x, "y"` for `x,"y"`), and it accepts a guard split across
## lines, which two of the four are. Lifted from v27_pat in test_ps_valid_1350.tcl.
## ⚠ EVERY DOUBLE QUOTE IN A TOKEN LIST BELOW IS WRITTEN `\"`, AND THAT IS LOAD-BEARING.
## `foreach t $toks` parses the braced string as a Tcl LIST, and list parsing strips the
## quotes from an element spelled `"bus_tap"` -- so the unescaped spelling silently searched
## for `bus_tap` without them and S2, S3 and S4 were all RED on the correct source. Measured,
## not guessed: that was this suite's first run.
proc pat {toks} {
  set out {}
  foreach t $toks { regsub -all {[][\\^$.|?*+(){}]} $t {\\&} t ; lappend out $t }
  return [join $out { ?}]
}

# ======================================================= CONTROL: THE FIXTURE ==
# C1 — DOES THE FIXTURE ACTUALLY LOAD TYPELESS, AND IS THE CONTROL ACTUALLY HARMLESS.
# `xschem getprop symbol <name>` with no token returns xctx->sym[i].prop_ptr verbatim, so
# an EMPTY answer means prop_ptr == NULL and a non-empty one means it is set. Read with C2
# (which fences the save.c code that makes prop_ptr == NULL imply type == NULL) this is
# what says the rows below are measuring a NULL and not an empty string. Without it this
# whole file could go green on a fixture that was never typeless at all -- the mistake the
# issue itself made, and the one its own first fixture made.
set c1 [child $dir c1 [list \
  "xschem load [file join $dir mix.sch]" \
  "puts \"SYMS=<\[xschem get symbols\]>\"" \
  "puts \"NOPROP=<\[xschem getprop symbol noprop.sym\]>\"" \
  "puts \"SOMEPROP=<\[xschem getprop symbol someprop.sym\]>\""]]
lassign $c1 c1rc c1death c1out
set c1np [kv $c1out NOPROP] ; set c1sp [kv $c1out SOMEPROP]
check "C1 (1603 control) the fixture loads TYPELESS and the control does not:\
 noprop.sym (a .sym with no G and no K record) presents an EMPTY global-attribute string,\
 i.e. prop_ptr == NULL, so load_sym_def() skipped set_sym_flags() and type is NULL;\
 someprop.sym (a K record with format= and template= and NO type=) presents a NON-EMPTY\
 one, so set_sym_flags() ran and type is \"\", not NULL" \
  [expr {$c1rc == 0 && !$c1death && $c1np eq {} && [string match {*format=*} $c1sp] \
         && [kv $c1out SYMS] eq {5}}] \
  "(rc=$c1rc death=$c1death noprop=<$c1np> someprop_len=[string length $c1sp]\
 syms=[kv $c1out SYMS])"

# C2 — THE CODE THAT MAKES C1's MEASUREMENT MEAN WHAT IT SAYS. Both symbol-attribute cases
# of load_sym_def() bail out on a NULL prop_ptr BEFORE calling set_sym_flags(), and that
# skip is the ONLY reason xSymbol.type is ever NULL at all -- get_tok_value() never returns
# NULL and my_strdup2 never NULLs its destination, so a symbol that reaches set_sym_flags()
# always ends up with "" at worst. Asserted on live code because both copies sit beside
# comments, and asserted as a COUNT OF TWO because there are exactly two cases ('K', the 1.2
# format, and 'G', .sym files and pre-1.2) and dropping either would make some third file
# shape typeless in a way no row here would notice.
set c2src  [slurp [file join $repo src save.c]]
set c2live [live_code $c2src]
set c2toks {if ( ! symbol [ symbols ] . prop_ptr ) break ; set_sym_flags ( & symbol [ symbols ] ) ;}
set c2n    [regexp -all [pat $c2toks] $c2live]
check "C2 (1603 control) load_sym_def() skips set_sym_flags() on a NULL prop_ptr in BOTH\
 symbol-attribute cases of src/save.c -- `if(!symbol\[symbols\].prop_ptr) break;` immediately\
 before `set_sym_flags(& symbol\[symbols\]);`, once for 'K' and once for 'G'. That skip is the\
 only route to a NULL xSymbol.type, so it is what makes C1's empty prop_ptr a typeless symbol\
 and not merely an undecorated one" \
  [expr {[string length $c2src] > 0 && $c2n == 2}] \
  "(occurrences=$c2n want=2 src=[string length $c2src]B live=[string length $c2live]B)"

# ============================================ BEHAVIOURAL: THE TWO DRIVEN CRASHES ==
# N1 (scheduler.c, xschem_cmds_s()) — THE TRULY HEADLESS ONE. Two lines of Tcl on the
# fixture above used to end in `FATAL: signal 11` and exit 1 with no pin list at all.
# ⚠ THE PREDICATE ASSERTS THE EXIT CODE AND THE ABSENCE OF A COLUMN-0 DEATH MARKER AND
# the exact answer. A row that only compared the pin list would pass on a binary that
# segfaulted before printing it, because a dead child's `PINLIST=` line is ABSENT and an
# absent line is easy to score as an empty list. The answer asserted is the full one --
# `{A} {in} {B} {out} {C} {inout}` -- so the row also fails if the guard skips a REAL pin
# or emits the typeless instance with an empty direction.
set n1 [child $dir n1 [list \
  "xschem load [file join $dir mix.sch]" \
  "puts \"PINLIST=<\[xschem sch_pinlist\]>\""]]
lassign $n1 n1rc n1death n1out
set n1pl [kv $n1out PINLIST]
check "N1 (1603) `xschem sch_pinlist` SURVIVES a schematic instancing a typeless symbol and\
 returns exactly the three real pins -- scheduler.c's three strcmp arms on\
 (inst\[i\].ptr + sym)->type were unguarded and this died with SIGSEGV, gdb backtrace\
 __strcmp_avx2 <- xschem_cmds_s; one guard covers all three arms, and a typeless symbol\
 contributes no direction so it is skipped like any other non-pin instance" \
  [expr {$n1rc == 0 && !$n1death && $n1pl eq {{A} {in} {B} {out} {C} {inout}} \
         && [regexp {(?n)^CHILD_DONE$} $n1out]}] \
  "(rc=$n1rc death=$n1death pinlist=<$n1pl> done=[regexp {(?n)^CHILD_DONE$} $n1out])"

# N3 — THE ORDINARY OPERATION, END TO END, ON THE SAME FIXTURE. All five back ends on a
# schematic instancing a typeless symbol. This is NOT a fence for S1/S2 and must not be
# read as one: prepare_netlist_structs() heals the NULL to "" before any back end runs, so
# this row is green with netlist.c's two guards deleted. What it DOES fence is the healing
# itself -- reset_caches()'s unconditional set_sym_flags() sweep -- from the outside, and the
# claim that a typeless symbol is an ordinary supported thing to have in a library rather
# than something that takes the netlister down. It is also the row that would notice the
# S3 sabotage arriving through the front door on a tree whose guards had been removed.
set n3 [child $dir n3 [list \
  "xschem load [file join $dir mix.sch]" \
  "foreach fmt {spice spectre vhdl verilog tedax} {" \
  "  xschem set netlist_type \$fmt" \
  "  if {\[catch {xschem netlist} e\]} { puts \"NLERR=<\$fmt \$e>\" } else { puts \"NLOK=<\$fmt>\" }" \
  "}" \
  "puts \"NETS=<\[string length \[xschem list_nets\]\]>\""]]
lassign $n3 n3rc n3death n3out
set n3ok [regexp -all {(?n)^NLOK=<} $n3out]
check "N3 (1603) all five netlist back ends and list_nets complete on a schematic instancing\
 a typeless symbol -- the operation this program exists to perform, headless. NOT a fence for\
 S1/S2 (reset_caches() heals the NULL to \"\" first, so this row is green with both of those\
 guards deleted); it fences the healing sweep itself and the claim that a typeless symbol is\
 an ordinary thing to have in a library" \
  [expr {$n3rc == 0 && !$n3death && $n3ok == 5 && ![regexp {NLERR=<} $n3out]}] \
  "(rc=$n3rc death=$n3death ok=$n3ok/5 nets=[kv $n3out NETS]\
 err=[regexp {NLERR=<} $n3out])"

# N2 (draw.c, draw_temp_symbol()) — DISPLAY ONLY, and it needs one ordinary extra step to
# break the accidental coupling between prop_ptr and type: `xschem setprop symbol <s> device
# widget` sets prop_ptr WITHOUT calling set_sym_flags(), so prop_ptr goes non-NULL while type
# stays NULL, and the old `prop_ptr &&` guard stops short-circuiting. Then hide_symbols == 1
# plus select_all -> draw_selection() -> draw_temp_symbol() -> strcmp(NULL).
# ⚠ WITH NO DEV DISPLAY THIS ROW SELF-SKIPS with a lowercase `skip:` line naming it, which
# T1's summarize_all collects into the verdict's `skips=` count (issue 1487) -- a coverage
# figure, not a failure. Which is why the reason text must not end in the words FAIL, GOLD?
# or RESULT?, and must not start with FATAL: summarize_all tests those shapes FIRST.
# S4 is the static half and runs on BOTH arms, so patch (b) is not unfenced when this skips.
set n2dd [file join $repo tests headless devdisplay.sh]
if {[catch {exec $n2dd status 2>@1} n2out]} {
  puts "skip: N2 -- tests/headless/devdisplay.sh status does not report the persistent dev\
 display alive, so the draw_temp_symbol() hide-symbols row did not run; bring it up with\
 tests/headless/devdisplay.sh start. S4 fences the same repair statically on either arm"
} else {
  set n2 [child $dir n2 [list \
    "xschem load [file join $dir mix.sch]" \
    "xschem setprop symbol noprop.sym device widget" \
    "puts \"PROP=<\[xschem getprop symbol noprop.sym\]>\"" \
    "xschem set hide_symbols 1" \
    "xschem select_all" \
    "puts \"SEL=<\[xschem get lastsel\]>\""] display]
  lassign $n2 n2rc n2death n2o
  check "N2 (1603) draw_temp_symbol() SURVIVES select_all with hide_symbols == 1 on a typeless\
 symbol whose prop_ptr has been set by `setprop symbol ... device widget` -- the state that\
 breaks the prop_ptr/type coupling the WRONG guard relied on. Driven on the dev display (:99)\
 through devdisplay.sh exec; this died with SIGSEGV before the field was corrected to ->type" \
    [expr {$n2rc == 0 && !$n2death && [kv $n2o PROP] eq {device=widget} \
           && [regexp {(?n)^CHILD_DONE$} $n2o]}] \
    "(rc=$n2rc death=$n2death prop=<[kv $n2o PROP]> sel=[kv $n2o SEL]\
 done=[regexp {(?n)^CHILD_DONE$} $n2o])"
}

# ================================ STATIC: THE GUARDS NO INPUT CAN REDDEN ==
# S1 / S2 — THE TWO netlist.c GUARDS, EACH BY NAME. Static because reset_caches() heals the
# NULL before either site runs (260 and 1576 instrumented visits, ZERO NULL), so no fixture
# can drive them; and load-bearing because with set_sym_flags()'s normalisation flipped they
# are the FIRST and SECOND segfault an ordinary `xschem netlist` hits. Each row asserts ONE
# guard, on live code, whitespace-tolerantly, and nothing here counts guards in the file.
set s12src  [slurp [file join $repo src netlist.c]]
set s12live [live_code $s12src]

# S1 — set_lab_or_pin_inst_attr(). ⚠ A `strcmp` SWEEP CANNOT SEE THIS SITE AT ALL:
# IS_LABEL_OR_PIN expands to four unguarded strcmp() inside xschem.h, which is why the
# issue's own 28-site list named the DOMINATED line below it and not this one. It was the
# only unguarded use of that macro in all of src/*.c -- the other seven write
# `type && IS_LABEL_OR_PIN(type)` -- so this is the single outlier in a tree otherwise
# uniformly careful about this exact macro, not one fragile site among many.
set s1toks {if ( j == 0 && xctx->sym[xctx->inst[i].ptr].type && IS_LABEL_OR_PIN ( xctx->sym[xctx->inst[i].ptr].type ) )}
check "S1 (1603) set_lab_or_pin_inst_attr() in src/netlist.c NULL-tests the symbol type before\
 IS_LABEL_OR_PIN -- the macro hides four unguarded strcmp() in xschem.h, and this was the only\
 one of its eight uses in src/\*.c without the `type && IS_LABEL_OR_PIN(type)` house guard.\
 First of the two segfaults reached when set_sym_flags()'s normalisation is flipped" \
  [expr {[string length $s12src] > 0 && [regexp [pat $s1toks] $s12live]}] \
  "(found=[regexp [pat $s1toks] $s12live] src=[string length $s12src]B\
 live=[string length $s12live]B)"

# S2 — instcheck()'s bus_tap. A DECLARATION INITIALISER, so it runs before every early
# return in the function: nothing downstream can shield it.
set s2toks {int bus_tap = xctx->sym[inst[n].ptr].type && ! strcmp ( xctx->sym[inst[n].ptr].type , \"bus_tap\" ) ;}
check "S2 (1603) instcheck() in src/netlist.c short-circuits its `bus_tap` declaration\
 initialiser on a NULL symbol type -- a typeless symbol is not a bus tap. It is an\
 initialiser, so it runs ahead of every early return in that function. Second of the two\
 segfaults reached when set_sym_flags()'s normalisation is flipped" \
  [expr {[string length $s12src] > 0 && [regexp [pat $s2toks] $s12live]}] \
  "(found=[regexp [pat $s2toks] $s12live] src=[string length $s12src]B)"

# S3 — THE INVARIANT, AND IT IS ONE TOKEN. set_sym_flags() normalises a missing `type=` to
# "" with my_strdup2; my_strdup -- the spelling used almost everywhere else in this tree --
# NULLs its destination on an empty source, and get_tok_value() returns "" for a missing
# token. reset_caches() runs set_sym_flags() over every symbol and prepare_netlist_structs()
# calls reset_caches() first, so THIS CALL is what keeps a NULL type out of every netlister,
# hilighter and net resolver. What flipping it costs, measured by the batch's verify crew:
# two sequential gdb-confirmed segfaults on an ordinary `xschem netlist` (netlist.c's
# IS_LABEL_OR_PIN test, then instcheck()'s bus_tap), and a clean run only once both were
# guarded -- which is the measurement that makes S1 and S2 defence in depth rather than
# decoration. The negative half is asserted too: nothing in live actions.c may write the
# my_strdup spelling into sym->type, so a flip cannot be green by adding a second call.
set s3src  [slurp [file join $repo src actions.c]]
set s3live [live_code $s3src]
set s3toks {my_strdup2 ( _ALLOC_ID_ , &sym->type , get_tok_value ( sym->prop_ptr , \"type\" , 0 ) ) ;}
set s3bad  {my_strdup ( _ALLOC_ID_ , &sym->type}
set s3have [regexp [pat $s3toks] $s3live]
set s3flip [regexp [pat $s3bad] $s3live]
check "S3 (1603) set_sym_flags() in src/actions.c still normalises a missing `type=` to \"\"\
 with my_strdup2 and NOT my_strdup -- get_tok_value() returns \"\" for a missing token and\
 my_strdup NULLs its destination on an empty source, so this ONE token is what converts a\
 NULL xSymbol.type into \"\" for every caller downstream of reset_caches(). Flipping it gave\
 two sequential segfaults on a plain `xschem netlist` before S1's and S2's guards existed" \
  [expr {[string length $s3src] > 0 && $s3have && !$s3flip}] \
  "(my_strdup2=$s3have my_strdup_flip=$s3flip src=[string length $s3src]B)"

# S4 — THE STATIC HALF OF N2, AND THE REASON IT EXISTS IS THAT N2 SELF-SKIPS WITHOUT A DEV
# DISPLAY. The defect was not a missing guard but a guard on the WRONG FIELD, so the row that
# fences it asserts BOTH halves: the correct spelling is present TWICE -- draw_symbol() and
# draw_temp_symbol() carry the same expression and the whole defect was that they disagreed --
# and the prop_ptr spelling is ABSENT. The absence is the real fence and is what a
# reintroduction reddens; the count of two is what a future divergence reddens. Neither is a
# count of "guards in the file": there are exactly two copies of this one expression and the
# row names which functions they are in.
set s4src  [slurp [file join $repo src draw.c]]
set s4live [live_code $s4src]
set s4ok   {( xctx->hide_symbols == 1 && ( xctx->inst[n].ptr + xctx->sym )->type && ! strcmp ( ( xctx->inst[n].ptr + xctx->sym )->type , \"subcircuit\" ) )}
set s4bad  {( xctx->hide_symbols == 1 && ( xctx->inst[n].ptr + xctx->sym )->prop_ptr &&}
set s4n    [regexp -all [pat $s4ok] $s4live]
set s4nbad [regexp -all [pat $s4bad] $s4live]
check "S4 (1603) BOTH copies of the hide-symbols subcircuit test in src/draw.c --\
 draw_symbol() and draw_temp_symbol() -- NULL-test `->type` and neither tests `->prop_ptr`.\
 The defect was a guard naming the WRONG FIELD, so this asserts the correct spelling twice\
 AND the wrong spelling zero times. Runs on both arms, which is why patch (b) is still fenced\
 when N2 self-skips for want of a dev display" \
  [expr {[string length $s4src] > 0 && $s4n == 2 && $s4nbad == 0}] \
  "(type_guarded=$s4n want=2 prop_ptr_guarded=$s4nbad want=0 src=[string length $s4src]B)"

## Both banners, for the same reason as test_ps_valid_1350.tcl: run_suites.sh scores a
## headless suite from its `^RESULT` line and T1 scores it from banner_rule.tcl's whole-line
## `OVERALL: ok`, which knows nothing about `RESULT:`. A suite registered in T1's `hcases`
## with only the first is scored `HARNESS: ... did not complete cleanly` -- a counted failure
## with every one of its own checks green.
if {$fail == 0} {
  puts "RESULT: ALL PASS ($pass checks)"
  puts "OVERALL: ok ($pass checks)"
} else {
  puts "RESULT: $fail FAILED ($pass passed)"
  puts "OVERALL: notok"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
