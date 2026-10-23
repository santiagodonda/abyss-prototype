extends Node


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("QA")

@export var start_on_run: bool = false

@export var network_timeout: float = 35.0

@export var stage_timeout: float = 6.0

@export var poll_interval: float = 0.05

@export var qa_revive_time: float = 0.75


@export_group("Tolerances")

@export var position_tolerance_px: float = 10.0

@export var environment_tolerance: float = 0.20

@export var depth_tolerance_m: float = 2.0


# =========================================================
# POSICIONES
# =========================================================

const HOST_POSITION := Vector2(
	230.0,
	300.0
)

const CLIENT_A_POSITION := Vector2(
	350.0,
	300.0
)

const CLIENT_B_POSITION := Vector2(
	430.0,
	300.0
)

const DOOR_TEST_POSITION := Vector2(
	600.0,
	360.0
)

const REVIVE_A_POSITION := Vector2(
	350.0,
	300.0
)

const REVIVE_B_POSITION := Vector2(
	410.0,
	300.0
)


# =========================================================
# REFERENCIAS
# =========================================================

var player_manager = null

var health_manager = null

var revive_manager = null

var crew_manager = null

var mission_manager = null

var mission_state = null

var mission_objective = null

var power_system = null

var network_interaction_manager = null

var door_component = null

var room_left = null

var room_right = null

var submarine_environment = null

var submarine_status = null

var hull_breach = null

var submarine_turret = null

var network_combat_manager = null

var local_player = null


# =========================================================
# PEERS
# =========================================================

var client_a_id: int = 0

var client_b_id: int = 0


# =========================================================
# QA
# =========================================================

var pass_count: int = 0

var fail_count: int = 0

var skip_count: int = 0

var test_running: bool = false

var test_finished: bool = false


# =========================================================
# REPORTES
# =========================================================

var reports: Dictionary = {}


# =========================================================
# DISCONNECT
# =========================================================

var disconnected_peer_id: int = 0


# =========================================================
# CONFIG ORIGINAL
# =========================================================

var original_lost_condition_time: float = 8.0

var lost_condition_saved: bool = false

var original_revive_time: float = 5.0

var revive_time_saved: bool = false

var original_reactor_on: bool = false

var reactor_state_saved: bool = false


# =========================================================
# QA INTERACTION GUARD
#
# El Player recalcula el interactable más cercano en _process.
#
# Durante el revive automatizado bloqueamos solamente ese
# _process para evitar que un target vecino genere
# interaction_cancel() y termine una sesión que la propia
# QA inició directamente.
#
# No se deshabilita Health, Revive, networking ni física.
# =========================================================

var local_interaction_guard_active: bool = false

var local_player_process_was_enabled: bool = true


# =========================================================
# READY
# =========================================================

func _ready():

	process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)


	NetworkManager.player_disconnected.connect(
		_on_qa_player_disconnected
	)


	if start_on_run:

		call_deferred(
			"start_test"
		)


# =========================================================
# START
# =========================================================

func start_test():

	if test_running:
		return


	test_running = true

	test_finished = false


	await get_tree().process_frame

	await get_tree().process_frame


	resolve_references()

	prepare_environment_guard()

	release_inputs()


	print("")
	print("[QA] ========================================")
	print("[QA] TEST: GLOBAL REINFORCED SKELETON")
	print("[QA] ========================================")


	if not validate_references():

		fail_step(
			1,
			"Required nodes",
			"See [QA][REF][MISSING] / [QA][REF][INVALID] above"
		)


		finish_failed()

		return


	pass_step(
		1,
		"Required nodes",
		"Global skeleton references resolved"
	)


	await wait_for_three_player_network()


	if test_finished:
		return


	if NetworkManager.is_client():

		print(
			"[QA] CLIENT ready | Peer ",
			multiplayer.get_unique_id()
		)

		return


	if not NetworkManager.is_host():

		fail_step(
			2,
			"Network role",
			"Instance is neither Host nor Client"
		)


		finish_failed()

		return


	await run_host_suite()


# =========================================================
# RESOLVER REFERENCIAS
# =========================================================

func resolve_references():

	var scene = (
		get_tree().current_scene
	)


	if scene == null:
		return


	local_player = (
		find_scene_node(
			scene,
			"Player"
		)
	)


	player_manager = (
		find_manager(
			scene,
			"NetworkPlayerManager",
			"network_player_manager"
		)
	)


	health_manager = (
		find_manager(
			scene,
			"NetworkPlayerHealthManager",
			"network_player_health_manager"
		)
	)


	revive_manager = (
		find_manager(
			scene,
			"NetworkReviveManager",
			"network_revive_manager"
		)
	)


	crew_manager = (
		find_manager(
			scene,
			"NetworkCrewRoundManager",
			"network_crew_round_manager"
		)
	)


	mission_manager = (
		find_manager(
			scene,
			"NetworkMissionManager",
			"network_mission_manager"
		)
	)


	mission_state = (
		find_scene_node(
			scene,
			"MissionState"
		)
	)


	mission_objective = (
		find_scene_node(
			scene,
			"MissionObjective"
		)
	)


	power_system = (
		find_scene_node(
			scene,
			"PowerSystem"
		)
	)


	network_interaction_manager = (
		find_manager(
			scene,
			"NetworkInteractionManager",
			"network_interaction_manager"
		)
	)


	room_left = (
		find_scene_node(
			scene,
			"RoomLeft"
		)
	)


	room_right = (
		find_scene_node(
			scene,
			"RoomRight"
		)
	)


	submarine_environment = (
		find_scene_node(
			scene,
			"SubmarineEnvironment"
		)
	)


	submarine_status = (
		find_scene_node(
			scene,
			"SubmarineStatus"
		)
	)


	hull_breach = (
		find_scene_node(
			scene,
			"HullBreach"
		)
	)


	submarine_turret = (
		find_scene_node(
			scene,
			"SubmarineTurret"
		)
	)


	if submarine_turret == null:

		var weapons: Array = (
			get_tree().get_nodes_in_group(
				"submarine_weapon"
			)
		)


		if not weapons.is_empty():

			submarine_turret = (
				weapons[0]
			)


	network_combat_manager = (
		find_manager(
			scene,
			"NetworkCombatManager",
			"network_combat_manager"
		)
	)


	door_component = (
		find_door_network_component(
			scene
		)
	)


