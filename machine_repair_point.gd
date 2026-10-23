extends Node2D


# =========================================================
# DISPOSITIVO
# =========================================================

@export_group("Device")

@export var device_name: String = "DEVICE"

@export var device_path: NodePath


@export_enum(
	"mechanical",
	"electrical"
)
var repair_type: String = "mechanical"


# =========================================================
# CONDICIÓN
# =========================================================

@export_group("Condition")

@export_range(
	0.0,
	100.0,
	1.0
)
var starting_condition: float = 100.0

@export var max_condition: float = 100.0

@export var repair_rate: float = 20.0


# =========================================================
# DEGRADACIÓN AUTOMÁTICA
# =========================================================

@export_group("Automatic Degradation")

@export var automatic_degradation_enabled: bool = true

@export var usage_wear_per_minute: float = 0.5

@export var water_damage_enabled: bool = true

@export var water_damage_per_minute: float = 2.0

@export var degradation_interval: float = 0.25


# =========================================================
# NETWORK
# =========================================================

@export_group("Network")

@export var network_repair_interval: float = 0.10


# =========================================================
# TESTING
# =========================================================

@export_group("Testing")

@export_range(
	0.1,
	100.0,
	0.1
)
var degradation_multiplier: float = 1.0


# =========================================================
# DEBUG
# =========================================================

@export_group("Debug")

@export var show_debug_label: bool = true


# =========================================================
# ESTADO
# =========================================================

var current_condition: float = 100.0

var is_being_repaired: bool = false

var last_status: String = "OK"

var last_damage_source: String = "NONE"

var degradation_accumulator: float = 0.0

var network_repair_accumulator: float = 0.0


# =========================================================
# REPARADORES NETWORK
# =========================================================

var active_network_repairers: Dictionary = {}


# =========================================================
# REFERENCIAS
# =========================================================

@onready var interaction_area: Area2D = (
	$InteractionArea
)


@onready var network_component = (
	$NetworkInteractable
)


var device: Node = null

var containing_room: Node = null

var debug_label: Label


# =========================================================
# READY
# =========================================================

func _ready():

	current_condition = clamp(
		starting_condition,
		0.0,
		max_condition
	)


	interaction_area.add_to_group(
		"interactable_area"
	)


	resolve_device()

	find_containing_room()


	if show_debug_label:

		create_debug_label()


	refresh_idle_status()

	update_status()

	queue_redraw()


# =========================================================
# LOCALIZAR DISPOSITIVO
# =========================================================

func resolve_device():

	if device_path.is_empty():

		device = null


		push_warning(
			device_name
			+ ": Device Path no configurado."
		)

		return


	device = get_node_or_null(
		device_path
	)


	if device == null:

		push_warning(
			device_name
			+ ": no se encontró device en "
			+ str(
				device_path
			)
		)


# =========================================================
# LOCALIZAR HABITACIÓN
# =========================================================

func find_containing_room():

	containing_room = null


	for candidate in get_tree().get_nodes_in_group(
		"rooms"
	):

		if not candidate.has_method(
			"contains_global_point"
		):

			continue


		if candidate.contains_global_point(
			global_position
		):

			containing_room = candidate

			return


# =========================================================
# PROCESS
# =========================================================

func _process(
	delta: float
):

	# Client multiplayer sólo representa
	# el estado del Host.
	if (
		NetworkManager.is_online()
		and not NetworkManager.is_host()
	):

		return


	if NetworkManager.is_host():

		process_network_repair(
			delta
		)


	process_automatic_degradation(
		delta
	)


# =========================================================
# DEGRADACIÓN AUTOMÁTICA
# =========================================================

func process_automatic_degradation(
	delta: float
):

	if not automatic_degradation_enabled:
		return


	if current_condition <= 0.0:
		return


	if is_being_repaired:
		return


	degradation_accumulator += delta


	if (
		degradation_accumulator
		< degradation_interval
	):

		return


	var simulation_delta: float = (
		degradation_accumulator
	)


	degradation_accumulator = 0.0


	simulate_degradation(
		simulation_delta
	)


# =========================================================
# SIMULAR DEGRADACIÓN
# =========================================================

func simulate_degradation(
	delta: float
):

	var total_damage: float = 0.0

	var source_parts: Array[String] = []


	if is_device_active():

		var usage_damage: float = (
			usage_wear_per_minute
			/ 60.0
			* delta
			* degradation_multiplier
		)


		if usage_damage > 0.0:

			total_damage += usage_damage


			source_parts.append(
				"USE"
			)


	if (
		water_damage_enabled
		and is_device_underwater()
	):

		var water_damage: float = (
			water_damage_per_minute
			/ 60.0
			* delta
			* degradation_multiplier
		)


		if water_damage > 0.0:

			total_damage += water_damage


			source_parts.append(
				"WATER"
			)


	if total_damage <= 0.0:
		return


	var damage_source: String = (
		"+".join(
			source_parts
		)
	)


	apply_damage(
		total_damage,
		damage_source
	)


