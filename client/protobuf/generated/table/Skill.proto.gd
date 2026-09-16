# Package: game_data

const GDScriptUtils = preload("res://addons/protobuf/proto/GDScriptUtils.gd")
const Message = preload("res://addons/protobuf/proto/Message.gd")
const Wire = preload("res://protobuf/runtime/wire.gd")

class SkillConfig extends Message:
	#1 : Records
	var _Records: Array[Skill] = []
	var _Records_size: int = 0
	## Size of _Records
	func Records_size() -> int:
		return self._Records_size
	## Get _Records
	func Records() -> Array[Skill]:
		return self._Records.slice(0, self._Records_size)
	## Get _Records item 
	func get_Records(index: int) -> Skill: # index begin from 1
		if index > 0 and index <= _Records_size and index <= _Records.size():
			return self._Records[index - 1]
		return null
	## Add _Records
	func add_Records(item: Skill) -> Skill:
		if self._Records_size >= 0 and self._Records_size < self._Records.size():
			self._Records[self._Records_size] = item
		else:
			self._Records.append(item)
		self._Records_size += 1
		return item
	## Append _Records
	func append_Records(item_array: Array):
		for item in item_array:
			if item is Skill:
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
		var msg = SkillConfig.new()
		return msg

	## Message ProtoName
	## Returns: String - ProtoName
	func ProtoName() -> String:
		return "game_data.SkillConfig"

	func MergeFrom(other : Message) -> void:
		if other is SkillConfig:
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
					var sub__Records = Skill.new()
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
				var item_msg = Skill.new()
				item_msg.ParseFromDictionary(item)
				self.add_Records(item_msg)

# =========================================

class Skill extends Message:
	#1 : ID
	var ID: int = 0

	#2 : Name
	var Name: String = ""

	#3 : Description
	var Description: String = ""

	#4 : Multiplier
	var Multiplier: int = 0

	#5 : Every
	var Every: int = 0


	## Init message field values to default value
	func Init() -> void:
		self.ID = 0
		self.Name = ""
		self.Description = ""
		self.Multiplier = 0
		self.Every = 0

	## Create a new message instance
	## Returns: Message - New message instance
	func New() -> Message:
		var msg = Skill.new()
		return msg

	## Message ProtoName
	## Returns: String - ProtoName
	func ProtoName() -> String:
		return "game_data.Skill"

	func MergeFrom(other : Message) -> void:
		if other is Skill:
			self.ID += other.ID
			self.Name += other.Name
			self.Description += other.Description
			self.Multiplier += other.Multiplier
			self.Every += other.Every
 
	func SerializeToBytes(buffer: PackedByteArray = PackedByteArray()) -> PackedByteArray:
		if self.ID != 0:
			GDScriptUtils.encode_tag(buffer, 1, 5)
			GDScriptUtils.encode_varint(buffer, self.ID)
		if self.Name != "":
			GDScriptUtils.encode_tag(buffer, 2, 9)
			GDScriptUtils.encode_string(buffer, self.Name)
		if self.Description != "":
			GDScriptUtils.encode_tag(buffer, 3, 9)
			GDScriptUtils.encode_string(buffer, self.Description)
		if self.Multiplier != 0:
			GDScriptUtils.encode_tag(buffer, 4, 5)
			GDScriptUtils.encode_varint(buffer, self.Multiplier)
		if self.Every != 0:
			GDScriptUtils.encode_tag(buffer, 5, 5)
			GDScriptUtils.encode_varint(buffer, self.Every)
		return buffer
 
	func ParseFromBytes(data: PackedByteArray) -> int:
		if not Wire.validate(data, {1: 0, 2: 2, 3: 2, 4: 0, 5: 0}):
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
					self.Name = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				3:
					var field_value = GDScriptUtils.decode_string(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.Description = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				4:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.Multiplier = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				5:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.Every = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				_:
					return -1

		return pos

	func SerializeToDictionary() -> Dictionary:
		var dict = {}
		dict["ID"] = self.ID
		dict["Name"] = self.Name
		dict["Description"] = self.Description
		dict["Multiplier"] = self.Multiplier
		dict["Every"] = self.Every
		return dict

	func ParseFromDictionary(dict: Dictionary) -> void:
		if dict == null:
			return

		if dict.has("ID"):
			self.ID = dict.get("ID")
		if dict.has("Name"):
			self.Name = dict.get("Name")
		if dict.has("Description"):
			self.Description = dict.get("Description")
		if dict.has("Multiplier"):
			self.Multiplier = dict.get("Multiplier")
		if dict.has("Every"):
			self.Every = dict.get("Every")

# =========================================