# =========================================================
# FIND NODE
# =========================================================

func find_scene_node(
	scene: Node,
	node_name: String
):

	if scene == null:
		return null


	var direct = (
		scene.get_node_or_null(
			NodePath(
				node_name
			)
		)
	)


	if direct != null:
		return direct


	return scene.find_child(
		node_name,
		true,
		false
	)


# =========================================================
# FIND MANAGER
# =========================================================

func find_manager(
	scene: Node,
	node_name: String,
	group_name: String
):

	var by_name = (
		find_scene_node(
			scene,
			node_name
		)
	)


	if by_name != null:
		return by_name


	if not group_name.is_empty():

		var grouped: Array = (
			get_tree().get_nodes_in_group(
				group_name
			)
		)


		if not grouped.is_empty():

			var candidate = (
				grouped[0]
			)


			if (
				candidate != null
				and is_instance_valid(
					candidate
				)
			):

				return candidate


	return null


# =========================================================
# FIND DOOR NETWORK COMPONENT
# =========================================================

func find_door_network_component(
	scene: Node
):

	var door = (
		find_scene_node(
			scene,
			"Door"
		)
	)


	if door != null:

		var named_component = (
			door.get_node_or_null(
				"NetworkInteractable"
			)
		)


		if named_component != null:
			return named_component


		for child in door.get_children():

			if (
				child != null
				and child.is_in_group(
					"network_interactable_component"
				)
			):

				return child


	var components: Array = (
		get_tree().get_nodes_in_group(
			"network_interactable_component"
		)
	)


	for component in components:

		if component == null:
			continue


		if not is_instance_valid(
			component
		):

			continue


		var parent = (
			component.get_parent()
		)


		if (
			parent != null
			and str(
				parent.name
			) == "Door"
		):

			return component


	return null


# =========================================================
# VALIDACIÓN DETALLADA
# =========================================================

func validate_references() -> bool:

	var valid: bool = true


	valid = check_reference(
		"Player",
		local_player
	) and valid


	valid = check_reference(
		"NetworkPlayerManager",
		player_manager
	) and valid


	valid = check_reference(
		"NetworkPlayerHealthManager",
		health_manager
	) and valid


	valid = check_reference(
		"NetworkReviveManager",
		revive_manager
	) and valid


	valid = check_reference(
		"NetworkCrewRoundManager",
		crew_manager
	) and valid


	valid = check_reference(
		"NetworkMissionManager",
		mission_manager
	) and valid


	valid = check_reference(
		"MissionState",
		mission_state
	) and valid


	valid = check_reference(
		"MissionObjective",
		mission_objective
	) and valid


	valid = check_reference(
		"PowerSystem",
		power_system
	) and valid


	valid = check_reference(
		"NetworkInteractionManager",
		network_interaction_manager
	) and valid


	valid = check_reference(
		"Door NetworkInteractable",
		door_component
	) and valid


	valid = check_reference(
		"RoomLeft",
		room_left
	) and valid


	valid = check_reference(
		"RoomRight",
		room_right
	) and valid


	valid = check_reference(
		"SubmarineEnvironment",
		submarine_environment
	) and valid


	valid = check_reference(
		"SubmarineStatus",
		submarine_status
	) and valid


	valid = check_reference(
		"HullBreach",
		hull_breach
	) and valid


	valid = check_reference(
		"SubmarineTurret",
		submarine_turret
	) and valid


	valid = check_reference(
		"NetworkCombatManager",
		network_combat_manager
	) and valid


	if not valid:
		return false


	valid = check_method(
		"NetworkPlayerManager",
		player_manager,
		"get_remote_player"
	) and valid


	valid = check_method(
		"NetworkPlayerManager",
		player_manager,
		"get_remote_player_count"
	) and valid


	valid = check_method(
		"NetworkPlayerManager",
		player_manager,
		"send_local_movement_state"
	) and valid


	valid = check_method(
		"NetworkPlayerHealthManager",
		health_manager,
		"force_unconscious_peer"
	) and valid


	valid = check_method(
		"NetworkPlayerHealthManager",
		health_manager,
		"revive_peer"
	) and valid


	valid = check_method(
		"NetworkPlayerHealthManager",
		health_manager,
		"force_die_peer"
	) and valid


	valid = check_method(
		"NetworkReviveManager",
		revive_manager,
		"request_revive_start"
	) and valid


	valid = check_method(
		"Door NetworkInteractable",
		door_component,
		"request_action"
	) and valid


	valid = check_method(
		"Door NetworkInteractable",
		door_component,
		"get_network_state"
	) and valid


	valid = check_method(
		"HullBreach",
		hull_breach,
		"is_repaired"
	) and valid


	valid = check_method(
		"SubmarineTurret",
		submarine_turret,
		"get_ammo"
	) and valid


	return valid


# =========================================================
# CHECK REFERENCE
# =========================================================

func check_reference(
	label: String,
	reference
) -> bool:

	if reference == null:

		print(
			"[QA][REF][MISSING] ",
			label
		)

		return false


	if not is_instance_valid(
		reference
	):

		print(
			"[QA][REF][INVALID] ",
			label
		)

		return false


	return true


# =========================================================
# CHECK METHOD
# =========================================================

func check_method(
	label: String,
	reference,
	method_name: String
) -> bool:

	if reference == null:
		return false


	if not reference.has_method(
		method_name
	):

		print(
			"[QA][REF][INVALID] ",
			label,
			" missing method ",
			method_name
		)

		return false


	return true


# =========================================================
# ENVIRONMENT GUARD
# =========================================================

func prepare_environment_guard():

	if submarine_status == null:
		return


	original_lost_condition_time = float(
		submarine_status.lost_condition_time
	)


	lost_condition_saved = true


	submarine_status.lost_condition_time = (
		9999.0
	)


func restore_environment_guard():

	if not lost_condition_saved:
		return


	if submarine_status == null:
		return


	if not is_instance_valid(
		submarine_status
	):

		return


	submarine_status.lost_condition_time = (
		original_lost_condition_time
	)


	lost_condition_saved = false


# =========================================================
# INPUT
# =========================================================

