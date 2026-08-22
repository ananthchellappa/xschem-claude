# 0424 — `make install` ships an `xschem.tcl` that sources an uninstalled `op_annot.tcl`, and the installed binary then SEGFAULTS at startup

Status: **CLOSED — fixed and measured 2026-08-22 (see Resolution at the bottom).**
Originally: open — measured, not fixed. Found by the S1 Verify-A agent of the
op-annotation run (2026-08-16) on branch `annotate`, re-measured by the write-up
agent. Not fixed here because the fix is `./configure`, a **build action**, and
this crew's hard rules bar every agent but Implement from running one.

**This is the one thing in step S1 that a human has to act on.**

## What is wrong

S1 added `src/op_annot.tcl` and one `source $XSCHEM_SHAREDIR/op_annot.tcl` line
to `src/xschem.tcl:14548`. The file was correctly added to the **tracked**
install list `put /local/install_shares` in `src/Makefile.in:23`.

But `src/Makefile` is **generated** from `Makefile.in` by `./configure`
(scconfig), is **gitignored** (`.gitignore:64`), and has **no self-regeneration
rule**. The copy in this working tree predates the `Makefile.in` edit:

```
$ ls -la --time-style=+%F_%T src/Makefile src/Makefile.in
-rw-r--r-- 1 analog analog 11281 2026-08-15_14:18:57 src/Makefile
-rw-r--r-- 1 analog analog  4102 2026-08-16_13:32:07 src/Makefile.in
```

so it still carries the pre-S1 install list. Measured, against eight sibling
helpers — every one of them has an install line and an uninstall line, and
`op_annot.tcl` has neither:

```
$ for f in calculator.tcl cmdmode.tcl ase_window.tcl save_as_form.tcl op_annot.tcl; do
      printf "%-20s %s\n" "$f" "$(grep -c "$f" src/Makefile)"; done
calculator.tcl       2
cmdmode.tcl          2
ase_window.tcl       2
save_as_form.tcl     2
op_annot.tcl         0
```

`make install` from this tree therefore installs an `xschem.tcl` containing a
`source` line for a file it does not install.

## Why it is not merely "one feature missing"

A missing sourced helper is not a degraded install — it is a **crash**, by the
mechanism of issue 0423. Measured directly, by hiding the file in the source
tree and launching the in-tree binary:

```
$ mv src/op_annot.tcl /tmp/…/op_annot.tcl.hidden
$ ./src/xschem --nogui --pipe -q --nolog --script probe.tcl
/bin/bash: line 1: 623927 Segmentation fault      (core dumped) …
EXIT=139
can't read "fix_broken_tiled_fill": no such variable
can't read "fix_mouse_coord": no such variable
can't read "cairo_vert_correct": no such variable
…
```

(The file was restored immediately; the tree is intact.) The cause is 0423:
`Tcl_AppInit()` continues into `alloc_xschem_data()` after
`source_tcl_file(xschem.tcl)` has failed, and `xinit.c:658` does
`strcmp(tclgetvar("undo_type"), "disk")` on a `NULL`.

So the user-visible consequence of installing from this tree today is
**"xschem segfaults on startup"**, not "the annotation feature is absent".

## Why no test caught it

Every tier in S1 runs **in-tree**, where `XSCHEM_SHAREDIR` resolves to `src/`
(`xinit.c:2977-3050`) and `op_annot.tcl` is right there next to `xschem.tcl`.
T1, T2 and all eleven T3 suites were byte-identical to baseline. Nothing in
`tests/` exercises an installed tree at all.

## Fix

```sh
cd /home/analog/dev/xschem-claude && ./configure && cd src && make
```

`./configure` regenerates `src/Makefile` from the already-correct
`Makefile.in`, which restores the install/uninstall pair for `op_annot.tcl`.
No source change is needed — the tracked state of the repository is already
right.

