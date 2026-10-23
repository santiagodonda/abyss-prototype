extends Node


# =========================================================
# AVERÍAS AUTOMÁTICAS
# =========================================================

@export_group("Automatic Faults")

@export var automatic_faults_enabled: bool = true

# Cada cuántos segundos evaluamos posibles averías.
@export var check_interval: float = 10.0

# Probabilidad base por chequeo.
# 0.003 = 0.3%
@export_range(
	0.0,
	1.0,
	0.001
)
var base_fault_chance: float = 0.003

# Una máquina encendida tiene mayor probabilidad.
@export var active_machine_multiplier: float = 2.0

# Una máquina deteriorada es más propensa a fallar.
@export var damaged_machine_multiplier: float = 2.0

# El agua aumenta mucho el riesgo.
@export var underwater_multiplier: float = 3.0

# Evita que una misma máquina reciba
# averías repetidamente en pocos segundos.
@export var fault_cooldown: float = 45.0


# =========================================================
# SEVERIDAD
# =========================================================

@export_group("Fault Damage")

@export var minor_fault_damage: float = 10.0

@export var major_fault_damage: float = 25.0

@export var severe_fault_damage: float = 40.0

@export_range(
	0.0,
	1.0,
	0.05
)
var major_fault_probability: float = 0.30

@export_range(
	0.0,
	1.0,
	0.05
)
var severe_fault_probability: float = 0.10


# =========================================================
# TESTING
# =========================================================

@export_group("Testing")

# Para probar una avería inmediatamente al iniciar.
@export var test_fault_on_start: bool = false

@export_enum(
	"Water Pump",
	"Pressure Regulator",
	"Reactor",
	"Oxygen Generator",
	"All"
)
var test_fault_mode: int = 0

@export var test_fault_delay: float = 1.0


# =========================================================
# DEBUG
# =========================================================

@export_group("Debug")

@export var show_fault_label: bool = true

@export var fault_label_duration: float = 4.0

@export var print_faults: bool = true


# =========================================================
# ESTADO INTERNO
# =========================================================

var check_accumulator: float = 0.0

var rng := RandomNumberGenerator.new()

var machines: Dictionary = {}

var cooldowns: Dictionary = {}

var last_event_text: String = "NONE"


# =========================================================
# INICIALIZACIÓN
# =========================================================

func _ready():

	rng.randomize()

	resolve_machines()


	if test_fault_on_start:

		call_deferred(
			"run_test_fault"
		)


# =========================================================
# LOCALIZAR MÁQUINAS
# =========================================================

func resolve_machines():

	machines.clear()


	register_machine(
		"water_pump",
		"../PumpRepairPoint"
	)


	register_machine(
		"pressure_regulator",
		"../PressureRegulatorRepairPoint"
	)


	register_machine(
		"reactor",
		"../ReactorRepairPoint"
	)


	register_machine(
		"oxygen_generator",
		"../OxygenGeneratorRepairPoint"
	)


func register_machine(
	machine_id: String,
	node_path: String
):

	var repair_point = get_node_or_null(
		node_path
	)


	if repair_point == null:

		push_warning(
			"MachineFailureSystem: "
			+ machine_id
			+ " no encontrado."
		)

		return


	machines[machine_id] = repair_point

	cooldowns[machine_id] = 0.0


# =========================================================
# SIMULACIÓN
# =========================================================

func _process(
	delta
):

	update_cooldowns(
		delta
	)


	if not automatic_faults_enabled:
		return


	check_accumulator += delta


	if check_accumulator < check_interval:
		return


	check_accumulator = 0.0


	check_for_faults()


# =========================================================
# COOLDOWNS
# =========================================================

func update_cooldowns(
	delta: float
):

	for machine_id in cooldowns.keys():

		var current_value: float = float(
			cooldowns[
				machine_id
			]
		)


		if current_value <= 0.0:
			continue


		cooldowns[
			machine_id
		] = max(
			current_value - delta,
			0.0
		)


# =========================================================
# COMPROBAR AVERÍAS
# =========================================================

func check_for_faults():

	for machine_id in machines.keys():

		var repair_point = machines[
			machine_id
		]


		if not is_instance_valid(
			repair_point
		):
			continue


		if float(
			cooldowns.get(
				machine_id,
				0.0
			)
		) > 0.0:

			continue


		if repair_point.is_broken():
			continue


		if repair_point.is_being_repaired:
			continue


		var chance: float = (
			calculate_fault_chance(
				repair_point
			)
		)


		if rng.randf() <= chance:

			trigger_random_fault(
				str(machine_id)
			)


# =========================================================
# CALCULAR PROBABILIDAD
# =========================================================

func calculate_fault_chance(
	repair_point
) -> float:

	var chance: float = (
		base_fault_chance
	)


	# -----------------------------------------------------
	# MÁQUINA ACTIVA
	# -----------------------------------------------------

	if repair_point.has_method(
		"is_device_active"
	):

		if repair_point.is_device_active():

			chance *= (
				active_machine_multiplier
			)


	# -----------------------------------------------------
	# CONDICIÓN
	# -----------------------------------------------------

	var condition_ratio: float = (
		repair_point.get_condition_ratio()
	)


	var damage_factor: float = (
		1.0
		+ (
			1.0
			- condition_ratio
		)
		* damaged_machine_multiplier
	)


	chance *= damage_factor


	# -----------------------------------------------------
	# INUNDACIÓN
	# -----------------------------------------------------

	if repair_point.has_method(
		"is_device_underwater"
	):

		if repair_point.is_device_underwater():

			chance *= (
				underwater_multiplier
			)


	return clamp(
		chance,
		0.0,
		0.75
	)


