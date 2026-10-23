extends Node2D


@export_group("Item")
@export var item_id: String = ""
@export var stored_quantity: int = 1
@export var auto_equip: bool = false


@onready var interaction_area: Area2D = (
	$InteractionArea
)


# =========================================================
# INICIALIZACIÓN
# =========================================================

func _ready():

	interaction_area.add_to_group(
		"interactable_area"
	)


	if not ItemDB.has_definition(
		item_id
	):

		push_error(
			"ItemRack: item desconocido: "
			+ item_id
		)


	queue_redraw()


# =========================================================
# INTERACCIÓN
# =========================================================

func interact(
	player
):

	var inventory = player.get_node_or_null(
		"Inventory"
	)


	var equipment = player.get_node_or_null(
		"Equipment"
	)


	if inventory == null:
		return


	# -----------------------------------------------------
	# RETIRAR ITEM
	# -----------------------------------------------------

	if stored_quantity > 0:

		var added: bool = inventory.add_item(
			item_id,
			1
		)


		if not added:
			return


		stored_quantity -= 1


		if (
			auto_equip
			and equipment != null
		):

			equipment.equip_item(
				item_id
			)


		queue_redraw()

		return


	# -----------------------------------------------------
	# DEVOLVER ITEM
	# -----------------------------------------------------

	if not inventory.has_item(
		item_id,
		1
	):
		return


	if (
		equipment != null
		and equipment.is_item_equipped(
			item_id
		)
	):

		var equipment_slot: String = (
			ItemDB.get_equipment_slot(
				item_id
			)
		)


		equipment.unequip_slot(
			equipment_slot
		)


	var removed: bool = inventory.remove_item(
		item_id,
		1
	)


	if removed:

		stored_quantity += 1


	queue_redraw()


# =========================================================
# INFORMACIÓN
# =========================================================

func get_stored_quantity() -> int:

	return stored_quantity


func get_item_name() -> String:

	return ItemDB.get_display_name(
		item_id
	)


# =========================================================
# VISUAL
# =========================================================

func _draw():

	var body_color: Color


	if stored_quantity > 0:

		body_color = Color(
			0.15,
			0.18,
			0.22,
			1.0
		)

	else:

		body_color = Color(
			0.07,
			0.08,
			0.10,
			1.0
		)


	draw_rect(
		Rect2(
			-35,
			-40,
			70,
			80
		),
		body_color
	)


	if stored_quantity <= 0:
		return


	var category: String = (
		ItemDB.get_category(
			item_id
		)
	)


	if category == "tool":

		draw_rect(
			Rect2(
				-25,
				-8,
				50,
				16
			),
			Color(
				0.65,
				0.68,
				0.72,
				1.0
			)
		)


	elif category == "fuel":

		draw_rect(
			Rect2(
				-12,
				-25,
				24,
				50
			),
			Color(
				0.75,
				0.45,
				0.18,
				1.0
			)
		)
