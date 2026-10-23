extends Node


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("QA")

@export var start_on_run: bool = false

@export var network_timeout: float = 30.0

@export var stage_timeout: float = 4.0

@export var poll_interval: float = 0.05

@export var qa_revive_time: float = 0.75


@export_group("Positions")

@export var safe_host_position: Vector2 = Vector2(
	300.0,
	300.0
)

@export var near_offset: Vector2 = Vector2(
	45.0,
	0.0
)

@export var far_offset: Vector2 = Vector2(
	350.0,
	0.0
)


# =========================================================
# CONSTANTES
# =========================================================

const LIFE_ALIVE: String = "ALIVE"
const LIFE_UNCONSCIOUS: String = "UNCONSCIOUS"
const LIFE_DEAD: String = "DEAD"


# =========================================================
# REFERENCIAS
# =========================================================

var revive_manager = null

var health_manager = null

var player_manager = null

var local_player = null


# =========================================================
# QA
# =========================================================

var pass_count: int = 0

var fail_count: int = 0

var skip_count: int = 0

var test_running: bool = false

var test_finished: bool = false


# =========================================================
# NETWORK
# =========================================================

var remote_peer_id: int = 0


# =========================================================
# CONFIG ORIGINAL
# =========================================================

var original_revive_time: float = 5.0

var revive_time_saved: bool = false


# =========================================================
# CLIENT HEALTH REPORT
# =========================================================

var health_report_received: bool = false

var health_report_token: String = ""

var health_report_state: String = ""

var health_report_value: float = 0.0


# =========================================================
# READY
# =========================================================

func _ready():

	if start_on_run:

		call_deferred(
			"start_test"
		)


# =========================================================
# START
# =========================================================

func start_test():

	if test_running:
		return


	test_running = true

	test_finished = false


	reset_test_state()

	resolve_references()


	print("")
	print("[QA] ========================================")
	print("[QA] TEST: REVIVE NETWORK AUTHORITY")
	print("[QA] ========================================")


	if not validate_references():

		fail_step(
			1,
			"Required nodes",
			"Missing Revive / Health / Player references"
		)


		finish_failed()

		return


	pass_step(
		1,
		"Required nodes",
		"Revive authority references resolved"
	)


	if not NetworkManager.is_online():

		print(
			"[QA] Waiting for multiplayer..."
		)


	await wait_for_network()


	if test_finished:
		return


	if NetworkManager.is_client():

		print(
			"[QA] CLIENT ready | Peer ",
			multiplayer.get_unique_id()
		)

		return


	if not NetworkManager.is_host():

		fail_step(
			2,
			"Network role",
			"Instance is neither Host nor Client"
		)


		finish_failed()

		return


	await run_host_suite()


# =========================================================
# RESET TEST STATE
# =========================================================

func reset_test_state():

	pass_count = 0

	fail_count = 0

	skip_count = 0

	remote_peer_id = 0

	health_report_received = false

	health_report_token = ""

	health_report_state = ""

	health_report_value = 0.0

	revive_time_saved = false


# =========================================================
# REFERENCES
# =========================================================

func resolve_references():

	var scene = (
		get_tree().current_scene
	)


	if scene == null:
		return


	revive_manager = (
		scene.get_node_or_null(
			"NetworkReviveManager"
		)
	)


	health_manager = (
		scene.get_node_or_null(
			"NetworkPlayerHealthManager"
		)
	)


	player_manager = (
		scene.get_node_or_null(
			"NetworkPlayerManager"
		)
	)


	local_player = (
		scene.get_node_or_null(
			"Player"
		)
	)


	# -----------------------------------------------------
	# FALLBACK REVIVE
	# -----------------------------------------------------

	if revive_manager == null:

		var revive_nodes: Array = (
			get_tree().get_nodes_in_group(
				"network_revive_manager"
			)
		)


		if not revive_nodes.is_empty():

			revive_manager = (
				revive_nodes[0]
			)


	# -----------------------------------------------------
	# FALLBACK HEALTH
	# -----------------------------------------------------

	if health_manager == null:

		var health_nodes: Array = (
			get_tree().get_nodes_in_group(
				"network_player_health_manager"
			)
		)


		if not health_nodes.is_empty():

			health_manager = (
				health_nodes[0]
			)


