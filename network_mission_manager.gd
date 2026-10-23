extends Node


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("Synchronization")

@export var backup_sync_interval: float = 0.50


@export_group("Debug")

@export var print_mission_events: bool = true

@export var print_snapshots: bool = true

@export var print_stale_rejections: bool = true


# =========================================================
# REFERENCIAS
# =========================================================

var mission_state = null

var mission_objective = null

var crew_round_manager = null


# =========================================================
# SYNC
# =========================================================

var backup_sync_accumulator: float = 0.0

var last_authoritative_signature: String = ""


# =========================================================
# REVISION AUTORITATIVA
#
# Cada cambio real del estado de misión recibe una revisión
# creciente.
#
# Un Client nunca puede aplicar una revisión anterior a la
# última que ya recibió.
# =========================================================

var authoritative_revision: int = 0

var last_received_revision: int = -1


# =========================================================
# READY
# =========================================================

func _ready():

	add_to_group(
		"network_mission_manager"
	)


	process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)


	resolve_references()


	NetworkManager.player_connected.connect(
		_on_player_connected
	)


	NetworkManager.network_state_changed.connect(
		_on_network_state_changed
	)


	NetworkManager.network_restart_started.connect(
		_on_network_restart_started
	)


	call_deferred(
		"_initialize_online_state"
	)


	print(
		"[NET MISSION] Manager ready"
	)


# =========================================================
# REFERENCES
# =========================================================

func resolve_references():

	var scene = (
		get_tree().current_scene
	)


	if scene == null:
		return


	mission_state = (
		scene.get_node_or_null(
			"MissionState"
		)
	)


	mission_objective = (
		scene.get_node_or_null(
			"MissionObjective"
		)
	)


	crew_round_manager = (
		scene.get_node_or_null(
			"NetworkCrewRoundManager"
		)
	)


	if crew_round_manager == null:

		var managers: Array = (
			get_tree().get_nodes_in_group(
				"network_crew_round_manager"
			)
		)


		if not managers.is_empty():

			crew_round_manager = (
				managers[0]
			)


# =========================================================
# INITIALIZE
# =========================================================

func _initialize_online_state():

	await get_tree().process_frame

	await get_tree().process_frame


	if NetworkManager.is_restart_in_progress():
		return


	resolve_references()


	if (
		NetworkManager.is_online()
		and NetworkManager.is_host()
	):

		last_authoritative_signature = ""


		ensure_authoritative_revision()


		broadcast_state_reliable()


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


	enforce_crew_failure()


	sync_if_changed()


	backup_sync_accumulator += delta


	if (
		backup_sync_accumulator
		< backup_sync_interval
	):

		return


	backup_sync_accumulator = 0.0


	broadcast_state_unreliable()


# =========================================================
# CREW FAILURE
# =========================================================

func enforce_crew_failure():

	if mission_state == null:
		return


	if crew_round_manager == null:
		return


	if not mission_state.is_running():
		return


	if not crew_round_manager.has_method(
		"is_round_failed"
	):

		return


	if not crew_round_manager.is_round_failed():
		return


	var reason: String = (
		"ALL CREW DEAD"
	)


	if crew_round_manager.has_method(
		"get_failure_reason"
	):

		var crew_reason: String = str(
			crew_round_manager.get_failure_reason()
		)


		if not crew_reason.is_empty():

			reason = crew_reason


	mission_state.fail_mission(
		reason
	)


# =========================================================
# BUILD STATE
# =========================================================

func build_network_state() -> Dictionary:

	var mission_name: String = "RUNNING"

	var failure_reason: String = ""

	var success_reason: String = ""

	var objective_stage: String = "IDLE"

	var encounter_started: bool = false


	if mission_state != null:

		mission_name = (
			mission_state.get_state_name()
		)


		failure_reason = (
			mission_state.get_failure_reason()
		)


		success_reason = (
			mission_state.get_success_reason()
		)


	if mission_objective != null:

		objective_stage = (
			mission_objective.get_stage_name()
		)


		encounter_started = bool(
			mission_objective.encounter_started
		)


	return {
		"revision":
			authoritative_revision,

		"mission_state":
			mission_name,

		"failure_reason":
			failure_reason,

		"success_reason":
			success_reason,

		"objective_stage":
			objective_stage,

		"encounter_started":
			encounter_started
	}


