extends Control

var paper := Color("f1ebdc")
var ink := Color("20382f")
var x_ink := Color("b84025")
var o_ink := Color("257058")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_palette(background: Color, foreground: Color, x_color: Color, o_color: Color) -> void:
	paper = background
	ink = foreground
	x_ink = x_color
	o_ink = o_color
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), paper)
	var dot := Color(ink, 0.11)
	for column in range(13, ceili(size.x), 18):
		for row in range(13, ceili(size.y), 18):
			draw_circle(Vector2(column, row), 0.85, dot, true, -1.0, true)

	if size.x >= 790:
		var cross := Vector2(22, size.y * 0.16)
		draw_line(cross + Vector2(-82, -82), cross + Vector2(82, 82), Color(x_ink, 0.09), 31, true)
		draw_line(cross + Vector2(82, -82), cross + Vector2(-82, 82), Color(x_ink, 0.09), 31, true)
		draw_arc(size - Vector2(24, 99), 98, 0, TAU, 96, Color(o_ink, 0.10), 33, true)
