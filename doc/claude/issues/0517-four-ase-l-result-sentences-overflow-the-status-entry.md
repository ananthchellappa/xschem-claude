# 0517 — the four ASE-L result sentences overflow the status entry; the other 283 fit

**Status:** OPEN. Filed 2026-08-20 by the results/calculator batch measuring
round (no repo edit outside this file). **RESCOPED 2026-08-20** after a
verification round, and the correction is kept in the open because it is half
the value of the file: the first draft was titled *"every sentence the
Calculator can put on its status line overflows"* and said so three more times
in the body. **That universal is false.** A full census of everything that can
reach the widget — **287** distinct strings — finds **283 that fit** and **4
that do not**, and the four are exactly the sentence procs one commit
(`407dc86b`) added on the day this was filed. The defect is real and unchanged
— what was wrong was the quantifier over it: the old title claimed 287 strings,
four qualify. **Branch:** `fluid-editing`.
**Area:** `.calc.status.msg` (`src/calculator.tcl:619-625`, packed `:630`) and
the four procs that write to it — `calc::no_result_msg` (`:965`),
`calc::busy_msg` (`:979`), `calc::no_viewer_msg` (`:1038`),
`calc::browse_inert` (`:1184`).
**Specs:** `doc/claude/specs/calculator.md` R506-R509 (the status contract),
R603 (the entry is an Entry so a scalar stays copyable);
`doc/claude/specs/results_selection.md` §17 decision 7 (**U7**, `:2563-2567`)
and §7.1a **R503f**.
**Severity:** the refusal a user reaches by pressing **Eval** with no result is
cut mid-word, and the file already ruled that this is worse than saying nothing.
Three of the four are on a live path; the fourth (`browse_inert`) is latent —
see **Reachability**, and do not read this issue as four live defects.

---

## What happens

`.calc.status.msg` is a one-line `Entry`. On the shipped 656x680 window it is
**613 px** wide; the left inset is 2 px, so **609 px** of text render at
`xview 0`. It has no `-wraplength` — the option does not exist on an Entry, so
the widget physically cannot wrap. Font is `TkTextFont`, resolved here to
DejaVu Sans 10.

Almost everything the Calculator writes there fits. **Four strings do not**,
and they are the four `calc::*_msg`/`*_inert` sentences that item 10 added:

| proc | line | chars | px | over 609 px | rendered | ends |
|---|---|---|---|---|---|---|
| `calc::no_viewer_msg` | `src/calculator.tcl:1038` | 264 | 1855 | **3.05x** | 84 | `…the session's vie` |
| `calc::busy_msg`      | `src/calculator.tcl:979`  | 142 |  981 | **1.61x** | 85 | `…text is busy — th` |
| `calc::browse_inert`  | `src/calculator.tcl:1184` | 137 |  961 | **1.58x** | 86 | `…esult and does no` |
| `calc::no_result_msg` | `src/calculator.tcl:965`  | 106 |  731 | **1.20x** | 87 | `…g one with ASE-L ` |

**In every one of the four, the clause the sentence exists for is the clause
that falls off.**

