package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"encoding/base64"
	"encoding/json"
	"strconv"
	"strings"
	"sync"
	"unsafe"

	"gameframe/data"
	"gameframe/internal/adapters/storage"
	"gameframe/internal/application"
)

var registry = struct {
	sync.Mutex
	next  uint64
	items map[string]*application.Runtime
}{items: map[string]*application.Runtime{}}

type call struct {
	Op       string `json:"op"`
	Handle   string `json:"handle"`
	SavePath string `json:"save_path"`
	Payload  string `json:"payload"`
}

//export GameCall
func GameCall(input *C.char) (out *C.char) {
	defer func() {
		if recover() != nil {
			out = C.CString(`{"ok":false,"code":"internal_error"}`)
		}
	}()
	var req call
	if input == nil {
		return C.CString(`{"ok":false,"code":"invalid_request"}`)
	}
	raw := C.GoString(input)
	if len(raw) > 100000 || json.Unmarshal([]byte(raw), &req) != nil {
		return C.CString(`{"ok":false,"code":"invalid_request"}`)
	}
	registry.Lock()
	defer registry.Unlock()
	var result any
	switch req.Op {
	case "open":
		if req.SavePath == "" {
			result = map[string]any{"ok": false, "code": "save_failed"}
			break
		}
		legacy := ""
		if strings.HasSuffix(req.SavePath, ".pb") {
			legacy = strings.TrimSuffix(req.SavePath, ".pb") + ".json"
		}
		runtime, err := application.New(data.Files, storage.File{Path: req.SavePath, LegacyPath: legacy}, storage.Clock{})
		if err != nil {
			result = map[string]any{"ok": false, "code": "save_failed"}
			break
		}
		registry.next++
		handle := strconv.FormatUint(registry.next, 10)
		registry.items[handle] = runtime
		result = map[string]any{"ok": true, "handle": handle}
	case "close":
		delete(registry.items, req.Handle)
		result = map[string]any{"ok": true}
	case "command":
		runtime := registry.items[req.Handle]
		if runtime == nil {
			result = map[string]any{"ok": false, "code": "invalid_session"}
		} else {
			input, err := base64.StdEncoding.DecodeString(req.Payload)
			if err != nil {
				result = map[string]any{"ok": false, "code": "invalid_request"}
				break
			}
			result = map[string]any{"ok": true, "payload": base64.StdEncoding.EncodeToString(runtime.HandleBytes(input))}
		}
	default:
		result = map[string]any{"ok": false, "code": "unknown_command"}
	}
	output, err := json.Marshal(result)
	if err != nil {
		return C.CString(`{"ok":false,"code":"internal_error"}`)
	}
	return C.CString(string(output))
}

//export GameFree
func GameFree(ptr unsafe.Pointer) { C.free(ptr) }
func main()                       {}
