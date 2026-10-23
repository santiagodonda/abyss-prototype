extends Node


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("Debug")

@export var print_interactions: bool = true


# =========================================================
# REFERENCIAS
# =========================================================

@onready var local_player = (
	get_node_or_null(
		"../Player"
	)
)


@onready var network_player_manager = (
	get_node_or_null(
		"../NetworkPlayerManager"
	)
)


# =========================================================
# READY
# =========================================================

func _ready():

	process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)


	add_to_group(
		"network_interaction_manager"
	)


	NetworkManager.player_connected.connect(
		_on_player_connected
	)


	if print_interactions:

		print(
			"[NET INTERACT] Manager ready"
		)


# =========================================================
# REQUEST DEL COMPONENTE
# =========================================================

func request_component_action(
	component: Node,
	action: String,
	payload: Dictionary = {}
):

	if NetworkManager.is_restart_in_progress():
		return


	if component == null:
		return


	if not is_instance_valid(
		component
	):
		return


	if not NetworkManager.is_online():
		return


	var current_scene = (
		get_tree().current_scene
	)


	if current_scene == null:
		return


	if not current_scene.is_ancestor_of(
		component
	):
		return


	var component_path: NodePath = (
		current_scene.get_path_to(
			component
		)
	)


	# =====================================================
	# HOST
	# =====================================================

	if NetworkManager.is_host():

		process_interaction_request(
			1,
			component_path,
			action,
			payload
		)

		return


	# =====================================================
	# CLIENT
	# =====================================================

	if NetworkManager.is_client():

		request_interaction_from_host.rpc_id(
			1,
			component_path,
			action,
			payload
		)


# =========================================================
# CLIENT -> HOST
# =========================================================

@rpc(
	"any_peer",
	"call_remote",
	"reliable"
)
func request_interaction_from_host(
	component_path: NodePath,
	action: String,
	payload: Dictionary
):

	if NetworkManager.is_restart_in_progress():
		return


	if not is_inside_tree():
		return


	var multiplayer_api = (
		get_multiplayer()
	)


	if multiplayer_api == null:
		return


	if not multiplayer_api.is_server():
		return


	var sender_id: int = (
		multiplayer_api.get_remote_sender_id()
	)


	if sender_id <= 1:
		return


	process_interaction_request(
		sender_id,
		component_path,
		action,
		payload
	)


# =========================================================
# HOST PROCESA
# =========================================================

func process_interaction_request(
	peer_id: int,
	component_path: NodePath,
	action: String,
	payload: Dictionary
):

	if NetworkManager.is_restart_in_progress():
		return


	if not NetworkManager.is_host():
		return


	var component: Node = (
		resolve_component(
			component_path
		)
	)


	if component == null:

		if print_interactions:

			print(
				"[NET INTERACT][REJECT] Component not found | ",
				component_path
			)

		return


	var display_name: String = (
		get_component_display_name(
			component
		)
	)


	if not component.has_method(
		"validate_network_request"
	):

		if print_interactions:

			print(
				"[NET INTERACT][REJECT] Invalid component | ",
				display_name
			)

		return


	if not component.has_method(
		"execute_network_request"
	):

		if print_interactions:

			print(
				"[NET INTERACT][REJECT] Missing execution | ",
				display_name
			)

		return


	if not component.has_method(
		"get_network_state"
	):

		if print_interactions:

			print(
				"[NET INTERACT][REJECT] Missing state | ",
				display_name
			)

		return


	var accepted: bool = (
		component.validate_network_request(
			peer_id,
			action,
			payload
		)
	)


	if not accepted:

		if print_interactions:

			print(
				"[NET INTERACT][REJECT] ",
				display_name,
				" | Peer ",
				peer_id,
				" | Action ",
				action
			)

		return


	# -----------------------------------------------------
	# HOST EJECUTA
	# -----------------------------------------------------

	component.execute_network_request(
		peer_id,
		action,
		payload
	)


	# -----------------------------------------------------
	# REPLICAR RESULTADO
	# -----------------------------------------------------

	broadcast_component_state(
		component
	)


	if print_interactions:

		print(
			"[NET INTERACT][OK] ",
			display_name,
			" | Peer ",
			peer_id,
			" | Action ",
			action
		)


# =========================================================
# RESOLVER COMPONENTE
# =========================================================

func resolve_component(
	component_path: NodePath
):

	var current_scene = (
		get_tree().current_scene
	)


	if current_scene == null:
		return null


	var component: Node = (
		current_scene.get_node_or_null(
			component_path
		)
	)


	if component == null:
		return null


	if not component.is_in_group(
		"network_interactable_component"
	):

		return null


	return component


# =========================================================
# NOMBRE DEL TARGET
# =========================================================

func get_component_display_name(
	component: Node
) -> String:

	if component == null:
		return "UNKNOWN"


	if component.has_method(
		"get_target_display_name"
	):

		return str(
			component.get_target_display_name()
		)


	var target: Node = (
		component.get_parent()
	)


	if target == null:
		return str(
			component.name
		)


	return str(
		target.name
	)


