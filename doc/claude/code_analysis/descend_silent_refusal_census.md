# Descending the hierarchy: a census of silent refusals

The question was a user report shaped like a guess — *"descend refuses when more than one
thing is selected, and it doesn't say so"*. Answering it needed a sweep rather than a patch,
because "descend" is not one function: six lenses were read independently — `descend_schematic()`
(`src/actions.c:3575`), `descend_symbol()` (`src/save.c:5546`), the `xschem` dispatcher branches
that reach them (`src/scheduler.c:2968` / `:3015`), the event layer that reaches *those*
(`src/callback.c` keys + context menu, `src/xschem.tcl` bindings and the `hi_descend` chooser),
the selection rules that decide what a descend even acts on (`rebuild_selected_array()`,
`src/move.c:53`), and the load-failure tail that runs *after* the guards have all passed
(`load_schematic()`, `src/save.c:3737` call site). Every claim each lens produced was then handed
to an independent verifier prompted to refute it; about 25 of the initial claims died there.
The one-sentence answer: **the guess is half right — `descend_symbol` really does refuse any
multi-object selection in silence, `descend_schematic` does not refuse it at all but quietly
picks a different instance than the user clicked, and the silence is not one bug but a
structural property of the descend family, which has thirteen refusal sites and no return
channel by which any of them could speak.**

## The question that started it: is it multiple selection?

Half right, and the two verbs disagree with each other.

**`descend_symbol` DOES refuse any multi-object selection, silently** —
`src/save.c:5562-5563`:

```c
  rebuild_selected_array();
  if(xctx->lastsel > 1)  return 0;
```

No `alert_`, no `statusmsg`, no `ciw_echo`, not even a `dbg()`. The function is `int` but
`descend_symbol()`'s only two callers (`src/scheduler.c:3033`, `src/callback.c:4519`,
`src/callback.c:6590`) discard the value; the scheduler branch even calls
`Tcl_ResetResult(interp)` right after (`:3035`), so `xschem descend_symbol` returns the empty
string whether it worked or not. → issue [0249](../issues/0249-descend-symbol-silently-refuses-any-multi-selection.md).

**`descend_schematic` does NOT refuse it** — the same test is commented out at
`src/actions.c:3589-3593`:

```c
 rebuild_selected_array();
 if(/* xctx->lastsel !=1 || */ xctx->sel_array[0].type!=ELEMENT) {
   dbg(1, "descend_schematic(): wrong selection\n");
   return 0;
 }
```

It descends into `sel_array[0]`, taken at `src/actions.c:3610` (`n = xctx->sel_array[0].n`).
`sel_array` is rebuilt in **array order**, not click order (`src/move.c:69-76` walks
`for(i=0;i<xctx->instances;++i)`), so `sel_array[0]` is the **lowest instance index in file
order** — not the instance the user clicked first. `xctx->first_sel` exists and records the
first-selected object, but `descend_schematic` never consults it.

The comment-out was deliberate, not an accident: the live twin of the disabled test still
stands in `symbol_in_new_window()` at `src/actions.c:2799`
(`if(xctx->lastsel !=1 || xctx->sel_array[0].type!=ELEMENT)`), and again in
`schematic_in_new_window()` at `:2918` (`else if(xctx->lastsel > 1) return 0;`).

Measured, headless, against a two-instance parent (`x1` at file index 0, `x2` at index 1):

```
--- A: two instances selected, xschem descend ---
before: currsch=0 name=census_parent.sch path=. lastsel=2
descend returns: 1
after: currsch=1 name=descend_child.sch path=.x1. lastsel=0

--- B: two instances selected, xschem descend_symbol ---
before: currsch=0 name=census_parent.sch path=. lastsel=2
descend_symbol returns: ''
after: currsch=0 name=census_parent.sch path=. lastsel=2
```

and, selecting `x2` **first** and `x1` second:

```
--- E: first_sel vs sel_array[0] ---
first_sel = 8 1 0   (type 8 = ELEMENT, n = instance index)
instance_list order: x1 x2
descend returns: 1
after: currsch=1 name=descend_child.sch path=.x1.
```

`first_sel` says instance **1** (`x2`, the one clicked first); the descend went to `.x1.`.
Nothing was printed on stderr in either run. The same fixture also settles the co-selection
asymmetry, because `rebuild_selected_array()` emits texts *before* instances
(`src/move.c:61-68` then `:69-76`) and wires *after* (`:94-101`):

