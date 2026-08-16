# Casemode batch — the 13 decisions

Settled 2026-08-16 with the user, one question at a time, before any code was
written. Companion docs: `OPEN_QUESTIONS.md` (how each question was posed),
`DESIGN_REVISION.md` (the read-path redesign that came out of question B2),
`PLAN.md` (the 15 items, now partly superseded — see §3).

Everything below is a **decision**, not a recommendation. Where the user's answer
differed from the recommendation, that is noted, because the reasoning is worth
keeping.

---

## 1. The decisions

### A1 — Default mode for a fresh profile: **`fold`** (option c)

`fold` is the default everywhere. `preserve` and `distinguish` are both opt-in.

**User's reasoning, which overturned the recommendation:** support what a person
gets from `apt install`, or what someone who clones this repo and does not build
`ver_50` will have. `preserve` does not exist in released ngspice.

**Why the recommendation (`preserve` default) was wrong:** a fresh profile
proposing `preserve` on a stock ngspice means the flag is accepted and ignored,
the probe returns nothing, and requested-vs-measured mismatch. Under A2 that
prints a warning — **on every run, forever, for a user who never asked for any
of this**. The recommendation had conflated three different "defaults": what a
user with no profile gets, what the dialog pre-fills, and what we request when a
profile is silent. Only the middle one was arguable, and it is answered below.

**Consequence — the dialog pre-fill is probe-driven, not a constant.** On
registering a simulator we probe it. No case support ⇒ pre-fill `fold` and offer
nothing else. Case support ⇒ the dropdown offers what the binary can actually
deliver, e.g. "supports: fold, preserve, distinguish". Nobody can select a mode
their simulator will silently ignore.

### A2 — `.spiceinit` override: **no `-n`, probe and report** (option a)

Do not pass `-n`. Probe with the real argv from the deck's own directory, run in
whatever mode came back, and report in the log and CIW when it differs from the
request. Add a **per-profile `-n` checkbox** for a user who knows their
`.spiceinit` is the problem.

**Measured, and wider than `PLAN.md` records:** the plan says this is about a
`.spiceinit` beside the deck. `~/.spiceinit` — the home directory — overrides
too:

```
no .spiceinit anywhere,  -D casemode=preserve  ->  preserve
~/.spiceinit says fold,  -D casemode=preserve  ->  fold
```

That kills any shortcut like "check for a `.spiceinit` next to the deck". The
simulator must actually be asked.

Not a bug: the ngspice side confirmed the precedence is deliberate. With `fold`
as the A1 default, this warning never fires for a stock user — only for someone
who deliberately requested a mode and did not get it.

### B1 — Scope of the mode setting: **per profile, with a global floor** (option a),
### implemented by **extending the existing `sim()` machinery** (option i)

The mode is a property of a specific binary, not a user preference. It rides on
the simulator profile. A global default underneath serves the path with no
profile at all.

**This supersedes `PLAN.md` item 6**, which proposed a brand-new registry file
`$USER_CONF_DIR/ase_simulators`. xschem **already has** a simulator
configuration system, and building a second one beside it was wrong:

| what | where |
|---|---|
| GUI | `Simulation > Configure simulators and tools` — `simconf`, `src/xschem.tcl:3092` |
| settings file | `$USER_CONF_DIR/simrc` (typically `~/.xschem/simrc`) — plain Tcl, hand-editable |
| rc route | `cadence_style_rc` or any `--script` rc — plain Tcl, sets the same globals |

**The actual gap** is that ASE-L ignores all of it. `run_cmd` (`src/ase.tcl:3238`)
is one hardcoded line:

```tcl
proc run_cmd {state deckpath} { return [list ngspice -b $deckpath 2>@1] }
```

A bare `ngspice` off `PATH`. So today ASE-L cannot be pointed at a specific
simulator at all; casemode is one consequence of that, not the whole of it.

**The wrinkle that forces new fields:** existing `sim($tool,$i,cmd)` entries are
free-form command *strings* with substitutions — one is
`{$terminal -e {ngspice -i "$N" -a || sh}}`, with ngspice nested inside a
terminal launch. You cannot reliably extract "which token is the executable"
from an arbitrary shell string. So the rows gain structured fields:

```tcl
set sim(spice,5,name)     {Ngspice ver_50 (case-capable)}
set sim(spice,5,exe)      {/home/qflow/dev/ngspice_test/build-ver_50/src/ngspice}
set sim(spice,5,args)     {}
set sim(spice,5,casemode) preserve
set sim(spice,n)          6
```

