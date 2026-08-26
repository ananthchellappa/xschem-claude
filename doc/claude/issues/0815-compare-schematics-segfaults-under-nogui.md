# 0815 — `xschem compare_schematics <path>` SEGFAULTS under `--nogui`

STATUS: **OPEN — filed by the 0812 implement agent, 2026-08-25. Measured, not fixed.**
FOUND IN: `src/scheduler.c`, the `compare_schematics` branch (~:2945-2960 at HEAD; the line numbers below predate the
0812 edits; the branch is unchanged by them).
NOT INJECTION, and NOT in issue 0812's blast radius — found while probing for it.

## Measured (on the 0812 attempt binary AND again at HEAD after that attempt was reverted — so it is neither caused nor fixed by 0812)

```sh
cd <scratch>
printf 'catch {xschem compare_schematics /home/analog/dev/xschem-claude/xschem_library/examples/cmos_example.sch} r\nputs "RET=$r"\n' > cmp.tcl
DISPLAY=:99 ./src/xschem --nogui --pipe -q --nolog --script cmp.tcl
```

```
Segmentation fault (core dumped)     exit = 139
```

The last output is `Sourcing .../xschemrc init file`; `RET=` is never printed, so the
crash is inside the branch, not after it.

Reproduces:
* with an **existing** schematic path and with a **missing** one,
* with a schematic loaded and with none,
* on the pre-0812 binary (measured independently by the 0812 measure agent) and on the
  post-0812 binary (measured here). **0812 neither caused nor fixed it.**

## Suspected class

Almost certainly the recorded "**secondary `Xschem_ctx` needs cairo**" class: the compare
path builds a second context to load the other schematic into, and under `--nogui` the
window cairo handles it borrows do not exist. Not investigated further — that is the next
owner's first thing to check, not a conclusion.

## Why it was not fixed here

Issue 0812's scope fence is the raw-file path resolver. A crash fix in a security commit
is the wrong shape, and the two changes share no code.
