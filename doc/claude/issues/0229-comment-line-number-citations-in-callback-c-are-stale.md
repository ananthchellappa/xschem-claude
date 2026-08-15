# 0229 — comments in `src/callback.c` cite bare line numbers, and 25 of the 27 no longer point at what they name

Status: **OPEN**. Severity: **low** — comments only, no runtime effect. Filed because the
citations are actively misleading: several land on a plausible-looking wrong line rather
than on nothing.
Found by: the merge-4 audit, checking every `:NNNN` in `src/callback.c` against the merged
tree at `15c600c6` and against both of its parents.
Related: `doc/claude/issues/0226-*.md` (same audit; the same failure mode one layer up — a
lookup rule that resolves to a real but wrong target).

## Symptom

`src/callback.c` carries line-number citations on **27** comment lines. On the merged tree
exactly **two** — `select.c:790` and `findnet.c ~208` — still land on what their comments
say.

Those 27 come in two spellings, and the split matters because the second one is what made
the first count of this issue wrong:

* the **colon form** (`select.c:790`, `:7878`, `(:1199)`) — 20 lines, **19 stale**, the
  table below;
* the **tilde form** (`draw.c ~4518`, `~8200`, `findnet.c ~208`) — **7 more lines**
  (`callback.c` 135, 1224, 1286, 1292, 3167, 3260, 8866), **6 stale**. The survivor is
  `:3167`, *"`find_closest_net_or_symbol_pin()` falls back to `mousex_snap`/`mousey_snap`
  (`findnet.c ~208`)"*: `src/findnet.c:201` opens that function and `:208` is the
  `min_dist_x = xctx->mousex_snap` line, exactly as named.

The worst of the tilde set is `draw.c ~8433`, cited **twice** (`:3260`, `:8866`) for
`if(tclgetboolvar("draw_crosshair")) draw_crosshair(7, 0);` — which now lives at
`src/draw.c:9816`, off by 1383. (`draw.c:8433` is a `my_free()` of `bus_msb`.)

**This issue shipped its own first draft with the defect it files**, twice: the `:393` row
below said 624 when the `delete()` it names is at 623 on both the merge and `HEAD^2`, and
the tilde form above was missed entirely by the Repro regex, which produced a confident
"19 of the 20 / exactly one survivor" that was wrong in both terms. Both were caught by an
adversarial re-read and are corrected here. That is the strongest available argument for
the fix at the end: a line number is not checkable by the reader who most needs it.

The clearest case, `src/callback.c:392-393`:

```
 * terminal: :7878's click-select guard requires !sympin_preview, so no press can select,
 * grab or complete anything ever again, and wire_label_try_commit() (:2843) refuses forever
```

What is actually at those lines:

```
$ sed -n '7878p;2843p' src/callback.c
2843:      if(rotl) av[ac++] = "local";
7878:    case '|':
```

Where the two named things really live:

```
$ grep -n '!xctx->sympin_preview' src/callback.c
8106:        !(xctx->ui_state & (PLACE_SYMBOL | PLACE_TEXT | START_SYMPIN)) && !xctx->sympin_preview) {
$ grep -n '^int wire_label_try_commit' src/callback.c
2990:int wire_label_try_commit(void)
```

They were exact when written, at `280bc18c` (2026-08-06):

```
$ git show 280bc18c:src/callback.c | sed -n '393p;398p;399p;2843p;2872p;2927p;7878p'
:393  ->      delete((xctx->sympin_preview && (xctx->ui_state & START_SYMPIN)) ? 0 : 1/* to_push_undo */);
:398  ->      xctx->sympin_preview = 0;
:399  ->      xctx->wirelabel_preview = 0;   /* add_wire_label.md: torn-down label preview */
:2843 ->   if(!(xctx->ui_state & START_SYMPIN) || !xctx->wirelabel_preview) return 0;
:2872 ->   else if(xctx->ui_state & STARTWIRE) {
:2927 ->   else if(xctx->ui_state & STARTMOVE) {
:7878 ->         !(xctx->ui_state & (PLACE_SYMBOL | PLACE_TEXT | START_SYMPIN)) && !xctx->sympin_preview) {
```

All seven correct then. All seven wrong now.

## Why it was invisible

