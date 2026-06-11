# Issue 0004 — the TCP command server has no authentication and binds all interfaces

**Opened:** 2026-06-11
**Status:** OPEN — security gap documented; mitigation options listed, none
applied. Pre-existing upstream behavior, not introduced by the
action-logging work.
**Affects:** any xschem started with `--tcp_port <N>` or with
`xschem_listen_port` set in an xschemrc
**Severity:** high WHEN the feature is enabled on a reachable interface
(remote arbitrary code execution); zero when the feature is unused (off by
default)
**Related:** issue 0003 (logging holes — same code path, `xschem_getdata`).

## Summary

The `--tcp_port` command server (see issue 0003 Hole B for what it is and a
working demo) evaluates whatever a client sends as **Tcl at global scope, with
no authentication, no transport security, and — by Tcl's default — a listener
bound to every network interface.** Anyone who can open a socket to the port
can run arbitrary Tcl in the xschem process, which means arbitrary code as the
user who launched xschem: file read/write/delete, `exec` of external programs,
`open |…` pipelines — the full interpreter.

This is a real, useful automation feature; the point of this issue is that its
trust model is "the network is friendly," which must be a conscious choice by
whoever turns it on, not a surprise.

## The exposure, concretely

The listener is created in `setup_tcp_xschem` (`src/xschem.tcl` ~11070):

```tcl
socket -server xschem_server $xschem_listen_port
```

Three properties of that one line are the whole issue:

1. **No bind address** → Tcl's `socket -server` listens on **all interfaces
   (0.0.0.0)** by default, not just loopback. On a machine with a routable or
   LAN IP, the port is reachable from other hosts.
2. **No accept-time check.** `xschem_server` (the accept callback, ~2510)
   stores the peer addr/port and wires up `xschem_getdata`; it never inspects
   or rejects the peer. Every connection is trusted.
3. **Full-interpreter eval.** `xschem_getdata` does
   `uplevel #0 [list catch $line tclcmd_puts]` — global scope, every command,
   no allow-list. `set`, `exec`, `open`, `file delete`, `source` all run.

Net: `--tcp_port 19899` on a multi-homed or internet-exposed host is an
unauthenticated remote-code-execution endpoint.

## What is NOT wrong

- **Off by default.** `tcp_port` is 0 unless the user passes `--tcp_port` or
  sets `xschem_listen_port`. An xschem that never enables it has zero exposure.
- **Not a regression.** This predates all the action-logging / action-registry
  work; it is inherent to the existing feature.
- The companion `bespice_listen_port` socket has the same shape and the same
  caveat, for the bespice waveform-viewer channel.

## Mitigation options (in rough order of effort / behavior change)

1. **Bind to loopback by default** — the single highest-value change:
   `socket -server xschem_server -myaddr 127.0.0.1 $port`. Kills remote
   reachability; local automation (the overwhelmingly common case) is
   unaffected. Make the all-interfaces bind an explicit opt-in
   (`--tcp_listen_all` or an rc var) for the rare deliberate remote setup.
2. **Document the risk loudly** — `xschem.help` and the man page currently say
   only "Listen to specified tcp port for client connections." Add: runs
   arbitrary code, no auth, localhost-only unless you know what you are doing.
   Cheapest possible step; do it regardless of (1).
3. **Shared-secret handshake** — require a token (from a file / env var /
   cmdline) as the first line before any eval. Modest Tcl in
   `xschem_getdata`; protects even a deliberately non-loopback bind.
4. **Per-connection peer allow-list** — reject in the accept callback unless
   the peer addr is in an allowed set (default `127.0.0.1`). Composes with (1).
5. **(Heavy, probably out of scope)** TLS via Tcl `tls`, or a restricted-
   interpreter (`interp create -safe`) eval so remote clients cannot reach
   `exec`/`file`/`open`. The safe-interp route also blunts the RCE even on an
   open bind, at the cost of breaking automation that legitimately needs those
   commands.

**Recommended minimum:** (1) + (2) — loopback-by-default plus an honest help
string. Both are small and neither breaks the common local-automation use.

## Open decisions for the implementer

- Is there any existing user/workflow that relies on the all-interfaces bind?
  If so, (1) needs the opt-out flag landed in the same change.
- Should the same treatment apply to `bespice_listen_port`? (Likely yes, for
  consistency.)
- Coordinate with issue 0003: if TCP commands start being logged, the log of a
  server session becomes a record of remote-driven activity — useful for audit,
  but note it may capture secrets passed as command arguments.

## Acceptance

- Default `--tcp_port N` run is reachable on `127.0.0.1:N` but NOT on the host's
  LAN/routable address (probe both).
- The opt-in flag (if added) restores all-interfaces binding.
- `xschem.help` / man page carry the risk note.
