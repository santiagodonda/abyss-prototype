extends CharacterBody2D


# =========================================================
# ESTADOS
# =========================================================

enum CreatureState {
	IDLE,
	ALERT,
	CHASE,
	ATTACK,
	RETURN,
	DEAD
}


# =========================================================
# TIPOS DE OBJETIVO
# =========================================================

const TARGET_NONE: String = "NONE"

const TARGET_PLAYER: String = "PLAYER"

const TARGET_HULL: String = "HULL"


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("Detection")

@export var detection_range: float = 320.0

@export var lose_target_range: float = 460.0

@export var alert_duration: float = 0.35


@export_group("Submarine Attack")

@export var attack_submarine_enabled: bool = false

@export var hull_detection_range: float = 500.0

@export var hull_lose_target_range: float = 650.0

@export var hull_attack_damage: float = 15.0


@export_group("Movement")

@export var movement_speed: float = 90.0

@export var return_tolerance: float = 5.0


@export_group("Attack")

@export var attack_range: float = 45.0

@export var attack_damage: float = 10.0

@export var attack_cooldown: float = 1.0


@export_group("Health")

@export var max_health: float = 50.0


@export_group("Network")

@export var proxy_interpolation_speed: float = 14.0

@export var proxy_snap_distance: float = 180.0


@export_group("Debug")

@export var show_debug_label: bool = true


# =========================================================
# ESTADO
# =========================================================

var current_state: CreatureState = (
	CreatureState.IDLE
)

var current_health: float = 50.0

var home_position: Vector2

var alert_timer: float = 0.0

var attack_timer: float = 0.0


# =========================================================
# NETWORK
# =========================================================

var network_creature_id: String = ""

var network_spawned_proxy: bool = false

var network_target_position: Vector2 = Vector2.ZERO


# =========================================================
# TARGET
# =========================================================

var current_target: Node2D = null

var current_target_type: String = (
	TARGET_NONE
)

var current_target_peer_id: int = 0


# =========================================================
# REFERENCIAS PLAYER LOCAL
# =========================================================

@onready var target_player = (
	get_node_or_null(
		"../Player"
	)
)


@onready var target_vitals = (
	get_node_or_null(
		"../Player/Vitals"
	)
)


@onready var target_health = (
	get_node_or_null(
		"../Player/Health"
	)
)


# =========================================================
# REFERENCIAS NETWORK
# =========================================================

@onready var network_player_manager = (
	get_node_or_null(
		"../NetworkPlayerManager"
	)
)


@onready var network_player_health_manager = (
	get_node_or_null(
		"../NetworkPlayerHealthManager"
	)
)


@onready var network_environment_manager = (
	get_node_or_null(
		"../NetworkEnvironmentManager"
	)
)


# =========================================================
# DEBUG
# =========================================================

var debug_label: Label


# =========================================================
# READY
# =========================================================

func _ready():

	add_to_group(
		"network_creature"
	)


	if network_creature_id.is_empty():

		network_creature_id = str(
			name
		)


	home_position = (
		global_position
	)


	network_target_position = (
		global_position
	)


	current_health = (
		max_health
	)


	if show_debug_label:

		create_debug_label()


	update_debug_label()

	queue_redraw()


# =========================================================
# NETWORK MODE
# =========================================================

func is_network_proxy() -> bool:

	return (
		NetworkManager.is_online()
		and not NetworkManager.is_host()
	)


# =========================================================
# PHYSICS
# =========================================================

func _physics_process(
	delta: float
):

	# -----------------------------------------------------
	# CLIENT
	#
	# No ejecuta IA ni daño.
	# Sólo representa el estado enviado por Host.
	# -----------------------------------------------------

	if is_network_proxy():

		process_network_proxy(
			delta
		)

		return


	# -----------------------------------------------------
	# OFFLINE / HOST
	# -----------------------------------------------------

	if current_state == CreatureState.DEAD:

		velocity = Vector2.ZERO

		return


	attack_timer = max(
		attack_timer - delta,
		0.0
	)


	match current_state:

		CreatureState.IDLE:

			process_idle()


		CreatureState.ALERT:

			process_alert(
				delta
			)


		CreatureState.CHASE:

			process_chase()


		CreatureState.ATTACK:

			process_attack()


		CreatureState.RETURN:

			process_return()


	update_debug_label()


