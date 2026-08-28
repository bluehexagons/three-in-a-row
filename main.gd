extends Control

const BG := Color("070b18")
const PANEL := Color("111a32")
const CELL := Color("182442")
const CELL_HOVER := Color("203158")
const X_COLOR := Color("69e6f5")
const O_COLOR := Color("ff8dc7")
const WIN_COLOR := Color("293e68")
const TEXT := Color("f3f6ff")
const MUTED := Color("9ca9c9")
const ACCENT := Color("6558f5")
const SAVE_PATH := "user://match_scores.cfg"
const WIN_LINES := [
	[0, 1, 2], [3, 4, 5], [6, 7, 8],
	[0, 3, 6], [1, 4, 7], [2, 5, 8],
	[0, 4, 8], [2, 4, 6]
]

var board: Array[String] = ["", "", "", "", "", "", "", "", ""]
var turn := "X"
var game_over := false
var cpu_thinking := false
var vs_cpu := true
var round_id := 0
var winning_cells: Array[int] = []
var scores := {
	"cpu": {"x": 0, "o": 0, "draws": 0},
	"local": {"x": 0, "o": 0, "draws": 0}
}

var cells: Array[Button] = []
var status_label: Label
var score_x_value: Label
var score_draw_value: Label
var score_o_value: Label
var x_name_label: Label
var o_name_label: Label
var cpu_button: Button
var local_button: Button
var round_button: Button


func _ready() -> void:
	_load_scores()
	_build_ui()
	_update_ui()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	var key: String = event.as_text_keycode()
	if key in ["1", "2", "3", "4", "5", "6", "7", "8", "9"]:
		_cell_pressed(int(key) - 1)
	elif key == "R":
		_start_new_round()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(column)

	var eyebrow := Label.new()
	eyebrow.text = "QUICK MATCH"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.add_theme_color_override("font_color", X_COLOR)
	column.add_child(eyebrow)

	var title := Label.new()
	title.text = "TIC-TAC-TOE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", TEXT)
	column.add_child(title)

	var mode_row := HBoxContainer.new()
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_row.add_theme_constant_override("separation", 8)
	column.add_child(mode_row)
	cpu_button = _mode_button("VS CPU", true)
	cpu_button.pressed.connect(_set_mode.bind(true))
	mode_row.add_child(cpu_button)
	local_button = _mode_button("2 PLAYERS", false)
	local_button.pressed.connect(_set_mode.bind(false))
	mode_row.add_child(local_button)

	var scoreboard := HBoxContainer.new()
	scoreboard.alignment = BoxContainer.ALIGNMENT_CENTER
	scoreboard.add_theme_constant_override("separation", 10)
	column.add_child(scoreboard)
	var x_card := _score_card("YOU", X_COLOR)
	x_name_label = x_card[1]
	score_x_value = x_card[2]
	scoreboard.add_child(x_card[0])
	var draw_card := _score_card("DRAWS", MUTED)
	score_draw_value = draw_card[2]
	scoreboard.add_child(draw_card[0])
	var o_card := _score_card("CPU", O_COLOR)
	o_name_label = o_card[1]
	score_o_value = o_card[2]
	scoreboard.add_child(o_card[0])

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(492, 492)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add_theme_stylebox_override("panel", _panel_style())
	column.add_child(card)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 9)
	grid.add_theme_constant_override("v_separation", 9)
	card.add_child(grid)
	for i in 9:
		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 150)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 68)
		button.add_theme_stylebox_override("normal", _cell_style(CELL))
		button.add_theme_stylebox_override("hover", _cell_style(CELL_HOVER))
		button.add_theme_stylebox_override("pressed", _cell_style(Color("121d37")))
		button.add_theme_stylebox_override("disabled", _cell_style(CELL))
		button.tooltip_text = "Square %d (keyboard: %d)" % [i + 1, i + 1]
		button.pressed.connect(_cell_pressed.bind(i))
		grid.add_child(button)
		cells.append(button)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 21)
	status_label.add_theme_color_override("font_color", TEXT)
	column.add_child(status_label)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 10)
	column.add_child(controls)
	round_button = Button.new()
	round_button.text = "NEW ROUND"
	round_button.custom_minimum_size = Vector2(250, 50)
	round_button.focus_mode = Control.FOCUS_NONE
	round_button.add_theme_font_size_override("font_size", 16)
	round_button.add_theme_stylebox_override("normal", _button_style(ACCENT))
	round_button.add_theme_stylebox_override("hover", _button_style(Color("766bf8")))
	round_button.pressed.connect(_start_new_round)
	controls.add_child(round_button)
	var clear_button := Button.new()
	clear_button.text = "RESET SCORE"
	clear_button.custom_minimum_size = Vector2(180, 50)
	clear_button.focus_mode = Control.FOCUS_NONE
	clear_button.add_theme_font_size_override("font_size", 14)
	clear_button.add_theme_color_override("font_color", MUTED)
	clear_button.add_theme_stylebox_override("normal", _button_style(Color("18223e")))
	clear_button.add_theme_stylebox_override("hover", _button_style(Color("202e50")))
	clear_button.pressed.connect(_clear_score)
	controls.add_child(clear_button)

	var hint := Label.new()
	hint.text = "Choose a square · Keys 1–9 · R starts a new round"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", MUTED)
	column.add_child(hint)


