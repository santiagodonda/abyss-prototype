extends Node


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("Run")

@export var start_on_run: bool = false

@export_range(
	1,
	4,
	1
)
var required_clients: int = 1


@export_group("Timeouts")

@export_range(
	5.0,
	300.0,
	1.0
)
var client_connect_timeout: float = 120.0

@export_range(
	1.0,
	30.0,
	0.5
)
var action_timeout: float = 6.0

@export_range(
	5.0,
	120.0,
	1.0
)
var client_cross_timeout: float = 30.0

@export_range(
	0.05,
	1.0,
	0.05
)
var poll_interval: float = 0.10


@export_group("Host Automation")

@export var host_action_offset: Vector2 = Vector2(
	-80.0,
	0.0
)

@export var restore_host_position_on_finish: bool = true


# =========================================================
# NODE PATHS
# =========================================================

@export_group("References")

@export var host_player_path: NodePath = NodePath(
	"../Player"
)

@export var network_interaction_manager_path: NodePath = NodePath(
	"../NetworkInteractionManager"
)

@export var reactor_path: NodePath = NodePath(
	"../Reactor"
)

@export var oxygen_generator_path: NodePath = NodePath(
	"../OxygenGenerator"
)

@export var door_path: NodePath = NodePath(
	"../Door"
)

@export var pump_path: NodePath = NodePath(
	"../PumpRight"
)

@export var pressure_regulator_path: NodePath = NodePath(
	"../PressureRegulator"
)


# =========================================================
# REFERENCIAS RESUELTAS
# =========================================================

var host_player: Node2D = null

var network_interaction_manager: Node = null

var reactor: Node = null

var oxygen_generator: Node = null

var door: Node = null

var pump: Node = null

var pressure_regulator: Node = null


# =========================================================
# ESTADO QA
# =========================================================

var qa_running: bool = false

var qa_finished: bool = false

var pass_count: int = 0

var fail_count: int = 0

var step_number: int = 1

var host_start_position: Vector2 = Vector2.ZERO


# =========================================================
# READY
# =========================================================

func _ready():

	process_mode = Node.PROCESS_MODE_ALWAYS


	if start_on_run:

		print(
			"[COOP QA] ARMED | Waiting for HOST..."
		)


# =========================================================
# PROCESS
# =========================================================

func _process(
	_delta: float
):

	if not start_on_run:
		return


	if qa_running:
		return


	if qa_finished:
		return


	# -----------------------------------------------------
	# TODAVÍA OFFLINE
	# -----------------------------------------------------

	if not NetworkManager.is_online():
		return


	# -----------------------------------------------------
	# CLIENTE
	#
	# El QA sólo existe funcionalmente en el Host.
	# -----------------------------------------------------

	if not NetworkManager.is_host():

		qa_finished = true

		print(
			"[COOP QA][CLIENT] Inactive | Host-only QA"
		)

		return


	# -----------------------------------------------------
	# HOST
	# -----------------------------------------------------

	qa_running = true

	run_scenario()


# =========================================================
# ESCENARIO
# =========================================================

