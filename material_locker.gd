extends Node2D


@export_group("Stored Materials")
@export var scrap_metal: int = 5
@export var electrical_components: int = 3
@export var rubber: int = 4


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


	if inventory == null:
		return


	# Cada interacción intenta retirar
	# UN material siguiendo este orden.
	if scrap_metal > 0:

		if inventory.add_item(
			"scrap_metal",
			1
		):

			scrap_metal -= 1
			queue_redraw()
			return


	if electrical_components > 0:

		if inventory.add_item(
			"electrical_component",
			1
		):

			electrical_components -= 1
			queue_redraw()
			return


	if rubber > 0:

		if inventory.add_item(
			"rubber",
			1
		):

			rubber -= 1
			queue_redraw()
			return


# ---------------------------------------------------------
# INFORMACIÓN
# ---------------------------------------------------------

func get_total_items() -> int:
	return (
		scrap_metal
		+ electrical_components
		+ rubber
	)


# ---------------------------------------------------------
# VISUAL
# ---------------------------------------------------------

func _draw():
	var body_color: Color


	if get_total_items() > 0:

		body_color = Color(
			0.22,
			0.18,
			0.12,
			1.0
		)

	else:

		body_color = Color(
			0.08,
			0.08,
			0.08,
			1.0
		)


	# Contenedor.
	draw_rect(
		Rect2(
			-40,
			-45,
			80,
			90
		),
		body_color
	)


	# Metal.
	if scrap_metal > 0:

		draw_rect(
			Rect2(
				-28,
				-28,
				20,
				20
			),
			Color(
				0.55,
				0.58,
				0.62,
				1.0
			)
		)


	# Componente eléctrico.
	if electrical_components > 0:

		draw_rect(
			Rect2(
				-5,
				-28,
				20,
				20
			),
			Color(
				0.8,
				0.65,
				0.15,
				1.0
			)
		)


	# Goma.
	if rubber > 0:

		draw_rect(
			Rect2(
				18,
				-28,
				12,
				20
			),
			Color(
				0.18,
				0.18,
				0.18,
				1.0
			)
		)
