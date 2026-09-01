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

---

## 9. RESOLUTION — fixed 2026-08-26, nine sites converted, guard extended

Status: **FIXED.** `src/scheduler.c` (8 sites) + `src/callback.c` (1 site),
rebuilt; guard row `FN07` extended; 13 new driven rows.

### 9.1 What changed

Every site below now passes its data as a `$::` global through the existing
`tcl_call()` (`src/util.c`, added by the 0827+0817+0828 item). **No second
mechanism was invented**, per §6.

| site | was | now |
|---|---|---|
| `scheduler.c:2708` | `tclvareval("cell_views {", argv[2], "} {", argv[3], "}")` | `tcl_call("cell_views", argv[2], argv[3], NULL)` |
| `scheduler.c:2726` | `tclvareval("ciform::open {", argv[2], "}")` | `tcl_call("ciform::open", argv[2], NULL, NULL)` |
| `scheduler.c:5527` | `tclvareval("library_inst_lcv {", inst[n].name, "}")` | `tcl_call("library_inst_lcv", inst[n].name, NULL, NULL)` |
| `scheduler.c:8068` | `tclvareval("library_resolve {", argv[2], "}")` | `tcl_call("library_resolve", argv[2], NULL, NULL)` |
| `scheduler.c:8077` | `tclvareval("library_cells {", argv[2], "}")` | `tcl_call("library_cells", argv[2], NULL, NULL)` |
| `scheduler.c:8097` | `tclvareval("libmgr::open {", argv[2], "}")` | `tcl_call("libmgr::open", argv[2], NULL, NULL)` |
| `scheduler.c:9707` | `tclvareval("set INITIALINSTDIR [file dirname {", …, "}]")` | copy → `tcl_call("file dirname", …)` → `tclsetvar()` |
| `callback.c:559` | identical to the above | identical to the above |
| `scheduler.c:12393` | `tclvareval("xschem replace_symbol {", num, "} {", …, "} fast")` | `tcl_call("xschem replace_symbol", num, dir_pin_sym(tgt), "fast")` |

At `:5527` the very next statement is `if(tclresult()[0] == '\0')` — the *only*
thing separating "not in a Cadence library" from a hit. `tcl_call()` returns
`tclresult()` and runs nothing after `tcleval()`, so those error semantics are
byte-identical. A comment in the source says not to insert anything between them.

### 9.2 The one non-mechanical site

