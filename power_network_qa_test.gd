extends Node


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("QA")

@export var start_on_run: bool = false

@export var network_timeout: float = 60.0

@export var stage_timeout: float = 8.0

@export var state_tolerance: float = 0.25

@export var environment_guard_interval: float = 0.10


# =========================================================
# FASE
# =========================================================

enum Phase {
	IDLE,
	WAIT_NETWORK,

	HOST_WAIT_CLIENT,
	HOST_WAIT_STAGE_RESULT,
	HOST_WAIT_MUTATION_RESULT,
	HOST_WAIT_DISCONNECT,
	HOST_WAIT_RECONNECT,
	HOST_WAIT_LATE_JOIN_RESULT,

	CLIENT_WAIT_COMMAND,
	CLIENT_WAIT_EXPECTED_STATE,
	CLIENT_WAIT_DISCONNECT,
	CLIENT_WAIT_RECONNECT,
	CLIENT_WAIT_LATE_JOIN_STATE,

	COMPLETE,
	FAILED
}


var phase: Phase = Phase.IDLE


# =========================================================
# REFERENCIAS
# =========================================================

var power_system = null
var network_power_manager = null

var reactor = null
var oxygen_generator = null
var pump_right = null
var pressure_regulator = null

var room_left = null
var room_right = null

var sea_creature = null


# =========================================================
# QA
# =========================================================

var pass_count: int = 0
var fail_count: int = 0
var skip_count: int = 0

var phase_timer: float = 0.0
var total_timer: float = 0.0
var guard_accumulator: float = 0.0


# =========================================================
# NETWORK
# =========================================================

var remote_peer_id: int = 0
var original_remote_peer_id: int = 0
var late_join_peer_id: int = 0

var was_online: bool = false
var has_been_online: bool = false

var primary_complete: bool = false
var client_poisoned: bool = false

var saw_primary_disconnect: bool = false


# =========================================================
# ESTADO ESPERADO CLIENT
# =========================================================

var client_expected_active: bool = false

var client_expected_step: int = 0
var client_expected_key: String = ""

var client_expected_reactor: bool = false
var client_expected_demand: float = 0.0
var client_expected_has_power: bool = false
var client_expected_output_zero: bool = true


# =========================================================
# HOST STAGES
# =========================================================

var host_stage_index: int = 0

var host_stage_result_received: bool = false
var host_stage_result_success: bool = false
var host_stage_result_key: String = ""

var host_mutation_result_received: bool = false
var host_mutation_result_success: bool = false

var host_late_join_result_received: bool = false
var host_late_join_result_success: bool = false


# =========================================================
# CREATURE ISOLATION
# =========================================================

var creature_setting_saved: bool = false
var previous_creature_hull_attack: bool = false


# =========================================================
# STAGE DEFINITIONS
# =========================================================

var stages: Array = [
	{
		"step": 3,
		"key": "baseline_off",
		"reactor": false,
		"oxygen": false,
		"pump": false,
		"pressure": false,
		"demand": 0.0,
		"has_power": false,
		"output_zero": true,
		"title": "Baseline power state"
	},
	{
		"step": 4,
		"key": "reactor_on",
		"reactor": true,
		"oxygen": false,
		"pump": false,
		"pressure": false,
		"demand": 0.0,
		"has_power": true,
		"output_zero": false,
		"title": "Reactor online"
	},
	{
		"step": 5,
		"key": "oxygen_on",
		"reactor": true,
		"oxygen": true,
		"pump": false,
		"pressure": false,
		"demand": 40.0,
		"has_power": true,
		"output_zero": false,
		"title": "Oxygen generator demand"
	},
	{
		"step": 6,
		"key": "pump_on",
		"reactor": true,
		"oxygen": true,
		"pump": true,
		"pressure": false,
		"demand": 70.0,
		"has_power": true,
		"output_zero": false,
		"title": "Pump demand"
	},
	{
		"step": 7,
		"key": "overload",
		"reactor": true,
		"oxygen": true,
		"pump": true,
		"pressure": true,
		"demand": 120.0,
		"has_power": false,
		"output_zero": false,
		"title": "Power overload"
	},
	{
		"step": 8,
		"key": "overload_recovery",
		"reactor": true,
		"oxygen": true,
		"pump": true,
		"pressure": false,
		"demand": 70.0,
		"has_power": true,
		"output_zero": false,
		"title": "Overload recovery"
	},
	{
		"step": 10,
		"key": "reactor_off_loaded",
		"reactor": false,
		"oxygen": true,
		"pump": true,
		"pressure": false,
		"demand": 70.0,
		"has_power": false,
		"output_zero": true,
		"title": "Reactor shutdown under load"
	},
	{
		"step": 11,
		"key": "late_join_base",
		"reactor": true,
		"oxygen": true,
		"pump": true,
		"pressure": false,
		"demand": 70.0,
		"has_power": true,
		"output_zero": false,
		"title": "Late join authoritative base"
	}
]


