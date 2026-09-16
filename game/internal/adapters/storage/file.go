package storage

import (
	"errors"
	"io"
	"os"
	"path/filepath"
	"time"
)

type File struct {
	Path       string
	LegacyPath string
}

func (f File) Load() ([]byte, error) {
	path := f.Path
	file, err := os.Open(path)
	if errors.Is(err, os.ErrNotExist) && f.LegacyPath != "" {
		file, err = os.Open(f.LegacyPath)
	}
	if err != nil {
		return nil, err
	}
	defer file.Close()
	data, err := io.ReadAll(io.LimitReader(file, (16<<20)+1))
	if err != nil {
		return nil, err
	}
	if len(data) > 16<<20 {
		return nil, errors.New("save too large")
	}
	return data, nil
}
func (f File) Save(data []byte) error {
	if err := os.MkdirAll(filepath.Dir(f.Path), 0700); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(f.Path), "save-*.tmp")
	if err != nil {
		return err
	}
	name := tmp.Name()
	defer os.Remove(name)
	if _, err = tmp.Write(data); err != nil {
		tmp.Close()
		return err
	}
	if err = tmp.Sync(); err != nil {
		tmp.Close()
		return err
	}
	if err = tmp.Close(); err != nil {
		return err
	}
	return replaceFile(name, f.Path)
}

type Clock struct{}

func (Clock) Unix() int64 { return time.Now().Unix() }
