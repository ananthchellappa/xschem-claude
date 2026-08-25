# 0686 — `ase::ui::close` tears down the session but leaves the design annotated: the SIXTH orphan producer

STATUS: OPEN — measured 2026-08-25 by the 0683+0684 crew (scout and measure passes,
both independently). A fix was implemented and then **reverted with the rest of that
attempt** because it does not hold (see §4). Filed, not fixed.
FOUND IN: `ase::ui::close`, `src/ase_window.tcl:300-330`.
RELATED: [0683](0683-annotation-is-reachable-with-no-bound-ase-l-session.md) — this is
a producer its §3 table does not list; [0688](0688-the-annotation-mask-outlives-the-schematic-so-window-keyed-binding-cannot-hold.md).

---

## 1. The defect

`ase::ui::close` unsets the session's per-key state and destroys the toplevel:

```
src/ase_window.tcl:319   array unset annot $key,*
```

but never touches the **design context's** `annot_show`. The only
`xschem set annot_show` in that entire file is at `:2383`, inside `annot_apply`.

So: tick `Results > Annotate > Operating Point info` ON, then `Session > Close`. The
session is gone, the ASE-L menu that owned the control is gone with it, and the
schematic is still annotated — with no reachable off switch, exactly the state 0683
is about, reached by the **sanctioned** road rather than by one of 0683's five
producers.

0683's own framing names this case without listing it: *"an annotation state that
cannot outlive the session that owns it"*. A guard on the two `Waves` /
`Simulation > Graphs` producers does not close it.

## 2. Why it is not in 0683's table

0683 enumerated the five things that **set** a non-zero mask. This one sets nothing —
it removes the only control that could clear it. It is a producer of the orphan
*state*, not of the mask value, which is why an enumeration of writers missed it.

## 3. The attempted fix (reverted — do not simply re-apply it)

`ase::ui::annot_clear_on_close {key}`, called first thing in `close`, guarded by a
no-switch `[ase::ui::annot_mask $key] != 0` pre-read so an ordinary close stays a pure
no-op, clearing through the existing writer (`annot_apply`, which gained a defaulted
`{attach 1}` argument that the close path passes as `0` so the teardown cannot attach
a raw on its way out). Test row **W8b** `{3 0}` covered it and went red under sabotage
S7 exactly as predicted, with W8's existing rows and W8c staying green.

That much worked. It is recorded here because the shape is right and only the key is
wrong.

## 4. Why it was reverted

The pre-read `ase::ui::annot_mask $key` resolves the session to a window by cellview
path. Open a different cell in the design window first — an ordinary `File > Open` —
and the mask reads **0** while it is really **3**, so `annot_clear_on_close` returns
having cleared nothing. Measured on the fixed tree with no sabotage live:

```
STEP 2  File > Open a different cell in the SAME window
        holds=LCC_instances.sch  annot_show=3  annot_mask K=0
STEP 3  Session > Close
        annot_clear_on_close returned 0   (0 = it cleared nothing)
        session destroyed. annot_show=3
```

Full transcript and the root cause in
[0688](0688-the-annotation-mask-outlives-the-schematic-so-window-keyed-binding-cannot-hold.md).
A retry has to fix 0688 first; this issue is downstream of it.

## 5. One more thing the attempt measured, for whoever retries

Routing the close-clear through `annot_apply` means every session close that had
annotation on also runs `annot_goto_design`, i.e. **raises and switches the current
xschem window to the design** (`raise_design_editor ifhidden` + redraw), once per
session during `prompt_all_on_quit`. That is a new user-visible side effect on close
and it was never eyeballed. Either the clear must not go through `annot_goto_design`,
or the raise has to be suppressed on the teardown path.

## 6. Still open

All of it.
