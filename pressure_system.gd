extends Node


@export_group("Equalization")
@export var pressure_transfer_speed: float = 0.60


@export_group("Decompression")
@export var minimum_force_difference: float = 0.30
@export var dangerous_difference: float = 1.50

@export var effect_radius: float = 300.0

@export var impulse_multiplier: float = 220.0
@export var max_impulse: float = 700.0

@export var pressure_damage_multiplier: float = 10.0


@onready var room_left = $"../RoomLeft"
@onready var room_right = $"../RoomRight"

@onready var door = $"../Door"

@onready var player = $"../Player"
@onready var player_health = $"../Player/Health"


const SIMULATION_INTERVAL: float = 0.1

var simulation_accumulator: float = 0.0


func _ready():
	door.state_changed.connect(
		_on_door_state_changed
	)


# ---------------------------------------------------------
# SIMULATION TICK
# ---------------------------------------------------------

func _process(delta):
	simulation_accumulator += delta

	if simulation_accumulator < SIMULATION_INTERVAL:
		return

	var simulation_delta = simulation_accumulator

	simulation_accumulator = 0.0

	simulate_pressure_transfer(
		simulation_delta
	)


# ---------------------------------------------------------
# IGUALACIÓN DE PRESIÓN
# ---------------------------------------------------------

func simulate_pressure_transfer(delta):
	if not door.is_open:
		return

	var difference = (
		room_right.pressure
		- room_left.pressure
	)

	if abs(difference) < 0.001:
		return

	var transfer_amount = (
		pressure_transfer_speed
		* delta
	)

	transfer_amount = min(
		transfer_amount,
		abs(difference) / 2.0
	)


	if difference > 0.0:

		room_right.set_pressure(
			room_right.pressure
			- transfer_amount
		)

		room_left.set_pressure(
			room_left.pressure
			+ transfer_amount
		)

	else:

		room_right.set_pressure(
			room_right.pressure
			+ transfer_amount
		)

		room_left.set_pressure(
			room_left.pressure
			- transfer_amount
		)


# ---------------------------------------------------------
# EVENTO DE PUERTA
# ---------------------------------------------------------

func _on_door_state_changed(is_open: bool):
	if not is_open:
		return

	trigger_decompression()


# ---------------------------------------------------------
# DESCOMPRESIÓN
# ---------------------------------------------------------

func trigger_decompression():
	var difference = (
		room_right.pressure
		- room_left.pressure
	)

	var pressure_difference = abs(difference)


	# Diferencia demasiado pequeña.
	if pressure_difference < minimum_force_difference:
		return


	# -----------------------------------------------------
	# DISTANCIA DEL JUGADOR A LA PUERTA
	# -----------------------------------------------------

	var distance_to_door = (
		player.global_position.distance_to(
			door.global_position
		)
	)

	# Si está muy lejos de la puerta,
	# no recibe el efecto.
	if distance_to_door > effect_radius:
		return


	# -----------------------------------------------------
	# FALLOFF POR DISTANCIA
	# -----------------------------------------------------

	var distance_factor = clamp(
		1.0 - (
			distance_to_door
			/ effect_radius
		),
		0.0,
		1.0
	)


	# -----------------------------------------------------
	# CENTROS DE LAS HABITACIONES
	# -----------------------------------------------------

	var left_center = room_left.to_global(
		room_left.room_position
		+ room_left.room_size * 0.5
	)

	var right_center = room_right.to_global(
		room_right.room_position
		+ room_right.room_size * 0.5
	)


	# -----------------------------------------------------
	# DIRECCIÓN DEL FLUJO
	# -----------------------------------------------------

	var flow_direction: Vector2


	if difference > 0.0:
		# RoomRight tiene mayor presión.
		# Flujo Right -> Left.

		flow_direction = (
			left_center
			- right_center
		).normalized()

	else:
		# RoomLeft tiene mayor presión.
		# Flujo Left -> Right.

		flow_direction = (
			right_center
			- left_center
		).normalized()


	# -----------------------------------------------------
	# FUERZA DEL IMPULSO
	# -----------------------------------------------------

	var impulse_strength = (
		pressure_difference
		* impulse_multiplier
		* distance_factor
	)

	impulse_strength = min(
		impulse_strength,
		max_impulse
	)


	player.apply_external_impulse(
		flow_direction
		* impulse_strength
	)


	# -----------------------------------------------------
	# DAÑO POR DESCOMPRESIÓN
	# -----------------------------------------------------

	if pressure_difference < dangerous_difference:
		return


	var damage = (
		pressure_difference
		- dangerous_difference
	)

	damage *= pressure_damage_multiplier

	damage *= distance_factor


	if damage <= 0.0:
		return


	player_health.apply_damage(
		damage,
		&"pressure"
	)
