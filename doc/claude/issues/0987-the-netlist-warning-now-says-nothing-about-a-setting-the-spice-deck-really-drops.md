# 0987 — the netlist warning now says nothing about a setting the SPICE deck really drops

**Filed** 2026-08-30, by the item S4c write-up, from the verify pass's
measurement and re-measured by me before filing. **Status** open.
**Parent** issue **0980**, whose fix caused this. **Subject**
`warn_unused_instance_attr()` / GUARD UA-TMPL in `src/token.c`.

## The short version

Issue 0980's fix was correct and it worked: the warning went from 43 wrong lines
out of 149 to **0 wrong out of 98**. But the guard that silenced those 43 lines
asks *"can any netlist format this symbol supports consume this setting?"*, not
*"does the netlist I am writing right now consume it?"* — and the answer differs.
On the shipped library there are **43 lines' worth of settings that are silently
dropped from the SPICE deck the user asked for**, and the tool now says nothing
about any of them.

Before S4c the user got a warning that named a real drop and then gave advice
that would have broken their VHDL netlist. After S4c they get silence. Neither
is the whole truth, and this file records the half that is still missing so the
next pass is not re-deriving it.

## What the user sees, measured

Open `xschem_library/examples/loading.sch` and press netlist with SPICE
selected. The sheet sets a capacitance on each of four capacitors:

    cap=100.0 on x1,  cap=30.0 on x3,  cap=20.0 on x6,  cap=40.0 on x9

The deck that comes out:

    x3 VX real_capa
    x1 VXS real_capa
    x6 SP real_capa
    x9 VX2 real_capa
    .subckt real_capa USC  cap=10.0

No parameter on any instance line. `grep -c '100\.0'` and `grep -c '30\.0'` over
the deck both return **0**. All four capacitors simulate at **10.0**, the
symbol's default. The Command window says **nothing at all** — measured,
`SPICEWARN loading.sch 0`, where before the fix it printed eleven lines.

The brief's other headline sheet is the same shape.
`xschem_library/logic/ram_tb.sch` sets `dim=8 width=16 hex=1`; the deck reads
`.subckt ram ... dim=5 width=8 hex=0`, `dim=8` occurs **0** times in it, and
`SPICEWARN ram_tb.sch` is **0**.

## Why

`real_capa.sym` is `format="@name @pinlist @symname"`. That format passes no
parameters, so `cap` genuinely does not reach the SPICE simulator. GUARD UA-TMPL
excuses it anyway, because `cap` is in the symbol's `template=` and a **VHDL**
netlist of the same sheet really would carry `cap => 30.0`.

Both statements are true at once. The setting reaches the VHDL netlist and is
dropped from the SPICE deck, and the warning is written from the SPICE netlister
while claiming to speak about "the netlist".

## Size, on the shipped library

**These are the same 43 lines.** The 43 that were false positives under the
"can any format consume it?" rule are exactly the 43 that are false negatives
under "does the netlist being written consume it?" — the trade is one-for-one.
(S4c silenced 53 lines in total; the other 10 are the 6 GUARD UA-SYMNAME lines
and the 4 `select` lines, both of which really are consumed.)

43 of those 53 sit on seven cells whose SPICE format string passes
**no parameters at all**. Each format string was read out of the shipped
symbol for this table:

| lines | cell | its SPICE `format=` |
|---|---|---|
| 9 | `logic/latch` | `@name @pinlist @symname` |
| 8 | `examples/real_capa` | `@name @pinlist @symname` |
| 8 | `examples/pump` | `@name @pinlist @symname` |
| 7 | `logic/ram` | `@name @pinlist @symname` |
| 6 | `examples/switch_rreal` | `@name @pinlist @symname` |
| 4 | `rom8k/bts` | `@name @pinlist @VCCPIN @VSSPIN @symname` — two NODES, still no parameters |
| 1 | `logic/mux21` | `@name @pinlist @symname` |

## This was sanctioned by the brief, and is filed anyway

The item brief's rule is literal: *"A property is UNUSED only if NO netlist
format this symbol can be written in consumes it."* GUARD UA-TMPL implements
exactly that, so S4c did what it was told and the `false=0` claim is true under
the rule it was given. What the brief did not say is that the rule buys its
zero by going **silent about a real drop in the deck the user asked for**, and
neither the S4c implementation report nor issue 0980 says so either. That
omission is the reason this file exists.

The harm the brief opened with was the **advice** — "take it off" would have
broken a working shipped example. S4c's own 0982 work shows that advice can be
repaired instead of deleted. Deleting the observation was not the only way to
stop the advice being destructive.

## Options, none taken

1. **Per-format truth, one sentence.** Ask whether the format being written
   consumes it, and when it does not but another format would, say so:
   "…is not passed into a SPICE netlist of this cell — it does reach a VHDL or
   Verilog netlist, so do not remove it if you netlist this design in those."
   Most informative; a longer sentence; needs the elision budget re-checked
   (ruling D5-4 keeps it one mint site, so this is a wording change, not a
   second call site).
2. **Warn at a quieter level**, distinct from the "reaches nothing anywhere"
   class. Two severities to explain instead of one.
3. **Leave it silent** (today). Cheapest; the tool watches a designer set
   `cap=100.0` on four capacitors, simulate all four at `10.0`, and says
   nothing.

Option 1 is the one this file recommends. **It is the user's call and a rule
debt is recorded against this number.**

## Rows

None yet — nothing pins this behaviour either way, which is itself part of the
defect. A row asserting `loading.sch` is silent would freeze today's answer
before the question is asked, so it was deliberately not written.

## What is NOT wrong here

The netlister's output is unchanged: the decks are byte-identical to the ones
the pre-fix binary wrote. The dropped `cap` was dropped before S4c too — that is
issue **0978**'s subject, not this one. What changed is only whether the user is
told.
