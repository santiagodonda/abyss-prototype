extends Node


const ITEMS: Dictionary = {

	# =====================================================
	# EQUIPAMIENTO
	# =====================================================

	"diving_suit": {
		"display_name": "Diving Suit",
		"category": "equipment",
		"max_stack": 1,
		"equipment_slot": "suit",
		"pressure_protection": 4.0
	},


	"oxygen_tank": {
		"display_name": "Oxygen Tank",
		"category": "equipment",
		"max_stack": 1,
		"equipment_slot": "tank",
		"oxygen_capacity": 1.0,
		"oxygen_consumption_rate": 0.015
	},


	# =====================================================
	# MATERIALES
	# =====================================================

	"scrap_metal": {
		"display_name": "Scrap Metal",
		"category": "material",
		"max_stack": 10
	},


	"electrical_component": {
		"display_name": "Electrical Component",
		"category": "material",
		"max_stack": 10
	},


	"rubber": {
		"display_name": "Rubber",
		"category": "material",
		"max_stack": 10
	},


	# =====================================================
	# LEGACY - LO RETIRAREMOS AL REHACER CRAFTING
	# =====================================================

	"repair_kit": {
		"display_name": "Repair Kit",
		"category": "consumable",
		"max_stack": 5,
		"repair_type": "legacy"
	},


	# =====================================================
	# HERRAMIENTAS
	# =====================================================

	"welding_tool": {
		"display_name": "Welding Tool",
		"category": "tool",
		"max_stack": 1,
		"equipment_slot": "tool",
		"tool_type": "welding",
		"repair_type": "hull",
		"required_fuel_item": "welding_fuel"
	},


	"wrench": {
		"display_name": "Wrench",
		"category": "tool",
		"max_stack": 1,
		"equipment_slot": "tool",
		"tool_type": "wrench",
		"repair_type": "mechanical"
	},


	"screwdriver": {
		"display_name": "Screwdriver",
		"category": "tool",
		"max_stack": 1,
		"equipment_slot": "tool",
		"tool_type": "screwdriver",
		"repair_type": "electrical"
	},


	# =====================================================
	# ARMAS
	# =====================================================

	"harpoon_gun": {
		"display_name": "Harpoon Gun",
		"category": "weapon",
		"max_stack": 1,

		# Reutilizamos el selector de herramientas actual.
		"equipment_slot": "tool",

		"tool_type": "weapon",
		"weapon_type": "projectile",

		"ammo_item": "harpoon_ammo",

		"damage": 20.0,
		"fire_cooldown": 0.8,

		"projectile_speed": 500.0,
		"projectile_range": 650.0
	},


	# =====================================================
	# MUNICIÓN
	# =====================================================

	"harpoon_ammo": {
		"display_name": "Harpoon",
		"category": "ammo",
		"max_stack": 12,
		"ammo_type": "harpoon"
	},


	# =====================================================
	# COMBUSTIBLES
	# =====================================================

	"welding_fuel": {
		"display_name": "Welding Fuel",
		"category": "fuel",
		"max_stack": 4,
		"fuel_type": "welding"
	}
}


# =========================================================
# CONSULTAS
# =========================================================

func has_definition(
	item_id: String
) -> bool:

	return ITEMS.has(
		item_id
	)


func get_definition(
	item_id: String
) -> Dictionary:

	if not ITEMS.has(
		item_id
	):
		return {}

	return ITEMS[item_id]


# =========================================================
# INFORMACIÓN BÁSICA
# =========================================================

func get_display_name(
	item_id: String
) -> String:

	var definition: Dictionary = (
		get_definition(
			item_id
		)
	)


	if definition.is_empty():
		return item_id


	return str(
		definition.get(
			"display_name",
			item_id
		)
	)


func get_category(
	item_id: String
) -> String:

	var definition: Dictionary = (
		get_definition(
			item_id
		)
	)


	return str(
		definition.get(
			"category",
			"unknown"
		)
	)


func get_max_stack(
	item_id: String
) -> int:

	var definition: Dictionary = (
		get_definition(
			item_id
		)
	)


	return int(
		definition.get(
			"max_stack",
			1
		)
	)


# =========================================================
# EQUIPAMIENTO
# =========================================================

func get_equipment_slot(
	item_id: String
) -> String:

	var definition: Dictionary = (
		get_definition(
			item_id
		)
	)


	return str(
		definition.get(
			"equipment_slot",
			""
		)
	)


# =========================================================
# PROPIEDADES GENÉRICAS
# =========================================================

func get_property(
	item_id: String,
	property_name: String,
	default_value = null
):

	var definition: Dictionary = (
		get_definition(
			item_id
		)
	)


	return definition.get(
		property_name,
		default_value
	)


func get_float_property(
	item_id: String,
	property_name: String,
	default_value: float = 0.0
) -> float:

	return float(
		get_property(
			item_id,
			property_name,
			default_value
		)
	)


func get_int_property(
	item_id: String,
	property_name: String,
	default_value: int = 0
) -> int:

	return int(
		get_property(
			item_id,
			property_name,
			default_value
		)
	)
