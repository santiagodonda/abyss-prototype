extends Node2D


const ITEM_ID: String = "oxygen_tank"


var item_available: bool = true


@onready var interaction_area: Area2D = (
	$InteractionArea
)


# ---------------------------------------------------------
# INICIALIZACIÓN
# ---------------------------------------------------------

func _ready():
	interaction_area.add_to_group(
		"interactable_area"
	)

	queue_redraw()


# ---------------------------------------------------------
# INTERACCIÓN
# ---------------------------------------------------------

func interact(player):
	var inventory = player.get_node_or_null(
		"Inventory"
	)

	var equipment = player.get_node_or_null(
		"Equipment"
	)


	if inventory == null:
		return

	if equipment == null:
		return


	# ---------------------------------------------
	# SACAR TANQUE
	# ---------------------------------------------

	if item_available:

		var added: bool = inventory.add_item(
			ITEM_ID,
			1
		)

		if not added:
			return


		item_available = false

		equipment.equip_oxygen_tank()

		queue_redraw()

		return


	# ---------------------------------------------
	# DEVOLVER TANQUE
	# ---------------------------------------------

	if not inventory.has_item(
		ITEM_ID
	):
		return


	equipment.unequip_oxygen_tank()


	var removed: bool = inventory.remove_item(
		ITEM_ID,
		1
	)


	if removed:
		item_available = true


	queue_redraw()


# ---------------------------------------------------------
# ESTADO
# ---------------------------------------------------------

func has_item() -> bool:
	return item_available


# ---------------------------------------------------------
# VISUAL
# ---------------------------------------------------------

func _draw():
	var body_color: Color


	if item_available:
		body_color = Color(
			0.12,
			0.16,
			0.20,
			1.0
		)

	else:
		body_color = Color(
			0.07,
			0.09,
			0.11,
			1.0
		)


	draw_rect(
		Rect2(
			-35,
			-50,
			70,
			100
		),
		body_color
	)


	if item_available:

		draw_rect(
			Rect2(
				-14,
				-32,
				28,
				65
			),
			Color(
				0.65,
				0.68,
				0.72,
				1.0
			)
		)

		draw_rect(
			Rect2(
				-7,
				-42,
				14,
				10
			),
			Color(
				0.35,
				0.38,
				0.42,
				1.0
			)
		)
