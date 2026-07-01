# FAQ

Running Q&A spanning the connected threads of XSCHEM internals work done in
this repo: the input action-registry / binding-table work (branch
`feature/action-registry`), the action-logging / CIW work (branch
`feature/action-logging`), and the scriptability / stable-object-handles work
(branch `feature/stable-object-handles`) — plus general questions about the
XSCHEM data model that come up along the way. Each entry records the **project
state when it was asked** (branch + HEAD commit + phase), because answers are
often tied to how much of a refactor had landed at that moment — a later phase
may make an old "no" a "yes."

Newest entries on top.

---

## Q21. I migrated my old-style libraries (pins whose name text is *not* owned by the pin) into new libraries with the pin-name migration tool. How do I make the Library Manager load the *migrated* libraries when xschem starts?

- **Asked:** 2026-06-30
- **Project state:** branch `cadence-pin-name-text` @ `6b8e6f93`. Pin-owned-name-text P0–P8
  done; migration tool `tools/migrate/migrate_pin_names.py` shipped; user-facing docs
  `doc/pin_name_migration.md` (the tool) and `doc/library_defs.md` (library registration)
  written. Example run: `xschem_libraries_oa` → `xschem_libs_newsym` (342 `.sym`, 239 migrated,
  0 errors), verified all load in xschem + netlist byte-identical.

**Short version:** it is *only* a startup-path question, because the migration is a drop-in.
The migrated tree keeps the same Library/Cell/View names, the same pin `name=`/`dir=`, and the
same connectivity — only display tokens (`show_pinname`, `name_*`) changed and adopted `T`
labels were folded in, so **netlists are identical**. The tool even copied the original tree's
`library.defs` (same `DEFINE` lines). So making xschem "load the correct libraries" means
pointing its startup search at the migrated tree instead of the old one — nothing needs
re-registering by hand.

xschem's startup library set comes from your `xschemrc`: whichever `library.defs` it loads —
explicitly via `XSCHEM_LIBRARY_DEFS`, or **auto-discovered** on `XSCHEM_LIBRARY_PATH` — is what
the Library Manager shows. Two clean ways:

- **Swap the tree on the path (recommended):** in `xschemrc`, put the migrated tree on
  `XSCHEM_LIBRARY_PATH` and drop the old one —
  `append XSCHEM_LIBRARY_PATH :/path/xschem_libs_newsym` (and remove the
  `…/xschem_libraries_oa` line). The migrated tree carries its own `library.defs`, so xschem
  auto-discovers it and the same library names reappear, now with owned pin names.
- **Or point `XSCHEM_LIBRARY_DEFS` at the migrated defs file:**
  `export XSCHEM_LIBRARY_DEFS=/path/xschem_libs_newsym/library.defs` (explicit defs take
  precedence over auto-discovered ones).

**The one trap:** do *not* leave *both* trees on the path with the *same* library names — two
`DEFINE devices …` are deduped by name and precedence/search-order decides the winner, so you
may silently get the old, un-migrated cells. Remove the old tree, or rename its libraries.

**Simplest of all:** because the migration is display-only, netlist-invariant, and idempotent,
you can migrate the *original* tree **in place** (its `.bak`/git is the backup) and skip the
two-tree problem entirely — every `library.defs` entry and schematic reference stays as-is and
each cell just gains owned pin names. Existing schematics never need editing: `C {devices/nmos4}`
resolves through whichever `devices` is registered, so once the migrated one is on the path they
pick up the owned-name symbols automatically.

**Verify at startup:** Tools ▸ Library Manager → pick a migrated cell → **Symbol ▸ Pin names ▸
Show all pin names** shows its names; `xschem get_inst_lcv` on a placed instance reports the
Library/Cell/View it resolved from. Full step-by-step: `doc/library_defs.md` §7.

## Q20. What would it take to animate net highlights (blink + marching ants) in *multiple* open windows at once, not just the front one?

- **Asked:** 2026-06-25
- **Project state:** branch `fluid-editing` @ `c2162eeb`. Net-highlight-styles: Pass 1 + 1.5 +
  2a (blink) + 2b (marching ants, phases A–E) all complete & committed; the animation tick
  animates only the **front** window by design. Plan for this item:
  `doc/claude/suggestions/plan_net_hilight_multiwindow_anim.md`.

> **UPDATE — DONE (2026-06-25, `fluid-editing`).** Implemented as planned, phases A–E. **Now
> every *visible* detached window animates its net highlights (blink + marching) simultaneously;**
> background **tabs** stay front-only (shared canvas, by design). It was exactly the "lift the
> global-front-`xctx` assumption out of four entry points behind one audited context-borrow"
> job described below. What shipped:
> - **`net_hilight_borrow_ctx()` / `net_hilight_restore_ctx()`** (`hilight.c`): the side-effect-free
>   borrow (repoint `xctx` at a window, no raise/focus/title) — A3 audit confirmed the draw path
>   is `xctx`-relative except the file-scope draw batch buffers, which stay safe as long as a
>   borrow wraps one complete, non-reentrant `draw()`.
> - **`xschem get net_hilight_animated <win>`** and **`xschem redraw_hilight_region <win>`** take an
>   optional window and evaluate/draw *that* window via the borrow.
> - **`net_hilight_anim_update()`** fans out to every open window (`net_hilight_anim_update_all`
>   exposes it for the kill-switch); the per-window Tcl tick gates on **`winfo viewable`** (stops
>   iconified windows and background tabs; a `<Visibility>` binding re-arms on restore).
> - **Serialization (E1):** no window animates a frame while the focused window is mid-gesture
>   (`net_hilight_ctx_gesturing()` on the pre-borrow context — a held `semaphore` from a passive
>   modal dialog does NOT freeze other windows). The global wall-clock keeps all windows in phase.
>   See `doc/claude/specs/net_hilight_styles.md` and `doc/claude/specs/multi_window_detach.md`.
>
> Commit chain on `fluid-editing` (each phase RED-first + a `/code-review high` gate): A `00ed9ebd`
> (+review `c85b4751`) → B `4115a27d` (+`fd12f072`) → C `87a36b86` (+`2b7cf900`) → D `4ab92062`
> (+`03597562`) → E `38bf4ea4` (+docs `0f66df43`, +review `ba14af94`). Deferred cleanups logged as
> issues `0030` (dash-period recompute), `0031` (per-window style-table staleness), `0032`
> (anim-update fan-out cost).

**Today it's front-window-only on purpose, but the groundwork is mostly there.** xschem already
keeps a **separate `Xschem_ctx` per window/tab** in the `save_xctx[]` array (`get_save_xctx()`,
`xinit.c:83`); the global `xctx` (`globals.c:236`) just points at the current/front one. Each
context owns its own `window`, `save_pixmap`, cairo surfaces/contexts, `gc[]`/`gc_hilight`,
zoom/pan, object arrays and hilight tables (`xschem.h:1058`+). The catch: **all drawing operates
on the global `xctx`** — to draw window N you must repoint `xctx` at `save_xctx[N]`.

The animation path bakes "front-only" into three spots:
- `net_hilight_anim_update()` (`hilight.c`) arms the Tcl tick only for `xctx->current_win_path`.
- `net_hilight_has_animation()` / `scan_animating_hilights()` / `draw_hilight_region()` all read
  the **global** `xctx`.
- `xschem redraw_hilight_region <win>` (`scheduler.c`) explicitly **returns 0 (stop)** when
  `win != xctx->current_win_path`, so a background window's tick cancels itself.

The one piece already multi-window-ready is the Tcl tick itself: `net_hilight_after` is an array
keyed by window path, so N concurrent self-rescheduling ticks already work.

**What it needs (see the plan doc for the atomic RED-first steps):**
1. A **side-effect-free "borrow context for a draw" primitive** — repoint `xctx` → `save_xctx[N]`,
   regional-redraw into N's pixmap+canvas, repoint back, with **no** focus/raise/title side
   effects (unlike the existing `switch_window()`, `xinit.c:1579`, which is heavyweight). *This is
   the only real risk* — drawing is almost all `xctx`-relative, but it needs an audit for hidden
   global draw state (`bbox()`, `set_clip_mask`, cairo globals).
2. Make the per-window query/frame evaluate window N via that borrow (`get net_hilight_animated
   <win>`, `redraw_hilight_region <win>`); drop the front-window bail.
3. `net_hilight_anim_update` arms **every** animating window (iterate `save_xctx[]`), not just the
   front.
4. Serialize the borrows + never borrow mid-gesture (globalize the `semaphore`/`HILIGHT_ANIM_BUSY`
   checks).
5. Animate only **visible** canvases → this is really a **detached-windows** feature; background
   **tabs share one canvas and aren't visible**, so they correctly stay static (gate on
   `winfo viewable`).
6. The wall-clock (`net_hilight_now_ms`) is already global, so all windows animate in sync — no work.

It is **not a new subsystem** (per-window contexts + per-window ticks already exist); the work is
lifting the "global front `xctx`" assumption out of those four entry points. It's the same
deferral the Pass-2a/2b reviews kept flagging, and a natural sub-item of the broader
**multi-window-detach** work (`doc/claude/specs/multi_window_detach.md`).

---

## Q19. Where are the net-highlight keys `9`/`8`/`0` defined, and how do I reassign them?