func release_inputs():

	Input.action_release(
		"move_up"
	)

	Input.action_release(
		"move_down"
	)

	Input.action_release(
		"move_left"
	)

	Input.action_release(
		"move_right"
	)

	Input.action_release(
		"interact"
	)


# =========================================================
# LOCAL INTERACTION GUARD
# =========================================================

func begin_local_interaction_guard():

	if local_interaction_guard_active:
		return


	if local_player == null:

		resolve_references()


	if local_player == null:
		return


	if not is_instance_valid(
		local_player
	):

		return


	local_player_process_was_enabled = (
		local_player.is_processing()
	)


	local_player.set_process(
		false
	)


	local_interaction_guard_active = true


	print(
		"[QA][REVIVE GUARD] Local Player interaction scan paused"
	)


func end_local_interaction_guard():

	if not local_interaction_guard_active:
		return


	if (
		local_player != null
		and is_instance_valid(
			local_player
		)
	):

		local_player.set_process(
			local_player_process_was_enabled
		)


	local_interaction_guard_active = false


	print(
		"[QA][REVIVE GUARD] Local Player interaction scan restored"
	)


# =========================================================
# NETWORK WAIT
# =========================================================

func wait_for_three_player_network():

	var elapsed: float = 0.0


	while elapsed < network_timeout:

		if NetworkManager.is_client():

			pass_step(
				2,
				"Network ready",
				"CLIENT | Peer "
				+ str(
					multiplayer.get_unique_id()
				)
			)


			return


		if NetworkManager.is_host():

			var clients: Array = (
				get_client_peer_ids()
			)


			if clients.size() >= 2:

				client_a_id = int(
					clients[0]
				)


				client_b_id = int(
					clients[1]
				)


				pass_step(
					2,
					"Network ready",
					"HOST + Client A "
					+ str(
						client_a_id
					)
					+ " + Client B "
					+ str(
						client_b_id
					)
				)


				return


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	fail_step(
		2,
		"Network ready",
		"Timed out waiting for Host + 2 Clients"
	)


	finish_failed()


# =========================================================
# CLIENT IDS
# =========================================================

func get_client_peer_ids() -> Array:

	var result: Array = []


	for peer_key in NetworkManager.get_connected_peer_ids():

		var peer_id: int = int(
			peer_key
		)


		if peer_id > 1:

			result.append(
				peer_id
			)


	result.sort()


	return result


# =========================================================
# HOST SUITE
# =========================================================

