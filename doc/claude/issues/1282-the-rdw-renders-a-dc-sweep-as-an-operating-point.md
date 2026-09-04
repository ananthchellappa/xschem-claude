# 1282 — the RDW renders a DC sweep as an operating point, and nothing on screen says so

**Filed by:** item **B3** (the Results Display Window), 2026-09-03. Found by
B3's adversary, **re-measured independently by the write-up agent** before
filing. **FILED, NOT FIXED.**

**Status:** **FIXED by item B2d, 2026-09-04** — both parts. See §"Fixed by
item B2d" at the end. Not a regression — the window is new, and this is the state
its own obligation 3 was written about, one state further in than anybody named.

---

## 1. The claim

The RDW's `ok` path prints the sentence

> Not a complete list: these are the **operating-point** columns this run saved
> for this device, not everything the device has.

over a block of numbers, **whenever the seam answers `ok`**. But the seam's
allow-list is `{op dc}`, not `{op}`. So a raw whose current slot is a **DC
transfer characteristic** answers `ok` with real point-0 numbers, and the window
presents them as an operating point. The word `dc` appears nowhere in the block.

The four non-`ok` states each get their own sentence, and `not_op` even names the
analysis it is refusing (`"The loaded results are a tran analysis, not an
operating point..."`). The `ok` path never names the analysis, although `ctx`
already carries `simtype` and `rdw::_state_sentence` already reads it.

## 2. Measured, on this binary, 2026-09-03

The mechanism, in two lines of shipped code:

* `src/ase.tcl:8803` — `} elseif {[lsearch -exact {op dc} $stp] < 0} {` — the
  seam admits `dc` alongside `op`. This is deliberate and correct: it is copied
  from `update_op()`'s own guard in `src/save.c` (see rule debt
  `1245_B1_not_op_refusal`).
* `src/rdw.tcl:213` — the `ok` arm of `rdw::_state_sentence` interpolates `$dp`
  only. `$sty` is read at `:199` and used **only** by the `not_op` arm at `:207`.

Driven end to end on a fabricated raw whose only plot is
`Plotname: DC transfer characteristic`, annotated with `xschem annotate_op <f> 0`:

```
DCPROBE sim_type = dc
DCPROBE state = ok  devices = @m.x1.m1 {{id 1.11e-05} {vth 0.75}}
DCPROBE ---- block ----
M1:/
@m.x1.m1
Not a complete list: these are the operating-point columns this run saved for this device, not everything the device has.
    id  : 1.11e-05
    vth : 0.75

DCPROBE ---- end ----
DCPROBE block-mentions-dc = 0
```

That is the whole defect: `sim_type = dc`, and the block says
*operating-point* twice (once in the sentence, once by existing at all) and
`dc` zero times.

## 3. Why it matters, and why it is not merely cosmetic

A DC sweep's **point 0** is the first step of the sweep, not the circuit's
quiescent operating point. Pasting that block into a design-review document under
a header that says "operating point" is exactly the plausible-wrong-number
failure **invariant I3** and **ruling D5-1** exist to prevent — the number is
real, it is just an answer to a different question than the heading claims.

It is also precisely the shape of the **three rendering obligations** the B3
brief made non-optional:

> **THE FOUR NON-`ok` STATES ARE FOUR DIFFERENT SENTENCES.** ... `not_op` in
> particular means the user is looking at a transient — say so and say what to do.

B3 honoured that for the four silences and added a fifth (`ok` with an empty
union). This is a **sixth**: `ok` *with* numbers, from an analysis that is not an
operating point. Nobody named it, so nobody fenced it.

## 4. Reachability

**Reachable in ordinary use.** `.dc` is a routine sweep card, an ASE deck can
enable it alongside `.op`, and once the dc slot is the current one the seam reads
it. No fabrication is needed beyond what the measurement above did for
convenience.

## 5. The fix, and the ruling it needs first

One line if the answer is "name it", in `rdw::_state_sentence`'s `ok` arm and/or
as an extra `note` line in `rdw::format_answer`:

```tcl
# when $sty is not "op", prepend/append e.g.
"These numbers come from the $sty analysis at its first point, not from a
 standalone operating point."
```

**But the wording, and whether a dc raw should be rendered at all, is a USER
decision and is unratified.** Three options, none taken here:

* **(a) render it and say so** — one extra sentence naming `dc`. Least
  surprising, keeps the seam's `{op dc}` allow-list honest on screen.
* **(b) render it silently** — what ships today. Defensible only if you consider
  a `.dc` point-0 to *be* an operating point, which it is for a `.dc` sweep whose
  source is at its nominal value and is not otherwise.
* **(c) refuse it** — answer `not_op` for `dc` too. This **contradicts** the
  seam's allow-list, which was copied from `save.c` deliberately, so it would be
  a change at B1's seam and not in the window.

