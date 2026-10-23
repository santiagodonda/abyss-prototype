extends Node2D


signal breach_opened
signal breach_repaired


# =========================================================
# NETWORK
# =========================================================

@export_group("Network")

@export var breach_id: StringName = (
	&"hull_main_breach"
)

@export var network_repair_distance: float = 110.0

@export var network_retry_delay: float = 0.35


# =========================================================
# REPAIR
# =========================================================

@export_group("Repair")

@export var repair_time: float = 3.0

@export var required_repair_type: String = "hull"


# =========================================================
# WATER INFLOW
# =========================================================

@export_group("Water Inflow")

@export var base_water_inflow_rate: float = 0.03

@export var pressure_water_multiplier: float = 0.02

@export var max_water_inflow_rate: float = 0.18


# =========================================================
# PRESSURE
# =========================================================

@export_group("Pressure")

@export var pressure_transfer_speed: float = 0.80


# =========================================================
# SIMULATION
# =========================================================

@export_group("Simulation")

@export var simulation_interval: float = 0.1


# =========================================================
# DEBUG
# =========================================================

@export_group("Debug")

@export var print_repair_debug: bool = true

@export var repair_debug_interval: float = 0.50


# =========================================================
# STATE
# =========================================================

var repair_progress: float = 0.0

var repaired: bool = false

var simulation_accumulator: float = 0.0

var current_water_inflow_rate: float = 0.0


# =========================================================
# NETWORK LOCAL STATE
# =========================================================

var network_repair_requested: bool = false

var network_request_cooldown: float = 0.0

var network_hull_manager = null


# =========================================================
# DEBUG STATE
# =========================================================

var repair_debug_accumulator: float = 0.0

var last_repair_block_reason: String = ""

var repair_debug_active: bool = false


# =========================================================
# REFERENCES
# =========================================================

@onready var interaction_area: Area2D = (
	$InteractionArea
)


@onready var room = (
	$"../RoomRight"
)


@onready var submarine_environment = (
	$"../SubmarineEnvironment"
)


# =========================================================
# INITIALIZATION
# =========================================================

func _ready():

	interaction_area.add_to_group(
		"interactable_area"
	)


	add_to_group(
		"network_hull_breach"
	)


	call_deferred(
		"resolve_network_hull_manager"
	)


	queue_redraw()


# =========================================================
# RESOLVE MANAGER
# =========================================================

func resolve_network_hull_manager():

	if (
		network_hull_manager != null
		and is_instance_valid(
			network_hull_manager
		)
	):
		return network_hull_manager


	network_hull_manager = null


	var scene = (
		get_tree().current_scene
	)


	if scene != null:

		var candidate = (
			scene.get_node_or_null(
				"NetworkHullManager"
			)
		)


		if (
			candidate != null
			and is_instance_valid(
				candidate
			)
		):

			network_hull_manager = candidate

			return network_hull_manager


	var managers: Array = (
		get_tree().get_nodes_in_group(
			"network_hull_manager"
		)
	)


	if not managers.is_empty():

		network_hull_manager = (
			managers[0]
		)


	return network_hull_manager


# =========================================================
# SIMULATION
# =========================================================

func _process(
	delta: float
):

	network_request_cooldown = max(
		network_request_cooldown
		- delta,
		0.0
	)


	if (
		NetworkManager.is_online()
		and NetworkManager.is_client()
	):

		return


	if repaired:

		current_water_inflow_rate = 0.0

		return


	simulation_accumulator += delta


	if simulation_accumulator < simulation_interval:
		return


	var simulation_delta: float = (
		simulation_accumulator
	)


	simulation_accumulator = 0.0


	simulate_water_breach(
		simulation_delta
	)


	simulate_pressure_breach(
		simulation_delta
	)


# =========================================================
# WATER
# =========================================================

func simulate_water_breach(
	delta: float
):

	if room.water_level >= 1.0:

		current_water_inflow_rate = 0.0

		return


	var external_pressure: float = (
		submarine_environment.get_external_pressure()
	)


	var depth_pressure: float = max(
		external_pressure - 1.0,
		0.0
	)


	current_water_inflow_rate = (
		base_water_inflow_rate
		+ depth_pressure
		* pressure_water_multiplier
	)


	current_water_inflow_rate = clamp(
		current_water_inflow_rate,
		0.0,
		max_water_inflow_rate
	)


	room.set_water_level(
		room.water_level
		+ current_water_inflow_rate
		* delta
	)


