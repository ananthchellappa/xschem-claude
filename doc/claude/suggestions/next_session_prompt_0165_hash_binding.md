# Issue 0165 — one `#`-leading name becomes TWO nodes, depending on how it arrived

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`, HEAD **`7791a85e`**.
Everything through `c8671825` is **pushed**; `d5968562` and `7791a85e` (docs only) are not.
Next free issue number is **0179**. **Never push** — commit, raise
`tools/review_gate/review_gate.sh` in the background, and wait.

⚠ **Do not confuse this with `next_session_prompt_0165.md`.** That file is named for
0165 but is a **0166** spec-first prompt, and it says of this issue: *"LOWER
PRIORITY, do not start with it… Ask me before starting this one at all."* The
user has now asked for it. Read that file anyway — its "HARD-WON TRAPS" section
is the best in the tree and most of it applies here — but its Phase 1/Phase 2
structure is 0166's, not yours.

---

## The ask

`doc/claude/issues/0165-netlist-hash-node-two-names.md`. In one sentence: **`#` is
stripped on the label/net path and passed through verbatim on the `extra=`
attribute-binding path, so one spelling the user typed once becomes two
unconnected nodes**, and the binding's node is a silent floating supply.

```
V1 topn 0 1
X1 topn #hfoo c      <- the extra= binding: verbatim
R9 hfoo  0    1k     <- a wire LABELLED #hfoo: '#' stripped
   hfoo 0.0V     #hfoo 1.0V     topn 1.0V     <- ngspice-42, two nodes
```

---

## ⚠ THE ISSUE FILE IS WRONG IN SEVEN PLACES. Fix it as your first act.

A recon pass on 2026-07-30 verified every claim in 0165 against the tree. The
load-bearing analysis in "Where the two paths diverge" is accurate, but the
following are **wrong or stale**, and three of them change the decision you are
being asked to make. Correct the issue file before you do anything else, then
work from the corrected version.

### 1. `print_erc` is NOT a function — it is a local `int` gate variable

0165 item 3 is written as if `print_erc` were a hook you could call. It is
declared at `src/netlist.c:1414` and assigned once at `:1426`:

```c
print_erc = (xctx->netlist_count == 0 || startlevel < xctx->currsch) && for_netlist;
```

It gates warning emission inside `name_nodes_of_pins_labels_and_propagate()`.
There is no `print_erc()` anywhere in the tree.

### 2. The precedent warning ALREADY FIRES on the label half of this exact trap

`src/netlist.c:1491` (message at `:1495`) is not merely "an example of this shape
of warning". **It fires on `#hfoo`-the-label and is silent on `#hfoo`-the-binding
— measured on the 0165 fixture.** So option 3 is not "add a warning"; it is
"extend a warning that already half-covers the case". That is a much cheaper
option than 0165 makes it sound, and it is the strongest argument for option 3.

### 3. "The node is unreachable by any other means" — FALSE

Three label-derived emission sites do **not** strip: the child
`.subckt`/`module`/`entity` **port list** built from the symbol pin `name`
attribute (`src/token.c:2098-2100`, `:2259-2261`,
`src/verilog_netlist.c:525`, `src/vhdl_netlist.c:599-603`), and the SPICE
top-level `.save` path. So the trap is wider than "only the binding can reach it".

### 4. The tEDAx claim is WRONG

0165 says the tEDAx `conn` emission "sits inside `if(!subcircuit)` and so is
unreachable for subcircuits". `subcircuit` is only ever set inside
`if(!format && !strcmp(type,"subcircuit"))` (`token.c:3159/3169`), and `!format`
already returns unconditionally at `:3198-3206` — so `if(!subcircuit)` at
`:3208` is **always true**. tEDAx is reachable.

### 5. Spectre and Verilog are AFFECTED, and both are now measured

0165 lists them as read-not-measured. Both diverge identically. Spectre emits
`X1 ( topn '#hfoo' ) chash` — the leaked name additionally single-quoted by
`spectre.awk`'s `q()` (`src/spectre.awk:290-299`), because `#` is outside
`[a-zA-Z0-9_$]`. Verilog's mechanism is as described (`token.c:3817` reads
`verilog_extra`, resolution is the flat two-step at `:3940-3941`) but it is
affected the same way.

### 6. `node_hash.c:132` is NOT a strip site

0165 lists it as "the same idiom" as `netlist.c:956`. It is the opposite: a
**bypass** that `my_strdup`s the token verbatim *keeping* the `#` so it skips
`expandlabel()`. The hash table therefore stores the name **with** its `#`.
(`:290 :302 :351 :362` are genuine strips and land correctly.)

### 7. "Tests: none yet" — and this one will bite

`tests/headless/test_resolved_net_attr_scope_0163.tcl` (34 legs) **already
asserts the exact behaviour 0165 proposes changing**: `AS1b` parses the generated
`.spice` and pins the unstripped binding. `AS13`, `AS14`/`AS15` and `AS18` are
coupled. A strip-side fix breaks a green suite by surprise unless you retarget
those four legs deliberately, as part of the change, with the reason in the diff.

