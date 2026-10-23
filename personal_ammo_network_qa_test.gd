extends Node


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("QA")

@export var start_on_run: bool = false

@export var network_timeout: float = 60.0

@export var action_timeout: float = 10.0

@export var zero_rejection_wait: float = 1.0

@export var publish_interval: float = 0.10

@export var rack_position_offset: Vector2 = Vector2(
	-60.0,
	0.0
)


# =========================================================
# FASES
# =========================================================

enum TestPhase {
	IDLE,
	WAIT_NETWORK,

	HOST_WAIT_CLIENT,
	HOST_WAIT_CLIENT_CONTEXT,
	HOST_WAIT_PICKUP,
	HOST_WAIT_SHOT_1,
	HOST_WAIT_SHOT_2,
	HOST_WAIT_SHOT_3,
	HOST_WAIT_LOCAL_ZERO_RESULT,
	HOST_WAIT_BYPASS_REJECTION,
	HOST_PREPARE_OWN_FIRE,
	HOST_WAIT_OWN_FIRE,
	HOST_WAIT_LATE_JOIN,
	HOST_COMPLETE,

	CLIENT_WAIT_PREPARE,
	CLIENT_WAIT_PICKUP,
	CLIENT_WAIT_PICKUP_RESULT,
	CLIENT_WAIT_FIRE_PERMISSION,
	CLIENT_FIRE_1,
	CLIENT_WAIT_AMMO_2,
	CLIENT_FIRE_2,
	CLIENT_WAIT_AMMO_1,
	CLIENT_FIRE_3,
	CLIENT_WAIT_AMMO_0,
	CLIENT_WAIT_LOCAL_ZERO_TEST,
	CLIENT_WAIT_BYPASS_TEST,
	CLIENT_WAIT_BYPASS_RESULT,
	CLIENT_WAIT_HOST_COMPLETE,
	CLIENT_WAIT_DISCONNECT,
	CLIENT_LATE_JOIN_WAIT,
	CLIENT_COMPLETE,

	FAILED
}


var phase: TestPhase = TestPhase.IDLE


# =========================================================
# REFERENCIAS
# =========================================================

var network_combat_manager = null

var network_interaction_manager = null

var network_player_manager = null

var player = null

var inventory = null

var equipment = null

var weapon_system = null

var harpoon_ammo_rack = null

var hull_breach = null

var hull_integrity = null

var sea_creature = null


# =========================================================
# TIMERS
# =========================================================

var phase_timer: float = 0.0

var total_timer: float = 0.0

var publish_accumulator: float = 0.0


# =========================================================
# RESULTADOS
# =========================================================

var pass_count: int = 0

var fail_count: int = 0

var skip_count: int = 0


# =========================================================
# HOST
# =========================================================

var remote_peer_id: int = 0

var projectile_serial_baseline: int = 0

var zero_bypass_serial: int = 0

var host_weapon_prepared: bool = false

var host_fire_attempted: bool = false

var host_local_zero_result_received: bool = false

var host_local_zero_result: bool = false


# =========================================================
# CLIENT
# =========================================================

var client_prepare_allowed: bool = false

var client_pickup_allowed: bool = false

var client_fire_allowed: bool = false

var client_local_zero_allowed: bool = false

var client_bypass_allowed: bool = false

var client_bypass_done: bool = false

var client_host_test_complete: bool = false

var client_primary_complete: bool = false


# =========================================================
# LATE JOIN
# =========================================================

var was_online: bool = false

var has_been_online: bool = false

var expecting_late_join: bool = false


# =========================================================
# CREATURE
# =========================================================

var creature_setting_saved: bool = false

var previous_creature_hull_attack: bool = false


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


	print("")
	print(
		"[QA] ========================================"
	)

	print(
		"[QA] TEST: PERSONAL AMMO NETWORK AUTHORITY"
	)

	print(
		"[QA] ========================================"
	)


	resolve_references()


	if not validate_references():

		fail_step(
			1,
			"Required nodes",
			"Missing required references or API"
		)


		finish_failed()

		return


	pass_step(
		1,
		"Required nodes",
		"All references resolved"
	)


	isolate_environment()


	phase = TestPhase.WAIT_NETWORK

	phase_timer = 0.0

	total_timer = 0.0


# =========================================================
# RESET
# =========================================================

func reset_test_state():

	phase = TestPhase.IDLE


	phase_timer = 0.0

	total_timer = 0.0

	publish_accumulator = 0.0


	pass_count = 0

	fail_count = 0

	skip_count = 0


	remote_peer_id = 0

	projectile_serial_baseline = 0

	zero_bypass_serial = 0


	host_weapon_prepared = false

	host_fire_attempted = false

	host_local_zero_result_received = false

	host_local_zero_result = false


	client_prepare_allowed = false

	client_pickup_allowed = false

	client_fire_allowed = false

	client_local_zero_allowed = false

	client_bypass_allowed = false

	client_bypass_done = false

	client_host_test_complete = false

	client_primary_complete = false


	was_online = false

	has_been_online = false

	expecting_late_join = false


	creature_setting_saved = false

	previous_creature_hull_attack = false


