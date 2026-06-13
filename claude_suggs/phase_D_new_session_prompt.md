# Task

Execute **Phase D (identity)** and **Phase E (close-out)** of the stable-object-handles
step-1 plan: session-stable wire ids stamped at the lifecycle funnel, queryable from
Tcl, test-driven red-first.

Branch: `feature/stable-object-handles` (you should already be on it; verify with
`git branch --show-current`). Phases A–C are DONE: characterization suite (32 checks,
`tests/stable_handles/`), lifecycle census (`code_analysis/wire_lifecycle_census.md`),
and the funnel — all 18 census sites route through `src/store.c`
(`wire_store`, `wire_store_split`, `wire_delete_compact`, `wire_storage_reset`;
commits 9c332c76..ba13cc1f).

Read first, in this order:
1. `claude_suggs/plan_stable_handles_step1.md` — Phase D/E specs (tests H1–H7, D3 options)
2. `code_analysis/wire_lifecycle_census.md` — especially "Facts banked for Phase D"
3. `claude_suggs/green_but_hollow_tests.md` — testing discipline; it is binding here

## Phase D1 (RED) — commit failing tests BEFORE any C change

Add to `tests/stable_handles/test_body.tcl` using the `xcheck` XFAIL marker
(already in wrap.tcl; it logs XFAIL while failing and a flip-me message once green).
Surface under test (minimal, two new scheduler subcommands, additive):

    xschem wire_id <index>   → id (or -1)
    xschem wire_index <id>   → current index (or -1)

Properties H1–H7 per the plan: unique id > 0; **H2 = the original dangling-index
scenario** (id survives neighbor delete and still dereferences to the same coords —
see `tcl_introspection_wire.md` §2e); deref after own deletion → -1 loudly; no id
reuse within session (create→delete→create → fresh id); memory-undo round-trip
(should pass nearly free — see census: `mem_pop_undo` copies whole structs);
split/merge semantics (surviving segment keeps id, new segments fresh — the test
RECORDS this decision); disk-undo round-trip as **expected XFAIL** (disk undo
restores via `clear_drawing` + `load_wire` → fresh ids; that's D3).

## Phase D2 (GREEN) — implementation

- `unsigned int id` field appended to `xWire` (`xschem.h` ~line 453); per-context
  monotonic counter in `Xschem_ctx` (multiple windows/tabs each have their own xctx —
  the counter must live there, not in a global).
- Stamp in `wire_store` AND `wire_store_split` (both are birth doors).
- id→index map: `Int_hashtable` utilities exist (`xschem.h:1669` region) — **read the
  actual API before using it**. Map maintenance: deletion compaction is
  order-preserving (decrement walk suffices), but R1 (storeobject pos>=0 insert-shift,
  Tcl-only reachable) and R2 (`change_elem_order` swap, `editprop.c`) also move
  structs — ids travel inside the structs, so a lazy full-rebuild-on-miss with a dirty
  flag may be simpler than incremental maintenance everywhere. Your call; say which
  and why in the commit.
- Two new branches in `scheduler.c` (pattern: any small existing branch like
  `wire_coord`) + entries in `xschem help` text if present.
- C changes need `make -C src -j8` before testing (Tcl changes don't).

## Phase D3 — STOP and ask the user

Disk undo cannot round-trip ids (re-reads .sch files). Present the three options from
the plan (serialize-in-undo-files / invalidate-on-restore / memory-undo-only),
recommend (b) invalidate-on-restore, and WAIT for the user's choice before
implementing it. Then flip or adjust H7 accordingly.

## Phase E — close-out

End-to-end probe in `code_analysis/introspection_probes/` re-running the §2e failure
side-by-side with the handle version; cross-reference note in
`tcl_introspection_wire.md` §5 defect 7; update plan status; then present (don't pick)
the step-2 decision menu: (a) instances next, (b) coherence sweep, (c) `xschem object`
uniform read API, (d) action-logging issue 0005 integration.

## Hard-won testing rules (each cost real debugging time — follow exactly)

- Suite: `cd src && timeout -s KILL 120 ./xschem -q --script ../tests/stable_handles/wrap.tcl`;
  results in `/tmp/sh_test.log`; needs an X display; 32 existing checks must stay
  green at EVERY commit; wrap.tcl already backs up/restores the user's recent_files
  and cleans fixtures.
- **Green-but-hollow discipline**: every new test must be shown to FAIL before the
  implementation lands (that's what XFAIL documents); stash-verify any change to
  existing behavior (`git stash push src/<files>` → rebuild → run → pop → rebuild).
- All schematic edits happen on the /tmp fixture copy — never load repo files directly;
  `xschem set modified 0` before every `xschem load`; modals are already stubbed in
  the harness.
- A freshly scripted schematic has a STALE wire spatial hash — call
  `xschem rebuild_connectivity` before anything that consults it (wire_cut, splits).
- `xschem wire x1 y1 x2 y2 -1 {} 1` creates a selected wire (argv: pos, prop, sel).
- Cross-check `tests/file_open_dialog/wrap.tcl` (33 checks) after C changes — it
  exercises load paths through a different surface.

Commit per phase with the established message style (refactor/test/docs(handles): …).
Do not start step 2 — Phase E ends with the decision menu presented to the user.