A bare `:NNNN` is unverifiable at review time — nothing checks it, and the reviewer would
have to open the file at that offset to notice. Worse, the misses are quiet: `:8665` lands
on `(persistent_command && (xctx->last_command & STARTLINE));` on `HEAD^2`, the
`line_draw_active` tail — a near-miss twin of the `wire_draw_active` line it names, which
reads plausible and would be accepted by a spot-checking reader.

And two of them were **wrong in the very commit that wrote them**, because the author read
the number off the buffer *before* their own insertion (see below). So the form is roughly
as likely to be wrong on day one as it is to rot later.

## The merge is innocent

Category "correct on a parent, desynchronised **by** merge 4" is **empty**.

```
$ diff -u <(git show HEAD^2:src/callback.c) src/callback.c | grep -E '^@@'
@@ -5060,6 +5060,22 @@
@@ -5223,7 +5239,15 @@
@@ -5335,6 +5359,18 @@
```

+37/−1 = +36 net, all above line 5060. Every citation target below 5060 keeps its `HEAD^2`
line number. The merge moved exactly three targets — 8020→8056, 8070→8106, 8842→8878 — and
all three were **already stale on `HEAD^2`** by 177, 192 and 177 respectively. The merge
added 36 to numbers that were already wrong by about 180; it broke nothing that was right.

All four citation-bearing commits are on the incoming side only:
`git merge-base --is-ancestor 280bc18c HEAD^1` → false, `… HEAD^2` → true; likewise
`8ff4041a`, `11debb49`, `465223be`. (`826e1b60`, which wrote the `:710/:711` and
`:1047/:1048` pairs, is in both parents.)

## Classification table

`merged` / `HEAD^2` / `HEAD^1` are the line numbers where the named thing **actually** is.
Class **a** = already stale on `HEAD^2`; **b** = also stale on `HEAD^1`; **c** = broken by
the merge (empty); **d** = still correct.

| cite (cb.c line) | comment says it is | merged | HEAD^2 | HEAD^1 | right when written? | class |
|---|---|---|---|---|---|---|
| `:710`/`:711` (34, 2158) | marker click, `GRAPH_CLICK_TOL * zoom` | 956/957 | 956/957 | 743/744 | yes, `826e1b60` | a+b |
| `:1047`/`:1048` (35, 2159) | wave-bold click | 1310/1311 | 1310/1311 | 1097/1098 | yes, `826e1b60` | a+b |
| `:393` (389) | the `delete()` in the placement abort | 623 | 623 | 372 | yes, `280bc18c` | a |
| `:398-399` (390) | `sympin_preview`/`wirelabel_preview` clears | 638/639 | 638/639 | 377/378 | yes, `280bc18c` | a |
| `:7878` (392) | click-select guard `!sympin_preview` | 8106 | 8070 | 7843 | yes, `280bc18c` | a (+36 from merge) |
| `:2843` (393) | `wire_label_try_commit()`'s refusal | 2993 | 2993 | 2772 | yes, `280bc18c` | a |
| `select.c:790` (399) | `delete()`'s trailing `draw()` | 790 = `draw();` | 790 | 790 | yes | **d — the only survivor** |
| `:2872` (532, 645) | `end_place_…()` STARTWIRE test | 3023 | 3023 | 2801 | yes at `280bc18c`; already stale when **copied** into the `465223be` comment | a |
| `:2927` (533, 646) | the placement arm (`… & STARTMOVE`) | 3078 | 3078 | 2856 | yes at `280bc18c`; stale when copied at `465223be` | a |
| `:7843` (565) | press handler testing `last_command` alone | 8056 | 8020 | 7793 | yes, `8ff4041a` | a (+36) |
| `:541` (569) | `last_command = STARTWIRE` | 691 | 691 | 478 | **NO — off by 15 at birth** | a |
| `:476` (569) | `last_command = STARTLINE` | 509 | 509 | 455 | yes, `8ff4041a` | a |
| `:7843-7856` (573) | the persistent-command press block | 8056-8071 | 8020-8035 | 7793-7808 | yes, `8ff4041a` | a (+36) |
| `:8665` (577) | `wire_draw_active` computation | 8878 | 8842 | 8615 | yes, `8ff4041a` | a (+36) |
| `~line 116` (1333) | `waves_selected`'s locked-rect bypass | 175 | 175 | 175 | yes-ish (117, and the cite says "~"), `5189c065` | a+b |
| `move.c:1600` (5755) | arc CENTER is the move START ref | `move.c:8880` | 8880 | 8880 | yes-ish (block head 1600, assignment 1602), `2afe5d29` | a+b |
| `:4460` (7192) | context-menu twin `stamp_placement_preview()` | 4483 | 4483 | absent | **NO — off by 23 at birth** | a |

