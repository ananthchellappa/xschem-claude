# 1270 — the declutter counter counts the RUNG, not what was taken off the sheet

Status: **FIXED** by the driver's A7 re-do, 2026-09-03 · Branch: `fluid-editing`
· Filed by item **A7**'s write-up agent, 2026-09-03, from its own adversary pass.
Related: **1257** (the defect A7 set out to close), **1256**, **1244**, ruling
**D-6**, ruling **D-8**.

**⚠ ITEM A7 IS `[F]` AND ITS CODE IS REVERTED.** Every line of it is preserved,
applying cleanly to commit `355a3dc6`, as
`doc/claude/op_param_batch/A7_working_tree_REFUTED.patch` (1802 lines, md5
`fe5571930f02cdaa3f816b1e3b3ab871`). The re-do is `patch -p1 <` that file, then
the four-line correction in **The repair** below, then rebuild and re-run.
Nothing has to be re-derived.

## The defect, in one sentence

A7 answered "was anything actually hidden?" with a new C counter bumped at the
declutter rung's `return 1` — but that `return 1` sits **above** the three
predicates that would have hidden the text anyway, so the counter answers *"the
declutter rung was the first predicate to say hide"*, not *"this text would
otherwise have been drawn"*. On any annotated device whose only non-`@name` text
is already suppressed by its own `hide=instance` or `hide=true`, the sheet is
byte-identical at mask 1 and mask 9 and **all three status-line producers still
claim a declutter happened** — which is issue 1257's defect, in a state issue
1257 never named.

## Why this is a refutation and not a nice-to-have

The driver's ruling on A7-a is verbatim: *"THE CLAUSE FOLLOWS THE GATE. The
clause is emitted only when something was actually hidden."* In the state below
nothing was hidden and the clause is emitted. The item's binding ruling is not
met, so the item is `[F]` rather than a partial landing. A7's own plan had
already rejected the alternative in writing — *"REJECTED: shipping the partial
fix and filing state 2, which would leave the suite green over a live lie"* —
and shipping this would have left the suite green (132 checks) over a live lie
of exactly that shape. `CLAUDE.md` records that this branch has already shipped
two defects past twenty-eight passing checks; this would have been the third,
past a hundred and thirty-two.

## Measured — BEFORE (the shipped binary, item A7's Measure agent)

The three states A7 was written for. Verbatim from the Measure agent's
`BEFORE_all4.txt`:

```
STATE 1 NO RAW AT ALL
   raw loaded=-1  _annotated=0  block={cid =|}
   mask 1 texts = MC1 CW=1u {cid =}
   mask 9 texts = MC1 CW=1u {cid =}
   HID SOMETHING? NO        CLAUSE IS PRESENT
STATE 2 DEAD RAW (no matching vector)
   raw loaded=0  _annotated=1  block={cid =|}
   HID SOMETHING? NO        CLAUSE IS PRESENT
STATE 3 VALUED RAW (control)
   mask 9 texts = MC1 {cid = 11.1u}
   HID SOMETHING? yes        CLAUSE IS PRESENT
```

## Measured — AFTER (A7's own binary, re-driven by the write-up agent)

Re-run independently of the adversary, on the binary A7 built
(`src/xschem`, 02:03:58, `strings … | grep -c annot_declutter_count` = 2), with
`scratch_A7_verifyC/vc4.tcl`. States 1 and 2 **are fixed**:

```
###### VC-12  A7's OWN FIX, re-driven with a netlist_dir that has NO raw at all
   raw loaded=-1  mask -> 9
   clause absent   (A7 requires: absent)
   Ctrl-Alt-6: Decluttering is on, but nothing changes yet: it applies only while
   operating-point values are showing. Press 6 to show them.
```

State **4**, which nobody had named, is not:

```
###### VC-13  THE COUNTEREXAMPLE, clean: a device whose only non-@name text
######        is hide=instance (as res.sym / nmos4.sym / 11 more ship).
   mask1 texts=MP {aid = 12.3u}
   mask9 texts=MP {aid = 12.3u}
   SVG BYTES IDENTICAL: YES
   chord 6 -> mask 9, clause PRESENT   (A7 requires: absent)
   Ctrl-Alt-6: Decluttering the schematic: a device showing operating-point
   values draws its name and those values only. Press Ctrl-Alt-6 again to bring
   the rest of its text back.
```