# =========================================================
# VALIDATION
# =========================================================

func validate_references() -> bool:

	if revive_manager == null:
		return false


	if health_manager == null:
		return false


	if player_manager == null:
		return false


	if local_player == null:
		return false


	if not revive_manager.has_method(
		"request_revive_start"
	):
		return false


	if not revive_manager.has_method(
		"request_revive_stop"
	):
		return false


	if not health_manager.has_method(
		"force_unconscious_peer"
	):
		return false


	if not health_manager.has_method(
		"force_die_peer"
	):
		return false


	if not health_manager.has_method(
		"revive_peer"
	):
		return false


	if not health_manager.has_method(
		"get_peer_life_state"
	):
		return false


	if not health_manager.has_method(
		"get_peer_health"
	):
		return false


	if not player_manager.has_method(
		"get_remote_player"
	):
		return false


	return true


# =========================================================
# WAIT NETWORK
# =========================================================

func wait_for_network():

	var elapsed: float = 0.0


	while elapsed < network_timeout:

		if (
			NetworkManager.is_online()
			and (
				NetworkManager.is_host()
				or NetworkManager.is_client()
			)
		):

			if NetworkManager.is_client():

				pass_step(
					2,
					"Network ready",
					"CLIENT | Peer "
					+ str(
						multiplayer.get_unique_id()
					)
				)


				return


			if NetworkManager.is_host():

				var peers: PackedInt32Array = (
					multiplayer.get_peers()
				)


				if not peers.is_empty():

					remote_peer_id = int(
						peers[0]
					)


					pass_step(
						2,
						"Network ready",
						"HOST | Client "
						+ str(
							remote_peer_id
						)
					)


					return


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	fail_step(
		2,
		"Network ready",
		"Timed out waiting for Host + Client"
	)


	finish_failed()


# =========================================================
# HOST SUITE
# =========================================================

