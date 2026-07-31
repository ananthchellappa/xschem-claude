# 0183 — an empty attribute value swallows the next property token

Status: **FIXED** 2026-07-31 — **six** producers repaired. The class sweep completed on the
second attempt (two of five slices died on API errors the first time), and the three sites
it turned up on the re-run include the most reachable instance of the whole class.
Area: `src/util.c` (`my_mstrcat_tok()`), `src/actions.c` (`create_pin()`,
`place_symbol()`, `get_additional_symbols()`)
Tests: `tests/headless/test_empty_value_swallows_token_0183.tcl` — **28 checks**
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

It lives in `util.c` rather than `actions.c` because the class is not file-local — but note
that all three repaired sites happen to be in `actions.c`.

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

*Separate latent bug noticed there and NOT fixed:* `$lab` is only assigned inside
`if {[regexp {lab=} $i]}`, so a clipboard pin line with no `lab=` token at all leaves `$lab`
holding the **previous** pin's value. That is a stale-carry-over bug, not a tokenizer one.

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

**`actions.c:1426` is NOT a defect**, though it is the textbook shape and was the prompt's
top suspect: `"name=l0 lab=", netname ? netname : "", " text_size_0=", szbuf`. The
`if(!netname || !netname[0]) { …; continue; }` five lines above means the empty case never
reaches the concatenation. The `? :` there guards NULL, not empty. Leg **EN1** pins the
guard, since that is what a future refactor would remove.

`paste.c:105` and `editprop.c:1125` were raised by the sweep and **refuted** on
verification.

## Verification

* `tests/headless/test_empty_value_swallows_token_0183.tcl` — 31 checks. **RED verified**
  against the pre-fix binary: **8 FAILED / 23 passed**; after the fix, 31/31.
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
