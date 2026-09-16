extends Node

var _config := GameData.new()
var _localization := GameLocalization.new()
var _service := AdventureService.new()
var _presenter := AdventurePresenter.new()
@onready var session: GameSession = $Session
@onready var view: AdventureView = $View

func _ready() -> void:
	if not _config.load_all():
		view.show_status(tr("UI_TABLE_ERROR"))
		return
	_localization.setup(_config)
	_service.setup(_config, session)
	_presenter.setup(view, _service, _localization)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--offline-save="):
			session.offline_path = argument.trim_prefix("--offline-save=")
	session.setup(_config.get_model("Rules").get_row(1).Version)

func _exit_tree() -> void:
	_presenter.dispose()
	_localization.dispose()
