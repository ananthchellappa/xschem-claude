# Decisions — stranger reds batch

# D1 — The audit's remaining findings are one batch, dispatched one item at a time (driver)

Issues 1483-1487 and 1489 were filed rather than fixed when the outsider-fixes batch
closed. They share one subject: what someone who is not this developer meets on first
contact with the branch we publish. They are dispatched in the order of PLAN.md's table,
one crew at a time, each returning a receipt.

# D2 — Rounds are capped at three, and the cap is part of the brief (driver)

The previous batch ran eleven implement-and-refute rounds on one item; the last three
shipped nothing. Each item here gets one implement round, one adversarial verify and at
most one fix round, with the acceptance criteria written before the first round rather
than after the fifth.
