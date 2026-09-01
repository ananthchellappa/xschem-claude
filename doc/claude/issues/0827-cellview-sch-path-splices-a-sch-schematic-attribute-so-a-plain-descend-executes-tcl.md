# 0827 — cellview_sch_path() splices a `.sch` `schematic=` attribute into a Tcl script, so descending into a block on someone else's schematic runs their Tcl

Status: **FIXED** by item 0827+0817+0828 (2026-08-26). Originally measured LIVE on the
FIXED 0821+0816+0817 tree.
Found by that item's adversary pass and **independently re-driven by its write-up
agent** before filing. Severity: **high, and its trigger is at least as ordinary as
0821's** — 0821 needs the Graph dialog opened; this needs one mailed `.sch`, a
**stock library symbol**, and a descend.
Family: 0812 (fixed, C raw paths) / 0816 (fixed) / 0821+0822 (fixed) / 0825
(fixed) / **0817** (open — this is an 0817-class site that 0817 under-rates).

## 1. The sink

`src/actions.c:4215-4219`:

```c
static const char *cellview_sch_path(const char *ref)
{
  char c[PATH_MAX + 100];
  my_snprintf(c, S(c), "cellview_path {%s} schematic", ref);
  return tcleval(c);
}
```

Called at `:4291` with `sch` — the instance's **`schematic=` property value, read
straight out of the file** — and at `:4314` with `sym->name`. The value sits inside
a brace group of a script that is then evaluated: a `}` in it closes the group and
the remainder is parsed as script. `\}` is the `.sch` format's own escape for a
literal brace, so the fixture below is **well-formed**, not corrupt.

## 2. Measured, on the FIXED binary (write-up agent, 2026-08-25)

Fixture — note it references only `examples/rlc.sym`, a symbol that ships with
xschem, so nothing but the one `.sch` has to be delivered:

```
C {examples/rlc.sym} 0 0 0 0 {name=x1 schematic="x\} schematic ; set ::CVPWN 1 ; exec touch <D>/CVHOST ; list \{y"}
```

```
after-load     CVPWN=0 host=0
after-descend  rc-res=0 CVPWN=1 host=1
```

`xschem descend -inst x1`, `--nogui`, no dialog, no gesture beyond the descend —
sentinel set and **the host file created**. The adversary also fired it through
`xschem get_sch_from_sym 0`, whose result came back as the payload's own tail
(`y schematic`), which is the non-vacuity receipt: the string really is being
parsed as script.

## 3. Why this is filed rather than folded into 0817

0817's inventory does list `cellview_path`, but under *"the rest of the sweep
(same class, **LOWER REACH**; verified present, not individually driven)"*, and it
attributes it to `scheduler.c`. Three corrections:

1. The live one is **`actions.c`**, not `scheduler.c`.
2. It is now **driven**, not merely present.
3. Its reach **exceeds 0817's own nominated sharpest reachable-on-unix site**
   (`actions.c:3784` `launcher`, which needs a gesture on a `url` property). This
   is descend-into-a-block: one file, no X, no dialog.

## 4. Fix direction (none taken)

The same route the sibling fixes took, and it is three lines:

```c
tclsetvar("__cellview_ref", ref ? ref : "");
return tcleval("cellview_path $::__cellview_ref schematic");
```

A variable substitution's result is one word and is never re-parsed. Precedent in
tree: `src/save.c` `backannot_refuse_digital()`, and now the three sym-path
wrappers in `src/actions.c` (issue 0825), which took exactly this shape.

⚠ **Do not stop at this one site.** `cellview_path` is called from Tcl in a dozen
places with `"$lib/$cell"` composed from file-derived names
(`create_instance.tcl`, `property_form.tcl`, `alt2_toggle_view.tcl`,
`ase_window.tcl`, `library_manager.tcl`); those are Tcl-to-Tcl and quote properly,
but the C wrapper is the one that concatenates.

## 5. Acceptance

1. The §2 fixture, descended into, creates **zero** host files and leaves the
   sentinel at 0 — driven through `xschem descend -inst`, true headless.
2. `xschem get_sch_from_sym` on the same instance returns a **path or empty**, not
   the payload's tail.
3. Non-vacuity: the literal `schematic=` value still reaches the resolver — the
   engine must still report it as a name it could not find.
