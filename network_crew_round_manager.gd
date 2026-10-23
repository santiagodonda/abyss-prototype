extends Node


# =========================================================
# SIGNALS
# =========================================================

signal crew_state_changed(
	old_state: String,
	new_state: String
)

signal round_state_changed(
	old_state: String,
	new_state: String,
	reason: String
)

signal crew_counts_changed(
	alive_count: int,
	unconscious_count: int,
	dead_count: int,
	total_count: int
)


# =========================================================
# CONSTANTES
# =========================================================

const LIFE_ALIVE: String = "ALIVE"
const LIFE_UNCONSCIOUS: String = "UNCONSCIOUS"
const LIFE_DEAD: String = "DEAD"

const CREW_OPERATIONAL: String = "OPERATIONAL"
const CREW_RECOVERABLE: String = "RECOVERABLE"
const CREW_LOST: String = "LOST"

const ROUND_RUNNING: String = "RUNNING"
const ROUND_FAILED: String = "FAILED"


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("Synchronization")

@export var sync_interval: float = 0.10


@export_group("Debug")

@export var print_state_changes: bool = true

@export var print_snapshots: bool = true


# =========================================================
# REFERENCIAS
# =========================================================

var health_manager = null

var local_health = null


# =========================================================
# ESTADO
# =========================================================

var crew_state: String = CREW_OPERATIONAL

var round_state: String = ROUND_RUNNING

var failure_reason: String = ""


var alive_count: int = 0

var unconscious_count: int = 0

var dead_count: int = 0

var total_count: int = 0


# Una ronda fallida no vuelve mágicamente a RUNNING
# porque alguien se conecte después.
var round_failed_latched: bool = false


var sync_accumulator: float = 0.0


# =========================================================
# READY
# =========================================================

func _ready():

	add_to_group(
		"network_crew_round_manager"
	)


	process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)


	resolve_references()


	NetworkManager.player_connected.connect(
		_on_player_connected
	)


	NetworkManager.player_disconnected.connect(
		_on_player_disconnected
	)


	NetworkManager.network_state_changed.connect(
		_on_network_state_changed
	)


	NetworkManager.network_restart_started.connect(
		_on_network_restart_started
	)


	call_deferred(
		"_initialize_state"
	)


	print(
		"[NET CREW] Manager ready"
	)


# =========================================================
# RESOLVER REFERENCIAS
# =========================================================

func resolve_references():

	var scene = (
		get_tree().current_scene
	)


	if scene != null:

		health_manager = (
			scene.get_node_or_null(
				"NetworkPlayerHealthManager"
			)
		)


		local_health = (
			scene.get_node_or_null(
				"Player/Health"
			)
		)


	if health_manager == null:

		var managers: Array = (
			get_tree().get_nodes_in_group(
				"network_player_health_manager"
			)
		)


		if not managers.is_empty():

			health_manager = (
				managers[0]
			)


# =========================================================
# INITIALIZE
# =========================================================

func _initialize_state():

	await get_tree().process_frame

	await get_tree().process_frame


	if NetworkManager.is_restart_in_progress():
		return


	refresh_authoritative_state()


# =========================================================
# PROCESS
# =========================================================

func _process(
	delta: float
):

	if NetworkManager.is_restart_in_progress():
		return


	# -----------------------------------------------------
	# OFFLINE
	# -----------------------------------------------------

	if not NetworkManager.is_online():

		refresh_offline_state()

		return


	# -----------------------------------------------------
	# CLIENT
	#
	# El Client nunca calcula el resultado de la ronda.
	# Espera estado autoritativo del Host.
	# -----------------------------------------------------

	if not NetworkManager.is_host():
		return


	# -----------------------------------------------------
	# HOST
	# -----------------------------------------------------

	refresh_host_state()


	sync_accumulator += delta


	if sync_accumulator < sync_interval:
		return


	sync_accumulator = 0.0


	broadcast_state_unreliable()


# =========================================================
# REFRESH AUTORITATIVO
# =========================================================

func refresh_authoritative_state():

	if NetworkManager.is_restart_in_progress():
		return


	if not NetworkManager.is_online():

		refresh_offline_state()

		return


	if NetworkManager.is_host():

		refresh_host_state()


