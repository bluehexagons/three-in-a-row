extends Button

var mark := ""
var mark_color := Color.WHITE
var underprint := Color("20382f")
var number_font: Font
var number_color: Color
var square_number: int
var preview := ""
var preview_color: Color
var last_played := false
var reveal := 0.0:
	set(value):
		reveal = clampf(value, 0.0, 1.0)
		queue_redraw()


func _ready() -> void:
	for hover_signal in [mouse_entered, mouse_exited, focus_entered, focus_exited, resized]:
		hover_signal.connect(queue_redraw)


func set_mark(value: String, color: Color) -> void:
	mark_color = color
	if mark != value:
		mark = value
		reveal = 0.0
	queue_redraw()


func set_underprint(color: Color) -> void:
	underprint = color
	queue_redraw()


func set_preview(value: String, color: Color, latest: bool) -> void:
	preview = value
	preview_color = color
	last_played = latest
	queue_redraw()


func _draw() -> void:
	if mark.is_empty():
		draw_string(number_font, Vector2(10, 20), str(square_number), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, number_color)
		if not preview.is_empty() and (is_hovered() or has_focus()):
			_draw_mark(preview, Color(preview_color, 0.30), 1.0)
	else:
		_draw_mark(mark, mark_color, reveal, true)
		if last_played:
			draw_circle(Vector2(size.x - 13, 13), 3.5, mark_color, true, -1.0, true)


func _draw_mark(symbol: String, color: Color, progress: float, printed := false) -> void:
	if progress <= 0.0:
		return
	var center := size * 0.5
	var cell_extent := minf(size.x, size.y)
	var radius := cell_extent * (0.214 if symbol == "X" else 0.236)
	var width := cell_extent * 0.087
	if printed:
		_draw_glyph(symbol, center + Vector2(2, 3), radius, width, Color(underprint, 0.18), progress)
	_draw_glyph(symbol, center, radius, width, color, progress)


func _draw_glyph(symbol: String, center: Vector2, radius: float, width: float, color: Color, progress: float) -> void:
	if symbol == "X":
		var down := Vector2(radius, radius)
		var up := Vector2(radius, -radius)
		var first := minf(progress * 2.0, 1.0)
		var second := clampf((progress - 0.42) / 0.58, 0.0, 1.0)
		_stroke(center - down, center + down * (first * 2.0 - 1.0), width, color)
		if second > 0.0:
			_stroke(center + up, center - up * (second * 2.0 - 1.0), width, color)
	else:
		var start := -PI / 2.0
		var finish := start + TAU * progress
		draw_arc(center, radius, start, finish, 64, color, width, true)
		if progress < 1.0:
			draw_circle(center + Vector2.from_angle(start) * radius, width * 0.5, color, true, -1.0, true)
			draw_circle(center + Vector2.from_angle(finish) * radius, width * 0.5, color, true, -1.0, true)


func _stroke(start: Vector2, finish: Vector2, width: float, color: Color) -> void:
	draw_line(start, finish, color, width, true)
	draw_circle(start, width * 0.5, color, true, -1.0, true)
	draw_circle(finish, width * 0.5, color, true, -1.0, true)
