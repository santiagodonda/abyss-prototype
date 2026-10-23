extends Node


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("Interaction")

@export var interaction_distance: float = 140.0

@export var validate_distance: bool = true


@export_group("Debug")

@export var print_component_errors: bool = true


# =========================================================
# ESTADO LOCAL
# =========================================================

var local_hold_active: bool = false


# =========================================================
# REFERENCIAS
# =========================================================

var interaction_manager: Node = null


# =========================================================
# READY
# =========================================================

func _ready():

	process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)


	add_to_group(
		"network_interactable_component"
	)


	resolve_manager()


# =========================================================
# MANAGER
# =========================================================

func resolve_manager():

	interaction_manager = (
		get_tree().get_first_node_in_group(
			"network_interaction_manager"
		)
	)


func get_manager():

	if (
		interaction_manager != null
		and is_instance_valid(
			interaction_manager
		)
	):

		return interaction_manager


	resolve_manager()


	return interaction_manager


# =========================================================
# TARGET
# =========================================================

func get_target() -> Node:

	return get_parent()


func get_target_display_name() -> String:

	var target: Node = (
		get_target()
	)


	if target == null:
		return "UNKNOWN"


	return str(
		target.name
	)


# =========================================================
# REQUEST NORMAL
# =========================================================

func request_action(
	action: String,
	payload: Dictionary = {}
) -> bool:

	if not NetworkManager.is_online():
		return false


	var manager = (
		get_manager()
	)


	if manager == null:

		if print_component_errors:

			push_error(
				get_target_display_name()
				+ ": NetworkInteractionManager no encontrado."
			)

		return false


	manager.request_component_action(
		self,
		action,
		payload
	)


	return true


# =========================================================
# HOLD START
# =========================================================

func request_hold_start(
	action: String,
	payload: Dictionary = {}
) -> bool:

	if local_hold_active:
		return false


	var requested: bool = (
		request_action(
			action,
			payload
		)
	)


	if not requested:
		return false


	local_hold_active = true


	return true


# =========================================================
# HOLD STOP
# =========================================================

func request_hold_stop(
	action: String,
	payload: Dictionary = {}
) -> bool:

	# -----------------------------------------------------
	# IMPORTANTE
	#
	# Si nunca iniciamos una acción mantenida,
	# no enviamos STOP.
	#
	# Esto elimina los falsos repair_stop que
	# detectamos durante las pruebas.
	# -----------------------------------------------------

	if not local_hold_active:
		return false


	local_hold_active = false


	return request_action(
		action,
		payload
	)


# =========================================================
# HOLD STATE
# =========================================================

func clear_local_hold():

	local_hold_active = false


func is_local_hold_active() -> bool:

	return local_hold_active


# =========================================================
# VALIDACIÓN AUTORITATIVA
# =========================================================

func validate_network_request(
	peer_id: int,
	action: String,
	payload: Dictionary
) -> bool:

	var target: Node = (
		get_target()
	)


	if target == null:
		return false


	if not is_instance_valid(
		target
	):
		return false


	# -----------------------------------------------------
	# DISTANCIA
	# -----------------------------------------------------

	if (
		validate_distance
		and should_validate_distance(
			action
		)
	):

		var manager = (
			get_manager()
		)


		if manager == null:
			return false


		var position_result: Dictionary = (
			manager.get_player_position(
				peer_id
			)
		)


		if not position_result.get(
			"valid",
			false
		):

			return false


		var player_position: Vector2 = (
			position_result[
				"position"
			]
		)


		var interaction_position_result: Dictionary = (
			get_interaction_position()
		)


		if not interaction_position_result.get(
			"valid",
			false
		):

			return false


		var interaction_position: Vector2 = (
			interaction_position_result[
				"position"
			]
		)


		var distance: float = (
			player_position.distance_to(
				interaction_position
			)
		)


		if distance > interaction_distance:
			return false


	# -----------------------------------------------------
	# VALIDACIÓN ESPECÍFICA DEL OBJETO
	# -----------------------------------------------------

	if target.has_method(
		"network_validate_action"
	):

		return bool(
			target.network_validate_action(
				peer_id,
				action,
				payload
			)
		)


	return true


# =========================================================
# ¿LA ACCIÓN REQUIERE DISTANCIA?
# =========================================================

func should_validate_distance(
	action: String
) -> bool:

	var target: Node = (
		get_target()
	)


	if target == null:
		return true


	if target.has_method(
		"network_requires_distance"
	):

		return bool(
			target.network_requires_distance(
				action
			)
		)


	return true


# =========================================================
# POSICIÓN DEL INTERACTUABLE
# =========================================================

func get_interaction_position() -> Dictionary:

	var target: Node = (
		get_target()
	)


	if target == null:

		return {
			"valid": false
		}


	if target.has_method(
		"get_network_interaction_position"
	):

		return {
			"valid": true,
			"position":
				target.get_network_interaction_position()
		}


	if target is Node2D:

		return {
			"valid": true,
			"position":
				target.global_position
		}


	return {
		"valid": false
	}


# =========================================================
# EJECUCIÓN AUTORITATIVA
# =========================================================

func execute_network_request(
	peer_id: int,
	action: String,
	payload: Dictionary
):

	var target: Node = (
		get_target()
	)


	if target == null:
		return


	if not target.has_method(
		"network_execute_action"
	):

		return


	target.network_execute_action(
		peer_id,
		action,
		payload
	)


# =========================================================
# OBTENER ESTADO
# =========================================================

func get_network_state() -> Dictionary:

	var target: Node = (
		get_target()
	)


	if target == null:
		return {}


	if not target.has_method(
		"network_get_state"
	):

		return {}


	var state = (
		target.network_get_state()
	)


	if state is Dictionary:

		return state


	return {}


# =========================================================
# APLICAR ESTADO
# =========================================================

func apply_network_state(
	state: Dictionary
):

	var target: Node = (
		get_target()
	)


	if target == null:
		return


	if not target.has_method(
		"network_apply_state"
	):

		return


	target.network_apply_state(
		state
	)


# =========================================================
# BROADCAST
# =========================================================

func broadcast_state():

	if not NetworkManager.is_host():
		return


	var manager = (
		get_manager()
	)


	if manager == null:
		return


	manager.broadcast_component_state(
		self
	)


# =========================================================
# PLAYER POSITION
# =========================================================

func get_player_position(
	peer_id: int
) -> Dictionary:

	var manager = (
		get_manager()
	)


	if manager == null:

		return {
			"valid": false
		}


	return manager.get_player_position(
		peer_id
	)


# =========================================================
# PLAYER TOOL
# =========================================================

func get_player_tool_id(
	peer_id: int
) -> String:

	var manager = (
		get_manager()
	)


	if manager == null:
		return ""


	return str(
		manager.get_player_tool_id(
			peer_id
		)
	)
