# OVB-01 item 02 — double-clicking a difference marker selects the PAIR

**Scout stage, 2026-08-01. Verdict: PROCEED.**
Every anchor below was re-located from source today, at HEAD `be5d9b98`
(*feat(0188): m/d mark anywhere in the plot box…*), i.e. **after** batch item 01
landed. Line numbers drift — grep the symbol, don't trust the number.

User spec, verbatim:

> If a marker is a "difference marker" - created by pressing "d" key so that
> delta and slope are displayed, then, double-clicking the marker will select
> both this marker and the one that its deltas are derived from.

---

## 1. Verdict and why it is not a DEFER

`doc/claude/specs/graph_markers.md` §11 lists **multi-marker selection** as
explicitly deferred, and says exactly what the cost is:

> `graph_marker_sel` holds one number. Cadence allows rubber-band selection of
> several. Making it a list turns `Delete` into a loop — **contained**, but it
> changes verb result shapes, so it should be decided before those are relied on.

That is the whole scope statement, written by the people who shipped the marker
model, and it says *contained*. Source agrees:

* the selection is **not** in any file token and never has been (§4, D-1 below),
  so there is no storage model to reshape and no file-format question;
* there are exactly **four** places in the tree that ask "is *this* marker
  selected" (§2.3) — not eleven;
* the viewer's `Delete` already routes through `wviewer::delete_items`, which
  **already** takes a LIST of marker numbers, dedupes it, filters it to live
  records, and produces one undo point and one log line
  (`src/wave_viewer.tcl:4708`, `:4767-4787`). The viewer half of "Delete removes
  both" is a one-line change.

No DEFER trigger fires. The item is additive: two `xctx` fields, one predicate,
two new primitives, two verb forms, one getter, one Tk binding.

---

## 2. What exists today (verified)

### 2.1 The selection is ONE NUMBER, held in `xctx`, never in a token

| anchor | what it is |
|---|---|
| `src/xschem.h:1690` | `int graph_marker_sel;` — selected marker **number**, `-1` = none |
| `src/xschem.h:1691` | `int graph_marker_selgraph;` — the rect index that owned it *at selection time*; documented as a **hint** |
| `src/draw.c:6611` | `int graph_marker_select(int num, int graph_idx)` — the only writer. "Pure UI state: no token write, no undo, no modify." |
| `src/scheduler.c:3951-3955` | `xschem get graph_marker_sel` → the number |
| `src/scheduler.c:5185-5190` | `xschem graph_marker select <num> [<gi>] \| -none` → returns the new head |
| `src/scheduler.c:5142` | the readonly exemption: `select`, `list`, `text` are NOT `scheduler_readonly_reject`ed |
| `src/actions.c:1915-1916` | `clear_drawing()` resets `sel`/`selgraph` — the selection **dies with the document** |
| `src/xinit.c:668-669` | `alloc_xschem_data()` seeds the `-1` sentinels |
| `src/wave_viewer.tcl:2830` | `wviewer::marker_selected {wp}` — the Tcl mirror, fail-closed to `-1` |

`graph_markers.md` §3.5 states the rule in one line: **selection is UI state, not
content** — "saving it would mean a reloaded schematic opens with a marker
mysteriously highlighted". There is no `hilight_wave`-shaped head token to extend
here, unlike the trace case. See §5.1.

### 2.2 The delta link

`GraphMarker.prev` is a **marker NUMBER**, `0` = none
(`graph_markers.md` §3 grammar; `src/xschem.h:1202`ff). It is written by the `d`
key / `-delta` verb flag and points **backwards**, from the difference marker to
its reference. `graph_marker_find(num, &gi, &out)` (`src/draw.c:5607`) resolves a
number to its owning rect + record, window-wide. Dangling `prev` links are swept
window-wide on every delete (`graph_marker_clear_prev_n`, `src/draw.c:6447`).

### 2.3 Every place that reads the selection today

| anchor | question it asks | must become |
|---|---|---|
| `src/draw.c:6017` | *is this marker selected* (renderer: ring + stroke weight) | `graph_marker_is_selected(m.num)` |
| `src/draw.c:6495` | *was the marker I just deleted selected* | drop it from the SET |
| `src/callback.c:635` | *is this marker selected* (the RIGID text-drag latch) | `graph_marker_is_selected(num)` |
| `src/callback.c:791` | *is this marker selected* (the click select/deselect toggle) | helper + the collapse rule (D-6) |
| `src/callback.c:613` | *is ANYTHING selected* (press on empty space deselects) | `graph_marker_n_sel > 0` |
| `src/callback.c:769-770` | `oldsel`/`oldgraph` repaint-scope hint | unchanged (head) |
| `src/callback.c:6948`, `:6955` | the `Delete` **strip-scope gate**, re-resolved with `graph_marker_find` | unchanged (head) — D-7 |
| `src/scheduler.c:3954` | the getter | unchanged (head) |
| `src/wave_viewer.tcl:2833` | the Tcl mirror | unchanged (head) |

**Four** "is this marker selected" sites, not eleven (§5.2).

### 2.4 The double-click seams

