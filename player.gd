extends CharacterBody2D


@export_group("Movement")
@export var speed: float = 250.0


@export_group("External Forces")
@export var external_drag: float = 700.0
@export var max_external_speed: float = 900.0


@export_group("Debug")
@export var print_interaction_debug: bool = true


@onready var interaction_area: Area2D = $InteractionArea
@onready var health: Node = $Health
@onready var equipment: Node = $Equipment


var current_interactable: Node = null
var locked_interactable: Node = null

var external_velocity: Vector2 = Vector2.ZERO

var interaction_hold_started: bool = false


# =========================================================
# INICIALIZACIÓN
# =========================================================

func _ready():

	if equipment == null:

		push_error(
			"Player: no se encontró Equipment"
		)


	if not InputMap.has_action(
		"tool_next"
	):

		push_warning(
			"Player: falta InputMap action 'tool_next'"
		)


# =========================================================
# MOVIMIENTO
# =========================================================

func _physics_process(delta):

	if not can_control():

		velocity = external_velocity

		external_velocity = (
			external_velocity.move_toward(
				Vector2.ZERO,
				external_drag * delta
			)
		)

		move_and_slide()

		return


	var direction: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)


	velocity = (
		direction * speed
		+ external_velocity
	)


	external_velocity = (
		external_velocity.move_toward(
			Vector2.ZERO,
			external_drag * delta
		)
	)


	move_and_slide()


# =========================================================
# PROCESO GENERAL
# =========================================================

func _process(delta):

	if not can_control():

		cancel_current_interaction()

		return


	# -----------------------------------------------------
	# CAMBIO DE HERRAMIENTA
	# -----------------------------------------------------

	process_tool_selection()


	var interact_just_pressed: bool = (
		Input.is_action_just_pressed(
			"interact"
		)
	)

	var interact_pressed: bool = (
		Input.is_action_pressed(
			"interact"
		)
	)

	var interact_just_released: bool = (
		Input.is_action_just_released(
			"interact"
		)
	)


	# -----------------------------------------------------
	# BUSCAR INTERACTUABLE
	#
	# Mientras existe una interacción activa NO se cambia
	# el target.
	# -----------------------------------------------------

	if locked_interactable == null:

		update_current_interactable()


	# -----------------------------------------------------
	# PRESS
	# -----------------------------------------------------

	if interact_just_pressed:

		interaction_hold_started = false

		locked_interactable = current_interactable


		if locked_interactable == null:

			if print_interaction_debug:

				print(
					"[PLAYER INTERACT] PRESS | Target = NONE"
				)

			return


		if not is_instance_valid(
			locked_interactable
		):

			locked_interactable = null

			return


		if print_interaction_debug:

			print(
				"[PLAYER INTERACT] PRESS | Target = ",
				locked_interactable.name,
				" | LOCKED",
				" | Has interact = ",
				locked_interactable.has_method(
					"interact"
				),
				" | Has hold = ",
				locked_interactable.has_method(
					"interact_hold"
				)
			)


		if locked_interactable.has_method(
			"interact"
		):

			locked_interactable.interact(
				self
			)


	# -----------------------------------------------------
	# INTERACCIÓN MANTENIDA
	# -----------------------------------------------------

	if interact_pressed:

		if locked_interactable == null:

			return


		if not is_instance_valid(
			locked_interactable
		):

			locked_interactable = null
			interaction_hold_started = false

			return


		if locked_interactable.has_method(
			"interact_hold"
		):

			if not interaction_hold_started:

				interaction_hold_started = true


				if print_interaction_debug:

					print(
						"[PLAYER INTERACT] HOLD START | Target = ",
						locked_interactable.name
					)


			locked_interactable.interact_hold(
				self,
				delta
			)


	# -----------------------------------------------------
	# RELEASE
	# -----------------------------------------------------

	if interact_just_released:

		if (
			locked_interactable != null
			and is_instance_valid(
				locked_interactable
			)
		):

			if print_interaction_debug:

				print(
					"[PLAYER INTERACT] RELEASE | Target = ",
					locked_interactable.name,
					" | LOCKED"
				)


			if locked_interactable.has_method(
				"interact_release"
			):

				locked_interactable.interact_release(
					self
				)


		locked_interactable = null
		interaction_hold_started = false


