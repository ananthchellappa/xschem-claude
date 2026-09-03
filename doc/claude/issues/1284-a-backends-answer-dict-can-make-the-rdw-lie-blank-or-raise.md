# 1284 — a backend's answer dict can make the RDW lie, blank, or raise

**Filed by:** item **B3**, 2026-09-03. Found by B3's adversary (Verify-C);
**four shapes re-measured independently by the write-up agent**, which found one
the adversary did not report (an **uncaught raise**). **FILED, NOT FIXED.**

**Status:** open. **Unreachable through the shipped ngspice backend**; reachable
by any third-party backend the **D-5** seam exists to admit.

---

## 1. Why this is filed at all

The whole point of ruling **D-5** and of `ase::backend_hook` is that
*"nothing above the seam changes when the wildcard arrives"* — a second simulator
plugs in and the window renders its answer. `rdw::format_answer` therefore treats
the five-key dict as **trusted input**, and it is not: it is whatever a backend
hands it.

Today `ngspice`'s `op_param_set` builds `devices` with `dict set` and gates every
value through `op_annot::raw_class`'s `string is double -strict`, so none of the
shapes below can occur. That is a property of **one backend**, not of the
renderer.

## 2. Four shapes, measured on this binary, 2026-09-03

All four driven through `rdw::block_text [rdw::format_answer $a $ctx]` with
`ctx = {header {M1:/} devpath @m.x1.m1 simtype op instname M1}`.

### (a) malformed at the DICT level → **a confident wrong answer**

`devices` = `"@m.x1.m1 {{id 1"` (not a valid list). `rdw::_rowdevs`'s `catch`
swallows it, the union comes back empty, and `format_answer` renders the
**fifth silence**:

```
M1:/
@m.x1.m1
This run's raw holds no operating-point columns for @m.x1.m1. Only parameters the deck explicitly saved appear here.
```

That sentence is a **statement about the raw** and it is false — the backend did
answer, its answer was unreadable, and the window says the run saved nothing.
This is the *wrong-answer-wearing-a-healthy-state* shape that returned item **B1**
`[F]` (issue 1272), one layer out.

### (b) malformed at the VALUE level → **an uncaught raise** *(not reported by the adversary)*

`devices` = a well-formed dict whose **value** is `{{id 1`:

```
RAISED: unmatched open brace in list
```

The raise escapes `rdw::format_answer` — the pure renderer, which every row of
the suite and every widget path calls. `_rowdevs` catches at the dict level;
nothing catches the `foreach {p v}` over a value. In the Tk path this surfaces as
a background error and the pane paints nothing.

### (c) a value-less pair → **blank, with no footnote**

`devices` = `{@m.x1.m1 {{id}}}` (a one-element pair) renders

```
    id :
```

i.e. **byte-identical to an `absent` column**, but without the footnote that
explains what a blank means. The renderer's one honest distinction between
"absent" and "present" is lost.

### (d) a newline inside a value → **one pair becomes two lines**

`devices` = `{@m.x1.m1 {{id "1.5\nINJECTED"}}}` renders

```
    id : 1.5
INJECTED
```

The second line is unindented and carries **no tag**, so it is neither a value
row nor a note. The one-pair-one-line model that `rdw::block_text` and
`rdw::render_pane` share is broken from the data side.

## 3. The related case that IS reachable: the footnote is per-block, not per-row

Measured separately, and this one needs no hostile backend:

* an **empty-string** value renders `    id :`
* a genuinely **absent** column renders `    id :` **plus** the block footnote
  *"A blank value means the raw names that column but the simulator did not
  compute it."*

The footnote is emitted **once per block, when `absent` is non-empty**. So in a
block that has *any* absent column, an empty-string value inherits a footnote
that is **false about it**. Low reachability through ngspice (values are
`string is double -strict` gated), but the coupling is in the renderer, not the
backend.

## 4. The fix

Small and entirely inside `src/rdw.tcl`; not applied here because it changes the
renderer B3 has just fenced with 42 checks, and because the choice of *what to
say* when a backend answers rubbish is itself a user-visible sentence (see rule
debt `1245_B3_window_wording`):

1. Wrap the per-value `foreach {p v}` in the same `catch` `_rowdevs` already has,
   so (b) cannot raise.
2. Give a malformed answer its **own sentence** — something that names the
   backend and says its answer could not be read — instead of letting (a) and (b)
   fall into the fifth silence, which is a claim about the *raw*.
3. Make the blank footnote per-row, or render a value-less/empty-string pair
   distinguishably from an absent column, closing (c) and §3.
4. Collapse or escape a newline in a value, closing (d).

## 5. Still open

All of the above. **Item B5** is the first item that will drive `::rdw::sim` and
therefore the first that can reach a second backend at all; **whoever adds the
second backend** is the one who makes every shape here live.
