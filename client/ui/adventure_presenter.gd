class_name AdventurePresenter
extends RefCounted

var _view: AdventureView
var _service: AdventureService
var _locale: GameLocalization
var _hero := 1
var _slot := 0
var _formation: Array = [1, 4, 2, 3, 5]
var _mode := ""
var _status_key := "UI_CONNECTING"
var _last_battle: Dictionary = {}
var _replaying := false
var _ready_once := false

func setup(view: AdventureView, service: AdventureService, locale: GameLocalization) -> void:
	_view = view
	_service = service
	_locale = locale
	_view.action_requested.connect(_on_action)
	_view.locale_selected.connect(_on_locale)
	_view.battle_finished.connect(_on_battle_finished)
	_service.session.changed.connect(refresh)
	_service.session.completed.connect(_on_completed)
	_locale.changed.connect(refresh)

func dispose() -> void:
	if not is_instance_valid(_view): return
	_view.action_requested.disconnect(_on_action)
	_view.locale_selected.disconnect(_on_locale)
	_view.battle_finished.disconnect(_on_battle_finished)
	_service.session.changed.disconnect(refresh)
	_service.session.completed.disconnect(_on_completed)
	_locale.changed.disconnect(refresh)

func _t(key: String) -> String:
	return _locale.resolve(key)

func _on_locale(index: int) -> void:
	_locale.set_locale(GameLocalization.LOCALES[index])

func _on_action(action: String, value: int) -> void:
	var session := _service.session
	match action:
		"tab": _view.select_page(value)
		"hero": _hero = value
		"slot": _slot = value
		"reserve":
			var existing := _formation.find(value)
			if existing >= 0: _formation[existing] = _formation[_slot]
			_formation[_slot] = value
		"mode":
			_view.cancel_battle()
			_replaying = false
			_last_battle = {}
			_status_key = "UI_CONNECTING"
			session.switch_mode("remote" if session.mode == "local" else "local")
		"battle": session.send("campaign.battle")
		"claim": session.send("idle.claim")
		"level": session.send("hero.level_up", {"hero_id": _hero})
		"equip": session.send("equipment.equip", {"hero_id": _hero, "equipment_id": value})
		"save_formation": session.send("formation.save", {"formation": _formation})
	refresh()

func _on_completed(result: Dictionary) -> void:
	if not result.get("ok", false):
		_status_key = "ERR_" + str(result.get("code", "generic")).to_upper()
		if _t(_status_key) == _status_key: _status_key = "ERR_GENERIC"
	elif result.has("battle"):
		_last_battle = result.battle
		_replaying = true
		_view.play_battle(_last_battle, _battle_names())
	elif _status_key == "UI_CONNECTING" or _status_key.begins_with("ERR_"):
		_status_key = "UI_READY"
	refresh()

func _on_battle_finished() -> void:
	_replaying = false
	refresh()

func _battle_names() -> Dictionary:
	var formation: Array = _service.session.snapshot.get("formation", [1, 4, 2, 3, 5])
	if _replaying:
		formation = []
		for fighter in _last_battle.allies: formation.append(int(fighter.id))
	var names: Array[String] = []
	for id in formation: names.append(_t(_service.hero(int(id)).name_key))
	var stage_id := int(_last_battle.get("stage", _service.session.snapshot.get("stage", 1))) if _replaying else int(_service.session.snapshot.get("stage", 1))
	var stage := _service.stage(mini(stage_id, _service.stage_count()))
	var enemies: Array[String] = []
	for i in range(5): enemies.append(_t(stage.enemy_key))
	var skills := {}
	for i in range(1, 7): skills[i] = _t(_service.skill_key(i))
	return {"ally": names, "enemy": enemies, "skills": skills}

