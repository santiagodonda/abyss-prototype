extends Node2D

@export_range(0.0, 1.0) var water_level: float = 0.0
@export var flood_speed: float = 0.08

@export var room_position: Vector2
@export var room_size: Vector2

var flooding: bool = false


func _process(delta):
	if flooding:
		water_level += flood_speed * delta
		water_level = clamp(water_level, 0.0, 1.0)

		queue_redraw()


func set_flooding(value: bool):
	flooding = value


func set_water_level(value: float):
	water_level = clamp(value, 0.0, 1.0)
	queue_redraw()


func _draw():
	if water_level <= 0.0:
		return

	var water_height = room_size.y * water_level
	var water_y = room_position.y + room_size.y - water_height

	draw_rect(
		Rect2(
			room_position.x,
			water_y,
			room_size.x,
			water_height
		),
		Color(0.05, 0.35, 0.55, 0.65)
	)
