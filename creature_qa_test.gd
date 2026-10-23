extends Node


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("QA")

@export var start_on_run: bool = false

@export var settle_time: float = 0.18

@export var chase_sample_time: float = 0.40

@export var cooldown_sample_time: float = 0.35

@export var test_depth: float = 100.0


# =========================================================
# REFERENCIAS
# =========================================================

@onready var test_bot = (
	get_parent()
)

@onready var player = (
	get_node_or_null("../../Player")
)

@onready var player_vitals = (
	get_node_or_null("../../Player/Vitals")
)

@onready var player_health = (
	get_node_or_null("../../Player/Health")
)

@onready var creature = (
	get_node_or_null("../../SeaCreature")
)

@onready var submarine_environment = (
	get_node_or_null("../../SubmarineEnvironment")
)

@onready var interior_point = (
	get_node_or_null("../../HatchInteriorPoint")
)

@onready var exterior_point = (
	get_node_or_null("../../HatchExteriorPoint")
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

var original_player_position: Vector2

var original_health: float = 100.0

var original_breath: float = 1.0

var original_depth: float = 0.0

var original_creature_position: Vector2


# =========================================================
# READY
# =========================================================

func _ready():

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
		"[QA] TEST: CREATURE AI"
	)

	print(
		"[QA] ========================================"
	)


	if test_bot != null:

		if test_bot.has_method(
			"set_status"
		):

			test_bot.set_status(
				"CREATURE QA\nRUNNING"
			)


	# =====================================================
	# PRECHECK
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

	prepare_test_environment()


	# =====================================================
	# 01 — IDLE
	# =====================================================

	player.global_position = (
		interior_point.global_position
	)


	await wait_seconds(
		settle_time
		+ 0.15
	)


	if creature.get_state_name() == "IDLE":

		qa_pass(
			"Creature starts IDLE",
			"State = IDLE"
		)

	else:

		qa_fail(
			"Creature starts IDLE",
			"Actual = "
			+ creature.get_state_name()
		)


	# =====================================================
	# 02 — ALERT
	# =====================================================

	player.global_position = Vector2(
		creature.global_position.x - 250.0,
		creature.global_position.y
	)


	await wait_seconds(
		settle_time
	)


	if creature.get_state_name() == "ALERT":

		qa_pass(
			"Target detected",
			"State = ALERT"
		)

	else:

		qa_fail(
			"Target detected",
			"Expected ALERT | Actual "
			+ creature.get_state_name()
		)


	# =====================================================
	# 03 — CHASE
	# =====================================================

	await wait_seconds(
		creature.alert_duration
		+ 0.10
	)


	if creature.get_state_name() == "CHASE":

		qa_pass(
			"Creature enters CHASE",
			"State = CHASE"
		)

	else:

		qa_fail(
			"Creature enters CHASE",
			"Expected CHASE | Actual "
			+ creature.get_state_name()
		)


	# =====================================================
	# 04 — DISTANCIA DISMINUYE
	# =====================================================

	var distance_before: float = (
		creature.get_distance_to_target()
	)


	await wait_seconds(
		chase_sample_time
	)


	var distance_after: float = (
		creature.get_distance_to_target()
	)


	if distance_after < distance_before:

		qa_pass(
			"Chase movement",
			"Distance "
			+ format_float(distance_before)
			+ " -> "
			+ format_float(distance_after)
		)

	else:

		qa_fail(
			"Chase movement",
			"Distance did not decrease | Before "
			+ format_float(distance_before)
			+ " | After "
			+ format_float(distance_after)
		)


	# =====================================================
	# 05 — ATTACK
	# =====================================================

	player_health.current_health = (
		player_health.max_health
	)


	player.global_position = (
		creature.global_position
		+ Vector2(
			25.0,
			0.0
		)
	)


	creature.make_attack_ready_for_qa()


	var health_before_attack: float = (
		player_health.current_health
	)


	await wait_seconds(
		0.20
	)


	if creature.get_state_name() == "ATTACK":

		qa_pass(
			"Attack range detected",
			"State = ATTACK"
		)

	else:

		qa_fail(
			"Attack range detected",
			"Expected ATTACK | Actual "
			+ creature.get_state_name()
		)


	# =====================================================
	# 06 — DAÑO
	# =====================================================

	var health_after_attack: float = (
		player_health.current_health
	)


	if health_after_attack < health_before_attack:

		qa_pass(
			"Player receives damage",
			"Health "
			+ format_float(
				health_before_attack
			)
			+ " -> "
			+ format_float(
				health_after_attack
			)
		)

	else:

		qa_fail(
			"Player receives damage",
			"Expected health loss | Health = "
			+ format_float(
				health_after_attack
			)
		)


	# =====================================================
	# 07 — COOLDOWN
	# =====================================================

	var health_before_cooldown: float = (
		player_health.current_health
	)


	await wait_seconds(
		cooldown_sample_time
	)


	var health_after_cooldown: float = (
		player_health.current_health
	)


	if abs(
		health_after_cooldown
		- health_before_cooldown
	) <= 0.01:

		qa_pass(
			"Attack cooldown respected",
			"No second hit during cooldown"
		)

	else:

		qa_fail(
			"Attack cooldown respected",
			"Unexpected second hit | Health "
			+ format_float(
				health_before_cooldown
			)
			+ " -> "
			+ format_float(
				health_after_cooldown
			)
		)


	# =====================================================
	# 08 — JUGADOR ESCAPA
	# =====================================================

	player.global_position = (
		interior_point.global_position
	)


	await wait_seconds(
		settle_time
		+ 0.10
	)


	var escaped_state: String = (
		creature.get_state_name()
	)


	if (
		escaped_state == "RETURN"
		or escaped_state == "IDLE"
	):

		qa_pass(
			"Target escapes",
			"State = "
			+ escaped_state
		)

	else:

		qa_fail(
			"Target escapes",
			"Expected RETURN/IDLE | Actual "
			+ escaped_state
		)


	# =====================================================
	# 09 — RETURN
	# =====================================================

	var distance_home_before: float = (
		creature.global_position.distance_to(
			creature.get_home_position()
		)
	)


	await wait_seconds(
		0.40
	)


	var distance_home_after: float = (
		creature.global_position.distance_to(
			creature.get_home_position()
		)
	)


	if (
		distance_home_after < distance_home_before
		or creature.get_state_name() == "IDLE"
	):

		qa_pass(
			"Creature returns home",
			"Distance "
			+ format_float(
				distance_home_before
			)
			+ " -> "
			+ format_float(
				distance_home_after
			)
		)

	else:

		qa_fail(
			"Creature returns home",
			"Distance did not decrease"
		)


	restore_state()

	finish_suite()


