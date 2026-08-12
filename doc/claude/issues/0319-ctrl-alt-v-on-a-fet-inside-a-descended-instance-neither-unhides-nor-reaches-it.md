# 0319 — Ctrl-Alt-V on a FET inside a descended instance neither ticks `Show device internals` nor reaches the device

**Status:** **FIXED pending an eyeball** (2026-08-12), commit `c858efd0`, UNPUSHED. One line at the call site
in `src/ase.tcl` plus two new procs; `src/wave_viewer.tcl` is UNCHANGED and the
R12 `==` was NOT relaxed. Receipt:
`doc/claude/batch_F/receipts/19-issue-0319-primitive-fet-path.md`. Checks:
`tests/headless/test_wave_sigbrowser_0319.tcl` (35 checks, 25 sabotage rows).
**Area:** `src/ase.tcl` — `ase::show_in_browser_for_current`'s item-17 selection
step, which is what BUILDS the asked path.
**Found:** 2026-08-12, by the user, eyeballing two-pane **item 18**.
**Related:** two-pane item 18 (`18_receipt.md`, `6c887aed` + `91a3de1a`), item 13,
issue 0217 (the declass rule), issue **0321** (the MIRROR direction: "Descend to
here" refuses the very device row this fix now selects — filed by this work).

## What happens

```
xschem load {…/sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/schematic/tb_bandgap.sch}
```
then load `ngspice_state1`.

**The part that works.** Descend into `x1`, select `x1` on the bandgap
schematic, press **Ctrl-Alt-V** — the Signal Browser finds `x1` correctly.

**The part that did not.** Descend into `x1` (an instance of `bandgap_opamp`),
select a **FET such as `M18`** and press **Ctrl-Alt-V**: `Show device internals`
did not tick itself, and the navigator selected only `x1 > x1`.

Verbatim: *"if I then select a FET such as M18 and do CTRL-ALT-V, the Show device
internals does not get checked and it only selects x1 > x1 in the Signal Browser
navigator pane."*

## THE CAUSE — measured, and it is NOT the hypothesis this issue was filed with

⚠ **The original hypothesis — that a primitive contributes no path segment at
all — is REFUTED.** It does contribute one. It is spelled differently.

`tb_bandgap_ase.raw` (424 variables) carries exactly six names mentioning m18,
and no bare `m18` at all:

```
v(m.x1.x1.xm18.msky130_fd_pr__nfet_01v8_lvt#body)   (+ #dbody, #sbody)
v(m.x1.x2.xm18.msky130_fd_pr__nfet_01v8_lvt#body)   (+ #dbody, #sbody)
```

sky130's FET symbols format their element line `@spiceprefix@name …` with
`spiceprefix=X`, so a FET **drawn** `M18` is **netlisted** `XM18`
(`tb_bandgap_ase.spice:110`) and ngspice lower-cases the raw to **`xm18`**.
xschem states the rule itself at `src/token.c:4435`:
`i(\@m.@path@spiceprefix@name\.msky130_fd_pr__@model\[id])`.

The gesture asked for the **schematic's** spelling. `ase::browser_sel_segment`
answers `{ok M18}` (its documented contract: the schematic's own spelling,
verbatim), so `segs` was `{x1 x1 M18}` — and `browser_node_for` matches `M18`
against the tree's `xm18` row neither exactly nor `-nocase`. `matched` stalled
at 2 of 3.

**Item 18's `==` probe was therefore right, and right for the right reason:**
with internals shown the asked path still did not resolve, so `pmatched` was 2
and the box correctly stayed unticked. Measured, both models built from the real
raw through the shipped procs:

| rows | `{x1 x1 M18}` | `{x1 x1 XM18}` |
|---|---|---|
| internals hidden | `g:x1.x1`, 2 of 3 | `g:x1.x1`, 2 of 3 |
| internals shown  | `g:x1.x1`, 2 of 3 | **`g:x1.x1.xm18`, 3 of 3** |

**Descending is scenery.** `test_nfet_final` has its FET at the TOP level with
no descend at all, drawn as plain `name=M1 W=1 L=0.15 nf=1` — no spiceprefix
token of its own, inherited from the symbol template — and it is netlisted
`XM1`. Same mismatch, zero descends. (⚠ Both sky130 and gf180 ship a cell of
that name; the raw in `~/.xschem/simulations/`, whose first variable is
`i(@m.xm1.m0[id])`, is **gf180's** — its Title line says so.) What decides the
outcome is whether the SELECTED instance carries a spiceprefix, not how deep it
sits.

## The fix

`ase::inst_path_segment` asks the netlister what the instance is called —
`xschem translate <inst> {@spiceprefix}`, which honours both the symbol-template
fallback and the global `spiceprefix` switch — and `ase::spice_seg_name` applies
it only when the format string actually consumes `@spiceprefix` (otherwise
`devices/netlist_options`, which carries `spiceprefix=true` and no format, would
be asked for as `trueNETLIST_OPTIONS`). The call site appends that instead of
`$selname`; `$selname` itself is unchanged, because step 3c's digital probe and
6b's sentence both need the schematic's spelling.

Three further properties came from adversarial review and each was a live
defect in the first cut (receipt §5):

* the ACTIVE format attribute is used — **`lvs_format` when `lvs_netlist` is
  on** — because 54 in-repo symbols (gf180mcu_pr, sg13g2_pr) disagree with
  `format` about `@spiceprefix`, and under LVS the prefix must NOT be applied;
* the format is read with **`getprop instance_notcl`**, because the plain
  accessor EXECUTES a `tcleval(...)` format — and one shipped symbol's format
  is `tcleval([::analyses::netlister spice])`;
* an **all-digit instance name is refused**, because `get_instance` reads one as
  an index and would silently answer about a different device.

⚠ **The `==` in `browser_show_path`'s R12 probe was NOT relaxed, and must not
be.** `BK43` guards it and `BN36` re-measures it from the 0319 side. `BN32`
guards the other wrong fix: teaching `browser_node_for` to guess an `x` prefix
reds it (sabotage S16).

## THE EYEBALL THAT IS STILL OWED

Everything above is widget state and returned values. Nobody has watched the
box tick. From **ASE-L**:

1. Open the bandgap testbench: **File > Open**, or the Library Manager, and pick
   library `sky130_tests_ase`, cell **tb_bandgap**, view **schematic**.
2. Load the saved ASE state: the cell's **ngspice_state1** view. (No re-simulation
   is needed if `~/.xschem/simulations/tb_bandgap_ase.raw` is still there; if it
   is not, run the state's TRAN analysis once so a raw exists.)
3. Open the waveform viewer and make sure the **Signal Browser** sidebar is
   showing, with **`Show device internals` UNTICKED** (that is the default —
   untick it by hand if a previous session left it on).
4. Back on the schematic: click `x1`, **descend** (`e`). Click `x1` again (the
   `bandgap_opamp` instance) and **descend** again. You are now inside
   `bandgap_opamp` and the title bar says `x1.x1`.
5. Click the FET labelled **`M18`** — one single instance selected, nothing else.
6. Press **Ctrl-Alt-V**.

**Expected, and this is the whole issue:**
* `Show device internals` **ticks itself**, and the tree grows.
* The navigator selects and scrolls to **`x1 > x1 > xm18`** — note the tree's
  spelling is the raw's, `xm18`, not the schematic's `M18`.
* The CIW shows **one** line, not red:
  `ase: signal browser: showing device internals to reach x1.x1.xm18`
* The lower pane lists that device's own signals (`…#body`, `#dbody`, `#sbody`).

**The control, in the same sitting:** press `Ctrl-Shift-E` / go back up one
level, select the subcircuit `x1`, Ctrl-Alt-V. It must land on `x1 > x1` with the
box **still unticked** and say `ase: signal browser: showing x1.x1`. If that
regressed, the fix over-applied.
