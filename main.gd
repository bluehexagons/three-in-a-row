extends Control

signal round_transition_finished

const Backdrop := preload("res://backdrop.gd")
const MarkCell := preload("res://mark_cell.gd")
const WinLine := preload("res://win_line.gd")
const Typeface := preload("res://fonts/BricolageGrotesque.ttf")

var PAPER: Color
var PANEL: Color
var CELL: Color
var CELL_HOVER: Color
var X_COLOR: Color
var O_COLOR: Color
var WIN_COLOR: Color
var TEXT: Color
var MUTED: Color
var ACCENT: Color
var ACCENT_TEXT: Color
var SHADOW: Color
var CONTROL_HOVER: Color
var CONTROL_PRESSED: Color
var ACCENT_HOVER: Color
var FRAME_TEXT: Color
var FRAME_MUTED: Color
var FRAME_X: Color
var FRAME_O: Color
var BORDER: Color
var FOCUS: Color
const SAVE_PATH := "user://match_scores.cfg"
const ROUND_TURN_OUT_SECONDS := 0.10
const ROUND_TURN_IN_SECONDS := 0.16
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
var reset_armed := false
var dark_mode := false
var theme_preference := "system"
var reduced_motion := false
var motion_preference := "system"
var last_move := -1
var winning_cells: Array[int] = []
var scores := {
	"cpu": {"x": 0, "o": 0, "draws": 0},
	"local": {"x": 0, "o": 0, "draws": 0}
}

var cells: Array = []
var status_label: Label
var status_badge: PanelContainer
var status_symbol: Label
var move_label: Label
var shell: Control
var masthead: HBoxContainer
var title_label: Label
var header_rule: ColorRect
var sidebar: VBoxContainer
var setup_heading: Label
var action_row: BoxContainer
var shortcuts: VBoxContainer
var about_card: PanelContainer
var motion_button: Button
var reset_overlay: Control
var reset_card: PanelContainer
var reset_description: Label
var reset_cancel_button: Button
var reset_confirm_button: Button
var body_font := _new_font(550, 14)
var button_font := _new_font(750, 14)
var score_x_value: Label
var score_draw_value: Label
var score_o_value: Label
var x_name_label: Label
var o_name_label: Label
var score_x_card: PanelContainer
var score_o_card: PanelContainer
var cpu_button: Button
var local_button: Button
var difficulty_button: OptionButton
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
var round_focus: Control
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	_load_scores()
	dark_mode = _resolved_dark_mode(theme_preference, _browser_prefers_dark())
	reduced_motion = motion_preference == "reduced" or (
		motion_preference == "system" and _browser_preference("(prefers-reduced-motion: reduce)")
	)
	_apply_palette_values()
	_build_ui()
	_update_ui()
	resized.connect(_layout_ui)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo or event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return
	if reset_armed:
		if event.keycode == KEY_ESCAPE:
			_disarm_reset()
			get_viewport().set_input_as_handled()
		return
	if about_overlay.visible:
		if event.keycode == KEY_ESCAPE:
			_hide_about()
			get_viewport().set_input_as_handled()
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_9:
		_cell_pressed(event.keycode - KEY_1)
	elif event.keycode >= KEY_KP_1 and event.keycode <= KEY_KP_9:
		_cell_pressed(event.keycode - KEY_KP_1)
	elif event.keycode == KEY_R:
		_start_new_round()
	elif event.keycode == KEY_D and vs_cpu:
		_cycle_difficulty()
	elif event.keycode == KEY_T:
		_toggle_theme()
	else:
		return
	get_viewport().set_input_as_handled()


