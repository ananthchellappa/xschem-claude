# Typed signal accessors — `VT(out)` instead of `v(out)`

**Status:** SPEC. No code yet. No companion PLAN.md yet.
**§17 was RULED by the user on 2026-08-19** — all five open questions answered;
they are recorded there and folded into the rules above them.
**Owner branch:** `fluid-editing`
**Audience:** Claude Code, in a future session, asked to put the *analysis* into
the expression the way Cadence does — `VT("/out")` for transient, `VS(...)` for
the DC sweep, `VDC(...)` for the operating point — in xschem spelling and
xschem's existing RPN grammar.
**Predecessor:** `doc/claude/specs/results_selection.md`. Results Selection
settles **which file**; this spec settles **which analysis inside it**. §19 of
that spec is this one's brief and carries the nine rulings (A1–A9) reproduced in
§16. The session prompt is
`doc/claude/suggestions/next_session_typed_signal_accessors.md`.
**Related:** `doc/claude/specs/calculator.md` (§3 the RPN contract, §7 the
catalogue, R204, R601–R607 — the Calculator is the largest consumer) ·
`doc/claude/code_analysis/waveform_subsystem_reference.md` (the house explainer
for the whole waveform stack; this spec does not re-derive what it states, and
corrects it in two places — §10 L11) · `doc/claude/specs/raw_case_mode.md` (the
lookup ladder this extends, and the subsystem it must not collide with) ·
`doc/claude/specs/mixed_signal_signal_browser.md` §D (the `%<rawfile>
<sim_type>` per-trace suffix) · `doc/claude/specs/ase_l.md` (Direct Plot and
Ctrl-4) · `doc/claude/specs/hierarchy_editor.md` (structure and the §1.1
gap-table idiom) · `doc/claude/specs/simulator_profiles.md` §8 (the four-status
resolver shape) and §14.7 (the "name the bypassing call sites with file:line"
idiom).
**Issues on this path:** **0418** (`raw_add_vector()` swallows the evaluator's
`-1`, measured again here — §10 L4), **0509**, **0305** (the one-parser rule this
spec is bound by), and **0510**/**0511**/**0512**, filed by the survey that
produced this spec (§19).

**Line numbers below are as of 2026-08-19 (`89d0f13e`) and will drift. Grep the
symbol.** Cross-file citations *inside source comments* in `wave_viewer.tcl`,
`calculator.tcl` and `ase.tcl` were measured to be systematically stale — at
least six in `wave_viewer.tcl` alone (§10 L12) — so do not copy one without
re-grepping it. Every claim here was checked by opening the line or by running
the binary, and then re-checked by **two** adversarial passes — 114 errors found
in the first draft, 64 more in the rewrite that fixed them. Where a measurement
rests on files that are **not tracked**, the text says so.

> **READER'S MAP.** **Nothing is ever renumbered** — tests and source comments
> will cite these sections and R-numbers by number.
>
> | you want to know | section |
> |---|---|
> | why this is a resolver and not a parser rewrite | §0 |
> | how far xschem is from Cadence, row by row | §1.1 |
> | the eight architectural facts the design may not violate | §1.2 |
> | the token grammar, the analysis map, the wrappers | §2 |
> | the resolution ladder and what it compiles to | §3 |
> | the C contract — one authority, three doors | §4 |
> | currents: which ngspice spellings the accessor accepts | §5 |
> | the emit side — every site that generates an expression today | §6 |
> | backward compatibility: `v()`, and the two spellings nobody mentions | §7 |
> | the migration of the tracked schematics | §8 |
> | messages and refusals | §9 |
> | landmines | §10 |
> | verification invariants | §11 |
> | decisions that can change | §12 |
> | beyond Cadence / deviations / non-goals | §13, §14, §15 |
> | the rulings already taken | §16 |
> | the five questions the user answered, with the workings | §17 |
> | what is deliberately NOT here | §18 |
> | the three defects this spec filed | §19 |

**R-number bands.** §2 grammar `R1xx` · §3 resolution `R2xx` · §4 engine `R3xx` ·
§5 currents `R4xx` · §6 emit `R5xx` · §7 compatibility `R6xx` · §8 migration
`R7xx` · §9 messages `R8xx`.

⚠ **`calculator.md` uses the same bands for different rules** — its R204, R601 and
R607 are not this spec's. **Always qualify a cross-spec R-number** the way the
text below does (`calculator.md R607`); a bare `R204` always means this spec's.

---

## 0. The one-paragraph version, and the two facts that make it affordable

`v(out)` is ngspice's own vector name and says nothing about which analysis
produced it. One run can leave a DC sweep and a transient loaded at the same
time — measured below, three slots from one file — and `v(out)` resolves in both
with different numbers, according to a registry cursor the user cannot see.
Cadence removes the ambiguity by putting the analysis into the expression. This
spec does the same in xschem spelling: `VT(out)`, `VS(out)`, `VF(out)`,
`VDC(out)` and the four current forms, no quotes, xschem paths.

**Two measured facts make this a resolver layer, not a parser rewrite.**

**(a) The token shape already exists.** The RPN evaluator
(`plot_raw_custom_data()`, `src/save.c:3520` — **not** `:2381`, which is what
`calculator.md:30` and `tests/headless/test_del_negative_arg.tcl:6` both cite,
and both are stale) splits on whitespace only
(`my_strtok_r(ntok_ptr, " \t\n", "", 0, &ntok_save)`, `:3545`), then matches
**52** operator spellings by exact `strcmp` down a single `else if` chain
(`:3553-3636`) — **40 of them written `name()`**, `sin()`, `db20()`, `del()`,
`re()`, plus **12 punctuation spellings** `+ == != > < >= <= - * / ** ?`. (The
brief's "40 ops spelled `name()`" is *correct* for the set it names;
`calculator.md:30`'s "~54 ops" is not, and is a second thing to fix there.) It
then tries `strtod` for a number (`:3637`), and **only then** falls through to
`get_raw_index()` as a vector name (the `else { /* SPICE_NODE */ }` block,
`:3641-3651`, the call at `:3642`). A token `VT(out)` matches no operator, is not
a number, and lands in that last `else`. Measured today, against a live transient
database:

```
VT(out)        idx=-1
vt(out)        idx=-1
VF(out)        idx=-1
IT(vmeas)      idx=-1
mag(v(out))    idx=-1
phase(v(out))  idx=-1
```

Every accessor spelling this spec introduces is a **clean miss today, in every
rung of the existing four-rung ladder**. Nothing can be silently re-interpreted;
the grammar has a hole exactly the shape of the feature. (`strtod` is the one
case-blind thing in the chain and it consumes **0** characters of all eight
accessor spellings — see §10 L13, which records what it *does* eat.)

**(b) AC is already split into four real vectors at read time**, so there is no
complex object to carry and the wrappers compile to names that already exist.
Measured on a three-analysis raw written by ngspice-46 — the vector list is one
name per line, reflowed here to four columns:

```
xschem raw read multi.raw ac ; xschem raw list        (reflowed to 4 columns)
  frequency  ph(frequency)  re(frequency)  im(frequency)
  v(in)      ph(in)         re(in)         im(in)
  v(mid)     ph(mid)        re(mid)        im(mid)
  v(out)     ph(out)        re(out)        im(out)
  i(vin)     ph(i(vin))     re(i(vin))     im(i(vin))
  i(vmeas)   ph(i(vmeas))   re(i(vmeas))   im(i(vmeas))
```

and numerically, at two points of the same RC response:

```
                p=10  (f = 10 Hz)        p=55  (f = 316227.77 Hz)
v(out)           1                        0.44956459     <- the MAGNITUDE
re(out)          1                        0.20210832
im(out)         -6.2831853e-05           -0.40157259
ph(out)         -0.0036                  -63.284248      <- DEGREES
```

At p=55, `sqrt(re² + im²)` is `0.44956459` and `atan2(im, re) * 180/pi` is
`-63.284248` — both to the last printed digit. So `v(out)` in an AC database
**is** the magnitude, which is exactly ruling A5, and `ph(...)` is in degrees.
(At p=10 the magnitude and the real part agree to eight digits because the phase
shift is 3.6 millidegrees; that row proves the *names*, the p=55 row proves the
*arithmetic*.) `mag`/`phase`/`real`/`imag`
therefore need no computation at all: they are rewrites onto a stored name.

**⚠ Both of those bullets correct the source documents.** §19 of
`results_selection.md` records the derived names as `ph(v(out))`, `re(v(out))`,
`im(v(out))`. **They are not.** For a name whose first two characters are `v(`
(case-insensitively, `src/save.c:1119`) the prefix is *stripped*:
`my_mstrcat(_ALLOC_ID_, &raw->names[(i << 2) + 1], "ph(", varname + 2, NULL)`
(`:1123`) turns `v(out)` into `ph(out)`. A name **without** that prefix is
wrapped whole (`:1125`), which is why the same file yields `ph(i(vin))`. The two
shapes are asymmetric and §2.2's wrapper table implements both. (The session
prompt's own AC listing, `next_session_typed_signal_accessors.md:75`, shows the
*second* shape — so the prompt and the brief disagree with each other, and the C
is the authority.)

**The whole feature is one resolver function, its three doors, one emit sweep,
and a migration.** No new opcode, no new stack type, no new file format.

---

## 1. Where xschem stands today

### 1.1 Cadence capability × xschem today

Cadence's side is sourced from `references/viva_research_raw.json` (research items
`:514`, `:563`, `:1792`, `:1883`, `:2058`, `:2378`, `:2392`, `:3436`) and `references/viva_cadence_waveform_viewer.md`.

