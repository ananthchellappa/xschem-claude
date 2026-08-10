# 0254 — descend_symbol on a missing-symbol placeholder does nothing and says nothing

Status: **OPEN** — the refusal and the total absence of output are measured headless (transcript
below). What is *not* measured is the live-GUI half: that a desktop-launched session sees nothing
at all is inferred from there being no `alert_` / `statusmsg` / `ciw_echo` call on the path and
from `dbg(0,…)` going to `stderr` (which a desktop launch discards), not from a run under X.
Area: `src/save.c` `descend_symbol()` missing-type guard (`:5587-5589`); the substitution that
creates the placeholder, `load_sym_def()` (`:4682-4683`) and `match_symbol()` (`src/token.c:201`);
the parallel silent refusal in `src/actions.c` `descend_schematic()` (`:3620-3624`); dispatch
`src/scheduler.c:3015-3036`; key `i` `src/callback.c:6587-6590`; context menu `src/callback.c:4518-4519`
Tests: none — nothing under `tests/headless/` instantiates an unresolvable symbol and descends.
Proposed `tests/headless/test_descend_missing_sym_0254.tcl`
Found: 2026-08-08, in the descend silent-refusal census
(`doc/claude/code_analysis/descend_silent_refusal_census.md`)
Related: **0232** (the same `missing.sym` substitution silently unnames nets and fires no ERC —
the netlist-side sibling of this UX-side silence);
[0232](0232-missing-symbol-substitution-silently-unnames-nets.md).
**0252** (non-subcircuit / no-type symbols are refused silently after the chooser offered the view
— the `descend_schematic` guard at `actions.c:3620` is the same guard that swallows *this*
placeholder, so 0252 and 0254 must be fixed with one message, not two).
**0251** (a refused descend has no return channel), **0250** (a failed descend load with `alert=0`
strands the window on a blank child page — measured incidentally below),
**0261** (descend reports success on a blank page).
[0125](0125-instance-branch-refusal-set-modify-spurious-undo.md) is **FIXED** and is relevant only
as the record that the substitution itself is treated as a real mutation (`set_modify(1)` + an undo
slot) — it says nothing about descending into the result.
[0203](0203-stale-sel_array-descends-a-deselected-instance.md),
[0200](0200-descend-has-no-verb-noun-pick.md),
[0248](0248-gate-and-prompt-statusbar-messages-are-wiped-by-the-coordinate-readout.md)
(any statusbar line a fix here adds must survive the coordinate readout).

## The defect

```c
src/save.c:5586-5589
    my_snprintf(name, S(name), "%s", translate(n, xctx->inst[n].name));
    /* dont allow descend in the default missing symbol */
    if((xctx->inst[n].ptr+ xctx->sym)->type &&
       !strcmp( (xctx->inst[n].ptr+ xctx->sym)->type,"missing")) return 0;
```

The guard is **correct**. There is genuinely nothing to descend into: the symbol the user is
looking at was never loaded, and what is on screen is `systemlib/missing.sym`. The defect is that
the guard is mute at exactly the moment the user most needs it to speak.

The chain that produces the placeholder:

```c
src/token.c:201
int match_symbol(const char *name)  /* never returns -1, if symbol not found load systemlib/missing.sym */

src/save.c:4681-4683
  if(lcc[level].fd==NULL) {
    /* issue warning only on top level symbol loading */
    if(recursion_counter == 1) dbg(0, "l_s_d(): Symbol not found: %s\n", transl_name);
    my_snprintf(sympath, S(sympath), "%s/%s", tclgetvar("XSCHEM_SHAREDIR"), "systemlib/missing.sym");
```

`src/systemlib/missing.sym` carries `G {type=missing …}` and draws a labelled box:

```
G {type=missing
format="*  @name -  @symname  IS MISSING !!!!"
template="name=x1"}
L 8 -110 -25 -110 25 {}
…
T {---MISSING SYMBOL---} -89.5 -21 0 0 0.3 0.3 {}
```

So a broken reference **renders**, and it renders as a box that announces it is broken. The user
clicks that box *precisely because* they want to see what it should have been — which symbol was
expected, from which library — presses `i` (Edit ▸ Push symbol, accelerator I,
`src/xschem.tcl:14726`; toolbar `EditPushSym`, `src/xschem.tcl:13167`), and nothing happens.
No dialog, no statusbar line, no CIW line, no cursor change, no stderr. The window does not move
and does not explain why. The user's next hypothesis is that the key is broken or that the
instance is not selected.

