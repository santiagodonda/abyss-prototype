extends Node


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("QA")

@export var start_on_run: bool = false

@export var network_timeout: float = 30.0

@export var reconnect_timeout: float = 10.0

@export var stage_timeout: float = 4.0

@export var poll_interval: float = 0.05

@export var reconnect_delay: float = 0.50


# =========================================================
# REFERENCIAS
# =========================================================

var player_manager = null

var health_manager = null

var crew_manager = null

var mission_manager = null

var mission_state = null

var mission_objective = null

var submarine_status = null


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

var initial_client_peer_id: int = 0

var reconnected_peer_id: int = 0

var disconnect_seen: bool = false

var reconnect_seen: bool = false

var client_reconnect_reported: bool = false


# =========================================================
# CLIENT REPORT
# =========================================================

var report_received: bool = false

var report_token: String = ""

var report_passed: bool = false

var report_detail: String = ""


# =========================================================
# ENVIRONMENT GUARD
# =========================================================

var original_lost_condition_time: float = 8.0

var lost_condition_saved: bool = false


# =========================================================
# READY
# =========================================================

func _ready():

	process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)


	NetworkManager.player_connected.connect(
		_on_qa_player_connected
	)


	NetworkManager.player_disconnected.connect(
		_on_qa_player_disconnected
	)


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


	resolve_references()

	prepare_environment_guard()


	print("")
	print("[QA] ========================================")
	print("[QA] TEST: RECONNECT STATE RECOVERY")
	print("[QA] ========================================")


	if not validate_references():

		fail_step(
			1,
			"Required nodes",
			"One or more network managers are missing"
		)


		finish_failed()

		return


	pass_step(
		1,
		"Required nodes",
		"Reconnect authority references resolved"
	)


	await wait_for_initial_network()


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
# REFERENCES
# =========================================================

func resolve_references():

	var scene = (
		get_tree().current_scene
	)


	if scene == null:
		return


	player_manager = (
		scene.get_node_or_null(
			"NetworkPlayerManager"
		)
	)


	health_manager = (
		scene.get_node_or_null(
			"NetworkPlayerHealthManager"
		)
	)


	crew_manager = (
		scene.get_node_or_null(
			"NetworkCrewRoundManager"
		)
	)


	mission_manager = (
		scene.get_node_or_null(
			"NetworkMissionManager"
		)
	)


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


	submarine_status = (
		scene.get_node_or_null(
			"SubmarineStatus"
		)
	)


# =========================================================
# VALIDATION
# =========================================================

func validate_references() -> bool:

	if player_manager == null:
		return false


	if health_manager == null:
		return false


	if crew_manager == null:
		return false


	if mission_manager == null:
		return false


	if mission_state == null:
		return false


	if mission_objective == null:
		return false


	if not player_manager.has_method(
		"get_remote_player"
	):

		return false


	if not health_manager.has_method(
		"get_peer_life_state"
	):

		return false


	return true


# =========================================================
# ENVIRONMENT GUARD
# =========================================================

func prepare_environment_guard():

	if submarine_status == null:
		return


	original_lost_condition_time = float(
		submarine_status.lost_condition_time
	)


	lost_condition_saved = true


	submarine_status.lost_condition_time = (
		9999.0
	)


func restore_environment_guard():

	if not lost_condition_saved:
		return


	if submarine_status == null:
		return


	if not is_instance_valid(
		submarine_status
	):

		return


	submarine_status.lost_condition_time = (
		original_lost_condition_time
	)


	lost_condition_saved = false


# =========================================================
# INITIAL NETWORK
# =========================================================

func wait_for_initial_network():

	var elapsed: float = 0.0


	while elapsed < network_timeout:

		if NetworkManager.is_client():

			pass_step(
				2,
				"Initial network",
				"CLIENT | Peer "
				+ str(
					multiplayer.get_unique_id()
				)
			)


			return


		if NetworkManager.is_host():

			var client_id: int = (
				get_current_client_peer_id()
			)


			if client_id > 1:

				initial_client_peer_id = (
					client_id
				)


				pass_step(
					2,
					"Initial network",
					"HOST | Client "
					+ str(
						initial_client_peer_id
					)
				)


				return


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	fail_step(
		2,
		"Initial network",
		"Timed out waiting for Host + Client"
	)


	finish_failed()


# =========================================================
# HOST SUITE
# =========================================================

