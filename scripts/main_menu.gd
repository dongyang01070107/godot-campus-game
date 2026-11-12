extends Control

const GAME_SCENE := "res://scenes/library_game.tscn"
const INK := Color("243747")
const CREAM := Color("fff8e9")
const GOLD := Color("efb953")


func _ready() -> void:
	_build_ui()


func _draw() -> void:
	var size := get_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color("e8dfcb"))
	draw_rect(Rect2(0, size.y * 0.72, size.x, size.y * 0.28), Color("c8b89b"))
	for side in [0.035, 0.84]:
		var shelf := Rect2(size.x * side, size.y * 0.12, size.x * 0.12, size.y * 0.56)
		draw_rect(shelf, Color("795b43"))
		for row in 3:
			var y := shelf.position.y + 18.0 + row * (shelf.size.y / 3.0)
			draw_rect(Rect2(shelf.position.x + 8, y, shelf.size.x - 16, 5), Color("bd9864"))
			for book in 5:
				var x := shelf.position.x + 11.0 + book * (shelf.size.x - 27.0) / 5.0
				var book_color: Color = [Color("b25a46"), Color("557c78"), Color("d5a548"), Color("526582")][(book + row) % 4]
				draw_rect(Rect2(x, y - 28, 12, 26), book_color)
	# A small study desk anchors the hand-drawn library scene.
	var desk := Rect2(size.x * 0.18, size.y * 0.76, size.x * 0.64, size.y * 0.1)
	draw_rect(desk, Color("9a704d"))
	draw_rect(Rect2(desk.position.x + 35, desk.end.y, 12, size.y * 0.11), Color("795b43"))
	draw_rect(Rect2(desk.end.x - 47, desk.end.y, 12, size.y * 0.11), Color("795b43"))


func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var compact := get_viewport_rect().size.x < 620.0
	panel.custom_minimum_size = Vector2(minf(600.0, get_viewport_rect().size.x - 28.0), 450 if not compact else 470)
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 14)
	panel.add_child(layout)

	var eyebrow := _label("期末週・中央圖書館", 20, Color("64847f"))
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(eyebrow)
	var title := _label("圖書館座位爭奪戰", 30 if compact else 38, INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(title)
	var description := _label("穿過書架與桌椅，躲開巡邏管理員，搶到最後一個空位！", 18, Color("52606a"))
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(description)
	var instructions := _label("方向鍵 / WASD 移動　・　E / 空白鍵坐下\n收集筆記本加分，管理員碰到三次就會被請出圖書館。", 16, INK)
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(instructions)
	var start_button := _button("開始尋找座位", GOLD)
	start_button.pressed.connect(_start_game)
	start_button.pressed.connect(func() -> void: AudioBus.play_sfx("click"))
	layout.add_child(start_button)
	var credit := _label("視傳四勤 121253015 陳冬昀", 15, Color("64716f"))
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(credit)
	var asset_credit := _label("字型：Noto Sans TC・Google Fonts・SIL OFL 1.1", 12, Color("7b8179"))
	asset_credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	asset_credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(asset_credit)


func _start_game() -> void:
	Session.reset_run()
	get_tree().change_scene_to_file(GAME_SCENE)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260, 54)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_stylebox_override("normal", _button_style(color))
	button.add_theme_stylebox_override("hover", _button_style(color.lightened(0.1)))
	button.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.08)))
	return button


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CREAM
	style.border_color = Color("d1c2a8")
	style.set_border_width_all(2)
	style.set_corner_radius_all(22)
	style.set_content_margin_all(28)
	style.shadow_color = Color(0, 0, 0, 0.13)
	style.shadow_size = 16
	return style


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(14)
	style.set_content_margin_all(10)
	return style
