# Net highlight — hierarchy propagation & linked‑window sync: coding‑agent guide

**Customer: a future Claude Code session.** This is the actionable companion to the
prose explainer
[`net_highlight_hierarchy_and_linked_windows.md`](net_highlight_hierarchy_and_linked_windows.md).
It is a dense, `file:line`‑anchored map plus two work packages: a **deep‑gap fix
roadmap** (§7) and a **headless‑test plan** (§8). Read the prose doc for *why*;
read this for *where* and *what to change*.

- **Verified against:** branch `fluid-editing`, HEAD `0b6cc230` + uncommitted work.
  All line numbers below were read from current source. Re‑`grep` before editing —
  `hilight.c` is 3945 lines and shifts.
- **The one‑paragraph summary:** Highlights are per‑window in
  `xctx->hilight_table[HASHSIZE]`, keyed by the composite `(sch_path[currsch],
  token)`. Cross‑window sync translates across a **one‑level** window gap by reading
  the crossed instance's `node[]` + symbol pin names (pure, no child load), and
  relays through chains of adjacent windows. A window **>1 level away with no
  window at the intervening level** cannot be translated (the middle netlist is
  loaded nowhere), so it falls to an orphan mop‑up that **clears through any depth
  but drops deep entries when populating** (ancestor‑or‑self filter,
  `net_hilight_copy_table_from` at `src/hilight.c:3183`, drop test `:3193`). That is
  the reported bug — a deliberate deferral (issue 0073 §9c), not a regression.

---

## 1. Data model quick‑reference

- `struct hilight_hashentry` — `src/xschem.h:871`. Fields: `next`, `hash`,
  `token`, `path`, `oldvalue`, `value`, `time`, `seq`. Identity = `(path, token)`.
- `hilight_table[HASHSIZE]` per `Xschem_ctx` — `src/xschem.h:1201`; `HASHSIZE`
  = 31627 `src/xschem.h:316`.
- **Key:** `hi_hash` `src/hilight.c:25` folds `sch_path[currsch]` (cached in
  `sch_path_hash[currsch]`) then `token`; match needs `strcmp(token)==0 &&
  strcmp(path)==0` `src/hilight.c:119-120`. **Moving `currsch` retargets which
  level is read/written.**
- **`value`:** `>=0` = `NetHilightStyle` index (mod n styles); `<0` = sim logic
  level (`LOGIC_0=-12,_1=-5,_X=-1,_Z=-13` `src/hilight.c:1940`), colour via
  `(-value)%cadlayers`, bypasses the style table.
- **`token` leading‑space tag:** 1 space = instance, 2 = label/pin
  (`inst_hilight_hash_lookup` `src/hilight.c:151`). Net tokens never start with a
  space. Decoded in `display_hilights` `src/hilight.c:271`.
- **`seq`:** monotonic `hilight_apply_seq` `src/hilight.c:74`, bumped on insert
  `:112` / re‑apply `:132`; carried by `copy_hilights` `:244` and
  `net_hilight_copy_table_from` `:3202`. Drives buried‑cue most‑recent‑wins.
- **Derived:** `hilight_nets` flag (`there_are_hilights` `src/hilight.c:290`);
  per‑instance `inst[].color` (sentinel `-10000`) and `inst[].buried_hilight`
  (sentinel `-1`). `clear_all_hilights` `src/hilight.c:896` is the sole full reset.
- **Constants:** `MAX_NEW_WINDOWS=20`, `CADMAXHIER=40`, `WINDOW_PATH_SIZE=30` —
  `src/xschem.h:158,212,159`.

---

## 2. Intra‑window propagation (the reusable translation primitives)

- **Down (descend):** `hilight_child_pins` `src/hilight.c:1036`. Reads
  `i=previous_instance[currsch-1]`, `inst[i].node[j]` + symbol `PINLAYER` pin
  `name`; bit map `((inst_number-1)*mult+k-1)%net_mult+1` `:1087`. Runs at the
  child `currsch` but reads the PARENT inst — needs **no child schematic loaded**.
  Called by `descend_schematic` `src/actions.c:3517` **before** `load_schematic`
  `:3522`.
