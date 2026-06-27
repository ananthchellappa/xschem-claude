# Issue 0034 — animated highlights (blink / marching ants) freeze after moving through the hierarchy

**Opened:** 2026-06-25
**Status:** ✅ RESOLVED (2026-06-25) — added a single `net_hilight_anim_update()` re-arm
call at the tail of each traversal path now that `xctx` is the destination context:
`descend_schematic()` (after the read-only block, guarded by `descend_ok`),
`go_back()` (after the final `draw()`), and `descend_symbol()` (before `zoom_full`/return).
The call is idempotent (the per-window Tcl proc cancels any existing `after` before
re-arming) and cheap (the issue-0032 short-circuits collapse it to one boolean read when
nothing animates). The new-window descend path (`open_sub_schematic` →
`xschem descend`) is covered transitively, since the C re-arm fans out to **every** open
window. Verified with a GUI probe (`scratchpad/probe_0034.tcl`): an animating style
installed + the per-window `net_hilight_anim_update {win}` proc wrapped with a counter —
descend bumps it 0→1 and ascend 1→2 (was 0/0 before). Sabotage-verified: neutralizing the
two re-arm calls drops both deltas to 0 (the frozen bug), restoring them returns 1/1.
Regression suites (`create_save`/`open_close`/`netlisting`) green; clean build, no warnings.
**Affects:** `descend_schematic()` (`src/actions.c` ~2682–2704), `descend_symbol()`
(`src/save.c`), `go_back()` (ascend/pop), `load_schematic()` (`src/actions.c`) — i.e.
every hierarchy-traversal path. Animation re-arm lives in `net_hilight_anim_update()`
(`src/hilight.c:2895`); the per-window tick is `draw_hilight_region()` /
`net_hilight_anim_tick` driven by `xschem get net_hilight_animated`.
**Severity:** medium — visual/UX only (correctness of the highlight set is fine), but
it directly defeats the debugging workflow the animated styles exist for.
**Branch:** `fluid-editing`. See [[net-hilight-styles]], [[multi-window-detach]],
`doc/claude/specs/net_hilight_styles.md`, `doc/claude/specs/hi_descend.md`. Sibling perf issues that touched
the same fan-out: 0030, 0031, 0032.

---

## 1. Symptom

Highlight a net with an **animated** style (blink, or marching-ants / march-dash —
the `9`/`8`/`0` styles from `net_hilight_styles`). The net animates correctly. Now
**descend** into a sub-schematic (`E` / `xschem descend`), descend into a symbol, or
**ascend** (`Ctrl+E` / `go_back`). The highlighted nets/pins are still drawn
highlighted in the new level (good — the set is preserved), **but the animation
freezes**: no more blinking, the marching ants stop moving. It stays frozen until the
next *highlight mutation* (another `9`/`8`/`0`, a `hilight`/`unhilight_all`, a
waveform highlight, or a style edit) happens to re-arm the tick.

Opening the child in a **new window/tab** (the `hi_descend target=new_window` /
`open_sub_schematic` path) shows the same freeze in the new context: `copy_hilights`
seeds the highlight set but nothing arms that window's animation tick.

## 2. Root cause

The per-window animation tick is **armed only from highlight-mutation paths**.
`net_hilight_anim_update()` (which arms/cancels the `after` tick for each window via
the Tcl `net_hilight_anim_update {win}` → `xschem get net_hilight_animated`) is
invoked from the *change* sites only:

```
src/hilight.c:1489   (propagate / apply styled hilight)
src/hilight.c:2327   (hilight)
src/hilight.c:2361   (unhilight_all — stop tick)
src/scheduler.c:2815, 4406, 6931, 8220, 8273  (9/8/0, waveform, edit paths)
```

The **traversal** paths do not call it. `descend_schematic()` re-propagates the
highlights into the freshly-loaded child:

```c
/* src/actions.c — descend_schematic() */
descend_ok = load_schematic(1, filename, (set_title & 1), alert);
if(descend_ok) {
  if(xctx->hilight_nets) {
    prepare_netlist_structs(0);
    propagate_hilights(1, 0, XINSERT_NOREPLACE);   /* set is restored ... */
  }
  ...
}                                                   /* ... but tick is never re-armed */
```

`load_schematic()` swaps `xctx` to a new schematic with its own (un-armed) tick
state, and neither `descend_schematic`, `descend_symbol`, nor `go_back` calls
`net_hilight_anim_update()` afterward. So the animation only resumes by accident on
the next mutation. The recent short-circuit work (issue 0032) made
`net_hilight_anim_update()` cheap to call when nothing animates, so re-arming on
traversal is now inexpensive.

## 3. Fix (sketch)

After a successful hierarchy move, re-arm the animation for the now-current context
(and, for the multi-window descend, the newly created window):

- In `descend_schematic()` and `descend_symbol()`, after the
  `propagate_hilights(...)` / load completes and `xctx` is the child, call
  `net_hilight_anim_update()` (guarded by the existing `xctx->hilight_nets` /
  kill-switch short-circuits so the no-animation case stays a single boolean check).
- Do the same in `go_back()` (ascend) after the parent reloads.
- For `open_sub_schematic` / `hi_descend target=new_window|new_tab`
  (`xschem.tcl:4365`), call it after `copy_hilights` + `new_schematic switch` so the
  new window's tick arms.

A single well-placed re-arm at the end of the common load-into-context tail (e.g.
where `load_schematic` finishes for a descend/ascend) may cover all paths at once —
prefer that over sprinkling calls if the tail is shared. Take care **not** to arm a
tick for a background tab that isn't the focused window beyond what
`net_hilight_anim_update`'s per-window fan-out already handles (it iterates open
contexts via `get_window_ctx`).

## 4. Tests

- **0034-A (GUI/eyeball):** highlight an animated (blink + march) net, descend, then
  ascend — animation continues at every level without any extra keypress. Repeat for
  `descend_symbol` and for `hi_descend target=new_window`/`new_tab`.
- **0034-B (probe):** a counter on `net_hilight_after(<win>)` / the per-window tick —
  after `xschem descend` with an animated net highlighted, the current window has an
  armed tick (was 0 before the fix). Sabotage-verify by removing the new re-arm call →
  the assertion goes red.
- **Regression:** `create_save` / `open_close` / `netlisting` stay green; the issue
  0032 short-circuit GUI test (default table → no fan-out) still passes (re-arm must
  no-op when nothing animates).

## 5. Notes

- Distinct from issue 0032 (which was *over*-calling the fan-out on mutation). This is
  the opposite gap: a traversal path that *should* re-arm and doesn't. The 0032
  short-circuit is what makes the fix cheap and safe to add on the hot descend path.
- Connectivity of the highlight **set** across windows is a snapshot (`copy_hilights`)
  by design; this issue is only about the **animation** not resuming, not about live
  set propagation (that remains out of scope — see `doc/claude/specs/hi_descend.md` §6).
