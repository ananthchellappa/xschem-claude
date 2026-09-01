# 1223 - a deleted re-read makes the warning quote a value the designer never typed

**Filed by** item S6b's sabotage pass, 2026-08-31. **Severity** HIGH -- RULING D5-1 on
the sentence a designer reads. **Area** `warn_unused_instance_attr()`, src/token.c.

## What is wrong

XSCHEM's property reader hands every answer back in **one shared buffer**
(`src/token.c`, `static char *result`). The new check "is this value already the
symbol's own default?" asks that reader a question of its own, which overwrites the
buffer the designer's own value is sitting in. So the value has to be read again
before the warning is built, and it is:

```c
      val = get_tok_value(prop, p, 0);
```

The implement agent recorded that this line cost them an hour. **No test row sees it.**

## Measured

Delete that one line and rebuild: `test_auto_specialize_1201` **77 checks all pass**,
`test_unused_attr_0970` 67, `test_op_annot` 484. Every suite green.

What the designer is told changes on three of the four sentences. The designer typed a
**single space**, and XSCHEM says:

> instance xS (a aswv) sets modelp=**pfet_01v8**, ... but the value you typed **has no
> letters or digits in it**

Both halves are wrong and they contradict each other. `pfet_01v8` is a value the
designer never entered -- it is the symbol template's default, quoted back at them as
though they had typed it -- and it plainly does have letters and digits in it. The
same happens to the tab and the line-break cases.

**RULING D5-1**: a value that was not read for the thing it is displayed next to is
the defect. The advice clause is also mis-chosen, because the fault description is
worked out from the same clobbered pointer.

## Why no row sees it

Every row that reads these sentences tests for the fixed clause `one word` (AS-SHAPE's
`said`), or for the setting **name** (AS55, AS65 assert `modelp`). No row anywhere
asserts the printed **value** for a setting whose cell body reads it. AS23's
`x2 (a aspass) sets modelp=pfet_01v8_lvt` is a different sentence, from the note, not
from this function. In `test_unused_attr_0970` every case has `body_reads=0`, so C's
short-circuit means the clobbering call never runs there.

## The repair

Add one element to AS59 (or to `as_shape`) asserting the quoted value is the one the
designer typed. For the space fixture that is `modelp= `; for punctuation, `modelp=---`.

Better still, follow the shape the code already uses elsewhere: have
`ua_value_is_template_default()` hand back its answer without disturbing the caller's
pointer, so the re-read is not needed and cannot be deleted.

---

## CLOSED 2026-08-31 by item S6b's REPAIR pass

New row **AS82** asserts the VALUE the sentence quotes, for a setting the cell's
own drawing reads: the punctuation copy's line must contain `sets modelp=---,`
and must NOT contain `sets modelp=pfet_01v8,` (the symbol template's value), and
the at-sign copy's line must contain `sets modelp=pfet@01v8_lvt,`.

Measured by deleting the re-read and rebuilding: AS82 and AS83 both go red. The
row's own reason is written into its title, because the line it guards looks
like a redundant second read to anybody who has not met the shared buffer.

The alternative the "repair" section above prefers -- have
`ua_value_is_template_default()` not disturb the caller's pointer -- is not what
was done: the function already copies the caller's value before it looks the
template up, and it is the TEMPLATE read that clobbers the buffer, which no
discipline inside that function can undo for its caller. A row is the honest
guard here.
