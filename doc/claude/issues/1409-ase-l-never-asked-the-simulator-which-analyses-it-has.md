# 1409 — ASE-L never asked the simulator which analyses it has, so the list was a guess

**Status:** fixed
**Branch:** fluid-editing
**Stage:** commit **C4** of Stage 2 of `doc/claude/ase_analyses_batch/` (plan item **2a**)

## What ships

The existing capability deck **C** gains, per analysis the adapter describes, an `echo "== <verb>"`
marker and a `help <verb>`, both redirected to a file, plus one `devhelp`. **No new run** — measured
on all three preflight binaries, the leg adds 0 ms within the tool's resolution, because deck C
already runs to completion and already writes a text file.

Three new keys: **`analyses_available`**, **`analyses_probed`**, **`devices_available`**.

## The probe token had no source, and that is why a schema proc was needed

Stage 1's Xyce paper-validation **deleted** the `verb` key (correction C41) — it was specified as
*"the `.control` command word AND what `help <verb>` is probed with"*, two ngspice words sitting in
the half D34–D37 say may contain none, and deleting it moved no byte because the emitted token was
always `[lindex $tmpl 0]`. Stage 2 needs that token back.

**`ase::analysis_card_tmpl {sim type {role analysis}}`** returns the emit card's template without a
row. Core learns *"the first word of what this adapter emits"* — true of any simulator with a
command language — and learns no ngspice.

⚠ **It must not go through `ase::analysis_cards`, and that is not a preference.** That proc resolves
`@slots` through `ase::analysis_expand`, which does `dict get $row <field>`. Measured with only a
type in hand: `op` answers, and `dc` / `ac` / `tran` **raise** `key "source" not known in
dictionary`, `"points"…`, `"step"…`. A driver following the plan's text would have reached for
`analysis_line` and got a raise on three of four types. Row **Q2** pins it.

## The four rules, each measured on all three binaries

| rule | measurement |
|---|---|
| **the verdict is read from the FILE, never the exit code** | ⚠ and the measured reason is **sharper** than "it exits nonzero". Deck C — which carries the leg and **has** a circuit — exits **0** on all three; a circuit-**less** probe deck exits **1**; and **both write their files**. So **rc tracks whether a circuit was parsed and says nothing whatever about whether the help answers arrived**, and an implementation gating on it would read a good answer as no answer on one deck shape and a missing answer as fine on the other. ⚠ This row first said *"all three exit 1"* — measured on a probe deck of my own construction rather than on deck C, so true of that deck and **false of this one**. Caught by C5's adversary, re-measured before committing. **A measurement is about the exact artifact it was taken on**, which is the same correction as §0.2's survey (issue 1405, 100 checks) and P8's line-vs-read count (issue 1407) |
| **a stanza counts on its FIRST TOKEN** | `help tf` prints `tf [.tran line args] : Do a transient analysis.` — the wrong bracket **and** the wrong sentence — on all three. A rule matching the description would read `tf` as absent on **every ngspice ever shipped** |
| **the comparison is CASE-INSENSITIVE** | ngspice resolves the verb with `eqc()` = `cieq()`, so `help TRAN` answers the lower-case `tran` stanza, and the failure line echoes the verb **folded**: `help XXNOSUCH` → `Sorry, no help for xxnosuch.` |
| **never `help all`** | ⚠ it would **accidentally work today** — its count loop stops at the first NULL `co_func`, which is `while` in `commands.c`, and the analysis verbs sit above it. The refusal is **one table edit** away from load-bearing, so it is fenced structurally now rather than after a later reader "simplifies" eleven help calls into one |

⚠ **`pss` on stock-47 is the ONLY reproducible `absent` fixture on this machine.** Measured: `help
sp` **answers** on apt 45.2, on the fork **and** on stock 47 — so `PLAN.md`'s `--enable-rfspice`
example cannot be demonstrated here at all.

## The finding that changed the design

⚠ **A build whose `spinit` never loaded cannot be asked what devices it has.** Measured: stock 47,
uninstalled, logs `Warning: can't find the initialization file spinit.` and its `devhelp` answers
**52** names against **136** on apt 45.2 and **138** on the fork — it loses every XSPICE code model.
Publishing 52 as a fact about that binary is a **fabricated absence of ~84 device families**, and
the readers would then refuse analyses that would have run.

So `devices_available` is **not published at all** in that case, and its absence is recorded by name
through the `unmeasured_keys` machinery issue 1407 built — a **third** provenance token, `noinit`,
for a condition genuinely different from the two already wired: those record a leg that was **cut**;
this records a leg that **ran, finished, and produced an artifact known to be incomplete**.

⚠ **Grepped, never counted.** The count is exactly what the missing models move, so a threshold
would be a guess about a number nobody controls.

## Two guards that are one line each and opposite in consequence

⚠ **`analyses_available` is published only for a NON-EMPTY verdict.** An empty list on a `known 1`
answer reads as *"this binary has no analyses"* and empties the grid; a **missing** key reads as
*"not measured"* and falls back to the source-verified baseline. **They are opposite answers to the
user, and the difference is one `ne {}`.** Row **Q6** is structural so the guard cannot be dropped
silently.

⚠ **The probed set comes from `ase::analysis_types`, never from `ase::analysis_offered`.** The
latter filters on `registered`, which is ASE-L's **display** switch — sourcing the probe from it
would change the probed set without changing the binary, and the cache, keyed on the binary's path,
mtime and size, would never notice. Row **Q13**.

## `analyses_probed` is a different fact from `analyses_available`

A cache taken before a type was registered says nothing about that type. Without this key a reader
cannot tell *"measured absent"* from *"was not among the questions asked"* — the same
absent-versus-unknown fusion the capability vocabulary exists to prevent, one level up.

And **an unknown device family is `unknown`, never `absent`.** `osdi_add_device` appends OpenVAF
devices at **load** time, so a `devhelp` against a **scratch** deck cannot see a PDK's Verilog-A
devices. Fusing the two produces the worst outcome this design can produce — refusing something that
would have run — and on any Verilog-A PDK it would be the **likely** outcome. Row **Q10**.

## Verification

`test_ase_simcaps_0948` **126 → 141** (section Q, 15 rows). Every canned fixture is **verbatim
measured text** from all three binaries; a fixture nobody measured proves the parser agrees with the
fixture and says nothing about ngspice.

**Eight sabotage passes:** matching the description instead of the first token (Q3, Q4, Q5, Q14,
Q15); case-sensitive comparison (Q5); dropping the non-empty guard (Q6); folding the device names
(Q7); counting rows instead of grepping the warning (Q8); fusing unknown with absent (Q10); sourcing
the probed set from the display switch (Q13); reaching for the row-taking reader (**Q15 only** — the
real-binary row is the one that caught it, which is what earns it its place).

One real end-to-end probe against the binary the registry resolves to: `analyses_available
{op dc ac tran}`, `devices_available` 138 names, `NUMD` present, `unmeasured_keys` empty.

## Related

* **1407** — the capability vocabulary this leg publishes through, and whose `unmeasured_keys` the
  `noinit` token uses.
* **1401** — Stage 1, which deleted the `verb` key that made `analysis_card_tmpl` necessary.
* **1334**, **0949** — why every redirect target is a bare lower-case name.