# =========================================================
# NETWORK PROXY
# =========================================================

func process_network_proxy(
	delta: float
):

	velocity = Vector2.ZERO


	var distance: float = (
		global_position.distance_to(
			network_target_position
		)
	)


	if distance > proxy_snap_distance:

		global_position = (
			network_target_position
		)

	else:

		var interpolation_weight: float = clamp(
			proxy_interpolation_speed
			* delta,
			0.0,
			1.0
		)


		global_position = (
			global_position.lerp(
				network_target_position,
				interpolation_weight
			)
		)


	update_debug_label()


# =========================================================
# NETWORK STATE
# =========================================================

func get_network_creature_id() -> String:

	if network_creature_id.is_empty():

		network_creature_id = str(
			name
		)


	return network_creature_id


func build_network_state() -> Dictionary:

	return {
		"id":
			get_network_creature_id(),

		"position":
			global_position,

		"velocity":
			velocity,

		"state":
			int(
				current_state
			),

		"health":
			current_health,

		"max_health":
			max_health,

		"home_position":
			home_position,

		"target_type":
			current_target_type,

		"target_peer_id":
			current_target_peer_id,

		"attack_submarine_enabled":
			attack_submarine_enabled
	}


func apply_network_state(
	state: Dictionary,
	snap_position: bool = false
):

	if state.has(
		"max_health"
	):

		max_health = max(
			float(
				state[
					"max_health"
				]
			),
			0.0
		)


	if state.has(
		"health"
	):

		current_health = clamp(
			float(
				state[
					"health"
				]
			),
			0.0,
			max_health
		)


	if state.has(
		"state"
	):

		var received_state: int = int(
			state[
				"state"
			]
		)


		received_state = clamp(
			received_state,
			int(
				CreatureState.IDLE
			),
			int(
				CreatureState.DEAD
			)
		)


		current_state = (
			received_state
			as CreatureState
		)


	if state.has(
		"target_type"
	):

		current_target_type = str(
			state[
				"target_type"
			]
		)


	if state.has(
		"target_peer_id"
	):

		current_target_peer_id = int(
			state[
				"target_peer_id"
			]
		)


	if state.has(
		"attack_submarine_enabled"
	):

		attack_submarine_enabled = bool(
			state[
				"attack_submarine_enabled"
			]
		)


	if state.has(
		"home_position"
	):

		home_position = (
			state[
				"home_position"
			]
		)


	if state.has(
		"position"
	):

		network_target_position = (
			state[
				"position"
			]
		)


		if snap_position:

			global_position = (
				network_target_position
			)


	if current_state == CreatureState.DEAD:

		velocity = Vector2.ZERO


	current_target = null


	update_debug_label()

	queue_redraw()


# =========================================================
# IDLE
# =========================================================

func process_idle():

	velocity = Vector2.ZERO


	# -----------------------------------------------------
	# PRIORIDAD 1:
	# Cualquier jugador exterior.
	# -----------------------------------------------------

	var player_target_data: Dictionary = (
		find_nearest_player_target(
			detection_range
		)
	)


	if not player_target_data.is_empty():

		set_player_target(
			player_target_data[
				"target"
			],
			int(
				player_target_data[
					"peer_id"
				]
			)
		)


		begin_alert()

		return


	# -----------------------------------------------------
	# PRIORIDAD 2:
	# Casco del submarino.
	# -----------------------------------------------------

	if attack_submarine_enabled:

		var hull_target = (
			find_nearest_hull_target()
		)


		if hull_target != null:

			set_target(
				hull_target,
				TARGET_HULL
			)


			begin_alert()


# =========================================================
# ALERT
# =========================================================

func begin_alert():

	current_state = (
		CreatureState.ALERT
	)


	alert_timer = (
		alert_duration
	)


	velocity = Vector2.ZERO


func process_alert(
	delta: float
):

	velocity = Vector2.ZERO


	if not is_current_target_detectable():

		clear_target()

		begin_return()

		return


	alert_timer -= delta


	if alert_timer <= 0.0:

		current_state = (
			CreatureState.CHASE
		)


# =========================================================
# CHASE
# =========================================================

