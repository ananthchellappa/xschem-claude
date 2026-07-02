# Issue 0041 — Read-only enforcement lives at keyboard-dispatch altitude and is bypassable via Tcl edit paths

**Opened:** 2026-06-26
**Status:** ✅ FIXED 2026-07-02 (branch `fluid-editing`) — layered enforcement: keyboard/menu `readonly_block()` + 29 `scheduler_readonly_reject()` Tcl-subcommand guards + action-registry `mutates` flag + `begin_edit()` core backstops (delete/move/copy). A universal store/`push_undo` funnel is infeasible (load/undo-restore/netlist-flatten share it), so the hybrid is the final design. Triaged 2026-07-01: was STILL PRESENT. Real severity **MEDIUM-HIGH** (keyboard/menu paths *are* guarded; exposure is Tcl scripts / command-server / unlisted action-ids, aggravated by the silent no-`*` save via `set_modify()` `ro_suppress` at `actions.c:170-174`). **Priority P1 — pragmatic fix only.** ⚠ The §3 fix-sketch is partly **WRONG**: gating the `store` funnels or `push_undo()` on `xctx->readonly` would break *loading* the read-only file itself (load routes through the store funnels) and break *netlisting* a read-only view (all six backends call `push_undo`). Do the **S–M** fix instead: add `if(xctx->readonly){ciw_echo(...);return;}` to the ~6 unguarded edit subcommands in `scheduler.c` (delete/paste/rotate/flip/move_objects/copy_objects) or their shared cores. A true chokepoint needs a new `begin_edit()` helper threaded only through genuine edit ops (**L**).
**Severity:** HIGH — protection bypass / data integrity; a file-protected schematic can be mutated and
saved with no modified marker.
**Branch:** `fluid-editing`.
**Source:** `/code-review high` this session (workflow `wf_1a6ce6c4-0d9`), finding #3 (CONFIRMED;
merges the two read-only findings — same root cause).
**Affects:** `src/callback.c` `readonly_block()` (:35) + ~45 `if(readonly_block()) break;` guards in
the keyboard switch; the action-binding guard at `callback.c:3136` via `action_id_mutates()`
(`callback.c:3102`, a hand-maintained 9-id allowlist with **default-allow**); the `xschem` Tcl edit
subcommands in `scheduler.c` (delete @1019, flip @1466, `move_objects` @4181, paste @5048, rotate
@6441, …) which have **no** guard; `set_modify()` suppresses the `*` marker on a read-only buffer.
Related: [[readonly-enforcement]], [[descend-readonly]].

---

## 1. Symptom

A read-only (file-protected / browse) schematic can be freely mutated via Tcl scripts, action
bindings, the TCP/stdin command server, or any non-keyboard path — then exported or Saved-As with the
edits. Because `set_modify()` does not flag a read-only buffer modified, the bogus edit shows **no**
`*` marker and does not prompt on close.

## 2. Root cause

Read-only is enforced at **dispatch altitude** with hand-maintained lists, not at the **mutation
chokepoint**. `readonly_block()` and its ~45 call sites guard only the keyboard switch; the
action-binding path guards via a 9-entry `action_id_mutates()` allowlist that returns 0 (non-mutating)
for any id not listed. The actual mutators (`store`, `push_undo`/`set_modify`, the `xschem` edit
subcommands) never consult `xctx->readonly`, so any path that doesn't go through the keyboard switch
edits freely. Every future edit entry point must remember to add its own guard — a leak-by-default
design.

## 3. Fix sketch

Move enforcement to the chokepoint: reject mutation in the shared funnel(s) — e.g. `push_undo()` /
`set_modify(1)` / the `store` registration funnels return early (with a single `ciw_echo`) when
`xctx->readonly`. Then every edit path — keyboard, Tcl subcommand, action binding, command server — is
covered by construction, and the scattered `readonly_block()` guards become a fast-path UX nicety
rather than the sole defense. Verify a `xschem delete`/`paste`/`rotate` on a read-only schematic is a
no-op and leaves the buffer unmodified.

## 4. Acceptance

No edit path can mutate a read-only schematic; the modified marker and save-prompt behavior are
consistent regardless of how the edit was attempted.

## Progress (2026-07-02)

**Done — Tcl command surface closed (the primary documented bypass).** Added a shared
`scheduler_readonly_reject()` helper in `src/scheduler.c` and guarded all **29** mutating `xschem`
subcommands at entry (mirroring the existing `xschem save` guard): copy_objects, cut, delete, flip,
merge, move_objects, paste, rotate, add_graph, add_image, add_symbol_pin, arc, change_elem_order,
instance, line, move_instance, net_label, place_symbol, polygon, rect, reset_inst_prop, text,
trim_wires, wire, undo, redo, align, setprop, replace_symbol. This covers every path that reaches the
dispatcher — Tcl scripts, the persistent/TCP command server, and action-log replay (Tcl-backed action
bindings emit `xschem …` commands, so they are covered too).

