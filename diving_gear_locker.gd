extends Node2D


const ITEM_ID: String = "diving_suit"


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
	# SACAR TRAJE DEL LOCKER
	# ---------------------------------------------

	if item_available:

		var added: bool = inventory.add_item(
			ITEM_ID,
			1
		)

		if not added:
			return


		item_available = false

		equipment.equip_diving_suit()

		queue_redraw()

		return


	# ---------------------------------------------
	# DEVOLVER TRAJE AL LOCKER
	# ---------------------------------------------

	if not inventory.has_item(
		ITEM_ID
	):
		return


	equipment.unequip_diving_suit()


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
			0.15,
			0.2,
			0.24,
			1.0
		)

	else:
		body_color = Color(
			0.08,
			0.1,
			0.12,
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


	# Visor del traje.
	if item_available:

		draw_rect(
			Rect2(
				-22,
				-30,
				44,
				35
			),
			Color(
				0.15,
				0.55,
				0.7,
				1.0
			)
		)


	draw_rect(
		Rect2(
			-18,
			15,
			36,
			25
		),
		Color(
			0.35,
			0.4,
			0.45,
			1.0
		)
	)
