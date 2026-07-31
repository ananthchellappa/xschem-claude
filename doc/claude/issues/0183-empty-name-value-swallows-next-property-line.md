# 0183 — an empty attribute value swallows the next property token

Status: **FIXED** 2026-07-31 — **ten** producers repaired over three sweeps. The first
sweep ran as five slices and two died on API errors; their re-run held three of the first
six defects. A third, pattern-agnostic sweep then found four more — the two on the "make symbol
from schematic" path, which is the most reachable of the lot, and the gEDA importer.
Area: `src/token.c` (`str_is_blank()`), `src/util.c` (`my_mstrcat_tok()`), `src/actions.c` (`create_pin()`,
`place_symbol()`, `get_additional_symbols()`), `src/save.c`, `src/token.c`,
`src/xschem.tcl` (`schpins_to_sympins()`, `create_symbol()`),
`src/make_sym.awk`, `src/make_sym_lcc.awk`, `src/gschemtoxschem.awk`
Tests: `tests/headless/test_empty_value_swallows_token_0183.tcl` — **62 checks**
Found: 2026-07-31, by the `my_mstrcat` NULL-vararg audit that issue 0180 spawned
Related: `doc/claude/code_analysis/my_mstrcat_null_vararg_audit.md`, 0180

## What happens

A property string is whitespace-separated `key=value` tokens read by `get_tok_value()`.
The whitespace after `=` is **skipped**, so an empty value is read as "the value is the
next thing along" — and the next token is consumed whole and ceases to exist:

```
name=
flags=graph,unlocked      ->  name == "flags=graph,unlocked" ; flags NOT FOUND
lock=1                        lock == "1"  (exactly ONE token is eaten)
```

## The tokenizer is NOT the bug — decided on evidence

The two candidate fixes were the producer or the tokenizer. **The tokenizer is off the
table**: its whitespace-skip is deliberate and load-bearing in a shipped library file.
`xschem_library/ngspice_verilog_cosim/tb_sar_adc.sch:176` (and `sar_adc.sch:78`):

```
C {dac_bridge.sym} 330 -160 0 0 {name=A2 dac_bridge_model= dac_buff
```

The author wrote a space after `=` and **meant** the value `dac_buff`. Re-measured
2026-07-31: `get_tok_value` on that string returns `dac_buff`, and `name` and
`device_model` either side of it read correctly. Changing the grammar would silently
break that file and any user schematic written the same way. Test leg **ET12** is the
guard rail on this decision.

**The grammar already has a way to say "empty": `key=""`.** It reads back as *present with
an empty value* and the following token survives (ET04/ET04b). That is what a producer
should emit.

## Characterised — 13 measured cases, all re-measured before the fix

| property string | result |
|---|---|
| `name=\nflags=graph,unlocked\nlock=1\n` | `name` = `flags=graph,unlocked`, `flags` **not found** |
| `name= flags=… lock=1` | identical — **a space behaves like a newline** |
| `name=\tflags=…` | identical — **a tab too** |
| `name=""\nflags=…\n` | `name` = `` (**found**), `flags` = `graph,unlocked` |
| `flags=…\nname=\n` | `name` = ``, **found = 0** |
| `a=1\nname=\nflags=graph\nb=2\n` | `name` = `flags=graph`; `a` and `b` unharmed |
| `lab=\nvalue=1k\n` | `lab` = `value=1k` — **not specific to `name`** |
| `name=\nlab=\nvalue=1k\n` | `name` = `lab=`; `value` still `1k` — **exactly one token eaten** |
| `name=\n\nflags=graph\n` | a blank line does not stop it |
| `name=` | `name` = ``, **found = 0** |
| `name=g1\nflags=…\n` | control — both correct |
| `…dac_bridge_model= dac_buff…` | `dac_buff` — the shipped-file case |

`xschem get_tok_size` is 0 when the token was not found and the token-name length when it
was; that pair is the only way to tell **absent** from **present but empty**, so every test
leg carries both.

## The fix

New in `src/util.c`, next to `my_mstrcat`:

```c
size_t my_mstrcat_tok(int id, char **str, const char *key, const char *value,
                      const char *tail);
```

