# sky130_fd_sc_hvl SPICE deck: provenance

- Upstream: https://github.com/google/skywater-pdk-libs-sky130_fd_sc_hvl
- Branch `main`, commit `4fd4f858d16c` (2020-11-04T07:47:11Z)
- License: Apache-2.0 (`LICENSE`, the upstream text)
- `spice/sky130_fd_sc_hvl.spice` is the concatenation of upstream
  `cells/*/sky130_fd_sc_hvl__*.spice` in file-name order, unmodified
  (69 `.subckt`). This is the same file open_pdks installs at
  `libs.ref/sky130_fd_sc_hvl/spice/sky130_fd_sc_hvl.spice`.
- Cell dimensions such as `w=1.5e+06u` are correct as written: the vendored
  models set `.option scale=1.0u`
  (`libs.tech/combined/continuous/models_global.spice`).

## Edits to the upstream text

The deck is the concatenation above with exactly three device-name lines changed,
because the upstream cell netlists name three legacy devices that the vendored
models (`libs.tech/combined`) do not define as subcircuits:

| cell | upstream | here |
|---|---|---|
| `diode_2` | `X0 VNB DIODE ndiode_h p=… a=…` | `X0 VNB DIODE sky130_fd_pr__diode_pw2nd_11v0 perim=… area=…` |
| `schmittbuf_1` | `X2 … mrdn_hv w=… l=…` | `X2 … sky130_fd_pr__res_generic_nd__hv w=… l=…` |
| `schmittbuf_1` | `X3 … mrdp_hv w=… l=…` | `X3 … sky130_fd_pr__res_generic_pd__hv w=… l=…` |

`ndiode_h` is a `.model` (not a subcircuit), and `sky130_fd_pr__diode_pw2nd_11v0`
in `continuous/models_diodes.spice` is the wrapper that instantiates exactly that
model with `area`/`perim`. The two resistors are the HV n/p-diffusion resistor
subcircuits in `rescap/sky130_fd_pr__model__res.model.spice`, with the same
`t1 t2 body` port order and `w`/`l` parameters. `conb_1`'s `short` needs no edit:
that file defines `.subckt short`. Unedited, ngspice stops on
`unknown subckt: … ndiode_h` for any netlist that places `diode_2`.

Checked 2026-11-10 with an `op` over one instance of each of the 69 cells, supplies
tied (3.3 V, 1.8 V on LVPWR) and inputs grounded: it converges, and the outputs
are the expected logic levels.
