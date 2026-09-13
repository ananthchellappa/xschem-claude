# 1438 — `render_deck` spells options without a `cptype`, and three classes of value are silently wrong

**Filed by the driver, not fixed.** Found by the Stage 7 task-1 crew (issue **1437**)
while building the option catalogue, named in its receipt, and deliberately left
unfixed because the fix belongs to `PLAN.md` **§7d**/**§7e**. Filed under its own number
so it is findable by a user asking *"why is my W wrong?"* rather than only by someone
reading a catalogue receipt.

**Branch:** fluid-editing. **Stage:** found during Stage 7 of
`doc/claude/ase_analyses_batch/`, older than the batch.

## One root cause

`render_deck` writes an option line from a stored `{name … value …}` pair **without
consulting what kind of option it is.** Until issue 1437 there was no `cptype` column to
consult, so this is not a regression — it is the defect the catalogue was built to make
visible, and it turned out to be already shipped rather than merely possible.

Three classes of value come out wrong, and **every one of them is silent**: no refusal,
no warning, rc 0, and a results file that looks ordinary.

## 1. ⚠ FIVE COMMITTED BENCHES ASK FOR `wnflag` AND NONE OF THEM GETS IT

`wnflag` decides whether a MOS `W` is the **total** width or the width **per finger**.
Driver-verified 2026-09-13:

```
$ git ls-files | grep '\.state$' | xargs grep -l wnflag
sky130A/xschem_libs/sky130_tests_ase/sky130_mismatch/ngspice_state1/sky130_mismatch.state
sky130A/xschem_libs/sky130_tests_ase/tb_bandgap_opamp/ngspice_state1/tb_bandgap_opamp.state
sky130A/xschem_libs/sky130_tests_ase/tb_ft_test_2/ngspice_state1/tb_ft_test_2.state
sky130A/xschem_libs/sky130_tests_ase/test_mos_binning/ngspice_state1/test_mos_binning.state
sky130A/xschem_libs/sky130_tests_ase/test_nmos/ngspice_state1/test_nmos.state

$ … | xargs grep -ho 'name wnflag value [0-9]*' | sort | uniq -c
      5 name wnflag value 1
```

`render_deck` spells a stored `1` as a **bare card**, so the deck carries
`.options wnflag`, and the crew measured on both binaries that a bare card makes it a
**valueless boolean**:

```
.options wnflag      ->  + wnflag        <- valueless
.options wnflag=1    ->    wnflag   1
```

**It is the wrong door twice over**, and the second half is the one no value would fix.
Driver-verified in the ngspice source, all three read sites at the cited lines and all
three `CP_NUM`:

```
src/spicelib/parser/inpgmod.c:268   cp_getvar("wnflag", CP_NUM, …)
src/frontend/inp.c:2828             cp_getvar("wnflag", CP_NUM, …)
src/frontend/inpcom.c:990           cp_getvar("wnflag", CP_NUM, …)
```

A `CP_BOOL` cannot answer a `CP_NUM` read. And `inpcom.c:990` sits inside
`inp_get_w_l_x()`, which is called from `inp_readall_cards()` at `inpcom.c:1535` — the
card-reading pass whose own file header names `inp_readall()` as its central function.
**That read happens while the netlist is being read, so no `.options` card can reach it
at all**, whatever it says. (The crew's receipt writes that site as *"inside
`inp_readall()`"*; the exact enclosing function is `inp_readall_cards`, which is where a
reader should look.)

**Net effect: the user asked for W per finger on five of their own benches and has been
getting W total, with nothing said by anything.**

## 2. A valued option stored as `1` is written as a bare card

Measured by the crew on both binaries, reading `option`'s own dump after a `tran`:

```
.options maxord=1    ->  MaxOrder = 1
.options maxord      ->  MaxOrder = 2     <- what render_deck writes for value 1
```

Driver-corroborated in the source: `cktsopt.c:314` declares `maxord` as
`IF_SET|IF_INTEGER`, and the `OPT_MAXORD` arm at `:123-124` reads `val->iValue`. A card
carrying no value cannot supply one, and `:126-127` then clamps whatever it finds.

## 3. A valued option stored as `0` is dropped

```
.options gminsteps=0 ->  gminsteps = 0    <- gmin stepping disabled
(nothing emitted)    ->  gminsteps = 1    <- what render_deck writes for value 0
```

⚠ **`PLAN.md` §7b predicted this one, as *"this batch's own defect inside its own
antidote"*.** The prediction was about a speller that did not exist yet. The defect is
older than the prediction and it is in the **emitter**.

## Why it is not fixed here

Fixing it means routing `render_deck`'s option emission through `ase::opt_line` — issue
1437's speller — and that changes what a deck contains for benches that already exist.
`wnflag` in particular cannot be fixed by a better card at all: it needs the pre-deck
door, which is `PLAN.md` §7d's subject and carries ⚖ **R2**'s four conditions as
requirements. So the repair is **§7d/§7e's**, and it is sequenced rather than deferred.

Section **BR** of `tests/headless/test_ase_options_1437.tcl` pins the blast radius by
name so the crew that rewires the emitter does not have to re-derive it.

⚠ **Until that lands, a `wnflag` tick on those five benches is a setting the user made
and the tool discarded.** That is worth saying out loud rather than leaving in a
catalogue receipt, which is why this number exists.

---

## ⚠ CORRECTED 2026-09-13 BY ISSUE 1439 — DEFECT 1's MECHANISM ABOVE IS WRONG

**The outcome stands and the explanation does not.** Issue **1439**'s crew re-read all
three `wnflag` sites and refuted the reasoning this file was filed on; the driver verified
the refutation in the ngspice source and it is correct.

**What this file said:** that `wnflag` is *"the wrong door twice over"* — that a bare card
cannot answer a `CP_NUM` read **and** that the read at `inpcom.c:990` happens during card
reading where *"no `.options` card can reach it at all"*.

**The second half is false, because two of the three sites are DEAD CODE:**

| site | status | verified |
|---|---|---|
| `src/frontend/inpcom.c:990` | reads `wnflag` into a **local that `inp_get_w_l_x()` never uses again** | driver-read: `int wnflag;` at `:989`, the `cp_getvar` at `:990`, and **no further mention of the name anywhere in the next 110 lines** |
| `src/frontend/inp.c:2828` | inside `rem_unused_mos_models()` at `:2685`, which is inside **`#ifdef REM_UNUSED`** opened at `:2683` — and `REM_UNUSED` is **defined nowhere in the ngspice tree** | driver-read: `grep -rn 'define REM_UNUSED' src/` returns **nothing** |
| `src/spicelib/parser/inpgmod.c:268` | **the only live read**, at model-binning time | ngspice's own comment at `:294-295`: *"We do have nf, but no wnflag on the instance. Now it depends on the default wnflag **or on the `.options wnflag`**"* |

**So `.options` IS the right door.** `wnflag` is a `deck` option, not a pre-deck one, and
**defect 1 of this file is defect 2 of this file** — a valued option written as a bare
card. It is fixed by the speller, in `1439`, and needs no pre-deck delivery at all.

⚠ **The user-visible claim is unchanged**: five committed benches carry
`{name wnflag value 1}`, the deck ASE-L wrote said `.options wnflag`, and a valueless
boolean cannot answer a `CP_NUM` read — so the value did not arrive. What changes is that
the repair is one line of spelling rather than a new delivery channel, and it has landed.

⚠ **What the driver did NOT reproduce**: the *behavioural* delta. Issue 1439's crew
measured `.options wnflag` → `@m1[vth]` 0.9889 / `i(vd)` −1.017 mA against
`.options wnflag=1` → 0.5889 / −1.737 mA (**71 %**), on a flat `m` line and on the sky130
`x`-line shape, on both binaries. The driver's own scratch probes used an **unbinned**
model and then a malformed binned one, and `wnflag` only acts where a model is **binned** —
so they showed no difference, which is consistent with the source rather than contrary to
it. **The source evidence above is the driver's; the 71 % is the crew's and was not
independently re-taken.** Said plainly rather than blurred, because this file has already
been wrong once about a mechanism.

**Lesson, and it is this file's own:** *a mechanism assembled from grep hits is a
hypothesis, not a measurement.* Three `cp_getvar("wnflag", …)` call sites were read as
three live reads. Two were dead — one a dead local, one behind a macro nobody defines —
and the dead one carried the whole argument. ⚠ **Before building a defect's explanation on
a call site, establish that the site executes.**
