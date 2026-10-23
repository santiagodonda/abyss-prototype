extends Node


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("QA")

@export var start_on_run: bool = false

@export var projectile_sample_time: float = 0.12

@export var impact_wait_time: float = 0.45

@export var second_impact_wait: float = 0.55


# =========================================================
# REFERENCIAS
# =========================================================

@onready var test_bot = (
	get_parent()
)


@onready var turret = (
	get_node_or_null(
		"../../SubmarineTurret"
	)
)


@onready var console = (
	get_node_or_null(
		"../../SubmarineTurretConsole"
	)
)


@onready var creature = (
	get_node_or_null(
		"../../SeaCreature"
	)
)


@onready var power_system = (
	get_node_or_null(
		"../../PowerSystem"
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

var original_turret_ammo: int

var original_creature_position: Vector2

var original_reactor_on: bool

var original_reactor_output: float

var original_attack_submarine_enabled: bool


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
		"[QA] TEST: SUBMARINE WEAPON"
	)

	print(
		"[QA] ========================================"
	)


	if test_bot != null:

		if test_bot.has_method(
			"set_status"
		):

			test_bot.set_status(
				"TURRET QA\nRUNNING"
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
	# TURRET GROUP
	# =====================================================

	if turret.is_in_group(
		"submarine_weapon"
	):

		qa_pass(
			"Turret registered",
			"submarine_weapon group"
		)

	else:

		qa_fail(
			"Turret registered",
			"Turret not found in group"
		)


	# =====================================================
	# CONSOLE INTERACTABLE
	# =====================================================

	var interaction_area = (
		console.get_node_or_null(
			"InteractionArea"
		)
	)


	if (
		interaction_area != null
		and interaction_area.is_in_group(
			"interactable_area"
		)
	):

		qa_pass(
			"Console interactable",
			"InteractionArea registered"
		)

	else:

		qa_fail(
			"Console interactable",
			"InteractionArea not registered"
		)


	# =====================================================
	# SIN ENERGÍA
	# =====================================================

	power_system.set_reactor_state(
		false
	)


	turret.make_fire_ready_for_qa()


	if not turret.can_fire():

		qa_pass(
			"Power requirement",
			"Turret blocked without reactor"
		)

	else:

		qa_fail(
			"Power requirement",
			"Turret fired without power"
		)


	# =====================================================
	# ENERGÍA RESTAURADA
	# =====================================================

	power_system.reactor_output = 1000.0


	power_system.set_reactor_state(
		true
	)


	turret.make_fire_ready_for_qa()


	if turret.can_fire():

		qa_pass(
			"Turret powered",
			"Weapon READY"
		)

	else:

		qa_fail(
			"Turret powered",
			"Weapon not ready with power"
		)


	# =====================================================
	# PRIMER DISPARO
	# =====================================================

	var ammo_before: int = (
		turret.get_ammo()
	)


	var fired: bool = (
		turret.fire_at(
			creature.global_position
		)
	)


	var projectile = (
		turret.get_last_projectile()
	)


	if (
		fired
		and projectile != null
		and is_instance_valid(
			projectile
		)
	):

		qa_pass(
			"Projectile created",
			"Submarine projectile spawned"
		)

	else:

		qa_fail(
			"Projectile created",
			"fire_at returned "
			+ str(
				fired
			)
		)


	# =====================================================
	# MUNICIÓN
	# =====================================================

	var ammo_after: int = (
		turret.get_ammo()
	)


	if ammo_after == ammo_before - 1:

		qa_pass(
			"Ammo consumed",
			str(
				ammo_before
			)
			+ " -> "
			+ str(
				ammo_after
			)
		)

	else:

		qa_fail(
			"Ammo consumed",
			"Expected "
			+ str(
				ammo_before - 1
			)
			+ " | Actual "
			+ str(
				ammo_after
			)
		)


	# =====================================================
	# COOLDOWN
	# =====================================================

	var second_immediate: bool = (
		turret.fire_at(
			creature.global_position
		)
	)


	if not second_immediate:

		qa_pass(
			"Fire cooldown respected",
			"Immediate second shot blocked"
		)

	else:

		qa_fail(
			"Fire cooldown respected",
			"Immediate second shot allowed"
		)


	# =====================================================
	# MOVIMIENTO PROYECTIL
	# =====================================================

	if (
		projectile != null
		and is_instance_valid(
			projectile
		)
	):

		var start_position: Vector2 = (
			projectile.global_position
		)


		await wait_seconds(
			projectile_sample_time
		)


		if is_instance_valid(
			projectile
		):

			var travelled: float = (
				projectile.global_position.distance_to(
					start_position
				)
			)


			if travelled > 5.0:

				qa_pass(
					"Projectile travels",
					"Distance = "
					+ format_float(
						travelled
					)
				)

			else:

				qa_fail(
					"Projectile travels",
					"Projectile barely moved"
				)

		else:

			qa_fail(
				"Projectile travels",
				"Projectile disappeared too early"
			)

	else:

		qa_skip(
			"Projectile travels",
			"No projectile available"
		)


	# =====================================================
	# PRIMER IMPACTO
	# =====================================================

	await wait_seconds(
		impact_wait_time
	)


	var expected_health: float = (
		creature.max_health
		- turret.damage
	)


	if abs(
		creature.current_health
		- expected_health
	) <= 0.1:

		qa_pass(
			"Creature receives turret damage",
			format_float(
				creature.max_health
			)
			+ " -> "
			+ format_float(
				creature.current_health
			)
		)

	else:

		qa_fail(
			"Creature receives turret damage",
			"Expected "
			+ format_float(
				expected_health
			)
			+ " | Actual "
			+ format_float(
				creature.current_health
			)
		)


	# =====================================================
	# SEGUNDO DISPARO
	# =====================================================

	await wait_seconds(
		0.15
	)


	var second_fired: bool = (
		turret.fire_at(
			creature.global_position
		)
	)


	if second_fired:

		await wait_seconds(
			second_impact_wait
		)


		if creature.is_dead():

			qa_pass(
				"Turret can kill creature",
				"Creature state = DEAD"
			)

		else:

			qa_fail(
				"Turret can kill creature",
				"Health = "
				+ format_float(
					creature.current_health
				)
			)

	else:

		qa_fail(
			"Turret can kill creature",
			"Second shot did not fire"
		)


	# =====================================================
	# SIN MUNICIÓN
	# =====================================================

	turret.set_ammo_for_qa(
		0
	)


	turret.make_fire_ready_for_qa()


	if not turret.can_fire():

		qa_pass(
			"Empty turret blocked",
			"Ammo = 0"
		)

	else:

		qa_fail(
			"Empty turret blocked",
			"Turret READY with 0 ammo"
		)


	restore_state()

	finish_suite()


# =========================================================
# VALIDACIÓN
# =========================================================

func validate_required_nodes() -> bool:

	var required_nodes: Array = [
		turret,
		console,
		creature,
		power_system
	]


	for node in required_nodes:

		if node == null:
			return false


	return true


# =========================================================
# BACKUP
# =========================================================

func backup_state():

	original_turret_ammo = (
		turret.get_ammo()
	)


	original_creature_position = (
		creature.global_position
	)


	original_reactor_on = bool(
		power_system.get(
			"reactor_on"
		)
	)


	original_reactor_output = float(
		power_system.get(
			"reactor_output"
		)
	)


	original_attack_submarine_enabled = (
		creature.attack_submarine_enabled
	)


# =========================================================
# PREPARAR
# =========================================================

func prepare_environment():

	# -----------------------------------------------------
	# EVITAR QUE ATAQUE EL CASCO
	# -----------------------------------------------------

	creature.set_attack_submarine_enabled(
		false
	)


	# -----------------------------------------------------
	# CRIATURA A DISTANCIA DE TEST
	# -----------------------------------------------------

	creature.reset_for_qa(
		turret.global_position
		+ Vector2(
			300.0,
			0.0
		)
	)


	# -----------------------------------------------------
	# MUNICIÓN DE TEST
	# -----------------------------------------------------

	turret.reset_for_qa(
		4
	)


	# -----------------------------------------------------
	# POTENCIA SUFICIENTE PARA AISLAR EL TEST
	# -----------------------------------------------------

	power_system.reactor_output = (
		1000.0
	)


	power_system.set_reactor_state(
		true
	)


# =========================================================
# RESTAURAR
# =========================================================

func restore_state():

	turret.reset_for_qa(
		original_turret_ammo
	)


	creature.reset_for_qa(
		original_creature_position
	)


	creature.set_attack_submarine_enabled(
		original_attack_submarine_enabled
	)


	power_system.reactor_output = (
		original_reactor_output
	)


	power_system.set_reactor_state(
		original_reactor_on
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
					"TURRET QA\nPASS\n"
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
					"TURRET QA\nFAIL\n"
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
