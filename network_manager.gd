extends Node


signal network_state_changed(
	new_state: String
)

signal player_connected(
	peer_id: int
)

signal player_disconnected(
	peer_id: int
)

signal connection_succeeded

signal connection_failed

signal disconnected_from_server

signal network_restart_started

signal network_restart_finished


# =========================================================
# CONFIGURACIÓN
# =========================================================

const DEFAULT_PORT: int = 7777

const MAX_TOTAL_PLAYERS: int = 5


# =========================================================
# ESTADOS
# =========================================================

enum NetworkState {
	OFFLINE,
	HOST,
	CONNECTING,
	CLIENT
}


var current_state: NetworkState = (
	NetworkState.OFFLINE
)


# =========================================================
# PEER
# =========================================================

var current_peer: ENetMultiplayerPeer = null


# =========================================================
# JUGADORES CONECTADOS
# =========================================================

var connected_peers: Dictionary = {}


# =========================================================
# RESTART
# =========================================================

var network_restart_in_progress: bool = false


# =========================================================
# READY
# =========================================================

func _ready():

	process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)


	multiplayer.peer_connected.connect(
		_on_peer_connected
	)


	multiplayer.peer_disconnected.connect(
		_on_peer_disconnected
	)


	multiplayer.connected_to_server.connect(
		_on_connected_to_server
	)


	multiplayer.connection_failed.connect(
		_on_connection_failed
	)


	multiplayer.server_disconnected.connect(
		_on_server_disconnected
	)


	print(
		"[NET] NetworkManager ready | OFFLINE"
	)


# =========================================================
# HOST
# =========================================================

func host_game(
	port: int = DEFAULT_PORT
) -> bool:

	if current_state != NetworkState.OFFLINE:

		disconnect_from_game()


	var peer := ENetMultiplayerPeer.new()


	var maximum_clients: int = (
		MAX_TOTAL_PLAYERS - 1
	)


	var error: Error = (
		peer.create_server(
			port,
			maximum_clients
		)
	)


	if error != OK:

		print(
			"[NET][FAIL] Could not create HOST | Error: ",
			error
		)

		return false


	current_peer = peer


	multiplayer.multiplayer_peer = (
		current_peer
	)


	connected_peers.clear()


	connected_peers[1] = true


	network_restart_in_progress = false


	set_network_state(
		NetworkState.HOST
	)


	print(
		"[NET] HOST started | Port: ",
		port,
		" | Max total players: ",
		MAX_TOTAL_PLAYERS
	)


	print(
		"[NET] Local Peer ID: ",
		multiplayer.get_unique_id()
	)


	return true


# =========================================================
# JOIN
# =========================================================

func join_game(
	address: String,
	port: int = DEFAULT_PORT
) -> bool:

	if address.strip_edges().is_empty():

		address = (
			"127.0.0.1"
		)


	if current_state != NetworkState.OFFLINE:

		disconnect_from_game()


	var peer := ENetMultiplayerPeer.new()


	var error: Error = (
		peer.create_client(
			address,
			port
		)
	)


	if error != OK:

		print(
			"[NET][FAIL] Could not create CLIENT | Error: ",
			error
		)

		return false


	current_peer = peer


	multiplayer.multiplayer_peer = (
		current_peer
	)


	connected_peers.clear()


	network_restart_in_progress = false


	set_network_state(
		NetworkState.CONNECTING
	)


	print(
		"[NET] CLIENT connecting | ",
		address,
		":",
		port
	)


	return true


# =========================================================
# DESCONECTAR
# =========================================================

func disconnect_from_game():

	network_restart_in_progress = false


	if current_peer != null:

		current_peer.close()


	current_peer = null


	multiplayer.multiplayer_peer = (
		OfflineMultiplayerPeer.new()
	)


	connected_peers.clear()


	set_network_state(
		NetworkState.OFFLINE
	)


	print(
		"[NET] Disconnected | OFFLINE"
	)


# =========================================================
# PEER CONECTADO
# =========================================================

