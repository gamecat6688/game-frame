class_name AdventureView
extends Control

signal action_requested(action: String, value: int)
signal locale_selected(index: int)
signal battle_finished

var _battle: Dictionary = {}
var _battle_index := 0
var _battle_elapsed := 0.0
var _playing := false
var _battle_names: Dictionary = {}
var _last_event: Dictionary = {}
@onready var _pages: Array[Control] = [%Campaign, %Heroes, %Formation, %Equipment]

func _ready() -> void:
	%Locale.item_selected.connect(func(index: int): locale_selected.emit(index))
	for i in range(4):
		get_node("%%Tab%d" % i).pressed.connect(func(): action_requested.emit("tab", i))
	for i in range(1, 7):
		get_node("%%Hero%d" % i).pressed.connect(func(): action_requested.emit("hero", i))
		get_node("%%Reserve%d" % i).pressed.connect(func(): action_requested.emit("reserve", i))
		get_node("%%EquipHero%d" % i).pressed.connect(func(): action_requested.emit("hero", i))
	for i in range(5):
		get_node("%%Slot%d" % i).pressed.connect(func(): action_requested.emit("slot", i))
	for i in range(101, 104):
		get_node("%%Equip%d" % i).pressed.connect(func(): action_requested.emit("equip", i))
	%Battle.pressed.connect(func(): action_requested.emit("battle", 0))
	%Claim.pressed.connect(func(): action_requested.emit("claim", 0))
	%LevelUp.pressed.connect(func(): action_requested.emit("level", 0))
	%Unequip.pressed.connect(func(): action_requested.emit("equip", 0))
	%SaveFormation.pressed.connect(func(): action_requested.emit("save_formation", 0))
	%ModeSwitch.pressed.connect(func(): action_requested.emit("mode", 0))
	%Skip.pressed.connect(finish_battle)

func select_page(index: int) -> void:
	for i in range(_pages.size()):
		_pages[i].visible = i == index
		get_node("%%Tab%d" % i).set_pressed_no_signal(i == index)

func render(data: Dictionary) -> void:
	%Gold.text = data.gold
	%XP.text = data.xp
	%ModeLabel.text = data.mode_label
	%ModeSwitch.text = data.mode_action
	%Locale.select(data.locale_index)
	%StageTitle.text = data.stage_title
	%StageDescription.text = data.stage_description
	%StageReward.text = data.stage_reward
	%IdleAmount.text = data.idle
	%IdleHint.text = data.idle_hint
	var blocked: bool = data.busy or data.empty
	%Battle.disabled = blocked or _playing or data.complete
	%LevelUp.disabled = blocked
	%Claim.disabled = blocked
	%SaveFormation.disabled = blocked
	%Unequip.disabled = blocked
	%ModeSwitch.disabled = data.busy
	%Skip.visible = _playing
	for item in data.heroes:
		var card: Button = get_node("%%Hero%d" % item.id)
		card.set_pressed_no_signal(item.selected)
		card.get_node("Content/Name").text = item.name
		card.get_node("Content/Detail").text = item.caption
		card.get_node("Content/Portrait").texture = load("res://assets/hero_%d.svg" % item.id)
		get_node("%%EquipHero%d" % item.id).text = item.name
		get_node("%%EquipHero%d" % item.id).set_pressed_no_signal(item.selected)
		get_node("%%Reserve%d" % item.id).text = item.name
	%HeroName.text = data.hero_name
	%HeroDescription.text = data.hero_description
	%HeroStats.text = data.hero_stats
	%HeroSkill.text = data.hero_skill
	%HeroEquipment.text = data.hero_equipment
	%LevelCost.text = data.level_cost
	%EquipTarget.text = data.hero_name
	for i in range(5):
		get_node("%%Slot%d" % i).text = data.slots[i]
		get_node("%%Slot%d" % i).set_pressed_no_signal(data.slot == i)
		if not _playing:
			_set_actor(get_node("%%Ally%d" % i), data.allies[i], 100.0)
			_set_actor(get_node("%%Enemy%d" % i), data.enemies[i], 100.0)
	for item in data.equipment:
		get_node("%%EquipmentName%d" % item.id).text = item.name
		get_node("%%EquipmentDescription%d" % item.id).text = item.description
		get_node("%%EquipmentStats%d" % item.id).text = item.stats
		get_node("%%Equip%d" % item.id).disabled = blocked
	_battle_names = data.battle_names
	if _playing:
		for i in range(5):
			get_node("%%Ally%d" % i).get_node("Content/Name").text = _battle_names.ally[i]
			get_node("%%Enemy%d" % i).get_node("Content/Name").text = _battle_names.enemy[i]
		_render_event_text()

func _set_actor(actor: Control, data: Dictionary, health: float) -> void:
	actor.get_node("Content/Portrait").texture = load(data.portrait)
	actor.get_node("Content/Name").text = data.name
	actor.get_node("Content/Health").value = health
	actor.modulate = Color.WHITE

func show_status(message: String) -> void:
	%Status.text = message

func show_battle_log(message: String) -> void:
	%BattleLog.text = message

func play_battle(battle: Dictionary, names: Dictionary) -> void:
	_battle = battle
	_battle_names = names
	_battle_index = 0
	_battle_elapsed = 0.0
	_last_event = {}
	_playing = true
	%Skip.visible = true
	%Battle.disabled = true
	for side in ["allies", "enemies"]:
		for i in range(5):
			var fighter: Dictionary = battle[side][i]
			var actor: Control = get_node("%" + ("Ally" if side == "allies" else "Enemy") + str(i))
			actor.get_node("Content/Health").max_value = fighter.health
			actor.get_node("Content/Health").value = fighter.health
			actor.modulate = Color.WHITE
			actor.get_node("Content/Portrait").texture = load("res://assets/hero_%d.svg" % int(fighter.id) if side == "allies" else "res://assets/enemy.svg")

func cancel_battle() -> void:
	_playing = false
	_battle = {}
	_last_event = {}
	%Skip.visible = false
	for i in range(5):
		get_node("%%Ally%d" % i).get_node("Content/Health").max_value = 100
		get_node("%%Enemy%d" % i).get_node("Content/Health").max_value = 100

func finish_battle() -> void:
	if not _playing: return
	cancel_battle()
	battle_finished.emit()

func _process(delta: float) -> void:
	if not _playing: return
	_battle_elapsed += delta
	if _battle_elapsed < 0.09: return
	_battle_elapsed = 0.0
	if _battle_index >= _battle.events.size():
		finish_battle()
		return
	var event: Dictionary = _battle.events[_battle_index]
	_battle_index += 1
	_last_event = event
	var target: Control = get_node("%" + ("Enemy" if event.side == "ally" else "Ally") + str(int(event.target)))
	target.get_node("Content/Health").value = event.remaining
	if int(event.remaining) == 0: target.modulate = Color(0.4, 0.4, 0.4)
	else:
		target.modulate = Color(1.5, 0.8, 0.7)
		create_tween().tween_property(target, "modulate", Color.WHITE, 0.08)
	_render_event_text()

func _render_event_text() -> void:
	if _last_event.is_empty(): return
	var side: String = _last_event.side
	var other := "enemy" if side == "ally" else "ally"
	var actor: String = _battle_names[side][int(_last_event.actor)]
	var skill_id := int(_last_event.skill_id)
	if skill_id > 0: actor += " · " + str(_battle_names.skills.get(skill_id, ""))
	%BattleLog.text = tr("UI_HIT") % [actor, _battle_names[other][int(_last_event.target)], int(_last_event.damage)]
