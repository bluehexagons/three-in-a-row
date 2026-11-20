extends Control

var line_cells: Array[int] = []
var ink := Color("20282c")
var marker := Color("d5a82e")
var progress := 0.0:
	set(value):
		progress = value
		queue_redraw()

var active_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_palette(foreground: Color, accent: Color) -> void:
	ink = foreground
	marker = accent
	queue_redraw()


func show_win(cells: Array[int], animate := true) -> void:
	if active_tween:
		active_tween.kill()
		active_tween = null
	line_cells = cells.duplicate()
	if not animate:
		progress = 1.0
		return
	progress = 0.0
	active_tween = create_tween()
	active_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(self, "progress", 1.0, 0.34)


func clear_win() -> void:
	if active_tween:
		active_tween.kill()
	line_cells.clear()
	progress = 0.0
	queue_redraw()


func _draw() -> void:
	if line_cells.size() != 3:
		return
	var start := _cell_center(line_cells[0])
	var finish := _cell_center(line_cells[2])
	var animated_finish := start.lerp(finish, progress)
	var direction := start.direction_to(finish)
	var normal := Vector2(-direction.y, direction.x)
	draw_line(start + normal * 4.0, animated_finish + normal * 4.0, Color(ink, 0.75), 5.0, true)
	draw_line(start, animated_finish, marker, 11.0, true)
	if progress > 0.97:
		draw_line(start - normal * 10.0, start + normal * 10.0, ink, 3.0, true)
		draw_line(finish - normal * 10.0, finish + normal * 10.0, ink, 3.0, true)


func _cell_center(index: int) -> Vector2:
	var column := index % 3
	var row := index / 3
	return Vector2(
		(float(column) + 0.5) * size.x / 3.0,
		(float(row) + 0.5) * size.y / 3.0
	)