# =========================================================
# GENERAR AVERÍA
# =========================================================

func trigger_random_fault(
	machine_id: String
) -> bool:

	var repair_point = machines.get(
		machine_id
	)


	if repair_point == null:
		return false


	var severity_roll: float = (
		rng.randf()
	)


	var damage: float

	var severity_name: String


	if severity_roll <= severe_fault_probability:

		damage = severe_fault_damage

		severity_name = "SEVERE"


	elif severity_roll <= (
		severe_fault_probability
		+ major_fault_probability
	):

		damage = major_fault_damage

		severity_name = "MAJOR"


	else:

		damage = minor_fault_damage

		severity_name = "MINOR"


	var fault_name: String = (
		get_fault_name(
			repair_point
		)
	)


	apply_fault(
		machine_id,
		fault_name,
		severity_name,
		damage
	)


	return true


# =========================================================
# NOMBRE DE AVERÍA
# =========================================================

func get_fault_name(
	repair_point
) -> String:

	var repair_type: String = str(
		repair_point.repair_type
	)


	match repair_type:

		"mechanical":

			return "MECHANICAL JAM"


		"electrical":

			return "ELECTRICAL SHORT"


	return "SYSTEM FAILURE"


# =========================================================
# APLICAR AVERÍA
# =========================================================

func apply_fault(
	machine_id: String,
	fault_name: String,
	severity_name: String,
	damage: float
):

	var repair_point = machines.get(
		machine_id
	)


	if repair_point == null:
		return


	var device_name: String = str(
		repair_point.device_name
	)


	repair_point.apply_damage(
		damage,
		fault_name
	)


	cooldowns[
		machine_id
	] = fault_cooldown


	last_event_text = (
		device_name
		+ " | "
		+ fault_name
		+ " | "
		+ severity_name
		+ " -"
		+ str(
			int(
				round(
					damage
				)
			)
		)
		+ "%"
	)


	if print_faults:

		print(
			"[FAULT] ",
			last_event_text
		)


	if show_fault_label:

		show_fault_message(
			repair_point,
			fault_name,
			severity_name,
			damage
		)


# =========================================================
# MENSAJE VISUAL
# =========================================================

func show_fault_message(
	repair_point,
	fault_name: String,
	severity_name: String,
	damage: float
):

	var old_label = repair_point.get_node_or_null(
		"FaultEventLabel"
	)


	if old_label != null:

		old_label.queue_free()


	var label := Label.new()


	label.name = "FaultEventLabel"


	label.text = (
		"FAULT!\n"
		+ fault_name
		+ "\n"
		+ severity_name
		+ "  -"
		+ str(
			int(
				round(
					damage
				)
			)
		)
		+ "%"
	)


	label.position = Vector2(
		-100,
		-125
	)


	label.size = Vector2(
		200,
		70
	)


	label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)


	label.add_theme_font_size_override(
		"font_size",
		13
	)


	label.add_theme_constant_override(
		"outline_size",
		4
	)


	label.add_theme_color_override(
		"font_outline_color",
		Color(
			0.0,
			0.0,
			0.0,
			1.0
		)
	)


	label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	label.z_index = 160


	repair_point.add_child(
		label
	)


	remove_fault_label_later(
		label
	)


# =========================================================
# QUITAR MENSAJE
# =========================================================

func remove_fault_label_later(
	label: Label
):

	await get_tree().create_timer(
		fault_label_duration
	).timeout


	if is_instance_valid(
		label
	):

		label.queue_free()


# =========================================================
# TEST MANUAL
# =========================================================

func run_test_fault():

	await get_tree().create_timer(
		test_fault_delay
	).timeout


	match test_fault_mode:

		0:

			force_fault(
				"water_pump",
				"major"
			)


		1:

			force_fault(
				"pressure_regulator",
				"major"
			)


		2:

			force_fault(
				"reactor",
				"major"
			)


		3:

			force_fault(
				"oxygen_generator",
				"major"
			)


		4:

			force_fault(
				"water_pump",
				"major"
			)


			await get_tree().create_timer(
				0.5
			).timeout


			force_fault(
				"pressure_regulator",
				"major"
			)


			await get_tree().create_timer(
				0.5
			).timeout


			force_fault(
				"reactor",
				"major"
			)


			await get_tree().create_timer(
				0.5
			).timeout


			force_fault(
				"oxygen_generator",
				"major"
			)


# =========================================================
# FORZAR AVERÍA
# =========================================================

func force_fault(
	machine_id: String,
	severity: String = "major"
) -> bool:

	var repair_point = machines.get(
		machine_id
	)


	if repair_point == null:

		push_warning(
			"MachineFailureSystem: máquina desconocida: "
			+ machine_id
		)

		return false


	var damage: float

	var severity_name: String


	match severity.to_lower():

		"minor":

			damage = minor_fault_damage

			severity_name = "MINOR"


		"severe":

			damage = severe_fault_damage

			severity_name = "SEVERE"


		_:

			damage = major_fault_damage

			severity_name = "MAJOR"


	var fault_name: String = (
		get_fault_name(
			repair_point
		)
	)


	apply_fault(
		machine_id,
		fault_name,
		severity_name,
		damage
	)


	return true


# =========================================================
# INFORMACIÓN
# =========================================================

func get_last_event_text() -> String:

	return last_event_text