# =========================================================
# VALIDAR NODOS
# =========================================================

func validate_required_nodes() -> bool:

	var required_nodes: Array = [
		player,
		player_vitals,
		player_health,
		creature,
		submarine_environment,
		interior_point,
		exterior_point
	]


	for node in required_nodes:

		if node == null:
			return false


	return true


# =========================================================
# BACKUP
# =========================================================

func backup_state():

	original_player_position = (
		player.global_position
	)

	original_health = (
		player_health.current_health
	)

	original_breath = (
		player_vitals.breath_level
	)

	original_depth = float(
		submarine_environment.get(
			"depth_meters"
		)
	)

	original_creature_position = (
		creature.global_position
	)


# =========================================================
# PREPARAR
# =========================================================

func prepare_test_environment():

	set_depth(
		test_depth
	)

	player_health.current_health = (
		player_health.max_health
	)

	player_vitals.breath_level = 1.0


	creature.reset_for_qa(
		original_creature_position
	)


# =========================================================
# RESTAURAR
# =========================================================

func restore_state():

	player.global_position = (
		original_player_position
	)

	if player is CharacterBody2D:

		player.velocity = Vector2.ZERO


	player_health.current_health = (
		original_health
	)

	player_vitals.breath_level = (
		original_breath
	)


	set_depth(
		original_depth
	)


	creature.reset_for_qa(
		original_creature_position
	)


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


	var text: String = (
		"[QA][STEP "
		+ format_step(step_number)
		+ "][PASS] "
		+ test_name
	)


	if not detail.is_empty():

		text += (
			" | "
			+ detail
		)


	print(text)


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
		+ format_step(step_number)
		+ "][FAIL] "
		+ test_name
	)


	if not detail.is_empty():

		text += (
			" | "
			+ detail
		)


	print(text)


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
		+ format_step(step_number)
		+ "][SKIP] "
		+ test_name
	)


	if not detail.is_empty():

		text += (
			" | "
			+ detail
		)


	print(text)


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


	if failed_steps == 0:

		print(
			"[QA] RESULT: TEST PASSED"
		)

		if test_bot != null:

			if test_bot.has_method(
				"set_status"
			):

				test_bot.set_status(
					"CREATURE QA\nPASS\n"
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
					"CREATURE QA\nFAIL\n"
					+ str(failed_steps)
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
			+ str(value)
		)


	return str(value)


func format_float(
	value: float
) -> String:

	return str(
		snapped(
			value,
			0.01
		)
	)
