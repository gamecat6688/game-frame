extends SceneTree

const PANEL_PATH := "View/Margin/Main/Currencies"
const PREVIEW_SCENE := "res://ui/components/currencies_restore/CurrenciesPreview.tscn"
const CASE_SIZES := [Vector2i(720, 1120), Vector2i(600, 1120)]

func _initialize() -> void:
	_run.call_deferred()

func _fail(message: String) -> void:
	push_error("UI_RESTORE_CAPTURE: " + message)
	quit(1)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not DirAccess.dir_exists_absolute(args[0]):
		_fail("Pass an existing absolute output directory after --")
		return
	if DisplayServer.get_name() == "headless":
		_fail("A real Compatibility renderer is required for pixel readback")
		return
	TranslationServer.set_locale("en")
	if TranslationServer.translate("UI_GOLD") != "Gold" or TranslationServer.translate("UI_EXPERIENCE") != "Essence":
		_fail("Expected project translations for the English capture")
		return

	var scene := load("res://ui/main.tscn") as PackedScene
	if scene == null:
		_fail("Could not load the game main scene")
		return
	var output := args[0]
	var records := []
	for size in CASE_SIZES:
		var viewport := SubViewport.new()
		viewport.size = size
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var app := scene.instantiate()
		# Leave the actual static scene and its view script in place, but isolate
		# rendering from the Session, network, local saves and real-time state.
		app.set_script(null)
		viewport.add_child(app)
		var view := app.get_node("View") as AdventureView
		view.select_page(0)
		view.render(_fixture_data())
		if app.get_node("%Gold").text != "12,345" or app.get_node("%XP").text != "678":
			_fail("The live AdventureView wallet bindings did not render fixture values")
			return
		var panel := app.get_node(PANEL_PATH) as PanelContainer
		var style := panel.get_theme_stylebox("panel") as StyleBoxTexture
		if not panel.has_theme_stylebox_override("panel") or style == null or style.texture == null or style.resource_path.get_extension() != "tres":
			_fail("The live currency panel does not use an external nine-slice StyleBoxTexture")
			return

		await _settle_render()
		var actual_rects := _rects(panel)
		if actual_rects.panel[2] != size.x - 48:
			_fail("Panel did not follow the parent container at viewport width %d: %s" % [size.x, str(actual_rects.panel)])
			return
		if not _save(viewport, output.path_join("actual-%d.png" % size.x)):
			return
		if size.x == 720 and not await _capture_preview(viewport, view, actual_rects, output.path_join("preview-720.png")):
			return

		# Independent pre-change reference: the original inherited StyleBoxFlat
		# from theme.tres, not a re-use of the generated PNG or preview scene.
		panel.remove_theme_stylebox_override("panel")
		if not panel.get_theme_stylebox("panel") is StyleBoxFlat:
			_fail("Could not recover the original inherited currency style")
			return
		await _settle_render()
		var reference_rects := _rects(panel)
		if actual_rects != reference_rects:
			_fail("The panel or one of its live labels shifted: actual %s; baseline %s" % [str(actual_rects), str(reference_rects)])
			return
		if not _save(viewport, output.path_join("reference-%d.png" % size.x)):
			return
		records.append({"viewport": [size.x, size.y], "roi": actual_rects.panel, "rectangles": actual_rects})
		viewport.queue_free()
		await process_frame
	var record_file := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	if record_file == null:
		_fail("Could not write capture metadata")
		return
	record_file.store_string(JSON.stringify({
		"godot": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(),
		"locale": "en",
		"gold": "12,345",
		"xp": "678",
		"style_reference": "inherited StyleBoxFlat from theme.tres",
		"cases": records,
	}, "  ") + "\n")
	record_file.close()
	print("UI_RESTORE_CAPTURE: rendered actual + reference at two widths")
	quit()

func _capture_preview(viewport: SubViewport, view: AdventureView, expected_rects: Dictionary, path: String) -> bool:
	var packed := load(PREVIEW_SCENE) as PackedScene
	if packed == null:
		_fail("Could not load generated CurrenciesPreview scene")
		return false
	var preview := packed.instantiate()
	view.hide()
	viewport.add_child(preview)
	await _settle_render()
	var panel := preview.get_node_or_null("Currencies") as PanelContainer
	if panel == null or _rects(panel) != expected_rects:
		_fail("Generated preview currency layout did not match the actual panel and label rectangles")
		return false
	if not _save(viewport, path):
		return false
	viewport.remove_child(preview)
	preview.queue_free()
	view.show()
	return true

func _settle_render() -> void:
	# First flush container sorting and theme changes, then read the completed draw.
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func _rects(panel: PanelContainer) -> Dictionary:
	var rects := {}
	var named := {"panel": panel, "row": panel.get_node("Row")}
	for label_name in ["GoldLabel", "Gold", "XPLabel", "XP"]:
		named[label_name] = panel.get_node("Row/" + label_name)
	for key in named:
		var rect: Rect2 = named[key].get_global_rect()
		rects[key] = [roundi(rect.position.x), roundi(rect.position.y), roundi(rect.size.x), roundi(rect.size.y)]
	return rects

func _save(viewport: SubViewport, path: String) -> bool:
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != viewport.size:
		_fail("Invalid rendered screenshot for " + path)
		return false
	if image.save_png(path) != OK:
		_fail("Could not save " + path)
		return false
	return true

func _fixture_data() -> Dictionary:
	var actor := {"portrait": "res://assets/hero_1.svg", "name": ""}
	var actors := [actor, actor, actor, actor, actor]
	return {
		"gold": "12,345", "xp": "678", "mode_label": "Offline", "mode_action": "Go online",
		"locale_index": 2, "stage_title": "Mistwood", "stage_description": "",
		"stage_reward": "", "idle": "", "idle_hint": "", "busy": false,
		"empty": false, "complete": false, "heroes": [], "hero_name": "",
		"hero_description": "", "hero_stats": "", "hero_skill": "", "hero_equipment": "",
		"level_cost": "", "slot": -1, "slots": ["", "", "", "", ""], "allies": actors,
		"enemies": actors, "equipment": [], "battle_names": {},
	}
