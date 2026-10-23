extends StaticBody2D

@export var wall_color: Color = Color(0.08, 0.20, 0.25, 1.0)

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready():
	queue_redraw()


func _draw():
	if collision_shape.shape is RectangleShape2D:
		var size = collision_shape.shape.size
		
		var rectangle = Rect2(
			-size / 2.0,
			size
		)
		
		draw_rect(rectangle, wall_color)
		
