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

---

# RESOLUTION — FIXED (the refusal half); one failure site remains OPEN as 0369

Item D4, run 2026-08-09, branch open_pdk. This is the **umbrella** resolution: 0249, 0254,
0256 and 0366 were closed by the single mechanism described here.
Item status is **E** — decision D6 below is a user-visible API change taken at ladder rung
R3 with no prior ratification, and needs a human ruling.

## What was measured BEFORE

```
A1 nothing selected   : descend_symbol -> ''   currsch=0
A2 one instance (OK)  : descend_symbol -> ''   currsch=1
A3 => a refused descend and a successful descend return the SAME string
B1 nothing selected   : descend -> '0'
B2 wire-only selection: descend -> '0'   selected_set={}
B3 non-subcircuit inst: descend -> '0'   selected_set={{l1}}
B4 success            : descend -> '1'   currsch=1
E1 xschem get descend_error -> ''   (no such key; unknown keys are '' too)
E2 after a refusal, statusmsg = 'n=   1 x = 590  y = 675  w = 220 h = 50'
```

Four unrelated causes collapsed into one `'0'`; a fifth (`semaphore != 0`) never entered the
function at all and was also `'0'`. `descend_symbol` returned the empty string for *both*
outcomes, which is why `src/xschem.tcl` inferred success from `[xschem get currsch]` rising.
E2 is 0248 confirmed: a plain `statusmsg()` is already clobbered by `select.c`'s info line.

## What it does AFTER

```
A1 nothing selected   : descend_symbol -> '0'   currsch=0
A2 one instance (OK)  : descend_symbol -> '1'   currsch=1
E1 xschem get descend_error -> 'missing-symbol:no_such_cell_0254.sym'
E2 after a refusal, statusmsg = 'Descend symbol: select an instance to descend into'
E3 after a refusal, statusmsg_hold = '1'
```

## The mechanism

One **per-context** reason channel, recorded ALWAYS and spoken SELECTIVELY.

- `char descend_err[192]` on `Xschem_ctx` (`src/xschem.h`), immediately after
  `statusmsg_text`. Per-context, not a file-scope static, because `open_sub_schematic` and
  `hi_descend_newwin` switch contexts mid-flight. Fixed array — no `_ALLOC_ID_`, no teardown.
- Four named callees in `src/actions.c`: `descend_clear_error()`, `descend_speak_p()` (the
  loud/silent **predicate**, its own function so it can be sabotaged), `descend_speak()` and
  `descend_set_error(code, detail, msg, speak)`. Plus `descend_pick_target()` (0249/0366) and
  `descend_missing_sym()` (0254).
- Exposed as `xschem get descend_error`. Both verbs clear on entry, so a stale reason can
  never be read as a fresh one.
- Speaking is `statusmsg_hold()` **only** — never `dbg(0)`, so the inert-class lock's stderr
  hygiene stays clean. A new dispatcher option `xschem statusmsg -hold <text>` gives the Tcl
  side the same hold discipline (the bare form is byte-identical).

Tokens: `maxdepth`, `busy`, `no-selection`, `no-instance-selected`, `multi-selection`,
`missing-symbol:<name>`, `not-descendable:<type>`, `no-schematic`, `save-cancelled`,
`save-failed`, `iter-cancelled`, `load-failed`.

**`load-failed` is not a refusal** — this issue's own risk note demanded that distinction and
it is honoured: the token is documented at `src/scheduler.c` as meaning *the hierarchy has
ALREADY ADVANCED and the caller must `go_back`*, and must never be read as "nothing happened".

## Decisions

- **D1 [R1] — the reason is a SECOND channel, never a widened result.** Rung R1, landmine 2
  ("never gate / disturb the replay-test seams"): the `"0"`/`"1"` string of `xschem descend`
  is load-bearing at `src/xschem.tcl:3717`, `sky130A/sky130_procs.tcl:148`,
  `ihp-sg13g2/sg13g2_procs.tcl:399`, `utils/cadence_nav.tcl:326`, `tests/buried_hilight.tcl:45`
  (a *string* compare) and three headless tests. `xschem descend` is unchanged.
  - *Rejected:* returning a reason string from `xschem descend` — breaks all seven at once.
