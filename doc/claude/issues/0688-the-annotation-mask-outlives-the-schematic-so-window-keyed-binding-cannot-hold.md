# 0688 — `annot_show` outlives the schematic that was annotated, so any binding keyed on "which cellview is in which window" cannot hold

STATUS: **PARTIALLY FIXED 2026-08-25 (status E). §6 is what landed.** The mask now
belongs to the window's ROOT sheet and `File > Open` drops it — in the window that
armed it. It is **still reachable** in a window that inherited the mask through the
Tcl-var pull: that half is
[0809](0809-the-annotation-mask-leaks-into-a-new-window-with-a-null-stamp.md), and
it is why the item shipped E and not x. The original measurement below (§1–§5) is
kept verbatim; it is the reason the 0683+0684 attempt 1 was reverted.
FOUND IN: `annot_show` ownership (`actions.c:1321-1325` `annot_show_sync_cache()`,
`tctx::global_list`), and every consumer that resolves a session to a window by
cellview path (`ase::ui::annot_design_win`, `src/ase_window.tcl:2218`).
RELATED: [0683](0683-annotation-is-reachable-with-no-bound-ase-l-session.md),
[0686](0686-ase-ui-close-leaves-the-design-annotated-after-the-session-is-gone.md),
invariant **I3**.

---

## 1. The measurement

`annot_show` is per-**context**, and a context is a window, not a schematic. Loading
a different cellview into the same window does not touch it:

```
xschem set annot_show 3
xschem load <other>.sch      -> annot_show = 3      (still on, different sheet)
descend + go_back            -> annot_show = 3
```

Nothing in the editor clears the mask on `File > Open`. That is not a defect on its
own — it is the ordinary "this window is in annotate mode" behaviour, and it is what
`tctx::global_list` is for.

It becomes a defect the moment a binding is written on top of it, because **the ASE-L
session's only handle on the design is a cellview path**. `ase::ui::annot_design_win`
resolves the session key to a window by comparing that path against what each window
currently holds; the instant the user opens a different cell there, it returns `{}`
and every session-side operation on the mask silently becomes a no-op — while the
mask itself stays exactly where it was.

## 2. What that costs: the 0683 orphan survives its own fix, end to end

Driver `vc/atk4.tcl`, re-run by the write-up pass on the clean tree with the fix
attempt applied and **no sabotage shims live** (`VC prelude: shims undone = <>`):

```
STEP 1  ASE-L Results>Annotate on design D (the sanctioned road)
        annot_show=3  v(a)=3.14  _annotated=1
STEP 2  File > Open a different cell in the SAME window
        holds=LCC_instances.sch  annot_show=3  annot_mask K=0
STEP 3  Session > Close  (ase::ui::annot_clear_on_close is the 0686 fix)
        annot_clear_on_close returned 0   (0 = it cleared nothing)
        session destroyed. annot_show=3
STEP 4  File > Open design D again
        annot_show                     = 3   <<< ANNOTATION IS ON
        raw loaded                     = 0
        op_annot::_annotated (paints?) = 1
        xschem raw value v(a) -1       = 3.14   <<< numbers on the sheet
STEP 5  the off switches available to this user:
        ase::session_for_current       = ''
        ase::annot_binding_ok          = 0   (0 = both producers refuse)
        ASE-L sessions alive           = 0
        ::cadence::annot_mode (Ctrl-6) = 0
        menubar entries that CLEAR it  = 0 of 6 annotation-ish entries
```

Every door in that transcript is a sanctioned one: annotate from ASE-L, open another
cell, close the session, come back. No synthetic mask write anywhere. The end state
is issue **0457**'s original complaint verbatim — annotation ON, real numbers on the
sheet, and no menu, no session and no chord that turns it off.

Step 2's `annot_mask K = 0` is the whole mechanism: the mask is 3, and the session
reads 0, because it is asking the wrong window.

## 3. The same root cause breaks the off switch itself

`vc/atk2.tcl`: with mask 3 live and the session's cellview no longer loaded in that
window, `ase::ui::annot_apply K op` runs `annot_goto_design`, which returns 0, echoes
*"cannot reach this session's design window"*, and returns. The mask stays 3.

So **both** halves of the attempted binding — the `ase::ui::close` clear and the
ASE-L untick — route through `annot_design_win`, and both go unavailable in exactly
the state they exist for.

## 4. What this binds on the retry

1. **Do not key the binding on `cellview path -> window`.** It is defeated by the
   most ordinary gesture in the editor. Whatever owns "this mask belongs to that
   session" has to survive a `File > Open` in the design window.
2. **A producer-side guard is not a binding.** Refusing `Waves > Op Annotate` when
   there is no session (which the attempt did, correctly) does nothing about a mask
   that is *already* on. 0683 is a **lifetime** problem, not an entry problem.
3. **The candidate that was not tried**: clear the mask where the schematic changes,
   not where the session ends — i.e. treat `annot_show` as belonging to the *loaded
   sheet*, so `xschem load` drops it. That is a C-side change in the load path with a
   blast radius over every context, it contradicts nothing measured here, and it is
   the only shape found so far that the transcript in §2 cannot walk around. It is
   **unratified and unimplemented** — the user has to be asked, because it changes
   what `File > Open` does to a mode the user set deliberately.
