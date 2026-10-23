extends Node


# =========================================================
# REMOTE PLAYER
# =========================================================

const NETWORK_PLAYER_AVATAR = preload(
	"res://network_player_avatar.gd"
)


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("Synchronization")

@export_range(
	5.0,
	30.0,
	1.0
)
var movement_sync_rate_hz: float = 20.0


@export_range(
	2.0,
	20.0,
	1.0
)
var state_sync_rate_hz: float = 10.0


@export_group("Debug")

@export var print_network_players: bool = true


# =========================================================
# REFERENCIAS
# =========================================================

@onready var local_player = (
	get_node_or_null(
		"../Player"
	)
)


@onready var local_health = (
	get_node_or_null(
		"../Player/Health"
	)
)


@onready var local_vitals = (
	get_node_or_null(
		"../Player/Vitals"
	)
)


@onready var local_equipment = (
	get_node_or_null(
		"../Player/Equipment"
	)
)


@onready var network_player_health_manager = (
	get_node_or_null(
		"../NetworkPlayerHealthManager"
	)
)


# =========================================================
# ESTADO
# =========================================================

var remote_players: Dictionary = {}


var movement_send_accumulator: float = 0.0

var state_send_accumulator: float = 0.0


# =========================================================
# READY
# =========================================================

func _ready():

	process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)


	if local_player == null:

		push_error(
			"NetworkPlayerManager: Player no encontrado."
		)

		return


	if local_health == null:

		push_error(
			"NetworkPlayerManager: Player/Health no encontrado."
		)


	if local_vitals == null:

		push_error(
			"NetworkPlayerManager: Player/Vitals no encontrado."
		)


	if local_equipment == null:

		push_error(
			"NetworkPlayerManager: Player/Equipment no encontrado."
		)


	if network_player_health_manager == null:

		push_error(
			"NetworkPlayerManager: NetworkPlayerHealthManager no encontrado."
		)


	NetworkManager.player_disconnected.connect(
		_on_player_disconnected
	)


	NetworkManager.network_state_changed.connect(
		_on_network_state_changed
	)


	NetworkManager.network_restart_started.connect(
		_on_network_restart_started
	)


	if print_network_players:

		print(
			"[NET PLAYER] Manager ready"
		)


# =========================================================
# PROCESS
# =========================================================

func _process(
	delta: float
):

	if not is_inside_tree():
		return


	if NetworkManager.is_restart_in_progress():
		return


	if not NetworkManager.is_online():
		return


	if local_player == null:
		return


	if not is_instance_valid(
		local_player
	):
		return


	movement_send_accumulator += delta


	var movement_interval: float = (
		1.0
		/ movement_sync_rate_hz
	)


	if (
		movement_send_accumulator
		>= movement_interval
	):

		movement_send_accumulator = 0.0


		send_local_movement_state()


	state_send_accumulator += delta


	var state_interval: float = (
		1.0
		/ state_sync_rate_hz
	)


	if (
		state_send_accumulator
		>= state_interval
	):

		state_send_accumulator = 0.0


		send_local_player_state()


# =========================================================
# MULTIPLAYER API SEGURA
# =========================================================

func get_safe_multiplayer():

	if not is_inside_tree():
		return null


	if get_tree() == null:
		return null


	return get_multiplayer()


# =========================================================
# ENVIAR MOVIMIENTO
# =========================================================

func send_local_movement_state():

	if NetworkManager.is_restart_in_progress():
		return


	if not is_instance_valid(
		local_player
	):
		return


	var local_position: Vector2 = (
		local_player.global_position
	)


	var local_velocity: Vector2 = (
		local_player.velocity
	)


	if NetworkManager.is_host():

		receive_movement_state.rpc(
			1,
			local_position,
			local_velocity
		)


		return


	if NetworkManager.is_client():

		submit_movement_state.rpc_id(
			1,
			local_position,
			local_velocity
		)


# =========================================================
# CLIENT -> HOST MOVEMENT
# =========================================================

@rpc(
	"any_peer",
	"call_remote",
	"unreliable"
)
func submit_movement_state(
	player_position: Vector2,
	player_velocity: Vector2
):

	if NetworkManager.is_restart_in_progress():
		return


	var multiplayer_api = (
		get_safe_multiplayer()
	)


	if multiplayer_api == null:
		return


	if not multiplayer_api.is_server():
		return


	var sender_id: int = (
		multiplayer_api.get_remote_sender_id()
	)


	if sender_id <= 1:
		return


	apply_remote_movement(
		sender_id,
		player_position,
		player_velocity
	)


	receive_movement_state.rpc(
		sender_id,
		player_position,
		player_velocity
	)


