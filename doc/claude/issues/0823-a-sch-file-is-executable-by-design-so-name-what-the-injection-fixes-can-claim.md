# 0823 — a `.sch` file is executable BY DESIGN, so no fix in the 0812 family may claim "opening a schematic is safe"

Status: **DESIGN FACT, measured 2026-08-25. Not a defect, and deliberately NOT
proposed for a fix.** Filed so it is citable, because three fixes in this family
have shipped or been drafted without it being written down anywhere.
Family context for: 0812 (fixed), 0816, 0817, 0821 (in flight), 0822.
⚠ **This issue exists to BOUND claims, not to generate work.**

## 0. ⚠ CORRECTION, 2026-09-27 — SECTION 2'S CENTRAL MEASUREMENT IS REFUTED

This section is at the top, ahead of the original filing, because **the severity changed**. The
filing below is kept verbatim so the corrections can be read against it; issue 1606 set that
precedent. Three items, all driven at `636bc431` in a throwaway directory with
`env -u DISPLAY ./src/xschem --nogui --pipe -q`, no display, no draw, no netlist.

**(a) "It does not fire on load. It fires on DRAW." is FALSE.** Section 2 measured a **text
floater** (`T {tcleval(...)}`), and for that record it is right — a floater's value is resolved
when it is drawn. But an **instance's symbol name** is resolved at load, because `load_sym_def()`
has to put the name through `tcl_hook2()` to find the symbol file at all. Driven, with a marker
file absent beforehand:

* `xschem load <file>` as the only subcommand, no draw, no netlist, no display — **fired**.
* A plain `./src/xschem --nogui --pipe -q <file>` with no subcommand at all — **fired**.

So the honest statement is **opening the file is sufficient, headless or not**, and it does not
depend on the GUI drawing anything. Section 2's parenthetical hedge — that the GUI draw was not
separately measured and SVG export stood in for it — is now moot in the direction that matters:
the trigger is earlier than either.

**(b) There is a SECOND door, and it is UNMARKED.** `get_generator_command()` in `src/token.c`
builds a command from a symbol name of the shape `head(args)` and the callers hand it to
`popen()`, i.e. `/bin/sh -c`. It quotes the generator's path and appends the **arguments raw**, so
every shell metacharacter in a symbol name is live. Driven: a symbol name
`/bin/true(z;/usr/bin/touch <scratch>/FIRED_VIA_SHELL)` created the marker, on a plain open.
**This needs no `tcleval(` marker**, so by section 3's own argument it is one of the *unmarked*
doors this file says are worth closing — not part of the by-design behaviour it declines to
reverse. Filed as its own defect, issue **1610**, and fixable without a ruling, because quoting the
arguments leaves every legitimate generator call byte-identical.

**(c) Section 5.2's census is now MEASURED**, and the answer is "it is everywhere", which section
5.2 itself said should then be recorded as settled. Instruments named, per the project's rule
that a census over source text is a census of spellings:
`/usr/bin/grep -rlF 'tcleval(' --include=*.sch --include=*.sym` gives **49 files under
`xschem_library/`** (19 `.sch` + 30 `.sym`) and **68 under `sky130A/`** (38 + 30), **117 in
total**, plus **5 generator scripts** shipped and referenced under `xschem_library/generators/`.
So the trust-prompt option is **not** cheaper than it sounds, and a blunt global off-switch would
break 117 shipped files including the primary PDK path. What that census actually argues for is the
**trusted-path** shape — evaluate under the install tree and configured library directories,
render literally elsewhere — which breaks none of the 117 while disarming a sheet that arrived by
mail, and which needs no blocking prompt and so cannot deadlock a batch or CI run.

**What section 4 still gets right:** the trust model is the user's ruling, not a crew's. It has now
been recorded as one on the owed ledger (`rule/0823`) rather than left as a sentence inside an
issue, which is what section 4 asked for and what nobody did.

## 1. Why this is filed

`grep -l 'untrusted\|threat model' doc/claude/issues/*.md` returns **nothing**
across 143 issue files. The 0812 family has been worked for two days on the
premise — stated in 0821's own header — that *"a `.sch` file is a document people
mail each other"*, and severity has been argued from it. That premise is right.
The conclusion people will draw from it is wrong, and nobody has written down why.