The adversary drove the **third** producer too — A7-b's new stock `Graphs >
Annotate` door emits the same false clause on the same sheet (`VC-10`: status
line `Decluttering is on, so other device text is hidden.`, mask 8 -> 11). So
A7-b inherits the defect rather than having one of its own; its own plumbing,
guards and hygiene were all found sound.

## How much of the shipped library has this shape

```
$ grep -l 'hide=instance' xschem_library/devices/*.sym | wc -l
57
$ grep -rl 'hide=instance' xschem_library/ | wc -l
60
```

The false clause needs the device to be **annotated** (ruling D-6) and to have no
*other* visible non-`@name` text — the shape of a minimal PDK symbol, and the
shape of any symbol whose parameter texts the user hid before arming the
declutter.

## The root cause, structurally

`src/actions.c`, `text_hidden_core()`, with A7's edit applied:

```c
  if(n >= 0 &&
     (xctx->annot_show & (ANNOT_SHOW_OP | ANNOT_SHOW_NOPARAM)) ==
                         (ANNOT_SHOW_OP | ANNOT_SHOW_NOPARAM) &&
     !annot_declutter_exempt(flags) &&
     annot_instance_annotated(n)) { ++annot_declutter_count; return 1; }   /* <-- here */
  if(xctx->show_hidden_texts) return 0;
  if(flags & HIDE_TEXT) return 1;
  if(ctx == TEXT_CTX_INSTANCE && (flags & HIDE_TEXT_INSTANTIATED)) return 1;
  return 0;
```

The rung's position is *correct for visibility* and is forced on both sides — the
long comment above it explains why, and none of that changes. What is wrong is
that the **increment** inherited that position. Visibility only needs to know
that the answer is "hide"; the counter needs to know **who hid it first**, and
the three lines below are exactly the ones that would have hidden it anyway.

## The repair

Inside A7's own edit point, no new function and no new call site:

```c
     annot_instance_annotated(n)) {
       /* count it only if the tail below would have DRAWN it -- otherwise the
        * text was already invisible and the declutter took nothing away (1270) */
       if(xctx->show_hidden_texts ||
          (!(flags & HIDE_TEXT) &&
           !(ctx == TEXT_CTX_INSTANCE && (flags & HIDE_TEXT_INSTANTIATED))))
         ++annot_declutter_count;
       return 1;
     }