| context | anchor | today |
|---|---|---|
| any editor toplevel | `src/xschem.tcl:13939` | `bind $topwin <Double-Button-1> "xschem callback %W -3 %x %y 0 %b 0 %s"` |
| routing | `src/callback.c:153-162` | `waves_selected()` explicitly claims `event == -3` inside the rect (inset by `border`) |
| C, on-canvas graph | `src/callback.c:1385-1393` | the `-3` arm: poison `graph_press_x/y` with `-1e30`, then `edit_wave_attributes(1,i,gr)` (legend → the wave dialog), else `graph_edit_properties` (`src/xschem.tcl:4249`, a NON-modal `toplevel .graphdialog`; its `tkwait` is commented out) |
| ASE viewer | `src/wave_viewer.tcl:6495` | `bind $wp <Double-Button-1> {break}` — *"D9: no graph props dlg"*. `<Double-Button-1>` is MORE SPECIFIC than the kept generic `<Button>` and than `strip_drag_press`'s `<ButtonPress-1>`, so the **second press never reaches C at all**; the second *release* still does. |

`graph_marker_at(i, px, py, tol, &part)` (`src/draw.c:6064`) is the hit test:
canvas pixels, `GRAPH_MARKER_TOL` = 8.0 screen px (`src/xschem.h:449`), returns
the number + part 1 (anchor) / 2 (label), brackets the landmine-37 hcursor bits,
and answers `0` under `--nogui` (no cairo ⇒ no measurable label box). Exposed as
`xschem get graph_marker_at` (`src/scheduler.c:3927`), which fails soft.

### 2.5 The pair-of-tolerances interlock, as it really is

`GRAPH_CLICK_TOL` is **file-private to `callback.c`** and is 3.0 (`src/xschem.h:439`
says so explicitly). It is a **click-vs-drag travel** test in WORLD units, used by
the wave-bold arm (`src/callback.c:930-932`) and by `graph_marker_drag_to`
(`:674`). It has **nothing to do with double-click detection**: that happens
entirely inside Tk's binding table (`NEARBY_MS` 500 / `NEARBY_PIXELS` 5), and the
product only ever sees the resulting `-3`.

What the interlock *does* contribute here is the **`-1e30` poison**, written in
two places, and it is what stops a double-click from also bolding a trace:

* `src/callback.c:1224-1226` — a press that ARMED a marker gesture nukes
  `graph_press_x/y`;
* `src/callback.c:1389` — the `-3` arm nukes them again.

Because a marker press always poisons, the trailing release of a double-click on
a marker cannot satisfy the wave-bold travel test. **This already holds today and
must be preserved, not rebuilt** (regression leg MS-X1c).

---

## 3. The design

### 3.1 Storage — a fixed array beside the existing head, still never in a token

```c
/* src/xschem.h, beside GRAPH_MARKER_TOL */
#define GRAPH_MARKER_MAX_SEL 8

/* src/xschem.h, beside graph_marker_sel */
int graph_marker_sel_set[GRAPH_MARKER_MAX_SEL]; /* the WHOLE selection, marker
                                                 * NUMBERS, head first */
int graph_marker_n_sel;                         /* 0 = nothing selected */
```

Invariants, enforced in **one** writer:

* `n_sel == 0` ⟺ `graph_marker_sel == -1`;
* `n_sel >= 1` ⟹ `graph_marker_sel == graph_marker_sel_set[0]`;
* no duplicates, no entries `<= 0`, capped at `GRAPH_MARKER_MAX_SEL`;
* **order is SELECTION order, head first** — not ascending. The head is the
  marker the user acted on: it drives `selgraph`, the `Delete` scope gate and the
  unchanged `xschem get graph_marker_sel`.

A fixed array, never a pointer: it is reset (not freed) at the two existing reset
sites, and a pointer would add a free path to `clear_drawing()` for nothing. (The
0175 reasoning — six `Graph_ctx` locals that die on return — does **not** apply
here; `xctx` is a single long-lived struct. Fixed is still right, for the simpler
reason.)

### 3.2 The one trio + the policy, all in `draw.c` beside `graph_marker_select`

```c
int graph_marker_is_selected(int num);                     /* THE predicate */
int graph_marker_select_set(const int *nums, int n, int graph_idx);
int graph_marker_select(int num, int graph_idx);           /* == select_set(&num,1,gi) */
int graph_marker_select_pair(int num, int graph_idx);      /* the double-click policy */
static void graph_marker_sel_drop(int num);                /* used by delete */
```

`graph_marker_select_pair(num, gi)`:

1. `graph_marker_find(num, &owner, &m)` — if it fails, `select_set(&num, 1, gi)`
   and return (permissive, byte-identical to `select <num>` today);
2. `nums[0] = num`;
3. if `m.prev >= 1` **and** `graph_marker_find(m.prev, NULL, NULL)` succeeds,
   `nums[1] = m.prev`, `n = 2`;
4. `graph_marker_select_set(nums, n, owner)`.

It **SETS**; it never toggles and never accumulates.

### 3.3 Delete — one gesture, one undo point

`graph_marker_delete()` (`src/draw.c:6479`) splits into a static
`graph_marker_delete_1(int num, int push)`; the public form is
`graph_marker_delete_1(num, 1)`. `graph_marker_delete_selected()`
(`src/draw.c:6546`) becomes:

* `graph_marker_ro_refuse()` once (so a read-only buffer gets **one** CIW line);
* copy the set into a local (the set mutates as records go);
* `if(!xctx->readonly) xctx->push_undo();` **once**;
* `graph_marker_delete_1(nums[k], 0)` per member;
* return the count.

Each member still self-logs its own `xschem graph_marker delete <n>` line, so a
replay reproduces the deletions exactly. **One `xschem undo` restores every
deleted record, across however many rects** — that is the leg that dies if
someone pushes per delete.

