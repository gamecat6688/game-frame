class_name I18NModel
extends RefCounted

const Proto = preload("../../protobuf/generated/table/I18N.proto.gd")
const DEFAULT_DATA_FILE := "../data/I18N.bytes"

var rows: Dictionary = {}


func load_data(path: String = "") -> bool:
	var data_path := path
	if data_path.is_empty():
		data_path = get_script().resource_path.get_base_dir().path_join(DEFAULT_DATA_FILE).simplify_path()

	if not FileAccess.file_exists(data_path):
		push_error("I18N config file does not exist: %s" % data_path)
		return false

	var data := FileAccess.get_file_as_bytes(data_path)
	var config := Proto.I18NConfig.new()
	var consumed: int = config.ParseFromBytes(data)
	if consumed != data.size():
		push_error("I18N config parse failed: consumed %d of %d bytes" % [consumed, data.size()])
		return false

	rows.clear()
	for row in config.Records():
		rows[row.ID] = row
	return true


func has(key: String) -> bool:
	return rows.has(key)


func get_row(key: String):
	return rows.get(key)


func get_rows() -> Dictionary:
	return rows
