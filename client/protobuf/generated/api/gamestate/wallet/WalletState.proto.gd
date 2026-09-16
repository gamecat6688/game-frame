# Package: gameframe.protocol

const GDScriptUtils = preload("res://addons/protobuf/proto/GDScriptUtils.gd")
const Message = preload("res://addons/protobuf/proto/Message.gd")
const Wire = preload("res://protobuf/runtime/wire.gd")

class WalletState extends Message:
	#1 : gold
	var gold: int = 0

	#2 : experience
	var experience: int = 0


	## Init message field values to default value
	func Init() -> void:
		self.gold = 0
		self.experience = 0

	## Create a new message instance
	## Returns: Message - New message instance
	func New() -> Message:
		var msg = WalletState.new()
		return msg

	## Message ProtoName
	## Returns: String - ProtoName
	func ProtoName() -> String:
		return "gameframe.protocol.WalletState"

	func MergeFrom(other : Message) -> void:
		if other is WalletState:
			self.gold += other.gold
			self.experience += other.experience
 
	func SerializeToBytes(buffer: PackedByteArray = PackedByteArray()) -> PackedByteArray:
		if self.gold != 0:
			GDScriptUtils.encode_tag(buffer, 1, 3)
			GDScriptUtils.encode_varint(buffer, self.gold)
		if self.experience != 0:
			GDScriptUtils.encode_tag(buffer, 2, 3)
			GDScriptUtils.encode_varint(buffer, self.experience)
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
					self.gold = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				2:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.experience = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				_:
					return -1

		return pos

	func SerializeToDictionary() -> Dictionary:
		var dict = {}
		dict["gold"] = self.gold
		dict["experience"] = self.experience
		return dict

	func ParseFromDictionary(dict: Dictionary) -> void:
		if dict == null:
			return

		if dict.has("gold"):
			self.gold = dict.get("gold")
		if dict.has("experience"):
			self.experience = dict.get("experience")

# =========================================

