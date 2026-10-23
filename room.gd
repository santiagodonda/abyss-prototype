extends Node2D


signal water_changed(
	new_level: float
)

signal oxygen_changed(
	new_level: float
)

signal pressure_changed(
	new_pressure: float
)


# =========================================================
# IDENTIDAD
# =========================================================

@export var room_id: StringName = (
	&"room_unknown"
)


# =========================================================
# GEOMETRÍA
# =========================================================

@export_group("Room Geometry")

@export var room_position: Vector2

@export var room_size: Vector2


# =========================================================
# AMBIENTE
# =========================================================

@export_group("Environment")

@export_range(
	0.0,
	1.0
)
var water_level: float = 0.0


@export_range(
	0.0,
	1.0
)
var oxygen_level: float = 1.0


@export var pressure: float = 1.0

@export var temperature: float = 20.0


# =========================================================
# INUNDACIÓN
# =========================================================

@export_group("Flooding")

@export var flood_speed: float = 0.08


var flooding: bool = false


const SIMULATION_INTERVAL := 0.1

var simulation_accumulator: float = 0.0


# =========================================================
# READY
# =========================================================

func _ready():

	add_to_group(
		"rooms"
	)


	queue_redraw()


# =========================================================
# ROOM DETECTION
# =========================================================

func contains_global_point(
	global_point: Vector2
) -> bool:

	var local_point: Vector2 = (
		to_local(
			global_point
		)
	)


	var room_rect: Rect2 = Rect2(
		room_position,
		room_size
	)


	return room_rect.has_point(
		local_point
	)


# =========================================================
# WATER / UNDERWATER DETECTION
# =========================================================

func is_point_underwater(
	global_point: Vector2
) -> bool:

	if water_level <= 0.0:
		return false


	var local_point: Vector2 = (
		to_local(
			global_point
		)
	)


	var water_height: float = (
		room_size.y
		* water_level
	)


	var water_surface_y: float = (
		room_position.y
		+ room_size.y
		- water_height
	)


	return (
		local_point.y
		>= water_surface_y
	)


# =========================================================
# OXYGEN — CONSUMO
# =========================================================

func consume_oxygen(
	amount: float
):

	if amount <= 0.0:
		return


	set_oxygen_level(
		oxygen_level
		- amount
	)


# =========================================================
# OXYGEN — LOCAL / AUTORITATIVO
# =========================================================

func set_oxygen_level(
	value: float
):

	if (
		NetworkManager.is_online()
		and not NetworkManager.is_host()
	):

		return


	apply_oxygen_level_internal(
		value
	)


# =========================================================
# OXYGEN — RECIBIDO DEL HOST
# =========================================================

func apply_network_oxygen_level(
	value: float
):

	apply_oxygen_level_internal(
		value
	)


# =========================================================
# OXYGEN — IMPLEMENTACIÓN INTERNA
# =========================================================

func apply_oxygen_level_internal(
	value: float
):

	var new_level: float = clamp(
		value,
		0.0,
		1.0
	)


	if is_equal_approx(
		new_level,
		oxygen_level
	):

		return


	oxygen_level = new_level


	oxygen_changed.emit(
		oxygen_level
	)


# =========================================================
# ROOM SIMULATION
# =========================================================

func _process(
	delta: float
):

	if (
		NetworkManager.is_online()
		and not NetworkManager.is_host()
	):

		return


	simulation_accumulator += delta


	if (
		simulation_accumulator
		< SIMULATION_INTERVAL
	):

		return


	var simulation_delta: float = (
		simulation_accumulator
	)


	simulation_accumulator = 0.0


	simulate_room(
		simulation_delta
	)


func simulate_room(
	delta: float
):

	if flooding:

		set_water_level(
			water_level
			+ flood_speed
			* delta
		)


# =========================================================
# PRESSURE — LOCAL / AUTORITATIVO
# =========================================================

func set_pressure(
	value: float
):

	# -----------------------------------------------------
	# En multiplayer solamente el Host puede modificar
	# la presión real de una habitación.
	#
	# Esto bloquea automáticamente en Client:
	#
	# PressureSystem
	# PressureRegulator
	# HullBreach
	# y cualquier futura fuente de presión.
	# -----------------------------------------------------

	if (
		NetworkManager.is_online()
		and not NetworkManager.is_host()
	):

		return


	apply_pressure_internal(
		value
	)


# =========================================================
# PRESSURE — RECIBIDA DEL HOST
# =========================================================

func apply_network_pressure(
	value: float
):

	apply_pressure_internal(
		value
	)


# =========================================================
# PRESSURE — IMPLEMENTACIÓN INTERNA
# =========================================================

func apply_pressure_internal(
	value: float
):

	var new_pressure: float = max(
		value,
		0.0
	)


	if is_equal_approx(
		new_pressure,
		pressure
	):

		return


	pressure = new_pressure


	pressure_changed.emit(
		pressure
	)


# =========================================================
# FLOODING
# =========================================================

func set_flooding(
	value: bool
):

	flooding = value


# =========================================================
# WATER — LOCAL / AUTORITATIVO
# =========================================================

func set_water_level(
	value: float
):

	if (
		NetworkManager.is_online()
		and not NetworkManager.is_host()
	):

		return


	apply_water_level_internal(
		value
	)


# =========================================================
# WATER — RECIBIDO DEL HOST
# =========================================================

func apply_network_water_level(
	value: float
):

	apply_water_level_internal(
		value
	)


# =========================================================
# WATER — IMPLEMENTACIÓN INTERNA
# =========================================================

func apply_water_level_internal(
	value: float
):

	var new_level: float = clamp(
		value,
		0.0,
		1.0
	)


	if is_equal_approx(
		new_level,
		water_level
	):

		return


	water_level = new_level


	water_changed.emit(
		water_level
	)


	queue_redraw()


# =========================================================
# VISUAL WATER
# =========================================================

func _draw():

	if water_level <= 0.0:
		return


	var water_height: float = (
		room_size.y
		* water_level
	)


	var water_y: float = (
		room_position.y
		+ room_size.y
		- water_height
	)


	draw_rect(
		Rect2(
			room_position.x,
			water_y,
			room_size.x,
			water_height
		),
		Color(
			0.05,
			0.35,
			0.55,
			0.65
		)
	)
