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
# REFERENCES
# =========================================================

var mission_manager = null

var mission_state = null

var mission_objective = null

var submarine_status = null

var crew_manager = null

var health_manager = null


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
# CLIENT REPORT
# =========================================================

var report_received: bool = false

var report_token: String = ""

var report_passed: bool = false

var report_detail: String = ""


# =========================================================
# ENV GUARD
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


	print("")
	print("[QA] ========================================")
	print("[QA] TEST: MISSION NETWORK AUTHORITY")
	print("[QA] ========================================")


	if not validate_references():

		fail_step(
			1,
			"Required nodes",
			"Mission network references missing"
		)


		finish_failed()

		return


	pass_step(
		1,
		"Required nodes",
		"Mission authority references resolved"
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


# =========================================================
# VALIDATE
# =========================================================

func validate_references() -> bool:

	return (
		mission_manager != null
		and mission_state != null
		and mission_objective != null
		and submarine_status != null
		and crew_manager != null
		and health_manager != null
	)


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
	# STEP 03 — BASELINE
	# =====================================================

	if not await wait_host_state(
		"RUNNING",
		"TRAVEL"
	):

		fail_step(
			3,
			"Baseline mission",
			get_local_detail()
		)


		finish_failed()

		return


	mission_manager.force_sync_for_qa()


	if not await expect_client_state(
		"RUNNING",
		"TRAVEL",
		"BASELINE"
	):

		fail_step(
			3,
			"Baseline mission",
			report_detail
		)


		finish_failed()

		return


	pass_step(
		3,
		"Baseline mission",
		"RUNNING / TRAVEL synchronized"
	)


	# =====================================================
	# STEP 04 — CLIENT CANNOT MUTATE
	# =====================================================

	if not await client_attempt_illegal_mutation():

		fail_step(
			4,
			"Client authority rejection",
			report_detail
		)


		finish_failed()

		return


	if (
		mission_state.get_state_name()
		!= "RUNNING"
		or mission_objective.get_stage_name()
		!= "TRAVEL"
	):

		fail_step(
			4,
			"Client authority rejection",
			"Host state changed after Client mutation attempt"
		)


		finish_failed()

		return


	pass_step(
		4,
		"Client authority rejection",
		"Client cannot impose FAILED or COMPLETE"
	)


	# =====================================================
	# STEP 05 — ENCOUNTER REPLICATION
	# =====================================================

	mission_objective.set_stage(
		2
	)


	mission_manager.force_sync_for_qa()


	if not await expect_client_state(
		"RUNNING",
		"ENCOUNTER",
		"ENCOUNTER"
	):

		fail_step(
			5,
			"Objective replication",
			report_detail
		)


		finish_failed()

		return


	pass_step(
		5,
		"Objective replication",
		"Host ENCOUNTER replicated to Client"
	)


	# =====================================================
	# STEP 06 — SNAPSHOT RESTORES CLIENT
	# =====================================================

	if not await poison_client_state():

		fail_step(
			6,
			"Snapshot recovery",
			report_detail
		)


		finish_failed()

		return


	mission_manager.send_snapshot(
		remote_peer_id
	)


	if not await expect_client_state(
		"RUNNING",
		"ENCOUNTER",
		"SNAPSHOT_RESTORE"
	):

		fail_step(
			6,
			"Snapshot recovery",
			report_detail
		)


		finish_failed()

		return


	pass_step(
		6,
		"Snapshot recovery",
		"Authoritative snapshot restored poisoned Client state"
	)


	# =====================================================
	# STEP 07 — SUCCESS
	# =====================================================

	mission_objective.set_stage(
		3
	)


	mission_state.complete_mission(
		"QA SUCCESS"
	)


	mission_manager.force_sync_for_qa()


	if not await wait_host_state(
		"SUCCESS",
		"COMPLETE"
	):

		fail_step(
			7,
			"Mission success",
			get_local_detail()
		)


		finish_failed()

		return


	if not await expect_client_state(
		"SUCCESS",
		"COMPLETE",
		"SUCCESS"
	):

		fail_step(
			7,
			"Mission success",
			report_detail
		)


		finish_failed()

		return


	if not mission_manager.is_restart_allowed():

		fail_step(
			7,
			"Mission success",
			"Restart policy did not open after SUCCESS"
		)


		finish_failed()

		return


	pass_step(
		7,
		"Mission success",
		"SUCCESS / COMPLETE synchronized | restart policy open"
	)


	# =====================================================
	# RESET FOR FAILURE TEST
	# =====================================================

	mission_state.reset_for_qa()

	mission_objective.reset_for_qa(
		true
	)


	mission_manager.force_sync_for_qa()


	if not await expect_client_state(
		"RUNNING",
		"TRAVEL",
		"RESET_AFTER_SUCCESS"
	):

		fail_step(
			8,
			"Submarine failure",
			"Could not restore RUNNING baseline"
		)


		finish_failed()

		return


	# =====================================================
	# STEP 08 — SUBMARINE LOST
	# =====================================================

	submarine_status.set_process(
		false
	)


	submarine_status.current_state = 4


	if not await wait_host_mission_state(
		"FAILED"
	):

		fail_step(
			8,
			"Submarine failure",
			"Host did not fail mission after LOST"
		)


		finish_failed()

		return


	mission_manager.force_sync_for_qa()


	if not await expect_client_state(
		"FAILED",
		"TRAVEL",
		"SUBMARINE_LOST"
	):

		fail_step(
			8,
			"Submarine failure",
			report_detail
		)


		finish_failed()

		return


	if (
		mission_state.get_failure_reason()
		!= "SUBMARINE LOST"
	):

		fail_step(
			8,
			"Submarine failure",
			"Unexpected reason: "
			+ mission_state.get_failure_reason()
		)


		finish_failed()

		return


	pass_step(
		8,
		"Submarine failure",
		"Host LOST caused synchronized FAILED"
	)


	# =====================================================
	# RESET FOR CREW TEST
	# =====================================================

	submarine_status.current_state = 0

	submarine_status.lost_condition_timer = 0.0

	submarine_status.set_process(
		true
	)


	mission_state.reset_for_qa()

	mission_objective.reset_for_qa(
		true
	)


	mission_manager.force_sync_for_qa()


	if not await expect_client_state(
		"RUNNING",
		"TRAVEL",
		"RESET_FOR_CREW"
	):

		fail_step(
			9,
			"Crew failure integration",
			"Could not restore second baseline"
		)


		finish_failed()

		return


	# =====================================================
	# STEP 09 — ALL CREW DEAD
	# =====================================================

	health_manager.force_die_peer(
		1
	)


	health_manager.force_die_peer(
		remote_peer_id
	)


	if not await wait_crew_failed():

		fail_step(
			9,
			"Crew failure integration",
			"CrewRound did not reach FAILED"
		)


		finish_failed()

		return


	if not await wait_host_mission_state(
		"FAILED"
	):

		fail_step(
			9,
			"Crew failure integration",
			"Mission did not consume CrewRound FAILED"
		)


		finish_failed()

		return


	mission_manager.force_sync_for_qa()


	if not await expect_client_state(
		"FAILED",
		"TRAVEL",
		"CREW_FAILED"
	):

		fail_step(
			9,
			"Crew failure integration",
			report_detail
		)


		finish_failed()

		return


	if (
		mission_state.get_failure_reason()
		!= "ALL CREW DEAD"
	):

		fail_step(
			9,
			"Crew failure integration",
			"Unexpected reason: "
			+ mission_state.get_failure_reason()
		)


		finish_failed()

		return


	pass_step(
		9,
		"Crew failure integration",
		"ALL CREW DEAD caused synchronized mission FAILED"
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
# WAIT HOST STATE
# =========================================================

func wait_host_state(
	expected_mission: String,
	expected_stage: String
) -> bool:

	var elapsed: float = 0.0


	while elapsed < stage_timeout:

		if (
			mission_state.get_state_name()
				== expected_mission
			and mission_objective.get_stage_name()
				== expected_stage
		):

			return true


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	return false


func wait_host_mission_state(
	expected_mission: String
) -> bool:

	var elapsed: float = 0.0


	while elapsed < stage_timeout:

		if (
			mission_state.get_state_name()
			== expected_mission
		):

			return true


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	return false


func wait_crew_failed() -> bool:

	var elapsed: float = 0.0


	while elapsed < stage_timeout:

		if crew_manager.is_round_failed():
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
	expected_mission: String,
	expected_stage: String,
	token: String
) -> bool:

	report_received = false

	report_token = token

	report_passed = false

	report_detail = ""


	qa_client_expect_state.rpc_id(
		remote_peer_id,
		expected_mission,
		expected_stage,
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
		"Timed out waiting for Client state"
	)


	return false


@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_client_expect_state(
	expected_mission: String,
	expected_stage: String,
	token: String
):

	if not NetworkManager.is_client():
		return


	resolve_references()


	var elapsed: float = 0.0


	while elapsed < stage_timeout:

		if (
			mission_state != null
			and mission_objective != null
		):

			if (
				mission_state.get_state_name()
					== expected_mission
				and mission_objective.get_stage_name()
					== expected_stage
			):

				qa_report.rpc_id(
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


	qa_report.rpc_id(
		1,
		token,
		false,
		get_local_detail()
	)


# =========================================================
# ILLEGAL CLIENT MUTATION
# =========================================================

func client_attempt_illegal_mutation() -> bool:

	report_received = false

	report_token = "ILLEGAL_MUTATION"

	report_passed = false

	report_detail = ""


	qa_client_attempt_illegal_mutation.rpc_id(
		remote_peer_id
	)


	return await wait_report(
		"ILLEGAL_MUTATION"
	)


@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_client_attempt_illegal_mutation():

	if not NetworkManager.is_client():
		return


	resolve_references()


	mission_state.fail_mission(
		"CLIENT INJECTION"
	)


	mission_objective.set_stage(
		3
	)


	await get_tree().create_timer(
		0.20
	).timeout


	var passed: bool = (
		mission_state.get_state_name()
			== "RUNNING"
		and mission_objective.get_stage_name()
			== "TRAVEL"
	)


	qa_report.rpc_id(
		1,
		"ILLEGAL_MUTATION",
		passed,
		get_local_detail()
	)


# =========================================================
# POISON CLIENT
# =========================================================

func poison_client_state() -> bool:

	report_received = false

	report_token = "POISON"

	report_passed = false

	report_detail = ""


	qa_client_poison_state.rpc_id(
		remote_peer_id
	)


	return await wait_report(
		"POISON"
	)


@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_client_poison_state():

	if not NetworkManager.is_client():
		return


	resolve_references()


	mission_state.apply_network_state(
		"RUNNING",
		"",
		""
	)


	mission_objective.apply_network_stage(
		"IDLE",
		false
	)


	var passed: bool = (
		mission_state.get_state_name()
			== "RUNNING"
		and mission_objective.get_stage_name()
			== "IDLE"
	)


	qa_report.rpc_id(
		1,
		"POISON",
		passed,
		get_local_detail()
	)


# =========================================================
# WAIT REPORT
# =========================================================

func wait_report(
	token: String
) -> bool:

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
# REPORT
# =========================================================

@rpc(
	"any_peer",
	"call_remote",
	"reliable"
)
func qa_report(
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
# DETAIL
# =========================================================

func get_local_detail() -> String:

	if (
		mission_state == null
		or mission_objective == null
	):

		return "Mission references missing"


	return (
		"Mission="
		+ mission_state.get_state_name()
		+ " Objective="
		+ mission_objective.get_stage_name()
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
	print("[QA] MISSION NETWORK AUTHORITY")
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
# PASS / FAIL
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
