extends Node


signal health_changed(
	current_health: float,
	max_health: float
)

signal became_unconscious

signal died

signal revived


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("Health")

@export var max_health: float = 100.0


@export_group("Unconscious")

@export var unconscious_time_before_death: float = 30.0


# =========================================================
# ESTADO
# =========================================================

var current_health: float = 100.0

var is_unconscious: bool = false

var is_dead: bool = false

var unconscious_timer: float = 0.0


# =========================================================
# NETWORK
# =========================================================

var network_health_manager = null


# =========================================================
# READY
# =========================================================

func _ready():

	current_health = (
		max_health
	)


	call_deferred(
		"resolve_network_health_manager"
	)


# =========================================================
# RESOLVER NETWORK HEALTH MANAGER
# =========================================================

func resolve_network_health_manager():

	if (
		network_health_manager != null
		and is_instance_valid(
			network_health_manager
		)
	):

		return network_health_manager


	network_health_manager = null


	var scene = (
		get_tree().current_scene
	)


	if scene != null:

		var scene_candidate = (
			scene.get_node_or_null(
				"NetworkPlayerHealthManager"
			)
		)


		if (
			scene_candidate != null
			and is_instance_valid(
				scene_candidate
			)
		):

			network_health_manager = (
				scene_candidate
			)


			return network_health_manager


	var managers: Array = (
		get_tree().get_nodes_in_group(
			"network_player_health_manager"
		)
	)


	if not managers.is_empty():

		var candidate = (
			managers[
				0
			]
		)


		if (
			candidate != null
			and is_instance_valid(
				candidate
			)
		):

			network_health_manager = (
				candidate
			)


	return network_health_manager


# =========================================================
# PROCESS
# =========================================================

func _process(
	delta
):

	if is_dead:
		return


	# -----------------------------------------------------
	# MULTIPLAYER
	#
	# Los timers de vida pertenecen al Host mediante
	# NetworkPlayerHealthManager.
	# -----------------------------------------------------

	if NetworkManager.is_online():
		return


	# -----------------------------------------------------
	# OFFLINE
	# -----------------------------------------------------

	if is_unconscious:

		unconscious_timer += delta


		if (
			unconscious_timer
			>= unconscious_time_before_death
		):

			die()


# =========================================================
# DAMAGE
# =========================================================

func apply_damage(
	amount: float,
	damage_type: StringName = &"generic"
):

	if is_dead:
		return


	if amount <= 0.0:
		return


	# -----------------------------------------------------
	# MULTIPLAYER
	#
	# Nunca modificamos Health directamente.
	# Todo daño termina pasando por el Host.
	# -----------------------------------------------------

	if NetworkManager.is_online():

		var manager = (
			resolve_network_health_manager()
		)


		if manager == null:
			return


		if not manager.has_method(
			"request_local_damage"
		):

			return


		manager.request_local_damage(
			amount,
			damage_type
		)


		return


	# -----------------------------------------------------
	# OFFLINE
	# -----------------------------------------------------

	if is_unconscious:

		unconscious_timer += (
			amount
			* 0.10
		)


		return


	current_health -= amount


	current_health = clamp(
		current_health,
		0.0,
		max_health
	)


	health_changed.emit(
		current_health,
		max_health
	)


	if current_health <= 0.0:

		become_unconscious()


# =========================================================
# HEAL
# =========================================================

func heal(
	amount: float
):

	if is_dead:
		return


	if amount <= 0.0:
		return


	if NetworkManager.is_online():

		if not NetworkManager.is_host():
			return


		var manager = (
			resolve_network_health_manager()
		)


		if manager == null:
			return


		if manager.has_method(
			"heal_peer"
		):

			manager.heal_peer(
				1,
				amount
			)


		return


	current_health += amount


	current_health = clamp(
		current_health,
		0.0,
		max_health
	)


	health_changed.emit(
		current_health,
		max_health
	)


# =========================================================
# INCONSCIENTE
# =========================================================