# =========================================================
# PRESSURE
# =========================================================

func simulate_pressure_breach(
	delta: float
):

	var external_pressure: float = (
		submarine_environment.get_external_pressure()
	)


	var difference: float = (
		external_pressure
		- room.pressure
	)


	if abs(difference) < 0.001:
		return


	var transfer_amount: float = (
		pressure_transfer_speed
		* delta
	)


	transfer_amount = min(
		transfer_amount,
		abs(difference)
	)


	if difference > 0.0:

		room.set_pressure(
			room.pressure
			+ transfer_amount
		)

	else:

		room.set_pressure(
			room.pressure
			- transfer_amount
		)


# =========================================================
# INTERACTION PRIORITY
# =========================================================

func get_interaction_priority(
	player
) -> int:

	if repaired:
		return 0


	var equipment = (
		player.get_node_or_null(
			"Equipment"
		)
	)


	if equipment == null:
		return 30


	var tool_id: String = str(
		equipment.get_equipped_tool()
	)


	if tool_id.is_empty():
		return 30


	var repair_type: String = str(
		ItemDB.get_property(
			tool_id,
			"repair_type",
			""
		)
	)


	if repair_type == required_repair_type:
		return 70


	return 30


# =========================================================
# ACTIVATE / REOPEN
# =========================================================

func trigger_breach():

	if not repaired:
		return


	repaired = false

	repair_progress = 0.0

	current_water_inflow_rate = 0.0

	network_repair_requested = false


	reset_repair_debug_state()


	breach_opened.emit()


	queue_redraw()


# =========================================================
# INTERACT HOLD
# =========================================================

func interact_hold(
	player,
	delta: float
):

	if repaired:

		debug_repair_block(
			"BREACH ALREADY REPAIRED"
		)


		stop_network_repair_if_needed()

		return


	if NetworkManager.is_online():

		process_network_interact_hold(
			player
		)

		return


	process_offline_repair(
		player,
		delta
	)


# =========================================================
# NETWORK HOLD
# =========================================================

func process_network_interact_hold(
	player
):

	if network_request_cooldown > 0.0:
		return


	var context: Dictionary = (
		get_local_repair_context(
			player
		)
	)


	if not bool(
		context.get(
			"valid",
			false
		)
	):

		var reason: String = str(
			context.get(
				"reason",
				"INVALID REPAIR CONTEXT"
			)
		)


		debug_repair_block(
			reason
		)


		stop_network_repair_if_needed()

		return


	debug_repair_ready(
		str(
			context.get(
				"tool_id",
				""
			)
		),
		str(
			context.get(
				"fuel_item_id",
				""
			)
		)
	)


	if network_repair_requested:
		return


	var manager = (
		resolve_network_hull_manager()
	)


	if manager == null:

		debug_repair_block(
			"NETWORK HULL MANAGER NOT FOUND"
		)

		return


	if not manager.has_method(
		"request_start_repair"
	):

		debug_repair_block(
			"NETWORK MANAGER HAS NO request_start_repair()"
		)

		return


	var requested: bool = bool(
		manager.request_start_repair(
			self,
			bool(
				context.get(
					"has_fuel",
					false
				)
			)
		)
	)


	if requested:

		network_repair_requested = true


		if print_repair_debug:

			print(
				"[HULL REPAIR] Network repair requested"
			)


# =========================================================
# LOCAL REPAIR CONTEXT
# =========================================================

