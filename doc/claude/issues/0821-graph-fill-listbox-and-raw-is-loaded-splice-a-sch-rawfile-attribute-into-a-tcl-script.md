# 0821 — graph_fill_listbox() splices a .sch `rawfile=` attribute into a Tcl script, so opening the Graph dialog on someone else's schematic runs their Tcl

Status: **FIXED 2026-08-25, item 0821+0816+0817. The evaluator is GONE from all three
graph attribute reads and `raw_is_loaded` is DELETED. Four `.sch`-delivered payload
shapes went host-file-created=1 → 0 through the real user door (open the file, open the
Graph dialog). Record of the fix: §6-§11 below. Issue 0822 (`autoload` / `sim_type`) was
fixed by the same change and is closed against this record.**
Found by the 0812-retry adversary pass. Family: 0812 / 0816 / **0817** (the Tcl-side
brace-group splices). This is the same defect class 0812 closed in C, still open in Tcl.
Severity: **high** — a `.sch` file is a document people mail each other.

## 1. The two sites

`src/xschem.tcl:4775`, inside `graph_fill_listbox` (LIVE — 7 call sites: the Graph
dialog's Refresh, its listbox rebuild, `-command`, and three dialog entry points):

```tcl
  set rawfile [xschem getprop rect 2 $graph_selected rawfile]
  if {$rawfile ne {}} {
    if {![catch {eval uplevel #0 {subst $rawfile}} res]} {
      set rawfile $res
    }
  }
```

`src/xschem.tcl:4842`, inside `raw_is_loaded` (**DEAD** — zero callers tree-wide, which is
the only reason it is not a second live door):

```tcl
  set r [catch "uplevel #0 {subst $rawfile}" res]
```

`graph_fill_listbox` also runs the same shape over the `autoload` and `sim_type`
properties at `:4772` and `:4779`.

## 2. Measured, in tclsh 8.6.13

```tcl
proc p {} {
  set rawfile {LOCAL[set ::HIT 1]}
  set ::HIT 0
  set r [catch {eval uplevel #0 {subst $rawfile}} res]
  puts "4775-shape: rc=$r res=$res HIT=$::HIT"
}
p          ->  4775-shape: rc=0 res=LOCAL1 HIT=1

proc q {} {
  set rawfile "a\}; set ::HIT2 1; list \{b"
  set ::HIT2 0
  set r [catch "uplevel #0 {subst $rawfile}" res]
  puts "4842-shape: rc=$r res=$res HIT2=$::HIT2"
}
q          ->  4842-shape: rc=0 res=b HIT2=1
```

Both execute. Note this **corrects the adversary's own characterisation** of `:4775`: it
reported that the line substitutes the *global* `rawfile` rather than the .sch-derived
local. It does not — `eval` concatenates to `uplevel #0 subst $rawfile`, `$rawfile` is
substituted in the *proc* frame (`res=LOCAL1`, the local value), and the payload then runs
at global level. So it is not a latent wrong-variable bug; it is a **live command
substitution over a string read out of a `.sch` file**, exactly the 0812 shape.

## 3. Why 0812-retry did not fix it

The item's scope fence names 0816 (the nine remaining `regsub {^~/}` + tcleval splices) and
0817 (the tclvareval brace groups) as the follow-on, and forbids widening. These two sites
are Tcl-side and are in neither list — 0817 enumerates C `tclvareval` call sites. They are
recorded here so the follow-on crew inherits them rather than rediscovering them.

## 4. Recommended fix (for the 0816/0817 crew)

`graph_fill_listbox` wants a *resolved path to display and to hand to `raw switch`*. The C
resolver built for 0812 already is that function and is reachable from Tcl through the
engine: route the attribute through the same one-pass resolution the drawing path uses
rather than through `subst`. Failing that, the minimal Tcl-only repair is
`uplevel #0 [list subst -nobackslashes -nocommands $rawfile]` **plus** the knowledge that
this is *not sufficient* — `$a([exec …])` still runs inside a variable array index (0812
§4, the refutation of attempt 1). Only a resolver with no evaluator in it closes this.

`raw_is_loaded` has no callers: **delete it** rather than fixing it.

## 5. Still open — AS OF THE ORIGINAL FILING (superseded by §11)

Everything above. Nothing in this issue was changed by 0812-retry.

---

# THE FIX — item 0821+0816+0817, 2026-08-25

This half of the file is the record of the crew that closed it. It also closes
**0822** (`autoload` and `sim_type`, the two neighbours three lines away) because
one change closed all three fields, and it is the sibling record for **0816**
(the nine `scheduler.c` `regsub` splices) and **0825** (the three sym-path
wrappers), which shipped in the same commit.

## 6. BEFORE — measured through the real user door, not by calling the proc

The requirement the item's brief set was that the red phase must **open a crafted
schematic the way a user would**, because a probe that calls `graph_fill_listbox`
directly proves nothing about the `.sch` route. It was met: each fixture is a
well-formed `.sch` with one graph rect, loaded with `xschem load`, and then
`graph_edit_properties 0` — the proc the double-click at `src/callback.c:2637`
calls — was run under `DISPLAY=:99`. Measure agent transcript, verbatim:

```
RED-START
loadA rects2=1
A(quoted-cmd-sub): rc=0 RED_Q_created=1 r=
B(var-value):      rc=0 RED_VAR_created=1 r=
C(array-index):    rc=0 RED_ARR_created=1 r=
D(sim_type-field): rc=0 RED_ST_created=1 r=
raw_is_loaded proc exists=1
raw_is_loaded direct-call HIT=1 rc? r=0
RED-END
```

Every `_created=1` is a **file that appeared on disk** because a schematic was
opened and its Graph dialog was opened. `rc=0` throughout: nothing raised,
nothing was logged, the dialog behaved normally (0822 §3 is why — the payload is
consumed by the substitution and leaves no residue in the result).

**One refinement of the scout's measurement, worth keeping.** The scout reported
that the array-index shape did **not** fire through this route, having tried the
unquoted spelling, which the `.sch` property parser truncates at the first space.
The **quoted** variant fires (`RED_ARR_created=1` above). 0822 §4 is the general
statement of that trap: a regression row that forgets to quote its payload passes
against a live defect.

## 7. AFTER — the same four shapes, plus two the red phase did not have

`tests/headless/test_wave_sigsearch.tcl`, group **GDI**, on `:99` (the suite must
run under X; it drives the real dialog):

```
GDI01 quoted command substitution in rawfile=   -> {0 0 0}
GDI02 payload delivered through a VARIABLE'S VALUE -> {0 0 0}
GDI03 quoted ARRAY INDEX  $arr([exec touch …])  -> {0 0 0}
GDI04 brace escape  q} ; set ::GDI_HIT 1; list {a -> {0 0 0}
GDI05 sim_type="tran[exec touch …]"             -> {0 0 0}
GDI06 autoload="1[exec touch …]"                -> {0 0 0}
GDI08 `subst` invocations during one fill        -> 0   (was 3)
GDI11 resolution passes on the dialog route      -> {0 1}  (was {1 1})
GDI12 info procs raw_is_loaded                   -> empty
GDI13 crafted non-boolean autoload=, dialog rc   -> 0
```

The adversary pass then re-drove the same door independently and added shapes the
suite does not carry — a namespace-qualified `$::nsx::p` whose value holds the
payload, the `${bv}` brace-var form, `sim_type=table` (which takes the
`raw table_read` branch instead of `raw read`/`switch`), `~/q[exec …].raw`, and a
payload **split across two fields at once**. All: `HIT=0`, host file 0. It also
re-checked 0812's own `%` node route (`node="a %[exec touch …].raw tran"`):
`HIT=0`, and the graph still plotted.

**Non-vacuity, so none of that is a green nothing.** The literal payload still
reaches the engine as a filename — `raw_read(): failed to open file q} ; set
::HIT 1; exec touch …/H4; list {a.raw`. The string is delivered end to end; it is
simply never parsed.

**Anti-hollow.** GDI09: `xschem_library/ngspice/autozero_comp.sch`, whose graph
really does carry `rawfile=$netlist_dir/autozero_comp.raw`, still opens its Graph
dialog `rc=0` and its raw is registered under the **resolved absolute path**.
GDI10: a plain relative rawfile still fills a non-empty listbox, and
`solar_panel.sch` and `cmos_example.sch` both load and open `rc=0`.

## 8. What changed

`src/xschem.tcl`, three edits and one deletion:

1. **One named intake**, `proc graph_rect_attr {n tok {with_quotes 0}}`, a single
   `xschem getprop rect 2 …` with **no evaluator in it**, carrying the comment
   block that says why there is none and must not be one.
2. `graph_fill_listbox` reads `autoload`, `rawfile` and `sim_type` through it.
   The `eval uplevel #0 {subst $rawfile}` block is **deleted, not weakened**, and
   so are the two `uplevel #0 {subst [xschem getprop …]}` reads either side of it.
3. `string is boolean -strict` guards the `autoload` branch — in
   `graph_fill_listbox` **and in `graph_edit_properties`** (see D3 below).
4. `proc raw_is_loaded` is **deleted**, replaced by a comment saying where the
   answer now comes from.

**The sink was never `subst` alone**, and the comment in the source says so,
because the next person to read that line will assume it was: `eval` and
`uplevel` *concatenate their arguments and evaluate the result as a script*, so
the attribute is re-parsed and a `[...]` in it runs while the script's own words
are being parsed — before `subst` is reached at all.

**Why no resolver was added here.** `rawfile` is consumed only by `xschem raw
read|switch|table_read` (`scheduler.c:10316-10370`), all of which land in
`extra_rawfile()` (`src/save.c:1774`), which since 0812 calls
`resolve_rawfile_path()` (`src/util.c:1069`). `src/draw.c:3643-3655` reads the
**same three attributes** off the same rect with `get_tok_value()` and no
substitution at all. Dropping the Tcl pass makes the dialog and the renderer see
byte-identical values — invariant **I1**, one name builder — and makes the route
**single-pass**.

## 9. Decisions, with ladder rung and rejected alternative

| # | rung | decision | rejected |
|---|---|---|---|
| D1 | L1 (**I1**) | Drop the `subst` outright; `extra_rawfile()` → `resolve_rawfile_path()` is the single resolution. | A new `xschem resolve_rawfile` Tcl verb: keeps the route double-resolved (0820), needs a C build for a value the C consumer already resolves, and creates a **second producer of the registry key** (0812 constraint 3). |
| D2 | L2 | One named intake `graph_rect_attr`. | Three bare inline `getprop` calls — smaller diff, but no place to state the rule, no callee a sabotage variant can rename, and the next editor re-adds a `subst` to one of the three. |
| D3 | L2 | `string is boolean -strict` on `autoload`, **in both procs**. | Leaving the bare `&& $autoload`: a crafted non-boolean throws, and the Graph dialog **cannot be opened at all** on that file. Same data-from-a-document class as the injection, one line away. |
| D4 | L2 | **Delete** `raw_is_loaded` (0821 §4's own recommendation; zero callers tree-wide). | Repairing it: leaves a never-called, never-exercised second resolver shape for someone to wire up later. |
| D9 | L2 | The dialog route becomes **single-pass**, and GDI11 measures it rather than asserting it. | Keeping both passes. |

**⚠ D3 is the one place the plan was wrong, and it is worth propagating.** The
plan hardened only `graph_fill_listbox`. The throw is in **`graph_edit_properties`**
(now `src/xschem.tcl:4954`), which reads `autoload` *before the dialog is built*.
Implemented as written, GDI13 would have shipped red. Two frames, both had to
change — the same shape as `load_new_window` needing both `expand_tilde()` **and**
0825's wrapper fix.

## 10. Sabotage matrix

| variant | predicted red | observed |
|---|---|---|
| **SAB-A1** evaluator back on all three fields + `raw_is_loaded` restored | GDI01,02,03,04,05,06,08,11,12 (9) | **10** — all nine, plus an unpredicted **GDI14** (the restored `raw_is_loaded` executed its payload and created the host file). GDI08 counted 3 `subst` invocations. |
| **SAB-A2** only `rawfile` left on the evaluator | GDI01,02,03,04,08,11 (6) | **exactly those 6**. Per-field coverage proven: a one-field fix cannot pass. |
| **SAB-A3** intake made inert (returns `{}`) | GDI09, GDI10, GDI11 (3) | **0 red — suite 248/248.** See below. |

**SAB-A3 is the finding, not the footnote.** Three anti-hollow rows were predicted
red when the attribute intake returns nothing, and all three stayed green, so a
measured user-visible break passed the suite: with two raws resident (current
`aaa`, graph names `bbb`), the fixed tree lists `bbb time` and the sabotaged tree
lists `aaa time`. Mechanisms, measured:

* **GDI09** is satisfied by the **C draw path** — `src/draw.c:3643-3655` reads the
  same attributes and calls `extra_rawfile()` itself, so the resolved-path
  assertion holds no matter what the Tcl intake returns. It does not cover the
  dialog route at all.
* **GDI10**'s advertised claim ("the listbox comes back non-empty") is not what it
  asserts: it reads `[winfo exists .graphdialog.center.left.list1]`, widget
  **existence**, not content. A dialog listing nothing, or listing the wrong
  database's signals, passes.
* **GDI11** is likewise also produced by the C path, so it detects an **added** Tcl
  pass (it went red under A1 and A2, correctly) but cannot tell a correct intake
  from an inert one.

Filed as **0828**, with the concrete "wrong database's signals" repro. The
injection rows are unaffected — A1/A2 discriminate them per field — but the
anti-hollow half of this suite is weaker than it reads.

## 11. Still open (supersedes §5)

* **The Tcl same-class siblings are NOT swept.** `src/xschem.tcl:2831`
  `file_exists` carries the identical `catch "uplevel #0 {subst $f}"` sink and is
  dead (no callers); `src/ase.tcl:202` `ase::expand_path` uses
  `subst -nocommands`, which 0812 §1 measured still running a command
  substitution inside an array index; `src/xschem.tcl:7067/7068` build the
  preview_window `<Expose>`/`<Configure>` binds with `subst` over a file-dialog
  filename.
* **A `.sch`'s own content still executes by another door**, on this fixed tree:
  `cellview_sch_path()` (`src/actions.c:4215-4219`) splices the instance's
  `schematic=` attribute into `cellview_path {%s} schematic` and `tcleval()`s it.
  One mailed file plus a **stock library symbol** runs `exec touch` on a plain
  `xschem descend`. Filed as **0827**, and its trigger is at least as ordinary as
  this issue's.
* **0820's `%` node route is untouched** and remains two-pass; only the dialog
  route was retired from that exposure.
* `string is boolean -strict` is **narrower than C `strboolcmp()`**
  (`src/util.c:78`), which treats any positive integer as true, so `autoload=2`
  yields the Tcl word `switch` where `draw.c` yields `read`. Measured
  unobservable today because `raw switch` falls through to a read (dialog
  `lbsize=2`, renderer-loaded=1 for `autoload` = 1/2/true/yes/7). It becomes a
  real I1 divergence the moment anything consumes that Tcl word for something
  else.
