extends Node2D


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("Depth Control")

@export var movement_speed: float = 20.0

@export var minimum_depth: float = 0.0

@export var maximum_depth: float = 1000.0

@export var target_tolerance: float = 0.5


@export_group("Power")

@export var power_draw: float = 35.0


@export_group("Debug")

@export var show_debug_label: bool = true


# =========================================================
# ESTADO
# =========================================================

var target_depth: float = 0.0


# =========================================================
# REFERENCIAS
# =========================================================

@onready var interaction_area: Area2D = (
	$InteractionArea
)


@onready var network_interactable = (
	get_node_or_null(
		"NetworkInteractable"
	)
)


@onready var submarine_environment = (
	$"../SubmarineEnvironment"
)


@onready var power_system = (
	$"../PowerSystem"
)


# =========================================================
# DEBUG
# =========================================================

var debug_label: Label


# =========================================================
# INICIALIZACIÓN
# =========================================================

func _ready():

	interaction_area.add_to_group(
		"interactable_area"
	)


	target_depth = (
		get_current_depth()
	)


	power_system.set_consumer_demand(
		name,
		0.0
	)


	if power_system.has_signal(
		"power_changed"
	):

		power_system.power_changed.connect(
			queue_redraw
		)


	if submarine_environment.has_signal(
		"depth_changed"
	):

		submarine_environment.depth_changed.connect(
			_on_depth_changed
		)


	if show_debug_label:

		create_debug_label()


	update_power_demand()

	update_debug()

	queue_redraw()


# =========================================================
# LIMPIEZA
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

	hold_current_depth()


# =========================================================
# PRIORIDAD
# =========================================================

func get_interaction_priority(
	_player
) -> int:

	return 10


# =========================================================
# SIMULACIÓN
# =========================================================

func _process(
	delta
):

	# -----------------------------------------------------
	# DEPTH AUTHORITY
	#
	# Offline:
	#   simula normalmente.
	#
	# Multiplayer Host:
	#   simula profundidad real.
	#
	# Multiplayer Client:
	#   solamente representa profundidad recibida.
	# -----------------------------------------------------

	if (
		NetworkManager.is_online()
		and not NetworkManager.is_host()
	):

		return


	var current_depth: float = (
		get_current_depth()
	)


	var difference: float = (
		target_depth
		- current_depth
	)


	# -----------------------------------------------------
	# YA LLEGAMOS
	# -----------------------------------------------------

	if abs(
		difference
	) <= target_tolerance:

		if current_depth != target_depth:

			set_environment_depth(
				target_depth
			)


		update_power_demand()

		update_debug()

		queue_redraw()

		return


	# -----------------------------------------------------
	# SIN ENERGÍA
	# -----------------------------------------------------

	if not power_system.has_power():

		update_power_demand()

		update_debug()

		queue_redraw()

		return


	# -----------------------------------------------------
	# MOVIMIENTO
	# -----------------------------------------------------

	var movement_amount: float = (
		movement_speed
		* delta
	)


	var new_depth: float = (
		current_depth
	)


	if difference > 0.0:

		new_depth = min(
			current_depth
			+ movement_amount,
			target_depth
		)

	else:

		new_depth = max(
			current_depth
			- movement_amount,
			target_depth
		)


	new_depth = clamp(
		new_depth,
		minimum_depth,
		maximum_depth
	)


	set_environment_depth(
		new_depth
	)


	update_power_demand()

	update_debug()

	queue_redraw()


# =========================================================
# PROFUNDIDAD ACTUAL
# =========================================================

func get_current_depth() -> float:

	if submarine_environment == null:
		return 0.0


	return float(
		submarine_environment.get(
			"depth_meters"
		)
	)


func set_environment_depth(
	new_depth: float
):

	if submarine_environment == null:
		return


	if submarine_environment.has_method(
		"set_depth"
	):

		submarine_environment.set_depth(
			new_depth
		)

		return


	submarine_environment.set(
		"depth_meters",
		new_depth
	)


# =========================================================
# TARGET DEPTH
# =========================================================

func set_target_depth(
	new_target: float
):

	if NetworkManager.is_online():

		if network_interactable == null:

			push_error(
				"SubmarineHelm: NetworkInteractable no encontrado."
			)

			return


		network_interactable.request_action(
			"set_target",
			{
				"target":
					new_target
			}
		)

		return


	apply_target_depth_internal(
		new_target
	)


func change_target_depth(
	amount: float
):

	if NetworkManager.is_online():

		if network_interactable == null:

			push_error(
				"SubmarineHelm: NetworkInteractable no encontrado."
			)

			return


		network_interactable.request_action(
			"change_target",
			{
				"amount":
					amount
			}
		)

		return


	apply_target_depth_internal(
		target_depth
		+ amount
	)


func ascend_25():

	change_target_depth(
		-25.0
	)


func descend_25():

	change_target_depth(
		25.0
	)


func ascend_100():

	change_target_depth(
		-100.0
	)


func descend_100():

	change_target_depth(
		100.0
	)