* `no_viewer_msg` — 180 of 264 characters never render. Everything after
  `…reads the session's vie` is gone, including the entire second sentence
  (*"Run a simulation, or open the session's waveforms and then pick a result
  with ASE-L ▸ Results ▸ Select."*). The em-dash (index 88) and **both** `▸`
  separators (indices **245 and 255**) are past the edge, so R503f's whole
  point — *"it names the OBSTACLE … instead of asking for a gesture that cannot
  help"* (`src/calculator.tcl:1030-1037`) — reaches the user as the obstacle
  with no next action.
* `busy_msg` — the reader sees `…context is busy — th`. The lost 57 characters
  are `at is a refused context switch, not an empty result list.` The proc's own
  comment says the sentence *"names the mechanism and then denies the wrong
  reading in so many words"* (`src/calculator.tcl:977-978`, verbatim); the
  denial is exactly what is cut.
* `browse_inert` — cut at `…and does no`, truncating a negation into what reads
  as an affirmative. The lost text is `t make one. Pick one with ASE-L ▸ Results
  ▸ Select.`
* `no_result_msg` — cut at `…with ASE-L `. U7 ruled *"refuse, and name the next
  action"*; the name of the action is the only part that does not render.

### The other 283 fit, and that is what scopes this issue

The first draft asserted the overflow of the whole status line. Measured, the
opposite is true everywhere else. Enumerating every string that can reach
`.calc.status.msg` — the 108 catalogue help lines `calc::fn_hover` writes
(`src/calculator.tcl:1986-1991`), the 108 click lines `calc::fn_click` composes
(`:2020-2028`, 14 refusals + 94 `not implemented (phase 5)`), the 8 category
lines (`:1976-1981`), the 22 selector lines (`calc::sel_click` `:1384-1386` for
the 14 enabled, `calc::sel_refuse` `:1390-1392` for the 8 that
`calc::sel_disabled` `:1278-1289` names), every other `calc::inert` label in the
mode strip, the buffer toolbar, the Stack, the keypad and the four user
buttons, plus the two `res_toggle` lines (`:1215-1216`) — gives **287 distinct
strings**, of which **283 fit inside 609 px**:

| class | n | over 609 px | widest | widest string |
|---|---|---|---|---|
| `fnhelp` (`fn_hover`) | 107 | **0** | 469 px | `Group delay in seconds: the phase slope, degrees per Hz, negated` |
| `fninert` (`fn_click`) | 94 | **0** | 378 px | `function compressionVRI: not implemented (phase 5)` |
| `fnrefusal` (`fn_click`) | 14 | **0** | 474 px | `function spectralPower is not available: needs a C opcode not in v1` |
| `selinert` | 14 | **0** | 400 px | `selector data: signal picking: not implemented (phase 6)` |
| `selrefusal` | 8 | **0** | 462 px | `selector vswr is not available: no S-parameter analysis in ngspice` |
| `padinert` | 12 | **0** | 291 px | `operator ==: not implemented (phase 2)` |
| `modeinert` | 10 | **0** | 382 px | `plot destination New Strip: not implemented (phase 3)` |
| `fncat` | 8 | **0** | 283 px | `functions: Special Functions (56 entries)` |
| `btbinert` | 6 | **0** | 245 px | `ClrBuf: not implemented (phase 2)` |
| `stkinert` | 4 | **0** | 288 px | `Stack Recall: not implemented (phase 4)` |
| `userinert` | 4 | **0** | 245 px | `user 1: not implemented (phase 9)` |
| `misc` (`res_toggle`) | 2 | **0** | 151 px | `Results Dir expanded` |
| **`msgproc`** | **4** | **4** | **1855 px** | `calc::no_viewer_msg` |
| **TOTAL** | **287** | **4** | | |

(107 help lines for 108 rows: two rows share the help string *"Frequency
measured from the wave's crossings"*, and the census counts distinct strings.
The catalogue itself has 108 rows — the number `test_calc_skeleton.tcl:2618`
pins.)

Two of those rows are the budget comment's own numbers re-measured
independently: the widest composed `fn_click` refusal is **474 px**, which is
exactly what `src/calculator.tcl:1693-1694` records, and the 108-row /
72-character bound at `test_calc_skeleton.tcl:2611-2618` holds with 140 px of
headroom.
**The budget works wherever it was applied.** It was never applied to the four.

### Reachability — three live, one latent

| proc | how a user reaches it today |
|---|---|
| `calc::no_result_msg` | **live.** Press `Eval` with no result: `calc::eval_click` (`:1173-1177`) → `calc::require_result` (`:1166`) → `calc::no_result_advice` (`:1053-1056`). Also the Results Dir tooltip (`calc::results_tip` `:1084`, attached `:1124`). |
| `calc::no_viewer_msg` | **live**, same two paths, whenever `calc::sessions_without_viewer` is non-empty (`:1053-1054`). |
| `calc::busy_msg` | **live**, same two paths, on the refused-borrow arm (`:1161`, `:1083`). |
| `calc::browse_inert` | **latent.** Its only caller is the `-command` of `.calc.res.browse`, which is created `-state disabled` (`src/calculator.tcl:748-749`) and stays that way by ruling U9 (`:786`). |

`browse_inert` cannot fire, and the file says so twice. Its own comment:
*"The button is `-state disabled`, so Tk runs this from no click"*
(`src/calculator.tcl:1179-1181`), and the selector code states the mechanism in
full — *"Tk's button `invoke` and the Button class bindings both return early on
a disabled widget, so a disabled control's -command NEVER fires"*
(`:1363-1367`), which is why `sel_refuse` needed an explicit `<Button-1>` bind
that `browse_inert` does not have. Measured: with the status line pre-set to a
sentinel, a synthetic `<Button-1>`/`<ButtonRelease-1>` on `.calc.res.browse`
leaves it untouched, and so does an explicit `.calc.res.browse invoke`.

That does not make it a non-defect — it makes it a **latent** one, which is the
cheapest kind to fix and the wrong kind to describe as a live truncation. Its
sentence is 961 px today, and the day U9 is revisited it becomes live.

**The file already states this rule, and states it about this same widget:**

```tcl
# ⚠ THE REASON IS BUDGETED FOR THE COMPOSED LINE, not for itself.  fn_click
# writes `function <name> is not available: <reason>`, and RULING-3's whole point
# is that a greyed entry carries INFORMATION — a sentence cut mid-word carries
# less than none.  Measured on the shipped 656x680 window: .calc.status.msg is
# 613 px wide in TkTextFont, and the old N text made
# `function spectralPower is not available: needs a new C opcode; no N-route
# function ships in v1` 94 characters / 666 px, of which 85 rendered — the line
# ended "...no N-route function sh".  The text below makes the same line 67
# characters / 474 px.  S24 asserts the COMPOSED string for every dead row, not
# the reason alone.
```
— `src/calculator.tcl:1686-1695`, verbatim.

That comment's own numbers re-measure correct: `.calc.status.msg` is 613 px, and
~85 characters render. The budget was written, enforced for the function
catalogue — and never applied to the four sentences the same widget shows.

### The tail is reachable, but only by a gesture with no affordance

The entry is `-state readonly -takefocus 0`. Tab cannot reach it. A **click**
does focus it anyway — Tk 8.6's `::tk::EntryButton1` tests for `"disabled"`, not
`"normal"` (`/usr/share/tcltk/tk8.6/entry.tcl:356-358`) — and `<End>` then
scrolls the view to `0.670 .. 1.000`. So the user can read the rest by clicking
into a widget with no focus ring, no cursor and no scrollbar, and pressing a key
that gives no visual hint it will do anything.

### Neither fallback shows the whole string

**The tooltip is not an escape hatch.** `calc::results_tip`'s default arm
returns `calc::no_result_advice` (`src/calculator.tcl:1084`, `:1053-1056`) —
which *is* `no_viewer_msg` whenever a live ASE-L session has no viewer
(measured: force `calc::sessions_without_viewer` non-empty and
`calc::results_tip none {} {}` is byte-identical to `calc::no_viewer_msg`). That
string is attached to the Results Dir row at `src/calculator.tcl:1124`.
`balloon_show` packs a plain `label … -font fixed -text $arg` with **no
`-wraplength`** (`src/xschem.tcl:14943-14944`), and that label's requested width
for the 264-char sentence is **2235 px** — on a **1920 px** screen. (`-font
fixed` resolves here to DejaVu Sans 12, not a fixed-width face.)

**The history dropdown shows less than the entry does.** `calc::status` records
every message into a 50-entry history (`src/calculator.tcl:653-668`, `histmax`
at `:167`), and W34 is a 2-character `ttk::combobox` whose popdown is widened by
`-postoffset` (`calc::popdown_extra`, `:553`) to a **493 px** listbox in
`TkTextFont`, with **no `-xscrollcommand`** — so it clips. Measured: it shows
**67 / 69 / 71** characters of `no_viewer_msg` / `busy_msg` / `no_result_msg`,
against the entry's 84 / 85 / 87. Recalling a message through W34 shows *less*
of it than the line the user just failed to read.

## Reproducer

Three legs, all self-contained: no PDK, no simulator, no schematic, no write
under `~/.xschem`. **Leg 1** measures the four sentences against the widget,
**leg 2** is the census that scopes the issue to those four, **leg 3** shows
which of them a user can trigger.

### Reproducer 1 — the four sentences vs the widget

Save as `/tmp/repro_0517.tcl` and run on the dev display.

```sh
mkdir -p /tmp/calc0517conf
DISPLAY=:99 GUI_GATE=0 ./src/xschem --pipe -q --nolog --script /tmp/repro_0517.tcl
```

```tcl
# 0517 reproducer -- the Calculator's status line vs the sentences put on it.
set ::USER_CONF_DIR /tmp/calc0517conf          ;# never ~/.xschem
set ::update_recent_files 0
proc write_recent_file {args} {} ; proc update_recent_file {args} {} ; proc rawhist_write {args} {}
proc p {s} {puts $s; flush stdout}

calc::open; update idletasks; update
set w .calc.status.msg
set F [$w cget -font]

p "toplevel     [wm geometry .calc]   screen [winfo screenwidth .]x[winfo screenheight .]"
p "$w  class [winfo class $w]  state [$w cget -state]  takefocus [$w cget -takefocus]"
p "  width [winfo width $w] px   font [$w cget -font] = [font actual $F -family] [font actual $F -size]"
p "  no -wraplength option: [catch {$w cget -wraplength}]   (1 = the option does not exist)"

calc::status MMM 0; update idletasks
set inset [lindex [$w bbox 0] 0]
set usable [expr {[winfo width $w] - 2*$inset}]
p "  left inset $inset px -> usable text width $usable px"

proc vis {w s} {                       ;# chars that render fully, at xview 0
    calc::status $s 0; update idletasks; $w xview 0; update idletasks
    set lim [expr {[winfo width $w] - [lindex [$w bbox 0] 0]}]; set last -1
    for {set i 0} {$i < [string length $s]} {incr i} {
        set b [$w bbox $i]
        if {[lindex $b 0]+[lindex $b 2] <= $lim} {set last $i} else break
    }
    return [expr {$last+1}]
}
calc::browse_inert                      ;# this one only exists as a side effect
set BR $::calc::statusmsg
set L [list no_viewer_msg [calc::no_viewer_msg] busy_msg [calc::busy_msg] \
            browse_inert $BR no_result_msg [calc::no_result_msg]]
p ""
p "sentence        chars     px  over   shown   cut mid-word at"
foreach {n s} $L {
    set v [vis $w $s]
    p [format "%-14s %5d  %5d %5.2fx %5d   ...%s|" $n [string length $s] \
        [font measure $F $s] [expr {double([font measure $F $s])/$usable}] $v \
        [string range $s [expr {$v-17}] [expr {$v-1}]]]
}
p ""
set s [calc::no_viewer_msg]
p "no_viewer_msg, the [expr {264-[vis $w $s]}] characters the user never sees:"
p "  |[string range $s [vis $w $s] end]|"
p "  em-dash U+2014 at index [string first — $s]; U+25B8 at [string first ▸ $s] and [string last ▸ $s] -- all past the edge"

p ""
calc::status $s 0; update idletasks; $w xview 0; focus .calc; update
p "xview at rest                    [format %.3f [lindex [$w xview] 0]] .. [format %.3f [lindex [$w xview] 1]]"
event generate $w <Button-1> -x 300 -y 8; event generate $w <ButtonRelease-1> -x 300 -y 8; update
p "focus after a click in the box   [focus]"
event generate $w <Key-End>; update
p "xview after that click + <End>   [format %.3f [lindex [$w xview] 0]] .. [format %.3f [lindex [$w xview] 1]]"
$w xview 0; update idletasks

p ""
set h [winfo height .calc]
foreach {n s} $L {
    set hit {}
    for {set tw 640} {$tw <= 1920} {incr tw} {
        wm geometry .calc ${tw}x$h; update idletasks; update
        if {[vis $w $s] == [string length $s]} {set hit $tw; break}
    }
    p [format "%-14s first fits at toplevel width %s px (entry %s px)" $n $hit [expr {$hit eq {} ? {-} : [winfo width $w]}]]
}
wm geometry .calc 656x$h; update idletasks; update; calc::status {} 0

p ""
toplevel .b0517
foreach {n s} $L {
    catch {destroy .b0517.t}
    label .b0517.t -justify left -font fixed -text $s      ;# balloon_show's own widget
    p [format "balloon label for %-14s reqwidth %5d px  -wraplength [.b0517.t cget -wraplength]  (screen %d px)" \
        $n [winfo reqwidth .b0517.t] [winfo screenwidth .]]
}
destroy .b0517

p ""
calc::status [calc::no_result_msg]; calc::status [calc::busy_msg]; calc::status [calc::no_viewer_msg]
update idletasks
set cb .calc.status.hist
catch {ttk::combobox::Post $cb}; update idletasks; update
set lb [ttk::combobox::PopdownWindow $cb].f.l
set lf [$lb cget -font]; set lw [winfo width $lb]
p "history popdown listbox $lw px, font $lf, -xscrollcommand {[$lb cget -xscrollcommand]}"
foreach i {0 1 2} {
    set e [lindex [calc::status_history] $i]; set n 0
    for {set j 1} {$j <= [string length $e]} {incr j} {
        if {[font measure $lf [string range $e 0 [expr {$j-1}]]] <= $lw} {set n $j} else break
    }
    p [format "  history\[%d\] %3d chars, needs %4d px, shows %3d   ...%s|" $i [string length $e] \
        [font measure $lf $e] $n [string range $e [expr {$n-14}] [expr {$n-1}]]]
}
catch {ttk::combobox::Unpost $cb}
p ""
p "DONE"
exit 0
```

Actual output, `src/xschem` built 2026-08-19 18:16, HEAD `30d87dee`, dev display
`:99` (Xvfb 1920x1080x24 + openbox), Tk 8.6.14:

```
toplevel     656x680+1262+0   screen 1920x1080
.calc.status.msg  class Entry  state readonly  takefocus 0
  width 613 px   font TkTextFont = DejaVu Sans 10
  no -wraplength option: 1   (1 = the option does not exist)
  left inset 2 px -> usable text width 609 px

sentence        chars     px  over   shown   cut mid-word at
no_viewer_msg    264   1855  3.05x    84   ...the session's vie|
busy_msg         142    981  1.61x    85   ...text is busy — th|
browse_inert     137    961  1.58x    86   ...esult and does no|
no_result_msg    106    731  1.20x    87   ...g one with ASE-L |

no_viewer_msg, the 180 characters the user never sees:
  |wer — a result selected while the session has no viewer is not visible here. Run a simulation, or open the session's waveforms and then pick a result with ASE-L ▸ Results ▸ Select.|
  em-dash U+2014 at index 88; U+25B8 at 245 and 255 -- all past the edge

xview at rest                    0.000 .. 0.322
focus after a click in the box   .calc.status.msg
xview after that click + <End>   0.670 .. 1.000

no_viewer_msg  first fits at toplevel width 1902 px (entry 1859 px)
busy_msg       first fits at toplevel width 1028 px (entry 985 px)
browse_inert   first fits at toplevel width 1008 px (entry 965 px)
no_result_msg  first fits at toplevel width 778 px (entry 735 px)

balloon label for no_viewer_msg  reqwidth  2235 px  -wraplength 0  (screen 1920 px)
balloon label for busy_msg       reqwidth  1194 px  -wraplength 0  (screen 1920 px)
balloon label for browse_inert   reqwidth  1157 px  -wraplength 0  (screen 1920 px)
balloon label for no_result_msg  reqwidth   883 px  -wraplength 0  (screen 1920 px)

history popdown listbox 493 px, font TkTextFont, -xscrollcommand {}
  history[0] 264 chars, needs 1855 px, shows  67   ...culator reads |
  history[1] 142 chars, needs  981 px, shows  69   ... viewer's cont|
  history[2] 106 chars, needs  731 px, shows  71   ...ck an existing|

DONE
```

(The `+X+Y` on the first line is wherever the WM drops the window and varies
run to run; nothing else in the output does — two consecutive runs reproduced
byte-for-byte otherwise.)

### Reproducer 2 — the census that scopes it

The same harness, enumerating every string that can reach the widget instead of
only the four. This is the leg the first draft did not have, and running it is
what refuted its title. Save as `/tmp/repro_0517_census.tcl`, same command line.

```tcl
# 0517 census -- EVERY string that can reach .calc.status.msg, vs its width.
set ::USER_CONF_DIR /tmp/calc0517conf          ;# never ~/.xschem
set ::update_recent_files 0
proc write_recent_file {args} {} ; proc update_recent_file {args} {} ; proc rawhist_write {args} {}
proc p {s} {puts $s; flush stdout}

calc::open; update idletasks; update
set w .calc.status.msg
set F [$w cget -font]
calc::status MMM 0; update idletasks
set inset [lindex [$w bbox 0] 0]
set usable [expr {[winfo width $w] - 2*$inset}]
p "entry [winfo width $w] px, inset $inset px, usable $usable px, font [font actual $F -family] [font actual $F -size]"
p ""

set S {}
proc add {cls s} { global S; lappend S [list $cls $s] }

# 1. the four sentence procs
foreach n {no_result_msg busy_msg no_viewer_msg} { add msgproc [calc::$n] }
calc::browse_inert ; add msgproc $::calc::statusmsg

# 2. catalogue: hover help + click line (refusal or inert), one per row
foreach row [calc::catalogue] {
    set name [lindex $row 0]
    add fnhelp [lindex $row 5]
    set why [calc::fn_reason [lindex $row 2]]
    if {$why ne {}} { add fnrefusal "function $name is not available: $why" } \
    else { add fninert "function $name: not implemented (phase 5)" }
}

# 3. fn_cat_changed, one line per category
foreach cat [calc::fn_categories] {
    add fncat "functions: $cat ([llength [calc::fn_entries $cat]] entries)"
}

# 4. selectors: the 14 enabled write sel_click's line, the 8 disabled write
#    sel_refuse's, each with its OWN reason from calc::sel_disabled.
set dis [calc::sel_disabled]
foreach row [calc::sel_rows] { foreach grp $row { foreach id $grp {
    if {[dict exists $dis $id]} {
        add selrefusal "selector $id is not available: [dict get $dis $id]"
    } else {
        add selinert "selector $id: signal picking: not implemented (phase 6)"
    }
} } }

# 5. every other calc::inert label: mode strip, toolbar, Stack, keypad, user
foreach {lbl ph} {{pick scope Off} 6 {pick scope Family} 6 {pick scope Wave} 6 {Clip} 6 \
                  {Plot} 3 {Eval} 3 {Table} 10 \
                  {plot destination Append} 3 {plot destination Replace} 3 \
                  {plot destination New Strip} 3} {
    add modeinert "$lbl: not implemented (phase $ph)"
}
foreach {lbl ph} {{ClrBuf} 2 {ClrStk} 4 {M+} 9 {ME} 9 {Undo} 2 {Redo} 2} {
    add btbinert "$lbl: not implemented (phase $ph)"
}
foreach lbl {Push Pop Del Recall} { add stkinert "Stack $lbl: not implemented (phase 4)" }
for {set i 1} {$i <= 4} {incr i} { add userinert "user $i: not implemented (phase 9)" }
foreach tok [calc::pad_keys] { add padinert "operator $tok: not implemented (phase 2)" }
add misc {Results Dir collapsed}
add misc {Results Dir expanded}

array set cnt {} ; array set over {} ; array set widest {} ; array set widestx {}
set uniq {}
foreach e $S {
    lassign $e cls s
    if {[lsearch -exact $uniq $s] >= 0} continue      ;# distinct strings only
    lappend uniq $s
    incr cnt($cls)
    set px [font measure $F $s]
    if {![info exists widest($cls)] || $px > $widest($cls)} {
        set widest($cls) $px; set widestx($cls) $s }
    if {$px > $usable} { lappend over($cls) [list $px $s] }
}
p [format "%-12s %5s %5s %6s  %s" class n over widest "widest string"]
set tot 0; set totover 0
foreach cls [lsort [array names cnt]] {
    set no 0; if {[info exists over($cls)]} { set no [llength $over($cls)] }
    incr tot $cnt($cls); incr totover $no
    p [format "%-12s %5d %5d %6d  %s" $cls $cnt($cls) $no $widest($cls) $widestx($cls)]
}
p [format "%-12s %5d %5d" TOTAL $tot $totover]
p ""
p "the strings that OVERFLOW $usable px:"
foreach cls [lsort [array names over]] {
    foreach o $over($cls) {
        lassign $o px s
        p [format "  %-11s %5d px  %s" $cls $px $s]
    }
}
p ""
p "DONE"
exit 0
```

Actual output, same binary, HEAD and display:

```
entry 613 px, inset 2 px, usable 609 px, font DejaVu Sans 10

class            n  over widest  widest string
btbinert         6     0    245  ClrBuf: not implemented (phase 2)
fncat            8     0    283  functions: Special Functions (56 entries)
fnhelp         107     0    469  Group delay in seconds: the phase slope, degrees per Hz, negated
fninert         94     0    378  function compressionVRI: not implemented (phase 5)
fnrefusal       14     0    474  function spectralPower is not available: needs a C opcode not in v1
misc             2     0    151  Results Dir expanded
modeinert       10     0    382  plot destination New Strip: not implemented (phase 3)
msgproc          4     4   1855  The ASE-L session has no waveform viewer, and the Calculator reads the session's viewer — a result selected while the session has no viewer is not visible here. Run a simulation, or open the session's waveforms and then pick a result with ASE-L ▸ Results ▸ Select.
padinert        12     0    291  operator ==: not implemented (phase 2)
selinert        14     0    400  selector data: signal picking: not implemented (phase 6)
selrefusal       8     0    462  selector vswr is not available: no S-parameter analysis in ngspice
stkinert         4     0    288  Stack Recall: not implemented (phase 4)
userinert        4     0    245  user 1: not implemented (phase 9)
TOTAL          287     4

the strings that OVERFLOW 609 px:
  msgproc       731 px  No simulation results are loaded. Run a simulation, or pick an existing one with ASE-L ▸ Results ▸ Select.
  msgproc       981 px  Could not read the ASE-L session's result: the waveform viewer's context is busy — that is a refused context switch, not an empty result list.
  msgproc      1855 px  The ASE-L session has no waveform viewer, and the Calculator reads the session's viewer — a result selected while the session has no viewer is not visible here. Run a simulation, or open the session's waveforms and then pick a result with ASE-L ▸ Results ▸ Select.
  msgproc       961 px  Browse is deliberately inert: the Calculator consumes the session's result and does not make one. Pick one with ASE-L ▸ Results ▸ Select.

DONE
```

### Reproducer 3 — which of the four a user can actually trigger

Save as `/tmp/repro_0517_reach.tcl`, same command line.

```tcl
# 0517 -- can a user reach the Browse sentence at all?  And what does the one
# gesture that needs no setup put on the line?
set ::USER_CONF_DIR /tmp/calc0517conf          ;# never ~/.xschem
set ::update_recent_files 0
proc write_recent_file {args} {} ; proc update_recent_file {args} {} ; proc rawhist_write {args} {}
proc p {s} {puts $s; flush stdout}

calc::open; update idletasks; update
set w .calc.status.msg ; set F [$w cget -font]
set b .calc.res.browse
p "$b  state [$b cget -state]  command {[$b cget -command]}"
set ::calc::statusmsg ZZZ-sentinel; update idletasks
event generate $b <Button-1> -x 5 -y 5; event generate $b <ButtonRelease-1> -x 5 -y 5; update
p "after synthetic click        |$::calc::statusmsg|"
catch {$b invoke} r
p "after explicit \[\$b invoke\]   |$::calc::statusmsg|"
set ::calc::statusmsg ZZZ-sentinel; update idletasks
.calc.mode.eval invoke; update idletasks
p "after .calc.mode.eval invoke |$::calc::statusmsg|"
p "  = calc::no_result_msg? [expr {$::calc::statusmsg eq [calc::no_result_msg]}],\
 [font measure $F $::calc::statusmsg] px vs [expr {[winfo width $w]-4}] px usable"
set ::calc::statusmsg ZZZ-sentinel
calc::fn_click spectralPower; update idletasks
p "after calc::fn_click spectralPower ([font measure $F $::calc::statusmsg] px)"
p "  |$::calc::statusmsg|"
p "DONE"
exit 0
```

Actual output:

```
.calc.res.browse  state disabled  command {calc::browse_inert}
after synthetic click        |ZZZ-sentinel|
after explicit [$b invoke]   |ZZZ-sentinel|
after .calc.mode.eval invoke |No simulation results are loaded. Run a simulation, or pick an existing one with ASE-L ▸ Results ▸ Select.|
  = calc::no_result_msg? 1, 731 px vs 609 px usable
after calc::fn_click spectralPower (474 px)
  |function spectralPower is not available: needs a C opcode not in v1|
DONE
```

Pressing `Eval` in the default state is the one gesture that puts an
overflowing sentence on screen with no setup at all: **731 px into 609 px**.
`Browse` puts nothing anywhere.

The window would have to be **1902 px** wide before `no_viewer_msg` renders —
18 px short of this 1920 px screen, and impossible on any narrower one. The
shipped default is 656 px and `wm minsize` is 626x680.

## Why it matters

1. **The file broke a rule it wrote about this exact widget, and the census
   proves the rule works everywhere it was applied.** Someone measured 613 px,
   found a 94-char line rendering 85 characters, shortened the text and pinned
   it with a check (`src/calculator.tcl:1686-1695`, cde74bc7, 2026-08-15;
   `tests/headless/test_calc_skeleton.tcl:2627-2639`). The 122 strings that
   budget actually covers all still fit — and so do the other 161 nobody
   bounded, the widest of all 283 being 474 px, a comfortable 135 px inside the
   line. Five days later **all four** of these sentences arrived in a **single
   commit** —
   `git log -S 'proc calc::<name>' -- src/calculator.tcl` returns exactly
   `407dc86b`, 2026-08-20, *"feat(calculator): consume the ASE-L session's
   selected result"*, for each of the four — and every one is 1.20x-3.05x over
   that same budget. This is not four independent slips; it is one commit that
   did not know the rule existed.
2. **0516's rework will write more of them.** Issue 0516 is RULED and awaiting
   implementation: the ASE-L session owns the result (`results_selection.md`
   §17.3, U13-U18), which means `calc::no_viewer_msg` — today's worst offender
   at 3.05x — gets rewritten, and the new arms need new sentences. Ruling the
   budget once, now, is what stops the rework shipping four more overflowing
   lines. `no_viewer_msg` is **zero days old** — 407dc86b landed 2026-08-20, the
   day this issue was filed (R503f, item 10) — which is how fast the drift
   happens, and how little of it a review caught.
3. **The one gesture that needs no setup already shows a cut sentence.**
   `calc::eval_click` (`:1173-1177`) is reachable from a freshly opened
   Calculator with nothing loaded — measured in Reproducer 3,
   `.calc.mode.eval invoke` puts `no_result_msg` on the line at **731 px into
   609 px**. It is *not* the only refusal the window gives — the 14 `fn_click`
   refusals are reachable too (`src/calculator.tcl:1958`, the canvas binds
   `<Button-1>` on greyed rows as well as live ones), and all 14 fit. It is the
   one a user meets first, and it is U7's ruled words cut exactly where the
   ruled action is named.
4. **`browse_inert`'s truncation is latent, and that is the reason to fix it
   now, not a reason to ignore it.** Cut at `and does no` the sentence does not
   merely stop, it inverts: `calc::inert`'s own comment (`:604-606`) rules that
   "not implemented" may only be said where a phase really is coming, which is
   why this sentence was written the long way, and what would render is
   `…the Calculator consumes the session's result and does no` — neither of the
   two things the wording was chosen between. **Nobody can see that today.**
   The button is permanently disabled by U9 (`:748-749`, `:786`) and a disabled
   button's `-command` never fires — the file states the mechanism itself at
   `:1363-1367`, and Reproducer 3 measures it. Shortening it costs nothing and
   removes a defect that would ship the day U9 is revisited. Calling it a live
   truncation, as this issue's first draft did, is the error the rescope
   exists to not repeat.

## Fix — candidates in order

**(b) Cap every sentence at the measured budget — recommended, for the three
crew-owned sentences.**
Priority within the three, by reachability (see *Reachability* above):
`no_viewer_msg` first — live, 3.05x, and the only one no window width can
rescue — then `busy_msg` (live, 1.61x), then `browse_inert` (latent, 1.58x,
free to fix now).
The budget is **609 px**. A character count is only a drafting rule of thumb,
and 85 is the wrong one: measured, the first 85 characters of these four
sentences run **594-617 px**, so 85 already overflows for `no_viewer_msg`'s own
glyph mix, and 85 capital `W` would be 1190 px. The conservative form already
exists in the suite — `test_calc_skeleton.tcl:2611-2618` and `:2627-2639` bound
two other string families at **72 characters**, which for these four runs
**497-525 px** and always fits. Reuse that number for drafting, and let the
check measure pixels.
Cost, measured: at 72 characters `no_viewer_msg` must lose 192 of 264 (73%),
`busy_msg` 70 of 142 (49%), `browse_inert` 65 of 137 (47%). That is a real
rewrite of R503f's sentence, not a trim — but R503f's own justification for the
long form is that both steps of the door are real, and a door description nobody
can read is not a door description. **`no_result_msg` is excluded — see the
ruling note below.**

**(d) Give the balloon a `-wraplength` so the full text is reachable by hover —
recommended alongside (b), not instead of it.**
`balloon_show` already carries the commented-out widget that would have done it
(`src/xschem.tcl:14941-14942`, a `message -aspect 10000`). Cost: `balloon_show`
is global — **34** invocation sites, `src/xschem.tcl` (30),
`src/wave_viewer.tcl` (2) and `src/calculator.tcl` (2), counted with
`grep -nE '(^|[^_a-zA-Z])balloon +(\.|\$)' src/*.tcl | grep -v 'proc balloon'`
— so a `-wraplength` in `balloon_show` re-lays out every tooltip in xschem:
visible, low-risk, but a change nobody asked for and one that touches
`src/xschem.tcl`. A local variant
(`balloon_show` gaining an optional wrap argument, or the Calculator packing its
own tooltip) confines it. Either way this is the **secondary** channel: it does
not repair the line the user is looking at, and hovering the Results Dir row is
not where a user looks after pressing Eval.

**(c) A two-line status region — not recommended.**
Measured at 609 px the four sentences wrap to **4 / 2 / 2 / 2** display lines,
so two lines fixes three of four and leaves the worst one cut. Cost: the status
frame is 23 px and `TkTextFont`'s linespace is 17 px, so a second line adds
17 px to a window whose height floor (`wm minsize`) is already 680.

**(a) Replace the Entry with a wrapping widget — last, and only in one form.**
The Entry is deliberate: `src/calculator.tcl:531-534` says *"W33 is an ENTRY,
not a label: R603 requires an evaluated scalar to be left selectable and
copyable, and only an entry gives that."* Measured, that capability is real —
`<<Copy>>` on the readonly entry does put the selection on the CLIPBOARD. A
plain `label`/`message` loses it and is therefore out.
The one form that survives R603 is a **`text -state disabled`**: measured, a
disabled text still selects and still answers `<<Copy>>` (CLIPBOARD read back
correctly). Its cost is height: a wrapping widget 609 px wide needs
`reqheight` **72 px** for `no_viewer_msg` against the entry's 21 px, so the
status region would grow from 23 px to ~74 px and shrink back as messages
arrive — a status bar that moves. `src/calculator.tcl:460` already rules that
class of thing out for a different reason (*"a status line that moved when you
dragged a sash would be a bug"*), and `test_calc_skeleton.tcl` S7 pins it. A
fixed 2-line disabled text avoids the movement and collapses into (c)'s
"fixes three of four".

### ⚠ `calc::no_result_msg` is a USER ruling and a crew may not shorten it

Its text is **U7**, ruled verbatim by the user on 2026-08-18
(`doc/claude/specs/results_selection.md:2563-2567`), and
`src/calculator.tcl:1047-1052` states the rule that keeps it unconditional. It
is also pinned **by exact text** in two checks —
`tests/headless/test_calc_skeleton.tcl:1319` and `:3347`. Any (b) applied to it
is an overturn, not an edit, and needs the user's word.
Mitigating: it is the *least* overflowing of the four at 1.20x, and it is the
cheapest to rescue by widening the window — **778 px** and it fits whole.
Widening is not exclusive to it, though, and an earlier draft of this file said
it was: measured in Reproducer 1, `browse_inert` fits at **1008 px** and
`busy_msg` at **1028 px**, both comfortably inside the 1920 px screen this was
measured on. **`no_viewer_msg` is the only one widening cannot reach** — it
needs **1902 px**, 18 px short of the screen, and is impossible on any narrower
one. So if the user declines to shorten U7's sentence, the honest alternative
is to raise the Calculator's default width (656 -> 778 px covers
`no_result_msg`, and 1028 px would cover three of the four on a large display
— at the cost of a window nobody asked for), while (b) stays **required** for
`no_viewer_msg` regardless.

## Coverage

Nothing asserts a length or pixel bound on any of the four sentences. The check
shape already exists twice in `tests/headless/test_calc_skeleton.tcl` and simply
does not include them (excerpt, `;#` markers added here):

```tcl
check "S24 every help line is short enough for the status entry" \
    [list [llength $rows] $longhelp] {108 {}}          ;# :2617-2618, bound 72
check "S24 every refusal line fn_click composes fits the status entry too" \
    [list $nrefusals $longrefusal] {14 {}}             ;# :2638-2639, bound 72
```

Both bound `string length` at 72, and both are green and *earned* — the census
shows all 108 help lines and all 14 composed refusals inside 609 px, the widest
at 469 px and 474 px. The gap is not that the budget is wrong; it is that
neither check can see a `proc calc::*_msg`.

A test would have to assert:

1. **Every status sentence fits, measured in pixels, not characters.** Enumerate
   the four procs (and any 0516 adds), and assert
   `font measure [.calc.status.msg cget -font] $s <= [winfo width .calc.status.msg] - 4`
   at the shipped default geometry. The `- 4` is measured, not guessed
   (`-borderwidth 1`, `-highlightthickness 0`, plus Tk's 1 px pad, each side):
   the thresholds are exact — entry 1859 px renders all 264 chars of
   `no_viewer_msg` (1855 px) and 1858 px renders 263.
2. **The list is closed.** A check that walks a hand-written list of four procs
   goes green the day a fifth is added. Derive the set — e.g. every
   `proc calc::*_msg`/`*_inert` in the file, or a registry the sentences must
   join — so a new one cannot skip the bound. This is the failure mode that
   produced the defect: `:2617` bounds the catalogue field, `:2638` bounds the
   composed refusal, and neither could ever see a new proc. A commit that adds
   four sentences at once (407dc86b did exactly that) walks straight past both.
3. **Latency is not exemption.** `browse_inert` is unreachable today and must
   still be in the bound — a check that skips the strings no gesture currently
   produces re-creates the hole the day the gesture arrives. Assert the
   *string*, from the proc, not the widget contents after a click.
4. **The rendered length, not just the measured one** — at least one leg that
   drives the real widget (`$w bbox $i`) rather than `font measure`, so a future
   change to inset, border or padding is caught.
5. **The fallbacks, if they are relied on.** If (d) is taken, assert the balloon
   label's `-wraplength` is non-zero and its `reqwidth` is under
   `winfo screenwidth`. If the history is ever claimed as a fallback, assert the
   popdown shows the full entry — today it shows 67 of 264 characters.
6. **Sabotage direction:** lengthen one sentence by one character past the
   bound and the check must go red; the existing S24 pair stays green either
   way, which is the proof the new check is not redundant. And run the census
   leg once as its own sabotage: it must report 4 over, not 287 — a check that
   would go red on the whole status line is measuring the wrong thing, which is
   how this issue's first draft went wrong.

Environment note: the pixel numbers above are DejaVu Sans 10 on `:99`. A bound
computed live from `font measure` and `winfo width` travels; a hardcoded 613 or
609 does not — see issue **0417** for a Calculator check that pinned a font
metric and went red on a different display.

## Related

- **0516** — the `here`-arm collision, RULED and awaiting implementation. Its
  rework rewrites `calc::no_viewer_msg`, the 3.05x offender, and will write new
  sentences. This budget should be ruled before that lands.
- **0518** — the Results Dir row goes stale when the ASE-L session or its
  viewer closes. Same window, and the surface it names came from this same
  commit (`calc::results_publish` and `calc::require_result` are both
  `407dc86b`, results batch item 10). They meet in that issue's leg B: the row
  is stale *and* `calc::no_viewer_msg`, the sentence sent to correct it, is
  this issue's 3.05x offender, cut at `…reads the session's vie`. Fixing 0518
  puts that sentence in front of the user MORE often, not less.
- **0417** — `test_calc_widgets` R111 pins a font-metric coincidence; the same
  caution applies to any bound this issue's coverage adds.
- `doc/claude/specs/results_selection.md` §17 decision 7 (U7, `:2563-2567`),
  §7.1a R503f — the two sentences a crew may and may not touch.
- `doc/claude/specs/calculator.md` R506-R509 (the status contract), R603 (why
  W33 is an Entry).
- `src/calculator.tcl:1686-1695` — the budget the file states and enforces on
  122 strings, and then does not apply to four.
- `doc/claude/calculator_batch/LEDGER.md` — the batch that owns this window.
  Its item 4 (`cde74bc7`) is where the 613 px budget was measured and enforced,
  and its item 8 (phase 3a, Evaluate / R603-R607) is the next item that will
  write status sentences. `doc/claude/results_batch/LEDGER.md` item 10
  (`407dc86b`) is where all four of these arrived.
- **On this file's own first draft.** It shipped with the title *"every sentence
  the Calculator can put on its status line overflows"*, and repeated that
  universal in the Severity line and the body. A census of the widget refuted it
  in one run: 283 of 287 fit. It also called `browse_inert` one of "the two
  paths a user can actually reach" while quoting the comment three lines above
  the proc that says the opposite, and split four sentences from one commit into
  "three written later and one the same day". The measurements were sound; the
  **quantifiers over them were never checked**. Recorded here rather than
  silently applied: an issue that says what it got wrong is worth more than one
  that quietly narrows its title.