# =========================================================
# HOST STATE
# =========================================================

func refresh_host_state():

	if not NetworkManager.is_host():
		return


	if health_manager == null:

		resolve_references()


	if health_manager == null:
		return


	if health_manager.has_method(
		"ensure_all_host_states"
	):

		health_manager.ensure_all_host_states()


	var peer_ids: Array = (
		NetworkManager.get_connected_peer_ids()
	)


	if peer_ids.is_empty():
		return


	var new_alive: int = 0

	var new_unconscious: int = 0

	var new_dead: int = 0

	var new_total: int = 0


	for peer_key in peer_ids:

		var peer_id: int = int(
			peer_key
		)


		var state: Dictionary = (
			get_health_state(
				peer_id
			)
		)


		# -------------------------------------------------
		# No tratamos un estado todavía inexistente como
		# ALIVE. Evita falsos positivos durante conexión.
		# -------------------------------------------------

		if state.is_empty():
			continue


		var life_state: String = str(
			state.get(
				"life_state",
				""
			)
		)


		match life_state:

			LIFE_ALIVE:

				new_alive += 1

				new_total += 1


			LIFE_UNCONSCIOUS:

				new_unconscious += 1

				new_total += 1


			LIFE_DEAD:

				new_dead += 1

				new_total += 1


	if new_total <= 0:
		return


	apply_authoritative_counts(
		new_alive,
		new_unconscious,
		new_dead,
		new_total
	)


# =========================================================
# OFFLINE STATE
# =========================================================

func refresh_offline_state():

	if local_health == null:

		resolve_references()


	if local_health == null:
		return


	if not is_instance_valid(
		local_health
	):
		return


	if not local_health.has_method(
		"get_state_name"
	):

		return


	var life_state: String = str(
		local_health.get_state_name()
	)


	var new_alive: int = 0

	var new_unconscious: int = 0

	var new_dead: int = 0


	match life_state:

		LIFE_ALIVE:

			new_alive = 1


		LIFE_UNCONSCIOUS:

			new_unconscious = 1


		LIFE_DEAD:

			new_dead = 1


		_:

			return


	apply_authoritative_counts(
		new_alive,
		new_unconscious,
		new_dead,
		1
	)


# =========================================================
# HEALTH STATE
# =========================================================

func get_health_state(
	peer_id: int
) -> Dictionary:

	if health_manager == null:
		return {}


	if not health_manager.has_method(
		"get_peer_state"
	):

		return {}


	var state_value = (
		health_manager.get_peer_state(
			peer_id
		)
	)


	if not (
		state_value
		is Dictionary
	):

		return {}


	return (
		state_value
	)


# =========================================================
# APPLY COUNTS
# =========================================================

func apply_authoritative_counts(
	new_alive: int,
	new_unconscious: int,
	new_dead: int,
	new_total: int
):

	var counts_changed: bool = (
		alive_count != new_alive
		or unconscious_count != new_unconscious
		or dead_count != new_dead
		or total_count != new_total
	)


	alive_count = new_alive

	unconscious_count = new_unconscious

	dead_count = new_dead

	total_count = new_total


	# -----------------------------------------------------
	# Una ronda ya fallida queda fallida.
	# -----------------------------------------------------

	if round_failed_latched:

		apply_state_values(
			CREW_LOST,
			ROUND_FAILED,
			failure_reason,
			counts_changed
		)

		return


	# -----------------------------------------------------
	# HAY AL MENOS UN JUGADOR OPERATIVO
	# -----------------------------------------------------

	if alive_count > 0:

		apply_state_values(
			CREW_OPERATIONAL,
			ROUND_RUNNING,
			"",
			counts_changed
		)

		return


	# -----------------------------------------------------
	# NADIE OPERATIVO, PERO TODAVÍA HAY REVIVIBLES
	# -----------------------------------------------------

	if unconscious_count > 0:

		apply_state_values(
			CREW_RECOVERABLE,
			ROUND_RUNNING,
			"",
			counts_changed
		)

		return


	# -----------------------------------------------------
	# TODOS DEAD
	# -----------------------------------------------------

	if (
		total_count > 0
		and dead_count == total_count
	):

		round_failed_latched = true


		apply_state_values(
			CREW_LOST,
			ROUND_FAILED,
			"ALL CREW DEAD",
			counts_changed
		)


