# 0947 — an entry added before its setting existed still says the setting is unknown after you set it

**Status: OPEN.** Filed by the S2a write-up agent, who measured it first-hand on
the repaired tree. **It is a wording defect this repair introduced**, in an arm
that was already refusing before the repair for a different stated reason. The
refusal itself is not new and is not the complaint; the sentence being **false at
the moment it is shown** is.

## What the user does

They add a simulator the documented portable way, `$::PDK_ROOT/bin/ngspice`,
in a session where that setting is not set yet — a mistyped variable name, or a
PDK file they have not sourced. The registry **deliberately keeps** such an
entry and reports it rather than throwing it away (one of issue 0931's recorded
decisions), so the entry stays on the list. Then they set the setting.

## What they are told, measured

```
C1 is the setting set       = 0
C3 entry                    = name late path {$::WU_LATE/bin/ngspice} ... varok 0 ok 0
C5 NOW the setting is set: $::WU_LATE = /tmp/wu0946/plain
C6 and it names a runnable file = 1
C7 problem, setting now set = The location given for the simulator named late mentions a
                              setting this session does not know about, so it cannot be
                              turned into a real file name: $::WU_LATE/bin/ngspice
C8 sim_status ok            = 0
```

The session knows that setting perfectly well by line C7. The sentence is not
merely unhelpful, it is **untrue**, and it sends the user to fix something that
is already fixed.

## What the same instant said before the repair

The old validator, asked at the same moment on the same binary:

```
D1 old validator's problem  = There is no file at $::WU_LATE/bin/ngspice, which you
                              registered as the simulator named late. Check that you typed
                              the location correctly, or point this entry at a different file.
```

**Both refuse** (`ok` 0 either way — this is not an over-refusal, and it is not a
regression in behaviour), and **both sentences are wrong**. The old one points
the user at a disk for a location that plainly contains a setting, which is the
exact contradiction rows R5 and R7 exist to prevent (issue 0933, half one). The
new one asserts something the session can disprove. The repair traded one wrong
sentence for another wrong sentence in this arm, and nobody wrote that down —
which is why this file exists.

## Why

The answer about the setting is now worked out **once**, at registration, and
recorded on the entry as `varok`. That was the whole point of the 0938 repair
(the substitution is not idempotent, so it must not be re-run), and for the arm
0938 was about it is exactly right — whether a *result* still contains a dollar
sign never changes.

But `varok 0` is recorded for a **different** reason: the setting genuinely was
not readable *then*. That fact **can** change under a live entry, and unlike the
filesystem facts — which are deliberately re-checked on every call — this one is
frozen.

## There IS a way out, and no sentence mentions it

Measured: adding the same entry again, with the setting now set, recovers it
completely.

```
E3 adding it AGAIN returns  = 1
E4 entry now                = name late path /tmp/wu0946/plain/bin/ngspice ... varok 1 ok 1
E5 problem now              = ''
E6 sim_status ok            = 1  resolved = /tmp/wu0946/plain/bin/ngspice
```

So the user is one `Edit` → `OK` away from a working entry and is told nothing
about it. Under the **plain-English ruling** the sentence owes them that second
half.

## Options

1. **Say what to do.** Keep the frozen verdict, and give this arm its own
   sentence: *"The simulator named late was added when this session had no
   setting called `$::WU_LATE`, so its location was never turned into a file
   name. Add it again now, and it will be."* One new mint, no new state, no
   change to the guard the 0938 repair turned on. **Recommended** — it is
   truthful about both the cause and the cure, and it costs nothing the repair
   was protecting.
2. **Re-derive `varok` when it is 0.** A recorded 1 can never go false (the
   result is a fixed string), so only the negative verdict is worth re-asking,
   and re-asking it is safe precisely because the stored path in that arm is the
   *unexpanded literal* — the value registration never transformed. Makes the
   entry come good on its own. It re-introduces a second substitution on one
   path, which is what row R18 pins against, so it needs R18 re-authored with
   care and a clear statement of why this one is not 0938.
3. **Keep what the user typed alongside what it resolved to** — 0933's storage
   half. Removes the question rather than answering it, and fixes 0946 as well.
   Largest.

## Acceptance, when it is fixed

A row in `tests/headless/test_ase_simreg_0931.tcl`: register the portable form
with the setting unset, then set the setting, then read the list's own reason
for that entry. Under option 1 it must name the entry's own way out and must not
claim the session does not know the setting; under option 2 the entry must
simply come good and the run must start. Either way the row must also assert
that a setting nobody ever sets still gets today's sentence unchanged — that arm
is what `varok` was recorded for.

## Not to be confused with

* **0938** — the *result* of a successful substitution carrying a literal dollar
  sign. Fixed; the recording of `varok` is what fixed it.
* **0946** — a dollar in a *folder name* at a location where no file is there.
  Same wrong sentence, different cause.
* **0933** half two — the storage half both of those and this one all lean on.
