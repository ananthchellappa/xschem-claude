# Phase 3d.5b — dead-remnant audit (verdicts + evidence)

**Status:** DONE. **Branch:** `feature/action-registry`.
**Predecessor:** d5a (`07c1d4d9`, Tk intercept retired). This closes the Phase-3 plan.

Four candidates, each inspected as-is; verdicts:

| Remnant | Verdict | Evidence / action |
|---|---|---|
| Phase-2 accel machinery (`migrated_action_ids`, `accel_to_tk_sequence`, `run_action`, `bind_accelerators_from_table`, `accel_bound_seqs`, `remap_action_accel`) | **DELETE** (151 lines) | Inert since d5a (empty list). Strictly superseded: a "Tcl-only accelerator" is now a Tcl-backed action id + `xschem bind` row — which additionally gets the idle gate, `bindings dump`, the cheat-sheet, and keybindings.csv persistence. Sole caller was xschem.tcl `set_bindings`; no test used the procs after the d5a rewrite (test_remap now asserts they DON'T exist). Tombstone comment left in place. The `accel` **column stays** — menus (`-accelerator`) and the palette display it. |
| Button2 skips in `waves_selected` (callback.c:48/50/52) | **KEEP + document** | Not dead: Button2 is the canvas pan gesture (`handle_button_press` callback.c:4716), and panning must work with the pointer over a graph, so middle-button events must never be treated as graph-targeted. Comment added; noted that if pan is ever migrated (3b-style, bind the initiating chord) the skips go with it. |
| `keys.help` vs generated cheat-sheet | **KEEP + cross-reference** | keys.help documents ALL defaults including un-migrated keys; the generated sheet only shows table-dispatched chords. Deleting either loses information. A note at the top of keys.help now says bindings are remappable and points at Help → "Keybindings (from table)" for the live view. |
| Stale phase comments | **SWEEP done** | xschem.tcl `set_bindings` call-site comment replaced with the retirement note; action_registry.tcl file header rewritten (it claimed the C keysym dispatcher was "untouched" and keyboard truth — pre-Phase-3 text). callback.c registry comments were already refreshed at d4a/d5a; grep for `fold in at d4` / `not yet in actions.csv` is clean. |

Tests: test_remap's "machinery is inert" checks became "machinery is deleted"
(`info procs` empty, `migrated_action_ids` unset). Engine 6/6 + all smokes green.

**This completes Phase 3d (d1, d1b, d2 batches, d3, d4a/b, d5a/b).** Remaining
un-migrated chords are structurally parked (dialogs, semaphore-manipulating,
unconditional symbol keys, cadence_compat-gated) — revisit on concrete need.
Next direction is a user decision: (a) generate more menus from actions.csv,
(b) `xschem action <id>` palette dispatcher, (c) derive displayed accels from the
live table, (d) need-driven migrations only.
