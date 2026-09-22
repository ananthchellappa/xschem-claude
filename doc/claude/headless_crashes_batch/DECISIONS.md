# Decisions — headless crashes batch

# D1 — Item A first, because it is what makes the rest measurable (driver)

`xserver_ok()` closes the display and leaves the global pointing at freed memory. While
that is true, a missed guard reads whatever survives in the freed block — measured on 1483
as `XMaxRequestSize=4` against a true 65535 — so the defect class is silent wherever a
`DISPLAY` happens to be set, which is every arm anyone routinely runs. Nulling the pointer
converts every remaining missed guard from a plausible wrong answer into a fault.

That is deliberately a fault-finding change: it will surface sites nobody has found. Those
are the point, not collateral.
