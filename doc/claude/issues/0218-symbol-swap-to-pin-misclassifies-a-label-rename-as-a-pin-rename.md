# 0218 — an Apply that swaps a label's master to `ipin` *and* renames it propagates as a pin rename

Status: **OPEN**
Severity: medium (silent connectivity change, no warning)
Introduced by: `74ef1aed` "renaming a pin renames its net labels", arrived on `fluid-editing`
via merge 3 of `github/open_pdk` (`958ada03`).
Spec: `doc/claude/specs/pin_rename_propagation.md` §"Direction, scope" and the §86 table row
*"source is not a pin (label→label…) | no-op | silent"*.
Found by: the merge-3 interaction audit (5 lenses, adversarial verify).

## Symptom

Select a `lab_pin`/`lab_wire` instance carrying `lab=FOO`, on a sheet where **other** labels
also carry `FOO`. Press `q` — the Cadence pin-form divert (`src/property_form.tcl:1247`) keys
on the instance's *current* master, so a label gets the generic slick form, which exposes the
Symbol row (`src/property_form.tcl:1334-1345`, or the L/C/V rows). In **one** Apply, set
Symbol to `devices/ipin.sym` and `lab` to `BAR`.

Result: every other label named `FOO` on the sheet is **silently** rewritten to `BAR`. The
gesture meant *"promote this one tap to a port called BAR"*; what happened is a sheet-wide
net rename. Pre-merge, only the edited object changed.

## Mechanism

In `apply_symbol_prop()` the order is:

| step | site | what happens |
|---|---|---|
| 1 | `src/editprop.c:1143` | `old_lab` captured from the **original** prop |
| 2 | — | the new prop (with the new `lab`) is written |
| 3 | `src/editprop.c:1197` | `xctx->inst[*ii].ptr = sym_number` — master re-pointed to the **new** symbol |
| 4 | `src/editprop.c:1246` | `if(ntargets == 1) propagate_pin_rename(*ii, old_lab)` |

`pin_rename_targets()` classifies the source by reading
`xctx->sym[xctx->inst[src_inst].ptr].type` at `src/editprop.c:991` through `IS_PIN`
(`src/xschem.h:582`) — i.e. the **post-swap** master. An object that was `type=label` when the
Apply began and became an `ipin` during it is therefore treated as a rename *source*.

No guard fires. `do_apply` reads `set symbol [.dialog.f1.e2 get]` (`src/property_form.tcl:607`)
and issues a single `xschem apply_properties` (`:638`) with the sticky default scope
`current` (`:1264`), which `scope_targets()` (`src/editprop.c:890-892`) resolves to
`ntargets == 1` — so the fan-out guard does not stop it. `oldlab`/`newlab` are non-empty and
different; ordinary nets are not global; the other `FOO` labels are unselected and take the
exact-match `continue` branch, so `PRR_BUSOVERLAP` is never evaluated; `PRR_AMBIGUOUS` needs
another *pin* named `FOO`. Status comes out `PRR_OK`, and the message block at
`src/editprop.c:1059-1073` fires only on the refusal statuses or `PRR_MERGE` — hence silent.

## Reachable / not reachable

- **Reachable**: the slick Edit Properties form (`edit_prop` → `slickprop::edit_form`,
  `src/xschem.tcl:10026-10028`), the L/C/V rows when the instance is library-managed, and a
  scripted `xschem apply_properties current <id> <newprop> <oldprop> 1`.
- **Not reachable**: scope `selected`/`all` (the `ntargets > 1` guard), and the vim/legacy
  property editor (that path cannot change the Symbol field).

## Suggested fix

Capture the source's pin-ness at the same moment `old_lab` is captured — i.e. before
`src/editprop.c:1197` re-points the master — and pass it in, or refuse (`PRR_NOT_PIN`) when
the master changed during the Apply. A symbol swap and a rename in one Apply is not a pin
rename in any reading of the spec.
