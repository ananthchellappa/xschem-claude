# 0500 — the C `@spice_get_*` floaters fold the query before the one lookup authority

**Status:** OPEN
**Filed:** 2026-08-16, casemode batch item 5b
**Area:** `src/token.c` (`get_pin_attr()` and the five sibling floater branches)
**Related:** `doc/claude/specs/raw_case_mode.md` §13.8, `DECISIONS.md` **D3**,
casemode item 4 (`hilight.c`, the same shape already fixed on the sender side)

## What

`token.c` expands the `@spice_get_voltage` / `@spice_get_current` /
`@spice_get_diff_voltage` / `@spice_get_modelparam` / `@#<pin>:spice_get_voltage`
tokens that `lab_pin`, `ipin`, `opin`, `iopin`, `vdd`, `ngspice_probe` and
`scope` symbols carry in their `T` records. Its own comment calls it "the
schematic voltage overlay by a second road".

It reaches the one lookup authority — `get_raw_index()` — but **folds the query
first**. Thirteen `strtolower()` calls, all immediately before a lookup:

```
src/token.c:4358  4535  4572  4855  4951  4954  4957  5036  5065  5126  5132  5217  5258
```

Item 5b deleted the equivalent fold from the **Tcl** overlay
(`ngspice::get_voltage` and friends), so the query there now carries the
schematic's own spelling and the ladder decides. These did not change.

## Why it matters

| mode | Tcl overlay asks | C floater asks | agree? |
|---|---|---|---|
| `fold` | `EN` → folded rung hits `v(en)` | `en` → exact hit | **yes** |
| `preserve` (stored `v(EN)`) | `v(EN)` exact hit | `v(en)` → folded rung hits | **yes** |
| `distinguish` (stored `v(EN)`) | `v(EN)` **exact hit** | `v(en)` miss, folded rung suppressed → `-` | **NO** |

So under the default and under `preserve` nothing is wrong. Under
`distinguish` the same net reads a voltage through one road and a dash through
the other, on the same schematic, at the same time.

This is item 5b **fixing one half** of what `PLAN.md` §5.7 recorded as
"backannotation will break under `distinguish` — accepted for this batch". It is
strictly better than before, where both halves broke. But the halves now
disagree, and that is worth a number.

## Why item 5b did not just do it

It is not a thirteen-line deletion. Each fold feeds case-sensitive logic
downstream of it, so removing one without the other breaks the name it builds:

```c
  strtolower(dev);
  prefix = dev[0];
  ...
  int vsource = (prefix == 'v') || (prefix == 'e');
  else if(prefix == 'q')  ... else if(prefix == 'd' || prefix == 'm') ...
  else if(prefix == 'i')  ...
  ...
  if(idx < 0 && !strncmp(fqdev, "i(@r", 4)) { ... }      /* the R -> B source retry */
```

A device drawn `Vs` with the fold gone and the tests unchanged builds
`i(@V.Vs)`, which no simulator writes in any mode. This is exactly the shape
item 4 handled on the `hilight.c` sender side: **gate or blind each
classification, then drive every branch**. Six branches, ~200 lines, and its own
red/green evidence — an item, not an aside.

## What "fixed" looks like

1. Every classification above becomes case-blind (`tolower(prefix)` for the
   comparison only, `my_strncasecmp` for the `i(@r` retry), keeping `dev` and
   `fqdev` in the schematic's own spelling.
2. The `strtolower()` calls go.
3. All six branches driven on a `preserve` and a `distinguish` fixture, plus the
   `@dev[param]` shapes item 5 measured (`i(@r1[i])`, `i(@r.x1.rq[i])` folded;
   `i(@R1[i])`, `i(@R.X1.Rq[i])` preserved).
4. An **agreement** check: for one net, the Tcl overlay and
   `xschem translate <inst> {@spice_get_voltage}` must answer the same thing in
   every mode. That is the check whose absence let this diverge.

`token.c:4358`'s fold also feeds `!strcmp(fqnet, "0")` and
`my_strcasecmp(fqnet, "GND")` — both already case-safe, so that branch is the
cheap one.
