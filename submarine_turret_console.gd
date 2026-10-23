extends Node2D


# =========================================================
# CONFIGURACIÓN
# =========================================================

@export_group("Turret")

@export var turret_path: NodePath = (
	NodePath("../SubmarineTurret")
)


@export_group("Debug")

@export var show_debug_label: bool = true


# =========================================================
# REFERENCIAS
# =========================================================

@onready var interaction_area: Area2D = (
	$InteractionArea
)


@onready var turret = (
	get_node_or_null(
		turret_path
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


	if show_debug_label:

		create_debug_label()


	queue_redraw()


# =========================================================
# INTERACCIÓN
# =========================================================

func interact(
	_player
):

	# Por ahora el control se habilitará desde HUD
	# cuando el jugador esté cerca de la consola.
	pass


# =========================================================
# PRIORIDAD
# =========================================================

func get_interaction_priority(
	_player
) -> int:

	return 55


# =========================================================
# CONSULTAS
# =========================================================

func get_turret():

	return turret


# =========================================================
# LABEL
# =========================================================

func create_debug_label():

	debug_label = Label.new()


	debug_label.name = (
		"TurretConsoleDebugLabel"
	)


	debug_label.position = Vector2(
		-90,
		-60
	)


	debug_label.size = Vector2(
		180,
		40
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
		Color.BLACK
	)


	debug_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	debug_label.z_index = 110


	add_child(
		debug_label
	)


	debug_label.text = (
		"TURRET CONTROL"
	)


# =========================================================
# VISUAL
# =========================================================

func _draw():

	draw_rect(
		Rect2(
			-42,
			-32,
			84,
			64
		),
		Color(
			0.15,
			0.28,
			0.33,
			1.0
		)
	)


	draw_rect(
		Rect2(
			-27,
			-18,
			54,
			28
		),
		Color(
			0.20,
			0.50,
			0.55,
			1.0
		)
	)
