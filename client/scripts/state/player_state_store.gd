class_name PlayerStateStore
extends RefCounted

signal modules_changed(modules: PackedStringArray)
const MODULES := ["wallet", "heroes", "equipment", "formation", "campaign", "idle"]
var snapshot: Dictionary = {}
var _modules: Dictionary = {}

func clear() -> void:
	snapshot = {}
	_modules = {}

func apply_response(response: Dictionary) -> String:
	if not response.has("update"): return "none"
	var update: Dictionary = response.update
	var revision := int(update.get("revision", 0))
	var current := int(snapshot.get("revision", 0))
	var full := true
	var idle_only: bool = update.has("idle") and response.get("notifications", []).is_empty()
	for module in MODULES:
		if not update.has(module):
			full = false
		elif not update[module] is Dictionary:
			return "invalid"
		elif module != "idle":
			idle_only = false
	if revision < 1: return "invalid"
	if revision < current: return "ignored"
	if not full:
		if snapshot.is_empty() or revision > current + 1: return "resync"
		if revision == current and not idle_only:
			return "ignored" # Already applied receipt; do not re-emit item changes.
	if revision == current and int(update.get("server_time", 0)) < int(snapshot.get("server_time", 0)):
		return "ignored"
	var candidate: Dictionary = {} if full else _modules.duplicate(true)
	for module in MODULES:
		if update.has(module): candidate[module] = update[module].duplicate(true)
	# Notifications are applied atomically with their enclosing state update.
	for notification in response.get("notifications", []):
		if not notification.has("equipment"): return "invalid"
		if full or update.has("equipment") or not candidate.has("equipment"): return "invalid"
		var items := {}
		for item in candidate.equipment.items: items[int(item.id)] = item.duplicate(true)
		var touched := {}
		for item in notification.equipment.get("upsert", []):
			var id := int(item.id)
			if id <= 0 or touched.has(id): return "invalid"
			touched[id] = true
			items[id] = item.duplicate(true)
		for value in notification.equipment.get("deleted_ids", []):
			var id := int(value)
			if id <= 0 or touched.has(id): return "invalid"
			touched[id] = true
			items.erase(id)
		var keys := items.keys()
		keys.sort()
		candidate.equipment.items = []
		for id in keys: candidate.equipment.items.append(items[id])
	for module in MODULES:
		if not candidate.has(module): return "resync"
	var changed := PackedStringArray()
	for module in MODULES:
		if candidate[module] != _modules.get(module): changed.append(module)
	var next := {
		"revision": revision, "config_version": str(update.config_version), "server_time": int(update.server_time),
		"gold": int(candidate.wallet.gold), "experience": int(candidate.wallet.experience),
		"stage": int(candidate.campaign.stage), "formation": candidate.formation.slots.duplicate(),
		"idle_gold": int(candidate.idle.gold), "idle_experience": int(candidate.idle.experience),
		"heroes": [], "stats": [], "equipment": [], "equipment_owners": {}}
	for hero in candidate.heroes.heroes:
		next.heroes.append({"id": int(hero.id), "level": int(hero.level), "equipment": int(hero.equipment)})
		next.stats.append({"id": int(hero.id), "attack": int(hero.attack), "health": int(hero.health), "defense": int(hero.defense), "skill_id": int(hero.skill_id)})
	for item in candidate.equipment.items:
		next.equipment.append(int(item.id))
		next.equipment_owners[int(item.id)] = int(item.hero_id)
	_modules = candidate
	snapshot = next
	if not changed.is_empty(): modules_changed.emit(changed)
	return "applied"