# =========================================================
# ACTUALIZAR TARGET DE INTERACCIÓN
# =========================================================

func update_current_interactable():

	var new_interactable: Node = (
		get_closest_interactable()
	)


	if new_interactable == current_interactable:

		return


	if (
		current_interactable != null
		and is_instance_valid(
			current_interactable
		)
	):

		if current_interactable.has_method(
			"interaction_cancel"
		):

			current_interactable.interaction_cancel(
				self
			)


	current_interactable = new_interactable

	interaction_hold_started = false


	if print_interaction_debug:

		if current_interactable == null:

			print(
				"[PLAYER INTERACT] Target = NONE"
			)

		else:

			print(
				"[PLAYER INTERACT] Target = ",
				current_interactable.name,
				" | Position = ",
				current_interactable.global_position
			)


# =========================================================
# CAMBIO DE HERRAMIENTA
# =========================================================

func process_tool_selection():

	if not InputMap.has_action(
		"tool_next"
	):

		return


	if not Input.is_action_just_pressed(
		"tool_next"
	):

		return


	print(
		"[PLAYER] tool_next detected"
	)


	if equipment == null:

		print(
			"[PLAYER] ERROR: Equipment not found"
		)

		return


	if not equipment.has_method(
		"cycle_tool_next"
	):

		print(
			"[PLAYER] ERROR: Equipment has no cycle_tool_next()"
		)

		return


	var changed: bool = (
		equipment.cycle_tool_next()
	)


	print(
		"[PLAYER] Tool cycle result: ",
		changed
	)


	if equipment.has_method(
		"get_active_tool_display_name"
	):

		print(
			"[PLAYER] Active Tool: ",
			equipment.get_active_tool_display_name()
		)


# =========================================================
# CONTROL DEL PERSONAJE
# =========================================================

func can_control() -> bool:

	if health.is_dead:

		return false


	if health.is_unconscious:

		return false


	return true


# =========================================================
# FUERZAS EXTERNAS
# =========================================================

func apply_external_impulse(
	impulse: Vector2
):

	external_velocity += impulse


	if (
		external_velocity.length()
		> max_external_speed
	):

		external_velocity = (
			external_velocity.normalized()
			* max_external_speed
		)


# =========================================================
# CANCELAR INTERACCIÓN
# =========================================================

func cancel_current_interaction():

	var cancel_target: Node = null


	if (
		locked_interactable != null
		and is_instance_valid(
			locked_interactable
		)
	):

		cancel_target = locked_interactable

	elif (
		current_interactable != null
		and is_instance_valid(
			current_interactable
		)
	):

		cancel_target = current_interactable


	if (
		cancel_target != null
		and cancel_target.has_method(
			"interaction_cancel"
		)
	):

		cancel_target.interaction_cancel(
			self
		)


	locked_interactable = null
	current_interactable = null

	interaction_hold_started = false


# =========================================================
# BUSCAR INTERACTUABLE
# =========================================================

func get_closest_interactable() -> Node:

	var best_candidate: Node = null

	var best_priority: int = -999999

	var best_distance: float = INF


	for area in interaction_area.get_overlapping_areas():

		if not area.is_in_group(
			"interactable_area"
		):

			continue


		var candidate: Node = (
			area.get_parent()
		)


		if candidate == null:

			continue


		# No interactuar con nuestro propio ReviveTarget.
		if candidate.get_parent() == self:

			continue


		var priority: int = 0


		if candidate.has_method(
			"get_interaction_priority"
		):

			priority = int(
				candidate.get_interaction_priority(
					self
				)
			)


		var distance: float = (
			global_position.distance_squared_to(
				area.global_position
			)
		)


		if priority > best_priority:

			best_priority = priority

			best_distance = distance

			best_candidate = candidate

			continue


		if (
			priority == best_priority
			and distance < best_distance
		):

			best_distance = distance

			best_candidate = candidate


	return best_candidate


# =========================================================
# DEBUG
# =========================================================

func get_current_interactable_name() -> String:

	if locked_interactable != null:

		if is_instance_valid(
			locked_interactable
		):

			return str(
				locked_interactable.name
			)


	if current_interactable == null:

		return "NONE"


	return str(
		current_interactable.name
	)
