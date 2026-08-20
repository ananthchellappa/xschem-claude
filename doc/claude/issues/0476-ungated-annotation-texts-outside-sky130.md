# 0476 — annotation texts outside sky130 that answer to no visibility knob

Status: MEASURED, DELIBERATELY NOT FIXED by S10b. Related: 0475, 0457, spec S10/S11.

S10b gated sky130's 119 FET annotation records behind `hide=true` (issue 0475).
While counting the corpus, three other groups of annotation texts turned up that
render **unconditionally** — they carry no `hide=` token at all, so neither
`annot_show` nor `show_hidden_texts` can turn them off. They were left exactly as
they are, and this issue records why, so the omission is a decision and not an
oversight.

## Measured

| where | records | state |
|---|---|---|
| `ihp-sg13g2/xschem_libs/sg13g2_pr/inductor/symbol/inductor.sym:59` and `inductor3/symbol/inductor3.sym:59` | 2 | `T {@spice_get_current} -12.5 5 0 1 0.2 0.2 {layer=17}` — no `hide=` |
| `ihp-sg13g2/xschem_libs/sg13g2_pr/annotate_fet_params/symbol/annotate_fet_params.sym:10-11` | 1 | `{layer=15\nfont=Monospace}` — no `hide=` |
| `xschem_library/devices/*.sym` | 30 records in 28 files | `@spice_get_current` / `@#n:spice_get_voltage` texts, none carrying `hide=` |

By contrast: gf180 = 38 records, all `hide=true`; sky130 = 119 records, all
`hide=true` after 0475. IHP is now the only PDK in the tree whose annotation
cannot be switched off.

## Why S10b did not touch them

**Ladder L2 — hiding them would be pure loss, not deduplication.** The sky130 case
is a trade: the S9b overlay paints a strict *superset* of the four texts it
replaces, so hiding them removes a duplicate, not a number. Neither of these
groups has that replacement.

* **IHP inductors.** No `op_annot::register` descriptor covers `type=inductor`
  (the ported sky130 descriptors are `nmos`/`pmos`, the IHP prototype's are FET and
  bipolar). The overlay would never fire on them, so a `hide=` token would delete
  the current reading with nothing to put in its place.
* **IHP's carrier `annotate_fet_params.sym`.** It is the prototype's own carrier and
  is *superseded* by the PDK-neutral `xschem_library/devices/annotate_params.sym`
  (S6b), which already carries `hide=op`. Editing the prototype's copy would fork a
  file whose replacement already ships; retiring it is S11/S12 work, not S10's.
* **`xschem_library/devices/*.sym`.** These are the generic, PDK-independent
  devices. sky130's descriptor carries `match {*sky130_fd_pr/*}`, so the overlay
  provably never covers them — and get_annot_overlay's decision D1 exists precisely
  because a `type=`-only gate would paint a block on 13 of them. Same reasoning:
  gating them removes a number and supplies nothing.

## Also worth recording

`grep -n 'hide\|annot_show\|show_hidden' ihp-sg13g2/sg13g2_procs.tcl` returns
**empty** across all 700+ lines. The single-PDK prototype this whole feature was
generalized from solves the *content* problem (build the vector name, walk the
hierarchy, emit save cards, format the block) and never had a *visibility* concept
at all. That absence is why its own shipped artifacts are the ungated ones.

## What would fix it

Either (a) an `op_annot` descriptor for `type=inductor` (and whatever else the IHP
tree annotates), after which these two records become genuine duplicates and can be
tokened exactly as sky130's were; or (b) an explicit ruling that some annotation is
always-on. (a) is the same shape as 0475 and is the smaller change. Neither belongs
in S10's blast radius.
