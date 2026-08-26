# 0816 — nine `regsub {^~/}` + `tcleval()` path splices are still live outside the raw-file family

STATUS: **OPEN — filed by the 0812 implement agent, 2026-08-25. Measured, not fixed.**
FOUND IN: `src/scheduler.c`. Same sink shape as issue 0812.
⚠ **UPDATED 2026-08-25 after the 0812 attempt was REVERTED.** That attempt would have
fixed the four raw-file-family splices (`embed_rawfile`, the `raw_read` verb, the
`table_read` verb, the `vcd_read` verb) and left these nine; it was reverted, so **all
THIRTEEN `regsub {^~/}` splices are live at HEAD.** The four raw-family ones belong to
0812; these nine are this issue, and the split is unchanged — it is only the count that
is live that moved.

## The sink

```c
my_snprintf(f, S(f), "regsub {^~/} {%s} {%s/}", argv[N], home_dir);
tcleval(f);
my_strncpy(f, tclresult(), S(f));
```

The path sits **inside a brace group in a script that is then evaluated**. A path
containing `}` closes the group early and the remainder RUNS AS TCL.

## The nine, with line numbers at HEAD

| line (HEAD, 2026-08-25) | verb |
|---|---|
| 2951 | `compare_schematics` |
| 7578 | `load` |
| 7734 | `load_new_window` |
| 7802 | `log` |
| 8099 | `merge` |
| 8956 | `new_process` |
| 8995 | `new_schematic` |
| 9798 | `preview_window` |
| 11145 | `saveas` |

The four that belong to 0812, for completeness, also live at HEAD: 851 `embed_rawfile`,
10559 the `raw_read` verb, 13202 `table_read`, 13787 `vcd_read`.

**NOT included: `src/xinit.c:3235.`** It splices the compile-time `USER_CONF_DIR` macro,
which is not attacker-controlled.

## Measured

Payload shape matters and is **not** the one issue 0812's `subst` sink takes. The regsub
sink needs a payload that leaves the trailing `{<home>/}` a legal argument, and it must
contain **no slash** or the name becomes a directory path that never reaches the splice:

```
x} {y} {z}; set ::SC_PWNED 1; list {a
```

On the **post-0812 binary**, with a real file of that name, the shared repro
(`repro_0812.sh`) reports:

```
0812| load verb                  PWNED=1
0812| merge verb                 PWNED=1
0812| log verb                   PWNED=1
```

The other six were not driven; they are the same three lines of code.

## Fix

Two lines each: a **pure-C** leading-`~/` expansion (`my_snprintf(dest, size, "%s/%s",
home_dir, s + 2)` when `s[0]=='~' && s[1]=='/'`, else a verbatim copy). It is
byte-identical to the regsub for every input that does not contain `}`, because a
brace-quoted word never did variable substitution either.

⚠ The 0812 attempt put exactly that expander in `src/util.c` as `expand_tilde()` and the
attempt was reverted, so **the helper does not exist at HEAD**. Whoever fixes 0816 either
adds it (it is written, in `doc/claude/evidence/0812-attempt1-reverted.patch.txt`) or
waits for the 0812 retry to land it. **Do not reach for `subst` for this** — 0812 §1
records that `subst -nocommands` still executes an array index `$a([...])`; tilde
expansion needs no Tcl at all.

## Why 0812 did not take them

They are not raw-file paths. Fixing them moves the **schematic-load** and
**process-launch** boundaries inside a security step whose acceptance rows do not cover
them, and `tests/headless/test_perform_action_embed_rawfile.tcl` is the only suite that
pins any of this seam's `~/` semantics. Whoever takes 0816 should run that suite plus the
load/merge/saveas suites.