func hold_current_depth():

	if NetworkManager.is_online():

		if network_interactable == null:

			push_error(
				"SubmarineHelm: NetworkInteractable no encontrado."
			)

			return


		network_interactable.request_action(
			"hold",
			{}
		)

		return


	apply_target_depth_internal(
		get_current_depth()
	)


func apply_target_depth_internal(
	new_target: float
):

	target_depth = clamp(
		new_target,
		minimum_depth,
		maximum_depth
	)


	update_power_demand()

	update_debug()

	queue_redraw()


func get_target_depth() -> float:

	return target_depth


# =========================================================
# NETWORK INTERACTABLE
# =========================================================

func network_requires_distance(
	_action: String
) -> bool:

	return true


func network_validate_action(
	_peer_id: int,
	action: String,
	payload: Dictionary
) -> bool:

	match action:

		"set_target":

			return payload.has(
				"target"
			)


		"change_target":

			return payload.has(
				"amount"
			)


		"hold":

			return true


	return false


func network_execute_action(
	_peer_id: int,
	action: String,
	payload: Dictionary
):

	match action:

		"set_target":

			apply_target_depth_internal(
				float(
					payload.get(
						"target",
						target_depth
					)
				)
			)


		"change_target":

			apply_target_depth_internal(
				target_depth
				+ float(
					payload.get(
						"amount",
						0.0
					)
				)
			)


		"hold":

			apply_target_depth_internal(
				get_current_depth()
			)


func network_get_state() -> Dictionary:

	return {
		"target_depth":
			target_depth
	}


func network_apply_state(
	state: Dictionary
):

	if not state.has(
		"target_depth"
	):

		return


	apply_target_depth_internal(
		float(
			state[
				"target_depth"
			]
		)
	)


# =========================================================
# MOVIMIENTO / ESTADO
# =========================================================

func is_at_target_depth() -> bool:

	return (
		abs(
			get_current_depth()
			- target_depth
		)
		<= target_tolerance
	)


func is_ascending() -> bool:

	return (
		target_depth
		< get_current_depth()
		- target_tolerance
	)


func is_descending() -> bool:

	return (
		target_depth
		> get_current_depth()
		+ target_tolerance
	)


func get_mode_text() -> String:

	if is_at_target_depth():
		return "HOLD"


	if is_ascending():
		return "ASCENDING"


	if is_descending():
		return "DESCENDING"


	return "HOLD"


# =========================================================
# ENERGÍA
# =========================================================

func update_power_demand():

	if power_system == null:
		return


	if is_at_target_depth():

		power_system.set_consumer_demand(
			name,
			0.0
		)

	else:

		power_system.set_consumer_demand(
			name,
			power_draw
		)


func has_power() -> bool:

	if power_system == null:
		return false


	return power_system.has_power()


# =========================================================
# ESTADO
# =========================================================

func get_status_text() -> String:

	if (
		not is_at_target_depth()
		and not has_power()
	):

		return "NO POWER"


	return get_mode_text()


# =========================================================
# CAMBIO DE DEPTH
# =========================================================

func _on_depth_changed(
	_new_depth: float
):

	update_power_demand()

	update_debug()

	queue_redraw()


# =========================================================
# DEBUG LABEL
# =========================================================

func create_debug_label():

	debug_label = Label.new()


	debug_label.name = (
		"HelmDebugLabel"
	)


	debug_label.position = Vector2(
		-105,
		-95
	)


	debug_label.size = Vector2(
		210,
		80
	)


	debug_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	debug_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)


	debug_label.add_theme_font_size_override(
		"font_size",
		13
	)


	debug_label.add_theme_constant_override(
		"outline_size",
		4
	)


	debug_label.add_theme_color_override(
		"font_outline_color",
		Color(
			0.0,
			0.0,
			0.0,
			1.0
		)
	)


	debug_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	debug_label.z_index = 110


	add_child(
		debug_label
	)


# =========================================================
# ACTUALIZAR DEBUG
# =========================================================

func update_debug():

	if debug_label == null:
		return


	debug_label.text = (
		"CONTROL SUBMARINO\n"
		+ get_status_text()
		+ "\nDEPTH: "
		+ str(
			int(
				round(
					get_current_depth()
				)
			)
		)
		+ " m"
		+ "\nTARGET: "
		+ str(
			int(
				round(
					target_depth
				)
			)
		)
		+ " m"
	)


# =========================================================
# VISUAL
# =========================================================

func _draw():

	draw_rect(
		Rect2(
			-45,
			-35,
			90,
			70
		),
		Color(
			0.15,
			0.20,
			0.22,
			1.0
		)
	)


	draw_rect(
		Rect2(
			-30,
			-18,
			60,
			25
		),
		Color(
			0.10,
			0.35,
			0.38,
			1.0
		)
	)


	var indicator_color: Color


	if is_at_target_depth():

		indicator_color = Color(
			0.35,
			0.55,
			0.65,
			1.0
		)

	elif not has_power():

		indicator_color = Color(
			0.9,
			0.45,
			0.1,
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
		Vector2(
			0,
			20
		),
		8,
		indicator_color
	)