func process_chase():

	if not is_current_target_valid():

		clear_target()

		begin_return()

		return


	var distance: float = (
		get_distance_to_target()
	)


	if distance <= attack_range:

		current_state = (
			CreatureState.ATTACK
		)

		velocity = Vector2.ZERO

		return


	var target_position: Vector2 = (
		get_current_target_position()
	)


	var direction: Vector2 = (
		global_position.direction_to(
			target_position
		)
	)


	velocity = (
		direction
		* movement_speed
	)


	move_and_slide()


# =========================================================
# ATTACK
# =========================================================

func process_attack():

	if not is_current_target_valid():

		clear_target()

		begin_return()

		return


	var distance: float = (
		get_distance_to_target()
	)


	if distance > attack_range:

		current_state = (
			CreatureState.CHASE
		)

		return


	velocity = Vector2.ZERO


	try_attack()


# =========================================================
# ATAQUE
# =========================================================

func try_attack():

	if attack_timer > 0.0:
		return


	# -----------------------------------------------------
	# PLAYER
	# -----------------------------------------------------

	if current_target_type == TARGET_PLAYER:

		if NetworkManager.is_online():

			# Solamente el Host ejecuta daño real.
			if not NetworkManager.is_host():
				return


			if network_player_health_manager == null:
				return


			if not is_instance_valid(
				network_player_health_manager
			):

				return


			if not network_player_health_manager.has_method(
				"apply_damage_to_peer"
			):

				return


			if current_target_peer_id <= 0:
				return


			network_player_health_manager.apply_damage_to_peer(
				current_target_peer_id,
				attack_damage,
				&"creature_attack"
			)

		else:

			# ---------------------------------------------
			# OFFLINE
			# ---------------------------------------------

			if target_health == null:
				return


			if not target_health.has_method(
				"apply_damage"
			):

				return


			target_health.apply_damage(
				attack_damage,
				&"creature_attack"
			)


	# -----------------------------------------------------
	# CASCO
	# -----------------------------------------------------

	elif current_target_type == TARGET_HULL:

		if current_target == null:
			return


		if not current_target.has_method(
			"apply_damage"
		):

			return


		current_target.apply_damage(
			hull_attack_damage,
			&"creature_attack"
		)


		if current_target.has_method(
			"is_breached"
		):

			if current_target.is_breached():

				attack_timer = (
					attack_cooldown
				)


				clear_target()

				begin_return()

				return


	attack_timer = (
		attack_cooldown
	)


# =========================================================
# RETURN
# =========================================================

func begin_return():

	current_state = (
		CreatureState.RETURN
	)


	velocity = Vector2.ZERO


func process_return():

	var player_target_data: Dictionary = (
		find_nearest_player_target(
			detection_range
		)
	)


	if not player_target_data.is_empty():

		set_player_target(
			player_target_data[
				"target"
			],
			int(
				player_target_data[
					"peer_id"
				]
			)
		)


		begin_alert()

		return


	var distance_home: float = (
		global_position.distance_to(
			home_position
		)
	)


	if distance_home <= return_tolerance:

		global_position = (
			home_position
		)

		velocity = Vector2.ZERO

		current_state = (
			CreatureState.IDLE
		)

		clear_target()

		return


	var direction: Vector2 = (
		global_position.direction_to(
			home_position
		)
	)


	velocity = (
		direction
		* movement_speed
	)


	move_and_slide()


# =========================================================
# BUSCAR PLAYER MÁS CERCANO
# =========================================================

