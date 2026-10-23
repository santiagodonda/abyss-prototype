extends Node


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("QA")

@export var start_on_run: bool = false

@export var settle_time: float = 0.20


# =========================================================
# REFERENCIAS
# =========================================================

@onready var test_bot = (
	get_parent()
)


@onready var mission_state = (
	get_node_or_null(
		"../../MissionState"
	)
)


@onready var mission_objective = (
	get_node_or_null(
		"../../MissionObjective"
	)
)


@onready var encounter_manager = (
	get_node_or_null(
		"../../EncounterManager"
	)
)


@onready var submarine_environment = (
	get_node_or_null(
		"../../SubmarineEnvironment"
	)
)


@onready var hull_breach = (
	get_node_or_null(
		"../../HullBreach"
	)
)


@onready var hull_integrity = (
	get_node_or_null(
		"../../HullIntegrityPoint"
	)
)


@onready var room_left = (
	get_node_or_null(
		"../../RoomLeft"
	)
)


@onready var room_right = (
	get_node_or_null(
		"../../RoomRight"
	)
)


# =========================================================
# QA STATE
# =========================================================

var running: bool = false

var step_number: int = 0

var passed_steps: int = 0

var failed_steps: int = 0

var skipped_steps: int = 0


# =========================================================
# BACKUP
# =========================================================

var original_depth: float = 0.0

var original_attack_submarine: bool = true

var original_left_water: float = 0.0

var original_right_water: float = 0.0

var original_left_pressure: float = 1.0

var original_right_pressure: float = 1.0

var original_breach_repaired: bool = false

var original_hull_integrity: float = 100.0

var original_hull_breached: bool = false

var original_objective_auto_start: bool = true


# =========================================================
# READY
# =========================================================

func _ready():

	# Este QA necesita poder continuar después
	# de que MissionState pause el juego por SUCCESS.
	process_mode = Node.PROCESS_MODE_ALWAYS


	if start_on_run:

		call_deferred(
			"run_suite"
		)


# =========================================================
# RUN
# =========================================================

