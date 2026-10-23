extends Node


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("QA")

@export var start_on_run: bool = false


@export_group("Exterior Test")

@export var test_depth: float = 500.0

@export var settle_time: float = 0.35

@export var pressure_damage_test_time: float = 0.50

@export var oxygen_consumption_test_time: float = 1.25

@export var interior_recovery_test_time: float = 1.00


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


@onready var player_inventory = (
	get_node_or_null(
		"../../Player/Inventory"
	)
)


@onready var player_equipment = (
	get_node_or_null(
		"../../Player/Equipment"
	)
)


@onready var submarine_environment = (
	get_node_or_null(
		"../../SubmarineEnvironment"
	)
)


@onready var room_left = (
	get_node_or_null(
		"../../RoomLeft"
	)
)


@onready var exterior_test_point = (
	get_node_or_null(
		"../../ExteriorTestPoint"
	)
)


@onready var interior_test_point = (
	get_node_or_null(
		"../../InteriorTestPoint"
	)
)


# =========================================================
# ESTADO QA
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

var original_depth: float = 0.0

var original_room_water: float = 0.0

var original_room_oxygen: float = 1.0

var original_room_pressure: float = 1.0


# =========================================================
# READY
# =========================================================

func _ready():

	if start_on_run:

		call_deferred(
			"run_suite"
		)


