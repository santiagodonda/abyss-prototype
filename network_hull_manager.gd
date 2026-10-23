extends Node


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("Synchronization")

@export_range(
	2.0,
	30.0,
	1.0
)
var sync_rate_hz: float = 10.0


@export_group("Repair")

@export var fuel_confirmation_timeout: float = 3.0


@export_group("Debug")

@export var print_hull_events: bool = true


# =========================================================
# ESTADO
# =========================================================

var sync_accumulator: float = 0.0


# Peer ID -> repair session
var repair_sessions: Dictionary = {}


# Breach ID -> Peer ID
var active_repair_peer_by_breach: Dictionary = {}


# Peer ID -> pending fuel confirmation
var pending_fuel_confirmation: Dictionary = {}


# =========================================================
# REFERENCIAS
# =========================================================

@onready var network_interaction_manager = (
	get_node_or_null(
		"../NetworkInteractionManager"
	)
)


@onready var local_player = (
	get_node_or_null(
		"../Player"
	)
)


# =========================================================
# READY
# =========================================================

func _ready():

	add_to_group(
		"network_hull_manager"
	)


	process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)


	NetworkManager.player_connected.connect(
		_on_player_connected
	)


	NetworkManager.player_disconnected.connect(
		_on_player_disconnected
	)


	if print_hull_events:

		print(
			"[NET HULL] Manager ready"
		)


# =========================================================
# PROCESS
# =========================================================

func _process(
	delta: float
):

	if NetworkManager.is_restart_in_progress():
		return


	if not NetworkManager.is_online():
		return


	if not NetworkManager.is_host():
		return


	process_repair_sessions(
		delta
	)


	process_pending_fuel_confirmations(
		delta
	)


	sync_accumulator += delta


	var sync_interval: float = (
		1.0
		/ max(
			sync_rate_hz,
			1.0
		)
	)


	if sync_accumulator < sync_interval:
		return


	sync_accumulator = 0.0


	broadcast_hull_state()


# =========================================================
# BROADCAST
# =========================================================

func broadcast_hull_state():

	if not NetworkManager.is_online():
		return


	if not NetworkManager.is_host():
		return


	var hull_states: Dictionary = (
		build_hull_state_dictionary()
	)


	var breach_states: Dictionary = (
		build_breach_state_dictionary()
	)


	receive_hull_state_sync.rpc(
		hull_states,
		breach_states
	)


# =========================================================
# BUILD HULL STATES
# =========================================================

func build_hull_state_dictionary() -> Dictionary:

	var result: Dictionary = {}


	var hull_points: Array = (
		get_tree().get_nodes_in_group(
			"network_hull_point"
		)
	)


	for hull_point in hull_points:

		if hull_point == null:
			continue


		if not is_instance_valid(
			hull_point
		):
			continue


		if not hull_point.has_method(
			"get_network_hull_id"
		):
			continue


		if not hull_point.has_method(
			"build_network_state"
		):
			continue


		var hull_id: String = str(
			hull_point.get_network_hull_id()
		)


		if hull_id.is_empty():
			continue


		result[
			hull_id
		] = (
			hull_point.build_network_state()
		)


	return result


# =========================================================
# BUILD BREACH STATES
# =========================================================

func build_breach_state_dictionary() -> Dictionary:

	var result: Dictionary = {}


	var breaches: Array = (
		get_tree().get_nodes_in_group(
			"network_hull_breach"
		)
	)


	for breach in breaches:

		if breach == null:
			continue


		if not is_instance_valid(
			breach
		):
			continue


		if not breach.has_method(
			"get_network_breach_id"
		):
			continue


		if not breach.has_method(
			"build_network_state"
		):
			continue


		var breach_id: String = str(
			breach.get_network_breach_id()
		)


		if breach_id.is_empty():
			continue


		result[
			breach_id
		] = (
			breach.build_network_state()
		)


	return result


# =========================================================
# CLIENT RECEIVE — CONTINUOUS
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"unreliable"
)
func receive_hull_state_sync(
	hull_states: Dictionary,
	breach_states: Dictionary
):

	if NetworkManager.is_restart_in_progress():
		return


	if NetworkManager.is_host():
		return


	apply_hull_states(
		hull_states
	)


	apply_breach_states(
		breach_states
	)


