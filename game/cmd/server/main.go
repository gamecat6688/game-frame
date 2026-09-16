package main

import (
	"flag"
	"log"
	"net/http"
	"strings"
	"time"

	"gameframe/data"
	"gameframe/internal/adapters/storage"
	"gameframe/internal/adapters/wsbackend"
	"gameframe/internal/application"
)

func main() {
	addr := flag.String("listen", "127.0.0.1:18080", "prototype loopback endpoint")
	save := flag.String("save", "runtime/server.pb", "server-owned protobuf save file")
	token := flag.String("token", "prototype-local", "development access token; replace for shared testing")
	tokenFile := flag.String("token-file", "", "read access token from a file (overrides -token)")
	healthURL := flag.String("healthcheck-url", "", "check a running server's health and exit")
	flag.Parse()
	if *healthURL != "" {
		if err := checkHealth(*healthURL); err != nil {
			log.Fatal(err)
		}
		return
	}
	if *tokenFile != "" {
		value, err := readTokenFile(*tokenFile)
		if err != nil {
			log.Fatal(err)
		}
		*token = value
	}
	legacy := ""
	if strings.HasSuffix(*save, ".pb") {
		legacy = strings.TrimSuffix(*save, ".pb") + ".json"
	}
	runtime, err := application.New(data.Files, storage.File{Path: *save, LegacyPath: legacy}, storage.Clock{})
	if err != nil {
		log.Fatal(err)
	}
	mux := http.NewServeMux()
	// Replace the development token with account-session verification when the
	// account service is added; business messages only travel over WebSocket.
	mux.Handle("GET /ws", wsbackend.New(runtime.HandleBytes, *token))
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) { _, _ = w.Write([]byte("ok")) })
	server := http.Server{Addr: *addr, Handler: mux, ReadHeaderTimeout: 3 * time.Second, ReadTimeout: 5 * time.Second, WriteTimeout: 10 * time.Second, IdleTimeout: 30 * time.Second}
	log.Printf("Prototype authority: ws://%s/ws (independent server save)", *addr)
	log.Fatal(server.ListenAndServe())
}
