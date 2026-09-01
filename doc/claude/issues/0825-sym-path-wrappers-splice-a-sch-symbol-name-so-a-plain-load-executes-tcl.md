# 0825 — the three sym-path wrappers splice a `.sch` symbol NAME into a Tcl script, so a plain `xschem load` executes it

Status: **FIXED 2026-08-25 in the same commit that filed it — item 0821+0816+0817.**
It was pulled into that item rather than deferred because §3 below makes 0816 unclosable
without it. Record of the fix: §6-§8. Originally: measured LIVE at HEAD (17b0c3fe).
Claimed and measured by the 0821+0816+0817 crew's RED agent, 2026-08-25.
Number: 0822 was already taken by the lead (the `autoload`/`sim_type` sinks), so
this is 0825. Family: 0812 (fixed, C raw-file paths) / 0816 / 0817 / 0821 / 0822.

⚠ **The trigger is strictly worse than 0821's.** 0821 needs the Graph dialog to be
opened; this needs only `xschem load evil.sch`, `--nogui`, no dialog, no gesture.

## 1. The three sinks, `src/actions.c`

```c
:477  my_snprintf(c, S(c), "abs_sym_path [regsub {\\(.*} {%s} {}] {%s}", s, ext); /* sanitized_abs_sym_path */
:487  my_snprintf(c, S(c), "abs_sym_path {%s} {%s}", s, ext);                     /* abs_sym_path */
:496  my_snprintf(c, S(c), "rel_sym_path {%s}", s);                               /* rel_sym_path */
```

`s` is an instance's SYMBOL NAME, read straight out of a `.sch` `C {...}` record.
A `}` in it closes the brace group and the remainder RUNS AS TCL.

## 2. Measured — the fixture is an ordinary, well-formed schematic

`\}` is the `.sch` format's own brace escape, so nothing here is malformed:

```
C {p\} {\} ; set ::SC_PWNED 1; exec touch <D>/HOST; list {a} 0 0 0 0 {name=x1}
```

| what | route | measured at HEAD |
|---|---|---|
| relative symbol name | `get_sym_type` → `abs_sym_path` | sentinel 1, **host file created** |
| absolute symbol name | `load_inst` → `rel_sym_path` | sentinel 1, **host file created** |
| counting payload, `xschem load` | as above | `::SYMP_HIT` = **1** |
| counting payload, `xschem netlist` | `sanitized_abs_sym_path` in the netlisters | `::SYMP_HIT` = **3** |

The engine then prints `l_s_d(): Symbol not found: p} {} ; …` — i.e. the literal
name really is treated as a filename, which is the non-vacuity receipt.

## 3. Why it cannot be deferred out of the 0816 unit

`scheduler.c:7767` (`load_new_window`) and `:9028` (`new_schematic`) feed their
argument into `abs_sym_path()`. Replacing only their `regsub {^~/}` splice leaves
those two verbs fully exploitable, so **0816 cannot honestly be reported swept
without this**.

## 4. Recommended fix (from the crew's plan, decision D7)

Hand the string over as a GLOBAL VARIABLE — the `save.c` `backannot_refuse_digital()`
route 0817 names as an in-tree answer — and keep `return tclresult()`:

```c
tclsetvar("__abs_symp_name", s ? s : ""); tclsetvar("__abs_symp_ext", ext ? ext : "");
tcleval("abs_sym_path $::__abs_symp_name $::__abs_symp_ext");
return tclresult();
```

A variable substitution's result is ONE word and is never re-parsed, so no content
can escape. Signatures, return storage and the Tcl-side procs are unchanged.
Rejected: `Tcl_Merge`/`Tcl_EvalObjv` (a rewrite of three two-line functions), and
any `subst` flag (0812 §1: `-nocommands` still runs `$a([...])`).

## 5. Red rows already written

`tests/headless/test_raw_read_dispatch.tcl`, group **SYMP** (true headless):
SYMP01, SYMP02, SYMP03, SYMP04, SYMP07 are RED at HEAD; SYMP05 (non-vacuity) and
SYMP06 (anti-hollow golden `** sym_path:` line with a SPACE in the path) are green
and must stay green.

---

## 6. FIXED — what changed

`src/actions.c`, all three wrappers, §4's recommendation taken verbatim:

```c
tclsetvar("__abs_symp_name", s ? s : "");
tclsetvar("__abs_symp_ext", ext ? ext : "");
tcleval("abs_sym_path $::__abs_symp_name $::__abs_symp_ext");
return tclresult();
```

and the sanitized variant keeps its `regsub` **as a command on a variable**:
`abs_sym_path [regsub {\(.*} $::__san_symp_name {}] $::__san_symp_ext`.