# =========================================================
# CLIENT RECEIVE — SNAPSHOT
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func receive_hull_snapshot(
	hull_states: Dictionary,
	breach_states: Dictionary
):

	if NetworkManager.is_restart_in_progress():
		return


	if NetworkManager.is_host():
		return


	apply_hull_states(
		hull_states
	)


	apply_breach_states(
		breach_states
	)


	if print_hull_events:

		print(
			"[NET HULL] Snapshot received | Hulls ",
			hull_states.size(),
			" | Breaches ",
			breach_states.size()
		)


# =========================================================
# APPLY HULL
# =========================================================

func apply_hull_states(
	hull_states: Dictionary
):

	for hull_id_value in hull_states.keys():

		var state_value = (
			hull_states[
				hull_id_value
			]
		)


		if not (
			state_value is Dictionary
		):
			continue


		var hull_point = (
			find_hull_point(
				str(
					hull_id_value
				)
			)
		)


		if hull_point == null:
			continue


		if not hull_point.has_method(
			"apply_network_state"
		):
			continue


		hull_point.apply_network_state(
			state_value
		)


# =========================================================
# APPLY BREACH
# =========================================================

func apply_breach_states(
	breach_states: Dictionary
):

	for breach_id_value in breach_states.keys():

		var state_value = (
			breach_states[
				breach_id_value
			]
		)


		if not (
			state_value is Dictionary
		):
			continue


		var breach = (
			find_breach(
				str(
					breach_id_value
				)
			)
		)


		if breach == null:
			continue


		if not breach.has_method(
			"apply_network_state"
		):
			continue


		breach.apply_network_state(
			state_value
		)


# =========================================================
# FIND HULL
# =========================================================

func find_hull_point(
	hull_id: String
):

	var hull_points: Array = (
		get_tree().get_nodes_in_group(
			"network_hull_point"
		)
	)


	for hull_point in hull_points:

		if hull_point == null:
			continue


		if not is_instance_valid(
			hull_point
		):
			continue


		if not hull_point.has_method(
			"get_network_hull_id"
		):
			continue


		if str(
			hull_point.get_network_hull_id()
		) == hull_id:

			return hull_point


	return null


# =========================================================
# FIND BREACH
# =========================================================

func find_breach(
	breach_id: String
):

	var breaches: Array = (
		get_tree().get_nodes_in_group(
			"network_hull_breach"
		)
	)


	for breach in breaches:

		if breach == null:
			continue


		if not is_instance_valid(
			breach
		):
			continue


		if not breach.has_method(
			"get_network_breach_id"
		):
			continue


		if str(
			breach.get_network_breach_id()
		) == breach_id:

			return breach


	return null


# =========================================================
# REQUEST START REPAIR
# =========================================================

func request_start_repair(
	breach: Node,
	declared_has_fuel: bool
) -> bool:

	if not NetworkManager.is_online():
		return false


	if breach == null:
		return false


	if not is_instance_valid(
		breach
	):
		return false


	if not breach.has_method(
		"get_network_breach_id"
	):
		return false


	var breach_id: String = str(
		breach.get_network_breach_id()
	)


	if breach_id.is_empty():
		return false


	if NetworkManager.is_host():

		return handle_start_repair_request(
			1,
			breach_id,
			declared_has_fuel
		)


	if NetworkManager.is_client():

		request_start_repair_from_host.rpc_id(
			1,
			breach_id,
			declared_has_fuel
		)


		return true


	return false


# =========================================================
# CLIENT -> HOST START
# =========================================================

@rpc(
	"any_peer",
	"call_remote",
	"reliable"
)
func request_start_repair_from_host(
	breach_id: String,
	declared_has_fuel: bool
):

	if not NetworkManager.is_host():
		return


	var peer_id: int = (
		multiplayer.get_remote_sender_id()
	)


	handle_start_repair_request(
		peer_id,
		breach_id,
		declared_has_fuel
	)


# =========================================================
# HOST START REPAIR
# =========================================================