func _on_peer_connected(
	peer_id: int
):

	connected_peers[peer_id] = true


	print(
		"[NET] Peer connected | ID: ",
		peer_id,
		" | Total players: ",
		get_player_count()
	)


	player_connected.emit(
		peer_id
	)


# =========================================================
# PEER DESCONECTADO
# =========================================================

func _on_peer_disconnected(
	peer_id: int
):

	connected_peers.erase(
		peer_id
	)


	print(
		"[NET] Peer disconnected | ID: ",
		peer_id,
		" | Total players: ",
		get_player_count()
	)


	player_disconnected.emit(
		peer_id
	)


# =========================================================
# CLIENTE CONECTADO
# =========================================================

func _on_connected_to_server():

	set_network_state(
		NetworkState.CLIENT
	)


	var local_id: int = (
		multiplayer.get_unique_id()
	)


	connected_peers[1] = true

	connected_peers[local_id] = true


	print(
		"[NET] CLIENT connected successfully"
	)


	print(
		"[NET] Local Peer ID: ",
		local_id
	)


	print(
		"[NET] Server Peer ID: 1"
	)


	connection_succeeded.emit()


# =========================================================
# FALLA CONEXIÓN
# =========================================================

func _on_connection_failed():

	print(
		"[NET][FAIL] Connection failed"
	)


	connection_failed.emit()


	reset_to_offline()


# =========================================================
# SERVER DESCONECTADO
# =========================================================

func _on_server_disconnected():

	print(
		"[NET] Server disconnected"
	)


	disconnected_from_server.emit()


	reset_to_offline()


# =========================================================
# RESET OFFLINE
# =========================================================

func reset_to_offline():

	network_restart_in_progress = false


	if current_peer != null:

		current_peer.close()


	current_peer = null


	multiplayer.multiplayer_peer = (
		OfflineMultiplayerPeer.new()
	)


	connected_peers.clear()


	set_network_state(
		NetworkState.OFFLINE
	)


# =========================================================
# SOLICITAR RESTART DE PARTIDA
# =========================================================

func request_game_restart():

	if network_restart_in_progress:
		return


	# -----------------------------------------------------
	# OFFLINE
	# -----------------------------------------------------

	if not is_online():

		start_local_restart()

		return


	# -----------------------------------------------------
	# HOST
	# -----------------------------------------------------

	if is_host():

		start_network_restart()

		return


	# -----------------------------------------------------
	# CLIENT
	#
	# El Client sólo solicita.
	# La autorización real siempre pertenece al Host.
	# -----------------------------------------------------

	if is_client():

		print(
			"[NET RESTART] Client requested restart | ID: ",
			get_local_peer_id()
		)


		request_restart_from_host.rpc_id(
			1
		)


# =========================================================
# CLIENT -> HOST
# =========================================================

@rpc(
	"any_peer",
	"call_remote",
	"reliable"
)
func request_restart_from_host():

	if not multiplayer.is_server():
		return


	if network_restart_in_progress:
		return


	var requester_id: int = (
		multiplayer.get_remote_sender_id()
	)


	# -----------------------------------------------------
	# VALIDAR IDENTIDAD
	# -----------------------------------------------------

	if requester_id <= 1:

		print(
			"[NET RESTART][REJECT] Invalid requester | Peer ",
			requester_id
		)

		return


	if not connected_peers.has(
		requester_id
	):

		print(
			"[NET RESTART][REJECT] Unknown peer ",
			requester_id
		)

		return


	# -----------------------------------------------------
	# VALIDAR POLÍTICA DE RONDA
	#
	# Un Client no puede reiniciar una partida RUNNING.
	# NetworkMissionManager es la fuente para determinar
	# si SUCCESS / FAILED ya habilitó el restart.
	# -----------------------------------------------------

	if not can_peer_request_network_restart(
		requester_id
	):

		print(
			"[NET RESTART][REJECT] Peer ",
			requester_id,
			" | Mission still RUNNING or restart unavailable"
		)

		return


	print(
		"[NET RESTART][ACCEPT] Request received from peer ",
		requester_id
	)


	start_network_restart()


# =========================================================
# POLÍTICA DE RESTART PARA CLIENTS
# =========================================================

