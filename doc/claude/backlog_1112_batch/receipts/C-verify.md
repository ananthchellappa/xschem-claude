# Stage C verifier receipt: more device limits

Adversarial verifier crew, 2026-11-12. I attacked the uncommitted stage C tree (receipt
`C-devlim.md`) on top of HEAD d67644607. Nothing is committed.
- Every xschem run had `unset DISPLAY`.
- The only display I used was my own Xvfb `:283` plus openbox. I killed both by pid
  afterwards. I never used `:99` and ran no T1.
- After every sabotage I restored the file with `cp` and proved the restore with `cmp`. After
  each C change I re-ran `make -C src`.

**Verdict:** I found no product defect. I found one coverage defect: four of the cited limits
had no row that would fail without them. I fixed it in the test file only.

## 1. Each limit against its cited source

| limit | source checked | result |
|---|---|---|
| IHP rsil/rppd w, l ≥ 0.5u; rhigh w ≥ 0.5u, l ≥ 0.96u | `sg13g2_res_drc`, the `rsil$\|rppd$` and `rhigh$` arms (`0.5e-6`, `0.96e-6`) | confirmed |
| IHP cap_cmim w ≥ 1.14u; area 1.3–5625 µm² not clamped | `sg13g2_mim_drc` | confirmed. The area window really is a w·l rule. |
| IHP cap_rfcmim w, l 7–75u; wfeed 1–30u | `ihp-sg13g2/models/capacitors_mod.lib`, the two `* Note:` lines above `.subckt cap_rfcmim`. The same lines are in `capacitors_mod_mismatch.lib`. | confirmed. Its symbol also calls `sg13g2_mim_drc` (w ≥ 1.14), which the 7u minimum already covers. |
| IHP units | Templates are SI (`w=0.5e-6`, `w=10.0e-6`). The provider unit is `u`, so `devlim::to_um` reads a bare number as metres. | consistent with the existing IHP FET provider |
| gf180 `_dss` W/L | I re-derived the bin extents from `models/sm141064.ngspice` (min/max of every `lmin/lmax/wmin/wmax` per model name). nfet/pfet_03v3: L 0.28–50u, W 0.22–100u. nfet_06v0: L ≥ 0.6u, W 0.3–100u. pfet_06v0: L ≥ 0.5u, W 0.3–100u. Each `.subckt *_dss` body instantiates `m0 … <plain model> l='l' w='w' nf=nf`. The subckt defaults are l=0.28u (3.3 V), l=0.6u (n 6 V) and l=0.5u (p 6 V). The symbol templates are 0.28u/0.22u, 0.28u/0.22u, 0.70u/0.30u and 0.50u/0.30u. | every figure confirmed |

**Repo data the implementer might have missed.** I found none that gives an R/C limit.
- **sky130:**
  - `models_resistors.spice` (`res_xhigh_po`, `res_high_po` and the rest) has only `w=1 l=1`
    defaults and effective-width equations.
  - The fixed-width `res_xhigh_po_0p35` (and the others like it) has only `L` in its template
    and no W token at all. Its subckt (`rescap/sky130_fd_pr__model__res.model.spice`) has
    `l=1` and no range.
  - `cap_mim_m3_1` has no range.
  - `cap_var_lvt/hvt.model.spice` has no bins, only `w=5 l=0.5` defaults.
  - The only `lmin/wmin` hits in sky130 models are FET, SONOS and `cap_vpp_*` bins. The vpp
    caps are fixed-size layouts, and the `vpp_cap` symbol is not a W/L device.
- **gf180:**
  - `ppolyf_*`, `npolyf_*`, `cap_mim_*` and `cap_[np]mos_*` subckts carry equations only, no
    range and no `.if`.
  - No gf180 symbol carries `drc=`.
  - `README.md` and `cadence_style_rc` hold no minimum or maximum.
- **Invented limits:** none.

## 2. The gf180 `_dss` ruling

The three conflicting figures are confirmed exactly as the receipt states them:

