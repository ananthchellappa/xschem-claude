# 0158 — `resolved_net()` leaks `#` on every bus element after the first

Status: **FIXED** (2026-07-26)
Area: `src/hilight.c` (`resolved_net`)
Tests: `tests/headless/test_resolved_net_hash_bus_0158.tcl` — `HS0`-`HS19` (21 checks, new file)
Related: 0154 (the audit that surfaced it — "Not fixed" item 4), 0156 (the `#`-is-reserved policy
and `is_auto_net_name()`), 0157 (the other defect in the same loop, fixed first)

## Report

From the 0154 backlog:

> **`resolved_net` leaks `#` on non-first bus elements** — the strip runs once on the whole token
> before `expandlabel`: `{D,#net1}` → `D,#net1`.

Reproduced first-hand at 7dea8447 in both arms, and it is worse than the one-liner suggests.
With a real auto-named net minted by the engine:

```
{#net1,TOP}   -> net1,TOP     (correct)
{TOP,#net1}   -> TOP,#net1    (leaked)
{#a,#b}       -> a,#b
{a[1:0],#b}   -> a[1],a[0],#b
```

and **descended**, the leaked `#` does not even stay at the front of its own element — it lands in
the middle of the answer, behind the hierarchy prefix:

```
{LOC,#x}      -> X1.LOC,X1.#x
{LOC,#x,GND}  -> X1.LOC,X1.#x,GND
```

`X1.#x` is not a name any netlist or `.raw` contains.

## Root cause

An unlabeled net is `#netN` in `wire[].node` but `netN` in the netlist and the `.raw`
(landmine 23). `resolved_net()` produces the **simulator-side** name, so it strips the marker —
but it did so once, on the whole incoming token, at `src/hilight.c:2602`, *before* `expandlabel()`
at `:2611` split the token into bus elements:

```c
    if(net[0] == '#') net++;            /* :2602 -- one token, one strip */
    ...
    my_strdup2(_ALLOC_ID_, &exp_net, expandlabel(net, &mult));   /* :2611 */
    for(k = 0; k < mult; k++) {
      char *net_name = my_strtok_r(n_s1, ",", "", 0, &n_s2);
      ...
```

So only whichever element happened to be first ever lost its `#`.

`#` is a perfectly ordinary label character to the parser — it appears in the `LAB`, `LAB_NODASH`,
`LAB_NUM`, `IDX_LAB_NUM_SP` and `LAB_NUM_SP` character classes in `src/parselabel.l` (~162-173) —
so `expandlabel` passes it through and distributes it over bracket bits:
`expandlabel("#a[1:0]")` = `#a[1],#a[0]`. That is why the pre-strip *looked* adequate for the
single-element case and silently failed for every other position.

## Fix

Move the strip inside the loop, one per element (`src/hilight.c`):

```c
-    if(net[0] == '#') net++;
```
```c
     for(k = 0; k < mult; k++) {
       char *net_name = my_strtok_r(n_s1, ",", "", 0, &n_s2);
       level = xctx->currsch;
       n_s1 = NULL;
+      /* strip the auto-net marker PER ELEMENT. ... issue 0158 ... */
+      if(net_name && net_name[0] == '#' && net_name[1]) net_name++;
       my_strdup2(_ALLOC_ID_, &resolved_net, net_name);
```

Three decisions worth recording:

**The strip stays LOOSE (any leading `#`), not `is_auto_net_name()`.** 0156 reserved `#` and added
the strict `#net`+digits predicate, but ruled that *output-strip* sites stay loose. Measured, that
is not a style preference — a user-authored `lab=#foo` **netlists as plain `foo`**:

```
R1 foo net1 1k
```

so a strict predicate here would make `resolved_net` disagree with the netlist for exactly the
names 0156 declared legal-but-discouraged. The sabotage run below turns the strip strict and
reddens 12 legs.

**It happens BEFORE the hierarchy lookups**, which is what element 0 already did — the
`hier_attr`/`portmap` resolution has always seen a stripped name. The portmap path cannot
re-introduce a `#` afterwards, because portmap *values* are stripped at `actions.c:3594-3599` when
the map is built. The `hier_attr` path **can** — see the separate finding at the end of this file;
that escape is pre-existing, was equally true for element 0, and is deliberately not fixed here.

**A bare `"#"` is never stripped to the empty string** (`&& net_name[1]`). The `,` separator at the
bottom of the loop is written regardless of what the element produced, and `my_mstrcat` skips an
empty argument, so an emptied element would emit a stray separator — `{a,#}` → `a,`. That is not
hypothetical: sabotage B below removes the guard and produces exactly `a,`.

## Behavior delta outside the bug

`xschem resolved_net {#}` returned the **empty string** before (strip → `""` → nothing to append)
and now returns `#`. `#` alone is not a legal net name — 0156 made `addlabel::name_ok` refuse it
and ERC warn about it — but a legacy file can still carry `lab=#`, and `#` is a more truthful
answer than a silent empty string. Pinned by `HS13`.

## Blast radius