func run_host_suite():

	# =====================================================
	# STEP 03
	# INTEGRATED BASELINE
	# =====================================================

	if not await wait_for_host_integrated_state(
		initial_client_peer_id
	):

		fail_step(
			3,
			"Initial state",
			get_host_state_detail(
				initial_client_peer_id
			)
		)


		finish_failed()

		return


	if not await client_validate_state(
		"INITIAL_CLIENT_STATE"
	):

		fail_step(
			3,
			"Initial state",
			report_detail
		)


		finish_failed()

		return


	pass_step(
		3,
		"Initial state",
		"Player + Health + Crew + Mission coherent on both peers"
	)


	# =====================================================
	# STEP 04
	# CLIENT DISCONNECT
	# =====================================================

	disconnect_seen = false

	reconnect_seen = false

	client_reconnect_reported = false

	reconnected_peer_id = 0


	qa_client_disconnect_and_reconnect.rpc_id(
		initial_client_peer_id
	)


	var disconnect_elapsed: float = 0.0


	while (
		not disconnect_seen
		and disconnect_elapsed
			< reconnect_timeout
	):

		await get_tree().create_timer(
			poll_interval
		).timeout


		disconnect_elapsed += (
			poll_interval
		)


	if not disconnect_seen:

		fail_step(
			4,
			"Disconnect cleanup",
			"Host did not observe Client disconnect"
		)


		finish_failed()

		return


	if NetworkManager.get_player_count() != 1:

		fail_step(
			4,
			"Disconnect cleanup",
			"Host player count did not return to 1"
		)


		finish_failed()

		return


	if (
		player_manager.get_remote_player(
			initial_client_peer_id
		)
		!= null
	):

		fail_step(
			4,
			"Disconnect cleanup",
			"Old remote avatar survived disconnect"
		)


		finish_failed()

		return


	pass_step(
		4,
		"Disconnect cleanup",
		"Host removed disconnected peer and remote avatar"
	)


	# =====================================================
	# STEP 05
	# CLIENT RECONNECT
	# =====================================================

	var reconnect_elapsed: float = 0.0


	while reconnect_elapsed < reconnect_timeout:

		if (
			reconnect_seen
			and client_reconnect_reported
			and reconnected_peer_id > 1
		):

			break


		await get_tree().create_timer(
			poll_interval
		).timeout


		reconnect_elapsed += (
			poll_interval
		)


	if (
		not reconnect_seen
		or not client_reconnect_reported
		or reconnected_peer_id <= 1
	):

		fail_step(
			5,
			"Reconnect transport",
			"Client did not reconnect within timeout"
		)


		finish_failed()

		return


	if NetworkManager.get_player_count() != 2:

		fail_step(
			5,
			"Reconnect transport",
			"Host player count is not 2 after reconnect"
		)


		finish_failed()

		return


	pass_step(
		5,
		"Reconnect transport",
		"Client reconnected as Peer "
		+ str(
			reconnected_peer_id
		)
	)


	# =====================================================
	# STEP 06
	# HOST RECONSTRUCTED STATE
	# =====================================================

	if not await wait_for_host_integrated_state(
		reconnected_peer_id
	):

		fail_step(
			6,
			"Host reconstruction",
			get_host_state_detail(
				reconnected_peer_id
			)
		)


		finish_failed()

		return


	var reconnect_health: float = float(
		health_manager.get_peer_health(
			reconnected_peer_id
		)
	)


	if reconnect_health <= 0.0:

		fail_step(
			6,
			"Host reconstruction",
			"Reconnected peer has invalid HP "
			+ str(
				reconnect_health
			)
		)


		finish_failed()

		return


	pass_step(
		6,
		"Host reconstruction",
		"Remote avatar + Health + Crew + Mission rebuilt"
	)


	# =====================================================
	# STEP 07
	# CLIENT RECEIVED SNAPSHOTS
	# =====================================================

	if not await client_validate_state(
		"RECONNECTED_CLIENT_STATE",
		reconnected_peer_id
	):

		fail_step(
			7,
			"Client reconstruction",
			report_detail
		)


		finish_failed()

		return


	pass_step(
		7,
		"Client reconstruction",
		"Client rebuilt Host + crew + mission after reconnect"
	)


	# =====================================================
	# STEP 08
	# NO DUPLICATES / FINAL COHERENCE
	# =====================================================

	if (
		player_manager.get_remote_player_count()
		!= 1
	):

		fail_step(
			8,
			"Final coherence",
			"Host remote avatar count is "
			+ str(
				player_manager.get_remote_player_count()
			)
			+ " instead of 1"
		)


		finish_failed()

		return


	if crew_manager.get_total_count() != 2:

		fail_step(
			8,
			"Final coherence",
			"Crew total is "
			+ str(
				crew_manager.get_total_count()
			)
			+ " instead of 2"
		)


		finish_failed()

		return


	if not mission_state.is_running():

		fail_step(
			8,
			"Final coherence",
			"Mission changed during reconnect"
		)


		finish_failed()

		return


	pass_step(
		8,
		"Final coherence",
		"No ghost peers | Crew=2 | Mission remains RUNNING"
	)


	# =====================================================
	# COMPLETE
	# =====================================================

	restore_environment_guard()


	print_summary(
		"HOST"
	)


	qa_client_finish.rpc_id(
		reconnected_peer_id
	)


	test_finished = true

	test_running = false