# =========================================================
# HOST -> CLIENT MOVEMENT
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"unreliable"
)
func receive_movement_state(
	peer_id: int,
	player_position: Vector2,
	player_velocity: Vector2
):

	if NetworkManager.is_restart_in_progress():
		return


	var multiplayer_api = (
		get_safe_multiplayer()
	)


	if multiplayer_api == null:
		return


	var local_id: int = (
		multiplayer_api.get_unique_id()
	)


	if peer_id == local_id:
		return


	apply_remote_movement(
		peer_id,
		player_position,
		player_velocity
	)


# =========================================================
# APLICAR MOVIMIENTO
# =========================================================

func apply_remote_movement(
	peer_id: int,
	player_position: Vector2,
	player_velocity: Vector2
):

	if NetworkManager.is_restart_in_progress():
		return


	var remote_player = (
		ensure_remote_player(
			peer_id,
			player_position
		)
	)


	if remote_player == null:
		return


	remote_player.apply_network_state(
		player_position,
		player_velocity
	)


# =========================================================
# ENVIAR PLAYER STATE
# =========================================================

func send_local_player_state():

	if NetworkManager.is_restart_in_progress():
		return


	if (
		local_vitals == null
		or local_equipment == null
	):

		return


	if (
		not is_instance_valid(
			local_vitals
		)
		or not is_instance_valid(
			local_equipment
		)
	):

		return


	var breath_value: float = (
		local_vitals.breath_level
	)


	var exterior: bool = (
		local_vitals.is_exterior()
	)


	var active_tool: String = (
		local_equipment.get_equipped_tool()
	)


	var suit_equipped: bool = (
		local_equipment.is_diving_suit_equipped()
	)


	var tank_equipped: bool = (
		local_equipment.is_oxygen_tank_equipped()
	)


	var tank_percentage: float = 0.0


	if tank_equipped:

		tank_percentage = (
			local_equipment.get_tank_percentage()
		)


	# -----------------------------------------------------
	# HOST
	#
	# La salud NO se toma de información enviada por un
	# jugador. El Host consulta NetworkPlayerHealthManager.
	# -----------------------------------------------------

	if NetworkManager.is_host():

		var health_state: Dictionary = (
			get_authoritative_health_state(
				1
			)
		)


		if health_state.is_empty():
			return


		receive_player_status.rpc(
			1,
			float(
				health_state[
					"health"
				]
			),
			float(
				health_state[
					"max_health"
				]
			),
			breath_value,
			str(
				health_state[
					"life_state"
				]
			),
			active_tool,
			suit_equipped,
			tank_equipped,
			tank_percentage,
			exterior
		)


		return


	# -----------------------------------------------------
	# CLIENT
	#
	# El Client solamente informa estado no autoritativo
	# que todavía pertenece al jugador local.
	#
	# HP, Max HP y Life State ya NO viajan Client -> Host.
	# -----------------------------------------------------

	if NetworkManager.is_client():

		submit_player_status.rpc_id(
			1,
			breath_value,
			active_tool,
			suit_equipped,
			tank_equipped,
			tank_percentage,
			exterior
		)


# =========================================================
# CLIENT -> HOST STATUS
# =========================================================

@rpc(
	"any_peer",
	"call_remote",
	"unreliable"
)
func submit_player_status(
	breath_value: float,
	active_tool: String,
	suit_equipped: bool,
	tank_equipped: bool,
	tank_percentage: float,
	exterior: bool
):

	if NetworkManager.is_restart_in_progress():
		return


	var multiplayer_api = (
		get_safe_multiplayer()
	)


	if multiplayer_api == null:
		return


	if not multiplayer_api.is_server():
		return


	var sender_id: int = (
		multiplayer_api.get_remote_sender_id()
	)


	if sender_id <= 1:
		return


	# -----------------------------------------------------
	# SALUD AUTORITATIVA
	#
	# No existe health/max_health/life_state en este RPC.
	# El Host los obtiene exclusivamente de HealthManager.
	# -----------------------------------------------------

	var health_state: Dictionary = (
		get_authoritative_health_state(
			sender_id
		)
	)


	if health_state.is_empty():
		return


	var health_value: float = float(
		health_state[
			"health"
		]
	)


	var max_health_value: float = float(
		health_state[
			"max_health"
		]
	)


	var life_state: String = str(
		health_state[
			"life_state"
		]
	)


	apply_remote_player_status(
		sender_id,
		health_value,
		max_health_value,
		breath_value,
		life_state,
		active_tool,
		suit_equipped,
		tank_equipped,
		tank_percentage,
		exterior
	)


	receive_player_status.rpc(
		sender_id,
		health_value,
		max_health_value,
		breath_value,
		life_state,
		active_tool,
		suit_equipped,
		tank_equipped,
		tank_percentage,
		exterior
	)


