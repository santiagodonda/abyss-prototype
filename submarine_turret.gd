extends Node2D


signal fired

signal ammo_changed(
	current_ammo: int
)


# =========================================================
# PROYECTIL
# =========================================================

const SUBMARINE_PROJECTILE = preload(
	"res://submarine_projectile.gd"
)


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("Weapon")

@export var damage: float = 25.0

@export var fire_cooldown: float = 0.60

@export var projectile_speed: float = 650.0

@export var projectile_range: float = 900.0


@export_group("Ammo")

@export var max_ammo: int = 12

@export var starting_ammo: int = 12


@export_group("Power")

@export var power_system_path: NodePath = (
	NodePath("../PowerSystem")
)


@export_group("Debug")

@export var show_debug_label: bool = true


# =========================================================
# ESTADO
# =========================================================

var ammo_count: int = 0

var cooldown_remaining: float = 0.0

var last_projectile = null

var network_combat_manager = null


# =========================================================
# REFERENCIAS
# =========================================================

@onready var power_system = (
	get_node_or_null(
		power_system_path
	)
)


# =========================================================
# DEBUG
# =========================================================

var debug_label: Label


# =========================================================
# READY
# =========================================================

func _ready():

	add_to_group(
		"submarine_weapon"
	)


	ammo_count = int(
		clamp(
			starting_ammo,
			0,
			max_ammo
		)
	)


	if show_debug_label:

		create_debug_label()


	update_debug_label()

	queue_redraw()


	call_deferred(
		"resolve_network_combat_manager"
	)


# =========================================================
# NETWORK COMBAT MANAGER
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


	var managers: Array = (
		get_tree().get_nodes_in_group(
			"network_combat_manager"
		)
	)


	if not managers.is_empty():

		var candidate = (
			managers[0]
		)


		if (
			candidate != null
			and is_instance_valid(
				candidate
			)
		):

			network_combat_manager = (
				candidate
			)


			return network_combat_manager


	var scene = (
		get_tree().current_scene
	)


	if scene != null:

		var candidate = (
			scene.get_node_or_null(
				"NetworkCombatManager"
			)
		)


		if candidate != null:

			network_combat_manager = (
				candidate
			)


	return network_combat_manager


# =========================================================
# PROCESS
# =========================================================

func _process(
	delta: float
):

	if cooldown_remaining > 0.0:

		cooldown_remaining = max(
			cooldown_remaining - delta,
			0.0
		)


	update_debug_label()


# =========================================================
# ENERGÍA
# =========================================================

func has_power() -> bool:

	if power_system == null:
		return false


	if not power_system.has_method(
		"has_power"
	):

		return false


	return power_system.has_power()


# =========================================================
# PUEDE DISPARAR
# =========================================================

func can_fire() -> bool:

	if not has_power():
		return false


	if ammo_count <= 0:
		return false


	if cooldown_remaining > 0.0:
		return false


	return true


# =========================================================
# DISPARAR
# =========================================================

func fire_at(
	target_position: Vector2
) -> bool:

	# -----------------------------------------------------
	# MULTIPLAYER
	#
	# El Host será el único que valida y ejecuta.
	# -----------------------------------------------------

	if NetworkManager.is_online():

		var combat_manager = (
			resolve_network_combat_manager()
		)


		if combat_manager == null:
			return false


		if not combat_manager.has_method(
			"request_turret_fire"
		):

			return false


		return combat_manager.request_turret_fire(
			target_position
		)


	# -----------------------------------------------------
	# OFFLINE
	# -----------------------------------------------------

	return fire_offline(
		target_position
	)


# =========================================================
# DISPARO OFFLINE
# =========================================================

func fire_offline(
	target_position: Vector2
) -> bool:

	var fire_data: Dictionary = (
		build_authoritative_fire_data(
			target_position
		)
	)


	if not bool(
		fire_data.get(
			"valid",
			false
		)
	):

		return false


	var projectile = (
		SUBMARINE_PROJECTILE.new()
	)


	var scene = (
		get_tree().current_scene
	)


	if scene == null:

		projectile.queue_free()

		return false


	scene.add_child(
		projectile
	)


	projectile.setup(
		fire_data[
			"start_position"
		],
		fire_data[
			"direction"
		],
		fire_data[
			"projectile_speed"
		],
		fire_data[
			"projectile_range"
		],
		fire_data[
			"damage"
		],
		self
	)


	last_projectile = (
		projectile
	)


	if not commit_authoritative_fire():

		projectile.queue_free()

		return false


	return true


# =========================================================
# PREPARAR DISPARO AUTORITATIVO
# =========================================================

func build_authoritative_fire_data(
	target_position: Vector2
) -> Dictionary:

	if not can_fire():

		return {
			"valid": false,
			"reason": get_fire_rejection_reason()
		}


	var direction: Vector2 = (
		global_position.direction_to(
			target_position
		)
	)


	if direction.length_squared() <= 0.0001:

		return {
			"valid": false,
			"reason": "INVALID DIRECTION"
		}


	var start_position: Vector2 = (
		global_position
		+ direction
		* 28.0
	)


	return {
		"valid": true,
		"start_position": start_position,
		"direction": direction,
		"projectile_speed": projectile_speed,
		"projectile_range": projectile_range,
		"damage": damage
	}