New verb form `xschem graph_marker delete -selected` → the count. It exists so the
multi-delete, its undo-point count and its `prev` sweep are assertable in **both**
test arms; the C `Delete` key path is DISPLAY-only.

### 3.4 The gesture, in two contexts

**On-canvas schematic graph** — inside the existing `-3` arm
(`src/callback.c:1385`), after the poison and *before* `edit_wave_attributes`:

```c
mnum = graph_marker_at(i, (double)mx, (double)my, GRAPH_MARKER_TOL, &mpart);
if(mnum > 0 && mpart) {
  graph_marker_select_pair(mnum, i);
  need_all_redraw = 1;              /* the partner may live on another strip */
} else if(!edit_wave_attributes(1, i, gr)) {
  tclvareval("graph_edit_properties ", my_itoa(i), NULL);
}
```

Marker first: a marker **anchor sits on a trace by construction**, and a callout
is clamped inside the plot box (§4.1 of the marker spec), so without this the
double-click reaches `graph_edit_properties`.

**ASE viewer** — `src/wave_viewer.tcl:6495` stops being a bare `{break}`:

```tcl
bind $wp <Double-Button-1> {wviewer::marker_dblclick_at %W %x %y; break}
```

`wviewer::marker_dblclick_at` (new, beside `marker_selected`):
resolve the token from `%W`; `strip_at_pixel` → `gi`; `xschem get graph_marker_at
$gi $px $py`; on a hit `xschem graph_marker select -pair <num> <gi>` +
`xschem redraw`, return 1; otherwise return 0. **It always `break`s**, so D9 —
no graph-props dialog in the viewer — is preserved unconditionally.

No `with_edit` bracket: `select` writes no token, pushes no undo, sets no modify
flag, and is one of the three sub-verbs `scheduler.c:5142` exempts from
`scheduler_readonly_reject()`. This is assertable (the buffer stays unmodified
and read-only across the gesture).

### 3.5 The viewer's `Delete`

`src/wave_viewer.tcl:4886-4891` — keep the scope test on the **head** and hand the
whole set to `delete_items`:

```tcl
  set marks {}
  set msel [wviewer::marker_selected $W]
  if {$msel >= 0} {
    set mg [wviewer::marker_graph_at $W $msel]
    if {$mg >= 0 && $mg == [wviewer::strip_at_pixel $W $px $py]} {
      set marks [wviewer::marker_selection $W]   ;# the WHOLE set, head first
    }
  }
```

`delete_items` already dedupes, filters to live numbers, pushes **one** undo point
and emits **one** log line naming explicit numbers (`:4767-4787`, `:4794-4795`).

### 3.6 Surface summary

| addition | where | note |
|---|---|---|
| `GRAPH_MARKER_MAX_SEL 8`, 2 `xctx` fields | `src/xschem.h` | **not** `MIRRORED IN TCL` — Tcl reads the list from the getter, never the cap |
| `graph_marker_is_selected` / `_select_set` / `_select_pair` + externs | `src/draw.c`, `src/xschem.h` | |
| `xschem get graph_marker_sel_set` → `"2 1"` \| `""` | `src/scheduler.c` `get` case **'g'** | same letter bucket as `graph_marker_sel`; fails soft |
| `graph_marker select -pair <num> [<gi>]`, `select -set <n1> …` | `src/scheduler.c` `graph_marker` block | ride the existing `select` readonly exemption |
| `graph_marker delete -selected` | same | readonly-rejected, like every other `delete` form |
| `wviewer::marker_selection`, `wviewer::marker_dblclick_at` | `src/wave_viewer.tcl` | fail-closed, context-switching, like `marker_selected` |
| reset `n_sel` | `src/actions.c:1915`, `src/xinit.c:668` | the gesture-state reset class (§3.5 of the spec) |

**No new rendering. No new token. No `XSCHEM_FILE_VERSION` bump. No config var.**

---

## 4. Every spec hole, resolved

