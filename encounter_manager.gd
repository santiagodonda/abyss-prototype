extends Node


signal encounter_started(
	creature_count: int
)

signal encounter_completed


# =========================================================
# RECURSOS
# =========================================================

const SEA_CREATURE_SCRIPT = preload(
	"res://sea_creature.gd"
)


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("Encounter")

@export var default_creature_count: int = 3

@export var spawn_distance: float = 420.0

@export var attack_submarine: bool = true


@export_group("Spawn")

@export var spawn_angle_min_degrees: float = -55.0

@export var spawn_angle_max_degrees: float = 55.0


@export_group("References")

@export var hull_target_path: NodePath = (
	NodePath("../HullIntegrityPoint")
)


@export_group("Debug")

@export var auto_start_on_run: bool = false

@export var show_spawned_labels: bool = true


# =========================================================
# REFERENCIAS
# =========================================================

@onready var hull_target = (
	get_node_or_null(
		hull_target_path
	)
)


# =========================================================
# ESTADO
# =========================================================

var encounter_active: bool = false

var encounter_finished: bool = false

var encounter_creatures: Array = []

var encounter_serial: int = 0


# =========================================================
# READY
# =========================================================

func _ready():

	if hull_target == null:

		push_error(
			"EncounterManager: HullIntegrityPoint no encontrado."
		)


	if auto_start_on_run:

		call_deferred(
			"start_encounter"
		)


# =========================================================
# AUTHORITY
# =========================================================

func has_encounter_authority() -> bool:

	if not NetworkManager.is_online():
		return true


	return NetworkManager.is_host()


# =========================================================
# PROCESS
# =========================================================

func _process(
	_delta: float
):

	if not has_encounter_authority():
		return


	if not encounter_active:
		return


	remove_invalid_references()


	if get_alive_count() > 0:
		return


	complete_encounter()


# =========================================================
# INICIAR ENCUENTRO
# =========================================================

func start_encounter(
	requested_count: int = -1
) -> bool:

	if not has_encounter_authority():
		return false


	if hull_target == null:
		return false


	clear_encounter_creatures()


	var creature_count: int = (
		requested_count
	)


	if creature_count < 0:

		creature_count = (
			default_creature_count
		)


	creature_count = max(
		creature_count,
		0
	)


	if creature_count <= 0:

		encounter_active = false

		encounter_finished = true

		return false


	encounter_serial += 1

	encounter_finished = false


	for index in range(
		creature_count
	):

		var spawn_position: Vector2 = (
			get_spawn_position(
				index,
				creature_count
			)
		)


		var creature = (
			create_creature(
				index,
				spawn_position
			)
		)


		if creature != null:

			encounter_creatures.append(
				creature
			)


	encounter_active = (
		encounter_creatures.size()
		> 0
	)


	if encounter_active:

		encounter_started.emit(
			encounter_creatures.size()
		)


	return encounter_active


# =========================================================
# CREAR CRIATURA
# =========================================================

func create_creature(
	index: int,
	spawn_position: Vector2
):

	if not has_encounter_authority():
		return null


	var creature = (
		SEA_CREATURE_SCRIPT.new()
	)


	if creature == null:
		return null


	creature.name = (
		"EncounterCreature_"
		+ str(
			encounter_serial
		)
		+ "_"
		+ str(
			index + 1
		)
	)


	var collision_shape := (
		CollisionShape2D.new()
	)


	collision_shape.name = (
		"CollisionShape2D"
	)


	var circle_shape := (
		CircleShape2D.new()
	)


	circle_shape.radius = 18.0


	collision_shape.shape = (
		circle_shape
	)


	creature.add_child(
		collision_shape
	)


	creature.show_debug_label = (
		show_spawned_labels
	)


	var scene = (
		get_tree().current_scene
	)


	if scene == null:

		creature.queue_free()

		return null


	scene.add_child(
		creature
	)


	creature.add_to_group(
		"damageable_creature"
	)


	creature.add_to_group(
		"encounter_creature"
	)


	creature.reset_for_qa(
		spawn_position
	)


	creature.set_attack_submarine_enabled(
		attack_submarine
	)


	return creature


# =========================================================
# POSICIÓN DE SPAWN
# =========================================================

func get_spawn_position(
	index: int,
	total_count: int
) -> Vector2:

	if hull_target == null:
		return Vector2.ZERO


	var interpolation: float = 0.5


	if total_count > 1:

		interpolation = (
			float(index)
			/ float(
				total_count - 1
			)
		)


	var angle_degrees: float = lerp(
		spawn_angle_min_degrees,
		spawn_angle_max_degrees,
		interpolation
	)


	var angle_radians: float = (
		deg_to_rad(
			angle_degrees
		)
	)


	var offset: Vector2 = (
		Vector2.RIGHT.rotated(
			angle_radians
		)
		* spawn_distance
	)


	return (
		hull_target.global_position
		+ offset
	)


# =========================================================
# COMPLETAR
# =========================================================

func complete_encounter():

	if not has_encounter_authority():
		return


	if not encounter_active:
		return


	encounter_active = false

	encounter_finished = true


	encounter_completed.emit()


	print(
		"[ENCOUNTER] COMPLETE | Creatures defeated"
	)


# =========================================================
# DETENER
# =========================================================

func stop_encounter(
	remove_creatures: bool = true
):

	encounter_active = false


	for creature in encounter_creatures:

		if not is_instance_valid(
			creature
		):

			continue


		if creature.has_method(
			"set_attack_submarine_enabled"
		):

			creature.set_attack_submarine_enabled(
				false
			)


	if remove_creatures:

		clear_encounter_creatures()


# =========================================================
# LIMPIEZA
# =========================================================

func clear_encounter_creatures():

	for creature in encounter_creatures:

		if not is_instance_valid(
			creature
		):

			continue


		creature.queue_free()


	encounter_creatures.clear()


func remove_invalid_references():

	var valid_creatures: Array = []


	for creature in encounter_creatures:

		if is_instance_valid(
			creature
		):

			valid_creatures.append(
				creature
			)


	encounter_creatures = (
		valid_creatures
	)


# =========================================================
# CONSULTAS
# =========================================================

func is_encounter_active() -> bool:

	return encounter_active


func is_encounter_complete() -> bool:

	return encounter_finished


func get_spawned_count() -> int:

	remove_invalid_references()


	return (
		encounter_creatures.size()
	)


func get_alive_count() -> int:

	var alive_count: int = 0


	for creature in encounter_creatures:

		if not is_instance_valid(
			creature
		):

			continue


		if creature.has_method(
			"is_dead"
		):

			if creature.is_dead():
				continue


		alive_count += 1


	return alive_count


func get_creatures() -> Array:

	remove_invalid_references()


	return (
		encounter_creatures.duplicate()
	)


func get_spawn_distance() -> float:

	return spawn_distance
