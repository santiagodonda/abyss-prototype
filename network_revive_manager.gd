extends Node


# =========================================================
# CONSTANTES
# =========================================================

const LIFE_ALIVE: String = "ALIVE"
const LIFE_UNCONSCIOUS: String = "UNCONSCIOUS"
const LIFE_DEAD: String = "DEAD"


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("Revive")

@export var revive_time: float = 5.0

@export_range(
	0.01,
	1.0,
	0.01
)
var revive_health_percentage: float = 0.25

@export var revive_distance: float = 125.0


@export_group("Synchronization")

@export var sync_interval: float = 0.10

@export var retry_after_reject: float = 0.35


@export_group("Debug")

@export var print_revive_events: bool = true


# =========================================================
# REFERENCIAS
# =========================================================

var health_manager = null

var player_manager = null

var local_player = null


# =========================================================
# ESTADO AUTORITATIVO
# =========================================================

# Key:
# rescuer_peer_id
#
# Value:
# {
#     "target_peer_id": int,
#     "progress": float
# }
var revive_sessions: Dictionary = {}


# =========================================================
# ESTADO REMOTO CLIENT
# =========================================================

var network_revive_sessions: Dictionary = {}


# =========================================================
# ESTADO LOCAL DE REQUEST
# =========================================================

var local_requested_target_id: int = 0

var local_retry_timer: float = 0.0


# =========================================================
# SINCRONIZACIÓN
# =========================================================

var sync_accumulator: float = 0.0


# =========================================================
# READY
# =========================================================

func _ready():

	add_to_group(
		"network_revive_manager"
	)


	process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)


	resolve_references()


	NetworkManager.player_disconnected.connect(
		_on_player_disconnected
	)


	NetworkManager.network_state_changed.connect(
		_on_network_state_changed
	)


	NetworkManager.network_restart_started.connect(
		_on_network_restart_started
	)


	print(
		"[NET REVIVE] Manager ready"
	)


# =========================================================
# RESOLVER REFERENCIAS
# =========================================================

func resolve_references():

	health_manager = (
		get_node_or_null(
			"../NetworkPlayerHealthManager"
		)
	)


	player_manager = (
		get_node_or_null(
			"../NetworkPlayerManager"
		)
	)


	local_player = (
		get_node_or_null(
			"../Player"
		)
	)


	# -----------------------------------------------------
	# FALLBACK HEALTH POR GROUP
	# -----------------------------------------------------

	if health_manager == null:

		var health_managers: Array = (
			get_tree().get_nodes_in_group(
				"network_player_health_manager"
			)
		)


		if not health_managers.is_empty():

			health_manager = (
				health_managers[0]
			)


	# -----------------------------------------------------
	# FALLBACK DESDE ESCENA
	# -----------------------------------------------------

	var scene = (
		get_tree().current_scene
	)


	if scene != null:

		if player_manager == null:

			player_manager = (
				scene.get_node_or_null(
					"NetworkPlayerManager"
				)
			)


		if local_player == null:

			local_player = (
				scene.get_node_or_null(
					"Player"
				)
			)


# =========================================================
# PROCESS
# =========================================================

func _process(
	delta: float
):

	if local_retry_timer > 0.0:

		local_retry_timer = max(
			local_retry_timer
			- delta,
			0.0
		)


	if NetworkManager.is_restart_in_progress():
		return


	if not NetworkManager.is_online():
		return


	if not NetworkManager.is_host():
		return


	process_revive_sessions(
		delta
	)


	sync_accumulator += delta


	if sync_accumulator < sync_interval:
		return


	sync_accumulator = 0.0


	broadcast_revive_sessions_unreliable()


# =========================================================
# REQUEST LOCAL — START
# =========================================================