func handle_start_repair_request(
	peer_id: int,
	breach_id: String,
	declared_has_fuel: bool
) -> bool:

	if not NetworkManager.is_host():
		return false


	var breach = (
		find_breach(
			breach_id
		)
	)


	if breach == null:

		reject_repair(
			peer_id,
			breach_id,
			"Breach not found"
		)

		return false


	var rejection_reason: String = (
		get_repair_rejection_reason(
			peer_id,
			breach,
			declared_has_fuel
		)
	)


	if not rejection_reason.is_empty():

		reject_repair(
			peer_id,
			breach_id,
			rejection_reason
		)

		return false


	if repair_sessions.has(
		peer_id
	):

		var existing: Dictionary = (
			repair_sessions[
				peer_id
			]
		)


		if str(
			existing.get(
				"breach_id",
				""
			)
		) == breach_id:

			return true


		stop_repair_session(
			peer_id,
			true
		)


	repair_sessions[
		peer_id
	] = {
		"breach_id": breach_id
	}


	active_repair_peer_by_breach[
		breach_id
	] = peer_id


	if print_hull_events:

		print(
			"[NET HULL][REPAIR START] Peer ",
			peer_id,
			" | ",
			breach_id
		)


	return true


# =========================================================
# VALIDACIÓN REPAIR
# =========================================================

func get_repair_rejection_reason(
	peer_id: int,
	breach: Node,
	declared_has_fuel: bool
) -> String:

	if breach == null:
		return "Invalid breach"


	if not breach.has_method(
		"is_repaired"
	):
		return "Missing breach API"


	if breach.is_repaired():
		return "Already repaired"


	var breach_id: String = str(
		breach.get_network_breach_id()
	)


	if active_repair_peer_by_breach.has(
		breach_id
	):

		var active_peer: int = int(
			active_repair_peer_by_breach[
				breach_id
			]
		)


		if active_peer != peer_id:
			return "Breach already being repaired"


	if network_interaction_manager == null:
		return "NetworkInteractionManager missing"


	if not network_interaction_manager.has_method(
		"get_player_position"
	):
		return "Player position API missing"


	if not network_interaction_manager.has_method(
		"get_player_tool_id"
	):
		return "Player tool API missing"


	var position_state: Dictionary = (
		network_interaction_manager.get_player_position(
			peer_id
		)
	)


	if not bool(
		position_state.get(
			"valid",
			false
		)
	):
		return "Invalid player position"


	var player_position: Vector2 = (
		position_state.get(
			"position",
			Vector2.ZERO
		)
	)


	var repair_distance: float = 110.0


	if breach.has_method(
		"get_network_repair_distance"
	):

		repair_distance = float(
			breach.get_network_repair_distance()
		)


	if player_position.distance_to(
		breach.global_position
	) > repair_distance:

		return "Player too far"


	var tool_id: String = str(
		network_interaction_manager.get_player_tool_id(
			peer_id
		)
	)


	if tool_id.is_empty():
		return "No equipped tool"


	var required_repair_type: String = str(
		breach.get(
			"required_repair_type"
		)
	)


	var tool_repair_type: String = str(
		ItemDB.get_property(
			tool_id,
			"repair_type",
			""
		)
	)


	if (
		tool_repair_type
		!= required_repair_type
	):

		return "Wrong repair tool"


	var fuel_item_id: String = str(
		ItemDB.get_property(
			tool_id,
			"required_fuel_item",
			""
		)
	)


	if fuel_item_id.is_empty():
		return ""


	# -----------------------------------------------------
	# HOST LOCAL:
	# el inventario local sí puede validarse directamente.
	# -----------------------------------------------------

	if peer_id == 1:

		var inventory = (
			get_local_inventory()
		)


		if inventory == null:
			return "Host inventory missing"


		if not inventory.has_item(
			fuel_item_id,
			1
		):
			return "Missing repair fuel"


		return ""


	# -----------------------------------------------------
	# CLIENT REMOTO:
	# todavía no existe Inventory Authority global.
	#
	# El Client declara disponibilidad aquí y el Host exige
	# confirmación de consumo antes de cerrar la reparación.
	# -----------------------------------------------------

	if not declared_has_fuel:
		return "Client reports missing repair fuel"


	return ""


# =========================================================
# REQUEST STOP
# =========================================================

