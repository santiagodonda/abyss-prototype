extends Node

@export var transfer_speed: float = 0.15

@onready var room_left = $"../RoomLeft"
@onready var room_right = $"../RoomRight"
@onready var door = $"../Door"

const SIMULATION_INTERVAL := 0.1
var simulation_accumulator: float = 0.0


func _process(delta):
	simulation_accumulator += delta

	if simulation_accumulator < SIMULATION_INTERVAL:
		return

	var simulation_delta = simulation_accumulator
	simulation_accumulator = 0.0

	simulate_water_transfer(simulation_delta)


func simulate_water_transfer(delta):
	if not door.is_open:
		return

	var difference = (
		room_right.water_level
		- room_left.water_level
	)

	if abs(difference) < 0.001:
		return

	var transfer_amount = transfer_speed * delta

	transfer_amount = min(
		transfer_amount,
		abs(difference) / 2.0
	)

	if difference > 0.0:
		room_right.set_water_level(
			room_right.water_level - transfer_amount
		)

		room_left.set_water_level(
			room_left.water_level + transfer_amount
		)

	else:
		room_right.set_water_level(
			room_right.water_level + transfer_amount
		)

		room_left.set_water_level(
			room_left.water_level - transfer_amount
		)
