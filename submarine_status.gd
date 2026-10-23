extends Node


# =========================================================
# ESTADOS
# =========================================================

enum SubmarineState {
	NORMAL,
	CAUTION,
	DANGER,
	CRITICAL,
	LOST
}


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("Flooding Thresholds")

@export_range(
	0.0,
	1.0,
	0.01
)
var caution_water_level: float = 0.25


@export_range(
	0.0,
	1.0,
	0.01
)
var danger_water_level: float = 0.60


@export_range(
	0.0,
	1.0,
	0.01
)
var critical_water_level: float = 0.85


@export_range(
	0.0,
	1.0,
	0.01
)
var lost_water_level: float = 0.95


@export_group("Machine Thresholds")

@export_range(
	0.0,
	1.0,
	0.01
)
var worn_machine_ratio: float = 0.75


@export_range(
	0.0,
	1.0,
	0.01
)
var damaged_machine_ratio: float = 0.50


@export_range(
	0.0,
	1.0,
	0.01
)
var critical_machine_ratio: float = 0.25


@export_group("Loss Condition")

# El submarino no se declara perdido de inmediato.
# La condición catastrófica debe mantenerse.
@export var lost_condition_time: float = 8.0


@export_group("Simulation")

@export var simulation_interval: float = 0.20


@export_group("Debug")

@export var print_state_changes: bool = true


# =========================================================
# REFERENCIAS
# =========================================================

@onready var room_left = (
	get_node_or_null("../RoomLeft")
)


@onready var room_right = (
	get_node_or_null("../RoomRight")
)


@onready var hull_breach = (
	get_node_or_null("../HullBreach")
)


@onready var reactor_repair_point = (
	get_node_or_null("../ReactorRepairPoint")
)


@onready var oxygen_generator_repair_point = (
	get_node_or_null("../OxygenGeneratorRepairPoint")
)


@onready var pump_repair_point = (
	get_node_or_null("../PumpRepairPoint")
)


@onready var pressure_regulator_repair_point = (
	get_node_or_null("../PressureRegulatorRepairPoint")
)


# =========================================================
# ESTADO INTERNO
# =========================================================

var current_state: SubmarineState = (
	SubmarineState.NORMAL
)


var risk_score: int = 0

var simulation_accumulator: float = 0.0

var lost_condition_timer: float = 0.0


var last_reason_text: String = "SYSTEMS NOMINAL"


# =========================================================
# INICIALIZACIÓN
# =========================================================

func _ready():

	validate_references()

	evaluate_submarine_state()


# =========================================================
# VALIDAR REFERENCIAS
# =========================================================

func validate_references():

	if room_left == null:

		push_warning(
			"SubmarineStatus: RoomLeft no encontrado."
		)


	if room_right == null:

		push_warning(
			"SubmarineStatus: RoomRight no encontrado."
		)


	if hull_breach == null:

		push_warning(
			"SubmarineStatus: HullBreach no encontrado."
		)


	var repair_points: Dictionary = {
		"ReactorRepairPoint":
			reactor_repair_point,

		"OxygenGeneratorRepairPoint":
			oxygen_generator_repair_point,

		"PumpRepairPoint":
			pump_repair_point,

		"PressureRegulatorRepairPoint":
			pressure_regulator_repair_point
	}


	for repair_name in repair_points.keys():

		if repair_points[repair_name] == null:

			push_warning(
				"SubmarineStatus: "
				+ str(repair_name)
				+ " no encontrado."
			)


# =========================================================
# SIMULACIÓN
# =========================================================

func _process(
	delta: float
):

	simulation_accumulator += delta


	if simulation_accumulator < simulation_interval:
		return


	var simulation_delta: float = (
		simulation_accumulator
	)


	simulation_accumulator = 0.0


	evaluate_submarine_state(
		simulation_delta
	)


# =========================================================
# EVALUACIÓN GLOBAL
# =========================================================

func evaluate_submarine_state(
	delta: float = 0.0
):

	var new_risk_score: int = 0

	var reasons: Array[String] = []


	# -----------------------------------------------------
	# INUNDACIÓN
	# -----------------------------------------------------

	new_risk_score += evaluate_flooding(
		reasons
	)


	# -----------------------------------------------------
	# BRECHA DE CASCO
	# -----------------------------------------------------

	new_risk_score += evaluate_hull_breach(
		reasons
	)


	# -----------------------------------------------------
	# MAQUINARIA
	# -----------------------------------------------------

	new_risk_score += evaluate_machinery(
		reasons
	)


	risk_score = new_risk_score


	# -----------------------------------------------------
	# CONDICIÓN CATASTRÓFICA
	# -----------------------------------------------------

	var catastrophic: bool = (
		is_catastrophic_condition()
	)


	if catastrophic:

		lost_condition_timer += delta


	else:

		lost_condition_timer = 0.0


	# -----------------------------------------------------
	# DETERMINAR ESTADO
	# -----------------------------------------------------

	var new_state: SubmarineState


	if (
		catastrophic
		and lost_condition_timer
		>= lost_condition_time
	):

		new_state = (
			SubmarineState.LOST
		)


	elif risk_score >= 7:

		new_state = (
			SubmarineState.CRITICAL
		)


	elif risk_score >= 4:

		new_state = (
			SubmarineState.DANGER
		)


	elif risk_score >= 1:

		new_state = (
			SubmarineState.CAUTION
		)


	else:

		new_state = (
			SubmarineState.NORMAL
		)


	# -----------------------------------------------------
	# MOTIVO
	# -----------------------------------------------------

	if reasons.is_empty():

		last_reason_text = (
			"SYSTEMS NOMINAL"
		)


	else:

		last_reason_text = (
			" | ".join(
				reasons
			)
		)


	set_state(
		new_state
	)