func find_nearest_player_target(
	maximum_distance: float
) -> Dictionary:

	var nearest_target: Node2D = null

	var nearest_peer_id: int = 0

	var nearest_distance: float = INF


	# -----------------------------------------------------
	# OFFLINE
	# -----------------------------------------------------

	if not NetworkManager.is_online():

		if is_player_candidate_valid(
			target_player,
			1
		):

			var local_distance: float = (
				global_position.distance_to(
					target_player.global_position
				)
			)


			if local_distance <= maximum_distance:

				return {
					"target":
						target_player,

					"peer_id":
						1
				}


		return {}


	# -----------------------------------------------------
	# MULTIPLAYER
	#
	# La IA sólo existe en Host.
	# -----------------------------------------------------

	if not NetworkManager.is_host():
		return {}


	# -----------------------------------------------------
	# PLAYER HOST
	# -----------------------------------------------------

	if is_player_candidate_valid(
		target_player,
		1
	):

		var host_distance: float = (
			global_position.distance_to(
				target_player.global_position
			)
		)


		if host_distance <= maximum_distance:

			nearest_target = (
				target_player
			)


			nearest_peer_id = 1

			nearest_distance = (
				host_distance
			)


	# -----------------------------------------------------
	# PLAYERS REMOTOS
	# -----------------------------------------------------

	if network_player_manager != null:

		if (
			is_instance_valid(
				network_player_manager
			)
			and network_player_manager.has_method(
				"get_remote_peer_ids"
			)
			and network_player_manager.has_method(
				"get_remote_player"
			)
		):

			var remote_peer_ids: Array = (
				network_player_manager.get_remote_peer_ids()
			)


			for peer_value in remote_peer_ids:

				var peer_id: int = int(
					peer_value
				)


				if peer_id <= 1:
					continue


				var remote_player = (
					network_player_manager.get_remote_player(
						peer_id
					)
				)


				if not is_player_candidate_valid(
					remote_player,
					peer_id
				):

					continue


				var remote_position: Vector2 = (
					get_player_candidate_position(
						remote_player,
						peer_id
					)
				)


				var remote_distance: float = (
					global_position.distance_to(
						remote_position
					)
				)


				if remote_distance > maximum_distance:
					continue


				if remote_distance >= nearest_distance:
					continue


				nearest_target = (
					remote_player
				)


				nearest_peer_id = (
					peer_id
				)


				nearest_distance = (
					remote_distance
				)


	if nearest_target == null:
		return {}


	return {
		"target":
			nearest_target,

		"peer_id":
			nearest_peer_id
	}


# =========================================================
# VALIDAR PLAYER CANDIDATO
# =========================================================

func is_player_candidate_valid(
	candidate,
	peer_id: int
) -> bool:

	if candidate == null:
		return false


	if not is_instance_valid(
		candidate
	):

		return false


	if not (
		candidate is Node2D
	):

		return false


	# -----------------------------------------------------
	# OFFLINE
	# -----------------------------------------------------

	if not NetworkManager.is_online():

		if candidate != target_player:
			return false


		if target_vitals == null:
			return false


		if target_health == null:
			return false


		if not target_vitals.is_exterior():
			return false


		if target_health.has_method(
			"get_state_name"
		):

			if (
				target_health.get_state_name()
				== "DEAD"
			):

				return false


		return true


	# -----------------------------------------------------
	# ONLINE: SÓLO HOST TOMA DECISIONES
	# -----------------------------------------------------

	if not NetworkManager.is_host():
		return false


	if peer_id <= 0:
		return false


	# -----------------------------------------------------
	# VIDA AUTORITATIVA
	# -----------------------------------------------------

	if (
		network_player_health_manager != null
		and is_instance_valid(
			network_player_health_manager
		)
		and network_player_health_manager.has_method(
			"get_peer_life_state"
		)
	):

		if (
			network_player_health_manager.get_peer_life_state(
				peer_id
			)
			== "DEAD"
		):

			return false


	# -----------------------------------------------------
	# HOST PLAYER
	# -----------------------------------------------------

	if peer_id == 1:

		if candidate != target_player:
			return false


		if target_vitals == null:
			return false


		if not target_vitals.is_exterior():
			return false


		return true


	# -----------------------------------------------------
	# REMOTE PLAYER
	# -----------------------------------------------------

	if not is_remote_player_exterior(
		candidate
	):

		return false


	return true


# =========================================================
# POSICIÓN PLAYER CANDIDATO
# =========================================================

func get_player_candidate_position(
	candidate: Node2D,
	peer_id: int
) -> Vector2:

	if peer_id <= 1:

		return (
			candidate.global_position
		)


	var target_position_value = (
		candidate.get(
			"target_position"
		)
	)


	if target_position_value is Vector2:

		return (
			target_position_value
		)


	return (
		candidate.global_position
	)


# =========================================================
# PLAYER REMOTO EXTERIOR
# =========================================================

