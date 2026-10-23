extends Node


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("QA")

@export var start_on_run: bool = false

@export var network_timeout: float = 30.0

@export var stage_timeout: float = 3.0

@export var poll_interval: float = 0.02


@export_group("Tolerances")

@export var target_tolerance_px: float = 8.0

@export var visual_tolerance_px: float = 10.0

@export var stable_max_error_px: float = 20.0

@export var stability_window: float = 0.60


# =========================================================
# POSICIONES
# =========================================================

const HOST_START := Vector2(
	260.0,
	300.0
)

const HOST_SINGLE := Vector2(
	360.0,
	300.0
)

const HOST_RAPID_A := Vector2(
	380.0,
	300.0
)

const HOST_RAPID_B := Vector2(
	440.0,
	300.0
)

const HOST_RAPID_C := Vector2(
	500.0,
	300.0
)


const CLIENT_START := Vector2(
	740.0,
	300.0
)

const CLIENT_SINGLE := Vector2(
	820.0,
	300.0
)

const CLIENT_RAPID_A := Vector2(
	840.0,
	300.0
)

const CLIENT_RAPID_B := Vector2(
	920.0,
	300.0
)

const CLIENT_RAPID_C := Vector2(
	1000.0,
	300.0
)


# =========================================================
# REFERENCIAS
# =========================================================

var player_manager = null

var local_player = null

var submarine_status = null


# =========================================================
# NETWORK
# =========================================================

var remote_peer_id: int = 0


# =========================================================
# QA
# =========================================================

var pass_count: int = 0

var fail_count: int = 0

var skip_count: int = 0

var test_running: bool = false

var test_finished: bool = false


# =========================================================
# CLIENT REPORT
# =========================================================

var report_received: bool = false

var report_token: String = ""

var report_passed: bool = false

var report_detail: String = ""

var report_target_error: float = 0.0

var report_visual_error: float = 0.0

var report_convergence_time: float = 0.0

var report_stable_error: float = 0.0

