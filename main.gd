extends Control

signal round_transition_finished

const Backdrop := preload("res://backdrop.gd")
const MarkCell := preload("res://mark_cell.gd")
const WinLine := preload("res://win_line.gd")

var PAPER := Color("eee9dc")
var PANEL := Color("20282c")
var CELL := Color("f6f1e7")
var CELL_HOVER := Color("e2dccb")
var X_COLOR := Color("2f6793")
var O_COLOR := Color("c95135")
var WIN_COLOR := Color("f0d77f")
var TEXT := Color("20282c")
var MUTED := Color("69716e")
var ACCENT := Color("d5a82e")
var ACCENT_TEXT := Color("20282c")
var SHADOW := Color("20282c")
var CONTROL_ALT := Color("dae4e5")
var CONTROL_HOVER := Color("e2dccb")
var CONTROL_PRESSED := Color("eadb9d")
var ACCENT_HOVER := Color("e4bf58")
var SHEET_TURN := Color("d8cfb9")
const SAVE_PATH := "user://match_scores.cfg"
const ROUND_TURN_OUT_SECONDS := 0.22
const ROUND_TURN_IN_SECONDS := 0.30
const CPU_LEVELS := ["CASUAL", "TACTICAL", "PERFECT"]
const WIN_LINES := [
	[0, 1, 2], [3, 4, 5], [6, 7, 8],
	[0, 3, 6], [1, 4, 7], [2, 5, 8],
	[0, 4, 8], [2, 4, 6]
]

var board: Array[String] = ["", "", "", "", "", "", "", "", ""]
var turn := "X"
var game_over := false
var cpu_thinking := false
var round_transitioning := false
var vs_cpu := true
var cpu_level := 1
var round_id := 0
var reset_request_id := 0
var reset_armed := false
var dark_mode := false
var theme_preference := "system"
var winning_cells: Array[int] = []
var scores := {
	"cpu": {"x": 0, "o": 0, "draws": 0},
	"local": {"x": 0, "o": 0, "draws": 0}
}

var cells: Array = []
var status_label: Label
var score_x_value: Label
var score_draw_value: Label
var score_o_value: Label
var x_name_label: Label
var o_name_label: Label
var score_x_card: PanelContainer
var score_o_card: PanelContainer
var cpu_button: Button
var local_button: Button
var difficulty_button: Button
var theme_button: Button
var round_button: Button
var clear_button: Button
var about_button: Button
var about_overlay: Control
var about_close_button: Button
var about_body_label: Label
var backdrop: Control
var board_card: PanelContainer
var win_line: Control
var round_transition_tween: Tween
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	_load_scores()
	dark_mode = _resolved_dark_mode(theme_preference, _browser_prefers_dark())
	_apply_palette_values()
	_build_ui()
	_update_ui()
	call_deferred("_play_intro")


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	var key: String = event.as_text_keycode()
	if about_overlay and about_overlay.visible:
		if key == "Escape":
			_hide_about()
		return
	if key in ["1", "2", "3", "4", "5", "6", "7", "8", "9"]:
		_cell_pressed(int(key) - 1)
	elif key == "R":
		_start_new_round()
	elif key == "D" and vs_cpu:
		_cycle_difficulty()
	elif key == "T":
		_toggle_theme()