```

Note the `show_hidden_texts` arm is load-bearing in the direction people will
forget: with **View > Show hidden texts on** — which both shipped Op-Annotate
menu bodies turn on one line before writing the mask — a `hide=instance` text
*is* drawn, so the rung really does take it away and the counter **must** bump.
A guard that only tested the two `HIDE_*` bits would fix the chord and break the
menu.

**The row that must go with it** (and would have caught this):
`test_annot_declutter_1244.tcl`, a fixture whose only non-`@name` text carries
`hide=instance`, valued raw attached — the sheet identical at mask 1 and mask 9
(assert the SVG bytes equal), **no clause** from the `6` chord, **DC_ARM** from
Ctrl-Alt-6, **silence** from both menu doors; plus its twin with
`show_hidden_texts` on, where all four must speak.

## Decisions taken by A7's write-up agent

* **Status `[F]`, not `[E]`** — ladder **L1**, the driver's own status rule
  (*"adversary refuted"* is listed under F) and A7-a's binding driver ruling.
  *Rejected:* `[E]` on the argument that three of four parts held and the item
  already carried a legitimate status-E question (the DC_ARM wording). Rejected
  because A7-b inherits the defect, so it is two of four; because the E question
  is about wording and this is about truth; and because *"Never round a partial
  result up"* is in the same paragraph.
* **Revert, but preserve as a patch first** — ladder **L2**, smallest blast
  radius. The F rule says revert; it does not say destroy. The patch was
  dry-run-applied to a pristine `git archive HEAD` extraction of all eight files
  **before** anything was reverted, so the re-do costs one `patch -p1`.
  Precedent: `A6_working_tree_UNVERIFIED.patch`, same directory, same reason.
  *Rejected:* `git stash` (forbidden by the batch's trap 2, and it already cost
  this batch ~99 lines once); leaving the code in the tree uncommitted (the next
  crew would test a lie).
* **No rebuild after the revert** — ladder **L1**, crew rule 2 (*"ONLY the
  Implement agent may run make"*). See **the one thing the next agent must do
  first**, below. *Rejected:* rebuilding anyway to leave a consistent tree — the
  rule is categorical, and the reverted checkout leaves every source **newer**
  than the binary, so the staleness announces itself to the standard freshness
  check every Measure agent in this batch has run.
* **One issue, not five** — ladder **L2**. 1255/1256/1257/1261 stay open and each
  gains a short "A7 attempt" section pointing here, rather than five copies of
  one finding.

## The sabotage matrix, carried forward (Verify-B, `trustworthy: true`)

Eight variants ran. Six were full or over-hits; two under-hit, and only one of
those is a real hole.

| variant | predicted | observed | verdict |
|---|---|---|---|
| SB-A7a-COUNTER (C) | 11 | 9: A57 A58 A59 A60 A61 E1 E2 E8 E9 | seam load-bearing |
| SB-A7a-REFRESH-TRUE | 5 | 6: V2a V3 E4 E6 E7 E9 | over-hit |
| SB-A7a-CLAUSE-IGNORES-HID | 7 | 8: S8 S9 V1c A61 B1 E4 E6 E7 | full hit |
| SB-A7a-GATED-IGNORES-HID | 2 | 2: V2a E9 | full hit |
| SB-A7b-DOOR-SILENT | 4 | 4: A59 A60 A61 A63 | full hit |
| **SB-A7b-DOOR-UNGUARDED** | 1 (A62) | **0** | **real hole** |
| SB-A7c-WINDOW-EMPTY | 2 | 2: F50 F51 (F49 green, as designed) | full hit |
| SB-A7d-PINS-TOKEN (C) | 1 (A38b) | 1: A38b only; A36/A37/A38 green | the 1261 demonstration |

**The real hole, to be fixed in the re-do: row A62 is blind to its own
sabotage.** A62 is the stock-xschem guarantee (cadence mint renamed away, both
doors must still run and say nothing). Its driver `a7_door` wraps the invoke in
`catch {$menu invoke $idx}`, and `xschem set annot_show` runs earlier in the
`-command` body — so when the unguarded call raises, the mask is already merged
and the sentinel untouched, and all eight legs still match. Verify-B drove both
the named mutation and a coarse twin that provably raises (`raised=1`,
`invalid command name ::cadence::_annot_declutter_clause`) and A62 reported 8/8
green through both. **A62 needs a leg that asserts the invoke did not raise, or a
bgerror count.** Verify-B also corrected the Implement agent's stated mechanism
for that variant: the `info commands` guard sits above an inner `catch`, so
deleting the guard alone raises nothing at all (`raised=0`).

Three other predicted-but-absent reds were chased and are **not** coverage holes:
A61 under SB-A7a-REFRESH-TRUE (the menu door measures through a deliberately
separate `annot_declutter_say`, so a cadence-side sabotage cannot reach it —
confirmed by SB-A7a-CLAUSE-IGNORES-HID, which sabotages the *shared* mint and
does red A61); V2a and E4 under SB-A7a-COUNTER (both rows' goldens are already
"no clause", so a sabotage that suppresses the clause everywhere cannot move
them — the DC_ON half is driven by E8/E9, which did red); and V2d, which never
shipped as a row (it was folded into E9).

## Still open — the adversary's residual risks, carried in full

Everything below was measured against A7's binary. The first item is the
refutation above; the rest survive the re-do and must be answered by it.

1. **The refutation itself.** Three producers claim a declutter on any annotated
   device whose only non-`@name` texts are already suppressed. Repair above.
2. **`hid` is answered by a GEOMETRY pass, not by the screen.** On the
   counterexample sheet the split delta is bbox-only 1, redraw-only 1 — so
   `update_all_sym_bboxes` alone is enough to make the tool claim the screen
   changed. The sentence *"other device text is hidden"* is backed by a geometry
   decision. It happens to agree today; it is not the same question.
3. **A7-c's headline comment overstates its own fix.** `src/op_annot.tcl` reads
   `⚠ THE ONE-SECOND HOLE IS CLOSED -- ISSUE 1255`. Measured, it is closed for
   files ≤ 8 KiB and for changes touching the first or last 4096 bytes. The
   residue paragraph below it is accurate; the headline is what a later reader
   will quote. **The re-do must reword the headline.**
4. **A7-c's blind region grows with file size** — 82 % of a 45 KB raw (measured:
   a same-second, same-size, one-value rewrite at byte offset 29050 leaves the
   fingerprint identical at `1286397804`), 99.3 % of F35's 1.2 MB fixture. ngspice
   binary raws are same-size by construction across a re-run with the same vector
   set. Mitigation worth writing down rather than assuming: a raw large enough to
   be mostly blind usually comes from a simulation slow enough that the
   same-second window is never reached. **Widening the window reds F35's budget
   leg** (`big <= 3*small + 100`) — a full-file crc32 measures 258 µs against a
   5 µs baseline. That trade is the conversation, and it is not free.
5. **`cadence::_annot_declutter_clause` raises on a non-boolean `hid`** and no
   longer accepts its old single argument. It guards `mask` with
   `string is integer -strict` and does not guard `hid`; every shipped call path
   wraps the whole message build in `catch`, so such a caller would silently drop
   the **entire** status line, not just the clause.
6. **Two production `_annot_msg` call sites** (`utils/annot_mode.tcl:1244` and
   `:1507`) still pass four arguments and so take `hid` = 0 by default, and can
   never emit the clause. Both are refusal/unwind arms where nothing is
   annotated, so 0 is right today — but it is a defaulted contract, not a checked
   one, and the next state added to those arms inherits it silently.
7. **A38b asserts the PNG difference by FILE SIZE**, and its non-vacuity twin by
   size equality. A rendering change that preserves the compressed size passes
   both. Low probability, cheap to strengthen to a byte compare.
8. **A38b/A38c exist only on the display arm** — under `--nogui` `xschem print
   png` writes no file — so draw.c's behavioural guard vanishes on any headless
   leg. Nothing is lost today because the suite is Tk-only.
9. **`annot_declutter_count` is an `unsigned int`** and the delta test is
   `$b > $a`; on wrap the seam reports "nothing hidden" for one press. Safe
   direction, one wrong sentence.
10. **Not measured, and worth measuring in the re-do:** a text invisible for a
    reason that is *not* in `text_hidden_core`'s tail — an off-screen text, or one
    on a disabled layer. The adversary's off-screen probe (VC-21) did not
    actually move the view, so that case is untested rather than cleared.
    `View > Symbol text` off (VC-9) and instance `hide_texts=true` (VC-22) both
    correctly give delta 0.

## What A7 got right, and must not be re-derived

* **The three-state finding**, which is not in issue 1257 and is the reason the
  fix cannot be Tcl-only: on a **dead raw** (loads, annotates, publishes no
  matching vector) `op_annot::_annotated` answers 1 and `cadence::annot_mode`'s
  `state` reads `live`, identically to a valued raw, while the sheet is
  byte-identical at mask 1 and mask 9. Every Tcl-only repair fixes the no-raw
  state and goes on lying in that one.
* **The seam's shape** — a measurement taken at the rung, not a second copy of the
  gate. A Tcl twin of `annot_block_has_value` would be a second parser of
  `op_annot::text`'s block format, which is precisely how 1252 became 1260.
* **Invariant I1 held throughout** (Verify-C looked for it explicitly): no second
  raw-vector name builder; `op_annot::vector` is still the only caller of
  `_wrap`. **I4 held**: `.sch` bytes identical and `xschem get modified` 0 across
  a full chord sequence. **The eleventh `text_hidden` call site**
  (`get_annot_overlay`, actions.c:1832) is unreachable for the counter twice over
  and was driven: `annot_overlay_count` delta 1 at mask 1 and 1 at mask 9.
* **D-4 / D-5 not violated**: no `show` parse, no per-model catalogue, no
  probe-and-prune. A7-c's fingerprint reads the raw's own **bytes**, which is the
  opposite of guessing.
* **A7-d is the demonstration issue 1261 asked for** and it worked: the grep
  census could not see `if(0 && text_hidden_inst(0, n))` and the PNG row could
  (`show_pinname=true mask1=16874 mask9=16874` sabotaged, `16874/15189`
  restored), with A36/A37 green throughout.

## THE RE-DO, 2026-09-03 — what the driver actually did

The crew's judgement was right on every count and nothing had to be re-derived.
`A7_working_tree_REFUTED.patch` applied clean (`git apply --check` green, md5 as
filed), the repair below went in at A7's own edit point, and the two rows the
report asked for were written and **proved by sabotage rather than asserted**:

| sabotage | predicted | observed |
|---|---|---|
| the 1270 defect restored (unconditional `++`) | A64 red | **A64 red** — seam counts 2 not 0, chord 6 emits the clause, Ctrl-Alt-6 gives the wrong sentence |
| the tempting repair that tests only the two `HIDE_*` bits | A65 red | **A64 and A65 both red** — A65 is load-bearing exactly as predicted |

**One golden in the first draft was wrong, and the measurement was right.** A64
was written expecting the stock `Graphs` door to stay silent on the
counterexample sheet like the two chords. It does not, and it *should* not: the
menu body runs `set show_hidden_texts 1` (`src/xschem.tcl:17340`, `:17782`) one
line before it writes the mask, so on that door — and only on that door — the
`hide=instance` text really is drawn and really is taken away. The clause is
true. A64 now golden that asymmetry and reads the switch back afterwards to
prove the reason rather than assert it. **This is not issue 1256 returning:**
1256 is two doors describing the *same* state differently, and after the menu
runs the state is not the same.

The other four residual risks the report asked the re-do to answer:

* **A62's blindness — closed, and the mechanism corrected again.** `a7_door` now
  reports whether the `-command` body raised, and A62 golden `raised` 0 on both
  doors. But deleting the `info commands` guard alone still raises **nothing** —
  the call below it is already inside a `catch`, which swallows the error. The
  mutation the new legs catch is the coarse twin (guard removed *and* the inner
  `catch` unwrapped), driven and confirmed red. The guard is worth keeping; it is
  simply not the thing that keeps stock xschem quiet. **The inner catch is.**
* **A7-c's headline reworded.** `src/op_annot.tcl` said *"THE ONE-SECOND HOLE IS
  CLOSED"*. It now says **NARROWED, NOT CLOSED**, and quantifies it in the same
  breath, because the headline is the sentence a later reader quotes.
* **`_annot_declutter_clause` now guards `hid`** the way it already guarded
  `mask`. The cost of not guarding it was never a missing clause: every shipped
  caller wraps the whole message build in `catch`, so a non-boolean would have
  taken the **entire status line** with it.
* **A38b compares bytes, not file size.** A crc32 leg each way, with the length
  kept in the answer so a size-only regression stays legible in the failure text.

Carried forward unfixed, and still listed below: the geometry-pass caveat (2),
A7-c's blind region growing with file size (4), the two defaulted `_annot_msg`
call sites (6), the display-arm-only PNG guards (8), the `unsigned` wrap (9), and
the untested off-screen / disabled-layer case (10).

## The one thing the next agent must do first

**`src/xschem` (02:03:58) carries A7's C change; the reverted sources do not.**
Crew rule 2 forbade the write-up agent from rebuilding. The revert leaves every
source file **newer** than the binary, so `make -q` reports out of date — but do
not trust a measurement taken before a build. Rebuild, then verify with
`strings src/xschem | grep -c annot_declutter_count` (expect **0** on the
reverted tree, **2** once the patch is re-applied). This is batch trap 1, and it
is armed right now.