Signatures, return storage (the interpreter result, held as a `const char *` by
~70 call sites) and the Tcl-side procs are unchanged. The globals are deliberately
**not** unset: `Tcl_UnsetVar` can reset the interpreter result, which *is* the
return value here.

**One behaviour delta, recorded rather than left to be discovered.** The old
wrappers passed a `NULL` `s` straight into `my_snprintf("%s")`, so a NULL name
became the literal string `"(null)"`; the new ones map NULL to `""`. No caller
depends on `"(null)"` (T1, T2 and every T3 suite are unchanged), but it is a real
difference, not a no-op.

## 7. AFTER

`tests/headless/test_raw_read_dispatch.tcl`, group **SYMP** (true headless):

* **SYMP01** `{0 0}` — relative name, `get_sym_type` → `abs_sym_path`.
* **SYMP02** `{0 0}` — absolute name, `load_inst` → `rel_sym_path`.
* **SYMP03** counting payload on `xschem load` → **0** (was 1).
* **SYMP04** counting payload on `xschem netlist` → **0** (was 3).
* **SYMP07** source scan: zero `{%s}` brace splices in `src/actions.c` (was three).
* **SYMP06** anti-hollow: `** sym_path: <dir>/symp_lib/sy m.sym` — a symbol whose
  absolute path contains a **space** still resolves. `tests/headless/run.sh`'s six
  golden netlists carry `** sym_path:` lines emitted by `sanitized_abs_sym_path()`
  and are `HARNESS PASS 6/6`, which is the shipped-corpus half of the same check.
* **SYMP05** non-vacuity: the engine still reports
  `Symbol not found: p} {} ; incr ::SYMP_HIT; list {a` — the literal name really
  reaches the resolver and is treated as a filename.

## 8. Sabotage matrix — and TWO rows that did not go red

| variant | predicted red | observed |
|---|---|---|
| **SAB-C1** `abs_sym_path` + `rel_sym_path` back to the brace splice | SYMP01,02,03,05,07 + SC07 (6) | **10 red** — five of the six predicted, plus five unpredicted (SC01, SC02, SC03, SC08, SYMP04). **SYMP05 stayed green.** |
| **SAB-C2** only `sanitized_abs_sym_path` back to the brace splice | SYMP04, SYMP07 (2) | **1 red** — SYMP07 only. **SYMP04 stayed green.** |

Both misses were then measured, not guessed:

* **SYMP05 does not test what its failure text claims.** It greps
  `l_s_d(): Symbol not found:` (`src/save.c:5362`), which prints `transl_name` — a
  value produced **before** the wrapper is called. It proves the name reached the
  **loader**, not the path resolver, so it cannot stop SYMP01-04 from going vacuous
  for the reason it states. (The other emitter, `src/save.c:4996` in
  `get_sym_type`, is `dbg` level 1 and never reaches a default log.)
* **`sanitized_abs_sym_path` has NO driven row at all.** A dedicated probe measured
  `SAN_HIT=0` on both `xschem load` and `xschem netlist`: a payload symbol name
  never reaches that wrapper, because the netlisters
  (`spice_netlist.c:688/701` and the four siblings) call it with the name of a
  symbol that actually **loaded**, and a payload name is replaced by `missing.sym`.
  The three netlist-time counts SYMP04 observed under SAB-C1 come from
  `abs_sym_path`/`rel_sym_path`, not from the sanitized wrapper. So that wrapper is
  covered **only** by the SYMP07 source scan (plus SYMP06/T2 for the benign path) —
  directly contradicting the plan's justification that SYMP04 "proves the
  netlist-time wrapper is covered by a driven row and not only by the grep guard".

**Both are left open, and neither is cosmetic**: a source-scan guard is deleted by
whoever next edits the file, and the row that was supposed to be its backstop does
not exist. Fixing them needs a fixture with a **real generator symbol** on the
library path, so that a name reaching `sanitized_abs_sym_path` is a name that
loaded.

## 9. Still open

* The two coverage gaps in §8.
* A new failure mode this fix introduced that the string splice did not have: the
  three wrappers now depend on `__abs_symp_name` / `__abs_symp_ext` /
  `__rel_symp_name` existing as **scalars**. If a user's rc array-ifies one, or
  puts a failing write/read trace on it, `tcleval` fails and `tclresult()` — the
  Tcl **error message** — is returned as a filesystem path to ~70 call sites.
  GUARD3 (`test_raw_read_dispatch`) pins read traces only in `src/*.tcl`, not in a
  user's rc. Low likelihood, silent if it happens.
* Those three global names are now reserved tree-wide, and are never unset, so the
  last symbol name handled persists in the global namespace.
