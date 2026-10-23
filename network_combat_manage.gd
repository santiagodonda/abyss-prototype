extends Node


# =========================================================
# RECURSOS
# =========================================================

const HARPOON_PROJECTILE = preload(
	"res://harpoon_projectile.gd"
)


const SUBMARINE_PROJECTILE = preload(
	"res://submarine_projectile.gd"
)


const PERSONAL_HARPOON_AMMO_ITEM: String = (
	"harpoon_ammo"
)


# =========================================================
# DEBUG
# =========================================================

@export_group("Debug")

@export var print_combat_events: bool = true

@export var print_rejections: bool = true


# =========================================================
# PERSONAL AMMO
# =========================================================

@export_group("Personal Harpoon Ammo")

@export var harpoon_ammo_pickup_distance: float = 130.0


# =========================================================
# ESTADO
# =========================================================

var peer_cooldowns: Dictionary = {}

var next_projectile_serial: int = 1

var next_turret_projectile_serial: int = 1


# ---------------------------------------------------------
# HOST:
# Peer ID -> authoritative personal harpoon ammo.
# ---------------------------------------------------------

var peer_harpoon_ammo: Dictionary = {}


# ---------------------------------------------------------
# CLIENT:
# copia local recibida del Host.
# ---------------------------------------------------------

var local_authoritative_harpoon_ammo: int = 0

var local_authoritative_ammo_initialized: bool = false


# =========================================================
# REFERENCIAS
# =========================================================

@onready var network_interaction_manager = (
	get_node_or_null(
		"../NetworkInteractionManager"
	)
)


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


@onready var local_weapon_system = (
	get_node_or_null(
		"../Player/WeaponSystem"
	)
)


@onready var submarine_turret = (
	get_node_or_null(
		"../SubmarineTurret"
	)
)


@onready var harpoon_ammo_rack = (
	get_node_or_null(
		"../HarpoonAmmoRack"
	)
)


# =========================================================
# READY
# =========================================================

