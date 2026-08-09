# 0257 — net-highlight mode eats the armed descend pick and strands MENUSTARTDESCEND

Status: **OPEN** — measured end to end (four transcripts below). The swallow, the arm being
burned by the matching ButtonRelease, the stale `MENUSTARTDESCEND` left in `ui_state2`, the
permanently latched `cmdmode::suspend_all`, and the loss of the on-screen prompt are all
reproduced. **Not** measured: the sibling swallow through the `persistent_command` wire arm
(`src/callback.c:8058`) — see Risks.
Area: `src/callback.c` `handle_button_press()` net-hilight arm (`:8043-8046`), the *only*
`check_menu_start_commands()` call site (`:8075`), the release-time `MENUSTART` clear in
`handle_button_release()` (`:8597-8600`), the pick arm in `check_menu_start_commands()`
(`:3710-3737`), the ESC continuation in `abort_operation()` (`:344-352`),
`net_hilight_mode_click()` (`:454-479`); `xschem descend_pick` (`src/scheduler.c:3046-3053`);
`net_hilight_interactive()` (`src/scheduler.c:5754-5785`); `hi_descend_pick_arm`
(`src/xschem.tcl:6104-6127`)
Tests: none. `tests/headless/test_verb_noun_descend_0200.tcl` and
`tests/headless/test_cmdmode_descend_0201.tcl` both exercise the pick with **no other mode
live**; nothing under `tests/` drives `hilight_net_interactive` /
`unhilight_net_interactive` at all. Proposed
`tests/headless/test_descend_pick_mode_clash_0257.tcl`.
Found: 2026-08-08, in the descend silent-refusal census
(`doc/claude/code_analysis/descend_silent_refusal_census.md`)
Related: [0200](0200-descend-has-no-verb-noun-pick.md) (the feature this breaks; its
"Prior art" section already names `NET_HILIGHT`/`NET_UNHILIGHT`/`DESEL_MODE` as a separate
verb-noun *family* but never checks the two families against each other),
[0201](0201-no-command-suspend-resume-contract.md) (the suspend/resume contract that this
strands), [0202](0202-canvas-gesture-seize-has-no-stack.md) (canvas Button-1 is a single
ownership slot with no stack — this is the concrete, measured symptom that issue predicted
and could not previously reproduce), [0248](0248-gate-and-prompt-statusbar-messages-are-wiped-by-the-coordinate-readout.md)
(the prompt disappears one event after the press).

## The defect

`Button1` press dispatch in `handle_button_press()` runs the persistent click-loop modes
**before** the one-shot `MENUSTART` arms, and each mode `return`s:

```c
src/callback.c:8041-8046
     /* interactive net-(un)highlight mode: a click acts on the net under the cursor
      * and stays in the mode until ESC (no normal selection happens) */
     if(xctx->ui_state & (NET_HILIGHT | NET_UNHILIGHT)) {
       net_hilight_mode_click((xctx->ui_state & NET_HILIGHT) ? 1 : 0);
       return;
     }
```

`check_menu_start_commands()` is 29 lines further down:

```c
src/callback.c:8074-8075
     /* handle all object insertions started from Tools/Edit menu */
     if(check_menu_start_commands(state, c_snap, mx, my)) return;
```

and `:8075` is its **only** call site in the tree (`grep -n check_menu_start_commands src/`
returns one definition at `:3695`, one call at `:8075`, and comments). So while
`NET_HILIGHT` or `NET_UNHILIGHT` is set there is no path by which the verb-noun descend
pick of [0200](0200-descend-has-no-verb-noun-pick.md) can ever be redeemed.

**Nothing prevents the two from being armed together.** `xschem descend_pick` has no mode
guard at all:

```c
src/scheduler.c:3046-3053
    else if(!strcmp(argv[1], "descend_pick"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      xctx->ui_state |= MENUSTART;
      xctx->ui_state2 = MENUSTARTDESCEND; /* assign, like every other arming site */
      statusmsg_hold("Descend: click the instance to descend into (ESC to cancel)", 1);
      Tcl_ResetResult(interp);
    }
```

and `net_hilight_interactive()` enters its mode with a bare `|=`
(`src/scheduler.c:5776-5777`), equally blind. The bits live in different words —
`MENUSTART` is `ui_state` bit 16 (`65536`, `src/xschem.h:249`), `NET_HILIGHT` is `ui_state`
bit 20 (`1048576`, `:254`), and `MENUSTARTDESCEND` is `32768` in the **separate** `ui_state2`
word (`:288`) — so `ui_state == 1114112` with `ui_state2 == 32768` is a perfectly
representable, and measured, state.

