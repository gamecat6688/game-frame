class_name AdventureService
extends RefCounted

var session: GameSession
var _config: GameData

func setup(config: GameData, authority: GameSession) -> void:
	_config = config
	session = authority

func hero(id: int) -> Dictionary:
	var definition = _config.get_model("Hero").get_row(id)
	if definition == null: return {}
	var state: Dictionary = {}
	var stats: Dictionary = {}
	for value in session.snapshot.get("heroes", []):
		if int(value.id) == id: state = value
	for value in session.snapshot.get("stats", []):
		if int(value.id) == id: stats = value
	var skill = _config.get_model("Skill").get_row(definition.SkillID)
	var level := int(state.get("level", 1))
	var rule = _config.get_model("Rules").get_row(1)
	return {"id": id, "name_key": definition.Name, "title_key": definition.Title, "role_key": definition.Role, "faction_key": definition.Faction,
		"description_key": definition.Description, "color": definition.PortraitColor, "skill_key": skill.Name, "skill_description_key": skill.Description,
		"level": level, "equipment": int(state.get("equipment", 0)), "attack": int(stats.get("attack", 0)), "health": int(stats.get("health", 0)),
		"defense": int(stats.get("defense", 0)), "level_gold": level * rule.LevelGold, "level_xp": level * rule.LevelExperience}

func stage(id: int) -> Dictionary:
	var row = _config.get_model("Stage").get_row(id)
	if row == null: return {}
	return {"id": id, "name_key": row.Name, "description_key": row.Description, "enemy_key": row.EnemyName, "gold": row.Gold, "xp": row.Experience}

func equipment(id: int) -> Dictionary:
	var row = _config.get_model("Equipment").get_row(id)
	if row == null: return {}
	var owner := 0
	for item in session.snapshot.get("heroes", []):
		if int(item.equipment) == id: owner = int(item.id)
	return {"id": id, "name_key": row.Name, "description_key": row.Description, "attack": row.Attack, "health": row.Health,
		"required_level": row.RequiredLevel, "owner": owner}

func skill_key(id: int) -> String:
	var row = _config.get_model("Skill").get_row(id)
	return "" if row == null else row.Name

func idle_cap_hours() -> int:
	return int(_config.get_model("Rules").get_row(1).IdleCapSeconds / 3600)

func stage_count() -> int:
	return _config.get_model("Stage").get_rows().size()