# =========================================================
# INICIAR
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
		"[QA] TEST: EXTERIOR SURVIVAL"
	)

	print(
		"[QA] ========================================"
	)


	if test_bot != null:

		if test_bot.has_method(
			"set_status"
		):

			test_bot.set_status(
				"EXTERIOR QA\nRUNNING"
			)


	# -----------------------------------------------------
	# PRECHECK
	# -----------------------------------------------------

	if not validate_required_nodes():

		qa_fail(
			"Required nodes",
			"One or more required nodes are missing"
		)


		qa_skip(
			"Exterior detection",
			"Precheck failed"
		)


		qa_skip(
			"Underwater state",
			"Precheck failed"
		)


		qa_skip(
			"Exterior pressure",
			"Precheck failed"
		)


		qa_skip(
			"Pressure damage",
			"Precheck failed"
		)


		qa_skip(
			"Diving suit protection",
			"Precheck failed"
		)


		qa_skip(
			"Oxygen tank consumption",
			"Precheck failed"
		)


		qa_skip(
			"Interior return",
			"Precheck failed"
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
	# EXTERIOR
	# =====================================================

	player.global_position = (
		exterior_test_point.global_position
	)


	await wait_seconds(
		settle_time
	)


	# -----------------------------------------------------
	# EXTERIOR DETECTADO
	# -----------------------------------------------------

	if player_vitals.is_exterior():

		qa_pass(
			"Exterior detection",
			"Room = EXTERIOR"
		)

	else:

		qa_fail(
			"Exterior detection",
			"Expected EXTERIOR, actual "
			+ player_vitals.get_room_id()
		)


	# -----------------------------------------------------
	# UNDERWATER
	# -----------------------------------------------------

	if player_vitals.is_underwater():

		qa_pass(
			"Underwater state",
			"Exterior correctly detected as underwater"
		)

	else:

		qa_fail(
			"Underwater state",
			"Expected UNDERWATER = true"
		)


	# -----------------------------------------------------
	# PRESIÓN EXTERIOR
	# -----------------------------------------------------

	var expected_pressure: float = (
		submarine_environment.get_external_pressure()
	)


	var actual_pressure: float = (
		player_vitals.get_environment_pressure()
	)


	if abs(
		expected_pressure
		- actual_pressure
	) <= 0.05:

		qa_pass(
			"Exterior pressure",
			"Expected "
			+ format_float(expected_pressure)
			+ " | Actual "
			+ format_float(actual_pressure)
		)

	else:

		qa_fail(
			"Exterior pressure",
			"Expected "
			+ format_float(expected_pressure)
			+ " | Actual "
			+ format_float(actual_pressure)
		)


	# =====================================================
	# PRESIÓN SIN TRAJE
	# =====================================================

	var already_wearing_suit: bool = (
		player_equipment.is_diving_suit_equipped()
	)


	if already_wearing_suit:

		qa_skip(
			"Pressure damage without suit",
			"Player already had diving suit equipped"
		)

	else:

		var health_before_pressure: float = (
			player_health.current_health
		)


		await wait_seconds(
			pressure_damage_test_time
		)


		var health_after_pressure: float = (
			player_health.current_health
		)


		if health_after_pressure < health_before_pressure:

			qa_pass(
				"Pressure damage without suit",
				"Health "
				+ format_float(
					health_before_pressure
				)
				+ " -> "
				+ format_float(
					health_after_pressure
				)
			)

		else:

			qa_fail(
				"Pressure damage without suit",
				"Expected health loss at "
				+ format_float(
					actual_pressure
				)
				+ " atm"
			)


	# =====================================================
	# TRAJE DE BUCEO
	# =====================================================

	var suit_ready: bool = (
		ensure_item(
			"diving_suit"
		)
	)


	if suit_ready:

		suit_ready = bool(
			player_equipment.equip_item(
				"diving_suit"
			)
		)


	if not suit_ready:

		qa_fail(
			"Diving suit protection",
			"Could not equip diving suit"
		)

	else:

		await wait_seconds(
			settle_time
		)


		var effective_safe_pressure: float = (
			player_vitals.get_effective_safe_pressure()
		)


		var pressure_status: String = (
			player_vitals.get_pressure_status()
		)


		if (
			effective_safe_pressure
			>= actual_pressure
			and pressure_status == "SAFE"
		):

			qa_pass(
				"Diving suit protection",
				"Safe limit "
				+ format_float(
					effective_safe_pressure
				)
				+ " atm | Environment "
				+ format_float(
					actual_pressure
				)
				+ " atm"
			)

		else:

			qa_fail(
				"Diving suit protection",
				"Safe limit "
				+ format_float(
					effective_safe_pressure
				)
				+ " | Environment "
				+ format_float(
					actual_pressure
				)
				+ " | Status "
				+ pressure_status
			)


	# =====================================================
	# TANQUE DE OXÍGENO
	# =====================================================

	var tank_ready: bool = (
		ensure_item(
			"oxygen_tank"
		)
	)


	if tank_ready:

		tank_ready = bool(
			player_equipment.equip_item(
				"oxygen_tank"
			)
		)


	if not tank_ready:

		qa_fail(
			"Oxygen tank consumption",
			"Could not equip oxygen tank"
		)


		qa_skip(
			"Breath stability outside",
			"Oxygen tank unavailable"
		)

	else:

		await wait_seconds(
			settle_time
		)


		var tank_before: float = (
			player_equipment.get_tank_percentage()
		)


		var breath_before: float = (
			player_vitals.breath_level
		)


		await wait_seconds(
			oxygen_consumption_test_time
		)


		var tank_after: float = (
			player_equipment.get_tank_percentage()
		)


		var breath_after: float = (
			player_vitals.breath_level
		)


		if tank_after < tank_before:

			qa_pass(
				"Oxygen tank consumption",
				format_percent(
					tank_before
				)
				+ " -> "
				+ format_percent(
					tank_after
				)
			)

		else:

			qa_fail(
				"Oxygen tank consumption",
				"Before "
				+ format_percent(
					tank_before
				)
				+ " | After "
				+ format_percent(
					tank_after
				)
			)


		if (
			breath_after >= 0.90
			or breath_after >= breath_before
		):

			qa_pass(
				"Breath stability outside",
				"Breath "
				+ format_percent(
					breath_before
				)
				+ " -> "
				+ format_percent(
					breath_after
				)
			)

		else:

			qa_fail(
				"Breath stability outside",
				"Breath dropped unexpectedly: "
				+ format_percent(
					breath_before
				)
				+ " -> "
				+ format_percent(
					breath_after
				)
			)


	# =====================================================
	# VOLVER AL INTERIOR
	# =====================================================

	player_vitals.breath_level = 0.70


	player.global_position = (
		interior_test_point.global_position
	)


	await wait_seconds(
		settle_time
	)


	if not player_vitals.is_exterior():

		qa_pass(
			"Interior return",
			"Room = "
			+ player_vitals.get_room_id()
		)

	else:

		qa_fail(
			"Interior return",
			"Player still detected as EXTERIOR"
		)


	# -----------------------------------------------------
	# RECUPERACIÓN DE RESPIRACIÓN
	# -----------------------------------------------------

	var breath_before_recovery: float = (
		player_vitals.breath_level
	)


	await wait_seconds(
		interior_recovery_test_time
	)


	var breath_after_recovery: float = (
		player_vitals.breath_level
	)


	if breath_after_recovery > breath_before_recovery:

		qa_pass(
			"Interior breath recovery",
			format_percent(
				breath_before_recovery
			)
			+ " -> "
			+ format_percent(
				breath_after_recovery
			)
		)

	else:

		qa_fail(
			"Interior breath recovery",
			"Expected breath recovery | Before "
			+ format_percent(
				breath_before_recovery
			)
			+ " | After "
			+ format_percent(
				breath_after_recovery
			)
		)


	restore_state()

	finish_suite()


# =========================================================
# VALIDACIÓN DE NODOS
# =========================================================

func validate_required_nodes() -> bool:

	var required_nodes: Array = [
		player,
		player_vitals,
		player_health,
		player_inventory,
		player_equipment,
		submarine_environment,
		room_left,
		exterior_test_point,
		interior_test_point
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


	original_player_health = (
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


	original_room_water = float(
		room_left.water_level
	)


	original_room_oxygen = float(
		room_left.oxygen_level
	)


	original_room_pressure = float(
		room_left.pressure
	)


# =========================================================
# PREPARAR ENTORNO
# =========================================================

func prepare_environment():

	set_depth(
		test_depth
	)


	set_room_water(
		0.0
	)


	set_room_oxygen(
		1.0
	)


	set_room_pressure(
		1.0
	)


	player_health.current_health = (
		player_health.max_health
	)


	player_vitals.breath_level = 1.0


# =========================================================
# RESTAURAR
# =========================================================

func restore_state():

	player.global_position = (
		original_player_position
	)


	player_health.current_health = (
		original_player_health
	)


	player_vitals.breath_level = (
		original_breath
	)


	set_depth(
		original_depth
	)


	set_room_water(
		original_room_water
	)


	set_room_oxygen(
		original_room_oxygen
	)


	set_room_pressure(
		original_room_pressure
	)


# =========================================================
# PROFUNDIDAD
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
# HABITACIÓN CONTROLADA
# =========================================================

func set_room_water(
	value: float
):

	if room_left.has_method(
		"set_water_level"
	):

		room_left.set_water_level(
			value
		)

	else:

		room_left.water_level = value


func set_room_oxygen(
	value: float
):

	if room_left.has_method(
		"set_oxygen_level"
	):

		room_left.set_oxygen_level(
			value
		)

	else:

		room_left.oxygen_level = value


func set_room_pressure(
	value: float
):

	if room_left.has_method(
		"set_pressure"
	):

		room_left.set_pressure(
			value
		)

	else:

		room_left.pressure = value


# =========================================================
# INVENTARIO
# =========================================================

func ensure_item(
	item_id: String
) -> bool:

	if player_inventory.has_item(
		item_id,
		1
	):

		return true


	return bool(
		player_inventory.add_item(
			item_id,
			1
		)
	)


# =========================================================
# ESPERA
# =========================================================

func wait_seconds(
	seconds: float
):

	await get_tree().create_timer(
		seconds
	).timeout


# =========================================================
# LOG PASS
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
# LOG FAIL
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
# LOG SKIP
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
					"EXTERIOR QA\nPASS\n"
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
					"EXTERIOR QA\nFAIL\n"
					+ str(failed_steps)
					+ " FAIL"
				)


	print(
		"[QA] ========================================"
	)

	print("")


	is_running = false


# =========================================================
# FORMATO
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