# =========================================================
# READY
# =========================================================

func _ready():

	if start_on_run:

		call_deferred(
			"start_test"
		)


# =========================================================
# START
# =========================================================

func start_test():

	reset_test_state()

	resolve_references()


	print("")
	print("[QA] ========================================")
	print("[QA] TEST: POWER NETWORK AUTHORITY")
	print("[QA] ========================================")


	if not validate_references():

		fail_step(
			1,
			"Required nodes",
			"Missing required reference or API"
		)

		finish_failed()

		return


	pass_step(
		1,
		"Required nodes",
		"Power authority references resolved"
	)


	isolate_creature()


	phase = Phase.WAIT_NETWORK

	phase_timer = 0.0
	total_timer = 0.0


# =========================================================
# RESET
# =========================================================

func reset_test_state():

	phase = Phase.IDLE

	pass_count = 0
	fail_count = 0
	skip_count = 0

	phase_timer = 0.0
	total_timer = 0.0
	guard_accumulator = 0.0

	remote_peer_id = 0
	original_remote_peer_id = 0
	late_join_peer_id = 0

	was_online = false
	has_been_online = false

	primary_complete = false
	client_poisoned = false
	saw_primary_disconnect = false

	client_expected_active = false
	client_expected_step = 0
	client_expected_key = ""

	host_stage_index = 0

	host_stage_result_received = false
	host_stage_result_success = false
	host_stage_result_key = ""

	host_mutation_result_received = false
	host_mutation_result_success = false

	host_late_join_result_received = false
	host_late_join_result_success = false

	creature_setting_saved = false
	previous_creature_hull_attack = false


# =========================================================
# REFERENCES
# =========================================================

func resolve_references():

	var scene = get_tree().current_scene


	if scene == null:
		return


	power_system = scene.get_node_or_null(
		"PowerSystem"
	)


	network_power_manager = scene.get_node_or_null(
		"NetworkPowerManager"
	)


	if network_power_manager == null:

		var managers: Array = (
			get_tree().get_nodes_in_group(
				"network_power_manager"
			)
		)


		if not managers.is_empty():

			network_power_manager = managers[0]


	reactor = scene.get_node_or_null(
		"Reactor"
	)


	oxygen_generator = scene.get_node_or_null(
		"OxygenGenerator"
	)


	pump_right = scene.get_node_or_null(
		"PumpRight"
	)


	pressure_regulator = scene.get_node_or_null(
		"PressureRegulator"
	)


	room_left = scene.get_node_or_null(
		"RoomLeft"
	)


	room_right = scene.get_node_or_null(
		"RoomRight"
	)


	sea_creature = scene.get_node_or_null(
		"SeaCreature"
	)


# =========================================================
# VALIDATION
# =========================================================

func validate_references() -> bool:

	if power_system == null:
		return false


	if network_power_manager == null:
		return false


	if reactor == null:
		return false


	if oxygen_generator == null:
		return false


	if pump_right == null:
		return false


	if pressure_regulator == null:
		return false


	if not power_system.has_method(
		"set_reactor_state"
	):
		return false


	if not power_system.has_method(
		"set_reactor_efficiency"
	):
		return false


	if not power_system.has_method(
		"set_consumer_demand"
	):
		return false


	if not power_system.has_method(
		"get_total_demand"
	):
		return false


	if not power_system.has_method(
		"get_available_output"
	):
		return false


	if not power_system.has_method(
		"get_power_balance"
	):
		return false


	if not power_system.has_method(
		"is_reactor_on"
	):
		return false


	if not power_system.has_method(
		"has_power"
	):
		return false


	if not reactor.has_method(
		"set_reactor_on"
	):
		return false


	if not oxygen_generator.has_method(
		"set_generator_on"
	):
		return false


	if not pump_right.has_method(
		"set_pump_on"
	):
		return false


	if not pressure_regulator.has_method(
		"set_regulator_on"
	):
		return false


	return true


