extends Node


# =========================================================
# CONSTANTES
# =========================================================

const LIFE_ALIVE: String = "ALIVE"
const LIFE_UNCONSCIOUS: String = "UNCONSCIOUS"
const LIFE_DEAD: String = "DEAD"


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("Synchronization")
@export var sync_interval: float = 0.10

@export_group("Debug")
@export var print_health_events: bool = true
@export var print_snapshots: bool = true


# =========================================================
# REFERENCIAS
# =========================================================

@onready var local_health = (
	get_node_or_null(
		"../Player/Health"
	)
)


# =========================================================
# ESTADO
# =========================================================

var health_states: Dictionary = {}
var sync_accumulator: float = 0.0


# =========================================================
# READY
# =========================================================

func _ready():

	add_to_group(
		"network_player_health_manager"
	)

	process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	NetworkManager.player_connected.connect(
		_on_player_connected
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

	call_deferred(
		"_initialize_online_state"
	)

	print(
		"[NET HEALTH] Manager ready"
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

	ensure_all_host_states()

	process_unconscious_timers(
		delta
	)

	sync_accumulator += delta

	if sync_accumulator < sync_interval:
		return

	sync_accumulator = 0.0

	broadcast_health_state()


# =========================================================
# INICIALIZAR ONLINE
# =========================================================

func _initialize_online_state():

	await get_tree().process_frame

	if NetworkManager.is_restart_in_progress():
		return

	if not NetworkManager.is_online():
		return

	if not NetworkManager.is_host():
		return

	ensure_all_host_states()


# =========================================================
# ASEGURAR ESTADOS DEL HOST
# =========================================================

func ensure_all_host_states():

	if not NetworkManager.is_host():
		return

	ensure_peer_state(
		1
	)

	var multiplayer_api = (
		get_multiplayer()
	)

	if multiplayer_api == null:
		return

	var peers: PackedInt32Array = (
		multiplayer_api.get_peers()
	)

	for peer_id in peers:

		ensure_peer_state(
			int(peer_id)
		)


# =========================================================
# ASEGURAR PLAYER
# =========================================================

func ensure_peer_state(
	peer_id: int
):

	if peer_id <= 0:
		return

	if health_states.has(
		peer_id
	):
		return

	var maximum_health: float = (
		get_default_max_health()
	)

	var initial_health: float = (
		maximum_health
	)

	var life_state: String = (
		LIFE_ALIVE
	)

	var unconscious_timer: float = 0.0

	if (
		peer_id == 1
		and local_health != null
		and is_instance_valid(
			local_health
		)
	):

		maximum_health = float(
			local_health.max_health
		)

		initial_health = float(
			local_health.current_health
		)

		life_state = str(
			local_health.get_state_name()
		)

		unconscious_timer = float(
			local_health.unconscious_timer
		)

	health_states[
		peer_id
	] = {
		"health":
			initial_health,

		"max_health":
			maximum_health,

		"life_state":
			life_state,

		"unconscious_timer":
			unconscious_timer
	}

	if print_health_events:

		print(
			"[NET HEALTH] State created | Peer ",
			peer_id,
			" | HP ",
			initial_health,
			"/",
			maximum_health,
			" | ",
			life_state
		)


# =========================================================
# CONFIG BASE
# =========================================================

func get_default_max_health() -> float:

	if (
		local_health != null
		and is_instance_valid(
			local_health
		)
	):

		return max(
			float(
				local_health.max_health
			),
			1.0
		)

	return 100.0


func get_unconscious_duration() -> float:

	if (
		local_health != null
		and is_instance_valid(
			local_health
		)
	):

		return max(
			float(
				local_health.unconscious_time_before_death
			),
			0.0
		)

	return 30.0


# =========================================================
# REQUEST LOCAL DAMAGE
# =========================================================

func request_local_damage(
	amount: float,
	damage_type: StringName = &"generic"
) -> bool:

	if amount <= 0.0:
		return false

	if not NetworkManager.is_online():
		return false

	if NetworkManager.is_host():

		return apply_damage_to_peer(
			1,
			amount,
			damage_type
		)

	if not is_client_environment_damage_allowed(
		damage_type
	):

		if print_health_events:

			print(
				"[NET HEALTH][REJECT] Client local damage source | ",
				damage_type
			)

		return false

	request_environment_damage_from_host.rpc_id(
		1,
		amount,
		str(
			damage_type
		)
	)

	return true


# =========================================================
# CLIENT -> HOST ENVIRONMENT DAMAGE
# =========================================================

@rpc(
	"any_peer",
	"call_remote",
	"reliable"
)
func request_environment_damage_from_host(
	amount: float,
	damage_type: String
):

	if not NetworkManager.is_host():
		return

	if NetworkManager.is_restart_in_progress():
		return

	var peer_id: int = (
		multiplayer.get_remote_sender_id()
	)

	if peer_id <= 1:
		return

	var damage_name: StringName = (
		StringName(
			damage_type
		)
	)

	if not is_client_environment_damage_allowed(
		damage_name
	):

		if print_health_events:

			print(
				"[NET HEALTH][REJECT] Environment damage | Peer ",
				peer_id,
				" | ",
				damage_type
			)

		return

	if amount <= 0.0:
		return

	if amount > 1000.0:

		if print_health_events:

			print(
				"[NET HEALTH][REJECT] Excessive environment damage | Peer ",
				peer_id,
				" | ",
				amount
			)

		return

	apply_damage_to_peer(
		peer_id,
		amount,
		damage_name
	)


# =========================================================
# FUENTES TEMPORALES ACEPTADAS DESDE CLIENT
# =========================================================

func is_client_environment_damage_allowed(
	damage_type: StringName
) -> bool:

	return (
		damage_type == &"suffocation"
		or damage_type == &"pressure"
		or damage_type == &"pressure_exposure"
	)


# =========================================================
# DAMAGE AUTORITATIVO
# =========================================================

func apply_damage_to_peer(
	peer_id: int,
	amount: float,
	damage_type: StringName = &"generic"
) -> bool:

	if not NetworkManager.is_host():
		return false

	if amount <= 0.0:
		return false

	ensure_peer_state(
		peer_id
	)

	if not health_states.has(
		peer_id
	):
		return false

	var state: Dictionary = (
		health_states[
			peer_id
		]
	)

	var life_state: String = str(
		state.get(
			"life_state",
			LIFE_ALIVE
		)
	)

	if life_state == LIFE_DEAD:
		return false

	if life_state == LIFE_UNCONSCIOUS:

		state[
			"unconscious_timer"
		] = (
			float(
				state.get(
					"unconscious_timer",
					0.0
				)
			)
			+ amount
			* 0.10
		)

		health_states[
			peer_id
		] = state

		check_unconscious_death(
			peer_id
		)

		broadcast_peer_health_state(
			peer_id
		)

		return true

	var maximum_health: float = max(
		float(
			state.get(
				"max_health",
				get_default_max_health()
			)
		),
		1.0
	)

	var current_health: float = float(
		state.get(
			"health",
			maximum_health
		)
	)

	current_health -= amount

	current_health = clamp(
		current_health,
		0.0,
		maximum_health
	)

	state[
		"health"
	] = current_health

	if current_health <= 0.0:

		state[
			"health"
		] = 0.0

		state[
			"life_state"
		] = LIFE_UNCONSCIOUS

		state[
			"unconscious_timer"
		] = 0.0

	health_states[
		peer_id
	] = state

	apply_state_to_host_local_if_needed(
		peer_id
	)

	broadcast_peer_health_state(
		peer_id
	)

	if print_health_events:

		print(
			"[NET HEALTH][DAMAGE] Peer ",
			peer_id,
			" | -",
			amount,
			" | ",
			damage_type,
			" | HP ",
			state[
				"health"
			],
			" | ",
			state[
				"life_state"
			]
		)

	return true


# =========================================================
# HEAL AUTORITATIVO
# =========================================================

func heal_peer(
	peer_id: int,
	amount: float
) -> bool:

	if not NetworkManager.is_host():
		return false

	if amount <= 0.0:
		return false

	ensure_peer_state(
		peer_id
	)

	if not health_states.has(
		peer_id
	):
		return false

	var state: Dictionary = (
		health_states[
			peer_id
		]
	)

	if str(
		state.get(
			"life_state",
			LIFE_ALIVE
		)
	) == LIFE_DEAD:

		return false

	if str(
		state.get(
			"life_state",
			LIFE_ALIVE
		)
	) == LIFE_UNCONSCIOUS:

		return false

	var maximum_health: float = max(
		float(
			state[
				"max_health"
			]
		),
		1.0
	)

	state[
		"health"
	] = clamp(
		float(
			state[
				"health"
			]
		)
		+ amount,
		0.0,
		maximum_health
	)

	health_states[
		peer_id
	] = state

	apply_state_to_host_local_if_needed(
		peer_id
	)

	broadcast_peer_health_state(
		peer_id
	)

	return true


# =========================================================
# FORZAR INCONSCIENTE
# =========================================================

func force_unconscious_peer(
	peer_id: int
) -> bool:

	if not NetworkManager.is_host():
		return false

	ensure_peer_state(
		peer_id
	)

	if not health_states.has(
		peer_id
	):
		return false

	var state: Dictionary = (
		health_states[
			peer_id
		]
	)

	if str(
		state.get(
			"life_state",
			LIFE_ALIVE
		)
	) == LIFE_DEAD:

		return false

	state[
		"health"
	] = 0.0

	state[
		"life_state"
	] = LIFE_UNCONSCIOUS

	state[
		"unconscious_timer"
	] = 0.0

	health_states[
		peer_id
	] = state

	apply_state_to_host_local_if_needed(
		peer_id
	)

	broadcast_peer_health_state(
		peer_id
	)

	return true


# =========================================================
# REVIVE
# =========================================================

func revive_peer(
	peer_id: int,
	health_percentage: float = 0.25
) -> bool:

	if not NetworkManager.is_host():
		return false

	ensure_peer_state(
		peer_id
	)

	if not health_states.has(
		peer_id
	):
		return false

	var state: Dictionary = (
		health_states[
			peer_id
		]
	)

	if str(
		state.get(
			"life_state",
			LIFE_ALIVE
		)
	) != LIFE_UNCONSCIOUS:

		return false

	var maximum_health: float = max(
		float(
			state[
				"max_health"
			]
		),
		1.0
	)

	state[
		"health"
	] = clamp(
		maximum_health
		* health_percentage,
		1.0,
		maximum_health
	)

	state[
		"life_state"
	] = LIFE_ALIVE

	state[
		"unconscious_timer"
	] = 0.0

	health_states[
		peer_id
	] = state

	apply_state_to_host_local_if_needed(
		peer_id
	)

	broadcast_peer_health_state(
		peer_id
	)

	return true


# =========================================================
# MUERTE
# =========================================================

func force_die_peer(
	peer_id: int
) -> bool:

	if not NetworkManager.is_host():
		return false

	ensure_peer_state(
		peer_id
	)

	if not health_states.has(
		peer_id
	):
		return false

	var state: Dictionary = (
		health_states[
			peer_id
		]
	)

	if str(
		state.get(
			"life_state",
			LIFE_ALIVE
		)
	) == LIFE_DEAD:

		return false

	state[
		"health"
	] = 0.0

	state[
		"life_state"
	] = LIFE_DEAD

	health_states[
		peer_id
	] = state

	apply_state_to_host_local_if_needed(
		peer_id
	)

	broadcast_peer_health_state(
		peer_id
	)

	if print_health_events:

		print(
			"[NET HEALTH][DEAD] Peer ",
			peer_id
		)

	return true


# =========================================================
# TIMERS INCONSCIENTES
# =========================================================

func process_unconscious_timers(
	delta: float
):

	var peer_ids: Array = (
		health_states.keys()
	)

	for peer_key in peer_ids:

		var peer_id: int = int(
			peer_key
		)

		var state: Dictionary = (
			health_states[
				peer_key
			]
		)

		if str(
			state.get(
				"life_state",
				LIFE_ALIVE
			)
		) != LIFE_UNCONSCIOUS:

			continue

		state[
			"unconscious_timer"
		] = (
			float(
				state.get(
					"unconscious_timer",
					0.0
				)
			)
			+ delta
		)

		health_states[
			peer_id
		] = state

		check_unconscious_death(
			peer_id
		)


# =========================================================
# CHECK MUERTE
# =========================================================

func check_unconscious_death(
	peer_id: int
):

	if not health_states.has(
		peer_id
	):
		return

	var state: Dictionary = (
		health_states[
			peer_id
		]
	)

	if str(
		state.get(
			"life_state",
			LIFE_ALIVE
		)
	) != LIFE_UNCONSCIOUS:

		return

	if (
		float(
			state.get(
				"unconscious_timer",
				0.0
			)
		)
		< get_unconscious_duration()
	):

		return

	state[
		"health"
	] = 0.0

	state[
		"life_state"
	] = LIFE_DEAD

	health_states[
		peer_id
	] = state

	apply_state_to_host_local_if_needed(
		peer_id
	)

	broadcast_peer_health_state(
		peer_id
	)

	if print_health_events:

		print(
			"[NET HEALTH][DEAD] Peer ",
			peer_id,
			" | Unconscious timeout"
		)


# =========================================================
# APLICAR AL PLAYER LOCAL DEL HOST
# =========================================================

func apply_state_to_host_local_if_needed(
	peer_id: int
):

	if peer_id != 1:
		return

	if local_health == null:
		return

	if not is_instance_valid(
		local_health
	):
		return

	if not health_states.has(
		peer_id
	):
		return

	var state: Dictionary = (
		health_states[
			peer_id
		]
	)

	if not local_health.has_method(
		"apply_network_health_state"
	):
		return

	local_health.apply_network_health_state(
		float(
			state[
				"health"
			]
		),
		float(
			state[
				"max_health"
			]
		),
		str(
			state[
				"life_state"
			]
		),
		float(
			state[
				"unconscious_timer"
			]
		)
	)


# =========================================================
# BROADCAST COMPLETO
# =========================================================

func broadcast_health_state():

	if not NetworkManager.is_online():
		return

	if not NetworkManager.is_host():
		return

	receive_health_state.rpc(
		health_states
	)


# =========================================================
# HOST -> CLIENT PERIODIC
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"unreliable"
)
func receive_health_state(
	state: Dictionary
):

	if NetworkManager.is_restart_in_progress():
		return

	if NetworkManager.is_host():
		return

	health_states = (
		state.duplicate(
			true
		)
	)

	apply_local_authoritative_state()


# =========================================================
# ESTADO INDIVIDUAL RELIABLE
# =========================================================

func broadcast_peer_health_state(
	peer_id: int
):

	if not NetworkManager.is_host():
		return

	if not health_states.has(
		peer_id
	):
		return

	apply_state_to_host_local_if_needed(
		peer_id
	)

	receive_peer_health_state.rpc(
		peer_id,
		health_states[
			peer_id
		]
	)


@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func receive_peer_health_state(
	peer_id: int,
	state: Dictionary
):

	if NetworkManager.is_restart_in_progress():
		return

	if NetworkManager.is_host():
		return

	health_states[
		peer_id
	] = state.duplicate(
		true
	)

	apply_local_authoritative_state()


# =========================================================
# APLICAR ESTADO LOCAL CLIENT
# =========================================================

func apply_local_authoritative_state():

	if not NetworkManager.is_online():
		return

	var multiplayer_api = (
		get_multiplayer()
	)

	if multiplayer_api == null:
		return

	var local_peer_id: int = (
		multiplayer_api.get_unique_id()
	)

	if not health_states.has(
		local_peer_id
	):
		return

	if local_health == null:
		return

	if not is_instance_valid(
		local_health
	):
		return

	if not local_health.has_method(
		"apply_network_health_state"
	):
		return

	var state: Dictionary = (
		health_states[
			local_peer_id
		]
	)

	local_health.apply_network_health_state(
		float(
			state[
				"health"
			]
		),
		float(
			state[
				"max_health"
			]
		),
		str(
			state[
				"life_state"
			]
		),
		float(
			state[
				"unconscious_timer"
			]
		)
	)


# =========================================================
# PLAYER CONNECTED
# =========================================================

func _on_player_connected(
	peer_id: int
):

	if NetworkManager.is_restart_in_progress():
		return

	if not NetworkManager.is_host():
		return

	if peer_id <= 1:
		return

	ensure_peer_state(
		peer_id
	)

	call_deferred(
		"send_health_snapshot",
		peer_id
	)


# =========================================================
# PLAYER DISCONNECTED
# =========================================================

func _on_player_disconnected(
	peer_id: int
):

	if health_states.has(
		peer_id
	):

		health_states.erase(
			peer_id
		)


# =========================================================
# SNAPSHOT
# =========================================================

func send_health_snapshot(
	peer_id: int
):

	await get_tree().process_frame
	await get_tree().process_frame

	if NetworkManager.is_restart_in_progress():
		return

	if not NetworkManager.is_host():
		return

	ensure_all_host_states()

	receive_health_snapshot.rpc_id(
		peer_id,
		health_states
	)

	if print_snapshots:

		print(
			"[NET HEALTH] Snapshot sent | Peer ",
			peer_id,
			" | Players ",
			health_states.size()
		)


@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func receive_health_snapshot(
	state: Dictionary
):

	if NetworkManager.is_restart_in_progress():
		return

	if NetworkManager.is_host():
		return

	health_states = (
		state.duplicate(
			true
		)
	)

	apply_local_authoritative_state()


# =========================================================
# NETWORK STATE
# =========================================================

func _on_network_state_changed(
	new_state: String
):

	if new_state == "OFFLINE":

		health_states.clear()
		sync_accumulator = 0.0

		return

	call_deferred(
		"_initialize_online_state"
	)


func _on_network_restart_started():

	health_states.clear()
	sync_accumulator = 0.0


# =========================================================
# CONSULTAS
# =========================================================

func get_peer_state(
	peer_id: int
) -> Dictionary:

	if not health_states.has(
		peer_id
	):
		return {}

	return (
		health_states[
			peer_id
		].duplicate(
			true
		)
	)


func get_peer_health(
	peer_id: int
) -> float:

	if not health_states.has(
		peer_id
	):
		return 0.0

	return float(
		health_states[
			peer_id
		].get(
			"health",
			0.0
		)
	)


func get_peer_max_health(
	peer_id: int
) -> float:

	if not health_states.has(
		peer_id
	):

		return get_default_max_health()

	return float(
		health_states[
			peer_id
		].get(
			"max_health",
			get_default_max_health()
		)
	)


func get_peer_life_state(
	peer_id: int
) -> String:

	if not health_states.has(
		peer_id
	):

		return LIFE_ALIVE

	return str(
		health_states[
			peer_id
		].get(
			"life_state",
			LIFE_ALIVE
		)
	)


func is_peer_alive(
	peer_id: int
) -> bool:

	return (
		get_peer_life_state(
			peer_id
		)
		!= LIFE_DEAD
	)