func _build_ui() -> void:
	backdrop = Backdrop.new()
	backdrop.set_palette(PAPER, TEXT, X_COLOR, O_COLOR, ACCENT)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var content_column := VBoxContainer.new()
	content_column.add_theme_constant_override("separation", 11)
	content_column.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(content_column)

	var eyebrow := Label.new()
	eyebrow.text = "PENCIL & PAPER"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.add_theme_color_override("font_color", X_COLOR)
	content_column.add_child(eyebrow)

	var title := Label.new()
	title.text = "THREE IN A ROW"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", TEXT)
	content_column.add_child(title)

	var mode_row := HBoxContainer.new()
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_row.add_theme_constant_override("separation", 8)
	content_column.add_child(mode_row)
	cpu_button = _mode_button("VS CPU", true)
	cpu_button.pressed.connect(_set_mode.bind(true))
	mode_row.add_child(cpu_button)
	local_button = _mode_button("TWO PLAYERS", false)
	local_button.pressed.connect(_set_mode.bind(false))
	mode_row.add_child(local_button)
	difficulty_button = Button.new()
	difficulty_button.custom_minimum_size = Vector2(142, 42)
	difficulty_button.focus_mode = Control.FOCUS_ALL
	difficulty_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	difficulty_button.tooltip_text = "Change CPU difficulty (D)"
	difficulty_button.add_theme_font_size_override("font_size", 13)
	_set_button_text_colors(difficulty_button, TEXT)
	_set_pressed_text_color(difficulty_button, ACCENT_TEXT)
	difficulty_button.add_theme_stylebox_override("normal", _button_style(CONTROL_ALT))
	difficulty_button.add_theme_stylebox_override("hover", _button_style(CONTROL_PRESSED))
	difficulty_button.add_theme_stylebox_override("pressed", _button_style(X_COLOR))
	difficulty_button.add_theme_stylebox_override("focus", _focus_style(X_COLOR))
	difficulty_button.pressed.connect(_cycle_difficulty)
	mode_row.add_child(difficulty_button)
	theme_button = Button.new()
	theme_button.custom_minimum_size = Vector2(106, 42)
	theme_button.focus_mode = Control.FOCUS_ALL
	theme_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	theme_button.add_theme_font_size_override("font_size", 12)
	_set_button_text_colors(theme_button, TEXT)
	_set_pressed_text_color(theme_button, ACCENT_TEXT)
	theme_button.add_theme_stylebox_override("normal", _button_style(PAPER))
	theme_button.add_theme_stylebox_override("hover", _button_style(CONTROL_HOVER))
	theme_button.add_theme_stylebox_override("pressed", _button_style(ACCENT))
	theme_button.add_theme_stylebox_override("focus", _focus_style(X_COLOR))
	theme_button.pressed.connect(_toggle_theme)
	mode_row.add_child(theme_button)

	var scoreboard := HBoxContainer.new()
	scoreboard.alignment = BoxContainer.ALIGNMENT_CENTER
	scoreboard.add_theme_constant_override("separation", 10)
	content_column.add_child(scoreboard)
	var x_card := _score_card("YOU (X)", X_COLOR)
	score_x_card = x_card[0]
	x_name_label = x_card[1]
	score_x_value = x_card[2]
	scoreboard.add_child(score_x_card)
	var draw_card := _score_card("DRAWS", MUTED)
	score_draw_value = draw_card[2]
	scoreboard.add_child(draw_card[0])
	var o_card := _score_card("CPU (O)", O_COLOR)
	score_o_card = o_card[0]
	o_name_label = o_card[1]
	score_o_value = o_card[2]
	scoreboard.add_child(score_o_card)

	board_card = PanelContainer.new()
	board_card.custom_minimum_size = Vector2(492, 492)
	board_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_card.add_theme_stylebox_override("panel", _panel_style())
	content_column.add_child(board_card)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	board_card.add_child(grid)
	for i in 9:
		var button := MarkCell.new()
		button.custom_minimum_size = Vector2(150, 150)
		button.set_underprint(SHADOW)
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_stylebox_override("normal", _cell_style(CELL))
		button.add_theme_stylebox_override("hover", _cell_style(CELL_HOVER))
		button.add_theme_stylebox_override("pressed", _cell_style(CONTROL_PRESSED))
		button.add_theme_stylebox_override("disabled", _cell_style(CELL))
		button.add_theme_stylebox_override("focus", _focus_style(X_COLOR))
		button.tooltip_text = "Square %d — press %d" % [i + 1, i + 1]
		button.pressed.connect(_cell_pressed.bind(i))
		grid.add_child(button)
		cells.append(button)
	win_line = WinLine.new()
	win_line.set_palette(TEXT, ACCENT)
	win_line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_card.add_child(win_line)

	var status_panel := PanelContainer.new()
	status_panel.custom_minimum_size = Vector2(420, 42)
	status_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	status_panel.add_theme_stylebox_override("panel", _status_style())
	content_column.add_child(status_panel)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 19)
	status_label.add_theme_color_override("font_color", PAPER)
	status_panel.add_child(status_label)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 10)
	content_column.add_child(controls)
	round_button = Button.new()
	round_button.text = "NEW ROUND"
	round_button.custom_minimum_size = Vector2(250, 50)
	round_button.focus_mode = Control.FOCUS_ALL
	round_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	round_button.add_theme_font_size_override("font_size", 16)
	round_button.add_theme_stylebox_override("normal", _button_style(ACCENT))
	_set_button_text_colors(round_button, ACCENT_TEXT)
	round_button.add_theme_color_override("font_focus_color", TEXT)
	round_button.add_theme_stylebox_override("hover", _button_style(ACCENT_HOVER))
	round_button.add_theme_stylebox_override("focus", _focus_style(X_COLOR))
	round_button.pressed.connect(_start_new_round)
	controls.add_child(round_button)
	clear_button = Button.new()
	clear_button.text = "RESET SCORES"
	clear_button.custom_minimum_size = Vector2(190, 50)
	clear_button.focus_mode = Control.FOCUS_ALL
	clear_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clear_button.add_theme_font_size_override("font_size", 14)
	_set_button_text_colors(clear_button, MUTED)
	clear_button.add_theme_stylebox_override("normal", _button_style(PAPER))
	clear_button.add_theme_stylebox_override("hover", _button_style(CONTROL_HOVER))
	clear_button.add_theme_stylebox_override("focus", _focus_style(O_COLOR))
	clear_button.pressed.connect(_request_score_reset)
	controls.add_child(clear_button)
	about_button = Button.new()
	about_button.text = "ABOUT"
	about_button.custom_minimum_size = Vector2(110, 50)
	about_button.focus_mode = Control.FOCUS_ALL
	about_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	about_button.tooltip_text = "Open credits and license information"
	about_button.add_theme_font_size_override("font_size", 14)
	_set_button_text_colors(about_button, TEXT)
	about_button.add_theme_stylebox_override("normal", _button_style(PAPER))
	about_button.add_theme_stylebox_override("hover", _button_style(CONTROL_ALT))
	about_button.add_theme_stylebox_override("focus", _focus_style(X_COLOR))
	about_button.pressed.connect(_show_about)
	controls.add_child(about_button)

	var hint := Label.new()
	hint.text = "KEYS 1–9: MARK   /   R: NEW ROUND   /   D: DIFFICULTY   /   T: THEME"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", MUTED)
	content_column.add_child(hint)

	_build_about_overlay()


