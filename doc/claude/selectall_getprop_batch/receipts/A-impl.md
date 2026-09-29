# Receipt — Stage A, implementation (issue 1617: Ctrl-A selects all traces)

Crew: A-impl. Branch `fluid-editing`, HEAD `06423abe` when I started, `69adfe59` when I
finished (Stage B landed meanwhile). **Everything of mine is left UNCOMMITTED in the
tree**, per the brief.

⚠ **THE TREE WAS SHARED WITH A LIVE STAGE B CREW FOR MOST OF THIS STAGE.** Part way
through my first build, `git status` showed `src/scheduler.c`,
`tests/headless/test_getprop_index_bounds.tcl` and `doc/xschem_man/developer_info.html`
already modified by someone else (issue 1618's `getprop_gfx_prop`). I touched none of
them, but **my `make -C src` compiled their then-uncommitted `scheduler.c` into the shared
binary**, and theirs will have compiled mine. They were committed as `69adfe59` before I
finished, so **HEAD is now `69adfe59` and my diff is the only uncommitted work in the
tree** — and my final green figure happens to be exactly HEAD + my diff. I checked `md5sum
src/xschem` immediately before and after each measuring run and it never moved mid-run, so
no run of mine was polluted by an interleaved build. Two things the driver should still
know: intermediate figures in §2–§4 were taken on a binary carrying both stages, and the
five sabotage windows each left a deliberately broken binary in the tree for ~3 minutes.
Nothing Stage B measures goes near Ctrl-A, but that risk was real and is reported rather
than hidden. **The binary in the tree right now is current** (binary mtime 1790684233 >
newest source 1790684232) and is HEAD + my diff, fully built.

---

## 1. What I changed, by symbol

**Seam chosen: recon's option (b), a new branch inside `waves_callback`, NOT a new
registered action.** Reasoning in §7; the consequence is that no line of
`action_registry[]`, `init_input_bindings()`, `src/actions.csv` or `src/keybindings.csv`
changed, so **D10 trap 3 does not apply** — and I proved that rather than assumed it
(`test_bindings_file`, the byte-comparator, `RESULT: ALL PASS`).

### `src/draw.c` — new `graph_sel_waves_all(void)`
Placed immediately after `graph_sel_waves_toggle()`. Iterates every layer-`GRIDLAYER`
rect with `flags & 1`, counts the strip's node space with the same expression
`legend_slot_hit()` uses (`count_items(get_tok_value(r->prop_ptr, "node", 0), "\n",
"\"")`), builds `{0 … n-1}` and hands it to **`graph_sel_waves_set`**. Returns 1 when any
rect's prop string actually changed.

Three properties that are decisions, not incidentals:
* **Window-wide** (D8): the loop is over every rect, not `xctx->graph_master`.
* **A strip with no traces is left untouched**, not cleared. `graph_sel_waves_set(i,
  NULL, 0)` writes `hilight_wave=-1` whenever the token is merely *absent*, so `n <= 0`
  would churn every blank strip's prop string and report `changed`, costing a redraw to
  select nothing.
* **It is a CALLER of the three sanctioned writers, not a fourth writer** — it never
  touches `hilight_wave`/`sel_waves` itself. The `xschem.h` invariant ("these three are
  the ONLY sanctioned readers/writers of that pair") still holds verbatim.

### `src/xschem.h` — declaration + documentation
`extern int graph_sel_waves_all(void);` added beside the other three, and the
trace-selection block comment extended to say explicitly that it composes
`graph_sel_waves_set` rather than joining the writer set.

### `src/callback.c` — new branch in `waves_callback()`
```c
else if(event == KeyPress && key == 'a' && (state & ControlMask)) {
  if(graph_sel_waves_all()) need_all_redraw = 1;
}
```
Sited **immediately above** the existing `else if(key == 'a' && access_cond)` cursor-A
toggle — which is the whole point, since that is the branch this takes the chord away
from. `need_all_redraw` (not `need_redraw_master`) because the bolding changes on strips
other than the master, exactly as the Button1 cross-strip sweep already does.

### `src/wave_viewer.tcl` — carve-out in `wviewer::key_filter`'s cursor tail
```tcl
if {$T == 2 && ($N == 97 || $N == 98 || $N == 115) &&
    !($N == 97 && ($s & 4))} {
  wviewer::key_cursor_tail $W $N
}
```
D10 trap 1. Shaped like the existing `fwd` carve-outs for 98/100. Ctrl+s (115) is
deliberately **not** carved out: it still swaps the cursors in C, and 115 reaches neither
`cva` nor `cvb` in the tail anyway, only the readout refresh it still needs.

### `tests/headless/test_wave_viewer.tcl` — the fence
Already registered (`dcases`) and already prints the `OVERALL: ok` sentinel since issue
1616, so **no registration work and no T1 case-count move.**

* **`send_key` gained an optional 4th parameter `gargs`**, forwarded to `event generate`.
  Not cosmetic — see §5.4. Existing callers pass nothing and are unaffected.
* **The `key_filter` instrumentation now records `::kf_last` = `{T N s}`.** Behaviour-
  neutral; it is the only witness that a generated chord *arrived as that chord*.
* **New CA band** (after SD5, before the SD teardown, inside the `have_raw` guard so
  `wb_ev` and a real raw are available). Helpers `ca_sel`, `ca_tok`, `ca_cursorA`,
  `ca_bands`, `ca_row`, `ca_send`, all renamed away at the end. **30 new checks.**

---

## 2. The red, verbatim

### 2a. First red — the band as first written, against the tree as handed to me
`tests/headless/run_suites.sh test_wave_viewer`:

```
FAIL     | test_wave_viewer             run 1/1  RESULT: 11 FAILED (420 passed)
         | FAIL: CA1 every trace of the POINTED strip is selected -> {} (exp {0 1}) : FAIL
         | FAIL: CA1 ...and of the OTHER strip too (window-wide, D8) -> {} (exp {0}) : FAIL
         | FAIL: CA2 strip 0 wrote BOTH tokens (sel_waves is the set) -> {-1 {}} (exp {0 {0 1}}) : FAIL
         | FAIL: CA2 strip 1's 1-element selection leaves sel_waves ABSENT -> {-1 {}} (exp {0 {}}) : FAIL
         | FAIL: CA3 selection_pairs gives the Delete path every trace, as {gi ti} -> {} (exp {{0 0} {0 1} {1 0}}) : FAIL
         | FAIL: CA4 Ctrl-A no longer toggles cursor A (engine AND menu mirror) -> {1 1} (exp {0 0}) : FAIL
         | FAIL: CA5 bare `a` still toggles cursor A, mirror and engine together -> {0 0} (exp {1 1}) : FAIL
         | FAIL: CA5 ...and off again -> {1 1} (exp {0 0}) : FAIL
         | FAIL: CA6 a second Ctrl-A leaves the same set selected (not a toggle) -> {{} {}} (exp {{0 1} 0}) : FAIL
         | FAIL: CA7 ...and still leaves cursor A alone -> {1 1} (exp {0 0}) : FAIL
         | FAIL: CA8 the cap holds at 64, the first 64 node indices -> {0 {} {}} (exp {64 0 63}) : FAIL
```

**Every row FAILED; none threw.** `CA4 -> {1 1}` is recon's measurement reproduced inside
a real ASE-L viewer for the first time: the chord toggled x-cursor A (engine bit *and*
menu mirror) and selected nothing.

### 2b. Definitive red — the FINISHED band (CA9 + the CA7 reset added) on a tree with both halves of the fix removed
I reverted the `callback.c` branch and the `wave_viewer.tcl` carve-out, rebuilt, and re-ran,
so the rows added after 2a also have an observed red:

```
FAIL     | test_wave_viewer             run 1/1  RESULT: 13 FAILED (424 passed)
         | FAIL: CA1 every trace of the POINTED strip is selected -> {} (exp {0 1}) : FAIL
         | FAIL: CA1 ...and of the OTHER strip too (window-wide, D8) -> {} (exp {0}) : FAIL
         | FAIL: CA2 strip 0 wrote BOTH tokens (sel_waves is the set) -> {-1 {}} (exp {0 {0 1}}) : FAIL
         | FAIL: CA2 strip 1's 1-element selection leaves sel_waves ABSENT -> {-1 {}} (exp {0 {}}) : FAIL
         | FAIL: CA3 selection_pairs gives the Delete path every trace, as {gi ti} -> {} (exp {{0 0} {0 1} {1 0}}) : FAIL
         | FAIL: CA4 Ctrl-A no longer toggles cursor A (engine AND menu mirror) -> {1 1} (exp {0 0}) : FAIL
         | FAIL: CA5 bare `a` still toggles cursor A, mirror and engine together -> {0 0} (exp {1 1}) : FAIL
         | FAIL: CA5 ...and off again -> {1 1} (exp {0 0}) : FAIL
         | FAIL: CA6 a second Ctrl-A leaves the same set selected (not a toggle) -> {{} {}} (exp {{0 1} 0}) : FAIL
         | FAIL: CA9 Ctrl-A selects all in the graph_use_ctrl_key 1 profile too -> {{} {}} (exp {{0 1} 0}) : FAIL
         | FAIL: CA9 ...and cursor A stays put there as well (D9's declared price) -> {1 1} (exp {0 0}) : FAIL
         | FAIL: CA7 ...and still leaves cursor A alone -> {1 1} (exp {0 0}) : FAIL
         | FAIL: CA8 the cap holds at 64, the first 64 node indices -> {0 {} {}} (exp {64 0 63}) : FAIL
```

### 2c. Rows that were GREEN on the unfixed tree, and are evidence in their own right
`CA0` passed in 2a and 2b — which **settles the one question recon could not**:

* `CA0 the Ctrl-A reached the viewer's key filter` → 1
* `CA0 ...and arrived AS Ctrl+keysym-97 (Control bit set)` → 1 (from `::kf_last`)
* `CA0 nothing binds <Control-Key-a> ahead of the key filter` → `{}` (swept every bindtag
  of the canvas **and** the toplevel)

So nothing intercepts `<Control-Key-a>` before the viewer canvas sees it, measured in a
really-open viewer rather than derived from a grep.

---

## 3. The green

**Baseline, taken by me before writing a line** (the brief's instruction; the brief's
"known pre-existing reds" list is silent about this suite):

```
PASS     | test_wave_viewer             run 1/1  RESULT: ALL PASS (407 checks)
```

**After the fix:**

```
PASS     | test_wave_viewer             run 1/1  RESULT: ALL PASS (437 checks)
```

407 → 437, **+30 checks**, zero pre-existing reds in this suite. `md5sum src/xschem` was
`9a21d187…` before and after that run — no interleaved rebuild.

**Sibling suites, for collateral damage** (all the suites mentioning `key_cursor_tail`,
`cursor_toggle`, `graph_flags` or a bare `a` that are not annotation suites):

```
PASS     | test_wave_hilight            run 1/5  RESULT: ALL PASS (196 checks)
PASS     | test_wave_modes              run 2/5  RESULT: ALL PASS (488 checks)
PASS     | test_wave_axis_zoom          run 3/5  RESULT: ALL PASS (370 checks)
PASS     | test_key_graph_context       run 4/5  RESULT: ALL PASS
PASS     | test_wave_cursor_crossdb     run 5/5  RESULT: ALL PASS (93 checks)
RESULT: 5/5 runs passed
```

**`test_bindings_file` (the unregistered CSV byte-comparator, D10 trap 3):**

```
PASS     | test_bindings_file           run 1/1  RESULT: ALL PASS
```

**Out-of-scope invariant, by probe** (not a committed test;
`scratchpad/A-impl/probe_scope.tcl`, armed HOME, `devdisplay.sh exec`, fixture
`xschem_library/examples/tb_test_evaluated_param.sch`):

```
PROBE: after Ctrl+a OVER GRAPH   lastsel=0 hilight_wave=0 sel_waves=0 1 2 graph_flags=0
PROBE: after Ctrl+a OVER CANVAS  lastsel=20 graph_flags=0
PROBE: lastsel after unselect_all = 0
PROBE: lastsel after `xschem select_all` = 20
```

Three things at once: the schematic canvas Ctrl+A still reaches `select_all()` and still
selects 20 objects (**unchanged**, recon §6 item 1); `xschem select_all` is untouched
(item 2); and the new branch **also covers graphs embedded in an ordinary schematic**, not
only the ASE-L viewer — `sel_waves=0 1 2` on a three-node strip, with `graph_flags` never
leaving 0.

---

## 4. What I sabotaged, and what reddened

Each sabotage: apply, `make -C src`, run the suite, revert, rebuild. All five were run.

| # | the plausible wrong implementation | result | rows that caught it |
|---|---|---|---|
| 1 | **Per-strip, not window-wide** — `if(i != xctx->graph_master) continue;` in the loop | `4 FAILED (427 passed)` | `CA1 ...and of the OTHER strip too` → `{}`; `CA2 strip 1's …` → `{-1 {}}`; **`CA3 selection_pairs …` → `{{0 0} {0 1}}`** (the Delete path would have missed strip 1); `CA6` |
| 2 | **`hilight_wave` written, `sel_waves` forgotten** — a direct `subst_token` of the head token instead of `graph_sel_waves_set` | `5 FAILED (426 passed)` | `CA1 every trace of the POINTED strip` → `{0}`; `CA2 strip 0 wrote BOTH tokens` → `{0 {}}`; `CA3` → `{{0 0} {1 0}}`; `CA6`; `CA8` → `{1 0 0}` |
| 3 | **`key_cursor_tail` carve-out omitted** (the C half only) | `4 FAILED (427 passed)` | **`CA4 … (engine AND menu mirror)` → `{1 0}`** — mirror ON, engine OFF, i.e. D10 trap 1 exactly; plus `CA5` ×2 and `CA7`. **No selection row moved**: the feature worked perfectly and the Cursors ▸ Cursor A checkbutton lied on every press. Without CA4 this ships silently. |
| 4 | **`mutates = 1`** — the branch routed through `readonly_block()`, which is what a registry row with the positional 5th field set to 1 would do to it | `9 FAILED (422 passed)` | `CA1` ×2, `CA2` ×2, `CA3`, `CA6`, `CA8`, and the two rows that name the mechanism: **`CA4 ...and it popped no read-only modal` → `{1}` (exp `{0}`)** and **`CA7 ...and pops no modal` → `{3}` (exp `{2}`)** |
| 5 | **Cap removed** — trust `graph_sel_waves_set`'s own clamp | ⚠ **`ALL PASS (431 checks)` — NOT CAUGHT** | none |

### ⚠ Sabotage 5 is the finding, and it changed the code

Deleting my two-statement clamp left **every** row green. `graph_sel_waves_set` clamps
too, so `CA8` still read exactly 64 selected — while `for(k = 0; k < n; ++k) sel[k] = k;`
wrote 65 ints into `sel[GRAPH_MAX_SEL_WAVES]`, one past the end of a stack array. That is
CLAUDE.md's *"a fence keyed to a symptom dies quietly when something else cures the
symptom"*, reached from the memory side: **a stack write that lands somewhere harmless is
invisible to every behavioural assertion there is, and no row I can write changes that.**

So I did not add a row; I removed the hazard. `ndraw` (what the strip draws) and `n` (what
fits) are now separate, and `n = ndraw < cap ? ndraw : cap;` applies the bound in **one
expression** that cannot be deleted without rewriting the assignment. `cap` is
`sizeof(sel)/sizeof(sel[0])` — the array's own bound, not a re-quoted constant. The
`dbg(0, …)` line is all the former clamp statement still owns. The comment in `draw.c`
records the measurement so the next reader does not "simplify" it back.

**Stated plainly, as the brief requires for anything unverified: the behavioural half of
the 64 cap is fenced (`CA8`); its memory-safety half is fenced by the shape of the code
and by nothing else.**

---

## 5. What I got wrong

1. **`CA6`'s expected value was malformed, and the row was red on a green product.** I
   wrote `check … [list [ca_sel 0] [ca_sel 1]] {{0 1} {0}}`. Tcl's `list` braces an
   element only when it *has* to, so `[list {0 1} {0}]` is the string `{0 1} 0`. The first
   green run came back `1 FAILED (430 passed)` with
   `CA6 … -> {{0 1} 0} (exp {{0 1} {0}})`. Corrected me: reading the got/exp pair rather
   than assuming the product. A comment now sits on that row explaining why the second
   element is bare, so nobody "restores the symmetry" with CA1's braces.
2. **I would have shipped an unfenced buffer overflow.** My first cut had the cap as a
   separate `if(n > GRAPH_MAX_SEL_WAVES) { dbg(…); n = …; }`. I believed `CA8` fenced it.
   Sabotage 5 proved it did not, and could not. Corrected me: running the sabotage I
   expected to be boring.
3. **`CA7`'s cursor row was measuring a PARITY, not an invariant.** Inserting CA9 above it
   changed the number of preceding Ctrl-A presses, and on the unfixed tree CA7's cursor
   row flipped from red to green — CA9's press had toggled cursor A on and CA7's toggled
   it off again. Corrected me: comparing the 2b red (12 failures) against the 2a red (11)
   and noticing the row that had *disappeared*. There is now an explicit reset plus a
   `CA7 fixture:` row before that gesture, and the finished band reddens 13.
4. **Neither the PLAN nor the recon receipt says the pointer pixel is part of a KEY
   gesture, and it is.** `callback()` recomputes `xctx->mousex/mousey` from the event's
   own `%x`/`%y` for **every** event type, KeyPress included, and `waves_selected()` then
   asks whether *that* point is inside a graph rect. A `<Control-Key-a>` generated with no
   `-x`/`-y` therefore decides the graph context from whatever Tk defaults those fields
   to. Recon's probes passed coordinates explicitly (`xschem callback .drw 2 797 192 97 0
   0 4`) and so never hit this; a `send_key`-driven row would have. That is why `send_key`
   gained `gargs` and why `ca_send` sends a `<Motion>` first (the Tcl-side `over_graph`
   gate reads the `mousex_snap` *mirror*, C's `waves_selected` reads what the key event
   just wrote — two different reads of the same idea, and a row has to satisfy both).
5. **I did not notice the shared tree until after my first build.** I rebuilt on top of
   another crew's uncommitted `scheduler.c`. Nothing broke, but I should have run `git
   status` before `make`, not after.

---

## 6. What I did NOT do

* **No commit, no push, no stash, no T1, no gate.** Working tree left dirty. My files:
  `src/draw.c`, `src/callback.c`, `src/xschem.h`, `src/wave_viewer.tcl`,
  `tests/headless/test_wave_viewer.tcl`, plus this receipt. **Not mine:** the untracked
  `.xschem/` and `sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/`, which were
  already there when I arrived. Stage B's files are now committed (`69adfe59`) and no
  longer show.
* **No new action id, no `action_registry[]` row, no `actions.csv` label, no
  `init_input_bindings()` change, no `keybindings.csv` regeneration.** Seam (b). See §7.
* **No menu entry.** A "Select All Traces" item in the **Graph** cascade (the viewer has
  no Edit cascade, and `test_wave_viewer` G2 pins the cascade set) is a user-facing label
  and an accelerator decision. D9's "do not pay for an unratified change with new UI"
  applies to it as much as to a replacement cursor-A chord.
* **No `ciw_echo` for the 64 cap.** Recon floated it on the `hilight_traces` precedent. It
  would be a new user-facing sentence; the cap is on the debug channel and in row `CA8`
  instead. The driver can promote it after the ruling.
* **No `owed.sh` entry of any kind.** The cursor-A ruling is already the driver's per D9,
  and a second ruling from me would break "one ruling at a time".
* **The delete path is untouched** — `wviewer::delete_selection_at`, `selection_pairs`,
  `delete_items`, `trace_index_of_node`: not one line. `CA3` asserts the shape they
  consume instead.
* **No log line** (D11), and no `log_action` was added anywhere.
* **I did not drive bare `a` in the `graph_use_ctrl_key 1` profile.** There it falls
  through to the schematic `case 'a'` and opens the **make-symbol dialog**, which the
  suite's `tk_messageBox` stub does not cover — it would pop a real dialog on the dev
  display and stall the suite rather than measure anything. `CA9` drives the Ctrl half
  only, and says so in its comment.
* **I did not measure the 5-px `border` band-edge inset** where `waves_selected` declines
  and Ctrl-A therefore reaches `select_all()` and selects the graph rects as objects.
  Pre-existing (issue 0149), explicitly out of scope, and my probe confirms the
  fall-through still behaves as it always did.
* **No T1 run and no other suite beyond the seven named in §3.** The dev display `:99` was
  left exactly as found (`alive`; no `start`/`stop`/`view`).
* **No permission prompt denied me anything.**

---

## 7. What the next stage / the driver must know

1. **⚠ THE CHORD IS NOT IN THE KEYBINDINGS CHEAT SHEET, AND THAT IS A CONSEQUENCE OF THE
   SEAM.** `generate_keybindings_text` (`src/action_registry.tcl`) builds the help window
   from `xschem bindings dump` and explicitly `continue`s over `graph.forward` as "context
   plumbing, not user commands". Since I retargeted nothing, `key 97 ctrl graph` still
   resolves to `graph.forward`, so **Ctrl-A appears nowhere in the generated help** — and
   neither did its old cursor-A meaning, so nothing became *worse*. But "the user's own
   wish-list feature is undiscoverable" is a real product gap, it is user-facing, and it
   is the one thing seam (a) would have bought. **Recommend the driver pair it with the
   cursor-A ruling as a single conversation** ("Ctrl-A now selects all traces; should it
   also appear in Help ▸ Keys, and should there be a Graph ▸ Select All Traces entry?"),
   because both questions are about the same change and asking them separately wastes a
   round.

2. **Why seam (b) and not (a).** Recon called it an internal engineering call and it is,
   so here is the reasoning rather than a preference. (i) The chord was **already in the
   table** — `key,97,ctrl,graph` — so the PLAN's "must go through that table rather than a
   hard-coded `bind`" is satisfied without touching it; nothing here is a Tk `bind`.
   (ii) A new action id would **appear in the user-visible cheat sheet with a label I
   would have had to invent**, which is the new unratified UI D9 declined to add. (iii)
   The remappability seam (a) buys does **not** mitigate the one real cost: rebinding
   `graph.select_all_traces` off Ctrl-A would not give the `graph_use_ctrl_key 1` user
   cursor A back, because cursor A is not an action. (iv) `waves_callback` owns the
   `need_*_redraw` / `setup_graph_data` re-read machinery; a standalone action function
   would have had to reimplement it. **If the driver wants (a) after the ruling, it is a
   clean follow-on**: add the row, retarget the `set_input_binding` call, regenerate the
   CSV with `save_input_bindings_file`, and the whole CA band keeps passing unchanged
   because it asserts behaviour, not ids.

3. **D10 trap 2 is satisfied by construction and is still fenced.** There is no new
   action, so nothing needed `mutates = 0`; `graph.forward`'s registry row has four
   initializers and the positional 5th field defaults to 0. I fenced the *failure class*
   anyway — sabotage 4 put the branch behind `readonly_block()` and the two `$::mb_hits`
   rows caught it (`{1}` exp `{0}`, `{3}` exp `{2}`). So if anyone later migrates to seam
   (a) and forgets the column, `CA4`/`CA7` redden.

4. **D10 trap 3 does not apply, proved not assumed.** `git diff --stat src/keybindings.csv`
   is empty and `test_bindings_file` (the unregistered byte-comparator) is `ALL PASS`.

5. **`test_wave_viewer`'s baseline moves 407 → 437.** The T1 **case count does not move**
   — the suite was already in `dcases` and already prints `OVERALL: ok`. Nothing needs
   registering and `CLAUDE.md`'s case-count table is unaffected by Stage A.

6. **The suite was green at 407 before I touched it.** The brief's "known pre-existing
   reds" list does not mention it (recon flagged that gap); it is not red.

7. **The change covers embedded schematic graphs too**, not only the ASE-L viewer, because
   it lives in `waves_callback`. Probe output in §3. Nobody asked for that and nothing is
   harmed by it, but it is a wider blast radius than "the waveform viewer" and the driver
   should know it is deliberate: `waves_callback` is the shared handler, and a strip is a
   strip.

8. **One PLAN gap closed.** Recon's "the third direction the PLAN is missing" — the
   `graph_use_ctrl_key 1` profile — is now row `CA9`, observed red on the pre-fix tree.
   D9's declared price is therefore fenced in the direction it was declared: Ctrl-A
   selects, cursor A does not move, in *both* profiles.

9. **The `send_key` signature change is local to this suite** (`proc send_key {w ev done
   {gargs {}}}`) and every pre-existing caller is unaffected. If another suite ever copies
   `send_key` for a graph-context chord, it needs `gargs` — see §5.4 for why.

10. **`::kf_last` is now available to any row in that suite's GUI band** as the
    `{T N s}` triple of the last `key_filter` call. It cost nothing and it is the only way
    to tell "the code declined the chord" from "the chord lost its modifier in the Tk/WSLg
    round trip".