```
--- C: one instance + one text selected, xschem descend ---
descend returns: 0        (sel_array[0].type == xTEXT -> the guard fires)
--- D: one instance + one wire selected, xschem descend ---
descend returns: 1        (sel_array[0].type == ELEMENT -> descends)
```

A text co-selected with an instance blocks the descend; a wire does not, and neither says
anything. → issue [0255](../issues/0255-an-instance-co-selected-with-a-text-silently-blocks-descend.md).

## How a descend is actually reached

Four assumptions a reader is likely to hold, all wrong:

| assumption | what the tree actually says |
| --- | --- |
| plain `e` is the C descend | No. `src/xschem.tcl:14175` binds `<Key-$hi_descend_key>` (default `e`, set at `:5746`) to `hi_descend_keybind_script` (`:6271-6273`), which forwards to the C dispatcher **only** when `%s & 0x4c` (Control\|Mod1\|Mod4) and otherwise runs the Tcl chooser `hi_descend`. A more-specific Tk binding pre-empts the generic `<KeyPress>`, so the C `case 'e'` plain arm is shadowed in a stock GUI. |
| descend-symbol is Shift-E | No. It is key **`i`** — `src/callback.c:6587-6591`, `if(rstate==0) { if(xctx->semaphore >= 2) break; descend_symbol(); }` — and the menu accelerator is `I` (`src/xschem.tcl:14726`). `case 'E'` (`src/callback.c:6468-6475`) has **only** an `EQUAL_MODMASK` arm (Alt/Super → `schematic_in_new_window(1,1,0,0)`); plain Shift+E falls out of the switch. |
| double-clicking an instance descends | No. There is no descend in the double-click handler; it does selection-grow or `edit_property`. |
| the Tcl routes and the C routes behave alike | No. **Every** Tcl-driven descend hardcodes `fallback=0, alert=0`: `src/scheduler.c:2993`, `:3000`, `:3002` all call `descend_schematic(n, 0, 0, set_title)`. Only two sites pass `alert=1`, both in C: the right-click context menu (`src/callback.c:4510` case 12 and `:4513` case 22, both `descend_schematic(0, 1, 1, 1)`) and the raw key handler (`src/callback.c:6453`). Since `alert` is what gates `load_schematic`'s only user-visible failure message (`src/save.c:3813-3818`), a scripted, menu-driven or chooser-driven descend that fails to load **cannot** report it. |

The chooser adds a second, parallel dispatch: `hi_descend` (`src/xschem.tcl:6043`) →
`hi_descend_do` (`:6000`) → `hi_descend_current` (`:5906`) / `hi_descend_newwin` (`:5918`) →
`hi_descend_finish` (`:5865`), which calls `xschem descend $iter` or `xschem descend_symbol`.
So the C guards are reached through Tcl code that is itself full of guards, and the two layers
were written to different conventions — Tcl echoes to the CIW, C returns an int nobody reads.

## The inventory

`silent` = nothing reaches the user by any channel; `dbg-only` = reaches stderr for a
terminal-launched session only (see the visibility rule below); `message` = `alert_`,
`tk_messageBox`, `statusmsg*`, `ciw_echo` or a `TCL_ERROR`.

Ranked within the silent block by how likely a user is to walk into it.