# =========================================================
# PROCESS
# =========================================================

func _process(
	delta: float
):

	if phase == Phase.IDLE:
		return


	if phase == Phase.COMPLETE:
		return


	if phase == Phase.FAILED:
		return


	process_network_transition()

	process_environment_guard(
		delta
	)


	match phase:

		Phase.WAIT_NETWORK:

			process_wait_network(
				delta
			)


		Phase.HOST_WAIT_CLIENT:

			process_host_wait_client(
				delta
			)


		Phase.HOST_WAIT_STAGE_RESULT:

			process_host_wait_stage_result(
				delta
			)


		Phase.HOST_WAIT_MUTATION_RESULT:

			process_host_wait_mutation_result(
				delta
			)


		Phase.HOST_WAIT_DISCONNECT:

			process_host_wait_disconnect(
				delta
			)


		Phase.HOST_WAIT_RECONNECT:

			process_host_wait_reconnect(
				delta
			)


		Phase.HOST_WAIT_LATE_JOIN_RESULT:

			process_host_wait_late_join_result(
				delta
			)


		Phase.CLIENT_WAIT_EXPECTED_STATE:

			process_client_wait_expected_state(
				delta
			)


		Phase.CLIENT_WAIT_LATE_JOIN_STATE:

			process_client_wait_late_join_state(
				delta
			)


# =========================================================
# NETWORK TRANSITION
# =========================================================

func process_network_transition():

	var online_now: bool = (
		NetworkManager.is_online()
	)


	if online_now:

		has_been_online = true


	# -----------------------------------------------------
	# CLIENT:
	# detectamos el disconnect manual después del primary.
	# -----------------------------------------------------

	if (
		primary_complete
		and has_been_online
		and was_online
		and not online_now
		and not client_poisoned
	):

		poison_client_power_state()

		phase = Phase.CLIENT_WAIT_RECONNECT


		print("")
		print("[QA] Client disconnected.")
		print("[QA] Local PowerSystem deliberately poisoned.")
		print("[QA] Reconnect this Client to the same Host.")
		print("")


	# -----------------------------------------------------
	# CLIENT:
	# detectamos que volvió a entrar.
	# -----------------------------------------------------

	if (
		phase == Phase.CLIENT_WAIT_RECONNECT
		and online_now
		and NetworkManager.is_client()
	):

		phase_timer = 0.0

		phase = Phase.CLIENT_WAIT_LATE_JOIN_STATE


		print(
			"[QA] Client reconnected | Peer ",
			multiplayer.get_unique_id()
		)


	was_online = online_now


# =========================================================
# WAIT NETWORK
# =========================================================

func process_wait_network(
	delta: float
):

	total_timer += delta


	if total_timer > network_timeout:

		fail_step(
			2,
			"Network ready",
			"Timed out waiting for Host/Client"
		)

		finish_failed()

		return


	if not NetworkManager.is_online():
		return


	var peer_id: int = (
		multiplayer.get_unique_id()
	)


	if NetworkManager.is_host():

		pass_step(
			2,
			"Network ready",
			"HOST | Peer "
			+ str(
				peer_id
			)
		)


		phase_timer = 0.0

		phase = Phase.HOST_WAIT_CLIENT

		return


	if NetworkManager.is_client():

		pass_step(
			2,
			"Network ready",
			"CLIENT | Peer "
			+ str(
				peer_id
			)
		)


		phase_timer = 0.0

		phase = Phase.CLIENT_WAIT_COMMAND


# =========================================================
# HOST — WAIT CLIENT
# =========================================================

