# Package: gameframe.protocol

const GDScriptUtils = preload("res://addons/protobuf/proto/GDScriptUtils.gd")
const Message = preload("res://addons/protobuf/proto/Message.gd")
const Wire = preload("res://protobuf/runtime/wire.gd")
const EquipmentChanges = preload("res://protobuf/generated/api/notification/equipment/EquipmentChanges.proto.gd").EquipmentChanges

class Notification extends Message:
	#1 : equipment
	var equipment: EquipmentChanges = null


	## Init message field values to default value
	func Init() -> void:
		self.equipment = null

	## Create a new message instance
	## Returns: Message - New message instance
	func New() -> Message:
		var msg = Notification.new()
		return msg

	## Message ProtoName
	## Returns: String - ProtoName
	func ProtoName() -> String:
		return "gameframe.protocol.Notification"

	func MergeFrom(other : Message) -> void:
		if other is Notification:
			if other.equipment != null:
				if self.equipment == null:
					self.equipment = EquipmentChanges.new()
				self.equipment.MergeFrom(other.equipment)
			else:
				self.equipment = null
 
	func SerializeToBytes(buffer: PackedByteArray = PackedByteArray()) -> PackedByteArray:
		if self.equipment != null:
			GDScriptUtils.encode_tag(buffer, 1, 11)
			GDScriptUtils.encode_message(buffer, self.equipment)
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
					if self.equipment == null:
						self.equipment = EquipmentChanges.new()
					self.equipment.Init()
					var field_value = Wire.decode_message(data, pos, self.equipment)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.equipment = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				_:
					return -1

		return pos

	func SerializeToDictionary() -> Dictionary:
		var dict = {}
		if self.equipment != null:
			dict["equipment"] = self.equipment.SerializeToDictionary()
		return dict

	func ParseFromDictionary(dict: Dictionary) -> void:
		if dict == null:
			return

		if dict.has("equipment"):
			if self.equipment == null:
				self.equipment = EquipmentChanges.new()
			self.equipment.Init()
			self.equipment.ParseFromDictionary(dict.get("equipment"))
		else:
			self.equipment = null

# =========================================

