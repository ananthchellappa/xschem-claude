# 0822 — `autoload` and `sim_type` execute from a `.sch` attribute too, and 0821 names neither

Status: **measured LIVE at HEAD, NOT FIXED.** Found by the lead 2026-08-25 21:50
while preparing the independent verification of the in-flight 0821+0816+0817 crew,
by reading the site 0821 points at and noticing its two neighbours.
Family: 0812 (fixed, C side) / 0816 / 0817 / **0821** (the Tcl side, in flight).
Severity: **high, and identical to 0821's** — a `.sch` file is a document people
mail each other.

⚠ **Filed as a separate number deliberately.** 0821 is being worked right now and
its file is open to another agent; an edit from the lead would collide. Everything
here belongs to 0821's subject and should be folded into it — or fixed with it —
at the first moment that is safe.

## 1. Why this exists as its own issue

0821 §1 names **two** sites: `src/xschem.tcl:4775` (`graph_fill_listbox`, live, 8
call sites) and `:4842` (`raw_is_loaded`, dead, 1 textual occurrence = its own
`proc` line, zero callers — confirmed).

**There are two more, three lines from the first, in the same proc, on the same
rect, out of the same file.** They are not `rawfile`; that is the only reason they
were missed:

```tcl
4772:  set autoload [uplevel #0 {subst [xschem getprop rect 2 $graph_selected autoload 2]}]
4775:  set rawfile  [xschem getprop rect 2 $graph_selected rawfile]
4775:    if {![catch {eval uplevel #0 {subst $rawfile}} res]} { set rawfile $res }
4779:  set sim_type [uplevel #0 {subst [xschem getprop rect 2 $graph_selected sim_type 2]}]
```

`uplevel #0 {subst [xschem getprop …]}` is braced, so `uplevel` evaluates the
script *at level #0*: `[xschem getprop …]` runs there and returns the attribute
**string**, and bare `subst` — no `-nocommands`, no `-nobackslashes` — is then
applied to it. Command substitution inside that string executes.

**A fix that closes 4775 alone closes one of three and reports 0821 fixed.**

## 2. Measured, at HEAD

`src/xschem` at `64e10e93`, `--nogui --pipe -q`, binary verified fresh
(`find src -maxdepth 1 -newer src/xschem` = 0). Fixture is one graph rect whose
three attributes each carry a distinct payload:

```
B 2 100 -100 500 -300 {flags=graph
rawfile="[exec touch OWNED_RAWFILE]/x.raw"
autoload="[exec touch OWNED_AUTOLOAD]1"
sim_type="[exec touch OWNED_SIMTYPE]tran"
}
```

Replaying the three lines of `graph_fill_listbox` verbatim:

```
GETPROP rawfile  = |[exec touch OWNED_RAWFILE]/x.raw|
GETPROP autoload = |[exec touch OWNED_AUTOLOAD]1|
GETPROP sim_type = |[exec touch OWNED_SIMTYPE]tran|
4772-autoload  rc=0 res=|1|
4775-rawfile   rc=0 res=|/x.raw|
4779-sim_type  rc=0 res=|tran|
OWNED: OWNED_AUTOLOAD OWNED_RAWFILE OWNED_SIMTYPE
```

**All three fired.** Three files created by a schematic that was merely opened and
whose Graph dialog was merely refreshed.

## 3. The part that makes it worse than 0821 alone

**`rc=0`, and the value the caller receives is exactly what a legitimate attribute
would have produced.** `autoload` comes back `1`, `sim_type` comes back `tran`,
`rawfile` comes back `/x.raw`. The payload is consumed by the substitution and
leaves **no residue in the result**, so:

* nothing is logged, nothing raises, nothing looks wrong;
* the dialog then behaves *correctly* — `xschem raw $autoload $rawfile $sim_type`
  gets sane arguments and loads;
* there is no failed-parse breadcrumb of the kind 0812's crafted **filename** left
  behind, because here the attacker controls the whole string and can make it
  reduce to a valid value.

0821's own vector at least had to survive being used as a path. These two do not:
`autoload` is tested `{$autoload ne {} && $autoload}` and `sim_type` is compared to
`table`. Any payload reducing to `1`/`0` or to a type name is invisible.

## 4. One property-parser fact a fixture needs

The value **must be quoted in the `.sch`** or the property parser truncates it at
the first space — an unquoted `rawfile=[exec touch X]/x.raw` reaches `getprop` as
the string `[exec`, which then fails `missing close-bracket` (measured first, and
it is why the first fixture read as a false negative). A real attacker quotes.
A regression row that forgets to quote passes against a live defect.

## 5. Fix

Whatever shape 0821's crew lands for `rawfile` applies unchanged to both. Per 0817's
caveat the answer is **not** `subst -nobackslashes -nocommands` — 0812 §1 measured
that a command substitution in a variable **array index** (`$a([...])`) still
executes under those flags. The in-tree answer is 0812's C scanner
`expand_tcl_vars()` (`src/util.c`, declared in `src/xschem.h`), which expands
`$name`, `${name}` and `$ns::name` and treats everything else as literal bytes.

For `autoload` and `sim_type` there is a **stronger and simpler** option than for
`rawfile`, and it should be preferred: **neither is a path and neither needs
variable expansion at all.** `autoload` is a boolean and `sim_type` is one of a
small closed set. Validate rather than expand — `string is boolean` and a
membership test against the known types — and the substitution disappears instead
of being made safe. That is a smaller blast radius than `rawfile`, which genuinely
does need `$netlist_dir`-style expansion.

⚠ If that is taken, say so explicitly in the write-up: it means `autoload` and
`sim_type` **stop** honouring `$var` in a `.sch`, which is a behaviour change on a
documented-by-accident surface. Nothing in `xschem_library/` uses it — worth a
census before shipping, not an assumption.

## 6. Acceptance

1. The fixture of §2, opened and refreshed, creates **zero** `OWNED_*` files —
   all three attributes, not just `rawfile`.
2. A legitimate graph rect still loads: `rawfile=$netlist_dir/x.raw`,
   `autoload=1`, `sim_type=tran` behave exactly as at HEAD. **This is the
   counterweight** — a fix that breaks graph loading passes acceptance 1 trivially.
3. The `.sch` quoting fact of §4 is exercised, so the row cannot pass by truncation.
4. `raw_is_loaded` (`:4842`) is dealt with as 0821 decides — its zero callers make
   deletion defensible, but that is 0821's call, not this issue's.
