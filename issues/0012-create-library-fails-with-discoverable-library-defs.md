# 0012 — "New library" fails when the writable `library.defs` is only on the search path

- **Status:** RESOLVED (backend RED→GREEN; GUI Browse + reworded label landed)
- **Branch:** fluid-editing
- **Component:** Library Manager (`src/library_defs.tcl`, `src/library_manager.tcl`)
- **Reported:** 2026-06-18

## Symptom

In the Library Manager, *right-click → New library*, set **name = `SANDBOX`**, leave
the **Directory** field blank, click OK. Creation fails with:

```
new library failed: no writable library.defs (set XSCHEM_LIBRARY_DEFS)
```

This is misleading: the active library tree *does* have a writable `library.defs`
(e.g. `xschem_library_oa/library.defs`), so the user reasonably expects the new
library to be created beside it.

## Root cause

The registry has **two** sources (see `library_registry`):

1. `library.defs` files listed in `$XSCHEM_LIBRARY_DEFS` (explicit), and
2. auto-discovery of dirs on the search path (`pathlist`) — a dir with a
   `library.tag`, otherwise the dir basename.

But the **write** side is asymmetric. `library_primary_defs_file` — the helper
`library_new` uses to pick a `library.defs` to append the new `DEFINE` to —
consults **only** `$XSCHEM_LIBRARY_DEFS`:

```tcl
proc library_primary_defs_file {} {
  global XSCHEM_LIBRARY_DEFS OS
  if {![info exists XSCHEM_LIBRARY_DEFS] || $XSCHEM_LIBRARY_DEFS eq {}} { return {} }
  ...
}
```

`XSCHEM_LIBRARY_DEFS` is **unset by default** (confirmed: the stock `xschemrc`
never sets it; a fresh headless session reports `DEFS_SET=0`). So
`library_primary_defs_file` returns `""` and `library_new` always errors — even
though a perfectly good, writable `library.defs` sits in the active tree.

In the OA layout the search path holds the per-library subdirs
(`xschem_library_oa/devices`, `…/examples`, …) and the `library.defs` lives in
their **parent** (`xschem_library_oa/`). The registry surfaces those libraries by
basename, which is *why the user sees them* — but nothing on the write path ever
looks at that `library.defs`.

A second, latent inconsistency: even if `library_new` appended to a discovered
`library.defs`, `library_registry` would not *parse* that discovered file (it only
parses `$XSCHEM_LIBRARY_DEFS` files), so the new library would not appear until the
dir happened to land on the search path. The fix must close both gaps.

## Fix

Treat a `library.defs` discovered on the search path (in a `pathlist` dir **or its
parent**) as a first-class registry source for both **read** and **write**:

1. New helper `library_discovered_defs_files` — every `library.defs` reachable from
   `pathlist` (dir or parent), deduped, search-order preserved.
2. New helper `library_candidate_defs_files` — explicit (`$XSCHEM_LIBRARY_DEFS`)
   first, then discovered; deduped. This is the ordered set the write path uses.
3. `library_primary_defs_file` iterates `library_candidate_defs_files` — so it
   falls back to the first **writable** discovered `library.defs`.
4. `library_registry` also parses the discovered defs files (so a freshly created
   library appears immediately). Explicit `$XSCHEM_LIBRARY_DEFS` keeps highest
   precedence: discovered defs are parsed *before* explicit ones.
5. `library_unregister` scans the same candidate set (symmetry — a library created
   in a discovered defs can also be removed).
6. **Personal registry fallback (the real stock-session case).** In a stock run
   there is often *no* `$XSCHEM_LIBRARY_DEFS` **and** no `library.defs` anywhere on
   the search path — discovery finds nothing, so steps 1–5 still leave the write
   path empty. So a third source is added: the personal `library.defs` in the user
   config dir (`$USER_CONF_DIR/library.defs`, typically `~/.xschem/library.defs`),
   the Cadence personal-`cds.lib` analog. It is the always-available, writable
   registry of last resort — `library_personal_defs_file` is appended to
   `library_candidate_defs_files` and parsed by `library_registry` (lowest
   precedence; explicit/discovered DEFINEs win). With a blank directory the new
   library lands at `$USER_CONF_DIR/<name>` and the personal `library.defs` is
   created on demand if absent.

## UI changes (same dialog)

- Add a **Browse…** button beside the Directory field so the user can pick the
  target directory with a folder chooser instead of typing a path.
- Reword the label `Directory (blank = beside library.defs):` →
  `Directory (blank = in same directory as library.defs):`.

## Acceptance

- `library_primary_defs_file` returns the discoverable `library.defs` when
  `XSCHEM_LIBRARY_DEFS` is unset but a writable `library.defs` is reachable from the
  search path.
- `library_new SANDBOX {}` (blank dir) succeeds: creates `<defs-dir>/SANDBOX`,
  appends `DEFINE SANDBOX SANDBOX` to the discovered `library.defs`, and the new
  library immediately resolves via `xschem library SANDBOX` / appears in
  `xschem libraries`.
- Explicit `$XSCHEM_LIBRARY_DEFS` still wins over a discovered defs of the same name.
- `library_unregister SANDBOX` removes the `DEFINE` from the discovered defs.
- Existing library suites stay green
  (`test_library_defs`, `test_library_ops`, `test_lib_roundtrip`, `test_lib_sweep`).

## Test (RED-first)

`tests/headless/test_lib_new_discovered_defs.tcl` — fixture mimics the OA layout
(parent dir with `library.defs`, per-library subdirs on `pathlist`, **no**
`XSCHEM_LIBRARY_DEFS`). Cases LND1–LND7 below.
