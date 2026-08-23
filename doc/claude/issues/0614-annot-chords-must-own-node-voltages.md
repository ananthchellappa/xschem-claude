# 0614 — the three OP chords must own the node voltages too (`Ctrl-6` off-ramp, `6` vs `Alt-6`)

STATUS: **OPEN — RULED by the user 2026-08-22.** Supersedes the open decision in
[0613](0613-ctrl-6-does-not-clear-node-voltages-so-everything-off-is-false.md), which measured the defect and listed
three options. The user picked the first: **the chords take authority over the
node voltages.** Related: 0457 (the mask's menu controls), 0615 (colour), S7/S8.

---

## The ruling, verbatim

> "Fix Ctrl-6 - yes - must clear node voltage display and the Alt-6 and 6 doing
> the same thing issue. 6 is for OP info."

So the contract `src/cadence_style_rc:283-285` already documents becomes true:

| chord | mask | on screen |
|---|---|---|
| `6` | 1 | device OP blocks **only** — node voltages OFF |
| `Alt-6` | 3 | device OP blocks **+** node voltages |
| `Ctrl-6` | 0 | **nothing** — blocks gone AND node voltages gone |

Note `6` gets *stricter*, not just `Ctrl-6`. Today `6` shows voltages because
nothing suppresses them; under the ruling `6` must actively turn them off, or
`Alt-6` still cannot be told apart from it.

## Why it is broken today (measured, 0613)

`annot_show` gates `hide=op` / `hide=voltage` text records through
`text_hidden()` (`src/actions.c`, `src/xschem.h:397-401`). The node voltages and
branch currents come from a **different** mechanism — XSCHEM's native OP
back-annotation, symbol texts carrying `@spice_get_voltage` /
`@spice_get_current*` tokens resolved in `token.c:4821/4912/4989` — and
**no shipped symbol carries `hide=voltage`**, so bit1 has nothing to gate.

Measured on `bandgap_opamp` (13 FETs, 15.8 MB tran raw, cursor2 at 20 µs):

| mask | chord | render bytes | on screen |
|---|---|---|---|
| 1 | `6` | 169897 | blocks **+** voltages |
| 3 | `Alt-6` | 169897 | **byte-identical to mask 1** |
| 0 | `Ctrl-6` | 114394 | blocks gone, **voltages remain** |

Surviving `Ctrl-6`: `1.8` VCC, `0.8696` ADJ, `1.461` SP, `0.5328` G1, `0.4967`
G2, `1.185` DIFFOUT, and branch currents `4.854u 2.43u 2.424u 12.83u 7.25u
905.8p 413.8n`.

The user hit the same thing again unprompted in the second session:
"node voltages are already displayed without asking for them."

## Two ways to give bit1 something to gate — and the recommended one

**Option A — tag the shipped symbols.** Add `hide=voltage` to the voltage/current
texts in `xschem_library/devices/*.sym`. Rejected as the primary mechanism: it
edits shipped libraries, it is a per-symbol opt-in a third-party or user PDK
symbol will not have, and every such symbol then permanently escapes the switch.

**Option B — classify by content (RECOMMENDED).** Treat a text whose *unresolved*
token is `@spice_get_voltage`, `@spice_get_voltage(...)`, `@spice_get_current`,
`@spice_get_current<n>` or `@spice_get_current_<param>(...)` as class VOLTAGE at
the visibility test, exactly as if it carried `hide=voltage`. One predicate,
covers every symbol in every library including ones not yet written, no library
churn. Decision ladder **L2**: smallest blast radius, least surprising.

Whichever is implemented, keep the explicit `hide=voltage` token working (I7) —
Option B *adds* an implicit class, it does not replace the explicit one.

## Landmines

- **Invariant I7.** A user with no raw loaded and no annotation must see these
  symbols exactly as before. `annot_show` starts at 0, so a content-based class
  would blank `@spice_get_voltage` texts that today render as the literal token
  or as blank when unresolved — **check what they render as with no raw loaded
  and preserve it.** This is the one way Option B can regress a non-annotating user.
- The nine copy-pasted visibility tests are already unified behind `text_hidden()`
  (S7): `draw.c:872,1135,10270,10650` `svgdraw.c:927,1330` `psprint.c:1209,1702`
  `select.c:709`. Do not add a tenth test elsewhere — extend the predicate.
- `select.c:709` means the class also decides **selectability**. Turning voltages
  off must not make a text unselectable in a way that strands it.
- `Ctrl-6` must keep ending in `break` (it displaces `Ctrl+<digit>` = select layer,
  `callback.c:7272`).

## Acceptance

- With a raw loaded: `6` shows blocks and **no** node voltages; `Alt-6` shows
  both; `Ctrl-6` shows neither. Three renders, three distinct byte counts.
- The 0457(b) View-menu pair (`::annot_show_op` / `::annot_show_voltage`) drives
  the same three states — unticking "node voltages" hides them.
- With **no** raw loaded and `annot_show` 0, every existing schematic renders
  byte-identically to before the change (I7 regression guard).