func run_scenario():

	print("")
	print(
		"========================================================="
	)
	print(
		"[COOP QA][START] B1.2 CORE COOP"
	)
	print(
		"========================================================="
	)


	# =====================================================
	# STEP 01 — REFERENCIAS
	# =====================================================

	if not resolve_references():

		fail_step(
			"Required references"
		)

		finish_qa(
			false
		)

		return


	host_start_position = (
		host_player.global_position
	)


	pass_step(
		"Required references"
	)


	# =====================================================
	# STEP 02 — ESPERAR CLIENTE
	# =====================================================

	print(
		"[COOP QA][WAIT] Android client connection"
	)


	var client_ready: bool = (
		await wait_for_clients(
			required_clients,
			client_connect_timeout
		)
	)


	if not client_ready:

		fail_step(
			"Android client connected"
		)

		finish_qa(
			false
		)

		return


	pass_step(
		"Android client connected"
	)


	var client_peer_id: int = (
		get_first_remote_peer_id()
	)


	if client_peer_id <= 1:

		fail_step(
			"Resolve Android peer"
		)

		finish_qa(
			false
		)

		return


	print(
		"[COOP QA] Client Peer = ",
		client_peer_id
	)


	# =====================================================
	# STEP 03 — REACTOR
	# =====================================================

	var reactor_ok: bool = (
		await ensure_device_on(
			reactor,
			"is_on"
		)
	)


	if not reactor_ok:

		fail_step(
			"Host Reactor ON"
		)

		finish_qa(
			false
		)

		return


	pass_step(
		"Host Reactor ON"
	)


	# =====================================================
	# STEP 04 — OXYGEN GENERATOR
	# =====================================================

	var oxygen_ok: bool = (
		await ensure_device_on(
			oxygen_generator,
			"is_on"
		)
	)


	if not oxygen_ok:

		fail_step(
			"Host OxygenGenerator ON"
		)

		finish_qa(
			false
		)

		return


	pass_step(
		"Host OxygenGenerator ON"
	)


	# =====================================================
	# STEP 05 — DOOR OPEN
	# =====================================================

	var door_ok: bool = (
		await ensure_device_on(
			door,
			"is_open"
		)
	)


	if not door_ok:

		fail_step(
			"Host Door OPEN"
		)

		finish_qa(
			false
		)

		return


	pass_step(
		"Host Door OPEN"
	)


	# =====================================================
	# STEP 06 — CLIENT CRUZA DOOR
	# =====================================================

	print("")
	print(
		"[COOP QA][ACTION REQUIRED]"
	)
	print(
		"[COOP QA] ANDROID: cruzá la Door al otro Room."
	)
	print(
		"[COOP QA] El Host espera automáticamente."
	)
	print("")


	var crossed: bool = (
		await wait_for_client_door_cross(
			client_peer_id,
			client_cross_timeout
		)
	)


	if not crossed:

		fail_step(
			"Android crossed Door"
		)

		finish_qa(
			false
		)

		return


	pass_step(
		"Android crossed Door"
	)


	# =====================================================
	# STEP 07 — PUMP
	# =====================================================

	var pump_ok: bool = (
		await ensure_device_on(
			pump,
			"is_on"
		)
	)


	if not pump_ok:

		fail_step(
			"Host PumpRight ON"
		)

		finish_qa(
			false
		)

		return


	pass_step(
		"Host PumpRight ON"
	)


	# =====================================================
	# STEP 08 — PRESSURE REGULATOR
	# =====================================================

	var pressure_ok: bool = (
		await ensure_device_on(
			pressure_regulator,
			"is_on"
		)
	)


	if not pressure_ok:

		fail_step(
			"Host PressureRegulator ON"
		)

		finish_qa(
			false
		)

		return


	pass_step(
		"Host PressureRegulator ON"
	)


	# =====================================================
	# FIN
	# =====================================================

	finish_qa(
		true
	)


# =========================================================
# RESOLVER REFERENCIAS
# =========================================================

func resolve_references() -> bool:

	host_player = (
		get_node_or_null(
			host_player_path
		) as Node2D
	)


	network_interaction_manager = (
		get_node_or_null(
			network_interaction_manager_path
		)
	)


	reactor = (
		get_node_or_null(
			reactor_path
		)
	)


	oxygen_generator = (
		get_node_or_null(
			oxygen_generator_path
		)
	)


	door = (
		get_node_or_null(
			door_path
		)
	)


	pump = (
		get_node_or_null(
			pump_path
		)
	)


	pressure_regulator = (
		get_node_or_null(
			pressure_regulator_path
		)
	)


	if host_player == null:

		print(
			"[COOP QA][ERROR] Player not found"
		)

		return false


	if network_interaction_manager == null:

		print(
			"[COOP QA][ERROR] NetworkInteractionManager not found"
		)

		return false


	if reactor == null:

		print(
			"[COOP QA][ERROR] Reactor not found"
		)

		return false


	if oxygen_generator == null:

		print(
			"[COOP QA][ERROR] OxygenGenerator not found"
		)

		return false


	if door == null:

		print(
			"[COOP QA][ERROR] Door not found"
		)

		return false


	if pump == null:

		print(
			"[COOP QA][ERROR] PumpRight not found"
		)

		return false


	if pressure_regulator == null:

		print(
			"[COOP QA][ERROR] PressureRegulator not found"
		)

		return false


	if not network_interaction_manager.has_method(
		"get_player_position"
	):

		print(
			"[COOP QA][ERROR] "
			+ "NetworkInteractionManager lacks "
			+ "get_player_position()"
		)

		return false


	return true


# =========================================================
# ESPERAR CLIENTES
# =========================================================

func wait_for_clients(
	amount: int,
	timeout: float
) -> bool:

	var elapsed: float = 0.0


	while elapsed < timeout:

		if not NetworkManager.is_online():
			return false


		if not NetworkManager.is_host():
			return false


		var peers = (
			multiplayer.get_peers()
		)


		if peers.size() >= amount:

			return true


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	return false


# =========================================================
# PRIMER CLIENT PEER
# =========================================================

func get_first_remote_peer_id() -> int:

	var peers = (
		multiplayer.get_peers()
	)


	if peers.is_empty():
		return 0


	return int(
		peers[0]
	)


# =========================================================
# ACTIVAR DISPOSITIVO
# =========================================================

