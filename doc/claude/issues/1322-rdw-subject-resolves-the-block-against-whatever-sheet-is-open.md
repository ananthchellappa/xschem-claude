# 1322 — `rdw::_subject` resolves the block against whatever sheet is open, so a button edits a device the user is not looking at

**Status:** **FIXED** by item **B5-a**, 2026-09-04 (was: FILED, NOT FIXED). **This is the defect that reverted item B5-2.**
Measured 2026-09-04 on `fluid-editing` at `c940a5df` + item B5-2's working tree
(preserved as `doc/claude/op_param_batch/B5-2_working_tree_REFUTED.patch`, md5
`42890cf163dd9ba1e85e312e1801c6ed`).
**Component:** `src/rdw.tcl` — `rdw::_hdr_instname`, `rdw::_subject`,
`rdw::push` / `rdw::render_pane`.
**Related:** issue **1314** (B5's own wrong-scope findings A6/A7), ruling
**DD-7** (a write touches one tier's own file), issue **1300** (the three key
lists), issue **1311**.

## The mechanism

`rdw::header` builds a block header as `"<instname>:<cadence path>"`.
`rdw::_hdr_instname` regexps it back:

```tcl
proc rdw::_hdr_instname {line} {
    if {[regexp {^(.*):(/.*)$} $line -> nm path]} { return $nm }
    return {}
}
```

It captures **both** halves and returns only the first. `rdw::_subject` then
re-resolves that bare name against the live editor:

```tcl
catch {set type [::op_annot::type $inst]}
catch {set cell [xschem getprop instance $inst cell::name]}
```

Both answer about **whatever schematic is open now**, not the schematic the
block was dumped from. Nothing clears `::rdw::blocks` on a load — `keep_latest`
(key 4) is the only writer that ever shortens the list — so a block outlives the
sheet it describes.

`M1` is the default `template="name=M1 …"` of every device symbol in this tree,
so two sheets holding an `M1` is the *ordinary* case, not a contrived one.

## The measurement

Reproduced independently by B5-2's write-up agent through the real `rdw::header`
and `rdw::push`; no hierarchy needed, both sheets top-level.

```
SHEET A: M1 type=vndev cell=vn.sym
HDR=M1:/
SHEET B: M1 type=vpdev cell=vp.sym  blocks=1
SUBJECT of the block on screen = instname M1 type vpdev class pcls cellname vp.sym
SAY=<Delete: removed gm from the annotation list for class pcls.>
NCLS(the sheet the block came from) owns=0
PCLS(the sheet now open)            owns=1 list={id ids 0} {gds gds 1}
```

The pane shows a block about an `ncls` device. The user presses Delete. The
button edits **`pcls`**, a class belonging to a device on a different sheet,
**reports success naming the wrong class**, and leaves the device on screen
untouched. Confirmed a second time with a real subcircuit fixture (header
`M1:/X1/`, pmos inside `X1`, nmos at top): the top-level `M1`'s class is edited.

This is the exact failure `_subject`'s own comment claims to prevent. B5-2 closed
the **block-index** axis (rows BT10/BT21/SD3, and `SAB-SUBJECT` reds eight rows)
and left the **sheet** axis wide open.

## ⚠ THE OBVIOUS FIX IS REFUTED — MEASURED, SO NOBODY SPENDS A RUN ON IT

Issue 1314's successor and B5-2's own adversary both proposed the same *"minimum
honest fix"*: have `_subject` compare `[rdw::_cadence_path [xschem get sch_path]]`
against the header's discarded path half and refuse on a mismatch.

**It does not catch the reproduction above.** Both sheets are top-level, so
`sch_path` is `.` on both and the header path half is `/` on both:

```
A: sch_path=<.> cadence=</> hdr=<M1:/>
B: sch_path=<.> cadence=</> hdr=<M1:/>      PATHS_EQUAL=1
```

The guard sees equal paths and waves the wrong-device edit straight through. The
axis is **sheet identity**, not hierarchy path. A path check would close only the
subcircuit variant and would read, in every review afterwards, as though the
whole defect were fenced.

## Recommended fix

**`rdw::push` captures the subject at dump time** — `type`, `class`, `cellname`
and the schematic file — into the block itself, and `rdw::_subject` reads it back
instead of re-resolving anything. The block already carries its own header line;
the subject belongs beside it. This is the same principle B5-2 already applied
when it chose to derive the subject from the block rather than build a parallel
`::rdw::subjects` list (invariant **I1**) — it simply was not carried far enough:
the block stores a *rendering* of the subject and then re-derives the *identity*.

Rejected alternatives:

* **Compare the cadence path** — refuted above by measurement.
* **Clear `::rdw::blocks` on every schematic load** — throws away the user's
  history for a problem that is about identity, and key 4 (`keep_latest`)
  already means the pane is expected to outlive individual dumps.
* **Refuse to act unless exactly one block is present** — makes the common
  multi-dump workflow unusable and still gets the single-block case wrong.

## The adjacent hole in the same guard

`op_param_lists::class` returns the **token** when the token has no class
mapping. So a symbol xschem cannot find (type `missing`) passes
`rdw::button`'s `class eq {}` guard and the user is told
*"Delete: gm is not in the missing annotation list."* Found incidentally while
building the hierarchy fixture. The capture-at-dump-time fix closes this too, if
`push` refuses to record a subject whose class did not resolve.

## Still open

Everything here. Nothing was fixed; item B5-2 was reverted in full and the tree
is back at baseline (window 76/86, store 102, keys 35).


---

## FIXED — item B5-a, 2026-09-04

**`src/rdw.tcl` only. No build; the file is sourced at startup.**

`rdw::push` now CAPTURES the subject at DUMP TIME, from the block's own header
text and the sheet that is still open, and stamps it into the block's **header
entry as a third element**:

```
{hdr M1:/ {instname M1 type bs_ndev cellname .../vn.sym schname .../a.sch}}
```

Five new procs, all in `src/rdw.tcl`:

| proc | what it is |
|---|---|
| `rdw::_hdr_instname {line}` | the exact inverse of `rdw::header`'s join. **MOVED HERE from `B5-2_working_tree_REFUTED.patch` and DELETED there** — it was defined twice and the last definition silently won. |
| `rdw::_subject_resolved {type}` | 1 when a `type=` token may be recorded: non-empty and not the literal `missing`. |
| `rdw::_capture_subject {block}` | the capture. Every read caught. |
| `rdw::_stamped {block}` | 1 when the block already carries a subject; a re-push never re-captures. |
| `rdw::block_subject {block}` | **the one reader of where the stamp lives, and a pure function of its argument** — it reads no namespace state, so the three suites that assign `set ::rdw::blocks {}` directly cannot desync it. |

`rdw::dump_devpath` now ends `return [rdw::push $blk]`, so the value handed back
is the value stored.

**What did NOT change, by construction:** the block is still ONE FLAT LIST OF
ENTRIES, so `llength $b` is still the block's line count (`rdw::_locate` and the
patch's `BE0`/`BT3` use it as one), `rdw::block_text` is byte-identical (it reads
`lindex $e 1`), and `render_pane` paints the same number of lines. A parallel
`::rdw::subjects` list was rejected: it would have **three** writers to keep
aligned — `push`, `keep_latest`, and the suites — and a desynced one answers
about the wrong block while every existing row stays green.

