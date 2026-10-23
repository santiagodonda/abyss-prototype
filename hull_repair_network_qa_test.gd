extends Node


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("QA")

@export var start_on_run: bool = false

@export var network_timeout: float = 60.0

@export var complete_timeout: float = 10.0

@export var cancel_hold_time: float = 1.20

@export var publish_interval: float = 0.10

@export var position_offset_from_breach: float = 60.0

@export var value_tolerance: float = 1.0

@export var print_sync_debug: bool = true


# =========================================================
# PHASE
# =========================================================

enum TestPhase {
	IDLE,
	WAIT_NETWORK,

	HOST_WAIT_CLIENT,
	HOST_PREPARE_BREACH,
	HOST_WAIT_CLIENT_READY,
	HOST_WAIT_FIRST_PROGRESS,
	HOST_WAIT_CANCEL,
	HOST_WAIT_SECOND_PROGRESS,
	HOST_WAIT_REPAIRED,
	HOST_COMPLETE,

	CLIENT_WAIT_BREACH,
	CLIENT_PREPARE,
	CLIENT_WAIT_HOST_READY,
	CLIENT_CANCEL_REPAIR,
	CLIENT_WAIT_CANCEL_CONFIRMATION,
	CLIENT_COMPLETE_REPAIR,
	CLIENT_WAIT_REPAIRED,
	CLIENT_WAIT_DISCONNECT,
	CLIENT_LATE_JOIN_WAIT,
	CLIENT_COMPLETE,

	FAILED
}


var phase: TestPhase = TestPhase.IDLE


# =========================================================
# REFERENCES
# =========================================================

var hull_integrity = null

var hull_breach = null

var network_hull_manager = null

var network_interaction_manager = null

var network_player_manager = null

var player = null

var inventory = null

var equipment = null

var sea_creature = null


# =========================================================
# TIMERS
# =========================================================

var phase_timer: float = 0.0

var total_timer: float = 0.0

var publish_accumulator: float = 0.0

var sync_debug_accumulator: float = 0.0


# =========================================================
# RESULTADOS
# =========================================================

var pass_count: int = 0

var fail_count: int = 0

var skip_count: int = 0


# =========================================================
# HOST STATE
# =========================================================

var remote_peer_id: int = 0

var host_first_progress_seen: bool = false

var host_cancel_seen: bool = false

var host_second_progress_seen: bool = false


# =========================================================
# CLIENT STATE
# =========================================================

var client_host_ready: bool = false

var client_cancel_confirmed: bool = false

var client_cancel_release_sent: bool = false

var client_complete_release_sent: bool = false

var client_primary_complete: bool = false

var expecting_late_join: bool = false


# =========================================================
# NETWORK TRANSITION
# =========================================================

var was_online: bool = false

var has_been_online: bool = false


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
		"[QA] TEST: HULL REPAIR NETWORK AUTHORITY"
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


	isolate_creature()


	# -----------------------------------------------------
	# La escena normalmente arranca con HullBreach abierto.
	#
	# La cerramos mientras estamos OFFLINE para que esta QA
	# sea quien genere la brecha controladamente.
	# -----------------------------------------------------

	if not NetworkManager.is_online():

		hull_breach.repair_instant()


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

	sync_debug_accumulator = 0.0


	pass_count = 0

	fail_count = 0

	skip_count = 0


	remote_peer_id = 0


	host_first_progress_seen = false

	host_cancel_seen = false

	host_second_progress_seen = false


	client_host_ready = false

	client_cancel_confirmed = false

	client_cancel_release_sent = false

	client_complete_release_sent = false

	client_primary_complete = false

	expecting_late_join = false


	was_online = false

	has_been_online = false


	creature_setting_saved = false

	previous_creature_hull_attack = false


# =========================================================
# REFERENCES
# =========================================================

func resolve_references():

	var scene = (
		get_tree().current_scene
	)


	if scene == null:
		return


	hull_integrity = (
		scene.get_node_or_null(
			"HullIntegrityPoint"
		)
	)


	hull_breach = (
		scene.get_node_or_null(
			"HullBreach"
		)
	)


	network_hull_manager = (
		scene.get_node_or_null(
			"NetworkHullManager"
		)
	)


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


# =========================================================
# VALIDATE
# =========================================================

