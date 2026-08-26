# 0829 — `get_directory [list …]` and `netlist {%s} … {%s}` in the five netlisters execute a crafted filename

**Status:** FIXED (this item, with 0827 + 0817 §Z.2)
**Filed by:** the 0827+0817+0828 crew, from a vector DRIVEN during planning; not present in
0817's inventory in any form.

## What it is

The five netlisters spelled the working-directory update

    tclvareval("get_directory [list ", xctx->sch[xctx->currsch], "]", NULL);

`[list …]` READS as the safe form and is not: the bracket is a **command substitution in the
OUTER script**, so whatever is inside it runs while that script's words are being parsed —
before `list` is ever reached. The `.sch` brace-escape defence discussed in 0825/0827 is
irrelevant to this spelling; a `[` in the *filename* is enough.

The same functions also spelled the per-cell netlist hand-off

    my_snprintf(tcl_cmd_netlist, S(tcl_cmd_netlist), "netlist {%s} noshow {%s}",
                netl_filename, cellname);
    tcleval(tcl_cmd_netlist);

— 18 sites, both data words derived from the schematic's own filename, both inside brace
groups, so a `}` closes the group exactly as in 0827.

## Measured, on the pre-fix binary (HEAD 466fab47)

A schematic whose FILENAME is `a[exec touch HOST_NL01]b.sch`, holding one
`examples/cmos_inv.sym` instance:

    xschem load  <dir>/a[exec touch HOST_NL01]b.sch      -> host file NOT created
    xschem netlist                                        -> host file CREATED

One verb past the `load` vector of 0817 §Z.2, same door (a crafted filename), no dialog,
`--nogui`.

## Fix

Every site now goes through `tcl_call()` / `tcl_call_mid()` (src/util.c): the path is handed
to the interpreter as a global and referenced with `$::`, whose substitution result is one
word and is never re-parsed. `get_directory [list $p]` and `get_directory $::v` are
semantically identical for every legitimate path — except that `[list …]` actually passed the
*braced list representation* (`{/a b/c.sch}`) for a path containing a space, which the other
`get_directory` call sites never did; the conversion also removes that inconsistency.

## Acceptance

* `NL01-netlist-list-splice` — load the crafted name, `xschem netlist`, sentinel 0 and no host
  file. Measured RED before the fix (`0 1`), green after.
* `NL02-netlist-still-emits-the-subcircuit` — the anti-hollow twin: the same netlist still
  writes `.subckt cmos_inv` with its `M1`/`M2` lines and `current_dirname` is still right.
* `FN07-no-concat-splice-in-the-load-path` — the source scan that names any surviving
  `"<proc> [list "` spelling.
* `FN08-no-tcl-diagnostics-on-an-ordinary-run` — a plain load/descend/netlist/saveas under a
  directory whose name merely contains `}` must emit zero Tcl diagnostics.

All in `tests/headless/test_raw_read_dispatch.tcl`.

## ⚠ Claims (issue 0823)

A `.sch` is executable **by design** — a `tcleval(` in a text record fires on DRAW via
token.c:78 `tcl_hook2()`. This fix does **not** make an untrusted `.sch` safe to open and does
**not** close "the injection family". It removes paths that executed **without saying so**.

## ⚠ RULING OWED — a user-visible behaviour change rode in with the sweep (ladder L3)

Three of the converted sites spliced their string **UNBRACED**, and two spliced it inside
**double quotes**. Converting those changes what an ORDINARY path does, not only a crafted one:

| site | before | after |
|---|---|---|
| `xinit.c:4062` `xschem load_new_window <argv>` | a command-line filename containing a SPACE split into several words and opened nothing | it opens as ONE file |
| `xinit.c:3857` / `scheduler.c:8888` `file dirname <name>` | same word-split on a spaced `--netlist-filename` / `xschem netlist <file>` | one name |
| `save.c` `ask_save "… <path> …"` (×2) | a `$` or `[` in the path was SUBSTITUTED inside the prompt text | shown literally |
| the five netlisters' `get_directory [list <path>]` | a spaced path was passed as its braced list form `{/a b/c.sch}` | passed as the path itself |

**The question for the user, not answered here:** should `xschem 'my file.sch'` now open that
single file, and should a save/descend prompt render a `$` or `[` in a path literally instead
of expanding it?

Implemented as YES on ladder L2 grounds — a word-split filename is indistinguishable from a
bug, nobody could be relying on it, and preserving the split would mean re-emitting the
unbraced form and keeping an RCE open to protect a defect. The **ratification is the user's**.
Rejected alternative: leave the unbraced/quoted sites as they are (keeps the vector live).
