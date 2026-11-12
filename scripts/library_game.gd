extends Control

const RESULT_SCENE := "res://scenes/result_screen.tscn"
const GRID := [
	"#############",
	"#....#......#",
	"###..#.#.##.#",
	"#...#...#...#",
	"#.###.###.#.#",
	"#.....#...#G#",
	"#.###.#.###.#",
	"#...........#",
	"#############",
]
const PLAYER_START := Vector2i(1, 1)
const GOAL := Vector2i(11, 5)
const STUDENTS := [Vector2i(7, 3), Vector2i(3, 5)]
const NOTES := [Vector2i(1, 7), Vector2i(6, 7), Vector2i(11, 7)]
const PATROL_ROUTE := [Vector2i(3, 1), Vector2i(4, 1), Vector2i(4, 2), Vector2i(3, 2), Vector2i(3, 3), Vector2i(2, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(3, 2), Vector2i(4, 2), Vector2i(4, 1)]
const SECOND_ROUTE := [Vector2i(9, 3), Vector2i(10, 3), Vector2i(11, 3), Vector2i(11, 4), Vector2i(11, 5), Vector2i(11, 4), Vector2i(11, 3), Vector2i(10, 3)]
const INK := Color("243747")
const WALL := Color("71563f")
const FLOOR_A := Color("eee5d4")
const FLOOR_B := Color("e4d9c5")
const GOLD := Color("efb953")

var player_pos: Vector2i = PLAYER_START
var guard_positions: Array = [PATROL_ROUTE[0]]
var guard_routes: Array = [PATROL_ROUTE]
var guard_route_indices: Array = [0]
var remaining_time := 120.0
var elapsed_time := 0.0
var score := 0
var lives := 3
var notebooks := 0
var collected_notes: Array[Vector2i] = []
var move_cooldown := 0.0
var guard_move_timer := 0.0
var hit_grace := 0.0
var result_started := false
var touch_direction := Vector2i.ZERO
var show_touch_controls := false
var active_touch_id := -1
var mouse_steering := false
var hud_label: Label
var feedback_label: Label
var _hud_last_second := -1


func _ready() -> void:
	show_touch_controls = DisplayServer.is_touchscreen_available() or get_viewport_rect().size.x < 760.0 or OS.has_feature("web")
	_build_ui()
	queue_redraw()


func _process(delta: float) -> void:
	if result_started:
		return
	remaining_time = maxf(0.0, remaining_time - delta)
	elapsed_time += delta
	move_cooldown = maxf(0.0, move_cooldown - delta)
	guard_move_timer += delta
	hit_grace = maxf(0.0, hit_grace - delta)
	if move_cooldown <= 0.0:
		var direction := _keyboard_direction()
		if direction != Vector2i.ZERO:
			_try_move(direction)
			move_cooldown = 0.14
	if elapsed_time >= 80.0 and guard_positions.size() == 1:
		guard_positions.append(SECOND_ROUTE[0])
		guard_routes.append(SECOND_ROUTE)
		guard_route_indices.append(0)
		_show_feedback("又有一位管理員開始巡邏！")
		AudioBus.play_sfx("alert")
	var guard_interval := 0.78
	if elapsed_time >= 40.0:
		guard_interval = 0.58
	if elapsed_time >= 80.0:
		guard_interval = 0.42
	if guard_move_timer >= guard_interval:
		guard_move_timer = 0.0
		_advance_guards()
		_check_guard_collision()
	if remaining_time <= 0.0:
		_finish(false)
	_update_hud()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if result_started:
		return
	if event.is_action_pressed("interact"):
		_try_sit()


func _input(event: InputEvent) -> void:
	if result_started or not show_touch_controls:
		return
	var local_position := Vector2.ZERO
	if event is InputEventScreenTouch:
		if event.pressed:
			var direction := _touch_direction_at(event.position)
			if direction != Vector2i.ZERO:
				active_touch_id = event.index
				_set_touch_direction(direction)
		elif event.index == active_touch_id:
			active_touch_id = -1
			touch_direction = Vector2i.ZERO
	elif event is InputEventScreenDrag and event.index == active_touch_id:
		local_position = event.position
		touch_direction = _touch_direction_at(local_position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var direction := _touch_direction_at(event.position)
			if direction != Vector2i.ZERO:
				mouse_steering = true
				_set_touch_direction(direction)
		elif mouse_steering:
			mouse_steering = false
			touch_direction = Vector2i.ZERO
	elif event is InputEventMouseMotion and mouse_steering:
		local_position = event.position
		touch_direction = _touch_direction_at(local_position)


func _draw() -> void:
	var size := get_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color("e8dfcb"))
	var reserve_bottom := 176.0 if show_touch_controls else 36.0
	var area := Rect2(Vector2(18, 80), Vector2(maxf(0.0, size.x - 36), maxf(0.0, size.y - 80 - reserve_bottom)))
	var tile := minf(area.size.x / 13.0, area.size.y / 9.0)
	var origin := area.position + (area.size - Vector2(13, 9) * tile) * 0.5
	for row in GRID.size():
		for column in GRID[row].length():
			var cell := Vector2i(column, row)
			var rect := Rect2(origin + Vector2(column, row) * tile, Vector2.ONE * tile)
			if GRID[row][column] == "#":
				_draw_shelf(rect, tile)
			else:
				var floor_color := FLOOR_A if (row + column) % 2 == 0 else FLOOR_B
				draw_rect(rect, floor_color)
				draw_rect(rect, Color("d6cbb8"), false, 1)
				if cell == GOAL:
					_draw_seat(rect, tile)
	for student in STUDENTS:
		_draw_student(_cell_rect(origin, tile, student), tile)
	for note in NOTES:
		if not collected_notes.has(note):
			_draw_notebook(_cell_rect(origin, tile, note), tile)
	for guard_pos in guard_positions:
		_draw_guard(_cell_rect(origin, tile, guard_pos), tile)
	_draw_player(_cell_rect(origin, tile, player_pos), tile)


func _build_ui() -> void:
	var header := HBoxContainer.new()
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 18
	header.offset_top = 12
	header.offset_right = -18
	header.offset_bottom = 60
	header.add_theme_constant_override("separation", 18)
	add_child(header)
	hud_label = Label.new()
	hud_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_label.add_theme_font_size_override("font_size", 20)
	hud_label.add_theme_color_override("font_color", INK)
	header.add_child(hud_label)
	var hint := Label.new()
	hint.text = "找到空位　E / 空白鍵坐下"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color("52606a"))
	header.add_child(hint)
	feedback_label = Label.new()
	feedback_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	feedback_label.position = Vector2(-160, 72)
	feedback_label.custom_minimum_size = Vector2(320, 42)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_font_size_override("font_size", 24)
	feedback_label.add_theme_color_override("font_color", Color("a54337"))
	add_child(feedback_label)
	if show_touch_controls:
		_build_touch_controls()


