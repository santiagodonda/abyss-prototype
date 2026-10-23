extends Node


signal inventory_changed


@export_group("Inventory")
@export var max_slots: int = 8


var slots: Array = []

var last_action: String = "NOT USED"


# =========================================================
# AGREGAR OBJETOS
# =========================================================

func add_item(
	item_id: String,
	quantity: int = 1
) -> bool:

	if item_id.is_empty():

		last_action = (
			"ADD FAILED: EMPTY ITEM ID"
		)

		return false


	if quantity <= 0:

		last_action = (
			"ADD FAILED: INVALID QUANTITY "
			+ str(quantity)
		)

		return false


	# -----------------------------------------------------
	# VALIDAR ITEM DATABASE
	# -----------------------------------------------------

	if ItemDB == null:

		last_action = (
			"ADD FAILED: ITEMDB NULL"
		)

		return false


	if not ItemDB.has_definition(
		item_id
	):

		last_action = (
			"ADD FAILED: UNKNOWN ITEM "
			+ item_id
		)


		push_warning(
			"Inventory: ItemDB no contiene: "
			+ item_id
		)


		return false


	# -----------------------------------------------------
	# ESPACIO
	# -----------------------------------------------------

	if not can_add_item(
		item_id,
		quantity
	):

		last_action = (
			"ADD FAILED: NO SPACE FOR "
			+ item_id
		)

		return false


	var remaining: int = quantity


	var max_stack: int = (
		ItemDB.get_max_stack(
			item_id
		)
	)


	max_stack = max(
		max_stack,
		1
	)


	# -----------------------------------------------------
	# LLENAR STACKS EXISTENTES
	# -----------------------------------------------------

	for index in range(
		slots.size()
	):

		if remaining <= 0:
			break


		var slot: Dictionary = (
			slots[index]
		)


		if str(
			slot.get(
				"item_id",
				""
			)
		) != item_id:

			continue


		var current_quantity: int = int(
			slot.get(
				"quantity",
				0
			)
		)


		if current_quantity >= max_stack:
			continue


		var available_space: int = (
			max_stack
			- current_quantity
		)


		var amount_to_add: int = min(
			remaining,
			available_space
		)


		current_quantity += (
			amount_to_add
		)


		remaining -= (
			amount_to_add
		)


		slot["quantity"] = (
			current_quantity
		)


		slots[index] = slot


	# -----------------------------------------------------
	# CREAR STACKS NUEVOS
	# -----------------------------------------------------

	while remaining > 0:

		var amount_to_add: int = min(
			remaining,
			max_stack
		)


		slots.append(
			{
				"item_id": item_id,
				"quantity": amount_to_add
			}
		)


		remaining -= (
			amount_to_add
		)


	last_action = (
		"ADDED: "
		+ ItemDB.get_display_name(
			item_id
		)
		+ " x"
		+ str(quantity)
	)


	inventory_changed.emit()

	return true


# =========================================================
# COMPROBAR ESPACIO
# =========================================================

func can_add_item(
	item_id: String,
	quantity: int = 1
) -> bool:

	if quantity <= 0:
		return false


	if not ItemDB.has_definition(
		item_id
	):
		return false


	var remaining: int = quantity


	var max_stack: int = (
		ItemDB.get_max_stack(
			item_id
		)
	)


	max_stack = max(
		max_stack,
		1
	)


	# -----------------------------------------------------
	# ESPACIO EN STACKS EXISTENTES
	# -----------------------------------------------------

	for slot in slots:

		if str(
			slot.get(
				"item_id",
				""
			)
		) != item_id:

			continue


		var current_quantity: int = int(
			slot.get(
				"quantity",
				0
			)
		)


		var available_space: int = max(
			max_stack
			- current_quantity,
			0
		)


		remaining -= (
			available_space
		)


		if remaining <= 0:
			return true


	# -----------------------------------------------------
	# SLOTS NUEVOS
	# -----------------------------------------------------

	var slots_needed: int = int(
		ceil(
			float(remaining)
			/ float(max_stack)
		)
	)


	return (
		get_free_slots()
		>= slots_needed
	)


# =========================================================
# QUITAR OBJETOS
# =========================================================

