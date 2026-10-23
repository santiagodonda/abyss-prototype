extends Node


signal projectile_fired(
	projectile
)

signal weapon_fired(
	weapon_id: String
)


# =========================================================
# CONFIGURACIÓN DEBUG
# =========================================================

@export_group("Debug")

@export var print_weapon_network_debug: bool = true


# =========================================================
# REFERENCIAS
# =========================================================

@onready var player = (
	get_parent()
)


@onready var inventory = (
	get_node_or_null(
		"../Inventory"
	)
)


@onready var equipment = (
	get_node_or_null(
		"../Equipment"
	)
)


var network_combat_manager = null


# =========================================================
# PROYECTIL
# =========================================================

const HARPOON_PROJECTILE = preload(
	"res://harpoon_projectile.gd"
)


# =========================================================
# ESTADO
# =========================================================

var cooldown_remaining: float = 0.0

var last_projectile: Node = null


# ---------------------------------------------------------
# ONLINE
#
# Un Client ya no consume munición localmente antes
# de recibir autorización del Host.
# ---------------------------------------------------------

var network_fire_request_pending: bool = false

var pending_weapon_id: String = ""

var pending_fire_cooldown: float = 0.0


# =========================================================
# READY
# =========================================================

func _ready():

	if inventory == null:

		push_error(
			"WeaponSystem: Inventory no encontrado."
		)


	if equipment == null:

		push_error(
			"WeaponSystem: Equipment no encontrado."
		)


	call_deferred(
		"resolve_network_combat_manager"
	)


	if print_weapon_network_debug:

		print(
			"[WEAPON] Ready | Peer ",
			get_local_peer_id_safe()
		)


# =========================================================
# RESOLVER NETWORK COMBAT MANAGER
# =========================================================

func resolve_network_combat_manager():

	if (
		network_combat_manager != null
		and is_instance_valid(
			network_combat_manager
		)
	):

		return network_combat_manager


	network_combat_manager = null


	var scene = (
		get_tree().current_scene
	)


	if scene != null:

		var scene_candidate = (
			scene.get_node_or_null(
				"NetworkCombatManager"
			)
		)


		if (
			scene_candidate != null
			and is_instance_valid(
				scene_candidate
			)
		):

			network_combat_manager = (
				scene_candidate
			)


			if print_weapon_network_debug:

				print(
					"[WEAPON NET] CombatManager resolved from scene"
				)


			return network_combat_manager


	var managers: Array = (
		get_tree().get_nodes_in_group(
			"network_combat_manager"
		)
	)


	if not managers.is_empty():

		var group_candidate = (
			managers[0]
		)


		if (
			group_candidate != null
			and is_instance_valid(
				group_candidate
			)
		):

			network_combat_manager = (
				group_candidate
			)


			if print_weapon_network_debug:

				print(
					"[WEAPON NET] CombatManager resolved by group"
				)


			return network_combat_manager


	var relative_candidate = (
		get_node_or_null(
			"../../NetworkCombatManager"
		)
	)


	if (
		relative_candidate != null
		and is_instance_valid(
			relative_candidate
		)
	):

		network_combat_manager = (
			relative_candidate
		)


		if print_weapon_network_debug:

			print(
				"[WEAPON NET] CombatManager resolved by relative path"
			)


	return network_combat_manager


# =========================================================
# PROCESS
# =========================================================

func _process(
	delta: float
):

	cooldown_remaining = max(
		cooldown_remaining - delta,
		0.0
	)


# =========================================================
# DISPARO
# =========================================================

func fire_at(
	target_position: Vector2
) -> bool:

	if print_weapon_network_debug:

		print(
			"[WEAPON][FIRE INPUT] Peer ",
			get_local_peer_id_safe(),
			" | Online: ",
			NetworkManager.is_online(),
			" | Target: ",
			target_position
		)


	if NetworkManager.is_online():

		return fire_networked(
			target_position
		)


	return fire_offline(
		target_position
	)


# =========================================================
# DISPARO OFFLINE
# =========================================================