func _keyboard_direction() -> Vector2i:
	if Input.is_action_pressed("move_up"):
		return Vector2i.UP
	if Input.is_action_pressed("move_down"):
		return Vector2i.DOWN
	if Input.is_action_pressed("move_left"):
		return Vector2i.LEFT
	if Input.is_action_pressed("move_right"):
		return Vector2i.RIGHT
	return touch_direction


func _build_touch_controls() -> void:
	var pad := GridContainer.new()
	pad.columns = 3
	pad.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	pad.offset_left = 16
	pad.offset_top = -178
	pad.offset_right = 186
	pad.offset_bottom = -8
	pad.add_theme_constant_override("h_separation", 4)
	pad.add_theme_constant_override("v_separation", 4)
	add_child(pad)
	pad.add_child(_touch_spacer())
	pad.add_child(_touch_button("▲"))
	pad.add_child(_touch_spacer())
	pad.add_child(_touch_button("◀"))
	pad.add_child(_touch_spacer())
	pad.add_child(_touch_button("▶"))
	pad.add_child(_touch_spacer())
	pad.add_child(_touch_button("▼"))
	pad.add_child(_touch_spacer())
	var interact_button := Button.new()
	interact_button.text = "坐下"
	interact_button.custom_minimum_size = Vector2(132, 68)
	interact_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	interact_button.offset_left = -150
	interact_button.offset_top = -82
	interact_button.offset_right = -16
	interact_button.offset_bottom = -8
	interact_button.add_theme_font_size_override("font_size", 20)
	var seat_button_style := _touch_button_style(Color("efb953"))
	for style_name in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		interact_button.add_theme_stylebox_override(style_name, seat_button_style)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color"]:
		interact_button.add_theme_color_override(color_name, Color.BLACK)
	interact_button.pressed.connect(_try_sit)
	interact_button.pressed.connect(func() -> void: AudioBus.play_sfx("click"))
	add_child(interact_button)