# =========================================================
# REFERENCIAS
# =========================================================

func resolve_references():

	var scene = (
		get_tree().current_scene
	)


	if scene == null:
		return


	# =====================================================
	# NETWORK COMBAT MANAGER
	#
	# 1. Intentamos por nombre directo.
	# 2. Si la escena no lo expone con esa ruta,
	#    usamos el grupo que el propio manager registra.
	# =====================================================

	network_combat_manager = (
		scene.get_node_or_null(
			"NetworkCombatManager"
		)
	)


	if network_combat_manager == null:

		var combat_managers: Array = (
			get_tree().get_nodes_in_group(
				"network_combat_manager"
			)
		)


		if not combat_managers.is_empty():

			network_combat_manager = (
				combat_managers[0]
			)


	# =====================================================
	# RESTO DE REFERENCIAS
	# =====================================================

	network_interaction_manager = (
		scene.get_node_or_null(
			"NetworkInteractionManager"
		)
	)


	network_player_manager = (
		scene.get_node_or_null(
			"NetworkPlayerManager"
		)
	)


	player = (
		scene.get_node_or_null(
			"Player"
		)
	)


	harpoon_ammo_rack = (
		scene.get_node_or_null(
			"HarpoonAmmoRack"
		)
	)


	hull_breach = (
		scene.get_node_or_null(
			"HullBreach"
		)
	)


	hull_integrity = (
		scene.get_node_or_null(
			"HullIntegrityPoint"
		)
	)


	sea_creature = (
		scene.get_node_or_null(
			"SeaCreature"
		)
	)


	if player != null:

		inventory = (
			player.get_node_or_null(
				"Inventory"
			)
		)


		equipment = (
			player.get_node_or_null(
				"Equipment"
			)
		)


		weapon_system = (
			player.get_node_or_null(
				"WeaponSystem"
			)
		)

# =========================================================
# VALIDACIÓN
# =========================================================

func validate_references() -> bool:

	if network_combat_manager == null:
		return false


	if network_interaction_manager == null:
		return false


	if player == null:
		return false


	if inventory == null:
		return false


	if equipment == null:
		return false


	if weapon_system == null:
		return false


	if harpoon_ammo_rack == null:
		return false


	if not network_combat_manager.has_method(
		"set_peer_harpoon_ammo"
	):
		return false


	if not network_combat_manager.has_method(
		"get_peer_harpoon_ammo"
	):
		return false


	if not network_combat_manager.has_method(
		"get_local_authoritative_harpoon_ammo"
	):
		return false


	if not network_combat_manager.has_method(
		"request_player_fire"
	):
		return false


	if not network_interaction_manager.has_method(
		"get_player_position"
	):
		return false


	if not network_interaction_manager.has_method(
		"get_player_tool_id"
	):
		return false


	if not inventory.has_method(
		"add_item"
	):
		return false


	if not inventory.has_method(
		"remove_item"
	):
		return false


	if not inventory.has_method(
		"get_item_quantity"
	):
		return false


	if not equipment.has_method(
		"equip_item"
	):
		return false


	if not weapon_system.has_method(
		"fire_at"
	):
		return false


	if not harpoon_ammo_rack.has_method(
		"interact"
	):
		return false


	return true


# =========================================================
# PROCESS
# =========================================================