func run_host_suite():

	# -----------------------------------------------------
	# CONFIG QA
	# -----------------------------------------------------

	original_revive_time = float(
		revive_manager.revive_time
	)


	revive_time_saved = true


	revive_manager.revive_time = (
		qa_revive_time
	)


	print(
		"[QA] Revive time temporarily set to ",
		qa_revive_time,
		" s"
	)


	# -----------------------------------------------------
	# POSICIONES SEGURAS
	# -----------------------------------------------------

	local_player.global_position = (
		safe_host_position
	)


	local_player.velocity = Vector2.ZERO


	qa_client_set_position.rpc_id(
		remote_peer_id,
		safe_host_position
		+ near_offset
	)


	if not await wait_for_remote_position(
		safe_host_position
		+ near_offset,
		100.0
	):

		fail_step(
			3,
			"Initial positioning",
			"Host did not receive Client position"
		)


		finish_failed()

		return


	# -----------------------------------------------------
	# BASELINE
	# -----------------------------------------------------

	if (
		get_life_state(
			1
		)
		!= LIFE_ALIVE
		or get_life_state(
			remote_peer_id
		)
		!= LIFE_ALIVE
	):

		fail_step(
			3,
			"Baseline crew state",
			"Host and Client must begin ALIVE"
		)


		finish_failed()

		return


	pass_step(
		3,
		"Baseline crew state",
		"Host ALIVE | Client ALIVE | positions synchronized"
	)


	# =====================================================
	# STEP 04
	# HOST -> UNCONSCIOUS + CLIENT REPLICATION
	# =====================================================

	if not health_manager.force_unconscious_peer(
		1
	):

		fail_step(
			4,
			"Unconscious replication",
			"Could not force Host unconscious"
		)


		finish_failed()

		return


	if not await wait_for_life_state(
		1,
		LIFE_UNCONSCIOUS
	):

		fail_step(
			4,
			"Unconscious replication",
			"Host did not become UNCONSCIOUS"
		)


		finish_failed()

		return


	if not await client_expect_health(
		1,
		LIFE_UNCONSCIOUS,
		"HOST_UNCONSCIOUS"
	):

		fail_step(
			4,
			"Unconscious replication",
			"Client did not receive Host UNCONSCIOUS"
		)


		finish_failed()

		return


	pass_step(
		4,
		"Unconscious replication",
		"Host authority replicated UNCONSCIOUS to Client"
	)


	# =====================================================
	# STEP 05
	# START + RELEASE CANCEL
	# =====================================================

	qa_client_request_start.rpc_id(
		remote_peer_id,
		1
	)


	if not await wait_for_session_active(
		remote_peer_id,
		1
	):

		fail_step(
			5,
			"Release cancellation",
			"Host never created revive session"
		)


		finish_failed()

		return


	qa_client_request_stop.rpc_id(
		remote_peer_id,
		1
	)


	if not await wait_for_session_cleared(
		remote_peer_id
	):

		fail_step(
			5,
			"Release cancellation",
			"Revive session remained active after STOP"
		)


		finish_failed()

		return


	if get_life_state(
		1
	) != LIFE_UNCONSCIOUS:

		fail_step(
			5,
			"Release cancellation",
			"Target revived despite cancelled hold"
		)


		finish_failed()

		return


	pass_step(
		5,
		"Release cancellation",
		"START created once | STOP cancelled | target still UNCONSCIOUS"
	)


	# =====================================================
	# STEP 06
	# DISTANCE REJECTION
	# =====================================================

	var far_position: Vector2 = (
		safe_host_position
		+ far_offset
	)


	qa_client_set_position.rpc_id(
		remote_peer_id,
		far_position
	)


	if not await wait_for_remote_position(
		far_position,
		100.0
	):

		fail_step(
			6,
			"Distance validation",
			"Host did not receive far Client position"
		)


		finish_failed()

		return


	qa_client_request_start.rpc_id(
		remote_peer_id,
		1
	)


	await get_tree().create_timer(
		0.50
	).timeout


	if revive_manager.revive_sessions.has(
		remote_peer_id
	):

		fail_step(
			6,
			"Distance validation",
			"Host accepted revive while Client was too far"
		)


		finish_failed()

		return


	pass_step(
		6,
		"Distance validation",
		"Out-of-range revive rejected by Host"
	)


	# Volvemos cerca.

	qa_client_set_position.rpc_id(
		remote_peer_id,
		safe_host_position
		+ near_offset
	)


	if not await wait_for_remote_position(
		safe_host_position
		+ near_offset,
		100.0
	):

		fail_step(
			6,
			"Distance validation",
			"Client could not return to revive range"
		)


		finish_failed()

		return


	# =====================================================
	# STEP 07
	# UNCONSCIOUS RESCUER REJECTION
	# =====================================================

	if not health_manager.force_unconscious_peer(
		remote_peer_id
	):

		fail_step(
			7,
			"Rescuer state validation",
			"Could not force Client unconscious"
		)


		finish_failed()

		return


	if not await wait_for_life_state(
		remote_peer_id,
		LIFE_UNCONSCIOUS
	):

		fail_step(
			7,
			"Rescuer state validation",
			"Client authoritative state did not become UNCONSCIOUS"
		)


		finish_failed()

		return


	qa_client_request_start.rpc_id(
		remote_peer_id,
		1
	)


	await get_tree().create_timer(
		0.50
	).timeout


	if revive_manager.revive_sessions.has(
		remote_peer_id
	):

		fail_step(
			7,
			"Rescuer state validation",
			"UNCONSCIOUS rescuer was allowed to revive"
		)


		finish_failed()

		return


	pass_step(
		7,
		"Rescuer state validation",
		"UNCONSCIOUS rescuer rejected by Host"
	)


	# Restauramos Client para continuar.

	if not health_manager.revive_peer(
		remote_peer_id,
		1.0
	):

		fail_step(
			7,
			"Rescuer state validation",
			"Could not restore Client to ALIVE"
		)


		finish_failed()

		return


	if not await wait_for_life_state(
		remote_peer_id,
		LIFE_ALIVE
	):

		fail_step(
			7,
			"Rescuer state validation",
			"Client did not return ALIVE"
		)


		finish_failed()

		return


	# =====================================================
	# STEP 08
	# SELF REVIVE
	# =====================================================

	var self_result: bool = (
		revive_manager.request_revive_start(
			1
		)
	)


	if (
		self_result
		or revive_manager.revive_sessions.has(
			1
		)
	):

		fail_step(
			8,
			"Self revive rejection",
			"Host was able to start revive on itself"
		)


		finish_failed()

		return


	pass_step(
		8,
		"Self revive rejection",
		"Self-revive blocked before session creation"
	)


	# =====================================================
	# STEP 09
	# SUCCESSFUL REVIVE
	# =====================================================

	qa_client_request_start.rpc_id(
		remote_peer_id,
		1
	)


	if not await wait_for_session_active(
		remote_peer_id,
		1
	):

		fail_step(
			9,
			"Successful revive",
			"Valid revive session did not start"
		)


		finish_failed()

		return


	if not await wait_for_life_state(
		1,
		LIFE_ALIVE,
		qa_revive_time
		+ 2.0
	):

		fail_step(
			9,
			"Successful revive",
			"Host did not return to ALIVE"
		)


		finish_failed()

		return


	var revived_health: float = (
		health_manager.get_peer_health(
			1
		)
	)


	if revived_health <= 0.0:

		fail_step(
			9,
			"Successful revive",
			"Revived Host has no health"
		)


		finish_failed()

		return


	if revived_health > 25.5:

		fail_step(
			9,
			"Successful revive",
			"Revived health exceeded expected 25%"
		)


		finish_failed()

		return


	if not await client_expect_health(
		1,
		LIFE_ALIVE,
		"HOST_REVIVED"
	):

		fail_step(
			9,
			"Successful revive",
			"Client did not receive ALIVE after revive"
		)


		finish_failed()

		return


	pass_step(
		9,
		"Successful revive",
		"Host ALIVE | HP "
		+ str(
			snapped(
				revived_health,
				0.1
			)
		)
		+ " | Client synchronized"
	)


	# =====================================================
	# STEP 10
	# DISCONNECT CLEANUP LOGIC
	# =====================================================

	if not health_manager.force_unconscious_peer(
		1
	):

		fail_step(
			10,
			"Disconnect cleanup",
			"Could not prepare unconscious target"
		)


		finish_failed()

		return


	qa_client_request_start.rpc_id(
		remote_peer_id,
		1
	)


	if not await wait_for_session_active(
		remote_peer_id,
		1
	):

		fail_step(
			10,
			"Disconnect cleanup",
			"Could not create session before simulated disconnect"
		)


		finish_failed()

		return


	# -----------------------------------------------------
	# Probamos directamente la ruta que utiliza la señal
	# player_disconnected. No desconectamos físicamente el
	# Client para poder completar la suite en una sola run.
	# -----------------------------------------------------

	revive_manager._on_player_disconnected(
		remote_peer_id
	)


	if not await wait_for_session_cleared(
		remote_peer_id
	):

		fail_step(
			10,
			"Disconnect cleanup",
			"Session survived player_disconnected cleanup"
		)


		finish_failed()

		return


	if get_life_state(
		1
	) != LIFE_UNCONSCIOUS:

		fail_step(
			10,
			"Disconnect cleanup",
			"Disconnect cleanup incorrectly revived target"
		)


		finish_failed()

		return


	pass_step(
		10,
		"Disconnect cleanup",
		"Active revive session removed on rescuer disconnect path"
	)


	# Restauramos Host para la última prueba.

	if not health_manager.revive_peer(
		1,
		1.0
	):

		fail_step(
			10,
			"Disconnect cleanup",
			"Could not restore Host after cleanup test"
		)


		finish_failed()

		return


	# =====================================================
	# STEP 11
	# DEAD TARGET
	# =====================================================

	if not health_manager.force_die_peer(
		remote_peer_id
	):

		fail_step(
			11,
			"Dead target rejection",
			"Could not force Client DEAD"
		)


		finish_failed()

		return


	if not await wait_for_life_state(
		remote_peer_id,
		LIFE_DEAD
	):

		fail_step(
			11,
			"Dead target rejection",
			"Client authoritative state did not become DEAD"
		)


		finish_failed()

		return


	var dead_target_result: bool = (
		revive_manager.request_revive_start(
			remote_peer_id
		)
	)


	if dead_target_result:

		fail_step(
			11,
			"Dead target rejection",
			"Host accepted revive request for DEAD target"
		)


		finish_failed()

		return


	if revive_manager.revive_sessions.has(
		1
	):

		fail_step(
			11,
			"Dead target rejection",
			"Revive session created for DEAD target"
		)


		finish_failed()

		return


	if not await client_expect_health(
		remote_peer_id,
		LIFE_DEAD,
		"CLIENT_DEAD"
	):

		fail_step(
			11,
			"Dead target rejection",
			"DEAD state did not replicate to Client"
		)


		finish_failed()

		return


	pass_step(
		11,
		"Dead target rejection",
		"DEAD target cannot be revived"
	)


	# =====================================================
	# COMPLETE
	# =====================================================

	restore_revive_time()


	print_summary(
		"HOST"
	)


	qa_client_finish.rpc_id(
		remote_peer_id
	)


	test_finished = true

	test_running = false


