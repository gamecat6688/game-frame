# Package: gameframe.protocol

const GDScriptUtils = preload("res://addons/protobuf/proto/GDScriptUtils.gd")
const Message = preload("res://addons/protobuf/proto/Message.gd")
const Wire = preload("res://protobuf/runtime/wire.gd")

class Command extends Message:
	#1 : protocol_version
	var protocol_version: int = 0

	#2 : id
	var id: String = ""

	#3 : type
	var type: String = ""

	#4 : expected_revision
	var expected_revision: int = 0

	#5 : hero_id
	var hero_id: int = 0

	#6 : equipment_id
	var equipment_id: int = 0

	#7 : formation
	var _formation: Array[int] = []
	var _formation_size: int = 0
	## Size of _formation
	func formation_size() -> int:
		return self._formation_size
	## Get _formation
	func formation() -> Array[int]:
		return self._formation.slice(0, self._formation_size)
	## Get _formation item 
	func get_formation(index: int) -> int: # index begin from 1
		if index > 0 and index <= _formation_size and index <= _formation.size():
			return self._formation[index - 1]
		return 0
	## Add _formation
	func add_formation(item: int) -> int:
		if self._formation_size >= 0 and self._formation_size < self._formation.size():
			self._formation[self._formation_size] = item
		else:
			self._formation.append(item)
		self._formation_size += 1
		return item
	## Append _formation
	func append_formation(item_array: Array):
		for item in item_array:
			if item is int:
				self.add_formation(item)
	## Clean _formation 
	func clear_formation() -> void:
		self._formation.clear()
		self._formation_size = 0


	## Init message field values to default value
	func Init() -> void:
		self.protocol_version = 0
		self.id = ""
		self.type = ""
		self.expected_revision = 0
		self.hero_id = 0
		self.equipment_id = 0
		self.clear_formation()

	## Create a new message instance
	## Returns: Message - New message instance
	func New() -> Message:
		var msg = Command.new()
		return msg

	## Message ProtoName
	## Returns: String - ProtoName
	func ProtoName() -> String:
		return "gameframe.protocol.Command"

	func MergeFrom(other : Message) -> void:
		if other is Command:
			self.protocol_version += other.protocol_version
			self.id += other.id
			self.type += other.type
			self.expected_revision += other.expected_revision
			self.hero_id += other.hero_id
			self.equipment_id += other.equipment_id
			self._formation = self._formation.slice(0, _formation_size)
			self._formation.append_array(other._formation.slice(0, other._formation_size))
			self._formation_size += other._formation_size
 
	func SerializeToBytes(buffer: PackedByteArray = PackedByteArray()) -> PackedByteArray:
		if self.protocol_version != 0:
			GDScriptUtils.encode_tag(buffer, 1, 5)
			GDScriptUtils.encode_varint(buffer, self.protocol_version)
		if self.id != "":
			GDScriptUtils.encode_tag(buffer, 2, 9)
			GDScriptUtils.encode_string(buffer, self.id)
		if self.type != "":
			GDScriptUtils.encode_tag(buffer, 3, 9)
			GDScriptUtils.encode_string(buffer, self.type)
		if self.expected_revision != 0:
			GDScriptUtils.encode_tag(buffer, 4, 3)
			GDScriptUtils.encode_varint(buffer, self.expected_revision)
		if self.hero_id != 0:
			GDScriptUtils.encode_tag(buffer, 5, 5)
			GDScriptUtils.encode_varint(buffer, self.hero_id)
		if self.equipment_id != 0:
			GDScriptUtils.encode_tag(buffer, 6, 5)
			GDScriptUtils.encode_varint(buffer, self.equipment_id)
		for item in self._formation:
			GDScriptUtils.encode_tag(buffer, 7, 5)
			GDScriptUtils.encode_varint(buffer, item)
		return buffer
 
	func ParseFromBytes(data: PackedByteArray) -> int:
		if not Wire.validate(data, {1: 0, 2: 2, 3: 2, 4: 0, 5: 0, 6: 0, 7: 0}):
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
					self.protocol_version = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				2:
					var field_value = GDScriptUtils.decode_string(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.id = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				3:
					var field_value = GDScriptUtils.decode_string(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.type = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				4:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.expected_revision = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				5:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.hero_id = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				6:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.equipment_id = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				7:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.add_formation(field_value[GDScriptUtils.VALUE_KEY])
					pos += field_value[GDScriptUtils.SIZE_KEY]
				_:
					return -1

		return pos

	func SerializeToDictionary() -> Dictionary:
		var dict = {}
		dict["protocol_version"] = self.protocol_version
		dict["id"] = self.id
		dict["type"] = self.type
		dict["expected_revision"] = self.expected_revision
		dict["hero_id"] = self.hero_id
		dict["equipment_id"] = self.equipment_id
		dict["formation"] = self._formation
		return dict

	func ParseFromDictionary(dict: Dictionary) -> void:
		if dict == null:
			return

		if dict.has("protocol_version"):
			self.protocol_version = dict.get("protocol_version")
		if dict.has("id"):
			self.id = dict.get("id")
		if dict.has("type"):
			self.type = dict.get("type")
		if dict.has("expected_revision"):
			self.expected_revision = dict.get("expected_revision")
		if dict.has("hero_id"):
			self.hero_id = dict.get("hero_id")
		if dict.has("equipment_id"):
			self.equipment_id = dict.get("equipment_id")
		self.clear_formation()
		if dict.has("formation"):
			var list = dict["formation"]
			for item in list:
				self.add_formation(item)

# =========================================

