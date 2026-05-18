# kiosk-ws-relay

Tiny localhost-only WebSocket relay for App 3 (synced 3-screen kiosk).

## What it does

Listens on `127.0.0.1:8743/ws`. Any message received from a connected
client is rebroadcast to all OTHER connected clients (sender does not
receive its own echo). The last message is cached and replayed to new
connections so late-joining satellites can re-sync without waiting for
the center to publish the next state.

That's it. No persistence, no auth, no TLS — runs only on `127.0.0.1`
so the kiosk Mac never opens a port to the network.

## Why we need it

The kiosk apps run from `file://` URLs. Three separate Chrome `--kiosk`
processes (one per display) can't communicate via `postMessage`,
`BroadcastChannel`, or `localStorage` events because each one has an
independent profile / origin. WebSocket is the simplest local IPC
mechanism that works without granting Chrome cross-origin file access
or merging the three windows into a single Chrome process.

This is an explicit carve-out from the "no server requirement"
constraint in `CLAUDE.md` — see that file's hard-constraints section
for the rationale and what it forbids elsewhere.

## Building

Requires Go 1.21+ (developer machine only — the kiosk Mac runs a
prebuilt binary checked into `../bin/`).

```bash
cd kiosk/ws-relay
go mod download                # one-time
./build.sh                     # builds both kiosk/bin/kiosk-ws-relay-{arm64,x86_64}
```

The prebuilt binaries are committed to git so the kiosk Mac doesn't
need a Go toolchain. Re-run `./build.sh` whenever `main.go` or
`go.sum` change, and commit the resulting binaries.

## Wire protocol

Messages are JSON strings sent as text frames. The relay does not
parse them — it forwards bytes verbatim. App 3 uses a single message
shape:

```json
{
  "type": "state",
  "index": 2,
  "paused": false,
  "ts": 1715974800000
}
```

`ts` is `Date.now()` from the sender; satellites drop messages with
`ts <= lastAppliedTs` to guard against any future re-ordering.

## Port choice

`8743` was picked because:

- High enough to not need root
- Not in any common services list (IANA, Nmap top-1000)
- Easy to remember (`8743` → "VKSK" on a phone keypad, "Victron KioSK")

If you change the port, also update:
- `kiosk/launch-app3-ws.sh` (the `-addr` flag the launcher passes)
- `app3-multi-screen/config.js` (the `wsUrl` field — the kiosk JS
  reads this at boot and errors out via the on-screen error overlay
  if it's missing)