- **Up (ascend):** `hilight_parent_pins` `src/hilight.c:956`, same formula `:1015`.
  **Additive only** — the un‑highlight `XDELETE` is commented out `:1019-1028`
  (two child pins may share one parent net). So single‑window ascend is a PATCH,
  not a reconcile.
- **Finalizer:** `propagate_hilights(set,clear,mode)` `src/hilight.c:1874` — colours
  instances, sets `hilight_nets`, calls `drill_hilight` `:1934` (only if
  `enable_drill`), then `compute_buried_hilights` `:1936`. Edits instance colours,
  does **not** GC net entries.
- **`drill_hilight` `src/hilight.c:1443` — LATERAL, not vertical.** Same‑level
  fixpoint pushing a highlight across an instance's sibling pins via the pin
  `propag` attribute. Never changes `currsch`/`sch_path`, never loads a subcircuit,
  never creates a deep‑path entry. `enable_drill` default 0 (`src/xinit.c:798`), set
  only by `xschem hilight drill` (`src/scheduler.c:3209`). **Do not treat drill as
  a source of deep entries — it is not** (adversarially verified).
- **Bit formula appears 5×** (keep in lockstep): `src/hilight.c:1087` (child),
  `:1015` (parent), `:3304` (`sync_one_child`), `:3464` (`sync_one_parent`),
  `src/actions.c:3477` (descend portmap). **Extraction target** — see §7.
- **Arbitrary‑path accessor:** `hier_hilight_hash_lookup` `src/hilight.c:208`
  (temporarily swaps `sch_path[currsch]`). Used by waveform back‑annotation, not by
  descend/drill. Potentially useful for a fix.

---

## 3. Buried‑net cue

- Field `xInstance.buried_hilight` `src/xschem.h:684` (style idx or `-1`). **Stamp
  `-1` at `inst_register` `src/store.c:543`** (memset zeroes it, 0 is a valid
  style). `clear_all_hilights` resets it directly `src/hilight.c:905` (that path
  skips `propagate_hilights`).
- Detect: `compute_buried_hilights` `src/hilight.c:1831`. Skip conditions: `value<0`
  `:1847`; space‑tagged token `:1848`; not strictly deeper `:1850`; not under
  current path `:1851`; pin‑exposed `buried_inst_pin_hilighted(k)` `:1859`;
  most‑recent‑wins `e->seq>=bseq[k]` `:1861` (NOT lowest index).
- `buried_inst_pin_hilighted` `src/hilight.c:1798` — independent pin re‑scan, NOT an
  `inst[].color` test (spec §4.3 stale).
- Draw: `draw_hilight_net` buried loop `src/hilight.c:3773` — 4 bbox edges via
  `draw_hilight_wire`, outset `BURIED_CUE_OUTSET_PX=4.0` `:79`. Anim scan 3rd loop
  `:2872` arms a buried‑only window (blink OR march, vs pin‑loop blink‑only `:2854`).
- **Cross‑window relevance:** copying a deep SURFACING net's entry into a shallow
  window paints a FALSE buried cue → the reason the orphan filter drops deep
  entries (§4, §7 correctness).
- Test seam: `xschem hilight_buried <inst>` `src/scheduler.c:3289` → style idx or
  `-1`.

---

## 4. Multi‑window infra

- Contexts: `save_xctx[MAX_NEW_WINDOWS]` `src/xinit.c:41`, slot 0 = main. Resolve
  slots via `get_window_ctx(i,&wp)` `src/xinit.c:138` — encodes the single‑schematic
  invariant `ctx = (get_window_count()==0 && i==0) ? xctx : save_xctx[i]` `:141`.
  Do NOT hand‑code the slot‑0 rule; route through this.
- Borrow/restore: `net_hilight_borrow_ctx(win_path)` `src/hilight.c:2922` (pure
  `prev=xctx; xctx=target; return prev`, exact‑path match only, NULL for
  current/unknown/unalloc), `net_hilight_restore_ctx` `:2952` (NULL = no‑op). Shape:
  `saved=borrow(wp); if(saved){…; restore(saved);}`. **No `vwait`/`update` between
  borrow and restore.**