Existing `cmd` strings are untouched and keep driving the Simulation menu. The
new fields are additive, so no existing `simrc` breaks.

### B2a — Resolving a file's mode: **explicit → header → schematic comparison → sniff**

Four sources, in that order. Two of the four are new to the plan.

**New source, ranked first: an explicit user setting, in the GUI.** The raw is
loaded in the viewer, so that is where the control belongs — showing what was
detected and allowing an override.

**New source, ranked third, replacing the plan's sniff: compare the raw's names
to the schematic's net names.** The plan's sniff looked at the raw *alone*
("are there capitals?"), with no reference point. Comparing against a schematic
whose true spelling we know is strictly better, and it detects a third outcome
the capital-sniff cannot:

| net drawn `MidNode`, raw says | verdict |
|---|---|
| `v(midnode)` | folded |
| `v(MidNode)` | case kept |
| `v(MIDNODE)` | **uppercased — neither** |

Row 3 is Xyce's shape. The capital-sniff calls it `preserve` and is wrong; the
comparison correctly reports "this simulator has its own convention".

**Its limits, recorded so nobody over-trusts it:** it needs a schematic, so the
File→Open-raw path may have none; an all-lowercase design gives no signal at
all; it must compare only against names the schematic owns, never against
simulator-constructed names (`i(V.X1.Vp)`, `v(v-sweep)`, hierarchy-prefixed
nodes, `.include`d PDK content); it cannot separate `preserve` from
`distinguish` (both keep capitals — treat case-kept as `preserve`, the safe
reading); and it wants a "most of them agree" rule, not a single hit.

**One consequence of the explicit override:** folding is destructive — once
`v(EN)` is lowercased the capitals are gone from memory. So a mode change on a
loaded file must **re-read** it, not flip a flag. Under `DESIGN_REVISION.md`
this becomes nearly moot, since nothing folds on read any more.

### B2b — "No answer" means **unknown, never `fold`**, permanently

Behaviour is the same either way (fold). The difference is that we do not record
a fact we did not establish: the UI says "mode unknown" rather than asserting
`fold`, and a later fallback has something to hang off.

**Permanent** because the upstream patch that would make the header appear by
default is **written and not sent**. Until it ships *and* propagates into
releases, absence keeps meaning "old simulator, or nobody asked".

### B3 — Auto-probe on registration: **only for `ngspice`-named executables** (option a)

Auto-probe on Add when the executable's filename contains `ngspice`
(case-insensitively). Everything else gets a **Test** button.

**Distinction the plan blurs, now recorded:** there are two probes.
The **capability probe** at registration answers "can this binary do casemode at
all?" — there is no deck yet. The **run probe** before each simulation, from the
deck's directory, answers "what mode will *this run* get?" and is the one
`.spiceinit` can override (A2). B3 is only about the first.

**Why the name gate:** `casemode` is an ngspice feature, so an ngspice-named
binary is the only one where the probe can return anything useful — and it
avoids auto-launching a licensed simulator (Spectre, a commercial Xyce) that may
check out a license or take seconds to start, merely because someone typed a
path.

**Mandatory regardless of this decision: the probe needs a hard timeout.** Hit
live during this session — the probe pipes commands into ngspice's interactive
mode, and a missing `quit` blocks forever. The first attempt hung for two
minutes. In a GUI dialog that is a frozen window.

### B4 — Requested ≠ measured: **split by mode** (option d)

- Requested `preserve`, got `fold` → **run and report**. Cosmetic: same circuit,
  same numbers, lowercase labels. Blocking work over that would be silly.
- Requested `distinguish`, got anything else → **refuse**.

**Why the split** (this overturned a flat "run and report"): the two modes fail
differently. A `distinguish` downgrade means the simulator merges nets the user
deliberately kept separate. **Same deck file, different circuit.** The run exits
cleanly and the numbers are wrong — the exact silent-wrong-answer class A1
avoided. And on a stock binary the merge is completely silent, because the
fold-collision warning does not exist there.

Consequence: `distinguish` can only ever run on a binary confirmed to support
it, immediately before the run. That is what a strict mode should mean.

Three ways a mismatch survives the other decisions: a hand-edited `simrc`/rc
naming a mode the binary cannot do; a `.spiceinit` override; and the binary
changing under the path (ver_50 has moved three times in four days).

