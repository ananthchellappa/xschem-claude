# 0251 — a refused descend is indistinguishable from a successful one at every caller

Status: **OPEN** — measured headless: four distinct `xschem descend` refusal causes all return the
string `0`, and `xschem descend_symbol` returns the empty string for refusal *and* for success.
Not measured: the GUI perception (no X session in this run) and the CADMAXHIER arm.
Area: `src/scheduler.c` `"descend"` (`:2968-3007`, result at `:3006`) and `"descend_symbol"`
(`:3015-3036`, result at `:3035`); `src/xschem.tcl` `hi_descend_finish()` (`:5865-5903`, the
`if {$ok}` at `:5888`); `src/callback.c:4519` and `:6590` (`descend_symbol()`'s int dropped);
`src/callback.c:4510` and `:6453` (`descend_schematic()`'s int dropped)
Tests: partial. `tests/headless/test_descend_log_absorb.tcl:152` asserts a refused
`xschem descend` returns `0`; `tests/headless/test_descend_untitled_preserve.tcl:50` and
`tests/buried_hilight.tcl:45` assert the success value (`== 1` / `ne "1"`).
`tests/headless/test_hi_descend.tcl` checks `hi_descend`'s return for a bad *view name*
(`:94-97`) but never for a *refused descend*. Nothing anywhere asserts that a refusal is
**reported**. Proposed: `tests/headless/test_descend_refusal_channel_0251.tcl`.
Found: 2026-08-08, in the descend silent-refusal census
(`doc/claude/code_analysis/descend_silent_refusal_census.md`)
Related: the whole 0249–0261 census batch, in particular
[0249](0249-descend-symbol-silently-refuses-any-multi-selection.md) (descend_symbol refuses a
multi-object selection), **0250** (a failed load with `alert=0` strands a blank child page),
**0253** (semaphore threshold disagreement; the `0` misread at `src/xschem.tcl:3717`),
**0256** (`open_sub_schematic` discards the result), **0259** (the `cadence_nav` descend procs
that do not echo). Pre-existing: [0203](0203-stale-sel_array-descends-a-deselected-instance.md)
(a *stale* `sel_array` makes a would-be refusal succeed — the mirror image of this issue, and
the reason probe case A2 below had to be rebuilt),
[0200](0200-descend-has-no-verb-noun-pick.md) (verb-noun pick, RESOLVED),
[0248](0248-gate-and-prompt-statusbar-messages-are-wiped-by-the-coordinate-readout.md)
(statusbar messages wiped — constrains one candidate fix).

## The defect

Descend has a rich set of refusal causes and exactly one, information-free, way to report any of
them — or, for the symbol view, no way at all. The signal is destroyed at three successive
layers, so by the time a caller could act on it there is nothing left to act on.

**Layer 1 — C → Tcl, `xschem descend`.** The dispatcher collapses every outcome into one integer
and stringifies it:

```c
src/scheduler.c:2968-2973
    else if(!strcmp(argv[1], "descend"))
    {
      int ret=0;
      int set_title = 1;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(xctx->semaphore == 0) {
```

```c
src/scheduler.c:3000-3007
            ret = descend_schematic(n, 0, 0, set_title);
          } else {
            ret = descend_schematic(0, 0, 0, set_title);
          }
        }
      }
      Tcl_SetResult(interp, dtoa(ret), TCL_VOLATILE);
    }
```

Note the shape: `ret` is initialised to `0` and the whole body is inside
`if(xctx->semaphore == 0)`. A semaphore-blocked call therefore returns `0` **without
`descend_schematic()` ever running** — indistinguishable, to Tcl, from a refusal the function
itself made. Inside `descend_schematic()` the `return 0`s are at `src/actions.c:3587` (max
hierarchy depth), `:3592` (selection is not an ELEMENT), `:3605` / `:3608` (Save-As cancelled /
save failed), `:3617` (`get_sch_from_sym()` produced no filename), `:3624` (symbol `type` is
neither `subcircuit` nor `primitive`) and `:3661` (the vector-instance number prompt was
cancelled). Seven causes, one value.

Worse, the final `return descend_ok` (`src/actions.c:3785`) carries a *different* meaning again:
`descend_ok` starts at `1` (`:3583`) and is only reassigned by `load_schematic()` at `:3737`,
which runs **after** `xctx->currsch++` at `:3731`. A `0` from that arm means "the hierarchy
already advanced and then the load failed", not "nothing happened" — see **0250**. A caller that
reads `0` as "still where I was" is wrong in exactly that case; `utils/cadence_nav.tcl:326-328`
is such a caller, and it returns without a compensating `go_back`.

The refusals themselves say nothing. `src/actions.c:3585-3593`:

```c
 if(xctx->currsch + 1 >= CADMAXHIER) {
   dbg(0, "descend_schematic(): max hierarchy depth reached: %d", CADMAXHIER);
   return 0;
 }
 rebuild_selected_array();
 if(/* xctx->lastsel !=1 || */ xctx->sel_array[0].type!=ELEMENT) {
   dbg(1, "descend_schematic(): wrong selection\n");
   return 0;
 }
```

`dbg(0, ...)` reaches stderr at the default debug level, so a terminal-launched user sees the
CADMAXHIER line and a desktop-launched user does not. `dbg(1, ...)` is invisible to both. Neither
is a return channel: nothing machine-readable, nothing correlated with the call.

**Layer 2 — C → Tcl, `xschem descend_symbol`.** Here the int is not collapsed, it is deleted:

```c
src/scheduler.c:3030-3036
          unselect_all(1);
          select_element(inst, SELECTED, 1, 1);
        }
        descend_symbol();
      }
      Tcl_ResetResult(interp);
    }
```

`descend_symbol()` is declared `int` (`src/xschem.h:2762`), is defined at **`src/save.c:5546`**
(not `actions.c`), and returns `0` from `:5559` (CADMAXHIER), `:5563` (`lastsel > 1`), `:5584`
(embedded-symbol save cancelled), `:5589` (symbol `type` is `"missing"`) and `:5594` (the
selection is not a single ELEMENT), and `1` from `:5701`. Every one of those becomes `""`. There
is no value a script can test.

The Tcl layer knows this and works around it rather than fixing it:

```tcl
src/xschem.tcl:5875-5880
  if {$vtype eq {symbol}} {
    # descend_symbol has no return value; detect success by the hierarchy level rising,
    # so a no-op symbol descend does not falsely report success and then mislabel /
    # clear the modified flag of the CURRENT (un-descended) schematic.
    xschem descend_symbol
    set ok [expr {[xschem get currsch] > $lvl}]
```

The comment is right about the Tcl command and wrong about the C function: `descend_symbol()`
*has* a return value, the dispatcher throws it away. Inferring success from `currsch` is a proxy,
not a channel — it still cannot say *why*, and it would misread any future refusal that happens
to leave `currsch` advanced (the `descend_ok` shape above, applied to the symbol path).

**Layer 3 — Tcl, `hi_descend_finish()`.** The schematic arm captures the value and then drops it
on the floor:

```tcl
src/xschem.tcl:5881-5888
  } else {
    if {![hi_descend_is_default_sch $instname $vpath]} {
      set ::hi_descend_view_path $vpath        ;# one-shot, consumed by get_sch_from_sym
    }
    set ok [xschem descend $iter]
    set ::hi_descend_view_path {}              ;# belt-and-suspenders if descend bailed early
  }
  if {$ok} {
```

`if {$ok}` has **no `else`**. `return $ok` at `:5902` propagates the `0` up through
`hi_descend_current` (`:5912`) → `hi_descend_do_body` (`:6035`) → `hi_descend_do` (`:6005`) →
`hi_descend` (`:6068`) → the Tk binding, whose script is
`{if {[expr {%s & 0x4c}]} {xschem callback ...} else {hi_descend}; break}`
(`hi_descend_keybind_script`, `src/xschem.tcl:6271-6273`, installed at `:14175`). A binding
script's result is discarded by Tk. On the verb-noun path the dialog is invoked as
`after idle [list hi_descend_dialog $instname]` (`hi_descend_pick_done`, `:6135`), where the
return value is not even reachable.

That silence is a local anomaly, not a house style. Every other failure arm in the same file
announces itself: `:5761` (no such instance), `:5771` (nothing selected), `:5871` (view type does
not descend), `:5910` (cannot select), `:5950` (new window/tab failed), `:6010` (no views),
`:6015` (no such view), `:6028` (cannot derive lib/cell), `:6038` (bad target), `:6057`/`:6062`
(bad option/argument), `:6065` (bad mode). Only the one that fires when the *descend itself* is
refused says nothing. `hi_descend_newwin()` has the same gap at `:5962-5977` — `set ok
[hi_descend_finish ...]`, `if {$ok}` at `:5968` and `:5976`, `return $ok`, no else.

**Layer 3b — the C callers.** `src/callback.c:4519` (context-menu case 13) and `:6590` (key `i`)
call `descend_symbol();` as a void statement. `:4510` (context-menu case 12) and `:6453` (key `e`
with no modifier) call `descend_schematic(0, 1, 1, 1);` the same way. The single C caller that
*does* consume the result is `:4513`, the "descend schematic, then force editable" arm:

```c
src/callback.c:4512-4517
    case 22: /* descend schematic, then force editable (overrides descend_readonly) */
      if(descend_schematic(0, 1, 1, 1)) {
        xctx->readonly = 0;
        set_modify(-1); /* refresh title: clear the read-only marker */
      }
      break;
```

— and it uses the result only to guard a side effect, never to tell the user anything.

**What the user perceives.** Press `e`, pick a view in the chooser, press OK. The dialog closes.
The canvas does not change. No dialog, no status-bar line, no CIW line, nothing on stderr unless
the session was launched from a terminal *and* the cause happened to be CADMAXHIER. The user has
no way to distinguish "this cell has no schematic", "you had two things selected", "the parent
Save-As was cancelled", and "a modal operation is in progress, try again". Scripts and action-log
replay are equally blind: the log line `xschem descend -inst x5` is written only on success
(`src/actions.c:3744-3745`), so a replay that refuses leaves no trace at all.

## Reproduce

Measured on `src/xschem` (prebuilt, this working tree), `--nogui --pipe -q --nolog`. Fixture:
`tests/headless/fixtures/descend/descend_child.{sch,sym}` plus a derived `labcell.sym` that is
byte-identical except `type=subcircuit` → `type=label`, with a `labcell.sch` beside it — so the
chooser *does* list a schematic view and `descend_schematic()` still refuses it at
`src/actions.c:3620-3624`. `ciw_echo` is a no-op headless (`src/ciw.tcl:113-115`), so the probe
renames it and records every message that *would* have reached the CIW.

```
=== A. `xschem descend`: four distinct refusal causes, one string ===
  A1 nothing selected                        ret=<0> currsch=0 echoed=NOTHING
  A2 wire-only selection                     ret=<0> currsch=0 echoed=NOTHING
  A3 type=label, .sch exists                 ret=<0> currsch=0 echoed=NOTHING
  A4 semaphore held (never called)           ret=<0> currsch=0 echoed=NOTHING
  A5 SUCCESS                                 ret=<1> currsch=1 echoed=NOTHING

=== B. `xschem descend_symbol`: refusal == success == the empty string ===
  B1 nothing selected                        ret=<> currsch=0 echoed=NOTHING
  B2 two instances selected                  ret=<> currsch=0 echoed=NOTHING
  B3 SUCCESS                                 ret=<> currsch=1 echoed=NOTHING
     schname = descend_child.sym

=== C. hi_descend: the sibling failures echo, the descend failure does not ===
  C1 no such instance (:5761 arm)            ret=<0> currsch=0 echoed={[error] hi_descend: no such instance: nope}
  C2 nothing selected (:5771 arm)            ret=<0> currsch=0 echoed={[error] hi_descend: select an instance to descend into}
  C3 bad view name (:6015 arm)               ret=<0> currsch=0 echoed={[error] hi_descend: no view "zzz" for x1 (have: schematic, symbol)}
  C4 descend REFUSED (:5885/:5888)           ret=<0> currsch=0 echoed=NOTHING
```

A1–A4 are four unrelated causes — no ELEMENT in `sel_array`, a wire-only selection, a symbol
whose `type` bars descent, and a held semaphore that means the C function was never entered —
producing one indistinguishable `0`. B1/B2 versus B3 is the sharper failure: the refusals and the
success are the *same empty string*, and only the out-of-band `currsch` read separates them.
C4 is the user-facing one: `hi_descend` picked the schematic view for `l1`, called
`xschem descend`, got `0`, and returned `0` having said nothing — while C1/C2/C3, three failures
in the same proc family, all echo.

Two honesty notes on the transcript. C2's message is emitted by `hi_descend_pick_arm()` at
`src/xschem.tcl:6106` (the headless `![info exists ::has_x]` arm), not by `:5771`; the text is
identical at both sites and both are `ciw_echo`, so the point — sibling failures speak — stands,
but the line attribution in the probe label is the arm's twin. And an earlier draft of A2 that
selected, then `select_all`ed, then `unselect_all`ed before descending returned **`1`** and
advanced `currsch` — that is [0203](0203-stale-sel_array-descends-a-deselected-instance.md)
(a stale `sel_array` descending a deselected instance) firing, not this issue; the transcript
above uses a freshly built wire-only context to avoid it.

Not reproduced: the CADMAXHIER arm (`src/actions.c:3587`, the one refusal that *does* reach
stderr via `dbg(0, ...)`), and the GUI perception of the C4 case — no X session was used, so
"the dialog closes and nothing happens" is read from the code path, not observed.

Probe script: `/tmp/claude-1000/-home-analog-dev-xschem-claude/ee436d63-e0fe-4f9d-aa40-0c351cf000f5/scratchpad/ret0251c.tcl`
(scratch, not committed).

## Who actually consumes the return today

Grepping `xschem descend` and `descend_schematic(` across the tree, the callers that read the
result at all are few, and one of them misreads it:

| site | what it does | verdict |
|---|---|---|
| `src/xschem.tcl:3717` | `set descended [xschem descend 1 6]`; the `else` comment reads *"descended into a blank schematic. Go back."* | **misreads** — treats every refusal as "blank schematic". See **0253**. |
| `sky130A/sky130_procs.tcl:148-155` | `set res [xschem descend $n 2]`, `else` → `go_back 2` + `puts "Can not descend into $instname"` | reports, but with the same wrong cause attribution (comment: *"descended into a blank schematic"*) |
| `ihp-sg13g2/sg13g2_procs.tcl:399-406` | identical copy of the sky130 block | same |
| `utils/cadence_nav.tcl:326-328` | `if {[xschem descend] == 0} { ciw_echo "cannot descend into '$name'" error ; return 0 }` | the only caller that both tests *and* tells the user — and still cannot say why |
| `src/callback.c:4513` | `if(descend_schematic(0, 1, 1, 1)) { … }` | guards a side effect only |
| `tests/buried_hilight.tcl:45`, `tests/headless/test_descend_untitled_preserve.tcl:50`, `tests/headless/test_descend_log_absorb.tcl:100,152` | assert `1` / `0` / `ne "1"` | pin the current string form |

Every other call site — `src/xschem.tcl:3872`, `:5710`, `:5885`, `:13166-13167`, `:14726`,
`utils/cadence_nav.tcl:238`, `:245`, `src/callback.c:4510`, `:4519`, `:6453`, `:6590` and all the
`xschem descend` lines under `tests/` — discards it.

No caller anywhere consumes a *reason*, because none is produced.

## Fix, if it is to be closed

A boolean is not enough; the cheapest useful thing is a reason channel that the dispatcher can
surface and Tcl can echo.

1. **Give the two C entry points an enum-shaped result.** Keep the `int` return exactly as it is
   (see the compatibility constraint below) and add a module-level `static char
   descend_last_error[…]` set on every early `return 0` in `descend_schematic()`
   (`src/actions.c:3587, 3592, 3605, 3608, 3617, 3624, 3661, 3785`) and `descend_symbol()`
   (`src/save.c:5559, 5563, 5584, 5589, 5594`), cleared on entry, with an accessor
   `const char *descend_last_error(void)`. Distinguish at minimum: `maxdepth`, `no-selection`,
   `multi-selection`, `not-subcircuit`, `no-schematic`, `save-cancelled`, `iter-cancelled`,
   `load-failed` (the post-`currsch++` case — a *different* recovery for the caller, see 0250).
   The semaphore case belongs to the dispatcher, which knows it without asking
   (`src/scheduler.c:2973`, `:3018`), and must be reported as `busy`, not as a descend refusal.

2. **Expose it without changing the existing result.** Add `xschem get descend_error` (or
   `xschem descend -why`) rather than widening the result string of `xschem descend`. That keeps
   `src/xschem.tcl:3717`, the two PDK procs, `utils/cadence_nav.tcl:326` and the four test
   assertions working byte-for-byte.

3. **Stop deleting `descend_symbol()`'s int.** `src/scheduler.c:3033-3035` becomes
   `Tcl_SetResult(interp, dtoa(descend_symbol()), TCL_VOLATILE);` — but only inside the
   `semaphore == 0` guard, with the outer default staying `0`, mirroring the `descend` branch.
   This is the one *behavioural* change to a documented result and needs a scan for scripts that
   test `[xschem descend_symbol] eq {}`; none exist in-tree (grep for `xschem descend_symbol`
   finds only bare invocations and the `-inst` action-log tests). Once it returns a value,
   `hi_descend_finish`'s `currsch`-rise proxy at `src/xschem.tcl:5876-5880` can be replaced by
   the real thing and its stale comment deleted.

4. **Add the missing `else`.** In `hi_descend_finish()` (`src/xschem.tcl:5888`):

   ```tcl
     if {$ok} {
       …
     } else {
       ciw_echo "hi_descend: cannot descend into $instname ([xschem get descend_error])" error
     }
   ```

   and the same at `hi_descend_newwin()`'s `:5968`. This alone converts the C4 transcript row
   from `echoed=NOTHING` into a line the user can read, and it makes the proc consistent with its
   eleven siblings.

5. **The two C key/menu callers** (`src/callback.c:4510`, `:4519`, `:6453`, `:6590`) should route
   the same reason to `statusmsg()`. Note the constraint from
   [0248](0248-gate-and-prompt-statusbar-messages-are-wiped-by-the-coordinate-readout.md):
   a plain `statusmsg()` line is wiped by the next coordinate readout, so use the hold variant or
   this becomes another invisible refusal.

## Risks

- **The `"0"` string is load-bearing.** `src/xschem.tcl:3717`, `sky130A/sky130_procs.tcl:148`,
  `ihp-sg13g2/sg13g2_procs.tcl:399`, `utils/cadence_nav.tcl:326`,
  `tests/buried_hilight.tcl:45` (`ne "1"`, i.e. a *string* compare),
  `tests/headless/test_descend_untitled_preserve.tcl:50` and
  `tests/headless/test_descend_log_absorb.tcl:100,152` all depend on it. Anything richer must be
  a *second* channel, not a widened result.
- **Changing `descend_symbol`'s result is a public-API change** even though nothing in-tree reads
  it. Out-of-tree user scripts and PDK glue could. It is the smallest such change available and
  is worth making, but it is not free.
- **A per-context reason string needs the same lifetime discipline as the rest of `xctx`.**
  A `static` in `actions.c` is shared across tabs/windows; if a descend in window A is followed by
  a read in window B the reason is stale. Either hang it off `Xschem_ctx` or document that it is
  only valid immediately after the call, as `Tcl_GetStringResult` is.
- **Attributing the cause is not the same as fixing the refusal.** Several census items (0249,
  0252, 0254, 0255) are refusals that arguably should not happen at all. Adding a reason channel
  makes them *visible*, which will surface them as bug reports before they are fixed — that is the
  point, but it should be a conscious choice.
- **`load_failed` is not a refusal.** Returning it through the same channel as the pre-`currsch++`
  refusals invites callers to treat "we are one level down on a blank page" (0250) as "nothing
  happened". If the enum is added, that value must be documented as *requiring* a `go_back`, and
  `utils/cadence_nav.tcl:326-328` must be fixed at the same time.
- **No coverage of the reporting itself.** Everything currently asserted about descend is about
  the *value*; a fix here needs a new test that asserts a *message* was produced, which means the
  test has to intercept `ciw_echo`/`statusmsg` as the probe above does.
