extends SceneTree

var _failures := 0
var _app: Node

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("SMOKE: " + message)

func _settle() -> void:
	for i in range(1000):
		await create_timer(0.025).timeout
		if not _app.session.busy: break
	await process_frame

func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/" + name + ".png"))

func _controls(node: Node) -> int:
	var count := 1 if node is Control else 0
	for child in node.get_children(): count += _controls(child)
	return count

func _check_currencies(context: String) -> void:
	var state: Dictionary = _app.session.snapshot
	_check(state.has("gold") and state.has("experience"), context + " wallet snapshot missing")
	_check(_app.get_node("%Gold").text == str(int(state.get("gold", -1))), context + " gold binding mismatch")
	_check(_app.get_node("%XP").text == str(int(state.get("experience", -1))), context + " experience binding mismatch")

func _run() -> void:
	ProjectSettings.set_setting("game/backend", "local")
	# This smoke connects to its isolated test server, not the local Docker save.
	ProjectSettings.set_setting("game/development_token", "prototype-local")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--server-url="):
			ProjectSettings.set_setting("game/server_url", argument.trim_prefix("--server-url="))
	_app = load("res://ui/main.tscn").instantiate()
	_app.get_node("Session").offline_path = "res://../build/ui-smoke-%d.pb" % Time.get_ticks_usec()
	root.add_child(_app)
	await _settle()
	_check(not _app.session.snapshot.is_empty(), "native DLL snapshot unavailable")
	if _app.session.snapshot.is_empty():
		quit(1)
		return
	_check(_app.session.snapshot.heroes.size() == 6, "six owned heroes expected")
	_check_currencies("offline startup")
	var original_controls := _controls(_app)
	var stage_label: Label = _app.get_node("%StageTitle")
	_check(stage_label.text.contains("薄雾林地"), "excel2pb Chinese content missing")
	await _capture("campaign-zh")
	_app.get_node("%Locale").item_selected.emit(2)
	_check(stage_label.text.contains("Mistwood"), "excel2pb English content missing")
	_check(TranslationServer.translate("UI_TAB_HEROES") == "Heroes", "Godot English UI missing")
	await _capture("campaign-en")
	_app.get_node("%Locale").item_selected.emit(1)
	_check(stage_label.text.contains("薄霧林地"), "excel2pb Traditional Chinese missing")
	await _capture("campaign-tw")
	_app.get_node("%Locale").item_selected.emit(0)
	_app.get_node("%Tab1").pressed.emit()
	_app.get_node("%Hero5").pressed.emit()
	_app.get_node("%LevelUp").pressed.emit()
	await _settle()
	_check(int(_app.session.snapshot.heroes[4].level) == 2, "training must be authoritative")
	_check_currencies("offline after training")
	await _capture("heroes-zh")
	_app.get_node("%Tab3").pressed.emit()
	_app.get_node("%Equip101").pressed.emit()
	await _settle()
	_check(int(_app.session.snapshot.heroes[4].equipment) == 101, "equipment mutation failed")
	await _capture("equipment-zh")
	_app.get_node("%Locale").item_selected.emit(2)
	await _capture("equipment-en")
	_app.get_node("%Tab2").pressed.emit()
	_app.get_node("%Slot0").pressed.emit()
	_app.get_node("%Reserve6").pressed.emit()
	_app.get_node("%SaveFormation").pressed.emit()
	await _settle()
	_check(int(_app.session.snapshot.formation[0]) == 6, "formation was not saved")
	await _capture("formation-en")
	_app.get_node("%Tab0").pressed.emit()
	_app.get_node("%Battle").pressed.emit()
	await _settle()
	_check(not _app._presenter._last_battle.is_empty(), "battle result missing")
	_check(_app._presenter._last_battle.events.size() > 0, "battle event playback missing")
	await create_timer(0.5).timeout
	await _capture("battle-en")
	_app.get_node("%Locale").item_selected.emit(0)
	_check(not _app.get_node("%BattleLog").text.contains("damage"), "active battle log not relocalized")
	_app.get_node("%Skip").pressed.emit()
	await _settle()
	# Simulate a lost committed response, then deliver the next valid delta.
	# The Session must detect its missing baseline and fetch a full state.
	var before_gap := int(_app.session.snapshot.revision)
	var lost := {"id": "smoke-lost", "type": "hero.level_up", "hero_id": 2, "expected_revision": before_gap}
	var lost_result: Dictionary = _app.session._local.execute(GameProtocol.encode(lost))
	_check(lost_result.get("ok", false), "could not create lost-response fixture")
	var after_gap := {"id": "smoke-after-gap", "type": "hero.level_up", "hero_id": 2, "expected_revision": before_gap + 1}
	_app.session._last_command = after_gap
	_app.session._dispatch(after_gap)
	await _settle()
	_check(int(_app.session.snapshot.revision) == before_gap + 2, "session did not recover missed revision")
	_check(int(_app.session.snapshot.heroes[1].level) == 3, "resync replayed or lost an authoritative operation")
	_check(_app.session._last_command.type == "snapshot", "gap did not trigger snapshot request")
	_check(_controls(_app) == original_controls, "runtime created or rebuilt Control layout")
	_check(_app.get_node("%StageTitle") == stage_label, "locale change recreated static scene")
	var offline_revision := int(_app.session.snapshot.revision)
	if "--with-server" in OS.get_cmdline_user_args():
		_app.get_node("%ModeSwitch").pressed.emit()
		await _settle()
		_check(_app.session.mode == "remote" and not _app.session.snapshot.is_empty(), "remote snapshot failed")
		_check_currencies("online startup")
		var backend: RemoteBackend = _app.session._remote
		var peer: WebSocketPeer = backend._peer
		_app.session.send("snapshot")
		await _settle()
		_check(backend._peer == peer, "online commands did not reuse one socket")
		var before_disconnect := int(_app.session.snapshot.revision)
		var old_level := int(_app.session.snapshot.heroes[2].level)
		_app.session.send("hero.level_up", {"hero_id": 3})
		var pending_id: String = _app.session._last_command.id
		var completions := [0]
		var on_complete := func(result: Dictionary):
			if str(result.get("id", "")) == pending_id: completions[0] += 1
		_app.session.completed.connect(on_complete)
		# Let the server commit and queue its response, without letting Session
		# consume it. Drop that response and require automatic reconnect/replay.
		_app.session.set_process(false)
		for i in range(160):
			peer.poll()
			if peer.get_available_packet_count() > 0: break
			await create_timer(0.025).timeout
		_check(peer.get_available_packet_count() > 0, "committed response was not queued")
		peer.close(-1)
		_app.session.set_process(true)
		await _settle()
		_check(backend._peer != peer and backend.is_open(), "WebSocket did not reconnect")
		_check(int(_app.session.snapshot.revision) == before_disconnect + 1, "reconnect duplicated or lost operation")
		_check(int(_app.session.snapshot.heroes[2].level) == old_level + 1, "reconnect did not restore committed upgrade")
		_check(completions[0] == 1, "replayed result completed more than once")
		_app.session.completed.disconnect(on_complete)
		# An idle disconnect must also reconnect and resynchronize without a click.
		backend._peer.close(-1)
		for i in range(240):
			await create_timer(0.025).timeout
			if backend.is_open() and not _app.session.busy: break
		_check(backend.is_open() and not _app.session.busy, "idle reconnect did not restore connection")
		await _capture("online-zh")
		_app.get_node("%ModeSwitch").pressed.emit()
		await _settle()
		_check(int(_app.session.snapshot.revision) == offline_revision, "switching modes contaminated offline save")
		_check_currencies("returned offline")
	print("UI_SMOKE: %d failures; %d static controls; locales + training + gear + formation + battle + WebSocket reconnect/replay verified" % [_failures, original_controls])
	_app.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)