Same five callers as 0157: `send_net_to_graph` (`hilight.c:1595`), `translate()`'s
`@#<pin>:resolved_net` (`token.c:4253`), the two scalar-only `@spice_get_voltage` sites
(`token.c:4224`, `:4718`, guarded by `multip == 1`, so unaffected), and the `xschem resolved_net`
verb (`scheduler.c:9254`). A leaked `#` reaching `send_net_to_graph` produces a graph trace name
that `get_raw_index` cannot match (it never strips `#` — landmine 23), i.e. a silently missing
trace; reaching `translate()` it produces a netlist card naming a net that does not exist.

Nothing in the tree depended on the old behavior: the Tcl callers of `xschem resolved_net`
(`tests/headless/wireedit/predicates.tcl`, the `test_fluid_*` files) use it for its
`prepare_netlist_structs` side effect only, and `src/ase_window.tcl` does its own `#` handling in
`sod_expr` and deliberately never calls this function.

## Test

`tests/headless/test_resolved_net_hash_bus_0158.tcl`, 21 checks, teeth in **both** arms.

Fixture in `test_scratch`: a parent whose subcircuit `X1` has pin `A` wired to the named net `TOP`,
a `GND`, and an `R1` with a free wire stub so the engine mints real `#netN` names; a child with the
port `A`, a local net `LOC` and `GND`. `HS0` reads the auto-named net **out of `xschem nets`**
rather than hardcoding `#net1`, so a renumbering fails the witness instead of skewing a leg.

- `HS0`-`HS1` — fixture witness + the already-working element-0 case.
- `HS2`-`HS7` — the defect: a real auto net in second position, `{#a,#b}`, `{a,#b}`, `{a,#b,c}`,
  after a bracket expansion, and two auto-shaped names in a row.
- `HS8`-`HS11` — controls: leading element, plain bus, `#a[1:0]` (the `#` must keep distributing
  over the bits inside `expandlabel`), and `##a` losing exactly one `#`.
- `HS12`-`HS13` — the lone `#` element and the stray-comma guard.
- `HS14`-`HS15` — interaction with 0157: strip after / before a global element.
- `HS15a` — **downstream** witness through `translate lBUS {@#0:resolved_net}`, the same
  consumer 0157 pinned with `RB8`, so the fix is proven where it reaches netlist output.
- `HS16`-`HS19` — descended: prefix and strip both applied per element.

### Verified

- RED first: **11 FAILED / 10 passed** before the fix; **21/21** after, in both the `--nogui`
  and the `--pipe`+`DISPLAY=:0` arm.
- Sabotage A — make the strip strict (`is_auto_net_name`): **12 legs red**, including the
  previously-passing controls `HS8`/`HS10`/`HS11`/`HS15`, so the loose-vs-strict choice is pinned.
- Sabotage B — drop the `net_name[1]` guard: `HS12` → `a,` and `HS13` red, so the stray-separator
  guard has teeth.
- 0157's file (`test_resolved_net_bus_global_0157.tcl`) still 19/19 — the two fixes are in the same
  loop and do not fight.
- Green after the fix: `test_prep_result_contamination_0155` (12), `test_hash_label_crash_0156`
  (23), `test_ase_unnamed_net` (28), `test_ase_interact` (63), `test_ase_plot` (145),
  `test_wave_viewer` (292), `test_wave_modes` (174), `test_ase_window` (166), `test_ase_dialogs`
  (133), `test_ase_persist` (109), `test_ase_core` (66), `test_ase_final` (28),
  `test_ase_final_gf180` (33), `test_add_wire_label`, `test_wire_split`, all 24 `test_fluid_*`,
  and the 52-file `wireedit` subset (0 leaked scratch dirs).
- `full_audit.sh` classifies both new files (0157 and 0158) as **PASS** with 0 leaked scratch dirs.

### NOT verified

- No `full_audit.sh` run for this change (targeted suites above instead).
- `send_net_to_graph` is reasoned about, not exercised — it needs a loaded `.raw` whose vectors
  match a bus containing an auto-named net.
- The `hier_attr` (`get_tok_value` on an instance property) resolution path is not covered by a
  leg: the fixture resolves through the **portmap**. See the separate finding below.

## Found while fixing this, NOT fixed — a third `#` leak, from an instance attribute → **issue 0163**

The strip runs *before* the hierarchy lookups (as it always did for element 0), so a value that
arrives *from* a lookup is never stripped. The `hier_attr` path — `get_tok_value` on the parent
instance's own properties, `hilight.c:2620` — can therefore put a `#` straight into the output.
Measured on the 0158 fixture with the instance carrying `LOC=#foo A=#bar`, descended into `X1`:

```
{LOC}         -> #foo          (expected foo)
{A,#x}        -> #bar,X1.x     (expected bar,X1.x)
{LOC,#x,GND}  -> #foo,X1.x,GND
```

Pre-existing and untouched by this fix — the same escape existed for element 0 before it. It is a
different source from 0158's (the *input token* vs a *resolved value*), and the portmap path is
already immune because `actions.c:3594-3599` strips when the map is built.

Opened as **issue 0163**, which also records the bigger problem found on the same line: that
attribute lookup is completely unguarded, so **any** instance attribute whose name collides with a
child net name silently replaces it — measured, a child net called `value` on an instance carrying
`value=1k` resolves to `1k`, and `spice_ignore` resolves to `false`.
