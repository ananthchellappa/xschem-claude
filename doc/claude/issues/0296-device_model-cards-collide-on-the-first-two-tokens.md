# 0296 — two different `device_model` attributes silently collapse to one `.model` card

Status: OPEN
Filed: 2026-08-08, measured during the section-E recon of
`doc/claude/specs/mixed_signal_signal_browser.md`
Component: `src/spice_netlist.c` (and the parallel copy in `src/spectre_netlist.c`)

## Symptom

Two instances carrying **different** `device_model=` strings emit only **one** `.model`
card when the two strings agree in their first two tokens. The other card is dropped with
no warning, so one of the devices silently simulates with the other's model parameters.

Measured (headless netlist of a two-instance fixture):

| instance | `device_model` | emitted |
|---|---|---|
| `x5` | `.model mC nmos level=FIRST` | — |
| `x6` | `.model mC nmos level=LAST`  | `.model mC nmos level=LAST` |

Same collapse for case (`.model MA nmos …` vs `.model ma nmos …`) and for whitespace
(`.model   sp    nmos    manyspaces=1` vs `.model sp nmos onespace=2` → only the second).

## Root cause

`model_name()` (`src/spice_netlist.c:143-169`) builds the hash key from **only the first
two whitespace-separated tokens** after `.model` / `.subckt`, lowercased and concatenated:

```c
} else if((ptr = strstr(m_lower, ".model"))) {
    n = sscanf(ptr, ".model %s %s", model_name_result, modelname);
...
if(n<2) my_strncpy(model_name_result, m_lower, l);
else    my_strcat(_ALLOC_ID_, &model_name_result, modelname);   /* key = tok1+tok2 */
```

so `.model mC nmos level=FIRST` and `.model mC nmos level=LAST` both key on `mcnmos`.
Insertion is `XINSERT` (`:232`, `:239`), whose documented contract is
"update value if not NULL" (`:733-734`, implementation `:780-782`) — i.e. **last writer
wins**, silently. `subckt_table` next to it deliberately uses `XINSERT_NOREPLACE` (`:94`).

The dedup itself is correct and wanted: the key is whitespace- and case-insensitive
precisely so that the *same* model written with different spacing is emitted once (the
comment at `:163` says so). What is missing is the distinction between "same model,
different formatting" and "different models, same name".

## Why it matters

A `.model` name IS the identity a device instance references (`m1 d g s b nch` names
`nch`), so two different definitions of one name are a user error — but a silent one.
The netlister is the only place that can see both. In mixed-signal decks the payload is
larger than a parameter: a `d_cosim` card carries `simulation=` and `sim_args=`, so a
collapse silently redirects a code block to another block's shared object and VCD.

## Fix sketch (not implemented)

- Keep the key, but compare the *value* on collision: when `XINSERT` would replace an
  existing entry whose value differs by more than whitespace, print a `dbg(0, ...)`
  warning naming both strings, and keep the first (matching `subckt_table`'s
  no-replace policy).
- The whitespace-insensitive comparison already exists in spirit; normalize both values
  through the same collapse before comparing so the intended "same card, different
  spacing" case stays silent.
- `src/spectre_netlist.c:49,113-125,461-471` carries the same structure and needs the
  same treatment.

## Evidence

Measured 2026-08-08 on this tree with headless netlists of purpose-built fixtures; the
reference case that motivated the recon is
`xschem_libraries_oa/ngspice_verilog_cosim_ase/tb_counter_wrapper`, whose single
`device_model` hashes to `counterd_cosim`.
