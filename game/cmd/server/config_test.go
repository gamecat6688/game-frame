package main

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestReadTokenFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "token")
	if _, err := readTokenFile(path); err == nil {
		t.Fatal("missing secret accepted")
	}
	for _, test := range []struct{ name, contents, want string }{
		{"valid", "  test-token\r\n", "test-token"},
		{"empty", " \n", ""},
		{"multiline", "first\nsecond", ""},
		{"oversized", strings.Repeat("x", 4097), ""},
	} {
		t.Run(test.name, func(t *testing.T) {
			if err := os.WriteFile(path, []byte(test.contents), 0600); err != nil {
				t.Fatal(err)
			}
			value, err := readTokenFile(path)
			if test.want == "" {
				if err == nil {
					t.Fatal("invalid secret accepted")
				}
				return
			}
			if err != nil || value != test.want {
				t.Fatalf("unexpected token result: %v", err)
			}
		})
	}
}

func TestHealthcheck(t *testing.T) {
	for _, test := range []struct {
		name   string
		status int
		body   string
		valid  bool
	}{
		{"healthy", 200, "ok", true}, {"wrong-body", 200, "not ready", false}, {"unhealthy", 503, "ok", false},
	} {
		t.Run(test.name, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.WriteHeader(test.status)
				_, _ = w.Write([]byte(test.body))
			}))
			defer server.Close()
			if err := checkHealth(server.URL); (err == nil) != test.valid {
				t.Fatalf("unexpected check result: %v", err)
			}
		})
	}
}
