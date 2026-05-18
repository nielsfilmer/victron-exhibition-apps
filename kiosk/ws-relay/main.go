// kiosk-ws-relay — minimal localhost-only WebSocket relay for App 3.
//
// Listens on 127.0.0.1:PORT/ws. Each incoming message is rebroadcast
// to all OTHER connected clients (sender does not receive its own
// echo). The last message received is cached and replayed to new
// connections so satellites that connect after the center has already
// broadcast its state immediately catch up.
//
// No persistence, no auth, no TLS. Bind address is hardcoded to
// 127.0.0.1 so the kiosk Mac never exposes a port to the network.
//
// Build: ./build.sh (produces kiosk/bin/kiosk-ws-relay-{arm64,x86_64}).
package main

import (
	"context"
	"flag"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

// upgrader: the relay only ever runs on 127.0.0.1, so we accept
// any Origin (including the null origin Chrome assigns to file:// URLs).
var upgrader = websocket.Upgrader{
	CheckOrigin:     func(r *http.Request) bool { return true },
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
}

type hub struct {
	mu      sync.Mutex
	conns   map[*websocket.Conn]struct{}
	lastMsg []byte // most recent text message — replayed to new connects
	lastMT  int    // its message type (TextMessage / BinaryMessage)
}

func (h *hub) add(c *websocket.Conn) {
	h.mu.Lock()
	h.conns[c] = struct{}{}
	cached, mt := h.lastMsg, h.lastMT
	h.mu.Unlock()
	// Replay cached state so the new client doesn't have to wait
	// for the next broadcast to know where the slideshow is.
	if cached != nil {
		_ = c.WriteMessage(mt, cached)
	}
}

func (h *hub) remove(c *websocket.Conn) {
	h.mu.Lock()
	delete(h.conns, c)
	h.mu.Unlock()
}

// broadcast forwards `data` (of WebSocket message type `mt`) to every
// connection EXCEPT `sender`, and caches it for replay to future
// connects. Writes are best-effort; a connection that errors on write
// is dropped on the next read loop iteration.
func (h *hub) broadcast(sender *websocket.Conn, mt int, data []byte) {
	h.mu.Lock()
	// Cache for late joiners (copy — the websocket library reuses the
	// underlying buffer for the next Read).
	cached := make([]byte, len(data))
	copy(cached, data)
	h.lastMsg = cached
	h.lastMT = mt
	// Snapshot the destination list under the lock so iteration is safe
	// even if a connection is added/removed concurrently.
	targets := make([]*websocket.Conn, 0, len(h.conns))
	for c := range h.conns {
		if c != sender {
			targets = append(targets, c)
		}
	}
	h.mu.Unlock()

	for _, c := range targets {
		// Per-write deadline so a stuck client can't block the broadcast.
		_ = c.SetWriteDeadline(time.Now().Add(2 * time.Second))
		_ = c.WriteMessage(mt, data)
	}
}

func main() {
	addr := flag.String("addr", "127.0.0.1:8743", "address to listen on (must be 127.0.0.1)")
	flag.Parse()

	h := &hub{conns: map[*websocket.Conn]struct{}{}}

	mux := http.NewServeMux()
	mux.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		c, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			log.Printf("upgrade: %v", err)
			return
		}
		h.add(c)
		defer func() {
			h.remove(c)
			_ = c.Close()
		}()

		// Pings keep idle connections alive through any local firewalls / NAT.
		c.SetReadDeadline(time.Now().Add(60 * time.Second))
		c.SetPongHandler(func(string) error {
			c.SetReadDeadline(time.Now().Add(60 * time.Second))
			return nil
		})
		go pingLoop(r.Context(), c)

		for {
			mt, data, err := c.ReadMessage()
			if err != nil {
				return
			}
			h.broadcast(c, mt, data)
		}
	})

	// `/health` exists so an operator can `curl http://127.0.0.1:8743/health`
	// to confirm the relay is up without needing a WebSocket client.
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	log.Printf("kiosk-ws-relay listening on %s (clients: ws://%s/ws, health: http://%s/health)",
		*addr, *addr, *addr)
	srv := &http.Server{
		Addr:         *addr,
		Handler:      mux,
		ReadTimeout:  0, // websocket connections are long-lived
		WriteTimeout: 0,
	}
	log.Fatal(srv.ListenAndServe())
}

func pingLoop(ctx context.Context, c *websocket.Conn) {
	t := time.NewTicker(20 * time.Second)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			_ = c.SetWriteDeadline(time.Now().Add(5 * time.Second))
			if err := c.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}