func is_remote_player_exterior(
	remote_player: Node2D
) -> bool:

	if remote_player == null:
		return false


	var player_position: Vector2 = (
		get_player_candidate_position(
			remote_player,
			int(
				remote_player.get(
					"peer_id"
				)
			)
		)
	)


	# -----------------------------------------------------
	# FUENTE PREFERIDA:
	# El Host determina la habitación desde la posición.
	# -----------------------------------------------------

	if (
		network_environment_manager != null
		and is_instance_valid(
			network_environment_manager
		)
		and network_environment_manager.has_method(
			"find_room_for_position"
		)
	):

		var room = (
			network_environment_manager.find_room_for_position(
				player_position
			)
		)


		return (
			room == null
		)


	# -----------------------------------------------------
	# FALLBACK:
	# Estado informado por NetworkPlayerAvatar.
	# -----------------------------------------------------

	var exterior_value = (
		remote_player.get(
			"exterior"
		)
	)


	if exterior_value == null:
		return false


	return bool(
		exterior_value
	)


# =========================================================
# COMPATIBILIDAD TARGET PLAYER LOCAL
# =========================================================

func can_detect_player() -> bool:

	var target_data: Dictionary = (
		find_nearest_player_target(
			detection_range
		)
	)


	return (
		not target_data.is_empty()
	)


func is_player_target_valid() -> bool:

	return is_player_candidate_valid(
		target_player,
		1
	)


# =========================================================
# TARGET CASCO
# =========================================================

