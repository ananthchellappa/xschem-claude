# 0475 — S10: the 40 shipped sky130 FET symbols' annotation texts are gated behind `hide=true`

Status: IMPLEMENTED (S10b). Carries one **E** question — see §7.
Spec: `doc/claude/specs/op_annotation.md` (S10). Related: 0428, 0457, 0476.

## 1. What changed

119 T records in 40 files under `sky130A/xschem_libs/sky130_fd_pr/*/symbol/*.sym`
gained one token in their **attribute** brace group:

```
-T {id=@spice_get_node i(\\@m.@path@spiceprefix@name\\.msky130_fd_pr__@model\\[id])} 30 -30 0 0 0.15 0.15 {layer=17}
+T {id=@spice_get_node i(\\@m.@path@spiceprefix@name\\.msky130_fd_pr__@model\\[id])} 30 -30 0 0 0.15 0.15 {layer=17
+hide=true}
```

Nothing else in those files moved: no text group, no geometry, no layer.
The two-line attribute spelling is the one already shipped by
`gf180mcuD/xschem_libs/gf180mcu_pr/nfet_03v3/symbol/nfet_03v3.sym:64-70`
(`{layer=15\nhide=true}`) and by the S6b carrier
`xschem_library/devices/annotate_params.sym:10-12`.

## 2. The measured inventory (counted, not assumed)

The step brief guessed "~40 symbols / 160 texts"; both halves needed correcting.

| | measured |
|---|---|
| sky130 files carrying annotation texts | **40**, all under `sky130_fd_pr/*/symbol/` (of 77 in that library, of 724 `.sym` in all of `sky130A`) |
| T records | **119**, not 160 — `vgs=` and `vds=` share **one** record spanning two lines |
| split | 40 `id=` + 40 `gm=` + 39 `vgs=`/`vds=` |
| per file | 39 files × 3 records; `nfet_20v0_iso` × 2 (no vgs/vds record) |
| attribute tails | 40 × `{layer=17}` (the id records) + 79 × `{layer=15}` (40 gm + 39 vgs/vds) = 119 |
| pre-existing `hide=` in all of sky130A | **1**, unrelated: `sky130_tests/diff_amp/symbol/diff_amp.sym:35` `hide=instance` |

Because 40 + 79 = 119 exactly, no other text in those 77 files ends in a
`layer=15`/`layer=17` tail, which is what makes the edit's anchor unambiguous.

## 3. THE TOKEN IS `hide=true`, NOT `hide=op` — the plan's D2 was refuted by measurement

The S10 plan asked for the S7 class token `hide=op`. It was implemented on all 40
files, measured, and reverted, because **it does not deduplicate**.

`text_hidden()` (`src/actions.c:1194`) gates a `hide=op` TEXT on `annot_show` bit0:

```c
if(flags & HIDE_TEXT_OP) return (xctx->annot_show & ANNOT_SHOW_OP) ? 0 : 1;
```

and `get_annot_overlay()` (`src/actions.c:1475`, decision D2) gates the **whole
overlay** on the *same* bit:

```c
if(text_hidden(HIDE_TEXT_OP, TEXT_CTX_INSTANCE)) return 0;
```

