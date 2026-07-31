# 0183 — an empty `name=` value swallows the next property line

Status: **OPEN** — measured, **not fixed** (the fix is a choice, see below).
Area: `src/actions.c` `place_symbol()` scope-floater block; the property tokenizer
Tests: none yet
Found: 2026-07-31, by the `my_mstrcat` NULL-vararg audit that issue 0180 spawned
Related: `doc/claude/code_analysis/my_mstrcat_null_vararg_audit.md`, 0180

## What happens

`place_symbol()` embeds a locked graph floater inside a `type=scope` symbol by building a
property string a line at a time:

```c
src/actions.c:2626  my_mstrcat(_ALLOC_ID_, &prop, "name=", xctx->inst[n].instname, "\n", NULL);
src/actions.c:2627  my_mstrcat(_ALLOC_ID_, &prop, "flags=graph,unlocked\n", NULL);
src/actions.c:2628  my_mstrcat(_ALLOC_ID_, &prop, "lock=1\n", NULL);
src/actions.c:2629  my_mstrcat(_ALLOC_ID_, &prop, "color=8\n", NULL);
```

If the symbol's `template=` carries no `name=` token, `instname` is `""` (not NULL —
`set_inst_flags()` at `actions.c:976` fills it via `my_strdup2` + `get_tok_value`, both
of which produce `""` rather than NULL). So `prop` legitimately begins:

```
name=
flags=graph,unlocked
lock=1
color=8
```

and the property tokenizer then reads the **empty value as continuing onto the next
line**, consuming `flags=graph,unlocked` as the value of `name`.

## Measured

Fixture: `type=scope`, one `PINLAYER` rect, `template="value=1"` — deliberately no
`name=`. Placed with `xschem place_symbol <sym>` (the `inst_props == NULL` route). The
floater is a rect on layer 2 (`actions.c:2668`):

```
=== noname : instances=1 rects[2]=1
  rect2[0] name=<<flags=graph,unlocked>>
  rect2[0] flags=<<>>
  rect2[0] lock=<<1>>
  rect2[0] color=<<8>>
  rect2[0] node=<<>>
=== named  : instances=1 rects[2]=1        (control: template="name=g1 value=1")
  rect2[0] name=<<g1>>
  rect2[0] flags=<<graph,unlocked>>
  rect2[0] lock=<<1>>
  rect2[0] color=<<8>>
  rect2[0] node=<<#net1>>
```

The floater loses `flags=graph`, so it is not treated as a graph.

Reproducible with no design at all, on a pure string:

```
$ xschem list_tokens "name=\nflags=graph,unlocked\nlock=1\ncolor=8\n" 0
name  lock color
```

`flags` is not a token in that string.

## DECIDED 2026-07-31 — fix the producer; the tokenizer is not broken

The two candidate fixes were:

1. **At the producer** — `actions.c:2626` should not emit a `name=` token with an empty
   value (skip it, or emit `name=""`).
2. **At the tokenizer** — an empty value terminated by whitespace should be read as empty,
   not as "the value is the next token".

**(2) is off the table, on evidence.** The whitespace-skip is deliberate and load-bearing
in a shipped library file — `xschem_library/ngspice_verilog_cosim/tb_sar_adc.sch:176`
(and `sar_adc.sch:78`) contain

```
C {dac_bridge.sym} 330 -160 0 0 {name=A2 dac_bridge_model= dac_buff
```

where the author wrote a space after `=` and means the value `dac_buff`. Measured:
`xschem get_tok "…dac_bridge_model= dac_buff…" dac_bridge_model` → `dac_buff`. So
`key= value` is part of the grammar in practice, and changing it would break that file
and any user schematic written the same way.

**The grammar has a way to say "empty": `key=""`.** Measured — it reads back as present
with an empty value, and the token after it parses normally. That is what a producer
should emit.

## Characterised — 11 measured cases

`xschem get_tok <str> <tok>` is a pure wrapper over `get_tok_value()`; `xschem
get_tok_size` returns 0 when the token was not found at all.

| property string | result |
|---|---|
| `name=\nflags=graph,unlocked\nlock=1\n` | `name` = `flags=graph,unlocked`, `flags` **not found** |
| `name= flags=graph,unlocked lock=1` | identical — **a space behaves like a newline** |
| `name=\tflags=graph,unlocked` | identical — **a tab too** |
| `name=""\nflags=graph,unlocked\n` | `name` = `` (found), `flags` = `graph,unlocked` |
| `flags=…\nname=\n` | `name` = ``, **found = 0** |
| `a=1\nname=\nflags=graph\nb=2\n` | `name` = `flags=graph`; `a` and `b` unharmed |
| `lab=\nvalue=1k\n` | `lab` = `value=1k` — **not specific to `name`** |
| `name=\nlab=\nvalue=1k\n` | `name` = `lab=`; `value` still `1k` — **exactly one token eaten** |
| `name=\n\nflags=graph\n` | a blank line does not stop it |
| `name=` | `name` = ``, **found = 0** |
| `name=g1\nflags=…\n` | control — both correct |

So: general to every attribute, triggered by any whitespace, consumes exactly one
following token, and avoidable by quoting. A trailing `key=` at end-of-string reports
**found = 0** — an empty value at the end is indistinguishable from an absent attribute,
which is a separate quirk worth knowing if you test `xctx->tok_size`.

## The class this belongs to

The reported site is narrow — all three shipped scope symbols
(`xschem_library/devices/scope.sym:24`, `scope2.sym:24`, `scope_ammeter.sym:24`) carry
`template="name=l1"`, so it needs a hand-authored symbol. **The class may not be narrow.**
Any `my_mstrcat` that builds `"key="` + a possibly-empty value + more tokens has it.
`actions.c:1426` is the first to check: its `netname ? netname : ""` NULL guard produces
exactly this empty value, followed by ` text_size_0=`, in wire-label creation.

`doc/claude/code_analysis/my_mstrcat_null_vararg_audit.md` swept those 150 sites for
**NULL** arguments and cleared empty strings as harmless. That is true of `my_mstrcat` and
misleading for its callers; the audit carries a correction pointing here, and the sweep for
this class has **not** been run. Candidate list is in
`doc/claude/suggestions/next_session_prompt_0183.md`.

## Not a `my_mstrcat` NULL truncation

It looks exactly like one — this is how it was found — but it is not. `instname` is `""`,
`my_mstrcat` skips empty arguments and keeps walking its varargs (`util.c:783`), and the
string it produces is correct. See the audit file for the full working.