func request_revive_start(
	target_peer_id: int
) -> bool:

	if NetworkManager.is_restart_in_progress():
		return false


	if not NetworkManager.is_online():
		return false


	if target_peer_id <= 0:
		return false


	var rescuer_peer_id: int = (
		get_local_peer_id()
	)


	if rescuer_peer_id <= 0:
		return false


	if rescuer_peer_id == target_peer_id:
		return false


	# -----------------------------------------------------
	# Ya tenemos este request activo.
	#
	# interact_hold() se ejecuta cada frame, por eso esta
	# condición evita RPC por frame.
	# -----------------------------------------------------

	if (
		local_requested_target_id
		== target_peer_id
	):

		return true


	# -----------------------------------------------------
	# No permitimos dos targets simultáneos.
	# -----------------------------------------------------

	if local_requested_target_id != 0:
		return false


	if local_retry_timer > 0.0:
		return false


	local_requested_target_id = (
		target_peer_id
	)


	# -----------------------------------------------------
	# HOST LOCAL
	# -----------------------------------------------------

	if NetworkManager.is_host():

		var accepted: bool = (
			start_revive_session(
				rescuer_peer_id,
				target_peer_id
			)
		)


		if not accepted:

			local_requested_target_id = 0

			local_retry_timer = (
				retry_after_reject
			)


		return accepted


	# -----------------------------------------------------
	# CLIENT -> HOST
	# -----------------------------------------------------

	request_revive_start_on_host.rpc_id(
		1,
		target_peer_id
	)


	return true


# =========================================================
# REQUEST LOCAL — STOP
# =========================================================

func request_revive_stop(
	target_peer_id: int
):

	if target_peer_id <= 0:
		return


	var rescuer_peer_id: int = (
		get_local_peer_id()
	)


	if rescuer_peer_id <= 0:
		return


	if (
		local_requested_target_id
		!= target_peer_id
	):

		return


	local_requested_target_id = 0


	if not NetworkManager.is_online():
		return


	if NetworkManager.is_host():

		stop_revive_session(
			rescuer_peer_id,
			target_peer_id,
			"RELEASE"
		)

		return


	request_revive_stop_on_host.rpc_id(
		1,
		target_peer_id
	)


# =========================================================
# CLIENT -> HOST — START
# =========================================================

@rpc(
	"any_peer",
	"call_remote",
	"reliable"
)
func request_revive_start_on_host(
	target_peer_id: int
):

	if not NetworkManager.is_host():
		return


	if NetworkManager.is_restart_in_progress():
		return


	var rescuer_peer_id: int = (
		multiplayer.get_remote_sender_id()
	)


	var accepted: bool = (
		start_revive_session(
			rescuer_peer_id,
			target_peer_id
		)
	)


	var reason: String = ""


	if not accepted:

		reason = (
			get_revive_rejection_reason(
				rescuer_peer_id,
				target_peer_id
			)
		)


	receive_revive_request_result.rpc_id(
		rescuer_peer_id,
		target_peer_id,
		accepted,
		reason
	)


# =========================================================
# CLIENT -> HOST — STOP
# =========================================================

@rpc(
	"any_peer",
	"call_remote",
	"reliable"
)
func request_revive_stop_on_host(
	target_peer_id: int
):

	if not NetworkManager.is_host():
		return


	if NetworkManager.is_restart_in_progress():
		return


	var rescuer_peer_id: int = (
		multiplayer.get_remote_sender_id()
	)


	stop_revive_session(
		rescuer_peer_id,
		target_peer_id,
		"RELEASE"
	)


# =========================================================
# HOST -> CLIENT — RESULTADO START
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func receive_revive_request_result(
	target_peer_id: int,
	accepted: bool,
	reason: String
):

	if NetworkManager.is_host():
		return


	if (
		local_requested_target_id
		!= target_peer_id
	):

		return


	if accepted:

		if print_revive_events:

			print(
				"[NET REVIVE][START ACK] Target ",
				target_peer_id
			)


		return


	local_requested_target_id = 0

	local_retry_timer = (
		retry_after_reject
	)


	if print_revive_events:

		print(
			"[NET REVIVE][REJECT] Target ",
			target_peer_id,
			" | ",
			reason
		)


