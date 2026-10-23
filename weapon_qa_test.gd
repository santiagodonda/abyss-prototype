extends Node


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("QA")

@export var start_on_run: bool = false

@export var projectile_sample_time: float = 0.15

@export var impact_wait_time: float = 0.75

@export var shot_cycle_wait: float = 0.90

@export var test_depth: float = 100.0


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


@onready var inventory = (
	get_node_or_null(
		"../../Player/Inventory"
	)
)


@onready var equipment = (
	get_node_or_null(
		"../../Player/Equipment"
	)
)


@onready var weapon_system = (
	get_node_or_null(
		"../../Player/WeaponSystem"
	)
)


@onready var player_health = (
	get_node_or_null(
		"../../Player/Health"
	)
)


@onready var player_vitals = (
	get_node_or_null(
		"../../Player/Vitals"
	)
)


@onready var creature = (
	get_node_or_null(
		"../../SeaCreature"
	)
)


@onready var submarine_environment = (
	get_node_or_null(
		"../../SubmarineEnvironment"
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

var original_tool: String = ""

var original_gun_quantity: int = 0

var original_ammo_quantity: int = 0

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
		"[QA] TEST: WEAPON COMBAT"
	)

	print(
		"[QA] ========================================"
	)


	if test_bot != null:

		if test_bot.has_method(
			"set_status"
		):

			test_bot.set_status(
				"WEAPON QA\nRUNNING"
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
	# ARMA
	# =====================================================

	var weapon_ready: bool = (
		ensure_item_quantity(
			"harpoon_gun",
			1
		)
	)


	if weapon_ready:

		weapon_ready = (
			equipment.select_tool(
				"harpoon_gun"
			)
		)


	if weapon_ready:

		qa_pass(
			"Weapon equipped",
			"Active Tool = Harpoon Gun"
		)

	else:

		qa_fail(
			"Weapon equipped",
			"Could not equip harpoon_gun"
		)

		restore_state()

		finish_suite()

		return


	# =====================================================
	# MUNICIÓN
	# =====================================================

	var ammo_ready: bool = (
		ensure_item_quantity(
			"harpoon_ammo",
			6
		)
	)


	if not ammo_ready:

		qa_fail(
			"Ammo available",
			"Could not add harpoon ammo"
		)

		restore_state()

		finish_suite()

		return


	# =====================================================
	# PRIMER DISPARO
	# =====================================================

	var ammo_before: int = (
		inventory.get_item_quantity(
			"harpoon_ammo"
		)
	)


	var fired: bool = (
		weapon_system.fire_at(
			creature.global_position
		)
	)


	var projectile = (
		weapon_system.get_last_projectile()
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
			"Harpoon projectile spawned"
		)

	else:

		qa_fail(
			"Projectile created",
			"fire_at returned "
			+ str(fired)
		)


	# =====================================================
	# MUNICIÓN CONSUMIDA
	# =====================================================

	var ammo_after: int = (
		inventory.get_item_quantity(
			"harpoon_ammo"
		)
	)


	if ammo_after == ammo_before - 1:

		qa_pass(
			"Ammo consumed",
			str(ammo_before)
			+ " -> "
			+ str(ammo_after)
		)

	else:

		qa_fail(
			"Ammo consumed",
			"Expected "
			+ str(
				ammo_before - 1
			)
			+ " | Actual "
			+ str(ammo_after)
		)


	# =====================================================
	# COOLDOWN
	# =====================================================

	var cooldown_ammo_before: int = (
		inventory.get_item_quantity(
			"harpoon_ammo"
		)
	)


	var fired_during_cooldown: bool = (
		weapon_system.fire_at(
			creature.global_position
		)
	)


	var cooldown_ammo_after: int = (
		inventory.get_item_quantity(
			"harpoon_ammo"
		)
	)


	if (
		not fired_during_cooldown
		and cooldown_ammo_before
		== cooldown_ammo_after
	):

		qa_pass(
			"Fire cooldown respected",
			"Immediate second shot blocked"
		)

	else:

		qa_fail(
			"Fire cooldown respected",
			"Immediate second shot was not blocked"
		)


	# =====================================================
	# MOVIMIENTO DEL PROYECTIL
	# =====================================================

	if (
		projectile != null
		and is_instance_valid(
			projectile
		)
	):

		var projectile_start: Vector2 = (
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
					projectile_start
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

	var expected_health_after_first: float = (
		creature.max_health
		- 20.0
	)


	await wait_seconds(
		impact_wait_time
	)


	if abs(
		creature.current_health
		- expected_health_after_first
	) <= 0.1:

		qa_pass(
			"Creature receives damage",
			"Health "
			+ format_float(
				creature.max_health
			)
			+ " -> "
			+ format_float(
				creature.current_health
			)
		)

	else:

		qa_fail(
			"Creature receives damage",
			"Expected "
			+ format_float(
				expected_health_after_first
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
		0.10
	)


	var second_fired: bool = (
		weapon_system.fire_at(
			creature.global_position
		)
	)


	if second_fired:

		await wait_seconds(
			shot_cycle_wait
		)


		if abs(
			creature.current_health
			- 10.0
		) <= 0.1:

			qa_pass(
				"Second shot works",
				"Creature Health = "
				+ format_float(
					creature.current_health
				)
			)

		else:

			qa_fail(
				"Second shot works",
				"Expected health 10 | Actual "
				+ format_float(
					creature.current_health
				)
			)

	else:

		qa_fail(
			"Second shot works",
			"Weapon did not fire after cooldown"
		)


	# =====================================================
	# TERCER DISPARO
	# =====================================================

	var third_fired: bool = (
		weapon_system.fire_at(
			creature.global_position
		)
	)


	if third_fired:

		await wait_seconds(
			shot_cycle_wait
		)


	if creature.is_dead():

		qa_pass(
			"Creature can die",
			"State = DEAD"
		)

	else:

		qa_fail(
			"Creature can die",
			"Health = "
			+ format_float(
				creature.current_health
			)
			+ " | State = "
			+ creature.get_state_name()
		)


	# =====================================================
	# IA DETENIDA
	# =====================================================

	await wait_seconds(
		0.20
	)


	if (
		creature.get_state_name()
		== "DEAD"
		and creature.velocity.length()
		<= 0.01
	):

		qa_pass(
			"Dead creature stops AI",
			"State = DEAD | Velocity = 0"
		)

	else:

		qa_fail(
			"Dead creature stops AI",
			"State = "
			+ creature.get_state_name()
			+ " | Velocity = "
			+ format_float(
				creature.velocity.length()
			)
		)


	restore_state()

	finish_suite()


# =========================================================
# PRECHECK
# =========================================================

func validate_required_nodes() -> bool:

	var required_nodes: Array = [
		player,
		inventory,
		equipment,
		weapon_system,
		player_health,
		player_vitals,
		creature,
		submarine_environment,
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


	original_tool = (
		equipment.get_equipped_tool()
	)


	original_gun_quantity = (
		inventory.get_item_quantity(
			"harpoon_gun"
		)
	)


	original_ammo_quantity = (
		inventory.get_item_quantity(
			"harpoon_ammo"
		)
	)


	original_creature_position = (
		creature.global_position
	)


# =========================================================
# PREPARAR
# =========================================================

func prepare_environment():

	set_depth(
		test_depth
	)


	player.global_position = (
		exterior_point.global_position
	)


	if player is CharacterBody2D:

		player.velocity = Vector2.ZERO


	player_health.current_health = (
		player_health.max_health
	)


	player_vitals.breath_level = 1.0


	# Lo colocamos fuera del detection_range,
	# pero dentro del alcance del arpón.
	creature.reset_for_qa(
		player.global_position
		+ Vector2(
			400.0,
			0.0
		)
	)


# =========================================================
# INVENTARIO
# =========================================================

func ensure_item_quantity(
	item_id: String,
	target_quantity: int
) -> bool:

	var current_quantity: int = (
		inventory.get_item_quantity(
			item_id
		)
	)


	if current_quantity >= target_quantity:
		return true


	return inventory.add_item(
		item_id,
		target_quantity
		- current_quantity
	)


func restore_item_quantity(
	item_id: String,
	target_quantity: int
):

	var current_quantity: int = (
		inventory.get_item_quantity(
			item_id
		)
	)


	if current_quantity > target_quantity:

		inventory.remove_item(
			item_id,
			current_quantity
			- target_quantity
		)


	elif current_quantity < target_quantity:

		inventory.add_item(
			item_id,
			target_quantity
			- current_quantity
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


	restore_item_quantity(
		"harpoon_gun",
		original_gun_quantity
	)


	restore_item_quantity(
		"harpoon_ammo",
		original_ammo_quantity
	)


	if (
		not original_tool.is_empty()
		and inventory.has_item(
			original_tool,
			1
		)
	):

		equipment.select_tool(
			original_tool
		)

	else:

		equipment.select_tool(
			""
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
					"WEAPON QA\nPASS\n"
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
					"WEAPON QA\nFAIL\n"
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
