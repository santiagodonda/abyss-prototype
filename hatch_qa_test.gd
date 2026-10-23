extends Node


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("QA")

@export var start_on_run: bool = false

@export var settle_time: float = 0.35


# =========================================================
# REFERENCIAS
# =========================================================

@onready var test_bot = (
	get_parent()
)


@onready var player = (
	get_node_or_null(
		"../../Player"
	)
)


@onready var player_vitals = (
	get_node_or_null(
		"../../Player/Vitals"
	)
)


@onready var player_health = (
	get_node_or_null(
		"../../Player/Health"
	)
)


@onready var exterior_hatch = (
	get_node_or_null(
		"../../ExteriorHatch"
	)
)


@onready var interior_point = (
	get_node_or_null(
		"../../HatchInteriorPoint"
	)
)


@onready var exterior_point = (
	get_node_or_null(
		"../../HatchExteriorPoint"
	)
)


# =========================================================
# QA STATE
# =========================================================

var is_running: bool = false

var step_number: int = 0

var passed_steps: int = 0

var failed_steps: int = 0

var skipped_steps: int = 0


# =========================================================
# BACKUP
# =========================================================

var original_player_position: Vector2

var original_player_health: float = 100.0

var original_breath: float = 1.0


# =========================================================
# READY
# =========================================================

func _ready():

	if start_on_run:

		call_deferred(
			"run_suite"
		)


# =========================================================
# TEST
# =========================================================

func run_suite():

	if is_running:
		return


	is_running = true


	step_number = 0

	passed_steps = 0

	failed_steps = 0

	skipped_steps = 0


	print("")

	print(
		"[QA] ========================================"
	)

	print(
		"[QA] TEST: EXTERIOR HATCH"
	)

	print(
		"[QA] ========================================"
	)


	if test_bot != null:

		if test_bot.has_method(
			"set_status"
		):

			test_bot.set_status(
				"HATCH QA\nRUNNING"
			)


	# -----------------------------------------------------
	# PRECHECK
	# -----------------------------------------------------

	if not validate_required_nodes():

		qa_fail(
			"Required nodes",
			"One or more references are missing"
		)

		qa_skip(
			"Interior setup",
			"Precheck failed"
		)

		qa_skip(
			"Exit through hatch",
			"Precheck failed"
		)

		qa_skip(
			"Exterior detection",
			"Precheck failed"
		)

		qa_skip(
			"Return through hatch",
			"Precheck failed"
		)

		qa_skip(
			"Interior detection",
			"Precheck failed"
		)

		finish_suite()

		return


	qa_pass(
		"Required nodes",
		"All references resolved"
	)


	backup_state()


	# =====================================================
	# POSICIÓN INICIAL INTERIOR
	# =====================================================

	player.global_position = (
		interior_point.global_position
	)


	if player is CharacterBody2D:

		player.velocity = (
			Vector2.ZERO
		)


	await wait_seconds(
		settle_time
	)


	if not player_vitals.is_exterior():

		qa_pass(
			"Interior setup",
			"Room = "
			+ player_vitals.get_room_id()
		)

	else:

		qa_fail(
			"Interior setup",
			"Expected interior but detected EXTERIOR"
		)


	# =====================================================
	# SALIR POR ESCOTILLA
	# =====================================================

	exterior_hatch.interact(
		player
	)


	await wait_seconds(
		settle_time
	)


	var exit_distance: float = (
		player.global_position.distance_to(
			exterior_point.global_position
		)
	)


	if exit_distance <= 2.0:

		qa_pass(
			"Exit through hatch",
			"Player reached exterior point"
		)

	else:

		qa_fail(
			"Exit through hatch",
			"Distance from exterior point = "
			+ format_float(
				exit_distance
			)
		)


	if player_vitals.is_exterior():

		qa_pass(
			"Exterior detection",
			"Environment = EXTERIOR"
		)

	else:

		qa_fail(
			"Exterior detection",
			"Expected EXTERIOR | Actual "
			+ player_vitals.get_room_id()
		)


	# =====================================================
	# VOLVER POR ESCOTILLA
	# =====================================================

	exterior_hatch.interact(
		player
	)


	await wait_seconds(
		settle_time
	)


	var return_distance: float = (
		player.global_position.distance_to(
			interior_point.global_position
		)
	)


	if return_distance <= 2.0:

		qa_pass(
			"Return through hatch",
			"Player reached interior point"
		)

	else:

		qa_fail(
			"Return through hatch",
			"Distance from interior point = "
			+ format_float(
				return_distance
			)
		)


	if not player_vitals.is_exterior():

		qa_pass(
			"Interior detection",
			"Room = "
			+ player_vitals.get_room_id()
		)

	else:

		qa_fail(
			"Interior detection",
			"Player remained EXTERIOR"
		)


	restore_state()

	finish_suite()


# =========================================================
# VALIDACIONES
# =========================================================

func validate_required_nodes() -> bool:

	var required_nodes: Array = [
		player,
		player_vitals,
		player_health,
		exterior_hatch,
		interior_point,
		exterior_point
	]


	for node in required_nodes:

		if node == null:
			return false


	return true


# =========================================================
# BACKUP / RESTORE
# =========================================================

func backup_state():

	original_player_position = (
		player.global_position
	)


	original_player_health = (
		player_health.current_health
	)


	original_breath = (
		player_vitals.breath_level
	)


func restore_state():

	player.global_position = (
		original_player_position
	)


	if player is CharacterBody2D:

		player.velocity = (
			Vector2.ZERO
		)


	player_health.current_health = (
		original_player_health
	)


	player_vitals.breath_level = (
		original_breath
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


	var text: String = (
		"[QA][STEP "
		+ format_step(
			step_number
		)
		+ "][PASS] "
		+ test_name
	)


	if not detail.is_empty():

		text += (
			" | "
			+ detail
		)


	print(
		text
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


	var text: String = (
		"[QA][STEP "
		+ format_step(
			step_number
		)
		+ "][FAIL] "
		+ test_name
	)


	if not detail.is_empty():

		text += (
			" | "
			+ detail
		)


	print(
		text
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


	var text: String = (
		"[QA][STEP "
		+ format_step(
			step_number
		)
		+ "][SKIP] "
		+ test_name
	)


	if not detail.is_empty():

		text += (
			" | "
			+ detail
		)


	print(
		text
	)


# =========================================================
# FINAL
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


	if failed_steps <= 0:

		print(
			"[QA] RESULT: TEST PASSED"
		)


		if test_bot != null:

			if test_bot.has_method(
				"set_status"
			):

				test_bot.set_status(
					"HATCH QA\nPASS\n"
					+ str(passed_steps)
					+ " PASS"
				)

	else:

		print(
			"[QA] RESULT: TEST FAILED"
		)


		if test_bot != null:

			if test_bot.has_method(
				"set_status"
			):

				test_bot.set_status(
					"HATCH QA\nFAIL\n"
					+ str(failed_steps)
					+ " FAIL"
				)


	print(
		"[QA] ========================================"
	)

	print("")


	is_running = false


# =========================================================
# FORMAT
# =========================================================

func format_step(
	value: int
) -> String:

	if value < 10:

		return (
			"0"
			+ str(value)
		)


	return str(
		value
	)


func format_float(
	value: float
) -> String:

	return str(
		snapped(
			value,
			0.01
		)
	)