func _process(
	delta: float
):

	if phase == TestPhase.IDLE:
		return


	if phase == TestPhase.FAILED:
		return


	process_network_transition()


	match phase:

		TestPhase.WAIT_NETWORK:

			process_wait_network(
				delta
			)


		TestPhase.HOST_WAIT_CLIENT:

			process_host_wait_client(
				delta
			)


		TestPhase.HOST_WAIT_CLIENT_CONTEXT:

			process_host_wait_client_context(
				delta
			)


		TestPhase.HOST_WAIT_PICKUP:

			process_host_wait_pickup(
				delta
			)


		TestPhase.HOST_WAIT_SHOT_1:

			process_host_wait_shot(
				delta,
				2,
				7,
				TestPhase.HOST_WAIT_SHOT_2
			)


		TestPhase.HOST_WAIT_SHOT_2:

			process_host_wait_shot(
				delta,
				1,
				8,
				TestPhase.HOST_WAIT_SHOT_3
			)


		TestPhase.HOST_WAIT_SHOT_3:

			process_host_wait_third_shot(
				delta
			)


		TestPhase.HOST_WAIT_LOCAL_ZERO_RESULT:

			process_host_wait_local_zero_result(
				delta
			)


		TestPhase.HOST_WAIT_BYPASS_REJECTION:

			process_host_wait_bypass_rejection(
				delta
			)


		TestPhase.HOST_PREPARE_OWN_FIRE:

			process_host_prepare_own_fire(
				delta
			)


		TestPhase.HOST_WAIT_OWN_FIRE:

			process_host_wait_own_fire(
				delta
			)


		TestPhase.CLIENT_WAIT_PREPARE:

			process_client_wait_prepare(
				delta
			)


		TestPhase.CLIENT_WAIT_PICKUP:

			process_client_wait_pickup(
				delta
			)


		TestPhase.CLIENT_WAIT_PICKUP_RESULT:

			process_client_wait_pickup_result(
				delta
			)


		TestPhase.CLIENT_WAIT_FIRE_PERMISSION:

			process_client_wait_fire_permission(
				delta
			)


		TestPhase.CLIENT_FIRE_1:

			process_client_fire(
				delta,
				TestPhase.CLIENT_WAIT_AMMO_2
			)


		TestPhase.CLIENT_WAIT_AMMO_2:

			process_client_wait_ammo(
				delta,
				2,
				7,
				TestPhase.CLIENT_FIRE_2
			)


		TestPhase.CLIENT_FIRE_2:

			process_client_fire(
				delta,
				TestPhase.CLIENT_WAIT_AMMO_1
			)


		TestPhase.CLIENT_WAIT_AMMO_1:

			process_client_wait_ammo(
				delta,
				1,
				8,
				TestPhase.CLIENT_FIRE_3
			)


		TestPhase.CLIENT_FIRE_3:

			process_client_fire(
				delta,
				TestPhase.CLIENT_WAIT_AMMO_0
			)


		TestPhase.CLIENT_WAIT_AMMO_0:

			process_client_wait_zero(
				delta
			)


		TestPhase.CLIENT_WAIT_LOCAL_ZERO_TEST:

			process_client_local_zero_test(
				delta
			)


		TestPhase.CLIENT_WAIT_BYPASS_TEST:

			process_client_bypass_test(
				delta
			)


		TestPhase.CLIENT_WAIT_BYPASS_RESULT:

			process_client_wait_bypass_result(
				delta
			)


		TestPhase.CLIENT_WAIT_HOST_COMPLETE:

			process_client_wait_host_complete(
				delta
			)


		TestPhase.CLIENT_LATE_JOIN_WAIT:

			process_client_late_join(
				delta
			)


# =========================================================
# NETWORK TRANSITION
# =========================================================

func process_network_transition():

	var online_now: bool = (
		NetworkManager.is_online()
	)


	if (
		was_online
		and not online_now
		and has_been_online
		and client_primary_complete
		and not expecting_late_join
	):

		prepare_true_late_join()


	if online_now:

		has_been_online = true


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
			"Timed out waiting for multiplayer"
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

		phase = TestPhase.HOST_WAIT_CLIENT

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

		phase = TestPhase.CLIENT_WAIT_PREPARE


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


	# -----------------------------------------------------
	# Base controlada:
	#
	# Host   = 2
	# Client = 0
	# -----------------------------------------------------

	network_combat_manager.set_peer_harpoon_ammo(
		1,
		2
	)


	network_combat_manager.set_peer_harpoon_ammo(
		remote_peer_id,
		0
	)


	pass_step(
		3,
		"Peer ammo initialization",
		"Host=2 | Client=0 | Peer "
		+ str(
			remote_peer_id
		)
	)


	qa_prepare_client.rpc_id(
		remote_peer_id
	)


	phase_timer = 0.0

	phase = TestPhase.HOST_WAIT_CLIENT_CONTEXT


# =========================================================
# HOST — CLIENT POSITION + TOOL
# =========================================================

func process_host_wait_client_context(
	delta: float
):

	phase_timer += delta


	if phase_timer > network_timeout:

		fail_step(
			4,
			"Client authoritative context",
			"Host did not receive valid position/tool"
		)


		finish_failed()

		return


	var position_data = (
		network_interaction_manager.get_player_position(
			remote_peer_id
		)
	)


	if not (
		position_data is Dictionary
	):
		return


	if not bool(
		position_data.get(
			"valid",
			false
		)
	):
		return


	var position_value = (
		position_data.get(
			"position",
			null
		)
	)


	if not (
		position_value is Vector2
	):
		return


	var remote_position: Vector2 = (
		position_value
	)


	var tool_id: String = str(
		network_interaction_manager.get_player_tool_id(
			remote_peer_id
		)
	)


	var distance: float = (
		remote_position.distance_to(
			harpoon_ammo_rack.global_position
		)
	)


	if distance > 120.0:
		return


	if tool_id != "harpoon_gun":
		return


	pass_step(
		4,
		"Client authoritative context",
		"Distance="
		+ str(
			snapped(
				distance,
				0.1
			)
		)
		+ " | Tool=harpoon_gun"
	)


	qa_allow_client_pickup.rpc_id(
		remote_peer_id
	)


	phase_timer = 0.0

	phase = TestPhase.HOST_WAIT_PICKUP


# =========================================================
# HOST — PICKUP
# =========================================================

