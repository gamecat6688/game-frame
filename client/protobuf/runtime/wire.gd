extends RefCounted

## Bounds checks for project-generated messages, before the vendor decoder reads fields.
const Utils = preload("res://addons/protobuf/proto/GDScriptUtils.gd")
const Message = preload("res://addons/protobuf/proto/Message.gd")


static func validate(data: PackedByteArray, fields: Dictionary) -> bool:
	var offset: int = 0
	while offset < data.size():
		var end := _varint_end(data, offset)
		if end < 0:
			return false

		var tag: int = Utils.decode_varint(data, offset)[Utils.VALUE_KEY]
		var number := tag >> 3
		var wire_type := tag & 7
		if number < 1 or number > 536870911 or fields.get(number, -1) != wire_type:
			return false

		offset = end
		match wire_type:
			0:
				offset = _varint_end(data, offset)
			1:
				offset += 8
			2:
				end = _varint_end(data, offset)
				if end < 0:
					return false

				var length: int = Utils.decode_varint(data, offset)[Utils.VALUE_KEY]
				if length < 0 or length > data.size() - end:
					return false
				offset = end + length
			5:
				offset += 4
			_:
				return false

		if offset < 0 or offset > data.size():
			return false

	return true


static func decode_message(data: PackedByteArray, offset: int, message: Message) -> Dictionary:
	var end := _varint_end(data, offset)
	if end < 0 or message == null:
		return {Utils.VALUE_KEY: null, Utils.SIZE_KEY: -1}

	var length: int = Utils.decode_varint(data, offset)[Utils.VALUE_KEY]
	if length < 0 or length > data.size() - end:
		return {Utils.VALUE_KEY: null, Utils.SIZE_KEY: -1}
	if message.ParseFromBytes(data.slice(end, end + length)) != length:
		return {Utils.VALUE_KEY: null, Utils.SIZE_KEY: -1}

	return {Utils.VALUE_KEY: message, Utils.SIZE_KEY: end - offset + length}


static func _varint_end(data: PackedByteArray, offset: int) -> int:
	for index in 10:
		if offset + index >= data.size():
			return -1

		var value: int = data[offset + index]
		if index == 9 and value > 1:
			return -1
		if value < 128:
			return offset + index + 1

	return -1
