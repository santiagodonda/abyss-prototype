extends Node


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("Synchronization")

@export var environment_sync_interval: float = 0.10


@export_group("Debug")

@export var print_snapshots: bool = true


# =========================================================
# FALLBACK RESPIRACIÓN REMOTA
# =========================================================

const DEFAULT_OXYGEN_CONSUMPTION_RATE: float = 0.0006

const DEFAULT_MINIMUM_BREATHABLE_OXYGEN: float = 0.20

const DEFAULT_TRANSITION_TOLERANCE: float = 50.0


# =========================================================
# ESTADO
# =========================================================

var environment_sync_accumulator: float = 0.0

var room_cache: Dictionary = {}


# =========================================================
# REFERENCIAS
# =========================================================

@onready var network_player_manager = (
	get_node_or_null(
		"../NetworkPlayerManager"
	)
)


@onready var local_player = (
	get_node_or_null(
		"../Player"
	)
)


@onready var local_vitals = (
	get_node_or_null(
		"../Player/Vitals"
	)
)


@onready var local_breathing_point = (
	get_node_or_null(
		"../Player/BreathingPoint"
	)
)


@onready var submarine_environment = (
	get_node_or_null(
		"../SubmarineEnvironment"
	)
)


# =========================================================
# READY
# =========================================================

func _ready():

	process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)


	rebuild_room_cache()


	NetworkManager.player_connected.connect(
		_on_player_connected
	)


	print(
		"[NET ENV] Manager ready"
	)


# =========================================================
# PROCESS
# =========================================================

func _process(
	delta: float
):

	if NetworkManager.is_restart_in_progress():
		return


	if not NetworkManager.is_online():
		return


	if not NetworkManager.is_host():
		return


	environment_sync_accumulator += delta


	if (
		environment_sync_accumulator
		< environment_sync_interval
	):

		return


	var simulation_delta: float = (
		environment_sync_accumulator
	)


	environment_sync_accumulator = 0.0


	simulate_remote_player_oxygen_consumption(
		simulation_delta
	)


	var environment_state: Dictionary = (
		build_environment_state()
	)


	if environment_state.is_empty():
		return


	receive_environment_state.rpc(
		environment_state
	)


# =========================================================
# ESTADO AMBIENTAL COMPLETO
# =========================================================

func build_environment_state() -> Dictionary:

	return {
		"rooms":
			build_room_state(),

		"depth_meters":
			get_authoritative_depth()
	}


# =========================================================
# ROOMS
# =========================================================

func rebuild_room_cache():

	room_cache.clear()


	var rooms: Array = (
		get_tree().get_nodes_in_group(
			"rooms"
		)
	)


	for room in rooms:

		if room == null:
			continue


		if not is_instance_valid(
			room
		):
			continue


		var room_id: String = str(
			room.get(
				"room_id"
			)
		)


		if room_id.is_empty():
			continue


		room_cache[
			room_id
		] = room


func build_room_state() -> Dictionary:

	var state: Dictionary = {}


	var rooms: Array = (
		get_tree().get_nodes_in_group(
			"rooms"
		)
	)


	for room in rooms:

		if room == null:
			continue


		if not is_instance_valid(
			room
		):
			continue


		var room_id: String = str(
			room.get(
				"room_id"
			)
		)


		if room_id.is_empty():
			continue


		state[
			room_id
		] = {
			"water_level":
				float(
					room.get(
						"water_level"
					)
				),

			"oxygen_level":
				float(
					room.get(
						"oxygen_level"
					)
				),

			"pressure":
				float(
					room.get(
						"pressure"
					)
				)
		}


	return state


# =========================================================
# DEPTH
# =========================================================

func get_authoritative_depth() -> float:

	if submarine_environment == null:
		return 0.0


	return float(
		submarine_environment.get(
			"depth_meters"
		)
	)


# =========================================================
# HOST -> CLIENTS
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"unreliable"
)
func receive_environment_state(
	state: Dictionary
):

	if NetworkManager.is_restart_in_progress():
		return


	apply_environment_state(
		state
	)