func validate_references() -> bool:

	if hull_integrity == null:
		return false


	if hull_breach == null:
		return false


	if network_hull_manager == null:
		return false


	if network_interaction_manager == null:
		return false


	if network_player_manager == null:
		return false


	if player == null:
		return false


	if inventory == null:
		return false


	if equipment == null:
		return false


	if not hull_integrity.has_method(
		"reset_for_qa"
	):
		return false


	if not hull_integrity.has_method(
		"apply_damage"
	):
		return false


	if not hull_integrity.has_method(
		"get_integrity"
	):
		return false


	if not hull_integrity.has_method(
		"is_breached"
	):
		return false


	if not hull_breach.has_method(
		"repair_instant"
	):
		return false


	if not hull_breach.has_method(
		"interact_hold"
	):
		return false


	if not hull_breach.has_method(
		"interact_release"
	):
		return false


	if not hull_breach.has_method(
		"get_repair_progress"
	):
		return false


	if not hull_breach.has_method(
		"is_repaired"
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
		"has_item"
	):
		return false


	if not equipment.has_method(
		"equip_item"
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


		TestPhase.HOST_PREPARE_BREACH:

			process_host_prepare_breach()


		TestPhase.HOST_WAIT_CLIENT_READY:

			process_host_wait_client_ready(
				delta
			)


		TestPhase.HOST_WAIT_FIRST_PROGRESS:

			process_host_wait_first_progress(
				delta
			)


		TestPhase.HOST_WAIT_CANCEL:

			process_host_wait_cancel(
				delta
			)


		TestPhase.HOST_WAIT_SECOND_PROGRESS:

			process_host_wait_second_progress(
				delta
			)


		TestPhase.HOST_WAIT_REPAIRED:

			process_host_wait_repaired(
				delta
			)


		TestPhase.CLIENT_WAIT_BREACH:

			process_client_wait_breach(
				delta
			)


		TestPhase.CLIENT_PREPARE:

			process_client_prepare()


		TestPhase.CLIENT_WAIT_HOST_READY:

			process_client_wait_host_ready(
				delta
			)


		TestPhase.CLIENT_CANCEL_REPAIR:

			process_client_cancel_repair(
				delta
			)


		TestPhase.CLIENT_WAIT_CANCEL_CONFIRMATION:

			process_client_wait_cancel_confirmation(
				delta
			)


		TestPhase.CLIENT_COMPLETE_REPAIR:

			process_client_complete_repair(
				delta
			)


		TestPhase.CLIENT_WAIT_REPAIRED:

			process_client_wait_repaired(
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

		phase = TestPhase.CLIENT_WAIT_BREACH


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


	pass_step(
		3,
		"Remote Client",
		"Peer "
		+ str(
			remote_peer_id
		)
	)


	phase = TestPhase.HOST_PREPARE_BREACH


# =========================================================
# HOST — PREPARE BREACH
# =========================================================

func process_host_prepare_breach():

	hull_breach.repair_instant()


	hull_integrity.reset_for_qa(
		100.0
	)


	var accepted: bool = bool(
		hull_integrity.apply_damage(
			100.0,
			&"qa_hull_repair_network"
		)
	)


	if not accepted:

		fail_step(
			4,
			"Prepare breach",
			"Hull damage rejected"
		)


		finish_failed()

		return


	if not hull_integrity.is_breached():

		fail_step(
			4,
			"Prepare breach",
			"Hull did not enter BREACHED"
		)


		finish_failed()

		return


	if hull_breach.is_repaired():

		fail_step(
			4,
			"Prepare breach",
			"HullBreach remained repaired"
		)


		finish_failed()

		return


	pass_step(
		4,
		"Prepare breach",
		"Integrity = 0 | BREACHED"
	)


	phase_timer = 0.0

	sync_debug_accumulator = 0.0


	phase = TestPhase.HOST_WAIT_CLIENT_READY


# =========================================================
# HOST — WAIT AUTHORITATIVE CLIENT CONTEXT
# =========================================================

func process_host_wait_client_ready(
	delta: float
):

	phase_timer += delta

	sync_debug_accumulator += delta


	if phase_timer > network_timeout:

		fail_step(
			5,
			"Client authoritative context",
			"Host never received valid Client position/tool"
		)


		finish_failed()

		return


	if remote_peer_id <= 1:
		return


	var position_data: Dictionary = (
		network_interaction_manager.get_player_position(
			remote_peer_id
		)
	)


	var valid_position: bool = bool(
		position_data.get(
			"valid",
			false
		)
	)


	var client_position: Vector2 = (
		position_data.get(
			"position",
			Vector2.ZERO
		)
	)


	var tool_id: String = str(
		network_interaction_manager.get_player_tool_id(
			remote_peer_id
		)
	)


	var distance: float = INF


	if valid_position:

		distance = (
			client_position.distance_to(
				hull_breach.global_position
			)
		)


	if (
		print_sync_debug
		and sync_debug_accumulator >= 1.0
	):

		sync_debug_accumulator = 0.0


		print(
			"[QA][SYNC] Host sees Client | Position=",
			client_position,
			" | Distance=",
			snapped(
				distance,
				0.1
			),
			" | Tool=",
			tool_id
		)


	var allowed_distance: float = 110.0


	if hull_breach.has_method(
		"get_network_repair_distance"
	):

		allowed_distance = float(
			hull_breach.get_network_repair_distance()
		)


	if not valid_position:
		return


	if distance > allowed_distance:
		return


	if tool_id != "welding_tool":
		return


	pass_step(
		5,
		"Client authoritative context",
		"Host sees Client at "
		+ str(
			snapped(
				distance,
				0.1
			)
		)
		+ " px | welding_tool"
	)


	qa_allow_client_repair.rpc_id(
		remote_peer_id
	)


	phase_timer = 0.0


	phase = TestPhase.HOST_WAIT_FIRST_PROGRESS


# =========================================================
# HOST — FIRST PROGRESS
# =========================================================

func process_host_wait_first_progress(
	delta: float
):

	phase_timer += delta


	if phase_timer > 8.0:

		fail_step(
			6,
			"First repair start",
			"Host never observed repair progress"
		)


		finish_failed()

		return


	var progress: float = float(
		hull_breach.get_repair_progress()
	)


	if progress < 0.20:
		return


	host_first_progress_seen = true


	pass_step(
		6,
		"First repair start",
		"Host progress = "
		+ str(
			snapped(
				progress,
				0.01
			)
		)
	)


	phase_timer = 0.0


	phase = TestPhase.HOST_WAIT_CANCEL


# =========================================================
# HOST — CANCEL
# =========================================================

func process_host_wait_cancel(
	delta: float
):

	phase_timer += delta


	if phase_timer > 5.0:

		fail_step(
			7,
			"Repair cancellation",
			"Host progress did not reset"
		)


		finish_failed()

		return


	if hull_breach.is_repaired():

		fail_step(
			7,
			"Repair cancellation",
			"Breach completed during cancellation test"
		)


		finish_failed()

		return


	var progress: float = float(
		hull_breach.get_repair_progress()
	)


	if progress > 0.05:
		return


	host_cancel_seen = true


	pass_step(
		7,
		"Repair cancellation",
		"Host confirmed progress reset to 0"
	)


	qa_confirm_client_cancel.rpc_id(
		remote_peer_id
	)


	phase_timer = 0.0


	phase = TestPhase.HOST_WAIT_SECOND_PROGRESS


# =========================================================
# HOST — SECOND START
# =========================================================

func process_host_wait_second_progress(
	delta: float
):

	phase_timer += delta


	if phase_timer > 8.0:

		fail_step(
			8,
			"Repair restart",
			"Host never observed second repair"
		)


		finish_failed()

		return


	var progress: float = float(
		hull_breach.get_repair_progress()
	)


	if progress < 0.20:
		return


	host_second_progress_seen = true


	pass_step(
		8,
		"Repair restart",
		"Host progress restarted"
	)


	phase_timer = 0.0


	phase = TestPhase.HOST_WAIT_REPAIRED


# =========================================================
# HOST — REPAIRED
# =========================================================

func process_host_wait_repaired(
	delta: float
):

	phase_timer += delta


	if phase_timer > complete_timeout:

		fail_step(
			9,
			"Authoritative repair",
			"Timed out waiting for repaired Hull"
		)


		finish_failed()

		return


	if not hull_breach.is_repaired():
		return


	var integrity: float = float(
		hull_integrity.get_integrity()
	)


	if integrity < 59.0:
		return


	if hull_integrity.is_breached():
		return


	pass_step(
		9,
		"Authoritative repair",
		"REPAIRED | Integrity = "
		+ str(
			integrity
		)
	)


	restore_creature()


	print_summary(
		"HOST"
	)


	print(
		"[QA] Host keeps repaired state for late join."
	)


	phase = TestPhase.HOST_COMPLETE


# =========================================================
# CLIENT — WAIT BREACH
# =========================================================

func process_client_wait_breach(
	delta: float
):

	phase_timer += delta


	if phase_timer > network_timeout:

		fail_step(
			3,
			"Breach synchronization",
			"Timed out waiting for BREACHED"
		)


		finish_failed()

		return


	if float(
		hull_integrity.get_integrity()
	) > value_tolerance:

		return


	if not hull_integrity.is_breached():
		return


	if hull_breach.is_repaired():
		return


	pass_step(
		3,
		"Breach synchronization",
		"Client received 0 / BREACHED"
	)


	phase = TestPhase.CLIENT_PREPARE


# =========================================================
# CLIENT — PREPARE
# =========================================================

func process_client_prepare():

	clean_item(
		"welding_fuel"
	)


	if not inventory.has_item(
		"welding_tool",
		1
	):

		if not bool(
			inventory.add_item(
				"welding_tool",
				1
			)
		):

			fail_step(
				4,
				"Repair loadout",
				"Could not add Welding Tool"
			)


			finish_failed()

			return


	if not bool(
		inventory.add_item(
			"welding_fuel",
			1
		)
	):

		fail_step(
			4,
			"Repair loadout",
			"Could not add Welding Fuel"
		)


		finish_failed()

		return


	if not bool(
		equipment.equip_item(
			"welding_tool"
		)
	):

		fail_step(
			4,
			"Repair loadout",
			"Could not equip Welding Tool"
		)


		finish_failed()

		return


	pin_client_to_repair_position()


	force_publish_local_state()


	pass_step(
		4,
		"Repair loadout",
		"Welding Tool + 1 Fuel prepared"
	)


	phase_timer = 0.0

	publish_accumulator = 0.0


	phase = TestPhase.CLIENT_WAIT_HOST_READY


# =========================================================
# CLIENT — WAIT HOST ACK
# =========================================================

func process_client_wait_host_ready(
	delta: float
):

	phase_timer += delta

	publish_accumulator += delta


	if phase_timer > network_timeout:

		fail_step(
			5,
			"Client authoritative context",
			"Host never acknowledged position/tool"
		)


		finish_failed()

		return


	pin_client_to_repair_position()


	if publish_accumulator >= publish_interval:

		publish_accumulator = 0.0

		force_publish_local_state()


	if not client_host_ready:
		return


	pass_step(
		5,
		"Client authoritative context",
		"Host acknowledged repair position + tool"
	)


	phase_timer = 0.0

	client_cancel_release_sent = false


	phase = TestPhase.CLIENT_CANCEL_REPAIR


# =========================================================
# CLIENT — REPAIR THEN CANCEL
# =========================================================

func process_client_cancel_repair(
	delta: float
):

	phase_timer += delta

	publish_accumulator += delta


	pin_client_to_repair_position()


	if publish_accumulator >= publish_interval:

		publish_accumulator = 0.0

		force_publish_local_state()


	hull_breach.interact_hold(
		player,
		delta
	)


	if phase_timer < cancel_hold_time:
		return


	if client_cancel_release_sent:
		return


	client_cancel_release_sent = true


	hull_breach.interact_release(
		player
	)


	pass_step(
		6,
		"Cancel input",
		"Client released after "
		+ str(
			cancel_hold_time
		)
		+ " s"
	)


	phase_timer = 0.0


	phase = TestPhase.CLIENT_WAIT_CANCEL_CONFIRMATION


# =========================================================
# CLIENT — WAIT REAL HOST CANCEL CONFIRMATION
# =========================================================

func process_client_wait_cancel_confirmation(
	delta: float
):

	phase_timer += delta

	publish_accumulator += delta


	pin_client_to_repair_position()


	if publish_accumulator >= publish_interval:

		publish_accumulator = 0.0

		force_publish_local_state()


	if phase_timer > 8.0:

		fail_step(
			7,
			"Cancel synchronization",
			"Host never confirmed cancellation"
		)


		finish_failed()

		return


	if not client_cancel_confirmed:
		return


	if hull_breach.is_repaired():

		fail_step(
			7,
			"Cancel synchronization",
			"Breach unexpectedly repaired"
		)


		finish_failed()

		return


	if not inventory.has_item(
		"welding_fuel",
		1
	):

		fail_step(
			7,
			"Cancel synchronization",
			"Fuel consumed during cancelled repair"
		)


		finish_failed()

		return


	pass_step(
		7,
		"Cancel synchronization",
		"Host confirmed cancel | Fuel preserved"
	)


	phase_timer = 0.0

	client_complete_release_sent = false


	phase = TestPhase.CLIENT_COMPLETE_REPAIR


# =========================================================
# CLIENT — COMPLETE SECOND REPAIR
# =========================================================

func process_client_complete_repair(
	delta: float
):

	phase_timer += delta

	publish_accumulator += delta


	if phase_timer > complete_timeout:

		fail_step(
			8,
			"Complete repair",
			"Timed out waiting for completion"
		)


		finish_failed()

		return


	pin_client_to_repair_position()


	if publish_accumulator >= publish_interval:

		publish_accumulator = 0.0

		force_publish_local_state()


	hull_breach.interact_hold(
		player,
		delta
	)


	if not hull_breach.is_repaired():
		return


	if not client_complete_release_sent:

		client_complete_release_sent = true


		hull_breach.interact_release(
			player
		)


	phase_timer = 0.0


	phase = TestPhase.CLIENT_WAIT_REPAIRED


# =========================================================
# CLIENT — VERIFY COMPLETE
# =========================================================

func process_client_wait_repaired(
	delta: float
):

	phase_timer += delta


	if phase_timer > 5.0:

		fail_step(
			8,
			"Repair replication",
			"Restored Hull state not received"
		)


		finish_failed()

		return


	if not hull_breach.is_repaired():
		return


	var integrity: float = float(
		hull_integrity.get_integrity()
	)


	if integrity < 59.0:
		return


	if hull_integrity.is_breached():
		return


	if inventory.has_item(
		"welding_fuel",
		1
	):

		fail_step(
			8,
			"Repair replication",
			"Fuel was not consumed"
		)


		finish_failed()

		return


	pass_step(
		8,
		"Repair replication",
		"REPAIRED | Integrity = "
		+ str(
			integrity
		)
		+ " | Fuel consumed"
	)


	client_primary_complete = true


	print_summary(
		"CLIENT PRIMARY"
	)


	print("")
	print(
		"[QA] PRIMARY HULL REPAIR TEST PASSED"
	)

	print(
		"[QA] Disconnect ONLY the Client now."
	)

	print(
		"[QA] Then reconnect it to the same Host."
	)


	phase = TestPhase.CLIENT_WAIT_DISCONNECT


# =========================================================
# HOST -> CLIENT AUTHORIZATION
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_allow_client_repair():

	if not NetworkManager.is_client():
		return


	client_host_ready = true


# =========================================================
# HOST -> CLIENT CANCEL CONFIRMED
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func qa_confirm_client_cancel():

	if not NetworkManager.is_client():
		return


	client_cancel_confirmed = true


# =========================================================
# CLIENT POSITION
# =========================================================

func pin_client_to_repair_position():

	if player == null:
		return


	if hull_breach == null:
		return


	player.global_position = (
		hull_breach.global_position
		+ Vector2(
			-position_offset_from_breach,
			0.0
		)
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
# PREPARE LATE JOIN
# =========================================================

func prepare_true_late_join():

	expecting_late_join = true


	# -----------------------------------------------------
	# Corrompemos deliberadamente la copia local.
	# El snapshot del Host debe restaurarla.
	# -----------------------------------------------------

	if hull_integrity.has_method(
		"apply_network_state"
	):

		hull_integrity.apply_network_state(
			{
				"integrity": 0.0,
				"max_integrity": 100.0,
				"breached": true
			}
		)


	if hull_breach.has_method(
		"apply_network_state"
	):

		hull_breach.apply_network_state(
			{
				"repaired": false,
				"repair_progress": 0.0,
				"repair_time": 3.0,
				"water_inflow_rate": 0.0
			}
		)


	print("")
	print(
		"[QA] ========================================"
	)

	print(
		"[QA] PREPARE: HULL REPAIR LATE JOIN"
	)

	print(
		"[QA] ========================================"
	)


	print(
		"[QA] Client deliberately poisoned to 0 / BREACHED / OPEN"
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
			9,
			"Late join repaired snapshot",
			"Timed out waiting for Host snapshot"
		)


		finish_failed()

		return


	if not hull_breach.is_repaired():
		return


	var integrity: float = float(
		hull_integrity.get_integrity()
	)


	if integrity < 59.0:
		return


	if hull_integrity.is_breached():
		return


	pass_step(
		9,
		"Late join repaired snapshot",
		"Host restored REPAIRED | Integrity = "
		+ str(
			integrity
		)
	)


	restore_creature()


	print_summary(
		"CLIENT + LATE JOIN"
	)


	phase = TestPhase.CLIENT_COMPLETE


# =========================================================
# INVENTORY CLEAN
# =========================================================

func clean_item(
	item_id: String
):

	var safety: int = 0


	while (
		inventory.has_item(
			item_id,
			1
		)
		and safety < 16
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
		"[QA] Creature hull attacks disabled for repair QA"
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