Do **not** hand-edit `src/Makefile`: it carries a DO-NOT-EDIT header and the
next `./configure` reverts it. That option was considered and rejected by the
S1 plan for exactly that reason.

## The general rule this exposes

**Any step in any plan that adds a new `.tcl` helper to `install_shares`
silently arms this trap until someone re-runs `./configure`.** The window is
invisible in-tree and fatal when installed. Steps S3–S6 of the op-annotation
plan add no new files, but any future one should either re-run `./configure` in
the same session or file a note like this.

A cheaper structural fix, if someone wants one: give `src/Makefile` a
regeneration rule keyed on `Makefile.in`, so `make` notices the staleness
itself. That is a scconfig change and is out of scope here.


---

## Resolution — 2026-08-22

The user ratified E-question 1 (`may a crew run ./configure?`) as **yes, when and
only when the step edited `Makefile.in`**, and authorised the run. Executed from
the repo root:

```sh
./configure && cd src && make
```

`./configure` rc=0, `make` rc=0 with **zero warnings**, full rebuild (`config.h`
regenerated, so every object recompiled). `Makefile.conf` came back byte-equivalent
in the fields that matter — `PREFIX=/usr/local`, same `CFLAGS`, same `LDFLAGS`, same
feature set (`cairo: yes`, `libjpeg: yes`, `xcb: no`) — so the regeneration restored
the install list without moving the build configuration.

The receipt this issue is about:

```
before:  op_annot.tcl lines in src/Makefile: 0
after:   op_annot.tcl lines in src/Makefile: 2
  225:   $(SCCBOX) install -f op_annot.tcl  "$(XSHAREDIR)"/op_annot.tcl
  286:   $(SCCBOX) rm "$(XSHAREDIR)"/op_annot.tcl
```

install **and** uninstall, matching the eight sibling helpers.

### Proved against a real installed tree, not just the Makefile text

`make install DESTDIR=<scratch>/pkg` (rc=0) then launching the **installed** binary
against the **installed** share dir:

```
$ XSCHEM_SHAREDIR=<pkg>/usr/local/share/xschem <pkg>/usr/local/bin/xschem \
      --nogui --pipe -q --nolog --script probe.tcl
PROBE-ALIVE
op_annot-ns: 1
op_annot-text-proc: 1
undo_type: disk
EXIT=0
```

27 `.tcl` helpers installed, `op_annot.tcl` among them at 42173 bytes.

### The negative control — the probe can fail

Per issue 0499's lesson (a check count is not evidence), the same probe was re-run
with the installed helper hidden:

```
$ mv <pkg>/…/op_annot.tcl <scratch>/op_annot.hidden && <same command>
Tcl_AppInit() error: can not execute …/xschem.tcl, please fix:
couldn't read file "…/op_annot.tcl": no such file or directory
Segmentation fault (core dumped)
EXIT_WITHOUT_FILE=139
```

139 without the file, 0 with it. That is also a verbatim confirmation of **0423**'s
mechanism: `Tcl_AppInit()` reports the failure and then continues into
`alloc_xschem_data()` anyway. The file was restored immediately.

### No regression from the full rebuild

* `tests/headless/test_op_annot.tcl` — **ALL PASS (241 checks)**, unchanged.
* `tests/headless/run.sh` — 6/6 PASS, `== HARNESS: PASS ==`.

### What was changed so it does not recur

Rule **2b** in `doc/claude/ledger/crew_annotate.js`: the Implement agent must run
`./configure` and rebuild whenever the step edited `src/Makefile.in`, must not
otherwise, and must quote the before/after `grep -c <newfile> src/Makefile` in its
notes. The Implement brief's "a new `.c` needs an OBJ entry AND a compile rule" line
was corrected to name `Makefile.in`, not the generated `Makefile`. A matching note
was added to `CLAUDE.md`.

**0423 remains open**, and it is the deeper defect: a missing sourced helper should
print and exit, not segfault. Fixing 0424 closes this instance only.
