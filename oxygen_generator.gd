extends Node2D


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("Oxygen")

@export var oxygen_generation_rate: float = 0.06


@export_group("Power")

@export var power_draw: float = 40.0


# =========================================================
# ESTADO
# =========================================================

var is_on: bool = false


# =========================================================
# REFERENCIAS
# =========================================================

@onready var interaction_area: Area2D = (
	$InteractionArea
)


@onready var room = (
	$"../RoomLeft"
)


@onready var power_system = (
	$"../PowerSystem"
)


@onready var repair_point = (
	$"../OxygenGeneratorRepairPoint"
)


@onready var network_component = (
	$NetworkInteractable
)


# =========================================================
# INICIALIZACIÓN
# =========================================================

func _ready():

	interaction_area.add_to_group(
		"interactable_area"
	)


	power_system.set_consumer_demand(
		name,
		0.0
	)


	power_system.power_changed.connect(
		queue_redraw
	)


	queue_redraw()


# =========================================================
# SALIDA
# =========================================================

func _exit_tree():

	if is_instance_valid(
		power_system
	):

		power_system.remove_consumer(
			name
		)


# =========================================================
# INTERACCIÓN
# =========================================================

func interact(
	_player
):

	if not NetworkManager.is_online():

		set_generator_on(
			not is_on
		)

		return


	network_component.request_action(
		"toggle"
	)


# =========================================================
# NETWORK — VALIDACIÓN
# =========================================================

func network_validate_action(
	_peer_id: int,
	action: String,
	_payload: Dictionary
) -> bool:

	return (
		action
		== "toggle"
	)


# =========================================================
# NETWORK — EJECUCIÓN AUTORITATIVA
# =========================================================

func network_execute_action(
	_peer_id: int,
	action: String,
	_payload: Dictionary
):

	if action != "toggle":
		return


	set_generator_on(
		not is_on
	)


# =========================================================
# CAMBIAR ESTADO
# =========================================================

func set_generator_on(
	value: bool
):

	is_on = value


	if is_on:

		power_system.set_consumer_demand(
			name,
			power_draw
		)

	else:

		power_system.set_consumer_demand(
			name,
			0.0
		)


	queue_redraw()


# =========================================================
# NETWORK — ESTADO
# =========================================================

func network_get_state() -> Dictionary:

	return {
		"is_on": is_on
	}


# =========================================================
# NETWORK — APLICAR ESTADO
# =========================================================

func network_apply_state(
	state: Dictionary
):

	if not state.has(
		"is_on"
	):
		return


	set_generator_on(
		bool(
			state[
				"is_on"
			]
		)
	)


# =========================================================
# SIMULACIÓN
# =========================================================

func _process(
	delta: float
):

	# Multiplayer:
	# solamente Host modifica el oxígeno real.
	if (
		NetworkManager.is_online()
		and not NetworkManager.is_host()
	):

		return


	if not is_on:
		return


	if not power_system.has_power():
		return


	var efficiency: float = (
		get_efficiency_multiplier()
	)


	if efficiency <= 0.0:
		return


	if room.oxygen_level >= 1.0:
		return


	var effective_generation_rate: float = (
		oxygen_generation_rate
		* efficiency
	)


	room.set_oxygen_level(
		room.oxygen_level
		+ effective_generation_rate
		* delta
	)


# =========================================================
# CONDICIÓN
# =========================================================

func get_efficiency_multiplier() -> float:

	if repair_point == null:
		return 1.0


	if not repair_point.has_method(
		"get_efficiency_multiplier"
	):

		return 1.0


	return repair_point.get_efficiency_multiplier()


# =========================================================
# GENERACIÓN EFECTIVA
# =========================================================

func get_effective_generation_rate() -> float:

	return (
		oxygen_generation_rate
		* get_efficiency_multiplier()
	)


# =========================================================
# ROTA
# =========================================================

func is_broken() -> bool:

	return (
		get_efficiency_multiplier()
		<= 0.0
	)


# =========================================================
# VISUAL
# =========================================================

func _draw():

	draw_rect(
		Rect2(
			-40,
			-40,
			80,
			80
		),
		Color(
			0.18,
			0.22,
			0.25,
			1.0
		)
	)


	var indicator_color: Color


	if not is_on:

		indicator_color = Color(
			0.55,
			0.15,
			0.15,
			1.0
		)


	elif is_broken():

		indicator_color = Color(
			0.30,
			0.30,
			0.30,
			1.0
		)


	elif power_system.has_power():

		indicator_color = Color(
			0.2,
			0.8,
			0.3,
			1.0
		)


	else:

		indicator_color = Color(
			0.9,
			0.5,
			0.1,
			1.0
		)


	draw_circle(
		Vector2.ZERO,
		18,
		indicator_color
	)