| # | site | guard | class | issue |
| --- | --- | --- | --- | --- |
| 1 | `src/save.c:5563` | `if(xctx->lastsel > 1) return 0;` | silent | [0249](../issues/0249-descend-symbol-silently-refuses-any-multi-selection.md) |
| 2 | `src/actions.c:3590` | `sel_array[0].type != ELEMENT` — a co-selected **text** sorts to index 0 | silent (`dbg(1)`) | [0255](../issues/0255-an-instance-co-selected-with-a-text-silently-blocks-descend.md) |
| 3 | `src/actions.c:3620-3624` | `type && strcmp(type,"subcircuit") && strcmp(type,"primitive")` — refuses a typed non-subcircuit **and** a symbol with no `type=` token, because `set_sym_flags()` fills `sym->type` with `my_strdup2` of `get_tok_value(...,"type",0)` (`src/actions.c:901-902`), i.e. `""`, not `NULL` | silent | [0252](../issues/0252-non-subcircuit-symbols-refused-silently-after-the-chooser-offered-the-view.md) |
| 4 | `src/actions.c:3737` + `:3731` | `currsch++` happens **before** `load_schematic(1, filename, set_title&1, alert)`; on failure with `alert=0` the window is left one level down on a cleared page | silent | [0250](../issues/0250-failed-descend-strands-the-window-on-a-blank-child-page.md) |
| 5 | `src/scheduler.c:3033`/`:3035`, `src/callback.c:4519`, `:6590` | `descend_symbol()`'s `int` return discarded at every call site; `Tcl_ResetResult` erases even the possibility | silent | [0251](../issues/0251-a-refused-descend-has-no-return-channel.md) |
| 6 | `src/save.c:5589` | `!strcmp(sym->type,"missing")` — the missing-symbol placeholder | silent | [0254](../issues/0254-descend-symbol-on-a-missing-symbol-placeholder-is-silent.md) |
| 7 | `src/save.c:5594` | trailing `else return 0;` — nothing selected, or the one selection is not an `ELEMENT` | silent | [0249](../issues/0249-descend-symbol-silently-refuses-any-multi-selection.md) / [0251](../issues/0251-a-refused-descend-has-no-return-channel.md) |
| 8 | `src/callback.c:8043-8046` | net-highlight mode `return`s before `check_menu_start_commands()` (`:8075`), so an armed `MENUSTARTDESCEND` pick never sees the click and the matching release clears `MENUSTART` at `:8597-8600` | silent | [0257](../issues/0257-net-highlight-mode-swallows-the-armed-descend-pick.md) |
| 9 | `src/xschem.tcl:5685` | `open_sub_schematic`: with 2+ selected, `$inst` is `{}`, `lsearch` misses, `return 0` | silent | [0256](../issues/0256-open-sub-schematic-dead-with-multi-selection-and-discards-the-result.md) |
| 10 | `src/xschem.tcl:5710` | same proc: `xschem descend`'s result is thrown away and `return 1` (`:5717`) follows unconditionally | silent | [0256](../issues/0256-open-sub-schematic-dead-with-multi-selection-and-discards-the-result.md) |
| 11 | `src/actions.c:2810-2813` | `symbol_in_new_window`: `if(!check_loaded(filename, win_path))` … and nothing at all in the `else` — `win_path` is filled and dropped | silent | [0258](../issues/0258-symbol-in-new-window-discards-win-path-when-the-sym-is-already-open.md) |
| 12 | `utils/cadence_nav.tcl:237`, `:244`, `:258` | `if {![cadence::one_instance_selected]} { return }` — bare `return`, while the same file carries 25 `ciw_echo` calls elsewhere | silent | [0259](../issues/0259-cadence-nav-descend-procs-bail-with-no-echo.md) |
| 13 | `src/xschem.tcl:6169` (and `:6067`) | `if {$instname eq {}} { cmdmode::resume_all; return 0 }` | silent | [0260](../issues/0260-hi-descend-dialog-returns-zero-for-an-instance-with-no-name-token.md) |
| 14 | `src/xschem.tcl:6044` vs `src/scheduler.c:2973`/`:3018` | Tcl refuses at `semaphore >= 2`, C at `semaphore != 0` — the band `semaphore == 1` is accepted by one and refused by the other, and the refused C branch still returns `"0"`, which reads as "descended into a blank schematic" | silent | [0253](../issues/0253-descend-semaphore-thresholds-disagree-and-a-zero-is-misread.md) |
| 15 | `src/save.c:3801-3808`, `:3858-3874`; `src/actions.c:3737`; `src/save.c:5643`/`:5669` | the *inverse* case: descend returns **1** having loaded nothing (generator produced no output, empty `.sch`, `tcleval`-emptied reference) | silent, and mislabelled as success | [0261](../issues/0261-descend-reports-success-on-a-blank-page.md) |
| 16 | pre-existing | a stale `sel_array[0]` makes `descend` return 1 with nothing actually selected | silent | [0203](../issues/0203-stale-sel_array-descends-a-deselected-instance.md) (do not refile) |

For contrast, the sites that **do** speak:

| site | channel |
| --- | --- |
| `src/save.c:3813-3818` | `fprintf(errfp, …)` **and** `alert_ {Unable to open file: …}` — but only under `if(alert)`, which only `src/callback.c:4510`/`:4513`/`:6453` ever set |
| `src/actions.c:3470` | `ask_save {Schematic …\ndoes not exist.\nDescend into base schematic?}` — the `get_sch_from_sym` fallback prompt, gated on `has_x && fallback`, and `fallback=0` on every Tcl route |
| `src/actions.c:3602-3605` | `save_file_dialog {Save file}` before descending out of an unnamed schematic; an empty result is a clean cancel |
| `src/actions.c:3654-3662` | `input_line {input instance number …}` for a vector instance; an empty result cancels |
| `src/scheduler.c:2982`, `:2988`, `:3022`, `:3027` | the four `-inst` `TCL_ERROR`s — "instance name required" / "instance not found". These are the **only** loud refusals on the whole `xschem descend*` command surface, and they cover argument errors, not descend refusals |
| `src/callback.c:3729-3734` | the verb-noun pick terminals: `statusmsg(" ", 1)` on a hit, `statusmsg_hold("Descend: cancelled (no instance there)", 1)` on a miss |
| `src/xschem.tcl:5761`, `:5771`, `:5871`, `:5910`, `:5950`, `:6010`, `:6015`, `:6028`, `:6038`, `:6057`, `:6062`, `:6065`, `:6106`, `:6125`, `:6148`, `:6179` | the `ciw_echo "hi_descend: …"` family — sixteen call sites. The chooser is by far the best-behaved layer, which is exactly why its two silent holes (rows 13, and the unreported `hi_descend_finish` 0) stand out |
| `src/xinit.c:1975-1979`, `:2124-2128` | `tk_messageBox … already open.` — the already-open modal. Note it lives in `new_schematic`, *not* in `check_loaded`, and it is suppressed whenever the caller passes a non-empty `noconfirm` (`"noalert"`) |

## The `dbg()` visibility rule

Several classifications above turn on this, so it is stated once and precisely.

- `src/globals.c:166` — `int debug_var=-10;  /* will be set to 0 in xinit.c */`
- `src/xinit.c:3364` — `if(debug_var==-10) debug_var=0;`
- `src/util.c:265-273` — `void dbg(int level, char *fmt, ...) { if(debug_var>=level) { … vfprintf(errfp, fmt, args); … } }`
- `src/main.c:91` — `errfp=stderr;` (overridable to a file by `-l` / `options.c:131`, and by `xschem debug` at `src/scheduler.c:7343`)

So at the default level `debug_var == 0`:

- **`dbg(0, …)` prints.** It reaches `stderr`, which a **terminal-launched** session shows and a
  **desktop/launcher-launched** session discards. Half the user base sees it, half does not, and
  the half that does sees it in a window they may not be looking at.
- **`dbg(1, …)` never prints** at the default level. It is invisible to everyone.

Hence `src/actions.c:3591` (`dbg(1, "descend_schematic(): wrong selection\n")`) is classified
**silent**, while `src/actions.c:3586` and `src/save.c:5558` (the `CADMAXHIER` guards, both
`dbg(0)`) are classified **dbg-only** and were not filed — a depth-1000 hierarchy is not a
realistic user path, and it does at least print.

## What was refuted

The verifiers killed roughly 25 candidate findings. The instructive ones, so nobody refiles them:

- **`src/actions.c:3405-3407`, `inst >= xctx->instances`.** Unreachable from either descend —
  `descend_schematic` passes `n = sel_array[0].n`, which `rebuild_selected_array` produced by
  walking `xctx->inst[]`, so it is in range by construction — and the guard prints `dbg(0, …)`
  anyway. *Verified.*
- **`src/actions.c:3410-3413`, `!sym`.** Dead code. Callers pass `xctx->inst[n].ptr + xctx->sym`
  — base-plus-index pointer arithmetic, never `NULL`; the value that actually signals "no symbol"
  is `ptr == -1` (which this guard would not catch, and which `schematic_in_new_window:2922`
  *does* test). Its own `dbg` call is malformed — `dbg(0, "get_sch_from_sym() error: called with
  NULL sym", inst)` passes an argument with no conversion in the format — which is proof it has
  never fired, since it would be a compiler-visible mismatch anyone triggering it would have hit.
  *Verified.*
