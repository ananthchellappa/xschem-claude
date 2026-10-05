# 0458 — the installed `cadence_style_rc` sources `utils/*.tcl`, which nothing installs

Status: **FIXED** 2026-10-05 (found pre-existing, measured by S8; the repair is below)
Found: S8 of doc/claude/specs/op_annotation.md.

`src/Makefile.in:18` ships `cadence_style_rc` to XSHAREDIR. That file then does

    set _ut [file join [file dirname [file normalize [info script]]] .. utils]
    source [file join $_ut lib_mgr_helpers.tcl]
    ... 10 more ...

and **`utils/` appears in no install list at all**, so the whole cadence profile
works from the source tree only: an installed xschem sourcing the installed rc
raises at its first `source`. S8's new `utils/annot_mode.tcl` inherits exactly
this, and is deliberately placed there anyway rather than inventing a second,
inconsistent home for one proc (S8 decision D1).

Adjacent, and worth fixing in the same pass: `src/Makefile` is generated and
gitignored, and it is STALE — `grep -n op_annot src/Makefile` finds nothing even
though `src/Makefile.in:23` lists `op_annot.tcl` (S1 added it to the template and
`./configure` was never re-run). Anyone fixing this should re-run `./configure`
as part of the fix and say so.

Fix shape: add a `utils/` install list to `src/Makefile.in` (or an
`install-utils` rule), ship the directory next to `cadence_style_rc`, and keep
the rc's relative `..\ utils` resolution working in both trees.

## 2026-10-05 — fixed, and it was TWO bugs rather than one

Measured by doing a real `make install DESTDIR=<scratch>` rather than by reading:

1. **Nothing installed `utils/`.** `find <destdir> -path '*utils*' -name '*.tcl'`
   returned **0** of the 14 files.
2. ⚠ **And even installed, the rc would have looked in the wrong place.**
   `set _ut [file join [file dirname [file normalize [info script]]] .. utils]`
   is right in a checkout — the rc is `src/cadence_style_rc` and the helpers are
   `<repo>/utils` — and wrong once installed, where the rc lands in
   `$XSCHEM_SHAREDIR` and `..` resolves to `share/utils`, outside the share tree.
   Reproduced against the installed copy: the first `source` gives
   `couldn't read file ".../share/xschem/../utils/lib_mgr_helpers.tcl"`.

   **Fixing only (1) would have left the feature broken**, which is why this is
   recorded as two bugs: the second is invisible until the first is fixed.

The repair:

* `src/Makefile.in` installs the DIRECTORY beside `systemlib/`
  (`install -f -d ../utils/* "$(XSHAREDIR)"/utils`) and removes both its
  contents and the directory on uninstall. ⚠ Deliberately **not** added to
  `install_shares`: every entry there installs as
  `install -f <n> "$(XSHAREDIR)"/<n>`, i.e. source and destination share one
  relative name, and `utils/` is one level up from `src/`. The directory form
  also means a NEW helper dropped into `utils/` ships without editing the
  template — **the hand-kept list is what let this happen.**
* `src/cadence_style_rc` tries the SIBLING `utils/` first (the installed layout,
  the one that was failing) and falls back to the parent's (the source tree's).

Verified both ways after the repair: 14 of 14 files installed into
`share/xschem/utils/`, and the resolution lifted from the rc's own text answers
the sibling for the installed layout and the parent for the source tree, with
**0 of the 14 sourced names missing** in either.

Fenced by `tests/headless/test_utils_install_0458.tcl`, registered in `hcases`.
Each half was sabotaged separately: reverting the rc to the unconditional parent
reddens `UI5a`/`UI5b`, and deleting the install line reddens `UI3`/`UI5e`.