| Cadence ADE-L / ViVA capability | xschem today | Evidence |
|---|---|---|
| An expression names the **analysis**: the AEL form set `VT`/`IT`/`VF`/`IF`/`VDC`/`IDC`/`VS`/`IS` (+ `OP`/`OPT`/`VAR`/`MP`/`VN`) | **absent** — an expression names a *vector*, and which analysis answers depends on the registry cursor | `references/viva_research_raw.json:2058`; xschem: `get_raw_index()` `src/save.c:3406` takes a name and nothing else |
| The click-to-pick button table is **per analysis** — tran: `vt`/`it`; ac: `vf`/`if`; dc: `vdc`/`idc`; swept_dc: `vs`/`is` | **absent** — one Direct Plot pick mode, analysis-blind: kind is voltage-or-current only | `references/viva_research_raw.json:2378`; xschem: `ase::ui::sod_expr` `src/ase_window.tcl:961`, whose only kind-bearing output is `v($token)` / `i($token)` (it also strips a leading `#`, `:962`, and applies the gesture's case mode, `:963-965`) |
| Several analyses of one run available at once | **yes, and ahead** — one file, one slot per analysis, all live | measured, §1.2 F3 |
| Which analysis a *saved trace* means, recorded in the file | **partial, at the graph level only** — a rect's `sim_type=` **can** name an analysis with no `rawfile=` beside it and performs a real registry switch when it does (measured, §1.2 F4); **146 of the 171** tracked rects that carry `sim_type=` carry no `rawfile=`. What cannot name an analysis alone is the **per-trace** `%` suffix | `sim_type=` read at **14** C sites (11 in `src/draw.c`, 3 in `src/callback.c`) plus 5 in Tcl; the substitution `src/draw.c:8969-8972`; the per-trace parser `node_token_split()` `src/draw.c:3330` and the gate at its eight call sites |
| Complex data has a per-trace **modifier**: Mag, Phase, WPhase, Real, Imag, dB10, dB20 | **partial** — the four parts are separate named vectors, plus a `db20()` operator; there is no dB10, and no per-trace modifier *property* | `references/viva_research_raw.json:514`, `:3436`; xschem: names built at `src/save.c:1119-1141`, `db20()` at `src/save.c:3609` |
| Wrapper spelling is **prefix and nested**: `dB20(VF("/net"))`, `phase(VF("/net"))`, `mag(...)`, `real`/`imag` | **absent as a spelling** — xschem's are postfix RPN operators (`re()` `im()` `cph()` `db20()`) plus stored names (`ph(out)`, `re(out)`, `im(out)`) | `references/viva_research_raw.json:1883`, `:3436`; xschem: `im()` `src/save.c:3592`, `re()` `:3593`, `cph()` `:3566`, `db20()` `:3609` |
| Node paths are quoted and slash-rooted: `VT("/I3/bp1!")` | **deliberately not copied (A2)** — xschem paths, dot-separated, unquoted: `VT(x1.x2.net5)` | `references/viva_research_raw.json:2392`; A2 |
| The picker emits a path **relative to the simulated top cell**, unchanged by descending | **yes, and already solved** — `sod_qualify` measures from the session's own design level, `sim_sch_path` is the raw's own origin | `references/viva_research_raw.json:2392`; xschem: `ase::ui::sod_qualify` `src/ase_window.tcl:1100`, issues 0161/0168 |
| Terminal currents named by appending the terminal (`i("/I0/M1/D")`, `I(V2:p)`) | **different but equivalent** — ngspice's three measured shapes (§5), all of which the existing ladder resolves | `references/viva_research_raw.json:563`, `:2392`; xschem: the `@dev[param]` note at `src/save.c:3346-3349` |
| A per-call `?result`/`?resultsDir` override that does **not** move the selection | **yes** — the `%<rawfile> <sim_type>` suffix is exactly this | `references/viva_research_raw.json:2058`; `node_token_split()` `src/draw.c:3330` |
| A signal reference always carries its kind (`v`/`i`) | **no, and the split is three ways** — of 666 tracked graph rects with a `node=`, **16** contain a `v(`, **264** contain an `i(`, and **395** contain neither wrapper (**29** of those use `tcleval`; 45 rects use it in all, the other 16 with a wrapper inside the tcleval string). The bare ones resolve at the ladder's `v()`-wrap rung; the `i(`-wrapped ones resolve at rung 1 | measured census, §1.2 F6; rung 3 `src/save.c:3372` |
| An unresolvable accessor is a clean, named failure | **partial** — `-1` is returned and propagated, but `raw_add_vector()` reports success anyway (issue **0418**), measured again here | `src/save.c:3643-3647`; §10 L4 |
| Analysis-specific Direct Plot: the form offers the analyses the run produced | **absent, and further away than it looks** — Direct Plot never asks, and the run writes only **one** analysis's data into the raw (R503) | `src/cadence_style_rc:264`; `render_deck`'s single `write`, `src/ase.tcl:4668` |

**Score: xschem has the *storage* for the distinction and no *notation* for it.**
Every analysis of a run is already loaded, already keyed, already switchable and
already addressable per trace — and at the *graph* level an analysis can already
be named on its own. What is missing is a way to say it inside an expression. Of
the thirteen rows, **four are absent outright** (the accessors, the per-analysis
pick, the prefix wrappers, the Direct Plot chooser), three are partial, one is a
deliberate non-copy (A2), one is different-but-equivalent, one is a plain "no",
and three are already at parity or ahead. The gap is one token form and the
resolver behind it; nothing in the data model has to move.

### 1.2 The architectural facts the design must respect

**F1 — ONE EXPRESSION EVALUATES AGAINST EXACTLY ONE DATABASE, and that database
is `xctx->raw`.** `plot_raw_custom_data()` binds its sweep column, its scratch
column and every operand to the current `Raw` before the token loop starts —
`x = xctx->raw->values[sweep_idx]` (`src/save.c:3529`),
`y = xctx->raw->values[xctx->raw->nvars]` (`:3535`) — and a `SPICE_NODE` stack
entry carries a bare `int idx` (`Stack1`, `:3510-3518`) read back as
`xctx->raw->values[stack1[i].idx][p]` (`:3676`). The constraint is not that
`Stack1` could not gain a `Raw *` field — it is a file-private struct and it
could. It is that there is **one point loop, one sweep column and one
`first`/`last` window**, and the analyses do not share a point count. Measured,
from one ngspice-46 run written to one file:

```
0  …/multi.raw  dc     5 points
1  …/multi.raw  tran 121 points
2  …/multi.raw  ac    61 points  (nvars 24 = 4 x 6, the AC quadrupling)
```

**This is the single hardest constraint in the feature**, and it is what makes
`VT(out) VS(out) -` a refusal rather than a feature (R204).

**F2 — the lookup ladder knows about names and case, and the only thing that
knows about an analysis is *which `Raw *` you hand it*.**
`get_raw_index(node, entry)` (`src/save.c:3406`) is `get_raw_index_in()`
(`:3362`) run against `xctx->raw`, gated by `sch_waves_loaded() >= 0`. Four rungs
(`:3307-3405`): 1 the exact spelling, 2 the case-folded alias
(`raw_fold_index()`, suppressed when `Raw.case_sensitive`), 3 the same two
`v()`-wrapped, 4 the same two with a leading `i(v.` — tested as `i(v.x`, case-blind — rewritten to `i(`, keeping the `x`. No rung
takes an analysis, and the entry point everything in the schematic and the viewer
uses is pinned to `xctx->raw` — so **selecting the analysis means selecting the
slot, and the ladder is untouched.** Measured on a transient database:

```
v(out) 3   V(OUT) 3   out 3   OUT 3      <- rungs 1,2,3, and 2+3
i(vmeas) 5
VT(out) -1  vt(out) -1  VF(out) -1  IT(vmeas) -1   <- the hole this spec fills
```

**F3 — an analysis IS a registry slot, keyed `(rawfile, sim_type)`.**
`extra_rawfile()`'s read arm matches
`!strcmp(arr[i]->rawfile, f) && (!type || !strcmp(arr[i]->sim_type, type))`
(`src/save.c:1934-1937`) — note a NULL/empty type is a **wildcard** there — and
the switch arm requires both (`:1984-1986`) with a **case-sensitive** `strcmp`.
The registry is `xctx->extra_raw_arr[]` + `extra_raw_n`/`extra_idx`/
`extra_prev_idx` (`src/xschem.h:2039-2042`), per `xctx`, therefore **per window
and per tab** (`results_selection.md` §1.2 F2). Measured after three
`xschem raw read` calls on one file:

```
2 current
0 /…/multi.raw dc
1 /…/multi.raw tran
2 /…/multi.raw ac
```

**F4 — THE GRAPH LEVEL CAN ALREADY NAME AN ANALYSIS ALONE; THE TRACE LEVEL
CANNOT.** This is the exact shape of the hole, and it is narrower than it looks.

*At the graph level it works.* `draw_graph()` substitutes the current database's
own path when the rect carries no `rawfile=` —

```c
ptr = get_tok_value(r->prop_ptr,"rawfile", 0);
if(!ptr[0]) {
  if(xctx->raw && xctx->raw->rawfile) my_strdup2(_ALLOC_ID_, &custom_rawfile, xctx->raw->rawfile);
```
(`src/draw.c:8969-8972`) — and then switches on `(custom_rawfile, sim_type)`
(`:8998-9003`). **Measured:** three sibling rects over a registry holding a `dc`
and a `tran` slot, none of them carrying a `rawfile=` — the rect with
`sim_type=dc` full-y-zooms to the DC data (`y1=0 y2=0.5`) while the `sim_type=tran`
rect and the rect with no `sim_type` both zoom to the transient (`2.5..2.6`). So
"this analysis, of the file I am already looking at" is already expressible —
once per graph, and **146 of the 171** rects that carry a `sim_type=` use it that
way.

*At the trace level it does not.* `node_token_split()` (`src/draw.c:3330`) parses
the **`%` half** of `[alias;]<vec-or-RPN> [ '%' [<dataset-digits>] [<rawfile>
[<sim_type>]] ]` — the `alias;` half is split separately by each walker — and the
sim_type is field `pos + 1` of the `%` payload, where `pos` is 1, or 2 when field
1 is all digits (`:3339-3348`). **Field `pos` is structurally the rawfile and no
spelling skips it.** Measured three ways: `v(anlg)% tran`, `v(anlg)%0 tran` and
`v(anlg)%tran` all parse `node_rawfile=|tran|`, and all three make the trace
unpickable, unboldable and unmarkable. `wviewer::db_suffix` emits only the shape
`"%$rf $st"` when it emits at all (`src/wave_viewer.tcl:2582`; three guards at
`:2574`, `:2575`, `:2581` return `{}` instead), and every one of the **eight**
call sites gates the per-trace switch on a non-empty `node_rawfile` — `:3628`,
`:3843`, `:4029`, `:5604`, `:6645`, `:7115`, `:8202`, `:9017`.

**The accessor's job, stated exactly: move the graph-level capability down to the
trace.** §3.2 owns how.

Two adjacent facts the design must not trip over: `%` is a **reserved character
with no working escape** (a vector named `v(a%b)` is unreachable — measured bare,
quoted, backslash-escaped and both), and the suffix's sim_type is matched by a
**case-sensitive** `strcmp` in the switch arm (`src/save.c:1984-1986`) while the
`spectrum`/`sp` → `ac` aliasing exists only in the *read* arm (`:1926-1929`) — so
`%<path> TRAN` refuses where `%<path> tran` resolves.

**F5 — `Raw.sim_type` is not a closed set, and a MULTI-POINT `op` is not stored as `op`.**
`read_dataset()` matches **eight** `Plotname:` phrases in **six** `else if`
branches, with `strncmp` + `strstr` (`src/save.c:883-919`) — "transient analysis"→`tran`, "dc transfer
characteristic"→`dc`, "noise spectral density curves"→`noise`, "operating
point"→`op`, "integrated noise"→`op` (or `noise` if that is what was asked for),
and "ac analysis" **or "spectrum" or "sp analysis"**→`ac` — and then falls
through to storing the **literal plot name**, spaces and all (`:920-931`). That
fall-through is why tracked schematics carry `sim_type=distrib` and
`sim_type=foo`. Worse for `VDC`: a **multi-point** Operating Point raw is stored
as `dc`, per-dataset —

```c
if(raw->npoints[raw->datasets] > 1 && !strcmp(sim_type, "op") ) { sim_type = "dc"; }
```
(`src/save.c:999-1001`, and the sibling at `:1046-1048`) — which is why
`Raw.req_sim_type` exists (`src/xschem.h:1250`, written at `src/save.c:1900` and
`:1953`) and has **one reader in the tree** (`src/scheduler.c:10116`), not
including either matcher in F3.

**F6 — THERE ARE THREE SPELLINGS OF A SIGNAL IN A `node=` TODAY, AND `v(` IS THE
RAREST.** Measured headlessly over every tracked `.sch` containing
`flags=graph` — 666 graph rects with a `node=`, 1656 trace entries, zero load
failures:

| spelling | rects | entries | resolves at |
|---|---|---|---|
| `v(...)` | **16** | 36 | rung 1 (exact) |
| `i(...)` | **264** | 403 | rung 1 (exact) — there is **no** `i()` rung |
| neither wrapper (bare name, `tcleval`, or a pure-RPN entry) | **395** | 1235 | rung 3, the `v()` wrap, for a bare voltage name |

45 rects use `tcleval(...)` — **29** of them in the last row, the other 16
carrying a `v(`/`i(` inside the tcleval string and therefore counted above it.
294 rects carry at least one genuinely bare entry and 243 are bare in every entry. The bare form is what the C highlight→graph path
produces: `send_net_to_graph()` (`src/hilight.c:1758`) emits
`"<netname> <colour> "` with no wrapper (`:1777-1778`) and
`graph_add_nodes_from_list` (`src/xschem.tcl:6516`) appends it verbatim. The
graph dialog's own listbox does the same on purpose: `graph_get_signal_list`
strips `^v\((.*)\)$` before displaying (`src/xschem.tcl:6748`), **for voltages
only** — measured, `v(en_n)` displays and stores as `en_n` while `i(e5)` stores
as `i(e5)`, because there is no `i()` rung to re-wrap it.

**So ruling A4's "nothing the tool emits uses `v(` any more" names the smallest
of the three groups.** §8 has to cover all three.

**F7 — the accessor may contain neither whitespace nor `%`.** The RPN lexer
splits on `" \t\n"` (`src/save.c:3545`), so whitespace inside `VT(...)` would
split the token; and `node_token_split()` takes the second `%`-separated field of
the token as the suffix (`find_nth(ntok, "%", "\"", 0, 2)`, `src/draw.c:3337`),
so a `%` inside an accessor would be eaten before the evaluator sees it. Both are
hard lexical limits, not conventions. (`calculator.md` L3 is the third face of
the same rule: a token counts as an expression only if it contains whitespace,
`strpbrk(express, " \n\t")`, `src/draw.c:5639`.)

**F8 — a Tcl MIRROR of the ladder exists, deliberately, and must be kept in
step.** `wviewer::validate_rpn` (`src/wave_viewer.tcl:3676`) re-implements the C
ladder in Tcl through `wviewer::name_rungs` (`:2629`) and `name_lookup` (`:2689`),
and it **may not** become a call to `xschem raw index`; the reasons are recorded
at `:2595-2604` — it must judge a name list that is *not* the current database's,
and it must run with no engine loaded at all (`test_wave_viewer.tcl` drives it on
synthetic lists). Anything the C resolver learns, this proc learns too, or the
viewer starts refusing expressions the engine would have accepted. Same for the
Tcl classifiers that parse the `v(`/`i(` prefix by pattern:
`ase::ui::output_kind` (`src/ase_window.tcl:856`), `wviewer::sig_type`
(`src/wave_viewer.tcl:1951`) and `ase::bus_expr_bits`'s
`regexp {^v\(([^()]+)\)$}` (`src/ase.tcl:326`).

---

## 2. The grammar

### 2.1 The token

**R101** An **accessor** is a single token of the form

```
<ACC> '(' <arg> ')'
```

with **no whitespace anywhere in it** and **no `%`** (F7), no quotes (A2), and
nothing between `<ACC>` and the `(`. It is a *token*, not a call: the RPN lexer
never sees a `(` as punctuation, so `VT ( out )` is **four** tokens — `VT`, `(`,
`out`, `)` — of which `(` and `)` resolve to nothing and the surviving `out` is an
ordinary bare vector name. **The spaced form does not fail; it silently means
something else.**

**R102** `<ACC>` is one of exactly eight spellings in v1 (A3):

| accessor | kind | Cadence's name for it | requested `sim_type` |
|---|---|---|---|
| `VT` | voltage | transient voltage | `tran` |
| `IT` | current | transient current | `tran` |
| `VS` | voltage | swept-DC (source sweep) voltage | `dc` |
| `IS` | current | swept-DC current (I-vs-V) | `dc` |
| `VF` | voltage | frequency (AC) voltage | `ac` |
| `IF` | current | frequency (AC) current | `ac` |
| `VDC` | voltage | DC operating-point voltage | `op`, then a 1-point `dc` (R103) |
| `IDC` | current | DC operating-point current | `op`, then a 1-point `dc` (R103) |

`VF`/`IF` **alone** are the magnitude (A5, §0(b)).

**R103 — `VDC`/`IDC` resolve against `op`, then against a `dc` slot that holds
exactly one point; a multi-point `dc` is a SWEEP and the message says `VS`.**
The second try exists for a genuine single-point operating point that reached the
registry as `dc` — e.g. a one-point `Plotname: DC transfer characteristic`
requested as `dc`. (A one-point `Plotname: Operating Point` is stored as `op` and
the **first** try already catches it — measured: ngspice `op` + `write`, read back
as `op`, gives `points=1 … sim_type=op`.) It uses the same predicate shape the scheduler
already uses to decide a switch landed in an operating point
(`raw->allpoints == 1` on an `op`-or-`dc` slot, `src/scheduler.c:10415-10417`,
`:10428-10430`), applied here only to the second try.

⚠ **It does NOT normally recover F5's promoted slot, and that is the intended
answer — but "never" would be wrong.** The `op`→`dc` rename fires on the
**header** count, `raw->npoints[raw->datasets] > 1` (`src/save.c:999`, `:1046`),
while `raw->allpoints` is summed from `npoints[]` **after** the data block
rewrites it to the count that survived the sweep window
(`raw->npoints[raw->datasets] = npoints` at `src/save.c:754`; the window filter at
`:670-692`; the sum at `:1392-1394`). So a sweep-windowed read —
`xschem raw read <file> op <sweep1> <sweep2>` (`src/scheduler.c:10381-10386`) —
can leave a promoted slot with `allpoints == 1`, and `VDC` will take it. That is a
narrow, user-driven case and it is *not* wrong to serve it: with one point left in
the window the slot really is an operating point. **What must not be written is
"a promoted slot can never have `allpoints == 1`."** The ordinary case stands:
xschem's reader has judged an unwindowed multi-point operating point to be a DC
sweep, and the accessor for a DC sweep is `VS`. F5 is the reason `VDC` needs *any*
second try, not the reason it needs *that* one.

**R104 — what is legal inside the parentheses.** Everything the existing ladder
can resolve once the accessor's own rewrite is applied (R202), and nothing else:

- **A plain net name** — `VT(out)`, `VT(net5)`.
- **A hierarchical path**, dot-separated, in the raw's own coordinate system —
  `VT(x1.x2.net5)`. **Not** built from `xctx->sch_path`; measured against the
  raw, per `calculator.md` R207 and issues 0161/0168. Cadence's slash-rooted
  quoted form (`VT("/x1/x2/net5")`) is deliberately not copied (A2).
- **Characters** — anything but whitespace, `%`, `(`, `)`. Measured in `.raw`
  files: `-` occurs (`i(i-sweep)`, `v(v-sweep)`), and `.`, `_`, `[`, `]`, `@` and
  digits occur. `#` must be **stripped by the emitter, never accepted here**
  (issue 0154: a `.save v(#net1)` card aborts the whole analysis;
  `ase::ui::sod_expr` already strips it at `src/ase_window.tcl:962` and
  `send_net_to_graph` at `src/hilight.c:1766`).
- **For the current accessors only**, ngspice's three measured device-current
  shapes — §5.
- **Buses: one accessor per bit.** `VT(d[3])` is one signal and is legal.
  **`VT(d[3:0])` is malformed** — RULED, §17 Q4. A bus in a `node=` entry is a
  comma list at the *entry* level: `get_bus_idx_array` (`src/draw.c:2890`) splits
  the bus **name** off on `";,"` (`:2903`) and then the **bits** on `";, \\\n"`
  (`:2904`) — note the bit split also breaks on whitespace, which is a second
  reason R101's no-whitespace rule is load-bearing, so the existing grammar already wants
  `alias;VT(d[3]),VT(d[2]),…` and a range would make the accessor the only token
  in this grammar that expands to N traces.

**R105** A bare `<ACC>()` with an empty argument is malformed (R121), not a
shorthand.

**R106 — THE ACCESSOR AND WRAPPER KEYWORDS ARE MATCHED CASE-INSENSITIVELY; THE
ARGUMENT IS NOT.** RULED, §17 Q3. `vt(out)` == `VT(out)` == `Vt(Out)` as far as
the *keyword* is concerned; what happens to `out` is entirely the existing
ladder's business (rung 2's fold, suppressed on a `distinguish` database). The
keyword comparison happens in the **parser, before the ladder runs**, so
`raw_fold_key()`'s whole-token lowercasing never touches it — which is the only
way the keyword can keep working on a `distinguish` raw. §10 L2 carries the
measurement that makes this the only viable choice.

### 2.2 The wrappers

**R110** Four **prefix** wrappers are added (A6), spelled and nested exactly as
Cadence spells them (`references/viva_research_raw.json:3436` for
`dB20(VF("/net"))`, `phase(VF("/net"))`, `real`/`imag`; `:1883` for
`mag(VF("/net1"))`):

```
mag(VF(out))    phase(VF(out))    real(VF(out))    imag(VF(out))
```

Still **one token** — no whitespace (F7). The set is closed at four: `re`/`im`
are deliberately **not** added as prefix spellings, because they are already both
an operator spelling and the head of a stored vector name (R120).

**R111** A wrapper's meaning is a **name rewrite onto a vector that already
exists**, never arithmetic. Measured (§0(b)), for an accessor whose argument is
`arg`:

| wrapper | rewrite for a **voltage** accessor | rewrite for a **current** accessor |
|---|---|---|
| *(none)* | `arg` — the bare name, and R202 explains why | `i(arg)` |
| `mag(...)` | `arg` — identical to no wrapper | `i(arg)` |
| `phase(...)` | `ph(arg)` | `ph(i(arg))` |
| `real(...)` | `re(arg)` | `re(i(arg))` |
| `imag(...)` | `im(arg)` | `im(i(arg))` |

On an **AC** database the no-wrapper row is the magnitude column; on `tran`/`dc`/
`op` it is simply the value, and the wrappers refuse (R116).

**The two columns are not the same rule, and that asymmetry is in the C, not
here.** `read_dataset()` strips a leading `v(` before wrapping
(`my_mstrcat(…, "ph(", varname + 2, NULL)`, `src/save.c:1123`) and wraps any
other name whole (`:1125`), which is why one file yields both `ph(out)` and
`ph(i(vin))`. **Do not implement one rule and expect the other to fall out.**
Note the voltage column is right for *both* stored spellings: a bare stored
`out` also derives `ph(out)` (through the else-branch), so `ph(arg)` is correct
whether the reader saw `v(out)` or `out`.