# =========================================================
# HOST -> CLIENT STATUS
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"unreliable"
)
func receive_player_status(
	peer_id: int,
	health_value: float,
	max_health_value: float,
	breath_value: float,
	life_state: String,
	active_tool: String,
	suit_equipped: bool,
	tank_equipped: bool,
	tank_percentage: float,
	exterior: bool
):

	if NetworkManager.is_restart_in_progress():
		return


	var multiplayer_api = (
		get_safe_multiplayer()
	)


	if multiplayer_api == null:
		return


	var local_id: int = (
		multiplayer_api.get_unique_id()
	)


	if peer_id == local_id:
		return


	apply_remote_player_status(
		peer_id,
		health_value,
		max_health_value,
		breath_value,
		life_state,
		active_tool,
		suit_equipped,
		tank_equipped,
		tank_percentage,
		exterior
	)


# =========================================================
# APLICAR STATUS
# =========================================================

func apply_remote_player_status(
	peer_id: int,
	health_value: float,
	max_health_value: float,
	breath_value: float,
	life_state: String,
	active_tool: String,
	suit_equipped: bool,
	tank_equipped: bool,
	tank_percentage: float,
	exterior: bool
):

	if NetworkManager.is_restart_in_progress():
		return


	if not is_instance_valid(
		local_player
	):

		return


	var remote_player = (
		ensure_remote_player(
			peer_id,
			local_player.global_position
		)
	)


	if remote_player == null:
		return


	remote_player.apply_player_state(
		health_value,
		max_health_value,
		breath_value,
		life_state,
		active_tool,
		suit_equipped,
		tank_equipped,
		tank_percentage,
		exterior
	)


# =========================================================
# HEALTH AUTORITATIVA
# =========================================================

func get_authoritative_health_state(
	peer_id: int
) -> Dictionary:

	if peer_id <= 0:
		return {}


	# -----------------------------------------------------
	# FUENTE PRINCIPAL:
	# NetworkPlayerHealthManager
	# -----------------------------------------------------

	if (
		network_player_health_manager != null
		and is_instance_valid(
			network_player_health_manager
		)
	):

		var health_value = null

		var max_health_value = null

		var life_state_value = null


		if network_player_health_manager.has_method(
			"get_peer_health"
		):

			health_value = (
				network_player_health_manager.call(
					"get_peer_health",
					peer_id
				)
			)


		if network_player_health_manager.has_method(
			"get_peer_max_health"
		):

			max_health_value = (
				network_player_health_manager.call(
					"get_peer_max_health",
					peer_id
				)
			)


		if network_player_health_manager.has_method(
			"get_peer_life_state"
		):

			life_state_value = (
				network_player_health_manager.call(
					"get_peer_life_state",
					peer_id
				)
			)


		if (
			health_value != null
			and max_health_value != null
			and life_state_value != null
		):

			return {
				"health":
					float(
						health_value
					),

				"max_health":
					float(
						max_health_value
					),

				"life_state":
					str(
						life_state_value
					)
			}


		# -------------------------------------------------
		# FALLBACK DE COMPATIBILIDAD:
		# algunos builds pueden exponer get_peer_state().
		# -------------------------------------------------

		if network_player_health_manager.has_method(
			"get_peer_state"
		):

			var state_value = (
				network_player_health_manager.call(
					"get_peer_state",
					peer_id
				)
			)


			if state_value is Dictionary:

				var state: Dictionary = (
					state_value
				)


				var state_health = (
					state.get(
						"health",
						state.get(
							"current_health",
							state.get(
								"hp",
								null
							)
						)
					)
				)


				var state_max_health = (
					state.get(
						"max_health",
						state.get(
							"max",
							null
						)
					)
				)


				var state_life = (
					state.get(
						"life_state",
						state.get(
							"life",
							state.get(
								"state",
								null
							)
						)
					)
				)


				if (
					state_health != null
					and state_max_health != null
					and state_life != null
				):

					return {
						"health":
							float(
								state_health
							),

						"max_health":
							float(
								state_max_health
							),

						"life_state":
							str(
								state_life
							)
					}


	# -----------------------------------------------------
	# FALLBACK LIMITADO AL HOST LOCAL
	#
	# Nunca usamos un valor enviado por un Client.
	# Player/Health local es solamente representación
	# del estado autoritativo del Peer 1.
	# -----------------------------------------------------

	if (
		peer_id == 1
		and NetworkManager.is_host()
		and local_health != null
		and is_instance_valid(
			local_health
		)
	):

		return {
			"health":
				float(
					local_health.current_health
				),

			"max_health":
				float(
					local_health.max_health
				),

			"life_state":
				str(
					local_health.get_state_name()
				)
		}


	return {}