func run_host_suite():

	heal_all_connected_players()


	# =====================================================
	# STEP 03 — TOPOLOGY
	# =====================================================

	if not await wait_host_topology():

		fail_step(
			3,
			"Three-player topology",
			get_host_topology_detail()
		)


		finish_failed()

		return


	reset_reports(
		"TOPOLOGY"
	)


	for peer_id in [
		client_a_id,
		client_b_id
	]:

		qa_client_validate_topology.rpc_id(
			peer_id,
			"TOPOLOGY",
			client_a_id,
			client_b_id
		)


	if not await wait_for_client_reports(
		"TOPOLOGY",
		[
			client_a_id,
			client_b_id
		]
	):

		fail_step(
			3,
			"Three-player topology",
			get_report_detail(
				"TOPOLOGY"
			)
		)


		finish_failed()

		return


	if not reports_all_passed(
		"TOPOLOGY",
		[
			client_a_id,
			client_b_id
		]
	):

		fail_step(
			3,
			"Three-player topology",
			get_report_detail(
				"TOPOLOGY"
			)
		)


		finish_failed()

		return


	pass_step(
		3,
		"Three-player topology",
		"Host + 2 Clients | 3 ALIVE | remote avatars coherent"
	)


	# =====================================================
	# STEP 04 — MOVEMENT
	# =====================================================

	await move_local_and_publish(
		HOST_POSITION
	)


	qa_client_move_and_publish.rpc_id(
		client_a_id,
		CLIENT_A_POSITION
	)


	qa_client_move_and_publish.rpc_id(
		client_b_id,
		CLIENT_B_POSITION
	)


	if not await wait_host_remote_position(
		client_a_id,
		CLIENT_A_POSITION
	):

		fail_step(
			4,
			"Three-way movement",
			"Host did not receive Client A final position"
		)


		finish_failed()

		return


	if not await wait_host_remote_position(
		client_b_id,
		CLIENT_B_POSITION
	):

		fail_step(
			4,
			"Three-way movement",
			"Host did not receive Client B final position"
		)


		finish_failed()

		return


	reset_reports(
		"MOVEMENT"
	)


	for peer_id in [
		client_a_id,
		client_b_id
	]:

		qa_client_validate_positions.rpc_id(
			peer_id,
			"MOVEMENT",
			client_a_id,
			client_b_id,
			HOST_POSITION,
			CLIENT_A_POSITION,
			CLIENT_B_POSITION
		)


	if not await wait_for_client_reports(
		"MOVEMENT",
		[
			client_a_id,
			client_b_id
		]
	):

		fail_step(
			4,
			"Three-way movement",
			get_report_detail(
				"MOVEMENT"
			)
		)


		finish_failed()

		return


	if not reports_all_passed(
		"MOVEMENT",
		[
			client_a_id,
			client_b_id
		]
	):

		fail_step(
			4,
			"Three-way movement",
			get_report_detail(
				"MOVEMENT"
			)
		)


		finish_failed()

		return


	pass_step(
		4,
		"Three-way movement",
		"All three peers retain independent synchronized positions"
	)


	# =====================================================
	# STEP 05 — REMOTE INTERACTION
	# =====================================================

	qa_client_move_and_publish.rpc_id(
		client_a_id,
		DOOR_TEST_POSITION
	)


	if not await wait_host_remote_position(
		client_a_id,
		DOOR_TEST_POSITION
	):

		fail_step(
			5,
			"Remote interaction",
			"Client A authoritative position did not reach Door"
		)


		finish_failed()

		return


	var door_before: Dictionary = (
		door_component.get_network_state()
	)


	qa_client_request_door_interaction.rpc_id(
		client_a_id
	)


	if not await wait_for_door_state_change(
		door_before
	):

		fail_step(
			5,
			"Remote interaction",
			"Host did not execute Client A Door interaction"
		)


		finish_failed()

		return


	var door_after: Dictionary = (
		door_component.get_network_state()
	)


	reset_reports(
		"DOOR"
	)


	for peer_id in [
		client_a_id,
		client_b_id
	]:

		qa_client_validate_door_state.rpc_id(
			peer_id,
			"DOOR",
			door_after
		)


	if not await wait_for_client_reports(
		"DOOR",
		[
			client_a_id,
			client_b_id
		]
	):

		fail_step(
			5,
			"Remote interaction",
			get_report_detail(
				"DOOR"
			)
		)


		finish_failed()

		return


	if not reports_all_passed(
		"DOOR",
		[
			client_a_id,
			client_b_id
		]
	):

		fail_step(
			5,
			"Remote interaction",
			get_report_detail(
				"DOOR"
			)
		)


		finish_failed()

		return


	pass_step(
		5,
		"Remote interaction",
		"Client A -> Host -> both Clients | Door state coherent"
	)


	# =====================================================
	# STEP 06 — CROSS SYSTEM WORLD
	# =====================================================

	original_reactor_on = (
		power_system.is_reactor_on()
	)


	reactor_state_saved = true


	power_system.set_reactor_state(
		true
	)


	await get_tree().create_timer(
		0.40
	).timeout


	var left_water: float = float(
		room_left.get(
			"water_level"
		)
	)


	var left_oxygen: float = float(
		room_left.get(
			"oxygen_level"
		)
	)


	var left_pressure: float = float(
		room_left.get(
			"pressure"
		)
	)


	var right_water: float = float(
		room_right.get(
			"water_level"
		)
	)


	var right_oxygen: float = float(
		room_right.get(
			"oxygen_level"
		)
	)


	var right_pressure: float = float(
		room_right.get(
			"pressure"
		)
	)


	var depth_value: float = float(
		submarine_environment.get(
			"depth_meters"
		)
	)


	var breach_repaired: bool = (
		hull_breach.is_repaired()
	)


	var turret_ammo: int = int(
		submarine_turret.get_ammo()
	)


	reset_reports(
		"WORLD"
	)


	for peer_id in [
		client_a_id,
		client_b_id
	]:

		qa_client_validate_world_state.rpc_id(
			peer_id,
			"WORLD",
			left_water,
			left_oxygen,
			left_pressure,
			right_water,
			right_oxygen,
			right_pressure,
			depth_value,
			breach_repaired,
			turret_ammo
		)


	if not await wait_for_client_reports(
		"WORLD",
		[
			client_a_id,
			client_b_id
		]
	):

		fail_step(
			6,
			"Cross-system world state",
			get_report_detail(
				"WORLD"
			)
		)


		finish_failed()

		return


	if not reports_all_passed(
		"WORLD",
		[
			client_a_id,
			client_b_id
		]
	):

		fail_step(
			6,
			"Cross-system world state",
			get_report_detail(
				"WORLD"
			)
		)


		finish_failed()

		return


	pass_step(
		6,
		"Cross-system world state",
		"Power + Environment + Hull + Combat coherent on 3 peers"
	)


	# =====================================================
	# STEP 07 — UNCONSCIOUS
	# =====================================================

	heal_all_connected_players()


	qa_client_move_and_publish.rpc_id(
		client_a_id,
		REVIVE_A_POSITION
	)


	qa_client_move_and_publish.rpc_id(
		client_b_id,
		REVIVE_B_POSITION
	)


	if not await wait_host_remote_position(
		client_a_id,
		REVIVE_A_POSITION
	):

		fail_step(
			7,
			"Unconscious replication",
			"Client A position not ready"
		)


		finish_failed()

		return


	if not await wait_host_remote_position(
		client_b_id,
		REVIVE_B_POSITION
	):

		fail_step(
			7,
			"Unconscious replication",
			"Client B position not ready"
		)


		finish_failed()

		return


	if not health_manager.force_unconscious_peer(
		client_a_id
	):

		fail_step(
			7,
			"Unconscious replication",
			"Host could not force Client A UNCONSCIOUS"
		)


		finish_failed()

		return


	if not await wait_life_state(
		client_a_id,
		"UNCONSCIOUS"
	):

		fail_step(
			7,
			"Unconscious replication",
			"Authoritative Client A state did not become UNCONSCIOUS"
		)


		finish_failed()

		return


	if not await wait_crew_state(
		2,
		1,
		0,
		3,
		"RUNNING"
	):

		fail_step(
			7,
			"Unconscious replication",
			get_crew_detail()
		)


		finish_failed()

		return


	reset_reports(
		"UNCONSCIOUS"
	)


	for peer_id in [
		client_a_id,
		client_b_id
	]:

		qa_client_validate_health_crew.rpc_id(
			peer_id,
			"UNCONSCIOUS",
			client_a_id,
			"UNCONSCIOUS",
			2,
			1,
			0,
			3
		)


	if not await wait_for_client_reports(
		"UNCONSCIOUS",
		[
			client_a_id,
			client_b_id
		]
	):

		fail_step(
			7,
			"Unconscious replication",
			get_report_detail(
				"UNCONSCIOUS"
			)
		)


		finish_failed()

		return


	if not reports_all_passed(
		"UNCONSCIOUS",
		[
			client_a_id,
			client_b_id
		]
	):

		fail_step(
			7,
			"Unconscious replication",
			get_report_detail(
				"UNCONSCIOUS"
			)
		)


		finish_failed()

		return


	pass_step(
		7,
		"Unconscious replication",
		"Client A UNCONSCIOUS | Crew remains RUNNING on all peers"
	)


	# =====================================================
	# STEP 08 — CROSS-CLIENT REVIVE
	# =====================================================

	original_revive_time = float(
		revive_manager.revive_time
	)


	revive_time_saved = true


	revive_manager.revive_time = (
		qa_revive_time
	)


	qa_client_request_revive.rpc_id(
		client_b_id,
		client_a_id
	)


	if not await wait_life_state(
		client_a_id,
		"ALIVE",
		qa_revive_time + 3.0
	):

		fail_step(
			8,
			"Cross-client revive",
			"Client B did not revive Client A"
		)


		finish_failed()

		return


	restore_revive_time()


	var revived_health: float = float(
		health_manager.get_peer_health(
			client_a_id
		)
	)


	if revived_health <= 0.0:

		fail_step(
			8,
			"Cross-client revive",
			"Client A revived with invalid HP"
		)


		finish_failed()

		return


	if not await wait_crew_state(
		3,
		0,
		0,
		3,
		"RUNNING"
	):

		fail_step(
			8,
			"Cross-client revive",
			get_crew_detail()
		)


		finish_failed()

		return


	reset_reports(
		"REVIVED"
	)


	for peer_id in [
		client_a_id,
		client_b_id
	]:

		qa_client_validate_health_crew.rpc_id(
			peer_id,
			"REVIVED",
			client_a_id,
			"ALIVE",
			3,
			0,
			0,
			3
		)


	if not await wait_for_client_reports(
		"REVIVED",
		[
			client_a_id,
			client_b_id
		]
	):

		fail_step(
			8,
			"Cross-client revive",
			get_report_detail(
				"REVIVED"
			)
		)


		finish_failed()

		return


	if not reports_all_passed(
		"REVIVED",
		[
			client_a_id,
			client_b_id
		]
	):

		fail_step(
			8,
			"Cross-client revive",
			get_report_detail(
				"REVIVED"
			)
		)


		finish_failed()

		return


	pass_step(
		8,
		"Cross-client revive",
		"Client B revived Client A | HP "
		+ str(
			snapped(
				revived_health,
				0.1
			)
		)
		+ " | Crew OPERATIONAL"
	)


	# =====================================================
	# STEP 09 — INDIVIDUAL DEATH
	# =====================================================

	if not health_manager.force_die_peer(
		client_a_id
	):

		fail_step(
			9,
			"Individual death",
			"Host could not force Client A DEAD"
		)


		finish_failed()

		return


	if not await wait_life_state(
		client_a_id,
		"DEAD"
	):

		fail_step(
			9,
			"Individual death",
			"Client A did not become DEAD"
		)


		finish_failed()

		return


	if not await wait_crew_state(
		2,
		0,
		1,
		3,
		"RUNNING"
	):

		fail_step(
			9,
			"Individual death",
			get_crew_detail()
		)


		finish_failed()

		return


	if not mission_state.is_running():

		fail_step(
			9,
			"Individual death",
			"Mission ended after one player died"
		)


		finish_failed()

		return


	reset_reports(
		"ONE_DEAD"
	)


	for peer_id in [
		client_a_id,
		client_b_id
	]:

		qa_client_validate_health_crew.rpc_id(
			peer_id,
			"ONE_DEAD",
			client_a_id,
			"DEAD",
			2,
			0,
			1,
			3
		)


	if not await wait_for_client_reports(
		"ONE_DEAD",
		[
			client_a_id,
			client_b_id
		]
	):

		fail_step(
			9,
			"Individual death",
			get_report_detail(
				"ONE_DEAD"
			)
		)


		finish_failed()

		return


	if not reports_all_passed(
		"ONE_DEAD",
		[
			client_a_id,
			client_b_id
		]
	):

		fail_step(
			9,
			"Individual death",
			get_report_detail(
				"ONE_DEAD"
			)
		)


		finish_failed()

		return


	pass_step(
		9,
		"Individual death",
		"1 DEAD + 2 ALIVE | Round and Mission remain RUNNING"
	)


	# =====================================================
	# STEP 10 — DISCONNECT CLEANUP
	# =====================================================

	disconnected_peer_id = 0


	qa_client_disconnect_only.rpc_id(
		client_a_id
	)


	var disconnect_elapsed: float = 0.0


	while disconnect_elapsed < stage_timeout:

		if disconnected_peer_id == client_a_id:
			break


		await get_tree().create_timer(
			poll_interval
		).timeout


		disconnect_elapsed += poll_interval


	if disconnected_peer_id != client_a_id:

		fail_step(
			10,
			"Final disconnect cleanup",
			"Host did not observe Client A disconnect"
		)


		finish_failed()

		return


	var cleanup_elapsed: float = 0.0

	var cleanup_ready: bool = false


	while cleanup_elapsed < stage_timeout:

		cleanup_ready = (
			NetworkManager.get_player_count() == 2
			and player_manager.get_remote_player_count() == 1
			and player_manager.get_remote_player(
				client_a_id
			) == null
			and crew_manager.get_total_count() == 2
			and crew_manager.get_alive_count() == 2
			and crew_manager.get_dead_count() == 0
			and crew_manager.get_round_state() == "RUNNING"
			and mission_state.is_running()
		)


		if cleanup_ready:
			break


		await get_tree().create_timer(
			poll_interval
		).timeout


		cleanup_elapsed += poll_interval


	if not cleanup_ready:

		fail_step(
			10,
			"Final disconnect cleanup",
			"Host cleanup mismatch | "
			+ get_final_detail()
		)


		finish_failed()

		return


	reset_reports(
		"FINAL"
	)


	qa_client_validate_final_cleanup.rpc_id(
		client_b_id,
		"FINAL",
		client_a_id
	)


	if not await wait_for_client_reports(
		"FINAL",
		[
			client_b_id
		]
	):

		fail_step(
			10,
			"Final disconnect cleanup",
			get_report_detail(
				"FINAL"
			)
		)


		finish_failed()

		return


	if not reports_all_passed(
		"FINAL",
		[
			client_b_id
		]
	):

		fail_step(
			10,
			"Final disconnect cleanup",
			get_report_detail(
				"FINAL"
			)
		)


		finish_failed()

		return


	pass_step(
		10,
		"Final disconnect cleanup",
		"No ghost peer | Crew=2 | Mission RUNNING | session coherent"
	)


	# =====================================================
	# COMPLETE
	# =====================================================

	restore_revive_time()

	restore_reactor_state()

	restore_environment_guard()


	print_summary(
		"HOST + 2 CLIENTS"
	)


	qa_client_finish.rpc_id(
		client_b_id
	)


	test_finished = true

	test_running = false


