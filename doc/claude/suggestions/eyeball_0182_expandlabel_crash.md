# Manual eyeball — issue 0182, `expandlabel()` zero/negative-multiplicity crash

Fix: commit `2a8d5718` on `fluid-editing`, **not pushed**. Issue doc:
`doc/claude/issues/0182-expandlabel-zero-negative-multiplicity-crash.md`.

**Why this doc exists.** 0182 is a headless issue and its automated coverage is 92 checks,
RED-verified. But **two surfaces were never seen by a human or by any test**: the
once-per-schematic warning as it actually renders in the info window, and the
`tk_messageBox` that rule 2 sends a negative multiplier to. Both are behind `has_x`, which
is 0 in every `--nogui` run. Steps C and D below are the whole reason to open this file;
A, B and E are cheap re-confirmations you can skip if you trust the suite.

Everything here runs from the repo root:

```sh
cd /home/qflow/dev/xschem/claude_1/xschem
```

---

## Step 0 — you need a pre-fix binary for steps A and B

```sh
git show 2a8d5718~1:src/expandlabel.y > /tmp/eyeball/expandlabel.y.pre   # keep the originals
git show 2a8d5718~1:src/parselabel.l  > /tmp/eyeball/parselabel.l.pre
mkdir -p /tmp/eyeball
cp src/expandlabel.y src/parselabel.l src/netlist.c src/xschem.h /tmp/eyeball/   # save the FIXED ones
git show 2a8d5718~1:src/expandlabel.y > src/expandlabel.y
git show 2a8d5718~1:src/parselabel.l  > src/parselabel.l
git show 2a8d5718~1:src/netlist.c     > src/netlist.c
git show 2a8d5718~1:src/xschem.h      > src/xschem.h
(cd src && make) && cp src/xschem /tmp/eyeball/xschem.pre
cp /tmp/eyeball/expandlabel.y /tmp/eyeball/parselabel.l /tmp/eyeball/netlist.c /tmp/eyeball/xschem.h src/
(cd src && make)
git status --short src/          # MUST be empty -- see the trap below
```

**Two traps, both already paid for.**

* `git checkout <sha> -- <file>` writes the **INDEX** as well as the worktree, so a later
  `git commit -a` silently reverts the fix. `git show <sha>:<f> > <f>` touches only the
  worktree — that is why every line above uses `git show`.
* `git stash push src/<f>` on a **clean** tree stashes nothing, so the "pre-fix" binary is
  the fixed one and every diff below comes back vacuously clean
  (trap 3 in `tests/netlist_diff/netlist_diff.sh`).

**Confirm the pre-fix binary really is pre-fix** before trusting steps A/B:

```sh
/tmp/eyeball/xschem.pre --nogui --pipe -q --nolog --script /dev/stdin <<'EOF'
puts [xschem expandlabel {2*(0*a)}]
EOF
```
Must print `FATAL: signal 11`. If it prints `2*(0*a) -1`, you rebuilt the fixed source.

---

## Step A — the crash is gone (headless, ~1 min)

Write `/tmp/eyeball/battery.sh`:

```sh
#!/bin/sh
XS=${1:-/home/qflow/dev/xschem/claude_1/xschem/src/xschem}
cd /home/qflow/dev/xschem/claude_1/xschem/src || exit 1
run_one() {
  out=$(printf 'puts "OUT:[xschem expandlabel {%s}]"\n' "$1" | \
        "$XS" --nogui --pipe -q --nolog --script /dev/stdin 2>/tmp/eyeball/err.txt)
  line=$(printf '%s\n' "$out" | grep '^OUT:' | head -1 | sed 's/^OUT://')
  e=$(grep -c 'syntax error in' /tmp/eyeball/err.txt)
  [ -z "$line" ] && printf '%-16s CRASH\n' "[$1]" || printf '%-16s |%s| syn=%s\n' "[$1]" "$line" "$e"
}
run_one ""; run_one " "
while IFS= read -r l; do run_one "$l"; done <<'LABS'
a
a,b
a[3:0]
0*a
a*0
2*a
0*a,b
b,0*a
a,0*b,c
2*(0*a)
(0*a)*2
0*a*2
2*0*a
2*0*a,c
a[3:0:1:0]
a[0:0:0:0]
a[3:0:1:2]
a[1:1]
$foo
*
,
a,
,a
a,,b
1*a
-1*a
a*-1
0*a,0*b
(a,b)*0
0*(a,b)
0*a[3:0]
a[3:0]*0
2*(0*a,b)
a.b
a:b
a,b,
LABS
```

```sh
sh /tmp/eyeball/battery.sh /tmp/eyeball/xschem.pre > /tmp/eyeball/pre.txt
sh /tmp/eyeball/battery.sh                         > /tmp/eyeball/post.txt
diff /tmp/eyeball/pre.txt /tmp/eyeball/post.txt
```

**Expect exactly 8 changed lines**, every one going `CRASH` → a real answer.

**What a failure looks like:** any *other* line differing. Those 30 rows are controls, and
a control that moves means the fix changed a label that already worked. The extended
battery (`battery2.sh` in the 0182 session scratchpad) covers 21 more crashers the same
way; the shape of the check is identical.

---

## Step B — read the semantics yourself

```sh
grep -E '2\*\(0\*a\)|a\[3:0:1:0\]|2\*0\*a,c|\[-1\*a\]' /tmp/eyeball/post.txt
```

| input | expect | why |
|---|---|---|
| `2*(0*a)` | `2*(0*a) -1` | rule 1 — original text back, multiplicity -1 |
| `a[3:0:1:0]` | `a[3:0:1:0] -1` | rule 1, bus arm |
| `2*0*a,c` | `,c 1` | the zero part is a **sub-expression**; parallel to today's `0*a,b` → `,b` |
| `-1*a` | `-1*a -1  syn=1` | rule 2 — the existing syntax-error path fired |

