# 0816 — nine `regsub {^~/}` + `tcleval()` path splices are still live outside the raw-file family

STATUS: **OPEN — filed by the 0812 implement agent, 2026-08-25. Measured, not fixed.**
FOUND IN: `src/scheduler.c`. Same sink shape as issue 0812.
⚠ **UPDATED 2026-08-25 (twice).** The first 0812 attempt was reverted, briefly making all
THIRTEEN splices live; **the 0812 RETRY then landed and killed the four raw-file-family
ones** (`embed_rawfile` :851, the `raw_read` verb :10559, the `table_read` verb :13202,
the `vcd_read` verb :13787). **These NINE — `scheduler.c` 2980, 7611, 7767, 7835, 8132,
8989, 9028, 9831, 11183, plus `xinit.c:3235` on a compile-time constant — are still live
and are this issue.** The split is unchanged; only the live count moved, 13 → 9.

## ✅ THE FIX ALREADY EXISTS — do not write a second one

0812 shipped `expand_tilde(const char *s, char *dest, int destsize)` in `src/util.c`
(declared in `src/xschem.h` after `tclvareval`). It expands a leading `~/` against
`home_dir` in pure C and does nothing else, which is **all `regsub {^~/} {…} {…}` ever
did** — a brace-quoted regsub word never performed variable substitution either, so for
every input without a `}` it is byte-identical to what it replaces. It writes at most
`destsize` bytes (NUL included), returns `dest`, and is safe on `NULL` / `destsize<=0`.

```c
/* was: my_snprintf(f, S(f), "regsub {^~/} {%s} {%s/}", argv[N], home_dir);
 *      tcleval(f); my_strncpy(f, tclresult(), S(f));                        */
expand_tilde(argv[N], f, (int)S(f));
```

Each site needs its own red row first — the payload shape for this sink is
`x} {y} {z}; set ::SC_PWNED 1; list {a` (**no slash**, so the `^~/` anchor is irrelevant),
and 0812 §4 constraint 4 is binding: assert the **side effect**, add an `[exec …]` row that
checks a created **file**, and add a row on a path that does **not exist** — the splice runs
before any `stat()`.

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
