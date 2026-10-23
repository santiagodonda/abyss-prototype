extends Node


# =========================================================
# CONFIG
# =========================================================

@export var start_on_run: bool = false

@export var network_timeout: float = 30.0

@export var stage_timeout: float = 3.0

@export var poll_interval: float = 0.05


# =========================================================
# REFERENCES
# =========================================================

var mission_state = null

var mission_manager = null


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

var attack_sent: bool = false


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


	resolve_references()


	print("")
	print("[QA] ========================================")
	print("[QA] TEST: NETWORK RESTART POLICY")
	print("[QA] ========================================")


	if (
		mission_state == null
		or mission_manager == null
	):

		fail_step(
			1,
			"Required nodes",
			"Mission references missing"
		)


		finish_test()

		return


	pass_step(
		1,
		"Required nodes",
		"Mission restart policy references resolved"
	)


	await wait_for_network()


	if not test_running:
		return


	if NetworkManager.is_client():

		print(
			"[QA] CLIENT ready | Peer ",
			multiplayer.get_unique_id()
		)

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


	mission_state = (
		scene.get_node_or_null(
			"MissionState"
		)
	)


	mission_manager = (
		scene.get_node_or_null(
			"NetworkMissionManager"
		)
	)


# =========================================================
# NETWORK WAIT
# =========================================================

func wait_for_network():

	var elapsed: float = 0.0


	while elapsed < network_timeout:

		if NetworkManager.is_client():

			pass_step(
				2,
				"Network ready",
				"CLIENT"
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
					"HOST + Client "
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


	finish_test()


# =========================================================
# HOST SUITE
# =========================================================

func run_host_suite():

	# -----------------------------------------------------
	# STEP 03
	# RUNNING MUST BE CLOSED
	# -----------------------------------------------------

	if not mission_state.is_running():

		fail_step(
			3,
			"RUNNING baseline",
			"Mission is not RUNNING"
		)


		finish_test()

		return


	if NetworkManager.can_peer_request_network_restart(
		remote_peer_id
	):

		fail_step(
			3,
			"RUNNING policy",
			"Host policy allows Client restart while RUNNING"
		)


		finish_test()

		return


	pass_step(
		3,
		"RUNNING policy",
		"Client restart forbidden while mission RUNNING"
	)


	# -----------------------------------------------------
	# STEP 04
	# MALICIOUS DIRECT RPC
	# -----------------------------------------------------

	attack_sent = false


	qa_client_send_direct_restart.rpc_id(
		remote_peer_id
	)


	var elapsed: float = 0.0


	while (
		not attack_sent
		and elapsed < stage_timeout
	):

		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	if not attack_sent:

		fail_step(
			4,
			"Direct RPC rejection",
			"Client did not send QA restart request"
		)


		finish_test()

		return


	await get_tree().create_timer(
		0.40
	).timeout


	if NetworkManager.is_restart_in_progress():

		fail_step(
			4,
			"Direct RPC rejection",
			"Malicious Client started network restart"
		)


		finish_test()

		return


	if not mission_state.is_running():

		fail_step(
			4,
			"Direct RPC rejection",
			"Mission changed during rejected request"
		)


		finish_test()

		return


	pass_step(
		4,
		"Direct RPC rejection",
		"Host rejected Client RPC while RUNNING"
	)


	# -----------------------------------------------------
	# STEP 05
	# TERMINAL STATE OPENS POLICY
	# -----------------------------------------------------

	mission_state.fail_mission(
		"QA RESTART POLICY"
	)


	mission_manager.force_sync_for_qa()


	await get_tree().create_timer(
		0.20
	).timeout


	if mission_state.is_running():

		fail_step(
			5,
			"Terminal policy",
			"Mission did not enter FAILED"
		)


		finish_test()

		return


	if not NetworkManager.can_peer_request_network_restart(
		remote_peer_id
	):

		fail_step(
			5,
			"Terminal policy",
			"Client restart still forbidden after FAILED"
		)


		finish_test()

		return


	pass_step(
		5,
		"Terminal policy",
		"FAILED mission authorizes Client restart"
	)


	# -----------------------------------------------------
	# FIN
	# -----------------------------------------------------

	finish_test()


# =========================================================
# CLIENT DIRECT ATTACK
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_client_send_direct_restart():

	if not NetworkManager.is_client():
		return


	# Intencionalmente salteamos request_game_restart().
	# Estamos atacando directamente el RPC protegido.
	NetworkManager.request_restart_from_host.rpc_id(
		1
	)


	qa_report_attack_sent.rpc_id(
		1
	)


# =========================================================
# REPORT
# =========================================================

@rpc(
	"any_peer",
	"call_remote",
	"reliable"
)
func qa_report_attack_sent():

	if not NetworkManager.is_host():
		return


	if (
		multiplayer.get_remote_sender_id()
		!= remote_peer_id
	):

		return


	attack_sent = true


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
# FINISH
# =========================================================

func finish_test():

	print(
		"[QA] ----------------------------------------"
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


	test_running = false