# =========================================================
# HEAL
# =========================================================

func heal_all_connected_players():

	if not NetworkManager.is_host():
		return


	for peer_key in NetworkManager.get_connected_peer_ids():

		var peer_id: int = int(
			peer_key
		)


		if (
			health_manager.get_peer_life_state(
				peer_id
			)
			== "ALIVE"
		):

			health_manager.heal_peer(
				peer_id,
				1000.0
			)


# =========================================================
# TOPOLOGY
# =========================================================

func wait_host_topology() -> bool:

	var elapsed: float = 0.0


	while elapsed < stage_timeout:

		var valid: bool = (
			NetworkManager.get_player_count() == 3
			and player_manager.get_remote_player_count() == 2
			and crew_manager.get_total_count() == 3
			and crew_manager.get_alive_count() == 3
			and crew_manager.get_round_state() == "RUNNING"
			and mission_state.is_running()
			and mission_objective.get_stage_name() == "TRAVEL"
			and health_manager.get_peer_life_state(
				1
			) == "ALIVE"
			and health_manager.get_peer_life_state(
				client_a_id
			) == "ALIVE"
			and health_manager.get_peer_life_state(
				client_b_id
			) == "ALIVE"
		)


		if valid:
			return true


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	return false


func get_host_topology_detail() -> String:

	return (
		"Players="
		+ str(
			NetworkManager.get_player_count()
		)
		+ " Remotes="
		+ str(
			player_manager.get_remote_player_count()
		)
		+ " Crew="
		+ str(
			crew_manager.get_total_count()
		)
		+ " Mission="
		+ mission_state.get_state_name()
		+ "/"
		+ mission_objective.get_stage_name()
	)


