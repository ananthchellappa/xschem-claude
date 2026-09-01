# 0458 — the installed `cadence_style_rc` sources `utils/*.tcl`, which nothing installs

Status: OPEN (pre-existing, measured by S8, not fixed)
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