# =========================================================
# START SESSION AUTORITATIVA
# =========================================================

func start_revive_session(
	rescuer_peer_id: int,
	target_peer_id: int
) -> bool:

	if not NetworkManager.is_host():
		return false


	# -----------------------------------------------------
	# START IDEMPOTENTE
	# -----------------------------------------------------

	if revive_sessions.has(
		rescuer_peer_id
	):

		var existing: Dictionary = (
			revive_sessions[
				rescuer_peer_id
			]
		)


		if int(
			existing.get(
				"target_peer_id",
				0
			)
		) == target_peer_id:

			return true


		return false


	if is_target_already_being_revived(
		target_peer_id
	):

		return false


	var rejection_reason: String = (
		get_revive_rejection_reason(
			rescuer_peer_id,
			target_peer_id
		)
	)


	if not rejection_reason.is_empty():

		if print_revive_events:

			print(
				"[NET REVIVE][REJECT] Rescuer ",
				rescuer_peer_id,
				" -> Target ",
				target_peer_id,
				" | ",
				rejection_reason
			)


		return false


	revive_sessions[
		rescuer_peer_id
	] = {
		"target_peer_id":
			target_peer_id,

		"progress":
			0.0
	}


	if print_revive_events:

		print(
			"[NET REVIVE][START] Rescuer ",
			rescuer_peer_id,
			" -> Target ",
			target_peer_id
		)


	broadcast_revive_sessions_reliable()


	return true


# =========================================================
# VALIDACIÓN START
# =========================================================

func get_revive_rejection_reason(
	rescuer_peer_id: int,
	target_peer_id: int
) -> String:

	if rescuer_peer_id <= 0:
		return "INVALID_RESCUER"


	if target_peer_id <= 0:
		return "INVALID_TARGET"


	if rescuer_peer_id == target_peer_id:
		return "SELF_REVIVE"


	if health_manager == null:

		resolve_references()


	if health_manager == null:
		return "NO_HEALTH_MANAGER"


	if player_manager == null:

		resolve_references()


	if player_manager == null:
		return "NO_PLAYER_MANAGER"


	if not peer_exists(
		rescuer_peer_id
	):

		return "RESCUER_NOT_CONNECTED"


	if not peer_exists(
		target_peer_id
	):

		return "TARGET_NOT_CONNECTED"


	var rescuer_state: String = (
		get_peer_life_state(
			rescuer_peer_id
		)
	)


	if rescuer_state != LIFE_ALIVE:

		return (
			"RESCUER_NOT_ALIVE_"
			+ rescuer_state
		)


	var target_state: String = (
		get_peer_life_state(
			target_peer_id
		)
	)


	if target_state != LIFE_UNCONSCIOUS:

		return (
			"TARGET_NOT_UNCONSCIOUS_"
			+ target_state
		)


	if is_target_already_being_revived(
		target_peer_id,
		rescuer_peer_id
	):

		return "TARGET_BUSY"


	var rescuer_position_data: Dictionary = (
		get_peer_position_data(
			rescuer_peer_id
		)
	)


	if not bool(
		rescuer_position_data.get(
			"valid",
			false
		)
	):

		return "NO_RESCUER_POSITION"


	var target_position_data: Dictionary = (
		get_peer_position_data(
			target_peer_id
		)
	)


	if not bool(
		target_position_data.get(
			"valid",
			false
		)
	):

		return "NO_TARGET_POSITION"


	var rescuer_position: Vector2 = (
		rescuer_position_data[
			"position"
		]
	)


	var target_position: Vector2 = (
		target_position_data[
			"position"
		]
	)


	var distance: float = (
		rescuer_position.distance_to(
			target_position
		)
	)


	if distance > revive_distance:

		return (
			"TOO_FAR_"
			+ str(
				snapped(
					distance,
					0.1
				)
			)
		)


	return ""


