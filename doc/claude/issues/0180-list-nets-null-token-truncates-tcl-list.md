# 0180 — a NULL token in `list_nets()` silently truncates the Tcl list `xschem list_nets` returns

Status: **FIXED** — reachability **DEMONSTRATED** 2026-07-31, RED-first, regression test.
Area: `src/node_hash.c` `list_nets()`, and the `my_mstrcat()` vararg contract generally
Tests: `tests/headless/test_list_nets_null_token_0180.tcl` (9 checks).
Direct consumer `tests/stable_handles/net_body.tcl` NC1a/NC1b still green.
Found: 2026-07-30, by the `my_strtok_r` NULL-argument audit that issue 0179 implied
Related: **0181** (the segfault that hid this one — it must be fixed for this to be
observable at all), 0182 (the label battery run to settle this issue's reachability),
0179, `doc/claude/code_analysis/my_strtok_r_null_argument_audit.md`

> **Status corrected.** This issue was filed as *"mechanism measured, reachability NOT
> demonstrated"* after five constructions came back balanced. That was accurate at the
> time and wrong as a conclusion: the trigger exists, and the five constructions missed
> it because a **different bug crashed the process first**. See "Why it looked
> unreachable".

## The mechanism, both halves measured

`list_nets()`, `src/node_hash.c:386-397` (pre-fix):

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

1. **An empty `lab` yields one iteration and zero tokens.** `xschem expandlabel {}`
   returns `""` **with `mult == 1`** — the `!strpbrk(s, "*,.:")` shortcut at
   `parselabel.l:105-113` sets `*m = 1` and `my_strdup2`s the empty string. So the
   `for(k = 1; k <= mult; ++k)` loop runs once, and `my_strtok_r("")` returns NULL
   (`util.c:189`, `if(tok[0]) return tok; else return NULL`).

2. **`my_mstrcat()` treats a NULL argument as END OF LIST, not as empty data**
   (`src/util.c:768-800`, `do { … } while(append_str)`). So a NULL `lab` at `:393`
   appends only `"{"` and stops. No crash — the `append_str[0]` deref is never reached —
   but `result` goes straight to Tcl at `src/scheduler.c:6338-6339`, so the caller gets
   an unbalanced `{`.

## The trigger — measured

A **pin-type symbol (`ipin`/`opin`/`iopin`) with ZERO `PINLAYER` rects and at least one
`GENERICLAYER` rect**, instantiated with an empty or absent `lab`.

Two passes disagree about what `inst[i].node` means:

```c
netlist.c:1636  rects = rects[PINLAYER] + rects[GENERICLAYER];   /* ALLOCATION */
netlist.c:1640  if(rects > 0) inst[i].node = my_malloc(...);
netlist.c:1611  rects = rects[PINLAYER];                         /* BACK-FILL walk */
```

So this symbol **has** a node array — the `xctx->inst[i].node` conjunct at
`node_hash.c:387` tests the array pointer, not `node[0]` — while
`name_unlabeled_instances()` never visits it, because that pass walks only PINLAYER
rects. `netlist.c:1484` (`my_strdup(&inst[i].node[0], inst[i].lab)`) leaves `node[0]`
NULL for an empty lab, and `set_lab_or_pin_inst_attr()` returns early on `!node[0]`
(`netlist.c:955`). The lab therefore survives empty all the way to `expandlabel()`.

Measured, on a binary with 0181 fixed and this issue's fix reverted:

```
R_gen_ipin_emptylab          >>>> UNBALANCED  open=1 close=0 llength_rc=1
                               raw=|{|
```

`xschem list_nets` returns the single character `{`. `llength` on it fails.
Identical for `opin`, `iopin`, for an instance with no `lab` token at all, and with two
generic rects.

## Why it looked unreachable

Three of the five earlier constructions (an ordinary `ipin`, with `lab=`, without `lab`,
dangling) really are back-filled and really are balanced — that half of the original
table stands. The fourth, a pin symbol with **zero** rects of any kind, is correctly
rejected: `inst[i].node` is genuinely NULL there.

The fifth — *"same, plus a `GENERICLAYER` rect"* — is this issue's trigger, and it was
recorded as *"no pin entry emitted at all"*. On the shipping binary that construction
does not emit nothing; it **SIGSEGVs**, inside `name_nodes_of_pins_labels_and_propagate()`
at `netlist.c:1463-1465`, which derefs `rect[PINLAYER][0]` unconditionally for any
non-label pin. The crash lands inside the `prepare_netlist_structs(1)` call at the head
of `list_nets()`, before the loop under test is entered. A harness that runs the child
through `exec` and reads only the returned net list sees an empty string either way,
which is how a hard crash came to be written down as an empty result. (Whether the
original construction actually placed its rect on layer 3 was not recoverable; either
way the conclusion drawn from it — that the two guards close on each other — does not
hold.)

**0180 was latent behind 0181.** Guard the deref and 0180 fires on the first run.

## Two angles closed by measurement, so nobody re-runs them

- **`IS_PIN` is the strict SUBSET, not a superset.** `xschem.h:497-501`: `IS_PIN` =
  {ipin,opin,iopin}; the back-fill gate at `netlist.c:959` uses `IS_LABEL_OR_PIN` =
  {label,ipin,opin,iopin}. Every type `list_nets` accepts is also back-filled. There is
  no type accepted by one gate and not the other.
- **`skip_instance` cannot diverge.** `list_nets` (`node_hash.c:385`) and
  `name_unlabeled_instances` (`netlist.c:1609`) call it with byte-identical arguments,
  `(i, 0, netlist_lvs_ignore)`.
- **There is no "multiplicity exceeds token count" label.** 38 label expressions were run
  through `xschem expandlabel` and compared against a token count computed the way
  `my_strtok_r` counts. The empty string is the **only** case where `mult` exceeds the
  token count. (`my_strtok_r` skips empty tokens rather than returning NULL for them, so
  an interior `,,` does not truncate either.) That battery did turn up eight hard
  crashes in `expandlabel` itself — filed separately as **0182**.

## The fix

```c
        lab = my_strtok_r(p_n_s1, ",", "", 0, &p_n_s2);
        p_n_s1 = NULL;
        if(!lab) continue;
        my_mstrcat(_ALLOC_ID_, result, "{", lab, " ", type, "}\n", NULL);
```

`continue` (**drop the row**) rather than `lab ? lab : ""` (**emit `{ <type>}`**), and
the reason is a consumer contract, not taste: this output is read as `{name type}`
**tuples**, and `tests/stable_handles/net_body.tcl:50` asserts
`[llength [lindex $nets 0]] == 2`. A row with an empty name has `llength` **1**, so the
ternary would swap an unbalanced brace for a malformed tuple in the very same consumer.
A pin with no name is not a net. Leg **NN4** pins that choice.

Making `my_mstrcat()` itself NULL-tolerant is impossible: NULL *is* the sentinel, and
143 of its 149 call sites end in a literal `NULL)`. The codebase already knows this —
`actions.c:1426` and `actions.c:1726` use the `x ? x : ""` guard idiom, the latter for
the same job of building a braced Tcl row.

## Verification

| step | result |
|---|---|
| new test on shipping binary (both fixes reverted) | **7 FAILED / 2 passed** — NN0 dies on the 0181 segfault |
| new test with 0181 fixed, 0180 reverted | **4 FAILED / 5 passed** — NN1/NN2/NN5/NN6, brace imbalance |
| new test with both fixes | **ALL PASS (9 checks)** |
| 9 required headless suites, `--nogui` | 10/10 runs passed |
| `tests/stable_handles/net_body.tcl` (`--nogui` arm) | **39 PASS / 0 FAIL**, NC1a/NC1b green |
| `tests/netlist_diff/netlist_diff.sh` vs a true pre-fix build | 945 runs per arm, 0 errors, **BYTE-IDENTICAL (920 netlists)** |

The pre-fix binary was verified to really be pre-fix by running the new test against it
(7 FAILED / 2 passed) — trap 4 of the session prompt. It was built by
`git show HEAD:src/<f> > src/<f>` rather than `git checkout`, so the index was never
written and `git status` stayed at ` M` throughout (trap 2).

Note on the `net_body.tcl` floor: the prompt for this issue recorded 35 PASS / 4 FAIL.
On the `--nogui` arm it measures **39 PASS / 0 FAIL** — same 39 checks, so the four that
fail under a GUI display pass headless. Not a change caused by this work; recorded here
so the next person does not read 39/0 as suspicious.

## Wider question — answered

See `doc/claude/code_analysis/my_strtok_r_null_argument_audit.md` for the sweep of the
other `my_mstrcat()` call sites.