- Tabs share `.drw`: `xctx->window = save_xctx[0]->window` `src/xinit.c:2049`. Main
  window + all tabs have EMPTY `top_path`; detached windows have non‑empty
  `top_path` + own canvas.
- **Sentinel disambiguator:** `drw_front_win` `src/xinit.c:51`, written by
  `note_drw_front` `:218` (4 sites: switch_window `:1733`, switch_tab `:1801`,
  create_new_tab `:2072`, destroy_tab `:2308`), read via `get_drw_front_win` `:210`.
- Visibility gate: `net_hilight_ctx_visible(wp)` `src/hilight.c:3217` =
  `save_pixmap && (top_path[0] || wp==get_drw_front_win())`. Gate every sync
  `draw()`.
- Gesture guard: `net_hilight_ctx_gesturing()` `src/hilight.c:2988` =
  `ui_state & HILIGHT_ANIM_BUSY` (excludes semaphore, unlike `_ctx_busy` `:2976`).
- **Headless:** `create_new_window` `src/xinit.c:1813` guards all Tk
  (toplevel/canvas/GC/pixmap) under `if(has_x)` (`:1879-1901`) but allocs the ctx +
  `load_schematic` unconditionally. `--nogui`→`has_x=0` (`src/options.c:186`).

---

## 5. The sync engine

Dispatch `net_hilight_sync_descend_windows()` `src/hilight.c:3602`:
```
if(!has_x) return;                          // 3606
if(net_hilight_sync_suspend_count) return;  // 3607 (batch defer)
if(net_hilight_ctx_gesturing()) return;     // 3608
src = xctx;
for i: nh_sync_visited[i]=0;                // 3610
net_hilight_sync_children_rec(0);           // 3611  DOWN ±1
net_hilight_sync_parents_rec(0);            // 3612  UP ±1
net_hilight_sync_orphans(src);              // 3613  >1‑level mop‑up
net_hilight_anim_update();                  // 3620  re‑arm (child tables now populated)
```

- **±1 down** `net_hilight_sync_children_rec` `:3344` accepts C iff
  `C->currsch==src->currsch+1` `:3365` + path prefix `:3368` + one trailing
  component `:3369-3371` + `src->sch[currsch]==C->sch[currsch-1]` `:3378-3379` +
  `get_instance(instname)>=0` `:3380`. Worker `net_hilight_sync_one_child` `:3275`:
  Phase A pin‑walk `:3293-3320`; Phase B borrow child, `clear_all_hilights`,
  `net_hilight_copy_table_from(src,NULL)` verbatim `:3328`, inject child nets
  `:3329-3330`, propagate, guarded draw. Marks `nh_sync_visited[i]` `:3385`, recurses.
- **±1 up** `net_hilight_sync_parents_rec` `:3509`: `if(src->currsch<=0) return`
  `:3517` (top has no parent window — this is why the primary‑as‑source case never
  reaches the deep secondary via `parents_rec`); accept P iff
  `P->currsch==Ccurr-1` `:3532`. Worker `net_hilight_sync_one_parent` `:3408`:
  Phase A0 snapshot child nets `:3421-3441`, borrow parent, map up `:3453-3480`,
  rebuild.
- **Orphan mop‑up** `net_hilight_sync_orphans` `:3568`: for each unvisited
  `net_hilight_prefix_related(src,C)` `:3234` window → `net_hilight_reconcile_verbatim`
  `:3258` → borrow, `tp=target sch_path[currsch]` `:3262`, `clear_all_hilights`
  (UNCONDITIONAL) `:3263`, `net_hilight_copy_table_from(src,tp)` `:3264`
  (ancestor‑or‑self), propagate, guarded draw.
- **THE FILTER** `net_hilight_copy_table_from(src,tp)` `:3183`: `tp==NULL` verbatim;
  else drop test `:3193` `if(!e->path || plen>tplen || strncmp(tp,e->path,plen)) continue;`
  (drops deeper‑than‑tp; keeps shallower iff component‑aligned prefix).
- **9 hook sites** (no new hook needed for the fix): mutations
  `hilight_netname` `src/hilight.c:1540`, `hilight_net_styled` `:2471`,
  `unhilight_net` `:2506`, `xschem hilight` `src/scheduler.c:3214`,
  `hilight_instname` `:3277`, waveform `:7672`, `unhilight_all` `:9039`; navigation
  `descend_schematic` `src/actions.c:3560`, `go_back` `:3667`.