| # | question | decision | why | rejected |
|---|---|---|---|---|
| **D-1** | How is a selection SET represented? | Two new `xctx` fields — a fixed array + a count — with `graph_marker_sel` kept as the **head**. **No prop token, at any size.** | `graph_markers.md` §3.5 / D9: marker selection is UI state and has never been in the token; `clear_drawing()` resets it precisely so it dies with the document. Putting it in the token would make a reloaded schematic open with markers mysteriously ringed — the exact thing §3.5 forbids. | PLAN Q1's "optional companion token emitted only at size ≥ 2" (the 0175 trace model). That model exists because trace bold *is* per-rect render state carried in `hilight_wave`; markers have no such head token to extend. See §5.1. |
| **D-2** | Who may read/write the pair of fields? | **One trio in `draw.c`** — `graph_marker_is_selected`, `graph_marker_select_set`, `graph_marker_select` (a one-line wrapper) — plus `graph_marker_select_pair` and a static `graph_marker_sel_drop`. Nothing else touches `graph_marker_sel` / `n_sel` except the three unchanged **head** readers (the getter, the `Delete` scope gate, the repaint hint). | This is what stopped the two 0175 tokens drifting, and it is what makes the source-level leg (MS13) meaningful. | scattering `n_sel` tests through `callback.c`. |
| **D-3** | Every draw-side "is this selected" comparison? | Through `graph_marker_is_selected()`, never a bare `== xctx->graph_marker_sel`. **Four** sites (§2.3), asserted at SOURCE level the way `test_wave_legend.tcl:264-282` (`LS5`) does. | A missed site renders a selected marker in the unselected style, and no leg that selects one marker can see it. | trusting a behavioural leg to catch it. |
| **D-4** | Double-click a NON-difference marker? | Selects just it. Same as a single click, no error, no message. | The user's sentence is about the delta case only. | refusing, or beeping. |
| **D-5** | The reference is deleted / unresolvable? | Select only the difference marker, silently. `graph_marker_find(prev)` failing is the whole test. | `graph_marker_clear_prev_n` already zeroes dangling `prev` on every delete, so this only arises from a hand-edited or foreign token — where silence is right and a dialog would be absurd. | a CIW warning. |
| **D-6** | Chained deltas (a `d` whose reference is itself a `d`)? | The **immediate pair only** — never transitive. | "the one that its deltas are derived from", singular; and the callout only ever renders one Δ block. | walking the `prev` chain. |
| **D-7** | Direction of the relation? | Followed **one way only**: from the difference marker to its reference. Double-clicking the *reference* selects just the reference. | `prev` is a back-pointer and N deltas may share one reference; "select all my dependants" is a different, unasked-for feature. | a reverse scan of the window. |
| **D-8** | Does `Delete` now remove both? | **Yes**, both paths. C: `graph_marker_delete_selected()` deletes the whole set under **one** undo point. Viewer: `delete_selection_at` hands the whole set to `delete_items`, which already gives one undo point and one log line. | Issue 0176: "Delete deletes whatever is selected", one undo point and one log line **per gesture** (D5 there). | deleting only the head; or n undo points (a two-`u` restore for a one-key gesture). |
| **D-9** | `Delete`'s strip-scope gate with a cross-strip pair? | Gate on the **HEAD** (`graph_marker_find(sel) == graph_master`); when the head is in scope, the **whole** set goes, partners on other strips included. | The head is the marker the user just acted on, and the shipped gate exists so a Delete pressed over *another* strip cannot eat a selection (spec §3.5). Both C and the Tcl mirror already resolve the head this way. | any-member-in-scope (looser than the shipped rule); per-member filtering (would delete half a pair and leave a dangling `prev` — strictly worse). |
| **D-10** | Reference on a DIFFERENT strip? | Still selected, still rendered selected. The renderer already matches by **number alone** (`src/draw.c:6012-6017` says why), so this works by construction; the gesture just has to ask for an all-graphs repaint. | `selgraph` is documented as a stale-able hint and must not become load-bearing. | scoping the set to one rect. |
| **D-11** | What is the double-click threshold / seam? | **Tk's** — `<Double-Button-1>` in the viewer, and the `-3` event `xschem.tcl:13939` already synthesises for every editor toplevel. **No new constant**, and `GRAPH_CLICK_TOL` is *not* reused (it answers a different question — §2.5). | The seam exists and is spec'd on both sides; inventing a timer would be a second, divergent double-click rule. | a bespoke travel/time test in C. |
| **D-12** | The viewer's `<Double-Button-1> {break}` (D9, no props dialog)? | **Preserved unconditionally.** The new binding always `break`s; it only *additionally* pair-selects when a marker is under the pointer. | D9 is a shipped viewer contract: the graph-properties dialog must never appear in a read-only viewer. | dropping the `break`; or forwarding `-3` to C from the viewer — where a Tcl/C hit-test disagreement would silently open `.graphdialog` over the viewer, exactly the fall-through class issue 0176 removed for `Delete`. |
| **D-13** | Anchor or callout — which parts accept the double-click? | **Both** (`graph_marker_at` part 1 or 2). | "double-clicking the marker" — the callout is the marker's readout and is its other grab handle everywhere else (§6.2). | anchor-only. |
| **D-14** | Does the FIRST click still single-select? | Yes, unchanged. The double-click then **widens** it. The `-3` SETS the pair absolutely — so double-clicking an already-selected delta marker (whose first click *deselected* it, per §6.2) still ends with the pair selected. | The press/release select path is untouched; only the `-3` arm is new. Asserted explicitly (MS-X1a). | making the second click a toggle. |
| **D-15** | A plain click on a member of a MULTI selection? | **Collapses** to that one marker. The shipped "second click on the already-selected one deselects" rule is kept for the **single**-selection case, byte for byte. | Two precedents collide: markers deselect on re-click (§6.2), traces collapse and never deselect (0174 D3). Keeping the shipped marker rule for `n_sel == 1` keeps every existing MX leg green; collapsing for `n_sel >= 2` is the only reading in which the click disambiguates rather than destroys, and a second click then still deselects. | deselecting one member out of a pair (leaves a half-selection whose `Delete` would break a delta link). |
| **D-16** | Return value of `xschem graph_marker select …`? | **Always the head**, for every form including `-pair`/`-set` — byte-identical to today for the existing forms (`-none` still answers `-1`). The set is read with `xschem get graph_marker_sel_set`. | §11 of the marker spec flags "it changes verb result shapes" as the thing to decide first. Deciding it as *no change* keeps ~27 shipped assertions and `wviewer::marker_selected` untouched. | returning the list (would make `-none` answer `{}` instead of `-1` and break existing legs). |
| **D-17** | Does the selection LOG for replay? | **No.** Neither the existing `graph_marker_select` nor trace selection logs, and this does not start. The replay-critical operations already name explicit numbers (`graph_marker delete <n>`, `wviewer::delete_items … {3 4}`). | `waveform_viewer_modes.md` §15 opening line: the trace selection "is view state: no dirty flag, no undo point, **no log line** (landmine 19)". Logging marker selection but not trace selection is an inconsistency the next reader files as a bug. **This diverges from PLAN Q10** — see §5.4. | logging `xschem graph_marker select -set <n1> <n2>`. That spelling is deliberately what the new verb takes, so adding a log line later is one line — but it is not added now. |
| **D-18** | Does `select -set` validate that the numbers exist? | No. Permissive, exactly like `select <num>` today (a nonexistent number simply renders no ring). `-pair` *does* check the partner, because resolving `prev` is its job. | Consistency with the shipped verb; a validating setter would also have to decide what to do with a partially valid list. | rejecting unknown numbers. |
| **D-19** | Does the `-3` arm decline the reorder-grip column, as `graph_marker_press` does (`src/callback.c:605`)? | No. | The grip owns no double-click gesture, and a callout is clamped inside the plot box (§4.1), so an overlap only exists on a very narrow strip — where selecting the marker under the pointer is the right answer anyway. Fewer moving parts. | mirroring the press-side decline. |
| **D-20** | Ctrl / Shift / Alt + double-click? | Out of scope, unchanged. The `-3` arm does not look at `state` today and still will not. | Not asked for; the viewer already swallows Shift/Alt+B1 entirely (`:6503-6506`). | inventing an additive-double-click. |
| **D-21** | `GRAPH_MARKER_MAX_SEL` value and mirroring? | **8**, C-only. | The double-click builds 1 or 2; 8 is headroom for a future Ctrl+click without another header edit. Tcl reads the list from the getter and never needs the cap, so there is nothing to mirror. | 2 (no headroom); 64 (`GRAPH_MAX_SEL_WAVES`, pointless here). |
| **D-22** | Where does the new test group live? | A new **`MS*` group in `tests/headless/test_wave_markers.tcl`, MK-style: no raw, no DISPLAY, both arms**, inserted after `MK12` (`:855-882`) and before the `MR*` fixture (`:883`). Records are written straight into the `markers` token with `setprop`, exactly as `MK7` does. | Selection, the `prev` walk and the delete never touch the raw, so a fixture would be dead weight — and a both-arms group is where the teeth are (landmine 41: anything observing the viewer model is DISPLAY-only). | extending `MR*` (needs a raw for no reason). |

