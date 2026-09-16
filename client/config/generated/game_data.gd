class_name GameData
extends RefCounted

var models: Dictionary = {}


func load_all() -> bool:
	models.clear()
	if not _load_model("Equipment", EquipmentModel.new()):
		return false
	if not _load_model("Hero", HeroModel.new()):
		return false
	if not _load_model("I18N", I18NModel.new()):
		return false
	if not _load_model("Rules", RulesModel.new()):
		return false
	if not _load_model("Skill", SkillModel.new()):
		return false
	if not _load_model("Stage", StageModel.new()):
		return false
	return true


func _load_model(model_name: StringName, model) -> bool:
	if not model.load_data():
		return false
	models[model_name] = model
	return true


func get_model(model_name: StringName):
	return models.get(model_name)
