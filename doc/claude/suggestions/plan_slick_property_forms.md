# Plan — slick per-property edit forms (Cadence-style)

*Goal:* replace XSCHEM's raw single-text-box property editor (the "Edit
Properties" dialog) with a structured Tk form that gives **one validated entry
field per property**, eliminating malformed `token=value` input, with **Enter =
OK** (from any field) and **Escape = Cancel** (any time, discard changes).

Status: **PLAN ONLY — no code yet.** Branch `slick-property-forms`. Analysis
below is run-verified against the build on this branch.

> **Decisions ratified by the user (2026-06-13):**
> 1. **Cadence-style** — the form shows *all declared* symbol attributes (from the
>    template), not just ones already set on the instance.
> 2. **Strict** — the user may not add undeclared properties through the form; the
>    declared template set is the field list (with one safeguard for pre-existing
>    undeclared tokens, §4.5).
> 3. **Structured form is the ONLY path** — no "Raw view" text-box fallback. This
>    raises the stakes on lossless round-trip (§6): the form must faithfully
>    represent and preserve *every* property string it can be opened on.
> 4. **Multi-line supported where needed — but DEFERRED to v2.** v1 uses a
>    **single-line entry for every value field** (keep it simple). Multi-line
>    values still round-trip safely (preserved byte-for-byte if untouched, via
>    subst-into-original §4.3); editing them in a one-line box is awkward, which is
>    why the multi-line widget is a v2 item (§4.4).
>
> **v1 build choices (confirmed):** pure-Tcl reskin, no C changes (§7.A); single-
> line entries only (§4.4); subst-into-original reassembly (§4.3, §7.C) — **only the
> fields the user actually touched are modified on submit**; pre-existing undeclared
> "Extra" tokens are **retained** (shown editable + deletable, never auto-dropped,
> §4.5). **All decisions settled; the plan is ready to implement.**

---

## 1. What the dialog is today (the screenshot)

The "Edit Properties" window is the Tcl proc **`edit_prop {txtlabel}`**
(`src/xschem.tcl:7372`). It is the instance/symbol attribute editor. Its core is
a single multi-line `text` widget (`.dialog.symprop`) holding the object's
**entire raw property string**, e.g.

```
name=E1 TABLE="1.4 0.0 1.6 4.0"
```

The user edits that string by hand. Around it: a Symbol entry + Browse/Load/
Del, three checkbuttons (No change properties / Preserve unchanged props / Copy
cell), and an "Edit Attr" combobox that lets you isolate one token at a time.

**Why it's bad:** the user types free-form `token=value` text, so `penguin=shark`
is accepted silently; long unstructured strings are unreadable; there is no
field-level structure, default visibility, or validation.

## 2. The C ↔ Tcl contract (the key enabler)

The property editors all follow the same protocol, and it is what makes a slick
form **mostly a Tcl-only change**:

1. **C** (`editprop.c`, e.g. `edit_property()` / `edit_symbol_property()`) puts
   the object's current property string into the Tcl variable `tctx::retval`,
   then calls the Tcl dialog proc.
2. **The Tcl dialog** lets the user edit, then on OK sets `tctx::retval` to the
   **new** property string and `tctx::rcode` to `ok` (Cancel leaves `rcode`
   empty).
3. **C** checks `tctx::rcode != ""`, reads `tctx::retval`, and applies it to the
   selected object(s) via `set_different_token` / `my_strdup` (honoring the
   `preserve_unchanged_attrs` / `no_change_attrs` globals the checkbuttons set).

**Consequence:** if the new form still produces the same `tctx::retval` string
and `tctx::rcode` flag, **no C code changes are required.** The form is a pure
reskin of `edit_prop` that parses `tctx::retval` into fields and reassembles it
on OK. This is the single most important architectural fact in this plan — it
makes the change low-risk and incremental.

## 3. The pieces already in place (verified)

Everything a field-based form needs already exists and is reachable from Tcl:

| need | primitive | verified result |
| --- | --- | --- |
| list a prop string's tokens (field names) | `list_tokens <prop>` | `list_tokens "name=p0 lab=PLUS"` → `name lab` |
| the declared-attribute set + defaults | `xschem getprop instance <n> cell::template` | → `name=p1 lab=xxx` (**the Cadence "all properties" source**) |
| read one token's value (quoted form) | `xschem get_tok <prop> <tok> [flags]` | flag `2` returns the re-substitutable quoted form |
| write one token back (lossless quoting) | `xschem subst_tok <prop> <tok> <val>` | used today by the "Edit Attr" combobox |
| the full current prop string | `xschem getprop instance <name>` | → `name=p0 lab=PLUS` |

