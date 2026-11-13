# Stage C receipt: more device limits

Implementer crew, 2026-11-12. Built on HEAD d67644607 (`devlim::corrections` + `devlim::say`,
the form's focus-out check). The limit rule was not copied: every new limit is provider data,
and the scripted edit reaches the same `devlim_clamp` → `devlim::clamp_edit` →
`devlim::corrections` that apply uses. Nothing committed. Every command ran with `unset DISPLAY`.
The only display I used was my own Xvfb `:271` + openbox, killed by pid. I never used `:99` and
ran no T1.

## Changes (by symbol)

- **`sg13g2_rescap_limits`** (new, `ihp-sg13g2/sg13g2_procs.tcl`). It is registered with
  `devlim::register` and keyed on the model, the way `sg13g2_res_drc`/`sg13g2_mim_drc` key on it.
  Unit is `u`.
- **`gf180_fet_limits`** (`gf180mcuD/gf180_procs.tcl`). Adds `nfet_03v3_dss`/`pfet_03v3_dss`
  (W 0.22–100 per finger, L 0.28–50) and `nfet_06v0_dss`/`pfet_06v0_dss` (W 0.3–100 per finger,
  L max 50, **no L minimum**). The comment above the proc is rewritten to say why.
- **`sky130_fet_limits` comment** (`sky130A/sky130_procs.tcl`): says why sky130 resistors and
  capacitors are not listed. The same note sits above `gf180_fet_limits`.
- **`devlim_clamp`** (`src/editprop.c`): `static` removed, declared in `src/xschem.h`. The comment
  now names its second caller.
- **`xschem setprop instance`** (`scheduler()`, `src/scheduler.c`):
  - It copies the property string before the edit.
  - Right after `new_prop_string()` it calls `devlim_clamp(inst, <after>, <before>)`. That is
    before `set_inst_flags`, the bbox and `draw()`, and inside whatever undo step the branch
    pushed. Undo is pushed by the plain form only, as before; `-fast` and `-fastundo` push none
    for instances.
  - All three spellings clamp, and so does `allprops`.
  - The command's help comment says so.
- **`tests/headless/test_device_limits.tcl`**:
  - DL0 now expects four providers.
  - New rows DL15–DL21 and SP1–SP7, listed in the header.
  - `DLFLOOR` raised to 29 headless and 41 on display.

## Every limit and its source

| device (model) | token: limit (µm) | source in this repo |
|---|---|---|
| IHP rsil, rppd | w ≥ 0.5, l ≥ 0.5 | `sg13g2_res_drc`, the `rsil$\|rppd$` arm |
| IHP rhigh | w ≥ 0.5, l ≥ 0.96 | `sg13g2_res_drc`, the `rhigh$` arm |
| IHP cap_cmim | w ≥ 1.14 | `sg13g2_mim_drc` |
| IHP cap_rfcmim | w, l 7–75; wfeed 1–30 | `ihp-sg13g2/models/capacitors_mod.lib`, the notes above `.subckt cap_rfcmim` ("valid parameter range for w and l: 7um to 75um", "for wfeed: 1um to 30um") |
| gf180 nfet/pfet_03v3_dss | W/nf 0.22–100, L 0.28–50 | `.subckt nfet_03v3_dss`/`pfet_03v3_dss` in `models/sm141064.ngspice` instantiate `m0 … nfet_03v3`/`pfet_03v3` at the same l, w. Those bins start at L 0.28u and W 0.22u and end at 50u and 100u. The symbols' templates default to L=0.28u W=0.22u. Bin edge = symbol default, so it is settled. |
| gf180 nfet/pfet_06v0_dss | W/nf 0.3–100, L ≤ 50 | Same wrapping (`m0 … nfet_06v0`/`pfet_06v0`). Every bin has wmin 0.3u, and the symbols default to W=0.30u. The L maximum is the bins' 50u. |

`devlim::corrections` compares a value against these limits per finger where a finger token is
given (W/nf for gf180), with a 1e-9 slack.

**Bracketing for the `_dss` devices.**
- Lower bound: below the inner device's bins ngspice has no model.
- Upper bound: the symbol's own default, taken to be legal.
- Where the two meet, the limit is settled. Where they do not, the token is left unclamped.

## Left unclamped: the repo cannot settle a limit

- **sky130 resistors and capacitors**, all of them (`res_*`, `cap_mim_m3_*`, `cap_var_*`,
  `vpp_cap`):
  - their symbols carry no `drc=`;
  - `models/libs.tech/combined/continuous/models_resistors.spice` and `models_capacitors.spice`
    state no range;
  - the `wmin*` parameters in `models_capacitors.spice` are widths of the parasitic-cap layers,
    not device limits;
  - `libs.ref/…/cap_var_*.model.spice` has no bins.
- **gf180 resistors and capacitors**, all of them:
  - no `drc=` on any gf180 symbol;
  - `sm141064.ngspice` and `sm141064_mim.ngspice` subcircuits state no range;
  - a case-insensitive search for valid/minimum/maximum over gf180's `models/*.spice` and
    `*.ngspice` hits only license text.
- **IHP cap_cmim area window**: area must be at least 1.3 µm² and at most 5625 µm²
  (`sg13g2_mim_drc`). That is a rule over w·l, and a single-token limit cannot express it. Which
  token to move is a design choice, so I did not invent it. Its `l` has no limit of its own. The
  `drc=` check still reports area.
- **IHP cap_rfcmim**: the coupled cap "maximum wfeed = w-1.2um" is not clamped. Only the 1–30
  window is.
- **IHP sg13_svaricap**: `sg13g2_svaricap_drc` allows exactly two (w,l) pairs, not a range. Nx is
  1..10, a count, which `devlim` units cannot express.
- **gf180 nfet_06v0_dss / pfet_06v0_dss L minimum**: an owed rule (below).

Row DL21 fences the "no limit" claims. A guessed limit reddens it (sabotage S8).

## Owed rule `gf180-dss-lmin` (recorded, not taken)

`tests/headless/owed.sh add rule gf180-dss-lmin "…" --ref <this file>`. I backed up the ledger
first to the session scratchpad `xschem_owed.bak.stageC`. Since this receipt is not committed
yet, `owed.sh list` shows the ref as "(not in this clone)".

**What the repo says:**

| | bins of the inner device (`sm141064.ngspice`) | subckt default | symbol default | plain 6 V rule (`gf180_fet_limits`) | 5 V rule |
|---|---|---|---|---|---|
| nfet_06v0_dss L | ≥ 0.6u | 0.6u | 0.70u | 0.7u | 0.6u |
| pfet_06v0_dss L | ≥ 0.5u | 0.5u | 0.50u | 0.55u | 0.5u |

The pfet's symbol default sits below the plain 6 V pmos rule. So either that default is illegal,
or the drain-SAB device has its own, smaller rule. Nothing in the tree says which.

**Options for the user:**
- **(a)** The 6 V rules: n 0.7u, p 0.55u. This matches the plain device. A pfet_06v0_dss placed
  at its own default L=0.50u would then be raised to 0.55u on its first L edit.
- **(b)** The bins' floor, which is also the 5 V rules and the subcircuit defaults: n 0.6u,
  p 0.5u. This is the least that still simulates.
- **(c)** Keep L's minimum unclamped (the current state). W and L-max are still clamped.

## Sabotages (each: copy, plant, run counted arm, restore with `cp`, `cmp` OK)

| id | sabotage | result |
|---|---|---|
| S1 | delete the `devlim_clamp` call in setprop | **red** 4: SP1 SP3 SP5 SP7 (SP2 was green, so I tightened it to assert the clamped value before undo) |
| S2 | `push_undo()` just before the setprop clamp (correction gets its own undo step) | **red** SP2 (`{0.13u 0.05u}`) |
| S3 | pass after-string as before-string (`devlim_clamp(inst,new,new)`) | **red** 5: SP1 SP2 SP3 SP5 SP7 |
| S4 | clamp before `new_prop_string()` instead of after | **red** 5: SP1 SP2 SP3 SP5 SP7 |
| S4′ | (accidental) clamp with an empty after-string | **red** SP4 (old out-of-range `l` touched) |
| S5 | `sg13g2_rescap_limits` not registered | **red** 5: DL0 DL15 DL16 DL17 DL18 |
| S6 | gf180 `_dss` arms removed | **red** DL19 DL20 |
| S7 | guess 6 V `_dss` L min 0.6 | **red** DL20 |
| S8 | guessed sky130 `res_high_po` limit | **red** DL21 |
| S9 | rfcmim `wfeed` rule dropped | **red** DL18 |
| S10 | rhigh given rsil's l=0.5 | **red** DL16 |
| S11 | guessed cmim `l ≥ 1.14` | **red** DL17 |
| S12 | 3.3 V `_dss` L left unsettled | **red** DL19 |

Not reddened by any sabotage: SP6 (a parameter left alone). It is a control. DL5 covers the same
predicate on the apply path. After every C sabotage `make -C src` was re-run, and the final build
has no warnings in the touched files.

## Suites run

| suite | arm | result |
|---|---|---|
| test_device_limits | counted (`--nogui`, `AUDIT_DISPLAY=none` and `=:271`) | ALL PASS (29), one `skip:` line naming FL0–FL11, as at HEAD |
| test_device_limits | display (`:271`, openbox) | ALL PASS (41) |
| test_prop_form_readonly | display (`:271`) | ALL PASS (7) |
| test_op_annot | counted | ALL PASS (486) |
| test_undo_link_symbols, test_pin_rename_propagate | counted | ALL PASS |
| test_calc_pick | display | ALL PASS (105) |
| test_annot_declutter_1244 | display | 1 FAILED (133): row A22 |

The A22 red on `test_annot_declutter_1244` is not stage C:
- it is a call-site census over draw/svg/ps/select (`{5 2 2 1 0}` against `{4 2 2 1 0}`), and
  none of those files is in this diff;
- the suite is in no T1 list;
- on the counted arm it reports NORESULT (it is display-only).

`test_shape_setprop_log` self-skipped on both arms ("no X — nothing ran"), even with `:271` up.
I did not investigate.

## Declared limits / not done

- Registration was unchanged: test_device_limits is already in hcases and dcases, so cases and
  blocks do not move. Only its published counts move (15 → 29 headless, 27 → 41 display).
- I did not reproduce the focus-out check (`slickprop::limits_check`) for the new devices by
  driving the form. It calls the same `devlim::corrections` over the same providers, and FL9
  fences that one-rule property.
- `xschem setprop -fastundo instance` pushes no undo at HEAD, despite the help text for other
  object kinds. I left that unchanged. The clamp rides whatever step exists.
