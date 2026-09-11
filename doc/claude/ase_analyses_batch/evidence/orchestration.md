# ngspice multi-run orchestration — dossier for the ASE-L GUI plan

Scope: everything ADE calls **parametric analysis**, **corners**, **statistical (Monte Carlo)**,
**temperature sweep**, plus how a multi-run campaign is launched, monitored, aborted and
post-processed. Written for a future Claude Code session building ASE-L in
`/home/analog/dev/xschem-claude/src/ase.tcl` / `ase_window.tcl`.

Source tree: `/home/analog/dev/ngspice`, branch `ver_50`, `git describe = ngspice-46-419-gccebdf2a2`.
Binary used for every experiment below: `/home/analog/dev/ngspice/build-ver_50/src/ngspice`
(reports `ngspice-46+`, build date Thu Sep 3 06:46:24 UTC 2026, KLU present, `USE_OMP 1`).
All decks and captured output live in
`/tmp/claude-1000/-home-analog-dev-ngspice/aa67b095-6376-4408-9db3-5c2a5c1d3f85/scratchpad/work/`.

Line references are `path:LINE` relative to `/home/analog/dev/ngspice`.
Documentation references are to the official manual (Ngspice User's Manual v46/v47),
<https://ngspice.sourceforge.io/docs/ngspice-manual.pdf> and
<https://ngspice.sourceforge.io/docs/ngspice-html-manual/manual.xhtml>.

---

## 0. The headline fact

**ngspice has no `.STEP`, no corner statement, no `.MC`/`.DATA` card, and no built-in
statistical analysis.** `grep -rn '"\.step"' src/frontend/ src/spicelib/parser/` returns
nothing (the only `.step`-looking hits are `div_list[i].step` in
`src/frontend/plotting/grid.c:587`). The only "sweep of a sweep" the *simulator* offers is
the second source of `.dc` (`src/spicelib/analysis/dctrcurv.c`), and `temp` is accepted there
as a pseudo-source (`dctrcurv.c:144`, `dctrcurv.c:453` `TEMP_CODE`).

Everything else — parameter sweeps, corners, Monte Carlo, temperature sweeps, and the
collection of results across runs — must be **synthesised by the GUI as ngspice
control-language code inside a `.control … .endc` block** (or an `*ng_script` file).
The manual says the same thing: the shipped example
`examples/various/param_sweep.cir:1-4` is titled "parameter sweep … replaces `.STEP R1 1k 10k 1k`,
chapter 16.13.4.2".

So ASE-L is not "driving an analysis"; it is **a code generator for a small imperative
language**. The rest of this dossier is the specification of that language's relevant
surface, its exact semantics, and its traps.

---

## 1. The control language: what a generator may rely on

### 1.1 Block constructs

Registered as keywords with `NULL` handlers in the command table and interpreted by the
control-structure machine, not by a command function:

| keyword | table entry | interpreter |
|---|---|---|
| `while <cond>` | `src/frontend/commands.c:568` | `src/frontend/control.c:294` (`CO_WHILE`) |
| `repeat [n]` | `src/frontend/commands.c:572` | `src/frontend/control.c:372` (`CO_REPEAT`) |
| `dowhile <cond>` | `src/frontend/commands.c:576` | `src/frontend/control.c:336` (`CO_DOWHILE`) |
| `foreach var w1 w2 …` | `src/frontend/commands.c:580` | `src/frontend/control.c:462` (`CO_FOREACH`) |
| `if <cond>` / `else` / `end` | `src/frontend/commands.c:584,588,592` | `src/frontend/control.c:429` (`CO_IF`) |
| `break [n]` / `continue [n]` | `src/frontend/commands.c:596,600` | `src/frontend/control.c:506,516` |
| `label <name>` / `goto <name>` | `src/frontend/commands.c:604,608` | `src/frontend/control.c:533,526` |

Semantics that matter to a generator:

* **`repeat` with no argument loops forever** (`src/frontend/control.c:724`,
  `co_numtimes = -1`). A GUI must never emit a bare `repeat`.
* **`repeat -3`** prints `Error: can't repeat a negative number of times` and becomes 0
  iterations (`src/frontend/control.c:743`).
* An **empty `while`/`repeat` body** prints a warning and (for `while`) spins calling
  `cp_periodic()` (`src/frontend/control.c:296,374`).
* **`dowhile` runs its body before testing** (`src/frontend/control.c:336-368`) — it is a
  *do…while*, not a *while*. Every shipped Monte Carlo example uses `dowhile` with the
  counter pre-initialised to 0, so the body always executes at least once even if the
  bound is 0. For "run N times where N may be 0" the GUI must use `while`.
* **`break n` / `continue n`** unwind *n* loop levels (`src/frontend/control.c:506-524`).
* **`goto`/`label` are byte-exact and case sensitive**: `findlabel()` uses `eq()`
  (`src/frontend/control.c:66,69`), not `cieq()`. `goto Next` will not find `label next`.
* `goto` can only jump to a label in the current block or an enclosing one; jumping *into*
  a loop is structurally impossible (comment at `src/frontend/control.c:271-277`).
* `foreach`'s word list is **globbed before variable substitution**
  (`src/frontend/control.c:463`: `cp_variablesubst(cp_bquote(cp_doglob(...)))`), whereas an
  ordinary command line is **substituted before globbing** (`src/frontend/control.c:149`
  then `:157`). The two orders differ; generated code that relies on `{$var}` inside a
  `foreach` list is relying on the *other* order.
* The loop variable of `foreach` is a **shell variable (string)**, set with
  `cp_vset(..., CP_STRING, ...)` at `src/frontend/control.c:466`. It is *not* a vector, so
  it can be used as `$c` but never as a bare operand of `let`/`while`.

### 1.2 Two disjoint namespaces — the single biggest generator hazard

| | created by | read as | lives in |
|---|---|---|---|
| **variable** (string/num/bool/list) | `set`, `setcs`, `foreach`, `option` | `$name` | global list `variables`, `src/frontend/variable.c` |
| **vector** (numeric array) | `let`, `compose`, `meas`, an analysis | bare name in expressions, `$&name` | the *current plot* |

`while`/`dowhile`/`if` conditions are evaluated by `cp_istrue()` →
`ft_getpnames()`/`ft_evaluate()` (`src/frontend/cpitf.c:360-375`), i.e. **the expression
parser, which sees vectors only**. Writing `set n = 4` and then `dowhile m < n` does *not*
work: `n` is a variable, the parser reports
`Warning from checkvalid: vector n is not available or has zero length` and — critically —
**the loop does not abort**; `cp_istrue()` returns `!vec_iszero(NULL)`, i.e. false, so a
`dowhile` silently runs its body exactly once. Measured: my first cut of
`ref_orchestrate.cir` did exactly this and executed 9 of the intended 36 runs while
reporting no error other than a warning on stderr.

Corollary rules for the generator:
1. **All loop bounds and counters must be `let` vectors.**
2. `$&vec` converts a vector back to a string (via `cp_enqvec_as_var`,
   `src/frontend/options.c:52-56`); `let v = $var` converts a variable to a vector.
3. A vector created while plot *P* is current is invisible once another plot becomes
   current. Always `setplot <collector>` immediately before touching collector vectors, and
   address foreign vectors as `{$plotname}.vecname`.

### 1.3 Comparison operators, and names a generator must never use

Numeric/relational operators (`src/frontend/parse.c:314-341`):
`+ - * / % ^ , = > < >= <= <> & | ~ [ [[ ?:` — note `=` is **equality** in a condition and
`~` is **not** (there is no `!`).

The lexer additionally accepts the word forms `gt lt ge le ne eq or and not`
(`src/frontend/parse.c:855-889`). It does so with a **prefix test** that only requires the
next character to be in
`specials = " \t%()-^+*,/|&<>~="` (`src/frontend/parse.c:842`). Consequence, verified:

```
* E24
R1 in eq 1k
.control
op
print v(eq)          -> PPerror: syntax error in line segment  v(eq)  near  )
let le = 5
print le             -> PPerror: syntax error in line segment  le  near  le
let y = le + 1       -> PPerror ... Error: RHS "le + 1" invalid
.endc
```

**A net or vector named `eq le ge lt gt ne or and not` is unusable in the control
language.** ASE-L must (a) never generate such loop-variable names, and (b) warn when the
schematic contains such a net before it offers a measurement on it.

### 1.4 `$` substitution swallows `.` `-` `(` `[` `&` `#` `?` `@` `_`

`cp_variablesubst()` (`src/frontend/variable.c:931`) delimits the name with
`span_var_expr()` (`src/frontend/variable.c:887`), whose accept set is
`isalnum` plus `VALIDCHARS "$-_<#?@.()[]&"` (`src/frontend/variable.c:875`). So
`deck_$c.cir` parses the variable name as `c.cir`. Verified:

```
* E9b
set c = tt
echo "plain:      >deck_$c.cir<"     ->  Error: c.cir<: no such variable.
                                         plain:      >deck_
echo "braced:     >deck_{$c}.cir<"   ->  braced:     >deck_tt.cir<
set n = 3
echo "num braced: >mc{$n}.out<"      ->  num braced: >mc3.out<
let v = 7
echo "vector amp: >run{$&v}.out<"    ->  vector amp: >run7.out<
```

**Rule: always emit `{$var}` / `{$&vec}`, never bare `$var`, when the value is followed by
anything other than whitespace.** (The brace form works because substitution runs first and
brace-globbing second — `src/frontend/control.c:149` then `:157`.)

### 1.5 `$&vec` loses precision by default

`cp_varwl()` formats a `CP_REAL` with `"%G"` — 6 significant digits — unless the variable
`csnumprec` is set, in which case `"%.*g"` with that precision
(`src/frontend/variable.c:51-56`). Verified:

```
* E15
let x = 1234.56789012345
echo "default   $&x  = $&x"           -> default   1234.57  = 1234.57
set csnumprec = 17
echo "csnumprec $&x  = $&x"           -> csnumprec 1234.5678901234501  = 1234.5678901234501
unset csnumprec
alter r1 = $&x   ; print @r1[resistance]  -> 1.234570e+03      (6 digits, value corrupted)
alter r1 = x     ; print @r1[resistance]  -> 1.234568e+03      (full double)
```

**Rules:** either emit `set csnumprec = 17` once at the top of every generated control
block, or pass vectors to `alter`/`alterparam`/`let` **by name** rather than through `$&`.
`alter` evaluates its right-hand side with the expression parser
(`src/frontend/device.c:1425` `ft_getpnames_quotes`, `:1484` `ft_evaluate`), so a bare
vector name is legal and lossless.

### 1.6 `define` — user functions, needed for Monte Carlo

`define name(args) expression` (`src/frontend/commands.c:125`, `src/frontend/define.c`).
Used by every shipped MC example to re-create the netlist-level distribution functions in
the control language; see §5.2.

---

## 2. Plot naming and addressing — where a generator silently gets it wrong

### 2.1 How an analysis plot is named

Every analysis run calls `plotInit()` (`src/frontend/outitf.c:1207`), which calls
`plot_alloc(run->type)` (`:1209`). `plot_alloc()` (`src/frontend/vectors.c:1094`) maps the
analysis's long name to a prefix through `ft_plotabbrev()`
(`src/frontend/typesdef.c:331`), which **substring-matches** against the table
`plotabs[]` (`src/frontend/typesdef.c:67-89`):

```
tran  <- "transient"        op   <- "op"          tf    <- "function"
dc    <- "d.c." "dc" "transfer"                    ac    <- "a.c." "ac"
pz    <- "pz" "p.z." "pole-zero"                   disto <- "disto"   dist <- "dist"
noise <- "noise"            sens <- "sens" "sensitivity"   sens2 <- "sens2"
sp    <- "s.p." "sp"        harm <- "harm"        spect <- "spect"   pss <- "periodic"
```

The number is appended from the **single global counter `plot_num`**, and the counter is
only advanced when a *collision* is found:

```c
/* src/frontend/vectors.c:1104-1111 */
do {
    (void) sprintf(buf, "%s%d", s, plot_num);
    for (tp = plot_list; tp; tp = tp->pl_next)
        if (cieq(tp->pl_typename, buf)) { plot_num++; break; }
} while (tp);
```

`plot_num` is *shared across analysis types*. Verified (E8 — op, op, tran, ac, tran, ac, dc, op):

```
1: op1
2: op2
3: tran2        <- there is NO tran1
4: ac2          <- there is NO ac1
5: tran3
6: ac3
7: dc3          <- there is NO dc1 or dc2
8: op3
```

**A GUI must never construct a plot name. It must capture `$curplot` immediately after each
analysis command.** `$curplot` is computed live from `plot_cur->pl_typename`
(`src/frontend/options.c:93-96`).

Two further name mutations:

* **`destroy all` resets `plot_num = 1`** (`src/frontend/postcoms.c:1048`). After it, the
  next analysis plot is `<type>1` again. Any cached name is stale.
* **`linearize` creates a new plot.** Verified (E21b): raw `tran1` → linearized `tran2`,
  raw `tran3` → linearized `tran4`, name `Transient Analysis (linearized)`. `$curplot` must
  be re-read after `linearize`, `fft`, `psd`, `spec` and `cutout`.

### 2.2 Naming the *collector* plot deterministically

`setplot new` creates an "unknown*N*" plot titled "Anonymous"
(`src/frontend/vectors.c:1391-1400`), but `com_splot()` accepts up to three extra words that
overwrite typename, title and name (`src/frontend/postcoms.c:1211-1229`):

```
setplot new <typename> <title> <name>
```

Verified (E2):

```
setplot new sweep "Corner/param results" sweepdata
echo "collector plot typename = $curplot"   -> sweep
echo "curplotname  = $curplotname"          -> sweepdata
echo "curplottitle = $curplottitle"         -> "corner/param results"     <- quotes are literal
```

**This is the single most useful fact for the GUI**: the results plot can have a stable,
generator-chosen name (`setplot new aselres "ASE-L results" aseldata`) so every later
reference is `{$…}`-free and `aselres.bw` addresses a result directly. Note the title keeps
its quote characters and is lower-cased by the reader — do not round-trip it as an identity.

`set curplot = new` is the other spelling (goes through `cp_usrset` →
`plot_setcur("new")`, `src/frontend/options.c:424`, `src/frontend/vectors.c:1391`) but takes
no name arguments.

### 2.3 Selecting and addressing plots

* `setplot <name>` → `plot_setcur()` (`src/frontend/vectors.c:1388`) → `get_plot()`
  (`:1371`) which matches with **`plot_prefix()`**, a *case-sensitive prefix* match
  (`src/frontend/vectors.c:1621-1639`). Special words: `new`, `previous`, `next`
  (`:1393`, `:1406`, `:1424`).
* The prefix match has one guard: if the prefix's last matched character is a digit and the
  stored name continues, it fails (`src/frontend/vectors.c:1635`). So `setplot dc1` does
  **not** match `dc10`, but `setplot tran` matches the *first* `tran*` in
  `plot_list` — and `plot_list` is newest-first (`plot_new()` prepends,
  `src/frontend/vectors.c:1479-1483`), so `setplot tran` silently means "the most recent
  transient plot".
* `plotname.vecname` addressing is resolved in `vec_get_maybe_report()`
  (`src/frontend/vectors.c:796-812`) with the same `plot_prefix()`; `all.vecname` is the
  wildcard, and a **plot prefix that matches nothing silently falls back to the current
  plot** (`src/frontend/vectors.c:809-811`, with the comment "This used to be an error…").
  That is a silent-wrong-answer path: `let x = ac7.v(out)` when `ac7` does not exist reads
  `v(out)` from whatever plot happens to be current.
* `destroy <name>` matches with **`eq()`** — byte exact, no prefix
  (`src/frontend/postcoms.c:1053`). Asymmetric with `setplot`.
* `destroy` with no argument kills the current plot and moves `plot_cur` to a *neighbour*
  (`killplot()`, `src/frontend/postcoms.c:1090,1109`) — after `destroy $curplot` the current
  plot is arbitrary; always `setplot <collector>` next.
* `destroy all` deletes **every plot except `const`**, including the collector
  (`src/frontend/postcoms.c:1037-1048`). `examples/Monte_Carlo/MC_2_control.sp` uses it
  safely only because it writes each run to a file before destroying.
* `$plots` returns the list of plot typenames, **oldest first** (built by prepending while
  walking the newest-first list, `src/frontend/options.c:111-118`). Verified (E21b):
  `plots: const tran1 tran2 tran3 tran4 tran5 tran6`.

---

## 3. Parameter sweeps

There are exactly four mechanisms, with different reach and cost.

| mechanism | changes | needs re-parse | reaches `.param` users | reaches `.model` | reaches B-source expressions |
|---|---|---|---|---|---|
| `alter` | one instance parameter | no | no | no | no |
| `altermod` | one model parameter (or a whole model file) | no | no | yes | no |
| `alterparam` + `reset` | the stored deck text of a `.param` | **yes** | yes | yes | yes |
| `source <other deck>` | everything | yes (new circuit) | yes | yes | yes |

### 3.1 Working deck: sweep a `.param`, one analysis plot per value

`work/e1_param_sweep.cir`:

```spice
* E1 param sweep via alterparam + reset
.param rload = 1k
V1 in 0 dc 0 ac 1
R2 in out {rload}
C1 out 0 1n
.control
  set curplot = new
  set sweepres = $curplot            $ name of the collector plot
  let rvals  = vector(4)
  let f3db   = vector(4)
  let rvals[0] = 500
  let rvals[1] = 1000
  let rvals[2] = 2000
  let rvals[3] = 4000
  let i = 0
  dowhile i < 4
    setplot $sweepres
    set i = "$&i"
    let rnow = rvals[$i]
    set rnow = "$&rnow"
    alterparam rload = $rnow
    reset                       $ re-parse the deck so the .param takes effect
    ac dec 50 1k 10meg
    echo "run $i : analysis plot = $curplot , rload = $rnow"
    meas ac bw3 when vdb(out)=-3.0103 fall=1
    set dt = $curplot
    setplot $sweepres
    let f3db[$i] = {$dt}.bw3
    let i = i + 1
  end
  setplot $sweepres
  print rvals f3db
  echo "== plots =="
  setplot
.endc
.end
```

Actual output (`ngspice -b e1_param_sweep.cir`, blank lines stripped):

```
Note: No compatibility mode selected!
Circuit: * e1 param sweep via alterparam + reset
Reset re-loads circuit * e1 param sweep via alterparam + reset
Circuit: * e1 param sweep via alterparam + reset
Doing analysis at TEMP = 27.000000 and TNOM = 27.000000
Using SPARSE 1.3 as Direct Linear Solver
No. of Data Rows : 201
run 0 : analysis plot = ac1 , rload = 500
bw3                 =  3.18310e+05
... (runs 1..3, plots ac2 ac3 ac4) ...
                                   Anonymous
                                   unknown  Wed Sep  9 18:49:55  2026
--------------------------------------------------------------------------------
Index   rvals           f3db
--------------------------------------------------------------------------------
0	5.000000e+02	3.183103e+05
1	1.000000e+03	1.591551e+05
2	2.000000e+03	7.957752e+04
3	4.000000e+03	3.978873e+04
== plots ==
List of plots available:
	ac4	* e1 param sweep via alterparam + reset (AC Analysis)
	ac3	* e1 param sweep via alterparam + reset (AC Analysis)
	ac2	* e1 param sweep via alterparam + reset (AC Analysis)
	ac1	* e1 param sweep via alterparam + reset (AC Analysis)
Current unknown1	Anonymous (unknown)
	const	Constant values (constants)
Note: Simulation executed from .control section
```

Facts established:

* One plot per run, `ac1 … ac4`, retained; the collector is a separate plot.
* Plots are listed newest-first.
* `reset` prints `Reset re-loads circuit <title>` on **stdout** every time
  (`src/frontend/inp.c:551`). A GUI parsing stdout must filter it.
* `f3db` values are exactly `1/(2*pi*R*1n)` — the `.param` change really took effect.

### 3.2 `alterparam` semantics

`com_alterparam()` (`src/frontend/inp.c:1747`) **edits the stored deck text**, i.e.
`ft_curckt->ci_mcdeck` (`:1758`, `:1789`). It does nothing to the live circuit. The comment
at `src/frontend/inp.c:1743-1746` states: "Changes params in mc_deck. To become effective,
'mc_source' has to be called after 'alterparam'". `reset` also works, and is the better
choice (§5.5).

Forms (`src/frontend/inp.c:1741-1743`):
```
alterparam <pname> = <value>              # a global .param
alterparam <subcktname> <pname> = <value> # a parameter of a .subckt
```
Because subcircuit parameters have already been folded onto the `.subckt`/`X` lines by the
time the deck is stored, the subckt form rewrites the *n*-th positional value on the `X`
line (`src/frontend/inp.c:1789-1840`); see `examples/various/alterparam.sp` for the shipped
demonstration.

Edits accumulate in the stored deck, so a sweep needs only one `alterparam` per swept
parameter per iteration, and values persist until overwritten.

### 3.3 `alter` / `altermod` — no re-parse

`com_alter()` / `com_altermod()` → `com_alter_common()`
(`src/frontend/device.c:1216`, `:1230`, `:1290`). Accepted forms (comment at
`src/frontend/device.c:1207-1211`):

```
alter    @device[parameter] = expr
alter    device parameter   = expr
alter    device            = expr        # the device's "default" parameter
alter    @vin[pulse] = [ 0 5 10n 10n 10n 50n 100n ]     # vector-valued
altermod @model[param]      = expr
altermod mod1 [mod2 …] file = newparams.mod              # whole-model reload
```

Working deck, `work/e2_setplotnew.cir` — same sweep as §3.1 but with `alter` and **no
`reset`**:

```spice
* E2 named collector plot + alter (no re-parse)
V1 in 0 dc 0 ac 1
R2 in out 1k
C1 out 0 1n
.control
  setplot new sweep "Corner/param results" sweepdata
  let f3db = vector(4)
  let rvals = vector(4)
  let rvals[0]=500
  let rvals[1]=1000
  let rvals[2]=2000
  let rvals[3]=4000
  let i = 0
  dowhile i < 4
    setplot sweep
    set i = "$&i"
    let rnow = rvals[$i]
    alter r2 = $&rnow            $ instance value, no re-parse
    ac dec 50 1k 10meg
    meas ac bw3 when vdb(out)=-3.0103 fall=1
    set dt = $curplot
    setplot sweep
    let f3db[$i] = {$dt}.bw3
    let i = i + 1
  end
  setplot sweep
  print rvals f3db
  show r2 : resistance
  setplot
.endc
.end
```

Output (identical numbers, no `Reset re-loads` lines):

```
collector plot typename = sweep
curplotname  = sweepdata
curplottitle = "corner/param results"
... four AC runs, no reset messages ...
Index   rvals           f3db
0	5.000000e+02	3.183103e+05
1	1.000000e+03	1.591551e+05
2	2.000000e+03	7.957752e+04
3	4.000000e+03	3.978873e+04
== show what alter did to the instance ==
 Resistor: Simple linear resistor
     device                    r2
      model                     R
 resistance                  4000
```

### 3.4 When `alter` is NOT equivalent to `alterparam` + `reset`

`work/e3_alter_vs_param.cir`:

```spice
.param rr = 1k
V1 in 0 dc 1
R1 in mid {rr}
R2 mid 0 {rr*2}
.subckt div a b rsub=3k
Rs a b {rsub}
.ends
Xd mid 0 div rsub={rr*5}
```

Output:

```
=== nominal rr=1k ===
@r1[resistance] = 1.000000e+03
@r2[resistance] = 2.000000e+03
@r.xd.rs[resistance] = 5.000000e+03
v(mid) = 5.882353e-01
=== alterparam rr=2k + reset ===
Reset re-loads circuit ...
@r1[resistance] = 2.000000e+03
@r2[resistance] = 4.000000e+03
@r.xd.rs[resistance] = 1.000000e+04
v(mid) = 5.882353e-01
=== back to nominal, then 'alter r1 = 2k' only ===
Reset re-loads circuit ...
@r1[resistance] = 2.000000e+03
@r2[resistance] = 2.000000e+03
@r.xd.rs[resistance] = 5.000000e+03
v(mid) = 4.166667e-01
```

The complete list of non-equivalences, each with a source anchor:

1. **One instance vs every user of the parameter.** `{rr}`, `{rr*2}` and `{rr*5}` are three
   *different* numbers baked in at parse time; `alter` reaches one instance parameter.
   `alterparam` + `reset` moves all three consistently (demonstrated above).
2. **Expressions are evaluated once, at parse.** numparam substitutes literal numbers
   (`listing expand` in §5.3 shows this). `alter` overwrites the number; it cannot re-evaluate
   the expression.
3. **B-source / behavioural expressions cannot be altered at all.** `alter @b1[v] = 5`
   answers `Can't assign value to "v" (unsupported type)` (measured). `agauss` etc. inside a
   B-line are *pre-substituted* with a fixed number at parse time by `eval_agauss()`
   (`src/frontend/inp.c:2560`, with the explanatory comment at `:2554-2559`: "agauss does not
   exist in the B source parser, and it would not make sense in adding it there, because in
   each time step a different return from agauss would result"). The `agauss/gauss/unif/
   aunif/limit` implementations used for that pre-substitution are
   `src/frontend/inp.c:2513-2551`; the B-source parse-tree function table
   (`src/spicelib/parser/inpptree.c:139-177`) contains no random function.
4. **Model parameters need `altermod`, not `alter`.**
5. **Names inside subcircuits are the flattened names.** `Rs` inside `Xd` becomes
   `r.xd.rs`; verify with `listing expand`. (`work/e3b.cir` output:
   `9 : r.xd.rs mid 0   5.000000000000000e+03`.)
6. **MOS geometry is special-cased.** `alter m1 w=…` / `l=…` triggers re-binning of the
   binned model set (`if_set_binned_model()`, `src/frontend/device.c:1355-1425`, called at
   `:1493`). Other devices get no such treatment.
7. **`alter`/`altermod` cannot change topology, add/remove devices, change a `.model`'s
   level, change a subcircuit's structure, or change the number of instances.**
8. **`alter` needs the case-folded name unless `casemode=preserve`**
   (`src/frontend/device.c:1409-1419`: `if (inp_case_folding()) { strtolower(param);
   strtolower(dev); }`). Under `set casemode=preserve` (which this build's spinit mentions at
   `build-ver_50/src/spinit:17`) the deck's spelling is kept and the GUI must emit the exact
   spelling.
9. **`alter` with more than one param/value pair in the pre-3f4 syntax is rejected**:
   `Error: Only a single param - value pair supported.` (`src/frontend/device.c:1348`).
10. **Wildcards** (`*`, `?`, `[`) and the word `all` are expanded to the device list by
    `devexpand()` (`src/frontend/device.c:1508`) — but only in the `show`/`showmod`
    path, not in `alter`.

**Cost.** Measured on a synthetic 2000-R/2000-C ladder (4001 device lines),
20 operating points:

| driver | wall time |
|---|---|
| `alterparam` + `reset` per run | 0.141 s |
| `alter` per run | 0.032 s |

≈5.5 ms of re-parse per run for a 4000-line deck, i.e. the re-parse dominates for anything
with a real PDK. **Generator rule: prefer `alter`/`altermod` whenever the swept quantity is
a single instance or model parameter; fall back to `alterparam` + `reset` only when the
parameter feeds an expression, several devices, a `.model`, a B-source, or a `.if`.**

### 3.5 The built-in second sweep of `.dc`

`dc <src1> <start> <stop> <step> [<src2> <start> <stop> <step>]` runs the inner sweep for
each outer value in *one* analysis, one plot (`src/spicelib/analysis/dctrcurv.c`).
`temp` is accepted as either source. Verified (E4 route C, `dc v1 0 1 0.5 temp 0 100 50`):

```
Index   v-sweep         v(out)
0	0.000000e+00	0.000000e+00
1	5.000000e-01	2.568125e-01
2	1.000000e+00	5.136249e-01
3	0.000000e+00	0.000000e+00      <- outer step 2 restarts the inner sweep
4	5.000000e-01	2.442603e-01
5	1.000000e+00	4.885207e-01
6	0.000000e+00	0.000000e+00
7	5.000000e-01	2.328786e-01
8	1.000000e+00	4.657571e-01
```

Note the scale is a **single concatenated vector with repeats**, not a 2-D vector. A GUI
that wants a family of curves from `.dc` with two sources must slice it itself
(`length = (stop1-start1)/step1 + 1`), or use a control loop instead. This is cheaper than a
loop (one `CKTdojob`), but produces one plot with a discontinuous scale.

---

## 4. Temperature sweeps

Three independent mechanisms; all verified in `work/e4_temp.cir`.

### 4.1 `set temp = <celsius>` — the loop route

`temp` is a "simvar": `cp_vset()` classifies it `US_SIMVAR`
(`src/frontend/variable.c:194-235`) and hands it to `if_option(ft_curckt->ci_ckt, …)`, which
writes `CKTtemp`. **No re-parse is needed and none happens.** Expressions containing the
`temper` keyword are re-evaluated at the start of *every* analysis:
`CKTdojob()` calls `inp_evaluate_temper(ft_curckt)` (`src/spicelib/analysis/cktdojob.c:130`,
with the comment "because we have a new temperature"); the four-step machinery is documented
at `src/frontend/inp.c:2218-2243` and implemented in `inp_parse_temper()`
(`src/frontend/inp.c:2245`), `inp_parse_temper_trees()` and `inp_evaluate_temper()`
(`src/frontend/inp.c:2370`).

```
foreach t -40 0 27 85 125
  set temp = $t
  op
  ...
end
```
gives (E4 route A):
```
Index   tvec            vout
0	-4.00000e+01	5.356467e-01
1	0.000000e+00	5.136249e-01
2	2.700000e+01	4.997567e-01
3	8.500000e+01	4.723602e-01
4	1.250000e+02	4.551531e-01
```
`settype temp-sweep tvec` gives the vector the right unit
(`src/frontend/typesdef.c:52`, type name `temp-sweep`, abbrev `Celsius`).

`temp` is **sticky**: it persists to the next analysis and is not reset by `reset`
(measured — the analysis header for the next command still said `TEMP = 125.000000`).
A GUI must set it explicitly for every run, including the nominal one.

`option temp = <v>` is the same thing through `com_option()`
(`src/frontend/com_option.c:15`, which just calls `cp_vset` at `:132`).

### 4.2 `.temp` card in the deck

Extracted at `src/frontend/inp.c:1166-1177`, applied with
`cp_vset("temp", CP_REAL, &temperature_value)` at `src/frontend/inp.c:1194`. It accepts
`.temp 125` and `.temp=125`. Because it goes through the same variable, a `.temp` card in the
deck is overwritten by a later `set temp`, and re-applied by `reset`.

### 4.3 `dc temp <start> <stop> <step>` — the analysis route

`TEMP_CODE` in `src/spicelib/analysis/dctrcurv.c:453`; the old temperature is saved at
`:145` and `inp_evaluate_temper()` is re-run at each step (`:466`, `:501`). Verified:

```
dc temp -40 125 41.25
Index   temp-sweep      in              out             temp-sweep
0	-4.00000e+01	1.000000e+00	5.356467e-01	-4.00000e+01
1	1.250000e+00	1.000000e+00	5.129659e-01	1.250000e+00
2	4.250000e+01	1.000000e+00	4.921287e-01	4.250000e+01
3	8.375000e+01	1.000000e+00	4.729189e-01	8.375000e+01
4	1.250000e+02	1.000000e+00	4.551531e-01	1.250000e+02
```

**One plot, one analysis, temperature is the scale.** This is by far the cheapest way to do
a pure temperature sweep of a DC quantity, and the *only* one that gives ADE-style "one
curve versus temperature" without any control-flow. Note the duplicated `temp-sweep`
column (the scale is also emitted as a data column). For AC/TRAN versus temperature there is
no equivalent — a loop is mandatory.

### 4.4 What a GUI should expose

* nominal temperature (`.temp` / `set temp`), `tnom` (`option tnom`), and per-instance
  `temp`/`dtemp` overrides (instance parameters `temp` and `dtemp`, e.g.
  `src/spicelib/devices/res/res.c:17`, `src/frontend/inpcom.c:8206`).
* a temperature list (loop) *or* a `dc temp` range, and it should pick `dc temp`
  automatically when the analysis is `op`/`dc` and nothing else is being swept.

---

## 5. Corners

### 5.1 How `.lib` sections are processed, and why that constrains the deck

`.lib <file> <section>` is resolved **inside `inp_readall()`**, long before any control
statement runs: `expand_section_references()` (`src/frontend/inpcom.c:4530`) is called at
`src/frontend/inpcom.c:2340`; it finds `.lib <name> … .endl` with
`find_section_definition()` (`:517`) and splices the section's text into the deck, then
comments out the `.lib` line (`expand_section_ref()`, `:4416`, `:4511`). Old-style
`.lib <file>` with no section name is turned into `.include` (`:1827-1840`).

The deck copy that `reset`/`mc_source` reload (`ft_curckt->ci_mcdeck`, assigned from
`inp_deckcopy_oc(deck)` at `src/frontend/inp.c:541` and stored at `:1563`) is taken
**after** library expansion. Therefore:

**You cannot switch `.lib` sections from the control language.** `alterparam` cannot rewrite
a `.lib` line into a different section, because by the time the stored deck exists the
`.lib` line is already a comment and both/all sections' text is present.

### 5.2 Route A — `.if` / `.elseif` / `.else` / `.endif` on a `.param`

ngspice does have netlist-level conditionals: `dotifeval()`/`recifeval()`
(`src/frontend/inp.c:2193`, `:2130`), prepared for numparam by `inp_fix_if_expr()`
(`src/frontend/inpcom.c:8535-8560`). They work, and `alterparam` + `reset` re-selects the
branch. `work/e7_corner_if.cir` with `work/corners.lib`:

```spice
* E7 corner selection by .if around .lib   (route A)
.param corner = 1
.if (corner == 1)
.lib corners.lib tt
.elseif (corner == 2)
.lib corners.lib ff
.else
.lib corners.lib ss
.endif
V1 in 0 dc 0.7
R1 in a 1k
D1 a 0 dmod
Rl a 0 {10k*rmul}
```
where each library section contains `.param rmul = …` and `.model dmod d (is=… )`.

Output:

```
corner=1  plot=op1     v(a) = 5.837056e-01    @rl[resistance] = 1.100000e+04
corner=2  plot=op1     v(a) = 5.709296e-01    @rl[resistance] = 1.100000e+04
corner=3  plot=op1     v(a) = 5.956596e-01    @rl[resistance] = 1.100000e+04
```

**The `.model` selection worked (three different `is` values are visible in `v(a)`), but the
`.param rmul` did NOT: every corner used 1.1, the value from the *last textual* section.**

Root cause, from the source: `inp_subcktexpand()` (with the numparam passes,
`src/frontend/subckt.c:263`, `:396`, `:422`) runs at `src/frontend/inp.c:937`, while
`dotifeval(deck)` runs later at `src/frontend/inp.c:1022`. numparam must register and
evaluate *all* `.param` lines in order to evaluate the `.if(...)` condition itself, so every
branch's `.param` assignments are executed and the last one wins. Only non-`.param` cards are
commented out afterwards.

**This is a silent wrong-answer generator and ASE-L must never emit it.** If ASE-L uses
`.if` for corners, it may put only `.model`, device and `.subckt` cards inside the branches,
never `.param`.

### 5.3 Route B — one top-level deck per corner, `source`d in a loop (recommended)

`work/e9_corner_source.cmd` (an `*ng_script` file, so ngspice treats it as a command file —
`src/frontend/inp.c:536`, `:602`):

```spice
*ng_script  corner run by sourcing one deck per corner
.control
  setplot new corners "corner results" cdata
  let vres = vector(3)
  let k = 0
  foreach c tt ff ss
    setplot corners
    source deck_{$c}.cir            $ note the brace form, see 1.4
    op
    set dt = $curplot
    echo "corner $c -> plot $dt"
    print v(a)
    setplot corners
    set k = "$&k"
    let vres[$k] = {$dt}.v(a)
    let k = k + 1
    destroy $dt
    remcirc                          $ drop the circuit so memory stays flat
  end
  setplot corners
  print vres
.endc
.end
```

Output:

```
Circuit: * corner deck (parameterised by the .lib section chosen on the .lib line)
corner tt -> plot op1
v(a) = 5.821780e-01
Circuit: ...
corner ff -> plot op1
v(a) = 5.679960e-01
Circuit: ...
corner ss -> plot op1
v(a) = 5.956596e-01
                                "corner results"
                                cdata  Wed Sep  9 18:57:13  2026
Index   vres
0	5.821780e-01
1	5.679960e-01
2	5.956596e-01
```

Compare with route A: `tt` 0.5821780 vs 0.5837056 and `ff` 0.5679960 vs 0.5709296 differ
(route A used the wrong `rmul`), while `ss` 0.5956596 agrees (route A happened to use `ss`'s
`rmul`). **That is the hard proof that route A's `.param` handling is broken.**

The per-corner decks differ only in one line
(`.include sect_tt.inc` / `.lib mylib.lib tt` …), so ASE-L generates them trivially.

Notes on route B:
* Each `source` creates a **new circuit** in `ft_circuits` and makes it current
  (`src/frontend/inp.c` → `inp_dodeck` at `:1096`, `ct->ci_mcdeck = mc_deck` at `:1563`).
  Without `remcirc` (`src/frontend/runcoms2.c:191`) memory grows per corner.
* `plot_num` restarted at `op1` each time here only because `destroy $dt` freed the name;
  see §2.1. Do not rely on it.
* `source` of a *circuit* file inside `.control` works in batch mode; the top-level file
  must then be a command file (`*ng_script`) or contain no netlist of its own — this is the
  structure of `examples/Monte_Carlo/MC_2_control.sp`.

### 5.4 Route C — one `.lib`-selecting wrapper deck, `alterparam` + `reset`, models only

Route A restricted to what it can do correctly: keep every corner's model cards in the deck
(or in one `.lib` section that is always included), and select with `.if` on a `.param`,
never letting a `.param` live inside a branch. That is what the reference deck in §8 does.

### 5.5 `reset` vs `mc_source` vs `remcirc`

| command | table entry | implementation | effect |
|---|---|---|---|
| `reset` | `src/frontend/commands.c:463` | `com_rset()`, `src/frontend/runcoms2.c:175` | `com_remcirc(NULL)` then `inp_source_recent()` — **replaces** the current circuit from the stored deck |
| `remcirc` | `src/frontend/commands.c:459` | `com_remcirc()`, `src/frontend/runcoms2.c:191` | frees the current circuit, numparam dico, deck copies |
| `mc_source` | `src/frontend/commands.c:371` | `com_mc_source()`, `src/frontend/inp.c:1642` → `inp_spsource(NULL, FALSE, NULL, FALSE)` | re-parses the stored deck into an **additional** circuit |

Verified (`work/e19_circs.cir`): after three `mc_source` calls `setcirc` lists **4**
circuits; after three further `reset` calls it still lists 4.

```
=== after 3 mc_source ===
List of circuits loaded:
Current	1	* e19 ...
	2	* e19 ...
	3	* e19 ...
	4	* e19 ...
=== after 3 more reset ===
List of circuits loaded:
Current	1	...   (still 4 total)
```

Memory, 200 iterations of a trivial deck (`work/e18_mem*.cir`, `rusage`):

| loop body | current program size after 200 runs |
|---|---|
| `mc_source` only | 18.168 MB |
| `mc_source` + `remcirc` | 14.254 MB |

≈20 kB of leak per retained circuit for a 4-device deck; for a real PDK deck this is fatal
within a few hundred runs.

**And `reset` re-draws the netlist random numbers just as `mc_source` does** — verified,
`work/e20_reset_mc.cir`:

```
setseed 777 ; loop { reset ; op ; print @r1[resistance] }
@r1[resistance] = 9.844280e+02
@r1[resistance] = 9.328112e+02
@r1[resistance] = 1.020550e+03
@r1[resistance] = 9.960026e+02
@r1[resistance] = 1.032040e+03
setcirc -> Current 1  (a single circuit)
```

Mechanism: `inp_source_recent()` sets `mc_reload = TRUE` (`src/frontend/inp.c:414-415`) and
`inp_spsource()` takes the `mc_reload` branch (`:547-556`) which copies `mc_deck`, forces
`expr_w_temper = TRUE` and re-runs the whole numparam pass — so `agauss()` etc. are
re-evaluated.

**Generator rule: use `reset`, not `mc_source`, as the per-run re-parse. It is memory-safe
and does everything `mc_source` does.** (Every shipped Monte Carlo example uses `mc_source`;
this is a genuine improvement over them.)

### 5.6 `save` does not survive a re-parse — a memory trap in the shipped examples

Verified (`work/e26_save.cir`):

```
save out
ac dec 5 1k 1meg
display        ->  frequency, out                      (2 vectors)
reset
ac dec 5 1k 1meg
display        ->  frequency, in, mid, out, v1#branch  (everything)
mc_source
ac dec 5 1k 1meg
display        ->  frequency, in, mid, out, v1#branch  (everything)
```

`examples/Monte_Carlo/MC_ring.sp:39` issues `save buf` once before the loop and calls
`reset` at the bottom of every iteration (`MC_ring.sp`, `label next` / `reset`), so runs 2..N
store every node of a 25-stage ring oscillator — exactly the 10× memory the comment claims
to avoid.

The fix that *does* survive: a **`.save` card in the netlist**
(`work/e26b.cir`):

```
.save out
...
--- run 1 (ac1) ---   frequency, out
--- run 2 after reset (ac2) ---   frequency, out
```

**Generator rule: emit `.save`/`.probe` cards in the deck (they are part of the stored deck
and survive `reset`), or re-issue `save` immediately after every `reset`/`mc_source`.**

---

## 6. Monte Carlo

### 6.1 Two entirely separate sets of random functions

**(a) Netlist / `.param` / `.model` level** — five functions, implemented three times over:

| function | signature | meaning | implementations |
|---|---|---|---|
| `agauss(nom, avar, sigma)` | absolute | `nom + (avar/sigma)*N(0,1)` | `src/frontend/numparam/xpressn.c:47`, `src/frontend/inp.c:2513`, `src/spicelib/parser/inpptree.c:1701` |
| `gauss(nom, rvar, sigma)` | relative | `nom + (nom*rvar/sigma)*N(0,1)` | `xpressn.c:58`, `inp.c:2524` |
| `aunif(nom, avar)` | absolute | `nom + avar*U(-1,1)` | `xpressn.c:76`, `inp.c:2539` |
| `unif(nom, rvar)` | relative | `nom + nom*rvar*U(-1,1)` | `xpressn.c:69`, `inp.c:2532` |
| `limit(nom, avar)` | two-point | `nom ± avar`, sign from `U(-1,1)>0` | `xpressn.c:83`, `inp.c:2546` |

Argument conventions verified in source. Note the guards: **`agauss` and `gauss` silently
return the nominal value if `avar <= 0` or `sigma <= 0`** (`xpressn.c:49-52`, `:60-63`) —
a GUI that lets the user type `sigma = 0` gets no variation and no warning.
`unif`/`aunif`/`limit` have no such guard. The registered names are in the space-separated
keyword list `fmathS` at `src/frontend/numparam/xpressn.c:92-95`; dispatch is
`src/frontend/numparam/xpressn.c:1152-1166`.

`agauss` etc. are *not* available in a B-source expression at run time; they are
pre-substituted with a fixed draw at parse time (`eval_agauss()`,
`src/frontend/inp.c:2560`, comment `:2554-2559`).

**(b) Control language** — five *different* functions, in the `ft_funcs[]` table
(`src/frontend/parse.c:386-390`):

| function | implementation | meaning |
|---|---|---|
| `sgauss(v)` | `cx_sgauss`, `src/maths/cmaths/cmath2.c:287` | one `N(0,1)` per element of `v` (uses `gauss1()` for real, `gauss0()` for complex) |
| `sunif(v)` | `cx_sunif`, `src/maths/cmaths/cmath2.c:175` | one `U(-1,1)` per element (`drand()`) |
| `rnd(v)` | `cx_rnd`, `src/maths/cmaths/cmath2.c:134` | integer in `[0, floor(v_i))` — **uses libc `rand()`, not the Tausworthe generator** |
| `poisson(v)` | `cx_poisson`, `src/maths/cmaths/cmath2.c:213` | Poisson with λ = `v_i` |
| `exponential(v)` | `cx_exponential`, `src/maths/cmaths/cmath2.c:251` | exponential with mean `v_i` |

The argument is only used for its **length and (for `rnd`/`poisson`/`exponential`) its
values**; `sgauss(0)` and `sunif(0)` are the idiomatic scalar draws (`NG_IGNORE(data)` at
`cmath2.c:177`, `:289`).

**`agauss`, `gauss`, `unif`, `aunif`, `limit` do not exist in the control language.**
Every shipped example re-defines them (manual §17.8.6;
`examples/Monte_Carlo/MonteCarlo.sp:26-33`, `examples/Monte_Carlo/MC_ring.sp:59-63`,
`examples/various/agauss_test.cir:8`):

```
define unif(nom, rvar)        (nom + (nom*rvar) * sunif(0))
define aunif(nom, avar)       (nom + avar * sunif(0))
define gauss(nom, rvar, sig)  (nom + (nom*rvar)/sig * sgauss(0))
define agauss(nom, avar, sig) (nom + avar/sig * sgauss(0))
define limit(nom, avar)       (nom + ((sgauss(0) >= 0) ? avar : -avar))
```

Beware: the control-language `limit` above is defined off `sgauss`, whereas the netlist
`limit` uses `drand()` (`xpressn.c:85`) — the two are *not* the same distribution of sign,
though both are symmetric. Also note the netlist `gauss`/`agauss` guard against
`sigma <= 0` while the `define`d versions divide by it.

Additionally, **`compose` can build a whole sample vector in one call**
(`src/frontend/com_compose.c:63-79`):

```
compose v gauss=1000 mean=0 sd=1      # 1000 N(mean,sd) values   (com_compose.c:627-631)
compose v unif=1000 mean=0.5 span=1   # 1000 uniform values      (com_compose.c:606-611)
compose v start=… stop=… step=…|lin=…|log=…|dec=…|oct=…|center=…|span=…
compose v values v1 v2 v3 …
```
Defaults: `gauss` → `mean = 0`, `sd = 1.0`; `unif` → `mean = 0.5`, `span = 1.0`
(`com_compose.c:620-625`, `:600-605`). This is the cleanest way for a GUI to pre-compute all
N per-run parameter values up front (so it can show the user the sample it is about to run).
Caveat: `com_compose`'s `unif`/`gauss` do **not** call `checkseed()` (see §6.3).

### 6.2 The random-number engine

`src/maths/misc/randnumb.c`, a combined Tausworthe-88 + LCG generator (header comment
`:11-24`), with **two independent 4-word states**: `CombState1..4` for doubles
(`randnumb.c:54-55`) and `CombState5..8` for integers (`:58-59`).

* `CombLCGTaus()` (`randnumb.c:140`) → `[0,1)`.
* `drand()` (`randnumb.c:95`) → `2*CombLCGTaus()-1` → `[-1,1)`.
* `gauss1()` (`randnumb.c:220`) → Box-Muller, **one value per call** ("to be reproducible,
  we just use one value per pass" — `:218-219`).
* `gauss0()` (`randnumb.c:195`) → Box-Muller caching **two values per call**, i.e. it has
  hidden state. Used for the *complex* branch of `cx_sgauss` only (`cmath2.c:300-301`).
* `TausSeed()` (`randnumb.c:101`) seeds all eight state words from libc `rand()`, i.e. from
  the last `srand()`.

### 6.3 Seeding: the exact rules, and two serious traps

**`setseed`** — `com_sseed()` (`src/maths/misc/randnumb.c:293`, registered
`src/frontend/commands.c:204`):
* `setseed <n>` with `0 < n <= INT_MAX`: `srand(n); TausSeed(); cp_vset("rndseed", n)` —
  **re-seeds immediately** (`randnumb.c:314-317`).
* `setseed` with no argument: uses `rndseed` if set, else `getpid()` (`randnumb.c:300-307`).
* A non-numeric or non-positive argument prints
  `Warning: Cannot use <x> as seed!` and is **ignored** (`randnumb.c:308-313`).

**`set rndseed = <n>`** does *not* re-seed by itself. It is picked up lazily by
`checkseed()` (`src/maths/misc/randnumb.c:77`), which compares against a **`static int
oldseed`** and re-seeds only when the value changed (`:82-91`). `checkseed()` is called from
exactly five places, all in `src/maths/cmaths/cmath2.c` — `cx_rnd:137`, `cx_sunif:180`,
`cx_poisson:216`, `cx_exponential:254`, `cx_sgauss:292`. It is **never** called from the
netlist-level `agauss`/`gauss`/`unif`/`aunif`/`limit`, nor from `com_compose`.

**`.option seed=<n>` / `.option seed=random` / `.option seedinfo`** — `eval_opt()`
(`src/frontend/inp.c:431-...`), called from `inp_spsource()` at `src/frontend/inp.c:612`,
i.e. immediately after `inp_readall()` and **before** numparam evaluation. `seed=random`
takes microseconds from `gettimeofday()` (`inp.c:452-460`); a numeric value is `atoi`'d and
non-positive values warn and are skipped (`inp.c:463-470`). Either way it calls
`cp_vset("rndseed", …)` and `com_sseed(NULL)`.

**Trap 1 — the first parse is seeded from the PID, so the nominal run is not reproducible.**
`main.c` seeds deterministically (`cp_vset("rndseed", 1); com_sseed(NULL);`,
`src/main.c:935-938`), but then, because `WaGauss` is defined
(`src/include/ngspice/ngspice.h:223`; `FastRand` is commented out at `:222`), `main.c:1371`
calls `initw()`, and `initw()` does:

```c
/* src/frontend/trannoise/wallace.c:76-86 */
void initw(void) {
    ...
    srand((unsigned int) getpid());
    // srand(17);
    TausSeed();
```

— it re-seeds *both* libc `rand()` and the Tausworthe state from the process id, right
before the input file is read. Measured (`work/e6_seedcheck.cir`, three invocations):

```
rndseed = 1     @r1[resistance] = 9.967322e+02     g1 = -1.13966e+00  g2 = 9.040756e-01
rndseed = 1     @r1[resistance] = 9.668247e+02     g1 = -1.13966e+00  g2 = 9.040756e-01
rndseed = 1     @r1[resistance] = 9.902101e+02     g1 = -1.13966e+00  g2 = 9.040756e-01
```

The netlist-level `agauss` in `.param` differs run to run; the control-language `sgauss(0)`
does not — because `cx_sgauss` calls `checkseed()`, which sees `rndseed = 1 != oldseed = 0`
and re-seeds `srand(1); TausSeed()` on first use, undoing the PID seeding. This asymmetry is
entirely explained by which code paths call `checkseed()`.

*Consequence for the GUI:* **the very first parse of a deck containing netlist-level random
functions is irreproducible.** Do not let any reported result come from it — always `reset`
(or `mc_source`) before the first measured run, after the control block has set the seed.
The reference deck in §8 does exactly this and is bit-reproducible.

**Trap 2 — `.option seed=<n>` destroys Monte Carlo entirely.** `eval_opt()` runs on *every*
re-parse, including the ones `reset` and `mc_source` perform, so it re-seeds the generator
to the same value before every draw. Measured, `work/e5c.cir` (`.option seed=12345`,
`setseed $&run` inside the loop, `mc_source` per run):

```
== inv 1 ==            == inv 2 ==
0  1.013170e+03        0  1.013170e+03
1  1.013170e+03        1  1.013170e+03
2  1.013170e+03        2  1.013170e+03
3  1.013170e+03        3  1.013170e+03
4  1.013170e+03        4  1.013170e+03
5  1.013170e+03        5  1.013170e+03
```

and `work/e25_seed_reset.cir` (`.option seed=999`, plain `reset` per run):

```
@r1[resistance] = 1.075945e+03
@r1[resistance] = 1.075945e+03
@r1[resistance] = 1.075945e+03
@r1[resistance] = 1.075945e+03
```

**Every "Monte Carlo" run is the same sample, silently.** Even the in-loop `setseed` is
overridden, because `mc_source`/`reset` re-runs `eval_opt()` *after* it.
Contrast, same deck with `.option seed=random` (`work/e5d.cir`) — varies, but is not
reproducible across invocations:

```
== inv 1 ==            == inv 2 ==
0  9.461910e+02        0  9.803629e+02
1  1.001002e+03        1  9.524605e+02
...                    ...
```

and with **no `.option seed` at all** plus `setseed $&run` before each `mc_source`
(`work/e5e.cir`): runs 1..5 identical across invocations, run 0 (the initial parse) not:

```
== inv 1 ==            == inv 2 ==
0  9.879273e+02        0  1.024759e+03    <- initial parse, PID-seeded
1  9.620114e+02        1  9.620114e+02
2  9.750444e+02        2  9.750444e+02
3  9.464092e+02        3  9.464092e+02
4  1.013848e+03        4  1.013848e+03
5  9.770711e+02        5  9.770711e+02
```

**Generator rules for seeding:**
1. **Never emit `.option seed=<n>` for a Monte Carlo campaign.** (It is the only correct
   choice for a *single* reproducible run with netlist randomness — and that is presumably
   why it exists.)
2. Emit `setseed <n>` once at the top of the control block, and make the *first measured
   run* be preceded by a `reset`. That gives one advancing stream and a bit-reproducible
   campaign (verified in §8).
3. If the user wants "re-run just case #17", emit `setseed <base + 17>` before that case's
   `reset`. This is what `examples/Monte_Carlo/MC_2_control.sp:26` and
   `examples/Monte_Carlo/mc_ring_lib_complete_actual.cir:102` do (`setseed $run`). It costs
   N independent seedings instead of one stream — acceptable, and it is what makes a single
   case replayable.
4. `.option seedinfo` (`src/frontend/inp.c:446-447` → `setseedinfo()`,
   `randnumb.c:326`) makes `setseed` announce the seed it used. Useful for a log.
5. `rnd()` uses libc `rand()`, so it is on a *different* stream from everything else and its
   range is capped by `RAND_MAX` (comment `src/maths/cmaths/cmath2.c:126-131`).
6. Transient-noise sources (`trnoise`, `trrandom`) draw from the Wallace pools which are
   themselves filled from `drand()` (`src/frontend/trannoise/wallace.c:53-54`, `:98-100`) —
   a deck with transient noise consumes the same double stream and shifts every subsequent
   Monte Carlo draw. A campaign that mixes the two must seed per run (rule 3).

### 6.4 Process variation vs mismatch — the exact spelling

This is the one place where ngspice's parse-time evaluation is a *feature*: numparam
evaluates each card separately, so **where you write the random function decides whether the
draw is shared or independent**.

`work/e13_mismatch.cir`:

```spice
* process: ONE draw per .model card, shared by every device using it
.model dproc d is=agauss(1e-14, 1e-15, 3) n=1
* mismatch: the agauss sits on an instance line inside a subckt,
* so numparam evaluates it once per expanded instance -> one draw per device
.subckt leg n
Rleg n 0 r = {agauss(1000, 30, 3)}
.ends
V1 in 0 dc 0.7
X1 in leg
X2 in leg
X3 in leg
D1 in 0 dproc
D2 in 0 dproc
```

Output, including `listing expand` (which shows the substituted literals — the best
verification tool a GUI has):

```
--- per-instance (mismatch) resistances, should all differ ---
@r.x1.rleg[resistance] = 1.021520e+03
@r.x2.rleg[resistance] = 9.822375e+02
@r.x3.rleg[resistance] = 9.707175e+02
--- model parameter is one draw shared by d1 and d2 (process) ---
     3 : .model dproc d is=    1.021058398744816e-14     n=1
     7 : v1 in 0 dc 0.7
     5 : r.x1.rleg in 0 r=    1.021519529373052e+03
     5 : r.x2.rleg in 0 r=    9.822375095084477e+02
     5 : r.x3.rleg in 0 r=    9.707175161643074e+02
    11 : d1 in 0 dproc
    12 : d2 in 0 dproc
```

So:

* **Process (global) variation** = the random function on a `.model` card
  (`.model n1 nmos vth0=agauss(0.6,0.1,3) …`, as in
  `examples/Monte_Carlo/MC_2_circ.sp:38-46` and
  `examples/Monte_Carlo/mc_ring_lib_complete_actual.cir:57-58`), or on a global `.param`
  used by many devices. One draw per re-parse, shared.
* **Mismatch (local) variation** = the random function on an *instance* line, most usefully
  inside a `.subckt` that is instantiated once per device. One independent draw per expanded
  instance, per re-parse.
* **`.model` cards must not wrap their parameter list in parentheses when a random function
  is used.** `.model dproc d (is=agauss(1e-14,1e-15,3))` fails:
  `Syntax error: letter [)]` / `Expression err: agauss(1e-14, 1e-15, 3))}` /
  `Cannot compute substitute` → `ERROR: fatal error in ngspice, exit(1)`. All the shipped
  examples write `.model n1 nmos` + continuation lines with no outer parens.
* There is **no `DEV=`/`LOT=` syntax** and no per-instance-parameter distribution keyword.
  Vendor PDKs express mismatch with their own subcircuit wrappers and a switch parameter
  (`mosmis_mod=1` in `examples/Monte_Carlo/mc_ring_lib_complete_actual.cir:19-24`) — ASE-L
  should surface that switch, not try to synthesise mismatch itself when the PDK has it.

The *other* way to get mismatch, entirely from the control language, is `altermod` /
`alter` on each instance with an independent `sgauss(0)` draw — `MC_ring.sp:84-95` uses
`altermod @n1[vth0] = gauss(n1vth0, 0.1, 3)` (process only, since a model parameter is
shared). For per-instance mismatch without a re-parse you must `alter` each instance
separately, which needs the flattened instance list; the GUI has that from the schematic.

Note the neat trick in `examples/Monte_Carlo/MC_ring.sp:71-81`: read the nominal value out
of the loaded circuit first (`let n1vth0 = @n1[vth0]`) so the loop does not hard-code it.

### 6.5 Working Monte Carlo, route 1: netlist randomness + `reset`

`work/e5_mc.cir` (edited to use `reset`, see §5.5) — the essentials, with output:

```spice
.param rmc  = agauss(1k, 100, 3)
R1 in out {rmc}
.control
  setseed 12345
  dowhile run < 6
     if $run > 0
        mc_source            $ (use 'reset' instead - see 5.5)
     end
     op
     let rres[$run] = {$dt}.@r1[resistance]
     ...
```

```
                                  "mc results"  mcdata
Index   rres            vres
0	1.006419e+03	4.984003e-01     <- initial parse, PID-seeded, NOT reproducible
1	1.013170e+03	4.967291e-01
2	9.995401e+02	5.001150e-01
3	1.092492e+03	4.778990e-01
4	1.023387e+03	4.942207e-01
5	1.022645e+03	4.944022e-01
```
(rows 1..5 identical on a second invocation; row 0 was `1.011559e+03` — the trap of §6.3.)

Also note: **`$&mean(rres)` does not work** — `$&` takes a plain vector name, not an
expression (`Error: &mean(rres): no such variable.`). Emit `let mu = mean(rres)` then
`$&mu`.

### 6.6 Working Monte Carlo, route 2: control-language randomness + `alter` (no re-parse)

`work/e14_mc_control.cir` — 40 runs, fully reproducible, ~10× cheaper per run than a
re-parse:

```spice
* E14 Monte Carlo driven entirely from the control language (no re-parse)
V1 in 0 dc 0 ac 1
R1 in out 1k
C1 out 0 1n
.control
  define unif(nom, rvar)        (nom + (nom*rvar) * sunif(0))
  define aunif(nom, avar)       (nom + avar * sunif(0))
  define gauss(nom, rvar, sig)  (nom + (nom*rvar)/sig * sgauss(0))
  define agauss(nom, avar, sig) (nom + avar/sig * sgauss(0))
  define limit(nom, avar)       (nom + ((sgauss(0) >= 0) ? avar : -avar))

  setseed 4242
  setplot new mc "Monte Carlo" mcdata
  let nruns = 40
  let rsample = vector(40)
  let bwsample = vector(40)
  let run = 0
  dowhile run < nruns
    setplot mc
    set run = "$&run"
    let rdraw = agauss(1000, 100, 3)
    let cdraw = agauss(1n, 0.1n, 3)
    alter r1 = rdraw                  $ pass the vector by NAME (see 1.5)
    alter c1 = cdraw
    ac dec 40 1k 30meg
    meas ac bw3 when vdb(out)=-3.0103 fall=1
    set dt = $curplot
    setplot mc
    let rsample[$run]  = rdraw
    let bwsample[$run] = {$dt}.bw3
    destroy $dt
    let run = run + 1
  end
  setplot mc
  let mu = mean(bwsample) $ let sigma = stddev(bwsample)
  let bmin = vecmin(bwsample) $ let bmax = vecmax(bwsample)
  echo "mean(bw)  = $&mu"
  echo "sigma(bw) = $&sigma"
  echo "min/max   = $&bmin / $&bmax"
  let idx = vector(40)
  setscale idx
  wrdata mc_sample.dat rsample bwsample
.endc
.end
```

Output (identical on two invocations):

```
runs      = 40
mean(bw)  = 159758
sigma(bw) = 8232.44
min/max   = 137411 / 179024
```

Choose route 2 when only instance/model parameters vary; route 1 when the variation must
propagate through `.param` expressions, `.model` cards, B-sources or per-instance mismatch.

### 6.7 Accumulating per-run results and computing statistics

Available in the control language (`src/frontend/parse.c:355-418`):
`mean`, `stddev`, `avg` (running average), `m3avg`, `vecmin`/`minimum`, `vecmax`/`maximum`,
`length`, `sortorder`, `norm`, `deriv`, `integ`, `interpolate`, `fft`/`ifft`,
`mtimeavg`, `group_delay`, `sum`-by-`integ`.

**There is no `sort`, no median, no percentile, no histogram command.** Verified:
`Error: no such function as sort,`. `sortorder(v)` returns the 0-based permutation that
sorts `v` ascending (`work/e21b.cir`):

```
Index   s               o
0	5.000000e+00	1.000000e+00
1	1.000000e+00	3.000000e+00
2	4.000000e+00	5.000000e+00
3	2.000000e+00	2.000000e+00
4	6.000000e+00	0.000000e+00
5	3.000000e+00	4.000000e+00
```
i.e. `s[1] <= s[3] <= s[5] <= s[2] <= s[0] <= s[4]`. To materialise a sorted vector or a
percentile the generated code must loop and index with `$&`, or the GUI should read the raw
sample out (§7) and do the statistics in Tcl — which is what ASE-L should do.

**Histogram**: the shipped pattern is an explicit bin loop —
`examples/Monte_Carlo/MC_ring.sp:167-195` (with `compose xvec start=… step=… lin=…`,
`set plotstyle=combplot`, `plot yvec-1 vs xvec`) and
`examples/various/agauss_test.cir:10-45`. Slow (O(N·bins) interpreted), and much better done
in the GUI.

---

## 7. Getting the results out

### 7.1 `meas` in control mode

`com_meas()` (`src/frontend/measure.c:36`) computes the measurement and then does
`com_let("<name> = <value>")` (`src/frontend/measure.c:138-139`). Three consequences:

* The result is a **length-1 vector in whatever plot is current when `meas` runs** — i.e.
  the analysis plot. The collector must fetch it as `{$dt}.<name>`.
* The value is formatted with `"%e"` — **6 decimals, ~7 significant digits**
  (`src/frontend/measure.c:138`). Measurements stored this way carry ~1e-7 relative
  resolution regardless of `measure_get_precision()` (which only affects printing).
* Analysis types accepted: `tran`, `ac`, `dc`, `sp` (`chkAnalysisType()`,
  `src/frontend/measure.c:145-152`).
* `.meas` **cards** are refused in batch mode when `-r rawfile` is given
  (`src/frontend/measure.c:241-247`) — one more reason for a GUI to use `meas` commands
  inside `.control` rather than `.meas` cards.
* `meas` may reference another single-valued vector on the right of `=`
  (`src/frontend/measure.c:57-61` and `:64-110`), which is how a *relative* bandwidth
  measurement is written (§8).

**Detecting a failed `meas`.** On failure `com_meas` prints `meas … failed!` and returns
**without creating the vector** (`src/frontend/measure.c:132-137`). There is no
`defined()` predicate in the language, and reading a non-existent vector only produces a
warning while leaving the expression invalid — so the robust idiom is a **sentinel**:

```
ac dec 20 1k 10meg
let bw3 = -1                       $ sentinel, created in the ANALYSIS plot
meas ac bw3 when vdb(out)=-3.0103 fall=1
set dt = $curplot
setplot <collector>
let got = {$dt}.bw3
if got < 0
   ... failed ...
```

Verified end to end (`work/e17_measfail.cir`):

```
bw3                 =  1.59156e+05
run 0 : bw3 = 159156
Error: measure  bw3  when(WHEN) : out of interval
 meas ac bw3 when vdb(out)=-3.010300e+00 fall=1 failed!
run 1 : meas FAILED (sentinel survived)
Index   res
0	1.591563e+05
1	0.000000e+00
```

### 7.2 Building the cross-run vector

The idiom every shipped example uses, and the one to generate:

```
setplot new results "…" resdata        $ deterministic collector name (2.2)
let idx = vector(N)                    $ CREATE THE SCALE FIRST (7.3)
setscale idx
let colA = vector(N)
...
  <run>
  set dt = $curplot
  setplot results
  let colA[$k] = {$dt}.<meas name>
  destroy $dt
```

`let v[i] = …` assigns one element (`op_ind`, `src/frontend/parse.c:330`); the index must be
a *literal* after substitution, hence the `set k = "$&k"` dance. `unitvec(n)` (all ones) and
`vector(n)` (0..n-1) are the two allocators (`ft_funcs[]`,
`src/frontend/parse.c:414-415`); `reshape v [a][b][c]` makes it multi-dimensional
(`src/frontend/commands.c:121`).

Whole waveforms per run: `let vout{$run} = {$dt}.v(out)` — the shipped pattern in
`examples/Monte_Carlo/MonteCarlo.sp:53` and `MC_ring.sp:128`. **Transient waveforms have
different time vectors per run**, so they must be `linearize`d before they can share a
scale; verified (`work/e21b.cir`): raw 220 points, linearized 201 points, and the
linearization lands in a *new plot*.

### 7.3 The default-scale trap in a synthetic plot

`wrdata`, `plot` and `write` iterate over the plot's **default scale**, which in a synthetic
plot is *the first vector created in it*. Verified twice:

* `work/e10_nested.cir` created `let res = vector(27)` (reshaped `[3][3][3]`) first, then
  `wrdata nested.dat res[0][0] res[1][1] res[2][2]` produced **27 rows of which 24 were
  uninitialised memory**: `1.63041663e-322`, `-1.03751853e+229`, `5.37325252e-310`. `print`
  of the same slices was correct (3 rows). The scale length (27) drove the row count while
  the slices are 3 long.
* `work/e11b.cir` created `let rvals` first, and `wrdata` then wrote the correct 4 rows both
  with and without an explicit `setscale rvals`.

**Generator rules:** create an index vector first in the collector plot **and** emit
`setscale idx`; never `wrdata`/`plot` a multi-dimensional slice against a longer scale.
(The garbage output is a genuine ngspice defect worth filing under `doc/codex/issues/` —
`wrdata` should clamp to each vector's own length.)

### 7.4 Output commands a GUI can use

Verified in `work/e12_out.cir`:

```
set filetype=ascii                     $ or 'binary'; also -r / SPICE_ASCIIRAWFILE
write mc{$i}.raw v(out)                $ one rawfile per run
set appendwrite                        $ subsequent 'write' APPENDS a new plot
write multi.raw v(out)
print bw3 >> runs.txt                  $ text append; '>' truncates
wrdata file.dat vecA vecB              $ columns: scale,valA,scale,valB, ...
load multi.raw                         $ read it all back as new plots
```

Output:
```
ASCII raw file "mc0.raw" / "multi.raw"    (x3)
# run  R  f3db
bw3 = 1.591563e+05
bw3 = 7.957779e+04
bw3 = 5.305171e+04
=== load multi.raw back ===
Loading raw data file ("multi.raw") ... done.
Title:  * e12 ...   Name: AC Analysis   (x3)
List of plots available:
Current ac6 ... ac5 ... ac4 ... ac3 ... ac2 ... ac1 ... const
```

Facts:
* A multi-plot rawfile carries the **same `Plotname` and `Title` for every run** — runs are
  distinguishable only by order. If ASE-L needs labelled runs it must write one file per run
  (`mc{$i}.raw`) or add its own index vector to each plot.
* `load` assigns fresh plot numbers (`ac4 … ac6` above), continuing the global counter.
* `wrdata` emits a scale column **per vector** (pairs). A parser must take every second
  column. From `work/asel_results.dat`:
  `0.0  1.0  0.0  -40.0  0.0  0.0  0.0  1.7508e+05  0.0  1.0` — scale, corner, scale, temp,
  scale, mc, scale, bw, scale, ok.
* `wrs2p` (`src/frontend/commands.c:224`) writes Touchstone from an `sp` analysis.
* `shell <cmd>` (`src/frontend/commands.c:540`, `src/frontend/com_shell.c`) works but its
  output goes straight to fd 1 while ngspice's own output is buffered — the two interleave
  unpredictably. Never rely on ordering between `shell` output and `echo`.

### 7.5 `.csparam` — passing sweep bounds from the netlist to the script

`.csparam name = {expr}` (`src/frontend/inp.c:1027-1050`) evaluates the expression with
numparam and creates a **vector in plot `const`**. Verified (`work/e22_csparam.cir`):

```
csparams live in plot 'const':
swstart = 1.000000e+03
swstop = 4.000000e+03
swstep = 1.000000e+03
number of steps = 4
alterparam pstart = 2k ; reset
swstart = 2.000000e+03        <- re-evaluated by the re-parse
```

Useful if ASE-L wants the *schematic* to declare its sweep ranges; less useful if the GUI
computes them, which it normally will.

---

## 8. Nested sweeps — the reference recipe

`work/ref_orchestrate.cir` is the deck a GUI should emit. It sweeps **3 corners × 3
temperatures × 4 Monte Carlo cases = 36 runs**, measures a relative −3 dB bandwidth,
detects failures, and writes the sample out. It is bit-reproducible across invocations.

```spice
* ASE-L reference orchestration deck: corners x temperature x Monte Carlo
.param corner = 1
.param rnom   = 1k
.if (corner == 1)
.model dmod d is=1e-14  n=1.0
.elseif (corner == 2)
.model dmod d is=2e-14  n=1.0
.else
.model dmod d is=0.5e-14 n=1.0
.endif
.subckt leg n
Rleg n 0 r = {agauss(20k, 600, 3)}
.ends
V1 in 0 dc 0 ac 1
R1 in out {rnom}
C1 out 0 1n
D1 out 0 dmod
X1 out leg
X2 out leg
.control
  set noaskquit
  setseed 20260909

  set corners = ( 1 2 3 )
  set temps   = ( -40 27 125 )

  setplot new results "ASE-L sweep results" asel
  let idx  = vector(36)          $ create the scale FIRST
  setscale idx
  let cidx = vector(36)
  let tidx = vector(36)
  let midx = vector(36)
  let bw   = vector(36)
  let ok   = vector(36)
  let nmc  = 4                   $ a VECTOR, because loop conditions see vectors
  let ntot = 36
  let k     = 0
  let nfail = 0

  foreach c $corners
    foreach t $temps
      setplot results
      let m = 0
      dowhile m < nmc
        setplot results
        set k = "$&k"
        set m = "$&m"

        alterparam corner = $c
        reset                    $ re-parse: new .if branch AND new MC draws
        set temp = $t            $ CKTtemp, no re-parse needed

        ac dec 30 1k 30meg

        meas ac vlo FIND vdb(out) AT=1k
        let vtarget = vlo - 3.0103
        let bw3 = -1                        $ sentinel
        meas ac bw3 WHEN vdb(out)=vtarget FALL=1

        set dt = $curplot
        setplot results
        let st  = $sim_status
        let got = {$dt}.bw3
        let idx[$k]  = k
        let cidx[$k] = $c
        let tidx[$k] = $t
        let midx[$k] = m
        if (got < 0) | (st = 1)
          let ok[$k] = 0
          let bw[$k] = 0
          let nfail  = nfail + 1
          echo "RUN $k/$&ntot corner=$c temp=$t mc=$m  FAILED"
        else
          let ok[$k] = 1
          let bw[$k] = got
          echo "RUN $k/$&ntot corner=$c temp=$t mc=$m  bw3=$&got"
        end
        destroy $dt
        let k = k + 1
        let m = m + 1
      end
    end
  end

  setplot results
  let mu = mean(bw) $ let sd = stddev(bw)
  let lo = vecmin(bw) $ let hi = vecmax(bw)
  echo ""
  echo "completed $&k runs, $&nfail failures"
  echo "bw3: mean $&mu  sigma $&sd  min $&lo  max $&hi"
  settype frequency bw
  wrdata asel_results.dat cidx tidx midx bw ok
  write asel_results.raw cidx tidx midx bw ok
.endc
.end
```

Output (36 lines, abbreviated in the middle):

```
RUN 0/36 corner=1 temp=-40 mc=0  bw3=175080
RUN 1/36 corner=1 temp=-40 mc=1  bw3=175003
RUN 2/36 corner=1 temp=-40 mc=2  bw3=175129
RUN 3/36 corner=1 temp=-40 mc=3  bw3=175046
RUN 4/36 corner=1 temp=27 mc=0  bw3=175151
...
RUN 33/36 corner=3 temp=125 mc=1  bw3=174951
RUN 34/36 corner=3 temp=125 mc=2  bw3=174894
RUN 35/36 corner=3 temp=125 mc=3  bw3=175138

completed 36 runs, 0 failures
bw3: mean 175067  sigma 103.1  min 174874  max 175273
binary raw file "asel_results.raw"
```

`asel_results.dat`, first rows (scale,corner, scale,temp, scale,mc, scale,bw, scale,ok):

```
 0.00000000e+00  1.00000000e+00  0.00000000e+00 -4.00000000e+01  0.00000000e+00  0.00000000e+00  0.00000000e+00  1.75080200e+05  0.00000000e+00  1.00000000e+00
 1.00000000e+00  1.00000000e+00  1.00000000e+00 -4.00000000e+01  1.00000000e+00  1.00000000e+00  1.00000000e+00  1.75003400e+05  1.00000000e+00  1.00000000e+00
 2.00000000e+00  1.00000000e+00  2.00000000e+00 -4.00000000e+01  2.00000000e+00  2.00000000e+00  2.00000000e+00  1.75128700e+05  2.00000000e+00  1.00000000e+00
```

Reproducibility and cost:

```
$ ngspice -b ref_orchestrate.cir | grep ^RUN > run_a.txt
$ ngspice -b ref_orchestrate.cir | grep ^RUN > run_b.txt
$ diff run_a.txt run_b.txt   ->  REPRODUCIBLE: two invocations identical
$ time ngspice -b ref_orchestrate.cir   ->  real 0m0.102s
```

### 8.1 What nesting costs

There is **no sharing between iterations**. Cost model:

```
total = N_runs * (re-parse? + setup + solve + output)
N_runs = prod(len(axis_i))
```

* Re-parse (`reset`/`mc_source`) is a full `inp_readall`-equivalent pass over the stored
  deck + numparam + subckt expansion + `inp_dodeck`. Measured 5.5 ms for 4000 device lines;
  it scales with deck size, not with matrix size. For a PDK deck with thousands of
  subcircuit instantiations this is easily 0.5–2 s per run.
* Device setup (`CKTsetup`, `SetAnalyse("Device Setup")`,
  `src/spicelib/analysis/cktsetup.c:327`) also re-runs.
* Nothing is parallel. `USE_OMP` (on in this build, `config.h:570`) parallelises the
  *matrix load* inside one analysis; it does not run iterations concurrently.
* One plot per run is retained unless destroyed — a 1000-run transient MC of a 200-node
  circuit at 10 000 points is ~1.6 GB of doubles. `destroy $dt` + `.save` are not optional.

**Therefore: the nesting order should put the axis that needs a re-parse innermost-last.**
In the reference deck, `corner` requires a re-parse (`.if`), so it is the *outer* loop and
`reset` happens per run anyway; if only `rnom` were swept, the whole loop could use `alter`
with no `reset` at all and would be ~10× faster. A good GUI computes, per axis, whether it
can be realised with `alter`/`altermod`/`set temp` (no re-parse) or needs
`alterparam`+`reset`, hoists the re-parse to the innermost point where it is actually
required, and tells the user the estimated cost before starting.

**The alternative worth offering: N separate ngspice processes.** Because every axis point
is independent, a GUI can shard the matrix over processes (one deck per shard, `-r` rawfiles,
merged in Tcl). That is the only way to use more than one core for a sweep, and it also
makes abort trivial (kill the process). The only thing lost is the single in-memory
collector plot.

---

## 9. Run count, progress, and abort

### 9.1 Run count

There is no run counter. The generated script must carry its own (`let k`, `let ntot`) and
`echo` it — as the reference deck does. `$&k` / `$&ntot` are the only way the GUI learns
where it is.

### 9.2 Progress

`SetAnalyse(<phase>, <per-mille>)` is the internal progress hook. Call sites:
`src/spicelib/analysis/dctran.c:475,477` (`"tran init"`, `"tran"`),
`acan.c:362,375` (`"ac"`), `dctrcurv.c:479` (`"dc"`), `cktop.c:35` (`"op"`),
`cktsetup.c:327` (`"Device Setup"`), `inppas2.c:92` (`"Parse"`),
`optran.c:329,494`, `dcpss.c:1051-1055`, `measure.c:232`, `spec.c:260`,
`src/frontend/inp.c:521,866` (`"Source Deck"`, `"Prepare Deck"`).

But it is **build-gated**:

```c
/* src/include/ngspice/ngspice.h:130-134 */
#ifdef HAS_WINGUI
#include "ngspice/wstdio.h"
#define HAS_PROGREP
extern void SetAnalyse(const char *Analyse, int Percent);
#endif
/* src/include/ngspice/ngspice.h:297-299  (inside the SHARED_MODULE section) */
extern void SetAnalyse(const char *analyse, int percent);
#define HAS_PROGREP
```

`HAS_PROGREP` is defined only under `HAS_WINGUI` (the Windows GUI build) or
`SHARED_MODULE` (`--with-ngshared`). In this tree `build-ver_50/src/include/ngspice/config.h:550`
says `/* #undef SHARED_MODULE */` and there is no WINGUI, so **the console `ngspice` binary
emits no progress information at all.** There are exactly two ways for a Linux GUI to show
progress:

1. **Link `libngspice`** (`--with-ngshared`, off by default) and pass a `SendStat` callback
   to `ngSpice_Init()` (`src/include/ngspice/sharedspice.h:437`). `SetAnalyse` there
   (`src/sharedspice.c:1958`) throttles to one update per `DELTATIME 150` ms
   (`src/sharedspice.c:1955`) and hands the caller strings like `"tran 512"`. The shared
   build also gives `bg_run` / `bg_halt` / `bg_pstop` / `bg_ctrl`
   (`src/sharedspice.c:649-720`), `ngSpice_running()`
   (`src/include/ngspice/sharedspice.h:539`), `ngSpice_CurPlot()`, `ngSpice_AllPlots()`,
   `ngSpice_AllVecs()` (`:523-535`) — i.e. a proper asynchronous, interruptible run with
   live plot enumeration. **This is the right architecture for ASE-L if it can depend on a
   shared build.**
2. **Parse stdout of the console binary.** The generated script's own
   `echo "RUN $k/$&ntot …"` lines are the *only* per-run signal; within a run the binary
   prints `Doing analysis at TEMP = …`, `Using SPARSE 1.3 as Direct Linear Solver` /
   `Using KLU as Direct Linear Solver`, and `No. of Data Rows : N` at the end of each
   analysis. Nothing reports fractional progress inside a long transient. `rusage`
   (`src/frontend/commands.c:544`) can be emitted per run for timing.

**Generator rule: always emit an `echo` progress line per run with the index and the axis
values.** It is the GUI's only handle in the subprocess architecture, and it costs nothing.

### 9.3 Abort — the ugly part

Signal path (`src/frontend/signal_handler.c:82-110`):

```c
void ft_sigintr(void) {
    static int interrupt_counter = 0;
    (void) signal(SIGINT, ft_sigintr);
    if (ft_intrpt) { fprintf(cp_err, "\nInterrupted again (ouch)\n"); interrupt_counter++; }
    else           { fprintf(cp_err, "\nInterrupted once . . .\n"); ft_intrpt = TRUE; interrupt_counter = 1; }
    if (interrupt_counter >= 3) { ... controlled_exit(1); }
    if (ft_setflag) return;     /* inside a simulation: just set the flag */
    cp_background = FALSE;
    LONGJMP(jbuf, 1);           /* between commands: unwind to main() */
}
```

`ft_setflag` is `TRUE` for the duration of an analysis (`src/frontend/runcoms.c:286`, cleared
at `:373`). So:

* **Ctrl-C *during* an analysis** sets `ft_intrpt`; the analysis stops at its next output
  point (`OUTstopnow()`, `src/frontend/outitf.c:1711-1719`), prints
  `<what> simulation interrupted` (`src/frontend/runcoms.c:345`) — and then
  **`cp_periodic()` clears the flag** (`src/frontend/cpitf.c:380-386`:
  `ft_setflag = FALSE; ft_intrpt = FALSE;`), which runs after every command
  (`src/frontend/control.c:262`). **The loop continues to the next iteration.** One Ctrl-C
  aborts one run, not the sweep.
* Worse, an interrupted run leaves `sim_status = 0` — the `err == 1` branch at
  `src/frontend/runcoms.c:343-347` explicitly resets `err = 0` and does **not** call
  `cp_vset("sim_status", …)`. An interrupted run is indistinguishable from a successful one
  through `$sim_status`.
* **Ctrl-C *between* commands** longjmps to `main()`'s `setjmp`, which calls
  `ft_sigintr_cleanup()` → `cp_resetcontrol(TRUE)`
  (`src/frontend/signal_handler.c:55-77`) — **the entire control block is discarded**, with
  `Warning: clearing control structures` (`src/frontend/control.c:900`). All collector
  vectors survive (they live in plots) but the loop is gone.
* **Three Ctrl-Cs** exit the process (`interrupt_counter >= 3`).

So Ctrl-C behaviour is *timing dependent*: it either kills one run and continues, or kills
the whole script, and the user cannot tell which. **For a GUI this is unusable as an abort
mechanism.**

Workable alternatives, in order of preference:
1. **One process per shard** (§8.1) — abort = `kill`.
2. **`libngspice` + `bg_run`/`bg_halt`** (`src/sharedspice.c:649-720`) — a real pause/stop.
3. **Cooperative abort inside the generated script**: have the loop check a file the GUI
   writes, e.g.
   ```
   fopen fd < abort.flag ; if $fd >= 0 ; break ; end ; fclose $fd
   ```
   using `fopen`/`fread`/`fclose` (`src/frontend/commands.c:641,646,652`,
   `src/frontend/com_fileio.c`). This is how `vlnggen` probes for files
   (`src/xspice/verilog/vlnggen`), so the idiom is established in the tree.
4. Emit `quit` from inside the loop when the GUI's condition is met (with `set noaskquit`,
   `src/frontend/misccoms.c`), which ends the process cleanly.

### 9.4 `sim_status`

Set by `dosim()` (`src/frontend/runcoms.c:206`):

| condition | `sim_status` | message | anchor |
|---|---|---|---|
| start of every analysis | `0` | — | `runcoms.c:329` |
| success | `0` | — | `runcoms.c:361` |
| interrupted (`err == 1`) | **`0`** | `<what> simulation interrupted` | `runcoms.c:343-347` |
| aborted (`err == 2`) | `1` | `<what> simulation(s) aborted` | `runcoms.c:348-353` |
| not started (`err == 3`) | `1` | `<what> simulation not started` | `runcoms.c:354-359` |

Measured (`work/e16b.cir`): a **floating subnet** produced
`Warning: singular matrix: check node f1`, `Dynamic gmin stepping failed`,
`True gmin stepping failed`, `source stepping failed` — and **`sim_status` stayed 0**.
A bad argument (`tran 1n 0`) produced `tran simulation(s) aborted` and `sim_status = 1`,
and the loop continued afterwards.

**Generator rule: `$sim_status` is necessary but far from sufficient.** ASE-L must also
(a) use the sentinel idiom of §7.1 for every measurement, and (b) grep the run's stderr for
`singular matrix`, `Timestep too small`, `iteration limit reached`, `simulation interrupted`,
`gmin stepping failed`, `source stepping failed`, `Warning: no DC convergence`.

An **invalid `if` condition silently takes the false branch.** Measured: with `st` an
undefined vector, `if (got < 0) | (st = 1)` printed only a `checkvalid` warning and executed
the `else` arm — so a broken failure check reports every run as a success.
`examples/Monte_Carlo/MC_ring.sp:100-118` shows the shipped idiom
(`let simstat = $sim_status`, `if simstat = 1`, `destroy $curplot`, `goto next`); note it
depends on `simstat` being created in the right plot.

---

## 10. Sharp edges — the blunt list

Ordered by how badly they will bite a GUI that does not know about them.

1. **`.option seed=<n>` turns Monte Carlo into N copies of one sample.** `eval_opt()` runs
   on every re-parse (`src/frontend/inp.c:612`), so `reset`/`mc_source` re-seed to the same
   value before every draw. Measured in §6.3. Never emit it for a statistical run.
2. **The first parse of the deck is seeded from `getpid()`.** `initw()` does
   `srand(getpid()); TausSeed();` (`src/frontend/trannoise/wallace.c:83-85`) at
   `src/main.c:1371`, after `main.c:938` set a deterministic seed. Netlist-level `agauss`
   in the initial parse is irreproducible; control-language `sgauss` is not, because it
   calls `checkseed()`. Always `reset` before the first measured run.
3. **`.param` inside `.if`/`.elseif`/`.else` is not conditional.** numparam evaluates all
   branches (`inp_subcktexpand` at `src/frontend/inp.c:937` precedes `dotifeval` at
   `:1022`); the last textual `.param` wins. Measured in §5.2: three "different" corners all
   used `rmul = 1.1`. Only device/`.model`/`.subckt` cards are conditional.
4. **Plot names are not `<type><run>`.** `plot_num` is one global counter advanced only on
   collision (`src/frontend/vectors.c:1104-1111`). Measured: `op1 op2 tran2 ac2 tran3 ac3
   dc3 op3` with no `tran1`/`ac1`/`dc1`. Capture `$curplot`.
5. **`destroy all` resets `plot_num` to 1** (`src/frontend/postcoms.c:1048`) and deletes the
   collector plot along with everything else. Cached names go stale; results vanish.
6. **`linearize`, `fft`, `psd`, `spec`, `cutout` and `load` all create new plots.**
   Re-read `$curplot`.
7. **A `plotname.` prefix that matches nothing silently reads from the current plot**
   (`src/frontend/vectors.c:809-811`). `let x = ac7.v(out)` with no `ac7` returns the wrong
   number with no error.
8. **`setplot <name>` is a case-sensitive *prefix* match, `destroy <name>` is byte-exact.**
   `setplot tran` means "newest transient plot" (`plot_prefix`,
   `src/frontend/vectors.c:1621`, list order `:1479`).
9. **Variables and vectors are different namespaces, and a loop condition sees only
   vectors.** `set n = 4` + `dowhile m < n` runs the body **once** and warns on stderr.
   Measured in §1.2. All bounds must be `let` vectors.
10. **An invalid `if`/`while` condition takes the false branch instead of erroring.**
11. **`$var` swallows a following `.` `-` `(` `[` `&` `#` `?` `@`** (`VALIDCHARS`,
    `src/frontend/variable.c:875`). `source deck_$c.cir` looks for the variable `c.cir`.
    Always `{$var}`.
12. **`$&vec` truncates to 6 significant digits** (`"%G"`,
    `src/frontend/variable.c:55`) unless `set csnumprec`. Measured: `1234.56789012345`
    became `1234.57`. Pass vectors to `alter` by name, or set `csnumprec = 17`.
13. **`meas` results are stored with `"%e"`, ~7 significant digits**
    (`src/frontend/measure.c:138`).
14. **A failed `meas` creates no vector**, and there is no existence predicate. Use the
    sentinel idiom (§7.1) or the collector element keeps its previous value silently.
15. **`sim_status` is 0 for an interrupted run and 0 for a non-converged OP with
    `singular matrix` warnings.** Measured in §9.4.
16. **Ctrl-C aborts one run, not the sweep — or destroys the whole control block, depending
    on when it lands.** `cp_periodic()` clears `ft_intrpt` after every command
    (`src/frontend/cpitf.c:383`). Three presses exit.
17. **No progress reporting in the console build.** `HAS_PROGREP` requires `HAS_WINGUI` or
    `SHARED_MODULE` (`src/include/ngspice/ngspice.h:132,299`); this build has neither
    (`config.h:550`).
18. **`save` is lost by `reset`/`mc_source`; `.save` cards survive.** Measured in §5.6.
    `examples/Monte_Carlo/MC_ring.sp:39` has this bug.
19. **`mc_source` leaks a whole circuit per call** (`setcirc` shows 4 after 3 calls);
    `reset` does not, and re-draws the random numbers just the same. Measured in §5.5.
20. **`wrdata`/`plot` iterate over the plot's default scale**, which in a synthetic plot is
    the first vector created. A reshaped 27-element vector as the first vector made
    `wrdata res[0][0] …` emit 24 rows of uninitialised memory
    (`1.63041663e-322`, `-1.03751853e+229`). Measured in §7.3. Create the index vector first
    and `setscale` it.
21. **`.model` cards with a parenthesised parameter list plus a random function are a fatal
    parse error**: `.model d1 d (is=agauss(1e-14,1e-15,3))` →
    `Cannot compute substitute` → `exit(1)`. Drop the outer parens.
22. **`agauss`/`gauss` silently return the nominal value if `sigma <= 0` or the variation is
    `<= 0`** (`src/frontend/numparam/xpressn.c:49,61`). Validate in the GUI.
23. **`agauss`/`gauss`/`unif`/`aunif`/`limit` do not exist in the control language;
    `sgauss`/`sunif`/`rnd`/`poisson`/`exponential` do not exist in the netlist.** Two
    disjoint sets, and the manual documents them in two different chapters (2.8.5 vs 17.8.6
    / 18.5). A GUI that lets the user type a distribution must know which side of the fence
    the expression will be evaluated on.
24. **`rnd()` uses libc `rand()`** — a different stream from everything else, capped at
    `RAND_MAX` (`src/maths/cmaths/cmath2.c:126-131,155`).
25. **Nets or vectors named `eq le ge lt gt ne or and not` break the expression parser.**
    Measured in §1.3 (`print v(eq)` → `PPerror: syntax error`).
26. **`goto`/`label` are case-sensitive** (`eq()`, `src/frontend/control.c:69`) while almost
    everything else in the language is not.
27. **A bare `repeat` loops forever** (`src/frontend/control.c:724`).
28. **`dowhile` always runs its body once**, so a 0-iteration axis silently becomes a
    1-iteration axis. Use `while` for counts that may be zero.
29. **`reset` prints `Reset re-loads circuit <title>` to stdout on every call**
    (`src/frontend/inp.c:551`), and every analysis prints `Doing analysis at TEMP = …`,
    the solver banner, and `No. of Data Rows : N`. A 1000-run sweep produces thousands of
    lines the GUI must filter. `.options noacct` / `set noacct` removes the accounting
    block; nothing suppresses the reset banner.
30. **`shell` output interleaves unpredictably** with ngspice's buffered stdout.
31. **A multi-plot rawfile written with `set appendwrite` labels every plot identically**
    (`Plotname: AC Analysis`, same `Title`). Runs are order-only.
32. **`set temp` is sticky across runs and across `reset`**, so a nominal run after a −40 °C
    run silently stays at −40 °C unless the temperature is set explicitly every time.
33. **`.dc` with two sources returns one plot with a repeating scale**, not a 2-D vector; the
    GUI must slice it.
34. **Nothing in a sweep is parallel or shared**; `USE_OMP` only parallelises the matrix load
    within one analysis.
35. **`alter` on a `casemode=preserve` deck needs the deck's exact spelling** — the
    lower-casing at `src/frontend/device.c:1409-1419` is conditional on
    `inp_case_folding()`. This build's spinit documents `set casemode=preserve` at
    `build-ver_50/src/spinit:17`.

---

## 11. What ASE-L should expose, concretely

A "Parametric / Corners / Statistical" panel that produces one generated `.control` block.
The GUI's model, mapped onto what actually exists:

* **Axis** = (kind, name, values). Kinds and their realisation:
  * *design variable / `.param`* → `alterparam <name> = <v>` + `reset` (per-run re-parse).
  * *instance parameter* → `alter <flat-name> <param> = <v>` (no re-parse).
  * *model parameter* → `altermod @<model>[<param>] = <v>` (no re-parse).
  * *temperature* → `set temp = <v>`; collapse to `dc temp <a> <b> <s>` when it is the only
    axis and the analysis is `op`/`dc`.
  * *corner* → one generated top-level deck per corner, `source`d (route B, §5.3); or `.if`
    on a `.param` **with models only** (§5.4).
  * *statistical* → a run count plus a seed, realised as `setseed <n>` once + `reset` per
    run (netlist randomness), or `sgauss`-driven `alter` (control randomness).
* **Values** = explicit list, or linear/log range (GUI expands it; do not make ngspice
  compute it), or `compose … gauss=/unif=` when the user asks for a random sample it should
  be able to inspect.
* **Per-run outputs** = a list of `meas` statements. Each gets a sentinel and a column in the
  collector plot. Store the axis coordinates as columns too — that is the only thing that
  makes the result table joinable.
* **Launch** = `ngspice -b <deck>` per shard (recommended) or one process with the whole
  matrix. Show progress from the generated `echo` lines. Offer "abort" as process kill and,
  when the loop is long, as a cooperative flag file.
* **Results** = read `wrdata`/`write` output back into Tcl and do sorting, medians,
  percentiles, histograms, yield and corner-worst-case there. ngspice gives you
  `mean`/`stddev`/`vecmin`/`vecmax`/`sortorder` and nothing else.
* **Reproducibility contract to show the user**: the seed, whether `.option seed` is present
  in the deck (warn loudly if it is), and the fact that the campaign begins with a `reset`.