@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_client_validate_topology(
	token: String,
	peer_a: int,
	peer_b: int
):

	if not NetworkManager.is_client():
		return


	resolve_references()


	var local_id: int = (
		multiplayer.get_unique_id()
	)


	var other_client_id: int = peer_a


	if local_id == peer_a:

		other_client_id = peer_b


	var elapsed: float = 0.0


	while elapsed < stage_timeout:

		var host_avatar = (
			player_manager.get_remote_player(
				1
			)
		)


		var other_avatar = (
			player_manager.get_remote_player(
				other_client_id
			)
		)


		var passed: bool = (
			player_manager.get_remote_player_count() == 2
			and host_avatar != null
			and is_instance_valid(
				host_avatar
			)
			and other_avatar != null
			and is_instance_valid(
				other_avatar
			)
			and crew_manager.get_total_count() == 3
			and crew_manager.get_alive_count() == 3
			and mission_state.is_running()
			and mission_objective.get_stage_name() == "TRAVEL"
		)


		if passed:

			report_to_host(
				token,
				true,
				"Peer "
				+ str(
					local_id
				)
				+ " sees Host + other Client"
			)

			return


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	report_to_host(
		token,
		false,
		"Peer "
		+ str(
			local_id
		)
		+ " | Remotes="
		+ str(
			player_manager.get_remote_player_count()
		)
		+ " Crew="
		+ str(
			crew_manager.get_total_count()
		)
	)


# =========================================================
# MOVEMENT
# =========================================================

func move_local_and_publish(
	new_position: Vector2
):

	release_inputs()


	local_player.global_position = (
		new_position
	)


	local_player.velocity = Vector2.ZERO


	for i in range(
		6
	):

		player_manager.send_local_movement_state()


		await get_tree().create_timer(
			0.03
		).timeout


@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_client_move_and_publish(
	new_position: Vector2
):

	if not NetworkManager.is_client():
		return


	resolve_references()

	release_inputs()


	local_player.global_position = (
		new_position
	)


	local_player.velocity = Vector2.ZERO


	for i in range(
		6
	):

		player_manager.send_local_movement_state()


		await get_tree().create_timer(
			0.03
		).timeout


func wait_host_remote_position(
	peer_id: int,
	expected_position: Vector2
) -> bool:

	var elapsed: float = 0.0


	while elapsed < stage_timeout:

		var avatar = (
			player_manager.get_remote_player(
				peer_id
			)
		)


		if (
			avatar != null
			and is_instance_valid(
				avatar
			)
			and avatar.target_position.distance_to(
				expected_position
			) <= position_tolerance_px
		):

			return true


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	return false


@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_client_validate_positions(
	token: String,
	peer_a: int,
	peer_b: int,
	host_position: Vector2,
	peer_a_position: Vector2,
	peer_b_position: Vector2
):

	if not NetworkManager.is_client():
		return


	resolve_references()


	var local_id: int = (
		multiplayer.get_unique_id()
	)


	var local_expected: Vector2 = (
		peer_a_position
	)


	var other_id: int = peer_b

	var other_expected: Vector2 = (
		peer_b_position
	)


	if local_id == peer_b:

		local_expected = (
			peer_b_position
		)

		other_id = peer_a

		other_expected = (
			peer_a_position
		)


	var elapsed: float = 0.0


	while elapsed < stage_timeout:

		var host_avatar = (
			player_manager.get_remote_player(
				1
			)
		)


		var other_avatar = (
			player_manager.get_remote_player(
				other_id
			)
		)


		var passed: bool = (
			local_player.global_position.distance_to(
				local_expected
			) <= position_tolerance_px
			and host_avatar != null
			and host_avatar.target_position.distance_to(
				host_position
			) <= position_tolerance_px
			and other_avatar != null
			and other_avatar.target_position.distance_to(
				other_expected
			) <= position_tolerance_px
		)


		if passed:

			report_to_host(
				token,
				true,
				"3-way positions synchronized"
			)

			return


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	report_to_host(
		token,
		false,
		"Position coherence timeout"
	)


# =========================================================
# DOOR
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_client_request_door_interaction():

	if not NetworkManager.is_client():
		return


	resolve_references()


	if door_component == null:
		return


	door_component.request_action(
		"interact"
	)


func wait_for_door_state_change(
	previous_state: Dictionary
) -> bool:

	var elapsed: float = 0.0


	while elapsed < stage_timeout:

		var current_state: Dictionary = (
			door_component.get_network_state()
		)


		if not dictionaries_match(
			previous_state,
			current_state
		):

			return true


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	return false


@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_client_validate_door_state(
	token: String,
	expected_state: Dictionary
):

	if not NetworkManager.is_client():
		return


	resolve_references()


	var elapsed: float = 0.0


	while elapsed < stage_timeout:

		var current_state: Dictionary = (
			door_component.get_network_state()
		)


		if dictionaries_match(
			expected_state,
			current_state
		):

			report_to_host(
				token,
				true,
				"Door state replicated"
			)

			return


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	report_to_host(
		token,
		false,
		"Door state mismatch"
	)


