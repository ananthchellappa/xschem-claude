# Audit: the `my_strtok_r()` NULL-first-argument crash class

Done 2026-07-30, after issue 0179 turned up one instance of it. **Result: 0179 was
the only reachable one.** 48 call sites across 10 files, all classified, nothing
else survived review. No code change.

This file exists so the next person who finds a `my_strtok_r` crash does not
re-run the whole sweep, and — more usefully — so the *reason* the rest are safe is
written down, because most of them are safe **by accident of which allocator they
happen to use**, not by design.

## The bug

`my_strtok_r()` (`src/util.c:159`) assigns `*saveptr` only inside its first-call
branch:

```c
  if(str) {          /* 1st call */
    *saveptr = str;
  }
  while(**saveptr && strchr(delim, **saveptr) ) {    /* :168 */
```

A NULL first argument on the **first** call of a sequence therefore dereferences
an uninitialised `saveptr`. There is no guard and no diagnostic. In 0179 it was a
hard SIGSEGV.

Second arm of the same class: the first call succeeds but a **later** call runs
the cursor dry and returns NULL, which is then handed to `"%s"`. Measured in
0179: this tree's `%s` sites are not NULL-tolerant, so that crashes too.

## The single fact that decides almost every site

```c
my_strdup (util.c:193)   /* "empty source string --> dest=NULL" */
my_strdup2(util.c:718)   /* "duplicates also empty string"      */
```

`my_strdup` leaves the destination **NULL** when the source is absent **or
present-but-empty**. `my_strdup2` does not — it allocates `""`.

Nearly every tokenizer input in the tree is filled from
`get_tok_value(...)`, which **never returns NULL** (`token.c:461`, `:463` return
`""`). So the allocator choice alone decides it:

- `my_strdup2` + `get_tok_value` → always non-NULL, the loop just runs zero times.
- `my_strdup` + `get_tok_value` → **NULL whenever the attribute is absent or empty**.

That is exactly how 0179 fired: a symbol with `extra=` and no `extra_pinnumber=`.

## Why 0179 was unique

Every other first-call site is protected by one of three things:

| protection | sites |
|---|---|
| **`if(x)` guard before the loop** | `token.c:4024` (`if(v_extra)`), `verilog_netlist.c:531` (`if(extra)`), `:572` (`if(extra2)`), `draw.c:5507-5510` (explicit `if(!val \|\| !val[0]) return`), `select.c:1235` (`if(!name \|\| !name[0]) return`) |
| **`my_strdup2`, so the input is `""` not NULL** | all 14 `draw.c` sites, `token.c:1941-1942`, `actions.c:3584`, `node_hash.c:388`, `save.c:1855`, `scheduler.c:7127` |
| **coupled to a `mult` that goes `-1` on the same path** | `hilight.c:1001` and its siblings — `expandlabel()` returns NULL only for a NULL input and sets `*m = -1` on that path, so the enclosing `for(k = 1; k <= mult; ++k)` never enters the body |

**0179's site had a `if(extra)` guard — on the wrong cursor.** It is the tree's
only *lockstep pair*, walking `extra=` and `extra_pinnumber=` with one cursor
each, and only the first was guarded:

```c
   if(extra){                                            /* guards extra_ptr    */
     for(extra_ptr = extra, extra_pinnumber_ptr = extra_pinnumber; ; ...) {
       extra_pinnumber_token = my_strtok_r(extra_pinnumber_ptr, ...);   /* NOT guarded */
```

**So the rule to carry forward is: a lockstep pair needs a guard per cursor, not
per loop.** `token.c:1941-1942` is the other lockstep pair in the tree and it is
safe only because both sides use `my_strdup2`.

## Two claims checked by hand rather than taken on trust

- **`token.c:704` (`hash_names`) has no `mult` guard at all** — it is a bare
  `while((tok = my_strtok_r(upinst_ptr, ...)))` fed by `my_strdup` (the NULLing
  variant) from `expandlabel(instname, &xmult)`, and `xmult` is never used. If
  `expandlabel()` could return `""` for a non-empty input, this would be a live
  crash. **MEASURED — it cannot**: `xschem expandlabel` on a zero-multiplicity
  expression returns the *original string* with `m = -1`, not an empty one
  (`0*a` → `0*a`, `-1`; `0*a,0*b` → `,`, `0`), because the grammar's
  `my_strdup` at `expandlabel.y:311` NULLs `dest_string.str` and
  `parselabel.l`'s else-branch then `my_strdup2`s the input back. A non-empty
  input always yields a non-empty output. SAFE — but it is the thinnest margin
  in the tree, and it is thin for a reason nobody wrote down until now.