**This is the default outcome inside the mode, not a corner case.** `hi_descend` only arms
the pick when the selection is empty (`src/xschem.tcl:6167`), and the highlight mode is
deliberately transient: `net_hilight_mode_click()` ends with `unselect_all(0)` on the add
path (`src/callback.c:473`) and `unhilight_net(0)` → `unselect_all(1)`
(`src/hilight.c`, last line of `unhilight_net`) on the remove path. Inside the mode
*nothing can stay selected*, so `E` always takes the arm branch, and the arm is always
swallowed. Descend-by-instance is simply unreachable from the keyboard while the mode runs.

### What actually destroys the arm

The brief for this census entry attributed the arm's death to `unselect_all()`'s
`xctx->ui_state = 0` (`src/select.c:1261`). That contributes on the net-hit path, but it is
**not** the mechanism, and correcting this matters for the fix: the arm dies on **every**
click in the mode, including one on a plain device body where `net_hilight_mode_click()`
returns having touched nothing (`src/callback.c:462-467`). The killer is the matching
ButtonRelease:

```c
src/callback.c:8596-8600
   /* clear start from menu flag or infix_interface=0 start commands */
   if( state == Button1Mask && xctx->ui_state & MENUSTART) {
     xctx->ui_state &= ~MENUSTART;
     return;
   }
```

That is unconditional — it does not care whether the press was consumed. So the sequence is:

1. **press** — swallowed at `:8043`; `MENUSTART|MENUSTARTDESCEND` still intact.
2. **release** — `:8598` clears `MENUSTART`. `ui_state2` is untouched.
3. state is now `MENUSTARTDESCEND` set with `MENUSTART` clear — a combination **no** reader
   tests. Both the pick arm (`:3710`) and the ESC continuation (`:344`) are guarded on
   `(ui_state & MENUSTART) && (ui_state2 & MENUSTARTDESCEND)`, so both are dead.

Step 3 is why this is more than a lost click. `hi_descend_pick_arm` suspends the
interrupted command mode *before* arming, and the only three resume terminals are
`hi_descend_do`, `hi_descend_dialog` and `hi_descend_pick_cancel`
(`src/xschem.tcl:6109-6127`):

```tcl
src/xschem.tcl:6123-6126
  cmdmode::suspend_all
  xschem descend_pick
  ciw_echo "hi_descend: click the instance to descend into (ESC to cancel)"
  return 1
```