func request_stop_repair(
	breach: Node
):

	if not NetworkManager.is_online():
		return


	if breach == null:
		return


	if not is_instance_valid(
		breach
	):
		return


	if not breach.has_method(
		"get_network_breach_id"
	):
		return


	var breach_id: String = str(
		breach.get_network_breach_id()
	)


	if NetworkManager.is_host():

		handle_stop_repair_request(
			1,
			breach_id
		)

		return


	if NetworkManager.is_client():

		request_stop_repair_from_host.rpc_id(
			1,
			breach_id
		)


# =========================================================
# CLIENT -> HOST STOP
# =========================================================

@rpc(
	"any_peer",
	"call_remote",
	"reliable"
)
func request_stop_repair_from_host(
	breach_id: String
):

	if not NetworkManager.is_host():
		return


	var peer_id: int = (
		multiplayer.get_remote_sender_id()
	)


	handle_stop_repair_request(
		peer_id,
		breach_id
	)


# =========================================================
# HOST STOP
# =========================================================

func handle_stop_repair_request(
	peer_id: int,
	breach_id: String
):

	if not repair_sessions.has(
		peer_id
	):
		return


	var session: Dictionary = (
		repair_sessions[
			peer_id
		]
	)


	if str(
		session.get(
			"breach_id",
			""
		)
	) != breach_id:

		return


	stop_repair_session(
		peer_id,
		true
	)


# =========================================================
# PROCESS REPAIR SESSIONS
# =========================================================

func process_repair_sessions(
	delta: float
):

	for peer_id_value in repair_sessions.keys():

		var peer_id: int = int(
			peer_id_value
		)


		if not repair_sessions.has(
			peer_id
		):
			continue


		var session: Dictionary = (
			repair_sessions[
				peer_id
			]
		)


		var breach_id: String = str(
			session.get(
				"breach_id",
				""
			)
		)


		var breach = (
			find_breach(
				breach_id
			)
		)


		if breach == null:

			stop_repair_session(
				peer_id,
				false
			)

			continue


		# -------------------------------------------------
		# Revalidamos distancia y herramienta continuamente.
		#
		# Para un Client remoto no volvemos a confiar en
		# inventario aquí; el fuel se confirma al completar.
		# -------------------------------------------------

		var rejection_reason: String = (
			get_repair_rejection_reason(
				peer_id,
				breach,
				true
			)
		)


		if not rejection_reason.is_empty():

			cancel_repair_from_host(
				peer_id,
				breach_id,
				rejection_reason
			)

			continue


		if not breach.has_method(
			"advance_network_repair"
		):

			cancel_repair_from_host(
				peer_id,
				breach_id,
				"Missing repair progression API"
			)

			continue


		var completed: bool = bool(
			breach.advance_network_repair(
				delta
			)
		)


		if completed:

			begin_repair_completion(
				peer_id,
				breach
			)


# =========================================================
# BEGIN COMPLETION
# =========================================================

func begin_repair_completion(
	peer_id: int,
	breach: Node
):

	if breach == null:
		return


	var breach_id: String = str(
		breach.get_network_breach_id()
	)


	var tool_id: String = ""


	if network_interaction_manager != null:

		tool_id = str(
			network_interaction_manager.get_player_tool_id(
				peer_id
			)
		)


	var fuel_item_id: String = str(
		ItemDB.get_property(
			tool_id,
			"required_fuel_item",
			""
		)
	)


	erase_repair_session(
		peer_id,
		breach_id
	)


	# -----------------------------------------------------
	# SIN FUEL REQUERIDO
	# -----------------------------------------------------

	if fuel_item_id.is_empty():

		complete_repair_authoritative(
			peer_id,
			breach
		)

		return


	# -----------------------------------------------------
	# HOST LOCAL
	# -----------------------------------------------------

	if peer_id == 1:

		var inventory = (
			get_local_inventory()
		)


		if inventory == null:

			breach.reset_network_repair_progress()

			return


		var consumed: bool = (
			inventory.remove_item(
				fuel_item_id,
				1
			)
		)


		if not consumed:

			breach.reset_network_repair_progress()


			if print_hull_events:

				print(
					"[NET HULL][REPAIR CANCEL] Peer 1 | Fuel consumption failed"
				)


			return


		complete_repair_authoritative(
			peer_id,
			breach
		)

		return


	# -----------------------------------------------------
	# CLIENT REMOTO:
	# pedimos consumo y esperamos confirmación.
	# -----------------------------------------------------

	pending_fuel_confirmation[
		peer_id
	] = {
		"breach_id": breach_id,
		"fuel_item_id": fuel_item_id,
		"timer": 0.0
	}


	request_repair_fuel_consumption.rpc_id(
		peer_id,
		breach_id,
		fuel_item_id
	)


