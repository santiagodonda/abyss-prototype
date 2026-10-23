extends CharacterBody2D


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("Test Bot")

@export var movement_speed: float = 150.0

@export var interaction_distance: float = 55.0

@export var test_timeout: float = 12.0

@export var time_between_tests: float = 1.0

@export var start_on_run: bool = false


@export_enum(
	"Water Pump",
	"Pressure Regulator",
	"Reactor",
	"Oxygen Generator",
	"Hull Breach",
	"All Repairs",
	"All Fault Recovery"
)
var test_mode: int = 5


# =========================================================
# NODOS
# =========================================================

@onready var inventory: Node = $Inventory

@onready var equipment: Node = $Equipment

@onready var failure_system = (
	$"../MachineFailureSystem"
)


# =========================================================
# ESTADOS
# =========================================================

enum BotState {
	IDLE,
	MOVING,
	REPAIRING,
	WAITING,
	PASSED,
	FAILED
}


var state: BotState = BotState.IDLE


# =========================================================
# TESTS
# =========================================================

var test_queue: Array = []

var current_test: Dictionary = {}

var current_target: Node = null

var completed_tests: int = 0

var failed_tests: int = 0


# =========================================================
# TIEMPOS
# =========================================================

var current_test_time: float = 0.0

var wait_timer: float = 0.0


# =========================================================
# DEBUG
# =========================================================

var status_label: Label

var current_status: String = "IDLE"


# =========================================================
# CONTROL DEL ENTORNO QA
# =========================================================

var previous_automatic_faults: bool = false

var automatic_faults_were_saved: bool = false

var degradation_states: Dictionary = {}


# =========================================================
# READY
# =========================================================

func _ready():

	create_debug_label()

	update_debug_label()


	if start_on_run:

		call_deferred(
			"start_test"
		)


# =========================================================
# INICIAR TEST
# =========================================================

func start_test():

	velocity = Vector2.ZERO

	test_queue.clear()

	current_test = {}

	current_target = null

	completed_tests = 0

	failed_tests = 0

	current_test_time = 0.0


	build_test_queue()


	if test_queue.is_empty():

		fail_complete_test(
			"NO TESTS"
		)

		return


	prepare_qa_environment()


	print("")
	print("==============================")
	print(" QA BOT - START")
	print("==============================")


	start_next_test()


# =========================================================
# CREAR COLA DE TESTS
# =========================================================

func build_test_queue():

	match test_mode:

		0:

			add_machine_test(
				"WATER PUMP",
				"../PumpRepairPoint",
				"wrench"
			)


		1:

			add_machine_test(
				"PRESSURE REGULATOR",
				"../PressureRegulatorRepairPoint",
				"wrench"
			)


		2:

			add_machine_test(
				"REACTOR",
				"../ReactorRepairPoint",
				"screwdriver"
			)


		3:

			add_machine_test(
				"OXYGEN GENERATOR",
				"../OxygenGeneratorRepairPoint",
				"screwdriver"
			)


		4:

			add_hull_test()


		5:

			add_machine_test(
				"WATER PUMP",
				"../PumpRepairPoint",
				"wrench"
			)

			add_machine_test(
				"PRESSURE REGULATOR",
				"../PressureRegulatorRepairPoint",
				"wrench"
			)

			add_machine_test(
				"REACTOR",
				"../ReactorRepairPoint",
				"screwdriver"
			)

			add_machine_test(
				"OXYGEN GENERATOR",
				"../OxygenGeneratorRepairPoint",
				"screwdriver"
			)

			add_hull_test()


		6:

			add_fault_test(
				"WATER PUMP",
				"../PumpRepairPoint",
				"wrench",
				"water_pump"
			)

			add_fault_test(
				"PRESSURE REGULATOR",
				"../PressureRegulatorRepairPoint",
				"wrench",
				"pressure_regulator"
			)

			add_fault_test(
				"REACTOR",
				"../ReactorRepairPoint",
				"screwdriver",
				"reactor"
			)

			add_fault_test(
				"OXYGEN GENERATOR",
				"../OxygenGeneratorRepairPoint",
				"screwdriver",
				"oxygen_generator"
			)


# =========================================================
# TEST DE MÁQUINA NORMAL
# =========================================================

func add_machine_test(
	display_name: String,
	target_path: String,
	tool_id: String
):

	test_queue.append(
		{
			"name": display_name,
			"target_path": target_path,
			"tool": tool_id,
			"type": "machine",
			"force_fault": false
		}
	)


# =========================================================
# TEST DE AVERÍA
# =========================================================

func add_fault_test(
	display_name: String,
	target_path: String,
	tool_id: String,
	machine_id: String
):

	test_queue.append(
		{
			"name": display_name,
			"target_path": target_path,
			"tool": tool_id,
			"type": "machine",
			"force_fault": true,
			"machine_id": machine_id
		}
	)