- **`src/scheduler.c:10617` `schematic_in_new_window`.** Not a silent-refusal site: the
  nothing-selected arm (`src/actions.c:2902-2917`) opens a duplicate of the current schematic and
  returns **1**, and the already-open arm falls through `if(force || !check_loaded(...))` to
  `return 1` at `:2941`. *Verified — with one correction:* the already-open **modal** does not
  live here. It is in `new_schematic` (`src/xinit.c:1975`, `:2124`) and every call
  `schematic_in_new_window` makes on that path passes `"noalert"`, so it does not fire. The one
  arm that does return 0 in silence is `lastsel > 1` at `src/actions.c:2918-2920`, and its only
  Tcl caller (`open_sub_schematic`) already refuses earlier — that refusal is filed as 0256.
- **`src/callback.c:6468` `case 'E'`.** An unbound chord, not a refusal: the only arm is
  `EQUAL_MODMASK`, so plain Shift+E simply does nothing. *Verified.*
- **`src/xschem.tcl:12599` the context-menu `$selection` gate.** `set selection [expr {[xschem
  get lastsel] > 0}]` inside `proc context_menu` (`:12590`) decides which *buttons to build*.
  Menu construction, not a refusal. *Verified.*
- **`src/move.c:81` a pins-only selection.** The `pin_sel` loop emits `INST_PIN` rows without an
  `ELEMENT` row (comment at `:77-80`), so `xschem selected_set` comes back empty — which makes
  `hi_descend_dialog` take its `llength == 0` branch (`src/xschem.tcl:6167`) and **arm the pick**,
  prompting "click the instance to descend into". Not silent. *Verified by reading; the pick
  itself was not driven headless here.*
- **The routing family `src/callback.c:7925 / 7928 / 7993 / 8003 / 8052 / 8442`** — cross-window
  guard, waveform routing, Alt-click unselect, the `semaphore >= 2` legacy-dialog arm, deselect
  mode, and the Button3 context-menu arm. In each, an armed `MENUSTARTDESCEND` is *deferred*
  rather than cleared, and both pick terminals speak (`src/callback.c:3729-3734`). **Not
  verified, and I disagree with one member of the list:** `src/callback.c:8058` (the
  `persistent_command` wire arm) `return`s at `:8072` before `check_menu_start_commands()` at
  `:8075` on exactly the same reading that makes `:8043` a defect, and 0257's own Risks section
  lists it as an unmeasured sibling swallow rather than a refutation. Treat 8058 as open.

## Open disagreements

Recorded so a later reader does not mistake any of these for settled.

1. **Is `src/callback.c:6452` reachable?** `case 'e'` / `if(xctx->semaphore >= 2) break;` is a
   real, message-free refusal, but in a stock GUI the Tk binding at `src/xschem.tcl:14175`
   pre-empts the generic `<KeyPress>` for the plain key, so the arm may never run from a
   keyboard. It *is* reachable via `xschem callback <win> <type> <x> <y> 101 …` (tests and
   action-log replay) and by remapping `hi_descend_key` away from `e` (`hi_descend_set_key`,
   `src/xschem.tcl:6278`), which restores the old key to C dispatch. The twin at
   `src/callback.c:6589` (`case 'i'`) is **not** shadowed by any Tk binding and is plainly live.
2. **Does a discarded return value count as a refusal *site*?** One reading says the sites are
   the guards themselves (`src/save.c:5563`, `:5589`, `:5594`) and the discards
   (`src/scheduler.c:3033`/`:3035`) are merely why they are silent; the other says the missing
   protocol is the defect and the guards are incidental. Filed as
   [0251](../issues/0251-a-refused-descend-has-no-return-channel.md) either way, because the fix
   is the same in both readings: give the descend verbs a status and make the callers read it.
3. **Which upstream causes can actually reach `hi_descend_finish`'s unreported 0?**
   `hi_descend_current` (`src/xschem.tcl:5906-5913`) does `xschem unselect_all` then
   `xschem select instance $instname fast` immediately before calling it, so the selection-shaped
   causes (rows 1, 2, 7, 16 of the inventory) are pre-empted on that path — leaving the type
   guard, the missing-symbol guard, the load failure and the semaphore band as the plausible
   sources. Nobody enumerated them exhaustively.

## Method note

