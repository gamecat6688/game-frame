# Package: gameframe.protocol

const GDScriptUtils = preload("res://addons/protobuf/proto/GDScriptUtils.gd")
const Message = preload("res://addons/protobuf/proto/Message.gd")
const Wire = preload("res://protobuf/runtime/wire.gd")

class EquipmentItem extends Message:
	#1 : id
	var id: int = 0

	#2 : hero_id
	var hero_id: int = 0


	## Init message field values to default value
	func Init() -> void:
		self.id = 0
		self.hero_id = 0

	## Create a new message instance
	## Returns: Message - New message instance
	func New() -> Message:
		var msg = EquipmentItem.new()
		return msg

	## Message ProtoName
	## Returns: String - ProtoName
	func ProtoName() -> String:
		return "gameframe.protocol.EquipmentItem"

	func MergeFrom(other : Message) -> void:
		if other is EquipmentItem:
			self.id += other.id
			self.hero_id += other.hero_id
 
	func SerializeToBytes(buffer: PackedByteArray = PackedByteArray()) -> PackedByteArray:
		if self.id != 0:
			GDScriptUtils.encode_tag(buffer, 1, 5)
			GDScriptUtils.encode_varint(buffer, self.id)
		if self.hero_id != 0:
			GDScriptUtils.encode_tag(buffer, 2, 5)
			GDScriptUtils.encode_varint(buffer, self.hero_id)
		return buffer
 
	func ParseFromBytes(data: PackedByteArray) -> int:
		if not Wire.validate(data, {1: 0, 2: 0}):
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
					self.hero_id = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				_:
					return -1

		return pos

	func SerializeToDictionary() -> Dictionary:
		var dict = {}
		dict["id"] = self.id
		dict["hero_id"] = self.hero_id
		return dict

	func ParseFromDictionary(dict: Dictionary) -> void:
		if dict == null:
			return

		if dict.has("id"):
			self.id = dict.get("id")
		if dict.has("hero_id"):
			self.hero_id = dict.get("hero_id")

# =========================================

class EquipmentState extends Message:
	#1 : items
	var _items: Array[EquipmentItem] = []
	var _items_size: int = 0
	## Size of _items
	func items_size() -> int:
		return self._items_size
	## Get _items
	func items() -> Array[EquipmentItem]:
		return self._items.slice(0, self._items_size)
	## Get _items item 
	func get_items(index: int) -> EquipmentItem: # index begin from 1
		if index > 0 and index <= _items_size and index <= _items.size():
			return self._items[index - 1]
		return null
	## Add _items
	func add_items(item: EquipmentItem) -> EquipmentItem:
		if self._items_size >= 0 and self._items_size < self._items.size():
			self._items[self._items_size] = item
		else:
			self._items.append(item)
		self._items_size += 1
		return item
	## Append _items
	func append_items(item_array: Array):
		for item in item_array:
			if item is EquipmentItem:
				self.add_items(item)
	## Clean _items 
	func clear_items() -> void:
		self._items.clear()
		self._items_size = 0


	## Init message field values to default value
	func Init() -> void:
		self.clear_items()

	## Create a new message instance
	## Returns: Message - New message instance
	func New() -> Message:
		var msg = EquipmentState.new()
		return msg

	## Message ProtoName
	## Returns: String - ProtoName
	func ProtoName() -> String:
		return "gameframe.protocol.EquipmentState"

	func MergeFrom(other : Message) -> void:
		if other is EquipmentState:
			self._items = self._items.slice(0, _items_size)
			self._items.append_array(other._items.slice(0, other._items_size))
			self._items_size += other._items_size
 
	func SerializeToBytes(buffer: PackedByteArray = PackedByteArray()) -> PackedByteArray:
		for item in self._items:
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
					var sub__items = EquipmentItem.new()
					var field_value = Wire.decode_message(data, pos, sub__items)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.add_items(field_value[GDScriptUtils.VALUE_KEY])
					pos += field_value[GDScriptUtils.SIZE_KEY]
				_:
					return -1

		return pos

	func SerializeToDictionary() -> Dictionary:
		var dict = {}
		dict["items"] = []
		for index in range(1, self._items_size + 1):
			var item = self.get_items(index)
			dict["items"].append(item.SerializeToDictionary())
		return dict

	func ParseFromDictionary(dict: Dictionary) -> void:
		if dict == null:
			return

		self.clear_items()
		if dict.has("items"):
			var list = dict["items"]
			for item in list:
				var item_msg = EquipmentItem.new()
				item_msg.ParseFromDictionary(item)
				self.add_items(item_msg)

# =========================================

