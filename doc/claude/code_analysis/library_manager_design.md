# Library Manager — Design & Decision Record

Branch: `library-manager` (off `feature/hover-highlight`).
Status: **Phase 0 — awaiting ratification.** No engine code written yet.
Author: design session 2026-06-15.

This document is the single source of truth for the "libraries / cells / views"
refactor. It captures the model, the ratified decisions, the reference grammar,
the backward-compatibility contract, and the RED-first phase plan. Implementation
does not begin until the user signs off on this document.

---

## 1. Problem

Managing schematics and symbols in xschem today is cluttered with poor UI/UX. The
root cause is that **there is no library/cell/view data model** — the concepts a
custom-IC designer thinks in (Cadence DFII / OpenAccess: *Library → Cell → View*)
simply do not exist in the tool. What exists instead:

- A **"library" is a bare directory** placed on a colon-separated search path
  (`XSCHEM_LIBRARY_PATH`). The default list (~13 entries) is hard-wired at build
  time in `scconfig/hooks.c:157-232` and materialised into `Makefile.conf` and
  `config.h`. Users extend it by appending paths in `xschemrc`.
- A **"cell" is a filename stem**. `examples/cmos_inv.sch` and
  `examples/cmos_inv.sym` are conceptually one cell ("cmos_inv") with two views,
  but nothing in the code represents that relationship — they are two files that
  share a basename and live in the same directory.
- A **reference is a bare relative path string**. Instance lines read
  `C {nmos4.sym} ...` or `C {devices/res.sym} ...`. Resolution
  (`abs_sym_path`, `src/xschem.tcl:9015`) concatenates each search-path entry
  with the string and returns the first file that exists. Saving
  (`rel_sym_path`, `src/xschem.tcl:8964`) strips a recognised path prefix back
  off so the stored reference is portable.
- The **GUI is two competing flat-listbox browsers** — the legacy
  `load_file_dialog` (`src/xschem.tcl:4920`) and the newer `file_chooser`
  (`src/xschem.tcl:5861`). Both show `.sch` and `.sym` jumbled in one list,
  expose raw filesystem paths, duplicate search/fuzzy/filter controls with
  different metaphors, and bury library-path editing in a secondary dialog.

The fix is to **introduce a real Library/Cell/View model**, keep the file record
format byte-identical, lay the directories out as close to OpenAccess/Cadence as
practical, ship migration tooling, migrate the repo's own libraries, and build a
Cadence-style Library Manager on top of the new model.

---

## 2. The chokepoint that makes this feasible

All reference resolution funnels through **two Tcl procs**, each with a thin C
wrapper:

- `abs_sym_path {fname {ext} {paths}}` — `src/xschem.tcl:9015`; C wrapper
  `actions.c:375`. Reference string → absolute file path (search-path iteration).
- `rel_sym_path {symbol {paths}}` — `src/xschem.tcl:8964`; C wrapper
  `actions.c:385`. Absolute path → portable reference string (prefix stripping).

`save.c` calls `rel_sym_path` when writing instance lines (`save.c:2872-2879`);
`load_sym_def` (`save.c:4257`) and the descend logic (`actions.c:2181-2274`) call
`abs_sym_path` when reading. Because resolution is centralised in these two procs,
the library model can be introduced **behind them** with the C engine essentially
unchanged. The `.sch`/`.sym` record grammar (`XSCHEM_FILE_VERSION "1.3"`,
`xschem.h:27`) is **not** touched.

---

## 3. Target model

Three concepts, mapped onto the filesystem the OpenAccess/DFII way:

| Concept | Cadence / OA | xschem (this design) |
|---|---|---|
| **Library** | name → path in `cds.lib` (`DEFINE`); dir tagged `cdsinfo.tag` | name → path in `library.defs` (`DEFINE`); dir tagged `library.tag` |
| **Cell** | a directory in the library | `<libdir>/<cell>/` |
| **View** | subdir `schematic/`, `symbol/`, `layout/` … | `<cell>/schematic/`, `<cell>/symbol/` |
| **Datafile** | `sch.oa`, `symbol.oa` | `<cell>/schematic/<cell>.sch`, `<cell>/symbol/<cell>.sym` |