None of them can now be reached: the pick will never fire, and ESC — the documented escape
hatch, added by 0201 precisely so no suspend is left dangling — is gated behind the
`MENUSTART` bit that the release just cleared. `cmdmode::is_suspended` stays `1` for the
rest of the session (measured below). Whatever released Button-1 to make the pick possible
(ASE Direct Plot's seize, Add-Pin's / Add-Label's ESC grab) never gets its bindings back.

### What the user sees

Nothing that names the problem. The refusal is silent by the census definition: no
`alert_`, no `tk_messageBox`, no `statusmsg`, no `ciw_echo`, not even a `dbg(0, …)` line on
stderr. The two visible cues both mislead:

- `.statusbar.10` still reads `HIGHLIGHT NET! (click a net or label, ESC to end) `
  (`src/callback.c:8743-8744`), i.e. the editor claims to be in the mode the user is in —
  correct, and no hint that a descend was pending.
- `.statusbar.1` carried the descend prompt, and loses it one event after the press. The
  hold is released at `src/callback.c:8990` (`if(event == ButtonPress) statusmsg_hold_clear();`),
  which by itself only drops the *deadline*, not the text; the coordinate readout at
  `:8981-8984` then overwrites the field on the very next event — measured as the matching
  ButtonRelease, because `mx_save` is not refreshed by the swallowed press. See
  [0248](0248-gate-and-prompt-statusbar-messages-are-wiped-by-the-coordinate-readout.md).

The `ciw_echo` line from `:6125` survives, but the CIW is a scrolling log, not a state
readout: it will still say "click the instance to descend into" long after the pick is
unrecoverable.

`DESEL_MODE` has the identical shape 6 lines below (`src/callback.c:8052-8055`) and is
measured below as the same defect.

## Reproduce

Driven through the real click dispatch with `xschem callback`, which needs Tk — so these
run under `$DISPLAY` via the GUI gate, not `--nogui`. Under `--nogui` `xschem callback`
segfaults (`FATAL: signal 11`), which is a separate pre-existing hazard and not this issue.
Fixture: `xschem_library/examples/0_examples_top.sch`, instance `x1` (`subcircuit`);
`hi_descend_enum_views` stubbed to record which instance was resolved and bail one line
before the modal dialog, exactly as `tests/headless/test_verb_noun_descend_0200.tcl` does.

**T1 — control vs. defect, press and release separated**

```
== CONTROL: no net-highlight mode -- the pick works ==
  armed                 : ui_state=65536 ui_state2=32768
  after PRESS           : ui_state=0 ui_state2=0   resolved='x1'
  after RELEASE         : ui_state=0 ui_state2=0   resolved='x1'

== DEFECT: net-highlight mode armed too -- press is swallowed, release burns the arm ==
  armed                 : ui_state=1114112 ui_state2=32768
  after PRESS           : ui_state=1114112 ui_state2=32768   resolved=''  (MENUSTART survives the press)
  after RELEASE         : ui_state=1048576 ui_state2=32768   resolved=''
  MENUSTART set?        : 0
  MENUSTARTDESCEND set? : 1
  after ESC             : ui_state=0 ui_state2=32768   pick_cancel fired = 0
```

`1114112 = MENUSTART(65536) | NET_HILIGHT(1048576)`. The press leaves both arms intact and
resolves nothing; the release drops `MENUSTART` and leaves `ui_state2=32768` behind; ESC
then reaches the blanket `ui_state = 0` (`src/callback.c:445`) without ever entering the
descend branch, so `hi_descend_pick_cancel` never runs and `ui_state2` stays `32768`
forever.

**T2 — the real GUI sequence (`9`, then `E`), and the stranded suspend**

```
== the real GUI path: hi_descend (verb) with nothing selected, in net-highlight mode ==
  net-highlight mode on : ui_state=1048576 ui_state2=0 cmdmode::is_suspended=0
  hi_descend returned   : 1
  armed                 : ui_state=1114112 ui_state2=32768 cmdmode::is_suspended=1
  after the click       : ui_state=1048576 ui_state2=32768 cmdmode::is_suspended=1
  resolved              : ''
  after ESC             : ui_state=0 ui_state2=32768 cmdmode::is_suspended=1
```

`hi_descend` returns 1 ("armed"), so the Tcl side believes a pick is pending; `is_suspended`
never returns to 0. This is the 0201 stranding, arrived at through a door 0201 did not close.

**T3 — the prompt the user was told to act on**

```
== the prompt the user is told to act on ==
  armed                    statusbar.1={Descend: click the instance to descend into (ESC to cancel)} hold=1
  after PRESS              statusbar.1={Descend: click the instance to descend into (ESC to cancel)} hold=0
  after RELEASE            statusbar.1={mouse = 170 -190 - selected: 0 path: .} hold=0
  after one mouse flick    statusbar.1={mouse = 240 -110 - selected: 0 w=240 h=-110} hold=0
  resolved = ''
```

**T4 — the `DESEL_MODE` sibling (`src/callback.c:8052-8055`)**

```
== sibling: DESEL_MODE (callback.c:8053-8056) swallows the same pick ==
  deselect mode on : ui_state=4194312 ui_state2=0   (DESEL_MODE=4194304)
  armed            : ui_state=4259848 ui_state2=32768
  after click      : ui_state=4194312 ui_state2=32768  resolved=''
```

Identical outcome. Note `xschem deselect_mode` is a no-op with an empty selection
(`src/scheduler.c:2945-2956`), so this leg pre-selects an unrelated instance and drives
`xschem descend_pick` directly; in the GUI the same state is reached by entering the mode,
deselecting the last object (the mode persists — `deselect_mode_click` restores its bit at
`src/callback.c:3671`), then pressing `E`. That last step is by construction, not measured.

**Manual GUI steps**, for anyone reproducing by hand (needs `cadence_style_rc`, which is
where the mode's keys live — `src/cadence_style_rc:139-140`,
`bind .drw <Key-9> {xschem hilight_net_interactive; break}`):

1. Open any schematic containing a subcircuit instance. Click empty canvas to be sure
   nothing is selected.
2. Press `9`. The status bar's right field shows `HIGHLIGHT NET!`.
3. Press `E` (or Edit ▸ Push schematic). The wide status field shows
   `Descend: click the instance to descend into (ESC to cancel)`.
4. Click the subcircuit. Nothing happens: no chooser, no descend, and the prompt is gone.
5. Press ESC. The mode ends, and the descend is unrecoverable — pressing `E` again with
   nothing selected arms a *fresh* pick, but `cmdmode` is still latched from step 3.

## Fix, if it is to be closed

The two gestures are mutually exclusive claims on Button-1, and [0202](0202-canvas-gesture-seize-has-no-stack.md)
is right that there is no stack to arbitrate them. Three shapes, in increasing cost:

**A. Refuse to arm, and say so.** In `xschem descend_pick` (`src/scheduler.c:3046`):

```c
      if(xctx->ui_state & (NET_HILIGHT | NET_UNHILIGHT | DESEL_MODE)) {
        statusmsg_hold("Descend: end the net-highlight / deselect mode first (ESC)", 1);
        Tcl_SetResult(interp, "0", TCL_STATIC);   /* the caller must be able to see this */
        return TCL_OK;
      }
```

with the matching Tcl guard in `hi_descend_pick_arm` **before** `cmdmode::suspend_all`
(`src/xschem.tcl:6123`) — arming and suspending must fail together or the cure reproduces
the disease. This is the smallest change and the only one that cannot introduce a new
silent state, but it makes the user do the mode dance manually. Note it depends on the pick
arm having a return channel at all, the subject of
[0251](0251-a-refused-descend-has-no-return-channel.md): today `xschem descend_pick`
returns nothing, so a Tcl caller cannot distinguish "armed" from "refused".

**B. The pick wins; the highlight mode defers.** Symmetric to the modal-gesture exclusion
already ratified for wire draws in issue 0247 — `leave_wire_draw_for()`
(`src/scheduler.c:144-153`) abandons an in-progress wire for a placement verb and *says so*
in a held status line. A `leave_click_mode_for("Descend")` would suspend `NET_HILIGHT` /
`NET_UNHILIGHT` / `DESEL_MODE` the same way, with the same held message. `descend_pick` is
conspicuously absent from the `leave_wire_draw_for()` call-site list, which is the same
omission in a different key.

**C. Order the press dispatch by armedness rather than by mode.** Hoist the
`MENUSTARTDESCEND` test above the three click-loop arms at `:8043`/`:8052`/`:8058` — it is
already the one arm in `check_menu_start_commands()` documented as non-mutating and
selection-free (`src/xschem.h:288-296`), so running it first cannot corrupt a mode's state.
Cheapest at the point of failure and it makes descend work *inside* the mode, but it hands
the modes' Button-1 to a one-shot arm and needs an audit of the other `MENUSTART*` codes
before it is safe to generalise.

**Independent of which shape wins, two repairs are needed:**

1. `handle_button_release()`'s unconditional `MENUSTART` clear (`src/callback.c:8597-8600`)
   must clear `ui_state2` too, or leave `MENUSTART` alone when the press was consumed
   without reaching `check_menu_start_commands()`. Right now it manufactures a state
   (`ui_state2` armed, `MENUSTART` clear) that no reader in the tree tests for, which is
   what turns a lost click into a permanent latch. The comment at
   `src/callback.c:339-342` claims "every arming site ASSIGNS `ui_state2` wholesale, so a
   stale bit cannot be misread as a live arm" — true today (verified: every
   `ui_state2 =` site in `callback.c` and `scheduler.c` is an assignment, none is a `|=`),
   but the ESC path's own hygiene clear at `:346` is unreachable here, so
   `xschem get ui_state2` stops being the honest report of what is armed that the 0200/0201
   tests assert on.
