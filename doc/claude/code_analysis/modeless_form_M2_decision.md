# M2 — full modeless property form: D1 guard audit + decision

**Status:** IMPLEMENTED 2026-06-14 (RED `a557170f` / GREEN `ad8c7f45`) — Option A
(non-blocking form) + D3 drop `wm transient` + initial `raise`. PENDING the manual
eyeball pass (D3 focus/activation is WM-dependent; see the issue's eyeball
checklist). Headless suite 226/226; main regression + headless callback tests green.
**Issue:** `doc/claude/issues/0009-property-form-not-fully-modeless-blocks-schematic.md`
**Builds on:** M1 modeless-selection (`doc/claude/code_analysis/modeless_property_form_decision.md`),
the slick form (`src/property_form.tcl`), the input dispatcher (`src/callback.c`).
**Goal:** with `slickprop::edit_form` open, the schematic accepts **all** bound
commands (not just zoom + Shift-select), the form floats non-capturing and stays
consistent with the live selection, and the genuine in-gesture re-entrancy guard
is untouched.

---

## 0. TL;DR (the audit's key correction)

The issue's D1 assumed the blocker is the form's explicit
`xschem set semaphore +1` (`property_form.tcl:878`), and that simply *not* raising
it would let the canvas run. **The audit shows that is not the dominant cause.**

The real lock is **`callback()` is still on the C stack while the form is open**,
because `edit_form` ends in `tkwait window .dialog` (`property_form.tcl:1050`). The
form is launched from inside a callback (the `q` key, or a menu command that itself
runs inside the Tk event loop), and `tkwait` blocks that frame without letting it
return. So:

- `callback()` bumps `semaphore` on entry (`callback.c:5568`) and drops it on exit
  (`:5672`). Idle baseline is **0**; inside one callback it is **1**; a genuinely
  re-entrant (nested) callback reaches **2** — that is the real meaning of the
  `>= 2` guard.
- While the form is open, the launching callback never returns (blocked in
  `tkwait`), so the baseline sits at **1** (the launching frame) **plus** the form's
  explicit `+1` = **2**. Any *new* canvas event opens a nested callback → **3**.
- Therefore **every `semaphore >= 2` guard trips on the very first canvas event** —
  which is exactly "only zoom (ungated) + Shift-select (the M1 carve-out at
  `:5002`) work."

**Consequence:** removing only the explicit `+1` is insufficient — the launching
frame alone still holds baseline 1, so a nested event still reaches 2 and stays
blocked. To return the baseline to 0 (canvas fully live at semaphore 1), the form
must become **non-blocking**: drop `tkwait`, let `edit_form` (and the launching
callback) return, and keep the form alive as an independent Tk toplevel. The apply
no longer needs the blocking return — for `x==0` it already happens mid-session via
`xschem apply_properties` (see §3).

---

## 1. Guard-by-guard audit

`grep -nE 'semaphore *>= *2' callback.c scheduler.c actions.c` → ~70 sites, all in
`callback.c`. Classified by purpose, not line-by-line (the per-chord ones are
identical):

| Bucket | Sites | What it guards | Verdict |
|---|---|---|---|
| **Counter infrastructure** | `5568` (entry `++`), `5672` (exit `--`), `5565`/`5673` (redraw-only window switch), `5586` (reentrant-call debug log) | The re-entrancy counter itself. | **KEEP, untouched.** This *is* the mechanism. |
| **In-gesture re-entrancy guards** | `1866`, `1891` (wire/line start); `3306` (motion); `5313` (button release); `5347` (double-click); every `if(semaphore>=2) break;` in `handle_key_press` (`3469`…`4907`) | Suppress side-effectful ops while a callback is *already on the stack* (true nested entry). | **KEEP, no edit.** Not form-specific. Once the form is non-blocking, baseline is 0, so these stop firing for the form **automatically** — they only fire on genuine nesting, as designed. |
| **Button-chord gate** | `4980` (`semaphore < 2 && dispatch_button_chord`) | Disables bound button chords while busy. | **KEEP.** Re-enables for the form automatically once baseline returns to 0. |
| **Dialog carve-outs (the only behavioural change)** | `5002` (`button1 && semaphore>=2`): legacy modal branches `5021`–`5036` **and** the M1 slick branch `5013`–`5020` | The legacy modal `edit_prop`/`text_line` "click = OK / click = re-select" behaviour, plus M1's "selection stays live + fire `on_selection_changed`." | **SPLIT.** Legacy branches stay (legacy `edit_prop_legacy` still blocks/bumps). The **M1 slick branch must MOVE** out of the `>=2` carve-out: once non-blocking, a live click runs at semaphore **1**, so `5002` no longer fires for the slick form — the `on_selection_changed` notification has to be re-hosted on the normal selection-completion path, gated by `slickprop_form_open`. This is a *relocation*, not a removal, of M1. |

**Audit conclusion:** **no guard needs to be rewritten to special-case
`form_open`.** The fix is to stop the form from inflating the baseline semaphore
(make it non-blocking), and to relocate the single M1 selection-notification hook
that piggybacked on the `>=2` carve-out.

---

## 2. D1 decision — make the slick instance form non-blocking

**Chosen approach (Option A).** Turn `edit_form` into a normal modeless toplevel:

1. Delete the explicit `xschem set semaphore +1`/`-1` (`property_form.tcl:878`,
   `:1053`).
2. Delete `tkwait window .dialog` (`:1050`). `edit_form` builds the form and
   returns immediately; the launching callback unwinds; baseline → 0.