### 3.1 Before / after (grounded example)

`examples/cmos_inv` is a cell with both views that cross-references primitives in
`devices` (`nmos4`, `pmos4`, `lab_pin`, …):

```
BEFORE (flat)                          AFTER (lib / cell / view)
xschem_library/                        xschem_library/
  examples/                              examples/                 ← library "examples"
    cmos_inv.sch                           library.tag             ← marks + names the library
    cmos_inv.sym                           cmos_inv/               ← cell
  devices/                                   schematic/cmos_inv.sch
    nmos4.sym                                symbol/cmos_inv.sym
    pmos4.sym                            devices/                  ← library "devices"
    lab_pin.sym                            library.tag
                                          nmos4/symbol/nmos4.sym
# inside cmos_inv.sch:                     pmos4/symbol/pmos4.sym
C {nmos4.sym}   ...                        lab_pin/symbol/lab_pin.sym
C {pmos4.sym}   ...
C {lab_pin.sym} ...                    # inside schematic/cmos_inv.sch:
                                       C {devices/nmos4}   ...     ← lib-qualified; view=symbol implied
                                       C {devices/pmos4}   ...
                                       C {devices/lab_pin} ...
```

### 3.2 The registry (`cds.lib` analog)

One authoritative file the user edits in a single place:

```
# library.defs
DEFINE devices   ${XSCHEM_SHAREDIR}/xschem_library/devices
DEFINE examples  ${XSCHEM_SHAREDIR}/xschem_library/examples
DEFINE mylib     ~/projects/mylib
```

