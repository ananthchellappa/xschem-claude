# 0659 — a CIW that is open but stacked behind the design window still reaches zero visible sinks

Status: OPEN (measured, NOT fixed)
Filed by: the 0650 write-up pass, 2026-08-23, from the adversary leg's finding.

## Measured (on :99, CIW deiconified then `lower`ed)

```
0659 .ciw ismapped (open, stacked behind)          1
0659 .ciw viewable                                 1
0659 sinks reached                                 ciw log
0659 statusbar.12 after the notice                 'SENTINEL-0659'
```

The sentinel survived: the fallback did **not** fire, and the notice went only
into a pane the user cannot see. That is the user's original complaint —
"I ticked the box, re-ran, and still get no OP info", with no mention of any
message — reproduced in an entirely ordinary window arrangement.

## Why the current predicate cannot see it

`xschem::notify_ciw_visible` uses `winfo ismapped .ciw`, which was the **correct
correction** to 0650's own `winfo exists` sentence (issue 0650's sink table said
`ciw_echo` *"No-ops silently when shut"*; it does not — `wm protocol .ciw
WM_DELETE_WINDOW {wm withdraw .ciw}` at `src/ciw.tcl:53` means a close merely
withdraws, so `.ciw.l.t` still exists and `ciw_echo` writes into the invisible
widget). `ismapped` covers **withdrawn, iconified and never-created**. It cannot
cover **occluded**, and neither can `winfo viewable` — measured 1 above.

So issue 0650's claim that "that state must not exist" is narrower in practice
than it reads. The honest statement today is: *a notice cannot be invisible when
the CIW is withdrawn, iconified, or was never created.*

## What a fix needs

Occlusion is not a Tk property. The candidates, in increasing cost:
1. `wm stackorder .ciw isbelow <design toplevel>` — cheap, and catches the
   measured case, but says nothing about overlap.
2. A `<Visibility>` binding on `.ciw` caching `VisibilityUnobscured` vs
   `VisibilityPartiallyObscured`/`VisibilityFullyObscured` — this is the property
   actually wanted, and X delivers it; the cost is a piece of state and a
   binding that must survive withdraw/deiconify.
3. Stop trying to answer "can the user see the pane?" at all and give the notice a
   sink in the window the user is *demonstrably* looking at — the ASE session
   window (issue 0655).

Option 3 subsumes this issue and is the one the user's ruling in the ledger may
settle; do not build 1 or 2 before that ruling comes back.

## Still open

All of it. Any claim that this channel "cannot go silent" must be narrowed to
withdrawn / iconified / never-created until this is closed.