# =========================================================
# ¿DEVICE ACTIVO?
# =========================================================

func is_device_active() -> bool:

	if device == null:
		return false


	var active_value = device.get(
		"is_on"
	)


	if active_value == null:
		return false


	return bool(
		active_value
	)


# =========================================================
# ¿BAJO AGUA?
# =========================================================

func is_device_underwater() -> bool:

	if containing_room == null:

		find_containing_room()


	if containing_room == null:
		return false


	if not containing_room.has_method(
		"is_point_underwater"
	):

		return false


	return containing_room.is_point_underwater(
		global_position
	)


# =========================================================
# PRIORIDAD
# =========================================================

func get_interaction_priority(
	player
) -> int:

	if is_fully_repaired():
		return 0


	var equipment = (
		player.get_node_or_null(
			"Equipment"
		)
	)


	if equipment == null:
		return 20


	var tool_id: String = (
		equipment.get_equipped_tool()
	)


	if tool_id.is_empty():
		return 20


	if tool_matches_repair_type(
		tool_id
	):

		return 100


	return 30


# =========================================================
# INTERACCIÓN INSTANTÁNEA
# =========================================================

func interact(
	player
):

	if is_fully_repaired():

		refresh_idle_status()

		update_status()

		return


	if not validate_local_player_tool(
		player
	):

		return


	# =====================================================
	# OFFLINE
	# =====================================================

	if not NetworkManager.is_online():

		last_status = "READY"

		update_status()

		return


	# =====================================================
	# MULTIPLAYER
	# =====================================================

	network_component.request_hold_start(
		"repair_start"
	)


# =========================================================
# HOLD
# =========================================================

func interact_hold(
	player,
	delta: float
):

	# En multiplayer el Host mantiene
	# el proceso después de repair_start.
	if NetworkManager.is_online():
		return


	process_local_repair(
		player,
		delta
	)


# =========================================================
# REPARACIÓN OFFLINE
# =========================================================

func process_local_repair(
	player,
	delta: float
):

	if is_fully_repaired():

		current_condition = max_condition

		is_being_repaired = false

		refresh_idle_status()

		update_status()

		return


	if not validate_local_player_tool(
		player
	):

		is_being_repaired = false

		return


	is_being_repaired = true

	last_status = "REPAIRING"


	current_condition += (
		repair_rate
		* delta
	)


	current_condition = clamp(
		current_condition,
		0.0,
		max_condition
	)


	if current_condition >= max_condition:

		current_condition = max_condition

		is_being_repaired = false

		last_damage_source = "NONE"

		refresh_idle_status()


	update_status()

	queue_redraw()


# =========================================================
# RELEASE
# =========================================================

func interact_release(
	_player
):

	if NetworkManager.is_online():

		var stopped: bool = (
			network_component.request_hold_stop(
				"repair_stop"
			)
		)


		if not stopped:

			refresh_idle_status()

			update_status()

			queue_redraw()


		return


	is_being_repaired = false

	refresh_idle_status()

	update_status()

	queue_redraw()


# =========================================================
# CANCEL
# =========================================================

func interaction_cancel(
	_player
):

	if NetworkManager.is_online():

		var stopped: bool = (
			network_component.request_hold_stop(
				"repair_stop"
			)
		)


		if not stopped:

			refresh_idle_status()

			update_status()

			queue_redraw()


		return


	is_being_repaired = false

	refresh_idle_status()

	update_status()

	queue_redraw()


# =========================================================
# NETWORK — DISTANCIA
# =========================================================

func network_requires_distance(
	action: String
) -> bool:

	# STOP siempre tiene que poder llegar al Host,
	# incluso si el jugador ya se alejó.
	return (
		action
		!= "repair_stop"
	)


# =========================================================
# NETWORK — VALIDACIÓN
# =========================================================

func network_validate_action(
	peer_id: int,
	action: String,
	_payload: Dictionary
) -> bool:

	# -----------------------------------------------------
	# STOP
	# -----------------------------------------------------

	if action == "repair_stop":

		return active_network_repairers.has(
			peer_id
		)


	# -----------------------------------------------------
	# START
	# -----------------------------------------------------

	if action != "repair_start":
		return false


	if is_fully_repaired():
		return false


	var tool_id: String = (
		network_component.get_player_tool_id(
			peer_id
		)
	)


	if not tool_matches_repair_type(
		tool_id
	):

		return false


	return true


