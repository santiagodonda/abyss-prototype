extends Node


signal equipment_changed
signal tank_oxygen_changed(new_value: float)
signal active_tool_changed(item_id: String)


const SLOT_SUIT: String = "suit"
const SLOT_TANK: String = "tank"
const SLOT_TOOL: String = "tool"

const TOOL_NEXT_ACTION: String = "tool_next"


@export_group("Tool Selection")
@export var keyboard_tool_selection_enabled: bool = true


var equipped_items: Dictionary = {
	SLOT_SUIT: "",
	SLOT_TANK: "",
	SLOT_TOOL: ""
}


var tank_oxygen: float = 1.0


@onready var inventory = (
	get_node_or_null("../Inventory")
)


# =========================================================
# INICIALIZACIÓN
# =========================================================

func _ready():

	if inventory == null:

		push_error(
			"Equipment: No se encontró Inventory"
		)

		return


	if inventory.has_signal(
		"inventory_changed"
	):

		inventory.inventory_changed.connect(
			_on_inventory_changed
		)


	if (
		keyboard_tool_selection_enabled
		and not InputMap.has_action(
			TOOL_NEXT_ACTION
		)
	):

		push_warning(
			"Equipment: falta InputMap action 'tool_next'"
		)


# =========================================================
# INPUT
# =========================================================

func _process(
	_delta
):

	if not keyboard_tool_selection_enabled:
		return


	if not InputMap.has_action(
		TOOL_NEXT_ACTION
	):
		return


	if Input.is_action_just_pressed(
		TOOL_NEXT_ACTION
	):

		print(
			"[EQUIPMENT] tool_next INPUT detected"
		)


		cycle_tool_next()


# =========================================================
# EQUIPAMIENTO GENÉRICO
# =========================================================

func equip_item(
	item_id: String
) -> bool:

	if inventory == null:
		return false


	if not inventory.has_item(
		item_id
	):
		return false


	var equipment_slot: String = (
		ItemDB.get_equipment_slot(
			item_id
		)
	)


	if equipment_slot.is_empty():
		return false


	if equipment_slot == SLOT_TOOL:

		return select_tool(
			item_id
		)


	if not equipped_items.has(
		equipment_slot
	):

		equipped_items[
			equipment_slot
		] = ""


	equipped_items[
		equipment_slot
	] = item_id


	# =====================================================
	# TANQUE
	# =====================================================

	if equipment_slot == SLOT_TANK:

		var capacity: float = (
			get_tank_capacity()
		)


		tank_oxygen = clamp(
			tank_oxygen,
			0.0,
			capacity
		)


	equipment_changed.emit()

	return true


# =========================================================
# DESEQUIPAR
# =========================================================

func unequip_slot(
	equipment_slot: String
):

	if not equipped_items.has(
		equipment_slot
	):
		return


	if str(
		equipped_items[
			equipment_slot
		]
	).is_empty():

		return


	equipped_items[
		equipment_slot
	] = ""


	equipment_changed.emit()


	if equipment_slot == SLOT_TOOL:

		active_tool_changed.emit(
			""
		)


# =========================================================
# TOGGLE
# =========================================================

func toggle_item(
	item_id: String
):

	if is_item_equipped(
		item_id
	):

		var equipment_slot: String = (
			ItemDB.get_equipment_slot(
				item_id
			)
		)


		unequip_slot(
			equipment_slot
		)


	else:

		equip_item(
			item_id
		)


# =========================================================
# CONSULTAS DE EQUIPAMIENTO
# =========================================================

func is_item_equipped(
	item_id: String
) -> bool:

	var equipment_slot: String = (
		ItemDB.get_equipment_slot(
			item_id
		)
	)


	if equipment_slot.is_empty():
		return false


	return (
		get_equipped_item(
			equipment_slot
		)
		== item_id
	)


func get_equipped_item(
	equipment_slot: String
) -> String:

	if not equipped_items.has(
		equipment_slot
	):
		return ""


	return str(
		equipped_items[
			equipment_slot
		]
	)


# =========================================================
# TRAJE
# =========================================================

func equip_diving_suit() -> bool:

	return equip_item(
		"diving_suit"
	)


func unequip_diving_suit():

	if is_diving_suit_equipped():

		unequip_slot(
			SLOT_SUIT
		)


func toggle_diving_suit():

	toggle_item(
		"diving_suit"
	)


func is_diving_suit_equipped() -> bool:

	return is_item_equipped(
		"diving_suit"
	)


# =========================================================
# TANQUE
# =========================================================

func equip_oxygen_tank() -> bool:

	return equip_item(
		"oxygen_tank"
	)


func unequip_oxygen_tank():

	if is_oxygen_tank_equipped():

		unequip_slot(
			SLOT_TANK
		)


func toggle_oxygen_tank():

	toggle_item(
		"oxygen_tank"
	)


func is_oxygen_tank_equipped() -> bool:

	return is_item_equipped(
		"oxygen_tank"
	)


# =========================================================
# HERRAMIENTAS
# =========================================================

func get_equipped_tool() -> String:

	return get_equipped_item(
		SLOT_TOOL
	)


func has_tool_equipped() -> bool:

	return not get_equipped_tool().is_empty()


func get_available_tools() -> Array[String]:

	if inventory == null:
		return []


	if not inventory.has_method(
		"get_tool_item_ids"
	):
		return []


	return inventory.get_tool_item_ids()


# =========================================================
# SELECCIONAR HERRAMIENTA
# =========================================================

