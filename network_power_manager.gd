extends Node


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("Network")

@export_range(
	1.0,
	30.0,
	1.0
)
var sync_rate_hz: float = 10.0


@export_group("Debug")

@export var print_power_events: bool = true


# =========================================================
# ESTADO
# =========================================================

var sync_accumulator: float = 0.0

var last_debug_signature: String = ""


# =========================================================
# REFERENCIAS
# =========================================================

@onready var power_system = (
	get_node_or_null(
		"../PowerSystem"
	)
)


# =========================================================
# READY
# =========================================================

func _ready():

	process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)


	add_to_group(
		"network_power_manager"
	)


	NetworkManager.player_connected.connect(
		_on_player_connected
	)


	if print_power_events:

		print(
			"[NET POWER] Manager ready"
		)


# =========================================================
# PROCESS
# =========================================================

func _process(
	delta: float
):

	if not NetworkManager.is_online():
		return


	if not NetworkManager.is_host():
		return


	if power_system == null:
		return


	if not is_instance_valid(
		power_system
	):
		return


	sync_accumulator += delta


	var sync_interval: float = (
		1.0
		/ max(
			sync_rate_hz,
			1.0
		)
	)


	if sync_accumulator < sync_interval:
		return


	sync_accumulator = 0.0


	broadcast_power_state()


# =========================================================
# HOST — BROADCAST
# =========================================================

func broadcast_power_state():

	if not NetworkManager.is_online():
		return


	if not NetworkManager.is_host():
		return


	if power_system == null:
		return


	var state: Dictionary = (
		power_system.build_network_state()
	)


	receive_power_state.rpc(
		state
	)


	print_state_if_changed(
		"HOST",
		state
	)


# =========================================================
# HOST -> CLIENTS
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"unreliable"
)
func receive_power_state(
	state: Dictionary
):

	if not NetworkManager.is_client():
		return


	if power_system == null:
		return


	power_system.apply_network_state(
		state
	)


	print_state_if_changed(
		"CLIENT",
		state
	)


# =========================================================
# PLAYER CONNECTED
# =========================================================

func _on_player_connected(
	peer_id: int
):

	if not NetworkManager.is_online():
		return


	if not NetworkManager.is_host():
		return


	if peer_id == 1:
		return


	call_deferred(
		"send_power_snapshot",
		peer_id
	)


# =========================================================
# SNAPSHOT
# =========================================================

func send_power_snapshot(
	peer_id: int
):

	if not NetworkManager.is_host():
		return


	if power_system == null:
		return


	await get_tree().process_frame

	await get_tree().process_frame


	if not NetworkManager.is_online():
		return


	if not NetworkManager.is_host():
		return


	if not multiplayer.get_peers().has(
		peer_id
	):
		return


	var state: Dictionary = (
		power_system.build_network_state()
	)


	receive_power_snapshot.rpc_id(
		peer_id,
		state
	)


	if print_power_events:

		print(
			"[NET POWER] Snapshot sent | Peer ",
			peer_id,
			" | Reactor ",
			state.get(
				"reactor_on",
				false
			),
			" | Demand ",
			state.get(
				"total_demand",
				0.0
			),
			" | Available ",
			state.get(
				"available_output",
				0.0
			),
			" | HasPower ",
			state.get(
				"has_power",
				false
			)
		)


# =========================================================
# SNAPSHOT RECEIVE
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func receive_power_snapshot(
	state: Dictionary
):

	if not NetworkManager.is_client():
		return


	if power_system == null:
		return


	power_system.apply_network_state(
		state
	)


	if print_power_events:

		print(
			"[NET POWER] Snapshot received | Reactor ",
			state.get(
				"reactor_on",
				false
			),
			" | Demand ",
			state.get(
				"total_demand",
				0.0
			),
			" | Available ",
			state.get(
				"available_output",
				0.0
			),
			" | HasPower ",
			state.get(
				"has_power",
				false
			)
		)


	print_state_if_changed(
		"CLIENT",
		state
	)


# =========================================================
# DEBUG
# =========================================================

func print_state_if_changed(
	source: String,
	state: Dictionary
):

	if not print_power_events:
		return


	var reactor_state: bool = bool(
		state.get(
			"reactor_on",
			false
		)
	)


	var efficiency: float = float(
		state.get(
			"reactor_efficiency",
			0.0
		)
	)


	var demand: float = float(
		state.get(
			"total_demand",
			0.0
		)
	)


	var available: float = float(
		state.get(
			"available_output",
			0.0
		)
	)


	var balance: float = float(
		state.get(
			"power_balance",
			0.0
		)
	)


	var has_power_value: bool = bool(
		state.get(
			"has_power",
			false
		)
	)


	var signature: String = (
		str(
			reactor_state
		)
		+ "|"
		+ str(
			int(
				round(
					efficiency
					* 1000.0
				)
			)
		)
		+ "|"
		+ str(
			int(
				round(
					demand
					* 10.0
				)
			)
		)
		+ "|"
		+ str(
			int(
				round(
					available
					* 10.0
				)
			)
		)
		+ "|"
		+ str(
			has_power_value
		)
	)


	if signature == last_debug_signature:
		return


	last_debug_signature = signature


	print(
		"[NET POWER][",
		source,
		"] Reactor=",
		reactor_state,
		" | Efficiency=",
		snapped(
			efficiency,
			0.001
		),
		" | Demand=",
		snapped(
			demand,
			0.1
		),
		" | Available=",
		snapped(
			available,
			0.1
		),
		" | Balance=",
		snapped(
			balance,
			0.1
		),
		" | HasPower=",
		has_power_value
	)