# =========================================================
# CLIENT — SET POSITION
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_client_set_position(
	new_position: Vector2
):

	if not NetworkManager.is_client():
		return


	resolve_references()


	if local_player == null:
		return


	local_player.global_position = (
		new_position
	)


	local_player.velocity = Vector2.ZERO


	# -----------------------------------------------------
	# Publicamos varias muestras para evitar el problema de
	# posición stale que vimos en QA anteriores.
	# -----------------------------------------------------

	for i in range(
		4
	):

		if (
			player_manager != null
			and player_manager.has_method(
				"send_local_movement_state"
			)
		):

			player_manager.send_local_movement_state()


		await get_tree().create_timer(
			0.05
		).timeout


# =========================================================
# CLIENT — START
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_client_request_start(
	target_peer_id: int
):

	if not NetworkManager.is_client():
		return


	resolve_references()


	if revive_manager == null:
		return


	revive_manager.request_revive_start(
		target_peer_id
	)


# =========================================================
# CLIENT — STOP
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_client_request_stop(
	target_peer_id: int
):

	if not NetworkManager.is_client():
		return


	resolve_references()


	if revive_manager == null:
		return


	revive_manager.request_revive_stop(
		target_peer_id
	)


# =========================================================
# WAIT REMOTE POSITION
# =========================================================