3. Move the post-`tkwait` cleanup (`:1051`–`:1053`: clear `slickprop_form_open`,
   remove the `apply_scope_greying` trace) into the close handlers (`slickprop::ok`,
   `slickprop::cancel`, `WM_DELETE_WINDOW`) — which already clear the flag, save
   geometry, clear the highlight and `destroy .dialog`. Add the trace removal there.
4. Relocate the M1 notification: drop `5013`–`5020` from the `5002` carve-out and
   instead call `slickprop::on_selection_changed` from the **normal** interactive
   selection-completion path(s), gated by `tclgetboolvar("slickprop_form_open")` —
   the single-click select endpoint and the rubber-band `ButtonRelease` endpoint in
   `callback.c`. (M1 behaviour is preserved; it just no longer needs `semaphore>=2`.)

**Why blocking is safe to drop for `x==0`:** `edit_symbol_property` (`editprop.c`)
calls `edit_prop` → `edit_form` and, *for `x==0`*, ignores the return/`rcode`: it
reads `tctx::applied` (pre-set to `0`, `:1123`) and does **not** route through
`update_symbol` (`:1046`–`:1048` comment). All applies for the slick form happen
mid-session via `xschem apply_properties` from `do_apply`. So returning early with
`tctx::applied==0` and `rcode=={}` changes nothing the caller relies on. (The
legacy/vim paths `x==1/x==2` keep their own blocking flow and are untouched —
`edit_prop` → `edit_form` is *only* the instance `x==0` path; `xschem.tcl:7617`
wrapper, callers: `editprop.c:1124` and `scheduler.c:1128`.)

**Rejected — Option B (keep blocking, relax each guard with `&& !form_open`):**
~70 edit sites, re-conflates the two meanings the audit just separated, and does
not address the launching frame still holding baseline 1. Brittle and wrong-shaped.

---

## 3. D2 — consistency when the edited object is deleted/replaced

Largely **already handled**, verified this session:

- `apply_instance_properties` (`editprop.c:1035`) does
  `idx = inst_index_from_id(displayed_id); if(idx < 0) return 0;` — a vanished
  stable id is a graceful no-op at the C apply layer.
- `do_apply` guards `$nav(disp_id) ne {} && $nav(disp_id) >= 0`
  (`property_form.tcl:477`).
- Move/rotate keep the id, so the form stays correct across those.

**To harden (M2):** when the live canvas now lets the user delete the edited
instance while the form floats, extend the M1 selection-reactive path so the form
reflects the vanished id (e.g. the next `on_selection_changed`/Apply re-resolves
and, if `disp_id` no longer resolves, the form greys Apply/OK or re-targets to the
remaining selection rather than silently applying to nothing). Confirm Apply/OK
**no-op cleanly** (no crash, no mis-apply to a reused index) in a RED test.

## 4. D3 — focus / window behaviour

Make the form a non-capturing floating toplevel so the schematic title bar can
activate it:

- Relax/drop `wm transient .dialog [xschem get topwindow]` (`:887`) so the WM does
  not glue the dialog above + focused; keep an initial `raise .dialog` so it is not
  born behind. Exact behaviour is **X11-WM-dependent** → this is the part that needs
  a **manual eyeball pass on the actual display**, not a headless assert (WSLg is
  unreliable for focus/activation; see §6).

## 5. D4 — Apply-to-live-selection

The "Apply to" scope already keys off the live selection via M1
(`selected_inst_ids` → `xschem objects -type instance -selected`). With full canvas
use this is unchanged; the RED tests should confirm Apply/OK/Next/Prev still behave
when the selection changed out from under the form (scope = selected/all re-reads
the live set at apply time).

---

## 6. Test plan (RED-first, after ratification)

Headlessly assertable in `tests/property_form/{wrap,body}.tcl` (`xschem get/set
semaphore` exist):

- **M2-sem:** with the form open, `xschem get semaphore` returns **0** at idle (not
  ≥1) — proves the form no longer inflates the baseline.
- **M2-live:** a bound canvas command that was previously blocked now takes effect
  while the form is open (e.g. select-all then a delete, asserted via
  `xschem get instances` / `xschem objects`).
- **M2-retarget:** canvas selection change still re-targets the form (M1 preserved)
  via the relocated hook — assert `nav`/`xschem objects -selected` agree.
- **M2-vanish (D2):** delete the edited instance, then Apply/OK → no crash, applies
  nothing (`apply_properties` returns 0; modify state unchanged).
- **Manual eyeball (D3, recorded in the issue):** form open → click schematic title
  bar activates it; all commands run; form stays on-screen, non-capturing; raise/
  lower works. WM-dependent; the real gate.

**Env rules (carried):** run from `src/` (`cd .../src && ./xschem`); suite via
`cd src && timeout -s KILL 120 ./xschem -q --script ../tests/property_form/wrap.tcl`
→ `/tmp/sh_pf_test.log`; ignore a lone `PF42` flake; `proc f {a b}` needs a space
before `{`.

---

## 7. STOP — ratification questions

1. **Approve Option A (non-blocking form)** over Option B (relax guards)? The audit
   says A; B is rejected as wrong-shaped.
2. **D3 scope:** drop `wm transient` entirely, or keep it but add an explicit
   "activate schematic" affordance? (X11-WM-dependent; recommend drop + initial
   `raise`, then eyeball.)
3. Any concern about the legacy `x==1/x==2` (vim) paths, which stay blocking and
   keep their `5002`/`5021`–`5036` carve-outs untouched?