func process_host_wait_client(
	delta: float
):

	phase_timer += delta


	if phase_timer > network_timeout:

		fail_step(
			3,
			"Remote Client",
			"Timed out waiting for Client"
		)

		finish_failed()

		return


	var peers: PackedInt32Array = (
		multiplayer.get_peers()
	)


	if peers.is_empty():
		return


	remote_peer_id = int(
		peers[0]
	)


	original_remote_peer_id = (
		remote_peer_id
	)


	host_stage_index = 0


	start_host_stage()


# =========================================================
# HOST — START STAGE
# =========================================================

func start_host_stage():

	if host_stage_index >= stages.size():

		begin_primary_complete()

		return


	var stage: Dictionary = (
		stages[
			host_stage_index
		]
	)


	apply_host_power_configuration(
		bool(
			stage[
				"reactor"
			]
		),
		bool(
			stage[
				"oxygen"
			]
		),
		bool(
			stage[
				"pump"
			]
		),
		bool(
			stage[
				"pressure"
			]
		)
	)


	host_stage_result_received = false
	host_stage_result_success = false

	host_stage_result_key = str(
		stage[
			"key"
		]
	)


	qa_expect_power_state.rpc_id(
		remote_peer_id,
		int(
			stage[
				"step"
			]
		),
		str(
			stage[
				"key"
			]
		),
		bool(
			stage[
				"reactor"
			]
		),
		float(
			stage[
				"demand"
			]
		),
		bool(
			stage[
				"has_power"
			]
		),
		bool(
			stage[
				"output_zero"
			]
		)
	)


	phase_timer = 0.0

	phase = Phase.HOST_WAIT_STAGE_RESULT


# =========================================================
# HOST — APPLY CONFIG
# =========================================================

func apply_host_power_configuration(
	reactor_value: bool,
	oxygen_value: bool,
	pump_value: bool,
	pressure_value: bool
):

	if not NetworkManager.is_host():
		return


	reactor.set_reactor_on(
		reactor_value
	)


	oxygen_generator.set_generator_on(
		oxygen_value
	)


	pump_right.set_pump_on(
		pump_value
	)


	pressure_regulator.set_regulator_on(
		pressure_value
	)


	broadcast_machine_state(
		reactor
	)


	broadcast_machine_state(
		oxygen_generator
	)


	broadcast_machine_state(
		pump_right
	)


	broadcast_machine_state(
		pressure_regulator
	)


# =========================================================
# BROADCAST MACHINE STATE
# =========================================================

func broadcast_machine_state(
	machine
):

	if machine == null:
		return


	var component = (
		machine.get_node_or_null(
			"NetworkInteractable"
		)
	)


	if component == null:
		return


	if not component.has_method(
		"broadcast_state"
	):
		return


	component.broadcast_state()


# =========================================================
# HOST — WAIT STAGE
# =========================================================

func process_host_wait_stage_result(
	delta: float
):

	phase_timer += delta


	if phase_timer > stage_timeout:

		var stage: Dictionary = (
			stages[
				host_stage_index
			]
		)


		fail_step(
			int(
				stage[
					"step"
				]
			),
			str(
				stage[
					"title"
				]
			),
			"Timed out waiting for Client replication"
		)

		finish_failed()

		return


	if not host_stage_result_received:
		return


	var stage: Dictionary = (
		stages[
			host_stage_index
		]
	)


	if not host_stage_result_success:

		fail_step(
			int(
				stage[
					"step"
				]
			),
			str(
				stage[
					"title"
				]
			),
			"Client reported incorrect power state"
		)

		finish_failed()

		return


	if not state_matches(
		bool(
			stage[
				"reactor"
			]
		),
		float(
			stage[
				"demand"
			]
		),
		bool(
			stage[
				"has_power"
			]
		),
		bool(
			stage[
				"output_zero"
			]
		)
	):

		fail_step(
			int(
				stage[
					"step"
				]
			),
			str(
				stage[
					"title"
				]
			),
			"Host state does not match expected values"
		)

		finish_failed()

		return


	pass_step(
		int(
			stage[
				"step"
			]
		),
		str(
			stage[
				"title"
			]
		),
		describe_power_state()
	)


	# -----------------------------------------------------
	# Después de Step 08 probamos que el Client no pueda
	# modificar PowerSystem autoritativo directamente.
	# -----------------------------------------------------

	if int(
		stage[
			"step"
		]
	) == 8:

		qa_test_client_local_mutation.rpc_id(
			remote_peer_id
		)


		host_mutation_result_received = false
		host_mutation_result_success = false

		phase_timer = 0.0

		phase = Phase.HOST_WAIT_MUTATION_RESULT

		return


	host_stage_index += 1


	start_host_stage()


