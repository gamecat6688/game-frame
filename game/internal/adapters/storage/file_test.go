package storage

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"
)

func TestAtomicReplacementAndLegacyFallback(t *testing.T) {
	dir := t.TempDir()
	legacy := filepath.Join(dir, "player.json")
	target := filepath.Join(dir, "player.pb")
	if err := os.WriteFile(legacy, []byte("legacy"), 0600); err != nil {
		t.Fatal(err)
	}
	store := File{Path: target, LegacyPath: legacy}
	if got, err := store.Load(); err != nil || string(got) != "legacy" {
		t.Fatal("legacy fallback failed", err)
	}
	for _, value := range [][]byte{[]byte("first complete record"), bytes.Repeat([]byte{7}, 8192), []byte("short")} {
		if err := store.Save(value); err != nil {
			t.Fatal(err)
		}
		got, err := store.Load()
		if err != nil || !bytes.Equal(got, value) {
			t.Fatal("replacement incomplete", err)
		}
	}
	if got, _ := os.ReadFile(legacy); string(got) != "legacy" {
		t.Fatal("legacy source overwritten")
	}
	matches, _ := filepath.Glob(filepath.Join(dir, "save-*.tmp"))
	if len(matches) != 0 {
		t.Fatal("temporary files left behind")
	}
}

func TestFailedReplacementKeepsDestination(t *testing.T) {
	dir := t.TempDir()
	target := filepath.Join(dir, "not-a-file")
	if err := os.Mkdir(target, 0700); err != nil {
		t.Fatal(err)
	}
	marker := filepath.Join(target, "keep")
	if err := os.WriteFile(marker, []byte("original"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := (File{Path: target}).Save([]byte("replacement")); err == nil {
		t.Fatal("expected replacement failure")
	}
	if got, _ := os.ReadFile(marker); string(got) != "original" {
		t.Fatal("failed save damaged destination")
	}
	matches, _ := filepath.Glob(filepath.Join(dir, "save-*.tmp"))
	if len(matches) != 0 {
		t.Fatal("failed save leaked temporary file")
	}
}