**R116 — A WRAPPER ON A NON-AC ACCESSOR IS A REFUSAL, all four of them.**
RULED, §17 Q1. A transient database holds no `ph(...)`, `re(...)` or `im(...)`
vector at all — measured, a `tran` raw of the §0 deck holds exactly
`time v(in) v(mid) v(out) i(vin) i(vmeas)` — and there is nothing to compute a
phase from, so `phase(VT(out))` could only ever return a fabricated zero. `mag`
and `real` *could* be waved through as `abs()` and identity, and are not: a
wrapper that means three different things depending on the analysis is worse than
one that means one thing and says so. The magnitude of a real signal is written
`VT(out) abs()`, which already works. Message: R806.

**R112 — `db20` is NOT one of the four**, and that is deliberate. It already
exists as a postfix RPN operator (`db20()`, `src/save.c:3609`); there is no
stored `db20(out)` vector to rewrite onto. Cadence's `dB20(VF("/net"))` is
therefore written here as `VF(out) db20()` — one wrapper spelling short of
Cadence, one operator that already works. A prefix `db20(...)` alias is out of
scope for v1 and is D6.

**R113 — the existing spellings keep working** (A6). `re()`, `im()`, `cph()` and
`db20()` remain postfix operators with the semantics `calculator.md` §3.2
records, and `ph(out)` / `re(out)` / `im(out)` remain resolvable as bare vector
names. Nothing is deprecated. (**There is no `ph()` operator** — the operator
chain has `cph()`, `im()`, `re()`, `db20()` and nothing named `ph()`; `ph(...)`
exists only as a stored name the AC reader synthesises.)

**R114 — ⚠ `phase()` is the WRAPPED phase.** The stored `ph(arg)` vector is raw
`atan2 · 180/π` — measured, `ph(out) = -63.284248` where
`atan2(im, re)·180/π = -63.284248` — i.e. bounded to ±180. xschem's unwrapper is
the postfix `cph()` operator (`src/save.c:3566`; the formula
`ph - 360*floor((ph - prev_ph)/360 + 0.5)` is at `calculator.md` §3.2), so the
unwrapped phase is `phase(VF(out)) cph()`.

*How this relates to Cadence is an inference, and is marked as one.* ViVA's
modifier list is `Mag, Phase, WPhase (wrapped phase), Real, Imag, dB10, dB20`
(`references/viva_research_raw.json:514`). The source documents **WPhase** as
wrapped and says nothing about plain **Phase**; the same file's own factcheck
(`:3717`) refuses to assert that Phase is unwrapped. So: xschem's `phase()` is
wrapped, that is a fact about xschem, and whether it lines up with Cadence's
`Phase` or its `WPhase` is not established here. **Every message and help string
must say "wrapped"** (§9), so a user reading Cadence documentation is not left to
guess.

**R115 — a wrapper may wrap ONLY an accessor.** `mag(v(out))`, `phase(out)` and
`mag(mag(VF(out)))` are all malformed (R121). One unambiguous shape, one parse.

### 2.3 The collisions, and why they do not bite

**R120 — `re(` and `im(` are *already* the head of a stored vector name, and the
resolver must not fight over them.** Three things share the spelling `re`:

| spelling | what it is | where |
|---|---|---|
| `re()` (exactly, one token) | an **RPN operator**: pops magnitude and phase-in-degrees, pushes the rectangular real part | `src/save.c:3593` → `case REAL` |
| `re(out)` | a **stored vector name** the AC reader synthesised | `src/save.c:1130` |
| `real(VF(out))` | this spec's **wrapper**, rewriting to `re(out)` | R111 |

They cannot collide, and the reason is lexical rather than clever: the operator
arm is `!strcmp(n, "re()")` — an **exact** whole-token compare — so `re(v(out))`,
`re(out)` and `real(VF(out))` match no operator and fall to the vector/accessor
arm. Measured: `re(out)` on a **transient** database returns `-1`, and on the
**AC** database resolves. This is also why **R110 keeps the wrapper set to
`mag`/`phase`/`real`/`imag`** and does not add `re`/`im` as prefix spellings: the
first token that is both a plausible operator and a plausible name is the last one
anybody should have to reason about.

**R121 — a malformed accessor is a REFUSAL, never a fall-through to the vector
lookup.** Once a token's leading identifier is one of the eight accessor names or
the four wrapper names (case-insensitively, R106), followed by `(`, the token
belongs to this resolver and its failure is reported by name (§9). It does **not**
get tried as a vector name. Rationale, measured: today `VT(out)` misses all four
rungs and the whole expression returns `-1` with
`dbg(1, "plot_raw_custom_data(): no data found: %s\n", n)` (`src/save.c:3644`) —
level 1, invisible by default. Making an accessor typo indistinguishable from a
missing signal would reproduce, in a brand-new feature, the exact failure mode
`calculator.md` R607 calls "the single worst failure mode of the Cadence
original".

**R122 — accessor names are RESERVED as vector names.** A raw containing a vector
literally named `VT(out)` is not reachable through this grammar; by R106 `vt(out)`
is reserved too. No such name can be produced by ngspice: its writers emit `v(`- and
`i(`-wrapped node and branch names, `@dev[param]` device quantities, and bare
axis/noise names (`time`, `frequency`, `onoise_spectrum`) — never an identifier
other than `v`/`i` followed by a parenthesised argument. Recorded rather than defended.

---

## 3. The resolution ladder, and what it compiles to

### 3.1 The ladder

**R201** Resolving one accessor token is five rungs. The first four are new; the
fifth is the existing four-rung name ladder (F2), reached unchanged.