It appends one `key=value` pair, writing an empty value as the quoted `key=""`. The quotes
must be part of a **literal**: `my_mstrcat` SKIPS an empty argument and keeps walking its
varargs (`util.c:783`), which is exactly what produces the bare `key=` in the first place,
so wrapping the variable in `"\"" , value, "\""` would not help.

It lives in `util.c` rather than `actions.c` because the class is not file-local, and that
turned out to be the right call: the ten repaired sites are spread over `actions.c`,
`save.c`, `token.c`, `xschem.tcl` and three awk scripts. The four sites that do not build
their string with `my_mstrcat` — `save.c`'s `my_snprintf`, the Tcl `puts`, the awk
`printf` — each write the quoted empty form inline instead.

### Site 1 — `create_pin()`, the WORSE one, and not the reported site

```c
src/actions.c   my_mstrcat(_ALLOC_ID_, &prop, "name=", name, " dir=", dir, nums, NULL);
```

`name` is `""` when the caller passes one — `create_pin()` itself turns a NULL into one —
and the `argc > 5` form of `xschem add_symbol_pin` (`scheduler.c:1677`) passes `argv[4]`
straight through **with no guard**, unlike the other two callers (`paste.c:441`
`if(lab && lab[0])`, `scheduler.c:1725` `nm = "XXX"`). Measured pre-fix:

```
xschem add_symbol_pin 0 100 {} in   ->  name=<<dir=in>>   dir=<<>>
```

`dir` is **gone**. It drives netlist port direction, ERC, `set_pin_type` and paste's
dup-name coercion, so a nameless pin silently becomes a direction-less one. `dir` itself
needs no quoting: it is forced non-empty a few lines above.

### Site 2 — `place_symbol()`, the reported one

```c
src/actions.c   my_mstrcat(_ALLOC_ID_, &prop, "name=", xctx->inst[n].instname, "\n", NULL);
src/actions.c   my_mstrcat(_ALLOC_ID_, &prop, "flags=graph,unlocked\n", NULL);
```

`instname` is `""` when a `type=scope` symbol's `template=` carries no `name=`. Measured
pre-fix, on a floater rect at layer 2 (GRIDLAYER):

```
=== noname : name=<<flags=graph,unlocked>>  flags=<<>>  lock=<<1>>  color=<<8>>  node=<<>>
=== named  : name=<<g1>>  flags=<<graph,unlocked>>  lock=<<1>>  color=<<8>>  node=<<#net1>>
```

The floater loses `flags=graph`, so it is not treated as a graph.

**It does NOT need a hand-authored symbol.** The session prompt recorded as established
that all three shipped scope symbols carry `template="name=l1"`, so the reported site
"needs a hand-authored symbol". That is **wrong**: the template is not consulted when the
caller supplies `inst_props`. `xschem instance <sym> x y r f <props>` (argc == 8) hands
`argv[7]` straight to `place_symbol()` as `inst_props`, and `new_prop_string()` then derives
`instname` from *that* string — with no `name=` in it, `instname` is `""` whatever the
template says. Measured pre-fix on the **stock** symbol:

```
xschem instance devices/scope.sym 0 0 0 0 {lock=1}
   ->  rect2 name=<<flags=graph,unlocked>>   flags=<<>>   lock=<<1>>
```

Leg **EF5** is that case, and it is the strongest leg in the file: one scriptable command,
stock library, no fixture.

There is also a claimed second route in which `instname` is **NULL** rather than `""` (when
`inst_props == NULL` and `set_inst_prop()` skips `new_prop_string()` because the template
has no `name=`). NULL is `my_mstrcat`'s end-of-list sentinel, so the trailing `"\n"` would
be dropped too and the whole floater would collapse to one token. That route was **not
reproduced here**; it is noted because `my_mstrcat_tok()` handles it either way — it tests
`value && value[0]`, and appends `tail` in its own call rather than as a vararg after a
possibly-NULL value.

*Checked before choosing `name=""` over omitting the line:* the two readers of a floater's
`name` are `unselect_attached_floaters()` (`callback.c:5211`, tests
`get_tok_value(...)[0]`) and `select_attached_floaters()` (`select.c:1229`, which early-
returns on an empty `attach` and otherwise `strcmp`s). Both treat empty and absent
identically, so the choice is free; `key=""` keeps the property shape the same whether or
not the symbol has a name.