# =========================================================
# NETWORK — EJECUCIÓN
# =========================================================

func network_execute_action(
	peer_id: int,
	action: String,
	_payload: Dictionary
):

	if action == "repair_start":

		active_network_repairers[
			peer_id
		] = true


		is_being_repaired = true

		last_status = "REPAIRING"

		update_status()

		return


	if action == "repair_stop":

		active_network_repairers.erase(
			peer_id
		)


		refresh_network_repair_state()


# =========================================================
# REPARACIÓN HOST
# =========================================================

func process_network_repair(
	delta: float
):

	if active_network_repairers.is_empty():

		if is_being_repaired:

			is_being_repaired = false

			refresh_idle_status()

			update_status()

			queue_redraw()


			network_component.broadcast_state()


		return


	# -----------------------------------------------------
	# REVALIDAR PEERS
	# -----------------------------------------------------

	var previous_count: int = (
		active_network_repairers.size()
	)


	for peer_key in active_network_repairers.keys():

		var peer_id: int = int(
			peer_key
		)


		if not is_network_repairer_valid(
			peer_id
		):

			active_network_repairers.erase(
				peer_key
			)


	if (
		active_network_repairers.size()
		!= previous_count
	):

		refresh_network_repair_state()

		network_component.broadcast_state()


	if active_network_repairers.is_empty():
		return


	# -----------------------------------------------------
	# TICK DE REPARACIÓN
	# -----------------------------------------------------

	network_repair_accumulator += delta


	if (
		network_repair_accumulator
		< network_repair_interval
	):

		return


	var repair_delta: float = (
		network_repair_accumulator
	)


	network_repair_accumulator = 0.0


	var repairer_count: int = (
		active_network_repairers.size()
	)


	current_condition += (
		repair_rate
		* repair_delta
		* float(
			repairer_count
		)
	)


	current_condition = clamp(
		current_condition,
		0.0,
		max_condition
	)


	is_being_repaired = true

	last_status = "REPAIRING"


	if current_condition >= max_condition:

		current_condition = max_condition

		last_damage_source = "NONE"

		active_network_repairers.clear()

		is_being_repaired = false

		network_repair_accumulator = 0.0

		refresh_idle_status()


		# El Host local puede haber iniciado
		# también un hold.
		network_component.clear_local_hold()


	update_status()

	queue_redraw()


	network_component.broadcast_state()


# =========================================================
# VALIDAR REPARADOR ACTIVO
# =========================================================

func is_network_repairer_valid(
	peer_id: int
) -> bool:

	var position_result: Dictionary = (
		network_component.get_player_position(
			peer_id
		)
	)


	if not position_result.get(
		"valid",
		false
	):

		return false


	var player_position: Vector2 = (
		position_result[
			"position"
		]
	)


	var distance: float = (
		player_position.distance_to(
			global_position
		)
	)


	if (
		distance
		> network_component.interaction_distance
	):

		return false


	var tool_id: String = (
		network_component.get_player_tool_id(
			peer_id
		)
	)


	return tool_matches_repair_type(
		tool_id
	)


# =========================================================
# REFRESCAR NETWORK REPAIR
# =========================================================

func refresh_network_repair_state():

	is_being_repaired = (
		not active_network_repairers.is_empty()
	)


	if is_being_repaired:

		last_status = "REPAIRING"


	else:

		network_repair_accumulator = 0.0

		refresh_idle_status()


	update_status()

	queue_redraw()


# =========================================================
# VALIDACIÓN LOCAL DE HERRAMIENTA
# =========================================================

func validate_local_player_tool(
	player
) -> bool:

	var equipment = (
		player.get_node_or_null(
			"Equipment"
		)
	)


	if equipment == null:

		last_status = "NO EQUIPMENT"

		update_status()

		return false


	var tool_id: String = (
		equipment.get_equipped_tool()
	)


	if tool_id.is_empty():

		last_status = (
			"NEED "
			+ get_required_tool_name()
		)

		update_status()

		return false


	if not tool_matches_repair_type(
		tool_id
	):

		last_status = (
			"NEED "
			+ get_required_tool_name()
		)

		update_status()

		return false


	last_status = "READY"

	update_status()

	return true


# =========================================================
# TOOL TYPE
# =========================================================

func tool_matches_repair_type(
	tool_id: String
) -> bool:

	if tool_id.is_empty():
		return false


	var tool_repair_type: String = str(
		ItemDB.get_property(
			tool_id,
			"repair_type",
			""
		)
	)


	return (
		tool_repair_type
		== repair_type
	)


# =========================================================
# DAÑO
# =========================================================