- **Asked:** 2026-06-24
- **Project state:** branch `fluid-editing` @ `0934579e`. Net-highlight-styles plan
  (`doc/claude/suggestions/plan_net_hilight_styles.md`): Pass 1 (Phases 1–4) + Pass 1.5 (tilted
  stripes) complete; only Pass 2 (animation) remains. Spec: `doc/claude/specs/net_hilight_styles.md`.

**They are three plain Tk bindings in `src/cadence_style_rc` (lines 81–83), each firing one
`xschem` subcommand:**

```tcl
bind .drw <Key-9> {xschem hilight_net_interactive;   break}   ;# highlight net(s)
bind .drw <Key-8> {xschem unhilight_net_interactive; break}   ;# remove a specific highlight
bind .drw <Key-0> {xschem unhilight_all;             break}   ;# remove ALL highlights
```

| Key | Command | Behavior |
|---|---|---|
| `9` | `xschem hilight_net_interactive` | noun-verb if a net/wire/label is selected (highlight it, advancing the style each press, selection kept); else verb-noun click-to-highlight mode, ESC to end |
| `8` | `xschem unhilight_net_interactive` | remove highlight on the selection, or click-to-remove mode |
| `0` | `xschem unhilight_all` | clear all net highlights |

The trailing **`break` is load-bearing**: it stops the digit from also reaching the C key
dispatcher, where bare `0` toggles pin logic level (`8`/`9` are no-ops there).

**Architectural note — these are NOT in the data-driven action registry.** Unlike the
snap/grid actions of Q17/Q18 (which are registered `ActionDef`s bound via `xschem bind key
<keysym> …`), `9`/`8`/`0` are direct **Tk `bind .drw`** lines (the "Tier A" recipe of Q17).
So `xschem bind` / `xschem bindings dump` / `xschem unbind` neither list nor manage them —
you reassign them by editing the Tk binding, not the registry. (The three *commands* are
real `xschem` subcommands in `scheduler.c`; only the key→command wiring lives in the rc.)

**To reassign — edit the Tk bind in `cadence_style_rc`, your `~/.xschem/xschemrc`, or a
`--script` file:**

1. **Free the old key** (optional): delete or comment out the `bind .drw <Key-9> …` line, or
   re-point it. (To make the old digit do nothing at all, leave a `bind .drw <Key-9> {break}`.)
2. **Bind the new key** to the same command, keeping `break`:
   ```tcl
   # e.g. move "highlight net" from 9 to F5, and "clear all" from 0 to Shift-F5
   bind .drw <Key-F5>       {xschem hilight_net_interactive; break}
   bind .drw <Shift-Key-F5> {xschem unhilight_all;           break}
   ```
3. Re-source the rc (or restart). New/detached windows inherit it automatically —
   `clone_canvas_bindings` (`xschem.tcl:10932`, issue 0020) copies `.drw` bindings to each
   new canvas.