- **Batch:** `net_hilight_sync_suspend/_resume` `src/hilight.c:3589-3597`
  (counter); Tcl `xschem net_hilight_sync_suspend/_resume`; used by
  `net_hilight_apply` `src/xschem.tcl:627` (bracket `:646/:648` in a `catch`).

---

## 6. The bug trace (compact) — CONFIRMED against source

Topology: P `.` `currsch=0` `.drw` empty‑top_path front; S `.x1.x4.` `currsch=2`
detached; no window at `.x1.`. `prefix_related(P,S)=TRUE` → they meet ONLY via
`sync_orphans`.

| Action | children_rec | parents_rec | orphans | Result |
|---|---|---|---|---|
| A1 highlight deep in S | need currsch 3: none | need currsch 1: P is 0 → skip | reconcile(S→P) `tp="."`; S entry `.x1.x4.` plen7>tplen1 → **dropped** | primary dark |
| A2 press 0 in P | none | `P.currsch<=0` returns | reconcile(P→S) `tp=".x1.x4."`; `clear_all_hilights` wipes S; empty copy | **secondary clears** |
| A3 highlight in P (surfaces to S) | need currsch 1: none | returns (top) | reconcile(P→S) `tp=".x1.x4."`; P entry `.` plen1, `1>7` false, prefix OK → **kept but inert** at `.` | secondary dark |
| A4 press 0 in S | none | none | reconcile(S→P) `tp="."`; clear wipes P | **primary clears** |

Up‑populate DROPS the leaf; down‑populate KEEPS an inert ancestor entry. Both fail;
clear (unconditional) always crosses. Principle: **stale > missing > wrong** — never
manufacture an unvalidatable deep entry (would paint a false buried cue on a
surfacing net, §3, §7‑correctness).

---

## 7. WORK PACKAGE A — deep‑gap fix roadmap  ✅ IMPLEMENTED

> **Status: shipped** on `fluid-editing`. Approach 2 (transient relay) was built as
> `net_hilight_relay_reconcile()` (+ helpers `nh_hop`, `nh_path_component`) in
> `src/hilight.c`, wired into `net_hilight_sync_orphans` (gap≥2 → relay, else
> verbatim fallback). Scratch lifecycle via `alloc_scratch_xschem_ctx()` /
> `free_scratch_xschem_ctx()` (xinit.c) with `has_x` forced 0 around the loads. Kill
> switch / test seam: `xschem net_hilight_relay_enable [0|1]` (`net_hilight_set/get_relay_enable`).
> Verified: `tests/hilight_xwin_sync.tcl` (44 checks — surfacing-net lights the real
> net, buried-net shows a validated cue, clear-through both ways, relay-off sabotage).
> The roadmap below is retained as the design record; the pin-walk extraction
> (§7.3) was implemented as the shared `nh_hop` (the ±1 `sync_one_child/_parent`
> were left as-is — a further DRY cleanup opportunity, not required).

Goal: light the EXACT internal net across a >1‑level gap with no intermediate
window. Wire‑up point: **inside `net_hilight_sync_orphans` `src/hilight.c:3568`** —
replace the unconditional `net_hilight_reconcile_verbatim(src, wp)` `:3578` with a
gap check; `gap==1` is already handled by ±1; `gap>=2` → new relay; keep
`reconcile_verbatim` as the fallback. **No new hook sites.**

### 7.1 Rejected approaches (do not chase)

- **Reuse `drill_hilight` deep entries — premise FALSE.** Drill is lateral +
  default‑off (§2); the source table has no deep entries to copy; the
  ancestor‑or‑self filter is filtering an empty set, not being "too aggressive."
  Single‑window oracle confirms: top highlight table is `{CTRL1}`, the `.x1.` entry
  appears only after descend runs `hilight_child_pins`.