func process_host_wait_pickup(
	delta: float
):

	phase_timer += delta


	if phase_timer > action_timeout:

		fail_step(
			5,
			"Authoritative ammo pickup",
			"Timed out waiting for 0 -> 6"
		)


		finish_failed()

		return


	var client_ammo: int = (
		network_combat_manager.get_peer_harpoon_ammo(
			remote_peer_id
		)
	)


	if client_ammo != 6:
		return


	if network_combat_manager.get_peer_harpoon_ammo(
		1
	) != 2:

		fail_step(
			5,
			"Authoritative ammo pickup",
			"Client pickup modified Host ammo"
		)


		finish_failed()

		return


	pass_step(
		5,
		"Authoritative ammo pickup",
		"Client 0 -> 6 | Host remained 2"
	)


	# -----------------------------------------------------
	# Para que la prueba de agotamiento sea corta:
	# normalizamos Client a 3.
	# -----------------------------------------------------

	network_combat_manager.set_peer_harpoon_ammo(
		remote_peer_id,
		3
	)


	projectile_serial_baseline = int(
		network_combat_manager.next_projectile_serial
	)


	pass_step(
		6,
		"Controlled fire state",
		"Host=2 | Client=3"
	)


	qa_begin_client_fire.rpc_id(
		remote_peer_id
	)


	phase_timer = 0.0

	phase = TestPhase.HOST_WAIT_SHOT_1


# =========================================================
# HOST — SHOT 1 / SHOT 2
# =========================================================

func process_host_wait_shot(
	delta: float,
	expected_ammo: int,
	step_number: int,
	next_phase: TestPhase
):

	phase_timer += delta


	if phase_timer > action_timeout:

		fail_step(
			step_number,
			"Authoritative Client fire",
			"Timed out waiting for ammo "
			+ str(
				expected_ammo
			)
		)


		finish_failed()

		return


	var client_ammo: int = (
		network_combat_manager.get_peer_harpoon_ammo(
			remote_peer_id
		)
	)


	if client_ammo != expected_ammo:
		return


	var current_serial: int = int(
		network_combat_manager.next_projectile_serial
	)


	if current_serial <= projectile_serial_baseline:
		return


	if network_combat_manager.get_peer_harpoon_ammo(
		1
	) != 2:

		fail_step(
			step_number,
			"Ammo isolation",
			"Client shot modified Host ammo"
		)


		finish_failed()

		return


	projectile_serial_baseline = current_serial


	pass_step(
		step_number,
		"Authoritative Client fire",
		"Client ammo="
		+ str(
			expected_ammo
		)
		+ " | Host ammo=2"
	)


	phase_timer = 0.0

	phase = next_phase


# =========================================================
# HOST — THIRD SHOT
# =========================================================

func process_host_wait_third_shot(
	delta: float
):

	phase_timer += delta


	if phase_timer > action_timeout:

		fail_step(
			9,
			"Client reaches zero",
			"Timed out waiting for ammo 0"
		)


		finish_failed()

		return


	if network_combat_manager.get_peer_harpoon_ammo(
		remote_peer_id
	) != 0:

		return


	var current_serial: int = int(
		network_combat_manager.next_projectile_serial
	)


	if current_serial <= projectile_serial_baseline:
		return


	if network_combat_manager.get_peer_harpoon_ammo(
		1
	) != 2:

		fail_step(
			9,
			"Ammo isolation",
			"Host ammo changed during Client firing"
		)


		finish_failed()

		return


	projectile_serial_baseline = current_serial


	pass_step(
		9,
		"Client reaches zero",
		"Client=0 | Host=2"
	)


	qa_test_client_local_zero.rpc_id(
		remote_peer_id
	)


	phase_timer = 0.0

	phase = TestPhase.HOST_WAIT_LOCAL_ZERO_RESULT


# =========================================================
# HOST — LOCAL ZERO RESULT
# =========================================================

func process_host_wait_local_zero_result(
	delta: float
):

	phase_timer += delta


	if phase_timer > action_timeout:

		fail_step(
			10,
			"Local zero-ammo block",
			"Client did not report result"
		)


		finish_failed()

		return


	if not host_local_zero_result_received:
		return


	if not host_local_zero_result:

		fail_step(
			10,
			"Local zero-ammo block",
			"WeaponSystem allowed FIRE with ammo 0"
		)


		finish_failed()

		return


	pass_step(
		10,
		"Local zero-ammo block",
		"WeaponSystem rejected FIRE at ammo 0"
	)


	zero_bypass_serial = int(
		network_combat_manager.next_projectile_serial
	)


	qa_test_host_zero_bypass.rpc_id(
		remote_peer_id
	)


	phase_timer = 0.0

	phase = TestPhase.HOST_WAIT_BYPASS_REJECTION


# =========================================================
# HOST — MALICIOUS/BYPASS ZERO REQUEST
# =========================================================

func process_host_wait_bypass_rejection(
	delta: float
):

	phase_timer += delta


	if phase_timer < zero_rejection_wait:
		return


	var current_serial: int = int(
		network_combat_manager.next_projectile_serial
	)


	if current_serial != zero_bypass_serial:

		fail_step(
			11,
			"Host zero-ammo authority",
			"Projectile created despite authoritative ammo 0"
		)


		finish_failed()

		return


	if network_combat_manager.get_peer_harpoon_ammo(
		remote_peer_id
	) != 0:

		fail_step(
			11,
			"Host zero-ammo authority",
			"Client ammo changed unexpectedly"
		)


		finish_failed()

		return


	pass_step(
		11,
		"Host zero-ammo authority",
		"Bypass request created no projectile"
	)


	qa_zero_bypass_done.rpc_id(
		remote_peer_id
	)


	phase_timer = 0.0

	phase = TestPhase.HOST_PREPARE_OWN_FIRE


