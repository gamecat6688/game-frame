class_name GameLocalization
extends RefCounted

signal changed
const LOCALES: Array[String] = ["zh_CN", "zh_TW", "en"]
var _translations: Array[Translation] = []

func setup(config: GameData) -> void:
	# Dynamic copy comes exclusively from excel2pb's generated I18N table.
	var model = config.get_model("I18N")
	for locale in LOCALES:
		var resource := Translation.new()
		resource.locale = locale
		for row in model.get_rows().values():
			var value: String = row.En
			if locale == "zh_CN": value = row.Cn
			if locale == "zh_TW": value = row.Tn
			if value.is_empty(): value = row.Cn
			resource.add_message(row.ID, value)
		TranslationServer.add_translation(resource)
		_translations.append(resource)
	set_locale(str(ProjectSettings.get_setting("game/locale", "zh_CN")))

func set_locale(locale: String) -> void:
	if locale not in LOCALES: locale = "en"
	TranslationServer.set_locale(locale)
	changed.emit()

func resolve(key: String) -> String:
	return str(TranslationServer.translate(key))

func dispose() -> void:
	for resource in _translations: TranslationServer.remove_translation(resource)
	_translations.clear()