# =========================================================
# WORLD
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_client_validate_world_state(
	token: String,
	expected_left_water: float,
	expected_left_oxygen: float,
	expected_left_pressure: float,
	expected_right_water: float,
	expected_right_oxygen: float,
	expected_right_pressure: float,
	expected_depth: float,
	expected_breach_repaired: bool,
	expected_turret_ammo: int
):

	if not NetworkManager.is_client():
		return


	resolve_references()


	var elapsed: float = 0.0


	while elapsed < stage_timeout:

		var left_water: float = float(
			room_left.get(
				"water_level"
			)
		)


		var left_oxygen: float = float(
			room_left.get(
				"oxygen_level"
			)
		)


		var left_pressure: float = float(
			room_left.get(
				"pressure"
			)
		)


		var right_water: float = float(
			room_right.get(
				"water_level"
			)
		)


		var right_oxygen: float = float(
			room_right.get(
				"oxygen_level"
			)
		)


		var right_pressure: float = float(
			room_right.get(
				"pressure"
			)
		)


		var depth_value: float = float(
			submarine_environment.get(
				"depth_meters"
			)
		)


		var passed: bool = (
			power_system.is_reactor_on()
			and abs(
				left_water
				- expected_left_water
			) <= environment_tolerance
			and abs(
				left_oxygen
				- expected_left_oxygen
			) <= environment_tolerance
			and abs(
				left_pressure
				- expected_left_pressure
			) <= environment_tolerance
			and abs(
				right_water
				- expected_right_water
			) <= environment_tolerance
			and abs(
				right_oxygen
				- expected_right_oxygen
			) <= environment_tolerance
			and abs(
				right_pressure
				- expected_right_pressure
			) <= environment_tolerance
			and abs(
				depth_value
				- expected_depth
			) <= depth_tolerance_m
			and hull_breach.is_repaired()
				== expected_breach_repaired
			and int(
				submarine_turret.get_ammo()
			) == expected_turret_ammo
		)


		if passed:

			report_to_host(
				token,
				true,
				"Power/Env/Hull/Combat coherent"
			)

			return


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	report_to_host(
		token,
		false,
		"World mismatch | Reactor="
		+ str(
			power_system.is_reactor_on()
		)
		+ " Depth="
		+ str(
			submarine_environment.get(
				"depth_meters"
			)
		)
		+ " HullRepaired="
		+ str(
			hull_breach.is_repaired()
		)
		+ " TurretAmmo="
		+ str(
			submarine_turret.get_ammo()
		)
	)


# =========================================================
# HEALTH / CREW
# =========================================================

func wait_life_state(
	peer_id: int,
	expected_state: String,
	timeout: float = -1.0
) -> bool:

	var effective_timeout: float = (
		stage_timeout
	)


	if timeout > 0.0:

		effective_timeout = timeout


	var elapsed: float = 0.0


	while elapsed < effective_timeout:

		if (
			str(
				health_manager.get_peer_life_state(
					peer_id
				)
			)
			== expected_state
		):

			return true


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	return false


func wait_crew_state(
	expected_alive: int,
	expected_unconscious: int,
	expected_dead: int,
	expected_total: int,
	expected_round: String
) -> bool:

	var elapsed: float = 0.0


	while elapsed < stage_timeout:

		if (
			crew_manager.get_alive_count()
				== expected_alive
			and crew_manager.get_unconscious_count()
				== expected_unconscious
			and crew_manager.get_dead_count()
				== expected_dead
			and crew_manager.get_total_count()
				== expected_total
			and crew_manager.get_round_state()
				== expected_round
		):

			return true


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	return false


func get_crew_detail() -> String:

	return (
		"A="
		+ str(
			crew_manager.get_alive_count()
		)
		+ " U="
		+ str(
			crew_manager.get_unconscious_count()
		)
		+ " D="
		+ str(
			crew_manager.get_dead_count()
		)
		+ " T="
		+ str(
			crew_manager.get_total_count()
		)
		+ " Round="
		+ crew_manager.get_round_state()
	)


@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_client_validate_health_crew(
	token: String,
	target_peer_id: int,
	expected_life_state: String,
	expected_alive: int,
	expected_unconscious: int,
	expected_dead: int,
	expected_total: int
):

	if not NetworkManager.is_client():
		return


	resolve_references()


	var elapsed: float = 0.0


	while elapsed < stage_timeout:

		var passed: bool = (
			str(
				health_manager.get_peer_life_state(
					target_peer_id
				)
			) == expected_life_state
			and crew_manager.get_alive_count()
				== expected_alive
			and crew_manager.get_unconscious_count()
				== expected_unconscious
			and crew_manager.get_dead_count()
				== expected_dead
			and crew_manager.get_total_count()
				== expected_total
			and crew_manager.get_round_state()
				== "RUNNING"
			and mission_state.is_running()
		)


		if passed:

			report_to_host(
				token,
				true,
				"Life="
				+ expected_life_state
				+ " | "
				+ get_crew_detail()
			)

			return


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	report_to_host(
		token,
		false,
		"Health/Crew mismatch"
	)


# =========================================================
# REVIVE
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_client_request_revive(
	target_peer_id: int
):

	if not NetworkManager.is_client():
		return


	resolve_references()


	if (
		revive_manager == null
		or local_player == null
	):

		return


	# -----------------------------------------------------
	# IMPORTANTE:
	#
	# Esta QA inicia el revive directamente en el manager,
	# no mediante un E mantenido por el jugador.
	#
	# Por eso evitamos que el selector normal de targets
	# cambie a un locker/máquina durante esta ventana y
	# dispare interaction_cancel() sobre RemotePlayer.
	# -----------------------------------------------------

	begin_local_interaction_guard()


	revive_manager.request_revive_start(
		target_peer_id
	)


	await get_tree().create_timer(
		qa_revive_time + 0.35
	).timeout


	end_local_interaction_guard()


# =========================================================
# RESTORE REVIVE TIME
# =========================================================

func restore_revive_time():

	if not revive_time_saved:
		return


	if revive_manager == null:
		return


	if not is_instance_valid(
		revive_manager
	):

		return


	revive_manager.revive_time = (
		original_revive_time
	)


	revive_time_saved = false


# =========================================================
# DISCONNECT
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_client_disconnect_only():

	if not NetworkManager.is_client():
		return


	end_local_interaction_guard()

	restore_environment_guard()


	NetworkManager.disconnect_from_game()