# =========================================================
# PROCESS SESSIONS
# =========================================================

func process_revive_sessions(
	delta: float
):

	if revive_sessions.is_empty():
		return


	var rescuer_ids: Array = (
		revive_sessions.keys()
	)


	for rescuer_key in rescuer_ids:

		var rescuer_peer_id: int = int(
			rescuer_key
		)


		if not revive_sessions.has(
			rescuer_peer_id
		):

			continue


		var session: Dictionary = (
			revive_sessions[
				rescuer_peer_id
			]
		)


		var target_peer_id: int = int(
			session.get(
				"target_peer_id",
				0
			)
		)


		var invalid_reason: String = (
			get_active_session_invalid_reason(
				rescuer_peer_id,
				target_peer_id
			)
		)


		if not invalid_reason.is_empty():

			stop_revive_session(
				rescuer_peer_id,
				target_peer_id,
				invalid_reason
			)

			continue


		var progress: float = float(
			session.get(
				"progress",
				0.0
			)
		)


		progress += delta


		session[
			"progress"
		] = progress


		revive_sessions[
			rescuer_peer_id
		] = session


		if progress < revive_time:
			continue


		complete_revive_session(
			rescuer_peer_id,
			target_peer_id
		)


# =========================================================
# VALIDACIÓN SESSION ACTIVA
# =========================================================

func get_active_session_invalid_reason(
	rescuer_peer_id: int,
	target_peer_id: int
) -> String:

	if not peer_exists(
		rescuer_peer_id
	):

		return "RESCUER_DISCONNECTED"


	if not peer_exists(
		target_peer_id
	):

		return "TARGET_DISCONNECTED"


	if (
		get_peer_life_state(
			rescuer_peer_id
		)
		!= LIFE_ALIVE
	):

		return "RESCUER_NOT_ALIVE"


	if (
		get_peer_life_state(
			target_peer_id
		)
		!= LIFE_UNCONSCIOUS
	):

		return "TARGET_NOT_UNCONSCIOUS"


	var rescuer_data: Dictionary = (
		get_peer_position_data(
			rescuer_peer_id
		)
	)


	var target_data: Dictionary = (
		get_peer_position_data(
			target_peer_id
		)
	)


	if not bool(
		rescuer_data.get(
			"valid",
			false
		)
	):

		return "NO_RESCUER_POSITION"


	if not bool(
		target_data.get(
			"valid",
			false
		)
	):

		return "NO_TARGET_POSITION"


	var distance: float = (
		Vector2(
			rescuer_data[
				"position"
			]
		).distance_to(
			Vector2(
				target_data[
					"position"
				]
			)
		)
	)


	if distance > revive_distance:

		return "TOO_FAR"


	return ""


# =========================================================
# COMPLETE
# =========================================================

func complete_revive_session(
	rescuer_peer_id: int,
	target_peer_id: int
):

	if not NetworkManager.is_host():
		return


	if health_manager == null:
		return


	var success: bool = (
		health_manager.revive_peer(
			target_peer_id,
			revive_health_percentage
		)
	)


	if not success:

		stop_revive_session(
			rescuer_peer_id,
			target_peer_id,
			"REVIVE_FAILED"
		)

		return


	revive_sessions.erase(
		rescuer_peer_id
	)


	if rescuer_peer_id == 1:

		local_requested_target_id = 0


	else:

		notify_revive_ended.rpc_id(
			rescuer_peer_id,
			target_peer_id,
			"COMPLETED"
		)


	if print_revive_events:

		print(
			"[NET REVIVE][COMPLETE] Rescuer ",
			rescuer_peer_id,
			" -> Target ",
			target_peer_id
		)


	broadcast_revive_sessions_reliable()


# =========================================================
# STOP SESSION
# =========================================================