func _build_about_overlay() -> void:
	about_overlay = Control.new()
	about_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	about_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	about_overlay.visible = false
	add_child(about_overlay)

	var scrim := ColorRect.new()
	scrim.color = Color(SHADOW, 0.86)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	about_overlay.add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	about_overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 410)
	card.add_theme_stylebox_override("panel", _about_style())
	center.add_child(card)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 16)
	card.add_child(stack)

	var title := Label.new()
	title.text = "ABOUT & CREDITS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", TEXT)
	stack.add_child(title)

	var rule := HSeparator.new()
	rule.add_theme_constant_override("separation", 2)
	stack.add_child(rule)

	about_body_label = Label.new()
	var game_version := str(ProjectSettings.get_setting("application/config/version", "development"))
	about_body_label.text = (
		"THREE IN A ROW is a small Godot web game built to test "
		+ "infra-tools agentic VMs and Godot web development.\n\n"
		+ "CREATED BY\nLoren Crain, with coding agents running on infra-tools\n\n"
		+ "BUILT WITH\nGodot Engine\n\n"
		+ "VERSION %s\n\n" % game_version
		+ "Copyright © 2026 Loren Crain\n"
		+ "Licensed under the Apache License, Version 2.0."
	)
	about_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	about_body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	about_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about_body_label.add_theme_font_size_override("font_size", 16)
	about_body_label.add_theme_color_override("font_color", TEXT)
	stack.add_child(about_body_label)

	about_close_button = Button.new()
	about_close_button.text = "BACK TO GAME"
	about_close_button.custom_minimum_size = Vector2(210, 48)
	about_close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	about_close_button.focus_mode = Control.FOCUS_ALL
	about_close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	about_close_button.add_theme_font_size_override("font_size", 15)
	_set_button_text_colors(about_close_button, ACCENT_TEXT)
	about_close_button.add_theme_color_override("font_focus_color", TEXT)
	about_close_button.add_theme_stylebox_override("normal", _button_style(ACCENT))
	about_close_button.add_theme_stylebox_override("hover", _button_style(ACCENT_HOVER))
	about_close_button.add_theme_stylebox_override("focus", _focus_style(X_COLOR))
	about_close_button.pressed.connect(_hide_about)
	stack.add_child(about_close_button)


