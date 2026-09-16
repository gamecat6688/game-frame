# Package: gameframe.protocol

const GDScriptUtils = preload("res://addons/protobuf/proto/GDScriptUtils.gd")
const Message = preload("res://addons/protobuf/proto/Message.gd")
const Wire = preload("res://protobuf/runtime/wire.gd")

class Fighter extends Message:
	#1 : id
	var id: int = 0

	#2 : attack
	var attack: int = 0

	#3 : health
	var health: int = 0

	#4 : defense
	var defense: int = 0

	#5 : skill_id
	var skill_id: int = 0


	## Init message field values to default value
	func Init() -> void:
		self.id = 0
		self.attack = 0
		self.health = 0
		self.defense = 0
		self.skill_id = 0

	## Create a new message instance
	## Returns: Message - New message instance
	func New() -> Message:
		var msg = Fighter.new()
		return msg

	## Message ProtoName
	## Returns: String - ProtoName
	func ProtoName() -> String:
		return "gameframe.protocol.Fighter"

	func MergeFrom(other : Message) -> void:
		if other is Fighter:
			self.id += other.id
			self.attack += other.attack
			self.health += other.health
			self.defense += other.defense
			self.skill_id += other.skill_id
 
	func SerializeToBytes(buffer: PackedByteArray = PackedByteArray()) -> PackedByteArray:
		if self.id != 0:
			GDScriptUtils.encode_tag(buffer, 1, 5)
			GDScriptUtils.encode_varint(buffer, self.id)
		if self.attack != 0:
			GDScriptUtils.encode_tag(buffer, 2, 3)
			GDScriptUtils.encode_varint(buffer, self.attack)
		if self.health != 0:
			GDScriptUtils.encode_tag(buffer, 3, 3)
			GDScriptUtils.encode_varint(buffer, self.health)
		if self.defense != 0:
			GDScriptUtils.encode_tag(buffer, 4, 3)
			GDScriptUtils.encode_varint(buffer, self.defense)
		if self.skill_id != 0:
			GDScriptUtils.encode_tag(buffer, 5, 5)
			GDScriptUtils.encode_varint(buffer, self.skill_id)
		return buffer
 
	func ParseFromBytes(data: PackedByteArray) -> int:
		if not Wire.validate(data, {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}):
			return -1

		var size = data.size()
		var pos = 0
 
		while pos < size:
			var tag = GDScriptUtils.decode_tag(data, pos)
			var field_number = tag[GDScriptUtils.VALUE_KEY]
			pos += tag[GDScriptUtils.SIZE_KEY]
 
			match field_number:
				1:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.id = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				2:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.attack = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				3:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.health = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				4:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.defense = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				5:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.skill_id = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				_:
					return -1

		return pos

	func SerializeToDictionary() -> Dictionary:
		var dict = {}
		dict["id"] = self.id
		dict["attack"] = self.attack
		dict["health"] = self.health
		dict["defense"] = self.defense
		dict["skill_id"] = self.skill_id
		return dict

	func ParseFromDictionary(dict: Dictionary) -> void:
		if dict == null:
			return

		if dict.has("id"):
			self.id = dict.get("id")
		if dict.has("attack"):
			self.attack = dict.get("attack")
		if dict.has("health"):
			self.health = dict.get("health")
		if dict.has("defense"):
			self.defense = dict.get("defense")
		if dict.has("skill_id"):
			self.skill_id = dict.get("skill_id")

# =========================================