func become_unconscious():

	if is_unconscious or is_dead:
		return


	if NetworkManager.is_online():

		if not NetworkManager.is_host():
			return


		var manager = (
			resolve_network_health_manager()
		)


		if manager == null:
			return


		if manager.has_method(
			"force_unconscious_peer"
		):

			manager.force_unconscious_peer(
				1
			)


		return


	is_unconscious = true

	current_health = 0.0

	unconscious_timer = 0.0


	became_unconscious.emit()


# =========================================================
# MUERTE
# =========================================================

func die():

	if is_dead:
		return


	if NetworkManager.is_online():

		if not NetworkManager.is_host():
			return


		var manager = (
			resolve_network_health_manager()
		)


		if manager == null:
			return


		if manager.has_method(
			"force_die_peer"
		):

			manager.force_die_peer(
				1
			)


		return


	is_dead = true

	is_unconscious = false

	current_health = 0.0


	died.emit()


# =========================================================
# REVIVE
# =========================================================

func revive(
	health_percentage: float = 0.25
):

	if is_dead:
		return


	if not is_unconscious:
		return


	if NetworkManager.is_online():

		if not NetworkManager.is_host():
			return


		var manager = (
			resolve_network_health_manager()
		)


		if manager == null:
			return


		if manager.has_method(
			"revive_peer"
		):

			manager.revive_peer(
				1,
				health_percentage
			)


		return


	is_unconscious = false

	unconscious_timer = 0.0


	current_health = clamp(
		max_health
		* health_percentage,
		1.0,
		max_health
	)


	health_changed.emit(
		current_health,
		max_health
	)


	revived.emit()


# =========================================================
# APLICAR ESTADO AUTORITATIVO
# =========================================================

func apply_network_health_state(
	new_health: float,
	new_max_health: float,
	new_life_state: String,
	new_unconscious_timer: float
):

	var previous_health: float = (
		current_health
	)


	var previous_max_health: float = (
		max_health
	)


	var was_unconscious: bool = (
		is_unconscious
	)


	var was_dead: bool = (
		is_dead
	)


	max_health = max(
		new_max_health,
		1.0
	)


	current_health = clamp(
		new_health,
		0.0,
		max_health
	)


	unconscious_timer = max(
		new_unconscious_timer,
		0.0
	)


	match new_life_state:

		"DEAD":

			is_dead = true

			is_unconscious = false

			current_health = 0.0


		"UNCONSCIOUS":

			is_dead = false

			is_unconscious = true

			current_health = 0.0


		_:

			is_dead = false

			is_unconscious = false


	if (
		not is_equal_approx(
			previous_health,
			current_health
		)
		or not is_equal_approx(
			previous_max_health,
			max_health
		)
	):

		health_changed.emit(
			current_health,
			max_health
		)


	if (
		is_unconscious
		and not was_unconscious
		and not was_dead
	):

		became_unconscious.emit()


	if (
		is_dead
		and not was_dead
	):

		died.emit()


	if (
		not is_dead
		and not is_unconscious
		and was_unconscious
	):

		revived.emit()


# =========================================================
# CONSULTAS
# =========================================================

func get_health_percentage() -> float:

	if max_health <= 0.0:
		return 0.0


	return (
		current_health
		/ max_health
	)


func get_unconscious_time_remaining() -> float:

	if not is_unconscious:
		return 0.0


	return max(
		unconscious_time_before_death
		- unconscious_timer,
		0.0
	)


func can_be_revived() -> bool:

	return (
		is_unconscious
		and not is_dead
	)


func get_state_name() -> String:

	if is_dead:
		return "DEAD"


	if is_unconscious:
		return "UNCONSCIOUS"


	return "ALIVE"


# =========================================================
# QA TEMPORAL REVIVE
# =========================================================

func _unhandled_input(
	event
):

	# El auto-revive con ui_accept es únicamente para QA
	# offline. En multiplayer un Client no debe poder
	# reanimarse a sí mismo.
	if NetworkManager.is_online():
		return


	if event.is_action_pressed(
		"ui_accept"
	):

		if can_be_revived():

			revive(
				0.25
			)
