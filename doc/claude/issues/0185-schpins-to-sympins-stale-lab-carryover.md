# 0185 — `schpins_to_sympins()` carries `lab` and `dir` over from the previous pin

Status: **FIXED** 2026-07-31
Area: `src/xschem.tcl` — `schpins_to_sympins()`
Tests: `tests/headless/test_schpins_stale_lab_0185.tcl` — **15 checks**
Found: 2026-07-31, while fixing 0183 in the same proc
Related: 0183 (an empty attribute value swallows the next property token)

## What happens

`schpins_to_sympins()` turns the selected schematic pins into symbol pin boxes. It copies
the selection to `$USER_CONF_DIR/.clipboard.sch`, rewrites every `C {…ipin.sym} …` line
into a `B 5 … {name=<lab> dir=<dir>}` box, and pastes the result.

Both `lab` and `dir` are assigned **only inside their own regexp guard**, in a loop over
every clipboard line, and neither is reset per line:

```tcl
foreach i $lines {
  if {[regexp {^C \{.*(i|o|io)pin} $i ]} {
    if {[regexp {ipin} [lindex $ii 1]]} { set dir in }        ;# only on a match
    …
    while {1} {
      if { [regexp {lab=} $i] } { … set lab … }               ;# only on a match
      if { [regexp {\}} $i]} { break}
    }
```

So a pin line carrying no `lab=` token keeps the **previous** pin's value. Three distinct
shapes, all measured:

### 1. A later unlabelled pin steals the previous pin's name

```
C {devices/ipin.sym} 0   0 0 0 {name=p1 lab=GOOD}
C {devices/ipin.sym} 0 -20 0 0 {name=p2}            <- no lab=

pre-fix   B 5 … {name=GOOD dir=in}     <- p1
          B 5 … {name=GOOD dir=in}     <- p2, SAME NAME   + T {GOOD} text too
post-fix  B 5 … {name=GOOD dir=in}
          B 5 … {name="" dir=in}
```

Two symbol pins with one name is a silent connectivity defect: the netlister can no longer
tell them apart, and the second pin has lost its identity. The drawn `T {…}` label carries
over with it, so the symbol *looks* right to a reader skimming it.

### 2. An unlabelled FIRST pin destroys the clipboard and generates nothing

With no earlier pin to inherit from, `lab` has never been set:

```
can't read "lab": no such variable
```

thrown **after** `[open $USER_CONF_DIR/.clipboard.sch w]` has already truncated the file.
So the user's copy is gone, no symbol is produced, `$fd` is left open, and the trailing
`xschem paste` never runs. Measured: zero `B 5` lines in the clipboard afterwards.

### 3. The line filter matches too much, and the phantom pin inherits a direction

The filter is `regexp {^C \{.*(i|o|io)pin} $i` — it matches anywhere in the **line**, not
just in the symbol name. A `lab_pin` whose label happens to be `ipin`

```
C {devices/lab_pin.sym} 0 -20 0 0 {name=l1 lab=ipin}
```

passes the filter, fails all three `[lindex $ii 1]` direction tests, and pre-fix was
emitted as a **phantom pin box** carrying the previous pin's `dir`.

## The fix

Reset both variables per line, and skip a line that yielded no direction — it is not a pin:

```tcl
set lab {}
set dir {}
if {[regexp {ipin} [lindex $ii 1]]} { set dir in }
if {[regexp {opin} [lindex $ii 1]]} { set dir out }
if {[regexp {iopin} [lindex $ii 1]]} { set dir inout }
if {$dir eq {}} { continue }
```

Shape 2 stops being an error at all, so the `close $fd` leak on that path disappears with
it rather than needing its own restructuring.

## Relationship to 0183

Same proc, different defect. 0183 fixed the *emission* — `name=$lab` with an empty `$lab`
produced `name= dir=in`, and `get_tok_value()` then read `dir=in` as the **name**, leaving
the generated pin with no direction at all. That fix (quoting the empty value as `name=""`)
is what legs SF3/SM1 depend on.

0185 is why the empty case is reachable in the first place, and it is strictly worse: 0183
lost an attribute, 0185 either duplicates a pin name or throws away the user's clipboard.
The 0183 write-up recorded this as *"a separate latent bug noticed there and NOT fixed"*;
this is that fix.

## Verification

`tests/headless/test_schpins_stale_lab_0185.tcl` — 15 checks.
**RED verified** against the pre-fix `xschem.tcl` (`git show HEAD:src/xschem.tcl`, i.e. with
0183 already fixed, so the legs isolate *this* defect): **8 FAILED / 7 passed**. After the
fix, 15/15.

The failures pin every shape: SL3/SL5 the name and text carry-over, SF1–SF4 the abort and
the destroyed clipboard (0 boxes generated), SD2 the phantom box, SM1 both carry-overs at
once (`name=IO1 dir=in`).

The test uses the **real** `$USER_CONF_DIR/.clipboard.sch` — `xschem copy` writes it from
the C side and `USER_CONF_DIR` is fixed at init, so a test cannot redirect it. It saves the
developer's clipboard first and restores it at the end.