# =========================================================
# CLIENT DISCONNECT + RECONNECT
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_client_disconnect_and_reconnect():

	if not NetworkManager.is_client():
		return


	NetworkManager.disconnect_from_game()


	await get_tree().create_timer(
		reconnect_delay
	).timeout


	var started: bool = (
		NetworkManager.join_game(
			"127.0.0.1"
		)
	)


	if not started:

		print(
			"[QA][CLIENT][FAIL] Could not start reconnect"
		)

		return


	var elapsed: float = 0.0


	while elapsed < reconnect_timeout:

		if NetworkManager.is_client():

			await get_tree().process_frame

			await get_tree().process_frame


			var new_peer_id: int = (
				multiplayer.get_unique_id()
			)


			qa_client_reconnected.rpc_id(
				1,
				new_peer_id
			)


			return


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	print(
		"[QA][CLIENT][FAIL] Reconnect timeout"
	)


# =========================================================
# CLIENT -> HOST RECONNECTED
# =========================================================

@rpc(
	"any_peer",
	"call_remote",
	"reliable"
)
func qa_client_reconnected(
	reported_peer_id: int
):

	if not NetworkManager.is_host():
		return


	var sender_id: int = (
		multiplayer.get_remote_sender_id()
	)


	if sender_id <= 1:
		return


	client_reconnect_reported = true

	reconnected_peer_id = sender_id


	if reported_peer_id != sender_id:

		print(
			"[QA][CLIENT][WARN] Reported Peer ",
			reported_peer_id,
			" but sender is ",
			sender_id
		)


# =========================================================
# HOST NETWORK SIGNALS
# =========================================================

func _on_qa_player_disconnected(
	peer_id: int
):

	if not test_running:
		return


	if not NetworkManager.is_host():
		return


	if peer_id == initial_client_peer_id:

		disconnect_seen = true


func _on_qa_player_connected(
	peer_id: int
):

	if not test_running:
		return


	if not NetworkManager.is_host():
		return


	if not disconnect_seen:
		return


	if peer_id <= 1:
		return


	reconnect_seen = true

	reconnected_peer_id = peer_id


# =========================================================
# CURRENT CLIENT
# =========================================================

func get_current_client_peer_id() -> int:

	var peers: Array = (
		NetworkManager.get_connected_peer_ids()
	)


	for peer_key in peers:

		var peer_id: int = int(
			peer_key
		)


		if peer_id > 1:
			return peer_id


	return 0


# =========================================================
# HOST INTEGRATED STATE
# =========================================================

func wait_for_host_integrated_state(
	client_peer_id: int
) -> bool:

	var elapsed: float = 0.0


	while elapsed < stage_timeout:

		var remote_avatar = (
			player_manager.get_remote_player(
				client_peer_id
			)
		)


		var life_state: String = str(
			health_manager.get_peer_life_state(
				client_peer_id
			)
		)


		var valid: bool = (
			remote_avatar != null
			and is_instance_valid(
				remote_avatar
			)
			and life_state == "ALIVE"
			and crew_manager.get_total_count() == 2
			and crew_manager.get_alive_count() == 2
			and crew_manager.get_round_state()
				== "RUNNING"
			and mission_state.get_state_name()
				== "RUNNING"
			and mission_objective.get_stage_name()
				== "TRAVEL"
		)


		if valid:
			return true


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	return false


# =========================================================
# HOST DETAIL
# =========================================================

func get_host_state_detail(
	client_peer_id: int
) -> String:

	var avatar_exists: bool = false


	if player_manager != null:

		var avatar = (
			player_manager.get_remote_player(
				client_peer_id
			)
		)


		avatar_exists = (
			avatar != null
			and is_instance_valid(
				avatar
			)
		)


	var life_state: String = "UNKNOWN"


	if health_manager != null:

		life_state = str(
			health_manager.get_peer_life_state(
				client_peer_id
			)
		)


	return (
		"Avatar="
		+ str(
			avatar_exists
		)
		+ " Life="
		+ life_state
		+ " Crew="
		+ str(
			crew_manager.get_total_count()
		)
		+ " Mission="
		+ mission_state.get_state_name()
		+ "/"
		+ mission_objective.get_stage_name()
	)


