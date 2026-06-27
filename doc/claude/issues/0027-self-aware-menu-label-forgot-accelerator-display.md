# Issue 0027 — Self-aware "Make Editable / Make Read Only" menu item showed no `Ctrl-2` / `Ctrl-Shift-2` accelerator

**Opened:** 2026-06-23
**Status:** ✅ RESOLVED 2026-06-23 (branch `fluid-editing`). `edit_menu_post` now reconfigures
`-accelerator` alongside `-label` on the read-only toggle entry: `Ctrl+2` while the view is
read-only (the label is "Make Editable"), `Ctrl+Shift+2` while editable (label "Make Read
Only"), mirroring the `cadence_style_rc` binds. Tcl-only change, no rebuild.
**Affects:** the Edit-menu read-only toggle added with the read-only-enforcement work
(`edit_menu_post` / the `Make Read Only` command entry, `src/xschem.tcl`). The keys themselves
were always bound (`src/cadence_style_rc` lines 107–109); only their *display* on the menu was
missing.
**Severity:** low — cosmetic/discoverability. The commands and the keys worked; the menu just
didn't advertise the shortcut, so a user couldn't learn the keystroke from the menu.
**Branch:** `fluid-editing`. See [[readonly-enforcement]], [[descend-readonly]],
[[action-registry]]. Sibling of 0026 (another "GUI-only affordance, not surfaced by headless
verification" miss).

---

## 1. Symptom

Open the **Edit** menu. The dynamic entry correctly reads "Make Editable" (when the view is
read-only) or "Make Read Only" (when editable), but the right-hand **accelerator column is
blank**. The expected hints are `Ctrl+2` for *Make Editable* and `Ctrl+Shift+2` for *Make Read
Only* — and those keys actually work (they are bound in `cadence_style_rc`), they just aren't
shown.

## 2. Root cause

Two compounding gaps, both rooted in the same Tk fact.

**Tk fact:** a menu entry's `-accelerator` is a *pure display string*. It is **not** derived
from any `bind`; Tk never looks at the binding table to populate it. The keystroke lives in one
place, the menu command in a second, and the accelerator text in a third — three independent
facts with no automatic linkage:

```tcl
# (1) the keystroke -> a proc                         src/cadence_style_rc:107-109
bind .drw <Control-Key-2>       {cadence::make_editable; break}
bind .drw <Control-Key-at>      {cadence::make_readonly; break}   ;# Ctrl-Shift-2 on US layout
bind .drw <Control-Shift-Key-2> {cadence::make_readonly; break}

# (2) the menu command (a DIFFERENT proc, same effect) src/xschem.tcl:11491
$topwin.menubar.edit add command -label "Make Read Only" -command toggle_readonly

# (3) the accelerator text -- was simply never set
```

**Gap A — the entry was created without any `-accelerator`.** The `add command` above carried
`-label` and `-command` only, so even before any dynamic flipping the accelerator column was
empty.

**Gap B — the self-aware `-postcommand` flipped only `-label`.** Making a menu entry
state-aware means its *creation-time* options go stale and must be recomputed every time the
menu is posted. `edit_menu_post` reconfigured the label per window but nothing else:

```tcl
# src/xschem.tcl  (before)
if {$cmd eq "toggle_readonly"} {
  $m entryconfigure $i -label [expr {$ro ? "Make Editable" : "Make Read Only"}]
  break
}
```

So `-accelerator` was both never-set *and* never-flipped — even if Gap A had been fixed with a
single static accelerator, it would then be *wrong* in one of the two states, because the
correct hint differs per state (`Ctrl+2` vs `Ctrl+Shift+2`).

## 3. Fix

Recompute `-accelerator` in lockstep with `-label` in the post-command:

```tcl
# src/xschem.tcl:10153-10158  (after)
if {$cmd eq "toggle_readonly"} {
  # accelerators mirror cadence_style_rc: Ctrl-2 -> make editable (shown while
  # read-only), Ctrl-Shift-2 -> make read only (shown while editable).
  $m entryconfigure $i \
    -label       [expr {$ro ? "Make Editable" : "Make Read Only"}] \
    -accelerator [expr {$ro ? "Ctrl+2"        : "Ctrl+Shift+2"}]
  break
}
```

The accelerator strings are intentionally *hand-kept in sync* with the `cadence_style_rc` binds
— Tk gives us no way to ask "what is bound to this command?", so the menu can only echo what we
assert. See §6 for the residual smell this leaves.

## 4. Why this wasn't caught proactively

Worth dwelling on, because the miss is instructive rather than careless:

1. **Inherited the omission.** The item this replaced — `View > "Toggle read-only"` — had no
   accelerator either. When I moved/renamed it into the Edit menu I carried its option set
   forward verbatim and never asked "should this now advertise a shortcut?" Refactors copy
   *bugs of omission* as faithfully as they copy code.

2. **Two subsystems, one mental boundary.** The `Ctrl-2` / `Ctrl-Shift-2` binds live in
   `cadence_style_rc` + `utils/cadence_nav.tcl` (the Cadence-nav feature, [[descend-readonly]]);
   the menu lives in `xschem.tcl`. I was editing the menu and never had the binds in view, so I
   didn't connect "I am building the discoverability surface for an action" with "that action
   already has a keystroke users should learn." The menu item *is* the place those binds become
   discoverable — that relationship wasn't in my model because the two halves sit in different
   files owned by different features.

3. **"Self-aware label" was scoped too narrowly.** I correctly reasoned "the label must flip,"
   but stopped at the one option the user named. The general rule — *when one option on a menu
   entry becomes state-dependent, audit every other state-dependent option on that same entry*
   (`-accelerator`, `-state`, `-image`, `-command`) — wasn't applied. I treated `-label` as the
   feature instead of "this entry is now dynamic."

4. **Headless verification can't see it.** All my automated checks ran `--nogui`, which never
   builds or posts the menubar, so `entryconfigure`/`-accelerator` are never exercised. A
   blank-but-present accelerator produces no error, no log line, no test failure — it is only
   visible to a human posting the menu. This is the same class as 0026 and 0016: **GUI-only
   affordances are invisible to headless suites**, so they need an explicit "open the menu and
   read it" step in the human smoke test, which I didn't script or request.

The throughline: the bug lived in the *seam* between three things (a keybind, a menu command,
and a display string) that Tk deliberately keeps decoupled, and my testing method was blind to
that seam.

## 5. The transferable lesson

- **In Tk, `-accelerator` is decorative.** It documents a binding; it does not create or read
  one. If you show it, you own keeping it true; if you bind a key, nothing shows it for you.
- **A dynamic menu entry owns *all* its dynamic options.** The moment a `-postcommand` (or any
  `entryconfigure`) drives one option from state, every other option that depends on the same
  state must be driven from the same place, or it silently goes stale/blank.
- **A menu/command-palette entry is the discoverability surface for its keystroke.** When you
  add or move one, check whether the action has a bind, and surface it.
- **Headless ≠ verified for GUI affordances.** Greenfield rule from 0016/[[green-but-hollow]]:
  a passing `--nogui` run says nothing about menus, accelerators, greying, tooltips, or
  cursors. Those need a scripted human step.

## 6. Residual smell / follow-ups

- **The accelerator is truthful only where the bind exists.** `cadence_style_rc` binds the keys
  on `.drw` (the main window's canvas). On a detached window (`.xN.drw`) the menu will now still
  *show* `Ctrl+2` / `Ctrl+Shift+2`, but the keys don't fire there — same root as 0020 (binds not
  cloned per window). Two honest options: (a) extend the cadence binds to every window's canvas,
  or (b) gate the accelerator string on `[bind <thiswin>.drw <Control-Key-2>] ne ""` so the menu
  only advertises a shortcut it can deliver. Deferred; tracked here.
- **The hint is hand-synced to the bind.** If someone rebinds make-editable/read-only in their
  rc, the menu text lies. A small registry mapping action → (label, accel, command), consulted by
  both the binder and `edit_menu_post`, would remove the duplication — a natural fit for the
  [[action-registry]] direction (its `ActionDef` already carries `help`; an `accel`/`label`
  field would let menus and the cheat-sheet derive display text from one source of truth).

## 7. Tests

No headless RED is possible (menubar isn't built under `--nogui`). Verification was by
inspection + a GUI smoke step:

1. Descend into a cell (read-only) → Edit menu shows **Make Editable** ··· **Ctrl+2**.
2. Click it (or press Ctrl-2) → editable → Edit menu now shows **Make Read Only** ··· **Ctrl+Shift+2**.
3. Open a view in edit mode → Edit menu shows **Make Read Only** ··· **Ctrl+Shift+2** from the start.

If/when a menubar GUI harness exists, assert `[$m entrycget <idx> -accelerator]` flips with
`xschem set readonly 0|1` across a `edit_menu_post` call. Sabotage-verify by dropping the
`-accelerator` line and confirming the column goes blank.