Four aggravating facts:

1. **The only trace is at LOAD time, not at descend time.** `l_s_d(): Symbol not found: X.sym`
   (`src/save.c:4682`) is emitted when the *parent* was opened, potentially minutes and hundreds
   of scrollback lines earlier. `dbg(0,…)` reaches `stderr`, so a terminal-launched user can
   scroll back and find it; a desktop-launched (menu/.desktop) GUI session has no terminal and
   never sees it.
2. **Nested misses print nothing at all, ever.** That `dbg(0,…)` is gated on
   `recursion_counter == 1` (`src/save.c:4682`; counter incremented at `:4641`, decremented at
   `:5373`). A symbol missing *inside* an LCC / hierarchical symbol load runs at depth ≥ 2 and
   produces no message on any channel at any time. The placeholder is then the sole evidence, and
   descending into it to learn more is the exact operation this guard refuses.
3. **The information the message would need is already in hand.** The refusal is two lines *after*
   `name` was filled with `translate(n, xctx->inst[n].name)` (`src/save.c:5586`), and
   `(inst[n].ptr+xctx->sym)->name` is the *requested* name too — `load_sym_def` stores
   `transl_name`, not the substituted path (`src/save.c:4715`,
   `my_strdup2(_ALLOC_ID_, &symbol[symbols].name,transl_name);`). Confirmed live: with the
   placeholder in place, `get_sch_from_sym()` logs `sym->name=no_such_cell_0254.sym`. Nothing has
   to be recovered or plumbed; the unresolved name is a local variable at the `return 0`.
4. **Every caller discards the 0.** `descend_symbol()` returns `int`, but the scheduler branch
   ends `Tcl_ResetResult(interp);` (`src/scheduler.c:3035`), so `xschem descend_symbol` evaluates
   to the empty string whether it worked or not. The Tcl chooser works around this by watching the
   hierarchy level instead:

   ```tcl
   src/xschem.tcl:5875-5880
     if {$vtype eq {symbol}} {
       # descend_symbol has no return value; detect success by the hierarchy level rising,
       # so a no-op symbol descend does not falsely report success and then mislabel /
       # clear the modified flag of the CURRENT (un-descended) schematic.
       xschem descend_symbol
       set ok [expr {[xschem get currsch] > $lvl}]
   ```

   That inference is sound but it only yields `0`; `hi_descend_finish` returns it and no caller
   turns it into a message (contrast every *other* refusal in that neighbourhood, which does
   `ciw_echo … error` — `src/xschem.tcl:5871`, `:5910`, `:5950`, `:6010`, `:6015`, `:6028`,
   `:6038`). See **0251**.

**The chooser actively offers the view it will then refuse.** `hi_descend_enum_views` derives view
paths from the symbol name, not from the filesystem, so for a missing symbol it still lists a
`symbol` row pointing at a file that does not exist (measured below). The Tk dialog does append
`(missing)` to the greyed path label (`src/xschem.tcl:6078`), which is the one honest signal
anywhere in this feature — but it is cosmetic: choosing that row and confirming still runs
`xschem descend_symbol`, still fails, and still says nothing. The `i` key and the toolbar button
never show that label at all.

**Same placeholder, different silent guard, on the schematic side.** `descend_schematic()` does not
test for `"missing"` — in fact `save.c:5589` is the *only* `"missing"` string comparison in the
entire C tree. The placeholder is refused there by the generic type guard:

```c
src/actions.c:3620-3624
   if(                   /*  do not descend if not subcircuit */
      (xctx->inst[n].ptr+ xctx->sym)->type &&
      strcmp( (xctx->inst[n].ptr+ xctx->sym)->type, "subcircuit") &&
      strcmp( (xctx->inst[n].ptr+ xctx->sym)->type, "primitive")
   ) return 0;
```

equally silently, and notably **after** `get_sch_from_sym()` has already produced a plausible
child filename (measured: `filename=…/no_such_cell_0254.sch`). Note also that
`descend_schematic`'s `alert` parameter cannot help: it is forwarded only to `load_schematic()`
(`src/actions.c:3737`) and never consulted by any of the earlier `return 0` refusals, so even the
one caller that passes `alert=1` (`descend_schematic(0, 1, 1, 1)`, `src/callback.c:4510` and
`:6453`) gets silence here. This is the shared surface with **0252**.

## Reproduce

Reproduced headless. `src/xschem` prebuilt, no `make`.