func _mode_button(label_text: String, selected: bool) -> Button:
	var button := Button.new()
	button.text = label_text
	button.toggle_mode = true
	button.button_pressed = selected
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(150, 42)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", _button_style(Color("141e38")))
	button.add_theme_stylebox_override("hover", _button_style(Color("1d2a4a")))
	button.add_theme_stylebox_override("pressed", _button_style(ACCENT))
	return button


func _score_card(label_text: String, color: Color) -> Array:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(145, 67)
	var style := _cell_style(Color("10182d"))
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel", style)
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
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_left = 24
	style.corner_radius_bottom_right = 24
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	return style


func _cell_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	return style


func _button_style(color: Color) -> StyleBoxFlat:
	var style := _cell_style(color)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _cell_pressed(index: int) -> void:
	if game_over or cpu_thinking or board[index] != "":
		return
	if vs_cpu and turn == "O":
		return
	_place_mark(index)
	if vs_cpu and not game_over and turn == "O":
		_take_cpu_turn(round_id)


func _place_mark(index: int) -> void:
	board[index] = turn
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


func _take_cpu_turn(expected_round: int) -> void:
	cpu_thinking = true
	_update_ui()
	await get_tree().create_timer(0.38).timeout
	if expected_round != round_id or game_over or not vs_cpu:
		cpu_thinking = false
		_update_ui()
		return
	var move := _best_cpu_move()
	cpu_thinking = false
	if move >= 0:
		_place_mark(move)


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
		cells[i].text = board[i]
		cells[i].add_theme_color_override("font_color", X_COLOR if board[i] == "X" else O_COLOR)
		cells[i].add_theme_color_override("font_disabled_color", X_COLOR if board[i] == "X" else O_COLOR)
		var fill := WIN_COLOR if i in winning_cells else CELL
		cells[i].add_theme_stylebox_override("disabled", _cell_style(fill))
		cells[i].disabled = board[i] != "" or game_over or cpu_thinking
	if game_over:
		status_label.text = "Draw — well played." if winning_cells.is_empty() else "%s wins the round!" % _player_name(turn)
		round_button.text = "PLAY AGAIN"
	elif cpu_thinking:
		status_label.text = "CPU is thinking…"
		round_button.text = "NEW ROUND"
	else:
		status_label.text = "%s, make your move." % _player_name(turn)
		round_button.text = "NEW ROUND"
	var score: Dictionary = _current_score()
	score_x_value.text = str(score["x"])
	score_o_value.text = str(score["o"])
	score_draw_value.text = str(score["draws"])
	x_name_label.text = "YOU" if vs_cpu else "PLAYER X"
	o_name_label.text = "CPU" if vs_cpu else "PLAYER O"
	cpu_button.button_pressed = vs_cpu
	local_button.button_pressed = not vs_cpu


func _player_name(mark: String) -> String:
	if vs_cpu:
		return "You" if mark == "X" else "CPU"
	return "Player %s" % mark


func _set_mode(cpu_mode: bool) -> void:
	if vs_cpu == cpu_mode:
		_update_ui()
		return
	vs_cpu = cpu_mode
	_start_new_round()


func _start_new_round() -> void:
	round_id += 1
	board = ["", "", "", "", "", "", "", "", ""]
	turn = "X"
	game_over = false
	cpu_thinking = false
	winning_cells.clear()
	_update_ui()


func _clear_score() -> void:
	var score: Dictionary = _current_score()
	score["x"] = 0
	score["o"] = 0
	score["draws"] = 0
	_save_scores()
	_start_new_round()


func _current_score() -> Dictionary:
	return scores["cpu" if vs_cpu else "local"]


func _load_scores() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for mode in ["cpu", "local"]:
		for key in ["x", "o", "draws"]:
			scores[mode][key] = maxi(0, int(config.get_value(mode, key, 0)))


func _save_scores() -> void:
	var config := ConfigFile.new()
	for mode in ["cpu", "local"]:
		for key in ["x", "o", "draws"]:
			config.set_value(mode, key, scores[mode][key])
	config.save(SAVE_PATH)