func fire_offline(
	target_position: Vector2
) -> bool:

	if inventory == null:
		return false


	if equipment == null:
		return false


	if cooldown_remaining > 0.0:
		return false


	var weapon_id: String = (
		equipment.get_equipped_tool()
	)


	if weapon_id.is_empty():
		return false


	var weapon_type: String = str(
		ItemDB.get_property(
			weapon_id,
			"weapon_type",
			""
		)
	)


	if weapon_type != "projectile":
		return false


	var ammo_item: String = str(
		ItemDB.get_property(
			weapon_id,
			"ammo_item",
			""
		)
	)


	if ammo_item.is_empty():
		return false


	if not inventory.has_item(
		ammo_item,
		1
	):
		return false


	var direction: Vector2 = (
		player.global_position.direction_to(
			target_position
		)
	)


	if direction.length_squared() <= 0.0001:
		return false


	var damage: float = (
		ItemDB.get_float_property(
			weapon_id,
			"damage",
			0.0
		)
	)


	var projectile_speed: float = (
		ItemDB.get_float_property(
			weapon_id,
			"projectile_speed",
			400.0
		)
	)


	var projectile_range: float = (
		ItemDB.get_float_property(
			weapon_id,
			"projectile_range",
			500.0
		)
	)


	var fire_cooldown: float = (
		ItemDB.get_float_property(
			weapon_id,
			"fire_cooldown",
			1.0
		)
	)


	var ammo_removed: bool = (
		inventory.remove_item(
			ammo_item,
			1
		)
	)


	if not ammo_removed:
		return false


	var projectile = (
		HARPOON_PROJECTILE.new()
	)


	var scene = (
		get_tree().current_scene
	)


	if scene == null:

		inventory.add_item(
			ammo_item,
			1
		)

		projectile.queue_free()

		return false


	scene.add_child(
		projectile
	)


	projectile.setup(
		player.global_position
		+ direction
		* 24.0,
		direction,
		projectile_speed,
		projectile_range,
		damage,
		player
	)


	last_projectile = projectile


	cooldown_remaining = (
		fire_cooldown
	)


	projectile_fired.emit(
		projectile
	)


	weapon_fired.emit(
		weapon_id
	)


	return true


# =========================================================
# DISPARO MULTIPLAYER
# =========================================================

func fire_networked(
	target_position: Vector2
) -> bool:

	var peer_id: int = (
		get_local_peer_id_safe()
	)


	if print_weapon_network_debug:

		print(
			"[WEAPON NET][START] Peer ",
			peer_id
		)


	if inventory == null:

		debug_network_reject(
			"Inventory missing"
		)

		return false


	if equipment == null:

		debug_network_reject(
			"Equipment missing"
		)

		return false


	var combat_manager = (
		resolve_network_combat_manager()
	)


	if combat_manager == null:

		debug_network_reject(
			"NetworkCombatManager missing"
		)

		return false


	if cooldown_remaining > 0.0:

		debug_network_reject(
			"Local cooldown "
			+ str(
				cooldown_remaining
			)
		)

		return false


	if network_fire_request_pending:

		debug_network_reject(
			"Fire request already pending"
		)

		return false


	var weapon_id: String = (
		equipment.get_equipped_tool()
	)


	if print_weapon_network_debug:

		print(
			"[WEAPON NET][TOOL] Peer ",
			peer_id,
			" | ",
			weapon_id
		)


	if weapon_id.is_empty():

		debug_network_reject(
			"No equipped tool"
		)

		return false


	var weapon_type: String = str(
		ItemDB.get_property(
			weapon_id,
			"weapon_type",
			""
		)
	)


	if print_weapon_network_debug:

		print(
			"[WEAPON NET][TYPE] ",
			weapon_type
		)


	if weapon_type != "projectile":

		debug_network_reject(
			"Weapon type is not projectile"
		)

		return false


	var ammo_item: String = str(
		ItemDB.get_property(
			weapon_id,
			"ammo_item",
			""
		)
	)


	if print_weapon_network_debug:

		print(
			"[WEAPON NET][AMMO ITEM] ",
			ammo_item
		)


	if ammo_item.is_empty():

		debug_network_reject(
			"Ammo item definition missing"
		)

		return false


	# -----------------------------------------------------
	# AMMO AUTORITATIVO
	#
	# Online NO consumimos inventory local.
	# Consultamos el estado replicado por Host.
	# -----------------------------------------------------

	if not combat_manager.has_method(
		"has_local_authoritative_harpoon_ammo"
	):

		debug_network_reject(
			"Authoritative ammo API missing"
		)

		return false


	var has_ammo: bool = bool(
		combat_manager.has_local_authoritative_harpoon_ammo()
	)


	if print_weapon_network_debug:

		print(
			"[WEAPON NET][AUTH AMMO] ",
			combat_manager.get_local_authoritative_harpoon_ammo()
		)


	if not has_ammo:

		debug_network_reject(
			"No authoritative ammo"
		)

		return false


	var direction: Vector2 = (
		player.global_position.direction_to(
			target_position
		)
	)


	if direction.length_squared() <= 0.0001:

		debug_network_reject(
			"Invalid fire direction"
		)

		return false


	var fire_cooldown: float = (
		ItemDB.get_float_property(
			weapon_id,
			"fire_cooldown",
			1.0
		)
	)


	# -----------------------------------------------------
	# PENDING
	#
	# Cooldown y weapon_fired se confirman únicamente
	# cuando llega el proyectil autorizado por Host.
	# -----------------------------------------------------

	network_fire_request_pending = true

	pending_weapon_id = weapon_id

	pending_fire_cooldown = fire_cooldown


	if print_weapon_network_debug:

		print(
			"[WEAPON NET][REQUEST] Peer ",
			peer_id,
			" | Weapon ",
			weapon_id,
			" | Target ",
			target_position
		)


	var request_sent: bool = bool(
		combat_manager.request_player_fire(
			target_position,
			weapon_id
		)
	)


	if print_weapon_network_debug:

		print(
			"[WEAPON NET][REQUEST RESULT] ",
			request_sent
		)


	if not request_sent:

		clear_pending_network_fire()


		debug_network_reject(
			"Combat manager rejected request"
		)

		return false


	return true


