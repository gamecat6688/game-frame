# Package: gameframe.protocol

const GDScriptUtils = preload("res://addons/protobuf/proto/GDScriptUtils.gd")
const Message = preload("res://addons/protobuf/proto/Message.gd")
const Wire = preload("res://protobuf/runtime/wire.gd")

class FormationState extends Message:
	#1 : slots
	var _slots: Array[int] = []
	var _slots_size: int = 0
	## Size of _slots
	func slots_size() -> int:
		return self._slots_size
	## Get _slots
	func slots() -> Array[int]:
		return self._slots.slice(0, self._slots_size)
	## Get _slots item 
	func get_slots(index: int) -> int: # index begin from 1
		if index > 0 and index <= _slots_size and index <= _slots.size():
			return self._slots[index - 1]
		return 0
	## Add _slots
	func add_slots(item: int) -> int:
		if self._slots_size >= 0 and self._slots_size < self._slots.size():
			self._slots[self._slots_size] = item
		else:
			self._slots.append(item)
		self._slots_size += 1
		return item
	## Append _slots
	func append_slots(item_array: Array):
		for item in item_array:
			if item is int:
				self.add_slots(item)
	## Clean _slots 
	func clear_slots() -> void:
		self._slots.clear()
		self._slots_size = 0


	## Init message field values to default value
	func Init() -> void:
		self.clear_slots()

	## Create a new message instance
	## Returns: Message - New message instance
	func New() -> Message:
		var msg = FormationState.new()
		return msg

	## Message ProtoName
	## Returns: String - ProtoName
	func ProtoName() -> String:
		return "gameframe.protocol.FormationState"

	func MergeFrom(other : Message) -> void:
		if other is FormationState:
			self._slots = self._slots.slice(0, _slots_size)
			self._slots.append_array(other._slots.slice(0, other._slots_size))
			self._slots_size += other._slots_size
 
	func SerializeToBytes(buffer: PackedByteArray = PackedByteArray()) -> PackedByteArray:
		for item in self._slots:
			GDScriptUtils.encode_tag(buffer, 1, 5)
			GDScriptUtils.encode_varint(buffer, item)
		return buffer
 
	func ParseFromBytes(data: PackedByteArray) -> int:
		if not Wire.validate(data, {1: 0}):
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
					self.add_slots(field_value[GDScriptUtils.VALUE_KEY])
					pos += field_value[GDScriptUtils.SIZE_KEY]
				_:
					return -1

		return pos

	func SerializeToDictionary() -> Dictionary:
		var dict = {}
		dict["slots"] = self._slots
		return dict

	func ParseFromDictionary(dict: Dictionary) -> void:
		if dict == null:
			return

		self.clear_slots()
		if dict.has("slots"):
			var list = dict["slots"]
			for item in list:
				self.add_slots(item)

# =========================================