Six finder lenses were run in parallel over the descend surface; every path each one claimed was
silent was then handed to an independent verifier prompted to **refute** it rather than confirm
it, with access to the same tree. Roughly 25 of the initial claims did not survive that step —
including several that looked like textbook silent refusals and turned out to be dead code,
unbound chords, menu construction, or paths that do in fact prompt. The claims that survived
became the thirteen issues below. Line numbers throughout were re-checked against the working
tree at filing time (2026-08-08, branch `open_pdk`); they will drift, and the function names and
quoted source are the durable part of every reference. The measured transcripts were produced
with `./src/xschem --nogui --pipe -q --nolog --script …` against a two-instance fixture built for
this sweep; `--nogui` means the alert/modal halves of every claim are read from the code rather
than clicked, and each issue says so in its own Status line.

## Filed issues

- [0249](../issues/0249-descend-symbol-silently-refuses-any-multi-selection.md) — `descend_symbol` refuses any multi-object selection with zero feedback
- [0250](../issues/0250-failed-descend-strands-the-window-on-a-blank-child-page.md) — a descend whose load fails with `alert=0` leaves the window on a blank page one level down
- [0251](../issues/0251-a-refused-descend-has-no-return-channel.md) — a refused descend is indistinguishable from a successful one at every caller
- [0252](../issues/0252-non-subcircuit-symbols-refused-silently-after-the-chooser-offered-the-view.md) — the descend chooser offers a schematic view for symbols the C guard will refuse
- [0253](../issues/0253-descend-semaphore-thresholds-disagree-and-a-zero-is-misread.md) — the descend re-entrancy threshold differs between Tcl and C, and the resulting 0 is misread as a blank schematic
- [0254](../issues/0254-descend-symbol-on-a-missing-symbol-placeholder-is-silent.md) — `descend_symbol` on a missing-symbol placeholder does nothing and says nothing
- [0255](../issues/0255-an-instance-co-selected-with-a-text-silently-blocks-descend.md) — a text co-selected with an instance blocks `descend_schematic`; a wire does not
- [0256](../issues/0256-open-sub-schematic-dead-with-multi-selection-and-discards-the-result.md) — `open_sub_schematic` is a no-op with 2+ objects selected and ignores the descend it just asked for
- [0257](../issues/0257-net-highlight-mode-swallows-the-armed-descend-pick.md) — net-highlight mode eats the armed descend pick and strands `MENUSTARTDESCEND`
- [0258](../issues/0258-symbol-in-new-window-discards-win-path-when-the-sym-is-already-open.md) — `symbol_in_new_window` silently does nothing when the target `.sym` is already open
- [0259](../issues/0259-cadence-nav-descend-procs-bail-with-no-echo.md) — the `cadence_nav` descend procs refuse without the `ciw_echo` every sibling proc gives
- [0260](../issues/0260-hi-descend-dialog-returns-zero-for-an-instance-with-no-name-token.md) — the descend chooser silently gives up on an instance whose symbol carries no `name=` token
- [0261](../issues/0261-descend-reports-success-on-a-blank-page.md) — three descend paths return success while landing the user on a blank or fabricated page

Not refiled, cross-referenced only: [0203](../issues/0203-stale-sel_array-descends-a-deselected-instance.md)
(a stale `sel_array[0]` descends a deselected instance — the reason `descend`'s `1` is as
untrustworthy as its `0`), [0232](../issues/0232-missing-symbol-substitution-silently-unnames-nets.md)
(the missing-symbol substitution behind row 6), [0200](../issues/0200-descend-has-no-verb-noun-pick.md)
(verb-noun pick, RESOLVED — it is what 0257 breaks), and the descend/new-window family
[0035](../issues/0035-descended-new-window-spuriously-modified.md) /
[0037](../issues/0037-newwin-descend-desync-and-exit-confusion.md) /
[0053](../issues/0053-descend-new-window-return-should-navigate-window-chain.md) /
[0054](../issues/0054-descend-return-context-pointer-desync.md) /
[0060](../issues/0060-descend-from-untitled-loses-parent-content-on-ascend.md) /
[0073](../issues/0073-hilight-not-synced-into-linked-descend-new-window.md), plus
[0248](../issues/0248-gate-and-prompt-statusbar-messages-are-wiped-by-the-coordinate-readout.md)
— which any statusbar-based cure proposed by these issues must survive.