Why subcommand-level and not the store funnels / `push_undo()` chokepoint: those cores also run during
legitimate load / descend / undo-restore and netlisting, so gating them would break *loading* the
read-only file and *netlisting* a read-only view (see the §Status triage note). The subcommand guard is
safe precisely because internal machinery calls the C cores directly and never routes through the
`xschem` dispatcher; only user scripts / GUI / command-server / replay do.

Verified headless (`tests/headless/test_readonly_guard.{tcl,sh}`): control proves delete + wire-creation
mutate a *writable* buffer; treatment proves all 29 subcommands are refused with a read-only error and
the instance/wire counts and the `modified` flag are unchanged; non-mutating `select_all`/`get`/
`translate` still work (no over-block). `translate` was deliberately left unguarded — it is a
`@`-token expansion *query* that returns a string, not an object mutation. Core regression suite green.

**Also done (2026-07-02, follow-up commit) — action-registry mutation flag.** The C-backed action path
no longer relies on a hand-maintained allowlist: `ActionDef` gained a `mutates` column and
`action_id_mutates()` (`callback.c`) now returns `find_action_def(id)->mutates`. The 15 previously
allow-listed ids are flagged, plus two that were leaking via the binding path (`sym.place_symbol_pin`,
`tools.insert_polygon` — both Tcl-backed, so also caught by the subcommand guards). A newly-added
mutating action is now covered by construction; dual-use self-gating actions (`edit.add_pin_stubs`,
which also pans on read-only) stay `mutates=0` and are guarded at their core so the shared key still
pans. Verified with a GUI end-to-end test (`tests/headless/test_readonly_action_dispatch.{tcl,sh}`,
needs X): the C-backed mutators `prop.toggle_ignore` (Shift+T) and `sym.attach_net_labels` (Shift+H)
— which have **no** scheduler-guard backup, so their read-only safety depends solely on the flag —
mutate a writable buffer (control) but are refused on read-only, while a non-mutating action (zoom)
still runs.

**Also done (2026-07-02, follow-up commit) — `begin_edit()` core backstops.** Added the canonical
read-only gate `begin_edit(op)` (`actions.c`, declared in `xschem.h`): returns 1 (refuse, with one
dbg/CIW notice) on a read-only buffer, else 0. Woven into the genuine-edit CORES below the entry
guards, so those operations are refused by construction on ANY path that reaches the core, not only the
ones with an entry guard:
- `delete()` (`select.c`) — gated on `to_push_undo` so internal/undo-free cleanups (`delete(0)`, e.g.
  the transient pin-name preview) still run;
- `move_objects()` / `copy_objects()` START (`move.c`) — placed alongside the existing `lastsel==0`
  early return, so a refused START leaves the same clean state (a follow-on END is a no-op).

Why not the "universal store/`push_undo` funnel" from §3: that is **architecturally infeasible here** —
`storeobject`/the store funnels and `push_undo()` also run during load, undo-restore (`pop_undo` →
`read_xschem_file`) and netlist-flatten (all five backends bracket flatten with push/pop on a possibly
read-only view), and there is no single reliable "internal vs user edit" flag at that level
(`no_autosave` covers load but not `pop_undo`/netlist). So enforcement is a **hybrid**: entry-point
guards + core backstops on the geometric-mutation cores; object creation and property edits stay
entry-guarded (their funnels are load-shared). `begin_edit()` is the one primitive to extend for future
enforcement (locked layers, VCS checkout, …).

Verified by **fault injection**: with the scheduler `delete`/`move_objects` entry guards temporarily
removed and rebuilt, the `begin_edit()` core backstops still refuse the edit on read-only (delete: 16
instances unchanged; move: `modified` stays 0, no crash from the START-bails/END-runs path), while a
writable delete still mutates (16→0). Headless 29-subcommand test, GUI action-dispatch test, and the
core regression suite all remain green.

**Enforcement layers now in place (issue resolved):** (1) keyboard/menu `readonly_block()`;
(2) 29 `scheduler_readonly_reject()` Tcl-subcommand guards; (3) action-registry `mutates` flag;
(4) `begin_edit()` core backstops on delete/move/copy. A universal single funnel is infeasible by the
load/netlist sharing above, so the hybrid is the accepted final design rather than an open gap.
- `set_modify()`'s `ro_suppress` is now correct-by-construction (edits can no longer reach it on a
  read-only buffer via any Tcl path); left as defense-in-depth.
