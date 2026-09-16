# Package: gameframe.protocol

const GDScriptUtils = preload("res://addons/protobuf/proto/GDScriptUtils.gd")
const Message = preload("res://addons/protobuf/proto/Message.gd")
const Wire = preload("res://protobuf/runtime/wire.gd")
const EquipmentItem = preload("res://protobuf/generated/api/gamestate/equipment/EquipmentState.proto.gd").EquipmentItem

class EquipmentChanges extends Message:
	#1 : upsert
	var _upsert: Array[EquipmentItem] = []
	var _upsert_size: int = 0
	## Size of _upsert
	func upsert_size() -> int:
		return self._upsert_size
	## Get _upsert
	func upsert() -> Array[EquipmentItem]:
		return self._upsert.slice(0, self._upsert_size)
	## Get _upsert item 
	func get_upsert(index: int) -> EquipmentItem: # index begin from 1
		if index > 0 and index <= _upsert_size and index <= _upsert.size():
			return self._upsert[index - 1]
		return null
	## Add _upsert
	func add_upsert(item: EquipmentItem) -> EquipmentItem:
		if self._upsert_size >= 0 and self._upsert_size < self._upsert.size():
			self._upsert[self._upsert_size] = item
		else:
			self._upsert.append(item)
		self._upsert_size += 1
		return item
	## Append _upsert
	func append_upsert(item_array: Array):
		for item in item_array:
			if item is EquipmentItem:
				self.add_upsert(item)
	## Clean _upsert 
	func clear_upsert() -> void:
		self._upsert.clear()
		self._upsert_size = 0

	#2 : deleted_ids
	var _deleted_ids: Array[int] = []
	var _deleted_ids_size: int = 0
	## Size of _deleted_ids
	func deleted_ids_size() -> int:
		return self._deleted_ids_size
	## Get _deleted_ids
	func deleted_ids() -> Array[int]:
		return self._deleted_ids.slice(0, self._deleted_ids_size)
	## Get _deleted_ids item 
	func get_deleted_ids(index: int) -> int: # index begin from 1
		if index > 0 and index <= _deleted_ids_size and index <= _deleted_ids.size():
			return self._deleted_ids[index - 1]
		return 0
	## Add _deleted_ids
	func add_deleted_ids(item: int) -> int:
		if self._deleted_ids_size >= 0 and self._deleted_ids_size < self._deleted_ids.size():
			self._deleted_ids[self._deleted_ids_size] = item
		else:
			self._deleted_ids.append(item)
		self._deleted_ids_size += 1
		return item
	## Append _deleted_ids
	func append_deleted_ids(item_array: Array):
		for item in item_array:
			if item is int:
				self.add_deleted_ids(item)
	## Clean _deleted_ids 
	func clear_deleted_ids() -> void:
		self._deleted_ids.clear()
		self._deleted_ids_size = 0


	## Init message field values to default value
	func Init() -> void:
		self.clear_upsert()
		self.clear_deleted_ids()

	## Create a new message instance
	## Returns: Message - New message instance
	func New() -> Message:
		var msg = EquipmentChanges.new()
		return msg

	## Message ProtoName
	## Returns: String - ProtoName
	func ProtoName() -> String:
		return "gameframe.protocol.EquipmentChanges"

	func MergeFrom(other : Message) -> void:
		if other is EquipmentChanges:
			self._upsert = self._upsert.slice(0, _upsert_size)
			self._upsert.append_array(other._upsert.slice(0, other._upsert_size))
			self._upsert_size += other._upsert_size
			self._deleted_ids = self._deleted_ids.slice(0, _deleted_ids_size)
			self._deleted_ids.append_array(other._deleted_ids.slice(0, other._deleted_ids_size))
			self._deleted_ids_size += other._deleted_ids_size
 
	func SerializeToBytes(buffer: PackedByteArray = PackedByteArray()) -> PackedByteArray:
		for item in self._upsert:
			GDScriptUtils.encode_tag(buffer, 1, 11)
			GDScriptUtils.encode_message(buffer, item)
		for item in self._deleted_ids:
			GDScriptUtils.encode_tag(buffer, 2, 5)
			GDScriptUtils.encode_varint(buffer, item)
		return buffer
 
	func ParseFromBytes(data: PackedByteArray) -> int:
		if not Wire.validate(data, {1: 2, 2: 0}):
			return -1

		var size = data.size()
		var pos = 0
 
		while pos < size:
			var tag = GDScriptUtils.decode_tag(data, pos)
			var field_number = tag[GDScriptUtils.VALUE_KEY]
			pos += tag[GDScriptUtils.SIZE_KEY]
 
			match field_number:
				1:
					var sub__upsert = EquipmentItem.new()
					var field_value = Wire.decode_message(data, pos, sub__upsert)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.add_upsert(field_value[GDScriptUtils.VALUE_KEY])
					pos += field_value[GDScriptUtils.SIZE_KEY]
				2:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.add_deleted_ids(field_value[GDScriptUtils.VALUE_KEY])
					pos += field_value[GDScriptUtils.SIZE_KEY]
				_:
					return -1

		return pos

	func SerializeToDictionary() -> Dictionary:
		var dict = {}
		dict["upsert"] = []
		for index in range(1, self._upsert_size + 1):
			var item = self.get_upsert(index)
			dict["upsert"].append(item.SerializeToDictionary())
		dict["deleted_ids"] = self._deleted_ids
		return dict

	func ParseFromDictionary(dict: Dictionary) -> void:
		if dict == null:
			return

		self.clear_upsert()
		if dict.has("upsert"):
			var list = dict["upsert"]
			for item in list:
				var item_msg = EquipmentItem.new()
				item_msg.ParseFromDictionary(item)
				self.add_upsert(item_msg)
		self.clear_deleted_ids()
		if dict.has("deleted_ids"):
			var list = dict["deleted_ids"]
			for item in list:
				self.add_deleted_ids(item)

# =========================================