# =========================================================
# HOST -> CLIENT CONSUME FUEL
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func request_repair_fuel_consumption(
	breach_id: String,
	fuel_item_id: String
):

	if not NetworkManager.is_client():
		return


	var success: bool = true


	if not fuel_item_id.is_empty():

		var inventory = (
			get_local_inventory()
		)


		if inventory == null:

			success = false

		else:

			success = bool(
				inventory.remove_item(
					fuel_item_id,
					1
				)
			)


	confirm_repair_fuel_consumption.rpc_id(
		1,
		breach_id,
		success
	)


# =========================================================
# CLIENT -> HOST FUEL CONFIRMATION
# =========================================================

@rpc(
	"any_peer",
	"call_remote",
	"reliable"
)
func confirm_repair_fuel_consumption(
	breach_id: String,
	success: bool
):

	if not NetworkManager.is_host():
		return


	var peer_id: int = (
		multiplayer.get_remote_sender_id()
	)


	if not pending_fuel_confirmation.has(
		peer_id
	):
		return


	var pending: Dictionary = (
		pending_fuel_confirmation[
			peer_id
		]
	)


	if str(
		pending.get(
			"breach_id",
			""
		)
	) != breach_id:

		return


	pending_fuel_confirmation.erase(
		peer_id
	)


	var breach = (
		find_breach(
			breach_id
		)
	)


	if breach == null:
		return


	if not success:

		breach.reset_network_repair_progress()


		if print_hull_events:

			print(
				"[NET HULL][REPAIR CANCEL] Peer ",
				peer_id,
				" | Client fuel consumption failed"
			)


		notify_repair_cancelled.rpc_id(
			peer_id,
			breach_id
		)


		return


	complete_repair_authoritative(
		peer_id,
		breach
	)


# =========================================================
# PENDING FUEL TIMEOUT
# =========================================================

func process_pending_fuel_confirmations(
	delta: float
):

	for peer_id_value in pending_fuel_confirmation.keys():

		var peer_id: int = int(
			peer_id_value
		)


		var pending: Dictionary = (
			pending_fuel_confirmation[
				peer_id
			]
		)


		var timer: float = float(
			pending.get(
				"timer",
				0.0
			)
		)


		timer += delta


		pending[
			"timer"
		] = timer


		pending_fuel_confirmation[
			peer_id
		] = pending


		if timer < fuel_confirmation_timeout:
			continue


		var breach_id: String = str(
			pending.get(
				"breach_id",
				""
			)
		)


		var breach = (
			find_breach(
				breach_id
			)
		)


		if breach != null:

			if breach.has_method(
				"reset_network_repair_progress"
			):

				breach.reset_network_repair_progress()


		pending_fuel_confirmation.erase(
			peer_id
		)


		if print_hull_events:

			print(
				"[NET HULL][REPAIR CANCEL] Peer ",
				peer_id,
				" | Fuel confirmation timeout"
			)


		notify_repair_cancelled.rpc_id(
			peer_id,
			breach_id
		)


# =========================================================
# COMPLETE AUTHORITATIVE
# =========================================================

func complete_repair_authoritative(
	peer_id: int,
	breach: Node
):

	if breach == null:
		return


	if not breach.has_method(
		"finish_repair_authoritative"
	):
		return


	breach.finish_repair_authoritative()


	if print_hull_events:

		print(
			"[NET HULL][REPAIR COMPLETE] Peer ",
			peer_id,
			" | ",
			breach.get_network_breach_id()
		)


	# El sync periódico replicará:
	# - repaired
	# - progress
	# - HullIntegrity restaurada por el Host.


# =========================================================
# CANCEL / STOP
# =========================================================

func cancel_repair_from_host(
	peer_id: int,
	breach_id: String,
	reason: String
):

	stop_repair_session(
		peer_id,
		true
	)


	if print_hull_events:

		print(
			"[NET HULL][REPAIR CANCEL] Peer ",
			peer_id,
			" | ",
			reason
		)


	if peer_id == 1:

		var breach = (
			find_breach(
				breach_id
			)
		)


		if (
			breach != null
			and breach.has_method(
				"notify_network_repair_cancelled"
			)
		):

			breach.notify_network_repair_cancelled()


	else:

		notify_repair_cancelled.rpc_id(
			peer_id,
			breach_id
		)


