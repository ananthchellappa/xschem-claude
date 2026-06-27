# Issue 0051 — Read-only view: Create Instance is wrongly allowed, viewing Properties is wrongly blocked

**Opened:** 2026-06-27
**Status:** OPEN
**Severity:** MEDIUM — read-only semantics are inverted on two paths: an edit slips through, a
non-edit is refused. Annoyance + a latent data-integrity hole (see §2.1).
**Branch:** `fluid-editing`.
**Source:** user report.
**Affects:** `src/create_instance.tcl` `ciform::open`; `src/callback.c` `case 'q'` (the
`readonly_block()` guard at ~:4433); `src/property_form.tcl` `slickprop::edit_form` /
`do_apply` / `maybe_apply_then`; the graphical/legacy property dialogs in `src/xschem.tcl`
(`text_line_slick`, `text_line_legacy`, `enter_text`).
Related: [[readonly-enforcement]], [[descend-readonly]], issue 0041 (enforcement altitude).

---

## 1. Symptom

On a schematic/symbol opened **Read-Only** (Cadence browse mode, or File > reopen, or
`xschem set readonly 1`):

1. **Create Instance is allowed.** Pressing **`i`** (Cadence binding → `xschem create_instance`)
   opens the *Create Instance* form and lets the user arm a placement. Creating an instance **is**
   an edit, so it must be refused on a read-only view — exactly like every other edit gesture.

2. **Viewing Properties is blocked.** Selecting an object and pressing **`q`** (Properties → Edit)
   pops the modal:

   > View is Read Only.
   > Use Edit > Make Editable to enable editing.

   …and opens nothing. **Viewing** properties is **not** an edit. The form should open so the user
   can read — and even experiment with — the values (fields are sometimes linked; tweaking one and
   watching the others is useful even though dependent recompute is not implemented yet). What must
   be prevented is **committing**: on a read-only view the Properties form should show **OK** and
   **Apply** greyed out, leave the fields editable, and treat **Enter** the same as **Esc**
   (Cancel). Cancel is the only exit that changes nothing — and the only one that should be needed.

## 2. Root cause

Read-only is enforced at **keyboard-dispatch altitude** (`readonly_block()` + scattered guards in
the `handle_key_press` switch — see [[readonly-enforcement]]), and the two paths above sit on the
wrong side of that line.

### 2.1 Create Instance bypasses the guard (and the menu greying)
The C `case 'I'` handler *is* guarded (`callback.c:4128 readonly_block()`), and the Edit-menu
"Create Instance" item *is* greyed (`edit_menu_post`, `xschem.tcl`). But the Cadence rc rebinds the
key to the Tcl form:

```
bind .drw <Key-i> {xschem create_instance; break}   # src/cadence_style_rc
```

`xschem create_instance` (`scheduler.c:625`) → `ciform::open` (`create_instance.tcl`) opens the
form with **no** read-only check, bypassing both the C handler and the menu state. Worse, the form's
placement fires `xschem place_symbol` and the canvas drop mutates the buffer with no `readonly`
consultation at the mutation site (the issue-0041 leak-by-default, here reached via the `i` key).

### 2.2 Properties is blocked at the wrong altitude
`case 'q'` (rstate==0) calls `if(readonly_block()) break;` **before** `edit_property(0)`
(`callback.c:4433`). So the keyboard refuses to even open the viewer. (The menu *Properties > Edit*
→ `xschem edit_prop` has **no** such guard, so the menu and the key already disagree — the menu
opens the form, the key refuses it.) The block is too blunt: it conflates "open the property
viewer" with "mutate the object". Opening is a view; only the OK/Apply commit is the edit.

## 3. Fix

Two independent, surgical changes — keep enforcement where the gesture's *intent* is known.

### 3.1 Create Instance — refuse on a read-only view (it is an edit)
Guard the single chokepoint every route funnels through: at the top of `ciform::open`
(`create_instance.tcl`), if `[xschem get readonly]` show the standard read-only notice and return
without building the form. This covers the `i` key, the Edit-menu item, and any scripted
`xschem create_instance [lcv]`. Use the same wording as `readonly_block()` via a small shared Tcl
helper (`readonly_notice`) so the C and Tcl messages stay identical.

### 3.2 Properties — open as a read-only viewer (it is not an edit)
- **Unblock the viewer:** drop `if(readonly_block()) break;` from `case 'q'` (rstate==0) in
  `callback.c` so the key opens the form like the menu already does. (Leave **`Q`** = *Edit with
  editor* / `edit_property(1)` blocked — that is an explicit external-editor edit, and a pure
  **View** already exists on `Ctrl+Shift+Q` / `edit_property(2)`.)
- **Make the form a viewer when `[xschem get readonly]`:**
  - *Instance slick form* (`slickprop::edit_form`): disable **OK** and **Apply**, keep **Cancel**,
    retarget `<Return>`/`<KP_Enter>` to Cancel, and update the hint to say the view is read-only.
    Fields stay editable (experimentation allowed); nothing can be committed.
  - *Defensive commit guards* (so no callback/path can write through a read-only view):
    `slickprop::do_apply` returns 0 immediately when read-only; `slickprop::maybe_apply_then`
    (the Next/Prev + selection-change "apply pending edits?" prompt) skips the prompt and just
    proceeds (no apply) when read-only.
  - *Graphical + legacy dialogs* reachable from `q` for non-instance objects — `text_line_slick`
    (rect/gfx), `text_line_legacy` (wire / text / global netlist props), `enter_text` (graphical
    text): disable the **OK** commit button. Where the dialog binds `<Return>` to OK
    (`text_line_slick`, `enter_text`), retarget it (and `<Shift-Return>` in the text box) to Cancel.
    `text_line_legacy` keeps `<Return>` = newline (multi-line editor); make `<Escape>` cancel
    unconditionally there so there is always a no-op exit. These dialogs already apply **only** when
    their `tctx::rcode != ""`, so a disabled OK + Cancel-on-Escape means a read-only open writes
    nothing even if the underlying `edit_*_property` C path runs.

No mutation-chokepoint refactor here (that is issue 0041); this restores correct *intent* on the two
reported paths and makes the Properties form a first-class read-only viewer.

## 4. Acceptance

1. Read-only view, press `i`: the Create Instance form does **not** open; the read-only notice is
   shown. Same for Edit > Create Instance and `xschem create_instance`. After `Ctrl+2`
   (Make Editable) the form opens normally.
2. Read-only view, select an instance, press `q`: the Properties form **opens**; **OK** and
   **Apply** are greyed; fields are editable; **Enter** and **Esc** both Cancel and change nothing;
   no `*`/modified marker appears. Same for a wire / graphical text / rect / global props.
3. After Make Editable, `q` opens the form with OK/Apply **enabled** and applying works as before.
4. Editable (non-read-only) views are unchanged on every path.