# =========================================================
# TEST DE CASCO
# =========================================================

func add_hull_test():

	test_queue.append(
		{
			"name": "HULL BREACH",
			"target_path": "../HullBreach",
			"tool": "welding_tool",
			"type": "hull",
			"force_fault": false
		}
	)


# =========================================================
# PREPARAR ENTORNO QA
# =========================================================

func prepare_qa_environment():

	# -----------------------------------------------------
	# PAUSAR AVERÍAS ALEATORIAS DURANTE QA
	# -----------------------------------------------------

	if failure_system != null:

		previous_automatic_faults = (
			failure_system.automatic_faults_enabled
		)

		automatic_faults_were_saved = true

		failure_system.automatic_faults_enabled = false


	# -----------------------------------------------------
	# PAUSAR DEGRADACIÓN DURANTE TESTS
	#
	# Así medimos exclusivamente lo que estamos probando.
	# -----------------------------------------------------

	degradation_states.clear()


	var repair_points: Array = [
		get_node_or_null(
			"../PumpRepairPoint"
		),
		get_node_or_null(
			"../PressureRegulatorRepairPoint"
		),
		get_node_or_null(
			"../ReactorRepairPoint"
		),
		get_node_or_null(
			"../OxygenGeneratorRepairPoint"
		)
	]


	for repair_point in repair_points:

		if repair_point == null:
			continue


		degradation_states[
			repair_point
		] = (
			repair_point.automatic_degradation_enabled
		)


		repair_point.automatic_degradation_enabled = false


# =========================================================
# RESTAURAR ENTORNO
# =========================================================

func restore_qa_environment():

	if (
		failure_system != null
		and automatic_faults_were_saved
	):

		failure_system.automatic_faults_enabled = (
			previous_automatic_faults
		)


	automatic_faults_were_saved = false


	for repair_point in degradation_states.keys():

		if not is_instance_valid(
			repair_point
		):
			continue


		repair_point.automatic_degradation_enabled = bool(
			degradation_states[
				repair_point
			]
		)


	degradation_states.clear()


# =========================================================
# SIGUIENTE TEST
# =========================================================

func start_next_test():

	if test_queue.is_empty():

		finish_test_suite()

		return


	current_test = test_queue.pop_front()


	var target_path: String = str(
		current_test.get(
			"target_path",
			""
		)
	)


	current_target = get_node_or_null(
		target_path
	)


	if current_target == null:

		fail_current_test(
			"TARGET NOT FOUND"
		)

		return


	current_test_time = 0.0


	prepare_current_test()


# =========================================================
# PREPARAR TEST ACTUAL
# =========================================================

func prepare_current_test():

	var test_name: String = str(
		current_test.get(
			"name",
			"UNKNOWN"
		)
	)


	var test_type: String = str(
		current_test.get(
			"type",
			""
		)
	)


	var tool_id: String = str(
		current_test.get(
			"tool",
			""
		)
	)


	var force_fault: bool = bool(
		current_test.get(
			"force_fault",
			false
		)
	)


	set_status(
		"PREPARING\n"
		+ test_name
	)


	# =====================================================
	# HERRAMIENTA
	# =====================================================

	if not inventory.has_item(
		tool_id,
		1
	):

		var added: bool = inventory.add_item(
			tool_id,
			1
		)


		if not added:

			fail_current_test(
				"CANNOT ADD TOOL"
			)

			return


	var equipped: bool = equipment.equip_item(
		tool_id
	)


	if not equipped:

		fail_current_test(
			"CANNOT EQUIP "
			+ tool_id
		)

		return


	# =====================================================
	# CASCO
	# =====================================================

	if test_type == "hull":

		if not inventory.has_item(
			"welding_fuel",
			1
		):

			var fuel_added: bool = (
				inventory.add_item(
					"welding_fuel",
					1
				)
			)


			if not fuel_added:

				fail_current_test(
					"CANNOT ADD FUEL"
				)

				return


		if (
			current_target.has_method(
				"is_repaired"
			)
			and current_target.is_repaired()
		):

			pass_current_test(
				"ALREADY REPAIRED"
			)

			return


	# =====================================================
	# MÁQUINA
	# =====================================================

	if test_type == "machine":

		if force_fault:

			if not prepare_fault_test():

				return

		else:

			prepare_standard_repair_test()


	# =====================================================
	# POSICIONAR BOT
	# =====================================================

	position_bot_near_target()


	state = BotState.MOVING


	set_status(
		"MOVING\n"
		+ test_name
	)


# =========================================================
# PREPARAR REPARACIÓN NORMAL
# =========================================================