# =========================================================
# HOST — PREPARE OWN WEAPON
# =========================================================

func process_host_prepare_own_fire(
	delta: float
):

	phase_timer += delta


	if phase_timer > action_timeout:

		fail_step(
			12,
			"Host independent ammo",
			"Could not prepare Host weapon"
		)


		finish_failed()

		return


	if not host_weapon_prepared:

		host_weapon_prepared = true


		if not inventory.has_item(
			"harpoon_gun",
			1
		):

			inventory.add_item(
				"harpoon_gun",
				1
			)


		if not equipment.equip_item(
			"harpoon_gun"
		):

			fail_step(
				12,
				"Host independent ammo",
				"Could not equip harpoon_gun"
			)


			finish_failed()

			return


	var host_tool: String = str(
		network_interaction_manager.get_player_tool_id(
			1
		)
	)


	if host_tool != "harpoon_gun":
		return


	if weapon_system.get_cooldown_remaining() > 0.0:
		return


	if host_fire_attempted:
		return


	host_fire_attempted = true


	var target_position: Vector2 = (
		player.global_position
		+ Vector2(
			250.0,
			0.0
		)
	)


	var fired: bool = bool(
		weapon_system.fire_at(
			target_position
		)
	)


	if not fired:

		fail_step(
			12,
			"Host independent ammo",
			"Host fire request rejected"
		)


		finish_failed()

		return


	phase_timer = 0.0

	phase = TestPhase.HOST_WAIT_OWN_FIRE


# =========================================================
# HOST — VERIFY OWN SHOT
# =========================================================

func process_host_wait_own_fire(
	delta: float
):

	phase_timer += delta


	if phase_timer > action_timeout:

		fail_step(
			12,
			"Host independent ammo",
			"Timed out waiting for Host 2 -> 1"
		)


		finish_failed()

		return


	var host_ammo: int = (
		network_combat_manager.get_peer_harpoon_ammo(
			1
		)
	)


	var client_ammo: int = (
		network_combat_manager.get_peer_harpoon_ammo(
			remote_peer_id
		)
	)


	if host_ammo != 1:
		return


	if client_ammo != 0:

		fail_step(
			12,
			"Host independent ammo",
			"Host shot modified Client ammo"
		)


		finish_failed()

		return


	pass_step(
		12,
		"Host independent ammo",
		"Host 2 -> 1 | Client remained 0"
	)


	qa_host_primary_complete.rpc_id(
		remote_peer_id
	)


	print_summary(
		"HOST PRIMARY"
	)


	print(
		"[QA] Host waiting for Client late join."
	)


	phase = TestPhase.HOST_WAIT_LATE_JOIN


# =========================================================
# CLIENT — WAIT PREPARE
# =========================================================

func process_client_wait_prepare(
	delta: float
):

	phase_timer += delta


	if phase_timer > network_timeout:

		fail_step(
			3,
			"Client preparation",
			"Host never started ammo QA"
		)


		finish_failed()

		return


	if not client_prepare_allowed:
		return


	clean_item(
		"harpoon_ammo"
	)


	if not inventory.has_item(
		"harpoon_gun",
		1
	):

		if not inventory.add_item(
			"harpoon_gun",
			1
		):

			fail_step(
				3,
				"Client preparation",
				"Could not add harpoon_gun"
			)


			finish_failed()

			return


	if not equipment.equip_item(
		"harpoon_gun"
	):

		fail_step(
			3,
			"Client preparation",
			"Could not equip harpoon_gun"
		)


		finish_failed()

		return


	pin_client_near_ammo_rack()

	force_publish_local_state()


	pass_step(
		3,
		"Client preparation",
		"harpoon_gun equipped | Local ammo cleared"
	)


	phase_timer = 0.0

	publish_accumulator = 0.0

	phase = TestPhase.CLIENT_WAIT_PICKUP


# =========================================================
# CLIENT — WAIT PICKUP PERMISSION
# =========================================================

func process_client_wait_pickup(
	delta: float
):

	phase_timer += delta

	publish_accumulator += delta


	if phase_timer > network_timeout:

		fail_step(
			4,
			"Client authoritative context",
			"Host never authorized pickup test"
		)


		finish_failed()

		return


	pin_client_near_ammo_rack()


	if publish_accumulator >= publish_interval:

		publish_accumulator = 0.0

		force_publish_local_state()


	if not client_pickup_allowed:
		return


	pass_step(
		4,
		"Client authoritative context",
		"Host validated position + harpoon_gun"
	)


	harpoon_ammo_rack.interact(
		player
	)


	phase_timer = 0.0

	phase = TestPhase.CLIENT_WAIT_PICKUP_RESULT


