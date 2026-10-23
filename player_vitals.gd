extends Node


@export_group("Breathing")

@export var oxygen_consumption_rate: float = 0.0006
@export var minimum_breathable_oxygen: float = 0.20


@export_group("Personal Breath")

@export var breath_drain_rate: float = 0.12
@export var breath_recovery_rate: float = 0.25


@export_group("Suffocation")

@export var suffocation_damage_rate: float = 8.0


@export_group("Pressure")

@export var safe_pressure_limit: float = 3.5
@export var pressure_damage_rate: float = 4.0


@export_group("Room Detection")

@export var transition_tolerance: float = 50.0


@export_group("Exterior")

@export var exterior_is_underwater: bool = true


@export_group("Simulation")

@export var simulation_interval: float = 0.1


# =========================================================
# ESTADO
# =========================================================

var breath_level: float = 1.0

var current_room: Node = null

var simulation_accumulator: float = 0.0

var rooms: Array[Node] = []


# =========================================================
# REFERENCIAS
# =========================================================

@onready var player = get_parent()


@onready var breathing_point: Marker2D = (
	get_node_or_null(
		"../BreathingPoint"
	)
)


@onready var health = (
	get_node_or_null(
		"../Health"
	)
)


@onready var equipment = (
	get_node_or_null(
		"../Equipment"
	)
)


@onready var submarine_environment = (
	get_node_or_null(
		"../../SubmarineEnvironment"
	)
)


# =========================================================
# INICIALIZACIÓN
# =========================================================

func _ready():

	if breathing_point == null:

		push_error(
			"Vitals: No se encontró Player/BreathingPoint"
		)

		return


	if health == null:

		push_error(
			"Vitals: No se encontró Player/Health"
		)

		return


	if equipment == null:

		push_error(
			"Vitals: No se encontró Player/Equipment"
		)

		return


	if submarine_environment == null:

		push_error(
			"Vitals: No se encontró SubmarineEnvironment"
		)

		return


	# Primer intento.
	_refresh_rooms()


	# Segundo intento cuando toda la escena terminó
	# de ejecutar sus _ready().
	call_deferred(
		"_refresh_rooms"
	)


# =========================================================
# HABITACIONES
# =========================================================

func _refresh_rooms():

	rooms.clear()


	var candidates: Array = (
		get_tree().get_nodes_in_group(
			"rooms"
		)
	)


	for candidate in candidates:

		if candidate == null:
			continue


		if not is_instance_valid(
			candidate
		):

			continue


		if not candidate.has_method(
			"contains_global_point"
		):

			continue


		rooms.append(
			candidate
		)


# =========================================================
# OBTENER HABITACIONES ACTUALES
# =========================================================

func get_current_rooms() -> Array[Node]:

	# Para nuestro prototipo hay solamente unas pocas Rooms.
	# Actualizar esta lista evita depender de un cache
	# creado antes de que las Rooms entren al grupo.
	_refresh_rooms()


	return rooms


# =========================================================
# SIMULACIÓN
# =========================================================

func _process(
	delta
):

	simulation_accumulator += delta


	if simulation_accumulator < simulation_interval:
		return


	var simulation_delta: float = (
		simulation_accumulator
	)


	simulation_accumulator = 0.0


	simulate_breathing(
		simulation_delta
	)


	apply_suffocation_damage(
		simulation_delta
	)


	apply_pressure_damage(
		simulation_delta
	)


# =========================================================
# RESPIRACIÓN
# =========================================================

func simulate_breathing(
	delta: float
):

	if breathing_point == null:
		return


	current_room = find_current_room()


	# -----------------------------------------------------
	# EXTERIOR
	#
	# Fuera del submarino no existe atmósfera respirable.
	# Sólo podemos utilizar oxígeno personal.
	# -----------------------------------------------------

	if current_room == null:

		try_use_personal_oxygen(
			delta
		)

		return


	# -----------------------------------------------------
	# INTERIOR SUMERGIDO
	# -----------------------------------------------------

	var underwater: bool = (
		current_room.is_point_underwater(
			breathing_point.global_position
		)
	)


	if underwater:

		try_use_personal_oxygen(
			delta
		)

		return


	# -----------------------------------------------------
	# ATMÓSFERA DE LA HABITACIÓN
	# -----------------------------------------------------

	var room_oxygen: float = (
		current_room.oxygen_level
	)


	if room_oxygen >= minimum_breathable_oxygen:

		current_room.consume_oxygen(
			oxygen_consumption_rate
			* delta
		)


		recover_breath(
			delta
		)

		return


	# -----------------------------------------------------
	# OXÍGENO BAJO
	# -----------------------------------------------------

	if equipment.has_breathing_supply():

		equipment.consume_tank_oxygen(
			delta
		)


		recover_breath(
			delta
		)

		return


	var oxygen_deficit: float = (
		minimum_breathable_oxygen
		- room_oxygen
	) / minimum_breathable_oxygen


	drain_breath(
		delta,
		clamp(
			oxygen_deficit,
			0.25,
			1.0
		)
	)


# =========================================================
# OXÍGENO PERSONAL
# =========================================================