func _build_ui() -> void:
	backdrop = Backdrop.new()
	backdrop.set_palette(PAPER, TEXT, X_COLOR, O_COLOR)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	shell = Control.new()
	add_child(shell)

	masthead = HBoxContainer.new()
	masthead.alignment = BoxContainer.ALIGNMENT_CENTER
	masthead.add_theme_constant_override("separation", 8)
	shell.add_child(masthead)
	var title := _label("Three in a Row", 60, TEXT, 800)
	title.clip_text = true
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	masthead.add_child(title)
	title_label = title

	theme_button = _button("DARK MODE", 13)
	theme_button.custom_minimum_size = Vector2(94, 44)
	theme_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	theme_button.add_theme_stylebox_override("pressed", _surface(ACCENT, ACCENT, 9, 10, 3))
	theme_button.add_theme_color_override("font_pressed_color", ACCENT_TEXT)
	theme_button.pressed.connect(_toggle_theme)
	masthead.add_child(theme_button)
	about_button = _button("?", 21)
	about_button.custom_minimum_size = Vector2(44, 44)
	about_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	about_button.tooltip_text = "How to play, settings, and credits"
	about_button.accessibility_name = "Help and settings"
	about_button.pressed.connect(_show_about)
	masthead.add_child(about_button)

	header_rule = ColorRect.new()
	header_rule.color = BORDER
	header_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(header_rule)

	_build_board()
	_build_match_controls()
	_build_about_overlay()
	_layout_ui()


func _build_board() -> void:
	board_card = PanelContainer.new()
	var frame := _surface(PANEL, PANEL, 22)
	frame.set_content_margin_all(12)
	frame.shadow_color = Color(SHADOW, 0.22)
	frame.shadow_offset = Vector2(0, 5)
	frame.shadow_size = 10
	board_card.add_theme_stylebox_override("panel", frame)
	shell.add_child(board_card)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	board_card.add_child(stack)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 10)
	status_row.custom_minimum_size.y = 36
	stack.add_child(status_row)
	status_badge = PanelContainer.new()
	status_badge.custom_minimum_size.x = 32
	status_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_row.add_child(status_badge)
	status_symbol = _label("X", 19, PANEL, 800)
	status_symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_badge.add_child(status_symbol)
	status_label = _label("", 17, FRAME_TEXT, 750)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(status_label)
	move_label = _label("", 13, FRAME_MUTED, 650)
	move_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_row.add_child(move_label)

	var play_area := Control.new()
	play_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(play_area)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play_area.add_child(grid)
	for i in 9:
		var button := MarkCell.new()
		button.square_number = i + 1
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.set_underprint(SHADOW)
		button.number_color = MUTED
		button.number_font = body_font
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_stylebox_override("focus", _focus_style(FOCUS, 9, -3))
		button.pressed.connect(_cell_pressed.bind(i))
		grid.add_child(button)
		cells.append(button)
	for i in 9:
		var button: Button = cells[i]
		button.focus_neighbor_left = button.get_path_to(cells[i - 1] if i % 3 > 0 else button)
		button.focus_neighbor_right = button.get_path_to(cells[i + 1] if i % 3 < 2 else button)
		button.focus_neighbor_top = button.get_path_to(cells[i - 3] if i >= 3 else button)
		button.focus_neighbor_bottom = button.get_path_to(cells[i + 3] if i < 6 else button)

	win_line = WinLine.new()
	win_line.grid = grid
	win_line.set_palette(TEXT, ACCENT)
	win_line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play_area.add_child(win_line)