func get_local_repair_context(
	player
) -> Dictionary:

	if player == null:

		return {
			"valid": false,
			"reason": "PLAYER IS NULL"
		}


	var inventory = (
		player.get_node_or_null(
			"Inventory"
		)
	)


	var equipment = (
		player.get_node_or_null(
			"Equipment"
		)
	)


	if inventory == null:

		return {
			"valid": false,
			"reason": "INVENTORY NOT FOUND"
		}


	if equipment == null:

		return {
			"valid": false,
			"reason": "EQUIPMENT NOT FOUND"
		}


	var tool_id: String = str(
		equipment.get_equipped_tool()
	)


	if tool_id.is_empty():

		return {
			"valid": false,
			"reason": "NO TOOL EQUIPPED"
		}


	var tool_repair_type: String = str(
		ItemDB.get_property(
			tool_id,
			"repair_type",
			""
		)
	)


	if tool_repair_type != required_repair_type:

		return {
			"valid": false,
			"reason":
				"WRONG TOOL | "
				+ tool_id
				+ " | repair_type="
				+ tool_repair_type
		}


	var fuel_item_id: String = str(
		ItemDB.get_property(
			tool_id,
			"required_fuel_item",
			""
		)
	)


	var has_fuel: bool = true


	if not fuel_item_id.is_empty():

		has_fuel = bool(
			inventory.has_item(
				fuel_item_id,
				1
			)
		)


	if not has_fuel:

		return {
			"valid": false,
			"has_fuel": false,
			"reason":
				"MISSING FUEL | "
				+ fuel_item_id
		}


	return {
		"valid": true,
		"has_fuel": true,
		"tool_id": tool_id,
		"fuel_item_id": fuel_item_id
	}


# =========================================================
# OFFLINE REPAIR
# =========================================================

func process_offline_repair(
	player,
	delta: float
):

	var inventory = (
		player.get_node_or_null(
			"Inventory"
		)
	)


	var equipment = (
		player.get_node_or_null(
			"Equipment"
		)
	)


	if inventory == null:

		debug_repair_block(
			"INVENTORY NOT FOUND"
		)


		reset_repair_progress()

		return


	if equipment == null:

		debug_repair_block(
			"EQUIPMENT NOT FOUND"
		)


		reset_repair_progress()

		return


	var tool_id: String = str(
		equipment.get_equipped_tool()
	)


	if tool_id.is_empty():

		debug_repair_block(
			"NO TOOL EQUIPPED"
		)


		reset_repair_progress()

		return


	var tool_repair_type: String = str(
		ItemDB.get_property(
			tool_id,
			"repair_type",
			""
		)
	)


	if tool_repair_type != required_repair_type:

		debug_repair_block(
			"WRONG TOOL | "
			+ tool_id
			+ " | repair_type="
			+ tool_repair_type
			+ " | required="
			+ required_repair_type
		)


		reset_repair_progress()

		return


	var fuel_item_id: String = str(
		ItemDB.get_property(
			tool_id,
			"required_fuel_item",
			""
		)
	)


	if not fuel_item_id.is_empty():

		if not inventory.has_item(
			fuel_item_id,
			1
		):

			var quantity: int = 0


			if inventory.has_method(
				"get_item_quantity"
			):

				quantity = int(
					inventory.get_item_quantity(
						fuel_item_id
					)
				)


			debug_repair_block(
				"MISSING FUEL | "
				+ fuel_item_id
				+ " | Quantity="
				+ str(
					quantity
				)
			)


			reset_repair_progress()

			return


	debug_repair_ready(
		tool_id,
		fuel_item_id
	)


	repair_progress += delta


	repair_progress = clamp(
		repair_progress,
		0.0,
		repair_time
	)


	repair_debug_accumulator += delta


	if (
		print_repair_debug
		and repair_debug_accumulator
		>= repair_debug_interval
	):

		repair_debug_accumulator = 0.0


		print(
			"[HULL REPAIR] Progress ",
			snapped(
				repair_progress,
				0.01
			),
			" / ",
			repair_time
		)


	if repair_progress >= repair_time:

		if print_repair_debug:

			print(
				"[HULL REPAIR] Repair time reached"
			)


		complete_repair(
			inventory,
			fuel_item_id
		)


	queue_redraw()


# =========================================================
# NETWORK PROGRESSION — HOST ONLY
# =========================================================

