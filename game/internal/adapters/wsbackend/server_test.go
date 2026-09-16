package wsbackend

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"gameframe/internal/application"
	"github.com/coder/websocket"
)

func dial(t *testing.T, url string, options *websocket.DialOptions) (*websocket.Conn, context.Context) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 4*time.Second)
	t.Cleanup(cancel)
	conn, _, err := websocket.Dial(ctx, strings.Replace(url, "http://", "ws://", 1), options)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { conn.CloseNow() })
	return conn, ctx
}

func options() *websocket.DialOptions {
	return &websocket.DialOptions{HTTPHeader: http.Header{"Authorization": {"Bearer test"}}, Subprotocols: []string{Subprotocol}}
}

func TestPersistentBinaryConnection(t *testing.T) {
	var calls atomic.Int32
	server := httptest.NewServer(New(func(raw []byte) []byte { calls.Add(1); return raw }, "test"))
	defer server.Close()
	conn, ctx := dial(t, server.URL, options())
	if conn.Subprotocol() != Subprotocol {
		t.Fatal("subprotocol not negotiated")
	}
	for _, value := range []string{"first", "second", "third"} {
		if err := conn.Write(ctx, websocket.MessageBinary, []byte(value)); err != nil {
			t.Fatal(err)
		}
		kind, raw, err := conn.Read(ctx)
		if err != nil || kind != websocket.MessageBinary || string(raw) != value {
			t.Fatalf("bad round trip: %q %v", raw, err)
		}
	}
	if calls.Load() != 3 {
		t.Fatal("lost messages on persistent connection")
	}
}

func TestHandshakeValidation(t *testing.T) {
	server := httptest.NewServer(New(func(raw []byte) []byte { t.Error("unauthorized execution"); return raw }, "test"))
	defer server.Close()
	for _, test := range []struct {
		name     string
		token    string
		protocol string
		origin   string
		status   int
	}{
		{"token", "wrong", Subprotocol, "", 401},
		{"protocol", "test", "unsupported", "", 400},
		{"origin", "test", Subprotocol, "https://foreign.example", 403},
	} {
		t.Run(test.name, func(t *testing.T) {
			opts := options()
			opts.HTTPHeader.Set("Authorization", "Bearer "+test.token)
			opts.Subprotocols = []string{test.protocol}
			if test.origin != "" {
				opts.HTTPHeader.Set("Origin", test.origin)
			}
			ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
			defer cancel()
			conn, response, err := websocket.Dial(ctx, server.URL, opts)
			if conn != nil {
				conn.CloseNow()
			}
			if err == nil || response == nil || response.StatusCode != test.status {
				t.Fatalf("unexpected handshake: %v %v", response, err)
			}
		})
	}
}

func TestRejectsTextAndOversizedMessages(t *testing.T) {
	var calls atomic.Int32
	server := httptest.NewServer(New(func(raw []byte) []byte { calls.Add(1); return raw }, "test"))
	defer server.Close()
	for _, test := range []struct {
		name string
		kind websocket.MessageType
		raw  []byte
		code websocket.StatusCode
	}{
		{"text", websocket.MessageText, []byte(`{"gold":999}`), websocket.StatusUnsupportedData},
		{"oversized", websocket.MessageBinary, make([]byte, application.MaxCommandBytes+1), websocket.StatusMessageTooBig},
	} {
		t.Run(test.name, func(t *testing.T) {
			conn, ctx := dial(t, server.URL, options())
			_ = conn.Write(ctx, test.kind, test.raw)
			_, _, err := conn.Read(ctx)
			if websocket.CloseStatus(err) != test.code {
				t.Fatalf("expected close %v: %v", test.code, err)
			}
		})
	}
	if calls.Load() != 0 {
		t.Fatal("invalid transport messages reached authority")
	}
}

func TestHeartbeatAndUnresponsivePeer(t *testing.T) {
	for _, respond := range []bool{true, false} {
		t.Run(map[bool]string{true: "pong", false: "timeout"}[respond], func(t *testing.T) {
			handler := New(func(raw []byte) []byte { return raw }, "test")
			handler.pingInterval = 20 * time.Millisecond
			handler.ioTimeout = 250 * time.Millisecond
			server := httptest.NewServer(handler)
			defer server.Close()
			pings := make(chan struct{}, 10)
			opts := options()
			opts.OnPingReceived = func(context.Context, []byte) bool {
				select {
				case pings <- struct{}{}:
				default:
				}
				return respond
			}
			conn, ctx := dial(t, server.URL, opts)
			ended := conn.CloseRead(ctx)
			select {
			case <-pings:
			case <-ctx.Done():
				t.Fatal("no server ping")
			}
			if respond {
				select {
				case <-pings:
				case <-ended.Done():
					t.Fatal("healthy connection disconnected")
				}
			} else {
				select {
				case <-ended.Done():
				case <-time.After(time.Second):
					t.Fatal("unresponsive connection kept alive")
				}
			}
		})
	}
}
