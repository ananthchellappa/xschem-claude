# Issue 0183 — an empty attribute value swallows the next token

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`.
Next free issue number after this one is **0184**.
**Never push** — commit, raise `tools/review_gate/review_gate.sh` in the background, and wait.

Doc: `doc/claude/issues/0183-empty-name-value-swallows-next-property-line.md`. Read it
first; this prompt does not repeat the discovery story.

---

## ⚠ The open question in the issue doc is CLOSED. Read this before you plan anything.

The issue was filed with two candidate fixes — **at the producer** (stop emitting an empty
`key=`) or **at the tokenizer** (make an empty value mean empty). Measurement has since
settled it, and the answer is not the one the issue doc leans toward:

> **The tokenizer is not broken. Its whitespace-skip is LOAD-BEARING in a shipped
> library file.**

`xschem_library/ngspice_verilog_cosim/tb_sar_adc.sch:176` (and `sar_adc.sch:78`):

```
C {dac_bridge.sym} 330 -160 0 0 {name=A2 dac_bridge_model= dac_buff

device_model=".model dac_buff dac_bridge input_load=1e-15 t_rise=10n t_fall=10n
+ out_low=0 out_high=3.3"
}
```

Measured:

```
$ xschem get_tok "name=A2 dac_bridge_model= dac_buff\n\ndevice_model=\"...\"\n" dac_bridge_model
dac_buff
```

The author wrote a space after `=` and **meant** the value `dac_buff`. So `key= value` is
part of the grammar, deliberately used, and changing the tokenizer would silently break
that file and any user schematic written the same way.

**Therefore: fix the producer. Do not touch the tokenizer.** If you find evidence that
overturns this, bring the evidence and stop — do not change the grammar on a hunch.

---

## What the tokenizer actually does — measured, 11 cases

`xschem get_tok <str> <tok>` is a pure wrapper over `get_tok_value()`;
`xschem get_tok_size` returns 0 when the token was not found at all, which is how you tell
"absent" from "present but empty". Neither needs a design.

| # | property string | result |
|---|---|---|
| A | `name=\nflags=graph,unlocked\nlock=1\n` | `name` = `flags=graph,unlocked`, `flags` **not found** |
| B | `name= flags=graph,unlocked lock=1` | identical to A — **a space behaves like a newline** |
| C | `name=\tflags=graph,unlocked` | identical — **a tab too** |
| D | `name=""\nflags=graph,unlocked\n` | `name` = `` (found), `flags` = `graph,unlocked` — **quoting works** |
| E | `flags=graph,unlocked\nname=\n` | `name` = ``, **found = 0** |
| F | `a=1\nname=\nflags=graph\nb=2\n` | `name` = `flags=graph`; `a` and `b` unharmed |
| G | `name=g1\nflags=graph,unlocked\n` | control — both correct |
| H | `lab=\nvalue=1k\n` | `lab` = `value=1k` — **not specific to `name`** |
| I | `name=\nlab=\nvalue=1k\n` | `name` = `lab=`; `value` still `1k` — **exactly one token is eaten** |
| J | `name=\n\nflags=graph\n` | a blank line does not stop it |
| K | `name=` | `name` = ``, **found = 0** |

Four facts to carry:

1. **It is general.** Every attribute, not just `name` (H).
2. **Any whitespace triggers it**, not just a newline (B, C).
3. **Exactly one following token is consumed** (I) — the rest of the string still parses.
4. **`key=""` is the way to write an empty value** (D). It reports found = 1 with an empty
   value, which is what a producer wants.

Bonus quirk worth a leg of its own: a trailing `key=` at end-of-string reports
**found = 0** (E, K), so an empty value at the end is indistinguishable from an absent
attribute. Any code testing `xctx->tok_size` to mean "the attribute exists" is reading
that as absent. Not the bug you are fixing — record it, do not chase it.

---

## Phase 1 — the known producer, and the class it belongs to

The reported instance is `place_symbol()`'s scope floater:

```c
src/actions.c:2626  my_mstrcat(_ALLOC_ID_, &prop, "name=", xctx->inst[n].instname, "\n", NULL);
src/actions.c:2627  my_mstrcat(_ALLOC_ID_, &prop, "flags=graph,unlocked\n", NULL);
```

`instname` is `""` — not NULL — when the scope symbol's `template=` carries no `name=`
token. `my_mstrcat` **skips** an empty argument (`util.c:783`) and keeps walking, so the
string it builds is `"name=\nflags=graph,unlocked\n…"`: correct C, wrong data.

Two shapes of fix, both small; pick one and say why in the diff:

- **`key=""`** — emit the quoted empty value, so the token stays present and reads back as
  empty (case D). Keeps the floater's property shape identical whether or not the symbol
  has a name.
- **omit the line** — `if(instname[0])` around the `"name="` append. Simpler, but the
  floater then has no `name` token at all, which is a different shape from the named case.

Lean toward `key=""` unless something downstream dislikes it — **check what reads the
floater's `name`** before deciding, do not assume.

### The class — this is the real work

**My earlier `my_mstrcat` audit asked the wrong question for this bug.**
`doc/claude/code_analysis/my_mstrcat_null_vararg_audit.md` swept all 150 call sites for
arguments that can be **NULL**, and correctly concluded that an empty string is harmless
*to `my_mstrcat`*. It is — but "harmless to `my_mstrcat`" is exactly what produces
`key=` with nothing after it, and that is this bug. The audit's own closing advice,
"Empty is fine, NULL is not", is true of the function and misleading for a caller building
a property string. **Do not treat that audit as having cleared this class.**

So there is a fresh, bounded sweep to run: **every `my_mstrcat` call that builds a
`key=` + value + MORE TOKENS property string, where the value can be empty.** From the
site list in that audit, the candidates to start from — none of these are verified, they
are where to look:

```
src/actions.c:1426   "name=l0 lab=", netname ? netname : "", " text_size_0=", szbuf, NULL
src/actions.c:1526   "name=", name, " dir=", dir, nums, NULL
src/actions.c:2626   "name=", instname, "\n", NULL                       <- the reported one
src/paste.c:105      "name=p1 lab=", lab, NULL                           <- value is LAST: see below
src/actions.c:2422   "name=p1 lab=", name, NULL                          <- value is LAST
src/actions.c:2446   "name=l1 lab=", name, NULL                          <- value is LAST
```

`actions.c:1426` is the one to look at hardest: it already carries the `netname ? netname
: ""` NULL guard, and that guard **produces exactly the empty value this bug is about** —
`lab=` followed by ` text_size_0=`, which by rule 3 above means `lab` swallows
`text_size_0=…`. If that reproduces it is a live defect in wire-label creation, not a
theoretical one. **Measure it before you believe it**, and measure it before you believe
it is safe.

Sites where the possibly-empty value is the **last** thing before the `NULL` terminator
are a different, milder case: they produce a trailing `key=`, which reads back as
*absent* (case E/K) rather than stealing anything. Decide whether that is acceptable and
say so; do not silently lump them in.

---

## Phase 2 — RED first

A natural RED exists for the reported site. On the shipped binary:

```
=== noname : instances=1 rects[2]=1        (type=scope symbol, template WITHOUT name=)
  rect2[0] name=<<flags=graph,unlocked>>
  rect2[0] flags=<<>>