### C1 — Phantom `v(all)`: **leave it, document it, cite upstream** (option c)

No filter, no warning. Documentation lands in item 15; `PLAN.md` §5.10 stays a
documented hole rather than becoming an item.

**The documentation must name both forms.** Every existing note records only
`v(all)`. Measured 2026-08-16 — the current form exists too:

| what you run | released ngspice-46 | ver_50 |
|---|---|---|
| `op`, record exactly one **voltage** | `v(in)` **`v(all)`** | clean |
| `op`, record exactly one **current** | `i(v1)` **`i(all)`** | clean |
| `op`, two signals / nothing | clean | clean |
| `tran` or `dc`, one signal | clean | clean |

The phantom carries the **same value** as the real signal — a duplicate column
with a wrong name. `tran`/`dc` escape because their sweep axis (`time`,
`v-sweep`) already makes the count two; only `op` has no axis.

Fixed on ver_50 by upstream `0064`; broken on every release. ASE-L emits one
`.save` per output row, so a one-output `op` session hits it every time — unless
`.options savecurrents` is on, which adds signals and pushes the count past one.

### C2 — Schematic net-case collapse: **fire only on genuine disagreement, and warn** (option c, corrected)

Fire under `fold` and `preserve`; **stay silent under `distinguish`**; warn
rather than error. Assume `fold` when no profile is set (the conservative
direction). Relay ngspice's own warning as-is.

**The option as originally written was backwards**, and the user caught it. The
option said "warn under fold/preserve, error under distinguish", from a lazy
intuition that strict mode deserves strict errors. The semantics run the other
way:

| mode | ngspice sees | xschem sees | agree? |
|---|---|---|---|
| `fold` | one net | two nets | **no — hazard** |
| `preserve` | one net | two nets | **no — hazard** |
| `distinguish` | two nets | two nets | **yes — nothing wrong** |

xschem's net table compares with `strcmp` (`node_hash.c`), so `Out` and `OUT`
genuinely **are** two nets in xschem. `distinguish` is the only mode that agrees
with what the schematic shows. There is nothing to report there — and a warning
that fires when nothing is wrong teaches people to ignore warnings.

So the check is not "you named two nets similarly". It is **"xschem and the
simulator disagree about how many nets you have"**.

Warn rather than error because our netlister cannot see nets arriving via
`.include`d PDK files, and a blocking error built on an admittedly incomplete
check is a bad thing to ship.

**Relaying upstream's warning is unaffected** — theirs already names the outcome
("one node" vs "two nodes"), so it is informative under `distinguish` rather
than alarming. Two mechanics: it is parse-time, so a deck cannot capture it from
inside `.control` (scrape the run log), and it repeats **once per subcircuit
instantiation**, so dedupe on the quoted pair.

### C3 — `.save` of an absent signal: **build both defences** (option a)

1. **Pre-flight refusal** — check every `.save`/`print` name against the netlist
   before generating the deck; refuse and list the offenders.
2. **Content-based rejection** — recognise the constants file on read
   (`Plotname: constants`, `Date:` == build stamp, a variable-count floor, and
   the `set appendwrite` shape where it hides behind a real plot) and refuse to
   attach it as a successful result.

**Measured live 2026-08-16 on today's ver_50 build — identical to stock:**

```
ver_50  rc=1 | Plotname: constants | No. Variables: 12 | names the bad token: 0
stock   rc=1 | Plotname: constants | No. Variables: 12 | names the bad token: 0
```

**This is why it differs from C1:**

| | C1 phantom `v(all)` | C3 absent `.save` |
|---|---|---|
| ver_50 | **fixed** (`0064`) | **not fixed** |
| upstream trajectory | awaiting release | fix **withdrawn three times** |
| symptom | one extra row, correct value | plot silently empty |
| long-term reach | installed base only | **everyone, indefinitely** |

"Wait for upstream" is not a route here. And one half is entirely ours: even if
ngspice never changes, xschem must not present a twelve-constants file as a
successful attach.

`rc=1` on both binaries is a free corroborating signal — but it arrives **with
the constants file already written**, so it cannot replace the content check.

### C4 — The `$sim_status` guard: **all three defences** (option a)

The guard joins C3's two; none is redundant.

| defence | catches | blind to |
|---|---|---|
| pre-flight | names the *specific bad expression*, before any simulator starts | names absent from the netlist because they came from an `.include`d PDK file |
| `$sim_status` guard | any failed analysis, **leaving no artefact at all** | any file we did not generate |
| content check | a bad file from anywhere — old, another tool's, pre-guard | cannot say *why* it is bad |