*Not fixed, and a separate consequence of the same empty `instname`:* the floater's
`node="tcleval([xschem translate  @#0:net_name])"` is already quoted, so it tokenises fine,
but the tcleval resolves to nothing (`node=<<>>` above). That is the empty instname being
useless, not the tokenizer eating anything.

### Site 3 — `get_additional_symbols()`, reachable-empty but symptom NOT constructed

```c
src/actions.c   my_mstrcat(_ALLOC_ID_, &symname_attr, "symname=", get_cell(sym, 0), NULL);
src/actions.c   my_mstrcat(_ALLOC_ID_, &symname_attr, " symref=", get_sym_name(i,9999,1,1), NULL);
```

`get_cell()` returns `""` whenever the basename is nothing but an extension:
`schematic=foo/` makes `sym` == `"foo/.sym"`, and `get_trailing_path()`
(`token.c:1434-1440`) NUL-terminates at the `.` and then returns the text after the `/`.
**Measured reachable** — such an instance logs `has_included_subcircuit: :` with an empty
cell name.

**What was NOT obtained is an end-to-end user-visible symptom.** The fixture that made
`get_cell` return `""` did not reach a path where `symname_attr` is consumed by
`translate3()` with a `spice_sym_def` that references `@symname`. So the swallowing is
inferred from measured tokenizer law, not reproduced. Legs **ET13/ET13b** pin the mechanism
at the level that *is* measurable — the exact string the site would build, and what
`get_tok_value` does to it — rather than claiming a reproduction that was never obtained.

### Site 4 — `add_pinlayer_boxes()`, the MOST reachable one, and initially MISSED

```c
src/save.c   label = get_tok_value(prop_ptr, "lab", 0);      /* "" when absent */
src/save.c   my_snprintf(pin_label, save, "name=%s dir=in ", label);
```

This synthesises a symbol `PINLAYER` rect for every `ipin`/`opin`/`iopin` instance when a
`.sch` is instantiated **directly as a symbol** (the LCC path, from `load_sym_def()`). An
unlabelled pin produced `"name= dir=in "`, so the generated symbol pin had **no `dir` at
all**. Measured with `xschem pinlist`:

```
parent.sch:  C {child.sch} 300 0 0 0 {name=X1}
child.sch:   ipin lab=GOOD  and  ipin lab=      (empty)

pre-fix   PINS_NAME = { {0} {GOOD} } { {1} {dir=in} }     PINS_DIR = { {0} {in} } { {1} {} }
post-fix  PINS_NAME = { {0} {GOOD} } { {1} {} }           PINS_DIR = { {0} {in} } { {1} {in} }
```

No scripted command, no hand-authored symbol — just a schematic with an unlabelled pin used
as a subcircuit. **This is the most reachable instance of the class and the first pass of
the fix missed it entirely**, because the sweep slice covering `save.c` died on an API error
and only ran on a re-run. Legs **EL1/EL2**.

`my_snprintf` is used here rather than `my_mstrcat`, so the fix is `if(!label[0]) label =
"\"\"";` ahead of the three branches; the existing `strlen(label)+30` slack covers the two
extra characters.

### Sites 5 and 6 — the twin `symname=` and the Tcl symbol generator

* `token.c` `has_included_subcircuit()` — the exact twin of site 3, same
  `"symname=", get_cell(...)` followed by `" symref="`. Fixing only one of the two copies
  would have been an inconsistency; both now use `my_mstrcat_tok()`.
* `xschem.tcl` — `puts $fd "B 5 … \{name=$lab dir=$dir\}"` in the clipboard-to-symbol
  generator. `$lab` is scraped with `regsub` and is `""` for a pin written `lab=`, giving
  the same `name=` eats `dir=` shape in generated symbol text.

*Separate latent bug noticed there:* `$lab` is only assigned inside
`if {[regexp {lab=} $i]}`, so a clipboard pin line with no `lab=` token at all leaves `$lab`
holding the **previous** pin's value. That is a stale-carry-over bug, not a tokenizer one —
filed and fixed as **0185**, which also found that an unlabelled *first* pin throws
`can't read "lab": no such variable` after the clipboard file has already been truncated.
It is what makes the empty `$lab` this issue quotes reachable at all.

