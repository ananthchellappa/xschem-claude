# 0169 — devices/vpwl + devices/ipwl lost their PWL default: a nested quote needs `\\"`

Status: **FIXED** (2026-07-27)
Area: `xschem_libs_newsym/devices/{vpwl,ipwl}/symbol/*.sym` (one character each — the
symbol data, no C and no Tcl change)
Tests: `tests/headless/test_vpwl.tcl` (+4 checks, 17 → 21), `tests/headless/test_isources.tcl`
(+3 checks, 11 → 14)
Related: the cell-custom-form work (`doc/claude/specs/cell_custom_form.md`, commits
2ca21e4e / 66fe26a9 / c763ded6), which introduced both cells

## Report

> The vpulse added to devices library is working ok. The vpwl is not displaying any
> properties. I expect ipwl will have same problem.

The prediction was right, and it names the discriminator: **`vpulse`/`ipulse` templates
have no quoted value; `vpwl`/`ipwl` do.**

## Root cause

`vpwl.sym`'s `K {...}` block declared

```
template="name=V1 DC=0 pwl=\"0 0 1n 1\""
```

The PWL point list is one spaced string, so it must be quoted — and it sits inside the
already-quoted `template="..."`. The file reader **unescapes one level** when it stores a
`K`/`C` property, so a single-backslash `\"` becomes a bare `"` in the stored string:

```
stored : template="name=V1 DC=0 pwl="0 0 1n 1""
                                       ^ the template value ends HERE
```

Re-parsing that (`xschem getprop symbol <sym> template`) therefore truncates:

| | before | after |
|---|---|---|
| `getprop symbol … template` | `name=V1 DC=0 pwl=0` | `name=V1 DC=0 pwl="0 0 1n 1"` |
| `list_tokens` of the symbol's global prop | `type format template `**`0 1n 1`**` edit_form` | `type format template edit_form` |
| a freshly PLACED vpwl | `name=V1 DC=0 pwl=0` | `name=V1 DC=0 pwl="0 0 1n 1"` |

So a placed vpwl carried `pwl=0`, the PWL editor opened with **two blank rows** instead of
the default `(0,0) (1n,1)` — the "not displaying any properties" of the report — and the
netlist emitted `PWL(0 )`. The stray `0` / `1n` / `1` tokens also polluted the symbol's
global property.

## Fix

Write the inner quotes as `\\"`, which is what every stock symbol that carries a quoted
value already does (`devices/asrc.sym`, `switch.sym`, `title.sym`, `isource_table.sym`,
`param.sym`, …):

```
template="name=V1 DC=0 pwl=\\"0 0 1n 1\\""      # vpwl
template="name=I1 DC=0 pwl=\\"0 0 1n 1m\\""     # ipwl
```

One level of unescaping leaves `\"` in the stored property, which is exactly what the
token parser expects. Nothing else changed: `format`, `edit_form`, the companion `.tcl`
forms and the netlist path are untouched. A sweep of `xschem_libs_newsym/` found no other
single-backslash nested quote.

## Why the suite was green through this

Both test files only ever handed `slickprop::build_fields` a **literal** template string —
they never read `template` back off the symbol, and never placed an instance. The new
checks close exactly that gap:

- `symbol template keeps the quoted pwl default` / `ipwl template keeps the quoted pwl default`
- `symbol global prop has no junk tokens` / `ipwl global prop has no junk tokens`
- `placed instance carries the PWL default` / `placed ipwl carries the PWL default`
- `PWL default survives save+reload`

Sabotage-verified: reverting the vpwl `.sym` to the single backslash fails **4 of the 4**
new vpwl checks (`4 FAILED / 17 passed`) and nothing else. `test_vpwl` 21/21,
`test_isources` 14/14, `test_vpulse` 11/11 (unchanged — it has no quoted value, which is
why it worked all along), both arms.

## Note for future cells

A cell attribute whose value contains spaces has to be quoted; if that attribute is itself
inside a quoted attribute (a `template=`/`format=` value), the inner quotes are `\\"`. This
joins the other `format=` landmine for these cells: `PWL(@pwl )` needs the **space before
`)`**, because `@token` is terminated by whitespace only.
