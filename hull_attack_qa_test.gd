extends Node


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("QA")

@export var start_on_run: bool = false

@export var test_depth: float = 100.0

@export var settle_time: float = 0.20

@export var timeout: float = 4.0


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


@onready var creature = (
	get_node_or_null(
		"../../SeaCreature"
	)
)


@onready var hull_integrity = (
	get_node_or_null(
		"../../HullIntegrityPoint"
	)
)


@onready var hull_breach = (
	get_node_or_null(
		"../../HullBreach"
	)
)


@onready var room_right = (
	get_node_or_null(
		"../../RoomRight"
	)
)


@onready var submarine_environment = (
	get_node_or_null(
		"../../SubmarineEnvironment"
	)
)


@onready var submarine_status = (
	get_node_or_null(
		"../../SubmarineStatus"
	)
)


@onready var interior_point = (
	get_node_or_null(
		"../../HatchInteriorPoint"
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

var original_player_position: Vector2

var original_creature_position: Vector2

var original_depth: float

var original_water: float

var original_pressure: float

var original_integrity: float

var original_breach_repaired: bool

var original_attack_submarine_enabled: bool

var original_hull_damage: float

var original_attack_cooldown: float

var original_movement_speed: float

var original_alert_duration: float


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
		"[QA] TEST: HULL COMBAT"
	)

	print(
		"[QA] ========================================"
	)


	if test_bot != null:

		if test_bot.has_method(
			"set_status"
		):

			test_bot.set_status(
				"HULL QA\nRUNNING"
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

	prepare_environment()


	# =====================================================
	# HULL TARGET
	# =====================================================

	var hull_targets: Array = (
		get_tree().get_nodes_in_group(
			"hull_target"
		)
	)


	if hull_integrity in hull_targets:

		qa_pass(
			"Hull target registered",
			"HullIntegrityPoint found in hull_target"
		)

	else:

		qa_fail(
			"Hull target registered",
			"HullIntegrityPoint not found in hull_target"
		)


	# =====================================================
	# ADQUIRIR TARGET
	# =====================================================

	await wait_seconds(
		settle_time
	)


	if creature.get_target_type() == "HULL":

		qa_pass(
			"Creature targets hull",
			"Target type = HULL"
		)

	else:

		qa_fail(
			"Creature targets hull",
			"Expected HULL | Actual "
			+ creature.get_target_type()
		)


	# =====================================================
	# CHASE
	# =====================================================

	await wait_seconds(
		creature.alert_duration
		+ 0.10
	)


	var distance_before: float = (
		creature.global_position.distance_to(
			hull_integrity.global_position
		)
	)


	await wait_seconds(
		0.25
	)


	var distance_after: float = (
		creature.global_position.distance_to(
			hull_integrity.global_position
		)
	)


	if (
		distance_after < distance_before
		or creature.get_state_name() == "ATTACK"
	):

		qa_pass(
			"Creature approaches hull",
			"Distance "
			+ format_float(
				distance_before
			)
			+ " -> "
			+ format_float(
				distance_after
			)
		)

	else:

		qa_fail(
			"Creature approaches hull",
			"Distance did not decrease"
		)


	# =====================================================
	# DAÑO AL CASCO
	# =====================================================

	var integrity_before: float = (
		hull_integrity.get_integrity()
	)


	var damage_detected: bool = (
		await wait_for_integrity_below(
			integrity_before,
			timeout
		)
	)


	if damage_detected:

		qa_pass(
			"Hull receives damage",
			"Integrity "
			+ format_float(
				integrity_before
			)
			+ " -> "
			+ format_float(
				hull_integrity.get_integrity()
			)
		)

	else:

		qa_fail(
			"Hull receives damage",
			"No integrity loss detected"
		)


	# =====================================================
	# BRECHA
	# =====================================================

	var breach_created: bool = (
		await wait_for_breach(
			timeout
		)
	)


	if breach_created:

		qa_pass(
			"Breach generated",
			"HullBreach active"
		)

	else:

		qa_fail(
			"Breach generated",
			"Hull did not generate breach"
		)


	# =====================================================
	# SUBMARINE STATUS
	# =====================================================

	await wait_seconds(
		0.25
	)


	if (
		submarine_status.get_reason_text()
		.contains(
			"HULL BREACH"
		)
	):

		qa_pass(
			"SubmarineStatus detects breach",
			submarine_status.get_reason_text()
		)

	else:

		qa_fail(
			"SubmarineStatus detects breach",
			"Reason = "
			+ submarine_status.get_reason_text()
		)


	# =====================================================
	# AGUA
	# =====================================================

	var water_before: float = (
		room_right.water_level
	)


	await wait_seconds(
		0.70
	)


	var water_after: float = (
		room_right.water_level
	)


	if water_after > water_before:

		qa_pass(
			"Flooding begins",
			format_percent(
				water_before
			)
			+ " -> "
			+ format_percent(
				water_after
			)
		)

	else:

		qa_fail(
			"Flooding begins",
			"Water did not increase"
		)


	# =====================================================
	# PRESIÓN
	# =====================================================

	if room_right.pressure > 1.0:

		qa_pass(
			"Pressure reacts to breach",
			"Pressure = "
			+ format_float(
				room_right.pressure
			)
		)

	else:

		qa_fail(
			"Pressure reacts to breach",
			"Pressure remained "
			+ format_float(
				room_right.pressure
			)
		)


	# =====================================================
	# DETENER CRIATURA
	# =====================================================

	creature.set_attack_submarine_enabled(
		false
	)


	# =====================================================
	# REPARAR BRECHA
	# =====================================================

	hull_breach.repair_instant()


	await wait_seconds(
		0.35
	)


	if hull_breach.is_repaired():

		qa_pass(
			"Breach can be repaired",
			"HullBreach repaired"
		)

	else:

		qa_fail(
			"Breach can be repaired",
			"HullBreach still active"
		)


	# =====================================================
	# INTEGRIDAD RESTAURADA
	# =====================================================

	if (
		not hull_integrity.is_breached()
		and hull_integrity.get_integrity()
		> hull_integrity.breach_threshold
	):

		qa_pass(
			"Hull integrity restored",
			"Integrity = "
			+ format_float(
				hull_integrity.get_integrity()
			)
		)

	else:

		qa_fail(
			"Hull integrity restored",
			"Integrity = "
			+ format_float(
				hull_integrity.get_integrity()
			)
		)


	# =====================================================
	# ENTRADA DE AGUA DETENIDA
	# =====================================================

	var repaired_water_before: float = (
		room_right.water_level
	)


	await wait_seconds(
		0.40
	)


	var repaired_water_after: float = (
		room_right.water_level
	)


	if abs(
		repaired_water_after
		- repaired_water_before
	) <= 0.005:

		qa_pass(
			"Water inflow stops after repair",
			format_percent(
				repaired_water_before
			)
			+ " -> "
			+ format_percent(
				repaired_water_after
			)
		)

	else:

		qa_fail(
			"Water inflow stops after repair",
			"Water continued rising"
		)


	restore_state()

	finish_suite()


# =========================================================
# VALIDACIÓN
# =========================================================

func validate_required_nodes() -> bool:

	var required_nodes: Array = [
		player,
		creature,
		hull_integrity,
		hull_breach,
		room_right,
		submarine_environment,
		submarine_status,
		interior_point
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


	original_creature_position = (
		creature.global_position
	)


	original_depth = float(
		submarine_environment.get(
			"depth_meters"
		)
	)


	original_water = float(
		room_right.water_level
	)


	original_pressure = float(
		room_right.pressure
	)


	original_integrity = (
		hull_integrity.get_integrity()
	)


	original_breach_repaired = (
		hull_breach.is_repaired()
	)


	original_attack_submarine_enabled = (
		creature.attack_submarine_enabled
	)


	original_hull_damage = (
		creature.hull_attack_damage
	)


	original_attack_cooldown = (
		creature.attack_cooldown
	)


	original_movement_speed = (
		creature.movement_speed
	)


	original_alert_duration = (
		creature.alert_duration
	)


# =========================================================
# PREPARAR TEST
# =========================================================

func prepare_environment():

	# -----------------------------------------------------
	# PLAYER ADENTRO
	# -----------------------------------------------------

	player.global_position = (
		interior_point.global_position
	)


	if player is CharacterBody2D:

		player.velocity = Vector2.ZERO


	# -----------------------------------------------------
	# PROFUNDIDAD
	# -----------------------------------------------------

	set_depth(
		test_depth
	)


	# -----------------------------------------------------
	# HABITACIÓN LIMPIA
	# -----------------------------------------------------

	room_right.set_water_level(
		0.0
	)


	room_right.set_pressure(
		1.0
	)


	# -----------------------------------------------------
	# CERRAR BRECHA EXISTENTE
	# -----------------------------------------------------

	hull_breach.repair_instant()


	# -----------------------------------------------------
	# CASCO 100%
	# -----------------------------------------------------

	hull_integrity.reset_for_qa(
		100.0
	)


	# -----------------------------------------------------
	# ACELERAR SÓLO ESTE QA
	# -----------------------------------------------------

	creature.hull_attack_damage = (
		50.0
	)


	creature.attack_cooldown = (
		0.25
	)


	creature.movement_speed = (
		300.0
	)


	creature.alert_duration = (
		0.10
	)


	# -----------------------------------------------------
	# POSICIÓN DE TEST
	# -----------------------------------------------------

	var creature_test_position: Vector2 = (
		hull_integrity.global_position
		+ Vector2(
			0.0,
			-180.0
		)
	)


	creature.reset_for_qa(
		creature_test_position
	)


	creature.set_attack_submarine_enabled(
		true
	)


# =========================================================
# ESPERAR DAÑO
# =========================================================

func wait_for_integrity_below(
	starting_integrity: float,
	maximum_wait: float
) -> bool:

	var elapsed: float = 0.0


	while elapsed < maximum_wait:

		if (
			hull_integrity.get_integrity()
			< starting_integrity
		):

			return true


		await wait_seconds(
			0.05
		)


		elapsed += 0.05


	return false


# =========================================================
# ESPERAR BRECHA
# =========================================================

func wait_for_breach(
	maximum_wait: float
) -> bool:

	var elapsed: float = 0.0


	while elapsed < maximum_wait:

		if (
			hull_integrity.is_breached()
			and not hull_breach.is_repaired()
		):

			return true


		await wait_seconds(
			0.05
		)


		elapsed += 0.05


	return false


# =========================================================
# RESTAURAR
# =========================================================

func restore_state():

	creature.set_attack_submarine_enabled(
		false
	)


	creature.hull_attack_damage = (
		original_hull_damage
	)


	creature.attack_cooldown = (
		original_attack_cooldown
	)


	creature.movement_speed = (
		original_movement_speed
	)


	creature.alert_duration = (
		original_alert_duration
	)


	creature.reset_for_qa(
		original_creature_position
	)


	creature.set_attack_submarine_enabled(
		original_attack_submarine_enabled
	)


	player.global_position = (
		original_player_position
	)


	if player is CharacterBody2D:

		player.velocity = Vector2.ZERO


	set_depth(
		original_depth
	)


	room_right.set_water_level(
		original_water
	)


	room_right.set_pressure(
		original_pressure
	)


	hull_integrity.reset_for_qa(
		original_integrity
	)


	if original_breach_repaired:

		hull_breach.repair_instant()

	else:

		hull_breach.trigger_breach()


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
					"HULL QA\nPASS\n"
					+ str(
						passed_steps
					)
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
					"HULL QA\nFAIL\n"
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


func format_float(
	value: float
) -> String:

	return str(
		snapped(
			value,
			0.01
		)
	)


func format_percent(
	value: float
) -> String:

	return (
		str(
			int(
				round(
					value
					* 100.0
				)
			)
		)
		+ "%"
	)
