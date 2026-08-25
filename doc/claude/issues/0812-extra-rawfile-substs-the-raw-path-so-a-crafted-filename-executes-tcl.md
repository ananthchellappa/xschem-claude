# 0812 — `extra_rawfile()` `subst`s the raw file path, so a crafted filename EXECUTES Tcl

STATUS: **OPEN — stub claimed by the 0807 implement agent, 2026-08-25. Measured, not fixed.**
FOUND IN: `src/save.c` — the six `tclvareval("subst {", file, "}", NULL)` calls in
`extra_rawfile()` (the two read arms, the switch arm and the three clear arms);
`src/scheduler.c` — the `raw_read` verb's own `regsub {^~/} {%s} {%s/}` + `tcleval()`
splice.
RELATED: `src/scheduler.c`'s `annotate_op` branch, whose comment block says this hazard
was closed for that command in C (it resolves `~/` with two `my_snprintf` branches
instead of a `regsub` tcleval). **That claim is true of its own line and false of the
path as a whole**: the hazard is closed one frame up and open one frame down.

## Measured (this tree, patched for 0807, `--nogui`)

```tcl
set f {<dir>/q}; set ::SC_PWNED 1; list {a.raw}   ;# a real file with that name
set ::SC_PWNED 0
catch {xschem annotate_op $f 0}
```

```
INJ| annotate_op  PWNED=1  ret=<0>
```

`::SC_PWNED` is 1: the filename's `}` closed `subst`'s brace group early and the rest of
the name ran as script. The scout on item 0807 measured the same through
`xschem raw_read <crafted path>` via `src/scheduler.c`'s
`regsub {^~/} {%s} {%s/}` + `tcleval()` (scheduler.c, the `raw_read` verb).

## Why it is reachable

Every path that hands a user-chosen or simulator-chosen filename to `extra_rawfile()`
reaches it: the `annotate_op` branch, `xschem raw read`, `xschem raw clear <file>`, the
ASE annotate arm, `open_sub_schematic`'s carry-over, `hi_descend`'s new-window arm. The
filename need not be typed — a directory a user chose plus a cell name is enough.

## Fix, when someone takes it

The `subst` exists only to expand Tcl variables and `~` in a path. Either drop it (the
callers already have resolved paths) or route it through a form with nothing to escape
from — `Tcl_SubstObj` with a value, or `list`-quoting the argument. The `annotate_op`
branch's two-`my_snprintf` `~/` expansion is the in-tree precedent for the C-side answer.

## Unaffected by 0807's revert, and an aggravating factor for its retry

The transcript above was taken on the attempt-1 binary, but the sink is in `extra_rawfile()`,
which that attempt did not touch — **this reproduces at HEAD unchanged**.

⚠ For whoever retries 0807: a detach-based fix runs attacker-controlled Tcl **while a
database is detached**, i.e. while a live `Raw` is owned only by a C local and is in no
registry. `xschem raw clear` in that window is harmless (the detached entry is not there to
clear), but anything that tears down `xctx` would leave the reattach writing through freed
memory. Fixing this issue first would remove that interaction entirely.

## Not fixed under 0807

0807's scope is the destroy-then-read lifetime bug and the fabricated return value. This
is a different decision with a different blast radius (every `extra_rawfile()` caller,
and the `~`/variable expansion some of them may rely on).