func _mode_button(label_text: String, selected: bool) -> Button:
	var button := Button.new()
	button.text = label_text
	button.toggle_mode = true
	button.button_pressed = selected
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(150, 42)
	button.add_theme_font_size_override("font_size", 14)
	_set_button_text_colors(button, TEXT)
	_set_pressed_text_color(button, ACCENT_TEXT)
	button.add_theme_stylebox_override("normal", _button_style(PAPER))
	button.add_theme_stylebox_override("hover", _button_style(CONTROL_HOVER))
	button.add_theme_stylebox_override("pressed", _button_style(ACCENT))
	button.add_theme_stylebox_override("focus", _focus_style(X_COLOR))
	return button


func _set_button_text_colors(button: Button, color: Color) -> void:
	for property in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_hover_pressed_color",
		"font_focus_color"
	]:
		button.add_theme_color_override(property, color)


func _set_pressed_text_color(button: Button, color: Color) -> void:
	button.add_theme_color_override("font_pressed_color", color)
	button.add_theme_color_override("font_hover_pressed_color", color)


func _score_card(label_text: String, color: Color) -> Array:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(145, 67)
	panel.add_theme_stylebox_override("panel", _score_card_style(color, false))
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	panel.add_child(stack)
	var name := Label.new()
	name.text = label_text
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", 11)
	name.add_theme_color_override("font_color", color)
	stack.add_child(name)
	var value := Label.new()
	value.text = "0"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 24)
	value.add_theme_color_override("font_color", TEXT)
	stack.add_child(value)
	return [panel, name, value]


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = TEXT
	style.shadow_color = Color(SHADOW, 0.52)
	style.shadow_size = 2
	style.shadow_offset = Vector2(8.0, 8.0)
	return style


func _cell_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = TEXT
	return style


func _button_style(color: Color) -> StyleBoxFlat:
	var style := _cell_style(color)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _focus_style(color: Color) -> StyleBoxFlat:
	var style := _button_style(PAPER)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = color
	style.expand_margin_left = 3
	style.expand_margin_top = 3
	style.expand_margin_right = 3
	style.expand_margin_bottom = 3
	return style


func _status_style() -> StyleBoxFlat:
	var style := _cell_style(TEXT)
	style.corner_radius_top_left = 1
	style.corner_radius_top_right = 1
	style.corner_radius_bottom_left = 1
	style.corner_radius_bottom_right = 1
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _score_card_style(color: Color, active: bool) -> StyleBoxFlat:
	var style := _cell_style(CELL)
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	if active:
		style.bg_color = color.darkened(0.58) if dark_mode else color.lightened(0.72)
		style.border_color = TEXT
		style.border_width_bottom = 7
	return style


func _about_style() -> StyleBoxFlat:
	var style := _cell_style(PAPER)
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.shadow_color = Color(SHADOW, 0.62)
	style.shadow_size = 3
	style.shadow_offset = Vector2(10.0, 10.0)
	return style


func _cell_pressed(index: int) -> void:
	if index < 0 or index >= board.size():
		return
	if game_over or cpu_thinking or round_transitioning or board[index] != "":
		return
	if vs_cpu and turn == "O":
		return
	_place_mark(index)
	if vs_cpu and not game_over and turn == "O":
		_take_cpu_turn(round_id)


func _place_mark(index: int) -> void:
	board[index] = turn
	var placed_mark := turn
	winning_cells = _winning_line(turn)
	if not winning_cells.is_empty():
		game_over = true
		_current_score()[turn.to_lower()] += 1
		_save_scores()
	elif not board.has(""):
		game_over = true
		_current_score()["draws"] += 1
		_save_scores()
	else:
		turn = "O" if turn == "X" else "X"
	_update_ui()
	_animate_mark(index)
	if not winning_cells.is_empty():
		win_line.show_win(winning_cells, X_COLOR if placed_mark == "X" else O_COLOR)
		_animate_victory()


func _take_cpu_turn(expected_round: int) -> void:
	cpu_thinking = true
	_update_ui()
	await get_tree().create_timer(0.38).timeout
	if expected_round != round_id or game_over or not vs_cpu:
		cpu_thinking = false
		_update_ui()
		return
	var move := _choose_cpu_move()
	cpu_thinking = false
	if move >= 0:
		_place_mark(move)


func _choose_cpu_move() -> int:
	match cpu_level:
		0:
			return _random_empty_cell()
		1:
			return _tactical_cpu_move()
		_:
			return _best_cpu_move()


