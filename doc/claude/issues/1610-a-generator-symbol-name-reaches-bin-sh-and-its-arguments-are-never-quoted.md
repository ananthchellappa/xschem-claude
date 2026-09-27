# 1610 — a generator symbol name reaches `/bin/sh`, and its arguments are never quoted

**STAMP:** `v1 claim=open tree=636bc431 stamped=2026-09-27 fix=untried open=2 by=driver`

## The defect

`get_generator_command()` in `src/token.c` turns an instance's symbol name of the shape
`head(args)` into a command string and the callers hand it to **`popen()`**, i.e. `/bin/sh -c`.
It quotes the generator's **path** — the comment says so, *"add quotes to protect spaces in cmd
path"* — and then appends the **arguments verbatim**:

```c
my_mstrcat(_ALLOC_ID_, &gen_cmd, "\"", cmd_filename, "\"", NULL);
*spc_idx = ' ';
my_strcat(_ALLOC_ID_, &gen_cmd, spc_idx);       /* <-- the arguments, raw, into a shell string */
```

`spc_idx` is the remainder of the symbol name after the first space, having had `(`, `)` and `,`
turned into spaces by `str_chars_replace`. Nothing else is done to it. So every shell
metacharacter in a symbol name is live: `;`, `|`, `&&`, `` ` ``, `$( )`, redirections.

**Driven at `636bc431`**, in a throwaway directory, `env -u DISPLAY ./src/xschem --nogui --pipe
-q <file>` with no subcommand, no draw and no netlist. One instance record whose symbol name is

```
/bin/true(z;/usr/bin/touch <scratch>/FIRED_VIA_SHELL)
```

created the marker file. The shell ran `/bin/true z`, then the `;`, then the second command.
`stat()` on the head is the only gate, so the head must name an existing file — any existing
file, and `/bin/true` is one.

## Why this is a defect and NOT the documented feature

Issue 0823 records that a `.sch` is executable **by design** through `tcl_hook2()`, and argues —
correctly — that reversing that is the project owner's decision, not a defect crew's. **This is
not that.** 0823's own reasoning draws the line and puts this on the defect side of it:

> `tcleval(` is a **marker**. A reader of the file can see it, a reviewer can grep for it, and
> its presence announces "this schematic contains code." … Closing the unmarked doors converts
> "any schematic may be executing code invisibly" into "a schematic executes code only where it
> says so."

A generator name **announces nothing**. `/bin/true(z;…)` is indistinguishable in shape from the
shipped, honest `res(1k)` or `mosgen(nmos,2u,0.15u)`. And the intended feature is *run this
generator with these arguments* — a device parameter is a number or a model name, never a shell
expression. **Nobody designed `;` to chain a second command.** Quoting the arguments leaves every
legitimate generator call byte-identical and removes only the shell's interpretation, so this
needs no ruling from the user: the feature is preserved exactly, and what stops working was never
a feature.

## Scope notes for the fix

* **Three call sites** reach it, per the recon receipt: `load_schematic` and `load_sym_def` in
  `src/save.c`, and a site in `src/paste.c`. The quoting belongs in
  `get_generator_command()` itself, once, not at the callers.
* **The `#else` (non-`__unix__`) branch builds a different string** — `tclsh "<path>"<args>` — and
  Windows' `popen` goes through `cmd.exe`, whose quoting rules are not the shell's. Whatever ships
  must say which branch it fixes and must not claim the other is measured: there is no Windows
  toolchain on this machine, and issue 1606 shipped a comment that turned exactly this kind of
  derivation into a claimed Win64 measurement and had to correct it.
* **`,` and `(` `)` are already collapsed to spaces before the arguments are seen**, so the
  comma/space distinction is lost before quoting can preserve it. Per-whitespace-token quoting is
  therefore faithful to today's behaviour, not a narrowing of it — state that rather than implying
  the arguments were ever structured.
* **Census the five shipped generators' real arguments** (`res.tcl`, `tier.tcl`, `symbolgen.tcl`,
  `schematicgen.tcl`, `mosgen.tcl` under `xschem_library/generators/`) before choosing between
  quoting and refusing, so the fix is known not to break a legitimate argument.

## Open

1. Quote each argument, or refuse any argument holding a metacharacter? Quoting preserves more and
   is the standard answer; refusing is smaller and arguably more honest for a parameter list.
   Decide with the census above.
2. The Windows branch.