# =========================================================
# INUNDACIÓN
# =========================================================

func evaluate_flooding(
	reasons: Array[String]
) -> int:

	if (
		room_left == null
		or room_right == null
	):

		return 0


	var left_water: float = (
		float(
			room_left.water_level
		)
	)


	var right_water: float = (
		float(
			room_right.water_level
		)
	)


	var maximum_water: float = max(
		left_water,
		right_water
	)


	var score: int = 0


	# -----------------------------------------------------
	# SALA MÁS AFECTADA
	# -----------------------------------------------------

	if maximum_water >= critical_water_level:

		score += 3

		reasons.append(
			"SEVERE FLOODING"
		)


	elif maximum_water >= danger_water_level:

		score += 2

		reasons.append(
			"FLOODING"
		)


	elif maximum_water >= caution_water_level:

		score += 1

		reasons.append(
			"WATER RISING"
		)


	# -----------------------------------------------------
	# LAS DOS SALAS AFECTADAS
	# -----------------------------------------------------

	if (
		left_water >= danger_water_level
		and right_water >= danger_water_level
	):

		score += 2

		reasons.append(
			"MULTIPLE ROOMS FLOODED"
		)


	return score


# =========================================================
# BRECHA
# =========================================================

func evaluate_hull_breach(
	reasons: Array[String]
) -> int:

	if hull_breach == null:
		return 0


	if not hull_breach.has_method(
		"is_repaired"
	):

		return 0


	if hull_breach.is_repaired():

		return 0


	reasons.append(
		"HULL BREACH"
	)


	# Una brecha abierta por sí sola
	# genera CAUTION.
	return 1


# =========================================================
# MAQUINARIA
# =========================================================

func evaluate_machinery(
	reasons: Array[String]
) -> int:

	var score: int = 0


	var machines: Array = [
		reactor_repair_point,
		oxygen_generator_repair_point,
		pump_repair_point,
		pressure_regulator_repair_point
	]


	var broken_count: int = 0

	var critical_count: int = 0

	var damaged_count: int = 0

	var worn_count: int = 0


	for machine in machines:

		if machine == null:
			continue


		if not machine.has_method(
			"get_condition_ratio"
		):

			continue


		var ratio: float = (
			machine.get_condition_ratio()
		)


		if ratio <= 0.0:

			broken_count += 1


		elif ratio < critical_machine_ratio:

			critical_count += 1


		elif ratio < damaged_machine_ratio:

			damaged_count += 1


		elif ratio < worn_machine_ratio:

			worn_count += 1


	# -----------------------------------------------------
	# PUNTUACIÓN
	# -----------------------------------------------------

	if broken_count > 0:

		score += (
			broken_count
			* 3
		)

		reasons.append(
			"BROKEN SYSTEM"
		)


	if critical_count > 0:

		score += (
			critical_count
			* 2
		)

		reasons.append(
			"CRITICAL MACHINERY"
		)


	if damaged_count > 0:

		score += (
			damaged_count
		)


		reasons.append(
			"DAMAGED MACHINERY"
		)


	# El desgaste normal genera como máximo
	# una advertencia leve.
	if (
		worn_count > 0
		and broken_count == 0
		and critical_count == 0
		and damaged_count == 0
	):

		score += 1

		reasons.append(
			"MACHINERY WORN"
		)


	return score


# =========================================================
# CONDICIÓN CATASTRÓFICA
# =========================================================

func is_catastrophic_condition() -> bool:

	if (
		room_left == null
		or room_right == null
	):

		return false


	var both_rooms_lost: bool = (
		room_left.water_level
		>= lost_water_level
		and room_right.water_level
		>= lost_water_level
	)


	return both_rooms_lost


# =========================================================
# CAMBIO DE ESTADO
# =========================================================

func set_state(
	new_state: SubmarineState
):

	if new_state == current_state:
		return


	var old_state: String = (
		get_state_name()
	)


	current_state = new_state


	if print_state_changes:

		print(
			"[SUBMARINE STATUS] ",
			old_state,
			" -> ",
			get_state_name(),
			" | Score: ",
			risk_score,
			" | ",
			last_reason_text
		)


# =========================================================
# CONSULTAS
# =========================================================

func get_state() -> SubmarineState:

	return current_state


func get_state_name() -> String:

	match current_state:

		SubmarineState.NORMAL:

			return "NORMAL"


		SubmarineState.CAUTION:

			return "CAUTION"


		SubmarineState.DANGER:

			return "DANGER"


		SubmarineState.CRITICAL:

			return "CRITICAL"


		SubmarineState.LOST:

			return "LOST"


	return "UNKNOWN"


func get_risk_score() -> int:

	return risk_score


func get_reason_text() -> String:

	return last_reason_text


func get_lost_timer() -> float:

	return lost_condition_timer


func get_lost_time_remaining() -> float:

	return max(
		lost_condition_time
		- lost_condition_timer,
		0.0
	)


func is_normal() -> bool:

	return (
		current_state
		== SubmarineState.NORMAL
	)


func is_lost() -> bool:

	return (
		current_state
		== SubmarineState.LOST
	)