func _build_match_controls() -> void:
	sidebar = VBoxContainer.new()
	shell.add_child(sidebar)

	var scores_panel := VBoxContainer.new()
	scores_panel.add_theme_constant_override("separation", 7)
	sidebar.add_child(scores_panel)

	var heading := HBoxContainer.new()
	scores_panel.add_child(heading)
	var scoreboard_label := _label("Scoreboard", 23, TEXT, 800)
	scoreboard_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(scoreboard_label)
	clear_button = _button("RESET SCORES", 12, false, true)
	clear_button.custom_minimum_size.y = 38
	clear_button.tooltip_text = "Clear scores for this game mode"
	clear_button.pressed.connect(_request_score_reset)
	heading.add_child(clear_button)

	var scoreboard := HBoxContainer.new()
	scoreboard.add_theme_constant_override("separation", 7)
	scores_panel.add_child(scoreboard)
	var x_card := _score_card("YOU · X", X_COLOR)
	score_x_card = x_card[0]
	x_name_label = x_card[1]
	score_x_value = x_card[2]
	scoreboard.add_child(score_x_card)
	var draw_card := _score_card("DRAWS", MUTED)
	score_draw_value = draw_card[2]
	scoreboard.add_child(draw_card[0])
	var o_card := _score_card("CPU · O", O_COLOR)
	score_o_card = o_card[0]
	o_name_label = o_card[1]
	score_o_value = o_card[2]
	scoreboard.add_child(score_o_card)

	var setup := PanelContainer.new()
	var setup_style := _surface(CELL, BORDER, 16)
	setup_style.set_content_margin_all(10)
	setup.add_theme_stylebox_override("panel", setup_style)
	sidebar.add_child(setup)

	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	setup.add_child(controls)
	setup_heading = _label("Game setup", 22, TEXT, 800)
	controls.add_child(setup_heading)

	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 6)
	controls.add_child(mode_row)
	cpu_button = _mode_button("VS CPU", true)
	mode_row.add_child(cpu_button)
	local_button = _mode_button("TWO PLAYERS", false)
	mode_row.add_child(local_button)

	action_row = BoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	controls.add_child(action_row)
	difficulty_button = OptionButton.new()
	_style_button(difficulty_button, 13)
	difficulty_button.custom_minimum_size.y = 44
	difficulty_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	difficulty_button.add_theme_constant_override("modulate_arrow", 1)
	difficulty_button.add_theme_constant_override("arrow_margin", 12)
	difficulty_button.tooltip_text = "Select CPU difficulty (D)"
	difficulty_button.accessibility_name = "CPU difficulty"
	for level in CPU_LEVELS:
		difficulty_button.add_item(level.capitalize())
	var popup := difficulty_button.get_popup()
	popup.add_theme_font_override("font", body_font)
	popup.add_theme_font_size_override("font_size", 17)
	popup.add_theme_color_override("font_color", TEXT)
	popup.add_theme_color_override("font_hover_color", ACCENT_TEXT)
	var popup_style := _surface(CELL, BORDER, 9)
	popup_style.set_content_margin_all(8)
	popup.add_theme_stylebox_override("panel", popup_style)
	popup.add_theme_stylebox_override("hover", _surface(ACCENT, ACCENT, 5))
	popup.add_theme_constant_override("v_separation", 12)
	difficulty_button.item_selected.connect(_set_difficulty)
	action_row.add_child(difficulty_button)

	round_button = _button("NEW ROUND", 15, true)
	round_button.custom_minimum_size = Vector2(120, 44)
	round_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	round_button.tooltip_text = "Start a new round (R)"
	round_button.pressed.connect(_start_new_round)
	action_row.add_child(round_button)

	shortcuts = VBoxContainer.new()
	shortcuts.add_theme_constant_override("separation", 7)
	sidebar.add_child(shortcuts)
	shortcuts.add_child(_label("Keyboard shortcuts", 19, TEXT, 750))
	_add_shortcut("1–9", "Place a mark")
	_add_shortcut("R", "Start a new round")
	_add_shortcut("T", "Switch theme")