- **Piggyback the SPICE netlister — REJECTED as a resolver.** `global_spice_netlist`
  `src/spice_netlist.c:441` traverses by unique subckt TYPE (dedup `:489`), emits
  `.subckt` with LOCAL node names, builds NO per‑instance‑path node table.
  **Salvage** only its transient‑load primitive (`load_schematic(reset_undo=0)` +
  `pop_undo` restore) — but that loads into the LIVE ctx and is too invasive to fire
  on a keystroke; use a scratch context instead.

### 7.2 Recommended: transient intermediate‑netlist relay

The intermediate schematic's filename is already in the orphan's stack:
`C->sch[L-1]` names the level‑`L` parent cell, descend instance = the path
component of `C->sch_path[L]` beyond `C->sch_path[L-1]` (extract like `children_rec`
`:3369-3375`), slice = `C->sch_inst_number[L-1]`. All reachable via
`get_window_ctx`.

**DOWN direction** (src at depth dS → orphan C at depth dC, gap ≥2):
1. Working set W = src's highlighted net tokens at its own level (read
   `src->hilight_table` at `src->sch_path[src->currsch]`, like `sync_one_parent`
   Phase A0 `:3421-3441`).
2. Hop L=dS+1 in src (top loaded): reuse the `sync_one_child` Phase‑A pin‑walk
   `:3293-3320` to map W → child‑level set.
3. Hops L=dS+2..dC: load `C->sch[L-1]` into a SCRATCH ctx, `prepare_netlist_structs(0)`,
   `get_instance(instname_L)` `src/scheduler.c:86`, run the SAME pin‑walk one level
   deeper. (gap−1 scratch loads; gap==2 → 1 load.)
4. Reconcile C like the ±1 path: borrow C, `clear_all_hilights`,
   `net_hilight_copy_table_from(src, NULL)` VERBATIM (carries ancestor + deep entries
   → clear‑through + correct buried cue), inject W at C's level
   (`bus_hilight_hash_lookup(...,XINSERT_NOREPLACE)`), `propagate_hilights(1,1,…)`,
   guarded `draw()` via `net_hilight_ctx_visible`, restore.

**UP direction** = mirror: snapshot deep nets from src (child) table; hop up loading
`src->sch[L-1]` intermediates with the parent pin‑walk `:3453-3480`; final hop into
the shallow orphan (already has its schematic); reconcile.

### 7.3 New code

- `net_hilight_relay_reconcile(Xschem_ctx *src, Xschem_ctx *tgt, const char *wp)` —
  the gap walker (~120 LOC).
- **Scratch‑context lifecycle** — model on `preview_window` `src/xinit.c:1444-1497`:
  save `xctx` → `alloc_xschem_data(src->top_path, win_path)` `:594` (makes NO
  GC/pixmap — callers do) → `load_schematic` → use → `delete_schematic_data` →
  restore `xctx`. A never‑drawn scratch is viable. Allocate once and cache across the
  sync pass, or per‑call.
- **Extract the per‑hop pin‑walk** into a shared helper (e.g.
  `nh_translate_hop(inst_idx, inst_number, down, in_toks, in_vals, n_in, …out…)`)
  used by `sync_one_child`, `sync_one_parent`, and the relay. Arithmetic already
  identical at the 5 sites (§2) — mechanical, and resolves the standing §9d
  "duplicated bus‑pin walk" note.

### 7.4 Correctness — buried‑vs‑surfacing is RESOLVED, not revived