func find_nearest_hull_target():

	if not attack_submarine_enabled:
		return null


	var nearest_target: Node2D = null

	var nearest_distance: float = INF


	var candidates: Array = (
		get_tree().get_nodes_in_group(
			"hull_target"
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


		if candidate.has_method(
			"is_breached"
		):

			if candidate.is_breached():
				continue


		var distance: float = (
			global_position.distance_to(
				candidate.global_position
			)
		)


		if distance > hull_detection_range:
			continue


		if distance >= nearest_distance:
			continue


		nearest_distance = (
			distance
		)


		nearest_target = (
			candidate
		)


	return nearest_target


# =========================================================
# TARGET ACTUAL
# =========================================================

func set_player_target(
	new_target: Node2D,
	peer_id: int
):

	current_target = (
		new_target
	)


	current_target_type = (
		TARGET_PLAYER
	)


	current_target_peer_id = (
		peer_id
	)


func set_target(
	new_target: Node2D,
	target_type: String
):

	current_target = (
		new_target
	)


	current_target_type = (
		target_type
	)


	if target_type != TARGET_PLAYER:

		current_target_peer_id = 0


func clear_target():

	current_target = null


	current_target_type = (
		TARGET_NONE
	)


	current_target_peer_id = 0


# =========================================================
# TARGET DETECTABLE
# =========================================================

func is_current_target_detectable() -> bool:

	if current_target == null:
		return false


	if current_target_type == TARGET_PLAYER:

		if not is_player_candidate_valid(
			current_target,
			current_target_peer_id
		):

			return false


		return (
			get_distance_to_target()
			<= detection_range
		)


	if current_target_type == TARGET_HULL:

		if not attack_submarine_enabled:
			return false


		if current_target.has_method(
			"is_breached"
		):

			if current_target.is_breached():
				return false


		return (
			get_distance_to_target()
			<= hull_detection_range
		)


	return false


# =========================================================
# TARGET VÁLIDO
# =========================================================

func is_current_target_valid() -> bool:

	if current_target == null:
		return false


	if current_target_type == TARGET_PLAYER:

		if not is_player_candidate_valid(
			current_target,
			current_target_peer_id
		):

			return false


		return (
			get_distance_to_target()
			<= lose_target_range
		)


	if current_target_type == TARGET_HULL:

		if not attack_submarine_enabled:
			return false


		if current_target.has_method(
			"is_breached"
		):

			if current_target.is_breached():
				return false


		return (
			get_distance_to_target()
			<= hull_lose_target_range
		)


	return false


# =========================================================
# POSICIÓN TARGET ACTUAL
# =========================================================

func get_current_target_position() -> Vector2:

	if current_target == null:

		return (
			global_position
		)


	if (
		current_target_type
		== TARGET_PLAYER
	):

		return get_player_candidate_position(
			current_target,
			current_target_peer_id
		)


	return (
		current_target.global_position
	)


# =========================================================
# DISTANCIA TARGET
# =========================================================

func get_distance_to_target() -> float:

	if current_target == null:
		return INF


	return (
		global_position.distance_to(
			get_current_target_position()
		)
	)


func get_target_type() -> String:

	return (
		current_target_type
	)


func get_target_peer_id() -> int:

	return (
		current_target_peer_id
	)


# =========================================================
# SALUD
# =========================================================

func apply_damage(
	amount: float,
	_source: StringName = &"damage"
):

	# La salud de criatura pertenece al Host.
	if (
		NetworkManager.is_online()
		and not NetworkManager.is_host()
	):

		return


	if current_state == CreatureState.DEAD:
		return


	if amount <= 0.0:
		return


	current_health -= amount


	current_health = clamp(
		current_health,
		0.0,
		max_health
	)


	if current_health <= 0.0:

		die()


	queue_redraw()


func die():

	if (
		NetworkManager.is_online()
		and not NetworkManager.is_host()
	):

		return


	current_health = 0.0


	current_state = (
		CreatureState.DEAD
	)


	velocity = Vector2.ZERO


	clear_target()


	update_debug_label()

	queue_redraw()


func is_dead() -> bool:

	return (
		current_state
		== CreatureState.DEAD
	)


# =========================================================
# CONSULTAS
# =========================================================

func get_state_name() -> String:

	match current_state:

		CreatureState.IDLE:
			return "IDLE"

		CreatureState.ALERT:
			return "ALERT"

		CreatureState.CHASE:
			return "CHASE"

		CreatureState.ATTACK:
			return "ATTACK"

		CreatureState.RETURN:
			return "RETURN"

		CreatureState.DEAD:
			return "DEAD"


	return "UNKNOWN"


func get_home_position() -> Vector2:

	return (
		home_position
	)


# =========================================================
# CONTROL CASCO
# =========================================================

func set_attack_submarine_enabled(
	value: bool
):

	attack_submarine_enabled = (
		value
	)


	if not value:

		if (
			current_target_type
			== TARGET_HULL
		):

			clear_target()

			begin_return()


# =========================================================
# QA
# =========================================================

func reset_for_qa(
	new_home_position: Vector2
):

	global_position = (
		new_home_position
	)


	network_target_position = (
		new_home_position
	)


	home_position = (
		new_home_position
	)


	current_health = (
		max_health
	)


	current_state = (
		CreatureState.IDLE
	)


	alert_timer = 0.0

	attack_timer = 0.0

	velocity = Vector2.ZERO


	clear_target()


	update_debug_label()

	queue_redraw()


func make_attack_ready_for_qa():

	attack_timer = 0.0


# =========================================================
# DEBUG LABEL
# =========================================================

func create_debug_label():

	debug_label = Label.new()


	debug_label.name = (
		"CreatureDebugLabel"
	)


	debug_label.position = Vector2(
		-70,
		-70
	)


	debug_label.size = Vector2(
		140,
		55
	)


	debug_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	debug_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)


	debug_label.add_theme_font_size_override(
		"font_size",
		13
	)


	debug_label.add_theme_constant_override(
		"outline_size",
		4
	)


	debug_label.add_theme_color_override(
		"font_outline_color",
		Color.BLACK
	)


	debug_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	debug_label.z_index = 110


	add_child(
		debug_label
	)


	update_debug_label()


func update_debug_label():

	if debug_label == null:
		return


	var target_text: String = (
		current_target_type
	)


	if (
		current_target_type
		== TARGET_PLAYER
		and current_target_peer_id > 0
	):

		target_text += (
			" P"
			+ str(
				current_target_peer_id
			)
		)


	debug_label.text = (
		"SEA CREATURE\n"
		+ get_state_name()
		+ "\n"
		+ target_text
	)


# =========================================================
# VISUAL
# =========================================================

func _draw():

	var body_color: Color = Color(
		0.50,
		0.20,
		0.25,
		1.0
	)


	if current_state == CreatureState.DEAD:

		body_color = Color(
			0.25,
			0.25,
			0.25,
			1.0
		)


	draw_circle(
		Vector2.ZERO,
		18.0,
		body_color
	)


	draw_circle(
		Vector2(
			-6,
			-4
		),
		3.0,
		Color.WHITE
	)


	draw_circle(
		Vector2(
			6,
			-4
		),
		3.0,
		Color.WHITE
	)