### Site 7 — `create_symbol()` (`src/xschem.tcl`), a scripting entry point that writes a `.sym`

```tcl
foreach pin $in { ;# create all input pins on the left
  puts $fd "B 5 … {name=$pin dir=in}"
```

`create_symbol <file> {in…} {out…} {inout…}` is a documented user-facing proc — its own
comment carries the example `create_symbol test.sym {CLK RST D} {Q QB} {VCC VSS}` — with
**no in-repo callers**, so nothing else covers it. An empty element in any of the three
lists wrote `name= dir=in` straight into the `.sym` on disk. Measured pre-fix:

```
create_symbol s.sym {A {} B} {Q} {IO}
  ->  B 5 -152.5 17.5 -147.5 22.5 {name= dir=in}
  ->  reloaded: rect5[1] name=<<dir=in>>, dir ABSENT (found=0)
```

Fixed in all three loops. The pin is still emitted rather than skipped — the caller passed
a list element, and the pin count and geometry are part of the proc's contract. Legs
**EC1–EC5**.

### Sites 8 and 9 — `make_sym.awk` / `make_sym_lcc.awk`, i.e. "make symbol from schematic"

**The most reachable site of the whole class, and no sweep had ever looked at an awk
script.** `make_symbol` (`xschem.tcl:8455`) shells out to `src/make_sym.awk`; the LCC
variant to `src/make_sym_lcc.awk`. Both build the pin block by concatenating the literal
`name=`, then `label_pin[i]`, then the literal ` dir=in`:

```awk
src/make_sym.awk:282        " {name=" label_pin[i] vhdt vert " dir=in" >sym
src/make_sym_lcc.awk:334    (the same, plus a trailing space)
```

`label_pin` is the schematic pin's `lab=`, and `process_line()` sets `pin_label=""` when the
line has none — the everyday unlabelled-pin case. Measured on the shipped scripts, no
fixture beyond a three-pin schematic:

```
C {devices/ipin.sym} 0 -20 0 0 {name=p2}        (no lab=)

pre-fix   B 5 -202.5 -12.5 -197.5 -7.5 {name= dir=in}
post-fix  B 5 -202.5 -12.5 -197.5 -7.5 {name="" dir=in}
```

So: draw a schematic, leave one pin unlabelled, Symbol → Make Symbol, and the generated
`.sym` has a pin with no direction — written to disk and kept. Both scripts also emit
`generic_type=` from a possibly-empty `sig_type` in the `dir=="generic"` branch, followed by
` value=…` or the pin's own props; that is quoted too. Legs **EA1–EA5**, which are the only
coverage either script has.

*Noticed, not chased:* `make_sym_lcc.awk` emits the source pin's own props after the
generated ones, so the LCC output carries **two** `name=` tokens
(`{name=GOOD dir=in name=p1 }`). `get_tok_value()` takes the first, so it is not this bug,
but it is not obviously intended either.

## The class sweep — completed, but only on the second attempt

The sweep ran as five slices. On the first attempt **two died on API errors and swept
nothing**; they were re-run and completed.

| slice | scope | first attempt | re-run |
|---|---|---|---|
| actions | `src/actions.c` | swept | — |
| edit | `paste.c clip.c move.c select.c store.c editprop.c check.c` | swept | — |
| rest_c | `scheduler.c callback.c xinit.c draw.c` + the `*_netlist.c` backends, `psprint.c svgdraw.c options.c font.c util.c globals.c main.c` | swept | — |
| token_save | `token.c save.c netlist.c node_hash.c hilight.c findnet.c` | **DIED** | swept |
| tcl | `src/*.tcl`, `utils/*.tcl` | **DIED** | swept |

**The two dead slices held three of the six defects, including the worst one.** That is
worth remembering: a sweep that reports "no findings" because it never ran looks exactly
like a sweep that found nothing.

Of all five slices, the rule applied was:

* **fix it** when an empty value would SWALLOW a following token;
* **record it** when the empty value is the LAST thing in the string, because a trailing
  `key=` reads back as *absent* (case E/K) and steals nothing.

Recorded, deliberately unfixed — all verified by hand:

| site | key | why only MILD |
|---|---|---|
| `spice_netlist.c:669` | `symname` | value is the whole string; empty -> `@symname` unresolved, nothing swallowed |
| `spectre_netlist.c:555` | `symname` | identical shape to the above |
| `draw.c:297` | `image_data` | trailing; empty only if `base64_encode` failed |
| `actions.c` ×3 | `lab` | trailing in `place_sch_pin` / `place_wire_label` / the wire-label builder |
| `save.c:5487` | `lab` | trailing |
| `token.c:1263` | caller's `tok` | trailing |
| `xschem.tcl` ×4, `place_pins.tcl`, `place_sym_pins.tcl`, `utils/toggle_pins_netlabels.tcl` | `lab` / `name` | trailing, or the value could not be shown to be empty |

**`actions.c:1426` was filed as NOT a defect and that was only half right.** It is the
textbook shape and was the prompt's top suspect:
`"name=l0 lab=", netname ? netname : "", " text_size_0=", szbuf`. The
`if(!netname || !netname[0]) { …; continue; }` five lines above does stop the **empty**
case from ever reaching the concatenation — but not the **blank** case, and
`xschem add_pin_stubs -prefix { }` over a nameless pin measured
`lab=<<text_size_0=0.2>>` with `text_size_0` destroyed. See "The BLANK variant" below;
the guard now tests `str_is_blank()`. Leg **EN1** pins the guard, since that is what a
future refactor would remove.

`paste.c:105` and `editprop.c:1125` were raised by the sweep and **refuted** on
verification.

## The THIRD sweep — and what the first two structurally could not see

Re-run 2026-07-31 as six slices, deliberately **pattern-agnostic** (the first pass keyed on
`my_mstrcat` and missed a `my_snprintf` site) and covering the files no earlier slice had
ever named: `flyline.c`, `in_memory_undo.c`, `hash_iterator.c`, `icon.c`, `cairo_jpg.c`,
`rawtovcd.c`, the generated parsers — **and everything outside `src/*.c` and `src/*.tcl`**.

That last slice is where the yield was. The awk converters are shipped toolchain invoked
from Tcl, they write `.sym` and `.sch` files, and **no sweep had ever looked at one**. Three
producers came out of it (sites 7, 8, 9 above) and the two that matter are on the
"make symbol from schematic" path.

| slice | scope | result |
|---|---|---|
| actions-edit | `actions.c editprop.c store.c check.c move.c` | 3 raised, **all 3 wrong** — see below |
| save-token | `save.c token.c netlist.c node_hash.c hilight.c findnet.c` | clean |
| ui-c | `scheduler.c callback.c xinit.c draw.c paste.c clip.c select.c` | clean |
| never-swept-c | the 6 never-covered files + the backends + `util.c main.c …` | clean |
| tcl | `src/*.tcl utils/*.tcl` | `create_symbol` ×3 (**site 7**), `place_sym_pins.tcl:38` |
| outside-src | `src/*.awk`, `src/utile/`, `XSchemWin/`, `xschem_library/**` | **sites 8 and 9**, plus the converter family below |

### Site 10 — `gschemtoxschem.awk`, the gEDA/lepton import path

This one was nearly recorded-and-left, on the grounds that its empty values come from
third-party input I could not fabricate faithfully. That was wrong: the route reproduces in
four lines of gEDA text, and the harm is worse than a lost attribute.

The converter copies attributes **verbatim** out of the gEDA file. An input carrying

```
refdes=R5 / value= / device=RESISTOR / footprint=0805
```

converts to `{name=R5\nvalue=\ndevice=RESISTOR\nfootprint=0805\n}`, and measured through
xschem's own reader: `value` == `device=RESISTOR`, **`device` absent**. `resistor-1.sym`'s
spice format is `@value`, so that instance netlists as `R5 n1 n2 device=RESISTOR`.

The symbol path is worse still — one empty attribute per pin destroys two:

```
pinnumber= / pinseq=1 / pinlabel= / pintype=in

pre-fix   {pinnumber=  pinseq=1  name=  dir=in}  ->  pinseq GONE and dir GONE
post-fix  {pinnumber="" pinseq=1 name="" dir=in} ->  all four present
```