# =========================================================
# ASEGURAR AVATAR
# =========================================================

func ensure_remote_player(
	peer_id: int,
	start_position: Vector2
):

	if NetworkManager.is_restart_in_progress():
		return null


	var remote_player = (
		get_remote_player(
			peer_id
		)
	)


	if remote_player != null:

		return remote_player


	return create_remote_player(
		peer_id,
		start_position
	)


# =========================================================
# CREAR AVATAR
# =========================================================

func create_remote_player(
	peer_id: int,
	start_position: Vector2
):

	if NetworkManager.is_restart_in_progress():
		return null


	if remote_players.has(
		peer_id
	):

		return remote_players[
			peer_id
		]


	var avatar = (
		NETWORK_PLAYER_AVATAR.new()
	)


	avatar.name = (
		"RemotePlayer_"
		+ str(
			peer_id
		)
	)


	add_child(
		avatar
	)


	avatar.setup(
		peer_id,
		start_position
	)


	remote_players[
		peer_id
	] = avatar


	if print_network_players:

		print(
			"[NET PLAYER] Remote avatar created | ID: ",
			peer_id
		)


	return avatar


# =========================================================
# GET REMOTE
# =========================================================

func get_remote_player(
	peer_id: int
):

	if not remote_players.has(
		peer_id
	):

		return null


	var avatar = (
		remote_players[
			peer_id
		]
	)


	if not is_instance_valid(
		avatar
	):

		remote_players.erase(
			peer_id
		)


		return null


	return avatar


# =========================================================
# DESCONECTAR
# =========================================================

func _on_player_disconnected(
	peer_id: int
):

	remove_remote_player(
		peer_id
	)


func remove_remote_player(
	peer_id: int
):

	if not remote_players.has(
		peer_id
	):

		return


	var avatar = (
		remote_players[
			peer_id
		]
	)


	if is_instance_valid(
		avatar
	):

		avatar.queue_free()


	remote_players.erase(
		peer_id
	)


	if print_network_players:

		print(
			"[NET PLAYER] Remote avatar removed | ID: ",
			peer_id
		)


# =========================================================
# NETWORK STATE
# =========================================================

func _on_network_state_changed(
	new_state: String
):

	if new_state != "OFFLINE":
		return


	clear_remote_players()


# =========================================================
# NETWORK RESTART
# =========================================================

func _on_network_restart_started():

	clear_remote_players()


# =========================================================
# LIMPIAR
# =========================================================

func clear_remote_players():

	for peer_id in remote_players.keys():

		var avatar = (
			remote_players[
				peer_id
			]
		)


		if is_instance_valid(
			avatar
		):

			avatar.queue_free()


	remote_players.clear()


	movement_send_accumulator = 0.0

	state_send_accumulator = 0.0


	if print_network_players:

		print(
			"[NET PLAYER] Remote avatars cleared"
		)


# =========================================================
# CONSULTAS
# =========================================================

func get_remote_player_count() -> int:

	var valid_count: int = 0


	for peer_id in remote_players.keys():

		if get_remote_player(
			int(
				peer_id
			)
		) != null:

			valid_count += 1


	return valid_count


func get_remote_peer_ids() -> Array:

	var result: Array = []


	for peer_id in remote_players.keys():

		if get_remote_player(
			int(
				peer_id
			)
		) != null:

			result.append(
				int(
					peer_id
				)
			)


	result.sort()


	return result
