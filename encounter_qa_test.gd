extends Node


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("QA")

@export var start_on_run: bool = false

@export var test_creature_count: int = 3

@export var settle_time: float = 0.20

@export var approach_test_time: float = 0.60


# =========================================================
# REFERENCIAS
# =========================================================

@onready var test_bot = (
	get_parent()
)


@onready var manager = (
	get_node_or_null(
		"../../EncounterManager"
	)
)


@onready var player = (
	get_node_or_null(
		"../../Player"
	)
)


@onready var interior_point = (
	get_node_or_null(
		"../../HatchInteriorPoint"
	)
)


@onready var hull_target = (
	get_node_or_null(
		"../../HullIntegrityPoint"
	)
)


@onready var hull_breach = (
	get_node_or_null(
		"../../HullBreach"
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


@onready var original_creature = (
	get_node_or_null(
		"../../SeaCreature"
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

var original_left_water: float

var original_right_water: float

var original_breach_repaired: bool

var original_existing_creature_attack: bool


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
		"[QA] TEST: ENCOUNTER SYSTEM"
	)

	print(
		"[QA] ========================================"
	)


	if test_bot != null:

		if test_bot.has_method(
			"set_status"
		):

			test_bot.set_status(
				"ENCOUNTER QA\nRUNNING"
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
	# START
	# =====================================================

	var started: bool = (
		manager.start_encounter(
			test_creature_count
		)
	)


	if (
		started
		and manager.is_encounter_active()
	):

		qa_pass(
			"Encounter starts",
			"Encounter active"
		)

	else:

		qa_fail(
			"Encounter starts",
			"Encounter did not become active"
		)


	# =====================================================
	# COUNT
	# =====================================================

	var creatures: Array = (
		manager.get_creatures()
	)


	if (
		creatures.size()
		== test_creature_count
	):

		qa_pass(
			"Correct creature count",
			"Spawned "
			+ str(
				creatures.size()
			)
		)

	else:

		qa_fail(
			"Correct creature count",
			"Expected "
			+ str(
				test_creature_count
			)
			+ " | Actual "
			+ str(
				creatures.size()
			)
		)


	# =====================================================
	# GROUPS
	# =====================================================

	var groups_valid: bool = true


	for creature in creatures:

		if not creature.is_in_group(
			"damageable_creature"
		):

			groups_valid = false


		if not creature.is_in_group(
			"encounter_creature"
		):

			groups_valid = false


	if groups_valid:

		qa_pass(
			"Spawn groups registered",
			"damageable_creature + encounter_creature"
		)

	else:

		qa_fail(
			"Spawn groups registered",
			"One or more creatures missing group"
		)


	# =====================================================
	# SPAWN FUERA DEL SUBMARINO
	# =====================================================

	var spawn_safe: bool = true


	for creature in creatures:

		if room_left.contains_global_point(
			creature.global_position
		):

			spawn_safe = false


		if room_right.contains_global_point(
			creature.global_position
		):

			spawn_safe = false


	if spawn_safe:

		qa_pass(
			"Spawn outside submarine",
			"No creature inside rooms"
		)

	else:

		qa_fail(
			"Spawn outside submarine",
			"Creature spawned inside a room"
		)


	# =====================================================
	# DISTANCIA DE SPAWN
	# =====================================================

	var distance_valid: bool = true

	var expected_distance: float = (
		manager.get_spawn_distance()
	)


	for creature in creatures:

		var distance: float = (
			creature.global_position.distance_to(
				hull_target.global_position
			)
		)


		if abs(
			distance
			- expected_distance
		) > 2.0:

			distance_valid = false


	if distance_valid:

		qa_pass(
			"Spawn distance valid",
			"Distance = "
			+ format_float(
				expected_distance
			)
		)

	else:

		qa_fail(
			"Spawn distance valid",
			"One or more spawn distances invalid"
		)


	# =====================================================
	# HOSTILIDAD AL SUBMARINO
	# =====================================================

	var attack_enabled: bool = true


	for creature in creatures:

		if not creature.attack_submarine_enabled:

			attack_enabled = false


	if attack_enabled:

		qa_pass(
			"Hull attack enabled",
			"All encounter creatures hostile"
		)

	else:

		qa_fail(
			"Hull attack enabled",
			"Creature without hull attack"
		)


	# =====================================================
	# ACELERAR IA PARA QA
	# =====================================================

	for creature in creatures:

		creature.movement_speed = 240.0

		creature.alert_duration = 0.10


	await wait_seconds(
		settle_time
	)


	# =====================================================
	# TARGET HULL
	# =====================================================

	var hull_targeted: bool = false


	for creature in creatures:

		if creature.get_target_type() == "HULL":

			hull_targeted = true


	if hull_targeted:

		qa_pass(
			"Encounter acquires hull target",
			"At least one creature targeting HULL"
		)

	else:

		qa_fail(
			"Encounter acquires hull target",
			"No creature targeting hull"
		)


	# =====================================================
	# APROXIMACIÓN
	# =====================================================

	var average_before: float = (
		get_average_hull_distance(
			creatures
		)
	)


	await wait_seconds(
		approach_test_time
	)


	var average_after: float = (
		get_average_hull_distance(
			creatures
		)
	)


	if average_after < average_before:

		qa_pass(
			"Encounter approaches submarine",
			format_float(
				average_before
			)
			+ " -> "
			+ format_float(
				average_after
			)
		)

	else:

		qa_fail(
			"Encounter approaches submarine",
			"Average distance did not decrease"
		)


	# =====================================================
	# ELIMINAR ENEMIGOS
	# =====================================================

	for creature in creatures:

		if not is_instance_valid(
			creature
		):

			continue


		creature.apply_damage(
			creature.max_health
			+ 100.0,
			&"qa_encounter"
		)


	await wait_seconds(
		0.10
	)


	if manager.get_alive_count() == 0:

		qa_pass(
			"All enemies defeated",
			"Alive count = 0"
		)

	else:

		qa_fail(
			"All enemies defeated",
			"Alive count = "
			+ str(
				manager.get_alive_count()
			)
		)


	# =====================================================
	# COMPLETE
	# =====================================================

	await wait_seconds(
		0.15
	)


	if (
		manager.is_encounter_complete()
		and not manager.is_encounter_active()
	):

		qa_pass(
			"Encounter completes",
			"Encounter state = COMPLETE"
		)

	else:

		qa_fail(
			"Encounter completes",
			"Encounter did not complete"
		)


	# =====================================================
	# RESTART
	# =====================================================

	var restarted: bool = (
		manager.start_encounter(
			2
		)
	)


	await wait_seconds(
		0.05
	)


	if (
		restarted
		and manager.is_encounter_active()
		and manager.get_spawned_count() == 2
		and manager.get_alive_count() == 2
	):

		qa_pass(
			"Encounter can restart",
			"Second encounter spawned 2 creatures"
		)

	else:

		qa_fail(
			"Encounter can restart",
			"Restart state invalid"
		)


	# =====================================================
	# CLEANUP
	# =====================================================

	manager.stop_encounter(
		true
	)


	await wait_seconds(
		0.05
	)


	if (
		not manager.is_encounter_active()
		and manager.get_spawned_count() == 0
	):

		qa_pass(
			"Encounter cleanup",
			"Spawned count = 0"
		)

	else:

		qa_fail(
			"Encounter cleanup",
			"Encounter creatures remain"
		)


	restore_state()

	finish_suite()


# =========================================================
# REQUIRED NODES
# =========================================================

func validate_required_nodes() -> bool:

	var required_nodes: Array = [
		manager,
		player,
		interior_point,
		hull_target,
		hull_breach,
		room_left,
		room_right,
		original_creature
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


	original_left_water = (
		room_left.water_level
	)


	original_right_water = (
		room_right.water_level
	)


	original_breach_repaired = (
		hull_breach.is_repaired()
	)


	original_existing_creature_attack = (
		original_creature.attack_submarine_enabled
	)


# =========================================================
# PREPARE
# =========================================================

func prepare_environment():

	# -----------------------------------------------------
	# EVITAR QUE PLAYER SEA EL TARGET
	# -----------------------------------------------------

	player.global_position = (
		interior_point.global_position
	)


	if player is CharacterBody2D:

		player.velocity = Vector2.ZERO


	# -----------------------------------------------------
	# EVITAR QUE LA CRIATURA MANUAL INTERFIERA
	# -----------------------------------------------------

	original_creature.set_attack_submarine_enabled(
		false
	)


	# -----------------------------------------------------
	# LIMPIAR ENCUENTRO PREVIO
	# -----------------------------------------------------

	manager.stop_encounter(
		true
	)


	# -----------------------------------------------------
	# AISLAR INUNDACIÓN
	# -----------------------------------------------------

	hull_breach.repair_instant()


	room_left.set_water_level(
		0.0
	)


	room_right.set_water_level(
		0.0
	)


# =========================================================
# DISTANCIA PROMEDIO
# =========================================================

func get_average_hull_distance(
	creatures: Array
) -> float:

	var total_distance: float = 0.0

	var valid_count: int = 0


	for creature in creatures:

		if not is_instance_valid(
			creature
		):

			continue


		total_distance += (
			creature.global_position.distance_to(
				hull_target.global_position
			)
		)


		valid_count += 1


	if valid_count <= 0:
		return INF


	return (
		total_distance
		/ float(
			valid_count
		)
	)


# =========================================================
# RESTORE
# =========================================================

func restore_state():

	manager.stop_encounter(
		true
	)


	player.global_position = (
		original_player_position
	)


	if player is CharacterBody2D:

		player.velocity = Vector2.ZERO


	room_left.set_water_level(
		original_left_water
	)


	room_right.set_water_level(
		original_right_water
	)


	if original_breach_repaired:

		hull_breach.repair_instant()

	else:

		hull_breach.trigger_breach()


	original_creature.set_attack_submarine_enabled(
		original_existing_creature_attack
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
# PASS / FAIL / SKIP
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
# FINISH
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
				"ENCOUNTER QA\nPASS\n"
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
				"ENCOUNTER QA\nFAIL\n"
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
