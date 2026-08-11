# 0378 — every Tcl-level `hi_descend` bail leaves `descend_error` unreadable

Status: **OPEN** — measured headless. In the tree today the token is *stale*; under the reverted
D5 fix it became *empty*, which is strictly worse. Filed so a re-attempt does not re-introduce it.
Area: `hi_descend`, `hi_descend_target_inst`, `hi_descend_do_body`, `hi_descend_no_view_msg`,
`hi_descend_refuse` in `src/xschem.tcl`; the channel itself is `xctx->descend_err`
(`src/actions.c`, D4 / issue 0251).
Tests: none. `test_descend_refusal_channel_0251.tcl` asserts the token after the **C** verb, never
after a Tcl-level bail.
Found: 2026-08-10 (D5 adversary pass CE-2/CE-2b, confirmed by the write-up agent).
Related: [0251](0251-a-refused-descend-has-no-return-channel.md) (the channel),
[0252](0252-non-subcircuit-symbols-refused-silently-after-the-chooser-offered-the-view.md),
[0253](0253-descend-semaphore-thresholds-disagree-and-a-zero-is-misread.md) (the stale-token
measurement), [0379](0379-get-sym-type-returns-empty-while-an-instance-is-selected.md).
Analysis: `doc/claude/code_analysis/descend_silent_refusal_census.md` (section "D5 attempt — reverted").

## The defect

`descend_error`'s contract is *"empty means the last descend succeeded"*, and that contract is
maintained only by `descend_clear_error()` at the top of the two **C** verbs. `hi_descend` refuses
in at least seven places that never reach C:

- unknown option, unexpected argument, bad `mode=`
- `hi_descend_target_inst` → no such instance / nothing selected
- `hi_descend_do_body` → no views found, no row picked (`hi_descend_no_view_msg`), bad `target=`

Every one of them returns `0` without touching the channel. **In the tree today** that leaves the
previous call's token readable (measured in the D5 baseline):

```
0253 sem=2 hi_descend    : '' err='busy'   <- STALE token from the sem=1 call
```

**Under the reverted D5 fix** it was worse: `hi_descend` gained an unconditional
`xschem set descend_error {}` on entry, so a refusal positively asserted success. Measured on the
D5 binary, at 0252's own headline case (a `type=resistor` whose default `.sch` is missing):

```
RAW  verb : ret=0 err='not-descendable'   <- C guard records the class
CHOOSER   : ret=0 err=''                  <- byte-identical to a success
SUCCESS   : ret=1 err=''
VERDICT: chooser-refusal token == success token ? 1
```

and on three more surfaces:

```
hi_descend inst=<nonexistent>  -> ret=0 err=''
hi_descend inst=R1 view=zzz    -> ret=0 err=''
hi_descend on an UNTYPED symbol-> ret=0 err=''   (raw verb records 'not-descendable')
```

That regression was made possible by D5's own 0252 chooser filter: with the schematic row removed,
the C guard that used to record `not-descendable:<type>` never runs at all, so nothing else fills
the channel in.

## The shape of the fix (written and measured during D5, reverted with the rest)

Make the stamp **opt-in**, defaulting to "leave the channel alone", and stamp only at bails that
refuse *before* the C verb is reached:

```tcl
proc hi_descend_refuse {msg {tok {}}} {
  if {$tok ne {}} { catch { xschem set descend_error $tok } }
  catch { xschem statusmsg -hold $msg }
  if {[info procs ciw_echo] ne {}} { ciw_echo $msg error }
  return 0
}
```

Opt-in is load-bearing: `hi_descend_finish` and `hier_traversal` call `hi_descend_refuse` **after**
the C verb ran, and the C side has already recorded the accurate reason there — an unconditional
stamp would overwrite `new-child` / `not-descendable:<type>` / `load-failed` with a generic token.

Measured with that in place (tokens `bad-option`, `bad-argument`, `bad-mode`, `no-instance`,
`no-views`, `bad-target`, `not-descendable:<ty>`, `no-view:<view>`):

```
CHOOSER   : ret=0 err='no-view:'      VERDICT: refusal token == success token ? 0
CE2b no-such-inst : ret=0 err='no-instance'
CE2b bad-view     : ret=0 err='not-descendable:resistor'
CE2b bad-mode     : ret=0 err='bad-mode'
CE2b bad-target   : ret=0 err='not-descendable:resistor'
CE2b bad-option   : ret=0 err='bad-option'
```

No committed suite asserts the channel is empty after a Tcl-level bail, so the stamp is safe with
respect to existing assertions (checked: the only `{}` assertions are `R20` on a freshly loaded
sheet, `inert_class` "B/reason cleared", and the post-push success rows).

## Landmines

- **`xschem set descend_error` does not exist in the tree** — it was added by the reverted D5 work
  (an `argv[2][0] < 'n'` block in `scheduler.c`). A re-attempt needs it, or an equivalent.
- **Opt-in, never unconditional** (see above), or the accurate C tokens are destroyed.
- **The `no-view:` token is the wrong class for an untyped symbol.** The message logic keys off
  `$ty ne {} && $ty ni {subcircuit primitive}`, so an untyped symbol falls to the `no-view:`
  branch while the raw verb records `not-descendable`. Widening the condition changes the message
  wording that row R27 pins — do both together or neither.
- **With [0379](0379-get-sym-type-returns-empty-while-an-instance-is-selected.md) unfixed the token
  is unstable anyway**: with a selection live the type lookup returns empty, so the same refusal
  reports `no-view:` instead of `not-descendable:resistor`. Fix 0379 first.
