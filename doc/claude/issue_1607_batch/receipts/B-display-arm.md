# Receipt B — item 4: the display arm was NOT clean, only lucky

Crew `measure:ps-display-arm`, dispatched from `cff55068`. `make -C src` rebuilt nothing,
before and after; binary md5 `c7ca057d871ab29a82cdd380ec4753a1` both times.

## The patched binary is clean on all four combinations

`xschem_library/examples/LCC_instances.sch`, valgrind 3.26.0, `--error-limit=no
--num-callers=25`:

| verb | arm | valgrind | `RGB` lines | out of gamut |
|---|---|---|---|---|
| `print ps` | `DISPLAY` unset | **0 errors / 0 contexts** | 301 | 0 |
| `hier_psprint` | `DISPLAY` unset | **0 errors / 0 contexts** | 493 | 0 |
| `print ps` | `DISPLAY=:99` | **0 errors / 0 contexts** | 301 | 0 |
| `hier_psprint` | `DISPLAY=:99` | **0 errors / 0 contexts** | 493 | 0 |

`grep -cE "Invalid (read|write)"` = 0 in all four; `grep -cE
"(set_ps_colors|ps_draw_symbol|create_ps|psprint)"` = 0, so there is no psprint frame to
attribute anything to. Cross-checked against a second patched build made in the revert
clone (`xs_pat`), same arm, same result — so the clean figure is not an artefact of the
in-tree build.

## Item 4's suspicion was RIGHT, and the display arm was the worse of the two

The clone reverted **exactly one line** in `set_ps_colors()` (`git diff --stat` = 1 file,
1 insertion, 1 deletion; the 1353 comment block untouched), built from scratch with
`config.h` byte-identical to the in-tree one, and both binaries were kept side by side in
the clone's `src/` (`xs_rev`, `xs_pat`). N = 9 runs per cell, all on `DISPLAY=:99`, both
binaries reading the **clone's** copy of the sheet so the drawn mtime is identical.

| verb | binary | `RGB` lines | out of gamut | distinct md5s / 9 |
|---|---|---|---|---|
| `print ps` | reverted | 445 | **144, in 9 of 9 runs** | **9 / 9** |
| `print ps` | patched | 301 | 0 in 9 of 9 | **1 / 9** |
| `hier_psprint` | reverted | 726 | 233, 233, 233, 89, 0, 0, 233, 233, 233 | **8 / 9** |
| `hier_psprint` | patched | 493 | 0 in 9 of 9 | **1 / 9** |

Valgrind on the reverted binary **with a display**: `print ps` → 432 errors from 3 contexts;
`hier_psprint` → 699 from 3. Reads at `+0`/`+4`/`+8` past a 264-byte block (22 layers ×
`sizeof(Ps_color)`), stack `set_ps_colors ← ps_draw_symbol.constprop.0 ← create_ps ←
ps_draw ← xschem_cmds_p ← xschem ← … ← main`. 432 / 3 = **144**, matching the 144
out-of-gamut lines exactly; 699 / 3 = **233**, matching hier's.

**The display arm over-reads exactly as much as headless** (same 432 and 699 counts) and is
**more** corrupted and **less** deterministic: 9 md5s in 9 runs with garbage in every run,
versus headless's 3 md5s in 9 with garbage in only 4. The garbage blue component across the
nine `:99` runs, on a 0..1 scale:

```
1.29687e+07  3.54792e+06  1.2709e+07  3.95584e+06  6.18003e+06
1.47638e+07  1.94254e+06  1.14533e+07  1.19623e+07
```

A different heap-pointer-magnitude value every run — which is why nine runs give nine md5s.

**So issue 1607's item 4 is answered and its wording was right**: the two agreeing `:160`
runs proved determinism, not correctness. With a display this path was reading garbage the
whole time; the earlier pair simply landed on the same value twice.

⚠ The original figure was taken on `:160`, which does not exist on this machine. This is
`:99`. `:160` was not reproduced.

## The fix changes nothing that is rendered — measured on the display arm

`gs -q -dNOPAUSE -dBATCH -dSAFER -r100`, each of the 9 reverted runs against the patched
output, page by page with `cmp -s`:

| verb | pages compared | differing |
|---|---|---|
| `print ps` | 9 (9 run-pairs × 1 page) | **0** |
| `hier_psprint` | 27 (9 × 3 pages) | **0** |

Repeated with `-sDEVICE=ppmraw` because greyscale can alias two hues: same **36 and 0**.
`gs` exit 0 on all 20 rasterisations; pages are not blank (965663 bytes each, 41–42 distinct
byte values).

**Why it comes out identical.** The textual diff of a reverted export against the patched
one is **144 lines present only in the reverted file, all 144 of them ` RGB` lines**, and
zero lines present only in the patched file, with no other difference anywhere. The
suppressed emissions are dead colour sets — no drawing operator moved. That is the
`psprint.c` comment's claim, *"every drawing site sets its own colour first"*, now measured
on the display arm as well as on the 313-of-314 sheets it already cited. **Decision E2
stands.**

## Two things worth keeping for the next crew

* **`git clone --local` fails here** — *"failed to create link … Invalid cross-device
  link"*, because the scratchpad is on a different filesystem from the repo.
  `git clone --local --no-hardlinks` works.
* **A built binary must be run from the clone's `src/`.** Elsewhere `XSCHEM_SHAREDIR` falls
  back to `/usr/local/share/xschem` and startup dies with *"Tcl_AppInit() err 4: cannot find
  /usr/local/share/xschem/xschem.tcl"* — and **with a display it HANGS on the error popup
  rather than failing**, which cost this crew one 1200 s timeout.

## Incidental, and it lands on item 3

The export **draws the schematic file's filesystem mtime as text** —
`2026-09-01  09:56:17` from the in-tree checkout versus `2026-09-24  15:37:19` from the
fresh clone, the only difference between two otherwise identical patched outputs. **A
byte-exact committed golden for this path would redden on every fresh clone.** Receipt C
traces it to `@time_last_modified` in `xschem_library/devices/title.sym`.