# =========================================================
# BROADCAST
# =========================================================

func broadcast_component_state(
	component: Node
):

	if NetworkManager.is_restart_in_progress():
		return


	if not NetworkManager.is_host():
		return


	if component == null:
		return


	if not is_instance_valid(
		component
	):
		return


	if not component.has_method(
		"get_network_state"
	):

		return


	var current_scene = (
		get_tree().current_scene
	)


	if current_scene == null:
		return


	if not current_scene.is_ancestor_of(
		component
	):

		return


	var component_path: NodePath = (
		current_scene.get_path_to(
			component
		)
	)


	var state: Dictionary = (
		component.get_network_state()
	)


	receive_interaction_state.rpc(
		component_path,
		state
	)


# =========================================================
# HOST -> CLIENTS
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func receive_interaction_state(
	component_path: NodePath,
	state: Dictionary
):

	if NetworkManager.is_restart_in_progress():
		return


	if not is_inside_tree():
		return


	var component: Node = (
		resolve_component(
			component_path
		)
	)


	if component == null:
		return


	if not component.has_method(
		"apply_network_state"
	):

		return


	component.apply_network_state(
		state
	)


# =========================================================
# POSICIÓN DEL PLAYER
# =========================================================

func get_player_position(
	peer_id: int
) -> Dictionary:

	# -----------------------------------------------------
	# HOST LOCAL
	# -----------------------------------------------------

	if peer_id == 1:

		if local_player == null:

			return {
				"valid": false
			}


		if not is_instance_valid(
			local_player
		):

			return {
				"valid": false
			}


		return {
			"valid": true,
			"position":
				local_player.global_position
		}


	# -----------------------------------------------------
	# CLIENT REMOTO
	# -----------------------------------------------------

	if network_player_manager == null:

		return {
			"valid": false
		}


	if not network_player_manager.has_method(
		"get_remote_player"
	):

		return {
			"valid": false
		}


	var remote_player = (
		network_player_manager.get_remote_player(
			peer_id
		)
	)


	if remote_player == null:

		return {
			"valid": false
		}


	if not is_instance_valid(
		remote_player
	):

		return {
			"valid": false
		}


	return {
		"valid": true,
		"position":
			remote_player.target_position
	}


# =========================================================
# HERRAMIENTA DEL PLAYER
# =========================================================

func get_player_tool_id(
	peer_id: int
) -> String:

	# -----------------------------------------------------
	# HOST LOCAL
	# -----------------------------------------------------

	if peer_id == 1:

		if local_player == null:
			return ""


		if not is_instance_valid(
			local_player
		):

			return ""


		var equipment = (
			local_player.get_node_or_null(
				"Equipment"
			)
		)


		if equipment == null:
			return ""


		if not equipment.has_method(
			"get_equipped_tool"
		):

			return ""


		return str(
			equipment.get_equipped_tool()
		)


	# -----------------------------------------------------
	# CLIENT REMOTO
	# -----------------------------------------------------

	if network_player_manager == null:
		return ""


	if not network_player_manager.has_method(
		"get_remote_player"
	):

		return ""


	var remote_player = (
		network_player_manager.get_remote_player(
			peer_id
		)
	)


	if remote_player == null:
		return ""


	if not is_instance_valid(
		remote_player
	):

		return ""


	return str(
		remote_player.active_tool_id
	)


# =========================================================
# NUEVO PEER
# =========================================================

func _on_player_connected(
	peer_id: int
):

	if NetworkManager.is_restart_in_progress():
		return


	if not NetworkManager.is_host():
		return


	if peer_id == 1:
		return


	call_deferred(
		"send_world_interaction_snapshot",
		peer_id
	)


# =========================================================
# SNAPSHOT LATE JOIN
# =========================================================

func send_world_interaction_snapshot(
	peer_id: int
):

	if NetworkManager.is_restart_in_progress():
		return


	if not NetworkManager.is_host():
		return


	await get_tree().process_frame

	await get_tree().process_frame


	if NetworkManager.is_restart_in_progress():
		return


	var current_scene = (
		get_tree().current_scene
	)


	if current_scene == null:
		return


	var components: Array = (
		get_tree().get_nodes_in_group(
			"network_interactable_component"
		)
	)


	var sent_count: int = 0


	for component in components:

		if component == null:
			continue


		if not is_instance_valid(
			component
		):

			continue


		if not current_scene.is_ancestor_of(
			component
		):

			continue


		if not component.has_method(
			"get_network_state"
		):

			continue


		var component_path: NodePath = (
			current_scene.get_path_to(
				component
			)
		)


		var state: Dictionary = (
			component.get_network_state()
		)


		receive_interaction_state.rpc_id(
			peer_id,
			component_path,
			state
		)


		sent_count += 1


	if print_interactions:

		print(
			"[NET INTERACT] Snapshot sent | Peer ",
			peer_id,
			" | Objects ",
			sent_count
		)