| rung | question | on failure |
|---|---|---|
| **A1** | Does the token *parse* as an accessor (R101/R106/R110)? | not an accessor — fall through to the existing vector lookup, byte-identically to today |
| **A2** | Is the head one of the twelve reserved identifiers but the rest malformed? | **REFUSE**, naming the token (R121, R801) |
| **A3** | Which registry slot? `(rawfile, sim_type)` where `sim_type` comes from R102 (with R103's second try) and `rawfile` comes from R203's ladder | **REFUSE**, naming the analysis and the file (R802) |
| **A4** | Make that slot current — `extra_rawfile(2, <rawfile>, <sim_type>, -1.0, -1.0)`, the verb the eight `node=` walkers already use | **REFUSE** (a slot that resolved in A3 but will not switch is a bug, not a user error — say so) |
| **A5** | `get_raw_index(<rewritten name>)` — the existing rungs 1-4, including the case fold and its `Raw.case_sensitive` suppression | the existing `-1`, reported by name (R803) |

**R202 — THE REWRITTEN NAME, AND THE ONE PLACE THIS IS SUBTLE.** A5 is handed
exactly R111's table: for a **voltage** accessor the **bare argument**, for a
**current** accessor `i(arg)`, and for a wrapper the derived name
`ph(arg)`/`ph(i(arg))`/`re(...)`/`im(...)`.

⚠ **A voltage accessor must NOT emit `v(arg)`, and this is a real trap.** Rung 3
of the shipped ladder *is* the `v()` wrap — `my_snprintf(vnode, S(vnode),
"v(%s)", node)` (`src/save.c:3372`) — so a query that already begins `v(` makes
rung 3 probe `v(v(arg))` and the rung is dead. That matters because names are
stored **bare** by several readers: a VCD signal column (`src/vcd_read.c:668`;
bus bits at `:682-686`), an ngspice `let` vector, and the axis name `time`
itself (`src/vcd_read.c:664`). Emitting the bare
argument keeps rungs 1-2 able to find a bare-stored name **and** leaves rung 3 to
build `v(arg)` for an ngspice raw — i.e. `VT(out)` resolves exactly what a bare
`out` in a `node=` resolves today, which is precisely what §8's resolution-
identity invariant (R709.3, T-O) requires for the 395 rects that carry no
`v(`/`i(` wrapper at all.

Measured, on a hand-written raw storing one name **bare** (`out`) and one
**wrapped** (`v(wrapped)`):

```
  out          -> 1        <- rung 1
  v(out)       -> -1       <- NO rung strips a `v(` wrapper
  OUT          -> 1        <- rung 2
  V(OUT)       -> -1
  wrapped      -> 2        <- rung 3 wraps it
  v(wrapped)   -> 2        <- rung 1
```

**The bare query resolves both storage forms; the `v()`-wrapped query resolves
only one.** That asymmetry is the whole of the rule.

For currents the opposite is true and for the same reason: **there is no `i()`
rung**, so `IT(vs)` must emit `i(vs)` or nothing will wrap it. Measured:
`xschem raw index e5` → `-1` while `xschem raw index i(e5)` → 3.

The resolver therefore re-implements **no rung**. It picks one query string and
lets the shipped ladder do its four. One ladder, one authority (the issue-0305
rule).

**R203 — WHICH FILE.** The accessor names an analysis, never a file. The file is
whatever the surrounding context already says, in this order (call these **steps**
— they are unrelated to the *name* ladder's rungs above):

1. the per-entry `%<rawfile>` from `node_token_split()`, when the entry has one;
2. else the graph rect's own `rawfile=` token;
3. else the **current** database's `rawfile` (`xctx->raw->rawfile`).

**Step 3 exists at only five of the eight `node=` walkers today** and the other
three must gain it: present in `graph_fullyzoom`
(`src/draw.c:3976-3982`), `find_closest_wave` (`:5525-5531`), `graph_point_at`
(`:6575-6581`), `wave_hilight_envelope` (`:7058-7064`) and `draw_graph`
(`:8969-8975`); **absent** from `graph_x_union_rect` (`:3608-3613`) and
`graph_cursor_dbs_rect` (`:3823-3831`), each of which switches only
`if(custom_rawfile[0])`. R211 already asks all eight to change, so for those two
this is one more line in the same edit — but a resolver that assumes the fallback
is universal will silently do nothing in the auto-X-zoom and cursor-database
paths.

⚠ **And there is a NINTH function, outside the eight-walker table.**
`graph_wave_resolve()` (`src/draw.c:8162`) reads only `autoload=`, `node=`,
`sweep=` and `sim_type=` (`:8179-8184`) — **it never reads `rawfile=` at all**, so
it has no graph-level switch and no fallback to add; its only switch is the
per-trace one at `:8202`. The rect's `rawfile=` for that path is read one frame
out, by its single caller `graph_marker_sample()` (`:8252`, the read at
`:8282-8283`), which is **not** a `node_token_split()` caller and appears nowhere
else in this spec. **The marker readout therefore needs its own line**, and it is
the site T-T's "answer a marker readout" leg actually exercises.

**The accessor overrides only the type half; the file half is untouched.**
Consequence worth stating out loud: an accessor is portable — it names no path,
so a schematic that carries `VT(out)` plots against any run of that design, which
a `%<abs-path>` suffix does not.

**R204 — ONE ANALYSIS PER `node=` ENTRY.** Every accessor in one entry must name
the same analysis; a mixed entry is **REFUSED** with both analyses named (R804).
This is F1 restated as a rule, and it is not a limitation the design chose: the
evaluator has one `Raw *`, one point loop, one sweep column and one
`first`/`last` window, and the analyses do not share a point count (measured: 5,
121 and 61 points from one run). `VT(out) VS(out) -` is not a subtraction with a
resampling bug; it is not a subtraction.

**R205 — a `%<…> <sim_type>` suffix and an accessor that disagree: the ACCESSOR
WINS, and the disagreement is REPORTED once.** Both are explicit statements by
whoever wrote the entry, so this is not a defaulting question; but the accessor is
the newer, narrower and more visible of the two, and it is the one a user typed
into an expression rather than the one a tool appended. The report is
`dbg(0, …)` + one CIW line per entry per resolution pass — see §10 L6 for why
"per redraw" is a hazard and what bounds it.

**R206 — a graph rect's `sim_type=` and an accessor that disagree: the ACCESSOR
WINS, SILENTLY.** RULED, §17 Q2.

⚠ **And the rationale must be stated honestly, because the obvious one is
wrong.** `node_dflt_sim_type(graph_sim_type)` (`src/draw.c:3366`) is evaluated at
the *call* and handed to `node_token_split()` as `dflt_sim_type`, which consumes
it in **both** branches — `:3349` (a `%` payload whose type field is empty) **and**
`:3355` (no `%` at all). Since F6 measures that the dominant `node=` spelling
carries no `%` suffix whatsoever, the rect's `sim_type=` is today the effective
analysis of **essentially every trace in the rect**, not merely of `%`-suffixed
ones missing a type. So R206 is not "a per-entry statement beating a defaulting
rule that rarely fires" — it is a per-entry statement beating the rect-wide
setting. The ruling stands because that is what an accessor is *for*, and because
the migration (A7) makes the two agree by construction wherever a `sim_type=`
exists — but note that for the **9 of 16** in-scope rects with no `sim_type=`
there is nothing to reconcile and nothing to infer from (R708).

**R207 — the switch is UNWOUND, absolutely and by index.** A4's switch is
balanced by `node_db_restore(<entry index>)` at the end of the entry and
`node_db_prev_restore(<entry prev>)` at the end of the walk — the existing
helpers (`src/draw.c:3378`, `:3404`), for the existing reason recorded there in
full: **the registry cursor is a pair**, and a walker that restores only
`extra_idx` still moves `extra_prev_idx` and therefore still moves where the
user's next `xschem raw switch_back` lands. A read-only getter must not be able to
do that. ⚠ Both helpers are `static` in `draw.c`, so a `save.c` resolver cannot
call them: **decide explicitly** whether they are de-`static`'d and declared in
`xschem.h`, or whether doors D-b and D-c open-code the pair (D2's decision column
carries this sub-decision).

**R208 — resolution is per ENTRY, not per redraw-of-everything.** The accessor
resolver runs where `node_token_split()` runs, i.e. once per `node=` entry per
walk, which is where the existing per-entry switch already is. It adds no walk.

### 3.2 What it compiles to — the existing token, and the one thing missing

**R210** The accessor compiles to **`node_token_split()`'s `sim_type`
out-parameter** — the same channel the `%<rawfile> <sim_type>` suffix feeds, the
same channel all eight walkers already consume, the same `extra_rawfile(…, type)`
call they already make. There is **no new node-file syntax, no new attribute and
no new registry concept**. That is the whole reason this is affordable.

**R211 — ⚠ AND THE PER-TRACE GATE HAS TO CHANGE, AT EIGHT SITES THAT ARE NOT
IDENTICAL.** F4: the graph level can already say "this analysis, current file";
the trace level cannot, because every call site gates the switch on a non-empty
`node_rawfile` and the `%` grammar has no spelling for a type without a file. The
gate must also fire when the rawfile is empty but the accessor's type differs
from the current database's, with R203 supplying the file — which is **exactly
the substitution `draw_graph()` already performs one scope out**
(`src/draw.c:8969-8972`). The change is not a new policy; it is the graph-level
policy applied one level in.

**The eight gates are three different shapes. Grepping one literal line finds
five of them.**

| walker | line | gate as written today |
|---|---|---|
| `graph_x_union_rect` | `:3628` | `if(node_rawfile[0]) {` — no raw guard |
| `graph_cursor_dbs_rect` | `:3843` | `if(node_rawfile[0]) {` — no raw guard |
| `graph_fullyzoom` | `:4029` | `if(node_rawfile[0] && raw && raw->values) {` — a **local** `raw`, not `xctx->raw` |
| `find_closest_wave` | `:5604` | `if(node_rawfile[0] && xctx->raw && xctx->raw->values) {` |
| `graph_point_at` | `:6645` | same as `:5604` |
| `wave_hilight_envelope` | `:7115` | same as `:5604` |
| `graph_wave_resolve` | `:8202` | same as `:5604` |
| `draw_graph` | `:9017` | same as `:5604` |

An implementer told "identical at all eight" and given one literal line will find
five and silently leave the auto-X-zoom, the cursor-database and the
full-y-zoom paths un-updated — i.e. accessors would work when drawing and picking
but not when sizing or resolving cursors.

**Do not "fix" this by teaching the `%` grammar an empty-rawfile spelling**
(`% {} tran`, `%. tran`). That would be a second way to say the same thing, in a
parser whose entire documented history is issue 0305 — six walkers with three
different behaviours, consolidated into one — pinned by a 168-check structural
test
(`tests/headless/test_node_token_split.tcl`) whose **NDX** leg (NDX1/NDX2,
`:727-732`) asserts the parse exists in exactly one function — and nothing would
emit it.

**R212 — the emitted node= text stays plain.** After migration a graph entry
reads `VT(out)` (or `alias;VT(out)`), with a `%` suffix **only** when the trace
genuinely comes from another *file*. The accessor replaces the type half of the
suffix, so the common single-run case emits **less** text than today, not more.

---

## 4. The engine contract — ONE authority, THREE doors

### 4.1 The authority

**R301** One new C function owns the whole of §2 and §3's parse and rewrite:

```c
/* returns: 1 resolved, 0 not an accessor (caller proceeds as today),
 *         -1 refused (caller reports *why and gives up on this entry)  */
int resolve_accessor(const char *token, char **rewritten, char **sim_type,
                     char **why);
```

It is **pure with respect to the registry** — it parses and rewrites, and it does
not switch. A3's slot search and A4's switch belong to the caller, because the
caller owns the unwind (R207) and already knows the rawfile (R203).

**R302 — it lives in `save.c`, beside the ladder it extends, not in `draw.c`
beside its first caller.** `node_token_split()` is `static` in `draw.c`, and
**both other doors are in `save.c`** — `plot_raw_custom_data()` at `:3520` and
`get_raw_index()` at `:3406`. A resolver placed with its first caller would be
copied by the second. This is the issue-0305 lesson applied before the fact
rather than after it. (The two unwind helpers are the mirror problem and R207
asks for an explicit decision about them.)

### 4.2 The three doors

Named with `file:line` in the idiom of `simulator_profiles.md` §14.7, because a
door that is missed is a spelling that silently returns `-1`.

| # | door | what reaches it | what it must do |
|---|---|---|---|
| **D-a** | `node_token_split()`, `src/draw.c:3330` — **8** walkers | every graph trace: bare name, `v()`/`i()` name, and RPN expression alike | resolve each accessor in the entry, R204-check they agree, set `*sim_type`, rewrite `*expr`; the caller's existing `extra_rawfile()`+`node_db_restore()` pair does A4/R207 — **with the R211 gate change and R203's missing fallback at three of the eight** |
| **D-b** | `plot_raw_custom_data()`, `src/save.c:3520`, reached from `raw_add_vector()` via `xschem raw add`, `src/scheduler.c:10636` | the Calculator's Plot and Evaluate (`calculator.md` R601, R605) and `wviewer::add_trace`'s expression arm (`src/wave_viewer.tcl:4251`) | resolve in a **pre-pass over the whole expression**, before the token loop, because the loop binds `xctx->raw` at `:3529`/`:3535` and cannot change database mid-flight (F1); switch, evaluate, unwind both halves of the cursor |
| **D-c** | `get_raw_index()`, `src/save.c:3406`, reached from `xschem raw index` | "does this name resolve?" checks. It is the only **C-side** verification an emitter has (`calculator.md` R204); the viewer verifies through the Tcl mirror instead, and R306 says why | resolve, switch, look up, **unwind**, return the index *in the accessor's own slot* — and say so in the verb's documentation, because the number is meaningless against any other slot |

**R303 — D-b's pre-pass is not optional and not an optimisation.**
`raw_add_vector()` **creates the destination vector in the current database**
before the evaluator runs. Resolving the accessor after that point would create
the vector in the wrong slot with the wrong length. The order is: parse the whole
expression → agree on one analysis (R204) → switch → `raw_add_vector` → evaluate
→ unwind.

**R304 — D-c must not leak the cursor.** `xschem raw index` is read-only from
every caller's point of view — three shipped Tcl call sites
(`src/wave_viewer.tcl:3721`, `:18113`, `:18124`) and 125 more in
`tests/headless/` — and `get_raw_index()` itself has 48 non-comment references across `src/*.c`, 20 of them in `draw.c`. It therefore owes
`node_db_prev_restore()`'s discipline as well as `node_db_restore()`'s: restore
`extra_idx` **and** `extra_prev_idx`. The measured precedent, from the code that
already learnt it (`src/draw.c:3393-3396`): with prev=1 and current=3, one call
to any of `graph_closest_wave` / `graph_trace_at` / `wave_hilight_points` / a
refused `fullyzoom` made the user's next `switch_back` land on slot 2.

**R305 — no new opcode, no new `Stack1` field, no new `#define`.** The accessor
never reaches the token loop: by the time `plot_raw_custom_data()` lexes, every
accessor has become an ordinary vector name. `calculator.md` R405's rule ("new C
opcodes are added only to `plot_raw_custom_data()`") is untouched because this
adds none.

**R306 — the Tcl mirror moves in lockstep (F8).** `wviewer::validate_rpn`
(`src/wave_viewer.tcl:3676`) must learn the accessor shape, or every accessor
expression is refused by the viewer before the engine ever sees it — and it is
also the **only** thing that reports a bad token today, because `raw_add_vector()`
discards the `-1` (§10 L4). Its companions
`ase::ui::output_kind` (`src/ase_window.tcl:856`), `wviewer::sig_type`
(`src/wave_viewer.tcl:1951`) and `ase::bus_expr_bits` (`src/ase.tcl:325`, regexp
at `:326`) parse the `v(`/`i(` prefix by pattern and must learn it too.

**R307 — THE REWRITE IS TEXTUAL, OVER THE WHOLE ENTRY, AND THAT IS WHAT MAKES
THE DOWNSTREAM CONSUMERS FREE.** D-a rewrites every accessor token inside
`*expr` before returning, so everything that later re-splits that string sees
plain names and needs no change. The consumer that proves the point is the
**bus** path: `get_bus_idx_array(ntok_copy, &n_bits)` (`src/draw.c:9120`) takes
the post-split text, re-tokenises it on `";, \\\n"` (`:2903-2904`) and calls
`get_raw_index(bit_name, NULL)` **directly** (`:2907`) — a resolution site that no accessor
rung would otherwise reach. A textual rewrite covers it for free; a per-token
hook inside `get_raw_index` would see the bit names but could not perform the
**analysis switch**, so the bits would resolve against whatever slot happened to
be current.

One deliberate exception, and it is a feature: **the legend keeps the accessor.**
`draw_graph()` labels from the *unsplit* `ntok` (`src/draw.c:9072` →
`draw_graph_variables`, `:4999-5009`), so a trace written `VT(out)` reads
`VT(out)` on screen while resolving as `out`. That is Cadence's own look; it is
also a pixel change on every migrated schematic (§10 L10).

### 4.3 What the engine does NOT gain

**R310** No verb that "sets the current analysis". The analysis is a property of
an expression, not of a session — that is the entire point, and
`results_selection.md` §17.1 already ruled that a *run* is what a session selects.
`xschem raw switch` keeps doing exactly what it does.

**R311** No change to `.sch`/`.sym` file format, `XSCHEM_FILE_VERSION`, or any
attribute name. An accessor is text inside an existing `node=` token; an old
xschem reading a migrated schematic draws no waveform for those traces and reports
`-1` — the same thing it already does for any signal it cannot find. (It still
draws the **legend entry**, from the literal token — R307's exception.)

---

## 5. Currents — which ngspice spellings `IT`/`IS`/`IF`/`IDC` accept

**⚠ READ THE PROVENANCE FIRST. This census is measured over a corpus that is
almost entirely UNTRACKED and nobody else can reproduce it as written.** Only
**2** `.raw` files in this tree are in git —
`doc/claude/casemode_batch/fixtures/tr_fold.raw` and `tr_preserve.raw` — while
`find . -iname '*.raw'` sees **89**: 22 under `tests/headless/.scratch/`
(`.gitignore:85`), 35 under `doc/claude/ngspice_upstream/` (nested `.gitignore`
files, each `*.raw`), 30 untracked-but-unignored under
`doc/claude/casemode_batch/`, and the 2 tracked fixtures. On a clean checkout the
whole census collapses to **two** records — `i(vs)` in `tr_fold.raw` and `i(Vs)`
in `tr_preserve.raw`, the same signal in the two case modes. It is reported because it is the only evidence of what
ngspice actually writes for this design corpus, and it is labelled because a
reader who tries to re-run it will get a different answer.

⚠ **And a plain `grep -r --include='*.raw' .` finds NONE of it**, which looks
like the corpus is missing and is not. Two independent reasons: the `grep` in
this environment is a wrapper that skips **binary** files and honours **every**
`.gitignore`, including the nested ones — so naming the directory is not even
enough. Use `command grep -ra --include='*.raw' .`, or the form the numbers here
were produced with:
`find . -iname '*.raw' -not -path './.git/*' -exec grep -a … {} +`. The `-a`
matters: most of these raws are binary.

785 `current`-typed variable records, by shape:

| count | shape | a measured example |
|---|---|---|
| 257 | `i(@<c>.<path>[<p>])`, 5 dot-segments | `i(@c.xr1.x0.xc0.c0[i])` |
| 143 | `i(@<c>.<path>[<p>])`, 4 | `i(@b.xr1.x0.brbody[i])` |
| 139 | `i(<name>)` | `i(vs)`, `i(be5)`, and the two phantoms below |
| 103 | `i(<L>.<path>.<name>)`, 3 | `i(v.x1.v1)` |
| 50 | `i(@<c>.<path>[<p>])`, 3 | `i(@m.xm1.msky130_fd_pr__nfet_01v8[id])` |
| 50 | `i(<L>.<path>.<name>)`, 4 | `i(v.x1.x1.v1)` |
| 27 | `i(@<dev>[<p>])`, 1 | `i(@Rg[i])` |
| 14 | `i(@<c>.<path>[<p>])`, 6 | `i(@c.x2.xr4.x0.xc0.c0[i])` |
| 2 | `i(<L>.<path>.<name>)`, 5 | `i(v.x1.x1.x1.vmeas)` |

**Three families**, and two things that are not device currents.

**R401** `IT`/`IS`/`IF`/`IDC` rewrite their argument to **`i(arg)` and nothing
else** (R202). The three families are therefore written:

```
IT(vs)                                      branch current of a named source        (139)
IT(v.x1.x1.x1.vmeas)                        the hierarchical source form            (155)
IT(@m.xm1.msky130_fd_pr__nfet_01v8[id])     the `.options savecurrents` form        (491)
```

and all three land in the shipped ladder **at rungs 1-2, family 2 included**: the
`@dev[param]` shape "needs no rung of its own: it is an ordinary stored name"
(`src/save.c:3346-3349`), and every one of the 155 dotted non-`@` names in this
corpus is *stored* in the long `i(v.…)` form, so rung 1 matches it as written.
Rung 4 (`src/save.c:3395-3397`) exists for the **other** direction — a raw that
stores `i(x1.vp)` while the query says `i(v.x1.vp)` — and no raw file in this
tree stores that spelling, so nothing here exercises it.

**R402 — `IT(i(vs))` is a REFUSAL, not a double-wrap that gets stripped.** It is
the predictable mistake — the user copies a name out of `xschem raw list`, which
prints `i(vs)`, and wraps it. Stripping it silently would give the grammar two
spellings for one signal, in a feature whose entire purpose is that there is one.
Detected at A2 (argument begins `i(` case-blind and ends `)`), message R805. The
symmetric case, `VT(v(out))`, is the same refusal.

**R403 — the accessor NORMALISES NOTHING.** No case folding (rung 2 owns that,
and `raw_case_mode.md` owns rung 2), no `v.` insertion or removal (rung 4 owns
that), no path construction (`calculator.md` R207: read hierarchical names back
from the raw, never build them from `xctx->sch_path`). The accessor's entire
transformation is the R111 table. This is what keeps `raw_case_mode.md` and this
spec from having two opinions about one name — §10 L2.

**R404 — the two shapes that are NOT device currents.**

- **A bare `@<dev>.<path>[<param>]` with no `i(` wrapper is a MODEL PARAMETER.**
  Measured: `@m.xm5.msky130_fd_pr__nfet_01v8[gm]`, typed `admittance`. Device
  *voltages* take a `v(` wrapper around the same `@` body:
  `v(@q.xq1.…[vbe])`, `v(@m.x1.xml.…[vth])`. These are Cadence's `MP` and `OP`
  families (`references/viva_research_raw.json:2058`), which A3 did not ask for
  — a non-goal (§15), not an absence. xschem already composes them:
  `get_fqdevice(param, modelparam, instname)` (`src/token.c:4514`), whose
  `modelparam` argument selects the prefix `"i("` / `""` / `"v("` (`:4524`), so
  adding `MP`/`OP` later is one row in R102 and one branch there.
- **Two simulator-constructed phantoms inside family 1**: `i(i-sweep)`, the DC
  sweep axis of a current sweep (variable index 0), and `i(all)`, the phantom duplicate column a
  released ngspice adds when a run saves exactly one vector (`doc/claude/FAQ.md`,
  and the casemode batch ledger's C1) — the current-side form of the
  better-known `v(all)`. Both are ordinary stored names and resolve;
  neither is a device current, and `i(all)` is one of the reasons the same
  physical current routinely carries two names (§10 L14).

**R405 — the `#` of an auto-named net is stripped by the EMITTER, never accepted
here.** Issue 0154: an unnamed net carries the engine's marker `#netN`, the
netlister emits it without the marker, and a `.save v(#net1)` card makes ngspice
abort the entire analysis — taking every other trace with it.
`ase::ui::sod_expr` already strips it (`src/ase_window.tcl:962`) and
`send_net_to_graph` already strips it (`src/hilight.c:1766`). `VT(#net1)` is
therefore malformed (R121), which is strictly safer than resolving it.

---

## 6. The emit side — every site that GENERATES an expression

This is the half that makes the transition real (A4, A8, A9). Enumerated with
`file:line` rather than gestured at, in the idiom of `simulator_profiles.md`
§14.7. **Grep patterns that find them:** `"v("`, `v(%s`, `"i("`, `i(%s`, `{v(`,
`v($`, `iprefix`. Measured negative worth having: **`src/draw.c`,
`src/callback.c` and `src/scheduler.c` construct no `v(`/`i(` string at all** —
the only C files that do are `hilight.c`, `save.c` and `token.c`.

**R501 — the sites fall into THREE classes, and only one of them is in scope.**

- **Class P (persisted to the canvas).** The string is written into a `.sch`
  `node=` token, or into a Calculator buffer the user reads, edits and saves.
  **These must emit a typed accessor** — this is what A4 means.
- **Class D (persisted into a DECK).** The string becomes a `.save` / `print`
  card, or a file the user keeps for a simulator. **These must stay plain**,
  because ngspice does not speak this grammar — and, measured on ngspice-46, it
  does not *say* so either. A deck carrying `.save VT(out)` and `print VT(out)`
  **completes** (`rc=0`, the raw is written); only the `print` line reports
  anything, `Error: no such function as vt,`, and the `.save` is accepted in
  silence. So the failure mode is not an abort — it is that the card **does not
  mean what was written and nothing tells you**. (R405's abort is a different
  case, `.save v(#net1)`, and belongs to issue 0154.)
- **Class T (transient).** The string is composed, handed straight to
  `get_raw_index()` for one scalar read, and discarded inside the same call.
  Typing it would cost a registry switch and buy nothing. **These stay plain.**

The class is a property of *where the string goes*, not of what builds it, and
**three sites straddle a class boundary**: E1's `sod_expr` (one string, two
arms), E2's `sod_click` (the shared handler that fans out to both), and E7 (whose
composer body exists twice) — plus E19, which is one string in both classes at
once. That is exactly why the rule is written down rather than assumed, and why
§6.1's heading ("must become typed") is an instruction E2 must not follow
wholesale.

### 6.1 Class P — the sites that must become typed

| id | site | `file:line` | emits today | emits after |
|---|---|---|---|---|
| **E1p** | the ASE-L **plot** arm of the shared pick: `ase::ui::dp_queue` | `src/ase_window.tcl:2171`, fed from `sod_click`'s branch at `:2105` | whatever `sod_expr` returned | the typed accessor for this session's analysis. ⚠ **See E1d — the same string is also produced for the deck, and only this arm may be typed** |
| **E2** | the shared Save-Options / Direct-Plot pick handler `ase::ui::sod_click` | proc at `src/ase_window.tcl:2018`; the `sod_expr` fan-out at `:2099`; branches at `:2105` (`dp_queue`) and `:2107` (`sod_queue`) | one string, used for both arms | compute the **canvas** spelling on the plot arm and the **deck** spelling on the save arm. The analysis, like the case mode and the base level, is resolved **once per gesture** before the fan-out, so a bus's bits cannot disagree |
| **E3** | `ase::bus_expr_bits` — outputs-row bus expander | `src/ase.tcl:325`, regexp `:326`, emit `:334` | `regexp {^v\(([^()]+)\)$}` in, `v($b)` per bit out | it is a consumer as well as a producer: it must **parse** the accessor. Whether it re-emits one depends on which arm consumes the row (E1d) |
| **E4** | `send_net_to_graph()` — C, highlight → graph | `src/hilight.c:1758`, emit at `:1777-1778` (ngspice) / `:1780-1781` (Xyce) | **a BARE net name** + colour, `"%s %d "` — no wrapper at all (F6) | the typed accessor; this site has to *gain* a wrapper, not change one. ⚠ The accessor letters go **after** `strtolower(t)` (`:1774`), the way `i(%s%s%s)` already does at `:1898` — otherwise `fold` mode turns `VT` into `vt` (harmless under R106, but the code should not depend on that) |
| **E5** | `send_current_to_graph()` — C, highlight → graph, ammeter/vsource arm | `src/hilight.c:1865`, emit at `:1898-1900` | `i(<prefix><path><t>) <colour>` | the typed current accessor |
| **E6** | `graph_add_nodes_from_list {nodelist}` | `src/xschem.tcl:6516` (dialog-open arm `:6534`/`:6554`, dialog-closed arm `:6585`/`:6587`) | appends E4/E5's tokens verbatim into `node=` | unchanged **if** E4/E5 emit typed — it is a transport, not a composer. Verify rather than assume: it also builds the `alias;` for a bus (`:6543`) |
| **E7p** | `get_fqdevice()` **as reached from the `scope_ammeter` floater** | composer `src/token.c:4514`; the persisting site is `src/actions.c:2793`, which writes `node="tcleval([xschem get_fqdevice [xschem translate <inst> @device]])"` | `i(v.x1.vmeas)` / `i(@m.x1.m1[id])`, substituted at **draw** time | ⚠ **cannot be fixed by wrapping the `tcleval`** (`IT([xschem get_fqdevice …])` expands to `IT(i(…))`, which R402 refuses) **and cannot be fixed by appending a word**: the verb is positional, `get_fqdevice <inst> [<param> <modelparam>]` (`src/scheduler.c:5460-5472`), so a 4-word call takes the `argc > 2` arm and the extra word is **silently dropped** — measured, `xschem get_fqdevice V1 IT` → `i(v1)`. Give the accessor its own position or a `-acc IT` flag, and teach the 2-arg arm to see it |
| **E8** | `graph_add_nodes` — the graph dialog's left listbox | `src/xschem.tcl:6594`, emit at `:6613-6614` | the listbox text, which `graph_get_signal_list` (`:6748`) has already stripped of a `v()` wrapper — voltages only | typed |
| **E9** | `wviewer::browser_send_to_add_trace` | `src/wave_viewer.tcl:11073`, emit at `:11084` | the first selected raw name, verbatim | typed |
| **E10** | `wviewer::add_trace_pick` / `add_trace_dialog` | `src/wave_viewer.tcl:16197` / `:16022` | the picked variable, verbatim | typed |
| **E11** | `wviewer::graph_props` — **the only place a `node=` string is built from the viewer's model** | proc `src/wave_viewer.tcl:3515`; the three shapes at `:3548` / `:3550` / `:3552`; the suffix from `wviewer::db_suffix` `:2571` | three literal shapes: bare `<vec>`; `"<name>;<vec>"`; `"<name>;<vec>%<rawfile> <sim_type>"` — no `v(` is ever added | the suffix's **type half becomes redundant** for a same-file trace (R212); the file half stays |
| **E12** | the Calculator's voltage/current selectors | `src/calculator.tcl` — **specified, not built.** All 22 selectors are inert: 8 are `-state disabled` with a stated reason (`calc::sel_disabled`, `:999-1010` — seven RF ids plus `mp`), and the other 14 are enabled radiobuttons whose `-command` reaches `calc::sel_click` (`:1105`) → `calc::inert` and only writes a status line. There is **no** `v(`/`i(` emission and **no** `xschem raw index` call anywhere in the file | nothing | **born typed** — the one site with no migration, and the reason A1 could rule "Calculator item 8 ships speaking `v(out)`": it does not have to |

**How E4/E5 are reached, because it is not the obvious way.** Both C graph
senders are called only from `hilight_net(XSCHEM_GRAPH)`, and there are two doors
into that: `act_highlight_send_waveform` (`src/callback.c:5576`), the registered
action `hilight.send_to_waveform`, which **ships UNBOUND** — no row in
`src/keybindings.csv` or `src/mousebindings.csv`, and its only line in
`src/cadence_style_rc` is commented out; and **`xschem send_to_viewer`**
(`src/scheduler.c:11936`), which calls `hilight_net(viewer)` at `:11954` with
`viewer = atoi($sim(spicewave,default))` and reaches the graph senders whenever
that index is `XSCHEM_GRAPH` and the configured tool name contains neither `Gaw`
nor `Bespice`. **That one has exactly one live route** — the hand-written menu item
`Highlight ▸ Send selected net/pins to Viewer` (`src/xschem.tcl:17617-17618`).
Its `-accelerator Alt+G` is a **label**, not a binding: there is no keysym-103 row
in `keybindings.csv` and the C `case 'g'` is gone. So E4/E5 are live in a default
install, through one menu item whose name does not mention waveforms.

**⚠ E19 — AND ONE STRING IS IN BOTH CLASSES AT ONCE.** An outputs row picked
through `Outputs ▸ To Be Plotted ▸ Select On Design` is stored `{save 1 plot 1}`,
so the **same** `sod_expr` string is `.save`d/`print`ed into the deck (E1d) *and*,
after each run, handed by `ase::ui::auto_plot` (`src/ase_window.tcl:4932`; the
per-row map at `:4982`, the add at `:4990`) to `wviewer::add_trace` — from which
`graph_props` writes it into a persisted `node=` (E11). **The E1p/E1d split is a
split of *arms*, not of strings**, and this is the string that takes both.

Whoever builds this must decide the shape explicitly. The only option that keeps
both consumers correct is to **store the deck spelling and type on the way out**:
the row keeps `v(out)`, and `auto_plot` applies the session's analysis when it
hands the string to `add_trace`. Typing the stored row instead would break the
deck; leaving `auto_plot` untyped would leave the canvas untyped for exactly the
rows a user picked most deliberately.

### 6.2 Class D — the sites that must stay plain, because a deck reads them

| id | site | `file:line` | why |
|---|---|---|---|
| **E1d** | the ASE-L **Save-Options** arm: `sod_expr` → `sod_queue` → `sod_merge` → the session's `outputs` list | `sod_expr` `src/ase_window.tcl:961`; `sod_queue` `:2144`; `sod_merge` `:1313`, row built `:1329`; stored `:2154` | `render_deck` emits `.save [dict get $o expr]` (`src/ase.tcl:4602`) and `print [ase::backend::ngspice::print_arg [dict get $o expr]]` (`:4651`) straight from that list. **Typing this arm writes `.save VT(out)` and `print VT(out)` into the deck.** Measured on ngspice-46 that does not abort — the run finishes and the raw is written — but the `.save` is silently meaningless and the `print` errors on its own line. A silent wrong answer, which is worse. This is the single most important entry in §6 |
| **E7t** | the `@spice_get_current` / `@spice_get_modelparam` / `@spice_get_modelvoltage` back-annotation composer | an **inlined duplicate of `get_fqdevice()`'s body**, `src/token.c:5212-5270` — not a call; nothing in `token.c` calls `get_fqdevice()` | back-annotation: composed, read, printed on the schematic, discarded. Two bodies, so a fix to one is not a fix to the other |
| **E16** | `print_hilight_net(3)` — writes `.save` cards into a temp file, shows it in a `viewdata` window (`:4530`) and unlinks it (`:4536-4537`); the user can Save As from there | `src/hilight.c:4442`, emit `.save v(%s%s)` at `:4484-4487` with the `#` strip at `:4487`; **bound**: menu `xschem print_hilight_net 3` at `src/xschem.tcl:17525` (Alt-Ctrl-J) and the C chord at `src/callback.c:7627` | not Class T, because the text leaves the program; not Class P, because nothing about it is a `node=`. **It is the reason this spec has three classes and not two**, and §6's own grep pattern `v(%s` finds it |
| **E17a** | `create_plot_cmd()` — the batch plot-command composer | `src/hilight.c:911`, emit `:1013` / `:1024`; live via `Simulation ▸ Send highlighted nets to viewer` (`src/xschem.tcl:17691`) | writes another tool's protocol |
| **E17b** | `send_net_to_gaw` / `send_current_to_gaw` | `src/hilight.c:1789` / `:1914`, reached from `hilight_net(GAW)` | they write `copyvar v(<path><tok>) sel #rrggbb` down a socket to gaw. gaw does not speak this grammar |
| **E18** | the BESPICE senders | the two composers `src/hilight.c:1715` and `:1830` (three call sites, `:2605`, `:2623`, `:2636`) | same argument |

### 6.3 Class T — transient lookups

| id | site | `file:line` | why |
|---|---|---|---|
| **E13** | the ngspice back-annotation road: `ngspice::lookup` and `ngspice::get_current` | `src/xschem.tcl:4010` (probe keys `[list v($name) $lc v($lc)]` at `:4014`) and `:4020` (ngspice composition `set n i($n)` at `:4054`; the Xyce arm opens `:4055` and composes at `:4062`). `ngspice::get_node` (`:4123`) is the same road | lookup keys, resolved against the current database and discarded |
| **E15** | `wviewer::signal_list_all` and the Signal Browser's tree labels | `src/wave_viewer.tcl:2430` | a **display** of names the database actually holds. The browser shows what is there; the accessor is what you *write*. Conflating them would put `VT(out)` in a list of vectors none of which is called that |

**R502 — E15, E17 and E18 are where a well-meaning sweep will get this wrong**,
because all three look like emit sites to a grep for `v(`. None is Class P. And
**E16 is where a sweep will get it wrong in the other direction**, by missing it
entirely.

**R503 — Direct Plot, after (A8), and the obstacle A8 does not mention.**
`ase::ui::dp_finish` (`src/ase_window.tcl:2302`) resolves the session's analysis
with `ase::plot_sim_type` (`src/ase.tcl:1934`), which loops the enabled analyses
(`:1937`) inside a walk of `{op dc ac tran}` and returns the **last** match — a
fixed priority, tran over ac over dc over op, applied silently. **That is the
ambiguity this whole spec exists to remove, and it is currently resolved by a
hard-coded preference order.**

⚠ **But "the analyses the run produced" is not the enabled list.** `render_deck`
emits a single `write [raw_file $state]` (`src/ase.tcl:4668`) which, by its own
comment at `:4654-4657`, writes **"the CURRENT (= last analysis) plot"**. So a
run with three enabled analyses produces a raw containing **one**. Offering the
enabled list would offer analyses whose samples are not in the file. Making A8
real therefore requires changing that `write` — e.g. to the
`write <file> dc1.all tran1.all ac1.all` form §11's fixture uses — and that is
**out of scope here** (§18), which makes A8 a two-part job and not the cheap one
the brief expected.

**R504 — and the run path loads one ANALOG analysis.** `ase::attach_dbs`
(`src/ase.tcl:2866`) reads one raw with one `sim_type`, then drops every other
slot (`:2912-2919`, comment: "drop everything that is not the DB just read") — and then
reads every VCD in `$vcdfiles` (`:2921-2925`), returning `1 + [llength $got]`
(`:2929`). So the registry routinely ends with several slots, just never two
analyses of one raw. The two-analyses state the accessors disambiguate is
reachable through the legacy Waves menu, through scripted `xschem raw read`, and
through a rect's `rawfile=`/`autoload=`. **This spec does not change
`attach_dbs`** (§18) — but it is the prerequisite for changing it.

**R505 — Ctrl-4, after (A9), RULED.** The chord is
`bind .drw <Control-Key-4> {ase::direct_plot_for_current; break}`
(`src/cadence_style_rc:264`), one line, overriding the C default "choose drawing
layer 4" (`src/callback.c:7246-7250`; `:7239-7243` is the unmodified `4` key,
"toggle pin logic level"). It reaches `ase::direct_plot_for_current`
(`src/ase.tcl:3901`) → `ase::ui::direct_plot`, which is **analysis-blind**.

The user's ruling (§17 Q5), in full:

| the run's plottable analyses | Ctrl-4 |
|---|---|
| exactly one, of any type | **plots it**, emitting that analysis's accessor |
| more than one, including `tran` | **plots the transient**, emitting `VT`/`IT` |
| more than one, no `tran` | **no plot**; an error line in the CIW naming the analyses it found |
| `op` only | no plot — `dp_finish` already refuses this (`src/ase_window.tcl:2304-2308`) |

**Ctrl-4 never opens a chooser** — A9's first two sentences, *"Ctrl-4 is not
Direct Plot. It is the transient bindkey."*, forbid it. Note the `op` row is about `op`
and **not** about `VDC`: by R103 `VDC` also resolves against a single-point `dc`
slot, and a session whose enabled analysis is a one-point `dc` yields
`plot_sim_type` = `dc`, reaches the plot path, and has a `VDC` route.

---

## 7. Backward compatibility — `v()`, `i()`, and the bare name

**R601 — `v(out)`, `i(vmeas)` and a bare `out` all keep working, everywhere, with
today's meaning: "resolve against the current database."** No deprecation, no
warning, no flag. Ruling A4, and the reason it is not negotiable: 666 tracked
graph rects carry a `node=`; **16** contain a `v(`, **264** contain an `i(`, and
**395** contain neither wrapper. Every one of them must still draw. (§8 decides
which get *rewritten*; this rule says none of them *breaks*.)

**R602 — "the current analysis" is `xctx->raw->sim_type`, and it is a registry
cursor, not a setting.** Nothing about that changes. It is what makes an untyped
reference ambiguous, and saying so plainly in the docs is part of the deliverable
— see R803's message.

**R603 — with two analyses of one file loaded, an untyped reference resolves in
whichever slot is current, silently.** Measured on the three-slot registry of
§1.2 F3: `v(out)` is column 3 in `dc`, column 3 in `tran` and column 12 in `ac`,
and returns three different sets of numbers with no diagnostic. **This is not a
bug this spec fixes** — it is the pre-existing behaviour A4 preserves. The
accessor is the way to *opt out* of it.

**R604 — a reader can tell the two spellings apart by inspection.** A typed token is one whose leading identifier is one of the
twelve reserved identifiers — eight accessors, four wrappers — followed by `(`. Nothing else in a `node=` has that shape today (R122), so an old xschem
reading a migrated schematic answers `-1` for those traces and **draws no
waveform** — while still drawing the legend entry from the literal token
(R307's exception; `draw_graph_variables` is called at `src/draw.c:9072`, before
`idx` is resolved at `:9101`). No version bump (R311).

**R605 — ⚠ WHAT DOES NOT CHANGE SPELLING: THE DECK.** `.save` cards, `.plot`,
`.print`, `FUNC=`, `value=`, `spice_sym_def=` and the schematic `S {}` SPICE
block all keep emitting `v(...)`/`i(...)`, because **ngspice does not speak this
grammar** — this is §6's Class D, stated as a rule. Measured: of the 420 `v(`
occurrences in tracked `.sch`, only **66** are inside a `node=`; **273** are in
`value=`, **44** in the `S {}` block, **33** in `FUNC=`, 2 in `spice_sym_def=`, 1
in `sweep=`, 1 in `author=` (273+66+44+33+2+1+1 = 420). And **20** tracked `.sym`
carry a lowercase `v(` (24 occurrences) — every one of them in `format=` or
`template=`, e.g. `spice_probe.sym:28` `format=".save @attrs v( @@p )"`; 20 more
`.sym` carry an uppercase `V(`, which is where the often-quoted "40 `.sym`" comes
from. **A migration that rewrites any of those breaks simulation.** The mapping
between the canvas spelling and the simulator's happens in the resolver (R202);
the `.save` side must keep asking for the vector the graph will look up.

**R606 — the same rule protects the two committed variable corpora.**
`tests/headless/fixtures/tb_bandgap_vars.txt` (424 lines, 365 `v(` names) and
`tb_charge_pump_vars.txt` (1191 lines, 864) are ngspice `Variables:` sections
consumed by **four** signal-browser suites (`test_wave_sigbrowser_2pane.tcl`,
`_keys.tcl`, `_panes.tcl`, `_sea.tcl`). **They are evidence of the wire format
and must not be rewritten.**

---

## 8. The migration (A7)

### 8.1 What is actually in scope — measured, and both smaller and larger than the brief

| the brief says | measured | in scope |
|---|---|---|
| "24 tracked schematics carry `v(...)` inside a `node=`" | **28** files by `node=.*\bv\(`. The 24 appears exactly when the 4 files whose only such hit is the device-parameter form `v(@q.xq1.…[vbe])` are excluded | see below |
| — | of the 28, only **16** carry it on a **graph rect**; the other 12 carry it on an `ngspice_get_value` / `ngspice_get_expr` **instance**, whose `node=` is a back-annotation label read by a different evaluator | **16 graph-rect files** |
| "420 `v(...)` occurrences" | **420 confirmed** for lowercase `v(` at a word boundary. Two things it hides: **189 uppercase `V(`** it does not count, and the fact that only **66** are inside a `node=` (R605) — of which only **36** are on a **graph rect** and 30 are on instances | **36 `v(` tokens** |
| — | ⚠ **and the census is `v(`-only, while R706 maps `tran`→`VT`/**`IT`**.** Measured: **264 graph rects in 156 files** carry an `i(` inside a `node=` (435 occurrences on graph rects), and **255 of those rects, in 156 files, contain no `v(` at all**. A line-oriented grep agrees on the **file** count (`git ls-files '*.sch' \| xargs grep -l 'node=.*\bi('` → 156) and on nothing else: it cannot separate a rect `node=` from an instance one, and a multi-line `node=` both over- and under-counts | **+435 `i(` tokens** |
| — | the union of the `v(` and `i(` graph-rect files is **163**, not 16 | **163 files** |
| — | a **second** graph-rect attribute is in the same surface: `sweep=v(d10v5)`, once, in `sky130A/xschem_libs/sky130_tests/test_nmos/schematic/test_nmos.sch:59` — a file **not** among the 28 | **+1 attribute**, 0 new files (that rect is already inside the 163) |
| — | the 28 span **five** trees — `xschem_libraries_oa` 9, `xschem_libs_newsym` 7, `xschem_library` 6, **`sky130A` 4**, **`tests/test_sweep_diff` 2** — with **17 distinct file contents** and **10 distinct design names**. One of the 16 in-scope graph-rect files is the `tests/test_sweep_diff` copy of `cmos_example`, byte-identical to the OA one. **"Edit every copy across the three library trees" edits 15 of 16** | all copies, five trees |
| — | **only `xschem_library/` is installed** (`Makefile:22-26`; the other trees have no Makefile). **6 of the 28 are shipped to users** | user blast radius: 6 |
| "no tracked `.sym`" | confirmed: **zero** tracked `.sym` has `v(` in a `node=`; the 8 that mention `node=` at all carry `template="name=r1 node=xxx …"` | none |

**R701** The migration rewrites **`node=` and `sweep=` on graph rects, and
nothing else.** Not `value=`, not `FUNC=`, not `S {}`, not `format=`, not
`template=`, not a fixture corpus (R605, R606), and not the 30 instance `node=`
values in 12 files (§15).

### 8.2 How, and the four traps

**R702 — it is a TEXT rewrite, not a load-and-save.** Measured: a load+save
round-trip of a `file_version=1.2` schematic is **not** byte-neutral in this
build — it rewrites the header to `version=3.4.8RC file_version=1.3` and inserts
an `F {}` record, three changed lines. **130 of the 163 in-scope files are still
1.2** (827 of 989 tracked `.sch` are, tree-wide) — 9 of the 16 `v(`-bearing ones,
plus the `sweep=` file — so the editor route would churn 130 headers for nothing. It is diff noise rather than a test failure: nothing in
`tests/` byte-compares a **tracked** `.sch` against a committed baseline — the
suites that do byte-compare `.sch` compare two files they generate themselves.

**R703 — but the text rewrite must parse the way the C parses, and a naive `sed`
corrupts six of the 28 files.** Two traps, both verified against the binary:

1. `load_ascii_string()` (`src/save.c:5018`) strips **one** level of backslash
   escapes from a `{…}` block.
2. `SPACE()` (`src/token.c:24`) counts **`;` and `\0`** as whitespace, so an
   **unquoted** attribute value terminates at the first semicolon.

A parser that skipped both found 833 of the 923 `node=` records in the tree and
lost 6 of the 28 files; with both, it agreed with
`xschem getprop rect 2 <i> node` on the record **inventory** exactly — 923
records, 666 rect + 257 instance. **Cross-check the rewriter's inventory against
the binary's own dump before touching a file.**

⚠ **But do not diff the VALUES against `getprop`.** 45 of the 666 rects carry a
`tcleval(...)` `node=`, and what the engine hands back for those is a *resolved*
string that is nowhere in the file text. Those 45 cannot be rewritten textually at
all in the general case — the accessor would have to be applied to whatever the
`tcleval` produces, which is E7p's problem one layer out — so the migration must
**list them and leave them**, not silently mis-diff them.

**R704 — `sim_type=` may appear AFTER `node=` in the same rect**, so a
line-oriented rewriter cannot assume ordering; parse the whole `{…}` block first.
Real example: `xschem_library/ngspice/solar_panel.sch` has `node=` at `:138-141`
and `sim_type=tran` at `:147`.

**R705 — a `node=` entry is an EXPRESSION, not a name, and the rewriter must
respect all three grammars inside one value.** From the tree, **as
`load_ascii_string()` leaves the value in memory** (the on-disk text carries one
more level of backslashes — that is R703's trap, and this is its best example):

```
node="diffout@2uA;v(diffout)%0                 <- alias ';' expr '%' dataset
diffout@10uA;v(diffout)%1
diffout@100uA;v(diffout)%2"                    xschem_library/examples/cmos_example.sch:66-68

node="Panel power; i(Vpanel) v(PANEL) *        <- alias ';' RPN: mixed v()+i(),
Led power; i(Vled) v(LED) *                       postfix ops, UPPERCASE names
Avg.Pan. Pwr; i(Vpanel) v(PANEL) * 20u ravg()
SUN \\%; SUN 100 *"                            xschem_library/ngspice/solar_panel.sch:138-141
```
(on disk that last line reads `SUN \\\\%; SUN 100 *"` — four backslashes.)

The second block is the shape that matters: `VT(...)`/`IT(...)` are **tokens
inside** that expression, replacing `v(PANEL)` and `i(Vpanel)` individually, and
`SUN` — a bare name — is a fourth thing in the same value.

### 8.3 Which accessor — and the case the brief assumes away

**R706** For a rect that carries `sim_type=`, the accessor is implied:
`tran`→`VT`/`IT`, `dc`→`VS`/`IS`, `ac`→`VF`/`IF`. That is ruling A7's premise.

**R707 — ⚠ AND IT DOES NOT HOLD FOR MOST RECTS.** Measured: of the 666 graph
rects carrying a `node=`, only **171 carry `sim_type=`** — 495 do not. Narrowed
to the 16 rects that contain a `v(`: **7 have `sim_type` (4 `dc`, 3 `tran`) and
9 do not.** The 9 are the `pv_ngspice`, `solar_panel_xyce` and `rom2_sa` copies.
**An absent `sim_type=` is not "tran by default": it means "whatever raw is
current"** — `draw_graph()` falls back to `xctx->raw->sim_type`
(`src/draw.c:8999-9000`) and a NULL type matches *any* analysis
(`src/save.c:1843`, `:1936`).

**R708** So the rewrite has three buckets, and only the first is mechanical:

| bucket | rule |
|---|---|
| rect has `sim_type=` and it is one of `tran`/`dc`/`ac` | rewrite mechanically per R706 |
| rect has no `sim_type=` | **do not guess.** Read the schematic's own SPICE block for the analysis card it runs, record the finding per file in the batch ledger, and rewrite only where the deck is unambiguous. Where it is not, leave the token untyped — R601 guarantees it keeps working |
| rect has `sim_type=distrib` (5 files) or `sim_type=foo` (1 file) | **out of scope.** Neither string is one of the eight `Plotname:` phrases `read_dataset()` matches in its six branches (`src/save.c:883-919`); both reach the registry through the literal fall-through at `:920-931`. Leave them alone and say so |

**R709 — what proves the rewrite did not change what a schematic plots.** Three
things, in increasing strength:

1. **Netlists are untouched, and this is measured, not assumed.** A graph rect's
   `node=` reaches no netlister. Verbatim check: rewriting the three `v(diffout)`
   traces in `xschem_library/examples/cmos_example.sch` — one of the five cases
   in `tests/headless/cases.txt` — produced a netlist differing only in the
   `** sch_path:` comment, which `tests/headless/run.sh`'s `normalize()` deletes;
   the normalized output diffs **empty** against
   `tests/headless/gold/cmos_example.spice`. **No gold promotion is needed for
   the `node=` edit.** (`tests/headless/gold/` holds six files, none containing
   `node=`; its regeneration verb is `tests/headless/run.sh --update-gold`, which
   `rm -rf`s the directory and recreates it, and a NEW normalized artifact absent
   from gold is reported `NEW <base>` and FAILS the run.)
2. **Trace-count and name identity per rect.** Before and after, for every rect:
   the number of `\n`-separated entries, the alias half of each, and the `%`
   suffix of each must be byte-identical; only the vector token changes.
3. **Resolution identity.** With the file's own raw loaded, every rewritten token
   must resolve to the **same column index** the old one did. This is the check
   that catches a wrong accessor — and it is the check R202's bare-argument rule
   exists to keep passing for the 395 unwrapped rects.

**R710 — SEVERAL committed tests assert the on-canvas spelling and must be
updated with the migration.** The known ones — the first two asserting `graph_props`' output, the third the
rect property it writes — rather than using `v(` as fixture data:

- `tests/headless/test_wave_viewer.tcl:268-269` — `check_true "H1 props carry node=\"v(d)\""`
- `tests/headless/test_wave_crossdb_trace.tcl:196-197` — `P7 current-DB trace emits a bare vec (byte-identical to pre-D1)` → `{"v(a)"}`, whose own comment at `:192-194` reads *"Every existing viewer test and all 127 shipped schematics with embedded graphs depend on this being untouched."*
- `tests/headless/test_wave_modes.tcl:1712-1713`

⚠ **Split the rule rather than blanket-updating them.** Migrating a *schematic's*
stored trace is not the same as changing what the *viewer emits* for a
newly-added trace. The three tests above pin the second; only the emit-side items
(§6.1 E11) may move them, and P7's comment is the reason to be careful. Do **not**
quote a "141 literal-`v(` assertion lines" figure: six plausible counting rules
give 101, 119, 124, 163, 172 and 199, and none gives 141.

---

## 9. Messages and refusals

`calculator.md` R607 states the standard this feature is held to: *"A bare
'expression error' is not acceptable — this is the single worst failure mode of
the Cadence original."* Every message below names the token.

**R801 — malformed accessor.** `VT()`, `VT(a b)` (which cannot even reach here —
it is two tokens), `mag(out)`, `mag(mag(VF(out)))`, `VT(d[3:0])`:

```
VT(): accessor needs a signal name -- VT(out), VT(x1.x2.net5)
mag(out): a wrapper takes an accessor -- mag(VF(out)), not mag(<name>)
VT(d[3:0]): one accessor names one signal -- write VT(d[3]),VT(d[2]),... 
```

**R802 — no such analysis loaded.** Names the analysis, the file, and what *is*
loaded, because the fix is almost always "read the other one":

```
VT(out): no `tran` analysis loaded from /path/run/cell_ase.raw
         loaded from that file: dc, ac
         (xschem raw read <file> tran, or set autoload=1 on the graph)
```

The `autoload` clause is a real lever, not politeness: a rect's `autoload=true`
turns the walker's `extra_rawfile()` `what` from 2 (switch only) to `1|32` (read +
suppress warnings), so a rect can register the missing slot as a side effect of
drawing. ⚠ **The mapping is not uniform.** Nine sites read the token; only six
carry the full `0→2` **and** `1→33` pair — `src/draw.c:5515`, `:6569`, `:7052`,
`:8179`, `:8277`, `:8959` — while three map only the `0→2` half and leave
`autoload=true` at a bare `1` (`:3602`, `:3821`, `:3970`). **Whether an accessor
should imply `autoload` is D4** (default: no).

For `VDC` specifically, a multi-point `dc` slot gets its own line (R103):

```
VDC(out): the only `dc` analysis in cell_ase.raw has 41 points -- that is a
          sweep, not an operating point. Write VS(out).
```

**R803 — the name is not in that analysis.** This is the existing `-1`, given a
message it never had. It must say which slot answered, because "not found" is
misleading when three slots are loaded:

```
VT(midnode): `midnode` is not in the `tran` analysis of cell_ase.raw
             (it IS in `ac`; try VF(midnode))
```

The "it IS in" clause is worth the extra registry walk: it is the exact ambiguity
the feature exists to remove, caught at the moment the user meets it.

**R804 — mixed analyses in one entry** (R204):

```
"VT(out) VS(out) -": one expression, one analysis. This names `tran` and `dc`,
                     which have different sweeps and different point counts.
```

**R805 — the double-wrap** (R402):

```
IT(i(vs)): drop the inner i() -- write IT(vs)
VT(v(out)):   drop the inner v() -- write VT(out)
```

**R806 — a wrapper on a non-AC accessor** (R116). Names the analysis and the
alternative, and says **wrapped** where it means wrapped (R114):

```
phase(VT(out)): a transient signal has no phase. Did you mean phase(VF(out))?
                (phase() is the WRAPPED phase, +-180; append cph() to unwrap)
mag(VT(out)):   a transient signal is already its own magnitude -- write
                `VT(out) abs()`
```

**R807 — every message goes to the CIW, not to `dbg`.** Today the whole failure
is `dbg(1, "plot_raw_custom_data(): no data found: %s\n", n)`
(`src/save.c:3644`) — level 1, invisible at default verbosity — and then
`raw_add_vector()` discards the `-1` (issue **0418**). Measured, at HEAD:

```
xschem raw add k  {VT(out) 2 *}   ->  1        (success)
xschem raw values k               ->  0 0      (an all-zero column)
xschem raw add k2 {v(out) 2 *}    ->  1
xschem raw values k2              ->  2 4      (the control)
```

**A new feature must not ship into that.** `ciw_echo` (`src/ciw.tcl:120`) is the
house channel — see `doc/claude/FAQ.md`; never `puts`, never the status bar.

**R808 — a message is emitted ONCE per entry per resolution pass, not once per
point and not once per redraw.** §10 L6.

---

## 10. Landmines — the ones that will bite an implementer

| # | landmine |
|---|---|
| **L1** | **The evaluator is bound to one `Raw *` before the first token** (`src/save.c:3529`, `:3535`, `:3676`). The blocker is not the `Stack1` struct — it is file-private and could gain a field — it is one point loop, one sweep column, one `first`/`last` window, and per-analysis point counts that differ (5 / 121 / 61, measured). F1, R204. |
| **L2** | **The case fold covers the WHOLE token, prefix included.** `raw_fold_key()` is `strdup` + `strtolower` over the entire string (`src/save.c:3233-3239`). Measured on a hand-written raw whose `Variables:` section names a vector `VT(MidNode)`: all six casings resolve to it on a fold/preserve database, and on the same file read `-case distinguish` **only the exact spelling survives** — including `vt(MidNode)`, where only the *keyword* differs in case. **So an accessor implemented as "a stored-name shape" inherits the database's case discipline, and `distinguish` breaks the keyword itself.** R106 puts the keyword compare in the parser, before the ladder, for exactly this reason. |
| **L3** | **`re()` / `im()` are operators AND name prefixes AND (nearly) wrappers.** They cannot collide, because the operator arms are exact whole-token `strcmp` — but the reasoning is subtle enough that **R110 keeps the wrapper set to `mag`/`phase`/`real`/`imag`** and does not add `re`/`im` as prefix spellings. §2.3. |
| **L4** | **`raw_add_vector()` reports success on a rejected expression and leaves an all-zero column** — issue **0418**, re-measured in R807. The only thing between a user and a silent zero trace is the Tcl pre-gate `wviewer::validate_rpn` (defined `src/wave_viewer.tcl:3676`, called from `add_trace` at `:4244`), which is *not* on the Calculator's or a scripted caller's path. **Fix or fence 0418 in the same batch**, or every accessor typo plots a flat line. |
| **L5** | **`wviewer::sig_bare` already bares an accessor and `wviewer::sig_type` does not classify one.** `sig_bare` (`src/wave_viewer.tcl:2155`) matches the generic `^[A-Za-z_][A-Za-z_0-9]*\((.*)\)$`, so `VT(out)` → `out` **today**; `sig_type` (`:1951`) keys on the literal two-character prefixes `v(`/`i(` and returns `other`. **The two disagree the moment an accessor exists**, and both feed the Signal Browser's classification. Pinned by `test_wave_sigsearch.tcl` ST01/ST03, SB01/SB04/SB05/SB08/SB09. Filed as **0512**. |
| **L6** | **A `node=` walker runs on every redraw.** A CIW line per failed entry is a CIW line per redraw — a pan over a broken graph floods the console. Rate-limit per (rect, entry) per resolution pass, the way the existing warning at `src/draw.c:9005` does *not*, and say so in the code. |
| **L7** | **`wviewer::repair_currents` will not recognise an accessor.** Its predicate is `is_current_ref` (`src/wave_viewer.tcl:2836`), `regexp -nocase {^(i\(.+\)\|@.+)$}`, and the pass itself (`:2880`, `:2908`, `:2932`) exists to rewrite an unresolvable current token to the database's own spelling. `IT(vs)` fails that regexp, so a repairable accessor current is silently not repaired. |
| **L8** | **`ase::ui::plot_map_expr` rewrites a leading minus into RPN** (`src/ase_window.tcl:1340`): `-i(v1)` → `i(v1) -1 *`. Checked, and it is **already generic** — the body tests only `[string index $ex 0] eq {-}` with no `v(`/`i(` test — so `-IT(v1)` → `IT(v1) -1 *` works unchanged. Listed so nobody "fixes" it into a wrapper-aware form and breaks the general case. |
| **L9** | **`get_fqdevice()` probes the loaded raw and rewrites itself.** Its resistor→B-source fallback (`i(@r…[i])` → `i(@b.<path>b<dev>[i])`) fires only when the first spelling misses `get_raw_index`. Measured: with **no** raw loaded, `xschem get_fqdevice R1` → `i(@br1[i])`; with a raw holding `i(@Rg[i])` loaded, `get_fqdevice Rg` → `i(@rg[i])`. **So the name it composes depends on which slot is current** — the very thing accessors exist to pin down. E7p inherits this. |
| **L10** | **The legend text is the UNSPLIT token.** `draw_graph()` hands `ntok` — suffix and all — to `draw_graph_variables` (`src/draw.c:9072`), which labels with `find_nth(ntok, ";", "\"", 0, 1)` (`:4999-5009`), and it does so **before** `idx` is resolved at `:9101`. A trace written `VT(out)` with no alias reads `VT(out)` in the legend, and an *unresolvable* accessor still gets a legend entry with no waveform. That may be wanted (it is Cadence's own look) but it is a **pixel change on every migrated schematic** and therefore a look debt (§11). |
| **L11** | **SIX documentation errors, in four documents — two of them in the house explainer.** `doc/claude/code_analysis/waveform_subsystem_reference.md:143` writes the per-trace suffix as `%rawfile%simtype` (it is `%[dataset] <rawfile> [<sim_type>]`, space-separated — `src/draw.c:3339-3348`), and `:180` gives `get_raw_index` at `~1677` (it is `:3406`). The rest are elsewhere: `results_selection.md` §19 gives the AC derived names as `ph(v(out))` (they are `ph(out)` for a `v(`-prefixed name — §0(b)); and `calculator.md:30` — the row *"RPN expression evaluator over waveform data, ~54 ops"* citing `plot_raw_custom_data()` at `src/save.c:2381` — is wrong twice (the count is **52**, the line is **:3520**). `tests/headless/test_del_negative_arg.tcl:6` carries the same stale `:2381`. Correct all of them when this work lands. |
| **L12** | **At least SIX live stale citations in `wave_viewer.tcl` comments**, exactly the class the discipline note warns about — and the real number may be higher; every `save.c` cite that was opened was stale. Confirmed: `:2355` cites `save.c:1225` for `extra_rawfile()` (actual `:1835`); `:2368` cites `save.c:1456-1465` for `raw info`'s print (actual `:2113`; `:1456` is inside `raw_deletevar`); `:2613` cites `save.c:2994` for rung 4 (actual `:3395`); `:2615` cites `save.c:2917` for `raw_lookup_name` (actual `:3307`); `:2663` cites `save.c:2867` for `raw_build_fold_table()` (actual `:3242`); `:3678` cites `save.c:1855-1939` for the operator table (actual `:3553-3636`). `raw_case_mode.md` has **at least four** of its own: `:1291` cites `raw_case_reread()` at `scheduler.c:10697` (actual `:10095`), `:261` cites `sim_is_xyce` at `xschem.tcl:2787` (actual `:4165`), `:1478` cites `ngspice::lookup` at `xschem.tcl:3751` (actual `:4010`), and `:1922` cites `run_cmd` at `ase.tcl:3238` (actual `:4707`); the two cites at its `:1372` are correct. **Re-grep, never copy.** |
| **L13** | **`inf`, `nan`, `infinity` and `0x10` are eaten by the NUMBER rung.** `strtod` is case-insensitively generous, so a raw containing a vector named `inf` is already unreachable. Measured, and **not** a problem the accessors create — but `IF(...)` is one character from `inf`, and a reviewer will ask: `strtod` consumes **0** characters of all eight accessor spellings. |
| **L14** | **The same physical current routinely carries two or three names in one raw.** Measured: `i(@l1[i])` and `i(l1)` are two columns with byte-identical samples; one sky130 resistor appears as `i(@r.xr1.x0.rend1[i])`, `i(@r.xr1.x0.rend2[i])` **and** `i(@b.xr1.x0.brbody[i])`, all reading `-3.5280149e-07`; and ngspice's `save all` phantom puts `i(Vs)` and `i(all)` side by side with the same values. An accessor resolves whichever spelling it is given; it does **not** unify them, and a test that asserts "one signal, one column" is asserting something false about ngspice. |

---

## 11. Verification invariants

Headless suites under `tests/headless/`, named `test_typed_accessor_*.tcl`, run
through `tests/headless/run_suites.sh <suite>` (bare name, `name.tcl` or a path;
it arms a display, sources the gate, and runs
`timeout $TIMEOUT $XSCHEM --pipe -q --nolog --script <f>`). Sabotage is required
for each — green-but-hollow discipline.

**The fixture.** A two-`Plotname:` file is *readable* today and one test drives
it: `tests/headless/test_raw_case_mode.tcl` writes `$tmp/h_twoplot.raw` with an
`Operating Point` and a `Transient Analysis` block (`:1098`) and reads each in
turn (CS57c `:1126`, CS57e `:1132`) — but with an `xschem raw clear` **between**
them, so it never holds two analyses of one file resident at once. Nothing in the
repo does, and **no committed `.raw` has more than one `Plotname:` section**
(only two `.raw` are tracked at all). So the fixture must be built: one ngspice
deck whose `.control` block ends `set filetype=ascii` /
`write multi.raw dc1.all tran1.all ac1.all`, giving one ASCII
raw with a DC transfer characteristic (5 points), a Transient Analysis (121) and
a complex AC Analysis (61, 4x nvars). Add two more plots for T-D: a genuine
single-point `Operating Point`, and a multi-point `dc` — F5's promotion means an
`op` block with more than one point is stored as `dc`, so the `op` leg must be
written against a truly one-point plot. ngspice is needed at generation time
only; commit the `.raw`, not the deck run.

| id | invariant | the sabotage that reddens it |
|---|---|---|
| **T-A** | **NOTHING-CHANGES.** Every existing suite that touches raw reading, `node=`, graphs or the RPN evaluator is green and unchanged with the feature built in and no accessor anywhere. Non-negotiable, runs every item. The surface is **54 suites**, counted: 4 `test_raw*` + 1 `test_node_token_split.tcl` + 1 `test_del_negative_arg.tcl` + 18 `test_wave_*` that are not `test_wave_sigbrowser*` + 14 `test_wave_sigbrowser*` + 14 of the 24 `test_ase*` (the ones carrying signal expressions — that 14 is a judgement, not a glob) + 2 `test_calc*` = 54. **Publish the enumeration alongside the count when the batch starts**, because no single glob reproduces it and the ASE-L subset has to be listed by name | any resolver rung that fires on a non-accessor token |
| **T-B** | grammar: each of the eight accessors x {plain net, hierarchical path, `@dev[param]` for the current four} resolves to the **same column index** the equivalent untyped name resolves to in that slot. **Include a bare-stored name** (a VCD column, or `time`) — that leg is what R202's bare-argument rule exists for | emit `v(arg)` for a voltage accessor: the bare-stored leg goes red, everything else stays green |
| **T-C** | the analysis really is selected: on the fixture, `VT(out)`, `VS(out)` and `VF(out)` return three **different** sample sets, each equal to `xschem raw switch <file> <type>` followed by `xschem raw values v(out)` (note: `raw value` without a point index is a Tcl error, `Wrong command`) | make the resolver ignore the type and use the current slot |
| **T-D** | `VDC` two-try (R103): resolves against a one-point `op` slot; resolves against a one-point `dc` slot; **refuses** a multi-point `dc` slot with the message naming `VS` | drop the `allpoints == 1` guard |
| **T-E** | wrappers (R111), **both columns**: `phase(VF(out))` -> the index of `ph(out)`; `phase(IF(vmeas))` -> the index of `ph(i(vmeas))`. The shapes are asymmetric and one rule passes only half | implement the voltage rule for both |
| **T-F** | `VF(out)` alone equals `mag(VF(out))` equals the stored `v(out)` in the AC slot, and `real`/`imag` satisfy `mag == sqrt(re^2 + im^2)` at a point with real phase shift (where the phase is milli-degrees the identity is uninformative — §0(b)) | make `VF` mean the real part |
| **T-G** | R114: `phase(VF(out))` is the **wrapped** phase (+-180) and `phase(VF(out)) cph()` is the unwrapped one, asserted on a response that actually wraps | a document-only change with no test |
| **T-H** | refusals R801–R806, one leg per message, each asserting the **token name appears in the message**. Includes R116's four wrapper refusals and R103's sweep refusal | replace any message with a bare "expression error" |
| **T-I** | **cursor hygiene** (R207, R304): after `xschem raw index VT(out)`, after a graph redraw containing an accessor, and after a Calculator evaluate, **both** `extra_idx` **and** `extra_prev_idx` are what they were before, proven by a `switch_back` landing where it did before | restore `extra_idx` only — the measured defect this rule comes from |
| **T-J** | one-analysis-per-entry (R204): `VT(out) VS(out) -` refuses and names both | let the last accessor win |
| **T-K** | R205/R206 precedence: an accessor beats a `%…<sim_type>` suffix **and reports**; an accessor beats a rect `sim_type=` **silently**; a rect `sim_type=` still governs an untyped entry | flip either precedence |
| **T-L** | R106: the keyword resolves in every casing on a `fold`, a `preserve` **and** a `distinguish` database. **The `distinguish` leg is the one that matters** — L2 | fold the keyword with the name |
| **T-M** | **the Tcl mirror agrees with the engine** for every spelling in T-B and T-H: `wviewer::validate_rpn` accepts exactly what `xschem raw index` resolves and refuses exactly what it does not. The agreement-by-comparison idiom of `test_wave_casemode.tcl`'s G leg | teach the C and forget the Tcl — the L4 silent-zero path |
| **T-N** | **emit sweep, grep-based**: no **Class P** site (§6.1) produces a string matching `(^\|[^A-Za-z0-9_])[vi]\(`. Runs every item. It must **exempt every Class D and Class T site** — `sod_expr`'s deck arm above all — or it fails on correct code and, worse, invites someone to "fix" E1d. Encode the exemption list in the test, not in a reviewer's head | add a `v(` back to a Class-P emitter |
| **T-O** | migration identity (R709.2/.3): for each rewritten rect, entry count, alias halves and `%` suffixes byte-identical; and with the file's raw loaded, every rewritten token resolves to the **same column index** as before | rewrite one trace to the wrong accessor |
| **T-P** | netlist identity (R709.1): the five `tests/headless/cases.txt` schematics netlist to a `normalize()`d output diffing empty against `tests/headless/gold/` after the migration | — (a regression guard, not a feature test) |
| **T-Q** | 0418 fence (L4): `xschem raw add <n> <bad accessor>` does **not** report success | — |
| **T-R** | R122/R604: a token that merely *starts* with an accessor name but is not one (`VTX(out)`, `VT`, `VTx`) is **not** claimed by the resolver and resolves exactly as it does today | anchor the parse on a prefix instead of on the full identifier |
| **T-S** | **the bus path** (R307, R104): `DBUS;VT(d[3]),VT(d[2]),VT(d[1]),VT(d[0])` draws the same bus as the untyped entry, proving the textual rewrite reached `get_bus_idx_array`'s own re-split (`src/draw.c:9120` -> `:2903-2907`); and `VT(d[3:0])` is refused by R801 | resolve per token inside `get_raw_index` instead of rewriting the entry — the bus path then silently draws nothing |
| **T-T** | R203's file ladder at **all eight** walkers, including the three that lack the current-file fallback today (`:3608`, `:3823`, `:8282`): an accessor on a rect with no `rawfile=` must size the X axis, resolve the cursor database and answer a marker readout, not only draw | update the five that already have the fallback and stop |

**Pixel deliverables are look debts** (`tests/headless/owed.sh add look
typed-accessor-<what>`, and they clear **only** when the user says so): the
legend text of a migrated schematic (L10), the Ctrl-4 CIW error line (R505), and
the message formatting of §9. **A green suite never discharges one.**

---

## 12. Design decisions that can change

Each names what must be redone if reversed. Record any change in the batch
ledger's rulings table, then amend this section.

| # | decision | default | if reversed, redo |
|---|---|---|---|
| **D1** | Where the resolver lives | a new function in `save.c`, pure w.r.t. the registry, called by three doors (§4.2) | §4 entirely; a `draw.c`-local resolver means doors D-b and D-c grow copies — the issue-0305 failure |
| **D2** | What the accessor compiles to | `node_token_split()`'s `sim_type` out-parameter plus the R211 gate change (§3.2). Includes R207's open sub-decision: de-`static` the two unwind helpers, or open-code the pair in D-b/D-c | §3.2, §4.2 D-a, and every walker; a new `node=` syntax would also move §7 and §8 |
| **D3** | One analysis per `node=` entry (R204) | **refuse** a mixed entry | R204, T-J — and if reversed, F1 forces a resampling model that does not exist |
| **D4** | Does an accessor imply `autoload`? | **no** — a missing analysis is a refusal (R802), not a silent disk read. The message names the lever | R802's message and T-H; and if reversed, every graph redraw becomes a potential file read |
| **D5** | Is the accessor keyword case-sensitive? | **case-INSENSITIVE, matched in the parser before the ladder** — R106. RULED, §17 Q3 | R106, R121's parse, T-L |
| **D6** | Is there a prefix `db20(...)` wrapper? | **no** — the postfix `db20()` operator exists and there is no stored vector to rewrite onto (R112) | R110, R112, the `db20()` row of `calculator.md` §3.2 and its shipped catalogue form in `src/calculator.tcl` |
| **D7** | `phase()` maps to the **wrapped** `ph(...)` | **yes**, because that is the stored vector; the unwrapped form is `phase(...) cph()` (R114) | R111, R114, T-G, and every help string |
| **D8** | Double-wrap (`IT(i(vs))`) | **refuse** with a corrective message (R402) | R402, R805, T-H |
| **D9** | Precedence vs a `%…<sim_type>` suffix | accessor wins, **reported** (R205) | R205, T-K |
| **D10** | Precedence vs a rect `sim_type=` | accessor wins, **silently** (R206). RULED, §17 Q2 | R206, T-K |
| **D11** | Buses | `VT(d[3])` yes, `VT(d[3:0])` malformed (R104). RULED, §17 Q4 | R104, R801, T-S |
| **D12** | Migration mechanism | a **text** rewrite that parses the way the C parses (R702, R703) | §8.2 |
| **D13** | Rects with no `sim_type=` | **do not guess** — read the deck, record per file, leave untyped where ambiguous (R708) | §8.3, T-O |
| **D14** | `MP`/`OP`/`VN`/`VAR`/`OPT` accessors | **not in v1** (R404) | one row in R102's table, one kind-column in R111's rewrite table, and one branch in `get_fqdevice()`'s `modelparam` prefix select (`src/token.c:4524`) |
| **D15** | Ctrl-4 | tran-if-present when several, plot-it when exactly one, **never a chooser** (R505). RULED, §17 Q5 | `src/cadence_style_rc:264`, `ase::plot_sim_type`, `dp_finish` |
| **D16** | Wrappers on a non-AC accessor | **refuse all four** (R116). RULED, §17 Q1 | R116, R806, T-H |

---

## 13. Where we go beyond Cadence

- **No quotes and no slashes** (A2). `VT(x1.x2.net5)` uses xschem's own path
  syntax — the one the raw actually stores — so the **path inside the accessor**
  is byte-identical to the path `xschem raw list` prints. Cadence's
  `VT("/x1/x2/net5")` needs a mental translation to the Spectre name (`I0.net5`)
  that xschem users never have to do.
- **`v(out)` keeps working, forever** (A4, R601). Cadence's untyped `v()` exists
  too, but as an OCEAN function with a `?result` keyword, not as the GUI's
  spelling; here the untyped form stays first-class for hand-editing and for
  every existing schematic.
- **The accessor is portable** (R203). It names no file, so a schematic carrying
  `VT(out)` plots against any run of that design. A `%<abs-path>` suffix does not.
- **`phase()` says which phase it is** (R114). Cadence ships `Phase` and `WPhase`
  as separate modifiers and documents only one of them.

## 14. Deliberate deviations from Cadence

| Cadence | here | why |
|---|---|---|
| `VT("/out")` — quoted, slash-rooted | `VT(out)` — unquoted, dot-separated | A2. Nothing else in xschem quotes a node name, and the RPN lexer splits on whitespace |
| `dB20(VF(...))` as a prefix wrapper | `VF(...) db20()` postfix | R112. The operator ships; a second spelling for it is not compatibility |
| `Phase` and `WPhase` as separate modifiers | `phase(...)` = wrapped; `phase(...) cph()` = unwrapped | R114. `ph(...)` is what the reader stores; `cph()` is what xschem already ships to unwrap it |
| `dB10` modifier | absent | no `db10()` operator exists; out of scope |
| `I(V2:p)` — terminal-qualified currents | ngspice's three measured shapes (§5) | the accessor accepts what the simulator writes, not what another tool writes |
| `MP`/`OP`/`OPT`/`VN`/`VAR` accessors | absent in v1 | D14 |
| Trace modifier as a per-trace **property** with a `.cdsenv` default | a spelling inside the expression | the per-trace tokens a rect does have (`color=`, `sweep=`) are **positional lists** indexed against `node=`, and they already desync silently (`waveform_subsystem_reference.md` §2.5). A modifier list would be a fourth list to keep aligned |

## 15. Non-goals for v1

- `MP` / `OP` / `OPT` / `VN` / `VAR` and the seven RF accessors (`sp`, `zp`,
  `vswr`, `yp`, `hp`, `gd`, `zm`). The seven RF ids plus `mp` already ship
  **disabled with a stated reason** (`calc::sel_disabled`,
  `src/calculator.tcl:999-1010`): seven carry *"no S-parameter analysis in
  ngspice"* and `mp` carries *"needs a model-database reader"*. `OP`, `OPT`, `VN`
  and `VAR` ship as **enabled-but-inert** radiobuttons, so only the eight are
  visibly absent — the other four look available and do nothing (§6.1 E12).
- Cross-analysis arithmetic in one expression (R204, D3).
- A per-trace modifier property.
- Any change to the deck side (R605, §6.2 Class D).
- Changing `render_deck`'s single `write` so a run produces more than one
  analysis (R503) — **A8's real prerequisite**, and out of scope here.
- Changing `ase::attach_dbs` to load more than one analog analysis (R504).
- Rewriting the **30** `ngspice_get_value` / `ngspice_get_expr` instance `node=`
  values, in 12 files (§8.1) — a different evaluator and a different surface.
- `sim_type=distrib` and `sim_type=foo` rects (R708).

---

## 16. The rulings already taken — 2026-08-18, user

Reproduced from `doc/claude/specs/results_selection.md` §19 so this spec stands
alone. **Not re-litigated.** Where measurement has since qualified one, the note
says so and points at the section.

| # | ruling, as the user wrote it | measured qualification |
|---|---|---|
| A1 | Its own spec and batch, **after** Results Selection. Calculator item 8 ships speaking `v(out)` | confirmed cheap: the Calculator has **no** emit path yet — all 22 selectors are inert (§6.1 E12) |
| A2 | **Spelling: xschem paths, no quotes** — `VT(out)`, `VT(x1.x2.net5)`. Cadence's quoted `VT("/x1/x2/net5")` is *not* copied: nothing else in xschem quotes a node name, and the engine splits on whitespace | R101; the constraint is `src/save.c:3545` |
| A3 | **Full set in v1:** voltage and current, all four analyses — `VT`/`VS`/`VF`/`VDC` and `IT`/`IS`/`IF`/`IDC` | R102. `VDC` needs a second try because a single-point operating point can reach the registry as `dc`; ⚠ **not** because of F5's multi-point promotion, which R103 shows is unreachable that way |
| A4 | **`v(out)` keeps working**, meaning "the current analysis", so saved schematics keep rendering. But **nothing the tool emits uses it any more** — every generated expression is typed | R601–R606. ⚠ Qualified twice: the **deck** side must keep emitting `v(` (R605, §6.2 Class D — including the ASE-L Save-Options arm, E1d), and the dominant existing canvas spelling is a **bare name**, not `v(` (F6) |
| A5 | **`VF(out)` alone is the magnitude** | measured true — §0(b) |
| A6 | **Add the Cadence wrapper names** `mag` / `phase` / `real` / `imag`, compiling to vectors that already exist; the existing `ph()` / `re()` / `im()` spellings keep working | R110–R116. ⚠ Two corrections: the derived names are `ph(out)`, not `ph(v(out))` (§0(b)); and **there is no `ph()` operator** — `ph(...)` exists only as a stored name (R113) |
| A7 | **Rewrite the 24 tracked schematics** that carry `v(...)` inside a `node=`. Each graph box already records its own `sim_type=`, so the correct accessor is known without guessing | ⚠ Qualified hard: it is **28** files by the plain reading, **16** on graph rects, and only **7 of those 16 carry `sim_type=`** — §8.1, R707. And the census misses currents entirely: **264 graph rects in 156 files** carry an `i(` in a `node=` |
| A8 | **Direct Plot** detects which analyses the run produced and offers the choice; with only one it plots straight away — but always emits the *typed* accessor, never `v()`. ASE-L knows the analysis | R503. ⚠ The enumeration is cheap, but a run currently **writes only one analysis into the raw** (`render_deck`'s single `write`), so "the analyses the run produced" is not the enabled list. That change is out of scope (§15) |
| A9 | **Ctrl-4 is not Direct Plot.** It is the transient bindkey. If it is cheap, let Ctrl-4 also work when a run contains exactly one analysis, whatever that analysis is; Cadence restricts it to transient, and xschem need not | R505, D15, §17 Q5 — where the user ruled the multi-analysis half. ⚠ The ruling's premise is stale in one respect: Ctrl-4 **is** bound to `ase::direct_plot_for_current` today (`src/cadence_style_rc:264`), i.e. to the pick mode, which is analysis-blind rather than transient-specific |

---

## 17. The five open decisions — RULED 2026-08-19 by the user

Each was put to the user with the measurement and a worked example. The answers
are folded into the rules above; the workings are kept here because the reasoning
is what a future reader will want.

### Q1 — a wrapper on the wrong analysis. **RULED: refuse all four.** (R116, D16)

`phase(VT(out))` asks for the phase of a transient signal. Measured, a `tran` raw
of the §0 deck holds exactly `time v(in) v(mid) v(out) i(vin) i(vmeas)` — there
is no `ph(out)` to rewrite onto and no imaginary part to take an `atan2` of.
`mag` and `real` *could* have been waved through as `abs()` and identity; they
are not, because a wrapper that means three different things depending on the
analysis is worse than one that means one thing and says so. The magnitude of a
real signal is `VT(out) abs()`, which already works.

### Q2 — rect `sim_type=` versus the expression's accessor. **RULED: the accessor wins, silently.** (R206, D10)

The decidable facts: `sim_type=` is read at **14** C sites (11 in `src/draw.c`,
3 in `src/callback.c`) plus 5 in Tcl, and every C site uses it as the type
argument to `extra_rawfile()` or as a pan-lock grouping token — never as an axis
label, a unit or a log scale. A per-entry statement overriding a rect-wide
setting is the shape the `%` suffix already has. Migration makes the two agree by
construction wherever a `sim_type=` exists.

⚠ **Two consequences the ruling does not remove.**

1. **`sim_type=` governs more than R206's framing suggests.**
   `node_dflt_sim_type()` is consumed in **both** branches of
   `node_token_split()` (`src/draw.c:3349` and `:3355`), and only **227 of the
   1656** trace entries (in 86 of the 666 rects) carry a `%` at all — so today
   the rect's token is the effective analysis of nearly seven entries in eight,
   not just of `%`-suffixed ones missing a type.
2. **Pan-lock grouping still keys on the property token, not on the accessor.**
   `graph_shares_x()` returns membership as
   `rk->sel || (same_sim_type && !(rk->flags & 2))` (`src/draw.c:3462`; the
   predicate is written out verbatim in the comment at `:3431`, and `k == master`
   is an early return at `:3453`). `same_sim_type` compares the two rects'
   `sim_type=` **strings** (`:3456-3458`) and is computed only when the *master*
   is not `graph_unlocked`. So two rects whose traces are typed differently but whose
   tokens match still share an X axis — and a **selected** rect joins the group
   regardless of `sim_type`. Making the accessor govern grouping is a second,
   larger change and should be its own item.
   **Four** of the five Tcl read sites are neither an `extra_rawfile()` argument
   nor a pan-lock token (`src/xschem.tcl:7147`, `:7148`, `:7154`, `:7155` — two
   per Tcl-version branch): they seed the graph dialog's `sim_type` combobox,
   which is where a grouping change would surface first.

### Q3 — keyword case. **RULED: case-INSENSITIVE, parsed before the ladder.** (R106, D5)

The measurement that decided it, on a raw whose header literally names a vector
`VT(MidNode)`:

```
a hand-written raw whose Variables: section names a vector `VT(MidNode)`

read as tran (case flag 0):
  VT(MidNode) -> 2   vt(midnode) -> 2   VT(MIDNODE) -> 2
  Vt(MidNode) -> 2   vt(MidNode) -> 2   VT(midnode) -> 2

the SAME file read with `-case distinguish` (case flag 1):
  VT(MidNode) -> 2
  vt(midnode) -> -1  VT(MIDNODE) -> -1  Vt(MidNode) -> -1
  vt(MidNode) -> -1  <- ONLY THE KEYWORD differs in case, and it misses
  VT(midnode) -> -1
```

`raw_fold_key()` lowercases the **whole token**, prefix included
(`src/save.c:3233-3239`), so an accessor implemented as a stored-name shape
inherits the database's case discipline — a property of the *simulator's* naming
that has nothing to do with an xschem keyword. Parsing the keyword before the
ladder keeps the two rules apart, and is the only option under which T-L's
`distinguish` leg can pass. (Note the recipe above needs a raw whose **header**
carries that name: `xschem raw read <same file> -case distinguish` routes through
`raw_case_reread()` precisely so a `-case` change cannot be a flag flip
(`src/scheduler.c:10390-10402`), so an in-memory `raw rename` does not survive
it.)

### Q4 — buses. **RULED: one accessor per bit; `VT(d[3:0])` is malformed.** (R104, D11)

Hierarchy was already settled: `VT(x1.x2.net5)` works and the path is the raw's
own — `sod_qualify` measures it from the session's design level, and issues
0161/0168 closed that. For buses, a `node=` entry is a comma list at the *entry*
level: `get_bus_idx_array()` (`src/draw.c:2890`) splits it on `";,"`
(`:2903-2904`) and resolves each bit through `get_raw_index()` (`:2907`). So

```
node="DBUS;VT(d[3]),VT(d[2]),VT(d[1]),VT(d[0])"   OK, zero new machinery
node="DBUS;VT(d[3:0])"                            malformed (R801)
```

A range inside the accessor would make it the one token in this grammar whose
resolution is N columns.

⚠ **And `ase::bus_expr_bits` is not simply "an emit change".** Its first guard is
`if {![regexp {^v\(([^()]+)\)$} $ex -> inner]} { return {} }` (`src/ase.tcl:326`),
so an accessor input is rejected before the emit at `:334` is ever reached — it
must learn to **parse** the accessor (§6.1 E3). And its output feeds the
**deck**: `ase::state_load` rewrites the outputs list through
`ase::expand_bus_outputs` (`src/ase.tcl:303`), and `render_deck` emits
`.save`/`print` straight out of that list (`:4602`, `:4651`). So it must keep
emitting `v($b)` — never `VT($b)`. That is E1d again, from the other side.

### Q5 — Ctrl-4. **RULED**, and the ruling is A9's first sentence taken seriously. (R505, D15)

| the run's plottable analyses | Ctrl-4 |
|---|---|
| exactly one, of any type | **plots it**, emitting that analysis's accessor |
| more than one, including `tran` | **plots the transient**, emitting `VT`/`IT` |
| more than one, no `tran` | **no plot**; an error line in the CIW naming what it found |
| `op` only | no plot — `dp_finish` already refuses this (`src/ase_window.tcl:2304-2308`) |

**No chooser** — A9's first two sentences forbid it. The single-analysis row is
not a new concession: it is what
Ctrl-4 does today for an AC-only or DC-only session, so ruling otherwise would be
a behaviour regression. What changes is the multi-analysis case, where
`ase::plot_sim_type` (`src/ase.tcl:1934`) currently walks `{op dc ac tran}` and
returns the **last** enabled match — a silent priority that happens to agree with
the ruling when `tran` is present and disagrees with it when it is not.

---

## 18. What is NOT here

- **`render_deck` still writes ONE analysis.** `src/ase.tcl:4668`, and its own
  comment at `:4654-4657` says so. A8's chooser is not reachable until that
  changes. R503.
- **`ase::attach_dbs` still loads exactly one ANALOG analysis**
  (`src/ase.tcl:2866`, the drop loop at `:2915-2919`) — plus every VCD in the
  run (`:2921-2925`). R504.
- **The `%<rawfile>` half of the per-trace suffix is untouched.** The accessor
  overrides only the *type*. Which file a session is bound to is
  `results_selection.md`'s subject, and its §17.1 already ruled it.
- **Issue 0418 is fenced, not necessarily fixed.** L4 and T-Q require that a bad
  accessor cannot report success; whether the fix is inside `raw_add_vector()` or
  a pre-gate is the batch's call.
- **The Calculator's own build** (`doc/claude/specs/calculator.md` +
  `doc/claude/calculator_batch/PLAN.md`, phases 2–10). Item 8 is gated on
  `results_selection.md`, not on this; A1 ruled it ships speaking `v(out)`, and
  §6.1 E12 measured why that costs nothing.
- **The netlist and simulator-profile machinery.** This spec starts after a
  `.raw` exists.
- **Three defects found while writing this spec**, filed rather than fixed — §19.

## 19. Defects found while writing this spec

Filed as issues **0510**, **0511** and **0512**. None is *caused* by this
feature. **0512 blocks it** — its own severity line says so, and §10 L5 and R306
depend on the fix. 0510 and 0511 do not block it; 0510 is in its blast radius
through E7p.

| # | issue | defect | evidence |
|---|---|---|---|
| 1 | **0510** | **`xschem get_fqdevice <inst>` in its 2-argument form emits an EMPTY parameter bracket.** `src/scheduler.c:5469` passes the literal `""` (not NULL) for `param`, so `token.c`'s `param ? param : "id"` selects the empty string. Measured: `xschem get_fqdevice M1` → `i(@m1[])`, `Q1` → `i(@q1[])`, `D1` → `i(@d1[])`, where the 3-argument form gives `i(@m1[id])`. §6.1 E7p inherits it | `src/scheduler.c:5469`; the no-path composition sites `src/token.c:4559`, `:4561` (and the hierarchical twins at `:4545-4549`) |
| 2 | **0511** | **`xschem raw switch` / `switch_back` read the point count from the PRE-switch database and the analysis type from the POST-switch one, with no NULL guard.** The dispatcher captures `Raw *raw = xctx->raw` once at entry (`src/scheduler.c:10338`); the `update_op()` gate then tests `raw->allpoints == 1` against `xctx->raw->sim_type` | `src/scheduler.c:10338`, `:10415-10417`, `:10428-10430` |
| 3 | **0512** | **`wviewer::sig_bare` and `wviewer::sig_type` will disagree the moment an accessor exists.** `sig_bare` (`src/wave_viewer.tcl:2155`) matches the generic `^[A-Za-z_][A-Za-z_0-9]*\((.*)\)$` and already bares `VT(out)` → `out`; `sig_type` (`:1951`) keys on the literal `v(`/`i(` and returns `other`. Both feed the Signal Browser's classification. §10 L5 | `src/wave_viewer.tcl:2155`, `:1951`; pinned by `test_wave_sigsearch.tcl` ST01/ST03, SB01/SB04/SB05/SB08/SB09 |

Plus the documentation corrections of **§10 L11** and the stale source citations
of **§10 L12**, which are edits rather than issues.