The `-1` matters more than it looks. `expandlabel()` returns NULL **only** for a NULL input
and sets `*m = -1` there; sibling loops such as `hilight.c:1008` are safe only because of
that coupling. If a collapse ever came back with `m == 0` instead, those loops would run.

---

## Step C — the warning ← **needs the GUI, never been seen**

Save as `/tmp/eyeball/eyeball_0182.sch`:

```
v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
E {}
N 0 0 200 0 {}
N 0 100 200 100 {}
N 0 200 200 200 {}
N 0 300 200 300 {}
N 0 400 200 400 {}
C {devices/lab_pin.sym} 0 0 0 0 {name=lA lab=2*(0*a)}
C {devices/lab_pin.sym} 0 100 0 0 {name=lB lab=0*b}
C {devices/lab_pin.sym} 0 200 0 0 {name=lC lab=c[3:0:1:0]}
C {devices/lab_pin.sym} 0 300 0 0 {name=lD lab=dd}
C {devices/lab_pin.sym} 0 400 0 0 {name=lE lab=e[3:0]}
```

```sh
./src/xschem /tmp/eyeball/eyeball_0182.sch
```

Netlist it, then read the info window.

| instance | `lab` | expect |
|---|---|---|
| lA | `2*(0*a)` | **warns**, instance turns pin-colour |
| lC | `c[3:0:1:0]` | **warns**, instance turns pin-colour |
| lB | `0*b` | **silent** |
| lD | `dd` | silent |
| lE | `e[3:0]` | silent |

Exact text:

```
Warning: instance: lA: net name '2*(0*a)' has a zero-width sub-expression and
expands to nothing; it names no node
```

**What a failure looks like — in priority order:**

1. **lB warns.** This is the one to hunt for. `0*b` has always expanded to itself with
   `m == -1` and is legal input; warning about it turns the fix into a nag on schematics
   that work today. The discrimination is that `0*a` reaches NULL through the `n==0` early
   return, which deliberately does **not** set `expandlabel_collapsed`. If lB warns, that
   distinction has been lost.
2. **More than two warning lines.** The `print_erc` gate (`netlist.c:1426`) exists because
   `prepare_netlist_structs()` runs twice per netlist — once on the way down, once on the
   reload. Three or more lines means the gate leaks and the warning is per-pass, not
   per-schematic.
3. **No highlight.** The warning sets `inst[i].color = -PINLAYER` and
   `xctx->hilight_nets = 1`, same as the other ERC checks in that loop. Text without
   colour means only half the precedent was copied.

---

## Step D — the syntax dialog ← **needs the GUI, never been seen**

Save as `/tmp/eyeball/eyeball_neg.sch`:

```
v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
E {}
N 0 0 200 0 {}
C {devices/lab_pin.sym} 0 0 0 0 {name=lN lab=-1*a}
```

```sh
./src/xschem /tmp/eyeball/eyeball_neg.sch
```

Netlist. Expect the **pre-existing** dialog, unchanged:

> Syntax error in identifier expansion: -1*a
> schematic: /tmp/eyeball/eyeball_neg.sch

**What a failure looks like:** no dialog at all. Headless, `has_x` is 0 and only the
`fprintf(errfp, "syntax error in %s\n", s)` runs — so the `tcleval(cmd)` branch at
`parselabel.l:127` that actually pops the box is unexercised by every test in the tree.
If nothing appears, rule 2 is only half-wired.

**Second thing to watch:** the dialog fires **once per netlist run**, not once per bad
label. `yyparse_error` latches to -1 after the first report and is only reset to 0 at the
start of a netlist (`scheduler.c:7601`, `callback.c:6200`). That is pre-existing behaviour
shared with every malformed label — worth knowing so it does not read as a new bug.

---

## Step E — nothing else moved

Already run and clean, but repeatable:

```sh
tests/netlist_diff/netlist_diff.sh /tmp/eyeball/xschem.pre
```

Expect `RESULT: BYTE-IDENTICAL (920 netlists)` — 189 schematics x 5 backends x 2 binaries,
945 runs per arm, 0 errors. Anything less means a label that was working changed, and
step A's control rows should tell you which.

The suite arm:

```sh
SUITE_TIMEOUT=900 GUI_GATE=0 tests/headless/run_suites.sh --nogui \
  test_expandlabel_zero_neg_mult_0182 test_list_nets_null_token_0180 \
  test_hash_extra_node_warn_0165 test_tedax_extra_pinnumber_0179
```

---

## Also on the table while you are looking

**0184 is filed, reproduced, and NOT fixed** —
`doc/claude/issues/0184-expandlabel-idxsize-static-leaks-across-parses.md`. Different
mechanism, same file, survives 0182's fix:

```sh
cd src
./xschem --nogui --pipe -q --nolog --script /dev/stdin <<'EOF'
puts "A=[xschem expandlabel {a[0:20,]}]"
puts "B=[xschem expandlabel {b[0:15]}]"
puts "C=[xschem expandlabel {c[0:31]}]"
EOF
```

`realloc(): invalid next size`, glibc abort, exit 134. The static `idxsize` is reset only
on the success path of the `B_NAME '[' index ']'` productions, so a malformed bus label
leaves it large and the next bus label overflows its 8-int allocation. Fix is
`idxsize = INITIALIDXSIZE;` at each of the 7 allocation sites. It was raised at the 0182
review gate; the gate timed out unanswered, so it was left alone.