func _touch_spacer() -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(54, 54)
	return spacer


func _touch_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(54, 54)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 22)
	var direction_button_style := _touch_button_style(Color("d6e6ef"))
	for style_name in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(style_name, direction_button_style)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color"]:
		button.add_theme_color_override(color_name, Color.BLACK)
	button.button_down.connect(func() -> void: AudioBus.play_sfx("click"))
	return button


func _touch_direction_at(position: Vector2) -> Vector2i:
	var control_size := get_rect().size
	var pad_rect := Rect2(Vector2(16, control_size.y - 178), Vector2(170, 170))
	if not pad_rect.has_point(position):
		return Vector2i.ZERO
	var delta := position - pad_rect.get_center()
	if delta.length() < 13.0:
		return Vector2i.ZERO
	if absf(delta.x) > absf(delta.y):
		return Vector2i.LEFT if delta.x < 0.0 else Vector2i.RIGHT
	return Vector2i.UP if delta.y < 0.0 else Vector2i.DOWN


func _set_touch_direction(direction: Vector2i) -> void:
	if touch_direction != direction:
		touch_direction = direction
		AudioBus.play_sfx("click")


func _touch_button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("8da49a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(13)
	style.set_content_margin_all(5)
	return style


func _advance_guards() -> void:
	for i in guard_positions.size():
		var route: Array = guard_routes[i]
		var route_index: int = guard_route_indices[i]
		route_index = (route_index + 1) % route.size()
		guard_route_indices[i] = route_index
		guard_positions[i] = route[route_index]


func _try_move(direction: Vector2i) -> void:
	var next := player_pos + direction
	if not _is_open(next):
		AudioBus.play_sfx("bump")
		return
	if STUDENTS.has(next):
		AudioBus.play_sfx("bump")
		_show_feedback("前面有同學佔位！")
		return
	player_pos = next
	for note in NOTES:
		if player_pos == note and not collected_notes.has(note):
			collected_notes.append(note)
			notebooks += 1
			score += 5
			_show_feedback("筆記本 +5")
			AudioBus.play_sfx("pickup")
	_check_guard_collision()


func _try_sit() -> void:
	if player_pos.distance_to(GOAL) <= 1.0:
		score += 10
		var bonus := int(floor(remaining_time)) * 2
		score += bonus
		_finish(true, bonus)
	else:
		AudioBus.play_sfx("click")
		_show_feedback("先找到發光的空位！")


func _check_guard_collision() -> void:
	if not guard_positions.has(player_pos) or hit_grace > 0.0:
		return
	lives -= 1
	hit_grace = 1.3
	AudioBus.play_sfx("hit")
	_show_feedback("管理員注意到你了！")
	if lives <= 0:
		_finish(false)


func _is_open(cell: Vector2i) -> bool:
	return cell.y >= 0 and cell.y < GRID.size() and cell.x >= 0 and cell.x < GRID[cell.y].length() and GRID[cell.y][cell.x] != "#"


func _finish(did_win: bool, bonus: int = 0) -> void:
	if result_started:
		return
	result_started = true
	if did_win:
		AudioBus.play_sfx("win")
	Session.finish_run(did_win, score, notebooks, bonus)
	get_tree().change_scene_to_file(RESULT_SCENE)


func _update_hud() -> void:
	if hud_label == null:
		return
	var seconds := int(ceil(remaining_time))
	if seconds != _hud_last_second:
		hud_label.text = "分數  %d　　 時間  %02d:%02d　　 生命  %s" % [score, seconds / 60, seconds % 60, "♥".repeat(lives) + "♡".repeat(3 - lives)]
		_hud_last_second = seconds


func _show_feedback(message: String) -> void:
	feedback_label.text = message
	feedback_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(feedback_label, "modulate:a", 0.0, 0.25)


func _cell_rect(origin: Vector2, tile: float, cell: Vector2i) -> Rect2:
	return Rect2(origin + Vector2(cell) * tile, Vector2.ONE * tile)


func _draw_shelf(rect: Rect2, tile: float) -> void:
	draw_rect(rect, WALL)
	draw_rect(Rect2(rect.position + Vector2(tile * 0.11, tile * 0.12), Vector2(tile * 0.78, tile * 0.72)), Color("927352"))
	for i in 3:
		var book_rect := Rect2(rect.position + Vector2(tile * (0.18 + i * 0.22), tile * 0.2), Vector2(tile * 0.15, tile * 0.55))
		draw_rect(book_rect, [Color("b25a46"), Color("547c78"), Color("d7b15d")][i])


func _draw_seat(rect: Rect2, tile: float) -> void:
	draw_rect(rect.grow(-tile * 0.08), Color("f7dc8b"))
	draw_rect(Rect2(rect.position + Vector2(tile * 0.23, tile * 0.16), Vector2(tile * 0.54, tile * 0.45)), Color("4b8d80"))
	draw_rect(Rect2(rect.position + Vector2(tile * 0.25, tile * 0.64), Vector2(tile * 0.5, tile * 0.14)), Color("315b56"))


func _draw_notebook(rect: Rect2, tile: float) -> void:
	draw_rect(Rect2(rect.position + Vector2(tile * 0.27, tile * 0.2), Vector2(tile * 0.46, tile * 0.6)), Color("f9fbf8"))
	draw_rect(Rect2(rect.position + Vector2(tile * 0.38, tile * 0.23), Vector2(tile * 0.08, tile * 0.54)), Color("d86d55"))
	draw_line(rect.position + Vector2(tile * 0.52, tile * 0.36), rect.position + Vector2(tile * 0.66, tile * 0.36), Color("9eb7ac"), 1.5)
	draw_line(rect.position + Vector2(tile * 0.52, tile * 0.49), rect.position + Vector2(tile * 0.66, tile * 0.49), Color("9eb7ac"), 1.5)


func _draw_student(rect: Rect2, tile: float) -> void:
	draw_rect(Rect2(rect.position + Vector2(tile * 0.12, tile * 0.67), Vector2(tile * 0.76, tile * 0.17)), Color("8b684b"))
	draw_circle(rect.position + Vector2(tile * 0.5, tile * 0.39), tile * 0.17, Color("d7a27b"))
	draw_rect(Rect2(rect.position + Vector2(tile * 0.31, tile * 0.47), Vector2(tile * 0.38, tile * 0.2)), Color("658b84"))


func _draw_guard(rect: Rect2, tile: float) -> void:
	draw_circle(rect.get_center(), tile * 0.34, Color("c7594c"))
	draw_circle(rect.get_center() + Vector2(0, -tile * 0.07), tile * 0.19, Color("f3d4b1"))
	draw_rect(Rect2(rect.get_center() + Vector2(-tile * 0.2, tile * 0.1), Vector2(tile * 0.4, tile * 0.19)), Color("31516b"))


func _draw_player(rect: Rect2, tile: float) -> void:
	if hit_grace > 0.0 and int(Time.get_ticks_msec() / 100) % 2 == 0:
		return
	draw_circle(rect.get_center(), tile * 0.34, Color("4b83a0"))
	draw_circle(rect.get_center() + Vector2(0, -tile * 0.08), tile * 0.18, Color("edc7a0"))
	draw_rect(Rect2(rect.get_center() + Vector2(-tile * 0.19, tile * 0.08), Vector2(tile * 0.38, tile * 0.21)), Color("e5b954"))