**Gotchas.**
- Bind by the **keysym the chord actually emits**: Shift changes it (on a US layout `Shift-9`
  is `parenleft`, not `9`), so `bind .drw <Key-parenleft> …`, not `<Shift-Key-9>`. Run `xev`
  (or `wish`'s `bind . <Key> {puts %K}`) to read a key's keysym.
- The command is the stable part — you can wire `hilight_net_interactive` to **any** key,
  or even a mouse button (`bind .drw <Button-2> {xschem hilight_net_interactive; break}`) or a
  menu entry; only the trigger changes.
- These bindings live in `cadence_style_rc`, so they exist only when that rc is sourced. To
  have them everywhere, move the three lines into your `~/.xschem/xschemrc`.

**If you instead want them in the remappable registry** (so they show in `bindings dump` and
take CSV rows), that's the Q17 **Tier B** path: register `ActionDef`s wrapping the three
commands in `callback.c`, then `xschem bind key 57 0 canvas net.hilight` (etc.). That needs a
recompile and is only worth it if you want registry-managed remapping; for a personal key
swap, the Tk `bind` edit above is the one-line, no-recompile answer.

---

## Q18. Some keyboard shortcuts stopped working — `g`/`G` (snap), `Ctrl-g`, `Alt-g`, `%` (grid). Where did they go, and how do I get them back?

- **Asked:** 2026-06-23
- **Project state:** branch `fluid-editing`, plan
  `doc/claude/suggestions/plan_keybind_snap_grid_actions.md` Phases 0–2 landed (snap defaults
  removed, the five actions registered, `cadence_style_rc` rebind recipes added);
  Phase 3 (delete the now-dead `case 'g'`/`case '%'`) still pending. Spec:
  `doc/claude/specs/keybind_snap_grid_actions.md`. Background: Q17.

**They didn't disappear — they were turned into *user-bindable actions* that now ship
UNBOUND, so you choose the keys.** The snap / grid / net-highlight operations used to be
hard-wired to specific keys in C. They are now entries in the action registry with **no
built-in default chord**, so every key mapping is yours to set (the whole point: map keys
to functions from Tcl / a loadable script, nothing soldered in C). The *functions* are
unchanged and still on the menus (Options / View).

**Where to get them back: the binding block in `src/cadence_style_rc`** (the
`# --- snap / grid / highlight key actions ---` block, ~lines 128–146). Uncomment the
`xschem bind` line for the shortcut you want:

| Old key | Did | Action id | Recipe in cadence_style_rc |
|---|---|---|---|
| `g` | halve snap | `view.snap_half` | line ~140 (commented) |
| `Shift-g` (`G`) | double snap | `view.snap_double` | line ~141 (commented) |
| `Alt-g` | highlight net → waveform viewer | `hilight.send_to_waveform` | line ~142 (commented) |
| `Ctrl-g` | set snap value (dialog) | `view.set_snap_value` | line ~143 (commented; old `Ctrl-g` is now grid) |
| `%` | toggle grid | `view.toggle_draw_grid` | line ~146 (commented) |

**`CTRL-G` is the one that ships active** — `cadence_style_rc` line ~137 binds it to
`view.toggle_draw_grid`, so under the cadence config **Ctrl-G toggles grid visibility**.

**The general way** (works in any rc / `--script` / the CIW):
`xschem bind key <keysym> <mods> canvas <action>` — keysyms `g`=103, `G`=71, `%`=37,
`s`=115 (run `xev` for others), mods `0|ctrl|alt|shift|super` joined by `+`. List what's
live with `xschem bindings dump`; remove one with `xschem unbind`. Gotcha: Shift changes
the produced keysym (Shift-g → `G`/71), so bind the chord by the keysym it actually emits.
See Q17 for the binding-table internals and `doc/claude/specs/keybind_snap_grid_actions.md` for the
full design.

---

## Q17. What is CTRL-G bound to currently, and what would it take to use it to toggle grid display ON/OFF?

- **Asked:** 2026-06-23
- **Project state:** branch `fluid-editing` @ `2919e381` (just after the 8
  code-review fixes, issues 0019–0026). The relevant substrate is the
  action-registry binding table (`feature/action-registry`): data-driven
  `ActionDef` table, `xschem bind/unbind/bindings`, context-aware dispatch —
  the migration from hardcoded C `case` keys to the table is **partial**.

> **Update (2026-06-23, IMPLEMENTED).** This was built — but the design landed *cleaner*
> than the "Tier B default binding" recommendation below: there is **NO built-in default**.
> The five ops are registered actions (`view.snap_half`, `view.snap_double`,
> `view.set_snap_value`, `hilight.send_to_waveform`, `view.toggle_draw_grid`) that ship
> **UNBOUND**; the `g`/`G` snap defaults were removed and the hardcoded `case 'g'`/`case '%'`
> deleted. Every chord is user-specified — `cadence_style_rc` carries the **active**
> `xschem bind key 103 ctrl canvas view.toggle_draw_grid` (so CTRL-G toggles grid under that
> config) plus commented recipes for the rest. See `doc/claude/specs/keybind_snap_grid_actions.md` and
> Q18 (how to rebind the shortcuts that "disappeared"). The Tier A/B/C analysis below is kept
> as the historical "what it would take" picture.

**CTRL-G currently *sets the snap value*** — it pops an `input_line` dialog
("Enter snap value…") and applies it via `xschem set cadsnap`. It is a
**hardcoded C branch** (`callback.c:3884`, `case 'g':` → `if(rstate==ControlMask)`),
**not** in the data-driven table. For context, the other `g` chords are:

| Chord | Does | Where |
|---|---|---|
| `g` | halve snap factor | `view.snap_half` (table; `keybindings.csv:32`, `act_snap_half` `callback.c:2602`) |
| `Shift-g` (`G`) | double snap factor | `view.snap_double` (table; `keybindings.csv:33`) |
| `Ctrl-g` | **set snap value (dialog)** | hardcoded `callback.c:3884` |
| `Alt-g` | highlight net → waveform viewer | hardcoded `callback.c:3890` |

**Grid toggling today** flips the Tcl var `draw_grid` and redraws. It is reachable
two ways, both hardcoded / not an action:
- the `%` key — `callback.c:4708` `case '%'`;
- Options menu **"Draw grid"** checkbutton (`xschem.tcl:11341`, `-variable draw_grid`,
  `-command {xschem redraw}`, accelerator `%`).

There is **no `view.toggle_draw_grid` action** in the registry yet.

**Key precedence fact.** The binding table is consulted **first**: `handle_key_press`
calls `dispatch_input_action()` at `callback.c:3601` and `return`s early on a match —
so a table entry for Ctrl-g will *shadow* the hardcoded "set snap value" case
automatically (that numeric-snap function then loses its Ctrl-g access; plain `g`/`G`
snap still work). Actions can be **C-backed** (`d->fn`) or **Tcl-backed** (`d->tcl`,
`dispatch_input_action` `callback.c:2994`), which decides whether a change needs a
recompile.

**Three tiers to make Ctrl-G toggle the grid:**

**Tier A — rc one-liner, no recompile (fastest).** A more-specific Tk binding pre-empts
the generic `<KeyPress>`→C dispatch (same trick as the command palette's
`<Control-Shift-Key-P>`). Add to `cadence_style_rc` / xschemrc:
```tcl
bind .drw <Control-Key-g> {set draw_grid [expr {!$draw_grid}]; xschem redraw; break}
```
Propagates to new/detached windows automatically (issue 0020's `clone_canvas_bindings`
fix). Downsides: bypasses the action log and the keybindings table.

**Tier B — data-driven action, the "right" way (needs a rebuild).** Matches the
codebase's migration direction and gives action-log + CSV-remap for free:
1. In `callback.c`, lift the `case '%'` body into `toggle_draw_grid_cmd()` + an
   `act_toggle_draw_grid` wrapper, and register
   `{ "view.toggle_draw_grid", act_toggle_draw_grid, NULL, "Toggle grid display" }`
   in the `ActionDef` table (next to `view.toggle_draw_pixmap`, `callback.c:2694`).
2. Bind the chord — either a default in `init_input_bindings`
   (`set_input_binding(DEV_KEY, 'g', ControlMask, ACTX_CANVAS, "view.toggle_draw_grid");`,
   mirroring `callback.c:2848`) or a CSV row `key,103,ctrl,canvas,view.toggle_draw_grid`.
3. Decide where "set snap value" goes: it's auto-shadowed by the table-first dispatch,
   so either migrate it to its own action + chord, or accept dropping it.
4. (Optional cleanup) point `%` at the same action and delete the dead `case '%'`.

**Tier C — minimal C hack.** Change the `case 'g'` `ControlMask` branch body to toggle
the grid. Quick, but fights the migration and silently drops set-snap.

**Recommendation:** Tier B — ~25 lines, keeps the architecture consistent, and makes the
chord remappable from `keybindings.csv` / `xschem bind` without further code. Tier A is
the instant no-recompile fallback.

---

## Q16. After the wire-prop-preservation fix (`06b08e61`), what difference will a user actually notice?

- **Asked:** 2026-06-19
- **Project state:** branch `fluid-editing` @ `06b08e61` (fix), docs follow-up at
  `d47558f5`. Wire-editing-on-move plan complete through Phase 6; this commit fixes
  **TC12 / R19**, the last RED — the full `tests/headless/wireedit` map (TC0–TC17) is now
  green. Bug-class write-up: `doc/claude/code_analysis/prop_dropped_on_move_tutorial.md`.

**Short answer: stretch-moving a component no longer strips a connected wire's properties
— most visibly, a bus wire stays a bus instead of being silently demoted to a plain
thin wire.** On ordinary unlabeled wires there is **no visible change** (output is
byte-identical).

**Before vs after.** When you rubber-band-stretch a wire by dragging a component it's
connected to, and the drag triggers the colinear-slide path, the move used to re-create
the surviving wire segment with **empty properties** — wiping `bus=` and any other
attribute tokens. A 4-bit bus drawn thick would come back as a plain thin wire on a
different net. After the fix the survivor **inherits the original wire's `prop_ptr`**, so
the bus (and any property) is preserved.

| | drag-stretch a `{bus=4}` wire | result |
|---|---|---|
| before `06b08e61` | saved as | `N 0 70 0 130 {}` — bus lost, wire demoted |
| after `06b08e61` | saved as | `N 0 70 0 130 {bus=4}` — bus preserved |

**When it's visible (all three must hold):**
1. stretch / rubber-band is active (`enable_stretch`, e.g. `cadence_compat` mode);
2. the wire being stretched carries a **persistent attribute** (notably a bus); and
3. the move hits the colinear-slide re-create path (`place_moved_wire()`'s V-H/H-V branch).

Because it was **silent data loss**, users who hit it before likely never traced it to
the move — they'd just notice a bus had gone thin/plain later. This removes that surprise.

**What this is NOT.** It is unrelated to the Phase-6 **exit-stub** feature (`8ba5ddf7`),
which is behind `wire_exit_stub` (default **OFF**) — users notice that one only if they
enable it (Options → "Keep stub out of moved pins"). And the very latest commit
(`d47558f5`) is an internal tutorial doc with **zero** user-facing effect.

**Why the original test premise was wrong (worth knowing).** Phase 1 asserted a wire's
`lab=A[3:0]` token survives the move. It can't — a bare wire's `lab` is a **write-only
derived-net cache** that `prepare_netlist_structs()` overwrites with the auto net name
(`#net1`) move-or-not. The real, user-visible thing to preserve is a *persistent* attribute
(`bus=`) and a real `lab_pin` net-label **instance**, which is what TC12 now tests. See the
tutorial for the full bug class (metadata loss across object re-creation).

---

## Q15. Two instances are placed so that two of their pins sit on the same point (directly connected, no wire). One instance is then moved. The pins must STAY connected — so wire segments need to be generated. What support exists for this, and where is it on the wire-editing plan?

- **Asked:** 2026-06-19
- **Project state:** branch `fluid-editing` @ `bc0fdb66`. Wire-editing-on-move plan
  (`doc/claude/code_analysis/wire_editing_spec_and_plan.md`): Phase 0 (scaffold) + Phase 1
  (TC1–TC15 baseline) + Phase 2 (sub-grid tolerant match) landed; the new
  `cadence_compat` modifier-drag feature is also in (`15dced84`).

**The mechanism already exists — `connect_by_kissing()` (`actions.c:1163`) — but the
drag path doesn't call it.** For each pin of the *moving* instance it scans (before the
move) for a coincident **non-selected instance pin** (true abutment) or a touching
wire; on a hit it inserts a zero-length wire anchored at that point (`storeobject(...,
SELECTED1, ...)`), which the move then stretches into the connecting segment. Verified
headlessly with two abutted `res.sym` pins at `(0,30)`, moving one by `(40,0)`:

| Move | Result |
|---|---|
| `xschem move_objects 40 0 kissing` | one wire `{0 30 40 30}` — **connection kept** |
| `xschem move_objects 40 0 stretch` | **0 wires — connection lost** |

It fires when `xctx->connect_by_kissing == 2`, set by: the **`M`** move command
(`callback.c:4053`) and **Ctrl+M** (`:4067`, move+stretch+kissing), an Alt-move and a
duplicate path (`:4037`/`:3683`), scripted `move_objects … kissing`
(`scheduler.c:3911`), and the **legacy intuitive Shift+drag** path (`:5272`).
`move_objects` consumes it at move END (`move.c:619/1165`).

**The gap:** the plain/stretch drag uses `select_attached_nets()`, which only stretches
*existing* wires — so dragging an abutted instance silently disconnects it. And in
**`cadence_compat`** mode the new drag branch maps plain→stretch, Ctrl→move,
Shift→copy, so **no click-drag gesture sets the kissing flag** — the legacy Shift+drag
that used to is now `copy`. So today this works only via the **`M` command** (or
scripted `kissing`), not by dragging.

**Where on the plan:** it was *not* a pre-existing test case. As of this commit it is
**TC16 (Issue H / R20)**, folded into **Phase 3** — which now routes the plain /
`cadence_compat` drag through `connect_by_kissing()`. Because that one function covers
**both** the T-junction/mid-span case (TC5) and the pin-abutment case (TC16), a single
Phase-3 change is positioned to turn both green *and* restore the kissing behavior
cadence users lost. TC16's baseline test
(`tests/headless/wireedit/test_wireedit_16_pin_abutment.tcl`) is RED on the drag path
today.

---

## Q14. Cadence supports both the verb-noun and noun-verb interaction grammars (like LTspice's verb-noun, plus the modern select-then-act). How big is the gap between XSCHEM and Cadence here?

- **Asked:** 2026-06-15
- **Project state:** branch `library-manager` @ `5661885e`. The relevant
  substrate is the action-registry binding table (branch
  `feature/action-registry`, Phase 3 plan complete) — `xschem bind/unbind/bindings`,
  data-driven `ActionDef`, context-aware dispatch, the `idle_only` semaphore flag.

**Smaller than the question implies — XSCHEM already supports *both* grammars
today.** It just doesn't frame them as "Cadence parity." The gap is qualitative
(polish + unification), not "missing feature," and the *architectural* gap is
small because the bindkey substrate Cadence is built on is exactly what the
action-registry work has been constructing.

**1 — XSCHEM already spans the verb-noun / noun-verb spectrum via four flags.**
There isn't one interaction model; there's a cluster of booleans (defaults in
`xschem.tcl:12037-12043`) that between them cover the range:

| Flag | Default | What it actually controls |
|---|---|---|
| `intuitive_interface` | **1** | The *noun-verb* refinements: click-on-object selects, click-drag a selected object moves it, click-empty deselects (`callback.c:5166-5230`). The modern select-then-act polish. |
| `infix_interface` | **1** | The verb *ordering*. `=1` → pressing `m`/`c`/`C`/`w`… acts **immediately at the cursor** (`copy_objects(START)` grabs where the pointer is). `=0` → the same key sets `MENUSTART \| MENUSTARTCOPY` and **waits for a click to anchor** (`callback.c:3656-3663`). That `=0` path *is* the verb-noun/prefix flow — and it's the path menu invocations already use. |
| `persistent_command` | 0 | The *armed-verb-repeats* behavior — the command stays active across objects until Escape (`callback.c:1892`, `5120`). LTspice's "stay in the tool." |
| `cadence_compat` | 0 | An explicit Cadence-bindkey bundle: Ctrl=simulate, click-on-selected-clears-selection, snap-cursor toggle, etc. (`callback.c:4251, 4584, 5321`). |

So pressing `c` with `infix_interface=1` gives the XSCHEM-native *infix* flow
(point already established by the cursor, verb injected in the middle); set it
`0` and the *same key* becomes prefix/verb-noun (verb first, then click a point).
The `MENUSTART`/`MENUSTART2` bits (`xschem.h:238-263`) are a per-command armed-verb
state machine that already covers move, copy, wire, line, rect, arc, polygon,
zoom, and wire-cut.

**2 — The remaining gap is qualitative.** What Cadence has that XSCHEM's version
doesn't:

1. **A unified command/point-entry kernel.** Cadence's `hiEnterPoint`/`hiGetPoint`
   is one generalized mechanism: a command declares "I need K points," the kernel
   collects them, drives the status-bar prompts ("Point at reference… Point at
   destination"), and allows **typed coordinate entry**. XSCHEM hardcodes the
   prefix flow per-command via `MENUSTART2` bits and scattered
   `if(infix_interface)` branches. No prompt line guiding the points, no
   coordinate typing. **This is the single biggest gap.**
2. **`persistent_command` is narrow.** The menu only exposes it as "Persistent
   wire/line place command" (`xschem.tcl:10962`); Cadence makes nearly *every*
   command persistent/repeating.
3. **No per-command options form.** Cadence's F3 brings up the active command's
   option form mid-gesture; XSCHEM has global toggles, not command-scoped ones.
4. **The modes are four loosely-coupled booleans, not a model.** They interact
   ad-hoc — `callback.c:2842` already notes `cadence_compat`-gated keys "the table
   can't express," and the action-registry work hit `s`/`Ctrl+r` keys that couldn't
   migrate because forward-behavior lives inside a `cadence_compat`-conditioned
   branch.

**3 — Why the *architectural* gap is small.** The substrate Cadence is built on
is bindkeys + a central command dispatcher — exactly what `feature/action-registry`
constructed: `xschem bind/unbind/bindings`, a data-driven `ActionDef` table (Tcl-
or C-backed), context-aware dispatch, an `idle_only` flag mirroring
semaphore-sensitivity. *That is the bindkey half of Cadence.* The missing half is
a **generalized point-entry state machine** layered on the dispatcher — one that
replaces the per-key `MENUSTART2` bit-twiddling and the `if(infix_interface)` forks
with: *"current command C wants N points; here are its prompts; here's whether it
persists; here's its options form."* Build that and the four flags collapse into
one coherent model, with prefix/infix/persistent/cadence behaviors becoming
*configurations* of it rather than separate code paths.

**Bottom line:** feature-wise the gap is modest (both grammars already exist;
what's missing is a prompt/point-entry kernel, generalized persistence, and
command-scoped options); architecturally it's small and shrinking, because the
dispatcher being decomposed is the right foundation and the `MENUSTART` machinery
is a working-but-ad-hoc prototype of the kernel you'd formalize.

---

## Q13. Why doesn't pressing `q` to open the Edit Properties form write `xschem edit_prop` to the action log?

- **Asked:** 2026-06-14
- **Project state:** branch `slick-property-forms` @ `098f4ea1` (the slick
  property form + multi-instance editing + the scope highlight + the modeless
  selection M1 have all landed; the action-logging machinery from
  `feature/action-logging` is present in this lineage).

**Because the action log records *committed effects*, not *user intentions* —
and "open a dialog" is an intention, not an effect.** Pressing `q` is genuinely
unlogged, but the fix is not "log `q`"; understanding *why* teaches three
architecture ideas that outlast this one key.

**1 — The log is opt-in at chokepoints, not an automatic command tap.** It is
tempting to assume the log wraps the one `xschem` dispatcher (`scheduler.c`) and
records every subcommand for free — the way the binding table funnel made key
remapping free (Q7). It doesn't. Logging is a **curated set of hand-placed
`log_action("xschem …")` calls** at specific sites: gesture completions
(wire/line/rect/arc/move/copy in `actions.c`), pan/zoom and placements
(`callback.c`), file open/save (resolved paths). A path with no `log_action()`
writes nothing. The `q` key calls the C function `edit_property(0)` **directly**
(`callback.c:4130`) — it never even goes through the `xschem edit_prop` Tcl
command — and neither it nor `edit_property()` carries a `log_action`. So:
silence, by omission.

> Why opt-in rather than a blanket tap on the dispatcher? Because most `xschem`
> subcommands are **queries** (`get`, `wire_coord`, `objects`, `instance_id`, …)
> — read-only, fired constantly, and meaningless in a replay. A blanket tap would
> drown the signal (the few state-changing commands) in noise (the thousands of
> reads), and would still mis-handle the interactive ones (next point). Curation
> is the cost of a log that is actually *replayable*.

**2 — Log the effect, not the gesture. `edit_prop` is the wrong thing to log
even in principle.** `xschem edit_prop` just **opens a modal dialog**. A log is
only useful if it can be *replayed*, and replaying "open a dialog" would pop a
window and block, waiting for a human — there is nothing deterministic to re-run.
This is the same reason file open/save log the **resolved path**
(`xschem load {…/foo.sch}`) rather than "the open-file dialog appeared." The
replayable thing a property edit produces is the mutation the form issues on
OK/Apply:

```
xschem apply_properties <scope> <displayed_id> <new_prop> <old_prop>
```

That command is deterministic and idempotent-on-replay; `edit_prop` is neither.
So the right design is: **don't log the dialog-open as a *replayable command*; log
the apply.** The general principle — worth carrying to any undo/redo, audit-trail,
or event-sourcing system — is *record the committed transition (old→new state),
not the UI event that led a human to it.* Intentions are infinite and interactive;
effects are finite and replayable.

> **Update (2026-06-14): the launch *is* now recorded — as a non-replayable
> marker, not a command.** Opening the form writes a Tcl-comment line,
> `# xschem edit_prop <scope> — Edit Properties form opened (non-replayable:
> modal)`, emitted at `slickprop::edit_form` (the one point `q`/menu/`xschem
> edit_prop` converge). Because it begins with `#`, `source`-ing the log **skips
> it** — so the audit record of "the user opened the editor" coexists with a
> replayable log, and the modal never re-opens on replay. This is the key
> distinction: *a replay log can carry two kinds of line* — replayable commands
> (the apply) and inert `#` markers for intentions worth recording but not
> re-executing. Don't force an interactive event into a replayable command;
> demote it to a comment.

> This is exactly the **command/query and intent/effect split**. A keystroke, a
> menu pick, and a scripted call can all reach the same effect by different
> routes; logging at the effect captures all three with one instrumentation
> point, while logging at the gesture would need three (and would record the two
> interactive ones unreplayably).

**3 — So where's the bug? Not in `q` — in coverage.** The honest gap was that
`apply_properties` *itself* was **also not logged** (added for the multi-instance
work without a `log_action`). So property edits were absent from the replay log in
*any* form. **(Now fixed — see the placement subtlety below, which is the real
lesson.)**

**3a — The instinct is right, the placement is a trap.** The obvious fix is "one
`log_action` in the **funnel** every Apply/OK passes through —
`apply_instance_properties()` (`editprop.c`)." That is where you'd put *identity*
or *undo* (Q7): one chokepoint, every route covered. **But for a replay log it is
wrong**, and seeing why is the payoff of this question. Look at *who* calls that
funnel:

| caller | reaches `apply_instance_properties()` via |
| --- | --- |
| the form's OK / Apply | `do_apply` → `xschem apply_properties` |
| a CIW-typed command | the CIW → `xschem apply_properties` |
| **replay** (sourcing the log) | `source` → `xschem apply_properties` |
| a script / keybinding | → `xschem apply_properties` |

A `log_action` in the funnel fires for **all four**. Two of them must *not* be
logged from there: the **CIW already logs typed commands itself** (you'd write the
line twice), and **replay must re-execute without re-recording** (logging in the
funnel makes replaying a log *grow a fresh copy of every edit*). This is the exact
trap the engine already documents at `callback.c`: *"hooking move.c instead would
double-log every replay"* — move/zoom log at the **interactive gesture layer**
(`callback.c`), never in the engine (`move.c`) that the `xschem move_objects`
command reuses.

So the correct site is the **interactive layer** — the form's `do_apply`, which
replay/CIW/scripts never call:

```tcl
# slickprop::do_apply, after a successful apply ($did): log the REPLAYABLE
# command itself (built with [list ...] so it re-parses when the log is sourced).
if {$did} {
  slickprop::log_apply [list xschem apply_properties \
    $::slickprop_apply_scope $nav(disp_id) $::tctx::retval $cur(orig)]
}
```

> **The distinction worth internalizing:** *state-mutation* concerns (identity,
> undo, cache invalidation) belong at the **engine funnel** — the one place every
> route mutates. A *replay log* belongs one layer **up**, at the **interactive
> trigger** — because the log's own replay vehicle is the engine command, and a
> recorder that sits on its own playback head records itself. Same codebase, two
> different "right chokepoints," chosen by whether the concern must *not* re-fire
> during replay.

**One caveat the student should not miss: a replay log is only as good as its
*referents*.** `displayed_id` is a **session-stable** id (Q7/Q8) — unique and
durable *within* a run, but minted fresh each session and not written to the
`.sch` file. So a logged `apply_properties … 42 …` replays perfectly in the same
session, but feeding last week's log to a fresh process may have id 42 refer to a
different object (or nothing). This is the known "stable referents" problem
(deferred *issue 0005* in the action-logging spec): a faithful command log still
needs **stable names** for the things its commands point at, or replay across
sessions silently drifts. Logging the command is half the job; making its
arguments mean the same thing tomorrow is the other half.

**Takeaways for an aspiring engineer:**
- A good event/audit/undo log records **state transitions (effects)**, not
  **UI events (intentions)** — effects are deterministic and replayable;
  intentions are interactive and infinite.
- Pick the chokepoint by the **concern**: *state-mutation* concerns (identity,
  undo) go at the **engine funnel**; a **replay log** goes one layer up at the
  **interactive trigger**, or it records its own playback and double-logs.
- **Opt-in beats blanket** for replay logs: most calls are queries; recording
  everything destroys the signal and still botches the interactive cases.
- A log is only replayable if its **referents are stable** across the replay
  horizon you care about (same session vs. across sessions).

---

## Q12. With several schematic windows open, how do you get the wire list of *one specific* schematic?

- **Asked:** 2026-06-13
- **Project state:** branch `feature/stable-object-handles` @ `1c653298`.

**Switch the active context to that window, then query — there is no
"query window X while window Y is active."** Every `xschem` query command
(`get wires`, `wire_coord`, `wire_id`, `selection`, …) reads the **active
context** only (the global `xctx`). The single command that reaches across
windows is `tab_list`, and it returns only filenames. So the procedure is
always *find the window → switch to it → query → (optionally) switch back.*

```tcl
# 1. find the window holding the schematic you want, by filename.
#    tab_list rows are: {win_path} {full_filename}
set target {}
foreach line [split [xschem tab_list] \n] {
  if {[string match *Q1.sch* $line]} { set target [lindex $line 0] }
}
#    -> target is e.g. ".x1.drw"

# 2. make that window the active context
xschem new_schematic switch $target

# 3. the wire queries now refer to THAT schematic
set n [xschem get wires]                 ;# e.g. 19 (Q1's wire count)
for {set i 0} {$i < $n} {incr i} { ... } ;# Q1's wires
xschem selection                         ;# Q1's selection

# 4. (optional) go back
xschem new_schematic switch .drw         ;# main window
```

Verified headless against three open schematics (mos_power_ampli=91,
Q1=19, bus_keeper=8 wires): each switch + `get wires` returned the right
count, and the contexts stay fully isolated.

**Naming the target — two forms, and one trap.** `new_schematic switch`
accepts either:

- a **win_path** — `.drw` is the main window, then `.x1.drw`, `.x2.drw`, …
  This is the robust id; read it from `tab_list`, don't hardcode it.
- a **schematic basename *with extension*** — `xschem new_schematic switch
  Q1.sch`.

The trap (found while verifying): switch-by-name matches the **basename only**
(`get_cell_w_ext`, `xinit.c:1341` `get_tab_or_window_number`), *not* a path.
`xschem new_schematic switch /…/examples/bus_keeper.sch` **silently does
nothing** (stays put). Use `bus_keeper.sch`, or use the win_path. If two
windows hold the same basename, only the win_path disambiguates.

**Nuances worth knowing:**

- **Opening makes it active.** `new_schematic create {} <file>` switches the
  active context *to* the new schematic — after opening several you are "in"
  the last one created, not back in main.
- **You get the level currently shown.** If that window has descended into a
  sub-schematic (hierarchy push), `get wires` returns the *sub-sheet's* wires,
  not the top sheet's. `xschem get currsch` is the depth (0 = top).
- **Wire ids are per-context.** Id 5 in window A is a different wire from id 5
  in window B — each context has its own monotonic `wire_id_counter` (see Q9).
  Collecting handles across windows? Tag each id with its win_path.
- **`switch previous`** works only in tabbed mode; in separate-window mode it
  is a no-op (`xinit.c:1536`).
- **Wire 0** still has the `wire_coord 0` off-by-one — a *complete*
  enumeration loops from index 1 plus the `saveas` ground-truth fallback (see
  `doc/stable_wire_handles.md` §6); the id-based commands (`wire_id 0`,
  `selection`) are not affected.

This is purely about *reading* a chosen context; the underlying multi-window
model (tabbed vs windowed, `MAX_NEW_WINDOWS`, hierarchy vs separate windows) is
Q9.

---

## Q11. Is there a way to iterate over the *selected* objects from a script?

- **Asked:** 2026-06-13
- **Project state:** branch `feature/stable-object-handles` @ `7539fa68`
  (wire stable handles shipped; selection-as-data still a gap).

> **Update (2026-06-13, same day): the gap is now closed.** The
> `xschem selection` command described at the bottom of this answer was
> implemented (TDD, RED commit then GREEN) and is the recommended way to
> iterate the whole selection:
>
> ```tcl
> xschem selection
> ;# -> {text 0 3 7} {wire 0 1 6} {line 0 4 5} ...
> ```
>
> It returns one `{type index col id}` Tcl list element per selected object
> across all seven types — `type` ∈ `wire|instance|rect|line|poly|arc|text`,
> `index`/`col` address the object, and `id` is the session-stable id. **All
> seven drawable types now carry an id** (an `id` of `-1` means a *dangling*
> reference, not a type without ids). So
> `foreach o [xschem selection] { lassign $o type idx col id … }` works, and
> `xschem objects`/`object` give the same data as self-describing dicts plus a
> resolver (`doc/object_query_api.md`). The analysis below is kept as the
> historical "before" picture.

**Partially — and the gap is instructive.** The *complete* selection already
exists inside the engine, but only fragments of it are exposed to Tcl, so a
single generic "for each selected object" loop is **not** possible through the
documented surface today.

**What exists in C.** `rebuild_selected_array()` (`move.c:52`) walks all seven
object types and fills `xctx->sel_array[]` with a `{type, n, col}` triple for
every selected object — texts, instances, wires, then per-layer arcs / rects /
lines / polygons — and sets `xctx->lastsel` to the count. So the full, typed
selection list is assembled and sitting in memory after any selection change.

**What Tcl can actually read** — only pieces of that array:

| Command | Covers | Returns |
| --- | --- | --- |
| `xschem get lastsel` | all types | just the **count** |
| `xschem get first_sel` | all types | only the **first** object: `type n col` |
| `xschem selected_set` | **instances** only | `{name} {name} …` |
| `xschem selected_set rect` | **rects** only | `col n x1 y1 x2 y2` per line |
| `xschem selected_set text` | **texts** only | `n x y rot flip {txt}` per line |
| `xschem selected_wire` | **wires** only | net **labels** — *not* indices/handles |
| lines, polygons, arcs | — | **not exposed at all** |

(`selected_set` is defined at `scheduler.c:5589`; it switches only on `rect` /
`text` and otherwise defaults to instances — `selected_wire` at
`scheduler.c:5632`.)

So concretely, from a script you **can**:

- iterate selected **instances**, **rectangles**, and **texts** (three
  separate `selected_set` calls);
- read the **net labels** of selected wires (`selected_wire`);
- get the **count** (`get lastsel`) and the **first** selected object's
  type+index (`get first_sel`).

And you **cannot**:

- get a selected wire's *index or stable id* (only its label) when more than
  one object is selected — `get first_sel` shows just the first;
- enumerate selected **lines, polygons, or arcs** at all;
- get one unified list of everything selected.

This is the "selection as data" gap from `tcl_introspection_wire.md` §4 and
defect #4 (`selected_set` omits WIRE / LINE / POLYGON / ARC). It is purely a
*missing exposure*, not missing data: `sel_array` already holds the answer.

**Type codes** (for reading `first_sel` / `sel_array`):
`WIRE=1, xRECT=2, LINE=4, ELEMENT=8, xTEXT=16, POLYGON=32, ARC=64`
(`xschem.h:265–271`).

**The natural fix** is one new dispatcher branch — e.g. `xschem selection`
returning `type index col` (plus, for wires, the stable id from the Q7/handle
work) one row per selected object across all seven types — turning the
already-populated `sel_array` into a real, scriptable "iterate every selection"
list. That is the selection half of the planned `xschem object` uniform API,
and it is now more valuable because wires carry stable ids the command could
hand back.

---

## Q10. Can you open a schematic or symbol in *read-only* mode?

- **Asked:** 2026-06-12
- **Project state:** branch `feature/stable-object-handles` @ `10c3f2f8`
  (step 1 of stable handles complete; the wire-handle manual just landed).

**No — XSCHEM has no read-only / view-only open mode today.** Every file you
open is loaded into a fully editable in-memory context. There is no
application-level lock, no flag, and no startup option that makes a loaded
schematic non-editable. Specifically, the searches come back empty on all of
these:

- **No `xschem load` flag for it.** The `load` command
  (`scheduler.c`, the `xschem_cmds_l` group) accepts
  `-nosymbols | -gui | -noundoreset | -nofullzoom | -nodraw | -keep_symbols |
  -lastclosed | -lastopened` — controlling *symbol loading, undo, zoom and
  drawing*, none of them editability. There is no `-readonly`, `-view`, or
  `-noedit`.
- **No command-line flag.** The startup option parser (`options.c`) has
  `-x/--no_x` (headless), `-b/--detach`, output/netlist selectors, etc., but
  nothing like `--readonly` or `--view`. (Note `-r` is already taken — it
  means `--no_readline`, not read-only.)
- **No write-permission awareness at open time.** XSCHEM does not `access(…,
  W_OK)` a file when loading it and does not warn that a file is unwritable.
  The permission check happens only at *save*: `save_schematic()`
  (`save.c:~3470`) just does `fopen(schname, "w")` and, if that fails, pops
  `alert_ {file opening for write failed!}`. So you discover a file is
  read-only on the filesystem only when you try to save it.
- **The `modified` flag is not a lock.** `xctx->modified` (set via
  `set_modify()`) only drives the "save your changes?" prompt on close/reload;
  it never prevents an edit.

**The closest things that *do* exist** (and how you might lean on them):

1. **Per-element `lock` attribute.** Any object can carry `lock=true` in its
   property string; `select.c` (the `select_*` functions, ~lines 896–1226 for
   wire / inst / text / rect / poly / line) refuses to select a locked object
   for editing unless you override with Shift-click. This is *per-object, not
   per-file*, it's bypassable, and it doesn't stop programmatic edits — but it
   is the only built-in "don't touch this" mechanism. A script could stamp
   `lock=true` on everything to approximate a soft read-only.
2. **Filesystem permissions.** `chmod -w file.sch` genuinely protects the file
   on disk — XSCHEM will let you open and edit the in-memory copy, but the
   eventual save fails loudly. Read-only-on-disk plus "don't save" is the
   honest current workaround for "I just want to look."
3. **Headless inspection.** For pure querying with zero risk of mutation,
   `xschem -x -q --script <file>` (or `--pipe`) loads the file and lets a
   script read it via the `xschem` query commands without ever opening an
   editable window.

If a real read-only mode were wanted, the natural shape — given the
stable-handles direction — would be a context-level `read_only` flag checked at
the mutation funnel (the same chokepoint the handle work is building), plus an
`access(W_OK)` probe at load that sets it automatically for unwritable files.
That is not implemented; it is noted here as the obvious place it would go.

---

## Q9. What support is there for multiple open schematics/symbols — windows and tabs?

- **Asked:** 2026-06-12
- **Project state:** branch `feature/stable-object-handles` @ `10c3f2f8`.

**Good support — XSCHEM can hold many schematics/symbols open at once, in
either tabs or separate windows, each with its own fully independent state.**
The key facts:

**Two interchangeable modes, one switch.** The Tcl boolean
`tabbed_interface` (`xschem.tcl`, `set_ne tabbed_interface 1` — **default on**)
chooses between:
- **Tabbed** — all schematics share one top-level X11 window, switchable via a
  tab bar (`create_new_tab` / `switch_tab` / `destroy_tab` in `xinit.c`);
- **Windowed** — each schematic gets its own top-level window
  (`create_new_window` / `switch_window` / `destroy_window`).
`new_schematic()` (`xinit.c`) reads the flag at runtime and dispatches to the
right pair, so the *same commands* drive both.

**Each open schematic is a separate `Xschem_ctx`.** This is the important part
for scripting: every tab/window owns a complete, independent copy of the editor
state — its own `wire[]`, `inst[]`, selection, undo stack, zoom, hierarchy
stack, *and (per the stable-handles work) its own wire-id counter.* They live
in a `save_xctx[MAX_NEW_WINDOWS]` array (`xinit.c`); the global `xctx` always
points at the active one, and switching tabs/windows just repoints it. A wire
id is unique **within one context**, not across contexts — two tabs can both
have a wire with id 5.

**The Tcl commands a script uses** (all verified against `scheduler.c`):

| Command | What it does |
| --- | --- |
| `xschem new_schematic create <win_path> [file]` | open a new tab/window (empty, or with `file` loaded). `win_path` is `{}` for auto, or e.g. `.x1.drw` |
| `xschem new_schematic switch <win_path>` | make that tab/window active (`win_path` may be `previous` or a schematic name) |
| `xschem new_schematic destroy <win_path>` | close one tab/window |
| `xschem new_schematic destroy_all [force]` | close all extra tabs/windows |
| `xschem tab_list` | list every open tab/window as `{win_path} {filename}` rows |
| `xschem get current_win_path` | path of the active tab/window (`.drw` for the main one, `.x1.drw`, `.x2.drw`, …) |
| `xschem get ntabs` | number of *extra* tabs (0 = only the main one) |
| `xschem get schname` / `sch_path` / `currsch` | name / hier-path / hierarchy level of the active context |

**The hard limit is `MAX_NEW_WINDOWS = 20`** (`xschem.h`) — try to open a 21st
and `create_new_window` / `create_new_tab` refuse with "no more free slots."

**Don't confuse "open windows" with "hierarchy depth."** These are two
different stacks:
- *Descending* into a sub-circuit (double-click an instance) pushes onto the
  **hierarchy stack** `sch[CADMAXHIER]` (`CADMAXHIER = 40`) **inside the same
  context and the same window** — `currsch` counts the depth (0 at top). You're
  still in one `xctx`, looking deeper into one design.
- *Opening* a file in a new tab/window allocates a **brand-new `xctx`** with its
  own `currsch = 0`. A genuinely separate design, separate undo, separate
  everything.

So "20" bounds how many separate designs you can have open; "40" bounds how
deep you can drill into any one of them.

---

## Q8. Besides wires, what object types does XSCHEM have?

- **Asked:** 2026-06-12
- **Project state:** branch `feature/stable-object-handles` @ `10c3f2f8`.
  The stable-handle work so far covers **wires only**; this question is about
  what the other types are, since they are the roadmap for the rest of the
  identity work.

**XSCHEM schematics/symbols are built from seven drawable object types, plus
the symbol *definition* that instances point at.** They are all defined
together near the top of `xschem.h` and each lives in its own array on `xctx`.
The type constants (`xschem.h:265–271`) double as a bitmask:

| Const (value) | Struct | `xctx` array | What it is |
| --- | --- | --- | --- |
| `WIRE` (1) | `xWire` | `wire[]` | a net segment (the type the handle work started on) |
| `xRECT` (2) | `xRect` | `rect[layer][]` | rectangle / box — also pins, graphs, embedded images (by layer) |
| `LINE` (4) | `xLine` | `line[layer][]` | a graphical line (by layer) |
| `ELEMENT` (8) | `xInstance` | `inst[]` | a placed **component instance** (a reference to a symbol) |
| `xTEXT` (16) | `xText` | `text[]` | a text label / annotation |
| `POLYGON` (32) | `xPoly` | `poly[layer][]` | a polyline / polygon (by layer) |
| `ARC` (64) | `xArc` | `arc[layer][]` | a circular arc or (via attrs) circle/ellipse (by layer) |

And separately:

- **`xSymbol`** (`sym[]`) — a loaded **symbol definition** (the master). It is
  not a placed object you draw; it is the template an `xInstance` references.
  Editing a `.sym` file edits one of these; placing it in a schematic creates
  an `xInstance` (`ELEMENT`) that points at it.

**Two structural facts a script author should know**, because they shape how
each type is addressed and how much identity work each will need:

1. **Three types are flat arrays; four are per-layer.** `wire`, `text` and
   `inst` are single arrays indexed by one number — hence `xschem select wire
   5`, one index. But `rect`, `line`, `poly` and `arc` are arrays *per drawing
   layer* (`xRect **rect;` = one array per `cadlayers`) — so they are addressed
   by **(layer, index)**: `xschem select rect <color> <n>`. That extra
   coordinate is why their commands look different from wires'.
2. **The scatter the identity work has to tame differs by type.** Instances are
   the planned next target precisely because they have the worst remaining
   lifecycle scatter (`xctx->instances++` happens in `paste.c`, `move.c`,
   `actions.c`, …), the mirror image of the wire situation that Q7 describes.
   The recipe proven on wires — census every birth/death/compaction site,
   funnel them through one family of functions, then stamp a per-context
   monotonic id at the funnel — repeats type by type. Wires were chosen first
   as the simplest specimen; instances, then the per-layer graphical types,
   follow the same playbook.

The asymmetry in *query* support across these types (instances are addressable
by name and have a rich query family; wires and the graphical types are
index-only) is catalogued in `tcl_introspection_wire.md` §3 — that, plus
identity, is what the uniform `xschem object` API is eventually meant to even
out.

---

## Q7. Toward "anything through code": what is the *first* thing to address in the code?

- **Asked:** 2026-06-12
- **Project state:** branch `feature/stable-object-handles` @ `cdf9bd9e`. The
  Tcl-introspection analysis (`tcl_introspection_wire.md`) and the C-vs-C++
  objects tutorial are committed; no design or implementation yet.
- **Context:** the end goal is SKILL-class scriptability — the user can query
  and drive everything from code. Wires were the probe specimen. What's the
  keystone change?

**Not the handles themselves — the fact that the object store has no owner.**
The expectation was that `storeobject()` (`store.c:226`) is the single factory
for wires. Grepping disproved it: `xctx->wires++` also happens at **four
sites inside `check.c`** (236, 520, 595, 685 — the connectivity checker
splits and creates wires directly), and `xctx->instances++` happens in
`paste.c`, `move.c` and `actions.c`. Deletion/compaction is similarly
scattered (`check.c:298,399`, `move.c:147`, `select.c:513`).

Every capability the goal decomposes into — stable ids, coherent caches,
undo-safe references, mutation logging, change events — needs to hook the
same three events: *object born, object died, object moved in memory*. Today
those events have half a dozen doors each. So the first move is a **pure,
behavior-identical refactor: funnel object lifecycle through one chokepoint
per event.** It is the same move that already paid off twice in this
codebase: the `scheduler()` command funnel made action-logging nearly free,
and the binding-table funnel made key remapping free. xschem funnels
*commands*; it has never funneled *state mutation* — that is the missing
half of the architecture.

Build order that falls out by dependency: (1) census + funnel (verbatim,
characterization-tested); (2) identity — stamp a monotonic id at the funnel's
birth point, maintain id→index at death/compact; (3) coherence — cache
invalidation moves into the funnel, killing the stale-query bug class
wholesale; (4) only then the user-visible uniform API (`xschem object @id`,
selection as ids). Constraints carried from day one: both undo backends must
round-trip identity (memory undo copies structs — free; disk undo
round-trips through the `.sch` format — needs a decision), and the drawing
hot path stays untouched (the funnel costs one call on human-speed mutation
only).

---

## Q6. Is it true C is a subset of C++?

- **Asked:** 2026-06-12
- **Project state:** branch `feature/stable-object-handles` @ `cdf9bd9e`,
  right after the C-vs-C++ objects tutorial (`objects_in_c_vs_cpp.md`) landed.

**Almost, but not literally — and the gap runs in three layers** (all
demonstrated live with gcc/g++ during the session):

1. **Valid C that C++ rejects:** `int *new = malloc(n)` fails twice over —
   `new` is one of ~30 extra C++ keywords, and C++ forbids the implicit
   `void *` conversion every C `malloc` call relies on. `char *s = "hello"`
   loses the `const`. Plus implicit function declarations, K&R definitions,
   tentative definitions — the C89 idioms.
2. **Valid C that C++ never adopted:** VLAs, `restrict`, flexible array
   members, `_Generic`, compound literals, full C99 designated initializers.
   Modern C is not contained in modern C++ either.
3. **The dangerous layer — compiles in both, means different things:**
   `sizeof('a')` is **4 in C** (character constants are `int`) and **1 in
   C++** (`char`); file-scope `const` linkage differs; enum conversions
   differ. No diagnostic fires.

What people correctly mean is the pragmatic version: a large common dialect
("Clean C") compiles identically under both, and xschem's C89 is a few
mechanical fixes from it. For the handles work the relevant direction is:
everything in the tutorial — factory functions, deep-copy discipline,
accessor-only mutation, generational handles — is expressible in C89. We
borrow C++'s *design ideas*, not its syntax.

---

## Q5. Is the CIW a full-fledged Tcl interpreter? And what would Ctrl-Backspace word-delete and Up-arrow history take?

- **Asked:** 2026-06-11
- **Project state:** branch `feature/action-logging` @ `094ee4a2`. Phase 0 (log
  file), the CIW (incl. the sash UX rework), Layer A slice 1 (Tcl-backed action
  logging) and `--nolog` are done; Layer A slice 2 is planned.
- **Prompted by an experiment:** the user typed `set a 10`, `set b 20`,
  `expr {$a + $b}` into the CIW and it printed `30`.

**Yes — and it's even better (or scarier) than "a" Tcl interpreter: it is THE
application's own interpreter.** When you press Return, the CIW runs your line
with `uplevel #0 $cmd` — "evaluate this at the top level of the running
program." There is no sandbox, no separate baby interpreter. That has three
consequences worth understanding:

1. **State persists between commands.** Your `set a 10` created a real global
   variable in the live program — that's exactly why `expr {$a + $b}` could see
   it two commands later. You can define procs, run loops, `source` whole
   files.
2. **You share the interpreter with the GUI itself.** Everything xschem's menus
   and dialogs can do, you can do — reconfigure widgets, call any `xschem …`
   subcommand. The flip side: a long-running loop freezes the UI until it
   finishes, because your command runs on the same thread that redraws the
   screen.
3. **Your session is being recorded.** Successful commands are appended to
   `Xschem.log` (that's the design — the file is a faithful, replayable session
   record), so `set a 10` is now part of the log. Failed commands are written
   as `# failed:` comments so replaying the file never aborts.

One honest limitation: each Return must be a **complete** command. The CIW
doesn't (yet) check `info complete`, so you can't type an open
`foreach x {1 2} {` and finish it on the next line — it errors immediately.
Type the whole construct on one line (it wraps in the entry area).

**What the two conveniences take — both are small, pure-Tcl widget bindings in
`ciw.tcl`; no C changes at all:**

*Ctrl-Backspace deletes a word.* Tk's text widget doesn't bind
`<Control-BackSpace>` by default on X11, but its index arithmetic does all the
real work — `{insert -1c wordstart}` literally means "the start of the word
just before the cursor":

```tcl
bind .ciw.c.e <Control-BackSpace> {
  .ciw.c.e delete {insert -1c wordstart} insert
  break    ;# stop the class binding from ALSO deleting one character
}
```

The only refinement worth adding is shell-like whitespace handling (skip the
spaces behind the cursor first, then eat the word) — a few more lines.

*Up/Down recalls history.* Three pieces, ~15 lines:
1. a global list that `ciw_exec` appends each executed command to;
2. `<Up>`/`<Down>` bindings that replace the entry's content with the
   previous/next list item (each ending in `break`, so the cursor-movement
   class binding doesn't fire);
3. the standard nicety: the first Up stashes whatever you'd half-typed, so
   pressing Down past the newest entry brings your draft back.

One design trade-off to know about: because the entry is now a multi-line-
capable text widget, Up natively means "move the cursor up one display line"
inside a tall, wrapped command. Binding it to history steals that. The simple
answer (what terminals and Virtuoso do) is history-always; the fancier version
triggers history only when the cursor is on the first display line.

Both features are listed in the spec's §6 "explicitly not v1" bucket — doing
them is consciously pulling future items forward, justified because they're
cheap and the CIW is a window you type into constantly.

## Q4. So far, how has this work made the code easier to read and maintain?

- **Asked:** 2026-06-08
- **Project state:** branch `feature/action-registry` @ `21ea55f4`. We are partway
  through **Phase 3c** (moving keyboard/mouse handling into the lookup table); the
  scroll wheel, the right-drag zoom gesture, the no-modifier `f` and arrow keys, and
  the graph-routing of six more keys are done. **Phase 3d** (deleting the old
  hard-wired code) has not started.

**The honest headline first: the code is currently a bit *longer*, not shorter.**
This phase is an investment. We added the new "controls list" machinery (the lookup
table, the part that reads it, and the commands to edit it) *before* we could start
removing the old hard-wired handling. So the file grew by roughly 425 lines. That
reverses later, in Phase 3d, when the old code gets deleted now that the new system
can replace it. So far we've only begun that removal (about 30 lines gone in the
most recent step).

**What is genuinely easier to read today:**

1. **Commands have names now.** Before, what a key did was spelled out as raw math
   and function calls buried inside one enormous 1,600-line block. Now each behavior
   is a small, clearly named piece (e.g. "zoom full", "scroll up", "hand this to the
   waveform graph"). You can tell what a key does by its name instead of decoding it.

2. **"Which key does what" is now a plain list, separate from "what it does."**
   Previously those two ideas were tangled together in every case. Now there's an
   editable list of "this input → this command," and you can print the whole list
   with one command to see every shortcut at a glance. That single, readable
   overview simply did not exist before.

3. **A copy-pasted block is being deleted.** The exact same five-line check —
   "if the mouse is over a waveform graph, hand the event to the graph" — had been
   pasted into the code about twenty times. We've removed it from the scroll-wheel
   handling entirely and from six keyboard shortcuts so far, each time replacing the
   duplicated code with a single line in the list. More removals are queued.

4. **One shared path instead of three different ones.** The wheel, the mouse-drag
   gestures, and the keyboard now all flow through the same handling, with one clear
   rule for which binding wins. A maintainer learns one mechanism, not three.

5. **The tricky, easy-to-break details are now written down.** The handful of subtle
   rules that used to be invisible traps (why certain shortcuts must stay as-is, why
   one check has to happen before another) are now explained in comments right where
   they matter, plus a short tutorial and these FAQ entries — so the next person
   doesn't have to rediscover them the hard way.

**Bottom line:** any individual shortcut is clearer (named, self-explaining, with its
reasoning attached), and the system as a whole is now navigable through one readable
list instead of a giant undocumented block. The raw line count is temporarily higher;
it drops below where it started once Phase 3d removes the now-replaceable old code.

---

## Q3. In plain language (high-school level): what are the next couple of steps, and what's the end goal?

- **Asked:** 2026-06-08
- **Project state:** branch `feature/action-registry` @ `cd5b5c9a` (wheel, zoom-rect
  gesture, and the no-modifier `f` + arrow keys are data-driven; Group B sweep next).

**Next couple of steps**

1. **"Group B" keys sweep.** A handful of keys (`a`, `b`, `s`, Ctrl+tab-switch
   arrows, …) each carry a copy-pasted "if the mouse is hovering over a waveform
   graph, hand this to the graph instead" check buried in a 1600-line block of C.
   The next step lifts just that check out into the lookup table (a plain list of
   "this input → does that"). The keys' normal jobs (open a dialog, save a file)
   stay in C; only the graph-routing part becomes data. This deletes a lot of
   duplicate code. (Caveat found while scoping: some of these keys check an
   "are we busy?" counter *before* the graph check, so they must be migrated
   carefully or deferred — see the semaphore-ordering note in the Phase 3c work.)
2. **Let an action run a Tcl command, not just C.** Today the table can only point a
   key at a built-in C function. Most menu items are written in Tcl (the scripting
   layer). Teaching the table to also say "this key runs *this script command*"
   unlocks migrating dozens more keys.

**End goal (the analogy)**

Think of a TV remote whose buttons are *soldered* to fixed jobs — you can't make the
red button do the green button's thing without rebuilding the remote. That's how
XSCHEM's keyboard/mouse handling works today: every shortcut is hard-wired deep in
the code.

We're replacing it with a **"Controls" settings list**, like the rebind-your-keys
menu in a video game. One master list says *"this key / mouse button / scroll does
this action,"* and:

- **You can edit it** in a config file to remap anything — no recompiling. (Already
  true for the scroll wheel and the arrow keys; see Q2.)
- **The help/cheat-sheet builds itself** from that same list, so it can't drift out
  of sync with what the keys actually do.
- Once everything is moved over, the old hard-wired code is **deleted**, leaving the
  program smaller and easier to maintain.

In one line: **turn soldered buttons into a remappable controls menu — for every
key, mouse button, and scroll — and let the help screen generate itself from it**,
done one small, fully-tested batch at a time so nothing breaks.

---

## Q2. Can a user remap the mouse wheel — **Ctrl+wheel = zoom, plain wheel = vertical pan, Shift+wheel = horizontal pan** — via `.xschemrc` / `--script`? (And why didn't the original author's `replace_key` snippet work?)

- **Asked:** 2026-06-08
- **Project state:** branch `feature/action-registry` @ `bfec8793` (Phase 3a wheel
  fully data-driven; 3b gestures; 3c c4/c5 first key `f`). Wheel dispatch goes
  through the in-C binding table (`xschem bind wheel ...`).

**Answer: Yes — fully supported and verified.** Put these in `~/.xschem/xschemrc`
(or `./.xschemrc`, or a `--script` file):

```tcl
# zoom with Ctrl+wheel
xschem bind wheel up   ctrl canvas view.zoom_in
xschem bind wheel down ctrl canvas view.zoom_out
# vertical pan with plain wheel
xschem bind wheel up   0    canvas view.pan_up
xschem bind wheel down 0    canvas view.pan_down
# Shift+wheel already pans horizontally (view.pan_left / view.pan_right) by default
```

Verified against observable state after firing synthetic wheel events
(`xschem callback .drw 4 <mx> <my> 0 <4|5> 0 <state>`; state 0/1/4 = plain/Shift/Ctrl):

| Input | Result | Verdict |
|---|---|---|
| plain wheel | `zoom` unchanged, `yorigin` moves | vertical pan ✅ |
| Ctrl+wheel  | `zoom` changes                   | zoom ✅ |
| Shift+wheel | `zoom` unchanged, `xorigin` moves | horizontal pan ✅ |

`xschem bindings dump` reflects the swap. (Swap `up`↔`down` for the opposite scroll
direction.) Timing is safe: `xschem bind` calls `ensure_input_bindings()`, which
lazily seeds the defaults *then* applies the override; `init_input_bindings()` is
guarded by `input_bindings_initialized`, so it never re-runs and clobbers the user's
rows — order of `.xschemrc` vs GUI bring-up does not matter.

**Why the original author's `replace_key` snippet didn't work.** `replace_key` is a
separate, *older, Tcl/Tk-level* mechanism (`set_replace_key_binding` →
`key_binding`, xschem.tcl:10994/1121). It installs a more-specific Tk binding such
as `<Control-Button-4>` that re-emits an `xschem callback` with a **rewritten
modifier mask** (e.g. mapping `Control-Button-4` → the state of a plain
`ButtonPress-4`), tricking the C wheel handler into seeing a different chord. It is
fragile in ways that bite silently:

- **Tk 8.7 / 9.0 deliver the wheel as `<MouseWheel>`, not `<Button-4/5>`**
  (xschem.tcl:9981 only binds `<MouseWheel>` when `tclversion > 8.7`). On those
  builds the `<Control-Button-4>` overrides never fire — the physical event isn't a
  Button-4 event. **Most likely cause of the failure.**
- Depends on Tk binding-specificity and on which widget (`.drw` vs the toplevel) the
  generic `<ButtonPress>` (xschem.tcl:9996/9998) vs the `replace_key` binding land
  on — subtle, easy to get subtly wrong.
- Piggybacks on the C button-mask stripping (`callback.c:4507`) as an undocumented
  implementation detail.

**Why the binding table is robust instead.** It dispatches **in C, after** the
event is normalized to "wheel up/down + clean modifier mask" — independent of Tk
version or how Tk delivered the event. It is the intended replacement for
`replace_key` for wheel/button/(now) key remapping.

**Caveats.**
1. Over a waveform graph, plain/Shift wheel still routes to the graph
   (`graph.forward` over_graph rows, unchanged); the canvas rebind only affects
   bare-canvas wheeling. Ctrl+wheel stays canvas-zoom even over a graph (its branch
   in `handle_mouse_wheel` forces `ctx=ACTX_CANVAS`).
2. Keep `graph_use_ctrl_key` at its default `0`. Setting it `1` reserves Ctrl+wheel
   for graph interaction, and `handle_mouse_wheel` returns early for Ctrl — so the
   canvas zoom binding won't be reached.

---

## Q1. Can a user remap the zoom-rectangle gesture from RMB-drag to **Ctrl+RMB-drag** with the current code?

- **Asked:** 2026-06-08
- **Project state:** branch `feature/action-registry` @ `898639af` (Phase 3a/3b done,
  Phase 3c c4/c5 first batch — key `f` — done). Mouse buttons: only the *bare*
  Button3 zoom-rect chord is data-driven (Phase 3b).

**Answer: No — not with the code at that commit, even though the binding can be created.**

`xschem bind button 3 ctrl canvas view.zoom_rect` parses and stores a valid row
(`parse_mods("ctrl") → ControlMask`, code 3). But the **press handler never reaches
the table dispatcher for a *modified* Button3 chord.**

`handle_button_press` (`callback.c`) is an `if / else-if` chain, and the data-driven
`dispatch_button_chord()` sits at the *end* of it (`callback.c:4560`). Earlier
`if`/`else if` branches hardcode the modified-Button3 chords and match first:

```c
if     (!excl && button==Button3 && state==ControlMask && semaphore<2) { … select_connected_nets(1); }  // 4522 ← Ctrl+RMB caught HERE
else if(!excl && button==Button3 && EQUAL_MODMASK && …)                { break_wires_at_point(…); }       // 4530/4536  (Alt+RMB)
else if(!excl && button==Button3 && state==ShiftMask && …)             { select_connected_nets(0); }      // 4542  (Shift+RMB)
…
else if(!excl && semaphore<2 && dispatch_button_chord(button, state, mx, my)) return;                      // 4560 ← table only reached here
```

`state` *is* correctly button-mask-stripped at `callback.c:4507`, so
`dispatch_button_chord` would see `mods==ControlMask` and *could* match the row — but
it is never called for Ctrl+Button3 because the hardcoded branch at 4522 wins and the
dispatch is in a later `else if`. Only **bare** Button3 falls through (the plain-RMB
context menu was moved to the release path, freeing the no-modifier slot).

**The completion side is already ready.** On Ctrl+RMB *release*, `state ==
Button3Mask|ControlMask`, so the exact-match context-menu branch
`if(state == Button3Mask)` (`callback.c:4779`) is skipped and the Phase 3b
fallthrough `else if((ui_state & STARTZOOM) && semaphore<2) end_place_move_copy_zoom()`
(`callback.c:4789`) completes the gesture. So only the **initiation** is blocked.

**What it would take** (a natural Phase 3 follow-on, same pattern as the key work):
1. Extract the hardcoded modified-Button3 branches into `act_*` fns
   (`select_connected_nets`, `break_wires_at_point`) + `{button 3 ctrl/shift/alt
   canvas}` rows; **or**
2. Move `dispatch_button_chord` earlier so a user-bound chord pre-empts the hardcoded
   default ("table-first, hardcoded-fallthrough" precedence, like the keys now have).

**UX consequence:** Ctrl+RMB is already a feature (select instance + connected nets,
stopping at junctions), so rebinding it to zoom means relocating that feature to
another chord.