```tcl
# scratchpad/repro_0254.tcl
xschem clear force
xschem instance no_such_cell_0254.sym 0 0 0 0 {name=X1}
xschem unselect_all
xschem select instance 0
puts "inst 0 name    = [xschem getprop instance 0 cell::name]"
puts "inst 0 type    = [xschem getprop instance 0 cell::type]"
puts "currsch BEFORE = [xschem get currsch]"
set r [xschem descend_symbol]
puts "descend_symbol Tcl result = |$r|"
puts "currsch AFTER  = [xschem get currsch]"
```

```
$ ./src/xschem --nogui --pipe -q --script .../repro_0254.tcl 2>&1
Using run time directory XSCHEM_SHAREDIR = /home/analog/dev/xschem-claude/src
Sourcing /home/analog/dev/xschem-claude/src/xschemrc init file
=== 0254 descend_symbol on missing-symbol placeholder ===
l_s_d(): Symbol not found: no_such_cell_0254.sym
lastsel        = 1
instances      = 1
inst 0 name    = no_such_cell_0254.sym
inst 0 type    = missing
currsch BEFORE = 0
descend_symbol Tcl result = ||
currsch AFTER  = 0
schname AFTER  = /home/analog/dev/xschem-claude/untitled-39.sch
=== done ===
```

The single `l_s_d(): Symbol not found:` line is emitted by `xschem instance`, i.e. at *load*
time — here one statement earlier, in a real session at parent-open time. Fencing the descend
proves nothing is emitted by the descend itself, on any of the three entry forms:

```
l_s_d(): Symbol not found: no_such_cell_0254.sym
--- MARK: everything below is emitted BY the descend ---
descend_symbol -> ||  currsch=0
descend_symbol -inst X1 -> ||  currsch=0
descend        -> |0|  currsch=0
--- MARK: end ---
```

Nothing between the marks but the `puts` output. `xschem descend` at least returns a `0`
(`src/scheduler.c:3006`, `Tcl_SetResult(interp, dtoa(ret), TCL_VOLATILE)`); `descend_symbol`
returns the empty string on both forms.

Which guard fires on the schematic side, at `-d 1`:

```
get_sch_from_sym(): symbol no_such_cell_0254.sym inst=0 web_url=0
get_sch_from_sym(): sym->name=no_such_cell_0254.sym, filename=/home/analog/dev/xschem-claude/no_such_cell_0254.sch
descend_schematic(): selected:no_such_cell_0254.sym
descend_schematic(): inst type: missing
descend        -> |0|  currsch=0
```

— so `get_sch_from_sym()` succeeded and the type guard at `actions.c:3620` is what refuses.
`dbg(1,…)` is invisible at the default debug level on every channel.

The chooser enumerates and offers the view it cannot open:

```
enum_views  = |{schematic schematic .../no_such_cell_0254.sch} {symbol symbol .../no_such_cell_0254.sym}|
--- MARK ---
hi_descend inst=X1 type=symbol -> |0|
currsch = 0
--- END ---
```

Neither path exists on disk. `hi_descend` returns `0` with no `ciw_echo`, no stderr, nothing.

**Contrast (a *present* symbol, `type=subcircuit`, whose `.sch` is missing)** — fixture symbol on
an appended `XSCHEM_LIBRARY_PATH`:

```
type = subcircuit
--- MARK ---
descend (missing .sch, present .sym) -> |0|  currsch=1  schname=.../lib0254/foo0254.sch
--- END ---
```

`xschem descend` returns **0** while `currsch` has gone 0→1 and the window now shows a blank page
named after a file that does not exist — `xctx->currsch++` (`src/actions.c:3731`) happens *before*
`descend_ok = load_schematic(…)` (`:3737`) and is never rolled back. That is **0250**/**0261**, not
this issue, and it is recorded here only because it establishes the asymmetry the user actually
experiences: a missing *schematic* silently takes you somewhere wrong, a missing *symbol* silently
takes you nowhere.

Not attempted: a live-GUI run (see Status).

## Fix, if it is to be closed

Keep the refusal; add the sentence. Report **the name that failed to resolve**, not a generic
"cannot descend" — the whole value of the message is telling the user *which* reference is broken
and therefore what to fix in the library path.

At `src/save.c:5588`, replacing the bare `return 0`:

```c
    /* dont allow descend in the default missing symbol -- but SAY SO, naming the
     * symbol that failed to resolve: the placeholder box is exactly what the user
     * clicks to find that out. The load-time l_s_d() warning (save.c:4682) is
     * stderr-only, is suppressed for nested loads (recursion_counter != 1), and is
     * long gone by now. doc/claude/issues/0254-...md */
    if((xctx->inst[n].ptr+ xctx->sym)->type &&
       !strcmp( (xctx->inst[n].ptr+ xctx->sym)->type,"missing")) {
      char msg[PATH_MAX + 128];
      my_snprintf(msg, S(msg), "symbol not found: %s -- nothing to descend into", name);
      dbg(0, "descend_symbol(): %s\n", msg);
      statusmsg_hold(msg, 1);
      if(has_x) tclvareval("if {[info procs ciw_echo] ne {}} {ciw_echo {", msg, "} error}", NULL);
      return 0;
    }