**Multi-line values are first-class in the data model** (verified): an attribute
value may contain literal newlines, stored inside the quotes. From
`xschem_library/devices/code.sym`:

```
format="
@value
"
```

i.e. the `format` token's value is `\n@value\n`. The form must round-trip such
values losslessly (§4.4, §6); `get_tok`/`subst_tok` already carry the newlines
and quoting, so the work is on the widget side, not the data side.

The existing "Edit Attr" combobox (`xschem.tcl:7524-7567`) is a **working
reference implementation of the per-token read/write round-trip**, including the
fiddly quote-escaping dance (`regsub` escape `"`/`\`, wrap in `"`, `subst_tok`).
The new form reuses exactly that per field — *do not reinvent the quoting.*

## 4. The design

### 4.1 Field model — why it kills `penguin=shark`

The form shows **one row per property**: a fixed **label = the token name** and an
**entry/value widget**. The user edits *values only*; token names are labels, not
text the user types. Malformed `token=value` soup becomes structurally
impossible. Adding a genuinely new property is a separate, explicit, *validated*
affordance (§4.5), not free text.

```
 name   [ E1                    ]   ← single-line entry (v1: all fields are single-line)
 TABLE  [ 1.4 0.0 1.6 4.0       ]   ← quotes handled by the round-trip, hidden from the user
 lab    [ xxx (default)         ]   ← declared in template, unset → greyed default placeholder
 ── Extra (undeclared) ──────────    ← only if this instance carries non-template tokens
 foobar [ 123                   ] ×  ← editable + deletable; but no "+ add" (strict)
                                        [ OK ]  [ Cancel ]
 Enter = OK (from any field) · Escape = Cancel · strict, no Raw view (decisions 2 & 3)
```

### 4.2 Where the field list comes from (Cadence-style, strict)

The field list is driven by the **symbol template** — the declared attributes —
so the form shows every field the symbol defines, set or not (decision 1):

1. **Declared fields** = `list_tokens [xschem getprop instance <n>
   cell::template]`. Each declared token is a row. Its value is the **instance's**
   value if set, else the **template default** (shown as a greyed placeholder so
   the user sees the default but it isn't written unless edited — §7.B answer).
2. **Pre-existing undeclared tokens** = instance tokens not in the template. Under
   **strict** mode the form does **not** let the user *add* new undeclared tokens
   (§4.5), but it must not silently drop ones that already exist (there is no Raw
   fallback to recover them — decision 3). So show them in a clearly-labelled
   **"Extra (undeclared)"** section: editable and deletable, but no "add" there.

This keeps the form Cadence-strict for new input while guaranteeing **no existing
data is hidden or lost** — essential given the form is the only path.

### 4.3 Reassembly on OK — subst-into-original (the correctness core)

On OK the form must turn the fields back into one property string. **v1 uses
subst-into-original** (confirmed): keep the object's *original* string as the
base, and for each field the user **actually edited**, surgically replace just
that token's value with `xschem subst_tok <string> <token> <newval>`. Tokens the
user didn't touch are never rewritten.

```
original:  name=E1 TABLE="1.4 0.0 1.6 4.0"
user edits name E1 -> E2, touches nothing else
result:    name=E2 TABLE="1.4 0.0 1.6 4.0"   (subst_tok swapped only E1->E2;
                                              TABLE's exact quoting/spacing intact)
```

Contrast — *assemble-fresh* (rebuild the whole string from all fields) would risk
reordering tokens, changing quoting, or adding template attrs the user never set,
so "open + OK with no edits" could silently mutate the string. Subst-into-original
guarantees the form changes **only** what the user typed — the cardinal invariant
(§6), and essential with no Raw fallback (decision 3).

**Mechanism:** track a **dirty flag per field** (current value != loaded value);
on OK, `subst_tok` once per dirty field into the running string. Bonus: an unset
declared field left untouched stays unset (not dirty → never written), which is
exactly the greyed-default behavior (§4.2). The dirty set also pre-wires the later
multi-object "apply only changed fields" feature (§8).

### 4.4 Long / multi-line values — v1 single-line, widgets deferred to v2

**v1: every value field is a single-line `entry`** (confirmed — keep it simple).
No `text` widgets, no expand toggles, no per-field multi-line detection. Because
v1 uses single-line entries throughout, **Enter = OK works from every field with
no exception** (there is no widget in which Enter needs to mean "newline").

**What about genuinely multi-line values?** A few attributes hold embedded
newlines (`code.sym`'s `value`/`format`, `ngspice_*`, etc.). In v1 they:
- **round-trip safely** — subst-into-original (§4.3) preserves any field the user
  doesn't edit byte-for-byte, newlines and all. Opening the form on a `code`
  instance and clicking OK does not harm its `format`/`value`.
- **display awkwardly if the user tries to edit them** — a one-line `entry` is a
  poor place to edit a newline-bearing value. That awkward case is precisely what
  the **v2 multi-line widget** addresses.

**v2 (deferred):** for the known multi-line attributes (`value`, `format`,
`*_format`, `template`, `model`, `descr`, …) render a `text` widget instead of an
`entry`; there Enter inserts a newline and **Ctrl/Shift+Enter** commits (the OK
button always commits), and **Tab** is rebound to focus-next (a `text` widget eats
Tab). This is the only place "Enter = OK everywhere" needs an exception, which is
why it is isolated into v2.

Either way the round-trip test corpus (§6) **must include the multi-line symbols**
(`code.sym`, `launcher.sym`, the `ngspice_*` family) from v1 onward — preservation
of those values is required even though editing them is a v2 nicety.

### 4.5 Adding / deleting a property (strict)

Under **strict** mode (decision 2) there is **no general "add arbitrary property"**
affordance — the declared template set *is* the editable field list, which is the
Cadence-for-fixed-cells behavior and keeps junk input impossible by construction
(the user never types a token name for a declared field; they fill values).

- **Declared fields:** value-only editing; the token name is a fixed label.
- **Pre-existing undeclared tokens** (the "Extra" section, §4.2): editable and
  **deletable** (per-row ×, reusing the token-removal path), so the user can clean
  them up — but none can be *added*.
- **Future / non-strict symbols:** if some symbols later want user-extensible
  attributes, a guarded **[+ add property]** (name validated
  `^[A-Za-z_][A-Za-z0-9_]*$`, non-empty, no whitespace) is the controlled opening
  — kept out of v1 per the strict decision.

### 4.6 Validation (phased)

- **v1 — structural only.** Separate fields already remove the malformed-string
  class of error; no per-value rules yet. This alone meets the stated goal.
- **v2 — per-attribute validators (future).** A small built-in map for well-known
  attrs (`dir` ∈ {in,out,inout}; booleans → checkbox; `name` non-empty;
  numeric-only where known), surfaced as a red border + blocked OK on invalid.
  Templates carry no rich type system today, so this starts as a curated map,
  optionally extended by `type=`/`format=` hints if a symbol provides them.

### 4.7 Keyboard contract (explicitly requested)

- **Enter → OK from any field** in v1, with no exception, because every field is a
  single-line `entry` (an `entry` never needs Enter for a newline — unlike the
  current text box, which is why it binds **Shift**-Enter to OK at
  `xschem.tcl:7516`). The lone exception arrives only with the v2 multi-line
  widgets (§4.4), which is why they are deferred.
- **Escape** any time → Cancel and discard. Drop the current conditional guard
  (`xschem.tcl:7517-7522`) that only cancels when nothing changed; make it
  unconditional, matching the request.

### 4.8 Features to preserve

The reskin must keep: the Symbol entry + Browse/Load/Del, the three checkbuttons
(their globals `no_change_attrs` / `preserve_unchanged_attrs` / `copy_cell` are
read by C — keep the widgets and variable names), and the OK/Cancel/WM-close
semantics. The "Edit Attr" combobox becomes redundant (per-field editing
supersedes single-token isolation) — remove it, or repurpose it as a "jump to
field" selector.

## 5. Scope: which dialogs

`edit_prop` (instance/symbol — the screenshot) is the target and the hardest, so
do it first. The same pattern generalizes to the dialog family (later, via a
shared `build_property_form` proc):

| proc | edits | priority |
| --- | --- | --- |
| `edit_prop` (`:7372`) | instance / symbol attributes | **v1** |
| `text_line` | graphical objects (rect/line/poly/arc/wire) props | v2 |
| `enter_text` | text object (string + size) | v2 |
| `graph_edit_properties` (`:3448`) | graph objects | v3 |
| `edit_vi_prop` / `edit_vi_netlist_prop` | external editor | leave as-is (power escape hatch) |

Factor the parse→fields→reassemble logic into reusable procs so each dialog is
thin.

## 6. The cardinal invariant & testing

**Invariant: opening the form on any object and clicking OK with no edits must
leave the property string byte-identical.** Quoting, escaping, ordering, empty
values, multi-line values, embedded `"`/`\`, and `TABLE="…"`-style space-bearing
values must all round-trip losslessly. This is the #1 risk and the #1 test —
**and decision 3 (no Raw fallback) makes it a hard release gate**: since the form
is the only path, a value it can't faithfully represent is a value the user can no
longer edit safely. **Gate: the round-trip suite must be green across the *entire*
shipped symbol library** (`xschem_library/devices/*.sym` templates + a sweep of
example schematics) before the structured form replaces the text box.

Testing approach (Tk dialogs are awkward headless, so split the work):

- **Headless round-trip suite (the core).** Factor parsing/assembly into pure
  Tcl procs (`prop_to_fields`, `fields_to_prop`) with **no widget dependency**,
  and unit-test them: for a corpus of real prop strings (pull from
  `xschem_library/devices/*.sym` templates + instances), assert
  `fields_to_prop(prop_to_fields(p)) == p`. Hammer the hostile cases (quotes,
  escapes, multi-line, empties). This catches the quoting bugs without a display.
- **Sabotage / green-but-hollow.** Each test fails first; after GREEN, perturb the
  assembler (e.g. drop quoting) and confirm the round-trip tests redden. Assert
  *exact* strings, not "non-empty". [[green-but-hollow]]
- **GUI smoke (manual / `verify` skill).** Enter→OK, Escape→Cancel, add/delete
  property, Raw toggle, long-value widget, on a couple of real symbols.

## 7. Decisions

- **A. C changes: zero or some?** **RATIFIED — pure-Tcl reskin, no C changes for
  v1** (keeps the `tctx::retval`/`rcode` contract, lowest risk). A richer C-side
  field API (`xschem object_fields <handle>` → name/value/type/default dicts,
  composing with the stable-handles `object` API) is a possible v2 upgrade.
- **B. Unset declared attrs:** **RATIFIED (decision 1)** — shown, with the template
  default as a greyed placeholder that is *not written* unless the user edits it.
- **C. Reassembly strategy:** **RATIFIED — subst-into-original** (§4.3; lossless,
  required by the §6 gate + no-Raw-fallback).
- **D. Raw toggle:** **RATIFIED (decision 3)** — no Raw fallback; structured form is
  the only path. (Raises §6 to a release gate.)
- **E. Add-property:** **RATIFIED (decision 2)** — strict; no arbitrary new tokens
  in v1. Pre-existing undeclared tokens are shown/editable/deletable but not
  addable (§4.5).

## 8. Forward hook — multi-object / all-objects (the user's "later")

Bake one thing in now so the later feature is cheap: **track which fields the
user edited** (the dirty set, §4.3). The eventual "apply to all selected / all in
view" then means: for each target object, `subst_tok` only the dirty fields into
*its* prop string — which is exactly what the existing C
`preserve_unchanged_attrs` + `set_different_token` path already does. So the form
should expose "the set of changed (token,value) pairs," and the apply loop
(C or Tcl) iterates objects. Designing the form around *dirty fields* rather than
*the whole string* is the one decision that makes §8 nearly free later.

## 9. Effort

- **v1 (`edit_prop` reskin, pure-Tcl, single-line fields, strict + Extra section,
  subst-into-original, Enter/Escape, headless round-trip suite):** ~1.5–2 days now
  that multi-line widgets and the Raw fallback are out of v1. Dominated by the
  quoting round-trip correctness (the §6 gate), not UI.
- **v2 (shared proc + `text_line`/`enter_text`, per-attr validators):** ~2 days.
- **multi-object apply (§8):** ~1–2 days once the dirty-field model exists.

Recommend shipping **v1 on `edit_prop`** first behind a "Raw view" fallback, get
it in front of the user, then generalize.

## 10. Open questions for the user

**None — all v1 decisions are settled (2026-06-13).** The "Extra (undeclared)"
call is resolved: the strict form **shows** pre-existing non-template tokens
(editable + deletable) and **retains** them on submit; only fields the user
touches are modified. Remaining items are explicitly v2 (multi-line widgets and
their Enter/Tab handling, optional per-attribute validators, the other dialogs in
§5, and a possible C `object_fields` API). **v1 is ready to implement.**

---

*Grounding: `edit_prop` `src/xschem.tcl:7372-7600`; the C contract
`editprop.c` (`edit_property`/`update_symbol`, `tctx::retval`/`tctx::rcode`,
`set_different_token`, `preserve_unchanged_attrs`); token primitives
`scheduler.c` `get_tok` (`:2291`), `subst_tok` (`:6987`), `list_tokens`
(`:3259`), `getprop ... cell::template` (`:2105`); template store
`xctx->sym[].templ` (`token.c`). Runtime checks (template + list_tokens +
get_tok) verified via a scratch script on `mos_power_ampli.sch`. Companion:
`object_query_api.md` (the handle/`object` API a v2 C field-API would compose
with).*