So a symbol text tokened `hide=op` becomes visible **exactly when the overlay that
is supposed to replace it becomes visible**. Measured on this tree, on the real 40
files, 10 FETs in the viewport `{1800 1200 100 -700 1800 -100}` of the shipped
`sky130_tests_ase/test_nmos`, `sky130_procs.tcl` sourced (`sym` = the four symbol
spellings, `ovl` = the overlay's rows):

| token | mask0 sht0 | mask1 sht0 | mask3 sht0 | mask0 sht1 | mask1 sht1 |
|---|---|---|---|---|---|
| (shipped) | sym10 ovl 0 | sym10 ovl10 **(!)** | sym10 ovl10 | sym10 ovl 0 | sym10 ovl10 |
| `hide=op` | sym 0 ovl 0 | sym10 ovl10 **(!)** | sym10 ovl10 | sym 0 ovl 0 | sym10 ovl10 |
| `hide=true` | sym 0 ovl 0 | sym 0 ovl10 | sym 0 ovl10 | sym10 ovl 0 | sym10 ovl10 |

`hide=op` removes the double-printing only at the mask where nothing is drawn at
all, and leaves it intact at exactly the two masks where the step says it must go
away.

**Ruling — ladder L1, invariant I1** ("ONE name builder, TWO consumers; never two
independent builders, because when they drift the failure is SILENT"). The
symbol's own text is a third, independent builder of the same vector names — test
row D8's header says so, and issue **0428** is that drift already realised: one
shipped symbol (`pfet_g5v0d16v0_nf`) whose builder disagrees with the other 39 and
has always rendered blank. I1 is satisfied only by the row of that table in which
the two builders are never both painting: `hide=true`.

**Second ground — ladder L2** (least surprising, smallest blast radius):
`hide=true` is the spelling gf180 already ships for exactly this content, so after
S10 the two PDKs behave alike instead of three ways; it is data-only, so no C
moves and section L's S7/S9b goldens stay put; and it leaves the legacy numbers
one stock menu item away (View > Show hidden texts, `src/xschem.tcl:15050`) for
the user who gets no overlay at all — see §7.

**Rejected**

* `hide=op` as planned — measured above; does not deliver the step.
* `hide=voltage` on the 39 vgs/vds records — same defect, one mask further out:
  `get_annot_overlay` gates the whole block including its own vgs/vds rows on bit0,
  so the duplication would return at mask 3 and nowhere else. Test row Q6.
* Changing `text_hidden()` / `get_annot_overlay()` so the class means "superseded
  BY the overlay" — real C surgery outside a step declared ZERO LOGIC, it would
  move section L's goldens, and S7 decision D3 (classes tested ahead of
  `show_hidden_texts`) was ratified deliberately.

## 4. The editing script — reproducible and reversible

Run as `tclsh s10_hide.tcl <repo> add hide=true`; the exact reverse is
`... strip hide=true` (verified byte-for-byte: after add-then-strip
`git status --short -- sky130A` is empty). Reverting the commit works too and is
stronger. Whole-file and record-anchored, never line-oriented — the vgs/vds record
is ONE T record spanning TWO lines whose attribute group sits at the end of the
SECOND, so a per-line pass would either double-add or land the token inside the
text group and corrupt the record. Idempotent by construction: after the edit the
tail is `{layer=17\nhide=true}`, which the `\{layer=17\}` anchor can no longer
match. It also refuses outright any record that already carries a `hide=` token,
and asserts 40/40/39 = 119 before it is believed. **Verified by running `add`
twice**: the second run changes 0 files, reports all 119 records as
`SKIP (already tokened)`, and exits 1 — no double token anywhere
(`grep -c hide=true nfet_01v8.sym` stays 3).

```tcl
#!/usr/bin/env tclsh
# S10b -- gate the shipped sky130_fd_pr FET annotation texts behind a hide= token.
# Usage:  tclsh s10_hide.tcl <repo> add hide=true
#         tclsh s10_hide.tcl <repo> strip hide=true
set repo  [lindex $argv 0]
set mode  [lindex $argv 1]
set tok   [lindex $argv 2]
if {$repo eq {} || $mode ni {add strip} || ![string match hide=* $tok]} {
  puts stderr "usage: s10_hide.tcl <repo> add|strip hide=<class>" ; exit 2
}
# {kind whole-record-pattern-up-to-the-attribute-tail layer}
set RECS {
  {id  {\nT \{id=@spice_get_node[^\}]*\}[^\{]*\{layer=17}  17}
  {gm  {\nT \{gm=@spice_get_node[^\}]*\}[^\{]*\{layer=15}  15}
  {vgs {\nT \{vgs=expr\([^\}]*\}[^\{]*\{layer=15}          15}
}
array set n {id 0 gm 0 vgs 0}
set nfiles 0 ; set nskip 0
foreach f [lsort [glob -nocomplain [file join $repo sky130A xschem_libs sky130_fd_pr * symbol *.sym]]] {
  set fd [open $f r] ; fconfigure $fd -translation binary ; set d [read $fd] ; close $fd
  set orig $d
  foreach r $RECS {
    lassign $r k pat lay
    if {$mode eq "add"} {
      foreach m [regexp -all -inline "${pat}\[^\\\}\]*\\\}" $d] {
        if {[string first hide= $m] >= 0} {
          puts stderr "SKIP (already tokened): [file tail $f] $k" ; incr nskip
        }
      }
      set c [regsub -all "(${pat})\\\}" $d "\\1\n$tok\}" d]
    } else {
      set c [regsub -all "(${pat})\n$tok\\\}" $d "\\1\}" d]
    }
    incr n($k) $c
  }
  if {$d ne $orig} {
    set fd [open $f w] ; fconfigure $fd -translation binary ; puts -nonewline $fd $d ; close $fd
    incr nfiles
  }
}
set total [expr {$n(id) + $n(gm) + $n(vgs)}]
puts "$mode $tok : id=$n(id) gm=$n(gm) vgs=$n(vgs)  total=$total  files=$nfiles  skipped=$nskip"
if {$total != 119 || $n(id) != 40 || $n(gm) != 40 || $n(vgs) != 39 || $nskip != 0} {
  puts stderr "ASSERTION FAILED: expected 40/40/39 = 119 records and 0 skips" ; exit 1
}
exit 0
```

Observed output: `add hide=true : id=40 gm=40 vgs=39  total=119  files=40  skipped=0`.

## 5. Acceptance, restated (the brief's is unsatisfiable by construction)

The brief asked for "with `annot_show` 0, a sky130 schematic looks EXACTLY as it
did before this whole plan started — an SVG or PS export diffed byte-for-byte
against one taken at the pre-plan commit". That cannot pass and must not be
attempted: at `annot_show` 0 those texts render **today** (measured 77134 bytes,
10× each on the fixture), so any `hide=` token makes mask 0 strictly emptier —
that *is* the change. The plan file's own S10 section already carries a warning
block saying so. Reaching a pre-plan commit would also need a detached checkout,
which this run's hard rules forbid.

Substituted, both runnable against the current binary and both now executable test
rows in `tests/headless/test_op_annot.tcl` section Q:

1. **Q3** — at `annot_show` 0 the export no longer contains the four symbol
   spellings (10,10,10,10 → 0,0,0,0), and **Q5** proves the exporter still drew.
2. **Q4** — at `annot_show` 1 each label is painted **once** per FET where it was
   painted twice: symbol spellings 0, overlay rows 10.

## 6. What was deliberately NOT touched

* **gf180's 38 `hide=true` records in 19 files** — invariant I7, and row L22 is the
  tree's only non-vacuous fixture for I7's `hide=true` half; converting them would
  destroy the guard and the thing it guards in one edit. Row **Q8** is the
  file-level tripwire.
* **IHP's two `@spice_get_current` inductor texts, IHP's `annotate_fet_params`
  carrier, and 19 ungated `xschem_library/devices/*.sym`** — filed as **0476**.
* **`pfet_g5v0d16v0_nf`'s wrong inner-device spelling** — already issue **0428**,
  and row P7's golden names the file, so it is tokened like every other record and
  otherwise left alone. Worth recording that S10 is a net *fix* there: that text
  has always rendered blank (invariant I3), so hiding it loses nothing.

## 7. ⚠ THE E QUESTION (ladder L3 — user-visible, no prior ratification covers it)

S10 makes 40 shipped sky130 FET symbols annotation-silent by default. Measured,
the users split in two:

* **With `sky130A/cadence_style_rc`** (which sources `sky130_procs.tcl` at :71) the
  descriptor registers for `nmos`/`pmos`, all 40 symbols match
  `match {*sky130_fd_pr/*}`, and at mask 1 the overlay paints a ten-row **superset**
  (id gm gds vth vdsat cgg vgs vds ft gm/id) of the four. Strictly better, one
  keystroke away.
* **Without it** `op_annot::descriptor nmos` returns EMPTY (note `op_annot::register`
  itself still exists, so probing the *proc* is a false positive — probe the
  descriptor's content), no overlay fires at any mask, and the `id=12.34u` /
  `gm=567.8u` that appeared whenever a raw was loaded are gone.

**The question, verbatim for the ledger:** *"S10 makes 40 shipped sky130 FET symbols
annotation-silent unless View > Show hidden texts is on. For a user whose rc never
sources sky130_procs.tcl the overlay never fires, so at every annot_show value this
is pure subtraction unless they find that menu item. Ratify one of: (a) ship as
implemented and accept show_hidden_texts as the escape hatch — the state gf180's 19
symbols have shipped in all along; (b) have op_annot ship a built-in fallback
registration for sky130_fd_pr so the overlay fires without cadence_style_rc;
(c) default annot_show to 1, which S8 decision D9 explicitly rejected."*

**This crew implemented (a).** Two facts mitigate but do not settle it: with no raw
loaded the shipped texts render as pure noise (`id=-  gm=-  vgs= -  vds= - `), so the
loss bites only once a raw is loaded; and the `hide=true` ruling of §3 is what
*creates* the escape hatch — under the planned `hide=op` there would have been none,
because S7 decision D3 puts the class bits ahead of `show_hidden_texts` on purpose.
Issue **0457**'s residual (outside the cadence profile there is no stock affordance
for the mask at all) must be settled before (b) or (c) can even be evaluated; S10
sharpens it from "a carrier symbol nobody has placed yet" to "40 shipped sky130 FET
symbols in every sky130 design".

## 8. Evidence

* `./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_op_annot.tcl`
  → `RESULT: ALL PASS (218 checks)` (baseline 209 + the 9 new Q rows).
* `GUI_GATE=0 xvfb-run -a ./src/xschem --pipe -q --nolog --script tests/headless/test_op_annot.tcl`
  → `RESULT: ALL PASS (223 checks)` (baseline 214 + 9).
* `tests/headless/run.sh` → `== HARNESS: PASS ==`, 6/6.
* No build: the change is data + test + docs only; `src/xschem` is untouched.

## 9. The BEFORE state, verbatim from the Measure agent's transcript

The capability was measurably absent — both halves of the step's premise
reproduced before a byte was edited.

```
$ grep -n -E 'id=|gm=|vgs=|vds=' sky130A/xschem_libs/sky130_fd_pr/nfet_01v8/symbol/nfet_01v8.sym
63:T {id=@spice_get_node i(\\@m.@path@spiceprefix@name\\.msky130_fd_pr__@model\\[id])} 30 -30 0 0 0.15 0.15 {layer=17}
64:T {gm=@spice_get_node \\@m.@path@spiceprefix@name\\.msky130_fd_pr__@model\\[gm]} 30 -10 0 0 0.15 0.15 {layer=15}
65:T {vgs=expr(@#1:spice_get_voltage - @#2:spice_get_voltage )
66:vds=expr(@#0:spice_get_voltage - @#2:spice_get_voltage )} 5 17.5 0 1 0.07 0.07 {layer=15}

$ grep -rn 'hide=' sky130A/ --include='*.sym'
sky130A/xschem_libs/sky130_tests/diff_amp/symbol/diff_amp.sym:35:order in the verilog-A file.} -30 -70 0 0 0.1 0.1 {hide=instance}

=== T records total that begin with id=/gm=/vgs= (the record count) ===
119
=== per-file record counts (T records starting id=/gm=/vgs=) ===
  files with 2 records: 1
  files with 3 records: 39
  non-3 files: nfet_20v0_iso.sym
=== attribute-tail shapes on the 119 records (last brace group) ===
     79 {layer=15}
     40 {layer=17}

$ grep -n 'annot_show' src/xschem.tcl
15981:set_ne annot_show 0

BEFORE-4 annot_show=0 svg_bytes=77134 id=x10 gm=x10 vgs=x10 vds=x10
BEFORE-4 annot_show=1 svg_bytes=92119 id=x10 gm=x10 vgs=x10 vds=x10
BEFORE-7 STOCK-RC annot_show=0 svg_bytes=77134 id=x10 gm=x10
BEFORE-7 STOCK-RC annot_show=1 svg_bytes=77134 id=x10 gm=x10
BEFORE-7 STOCK-RC annot_show=3 svg_bytes=77134 id=x10 gm=x10

=== rendered text strings, annot_show=1 ===
     10 vgs= -            <- the shipped symbol text
     10 vgs   =           <- the S9b overlay, same quantity
     10 id=-
     10 id    =
     10 gm=-
     10 gm    =
     ... (gds vth vdsat cgg vds ft gm/id, all x10)

BEFORE-10 sky130_procs.tcl SOURCED + RAW LOADED, annot_show=1 bytes=6817
   TEXT: id=12.34u
   TEXT: gm=567.8u
   TEXT: id    = 12.34u
   TEXT: gm    = 567.8u

$ ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_op_annot.tcl
RESULT: ALL PASS (209 checks)
```

The `BEFORE-7` triple is the sharpest line: the export is byte-identical at
`annot_show` 0, 1 **and** 3 with the four texts painted 10× at every one of them.
They carried no token and answered to no knob.

### AFTER, same commands, same tree

```
$ ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_op_annot.tcl
RESULT: ALL PASS (218 checks)
$ GUI_GATE=0 xvfb-run -a ./src/xschem --pipe -q --nolog --script tests/headless/test_op_annot.tcl
RESULT: ALL PASS (223 checks)
$ tests/headless/run.sh
== HARNESS: PASS ==            (6/6 goldens)
$ cd tests && tclsh run_regression.tcl
3 FAIL-at-EOL / 0 GOLD? / 0 RESULT? / 0 FATAL     (the documented floor: 0420, 0421)

add hide=true : id=40 gm=40 vgs=39  total=119  files=40  skipped=0
```

Verify-C additionally built a pre-change mirror of `sky130A` from
`git show HEAD:<path>` for the 40 originals and diffed the rendered-text
histograms symmetrically. The mirror reproduced the baseline exactly
(77134 / 92119 / 81504 bytes); at `show_hidden_texts 0` the **only** difference at
masks 0, 1 and 3 is the removal of `id=-` ×10, `gm=-` ×10, `vgs= -` ×10,
`vds= -` ×10, and the non-text SVG line count is identical (579 vs 579) — no
geometry, no bbox moved. The PostScript back end agrees with the SVG one
(10/10/10/10 → 0/0/0/0 at sht 0), the SPICE netlist is byte-identical apart from
the `** sch_path:` header naming the two source trees, and all 40 symbols
load-and-re-save with the token intact.

## 10. Sabotage matrix — 7 variants, 7 detected

| variant | what it does | predicted red | observed |
|---|---|---|---|
| **SAB-1** null-edit | strip all 119 tokens; tree byte-identical to HEAD | Q1 Q2 Q3 Q4 Q6 Q7 | **5 red** — Q1 Q2 Q3 Q4 Q6 (Q7 did not fire, see below) |
| **SAB-2** wrong-token | `hide=op` on all 119 — *the token the plan called for* | Q1 Q2 Q7 | **5 red** — Q1 Q2 Q4 Q6 Q7 |
| **SAB-3** partial corpus | only the 40 `id=` records tokened | Q1 Q2 Q3 Q4 Q6 | **5 red**, exact match |
| **SAB-4** voltage class | the 39 vgs/vds records get `hide=voltage` | Q1 Q2 Q6 | **4 red** — + Q7 |
| **SAB-5** gf180 collateral | rewrite gf180's 38 `hide=true` → `hide=op` (what this plan section literally asked for) | Q8 + **L22**, Q2 *not* red | **2 red**, exactly as predicted: Q8 `{0 38 0}` at file level, L22 `{0 0 0 0 0}` at render level — all five terms at once |
| **SAB-6** text-group corruption, vgs leg | naive per-line pass lands the token inside the two-line record's **text** group | Q1 Q2 Q3 Q4 Q6 | **4 red** — Q2 did not fire (see below) |
| **SAB-6b** same, all three legs | the conditional prediction, run | D8/D8b/P7 | **8 red** — all three plus Q1 Q2 Q3 Q4 Q6; P7's outlier list explodes from `{40 pfet_g5v0d16v0_nf.sym}` to all 40 filenames |

**SAB-2 independently reproduces the §3 ruling.** Under `hide=op` the symbol texts
paint at mask 1 alongside the overlay — Q4 and Q6 red — i.e. the duplication
survives exactly where the step must remove it. That is the refutation arriving a
second time, from a different direction.

### Predicted reds that did NOT appear

* **SAB-1 / Q7 — stale prediction, not a coverage loss.** The sabotage list was
  written against the *planned* `hide=op`, where Q7 asserted the four texts stay
  hidden even at `show_hidden_texts 1`. The §3 ruling inverted Q7 to assert what
  `hide=true` actually does (the texts **return**, the overlay stays off), and
  nobody updated the variant's prediction. Untokened text is equally visible at
  mask0/sht1, so Q7 is now structurally blind to the null edit. The mechanism is
  covered 5× over by Q1/Q2/Q3/Q4/Q6, all of which fired.
* **SAB-6 / Q2 — a genuine blind spot in the check as written.** Q2 counts
  `hide=[A-Za-z0-9_]+` over whole **file text**, so a token that *migrates* from a
  record's attribute group into that same record's text group is
  **count-conserving and invisible**: 80 attribute-group + 39 injected in-text =
  119, exactly Q2's golden, while 39 records were corrupt. Q2's own comment
  ("a stray token landing on an unrelated record has to show up somewhere, and this
  is the somewhere") is true only when the token **adds** to the census — SAB-6b,
  where Q2 did fire at 158. The mis-anchoring is still caught 4× by Q1/Q3/Q4/Q6, so
  no mechanism escaped detection, but the comment should be narrowed if Q2 is ever
  reused for another PDK.

## 11. Still open

Measured by the adversary pass and deliberately not fixed here.

1. **The duplication returns in full at `annot_show 1` + `show_hidden_texts 1`** —
   measured with a real raw: `id=12.34u` **and** `id    = 12.34u` on the same
   device. **No test row covers that state** (Q7 exercises mask 0 + sht 1 only),
   and §3's phrase "the two builders are never both painting" is false there. Still
   strictly better than `hide=op`, which double-paints in the *common* case
   (mask 1, sht 0). Add the mask1+sht1 cell rather than re-litigating the token.
2. **A second loss class the E question does not name.** `op_annot::_matches`
   tests `match {*sky130_fd_pr/*}` against **`cell::name`, not the file's real
   location**. Measured: a byte-copy of the edited `nfet_01v8.sym` instanced from a
   user library renders **nothing** at mask 0 *and* mask 1 with a raw loaded, and
   `_matches` returns 0 for `myfoundry/nfet_01v8` reached through a differently
   named library alias. So vendored or aliased PDK symbols are silent at every mask
   **even with `sky130_procs.tcl` sourced**. §7's option (b) must be sized against
   this, not against the rc-only case.
3. **Issue 0428's disagreeing builder is now harder to notice, not gone.** It
   renders only at `show_hidden_texts 1`, where it appears as a blank *beside* the
   overlay's correct number — a contradictory pair rather than an obvious blank.
4. **The legacy vgs/vds text renders `vgs=- - -` where the raw lacks pin voltages**,
   next to the overlay's blank `vgs   =`. An I3-shaped inconsistency (a dash-string,
   not a blank) that this change makes default-invisible but that
   `show_hidden_texts` restores side by side with the correct blank.
5. **`show_hidden_texts` becomes a coarser knob on sky130.** Before S10b it did not
   affect the FET annotation at all; now a user who enables it to see
   `hide=instance` texts also gets 40 FET symbols' worth of legacy annotation back,
   and at mask 1 the duplication of item 1 with it.
6. **Test-coverage gap.** Every Q row uses the same fixture and viewport. Nothing
   exercises a non-matching cell name, a symbol reached by absolute path, or the
   mask1+sht1 state — the two behaviours most likely to surprise a user are
   unguarded.
7. **Q2's census check has the count-conserving blind spot of §10.**
8. **The stronger acceptance evidence lives outside the suite.** The suite asserts
   only that four prefixes count 0; the mirror diff proves the export changed by
   exactly those texts and nothing else. Consider promoting the mirror comparison —
   or at least its non-text-line-count assertion — into section Q.
9. **`xschem_library/devices` and IHP remain ungated** — issue **0476**. A schematic
   mixing generic devices with sky130 FETs now annotates inconsistently.
10. **Measurement hazard, recorded for anyone re-running these numbers.** Sabotage
    variants mutate the real `.sym` files in place. Bracket every measurement with
    `git diff -- sky130A | md5sum` — every number here was taken with that stable at
    `6ab928dcee2d6321a73cdbb09d97577a` and `git status --short --untracked-files=no`
    at exactly 42 files.

---

## 10. RULING (the user, 2026-08-22) — **(a), ship as implemented**

Verbatim: *"Yes, we move to the new regime. Our local repo sky130 turns off that
noise... We are always going to improve things."*

So option **(a)**: the 119 `hide=true` records stay, `View > Show hidden texts`
is the way back, and no built-in `sky130_fd_pr` fallback registration (b) and no
`annot_show` default change (c) are wanted. This matches the state gf180's 38
records have shipped in all along.

**Documented for the user in `doc/claude/FAQ.md` Q48**, which is the deliverable
the ruling asked for: what disappeared, the one-click way back
(`show_hidden_texts`, and note it must be set in BOTH the C field and the Tcl
var), a verified permanent revert for a private library, and why the change is
not simply a loss.

The revert one-liner in Q48 was measured on a copy of the real library before
shipping: 119 records across 40 files -> 0, with the `{layer=15}` / `{layer=17}`
tails restored to 79 / 40 exactly, i.e. byte-identical to the pre-S10b files.

### One argument the crew that implemented (a) did not have

Hiding the four texts was supposed to stop them colliding with the overlay.
Measured on the sky130 `bandgap_opamp` bench 2026-08-22, **it bought no space at
all**: the overlay collides with the symbol's *geometry* text (`pfet_01v8`,
`nf=1`, `1 x 1 / 6`) and the `VCC`/`VSS` pin labels, none of which carry a
`hide=` token. 4 of 6 rows unreadable on a typical instance. The `hide=true`
edit did the job it actually had — removing a DUPLICATE — and none of the job it
was thought to have. That belongs to 0605, ruled the same day.

### Still open, and NOT settled by this ruling

* **0457** — outside the cadence profile there is still no stock affordance for
  `annot_show`; the `6` key is the only one. The FAQ says so plainly.
* **0476** — IHP's 2 inductor records, `annotate_fet_params`, and 30 records in
  `xschem_library/devices/*.sym` still answer to no knob at all. The user's
  "we are always going to improve things" points at fixing those the same way,
  but that is a change to make, not a question to answer.