```

`name` already holds `translate(n, xctx->inst[n].name)` from the line immediately above
(`src/save.c:5586`), so no plumbing is required. `save.c` already reaches Tcl this way
(`src/save.c:5193`, `if(has_x) tcleval("alert_ {…} {} 1");`) and `statusmsg_hold()` is the
0248-safe form (`src/xschem.h:2948`) — a plain `statusmsg()` is wiped by the coordinate readout.
Use `statusmsg_hold`, not `alert_`: a modal box for "you clicked a broken symbol" is punitive when
a schematic has twenty of them.

Two things that must be decided in the same pass, not left implicit:

- **Do the same for `descend_schematic`.** Same placeholder, same user gesture (`E` / Edit ▸ Push
  schematic), different guard (`src/actions.c:3620-3624`), same silence. Special-casing
  `type=="missing"` *before* the generic type guard there lets the two paths emit one identical
  message. Doing only `descend_symbol` fixes half the gesture surface and makes the remaining half
  more confusing, not less. Coordinate with **0252**, which owns the generic-type half of that
  guard.
- **Return the refusal.** `descend_symbol()`'s `0` is thrown away at `src/scheduler.c:3035`
  (`Tcl_ResetResult`). Making that branch `Tcl_SetResult(interp, ret ? "1" : "0", TCL_STATIC)`
  costs one line, lets `hi_descend_finish` (`src/xschem.tcl:5875-5880`) drop its currsch-watching
  workaround, and is the precondition for the chooser echoing anything of its own. That is
  **0251**'s scope; this issue is unfixable-in-spirit without it, because a script driving
  `xschem descend_symbol` still cannot tell success from refusal even after the C side starts
  talking.

## Risks

- **A user-authored `type=missing` symbol would be misreported.** The guard keys on the *content*
  of the loaded symbol (`type=missing`, from `src/systemlib/missing.sym`), not on provenance.
  A real, present `foo.sym` that happens to declare `type=missing` would be told "symbol not
  found: foo.sym", which is a lie. There is no substitution flag today. Discriminate at refusal
  time with a stat — `abs_sym_path()` (`src/xschem.h:2415`) plus a `my_fopen` — and word the
  message accordingly ("not found" vs. "type=missing: nothing to descend into").
- **Do not add an `xSymbol.flags` bit for this without checking `reset_caches()`.** Bit 1 is
  documented free for symbols (`src/xschem.h:850`), but `set_sym_flags()` opens with
  `sym->flags = 0;` (`src/actions.c:897`) and re-derives everything from `prop_ptr`, and
  `reset_caches()` (`src/actions.c:1844`, symbol loop at `:1854-1856`) calls it over every symbol
  in the context. Any bit
  set out-of-band at substitution time in `load_sym_def` is destroyed the next time caches reset.
  (`EMBEDDED`, set after the parse loop at `src/save.c:5337-5341`, has the same latent exposure —
  out of scope here, but do not copy that pattern assuming it is safe.)
- **Message volume.** A schematic with a whole missing library produces one placeholder per
  instance. The message fires per *descend attempt*, not per instance, so this is bounded by user
  gestures — but a `statusmsg_hold` on every click of a broken box in a mostly-broken schematic is
  noise. Consider deduping on the symbol name within a session, or leaving the CIW line and
  dropping the statusbar hold.
- **Not free of behaviour change for scripts.** Adding output to `descend_symbol` changes stderr
  for any harness that diffs it. `tests/headless/gold/` is currently clean (`grep -rl "Symbol not
  found" tests/headless/gold/` → 0 hits), so no headless baseline is at risk today; the
  `tests/netlisting/results/` transcripts *are* full of that string (the viewdraw/gschem import
  fixtures), but those cases have no committed `gold/` baseline (see CLAUDE.md) and verify nothing.
  Re-run the grep before landing in case a baseline is promoted first.
