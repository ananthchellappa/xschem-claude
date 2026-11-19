# Issue 1723: the sabotage sweep (crew R, 2026-11-19)

A dated record, not a baseline: it was measured on the working tree that became the commit adding this
file (parent `777efaf24`), and nothing re-runs it. The counts below are what that tree printed; a later
edit to either suite moves them.

## Method

A scratch Tcl driver (it is not committed; its full text is below) took one exact substitution per
sabotage. Each `old` string had to occur exactly once in its file, or the driver refused it. The
driver then:

1. wrote the sabotaged copy over `src/ase.tcl` or `src/ase_window.tcl` in the worktree;
2. ran the named suite through `tests/headless/gated_xschem.sh` (armed throwaway HOME):
   - `S*` ran `test_ase_preflight` with `--nogui` and `DISPLAY=` (the counted headless arm);
   - `W*` ran `test_ase_window` with `AUDIT_DISPLAY=private`, a private Xvfb with openbox;
3. collected the `FAIL:` rows and any column-0 `FATAL` or `UNEXPECTED ERROR`;
4. restored the original in a `finally`.

Both files' md5 matched the pre-sweep copies afterwards (`src/ase.tcl` `1ac6c7c0…`,
`src/ase_window.tcl` `5d7b092d…`).

## Results

The clean tree: `test_ase_preflight` ALL PASS (271), `test_ase_window` ALL PASS (363 on the display
arm, 71 `--nogui`).

| sabotage | what it breaks | red rows |
|---|---|---|
| S01 | the resolver records no `miss` | PF1723a c c2 d e g h h2 p i j k l l2 o o2 n n2 (18) |
| S02 | a fold-ambiguous segment is searched too | PF1723q |
| **S03** | the try loop without the defined-master pre-filter | **none (declared survivor, below)** |
| S04 | the try keeps instances under which the rest does not resolve | PF1723b c c2 d e g h h2 i j k l l2 o o2 n n2 (17) |
| S05 | several candidates offer the first (`nc >= 1`) | PF1723g |
| S06 | the union decides, not the intersection | PF1723h h2 |
| S07 | measurements decide beside the outputs | PF1723i j o o2 n n2 |
| S08 | a measurement-only prefix has no deciders | PF1723k |
| S09 | a stale measurement refuses the run | PF1723k n2 |
| S10 | only a measurement's `target` field is scanned | PF1723i j o o2 n |
| S11 | the include count drops the `.` after the prefix | PF1723l l2 |
| S12 | the include count drops the left boundary | PF1723l l2 |
| S13 | the include count is always case-sensitive | PF1723l l2 |
| S14 | the include file is edited | PF1723l2 n2 |
| S15 | a rename is also called a case mismatch | PF1723e |
| S16 | a rename line uses the case wording | PF1723d e |
| S17 | the remedy sentence only for a case mismatch | PF1723e j |
| S18 | the apply skips the measurements | PF1723o o2 n |
| S19 | the apply counts measurement fields, not rows | PF1723o o2 n |
| S20 | `preflight_fix_session` does not write the session | PF217e f g, PF221aa ab ac, PF1723n n2 |
| S21 | the refusal predicate says yes to everything | PF1723m o3 |
| S22 | the scan never runs the rename solver | PF1723c c2 d e g h h2 p i j k l l2 o o2 n n2 (17) |
| S23 | a case row carries no `fixkind` | PF1723f |
| S24 | the offer ignores the predicate | PF1723o3 |
| S25 | the offer counts every output as a rename | PF1723o4 |
| S26 | `preflight_fix_session` also saves | PF217f, PF1723n n3 |
| W01 | a refused Run offers nothing | FX1723b d d2 e f g h j (8) |
| W02 | Apply does not run the command | FX1723f g h |
| W03 | Apply does not repopulate the panes | FX1723h |
| W04 | Dismiss applies | FX1723e f g |
| W05 | a refusal with nothing to offer leaves a stale banner up | FX1723j |
| W06 | D1 broken: the refusal applies silently | FX1723c e f g h |
| W07 | Apply also saves | FX1723f i j k |
| W08 | a started Run leaves the offer up | FX1723k |

Every new row except FX1723a was reddened by at least one sabotage. FX1723a ("the banner does not exist
before any Run") is the precondition that makes FX1723b's banner the Run's doing. No product code
creates the banner early, so there was nothing to sabotage there.

### The declared survivor, S03

`ase::preflight_rename_try` skips an instance whose master is not a subcircuit the netlist defines,
before resolving the rest of the path under it. The resolver would answer `absent` for that instance
anyway (the rest of the path cannot resolve under a master with no scope). The skip only saves a
resolve per primitive device in a large scope. Its removal changes no answer, so no row can see it,
and none should.

### What the sweep fixed in the suite

The first W01 run reddened FX1723b and d, then aborted the band on FX1723d2 (`winfo y` of the absent
banner). That deleted the band's remaining rows from the verdict (353 passed + 3 failed, against 362).
FX1723d2 now asks `winfo exists` first. The re-run reddens 8 rows with none lost (354 + 8 = 362, the
band's count then). FX1723k and the S26/W07/W08 sabotages were added after the first round: no
sabotage had reached PF1723n3, FX1723i ("nothing is saved until the user saves") or the `run_started`
hide.

## The driver

The SAB list is `{name file old new suite arm}`, where `$PF` and `$WN` are the two suite paths. The
lists were `list.tcl` (S01 to S25, W01 to W06) and a second round (S26, W07, W08).

```tcl
set W <the worktree>
set S [file dirname [file normalize [info script]]]
proc slurp {p} { set f [open $p r]; fconfigure $f -encoding utf-8; set t [read $f]; close $f; return $t }
proc spit {p t} { set f [open $p w]; fconfigure $f -encoding utf-8; puts -nonewline $f $t; close $f }
set PF tests/headless/test_ase_preflight.tcl
set WN tests/headless/test_ase_window.tcl
source [file join $S list.tcl]
set orig(src/ase.tcl) [slurp [file join $W src/ase.tcl]]
set orig(src/ase_window.tcl) [slurp [file join $W src/ase_window.tcl]]
set res [open [file join $S results.txt] w]
foreach {name file old new suite arm} $SAB {
  set t $orig($file)
  set n 0 ; set k -1
  while {[set k [string first $old $t [expr {$k + 1}]]] >= 0} { incr n }
  if {$n != 1} { puts $res "$name | PATTERN-MATCHED-$n-TIMES | -" ; continue }
  set i [string first $old $t]
  set t2 [string replace $t $i [expr {$i + [string length $old] - 1}] $new]
  try {
    spit [file join $W $file] $t2
    if {$arm eq {nogui}} {
      set cmd [list env DISPLAY= timeout 600 [file join $W tests/headless/gated_xschem.sh] \
                 --nogui --pipe -q --nolog --script [file join $W $suite]]
    } else {
      set cmd [list env AUDIT_DISPLAY=private timeout 900 [file join $W tests/headless/gated_xschem.sh] \
                 --pipe -q --nolog --script [file join $W $suite]]
    }
    catch {exec {*}$cmd 2>@1} out
    set reds {}
    foreach line [split $out \n] {
      if {[regexp {^FAIL:\s+(\S+)} $line -> r]} { lappend reds $r }
      if {[regexp {^(FATAL|UNEXPECTED ERROR)} $line]} { lappend reds "<<$line>>" }
    }
    set tail {} ; regexp -line {^RESULT:.*$} $out tail
    puts $res "$name | [llength $reds] red | [join $reds {, }] | $tail"
  } finally {
    spit [file join $W $file] $orig($file)
  }
}
close $res
```