func _tactical_cpu_move() -> int:
	var winning_move := _tactical_move("O")
	if winning_move >= 0:
		return winning_move
	var blocking_move := _tactical_move("X")
	if blocking_move >= 0:
		return blocking_move
	if board[4] == "":
		return 4
	var open_corners: Array[int] = []
	for index in [0, 2, 6, 8]:
		if board[index] == "":
			open_corners.append(index)
	if not open_corners.is_empty():
		return open_corners[rng.randi_range(0, open_corners.size() - 1)]
	return _random_empty_cell()


func _tactical_move(mark: String) -> int:
	for index in 9:
		if board[index] != "":
			continue
		board[index] = mark
		var wins := not _winning_line(mark).is_empty()
		board[index] = ""
		if wins:
			return index
	return -1


func _random_empty_cell() -> int:
	var open_cells: Array[int] = []
	for index in 9:
		if board[index] == "":
			open_cells.append(index)
	if open_cells.is_empty():
		return -1
	return open_cells[rng.randi_range(0, open_cells.size() - 1)]


func _best_cpu_move() -> int:
	var best_score := -100
	var best_move := -1
	for i in 9:
		if board[i] == "":
			board[i] = "O"
			var score := _minimax(false, 0)
			board[i] = ""
			if score > best_score:
				best_score = score
				best_move = i
	return best_move


func _minimax(is_maximizing: bool, depth: int) -> int:
	if not _winning_line("O").is_empty():
		return 10 - depth
	if not _winning_line("X").is_empty():
		return depth - 10
	if not board.has(""):
		return 0
	if is_maximizing:
		var best := -100
		for i in 9:
			if board[i] == "":
				board[i] = "O"
				best = maxi(best, _minimax(false, depth + 1))
				board[i] = ""
		return best
	var best := 100
	for i in 9:
		if board[i] == "":
			board[i] = "X"
			best = mini(best, _minimax(true, depth + 1))
			board[i] = ""
	return best


func _winning_line(mark: String) -> Array[int]:
	for line in WIN_LINES:
		if board[line[0]] == mark and board[line[1]] == mark and board[line[2]] == mark:
			return [line[0], line[1], line[2]]
	return []


func _update_ui() -> void:
	if not status_label:
		return
	for i in 9:
		cells[i].set_mark(board[i], X_COLOR if board[i] == "X" else O_COLOR)
		var fill := WIN_COLOR if i in winning_cells else CELL
		cells[i].add_theme_stylebox_override("disabled", _cell_style(fill))
		cells[i].disabled = board[i] != "" or game_over or cpu_thinking or round_transitioning
	if round_transitioning:
		status_label.text = "TURNING THE PAGE…"
		round_button.text = "ONE MOMENT"
	elif game_over:
		status_label.text = "DRAW — BOARD FULL" if winning_cells.is_empty() else _win_message(turn)
		round_button.text = "PLAY AGAIN"
	elif cpu_thinking:
		status_label.text = "CPU IS THINKING…"
		round_button.text = "NEW ROUND"
	else:
		status_label.text = _turn_message()
		round_button.text = "NEW ROUND"
	status_label.add_theme_color_override("font_color", PAPER)
	var score: Dictionary = _current_score()
	score_x_value.text = str(score["x"])
	score_o_value.text = str(score["o"])
	score_draw_value.text = str(score["draws"])
	x_name_label.text = "YOU (X)" if vs_cpu else "PLAYER X"
	o_name_label.text = "CPU (O)" if vs_cpu else "PLAYER O"
	cpu_button.button_pressed = vs_cpu
	local_button.button_pressed = not vs_cpu
	difficulty_button.visible = vs_cpu
	difficulty_button.text = "DIFFICULTY: %s" % _difficulty_name()
	theme_button.text = "LIGHT MODE" if dark_mode else "DARK MODE"
	theme_button.tooltip_text = "Switch to %s mode (T)" % ("light" if dark_mode else "dark")
	score_x_card.add_theme_stylebox_override("panel", _score_card_style(X_COLOR, not game_over and not round_transitioning and turn == "X"))
	score_o_card.add_theme_stylebox_override("panel", _score_card_style(O_COLOR, not game_over and not round_transitioning and turn == "O"))
	round_button.disabled = round_transitioning
	clear_button.disabled = round_transitioning
	cpu_button.disabled = round_transitioning
	local_button.disabled = round_transitioning
	difficulty_button.disabled = round_transitioning
	theme_button.disabled = round_transitioning
	if reset_armed:
		clear_button.text = "CONFIRM RESET"
		clear_button.add_theme_color_override("font_color", O_COLOR)
	else:
		clear_button.text = "RESET SCORES"
		clear_button.add_theme_color_override("font_color", MUTED)


