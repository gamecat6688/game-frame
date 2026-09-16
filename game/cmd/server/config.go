package main

import (
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"
)

func readTokenFile(path string) (string, error) {
	file, err := os.Open(path)
	if err != nil {
		return "", fmt.Errorf("open token file: %w", err)
	}
	defer file.Close()
	raw, err := io.ReadAll(io.LimitReader(file, 4097))
	if err != nil {
		return "", fmt.Errorf("read token file: %w", err)
	}
	token := strings.TrimSpace(string(raw))
	if len(raw) > 4096 || token == "" || strings.ContainsAny(token, "\r\n\x00") {
		return "", errors.New("token file must contain one nonempty token of at most 4096 bytes")
	}
	return token, nil
}

func checkHealth(url string) error {
	client := http.Client{Timeout: 2 * time.Second}
	response, err := client.Get(url)
	if err != nil {
		return fmt.Errorf("healthcheck: %w", err)
	}
	defer response.Body.Close()
	body, err := io.ReadAll(io.LimitReader(response.Body, 16))
	if err != nil {
		return fmt.Errorf("healthcheck body: %w", err)
	}
	if response.StatusCode != http.StatusOK || string(body) != "ok" {
		return fmt.Errorf("healthcheck failed: HTTP %d", response.StatusCode)
	}
	return nil
}