4. Anti-hollow: a real lib-qualified `schematic=lib/cell` still resolves to
   `<libpath>/<cell>/schematic/<cell>.sch` and descend still works
   (library-manager Phase 4; `doc/claude/code_analysis/library_manager_design.md`).

---

## 6. FIXED — item 0827+0817+0828, 2026-08-26

### 6.1 What changed

`cellview_sch_path()` is now one line:

```c
static const char *cellview_sch_path(const char *ref)
{
  return tcl_call("cellview_path", ref ? ref : "", NULL, "schematic");
}
```

`tcl_call()` (new, `src/util.c`) hands `ref` to the interpreter as a **global
variable** and evaluates `cellview_path $::__tcl_call_a1 schematic`. The command
name and the trailing word are program text; the data word is never concatenated,
and a variable substitution's result is one word that is never re-parsed. This is
the `backannot_refuse_digital()` / 0825 route, **not** a new resolver — it expands
nothing and resolves nothing, so 0812's `strcmp()` registry key is untouched and
0820's double-resolution exposure is not re-opened. The `PATH_MAX + 100` buffer
and its silent mid-escape truncation are gone with it.

**Both doors close together**, because both go through this one wrapper. The
sibling `xschem cellview_path` verb (`scheduler.c:2699`) was converted in the same
pass, per §4's "do not stop at this one site".

### 6.2 Measured AFTER, on the rebuilt binary

BEFORE (§2, and the lead's independent reproduction):

```
after-load     CVPWN=0 host=0
after-descend  CVPWN=1 host=1   VERDICT=PWNED
```

AFTER, same fixture, same driver:

```
after-load     CVPWN=0 host=0
after-descend  CVPWN=0 host=0
```

Site 2 (`:4314`, `sym->name` via an embedded subcircuit whose `C{}` reference name
carries the format brace-escape) — BEFORE `CVPWN2=1 host2=1`, AFTER
`CVPWN2=0 host2=0`.

### 6.3 The acceptance rows, all four met

| § 5 row | test | result |
|---|---|---|
| 1. fixture descends, no host file, sentinel 0 | `CVP01`, `CVP02` | `{0 0}` |
| 2. `get_sch_from_sym` returns a path or empty, not the payload tail | `CVP03` | pass |
| 3. **non-vacuity** — the literal value still reaches the resolver | `CVP04` | answers with the whole payload bytes, un-truncated: `.../x} schematic ; set ::SC_PWNED 1 ; exec touch .../HOST_CVP03 ; list {y` — it reached the resolver whole, it is simply **no longer script** |
| 4. anti-hollow — a real lib-qualified descend still works | `CVP06`, `test_descend_views` D1/D2/D4 | pass |

The sharpest row is **`CVP05`**: a test-local recorder over `cellview_path` (a proc
**rename**, not a read trace — GUARD3/0819 untouched) sees the proc called exactly
**once with exactly 2 arguments**, and `arg1` is the **entire payload verbatim**.
Pre-fix, `arg1` was the single word `x`.

### 6.4 Sabotage

`SAB-2` restored the pre-fix `my_snprintf`+`tcleval` body: **5/5 predicted rows
red** (CVP01 `1 1`, CVP02 `1 1`, CVP03, CVP05 `arg1 == x`, CVP06), plus CVP04 and
FN07 as bonus. The fix is fully load-bearing.

`SAB-1` (wrapper inert) reddened `CVP05` and `test_descend_views` D1/D2/D4 — but
**`test_cellview_resolve` stayed ALL PASS**. Recorded because it corrects a
mislabelled counterweight: **CV1-CV12 drive the `xschem cellview_path` verb, never
the `actions.c` wrapper**, so they are *not* the anti-hollow suite for the descend
route. `test_descend_views` D1/D2/D4 are. (D3 is not either — legacy flat descend
resolves via `abs_sym_path` and never enters `tcl_call`.)

### 6.5 ⚠ What this does NOT claim (0823)

A `.sch` is executable **by design**: `tcleval(` in a text record fires on DRAW via
`token.c:78 tcl_hook2()`, measured. This fix removes a path that executed
**without saying so**. It does **not** mean opening a schematic no longer runs its
Tcl, that the injection family is closed, or that an untrusted `.sch` is safe to
open. **See issue 0831 — sibling sinks in this same family are still live.**
