# 0688 — `annot_show` outlives the schematic that was annotated, so any binding keyed on "which cellview is in which window" cannot hold

STATUS: OPEN — measured 2026-08-25 by the 0683+0684 crew's adversary pass, and
independently re-measured by the write-up pass on a clean tree. **Filed, not fixed.**
This is **the reason the 0683+0684 fix attempt was refuted and reverted** — read it
before retrying either issue.
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

## 5. Still open

Everything above. Nothing was fixed; the fix attempt that exposed it was reverted in
full (see [0683](0683-annotation-is-reachable-with-no-bound-ase-l-session.md) §7).