**The class is deliberately NOT captured.** `op_param_lists::class` is a pure
classmap lookup with no sheet dependence, so it keeps its single home
(invariant I1); only the `type=` token is sheet-dependent. This also keeps
`src/rdw.tcl` naming the `op_param_lists::` namespace ZERO times, which rows
**S1** and **K11** gold. The patch's `rdw::_subject` derives the class from the
captured type.

**The adjacent hole is closed at capture time.** A symbol xschem cannot find
answers `op_annot::type` = the literal `missing` (xschem's own placeholder,
`systemlib/missing.sym`, `save.c:7281`, the token `descend_missing_sym` guards
by name at `actions.c:6049-6063`), and `op_param_lists::class missing` returns
that TOKEN by contract — so a consumer's "class is empty" guard would wave it
through and the user would read a sentence naming a class no PDK ever mapped.
`push` records NO subject for it, and blank is available here and nowhere later.
**Stated cost:** a user-authored symbol that really exists on disk and really
declares `type=missing` gets no captured subject either.

### Fenced by

* window `BS0`..`BS5` (both arms), `BS6` (:99) — the two-sheet repro reproduced
  and closed, the path guard's refutation written down so nobody re-proposes it,
  the stamp invisible to paste / line count / pane, a re-push that neither
  re-stamps nor re-resolves, the adjacent hole, and the one-structure fence.