func apply_damage(
	amount: float,
	source: String = "DAMAGE"
):

	if amount <= 0.0:
		return


	# Client no modifica condición real.
	if (
		NetworkManager.is_online()
		and not NetworkManager.is_host()
	):

		return


	current_condition -= amount


	current_condition = clamp(
		current_condition,
		0.0,
		max_condition
	)


	last_damage_source = source


	if not is_being_repaired:

		refresh_idle_status()


	update_status()

	queue_redraw()


	if NetworkManager.is_host():

		network_component.broadcast_state()


# =========================================================
# NETWORK — ESTADO
# =========================================================

func network_get_state() -> Dictionary:

	return {
		"current_condition":
			current_condition,

		"is_being_repaired":
			is_being_repaired,

		"last_status":
			last_status,

		"last_damage_source":
			last_damage_source
	}


# =========================================================
# NETWORK — APLICAR
# =========================================================

func network_apply_state(
	state: Dictionary
):

	if state.has(
		"current_condition"
	):

		current_condition = clamp(
			float(
				state[
					"current_condition"
				]
			),
			0.0,
			max_condition
		)


	if state.has(
		"is_being_repaired"
	):

		is_being_repaired = bool(
			state[
				"is_being_repaired"
			]
		)


	if state.has(
		"last_status"
	):

		last_status = str(
			state[
				"last_status"
			]
		)


	if state.has(
		"last_damage_source"
	):

		last_damage_source = str(
			state[
				"last_damage_source"
			]
		)


	# Si la reparación terminó, este peer ya no
	# necesita conservar un HOLD local activo.
	if (
		current_condition >= max_condition
		or not is_being_repaired
	):

		network_component.clear_local_hold()


	update_status()

	queue_redraw()


# =========================================================
# ESTADO DE CONDICIÓN
# =========================================================

func refresh_idle_status():

	last_status = (
		get_condition_state_name()
	)


func get_condition_state_name() -> String:

	if current_condition <= 0.0:
		return "BROKEN"


	var ratio: float = (
		get_condition_ratio()
	)


	if ratio < 0.25:
		return "CRITICAL"


	if ratio < 0.50:
		return "DAMAGED"


	if ratio < 0.75:
		return "WORN"


	if ratio < 1.0:
		return "GOOD"


	return "OK"


# =========================================================
# CONSULTAS
# =========================================================

func get_condition() -> float:

	return current_condition


func get_condition_ratio() -> float:

	if max_condition <= 0.0:
		return 0.0


	return clamp(
		current_condition
		/ max_condition,
		0.0,
		1.0
	)


func is_broken() -> bool:

	return (
		current_condition
		<= 0.0
	)


func is_fully_repaired() -> bool:

	return (
		current_condition
		>= max_condition
	)


func is_operational() -> bool:

	return not is_broken()


func get_efficiency_multiplier() -> float:

	if is_broken():
		return 0.0


	return get_condition_ratio()


func get_required_tool_name() -> String:

	match repair_type:

		"mechanical":

			return "WRENCH"


		"electrical":

			return "SCREWDRIVER"


	return "TOOL"


func get_status_text() -> String:

	return last_status


func get_last_damage_source() -> String:

	return last_damage_source


# =========================================================
# DEBUG LABEL
# =========================================================

func create_debug_label():

	debug_label = Label.new()


	debug_label.name = (
		"RepairDebugLabel"
	)


	debug_label.position = Vector2(
		-90,
		-70
	)


	debug_label.size = Vector2(
		180,
		60
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
		Color(
			0.0,
			0.0,
			0.0,
			1.0
		)
	)


	debug_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	debug_label.z_index = 110


	add_child(
		debug_label
	)


# =========================================================
# DEBUG STATUS
# =========================================================

func update_status():

	if debug_label == null:
		return


	var condition_percent: int = int(
		round(
			get_condition_ratio()
			* 100.0
		)
	)


	debug_label.text = (
		device_name
		+ "\n"
		+ str(
			condition_percent
		)
		+ "% | "
		+ last_status
		+ "\n"
		+ get_required_tool_name()
	)


	queue_redraw()


# =========================================================
# VISUAL
# =========================================================

func _draw():

	var ratio: float = (
		get_condition_ratio()
	)


	draw_circle(
		Vector2.ZERO,
		13.0,
		Color(
			0.45,
			0.45,
			0.50,
			1.0
		)
	)


	draw_rect(
		Rect2(
			-45,
			22,
			90,
			9
		),
		Color(
			0.12,
			0.12,
			0.12,
			1.0
		)
	)


	draw_rect(
		Rect2(
			-45,
			22,
			90.0 * ratio,
			9
		),
		Color(
			0.55,
			0.75,
			0.55,
			1.0
		)
	)