func _add_shortcut(key: String, action: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	shortcuts.add_child(row)
	var keycap := PanelContainer.new()
	keycap.custom_minimum_size.x = 37
	keycap.add_theme_stylebox_override("panel", _surface(CELL, BORDER, 5, 5, 3))
	row.add_child(keycap)
	var key_label := _label(key, 13, TEXT, 750)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keycap.add_child(key_label)
	row.add_child(_label(action, 15, MUTED))


func _layout_ui() -> void:
	var wide := size.x >= 790
	var width: float
	var board_width: float
	if wide:
		width = minf(928.0, size.x - 64.0)
		board_width = minf(504.0, width * 0.56)
	else:
		width = minf(456.0, minf(size.x - 28.0, size.y - 385.0))
		board_width = width
	var title_height := 82.0 if wide else 58.0
	var gap := 20.0 if wide else 10.0
	var board_height := board_width + 44.0
	var rail_width := width - board_width - 28.0 if wide else width
	var body_height := board_height if wide else board_height + gap + 235.0
	var shell_height := title_height + gap + body_height
	_place(shell, (size - Vector2(width, shell_height)) * 0.5, Vector2(width, shell_height))
	var title_size := 60 if wide else clampi(int(width / 12), 27, 36)
	title_label.add_theme_font_size_override("font_size", title_size)
	_place(masthead, Vector2.ZERO, Vector2(width, title_height))
	_place(header_rule, Vector2(0, title_height), Vector2(width, 1))
	_place(board_card, Vector2(0, title_height + gap), Vector2(board_width, board_height))
	setup_heading.visible = wide
	shortcuts.visible = wide
	action_row.vertical = wide
	sidebar.add_theme_constant_override("separation", 20 if wide else 10)
	var rail_origin := Vector2(board_width + 28, title_height + gap) if wide else Vector2(0, title_height + gap + board_height + gap)
	_place(sidebar, rail_origin, Vector2(rail_width, 0))
	sidebar.set_deferred("size", Vector2(rail_width, 0))
	var dialog_width := minf(466.0, size.x - 30.0)
	for card in [about_card, reset_card]:
		card.custom_minimum_size.x = dialog_width


func _place(control: Control, origin: Vector2, extent: Vector2) -> void:
	control.position = origin.round()
	control.size = extent.round()


func _build_about_overlay() -> void:
	about_overlay = _modal_overlay()
	about_card = _modal_card(about_overlay)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 15)
	about_card.add_child(stack)
	stack.add_child(_label("How to play", 34, TEXT, 800))
	stack.add_child(_wrapped_label("Take turns placing X or O. Complete any row, column, or diagonal to win. A full board with no winner is a draw.", 17, TEXT))
	stack.add_child(_wrapped_label("Click or tap a square, or press 1–9. Use Tab and the arrow keys to move focus, then Enter or Space to play. R starts a new round, D changes CPU difficulty, and T switches the theme.", 15, MUTED))

	motion_button = _button("", 14)
	motion_button.pressed.connect(_toggle_motion)
	stack.add_child(motion_button)
	_update_motion_button()

	var version := str(ProjectSettings.get_setting("application/config/version", "development"))
	about_body_label = _wrapped_label(
		"VERSION %s · GODOT ENGINE\n" % version
		+ "Built to test infra-tools agentic VMs and Godot web development.\n\n"
		+ "Copyright © 2026 Loren Crain\n"
		+ "Licensed under the Apache License, Version 2.0.",
		13, MUTED
	)
	stack.add_child(about_body_label)
	about_close_button = _button("BACK TO GAME", 15, true)
	about_close_button.pressed.connect(_hide_about)
	stack.add_child(about_close_button)

	reset_overlay = _modal_overlay()
	reset_card = _modal_card(reset_overlay)
	var reset_stack := VBoxContainer.new()
	reset_stack.add_theme_constant_override("separation", 14)
	reset_card.add_child(reset_stack)
	reset_stack.add_child(_label("Reset scores?", 31, TEXT, 800))
	reset_description = _wrapped_label("", 17, MUTED)
	reset_stack.add_child(reset_description)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	reset_stack.add_child(actions)
	reset_cancel_button = _button("CANCEL", 14)
	reset_cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_cancel_button.pressed.connect(_disarm_reset)
	actions.add_child(reset_cancel_button)
	reset_confirm_button = _button("RESET SCORES", 14, true)
	reset_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_confirm_button.pressed.connect(_clear_score)
	actions.add_child(reset_confirm_button)