# =========================================================
# APPLY STATE
# =========================================================

func apply_state_values(
	new_crew_state: String,
	new_round_state: String,
	new_failure_reason: String,
	counts_changed: bool
):

	var old_crew_state: String = (
		crew_state
	)


	var old_round_state: String = (
		round_state
	)


	var old_failure_reason: String = (
		failure_reason
	)


	crew_state = new_crew_state

	round_state = new_round_state

	failure_reason = new_failure_reason


	var state_changed: bool = (
		old_crew_state != crew_state
		or old_round_state != round_state
		or old_failure_reason != failure_reason
	)


	if counts_changed:

		crew_counts_changed.emit(
			alive_count,
			unconscious_count,
			dead_count,
			total_count
		)


	if old_crew_state != crew_state:

		crew_state_changed.emit(
			old_crew_state,
			crew_state
		)


	if old_round_state != round_state:

		round_state_changed.emit(
			old_round_state,
			round_state,
			failure_reason
		)


	if (
		print_state_changes
		and (
			state_changed
			or counts_changed
		)
	):

		print(
			"[NET CREW][AUTH] Crew=",
			crew_state,
			" | Round=",
			round_state,
			" | A=",
			alive_count,
			" U=",
			unconscious_count,
			" D=",
			dead_count,
			" T=",
			total_count,
			(
				" | "
				+ failure_reason
				if not failure_reason.is_empty()
				else ""
			)
		)


	if (
		NetworkManager.is_online()
		and NetworkManager.is_host()
		and (
			state_changed
			or counts_changed
		)
	):

		broadcast_state_reliable()


# =========================================================
# BUILD NETWORK STATE
# =========================================================

func build_network_state() -> Dictionary:

	return {
		"crew_state":
			crew_state,

		"round_state":
			round_state,

		"failure_reason":
			failure_reason,

		"alive_count":
			alive_count,

		"unconscious_count":
			unconscious_count,

		"dead_count":
			dead_count,

		"total_count":
			total_count,

		"round_failed_latched":
			round_failed_latched
	}


# =========================================================
# RELIABLE BROADCAST
# =========================================================

func broadcast_state_reliable():

	if not NetworkManager.is_online():
		return


	if not NetworkManager.is_host():
		return


	receive_crew_round_state_reliable.rpc(
		build_network_state()
	)


@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func receive_crew_round_state_reliable(
	state: Dictionary
):

	if NetworkManager.is_restart_in_progress():
		return


	if NetworkManager.is_host():
		return


	apply_network_state(
		state
	)


# =========================================================
# UNRELIABLE BROADCAST
# =========================================================

func broadcast_state_unreliable():

	if not NetworkManager.is_online():
		return


	if not NetworkManager.is_host():
		return


	receive_crew_round_state_unreliable.rpc(
		build_network_state()
	)


@rpc(
	"authority",
	"call_remote",
	"unreliable"
)
func receive_crew_round_state_unreliable(
	state: Dictionary
):

	if NetworkManager.is_restart_in_progress():
		return


	if NetworkManager.is_host():
		return


	apply_network_state(
		state
	)


# =========================================================
# APPLY NETWORK STATE
# =========================================================

func apply_network_state(
	state: Dictionary
):

	var old_crew_state: String = (
		crew_state
	)


	var old_round_state: String = (
		round_state
	)


	var old_alive: int = alive_count

	var old_unconscious: int = unconscious_count

	var old_dead: int = dead_count

	var old_total: int = total_count


	crew_state = str(
		state.get(
			"crew_state",
			CREW_OPERATIONAL
		)
	)


	round_state = str(
		state.get(
			"round_state",
			ROUND_RUNNING
		)
	)


	failure_reason = str(
		state.get(
			"failure_reason",
			""
		)
	)


	alive_count = int(
		state.get(
			"alive_count",
			0
		)
	)


	unconscious_count = int(
		state.get(
			"unconscious_count",
			0
		)
	)


	dead_count = int(
		state.get(
			"dead_count",
			0
		)
	)


	total_count = int(
		state.get(
			"total_count",
			0
		)
	)


	round_failed_latched = bool(
		state.get(
			"round_failed_latched",
			false
		)
	)


	if old_crew_state != crew_state:

		crew_state_changed.emit(
			old_crew_state,
			crew_state
		)


	if old_round_state != round_state:

		round_state_changed.emit(
			old_round_state,
			round_state,
			failure_reason
		)


	if (
		old_alive != alive_count
		or old_unconscious
			!= unconscious_count
		or old_dead != dead_count
		or old_total != total_count
	):

		crew_counts_changed.emit(
			alive_count,
			unconscious_count,
			dead_count,
			total_count
		)


