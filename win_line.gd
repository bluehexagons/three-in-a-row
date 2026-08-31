extends Control

const INK := Color("20282c")
const MARKER := Color("d5a82e")

var line_cells: Array[int] = []
var progress := 0.0:
	set(value):
		progress = value
		queue_redraw()

var active_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func show_win(cells: Array[int], _color: Color) -> void:
	if active_tween:
		active_tween.kill()
	line_cells = cells.duplicate()
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
	draw_line(start + normal * 4.0, animated_finish + normal * 4.0, Color(INK, 0.75), 5.0, true)
	draw_line(start, animated_finish, MARKER, 11.0, true)
	if progress > 0.97:
		draw_line(start - normal * 10.0, start + normal * 10.0, INK, 3.0, true)
		draw_line(finish - normal * 10.0, finish + normal * 10.0, INK, 3.0, true)


func _cell_center(index: int) -> Vector2:
	var column := index % 3
	var row := index / 3
	return Vector2(
		(float(column) + 0.5) * size.x / 3.0,
		(float(row) + 0.5) * size.y / 3.0
	)
