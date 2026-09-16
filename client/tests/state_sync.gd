extends SceneTree

var _failures := 0
var _signals := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	if not value:
		_failures += 1
		push_error("STATE_SYNC: " + message)

func _wire(value: Dictionary) -> Dictionary:
	var message := GameProtocol.GameResponse.new()
	message.ParseFromDictionary(value)
	return GameProtocol.decode(message.SerializeToBytes())

func _response(revision: int) -> Dictionary:
	return {"id": "response-%d" % revision, "code": "ok", "update": {
		"revision": revision, "config_version": "test", "server_time": 100,
		"idle": {"gold": 0, "experience": 0}}}

func _run() -> void:
	var success := _wire({"id": "compact-success", "code": "ok"})
	_check(success.get("ok", false), "success was not derived from code")
	var failure := _wire({"id": "compact-failure", "code": "insufficient_resources"})
	_check(not failure.get("ok", true), "error code was treated as success")
	_check(_wire({"id": "missing-status"}).code == "invalid_response", "missing status was accepted")
	var store := PlayerStateStore.new()
	store.modules_changed.connect(func(_modules: PackedStringArray): _signals += 1)
	var full := _response(1)
	full.update.merge({"wallet": {"gold": 80, "experience": 30}, "heroes": {"heroes": [{"id": 1, "level": 1, "equipment": 101, "health": 100}]},
		"equipment": {"items": [{"id": 101, "hero_id": 1}, {"id": 102, "hero_id": 0}]},
		"formation": {"slots": [1]}, "campaign": {"stage": 1}})
	_check(store.apply_response(_wire(full)) == "applied", "initial full state rejected")
	for module in PlayerStateStore.MODULES:
		var incomplete := full.duplicate(true)
		incomplete.update.erase(module)
		_check(PlayerStateStore.new().apply_response(_wire(incomplete)) == "resync", "incomplete snapshot accepted: " + module)
	var delta := _response(2)
	delta.update.wallet = {"gold": 0, "experience": 0}
	delta.update.formation = {"slots": []}
	delta.notifications = [{"equipment": {"upsert": [{"id": 101, "hero_id": 0}], "deleted_ids": [102]}}]
	_check(store.apply_response(_wire(delta)) == "applied", "delta rejected")
	_check(store.snapshot.gold == 0 and store.snapshot.experience == 0, "scalar zero was lost")
	_check(store.snapshot.formation.is_empty(), "empty repeated field did not replace prior module")
	_check(store.snapshot.heroes.size() == 1 and store.snapshot.stage == 1, "absent modules were overwritten")
	_check(store.snapshot.equipment == [101] and store.snapshot.equipment_owners[101] == 0, "delete or zero-owner upsert failed")
	var signals_before := _signals
	_check(store.apply_response(_wire(delta)) == "ignored" and _signals == signals_before, "duplicate receipt reapplied")
	_check(store.apply_response(_wire(full)) == "ignored", "older full state rolled back progress")
	var before := store.snapshot.duplicate(true)
	_check(store.apply_response(_wire(_response(4))) == "resync", "revision gap not detected")
	_check(store.snapshot == before, "gap partially changed visible state")
	var invalid := _response(3)
	invalid.update.wallet = {"gold": 999}
	invalid.notifications = [{"equipment": {"upsert": [{"id": 101}], "deleted_ids": [101]}}]
	_check(store.apply_response(_wire(invalid)) == "invalid", "contradictory inventory patch accepted")
	_check(store.snapshot == before, "invalid response partially changed wallet")
	var heartbeat := _response(2)
	heartbeat.update.server_time = 101
	heartbeat.update.idle.gold = 5
	_check(store.apply_response(_wire(heartbeat)) == "applied" and store.snapshot.idle_gold == 5, "same-revision idle refresh failed")
	_check(store.apply_response(_wire(_response(2))) == "ignored", "old timed view rolled back idle accrual")
	full.update.revision = 4
	full.update.server_time = 105
	_check(store.apply_response(_wire(full)) == "applied" and store.snapshot.revision == 4, "full resync failed")
	var empty := _response(5)
	empty.update.merge({"wallet": {}, "heroes": {}, "equipment": {}, "formation": {}, "campaign": {}})
	_check(store.apply_response(_wire(empty)) == "applied", "empty modules did not count as a full snapshot")
	_check(store.snapshot.heroes.is_empty() and store.snapshot.equipment.is_empty(), "full snapshot retained prior items")
	store.clear()
	_check(store.apply_response(_wire(delta)) == "resync", "delta applied without a baseline")
	var encoded := GameProtocol.encode({"id": "large", "type": "snapshot", "expected_revision": 9007199254740993})
	var command := GameProtocol.Command.new()
	_check(command.ParseFromBytes(encoded) == encoded.size() and command.expected_revision == 9007199254740993, "int64 lost precision")
	print("STATE_SYNC: %d failures; protobuf, zero/empty values, notifications, duplicate/stale/gap recovery verified" % _failures)
	quit(0 if _failures == 0 else 1)
