extends Node


# =========================================================
# RECURSOS
# =========================================================

const SEA_CREATURE_SCRIPT = preload(
	"res://sea_creature.gd"
)


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("Synchronization")

@export var sync_interval: float = 0.10


@export_group("Proxy")

@export var proxy_debug_labels: bool = true


@export_group("Debug")

@export var print_snapshots: bool = true

@export var print_proxy_events: bool = true


# =========================================================
# ESTADO
# =========================================================

var sync_accumulator: float = 0.0


# =========================================================
# READY
# =========================================================

func _ready():

	process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)


	NetworkManager.player_connected.connect(
		_on_player_connected
	)


	print(
		"[NET CREATURE] Manager ready"
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


	# Sólo Host publica criaturas.
	if not NetworkManager.is_host():
		return


	sync_accumulator += delta


	if sync_accumulator < sync_interval:
		return


	sync_accumulator = 0.0


	var creature_state: Dictionary = (
		build_creature_state()
	)


	# Incluso enviamos estado vacío.
	#
	# Esto permite que Clients eliminen proxies
	# cuando ya no existen criaturas dinámicas.
	receive_creature_state.rpc(
		creature_state
	)


# =========================================================
# CONSTRUIR ESTADO
# =========================================================

func build_creature_state() -> Dictionary:

	var state: Dictionary = {}


	var creatures: Array = (
		get_tree().get_nodes_in_group(
			"network_creature"
		)
	)


	for creature in creatures:

		if creature == null:
			continue


		if not is_instance_valid(
			creature
		):
			continue


		if not creature.has_method(
			"get_network_creature_id"
		):
			continue


		if not creature.has_method(
			"build_network_state"
		):
			continue


		var creature_id: String = str(
			creature.get_network_creature_id()
		)


		if creature_id.is_empty():
			continue


		state[
			creature_id
		] = creature.build_network_state()


	return state


# =========================================================
# ESTADO HOST -> CLIENT
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"unreliable"
)
func receive_creature_state(
	state: Dictionary
):

	if NetworkManager.is_restart_in_progress():
		return


	if NetworkManager.is_host():
		return


	apply_creature_state(
		state,
		false
	)


# =========================================================
# SNAPSHOT RELIABLE
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func receive_creature_snapshot(
	state: Dictionary
):

	if NetworkManager.is_restart_in_progress():
		return


	if NetworkManager.is_host():
		return


	apply_creature_state(
		state,
		true
	)


# =========================================================
# APLICAR ESTADO
# =========================================================

func apply_creature_state(
	state: Dictionary,
	snap_positions: bool
):

	var local_creatures: Dictionary = (
		build_local_creature_map()
	)


	var expected_ids: Dictionary = {}


	for creature_key in state.keys():

		var creature_id: String = str(
			creature_key
		)


		expected_ids[
			creature_id
		] = true


		var creature = null

		var created_now: bool = false


		if local_creatures.has(
			creature_id
		):

			creature = (
				local_creatures[
					creature_id
				]
			)


		if (
			creature == null
			or not is_instance_valid(
				creature
			)
		):

			creature = create_proxy_creature(
				creature_id,
				state[
					creature_key
				]
			)


			created_now = true


		if creature == null:
			continue


		if not creature.has_method(
			"apply_network_state"
		):
			continue


		var creature_data = (
			state[
				creature_key
			]
		)


		if not (
			creature_data
			is Dictionary
		):
			continue


		creature.apply_network_state(
			creature_data,
			snap_positions
			or created_now
		)


	remove_missing_dynamic_proxies(
		expected_ids
	)


# =========================================================
# MAPA LOCAL
# =========================================================

func build_local_creature_map() -> Dictionary:

	var result: Dictionary = {}


	var creatures: Array = (
		get_tree().get_nodes_in_group(
			"network_creature"
		)
	)


	for creature in creatures:

		if creature == null:
			continue


		if not is_instance_valid(
			creature
		):
			continue


		if not creature.has_method(
			"get_network_creature_id"
		):
			continue


		var creature_id: String = str(
			creature.get_network_creature_id()
		)


		if creature_id.is_empty():
			continue


		result[
			creature_id
		] = creature


	return result


# =========================================================
# CREAR PROXY
# =========================================================

func create_proxy_creature(
	creature_id: String,
	state
):

	if not (
		state
		is Dictionary
	):

		return null


	var scene = (
		get_tree().current_scene
	)


	if scene == null:
		return null


	var creature = (
		SEA_CREATURE_SCRIPT.new()
	)


	if creature == null:
		return null


	creature.name = (
		creature_id
	)


	creature.network_creature_id = (
		creature_id
	)


	creature.network_spawned_proxy = true


	creature.show_debug_label = (
		proxy_debug_labels
	)


	if state.has(
		"max_health"
	):

		creature.max_health = float(
			state[
				"max_health"
			]
		)


	scene.add_child(
		creature
	)


	# -----------------------------------------------------
	# GRUPOS DE GAMEPLAY DEL PROXY
	#
	# El proxy ya pertenece a "network_creature"
	# mediante sea_creature.gd.
	#
	# También debe pertenecer a "damageable_creature"
	# para que sistemas locales de selección de objetivo,
	# como GameplayHUD / Turret Targeting, puedan verlo.
	#
	# IMPORTANTE:
	# El proxy sigue sin aplicar daño autoritativo.
	# Esta agrupación sólo permite localizarlo como target.
	# -----------------------------------------------------

	if not creature.is_in_group(
		"damageable_creature"
	):

		creature.add_to_group(
			"damageable_creature"
		)


	if print_proxy_events:

		print(
			"[NET CREATURE] Proxy created | ",
			creature_id,
			" | Damageable: ",
			creature.is_in_group(
				"damageable_creature"
			)
		)


	return creature


# =========================================================
# ELIMINAR PROXIES QUE YA NO EXISTEN
# =========================================================

func remove_missing_dynamic_proxies(
	expected_ids: Dictionary
):

	var creatures: Array = (
		get_tree().get_nodes_in_group(
			"network_creature"
		)
	)


	for creature in creatures:

		if creature == null:
			continue


		if not is_instance_valid(
			creature
		):
			continue


		var is_dynamic_proxy = bool(
			creature.get(
				"network_spawned_proxy"
			)
		)


		if not is_dynamic_proxy:
			continue


		if not creature.has_method(
			"get_network_creature_id"
		):
			continue


		var creature_id: String = str(
			creature.get_network_creature_id()
		)


		if expected_ids.has(
			creature_id
		):

			continue


		if print_proxy_events:

			print(
				"[NET CREATURE] Proxy removed | ",
				creature_id
			)


		creature.queue_free()


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


	if peer_id == 1:
		return


	call_deferred(
		"send_creature_snapshot",
		peer_id
	)


# =========================================================
# LATE JOIN SNAPSHOT
# =========================================================

func send_creature_snapshot(
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
		build_creature_state()
	)


	receive_creature_snapshot.rpc_id(
		peer_id,
		state
	)


	if print_snapshots:

		print(
			"[NET CREATURE] Snapshot sent | Peer ",
			peer_id,
			" | Creatures ",
			state.size()
		)
