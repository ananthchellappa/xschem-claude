# 0252 — the descend chooser offers a schematic view for symbols the C guard will refuse

Status: **OPEN** — the C refusal and the chooser's disagreement are both measured headless; the
`fallback=1` modal-then-refuse ordering is read from source only (`has_x`-gated, so GUI-only).
Area: `src/actions.c` `descend_schematic()` type guard (`:3620-3624`); `src/xschem.tcl` `hi_descend_enum_views()` (`:5781-5819`, unconditional default row `:5806-5813`), `hi_descend_pick_view()` (`:5823-5839`), `hi_descend_do_body()` (`:6008-6040`), `hi_descend_finish()` (`:5865-5903`); `set_sym_flags()` (`src/actions.c:894`); `reset_caches()` (`src/actions.c:1844`)
Tests: none yet — proposed `tests/headless/test_descend_type_guard_0252.tcl`
Found: 2026-08-08, in the descend silent-refusal census (`doc/claude/code_analysis/descend_silent_refusal_census.md`)
Related: [0251](0251-a-refused-descend-has-no-return-channel.md) (the `0` this guard returns is discarded at every caller — that is why nothing downstream can report it), [0250](0250-failed-descend-strands-the-window-on-a-blank-child-page.md), [0254](0254-descend-symbol-on-a-missing-symbol-placeholder-is-silent.md) (the `type=missing` twin in `descend_symbol()`, `src/save.c:5588-5589`), [0260](0260-hi-descend-dialog-returns-zero-for-an-instance-with-no-name-token.md), [0261](0261-descend-reports-success-on-a-blank-page.md), [0232](0232-missing-symbol-substitution-silently-unnames-nets.md) (the other half of the missing-symbol silence). Spec: `doc/claude/specs/hi_descend.md`.

## The defect

`descend_schematic()` refuses any instance whose symbol is not `subcircuit` or `primitive`
with a bare `return 0`:

```c
src/actions.c:3620-3624
   if(                   /*  do not descend if not subcircuit */
      (xctx->inst[n].ptr+ xctx->sym)->type &&
      strcmp( (xctx->inst[n].ptr+ xctx->sym)->type, "subcircuit") &&
      strcmp( (xctx->inst[n].ptr+ xctx->sym)->type, "primitive")
   ) return 0;
```

No `alert_`, no `statusmsg`, no `ciw_echo`, no stderr. The only trace of the decision is the
line immediately above it:

```c
src/actions.c:3619
   dbg(1, "descend_schematic(): inst type: %s\n", (xctx->inst[n].ptr+ xctx->sym)->type);
```

`dbg(1, ...)` is invisible at the default debug level, so **no user sees this on any launch
path** — not even a terminal-launched one, which does receive `dbg(0, ...)`.

**The `alert` parameter cannot help here.** `descend_schematic(instnumber, fallback, alert,
set_title)` forwards `alert` to exactly one place, `load_schematic()` at `src/actions.c:3737`
— 113 lines *after* this guard. The two call sites that bother to pass `alert=1`
(`src/callback.c:4510` and `:4513`, the right-click context menu; `src/callback.c:6453`, the raw
C `e` handler, all `descend_schematic(0, 1, 1, 1)`) therefore get exactly the same silence as
the `alert=0` callers. Requesting alerts does not make this refusal speak.

### The real UX defect is the pairing with the chooser

Refusing to descend into a resistor is correct. The defect is that the **Tcl chooser offers the
schematic view first, and only the C guard knows it is a lie.**

`hi_descend_enum_views()` appends a default `schematic` row unconditionally:

```tcl
src/xschem.tcl:5806-5813
  # Always make sure the default schematic view and the symbol view are present
  # (covers legacy flat cells, and OA cells whose default sits outside cell_views).
  set defsch {}
  catch { set defsch [xschem get_sch_from_sym -1 $sym] }
  if {$defsch ne {} && ![xschem is_generator $defsch] && [lsearch -exact $seen $defsch] < 0} {
    lappend rows [list schematic schematic $defsch]
    lappend seen $defsch
  }
```

