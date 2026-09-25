# Receipt A — 26 candidates, 2 driven defects, and the issue's premise was wrong

Four crews from `73ebbfa0`: `measure:fixture+drive`, `triage:netlisters`, `triage:rest`,
`verify:refute-claims`. The verify crew refuted **no verdict** but refuted several pieces of the
*evidence* behind them, and reframed the one site that matters. Both are recorded.

## The headline

| count | class |
|---|---|
| **2** | **driven to a segfault**, gdb backtrace in hand |
| 2 | reached and survived, measured (`type` was `""`, not NULL) |
| **16** | **mis-classified by the original sweep** — a dominating guard, or commented-out code |
| 5 | unreachable by construction (caller contract, or an `else if` arm downstream of the fault) |
| 1 | must stay unguarded — a guard there would encode a falsehood |

**The netlister cluster — the 19 sites the issue and this batch's own PLAN.md called the
priority — contains ZERO driven defects.** 14 already guard, 2 are comments, 3 are caller-guarded.
Of the two that do need patching, **one was invisible to the sweep entirely.** The driver's
recommendation to the user rested on "19 of 27 are in the netlisters"; that count was right and
its implication was wrong.

## The issue's premise is wrong, and this corrects it

"A symbol with no `type=` property" is **not** sufficient to produce a NULL. Read and then driven:

* `load_sym_def()` (`save.c`, cases `'K'`/`'G'`) does
  `load_ascii_string(&symbol[symbols].prop_ptr, …); if(!symbol[symbols].prop_ptr) break;` and only
  *then* calls `set_sym_flags()`.
* `load_ascii_string` ends in `my_strdup`, whose own comment reads *"empty source string →
  dest=NULL"*. So `K {}` yields `prop_ptr == NULL` and the `break` skips `set_sym_flags` entirely.
* `set_sym_flags()` does `my_strdup2(…, &sym->type, get_tok_value(sym->prop_ptr, "type", 0))`.
  `get_tok_value` **never** returns NULL — it returns `""` for a missing token — and `my_strdup2`
  duplicates the empty string. So whenever `set_sym_flags` runs, `type` is non-NULL.

Therefore `prop_ptr == NULL` ⟺ `set_sym_flags` was skipped ⟺ `type == NULL`. **The reachable NULL
state is a symbol whose global-attribute record is empty or absent** — `K {}`, or a file with
neither `G` nor `K`. A symbol carrying any other property but no `type=` gets `""` and is
harmless. Proven in gdb, printing the raw pointer with `%p`:

```
sym[0] <the typeless fixture>   type_ptr=(nil)          type=<<NULL>>  prop_ptr=(nil)
sym[0] <the control fixture>    type_ptr=0x5555566deed0 type=[]        prop_ptr=0x5555566905b0
```

⚠ **Correction, found by the implementation crew.** The original transcript labelled the NULL row
`notype.sym`, but the `notype.sym` left in the reference fixture directory carries a
`K {format=… template=…}` record — so its `prop_ptr` is **non-NULL** and it is in fact the
*control*. Measured on the pristine binary: that file gives `PROP=<format="@name @pinlist …">` and
`sch_pinlist` **survives**; the file with no `G`/`K` record at all gives `PROP=<>` and
`sch_pinlist` gives `FATAL: signal 11`, exit 1. **The conclusion above is unchanged and the file
names in that one transcript were stale.** The committed suite uses unambiguous names —
`noprop.sym` for the NULL case and `someprop.sym` for the control — precisely so this cannot
recur.

## The invariant that protects almost everything

`prepare_netlist_structs()` calls `reset_caches()` at `netlist.c:1828`, and `reset_caches()` runs
`set_sym_flags()` on **every** symbol unconditionally — `prop_ptr == NULL` included. **It converts
`type == NULL` into `type == ""` before any netlister, hilighter or net-resolver site is
reached.** Caught on a conditional breakpoint:

```
>>> set_sym_flags on prop_ptr==NULL symbol name=notype.sym old_type_ptr=(nil)
#1 reset_caches () at actions.c:3036
#2 prepare_netlist_structs (for_netl=1) at netlist.c:1828
#3 spice_netlist (…)  #4 global_spice_netlist (…)  #5 xschem_cmds_n (…)
```

Instrumented counts, with a symbol whose `prop_ptr` is NULL at load: 5 netlisters × 3 schematics
+ `list_nets` = **260 visits, 216 on the typeless symbol, type always `""`, ZERO NULL**. A broader
driver covering delete+undo, redo, `copy_objects`, `descend`/`go_back`, `check_unique_names` and
reloads — the `in_memory_undo` / `copy_symbol` paths — gives **1576 visits, 1312 typeless, ZERO
NULL**. The 5 verbs that survived a focused display sweep in the dangerous state are exactly the
ones that run `prepare_netlist_structs()` first.

⚠ **That safety rests on ONE TOKEN in another file.** The verify crew flipped `actions.c:1017`
from `my_strdup2` to `my_strdup` — the spelling used almost everywhere else in this tree, and one
which NULLs an empty source — and got two sequential gdb-confirmed segfaults: `netlist.c:1024`
first, then `netlist.c:1354` once :1024 was guarded, then a clean run once both were. **So the
guards are defence-in-depth backed by a measurement, not by style, and the flip is a ready-made
deterministic sabotage for Stage C.**

## The two driven defects

**1. `scheduler.c:12142`, `xschem_cmds_s()`, the `sch_pinlist` branch. TRUE HEADLESS, two lines
of Tcl, no extra state.**

```
#0 __strcmp_avx2 ()  #1 xschem_cmds_s (…) at scheduler.c:12142  #2 xschem (…) at scheduler.c:15297
```