func stop_revive_session(
	rescuer_peer_id: int,
	target_peer_id: int,
	reason: String
):

	if not NetworkManager.is_host():
		return


	if not revive_sessions.has(
		rescuer_peer_id
	):

		return


	var session: Dictionary = (
		revive_sessions[
			rescuer_peer_id
		]
	)


	if int(
		session.get(
			"target_peer_id",
			0
		)
	) != target_peer_id:

		return


	revive_sessions.erase(
		rescuer_peer_id
	)


	if rescuer_peer_id == 1:

		local_requested_target_id = 0


	else:

		notify_revive_ended.rpc_id(
			rescuer_peer_id,
			target_peer_id,
			reason
		)


	if print_revive_events:

		print(
			"[NET REVIVE][STOP] Rescuer ",
			rescuer_peer_id,
			" -> Target ",
			target_peer_id,
			" | ",
			reason
		)


	broadcast_revive_sessions_reliable()


# =========================================================
# HOST -> RESCUER — SESSION ENDED
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func notify_revive_ended(
	target_peer_id: int,
	reason: String
):

	if NetworkManager.is_host():
		return


	if (
		local_requested_target_id
		== target_peer_id
	):

		local_requested_target_id = 0


	if print_revive_events:

		print(
			"[NET REVIVE][END] Target ",
			target_peer_id,
			" | ",
			reason
		)


# =========================================================
# TARGET BUSY
# =========================================================

func is_target_already_being_revived(
	target_peer_id: int,
	ignore_rescuer_peer_id: int = 0
) -> bool:

	for rescuer_key in revive_sessions.keys():

		var rescuer_peer_id: int = int(
			rescuer_key
		)


		if (
			ignore_rescuer_peer_id > 0
			and rescuer_peer_id
				== ignore_rescuer_peer_id
		):

			continue


		var session: Dictionary = (
			revive_sessions[
				rescuer_key
			]
		)


		if int(
			session.get(
				"target_peer_id",
				0
			)
		) == target_peer_id:

			return true


	return false


# =========================================================
# HEALTH STATE
# =========================================================

func get_peer_life_state(
	peer_id: int
) -> String:

	if health_manager == null:
		return LIFE_DEAD


	if not health_manager.has_method(
		"get_peer_life_state"
	):

		return LIFE_DEAD


	return str(
		health_manager.get_peer_life_state(
			peer_id
		)
	)


# =========================================================
# PEER EXISTS
# =========================================================

func peer_exists(
	peer_id: int
) -> bool:

	if peer_id <= 0:
		return false


	if peer_id == 1:

		return NetworkManager.is_host()


	if not NetworkManager.is_host():
		return false


	var peers: PackedInt32Array = (
		multiplayer.get_peers()
	)


	return peers.has(
		peer_id
	)


# =========================================================
# POSICIÓN AUTORITATIVA
# =========================================================