Loading the intermediate netlist IS the surface‑vs‑buried decision. Surfacing net →
relay yields the real shallow net → highlighted at the shallow level →
`buried_inst_pin_hilighted` `:1798` suppresses the cue (no false rectangle). Truly
buried → no shallow entry, deep entry stands alone → correct cue. Because the
translated shallow net now accompanies the deep entries, verbatim‑copying the deep
entries is SAFE again (restores the ±1 invariant "deep entry rides alongside its real
net"). Output byte‑matches a fully‑open descend chain. **Rule: never copy a deep
entry into a shallow target without its translated companion net in the same
reconcile.**

### 7.5 Risks / must‑verify / effort

- Keep global `xctx` balanced around the scratch borrow (reuse borrow/restore
  discipline; self‑balancing on NULL).
- Confirm `load_schematic` `src/save.c:3670` + `prepare_netlist_structs`
  `src/netlist.c:1663` run cleanly in a WINDOWLESS scratch ctx (headless netlisting
  suggests yes; this exact path is new — smoke‑test set_modify/title/current_dirname
  side effects).
- Load intermediates by ABSOLUTE path from `C->sch[]` to avoid `get_sch_from_sym`
  `src/actions.c:3183` resolution (web/generator/lib‑cellview, `current_dirname`).
  `previous_instance[]` is a parent‑array index — meaningless once that schematic
  isn't loaded; recover the instance by NAME + `get_instance` after loading.
- Bound recursion/loads by `CADMAXHIER=40`; orphan scan by `MAX_NEW_WINDOWS=20`.
- **FALLBACK:** if any intermediate load fails, fall back to
  `net_hilight_reconcile_verbatim` (clear‑through + ancestor‑only drop) — never
  regress clear‑through, never draw a false cue.
- Perf: `gap≥2` orphan → `(gap-1)` loads per highlight change (rare topology);
  bulk loops already covered by suspend/resume; consider caching one scratch ctx per
  sync pass.
- **Effort: MEDIUM (~1–2 days incl. tests).** Core relay ~120 LOC + ~40 LOC scratch
  lifecycle + pin‑walk extraction. Tests: the existing grandchild fixture already
  encodes both boundary cases — FLIP the two §9c "primary NOT populated" asserts to
  "primary lights `CTRL1` (surfacing) / shows buried cue on `xg` (genuinely
  buried)"; keep clear‑through green; sabotage‑gate the relay to isolate.

### 7.6 Still out of scope after this fix

Sibling cross‑sync (two windows descended into the SAME instance) — excluded by
`net_hilight_prefix_related` rejecting equal `currsch` `:3239`. Separate topology,
separately deferred.

---

## 8. WORK PACKAGE B — headless‑test plan  ✅ TIERS A/B/C LANDED

> **Status: shipped** on `fluid-editing`. All three headless tiers are live and green
> under `--nogui`, plus the GUI end‑to‑end test (Tier D) is retained:
> - **Tier A** — `tests/hilight_hier_oracle.tcl` (zero new C): single‑window
>   descend/ascend oracle; asserts the byte‑targets the sync/relay must match (FOO
>   surfaces 1 level, CTRL surfaces 2, BAR buried 2 → validated cue).
> - **Tier B** — `tests/hilight_hier_dump_replay.tcl` + new getter
>   `xschem get sch_inst_number [n]` (scheduler.c): dumps the hierarchy
>   representation to a file, then replays the two engine rules (per‑hop
>   up‑translation R1; ancestor‑or‑self filter R2) purely from the file — proves the
>   mapping is a pure function of serialized state.
> - **Tier C** — `tests/hilight_xwin_sync_headless.tcl` + bypass seam
>   `xschem net_hilight_sync_force_headless 1` (flag `net_hilight_sync_force_headless`
>   in hilight.c; the one outer `has_x` guard on `net_hilight_sync_descend_windows`
>   now reads `if(!has_x && !net_hilight_sync_force_headless) return;`): runs the REAL
>   sync engine + relay over two logical contexts headless (draws self‑skip via
>   `net_hilight_ctx_visible` — no pixmap). A second context is created under
>   `--nogui` via the existing `schematic_in_new_window` path (emits harmless swallowed
>   Tcl warnings). Covers surfacing, buried, clear‑through both ways, ±1 adjacent, and
>   a relay‑off sabotage.
> - **Tier D** — `tests/hilight_xwin_sync.tcl` (44 checks) retained for real Tk
>   windows + animation; the bypass flag defaults off, so it is unaffected.
> The plan below is the design record.


The translation math is PURE over `inst.node[]`, symbol `PINLAYER` pin names,
`sch_inst_number`, path strings, and `hilight_table`. The sync CORE is
`has_x`‑independent except the outer guard; its only `draw()` is separately gated by
`net_hilight_ctx_visible` (returns 0 with no `save_pixmap` → always headless). Ranked
tiers:

### Tier A — single‑window ORACLE (do first, ZERO new C, `--nogui`)

