# 0988 — a setting no netlist format can consume is silent when the symbol's template declares it

**Filed** 2026-08-30, by the item S4c write-up, from the verify pass's
measurement. **Status** open. **Parent** issue **0980**, whose fix caused this.
**Sibling** issue **0987** — same guard, different half. **Subject** GUARD
UA-TMPL in `src/token.c`.

## The rule the fix was given, and the rule it implements

The item brief's rule, verbatim:

> A property is UNUSED only if **NO netlist format this symbol can be written
> in** consumes it.

GUARD UA-TMPL asks a narrower question: *is this name in the symbol's
`template=`?* Those two coincide on almost all shipped data, which is why the
sweep came out clean — but they come apart whenever the symbol **cannot be
written in the other formats at all**. A symbol carrying `vhdl_ignore=true` and
`verilog_ignore=true` is never emitted into a VHDL or Verilog netlist, so a
template name on it is consumed by nothing, anywhere — and the diagnostic is
silent about it.

## Measured

Two fixtures, both built and netlisted against the binary S4c shipped.

**Shape 1 — the format drops it and nothing else picks it up.** A subcircuit
symbol with `type=subcircuit`, `format="@name @pinlist @symname W=@W"` and
`template="name=x1 W=1 DEAD=0"`. An instance sets `W=7 DEAD=9 zzctl=1`. The
netlister warns about `zzctl` only. `DEAD` is silent, and the deck is:

    xR net1 vcread W=7
    .subckt vcread A  W=1 DEAD=0

`DECK_HAS_DEAD9: 0`. The user's `DEAD=9` is gone and unmentioned.

**Shape 2 — the sharp form, where no format anywhere can consume it.** The same
shape plus `vhdl_ignore=true verilog_ignore=true tedax_ignore=true
spectre_ignore=true`. An instance sets `KNOB=99 zzdead=1`. Measured:

    KNOB_WARNINGS: 0    CONTROL_WARNINGS: 1

and the value `99` appears **zero times across all four products the tool
wrote** — `vctop.spice`, `vctop.vhdl`, `vctop.v`, `vctop.tdx`. The VHDL entity
is empty, because the instance is skipped there entirely. The control attribute
proves the instance really did reach the diagnostic, so this is the guard
choosing silence, not the instance being skipped.

## Not synthetic

**112 `.sym` files in this tree carry a `vhdl_ignore` or `verilog_ignore`
flag.** The class is shipped, not invented for the fixture.

## The fix

Consult the `*_ignore` flags before crediting a format with consuming a setting:
a template name on a symbol that no other backend will ever emit is not reached
by anything, and the original 0970 warning is the correct thing to print. That
makes GUARD UA-TMPL implement the brief's rule as written instead of an
approximation of it.

Note this is a **narrowing** of the excuse, so it can only make the warning
speak more; it cannot resurrect any of the 43 false positives 0980 removed
(those symbols carry no `*_ignore` flags — the point of them is that they DO
netlist to VHDL and Verilog).

## Rows

None. A fixture pair for both shapes belongs with the fix; writing rows now
would pin today's silence as the contract.

## Relationship to 0987

0987 is *"the format being written drops it, another format would not"* — a
question about **which netlist**. This one is *"no format takes it at all, and
the guard excused it anyway"* — a straightforward miss against the stated rule.
0987 needs a ruling; this one does not.

---

# FIXED by item S4d, 2026-08-30

**Status** fixed, with issue 0987 and in the same function. **Subject** the new
`ua_inst_or_sym_flag()` in `src/token.c`, GUARD UA-IGNORE.

## What was wrong, reproduced

A symbol whose `template=` declares `knob`, whose format string never mentions
it, and which carries `vhdl_ignore=true verilog_ignore=true spectre_ignore=true
tedax_ignore=true`. The sheet types `knob=99`. Measured on the pre-fix binary:
the SPICE deck carries only the template default `knob=1`; the VHDL netlist
holds **no instance of that cell at all**; the Verilog and tEDAx products mention
`knob` nowhere. The tool said nothing about `knob` — while correctly reporting a
control setting on the very same instance, so the instance was not being skipped
wholesale. Exactly the case the diagnostic exists for, and it was the one that
got away.

## The fix

The reach test now asks, per backend and before anything else, whether this
instance is written out in that format at all:

```c
static int ua_inst_or_sym_flag(int inst, int mask)
{
  return ((xctx->inst[inst].flags & mask) ||
          (xctx->sym[xctx->inst[inst].ptr].flags & mask)) ? 1 : 0;
}
```

The bits are the ones `skip_instance2()` tests — `VHDL_IGNORE|VHDL_SHORT`,
`VERILOG_IGNORE|VERILOG_SHORT`, `SPECTRE_IGNORE|SPECTRE_SHORT`,
`TEDAX_IGNORE|TEDAX_SHORT` — set from the `*_ignore` attributes by
`set_sym_flags()` and `set_inst_flags()` in `actions.c`, so the check asks the
netlisters' own question rather than re-parsing the strings. With every mark set,
nothing carries the setting, `ua_reach()` answers `UA_NOWHERE`, and the original
accusing sentence is printed — which is the truthful one, because there really is
nothing here to keep.

`LVS_IGNORE` is deliberately not consulted: when it applies,
`spice_netlist.c`'s own `skip_instance()` means `print_spice_element()`, and
therefore this whole check, is never reached for that instance.

**Both halves of the flag test are pinned separately.** The symbol half is seen
by `UN2` and `UN4`; the instance half — the marks typed on **one copy** of the
cell rather than on the cell itself — had no witness anywhere until `UN5` was
written for it, and would have deleted clean with every check green. Verified by
deleting each half in turn against a built binary: dropping the symbol half
reddens `UN2` and `UN4` and nothing else; dropping the instance half reddens
`UN5` and nothing else.

## Rows

* `UN2` — all four marks on the cell: 2 lines, **both** accusing.
* `UN3` — the same cell with the marks off, the only difference: `knob` becomes
  the other shape and names *VHDL or Verilog*. Paired with UN2 this is the only
  place the difference between the two answers can be seen.
* `UN4` — marked not to be written in VHDL **only**: the list drops VHDL and
  keeps Verilog, so the marks are demonstrably read one netlist at a time and
  not as one blanket.
* `UN5` — the marks typed on one copy of an otherwise ordinary cell.

## Rejected alternative

Calling `skip_instance2()` directly. It is static to `netlist.c` **and** keyed to
`xctx->netlist_type`, which is `CAD_SPICE_NETLIST` at this call site, so it
cannot answer "would a VHDL netlist skip this instance". A three-line local
reader of the same bits keeps the change to one file.