# =========================================================
# HOST — MUTATION RESULT
# =========================================================

func process_host_wait_mutation_result(
	delta: float
):

	phase_timer += delta


	if phase_timer > stage_timeout:

		fail_step(
			9,
			"Client authority rejection",
			"Timed out waiting for Client mutation result"
		)

		finish_failed()

		return


	if not host_mutation_result_received:
		return


	if not host_mutation_result_success:

		fail_step(
			9,
			"Client authority rejection",
			"Client modified authoritative PowerSystem locally"
		)

		finish_failed()

		return


	if not state_matches(
		true,
		70.0,
		true,
		false
	):

		fail_step(
			9,
			"Client authority rejection",
			"Host state changed during Client mutation attempt"
		)

		finish_failed()

		return


	pass_step(
		9,
		"Client authority rejection",
		"Direct Client mutation was blocked"
	)


	host_stage_index += 1


	start_host_stage()


# =========================================================
# PRIMARY COMPLETE
# =========================================================

func begin_primary_complete():

	qa_primary_complete.rpc_id(
		remote_peer_id
	)


	print_summary(
		"HOST PRIMARY"
	)


	print("")
	print("[QA] PRIMARY POWER TEST PASSED")
	print("[QA] Disconnect ONLY the Client.")
	print("[QA] Then reconnect it to the same Host.")
	print("")


	phase_timer = 0.0

	phase = Phase.HOST_WAIT_DISCONNECT


# =========================================================
# HOST — WAIT DISCONNECT
# =========================================================

func process_host_wait_disconnect(
	delta: float
):

	phase_timer += delta


	if phase_timer > network_timeout:

		fail_step(
			12,
			"Late join power snapshot",
			"Timed out waiting for Client disconnect"
		)

		finish_failed()

		return


	var peers: PackedInt32Array = (
		multiplayer.get_peers()
	)


	if not peers.is_empty():
		return


	saw_primary_disconnect = true


	print(
		"[QA] Host detected Client disconnect."
	)


	phase_timer = 0.0

	phase = Phase.HOST_WAIT_RECONNECT


# =========================================================
# HOST — WAIT RECONNECT
# =========================================================

func process_host_wait_reconnect(
	delta: float
):

	phase_timer += delta


	if phase_timer > network_timeout:

		fail_step(
			12,
			"Late join power snapshot",
			"Timed out waiting for Client reconnect"
		)

		finish_failed()

		return


	var peers: PackedInt32Array = (
		multiplayer.get_peers()
	)


	if peers.is_empty():
		return


	late_join_peer_id = int(
		peers[0]
	)


	if (
		late_join_peer_id
		== original_remote_peer_id
	):

		return


	print(
		"[QA] Host detected new Client Peer ",
		late_join_peer_id
	)


	host_late_join_result_received = false
	host_late_join_result_success = false


	phase_timer = 0.0

	phase = Phase.HOST_WAIT_LATE_JOIN_RESULT


# =========================================================
# HOST — LATE JOIN RESULT
# =========================================================

func process_host_wait_late_join_result(
	delta: float
):

	phase_timer += delta


	if phase_timer > stage_timeout:

		fail_step(
			12,
			"Late join power snapshot",
			"Timed out waiting for Client snapshot validation"
		)

		finish_failed()

		return


	if not host_late_join_result_received:
		return


	if not host_late_join_result_success:

		fail_step(
			12,
			"Late join power snapshot",
			"Client did not restore authoritative power state"
		)

		finish_failed()

		return


	if not state_matches(
		true,
		70.0,
		true,
		false
	):

		fail_step(
			12,
			"Late join power snapshot",
			"Host final power state changed unexpectedly"
		)

		finish_failed()

		return


	pass_step(
		12,
		"Late join power snapshot",
		"New Peer "
		+ str(
			late_join_peer_id
		)
		+ " restored Reactor ON / Demand 70"
	)


	print_summary(
		"HOST + TRUE LATE JOIN"
	)


	restore_creature()


	phase = Phase.COMPLETE