# =========================================================
# PROYECTIL CONFIRMADO POR RED
# =========================================================

func register_network_projectile(
	projectile
):

	if projectile == null:
		return


	if not is_instance_valid(
		projectile
	):
		return


	last_projectile = projectile


	projectile_fired.emit(
		projectile
	)


	# -----------------------------------------------------
	# Sólo el proyectil autorizado confirma el disparo.
	# -----------------------------------------------------

	if not pending_weapon_id.is_empty():

		cooldown_remaining = max(
			pending_fire_cooldown,
			0.0
		)


		weapon_fired.emit(
			pending_weapon_id
		)


	clear_pending_network_fire()


	if print_weapon_network_debug:

		print(
			"[WEAPON NET][PROJECTILE CONFIRMED] Peer ",
			get_local_peer_id_safe(),
			" | ",
			projectile.name
		)


# =========================================================
# FIRE REJECTED BY HOST
# =========================================================

func notify_network_fire_rejected(
	reason: String
):

	clear_pending_network_fire()


	if print_weapon_network_debug:

		print(
			"[WEAPON NET][HOST REJECT] Peer ",
			get_local_peer_id_safe(),
			" | ",
			reason
		)


func clear_pending_network_fire():

	network_fire_request_pending = false

	pending_weapon_id = ""

	pending_fire_cooldown = 0.0


# =========================================================
# DEBUG NETWORK
# =========================================================

func debug_network_reject(
	reason: String
):

	if not print_weapon_network_debug:
		return


	print(
		"[WEAPON NET][LOCAL REJECT] Peer ",
		get_local_peer_id_safe(),
		" | ",
		reason
	)


func get_local_peer_id_safe() -> int:

	if not NetworkManager.is_online():
		return 0


	var multiplayer_api = (
		get_multiplayer()
	)


	if multiplayer_api == null:
		return 0


	return multiplayer_api.get_unique_id()


# =========================================================
# CONSULTAS
# =========================================================

func can_fire() -> bool:

	if inventory == null:
		return false


	if equipment == null:
		return false


	if cooldown_remaining > 0.0:
		return false


	if (
		NetworkManager.is_online()
		and network_fire_request_pending
	):
		return false


	var weapon_id: String = (
		equipment.get_equipped_tool()
	)


	if weapon_id.is_empty():
		return false


	if str(
		ItemDB.get_property(
			weapon_id,
			"weapon_type",
			""
		)
	) != "projectile":

		return false


	var ammo_item: String = str(
		ItemDB.get_property(
			weapon_id,
			"ammo_item",
			""
		)
	)


	if ammo_item.is_empty():
		return false


	if NetworkManager.is_online():

		var combat_manager = (
			resolve_network_combat_manager()
		)


		if combat_manager == null:
			return false


		if not combat_manager.has_method(
			"has_local_authoritative_harpoon_ammo"
		):
			return false


		return bool(
			combat_manager.has_local_authoritative_harpoon_ammo()
		)


	return inventory.has_item(
		ammo_item,
		1
	)


func get_cooldown_remaining() -> float:

	return cooldown_remaining


func get_last_projectile():

	return last_projectile


func is_network_fire_pending() -> bool:

	return network_fire_request_pending
