package application

import (
	pb "gameframe/internal/protocol"
	"google.golang.org/protobuf/proto"
)

const MaxCommandBytes = 65536
const ProtocolVersion = 2

func ErrorBytes(code string) []byte {
	raw, _ := proto.Marshal(&pb.GameResponse{Code: code})
	return raw
}

// Both hosts use this exact decoder and handler. No transport has a second set
// of gameplay rules or accepts client-provided player state.
func (r *Runtime) HandleBytes(raw []byte) []byte {
	cmd := &pb.Command{}
	if len(raw) == 0 || len(raw) > MaxCommandBytes || proto.Unmarshal(raw, cmd) != nil {
		return ErrorBytes("invalid_request")
	}
	result := r.Execute(cmd)
	output, err := proto.Marshal(result)
	if err != nil {
		return ErrorBytes("internal_error")
	}
	return output
}