func advance_network_repair(
	delta: float
) -> bool:

	if (
		NetworkManager.is_online()
		and not NetworkManager.is_host()
	):

		return false


	if repaired:
		return false


	if delta <= 0.0:
		return false


	repair_progress += delta


	repair_progress = clamp(
		repair_progress,
		0.0,
		repair_time
	)


	repair_debug_accumulator += delta


	if (
		print_repair_debug
		and repair_debug_accumulator
		>= repair_debug_interval
	):

		repair_debug_accumulator = 0.0


		print(
			"[HULL REPAIR][HOST] Progress ",
			snapped(
				repair_progress,
				0.01
			),
			" / ",
			repair_time
		)


	queue_redraw()


	return (
		repair_progress
		>= repair_time
	)


# =========================================================
# COMPLETE REPAIR — LEGACY/OFFLINE
# =========================================================

func complete_repair(
	inventory,
	fuel_item_id: String
):

	if repaired:
		return


	if (
		NetworkManager.is_online()
		and NetworkManager.is_client()
	):

		return


	if not fuel_item_id.is_empty():

		if print_repair_debug:

			print(
				"[HULL REPAIR] Consuming fuel: ",
				fuel_item_id
			)


		var consumed: bool = bool(
			inventory.remove_item(
				fuel_item_id,
				1
			)
		)


		if not consumed:

			if print_repair_debug:

				print(
					"[HULL REPAIR][BLOCKED] Fuel consumption failed"
				)


			reset_repair_progress()

			return


		if print_repair_debug:

			print(
				"[HULL REPAIR] Fuel consumed successfully"
			)


	finish_repair_authoritative()


# =========================================================
# AUTHORITATIVE FINISH
# =========================================================

func finish_repair_authoritative():

	if repaired:
		return


	if (
		NetworkManager.is_online()
		and not NetworkManager.is_host()
	):

		return


	repaired = true

	repair_progress = repair_time

	current_water_inflow_rate = 0.0

	network_repair_requested = false


	if print_repair_debug:

		print(
			"[HULL REPAIR] COMPLETE | ",
			breach_id
		)


	reset_repair_debug_state()


	breach_repaired.emit()


	queue_redraw()


# =========================================================
# COMPATIBILITY
# =========================================================

func finish_repair():

	finish_repair_authoritative()


# =========================================================
# INSTANT REPAIR
# =========================================================

func repair_instant():

	if (
		NetworkManager.is_online()
		and not NetworkManager.is_host()
	):

		return


	if repaired:

		current_water_inflow_rate = 0.0

		return


	repaired = true

	repair_progress = repair_time

	current_water_inflow_rate = 0.0

	network_repair_requested = false


	reset_repair_debug_state()


	breach_repaired.emit()


	queue_redraw()


# =========================================================
# RELEASE / CANCEL
# =========================================================

func interact_release(
	_player
):

	if NetworkManager.is_online():

		stop_network_repair_if_needed()

		return


	if repaired:
		return


	if print_repair_debug:

		print(
			"[HULL REPAIR] RELEASE | Progress was ",
			snapped(
				repair_progress,
				0.01
			),
			" / ",
			repair_time
		)


	reset_repair_progress()


func interaction_cancel(
	_player
):

	if NetworkManager.is_online():

		stop_network_repair_if_needed()

		return


	if repaired:
		return


	if (
		print_repair_debug
		and repair_progress > 0.0
	):

		print(
			"[HULL REPAIR] CANCEL | Progress was ",
			snapped(
				repair_progress,
				0.01
			),
			" / ",
			repair_time
		)


	reset_repair_progress()


# =========================================================
# STOP NETWORK REQUEST
# =========================================================

func stop_network_repair_if_needed():

	if not network_repair_requested:
		return


	var manager = (
		resolve_network_hull_manager()
	)


	if (
		manager != null
		and manager.has_method(
			"request_stop_repair"
		)
	):

		manager.request_stop_repair(
			self
		)


	network_repair_requested = false


# =========================================================
# HOST CANCEL NOTIFICATION
# =========================================================

func notify_network_repair_cancelled():

	network_repair_requested = false

	network_request_cooldown = (
		network_retry_delay
	)


	if print_repair_debug:

		print(
			"[HULL REPAIR] Network repair cancelled"
		)


# =========================================================
# RESET PROGRESS
# =========================================================

func reset_network_repair_progress():

	if (
		NetworkManager.is_online()
		and not NetworkManager.is_host()
	):

		return


	repair_progress = 0.0

	repair_debug_accumulator = 0.0


	queue_redraw()


