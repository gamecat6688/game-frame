# Package: game_data

const GDScriptUtils = preload("res://addons/protobuf/proto/GDScriptUtils.gd")
const Message = preload("res://addons/protobuf/proto/Message.gd")
const Wire = preload("res://protobuf/runtime/wire.gd")

class RulesConfig extends Message:
	#1 : Records
	var _Records: Array[Rules] = []
	var _Records_size: int = 0
	## Size of _Records
	func Records_size() -> int:
		return self._Records_size
	## Get _Records
	func Records() -> Array[Rules]:
		return self._Records.slice(0, self._Records_size)
	## Get _Records item 
	func get_Records(index: int) -> Rules: # index begin from 1
		if index > 0 and index <= _Records_size and index <= _Records.size():
			return self._Records[index - 1]
		return null
	## Add _Records
	func add_Records(item: Rules) -> Rules:
		if self._Records_size >= 0 and self._Records_size < self._Records.size():
			self._Records[self._Records_size] = item
		else:
			self._Records.append(item)
		self._Records_size += 1
		return item
	## Append _Records
	func append_Records(item_array: Array):
		for item in item_array:
			if item is Rules:
				self.add_Records(item)
	## Clean _Records 
	func clear_Records() -> void:
		self._Records.clear()
		self._Records_size = 0


	## Init message field values to default value
	func Init() -> void:
		self.clear_Records()

	## Create a new message instance
	## Returns: Message - New message instance
	func New() -> Message:
		var msg = RulesConfig.new()
		return msg

	## Message ProtoName
	## Returns: String - ProtoName
	func ProtoName() -> String:
		return "game_data.RulesConfig"

	func MergeFrom(other : Message) -> void:
		if other is RulesConfig:
			self._Records = self._Records.slice(0, _Records_size)
			self._Records.append_array(other._Records.slice(0, other._Records_size))
			self._Records_size += other._Records_size
 
	func SerializeToBytes(buffer: PackedByteArray = PackedByteArray()) -> PackedByteArray:
		for item in self._Records:
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
					var sub__Records = Rules.new()
					var field_value = Wire.decode_message(data, pos, sub__Records)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.add_Records(field_value[GDScriptUtils.VALUE_KEY])
					pos += field_value[GDScriptUtils.SIZE_KEY]
				_:
					return -1

		return pos

	func SerializeToDictionary() -> Dictionary:
		var dict = {}
		dict["Records"] = []
		for index in range(1, self._Records_size + 1):
			var item = self.get_Records(index)
			dict["Records"].append(item.SerializeToDictionary())
		return dict

	func ParseFromDictionary(dict: Dictionary) -> void:
		if dict == null:
			return

		self.clear_Records()
		if dict.has("Records"):
			var list = dict["Records"]
			for item in list:
				var item_msg = Rules.new()
				item_msg.ParseFromDictionary(item)
				self.add_Records(item_msg)

# =========================================

