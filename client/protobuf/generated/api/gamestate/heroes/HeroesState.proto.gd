# Package: gameframe.protocol

const GDScriptUtils = preload("res://addons/protobuf/proto/GDScriptUtils.gd")
const Message = preload("res://addons/protobuf/proto/Message.gd")
const Wire = preload("res://protobuf/runtime/wire.gd")

class HeroState extends Message:
	#1 : id
	var id: int = 0

	#2 : level
	var level: int = 0

	#3 : equipment
	var equipment: int = 0

	#4 : attack
	var attack: int = 0

	#5 : health
	var health: int = 0

	#6 : defense
	var defense: int = 0

	#7 : skill_id
	var skill_id: int = 0


	## Init message field values to default value
	func Init() -> void:
		self.id = 0
		self.level = 0
		self.equipment = 0
		self.attack = 0
		self.health = 0
		self.defense = 0
		self.skill_id = 0

	## Create a new message instance
	## Returns: Message - New message instance
	func New() -> Message:
		var msg = HeroState.new()
		return msg

	## Message ProtoName
	## Returns: String - ProtoName
	func ProtoName() -> String:
		return "gameframe.protocol.HeroState"

	func MergeFrom(other : Message) -> void:
		if other is HeroState:
			self.id += other.id
			self.level += other.level
			self.equipment += other.equipment
			self.attack += other.attack
			self.health += other.health
			self.defense += other.defense
			self.skill_id += other.skill_id
 
	func SerializeToBytes(buffer: PackedByteArray = PackedByteArray()) -> PackedByteArray:
		if self.id != 0:
			GDScriptUtils.encode_tag(buffer, 1, 5)
			GDScriptUtils.encode_varint(buffer, self.id)
		if self.level != 0:
			GDScriptUtils.encode_tag(buffer, 2, 5)
			GDScriptUtils.encode_varint(buffer, self.level)
		if self.equipment != 0:
			GDScriptUtils.encode_tag(buffer, 3, 5)
			GDScriptUtils.encode_varint(buffer, self.equipment)
		if self.attack != 0:
			GDScriptUtils.encode_tag(buffer, 4, 3)
			GDScriptUtils.encode_varint(buffer, self.attack)
		if self.health != 0:
			GDScriptUtils.encode_tag(buffer, 5, 3)
			GDScriptUtils.encode_varint(buffer, self.health)
		if self.defense != 0:
			GDScriptUtils.encode_tag(buffer, 6, 3)
			GDScriptUtils.encode_varint(buffer, self.defense)
		if self.skill_id != 0:
			GDScriptUtils.encode_tag(buffer, 7, 5)
			GDScriptUtils.encode_varint(buffer, self.skill_id)
		return buffer
 
	func ParseFromBytes(data: PackedByteArray) -> int:
		if not Wire.validate(data, {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0}):
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
					self.level = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				3:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.equipment = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				4:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.attack = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				5:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.health = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				6:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.defense = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				7:
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
		dict["level"] = self.level
		dict["equipment"] = self.equipment
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
		if dict.has("level"):
			self.level = dict.get("level")
		if dict.has("equipment"):
			self.equipment = dict.get("equipment")
		if dict.has("attack"):
			self.attack = dict.get("attack")
		if dict.has("health"):
			self.health = dict.get("health")
		if dict.has("defense"):
			self.defense = dict.get("defense")
		if dict.has("skill_id"):
			self.skill_id = dict.get("skill_id")

# =========================================

class HeroesState extends Message:
	#1 : heroes
	var _heroes: Array[HeroState] = []
	var _heroes_size: int = 0
	## Size of _heroes
	func heroes_size() -> int:
		return self._heroes_size
	## Get _heroes
	func heroes() -> Array[HeroState]:
		return self._heroes.slice(0, self._heroes_size)
	## Get _heroes item 
	func get_heroes(index: int) -> HeroState: # index begin from 1
		if index > 0 and index <= _heroes_size and index <= _heroes.size():
			return self._heroes[index - 1]
		return null
	## Add _heroes
	func add_heroes(item: HeroState) -> HeroState:
		if self._heroes_size >= 0 and self._heroes_size < self._heroes.size():
			self._heroes[self._heroes_size] = item
		else:
			self._heroes.append(item)
		self._heroes_size += 1
		return item
	## Append _heroes
	func append_heroes(item_array: Array):
		for item in item_array:
			if item is HeroState:
				self.add_heroes(item)
	## Clean _heroes 
	func clear_heroes() -> void:
		self._heroes.clear()
		self._heroes_size = 0


	## Init message field values to default value
	func Init() -> void:
		self.clear_heroes()

	## Create a new message instance
	## Returns: Message - New message instance
	func New() -> Message:
		var msg = HeroesState.new()
		return msg

	## Message ProtoName
	## Returns: String - ProtoName
	func ProtoName() -> String:
		return "gameframe.protocol.HeroesState"

	func MergeFrom(other : Message) -> void:
		if other is HeroesState:
			self._heroes = self._heroes.slice(0, _heroes_size)
			self._heroes.append_array(other._heroes.slice(0, other._heroes_size))
			self._heroes_size += other._heroes_size
 
	func SerializeToBytes(buffer: PackedByteArray = PackedByteArray()) -> PackedByteArray:
		for item in self._heroes:
			GDScriptUtils.encode_tag(buffer, 1, 11)
			GDScriptUtils.encode_message(buffer, item)
		return buffer
 
	func ParseFromBytes(data: PackedByteArray) -> int:
		if not Wire.validate(data, {1: 2}):
			return -1

		var size = data.size()
		var pos = 0
 
		while pos < size:
			var tag = GDScriptUtils.decode_tag(data, pos)
			var field_number = tag[GDScriptUtils.VALUE_KEY]
			pos += tag[GDScriptUtils.SIZE_KEY]
 
			match field_number:
				1:
					var sub__heroes = HeroState.new()
					var field_value = Wire.decode_message(data, pos, sub__heroes)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.add_heroes(field_value[GDScriptUtils.VALUE_KEY])
					pos += field_value[GDScriptUtils.SIZE_KEY]
				_:
					return -1

		return pos

	func SerializeToDictionary() -> Dictionary:
		var dict = {}
		dict["heroes"] = []
		for index in range(1, self._heroes_size + 1):
			var item = self.get_heroes(index)
			dict["heroes"].append(item.SerializeToDictionary())
		return dict

	func ParseFromDictionary(dict: Dictionary) -> void:
		if dict == null:
			return

		self.clear_heroes()
		if dict.has("heroes"):
			var list = dict["heroes"]
			for item in list:
				var item_msg = HeroState.new()
				item_msg.ParseFromDictionary(item)
				self.add_heroes(item_msg)

# =========================================

