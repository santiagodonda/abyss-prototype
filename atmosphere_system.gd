extends Node

@export var oxygen_transfer_speed: float = 0.10

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

	simulate_oxygen_transfer(simulation_delta)


func simulate_oxygen_transfer(delta):
	if not door.is_open:
		return

	var difference = (
		room_right.oxygen_level
		- room_left.oxygen_level
	)

	if abs(difference) < 0.001:
		return

	var transfer_amount = oxygen_transfer_speed * delta

	transfer_amount = min(
		transfer_amount,
		abs(difference) / 2.0
	)

	if difference > 0.0:
		room_right.set_oxygen_level(
			room_right.oxygen_level - transfer_amount
		)

		room_left.set_oxygen_level(
			room_left.oxygen_level + transfer_amount
		)

	else:
		room_right.set_oxygen_level(
			room_right.oxygen_level + transfer_amount
		)

		room_left.set_oxygen_level(
			room_left.oxygen_level - transfer_amount
		)
