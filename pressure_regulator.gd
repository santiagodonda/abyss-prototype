extends Node2D


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("Pressure Control")

@export var target_pressure: float = 1.0

@export var pressure_change_rate: float = 0.35

@export var pressure_tolerance: float = 0.02


@export_group("Power")

@export var power_draw: float = 50.0


@export_group("Simulation")

@export var simulation_interval: float = 0.1


# =========================================================
# ESTADO
# =========================================================

var is_on: bool = false

var simulation_accumulator: float = 0.0


# =========================================================
# REFERENCIAS
# =========================================================

@onready var interaction_area: Area2D = (
	$InteractionArea
)


@onready var room = (
	$"../RoomRight"
)


@onready var power_system = (
	$"../PowerSystem"
)


@onready var repair_point = (
	$"../PressureRegulatorRepairPoint"
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

		set_regulator_on(
			not is_on
		)

		return


	network_component.request_action(
		"toggle"
	)


# =========================================================
# PRIORIDAD DE INTERACCIÓN
# =========================================================

func get_interaction_priority(
	_player
) -> int:

	return 40


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


	set_regulator_on(
		not is_on
	)


# =========================================================
# CAMBIAR ESTADO
# =========================================================

func set_regulator_on(
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


	set_regulator_on(
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

	if (
		NetworkManager.is_online()
		and not NetworkManager.is_host()
	):

		return


	if not is_on:
		return


	if not power_system.has_power():
		return


	if is_broken():
		return


	simulation_accumulator += delta


	if (
		simulation_accumulator
		< simulation_interval
	):

		return


	var simulation_delta: float = (
		simulation_accumulator
	)


	simulation_accumulator = 0.0


	normalize_pressure(
		simulation_delta
	)


# =========================================================
# CONTROL DE PRESIÓN
# =========================================================

func normalize_pressure(
	delta: float
):

	var difference: float = (
		target_pressure
		- room.pressure
	)


	if abs(
		difference
	) <= pressure_tolerance:

		room.set_pressure(
			target_pressure
		)

		return


	var efficiency: float = (
		get_efficiency_multiplier()
	)


	if efficiency <= 0.0:
		return


	var effective_change_rate: float = (
		pressure_change_rate
		* efficiency
	)


	var change_amount: float = (
		effective_change_rate
		* delta
	)


	if difference < 0.0:

		room.set_pressure(
			max(
				room.pressure
				- change_amount,
				target_pressure
			)
		)

	else:

		room.set_pressure(
			min(
				room.pressure
				+ change_amount,
				target_pressure
			)
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
# VELOCIDAD EFECTIVA
# =========================================================

func get_effective_pressure_change_rate() -> float:

	return (
		pressure_change_rate
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
# INFORMACIÓN
# =========================================================

func has_power() -> bool:

	return power_system.has_power()


func is_working() -> bool:

	if not is_on:
		return false


	if not power_system.has_power():
		return false


	if is_broken():
		return false


	if abs(
		room.pressure
		- target_pressure
	) <= pressure_tolerance:

		return false


	return true


func get_status_text() -> String:

	if not is_on:
		return "OFF"


	if is_broken():
		return "BROKEN"


	if not power_system.has_power():
		return "NO POWER"


	if abs(
		room.pressure
		- target_pressure
	) <= pressure_tolerance:

		return "STABLE"


	return "WORKING"


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


	elif not power_system.has_power():

		indicator_color = Color(
			0.9,
			0.5,
			0.1,
			1.0
		)


	elif abs(
		room.pressure
		- target_pressure
	) <= pressure_tolerance:

		indicator_color = Color(
			0.2,
			0.55,
			0.85,
			1.0
		)


	else:

		indicator_color = Color(
			0.2,
			0.8,
			0.3,
			1.0
		)


	draw_circle(
		Vector2.ZERO,
		18,
		indicator_color
	)
