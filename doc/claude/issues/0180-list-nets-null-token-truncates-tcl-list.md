# 0180 — a NULL token in `list_nets()` silently truncates the Tcl list `xschem list_nets` returns

Status: **OPEN** — latent. Mechanism measured; **reachability NOT demonstrated** (see below).
Area: `src/node_hash.c` `list_nets()`, and the `my_mstrcat()` vararg contract generally
Tests: none yet. `tests/stable_handles/net_body.tcl` NC1a/NC1b are the existing consumers.
Found: 2026-07-30, by the `my_strtok_r` NULL-argument audit that issue 0179 implied
Related: 0179 (the audit that turned it up),
`doc/claude/code_analysis/my_strtok_r_null_argument_audit.md`

> **Read the status line literally.** This issue is filed on a *measured mechanism* with an
> *unproven trigger*. Five constructions failed to reach it. It is filed anyway because the
> mechanism is real, the fix is one line, and the general lesson about `my_mstrcat()` applies to
> 149 call sites. Do not write a triumphant "FIXED" without reading "How to prove a fix" below —
> the usual RED-first discipline cannot apply unmodified here.

## The mechanism, both halves measured

`list_nets()`, `src/node_hash.c:386-397`:

```c
    my_strdup(_ALLOC_ID_, &type,(xctx->inst[i].ptr+ xctx->sym)->type);
    if(type && xctx->inst[i].node && IS_PIN(type)) {                       /* :387 */
      my_strdup2(_ALLOC_ID_, &pin_node, expandlabel(xctx->inst[i].lab, &mult));   /* :388 */
      p_n_s1 = pin_node;
      for(k = 1; k <= mult; ++k) {                                         /* :390 */
        lab = my_strtok_r(p_n_s1, ",", "", 0, &p_n_s2);                    /* :391 -- may be NULL */
        p_n_s1 = NULL;
        my_mstrcat(_ALLOC_ID_, result, "{", lab, " ", type, "}\n", NULL);  /* :393 */
      }
    }
```

1. **An empty `lab` yields one iteration and zero tokens.** MEASURED:
   `xschem expandlabel {}` returns `""` **with `mult == 1`** — the `!strpbrk(s, "*,.:")`
   shortcut at `parselabel.l:105-113` sets `*m = 1` and `my_strdup2`s the empty string. So the
   `for(k = 1; k <= mult; ++k)` loop runs once, and `my_strtok_r("")` returns NULL
   (`util.c:189`, `if(tok[0]) return tok; else return NULL`).

2. **`my_mstrcat()` treats a NULL argument as END OF LIST, not as empty data.**
   `src/util.c:768-800`:

   ```c
   do {
     ...append append_str...
     append_str = va_arg(args, const char *);
   } while(append_str);
   ```

   So a NULL `lab` at `:393` appends only `"{"` and then stops — the ` <type>}\n` is lost. There
   is **no crash** (the `append_str[0]` deref is never reached), but `result` goes straight to Tcl
   at `src/scheduler.c:6338-6339`, so the caller receives a string with an unbalanced `{` and any
   `foreach` / `lindex` / `llength` over it dies with *unmatched open brace in list*.

## Reachability — NOT demonstrated, and here is exactly what was tried

Five constructions, every one balanced:

| construction | `xschem list_nets` returned |
|---|---|
| `ipin` with `lab=` (empty) | `{lab=net1 ipin}` — back-filled |
| `ipin` with no `lab=` at all | `{net1 ipin}` — back-filled |
| dangling `ipin`, empty lab, nothing attached to its pin | `{lab=net1 ipin}` — back-filled |
| `type=ipin` symbol with **zero** `PINLAYER` rects | no pin row emitted at all |
| same, plus a `GENERICLAYER` rect | no pin row emitted at all |

The last two were the hand-crafted shape originally proposed as the way in. They do not work: with
no pin rect, `xctx->inst[i].node` is NULL and the `:387` guard rejects the instance before the loop.

**The two guards close on each other.** An instance that HAS a node gets its `lab` back-filled by
`prepare_netlist_structs()` — called unconditionally at `node_hash.c:383`, reaching
`set_lab_or_pin_inst_attr()` (`netlist.c:944-983`) via `name_unlabeled_instances()`. An instance
that does NOT have a node never enters the loop. Whether that closure is *total* or merely
*untested* is the open question, and it is the first thing to settle.

## Why the fix has to be at the call site

The obvious alternative — "make `my_mstrcat()` skip NULLs instead of stopping" — is **impossible**.
NULL *is* the sentinel: 143 of the 149 call sites end in a literal `NULL)`. The API has no way to
distinguish "NULL datum" from "end of arguments", so the caller must never pass one.

The codebase already knows this. Two sites use the guard idiom, and one of them is the same shape
as the broken line — building a braced Tcl list row:

```c
src/actions.c:1726:
  my_mstrcat(_ALLOC_ID_, res, "{", type, " ", idxbuf, " {", name ? name : "", "}}", NULL);
src/actions.c:1426:
  my_mstrcat(_ALLOC_ID_, &prop, "name=l0 lab=", netname ? netname : "", " text_size_0=", szbuf, NULL);
```

So `node_hash.c:393` is not a novel hazard; it is an **inconsistency** with an idiom already in use
ten lines away in another file.

## Proposed fix

```c
        lab = my_strtok_r(p_n_s1, ",", "", 0, &p_n_s2);
        p_n_s1 = NULL;
        if(!lab) continue;        /* or: lab ? lab : "" in the my_mstrcat call */
        my_mstrcat(_ALLOC_ID_, result, "{", lab, " ", type, "}\n", NULL);
```

`continue` vs `lab ? lab : ""` is a real choice, not a style preference: `continue` **drops the
row**, the ternary **emits `{ <type>}`** — a row with an empty name. Decide which the consumer
wants (`tests/stable_handles/net_body.tcl` NC1a treats the output as `{name type}` tuples), and say
why in the diff.

## Wider question this opens, deliberately left unanswered here

`my_mstrcat()` has 149 call sites. Most pass string literals or `get_tok_value()` results, which
are never NULL. **How many pass something that can be?** That is a bounded, mechanical sweep of
exactly the same character as the one 0179 spawned — and that one came back empty, so do not assume
this one will not.