func refresh() -> void:
	var session := _service.session
	var state := session.snapshot
	if _mode != session.mode:
		_mode = session.mode
		_ready_once = false
	if not _ready_once and not state.is_empty():
		_formation = []
		for id in state.formation: _formation.append(int(id))
		_ready_once = true
	var stage_number := int(state.get("stage", 1))
	if _replaying: stage_number = int(_last_battle.stage)
	var stage := _service.stage(stage_number)
	var complete := stage.is_empty()
	var heroes: Array = []
	for id in range(1, 7):
		var h := _service.hero(id)
		heroes.append({"id": id, "name": _t(h.name_key), "caption": _t("UI_LEVEL") % [_t(h.role_key), h.level], "selected": id == _hero})
	var hero := _service.hero(_hero)
	var equipped := _service.equipment(hero.equipment)
	var equipment: Array = []
	for id in range(101, 104):
		var item := _service.equipment(id)
		var owner := _t("UI_UNASSIGNED")
		if item.owner > 0: owner = _t("UI_OWNER") % _t(_service.hero(item.owner).name_key)
		equipment.append({"id": id, "name": _t(item.name_key), "description": _t(item.description_key),
			"stats": (_t("UI_EQUIP_STATS") % [item.attack, item.health, item.required_level]) + "\n" + owner})
	var slots: Array[String] = []
	for i in range(5): slots.append(_t("UI_SLOT") % [i + 1, _t(_service.hero(int(_formation[i])).name_key)])
	var names := _battle_names()
	var allies: Array = []
	var enemies: Array = []
	var deployed: Array = state.get("formation", [1, 4, 2, 3, 5])
	for i in range(5):
		allies.append({"name": names.ally[i], "portrait": "res://assets/hero_%d.svg" % int(deployed[i])})
		enemies.append({"name": names.enemy[i], "portrait": "res://assets/enemy.svg"})
	_view.render({"gold": str(int(state.get("gold", 0))), "xp": str(int(state.get("experience", 0))), "empty": state.is_empty(),
		"mode_label": _t("UI_MODE_LOCAL" if session.mode == "local" else "UI_MODE_REMOTE"),
		"mode_action": _t("UI_GO_ONLINE" if session.mode == "local" else "UI_GO_OFFLINE"),
		"locale_index": maxi(0, GameLocalization.LOCALES.find(TranslationServer.get_locale())),
		"stage_title": _t("UI_COMPLETE") if complete else ("1–%d  %s" % [stage_number, _t(stage.name_key)]),
		"stage_description": _t("UI_COMPLETE_HINT") if complete else _t(stage.description_key),
		"stage_reward": "" if complete else _t("UI_REWARDS") % [stage.gold, stage.xp],
		"idle": _t("UI_IDLE_AMOUNT") % [int(state.get("idle_gold", 0)), int(state.get("idle_experience", 0))],
		"idle_hint": _t("UI_IDLE_HINT") % _service.idle_cap_hours(),
		"busy": session.busy, "complete": complete, "heroes": heroes, "equipment": equipment, "slot": _slot, "slots": slots,
		"hero_name": _t("UI_LEVEL") % [_t(hero.name_key), hero.level], "hero_description": _t(hero.description_key),
		"hero_stats": _t("UI_STATS") % [hero.attack, hero.health, hero.defense],
		"hero_skill": _t(hero.skill_key) + " · " + _t(hero.skill_description_key),
		"hero_equipment": _t("UI_EQUIPPED") % (_t("UI_NO_EQUIPMENT") if equipped.is_empty() else _t(equipped.name_key)),
		"level_cost": _t("UI_COST") % [hero.level_gold, hero.level_xp], "allies": allies, "enemies": enemies, "battle_names": names})
	_view.show_status(_t(_status_key))
	if not _replaying:
		if _last_battle.is_empty(): _view.show_battle_log(_t("UI_ADVENTURE_HINT"))
		elif _last_battle.victory: _view.show_battle_log(_t("UI_VICTORY") % [int(_last_battle.gold), int(_last_battle.experience)])
		else: _view.show_battle_log(_t("UI_DEFEAT"))
