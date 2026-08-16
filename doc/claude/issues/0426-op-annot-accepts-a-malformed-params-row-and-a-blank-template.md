# 0426 — `op_annot` validates the descriptor dict but not the one field users actually edit: a malformed `params` row silently changes the wrapper

Status: **open — measured, not fixed.** Found by the S1 Verify-C adversary of the
op-annotation run (2026-08-16) on branch `annotate`; all four cases re-measured
independently by the write-up agent with the transcript below. Left unfixed
because each fix is a behaviour choice (what should a bad row *do*?) and S1's
brief is the name builder, not a validation layer — but the gap is squarely in
the surface spec requirement **F** hands to users ("the user edits *which*
parameters are shown"), so it should be closed before S6 puts that surface in
front of anyone.

## Measured

Fixture: `top.sch` → `x1` (leaf) → sky130 `nfet_01v8` instance `M1`, descended to
`sim_sch_path` `x1.`. Template is the escaped, correct one.

```
SANE      <i(@m.x1.xm1.msky130_fd_pr__nfet_01v8[id])>      params {{id id 0} {gm gm 1}}
2FIELD    <v(@m.x1.xm1.msky130_fd_pr__nfet_01v8[id])>      params {{id id}}
WORDKIND  <v(@m.x1.xm1.msky130_fd_pr__nfet_01v8[id])>      params {{id id current}}
BLANKTPL  devpath <   >  vector <   [gm]>                  devpath {   }
PARAMCASE <@m.x1.xm1.msky130_fd_pr__nfet_01v8[GM]>         vector M1 GM 1
```

### 1. A `params` row with a missing or non-numeric `kind` silently becomes `v(…)`

`op_annot::_kind` returns `[lindex $row 2]`, which is `{}` for a two-field row,
and `op_annot::_wrap`'s `switch` has `default { return "v(${dev}\[${param}\])" }`.
So `{id id}` and `{id id current}` both produce a **voltage-wrapped drain
current**. Nothing raises.

The `default` branch is not itself a mistake — it is a deliberate mirror of
`token.c:4524-4525`, where `modelparam` that is neither 0 nor 1 also falls into
the `v(` branch, and `op_annot.tcl:202-208` says so explicitly. Diverging from
the C there is how two name builders start to drift (I1). The defect is that
nothing checks the row **on the way in**, where the value is known to be user
data and the C has no opinion at all.

`op_annot::register` already establishes the right instinct — it raises on an
odd-length dict, precisely so "an rc typo is caught at registration instead of
yielding blanks at draw time". It just stops one level too shallow: the dict
shape is validated, the `params` row shape is not.

### 2. A whitespace-only `devpath` template survives as a device name

`op_annot::devpath` guards with `if {$tmpl eq {}}`, so `{   }` passes, `translate`
returns it unchanged, and `vector` builds `"   [gm]"` — a non-blank, invalid
name that would be written into a save card. Inconsistent with `register`, which
does `string trim $type` on its own key.

### 3. The parameter name is not lowercased, though the device path is

`_lower` is applied to the device path only, so `vector M1 GM 1` yields
`…[GM]` while `get_fqdevice`'s `strtolower(fqdev)` (`token.c:4572`) — the
authority `op_annot.tcl` cites — lowercases the *whole* vector.

Harmless in practice, and verified so: ngspice's `save` and its vector lookup are
both case-insensitive, and `get_raw_index()` (`save.c:2251-2285`) retries case
variants at read time. But the file claims to mirror `token.c:4572` and does not
quite, and a golden-string comparison between two consumers would notice.

## Suggested fix (not applied)

In `op_annot::register`, validate each `params` row at registration — three
fields, third is `0`, `1` or `2` — and raise naming the offending row, in the
same voice as the existing odd-length-dict message. That is one loop and it
converts all of case 1 into the loud failure the file's own error discipline
asks for ("data conditions are blank, caller bugs are loud" —
`op_annot.tcl:86-101`): a bad row in an rc is a caller bug, not a data
condition.

For case 2, change the guard to `[string trim $tmpl] eq {}`. For case 3, either
lowercase `$param` in `_wrap` or delete the claim that the whole vector mirrors
`strtolower`.

`_wrap`'s `default` branch should stay exactly as it is — it is the C's
behaviour, and by then the row has already been vouched for.