# =========================================================
# CLIENT — VERIFY 0 -> 6
# =========================================================

func process_client_wait_pickup_result(
	delta: float
):

	phase_timer += delta


	if phase_timer > action_timeout:

		fail_step(
			5,
			"Authoritative ammo pickup",
			"Client did not receive ammo 6"
		)


		finish_failed()

		return


	var ammo: int = (
		network_combat_manager.get_local_authoritative_harpoon_ammo()
	)


	if ammo != 6:
		return


	if get_local_inventory_ammo() != 6:
		return


	pass_step(
		5,
		"Authoritative ammo pickup",
		"0 -> 6 replicated to Client inventory"
	)


	phase_timer = 0.0

	phase = TestPhase.CLIENT_WAIT_FIRE_PERMISSION


# =========================================================
# CLIENT — WAIT CONTROLLED AMMO 3
# =========================================================

func process_client_wait_fire_permission(
	delta: float
):

	phase_timer += delta

	publish_accumulator += delta


	if phase_timer > action_timeout:

		fail_step(
			6,
			"Controlled fire state",
			"Host did not prepare ammo 3"
		)


		finish_failed()

		return


	pin_client_near_ammo_rack()


	if publish_accumulator >= publish_interval:

		publish_accumulator = 0.0

		force_publish_local_state()


	if not client_fire_allowed:
		return


	if (
		network_combat_manager.get_local_authoritative_harpoon_ammo()
		!= 3
	):

		return


	if get_local_inventory_ammo() != 3:
		return


	pass_step(
		6,
		"Controlled fire state",
		"Client authoritative ammo = 3"
	)


	phase_timer = 0.0

	phase = TestPhase.CLIENT_FIRE_1


# =========================================================
# CLIENT — FIRE
# =========================================================

func process_client_fire(
	delta: float,
	next_phase: TestPhase
):

	phase_timer += delta

	publish_accumulator += delta


	if phase_timer > action_timeout:

		fail_step(
			7,
			"Client fire",
			"Timed out waiting for fire availability"
		)


		finish_failed()

		return


	pin_client_near_ammo_rack()


	if publish_accumulator >= publish_interval:

		publish_accumulator = 0.0

		force_publish_local_state()


	if weapon_system.get_cooldown_remaining() > 0.0:
		return


	if weapon_system.is_network_fire_pending():
		return


	var target_position: Vector2 = (
		player.global_position
		+ Vector2(
			250.0,
			0.0
		)
	)


	var fired: bool = bool(
		weapon_system.fire_at(
			target_position
		)
	)


	if not fired:

		fail_step(
			7,
			"Client fire",
			"WeaponSystem rejected valid shot"
		)


		finish_failed()

		return


	phase_timer = 0.0

	phase = next_phase


# =========================================================
# CLIENT — WAIT AMMO 2 / 1
# =========================================================

func process_client_wait_ammo(
	delta: float,
	expected_ammo: int,
	step_number: int,
	next_phase: TestPhase
):

	phase_timer += delta


	if phase_timer > action_timeout:

		fail_step(
			step_number,
			"Authoritative Client fire",
			"Timed out waiting for ammo "
			+ str(
				expected_ammo
			)
		)


		finish_failed()

		return


	if weapon_system.is_network_fire_pending():
		return


	if (
		network_combat_manager.get_local_authoritative_harpoon_ammo()
		!= expected_ammo
	):

		return


	if get_local_inventory_ammo() != expected_ammo:
		return


	pass_step(
		step_number,
		"Authoritative Client fire",
		"Client ammo = "
		+ str(
			expected_ammo
		)
	)


	phase_timer = 0.0

	phase = next_phase


# =========================================================
# CLIENT — WAIT ZERO
# =========================================================

func process_client_wait_zero(
	delta: float
):

	phase_timer += delta


	if phase_timer > action_timeout:

		fail_step(
			9,
			"Client reaches zero",
			"Timed out waiting for ammo 0"
		)


		finish_failed()

		return


	if weapon_system.is_network_fire_pending():
		return


	if (
		network_combat_manager.get_local_authoritative_harpoon_ammo()
		!= 0
	):

		return


	if get_local_inventory_ammo() != 0:
		return


	pass_step(
		9,
		"Client reaches zero",
		"Authoritative ammo = 0"
	)


	phase_timer = 0.0

	phase = TestPhase.CLIENT_WAIT_LOCAL_ZERO_TEST


# =========================================================
# CLIENT — LOCAL BLOCK AT ZERO
# =========================================================