New `tests/hilight_hier_oracle.tcl`, run
`../src/xschem --nogui --pipe -q --script hilight_hier_oracle.tcl`. Reuse
`tests/hilight_xwin_sync/` fixture. In ONE context: `load parent.sch`; select `xi`
+ `descend 1` (`.xi.`); select `xg` + `descend 1` (`.xi.xg.`); `hilight_netname
BAR`; assert `display_hilights` has `xi.xg.BAR`; `go_back` → assert `lsort
[display_hilights] == {xi.BAR xi.xg.BAR}`; `go_back` → assert `hilight_buried xi`
== BAR's style (BAR is a `lab_pin`, genuinely buried). FOO variant: descend `xi`,
`hilight_netname FOO`, `go_back`, assert `{FOO xi.FOO}`. **Locks the translation
math + surfaced/buried classification with no window** and produces the exact
byte‑targets the GUI test hard‑codes (`{FOO xi.FOO}` `hilight_xwin_sync.tcl:89`;
`{xi.xg.BAR xi.BAR}` `:120`).

### Tier B — representation dump + offline replay (RECOMMENDED)

Dump seam: new `xschem dump_hier_rep <file>` (branch in `scheduler.c` near
`display_hilights` ~`:1337`), line‑oriented:
```
CURRSCH <n>
PATH  <lvl> <sch_path[lvl]>        # get sch_path exists scheduler.c:2351
SCH   <lvl> <sch[lvl]>
INSTN <lvl> <sch_inst_number[lvl]> # NO existing getter — the one new field
INST  <instname> <symref>
PIN   <instname> <pinname> <dir> raw=<inst.node[j]> exp=<expandlabel(node)>
HILIGHT <path> <token> <value>     # == list_hilights all (hilight.c:3921)
```
Reuse instead of new C where possible: `instance_nodemap` `src/scheduler.c:3667`,
`getprop instance_pin` `:2692`, `list_hilights all` `:4049`, `get sch_path`
`:2351` / `currsch` `:1940`. **Only `sch_inst_number` lacks a getter** → add
`xschem get sch_inst_number [n]` (mirror the `sch_path` getter) or fold into
`dump_hier_rep`. Scalar instances are always 1, so a first cut can skip it, but add
for bus correctness.

Driver (headless): top → `dump top.rep`; descend `xi` → `mid.rep`; descend `xg` +
`hilight BAR` → `deep.rep`. PURE‑Tcl checker (no xschem) replays:
- **R1 one‑level relay** (mirror `sync_one_parent` `:3486`): target := neighbour
  table verbatim + map shared instance's highlighted pins up using dumped PIN
  raw/exp + INSTN. Assert deep(`.xi.xg.`,BAR) up one level with `mid.rep` xg map →
  `{xi.BAR}`.
- **R2 deep‑gap reconcile** (mirror filter `:3193`): target := only src entries with
  path a prefix of target‑path AND `len<=target‑len`. Assert deep(`.xi.xg.`) against
  `.` DROPS both `xi.xg.BAR`/`xi.BAR` → top EMPTY (no false populate); emptied deep →
  top cleared (clear‑through). **This asserts the §7 boundary as arithmetic, zero
  windows** — highest value / lowest risk.

### Tier C — run the REAL engine headless (one small seam)

1. **Bypass seam:** file‑scope `int net_hilight_sync_force_headless` in
   `hilight.c`; change the guards to
   `if(!has_x && !net_hilight_sync_force_headless) return;` (`:3606`, plus a no‑op
   anim path). Expose `xschem net_hilight_sync_run` that sets the flag, calls
   `net_hilight_sync_descend_windows()`, clears it. Model on
   `net_hilight_test_now`/`net_hilight_test_active` `src/scheduler.c:4894`,
   `src/xschem.h:1186`. `draw()` auto‑skips (no `save_pixmap`) → no `BadDrawable`.
2. **Second logical context headless:** either (a) spike `xschem
   schematic_in_new_window force window` under `--nogui` (Tk is guarded, ctx
   alloc + `load_schematic` are not — UNVERIFIED whether the unconditional
   `tclvareval` proc calls in `create_new_window` leave it usable), or (b) a clean
   `xschem test_new_logical_ctx <winpath> <file> [<descend-inst>...]` that saves
   `xctx`, `alloc_xschem_data`, registers `save_xctx[n]`+`window_path[n]`+bumps
   `window_count`, `load_schematic`, descends, restores. (b) gives a fully‑formed
   linked context with correct `sch_path`/`sch_inst_number` that
   `prefix_related`/`sync_*_rec` match — no widgets.