func reset_repair_progress():

	if (
		NetworkManager.is_online()
		and NetworkManager.is_client()
	):

		return


	if repair_progress <= 0.0:

		repair_debug_accumulator = 0.0

		return


	repair_progress = 0.0

	repair_debug_accumulator = 0.0


	queue_redraw()


# =========================================================
# DEBUG HELPERS
# =========================================================

func debug_repair_block(
	reason: String
):

	if not print_repair_debug:
		return


	if last_repair_block_reason == reason:
		return


	last_repair_block_reason = reason

	repair_debug_active = false


	print(
		"[HULL REPAIR][BLOCKED] ",
		reason
	)


func debug_repair_ready(
	tool_id: String,
	fuel_item_id: String
):

	last_repair_block_reason = ""


	if repair_debug_active:
		return


	repair_debug_active = true


	if not print_repair_debug:
		return


	print(
		"[HULL REPAIR] READY | Tool=",
		tool_id,
		" | Fuel=",
		fuel_item_id
	)


func reset_repair_debug_state():

	repair_debug_accumulator = 0.0

	last_repair_block_reason = ""

	repair_debug_active = false


# =========================================================
# NETWORK ID
# =========================================================

func get_network_breach_id() -> StringName:

	return breach_id


func get_network_repair_distance() -> float:

	return network_repair_distance


# =========================================================
# BUILD NETWORK STATE
# =========================================================

func build_network_state() -> Dictionary:

	return {
		"breach_id":
			str(
				breach_id
			),

		"repaired":
			repaired,

		"repair_progress":
			repair_progress,

		"repair_time":
			repair_time,

		"water_inflow_rate":
			current_water_inflow_rate
	}


# =========================================================
# APPLY NETWORK STATE
# =========================================================

func apply_network_state(
	state: Dictionary
):

	if (
		NetworkManager.is_online()
		and NetworkManager.is_host()
	):

		return


	var was_repaired: bool = (
		repaired
	)


	if state.has(
		"repair_time"
	):

		repair_time = max(
			float(
				state[
					"repair_time"
				]
			),
			0.001
		)


	repair_progress = clamp(
		float(
			state.get(
				"repair_progress",
				repair_progress
			)
		),
		0.0,
		repair_time
	)


	current_water_inflow_rate = max(
		float(
			state.get(
				"water_inflow_rate",
				current_water_inflow_rate
			)
		),
		0.0
	)


	repaired = bool(
		state.get(
			"repaired",
			repaired
		)
	)


	if repaired:

		current_water_inflow_rate = 0.0

		network_repair_requested = false


	if (
		not was_repaired
		and repaired
	):

		breach_repaired.emit()


	elif (
		was_repaired
		and not repaired
	):

		breach_opened.emit()


	queue_redraw()


# =========================================================
# INFORMATION
# =========================================================

func get_water_inflow_rate() -> float:

	return current_water_inflow_rate


func get_repair_progress() -> float:

	return repair_progress


func get_repair_ratio() -> float:

	if repair_time <= 0.0:
		return 0.0


	return clamp(
		repair_progress
		/ repair_time,
		0.0,
		1.0
	)


func is_repaired() -> bool:

	return repaired


func is_active() -> bool:

	return not repaired


# =========================================================
# VISUAL
# =========================================================

func _draw():

	if repaired:

		draw_rect(
			Rect2(
				-12,
				-45,
				24,
				90
			),
			Color(
				0.2,
				0.55,
				0.25,
				1.0
			)
		)

	else:

		draw_rect(
			Rect2(
				-12,
				-45,
				24,
				90
			),
			Color(
				0.85,
				0.25,
				0.1,
				1.0
			)
		)


		if repair_progress > 0.0:

			var percent: float = clamp(
				repair_progress
				/ repair_time,
				0.0,
				1.0
			)


			draw_rect(
				Rect2(
					-50,
					-75,
					100,
					10
				),
				Color(
					0.15,
					0.15,
					0.15,
					1.0
				)
			)


			draw_rect(
				Rect2(
					-50,
					-75,
					100 * percent,
					10
				),
				Color(
					0.3,
					0.8,
					0.3,
					1.0
				)
			)