# =========================================================
# SIGNATURE
# =========================================================

func get_authoritative_signature() -> String:

	var mission_name: String = "RUNNING"

	var failure_reason: String = ""

	var success_reason: String = ""

	var objective_stage: String = "IDLE"

	var encounter_started: bool = false


	if mission_state != null:

		mission_name = (
			mission_state.get_state_name()
		)


		failure_reason = (
			mission_state.get_failure_reason()
		)


		success_reason = (
			mission_state.get_success_reason()
		)


	if mission_objective != null:

		objective_stage = (
			mission_objective.get_stage_name()
		)


		encounter_started = bool(
			mission_objective.encounter_started
		)


	return (
		mission_name
		+ "|"
		+ failure_reason
		+ "|"
		+ success_reason
		+ "|"
		+ objective_stage
		+ "|"
		+ str(
			encounter_started
		)
	)


# =========================================================
# ASEGURAR REVISION ACTUAL
# =========================================================

func ensure_authoritative_revision() -> bool:

	if not NetworkManager.is_host():
		return false


	var signature: String = (
		get_authoritative_signature()
	)


	if signature == last_authoritative_signature:

		return false


	last_authoritative_signature = (
		signature
	)


	authoritative_revision += 1


	if print_mission_events:

		var state: Dictionary = (
			build_network_state()
		)


		print(
			"[NET MISSION][HOST] Rev=",
			authoritative_revision,
			" | State=",
			state[
				"mission_state"
			],
			" | Objective=",
			state[
				"objective_stage"
			]
		)


	return true


# =========================================================
# SYNC ON CHANGE
# =========================================================

func sync_if_changed():

	if not NetworkManager.is_host():
		return


	var changed: bool = (
		ensure_authoritative_revision()
	)


	if not changed:
		return


	broadcast_state_reliable()


# =========================================================
# RELIABLE
# =========================================================

func broadcast_state_reliable():

	if not NetworkManager.is_online():
		return


	if not NetworkManager.is_host():
		return


	receive_mission_state_reliable.rpc(
		build_network_state()
	)


@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func receive_mission_state_reliable(
	state: Dictionary
):

	if NetworkManager.is_restart_in_progress():
		return


	if NetworkManager.is_host():
		return


	apply_network_state(
		state,
		false
	)


# =========================================================
# UNRELIABLE BACKUP
# =========================================================

func broadcast_state_unreliable():

	if not NetworkManager.is_online():
		return


	if not NetworkManager.is_host():
		return


	receive_mission_state_unreliable.rpc(
		build_network_state()
	)


@rpc(
	"authority",
	"call_remote",
	"unreliable"
)
func receive_mission_state_unreliable(
	state: Dictionary
):

	if NetworkManager.is_restart_in_progress():
		return


	if NetworkManager.is_host():
		return


	apply_network_state(
		state,
		false
	)


# =========================================================
# APPLY CLIENT SHADOW
# =========================================================

