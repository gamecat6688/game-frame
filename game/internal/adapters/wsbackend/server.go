// Package wsbackend hosts the same binary command handler used by the DLL.
package wsbackend

import (
	"context"
	"crypto/subtle"
	"net/http"
	"strings"
	"time"

	"gameframe/internal/application"
	"github.com/coder/websocket"
)

const Subprotocol = "gameframe.v2"

type Handler struct {
	execute      func([]byte) []byte
	token        string
	pingInterval time.Duration
	ioTimeout    time.Duration
}

func New(execute func([]byte) []byte, token string) *Handler {
	return &Handler{execute: execute, token: token, pingInterval: 15 * time.Second, ioTimeout: 10 * time.Second}
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if h.token == "" || subtle.ConstantTimeCompare([]byte(r.Header.Get("Authorization")), []byte("Bearer "+h.token)) != 1 {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	supported := false
	for _, value := range r.Header.Values("Sec-WebSocket-Protocol") {
		for _, protocol := range strings.Split(value, ",") {
			if strings.TrimSpace(protocol) == Subprotocol {
				supported = true
			}
		}
	}
	if !supported {
		http.Error(w, "unsupported websocket subprotocol", http.StatusBadRequest)
		return
	}
	// Default Origin checks remain enabled. Native Godot has no browser Origin.
	conn, err := websocket.Accept(w, r, &websocket.AcceptOptions{Subprotocols: []string{Subprotocol}})
	if err != nil {
		return
	}
	defer conn.CloseNow()
	conn.SetReadLimit(application.MaxCommandBytes)
	ctx, cancel := context.WithCancel(r.Context())
	defer cancel()
	go h.heartbeat(ctx, cancel, conn)
	for {
		kind, raw, err := conn.Read(ctx)
		if err != nil {
			return
		}
		if kind != websocket.MessageBinary {
			_ = conn.Close(websocket.StatusUnsupportedData, "binary protobuf required")
			return
		}
		// Sequential per connection; Runtime also serializes mutations across
		// connections. Persistence completes before any reply is written.
		response := h.execute(raw)
		writeCtx, writeCancel := context.WithTimeout(ctx, h.ioTimeout)
		err = conn.Write(writeCtx, websocket.MessageBinary, response)
		writeCancel()
		if err != nil {
			return
		}
	}
}

func (h *Handler) heartbeat(ctx context.Context, cancel context.CancelFunc, conn *websocket.Conn) {
	ticker := time.NewTicker(h.pingInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			pingCtx, pingCancel := context.WithTimeout(ctx, h.ioTimeout)
			err := conn.Ping(pingCtx)
			pingCancel()
			if err != nil {
				cancel()
				return
			}
		}
	}
}
