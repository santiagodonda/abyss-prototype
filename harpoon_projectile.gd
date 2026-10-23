extends Node2D


# =========================================================
# CONFIGURACIÓN INTERNA
# =========================================================

var direction: Vector2 = Vector2.RIGHT

var movement_speed: float = 500.0

var maximum_range: float = 650.0

var damage: float = 20.0

var travelled_distance: float = 0.0

var hit_radius: float = 24.0

var source_actor: Node = null


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
	new_source: Node
):

	global_position = (
		start_position
	)


	direction = (
		new_direction.normalized()
	)


	movement_speed = (
		new_speed
	)


	maximum_range = (
		new_range
	)


	damage = (
		new_damage
	)


	source_actor = (
		new_source
	)


	travelled_distance = 0.0


	z_index = 120


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
# MOVIMIENTO
# =========================================================

func _physics_process(
	delta: float
):

	var movement: Vector2 = (
		direction
		* movement_speed
		* delta
	)


	global_position += movement


	travelled_distance += (
		movement.length()
	)


	# -----------------------------------------------------
	# SOLAMENTE HOST / OFFLINE RESUELVE IMPACTOS
	# -----------------------------------------------------

	if authoritative_damage:

		if check_creature_hit():
			return


	if travelled_distance >= maximum_range:

		finish_projectile()


# =========================================================
# IMPACTO
# =========================================================

func check_creature_hit() -> bool:

	var creatures: Array = (
		get_tree().get_nodes_in_group(
			"damageable_creature"
		)
	)


	for creature in creatures:

		if not is_instance_valid(
			creature
		):

			continue


		if not creature is Node2D:
			continue


		if creature == source_actor:
			continue


		if creature.has_method(
			"is_dead"
		):

			if creature.is_dead():
				continue


		var distance: float = (
			global_position.distance_to(
				creature.global_position
			)
		)


		if distance > hit_radius:
			continue


		if creature.has_method(
			"apply_damage"
		):

			creature.apply_damage(
				damage,
				&"harpoon"
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


			if manager != null:

				if manager.has_method(
					"broadcast_projectile_despawn"
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
			0.85,
			0.85,
			0.85,
			1.0
		),
		4.0
	)


	draw_circle(
		Vector2(
			12,
			0
		),
		4.0,
		Color(
			0.75,
			0.75,
			0.80,
			1.0
		)
	)
