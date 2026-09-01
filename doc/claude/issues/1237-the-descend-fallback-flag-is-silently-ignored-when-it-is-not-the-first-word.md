# 1237 — `xschem descend`'s `-fallback` flag is silently ignored when it is not the first word

**Status:** OPEN, LOW. Measured 2026-08-31 by item S7's adversary pass, re-measured
independently by the write-up agent before filing. **Introduced by item S7**, which
added the flag. No shipped caller trips it.

## Measured

```
xschem descend -fallback -inst x3      rc=1 sheet=comp3.sch     currsch=1 err=
xschem descend -inst x3 -fallback      rc=0 sheet=comp3_pex     currsch=1 err=load-failed
xschem descend --fallback              rc=0 sheet=...           currsch=0 err=no-selection
xschem descend -Fallback               rc=0 sheet=...           currsch=0 err=no-selection
```

Line 2: the flag written **after** `-inst` is swallowed without a word, and the caller
gets the stranding behaviour they were explicitly trying to avoid — one level down on a
blank page. Lines 3 and 4: a misspelled flag is parsed as an instance **number**
(`atoi("--fallback")` is 0), so the command reports `no-selection` and never mentions
that it did not understand its own argument.

## Cause

`src/scheduler.c`'s `descend` branch accepts the flag only in the leading position:

```c
if(argc > a && !strcmp(argv[a], "-fallback")) { fallback = 1; a++; }
```

Everything after that is read positionally off `a`. There is no arm that notices an
argument beginning with `-` that it does not recognise.

## Why it is filed rather than fixed

The doc comment above the branch says the flag is leading, all seven controls a person
presses pass it that way, and item S7's row E6 pins the exact spelling at every call
site. So nothing in the tree is affected today. It is filed because the failure is
**silent** and its consequence — stranding — is the very thing the flag exists to
prevent, so the next person to write a script against this verb pays for it.

## The repair

Reject an unrecognised leading `-` argument with a named error
(`descend_set_error(...)`) rather than running `atoi` over it, and either accept
`-fallback` in any position or say so when it arrives in one that is not honoured.
Cheap either way; the point is that it must not be silent.