# =========================================================
# PLAYER CONNECTED
# =========================================================

func _on_player_connected(
	peer_id: int
):

	if NetworkManager.is_restart_in_progress():
		return


	if not NetworkManager.is_host():
		return


	call_deferred(
		"refresh_authoritative_state"
	)


	call_deferred(
		"send_snapshot",
		peer_id
	)


# =========================================================
# PLAYER DISCONNECTED
# =========================================================

func _on_player_disconnected(
	_peer_id: int
):

	if NetworkManager.is_restart_in_progress():
		return


	if not NetworkManager.is_host():
		return


	call_deferred(
		"refresh_authoritative_state"
	)


# =========================================================
# SNAPSHOT
# =========================================================

func send_snapshot(
	peer_id: int
):

	await get_tree().process_frame

	await get_tree().process_frame


	if NetworkManager.is_restart_in_progress():
		return


	if not NetworkManager.is_host():
		return


	refresh_host_state()


	receive_crew_round_snapshot.rpc_id(
		peer_id,
		build_network_state()
	)


	if print_snapshots:

		print(
			"[NET CREW] Snapshot sent | Peer ",
			peer_id,
			" | Crew ",
			crew_state,
			" | Round ",
			round_state
		)


@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func receive_crew_round_snapshot(
	state: Dictionary
):

	if NetworkManager.is_restart_in_progress():
		return


	if NetworkManager.is_host():
		return


	apply_network_state(
		state
	)


	if print_snapshots:

		print(
			"[NET CREW] Snapshot received | Crew ",
			crew_state,
			" | Round ",
			round_state
		)


# =========================================================
# NETWORK STATE
# =========================================================

func _on_network_state_changed(
	new_state: String
):

	if new_state == "OFFLINE":

		reset_state()

		call_deferred(
			"refresh_offline_state"
		)

		return


	call_deferred(
		"refresh_authoritative_state"
	)


# =========================================================
# RESTART
# =========================================================

func _on_network_restart_started():

	reset_state()


# =========================================================
# RESET
# =========================================================

func reset_state():

	crew_state = CREW_OPERATIONAL

	round_state = ROUND_RUNNING

	failure_reason = ""

	alive_count = 0

	unconscious_count = 0

	dead_count = 0

	total_count = 0

	round_failed_latched = false

	sync_accumulator = 0.0


# =========================================================
# RESET QA
# =========================================================

func reset_for_qa():

	if (
		NetworkManager.is_online()
		and not NetworkManager.is_host()
	):

		return


	reset_state()

	refresh_authoritative_state()


# =========================================================
# CONSULTAS
# =========================================================

func get_crew_state() -> String:

	return crew_state


func get_round_state() -> String:

	return round_state


func get_failure_reason() -> String:

	return failure_reason


func get_alive_count() -> int:

	return alive_count


func get_unconscious_count() -> int:

	return unconscious_count


func get_dead_count() -> int:

	return dead_count


func get_total_count() -> int:

	return total_count


func is_operational() -> bool:

	return (
		crew_state
		== CREW_OPERATIONAL
	)


func is_recoverable() -> bool:

	return (
		crew_state
		== CREW_RECOVERABLE
	)


func is_lost() -> bool:

	return (
		crew_state
		== CREW_LOST
	)


func is_round_running() -> bool:

	return (
		round_state
		== ROUND_RUNNING
	)


func is_round_failed() -> bool:

	return (
		round_state
		== ROUND_FAILED
	)
