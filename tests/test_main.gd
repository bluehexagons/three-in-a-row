extends SceneTree

var failures := 0


func _init() -> void:
	var scene: PackedScene = load("res://main.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame

	assert_equal(game._winning_line("X"), [], "empty board has no winner")
	game.board.assign(["X", "X", "X", "", "", "", "", "", ""])
	assert_equal(game._winning_line("X"), [0, 1, 2], "detects row win")
	game.board.assign(["O", "", "", "", "O", "", "", "", "O"])
	assert_equal(game._winning_line("O"), [0, 4, 8], "detects diagonal win")

	game.board.assign(["O", "O", "", "X", "X", "", "", "", ""])
	assert_equal(game._best_cpu_move(), 2, "CPU takes a winning move")
	game.board.assign(["X", "X", "", "O", "", "", "", "O", ""])
	assert_equal(game._best_cpu_move(), 2, "CPU blocks an immediate loss")
	game.board.assign(["X", "", "", "", "", "", "", "", ""])
	assert_equal(game._best_cpu_move(), 4, "CPU answers a corner with the center")
	game.board.assign(["O", "O", "", "X", "X", "", "", "", ""])
	assert_equal(game._tactical_move("O"), 2, "tactical CPU spots its winning move")
	game.board.assign(["X", "X", "", "O", "", "", "", "", ""])
	assert_equal(game._tactical_cpu_move(), 2, "tactical CPU blocks an immediate loss")

	game.vs_cpu = false
	game.board.assign(["X", "", "", "", "", "", "", "", ""])
	game._update_ui()
	game._start_new_round()
	assert_equal(game.round_transitioning, true, "new round starts a board transition")
	assert_equal(game.board[0], "X", "old board remains visible at transition start")
	assert_equal(game.status_label.text, "TURNING THE PAGE…", "transition explains the short pause")
	assert_equal(game.cells[1].disabled, true, "transition locks empty board cells")
	await game.round_transition_finished
	assert_equal(game.round_transitioning, false, "new round unlocks after the transition")
	assert_equal(game.board.has("X"), false, "board clears during the hidden midpoint")
	assert_equal(game.board_card.scale, Vector2.ONE, "board finishes at its resting scale")
	assert_equal(game.status_label.text, "PLAYER X TO MOVE", "local turn prompt reads naturally")
	game._cell_pressed(0)
	game._cell_pressed(3)
	game._cell_pressed(1)
	game._cell_pressed(4)
	game._cell_pressed(2)
	assert_equal(game.game_over, true, "local round ends after a win")
	assert_equal(game.winning_cells, [0, 1, 2], "winning cells are retained for highlighting")
	assert_equal(game.status_label.text, "PLAYER X WINS", "local win message agrees with its subject")
	assert_equal(game.round_button.text, "PLAY AGAIN", "finished round offers a replay")
	game._request_score_reset()
	await process_frame
	assert_equal(game.reset_armed, true, "score reset asks for confirmation")
	assert_equal(game.clear_button.text, "CONFIRM RESET", "score reset labels the confirm action")
	game._request_score_reset()
	await game.round_transition_finished
	assert_equal(game.scores["local"]["x"], 0, "confirmed score reset clears the current mode")
	assert_equal(game.clear_button.text, "RESET SCORES", "score reset returns to its default label")

	game.vs_cpu = true
	assert_equal(game._win_message("X"), "YOU WIN", "one-player win addresses the player directly")
	assert_equal(game._win_message("O"), "CPU WINS", "CPU win uses grammatical agreement")
	game.vs_cpu = false
	game.board.assign(["X", "O", "X", "X", "O", "O", "O", "X", "X"])
	game.game_over = true
	game.winning_cells.clear()
	game._update_ui()
	assert_equal(game.status_label.text, "DRAW — BOARD FULL", "draw message explains the result")
	assert_equal(game.about_overlay.visible, false, "about screen starts closed")
	game._show_about()
	assert_equal(game.about_overlay.visible, true, "about button opens the credits screen")
	assert_equal(
		"infra-tools agentic VMs" in game.about_body_label.text,
		true,
		"about screen explains the game's purpose"
	)
	assert_equal(
		"Apache License, Version 2.0" in game.about_body_label.text,
		true,
		"about screen identifies the project license"
	)
	var project_version := str(ProjectSettings.get_setting("application/config/version"))
	assert_equal(
		"VERSION %s" % project_version in game.about_body_label.text,
		true,
		"about screen reads its version from project settings"
	)
	game._hide_about()
	assert_equal(game.about_overlay.visible, false, "about screen returns to the game")

	if failures == 0:
		print("PASS: all gameplay checks")
	quit(failures)


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		print("PASS: ", label)
		return
	failures += 1
	printerr("FAIL: %s — expected %s, got %s" % [label, expected, actual])
