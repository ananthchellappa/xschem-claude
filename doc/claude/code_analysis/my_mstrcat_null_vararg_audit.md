# Audit: the `my_mstrcat()` NULL-vararg truncation class

Done 2026-07-31, after issue 0180 turned up one instance of it. **Result: 0180 was the
only one.** 150 call sites across 12 files, all classified, nothing else survived review.
No code change.

Sibling of `my_strtok_r_null_argument_audit.md`, which spawned 0180 and came back equally
empty. Both files exist so the next person does not re-run the sweep, and — more usefully
— so the *reason* the rest are safe is written down.

## The bug

`my_mstrcat()` (`src/util.c:768`) walks its varargs with

```c
  do {
    ...append append_str...
    append_str = va_arg(args, const char *);
  } while(append_str);
```

so **NULL is the end-of-list sentinel, not empty data**. A NULL argument that is not the
final terminator silently drops every argument after it. There is no crash and no
diagnostic; the damage surfaces in the *consumer* of the truncated string, far from here.
In 0180 it was an unbalanced `{` handed to Tcl.

This cannot be fixed inside `my_mstrcat()`: 143 of the 150 sites end in a literal `NULL)`,
so the API has no way to tell "NULL datum" from "end of arguments". **The caller must
never pass one.** Two sites already use the guard idiom and are the reference for what
right looks like:

```c
src/actions.c:1426:  my_mstrcat(_ALLOC_ID_, &prop, "name=l0 lab=", netname ? netname : "", " text_size_0=", szbuf, NULL);
src/actions.c:1726:  my_mstrcat(_ALLOC_ID_, res, "{", type, " ", idxbuf, " {", name ? name : "", "}}", NULL);
```

## Why an EMPTY string is not the same hazard

Worth stating, because it is the single fact that clears most of the 150:

```c
    if(append_str[0]) { ...append... }        /* util.c:783, :791 */
    append_str = va_arg(args, const char *);  /* walk continues regardless */
```

`my_mstrcat` **skips** an empty argument and keeps walking. Only NULL stops it. So a site
fed by `my_strdup2` or `get_tok_value` is safe *by construction*, and the distinction that
decides nearly every call site is the same one that decided the `my_strtok_r` audit:

```c
my_strdup (util.c:193)   /* "empty source string --> dest=NULL"  -- the NULLING variant */
my_strdup2(util.c:718)   /* "duplicates also empty string"       -- never NULL          */
get_tok_value(token.c)   /* returns "" for a missing token, NEVER NULL (token.c:461,463) */
```

## The classification

| class | sites | why safe |
|---|---:|---|
| every argument is a **string literal** | ~60 | cannot be NULL |
| argument is `get_tok_value(...)` / `tclgetvar` / `tclresult` / `my_itoa` / `dtoa` | ~35 | none of these ever returns NULL |
| argument came from `my_strdup2` | ~20 | allocates `""` rather than NULLing |
| argument is a **dominated pointer** — the enclosing `if(x)`, an early `return`, or a `while(x)` proves it non-NULL | ~25 | e.g. `token.c:1016` (`token+1` inside `if(token)`), `hilight.c:2758` (`path2` from `my_strdup2(path)` where `path = xctx->sch_path[level]+1`, never NULL) |
| argument already carries the `x ? x : ""` guard | 2 | `actions.c:1426`, `actions.c:1726` |
| **the defect** | 1 | `node_hash.c:393` — fixed, issue 0180 |
| flagged, then refuted | 6 | see below |

150 total. `util.c:768/786/794` are the definition and its own `dbg` lines, not call sites.

## The six that were flagged and did not survive

Five were refuted by reading; the sixth by **running it**, which is the part worth
recording.

- `actions.c:2632`, `:2657`, `:2662` — `xctx->inst[n].instname` in `place_symbol()`. The
  claim was that `:2583` sets it NULL and the `inst_props == NULL` route
  (`set_inst_prop()` → `new_prop_string()` gated on
  `if(get_tok_value(ptr,"name",0)[0])`, `editprop.c:224`) can leave it so. It cannot:
  **`set_inst_flags()` at `actions.c:2608` runs unconditionally in between**, and its
  first act (`actions.c:976`) is
  `my_strdup2(&inst->instname, get_tok_value(inst->prop_ptr, "name", 0))`. `get_tok_value`
  never returns NULL and `my_strdup2` allocates `""` for an empty source, so `instname`
  is `""` — not NULL — from `:2608` onward. **Measured**: with `-d 1`, a `type=scope`
  symbol whose template carries no `name=` prints `set_inst_flags(): instname=` (empty),
  not `(null)`.
- `hilight.c:2758` — `path2`. Filled by `my_strdup2(&path2, path)` where
  `path = xctx->sch_path[level] + 1` (`hilight.c:2646`), pointer arithmetic on an
  always-allocated hierarchy string. Never NULL.
- `spice_netlist.c:669`, `spectre_netlist.c:555` — `get_cell(name, 0)`, which is
  `get_trailing_path()` (`token.c:1444`) and returns a pointer into its argument or a
  static buffer, never NULL.

## `actions.c:2626` — the one that had to be measured, and what it actually found

This was the single site that survived the adversarial verify pass, on the same
`instname`-is-NULL reasoning as `:2632`. It was **refuted the same way** — but only after
a probe was built, and the probe found something else.

Fixture: a `type=scope` symbol whose `template=` carries **no** `name=` token, placed via
`xschem place_symbol <sym>` (which passes `inst_props == NULL`). Read the graph floater
back — it is stored as a rect on layer 2 (`actions.c:2668`):

```
=== noname : instances=1 rects[2]=1
  rect2[0] name=<<flags=graph,unlocked>>       <-- name swallowed the next line
  rect2[0] flags=<<>>                          <-- flags is GONE
=== named  : instances=1 rects[2]=1            (control: template has name=g1)
  rect2[0] name=<<g1>>
  rect2[0] flags=<<graph,unlocked>>
```

That looks exactly like a `my_mstrcat` truncation and it is not one. With `instname == ""`
the call at `:2626` correctly produces `"name=\n"`, and `:2627` correctly appends
`"flags=graph,unlocked\n"`. The malformation is downstream: **the property tokenizer
reads an empty value followed by a newline as "value continues on the next line"**, so
`flags=graph,unlocked` is consumed as the value of `name`. Confirmed on a pure string,
no design involved:

```
$ xschem list_tokens "name=\nflags=graph,unlocked\nlock=1\ncolor=8\n" 0
name  lock color                               <-- `flags` is not a token at all
```

So the graph floater a hand-authored scope symbol produces is not marked as a graph.
Real, narrow, and **not** in this class — filed separately as issue 0183.

**The lesson is the same one issue 0180 exists to teach**: an adversarial verifier that
reads carefully still produced a confident wrong verdict here, in both directions — it
called `:2632` safe and `:2626` unsafe on identical evidence. The probe settled it, and
paid for itself by turning up an unrelated defect the reading would never have found.

## If you are adding a `my_mstrcat()` call

1. Any argument that is not a string literal, a `get_tok_value()` result, or something
   filled by `my_strdup2` needs `x ? x : ""`. `my_strdup` is the trap: it NULLs its
   destination for an **empty** source, not just an absent one.
2. Empty is fine, NULL is not. `my_mstrcat` skips `""` and keeps going.
3. If you are building a **structured** string — a braced Tcl row, a `key=value` property,
   a path — say so in a comment, because that is what turns a silent truncation into a
   consumer-side failure someone will debug from the wrong end.
