# Package: gameframe.protocol

const GDScriptUtils = preload("res://addons/protobuf/proto/GDScriptUtils.gd")
const Message = preload("res://addons/protobuf/proto/Message.gd")
const Wire = preload("res://protobuf/runtime/wire.gd")
const Battle = preload("res://protobuf/generated/api/battle/Battle.proto.gd").Battle
const Notification = preload("res://protobuf/generated/api/notification/Notification.proto.gd").Notification
const StateUpdate = preload("res://protobuf/generated/api/gamestate/StateUpdate.proto.gd").StateUpdate

class GameResponse extends Message:
	#1 : id
	var id: String = ""

	#2 : code
	var code: String = ""

	#3 : update
	var update: StateUpdate = null

	#4 : notifications
	var _notifications: Array[Notification] = []
	var _notifications_size: int = 0
	## Size of _notifications
	func notifications_size() -> int:
		return self._notifications_size
	## Get _notifications
	func notifications() -> Array[Notification]:
		return self._notifications.slice(0, self._notifications_size)
	## Get _notifications item 
	func get_notifications(index: int) -> Notification: # index begin from 1
		if index > 0 and index <= _notifications_size and index <= _notifications.size():
			return self._notifications[index - 1]
		return null
	## Add _notifications
	func add_notifications(item: Notification) -> Notification:
		if self._notifications_size >= 0 and self._notifications_size < self._notifications.size():
			self._notifications[self._notifications_size] = item
		else:
			self._notifications.append(item)
		self._notifications_size += 1
		return item
	## Append _notifications
	func append_notifications(item_array: Array):
		for item in item_array:
			if item is Notification:
				self.add_notifications(item)
	## Clean _notifications 
	func clear_notifications() -> void:
		self._notifications.clear()
		self._notifications_size = 0

	#5 : battle
	var battle: Battle = null


	## Init message field values to default value
	func Init() -> void:
		self.id = ""
		self.code = ""
		self.update = null
		self.clear_notifications()
		self.battle = null

	## Create a new message instance
	## Returns: Message - New message instance
	func New() -> Message:
		var msg = GameResponse.new()
		return msg

	## Message ProtoName
	## Returns: String - ProtoName
	func ProtoName() -> String:
		return "gameframe.protocol.GameResponse"

	func MergeFrom(other : Message) -> void:
		if other is GameResponse:
			self.id += other.id
			self.code += other.code
			if other.update != null:
				if self.update == null:
					self.update = StateUpdate.new()
				self.update.MergeFrom(other.update)
			else:
				self.update = null
			self._notifications = self._notifications.slice(0, _notifications_size)
			self._notifications.append_array(other._notifications.slice(0, other._notifications_size))
			self._notifications_size += other._notifications_size
			if other.battle != null:
				if self.battle == null:
					self.battle = Battle.new()
				self.battle.MergeFrom(other.battle)
			else:
				self.battle = null
 
	func SerializeToBytes(buffer: PackedByteArray = PackedByteArray()) -> PackedByteArray:
		if self.id != "":
			GDScriptUtils.encode_tag(buffer, 1, 9)
			GDScriptUtils.encode_string(buffer, self.id)
		if self.code != "":
			GDScriptUtils.encode_tag(buffer, 2, 9)
			GDScriptUtils.encode_string(buffer, self.code)
		if self.update != null:
			GDScriptUtils.encode_tag(buffer, 3, 11)
			GDScriptUtils.encode_message(buffer, self.update)
		for item in self._notifications:
			GDScriptUtils.encode_tag(buffer, 4, 11)
			GDScriptUtils.encode_message(buffer, item)
		if self.battle != null:
			GDScriptUtils.encode_tag(buffer, 5, 11)
			GDScriptUtils.encode_message(buffer, self.battle)
		return buffer
 
	func ParseFromBytes(data: PackedByteArray) -> int:
		if not Wire.validate(data, {1: 2, 2: 2, 3: 2, 4: 2, 5: 2}):
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
					self.id = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				2:
					var field_value = GDScriptUtils.decode_string(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.code = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				3:
					if self.update == null:
						self.update = StateUpdate.new()
					self.update.Init()
					var field_value = Wire.decode_message(data, pos, self.update)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.update = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				4:
					var sub__notifications = Notification.new()
					var field_value = Wire.decode_message(data, pos, sub__notifications)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.add_notifications(field_value[GDScriptUtils.VALUE_KEY])
					pos += field_value[GDScriptUtils.SIZE_KEY]
				5:
					if self.battle == null:
						self.battle = Battle.new()
					self.battle.Init()
					var field_value = Wire.decode_message(data, pos, self.battle)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.battle = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				_:
					return -1

		return pos

	func SerializeToDictionary() -> Dictionary:
		var dict = {}
		dict["id"] = self.id
		dict["code"] = self.code
		if self.update != null:
			dict["update"] = self.update.SerializeToDictionary()
		dict["notifications"] = []
		for index in range(1, self._notifications_size + 1):
			var item = self.get_notifications(index)
			dict["notifications"].append(item.SerializeToDictionary())
		if self.battle != null:
			dict["battle"] = self.battle.SerializeToDictionary()
		return dict

	func ParseFromDictionary(dict: Dictionary) -> void:
		if dict == null:
			return

		if dict.has("id"):
			self.id = dict.get("id")
		if dict.has("code"):
			self.code = dict.get("code")
		if dict.has("update"):
			if self.update == null:
				self.update = StateUpdate.new()
			self.update.Init()
			self.update.ParseFromDictionary(dict.get("update"))
		else:
			self.update = null
		self.clear_notifications()
		if dict.has("notifications"):
			var list = dict["notifications"]
			for item in list:
				var item_msg = Notification.new()
				item_msg.ParseFromDictionary(item)
				self.add_notifications(item_msg)
		if dict.has("battle"):
			if self.battle == null:
				self.battle = Battle.new()
			self.battle.Init()
			self.battle.ParseFromDictionary(dict.get("battle"))
		else:
			self.battle = null

# =========================================