# =========================================================
# CLIENT VALIDATION
# =========================================================

func client_validate_state(
	token: String,
	expected_local_peer_id: int = 0
) -> bool:

	reset_report()


	var target_peer_id: int = (
		initial_client_peer_id
	)


	if expected_local_peer_id > 1:

		target_peer_id = (
			expected_local_peer_id
		)


	qa_client_validate_state.rpc_id(
		target_peer_id,
		token
	)


	var elapsed: float = 0.0


	while elapsed < stage_timeout:

		if (
			report_received
			and report_token == token
		):

			return report_passed


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	report_detail = (
		"Timed out waiting for Client validation"
	)


	return false


@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_client_validate_state(
	token: String
):

	if not NetworkManager.is_client():
		return


	resolve_references()


	var local_peer_id: int = (
		multiplayer.get_unique_id()
	)


	var elapsed: float = 0.0


	while elapsed < stage_timeout:

		var host_avatar = (
			player_manager.get_remote_player(
				1
			)
		)


		var host_life: String = str(
			health_manager.get_peer_life_state(
				1
			)
		)


		var local_life: String = str(
			health_manager.get_peer_life_state(
				local_peer_id
			)
		)


		var passed: bool = (
			host_avatar != null
			and is_instance_valid(
				host_avatar
			)
			and host_life == "ALIVE"
			and local_life == "ALIVE"
			and crew_manager.get_total_count() == 2
			and crew_manager.get_alive_count() == 2
			and crew_manager.get_round_state()
				== "RUNNING"
			and mission_state.get_state_name()
				== "RUNNING"
			and mission_objective.get_stage_name()
				== "TRAVEL"
		)


		if passed:

			qa_report_validation.rpc_id(
				1,
				token,
				true,
				get_client_state_detail(
					local_peer_id
				)
			)


			return


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	qa_report_validation.rpc_id(
		1,
		token,
		false,
		get_client_state_detail(
			local_peer_id
		)
	)


# =========================================================
# CLIENT DETAIL
# =========================================================

func get_client_state_detail(
	local_peer_id: int
) -> String:

	var host_avatar_exists: bool = false


	if player_manager != null:

		var host_avatar = (
			player_manager.get_remote_player(
				1
			)
		)


		host_avatar_exists = (
			host_avatar != null
			and is_instance_valid(
				host_avatar
			)
		)


	return (
		"HostAvatar="
		+ str(
			host_avatar_exists
		)
		+ " LocalPeer="
		+ str(
			local_peer_id
		)
		+ " Crew="
		+ str(
			crew_manager.get_total_count()
		)
		+ " Mission="
		+ mission_state.get_state_name()
		+ "/"
		+ mission_objective.get_stage_name()
	)


# =========================================================
# CLIENT REPORT
# =========================================================

@rpc(
	"any_peer",
	"call_remote",
	"reliable"
)
func qa_report_validation(
	token: String,
	passed: bool,
	detail: String
):

	if not NetworkManager.is_host():
		return


	if (
		multiplayer.get_remote_sender_id()
		!= reconnected_peer_id
		and multiplayer.get_remote_sender_id()
		!= initial_client_peer_id
	):

		return


	report_received = true

	report_token = token

	report_passed = passed

	report_detail = detail


# =========================================================
# REPORT RESET
# =========================================================

func reset_report():

	report_received = false

	report_token = ""

	report_passed = false

	report_detail = ""


# =========================================================
# CLIENT FINISH / ABORT
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_client_finish():

	if not NetworkManager.is_client():
		return


	restore_environment_guard()


	print("")
	print("[QA] ========================================")
	print("[QA] RECONNECT STATE RECOVERY")
	print("[QA] CLIENT SIDE COMPLETE")
	print("[QA] ========================================")


	test_finished = true

	test_running = false


@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_client_abort():

	if not NetworkManager.is_client():
		return


	restore_environment_guard()


	test_finished = true

	test_running = false


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

	restore_environment_guard()


	if (
		NetworkManager.is_host()
		and reconnected_peer_id > 1
	):

		qa_client_abort.rpc_id(
			reconnected_peer_id
		)


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


	if fail_count == 0:

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