4. **Any retry must run `vc/atk4.tcl`'s five steps as a test row.** The attempt
   shipped 22 + 207 + 342 green checks and every one of them passed over this.

## 5. Still open (as of the 2026-08-25 filing)

Everything above. Nothing was fixed; the fix attempt that exposed it was reverted in
full (see [0683](0683-annotation-is-reachable-with-no-bound-ase-l-session.md) §7).

---

## 6. ✅ WHAT LANDED, 2026-08-25 — §4's candidate (3), refined by measurement

§4 point 3 named the shape: *"treat `annot_show` as belonging to the loaded sheet,
so `xschem load` drops it"*. That is what was built, with one refinement §4 did not
have: the discriminator is the window's **ROOT** sheet `xctx->sch[0]`, not the
current sheet, because §1 records descend + `go_back` KEEPING the mask as
deliberate and `sch[0]` does not move under either. Descend-safety is therefore by
construction rather than by a special case. Sabotage variant **SAB-B** (the
discriminator widened to `sch[xctx->currsch]`) exists to catch a regression to the
wrong one, and reddened Y4, Y6 and O25.

| piece | file | what |
|---|---|---|
| `char *annot_root` | `src/xschem.h` (beside `annot_show`) | the root sheet the mask was armed for; per-`Xschem_ctx`, NOT mirrored in Tcl |
| `annot_show_set(int)` | `src/actions.c` | **the one C writer (I1)** — C field + Tcl mirror + stamp, one fact in one place |
| `annot_show_check_root(void)` | `src/actions.c` | the clear, through that same setter, when the stamp no longer names `sch[0]` |
| call site 1 | `src/save.c` `load_schematic()` tail | the deterministic seam |
| call site 2 | `src/actions.c` `annot_show_sync_cache()`, after the pull | the backstop |
| `xschem get annot_root` | `src/scheduler.c` | the test witness |
| free + NULL init | `src/xinit.c` | ctx teardown and `alloc_xschem_data` |

### The AFTER, against §2's transcript

```
L22  File > Open another cell  ->  {annot_show 0, op_annot::_annotated 0}   (was {3 1})
L24  reopen the cell           ->  {0 0 {} 0}                               (was {3 1 '' 0})
L20  POSITIVE the sanctioned road still annotates  ->  {1 1 3 3 3.14 1 1}
L25  POSITIVE relaunch ASE-L on the same cell and re-annotate  ->  {1 3 3.14 1}
Y5   different-cell load drops the mask immediately  ->  {3 0 y_b.sch}
Y1/Y2/Y3/Y4/Y9  the KEEP half: same-path load, -keep_symbols, reload,
                descend+go_back, and an rc-set (never-stamped) mask all keep it
Y7/Y7b  the clear touches NO waveform database, including a raw truncated on disk
```

### ⚠ IT TOUCHES NO RAW DATABASE, DELIBERATELY

The reverted attempt's data-loss regression (§7 of 0683, refutation 3) cleared
`op`/`dc`/`tran` at the session path and RE-READ; over a raw ngspice was
mid-rewrite the user's database was destroyed. This clear writes one int, one Tcl
var and one path and **never opens a file**. Rows Y7 and Y7b prove it against
exactly that file state. Note separately that the command both guarded entry points
*call* still has that defect at HEAD — issue
[0807](0807-annotate-op-destroys-the-attached-op-database-on-a-truncated-raw.md).

### The stamp is written ONLY by the setter (decision D2)

Never adopted lazily. Measured: at startup `xschem get schname 0` is
`<launchdir>/untitled.sch` and the rc sync (`xinit.c:3839`) runs BEFORE the CLI file
is loaded, so an adopting sync would stamp `untitled.sch` and the first real load
would then silently clear an `xschemrc`-set `annot_show` — killing producer (c),
which the 0683 ruling does not touch. Row **Y9** pins it.

That decision is also exactly what
[0809](0809-the-annotation-mask-leaks-into-a-new-window-with-a-null-stamp.md) runs
into: a NULL stamp means "never armed through the setter", and a leaked mask looks
identical to an rc-set one. The two cases have to be distinguished, not merged.

## 7. STILL OPEN after the partial fix

* **[0809](0809-the-annotation-mask-leaks-into-a-new-window-with-a-null-stamp.md)** —
  the mask leaks into a new window/tab with a NULL stamp, so the clear is inert
  there and §2's orphan reproduces through `File > Open in new window`. **This is
  the unfinished half of this issue.**
* **[0810](0810-annot-root-is-compared-with-a-bare-strcmp-so-a-respelled-path-false-clears.md)** —
  bare `strcmp` on the stamp: `./`, `//`, `../` and symlinked spellings of the SAME
  file false-clear the mask.
* **[0811](0811-only-load-schematic-got-the-deterministic-annotation-clear.md)** —
  only `load_schematic()` got the deterministic clear; `Save As` and
  `clear_schematic()` are lagged until the next bulk evaluation.
* **[0808](0808-y5-l22-l24-claim-to-pin-the-load-schematic-seam-and-do-not.md)** —
  the mirror image: three rows claim to pin the `load_schematic` seam and do not,
  because the load reaches `annot_show_sync_cache()` on its own. Read with 0811.
* §4 point 4's requirement is met: `vc/atk4.tcl`'s five steps are now rows
  **L20–L25** in `tests/headless/test_ase_launch.tcl`.
