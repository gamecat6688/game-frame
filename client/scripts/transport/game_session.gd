class_name GameSession
extends Node

signal changed
signal completed(result: Dictionary)
signal state_changed(modules: PackedStringArray)
var snapshot: Dictionary = {}
var mode := "local"
var busy := false
var _local: LocalBackend
var _remote: RemoteBackend
var _generation := 0
var _sequence := 0
var _prefix := ""
var _last_command: Dictionary = {}
var _state := PlayerStateStore.new()
var _resync_result: Dictionary = {}
var _completed_ids: Dictionary = {}
var _reconnect_sync := false
var _elapsed := 0.0
var _config_version := ""
var offline_path := "user://offline.pb"

func setup(config_version: String) -> void:
	_config_version = config_version
	_state.modules_changed.connect(func(modules: PackedStringArray):
		snapshot = _state.snapshot
		state_changed.emit(modules))
	_prefix = Crypto.new().generate_random_bytes(12).hex_encode()
	switch_mode(str(ProjectSettings.get_setting("game/backend", "local")))

func switch_mode(next: String) -> void:
	if next not in ["local", "remote"]: next = "local"
	_generation += 1
	if _remote != null: _remote.close()
	_remote = null
	if _local != null: _local.close()
	_local = null
	mode = next
	snapshot = {}
	_state.clear()
	busy = false
	_resync_result.clear()
	_completed_ids.clear()
	_reconnect_sync = false
	if mode == "local":
		_local = LocalBackend.new()
		_local.open(ProjectSettings.globalize_path(offline_path))
	else:
		_remote = RemoteBackend.new()
		_remote.received.connect(_on_remote_response.bind(_generation))
		_remote.failed.connect(_on_remote_failure.bind(_generation))
		_remote.opened.connect(_on_remote_open.bind(_generation))
		_remote.open(str(ProjectSettings.get_setting("game/server_url")), str(ProjectSettings.get_setting("game/development_token")))
	changed.emit()
	send("snapshot")

func send(type: String, arguments: Dictionary = {}) -> void:
	if busy: return
	_sequence += 1
	var command := arguments.duplicate(true)
	command["id"] = "%s:%d" % [_prefix, _sequence]
	command["type"] = type
	command["protocol_version"] = GameProtocol.VERSION
	command["expected_revision"] = int(snapshot.get("revision", 0))
	_last_command = command
	_dispatch(command)

func _dispatch(command: Dictionary) -> void:
	busy = true
	var payload := GameProtocol.encode(command)
	if mode == "local":
		# Deferred completion gives local and remote transports the same async contract.
		_deliver.call_deferred(_local.execute(payload), _generation)
	else:
		_remote.execute(payload)
	changed.emit()

func _on_remote_response(body: PackedByteArray, generation: int) -> void:
	if generation != _generation or not busy: return
	var decoded := GameProtocol.decode(body)
	var id := str(decoded.get("id", ""))
	# A late/duplicate response cannot acknowledge a different pending command.
	if not id.is_empty() and id != str(_last_command.id): return
	_remote.acknowledge()
	_deliver(decoded, generation)
	_resume_sync.call_deferred(generation)

func _on_remote_failure(code: String, generation: int) -> void:
	if generation == _generation and busy:
		_deliver({"ok": false, "code": code}, generation)

func _on_remote_open(reconnected: bool, generation: int) -> void:
	if generation != _generation or (not reconnected and busy): return
	_reconnect_sync = true
	_resume_sync(generation)

func _resume_sync(generation: int) -> void:
	if generation != _generation or mode != "remote" or busy or not _reconnect_sync: return
	_reconnect_sync = false
	send("state.sync" if not snapshot.is_empty() else "snapshot")

func _deliver(result: Dictionary, generation: int) -> void:
	if generation != _generation: return
	busy = false
	if not str(result.get("id", "")).is_empty() and str(result.id) != str(_last_command.id):
		result = {"ok": false, "code": "invalid_response"}
	if result.has("update"):
		var received: Dictionary = result.update
		if str(received.get("config_version", "")) != _config_version:
			snapshot = {}
			_state.clear()
			changed.emit()
			completed.emit({"ok": false, "code": "config_mismatch"})
			return
		var outcome := _state.apply_response(result)
		if outcome == "resync" and _last_command.type != "snapshot":
			_resync_result = result
			send("snapshot")
			return
		if outcome in ["invalid", "resync"]:
			result = {"ok": false, "code": "invalid_response"}
		snapshot = _state.snapshot
	changed.emit()
	if not _resync_result.is_empty():
		var original := _resync_result
		_resync_result = {}
		if result.get("ok", false): result = original
	var id := str(result.get("id", ""))
	if not id.is_empty() and _completed_ids.has(id): return
	if not id.is_empty():
		_completed_ids[id] = true
		if _completed_ids.size() > 64: _completed_ids.erase(_completed_ids.keys()[0])
	completed.emit(result)

func _process(delta: float) -> void:
	if _remote != null: _remote.poll(delta)
	_elapsed += delta
	if _elapsed >= 5.0:
		_elapsed = 0.0
		if not busy and not snapshot.is_empty() and (mode == "local" or _remote.is_open()): send("state.sync")

func _exit_tree() -> void:
	_generation += 1
	if _remote != null: _remote.close()
	if _local != null: _local.close()
