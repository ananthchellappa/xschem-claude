# 0827 — cellview_sch_path() splices a `.sch` `schematic=` attribute into a Tcl script, so descending into a block on someone else's schematic runs their Tcl

Status: **measured LIVE on the FIXED 0821+0816+0817 tree, NOT FIXED.**
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
