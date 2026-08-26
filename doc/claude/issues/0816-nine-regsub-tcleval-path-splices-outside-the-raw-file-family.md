# 0816 — nine `regsub {^~/}` + `tcleval()` path splices are still live outside the raw-file family

STATUS: **FIXED 2026-08-25, item 0821+0816+0817 — all nine `scheduler.c` sites now call
`expand_tilde()`; `xinit.c:3235` is excluded by this issue itself. See §A below, and read
§B before writing "`xschem load` is safe" anywhere.**
Originally filed by the 0812 implement agent, 2026-08-25. Measured, not fixed.
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

---

## §A — FIXED, 2026-08-25 (item 0821+0816+0817)

### BEFORE (Measure agent, on the rebuilt HEAD binary, verbatim)

```
load: HITL=1 SC_FILE=1
merge: HITM=1
log: HITG=1
load-nonexistent: HITN=1
```

The payload is this issue's own no-slash shape,
`x} {y} {z}; set ::HIT 1; list {a`. `SC_FILE=1` is an embedded `[exec touch]`
creating a **host file**; `HITN=1` is the row this issue demanded — the splice runs
**before any `stat()`**, so a path that does not exist executes just as well.

### AFTER

All nine sites replaced with the two-line form this issue prescribed:

```c
expand_tilde(argv[N], f, (int)S(f));
```

`tests/headless/test_raw_read_dispatch.tcl`, group **SC** (true headless), added by
this item — 89 checks → **107**, `ALL PASS`:

* **SC01-SC08** `{0 0}` for `load`, `merge`, `log`, `saveas`, `load_new_window`,
  `new_schematic` — sentinel 0 **and** no host file; **SC03** repeats it on a path
  that does not exist; **SC06b** asserts no file appeared in the repo root.
* **SC09** is a source scan: zero live `regsub {^~/}` splices remain in
  `src/scheduler.c` (was nine, at 2980 7611 7767 7835 8132 8989 9028 9831 11183),
  with `xinit.c:3235` named in the failure text as the one deliberate exclusion.
  **It is the only coverage of `compare_schematics`, `new_process` and
  `preview_window`**, which are not driven — 0815 segfaults `compare_schematics`
  under `--nogui` and `new_process` forks a real xschem.
* **SC10** anti-hollow: `xschem log ~/<name>.log` still expands the tilde and
  creates the file under `$HOME`; a real `~/` `.sch` still loads; a path containing
  a **space** still loads.

**Two of the nine needed a second frame, and this is the propagating lesson.**
`:7767` `load_new_window` and `:9028` `new_schematic` feed their argument into
`abs_sym_path()`, whose **own body** spliced it into `abs_sym_path {%s} {%s}`.
Replacing only their `regsub` left those two verbs fully exploitable, so this issue
could not honestly be reported swept without fixing that wrapper family too — filed
and fixed in the same commit as **0825**. `SC07` is the row that only passes once
0825 lands, and sabotage variant SAB-C1 turned it red exactly as predicted.

### Sabotage matrix

| variant | predicted red | observed |
|---|---|---|
| **SAB-B1** splice back at all nine verbs | SC01-SC09 (9) | **exactly those 9** |
| **SAB-B2** splice back at `log` only | SC05, SC09 (2) | **exactly those 2** — per-verb coverage, not one row standing in for nine |
| **SAB-B3** tilde expansion dropped (verbatim copy) | SC10 (1) | **exactly SC10**; every injection row correctly stayed green |

⚠ One weakness recorded rather than papered over: only SC10's
`xschem log ~/x.log` element discriminates SAB-B3. Its two `.sch`-load elements
pass either way, because an unexpanded literal `~/…` still reports the same
`file tail`.

### Decision

**`expand_tilde()` only, never `resolve_rawfile_path()`** (ladder rung L2). It is
byte-identical to the regsub for every input without a `}` — a brace-quoted regsub
word never did variable substitution either. Rejected: the full resolver, which
would **add** `$var` expansion to `load`/`merge`/`saveas`/`log` that nobody asked
for. That is the same call 0812 made for the four raw-family verbs, with **0818**
as the recorded residual.

## §B — ⚠ "0816 FIXED" DOES NOT MEAN `xschem load` IS SAFE

Driven on the **fixed** binary, twice independently (the implement agent, then the
write-up agent):

```
xschem load "<dir>/x} ; set ::FNPWN 1; exec touch <dir>/FNHOST; is_xschem_file {a"
->  FNPWN=1  host=1
```

A crafted **filename** still executes, through the `tclvareval` brace groups of
`is_xschem_file` / `get_directory` / `update_recent_file` — **issue 0817**, which
this item deliberately deferred. SC01-SC08 pass only because *this issue's* payload
shape trips a wrong-number-of-args error at the first of those sinks and aborts the
script; a payload shaped for that sink does not.

The sink named by this issue is closed at all nine sites. The **verb** is not clean.
Any status row that compresses the first sentence into the second is wrong.
