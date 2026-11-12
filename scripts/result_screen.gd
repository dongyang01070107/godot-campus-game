extends Control

const MENU_SCENE := "res://scenes/main_menu.tscn"
const GAME_SCENE := "res://scenes/library_game.tscn"
const INK := Color("243747")


func _ready() -> void:
	_build_ui()


func _draw() -> void:
	var size := get_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color("e8dfcb"))
	draw_rect(Rect2(0, size.y * 0.78, size.x, size.y * 0.22), Color("c8b89b"))
	for x in [size.x * 0.08, size.x * 0.88]:
		draw_rect(Rect2(x, size.y * 0.1, size.x * 0.045, size.y * 0.58), Color("795b43"))
		for row in 4:
			draw_rect(Rect2(x + 5, size.y * (0.2 + row * 0.12), size.x * 0.035, size.y * 0.1), [Color("b25a46"), Color("547c78"), Color("d7b15d"), Color("526582")][row])


func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var compact := get_viewport_rect().size.x < 600.0
	panel.custom_minimum_size = Vector2(minf(570.0, get_viewport_rect().size.x - 28.0), 450)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("fff8e9")
	panel_style.border_color = Color("d1c2a8")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(22)
	panel_style.set_content_margin_all(30)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 13)
	panel.add_child(layout)
	var heading := Label.new()
	heading.text = "找到座位，任務完成！" if Session.won else "時間到，再找一次吧！"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 26 if compact else 32)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_color_override("font_color", INK)
	layout.add_child(heading)
	var subheading := Label.new()
	subheading.text = "你成功搶到一個安靜的讀書位置。" if Session.won else "這次沒能在管理員巡到前找到空位。"
	subheading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subheading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subheading.add_theme_font_size_override("font_size", 17)
	subheading.add_theme_color_override("font_color", Color("52606a"))
	layout.add_child(subheading)
	var score_label := Label.new()
	var seat_score := 10 if Session.won else 0
	score_label.text = "空位 %d 分　筆記本 %d 本（+%d）\n時間獎勵 %d 分　・　總分 %d 分" % [seat_score, Session.notebook_count, Session.notebook_count * 5, Session.time_bonus, Session.score]
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 19 if compact else 22)
	score_label.add_theme_color_override("font_color", INK)
	layout.add_child(score_label)
	var retry := _button("再玩一次", Color("efb953"))
	retry.pressed.connect(_retry)
	retry.pressed.connect(func() -> void: AudioBus.play_sfx("click"))
	layout.add_child(retry)
	var home := _button("回到首頁", Color("d9e5dc"))
	home.pressed.connect(_go_home)
	home.pressed.connect(func() -> void: AudioBus.play_sfx("click"))
	layout.add_child(home)


func _retry() -> void:
	Session.reset_run()
	get_tree().change_scene_to_file(GAME_SCENE)


func _go_home() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


func _button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(240, 50)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", INK)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(13)
	style.set_content_margin_all(10)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.08)
	button.add_theme_stylebox_override("hover", hover)
	return button