func try_use_personal_oxygen(
	delta: float
):

	if equipment.has_breathing_supply():

		equipment.consume_tank_oxygen(
			delta
		)


		recover_breath(
			delta
		)

		return


	drain_breath(
		delta,
		1.0
	)


# =========================================================
# ASFIXIA
# =========================================================

func apply_suffocation_damage(
	delta: float
):

	if breath_level > 0.0:
		return


	if health == null:
		return


	health.apply_damage(
		suffocation_damage_rate
		* delta,
		&"suffocation"
	)


# =========================================================
# PRESIÓN
# =========================================================

func apply_pressure_damage(
	delta: float
):

	if health == null:
		return


	var environment_pressure: float = (
		get_environment_pressure()
	)


	var safe_pressure: float = (
		get_effective_safe_pressure()
	)


	if environment_pressure <= safe_pressure:
		return


	var excess_pressure: float = (
		environment_pressure
		- safe_pressure
	)


	var damage: float = (
		excess_pressure
		* pressure_damage_rate
		* delta
	)


	health.apply_damage(
		damage,
		&"pressure_exposure"
	)


# =========================================================
# PRESIÓN DEL ENTORNO
# =========================================================

func get_environment_pressure() -> float:

	if current_room != null:

		return float(
			current_room.pressure
		)


	if submarine_environment != null:

		return float(
			submarine_environment.get_external_pressure()
		)


	return 1.0


# =========================================================
# PRESIÓN SEGURA
# =========================================================

func get_effective_safe_pressure() -> float:

	var protection_bonus: float = 0.0


	if equipment != null:

		protection_bonus = (
			equipment.get_pressure_protection_bonus()
		)


	return (
		safe_pressure_limit
		+ protection_bonus
	)


# =========================================================
# ESTADO DE PRESIÓN
# =========================================================

func get_pressure_status() -> String:

	var environment_pressure: float = (
		get_environment_pressure()
	)


	if (
		environment_pressure
		<= get_effective_safe_pressure()
	):

		return "SAFE"


	return "DANGER"


# =========================================================
# DETECCIÓN DE HABITACIÓN
# =========================================================

func find_current_room() -> Node:

	var active_rooms: Array[Node] = (
		get_current_rooms()
	)


	# -----------------------------------------------------
	# DETECCIÓN EXACTA
	# -----------------------------------------------------

	for room in active_rooms:

		if room == null:
			continue


		if not is_instance_valid(
			room
		):

			continue


		if room.contains_global_point(
			player.global_position
		):

			return room


	# -----------------------------------------------------
	# TOLERANCIA DE TRANSICIÓN
	#
	# Se usa distancia real al rectángulo para evitar
	# considerar interior una posición exterior lejana.
	# -----------------------------------------------------

	var closest_room: Node = null

	var closest_distance: float = INF


	for room in active_rooms:

		if room == null:
			continue


		if not is_instance_valid(
			room
		):

			continue


		var distance: float = (
			get_distance_to_room_rect(
				room,
				player.global_position
			)
		)


		if (
			distance <= transition_tolerance
			and distance < closest_distance
		):

			closest_distance = distance

			closest_room = room


	return closest_room


# =========================================================
# DISTANCIA A HABITACIÓN
# =========================================================

func get_distance_to_room_rect(
	room: Node,
	global_point: Vector2
) -> float:

	if room == null:
		return INF


	if not is_instance_valid(
		room
	):

		return INF


	var local_point: Vector2 = (
		room.to_local(
			global_point
		)
	)


	var minimum_corner: Vector2 = (
		room.room_position
	)


	var maximum_corner: Vector2 = (
		room.room_position
		+ room.room_size
	)


	var closest_point: Vector2 = Vector2(
		clamp(
			local_point.x,
			minimum_corner.x,
			maximum_corner.x
		),
		clamp(
			local_point.y,
			minimum_corner.y,
			maximum_corner.y
		)
	)


	return local_point.distance_to(
		closest_point
	)


# =========================================================
# RESERVA RESPIRATORIA
# =========================================================

func drain_breath(
	delta: float,
	severity: float
):

	breath_level -= (
		breath_drain_rate
		* severity
		* delta
	)


	breath_level = clamp(
		breath_level,
		0.0,
		1.0
	)


func recover_breath(
	delta: float
):

	breath_level += (
		breath_recovery_rate
		* delta
	)


	breath_level = clamp(
		breath_level,
		0.0,
		1.0
	)


# =========================================================
# INFORMACIÓN — HABITACIÓN / EXTERIOR
# =========================================================

func get_room_id() -> String:

	if current_room == null:

		return "EXTERIOR"


	return str(
		current_room.room_id
	)


func is_exterior() -> bool:

	return (
		current_room == null
	)


func get_environment_name() -> String:

	if is_exterior():

		return "EXTERIOR"


	return get_room_id()


# =========================================================
# INFORMACIÓN — AGUA
# =========================================================

func is_underwater() -> bool:

	if breathing_point == null:
		return false


	if current_room == null:

		return exterior_is_underwater


	return current_room.is_point_underwater(
		breathing_point.global_position
	)