func prepare_standard_repair_test():

	if not current_target.has_method(
		"get_condition"
	):
		return


	var condition: float = (
		current_target.get_condition()
	)


	# La prueba de reparación clásica siempre
	# comienza alrededor de 40%.
	if condition > 40.0:

		if current_target.has_method(
			"apply_damage"
		):

			current_target.apply_damage(
				condition - 40.0,
				"QA TEST DAMAGE"
			)


# =========================================================
# PREPARAR TEST DE AVERÍA
# =========================================================

func prepare_fault_test() -> bool:

	if failure_system == null:

		fail_current_test(
			"NO FAILURE SYSTEM"
		)

		return false


	if not current_target.has_method(
		"get_condition"
	):

		fail_current_test(
			"NO CONDITION"
		)

		return false


	var initial_condition: float = (
		current_target.get_condition()
	)


	# Los Fault Tests se realizan desde una
	# máquina prácticamente nueva.
	if initial_condition < 99.0:

		fail_current_test(
			"START CONDITION NOT 100%"
		)

		return false


	var machine_id: String = str(
		current_test.get(
			"machine_id",
			""
		)
	)


	var fault_created: bool = (
		failure_system.force_fault(
			machine_id,
			"major"
		)
	)


	if not fault_created:

		fail_current_test(
			"FAULT NOT CREATED"
		)

		return false


	var damaged_condition: float = (
		current_target.get_condition()
	)


	var condition_loss: float = (
		initial_condition
		- damaged_condition
	)


	# MAJOR actualmente equivale a -25.
	# Dejamos una pequeña tolerancia.
	if (
		condition_loss < 24.0
		or condition_loss > 26.0
	):

		fail_current_test(
			"INVALID FAULT DAMAGE"
		)

		return false


	print(
		"[QA BOT] FAULT VERIFIED - ",
		machine_id,
		" - CONDITION ",
		initial_condition,
		" -> ",
		damaged_condition
	)


	set_status(
		"FAULT VERIFIED\n"
		+ str(
			current_test.get(
				"name",
				""
			)
		)
		+ "\n"
		+ str(
			int(
				round(
					damaged_condition
				)
			)
		)
		+ "%"
	)


	return true


# =========================================================
# POSICIONAR CERCA
# =========================================================

func position_bot_near_target():

	if not current_target is Node2D:
		return


	var target_position: Vector2 = (
		current_target.global_position
	)


	var horizontal_offset: float = -130.0


	if target_position.x < 320.0:

		horizontal_offset = 130.0


	global_position = (
		target_position
		+ Vector2(
			horizontal_offset,
			0.0
		)
	)


# =========================================================
# PHYSICS
# =========================================================

func _physics_process(
	delta
):

	match state:

		BotState.MOVING:

			process_movement(
				delta
			)


		BotState.REPAIRING:

			process_repair(
				delta
			)


		BotState.WAITING:

			process_waiting(
				delta
			)


# =========================================================
# MOVIMIENTO
# =========================================================

func process_movement(
	delta: float
):

	if current_target == null:

		fail_current_test(
			"TARGET LOST"
		)

		return


	if not current_target is Node2D:

		fail_current_test(
			"TARGET NOT NODE2D"
		)

		return


	current_test_time += delta


	if current_test_time > test_timeout:

		fail_current_test(
			"MOVE TIMEOUT"
		)

		return


	var target_position: Vector2 = (
		current_target.global_position
	)


	var difference: Vector2 = (
		target_position
		- global_position
	)


	var distance: float = (
		difference.length()
	)


	if distance <= interaction_distance:

		velocity = Vector2.ZERO

		state = BotState.REPAIRING

		current_test_time = 0.0


		set_status(
			"REPAIRING\n"
			+ str(
				current_test.get(
					"name",
					""
				)
			)
		)

		return


	velocity = (
		difference.normalized()
		* movement_speed
	)


	move_and_slide()


# =========================================================
# REPARACIÓN
# =========================================================

func process_repair(
	delta: float
):

	if current_target == null:

		fail_current_test(
			"TARGET LOST"
		)

		return


	current_test_time += delta


	if current_test_time > test_timeout:

		fail_current_test(
			"REPAIR TIMEOUT"
		)

		return


	if current_target.has_method(
		"interact_hold"
	):

		current_target.interact_hold(
			self,
			delta
		)

	else:

		fail_current_test(
			"NO INTERACT_HOLD"
		)

		return


	var test_type: String = str(
		current_test.get(
			"type",
			""
		)
	)


	# =====================================================
	# MÁQUINA
	# =====================================================

	if test_type == "machine":

		if current_target.has_method(
			"is_fully_repaired"
		):

			if current_target.is_fully_repaired():

				if current_target.has_method(
					"interact_release"
				):

					current_target.interact_release(
						self
					)


				var force_fault: bool = bool(
					current_test.get(
						"force_fault",
						false
					)
				)


				if force_fault:

					pass_current_test(
						"FAULT RECOVERED"
					)

				else:

					pass_current_test(
						"100% CONDITION"
					)


	# =====================================================
	# CASCO
	# =====================================================

	elif test_type == "hull":

		if current_target.has_method(
			"is_repaired"
		):

			if current_target.is_repaired():

				validate_hull_repair()


