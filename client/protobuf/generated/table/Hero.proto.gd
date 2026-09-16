# Package: game_data

const GDScriptUtils = preload("res://addons/protobuf/proto/GDScriptUtils.gd")
const Message = preload("res://addons/protobuf/proto/Message.gd")
const Wire = preload("res://protobuf/runtime/wire.gd")

class HeroConfig extends Message:
	#1 : Records
	var _Records: Array[Hero] = []
	var _Records_size: int = 0
	## Size of _Records
	func Records_size() -> int:
		return self._Records_size
	## Get _Records
	func Records() -> Array[Hero]:
		return self._Records.slice(0, self._Records_size)
	## Get _Records item 
	func get_Records(index: int) -> Hero: # index begin from 1
		if index > 0 and index <= _Records_size and index <= _Records.size():
			return self._Records[index - 1]
		return null
	## Add _Records
	func add_Records(item: Hero) -> Hero:
		if self._Records_size >= 0 and self._Records_size < self._Records.size():
			self._Records[self._Records_size] = item
		else:
			self._Records.append(item)
		self._Records_size += 1
		return item
	## Append _Records
	func append_Records(item_array: Array):
		for item in item_array:
			if item is Hero:
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
		var msg = HeroConfig.new()
		return msg

	## Message ProtoName
	## Returns: String - ProtoName
	func ProtoName() -> String:
		return "game_data.HeroConfig"

	func MergeFrom(other : Message) -> void:
		if other is HeroConfig:
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
					var sub__Records = Hero.new()
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
				var item_msg = Hero.new()
				item_msg.ParseFromDictionary(item)
				self.add_Records(item_msg)

# =========================================

class Hero extends Message:
	#1 : ID
	var ID: int = 0

	#2 : Name
	var Name: String = ""

	#3 : Title
	var Title: String = ""

	#4 : Faction
	var Faction: String = ""

	#5 : Role
	var Role: String = ""

	#6 : Description
	var Description: String = ""

	#7 : Attack
	var Attack: int = 0

	#8 : Health
	var Health: int = 0

	#9 : Defense
	var Defense: int = 0

	#10 : SkillID
	var SkillID: int = 0

	#11 : PortraitColor
	var PortraitColor: String = ""


	## Init message field values to default value
	func Init() -> void:
		self.ID = 0
		self.Name = ""
		self.Title = ""
		self.Faction = ""
		self.Role = ""
		self.Description = ""
		self.Attack = 0
		self.Health = 0
		self.Defense = 0
		self.SkillID = 0
		self.PortraitColor = ""

	## Create a new message instance
	## Returns: Message - New message instance
	func New() -> Message:
		var msg = Hero.new()
		return msg

	## Message ProtoName
	## Returns: String - ProtoName
	func ProtoName() -> String:
		return "game_data.Hero"

	func MergeFrom(other : Message) -> void:
		if other is Hero:
			self.ID += other.ID
			self.Name += other.Name
			self.Title += other.Title
			self.Faction += other.Faction
			self.Role += other.Role
			self.Description += other.Description
			self.Attack += other.Attack
			self.Health += other.Health
			self.Defense += other.Defense
			self.SkillID += other.SkillID
			self.PortraitColor += other.PortraitColor
 
	func SerializeToBytes(buffer: PackedByteArray = PackedByteArray()) -> PackedByteArray:
		if self.ID != 0:
			GDScriptUtils.encode_tag(buffer, 1, 5)
			GDScriptUtils.encode_varint(buffer, self.ID)
		if self.Name != "":
			GDScriptUtils.encode_tag(buffer, 2, 9)
			GDScriptUtils.encode_string(buffer, self.Name)
		if self.Title != "":
			GDScriptUtils.encode_tag(buffer, 3, 9)
			GDScriptUtils.encode_string(buffer, self.Title)
		if self.Faction != "":
			GDScriptUtils.encode_tag(buffer, 4, 9)
			GDScriptUtils.encode_string(buffer, self.Faction)
		if self.Role != "":
			GDScriptUtils.encode_tag(buffer, 5, 9)
			GDScriptUtils.encode_string(buffer, self.Role)
		if self.Description != "":
			GDScriptUtils.encode_tag(buffer, 6, 9)
			GDScriptUtils.encode_string(buffer, self.Description)
		if self.Attack != 0:
			GDScriptUtils.encode_tag(buffer, 7, 5)
			GDScriptUtils.encode_varint(buffer, self.Attack)
		if self.Health != 0:
			GDScriptUtils.encode_tag(buffer, 8, 5)
			GDScriptUtils.encode_varint(buffer, self.Health)
		if self.Defense != 0:
			GDScriptUtils.encode_tag(buffer, 9, 5)
			GDScriptUtils.encode_varint(buffer, self.Defense)
		if self.SkillID != 0:
			GDScriptUtils.encode_tag(buffer, 10, 5)
			GDScriptUtils.encode_varint(buffer, self.SkillID)
		if self.PortraitColor != "":
			GDScriptUtils.encode_tag(buffer, 11, 9)
			GDScriptUtils.encode_string(buffer, self.PortraitColor)
		return buffer
 
	func ParseFromBytes(data: PackedByteArray) -> int:
		if not Wire.validate(data, {1: 0, 2: 2, 3: 2, 4: 2, 5: 2, 6: 2, 7: 0, 8: 0, 9: 0, 10: 0, 11: 2}):
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
					self.Title = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				4:
					var field_value = GDScriptUtils.decode_string(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.Faction = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				5:
					var field_value = GDScriptUtils.decode_string(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.Role = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				6:
					var field_value = GDScriptUtils.decode_string(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.Description = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				7:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.Attack = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				8:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.Health = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				9:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.Defense = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				10:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.SkillID = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				11:
					var field_value = GDScriptUtils.decode_string(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.PortraitColor = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				_:
					return -1

		return pos

	func SerializeToDictionary() -> Dictionary:
		var dict = {}
		dict["ID"] = self.ID
		dict["Name"] = self.Name
		dict["Title"] = self.Title
		dict["Faction"] = self.Faction
		dict["Role"] = self.Role
		dict["Description"] = self.Description
		dict["Attack"] = self.Attack
		dict["Health"] = self.Health
		dict["Defense"] = self.Defense
		dict["SkillID"] = self.SkillID
		dict["PortraitColor"] = self.PortraitColor
		return dict

	func ParseFromDictionary(dict: Dictionary) -> void:
		if dict == null:
			return

		if dict.has("ID"):
			self.ID = dict.get("ID")
		if dict.has("Name"):
			self.Name = dict.get("Name")
		if dict.has("Title"):
			self.Title = dict.get("Title")
		if dict.has("Faction"):
			self.Faction = dict.get("Faction")
		if dict.has("Role"):
			self.Role = dict.get("Role")
		if dict.has("Description"):
			self.Description = dict.get("Description")
		if dict.has("Attack"):
			self.Attack = dict.get("Attack")
		if dict.has("Health"):
			self.Health = dict.get("Health")
		if dict.has("Defense"):
			self.Defense = dict.get("Defense")
		if dict.has("SkillID"):
			self.SkillID = dict.get("SkillID")
		if dict.has("PortraitColor"):
			self.PortraitColor = dict.get("PortraitColor")

# =========================================

