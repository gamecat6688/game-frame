package ports

type Store interface {
	Load() ([]byte, error)
	Save([]byte) error
}

type Clock interface{ Unix() int64 }
