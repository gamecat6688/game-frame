# Package: game_data

const GDScriptUtils = preload("res://addons/protobuf/proto/GDScriptUtils.gd")
const Message = preload("res://addons/protobuf/proto/Message.gd")
const Wire = preload("res://protobuf/runtime/wire.gd")

class I18NConfig extends Message:
	#1 : Records
	var _Records: Array[I18N] = []
	var _Records_size: int = 0
	## Size of _Records
	func Records_size() -> int:
		return self._Records_size
	## Get _Records
	func Records() -> Array[I18N]:
		return self._Records.slice(0, self._Records_size)
	## Get _Records item 
	func get_Records(index: int) -> I18N: # index begin from 1
		if index > 0 and index <= _Records_size and index <= _Records.size():
			return self._Records[index - 1]
		return null
	## Add _Records
	func add_Records(item: I18N) -> I18N:
		if self._Records_size >= 0 and self._Records_size < self._Records.size():
			self._Records[self._Records_size] = item
		else:
			self._Records.append(item)
		self._Records_size += 1
		return item
	## Append _Records
	func append_Records(item_array: Array):
		for item in item_array:
			if item is I18N:
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
		var msg = I18NConfig.new()
		return msg

	## Message ProtoName
	## Returns: String - ProtoName
	func ProtoName() -> String:
		return "game_data.I18NConfig"

	func MergeFrom(other : Message) -> void:
		if other is I18NConfig:
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
					var sub__Records = I18N.new()
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
				var item_msg = I18N.new()
				item_msg.ParseFromDictionary(item)
				self.add_Records(item_msg)

# =========================================

class I18N extends Message:
	#1 : ID
	var ID: String = ""

	#2 : Cn
	var Cn: String = ""

	#3 : Tn
	var Tn: String = ""

	#4 : En
	var En: String = ""


	## Init message field values to default value
	func Init() -> void:
		self.ID = ""
		self.Cn = ""
		self.Tn = ""
		self.En = ""

	## Create a new message instance
	## Returns: Message - New message instance
	func New() -> Message:
		var msg = I18N.new()
		return msg

	## Message ProtoName
	## Returns: String - ProtoName
	func ProtoName() -> String:
		return "game_data.I18N"

	func MergeFrom(other : Message) -> void:
		if other is I18N:
			self.ID += other.ID
			self.Cn += other.Cn
			self.Tn += other.Tn
			self.En += other.En
 
	func SerializeToBytes(buffer: PackedByteArray = PackedByteArray()) -> PackedByteArray:
		if self.ID != "":
			GDScriptUtils.encode_tag(buffer, 1, 9)
			GDScriptUtils.encode_string(buffer, self.ID)
		if self.Cn != "":
			GDScriptUtils.encode_tag(buffer, 2, 9)
			GDScriptUtils.encode_string(buffer, self.Cn)
		if self.Tn != "":
			GDScriptUtils.encode_tag(buffer, 3, 9)
			GDScriptUtils.encode_string(buffer, self.Tn)
		if self.En != "":
			GDScriptUtils.encode_tag(buffer, 4, 9)
			GDScriptUtils.encode_string(buffer, self.En)
		return buffer
 
	func ParseFromBytes(data: PackedByteArray) -> int:
		if not Wire.validate(data, {1: 2, 2: 2, 3: 2, 4: 2}):
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
					self.ID = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				2:
					var field_value = GDScriptUtils.decode_string(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.Cn = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				3:
					var field_value = GDScriptUtils.decode_string(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.Tn = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				4:
					var field_value = GDScriptUtils.decode_string(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.En = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				_:
					return -1

		return pos

	func SerializeToDictionary() -> Dictionary:
		var dict = {}
		dict["ID"] = self.ID
		dict["Cn"] = self.Cn
		dict["Tn"] = self.Tn
		dict["En"] = self.En
		return dict

	func ParseFromDictionary(dict: Dictionary) -> void:
		if dict == null:
			return

		if dict.has("ID"):
			self.ID = dict.get("ID")
		if dict.has("Cn"):
			self.Cn = dict.get("Cn")
		if dict.has("Tn"):
			self.Tn = dict.get("Tn")
		if dict.has("En"):
			self.En = dict.get("En")

# =========================================