# =========================================================
# COMMIT AUTORITATIVO
# =========================================================

func commit_authoritative_fire() -> bool:

	if not can_fire():
		return false


	ammo_count -= 1


	ammo_changed.emit(
		ammo_count
	)


	cooldown_remaining = (
		fire_cooldown
	)


	fired.emit()


	update_debug_label()

	queue_redraw()


	return true


# =========================================================
# RECHAZO
# =========================================================

func get_fire_rejection_reason() -> String:

	if not has_power():
		return "NO POWER"


	if ammo_count <= 0:
		return "NO AMMO"


	if cooldown_remaining > 0.0:
		return "COOLDOWN"


	return "UNKNOWN"


# =========================================================
# PROYECTIL DE RED
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


	last_projectile = (
		projectile
	)


# =========================================================
# APLICAR ESTADO DE RED
# =========================================================

func apply_network_state(
	new_ammo_count: int,
	new_cooldown_remaining: float
):

	# El Host ya tiene el estado autoritativo.
	if (
		NetworkManager.is_online()
		and NetworkManager.is_host()
	):

		return


	ammo_count = int(
		clamp(
			new_ammo_count,
			0,
			max_ammo
		)
	)


	cooldown_remaining = max(
		new_cooldown_remaining,
		0.0
	)


	ammo_changed.emit(
		ammo_count
	)


	update_debug_label()

	queue_redraw()


# =========================================================
# MUNICIÓN
# =========================================================

func reload(
	amount: int
) -> int:

	if amount <= 0:
		return 0


	# -----------------------------------------------------
	# ONLINE:
	# solamente el Host modifica la munición compartida.
	#
	# La solicitud remota de reload quedará para Ammo
	# Authority / interacción de torreta.
	# -----------------------------------------------------

	if (
		NetworkManager.is_online()
		and not NetworkManager.is_host()
	):

		return 0


	var previous_ammo: int = (
		ammo_count
	)


	ammo_count = int(
		clamp(
			ammo_count + amount,
			0,
			max_ammo
		)
	)


	var loaded: int = (
		ammo_count
		- previous_ammo
	)


	if loaded > 0:

		ammo_changed.emit(
			ammo_count
		)


		update_debug_label()


		if NetworkManager.is_online():

			var combat_manager = (
				resolve_network_combat_manager()
			)


			if (
				combat_manager != null
				and combat_manager.has_method(
					"broadcast_turret_state"
				)
			):

				combat_manager.broadcast_turret_state()


	return loaded


func get_ammo() -> int:

	return ammo_count


func get_max_ammo() -> int:

	return max_ammo


func get_projectile_range() -> float:

	return projectile_range


func get_cooldown_remaining() -> float:

	return cooldown_remaining


func get_last_projectile():

	return last_projectile


# =========================================================
# ESTADO
# =========================================================

func get_state_text() -> String:

	if not has_power():

		return "NO POWER"


	if ammo_count <= 0:

		return "NO AMMO"


	if cooldown_remaining > 0.0:

		return "COOLDOWN"


	return "READY"


# =========================================================
# QA
# =========================================================

func reset_for_qa(
	new_ammo: int
):

	ammo_count = int(
		clamp(
			new_ammo,
			0,
			max_ammo
		)
	)


	cooldown_remaining = 0.0

	last_projectile = null


	ammo_changed.emit(
		ammo_count
	)


	update_debug_label()

	queue_redraw()


func make_fire_ready_for_qa():

	cooldown_remaining = 0.0


func set_ammo_for_qa(
	value: int
):

	ammo_count = int(
		clamp(
			value,
			0,
			max_ammo
		)
	)


	ammo_changed.emit(
		ammo_count
	)


	update_debug_label()


# =========================================================
# DEBUG LABEL
# =========================================================

func create_debug_label():

	debug_label = Label.new()


	debug_label.name = (
		"SubmarineTurretDebugLabel"
	)


	debug_label.position = Vector2(
		-75,
		-65
	)


	debug_label.size = Vector2(
		150,
		55
	)


	debug_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)


	debug_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)


	debug_label.add_theme_font_size_override(
		"font_size",
		13
	)


	debug_label.add_theme_constant_override(
		"outline_size",
		4
	)


	debug_label.add_theme_color_override(
		"font_outline_color",
		Color.BLACK
	)


	debug_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	debug_label.z_index = 110


	add_child(
		debug_label
	)


# =========================================================
# ACTUALIZAR LABEL
# =========================================================

func update_debug_label():

	if debug_label == null:
		return


	debug_label.text = (
		"SUB TURRET\n"
		+ str(
			ammo_count
		)
		+ " / "
		+ str(
			max_ammo
		)
		+ " | "
		+ get_state_text()
	)


# =========================================================
# VISUAL
# =========================================================

func _draw():

	draw_rect(
		Rect2(
			-25,
			-10,
			50,
			20
		),
		Color(
			0.25,
			0.35,
			0.40,
			1.0
		)
	)


	draw_line(
		Vector2.ZERO,
		Vector2(
			35,
			0
		),
		Color(
			0.70,
			0.75,
			0.80,
			1.0
		),
		7.0
	)


	draw_circle(
		Vector2.ZERO,
		12.0,
		Color(
			0.35,
			0.45,
			0.50,
			1.0
		)
	)