2. ESC must reach `hi_descend_pick_cancel` whenever `MENUSTARTDESCEND` is set, regardless of
   `MENUSTART` — the Tcl-side suspend is latched on `MENUSTARTDESCEND` alone, so that is the
   bit the resume must key off.

## Risks

- **`ui_state2` is a shared word.** Relaxing the ESC guard to `ui_state2 & MENUSTARTDESCEND`
  alone is only safe while `descend_pick` is the sole writer of that bit and every site
  assigns rather than ORs. Both hold today; neither is enforced. A future `|=` would make a
  stale bit fire a spurious `hi_descend_pick_cancel`, which calls `cmdmode::resume_all` —
  harmless in isolation (the latch makes the first resume the winner) but it would resume a
  mode nobody suspended.
- **Shape C reorders press dispatch for every mode.** The three click-loop arms are ordered
  deliberately ("Placed before pin-select / persistent-wire / normal-select so the mode owns
  plain Button1 clicks", `src/callback.c:8050-8051`). Only `MENUSTARTDESCEND` is
  non-mutating; hoisting the whole `check_menu_start_commands()` call would let an armed
  move/copy/rotate fire inside the deselect mode, which is a worse bug than this one.
- **The `persistent_command` wire door is unmeasured.** `:8058` returns before `:8075` too,
  so with `persistent_command` set and a resting `last_command` an armed pick should be
  swallowed into a fresh wire start — a *mutating* swallow, strictly worse than this one. I
  could not drive the resting-command state headlessly (ESC clears `last_command`), so this
  is asserted from the code only. It is the reason shape A should test that arm as well.
- **Shape B changes what `9` means.** A user who presses `9`, then `E`, then ESC on the
  chooser would find the highlight mode gone rather than merely interrupted, unless
  `leave_click_mode_for` genuinely suspends and the descend terminals resume it — i.e. it
  needs a `cmdmode` registration, not an ad-hoc bit save. That is the missing piece 0202
  describes and would be its first real client.
- **No coverage anywhere.** Neither mode is exercised by any test in `tests/`, so any of
  these changes lands unguarded. A fix should ship with the proposed
  `tests/headless/test_descend_pick_mode_clash_0257.tcl` asserting, at minimum: the pick
  resolves or refuses (never silently drops), `ui_state2` is 0 after any terminal, and
  `cmdmode::is_suspended` returns to 0.