# =========================================================
# SNAPSHOT RELIABLE
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func receive_environment_snapshot(
	state: Dictionary
):

	if NetworkManager.is_restart_in_progress():
		return


	apply_environment_state(
		state
	)


# =========================================================
# APLICAR ESTADO
# =========================================================

func apply_environment_state(
	state: Dictionary
):

	if NetworkManager.is_host():
		return


	if state.has(
		"rooms"
	):

		var rooms_state = (
			state[
				"rooms"
			]
		)


		if rooms_state is Dictionary:

			apply_room_state(
				rooms_state
			)


	if state.has(
		"depth_meters"
	):

		if (
			submarine_environment != null
			and submarine_environment.has_method(
				"apply_network_depth"
			)
		):

			submarine_environment.apply_network_depth(
				float(
					state[
						"depth_meters"
					]
				)
			)


func apply_room_state(
	state: Dictionary
):

	if room_cache.is_empty():

		rebuild_room_cache()


	for room_key in state.keys():

		var room_id: String = str(
			room_key
		)


		if not room_cache.has(
			room_id
		):

			rebuild_room_cache()


		if not room_cache.has(
			room_id
		):

			continue


		var room = (
			room_cache[
				room_id
			]
		)


		if room == null:
			continue


		if not is_instance_valid(
			room
		):
			continue


		var received_state = (
			state[
				room_key
			]
		)


		if not (
			received_state
			is Dictionary
		):

			continue


		if received_state.has(
			"water_level"
		):

			if room.has_method(
				"apply_network_water_level"
			):

				room.apply_network_water_level(
					float(
						received_state[
							"water_level"
						]
					)
				)


		if received_state.has(
			"oxygen_level"
		):

			if room.has_method(
				"apply_network_oxygen_level"
			):

				room.apply_network_oxygen_level(
					float(
						received_state[
							"oxygen_level"
						]
					)
				)


		if received_state.has(
			"pressure"
		):

			if room.has_method(
				"apply_network_pressure"
			):

				room.apply_network_pressure(
					float(
						received_state[
							"pressure"
						]
					)
				)


# =========================================================
# RESPIRACIÓN REMOTA
# =========================================================

func simulate_remote_player_oxygen_consumption(
	delta: float
):

	if not NetworkManager.is_host():
		return


	if network_player_manager == null:
		return


	if not network_player_manager.has_method(
		"get_remote_player"
	):

		return


	var multiplayer_api = (
		get_multiplayer()
	)


	if multiplayer_api == null:
		return


	var peer_ids: PackedInt32Array = (
		multiplayer_api.get_peers()
	)


	if peer_ids.is_empty():
		return


	var consumption_rate: float = (
		get_remote_oxygen_consumption_rate()
	)


	var minimum_oxygen: float = (
		get_remote_minimum_breathable_oxygen()
	)


	var breathing_offset: Vector2 = (
		get_breathing_point_offset()
	)


	for peer_id in peer_ids:

		var remote_player = (
			network_player_manager.get_remote_player(
				int(
					peer_id
				)
			)
		)


		if remote_player == null:
			continue


		if not is_instance_valid(
			remote_player
		):
			continue


		var remote_position_value = (
			remote_player.get(
				"target_position"
			)
		)


		if remote_position_value == null:
			continue


		var remote_position: Vector2 = (
			remote_position_value
		)


		var room = (
			find_room_for_position(
				remote_position
			)
		)


		if room == null:
			continue


		var breathing_position: Vector2 = (
			remote_position
			+ breathing_offset
		)


		if room.is_point_underwater(
			breathing_position
		):

			continue


		if (
			float(
				room.oxygen_level
			)
			< minimum_oxygen
		):

			continue


		room.consume_oxygen(
			consumption_rate
			* delta
		)


# =========================================================
# BUSCAR ROOM
# =========================================================