func _on_qa_player_disconnected(
	peer_id: int
):

	if not test_running:
		return


	if not NetworkManager.is_host():
		return


	disconnected_peer_id = peer_id


@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_client_validate_final_cleanup(
	token: String,
	removed_peer_id: int
):

	if not NetworkManager.is_client():
		return


	resolve_references()


	var elapsed: float = 0.0


	while elapsed < stage_timeout:

		var passed: bool = (
			NetworkManager.get_player_count() == 2
			and player_manager.get_remote_player_count() == 1
			and player_manager.get_remote_player(
				removed_peer_id
			) == null
			and crew_manager.get_total_count() == 2
			and crew_manager.get_alive_count() == 2
			and crew_manager.get_dead_count() == 0
			and crew_manager.get_round_state() == "RUNNING"
			and mission_state.is_running()
		)


		if passed:

			report_to_host(
				token,
				true,
				"Removed peer absent | Crew=2 | Mission RUNNING"
			)

			return


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	report_to_host(
		token,
		false,
		"Final Client cleanup mismatch"
	)


func get_final_detail() -> String:

	return (
		"Players="
		+ str(
			NetworkManager.get_player_count()
		)
		+ " Remotes="
		+ str(
			player_manager.get_remote_player_count()
		)
		+ " Crew="
		+ str(
			crew_manager.get_total_count()
		)
		+ " A="
		+ str(
			crew_manager.get_alive_count()
		)
		+ " D="
		+ str(
			crew_manager.get_dead_count()
		)
		+ " Mission="
		+ mission_state.get_state_name()
	)


# =========================================================
# RESTORE POWER
# =========================================================

func restore_reactor_state():

	if not reactor_state_saved:
		return


	if power_system == null:
		return


	if not is_instance_valid(
		power_system
	):

		return


	power_system.set_reactor_state(
		original_reactor_on
	)


	reactor_state_saved = false


# =========================================================
# DICTIONARY MATCH
# =========================================================

func dictionaries_match(
	expected: Dictionary,
	current: Dictionary
) -> bool:

	if expected.size() != current.size():
		return false


	for key in expected.keys():

		if not current.has(
			key
		):

			return false


		var expected_value = (
			expected[
				key
			]
		)


		var current_value = (
			current[
				key
			]
		)


		if (
			expected_value is float
			or current_value is float
		):

			if not is_equal_approx(
				float(
					expected_value
				),
				float(
					current_value
				)
			):

				return false


		elif expected_value != current_value:

			return false


	return true


# =========================================================
# REPORT SYSTEM
# =========================================================

func reset_reports(
	token: String
):

	reports[
		token
	] = {}


@rpc(
	"any_peer",
	"call_remote",
	"reliable"
)
func qa_report(
	token: String,
	passed: bool,
	detail: String
):

	if not NetworkManager.is_host():
		return


	var sender_id: int = (
		multiplayer.get_remote_sender_id()
	)


	if sender_id <= 1:
		return


	if not reports.has(
		token
	):

		reports[
			token
		] = {}


	var bucket: Dictionary = (
		reports[
			token
		]
	)


	bucket[
		sender_id
	] = {
		"passed":
			passed,

		"detail":
			detail
	}


	reports[
		token
	] = bucket


func report_to_host(
	token: String,
	passed: bool,
	detail: String
):

	if not NetworkManager.is_client():
		return


	qa_report.rpc_id(
		1,
		token,
		passed,
		detail
	)


func wait_for_client_reports(
	token: String,
	expected_peer_ids: Array
) -> bool:

	var elapsed: float = 0.0


	while elapsed < stage_timeout:

		if reports.has(
			token
		):

			var bucket: Dictionary = (
				reports[
					token
				]
			)


			var complete: bool = true


			for peer_id in expected_peer_ids:

				if not bucket.has(
					peer_id
				):

					complete = false

					break


			if complete:
				return true


		await get_tree().create_timer(
			poll_interval
		).timeout


		elapsed += poll_interval


	return false


func reports_all_passed(
	token: String,
	expected_peer_ids: Array
) -> bool:

	if not reports.has(
		token
	):

		return false


	var bucket: Dictionary = (
		reports[
			token
		]
	)


	for peer_id in expected_peer_ids:

		if not bucket.has(
			peer_id
		):

			return false


		var report: Dictionary = (
			bucket[
				peer_id
			]
		)


		if not bool(
			report.get(
				"passed",
				false
			)
		):

			return false


	return true


func get_report_detail(
	token: String
) -> String:

	if not reports.has(
		token
	):

		return (
			"No reports for "
			+ token
		)


	var bucket: Dictionary = (
		reports[
			token
		]
	)


	var parts: Array[String] = []


	for peer_key in bucket.keys():

		var peer_id: int = int(
			peer_key
		)


		var report: Dictionary = (
			bucket[
				peer_key
			]
		)


		parts.append(
			"Peer "
			+ str(
				peer_id
			)
			+ ": "
			+ str(
				report.get(
					"detail",
					""
				)
			)
		)


	if parts.is_empty():

		return (
			"No Client report received"
		)


	return (
		" | ".join(
			parts
		)
	)


# =========================================================
# CLIENT FINISH
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_client_finish():

	if not NetworkManager.is_client():
		return


	end_local_interaction_guard()

	restore_environment_guard()


	print("")
	print("[QA] ========================================")
	print("[QA] GLOBAL REINFORCED SKELETON")
	print("[QA] CLIENT SIDE COMPLETE")
	print("[QA] ========================================")


	test_finished = true

	test_running = false


@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_client_abort():

	if not NetworkManager.is_client():
		return


	end_local_interaction_guard()

	restore_environment_guard()


	test_finished = true

	test_running = false


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
# FAIL CLEANUP
# =========================================================

func finish_failed():

	end_local_interaction_guard()

	restore_revive_time()

	restore_reactor_state()

	restore_environment_guard()


	if NetworkManager.is_host():

		if client_a_id > 1:

			qa_client_abort.rpc_id(
				client_a_id
			)


		if client_b_id > 1:

			qa_client_abort.rpc_id(
				client_b_id
			)


	print_summary(
		"FAILED"
	)


	test_finished = true

	test_running = false


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


	if fail_count == 0:

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