func stop_repair_session(
	peer_id: int,
	reset_progress: bool
):

	if not repair_sessions.has(
		peer_id
	):
		return


	var session: Dictionary = (
		repair_sessions[
			peer_id
		]
	)


	var breach_id: String = str(
		session.get(
			"breach_id",
			""
		)
	)


	var breach = (
		find_breach(
			breach_id
		)
	)


	erase_repair_session(
		peer_id,
		breach_id
	)


	if (
		reset_progress
		and breach != null
		and breach.has_method(
			"reset_network_repair_progress"
		)
	):

		breach.reset_network_repair_progress()


func erase_repair_session(
	peer_id: int,
	breach_id: String
):

	repair_sessions.erase(
		peer_id
	)


	if active_repair_peer_by_breach.has(
		breach_id
	):

		if int(
			active_repair_peer_by_breach[
				breach_id
			]
		) == peer_id:

			active_repair_peer_by_breach.erase(
				breach_id
			)


# =========================================================
# REJECTION
# =========================================================

func reject_repair(
	peer_id: int,
	breach_id: String,
	reason: String
):

	if print_hull_events:

		print(
			"[NET HULL][REPAIR REJECT] Peer ",
			peer_id,
			" | ",
			reason
		)


	if peer_id == 1:

		var breach = (
			find_breach(
				breach_id
			)
		)


		if (
			breach != null
			and breach.has_method(
				"notify_network_repair_cancelled"
			)
		):

			breach.notify_network_repair_cancelled()


	else:

		notify_repair_cancelled.rpc_id(
			peer_id,
			breach_id
		)


# =========================================================
# HOST -> CLIENT CANCEL NOTIFICATION
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func notify_repair_cancelled(
	breach_id: String
):

	if not NetworkManager.is_client():
		return


	var breach = (
		find_breach(
			breach_id
		)
	)


	if breach == null:
		return


	if breach.has_method(
		"notify_network_repair_cancelled"
	):

		breach.notify_network_repair_cancelled()


# =========================================================
# LOCAL INVENTORY
# =========================================================

func get_local_inventory():

	if local_player == null:
		return null


	if not is_instance_valid(
		local_player
	):
		return null


	return local_player.get_node_or_null(
		"Inventory"
	)


# =========================================================
# NEW PEER
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
		"send_hull_snapshot_to_peer",
		peer_id
	)


# =========================================================
# DISCONNECTED
# =========================================================

func _on_player_disconnected(
	peer_id: int
):

	if repair_sessions.has(
		peer_id
	):

		stop_repair_session(
			peer_id,
			true
		)


	if pending_fuel_confirmation.has(
		peer_id
	):

		var pending: Dictionary = (
			pending_fuel_confirmation[
				peer_id
			]
		)


		var breach_id: String = str(
			pending.get(
				"breach_id",
				""
			)
		)


		var breach = (
			find_breach(
				breach_id
			)
		)


		if (
			breach != null
			and breach.has_method(
				"reset_network_repair_progress"
			)
		):

			breach.reset_network_repair_progress()


		pending_fuel_confirmation.erase(
			peer_id
		)


# =========================================================
# LATE JOIN SNAPSHOT
# =========================================================

func send_hull_snapshot_to_peer(
	peer_id: int
):

	await get_tree().process_frame

	await get_tree().process_frame


	if NetworkManager.is_restart_in_progress():
		return


	if not NetworkManager.is_online():
		return


	if not NetworkManager.is_host():
		return


	var hull_states: Dictionary = (
		build_hull_state_dictionary()
	)


	var breach_states: Dictionary = (
		build_breach_state_dictionary()
	)


	receive_hull_snapshot.rpc_id(
		peer_id,
		hull_states,
		breach_states
	)


	if print_hull_events:

		print(
			"[NET HULL] Snapshot sent | Peer ",
			peer_id,
			" | Hulls ",
			hull_states.size(),
			" | Breaches ",
			breach_states.size()
		)