### Minor drift, fix while you are in there

| 0165 cites | today |
|---|---|
| `src/netlist.c:778-790` (the policy comment) | comment `:775-786`, `is_auto_net_name()` at `:788-794` |
| `print_spice_element()` `~2615-2645` | fn at `:2347`; generic-`@token` branch `:2585-2674`; resolution `:2616-2642`; `value = val` at `:2646`; **the verbatim write is `:2671`**, outside the cited range |
| `actions.c:3568-3572` (portmap strip, cited from `hilight.c`) | `:3594-3600` |
| `voltage_protection.sch:69` / `pcb_voltage_protection.sch:76` | `:73` / `:80` |
| "68016 attribute values… exactly 7… 4778 labels / 407 files" | tree has grown; **6** committed `xxxspiceprefix="#"`, ~4785 `lab=#` across ~404 committed `.sch`. The denominator 68016 is not reproducible — re-measure and record your command rather than copying a number |

---

## THE FACT THAT SHOULD DRIVE THE DECISION

**Every one of the ~5000 committed `lab=#...` records is `#net<digits>`.**
`grep -vE '^lab=#net[0-9]+$'` returns nothing. So:

- No committed design contains a **user-authored** `#foo` label.
- No committed design contains an `extra=` binding whose value starts with `#`.
- The existing `netlist.c:1491` warning therefore fires on **zero** stock designs.
- A new warning at `token.c:2646` — even an unfiltered one — would also fire on
  **zero** stock designs.

Which means **option 3 (warn) is provably output-neutral and transcript-neutral
on the shipped libraries**, and option 1 (strip) is the only one that needs the
201-design diff. Weigh that before you write anything.

---

## Two other stages 0165 never accounts for

1. **`src/spice.awk` and `src/spectre.awk` post-process the emitted netlist.**
   Dispatched at `src/xschem.tcl:2255-2262` (spice) and `:2268-2274` (spectre).
   `spice.awk:204-221` rewrites `##name` → `name` and `#pfx#name` → `pfxname`.
   **A single leading `#` matches neither pattern and survives** — measured. If
   you decide to strip, decide *where*: C emission, or this awk stage. They have
   different blast radii and the awk stage is post-hoc text munging on a file the
   user can already see.
2. **`hash_prefix_unnamed_net`.** `net_name()` (`src/token.c:3961`, branch at
   `:4016`, emission `:4035/:4037`) emits names **with** the `#` when this
   parameter is 1. There is already a user-facing knob about `#` in output.
   Any strip decision must say what it does when that knob is on.

---

## THE DECISION I OWE YOU — ask me once, early, then proceed

0165's "Not yet decided" has four items. Two are mine, not yours. **Bring me the
evidence and your recommendation, then stop.**

- **D1 — strip on the binding side, or warn and leave output alone?** My prior
  lean, recorded in the 0166 prompt, was *ERC-warn rather than rewrite*. The
  recon above strengthens that considerably (finding 2 and the zero-stock-designs
  fact). Tell me if you disagree, with the reason.
- **D2 — strict or loose?** `is_auto_net_name()` (`#net<digits>`, the 0156
  policy) versus any leading `#` (what the label path does). They disagree
  exactly on user-authored `#foo`, which is the measured case. Note that the
  label path is loose and the existing warning is loose-AND-NOT-strict.
- **D3 — which backends?** SPICE, Spectre and Verilog all diverge; VHDL turns
  extra tokens into generics, not nodes; tEDAx is reachable (finding 4). A fix
  in one backend and not the others is a new inconsistency, so say explicitly
  which you are changing and why the rest are fine.
- **D4 — does `resolved_net` move with it?** It must. `resolved_net_from()`
  (`src/hilight.c:2625`, the strip at `:2673`) already strips `#` **per bus
  element** (issue 0158) and refuses to empty a bare `"#"`. 0165's own line 66
  says the two must stay in agreement. A strip-side fix is one commit touching
  `src/token.c`, `src/hilight.c:2704-2717` (the comment inverts) and four legs in
  `test_resolved_net_attr_scope_0163.tcl`.

---

## If D1 comes back "strip": the evidence bar

**There is NO committed 201-design netlist-diff harness.** Neither 0163
(`:224-225`) nor 0164 (`:121-124`) defines the set, and `tests/netlisting.tcl`
walks `../xschem_library` and finds **189** `.sch` today. So the "201 designs,
byte-identical" evidence that cleared 0163 and 0164 **must be rebuilt before it
can clear this**. Build it as a committed script, not a one-off — it is the third
time it has been needed.

The two traps that make a netlist diff lie, both already paid for:

- Run **both binaries back to back**. xschem writes gitignored `<cell>~.sch`
  autosave files while descending, and `xschem_library/examples/*.sch` globs them
  as tops — a stale one produced a spurious `Q1~.spice` diff that looked exactly
  like a behaviour change.
