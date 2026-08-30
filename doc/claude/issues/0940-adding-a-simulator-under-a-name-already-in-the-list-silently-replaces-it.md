# 0940 — adding a simulator under a name already in the list silently replaces it

**Status: OPEN — examined during the 0938/0941 repair (item S2a) and
deliberately left filed.** The S2a brief asked whether this shares the
one-string-recorder root that 0941 has. **Measured: it does not.** Removing an
in-force startup-file entry says two true sentences and the recorder kept only
the last of them — that is 0941, and accumulating fixed it. Re-registering onto
a name already taken says **zero** sentences and leaves the recorder **empty**:

```
N2 second register returns   = 1
N4 entry after               = name ng path ... args {} backend {} origin session ok 1
N5 sentences the CIW got     = 0
N6 sim_said                  = ''
```

Nothing is overwritten in the recorder because nothing is ever put in it. There
is no collision guard and no minted sentence at all, so fixing this needs a NEW
sentence and the user's refuse-vs-confirm ruling below — neither of which the
0938/0941 repair could carry.

**The original filing, unchanged.** Measured on the `Setup > Simulators…` dialog
that issue 0937 shipped, and reproduced first-hand at the registry level by the write-up agent.

**This is the same defect row S9 exists to prevent, reachable through the other
button.** `ase::ui::simdlg_ok` carries an entry's extra arguments and its backend
through an **Edit** untouched — that is what S9 pins. The **Add** path runs the
same code with empty values and has no guard and no row.

## What the user does

Press `Add…`, type a name that is **already** in the list, give it a different
program, press OK.

## What happens

The existing entry is replaced, its extra arguments and its backend are wiped,
and the dialog reports **success**:

```
F2 before: args='-b --define x' backend='ngspice'
F2 after : args='' backend='' path=/tmp/wu0937/bin/ngb
F2 entries now = ng  (an Add added nothing; it replaced)
F2 register returned 1 and said: ''
```

`ase::sim_register` does a bare `dict set simulators $name [dict create …]` with
no already-registered check, and says nothing. The status line then reads *"The
simulator named ng is the one that will be used…"*, so every visible signal is
green while the user's settings are gone.

Combined with **0939**, `Add…` onto a name a startup configuration file declared
does the same takeover.

## Why this matters here specifically

The item brief names this failure mode by name: *"validation feedback shown IN
the dialog, not only in the CIW, because silence is this area's failure mode."*
An Add that overwrites is the one gesture in this dialog that destroys something,
and it is the one gesture that says nothing at all.

## What is still open

The fix is a decision, not just code. Either **refuse** the Add and say the name
is taken (offer Edit instead), or **confirm** it and say what will be lost. The
first is more consistent with the dialog's read-only Name field in Edit mode —
a rename is already Remove-then-Add — and does not need a new sentence about
discarded settings. Both need a new minted sentence under **D5-4**.

## Acceptance rows this needs

An Add onto an existing name must either leave the entry untouched and explain,
or preserve `-args`/`-backend` — asserted through the real `Add…` button and the
real OK button, the way S9 drives the Edit path.
