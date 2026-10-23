extends Node2D


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export var interpolation_speed: float = 14.0


# =========================================================
# IDENTIDAD
# =========================================================

var peer_id: int = 0


# =========================================================
# NETWORK MOVEMENT
# =========================================================

var target_position: Vector2 = Vector2.ZERO

var network_velocity: Vector2 = Vector2.ZERO

var initialized: bool = false


# =========================================================
# PLAYER STATE REMOTO
# =========================================================

var health_value: float = 100.0

var max_health_value: float = 100.0

var breath_value: float = 1.0

var life_state: String = "ALIVE"

var active_tool_id: String = ""

var suit_equipped: bool = false

var tank_equipped: bool = false

var tank_percentage: float = 0.0

var exterior: bool = false


# =========================================================
# REVIVE
# =========================================================

var revive_manager = null

var revive_interaction_area: Area2D = null

var revive_collision_shape: CollisionShape2D = null

var last_revive_fraction: float = -1.0


# =========================================================
# DEBUG
# =========================================================

var player_label: Label


# =========================================================
# READY
# =========================================================

func _ready():

	create_label()

	create_revive_interaction_area()

	resolve_revive_manager()

	update_revive_interaction_state()

	queue_redraw()


# =========================================================
# CONFIGURAR
# =========================================================

func setup(
	new_peer_id: int,
	start_position: Vector2
):

	peer_id = new_peer_id


	global_position = (
		start_position
	)


	target_position = (
		start_position
	)


	initialized = true


	update_label()

	update_revive_interaction_state()

	queue_redraw()


# =========================================================
# MOVIMIENTO REMOTO
# =========================================================

func apply_network_state(
	new_position: Vector2,
	new_velocity: Vector2
):

	target_position = (
		new_position
	)


	network_velocity = (
		new_velocity
	)


	if not initialized:

		global_position = (
			new_position
		)


		initialized = true


# =========================================================
# ESTADO REMOTO
# =========================================================

func apply_player_state(
	new_health: float,
	new_max_health: float,
	new_breath: float,
	new_life_state: String,
	new_active_tool: String,
	new_suit_equipped: bool,
	new_tank_equipped: bool,
	new_tank_percentage: float,
	new_exterior: bool
):

	health_value = new_health

	max_health_value = new_max_health

	breath_value = new_breath

	life_state = new_life_state

	active_tool_id = new_active_tool

	suit_equipped = new_suit_equipped

	tank_equipped = new_tank_equipped

	tank_percentage = new_tank_percentage

	exterior = new_exterior


	update_label()

	update_revive_interaction_state()

	queue_redraw()


# =========================================================
# INTERPOLACIÓN
# =========================================================

func _process(
	delta: float
):

	if initialized:

		var interpolation_weight: float = (
			1.0
			- exp(
				-interpolation_speed
				* delta
			)
		)


		global_position = (
			global_position.lerp(
				target_position,
				interpolation_weight
			)
		)


	if revive_manager == null:

		resolve_revive_manager()


	var revive_fraction: float = (
		get_revive_fraction()
	)


	if abs(
		revive_fraction
		- last_revive_fraction
	) >= 0.01:

		last_revive_fraction = (
			revive_fraction
		)

		queue_redraw()


# =========================================================
# REVIVE MANAGER
# =========================================================

func resolve_revive_manager():

	var managers: Array = (
		get_tree().get_nodes_in_group(
			"network_revive_manager"
		)
	)


	if managers.is_empty():

		revive_manager = null

		return


	revive_manager = (
		managers[0]
	)


# =========================================================
# CREAR ÁREA DE REVIVE
# =========================================================

func create_revive_interaction_area():

	if revive_interaction_area != null:
		return


	revive_interaction_area = (
		Area2D.new()
	)


	revive_interaction_area.name = (
		"ReviveInteractionArea"
	)


	revive_interaction_area.collision_layer = 1

	revive_interaction_area.collision_mask = 1

	revive_interaction_area.monitoring = true

	revive_interaction_area.monitorable = true


	add_child(
		revive_interaction_area
	)


	revive_collision_shape = (
		CollisionShape2D.new()
	)


	revive_collision_shape.name = (
		"CollisionShape2D"
	)


	var circle_shape := (
		CircleShape2D.new()
	)


	circle_shape.radius = 30.0


	revive_collision_shape.shape = (
		circle_shape
	)


	revive_interaction_area.add_child(
		revive_collision_shape
	)


# =========================================================
# ACTIVAR / DESACTIVAR INTERACCIÓN
# =========================================================

func update_revive_interaction_state():

	if revive_interaction_area == null:
		return


	var revivable: bool = (
		life_state
		== "UNCONSCIOUS"
	)


	if revivable:

		if not revive_interaction_area.is_in_group(
			"interactable_area"
		):

			revive_interaction_area.add_to_group(
				"interactable_area"
			)


	else:

		if revive_interaction_area.is_in_group(
			"interactable_area"
		):

			revive_interaction_area.remove_from_group(
				"interactable_area"
			)


# =========================================================
# PRIORIDAD DE INTERACCIÓN
# =========================================================

func get_interaction_priority(
	_player
) -> int:

	if life_state != "UNCONSCIOUS":
		return 0


	# Un compañero inconsciente debe tener prioridad
	# sobre máquinas, racks y repair points.
	return 110


# =========================================================
# REVIVE — HOLD
# =========================================================

