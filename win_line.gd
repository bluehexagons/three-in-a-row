extends Control

var grid: GridContainer
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
	grid.sort_children.connect(queue_redraw)


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
	if line_cells.size() != 3 or progress <= 0.0:
		return
	var start := _cell_center(line_cells[0])
	var finish := _cell_center(line_cells[2])
	var direction := start.direction_to(finish)
	var extension := minf(size.x, size.y) * 0.08
	start -= direction * extension
	finish += direction * extension
	var animated_finish := start.lerp(finish, progress)
	draw_line(start, animated_finish, ink, 8.0, true)
	draw_line(start, animated_finish, marker, 5.0, true)
	draw_circle(start, 4.0, marker, true, -1.0, true)
	draw_circle(animated_finish, 4.0, marker, true, -1.0, true)


func _cell_center(index: int) -> Vector2:
	var cell := grid.get_child(index) as Control
	return cell.position + cell.size * 0.5
