extends Control

var paper := Color("eee9dc")
var ink := Color("20282c")
var blue := Color("2f6793")
var orange := Color("c95135")
var mustard := Color("d5a82e")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_palette(
	background: Color,
	foreground: Color,
	blue_ink: Color,
	orange_ink: Color,
	accent_ink: Color
) -> void:
	paper = background
	ink = foreground
	blue = blue_ink
	orange = orange_ink
	mustard = accent_ink
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), paper)
	_draw_rules()
	_draw_paper_fibers()

	# Registration furniture stays at the edges so the game reads like a
	# printed score sheet without competing with the playable grid.
	draw_rect(Rect2(34.0, 34.0, 176.0, 13.0), blue)
	draw_rect(Rect2(34.0, 34.0, 13.0, 106.0), blue)
	draw_rect(Rect2(size.x - 210.0, size.y - 52.0, 176.0, 13.0), orange)
	draw_rect(Rect2(size.x - 47.0, size.y - 140.0, 13.0, 101.0), orange)

	_draw_tick_block(Vector2(42.0, size.y * 0.64), blue)
	_draw_tick_block(Vector2(size.x - 164.0, size.y * 0.22), orange)
	_draw_reference_grid(Vector2(size.x - 246.0, size.y * 0.48), 178.0)

	var marker_origin := Vector2(60.0, size.y - 120.0)
	draw_line(marker_origin, marker_origin + Vector2(76.0, 0.0), ink, 5.0)
	draw_line(marker_origin + Vector2(87.0, 0.0), marker_origin + Vector2(108.0, 0.0), mustard, 5.0)
	draw_line(marker_origin + Vector2(119.0, 0.0), marker_origin + Vector2(132.0, 0.0), ink, 5.0)


func _draw_rules() -> void:
	var spacing := 48.0
	var rule_color := Color(ink, 0.075)
	for column in ceili(size.x / spacing) + 1:
		var x := float(column) * spacing
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), rule_color, 1.0)
	for row in ceili(size.y / spacing) + 1:
		var y := float(row) * spacing
		draw_line(Vector2(0.0, y), Vector2(size.x, y), rule_color, 1.0)


func _draw_paper_fibers() -> void:
	var fiber_color := Color(ink, 0.075)
	for index in 96:
		var x := fmod(float(index * 137 + 29), maxf(size.x, 1.0))
		var y := fmod(float(index * 83 + 47), maxf(size.y, 1.0))
		var length := 2.0 + float(index % 4)
		draw_line(Vector2(x, y), Vector2(x + length, y), fiber_color, 1.0)


func _draw_tick_block(origin: Vector2, color: Color) -> void:
	for index in 7:
		var width := 48.0 if index % 3 == 0 else 27.0
		draw_rect(Rect2(origin + Vector2(0.0, index * 11.0), Vector2(width, 4.0)), Color(color, 0.58))


func _draw_reference_grid(origin: Vector2, extent: float) -> void:
	var color := Color(ink, 0.1)
	for index in 4:
		var amount := float(index) / 3.0
		draw_line(origin + Vector2(extent * amount, 0.0), origin + Vector2(extent * amount, extent), color, 2.0)
		draw_line(origin + Vector2(0.0, extent * amount), origin + Vector2(extent, extent * amount), color, 2.0)
