# Finding refactoring fruit for readability / maintainability / extensibility

A repeatable method for locating and prioritizing refactoring targets aimed at
**readability, maintainability, and extensibility (R/M/E)** — distinct from the
earlier coupling-focused "un-hairball" pass (see
`refactor_plan_util_extraction.md`). Grounded in a real scan of xschem.

## Key framing

Size is the loudest signal but not the fruit. The **lowest-hanging** target is
where *big-and-ugly* meets *safe-and-mechanical*. Score every candidate as:

    priority = (R/M/E gain)  ÷  (risk)

where **risk** comes from the coupling/risk-map in `doc/claude/code_analysis/callgraph/`
(safe seams vs. the hostile core), not from gut feel.

## The discovery method (repeatable)

| Step | Signal | How to measure | Tool |
|---|---|---|---|
| 1 | Size | functions >200 lines, files >3k | `doc/claude/code_analysis/callgraph/hotspots.py` |
| 2 | Nesting / complexity | max brace depth, branch count | `hotspots.py` |
| 3 | Duplication | near-parallel function families (copy-paste extensibility tax) | diff sibling functions (`*_element`, `global_*`) |
| 4 | Extensibility friction | "add one X ⇒ edit N places" (commands, keys, formats) | dispatcher + `doc/claude/code_analysis/menu_inventory/` |
| 5 | Risk gate | candidate in a safe seam or the hostile core? | call-graph risk map |
| 6 | Mechanical-extractability | splittable by pure helper-extraction, no shared-state entanglement? | read the function |
| 7 | Validate | behavior-preserving? | `tests/headless/run.sh` |

Re-run `hotspots.py` after each refactor to watch the hotspot list shrink.

## What the scan found (snapshot)

```
 6752  xschem()              scheduler.c   command dispatcher (1462 branches)
 1596  handle_key_press      callback.c    keysym chain
  993  waves_callback        callback.c
  924  Tcl_AppInit           xinit.c       startup, runs once
  835  translate             token.c       (nest 10)
  790  load_sym_def          save.c
  500  plot_raw_custom_data  save.c
 ~360  global_{spice,spectre,vhdl,verilog}_netlist   near-parallel
 ~340  print_{spice,spectre,tedax,vhdl,verilog}_element [token.c]  near-parallel
```
39 functions > 200 lines; 111 > 100; deepest nesting depth 12 (`sym_vs_sch_pins`).

## Prioritization (size × risk gate)

**High value, NOT low-hanging (defer — high risk/effort):**
- `xschem()` dispatcher and `handle_key_press` — biggest R/M/E + extensibility
  wins, but they are control-flow spines. These want the declarative *action
  table* approach (`ui_refactor_first_move.txt`), not a quick split.
- `translate`, `print_*_element` — `token.c` is the measured spine; touch with care.

**Genuinely low-hanging (big × isolated × mechanical):**
- **`Tcl_AppInit` (xinit.c, 924)** — startup, runs once, low fan-in. Pure
  extract-into-named-helpers. Near-zero risk; large readability win. (Safest warm-up.)
- **`load_sym_def` (790) / `plot_raw_custom_data` (500) in save.c** — large but
  self-contained; decompose into stages.
- **`global_{spice,spectre,vhdl,verilog}_netlist`** — four ~360-line *near-parallel*
  functions in the **safe backend seam**. Factoring their shared skeleton is the
  best **extensibility** fruit (add-a-format becomes cheap, fix-once). Lower risk
  than the token.c `print_*` siblings because they live in isolated backend files.

## Recommended first move

> **Deep-read refinement (step 6 applied to the top candidates).** Reading the
> code revised the ranking — which is the whole point of confirming before
> committing:
>
> - The **`global_*_netlist` cluster** is the highest *extensibility* value but is
>   **NOT low-hanging-mechanical**. The format-specific differences are interwoven
>   line-by-line (`****` vs `////`, `print_spice_element` vs `print_spectre_element`,
>   `device_model` vs `spectre_device_model`, `model_table` vs `spectre_model_table`).
>   Unifying them needs a *designed abstraction* (a format-descriptor struct of
>   strings + callbacks), not a pure move. Real value, **medium** effort/risk.
> - **`Tcl_AppInit` (xinit.c, 924)** is the genuine **lowest-hanging mechanical**
>   target: a flat, linear init sequence the author already split into commented
>   phases (`SHAREDIR DETECTION`, `SOURCE xschemrc`, `LOOKING FOR xschem.tcl`,
>   `EXECUTE xschem.tcl`, …). Each block → one `static` helper. Near-zero risk.
>   Value is **readability/maintainability** (it is startup code — rarely extended).
> - `load_sym_def` is a recursive, stateful parser (`lcc[level]`) — medium, less
>   clean than `Tcl_AppInit`.

There is a real tension: lowest-risk (`Tcl_AppInit`) ≠ highest-extensibility-value
(`global_*`). No single target is both trivially mechanical *and* a big
extensibility win.

Suggested sequence:
1. **`Tcl_AppInit`** — safe warm-up that proves the decomposition loop on this
   codebase (extract each commented phase into a named `static` helper).
2. **`global_*_netlist` unification** — the extensibility play, as a deliberately
   *designed* refactor (format-descriptor), with the harness as the safety net.

Either way, iterate the same loop used for the utility extraction:
**plan doc → pure extraction → build → harness → commit.**