func find_room_for_position(
	player_position: Vector2
):

	if room_cache.is_empty():

		rebuild_room_cache()


	for room in room_cache.values():

		if room == null:
			continue


		if not is_instance_valid(
			room
		):
			continue


		if room.contains_global_point(
			player_position
		):

			return room


	var transition_tolerance: float = (
		get_remote_transition_tolerance()
	)


	var closest_room = null

	var closest_distance: float = INF


	for room in room_cache.values():

		if room == null:
			continue


		if not is_instance_valid(
			room
		):
			continue


		var distance: float = (
			get_distance_to_room_rect(
				room,
				player_position
			)
		)


		if (
			distance
			<= transition_tolerance
			and distance
			< closest_distance
		):

			closest_distance = distance

			closest_room = room


	return closest_room


func get_distance_to_room_rect(
	room: Node,
	global_point: Vector2
) -> float:

	var local_point: Vector2 = (
		room.to_local(
			global_point
		)
	)


	var minimum_corner: Vector2 = (
		room.room_position
	)


	var maximum_corner: Vector2 = (
		room.room_position
		+ room.room_size
	)


	var closest_point: Vector2 = Vector2(
		clamp(
			local_point.x,
			minimum_corner.x,
			maximum_corner.x
		),
		clamp(
			local_point.y,
			minimum_corner.y,
			maximum_corner.y
		)
	)


	return local_point.distance_to(
		closest_point
	)


# =========================================================
# CONFIG RESPIRACIÓN REMOTA
# =========================================================

func get_remote_oxygen_consumption_rate() -> float:

	if local_vitals != null:

		var value = (
			local_vitals.get(
				"oxygen_consumption_rate"
			)
		)


		if value != null:

			return float(
				value
			)


	return (
		DEFAULT_OXYGEN_CONSUMPTION_RATE
	)


func get_remote_minimum_breathable_oxygen() -> float:

	if local_vitals != null:

		var value = (
			local_vitals.get(
				"minimum_breathable_oxygen"
			)
		)


		if value != null:

			return float(
				value
			)


	return (
		DEFAULT_MINIMUM_BREATHABLE_OXYGEN
	)


func get_remote_transition_tolerance() -> float:

	if local_vitals != null:

		var value = (
			local_vitals.get(
				"transition_tolerance"
			)
		)


		if value != null:

			return float(
				value
			)


	return (
		DEFAULT_TRANSITION_TOLERANCE
	)


func get_breathing_point_offset() -> Vector2:

	if (
		local_player == null
		or local_breathing_point == null
	):

		return Vector2(
			0.0,
			-15.0
		)


	if (
		not is_instance_valid(
			local_player
		)
		or not is_instance_valid(
			local_breathing_point
		)
	):

		return Vector2(
			0.0,
			-15.0
		)


	return (
		local_breathing_point.global_position
		- local_player.global_position
	)


# =========================================================
# NUEVO CLIENT
# =========================================================

func _on_player_connected(
	peer_id: int
):

	if NetworkManager.is_restart_in_progress():
		return


	if not NetworkManager.is_host():
		return


	if peer_id == 1:
		return


	call_deferred(
		"send_environment_snapshot",
		peer_id
	)


# =========================================================
# LATE JOIN
# =========================================================

func send_environment_snapshot(
	peer_id: int
):

	if NetworkManager.is_restart_in_progress():
		return


	if not NetworkManager.is_host():
		return


	await get_tree().process_frame

	await get_tree().process_frame


	if NetworkManager.is_restart_in_progress():
		return


	var state: Dictionary = (
		build_environment_state()
	)


	receive_environment_snapshot.rpc_id(
		peer_id,
		state
	)


	var room_count: int = 0


	if state.has(
		"rooms"
	):

		var rooms_state = (
			state[
				"rooms"
			]
		)


		if rooms_state is Dictionary:

			room_count = (
				rooms_state.size()
			)


	if print_snapshots:

		print(
			"[NET ENV] Environment snapshot sent | Peer ",
			peer_id,
			" | Rooms ",
			room_count,
			" | Depth ",
			int(
				round(
					get_authoritative_depth()
				)
			),
			" m"
		)
