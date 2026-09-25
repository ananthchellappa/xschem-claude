# Decisions — issue 1603 batch

## F1 — the driver's prediction, registered BEFORE the measurement round reported

Recorded at `73ebbfa0`, so the Stage A crew's fixture tests this rather than confirming it. If
the measurement refutes it, the refutation stands and this entry stays as written. The 1607 batch
ran the same way and a crew caught the driver overstating his instrument; that is the point.

**Prediction: fewer than half of the 26 candidates will be drivable to a crash** with an ordinary
typeless symbol, and the valuable output of this batch will be the **semantic grouping** rather
than the patch count.

The reasoning, such as it is:

* **The one site that was drivable took a verb nobody had driven before.** `psprint.c:1070` fell
  out of the headless-crashes batch's Map crew driving *every* `xschem` subcommand with no
  display; the receipt says plainly that nobody had driven `hier_psprint` on a loaded schematic
  before. That is the signature of a site reached only by an unusual path.
* **17 guarded against 28 unguarded looks like reactive patching.** If guards were added where
  crashes were actually observed, then the guarded sites are the reachable ones and the unguarded
  remainder skews towards paths ordinary content does not take. ⚠ This is an inference about
  development history, not evidence, and it is exactly the kind of story that sounds good and
  turns out to be wrong.
* **Something may filter earlier.** `check.c` does ERC and symbol consistency, and a netlist run
  may reject or skip a symbol with no `type=` before any back end reads the field. If so, the
  netlister cluster is largely unreachable *through netlisting* while remaining a real hazard for
  anyone who calls those functions another way.

⚠ **What would refute it.** A majority of the 26 driven to a crash from a single ordinary
fixture; or `check.c` turning out to pass typeless symbols straight through, which would make the
whole netlister cluster live.

### F1a — the driver refuted his own third bullet within the hour, before any crew reported

The third bullet guessed that `check.c` might reject or skip a typeless symbol before a back end
ever reads the field. **It does not.** `check.c`'s own label predicate reads:

```c
  if(xctx->inst[i].ptr < 0) return 0;               /* unlinked symbol: no type to ask about */
  type = (xctx->inst[i].ptr + xctx->sym)->type;
  return type && !strcmp(type, "label");
```

That is the **house-style guard, correctly applied** — and its comment shows the author was
thinking about exactly this case ("unlinked symbol: no type to ask about"). So ERC does not
filter typeless symbols; it simply answers "not a label" and passes them on. There is no upstream
sieve, and **the netlister cluster is live rather than shielded.**

Two things follow. First, the prediction's "fewer than half drivable" now rests only on its first
two bullets, one of which is an inference about development history that the entry already flags
as the kind of story that sounds good and turns out wrong — so the driver's confidence in F1
should be read as low, and the Stage A measurement is what decides it. Second, `check.c` joins
`move.c` as a *second* in-tree example of the considered form, which strengthens F2: the house
style is not only common, it is applied by authors who were explicitly reasoning about a missing
type.

⚠ **What must NOT happen if the prediction holds.** "Mostly unreachable" is not a reason to
close the issue. An unreachable NULL dereference is one refactor away from a reachable one, and
the guard is one `&&`. The prediction is about *priority ordering*, not about whether to fix.

## F1b — OUTCOME: F1 was right about the number and wrong about the reason

**Measured: 2 of 26 driven to a crash** — far fewer than half, so the prediction holds. But both
of its surviving bullets were wrong about *why*, and the real reason is more interesting than
either:

* The "reactive patching" inference — that unguarded sites skew towards paths ordinary content
  does not take — is **not** what protects them. What protects them is (i) that **16 of the 26 were
  never unguarded at all**, a flaw in the original sweep's classification rather than anything
  about reachability, and (ii) an **invariant**: `prepare_netlist_structs()` → `reset_caches()` →
  `set_sym_flags()` rewrites a NULL `type` to `""` before any netlister site is read.
* The "unusual path" story about `psprint.c:1070` also does not generalise. The two real defects
  are reached by **two lines of Tcl** (`xschem load`; `xschem sch_pinlist`) and by an ordinary
  `setprop` followed by `select_all`. Neither is exotic.

**The honest verdict on F1 is that it got the right answer from the wrong model**, which is worth
recording as plainly as a refutation would be. A prediction that lands for the wrong reason is
not evidence that the reasoning was sound, and the entry should not be read as a win.

⚠ **And its warning held.** F1 said "'mostly unreachable' is not a reason to close the issue — an
unreachable NULL dereference is one refactor away from a reachable one". That turned out to be
measurable rather than rhetorical: flipping **one token** in `set_sym_flags` (`my_strdup2` →
`my_strdup`, the spelling used almost everywhere else in this tree) produces two sequential
gdb-confirmed segfaults at `netlist.c:1024` and `:1354`. The refactor is one character wide.

## F2 — no blanket `type ? type : ""`, and the issue is right about why

The issue warns that a blanket substitution "would answer all 28 at once and would be wrong
wherever the absence means something other than 'not that type'". Accepted as a constraint on
this batch, not as a matter for the user: it is internal correctness.

The considered form already in the tree is `move.c`'s `if(!sym->type || strcmp(sym->type,
"label")) return -1;` — a typeless symbol is *not* a label, so the predicate short-circuits to
"not that type". The reason that is not automatic everywhere is that some sites ask a question
where "unknown" and "no" differ: whether to emit a port, whether to descend a hierarchy, whether
to skip an instance entirely. Each group gets a stated rule, and the rule goes in the source
comment so the next reader does not have to re-derive it.

### F2a — VINDICATED, and the site the issue warned about has a name

The issue said a blanket substitution "would be wrong wherever the absence means something other
than 'not that type'" without naming such a site. **It is `netlist.c:1030`.** The variable it
computes is `port`, so `type ? strcmp(type, "label") : 1` would read *"typeless ⇒ not a label ⇒ it
IS a port"* — false. And it does not need a guard at all: it is dominated by `:1024`, so reaching
it requires `type` to have already compared equal to one of four known strings.

So the batch's rule is: **guard `:1024`, leave `:1030` alone, and leave a comment at `:1030`
saying why** — otherwise the next reader "fixes" it and silently turns every typeless symbol into
a port.

Two in-tree precedents for the considered form, both by authors who were visibly thinking about
this case: `move.c`'s `if(!sym->type || strcmp(sym->type, "label")) return -1;`, and `check.c`'s
`return type && !strcmp(type, "label");` under the comment *"unlinked symbol: no type to ask
about"*. The house style is not merely common — it is what careful authors here already write.

## F3 — a guard without a row that reddens on its removal is a guard that leaves silently

The 1607 batch paid for this lesson twice: a behavioural row can be defeated by heap luck (`V25`
flipped green/red/green on one byte of environment), and a static row can be defeated by a dead
copy of the code it greps for (`svgdraw.c` carries a `#if 0` clone of one clamp, so a whole-file
regexp stayed green with the live clamp deleted). Both shapes are now in
`tests/headless/test_ps_valid_1350.tcl` as `V25` and `V27`.

So Stage C uses the same pairing where it applies: a behavioural row driven by Stage A's fixture
wherever the crash can be driven deterministically, and a static row where it cannot — with the
static one scoped past comments and disabled regions, not a whole-file grep.
