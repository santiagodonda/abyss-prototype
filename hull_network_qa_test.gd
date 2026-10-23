extends Node


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("QA")

@export var start_on_run: bool = false

@export var network_wait_timeout: float = 60.0

@export var initial_settle_time: float = 1.5

@export var state_hold_time: float = 1.5

@export var value_tolerance: float = 0.5


# =========================================================
# PHASE
# =========================================================

enum TestPhase {
	IDLE,

	WAIT_NETWORK,

	HOST_PREPARE,
	HOST_WAIT_REMOTE_PEER,
	HOST_WAIT_INITIAL_SYNC,
	HOST_DAMAGE_50,
	HOST_WAIT_50,
	HOST_DAMAGE_100,
	HOST_WAIT_BREACH,
	HOST_COMPLETE,

	CLIENT_OBSERVE,
	CLIENT_WAIT_BREACH_STABLE,
	CLIENT_WAIT_DISCONNECT,
	CLIENT_LATE_JOIN_WAIT,
	CLIENT_COMPLETE,

	FAILED
}


var phase: TestPhase = (
	TestPhase.IDLE
)


# =========================================================
# REFERENCES
# =========================================================

var hull_integrity = null

var network_hull_manager = null

var sea_creature = null


# =========================================================
# TIMERS
# =========================================================

var phase_timer: float = 0.0

var network_wait_timer: float = 0.0


# =========================================================
# RESULTS
# =========================================================

var pass_count: int = 0

var fail_count: int = 0

var skip_count: int = 0


# =========================================================
# CLIENT OBSERVATION
# =========================================================

var client_initial_seen: bool = false

var client_mid_seen: bool = false

var client_breach_seen: bool = false

var client_primary_complete: bool = false

var expecting_late_join: bool = false

var client_late_join_complete: bool = false


# =========================================================
# NETWORK TRANSITION
# =========================================================

var was_online: bool = false

var has_been_online: bool = false


# =========================================================
# CREATURE ISOLATION
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
		"[QA] TEST: HULL NETWORK AUTHORITY"
	)

	print(
		"[QA] ========================================"
	)


	resolve_references()


	if not validate_references():

		fail_step(
			1,
			"Required nodes",
			"Missing required references"
		)


		finish_failed()

		return


	pass_step(
		1,
		"Required nodes",
		"All references resolved"
	)


	# -----------------------------------------------------
	# IMPORTANTE:
	#
	# Aislamos a la criatura ANTES de conectar.
	# Así no puede destruir el casco durante el período
	# OFFLINE previo a Host/Client.
	# -----------------------------------------------------

	isolate_creature_hull_attack()


	phase = (
		TestPhase.WAIT_NETWORK
	)


	network_wait_timer = 0.0


# =========================================================
# RESET
# =========================================================

func reset_test_state():

	phase = (
		TestPhase.IDLE
	)


	phase_timer = 0.0

	network_wait_timer = 0.0


	pass_count = 0

	fail_count = 0

	skip_count = 0


	client_initial_seen = false

	client_mid_seen = false

	client_breach_seen = false

	client_primary_complete = false

	expecting_late_join = false

	client_late_join_complete = false


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


	network_hull_manager = (
		scene.get_node_or_null(
			"NetworkHullManager"
		)
	)


	sea_creature = (
		scene.get_node_or_null(
			"SeaCreature"
		)
	)


# =========================================================
# VALIDATE REFERENCES
# =========================================================