func run_suite():

	if running:
		return


	running = true


	step_number = 0

	passed_steps = 0

	failed_steps = 0

	skipped_steps = 0


	print("")

	print(
		"[QA] ========================================"
	)

	print(
		"[QA] TEST: MISSION SUCCESS"
	)

	print(
		"[QA] ========================================"
	)


	if (
		test_bot != null
		and test_bot.has_method(
			"set_status"
		)
	):

		test_bot.set_status(
			"MISSION QA\nRUNNING"
		)


	# =====================================================
	# REQUIRED
	# =====================================================

	if not validate_required_nodes():

		qa_fail(
			"Required nodes",
			"One or more references are missing"
		)

		finish_suite()

		return


	qa_pass(
		"Required nodes",
		"All references resolved"
	)


	backup_state()

	prepare_environment()


	# =====================================================
	# MISSION RUNNING
	# =====================================================

	if mission_state.is_running():

		qa_pass(
			"Mission starts running",
			"State = RUNNING"
		)

	else:

		qa_fail(
			"Mission starts running",
			"State = "
			+ mission_state.get_state_name()
		)


	# =====================================================
	# TRAVEL STAGE
	# =====================================================

	if (
		mission_objective.get_stage_name()
		== "TRAVEL"
	):

		qa_pass(
			"Travel objective active",
			"Stage = TRAVEL"
		)

	else:

		qa_fail(
			"Travel objective active",
			"Stage = "
			+ mission_objective.get_stage_name()
		)


	# =====================================================
	# BELOW TARGET
	# =====================================================

	await wait_seconds(
		settle_time
	)


	if (
		not encounter_manager.is_encounter_active()
		and mission_objective.get_stage_name()
		== "TRAVEL"
	):

		qa_pass(
			"Encounter waits for target depth",
			"No encounter below target depth"
		)

	else:

		qa_fail(
			"Encounter waits for target depth",
			"Encounter started too early"
		)


	# =====================================================
	# REACH TARGET DEPTH
	# =====================================================

	set_depth(
		mission_objective.get_target_depth()
	)


	await wait_seconds(
		settle_time
	)


	if (
		mission_objective.get_stage_name()
		== "ENCOUNTER"
		and encounter_manager.is_encounter_active()
	):

		qa_pass(
			"Target depth starts encounter",
			"Stage = ENCOUNTER"
		)

	else:

		qa_fail(
			"Target depth starts encounter",
			"Stage = "
			+ mission_objective.get_stage_name()
		)


	# =====================================================
	# ENCOUNTER COUNT
	# =====================================================

	var encounter_creatures: Array = (
		encounter_manager.get_creatures()
	)


	if (
		encounter_creatures.size()
		== mission_objective.encounter_creature_count
	):

		qa_pass(
			"Mission encounter spawned",
			"Creatures = "
			+ str(
				encounter_creatures.size()
			)
		)

	else:

		qa_fail(
			"Mission encounter spawned",
			"Expected "
			+ str(
				mission_objective.encounter_creature_count
			)
			+ " | Actual "
			+ str(
				encounter_creatures.size()
			)
		)


	# =====================================================
	# MISSION NO TERMINA ANTES
	# =====================================================

	if mission_state.is_running():

		qa_pass(
			"Mission remains running during encounter",
			"State = RUNNING"
		)

	else:

		qa_fail(
			"Mission remains running during encounter",
			"State = "
			+ mission_state.get_state_name()
		)


	# =====================================================
	# ELIMINAR ENEMIGOS
	# =====================================================

	for creature in encounter_creatures:

		if not is_instance_valid(
			creature
		):

			continue


		creature.apply_damage(
			creature.max_health
			+ 100.0,
			&"qa_mission_success"
		)


	await wait_seconds(
		0.10
	)


	if encounter_manager.get_alive_count() == 0:

		qa_pass(
			"Mission enemies defeated",
			"Alive count = 0"
		)

	else:

		qa_fail(
			"Mission enemies defeated",
			"Alive count = "
			+ str(
				encounter_manager.get_alive_count()
			)
		)


	# =====================================================
	# ENCOUNTER COMPLETE
	# =====================================================

	await wait_seconds(
		0.15
	)


	if encounter_manager.is_encounter_complete():

		qa_pass(
			"Mission encounter completes",
			"Encounter = COMPLETE"
		)

	else:

		qa_fail(
			"Mission encounter completes",
			"Encounter did not complete"
		)


	# =====================================================
	# MISSION SUCCESS
	# =====================================================

	await wait_seconds(
		0.15
	)


	if mission_state.is_success():

		qa_pass(
			"Mission reaches SUCCESS",
			"State = SUCCESS"
		)

	else:

		qa_fail(
			"Mission reaches SUCCESS",
			"State = "
			+ mission_state.get_state_name()
		)


	# =====================================================
	# OBJECTIVE COMPLETE
	# =====================================================

	if mission_objective.is_complete():

		qa_pass(
			"Objective completes",
			"Stage = COMPLETE"
		)

	else:

		qa_fail(
			"Objective completes",
			"Stage = "
			+ mission_objective.get_stage_name()
		)


	# =====================================================
	# SUCCESS UI
	# =====================================================

	if mission_state.is_success_ui_visible():

		qa_pass(
			"Success UI visible",
			"MISSION COMPLETE overlay visible"
		)

	else:

		qa_fail(
			"Success UI visible",
			"Success overlay hidden"
		)


	# =====================================================
	# SIMULATION PAUSED
	# =====================================================

	if get_tree().paused:

		qa_pass(
			"Success pauses simulation",
			"SceneTree paused"
		)

	else:

		qa_fail(
			"Success pauses simulation",
			"SceneTree still running"
		)


	# =====================================================
	# RESET
	# =====================================================

	get_tree().paused = false


	mission_state.reset_for_qa()


	mission_objective.reset_for_qa(
		false
	)


	if (
		not get_tree().paused
		and mission_state.is_running()
		and not mission_state.is_success_ui_visible()
	):

		qa_pass(
			"Mission can reset",
			"RUNNING | UI hidden | unpaused"
		)

	else:

		qa_fail(
			"Mission can reset",
			"Reset state invalid"
		)


	restore_state()

	finish_suite()


# =========================================================
# REQUIRED NODES
# =========================================================

func validate_required_nodes() -> bool:

	var required_nodes: Array = [
		mission_state,
		mission_objective,
		encounter_manager,
		submarine_environment,
		hull_breach,
		hull_integrity,
		room_left,
		room_right
	]


	for node in required_nodes:

		if node == null:
			return false


	return true


# =========================================================
# BACKUP
# =========================================================

func backup_state():

	original_depth = float(
		submarine_environment.get(
			"depth_meters"
		)
	)


	original_attack_submarine = (
		encounter_manager.attack_submarine
	)


	original_left_water = (
		room_left.water_level
	)


	original_right_water = (
		room_right.water_level
	)


	original_left_pressure = (
		room_left.pressure
	)


	original_right_pressure = (
		room_right.pressure
	)


	original_breach_repaired = (
		hull_breach.is_repaired()
	)


	original_hull_integrity = (
		hull_integrity.get_integrity()
	)


	original_hull_breached = (
		hull_integrity.is_breached()
	)


	original_objective_auto_start = (
		mission_objective.auto_start_on_run
	)


# =========================================================
# PREPARAR
# =========================================================

