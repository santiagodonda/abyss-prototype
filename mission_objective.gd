extends Node


# =========================================================
# ETAPAS
# =========================================================

enum ObjectiveStage {
	IDLE,
	TRAVEL,
	ENCOUNTER,
	COMPLETE
}


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("Mission")

@export var target_depth: float = 700.0

@export var depth_tolerance: float = 5.0

@export var encounter_creature_count: int = 3

@export var auto_start_on_run: bool = true


@export_group("Debug")

@export var print_stage_changes: bool = true


# =========================================================
# REFERENCIAS
# =========================================================

@onready var mission_state = (
	get_node_or_null(
		"../MissionState"
	)
)


@onready var encounter_manager = (
	get_node_or_null(
		"../EncounterManager"
	)
)


@onready var submarine_environment = (
	get_node_or_null(
		"../SubmarineEnvironment"
	)
)


# =========================================================
# ESTADO
# =========================================================

var current_stage: ObjectiveStage = (
	ObjectiveStage.IDLE
)

var encounter_started: bool = false


# =========================================================
# READY
# =========================================================

func _ready():

	if mission_state == null:

		push_error(
			"MissionObjective: MissionState no encontrado."
		)


	if encounter_manager == null:

		push_error(
			"MissionObjective: EncounterManager no encontrado."
		)


	if submarine_environment == null:

		push_error(
			"MissionObjective: SubmarineEnvironment no encontrado."
		)


	if auto_start_on_run:

		call_deferred(
			"start_mission"
		)


# =========================================================
# AUTHORITY
# =========================================================

func has_mission_authority() -> bool:

	if not NetworkManager.is_online():
		return true


	return NetworkManager.is_host()


# =========================================================
# PROCESS
# =========================================================

func _process(
	_delta: float
):

	if current_stage == ObjectiveStage.IDLE:
		return


	if current_stage == ObjectiveStage.COMPLETE:
		return


	if not has_mission_authority():
		return


	if mission_state == null:
		return


	if not mission_state.is_running():
		return


	match current_stage:

		ObjectiveStage.TRAVEL:

			process_travel_stage()


		ObjectiveStage.ENCOUNTER:

			process_encounter_stage()


# =========================================================
# START
# =========================================================

func start_mission() -> bool:

	if not has_mission_authority():
		return false


	if mission_state == null:
		return false


	if encounter_manager == null:
		return false


	if submarine_environment == null:
		return false


	if not mission_state.is_running():
		return false


	encounter_manager.stop_encounter(
		true
	)


	encounter_started = false


	set_stage(
		ObjectiveStage.TRAVEL
	)


	return true


# =========================================================
# VIAJE
# =========================================================

func process_travel_stage():

	if not has_mission_authority():
		return


	var current_depth: float = (
		get_current_depth()
	)


	if (
		current_depth
		< target_depth
		- depth_tolerance
	):

		return


	begin_encounter()


# =========================================================
# INICIAR ENCUENTRO
# =========================================================

func begin_encounter():

	if not has_mission_authority():
		return


	if encounter_started:
		return


	encounter_started = true


	var started: bool = (
		encounter_manager.start_encounter(
			encounter_creature_count
		)
	)


	if not started:

		encounter_started = false


		push_warning(
			"MissionObjective: no se pudo iniciar el encounter."
		)

		return


	set_stage(
		ObjectiveStage.ENCOUNTER
	)


# =========================================================
# ENCOUNTER
# =========================================================

func process_encounter_stage():

	if not has_mission_authority():
		return


	if not encounter_started:
		return


	if not encounter_manager.is_encounter_complete():
		return


	complete_objective()


# =========================================================
# COMPLETAR OBJETIVO
# =========================================================

func complete_objective():

	if not has_mission_authority():
		return


	if current_stage == ObjectiveStage.COMPLETE:
		return


	set_stage(
		ObjectiveStage.COMPLETE
	)


	if mission_state != null:

		mission_state.complete_mission(
			"TARGET DEPTH REACHED\n"
			+ "ENCOUNTER SURVIVED"
		)


# =========================================================
# DEPTH
# =========================================================

func get_current_depth() -> float:

	if submarine_environment == null:
		return 0.0


	return float(
		submarine_environment.get(
			"depth_meters"
		)
	)


# =========================================================
# ETAPA AUTORITATIVA
# =========================================================

func set_stage(
	new_stage: ObjectiveStage
):

	if not has_mission_authority():
		return


	set_stage_internal(
		new_stage,
		"AUTH"
	)


# =========================================================
# APLICAR ETAPA DESDE NETWORK
# =========================================================

func apply_network_stage(
	new_stage_name: String,
	new_encounter_started: bool
) -> bool:

	if not NetworkManager.is_online():
		return false


	if NetworkManager.is_host():
		return false


	var parsed_stage: int = (
		get_stage_from_name(
			new_stage_name
		)
	)


	if parsed_stage < 0:
		return false


	encounter_started = (
		new_encounter_started
	)


	set_stage_internal(
		parsed_stage,
		"NET"
	)


	return true


# =========================================================
# SET INTERNAL
# =========================================================

func set_stage_internal(
	new_stage: ObjectiveStage,
	source: String
):

	if current_stage == new_stage:
		return


	var previous_name: String = (
		get_stage_name()
	)


	current_stage = new_stage


	if print_stage_changes:

		print(
			"[MISSION OBJECTIVE][",
			source,
			"] ",
			previous_name,
			" -> ",
			get_stage_name()
		)


# =========================================================
# STAGE FROM NAME
# =========================================================

func get_stage_from_name(
	stage_name: String
) -> int:

	match stage_name:

		"IDLE":
			return ObjectiveStage.IDLE

		"TRAVEL":
			return ObjectiveStage.TRAVEL

		"ENCOUNTER":
			return ObjectiveStage.ENCOUNTER

		"COMPLETE":
			return ObjectiveStage.COMPLETE


	return -1


# =========================================================
# RESET QA
# =========================================================

func reset_for_qa(
	start_active: bool = false
):

	if (
		NetworkManager.is_online()
		and not NetworkManager.is_host()
	):

		return


	if encounter_manager != null:

		encounter_manager.stop_encounter(
			true
		)


	current_stage = (
		ObjectiveStage.IDLE
	)


	encounter_started = false


	if start_active:

		start_mission()


# =========================================================
# CONSULTAS
# =========================================================

func get_stage_name() -> String:

	match current_stage:

		ObjectiveStage.IDLE:
			return "IDLE"

		ObjectiveStage.TRAVEL:
			return "TRAVEL"

		ObjectiveStage.ENCOUNTER:
			return "ENCOUNTER"

		ObjectiveStage.COMPLETE:
			return "COMPLETE"


	return "UNKNOWN"


func is_active() -> bool:

	return (
		current_stage
		!= ObjectiveStage.IDLE
		and current_stage
		!= ObjectiveStage.COMPLETE
	)


func is_complete() -> bool:

	return (
		current_stage
		== ObjectiveStage.COMPLETE
	)


func get_target_depth() -> float:

	return target_depth