The only filter is `is_generator`. There is **no symbol-type filter** — `type` is never consulted
anywhere in the proc — and no `file exists` test, because `get_sch_from_sym()` cheerfully returns
a path for a schematic that was never created (`src/actions.c:3494-3495`, the "symbol exists.
pretend schematic exists too" branch). `hi_descend_pick_view()` then *prefers* that row
(`src/xschem.tcl:5831`), and `hi_descend_dialog_body()` makes it the drop-down's default
(`src/xschem.tcl:6196-6199`).

So the user selects an instance, presses `e`, is shown a **View: schematic** row, presses OK, the
dialog destroys itself — and nothing happens. The chooser advertised a capability the C layer was
always going to veto.

The silence survives the whole Tcl return path, and this is not for want of a channel:
`hi_descend_do_body()` calls `ciw_echo` on *every other* failure arm — no views (`:6010`),
unknown view name (`:6015`), underivable lib/cell (`:6028`), bad target (`:6038`) — and
`hi_descend_finish()` echoes for a non-descendable view type (`:5871`). The one arm with no echo
is the one that matters: `hi_descend_current()` (`:5906-5913`) returns `hi_descend_finish()`'s
`$ok`, which is `[xschem descend $iter]` (`:5885`) — a bare `0` — straight up through
`hi_descend_do` to a caller that drops it.

### What the guard actually covers

1. **Every ordinary device** — `type=resistor`, `nmos`, `label`, `vsource`, … Refusing is right;
   saying nothing is not.
2. **A symbol with no `type=` token at all.** Refused — see the correction below.
3. **The missing-symbol placeholder**, `src/systemlib/missing.sym`, whose first record is
   `G {type=missing`. `descend_symbol()` guards this case explicitly and separately
   (`src/save.c:5588-5589`); in `descend_schematic()` it just falls into the generic
   non-subcircuit refusal.

### Correction to the census brief: an untyped symbol IS refused, and the NULL branch is dead

The brief predicted an asymmetry — that a symbol with no `type=` gets `type == ""` (non-NULL, so
the guard fires) while a genuinely NULL `type` short-circuits the `&&` and is let through. The
first half is right; **the second half is unreachable in practice.**

The mechanism for `""` is as predicted. `set_sym_flags()` caches the token with `my_strdup2`:

```c
src/actions.c:901-902
  my_strdup2(_ALLOC_ID_, &sym->type,
             get_tok_value(sym->prop_ptr, "type",0));
```

`get_tok_value()` returns the literal `""` both when the property string is NULL
(`src/token.c:472-481`) and when the token is absent (`src/token.c:482`), and `my_strdup2()`
"duplicates also empty string" (`src/util.c:718-728`) rather than freeing the destination. So
`sym->type` becomes `""` — non-NULL, and both `strcmp`s are non-zero, so the guard fires.

But the NULL state cannot survive to the guard either. `load_sym_def()` does initialise
`symbol[symbols].type = NULL` (`src/save.c:4700`) and calls `set_sym_flags()` only when a `K` or
`G` record actually loaded a non-NULL `prop_ptr` (`src/save.c:4756-4762`, `:4767-4772`) — so a
`.sym` with neither record leaves `type` NULL *at load time*. `reset_caches()` then normalises it
away:

```c
src/actions.c:1854-1856
  for(i = 0; i < xctx->symbols; i++) {
    set_sym_flags(&xctx->sym[i]);
  }
```

and that runs unconditionally from `prepare_netlist_structs()` (`src/netlist.c:1796`), which the
editor reaches long before any descend. Measured below: a `.sym` with **no `G` and no `K` record
at all** still reports `type` as `""` and is still refused. I could not construct a case where
the `type &&` short-circuit is taken. The NULL branch is defensive code that no longer defends
anything — which makes the guard's behaviour *more* uniform than the source reads, not less, but
also means the many NULL-checking siblings (`src/findnet.c:225`, `src/spice_netlist.c:342`,
`src/vhdl_netlist.c:43`, `src/editprop.c:1335`) are guarding a state the pipeline erases.

### Correction: the dialog does flag a missing *file* — but not an ineligible *type*

The brief's "no existence check" is accurate for `hi_descend_enum_views`, but the **dialog** is
not entirely mute about existence:

```tcl
src/xschem.tcl:6078
      .hi_descend.view.path configure -text [expr {[file exists $p] ? $p : "$p  (missing)"}]
```

A grey `-fg gray40` subordinate label (`src/xschem.tcl:6204`) gains the suffix `  (missing)`.
That is a hint, not a refusal: the OK button (`src/xschem.tcl:6244`) is never disabled, and the
label says nothing whatsoever about symbol *type*. The worst case is therefore the one where the
label is **reassuring** — a non-subcircuit symbol carrying an explicit `schematic=` attribute
that points at a file which really does exist. The path renders clean, with no `(missing)`
marker, and the descend is still refused. That case is measured below.

### Ordering: the modal can be answered and then overruled

The guard at `:3620` runs *after* `get_sch_from_sym()` (called at `src/actions.c:3615`), which on
a `fallback` path can put up a modal:

```c
src/actions.c:3467-3471
  if(has_x && fallback && !is_gen && filename[0]) {
    file_exists = !stat(filename, &buf);
    if(!file_exists) {
      tclvareval("ask_save {Schematic ", filename, "\ndoes not exist.\nDescend into base schematic?}", NULL);
```

So on the `fallback=1` sites (`src/callback.c:4510/4513/6453`) the user can be asked "Schematic X
does not exist. Descend into base schematic?", click **yes**, and then be refused with no message
at all. Narrower than the brief implied, though: the arm needs `has_x` **and** `fallback` **and**
a non-empty `filename`, i.e. the symbol or instance must already carry a `schematic=` attribute.
A plain `res.sym` with no such attribute leaves `str_tmp` empty, `filename` empty, and never
reaches the modal. Note also that every Tcl-driven descend hardcodes `fallback=0`
(`src/scheduler.c:2993`, `:3000`, `:3002`), so the chooser path never sees this modal — only the
raw C key and the context menu do.

## Reproduce

Measured against the prebuilt `src/xschem`, WSL2, `2026-08-08`. Fixture symbols in the scratchpad;
`subck.sym` is `type=subcircuit`, `notype.sym` has a `K` record with `template=` but no `type=`,
`nullprop.sym` has neither a `G` nor a `K` record.

**The chooser/guard disagreement, on stock library devices.** For each: enumerate the views the
chooser would show, ask it which row it defaults to, then descend.

```
== res.sym (type=resistor)
   rows={schematic schematic .../xschem_library/devices/res.sch} {symbol symbol .../devices/res.sym}
   pick=schematic schematic .../xschem_library/devices/res.sch
   descend ret=0  currsch=0
== lab_wire.sym (type=label)
   rows={schematic schematic .../xschem_library/devices/lab_wire.sch} {symbol symbol .../devices/lab_wire.sym}
   pick=schematic schematic .../xschem_library/devices/lab_wire.sch
   descend ret=0  currsch=0
== vsource.sym
   rows={schematic schematic .../xschem_library/devices/vsource.sch} {symbol symbol .../devices/vsource.sym}
   pick=schematic schematic .../xschem_library/devices/vsource.sch
   descend ret=0  currsch=0
```

Neither `xschem_library/devices/res.sch` nor `lab_wire.sch` exists (`ls` → `No such file or
directory`). The chooser offered, and defaulted to, a schematic view that is both non-existent
and type-ineligible.

**The reassuring-label case** — `type=resistor` plus `schematic=` pointing at a file that *does*
exist, so the dialog's path label renders clean with no `(missing)` suffix:

```
rows={schematic schematic .../scratchpad/lib/subck.sch} {symbol symbol .../scratchpad/lib/rsch.sym}
get_sch_from_sym=/.../scratchpad/lib/subck.sch
descend ret=0 currsch=0
hi_descend ret=0
```

`hi_descend inst=xt1` returns `0` having emitted no message — the OK-press equivalent.

**Which branch fires**, using the `dbg(1, ...)` at `src/actions.c:3632` (`selected instname=`,
the first statement after the guard) as the probe. Its presence means the guard was passed:

```
$ ./src/xschem --nogui --pipe -q -d 1 --script t2.tcl
---- RES(type=resistor)
descend_schematic(): inst type: resistor
>>>> RES(type=resistor) ret=0 currsch=0 list={xt1} {res.sym} {resistor}
---- SUBCK(type=subcircuit)
descend_schematic(): inst type: subcircuit
descend_schematic(): selected instname=xt1
>>>> SUBCK(type=subcircuit) ret=1 currsch=1 list=
---- NOTYPE(K present,no type=)
descend_schematic(): inst type: 
>>>> NOTYPE(K present,no type=) ret=0 currsch=0 list={xt1} {.../notype.sym} {}
---- NULLPROP(no G/K record)
descend_schematic(): inst type: 
>>>> NULLPROP(no G/K record) ret=0 currsch=0 list={xt1} {.../nullprop.sym} {}
```

Only `subcircuit` reaches `selected instname=`. **`NULLPROP` — the file with no property record
whatsoever — prints an empty type, not `(null)`, and is refused**, which is the measurement that
corrects the brief. Isolated to a single descend with no prior one, `reset_caches()` is still
observed running ahead of it:

```
$ ./src/xschem --nogui --pipe -q -d 1 --script t3.tcl
reset_caches()
descend_schematic(): inst type: 
ret=0 currsch=0
```

**Not reproduced:** the `ask_save`-then-silent-refusal ordering. `src/actions.c:3467` is gated on
`has_x`, which is false under `--nogui`, so the modal cannot be driven headless. That claim rests
on source reading alone and is GUI-only.

**What the user perceives** (GUI, desktop-launched): select a resistor, press `e`, the descend
dialog opens showing `View: schematic`, press OK or Return. The dialog vanishes. The canvas is
unchanged, the title bar is unchanged, the status bar is unchanged, the CIW logs nothing. There
is no way to distinguish this from a dropped keystroke.

## Fix, if it is to be closed

Two independent halves; do the first even if the second is deferred.

**1. Make the chooser's row list agree with the C guard.** The row set is built in one place, so
the filter belongs there. In `hi_descend_enum_views()` (`src/xschem.tcl:5806-5813`), suppress the
default `schematic` row when the symbol type cannot descend and the file does not exist:

```tcl
  # A schematic row the C guard (src/actions.c:3620) will refuse is worse than no
  # row: the user picks it, presses OK, and nothing happens. issue 0252.
  set symtype {}
  foreach {i s t} [xschem instance_list] { if {$i eq $instname} { set symtype $t } }
  set descendable [expr {$symtype in {subcircuit primitive}}]
  if {$defsch ne {} && ![xschem is_generator $defsch] &&
      ($descendable || [file exists $defsch]) && [lsearch -exact $seen $defsch] < 0} {
```

Keeping the `[file exists]` escape hatch matters: a symbol may legitimately be mistyped while its
schematic exists, and hiding the row would remove the user's only route to fixing it. The row
survives, the C guard still refuses, and half 2 explains why. A stricter variant — drop the row
unless `$descendable` — is cleaner but forecloses that repair path; prefer the disjunction.

Do **not** filter the `symbol` row (`:5814-5817`). `descend_symbol()` has its own, different
eligibility rule (`src/save.c:5588-5589` refuses only `type=missing`), and a resistor's symbol
view is perfectly descendable — that is the correct answer for the resistor case and should stay
one drop-down click away.

**2. Give the C guard a message,** for the raw-key and context-menu paths that bypass the chooser
entirely. The refusal is a *user error*, not an internal one, so `dbg(0, ...)` is the wrong
channel (invisible to a desktop-launched user):

```c
   if( (xctx->inst[n].ptr+ xctx->sym)->type &&
       strcmp( (xctx->inst[n].ptr+ xctx->sym)->type, "subcircuit") &&
       strcmp( (xctx->inst[n].ptr+ xctx->sym)->type, "primitive")
   ) {
     char m[256];
     my_snprintf(m, S(m), "cannot descend: %s is type '%s', not subcircuit/primitive"
                          " -- use descend-to-symbol (I)",
                 xctx->inst[n].instname ? xctx->inst[n].instname : "?",
                 (xctx->inst[n].ptr+ xctx->sym)->type);
     statusmsg(m, 2);
     return 0;
   }
```

Naming the alternative (`I`, `src/callback.c:6587`) turns a dead end into a redirect — descending
into a resistor's *symbol* is almost always what the user actually wanted. Check `statusmsg`'s
lifetime against [0248](0248-gate-and-prompt-statusbar-messages-are-wiped-by-the-coordinate-readout.md)
before relying on it; if the coordinate readout still wipes it, route through `ciw_echo` instead.

**3. Separately: fix `""` vs NULL.** Worth doing on its own merits, not as part of this issue. The
NULL branch of the guard is unreachable (measured above) yet is replicated across at least
`src/findnet.c:225`, `src/spice_netlist.c:342`, `src/vhdl_netlist.c:43`, `src/editprop.c:1335`.
Either make `set_sym_flags()` leave `type` NULL when the token is absent (use `my_strdup`, which
frees on NULL/empty, rather than `my_strdup2`) so the NULL checks become real, or delete the NULL
checks and document `type` as always-non-NULL-after-`set_sym_flags`. Doing neither leaves two
spellings of "untyped" that behave identically by accident. **The `my_strdup` route is not free**:
every one of those call sites currently dereferences `type` after a merely-truthy test, and a
`type` that is genuinely NULL would newly reach `strcmp` in code paths that today never see it —
audit all of them together, and note that `type=""` and "no `type=` token" would stop being
distinguishable in the other direction.

Proposed coverage, `tests/headless/test_descend_type_guard_0252.tcl`: for each of
`{subcircuit primitive resistor {} }` assert `[xschem descend]` matches the expected 1/1/0/0, and
assert `hi_descend_enum_views` emits no `schematic` row for the ineligible-and-nonexistent cases.

## Risks

- **Hiding a row hides a repair path.** A cell whose symbol is genuinely mistyped (`type=resistor`
  on something that has a real schematic) is a common hand-editing slip. The `[file exists]`
  disjunction above is what keeps that case visible; a stricter filter would silently remove the
  user's route to noticing the typo. This is the main reason not to over-filter.
- **`instance_list` is O(instances) per enum call.** `hi_descend_enum_views` currently touches no
  instance array; the fix above scans the whole list to recover one type. On a large sheet the
  chooser gains a linear scan per open. Prefer a dedicated `xschem instance_type <name>`
  accessor if one is added — and note `instance_list` maps NULL type to `""`
  (`src/scheduler.c:6434-6435`), so it cannot distinguish the two spellings discussed above.
- **`primitive` is in the guard but not in most people's mental model.** Any filter must accept
  both `subcircuit` and `primitive` or it will start hiding rows that descend fine today.
- **Message spam on rubber-band selections.** With [0255](0255-an-instance-co-selected-with-a-text-silently-blocks-descend.md)
  in play, a user who repeatedly presses `e` over a mixed selection could now get a status message
  naming a type they did not intend to descend into. The message must name the instance, not just
  the type, or it will read as noise.
- **Return-value change.** The fix deliberately does **not** change what `descend_schematic()`
  returns — it still returns `0`. Anything that wants to distinguish "refused because type" from
  "refused because no selection" needs [0251](0251-a-refused-descend-has-no-return-channel.md)
  first; adding a distinct return code here without that would be a silent API change no caller
  reads.
- **No coverage today.** Nothing in `tests/headless/` exercises the type guard, so any change to
  it is currently unguarded.

---

## D5 attempt (2026-08-10) — built, then **REVERTED**. Still OPEN, and now with a known landmine.

Measured BEFORE (unchanged — the tree is back at `b1326180`):

```
0252   row view='schematic' label='schematic' path='.../devices/res.sch' EXISTS=0
0252 descend_error       : 'not-descendable:resistor'
0252 statusmsg changed   : 0
```

Two things were built: a chooser filter (`hi_descend_row_offerable`) so the enumerator stops
offering a row the C guard will veto, and a spoken refusal at the surface the user drove
(`hi_descend_refuse` → held `statusmsg` **and** `ciw_echo`, because `ciw_echo` alone is a hard
no-op without the `.ciw.l.t` widget). The C type guard stayed byte-silent (R1 / 0243 F2 — gates
live at the verbs), so the committed 177-check inert-class silence lock stayed green.

**The filter is what killed the whole item.** It decides via `xschem get_sym_type $symabs`, and that
command returns **empty whenever an instance is selected** — the exact state the user is in when
they select an instance and descend. The filter then collapses to a pure file-exists test and drops
the schematic row for a `type=subcircuit` whose child does not exist yet:

```
ns.sch exists = 0 (create-the-child flow)
BY NAME  rows = {schematic .../ns.sch} {symbol .../ns.sym}
SELECTED rows = {symbol .../ns.sym}          <- schematic view GONE
```

Row V5 ("a subcircuit whose .sch does not exist yet is still offered") passed **only because the
suite addresses instances by name (`inst=XN`), never with a live selection** — a green suite hiding
a broken workflow. Root cause filed as
[0379](0379-get-sym-type-returns-empty-while-an-instance-is-selected.md).

The filter also caused a second regression: with the row removed, the C guard never runs, so
`hi_descend` returned `0` with `descend_error` **empty** — byte-identical to a success. Filed as
[0378](0378-hi-descend-tcl-level-bails-leave-descend-error-unreadable.md).

**Do not re-attempt this filter until 0379 is fixed**, and any test for it **must set a selection** —
that is the only reason this survived a 67-check suite, an 8-variant sabotage matrix and an
adversary pass. This file's existing "risks" section already warned that over-filtering silently
removes the user's route to noticing a mistyped symbol; the create-the-child flow is a second,
sharper instance of the same hazard.

The spoken-refusal half (`hi_descend_refuse`) is independent of the filter and can land on its own.

## 2026-08-15 — the human asked for this again, filed as 0411

During the D1–D10 eyeball verification the human asked that, in cadence mode, `e` with an
instance selected offer descending into the **symbol**. That is this issue's chooser half, and it
is filed as
[0411](0411-cadence-e-should-offer-descending-into-the-symbol-of-the-selected-instance.md), which
names **this** issue as its vehicle and
[0379](0379-get-sym-type-returns-empty-while-an-instance-is-selected.md) as its blocker.

Crew item D11 shipped only the keyboard half —
[0410](0410-descend-into-symbol-has-no-key-in-cadence-mode.md), Ctrl-Y bound to
`xschem descend_symbol` in `src/cadence_style_rc`, because the cadence `i` steal left
descend-into-symbol with no key at all — and deliberately built **no** chooser behaviour.

Note for whoever resumes the filter: 0379, the reason the D5 attempt (`504e38c7`) was reverted,
**did not reproduce** when re-measured twice on 2026-08-15. Re-measure it before treating it as
the blocker, and read the caveat at the end of that file.
