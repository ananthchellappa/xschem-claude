# 0823 — a `.sch` file is executable BY DESIGN, so no fix in the 0812 family may claim "opening a schematic is safe"

Status: **DESIGN FACT, measured 2026-08-25. Not a defect, and deliberately NOT
proposed for a fix.** Filed so it is citable, because three fixes in this family
have shipped or been drafted without it being written down anywhere.
Family context for: 0812 (fixed), 0816, 0817, 0821 (in flight), 0822.
⚠ **This issue exists to BOUND claims, not to generate work.**

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
