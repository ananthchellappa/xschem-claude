# 0831 — the library-manager brace-concat sinks survived the 0827+0817 sweep, and one of them is a driven file-derived RCE

Status: **measured LIVE on the 0827+0817+0828 tree, NOT FIXED.**
Found by that item's **adversary pass** and **independently re-driven by its
write-up agent** before filing.
Severity: **high** — `library_inst_lcv` is the same class and the same severity as
0827 (a mailed `.sch`, a stock gesture, attacker Tcl runs), and it was left live by
an item whose own report said the load/descend family was swept.
Family: 0812 / 0816 / 0817 / 0821+0822 / 0825 / 0827 / 0829.

## 1. Why this issue exists at all

0817 §Z.4 was written because a family was reported swept while a sibling site
stayed live. **It happened again, in the same sentence of the same list.**

0817's own "rest of the sweep" section reads, verbatim:

> `scheduler.c` `cellview_path` / `cell_views` / `ciform::open` / `library_inst_lcv` /
> `library_resolve` / `library_cells` / `libmgr::open` / `file normalize` /
> `replace_symbol` / `alert_` / `update_recent_file` / `xschem_recover_backup`;

The 0827+0817+0828 item fixed **`cellview_path`** — the first name on that line —
and `update_recent_file` and `xschem_recover_backup`. It left **`cell_views`,
`ciform::open`, `library_inst_lcv`, `library_resolve`, `library_cells`,
`libmgr::open`** and `replace_symbol` concatenating, and its `FN07` source-scan
guard does not list any of those procs, so the anti-half-sweep guard stayed
**green while the sinks were live**.

That is the exact defect the brief warned against. Record it as such.

## 2. The sharpest: `library_inst_lcv`, file-derived, DRIVEN

`src/scheduler.c:5527`, in the `xschem get_inst_lcv` branch:

```c
      n = xctx->sel_array[0].n;
      /* delegate the lib/cell/view reverse-map to Tcl, passing the instance's
       * symbol reference (resolved to an abs path Tcl-side via abs_sym_path). */
      tclvareval("library_inst_lcv {", xctx->inst[n].name, "}", NULL);
```

`xctx->inst[n].name` is the instance's **symbol reference, read straight out of
the `.sch`** — the identical data path 0825 closed for the sym-path wrappers and
0827 closed for `cellview_sch_path`. A `}` in it closes the brace group and the
remainder parses as script; `\}` is the `.sch` format's own escape for a literal
brace, so the fixture is **well-formed, not corrupt**.

### Measured — write-up agent, 2026-08-26, on the FIXED 0827+0817+0828 binary

Fixture, one `.sch`, on-disk bytes (single-backslash format escape):

```
C {x\} ; set ::LMX 1 ; exec touch <D>/LMXHOST ; list \{y} 0 0 0 0 {name=x1}
```

Driver — `--nogui`, no dialog, the gesture is select-instance then the Cadence
Library Manager's own reverse-map verb:

```tcl
set ::LMX 0
xschem load <D>/evil.sch
xschem select_all
catch {xschem get_inst_lcv 0} r
puts "LMX=$::LMX host=[file exists <D>/LMXHOST] r=$r"
```

```
LMX=1 host=1 r=y
```

`LMXHOST` created. **VERDICT=PWNED.** The adversary measured the same, 3/3
deterministic; this is an independent second reproduction.

## 3. The argv-derived siblings

The adversary drove `cell_views` (`scheduler.c:2708`) to Tcl execution with a
sink-shaped two-argument payload `x} {y} ; set ::CVX 1 ; list {z` → `CVX=1`.
`ciform::open` (2726), `library_resolve` (8068), `library_cells` (8077) and
`libmgr::open` (8097) share the identical spelling.

⚠ **Do not record these as "protected because the first token errors on wrong
args."** 0817 §Z.2 already established that a wrong-args abort is an *accident of
payload shape*, not a defence — a payload shaped for the sink defeats it, which
is precisely what the `cell_views` drive demonstrates.

## 4. Two more, found by the write-up agent, not in the adversary's list

`src/scheduler.c:9707` and `src/callback.c:559`, identical:

```c
      tclvareval("set INITIALINSTDIR [file dirname {",
           abs_sym_path(tcl_hook2(xctx->inst[xctx->sel_array[0].n].name), ""), "}]", NULL);
```

File-derived (`inst[].name` again), and doubly exposed: the splice sits inside a
`[file dirname {...}]` **command substitution**, so this has 0829's bracket
problem as well as 0827's brace problem. **Verified present; not individually
driven** — say so, do not upgrade it without a measurement.

`src/scheduler.c:12393` `xschem replace_symbol {..} {dir_pin_sym(tgt)} fast` is on
0817's list and also still concatenates.

## 5. Explicitly NOT defects (checked, so the next crew does not re-derive)

* `scheduler.c:7819` / `:7840` `xschem load {f}` — **already guarded** by
  `is_pristine_untitled() && tcl_braceable(f)`, with a `new_schematic()` C-string
  fall-through. Issue 0022 solved this one. Leave it.
* `scheduler.c:7798` `file normalize` — **commented out** already.
* `token.c:90` `tclpropeval2` — Tcl evaluation from a `.sch` **by design**
  (0817's own "Explicitly NOT a defect" section, and 0823). Do not "fix" it.

## 6. The fix, when someone takes it

`tcl_call()` / `tcl_call_mid()` already exist in `src/util.c` from the
0827+0817+0828 item and are exactly the right shape:
`tcl_call("library_inst_lcv", xctx->inst[n].name, NULL, NULL)`. This is a
mechanical conversion of ~10 sites, not a design problem.

**And extend `FN07`'s `FN_PROCS` list** in
`tests/headless/test_raw_read_dispatch.tcl` to cover `cell_views`,
`ciform::open`, `library_inst_lcv`, `library_resolve`, `library_cells`,
`libmgr::open` and `replace_symbol`. The guard is only as good as its proc list,
and its blind spot is what let this ship.

## 7. Ladder / decision

**Not fixed in the 0827+0817+0828 item deliberately** (ladder **L2**): that item
had already converted 72 call sites across 13 files and rebuilt; taking another
family late in an unattended run, after Verify-A/B had already measured the tree,
would have invalidated every tier number in the receipt. The brief's own rule is
"STOP AFTER A COMPLETE UNIT and say EXACTLY which sites are still live" — so the
unit was closed and this was filed with a driven repro instead.
**REJECTED:** folding it into 0817 as another inventory bullet — burying a
*driven* vector in a 40-line list is what produced 0817 §Z.4 in the first place.

## 8. Claims discipline (0823)

A `.sch` is executable **by design** (`tcleval(` in a text record fires on DRAW via
`token.c:78 tcl_hook2()`, measured). Nothing here may be written up as "the
injection family is closed" or "an untrusted `.sch` is safe to open". The honest
form is that these sites still execute **without saying so**.