func wait_for_remote_position(
	expected_position: Vector2,
	tolerance: float
) -> bool:

	var elapsed: float = 0.0


	while elapsed < stage_timeout:

		var avatar = (
			player_manager.get_remote_player(
				remote_peer_id
			)
		)


		if (
			avatar != null
			and is_instance_valid(
				avatar
			)
		):

			var known_position: Vector2 = (
				avatar.target_position
			)


			if (
				known_position.distance_to(
					expected_position
				)
				<= tolerance
			):

				return true


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	return false


# =========================================================
# WAIT LIFE STATE
# =========================================================

func wait_for_life_state(
	peer_id: int,
	expected_state: String,
	timeout: float = -1.0
) -> bool:

	var effective_timeout: float = (
		stage_timeout
	)


	if timeout > 0.0:

		effective_timeout = (
			timeout
		)


	var elapsed: float = 0.0


	while elapsed < effective_timeout:

		if (
			get_life_state(
				peer_id
			)
			== expected_state
		):

			return true


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	return false


# =========================================================
# GET LIFE STATE
# =========================================================

func get_life_state(
	peer_id: int
) -> String:

	if health_manager == null:
		return ""


	return str(
		health_manager.get_peer_life_state(
			peer_id
		)
	)


# =========================================================
# WAIT SESSION ACTIVE
# =========================================================

func wait_for_session_active(
	rescuer_peer_id: int,
	target_peer_id: int
) -> bool:

	var elapsed: float = 0.0


	while elapsed < stage_timeout:

		if revive_manager.revive_sessions.has(
			rescuer_peer_id
		):

			var session: Dictionary = (
				revive_manager.revive_sessions[
					rescuer_peer_id
				]
			)


			if int(
				session.get(
					"target_peer_id",
					0
				)
			) == target_peer_id:

				return true


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	return false


# =========================================================
# WAIT SESSION CLEARED
# =========================================================

func wait_for_session_cleared(
	rescuer_peer_id: int
) -> bool:

	var elapsed: float = 0.0


	while elapsed < stage_timeout:

		if not revive_manager.revive_sessions.has(
			rescuer_peer_id
		):

			return true


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	return false


# =========================================================
# CLIENT HEALTH EXPECTATION
# =========================================================