# =========================================================
# HOST -> CLIENT EXPECTATION
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_expect_power_state(
	step_number: int,
	stage_key: String,
	expected_reactor: bool,
	expected_demand: float,
	expected_has_power: bool,
	expected_output_zero: bool
):

	if not NetworkManager.is_client():
		return


	client_expected_step = step_number
	client_expected_key = stage_key

	client_expected_reactor = (
		expected_reactor
	)

	client_expected_demand = (
		expected_demand
	)

	client_expected_has_power = (
		expected_has_power
	)

	client_expected_output_zero = (
		expected_output_zero
	)


	client_expected_active = true

	phase_timer = 0.0

	phase = Phase.CLIENT_WAIT_EXPECTED_STATE


# =========================================================
# CLIENT — WAIT EXPECTED STATE
# =========================================================

func process_client_wait_expected_state(
	delta: float
):

	if not client_expected_active:
		return


	phase_timer += delta


	if phase_timer > stage_timeout:

		fail_step(
			client_expected_step,
			"Power replication",
			"Timed out waiting for "
			+ client_expected_key
		)

		qa_report_stage_result.rpc_id(
			1,
			client_expected_key,
			false
		)


		finish_failed()

		return


	if not state_matches(
		client_expected_reactor,
		client_expected_demand,
		client_expected_has_power,
		client_expected_output_zero
	):

		return


	pass_step(
		client_expected_step,
		"Power replication",
		client_expected_key
		+ " | "
		+ describe_power_state()
	)


	qa_report_stage_result.rpc_id(
		1,
		client_expected_key,
		true
	)


	client_expected_active = false


	phase = Phase.CLIENT_WAIT_COMMAND


# =========================================================
# CLIENT -> HOST STAGE RESULT
# =========================================================

@rpc(
	"any_peer",
	"call_remote",
	"reliable"
)
func qa_report_stage_result(
	stage_key: String,
	success: bool
):

	if not NetworkManager.is_host():
		return


	var sender: int = (
		multiplayer.get_remote_sender_id()
	)


	if sender != remote_peer_id:
		return


	if stage_key != host_stage_result_key:
		return


	host_stage_result_received = true

	host_stage_result_success = success


# =========================================================
# HOST -> CLIENT MUTATION TEST
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_test_client_local_mutation():

	if not NetworkManager.is_client():
		return


	var previous_reactor: bool = bool(
		power_system.reactor_on
	)


	var previous_efficiency: float = float(
		power_system.reactor_efficiency
	)


	var fake_key: StringName = (
		&"QA_FAKE_POWER"
	)


	var had_fake_before: bool = (
		power_system.consumers.has(
			fake_key
		)
		or power_system.consumers.has(
			"QA_FAKE_POWER"
		)
	)


	# -----------------------------------------------------
	# Estas llamadas DEBEN ser ignoradas por un Client.
	# -----------------------------------------------------

	power_system.set_reactor_state(
		false
	)


	power_system.set_reactor_efficiency(
		0.10
	)


	power_system.set_consumer_demand(
		fake_key,
		999.0
	)


	var has_fake_after: bool = (
		power_system.consumers.has(
			fake_key
		)
		or power_system.consumers.has(
			"QA_FAKE_POWER"
		)
	)


	var blocked: bool = (
		bool(
			power_system.reactor_on
		)
		== previous_reactor
		and is_equal_approx(
			float(
				power_system.reactor_efficiency
			),
			previous_efficiency
		)
		and has_fake_after
			== had_fake_before
	)


	if blocked:

		pass_step(
			9,
			"Client authority rejection",
			"Local setters did not modify raw power state"
		)

	else:

		fail_step(
			9,
			"Client authority rejection",
			"Client altered raw PowerSystem state"
		)


	qa_report_mutation_result.rpc_id(
		1,
		blocked
	)


# =========================================================
# CLIENT -> HOST MUTATION RESULT
# =========================================================