Neither `doc/claude/op_param_batch/DECISIONS.md` nor
`doc/claude/specs/op_param_lists.md` mentions the `dc` arm at all (grep: zero
hits in both). This is entangled with the open rule debt
`1245_B1_not_op_refusal`, which asks the adjacent question about `tran`.

## 6. Part 2 — `rdw::sim` collapses two different refusals into one sentence

Same class, smaller. With `::rdw::sim` set to a name no backend registered,
`ase::backend_hook` raises *"unknown simulator"*, and the window says:

> Simulator `<name>` has no operating-point reader, so this window has nothing to
> show for it.

**Not registered** and **registered but declaring no `op_param_set` hook** are
different facts with different remedies, and this feature's whole obligation 3 is
that different silences get different sentences. Unreachable today (nothing sets
`::rdw::sim`); **item B5 is the first thing that will set it.**

## 7. Still open

Everything above. Nothing was changed in `src/rdw.tcl` or `src/ase.tcl` for this
issue — B3 shipped as measured, and this is filed rather than fixed because the
choice between (a), (b) and (c) is the user's and because (c) reaches into
another item's landed seam.

---

# ITEM B2a — **ATTEMPTED, MEASURED, AND REVERTED**, 2026-09-03

> **STATUS: NOT FIXED. The code below was written, verified green, and then
> REVERSE-APPLIED out of the tree.** The item's adversary pass refuted the
> batch's central claim and the write-up agent reproduced three of its attacks
> independently, so item B2a is **[F]** and `src/op_param_lists.tcl`,
> `src/rdw.tcl` and both suites are byte-identical to commit `825cd3bd`.
>
> **The work is not lost and must not be retyped.** The full 2,506-line diff is
> preserved at `doc/claude/op_param_batch/B2a_working_tree_REVERTED.patch` and
> applies clean to `825cd3bd`. The next crew's job is
> **apply + fix the named holes + re-verify**, not reconstruct.
>
> Everything below this banner is a record of THE ATTEMPT — what it changed and
> what it measured. Read it as evidence, not as a description of the tree. The
> reasons for the revert are under **"Why this was reverted"** at the end of
> this section; the three defects that forced it are in issues 1277, 1281 and
> 1284, and 1276/1278/1279/1280/1282/1283 were reverted as **collateral**,
> because a 2,506-line diff is one unit and splitting it at write-up time would
> ship a code change no verifier ever saw.

## What the attempt did (item B2a — **FIXED**, 2026-09-03, both parts. Ruling **DD-5**, option (a).)


## Part 1 — the window names the analysis

New pure `rdw::_analysis_line {ctx}` in `src/rdw.tcl`, appended by
`format_answer` as a `note` **between the device-path line and the
incompleteness line**, so a reader learns *what* the numbers are before being
told the list of them is partial.

**The gate is `$sty ne {} && $sty ne "op"`, and it fires only in state `ok` with
a non-empty union.** The empty half is not decoration: a hand-built ctx and a
failed `xschem raw sim_type` both produce `{}`, and a sentence that fired on
those would be indistinguishable from an honest one. It deliberately does **not**
fire on the fifth silence (F9 / F10_OKE), where it would put *"these numbers
come from…"* over a block with no numbers.

Option **(c)**, refusing `dc`, was not taken — forbidden by DD-5, and it would
red row **G3b** of `tests/headless/test_rdw_seam_1245.tcl`, a cross-language
fence over `save.c`'s own op/dc `strcmp`s. `src/ase.tcl:8803` is untouched.

### ⚠ DD-5's QUOTED SPECIMEN WORDING IS REFUTED; ITS DECISION IS NOT

The refuted sentence is DD-5's own:

> *"these numbers come from the `dc` analysis at its first point, not from a
> standalone operating point."*

That asserts something **false for a case `save.c` creates itself**.
`src/save.c:1073` and `:1120` both carry

```c
if(raw->npoints[...] > 1 && !strcmp(sim_type, "op")) sim_type = "dc";
```