func process_client_local_zero_test(
	delta: float
):

	phase_timer += delta


	if phase_timer > action_timeout:

		fail_step(
			10,
			"Local zero-ammo block",
			"Host never started zero test"
		)


		finish_failed()

		return


	if not client_local_zero_allowed:
		return


	if weapon_system.get_cooldown_remaining() > 0.0:
		return


	var target_position: Vector2 = (
		player.global_position
		+ Vector2(
			250.0,
			0.0
		)
	)


	var fired: bool = bool(
		weapon_system.fire_at(
			target_position
		)
	)


	var blocked: bool = not fired


	if blocked:

		pass_step(
			10,
			"Local zero-ammo block",
			"WeaponSystem rejected FIRE at 0"
		)

	else:

		fail_step(
			10,
			"Local zero-ammo block",
			"WeaponSystem returned true at ammo 0"
		)


	qa_report_local_zero_result.rpc_id(
		1,
		blocked
	)


	if not blocked:

		finish_failed()

		return


	phase_timer = 0.0

	phase = TestPhase.CLIENT_WAIT_BYPASS_TEST


# =========================================================
# CLIENT — DIRECT MANAGER BYPASS
# =========================================================

func process_client_bypass_test(
	delta: float
):

	phase_timer += delta


	if phase_timer > action_timeout:

		fail_step(
			11,
			"Host zero-ammo authority",
			"Host never requested bypass test"
		)


		finish_failed()

		return


	if not client_bypass_allowed:
		return


	var target_position: Vector2 = (
		player.global_position
		+ Vector2(
			250.0,
			0.0
		)
	)


	# -----------------------------------------------------
	# Deliberadamente evitamos WeaponSystem.
	#
	# Esto comprueba que incluso una request enviada
	# directamente al CombatManager es rechazada por Host
	# cuando authoritative ammo == 0.
	# -----------------------------------------------------

	network_combat_manager.request_player_fire(
		target_position,
		"harpoon_gun"
	)


	print(
		"[QA] Client sent deliberate zero-ammo bypass request"
	)


	phase_timer = 0.0

	phase = TestPhase.CLIENT_WAIT_BYPASS_RESULT


# =========================================================
# CLIENT — WAIT HOST BYPASS RESULT
# =========================================================

func process_client_wait_bypass_result(
	delta: float
):

	phase_timer += delta


	if phase_timer > action_timeout:

		fail_step(
			11,
			"Host zero-ammo authority",
			"Host did not confirm rejection"
		)


		finish_failed()

		return


	if not client_bypass_done:
		return


	pass_step(
		11,
		"Host zero-ammo authority",
		"Direct request produced no projectile"
	)


	phase_timer = 0.0

	phase = TestPhase.CLIENT_WAIT_HOST_COMPLETE


# =========================================================
# CLIENT — WAIT HOST INDEPENDENCE TEST
# =========================================================

func process_client_wait_host_complete(
	delta: float
):

	phase_timer += delta


	if phase_timer > action_timeout:

		fail_step(
			12,
			"Host independent ammo",
			"Host did not complete own fire test"
		)


		finish_failed()

		return


	if not client_host_test_complete:
		return


	if (
		network_combat_manager.get_local_authoritative_harpoon_ammo()
		!= 0
	):

		fail_step(
			12,
			"Host independent ammo",
			"Client ammo changed after Host shot"
		)


		finish_failed()

		return


	if get_local_inventory_ammo() != 0:

		fail_step(
			12,
			"Host independent ammo",
			"Client inventory changed after Host shot"
		)


		finish_failed()

		return


	pass_step(
		12,
		"Host independent ammo",
		"Client remained 0 after Host shot"
	)


	client_primary_complete = true


	print_summary(
		"CLIENT PRIMARY"
	)


	print("")
	print(
		"[QA] PRIMARY PERSONAL AMMO TEST PASSED"
	)

	print(
		"[QA] Disconnect ONLY the Client now."
	)

	print(
		"[QA] Then reconnect it to the same Host."
	)


	phase = TestPhase.CLIENT_WAIT_DISCONNECT


# =========================================================
# PREPARE TRUE LATE JOIN
# =========================================================

func prepare_true_late_join():

	expecting_late_join = true


	# -----------------------------------------------------
	# Corrompemos deliberadamente la copia local.
	#
	# El nuevo Peer debe comenzar en 0 y el snapshot
	# del Host debe eliminar este estado falso.
	# -----------------------------------------------------

	clean_item(
		"harpoon_ammo"
	)


	inventory.add_item(
		"harpoon_ammo",
		5
	)


	network_combat_manager.local_authoritative_harpoon_ammo = 5

	network_combat_manager.local_authoritative_ammo_initialized = true


	print("")
	print(
		"[QA] ========================================"
	)

	print(
		"[QA] PREPARE: PERSONAL AMMO TRUE LATE JOIN"
	)

	print(
		"[QA] ========================================"
	)

	print(
		"[QA] Client deliberately poisoned to Ammo = 5"
	)


	phase_timer = 0.0

	phase = TestPhase.CLIENT_LATE_JOIN_WAIT


# =========================================================
# CLIENT — LATE JOIN
# =========================================================