@rpc(
	"any_peer",
	"call_remote",
	"reliable"
)
func qa_report_mutation_result(
	success: bool
):

	if not NetworkManager.is_host():
		return


	var sender: int = (
		multiplayer.get_remote_sender_id()
	)


	if sender != remote_peer_id:
		return


	host_mutation_result_received = true

	host_mutation_result_success = success


# =========================================================
# HOST -> CLIENT PRIMARY COMPLETE
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_primary_complete():

	if not NetworkManager.is_client():
		return


	primary_complete = true


	print_summary(
		"CLIENT PRIMARY"
	)


	print("")
	print("[QA] PRIMARY POWER TEST PASSED")
	print("[QA] Disconnect ONLY this Client.")
	print("[QA] Reconnect it to the same Host.")
	print("")


	phase = Phase.CLIENT_WAIT_DISCONNECT


# =========================================================
# CLIENT — POISON BEFORE TRUE LATE JOIN
# =========================================================

func poison_client_power_state():

	if power_system == null:
		return


	client_poisoned = true


	# -----------------------------------------------------
	# Corrupción deliberada.
	#
	# No usamos setters porque offline los setters volverían
	# a ser válidos. Queremos demostrar que el snapshot
	# posterior reemplaza una copia local incorrecta.
	# -----------------------------------------------------

	power_system.reactor_on = false

	power_system.reactor_efficiency = 0.25


	power_system.consumers = {
		&"QA_FAKE_POWER": 999.0
	}


	power_system.network_state_received = true

	power_system.network_total_demand = 999.0

	power_system.network_available_output = 0.0

	power_system.network_power_balance = -999.0

	power_system.network_has_power = false


	print(
		"[QA] Client deliberately poisoned | Reactor=false | Demand=999"
	)


# =========================================================
# CLIENT — LATE JOIN
# =========================================================

func process_client_wait_late_join_state(
	delta: float
):

	phase_timer += delta


	if phase_timer > network_timeout:

		fail_step(
			12,
			"Late join power snapshot",
			"Timed out waiting for authoritative snapshot"
		)

		qa_report_late_join_result.rpc_id(
			1,
			false
		)


		finish_failed()

		return


	if not power_system.network_state_received:
		return


	if power_system.consumers.has(
		&"QA_FAKE_POWER"
	):
		return


	if power_system.consumers.has(
		"QA_FAKE_POWER"
	):
		return


	if not state_matches(
		true,
		70.0,
		true,
		false
	):

		return


	pass_step(
		12,
		"Late join power snapshot",
		"Poisoned Client restored to Reactor ON / Demand 70"
	)


	qa_report_late_join_result.rpc_id(
		1,
		true
	)


	print_summary(
		"CLIENT + TRUE LATE JOIN"
	)


	restore_creature()


	phase = Phase.COMPLETE


# =========================================================
# CLIENT -> HOST LATE JOIN RESULT
# =========================================================

@rpc(
	"any_peer",
	"call_remote",
	"reliable"
)
func qa_report_late_join_result(
	success: bool
):

	if not NetworkManager.is_host():
		return


	var sender: int = (
		multiplayer.get_remote_sender_id()
	)


	if (
		late_join_peer_id != 0
		and sender != late_join_peer_id
	):
		return


	host_late_join_result_received = true

	host_late_join_result_success = success


# =========================================================
# STATE MATCH
# =========================================================

func state_matches(
	expected_reactor: bool,
	expected_demand: float,
	expected_has_power: bool,
	expected_output_zero: bool
) -> bool:

	if power_system == null:
		return false


	if (
		power_system.is_reactor_on()
		!= expected_reactor
	):

		return false


	var current_demand: float = (
		power_system.get_total_demand()
	)


	if abs(
		current_demand
		- expected_demand
	) > state_tolerance:

		return false


	if (
		power_system.has_power()
		!= expected_has_power
	):

		return false


	var available_output: float = (
		power_system.get_available_output()
	)


	if expected_output_zero:

		if abs(
			available_output
		) > state_tolerance:

			return false

	else:

		if available_output <= 0.0:
			return false


	return true


# =========================================================
# DESCRIPTION
# =========================================================