=== named  : instances=1 rects[2]=1        (control, template="name=g1 value=1")
  rect2[0] name=<<g1>>
  rect2[0] flags=<<graph,unlocked>>
```

Fixture recipe: a `type=scope` symbol with one `PINLAYER` rect (so the
`rects[PINLAYER]==0` arm, which needs a selected ELEMENT, is skipped) and
`template="value=1"` — deliberately no `name=`. Place it with
`xschem place_symbol <sym>` (argc == 3, so `inst_props` is NULL). The floater is stored as
a rect on **layer 2** (`actions.c:2668`); read it back with
`xschem getprop rect 2 0 <token>` — note that is the **3-argument** form, the 2-argument
form errors with `xschem getprop rect needs <color> <n> <token>`.

Also put the 11-row tokenizer table above in the test as pure `xschem get_tok` legs. They
need no design, they run in milliseconds, and they are the thing that will catch anyone
who later "fixes" the tokenizer and breaks `tb_sar_adc.sch`. **Include case D and the
`dac_bridge_model= dac_buff` string explicitly** — those two are the guard rail on the
decision at the top of this prompt.

---

## HARD-WON TRAPS — these cost real time, do not rediscover them

**Verification**

1. **Subagents report confident wrong answers, including about code they claim to have
   read.** This issue exists *because* an adversarial verifier flagged `actions.c:2626`
   as a NULL bug; it is not one, `instname` is `""`. Two verifiers in that run reached
   opposite conclusions about the same variable on the same evidence. Reproduce
   everything yourself.
2. **The symptom of this bug looks exactly like a `my_mstrcat` NULL truncation.** It is
   not. Before blaming the concatenator, print the string it actually built.
3. **`git checkout <sha> -- <file>` writes the INDEX as well as the worktree**, and a
   later `git commit -a` then silently reverts your fix. Use
   `git show HEAD:src/<f> > src/<f>` — worktree only, `git status` stays at ` M`.
4. **Verify a "pre-fix" binary really is pre-fix** by running your new test against it and
   confirming it fails.
5. **A test leg that passes on absent or unparseable output is passing VACUOUSLY.** Ask of
   every leg: *what does this print when the feature is completely broken?*
6. **Scratch dirs: always `test_scratch` from `tests/headless/scratch.tcl`.** Throwaway
   probes go in the session scratchpad, never in the repo.
7. **A new test must end with `RESULT: ALL PASS (N checks)`** or `full_audit.sh`'s
   `is_pass()` scores it FAIL while every leg prints ok. `full_audit.sh` globs
   `test_*.tcl`, so there is nothing to register.
8. **C changes need `cd src && make`. The shell's cwd PERSISTS across tool calls** — a
   later `./src/xschem` from inside `src/` fails with "No such file or directory".
9. **`perl -0pi -e 's/\Q...$var...\E/.../'` INTERPOLATES `$var` TO EMPTY.** Use python,
   assert the pattern was found, and write at the end.

**Environment**

10. **The GUI arm is unreliable on this box (WSLg).** This issue is fully headless.
11. Run suites with
    `SUITE_TIMEOUT=900 GUI_GATE=0 tests/headless/run_suites.sh --nogui <names>`, **never a
    bare loop**.
12. The Bash safety classifier was unavailable for ~40 minutes during the 0180 session.
    Read-only commands kept working; anything that *executes* a binary was blocked. Do
    read-only analysis and retry — it clears.

**Facts already established — do not re-derive**

13. `my_strdup` (`util.c:193`) NULLs its destination for an absent **or empty** source;
    `my_strdup2` (`util.c:718`) does not. `get_tok_value()` **never** returns NULL.
14. `my_mstrcat` (`util.c:768`) **skips** empty arguments and keeps walking; only NULL
    stops it (NULL is its end-of-list sentinel and cannot be changed). That skip is what
    creates this bug.
15. `set_inst_flags()` (`actions.c:972`, called unconditionally from `place_symbol()` at
    `:2608`) fills `instname` via `my_strdup2(get_tok_value(...))`, so it is `""` and
    never NULL from that point on. Measured under `-d 1`: the trace prints `instname=`,
    not `(null)`.
16. All three shipped scope symbols (`xschem_library/devices/scope.sym:24`,
    `scope2.sym:24`, `scope_ammeter.sym:24`) carry `template="name=l1"`, so the reported
    site needs a hand-authored symbol. That narrowness is about the *reported* site only —
    the class sweep in Phase 1 may not be narrow at all.

---

## Suites that must stay green (measured 2026-07-31, `--nogui` arm)

```
test_list_nets_null_token_0180        9
test_hash_extra_node_warn_0165       15
test_tedax_extra_pinnumber_0179      10
test_resolved_net_attr_scope_0163    34
test_resolved_net_templ_fallback_0164 23
test_resolved_net_bus_global_0157    19
test_resolved_net_hash_bus_0158      21
test_hash_label_crash_0156           23
test_ase_unnamed_net                 28
test_prep_result_contamination_0155  12
```

Plus `tests/stable_handles/net_body.tcl`, **39 PASS / 0 FAIL on the `--nogui` arm** (an
older note records 35/4 — that is the GUI arm). It writes to `/tmp/sh_net_test.log`, not
stdout: `cd src && ./xschem --nogui -q --script ../tests/stable_handles/net_wrap.tcl`.

**`tests/netlist_diff/netlist_diff.sh <old-binary>` is strongly advised if you touch
anything in the class sweep.** Property strings feed every backend. 189 schematics x 5
backends, 920 netlists diffed, a few minutes. It came back `BYTE-IDENTICAL` for
0180/0181. If your change is producer-side and correct it should stay that way — and if it
does not, `tb_sar_adc.sch` is the first file to look at.

## How I want you to work

1. Reproduce the symptom yourself before trusting any of this prompt.
2. The producer-vs-tokenizer question is decided **on measured evidence**, not opinion.
   Implement producer-side; if you think the evidence is wrong, bring evidence.
3. Fix the reported site, then run the class sweep. `actions.c:1426` is the one most
   likely to be a second live defect — it is in wire-label creation, which users touch
   constantly.
4. Issue doc updated with what you actually established. Commit. Raise the review gate.
   **Never push.**
5. Report what you verified, what you did **not**, and any judgement call I should weigh
   in on.
