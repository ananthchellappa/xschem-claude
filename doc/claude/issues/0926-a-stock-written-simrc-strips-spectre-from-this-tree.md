# 0926 — a stock-written simrc would strip Spectre from this tree's simulator menus

**Status:** **OPEN, LATENT, NOT FIXED.** Found 2026-08-29 by the adversarial
review of the [0924](0924-file-open-recent-empties-whenever-a-stock-xschem-touches-the-same-conf.md)
fix. Same shared-`~/.xschem` class as 0924, different file.

**Latent right now:** `~/.xschem/simrc` does not exist on this machine. It is
created the first time anyone presses **Save** in the simulation-configuration
dialog — from *either* build.

---

## 1. What the user would see

The **Simulation** configuration lists the simulators. On this tree that list
includes **Spectre**. After a stock xschem writes `~/.xschem/simrc`, Spectre is
**gone** from this tree's list too, and stays gone until the file is deleted or
hand-edited. No message.

## 2. The measurement

The simulator list is persisted, not derived. Ours:

```
src/xschem.tcl:2998   set sim(tool_list) {spice spicewave spectre verilog verilogwave vhdl vhdlwave}
```

Stock 3.4.6's, and it writes that variable into `simrc`:

```
/usr/local/share/xschem/xschem.tcl:1473   set sim(tool_list) {spice spicewave verilog verilogwave vhdl vhdlwave}
/usr/local/share/xschem/xschem.tcl:1091   puts $fd "set sim(tool_list) {$sim(tool_list)}"
```

`spectre` is absent from the stock list. Our loader (`src/xschem.tcl:2982-2984`)
sources `simrc` when present and only falls back to the default at `:2998` when
it is **not** — so a stock-written file wins, silently, and everything keyed off
`$sim(tool_list)` (`:2487`, `:2975`, `:3124`, `:3135`, `:3167`) narrows with it.

## 3. Why it is not the same fix as 0924

0924 was two spellings of one variable. This is **one spelling, two different
values** — nothing about naming or scope. The conf faithfully records what the
older program knew, and the older program did not know about Spectre.

## 4. Candidate fixes, none ruled

1. **Merge rather than replace** — union the sourced `tool_list` with the
   built-in default, so a tool this build supports is never removed by a conf
   written elsewhere. Cheapest, and matches how the list is actually used.
2. **Version-stamp the conf** — write a `sim(conf_version)` and ignore a
   `tool_list` from a file that does not carry the current one.
3. **Leave it** — accept that a shared `~/.xschem` between two xschem
   generations degrades to the older one's feature set, and document it.

Option 1 has a real cost worth stating: a user who *deliberately* removed a
simulator from the list would find it back. That is a decision for the user, not
for this file.

## 5. Scope

Only `sim(tool_list)` was measured. `save_sim_defaults`
(`src/xschem.tcl:3142`) writes the whole `sim()` array, so per-tool command
strings are also carried across builds and may differ in the same way. Not
measured; noted so the eventual fix looks at the array, not one element.
