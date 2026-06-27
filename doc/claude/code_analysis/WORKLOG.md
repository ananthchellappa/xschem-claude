# Worklog & decision log

A narrative record of the analysis/tooling effort in this repo and the
decisions behind it — the things that flat commit messages and git ref
operations don't preserve. Dates: 2026-06-01 → 2026-06-03.

## Why this exists

The conclusions of the analysis live in `doc/claude/code_analysis/*.txt` and in the three
commit messages, but the *journey*, the *rationale*, and all the *git/publishing
decisions* were otherwise only in the working session. This file captures them.

## Analysis chain (each step motivated the next)

1. **Coding style** (`opinion1.txt`) — judged the codebase as competent,
   experienced, single-author, domain-expert C (not modern small-module style).
2. **Orthogonality** (`orthogonality_analysis.txt`) — measured coupling:
   14.6k `xctx->` refs, ~1.9k C↔Tcl bridge calls. Verdict: *horizontally
   orthogonal (clean pluggable seams: netlist backends, renderers) but
   vertically coupled* through the shared `xctx` god-struct.
3. **Call graph** (`callgraph/`) — built a heuristic function-level extractor
   (`analyze.py`). Key correction: 60% of cross-file calls are leaf-utility
   noise (`my_*`, `tcl*`, `dbg`); stripping it shows **`token.c` is the true
   spine** (the property/token subsystem), not `editprop.c`.
4. **Layering** (`layered.py`) — SCC-condensed the call graph. Finding: at full
   strength the core is **one 17-file cycle of thin back-edges**; raising the
   edge floor peels it into a clean DAG by ~50 calls. The dominant flow is a
   real driver→service hierarchy.
5. **UI first move** (`ui_refactor_first_move.txt`) — given a goal of adding
   ease-of-use UI features, recommended a **declarative action table** as the
   first refactor, because it sits on the low-risk Tcl seam (no `xctx`, no
   `token.c`, no editing-core cycle).
6. **Menu inventory** (`menu_inventory/`) — extracted the **242 menu items**
   (221 real actions) into a draft action table; ~70% map directly to a
   registry, 43 inline scripts need extraction into named procs first.

Also built: a hermetic **headless test/repro harness** (`tests/headless/`),
proven to catch regressions, and **`CLAUDE.md`** (build/test/architecture guide).

## Key decisions and rationale

| Decision | Choice | Why |
|---|---|---|
| Verify the harness, not assume | layered checks + injected regression | exit-0 alone would pass even if `netlist` no-op'd; only checking the written artifact proves it works |
| Call-graph tool | custom Python heuristic | no `cflow`/`ctags` available; column-0 anchoring beat fighting clang's include setup |
| First UI refactor | declarative action table | lowest blast radius per the risk map; foundation every later UI feature (palette, custom shortcuts, generated help) builds on |
| What NOT to do first | leave `callback.c` keysym chain, don't split `xschem.tcl`, don't touch `xctx`/mirrored vars | high value but high risk / cosmetic-first / out-of-scope for short-term UI work |

## Git & publishing operations (leave no commit trail — recorded here)

- **Work committed** in 3 commits on top of upstream `f276d0cf`: CLAUDE.md;
  the headless harness; the analysis + tooling + menu inventory.
- **Author identity**: set repo-locally to `Ananth Ch
  <ananth.chellappa@outlook.com>`. An earlier identity
  (`ananth.ch@gmail.com`) was used by mistake, then the 3 commits were
  **reauthored** (rebase `--reset-author`) so the gmail address appears nowhere.
  *Caveat acknowledged: the outlook email is public in history once pushed.*
- **Remotes**: `origin` → upstream xschem on Codeberg
  (`codeberg.org/stef_xschem/xschem.git`); `github` → personal copy
  (`github.com/ananthchellappa/xschem-claude.git`).
- **Publish decisions**: new repo `xschem-claude`, **public**, containing the
  **full xschem history + this work** (a GPLv2 fork-by-copy; LICENSE intact,
  original authorship preserved).
- **Branches**: local work branch renamed `claude/codebase-analysis-and-harness`
  → **`main`** (tracks `github/main`). Local `master` left at upstream tip,
  tracking `origin/master` (Codeberg) for pulling future xschem updates.

## Open next steps

- Promote `menu_inventory/menu_items.csv` into a real `actions.tcl` (+ `id`,
  `help` columns); convert the File menu to generate from it as a proof-of-PR.
- Extract the 43 inline menu-command scripts into named procs.
- Fold the 4 runtime menu builders (`context_menu`, `tab_context_menu`,
  `setup_recent_menu`, `reconfigure_layers_menu`) into the same registry later.
- Phase 2 (higher risk): migrate the `callback.c` keysym chain onto the table.