func prepare_environment():

	get_tree().paused = false


	mission_state.reset_for_qa()


	mission_objective.reset_for_qa(
		false
	)


	encounter_manager.stop_encounter(
		true
	)


	# Este QA prueba flujo de misión.
	# Hull Combat ya fue probado aparte.
	#
	# Evitamos que las criaturas destruyan
	# el submarino mientras validamos SUCCESS.
	encounter_manager.attack_submarine = false


	hull_breach.repair_instant()


	hull_integrity.reset_for_qa(
		100.0
	)


	room_left.set_water_level(
		0.0
	)


	room_right.set_water_level(
		0.0
	)


	room_left.set_pressure(
		1.0
	)


	room_right.set_pressure(
		1.0
	)


	set_depth(
		mission_objective.get_target_depth()
		- 100.0
	)


	mission_objective.start_mission()


# =========================================================
# RESTAURAR
# =========================================================

func restore_state():

	get_tree().paused = false


	encounter_manager.stop_encounter(
		true
	)


	encounter_manager.attack_submarine = (
		original_attack_submarine
	)


	mission_objective.reset_for_qa(
		false
	)


	mission_state.reset_for_qa()


	set_depth(
		original_depth
	)


	room_left.set_water_level(
		original_left_water
	)


	room_right.set_water_level(
		original_right_water
	)


	room_left.set_pressure(
		original_left_pressure
	)


	room_right.set_pressure(
		original_right_pressure
	)


	# -----------------------------------------------------
	# RESTAURAR CASCO
	# -----------------------------------------------------

	hull_breach.repair_instant()


	hull_integrity.reset_for_qa(
		original_hull_integrity
	)


	if original_hull_breached:

		hull_integrity.trigger_hull_failure()


	elif not original_breach_repaired:

		hull_breach.trigger_breach()


	# -----------------------------------------------------
	# RESTAURAR MISIÓN NORMAL
	# -----------------------------------------------------

	if original_objective_auto_start:

		mission_objective.start_mission()


# =========================================================
# DEPTH
# =========================================================

func set_depth(
	value: float
):

	if submarine_environment.has_method(
		"set_depth"
	):

		submarine_environment.set_depth(
			value
		)

	else:

		submarine_environment.set(
			"depth_meters",
			value
		)


# =========================================================
# WAIT
# =========================================================

func wait_seconds(
	seconds: float
):

	await get_tree().create_timer(
		seconds
	).timeout


# =========================================================
# PASS
# =========================================================

func qa_pass(
	test_name: String,
	detail: String = ""
):

	step_number += 1

	passed_steps += 1


	print(
		build_log(
			"PASS",
			test_name,
			detail
		)
	)


# =========================================================
# FAIL
# =========================================================

func qa_fail(
	test_name: String,
	detail: String = ""
):

	step_number += 1

	failed_steps += 1


	print(
		build_log(
			"FAIL",
			test_name,
			detail
		)
	)


# =========================================================
# SKIP
# =========================================================

func qa_skip(
	test_name: String,
	detail: String = ""
):

	step_number += 1

	skipped_steps += 1


	print(
		build_log(
			"SKIP",
			test_name,
			detail
		)
	)


# =========================================================
# LOG
# =========================================================

func build_log(
	result: String,
	test_name: String,
	detail: String
) -> String:

	var text: String = (
		"[QA][STEP "
		+ format_step(
			step_number
		)
		+ "]["
		+ result
		+ "] "
		+ test_name
	)


	if not detail.is_empty():

		text += (
			" | "
			+ detail
		)


	return text


# =========================================================
# FIN
# =========================================================

func finish_suite():

	print(
		"[QA] ----------------------------------------"
	)


	print(
		"[QA] SUMMARY"
	)


	print(
		"[QA] PASS: ",
		passed_steps
	)


	print(
		"[QA] FAIL: ",
		failed_steps
	)


	print(
		"[QA] SKIP: ",
		skipped_steps
	)


	if failed_steps == 0:

		print(
			"[QA] RESULT: TEST PASSED"
		)


		if (
			test_bot != null
			and test_bot.has_method(
				"set_status"
			)
		):

			test_bot.set_status(
				"MISSION QA\nPASS\n"
				+ str(
					passed_steps
				)
				+ " PASS"
			)


	else:

		print(
			"[QA] RESULT: TEST FAILED"
		)


		if (
			test_bot != null
			and test_bot.has_method(
				"set_status"
			)
		):

			test_bot.set_status(
				"MISSION QA\nFAIL\n"
				+ str(
					failed_steps
				)
				+ " FAIL"
			)


	print(
		"[QA] ========================================"
	)


	print("")


	running = false


# =========================================================
# FORMAT
# =========================================================

func format_step(
	value: int
) -> String:

	if value < 10:

		return (
			"0"
			+ str(
				value
			)
		)


	return str(
		value
	)