| L minimum | bins / subckt default | symbol default | plain 6 V rule (`gf180_fet_limits`) |
|---|---|---|---|
| nfet_06v0_dss | 0.6u | 0.70u | 0.7u |
| pfet_06v0_dss | 0.5u | 0.50u | 0.55u |

**What is clamped is settled.**
- 3.3 V pair: W and L minimums, where bin floor = symbol default.
- 6 V pair: W minimum 0.3u, where bin floor = symbol default.
- All `_dss` devices: W max 100u per finger and L max 50u, the outer bin edges.

**One nuance for the user's ruling (`gf180-dss-lmin`, already in the owed ledger; not taken
here).** For **pfet_06v0_dss** the receipt's own bracketing method does meet: bins, subckt
default and symbol default are all 0.5u. Only the plain-pmos design rule (0.55u) disagrees,
and that rule's source is not model data in this repo. For **nfet_06v0_dss** the method does
not meet: bins 0.6u, symbol 0.70u. So the user could rule the two devices separately, e.g.
"pfet 0.5u by the method, nfet asks". That is a refinement of the receipt's options (a)/(b)/(c),
not a contradiction of them. Leaving both unclamped, as now, is the safe state.

## 3. `xschem setprop instance`: one clamp, one warning, one undo step

I ran a hand probe headless (`--nogui --pipe -q --nolog --norecent`, throwaway HOME). It used
all three providers, with `ciw_echo` recorded. Every result below is as intended, and no
`tcleval(): … failed` line appeared on stderr.

| attack | result |
|---|---|
| `setprop instance 0 name M5` on an instance that already has an out-of-range `l=0.05u` | renamed, `l` untouched, no CIW line |
| `w {1u*0.01}` (expression), `w W` (parameter), `w {'Wn/10'}` | left as typed, silent |
| `setprop instance 0 w` (delete the token); `setprop instance 0` (clear all props) | no clamp, silent |
| instance with no provider (`devices/res.sym`, `w=0.001u`) | untouched |
| `w 1e-6` (same value, different spelling) | untouched, silent |
| two clamped setprops, then undo, undo, redo | `{0.13u 10u}` → `{0.13u 0.13u}` → `{1u 0.13u}` → redo `{0.13u 0.13u}`: one step per setprop, the clamp inside it |
| the command's result after a clamp | the instance name, as before |
| `namespace delete ::devlim`, then a setprop | no error, no clamp (the C guard `info procs ::devlim::clamp_edit`) |
| re-spelling an already-out-of-range value (`l 0.05U`) | clamped, one line. The token was changed by this edit, so this matches the form's rule. Toggle Case only touches labels, so no in-tree caller does this. |

Notes on the C side:
- **Build:** after `touch src/editprop.c src/scheduler.c`, `make -C src` gives no warnings or
  errors. The newly exported `devlim_clamp` appears only at its two call sites and the
  `xschem.h` declaration.
- **Callers:** every in-tree `setprop instance` caller I found sets a non-geometry token
  (`lab`, `voltage`, `current`, `schematic`, toggle-case `lab`). None of them can be newly
  clamped.
- **Action log:**
  - The self-log (`log_action_argv`) records setprop's argv, which is the requested value
    before the clamp.
  - A replay re-clamps to the same result where the PDK provider is loaded, and stays
    unclamped where it is not.
  - This is an observation, not a defect. The vi-edit path logs the prop string after the
    clamp, which is already in range.

## 4. Sabotages

**Re-runs of the receipt's own sabotages:**

| id | sabotage | result |
|---|---|---|
| S1 | delete the setprop `devlim_clamp` call | **red** 5: SP1 SP2 SP3 SP5 SP7. This matches the receipt once SP2 is tightened. |
| S7 | guess a 6 V `_dss` L minimum of 0.6 | **red** DL20 |

**My own, on the tree as delivered:**