func ensure_device_on(
	target: Node,
	property_name: String
) -> bool:

	if target == null:
		return false


	if bool(
		target.get(
			property_name
		)
	):

		return true


	if not target.has_method(
		"interact"
	):

		return false


	# -----------------------------------------------------
	# DOS INTENTOS MÁXIMO
	# -----------------------------------------------------

	for attempt in range(
		2
	):

		move_host_near(
			target
		)


		await get_tree().physics_frame
		await get_tree().physics_frame


		print(
			"[COOP QA][HOST ACTION] ",
			target.name,
			" | Attempt ",
			attempt + 1
		)


		target.call(
			"interact",
			host_player
		)


		var changed: bool = (
			await wait_for_bool_property(
				target,
				property_name,
				true,
				action_timeout
			)
		)


		if changed:
			return true


	return false


# =========================================================
# MOVER HOST A TARGET
# =========================================================

func move_host_near(
	target: Node
):

	if host_player == null:
		return


	if target == null:
		return


	if not target is Node2D:
		return


	var target_2d: Node2D = (
		target as Node2D
	)


	host_player.global_position = (
		target_2d.global_position
		+ host_action_offset
	)


	var body: CharacterBody2D = (
		host_player as CharacterBody2D
	)


	if body != null:

		body.velocity = Vector2.ZERO


# =========================================================
# ESPERAR PROPERTY BOOL
# =========================================================

func wait_for_bool_property(
	target: Node,
	property_name: String,
	expected_value: bool,
	timeout: float
) -> bool:

	var elapsed: float = 0.0


	while elapsed < timeout:

		if target == null:
			return false


		if not is_instance_valid(
			target
		):

			return false


		var current_value = (
			target.get(
				property_name
			)
		)


		if bool(
			current_value
		) == expected_value:

			return true


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	return false


# =========================================================
# CLIENT CRUZA DOOR
# =========================================================

func wait_for_client_door_cross(
	peer_id: int,
	timeout: float
) -> bool:

	if network_interaction_manager == null:
		return false


	if door == null:
		return false


	if not door is Node2D:
		return false


	var start_data = (
		network_interaction_manager.call(
			"get_player_position",
			peer_id
		)
	)


	if not start_data is Dictionary:

		print(
			"[COOP QA][ERROR] Invalid player position data"
		)

		return false


	if not bool(
		start_data.get(
			"valid",
			false
		)
	):

		print(
			"[COOP QA][ERROR] Client position unavailable"
		)

		return false


	var start_position: Vector2 = (
		start_data.get(
			"position",
			Vector2.ZERO
		)
	)


	var door_2d: Node2D = (
		door as Node2D
	)


	var door_x: float = (
		door_2d.global_position.x
	)


	var started_left: bool = (
		start_position.x
		< door_x
	)


	var margin: float = 70.0

	var elapsed: float = 0.0


	if started_left:

		print(
			"[COOP QA] Client starts LEFT | "
			+ "Cross to RIGHT"
		)

	else:

		print(
			"[COOP QA] Client starts RIGHT | "
			+ "Cross to LEFT"
		)


	while elapsed < timeout:

		var data = (
			network_interaction_manager.call(
				"get_player_position",
				peer_id
			)
		)


		if data is Dictionary:

			if bool(
				data.get(
					"valid",
					false
				)
			):

				var position: Vector2 = (
					data.get(
						"position",
						Vector2.ZERO
					)
				)


				if (
					started_left
					and position.x
					> door_x + margin
				):

					return true


				if (
					not started_left
					and position.x
					< door_x - margin
				):

					return true


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	return false


# =========================================================
# PASS
# =========================================================

func pass_step(
	description: String
):

	print(
		"[QA][STEP ",
		str(
			step_number
		).pad_zeros(
			2
		),
		"][PASS] ",
		description
	)


	pass_count += 1

	step_number += 1


# =========================================================
# FAIL
# =========================================================

func fail_step(
	description: String
):

	print(
		"[QA][STEP ",
		str(
			step_number
		).pad_zeros(
			2
		),
		"][FAIL] ",
		description
	)


	fail_count += 1

	step_number += 1


# =========================================================
# FINAL
# =========================================================

func finish_qa(
	success: bool
):

	if (
		restore_host_position_on_finish
		and host_player != null
		and is_instance_valid(
			host_player
		)
	):

		host_player.global_position = (
			host_start_position
		)


		var body: CharacterBody2D = (
			host_player as CharacterBody2D
		)


		if body != null:

			body.velocity = Vector2.ZERO


	print("")
	print(
		"========================================================="
	)
	print(
		"[COOP QA][RESULT]"
	)
	print(
		"PASS: ",
		pass_count
	)
	print(
		"FAIL: ",
		fail_count
	)


	if success and fail_count == 0:

		print(
			"B1.2 CORE COOP = TEST PASSED"
		)

	else:

		print(
			"B1.2 CORE COOP = TEST FAILED"
		)


	print(
		"========================================================="
	)
	print("")


	qa_running = false

	qa_finished = true