func _ready():

	add_to_group(
		"network_combat_manager"
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


	print(
		"[NET COMBAT] Manager ready"
	)


# =========================================================
# PROCESS
# =========================================================

func _process(
	delta: float
):

	# -----------------------------------------------------
	# HOST LOCAL AMMO INITIALIZATION
	# -----------------------------------------------------

	if (
		NetworkManager.is_online()
		and NetworkManager.is_host()
		and not peer_harpoon_ammo.has(
			1
		)
	):

		ensure_peer_harpoon_ammo_state(
			1
		)


	# -----------------------------------------------------
	# COOLDOWNS
	# -----------------------------------------------------

	if peer_cooldowns.is_empty():
		return


	var peers_to_remove: Array = []


	for peer_id in peer_cooldowns.keys():

		var remaining: float = (
			float(
				peer_cooldowns[
					peer_id
				]
			)
			- delta
		)


		if remaining <= 0.0:

			peers_to_remove.append(
				peer_id
			)

		else:

			peer_cooldowns[
				peer_id
			] = remaining


	for peer_id in peers_to_remove:

		peer_cooldowns.erase(
			peer_id
		)


# =========================================================
# PERSONAL AMMO - LOCAL INVENTORY
# =========================================================

func get_local_inventory():

	if local_player == null:
		return null


	if not is_instance_valid(
		local_player
	):
		return null


	return local_player.get_node_or_null(
		"Inventory"
	)


# =========================================================
# PERSONAL AMMO - MAX
# =========================================================

func get_harpoon_ammo_max_stack() -> int:

	return max(
		ItemDB.get_max_stack(
			PERSONAL_HARPOON_AMMO_ITEM
		),
		1
	)


# =========================================================
# PERSONAL AMMO - HOST INITIAL STATE
# =========================================================

func ensure_peer_harpoon_ammo_state(
	peer_id: int
) -> int:

	if peer_harpoon_ammo.has(
		peer_id
	):

		return int(
			peer_harpoon_ammo[
				peer_id
			]
		)


	var initial_ammo: int = 0


	# -----------------------------------------------------
	# HOST LOCAL:
	# su inventario local es parte del estado autoritativo.
	# -----------------------------------------------------

	if peer_id == 1:

		var inventory = (
			get_local_inventory()
		)


		if (
			inventory != null
			and inventory.has_method(
				"get_item_quantity"
			)
		):

			initial_ammo = int(
				inventory.get_item_quantity(
					PERSONAL_HARPOON_AMMO_ITEM
				)
			)


	initial_ammo = clampi(
		initial_ammo,
		0,
		get_harpoon_ammo_max_stack()
	)


	peer_harpoon_ammo[
		peer_id
	] = initial_ammo


	if peer_id == 1:

		apply_authoritative_harpoon_ammo_to_local_inventory(
			initial_ammo
		)


	if print_combat_events:

		print(
			"[NET AMMO] State created | Peer ",
			peer_id,
			" | Ammo ",
			initial_ammo
		)


	return initial_ammo


# =========================================================
# PERSONAL AMMO - HOST GET
# =========================================================

func get_peer_harpoon_ammo(
	peer_id: int
) -> int:

	if not NetworkManager.is_host():
		return 0


	return ensure_peer_harpoon_ammo_state(
		peer_id
	)


# =========================================================
# PERSONAL AMMO - HOST SET
# =========================================================

func set_peer_harpoon_ammo(
	peer_id: int,
	ammo_count: int
):

	if not NetworkManager.is_host():
		return


	var clamped_count: int = clampi(
		ammo_count,
		0,
		get_harpoon_ammo_max_stack()
	)


	peer_harpoon_ammo[
		peer_id
	] = clamped_count


	if peer_id == 1:

		local_authoritative_harpoon_ammo = (
			clamped_count
		)

		local_authoritative_ammo_initialized = true


		apply_authoritative_harpoon_ammo_to_local_inventory(
			clamped_count
		)

	else:

		receive_harpoon_ammo_state.rpc_id(
			peer_id,
			clamped_count
		)


	if print_combat_events:

		print(
			"[NET AMMO] Sync | Peer ",
			peer_id,
			" | Ammo ",
			clamped_count
		)


# =========================================================
# PERSONAL AMMO - LOCAL QUERY
# =========================================================

func get_local_authoritative_harpoon_ammo() -> int:

	if not NetworkManager.is_online():

		var inventory = (
			get_local_inventory()
		)


		if (
			inventory != null
			and inventory.has_method(
				"get_item_quantity"
			)
		):

			return int(
				inventory.get_item_quantity(
					PERSONAL_HARPOON_AMMO_ITEM
				)
			)


		return 0


	if NetworkManager.is_host():

		return ensure_peer_harpoon_ammo_state(
			1
		)


	if not local_authoritative_ammo_initialized:
		return 0


	return local_authoritative_harpoon_ammo


func has_local_authoritative_harpoon_ammo() -> bool:

	return (
		get_local_authoritative_harpoon_ammo()
		> 0
	)


# =========================================================
# PERSONAL AMMO - APPLY LOCAL INVENTORY
# =========================================================

func apply_authoritative_harpoon_ammo_to_local_inventory(
	ammo_count: int
):

	var inventory = (
		get_local_inventory()
	)


	if inventory == null:
		return


	if not inventory.has_method(
		"get_item_quantity"
	):
		return


	var target_count: int = clampi(
		ammo_count,
		0,
		get_harpoon_ammo_max_stack()
	)


	var current_count: int = int(
		inventory.get_item_quantity(
			PERSONAL_HARPOON_AMMO_ITEM
		)
	)


	if current_count < target_count:

		inventory.add_item(
			PERSONAL_HARPOON_AMMO_ITEM,
			target_count - current_count
		)


	elif current_count > target_count:

		inventory.remove_item(
			PERSONAL_HARPOON_AMMO_ITEM,
			current_count - target_count
		)


	local_authoritative_harpoon_ammo = (
		target_count
	)

	local_authoritative_ammo_initialized = true


# =========================================================
# PERSONAL AMMO - HOST -> CLIENT
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func receive_harpoon_ammo_state(
	ammo_count: int
):

	if NetworkManager.is_host():
		return


	apply_authoritative_harpoon_ammo_to_local_inventory(
		ammo_count
	)


	if print_combat_events:

		print(
			"[NET AMMO] Received | Peer ",
			multiplayer.get_unique_id(),
			" | Ammo ",
			ammo_count
		)


# =========================================================
# PERSONAL AMMO - PICKUP LOCAL
# =========================================================

func request_harpoon_ammo_pickup() -> bool:

	if not NetworkManager.is_online():
		return false


	if NetworkManager.is_host():

		return handle_harpoon_ammo_pickup(
			1
		)


	request_harpoon_ammo_pickup_from_host.rpc_id(
		1
	)


	return true


# =========================================================
# PERSONAL AMMO - CLIENT -> HOST PICKUP
# =========================================================

@rpc(
	"any_peer",
	"call_remote",
	"reliable"
)
func request_harpoon_ammo_pickup_from_host():

	if not NetworkManager.is_host():
		return


	var peer_id: int = (
		multiplayer.get_remote_sender_id()
	)


	handle_harpoon_ammo_pickup(
		peer_id
	)


# =========================================================
# PERSONAL AMMO - HOST VALIDATE PICKUP
# =========================================================

func handle_harpoon_ammo_pickup(
	peer_id: int
) -> bool:

	if not NetworkManager.is_host():
		return false


	if harpoon_ammo_rack == null:

		reject_harpoon_ammo_pickup(
			peer_id,
			"HarpoonAmmoRack missing"
		)

		return false


	if not is_instance_valid(
		harpoon_ammo_rack
	):

		reject_harpoon_ammo_pickup(
			peer_id,
			"HarpoonAmmoRack invalid"
		)

		return false


	if str(
		harpoon_ammo_rack.get(
			"item_id"
		)
	) != PERSONAL_HARPOON_AMMO_ITEM:

		reject_harpoon_ammo_pickup(
			peer_id,
			"Ammo rack item mismatch"
		)

		return false


	var shooter_position_value = (
		get_authoritative_player_position(
			peer_id
		)
	)


	if not (
		shooter_position_value is Vector2
	):

		reject_harpoon_ammo_pickup(
			peer_id,
			"Invalid player position"
		)

		return false


	var player_position: Vector2 = (
		shooter_position_value
	)


	var distance: float = (
		player_position.distance_to(
			harpoon_ammo_rack.global_position
		)
	)


	if distance > harpoon_ammo_pickup_distance:

		reject_harpoon_ammo_pickup(
			peer_id,
			"Player too far"
		)

		return false


	var quantity: int = max(
		int(
			harpoon_ammo_rack.get(
				"quantity_per_interaction"
			)
		),
		1
	)


	var current_ammo: int = (
		ensure_peer_harpoon_ammo_state(
			peer_id
		)
	)


	var max_ammo: int = (
		get_harpoon_ammo_max_stack()
	)


	if current_ammo >= max_ammo:

		reject_harpoon_ammo_pickup(
			peer_id,
			"Ammo already full"
		)

		return false


	var new_ammo: int = min(
		current_ammo + quantity,
		max_ammo
	)


	set_peer_harpoon_ammo(
		peer_id,
		new_ammo
	)


	if print_combat_events:

		print(
			"[NET AMMO][PICKUP] Peer ",
			peer_id,
			" | ",
			current_ammo,
			" -> ",
			new_ammo
		)


	return true


# =========================================================
# PERSONAL AMMO - PICKUP REJECT
# =========================================================

func reject_harpoon_ammo_pickup(
	peer_id: int,
	reason: String
):

	if print_rejections:

		print(
			"[NET AMMO][REJECT] Pickup | Peer ",
			peer_id,
			" | ",
			reason
		)


	if not NetworkManager.is_host():
		return


	var ammo_count: int = (
		ensure_peer_harpoon_ammo_state(
			peer_id
		)
	)


	if peer_id == 1:

		apply_authoritative_harpoon_ammo_to_local_inventory(
			ammo_count
		)

	else:

		receive_harpoon_ammo_state.rpc_id(
			peer_id,
			ammo_count
		)


# =========================================================
# PLAYER HARPOON - REQUEST LOCAL
# =========================================================

func request_player_fire(
	target_position: Vector2,
	requested_weapon_id: String
) -> bool:

	if not NetworkManager.is_online():
		return false


	if requested_weapon_id.is_empty():
		return false


	if NetworkManager.is_host():

		return handle_player_fire_request(
			1,
			target_position,
			requested_weapon_id
		)


	request_player_fire_from_host.rpc_id(
		1,
		target_position,
		requested_weapon_id
	)


	return true


# =========================================================
# PLAYER HARPOON - CLIENT -> HOST
# =========================================================

@rpc(
	"any_peer",
	"call_remote",
	"reliable"
)
func request_player_fire_from_host(
	target_position: Vector2,
	requested_weapon_id: String
):

	if not NetworkManager.is_host():
		return


	var peer_id: int = (
		multiplayer.get_remote_sender_id()
	)


	handle_player_fire_request(
		peer_id,
		target_position,
		requested_weapon_id
	)


# =========================================================
# PLAYER HARPOON - VALIDAR / EJECUTAR
# =========================================================

func handle_player_fire_request(
	peer_id: int,
	target_position: Vector2,
	requested_weapon_id: String
) -> bool:

	if not NetworkManager.is_host():
		return false


	if network_interaction_manager == null:

		reject_fire(
			peer_id,
			"NetworkInteractionManager missing"
		)

		return false


	if not network_interaction_manager.has_method(
		"get_player_position"
	):

		reject_fire(
			peer_id,
			"Player position API missing"
		)

		return false


	if not network_interaction_manager.has_method(
		"get_player_tool_id"
	):

		reject_fire(
			peer_id,
			"Player tool API missing"
		)

		return false


	var authoritative_weapon_id: String = str(
		network_interaction_manager.get_player_tool_id(
			peer_id
		)
	)


	if authoritative_weapon_id.is_empty():

		reject_fire(
			peer_id,
			"No equipped weapon"
		)

		return false


	if (
		authoritative_weapon_id
		!= requested_weapon_id
	):

		reject_fire(
			peer_id,
			"Weapon mismatch"
		)

		return false


	var weapon_type: String = str(
		ItemDB.get_property(
			authoritative_weapon_id,
			"weapon_type",
			""
		)
	)


	if weapon_type != "projectile":

		reject_fire(
			peer_id,
			"Invalid weapon type"
		)

		return false


	var ammo_item: String = str(
		ItemDB.get_property(
			authoritative_weapon_id,
			"ammo_item",
			""
		)
	)


	if ammo_item.is_empty():

		reject_fire(
			peer_id,
			"Weapon has no ammo definition"
		)

		return false


	if ammo_item != PERSONAL_HARPOON_AMMO_ITEM:

		reject_fire(
			peer_id,
			"Unsupported personal ammo item"
		)

		return false


	# -----------------------------------------------------
	# AMMO AUTORITATIVO
	# -----------------------------------------------------

	var current_ammo: int = (
		ensure_peer_harpoon_ammo_state(
			peer_id
		)
	)


	if current_ammo <= 0:

		reject_fire(
			peer_id,
			"No authoritative ammo"
		)

		return false


	if peer_cooldowns.has(
		peer_id
	):

		reject_fire(
			peer_id,
			"Cooldown"
		)

		return false


	var shooter_position_value = (
		get_authoritative_player_position(
			peer_id
		)
	)


	if not (
		shooter_position_value
		is Vector2
	):

		reject_fire(
			peer_id,
			"Invalid player position"
		)

		return false


	var shooter_position: Vector2 = (
		shooter_position_value
	)


	var direction: Vector2 = (
		shooter_position.direction_to(
			target_position
		)
	)


	if direction.length_squared() <= 0.0001:

		reject_fire(
			peer_id,
			"Invalid direction"
		)

		return false


	var damage: float = (
		ItemDB.get_float_property(
			authoritative_weapon_id,
			"damage",
			0.0
		)
	)


	var projectile_speed: float = (
		ItemDB.get_float_property(
			authoritative_weapon_id,
			"projectile_speed",
			400.0
		)
	)


	var projectile_range: float = (
		ItemDB.get_float_property(
			authoritative_weapon_id,
			"projectile_range",
			500.0
		)
	)


	var fire_cooldown: float = (
		ItemDB.get_float_property(
			authoritative_weapon_id,
			"fire_cooldown",
			1.0
		)
	)


	if damage <= 0.0:

		reject_fire(
			peer_id,
			"Invalid damage"
		)

		return false


	if projectile_speed <= 0.0:

		reject_fire(
			peer_id,
			"Invalid projectile speed"
		)

		return false


	if projectile_range <= 0.0:

		reject_fire(
			peer_id,
			"Invalid projectile range"
		)

		return false


	if fire_cooldown < 0.0:

		fire_cooldown = 0.0


	var projectile_id: String = (
		"Harpoon_"
		+ str(
			next_projectile_serial
		)
	)


	next_projectile_serial += 1


	var start_position: Vector2 = (
		shooter_position
		+ direction
		* 24.0
	)


	var projectile = (
		create_authoritative_harpoon_projectile(
			projectile_id,
			peer_id,
			start_position,
			direction,
			projectile_speed,
			projectile_range,
			damage
		)
	)


	if projectile == null:

		reject_fire(
			peer_id,
			"Projectile creation failed"
		)

		return false


	# -----------------------------------------------------
	# Sólo después de crear correctamente el proyectil
	# consumimos la munición autoritativa.
	# -----------------------------------------------------

	set_peer_harpoon_ammo(
		peer_id,
		current_ammo - 1
	)


	peer_cooldowns[
		peer_id
	] = fire_cooldown


	receive_harpoon_projectile_spawn.rpc(
		projectile_id,
		peer_id,
		start_position,
		direction,
		projectile_speed,
		projectile_range,
		damage
	)


	if (
		peer_id == 1
		and local_weapon_system != null
		and local_weapon_system.has_method(
			"register_network_projectile"
		)
	):

		local_weapon_system.register_network_projectile(
			projectile
		)


	if print_combat_events:

		print(
			"[NET COMBAT][OK] Fire | Peer ",
			peer_id,
			" | Weapon ",
			authoritative_weapon_id,
			" | Projectile ",
			projectile_id,
			" | Ammo ",
			current_ammo - 1,
			" | Position ",
			shooter_position
		)


	return true


# =========================================================
# PLAYER HARPOON - POSICIÓN AUTORITATIVA
# =========================================================

func get_authoritative_player_position(
	peer_id: int
):

	if network_interaction_manager != null:

		if network_interaction_manager.has_method(
			"get_player_position"
		):

			var position_result = (
				network_interaction_manager.get_player_position(
					peer_id
				)
			)


			if position_result is Vector2:

				return position_result


			if position_result is Dictionary:

				var position_data: Dictionary = (
					position_result
				)


				if bool(
					position_data.get(
						"valid",
						false
					)
				):

					var position_value = (
						position_data.get(
							"position",
							null
						)
					)


					if position_value is Vector2:

						return position_value


	# Host local fallback.
	if (
		peer_id == 1
		and local_player != null
		and is_instance_valid(
			local_player
		)
	):

		return local_player.global_position


	return null


# =========================================================
# PLAYER HARPOON - CREAR HOST
# =========================================================

func create_authoritative_harpoon_projectile(
	projectile_id: String,
	peer_id: int,
	start_position: Vector2,
	direction: Vector2,
	projectile_speed: float,
	projectile_range: float,
	damage: float
):

	var scene = (
		get_tree().current_scene
	)


	if scene == null:
		return null


	var projectile = (
		HARPOON_PROJECTILE.new()
	)


	if projectile == null:
		return null


	projectile.name = (
		projectile_id
	)


	scene.add_child(
		projectile
	)


	projectile.setup(
		start_position,
		direction,
		projectile_speed,
		projectile_range,
		damage,
		get_source_actor(
			peer_id
		)
	)


	if projectile.has_method(
		"set_network_context"
	):

		projectile.set_network_context(
			projectile_id,
			true
		)


	return projectile


# =========================================================
# PLAYER HARPOON - SPAWN CLIENT
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func receive_harpoon_projectile_spawn(
	projectile_id: String,
	shooter_peer_id: int,
	start_position: Vector2,
	direction: Vector2,
	projectile_speed: float,
	projectile_range: float,
	damage: float
):

	if NetworkManager.is_restart_in_progress():
		return


	if NetworkManager.is_host():
		return


	if find_network_projectile(
		projectile_id
	) != null:

		return


	var scene = (
		get_tree().current_scene
	)


	if scene == null:
		return


	var projectile = (
		HARPOON_PROJECTILE.new()
	)


	if projectile == null:
		return


	projectile.name = (
		projectile_id
	)


	scene.add_child(
		projectile
	)


	projectile.setup(
		start_position,
		direction,
		projectile_speed,
		projectile_range,
		damage,
		get_source_actor(
			shooter_peer_id
		)
	)


	if projectile.has_method(
		"set_network_context"
	):

		projectile.set_network_context(
			projectile_id,
			false
		)


	if (
		shooter_peer_id
		== multiplayer.get_unique_id()
		and local_weapon_system != null
		and local_weapon_system.has_method(
			"register_network_projectile"
		)
	):

		local_weapon_system.register_network_projectile(
			projectile
		)


# =========================================================
# PLAYER HARPOON - FIRE REJECTION CLIENT
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func receive_player_fire_rejection(
	reason: String,
	ammo_count: int
):

	if NetworkManager.is_host():
		return


	apply_authoritative_harpoon_ammo_to_local_inventory(
		ammo_count
	)


	if (
		local_weapon_system != null
		and local_weapon_system.has_method(
			"notify_network_fire_rejected"
		)
	):

		local_weapon_system.notify_network_fire_rejected(
			reason
		)


# =========================================================
# TURRET - REQUEST LOCAL
# =========================================================

func request_turret_fire(
	target_position: Vector2
) -> bool:

	if not NetworkManager.is_online():
		return false


	if NetworkManager.is_host():

		return handle_turret_fire_request(
			1,
			target_position
		)


	request_turret_fire_from_host.rpc_id(
		1,
		target_position
	)


	return true


# =========================================================
# TURRET - CLIENT -> HOST
# =========================================================

@rpc(
	"any_peer",
	"call_remote",
	"reliable"
)
func request_turret_fire_from_host(
	target_position: Vector2
):

	if not NetworkManager.is_host():
		return


	var peer_id: int = (
		multiplayer.get_remote_sender_id()
	)


	handle_turret_fire_request(
		peer_id,
		target_position
	)


# =========================================================
# TURRET - HOST VALIDA / EJECUTA
# =========================================================

func handle_turret_fire_request(
	peer_id: int,
	target_position: Vector2
) -> bool:

	if not NetworkManager.is_host():
		return false


	if submarine_turret == null:

		reject_turret_fire(
			peer_id,
			"Turret missing"
		)

		return false


	if not is_instance_valid(
		submarine_turret
	):

		reject_turret_fire(
			peer_id,
			"Turret invalid"
		)

		return false


	if not submarine_turret.has_method(
		"build_authoritative_fire_data"
	):

		reject_turret_fire(
			peer_id,
			"Turret fire API missing"
		)

		return false


	if not submarine_turret.has_method(
		"commit_authoritative_fire"
	):

		reject_turret_fire(
			peer_id,
			"Turret commit API missing"
		)

		return false


	var fire_data: Dictionary = (
		submarine_turret.build_authoritative_fire_data(
			target_position
		)
	)


	if not bool(
		fire_data.get(
			"valid",
			false
		)
	):

		reject_turret_fire(
			peer_id,
			str(
				fire_data.get(
					"reason",
					"Rejected"
				)
			)
		)

		return false


	var projectile_id: String = (
		"Turret_"
		+ str(
			next_turret_projectile_serial
		)
	)


	next_turret_projectile_serial += 1


	var start_position: Vector2 = (
		fire_data[
			"start_position"
		]
	)


	var direction: Vector2 = (
		fire_data[
			"direction"
		]
	)


	var turret_projectile_speed: float = float(
		fire_data[
			"projectile_speed"
		]
	)


	var turret_projectile_range: float = float(
		fire_data[
			"projectile_range"
		]
	)


	var turret_damage: float = float(
		fire_data[
			"damage"
		]
	)


	var projectile = (
		create_authoritative_turret_projectile(
			projectile_id,
			start_position,
			direction,
			turret_projectile_speed,
			turret_projectile_range,
			turret_damage
		)
	)


	if projectile == null:

		reject_turret_fire(
			peer_id,
			"Projectile creation failed"
		)

		return false


	var committed: bool = (
		submarine_turret.commit_authoritative_fire()
	)


	if not committed:

		projectile.queue_free()


		reject_turret_fire(
			peer_id,
			"Turret state commit failed"
		)

		return false


	if submarine_turret.has_method(
		"register_network_projectile"
	):

		submarine_turret.register_network_projectile(
			projectile
		)


	receive_turret_projectile_spawn.rpc(
		projectile_id,
		start_position,
		direction,
		turret_projectile_speed,
		turret_projectile_range,
		turret_damage
	)


	broadcast_turret_state()


	if print_combat_events:

		print(
			"[NET COMBAT][OK] Turret fire | Peer ",
			peer_id,
			" | Projectile ",
			projectile_id,
			" | Ammo ",
			submarine_turret.get_ammo()
		)


	return true


# =========================================================
# TURRET - CREAR PROYECTIL HOST
# =========================================================

func create_authoritative_turret_projectile(
	projectile_id: String,
	start_position: Vector2,
	direction: Vector2,
	projectile_speed: float,
	projectile_range: float,
	damage: float
):

	var scene = (
		get_tree().current_scene
	)


	if scene == null:
		return null


	var projectile = (
		SUBMARINE_PROJECTILE.new()
	)


	if projectile == null:
		return null


	projectile.name = (
		projectile_id
	)


	scene.add_child(
		projectile
	)


	projectile.setup(
		start_position,
		direction,
		projectile_speed,
		projectile_range,
		damage,
		submarine_turret
	)


	if projectile.has_method(
		"set_network_context"
	):

		projectile.set_network_context(
			projectile_id,
			true
		)


	return projectile


# =========================================================
# TURRET - SPAWN CLIENT
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func receive_turret_projectile_spawn(
	projectile_id: String,
	start_position: Vector2,
	direction: Vector2,
	projectile_speed: float,
	projectile_range: float,
	damage: float
):

	if NetworkManager.is_restart_in_progress():
		return


	if NetworkManager.is_host():
		return


	if find_network_projectile(
		projectile_id
	) != null:

		return


	var scene = (
		get_tree().current_scene
	)


	if scene == null:
		return


	var projectile = (
		SUBMARINE_PROJECTILE.new()
	)


	if projectile == null:
		return


	projectile.name = (
		projectile_id
	)


	scene.add_child(
		projectile
	)


	projectile.setup(
		start_position,
		direction,
		projectile_speed,
		projectile_range,
		damage,
		submarine_turret
	)


	if projectile.has_method(
		"set_network_context"
	):

		projectile.set_network_context(
			projectile_id,
			false
		)


	if (
		submarine_turret != null
		and submarine_turret.has_method(
			"register_network_projectile"
		)
	):

		submarine_turret.register_network_projectile(
			projectile
		)


# =========================================================
# TURRET - ESTADO
# =========================================================

func broadcast_turret_state():

	if not NetworkManager.is_online():
		return


	if not NetworkManager.is_host():
		return


	if submarine_turret == null:
		return


	receive_turret_state.rpc(
		submarine_turret.get_ammo(),
		submarine_turret.get_cooldown_remaining()
	)


# =========================================================
# TURRET - HOST -> CLIENT
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func receive_turret_state(
	ammo_count: int,
	cooldown_remaining: float
):

	if NetworkManager.is_host():
		return


	if submarine_turret == null:
		return


	if not submarine_turret.has_method(
		"apply_network_state"
	):

		return


	submarine_turret.apply_network_state(
		ammo_count,
		cooldown_remaining
	)


# =========================================================
# PROYECTIL - DESPAWN GENÉRICO
# =========================================================

func broadcast_projectile_despawn(
	projectile_id: String
):

	if projectile_id.is_empty():
		return


	if not NetworkManager.is_online():
		return


	if not NetworkManager.is_host():
		return


	receive_projectile_despawn.rpc(
		projectile_id
	)


# =========================================================
# PROYECTIL - RPC DESPAWN
# =========================================================

@rpc(
	"authority",
	"call_remote",
	"reliable"
)
func receive_projectile_despawn(
	projectile_id: String
):

	if NetworkManager.is_host():
		return


	var projectile = (
		find_network_projectile(
			projectile_id
		)
	)


	if projectile == null:
		return


	projectile.queue_free()


# =========================================================
# PROYECTIL - BUSCAR
# =========================================================

func find_network_projectile(
	projectile_id: String
):

	var projectiles: Array = (
		get_tree().get_nodes_in_group(
			"network_projectile"
		)
	)


	for projectile in projectiles:

		if projectile == null:
			continue


		if not is_instance_valid(
			projectile
		):

			continue


		if str(
			projectile.get(
				"network_projectile_id"
			)
		) == projectile_id:

			return projectile


	return null


# =========================================================
# PLAYER SOURCE ACTOR
# =========================================================

func get_source_actor(
	peer_id: int
):

	if peer_id == 1:

		return local_player


	if network_player_manager == null:
		return null


	if not network_player_manager.has_method(
		"get_remote_player"
	):

		return null


	return network_player_manager.get_remote_player(
		peer_id
	)


# =========================================================
# PLAYER CONNECTED
# =========================================================

func _on_player_connected(
	peer_id: int
):

	if not NetworkManager.is_host():
		return


	if peer_id == 1:
		return


	# -----------------------------------------------------
	# Un nuevo Peer comienza con ammo personal 0.
	#
	# No confiamos en el Inventory que el Client pudiera
	# haber tenido antes de conectarse.
	# -----------------------------------------------------

	peer_harpoon_ammo[
		peer_id
	] = 0


	call_deferred(
		"send_turret_state_to_peer",
		peer_id
	)


	call_deferred(
		"send_harpoon_ammo_state_to_peer",
		peer_id
	)


# =========================================================
# PLAYER DISCONNECTED
# =========================================================

func _on_player_disconnected(
	peer_id: int
):

	if not NetworkManager.is_host():
		return


	peer_cooldowns.erase(
		peer_id
	)


	peer_harpoon_ammo.erase(
		peer_id
	)


# =========================================================
# PERSONAL AMMO SNAPSHOT
# =========================================================

func send_harpoon_ammo_state_to_peer(
	peer_id: int
):

	await get_tree().process_frame

	await get_tree().process_frame


	if not NetworkManager.is_online():
		return


	if not NetworkManager.is_host():
		return


	if not peer_harpoon_ammo.has(
		peer_id
	):

		peer_harpoon_ammo[
			peer_id
		] = 0


	var ammo_count: int = int(
		peer_harpoon_ammo[
			peer_id
		]
	)


	receive_harpoon_ammo_state.rpc_id(
		peer_id,
		ammo_count
	)


	if print_combat_events:

		print(
			"[NET AMMO] Snapshot sent | Peer ",
			peer_id,
			" | Ammo ",
			ammo_count
		)


# =========================================================
# TURRET SNAPSHOT
# =========================================================

func send_turret_state_to_peer(
	peer_id: int
):

	await get_tree().process_frame

	await get_tree().process_frame


	if not NetworkManager.is_host():
		return


	if submarine_turret == null:
		return


	receive_turret_state.rpc_id(
		peer_id,
		submarine_turret.get_ammo(),
		submarine_turret.get_cooldown_remaining()
	)


	if print_combat_events:

		print(
			"[NET COMBAT] Turret snapshot sent | Peer ",
			peer_id,
			" | Ammo ",
			submarine_turret.get_ammo()
		)


# =========================================================
# REJECTIONS
# =========================================================

func reject_fire(
	peer_id: int,
	reason: String
):

	if print_rejections:

		print(
			"[NET COMBAT][REJECT] Fire | Peer ",
			peer_id,
			" | ",
			reason
		)


	if not NetworkManager.is_host():
		return


	if peer_id == 1:
		return


	var ammo_count: int = (
		ensure_peer_harpoon_ammo_state(
			peer_id
		)
	)


	receive_player_fire_rejection.rpc_id(
		peer_id,
		reason,
		ammo_count
	)


func reject_turret_fire(
	peer_id: int,
	reason: String
):

	if not print_rejections:
		return


	print(
		"[NET COMBAT][REJECT] Turret fire | Peer ",
		peer_id,
		" | ",
		reason
	)