func _win_message(mark: String) -> String:
	if vs_cpu:
		return "YOU WIN" if mark == "X" else "CPU WINS"
	return "PLAYER %s WINS" % mark


func _turn_message() -> String:
	if vs_cpu:
		return "YOUR TURN — PLACE X" if turn == "X" else "CPU TO MOVE"
	return "PLAYER %s TO MOVE" % turn


func _show_about() -> void:
	about_overlay.visible = true
	about_overlay.move_to_front()
	about_close_button.grab_focus()


func _hide_about() -> void:
	about_overlay.visible = false
	about_button.grab_focus()


func _set_mode(cpu_mode: bool) -> void:
	if round_transitioning:
		return
	if vs_cpu == cpu_mode:
		_update_ui()
		return
	_disarm_reset()
	vs_cpu = cpu_mode
	_start_new_round()


func _cycle_difficulty() -> void:
	if round_transitioning:
		return
	cpu_level = (cpu_level + 1) % CPU_LEVELS.size()
	_save_scores()
	_update_ui()
	var tween := create_tween()
	difficulty_button.pivot_offset = difficulty_button.size * 0.5
	tween.tween_property(difficulty_button, "scale", Vector2(1.05, 1.05), 0.08)
	tween.tween_property(difficulty_button, "scale", Vector2.ONE, 0.13)


func _toggle_theme() -> void:
	if round_transitioning:
		return
	_set_dark_mode(not dark_mode, true)


func _set_dark_mode(enabled: bool, remember_choice: bool) -> void:
	dark_mode = enabled
	if remember_choice:
		theme_preference = "dark" if dark_mode else "light"
		_save_scores()
	_apply_palette_values()
	call_deferred("_rebuild_ui_for_theme")


func _rebuild_ui_for_theme() -> void:
	for child in get_children():
		child.free()
	cells.clear()
	_build_ui()
	_update_ui()
	theme_button.grab_focus()


func _resolved_dark_mode(preference: String, system_prefers_dark: bool) -> bool:
	if preference == "dark":
		return true
	if preference == "light":
		return false
	return system_prefers_dark


func _browser_prefers_dark() -> bool:
	if not OS.has_feature("web"):
		return false
	var result = JavaScriptBridge.eval(
		"window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches",
		true
	)
	return bool(result)


func _apply_palette_values() -> void:
	if dark_mode:
		PAPER = Color("171b1d")
		PANEL = Color("0d1113")
		CELL = Color("22292c")
		CELL_HOVER = Color("303a3e")
		X_COLOR = Color("72acd0")
		O_COLOR = Color("eb8067")
		WIN_COLOR = Color("554922")
		TEXT = Color("e8e2d5")
		MUTED = Color("a5aaa5")
		ACCENT = Color("d8ad3d")
		ACCENT_TEXT = Color("171b1d")
		SHADOW = Color("050708")
		CONTROL_ALT = Color("273238")
		CONTROL_HOVER = Color("323c40")
		CONTROL_PRESSED = Color("5d5027")
		ACCENT_HOVER = Color("e8c45b")
		SHEET_TURN = Color("71808a")
	else:
		PAPER = Color("eee9dc")
		PANEL = Color("20282c")
		CELL = Color("f6f1e7")
		CELL_HOVER = Color("e2dccb")
		X_COLOR = Color("2f6793")
		O_COLOR = Color("c95135")
		WIN_COLOR = Color("f0d77f")
		TEXT = Color("20282c")
		MUTED = Color("69716e")
		ACCENT = Color("d5a82e")
		ACCENT_TEXT = Color("20282c")
		SHADOW = Color("20282c")
		CONTROL_ALT = Color("dae4e5")
		CONTROL_HOVER = Color("e2dccb")
		CONTROL_PRESSED = Color("eadb9d")
		ACCENT_HOVER = Color("e4bf58")
		SHEET_TURN = Color("d8cfb9")
	RenderingServer.set_default_clear_color(PAPER)


