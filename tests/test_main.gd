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

	game.vs_cpu = false
	game._start_new_round()
	game._cell_pressed(0)
	game._cell_pressed(3)
	game._cell_pressed(1)
	game._cell_pressed(4)
	game._cell_pressed(2)
	assert_equal(game.game_over, true, "local round ends after a win")
	assert_equal(game.winning_cells, [0, 1, 2], "winning cells are retained for highlighting")
	game._clear_score()

	if failures == 0:
		print("PASS: all gameplay checks")
	quit(failures)


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		print("PASS: ", label)
		return
	failures += 1
	printerr("FAIL: %s — expected %s, got %s" % [label, expected, actual])
