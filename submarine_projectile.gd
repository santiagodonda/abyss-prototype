extends Node2D


# =========================================================
# ESTADO
# =========================================================

var direction: Vector2 = Vector2.RIGHT

var projectile_speed: float = 650.0

var max_distance: float = 900.0

var damage: float = 25.0

var travelled_distance: float = 0.0

var source = null


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export var hit_radius: float = 26.0


# =========================================================
# NETWORK
# =========================================================

var network_projectile_id: String = ""

var authoritative_damage: bool = true


# =========================================================
# READY
# =========================================================

func _ready():

	add_to_group(
		"network_projectile"
	)


# =========================================================
# SETUP
# =========================================================

func setup(
	start_position: Vector2,
	new_direction: Vector2,
	new_speed: float,
	new_range: float,
	new_damage: float,
	new_source
):

	global_position = (
		start_position
	)


	direction = (
		new_direction.normalized()
	)


	projectile_speed = (
		new_speed
	)


	max_distance = (
		new_range
	)


	damage = (
		new_damage
	)


	source = (
		new_source
	)


	travelled_distance = 0.0


	queue_redraw()


# =========================================================
# NETWORK CONTEXT
# =========================================================

func set_network_context(
	projectile_id: String,
	is_authoritative: bool
):

	network_projectile_id = (
		projectile_id
	)


	authoritative_damage = (
		is_authoritative
	)


# =========================================================
# PHYSICS
# =========================================================

func _physics_process(
	delta: float
):

	var movement: Vector2 = (
		direction
		* projectile_speed
		* delta
	)


	global_position += (
		movement
	)


	travelled_distance += (
		movement.length()
	)


	# -----------------------------------------------------
	# SOLAMENTE HOST / OFFLINE RESUELVE IMPACTOS
	# -----------------------------------------------------

	if authoritative_damage:

		if try_hit_creature():
			return


	if travelled_distance >= max_distance:

		finish_projectile()


# =========================================================
# IMPACTO
# =========================================================

func try_hit_creature() -> bool:

	var candidates: Array = (
		get_tree().get_nodes_in_group(
			"damageable_creature"
		)
	)


	for candidate in candidates:

		if not is_instance_valid(
			candidate
		):

			continue


		if not (
			candidate is Node2D
		):

			continue


		if candidate == source:
			continue


		if candidate.has_method(
			"is_dead"
		):

			if candidate.is_dead():
				continue


		var distance: float = (
			global_position.distance_to(
				candidate.global_position
			)
		)


		if distance > hit_radius:
			continue


		if candidate.has_method(
			"apply_damage"
		):

			candidate.apply_damage(
				damage,
				&"submarine_turret"
			)


		finish_projectile()

		return true


	return false


# =========================================================
# FINALIZAR
# =========================================================

func finish_projectile():

	if (
		authoritative_damage
		and NetworkManager.is_online()
		and NetworkManager.is_host()
		and not network_projectile_id.is_empty()
	):

		var managers: Array = (
			get_tree().get_nodes_in_group(
				"network_combat_manager"
			)
		)


		if not managers.is_empty():

			var manager = (
				managers[0]
			)


			if (
				manager != null
				and is_instance_valid(
					manager
				)
				and manager.has_method(
					"broadcast_projectile_despawn"
				)
			):

				manager.broadcast_projectile_despawn(
					network_projectile_id
				)


	queue_free()


# =========================================================
# VISUAL
# =========================================================

func _draw():

	draw_line(
		Vector2(
			-12,
			0
		),
		Vector2(
			12,
			0
		),
		Color(
			0.95,
			0.85,
			0.40,
			1.0
		),
		5.0
	)


	draw_circle(
		Vector2.ZERO,
		4.0,
		Color.WHITE
	)