func client_expect_health(
	peer_id: int,
	expected_state: String,
	token: String
) -> bool:

	health_report_received = false

	health_report_token = token

	health_report_state = ""

	health_report_value = 0.0


	qa_client_expect_health.rpc_id(
		remote_peer_id,
		peer_id,
		expected_state,
		token
	)


	var elapsed: float = 0.0


	while elapsed < stage_timeout:

		if (
			health_report_received
			and health_report_token
				== token
		):

			return (
				health_report_state
				== expected_state
			)


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	return false


# =========================================================
# CLIENT — EXPECT HEALTH
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_client_expect_health(
	peer_id: int,
	expected_state: String,
	token: String
):

	if not NetworkManager.is_client():
		return


	resolve_references()


	var elapsed: float = 0.0


	while elapsed < stage_timeout:

		if health_manager != null:

			var current_state: String = str(
				health_manager.get_peer_life_state(
					peer_id
				)
			)


			if current_state == expected_state:

				var hp: float = float(
					health_manager.get_peer_health(
						peer_id
					)
				)


				qa_report_health.rpc_id(
					1,
					token,
					current_state,
					hp
				)


				return


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	var final_state: String = ""

	var final_health: float = 0.0


	if health_manager != null:

		final_state = str(
			health_manager.get_peer_life_state(
				peer_id
			)
		)


		final_health = float(
			health_manager.get_peer_health(
				peer_id
			)
		)


	qa_report_health.rpc_id(
		1,
		token,
		final_state,
		final_health
	)


# =========================================================
# CLIENT -> HOST HEALTH REPORT
# =========================================================

@rpc(
	"any_peer",
	"call_remote",
	"reliable"
)
func qa_report_health(
	token: String,
	state: String,
	health: float
):

	if not NetworkManager.is_host():
		return


	var sender_id: int = (
		multiplayer.get_remote_sender_id()
	)


	if sender_id != remote_peer_id:
		return


	health_report_received = true

	health_report_token = token

	health_report_state = state

	health_report_value = health


# =========================================================
# CLIENT FINISH
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_client_finish():

	if not NetworkManager.is_client():
		return


	print("")
	print("[QA] ========================================")
	print("[QA] REVIVE NETWORK AUTHORITY")
	print("[QA] CLIENT SIDE COMPLETE")
	print("[QA] ========================================")


	test_finished = true

	test_running = false


# =========================================================
# RESTORE CONFIG
# =========================================================

func restore_revive_time():

	if not revive_time_saved:
		return


	if revive_manager == null:
		return


	if not is_instance_valid(
		revive_manager
	):
		return


	revive_manager.revive_time = (
		original_revive_time
	)


	revive_time_saved = false


	print(
		"[QA] Revive time restored to ",
		original_revive_time,
		" s"
	)


# =========================================================
# PASS
# =========================================================

func pass_step(
	step_number: int,
	title: String,
	detail: String
):

	pass_count += 1


	print(
		"[QA][STEP ",
		str(
			step_number
		).pad_zeros(
			2
		),
		"][PASS] ",
		title,
		" | ",
		detail
	)


# =========================================================
# FAIL
# =========================================================

func fail_step(
	step_number: int,
	title: String,
	detail: String
):

	fail_count += 1


	print(
		"[QA][STEP ",
		str(
			step_number
		).pad_zeros(
			2
		),
		"][FAIL] ",
		title,
		" | ",
		detail
	)


# =========================================================
# FAILED
# =========================================================

func finish_failed():

	restore_revive_time()


	print_summary(
		"FAILED"
	)


	test_finished = true

	test_running = false


# =========================================================
# SUMMARY
# =========================================================

func print_summary(
	context: String
):

	print(
		"[QA] ----------------------------------------"
	)


	print(
		"[QA] SUMMARY | ",
		context
	)


	print(
		"[QA] PASS: ",
		pass_count
	)


	print(
		"[QA] FAIL: ",
		fail_count
	)


	print(
		"[QA] SKIP: ",
		skip_count
	)


	if fail_count <= 0:

		print(
			"[QA] RESULT: TEST PASSED"
		)

	else:

		print(
			"[QA] RESULT: TEST FAILED"
		)


	print(
		"[QA] ========================================"
	)