Guard shape, measured on both binaries (bad run ⇒ rc=1, `RUN-FAILED`, **no file
written**; good run ⇒ rc=0 and the real file):

```
op
if $?sim_status = 0
  echo NO-SIM-STATUS
end
if $sim_status ne 0
  echo RUN-FAILED
  quit 1
end
remzerovec
write <abs path>
```

**Two traps recorded:** `$sim_status` does not exist before the first analysis
(hence the `$?` check), and it is **last-writer-wins per analysis** — so the
guard must be emitted after **each** analysis, or a failed `op` is masked by a
successful `tran`.

The content check is the cheapest of the three (one comparison against
`Plotname:`) and is the only one protecting `File → Open` on a raw someone hands
you, and the only one that survives if `$sim_status` changes meaning upstream.

### D1 — Legacy session files: **the pre-flight offers the fix** (option c)

Not an automatic silent re-case pass. The pre-flight from C3 is *already*
computing the comparison a re-case pass needs, so it lists the corrections it
found (`v(en)` → `v(EN)`, twelve of them) and applies them **on confirmation**.

**Why not automatic:** silently rewriting a user's saved session means that if
our netlist map is wrong about something, we corrupt saved work with no trace.

**Scope note:** this is `distinguish`-only. Under `preserve` a folded `.save`
resolves (upstream `0056`) — non-issue. And with `fold` as the A1 default,
`distinguish` is a deliberate opt-in.

### D2 — Case collisions in the index: **no alias when two names collide** (option b)

Most of D2 was **dissolved by `DESIGN_REVISION.md`**: VCD already stores names
verbatim, and the lookup becomes case-insensitive for every reader, so "mark VCD
as preserve" is not a separate sub-project. What remained is the collision rule.

VCD is where a case collision is *legitimate* — Verilog is case-sensitive, so
`Count` and `count` are two real signals. Rule: **build no folded alias when two
stored names fold to the same key.**

| VCD has `Count` **and** `count`; query | first-wins | no alias on collision |
|---|---|---|
| `Count` | `Count` | `Count` |
| `count` | `count` | `count` |
| `COUNT` | **arbitrarily `Count`** | nothing — correct, it is ambiguous |

| VCD has only `Count`; query | first-wins | no alias on collision |
|---|---|---|
| `count` | `Count` | `Count` — still helpful |

Keeps every helpful case, drops only the guess. `vcd_read.c:140` stops being an
apology and becomes a statement of the rule.

### D3 — Backannotation: **the perfect fix — one lookup authority, lazy view** (all three properties)

The user asked for the correct design regardless of cost. The posed options
(a)/(b)/(c) were all wrong: each kept two lookup authorities and argued about
how to paper over the seam.

**The real defect**, found by grep during the discussion —
`ngspice::get_diff_voltage` (`src/xschem.tcl:2688`):

```tcl
set n [string tolower $n]                              ;# folds the query
set nn $path$n
set errn [catch {set ::ngspice::ngspice_data($nn)} resn]
if {$errn} {
  set nn v(${path}${n})                                ;# the v() wrap rung
  set errn [catch {set ::ngspice::ngspice_data($nn)} resn]
}
```

That is **a second copy of `get_raw_index`'s ladder** — its own `tolower`, its
own `v(...)` fallback — in Tcl, in another file. Every case rule decided in this
document would apply to one authority and not the other, forever.

**The three properties:**

1. **One lookup authority.** `get_raw_index` is it. Backannotation calls it
   instead of reimplementing it; the Tcl-side `string tolower` and the
   hand-rolled `v(...)` rung are **deleted, not ported**.
2. **The query carries the schematic's own spelling** (`EN`, not `en`). Then
   `distinguish` exact-matches `v(EN)` and `fold` falls back to `v(en)` — and
   **the mode never appears in backannotation code at all**. The special case
   disappears rather than getting a branch. D3's original question ceases to
   exist: there are no keys, so keys cannot collide.
3. **`ngspice_data` becomes a lazy view, not an eager copy.** Today every
   operating-point read does one `Tcl_SetVar2` per variable, duplicating a
   database that already exists in C. A Tcl **read trace** turns
   `$ngspice::ngspice_data(v(en))` into an on-demand callback. Kills staleness,
   duplication, and per-variable Tcl churn.