- **`hilight.c:1008`** uses `my_strdup` too, and *is* the 0179 shape. It survives
  only on the `mult == -1` coupling above. If anyone ever changes
  `expandlabel()`'s NULL path to leave `*m` alone, this becomes a crash.

## A latent fragility in `list_nets()` — mechanism real, reachability NOT shown

**Corrected 2026-07-30 after measuring.** The first version of this file called
this "one real defect found". That was an agent's claim published before I had
run it. On measurement the mechanism is real but I could not reach it, so it is
recorded here as fragility, not as a defect, and no issue was filed.

`list_nets()`, `src/node_hash.c:388-393`:

```c
my_strdup2(_ALLOC_ID_, &pin_node, expandlabel(xctx->inst[i].lab, &mult));
p_n_s1 = pin_node;
for(k = 1; k <= mult; ++k) {
  lab = my_strtok_r(p_n_s1, ",", "", 0, &p_n_s2);
  p_n_s1 = NULL;
  my_mstrcat(_ALLOC_ID_, result, "{", lab, " ", type, "}\n", NULL);   /* lab may be NULL */
}
```

**Both halves of the mechanism are confirmed by measurement:**

- `xschem expandlabel {}` returns `""` **with `mult == 1`** — measured. So an
  empty `lab` gives one loop iteration over a string with zero tokens, and
  `my_strtok_r` returns NULL (`util.c:189`).
- `my_mstrcat` (`util.c:768`) walks its varargs with `do { … } while(append_str)`,
  so a NULL argument is taken as the **list terminator**. Only `{` would be
  appended; the closing ` <type>}` would be lost. No crash (the `append_str[0]`
  deref is never reached), but `result` goes straight to Tcl
  (`scheduler.c:6339`), so the caller would get an unbalanced brace and any
  `foreach`/`lindex` over it would die with *unmatched open brace in list*.

**What I could not do is get `inst[i].lab` to be `""` at that point.** Five
constructions, all balanced:

| construction | result |
|---|---|
| `ipin` with `lab=` (empty) | `{lab=net1 ipin}` — back-filled |
| `ipin` with no `lab=` at all | `{net1 ipin}` — back-filled |
| dangling `ipin`, empty lab, nothing attached | `{lab=net1 ipin}` — back-filled |
| `type=ipin` symbol with **zero** `PINLAYER` rects | no pin entry emitted at all |
| same, plus a `GENERICLAYER` rect | no pin entry emitted at all |

The last two are the hand-crafted shape the earlier version of this file named as
the way in. They do not work: with no pin rect, `xctx->inst[i].node` is NULL and
the guard at `node_hash.c:387` (`type && xctx->inst[i].node && IS_PIN(type)`)
rejects the instance before the loop. So the two sides close on each other — an
instance that HAS a node gets its `lab` back-filled by
`prepare_netlist_structs()` (called unconditionally at `node_hash.c:383`), and an
instance that does NOT have a node never enters the loop.

**Status: not a filed issue.** "I could not reproduce it in five tries" is not
the same as "unreachable", so the note stays: if anyone ever loosens the
`inst[i].node` guard, or adds a path that reaches `list_nets` without
`prepare_netlist_structs()`, this becomes live. A one-line `if(!lab) continue;`
before `node_hash.c:393` would close it permanently and cost nothing.

## If you are adding a `my_strtok_r` loop

1. Use `my_strdup2`, or guard the pointer with `if(x)`. Do not rely on the reader
   noticing which allocator you picked.
2. If you are walking **two** lists in lockstep, guard **both** cursors, and
   decide what a short list means before you write it. 0179's answer was the
   `"--UNDEF--"` placeholder the pin loop next door already used.
3. The returned token can be NULL mid-loop even when the first call succeeded.
   Do not pass it to `"%s"` without a test.
