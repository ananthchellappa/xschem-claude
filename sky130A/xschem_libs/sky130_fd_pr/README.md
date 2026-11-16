# XSCHEM Device symbols for the Google-Skywater SKY130 Process Design Kit (PDK) 

## *Warning: This is currently Work in progress.*

This directory contains symbols to be used in the [XSCHEM](https://github.com/StefanSchippers/xschem)
schematic editor. For a quick XSCHEM introduction see this 
[presentation](https://xschem.sourceforge.io/stefan/xschem_man/tutorial_xschem_slides.html).<br>
These symbols represent the available silicon devices as documented on the 
[Skywater-pdk](https://skywater-pdk.readthedocs.io/en/latest/rules/device-details.html) website
in the `device details` section.

## GOAL

Provide a set of symbols that can be used to draw circuit schematics in XSCHEM.
Netlists in various target formats can be extracted for simulation or Layout vs Schematic checks.
The set of symbols is designed to correctly link to the Skywater PDK model files, allowing to
seamlessly simulate the circuit with SPICE simulators.
A good tutorial for starting with xschem and Sky130 pdk can be found
[here](https://github.com/bluecmd/learn-sky130/blob/main/schematic/xschem/getting-started.md). Thanks Bluecmd!

## SYMBOL DRAWINGS

Up to now this is the list of devices that have been created. There are a lot of missing devices,
as this is a work in progress and the whole PDK is evolving.

![Devices Drawings](doc/devices.svg)

---

## DEVICE LIST
| File name | Description |
| ----------- | ----------- |
| `diode.sym` |Diode used to describe various p-n junction between p-n wells and p-n diffusions|
| `lvsdiode.sym` |Diodes used for LVS matching ? or for parasitic|
| `nfet_01v8_lvt.sym` |1.8V low threshold N-type Fet|
| `nfet_01v8.sym` | 1.8V standard N-type Fet|
| `nfet_03v3_nvt.sym` |3.3V native threshold N-type Fet |
| `nfet_05v0_nvt.sym` |5V native threshold N-type Fet|
| `nfet_20v0.sym` |20V Vds, 5V Vgs N-type Fet|
| `nfet_20v0_zvt.sym` |20V Vds, 5V Vgs 'Zero threshold' N-type Fet|
| `nfet_20v0_iso.sym` |20V Vds, 5V Vgs N-type Fet in insulated p-well (uses deep nwell)|
| `nfet_20v0_nvt.sym` |20V Vds, 5V Vgs N-type Native Vth Fet in insulated p-well (uses deep nwell)|
| `nfet_g5v0d10v5.sym` |10.5V Vds, 5V Vgs N-type Fet|
| `nfet_g5v0d16v0.sym` |16V Vds, 5V Vgs N-type FET|
| `pfet_01v8_hvt.sym` |1.8V high threshold P-type Fet|
| `pfet_01v8_lvt.sym` |1.8V low threshold P-type Fet|
| `pfet_01v8.sym` |1.8V standard P-type Fet|
| `pfet_20v0.sym` |20V Vds, 5V Vgs P-type Fet|
| `pfet_g5v0d10v5.sym` |10.5V Vds, 5V Vgs P-type Fet|
| `pfet_g5v0d16v0.sym` |16V Vds, 5V Vgs P-type FET |
| `pnp_05v5.sym` |5V Vce PNP bipolar transistor|
| `res_generic_nd.sym` |N diffusion generic resistor|
| `res_generic_pd.sym` |P diffusion generic resistor|
| `res_generic_po.sym` |Generic Poly resistor|
| `res_high_po_0p35.sym` |High precision Poly resistor, 0.35um width|
| `res_high_po_0p69.sym` |High precision Poly resistor, 0.69um width|
| `res_high_po_1p41.sym` |High precision Poly resistor, 1.41um width|
| `res_high_po.sym` |High precision Poly resistor, custom size|
| `res_iso_pw.sym` |P-Well Poly resistor|
| `res_xhigh_po_0p35.sym` |High precision High resistivity Poly resistor, 0.35um width|
| `res_xhigh_po_0p69.sym` |High precision High resistivity Poly resistor, 0.69m width|
| `res_xhigh_po_1p41.sym` |High precision High resistivity Poly resistor, 1.41um width|
| `res_xhigh_po.sym` |High precision High resistivity Poly resistor, custom size|
| `cap_mim_m3_1.sym` |Metal3 Insulator Metal4 (MIM) capacitor|
| `cap_mim_m3_2.sym` |Metal4 Insulator Metal5 (MIM) capacitor|
| `vpp_cap.sym` |Vertical parallel plate metal capacitors|
| `cap_var_lvt.sym` |Variable capacitance (Varactor), LVT version|
| `cap_var_hvt.sym` |Variable capacitance (Varactor), HVT version|
| `vpp_cap.sym`     |Vertical Parallel Plate (VPP) capacitors|

## RESISTORS: SERIES SEGMENTS (`ns`)

Every `res_*` symbol has an `ns` attribute (default 1), the number of series
segments; `mult` is the number of parallel copies. `L` and `W` are those of one segment.

- `ns=10` on `R1` netlists ten instances `R1_1` .. `R1_10` in a chain through the
  internal nets `R1_s1` .. `R1_s9`, each with the instance's own `L`/`W`/`mult` and
  body net. `ns=1`, or no `ns` at all, netlists the single line these symbols always
  produced.
- A bussed instance works the same way, per bit: `R1[3:0]` at `ns=3` netlists
  `R1_1[3]` .. `R1_3[0]`, twelve devices, each bit's chain running through its own
  internal nets `R1_s1[3]`, `R1_s2[3]`, ... between that bit's two nets.
- The symbol's `R=` text is the total: one segment x `ns` / `mult`. An `ns=` text is
  shown only when `ns` is not 1.
- `ns` is kept a whole number, 1 or more: the property form (on leaving the field and
  on OK/Apply) and `xschem setprop` correct anything else, with a warning in the CIW.
  2.5 becomes 3, 0 becomes 1, and a parameter name or an expression goes back to the
  value the field held before. A count of devices has to be a number when the netlist
  is written; it cannot be a design variable.
- The expansion is done by `sky130_res_series` in `sky130_res.tcl`, in this library
  directory. Each resistor symbol loads that file by itself the first time it is
  netlisted, so `ns` works in any session that can find the symbol, whichever rc or
  PDK procs file it sourced (the sky130 workarea's `sky130_procs.tcl` sources it too,
  for the property-form extras). Keep `sky130_res.tcl` with the library if you copy it.
- An `ns` that still cannot be expanded is never netlisted as one plausible segment:
  the device is written with the model name prefixed `ns_not_expanded__`, under a
  comment line giving the reason, so the simulator stops on it. That is a value that
  got past the form (a sheet edited by hand) or `ns` > 1 with `sky130_res.tcl` missing.
- Names the expansion takes: instances `<name>_<k>` and nets `<name>_s<k>`. Another
  instance already named `R1_1` makes the simulator stop (duplicate device); a net
  the designer labels `R1_s1` would be shorted to that internal node, so do not use
  such a label on a sheet where `R1` has `ns` > 1.
- The fixed-width cells (`res_high_po_0p69`, `res_xhigh_po_1p41`, ...) take no `W`:
  their model wires the width itself. The property form shows it as a greyed
  "W (fixed)" row. A `W=` token left on such an instance by an older sheet is not
  used, not offered for editing and not removed. For another width use the custom-size
  cell (`res_high_po`, `res_xhigh_po`).
- The property form also has an "Import split" checkbox (`import_split=true` on the
  instance). It is a placeholder for layout import: nothing reads it yet, and it is
  neither drawn on the schematic nor netlisted.

## SYMBOL IMAGES

|   symbol image |   symbol image |   symbol image |   symbol image |
| ----           | ----           | ----           | ----           |
|![cap_mim_m3_1.svg](doc/cap_mim_m3_1.svg)|![nfet_20v0_zvt.svg](doc/nfet_20v0_zvt.svg)|![pfet_20v0.svg](doc/pfet_20v0.svg)|![res_high_po_0p35.svg](doc/res_high_po_0p35.svg)|
|![cap_mim_m3_2.svg](doc/cap_mim_m3_2.svg)|![nfet3_01v8_lvt.svg](doc/nfet3_01v8_lvt.svg)|![pfet3_01v8_hvt.svg](doc/pfet3_01v8_hvt.svg)|![res_high_po_0p69.svg](doc/res_high_po_0p69.svg)|
|![cap_var_hvt.svg](doc/cap_var_hvt.svg)|![nfet3_01v8.svg](doc/nfet3_01v8.svg)|![pfet3_01v8_lvt.svg](doc/pfet3_01v8_lvt.svg)|![res_high_po_1p41.svg](doc/res_high_po_1p41.svg)|
|![cap_var_lvt.svg](doc/cap_var_lvt.svg)|![nfet3_03v3_nvt.svg](doc/nfet3_03v3_nvt.svg)|![pfet3_01v8.svg](doc/pfet3_01v8.svg)|![res_high_po.svg](doc/res_high_po.svg)|
|![diode.svg](doc/diode.svg)|![nfet3_05v0_nvt.svg](doc/nfet3_05v0_nvt.svg)|![pfet3_20v0.svg](doc/pfet3_20v0.svg)|![res_iso_pw.svg](doc/res_iso_pw.svg)|
|![lvsdiode.svg](doc/lvsdiode.svg)|![nfet3_20v0.svg](doc/nfet3_20v0.svg)|![pfet3_g5v0d10v5.svg](doc/pfet3_g5v0d10v5.svg)|![res_xhigh_po_0p35.svg](doc/res_xhigh_po_0p35.svg)|
|![nfet_01v8_lvt.svg](doc/nfet_01v8_lvt.svg)|![nfet3_g5v0d10v5.svg](doc/nfet3_g5v0d10v5.svg)|![pfet3_g5v0d16v0.svg](doc/pfet3_g5v0d16v0.svg)|![res_xhigh_po_0p69.svg](doc/res_xhigh_po_0p69.svg)|
|![nfet_01v8.svg](doc/nfet_01v8.svg)|![nfet3_g5v0d16v0.svg](doc/nfet3_g5v0d16v0.svg)|![pfet_g5v0d10v5.svg](doc/pfet_g5v0d10v5.svg)|![res_xhigh_po_1p41.svg](doc/res_xhigh_po_1p41.svg)|
|![nfet_03v3_nvt.svg](doc/nfet_03v3_nvt.svg)|![nfet_g5v0d10v5.svg](doc/nfet_g5v0d10v5.svg)|![pfet_g5v0d16v0.svg](doc/pfet_g5v0d16v0.svg)|![res_xhigh_po.svg](doc/res_xhigh_po.svg)|
|![nfet_05v0_nvt.svg](doc/nfet_05v0_nvt.svg)|![nfet_g5v0d16v0.svg](doc/nfet_g5v0d16v0.svg)|![pnp_05v5.svg](doc/pnp_05v5.svg)|![vpp_cap.svg](doc/vpp_cap.svg)|
|![nfet_20v0_iso.svg](doc/nfet_20v0_iso.svg)|![pfet_01v8_hvt.svg](doc/pfet_01v8_hvt.svg)|![res_generic_nd.svg](doc/res_generic_nd.svg)|
|![nfet_20v0_nvt.svg](doc/nfet_20v0_nvt.svg)|![pfet_01v8_lvt.svg](doc/pfet_01v8_lvt.svg)|![res_generic_pd.svg](doc/res_generic_pd.svg)|
|![nfet_20v0.svg](doc/nfet_20v0.svg)|![pfet_01v8.svg](doc/pfet_01v8.svg)|![res_generic_po.svg](doc/res_generic_po.svg)|