func apply_network_state(
	state: Dictionary,
	allow_same_revision: bool = false
) -> bool:

	if NetworkManager.is_host():
		return false


	var incoming_revision: int = int(
		state.get(
			"revision",
			-1
		)
	)


	if incoming_revision < 0:

		return false


	# -----------------------------------------------------
	# PAQUETE ANTIGUO
	#
	# Nunca permitimos que un paquete con una revisión
	# anterior revierta un estado más nuevo.
	# -----------------------------------------------------

	if incoming_revision < last_received_revision:

		if print_stale_rejections:

			print(
				"[NET MISSION][DROP STALE] Incoming=",
				incoming_revision,
				" | Last=",
				last_received_revision
			)


		return false


	# -----------------------------------------------------
	# DUPLICADO DE LA MISMA REVISION
	#
	# Los backups periódicos se ignoran normalmente.
	#
	# Un snapshot explícito sí puede reaplicar la misma
	# revisión. Esto permite recuperar un Client cuyo estado
	# local haya quedado corrupto.
	# -----------------------------------------------------

	if (
		incoming_revision
		== last_received_revision
		and not allow_same_revision
	):

		return false


	if mission_state == null:

		resolve_references()


	if mission_objective == null:

		resolve_references()


	if mission_state == null:
		return false


	if mission_objective == null:
		return false


	last_received_revision = (
		incoming_revision
	)


	mission_state.apply_network_state(
		str(
			state.get(
				"mission_state",
				"RUNNING"
			)
		),
		str(
			state.get(
				"failure_reason",
				""
			)
		),
		str(
			state.get(
				"success_reason",
				""
			)
		)
	)


	mission_objective.apply_network_stage(
		str(
			state.get(
				"objective_stage",
				"IDLE"
			)
		),
		bool(
			state.get(
				"encounter_started",
				false
			)
		)
	)


	if print_mission_events:

		print(
			"[NET MISSION][CLIENT] Rev=",
			last_received_revision,
			" | State=",
			state.get(
				"mission_state",
				"?"
			),
			" | Objective=",
			state.get(
				"objective_stage",
				"?"
			)
		)


	return true


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
		"send_snapshot",
		peer_id
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


	ensure_authoritative_revision()


	var state: Dictionary = (
		build_network_state()
	)


	receive_mission_snapshot.rpc_id(
		peer_id,
		state
	)


	if print_snapshots:

		print(
			"[NET MISSION] Snapshot sent | Peer ",
			peer_id,
			" | Rev ",
			authoritative_revision,
			" | State ",
			state.get(
				"mission_state",
				"?"
			),
			" | Objective ",
			state.get(
				"objective_stage",
				"?"
			)
		)


@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func receive_mission_snapshot(
	state: Dictionary
):

	if NetworkManager.is_restart_in_progress():
		return


	if NetworkManager.is_host():
		return


	var applied: bool = (
		apply_network_state(
			state,
			true
		)
	)


	if (
		print_snapshots
		and applied
	):

		print(
			"[NET MISSION] Snapshot received | Rev ",
			state.get(
				"revision",
				-1
			),
			" | State ",
			state.get(
				"mission_state",
				"?"
			),
			" | Objective ",
			state.get(
				"objective_stage",
				"?"
			)
		)


# =========================================================
# NETWORK STATE
# =========================================================

func _on_network_state_changed(
	new_state: String
):

	backup_sync_accumulator = 0.0


	if new_state == "OFFLINE":

		last_authoritative_signature = ""

		authoritative_revision = 0

		last_received_revision = -1

		return


	if new_state == "HOST":

		last_authoritative_signature = ""

		authoritative_revision = 0


		call_deferred(
			"_initialize_online_state"
		)

		return


	if new_state == "CONNECTING":

		last_received_revision = -1

		return


	if new_state == "CLIENT":

		call_deferred(
			"_initialize_online_state"
		)


# =========================================================
# RESTART
# =========================================================

func _on_network_restart_started():

	last_authoritative_signature = ""

	backup_sync_accumulator = 0.0

	authoritative_revision = 0

	last_received_revision = -1


# =========================================================
# RESTART POLICY
# =========================================================

func is_restart_allowed() -> bool:

	if mission_state == null:

		resolve_references()


	if mission_state == null:
		return false


	return (
		not mission_state.is_running()
	)


func can_client_request_restart(
	peer_id: int
) -> bool:

	if not NetworkManager.is_host():
		return false


	if peer_id <= 1:
		return false


	if not NetworkManager.get_connected_peer_ids().has(
		peer_id
	):

		return false


	return is_restart_allowed()


# =========================================================
# QA FORCE SYNC
# =========================================================

func force_sync_for_qa():

	if not NetworkManager.is_host():
		return


	ensure_authoritative_revision()


	broadcast_state_reliable()


# =========================================================
# CONSULTAS
# =========================================================

func get_mission_state_name() -> String:

	if mission_state == null:
		return "UNKNOWN"


	return (
		mission_state.get_state_name()
	)


func get_objective_stage_name() -> String:

	if mission_objective == null:
		return "UNKNOWN"


	return (
		mission_objective.get_stage_name()
	)


func get_authoritative_revision() -> int:

	return authoritative_revision


func get_last_received_revision() -> int:

	return last_received_revision