- `git stash push src/<file>` on a **clean tree stashes nothing**. For a true
  pre-fix binary use `git checkout <sha> -- src/<file>`, rebuild, copy the binary
  out, and **verify it is the old one** by running your new test against it and
  confirming it fails. A binary copied out of the tree needs
  `XSCHEM_SHAREDIR=$PWD/src`.

---

## If D1 comes back "warn": where it goes

`print_spice_element()`, the generic `@token` else-branch. The earliest line at
which the resolved value exists is **`src/token.c:2646`**; the natural insertion
point is after the expression evaluation at `:2656-2658`, immediately before the
emission at `:2660-2673`.

Do **not** check `get_tok_value(inst.prop_ptr, "HN", 0)` instead — it would miss
`HN=@FOO` forwarding, a value defaulted from `template=`, and any `expr(...)`.
The value is produced by up to **four** `translate3()` rounds (`:2616-2642`):
round 1 instance-only, round 2 adds `parent_prop_ptr` + the symbol template
(0164's fallback), round 3 resolves `@symname`, round 4 adds the parent template.

In scope at `:2646`: `inst`, `token` (with its leading `@`; the code already uses
`token+1` at `:2661`/`:2667`), `value`/`val`, `template` (`:2369`), and
`xctx->sym[xctx->inst[inst].ptr].prop_ptr` — so the symbol's `extra=` list is one
`get_tok_value()` away, which is how you restrict the check to extra **nodes**
rather than every parameter.

Assert it via `xschem get infowindow_text` after `xschem netlist` (works in both
arms). The warning fires on zero stock designs, so **the test must build its own
fixture** — copy the shape from `tests/headless/test_hash_label_crash_0156.tcl`.

---

## Suites that must stay green (measured 2026-07-30, `--nogui` arm)

```
test_resolved_net_attr_scope_0163      34    <- WILL need retargeting if you strip
test_resolved_net_templ_fallback_0164  23
test_resolved_net_bus_global_0157      19
test_resolved_net_hash_bus_0158        21
test_ase_hier_pick_0161                21
test_ase_hier_plot_0168                31
test_hash_label_crash_0156             23
test_prep_result_contamination_0155    12
test_ase_unnamed_net                   28
```

Run them with `SUITE_TIMEOUT=900 GUI_GATE=0 tests/headless/run_suites.sh --nogui <names>`,
never a bare loop. For the DISPLAY arm drop `--nogui` and `GUI_GATE=0` — the
control panel is the user's consent to having the display flooded; press
**Allow 2h** once rather than Proceed per suite.

⚠ **The netlisting regression (`cd tests && tclsh netlisting.tcl`) has NO gold
baseline** — it can only report NOGOLD. It is not evidence.

---

## How I want you to work

1. **Correct the issue file first**, from the seven findings above. That is a
   commit on its own and it is the deliverable even if nothing else lands.
2. **Reproduce the defect yourself** before trusting any of it — including the
   parts this prompt asserts. Subagents report confident wrong answers, including
   ones that claim to have run the binary; 0166 came from an agent that was right
   about the defect and wrong about the expected value.
3. **Bring me D1–D4 with evidence and a recommendation. Then stop.**
4. After I answer: RED-first — the failing test before the fix, and it must fail
   before and pass after. Then **sabotage-verify**, and sabotage the *opposite*
   error too, not just the revert. **If a sabotage changes nothing, say so out
   loud** — that half has no teeth.
5. Issue doc + `doc/claude/code_analysis/waveform_subsystem_reference.md` §11 if
   a landmine moves. Commit. Raise the review gate. **Never push.**
6. Report what you verified, what you did **not** verify, and any judgement call
   I should weigh in on.

## Background to read

- `doc/claude/issues/0163-*.md` — **especially "What the loop is actually for"
  and "Correction"**. The Correction is the ngspice measurement both 0165 and the
  no-strip rule hang off.
- `doc/claude/issues/0164-*.md`, `0166-*.md` — 0166 is the sibling still open,
  and a strip-side fix here touches the same function.
- `doc/claude/suggestions/next_session_prompt_0165.md` — the traps section.
- `src/netlist.c:775-786` — the `#`-is-not-proof-of-auto-named policy.

**Policy ratified in 0156:** net names are not restricted to `[a-zA-Z_]`. Only
`#` is reserved for the engine. Existing `#foo` names are ordinary user names
(never rewritten, never refused at load) and reported by ERC. Output-strip sites
stay **loose**; only index-computing sites use strict `is_auto_net_name()`.

**`resolved_net`'s contract:** return the name the **simulator actually has**.
That is why 0163's `#` strip was reverted (`a5a08bc8`) — given a binding
`HN=#hfoo`, the node *is* `#hfoo`, and stripping named a different node the
child's port is not connected to. **If D1 says strip, that contract inverts and
`resolved_net` must move in the same commit.**