func interact_hold(
	_rescuer,
	_delta: float
):

	if life_state != "UNCONSCIOUS":
		return


	if peer_id <= 0:
		return


	if revive_manager == null:

		resolve_revive_manager()


	if revive_manager == null:
		return


	if not revive_manager.has_method(
		"request_revive_start"
	):

		return


	revive_manager.request_revive_start(
		peer_id
	)


# =========================================================
# REVIVE — RELEASE
# =========================================================

func interact_release(
	_rescuer
):

	stop_local_revive_request()


# =========================================================
# REVIVE — CANCEL
# =========================================================

func interaction_cancel(
	_rescuer
):

	stop_local_revive_request()


# =========================================================
# DETENER REQUEST LOCAL
# =========================================================

func stop_local_revive_request():

	if peer_id <= 0:
		return


	if revive_manager == null:

		resolve_revive_manager()


	if revive_manager == null:
		return


	if not revive_manager.has_method(
		"request_revive_stop"
	):

		return


	revive_manager.request_revive_stop(
		peer_id
	)


# =========================================================
# PROGRESO DE REVIVE
# =========================================================

func get_revive_fraction() -> float:

	if life_state != "UNCONSCIOUS":
		return 0.0


	if revive_manager == null:
		return 0.0


	if not revive_manager.has_method(
		"get_target_revive_fraction"
	):

		return 0.0


	return float(
		revive_manager.get_target_revive_fraction(
			peer_id
		)
	)


# =========================================================
# LABEL
# =========================================================

func create_label():

	player_label = Label.new()


	player_label.name = (
		"NetworkPlayerLabel"
	)


	player_label.position = Vector2(
		-90,
		-100
	)


	player_label.size = Vector2(
		180,
		85
	)


	player_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	player_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)


	player_label.add_theme_font_size_override(
		"font_size",
		12
	)


	player_label.add_theme_constant_override(
		"outline_size",
		4
	)


	player_label.add_theme_color_override(
		"font_outline_color",
		Color.BLACK
	)


	player_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	player_label.z_index = 120


	add_child(
		player_label
	)


	update_label()


# =========================================================
# ACTUALIZAR LABEL
# =========================================================

func update_label():

	if player_label == null:
		return


	var health_percent: int = 0


	if max_health_value > 0.0:

		health_percent = int(
			round(
				health_value
				/ max_health_value
				* 100.0
			)
		)


	var environment_text: String = (
		"INTERIOR"
	)


	if exterior:

		environment_text = (
			"EXTERIOR"
		)


	var equipment_text: String = ""


	if suit_equipped:

		equipment_text += (
			"SUIT"
		)


	if tank_equipped:

		if not equipment_text.is_empty():

			equipment_text += (
				" + "
			)


		equipment_text += (
			"TANK "
			+ str(
				int(
					round(
						tank_percentage
						* 100.0
					)
				)
			)
			+ "%"
		)


	if equipment_text.is_empty():

		equipment_text = (
			"NO GEAR"
		)


	var tool_text: String = (
		"NONE"
	)


	if not active_tool_id.is_empty():

		tool_text = (
			ItemDB.get_display_name(
				active_tool_id
			)
		)


	var revive_text: String = ""


	if life_state == "UNCONSCIOUS":

		revive_text = (
			"\nREVIVABLE"
		)


	player_label.text = (
		"REMOTE ID "
		+ str(
			peer_id
		)
		+ "\n"
		+ life_state
		+ " | HP "
		+ str(
			health_percent
		)
		+ "% | BREATH "
		+ str(
			int(
				round(
					breath_value
					* 100.0
				)
			)
		)
		+ "%"
		+ "\n"
		+ environment_text
		+ " | "
		+ equipment_text
		+ "\nTOOL: "
		+ tool_text
		+ revive_text
	)


# =========================================================
# VISUAL
# =========================================================

func _draw():

	var body_color: Color = Color(
		0.85,
		0.45,
		0.20,
		1.0
	)


	if life_state == "UNCONSCIOUS":

		body_color = Color(
			0.65,
			0.55,
			0.20,
			1.0
		)


	elif life_state == "DEAD":

		body_color = Color(
			0.30,
			0.30,
			0.30,
			1.0
		)


	elif suit_equipped:

		body_color = Color(
			0.25,
			0.65,
			0.85,
			1.0
		)


	draw_rect(
		Rect2(
			-14,
			-18,
			28,
			36
		),
		body_color
	)


	draw_circle(
		Vector2.ZERO,
		7.0,
		Color(
			1.0,
			0.75,
			0.30,
			1.0
		)
	)


	draw_circle(
		Vector2(
			0,
			-12
		),
		3.0,
		Color.WHITE
	)


	# -----------------------------------------------------
	# TANQUE
	# -----------------------------------------------------

	if tank_equipped:

		draw_rect(
			Rect2(
				15,
				-12,
				6,
				24
			),
			Color(
				0.65,
				0.80,
				0.85,
				1.0
			)
		)


	# -----------------------------------------------------
	# BARRA DE REVIVE
	# -----------------------------------------------------

	if life_state == "UNCONSCIOUS":

		var revive_fraction: float = (
			get_revive_fraction()
		)


		draw_rect(
			Rect2(
				-30,
				25,
				60,
				7
			),
			Color(
				0.12,
				0.12,
				0.12,
				1.0
			)
		)


		if revive_fraction > 0.0:

			draw_rect(
				Rect2(
					-30,
					25,
					60
					* revive_fraction,
					7
				),
				Color(
					0.25,
					0.80,
					0.40,
					1.0
				)
			)