func validate_references() -> bool:

	if hull_integrity == null:
		return false


	if not is_instance_valid(
		hull_integrity
	):

		return false


	if network_hull_manager == null:
		return false


	if not is_instance_valid(
		network_hull_manager
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


	if not hull_integrity.has_method(
		"apply_damage"
	):

		return false


	if not hull_integrity.has_method(
		"reset_for_qa"
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


		TestPhase.HOST_PREPARE:

			process_host_prepare()


		TestPhase.HOST_WAIT_REMOTE_PEER:

			process_host_wait_remote_peer(
				delta
			)


		TestPhase.HOST_WAIT_INITIAL_SYNC:

			process_host_wait_initial_sync(
				delta
			)


		TestPhase.HOST_DAMAGE_50:

			process_host_damage_50()


		TestPhase.HOST_WAIT_50:

			process_host_wait_50(
				delta
			)


		TestPhase.HOST_DAMAGE_100:

			process_host_damage_100()


		TestPhase.HOST_WAIT_BREACH:

			process_host_wait_breach(
				delta
			)


		TestPhase.HOST_COMPLETE:

			pass


		TestPhase.CLIENT_OBSERVE:

			process_client_observe(
				delta
			)


		TestPhase.CLIENT_WAIT_BREACH_STABLE:

			process_client_breach_stable(
				delta
			)


		TestPhase.CLIENT_WAIT_DISCONNECT:

			pass


		TestPhase.CLIENT_LATE_JOIN_WAIT:

			process_client_late_join(
				delta
			)


		TestPhase.CLIENT_COMPLETE:

			pass


# =========================================================
# NETWORK TRANSITION
# =========================================================

func process_network_transition():

	var online_now: bool = (
		NetworkManager.is_online()
	)


	# -----------------------------------------------------
	# CLIENT PRIMARIO:
	# ONLINE -> OFFLINE
	#
	# Solamente después de haber completado 100 -> 50 -> 0
	# empezamos la prueba de reconnect.
	# -----------------------------------------------------

	if (
		was_online
		and not online_now
		and has_been_online
		and client_primary_complete
		and not client_late_join_complete
	):

		prepare_client_for_late_join()


	if online_now:

		has_been_online = true


	was_online = online_now


# =========================================================
# WAIT NETWORK
# =========================================================

func process_wait_network(
	delta: float
):

	network_wait_timer += delta


	if network_wait_timer > network_wait_timeout:

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


		phase = (
			TestPhase.HOST_PREPARE
		)


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


		phase = (
			TestPhase.CLIENT_OBSERVE
		)


# =========================================================
# HOST — PREPARE BEFORE CLIENT SNAPSHOT
# =========================================================

func process_host_prepare():

	hull_integrity.reset_for_qa(
		100.0
	)


	var integrity: float = (
		float(
			hull_integrity.get_integrity()
		)
	)


	var breached: bool = (
		bool(
			hull_integrity.is_breached()
		)
	)


	if (
		not approximately_equal(
			integrity,
			100.0
		)
		or breached
	):

		fail_step(
			3,
			"Host initial state",
			"Expected 100 / INTACT, got "
			+ describe_hull_state()
		)


		finish_failed()

		return


	pass_step(
		3,
		"Host initial state",
		describe_hull_state()
	)


	network_wait_timer = 0.0


	phase = (
		TestPhase.HOST_WAIT_REMOTE_PEER
	)


# =========================================================
# HOST — WAIT CLIENT
# =========================================================

func process_host_wait_remote_peer(
	delta: float
):

	network_wait_timer += delta


	if network_wait_timer > network_wait_timeout:

		fail_step(
			4,
			"Remote peer",
			"Timed out waiting for Client"
		)


		finish_failed()

		return


	var peers: PackedInt32Array = (
		multiplayer.get_peers()
	)


	if peers.is_empty():
		return


	pass_step(
		4,
		"Remote peer",
		"Connected Clients = "
		+ str(
			peers.size()
		)
	)


	phase_timer = 0.0


	phase = (
		TestPhase.HOST_WAIT_INITIAL_SYNC
	)


# =========================================================
# HOST — GIVE CLIENT TIME TO RECEIVE 100
# =========================================================

func process_host_wait_initial_sync(
	delta: float
):

	phase_timer += delta


	if phase_timer < initial_settle_time:
		return


	phase_timer = 0.0


	phase = (
		TestPhase.HOST_DAMAGE_50
	)


# =========================================================
# HOST — 100 -> 50
# =========================================================

func process_host_damage_50():

	var accepted: bool = (
		hull_integrity.apply_damage(
			50.0,
			&"qa_network_hull"
		)
	)


	if not accepted:

		fail_step(
			5,
			"Host damage 100 -> 50",
			"Damage rejected"
		)


		finish_failed()

		return


	var integrity: float = (
		float(
			hull_integrity.get_integrity()
		)
	)


	var breached: bool = (
		bool(
			hull_integrity.is_breached()
		)
	)


	if (
		not approximately_equal(
			integrity,
			50.0
		)
		or breached
	):

		fail_step(
			5,
			"Host damage 100 -> 50",
			"Unexpected state: "
			+ describe_hull_state()
		)


		finish_failed()

		return


	pass_step(
		5,
		"Host damage 100 -> 50",
		describe_hull_state()
	)


	phase_timer = 0.0


	phase = (
		TestPhase.HOST_WAIT_50
	)


# =========================================================
# HOST — HOLD 50
# =========================================================

func process_host_wait_50(
	delta: float
):

	phase_timer += delta


	if phase_timer < state_hold_time:
		return


	phase_timer = 0.0


	phase = (
		TestPhase.HOST_DAMAGE_100
	)


# =========================================================
# HOST — 50 -> 0
# =========================================================

func process_host_damage_100():

	var accepted: bool = (
		hull_integrity.apply_damage(
			50.0,
			&"qa_network_hull"
		)
	)


	if not accepted:

		fail_step(
			6,
			"Host breach",
			"Second damage rejected"
		)


		finish_failed()

		return


	var integrity: float = (
		float(
			hull_integrity.get_integrity()
		)
	)


	var breached: bool = (
		bool(
			hull_integrity.is_breached()
		)
	)


	if (
		not approximately_equal(
			integrity,
			0.0
		)
		or not breached
	):

		fail_step(
			6,
			"Host breach",
			"Expected 0 / BREACHED, got "
			+ describe_hull_state()
		)


		finish_failed()

		return


	pass_step(
		6,
		"Host breach",
		describe_hull_state()
	)


	phase_timer = 0.0


	phase = (
		TestPhase.HOST_WAIT_BREACH
	)


# =========================================================
# HOST — BREACH STABLE
# =========================================================

func process_host_wait_breach(
	delta: float
):

	phase_timer += delta


	if phase_timer < state_hold_time:
		return


	var integrity: float = (
		float(
			hull_integrity.get_integrity()
		)
	)


	var breached: bool = (
		bool(
			hull_integrity.is_breached()
		)
	)


	if (
		not approximately_equal(
			integrity,
			0.0
		)
		or not breached
	):

		fail_step(
			7,
			"Host authoritative state",
			"State changed unexpectedly: "
			+ describe_hull_state()
		)


		finish_failed()

		return


	pass_step(
		7,
		"Host authoritative state",
		"Stable at "
		+ describe_hull_state()
	)


	restore_creature_hull_attack()


	print_summary(
		"HOST"
	)


	print(
		"[QA] Host remains at 0 / BREACHED."
	)

	print(
		"[QA] After Client primary PASS, disconnect and reconnect Client."
	)


	phase = (
		TestPhase.HOST_COMPLETE
	)


# =========================================================
# CLIENT — OBSERVE PRIMARY SYNC
# =========================================================

func process_client_observe(
	delta: float
):

	phase_timer += delta


	if phase_timer > network_wait_timeout:

		fail_step(
			3,
			"Client synchronization",
			"Timed out waiting for 100 -> 50 -> 0"
		)


		finish_failed()

		return


	var integrity: float = (
		float(
			hull_integrity.get_integrity()
		)
	)


	var breached: bool = (
		bool(
			hull_integrity.is_breached()
		)
	)


	# -----------------------------------------------------
	# IMPORTANTE:
	#
	# Durante la conexión inicial, 0/BREACHED NO ES
	# considerado late join.
	#
	# Primero necesitamos ver 100/INTACT.
	# -----------------------------------------------------

	if not client_initial_seen:

		if (
			approximately_equal(
				integrity,
				100.0
			)
			and not breached
		):

			client_initial_seen = true


			pass_step(
				3,
				"Client initial sync",
				describe_hull_state()
			)


		return


	# -----------------------------------------------------
	# SECOND STATE = 50
	# -----------------------------------------------------

	if not client_mid_seen:

		if (
			approximately_equal(
				integrity,
				50.0
			)
			and not breached
		):

			client_mid_seen = true


			pass_step(
				4,
				"Client receives 50",
				describe_hull_state()
			)


		return


	# -----------------------------------------------------
	# THIRD STATE = 0 / BREACHED
	# -----------------------------------------------------

	if not client_breach_seen:

		if (
			approximately_equal(
				integrity,
				0.0
			)
			and breached
		):

			client_breach_seen = true


			pass_step(
				5,
				"Client receives breach",
				describe_hull_state()
			)


			phase_timer = 0.0


			phase = (
				TestPhase.CLIENT_WAIT_BREACH_STABLE
			)


# =========================================================
# CLIENT — STABLE BREACH
# =========================================================

func process_client_breach_stable(
	delta: float
):

	phase_timer += delta


	if phase_timer < 0.75:
		return


	var integrity: float = (
		float(
			hull_integrity.get_integrity()
		)
	)


	var breached: bool = (
		bool(
			hull_integrity.is_breached()
		)
	)


	if (
		not approximately_equal(
			integrity,
			0.0
		)
		or not breached
	):

		fail_step(
			6,
			"Client breach stable",
			"State diverged: "
			+ describe_hull_state()
		)


		finish_failed()

		return


	pass_step(
		6,
		"Client breach stable",
		describe_hull_state()
	)


	client_primary_complete = true


	print_summary(
		"CLIENT PRIMARY"
	)


	print("")
	print(
		"[QA] PRIMARY SYNC PASSED"
	)

	print(
		"[QA] Disconnect ONLY the Client now."
	)

	print(
		"[QA] Then reconnect it to the same Host."
	)


	phase = (
		TestPhase.CLIENT_WAIT_DISCONNECT
	)


# =========================================================
# PREPARE TRUE LATE JOIN
# =========================================================

func prepare_client_for_late_join():

	if expecting_late_join:
		return


	if hull_integrity == null:
		return


	if not is_instance_valid(
		hull_integrity
	):

		return


	expecting_late_join = true


	# -----------------------------------------------------
	# OFFLINE:
	#
	# Deliberadamente ponemos el Client en 100 / INTACT.
	# Al volver a conectar, el test sólo pasa si el Host
	# vuelve a imponer 0 / BREACHED.
	# -----------------------------------------------------

	hull_integrity.reset_for_qa(
		100.0
	)


	print("")
	print(
		"[QA] ========================================"
	)

	print(
		"[QA] PREPARE: TRUE HULL LATE JOIN"
	)

	print(
		"[QA] ========================================"
	)


	print(
		"[QA] Client deliberately reset to ",
		describe_hull_state()
	)


	phase_timer = 0.0


	phase = (
		TestPhase.CLIENT_LATE_JOIN_WAIT
	)


# =========================================================
# CLIENT — TRUE LATE JOIN
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


	if phase_timer > network_wait_timeout:

		fail_step(
			7,
			"Late join snapshot",
			"Timed out waiting for authoritative Host state"
		)


		finish_failed()

		return


	var integrity: float = (
		float(
			hull_integrity.get_integrity()
		)
	)


	var breached: bool = (
		bool(
			hull_integrity.is_breached()
		)
	)


	if (
		not approximately_equal(
			integrity,
			0.0
		)
		or not breached
	):

		return


	pass_step(
		7,
		"Late join snapshot",
		"Host restored "
		+ describe_hull_state()
	)


	client_late_join_complete = true


	print_summary(
		"CLIENT + TRUE LATE JOIN"
	)


	phase = (
		TestPhase.CLIENT_COMPLETE
	)


# =========================================================
# CREATURE ISOLATION
# =========================================================

func isolate_creature_hull_attack():

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
		"[QA] Creature hull attacks temporarily disabled"
	)


# =========================================================
# RESTORE CREATURE
# =========================================================

func restore_creature_hull_attack():

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
# HELPERS
# =========================================================

func approximately_equal(
	value_a: float,
	value_b: float
) -> bool:

	return (
		abs(
			value_a
			- value_b
		)
		<= value_tolerance
	)


func describe_hull_state() -> String:

	if hull_integrity == null:
		return "NO HULL"


	var integrity: float = (
		float(
			hull_integrity.get_integrity()
		)
	)


	var state_text: String = "UNKNOWN"


	if hull_integrity.has_method(
		"get_state_text"
	):

		state_text = str(
			hull_integrity.get_state_text()
		)


	return (
		"Integrity = "
		+ str(
			integrity
		)
		+ " | "
		+ state_text
	)


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

	restore_creature_hull_attack()


	print_summary(
		"FAILED"
	)


	phase = (
		TestPhase.FAILED
	)


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
