extends Node2D

@export var revive_time: float = 5.0

var revive_progress: float = 0.0

@onready var interaction_area: Area2D = $InteractionArea
@onready var health = $"../Health"


func _ready():
	interaction_area.add_to_group("interactable_area")
	queue_redraw()


func interact_hold(_rescuer, delta):
	if not health.can_be_revived():
		revive_progress = 0.0
		queue_redraw()
		return

	revive_progress += delta

	if revive_progress >= revive_time:
		complete_revive()

	queue_redraw()


func interact_release(_rescuer):
	if not health.can_be_revived():
		return

	revive_progress = 0.0
	queue_redraw()


func interaction_cancel(_rescuer):
	if not health.can_be_revived():
		return

	revive_progress = 0.0
	queue_redraw()


func complete_revive():
	if not health.can_be_revived():
		return

	health.revive(0.25)

	revive_progress = 0.0

	queue_redraw()


func _draw():
	if not health.can_be_revived():
		return

	var percent = clamp(
		revive_progress / revive_time,
		0.0,
		1.0
	)

	draw_rect(
		Rect2(-50, -55, 100, 10),
		Color(0.15, 0.15, 0.15, 1.0)
	)

	draw_rect(
		Rect2(-50, -55, 100 * percent, 10),
		Color(0.25, 0.8, 0.4, 1.0)
	)
