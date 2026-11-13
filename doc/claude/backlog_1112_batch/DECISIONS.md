# Backlog batch 2026-11-12 — DECISIONS

D1. Order A(1), B(3), C(4), D(2) — the user's, 2026-11-12.
D2. Crews never commit; the driver commits as Ananth after a verifier crew and a T1 gate.
D3. T1 gates run off :99 (XSCHEM_DEVDISPLAY_DIR=<missing dir>, private Xvfb from :100) until
    stage B lands a first-class way; crews use their own Xvfb in 260-299. Since stage B:
    `T1_DISPLAY=private` is that way, and gates use it.
D4. Stage A: a bare `setseed N` in the bench's control text does NOT make the default seed
    step aside (diverges from private 7843e17e7). Crew A measured that the default line does not
    touch the draws setseed seeds, and stepping aside would make the tt_mm draw unrepeatable on
    stock ngspice 45.2 — the user's ruling is "tt_mm should give same result each time".
D5. Stage A includes the options-preview follow-up (crew A's item 5): the preview must show
    what the deck carries (row RS4's promise), so it is not deferred.
D6. Stage A residuals accepted (A-verify.md Re-verify): four seed spellings ngspice honours
    are not recognised (`;` inside a quoted string, comment/blank line before a `+` line,
    `+ ;`); each only adds ngspice's "Multiple seed" warning while the bench's own draw
    repeats. Sabotage Y1 (cut at any `$`) survives the suite; warning-only. Not pursued.
D7. Stage C waits on the user's yes/no for xschem-private's focus-loss clamp patch, which
    touches the same devlim code; take it first if yes.