`scheduler.c:9707` / `callback.c:559` were **not** a rename. The splice sat inside
a `[file dirname {...}]` **command substitution** (0829's bracket problem on top
of 0827's brace problem), and its argument is `abs_sym_path()`, which *returns
`tclresult()`* — which `util.c:1122-1126` forbids handing straight to
`tcl_call()`, because `tclsetvar()` writes through the interpreter and
invalidates that pointer. The substitution was **deleted outright** rather than
rebuilt: each result is copied to the heap (`my_strdup2`/`my_free`, no fixed
buffer — a symbol reference has no length bound and a bounded copy would truncate
silently, the very defect 0827 removed from `cellview_sch_path`), and the
assignment is `tclsetvar("INITIALINSTDIR", …)` = `Tcl_SetVar`/`TCL_GLOBAL_ONLY`,
exactly what the old global-level `set` did.

### 9.3 §4 IS UPGRADED, ON MEASUREMENTS

§4 recorded `scheduler.c:9707` and `callback.c:559` as "verified present, not
individually driven" and forbade upgrading without a measurement. **Both were
driven, twice each, by independent agents.** `:9707` headless: load the evil
fixture, `select_all`, `xschem place_symbol devices/lab_pin.sym {}` → host file
created and `$::INITIALINSTDIR == y` (the payload's own `list {y}` tail returned
*through* the command substitution). `callback.c:559` on `:99` with a real
`event generate .drw <KeyPress> -keysym I` and `new_file_browser 0` → host file
`0 → 1`. Both are now standing test rows (`LM10`/`LM11`, `CI17`).

### 9.4 ⚠ CORRECTION TO §4: `scheduler.c:12393` IS NOT A VECTOR

§4 lists `replace_symbol` alongside the others. It does not belong there. **Both**
spliced words are program-derived: `num` is `my_snprintf(num, S(num), "%d", i)` of
a loop index (`:12392`) and `dir_pin_sym()` returns one of three compile-time
literals (`src/paste.c:56-61`). No attacker data reaches it. It was converted for
**hygiene and FN07 uniformity only**, it was not driven, and it must not be
counted as a tenth RCE.

### 9.5 The guard (§6), and why the obvious extension was not enough

`tests/headless/test_raw_read_dispatch.tcl` `FN_PROCS` gained **eight** entries,
six single-word and **two multi-word**. Measured against FN07's own loop: the six
single-word 0831 names find **6 of the 9** sites and *silently miss*
`scheduler.c:9707`, `scheduler.c:12393` and `callback.c:559`, whose lines read
`tclvareval("set INITIALINSTDIR [file dirname {` and
`tclvareval("xschem replace_symbol {` — words between the paren and the name.
Adding `{xschem replace_symbol}` and `{set INITIALINSTDIR [file dirname}` gives
**9/9**. A single-word-per-proc extension would have shipped a guard still blind
to both file-derived `INITIALINSTDIR` doors — this issue in a fresh coat.
FN07's "⚠ WHAT IT DOES NOT COVER" prose was rewritten in the same edit, and now
names what is still live rather than staying silent about it.

A **shape** scan (`tclvareval("<anything> {`) was considered and rejected,
measured: it fires on ~10 non-defects including `:7828`/`:7849`, which §5 records
as already guarded. That would be a standing red, and a standing red is a defect.

### 9.6 STILL LIVE WHEN THIS ITEM STOPPED — named, not swept

* **0832** — `scheduler.c:8107` `log_action("xschem library_manager {%s}", argv[2])`
  is unguarded where its four `tcl_braceable()`-guarded siblings are not. Driven
  end to end on the *fixed* binary: the log line replays and executes
  (`after-replay host=1 r=|y|`).
* **0833** — `move.c:9135` `c_toolbar::add {` + `abs_sym_path(sym->name)`
  (file-derived) and `scheduler.c:7472` `join [lsort … {` + `.sch` net names with
  `sep` spliced unquoted from argv. Both verified present, **neither driven**.
  Plus two recorded-not-chased: `hilight.c:1113-1120` (`#ifndef __unix__`, not
  compiled here) and `xinit.c:3392` (first-run mkdir only).
* **0834** — `xschem callback` segfaults under `--nogui`, which is why
  `callback.c:559` needs X to drive at all.

### 9.7 Claims (§8, 0823 — binding)

A `.sch` is executable **by design**: `tcleval(` in a text record fires on DRAW
via `token.c:78 tcl_hook2()`, and `scheduler.c:9708` / `callback.c:560` call
`tcl_hook2()` on the instance name *themselves* — no conversion here changes
that. This resolution may **not** be read as "opening a schematic no longer runs
their Tcl", "the injection family is closed", or "an untrusted `.sch` is safe to
open". What it says is narrower and is the whole point: these nine sites no
longer execute **without saying so**, and 0832 / 0833 are still live.

## 10. The sabotage matrix

Eight variants, each a **renamed callee** (never a `/* SABOTAGE */` comment), each
followed by `cp` + `touch` restore, rebuild, and a re-assert of the baseline.

| variant | what it neutralizes | predicted red | observed |
|---|---|---|---|
| `sab_lcv_concat` | `tcl_sab_concat` rebuilds the pre-fix splice at `scheduler.c:5536` only | LM01, LM02 | **exact** — `2 FAILED (135 passed)`; LM03 and FN07 correctly green |
| `sab_argv_concat` | same twin at `:2708`/`:8068`/`:8077` | LM04, LM05, LM06 | **exact** — `3 FAILED (134 passed)`; LM07/08/09 green |
| `sab_hasx_concat` | same twin at `:2726` + `:8097` (`:99`, openbox 3.6.1 live) | CI16, LL8 | **exact** — both `pwned=1 host=1 answer='y'` |
| `sab_instdir_concat` | `tcl_sab_setdir` rebuilds `set INITIALINSTDIR [file dirname {…}]` from the **uncopied** `symref`, at `:9707` + `callback.c:559` | LM10, LM11, CI17 | **exact** — LM11 saw `INITIALINSTDIR == y`; LM12/CI18 green |
| `sab_noop_all` | `tcl_call_nop` returning `""` over all 9 new sites | 13 rows | **11 of 13** — see §10.1 |
| `sab_literal_revert` | exact pre-fix source text at `:5527` + `callback.c:559`, no helper | FN07, LM01, LM02, CI17 | **exact** — FN07 named **both** sites, see §10.2 |
| `sab_replace_symbol_nop` | `tcl_call_nop` at `:12393` only | `test_pin_type_edit`, `test_perform_action_replace_symbol` | **1 of 2** — see §10.1 |
| `sab_instdir_noop` | `tclsetvar_nop` over the assignment at `:9707` + `callback.c:559` | LM12, CI18 | **exact** — LM12 got `NOTSET 0`; LM10/LM11/CI17 green |

**The result that matters most is a negative one.** Under `sab_noop_all` — the
feature gutted to a no-op — **every negative row stayed green** (LM01/02/04/05/06/
10/11, CI16, CI17, LL8). That is issue 0828's thesis restated as a measurement:
the injection rows cannot police the feature's survival, and the positives are not
decoration.

### 10.1 PREDICTED REDS THAT DID NOT APPEAR — all three were real, all are now filed

Recorded because a predicted red that silently does not appear is the one result a
sabotage pass exists to surface.

1. **`sab_noop_all`: LL1 did not go red, and NOTHING in `test_lib_manager_launch`
   did — the file scored `RESULT: ALL PASS` with `libmgr::open`'s argument path
   gutted.** A **real hole**, not a mis-attribution: LL1/LL6 launch bare and take
   the untouched `else tcleval("libmgr::open")` branch, and a repo-wide grep found
   **no** test anywhere driving the argument form. Fixed in this item's own commit
   by a new **LL9**; filed as **0835**.
2. **`sab_noop_all`: CI1a did not go red.** Mis-attribution only — CI1a calls the
   verb bare. The converted path at `:2729` *is* covered, by CI13a/CI13c/CI13d and
   CI6b-CI6h/CI7e (11 rows measured red). Comment corrected; **0835**.
3. **`sab_replace_symbol_nop` and `sab_noop_all`: `test_perform_action_replace_symbol`
   stayed `ALL PASS`** with the converted caller gutted. It tests the *subcommand*
   (the callee); `:12393` is a *caller*. **`test_pin_type_edit` is the only cover**
   for that site (5 rows red). Comment corrected; **0835**.

### 10.2 The multi-word needle is load-bearing, and it was measured

`sab_literal_revert` made FN07 name **both** `scheduler.c:5536` (single-word
`library_inst_lcv` needle) **and** `callback.c:559` (multi-word
`{set INITIALINSTDIR [file dirname}` needle). Verify-B then re-ran with the two
multi-word entries **stripped**: FN07 named only `scheduler.c:5536` and missed
`callback.c:559` entirely. So the obvious single-word-per-proc extension of
`FN_PROCS` would have shipped a guard still blind to both file-derived
`INITIALINSTDIR` doors — this issue in a fresh coat. §9.5's reasoning is confirmed
by measurement, not by reading.

## 11. STILL OPEN — the adversary's residual risks

The adversary did **not** refute the central claim: the headline repro is
`LMX=0 host=0`, all nine sites are converted, the verbs still work. What follows
is what it could not close.

1. **⚠ SIX MORE SPLICES OF THIS EXACT FAMILY, IN THREE FILES NOBODY SCANNED.**
   `draw.c:121`, `psprint.c:1790`, `svgdraw.c:1108` splice
   `get_cell(xctx->sch[xctx->currsch],0)` — the schematic's **own path**, i.e.
   0817 §Z.2's crafted-filename vector — into a `save_file_dialog {…}` call; and
   `draw.c:126`, `psprint.c:1795`, `svgdraw.c:1113` splice the dialog's returned
   filename into `tclvareval("file dirname {", xctx->plotfile, "}")`. **Verified
   present by reading, NOT driven** (has_x, plus a modal dialog that must return
   before the payload's second command runs). **None of the three files is in
   `FN_FILES`**, so extending `FN_PROCS` does not reach them. Folded into **0833**.
2. **`tcl_call_core()` does not check `tclsetvar()`'s failure.** `tclsetvar`
   (`scheduler.c:14536`) only prints to `errfp` when `Tcl_SetVar` returns NULL,
   after which `tcl_call_core` evaluates with a **stale** `$::__tcl_call_a1` from
   the previous call. Reaching it requires `::__tcl_call_a1` to be an array or to
   carry a failing write trace — i.e. prior Tcl execution — so it is **not** an
   escalation over the by-design `tcleval(` path. But it is a shared-global
   weakness inherited by **all ~81 converted call sites**, not just these nine, and
   it is undocumented in `util.c`'s header comment.
3. **CI17 can go vacuous without CI18 noticing.** The two rows load *different*
   schematics; CI18 proves key-`I` works for a **resolvable** symbol. If a future
   change made `start_place_symbol` bail early only for an **unresolvable**
   reference — which the evil fixture is (`l_s_d(): Symbol not found:` is printed
   on that path) — CI17 would silently stop driving while CI18 stayed green.
   Non-vacuous **today**: measured red under `sab_literal_revert`.
4. **0833's two original sites remain undriven and could not be driven.**
   `move.c:9135` fires only from `move_objects(END)` under `PLACE_SYMBOL`,
   reachable only through a real button release — and `xschem callback` segfaults
   headless (**0834**). "Verified present, not driven" is the honest state; it must
   not be upgraded without a `:99` button drive.
5. **`library_cells` / `cell_views` pass their now-literal argument into
   `glob -nocomplain [file join $lpath $cell *]`**, so `*`, `?`, `[…]` and `{a,b}`
   in a cell name are **glob** metacharacters. Pattern matching only — no
   execution, and strictly better than the pre-fix behaviour — but a crafted cell
   name can still make the verb enumerate directories the caller did not ask for.
   Pre-existing, out of this item's scope, previously unrecorded anywhere.
6. **The `:0` debt stands.** Every measurement here is Xvfb `:99` (openbox 3.6.1
   live) or `--nogui`. CLAUDE.md's rule is that a GUI feature's suite runs on `:0`
   once before it is called done; CI16/CI17/CI18 and LL8/LL9 are GUI rows that have
   not.
7. **`grep -rn SABOTAGE src/` was blind for the whole sabotage window — 0807 §10,
   demonstrated live.** Twice, `util.c` + `xschem.h` carried `tcl_sab_concat`,
   `tcl_sab_setdir`, `tcl_call_nop`, `tclsetvar_nop`, `nm src/xschem` listed all
   four as `T`, and the prescribed `grep` returned **empty** throughout (the marker
   comment was lowercase "verify-b sabotage helpers"). Verify against `nm` and the
   real spellings, never against the uppercase word. Clean at commit: `grep` for
   all four spellings = 0 hits, `nm` count = 0, `util.c`/`xschem.h` byte-clean.