so a **multi-point `Operating Point` plot is renamed `dc` by the reader**, and a
user who ran nothing but an operating point would be told they ran a sweep.
**Measured on this binary:** a three-point `Plotname: Operating Point` raw
answers `xschem raw sim_type` = `dc` (row Q6's second leg). `test_op_annot`'s
row T26 is exactly such a raw and must keep publishing, so the C is not moving
either.

The shipped sentence therefore names what the **loaded results call themselves**
rather than what the user ran — true in both cases, asserting nothing stronger:

> These numbers come from the first point of results xschem reports as a `<sty>`
> analysis, not as a standalone operating point. A `<sty>` sweep's first point is
> one sweep step, and xschem also reports a multi-point operating point as
> `<sty>`.

**This wording is on the owed ledger as a `rule` debt for the user**, and it is
also a `look` debt: it is new text on screen and a green suite is not an eyeball.

## Part 2 — two facts, two sentences

New `rdw::_sim_refusal {s}`. `dump_devpath` tested nothing and produced one
sentence — *"Simulator X has no operating-point reader"* — for **both** "no such
backend" and "a backend that registered without the (deliberately non-required)
`op_param_set` hook". The split tests membership in `ase::backend_names`
**before** the call, rather than parsing `ase::backend_hook`'s error string, so
there is one source of truth. `op_param_set` is deliberately absent from
`register_backend`'s required list (`ase.tcl:534`), which is what makes
"registered, no reader" genuinely reachable. **Item B5 is the first thing that
sets `::rdw::sim`, so this had to exist before B5, not after.**

## Red before green

| row | red on | green after |
|---|---|---|
| `F14` a `dc` ctx | block mentions `dc` **zero** times | the sentence, as a `note`, tags `{hdr dim note note {} …}` |
| `F15` **control** | (green before, and it is not optional) | `op` and `{}` simtypes carry no sentence, asserted as the whole block |
| `Q6` end to end, two raws | `sim_type=dc` on both, block-mentions-dc 0 | both name the analysis; the second leg is the three-point Operating Point |
| `Q7` unregistered name | *"…has no operating-point reader…"* — the wrong fact | *"No simulator named zznosuchsim is registered…"*, with the remedy, and `op_param_set` nowhere |
| `Q8` registered, no hook | same one sentence | names the hook, differs from Q7, and `::ase::backends` is restored so Q5 still sees `{ngspice}` |

Sabotage, with the fix in place:

* `SB-NO-ANALYSIS-SENTENCE` (`_analysis_line` → `{}`) → **F14, Q6 red**, `2 FAILED (41 passed)`.
* `SB-ONE-REFUSAL` (`_sim_refusal` → the old single sentence) → **Q7, Q8 red**, `2 FAILED (41 passed)`.

## Why this was reverted

**This issue's own fix was not refuted, and nothing below was measured wrong.**
It was reverted as **collateral**. Item B2a was implemented as one 2,506-line
diff across four files; the adversary pass refuted the batch's central claim on
three *other* issues — **1277**, **1281** and **1284** — and the write-up agent
reproduced all three independently before deciding. Splitting a diff that size
into a "sound" half and an "unsound" half at write-up time would have committed
a code change that no Measure, Verify-A, Verify-B or Verify-C pass had ever
seen, which is precisely the failure mode this batch has already paid for in
items B1, B2 and B3.

**The work is preserved and must not be retyped.**
`doc/claude/op_param_batch/B2a_working_tree_REVERTED.patch` applies clean to
`825cd3bd`. The next crew's job is **apply → fix the three named holes →
re-verify**, and this issue's portion should survive that pass unchanged.

---

## Item B2a-2 — REVERTED A SECOND TIME, 2026-09-03, AGAIN AS COLLATERAL

**This issue's own fix was still not refuted.** Item **B2a-2** re-applied
B2a's patch unchanged, re-fixed the three holes, added ruling **DD-6**'s display
key, and went green everywhere — store **39→71**, RDW window **32→49** headless
and **42→59** on `:99`, `test_op_annot` **485/492** and
`test_annot_declutter_1244` **134** all unmoved, audit back at the 367/12/0/2
baseline with an empty non-PASS diff.

**It was reverted anyway**, because the adversary refuted the central claim on
**1277**, **1281** and **1285** and the write-up agent reproduced **four**
attacks first-hand. Same reasoning as the first revert: the diff was one
2,838-line change across eight files, and splitting it at write-up time would
commit code no verification pass had ever seen.

**The work is preserved and must not be retyped.**
`doc/claude/op_param_batch/B2a-2_working_tree_REVERTED.patch` (md5
`1977a39e5d419d31fcbbbc3932c2606f`, 3,573 lines, eight files) **applies clean to
`849f2231`** — verified with `git apply --check` in both directions. It contains
**both** attempts: B2a's six sound fixes *and* B2a-2's re-fixes. This issue's
portion should survive the third pass unchanged; apply the patch and fix only
what §"Still open after B2a-2" in **1277**, **1281** and **1285** names.

---

# Fixed by item B2d, 2026-09-04 — both parts

**File:** `src/rdw.tcl`. Pure Tcl, no build.

## Part 1 — a DC sweep now names its analysis

**BEFORE**, measured on HEAD `21fcece6` with `simtype dc`, `state ok`:

```
M1:/
@m.x1.m1
Not a complete list: these are the operating-point columns this run saved for this device, not everything the device has.
    id  : 1.11e-05
    vth : 0.45
block-mentions-dc = 0
```

**AFTER**, the same answer and the same ctx:

```
M1:/
@m.x1.m1
These numbers come from the first point of results xschem reports as a dc analysis, not as a standalone operating point. A dc sweep's first point is one sweep step, and xschem also reports a multi-point operating point as dc.
Not a complete list: these are the operating-point columns this run saved for this device, not everything the device has.
    id  : 1.11e-05
    vth : 0.45
```

`rdw::_analysis_line {ctx}`, gated `$sty ne {} && $sty ne "op"`, appended by
`format_answer` as a `note` **between** the device path and the incompleteness
line — so a reader learns *what* the numbers are before being told the list of
them is partial. Row **F14** asserts the text and the tag list; **F15** is the
control (`op` and `{}` carry no sentence, asserted as the WHOLE block, because a
count of zero over a never-rendered string is also zero); **Q6** drives it end to
end through the real seam on two raws that both answer `sim_type = dc` — a DC
transfer characteristic, and a THREE-POINT `Plotname: Operating Point` that
`save.c:1073`/`:1120` renames itself.

### ⚠ THE SHIPPED WORDING IS NOT DD-5's SPECIMEN, AND THE STEP IS STATUS E FOR IT

Ruling **DD-5** proposes *"these numbers come from the `dc` analysis at its
first point, not from a standalone operating point"*. `src/save.c:1073` and
`:1120` both carry
`if(raw->npoints[…] > 1 && !strcmp(sim_type, "op")) sim_type = "dc";`, so a
**multi-point `Operating Point` plot is renamed `dc` by the reader** and that
sentence would tell a user who ran nothing but an operating point that they ran
a sweep. Row Q6 reproduces it on a real three-point raw. **DD-5's DECISION —
render it, and name the analysis, option (a) — is implemented unchanged; only
its specimen wording is refused, and only on a measurement.** The shipped
sentence names what the loaded results *call themselves*. On the owed ledger as
rule debt `1282_analysis_sentence_wording`.

Option **(c)**, refusing `dc`, remains forbidden: it would contradict the seam's
`{op dc}` allow-list (`ase.tcl:8803`, copied from `update_op()`'s own guard —
`int update_op()` is at **save.c:3550**, its op/dc guard at **:3780**; the crew
brief's `save.c:1988` anchor is stale) and red row **G3b** of
`tests/headless/test_rdw_seam_1245.tcl:879`, a cross-language fence over
save.c's two strcmps. That suite is unmoved at 49.

## Part 2 — two facts, two sentences

**BEFORE**, driven through the real binary: an unregistered simulator and a
backend registered with the five required hooks but no `op_param_set` produced
**the same sentence modulo the name**:

```
unknown-simulator  : Simulator <NAME> has no operating-point reader, so this window has nothing to show for it.
registered-no-hook : Simulator <NAME> has no operating-point reader, so this window has nothing to show for it.
IDENTICAL = 1
```

**AFTER**: `IDENTICAL = 0`.

```
No simulator named zznosuchsim is registered, so there is nothing to ask for this device. Check the name, or register a backend for it with ase::register_backend.
Simulator zzhookless is registered but declares no operating-point reader - the op_param_set hook - so this window has nothing to show for it. A backend adds that hook to publish operating-point columns.
```

**L1 / invariant I1 (one source of truth).** `rdw::_sim_refusal` asks
`ase::backend_names` for MEMBERSHIP **before** calling `ase::backend_hook`,
rather than parsing the hook's error string. *Rejected:* `string match` on the
error text, which couples this window's wording to another file's wording and
breaks silently when either moves. `ase::backend_hook` already mints two
distinct errors — `ase.tcl:550` *"unknown simulator"* and **`:553`** *"unknown
hook"* (the preserved patch's comment said `:552`; corrected in both the shipped
comment and the suite's). `op_param_set` is deliberately **not** on
`register_backend`'s required list (`ase.tcl:534`), so *"registered, no reader"*
is genuinely reachable. Rows **Q7** and **Q8**; Q8 restores `::ase::backends` so
`backend_names` is `{ngspice}` again and row Q5 still passes.

**This had to land before B5**, which is the first thing that sets `::rdw::sim`.

## Sabotage

* `_analysis_line` → `{}` reds **F14** and **Q6**, and nothing else.
* `_sim_refusal` → HEAD's one collapsed sentence reds **Q7** and **Q8**.

## Still open

* **1298** — the analysis sentence is a property of `rdw::dump`, which sets
  `simtype`, and **not** of `rdw::dump_devpath`, the door items B4 and B5 call.
  A caller that builds its own ctx gets the pre-DD-5 render back, silently.
  Latent today; filed with the measurement and a one-line recommended fix.
* The wording itself is the user's: rule debt `1282_analysis_sentence_wording`.
