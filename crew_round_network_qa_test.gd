extends Node


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("QA")

@export var start_on_run: bool = false

@export var network_timeout: float = 30.0

@export var stage_timeout: float = 4.0

@export var poll_interval: float = 0.05


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
# REFERENCIAS
# =========================================================

var crew_manager = null

var health_manager = null


# =========================================================
# QA STATE
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
# CLIENT REPORT
# =========================================================

var report_received: bool = false

var report_token: String = ""

var report_passed: bool = false

var report_detail: String = ""


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
	print("[QA] TEST: CREW / ROUND NETWORK AUTHORITY")
	print("[QA] ========================================")


	if not validate_references():

		fail_step(
			1,
			"Required nodes",
			"Missing CrewRound or Health manager"
		)


		finish_failed()

		return


	pass_step(
		1,
		"Required nodes",
		"Crew / Round authority references resolved"
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
# RESET
# =========================================================

func reset_test_state():

	pass_count = 0

	fail_count = 0

	skip_count = 0

	remote_peer_id = 0

	report_received = false

	report_token = ""

	report_passed = false

	report_detail = ""


# =========================================================
# REFERENCES
# =========================================================

func resolve_references():

	var scene = (
		get_tree().current_scene
	)


	if scene == null:
		return


	crew_manager = (
		scene.get_node_or_null(
			"NetworkCrewRoundManager"
		)
	)


	health_manager = (
		scene.get_node_or_null(
			"NetworkPlayerHealthManager"
		)
	)


	if crew_manager == null:

		var crew_nodes: Array = (
			get_tree().get_nodes_in_group(
				"network_crew_round_manager"
			)
		)


		if not crew_nodes.is_empty():

			crew_manager = (
				crew_nodes[0]
			)


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
# VALIDATE
# =========================================================

func validate_references() -> bool:

	if crew_manager == null:
		return false


	if health_manager == null:
		return false


	if not crew_manager.has_method(
		"refresh_authoritative_state"
	):
		return false


	if not crew_manager.has_method(
		"get_crew_state"
	):
		return false


	if not crew_manager.has_method(
		"get_round_state"
	):
		return false


	if not health_manager.has_method(
		"force_unconscious_peer"
	):
		return false


	if not health_manager.has_method(
		"revive_peer"
	):
		return false


	if not health_manager.has_method(
		"force_die_peer"
	):
		return false


	return true


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

	crew_manager.reset_for_qa()


	await get_tree().create_timer(
		0.15
	).timeout


	# =====================================================
	# STEP 03
	# BASELINE
	# =====================================================

	if not await expect_host_state(
		CREW_OPERATIONAL,
		ROUND_RUNNING,
		2,
		0,
		0
	):

		fail_step(
			3,
			"Baseline crew",
			get_host_detail()
		)


		finish_failed()

		return


	if not await expect_client_state(
		CREW_OPERATIONAL,
		ROUND_RUNNING,
		2,
		0,
		0,
		"BASELINE"
	):

		fail_step(
			3,
			"Baseline crew",
			report_detail
		)


		finish_failed()

		return


	pass_step(
		3,
		"Baseline crew",
		"2 ALIVE | OPERATIONAL | RUNNING | synchronized"
	)


	# =====================================================
	# STEP 04
	# HOST UNCONSCIOUS, CLIENT ALIVE
	# =====================================================

	if not health_manager.force_unconscious_peer(
		1
	):

		fail_step(
			4,
			"One unconscious",
			"Could not force Host UNCONSCIOUS"
		)


		finish_failed()

		return


	crew_manager.refresh_authoritative_state()


	if not await expect_host_state(
		CREW_OPERATIONAL,
		ROUND_RUNNING,
		1,
		1,
		0
	):

		fail_step(
			4,
			"One unconscious",
			get_host_detail()
		)


		finish_failed()

		return


	if not await expect_client_state(
		CREW_OPERATIONAL,
		ROUND_RUNNING,
		1,
		1,
		0,
		"ONE_UNCONSCIOUS"
	):

		fail_step(
			4,
			"One unconscious",
			report_detail
		)


		finish_failed()

		return


	pass_step(
		4,
		"One unconscious",
		"1 ALIVE + 1 UNCONSCIOUS keeps round RUNNING"
	)


	# =====================================================
	# STEP 05
	# TODOS UNCONSCIOUS
	# =====================================================

	if not health_manager.force_unconscious_peer(
		remote_peer_id
	):

		fail_step(
			5,
			"Recoverable crew",
			"Could not force Client UNCONSCIOUS"
		)


		finish_failed()

		return


	crew_manager.refresh_authoritative_state()


	if not await expect_host_state(
		CREW_RECOVERABLE,
		ROUND_RUNNING,
		0,
		2,
		0
	):

		fail_step(
			5,
			"Recoverable crew",
			get_host_detail()
		)


		finish_failed()

		return


	if not await expect_client_state(
		CREW_RECOVERABLE,
		ROUND_RUNNING,
		0,
		2,
		0,
		"ALL_UNCONSCIOUS"
	):

		fail_step(
			5,
			"Recoverable crew",
			report_detail
		)


		finish_failed()

		return


	pass_step(
		5,
		"Recoverable crew",
		"0 ALIVE + 2 UNCONSCIOUS = RECOVERABLE / RUNNING"
	)


	# =====================================================
	# STEP 06
	# REVIVE CLIENT
	# =====================================================

	if not health_manager.revive_peer(
		remote_peer_id,
		1.0
	):

		fail_step(
			6,
			"Recovery",
			"Could not revive Client"
		)


		finish_failed()

		return


	crew_manager.refresh_authoritative_state()


	if not await expect_host_state(
		CREW_OPERATIONAL,
		ROUND_RUNNING,
		1,
		1,
		0
	):

		fail_step(
			6,
			"Recovery",
			get_host_detail()
		)


		finish_failed()

		return


	if not await expect_client_state(
		CREW_OPERATIONAL,
		ROUND_RUNNING,
		1,
		1,
		0,
		"RECOVERED"
	):

		fail_step(
			6,
			"Recovery",
			report_detail
		)


		finish_failed()

		return


	pass_step(
		6,
		"Recovery",
		"Reviving one crewmember returns crew to OPERATIONAL"
	)


	# =====================================================
	# STEP 07
	# HOST DEAD, CLIENT ALIVE
	# =====================================================

	if not health_manager.force_die_peer(
		1
	):

		fail_step(
			7,
			"Individual death",
			"Could not force Host DEAD"
		)


		finish_failed()

		return


	crew_manager.refresh_authoritative_state()


	if not await expect_host_state(
		CREW_OPERATIONAL,
		ROUND_RUNNING,
		1,
		0,
		1
	):

		fail_step(
			7,
			"Individual death",
			get_host_detail()
		)


		finish_failed()

		return


	if not await expect_client_state(
		CREW_OPERATIONAL,
		ROUND_RUNNING,
		1,
		0,
		1,
		"ONE_DEAD"
	):

		fail_step(
			7,
			"Individual death",
			report_detail
		)


		finish_failed()

		return


	pass_step(
		7,
		"Individual death",
		"One DEAD player does not end the round"
	)


	# =====================================================
	# STEP 08
	# TODOS DEAD
	# =====================================================

	if not health_manager.force_die_peer(
		remote_peer_id
	):

		fail_step(
			8,
			"All crew dead",
			"Could not force Client DEAD"
		)


		finish_failed()

		return


	crew_manager.refresh_authoritative_state()


	if not await expect_host_state(
		CREW_LOST,
		ROUND_FAILED,
		0,
		0,
		2
	):

		fail_step(
			8,
			"All crew dead",
			get_host_detail()
		)


		finish_failed()

		return


	if (
		crew_manager.get_failure_reason()
		!= "ALL CREW DEAD"
	):

		fail_step(
			8,
			"All crew dead",
			"Unexpected failure reason: "
			+ crew_manager.get_failure_reason()
		)


		finish_failed()

		return


	if not await expect_client_state(
		CREW_LOST,
		ROUND_FAILED,
		0,
		0,
		2,
		"ALL_DEAD"
	):

		fail_step(
			8,
			"All crew dead",
			report_detail
		)


		finish_failed()

		return


	pass_step(
		8,
		"All crew dead",
		"0 ALIVE + 0 UNCONSCIOUS + 2 DEAD = LOST / FAILED"
	)


	# =====================================================
	# FIN
	# =====================================================

	print_summary(
		"HOST"
	)


	qa_client_finish.rpc_id(
		remote_peer_id
	)


	test_finished = true

	test_running = false


# =========================================================
# HOST EXPECTATION
# =========================================================

func expect_host_state(
	expected_crew: String,
	expected_round: String,
	expected_alive: int,
	expected_unconscious: int,
	expected_dead: int
) -> bool:

	var elapsed: float = 0.0


	while elapsed < stage_timeout:

		if (
			crew_manager.get_crew_state()
				== expected_crew
			and crew_manager.get_round_state()
				== expected_round
			and crew_manager.get_alive_count()
				== expected_alive
			and crew_manager.get_unconscious_count()
				== expected_unconscious
			and crew_manager.get_dead_count()
				== expected_dead
		):

			return true


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	return false


# =========================================================
# CLIENT EXPECTATION
# =========================================================

func expect_client_state(
	expected_crew: String,
	expected_round: String,
	expected_alive: int,
	expected_unconscious: int,
	expected_dead: int,
	token: String
) -> bool:

	report_received = false

	report_token = token

	report_passed = false

	report_detail = ""


	qa_client_expect_state.rpc_id(
		remote_peer_id,
		expected_crew,
		expected_round,
		expected_alive,
		expected_unconscious,
		expected_dead,
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
		"Timed out waiting for Client report"
	)


	return false


# =========================================================
# CLIENT EXPECT STATE
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_client_expect_state(
	expected_crew: String,
	expected_round: String,
	expected_alive: int,
	expected_unconscious: int,
	expected_dead: int,
	token: String
):

	if not NetworkManager.is_client():
		return


	resolve_references()


	var elapsed: float = 0.0


	while elapsed < stage_timeout:

		if crew_manager != null:

			var matches: bool = (
				crew_manager.get_crew_state()
					== expected_crew
				and crew_manager.get_round_state()
					== expected_round
				and crew_manager.get_alive_count()
					== expected_alive
				and crew_manager.get_unconscious_count()
					== expected_unconscious
				and crew_manager.get_dead_count()
					== expected_dead
			)


			if matches:

				qa_report_state.rpc_id(
					1,
					token,
					true,
					get_local_detail()
				)


				return


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	qa_report_state.rpc_id(
		1,
		token,
		false,
		get_local_detail()
	)


# =========================================================
# CLIENT -> HOST REPORT
# =========================================================

@rpc(
	"any_peer",
	"call_remote",
	"reliable"
)
func qa_report_state(
	token: String,
	passed: bool,
	detail: String
):

	if not NetworkManager.is_host():
		return


	var sender_id: int = (
		multiplayer.get_remote_sender_id()
	)


	if sender_id != remote_peer_id:
		return


	report_received = true

	report_token = token

	report_passed = passed

	report_detail = detail


# =========================================================
# DETAILS
# =========================================================

func get_host_detail() -> String:

	if crew_manager == null:
		return "Crew manager missing"


	return (
		"Crew="
		+ crew_manager.get_crew_state()
		+ " Round="
		+ crew_manager.get_round_state()
		+ " A="
		+ str(
			crew_manager.get_alive_count()
		)
		+ " U="
		+ str(
			crew_manager.get_unconscious_count()
		)
		+ " D="
		+ str(
			crew_manager.get_dead_count()
		)
	)


func get_local_detail() -> String:

	if crew_manager == null:
		return "Crew manager missing"


	return (
		"Crew="
		+ crew_manager.get_crew_state()
		+ " Round="
		+ crew_manager.get_round_state()
		+ " A="
		+ str(
			crew_manager.get_alive_count()
		)
		+ " U="
		+ str(
			crew_manager.get_unconscious_count()
		)
		+ " D="
		+ str(
			crew_manager.get_dead_count()
		)
	)


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
	print("[QA] CREW / ROUND NETWORK AUTHORITY")
	print("[QA] CLIENT SIDE COMPLETE")
	print("[QA] ========================================")


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