var report_local_position: Vector2 = Vector2.ZERO


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

	release_movement_inputs()


	print("")
	print("[QA] ========================================")
	print("[QA] TEST: PLAYER MOVEMENT NETWORK")
	print("[QA] ========================================")


	if not validate_references():

		fail_step(
			1,
			"Required nodes",
			"Player or NetworkPlayerManager missing"
		)


		finish_failed()

		return


	pass_step(
		1,
		"Required nodes",
		"Movement network references resolved"
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


	local_player = (
		scene.get_node_or_null(
			"Player"
		)
	)


	submarine_status = (
		scene.get_node_or_null(
			"SubmarineStatus"
		)
	)


# =========================================================
# VALIDATE
# =========================================================

func validate_references() -> bool:

	if player_manager == null:
		return false


	if local_player == null:
		return false


	if not player_manager.has_method(
		"send_local_movement_state"
	):

		return false


	if not player_manager.has_method(
		"get_remote_player"
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
# INPUTS
# =========================================================

func release_movement_inputs():

	Input.action_release(
		"move_up"
	)


	Input.action_release(
		"move_down"
	)


	Input.action_release(
		"move_left"
	)


	Input.action_release(
		"move_right"
	)


# =========================================================
# WAIT NETWORK
# =========================================================

func wait_for_network():

	var elapsed: float = 0.0


	while elapsed < network_timeout:

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

	# =====================================================
	# STEP 03
	# INITIAL POSITIONING
	# =====================================================

	await move_local_player_and_publish(
		HOST_START
	)


	reset_report()


	qa_client_move_and_publish.rpc_id(
		remote_peer_id,
		CLIENT_START,
		"INITIAL_CLIENT"
	)


	if not await wait_for_report(
		"INITIAL_CLIENT"
	):

		fail_step(
			3,
			"Initial positioning",
			"Client positioning report timed out"
		)


		finish_failed()

		return


	if not report_passed:

		fail_step(
			3,
			"Initial positioning",
			report_detail
		)


		finish_failed()

		return


	if not await wait_for_remote_avatar(
		remote_peer_id
	):

		fail_step(
			3,
			"Initial positioning",
			"Host did not create Client avatar"
		)


		finish_failed()

		return


	if not await client_wait_for_remote_avatar(
		1,
		"INITIAL_HOST_AVATAR"
	):

		fail_step(
			3,
			"Initial positioning",
			report_detail
		)


		finish_failed()

		return


	pass_step(
		3,
		"Initial positioning",
		"Host and Client remote avatars available"
	)


	# =====================================================
	# STEP 04
	# CLIENT -> HOST SINGLE MOVE
	# =====================================================

	reset_report()


	qa_client_move_and_publish.rpc_id(
		remote_peer_id,
		CLIENT_SINGLE,
		"CLIENT_SINGLE"
	)


	if not await wait_for_report(
		"CLIENT_SINGLE"
	):

		fail_step(
			4,
			"Client -> Host target",
			"Client movement command timed out"
		)


		finish_failed()

		return


	var client_to_host_metrics: Dictionary = (
		await measure_remote_avatar_local(
			remote_peer_id,
			CLIENT_SINGLE
		)
	)


	if not bool(
		client_to_host_metrics.get(
			"passed",
			false
		)
	):

		fail_step(
			4,
			"Client -> Host target",
			str(
				client_to_host_metrics.get(
					"detail",
					"Unknown movement error"
				)
			)
		)


		finish_failed()

		return


	pass_step(
		4,
		"Client -> Host target",
		format_metrics(
			client_to_host_metrics
		)
	)


	# =====================================================
	# STEP 05
	# CLIENT RAPID PATH
	# =====================================================

	reset_report()


	qa_client_run_rapid_path.rpc_id(
		remote_peer_id,
		CLIENT_RAPID_A,
		CLIENT_RAPID_B,
		CLIENT_RAPID_C,
		"CLIENT_RAPID"
	)


	if not await wait_for_report(
		"CLIENT_RAPID"
	):

		fail_step(
			5,
			"Client rapid path",
			"Client rapid path report timed out"
		)


		finish_failed()

		return


	if not report_passed:

		fail_step(
			5,
			"Client rapid path",
			report_detail
		)


		finish_failed()

		return


	var rapid_client_metrics: Dictionary = (
		await measure_remote_avatar_local(
			remote_peer_id,
			CLIENT_RAPID_C
		)
	)


	if not bool(
		rapid_client_metrics.get(
			"passed",
			false
		)
	):

		fail_step(
			5,
			"Client rapid path",
			str(
				rapid_client_metrics.get(
					"detail",
					"Final Client waypoint not stable"
				)
			)
		)


		finish_failed()

		return


	pass_step(
		5,
		"Client rapid path",
		"Final C stable | "
		+ format_metrics(
			rapid_client_metrics
		)
	)


	# =====================================================
	# STEP 06
	# HOST -> CLIENT SINGLE MOVE
	# =====================================================

	await move_local_player_and_publish(
		HOST_SINGLE
	)


	if not await client_measure_remote_avatar(
		1,
		HOST_SINGLE,
		"HOST_SINGLE"
	):

		fail_step(
			6,
			"Host -> Client target",
			report_detail
		)


		finish_failed()

		return


	pass_step(
		6,
		"Host -> Client target",
		"TargetErr="
		+ str(
			snapped(
				report_target_error,
				0.1
			)
		)
		+ "px | VisualErr="
		+ str(
			snapped(
				report_visual_error,
				0.1
			)
		)
		+ "px | Conv="
		+ str(
			snapped(
				report_convergence_time,
				0.01
			)
		)
		+ "s"
	)


	# =====================================================
	# STEP 07
	# HOST RAPID PATH
	# =====================================================

	await move_local_player_and_publish(
		HOST_RAPID_A,
		2,
		0.025
	)


	await move_local_player_and_publish(
		HOST_RAPID_B,
		2,
		0.025
	)


	await move_local_player_and_publish(
		HOST_RAPID_C,
		6,
		0.025
	)


	if not await client_measure_remote_avatar(
		1,
		HOST_RAPID_C,
		"HOST_RAPID"
	):

		fail_step(
			7,
			"Host rapid path",
			report_detail
		)


		finish_failed()

		return


	if report_stable_error > stable_max_error_px:

		fail_step(
			7,
			"Host rapid path",
			"Final state regressed | Stable error "
			+ str(
				snapped(
					report_stable_error,
					0.1
				)
			)
			+ "px"
		)


		finish_failed()

		return


	pass_step(
		7,
		"Host rapid path",
		"Final C stable | MaxStableErr="
		+ str(
			snapped(
				report_stable_error,
				0.1
			)
		)
		+ "px"
	)


	# =====================================================
	# STEP 08
	# FINAL CROSS-PEER COHERENCE
	# =====================================================

	var host_view_client = (
		player_manager.get_remote_player(
			remote_peer_id
		)
	)


	if host_view_client == null:

		fail_step(
			8,
			"Final peer coherence",
			"Host lost Client avatar"
		)


		finish_failed()

		return


	var host_client_target_error: float = (
		host_view_client.target_position.distance_to(
			CLIENT_RAPID_C
		)
	)


	if (
		host_client_target_error
		> target_tolerance_px
	):

		fail_step(
			8,
			"Final peer coherence",
			"Host sees Client at wrong final target | Error "
			+ str(
				snapped(
					host_client_target_error,
					0.1
				)
			)
			+ "px"
		)


		finish_failed()

		return


	if not await client_check_final_coherence(
		HOST_RAPID_C,
		CLIENT_RAPID_C,
		"FINAL_COHERENCE"
	):

		fail_step(
			8,
			"Final peer coherence",
			report_detail
		)


		finish_failed()

		return


	pass_step(
		8,
		"Final peer coherence",
		"Host and Client retain independent final positions"
	)


	# =====================================================
	# COMPLETE
	# =====================================================

	restore_environment_guard()


	print_summary(
		"HOST"
	)


	qa_client_finish.rpc_id(
		remote_peer_id
	)


	test_finished = true

	test_running = false


# =========================================================
# LOCAL MOVE + PUBLISH
# =========================================================

func move_local_player_and_publish(
	new_position: Vector2,
	samples: int = 6,
	sample_delay: float = 0.03
):

	release_movement_inputs()


	local_player.global_position = (
		new_position
	)


	local_player.velocity = (
		Vector2.ZERO
	)


	for i in range(
		samples
	):

		player_manager.send_local_movement_state()


		await get_tree().create_timer(
			sample_delay
		).timeout


# =========================================================
# CLIENT MOVE
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_client_move_and_publish(
	new_position: Vector2,
	token: String
):

	if not NetworkManager.is_client():
		return


	resolve_references()

	release_movement_inputs()


	if (
		player_manager == null
		or local_player == null
	):

		qa_report_metrics.rpc_id(
			1,
			token,
			false,
			"Client references missing",
			0.0,
			0.0,
			0.0,
			0.0,
			Vector2.ZERO
		)

		return


	local_player.global_position = (
		new_position
	)


	local_player.velocity = (
		Vector2.ZERO
	)


	for i in range(
		6
	):

		player_manager.send_local_movement_state()


		await get_tree().create_timer(
			0.03
		).timeout


	var local_error: float = (
		local_player.global_position.distance_to(
			new_position
		)
	)


	qa_report_metrics.rpc_id(
		1,
		token,
		local_error <= target_tolerance_px,
		"Client local position error "
		+ str(
			snapped(
				local_error,
				0.1
			)
		)
		+ "px",
		local_error,
		0.0,
		0.0,
		0.0,
		local_player.global_position
	)


# =========================================================
# CLIENT RAPID PATH
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_client_run_rapid_path(
	position_a: Vector2,
	position_b: Vector2,
	position_c: Vector2,
	token: String
):

	if not NetworkManager.is_client():
		return


	resolve_references()

	release_movement_inputs()


	if (
		player_manager == null
		or local_player == null
	):

		qa_report_metrics.rpc_id(
			1,
			token,
			false,
			"Client references missing",
			0.0,
			0.0,
			0.0,
			0.0,
			Vector2.ZERO
		)

		return


	var positions: Array[Vector2] = [
		position_a,
		position_b,
		position_c
	]


	for index in range(
		positions.size()
	):

		local_player.global_position = (
			positions[
				index
			]
		)


		local_player.velocity = Vector2.ZERO


		var samples: int = 2


		if index == positions.size() - 1:

			samples = 6


		for sample_index in range(
			samples
		):

			player_manager.send_local_movement_state()


			await get_tree().create_timer(
				0.025
			).timeout


	var local_error: float = (
		local_player.global_position.distance_to(
			position_c
		)
	)


	qa_report_metrics.rpc_id(
		1,
		token,
		local_error <= target_tolerance_px,
		"Client final waypoint error "
		+ str(
			snapped(
				local_error,
				0.1
			)
		)
		+ "px",
		local_error,
		0.0,
		0.0,
		0.0,
		local_player.global_position
	)


# =========================================================
# MEASURE REMOTE AVATAR LOCALLY
# =========================================================

func measure_remote_avatar_local(
	peer_id: int,
	expected_position: Vector2
) -> Dictionary:

	var avatar = (
		player_manager.get_remote_player(
			peer_id
		)
	)


	if avatar == null:

		return {
			"passed": false,
			"detail": "Remote avatar missing"
		}


	var elapsed: float = 0.0

	var target_reached: bool = false

	var target_error: float = INF


	while elapsed < stage_timeout:

		target_error = (
			avatar.target_position.distance_to(
				expected_position
			)
		)


		if target_error <= target_tolerance_px:

			target_reached = true

			break


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	if not target_reached:

		return {
			"passed": false,
			"detail":
				"Target position did not converge | Error "
				+ str(
					snapped(
						target_error,
						0.1
					)
				)
				+ "px"
		}


	var convergence_elapsed: float = 0.0

	var visual_error: float = INF


	while convergence_elapsed < stage_timeout:

		visual_error = (
			avatar.global_position.distance_to(
				expected_position
			)
		)


		if visual_error <= visual_tolerance_px:
			break


		await get_tree().create_timer(
			poll_interval
		).timeout


		convergence_elapsed += (
			poll_interval
		)


	if visual_error > visual_tolerance_px:

		return {
			"passed": false,
			"detail":
				"Visual avatar did not converge | Error "
				+ str(
					snapped(
						visual_error,
						0.1
					)
				)
				+ "px"
		}


	var stable_elapsed: float = 0.0

	var max_stable_error: float = 0.0


	while stable_elapsed < stability_window:

		var current_error: float = (
			avatar.target_position.distance_to(
				expected_position
			)
		)


		max_stable_error = max(
			max_stable_error,
			current_error
		)


		await get_tree().create_timer(
			poll_interval
		).timeout


		stable_elapsed += poll_interval


	if max_stable_error > stable_max_error_px:

		return {
			"passed": false,
			"detail":
				"Target regressed after final waypoint | Max "
				+ str(
					snapped(
						max_stable_error,
						0.1
					)
				)
				+ "px"
		}


	return {
		"passed": true,
		"target_error": target_error,
		"visual_error": visual_error,
		"convergence_time": convergence_elapsed,
		"stable_error": max_stable_error
	}


# =========================================================
# CLIENT MEASURE REMOTE
# =========================================================

func client_measure_remote_avatar(
	peer_id: int,
	expected_position: Vector2,
	token: String
) -> bool:

	reset_report()


	qa_client_measure_remote_avatar.rpc_id(
		remote_peer_id,
		peer_id,
		expected_position,
		token
	)


	if not await wait_for_report(
		token
	):

		report_detail = (
			"Timed out waiting for Client movement metrics"
		)

		return false


	return report_passed


@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_client_measure_remote_avatar(
	peer_id: int,
	expected_position: Vector2,
	token: String
):

	if not NetworkManager.is_client():
		return


	resolve_references()


	if player_manager == null:

		qa_report_metrics.rpc_id(
			1,
			token,
			false,
			"Client NetworkPlayerManager missing",
			0.0,
			0.0,
			0.0,
			0.0,
			Vector2.ZERO
		)

		return


	var metrics: Dictionary = (
		await measure_remote_avatar_local(
			peer_id,
			expected_position
		)
	)


	qa_report_metrics.rpc_id(
		1,
		token,
		bool(
			metrics.get(
				"passed",
				false
			)
		),
		str(
			metrics.get(
				"detail",
				"OK"
			)
		),
		float(
			metrics.get(
				"target_error",
				0.0
			)
		),
		float(
			metrics.get(
				"visual_error",
				0.0
			)
		),
		float(
			metrics.get(
				"convergence_time",
				0.0
			)
		),
		float(
			metrics.get(
				"stable_error",
				0.0
			)
		),
		local_player.global_position
	)


# =========================================================
# WAIT REMOTE AVATAR
# =========================================================

func wait_for_remote_avatar(
	peer_id: int
) -> bool:

	var elapsed: float = 0.0


	while elapsed < stage_timeout:

		var avatar = (
			player_manager.get_remote_player(
				peer_id
			)
		)


		if (
			avatar != null
			and is_instance_valid(
				avatar
			)
		):

			return true


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	return false


# =========================================================
# CLIENT WAIT REMOTE AVATAR
# =========================================================

func client_wait_for_remote_avatar(
	peer_id: int,
	token: String
) -> bool:

	reset_report()


	qa_client_wait_remote_avatar.rpc_id(
		remote_peer_id,
		peer_id,
		token
	)


	if not await wait_for_report(
		token
	):

		report_detail = (
			"Client remote avatar wait timed out"
		)

		return false


	return report_passed


@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_client_wait_remote_avatar(
	peer_id: int,
	token: String
):

	if not NetworkManager.is_client():
		return


	resolve_references()


	var elapsed: float = 0.0


	while elapsed < stage_timeout:

		if player_manager != null:

			var avatar = (
				player_manager.get_remote_player(
					peer_id
				)
			)


			if (
				avatar != null
				and is_instance_valid(
					avatar
				)
			):

				qa_report_metrics.rpc_id(
					1,
					token,
					true,
					"Remote avatar available",
					0.0,
					0.0,
					0.0,
					0.0,
					local_player.global_position
				)

				return


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	qa_report_metrics.rpc_id(
		1,
		token,
		false,
		"Remote avatar missing",
		0.0,
		0.0,
		0.0,
		0.0,
		local_player.global_position
	)


# =========================================================
# FINAL COHERENCE
# =========================================================

func client_check_final_coherence(
	expected_host_position: Vector2,
	expected_client_position: Vector2,
	token: String
) -> bool:

	reset_report()


	qa_client_check_final_coherence.rpc_id(
		remote_peer_id,
		expected_host_position,
		expected_client_position,
		token
	)


	if not await wait_for_report(
		token
	):

		report_detail = (
			"Final Client coherence report timed out"
		)

		return false


	return report_passed


@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_client_check_final_coherence(
	expected_host_position: Vector2,
	expected_client_position: Vector2,
	token: String
):

	if not NetworkManager.is_client():
		return


	resolve_references()


	var host_avatar = (
		player_manager.get_remote_player(
			1
		)
	)


	if host_avatar == null:

		qa_report_metrics.rpc_id(
			1,
			token,
			false,
			"Client lost Host avatar",
			0.0,
			0.0,
			0.0,
			0.0,
			local_player.global_position
		)

		return


	var host_error: float = (
		host_avatar.target_position.distance_to(
			expected_host_position
		)
	)


	var client_error: float = (
		local_player.global_position.distance_to(
			expected_client_position
		)
	)


	var passed: bool = (
		host_error <= target_tolerance_px
		and client_error <= target_tolerance_px
	)


	qa_report_metrics.rpc_id(
		1,
		token,
		passed,
		"HostRemoteErr="
		+ str(
			snapped(
				host_error,
				0.1
			)
		)
		+ "px | ClientLocalErr="
		+ str(
			snapped(
				client_error,
				0.1
			)
		)
		+ "px",
		host_error,
		0.0,
		0.0,
		0.0,
		local_player.global_position
	)


# =========================================================
# REPORT
# =========================================================

@rpc(
	"any_peer",
	"call_remote",
	"reliable"
)
func qa_report_metrics(
	token: String,
	passed: bool,
	detail: String,
	target_error: float,
	visual_error: float,
	convergence_time: float,
	stable_error: float,
	local_position: Vector2
):

	if not NetworkManager.is_host():
		return


	if (
		multiplayer.get_remote_sender_id()
		!= remote_peer_id
	):

		return


	report_received = true

	report_token = token

	report_passed = passed

	report_detail = detail

	report_target_error = target_error

	report_visual_error = visual_error

	report_convergence_time = convergence_time

	report_stable_error = stable_error

	report_local_position = local_position


# =========================================================
# REPORT CONTROL
# =========================================================

func reset_report():

	report_received = false

	report_token = ""

	report_passed = false

	report_detail = ""

	report_target_error = 0.0

	report_visual_error = 0.0

	report_convergence_time = 0.0

	report_stable_error = 0.0

	report_local_position = Vector2.ZERO


func wait_for_report(
	token: String
) -> bool:

	var elapsed: float = 0.0


	while elapsed < stage_timeout:

		if (
			report_received
			and report_token == token
		):

			return true


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	return false


# =========================================================
# FORMAT METRICS
# =========================================================

func format_metrics(
	metrics: Dictionary
) -> String:

	return (
		"TargetErr="
		+ str(
			snapped(
				float(
					metrics.get(
						"target_error",
						0.0
					)
				),
				0.1
			)
		)
		+ "px | VisualErr="
		+ str(
			snapped(
				float(
					metrics.get(
						"visual_error",
						0.0
					)
				),
				0.1
			)
		)
		+ "px | Conv="
		+ str(
			snapped(
				float(
					metrics.get(
						"convergence_time",
						0.0
					)
				),
				0.01
			)
		)
		+ "s | StableErr="
		+ str(
			snapped(
				float(
					metrics.get(
						"stable_error",
						0.0
					)
				),
				0.1
			)
		)
		+ "px"
	)


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
	print("[QA] PLAYER MOVEMENT NETWORK")
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
		and remote_peer_id > 1
	):

		qa_client_abort.rpc_id(
			remote_peer_id
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