- **Untested surface.** No headless test currently instantiates an unresolvable symbol and
  descends, so both the current behaviour and any fix are unguarded. The proposed
  `tests/headless/test_descend_missing_sym_0254.tcl` should assert the transcript above verbatim
  (result string, `currsch` unchanged, and — after the fix — the presence of the named-symbol
  line), because the whole defect *is* the absence of output and only an output assertion can
  regress-guard it.

---

# RESOLUTION — FIXED (item D4, run 2026-08-09, branch open_pdk)

Part of the one mechanism described in 0251's resolution. Item status **E** (see 0251, D6).

## What was measured BEFORE

With stderr fenced by markers, so "nothing was emitted" is a positive observation:

```
D0 placeholder: name=XM cell=no_such_cell_0254.sym type='missing'
<<<STDERR FENCE OPEN (D1..D3)>>>
<<<STDERR FENCE CLOSED>>>
D1 descend_symbol       -> ''
D3 descend              -> '0'
D4 => the unresolved name 'no_such_cell_0254.sym' is never told to the user
E1 xschem get descend_error -> ''
```

All three entry points refused and **nothing** appeared on any channel — even though the
unresolved name was live in `name` (`src/save.c:5586`) two lines above the refusal. The only
trace in the whole session was `l_s_d(): Symbol not found: …` at parent-*load* time, gated on
`recursion_counter == 1` (so nested misses print nothing, ever) and stderr-only.

## What it does AFTER

```
D1 descend_symbol       -> '0'
D2 descend_symbol -inst -> '0'
D3 descend              -> '0'
E1 xschem get descend_error -> 'missing-symbol:no_such_cell_0254.sym'
```

and on the held status line (0248-safe — a plain `statusmsg` is clobbered by `select.c`):

```
statusmsg = {Descend: symbol not found: doomed.sym -- nothing to descend into} hold=1
```

The `-inst` form is covered too: it bypasses the *selection* guard but not this one.

## How

A named callee `descend_missing_sym(int n, const char *symname)` (`src/actions.c:3751`),
tested **before** the generic type guard on **both** verbs — `src/save.c:5604` and
`src/actions.c:3841`. Both emit the same sentence and record `missing-symbol:<name>`.

Per this issue's first risk note, a user-authored `type=missing` symbol that really exists on
disk is discriminated (`abs_sym_path` + `stat`) and worded differently:

```c
  if(path && path[0] && !stat(path, &sbuf))
    "Descend: %s declares type=missing -- nothing to descend into"
  else
    "Descend: symbol not found: %s -- nothing to descend into"
```

## Decision

- **D5 [R2] — `type=="missing"` becomes its own named, LOUD refusal, placed before
  `descend_schematic`'s generic type guard.** The placeholder is the one thing in this class
  the user *deliberately* clicked to interrogate — a `---MISSING SYMBOL---` box is precisely
  what you click to find out what broke — and none of the 262 symbols locked by
  `test_descend_inert_class.tcl` carries type `missing`, so the lock is untouched.
  - *Rejected:* leaving the placeholder inside the generic type guard — that forces a choice
    between making the whole annotation class loud and leaving the placeholder silent, which
    is exactly the flattening decision D2 forbids.

## Coverage and the stderr risk

Rows R07 (token), R08 (`statusmsg` contains the name, `statusmsg_hold == 1`), R10 (`-inst`
form) in `tests/headless/test_descend_symbol.tcl`; R17 on the `descend` verb in
`test_descend_refusal_channel_0251.tcl`.

This issue's "not free of behaviour change for scripts" note is satisfied: the fix speaks via
`statusmsg_hold()` and **never** `dbg(0)`, so stderr is unchanged. The inert-class header's
stderr-noise recipe prints nothing against the new binary.

Sabotage **S6** (`#define descend_missing_sym(n,symname) (0)`) turns R07, R08, R10 and R17
red. R07 is the sharp one: `descend_symbol` then returns `1` and **succeeds into** the
`---MISSING SYMBOL---` placeholder, and R17 records `not-descendable:missing` instead of
`missing-symbol:<name>` — so the token discriminates *which* guard fired, not merely that
something refused.

## Still open

`descend_missing_sym()` dereferences `(xctx->inst[n].ptr + xctx->sym)->type` with no
`ptr >= 0` guard, while `rebuild_selected_array()` guards exactly that elsewhere. Pre-existing
shape, but this fix moved the deref onto both verbs' hot path. See 0251 "still open" item 9.