func remove_item(
	item_id: String,
	quantity: int = 1
) -> bool:

	if quantity <= 0:

		last_action = (
			"REMOVE FAILED: INVALID QUANTITY"
		)

		return false


	if not has_item(
		item_id,
		quantity
	):

		last_action = (
			"REMOVE FAILED: MISSING "
			+ item_id
		)

		return false


	var remaining: int = quantity


	for index in range(
		slots.size() - 1,
		-1,
		-1
	):

		if remaining <= 0:
			break


		var slot: Dictionary = (
			slots[index]
		)


		if str(
			slot.get(
				"item_id",
				""
			)
		) != item_id:

			continue


		var current_quantity: int = int(
			slot.get(
				"quantity",
				0
			)
		)


		var amount_to_remove: int = min(
			current_quantity,
			remaining
		)


		current_quantity -= (
			amount_to_remove
		)


		remaining -= (
			amount_to_remove
		)


		if current_quantity <= 0:

			slots.remove_at(
				index
			)

		else:

			slot["quantity"] = (
				current_quantity
			)


			slots[index] = slot


	last_action = (
		"REMOVED: "
		+ ItemDB.get_display_name(
			item_id
		)
		+ " x"
		+ str(quantity)
	)


	inventory_changed.emit()

	return true


# =========================================================
# VARIOS OBJETOS
# =========================================================

func has_items(
	requirements: Dictionary
) -> bool:

	for item_id in requirements.keys():

		var quantity: int = int(
			requirements[
				item_id
			]
		)


		if not has_item(
			str(item_id),
			quantity
		):

			return false


	return true


func remove_items(
	requirements: Dictionary
) -> bool:

	if not has_items(
		requirements
	):

		last_action = (
			"REMOVE FAILED: MISSING RECIPE ITEMS"
		)

		return false


	for item_id in requirements.keys():

		var removed: bool = remove_item(
			str(item_id),
			int(
				requirements[
					item_id
				]
			)
		)


		if not removed:
			return false


	last_action = (
		"REMOVED RECIPE MATERIALS"
	)


	return true


# =========================================================
# CONSULTAS BÁSICAS
# =========================================================

func has_item(
	item_id: String,
	quantity: int = 1
) -> bool:

	return (
		get_item_quantity(
			item_id
		)
		>= quantity
	)


func get_item_quantity(
	item_id: String
) -> int:

	var total: int = 0


	for slot in slots:

		if str(
			slot.get(
				"item_id",
				""
			)
		) == item_id:

			total += int(
				slot.get(
					"quantity",
					0
				)
			)


	return total


func get_used_slots() -> int:

	return slots.size()


func get_free_slots() -> int:

	return max(
		max_slots
		- slots.size(),
		0
	)


func is_full() -> bool:

	return (
		get_free_slots()
		<= 0
	)


# =========================================================
# CONSULTAS POR TIPO / EQUIPMENT SLOT
# =========================================================

func get_item_ids_by_equipment_slot(
	equipment_slot: String
) -> Array[String]:

	var result: Array[String] = []


	for slot in slots:

		var item_id: String = str(
			slot.get(
				"item_id",
				""
			)
		)


		if item_id.is_empty():
			continue


		if item_id in result:
			continue


		if not ItemDB.has_definition(
			item_id
		):
			continue


		var item_equipment_slot: String = (
			ItemDB.get_equipment_slot(
				item_id
			)
		)


		if item_equipment_slot != equipment_slot:
			continue


		result.append(
			item_id
		)


	return result


func get_tool_item_ids() -> Array[String]:

	return get_item_ids_by_equipment_slot(
		"tool"
	)


func get_item_ids_by_category(
	category: String
) -> Array[String]:

	var result: Array[String] = []


	for slot in slots:

		var item_id: String = str(
			slot.get(
				"item_id",
				""
			)
		)


		if item_id.is_empty():
			continue


		if item_id in result:
			continue


		if ItemDB.get_category(
			item_id
		) != category:

			continue


		result.append(
			item_id
		)


	return result


# =========================================================
# DEBUG
# =========================================================

func get_last_action() -> String:

	return last_action


func get_item_database_status() -> String:

	if ItemDB == null:
		return "ERROR: ItemDB NULL"


	var required_test_items: Array[String] = [
		"diving_suit",
		"oxygen_tank",
		"scrap_metal",
		"electrical_component",
		"rubber",
		"repair_kit",
		"welding_tool",
		"welding_fuel",
		"wrench",
		"screwdriver"
	]


	var missing_items: Array[String] = []


	for item_id in required_test_items:

		if not ItemDB.has_definition(
			item_id
		):

			missing_items.append(
				item_id
			)


	if missing_items.is_empty():
		return "OK"


	return (
		"MISSING: "
		+ ", ".join(
			missing_items
		)
	)


func get_inventory_text() -> String:

	if slots.is_empty():
		return "Empty"


	var text: String = ""


	for index in range(
		slots.size()
	):

		var slot: Dictionary = (
			slots[index]
		)


		var item_id: String = str(
			slot.get(
				"item_id",
				""
			)
		)


		var quantity: int = int(
			slot.get(
				"quantity",
				0
			)
		)


		text += (
			ItemDB.get_display_name(
				item_id
			)
			+ " x"
			+ str(quantity)
		)


		if index < slots.size() - 1:

			text += "\n"


	return text
