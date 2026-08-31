extends Button

var mark := ""
var mark_color := Color.WHITE
var underprint := Color("20282c")
var reveal := 0.0:
	set(value):
		reveal = clampf(value, 0.0, 1.0)
		queue_redraw()


func set_mark(value: String, color: Color) -> void:
	mark_color = color
	if mark == value:
		queue_redraw()
		return
	mark = value
	reveal = 0.0
	queue_redraw()


func set_underprint(color: Color) -> void:
	underprint = color
	queue_redraw()


func _draw() -> void:
	if mark == "" or reveal <= 0.0:
		return
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.245
	var pen_width := maxf(8.0, minf(size.x, size.y) * 0.075)
	if mark == "X":
		_draw_x(center, radius, pen_width)
	else:
		_draw_o(center, radius, pen_width)


func _draw_x(center: Vector2, radius: float, pen_width: float) -> void:
	var first_progress := minf(reveal * 2.0, 1.0)
	var second_progress := clampf((reveal - 0.42) * 1.72, 0.0, 1.0)
	var top_left := center + Vector2(-radius, -radius)
	var bottom_right := center + Vector2(radius, radius)
	var top_right := center + Vector2(radius, -radius)
	var bottom_left := center + Vector2(-radius, radius)
	_draw_print_stroke(top_left, top_left.lerp(bottom_right, first_progress), pen_width)
	if second_progress > 0.0:
		_draw_print_stroke(top_right, top_right.lerp(bottom_left, second_progress), pen_width)


func _draw_o(center: Vector2, radius: float, pen_width: float) -> void:
	var start_angle := -PI * 0.5
	var end_angle := start_angle + TAU * reveal
	draw_arc(center + Vector2(3.0, 3.0), radius, start_angle, end_angle, 48, underprint, pen_width + 3.0, true)
	draw_arc(center, radius, start_angle, end_angle, 48, mark_color, pen_width, true)


func _draw_print_stroke(start: Vector2, finish: Vector2, pen_width: float) -> void:
	draw_line(start + Vector2(3.0, 3.0), finish + Vector2(3.0, 3.0), underprint, pen_width + 3.0, true)
	draw_line(start, finish, mark_color, pen_width, true)
