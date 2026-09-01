# 0804 — `test_ase_core` NT14 asserts headless-only behaviour in both arms

Status: **FIXED on the test side** (arm-gated skip). Notify channel untouched.
Filed by: the 0689+0690+0698 crew, 2026-08-25, from its Implement leg.
Class: a **test** defect — a row whose premise is "there is no Tk" ran with Tk
present and scored correct behaviour as a failure.

## The measurement

`tests/headless/test_ase_core.tcl` NT14, whose own name and comment say
*headless*:

```tcl
check "NT14 0650 headless: no sink raises, and neither Tk-only sink is claimed" \
  [list $nt14_rc <statusbar claimed?> <popup claimed?>] {0 0 0}
```

On `:99`, 2026-08-25:

```
FAIL: NT14 0650 headless: no sink raises, and neither Tk-only sink is claimed
      -> {0 1 0} (exp {0 0 0}) : FAIL
```

`{0 1 0}` = no sink raised, the **statusbar** sink was claimed, the popup sink was
not. With a display present, a notice reaching the statusbar sink is the channel
doing its job. The row is measuring the right thing and grading it against the
wrong arm's expectation.

### Why nobody had seen it

Same reason as 0803: reachable only after issue 0698's design-window bind let the
suite run past check 104 under X. `full_audit.sh:163` pins the suite `--nogui`, so
CI has never evaluated NT14 with a display.

## The fix taken

Gated on `[info exists ::has_x]` — the same predicate `src/ase.tcl:868` and
`src/xinit.c:3135-3138` use for "a display is available". Under X the row prints

```
SKIPPED: NT14 headless-only sink safety (a display is present; see 0804)
```

and the headless arm is byte-unchanged.

**SKIPPED, not widened, and that choice is the point.** Widening the expectation
to accept `{0 1 0}` would assert something *unmeasured* about which sinks a notice
reaches under X — and that channel is mid-ruling (0674/0675/0677/0699/0800, where
a crew was refuted only days ago). A skip asserts nothing new, loses no headless
coverage, and leaves the X-arm question open for whoever takes that ruling.

## Follow-up for the notify crew (NOT claimed here)

There is no X-arm counterpart to NT14 — no row asserts which sinks a notice
reaches WITH a display. That gap is worth a row once the channel's ruling lands;
writing it now would pre-empt the ruling.

## Acceptance

1. Headless: the row runs and passes exactly as before. **Met**: `RESULT: ALL PASS
   (173 checks)`.
2. Under X: the suite reaches its end with no false red. **Met**: `RESULT: ALL PASS
   (172 checks)`, exit 0, one printed SKIPPED line naming this issue.
3. `src/` is untouched; no notify-channel behaviour is asserted either way.