class Rules extends Message:
	#1 : ID
	var ID: int = 0

	#2 : Version
	var Version: String = ""

	#3 : InitialGold
	var InitialGold: int = 0

	#4 : InitialExperience
	var InitialExperience: int = 0

	#5 : LevelGold
	var LevelGold: int = 0

	#6 : LevelExperience
	var LevelExperience: int = 0

	#7 : MaxLevel
	var MaxLevel: int = 0

	#8 : IdleGoldPerMinute
	var IdleGoldPerMinute: int = 0

	#9 : IdleExperiencePerMinute
	var IdleExperiencePerMinute: int = 0

	#10 : IdleCapSeconds
	var IdleCapSeconds: int = 0

	#11 : AttackPerLevel
	var AttackPerLevel: int = 0

	#12 : HealthPerLevel
	var HealthPerLevel: int = 0

	#13 : DefensePerLevel
	var DefensePerLevel: int = 0


	## Init message field values to default value
	func Init() -> void:
		self.ID = 0
		self.Version = ""
		self.InitialGold = 0
		self.InitialExperience = 0
		self.LevelGold = 0
		self.LevelExperience = 0
		self.MaxLevel = 0
		self.IdleGoldPerMinute = 0
		self.IdleExperiencePerMinute = 0
		self.IdleCapSeconds = 0
		self.AttackPerLevel = 0
		self.HealthPerLevel = 0
		self.DefensePerLevel = 0

	## Create a new message instance
	## Returns: Message - New message instance
	func New() -> Message:
		var msg = Rules.new()
		return msg

	## Message ProtoName
	## Returns: String - ProtoName
	func ProtoName() -> String:
		return "game_data.Rules"

	func MergeFrom(other : Message) -> void:
		if other is Rules:
			self.ID += other.ID
			self.Version += other.Version
			self.InitialGold += other.InitialGold
			self.InitialExperience += other.InitialExperience
			self.LevelGold += other.LevelGold
			self.LevelExperience += other.LevelExperience
			self.MaxLevel += other.MaxLevel
			self.IdleGoldPerMinute += other.IdleGoldPerMinute
			self.IdleExperiencePerMinute += other.IdleExperiencePerMinute
			self.IdleCapSeconds += other.IdleCapSeconds
			self.AttackPerLevel += other.AttackPerLevel
			self.HealthPerLevel += other.HealthPerLevel
			self.DefensePerLevel += other.DefensePerLevel
 
	func SerializeToBytes(buffer: PackedByteArray = PackedByteArray()) -> PackedByteArray:
		if self.ID != 0:
			GDScriptUtils.encode_tag(buffer, 1, 5)
			GDScriptUtils.encode_varint(buffer, self.ID)
		if self.Version != "":
			GDScriptUtils.encode_tag(buffer, 2, 9)
			GDScriptUtils.encode_string(buffer, self.Version)
		if self.InitialGold != 0:
			GDScriptUtils.encode_tag(buffer, 3, 5)
			GDScriptUtils.encode_varint(buffer, self.InitialGold)
		if self.InitialExperience != 0:
			GDScriptUtils.encode_tag(buffer, 4, 5)
			GDScriptUtils.encode_varint(buffer, self.InitialExperience)
		if self.LevelGold != 0:
			GDScriptUtils.encode_tag(buffer, 5, 5)
			GDScriptUtils.encode_varint(buffer, self.LevelGold)
		if self.LevelExperience != 0:
			GDScriptUtils.encode_tag(buffer, 6, 5)
			GDScriptUtils.encode_varint(buffer, self.LevelExperience)
		if self.MaxLevel != 0:
			GDScriptUtils.encode_tag(buffer, 7, 5)
			GDScriptUtils.encode_varint(buffer, self.MaxLevel)
		if self.IdleGoldPerMinute != 0:
			GDScriptUtils.encode_tag(buffer, 8, 5)
			GDScriptUtils.encode_varint(buffer, self.IdleGoldPerMinute)
		if self.IdleExperiencePerMinute != 0:
			GDScriptUtils.encode_tag(buffer, 9, 5)
			GDScriptUtils.encode_varint(buffer, self.IdleExperiencePerMinute)
		if self.IdleCapSeconds != 0:
			GDScriptUtils.encode_tag(buffer, 10, 5)
			GDScriptUtils.encode_varint(buffer, self.IdleCapSeconds)
		if self.AttackPerLevel != 0:
			GDScriptUtils.encode_tag(buffer, 11, 5)
			GDScriptUtils.encode_varint(buffer, self.AttackPerLevel)
		if self.HealthPerLevel != 0:
			GDScriptUtils.encode_tag(buffer, 12, 5)
			GDScriptUtils.encode_varint(buffer, self.HealthPerLevel)
		if self.DefensePerLevel != 0:
			GDScriptUtils.encode_tag(buffer, 13, 5)
			GDScriptUtils.encode_varint(buffer, self.DefensePerLevel)
		return buffer
 
	func ParseFromBytes(data: PackedByteArray) -> int:
		if not Wire.validate(data, {1: 0, 2: 2, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0, 8: 0, 9: 0, 10: 0, 11: 0, 12: 0, 13: 0}):
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
					self.ID = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				2:
					var field_value = GDScriptUtils.decode_string(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.Version = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				3:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.InitialGold = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				4:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.InitialExperience = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				5:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.LevelGold = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				6:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.LevelExperience = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				7:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.MaxLevel = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				8:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.IdleGoldPerMinute = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				9:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.IdleExperiencePerMinute = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				10:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.IdleCapSeconds = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				11:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.AttackPerLevel = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				12:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.HealthPerLevel = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				13:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.DefensePerLevel = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				_:
					return -1

		return pos

	func SerializeToDictionary() -> Dictionary:
		var dict = {}
		dict["ID"] = self.ID
		dict["Version"] = self.Version
		dict["InitialGold"] = self.InitialGold
		dict["InitialExperience"] = self.InitialExperience
		dict["LevelGold"] = self.LevelGold
		dict["LevelExperience"] = self.LevelExperience
		dict["MaxLevel"] = self.MaxLevel
		dict["IdleGoldPerMinute"] = self.IdleGoldPerMinute
		dict["IdleExperiencePerMinute"] = self.IdleExperiencePerMinute
		dict["IdleCapSeconds"] = self.IdleCapSeconds
		dict["AttackPerLevel"] = self.AttackPerLevel
		dict["HealthPerLevel"] = self.HealthPerLevel
		dict["DefensePerLevel"] = self.DefensePerLevel
		return dict

	func ParseFromDictionary(dict: Dictionary) -> void:
		if dict == null:
			return

		if dict.has("ID"):
			self.ID = dict.get("ID")
		if dict.has("Version"):
			self.Version = dict.get("Version")
		if dict.has("InitialGold"):
			self.InitialGold = dict.get("InitialGold")
		if dict.has("InitialExperience"):
			self.InitialExperience = dict.get("InitialExperience")
		if dict.has("LevelGold"):
			self.LevelGold = dict.get("LevelGold")
		if dict.has("LevelExperience"):
			self.LevelExperience = dict.get("LevelExperience")
		if dict.has("MaxLevel"):
			self.MaxLevel = dict.get("MaxLevel")
		if dict.has("IdleGoldPerMinute"):
			self.IdleGoldPerMinute = dict.get("IdleGoldPerMinute")
		if dict.has("IdleExperiencePerMinute"):
			self.IdleExperiencePerMinute = dict.get("IdleExperiencePerMinute")
		if dict.has("IdleCapSeconds"):
			self.IdleCapSeconds = dict.get("IdleCapSeconds")
		if dict.has("AttackPerLevel"):
			self.AttackPerLevel = dict.get("AttackPerLevel")
		if dict.has("HealthPerLevel"):
			self.HealthPerLevel = dict.get("HealthPerLevel")
		if dict.has("DefensePerLevel"):
			self.DefensePerLevel = dict.get("DefensePerLevel")

# =========================================