Plus a per-library self-description so a directory is recognisable on its own and
auto-discoverable from the existing search path (bridges the old "just add it to
the path" habit):

```
# <libdir>/library.tag
NAME devices
# (room for future metadata: tech, readonly, description, ...)
```

---

## 4. Ratified decisions

Confirmed by the user on 2026-06-15.

| # | Decision | Choice | Rationale |
|---|---|---|---|
| D1 | Datafile naming in a view dir | **Cell-named**: `<cell>/symbol/<cell>.sym`, `<cell>/schematic/<cell>.sch` | Files stay self-identifying; `get_cell` basename logic, logging and grep keep working; the directory tree alone already delivers the Cadence look. (Rejected: Cadence-pure generic `symbol/symbol.sym`.) |
| D2 | Reference syntax in `.sch` | **Lib-qualified**: `C {devices/nmos4}`, view inferred (symbol to instantiate, schematic to descend) | Location-independent via the registry; slick inside the file; legacy `{nmos4.sym}` still resolves via fallback. (Rejected: full view path `{devices/nmos4/symbol/nmos4.sym}`.) |
| D3 | Library registration | **`library.defs` (authoritative) + per-library `library.tag`** | One-place `cds.lib`-style edit; tag lets a dir self-identify and be auto-discovered from the search path. (Rejected: defs-only.) |
| D4 | File-format version | **No bump** | Record grammar untouched; references are just strings. `XSCHEM_FILE_VERSION` stays `"1.3"`. |

### 4.1 Reference grammar (normative)

A reference inside a `C {...}` instance line is resolved in this order:

1. **Absolute path** (`/...` on Unix, `X:/...` on Windows) or **URL** → used as-is.
2. **Lib-qualified** `lib/cell` where `lib` is a name defined in `library.defs`
   (or an auto-discovered tagged dir) → resolve to
   `<libpath>/<cell>/<view>/<cell>.<ext>`, where `view`/`ext` are inferred from
   the calling context: **symbol** (`.sym`) for instantiation/symbol lookup,
   **schematic** (`.sch`) for descend, with the `schematic=` attribute overriding
   the descend target.
3. **Legacy flat fallback** — the *exact current behaviour*: iterate
   `XSCHEM_LIBRARY_PATH` and return the first `<pathentry>/<reference>` that
   exists. This catches old `{nmos4.sym}`, `{devices/res.sym}`, and any path that
   is not a `lib/cell` under a known library.

`rel_sym_path` (save side) inverts this: an absolute path under a known library
becomes `lib/cell`; an absolute path under a legacy flat search dir keeps its
current relative form; anything else stays absolute. Saving must **not** rewrite
a reference that already round-trips, to avoid churning untouched files.

---

## 5. Backward-compatibility contract (the spine)

Non-negotiable, enforced by tests in every phase:

1. **Flat libraries keep working.** A directory of `*.sym`/`*.sch` on
   `XSCHEM_LIBRARY_PATH` with no `library.tag` resolves exactly as today (rule 3).
2. **Old `.sch` files keep working.** `{nmos4.sym}` / `{devices/res.sym}`
   references resolve unchanged. No flag day, no required migration to open an old
   design.
3. **No format bump.** Old xschem can still read files saved by new xschem unless
   the file actually uses a new lib-qualified reference (which old xschem would
   then fail to resolve — documented, expected, and only happens after a user
   migrates *and* re-saves).
4. **Mixed mode is legal.** A single schematic may contain both lib-qualified and
   legacy references during incremental migration.
5. **Resolution is additive.** New rules (1→2) are tried first; on miss, fall
   through to the legacy search (3). A new behaviour never removes an old one.

Every GREEN in this project is **sabotage-verified** (disable the new path → the
new test reddens while the legacy test stays green), per the repo's testing
discipline ([[green-but-hollow]]).

---

## 6. Phase plan (RED-first, headless-testable, shippable)

Each phase: write a failing headless test (RED) → implement (GREEN) → sabotage-
verify → run the core regression suite (create_save / open_close / netlisting)
before committing. Tests live under `tests/headless/` (the established pattern,
e.g. `test_hover_highlight.tcl`) except Phase 5 which is Python/pytest.

### Phase 0 — this document. Ratify, then begin. *(no code)*

### Phase 1 — Library registry (read-only query API)
- **Surface:** `xschem libraries` → list of `{name path}`; `xschem library <name>`
  → absolute path or "". Reads `library.defs` (with `${VAR}`/`~` expansion) and
  auto-discovers `library.tag` dirs on `XSCHEM_LIBRARY_PATH`.
- **RED:** temp `library.defs` with two libs → assert listing + per-name resolve;
  unknown name → ""; a tagged dir on the path auto-appears.
- **GREEN:** new Tcl resolver module (e.g. `src/library_defs.tcl`) + a scheduler
  query branch in `xschem_cmds_l`. No reference behaviour changes yet.
- **Risk:** low — pure additive read API.

### Phase 2 — lib/cell/view resolver (core)
- **Surface:** `xschem cellview_path <lib/cell> <view>` → absolute datafile path
  under `<cell>/<view>/<cell>.<ext>`, with legacy-flat fallback; teach
  `abs_sym_path` rule 1→2→3 and `rel_sym_path` the inverse.
- **RED:** tmp fixture library in new layout → `cmos_inv schematic` and
  `cmos_inv symbol` resolve; legacy `{res.sym}` still resolves (rule 3);
  `abs→rel→abs` round-trip stable; saving an already-good ref does not rewrite it.
- **GREEN:** extend the two procs; keep the C wrappers unchanged.
- **Risk:** medium — the heart of the change; the fallback ordering is delicate.

### Phase 3 — Load/save round-trip with lib-qualified references
- **Surface:** placing an instance of `devices/res` saves `C {devices/res}`;
  loading resolves it; netlisting is unchanged.
- **RED:** create inst → `xschem save` → reload → `xschem netlist`; assert
  connectivity AND byte-stability of the saved `.sch`.
- **Risk:** medium — touches the save/load instance path (already the chokepoint).

### Phase 4 — Descend & symbol↔schematic association under views
- **Surface:** descending an instance opens `<cell>/schematic/<cell>.sch`,
  honouring a `schematic=` override; "make schematic from symbol" / "make symbol
  from schematic" write into the correct view dir.
- **RED:** descend into a new-layout instance lands on the schematic view;
  `schematic=` override redirects; round-trip of symbol↔schematic creation.
- **Risk:** medium — `actions.c:2181-2274` descend logic + creation flows.

### Phase 5 — Python migration toolkit (user-facing)
- **Deliverable:** `tools/migrate/` Python package — converts a flat library dir
  → lib/cell/view; rewrites references flat → lib-qualified; **idempotent**;
  `--dry-run`; emits a report; reversible (backup / `--revert`). Pure stdlib, no
  deps. Operates on copies; never edits in place without a backup.
- **RED:** pytest golden tests on a fixture flat lib → expected tree + rewritten
  refs; idempotency (second run is a no-op); `--dry-run` writes nothing; a
  cross-library reference (`examples` → `devices`) rewrites correctly.
- **Risk:** medium — reference rewriting across libraries must be consistent.

### Phase 6 — Migrate the repo's own libraries
- Apply the migrator to `devices/`, `examples/`, `logic/`, `ngspice/`, … ; ship a
  default `library.defs`; update `xschem_library/Makefile`, `Makefile.conf.in`,
  `scconfig/hooks.c`, `src/xschemrc` to install the new layout + registry.
- **RED / regression:** the existing `tests/` suite stays green on migrated data;
  a migrated example loads + netlists vs golden; a clean build + install places
  the new tree and a working `library.defs`.
- **Risk:** high blast radius — done last, after tooling proves safe; the
  migration is a reviewable commit (or a generated artifact) that can be reverted.

### Phase 7 — Cadence-style Library Manager GUI (decomposes)
- **7a** read-only `ttk::treeview`: Library → Cell → View, built on the Phase 1–4
  query APIs (replaces the flat jumble).
- **7b** open-schematic / place-symbol from the tree.
- **7c** cell/view ops: new / copy / rename / delete — each a headless-testable
  `xschem` subcommand first, GUI on top.
- **7d** registry / library-path editor (edit `library.defs` in-GUI).
- **RED:** the command layer each action calls is asserted headless; pixels and
  interaction are the manual eyeball (this branch's established discipline —
  WSLg can't drive a real pointer).
- **Risk:** medium — large surface, but rests on a model already proven by 1–6.

---

## 7. Cross-cutting principles

- **Backward compatibility is the spine** (§5) — every phase carries a "legacy
  still works" assertion.
- **`rel_sym_path` must not churn** untouched files — only rewrite a reference
  when it genuinely changes.
- **Sabotage-verify every GREEN** ([[green-but-hollow]]).
- **Run core regression** (create_save / open_close / netlisting) before each
  commit; example designs must still load + netlist.
- **Format stays at 1.3** — references are strings, not grammar.
- **Run headless GUI tests from `src/`** with `--pipe -q --script` (per repo
  conventions; mind WSLg flakiness on fresh-process GUI scripts).

---

## 8. Open questions (resolve as they arise; none block Phase 1)

- **View vocabulary:** start with `schematic` + `symbol`; reserve `layout`,
  `verilog`, `spice`, `veriloga` for future view kinds (xschem already has
  format-specific files like `.va`, `.v` floating in some libs — candidates for
  becoming views later).
- **Special libraries** (`generators/` with `.tcl`, `analyses/` with
  `lib_init.tcl`, `viewdraw_import/`, `gschem_import/sym/` with 700+ symbols):
  decide per-library in Phase 6 whether to model as a cell/view library or leave
  flat (the fallback keeps them working either way).
- **User library default** (`~/.xschem/xschem_library`): seed an empty
  `library.defs` + a starter user library on first run? (Phase 6 install logic.)
- **`schematic=` and other path-bearing attributes:** audit for any reference
  that bypasses `abs_sym_path` (Phase 4).

---

## 9. Decision log

- 2026-06-15: D1 cell-named, D2 lib-qualified, D3 defs+tag, D4 no version bump —
  ratified by user. Phase 0 doc written; **awaiting sign-off to start Phase 1.**