func process_client_late_join(
	delta: float
):

	if not expecting_late_join:
		return


	if not NetworkManager.is_online():
		return


	if not NetworkManager.is_client():
		return


	phase_timer += delta


	if phase_timer > network_timeout:

		fail_step(
			13,
			"Late join ammo snapshot",
			"Timed out waiting for authoritative 0"
		)


		finish_failed()

		return


	if (
		network_combat_manager.get_local_authoritative_harpoon_ammo()
		!= 0
	):

		return


	if get_local_inventory_ammo() != 0:
		return


	pass_step(
		13,
		"Late join ammo snapshot",
		"Host restored authoritative Ammo = 0"
	)


	print_summary(
		"CLIENT + TRUE LATE JOIN"
	)


	qa_report_late_join_complete.rpc_id(
		1
	)


	restore_environment()


	phase = TestPhase.CLIENT_COMPLETE


# =========================================================
# RPC — HOST -> CLIENT PREPARE
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_prepare_client():

	if not NetworkManager.is_client():
		return


	client_prepare_allowed = true


# =========================================================
# RPC — HOST -> CLIENT PICKUP
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_allow_client_pickup():

	if not NetworkManager.is_client():
		return


	client_pickup_allowed = true


# =========================================================
# RPC — HOST -> CLIENT FIRE
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_begin_client_fire():

	if not NetworkManager.is_client():
		return


	client_fire_allowed = true


# =========================================================
# RPC — HOST -> CLIENT LOCAL ZERO
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_test_client_local_zero():

	if not NetworkManager.is_client():
		return


	client_local_zero_allowed = true


# =========================================================
# RPC — CLIENT -> HOST LOCAL ZERO RESULT
# =========================================================

@rpc(
	"any_peer",
	"call_remote",
	"reliable"
)
func qa_report_local_zero_result(
	blocked: bool
):

	if not NetworkManager.is_host():
		return


	host_local_zero_result_received = true

	host_local_zero_result = blocked


# =========================================================
# RPC — HOST -> CLIENT BYPASS
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_test_host_zero_bypass():

	if not NetworkManager.is_client():
		return


	client_bypass_allowed = true


# =========================================================
# RPC — HOST -> CLIENT BYPASS DONE
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_zero_bypass_done():

	if not NetworkManager.is_client():
		return


	client_bypass_done = true


# =========================================================
# RPC — HOST -> CLIENT HOST TEST COMPLETE
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_host_primary_complete():

	if not NetworkManager.is_client():
		return


	client_host_test_complete = true


# =========================================================
# RPC — CLIENT -> HOST LATE JOIN COMPLETE
# =========================================================

@rpc(
	"any_peer",
	"call_remote",
	"reliable"
)
func qa_report_late_join_complete():

	if not NetworkManager.is_host():
		return


	var new_peer_id: int = (
		multiplayer.get_remote_sender_id()
	)


	var new_peer_ammo: int = (
		network_combat_manager.get_peer_harpoon_ammo(
			new_peer_id
		)
	)


	if new_peer_ammo != 0:

		fail_step(
			13,
			"Late join ammo snapshot",
			"New Peer authoritative ammo != 0"
		)


		finish_failed()

		return


	pass_step(
		13,
		"Late join ammo snapshot",
		"New Peer "
		+ str(
			new_peer_id
		)
		+ " starts at Ammo 0"
	)


	print_summary(
		"HOST + TRUE LATE JOIN"
	)


	restore_environment()


	phase = TestPhase.HOST_COMPLETE


# =========================================================
# CLIENT POSITION
# =========================================================

func pin_client_near_ammo_rack():

	if player == null:
		return


	if harpoon_ammo_rack == null:
		return


	player.global_position = (
		harpoon_ammo_rack.global_position
		+ rack_position_offset
	)


	if player is CharacterBody2D:

		player.velocity = Vector2.ZERO


# =========================================================
# FORCE NORMAL NETWORK PUBLICATION
# =========================================================

func force_publish_local_state():

	if network_player_manager == null:
		return


	if network_player_manager.has_method(
		"send_local_movement_state"
	):

		network_player_manager.send_local_movement_state()


	if network_player_manager.has_method(
		"send_local_player_state"
	):

		network_player_manager.send_local_player_state()


# =========================================================
# INVENTORY
# =========================================================

func get_local_inventory_ammo() -> int:

	return int(
		inventory.get_item_quantity(
			"harpoon_ammo"
		)
	)


func clean_item(
	item_id: String
):

	var safety: int = 0


	while (
		inventory.has_item(
			item_id,
			1
		)
		and safety < 32
	):

		var removed: bool = bool(
			inventory.remove_item(
				item_id,
				1
			)
		)


		if not removed:
			break


		safety += 1


# =========================================================
# ENVIRONMENT ISOLATION
# =========================================================

func isolate_environment():

	if not NetworkManager.is_online():

		if (
			hull_breach != null
			and hull_breach.has_method(
				"repair_instant"
			)
		):

			hull_breach.repair_instant()


		if (
			hull_integrity != null
			and hull_integrity.has_method(
				"reset_for_qa"
			)
		):

			hull_integrity.reset_for_qa(
				100.0
			)


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
		"[QA] Hull breach closed and creature hull attacks isolated"
	)


# =========================================================
# RESTORE
# =========================================================

func restore_environment():

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

	restore_environment()


	print_summary(
		"FAILED"
	)


	phase = TestPhase.FAILED


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