---

## 5. PLAN.md claims that source refutes

### 5.1 Q1: "add an optional companion **token**, emitted only at size ≥ 2"

**Refuted.** Marker selection has never been in the token and must not be.
`graph_markers.md` §3.5 ("What is *not* in the token") and D9 are explicit, and
`clear_drawing()` (`src/actions.c:1915`) resets it because it is meant to die with
the document. The 0175 model that PLAN points at works because `hilight_wave` is a
real per-rect **render-state** token that `sel_waves` extends; the marker analogue
of `hilight_wave` is `xctx->graph_marker_sel`, a session field.

What survives from the recommendation is its *shape*, and it is kept exactly:
a **head** + a **set**, with **one trio** as the only readers/writers, and a
predicate every draw-side comparison must go through.

Two consequences for the test plan, both **strengthening** it:

* the seed leg "the serialised prop of a never-double-clicked strip is
  byte-identical" becomes the stronger **"no graph's `prop_ptr` changes at all,
  under any selection, including a two-marker one"** (MS8);
* the seed sabotage "emit the companion token at size 1" is replaced by
  **"write a `sel_markers=` token from `graph_marker_select_set`"**, which must
  kill MS8 and nothing else.

### 5.2 Q3: "There were **eleven** such bare sites in the trace case"

True of 0175/traces (`test_wave_legend.tcl:281-282` asserts `>= 11`
`wave_is_hilighted` calls). In the **marker** code there are **four**
"is this marker selected" comparisons — `src/draw.c:6017`, `src/draw.c:6495`,
`src/callback.c:635`, `src/callback.c:791` — plus one "is anything selected"
(`src/callback.c:613`), one repaint hint (`:769-770`) and one scope read (`:6955`).
The implementer should look for four, not eleven, and the source leg must assert
the exact set rather than a `>= N` count.

### 5.3 Q9: "reuse the existing interlock's travel/time rules"

Sharpened, not refuted. There is **no travel/time rule to reuse**: double-click
detection is Tk's (`NEARBY_MS` / `NEARBY_PIXELS`), and `GRAPH_CLICK_TOL` is a
click-vs-drag travel test on a *single* click (`src/xschem.h:439` documents the
distinction). What the interlock contributes is the `-1e30` poison
(`src/callback.c:1224-1226` and `:1389`), which **already** prevents the trailing
release from bolding under a marker double-click, because the first press of the
double armed a marker gesture. Preserve it; do not rebuild it. Regression leg.

Also worth stating: PLAN says "if Tk's `<Double-Button-1>` is the natural seam in
the viewer, use it". It is the seam — but it is currently a **shipped, spec'd
refusal** (`{break}`, D9). The item necessarily edits that refusal, and D9 has to
survive for every non-marker double-click (D-12).

### 5.4 Q10: "it logs for replay"

Contradicted by `waveform_viewer_modes.md` §15 (trace selection: "no log line")
and by `graph_marker_select()` carrying no `log_action` (`src/draw.c:6611-6622`).
Decision D-17 takes source over the recommendation and records the one-line path
back.

