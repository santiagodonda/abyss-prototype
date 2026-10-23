extends Node


signal depth_changed(
	new_depth: float
)

signal external_pressure_changed(
	new_pressure: float
)


@export_group("Depth")

@export var depth_meters: float = 200.0


@export_group("Pressure Model")

@export var surface_pressure: float = 1.0

@export var pressure_per_100m: float = 1.0

@export var max_external_pressure: float = 10.0


var external_pressure: float = 1.0


# =========================================================
# READY
# =========================================================

func _ready():

	recalculate_external_pressure()


# =========================================================
# DEPTH — AUTORITATIVA
# =========================================================

func set_depth(
	value: float
):

	if (
		NetworkManager.is_online()
		and not NetworkManager.is_host()
	):

		return


	apply_depth_internal(
		value
	)


# =========================================================
# DEPTH — RECIBIDA DEL HOST
# =========================================================

func apply_network_depth(
	value: float
):

	apply_depth_internal(
		value
	)


# =========================================================
# DEPTH — INTERNA
# =========================================================

func apply_depth_internal(
	value: float
):

	var new_depth: float = max(
		value,
		0.0
	)


	if is_equal_approx(
		new_depth,
		depth_meters
	):

		return


	depth_meters = new_depth


	recalculate_external_pressure()


	depth_changed.emit(
		depth_meters
	)


# =========================================================
# PRESIÓN EXTERIOR
# =========================================================

func recalculate_external_pressure():

	var calculated_pressure: float = (
		surface_pressure
		+ (
			depth_meters
			/ 100.0
		)
		* pressure_per_100m
	)


	external_pressure = clamp(
		calculated_pressure,
		surface_pressure,
		max_external_pressure
	)


	external_pressure_changed.emit(
		external_pressure
	)


func get_external_pressure() -> float:

	return external_pressure