| id | sabotage | result as delivered |
|---|---|---|
| V1 | drop cap_rfcmim's `l` maximum (`{l 7 {}}`) | **survived**, ALL PASS (29) |
| V2 | split `rsil - rppd` and drop rppd's `l` minimum | **survived** |
| V3 | split the 3.3 V `_dss` arm and drop pfet_03v3_dss's L minimum | **survived** |
| V4 | split it and drop nfet_03v3_dss's W minimum | **survived** |
| V5 | skip the setprop clamp for `allprops` only (C, rebuilt) | **red** SP5 |

V1–V4 are cited limits that no row exercised. DL15 checked rppd `w` only. DL18 checked the `l`
minimum but not the maximum. DL19 checked nfet L and pfet W, but not the other two.

**The fix, red first:** I widened three rows in `tests/headless/test_device_limits.tcl`. These
are new legs, not new rows, so check counts and `DLFLOOR` do not move.
- **DL15:** the rppd edit is `w 0.3u l 0.2u`, and the row expects 0.5u 0.5u.
- **DL18:** the second rfcmim edit is `wfeed 40u l 80u w 5u`, and the row expects 30u 75u 7u.
- **DL19:** both 3.3 V `_dss` devices get `L 0.1u W 0.1u`, and the row expects 0.28u 0.22u for
  each.

On the clean tree the suite reads ALL PASS (29). With each sabotage planted again:

| sabotage | result after the fix |
|---|---|
| V1 | **red** DL18 (`l` 80u kept) |
| V2 | **red** DL15 (`l` 0.2u kept) |
| V3 | **red** DL19 (`{0.28u 0.22u 0.1u 0.22u}`) |
| V4 | **red** DL19 (`{0.28u 0.1u 0.28u 0.22u}`) |

Every product file was restored, and `cmp` confirmed each one. The final suite runs are on
the restored tree.

**Vacuity check of the new rows.** Each input differs from its expected result, and every row
reads values back with `getprop`.
- DL21's tiny values (0.01, 1e-9, 1n) differ from the defaults.
- SP6 is a declared control.
- SP1 asserts the exact CIW sentence and tag, once.

## 5. test_annot_declutter_1244 row A22 is not stage C

- The row is a textual census of `text_hidden_inst(` in `src/draw.c`, `svgdraw.c`,
  `psprint.c` and `select.c`.
- None of those files is modified in this tree (`git status --short` is empty for them).
- **Measured:** `git show HEAD:src/<f>.c | grep -c 'text_hidden_inst('` and the working-tree
  count are equal for all four files, at 5/2/2/1, while the golden is `{4 2 2 1 0}`. Since the
  census reads only those bytes, HEAD gives the same red.
- `git log -S 'text_hidden_inst(' -- src/draw.c` puts the fifth draw.c call at **15b76baef**
  (issue 1623, vertical bus-label stacking), well before this batch.
- The display arm on `:283` gives `1 FAILED (133 passed)`, A22 only, the same as the receipt.
- The suite is in no T1 list (`grep -c annot_declutter tests/run_regression.tcl` → 0).
- **Not fixed: out of scope.** It is a stale census golden, or a missed site, from 1623. The
  driver may want an issue filed for it.

## Suites run (all through `run_suites.sh`, `AUDIT_DISPLAY=:283` or `none`)

| suite | arm | result |
|---|---|---|
| test_device_limits | counted `--nogui` | ALL PASS (29), plus the same `skip:` line naming FL0–FL11, before and after the widening |
| test_device_limits | display (`:283`, openbox) | ALL PASS (41), before and after the widening |
| test_prop_form_readonly | display (`:283`) | ALL PASS (7) |
| test_annot_declutter_1244 | display (`:283`) | 1 FAILED (133): A22, which predates this change (§5) |

## User rulings (described, not taken)

- **`gf180-dss-lmin`** (already filed by the implementer): the L minimum of nfet_06v0_dss and
  pfet_06v0_dss. §2 adds that the two devices could be ruled separately, since the pfet's repo
  data all agree on 0.5u.