Four sites fixed, via a new `quote_empty_attr()` helper next to `escape_chars()`:
component attributes (`:301`), the symbol/global block (`:141`), the pin `attr_string`
loop (`:615`), and `template=` — the last inside `escape_chars()` itself, in that
function's doubled-backslash convention, mirroring how it already escapes a value
containing spaces. Verified that xschem reads the result: `template="device=\"\"
value=\"\" footprint=0805 "` gives `device` and `value` present-and-empty with
`footprint` intact. Legs **EG1–EG9**.

The helper tests `/^[^=]+=$/`, not `/=$/`, so a value that legitimately ends in `=`
(`foo=bar=`) is left alone.

*Regression check, since no gEDA corpus exists on this machine:* a hand-built input
exercising component attributes (including values with spaces, which take the
`escape_chars` quoting path), symbol attributes, and pins converts **byte-identically**
under the pre-fix and post-fix scripts. The output only changes where a value is actually
empty.

**Recorded, deliberately unfixed:**

| script | sites | why recorded |
|---|---|---|
| `src/make_sch_from_vhdl.awk` | `:919 :931 :940 :949` `print_sch()`, `:1031 :1049 :1063 :1077` `print_signals()` — `sig_type=` / `generic_type=` | needs a VHDL input where a signal or generic has no type; not constructed |
| `xschem_library/viewdraw_import/viewdraw_import.awk` | `:308` `name=` (`dir=` is trailing → mild) | same, for viewdraw input |
| `src/gschemtoxschem.awk:634` | slotted `pinnumber=` | genuinely **last** in the block, so it steals nothing. It is however committed proof that the converter emits bare `key=` into real output: `xschem_library/gschem_import/sym/lm324-1.sym:60`, `lm2902-1.sym:60` and `max4662-2.sym:66` each carry one |

The fix shape for the first two is the one used everywhere else — write `key=""` when the
value is empty, one line per site. They are left for a decision rather than edited blind:
unlike gschemtoxschem, I could not reproduce their empty case end to end, and a wrong edit
to a converter only surfaces when someone imports.

**`place_sym_pins.tcl:38`** (`xschem rect … "name=$name dir=$dir"`) is real in shape but its
`$name` comes from `foreach {name num} $pinlist` over a two-column pin-list file, where an
empty name needs a literal `{}` in the file. Recorded, not fixed.

## The BLANK variant — whitespace and `;` are empty too, and slipped past every guard

The first round of this fix tested emptiness as `value[0]` in C, `eq {}` in Tcl and `== ""`
in awk. **None of those catches a value made only of separator characters**, and
`get_tok_value()` treats such a value exactly like `""` — it skips every separator after
the `=` and takes the next token as the value. `SPACE()` (`token.c:24`) counts **`;`** as a
separator as well as space, tab and newline, so `key=;` is as destructive as `key=`.
Measured on all of them: space, tab, newline, `;`, and any mix.

Three routes measured live on the round-3 code, i.e. **after** the empty case was closed:

```
xschem add_symbol_pin 0 100 { } in      ->  name=<<dir=in>>   dir ABSENT
child.sch pin written  lab=" "          ->  LCC pin: name=<<dir=in>>, dir ABSENT
xschem add_pin_stubs -prefix { }        ->  lab=<<text_size_0=0.2>>, text_size_0 ABSENT
   (over a pin with no name= token, e.g. xschem_library/viewdraw_import/xschem_lib/nmos.sym)
```

Fix: `str_is_blank()` in **`token.c`**, deliberately next to `SPACE()` so the two cannot
drift apart, used by `my_mstrcat_tok()` (which covers all four of its call sites),
`save.c`'s LCC path, and `add_pin_stubs`'s own skip guard. The Tcl and awk producers use
the equivalent trim/regexp. Legs **EW0–EW4**.

`add_pin_stubs` is the one whose behaviour changes rather than whose output is quoted: its
guard already said "skip a pin that yields no net name rather than drop a blank `lab=`",
and a blank net name is now what that means.

### Correction: the two `actions.c` findings were RIGHT, and I dismissed them once

Recorded because the mistake was mine, not the sweep's. Both were flagged, both looked
wrong against the code, and both were real:

* `actions.c:1426` — I refuted it by reading `if(!netname || !netname[0]) { …; continue; }`
  five lines above and concluding the value cannot be empty. True of the **empty** case,
  false of the **blank** case: a `-prefix " "` walks straight through that test. The
  measurement above is the proof. The guard now uses `str_is_blank()`.