func describe_power_state() -> String:

	if power_system == null:
		return "PowerSystem NULL"


	return (
		"Reactor="
		+ str(
			power_system.is_reactor_on()
		)
		+ " | Demand="
		+ str(
			snapped(
				power_system.get_total_demand(),
				0.1
			)
		)
		+ " | Available="
		+ str(
			snapped(
				power_system.get_available_output(),
				0.1
			)
		)
		+ " | Balance="
		+ str(
			snapped(
				power_system.get_power_balance(),
				0.1
			)
		)
		+ " | HasPower="
		+ str(
			power_system.has_power()
		)
	)


# =========================================================
# ENVIRONMENT GUARD
# =========================================================

func process_environment_guard(
	delta: float
):

	if not NetworkManager.is_online():
		return


	if not NetworkManager.is_host():
		return


	guard_accumulator += delta


	if (
		guard_accumulator
		< environment_guard_interval
	):

		return


	guard_accumulator = 0.0


	stabilize_room(
		room_left
	)


	stabilize_room(
		room_right
	)


# =========================================================
# STABILIZE ROOM
# =========================================================

func stabilize_room(
	room
):

	if room == null:
		return


	if room.has_method(
		"set_water_level"
	):

		room.set_water_level(
			0.0
		)


	if room.has_method(
		"set_oxygen_level"
	):

		room.set_oxygen_level(
			1.0
		)


	if room.has_method(
		"set_pressure"
	):

		room.set_pressure(
			1.0
		)


# =========================================================
# CREATURE ISOLATION
# =========================================================

func isolate_creature():

	if sea_creature == null:
		return


	if not is_instance_valid(
		sea_creature
	):
		return


	var current_value = (
		sea_creature.get(
			"attack_submarine_enabled"
		)
	)


	if current_value == null:
		return


	previous_creature_hull_attack = bool(
		current_value
	)


	creature_setting_saved = true


	if sea_creature.has_method(
		"set_attack_submarine_enabled"
	):

		sea_creature.set_attack_submarine_enabled(
			false
		)

	else:

		sea_creature.set(
			"attack_submarine_enabled",
			false
		)


	print(
		"[QA] Environment isolated for Power test"
	)


# =========================================================
# RESTORE CREATURE
# =========================================================

func restore_creature():

	if not creature_setting_saved:
		return


	if sea_creature == null:
		return


	if not is_instance_valid(
		sea_creature
	):
		return


	if sea_creature.has_method(
		"set_attack_submarine_enabled"
	):

		sea_creature.set_attack_submarine_enabled(
			previous_creature_hull_attack
		)

	else:

		sea_creature.set(
			"attack_submarine_enabled",
			previous_creature_hull_attack
		)


	creature_setting_saved = false


# =========================================================
# PASS
# =========================================================

func pass_step(
	step_number: int,
	title: String,
	detail: String
):

	pass_count += 1


	print(
		"[QA][STEP ",
		str(
			step_number
		).pad_zeros(
			2
		),
		"][PASS] ",
		title,
		" | ",
		detail
	)


# =========================================================
# FAIL
# =========================================================

func fail_step(
	step_number: int,
	title: String,
	detail: String
):

	fail_count += 1


	print(
		"[QA][STEP ",
		str(
			step_number
		).pad_zeros(
			2
		),
		"][FAIL] ",
		title,
		" | ",
		detail
	)


# =========================================================
# FAILED
# =========================================================

func finish_failed():

	restore_creature()


	print_summary(
		"FAILED"
	)


	phase = Phase.FAILED


# =========================================================
# SUMMARY
# =========================================================

func print_summary(
	context: String
):

	print(
		"[QA] ----------------------------------------"
	)

	print(
		"[QA] SUMMARY | ",
		context
	)

	print(
		"[QA] PASS: ",
		pass_count
	)

	print(
		"[QA] FAIL: ",
		fail_count
	)

	print(
		"[QA] SKIP: ",
		skip_count
	)


	if fail_count <= 0:

		print(
			"[QA] RESULT: TEST PASSED"
		)

	else:

		print(
			"[QA] RESULT: TEST FAILED"
		)


	print(
		"[QA] ========================================"
	)