**Why property 3 is reachable:** every consumer is an indexed read —
`catch {set ::ngspice::ngspice_data($n)}` — and **nothing in the tree
enumerates the array.** No `array names`, no `array get`, verified by grep. That
is what makes a lazy array a drop-in.

**Costs, accepted:**

- `info exists ngspice::ngspice_data` is an "is data loaded?" test
  (`actions.c:4081`); the array must still exist, so one sentinel element or the
  existing `n vars` key stays real.
- Five sites do `array unset` / `Tcl_UnsetVar` to clear it (`callback.c:1452`,
  `save.c:1888`, `:1918`, `:1959`, `:1991`); those become trace resets.
- An out-of-tree **user** script doing `array names` would get nothing.
  Mitigable — the trace can populate on first enumeration.
- This is C-side Tcl API work in a file that currently only pushes values.

**Supersedes `PLAN.md` §5.7** ("backannotation is left folding and keeps
working; under distinguish it will break — accepted for this batch"). It no
longer breaks under `distinguish`, and it no longer folds.

---

## 2. Cross-cutting requirements these decisions created

1. **The probe needs a hard timeout** (B3). Non-negotiable — a missing `quit`
   hangs it forever, verified live.
2. **The `$sim_status` guard is emitted after every analysis**, not once (C4).
3. **`ngspice_data` keys**: `DESIGN_REVISION.md` §6 ruled they stay folded for
   compatibility. **D3 supersedes that** — with a lazy view there are no stored
   keys at all, and the resolver honours the case rules directly.
4. **Pre-item-1 test sweep.** Roughly 20 headless suites touch
   `raw read`/`raw list`. `DESIGN_REVISION.md` changes what a VCD or table file
   lookup returns, and the "audit diff must be empty" rule means this is swept
   **before** item 1, not after.
5. **Xyce is unverified.** `PLAN.md` asserts Xyce writes `V(EN)` uppercase;
   there is no Xyce on this machine and it has not been measured. Either obtain
   a Xyce raw, or keep a Xyce-specific fold. Open.

---

## 3. What this does to `PLAN.md`

| plan item | status after these decisions |
|---|---|
| 1 `Raw.case_mode` + reader gate | **reshaped** — delete the fold outright; `Raw` gains a boolean `case_sensitive`, set only by `distinguish` (`DESIGN_REVISION.md`) |
| 2 `get_raw_index` ladder | **simplified** — one ladder: exact → folded alias (skipped on collision, D2) → `v()` wrap → `i(v.x` fixup, plus the `@dev[param]` shape |
| 3 `sim_case_mode` global + `auto` sniff | **mostly dissolved** — the File→Open-raw path no longer needs a mode. What survives is the requested mode on the profile (B1) and the four-source resolution order (B2a) |
| 4 the four `hilight.c` senders | unchanged |
| 5 viewer Tcl matching + browser scan | **narrowed** — only `distinguish` needs it |
| 6 profile registry | **replaced** — extend `sim()`/`simconf`/`simrc` (B1 option i), not a new `ase_simulators` file |
| 7 the capability probe | unchanged + **hard timeout** (B3) |
| 8 profile-aware `run_cmd` + mismatch report | **reshaped** by B4(d) — refuse on a `distinguish` mismatch |
| 9 `sod_expr` stops folding | unchanged |
| 10 pre-flight + empty-raw reject | **widened** — three defences (C3 + C4), and the pre-flight also offers legacy corrections (D1) |
| 11 `result_probe` `-nocase` | unchanged |
| 12 post-load current repair | unchanged |
| 13 `Setup > Simulator…` dialog | **relocated** — extends the existing `simconf` dialog (B1 i); probe-driven pre-fill (A1); auto-probe gated on the name (B3); Test button |
| 14 netlister fold-collision + `model_name()` | **reshaped** by C2 — fire only under `fold`/`preserve`, warn, relay upstream's |
| 15 docs | **widened** — must name both `v(all)` and `i(all)` (C1) |
| §5.6 / D2 VCD sub-step | **absorbed** into item 2 |
| §5.7 backannotation limitation | **superseded** by D3 |
| §5.10 phantom `v(all)` | stays a documented hole (C1) |
| — | **NEW item: unify the lookup authority + lazy `ngspice_data`** (D3) |
| — | **NEW pre-work: sweep ~20 suites for lowercase assertions** (§2.4) |