The statement is `if( !strcmp((xctx->inst[i].ptr + xctx->sym)->type, "ipin") ) dir="in";` inside
`for(i = 0; i < xctx->instances; ++i)`, with no `type` test anywhere in the branch. `:12143` and
`:12144` are `else if` arms on the same pointer — they can never fault first, so **one guard must
cover all three or fixing :12142 re-opens them immediately.**

**2. `draw.c:1078`, `draw_temp_symbol()`. DISPLAY only, after one ordinary extra step — and the
bug is that THE GUARD NAMES THE WRONG FIELD.**

```c
1077:  (xctx->hide_symbols==1 && (xctx->inst[n].ptr+ xctx->sym)->prop_ptr &&
1078:  !strcmp( (xctx->inst[n].ptr+ xctx->sym)->type, "subcircuit") ) ||
```

`prop_ptr`, not `type`. `draw_symbol()` 336 lines earlier at `draw.c:742` tests `type` correctly;
the two expressions are otherwise identical. On a freshly loaded typeless symbol `prop_ptr` is
*also* NULL, so the `&&` short-circuits and the wrong guard accidentally holds. `xschem setprop
symbol notype.sym device widget` sets `prop_ptr` **without** calling `set_sym_flags`, breaking the
coupling — and the next `select_all` with `hide_symbols == 1` dies. Reached by a second door too:
`show_unconnected_pins()` → same site.

Counts: **320 verbs driven truly headless → 1 crash**; 320 with a display in the plain state → 1;
320 with a display after `setprop` → **3** (`sch_pinlist`, `select_all`, `show_unconnected_pins`).

## Two more to patch as defence-in-depth, one of which the sweep could not see

**`netlist.c:1024`** — `if(j == 0 && IS_LABEL_OR_PIN(xctx->sym[xctx->inst[i].ptr].type))`. A
`strcmp` regex cannot see this: `IS_LABEL_OR_PIN` expands to unguarded `strcmp` inside
`xschem.h`. It **dominates the listed `netlist.c:1030`**, so the listed site could never have
faulted first, and under the one-token flip it is the **first** crash site. It is also the **only
unguarded use of that macro in all of `src/*.c`** — the other seven all write
`type && IS_LABEL_OR_PIN(type)`. Not "fragile like its siblings": the single outlier in a tree
otherwise uniformly careful about this exact macro.

**`netlist.c:1354`** — `int bus_tap = !strcmp(xctx->sym[inst[n].ptr].type, "bus_tap");`, a
declaration initialiser that runs before every early return in `instcheck()`. Second crash site
under the flip.

## `netlist.c:1030` must STAY unguarded, and that is a decision not an omission

It sits inside the `if` opened at `:1024`, so reaching it requires `type` to have already compared
equal to one of four known strings. And semantically the variable is `port`: a blanket
`type ? strcmp(type,"label") : 1` would read *"typeless ⇒ not a label ⇒ it IS a port"*, which is
false. **This is the site the issue warned existed** when it said a blanket `type ? type : ""`
"would answer all 28 at once and would be wrong wherever the absence means something other than
'not that type'". Guard `:1024` and `:1030` needs nothing.

## The sweep's method was the real defect, and the indictment is worse than the issue states

The issue conceded one false positive (`spice_netlist.c:96`). There are **sixteen**. At the
sweep's own commit `d9f45e8f`, **six** sites were guarded on the *immediately preceding line*
(spice 398/399, spectre 250/251, tedax 183/184, vhdl 43/45, 581/582, 590/591) — a two-line window
should have cleared six, not one. And `git diff --stat d9f45e8f HEAD` shows the files unchanged,
so this is a flaw in the original classification, not drift.

Macro blind spot, now closed: 8 `IS_LABEL_OR_PIN` uses → exactly **one** unguarded
(`netlist.c:1024`); 10 `IS_PIN` uses → **all guarded**. A decoy worth recording: `findnet.c:293`
looks like a second unguarded use and is a non-site twice over — inside `#if 0` **and** guarded by
`if(!type) continue;` two lines above.

⚠ **So the remaining non-netlister rows should be assumed to carry the same ~89% false-positive
rate** and re-derived with a whole-function window before anyone patches them.

## Out of scope, found while reading, neither a NULL-type issue, both unverified behaviourally

1. `vhdl_netlist.c:655` and `:661` read `xctx->sym[i]` inside the `j` loop opened at `:651`, while
   `:654`/`:658`/`:662` read `xctx->sym[j]`. The analogous loop at `:323`–`:328` uses `j`
   throughout, so `check_lib(1, abs_path)` appears to test the **outer** symbol's path against the
   **inner** symbol's type — suspected `i`/`j` mix-up.
2. `netlist.c:1353`–`:1354` dereference `xctx->sym[inst[n].ptr]` with no `ptr >= 0` test (the
   issue 0498 class).

## ⚠ A methodology failure, self-reported by the crew, and the driver's brief caused it

The Stage A crew's first round of "headless" runs used `./src/xschem --pipe -q --script …`
**without unsetting `DISPLAY`**. `$DISPLAY` on this machine is `172.20.160.1:0` — the user's real
Windows X server — and `--pipe` does **not** imply `--nogui`: a probe confirmed `tk=1` and
`display=172.20.160.1:0` inside such a run, and `draw_temp_symbol`, which sits behind
`if(!has_x) return;`, crashed in them. **Those runs mapped windows on the user's screen.**

The crew caught this itself, labelled every affected figure, and re-ran the headless arm properly.
The cause is the driver's brief: it required `HOME` to be redirected for ad-hoc runs and said
nothing about `DISPLAY`, even though `CLAUDE.md` is explicit that a bare `./src/xschem` inherits
the user's real screen. **Every future crew brief in this project must say `env -u DISPLAY` (or
`--nogui`) for a headless arm, not just "redirect HOME".**