* keys `KS1` (:99) — the capture through the REAL keybinding, plus a second
  top-level sheet loaded afterwards. ⚠ The row's first draft **did not red**
  under sabotage `SAB-RESOLVE-LATE`, because `check` evaluates its arguments when
  it is CALLED and the original sheet had already been restored; the legs are now
  snapshotted while the other sheet is open. Recorded because it is exactly the
  failure this item exists to break.

### Sabotage receipts (all on a COPY of the tree, restored by `cp`, md5-verified)

| variant | red |
|---|---|
| `SAB-RESOLVE-LATE` (the shipped defect restored exactly) | window `BS1 BS1b BS2 BS3 BS4`; keys `KS1` |
| `SAB-STAMP-DROPPED` | window `BS1 BS1b BS3 BS5`; keys `KS1` |
| `SAB-RESTAMP` | window `BS3` |
| `SAB-STAMP-MISSING` | window `BS4` |

### Still the user's, recorded as a rule debt

`schname` is captured but **nothing refuses on it**: a block dumped from another
sheet still edits a well-defined class list, and refusing would break the
multi-sheet review workflow this window exists for — the same reason this issue
rejects clearing `::rdw::blocks` on load. **Should the status line say which
sheet a block came from when it is not the sheet on screen, and should it ever
refuse?** Not implemented; the captured value exists so item B5-3 *can* say it.

### The adversary's receipts, and one prediction that did NOT fire

Verify-C re-ran the **whole two-sheet repro through the real consumer** on a
patched copy (patch applied, nothing extracted, nothing stubbed) and could not
reproduce the defect: `SAY=<removed gm from the annotation list for class
ncls>`, `NCLS_LIST` lost `gm`, `PCLS_LIST` intact with `PCLS_OWNS=0`, and
`_apply_now` moved `vndev`'s `shown` while `vpdev`'s stayed `NOKEY`. It also
added two sabotage variants this item had not tried:

| variant (adversary's own) | red |
|---|---|
| `push` drops the TAG in its `lreplace` (the most plausible future slip) | 6 rows including `K8` and `BS2` — the paste/pane shape is genuinely fenced |
| `_subject_resolved` returns 1 for `missing` (the adjacent hole reopened) | `BS4`, alone |

⚠ **`SAB-RESTAMP` was predicted to red `BS2` and did not, and the PREDICTION was
wrong rather than the fence.** `rdw::push` rebuilds the header entry as
`[list <tag> <text> $subj]`, discarding any existing third element, so a
re-stamp keeps the arity at exactly 3 forever and `BS2`'s 2-vs-3 leg cannot
observe re-stamping. `BS3` covers the mechanism, and its failure line is the
receipt: got `{3 bs_pdev vp.sym b.sch 1}` against `{3 bs_ndev vn.sym a.sch 1}`
— arity unchanged, identity wrong. **Correct the prediction to `BS3` alone; do
not "fix" `BS2`.**

### Still open — carried risks the adversary named

* **`rdw::_stamped` is an ARITY test only** (`llength $e >= 3`). If a later
  change adds a third element to the header entry for some other purpose, the
  capture silently stops happening for every block and `block_subject` returns
  a non-dict. It is safe today only because `rdw::_subject`'s `dict get`s are
  caught. **No row asserts that the third element is a dict carrying the four
  expected keys** — a cheap row for item B5-3 to add.
* **A stamp is forever, deliberately.** After the device is renamed or deleted
  the block still edits the class it was dumped about, and after the classmap is
  re-registered the class is re-derived from a captured type that may no longer
  be the instance's. Both follow from *"a block records what it was about"* and
  both are the intended behaviour — recorded here because neither was written
  down as a consequence anywhere.
* **`schname` is captured and nothing reads it.** The sheet-identity axis — the
  whole point of this fix — is recorded but never compared, so the user still
  gets no indication which sheet a button changed, and the sheet on screen
  redraws unchanged. That is the rule debt above; until it is ruled, the visible
  behaviour of a cross-sheet edit is *"the button did something you cannot
  see"*.