### The two born stale

`:541`, commit `8ff4041a`. Before the commit the target was on 541; the commit's own
~15-line comment block — the one that cites it — pushed it to 556 in the same patch:

```
$ git show 8ff4041a^:src/callback.c | grep -n 'last_command = START'
476:    xctx->last_command = STARTLINE;
541:  xctx->last_command = STARTWIRE;
$ git show 8ff4041a:src/callback.c | grep -n 'last_command = START'
476:    xctx->last_command = STARTLINE;
556:  xctx->last_command = STARTWIRE;
```

Its sibling `:476` sat *above* the insertion and was correct.

`:4460`, commit `11debb49` — the commit that introduced `stamp_placement_preview()`:

```
$ git show 11debb49:src/callback.c | grep -n 'stamp_placement_preview()'
501:      stamp_placement_preview();   /* issue 0231 -- see stamp_placement_preview() in select.c */
4483:        stamp_placement_preview();
7156:          stamp_placement_preview();  /* issue 0231, same note as the context-menu twin at :4460 */
$ git show 11debb49:src/callback.c | sed -n '4460p'
      break;
```

The twin landed at 4483, 23 lines below the number cited for it, on the day it was written.
(Note the same commit's `:501` comment cites the *symbol*, not a line — and that half is
still correct today.)

## Repro

```sh
# the COLON form -- 20 lines
grep -nE '(\.c|\.h|\.tcl):[0-9]+|\(:[0-9]{2,4}|[ (]:[0-9]{3,4}|~?line[s]? [0-9]{3,4}' src/callback.c
#  -> 34 35 389 390 392 393 399 532 533 565 569 573 577 645 646 1333 2158 2159 5755 7192

# the TILDE form -- 7 more, which the regex above CANNOT match (it requires the
# literal word "line"). Missing these is what made the first draft's count wrong.
grep -nE '\.(c|h|tcl|y|l) *~?[0-9]{3,4}|~[0-9]{3,4}' src/callback.c
#  -> 135 1224 1286 1292 3167 3260 8866
#     (1778's "~100 lines above" is relative, not a citation -- excluded)
```

then, for each cited number, `sed -n '<n>p' src/callback.c` against `grep -n` for the thing
the comment names. Every "merged" cell in the table above was checked that way at
`15c600c6`; the `HEAD^1` column was spot-checked on 16 of its values via
`git show HEAD^1:src/callback.c`.

Nothing was built and no suite was run: the finding changes no code and has no runtime
component, so a green suite would have been evidence of nothing.

## It is not confined to `callback.c`

`grep -rcE '(\.c|\.h|\.tcl|\.y|\.l):[0-9]+|\(:[0-9]{2,4}\)|~?lines? [0-9]{3,4}' src/*.c`,
excluding the three generated parsers (`expandlabel.c`, `eval_expr.c`, `parselabel.c`, whose
hits are mostly bison/flex `#line` directives — 62, 48 and 34 of them respectively):

```
src/move.c:35   src/scheduler.c:12   src/callback.c:8   src/netlist.c:7
src/token.c:3   src/node_hash.c:3    src/actions.c:3    src/select.c:2   src/hilight.c:1
```

(The `callback.c:8` there is a narrower regex than the one in Repro — the bare `:NNNN` form
inside prose is easy to miss, which is part of the problem.)

Sampling 38 of the `move.c` / `scheduler.c` / `select.c` / cross-file citations against the
merged tree: **8 correct, 2 near** (off ≤4, still inside the right block — `move.c:221` is
one line above the `symbol_bbox()` call; `select.c:1197` is the `statusmsg()` of the info
line whose `my_snprintf` is at 1193), **28 wrong**. The correct ones are
`select.c:695/707/788`, `select.c:499`, `select.c:1729-1731`, `clip.c:234-245`,
`store.c:404`, `flyline.c:80-83`. Verified wrong ones include:

* `src/callback.c:5100` — blank line; the ROTATELOCAL sites are 3823/3830/3835/6106/6110
* `src/callback.c:237` — `return is_inside;`
* `src/save.c:4475` — `calc_symbol_bbox` is at `save.c:4495`
* `src/check.c:405` — `any_inst_pin_at` is at `check.c:201`
* `src/move.c:1220` — `point_near_pin` is at `move.c:1375`
* `src/move.c:8252` cites `check.c:406-423` as "the trim merge"; `merge_collinear_wires` is
  at `check.c:832`

**The rot is contagious by copy-paste.** `src/scheduler.c:119-120` carries a verbatim copy
of three already-stale `callback.c` citations:

```
 * tests STARTWIRE (callback.c:2872) BEFORE the placement arm (:2927), and under
 * `persistent_command` the press handler (callback.c:7843) seizes the click one step earlier
```

and `src/scheduler.c:1967` a second copy (`callback.c:2872 is tested before :2927`).

## Suggested fix

**Cite symbols, not offsets.** Every one of the 20 targets sits inside a named function, so
replace the number with the enclosing function (plus the file when it differs), and where
the point is a specific statement, quote the statement's first tokens instead of pointing at
it. This is already the dominant form in the codebase — `src/*.c` comments carry ~3500
`function_name()` mentions against ~74 hand-written line citations — and it is exactly what
`src/callback.c:501` does today:

```c
      stamp_placement_preview();   /* issue 0241 -- see stamp_placement_preview() in select.c */
```

Concrete rewrites for `src/callback.c` (target → enclosing function, measured):

```
:710/:711  -> graph_marker_drag_to()                          (956/957)
:1047/:1048-> waves_callback()                                (1310/1311)
:393       -> abort_placement_preview()'s delete()            (623)
:398-399   -> abort_placement_preview()'s flag clears         (638/639)
:7878      -> handle_button_press()'s click-select guard      (8106)
:2843      -> wire_label_try_commit()'s START_SYMPIN refusal  (2993)
:2872      -> end_place_move_copy_zoom()'s STARTWIRE arm      (3023)
:2927      -> end_place_move_copy_zoom()'s STARTMOVE arm      (3078)
:7843      -> handle_button_press()'s persistent_command arm  (8056)
:541       -> start_wire()                                    (691)
:476       -> start_line()                                    (509)
:8665      -> callback()'s wire_draw_active init              (8878)
~line 116  -> waves_selected()'s lock=true bypass             (175)
move.c:1600-> move_objects(START)'s ARC arm                   (move.c:8880)
:4460      -> context_menu_action()'s place-text arm          (4483)
select.c:790 -> keep, or upgrade to "delete()'s trailing draw() (select.c)"
```

Where the reference is conceptual rather than a single statement, the house already has
three rot-proof anchors that should be preferred over any location at all: `issue NNNN`, a
`doc/claude/…` path (optionally `WIRING.md §N`), or a pinning test
(`tests/headless/test_*.tcl`). `src/callback.c:393`'s own next clause — "Issue 0240;
WIRING.md §8 class D (decline residue)" — is the model: that half of the sentence is still
accurate while the `:2843` half of it is not.

Give `src/scheduler.c:119-120` and `:1967` the same treatment first, since they are copies
and will otherwise be re-copied.

**Prevention.** A grep in the pre-commit path would refuse new ones for free:

```sh
grep -nE '\(:[0-9]{3,4}|[^0-9]:[0-9]{3,4}' src/*.c   # excluding the three generated parsers
```

## Sub-claims from the original report that did not hold

* **`:406` is a `callback.c` citation** — false. No `:406` exists in `src/callback.c` on the
  merge or on either parent. The only `:406` in `src/` is `check.c:406-423`, cited from
  `src/move.c:8252`, and it is itself wrong.
* **`:8665` matched on `HEAD^2`** — false. Its target is at `HEAD^2:8842`; the citation was
  already off by 177 there.
* **Some citations were correct on a parent and desynchronised by the merge** — false;
  class (c) is empty, per "The merge is innocent" above.
* **Only `:2872 :2927 :7843 :7878 :2843` were stale** — understated. Those are five of
  nineteen.
* **The citations were accurate when written, and rot came from later edits** — true for 15
  of them, false for `:541` and `:4460`.