func _modal_overlay() -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color("14221c")
	overlay.color.a = 0.76
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.hide()
	add_child(overlay)
	return overlay


func _modal_card(overlay: Control) -> PanelContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var card := PanelContainer.new()
	var style := _surface(CELL, BORDER, 20)
	style.set_content_margin_all(22)
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)
	return card


func _mode_button(label_text: String, cpu_mode: bool) -> Button:
	var button := _button(label_text, 14)
	button.toggle_mode = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("pressed", _surface(PANEL, PANEL, 9, 10, 3))
	button.add_theme_stylebox_override("hover_pressed", _surface(PANEL.lightened(0.10), PANEL, 9, 10, 3))
	for state in ["font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, FRAME_TEXT)
	button.pressed.connect(_set_mode.bind(cpu_mode))
	return button


func _new_font(weight: int, optical_size: int) -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = Typeface
	variation.variation_opentype = {"wght": weight, "opsz": optical_size}
	return variation


func _label(value: String, points: int, color: Color, weight := 550) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", body_font if weight == 550 else _new_font(weight, points))
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", color)
	return label


func _wrapped_label(value: String, points: int, color: Color) -> Label:
	var label := _label(value, points, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(value: String, points: int, primary := false, quiet := false) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 44
	_style_button(button, points, primary, quiet)
	return button


func _style_button(button: Button, points: int, primary := false, quiet := false) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", button_font)
	button.add_theme_font_size_override("font_size", points)
	var color := ACCENT_TEXT if primary else TEXT
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, color)
	button.add_theme_color_override("font_focus_color", TEXT)
	button.add_theme_color_override("font_disabled_color", MUTED)
	var normal_fill := ACCENT if primary else CELL
	var normal_border := ACCENT if primary else BORDER
	if quiet:
		normal_fill = Color.TRANSPARENT
		normal_border = Color.TRANSPARENT
	button.add_theme_stylebox_override("normal", _surface(normal_fill, normal_border, 9, 10, 3))
	button.add_theme_stylebox_override("hover", _surface(ACCENT_HOVER if primary else CONTROL_HOVER, BORDER, 9, 10, 3))
	button.add_theme_stylebox_override("pressed", _surface(ACCENT_HOVER if primary else CONTROL_PRESSED, BORDER, 9, 10, 3))
	button.add_theme_stylebox_override("disabled", _surface(PAPER, BORDER, 9, 10, 3))
	button.add_theme_stylebox_override("focus", _focus_style(FOCUS, 9))


func _score_card(label_text: String, color: Color) -> Array:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 64
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _score_card_style(color, false))
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 0)
	panel.add_child(stack)
	var name := _label(label_text, 12, color, 750)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(name)
	var value := _label("0", 29, TEXT, 800)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.clip_text = true
	stack.add_child(value)
	return [panel, name, value]


func _score_card_style(color: Color, active: bool) -> StyleBoxFlat:
	var fill := CELL.lerp(color, 0.14) if active else CELL
	var style := _surface(fill, color if active else BORDER, 10, 3, 2)
	style.border_width_bottom = 3
	style.border_blend = false
	return style