## 2. Measured

`src/xschem` at `01f71458`, `--nogui --pipe -q`, binary fresh. One text record:

```
T {tcleval([exec touch OWNED_HOOK2]hello)} 100 -100 0 0 0.4 0.4 {name=X1}
```

```
OWNED-after-load:
OWNED-after-draw: OWNED_HOOK2
```

**It does not fire on load. It fires on DRAW.** The draw here is a headless
`xschem print svg`; the GUI's draw path shares `translate()`, and opening a
schematic in the GUI draws it, so in the GUI **opening is sufficient**. (Stated
precisely: the *GUI* draw was not separately measured — SVG export was the
headless proxy, and the shared path is `tcl_hook2()`.)

The mechanism is `src/token.c:78 tcl_hook2()`, and it is **documented behaviour**,
not an oversight:

```c
/* if cmd is wrapped inside tcleval(...) pass the content to tcl
 * for evaluation, return tcl result. If no tcleval(...) found return copy of cmd */
if(strstr(cmd, "tcleval(") == cmd) {
  unescaped_res = str_replace(cmd, "\\}", "}", 0, -1);
  tclvareval("tclpropeval2 {", unescaped_res, "}" , NULL);
```

`tclpropeval2` (`src/xschem.tcl:9870`) is `uplevel #0 "subst \{$s\}"`. The sibling
`tclpropeval` (`:9829`, `catch {subst $s}`) is reached from the **netlisters** —
`src/token.c` 1187, 2668, 3046, 3541, 3803 (`print_spice_element`,
`print_spectre_element` and friends) — so netlisting a schematic is a second
execution trigger. **Not separately measured**; the call sites are read, not run.

⚠ The prefix is `tcleval(`, **not** `@tcleval(`. A fixture using the `@` spelling
produces a clean false negative — measured, and it cost one round here.

## 3. What this does and does not mean

**It does NOT excuse 0812 / 0821 / 0822.** Those remain real and worth fixing, and
the reason is precise: `tcleval(` is a **marker**. A reader of the file can see it,
a reviewer can grep for it, and its presence announces "this schematic contains
code." A `rawfile=`, `autoload=` or `sim_type=` attribute announces nothing —
0822 measured those returning `1`, `/x.raw` and `tran`, values indistinguishable
from honest ones, with the payload consumed and no residue. Closing the unmarked
doors converts "any schematic may be executing code invisibly" into "a schematic
executes code only where it says so." That is a large, real reduction in surprise.

**It DOES mean no write-up in this family may say any of the following:**

* *"opening a schematic someone sent you no longer runs their Tcl"* — false;
  `tcleval(` still does, by design, on draw;
* *"the injection family is closed"* — false while `tcl_hook2()` exists;
* *"a `.sch` from an untrusted source is now safe to open"* — false, and it is the
  sentence most likely to be written, because it is what the fixes feel like.

The honest form is: **a `.sch` is executable by design, like a Makefile or a
`.emacs`. The fixes remove the paths that execute WITHOUT saying so.**

## 4. Why no fix is proposed

Removing or gating `tcleval()` would break the feature xschem ships it for —
computed labels, parameterised symbols, `@tcleval` in netlist templates — across
the shipped libraries and every user's designs. It is upstream's design decision,
not this branch's to reverse, and it is the kind of change that belongs to the
project owner, not to a defect crew.

If it is ever revisited, the shape is a **trust prompt on load** (this file wants
to run code: allow / refuse / always-for-this-directory), not a removal — and that
is a feature proposal needing the user's ruling, not an issue.

## 5. What IS worth doing, cheaply

Nothing tonight, and nothing that blocks the family. Two candidates, both small,
both for after the user's 07:00 ratification:

1. **A one-line note in the fixes' own write-ups** pointing here, so the bounding
   claim travels with the work instead of living in one issue nobody reads.
2. **A census**: how many shipped `xschem_library/` sheets actually use
   `tcleval(`? If it is a handful, the trust-prompt option above is cheaper than
   it sounds. If it is everywhere, it is settled and should be recorded as settled.
   **Not measured here** — it is a `grep`, and guessing the answer in an issue is
   how 0681 happened.