### 5.5 Verified as stated in PLAN (no action)

* `GRAPH_CLICK_TOL` = 3.0, `callback.c`-private ✔ (`src/xschem.h:439`)
* the `-3` arm poisons `graph_press_x/y` with `-1e30` ✔ (`src/callback.c:1389`)
* selection is by NUMBER; `selgraph` is a stale-able hint; the `Delete` gate
  re-resolves with `graph_marker_find()` ✔ (`src/callback.c:6950-6956`)
* multi-marker selection is listed as deferred ✔ (`graph_markers.md` §11)

---

## 6. Collision map for the new gesture

| gesture / owner | today | after | verdict |
|---|---|---|---|
| viewer `<Double-Button-1>` | `{break}` (D9) | pair-select **iff** a marker is under the pointer; **always `break`** | changed, deliberately; D9 intact |
| viewer `<Double-Button-2>` / `-3` | `{break}` | unchanged | no touch |
| viewer `<ButtonPress-1>` → `strip_drag_press` | more general than `<Double-Button-1>`; does **not** fire for the second press | unchanged | the second press never re-targets a strip or reaches C — same as today |
| viewer `<ButtonRelease-1>` → `strip_drag_release` | fires for the trailing release, forwards raw (nothing armed) | unchanged | the wave-bold cannot fire because the first press poisoned the anchor (§2.5) — **regression leg MS-X1c** |
| on-canvas `-3` → wave dialog / graph props | `edit_wave_attributes(1,…)` else `graph_edit_properties` | reached only when no marker is under the pointer | changed for marker pixels only — **leg MS-X5 spies `graph_edit_properties`** |
| legend double-click (embedded graphs) → wave dialog | `edit_wave_attributes(1,…)` | unchanged: the legend is outside the plot box and a callout is clamped inside it, so no marker part is normally there. `GRAPH_MARKER_TOL` (8 px) can reach a few px above the box top; a double-click that close to an anchor is aimed at the marker | acceptable, stated |
| strip reorder grip (right `GRAPH_REORDER_HANDLE_W` px) | `graph_marker_press` declines it on a PRESS (`src/callback.c:605`) | the `-3` arm does not decline it (D-19) | no double-click gesture belongs to the grip |
| `Delete` over a graph (C) | deletes the selected marker if its strip is under the pointer | deletes the whole set, one undo point, head-scoped | changed per D-8/D-9 |
| `Delete` in the viewer | `delete_selection_at` → `delete_items` with one marker | same, with the whole set | one-line change |
| `m` / `d` / `M` / `t` / cursors / box zoom / pan / trace drag / strip reorder | — | **untouched** | none of them see `-3` |

---

## 7. The invariants the suite asserts

* **INV-1** `n_sel == 0` ⟺ `xschem get graph_marker_sel` == `-1` ⟺
  `xschem get graph_marker_sel_set` == `{}`.
* **INV-2** `n_sel >= 1` ⟹ `lindex [get graph_marker_sel_set] 0` ==
  `get graph_marker_sel` (head first, selection order — **not** ascending: a
  double-click on M2 with `prev` M1 answers `2 1`).
* **INV-3** `select -pair N` ⟹ the set is `{N}` when `find(N)` fails, or
  `N.prev == 0`, or `find(N.prev)` fails; otherwise exactly `{N, N.prev}`.
* **INV-4** never transitive: with `M3.prev = 2`, `M2.prev = 1`,
  `select -pair 3` answers `3 2` and `1` is not in it.
* **INV-5** **no token is written, ever.** `xschem getprop rect 2 <gi> markers`
  and the whole `prop_ptr` of every graph rect are byte-identical before and
  after any selection change, on a 1-marker and a 2-marker selection alike; and
  `xschem get modified` does not change.
* **INV-6** `graph_marker delete -selected` removes exactly the set, leaves
  `n_sel == 0`, and is **one undo point**: a single `xschem undo` restores every
  deleted record across every affected rect.
* **INV-7** source-level: `draw_graph_markers()` contains **no**
  `graph_marker_sel` and **does** contain `graph_marker_is_selected(`; likewise
  the rigid-drag latch in `graph_marker_press()` and the click toggle in
  `graph_marker_release()`. (Counted on CODE lines only — `test_wave_snap.tcl`
  has `count_code` for exactly this reason.)
* **INV-8** backward compatibility: `xschem graph_marker select <n>` returns `n`,
  `select -none` returns `-1`, `xschem get graph_marker_sel` still returns the
  head — byte-for-byte as today.
* **INV-9** the first click still single-selects, and the double-click then
  widens (D-14); it SETS, so a repeat double-click leaves the pair selected.
* **INV-10** the viewer buffer is still `modified == 0` and `readonly == 1` after
  a double-click (no `with_edit` needed, §3.4), and no viewer log line is emitted.

---

## 8. Test plan

Suite: **`tests/headless/test_wave_markers.tcl`** (already globbed by
`tests/headless/full_audit.sh` — no registration needed). Its `MZ1` self-check
hard-codes the expected check count per arm at `:5270-5271`
(`mk_expect_x 868`, `mk_expect_nogui 371`); **both must be updated or MZ1 fails.**

### 8.1 `MS*` — both arms, no raw, no DISPLAY (insert after `MK12`, `:882`)

Fixture: `mk_reset`; two graph rects via `mk_graph`; `xschem setprop rect 2 <gi>
markers` with hand-written records (`mk_rec`), exactly as `MK7` does.