- **D2 [R1] — record ALWAYS, speak SELECTIVELY.** 0241 ("a refusal must name what it is
  refusing") settles that a refusal the user asked for must speak; the committed lock
  `tests/headless/test_descend_inert_class.tcl` (262 annotation symbols) settles that pressing
  `e` on a `lab_pin` promised nothing and must stay silent. Recorded at all 13 sites, spoken
  at 8.
  - *Rejected:* "every refusal speaks" — one status line per label/gnd/title-block press, and
    it breaks the lock.
  - Implementation note: the silent sites **compose their message and pass `speak=0`**, rather
    than passing `msg=NULL`. The first cut passed NULL, and sabotage S3 then left the lock
    green — the silence came from a missing string, not from policy. This was corrected so
    `descend_speak_p()` is the single switch, which is what makes D2 falsifiable.
- **D6 [R3] — `xschem descend_symbol` now evaluates to `"1"`/`"0"` instead of the empty
  string** (`src/scheduler.c`: `Tcl_ResetResult` → `Tcl_SetResult(interp, dtoa(ret), …)`), and
  a semaphore-blocked call on either verb records `busy`. **This is the E question.** Every
  in-tree consumer was re-verified safe (`src/xschem.tcl:5963` now genuinely reads it,
  `:13260`/`:14820` are `-command` strings, `src/actions.csv:92` is a csv action, the tests
  invoke it bare). Out-of-tree rc/PDK glue cannot be audited from here.
  - *Rejected:* keeping `ResetResult` and the `currsch`-rise proxy — it cannot report a reason
    and misreads any refusal that leaves `currsch` advanced.
- **D7 [R1] — `hi_descend_finish` drops the `currsch`-rise proxy for the real return value**
  and gains the missing `else` that echoes `[xschem get descend_error]`. R1/0241; and it is a
  local anomaly, not house style — eleven sibling failure arms in the same proc family already
  `ciw_echo`.
  - *Rejected:* keeping both proxy and return as belt-and-braces — dead weight that hides
    which one is authoritative.
- **D10 [R1] — the context-menu action-log wrapper is gated on the verb's return value**
  (`src/callback.c`). Direct generalisation of the ratified "an aborted gesture must not lie
  about the modify flag" (0244/0267/0270): it must not lie in the action log either.
  **Narrowed during implementation**: the gate is `(!verb_refused || logcmd[0] == '#')`,
  because the blanket form suppressed the inert `'# '` marker that
  `tests/headless/test_context_menu_log.tcl` pins. A `'#'` marker is inert commentary about
  what was *picked* — replay skips it, so it cannot lie — while a command line replays and
  must not describe work that never happened.

## Sabotage matrix (Verify-B; `trustworthy = true`)

| # | variant | predicted | observed |
|---|---------|-----------|----------|
| S1 | `descend_set_error` → no-op | 10 red | **13 red** — all 10 + R08/R09/R17 bonus |
| S2 | `descend_speak` → no-op | 3 red | **2 red** (R08, R17); R22 mis-scoped |
| S3 | `descend_speak_p` → `1` | 4 red | **2 red** — 34 inert "silent" rows + R16 |
| S4 | `Tcl_ResetResult` restored | 5 red | **9 red**; R28 lost to an abort |
| S5 | legacy picker macro | 7 red | **5 red**; R05/R06 unmoved (wrong shape) |
| S5b | *added by Verify-B* — true pre-fix rule | — | **8 red** incl. R05, R06 |
| S6 | `descend_missing_sym` → `0` | 4 red | **4 red** + 2 bonus |
| S7 | `newwin_open_ok` → `1` | 2 red | **2 red** |
| S8 | `newwin_descend_failed` → `1` | 3 red | **1 red** (R23); R22/R26 mis-scoped |

**Controls that held.** Under S2 the inert-class stayed 177 ok / 0 FAIL and R16 stayed green;
under S3 every reason-token row stayed green. Record and speak are genuinely separate.

**Predicted reds that did NOT appear — all four causes are honest and named:**

- **S4 / R28 — the one that matters.** R28 never *ran*: S4 makes the 0251 suite abort at line
  315 (`expected boolean value but got ""` in `hi_descend_finish`'s `if {$ok}`), losing R25 and
  R28. The abort exits 0, prints zero FAIL lines and no `OVERALL:` line, so a FAIL-grepping
  harness scores the truncated run GREEN. Filed as **0368**.
- **S3 / R14 — a real (small) coverage hole.** The re-anchored stderr-noise recipe cannot catch
  speak-everything: `descend_speak()` writes only to `statusmsg_hold()`, never to stderr. R14
  verifies C-level stderr hygiene and is worth having, but **R11 and R16 are the only checks
  that cover the loud/silent split.** The plan's claim that R14 covered it was wrong.
- **S3 / R13 — structurally unreachable.** A *successful* descend never calls
  `descend_set_error`, so no `descend_speak_p` sabotage can move R13. It is a stale-channel
  counterweight, not a speak-policy check.
- **S2 & S8 / R22, R26 — mis-scoped.** Both select a lone wire, which refuses *earlier*, at
  `open_sub_schematic`'s target-derivation step, and never reaches `newwin_descend_failed` or
  the C-side `descend_speak()`. Consequence: `newwin_descend_failed` has exactly **one**
  covering row (R23), which is thin for a proc whose failure mode is a leaked window plus a
  bogus success return — see 0371.

## Still open

Verify-C (adversary) **refuted the maximal claim** ("distinguishable at every caller"), so
this item was NOT certified `x`. What survives:

1. **0369 — the refutation. `descend_symbol()` still drops `load_schematic()`'s result**
   (`src/save.c:5686`) and returns 1 unconditionally, so a descend whose load *fails* reports
   `1` with `descend_error={}` — a channel that positively asserts success — and self-logs a
   phantom replayable line. Its sibling `descend_schematic()` got the `load-failed` token **in
   this very fix**. Re-measured independently by the write-up agent; highest-value follow-up.
2. **0370 — `hi_descend_newwin` never got `newwin_open_ok`/`newwin_descend_failed`.** It keeps
   the full-table hijack and the orphan-window-on-refused-descend that this fix closed in
   `open_sub_schematic`. Two procs, one defect, one fixed.
3. **0371 — `newwin_descend_failed` clears the modify flag before an unverified destroy.**
   New surface introduced by this fix; reachable only with `tabbed_interface=0` **and** no X.
4. **0372 / 0373** — the pre-existing teardown defects that make 0371 possible.
5. **The channel does not cross the window boundary.** After a refused `open_sub_schematic`,
   `xschem get descend_error` on the *caller's* context is `{}` — the token was recorded on the
   new window's context, which the teardown then destroyed. Measured. New-window callers get
   the boolean plus a status string, not a machine-readable reason.
6. **`load-failed`'s documented contract is implemented by no in-tree caller.** The `e` key
   drops the value and `hi_descend_finish` only echoes. Measured: `e` on the shipped
   `type=primitive` `devices/single2cm.sym` leaves the user at `currsch=1` on a nonexistent
   `single2cm.sch`. Pre-existing (0250), now *named* but still not repaired.
7. **A held refusal line survives a subsequent SUCCESSFUL descend** for the rest of its 5 s —
   `statusmsg_hold` has no success-side release. And refusals now fire on very common
   accidents (`e`/`i` with nothing selected), each holding the status bar for 5 s and
   suppressing ordinary `statusmsg()` in that window. 0248 accepted this frequency for gate
   messages; descend refusals are a much higher-rate source.
8. **`xschem statusmsg -hold` is a new positional option**, so a caller passing the literal
   text `-hold` gets a blank held line. Measured: `bare -hold: { } hold=1`.
9. **`descend_missing_sym()` dereferences `(xctx->inst[n].ptr + xctx->sym)->type` with no
   `ptr >= 0` guard.** `rebuild_selected_array()` guards `inst[i].ptr >= 0` elsewhere, so a
   negative ptr is considered reachable here. Pre-existing shape, but this fix moved the deref
   onto both verbs' hot path.
10. **The two verbs still disagree** on identical state (0249 C1). Answered by speaking, not
    by unifying — a deliberate R2 call, still a latent surprise.

## What the adversary FAILED to break

0366 one level deeper; the picker's bounds (no stale-`lastsel` or out-of-bounds `inst[]`);
the `INST_PIN` rule; the loud/silent split (`descend` on `lab_pin.sym` → `0`,
`not-descendable:label`, status bar untouched, `hold=0`); and both forbidden shapes — no pure
commit-coordinate form is gated, and no gate was placed at a shared per-click primitive
(`descend_pick_target`/`descend_missing_sym` are called only from the two verbs).
