# 1412 — four defects this ngspice has or has not, measured from files instead of a version string

**Status:** fixed
**Branch:** fluid-editing
**Stage:** commit **C7** of Stage 2 of `doc/claude/ase_analyses_batch/` (plan item **2g**), and the
last commit of the stage.

## Why behaviour and not a version string

⚠ **This suite's own header already records the measurement that forces it:** two *different*
builds both print `** ngspice-46+ : Circuit level simulation program`, **byte for byte**. One
version string, two binaries, measured in-tree. So the variant questions are asked as **behaviour,
from files**, and the identity keys are display and log only — never compared, never ordered (D44).

## What ships

One additional `-b` process, **last**, out of the same budget. Measured on all three preflight
binaries: below `/usr/bin/time`'s resolution.

Three **Band-3 defect** keys and two **Band-1 identity** keys:

| key | apt 45.2 | the fork | upstream 47 |
|---|---|---|---|
| `one_vector_write` — a one-save `op` plot comes back holding **one** vector | 0 | **1** | 0 |
| `keyword_case` — a **capitalised** keyword argument resolves | 0 | **1** | 0 |
| `gnd_literal` — a bare `gnd` token survives a control argument list | 0 | **1** | 0 |

⚠ **Polarity is "1 = SOUND", and each key is named for the DEFECT rather than for the fix** — so it
survives somebody fixing it a different way, and survives the fork being upstreamed.

## The rename that makes a verdict honest

⚠ **The ground marker is `@@gref=`, not `@@gnd=`.** With the key itself spelled `@@gnd=`, the
natural test `string first gnd <line>` is **true on every binary including the two that rewrite** —
the key satisfies its own search, and the verdict measures nothing. Measured payloads after the
rename: `my 0 rail` on apt 45.2 and upstream 47, `my gnd rail` on the fork. Row **V2** pins both
halves.

⚠ **And the deck asks with `ALL`, upper case, deliberately.** Measured on apt 45.2:
`write w.raw all` **succeeds** while `ALL` and `All` both fail with *"vector ALL is not available or
has zero length"*. Lower-casing it turns `keyword_case` into a probe that answers 1 on every binary.

## A folder name could have killed the user's Run

⚠ `probe_d.txt` is written by a program ASE-L does not control, and its payload can contain **the
user's own folder name**. Handing that to a Tcl **list** command — `foreach`, `lsearch` — raises on
a double quote or an unbalanced brace, inside `capabilities`, which `ase::sim_capabilities_at`
**deliberately re-raises**: the exception reaches the Run gesture as a stack trace. That is issue
**0949**'s category error escalated from a silent wrong answer to a crash.

Words come out by `regexp -all -inline` and are compared as strings; the whole reader block is
wrapped, and a raise publishes **`noanswer`** rather than propagating. Row **V6** drives a payload
carrying both characters.

## Three keys dropped, and the reasons

- **`flags`** — `version -f` reports only XSPICE, CIDER and KLU and says nothing about rfspice, osdi
  or pss; the rest were derivable from issue 1409's two keys or unmeasured. Half the key was
  underivable and half answered the same question from the same oracle, which is the drift this
  batch exists to delete.
- **`curcasemode_default`** — it reports the **current** mode, never the supported **set** (measured:
  the empty string on apt 45.2 and upstream 47, whose logs say `Error: curcasemode: no such
  variable.`), D52 forbids its one tempting use, and nothing in the stage reads it.
- **`scripts_path`** — measured, `$sourcepath` came back **empty from inside the probe deck on all
  three binaries**, so the key would be absent everywhere in this environment.

**A key with no consumer, no value on any binary here, and one forbidden use is not a key.**

## `noanswer` is a third provenance token, for a different condition

The two already wired record a leg that was **cut**. This one records a leg that **ran, was not
cut, and whose artifact did not come back in a readable shape**. Collapsing them would tell the user
their box was slow when it was not.

⚠ **Leg D runs last, and the ordering has a cost worth naming:** on a slow box it is the **first**
thing a spent budget kills, so Band 3 then stays unmeasured for the whole session —
`ase::sim_caps` is written only on `known 1` and cleared only by `ase::sim_caps_clear`. That is why
it records its own absence by name instead of going quiet.

## One self-inflicted trap worth the next reader's time

⚠ **Tcl counts braces inside comments.** Writing an unbalanced one in a comment — even in
backticks, even as the example of the very character being discussed — left the enclosing
`namespace eval` unclosed and **aborted xschem at startup** with
`missing close-brace: possible unbalanced brace in comment`. That is issue **0663**'s arm. The
comment now says so, in prose, without showing the character.

## Verification

`test_ase_simcaps_0948` **148 → 158** (section **V**, 10 rows).

**Five sabotage passes:** renaming the marker back to `@@gnd=` (V1, V2, V3, V6); asking with a
lower-case keyword (V1); handing the payload to a list command (V6); a cut leg going quiet (V9);
a variant reader publishing `casemode_detected` (V3, V5, V7).

⚠ **V7's scope had to exclude `capabilities` itself**, which matches `cap*` and writes that key
**twice by design** — once to publish the casemode leg's answer, once to record it unmeasured when
cut. The first scope counted those two and **reddened a correct tree**.

One real end-to-end probe against the binary the registry resolves to: all three Band-3 keys
measured, `version_line ngspice-46+`, `unmeasured_keys` empty.

## Related

* **1407** — the vocabulary and `unmeasured_keys`, which `noanswer` extends.
* **1409** — the probe leg that shares the deck and the budget.
* **0949** — the folder-name category error this avoids escalating.
* **0663** — startup aborts on an unsourceable file.