func _difficulty_name() -> String:
	return CPU_LEVELS[cpu_level]


func _start_new_round() -> void:
	if round_transitioning:
		return
	_disarm_reset()
	round_id += 1
	cpu_thinking = false
	round_transitioning = true
	_update_ui()
	board_card.pivot_offset = board_card.size * 0.5
	round_transition_tween = create_tween()
	round_transition_tween.tween_property(
		board_card,
		"scale",
		Vector2(0.035, 0.94),
		ROUND_TURN_OUT_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	round_transition_tween.parallel().tween_property(
		board_card,
		"rotation",
		-0.015,
		ROUND_TURN_OUT_SECONDS
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	round_transition_tween.parallel().tween_property(
		board_card,
		"modulate",
		SHEET_TURN,
		ROUND_TURN_OUT_SECONDS
	)
	round_transition_tween.tween_callback(_swap_round_sheet)
	round_transition_tween.tween_property(
		board_card,
		"scale",
		Vector2.ONE,
		ROUND_TURN_IN_SECONDS
	).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	round_transition_tween.parallel().tween_property(
		board_card,
		"rotation",
		0.0,
		ROUND_TURN_IN_SECONDS
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	round_transition_tween.parallel().tween_property(
		board_card,
		"modulate",
		Color.WHITE,
		ROUND_TURN_IN_SECONDS
	)
	round_transition_tween.tween_callback(_finish_round_transition)


func _swap_round_sheet() -> void:
	board = ["", "", "", "", "", "", "", "", ""]
	turn = "X"
	game_over = false
	winning_cells.clear()
	if win_line:
		win_line.clear_win()
	_update_ui()


func _finish_round_transition() -> void:
	board_card.scale = Vector2.ONE
	board_card.rotation = 0.0
	board_card.modulate = Color.WHITE
	round_transitioning = false
	round_transition_tween = null
	_update_ui()
	round_transition_finished.emit()


func _clear_score() -> void:
	var score: Dictionary = _current_score()
	score["x"] = 0
	score["o"] = 0
	score["draws"] = 0
	_save_scores()
	_start_new_round()


func _request_score_reset() -> void:
	if round_transitioning:
		return
	if reset_armed:
		_clear_score()
		return
	reset_armed = true
	reset_request_id += 1
	var expected_request := reset_request_id
	clear_button.text = "CONFIRM RESET"
	clear_button.add_theme_color_override("font_color", O_COLOR)
	await get_tree().create_timer(2.2).timeout
	if expected_request == reset_request_id and reset_armed:
		_disarm_reset()
		_update_ui()


func _disarm_reset() -> void:
	reset_armed = false
	reset_request_id += 1
	if clear_button:
		clear_button.text = "RESET SCORES"
		clear_button.add_theme_color_override("font_color", MUTED)


func _current_score() -> Dictionary:
	return scores["cpu" if vs_cpu else "local"]


func _load_scores() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for mode in ["cpu", "local"]:
		for key in ["x", "o", "draws"]:
			scores[mode][key] = maxi(0, int(config.get_value(mode, key, 0)))
	cpu_level = clampi(int(config.get_value("settings", "cpu_level", 1)), 0, CPU_LEVELS.size() - 1)
	var stored_theme := str(config.get_value("settings", "theme", "system"))
	theme_preference = stored_theme if stored_theme in ["system", "light", "dark"] else "system"


func _save_scores() -> void:
	var config := ConfigFile.new()
	for mode in ["cpu", "local"]:
		for key in ["x", "o", "draws"]:
			config.set_value(mode, key, scores[mode][key])
	config.set_value("settings", "cpu_level", cpu_level)
	config.set_value("settings", "theme", theme_preference)
	config.save(SAVE_PATH)


func _play_intro() -> void:
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.5)


func _animate_mark(index: int) -> void:
	var cell = cells[index]
	cell.reveal = 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(cell, "reveal", 1.0, 0.28)


func _animate_victory() -> void:
	board_card.pivot_offset = board_card.size * 0.5
	var tween := create_tween()
	tween.tween_property(board_card, "rotation", -0.008, 0.08).set_trans(Tween.TRANS_SINE)
	tween.tween_property(board_card, "rotation", 0.006, 0.08).set_trans(Tween.TRANS_SINE)
	tween.tween_property(board_card, "rotation", 0.0, 0.1).set_trans(Tween.TRANS_SINE)