Test: ctx A (`.`), ctx B linked via `copy_hierarchy_data` `src/actions.c:2614`
(needs `get_window_count()>0` first) then descend to `.xi.`/`.xi.xg.`; highlight in
one; `net_hilight_sync_run`; borrow‑read the other via `display_hilights`. Assert ±1
tables match Tier‑A byte‑targets; the 2‑level gap does NOT populate but clear‑through
empties the deep window.

### Tier D — keep the GUI test, narrow its remit

`tests/hilight_xwin_sync.tcl` remains the ONLY end‑to‑end check for what genuinely
needs a display: real toplevel/canvas/GC (`create_new_window` `if(has_x)` half), the
Tk `after`‑loop tick + `vwait` (`:157-216`), `net_hilight_dump_pixmap` byte‑compare,
front‑of‑`.drw`/bg‑tab visibility. Its table assertions become redundant with A/B/C
(cheap to keep as smoke). Wire A (+B, +C if seam added) into a headless runner
(`run_regression.tcl` already execs `xschemtest.tcl --nogui`).

### Headless gotchas

- `net_hilight_sync_descend_windows` early‑returns `!has_x` `:3606` — a naive
  headless two‑context test sees NO sync (Tier C needs the bypass).
- No `xschem get sch_inst_number` getter — add it for bus replay.
- Green headless tables ≠ pixels: the sync `draw()` is skipped headless — label
  tiers "table‑level only"; pixel/anim still needs the GUI test.
- `instance_nodemap` returns RAW `inst.node[]` `:3686`; sync uses `expandlabel`
  `:3296` — dump/replay must `expandlabel` (`xschem expandlabel` `:1631`) or dump
  both.
- Single‑window oracle (`hilight_parent_pins`) is additive (commented‑out XDELETE);
  the sync rebuilds from scratch. Steady‑state tables match; incremental deltas
  differ. **Assert on final tables, not deltas.**

---

## 9. Stale‑doc corrections (fix opportunistically)

- Issue 0073 §9c prose names `net_hilight_copy_table_ancestor` — **does not exist**;
  it was merged into `net_hilight_copy_table_from(src, tp)` (nullable `tp`). The
  issue's "files touched" section already matches; only the §9c prose name is stale.
- `compute_buried_hilights` docblock `src/hilight.c:1822` ("the lowest among
  several") and `doc/claude/specs/buried_net_hilight.md` §4.2 ("lowest style index")
  are WRONG — code `:1861` + field comment `src/xschem.h:882` + spec §8.2 =
  most‑recently‑applied (max `seq`).
- Spec §4.3 ("exclusion via `inst[i].color<0`") is stale — real exclusion is
  `buried_inst_pin_hilighted` (independent pin re‑scan).
- Spec §9 lists `xschem hilight_buried_list` — not found in `scheduler.c`; confirm
  before relying.

---

## 10. Open questions (unresolved in current code)

1. Does `load_schematic` + `prepare_netlist_structs` run cleanly in a never‑drawn
   scratch `Xschem_ctx`? (Headless netlisting suggests yes for `load_schematic`; the
   scratch path is new.)
2. Scratch‑context cost: per‑call alloc/free vs cache one across the sync pass?
3. Does `xschem schematic_in_new_window force window` yield a usable second context
   under `--nogui`, or do the unconditional `tclvareval` proc calls in
   `create_new_window` leave it half‑initialised? (Spike before relying on Tier‑C
   option (a).)
4. Vector INTERMEDIATE hops: confirm `sch_inst_number` slice threading + `%net_mult`
   wraparound stay correct when a non‑endpoint level is a vector instance (needs a
   bussed‑intermediate fixture; current fixtures are all scalar).
5. Interactive coalescing: `reconcile_verbatim` re‑borrows + rebuilds per (src,
   target) on every mutation — O(windows) per change; suspend/resume only helps bulk
   loops, not many independent single highlights. Worth a coalesce?