func select_tool(
	item_id: String
) -> bool:

	if inventory == null:
		return false


	if item_id.is_empty():

		unequip_slot(
			SLOT_TOOL
		)

		return true


	if not inventory.has_item(
		item_id,
		1
	):
		return false


	if ItemDB.get_equipment_slot(
		item_id
	) != SLOT_TOOL:

		return false


	var previous_tool: String = (
		get_equipped_tool()
	)


	equipped_items[
		SLOT_TOOL
	] = item_id


	equipment_changed.emit()


	if previous_tool != item_id:

		active_tool_changed.emit(
			item_id
		)


		print(
			"[EQUIPMENT] Active Tool: ",
			ItemDB.get_display_name(
				item_id
			)
		)


	return true


# =========================================================
# CICLAR HERRAMIENTAS
# =========================================================

func cycle_tool_next() -> bool:

	return cycle_tool(
		1
	)


func cycle_tool_previous() -> bool:

	return cycle_tool(
		-1
	)


func cycle_tool(
	direction: int
) -> bool:

	var tools: Array[String] = (
		get_available_tools()
	)


	print(
		"[EQUIPMENT] Available tools: ",
		tools
	)


	if tools.is_empty():

		print(
			"[EQUIPMENT] No tools available"
		)


		if has_tool_equipped():

			unequip_slot(
				SLOT_TOOL
			)


		return false


	if direction == 0:
		return false


	var current_tool: String = (
		get_equipped_tool()
	)


	print(
		"[EQUIPMENT] Current tool: ",
		current_tool
	)


	var current_index: int = (
		tools.find(
			current_tool
		)
	)


	var next_index: int


	if current_index < 0:

		next_index = 0


	else:

		next_index = (
			current_index
			+ direction
		)


		next_index = posmod(
			next_index,
			tools.size()
		)


	return select_tool(
		tools[
			next_index
		]
	)


# =========================================================
# SELECCIÓN POR ÍNDICE
# =========================================================

func select_tool_by_index(
	index: int
) -> bool:

	var tools: Array[String] = (
		get_available_tools()
	)


	if index < 0:
		return false


	if index >= tools.size():
		return false


	return select_tool(
		tools[
			index
		]
	)


# =========================================================
# TEXTO PARA HUD
# =========================================================

func get_active_tool_display_name() -> String:

	var tool_id: String = (
		get_equipped_tool()
	)


	if tool_id.is_empty():
		return "NONE"


	return ItemDB.get_display_name(
		tool_id
	)


func get_available_tools_text() -> String:

	var tools: Array[String] = (
		get_available_tools()
	)


	if tools.is_empty():
		return "NONE"


	var names: Array[String] = []


	for tool_id in tools:

		names.append(
			ItemDB.get_display_name(
				tool_id
			)
		)


	return ", ".join(
		names
	)


# =========================================================
# INVENTARIO MODIFICADO
# =========================================================

func _on_inventory_changed():

	validate_equipped_items()


func validate_equipped_items():

	if inventory == null:
		return


	var changed: bool = false

	var tool_changed: bool = false


	for equipment_slot in equipped_items.keys():

		var item_id: String = str(
			equipped_items[
				equipment_slot
			]
		)


		if item_id.is_empty():
			continue


		if inventory.has_item(
			item_id,
			1
		):
			continue


		equipped_items[
			equipment_slot
		] = ""


		changed = true


		if equipment_slot == SLOT_TOOL:

			tool_changed = true


	if changed:

		equipment_changed.emit()


	if tool_changed:

		active_tool_changed.emit(
			""
		)


# =========================================================
# PROTECCIÓN CONTRA PRESIÓN
# =========================================================

func get_pressure_protection_bonus() -> float:

	var suit_id: String = (
		get_equipped_item(
			SLOT_SUIT
		)
	)


	if suit_id.is_empty():
		return 0.0


	return ItemDB.get_float_property(
		suit_id,
		"pressure_protection",
		0.0
	)


# =========================================================
# OXÍGENO
# =========================================================

func get_tank_capacity() -> float:

	var tank_id: String = (
		get_equipped_item(
			SLOT_TANK
		)
	)


	if tank_id.is_empty():
		return 0.0


	return ItemDB.get_float_property(
		tank_id,
		"oxygen_capacity",
		1.0
	)


func get_tank_consumption_rate() -> float:

	var tank_id: String = (
		get_equipped_item(
			SLOT_TANK
		)
	)


	if tank_id.is_empty():
		return 0.0


	return ItemDB.get_float_property(
		tank_id,
		"oxygen_consumption_rate",
		0.015
	)


func has_breathing_supply() -> bool:

	if get_equipped_item(
		SLOT_TANK
	).is_empty():

		return false


	return tank_oxygen > 0.0


func consume_tank_oxygen(
	delta: float
):

	if not has_breathing_supply():
		return


	tank_oxygen -= (
		get_tank_consumption_rate()
		* delta
	)


	tank_oxygen = clamp(
		tank_oxygen,
		0.0,
		get_tank_capacity()
	)


	tank_oxygen_changed.emit(
		tank_oxygen
	)


func refill_tank():

	var capacity: float = (
		get_tank_capacity()
	)


	if capacity <= 0.0:
		return


	tank_oxygen = capacity


	tank_oxygen_changed.emit(
		tank_oxygen
	)


func get_tank_percentage() -> float:

	var capacity: float = (
		get_tank_capacity()
	)


	if capacity <= 0.0:

		return clamp(
			tank_oxygen,
			0.0,
			1.0
		)


	return clamp(
		tank_oxygen
		/ capacity,
		0.0,
		1.0
	)