class BattleEvent extends Message:
	#1 : side
	var side: String = ""

	#2 : actor
	var actor: int = 0

	#3 : target
	var target: int = 0

	#4 : damage
	var damage: int = 0

	#5 : remaining
	var remaining: int = 0

	#6 : skill_id
	var skill_id: int = 0


	## Init message field values to default value
	func Init() -> void:
		self.side = ""
		self.actor = 0
		self.target = 0
		self.damage = 0
		self.remaining = 0
		self.skill_id = 0

	## Create a new message instance
	## Returns: Message - New message instance
	func New() -> Message:
		var msg = BattleEvent.new()
		return msg

	## Message ProtoName
	## Returns: String - ProtoName
	func ProtoName() -> String:
		return "gameframe.protocol.BattleEvent"

	func MergeFrom(other : Message) -> void:
		if other is BattleEvent:
			self.side += other.side
			self.actor += other.actor
			self.target += other.target
			self.damage += other.damage
			self.remaining += other.remaining
			self.skill_id += other.skill_id
 
	func SerializeToBytes(buffer: PackedByteArray = PackedByteArray()) -> PackedByteArray:
		if self.side != "":
			GDScriptUtils.encode_tag(buffer, 1, 9)
			GDScriptUtils.encode_string(buffer, self.side)
		if self.actor != 0:
			GDScriptUtils.encode_tag(buffer, 2, 5)
			GDScriptUtils.encode_varint(buffer, self.actor)
		if self.target != 0:
			GDScriptUtils.encode_tag(buffer, 3, 5)
			GDScriptUtils.encode_varint(buffer, self.target)
		if self.damage != 0:
			GDScriptUtils.encode_tag(buffer, 4, 3)
			GDScriptUtils.encode_varint(buffer, self.damage)
		if self.remaining != 0:
			GDScriptUtils.encode_tag(buffer, 5, 3)
			GDScriptUtils.encode_varint(buffer, self.remaining)
		if self.skill_id != 0:
			GDScriptUtils.encode_tag(buffer, 6, 5)
			GDScriptUtils.encode_varint(buffer, self.skill_id)
		return buffer
 
	func ParseFromBytes(data: PackedByteArray) -> int:
		if not Wire.validate(data, {1: 2, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0}):
			return -1

		var size = data.size()
		var pos = 0
 
		while pos < size:
			var tag = GDScriptUtils.decode_tag(data, pos)
			var field_number = tag[GDScriptUtils.VALUE_KEY]
			pos += tag[GDScriptUtils.SIZE_KEY]
 
			match field_number:
				1:
					var field_value = GDScriptUtils.decode_string(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.side = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				2:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.actor = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				3:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.target = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				4:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.damage = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				5:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.remaining = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				6:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.skill_id = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				_:
					return -1

		return pos

	func SerializeToDictionary() -> Dictionary:
		var dict = {}
		dict["side"] = self.side
		dict["actor"] = self.actor
		dict["target"] = self.target
		dict["damage"] = self.damage
		dict["remaining"] = self.remaining
		dict["skill_id"] = self.skill_id
		return dict

	func ParseFromDictionary(dict: Dictionary) -> void:
		if dict == null:
			return

		if dict.has("side"):
			self.side = dict.get("side")
		if dict.has("actor"):
			self.actor = dict.get("actor")
		if dict.has("target"):
			self.target = dict.get("target")
		if dict.has("damage"):
			self.damage = dict.get("damage")
		if dict.has("remaining"):
			self.remaining = dict.get("remaining")
		if dict.has("skill_id"):
			self.skill_id = dict.get("skill_id")

# =========================================

class Battle extends Message:
	#1 : stage
	var stage: int = 0

	#2 : victory
	var victory: bool = false

	#3 : allies
	var _allies: Array[Fighter] = []
	var _allies_size: int = 0
	## Size of _allies
	func allies_size() -> int:
		return self._allies_size
	## Get _allies
	func allies() -> Array[Fighter]:
		return self._allies.slice(0, self._allies_size)
	## Get _allies item 
	func get_allies(index: int) -> Fighter: # index begin from 1
		if index > 0 and index <= _allies_size and index <= _allies.size():
			return self._allies[index - 1]
		return null
	## Add _allies
	func add_allies(item: Fighter) -> Fighter:
		if self._allies_size >= 0 and self._allies_size < self._allies.size():
			self._allies[self._allies_size] = item
		else:
			self._allies.append(item)
		self._allies_size += 1
		return item
	## Append _allies
	func append_allies(item_array: Array):
		for item in item_array:
			if item is Fighter:
				self.add_allies(item)
	## Clean _allies 
	func clear_allies() -> void:
		self._allies.clear()
		self._allies_size = 0

	#4 : enemies
	var _enemies: Array[Fighter] = []
	var _enemies_size: int = 0
	## Size of _enemies
	func enemies_size() -> int:
		return self._enemies_size
	## Get _enemies
	func enemies() -> Array[Fighter]:
		return self._enemies.slice(0, self._enemies_size)
	## Get _enemies item 
	func get_enemies(index: int) -> Fighter: # index begin from 1
		if index > 0 and index <= _enemies_size and index <= _enemies.size():
			return self._enemies[index - 1]
		return null
	## Add _enemies
	func add_enemies(item: Fighter) -> Fighter:
		if self._enemies_size >= 0 and self._enemies_size < self._enemies.size():
			self._enemies[self._enemies_size] = item
		else:
			self._enemies.append(item)
		self._enemies_size += 1
		return item
	## Append _enemies
	func append_enemies(item_array: Array):
		for item in item_array:
			if item is Fighter:
				self.add_enemies(item)
	## Clean _enemies 
	func clear_enemies() -> void:
		self._enemies.clear()
		self._enemies_size = 0

	#5 : events
	var _events: Array[BattleEvent] = []
	var _events_size: int = 0
	## Size of _events
	func events_size() -> int:
		return self._events_size
	## Get _events
	func events() -> Array[BattleEvent]:
		return self._events.slice(0, self._events_size)
	## Get _events item 
	func get_events(index: int) -> BattleEvent: # index begin from 1
		if index > 0 and index <= _events_size and index <= _events.size():
			return self._events[index - 1]
		return null
	## Add _events
	func add_events(item: BattleEvent) -> BattleEvent:
		if self._events_size >= 0 and self._events_size < self._events.size():
			self._events[self._events_size] = item
		else:
			self._events.append(item)
		self._events_size += 1
		return item
	## Append _events
	func append_events(item_array: Array):
		for item in item_array:
			if item is BattleEvent:
				self.add_events(item)
	## Clean _events 
	func clear_events() -> void:
		self._events.clear()
		self._events_size = 0

	#6 : gold
	var gold: int = 0

	#7 : experience
	var experience: int = 0


	## Init message field values to default value
	func Init() -> void:
		self.stage = 0
		self.victory = false
		self.clear_allies()
		self.clear_enemies()
		self.clear_events()
		self.gold = 0
		self.experience = 0

	## Create a new message instance
	## Returns: Message - New message instance
	func New() -> Message:
		var msg = Battle.new()
		return msg

	## Message ProtoName
	## Returns: String - ProtoName
	func ProtoName() -> String:
		return "gameframe.protocol.Battle"

	func MergeFrom(other : Message) -> void:
		if other is Battle:
			self.stage += other.stage
			self.victory = other.victory
			self._allies = self._allies.slice(0, _allies_size)
			self._allies.append_array(other._allies.slice(0, other._allies_size))
			self._allies_size += other._allies_size
			self._enemies = self._enemies.slice(0, _enemies_size)
			self._enemies.append_array(other._enemies.slice(0, other._enemies_size))
			self._enemies_size += other._enemies_size
			self._events = self._events.slice(0, _events_size)
			self._events.append_array(other._events.slice(0, other._events_size))
			self._events_size += other._events_size
			self.gold += other.gold
			self.experience += other.experience
 
	func SerializeToBytes(buffer: PackedByteArray = PackedByteArray()) -> PackedByteArray:
		if self.stage != 0:
			GDScriptUtils.encode_tag(buffer, 1, 5)
			GDScriptUtils.encode_varint(buffer, self.stage)
		if self.victory != false:
			GDScriptUtils.encode_tag(buffer, 2, 8)
			GDScriptUtils.encode_bool(buffer, self.victory)
		for item in self._allies:
			GDScriptUtils.encode_tag(buffer, 3, 11)
			GDScriptUtils.encode_message(buffer, item)
		for item in self._enemies:
			GDScriptUtils.encode_tag(buffer, 4, 11)
			GDScriptUtils.encode_message(buffer, item)
		for item in self._events:
			GDScriptUtils.encode_tag(buffer, 5, 11)
			GDScriptUtils.encode_message(buffer, item)
		if self.gold != 0:
			GDScriptUtils.encode_tag(buffer, 6, 3)
			GDScriptUtils.encode_varint(buffer, self.gold)
		if self.experience != 0:
			GDScriptUtils.encode_tag(buffer, 7, 3)
			GDScriptUtils.encode_varint(buffer, self.experience)
		return buffer
 
	func ParseFromBytes(data: PackedByteArray) -> int:
		if not Wire.validate(data, {1: 0, 2: 0, 3: 2, 4: 2, 5: 2, 6: 0, 7: 0}):
			return -1

		var size = data.size()
		var pos = 0
 
		while pos < size:
			var tag = GDScriptUtils.decode_tag(data, pos)
			var field_number = tag[GDScriptUtils.VALUE_KEY]
			pos += tag[GDScriptUtils.SIZE_KEY]
 
			match field_number:
				1:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.stage = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				2:
					var field_value = GDScriptUtils.decode_bool(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.victory = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				3:
					var sub__allies = Fighter.new()
					var field_value = Wire.decode_message(data, pos, sub__allies)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.add_allies(field_value[GDScriptUtils.VALUE_KEY])
					pos += field_value[GDScriptUtils.SIZE_KEY]
				4:
					var sub__enemies = Fighter.new()
					var field_value = Wire.decode_message(data, pos, sub__enemies)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.add_enemies(field_value[GDScriptUtils.VALUE_KEY])
					pos += field_value[GDScriptUtils.SIZE_KEY]
				5:
					var sub__events = BattleEvent.new()
					var field_value = Wire.decode_message(data, pos, sub__events)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.add_events(field_value[GDScriptUtils.VALUE_KEY])
					pos += field_value[GDScriptUtils.SIZE_KEY]
				6:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.gold = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				7:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.experience = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				_:
					return -1

		return pos

	func SerializeToDictionary() -> Dictionary:
		var dict = {}
		dict["stage"] = self.stage
		dict["victory"] = self.victory
		dict["allies"] = []
		for index in range(1, self._allies_size + 1):
			var item = self.get_allies(index)
			dict["allies"].append(item.SerializeToDictionary())
		dict["enemies"] = []
		for index in range(1, self._enemies_size + 1):
			var item = self.get_enemies(index)
			dict["enemies"].append(item.SerializeToDictionary())
		dict["events"] = []
		for index in range(1, self._events_size + 1):
			var item = self.get_events(index)
			dict["events"].append(item.SerializeToDictionary())
		dict["gold"] = self.gold
		dict["experience"] = self.experience
		return dict

	func ParseFromDictionary(dict: Dictionary) -> void:
		if dict == null:
			return

		if dict.has("stage"):
			self.stage = dict.get("stage")
		if dict.has("victory"):
			self.victory = dict.get("victory")
		self.clear_allies()
		if dict.has("allies"):
			var list = dict["allies"]
			for item in list:
				var item_msg = Fighter.new()
				item_msg.ParseFromDictionary(item)
				self.add_allies(item_msg)
		self.clear_enemies()
		if dict.has("enemies"):
			var list = dict["enemies"]
			for item in list:
				var item_msg = Fighter.new()
				item_msg.ParseFromDictionary(item)
				self.add_enemies(item_msg)
		self.clear_events()
		if dict.has("events"):
			var list = dict["events"]
			for item in list:
				var item_msg = BattleEvent.new()
				item_msg.ParseFromDictionary(item)
				self.add_events(item_msg)
		if dict.has("gold"):
			self.gold = dict.get("gold")
		if dict.has("experience"):
			self.experience = dict.get("experience")

# =========================================