func get_peer_position_data(
	peer_id: int
) -> Dictionary:

	if peer_id <= 0:

		return {
			"valid": false
		}


	# -----------------------------------------------------
	# HOST LOCAL
	# -----------------------------------------------------

	if peer_id == 1:

		if (
			local_player == null
			or not is_instance_valid(
				local_player
			)
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
	# REMOTE PEER
	#
	# Usamos target_position, no global_position interpolada.
	# Esto representa la última posición recibida por el Host.
	# -----------------------------------------------------

	if (
		player_manager == null
		or not is_instance_valid(
			player_manager
		)
	):

		return {
			"valid": false
		}


	if not player_manager.has_method(
		"get_remote_player"
	):

		return {
			"valid": false
		}


	var avatar = (
		player_manager.get_remote_player(
			peer_id
		)
	)


	if avatar == null:

		return {
			"valid": false
		}


	if not is_instance_valid(
		avatar
	):

		return {
			"valid": false
		}


	var target_value = (
		avatar.get(
			"target_position"
		)
	)


	if target_value is Vector2:

		return {
			"valid": true,
			"position":
				target_value
		}


	return {
		"valid": true,
		"position":
			avatar.global_position
	}


# =========================================================
# LOCAL PEER ID
# =========================================================

func get_local_peer_id() -> int:

	if not NetworkManager.is_online():
		return 0


	var multiplayer_api = (
		get_multiplayer()
	)


	if multiplayer_api == null:
		return 0


	return int(
		multiplayer_api.get_unique_id()
	)


# =========================================================
# NETWORK SESSION SYNC — RELIABLE
# =========================================================

func broadcast_revive_sessions_reliable():

	if not NetworkManager.is_host():
		return


	receive_revive_sessions_reliable.rpc(
		revive_sessions
	)


@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func receive_revive_sessions_reliable(
	state: Dictionary
):

	if NetworkManager.is_host():
		return


	network_revive_sessions = (
		state.duplicate(
			true
		)
	)


# =========================================================
# NETWORK SESSION SYNC — UNRELIABLE
# =========================================================

func broadcast_revive_sessions_unreliable():

	if not NetworkManager.is_host():
		return


	receive_revive_sessions_unreliable.rpc(
		revive_sessions
	)


@rpc(
	"authority",
	"call_remote",
	"unreliable"
)
func receive_revive_sessions_unreliable(
	state: Dictionary
):

	if NetworkManager.is_host():
		return


	network_revive_sessions = (
		state.duplicate(
			true
		)
	)


# =========================================================
# CONSULTA DE PROGRESO
# =========================================================

func get_target_revive_fraction(
	target_peer_id: int
) -> float:

	if target_peer_id <= 0:
		return 0.0


	var source: Dictionary


	if NetworkManager.is_host():

		source = revive_sessions

	else:

		source = network_revive_sessions


	var best_progress: float = 0.0


	for session_value in source.values():

		if not (
			session_value
			is Dictionary
		):

			continue


		var session: Dictionary = (
			session_value
		)


		if int(
			session.get(
				"target_peer_id",
				0
			)
		) != target_peer_id:

			continue


		best_progress = max(
			best_progress,
			float(
				session.get(
					"progress",
					0.0
				)
			)
		)


	if revive_time <= 0.0:
		return 0.0


	return clamp(
		best_progress
		/ revive_time,
		0.0,
		1.0
	)


# =========================================================
# LOCAL REQUEST
# =========================================================

func get_local_requested_target_id() -> int:

	return local_requested_target_id


# =========================================================
# PLAYER DISCONNECTED
# =========================================================

func _on_player_disconnected(
	peer_id: int
):

	if not NetworkManager.is_host():
		return


	var rescuer_ids: Array = (
		revive_sessions.keys()
	)


	for rescuer_key in rescuer_ids:

		var rescuer_peer_id: int = int(
			rescuer_key
		)


		if not revive_sessions.has(
			rescuer_peer_id
		):

			continue


		var session: Dictionary = (
			revive_sessions[
				rescuer_peer_id
			]
		)


		var target_peer_id: int = int(
			session.get(
				"target_peer_id",
				0
			)
		)


		if (
			rescuer_peer_id == peer_id
			or target_peer_id == peer_id
		):

			stop_revive_session(
				rescuer_peer_id,
				target_peer_id,
				"DISCONNECTED"
			)


# =========================================================
# NETWORK STATE
# =========================================================

func _on_network_state_changed(
	new_state: String
):

	if new_state != "OFFLINE":
		return


	clear_revive_state()


# =========================================================
# NETWORK RESTART
# =========================================================

func _on_network_restart_started():

	clear_revive_state()


# =========================================================
# CLEAR
# =========================================================

func clear_revive_state():

	revive_sessions.clear()

	network_revive_sessions.clear()

	local_requested_target_id = 0

	local_retry_timer = 0.0

	sync_accumulator = 0.0
