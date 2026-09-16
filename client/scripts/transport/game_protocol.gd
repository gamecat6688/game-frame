class_name GameProtocol
extends RefCounted

const Command = preload("res://protobuf/generated/api/Command.proto.gd").Command
const GameResponse = preload("res://protobuf/generated/api/GameResponse.proto.gd").GameResponse
const VERSION := 2
const SUBPROTOCOL := "gameframe.v2"

static func encode(command: Dictionary) -> PackedByteArray:
	var message := Command.new()
	message.ParseFromDictionary(command)
	message.protocol_version = VERSION
	return message.SerializeToBytes()

static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty() or bytes.size() > 1048576:
		return {"ok": false, "code": "invalid_response"}
	var message := GameResponse.new()
	if message.ParseFromBytes(bytes) != bytes.size():
		return {"ok": false, "code": "invalid_response"}
	if message.code.is_empty():
		return {"ok": false, "code": "invalid_response"}
	var result := message.SerializeToDictionary()
	# UI convenience only; success is represented once on the wire by code.
	result["ok"] = message.code == "ok"
	return result
