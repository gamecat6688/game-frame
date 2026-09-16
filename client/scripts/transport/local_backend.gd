class_name LocalBackend
extends RefCounted

var _bridge: RefCounted
var _handle := ""
var _library := ""
var _error := "native_unavailable"

func open(save_path: String) -> void:
	_library = ProjectSettings.globalize_path("res://addons/game_bridge/bin/gamecore.dll")
	if not ClassDB.class_exists("GameCoreBridge"): return
	_bridge = ClassDB.instantiate("GameCoreBridge")
	var result := _call({"op": "open", "save_path": save_path})
	_handle = str(result.get("handle", ""))
	_error = str(result.get("code", "native_unavailable"))

func execute(payload: PackedByteArray) -> Dictionary:
	if _handle.is_empty(): return {"ok": false, "code": _error}
	var result := _call({"op": "command", "handle": _handle, "payload": Marshalls.raw_to_base64(payload)})
	if not result.get("ok", false): return result
	return GameProtocol.decode(Marshalls.base64_to_raw(str(result.get("payload", ""))))

func close() -> void:
	if not _handle.is_empty(): _call({"op": "close", "handle": _handle})
	_handle = ""
	_bridge = null

func _call(value: Dictionary) -> Dictionary:
	var raw: String = _bridge.call_core(_library, JSON.stringify(value))
	var decoded = JSON.parse_string(raw)
	return decoded if decoded is Dictionary else {"ok": false, "code": "invalid_response"}