| leg | asserts |
|---|---|
| `MS0` | staging: two graph rects, `graph_marker list` sees the hand-written records with the intended `prev` links |
| `MS1` | `select -pair 2` (M2.prev = 1) → `get graph_marker_sel` == 2, `get graph_marker_sel_set` == `2 1` (INV-2, INV-3) |
| `MS2` | `select -pair 1` (a plain marker) → set == `1` (D-4) |
| `MS3` | `select 2` → set == `2`; `select -none` → sel == `-1`, set == `{}`, and the **return values** are `2` and `-1` (INV-1, INV-8) |
| `MS4` | orphan: `graph_marker delete 1` (which sweeps M2's `prev` to 0) then `select -pair 2` → set == `2` (D-5) |
| `MS4b` | hand-written **dangling** `prev` (names a number no record carries) → `select -pair` → set == `2`, no error, no message (D-5) |
| `MS5` | chain M1←M2←M3: `select -pair 3` → set == `3 2`, and `1 ∉ set` (INV-4, D-6) |
| `MS6` | direction: `select -pair 1` with M2.prev = 1 → set == `1` (D-7) |
| `MS7` | cross-strip: M1 on rect 0, M2(prev 1) on rect 1 → `select -pair 2` → set == `2 1`; `graph_marker list 0` / `list 1` prove they are on different rects; `selgraph` is the head's rect (D-10) |
| `MS8` | **INV-5** — capture `getprop rect 2 0 markers`, `getprop rect 2 1 markers` and both rects' whole prop strings before/after `select -pair`; byte-identical; `xschem get modified` unchanged |
| `MS9` | `delete -selected` on the cross-strip pair → returns 2, both records gone from **both** rects, `sel` == -1, set == `{}` |
| `MS10` | **INV-6** — a single `xschem undo` after `MS9` restores **both** records (this is the leg that dies if undo is pushed per delete) |
| `MS11` | `select -set 2 2 1` → set == `2 1` (dedupe, order preserved); `select -set` with a nonexistent number is accepted (D-18) |
| `MS12` | `delete -selected` with nothing selected → 0, nothing deleted, no undo point consumed |
| `MS13` | **INV-7**, the `LS5` idiom (`test_wave_legend.tcl:264-282`): read `src/draw.c` and `src/callback.c`, count on CODE lines only, and assert the exact sanctioned set of `graph_marker_sel` readers |
| `MS14` | `select -pair` on a read-only buffer still works (`xschem set readonly 1`; select is not a mutation), while `delete -selected` is readonly-**rejected** at the scheduler (a `catch` that must be non-zero) |

### 8.2 Display legs

**Viewer** (inside the existing `MR-viewer`/`MX*` block, after `MX5`, `:4523`;
use `mk_wadd`/`mk_wdel`/`mk_parts`/`mk_list`/`mk_bold`/`mx_ready` and the
timestamped `wb_ev`, `:3849`):

* `MS-X1` — place M1, then M2 with `-delta`, both on strip 0. Replay the FULL
  double-click: `press(t)`, `release(t+~50)`, **second press within Tk's 500 ms /
  5 px window so `<Double-Button-1>` matches**, `release`. Note `wb_ev` bumps
  `-time` by 1000 ms per event, so this leg needs its own helper that stamps the
  second press close to the first.
  * `MS-X1a` after the FIRST release: `sel` == 2, set == `2` (the ordinary
    single-select still happens — INV-9);
  * `MS-X1b` after the double: set == `2 1`, `sel` == 2;
  * `MS-X1c` `mk_bold` is unchanged (the trailing release did not wave-bold);
  * `MS-X1d` `winfo exists .graphdialog` == 0 (D9 intact);
  * `MS-X1e` the viewer buffer is still `modified 0` / `readonly 1`, and
    `llength $::mxlog` did not grow (INV-10);
  * `MS-X1f` a **second** double-click leaves the set at `2 1` (it SETS, D-14).
* `MS-X2` — double-click on empty plot body: set == `{}`, no `.graphdialog`.
* `MS-X3` — double-click a plain marker: set == that one number.
* `MS-X4` — with the pair selected and the pointer over the head's strip, a real
  `Delete` keystroke removes **both**; `wviewer::history_depth` rose by exactly 1
  and one `u` brings both back (the 0176 end-to-end user story).

**On-canvas graph** (inside the `MF*` display half, after `MP21`/`MP22`):

* `MS-X5` — spy the dialog: `rename graph_edit_properties __ms_saved;
  proc graph_edit_properties {i} {set ::ms_dlg 1}` (restore in the same block).
  Place a marker on the embedded graph, scan its anchor pixel with
  `xschem get graph_marker_at`, drive `xschem callback .drw -3 <px> <py> 0 1 0 0`
  → the pair is selected **and** `::ms_dlg` was never set. Control: the same `-3`
  at an empty plot-box pixel sets `::ms_dlg` exactly once and selects nothing.
  (`graph_edit_properties` is non-modal — its `tkwait` is commented out — so the
  control is safe either way; the spy makes it deterministic and leaves no
  toplevel behind.)

### 8.3 Named sabotages — each must kill EXACTLY its list

| # | sabotage | must kill | must stay green |
|---|---|---|---|
| **SAB-1** | `graph_marker_select_pair` ignores `prev` (selects only the clicked number) | `MS1`, `MS5`, `MS7`, `MS9`/`MS10` pair halves, `MS-X1b`, `MS-X4` | `MS2`, `MS3`, `MS4`, `MS6`, `MS8`, `MS11`-`MS14`, `MS-X2`, `MS-X3` |
| **SAB-2** | restore ONE bare comparison in `draw_graph_markers` (`m.num == xctx->graph_marker_sel`) | `MS13` **only** | everything else |
| **SAB-3** | `graph_marker_delete_selected` deletes only the head | `MS9`, `MS-X4` | `MS10` must still be *attemptable*; `MS1`-`MS8`, `MS11`-`MS14` |
| **SAB-4** | `graph_marker_select_set` writes a `sel_markers=` token onto the rect | `MS8` **only** | everything else — this is the leg that carries decision D-1 |
| **SAB-5** | push undo per delete instead of once in `graph_marker_delete_selected` | `MS10` **only** | `MS9` and everything else |

If a sabotage kills more or fewer legs than its list, **the leg is wrong, not the
sabotage**.

---

## 9. What no assertion can reach (→ `[E]`)

1. **Two markers rendering selected at once** — the hollow ring and the doubled
   stroke on *both* members. No verb reads pixels. The suite asserts the set and
   asserts at source level that the renderer consults the predicate (INV-7), which
   is the strongest available proxy and is exactly what `LS5` does for traces.
2. **The cross-strip repaint** — that both rings appear together and no stale ring
   is left on the partner's strip. `need_all_redraw` / `xschem redraw` is not
   observable; the reference doc already records "the repaint scope of a
   cross-strip selection change" as eyeball-only.
3. **The double-click feel** — Tk's 500 ms / 5 px window is Tk's, and whether a
   real hand lands two clicks inside it is not assertable.
4. **That the pair cue reads as "these two go together"** — a design judgement
   (no distinct head cue, per §15.4's "there is no separate cue for the head of
   the set"). Only an eyeball can reject it.

---

## 10. Files this item touches

```
src/xschem.h            2 fields, 1 define, 3 externs
src/draw.c              the trio + pair + sel_drop + the delete split + the renderer predicate
src/callback.c          the -3 arm, the rigid latch, the click toggle, the empty-space deselect
src/scheduler.c         get graph_marker_sel_set; select -pair / -set; delete -selected
src/actions.c           clear_drawing(): reset n_sel
src/xinit.c             alloc_xschem_data(): reset n_sel
src/wave_viewer.tcl     marker_selection, marker_dblclick_at, the <Double-Button-1> bind,
                        one line in delete_selection_at
tests/headless/test_wave_markers.tcl    the MS group + display legs + the MZ constants
doc/claude/specs/graph_markers.md
doc/claude/specs/waveform_viewer_modes.md      §15.1 (the double-click row)
doc/claude/code_analysis/waveform_subsystem_reference.md   §5, §9, new landmine 46
doc/claude/issues/0189-dblclick-delta-marker-selects-pair.md   (0189 verified free today)
```

---

**Status: IMPLEMENTED (2026-08-01) — issue
`doc/claude/issues/0189-dblclick-delta-marker-selects-pair.md`, verdict `[E]`.
Every decision D-1 … D-22 above was implemented as written. All five named
sabotages (§8.3) were verified to fail exactly their target legs, with two
recorded deviations from the abbreviated table, both of them the leg being
*right* rather than the sabotage being wrong — see below. Implementation prompt:
`doc/claude/overnight_batch_2026_08_01/prompts/02_dblclick-delta-marker-selects-pair.md`.
The `[E]` is §9's list: the two-ring rendering and the cross-strip repaint are
pixels no check can see.**

### Post-implementation corrections to §8

1. **`SAB-1` and the staging of `MS8` / `MS14`.** As first written, both legs
   staged their two-marker selection with `select -pair`, so `SAB-1` (which
   disables the pair widening) collapsed them too — they appeared in its kill
   list although §8.3 says they must stay green. The **leg** was wrong: `MS8`'s
   subject is *"no token at any selection SIZE"* and `MS14`'s is the read-only
   split, neither of which is about the pair policy. `MS8` now stages with
   `select -set 2 1` (pair-policy-independent) and additionally exercises
   `-pair`; `MS14` now asserts only that the head moved. `SAB-1`'s measured kill
   list is then exactly the pair legs: `MS1`, `MS5`, `MS7`, `MS9`'s pair halves,
   `MS-X1b`, `MS-X1f`, `MS-X4` and `MS-X5` — the last two of those being pair
   legs the prompt's §8b table added *after* §8.3 was written.
2. **`SAB-3` and the missing C-key leg.** §8.3 expects `SAB-3`
   (`graph_marker_delete_selected` deletes only the head) to kill `MS-X4`. It
   does not, and cannot: `MS-X4` is the **viewer's** Delete, which goes through
   the Tcl `delete_items` path and never touches that primitive. The gap was
   real — the C `Delete` KEY path over an embedded graph had no leg at all — so
   **`MS-X6`** was added to the `MF*` display half: select the pair with a `-3`,
   press a real `Delete`, assert both records go and one `xschem undo` brings
   both back. `SAB-3` now kills `MS9` + `MS-X6`; `SAB-5` kills `MS10` +
   `MS-X6`'s undo legs.

Measured check counts: **437** (`--nogui`) and **979** (DISPLAY), up from
**373** / **870** at HEAD `be5d9b98`. `MZ1`'s two constants were updated to
match.