func can_peer_request_network_restart(
	peer_id: int
) -> bool:

	if not is_host():
		return false


	if peer_id <= 1:
		return false


	if not connected_peers.has(
		peer_id
	):

		return false


	var mission_manager = (
		get_network_mission_manager()
	)


	if mission_manager == null:
		return false


	if not mission_manager.has_method(
		"can_client_request_restart"
	):

		return false


	return bool(
		mission_manager.can_client_request_restart(
			peer_id
		)
	)


# =========================================================
# RESOLVER NETWORK MISSION MANAGER
# =========================================================

func get_network_mission_manager():

	var tree = (
		get_tree()
	)


	if tree == null:
		return null


	var managers: Array = (
		tree.get_nodes_in_group(
			"network_mission_manager"
		)
	)


	if managers.is_empty():
		return null


	var manager = (
		managers[0]
	)


	if not is_instance_valid(
		manager
	):

		return null


	return manager


# =========================================================
# HOST INICIA RESTART GLOBAL
# =========================================================

func start_network_restart():

	if network_restart_in_progress:
		return


	if not is_host():
		return


	network_restart_in_progress = true


	print(
		"[NET RESTART] HOST broadcasting restart"
	)


	network_restart_started.emit()


	# Clientes.
	execute_network_restart.rpc()


	# Host.
	execute_network_restart()


# =========================================================
# EJECUTAR RESTART EN TODOS
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func execute_network_restart():

	if not network_restart_in_progress:

		network_restart_in_progress = true


	network_restart_started.emit()


	print(
		"[NET RESTART] Reloading scene | Peer ID: ",
		get_local_peer_id()
	)


	call_deferred(
		"perform_scene_reload"
	)


# =========================================================
# RELOAD
# =========================================================

func perform_scene_reload():

	get_tree().paused = false


	var reload_error: Error = (
		get_tree().reload_current_scene()
	)


	if reload_error != OK:

		push_error(
			"NetworkManager: no se pudo reiniciar la escena. Error: "
			+ str(
				reload_error
			)
		)


		network_restart_in_progress = false

		return


	# Dejamos que la nueva escena entre al árbol
	# antes de reactivar sincronización.
	await get_tree().process_frame

	await get_tree().process_frame


	network_restart_in_progress = false


	print(
		"[NET RESTART] Scene ready | Peer ID: ",
		get_local_peer_id()
	)


	network_restart_finished.emit()


# =========================================================
# RESTART LOCAL OFFLINE
# =========================================================

func start_local_restart():

	if network_restart_in_progress:
		return


	network_restart_in_progress = true


	network_restart_started.emit()


	call_deferred(
		"perform_scene_reload"
	)


# =========================================================
# ESTADO
# =========================================================

func set_network_state(
	new_state: NetworkState
):

	if current_state == new_state:
		return


	current_state = new_state


	network_state_changed.emit(
		get_state_name()
	)


# =========================================================
# CONSULTAS
# =========================================================

func get_state_name() -> String:

	match current_state:

		NetworkState.OFFLINE:
			return "OFFLINE"

		NetworkState.HOST:
			return "HOST"

		NetworkState.CONNECTING:
			return "CONNECTING"

		NetworkState.CLIENT:
			return "CLIENT"


	return "UNKNOWN"


func is_online() -> bool:

	return (
		current_state
		== NetworkState.HOST
		or current_state
		== NetworkState.CLIENT
	)


func is_host() -> bool:

	return (
		current_state
		== NetworkState.HOST
	)


func is_client() -> bool:

	return (
		current_state
		== NetworkState.CLIENT
	)


func is_restart_in_progress() -> bool:

	return (
		network_restart_in_progress
	)


func get_local_peer_id() -> int:

	if not is_online():
		return 0


	if multiplayer == null:
		return 0


	return (
		multiplayer.get_unique_id()
	)


func get_player_count() -> int:

	return (
		connected_peers.size()
	)


func get_connected_peer_ids() -> Array:

	var result: Array = (
		connected_peers.keys()
	)


	result.sort()


	return result


func get_port() -> int:

	return DEFAULT_PORT
