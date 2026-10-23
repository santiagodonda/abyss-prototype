extends Node2D


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("Debug")

@export var show_debug_label: bool = true


# =========================================================
# REFERENCIAS
# =========================================================

@onready var interaction_area: Area2D = (
	$InteractionArea
)


@onready var interior_point = (
	get_node_or_null(
		"../HatchInteriorPoint"
	)
)


@onready var exterior_point = (
	get_node_or_null(
		"../HatchExteriorPoint"
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

	interaction_area.add_to_group(
		"interactable_area"
	)


	if interior_point == null:

		push_error(
			"ExteriorHatch: HatchInteriorPoint no encontrado."
		)


	if exterior_point == null:

		push_error(
			"ExteriorHatch: HatchExteriorPoint no encontrado."
		)


	if show_debug_label:

		create_debug_label()


	queue_redraw()


# =========================================================
# INTERACCIÓN
# =========================================================

func interact(
	player
):

	if player == null:
		return


	if interior_point == null:
		return


	if exterior_point == null:
		return


	var vitals = (
		player.get_node_or_null(
			"Vitals"
		)
	)


	if vitals == null:
		return


	# Usamos una comprobación actual de habitación,
	# no current_room, para no depender del tick de Vitals.
	var detected_room = null


	if vitals.has_method(
		"find_current_room"
	):

		detected_room = (
			vitals.find_current_room()
		)


	# -----------------------------------------------------
	# ESTÁ AFUERA -> ENTRAR
	# -----------------------------------------------------

	if detected_room == null:

		move_character(
			player,
			interior_point.global_position
		)

		return


	# -----------------------------------------------------
	# ESTÁ ADENTRO -> SALIR
	# -----------------------------------------------------

	move_character(
		player,
		exterior_point.global_position
	)


# =========================================================
# MOVER PERSONAJE
# =========================================================

func move_character(
	character,
	target_position: Vector2
):

	character.global_position = (
		target_position
	)


	# CharacterBody2D tiene velocity.
	# La anulamos para que no conserve impulso
	# al atravesar la escotilla.
	if character is CharacterBody2D:

		character.velocity = (
			Vector2.ZERO
		)


# =========================================================
# PRIORIDAD
# =========================================================

func get_interaction_priority(
	_player
) -> int:

	return 60


# =========================================================
# DEBUG LABEL
# =========================================================

func create_debug_label():

	debug_label = Label.new()


	debug_label.name = (
		"HatchDebugLabel"
	)


	debug_label.text = (
		"ESCOTILLA EXTERIOR"
	)


	debug_label.position = Vector2(
		-100,
		-28
	)


	debug_label.size = Vector2(
		200,
		25
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
# VISUAL
# =========================================================

func _draw():

	# Marco de escotilla sobre la pared superior.
	draw_rect(
		Rect2(
			-45,
			-12,
			90,
			24
		),
		Color(
			0.20,
			0.35,
			0.40,
			1.0
		)
	)


	draw_rect(
		Rect2(
			-35,
			-8,
			70,
			16
		),
		Color(
			0.10,
			0.15,
			0.18,
			1.0
		)
	)


	draw_circle(
		Vector2.ZERO,
		5.0,
		Color(
			0.35,
			0.75,
			0.80,
			1.0
		)
	)