# =========================================================
# VALIDAR CASCO
# =========================================================

func validate_hull_repair():

	var tool_ok: bool = inventory.has_item(
		"welding_tool",
		1
	)


	var fuel_consumed: bool = (
		not inventory.has_item(
			"welding_fuel",
			1
		)
	)


	if not tool_ok:

		fail_current_test(
			"WELDING TOOL WAS LOST"
		)

		return


	if not fuel_consumed:

		fail_current_test(
			"FUEL NOT CONSUMED"
		)

		return


	pass_current_test(
		"HULL REPAIRED"
	)


# =========================================================
# PASS
# =========================================================

func pass_current_test(
	detail: String
):

	var test_name: String = str(
		current_test.get(
			"name",
			"UNKNOWN"
		)
	)


	completed_tests += 1


	print(
		"[QA BOT] PASS - ",
		test_name,
		" - ",
		detail
	)


	set_status(
		"PASS\n"
		+ test_name
	)


	velocity = Vector2.ZERO


	state = BotState.WAITING

	wait_timer = time_between_tests


# =========================================================
# FAIL
# =========================================================

func fail_current_test(
	reason: String
):

	var test_name: String = str(
		current_test.get(
			"name",
			"UNKNOWN"
		)
	)


	failed_tests += 1


	print(
		"[QA BOT] FAIL - ",
		test_name,
		" - ",
		reason
	)


	set_status(
		"FAIL\n"
		+ test_name
		+ "\n"
		+ reason
	)


	velocity = Vector2.ZERO


	state = BotState.WAITING

	wait_timer = time_between_tests


# =========================================================
# FALLA GENERAL
# =========================================================

func fail_complete_test(
	reason: String
):

	failed_tests += 1

	state = BotState.FAILED


	restore_qa_environment()


	set_status(
		"FAILED\n"
		+ reason
	)


	print(
		"[QA BOT] FAILED - ",
		reason
	)


# =========================================================
# ESPERA
# =========================================================

func process_waiting(
	delta: float
):

	wait_timer -= delta


	if wait_timer > 0.0:
		return


	start_next_test()


# =========================================================
# FINAL
# =========================================================

func finish_test_suite():

	velocity = Vector2.ZERO


	restore_qa_environment()


	print("==============================")
	print(" QA BOT RESULTS")
	print(
		" PASSED: ",
		completed_tests
	)
	print(
		" FAILED: ",
		failed_tests
	)
	print("==============================")


	if failed_tests <= 0:

		state = BotState.PASSED


		set_status(
			"ALL TESTS PASS\n"
			+ str(
				completed_tests
			)
			+ " / "
			+ str(
				completed_tests
			)
		)


	else:

		state = BotState.FAILED


		set_status(
			"TESTS FINISHED\n"
			+ "PASS: "
			+ str(
				completed_tests
			)
			+ "\nFAIL: "
			+ str(
				failed_tests
			)
		)


# =========================================================
# LABEL DEBUG
# =========================================================

func create_debug_label():

	status_label = Label.new()


	status_label.name = "QABotLabel"


	status_label.position = Vector2(
		-85,
		-75
	)


	status_label.size = Vector2(
		170,
		65
	)


	status_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	status_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)


	status_label.add_theme_font_size_override(
		"font_size",
		13
	)


	status_label.add_theme_constant_override(
		"outline_size",
		4
	)


	status_label.add_theme_color_override(
		"font_outline_color",
		Color(
			0.0,
			0.0,
			0.0,
			1.0
		)
	)


	status_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	status_label.z_index = 150


	add_child(
		status_label
	)


# =========================================================
# ESTADO DEBUG
# =========================================================

func set_status(
	text: String
):

	current_status = text

	update_debug_label()


func update_debug_label():

	if status_label == null:
		return


	status_label.text = (
		"QA BOT\n"
		+ current_status
	)


	queue_redraw()


# =========================================================
# VISUAL
# =========================================================

func _draw():

	draw_circle(
		Vector2.ZERO,
		16.0,
		Color(
			0.75,
			0.75,
			0.80,
			1.0
		)
	)


	draw_circle(
		Vector2.ZERO,
		7.0,
		Color(
			0.20,
			0.55,
			0.85,
			1.0
		)
	)
