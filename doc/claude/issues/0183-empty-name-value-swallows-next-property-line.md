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

## Why it is filed rather than patched

There are two defensible fixes and they are not equivalent:

1. **At the producer** — `actions.c:2626` should not emit a `name=` token with an empty
   value at all (skip the token, or emit `name=""`). Narrow, safe, and leaves the
   tokenizer alone.
2. **At the tokenizer** — an empty value terminated by a newline should be read as empty,
   not as "continues on the next line".

(2) is the real bug but it is a change to the **property grammar**, which every `.sch`
and `.sym` in existence is written against, and a schematic somewhere may rely on
`attr=` + newline meaning what it means today. That is not a call to make from one
narrow repro.

Narrow in practice either way: all three shipped scope symbols
(`xschem_library/devices/scope.sym:24`, `scope2.sym:24`, `scope_ammeter.sym:24`) carry
`template="name=l1"`, so this needs a user- or generator-authored `type=scope` symbol
whose template omits `name=`.

## Not a `my_mstrcat` NULL truncation

It looks exactly like one — this is how it was found — but it is not. `instname` is `""`,
`my_mstrcat` skips empty arguments and keeps walking its varargs (`util.c:783`), and the
string it produces is correct. See the audit file for the full working.