* `actions.c:1532` — I dismissed it as quoting pre-fix code, because an intermediate
  verdict argued only that "the value is NOT last". The final report quoted the *current*
  `my_mstrcat_tok(...)` line and located the defect in the **shared helper's `value[0]`
  test**, which is exactly right and holed all four call sites at once.
* `actions.c:1533` (`dir`) was correctly refuted: `if(!dir || !dir[0]) dir = "inout";` — and
  that one survives the blank variant too, since `dir` is compared against a fixed set.

The lesson is not "trust the agents" — one of them did quote code it had not read, in the
earlier round. It is that a partial verdict read mid-run is not the finding, and a
refutation is only as good as the case it actually tested. Leg EN1 still pins the guard;
it now pins the blank form of it.

### Pre-existing, NOT this bug, found while measuring the blank variant

`make_sym.awk`'s `process_line()` extracts the label with `sub(/[ }].*$/,"",pin_label)`,
which truncates at the first space — so a schematic pin written `lab=" x"` yields the single
character `"` and the generated symbol gets `{name=" dir=in "}`. Identical before and after
this fix, so it is a **quoted-value parsing** defect in the converter, not a member of this
class. `schpins_to_sympins`'s `regsub {[\} ].*}` has the same shape.

## The defect PERSISTS IN THE SAVED FILE — and the fix survives a round-trip

Every leg above reads the **in-memory** property string, which leaves the obvious question
unanswered: does `key=""` survive `save` + reload, or does the writer strip the quotes and
put a bare `key=` back on disk? Measured — it survives, and the written file text is

```
B 5 -2.5 97.5 2.5 102.5 {name="" dir=in show_pinname=true name_dx=25 ...}
B 2 20 -125 130 -25 {name=""\nflags=graph,unlocked\nlock=1\n...}
```

with `dir` / `flags` reading back present and correct after a reload of both the `.sym` and
the `.sch`. Legs **ER1–ER4**.

The same round-trip run against the **pre-fix** binary is the sharper result: `dir` is
**absent after reload too** (`{} 0`, not merely empty), and the reloaded `name` is
`dir=in`. So the pre-fix corruption was never a display artefact of the in-memory string —
it was **written to the file**, and any cell saved by an affected build carries it. That
matters for the LCC path in particular, where the damaged pin is regenerated on every load
rather than stored, but a `.sym` written by `create_pin` keeps it permanently.

## Verification

* `tests/headless/test_empty_value_swallows_token_0183.tcl` — 62 checks. **RED verified**
  against the pre-fix binary: **12 FAILED / 23 passed**; after the fix, 35/35.
  (Re-verified independently on 2026-07-31 by rebuilding a true pre-fix binary from
  `bf5bfde0` — the six changed files restored with `git show <sha>:src/<f> > src/<f>`,
  worktree only, per the trap below. The 8 pre-existing legs reproduced exactly; ER1–ER4
  are new and fail pre-fix, so they are not vacuous.)
* `tests/netlist_diff/netlist_diff.sh <pre-fix>` — **BYTE-IDENTICAL (920 netlists)**,
  945 runs per arm, 0 errors. Property strings feed every backend, so this is the leg that
  matters most for a producer-side change.
* Twelve suites green at their recorded counts. `test_pin_type_edit` (19),
  `test_add_pin_lib_symbol_view` (12) and `test_crossview_paste` (28) are the real
  `create_pin` coverage and all pass — note `run_suites.sh` scores them **NORESULT** on
  both arms and on BOTH binaries, because they end with `OVERALL: ok` rather than
  `RESULT: ALL PASS`; that is a pre-existing harness-reporting gap, not a failure.

## Not a `my_mstrcat` NULL truncation

It looks exactly like one — that is how it was found — but it is not. `instname` is `""`,
`my_mstrcat` skips empty arguments and keeps walking (`util.c:783`), and the string it
produces is correct C. `doc/claude/code_analysis/my_mstrcat_null_vararg_audit.md` swept
those 150 sites for **NULL** arguments and correctly cleared empty strings as harmless *to
`my_mstrcat`* — which is true of the function and misleading for a caller building a
property string. That audit did not clear this class; this sweep did.