func _surface(fill: Color, border: Color, radius: int, h_padding := 0, v_padding := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_corner_radius_all(radius)
	style.set_border_width_all(1)
	style.content_margin_left = h_padding
	style.content_margin_right = h_padding
	style.content_margin_top = v_padding
	style.content_margin_bottom = v_padding
	return style


func _focus_style(color: Color, radius: int, spread := 2) -> StyleBoxFlat:
	var style := _surface(Color.TRANSPARENT, color, radius)
	style.set_border_width_all(2)
	style.set_expand_margin_all(spread)
	style.draw_center = false
	return style


func _cell_pressed(index: int) -> void:
	if index < 0 or index >= board.size():
		return
	if reset_armed or about_overlay.visible or game_over or cpu_thinking or round_transitioning or board[index] != "":
		return
	if vs_cpu and turn == "O":
		return
	_place_mark(index)
	if vs_cpu and not game_over and turn == "O":
		_take_cpu_turn(round_id)


func _place_mark(index: int) -> void:
	last_move = index
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
	_animate_mark(index)
	if not winning_cells.is_empty():
		win_line.show_win(winning_cells, not reduced_motion)


func _take_cpu_turn(expected_round: int) -> void:
	cpu_thinking = true
	_update_ui()
	await get_tree().create_timer(0.38).timeout
	if expected_round != round_id or game_over or not vs_cpu:
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
	var mark_color := X_COLOR if turn == "X" else O_COLOR
	var can_place := not (game_over or cpu_thinking or round_transitioning)
	for i in 9:
		var cell = cells[i]
		var placed_color := X_COLOR if board[i] == "X" else O_COLOR
		cell.set_mark(board[i], placed_color)
		var highlighted := i in winning_cells
		var fill := WIN_COLOR if highlighted else CELL
		cell.add_theme_stylebox_override("normal", _surface(fill, fill, 9))
		var playable: bool = can_place and board[i].is_empty()
		var hover := CELL_HOVER.lerp(mark_color, 0.10) if playable else fill
		cell.add_theme_stylebox_override("hover", _surface(hover, hover, 9))
		cell.add_theme_stylebox_override("pressed", _surface(CONTROL_PRESSED if playable else fill, fill, 9))
		cell.add_theme_stylebox_override("disabled", _surface(fill, fill, 9))
		cell.disabled = round_transitioning
		cell.set_preview(turn if playable else "", mark_color, i == last_move and winning_cells.is_empty())
		cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if playable else Control.CURSOR_ARROW
		cell.accessibility_name = "Square %d, %s" % [i + 1, "empty" if board[i].is_empty() else board[i]]

	if round_transitioning:
		status_label.text = "TURNING THE PAGE…"
	elif game_over:
		status_label.text = "DRAW — BOARD FULL" if winning_cells.is_empty() else _win_message(turn)
	elif cpu_thinking:
		status_label.text = "CPU IS THINKING…"
	else:
		status_label.text = _turn_message()
	var neutral := round_transitioning or (game_over and winning_cells.is_empty())
	var badge_color := FRAME_MUTED if neutral else (FRAME_X if turn == "X" else FRAME_O)
	var badge_style := _surface(badge_color, badge_color, 7, 3, 2)
	status_badge.add_theme_stylebox_override("panel", badge_style)
	status_symbol.text = "–" if neutral else turn
	move_label.text = "" if last_move < 0 or game_over or round_transitioning else "Last move  %d" % (last_move + 1)
	round_button.text = "PLAY AGAIN" if game_over and not round_transitioning else "NEW ROUND"

	var score: Dictionary = _current_score()
	score_x_value.text = str(score["x"])
	score_o_value.text = str(score["o"])
	score_draw_value.text = str(score["draws"])
	x_name_label.text = "YOU · X" if vs_cpu else "PLAYER X"
	o_name_label.text = "CPU · O" if vs_cpu else "PLAYER O"
	cpu_button.set_pressed_no_signal(vs_cpu)
	local_button.set_pressed_no_signal(not vs_cpu)
	difficulty_button.visible = vs_cpu
	difficulty_button.select(cpu_level)
	difficulty_button.text = "CPU · %s" % CPU_LEVELS[cpu_level].capitalize()
	theme_button.text = "LIGHT MODE" if dark_mode else "DARK MODE"
	theme_button.tooltip_text = "Switch to %s mode (T)" % ("light" if dark_mode else "dark")
	score_x_card.add_theme_stylebox_override("panel", _score_card_style(X_COLOR, not neutral and turn == "X"))
	score_o_card.add_theme_stylebox_override("panel", _score_card_style(O_COLOR, not neutral and turn == "O"))
	round_button.disabled = round_transitioning
	clear_button.disabled = round_transitioning
	cpu_button.disabled = round_transitioning
	local_button.disabled = round_transitioning
	difficulty_button.disabled = round_transitioning
	theme_button.disabled = round_transitioning


func _win_message(mark: String) -> String:
	if vs_cpu:
		return "YOU WIN" if mark == "X" else "CPU WINS"
	return "PLAYER %s WINS" % mark


func _turn_message() -> String:
	if vs_cpu:
		return "YOUR TURN — PLACE X" if turn == "X" else "CPU TO MOVE"
	return "PLAYER %s TO MOVE" % turn


func _show_about() -> void:
	about_overlay.show()
	shell.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	about_close_button.grab_focus()


func _hide_about() -> void:
	about_overlay.hide()
	shell.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	about_button.grab_focus()


func _set_mode(cpu_mode: bool) -> void:
	if round_transitioning:
		return
	if vs_cpu == cpu_mode:
		_update_ui()
		return
	vs_cpu = cpu_mode
	_start_new_round()


func _cycle_difficulty() -> void:
	if vs_cpu and not round_transitioning:
		_set_difficulty((cpu_level + 1) % CPU_LEVELS.size())


func _set_difficulty(index: int) -> void:
	cpu_level = index
	_save_scores()
	_update_ui()


func _toggle_motion() -> void:
	reduced_motion = not reduced_motion
	motion_preference = "reduced" if reduced_motion else "full"
	_save_scores()
	_update_motion_button()


func _update_motion_button() -> void:
	motion_button.text = "REDUCED MOTION  ·  %s" % ("ON" if reduced_motion else "OFF")


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
	var focused_square := cells.find(get_viewport().gui_get_focus_owner())
	for child in get_children():
		child.free()
	cells.clear()
	_build_ui()
	_update_ui()
	for cell in cells:
		if cell.mark != "":
			cell.reveal = 1.0
	if not winning_cells.is_empty():
		win_line.show_win(winning_cells, false)
	if focused_square >= 0:
		cells[focused_square].grab_focus()
	else:
		theme_button.grab_focus()


func _resolved_dark_mode(preference: String, system_prefers_dark: bool) -> bool:
	if preference == "dark":
		return true
	if preference == "light":
		return false
	return system_prefers_dark


func _browser_prefers_dark() -> bool:
	return _browser_preference("(prefers-color-scheme: dark)")


func _browser_preference(query: String) -> bool:
	if not OS.has_feature("web"):
		return false
	return bool(JavaScriptBridge.eval("window.matchMedia('%s').matches" % query, true))


func _apply_palette_values() -> void:
	PANEL = Color("20382f") if not dark_mode else Color("111e1a")
	FRAME_TEXT = Color("fff4dc")
	FRAME_MUTED = Color("bbcab9")
	FRAME_X = Color("ff9a78")
	FRAME_O = Color("a4dec1")
	ACCENT_TEXT = Color("20332a")
	SHADOW = Color("151a16")
	if dark_mode:
		PAPER = Color("1b2924")
		CELL = Color("283a33")
		CELL_HOVER = Color("354c42")
		X_COLOR = Color("ff9a78")
		O_COLOR = Color("a4dec1")
		WIN_COLOR = Color("435349")
		TEXT = Color("fff3db")
		MUTED = Color("b7c6b9")
		ACCENT = Color("e8c981")
		CONTROL_HOVER = Color("3a5045")
		CONTROL_PRESSED = Color("4b6357")
		ACCENT_HOVER = Color("f7dfa1")
		BORDER = Color("4f675b")
		FOCUS = Color("f7dfa1")
	else:
		PAPER = Color("f1ebdc")
		CELL = Color("fff9eb")
		CELL_HOVER = Color("f1e5ce")
		X_COLOR = Color("b84025")
		O_COLOR = Color("257058")
		WIN_COLOR = Color("f7e6aa")
		TEXT = Color("20382f")
		MUTED = Color("546459")
		ACCENT = Color("e9bd62")
		CONTROL_HOVER = Color("efe5ce")
		CONTROL_PRESSED = Color("e9d9b5")
		ACCENT_HOVER = Color("f6cf7f")
		BORDER = Color("c8c5b0")
		FOCUS = Color("80500b")
	RenderingServer.set_default_clear_color(PAPER)


func _start_new_round() -> void:
	if round_transitioning:
		return
	_disarm_reset()
	round_id += 1
	cpu_thinking = false
	round_transitioning = true
	round_focus = get_viewport().gui_get_focus_owner()
	_update_ui()
	if reduced_motion:
		_swap_round_sheet()
		call_deferred("_finish_round_transition")
		return
	board_card.pivot_offset = board_card.size * 0.5
	round_transition_tween = create_tween()
	round_transition_tween.tween_property(board_card, "modulate:a", 0.35, ROUND_TURN_OUT_SECONDS)
	round_transition_tween.parallel().tween_property(board_card, "scale", Vector2(0.98, 0.98), ROUND_TURN_OUT_SECONDS)
	round_transition_tween.tween_callback(_swap_round_sheet)
	round_transition_tween.tween_property(board_card, "modulate:a", 1.0, ROUND_TURN_IN_SECONDS)
	round_transition_tween.parallel().tween_property(board_card, "scale", Vector2.ONE, ROUND_TURN_IN_SECONDS)
	round_transition_tween.tween_callback(_finish_round_transition)


func _swap_round_sheet() -> void:
	last_move = -1
	board = ["", "", "", "", "", "", "", "", ""]
	turn = "X"
	game_over = false
	winning_cells.clear()
	if win_line:
		win_line.clear_win()
	_update_ui()


func _finish_round_transition() -> void:
	board_card.scale = Vector2.ONE
	board_card.modulate = Color.WHITE
	round_transitioning = false
	round_transition_tween = null
	_update_ui()
	if not about_overlay.visible and not get_viewport().gui_get_focus_owner() and is_instance_valid(round_focus) and round_focus.is_visible_in_tree():
		round_focus.grab_focus()
	round_focus = null
	round_transition_finished.emit()


func _clear_score() -> void:
	var score: Dictionary = _current_score()
	score["x"] = 0
	score["o"] = 0
	score["draws"] = 0
	_save_scores()
	_start_new_round()


func _request_score_reset() -> void:
	if round_transitioning or reset_armed:
		return
	reset_armed = true
	var mode_name := "VS CPU" if vs_cpu else "Two Players"
	reset_description.text = "Clear your %s scoreboard and start a fresh round?" % mode_name
	reset_overlay.show()
	shell.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	reset_cancel_button.grab_focus()


func _disarm_reset() -> void:
	if not reset_armed:
		return
	reset_armed = false
	reset_overlay.hide()
	shell.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	clear_button.grab_focus()


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


	var stored_motion := str(config.get_value("settings", "motion", "system"))
	motion_preference = stored_motion if stored_motion in ["system", "full", "reduced"] else "system"


func _save_scores() -> void:
	var config := ConfigFile.new()
	for mode in ["cpu", "local"]:
		for key in ["x", "o", "draws"]:
			config.set_value(mode, key, scores[mode][key])
	config.set_value("settings", "cpu_level", cpu_level)
	config.set_value("settings", "theme", theme_preference)
	config.set_value("settings", "motion", motion_preference)
	config.save(SAVE_PATH)


func _animate_mark(index: int) -> void:
	var cell = cells[index]
	if reduced_motion:
		cell.reveal = 1.0
		return
	cell.reveal = 0.0
	var tween := create_tween().bind_node(cell)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(cell, "reveal", 1.0, 0.20)
